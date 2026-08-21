/* ---------- SCREEN RENDER ---------- */
function renderScreen(name){
  const c=$('content');
  const crumb=$('crumb');
  const act = id=>{ document.querySelectorAll('.nav-item').forEach(n=>n.classList.toggle('active',n.dataset.nav===id)); document.querySelectorAll('[data-mnav]').forEach(n=>n.classList.toggle('active',n.dataset.mnav===id)); };
  const p = S.patient, e = S.encounter;
  const fac = FACILITIES.find(f=>f.id===S.facility);
  const ctx = ()=>{
    $('ctxPatientName').textContent = p.name;
    $('ctxPatient').style.display='inline-flex';
    if(e){ $('ctxEncName').textContent = e.id; $('ctxEnc').style.display='inline-flex'; }
    else { $('ctxEnc').style.display='none'; }
  };
  const renderPatient = ()=>`
    <div class="card mb4" style="padding:var(--sp4) var(--sp5);display:flex;align-items:center;gap:var(--sp4);flex-wrap:wrap">
      <div style="width:52px;height:52px;border-radius:14px;background:${p.color};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:20px;flex-shrink:0">${p.avat}</div>
      <div class="grow">
        <div class="row gap2 wrap"><h2 style="font-size:var(--xl)">${p.name}</h2><span class="badge badge-gray">${p.sex} ${p.ageLabel||(p.age+' yrs')}</span><span class="badge badge-sky mono">${p.mrn}</span></div>
        <div class="row gap3 small muted wrap mt1">
          <span>${p.occupation}</span><span>•</span><span>${p.phone}</span><span>•</span><span>${p.address}</span>
        </div>
      </div>
      <div class="row gap2 wrap">
        <button class="btn btn-primary btn-sm" onclick="go('encounter')">Open encounter</button>
        <button class="btn btn-outline btn-sm" onclick="showPatientModal()">Details</button>
      </div>
    </div>`;

  const crumbTrail = active => {
    const map={
      dashboard:[['Home','dashboard'],['Command Center','dashboard']],
      patients:[['Home','dashboard'],['Patients','patients']],
      patient:[['Home','dashboard'],['Patients','patients'],[p.name||'Patient','patient']],
      register:[['Home','dashboard'],['Patients','patients'],['Register','register']],
      encounters:[['Home','dashboard'],['Encounters','encounters']],
      encounter:[['Home','dashboard'],['Encounters','encounters'],[e.id,'encounter']],
      activity:[['Home','dashboard'],['Activity','activity']],
      tasks:[['Home','dashboard'],['Tasks','tasks']],
      ops:[['Home','dashboard'],['Operations','ops']],
      diagnostics:[['Home','dashboard'],['Diagnostics','diagnostics']],
      pharmacy:[['Home','dashboard'],['Pharmacy','pharmacy']],
      telemedicine:[['Home','dashboard'],['Telemedicine','telemedicine']],
      billing:[['Home','dashboard'],['Billing','billing']],
      reports:[['Home','dashboard'],['Reports / HMIS','reports']],
      research:[['Home','dashboard'],['Research','research']],
      integrations:[['Home','dashboard'],['Integrations','integrations']],
      documents:[['Home','dashboard'],['Documents','documents']],
      governance:[['Home','dashboard'],['Governance','governance']],
      coding:[['Home','dashboard'],['ICD-11 Coding','coding']],
      portal:[['Home','dashboard'],['My Health','portal']],
      exec:[['Home','dashboard'],['Executive Overview','exec']],
      clinicalops:[['Home','dashboard'],['Clinical Operations Monitor','clinicalops']],
      workforce:[['Home','dashboard'],['Workforce Command','workforce']],
      workforceanalytics:[['Home','dashboard'],['Workforce Analytics','workforceanalytics']],
      researchintel:[['Home','dashboard'],['Research Intelligence','researchintel']],
      financial:[['Home','dashboard'],['Financial','financial']],
      quality:[['Home','dashboard'],['Quality · Safety & Governance','quality']],
      security:[['Home','dashboard'],['Security Center','security']],
      provision:[['Home','dashboard'],['Provision Staff & Roles','provision']],
      organizations:[['Home','dashboard'],['Organizations','organizations']],
      services:[['Home','dashboard'],['Service Catalogues','services']],
      infrastructure:[['Home','dashboard'],['Infrastructure','infrastructure']],
      assets:[['Home','dashboard'],['Asset Intelligence','assets']],
      identity:[['Home','dashboard'],['Hospital Identity','identity']],
      education:[['Home','dashboard'],['Clinical Education','education']],
      communications:[['Home','dashboard'],['Communications','communications']],
      protocols:[['Home','dashboard'],['Protocol Centers','protocols']],
      intel:[['Home','dashboard'],['Clinical Intelligence','intel']],
      execintel:[['Home','dashboard'],['Executive Intelligence','execintel']],
      marketplace:[['Home','dashboard'],['Marketplace','marketplace']],
      hmis:[['Home','dashboard'],['HMIS Connection','hmis']],
      national:[['Home','dashboard'],['National Data Readiness','national']],
      migration:[['Home','dashboard'],['Data Migration','migration']],
      ecosystem:[['Home','dashboard'],['Facility Ecosystem','ecosystem']],
      builder:[['Home','dashboard'],['Hospital Builder','builder']],
      invitations:[['Home','dashboard'],['Invitation Links & Roster','invitations']],
      stafflogins:[['Home','dashboard'],['Auto-create Staff Logins','stafflogins']],
      ward:[['Home','dashboard'],['Ward 4A','ward']],
      round:[['Home','dashboard'],['Ward 4A','ward'],['Daily Ward Round','round']],
      handover:[['Home','dashboard'],['Handover','handover']],
      clinic:[['Home','dashboard'],['Clinic','clinic']],
      results:[['Home','dashboard'],['Results','results']],
      discharge:[['Home','dashboard'],['Discharge','discharge']]
    };
    const trail=map[active]||[['Home','dashboard']];
    return trail.map((t,i)=> i===trail.length-1
      ? `<span class="crumb-link active">${t[0]}</span>`
      : `<span class="crumb-link" onclick="go('${t[1]}')">${t[0]}</span><span class="crumb-sep">/</span>`).join('');
  };

  switch(name){
    /* ---------- COMMAND CENTER ---------- */
    case 'dashboard': {
      act('dashboard'); crumb.innerHTML=crumbTrail('dashboard'); ctx();
      if(S.role==='clinician'){ c.innerHTML=renderClinicianHome(); renderClinical(); break; }
      const roleObj=ROLES.find(r=>r.id===S.role)||{};
      const nextE=ENCOUNTERS.find(x=>x.status!=='Completed');
      const nextP=nextE?PATIENTS.find(pp=>pp.mrn===nextE.mrn):null;
      const urgent=ENCOUNTERS.find(x=>x.urgent)||ENCOUNTERS.find(x=>x.mrn==='AMX-000008');
      const urgentP=urgent?PATIENTS.find(pp=>pp.mrn===urgent.mrn):null;
      const pendingTests=['CBC','CRP','Chest X-ray'].filter(t=>!S.reviewed[{CBC:'cbc',CRP:'crp','Chest X-ray':'cxr'}[t]]);
      const myWork = S.role==='lab'? renderDashLabWork()
        : S.role==='pharmacy'? renderDashRxWork()
        : S.role==='admin'? renderDashAdminWork()
        : S.role==='patient'? null
        : renderDashClinicalWork();
      const today=new Date().toLocaleDateString('en-GB',{weekday:'short',day:'numeric',month:'short',year:'numeric'});
      c.innerHTML=`
        <div class="row-b wrap mb4">
          <div><h1 style="font-size:var(--2xl)">Good ${new Date().getHours()<12?'morning':new Date().getHours()<17?'afternoon':'evening'}, ${roleObj.def||'there'}</h1>
          <p class="muted">${fac?fac.name:'Facility'} &middot; ${fac?fac.level:'—'} &middot; <span class="mono">${today}</span></p></div>
          <div class="row gap2 wrap">
            <span class="chip green"><span class="dot dot-green"></span>System operational</span>
            ${S.role==='patient'?`<button class="btn btn-primary" onclick="go('portal')">Open my portal</button>`
              :S.role==='admin'?`<button class="btn btn-primary" onclick="go('exec')">Executive Overview →</button>`
              :`<button class="btn btn-primary" onclick="go('patients')">+ New consultation</button>`}
          </div>
        </div>
        ${S.role==='patient'?renderDashPatient()
          :S.role==='admin'?`<div class="grid cols-3 mb4">
            <div class="card dash-card dash-mywork">${renderDashAdminWork()}</div>
            <div class="card dash-card">${renderDashAdminAttention()}</div>
            <div class="card dash-card dash-urgent">${renderDashAdminEvents()}</div>
          </div>`
          :`<div class="grid cols-3 mb4">
            <div class="card dash-card dash-mywork">${myWork}</div>
            <div class="card dash-card">${dashNextPatient(nextE,nextP)}</div>
            <div class="card dash-card dash-urgent">${dashAttention(urgent,urgentP)}</div>
          </div>`}
        ${S.role==='lab'?renderDashLab()
          : S.role==='pharmacy'?renderDashPharmacy()
          : S.role==='admin'?renderDashAdmin()
          : S.role==='nurse'?renderDashNurse()
          : S.role==='patient'?''
          : renderDashClinician()}`;
      break;
    }

    /* ---------- PATIENTS ---------- */
    case 'patients': {
      act('patients'); crumb.innerHTML=crumbTrail('patients'); ctx();
      c.innerHTML=`
        <div class="row-b wrap mb4">
          <div><h1 style="font-size:var(--2xl)">Patient directory</h1><p class="muted">${PATIENTS.length} demo patients</p></div>
          <button class="btn btn-primary" onclick="go('register')">+ Register patient</button>
        </div>
        <div class="card">
          <div class="card-h" style="flex-wrap:wrap"><div class="input-group grow" style="max-width:360px"><svg class="ic" viewBox="0 0 24 24" style="position:absolute;left:12px;top:50%;transform:translateY(-50%);color:var(--text-muted)"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg><input class="input" id="patSearch" placeholder="Search by name or MRN…" oninput="filterPatients()"></div>
          <div class="row gap2"><span class="badge badge-sky">Active 6</span><span class="badge badge-gray">Registered 1</span></div></div>
          <div class="table-wrap"><table>
            <tr><th>Patient</th><th>MRN</th><th>Age / Sex</th><th>Conditions</th><th>Phone</th><th>Status</th><th></th></tr>
            <tbody id="patRows">${PATIENTS.map(p=>patientRow(p)).join('')}</tbody>
          </table></div>
        </div>`;
      break;
    }
    /* ---------- PATIENT REGISTER ---------- */
    case 'register': {
      act('register'); crumb.innerHTML=crumbTrail('register'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Register a patient</h1><p class="muted">Demo registration — a new record is created locally.</p></div></div>
        <div class="card" style="max-width:720px">
          <div class="card-body">
            <div class="grid cols-2">
              <div class="field"><label>First name</label><input class="input" id="regFirst" placeholder="e.g. Amani"></div>
              <div class="field"><label>Last name</label><input class="input" id="regLast" placeholder="e.g. Wanjiru"></div>
              <div class="field"><label>Date of birth</label><input class="input" id="regDob" type="date" value="1995-01-01"></div>
              <div class="field"><label>Sex</label><select class="select" id="regSex"><option>Female</option><option>Male</option></select></div>
              <div class="field"><label>Phone</label><input class="input" id="regPhone" placeholder="+254 7XX XXX XXX"></div>
              <div class="field"><label>Next of kin</label><input class="input" id="regKin" placeholder="Name + phone"></div>
              <div class="field"><label>Address</label><input class="input" id="regAddr" placeholder="Village / town"></div>
              <div class="field"><label>Blood group</label><select class="select" id="regBlood"><option>O+</option><option>O-</option><option>A+</option><option>A-</option><option>B+</option><option>B-</option><option>AB+</option><option>AB-</option></select></div>
            </div>
            <div class="row gap2 mt3">
              <button class="btn btn-primary" onclick="registerPatient()">Register patient</button>
              <button class="btn btn-ghost" onclick="go('patients')">Cancel</button>
            </div>
          </div>
        </div>`;
      break;
    }
    /* ---------- ENCOUNTERS LIST ---------- */
    case 'encounters': {
      act('encounters'); crumb.innerHTML=crumbTrail('encounters'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Encounters</h1><p class="muted">All demo encounters across the facility.</p></div>
        <button class="btn btn-primary" onclick="go('patients')">Start new encounter</button></div>
        <div class="card"><div class="table-wrap"><table>
          <tr><th>Encounter</th><th>Patient</th><th>Type</th><th>Chief complaint</th><th>Clinician</th><th>Date</th><th>Status</th></tr>
          ${ENCOUNTERS.map(e=>`<tr style="cursor:pointer" onclick="selectPatient('${e.mrn}');go('encounter')">
            <td class="mono" style="font-weight:600">${e.id}</td><td><b>${PATIENTS.find(p=>p.mrn===e.mrn)?.name||'—'}</b></td>
            <td><span class="badge badge-gray">${e.type}</span></td><td>${e.cc}</td><td class="muted">${e.clinician}</td><td class="muted">${e.date}</td>
            <td><span class="state-pill ${e.status==='Completed'?'state-done':e.status==='In progress'?'state-active':'state-pending'}">${e.status}</span></td>
          </tr>`).join('')}
        </table></div></div>`;
      break;
    }
    /* ---------- ENCOUNTER WORKSPACE ---------- */
    case 'encounter': {
      act('encounter'); crumb.innerHTML=crumbTrail('encounter'); ctx();
      if(!e){
        c.innerHTML=`<div class="empty" style="padding:var(--sp8)"><div class="ei"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/></svg></div>
          <h2>No active encounter</h2><p>${p.name} has no current encounter in the queue.</p>
          <button class="btn btn-primary mt4" onclick="S.encounter={id:'ENC-'+String(1999+ENCOUNTERS.length),mrn:S.patient.mrn,type:'Outpatient',date:new Date().toLocaleDateString('en-GB',{day:'2-digit',month:'short',year:'numeric'}),clinician:'Dr. Brian Kamau',status:'In progress',cc:'New consultation',queue:'General OPD',d:ENC_DEFAULTS()};loadEnc(S.encounter);renderScreen('encounter')">Start new encounter</button></div>`;
        break;
      }
      c.innerHTML=`
        <div class="next-strip">
          <span class="badge badge-sky" style="flex-shrink:0">NEXT</span>
          <span><b>${ENC_STEPS[Math.min(S.step,ENC_STEPS.length-1)]}</b>${ENC_STEPS[S.step]==='Closure'?' — ready to close & sign':S.step<ENC_STEPS.length-1?' — capture the remaining detail then continue':''}</span>
          ${S.step<8?`<button class="btn btn-primary btn-sm" onclick="setStep(${S.step+1})">Continue →</button>`:`<button class="btn btn-primary btn-sm" onclick="closeEncounter()">Sign & close</button>`}
        </div>
        <div class="enc-layout">
          <div>
            ${renderPatient()}
            <div class="card mb4">
              <div class="card-h" style="flex-wrap:wrap">
                <div class="row gap2"><h3 style="font-size:var(--lg)">Encounter ${e.id}</h3><span class="badge badge-sky">${e.type}</span><span class="state-pill state-active">In progress</span></div>
                <div class="row gap2 small muted"><span>${e.date}</span><span>•</span><span>${e.clinician}</span></div>
              </div>
              <div class="card-body">
                <div class="stepper" id="stepper">${ENC_STEPS.map((s,i)=>`<button class="step ${i===S.step?'active':S.stepDone.includes(i)?'done':''}" onclick="setStep(${i})"><span class="n">${S.stepDone.includes(i)?'✓':i+1}</span>${s}</button>`).join('')}</div>
                <div id="stepBody"></div>
              </div>
            </div>
          </div>
          <div class="enc-state">
            <div class="card">
              <div class="card-h">
                <h3>Clinical state — <span class="text-primary">live</span></h3>
                <div class="row gap2"><span class="badge badge-sky" id="statePill">HPI active</span><button class="btn btn-icon sheet-close" onclick="toggleStateSheet()" title="Close state sheet"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
              </div>
              <div class="card-body" id="clinicalPanel"></div>
            </div>
          </div>
          <button class="btn btn-primary state-fab" onclick="toggleStateSheet()"><svg class="ic" width="15" height="15" viewBox="0 0 24 24"><path d="M12 8v5l3 2"/></svg> Clinical state</button>
        </div>`;
      renderStep();
      renderClinical();
      break;
    }
    /* ---------- ACTIVITY ---------- */
    case 'activity': {
      act('activity'); crumb.innerHTML=crumbTrail('activity'); ctx();
      const items=S.audit.length?S.audit:[
        {t:'17:30',msg:'Dr. Kamau opened ENC-000145 (John Otieno)'},
        {t:'17:31',msg:'Chief complaint recorded — Cough for 5 days'},
        {t:'17:32',msg:'HPI fact captured — productive cough'},
        {t:'17:33',msg:'Vitals captured — HR 112, RR 26, SpO₂ 92%'},
        {t:'17:34',msg:'CBC ordered'},
        {t:'17:40',msg:'CBC result reviewed — WBC 23.1'},
        {t:'17:41',msg:'Assessment signed — Severe community-acquired pneumonia'},
        {t:'17:42',msg:'Coding suggested — ICD-11 CA40.2'},
        {t:'17:45',msg:'Plan created — admit to short-stay ward'}];
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Activity</h1><p class="muted">Full audit trail of this demo session.</p></div>
        <button class="btn btn-outline btn-sm" onclick="go('governance')">Governance &amp; audit →</button></div>
        <div class="card"><div class="card-body">
          <div class="tl">${items.map(a=>`<div class="tl-item"><div class="tl-time">${a.t}</div><div class="tl-title">${a.msg}</div></div>`).join('')}</div>
        </div></div>`;
      break;
    }
    /* ---------- TASKS ---------- */
    case 'tasks': {
      act('tasks'); crumb.innerHTML=crumbTrail('tasks'); ctx();
      const cats=['All',...new Set(TASKS.map(t=>t.cat))];
      const filt=t=>(S.taskCat==='All'||t.cat===S.taskCat);
      const pend=TASKS.filter(t=>!S.tasksDone[t.id]&&filt(t));
      const done=TASKS.filter(t=>S.tasksDone[t.id]&&filt(t));
      const ovr=pend.filter(t=>/overdue/i.test(t.due)||t.prio==='high');
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">My tasks</h1><p class="muted">${pend.length} pending · ${ovr.length} urgent/overdue. Tick to complete — tap to go to the destination.</p></div>
        <button class="btn btn-outline btn-sm" onclick="go('activity')">Activity →</button></div>
        <div class="row gap2 wrap mb3">${cats.map(cat=>`<button class="chip ${S.taskCat===cat?'active':''}" onclick="S.taskCat='${cat}';renderScreen('tasks')">${cat}</button>`).join('')}</div>
        ${ovr.length?`<div class="next-strip mb4"><span class="badge badge-red">${ovr.length} URGENT</span><span><b>Prioritise these first:</b> ${ovr.slice(0,3).map(t=>t.label).join(' · ')}</span></div>`:''}
        <div class="grid cols-2">
          <div class="card"><div class="card-h"><h3>To review</h3><span class="badge badge-sky">${pend.length}</span></div><div class="card-body" style="padding-top:var(--sp3)">
            ${pend.length?pend.map(t=>`
              <div class="task-row ${/overdue/i.test(t.due)?'overdue':''}">
                <label class="checkbox"><input type="checkbox" onchange="toggleTask('${t.id}')"><span></span></label>
                <button class="grow" style="text-align:left;background:none;border:none;cursor:pointer;padding:0" onclick="go('${t.go}')">
                  <b>${t.label}</b><div class="small muted">${t.note} · <span class="${t.prio==='high'?'badge badge-red':t.prio==='med'?'badge badge-amber':'badge badge-gray'}">${t.prio}</span> · ${t.due}</div>
                </button>
                <span class="muted">›</span>
              </div>`).join(''):'<div class="empty" style="padding:var(--sp4)"><p>Nothing pending. All tasks done. 🎉</p></div>'}
          </div></div>
          <div class="card"><div class="card-h"><h3>Completed</h3><span class="badge badge-green">${done.length}</span></div><div class="card-body" style="padding-top:var(--sp3)">
            ${done.length?done.map(t=>`<div class="fact"><div class="fc" style="background:var(--success-light);color:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div><div><b style="text-decoration:line-through;opacity:.6">${t.label}</b><p class="muted">${t.cat} · completed in this demo</p></div></div>`).join(''):'<div class="empty" style="padding:var(--sp4)"><p>Completed tasks appear here.</p></div>'}
          </div></div>
        </div>`;
      break;
    }
    /* ---------- OPERATIONS ---------- */
    case 'ops': {
      act('ops'); crumb.innerHTML=crumbTrail('ops'); ctx();
      const tabs=[['queues','Queues'],['appts','Appointments'],['admits','Admissions'],['beds','Beds'],['theatre','Theatre']];
      const body = S.opsView==='appts'?`
        <div class="grid split2">
          <div class="card"><div class="card-h"><h3>Today's appointments</h3><span class="badge badge-sky">18</span></div>
            <div class="table-wrap"><table><tr><th>Time</th><th>Patient</th><th>Clinic</th><th>Status</th><th></th></tr>
              ${[['09:00','Mary Achieng','General OPD','Checked in','AMX-000002'],['09:30','John Otieno','General OPD','Confirmed','AMX-000001'],['10:00','Esther Nyambura','Respiratory','Confirmed','AMX-000004'],['10:30','Faith Njeri','Chronic care','Awaiting','AMX-000006'],['11:00','David Omondi','Diabetes','Confirmed','AMX-000003']].map(r=>`
              <tr style="cursor:pointer" onclick="selectPatientMRN('${r[4]}')"><td class="muted">${r[0]}</td><td><b>${r[1]}</b></td><td>${r[2]}</td><td><span class="state-pill state-active">${r[3]}</span></td><td>→</td></tr>`).join('')}
            </table></div></div>
          <div class="card"><div class="card-h"><h3>Scheduling</h3><span class="badge badge-amber">4 no-shows</span></div><div class="card-body" style="padding-top:var(--sp3)">
            <div class="fact"><div class="fc">+</div><div><b>Book appointment</b><p class="muted">Create a new slot for any patient</p></div></div>
            <div class="fact flag"><div class="fc">!</div><div><b>4 no-shows today</b><p class="muted">Call-back queue for rescheduling</p></div></div>
            <button class="btn btn-outline btn-block mt3" onclick="toast('Appointment booked (demo)','ok')">+ Book appointment</button>
          </div></div>
        </div>`
      : S.opsView==='admits'?`
        <div class="grid split2">
          <div class="card"><div class="card-h"><h3>Admissions</h3><span class="badge badge-sky">48 in wards</span></div>
            <div class="table-wrap"><table><tr><th>Patient</th><th>Ward</th><th>Bed</th><th>Admitted</th><th></th></tr>
              ${[['Faith Njeri','General medical','B-12','18 Aug'],['David Omondi','Medical (diabetes)','C-07','17 Aug'],['Esther Nyambura','Respiratory','A-03','18 Aug'],['Peter Kiprop','Paediatrics','P-02','18 Aug']].map(r=>`
              <tr><td><b>${r[0]}</b></td><td>${r[1]}</td><td class="mono">${r[2]}</td><td class="muted">${r[3]}</td><td><button class="btn btn-soft btn-sm" onclick="toast('Discharge workflow opened (demo)','ok')">Discharge</button></td></tr>`).join('')}
            </table></div></div>
          <div class="card"><div class="card-h"><h3>Admit patient</h3><span class="badge badge-amber">312/420 occupied</span></div><div class="card-body" style="padding-top:var(--sp3)">
            <div class="bar" style="height:10px;border-radius:var(--r-full);background:var(--neutral-100);overflow:hidden"><div style="height:100%;width:74%;background:linear-gradient(90deg,var(--sky-400),var(--primary))"></div></div>
            <div class="small muted mt2 mb3">74% occupancy — 108 beds free</div>
            <button class="btn btn-primary btn-block" onclick="toast('Admission request sent (demo)','ok')">+ New admission</button>
          </div></div>
        </div>`
      : S.opsView==='beds'?`
        <div class="grid split2">
          <div class="card"><div class="card-h"><h3>Ward occupancy</h3><span class="badge badge-sky">82%</span></div>
            <div class="card-body">${[['General medical',42,32],['Paediatrics',24,20],['Maternity',18,16],['Surgical',30,22]].map(([w,cap,occ])=>`
              <div class="mb3"><div class="row-b mb1"><b style="font-size:var(--sm)">${w}</b><span class="small muted">${occ}/${cap} free ${cap-occ}</span></div>
              <div class="bar"><div style="width:${Math.round(occ/cap*100)}%"></div></div></div>`).join('')}</div></div>
          <div class="card"><div class="card-h"><h3>Bed requests</h3><span class="badge badge-amber">5 waiting</span></div><div class="card-body" style="padding-top:var(--sp3)">
            ${['General medical — 2','Paediatrics — 2','Maternity — 1'].map(r=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><span style="font-size:var(--sm)">${r}</span><button class="btn btn-ghost btn-sm" onclick="toast('Bed assigned (demo)','ok')">Assign</button></div>`).join('')}
          </div></div>
        </div>`
      : S.opsView==='theatre'?`
        <div class="grid split2">
          <div class="card"><div class="card-h"><h3>Theatre list</h3><span class="badge badge-sky">3 today</span></div>
            <div class="table-wrap"><table><tr><th>Time</th><th>Procedure</th><th>Patient</th><th>Status</th></tr>
              ${[['08:00','C-section',PName('AMX-000011'),'Done'],['10:30','Wound debridement',PName('AMX-000009'),'In progress'],['14:00','Hernia repair',PName('AMX-000012'),'Scheduled']].map(r=>`
              <tr><td class="muted">${r[0]}</td><td><b>${r[1]}</b></td><td>${r[2]}</td><td><span class="state-pill ${r[3]==='Done'?'state-done':r[3]==='In progress'?'state-active':'state-pending'}">${r[3]}</span></td></tr>`).join('')}
            </table></div></div>
          <div class="card"><div class="card-h"><h3>Theatre availability</h3></div><div class="card-body">
            <div class="fact"><div class="fc" style="background:var(--success-light);color:var(--success)">✓</div><div><b>Theatre 1 — free 15:00</b><p class="muted">Next slot after hernia repair</p></div></div>
            <div class="fact flag"><div class="fc">!</div><div><b>Theatre 2 — occupied all day</b><p class="muted">C-section + emergency list</p></div></div>
            <button class="btn btn-outline btn-block mt3" onclick="toast('Theatre slot reserved (demo)','ok')">Reserve slot</button>
          </div></div>
        </div>`
      :`
        <div class="grid split2">
          <div class="card">
            <div class="card-h"><h3>Emergency queue</h3><span class="badge badge-red">3</span></div>
            <div class="table-wrap"><table>
              <tr><th>#</th><th>Patient</th><th>Presentation</th><th>Wait</th><th>Action</th></tr>
              ${[['AMX-000008','Respiratory distress','1h 10m','badge-red'],['AMX-000009','Chest pain','45m','badge-amber'],['AMX-000010','Abdominal pain','20m','badge-amber']].map((r,i)=>`<tr style="cursor:pointer" onclick="selectPatientMRN('${r[0]}');go('encounter')"><td class="muted">${i+1}</td><td><b>${PName(r[0])}</b></td><td>${r[1]}</td><td><span class="badge ${r[3]}">${r[2]}</span></td><td><button class="btn btn-soft btn-sm" onclick="event.stopPropagation();selectPatientMRN('${r[0]}');go('encounter')">Open</button></td></tr>`).join('')}
            </table></div>
          </div>
          <div>
            <div class="card mb4"><div class="card-h"><h3>Bed occupancy</h3></div><div class="card-body"><div class="row-b mb2"><span class="muted">Occupied</span><b>312 / 420</b></div><div class="bar" style="height:10px;border-radius:var(--r-full);background:var(--neutral-100);overflow:hidden"><div style="height:100%;width:74%;background:linear-gradient(90deg,var(--sky-400),var(--primary))"></div></div></div></div>
            <div class="card mb4"><div class="card-h"><h3>Referrals</h3><span class="badge badge-amber">4 pending</span></div><div class="card-body" style="padding-top:var(--sp3)">
              ${['ENC-000148 → Orthopaedics (KCH) — James Mwangi','ENC-000144 → Endocrinology (KTRH) — David Omondi','Ambulance → Nyanza General','Chronic care → Kisii County'].map(r=>`<div class="row-b" style="padding:7px 0;border-bottom:1px solid var(--neutral-100)"><span style="font-size:var(--sm)">${r}</span><button class="btn btn-ghost btn-sm" onclick="toast('Referral processed (demo)','ok')">→</button></div>`).join('')}
            </div></div>
          </div>
        </div>`;
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Operations</h1><p class="muted">Queues, appointments, admissions, beds, referrals and theatre.</p></div></div>
        <div class="tabs">${tabs.map(([id,label])=>`<button class="tab ${S.opsView===id?'active':''}" onclick="setOpsView('${id}')">${label}</button>`).join('')}</div>
        ${body}`;
      break;
    }
    /* ---------- DIAGNOSTICS ---------- */
    case 'diagnostics': {
      act('diagnostics'); crumb.innerHTML=crumbTrail('diagnostics'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Laboratory &amp; Imaging</h1><p class="muted">Orders, results and interpretation — connected to encounters.</p></div></div>
        <div class="grid cols-2">
          <div class="card"><div class="card-h"><h3>Recent results</h3><span class="badge badge-green">3 new</span></div><div class="table-wrap"><table>
            <tr><th>Test</th><th>Patient</th><th>Result</th><th>Status</th></tr>
            <tr><td><b>CBC</b><div class="tiny muted">ENC-000145</div></td><td>John Otieno</td><td class="mono">WBC 23.1 · Hb 9.8</td><td><span class="badge badge-red">High</span></td></tr>
            <tr><td><b>CRP</b><div class="tiny muted">ENC-000145</div></td><td>John Otieno</td><td class="mono">148 mg/L</td><td><span class="badge badge-red">High</span></td></tr>
            <tr><td><b>Chest X-ray</b><div class="tiny muted">ENC-000145</div></td><td>John Otieno</td><td>RLL consolidation</td><td><span class="badge badge-amber">Review</span></td></tr>
            <tr><td><b>HbA1c</b><div class="tiny muted">ENC-000144</div></td><td>David Omondi</td><td class="mono">8.2%</td><td><span class="badge badge-amber">Elevated</span></td></tr>
          </table></div></div>
          <div class="card"><div class="card-h"><h3>Pending orders</h3><span class="badge badge-sky">7</span></div><div class="card-body" style="padding-top:var(--sp3)">
            ${['Malaria screen — '+PName('AMX-000010'),'Blood glucose — '+PName('AMX-000003'),'Urine dipstick — '+PName('AMX-000006'),'ECG — '+PName('AMX-000009'),'X-ray wrist — '+PName('AMX-000014'),'RBS — '+PName('AMX-000008'),'Creatinine — '+PName('AMX-000002')].map(t=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><span style="font-size:var(--sm)">${t}</span><span class="badge badge-gray">Ordered 14:00</span></div>`).join('')}
          </div></div>
        </div>`;
      break;
    }
    /* ---------- PHARMACY ---------- */
    case 'pharmacy': {
      act('pharmacy'); crumb.innerHTML=crumbTrail('pharmacy'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Pharmacy</h1><p class="muted">Prescriptions, dispensing and medication history.</p></div></div>
        <div class="tabs"><span class="tab active">Dispensing</span><span class="tab" onclick="toast('Inventory view','ok')">Inventory</span><span class="tab" onclick="toast('Medication history','ok')">Medication history</span></div>
        <div class="grid cols-2">
          <div class="card"><div class="card-h"><h3>To dispense</h3></div><div class="table-wrap"><table>
            <tr><th>Patient</th><th>Medication</th><th>Qty</th><th></th></tr>
            <tr><td><b>John Otieno</b><div class="tiny muted mono">ENC-000145</div></td><td>Ceftriaxone 1g IV BD</td><td>6</td><td><button class="btn btn-soft btn-sm" onclick="toast('Dispensed (demo)','ok')">Dispense</button></td></tr>
            <tr><td><b>John Otieno</b><div class="tiny muted mono">ENC-000145</div></td><td>Azithromycin 500mg OD</td><td>3</td><td><button class="btn btn-soft btn-sm" onclick="toast('Dispensed (demo)','ok')">Dispense</button></td></tr>
            <tr><td><b>Mary Achieng</b><div class="tiny muted mono">ENC-000146</div></td><td>Amlodipine 5mg OD</td><td>30</td><td><button class="btn btn-soft btn-sm" onclick="toast('Dispensed (demo)','ok')">Dispense</button></td></tr>
          </table></div></div>
          <div class="card"><div class="card-h"><h3>Inventory alerts</h3></div><div class="card-body" style="padding-top:var(--sp3)">
            ${[['IV Ceftriaxone','Low stock — 12 vials','badge-amber'],['Paracetamol syrup','Re-stock tomorrow','badge-gray'],['Insulin glargine','In stock','badge-green'],['Azithromycin tabs','In stock','badge-green']].map(m=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><span style="font-size:var(--sm)"><b>${m[0]}</b><div class="tiny muted">${m[1]}</div></span><span class="badge ${m[2]}">${m[2]==='In stock'?'OK':'Action'}</span></div>`).join('')}
          </div></div>
        </div>`;
      break;
    }
    /* ---------- TELEMEDICINE ---------- */
    case 'telemedicine': {
      act('telemedicine'); crumb.innerHTML=crumbTrail('telemedicine'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Telemedicine</h1><p class="muted">Virtual consultations — the same encounter architecture.</p></div></div>
        <div class="grid split16">
          <div>
            <div class="video-mock mb3">
              <div style="text-align:center"><div style="font-size:26px;font-weight:700">Dr. Brian Kamau</div><div class="tiny" style="margin-top:4px">Virtual consultation — demo stream (no real video)</div></div>
              <div class="vp"><div style="text-align:center;font-size:11px;padding-top:30px">Patient</div></div>
              <div style="position:absolute;left:16px;bottom:16px" class="row gap1"><button class="btn btn-icon" style="background:rgba(255,255,255,.2)"><svg class="ic" viewBox="0 0 24 24"><path d="M4 6h11v9H4Z"/></svg></button><button class="btn btn-icon" style="background:rgba(255,255,255,.2)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8a3 3 0 1 0-3-3 3 3 0 0 0 3 3Zm0 2c-2.7 0-8 1.3-8 4v2h16v-2c0-2.7-5.3-4-8-4Z"/></svg></button><button class="btn btn-danger btn-icon"><svg class="ic" viewBox="0 0 24 24"><path d="M4 6h11v9H4Z"/></svg></button></div>
            </div>
            <div class="card"><div class="card-h"><h3>Chat</h3><span class="badge badge-sky">Secure</span></div><div class="card-body">
              <div class="fact"><div class="fc" style="background:var(--primary-light);color:var(--primary)">P</div><div><b>Patient</b><p>"Doctor, the cough started five days ago."</p></div></div>
              <div class="fact"><div class="fc" style="background:var(--sky-100);color:var(--sky-700)">D</div><div><b>Dr. Kamau</b><p>"Have you noticed any shortness of breath?"</p></div></div>
              <div class="row gap2 mt3"><input class="input grow" id="chatIn" placeholder="Type a message (demo)…"><button class="btn btn-primary" onclick="chatSend()">Send</button></div>
            </div></div>
          </div>
          <div>
            <div class="card mb4"><div class="card-h"><h3>Next appointments</h3></div><div class="card-body" style="padding-top:var(--sp3)">
              ${[[PName('AMX-000013'),'09:00','Video','badge-sky'],[PName('AMX-000002'),'11:30','Video','badge-sky'],[PName('AMX-000003'),'14:00','Phone','badge-gray'],[PName('AMX-000005'),'15:30','Video','badge-sky']].map(a=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><div><b style="font-size:var(--sm)">${a[0]}</b><div class="tiny muted">${a[2]} consultation</div></div><div class="row gap2"><span class="badge ${a[3]}">${a[1]}</span></div></div>`).join('')}
            </div></div>
            <div class="card"><div class="card-h"><h3>Shared record</h3></div><div class="card-body"><p class="small muted">Telemedicine encounters use the same clinical record and flow into the patient timeline automatically.</p></div></div>
          </div>
        </div>`;
      break;
    }
    /* ---------- RESEARCH ---------- */
    case 'research': {
      act('research'); crumb.innerHTML=crumbTrail('research'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Research</h1><p class="muted">De-identified demo cohorts. Access is governed separately from clinical access.</p>
        <span class="badge badge-gray" style="margin-top:6px">Governed access — research never shows identifiable patient data</span></div></div>
        <div class="grid cols-3 mb4">
          <div class="kpi"><div class="kpi-icon" style="background:#7c3aed"><svg class="ic" viewBox="0 0 24 24"><path d="M9 3v18M15 3v18M3 7h18M3 17h18"/></svg></div><div><div class="kpi-value">1,248</div><div class="kpi-label">Pneumonia cohort</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6"/></svg></div><div><div class="kpi-value">17</div><div class="kpi-label">Active studies</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M4 20h16M6 20V8l6-4 6 4v12"/></svg></div><div><div class="kpi-value">3</div><div class="kpi-label">Pending exports</div></div></div>
        </div>
        <div class="grid split14">
          <div class="card"><div class="card-h"><h3>Pneumonia Research Cohort</h3><button class="btn btn-outline btn-sm" onclick="toast('Export queued (demo)','ok')">Export CSV</button></div><div class="card-body">
            <div class="grid cols-2">
              <div><div class="small muted mb2">Age distribution</div><div class="chart" style="height:90px">${[5,9,14,21,30,26,18].map(h=>`<div class="c-bar" style="height:${h*3}%"></div>`).join('')}</div></div>
              <div><div class="small muted mb2">Severity</div><div class="chart" style="height:90px">${[62,28,10].map((h,i)=>`<div class="c-bar ${i===2?'':'low'}" style="height:${h*3}%"><span>${h}%</span></div>`).join('')}</div></div>
            </div>
            <table class="mt3"><tr><th>Outcome</th><th>Value</th><th>Trend</th></tr>
              <tr><td>Median length of stay</td><td>4.2 days</td><td class="text-primary">↓ 0.6 vs 2025</td></tr>
              <tr><td>30-day readmission</td><td>11%</td><td class="text-primary">↓ 2%</td></tr>
              <tr><td>Mortality</td><td>4.8%</td><td class="muted">Stable</td></tr>
            </table>
          </div></div>
          <div class="card"><div class="card-h"><h3>Studies</h3></div><div class="card-body" style="padding-top:var(--sp3)">
            ${['Community pneumonia outcomes','Antimicrobial stewardship','Maternal emergency trends','Asthma care gaps'].map(s=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${s}</b><span class="badge badge-green">Active</span></div>`).join('')}
          </div></div>
        </div>`;
      break;
    }
    /* ---------- REPORTS / HMIS ---------- */
    case 'reports': {
      act('reports'); crumb.innerHTML=crumbTrail('reports'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Reports / HMIS</h1><p class="muted">Structured data flowing into national reporting — dummy values.</p></div>
        <button class="btn btn-primary" onclick="toast('Monthly report generated (demo)','ok')">Generate monthly report</button></div>
        <div class="card mb4"><div class="card-h"><h3>Monthly facility report — ${fac?fac.name:'Facility'}</h3><span class="badge badge-sky">August 2026</span></div>
        <div class="table-wrap"><table>
          <tr><th>Indicator</th><th>Value</th><th>Indicator</th><th>Value</th></tr>
          <tr><td>OPD visits</td><td><b>4,821</b></td><td>Pneumonia cases</td><td><b>317</b></td></tr>
          <tr><td>Admissions</td><td><b>832</b></td><td>TB notifications</td><td><b>41</b></td></tr>
          <tr><td>Deliveries</td><td><b>214</b></td><td>Maternal emergencies</td><td><b>12</b></td></tr>
          <tr><td>Major surgeries</td><td><b>156</b></td><td>Referrals out</td><td><b>48</b></td></tr>
        </table></div></div>
        <div class="grid cols-2">
          <div class="card"><div class="card-h"><h3>Weekly trend — OPD</h3></div><div class="card-body"><div class="chart">${[72,84,91,78,95,88,101].map(h=>`<div class="c-bar" style="height:${h}%"><span>${h*10}</span></div>`).join('')}</div></div></div>
          <div class="card"><div class="card-h"><h3>Notifiable diseases (YTD)</h3></div><div class="card-body" style="padding-top:var(--sp3)">
            ${[['Cholera',0,'badge-green'],['Measles',2,'badge-green'],['Malaria',1204,'badge-amber'],['TB',382,'badge-sky'],['Chikungunya',7,'badge-green']].map(d=>`<div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><b style="font-size:var(--sm)">${d[0]}</b><span class="badge ${d[2]}">${d[1]}</span></div>`).join('')}
          </div></div>
        </div>`;
      break;
    }
    /* ---------- CODING ---------- */
    case 'coding': {
      act('coding'); crumb.innerHTML=crumbTrail('coding'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">ICD-11 coding</h1><p class="muted">Clinician language → clinical concept → terminology → code.</p></div></div>
        <div class="grid split11">
          <div class="card"><div class="card-h"><h3>Diagnosis from assessment</h3></div><div class="card-body">
            <div class="fact"><div class="fc" style="background:var(--success-light);color:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div><div><b>${S.dx}</b><p class="muted">Signed by Dr. Kamau</p></div></div>
            <div class="field mt3"><label>Search terminology</label><div class="input-group"><svg class="ic" viewBox="0 0 24 24" style="position:absolute;left:12px;top:50%;transform:translateY(-50%);color:var(--text-muted)"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg><input class="input" id="icdSearch" placeholder="e.g. pneumonia" oninput="icdFilter()"></div></div>
            <div id="icdList" class="mt2"></div>
          </div></div>
          <div class="card"><div class="card-h"><h3>Selected code</h3><span class="badge badge-sky">Auto-suggested (demo)</span></div><div class="card-body">
            <div class="row gap2" style="padding:12px;border:1px solid var(--primary-border);background:var(--sky-50);border-radius:var(--r-md)"><div style="font-size:22px;font-weight:800;color:var(--primary)">${S.dxCode}</div><div><b>${S.dx}</b><div class="tiny muted">Confidence ${S.dxConf}% — demo intelligence</div></div></div>
            <div class="mt3"><div class="small muted mb2">Concept path</div>
              <div class="fact"><div class="fc">①</div><div><b>Clinician language</b><p>"Severe pneumonia"</p></div></div>
              <div class="fact"><div class="fc">②</div><div><b>Clinical concept</b><p>Lower respiratory infection — severe</p></div></div>
              <div class="fact"><div class="fc">③</div><div><b>Terminology</b><p>Community-acquired pneumonia</p></div></div>
              <div class="fact"><div class="fc" style="background:var(--primary-light);color:var(--primary)">✓</div><div><b>ICD-11 code</b><p class="mono">${S.dxCode}</p></div></div>
            </div>
          </div></div>
        </div>`;
      icdFilter();
      break;
    }
    /* ---------- DOCUMENTS ---------- */
    case 'documents': {
      act('documents'); crumb.innerHTML=crumbTrail('documents'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Documents</h1><p class="muted">Generated from captured clinical facts — nothing is free-text authored by the UI.</p></div>
        <button class="btn btn-primary" onclick="renderDoc('note')">Clinical encounter note</button></div>
        <div class="grid cols-2">
          <div class="card"><div class="card-h"><h3>Library</h3></div><div class="table-wrap"><table>
            <tr><th>Document</th><th>Patient</th><th>Date</th><th></th></tr>
            ${[['Clinical encounter note — ENC-000145','John Otieno','Today',1],['Discharge summary','Faith Njeri','18 Aug',0],['Referral letter — ortho','Brian Mose','17 Aug',0],['Prescription — Ceftriaxone','John Otieno','Today',1],['Medical certificate','David Omondi','18 Aug',0]].map(d=>`<tr><td><b style="font-size:var(--sm)">${d[0]}</b></td><td class="muted">${d[1]}</td><td class="muted">${d[2]}</td><td><button class="btn btn-outline btn-sm" onclick="renderDoc('note')">Preview</button></td></tr>`).join('')}
          </table></div></div>
          <div class="card"><div class="card-h"><h3>Documentation modes</h3></div><div class="card-body" style="padding-top:var(--sp3)">
            <div class="tabs" style="margin-bottom:var(--sp3)"><span class="tab active">Full note</span><span class="tab" onclick="renderDoc('soap')">SOAP</span><span class="tab" onclick="renderDoc('short')">Shorthand</span></div>
            <div id="docPreview" style="max-height:420px;overflow-y:auto"></div>
            <div class="row gap2 mt3"><button class="btn btn-outline btn-sm" onclick="renderDoc('short')">Shorthand</button><button class="btn btn-outline btn-sm" onclick="window.print()">Print / PDF</button></div>
          </div></div>
        </div>`;
      renderDoc('note');
      break;
    }
    /* ---------- INTEGRATIONS ---------- */
    case 'integrations': {
      if(S.role==='admin' && window.facilityScreen){ const h=facilityScreen('integrations'); if(h){ act('integrations'); crumb.innerHTML=crumbTrail('integrations'); c.innerHTML=h; break; } }
      act('integrations'); crumb.innerHTML=crumbTrail('integrations'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Integrations</h1><p class="muted">Where AMEXAN connects outward. All connections are simulated.</p></div></div>
        <div class="card mb4"><div class="card-h"><h3>Interoperability overview</h3><span class="badge badge-amber">Demo connections</span></div>
        <div class="card-body"><div class="grid cols-2">${INTEGRATIONS.map(i=>`<div class="fact"><div class="fc" style="background:${i.color}22;color:${i.color}"><span class="dot" style="background:${i.color}"></span></div><div><b>${i.name}</b><p>${i.note}</p><span class="badge ${i.badge.includes('PENDING')?'badge-amber':'badge-green'}">${i.badge}</span></div></div>`).join('')}</div></div></div>
        <div class="card"><div class="card-h"><h3>Conceptual flow</h3></div><div class="card-body"><div class="grid cols-3 center" style="align-items:center">
          <div class="card card-pad"><b>AMEXAN</b><div class="tiny muted">Clinical record</div></div>
          <div class="text-primary" style="font-size:24px">→</div>
          <div class="card card-pad"><b>Interoperability UI</b><div class="tiny muted">Registry • Exchange • Claims</div></div>
          <div class="text-primary" style="font-size:24px">→</div>
          <div class="card card-pad"><b>DHA / HIE / HMIS</b><div class="tiny muted">National systems</div></div>
        </div><p class="small muted center mt3">Prototype shows <b>DEMO CONNECTION</b> until the real integration is implemented.</p></div></div>`;
      break;
    }
    /* ---------- GOVERNANCE ---------- */
    case 'governance': {
      act('governance'); crumb.innerHTML=crumbTrail('governance'); ctx();
      const log=S.audit.length?S.audit:[{t:'17:30',msg:'Dr. Kamau opened ENC-000145'},{t:'17:31',msg:'Chief complaint recorded'},{t:'17:32',msg:'HPI fact captured'},{t:'17:40',msg:'CBC result reviewed'},{t:'17:41',msg:'Assessment signed'},{t:'17:45',msg:'Encounter updated — plan created'}];
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Governance &amp; Audit</h1><p class="muted">Users, roles, permissions, privacy and the audit trail.</p></div></div>
        <div class="grid split11">
          <div class="card mb4"><div class="card-h"><h3>Access control</h3><button class="btn btn-outline btn-sm" onclick="toast('User management (demo)','ok')">Manage</button></div><div class="table-wrap"><table>
            <tr><th>User</th><th>Role</th><th>Status</th></tr>
            <tr><td><b>Dr. Brian Kamau</b><div class="tiny muted">dr-kamau@ktrh.ke</div></td><td><span class="badge badge-sky">Clinician</span></td><td><span class="badge badge-green">Active</span></td></tr>
            <tr><td><b>Sarah Ochieng</b><div class="tiny muted">sarah@ktrh.ke</div></td><td><span class="badge badge-sky">Facility Admin</span></td><td><span class="badge badge-green">Active</span></td></tr>
            <tr><td><b>Grace Moraa</b><div class="tiny muted">grace@ktrh.ke</div></td><td><span class="badge badge-sky">Clinician</span></td><td><span class="badge badge-green">Active</span></td></tr>
            <tr><td><b>County DHO</b><div class="tiny muted">dho@kisii.ke</div></td><td><span class="badge badge-gray">Public Health</span></td><td><span class="badge badge-amber">Session</span></td></tr>
          </table></div></div>
          <div class="card mb4"><div class="card-h"><h3>Audit trail</h3><span class="badge badge-sky">Live</span></div><div class="card-body" style="padding-top:var(--sp3)"><div class="tl" style="max-height:360px;overflow-y:auto">${log.map(a=>`<div class="tl-item"><div class="tl-time">${a.t}</div><div class="tl-title">${a.msg}</div></div>`).join('')}</div></div></div>
        </div>
        <div class="grid cols-3">
          <div class="card card-pad"><b>Privacy</b><p class="small muted mt1">Role-based access, consent flags and de-identification for research.</p></div>
          <div class="card card-pad"><b>Security</b><p class="small muted mt1">Demo session only. No real credentials or patient data are stored.</p></div>
          <div class="card card-pad"><b>Compliance</b><p class="small muted mt1">Prepared for Kenya health-data regulations; nothing transmitted.</p></div>
        </div>`;
      break;
    }
    /* ---------- BILLING ---------- */
    case 'billing': {
      act('billing'); crumb.innerHTML=crumbTrail('billing'); ctx();
      c.innerHTML=`
        <div class="row-b mb4"><div><h1 style="font-size:var(--2xl)">Billing &amp; Claims</h1><p class="muted">Invoices, payments and payer claims — simulated.</p></div></div>
        <div class="grid cols-3 mb4">
          <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 3h14v18l-2-1-2 1-2-1-2 1-2-1-2 1Z"/></svg></div><div><div class="kpi-value">KSh 184,200</div><div class="kpi-label">Outstanding today</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg></div><div><div class="kpi-value">78%</div><div class="kpi-label">Collection rate</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:var(--warning)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 9v5M12 17h.01"/></svg></div><div><div class="kpi-value">23</div><div class="kpi-label">Claims in review</div></div></div>
        </div>
        <div class="card"><div class="card-h"><h3>Invoices</h3><button class="btn btn-outline btn-sm" onclick="toast('New invoice (demo)','ok')">+ New</button></div>
        <div class="table-wrap"><table><tr><th>Invoice</th><th>Patient</th><th>Encounter</th><th>Amount</th><th>Status</th></tr>
          ${[['INV-2041','John Otieno','ENC-000145','KSh 18,400','badge-amber','Pending'],['INV-2040','Mary Achieng','ENC-000146','KSh 6,200','badge-green','Paid'],['INV-2039','David Omondi','ENC-000144','KSh 9,800','badge-green','Paid'],['INV-2038','Brian Mose','ENC-000141','KSh 22,100','badge-amber','Pending']].map(i=>`<tr><td class="mono">${i[0]}</td><td><b>${i[1]}</b></td><td class="mono muted">${i[2]}</td><td>${i[3]}</td><td><span class="badge ${i[4]}">${i[5]}</span></td></tr>`).join('')}
        </table></div></div>`;
      break;
    }
    /* ---------- PATIENT WORKSPACE ---------- */
    case 'patient': {
      act('patient'); crumb.innerHTML=crumbTrail('patient'); ctx();
      const tabs=[['overview','Overview'],['encounter','Encounter'],['history','History'],['results','Results'],['documents','Documents']];
      const eCur=ENCOUNTERS.find(x=>x.mrn===p.mrn && x.status!=='Completed') || ENCOUNTERS.find(x=>x.mrn===p.mrn) || null;
      const ccNow=ccText();
      c.innerHTML=`
        <div class="card mb4" style="padding:var(--sp4) var(--sp5)">
          <div class="row-b wrap gap3">
            <div class="row gap3 wrap">
              <div style="width:56px;height:56px;border-radius:16px;background:${p.color};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:20px;flex-shrink:0">${p.avat}</div>
              <div>
                <div class="row gap2 wrap"><h1 style="font-size:var(--xl)">${p.name}</h1><span class="badge badge-gray">${p.sex} ${p.ageLabel||(p.age+' yrs')}</span><span class="badge badge-sky mono">${p.mrn}</span></div>
                <div class="row gap3 small muted wrap mt1"><span>${p.occupation}</span><span>•</span><span>${p.phone}</span><span>•</span><span>${p.address}</span><span>•</span><span>DOB ${p.dob}</span></div>
              </div>
            </div>
            <div class="row gap2 wrap">
              ${eCur?`<button class="btn btn-primary btn-sm" onclick="go('encounter')">Open current encounter</button>`:`<button class="btn btn-primary btn-sm" onclick="toast(&quot;New encounter (demo)&quot;,'ok');go('encounter')">Start encounter</button>`}
              <button class="btn btn-outline btn-sm" onclick="showPatientModal()">Details</button>
            </div>
          </div>
          <div class="row-b wrap gap2 mt3" style="border-top:1px solid var(--border);padding-top:var(--sp3)">
            <div class="row gap3 wrap">
              ${eCur?`<div><div class="tiny muted uppercase">Current encounter</div><b>${eCur.id}</b> <span class="badge badge-sky">${eCur.type}</span> <span class="state-pill ${eCur.status==='In progress'?'state-active':eCur.status==='Completed'?'state-done':'state-pending'}">${eCur.status}</span> <span class="small muted">· ${ccNow||eCur.cc}</span></div>`:'<div class="tiny muted">No active encounter</div>'}
            </div>
            <div class="tabs" style="margin:0">
              ${tabs.map(t=>`<span class="tab ${S.ptab===t[0]?'active':''}" onclick="S.ptab='${t[0]}';renderScreen('patient')">${t[1]}</span>`).join('')}
            </div>
          </div>
        </div>
        <div id="pTabBody">${
          S.ptab==='overview'?renderPOverview()
          : S.ptab==='encounter'?renderPEncounter()
          : S.ptab==='history'?renderPHistory()
          : S.ptab==='results'?renderPResults()
          : renderPDocs()
        }</div>`;
      break;
    }
    /* ---------- PATIENT PORTAL ---------- */
    case 'portal': {
      act('portal'); crumb.innerHTML=crumbTrail('portal'); ctx();
      const my=PATIENTS[0];
      c.innerHTML=`
        <div class="row-b wrap mb4">
          <div>
            <h1 style="font-size:var(--2xl)">Hello, ${my.name.split(' ')[0]}</h1>
            <p class="muted">Your personal health record at ${fac?fac.name:'your facility'} — view-only demo.</p>
          </div>
          <button class="btn btn-outline btn-sm" onclick="go('auth')">Switch account</button>
        </div>
        <div class="grid cols-4 mb4">
          <div class="kpi"><div class="kpi-icon" style="background:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/></svg></div><div><div class="kpi-value">4</div><div class="kpi-label">Visits</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:var(--success)"><svg class="ic" viewBox="0 0 24 24"><path d="M9 3v18M15 3v18M3 7h18M3 17h18"/></svg></div><div><div class="kpi-value">6</div><div class="kpi-label">Results</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:var(--warning)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z"/></svg></div><div><div class="kpi-value">2</div><div class="kpi-label">Medications</div></div></div>
          <div class="kpi"><div class="kpi-icon" style="background:#7c3aed"><svg class="ic" viewBox="0 0 24 24"><path d="M7 3v4M17 3v4M3 10h18M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z"/></svg></div><div><div class="kpi-value">1</div><div class="kpi-label">Next appointment</div></div></div>
        </div>
        <div class="grid split2">
          <div>
            <div class="card mb4">
              <div class="card-h"><h3>My recent visits</h3><button class="btn btn-ghost btn-sm" onclick="toast('All visits (demo)','ok')">View all →</button></div>
              <div class="table-wrap"><table>
                <tr><th>Date</th><th>Facility</th><th>Reason</th><th>Clinician</th><th>Status</th></tr>
                ${[['19 Aug 2026','KTRH','Cough for 5 days','Dr. Brian Kamau','In progress'],['12 Aug 2026','KTRH','Asthma review','Dr. Grace Moraa','Completed'],['28 Jul 2026','KTRH','Routine check-up','Dr. Brian Kamau','Completed'],['09 Jul 2026','Christamarie HC','Allergic reaction','Dr. Nyaberi','Completed']].map(v=>`<tr><td>${v[0]}</td><td>${v[1]}</td><td><b>${v[2]}</b></td><td class="muted">${v[3]}</td><td><span class="state-pill ${v[4]==='In progress'?'state-active':'state-done'}">${v[4]}</span></td></tr>`).join('')}
              </table></div>
            </div>
            <div class="card mb4">
              <div class="card-h"><h3>My medications</h3></div>
              <div class="card-body" style="padding-top:var(--sp3)">
                <div class="fact"><div class="fc" style="background:var(--primary-light);color:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z"/></svg></div><div><b>Salbutamol inhaler</b><p class="muted">2 puffs PRN — as needed for wheeze</p></div></div>
                <div class="fact"><div class="fc" style="background:var(--primary-light);color:var(--primary)"><svg class="ic" viewBox="0 0 24 24"><path d="M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z"/></svg></div><div><b>Montelukast 10mg</b><p class="muted">Once nightly</p></div></div>
              </div>
            </div>
          </div>
          <div>
            <div class="card mb4">
              <div class="card-h"><h3>Next appointment</h3></div>
              <div class="card-body">
                <div class="badge badge-sky" style="font-size:var(--sm)">Sat 23 Aug 2026 · 09:00</div>
                <p class="small muted mt2">Follow-up after your recent encounter at the General OPD clinic.</p>
                <button class="btn btn-primary btn-block mt3" onclick="toast('Appointment reminder set (demo)','ok')">Get reminder</button>
              </div>
            </div>
            <div class="card mb4">
              <div class="card-h"><h3>Latest results</h3></div>
              <div class="card-body" style="padding-top:var(--sp3)">
                <div class="fact"><div class="fc"><span class="dot dot-red"></span></div><div><b>CBC — 19 Aug</b><p class="mono">WBC 23.1 · Hb 9.8 · PLT 312</p></div></div>
                <div class="fact"><div class="fc"><span class="dot dot-amber"></span></div><div><b>Chest X-ray — 19 Aug</b><p class="muted">Right lower lobe consolidation</p></div></div>
              </div>
            </div>
            <div class="card">
              <div class="card-h"><h3>Privacy</h3></div>
              <div class="card-body small muted">This portal is a demo. In production, data is shared through the DHA Shared Health Record with your consent.</div>
            </div>
          </div>
        </div>`;
      break;
    }
    /* ---------- CLINICIAN OS: WARD ---------- */
    case 'ward': {
      act('ward'); crumb.innerHTML=crumbTrail('ward'); ctx();
      c.innerHTML=renderWardScreen();
      break;
    }
    case 'round': {
      act('round'); crumb.innerHTML=crumbTrail('round'); ctx();
      c.innerHTML=renderRoundScreen();
      renderClinical();
      break;
    }
    case 'handover': {
      act('handover'); crumb.innerHTML=crumbTrail('handover'); ctx();
      c.innerHTML=renderHandoverScreen();
      break;
    }
    case 'clinic': {
      act('clinic'); crumb.innerHTML=crumbTrail('clinic'); ctx();
      c.innerHTML=renderClinicScreen();
      break;
    }
    case 'results': {
      act('results'); crumb.innerHTML=crumbTrail('results'); ctx();
      c.innerHTML=renderResultsScreen();
      break;
    }
    case 'discharge': {
      act('discharge'); crumb.innerHTML=crumbTrail('discharge'); ctx();
      c.innerHTML=renderDischargeScreen();
      break;
    }
    default: {
      if(window.facilityScreen){
        const html = facilityScreen(name);
        if(html){
          act(name); crumb.innerHTML = crumbTrail(name); c.innerHTML = html;
          break;
        }
      }
      c.innerHTML='<div class="empty"><div class="ei"><svg class="ic" viewBox="0 0 24 24"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Z"/></svg></div><h3>Module under construction</h3><p>This screen is part of the roadmap. Choose a module from the menu.</p></div>';
    }
  }
}

function patientRow(p){ return `<tr style="cursor:pointer" onclick="selectPatient('${p.mrn}');go('patient')"><td><b>${p.name}</b><div class="tiny muted">${p.avat}</div></td><td class="mono">${p.mrn}</td><td>${p.ageLabel||(p.age+' yrs')} / ${p.sex}</td><td>${p.conditions.length?p.conditions.join(', '):'<span class="muted">—</span>'}</td><td class="muted">${p.phone}</td><td><span class="badge ${p.status==='Active'?'badge-green':'badge-gray'}">${p.status}</span></td><td>→</td></tr>`; }

/* ---------- PATIENT WORKSPACE TABS ---------- */
function renderPOverview(){
  const p=S.patient, eCur=ENCOUNTERS.find(x=>x.mrn===p.mrn && x.status!=='Completed') || null;
  const alerts=[];
  if(p.allergies.length) alerts.push(`<div class="fact flag"><div class="fc">!</div><div><b>Allergy: ${p.allergies.join(', ')}</b><p>Flagged on the patient record</p></div></div>`);
  if(p.mrn==='AMX-000008') alerts.push(`<div class="fact flag"><div class="fc">!</div><div><b>Respiratory distress</b><p>ENC-000147 · SpO₂ 84% — urgent</p></div></div>`);
  const recent=ENCOUNTERS.filter(x=>x.mrn===p.mrn && x.status==='Completed').slice(0,3);
  return `
    <div class="grid split2">
      <div class="stack gap4">
        <div class="card"><div class="card-h"><h3>Current concern</h3></div><div class="card-body">
          ${eCur?`<b style="font-size:var(--md)">${ccText()||eCur.cc}</b><p class="muted">${eCur.id} · ${eCur.type} · ${eCur.date}</p>`:'<p class="muted">No active encounter.</p>'}
          <button class="btn btn-primary btn-block mt3" onclick="go('encounter')">Open encounter workspace</button>
        </div></div>
        <div class="card"><div class="card-h"><h3>Clinical summary</h3></div><div class="card-body">
          <div class="row-b" style="padding:7px 0"><span class="muted">Known conditions</span><b>${p.conditions.length?p.conditions.join(', '):'None documented'}</b></div>
          <div class="row-b" style="padding:7px 0"><span class="muted">Allergies</span><b>${p.allergies.length?p.allergies.join(', '):'No known allergies'}</b></div>
          <div class="row-b" style="padding:7px 0"><span class="muted">Current medications</span><b>${S.plan.meds.length?S.plan.meds.join(', '):'None recorded'}</b></div>
          <div class="row-b" style="padding:7px 0"><span class="muted">Blood group</span><b class="mono">${p.blood}</b></div>
          <div class="row-b" style="padding:7px 0"><span class="muted">Next of kin</span><b>${p.kin} · ${p.kinPhone}</b></div>
        </div></div>
        <div class="card"><div class="card-h"><h3>Clinical alerts</h3></div><div class="card-body" style="padding-top:var(--sp3)">${alerts.join('')||'<div class="empty" style="padding:var(--sp4)"><p>No alerts.</p></div>'}</div></div>
      </div>
      <div class="card"><div class="card-h"><h3>Recent encounters</h3><button class="btn btn-ghost btn-sm" onclick="S.ptab='history';renderScreen('patient')">Timeline →</button></div>
        <div class="table-wrap"><table><tr><th>Date</th><th>Type</th><th>Reason</th><th>Status</th></tr>
          ${ENCOUNTERS.filter(x=>x.mrn===p.mrn).map(x=>`<tr style="cursor:pointer" onclick="selectPatient('${p.mrn}');go('encounter')"><td class="muted">${x.date}</td><td><span class="badge badge-gray">${x.type}</span></td><td><b>${x.cc}</b></td><td><span class="state-pill ${x.status==='Completed'?'state-done':x.status==='In progress'?'state-active':'state-pending'}">${x.status}</span></td></tr>`).join('')||'<tr class="empty-row"><td colspan="4">No previous encounters.</td></tr>'}
        </table></div></div>
    </div>`;
}
function renderPEncounter(){
  const eCur=ENCOUNTERS.find(x=>x.mrn===S.patient.mrn && x.status!=='Completed') || null;
  if(!eCur) return `<div class="empty" style="padding:var(--sp6)"><div class="ei"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/></svg></div><h3>No active encounter</h3><p>This patient has no current encounter.</p><button class="btn btn-primary mt3" onclick="toast('New encounter (demo)','ok');go('encounter')">Start new encounter</button></div>`;
  const e=eCur;
  return `
    <div class="card"><div class="card-h"><h3>${e.id}</h3><span class="badge badge-sky">${e.type}</span><span class="state-pill state-active">${e.status}</span></div>
      <div class="card-body">
        <div class="row-b mb3"><span class="muted">${e.date} · ${e.clinician} · ${e.queue}</span></div>
        <div class="row gap2 mb3"><b>Presenting concern</b><span class="badge badge-sky">${ccText()||e.cc}</span></div>
        <div class="mb3"><div class="tiny muted uppercase mb1" style="margin-bottom:6px">Progress</div>
          <div class="qdots">${ENC_STEPS.map((s,i)=>`<span class="${S.stepDone.includes(i)?'on':''} ${S.step===i?'cur':''}" title="${s}"></span>`).join('')}</div>
          <div class="small muted mt1">${S.stepDone.length}/${ENC_STEPS.length} sections complete · current: ${ENC_STEPS[S.step]||ENC_STEPS[8]}</div>
        </div>
        <div class="next-strip" style="margin-bottom:0"><span class="badge badge-sky">NEXT</span><span><b>${ENC_STEPS[Math.min(S.step,8)]}</b> — the system knows the next useful action.</span><button class="btn btn-primary btn-sm" onclick="go('encounter')">Continue →</button></div>
      </div></div>`;
}
function renderPHistory(){
  const all=TIMELINE.filter(t=>t.mrn===S.patient.mrn);
  const typeChip={Encounter:['badge-sky','Encounter'],Laboratory:['badge-purple','Lab'],Pharmacy:['badge-green','Rx'],Immunisation:['badge-amber','IM'],Document:['badge-gray','Doc'],Clinical:['badge-sky','Clinical']};
  const cats=['All',...new Set(all.map(t=>t.type))];
  const items=all.filter(t=>S.tlFilter==='All'||t.type===S.tlFilter);
  return `
    <div class="card"><div class="card-h"><h3>Timeline</h3><span class="badge badge-sky">${items.length} events</span></div>
      <div class="card-body">
        <div class="row gap2 wrap mb3">${cats.map(cat=>`<button class="chip ${S.tlFilter===cat?'active':''}" onclick="S.tlFilter='${cat}';renderScreen('patient')">${cat}</button>`).join('')}</div>
        <div class="tl">${items.length?items.map(t=>`<div class="tl-item"><div class="tl-time">${t.date} · ${t.time}</div><div class="tl-title">${t.title}<span class="badge ${(typeChip[t.type]||['badge-gray'])[0]}" style="margin-left:8px">${(typeChip[t.type]||[t.type])[1]||t.type}</span></div><div class="tl-desc">${t.detail}</div></div>`).join(''):'<div class="empty" style="padding:var(--sp4)"><p>No previous events recorded at this facility.</p></div>'}</div>
      </div></div>`;
}
function renderPResults(){
  const e=S.encounter, inv=S.inv, rev=S.reviewed;
  const rows=[['CBC',inv.cbc||'Pending',rev.cbc],['CRP',inv.crp||'Pending',rev.crp],['Chest X-ray',inv.cxr||'Pending',rev.cxr]];
  return `
    <div class="card"><div class="card-h"><h3>Investigations &amp; results</h3><span class="badge badge-sky">${rows.filter(r=>r[2]).length} reviewed</span></div>
      <div class="table-wrap"><table><tr><th>Test</th><th>Result</th><th>Status</th><th></th></tr>
        ${rows.map(r=>`<tr><td><b>${r[0]}</b></td><td class="mono">${r[1]}</td><td><span class="state-pill ${r[1]==='Pending'?'state-pending':r[2]?'state-done':'state-active'}">${r[1]==='Pending'?'Pending':r[2]?'Reviewed':'Available'}</span></td><td>${r[1]!=='Pending'&&!r[2]?`<button class="btn btn-primary btn-sm" onclick="reviewResult('${r[0].toLowerCase().replace(/[^a-z]/g,'')}')">Review</button>`:''}</td></tr>`).join('')}
      </table></div></div>`;
}
function renderPDocs(){
  const p=S.patient;
  const docs=[
    {t:'Clinical encounter note', d:'Full note generated from captured facts', icon:'M6 2h9l4 4v16H6Z', go:'documents'},
    {t:'Referral letter', d:'To Kenyatta County Hospital (KCH)', icon:'M12 3a9 9 0 1 0 9 9M12 3v8l6 4', go:'documents'},
    {t:'Discharge summary', d:'For the most recent admission', icon:'M4 20h16M6 20V8l6-4 6 4v12', go:'documents'},
    {t:'Laboratory report', d:'CBC · CRP · Chest X-ray', icon:'M6 3v12M18 3v6M6 9h12', go:'diagnostics'},
    {t:'Consent for treatment', d:'Signed digitally (demo)', icon:'M9 12l2 2 4-4M12 2l8 4v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6Z', go:'documents'}
  ];
  return `<div class="grid cols-2">${docs.map(d=>`<div class="card card-hover" style="cursor:pointer" onclick="go('${d.go}')"><div class="card-h"><span style="width:36px;height:36px;border-radius:10px;background:var(--primary-light);color:var(--primary);display:inline-flex;align-items:center;justify-content:center"><svg class="ic" viewBox="0 0 24 24"><path d="${d.icon}"/></svg></span><div><b>${d.t}</b><p class="muted">${d.d}</p></div></div></div>`).join('')}</div>`;
}


/* ---------- FILTERS ---------- */
function filterPatients(){
  const q=($('patSearch').value||'').toLowerCase();
  const rows=PATIENTS.filter(p=>!q||p.name.toLowerCase().includes(q)||p.mrn.toLowerCase().includes(q));
  $('patRows').innerHTML = rows.length
    ? rows.map(patientRow).join('')
    : `<tr class="empty-row"><td colspan="6"><svg class="ic" viewBox="0 0 24 24"><path d="M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm10 17-5-5"/></svg><div style="margin-top:8px">No patients match “${q}”. Try another name or MRN, or <a href="#" onclick="go('register');return false">register a new patient</a>.</div></td></tr>`;
}

/* ---------- REGISTER ---------- */
function registerPatient(){
  const f=$('regFirst').value.trim(), l=$('regLast').value.trim();
  if(!f||!l){ toast('Please enter first and last name','err'); return; }
  const n=f+' '+l;
  const p={mrn:'AMX-0000'+(PATIENTS.length+1),name:n,sex:$('regSex').value,age:new Date().getFullYear()-new Date($('regDob').value).getFullYear(),dob:$('regDob').value,phone:$('regPhone').value||'—',kin:$('regKin').value||'—',kinPhone:'—',blood:$('regBlood').value,allergies:[],conditions:[],occupation:'—',address:$('regAddr').value||'—',status:'Registered',avat:f[0]+(l[0]||''),color:'#0284c7'};
  PATIENTS.unshift(p); auditLog(`New patient registered — ${n} (${p.mrn})`);
  toast(`Patient ${n} registered (demo)`,'ok');
  S.patient=p; go('patients');
}

/* ---------- ICD-11 SEARCH ---------- */
function icdFilter(){
  const el=$('icdList'); if(!el) return;
  const q=($('icdSearch')?.value||'').toLowerCase();
  const list = ICD11.filter(i=>!q || i.label.toLowerCase().includes(q) || i.syn.some(s=>s.includes(q)));
  el.innerHTML = list.map(i=>`<div class="fact" style="cursor:pointer" onclick="pickCode('${i.code}')"><div class="fc mono" style="background:var(--sky-100);color:var(--sky-700)">${i.code}</div><div><b>${i.label}</b><p class="muted">${i.syn.slice(0,3).join(' · ')}</p></div><span style="margin-left:auto;color:var(--primary)">+</span></div>`).join('') || '<div class="empty"><p>No concepts match. Try "pneumonia" or "headache".</p></div>';
}
function pickCode(c){ const i=ICD11.find(x=>x.code===c); if(i){ S.dx=i.label; S.dxCode=i.code; renderScreen('coding'); renderDoc('note'); toast(`Code ${i.code} selected (demo)`,'ok'); } }

/* ---------- TELEMEDICINE CHAT ---------- */
function chatSend(){ const i=$('chatIn'); if(i&&i.value.trim()){ toast('Message sent (demo)','ok'); i.value=''; } }