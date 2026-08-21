/* ---------- ENCOUNTER STEPPER ---------- */
function setStep(i){
  const prevDone = i>0 && S.stepDone.includes(i-1);
  if(i>S.step && !prevDone && !S.stepDone.includes(i)){ toast('Complete earlier steps first','warn'); return; }
  S.step=i; saveEnc(); renderEncounterScreen(); renderClinical();
}
function addCc(){ const t=$('ccText')&&$('ccText').value.trim(); if(!t){toast('Enter the concern first','warn');return;} const d=$('ccDur')?$('ccDur').value:''; S.ccs.push({text:t,dur:d}); if($('ccText'))$('ccText').value=''; if($('ccDur'))$('ccDur').value=''; auditLog('Chief complaint recorded — '+t+(d?' ('+d+')':'')); renderClinical(); saveEnc(); renderStep(); }
function removeCc(i){ S.ccs.splice(i,1); renderClinical(); saveEnc(); renderStep(); }
function stepDone(i){ if(!S.stepDone.includes(i))S.stepDone.push(i); }
function renderEncounterScreen(){ renderScreen('encounter'); }

/* ---------- STEP BODIES ---------- */
function renderStep(){
  const b=$('stepBody'); if(!b) return;
  const p=S.patient, e=S.encounter, st=S;
  const bodies={
    0:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Biodata verification</h3>
      <div class="grid cols-3">
        <div class="field"><label>Full name</label><input class="input" value="${p.name}" readonly></div>
        <div class="field"><label>MRN</label><input class="input mono" value="${p.mrn}" readonly></div>
        <div class="field"><label>Date of birth</label><input class="input" value="${p.dob}" readonly></div>
        <div class="field"><label>Sex</label><input class="input" value="${p.sex}" readonly></div>
        <div class="field"><label>Blood group</label><input class="input" value="${p.blood}" readonly></div>
        <div class="field"><label>Phone</label><input class="input" value="${p.phone}" readonly></div>
      </div>
      <div class="row gap2"><button class="btn btn-primary" onclick="stepDone(0);setStep(1)">Verified — continue</button></div>`,
    1:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Chief complaint</h3>
      <p class="muted mb3">Why is the patient here? Record one or more presenting concerns. HPI stays inactive until at least one is recorded.</p>
      <div class="stack gap2 mb3" id="ccList">
        ${S.ccs.map((c,i)=>`<div class="fact" style="align-items:center"><div class="fc" style="background:var(--primary-light);color:var(--primary);font-weight:700">${i+1}</div><div class="grow"><b>${c.text}</b><p class="muted">${c.dur||'Duration not set'}</p></div><button class="btn btn-ghost btn-sm" onclick="removeCc(${i})" title="Remove concern">✕</button></div>`).join('')||'<div class="empty" style="padding:var(--sp4)"><p>No presenting concern recorded yet.</p></div>'}
      </div>
      <div class="card card-pad mb3">
        <div class="row gap2"><label style="font-weight:600;flex:1">Add a concern</label>
          <input class="input" id="ccText" placeholder="e.g. Cough" style="flex:2"></div>
        <div class="row gap2 mt2">
          <select class="select" id="ccDur" style="flex:1"><option value="">Duration…</option><option>5 days</option><option>3 days</option><option>2 hours</option><option>1 week</option><option>2 weeks</option></select>
          <button class="btn btn-outline btn-sm" onclick="addCc()">+ Add concern</button>
        </div>
      </div>
      ${S.ccs.length?`<div class="success-note"><svg class="ic" width="16" height="16" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"/></svg> ${S.ccs.length} concern${S.ccs.length>1?'s':''} recorded — HPI is now active. The complaints feed the assessment, documentation and coding automatically.</div>`:''}
      <div class="fact"><div class="fc"><svg class="ic" viewBox="0 0 24 24"><path d="M12 8v5l3 2"/></svg></div><div><b>No C/C? </b><p class="muted">If no complaint is present, HPI stays inactive until a C/C is added.</p></div></div>
      <div class="row gap2 mt2"><button class="btn btn-primary" onclick="if(!S.ccs.length){toast('Record a chief complaint first','warn');return;}stepDone(1);setStep(2)">Continue to HPI →</button></div>`,
    2:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">History of Presenting Illness</h3>
      <div class="row-b mb3"><span class="state-pill ${S.ccs.length?'state-active':'state-none'}">${S.ccs.length?'HPI active':'HPI inactive — no C/C yet'}</span><span class="small muted">The system asks the next clinically relevant question — answers update the clinical state live.</span></div>
      ${S.ccs.length? renderHpiWidget() : `
        <div class="empty" style="padding:var(--sp6)"><div class="ei"><svg class="ic" viewBox="0 0 24 24"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Z"/></svg></div>
        <h3>No chief complaint recorded</h3>
        <p>Chief complaint must be recorded before symptom history can begin.</p>
        <button class="btn btn-primary mt3" onclick="setStep(1)">Add chief complaint</button></div>`}`,
    3:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Examination</h3>
      <div class="grid cols-2">
        <div class="card card-pad">
          <h4 class="mb3">Vitals</h4>
          <div class="grid cols-3" style="gap:8px">
            <div class="field"><label>Temp (°C)</label><input class="input" type="number" value="38.2" onchange="S.risk.temp=+this.value;renderClinical()"></div>
            <div class="field"><label>HR (bpm)</label><input class="input" type="number" value="112" onchange="S.risk.hr=+this.value;renderClinical()"></div>
            <div class="field"><label>RR (/min)</label><input class="input" type="number" value="26" onchange="S.risk.rr=+this.value;renderClinical()"></div>
            <div class="field"><label>SpO₂ (%)</label><input class="input" type="number" value="92" onchange="S.risk.spo2=+this.value;renderClinical()"></div>
            <div class="field"><label>SBP (mmHg)</label><input class="input" type="number" value="118" onchange="S.risk.sbp=+this.value;renderClinical()"></div>
            <div class="field"><label>DBP (mmHg)</label><input class="input" type="number" value="76" onchange="S.risk.dbp=+this.value;renderClinical()"></div>
          </div>
        </div>
        <div class="card card-pad">
          <h4 class="mb3">Systems</h4>
          <div class="field"><label>General</label><input class="input" value="Acyanosed, alert" onchange="S.exam.general=this.value;renderClinical()"></div>
          <div class="field"><label>Respiratory</label><input class="input" value="Widespread crackles right base" onchange="S.exam.respiratory=this.value;renderClinical()"></div>
          <div class="field"><label>Cardiovascular</label><input class="input" value="S1S2 audible, no murmurs" onchange="S.exam.cardio=this.value;renderClinical()"></div>
          <div class="field"><label>Abdomen</label><input class="input" value="Soft, non-tender" onchange="S.exam.abdomen=this.value;renderClinical()"></div>
        </div>
      </div>
      <div class="mt3 row gap2"><button class="btn btn-primary" onclick="stepDone(3);setStep(4)">Examination done — continue →</button></div>`,
    4:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Investigations</h3>
      <div class="grid cols-2">
        <div class="card"><div class="card-h"><h3>Ordered</h3></div><div class="card-body" style="padding-top:var(--sp3)">
          <div class="check"><input type="checkbox" checked><label style="margin:0">Full blood count (CBC)</label></div>
          <div class="check"><input type="checkbox" checked><label style="margin:0">C-reactive protein (CRP)</label></div>
          <div class="check"><input type="checkbox" checked><label style="margin:0">Chest X-ray (PA)</label></div>
          <div class="check"><input type="checkbox"><label style="margin:0">Blood cultures ×2</label></div>
          <div class="check"><input type="checkbox"><label style="margin:0">Malaria RDT</label></div>
          <div class="check"><input type="checkbox"><label style="margin:0">Sputum AFB + GeneXpert</label></div>
        </div></div>
        <div class="card"><div class="card-h"><h3>Results (demo)</h3><span class="badge badge-sky">2 new</span></div><div class="card-body" style="padding-top:var(--sp3)">
          <div class="fact"><div class="fc"><span class="dot dot-red"></span></div><div><b>CBC</b><p class="mono">WBC 23.1 ×10⁹/L · Hb 9.8 g/dL · PLT 312</p></div></div>
          <div class="fact"><div class="fc"><span class="dot dot-red"></span></div><div><b>CRP</b><p class="mono">148 mg/L — elevated</p></div></div>
          <div class="fact"><div class="fc"><span class="dot dot-amber"></span></div><div><b>Chest X-ray</b><p class="muted">Right lower lobe consolidation — awaiting review</p></div></div>
        </div></div>
      </div>
      <div class="mt3 row gap2"><button class="btn btn-primary" onclick="stepDone(4);setStep(5)">Results reviewed — continue →</button></div>`,
    5:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Assessment &amp; Reasoning</h3>
      <div class="grid split14">
        <div>
          <div class="card card-pad mb3"><h4 class="mb2">Clinical picture (from captured facts)</h4><div id="pictureFacts"></div></div>
          <div class="card card-pad"><h4 class="mb2">Risk (demo)</h4>
            <div class="row-b" style="padding:8px 0"><span class="muted">Severity (NEWS-2 style)</span><span class="badge badge-red">High — score 7</span></div>
            <div class="row-b" style="padding:8px 0"><span class="muted">Hypoxia risk</span><span class="badge badge-amber">SpO₂ 92%</span></div>
            <div class="row-b" style="padding:8px 0"><span class="muted">Sepsis screen</span><span class="badge badge-amber">WBC 23.1 · CRP 148</span></div>
          </div>
        </div>
        <div class="card card-pad">
          <h4 class="mb2">Demo intelligence — differentials</h4>
          <div class="sugg"><div class="grow"><b>Severe pneumonia</b></div><div class="bar" style="width:82%"></div><span class="tiny muted">82%</span></div>
          <div class="sugg mid"><div class="grow"><b>Tuberculosis</b></div><div class="bar" style="width:54%"></div><span class="tiny muted">54%</span></div>
          <div class="sugg low"><div class="grow"><b>Foreign body</b></div><div class="bar" style="width:22%"></div><span class="tiny muted">22%</span></div>
          <div class="tiny muted mt2">Clearly labelled demo intelligence — the clinician decides.</div>
          <div class="field mt3"><label>Diagnosis (signed)</label><input class="input" id="dxInput" value="Severe community-acquired pneumonia" onchange="S.dx=this.value||S.dx;renderClinical()"></div>
          <button class="btn btn-primary btn-block" onclick="stepDone(5);setStep(6)">Sign assessment — continue →</button>
        </div>
      </div>`,
    6:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Plan &amp; Orders</h3>
      <div class="grid cols-2">
        <div class="card"><div class="card-h"><h3>Medications</h3><button class="btn btn-ghost btn-sm" onclick="toast('Add medication (demo)','ok')">+</button></div><div class="card-body" style="padding-top:var(--sp3)">
          <div class="check"><input type="checkbox" checked><label style="margin:0">IV Ceftriaxone 1g BD</label></div>
          <div class="check"><input type="checkbox" checked><label style="margin:0">IV Azithromycin 500mg OD</label></div>
          <div class="check"><input type="checkbox" checked><label style="margin:0">Paracetamol 1g PRN</label></div>
        </div></div>
        <div class="card"><div class="card-h"><h3>Disposition &amp; monitoring</h3></div><div class="card-body" style="padding-top:var(--sp3)">
          <div class="field"><label>Disposition</label><select class="select" id="planDisp" onchange="S.plan.admit=this.value;renderClinical()"><option>Admit — short-stay ward</option><option>Treat ambulatory</option><option>Transfer — KCH</option></select></div>
          <div class="field"><label>Monitoring</label><textarea class="textarea" onchange="S.plan.obs=this.value;renderClinical()">SatO₂ target ≥94% · repeat WBC at 48h · review in 24h</textarea></div>
        </div></div>
      </div>
      <div class="mt3 row gap2"><button class="btn btn-primary" onclick="stepDone(6);setStep(7)">Plan created — continue →</button></div>`,
    7:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Documentation</h3>
      <p class="muted mb3">Generated from captured facts — not free-text authored by the UI.</p>
      <div class="tabs" style="margin-bottom:var(--sp3)"><span class="tab active" onclick="renderDoc('note')">Full note</span><span class="tab" onclick="renderDoc('soap')">SOAP</span><span class="tab" onclick="renderDoc('short')">Shorthand</span></div>
      <div id="docPreview"></div>
      <div class="row gap2 mt3"><button class="btn btn-primary" onclick="stepDone(7);setStep(8)">Documentation ready — continue →</button></div>`,
    8:`<h3 style="font-size:var(--lg);margin-bottom:var(--sp4)">Closure</h3>
      <div class="card card-pad mb3"><div class="row-b"><div><b>Encounter ${e.id}</b><div class="small muted">${e.type} · ${e.date} · ${p.name}</div></div><span class="state-pill state-active">Closing…</span></div></div>
      <div class="grid cols-2">
        <div class="card"><div class="card-h"><h3>Outstanding before close</h3><span class="badge ${closureChecks().missing.length?'badge-red':'badge-green'}">${closureChecks().missing.length?closureChecks().missing.length+' to complete':'All complete'}</span></div>
          <div class="card-body" style="padding-top:var(--sp3)">${closureChecks().items.map(c=>`
            <div class="row-b" style="padding:8px 0;border-bottom:1px solid var(--neutral-100)"><span class="small">${c.label}</span>${c.ok?'<span class="chip green">Done</span>':c.missing?'<span class="chip amber">Missing</span>':'<span class="chip">Optional</span>'}</div>`).join('')}
            ${closureChecks().missing.length?`<div class="fact flag mt3"><div class="fc">!</div><div><b>${closureChecks().missing.length} item${closureChecks().missing.length>1?'s':''} incomplete</b><p>${closureChecks().missing.map(m=>m.label).join(' · ')}</p></div></div>`:`<div class="fact"><div class="fc" style="background:var(--success-light);color:var(--success)">✓</div><div><b>Ready to close</b><p>All required sections are complete.</p></div></div>`}
          </div></div>
        <div class="card"><div class="card-h"><h3>Follow-up &amp; handover</h3></div><div class="card-body">
          <div class="field"><label>Follow-up date</label><input class="input" type="date" value="2026-08-23"></div>
          <div class="field"><label>Instructions</label><textarea class="textarea">Return in 3 days or earlier if symptoms worsen, fever persists or breathing difficulty develops.</textarea></div>
        </div></div>
      </div>
      <div class="row gap2 mt4"><button class="btn btn-primary btn-lg" onclick="confirmClose()">Review &amp; close encounter</button></div>`
  };
  b.innerHTML = bodies[S.step]||bodies[0];
  renderStepFacts();
  renderDoc('note');
}

/* ---------- STEP FACTS ---------- */
function renderStepFacts(){
  const el=$('pictureFacts'); if(!el) return;
  const f=S.facts;
  const rows=[
    ['Onset',f.onset],['Progression',f.progression],['Character',f.character],['Sputum',f.sputum],
    ['Fever',f.fever?'Present':'—'],['Shortness of breath',f.sob?'Present':'—'],['Chest pain',f.chestpain?'Present':'—'],['Weight loss',f.weightloss?'Present':'—'],
    ['Hemoptysis',f.hemoptysis?'Present':'—'],['Night sweats',f.nightsweats?'Present':'—'],['Smoker',f.smoker?'Yes':'—'],['TB contact',f.tbcontact?'Yes':'—'],
    ['Previous episodes',f.prev],['Impact',f.impact]
  ];
  el.innerHTML = rows.filter(r=>r[1]).map(r=>`<span class="badge badge-sky" style="margin:0 4px 4px 0">${r[0]}: <b>${r[1]}</b></span>`).join('') || '<span class="muted">No facts captured yet — complete the HPI step.</span>';
}

/* ---------- CLOSE ENCOUNTER ---------- */
function closureChecks(){
  const hasHist=S.stepDone.includes(2), hasExam=S.stepDone.includes(3), hasInv=!!S.inv.cbc||S.reviewed.cbc||S.reviewed.crp||S.reviewed.cxr;
  const highGaps = (typeof clinicalGaps==='function') ? clinicalGaps().filter(g=>g.prio==='HIGH') : [];
  const items=[
    {label:'Chief complaint recorded', ok:S.ccs.length>0, missing:true},
    {label:'HPI captured', ok:hasHist, missing:true},
    {label:'Examination documented', ok:hasExam, missing:true},
    {label:'Investigations reviewed', ok:hasInv, missing:true},
    {label:'High-priority clinical gaps resolved', ok:highGaps.length===0, missing:true},
    {label:'Assessment / ICD-11 code set', ok:!!S.dxCode, missing:true},
    {label:'Plan recorded', ok:S.plan.meds.length>0, missing:true},
    {label:'Documentation generated', ok:S.stepDone.includes(7), missing:false},
    {label:'Follow-up arranged', ok:true, missing:false}
  ];
  const missing=items.filter(i=>i.missing&&!i.ok);
  return {items, missing, ok:missing.length===0};
}
function confirmClose(){
  const p=S.patient, e=S.encounter, chk=closureChecks();
  const statusMsg = chk.ok?'All checks complete':(chk.missing.length+' outstanding');
  $('modalBox').innerHTML=`
    <div class="modal-h"><h3>Close ${e.id}</h3><button class="btn btn-icon" onclick="closeModal()"><svg class="ic" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
    <div class="modal-b">
      <div class="row-b mb3"><span class="muted">Patient</span><b>${p.name} (${p.ageLabel||(p.age+' yrs')})</b></div>
      <div class="row-b mb3"><span class="muted">Encounter</span><b>${e.id} · ${e.type}</b></div>
      <div class="row-b mb3"><span class="muted">Assessment</span><b>${S.dx||'Not set'}</b></div>
      <div class="row-b mb3"><span class="muted">ICD-11</span><b class="mono">${S.dxCode||'—'}</b></div>
      <div class="row-b mb3"><span class="muted">Plan</span><b>${S.plan.admit}${S.plan.meds.length?' · '+S.plan.meds.join(', '):''}</b></div>
      <div class="fact ${chk.ok?'':'flag'}"><div class="fc">${chk.ok?'✓':'!'}</div><div><b>${statusMsg}</b><p>${chk.ok?'This encounter is ready to be closed and signed.':'Complete the outstanding items before closing.'}</p></div></div>
      <div class="field mt3"><label>Closing clinician</label><input class="input" value="Dr. Brian Kamau" disabled></div>
      <div class="check mt2"><input type="checkbox" id="consentClose" checked><label for="consentClose" style="margin:0">I confirm the record is complete and accurate (digital signature)</label></div>
    </div>
    <div class="modal-f"><button class="btn btn-ghost" onclick="closeModal()">Cancel</button><button class="btn btn-primary" onclick="if(document.getElementById('consentClose').checked)closeEncounter()" ${chk.ok?'':'disabled'} style="${chk.ok?'':'opacity:.5;cursor:not-allowed'}">Close &amp; sign</button></div>`;
  $('modalOv').classList.add('show');
}
function closeEncounter(){
  const e=S.encounter;
  e.status='Completed';
  S.stepDone=ENC_STEPS.map((_,i)=>i);
  S.step=8;
  saveEnc();
  auditLog(`Encounter ${e.id} closed — patient timeline updated`);
  TIMELINE.unshift({mrn:e.mrn, date:new Date().toLocaleDateString('en-GB',{day:'2-digit',month:'short',year:'numeric'}), time:new Date().toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'}), type:'Encounter', title:`${e.type} — ${e.cc}`, detail:e.id+' · completed', icon:'M5 13l4 4L19 7'});
  closeModal();
  toast('Encounter closed. Patient timeline updated (demo)','ok');
  renderScreen('encounter');
  renderClinical();
  updateCommandCenter();
}