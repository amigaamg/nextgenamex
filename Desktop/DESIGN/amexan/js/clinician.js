/* =================================================================
   AMEXAN CLINICIAN OS — the clinician workspace as the clinical
   operating layer. One patient, one story: the clinician works a
   task (ward round, clinic, results, discharge) and AMEXAN assembles
   that patient's current clinical reality around the task.

   Built on the existing clinical CPU (intelligence.js), the encounter
   workspace (clinical.js), the patient record and the shared S state.
   No dead UI: every button here navigates to a real connected
   destination against the same clinical-state model.
   ================================================================= */

/* ---------- OS DATA ---------- */

/* Ward 4A — General Medical (short-stay). Each row links to a real
   patient MRN so selectPatient() loads the true encounter clinical state. */
const WARD_4A = [
  {mrn:'AMX-000001', bed:'4A-03', admitted:'19 Aug 2026', days:2, status:'attention', trajectory:'Improving',
   reason:'Severe CAP — hypoxaemia, sepsis screen', oxygen:'O₂ 2 L/min',
   note:'Responding to IV antibiotics · oxygen weaning overnight',
   overnight:[
     {t:'03:40', sev:'amber', s:'SpO₂ 91% on room air — placed on O₂ 2 L/min'},
     {t:'05:10', sev:'amber', s:'CBC returned — WBC 23.1 ×10⁹/L (elevated)'},
     {t:'07:20', sev:'ok', s:'IV Ceftriaxone 1g BD + Azithromycin 500mg OD administered'}
   ],
   plan:[
     {l:'Review Chest X-ray result', k:'review'},
     {l:'Repeat SpO₂ — target ≥94%', k:'task'},
     {l:'Sign assessment — severe CAP', k:'task'},
     {l:'Plan discharge for tomorrow', k:'task'}
   ],
   blockers:['Chest X-ray awaiting review']},
  {mrn:'AMX-000009', bed:'4A-02', admitted:'20 Aug 2026', days:0, status:'new', trajectory:'Stable',
   reason:'Chest pain — observation, hypertension', oxygen:'Room air',
   note:'Observation for hypertensive urgency — BP improving on Amlodipine',
   overnight:[
     {t:'05:00', sev:'amber', s:'BP 148/92 — Amlodipine 5mg given'},
     {t:'06:10', sev:'ok', s:'ECG — no ischaemic changes'},
     {t:'07:20', sev:'ok', s:'Troponin — negative'}
   ],
   plan:[
     {l:'Review ECG + troponin result', k:'review'},
     {l:'BP 4-hourly — target <140/90', k:'task'},
     {l:'Begin admission workflow — Ward 4A', k:'admit'},
     {l:'Cardiac review if pain recurs', k:'task'}
   ],
   blockers:['Observation — repeat troponin at 12h']},
  {mrn:'AMX-000003', bed:'4A-05', admitted:'19 Aug 2026', days:2, status:'stable', trajectory:'Improving',
   reason:'Diabetic ketoacidosis — hyperglycaemia', oxygen:'Room air',
   note:'Insulin titrated overnight — glucose trending down',
   overnight:[
     {t:'05:20', sev:'ok', s:'RBS 14.2 → 11.4 mmol/L — insulin adjusted'},
     {t:'06:40', sev:'amber', s:'Fasting glucose 11.4 — above target'},
     {t:'07:10', sev:'ok', s:'IV 0.9% saline running'}
   ],
   plan:[
     {l:'Titrate insulin — review RBS 4-hourly', k:'task'},
     {l:'Repeat fasting glucose (AM)', k:'order'},
     {l:'Diabetes education — meal plan', k:'task'}
   ],
   blockers:['Fasting glucose 11.4 mmol/L — above target']},
  {mrn:'AMX-000004', bed:'4A-09', admitted:'19 Aug 2026', days:2, status:'attention', trajectory:'Improving',
   reason:'Asthma exacerbation — wheeze', oxygen:'O₂ 2 L/min as needed',
   note:'Responding to nebulisation — still mild distress',
   overnight:[
     {t:'04:10', sev:'amber', s:'Salbutamol neb given — SpO₂ 94%'},
     {t:'06:30', sev:'amber', s:'Peak flow 210 L/min — low'},
     {t:'07:15', sev:'ok', s:'Prednisolone 40mg given'}
   ],
   plan:[
     {l:'Reassess peak flow in 2h', k:'task'},
     {l:'Continue nebulisation 4-hourly', k:'task'},
     {l:'Review prednisolone course', k:'task'}
   ],
   blockers:['SpO₂ 94% — reassess in 2h']},
  {mrn:'AMX-000006', bed:'4A-11', admitted:'18 Aug 2026', days:3, status:'stable', trajectory:'Improving',
   reason:'COPD exacerbation', oxygen:'Room air',
   note:'Breathing comfortable — off oxygen since yesterday',
   overnight:[
     {t:'02:50', sev:'ok', s:'SpO₂ 94% on room air — stable'},
     {t:'06:20', sev:'ok', s:'Salbutamol neb given'},
     {t:'07:40', sev:'ok', s:'Prednisolone 30mg given'}
   ],
   plan:[
     {l:'Complete discharge summary', k:'task'},
     {l:'Confirm follow-up — chronic care clinic', k:'task'},
     {l:'Patient education — inhaler technique', k:'task'},
     {l:'Plan discharge today', k:'review'}
   ],
   blockers:[]}
];

/* Connected order collection — order → result → interpretation → timeline.
   status: ordered → resulted → reviewed (reviewed = clinician has acted
   on the result and the interpretation has been recorded). */
const ORDERS = [
  {id:'ORD-000501', mrn:'AMX-000001', type:'Radiology', item:'Chest X-ray — repeat (PA)', status:'resulted', abnormal:false, reviewed:false,
   result:'Interval improvement — right lower lobe consolidation resolving', source:'Ward round · 19 Aug', created:'19 Aug 2026 08:05'},
  {id:'ORD-000502', mrn:'AMX-000001', type:'Laboratory', item:'Repeat WBC + CRP at 48h', status:'resulted', abnormal:false, reviewed:false,
   result:'WBC 18.2 ×10⁹/L (falling) · CRP 96 mg/L (trending down)', source:'Ward round · 19 Aug', created:'19 Aug 2026 08:05'},
  {id:'ORD-000503', mrn:'AMX-000003', type:'Laboratory', item:'Fasting glucose + pre-meal RBS', status:'resulted', abnormal:true, reviewed:false,
   result:'Fasting 11.4 mmol/L · pre-lunch 13.1 mmol/L (elevated)', source:'Ward · 20 Aug', created:'20 Aug 2026 06:30'},
  {id:'ORD-000504', mrn:'AMX-000004', type:'Laboratory', item:'Peak flow + SpO₂ monitor', status:'ordered', abnormal:false, reviewed:false,
   result:'', source:'Ward · 20 Aug', created:'20 Aug 2026 07:00'},
  {id:'ORD-000505', mrn:'AMX-000009', type:'Cardiology', item:'ECG + troponin (repeat at 12h)', status:'resulted', abnormal:false, reviewed:false,
   result:'ECG — no ischaemic changes · Troponin — negative', source:'Ward 4A · 20 Aug', created:'20 Aug 2026 06:10'},
  {id:'ORD-000506', mrn:'AMX-000014', type:'Radiology', item:'X-ray wrist — orthopaedic review', status:'resulted', abnormal:false, reviewed:false,
   result:'No fracture seen', source:'Consultation · 18 Aug', created:'18 Aug 2026 16:30'}
];

/* General OPD clinic queue — the consultation entry point. */
const CLINIC_QUEUE = [
  {mrn:'AMX-000002', enc:'ENC-000146', cc:'Headache for 2 days', prio:'med', wait:'18 min', since:'Last visit 5 Aug 2026 — ANC booking'},
  {mrn:'AMX-000010', enc:null, cc:'Abdominal pain', prio:'med', wait:'14 min', since:'No prior visit at this facility'},
  {mrn:'AMX-000013', enc:null, cc:'Diabetes follow-up', prio:'low', wait:'9 min', since:'Last visit 30 Jul 2026 — chronic care'},
  {mrn:'AMX-000007', enc:'ENC-000141', cc:'Wound review — left hand', prio:'low', wait:'5 min', since:'Laceration 18 Aug 2026 — casualty'},
  {mrn:'AMX-000011', enc:null, cc:'Pregnancy check — 30 weeks', prio:'med', wait:'22 min', since:'Last ANC 15 Aug 2026'}
];

window.WARD_4A = WARD_4A; window.ORDERS = ORDERS; window.CLINIC_QUEUE = CLINIC_QUEUE;

/* ---------- OS HELPERS ---------- */
const osNow = ()=>new Date().toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'});
const osToday = ()=>new Date().toLocaleDateString('en-GB',{weekday:'short',day:'numeric',month:'short',year:'numeric'});
const INV_LABELS = {cbc:'Full blood count', crp:'C-reactive protein', cxr:'Chest X-ray'};
const tlPush = (mrn, title, detail)=>{
  TIMELINE.unshift({mrn, date:osToday(), time:osNow(), type:'Clinical', title, detail, icon:'M12 8v5l3 2'});
};
const roundStats = ()=>({ total:WARD_4A.length, seen:WARD_4A.filter(r=>r.seen).length });
const pendingResults = ()=>ORDERS.filter(o=>o.status==='resulted' && !o.reviewed);
const openOrders = ()=>ORDERS.filter(o=>o.status==='ordered');
const rosterStatus = r => r.status==='attention'?['red','Attention'] : r.status==='new'?['amber','New'] : ['green','Stable'];
const roverDot = o => o.sev==='red'?'dot-red' : o.sev==='amber'?'dot-amber' : 'dot-green';

const handoverBuckets = ()=>{
  const high=[], nb=[], pending=[], dc=[];
  WARD_4A.forEach(r=>{
    const redNight=(r.overnight||[]).some(o=>o.sev==='red');
    if(r.status==='attention' && redNight) high.push({mrn:r.mrn, bed:r.bed, line:r.note||r.reason, tag:r.reason});
    else if(r.status==='new' || (r.days||0)<=1) nb.push({mrn:r.mrn, bed:r.bed, line:'Admitted '+r.admitted+' — '+r.reason, tag:'New'});
    else if(r.blockers && r.blockers.length) pending.push({mrn:r.mrn, bed:r.bed, line:r.blockers[0], tag:'Pending'});
    else if(r.trajectory==='Improving') dc.push({mrn:r.mrn, bed:r.bed, line:'Clinically improving — assess for discharge', tag:'Discharge possible'});
  });
  high.push({mrn:'AMX-000008', bed:'Casualty', line:'Severe pneumonia — SpO₂ 84%, RR 68, chest indrawing', tag:'Escalate to senior'});
  return {high, nb, pending, dc};
};

/* ---------- SHARED COMPONENTS ---------- */
/* Universal patient context header — the persistent patient identity strip
   every clinical workspace shows before any content. */
function clContext(p, extra){
  const alerts = p.allergies.length
    ? `<span class="ctx-alert" title="Allergy"><b>⚠</b> ${p.allergies.join(', ')}</span>` : '';
  const encNow = ENCOUNTERS.find(x=>x.mrn===p.mrn && x.status!=='Completed');
  return `
  <div class="cl-context">
    <div class="cl-av" style="background:${p.color}">${p.avat}</div>
    <div class="grow">
      <div class="row gap2 wrap">
        <b style="font-size:var(--md)">${p.name}</b>
        <span class="badge badge-gray">${p.sex} ${p.ageLabel||(p.age+' yrs')}</span>
        <span class="badge badge-sky mono">${p.mrn}</span>
        <span class="badge badge-green mono">${p.blood}</span>
        ${alerts}
      </div>
      <div class="row gap2 small muted wrap mt1">${extra||''}${encNow?`<span>Current: <b>${encNow.id}</b> · ${ccText()||encNow.cc}</span>`:''}</div>
    </div>
    <div class="row gap1 wrap">
      <button class="btn btn-outline btn-sm" onclick="go('patient')">Record</button>
      <button class="btn btn-primary btn-sm" onclick="go('encounter')">Encounter</button>
    </div>
  </div>`;
}

/* Problem chips — known conditions + the signed diagnosis. */
function clProblems(p){
  const list=[...(p.conditions||[])].map(c=>`<span class="chip">${c}</span>`);
  if(S.dx) list.unshift(`<span class="chip active" title="Assessment · ICD-11 ${S.dxCode||'—'}">${S.dx}${S.dxCode?' · '+S.dxCode:''}</span>`);
  return list.length? list.join('') : '<span class="muted small">No active problems documented.</span>';
}

/* Order lifecycle chip — ordered → resulted → reviewed. */
function orderChip(o){
  if(o.status==='reviewed') return `<span class="badge badge-green">Reviewed</span>`;
  if(o.status==='resulted') return `<span class="badge ${o.abnormal?'badge-red':'badge-amber'}">${o.abnormal?'Abnormal':'Result ready'}</span>`;
  return `<span class="badge badge-gray">Ordered</span>`;
}

/* ---------- CLINICIAN HOME ---------- */
function renderClinicianHome(){
  const roleObj=ROLES.find(r=>r.id===S.role)||{def:'Dr. Brian Kamau'};
  const facObj = FACILITIES.find(f=>f.id===S.facility);
  const rs=roundStats(), queue=CLINIC_QUEUE.length, tasks=tasksPending(), over=tasksOverdue();
  const res=pendingResults();
  const cs=computeClinicalState();
  const hour=new Date().getHours();
  const greeting = hour<12?'Good morning':hour<17?'Good afternoon':'Good evening';

  /* Clinical attention — three buckets: Critical / Review / Pending */
  const critical=[];
  (cs.safety||[]).slice(0,2).forEach(s=>critical.push({label:s.text, note:'Current patient · '+s.src, go:'encounter'}));
  WARD_4A.filter(r=>r.status==='attention').forEach(r=>critical.push({label:P(r.mrn).name+' — '+r.reason, note:'Ward 4A · '+r.bed+' · '+r.note, go:'round'}));
  const criticalRow = it=>`<button class="att-item" onclick="go('${it.go}')"><b>${it.label}</b><span class="small muted">${it.note}</span><span class="muted">›</span></button>`;

  const review=[];
  res.forEach(o=>review.push({label:o.item, note:P(o.mrn).name+' · '+o.result, go:'results'}));
  ['CBC','CRP','Chest X-ray'].filter(t=>!S.reviewed[{CBC:'cbc',CRP:'crp','Chest X-ray':'cxr'}[t]] && !!S.inv[{CBC:'cbc',CRP:'crp','Chest X-ray':'cxr'}[t]])
    .forEach(t=>review.push({label:t+' result to review', note:S.patient.name+' · encounter '+S.encounter.id, go:'results'}));

  const pending=[];
  tasks.slice(0,3).forEach(t=>pending.push({label:t.label, note:t.cat+' · '+t.due, go:t.go}));
  if(S.ccs.length && hpiPending().length) pending.push({label:'Answer '+hpiPending().length+' high-priority HPI question'+(hpiPending().length>1?'s':''), note:S.patient.name+' · clinical picture', go:'encounter'});
  pending.push({label:queue+' waiting in General OPD clinic', note:'Consultation queue · today', go:'clinic'});

  const bucket = (title,color,items)=>`
    <div class="card os-bucket">
      <div class="card-h"><h3>${title}</h3><span class="badge badge-sky" style="background:${color};color:#fff">${items.length}</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">${items.length?items.map(criticalRow).join(''):'<div class="empty" style="padding:var(--sp3)"><p>Nothing here right now.</p></div>'}</div>
    </div>`;

  return `
    <div class="row-b wrap mb4">
      <div>
        <h1 style="font-size:var(--2xl)">${greeting}, ${roleObj.def}</h1>
        <p class="muted">${facObj ? facObj.name : 'Facility'} · ${osToday()} · Ward 4A round ${rs.seen}/${rs.total} seen</p>
      </div>
      <div class="row gap2 wrap">
        <span class="chip green"><span class="dot dot-green"></span>System operational</span>
        <span class="chip ${rs.seen===rs.total?'green':'amber'}"><span class="dot ${rs.seen===rs.total?'dot-green':'dot-amber'}"></span>Daily ward round ${rs.seen===rs.total?'complete':'in progress'}</span>
      </div>
    </div>

    <div class="grid cols-3 mb4">
      <div class="card dash-card dash-mywork">
        <div class="card-h"><h3>Ward 4A — Daily round</h3><span class="badge badge-sky">${rs.seen}/${rs.total}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="qdots mb3">${WARD_4A.map((r,i)=>`<span class="${r.seen?'on':''} ${i===S.roundIdx?'cur':''}" title="${P(r.mrn).name}"></span>`).join('')}</div>
          <div class="small muted mb1">${rs.total-rs.seen} patient${rs.total-rs.seen>1?'s':''} remaining · ${res.length} result${res.length>1?'s':''} to review</div>
          <button class="btn btn-primary btn-block" onclick="go('round')">${rs.seen? 'Continue daily round →':'Start daily round →'}</button>
        </div>
      </div>
      <div class="card dash-card">
        <div class="card-h"><h3>Clinic — General OPD</h3><span class="badge badge-sky">${queue} waiting</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="small muted mb3">${queue? 'Patients checked in and waiting for consultation today.':'The clinic queue is clear.'}</div>
          <button class="btn btn-outline btn-block" onclick="go('clinic')">Open clinic queue →</button>
        </div>
      </div>
      <div class="card dash-card dash-urgent">
        <div class="card-h"><h3>My tasks</h3><span class="badge ${over.length?'badge-red':'badge-sky'}">${tasks.length} pending</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="small muted mb3">${over.length? over.slice(0,2).map(t=>t.label).join(' · ') : 'Nothing overdue — the task engine surfaces what needs you next.'}</div>
          <button class="btn btn-outline btn-block" onclick="go('tasks')">Open tasks →</button>
        </div>
      </div>
    </div>

    ${S.encounter?`<div class="next-strip mb4"><span class="badge badge-sky" style="flex-shrink:0">CONTINUE</span>
      <span><b>Encounter ${S.encounter.id} — ${S.patient.name}</b> · ${ENC_STEPS[Math.min(S.step,ENC_STEPS.length-1)]} · the system knows the next useful action.</span>
      <button class="btn btn-primary btn-sm" onclick="go('encounter')">Continue workspace →</button></div>`:''}

    <div class="grid split3">
      <div class="stack gap4">
        <div>${bucket('Clinical attention — critical', '#dc2626', critical)}</div>
        <div>${bucket('Results to review', '#7c3aed', review)}</div>
        <div>${bucket('Pending work', '#0284c7', pending)}</div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Clinical state — ${S.patient.name}</h3><span class="badge badge-sky" id="statePill">live</span></div>
        <div class="card-body" id="clinicalPanel"></div>
      </div>
    </div>`;
}

/* ---------- WARD SCREEN ---------- */
function renderWardScreen(){
  const res=pendingResults(), hb=handoverBuckets();
  const kpis=[
    {icon:'bed', label:'Patients on ward', val:WARD_4A.length, sub:'4A · General Medical'},
    {icon:'alert', label:'High risk', val:WARD_4A.filter(r=>r.status==='attention').length, sub:'attention flag', tone:'red'},
    {icon:'lab', label:'Results to review', val:res.length, sub:res.length?'ordered → resulted → reviewed':'all clear', tone:'violet'},
    {icon:'check', label:'Discharge possible', val:hb.dc.length, sub:'trajectory improving', tone:'green'}
  ];
  const row=r=>{
    const st=rosterStatus(r);
    return `<tr onclick="roundSelect(${WARD_4A.indexOf(r)})">
      <td><b>${P(r.mrn).name}</b><div class="small muted">${P(r.mrn).sex} ${P(r.mrn).age}y · ${r.mrn}</div></td>
      <td><span class="mono small">${r.bed}</span></td>
      <td><span class="badge badge-${st[0]==='red'?'red':st[0]==='amber'?'amber':'green'}">${st[1]}</span></td>
      <td class="small">${r.trajectory}</td>
      <td class="small">${r.admitted} <div class="muted tiny">day ${r.days}</div></td>
      <td class="small">${r.reason}</td>
      <td>${r.seen?'<span class="badge badge-green">Seen</span>':'<span class="badge badge-gray">Not seen</span>'}</td>
      <td class="mono small">›</td>
    </tr>`;
  };
  return `
    <div class="row-b wrap mb4">
      <div>
        <h1>Ward 4A — General Medical</h1>
        <p class="muted">${osToday()} · ${WARD_4A.length} patients · census sync live</p>
      </div>
      <div class="row gap2 wrap">
        <button class="btn btn-primary" onclick="go('round')">Start daily round →</button>
        <button class="btn btn-outline" onclick="go('handover')">Handover board →</button>
      </div>
    </div>

    <div class="grid cols-4 mb4">
      ${kpis.map(k=>`<div class="card kpi"><div class="kpi-icon ${k.tone?k.tone:''}">${k.icon}</div><div><b style="font-size:var(--xl)">${k.val}</b><div class="small muted">${k.label}</div><div class="tiny muted">${k.sub}</div></div></div>`).join('')}
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Patient census — ${WARD_4A.length} on ward</h3><span class="badge badge-sky">tap a patient to open their workspace</span></div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Patient</th><th>Bed</th><th>Status</th><th>Trajectory</th><th>Admitted</th><th>Admission reason</th><th>Round</th><th></th></tr></thead>
          <tbody>${WARD_4A.map(row).join('')}</tbody>
        </table>
      </div>
    </div>

    <div class="grid split2">
      <div class="card">
        <div class="card-h"><h3>Handover — HIGH RISK</h3><span class="badge badge-red">${hb.high.length}</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          ${hb.high.length?hb.high.map(it=>`
            <div class="hb-item"><div class="row gap2"><span class="dot dot-red"></span><b>${it.tag}</b><span class="badge badge-gray mono">${it.bed}</span></div>
            <div class="small muted mt1">${it.line}</div></div>`).join(''):'<div class="empty"><p>Nothing flagged high risk.</p></div>'}
          <button class="btn btn-outline btn-block" style="margin-top:var(--sp3)" onclick="go('handover')">Open full handover board →</button>
        </div>
      </div>
      <div class="card">
        <div class="card-h"><h3>Ward actions</h3></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="att-group">
            <button class="att-item" onclick="go('round')"><b>Daily ward round</b><span class="small muted">${roundStats().seen} seen · SAVE &amp; NEXT flow</span><span>›</span></button>
            <button class="att-item" onclick="go('results')"><b>Results inbox</b><span class="small muted">${res.length} result${res.length>1?'s':''} awaiting review</span><span>›</span></button>
            <button class="att-item" onclick="go('clinic')"><b>OPD clinic queue</b><span class="small muted">${CLINIC_QUEUE.length} waiting</span><span>›</span></button>
            <button class="att-item" onclick="showAdmissionFlow()"><b>Admit a patient</b><span class="small muted">New admission workflow — Ward 4A</span><span>›</span></button>
          </div>
        </div>
      </div>
    </div>`;
}

/* ---------- ROUND ACTIONS ---------- */
function roundSelect(i){
  S.roundIdx=i;
  const r=WARD_4A[i];
  if(r) selectPatient(r.mrn);
  go('round');
}
function roundTogglePlan(l){
  const r=WARD_4A[S.roundIdx];
  if(!r) return;
  if(!r.planChecked) r.planChecked={};
  r.planChecked[l]=!r.planChecked[l];
  renderScreen('round');
}
function roundAddPlan(){
  const r=WARD_4A[S.roundIdx];
  if(!r) return;
  const l=(document.getElementById('newPlanInput')||{}).value||'';
  if(!l.trim()) return;
  r.plan.push({l:l.trim(), k:'task'});
  if(!r.planChecked) r.planChecked={};
  r.planChecked[l.trim()]=true;
  renderScreen('round');
}
function roundSetAll(){
  const r=WARD_4A[S.roundIdx];
  if(!r) return;
  r.planChecked={};
  r.plan.forEach(p=>r.planChecked[p.l]=true);
  renderScreen('round');
}
/* Commit a patient's checked plan → connected consequences, then NEXT. */
function roundNext(){
  const r=WARD_4A[S.roundIdx];
  if(!r) return;
  const p=P(r.mrn);
  const checked=(r.plan||[]).filter(x=>r.planChecked && r.planChecked[x.l]);

  checked.forEach(item=>{
    if(item.k==='review'){
      TASKS.push({id:taskId(), label:item.l, cat:'Results', due:'today', prio:'high', mrn:r.mrn, go:'results'});
      tlPush(r.mrn, 'Sent to results review', item.l);
    } else if(item.k==='task'){
      TASKS.push({id:taskId(), label:item.l, cat:'Clinical', due:'today', prio:'med', mrn:r.mrn, go:'round'});
      tlPush(r.mrn, 'Clinical task queued', item.l);
    } else if(item.k==='order'){
      ORDERS.push({id:ordId(), mrn:r.mrn, type:'Laboratory', item:item.l, status:'ordered', abnormal:false, reviewed:false, result:'', source:'Ward round · '+osToday(), created:osToday()+' '+osNow()});
      tlPush(r.mrn, 'Order sent to laboratory', item.l);
    }
  });
  if(r.plan.some(x=>x.k==='admit' && r.planChecked && r.planChecked[x.l])){
    const task=TASKS.find(t=>t.mrn===r.mrn && t.cat==='Clinical' && /admission/i.test(t.label));
    if(!task){ TASKS.push({id:taskId(), label:'Complete admission — '+r.reason, cat:'Clinical', due:'today', prio:'high', mrn:r.mrn, go:'round'}); }
  }
  r.seen=true;
  tlPush(r.mrn, 'Daily round completed', checked.length+' plan items committed');
  if(S.patient && S.patient.mrn===r.mrn) saveEnc();

  /* advance to next unseen patient */
  const next=WARD_4A.findIndex((x,i)=>i!==S.roundIdx && !x.seen);
  if(next!==-1){ S.roundIdx=next; selectPatient(WARD_4A[next].mrn); }
  renderScreen('round');
}

/* ---------- ROUND SCREEN ---------- */
function renderRoundScreen(){
  const rs=roundStats();
  if(rs.seen===rs.total){
    return `
      <div class="card" style="max-width:640px;margin:8vh auto;text-align:center">
        <div style="font-size:56px;line-height:1">✓</div>
        <h1 style="font-size:var(--xl)" class="mt1">Daily ward round complete</h1>
        <p class="muted mt1">All ${rs.total} patients on Ward 4A have been reviewed today. The handover board reflects the current state.</p>
        <div class="row gap2 center wrap mt4">
          <button class="btn btn-outline" onclick="go('handover')">Handover board →</button>
          <button class="btn btn-outline" onclick="go('results')">Results inbox →</button>
          <button class="btn btn-primary" onclick="go('clinic')">Start clinic →</button>
        </div>
      </div>`;
  }

  const r=WARD_4A[S.roundIdx], p=P(r.mrn);
  const st=rosterStatus(r);
  const qdot = (i,row)=>`<button class="qdot-btn ${i===S.roundIdx?'cur':''} ${row.seen?'on':''}" onclick="roundSelect(${i})" title="${P(row.mrn).name}">${i+1}</button>`;
  const overnight=(r.overnight||[]).map(o=>`<div class="overnight"><div class="row gap2"><span class="dot ${roverDot(o)}"></span><span class="mono small muted">${o.t}</span></div><div class="small">${o.s}</div></div>`).join('');
  const invRow=k=>{
    const v=S.inv&&S.inv[k], label=INV_LABELS[k]||k;
    return `<div class="check ${v?'checked':''}"><span>${label}</span><span class="mono small muted">${v||'not recorded'}</span></div>`;
  };
  const planned=(r.plan||[]).map(x=>{
    const ch=!!(r.planChecked&&r.planChecked[x.l]);
    return `<label class="check ${ch?'checked':''}"><input type="checkbox" onchange="roundTogglePlan(${JSON.stringify(x.l)})" ${ch?'checked':''}><span>${x.l}</span><span class="badge ${x.k==='review'?'badge-violet':x.k==='order'?'badge-sky':'badge-gray'} tiny">${x.k}</span></label>`;
  }).join('');
  const cs=computeClinicalState();
  const railSafety=(cs.safety||[]).map(s=>`<div class="safety-item"><span class="dot dot-red"></span><div><b>${s.text}</b><span class="tiny muted"> · ${s.src}</span></div></div>`).join('');
  const railGaps=(cs.gaps||[]).map(g=>`<div class="gap-item" style="border-left-color:${g.prio==='HIGH'?'#dc2626':g.prio==='MED'?'#d97706':'#64748b'}"><span class="badge ${g.prio==='HIGH'?'badge-red':g.prio==='MED'?'badge-amber':'badge-gray'}">${g.prio}</span><div class="grow"><b>${g.label}</b><p class="tiny muted">${g.reason}</p></div></div>`).join('');
  const railNext=cs.next?`<div class="fact"><div class="fc" style="background:var(--primary-light);color:var(--primary)">→</div><div><b>${cs.next.label}</b><p>${cs.next.detail}</p></div></div>`:'';

  return `
    <div class="row-b wrap mb3">
      <div>
        <h1>Daily Ward Round — Ward 4A</h1>
        <p class="muted">${osToday()} · ${rs.seen}/${rs.total} seen · working ${r.bed} · ${P(r.mrn).name}</p>
      </div>
      <div class="row gap2 wrap">
        <span class="chip ${st[0]==='red'?'red':st[0]==='amber'?'amber':'green'}"><span class="dot ${roverDot(r)}"></span>${st[1]} · ${r.trajectory}</span>
        <button class="btn btn-outline btn-sm" onclick="go('handover')">Handover</button>
        <button class="btn btn-primary" onclick="roundNext()">${rs.seen===rs.total-1?'Finish round': (rs.total-rs.seen-1? 'Save & next patient':'Finish round')} →</button>
      </div>
    </div>

    <div class="round-layout">
      <div class="card round-queue">
        <div class="card-h"><h3 class="small" style="text-transform:uppercase;letter-spacing:.06em">Queue</h3><span class="badge badge-sky">${rs.total-rs.seen} left</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="qdots mb3">${WARD_4A.map((row,i)=>qdot(i,row)).join('')}</div>
          <div class="round-names">${WARD_4A.map((row,i)=>`<button class="round-name ${i===S.roundIdx?'cur':''} ${row.seen?'seen':''}" onclick="roundSelect(${i})"><span class="dot ${row.status==='attention'?'dot-red':row.status==='new'?'dot-amber':'dot-green'}"></span>${P(row.mrn).name}<span class="small muted">${row.bed}</span></button>`).join('')}</div>
          <div class="hint small muted mt3">N key → next patient · S → save &amp; sign</div>
        </div>
      </div>

      <div class="stack gap4">
        ${clContext(p, `<span>Bed ${r.bed} · ${r.oxygen}</span><span>Admitted ${r.admitted}</span><span>${r.reason}</span>`)}

        <div class="card">
          <div class="card-h"><h3>Overnight events</h3><span class="badge badge-sky">pre-fetched · ${(r.overnight||[]).length}</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">${overnight||'<div class="empty"><p>No overnight events recorded.</p></div>'}</div>
        </div>

        <div class="card">
          <div class="card-h"><h3>Clinical state</h3><span class="badge badge-green" id="statePill">live</span></div>
          <div class="card-body" id="clinicalPanel"></div>
        </div>

        <div class="card">
          <div class="card-h"><h3>Results</h3><span class="badge badge-sky" onclick="go('results')" style="cursor:pointer">results inbox →</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="stack gap2">
              ${invRow('cbc')}${invRow('crp')}${invRow('cxr')}
              <button class="btn btn-outline btn-sm btn-block" onclick="go('results')">Open results →</button>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="card-h"><h3>Problems</h3></div>
          <div class="card-body" style="padding-top:var(--sp3)"><div class="row gap1 wrap">${clProblems(p)}</div></div>
        </div>

        <div class="card">
          <div class="card-h"><h3>Plan for today</h3>
            <div class="row gap2"><button class="btn btn-outline btn-sm" onclick="roundSetAll()">Select all</button>
            <span class="badge badge-sky">committed on SAVE &amp; NEXT</span></div></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="stack gap2">${planned}</div>
            <div class="row gap2 mt3">
              <input id="newPlanInput" class="inp" placeholder="Add a plan item…" onkeydown="if(event.key==='Enter')roundAddPlan()">
              <button class="btn btn-outline" onclick="roundAddPlan()">Add</button>
            </div>
          </div>
        </div>
      </div>

      <div class="card round-rail">
        <div class="card-h"><h3 class="small" style="text-transform:uppercase;letter-spacing:.06em">Intelligence</h3><span class="badge badge-sky">live</span></div>
        <div class="card-body" id="clinicalPanelRail">
          ${cs.safety&&cs.safety.length?`<div class="cs-section"><div class="cs-title">Safety — ${P(r.mrn).name}</div>${railSafety}</div>`:''}
          ${railNext?`<div class="cs-section"><div class="cs-title">Next best action</div>${railNext}</div>`:''}
          ${railGaps?`<div class="cs-section"><div class="cs-title">Clinical gaps</div>${railGaps}</div>`:'<div class="empty"><p>No open gaps.</p></div>'}
          <div class="hint small muted mt3">Intelligence derives from the live clinical state — facts, gaps, risk and the safety block. S key saves &amp; signs.</div>
        </div>
      </div>
    </div>`;
}

/* ---------- HANDOVER SCREEN ---------- */
function renderHandoverScreen(){
  const hb=handoverBuckets();
  const bucket=(title,items,dot)=>{
    return `<div class="card"><div class="card-h"><h3>${title}</h3><span class="badge ${dot}">${items.length}</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        ${items.length?items.map(it=>`<div class="hb-item">
          <div class="row gap2"><span class="dot ${dot.replace('badge','dot')}"></span><b>${P(it.mrn)?P(it.mrn).name:'Baby A.'}</b><span class="badge badge-gray mono">${it.bed}</span>${it.tag?`<span class="badge badge-sky" style="margin-left:auto">${it.tag}</span>`:''}</div>
          <div class="small muted mt1">${it.line}</div>
          <div class="row gap1 wrap mt2">${WARD_4A.some(r=>r.mrn===it.mrn)?`<button class="btn btn-soft btn-sm" onclick="roundSelect(${WARD_4A.findIndex(r=>r.mrn===it.mrn)});go('round')">Open patient</button>`:`<button class="btn btn-soft btn-sm" onclick="selectPatientMRN('${it.mrn}');go('encounter')">Open patient</button>`}
          <button class="btn btn-ghost btn-sm" onclick="selectPatientMRN('${it.mrn}');go('encounter')">Encounter</button></div>
        </div>`).join(''):'<div class="empty"><p>Nothing here — good news.</p></div>'}
      </div></div>`;
  };
  return `
    <div class="row-b wrap mb4">
      <div>
        <h1>Handover board</h1>
        <p class="muted">${osToday()} · ${osNow()} · built from tonight's round + ward state · for the oncoming team</p>
      </div>
      <div class="row gap2 wrap">
        <button class="btn btn-outline" onclick="go('round')">Daily round →</button>
        <button class="btn btn-primary" onclick="go('clinic')">Clinic →</button>
      </div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Handover summary</h3></div>
      <div class="card-body">
        <p class="small muted">${hb.high.length} HIGH RISK · ${hb.nb.length} new patients · ${hb.pending.length} pending items · ${hb.dc.length} discharge possible · ${roundStats().seen}/${roundStats().total} ward round seen.</p>
        <p class="small muted mt1">Priority rule — <b>HIGH RISK &gt; NEW &gt; PENDING &gt; DISCHARGE POSSIBLE</b>. The handover is derived, never typed: it reflects the live round, results and plan state.</p>
      </div>
    </div>

    <div class="grid cols-2">
      ${bucket('HIGH RISK — review first', hb.high, 'badge-red')}
      ${bucket('New admissions — assess', hb.nb, 'badge-amber')}
      ${bucket('Pending items — resolve', hb.pending, 'badge-sky')}
      ${bucket('Discharge possible — plan today', hb.dc, 'badge-green')}
    </div>`;
}

/* ---------- CLINIC SCREEN ---------- */
let clinicSel=0;
function clinicSelect(i){ clinicSel=i; renderScreen('clinic'); }
function openConsultation(mrn){ selectPatient(mrn); go('encounter'); }

function renderClinicScreen(){
  const sel=CLINIC_QUEUE[clinicSel]||CLINIC_QUEUE[0];
  const p=P(sel.mrn);
  const tl=TIMELINE.filter(t=>t.mrn===sel.mrn).slice().reverse().slice(0,5).map(t=>`<div class="tl-item"><div class="tl-date"><b>${t.time||''}</b><span>${t.date||''}</span></div><div class="tl-content"><b>${t.type}</b><span>${t.title}${t.detail?' — '+t.detail:''}</span></div></div>`).join('');
  const row=q=>`
    <tr class="${q.mrn===sel.mrn?'sel':''}" onclick="clinicSelect(${CLINIC_QUEUE.indexOf(q)})">
      <td><b>${P(q.mrn).name}</b><div class="small muted">${P(q.mrn).sex} ${P(q.mrn).age}y · ${q.mrn}</div></td>
      <td class="small">${q.cc}</td>
      <td><span class="badge ${q.prio==='low'?'badge-green':q.prio==='med'?'badge-amber':'badge-red'}">${q.prio}</span></td>
      <td class="muted small">${q.wait}</td>
      <td class="muted small">${q.since}</td>
    </tr>`;
  return `
    <div class="row-b wrap mb4">
      <div>
        <h1>Clinic — General OPD</h1>
        <p class="muted">${osToday()} · ${CLINIC_QUEUE.length} waiting · queue is live from check-in</p>
      </div>
      <div class="row gap2 wrap">
        <span class="chip green"><span class="dot dot-green"></span>${sel.mrn===P(sel.mrn).mrn?'Consultation ready':''}</span>
      </div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Waiting queue</h3><span class="badge badge-sky">${CLINIC_QUEUE.length} patients</span></div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Patient</th><th>Presenting complaint</th><th>Priority</th><th>Waiting</th><th>History</th></tr></thead>
          <tbody>${CLINIC_QUEUE.map(row).join('')}</tbody>
        </table>
      </div>
    </div>

    <div class="cl-consult card">
      ${clContext(p, `<span>Queue position ${CLINIC_QUEUE.indexOf(sel)+1}</span><span>${sel.cc}</span>`)}
      <div class="card mt3">
        <div class="card-h"><h3>Since last visit</h3><span class="badge badge-sky">pre-fetched timeline</span></div>
        <div class="card-body" style="padding-top:var(--sp3)">${tl||'<div class="empty"><p>No prior visits at this facility.</p></div>'}</div>
      </div>
      <div class="card mt3">
        <div class="card-h"><h3>Consultation workspace</h3></div>
        <div class="card-body" style="padding-top:var(--sp3)">
          <div class="row gap2 wrap">
            <button class="btn btn-primary" onclick="openConsultation('${p.mrn}')">Open consultation →</button>
            <button class="btn btn-outline" onclick="go('encounter')">Patient clinical state →</button>
            <button class="btn btn-outline" onclick="go('results')">Order / review results →</button>
          </div>
          <p class="small muted mt2">The encounter workspace assembles HPI, exam, results, problems and Intelligence for <b>${p.name}</b> — the consultation continues from here.</p>
        </div>
      </div>
    </div>`;
}

/* ---------- RESULTS SCREEN ---------- */
function reviewOrder(id){
  const o=ORDERS.find(x=>x.id===id); if(!o) return;
  o.status='reviewed'; o.reviewed=true;
  const p=P(o.mrn);
  tlPush(o.mrn, o.item+' — result reviewed', o.abnormal?'abnormal — action needed':'normal');
  if(S.patient && S.patient.mrn===o.mrn && o.abnormal) TASKS.push({id:taskId(), label:'Act on '+o.item.toLowerCase()+' — abnormal', cat:'Clinical', due:'today', prio:'high', mrn:o.mrn, go:'encounter'});
  toast('Result reviewed — '+o.item,'ok');
  renderScreen('results');
}
function renderResultsScreen(){
  const res=pendingResults(), open=openOrders();
  const p=S.patient;
  const orderRow=o=>`<tr>
      <td class="mono">${o.id}</td>
      <td><b>${o.item}</b><div class="small muted">${o.type}</div></td>
      <td>${P(o.mrn)?P(o.mrn).name:'—'}</td>
      <td>${orderChip(o)}</td>
      <td class="small muted">${o.result||'Awaiting result'}</td>
      <td class="small muted">${o.created}</td>
      <td>${o.status==='resulted'?`<button class="btn btn-primary btn-sm" onclick="reviewOrder('${o.id}')">Review result</button>`:`<span class="muted small">${o.status==='reviewed'?'Reviewed':'In progress'}</span>`}</td>
    </tr>`;
  return `
    <div class="row-b wrap mb4">
      <div>
        <h1>Results inbox</h1>
        <p class="muted">${osToday()} · ordered → resulted → reviewed · every result traces to its order</p>
      </div>
      <div class="row gap2 wrap">
        <span class="chip ${res.length?'amber':'green'}"><span class="dot ${res.length?'dot-amber':'dot-green'}"></span>${res.length} awaiting review</span>
      </div>
    </div>

    ${res.length?`<div class="card mb4">
      <div class="card-h"><h3>Awaiting your review</h3><span class="badge badge-red">${res.length}</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="stack gap2">${res.map(o=>`<div class="hb-item">
          <div class="row gap2"><span class="dot ${o.abnormal?'dot-red':'dot-amber'}"></span><b>${o.item}</b><span class="badge ${o.abnormal?'badge-red':'badge-amber'}">${o.abnormal?'Abnormal':'Result ready'}</span></div>
          <div class="small muted mt1">${P(o.mrn)?P(o.mrn).name:''} · ${o.result}</div>
          <div class="row gap1 wrap mt2"><button class="btn btn-primary btn-sm" onclick="reviewOrder('${o.id}')">Review &amp; record interpretation</button>
          <button class="btn btn-soft btn-sm" onclick="selectPatient('${o.mrn}');go('encounter')">Open patient</button></div>
        </div>`).join('')}</div>
      </div></div>`:''}

    <div class="card">
      <div class="card-h"><h3>All orders</h3><span class="badge badge-sky">${ORDERS.length}</span></div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Order</th><th>Investigation</th><th>Patient</th><th>Status</th><th>Result</th><th>Created</th><th></th></tr></thead>
          <tbody>${ORDERS.map(orderRow).join('')}</tbody>
        </table>
      </div>
    </div>`;
}

/* ---------- DISCHARGE SCREEN ---------- */
let dcCheck={clinical:false,results:false,plan:false,summary:false,edu:false,follow:false};
const dcItems=[
  {k:'clinical', label:'Clinical review complete — stable, off oxygen'},
  {k:'results', label:'Pending results reviewed / acknowledged'},
  {k:'plan', label:'Discharge plan + follow-up set'},
  {k:'summary', label:'Discharge summary drafted'},
  {k:'edu', label:'Patient education — medication & red flags'},
  {k:'follow', label:'Follow-up appointment booked'}
];
function dcToggle(k){ dcCheck[k]=!dcCheck[k]; renderScreen('discharge'); }
function dcApprove(){
  const r=WARD_4A.find(x=>x.mrn===(S.patient?S.patient.mrn:''));
  tlPush(S.patient?S.patient.mrn:'', 'Discharge approved', r?('from '+r.bed+' — Ward 4A'):'');
  toast('Discharge approved — documentation queued','ok');
  go('handover');
}
function renderDischargeScreen(){
  const p=S.patient;
  const r=WARD_4A.find(x=>x.mrn===p.mrn);
  const done=dcItems.filter(i=>dcCheck[i.k]).length;
  const ready=done===dcItems.length;
  return `
    <div class="row-b wrap mb4">
      <div>
        <h1>Discharge — ${p.name}</h1>
        <p class="muted">${r?'Ward 4A · '+r.bed+' · admitted '+r.admitted:'Outpatient'} · readiness checklist derived from the clinical state</p>
      </div>
      <div class="row gap2 wrap">
        <span class="chip ${ready?'green':'amber'}"><span class="dot ${ready?'dot-green':'dot-amber'}"></span>${done}/${dcItems.length} ready</span>
      </div>
    </div>

    <div class="card mb4">
      <div class="card-h"><h3>Discharge readiness checklist</h3><span class="badge badge-sky">one patient, one safe discharge</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="stack gap2">${dcItems.map(i=>`<label class="check ${dcCheck[i.k]?'checked':''}"><input type="checkbox" onchange="dcToggle('${i.k}')" ${dcCheck[i.k]?'checked':''}><span>${i.label}</span></label>`).join('')}</div>
        <div class="row gap2 mt4">
          <button class="btn btn-outline" onclick="go('round')">Back to round</button>
          <button class="btn btn-primary" ${ready?'':'disabled'} onclick="dcApprove()">Approve discharge →</button>
        </div>
        ${ready?'<p class="small muted mt2">All checks complete — discharge can be approved safely.</p>':`<p class="small muted mt2">${dcItems.length-done} item${dcItems.length-done>1?'s':''} remaining before discharge can be approved.</p>`}
      </div>
    </div>

    <div class="card">
      <div class="card-h"><h3>Discharge summary</h3><span class="badge badge-sky">drafted by the documentation engine</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <p class="small muted">Admission: ${r?r.reason:'—'} · Trajectory: ${r?r.trajectory:'—'} · Plan: ${S.dx||'assessment signed in encounter'}</p>
        <div class="row gap2 wrap mt3">
          <button class="btn btn-outline btn-sm" onclick="renderDoc('note')">Preview summary →</button>
          <button class="btn btn-outline btn-sm" onclick="go('documents')">Documents →</button>
        </div>
      </div>
    </div>`;
}

/* ---------- ADMISSION FLOW ---------- */
let admCheck={id:true,ward:true,risk:true,plan:true,edu:false};
const admItems=[
  {k:'id', label:'Patient identified — demographics verified'},
  {k:'ward', label:'Ward allocated — Ward 4A General Medical'},
  {k:'risk', label:'Risk & observation plan set'},
  {k:'plan', label:'Admission plan — diagnosis & treatment'},
  {k:'edu', label:'Consent + information given'}
];
function showAdmissionFlow(){ renderAdmissionFlow(); }
function admToggle(k){ admCheck[k]=!admCheck[k]; renderAdmissionFlow(); }
function admConfirm(){
  const r=WARD_4A.find(x=>x.status==='new' && !x.seen);
  const mrn=r?r.mrn:(S.patient?S.patient.mrn:'AMX-000009');
  tlPush(mrn, 'Admission workflow completed', P(mrn).name+' admitted to Ward 4A');
  toast('Admission confirmed — '+P(mrn).name,'ok');
  renderScreen('ward');
}
function renderAdmissionFlow(){
  const mrn=(S.patient?S.patient.mrn:'AMX-000009');
  const p=P(mrn);
  const done=admItems.filter(i=>admCheck[i.k]).length;
  $('modalBox').innerHTML=`<div class="modal-h"><h3>New admission — ${p.name}</h3><button class="btn btn-icon" onclick="closeModal()"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
    <div class="modal-b">
      ${clContext(p, `<span>${p.mrn} · ${p.sex} ${p.age}y</span>`)}
      <div class="stack gap2 mt3">${admItems.map(i=>`<label class="check ${admCheck[i.k]?'checked':''}"><input type="checkbox" onchange="admToggle('${i.k}')" ${admCheck[i.k]?'checked':''}><span>${i.label}</span></label>`).join('')}</div>
    </div>
    <div class="modal-f">
      <button class="btn btn-outline" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" ${done===admItems.length?'':'disabled'} onclick="closeModal();admConfirm()">Confirm admission →</button>
    </div>`;
  $('modalOv').classList.add('show');
}

/* ---------- ID HELPERS ---------- */
function taskId(){ return 'T'+(1+Object.keys(S.tasksDone).length+TASKS.length); }
function ordId(){ return 'ORD-'+String(1000+ORDERS.length); }

/* ---------- KEYBOARD SHORTCUTS ---------- */
/* N → next patient in the round · R → results · M → pharmacy
   P → patients · O → round · T → tasks · S → save & sign */
function clinicianKey(e){
  const t=(e.target||{}).tagName||'';
  if(t==='INPUT'||t==='TEXTAREA'||t==='SELECT') return;
  const k=(e.key||'').toLowerCase();
  const map={n:()=>{ if(S.screen==='round') roundNext(); }, r:()=>go('results'), m:()=>go('pharmacy'), p:()=>go('patients'), o:()=>go('round'), t:()=>go('tasks'), s:()=>{ if(S.encounter) saveEnc(); toast('Encounter saved','ok'); }};
  if(map[k]) map[k]();
}
document.addEventListener('keydown', clinicianKey);
window.clinicianKey = clinicianKey;