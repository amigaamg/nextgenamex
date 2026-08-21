/* ---------- COMMAND CENTER HELPERS ---------- */
function updateCommandCenter(){ if(S.screen==='dashboard') renderScreen('dashboard'); }
function dashCardHead(title,badge,cls=''){
  return `<div class="card-h"><h3>${title}</h3>${badge||''}</div>`;
}
function dashNextPatient(nextE,nextP){
  const triage = nextE && nextE.urgent ? '<span class="badge badge-red">Urgent</span>' : '<span class="badge badge-amber">Waiting</span>';
  return `
    <div class="card-h"><h3>Next patient</h3><span class="badge badge-sky">QUEUE</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      ${nextE?`
        <div class="row gap3 wrap"><div style="width:44px;height:44px;border-radius:12px;background:${nextP.color};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:17px;flex-shrink:0">${nextP.avat}</div>
        <div class="grow"><b style="font-size:var(--md)">${nextP.name}</b><div class="small muted">${nextP.sex} ${nextP.ageLabel||(nextP.age+' yrs')} · ${nextE.id}</div></div>${triage}</div>
        <div class="row-b mt3" style="padding:10px 0;border-top:1px solid var(--neutral-100)"><span class="muted">Presenting concern</span><b>${nextE.cc}</b></div>
        <button class="btn btn-primary btn-block mt3" onclick="selectPatient('${nextE.mrn}');go('encounter')">Open encounter →</button>`
      :`<div class="empty" style="padding:var(--sp4)"><p>Queue is clear.</p></div>`}
    </div>`;
}
function dashAttention(urgent,urgentP){
  const items=[];
  if(urgent && urgentP) items.push({label:urgentP.name, tag:urgentP.mrn==='AMX-000008'?'SpO₂ 84% · severe':(urgent.cc||'urgent'), mrn:urgent.mrn, urgent:true, note:'Respiratory distress — immediate review'});
  if(S.role!=='pharmacy') items.push({label:'Referral pending — James Mwangi', tag:'ENC-000148', mrn:'AMX-000014', note:'Orthopaedics → Kenyatta County Hospital', med:'ref'});
  const pendingCount=items.length;
  return `
    <div class="card-h"><h3>Attention required</h3><span class="badge badge-red">${pendingCount}</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      ${items.map(it=>`
        <div class="fact flag"><div class="fc"><svg class="ic" viewBox="0 0 24 24"><path d="M12 9v5M12 17h.01"/></svg></div>
        <div><b>${it.label}${it.urgent?' <span class="badge badge-red">URGENT</span>':''}</b><p>${it.note}${it.tag?' · <span class="mono">'+it.tag+'</span>':''}</p></div></div>`).join('')}
        <button class="btn btn-outline btn-block mt3" onclick="go('encounter')">Open urgent encounter</button>
    </div>`;
}
function renderDashClinicalWork(){
  const pt=S.patient, en=S.encounter;
  const pending={CBC:!S.reviewed.cbc,CRP:!S.reviewed.crp,'Chest X-ray':!S.reviewed.cxr};
  const pendingN=Object.values(pending).filter(Boolean).length;
  const nextAction = S.step<8 ? `Complete ${ENC_STEPS[S.step]} for ${pt.name}` : 'Close the current encounter';
  return `
    <div class="card-h"><h3>My work</h3><span class="badge badge-sky">${pendingN?pendingN+' to review':'Clear'}</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      <div class="row-b mb3"><span class="small muted">Active encounter</span><b>${en.id} · ${pt.name}</b></div>
      <div class="mb3"><div class="tiny muted uppercase mb1" style="margin-bottom:6px">Step ${S.step+1}/9 · ${ENC_STEPS[S.step]}</div>
        <div class="qdots">${ENC_STEPS.map((s,i)=>`<span class="${S.stepDone.includes(i)?'on':''} ${S.step===i?'cur':''}"></span>`).join('')}</div></div>
      <div class="next-strip" style="margin-bottom:0"><span class="badge badge-sky" style="flex-shrink:0">NEXT</span><span><b>${nextAction}</b></span></div>
      <button class="btn btn-primary btn-block mt3" onclick="go('encounter')">Continue workspace →</button>
    </div>`;
}
function renderDashLabWork(){
  const pend=['CBC','CRP','Chest X-ray'].filter(t=>!S.reviewed[{CBC:'cbc',CRP:'crp','Chest X-ray':'cxr'}[t]]);
  return `
    <div class="card-h"><h3>My work</h3><span class="badge badge-sky">${pend.length} pending</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      <div class="small muted mb2">Pending results to release</div>
      ${pend.length?pend.map(t=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${t}</b><button class="btn btn-primary btn-sm" onclick="reviewResult('${t==='Chest X-ray'?'cxr':t.toLowerCase()}')">Release</button></div>`).join(''):'<div class="empty" style="padding:var(--sp4)"><p>Nothing pending.</p></div>'}
      <button class="btn btn-outline btn-block mt3" onclick="go('diagnostics')">Open lab worklist →</button>
    </div>`;
}
function renderDashRxWork(){
  const scripts=[{pat:PName('AMX-000001'),med:'Amoxicillin 500mg TID ×7d',id:'ENC-000140',stat:false},{pat:PName('AMX-000008'),med:'Amoxicillin syrup 125mg/5mL TID ×7d',id:'ENC-000147',stat:true}];
  return `
    <div class="card-h"><h3>My work</h3><span class="badge badge-sky">${scripts.length} to dispense</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      ${scripts.map(s=>`<div class="fact ${s.stat?'flag':''}"><div class="fc">${s.stat?'!':'Rx'}</div><div><b>${s.med}</b><p>${s.pat} · ${s.id}${s.stat?' · <span class="badge badge-red">STAT</span>':''}</p></div></div>`).join('')}
      <button class="btn btn-outline btn-block mt3" onclick="go('pharmacy')">Open pharmacy queue →</button>
    </div>`;
}
function renderDashAdminWork(){
  const approvals=[
    {ic:'$', label:'Ward stock re-order', note:'Amoxicillin syrup below facility re-order level', by:'Requested by: Pharmacy', go:'pharmacy'},
    {ic:'A', label:'Staff schedule', note:'Next week\u2019s roster awaiting approval', by:'Owner: Workforce Command', go:'workforce'},
    {ic:'C', label:'Equipment service contract', note:'Radiology procurement approval required', by:'Governance', go:'financial'}
  ];
  return `
    <div class="card-h"><h3>My approvals</h3><span class="badge badge-red">${approvals.length} awaiting action</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      ${approvals.map(a=>`
        <div class="fact flag"><div class="fc">${a.ic}</div>
        <div class="grow"><b>${a.label}</b><p>${a.note} · ${a.by}</p>
          <button class="btn btn-outline btn-sm mt1" onclick="go('${a.go}')">Review →</button></div></div>`).join('')}
    </div>`;
}
function renderDashAdminAttention(){
  return `
    <div class="card-h"><h3>Facility attention</h3><span class="badge badge-red">2 open</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      <div class="att-group">
        <div class="att-gtitle"><span class="dot dot-red"></span>Critical — Paediatric service</div>
        <button class="att-item" onclick="go('quality')">
          <b>Respiratory safety escalation</b>
          <span class="small muted">Paediatric respiratory workload has triggered the facility escalation threshold.</span>
          <span class="small muted">Owner: Paediatrics · Status: Active · Escalation: Clinical leadership</span>
          <span class="btn btn-outline btn-sm" style="pointer-events:none">View safety command →</span>
        </button>
      </div>
      <div class="att-group">
        <div class="att-gtitle"><span class="dot dot-amber"></span>Referral coordination</div>
        <button class="att-item" onclick="go('ops')">
          <b>Orthopaedic referral awaiting confirmation</b>
          <span class="small muted">1 referral coordination issue — awaiting receiving-facility confirmation.</span>
          <span class="small muted">Sending: Orthopaedics · Destination: Kenyatta County Hospital</span>
          <span class="btn btn-outline btn-sm" style="pointer-events:none">Coordinate referral →</span>
        </button>
      </div>
    </div>`;
}
function renderDashAdminEvents(){
  const events=[
    {t:'20:15', e:'Emergency department capacity review'},
    {t:'20:30', e:'Theatre utilization checkpoint'},
    {t:'21:00', e:'Night workforce handover'},
    {t:'22:00', e:'National reporting synchronization'}
  ];
  return `
    <div class="card-h"><h3>Next facility events</h3><span class="badge badge-sky">Tonight</span></div>
    <div class="card-body" style="padding-top:var(--sp3)">
      ${events.map(ev=>`<div class="row" style="padding:9px 0;border-bottom:1px solid var(--neutral-100)"><span class="mono" style="color:var(--primary);font-weight:700;flex-shrink:0">${ev.t}</span><b style="font-size:var(--sm)">${ev.e}</b></div>`).join('')}
      <button class="btn btn-outline btn-block mt3" onclick="go('clinicalops')">Open clinical operations →</button>
    </div>`;
}
function attentionGroups(){
  return [
    {g:'Urgent', color:'#dc2626', items:[
      {label:'Baby A. — SpO₂ 84%', note:'Severe pneumonia · RR 68 · chest indrawing', time:'14:02', go:'encounter', mrn:'AMX-000008'},
      {label:'Waiting 4h — Esther Nyambura', note:'Wheeze · ENC-000143', time:'since 10:20', go:'encounter', mrn:'AMX-000004'}
    ]},
    {g:'Pending', color:'#0284c7', items:[
      {label:'Vitals capture — 12 awaiting', note:'Triage queue · General OPD', time:'now', go:'ops', mrn:null}
    ]},
    {g:'Results', color:'#7c3aed', items:[
      {label:'CBC · CRP · CXR ready to review', note:'John Otieno — ENC-000145', time:'14:03', go:'diagnostics', mrn:'AMX-000001'}
    ]},
    {g:'Referrals', color:'#059669', items:[
      {label:'ENC-000148 → Orthopaedics (KCH)', note:'Awaiting signature — James Mwangi', time:'13:55', go:'ops', mrn:'AMX-000014'}
    ]}
  ];
}
function tasksPending(){ return TASKS.filter(t=>!S.tasksDone[t.id]); }
function tasksOverdue(){ return tasksPending().filter(t=>/overdue/i.test(t.due)||t.prio==='high'); }
function toggleTask(id){ S.tasksDone[id]=!S.tasksDone[id]; renderScreen(S.screen); }
function actFeed(){
  const base = S.audit.length ? [...S.audit.map(a=>({cat:'Clinical', t:a.t, msg:a.msg})), ...ACTIVITY_FEED] : ACTIVITY_FEED;
  return base.filter(a=>S.actFilter==='All'||a.cat===S.actFilter);
}
function setActFilter(f){ S.actFilter=f; renderScreen('dashboard'); }
function renderDashClinician(){
  const waitingN=ENCOUNTERS.filter(x=>x.status!=='Completed').length;
  const urgentN=ENCOUNTERS.filter(x=>x.urgent).length+1;
  const pendingTests=['CBC','CRP','Chest X-ray'].filter(t=>!S.reviewed[{CBC:'cbc',CRP:'crp','Chest X-ray':'cxr'}[t]]);
  const pendTasks=tasksPending(), overTasks=tasksOverdue();
  const qmax=Math.max(...QUEUE_FLOW.map(q=>q.count));
  const quick=[
    {l:'Register patient', s:'Add to facility', go:'register', ic:'M12 5v14M5 12h14'},
    {l:'New encounter', s:S.patient?S.patient.name:'—', go:'encounter', ic:'M12 8v5l3 2'},
    {l:'Order investigation', s:'Lab / imaging', go:'diagnostics', ic:'M6 3v12M6 21v-6M18 3v6M18 21v-3M6 9h12M6 15h12'},
    {l:'Write prescription', s:'Medication', go:'pharmacy', ic:'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z'},
    {l:'Generate document', s:'Note / discharge', go:'documents', ic:'M6 2h9l4 4v16H6Z'},
    {l:'Referral', s:'To another facility', go:'ops', ic:'M3 7h18M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7'}
  ];
  const act=actFeed();
  return `
    <div class="grid cols-4 mb4">
      <div class="kpi hoverable" onclick="go('ops')"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 21V7l7-4 7 4v14M3 21h18M10 11h4"/></svg></div><div><div class="kpi-value">${waitingN}</div><div class="kpi-label">Waiting in queue</div><div class="kpi-trend">View queue →</div></div></div>
      <div class="kpi hoverable" onclick="go('ops')"><div class="kpi-icon" style="background:var(--danger)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 9v5M12 17h.01"/></svg></div><div><div class="kpi-value">${urgentN}</div><div class="kpi-label">Urgent / emergencies</div><div class="kpi-trend" style="color:var(--danger)">Action now →</div></div></div>
      <div class="kpi hoverable" onclick="go('diagnostics')"><div class="kpi-icon" style="background:#7c3aed"><svg class="ic" viewBox="0 0 24 24"><path d="M6 3v12M6 21v-6M18 3v6M18 21v-3M6 9h12M6 15h12"/></svg></div><div><div class="kpi-value">${pendingTests.length}</div><div class="kpi-label">Results to review</div><div class="kpi-trend">${pendingTests.join(' · ')}</div></div></div>
      <div class="kpi hoverable" onclick="go('tasks')"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M9 4h6m-6 0a2 2 0 0 0-2 2v14h10V6a2 2 0 0 0-2-2m-6 0a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2"/></svg></div><div><div class="kpi-value">${pendTasks.length}</div><div class="kpi-label">My tasks</div><div class="kpi-trend" style="color:${overTasks.length?'var(--danger)':'var(--success)'}">${overTasks.length} overdue · Open →</div></div></div>
    </div>
    <div class="card mb4">
      <div class="card-h"><h3>Recent patients</h3><button class="btn btn-ghost btn-sm" onclick="go('patients')">View all →</button></div>
      <div class="recent-strip">
        ${PATIENTS.slice(0,4).map(p=>{const pe=ENCOUNTERS.find(x=>x.mrn===p.mrn&&x.status!=='Completed');return `
        <button class="recent-pat" onclick="selectPatient('${p.mrn}');go('${pe?'encounter':'patients'}')">
          <span class="rp-av" style="background:${p.color}">${p.avat}</span>
          <b>${p.name}</b><small>${p.mrn}</small>
          <span class="chip ${pe?'amber':'gray'}">${pe?'In queue':'Record'}</span>
        </button>`;}).join('')}
      </div>
    </div>
    <div class="grid split2">
      <div>
        <div class="card mb4">
          <div class="card-h"><h3>Queue — General OPD</h3><button class="btn btn-ghost btn-sm" onclick="go('ops')">View all →</button></div>
          <div class="table-wrap"><table>
            <tr><th>#</th><th>Patient</th><th>Chief complaint</th><th>Waiting</th><th>Status</th><th></th></tr>
            ${ENCOUNTERS.filter(x=>x.status!=='Completed').map((x,i)=>`
            <tr style="cursor:pointer" onclick="selectPatient('${x.mrn}');go('encounter')">
              <td class="muted">${i+1}</td><td><b>${PATIENTS.find(pp=>pp.mrn===x.mrn)?.name||'—'}</b><div class="tiny muted mono">${x.id}</div></td>
              <td>${x.cc}</td><td class="muted">${i<3?'<span class="badge badge-red">Immediate</span>':i<6?'<span class="badge badge-amber">Waiting</span>':'<span class="badge badge-gray">Seen</span>'}</td>
              <td><span class="state-pill ${x.status==='In progress'?'state-active':'state-pending'}">${x.status}</span></td>
              <td>→</td>
            </tr>`).join('')}
          </table></div>
        </div>
        <div class="card mb4">
          <div class="card-h"><h3>Patient flow — this week</h3><span class="badge badge-sky">169 peak · Fri</span></div>
          <div class="card-body">
            <div class="flow-chart">
              ${[{d:'Mon',v:132},{d:'Tue',v:148},{d:'Wed',v:141},{d:'Thu',v:156},{d:'Fri',v:169,peak:1},{d:'Sat',v:94},{d:'Sun',v:61}].map(day=>`
                <div class="flow-col ${day.peak?'clickable':''}" ${day.peak?`onclick="S.friDrill=!S.friDrill;renderScreen('dashboard')"`:''}>
                  <span class="fv">${day.v}</span>
                  <div class="fb ${day.peak?'peak':''}" style="height:${Math.round(day.v/169*100)}%"></div>
                  <small>${day.d}</small>
                </div>`).join('')}
            </div>
            ${S.friDrill?`<div class="row gap2 wrap mt2" style="justify-content:center">${[['Outpatient',121],['Emergency',28],['ANC',12],['Paediatrics',8]].map(([k,v])=>`<span class="chip">${k} <b>${v}</b></span>`).join('')}</div>`:''}
            <div class="row-b small muted mt3"><span>1,001 outpatient encounters this week</span><span>Tap Fri for breakdown · Peak: Friday 169</span></div>
          </div>
        </div>
        <div class="card">
          <div class="card-h"><h3>Live queue flow</h3><span class="badge badge-sky">${QUEUE_FLOW.reduce((a,q)=>a+q.count,0)} in system</span></div>
          <div class="card-body">
            <div class="flow-stages">
              ${QUEUE_FLOW.map(q=>`<div class="stage"><span class="stage-bar" style="height:${Math.round(q.count/qmax*100)}%"></span><b>${q.count}</b><span>${q.stage}</span><small>${q.note}</small></div>`).join('')}
            </div>
            <div class="row-b small muted mt3"><span>Stages show where patients are right now.</span><span>Bottleneck: Consultation</span></div>
          </div>
        </div>
      </div>
      <div>
        <div class="card mb4">
          <div class="card-h"><h3>Attention center</h3><span class="badge badge-red">${urgentN} urgent</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            ${attentionGroups().map(g=>`
              <div class="att-group">
                <div class="att-gtitle"><span class="dot" style="background:${g.color}"></span>${g.g}</div>
                ${g.items.map(it=>`<button class="att-item" onclick="selectPatient('${it.mrn}');go('${it.go}')">
                  <b>${it.label}${it.time?' <span class="tiny muted">· '+it.time+'</span>':''}</b>
                  <span class="small muted">${it.note}</span>
                  <span class="muted">›</span></button>`).join('')}
              </div>`).join('')}
          </div>
        </div>
        <div class="card mb4">
          <div class="card-h"><h3>My tasks</h3><button class="btn btn-ghost btn-sm" onclick="go('tasks')">All tasks →</button></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            ${pendTasks.length?pendTasks.slice(0,5).map(t=>`
              <div class="task-row ${/overdue/i.test(t.due)?'overdue':''}">
                <label class="checkbox"><input type="checkbox" onchange="toggleTask('${t.id}')"><span></span></label>
                <button class="grow" style="text-align:left;background:none;border:none;cursor:pointer;padding:0" onclick="go('${t.go}')">
                  <b>${t.label}</b><div class="small muted">${t.note} · <span class="${t.prio==='high'?'badge badge-red':t.prio==='med'?'badge badge-amber':'badge badge-gray'}">${t.prio}</span> · ${t.due}</div>
                </button>
              </div>`).join(''):'<div class="empty" style="padding:var(--sp3)"><p>All tasks done. 🎉</p></div>'}
          </div>
        </div>
        <div class="card mb4">
          <div class="card-h"><h3>Quick actions</h3><span class="badge badge-sky">Context-aware</span></div>
          <div class="grid cols-2" style="gap:var(--sp2);padding:var(--sp3)">
            ${quick.map(a=>`<button class="qa-btn" onclick="go('${a.go}')"><svg class="ic" viewBox="0 0 24 24"><path d="${a.ic}"/></svg><b>${a.l}</b><small>${a.s}</small></button>`).join('')}
          </div>
        </div>
        <div class="card mb4">
          <div class="card-h"><h3>Recent activity</h3>
            <div class="row gap1">
              ${['All','Clinical','Operations','Results','Documents','System'].map(f=>`<button class="chip ${S.actFilter===f?'active':''}" onclick="setActFilter('${f}')">${f}</button>`).join('')}
            </div>
          </div>
          <div class="card-body" style="padding-top:var(--sp3)"><div class="tl">
            ${act.length?act.map(a=>`<div class="tl-item"><div class="tl-time">${a.t}</div><div class="tl-title">${a.msg}</div></div>`).join(''):'<div class="empty" style="padding:var(--sp3)"><p>No activity in this filter.</p></div>'}
          </div></div>
        </div>
        <div class="card">
          <div class="card-h"><h3>System status</h3><span class="badge badge-green">All systems nominal</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            ${INTEGRATIONS.slice(0,5).map(i=>`<div class="row-b" style="padding:7px 0;border-bottom:1px solid var(--neutral-100)"><div class="row gap2"><span class="dot" style="background:${i.color}"></span><b style="font-size:var(--sm)">${i.name}</b></div><span class="tiny muted">${i.badge}</span></div>`).join('')}
          </div>
        </div>
      </div>
    </div>`;
}
function renderDashLab(){
  const tests=['CBC ('+PName('AMX-000001')+')','CRP ('+PName('AMX-000001')+')','Chest X-ray ('+PName('AMX-000008')+')','Blood culture ('+PName('AMX-000014')+')','Urinalysis ('+PName('AMX-000004')+')'];
  return `
    <div class="grid cols-4 mb4">
      <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M6 3v12M6 21v-6M18 3v6M18 21v-3M6 9h12M6 15h12"/></svg></div><div><div class="kpi-value">24</div><div class="kpi-label">Samples received</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--warning)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2"/></svg></div><div><div class="kpi-value">7</div><div class="kpi-label">Pending</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div><div><div class="kpi-value">17</div><div class="kpi-label">Released today</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:#7c3aed"><svg class="ic" viewBox="0 0 24 24"><path d="M12 9v5M12 17h.01"/></svg></div><div><div class="kpi-value">1</div><div class="kpi-label">STAT results</div><div class="kpi-trend" style="color:var(--danger)">Chest X-ray</div></div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Lab worklist</h3><span class="badge badge-sky">7 pending</span></div>
      <div class="table-wrap"><table><tr><th>Order</th><th>Patient</th><th>Test</th><th>Received</th><th>Status</th><th></th></tr>
        ${tests.map((t,i)=>`<tr><td class="mono">LB-${(1440-i)}</td><td>${t.split('(')[1]?t.split('(')[1].replace(')',''):'—'}</td><td><b>${t.split(' (')[0]}</b></td><td class="muted">${i<2?'09:40':'10:1'+i}</td><td><span class="state-pill ${i<2?'state-active':'state-pending'}">${i<2?'Ready to release':'Processing'}</span></td><td><button class="btn btn-primary btn-sm" onclick="toast('Result released (demo)','ok');renderScreen('dashboard')">Release</button></td></tr>`).join('')}
      </table></div></div>`;
}
function renderDashPharmacy(){
  return `
    <div class="grid cols-4 mb4">
      <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M9 5h6m-6 0a2 2 0 0 0-2 2v14h10V7a2 2 0 0 0-2-2m-6 0a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2"/></svg></div><div><div class="kpi-value">14</div><div class="kpi-label">To dispense</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--warning)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 9v5M12 17h.01"/></svg></div><div><div class="kpi-value">2</div><div class="kpi-label">STAT scripts</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div><div><div class="kpi-value">38</div><div class="kpi-label">Dispensed today</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--danger)"><svg class="ic" viewBox="0 0 24 24"><path d="M4 7h16M10 7V4h4v3M5 7l1 13h12l1-13"/></svg></div><div><div class="kpi-value">3</div><div class="kpi-label">Low stock</div></div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Prescriptions to dispense</h3><span class="badge badge-red">2 STAT</span></div>
      <div class="table-wrap"><table><tr><th>Patient</th><th>Medication</th><th>Encounter</th><th>Priority</th><th></th></tr>
        <tr><td><b>Baby A.</b></td><td>Amoxicillin syrup 125mg/5mL TID ×7d</td><td class="mono">ENC-000147</td><td><span class="badge badge-red">STAT</span></td><td><button class="btn btn-primary btn-sm" onclick="toast('Dispensed to patient (demo)','ok');renderScreen('dashboard')">Dispense</button></td></tr>
        <tr><td><b>John Otieno</b></td><td>Amoxicillin 500mg TID ×7d</td><td class="mono">ENC-000140</td><td><span class="badge badge-gray">Routine</span></td><td><button class="btn btn-primary btn-sm" onclick="toast('Dispensed to patient (demo)','ok');renderScreen('dashboard')">Dispense</button></td></tr>
        <tr><td><b>Esther Nyambura</b></td><td>Salbutamol inhaler + Prednisolone</td><td class="mono">ENC-000143</td><td><span class="badge badge-gray">Routine</span></td><td><button class="btn btn-primary btn-sm" onclick="toast('Dispensed to patient (demo)','ok');renderScreen('dashboard')">Dispense</button></td></tr>
      </table></div></div>`;
}
function renderDashAdmin(){
  const f = FACILITIES.find(x=>x.id===S.facility) || FACILITIES[0];
  const day = dayFor(S.facility);
  const st = day.strip;

  /* ---- capacity (licensed beds + occupancy) ---- */
  const licensed = f.beds||420;
  const occupied = Math.floor(licensed*day.occupancy/100);
  const available = licensed-occupied;
  const utilPct = Math.round(occupied/licensed*100);
  const capColor = pct => pct>=95?'#dc2626' : pct>=85?'#d97706' : '#059669';
  const capLabel = pct => pct>=95?'Near capacity' : pct>=85?'Pressure' : 'Stable';
  const capChip  = pct => pct>=95?'chip red' : pct>=85?'chip amber' : 'chip green';
  const nearCap = day.wards.filter(w=>w[3]>=85).length;

  /* ---- workforce ---- */
  const wfTotal=WORKFORCE.length;
  const onDuty=WORKFORCE.filter(w=>w.status==='On duty').length;
  const offDuty=WORKFORCE.filter(w=>w.status==='Off duty').length;
  const leave=WORKFORCE.filter(w=>w.status==='Leave').length;
  const pendingAct=WORKFORCE.filter(w=>w.status==='Pending activation').length;
  const coverage=[
    {d:'Emergency', v:94, c:'#059669'},
    {d:'ICU', v:100, c:'#059669'},
    {d:'Theatre', v:83, c:'#d97706'},
    {d:'Maternity', v:100, c:'#059669'},
    {d:'Laboratory', v:76, c:'#dc2626'}
  ];
  const covLow=coverage.filter(x=>x.v<85).map(x=>x.d);

  /* ---- facility status matrix ---- */
  const matrix=[
    {d:'Clinical Operations', s:'Stable', c:'green'},
    {d:'Workforce', s:'Adequate', c:'green'},
    {d:'Capacity', s:'Pressure', c:'amber'},
    {d:'Finance', s:'Stable', c:'green'},
    {d:'Supplies', s:'Attention', c:'amber'},
    {d:'Safety & Governance', s:'2 open', c:'amber'},
    {d:'Infrastructure', s:'Operational', c:'green'},
    {d:'National Reporting', s:'96% ready', c:'green'},
    {d:'Integrations', s:'Connected', c:'green'}
  ];

  /* ---- operational pressure ---- */
  const icuPct  = day.wards.find(w=>w[0]==='ICU')?.[3] ?? 91;
  const matPct  = day.wards.find(w=>w[0]==='Maternity')?.[3] ?? 89;
  const pressure=[
    {l:'Emergency', v:`${st.emergency} waiting`, s:'Attention', c:'#d97706', go:'ops'},
    {l:'Laboratory', v:`${st.lab} pending`, s:'Attention', c:'#d97706', go:'diagnostics'},
    {l:'ICU', v:`${icuPct}% occupied`, s:'Pressure', c:'#d97706', go:'ops'},
    {l:'Theatre', v:`${st.theatre} active`, s:'Stable', c:'#059669', go:'ops'},
    {l:'Maternity', v:`${matPct}% occupied`, s:'Attention', c:'#d97706', go:'ops'},
    {l:'Pharmacy', v:`${st.pharmacy} pending`, s:'Stable', c:'#059669', go:'pharmacy'}
  ];

  /* ---- national readiness ---- */
  const nAvg = Math.round(REPORT_DOMAINS.reduce((a,d)=>a+d.pct,0)/REPORT_DOMAINS.length);
  const nIssues = REPORTING_ISSUES.reduce((a,i)=>(a+(parseInt(i.record)||0)),0);

  const trendDiff = day.trend.patients[6]-day.trend.patients[5];
  const now = new Date().toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'});
  return `
    <div class="fac-hero card mb4" style="background:linear-gradient(120deg,${f.color}14,#fff 62%)">
      <div class="row-b" style="flex-wrap:wrap;gap:var(--sp3)">
        <div class="row gap3">
          <div class="fac-monogram" style="background:${f.color}">${f.code}</div>
          <div>
            <div class="row gap2 wrap" style="margin-bottom:4px"><h2 style="font-size:var(--xl)">Facility Command Center</h2><span class="chip green"><span class="dot dot-green"></span>SYSTEM OPERATIONAL</span></div>
            <h2 style="font-size:var(--md);margin:0">${f.name}</h2>
            <p class="small muted">${f.level} · ${f.beds} licensed beds · ${day.patients} patients · ${day.encounters} encounters today</p>
            <div class="row gap1 mt1"><span class="chip">${f.workspace}</span><span class="chip green"><span class="dot dot-green"></span>${f.status}</span></div>
          </div>
        </div>
        <div class="row gap2">
          <button class="btn btn-outline btn-sm" onclick="showFacilitySwitch()">Switch facility</button>
          <button class="btn btn-primary btn-sm" onclick="go('exec')">Executive Overview →</button>
        </div>
      </div>
    </div>
    <div class="grid cols-5 mb4">
      <div class="kpi hoverable" onclick="go('exec')"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3"/></svg></div><div><div class="kpi-value">${day.patients}</div><div class="kpi-label">Patients in facility</div><div class="kpi-trend">${trendDiff>=0?'+':'−'}${Math.abs(trendDiff)} vs yesterday</div></div></div>
      <div class="kpi hoverable" onclick="go('ops')"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/></svg></div><div><div class="kpi-value">${day.encounters}</div><div class="kpi-label">Encounters today</div></div></div>
      <div class="kpi hoverable" onclick="go('ops')"><div class="kpi-icon" style="background:#7c3aed"><svg class="ic" viewBox="0 0 24 24"><path d="M5 21V7l7-4 7 4v14M3 21h18M10 11h4"/></svg></div><div><div class="kpi-value">${day.admissions}</div><div class="kpi-label">Admissions</div></div></div>
      <div class="kpi hoverable" onclick="go('ops')"><div class="kpi-icon" style="background:#0ea5e9"><svg class="ic" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div><div><div class="kpi-value">${day.discharges}</div><div class="kpi-label">Discharges</div></div></div>
      <div class="kpi hoverable" onclick="go('clinicalops')"><div class="kpi-icon" style="background:${utilPct>=85?'var(--danger)':'var(--success)'}"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2"/></svg></div><div><div class="kpi-value">${day.occupancy}%</div><div class="kpi-label">Bed occupancy</div><div class="kpi-trend" style="color:${utilPct>=85?'var(--danger)':'var(--success)'}">${utilPct>=85?'Pressure':'Stable'}</div></div></div>
    </div>
    <div class="card mb4">
      <div class="card-h"><h3>Facility status</h3><span class="badge badge-green"><span class="dot dot-green"></span>Operational</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="row gap4 wrap mb4">
          <div style="text-align:center">${miniDonut(utilPct, '#059669', 124, 'utilization')}</div>
          <div>
            <div class="kpi-value" style="font-size:var(--2xl)">Operational</div>
            <div class="small muted">No facility-wide service interruption</div>
            <div class="tiny muted mt1">Last evaluated: ${now}</div>
          </div>
        </div>
        <div class="status-grid">
          ${matrix.map(m=>`<div class="status-row"><b>${m.d}</b><span class="chip ${m.c}"><span class="dot dot-${m.c}"></span>${m.s}</span></div>`).join('')}
        </div>
      </div>
    </div>
    <div class="grid split2">
      <div>
        <div class="card mb4"><div class="card-h"><h3>Operational pressure</h3><span class="badge badge-amber">Live</span></div>
          <div class="strip-grid">
            ${pressure.map(p=>`<button class="strip-item" onclick="go('${p.go}')"><span class="strip-ic" style="background:${p.c}15;color:${p.c}">${p.v.split(' ')[0]}</span><b>${p.l}</b><small><span class="dot" style="background:${p.c}"></span> ${p.v} · ${p.s}</small></button>`).join('')}
          </div>
        </div>
        <div class="card mb4"><div class="card-h"><h3>Financial position</h3><span class="badge badge-sky">Month-to-date</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="row-b"><span class="kpi-value" style="font-size:30px">KES ${(day.trend.rev[6]).toFixed(1)}M</span><span class="chip green"><span class="dot dot-green"></span>+8.4% vs previous month</span></div>
            <div class="small muted mb3">Month-to-date revenue</div>
            ${spark(day.trend.rev, 260, 44, '#059669')}
            <div class="grid cols-2 mt3" style="gap:var(--sp2)">
              <div class="fact flag"><div class="fc">$</div><div><b>KES 7.2M</b><p>Claims pending</p></div></div>
              <div class="fact flag"><div class="fc">!</div><div><b>KES 2.1M</b><p>Claims rejected</p></div></div>
            </div>
            <button class="btn btn-outline btn-block mt3" onclick="go('financial')">Open financial command →</button>
          </div></div>
        <div class="card mb4"><div class="card-h"><h3>Facility operations</h3><span class="badge badge-sky">Service topology</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="topo">
              <div class="topo-root">${f.code}</div>
              <div class="topo-arrow">│</div>
              <div class="topo-groups">
                ${[['CLINICAL',[['Emergency','ops'],['OPD','ops'],['Inpatient','ops'],['Theatre','ops'],['Maternity','ops']]],['DIAGNOSTICS',[['Laboratory','diagnostics'],['Radiology','diagnostics'],['Imaging','diagnostics']]],['SUPPORT',[['Pharmacy','pharmacy'],['Blood Bank','diagnostics'],['Nutrition','ops']]]].map(([g,items])=>`
                  <div class="topo-group"><div class="topo-gtitle">${g}</div>
                    ${items.map(([name,go2])=>`<button onclick="go('${go2}')">${name}</button>`).join('')}
                  </div>`).join('')}
              </div>
            </div>
            <div class="small muted mt3">Clicking a service opens that service\u2019s operations — never an individual patient chart.</div>
          </div></div>
      </div>
      <div>
        <div class="card mb4"><div class="card-h"><h3>Workforce now</h3><span class="badge badge-sky">${wfTotal} identities</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="row gap2 wrap mb3">
              ${[['On duty',onDuty,'#059669'],['Off duty',offDuty,'#64748b'],['Leave',leave,'#d97706'],['Pending activation',pendingAct,'#0284c7']].map(([l,v,c])=>`
                <span class="chip" style="border-color:${c}55;color:${c}">${l} <b>${v}</b></span>`).join('')}
            </div>
            <div class="tiny muted uppercase mb1">Coverage</div>
            <div class="status-grid">
              ${coverage.map(cv=>`<div class="status-row"><b>${cv.d}</b><span class="mono" style="color:${cv.c};font-weight:700">${cv.v}%</span></div>`).join('')}
            </div>
            ${covLow.length?`<div class="next-strip mt3" style="margin-bottom:0"><span class="badge badge-red" style="flex-shrink:0">ALERT</span><span><b>${covLow.join(', ')} ${covLow.length>1?'coverage below configured threshold':'evening coverage below configured threshold'}.</b></span></div>`:''}
            <button class="btn btn-outline btn-block mt3" onclick="go('workforce')">Open workforce command →</button>
          </div></div>
        <div class="card mb4"><div class="card-h"><h3>Capacity</h3><span class="badge badge-sky">${licensed} licensed beds</span></div>
          <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
            <div style="text-align:center">${miniDonut(utilPct, '#d97706', 130, 'utilization')}</div>
            <div style="flex:1;min-width:200px">
              <div class="row-b" style="padding:4px 0"><b style="font-size:var(--lg)">${occupied} / ${licensed}</b><span class="small muted">beds occupied</span></div>
              <div class="row-b mb3" style="padding:4px 0"><b style="font-size:var(--lg)">${available}</b><span class="small muted">beds available</span></div>
              ${day.wards.map(([w,cap,occ,pct])=>`
                <div class="mb3"><div class="row-b mb1"><b style="font-size:var(--sm)">${w}</b><span class="small muted">${occ}/${cap} · ${pct}%</span><span class="${capChip(pct)}" style="padding:2px 8px">${capLabel(pct)}</span></div>
                <div class="bar"><div style="width:${pct}%;background:${capColor(pct)}"></div></div></div>`).join('')}
            </div>
          </div>
          <div class="card-body" style="padding-top:0">
            <div class="next-strip" style="margin-bottom:0"><span class="badge badge-amber" style="flex-shrink:0">INTEL</span><span><b>${nearCap} ${nearCap>1?'units':'unit'} approaching configured capacity thresholds.</b></span></div>
            <button class="btn btn-outline btn-block mt3" onclick="go('clinicalops')">Open capacity command →</button>
          </div></div>
        <div class="card mb4"><div class="card-h"><h3>National data readiness</h3><span class="badge badge-sky">${nAvg}% ready</span></div>
          <div class="card-body" style="display:flex;gap:var(--sp5);align-items:center;flex-wrap:wrap">
            <div style="text-align:center">${miniDonut(nAvg,'#0284c7',120,'ready')}</div>
            <div style="flex:1;min-width:220px">
              ${REPORT_DOMAINS.map(d=>`
                <div class="row-b mb2"><b style="font-size:12px;width:150px">${d.name}</b>${hbar(d.pct,100,d.pct>=99?'#059669':d.pct>=95?'#d97706':'#dc2626',130)}<span class="small mono">${d.pct}%</span></div>`).join('')}
            </div>
          </div>
          <div class="card-body" style="padding-top:0">
            <div class="fact flag"><div class="fc">!</div><div><b>${nIssues} records require attention</b><p>Missing outcomes, coding gaps and inconsistent demographics</p></div></div>
            <button class="btn btn-outline btn-block mt3" onclick="go('national')">Open national data →</button>
          </div></div>
      </div>
    </div>
    <div class="card">
      <div class="card-h"><h3>Quick actions</h3><span class="badge badge-sky">Facility scope</span></div>
      <div class="card-body" style="padding-top:var(--sp3)">
        <div class="grid cols-4" style="gap:var(--sp2)">
          ${[['Provision staff','provision','M12 5v14M5 12h14'],['Facility structure','organizations','M12 3a9 9 0 1 0 9 9M12 3v8l6 4M3 12h6'],['Approve roster','workforce','M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3'],['HMIS connection','hmis','M4 20h16M6 20V8l6-4 6 4v12M9 12h.01M15 12h.01'],['National reporting','national','M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Z M12 8v6M12 17h.01'],['Financial command','financial','M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z'],['Ecosystem','ecosystem','M12 3a9 9 0 1 0 9 9M12 3v8l6 4M12 21a9 9 0 0 0 7-12'],['Security center','security','M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z']].map(a=>`
            <button class="qa-btn" onclick="go('${a[1]}')"><svg class="ic" viewBox="0 0 24 24"><path d="${a[2]}"/></svg><b>${a[0]}</b><small>Facility</small></button>`).join('')}
        </div>
      </div></div>`;
}
function renderDashNurse(){
  return `
    <div class="grid cols-4 mb4">
      <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3"/></svg></div><div><div class="kpi-value">128</div><div class="kpi-label">Triaged today</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--warning)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2"/></svg></div><div><div class="kpi-value">12</div><div class="kpi-label">Awaiting vitals</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M3 7h18M6 7v13M18 7v13M3 20h18"/></svg></div><div><div class="kpi-value">9</div><div class="kpi-label">Vitals captured</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--danger)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 9v5M12 17h.01"/></svg></div><div><div class="kpi-value">3</div><div class="kpi-label">Critical alerts</div></div></div>
    </div>
    <div class="card"><div class="card-h"><h3>Triage queue</h3><button class="btn btn-ghost btn-sm" onclick="go('ops')">View all →</button></div>
      <div class="table-wrap"><table><tr><th>Patient</th><th>Complaint</th><th>Vitals</th><th>Triage</th><th></th></tr>
        ${ENCOUNTERS.filter(x=>x.status!=='Completed').map(x=>{const pp=PATIENTS.find(q=>q.mrn===x.mrn);return `<tr><td><b>${pp.name}</b></td><td>${x.cc}</td><td class="muted">${pp.mrn==='AMX-000008'?'SpO₂ 84% · RR 68 · HR 158':'—'}</td><td>${x.urgent?'<span class="badge badge-red">Resuscitation</span>':'<span class="badge badge-amber">Urgent</span>'}</td><td><button class="btn btn-primary btn-sm" onclick="toast('Vitals captured (demo)','ok');renderScreen('dashboard')">Capture</button></td></tr>`;}).join('')}
      </table></div></div>`;
}
function renderDashPatient(){
  const p=S.patient;
  const visits=ENCOUNTERS.filter(x=>x.mrn===p.mrn).length;
  const meds=[{name:'Amoxicillin 500mg',dose:'TID ×7d',due:'18:00',col:'#0284c7'},{name:'Salbutamol inhaler',dose:'2 puffs PRN',due:'As needed',col:'#059669'}];
  return `
    <div class="row-b mb4">
      <div class="row gap3"><div style="width:56px;height:56px;border-radius:16px;background:${p.color};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:22px">${p.avat}</div>
      <div><h2 style="font-size:var(--xl)">${p.name}</h2><p class="muted">${p.sex} ${p.ageLabel||(p.age+' yrs')} · ${p.mrn} · Patient portal</p></div></div>
      <button class="btn btn-primary" onclick="go('portal')">Open my portal →</button>
    </div>
    <div class="grid cols-4 mb4">
      <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2"/></svg></div><div><div class="kpi-value">${visits}</div><div class="kpi-label">My visits</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M9 3v18M15 3v18M3 7h18M3 17h18"/></svg></div><div><div class="kpi-value">3</div><div class="kpi-label">Results available</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:var(--warning)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z"/></svg></div><div><div class="kpi-value">2</div><div class="kpi-label">Active meds</div></div></div>
      <div class="kpi"><div class="kpi-icon" style="background:#7c3aed"><svg class="ic" viewBox="0 0 24 24"><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg></div><div><div class="kpi-value">${S.encounter&&S.encounter.mrn===p.mrn&&S.encounter.status!=='Completed'?'Active':'—'}</div><div class="kpi-label">Open encounter</div></div></div>
    </div>
    <div class="grid split2">
      <div>
        <div class="card mb4"><div class="card-h"><h3>My medications</h3><button class="btn btn-ghost btn-sm" onclick="go('portal')">View →</button></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            ${meds.map(m=>`<div class="fact"><div class="fc" style="background:${m.col}15;color:${m.col}">Rx</div><div><b>${m.name}</b><p>${m.dose} · next dose ${m.due}</p></div></div>`).join('')}
          </div></div>
        <div class="card"><div class="card-h"><h3>Recent results</h3><span class="badge badge-green">3 new</span></div>
          <div class="table-wrap"><table><tr><th>Test</th><th>Date</th><th>Result</th></tr>
            <tr><td><b>CBC</b></td><td class="muted">18 Aug</td><td class="mono">WBC 23.1 · Hb 9.8</td></tr>
            <tr><td><b>CRP</b></td><td class="muted">18 Aug</td><td class="mono">148 mg/L</td></tr>
            <tr><td><b>Chest X-ray</b></td><td class="muted">18 Aug</td><td>RLL consolidation</td></tr>
          </table></div></div>
      </div>
      <div>
        <div class="card mb4"><div class="card-h"><h3>Next appointment</h3><span class="badge badge-sky">General OPD</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><span class="muted">Date</span><b>Fri, 22 Aug · 09:30</b></div>
            <div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><span class="muted">Clinic</span><b>Dr. Brian Kamau</b></div>
            <div class="row-b" style="padding:8px 0"><span class="muted">Location</span><b>Room 12 — KTRH</b></div>
            <button class="btn btn-outline btn-block mt3" onclick="toast('Appointment reminder sent (demo)','ok')">Send reminder</button>
          </div></div>
        <div class="card"><div class="card-h"><h3>Care team</h3></div>
          <div class="card-body" style="padding-top:var(--sp3)">
            <div class="fact"><div class="fc" style="background:var(--primary-light);color:var(--primary)">✚</div><div><b>Dr. Brian Kamau</b><p>Clinician · Kisii Teaching &amp; Referral Hospital</p></div></div>
            <div class="fact"><div class="fc" style="background:var(--success-light);color:var(--success)">⚙</div><div><b>Sarah Ochieng</b><p>Facility administrator · billing &amp; appointments</p></div></div>
          </div></div>
      </div>
    </div>`;
}
function showPatientModal(){
  const p=S.patient;
  $('modalBox').innerHTML=`
    <div class="modal-h"><h3>${p.name}</h3><button class="btn btn-icon" onclick="closeModal()"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
    <div class="modal-b">
      <div class="grid cols-2">
        <div class="field"><label>MRN</label><div class="mono">${p.mrn}</div></div>
        <div class="field"><label>Date of birth</label><div>${p.dob} (${p.ageLabel||(p.age+' yrs')})</div></div>
        <div class="field"><label>Blood group</label><div>${p.blood}</div></div>
        <div class="field"><label>Phone</label><div>${p.phone}</div></div>
        <div class="field"><label>Next of kin</label><div>${p.kin} — ${p.kinPhone}</div></div>
        <div class="field"><label>Address</label><div>${p.address}</div></div>
        <div class="field"><label>Allergies</label><div>${p.allergies.length?p.allergies.join(', '):'None recorded'}</div></div>
        <div class="field"><label>Conditions</label><div>${p.conditions.length?p.conditions.join(', '):'None recorded'}</div></div>
      </div>
    </div>
    <div class="modal-f"><button class="btn btn-primary" onclick="closeModal()">Close</button></div>`;
  $('modalOv').classList.add('show');
}
function closeModal(){ $('modalOv').classList.remove('show'); }
