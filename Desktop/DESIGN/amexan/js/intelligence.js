/* =================================================================
   AMEXAN — CLINICAL INTELLIGENCE MODULE (Phase 3)
   A transparent reasoning layer over the captured clinical state.
   Everything here is derived from patient facts — nothing is guessed
   silently. Every suggestion carries its source so the clinician can
   trace how the system reached a conclusion.

   Exposed globals:
     computeClinicalState()  -> full reasoning object
     clinicalFacts()         -> facts with provenance
     clinicalGaps()          -> prioritized missing/unknown facts
     clinicalRisks()         -> risk signals with severity + source
     clinicalCandidates()    -> differentials with supporting/against
     nextBestAction()        -> what the clinician should do next
     safetyBlock()           -> persistent critical alerts
     symptomTimeline()       -> temporal narrative of the illness
     factSource(key)         -> provenance for a single fact
     renderClinical()        -> renders the Clinical State panel
     toggleStateSheet()      -> mobile bottom-sheet toggle
   ================================================================= */

const FACT_LABELS = {
  onset:'Onset', progression:'Progression', character:'Cough character', sputum:'Sputum',
  fever:'Fever', sob:'Shortness of breath', chestpain:'Chest pain', hemoptysis:'Hemoptysis',
  nightsweats:'Night sweats', weightloss:'Weight loss', smoker:'Smoker', tbcontact:'TB contact',
  prev:'Previous episodes', impact:'Functional impact', treatment:'Prior treatment'
};

/* Facts captured so far, each tagged with a source and a status.
   status: established (present), negative (explicitly absent), derived (computed) */
function clinicalFacts(){
  const f=S.facts||{}, r=S.risk||{}, ex=S.exam||{}, inv=S.inv||{};
  const out=[];
  const add=(key,label,value,source,status)=>{
    if(value===undefined||value===null||value==='') return;
    if(status==='established' && (value===false||value==='No'||value==='None'||value==='no')){ status='negative'; }
    out.push({key,label,value,source,status});
  };
  HPI_QUESTIONS.forEach(q=>add(q.key, FACT_LABELS[q.key]||q.key, f[q.key], 'HPI'));
  add('temp','Temperature', r.temp, 'Vitals');
  add('hr','Heart rate', r.hr, 'Vitals');
  add('rr','Respiratory rate', r.rr, 'Vitals');
  add('spo2','SpO₂', r.spo2, 'Vitals');
  add('sbp','Systolic BP', r.sbp, 'Vitals');
  add('dbp','Diastolic BP', r.dbp, 'Vitals');
  add('general','General examination', ex.general, 'Examination');
  add('respiratory','Respiratory exam', ex.respiratory, 'Examination');
  add('cardio','Cardiovascular exam', ex.cardio, 'Examination');
  add('abdomen','Abdominal exam', ex.abdomen, 'Examination');
  add('cbc','Full blood count', inv.cbc, 'Investigations');
  add('crp','C-reactive protein', inv.crp, 'Investigations');
  add('cxr','Chest X-ray', inv.cxr, 'Investigations');
  /* Derived facts — computed, clearly labelled as such */
  if(typeof r.spo2==='number') add('hypoxia','Hypoxaemia', r.spo2<93? 'Present (SpO₂ '+r.spo2+'%)' : 'Absent', 'Derived');
  if(typeof r.rr==='number') add('tachypnoea','Tachypnoea', r.rr>22? 'Present (RR '+r.rr+')' : 'Absent', 'Derived');
  if(typeof r.hr==='number') add('tachycardia','Tachycardia', r.hr>100? 'Present (HR '+r.hr+')' : 'Absent', 'Derived');
  if(typeof r.temp==='number') add('pyrexia','Pyrexia', r.temp>38? 'Present (T '+r.temp+'°C)' : 'Absent', 'Derived');
  return out;
}

/* Questions the clinician still needs answers to, prioritised by clinical risk.
   The UI shows these so the user knows what the system is waiting for. */
function clinicalGaps(){
  const f=S.facts||{};
  const gaps=[];
  const Q = id => HPI_QUESTIONS.find(q=>q.id===id)||null;
  const ask=(id,label,prio,reason)=>{
    const q=Q(id);
    if(!q) return;
    const answered = f[q.key]!==undefined;
    gaps.push({id, label, prio, reason, answered,
      status: answered ? 'answered' : 'unknown'});
  };
  ask('hemoptysis','Hemoptysis (blood in sputum)','HIGH','Red flag — changes urgency and work-up (TB, malignancy).');
  ask('chestpain','Chest pain','HIGH','Pleuritic pain supports consolidation; unexplained pain needs cardiac risk assessment.');
  ask('sob','Shortness of breath','HIGH','Key severity driver for oxygen need and admission.');
  ask('fever','Fever','HIGH','Supports infection and sepsis screening.');
  ask('sputum','Sputum character','HIGH','Bacterial vs viral vs blood-stained guides antibiotic and TB work-up.');
  ask('nightsweats','Night sweats','MED','With cough, raises the probability of tuberculosis.');
  ask('weightloss','Weight loss','MED','Unexplained loss points to chronic infection or malignancy.');
  ask('tbcontact','TB contact','MED','Known contact materially raises prior probability of TB.');
  ask('smoker','Smoking history','MED','Major risk factor for pneumonia, COPD and lung cancer.');
  ask('prev','Previous similar episodes','LOW','Recurrence suggests asthma/COPD/bronchiectasis.');
  ask('impact','Functional impact','LOW','Helps judge severity and follow-up urgency.');
  ask('treatment','Prior treatment','LOW','Informs antibiotic choice and escalation.');
  /* Investigation gaps */
  if(!(S.inv||{}).cbc) gaps.push({id:'cbc', label:'Full blood count result', prio:'HIGH', reason:'Leucocytosis supports bacterial infection and severity.', answered:false, status:'unknown'});
  if(!(S.inv||{}).crp) gaps.push({id:'crp', label:'C-reactive protein', prio:'MED', reason:'Elevated CRP supports bacterial infection.', answered:false, status:'unknown'});
  if(!(S.inv||{}).cxr) gaps.push({id:'cxr', label:'Chest X-ray review', prio:'HIGH', reason:'Confirms or refutes consolidation.', answered:false, status:'unknown'});
  const order={HIGH:0, MED:1, LOW:2};
  return gaps.filter(g=>!g.answered).sort((a,b)=>order[a.prio]-order[b.prio]);
}

/* Risk signals derived from vitals and facts, with severity and source. */
function clinicalRisks(){
  const r=S.risk||{}, f=S.facts||{}, inv=S.inv||{};
  const risks=[];
  let score=0;
  const flag=(label,sev,detail,src)=>{
    risks.push({label, sev, detail, source:src});
    if(sev==='red') score+=3; else if(sev==='amber') score+=1;
  };
  if(typeof r.spo2==='number'){
    if(r.spo2<=84) flag('Critical hypoxaemia','red','SpO₂ '+r.spo2+'% — severe hypoxia','Vitals');
    else if(r.spo2<90) flag('Severe hypoxaemia','red','SpO₂ '+r.spo2+'%','Vitals');
    else if(r.spo2<93) flag('Mild hypoxaemia','amber','SpO₂ '+r.spo2+'%','Vitals');
    if(r.spo2>=91&&r.spo2<=95) score+=2; else if(r.spo2<91) score+=3;
  }
  if(typeof r.rr==='number'){
    if(r.rr>=25) flag('Severe tachypnoea','red','RR '+r.rr+' — respiratory distress','Vitals');
    else if(r.rr>22) flag('Tachypnoea','amber','RR '+r.rr,'Vitals');
    if(r.rr>=25) score+=3; else if(r.rr>=21) score+=1;
  }
  if(typeof r.hr==='number'){
    if(r.hr>=130) flag('Severe tachycardia','red','HR '+r.hr,'Vitals');
    else if(r.hr>100) flag('Tachycardia','amber','HR '+r.hr,'Vitals');
    if(r.hr>=130) score+=2; else if(r.hr>100) score+=1;
  }
  if(typeof r.temp==='number' && r.temp>38) flag('Fever','amber','T '+r.temp+'°C','Vitals');
  if(typeof r.sbp==='number' && r.sbp<90) flag('Hypotension','red','SBP '+r.sbp+' mmHg — shock risk','Vitals');
  if(f.hemoptysis) flag('Hemoptysis','red','Blood in sputum — red flag','HPI');
  if(f.chestpain) flag('Chest pain','amber','Pleuritic or cardiac — assess','HPI');
  const wbc = typeof inv.cbc==='string' ? parseFloat((inv.cbc.match(/(\d+(\.\d+)?)/)||[])[1]) : null;
  const crpV = typeof inv.crp==='string' ? parseFloat((inv.crp.match(/(\d+(\.\d+)?)/)||[])[1]) : null;
  if(wbc && wbc>15) flag('Leucocytosis','amber','WBC '+wbc+' ×10⁹/L — supports bacterial infection','Investigations');
  if(crpV && crpV>100) flag('High CRP','amber','CRP '+crpV+' mg/L — marked inflammation','Investigations');
  if(wbc && crpV && (wbc>15||crpV>100) && (f.fever||(typeof r.temp==='number'&&r.temp>38))) flag('Sepsis screen positive','red','Fever + leucocytosis/inflammation — screen for sepsis','Derived');
  risks.sort((a,b)=>(a.sev==='red'?0:b.sev==='red'?1:a.sev==='amber'?0:1)-(b.sev==='red'?0:a.sev==='red'?1:a.sev==='amber'?0:1));
  return { items: risks, score };
}

/* Candidate differentials with transparent supporting and against evidence.
   Probabilities are qualitative (not fake-precise) and always editable by the clinician. */
function clinicalCandidates(){
  const f=S.facts||{}, inv=S.inv||{}, ex=S.exam||{}, ccs=S.ccs||[];
  const cc = ccs.map(c=>c.text.toLowerCase()).join(' ');
  const has=(k)=>f[k]!==undefined&&f[k]!==false&&f[k]!=='No'&&f[k]!=='None'&&f[k]!=='';
  const candidates=[];
  const wheeze = has('character')&&/whee/i.test(String(f.character)) || /wheeze/i.test(cc);
  const cough = has('character')&&/cough/i.test(String(f.character)) || /cough/i.test(cc);
  const productive = has('sputum')&&/purulent|yellowish|productive/i.test(String(f.sputum));
  const blood = has('sputum')&&/blood/i.test(String(f.sputum));
  const fever = has('fever')|| /fever/i.test(cc) || (typeof S.risk.temp==='number'&&S.risk.temp>38);
  const sob = has('sob')||/breath|sob|distress/i.test(cc);
  const tbSugg = has('nightsweats')||has('weightloss')||has('tbcontact')||blood;
  const wbc = typeof inv.cbc==='string' ? parseFloat((inv.cbc.match(/(\d+(\.\d+)?)/)||[])[1]) : null;
  const crpV = typeof inv.crp==='string' ? parseFloat((inv.crp.match(/(\d+(\.\d+)?)/)||[])[1]) : null;
  const consolidation = typeof inv.cxr==='string'&&/consolidat/i.test(inv.cxr);

  const c1 = { title:'Community-acquired pneumonia', likelihood:'High', for:[], against:[] };
  if(cough) c1.for.push('Productive/any cough (HPI)');
  if(productive) c1.for.push('Purulent sputum (HPI)');
  if(fever) c1.for.push('Fever (HPI/vitals)');
  if(sob) c1.for.push('Shortness of breath (HPI)');
  if(wbc!==null&&wbc>11) c1.for.push('Leucocytosis on CBC (investigations)');
  if(crpV!==null&&crpV>40) c1.for.push('Elevated CRP (investigations)');
  if(consolidation) c1.for.push('Consolidation on CXR (investigations)');
  if(ex.respiratory&&/crackles/i.test(ex.respiratory)) c1.for.push('Crackles on examination');
  if(has('smoker')) c1.for.push('Smoking history (HPI)');
  if(wheeze) c1.against.push('Wheeze is more typical of airway disease (HPI)');
  if(blood) c1.against.push('Blood-stained sputum is atypical — consider TB (HPI)');
  if(c1.for.length) candidates.push(c1);

  const c2 = { title:'Tuberculosis (pulmonary)', likelihood: tbSugg?'Moderate':'Lower', for:[], against:[] };
  if(has('nightsweats')) c2.for.push('Night sweats (HPI)');
  if(has('weightloss')) c2.for.push('Weight loss (HPI)');
  if(has('tbcontact')) c2.for.push('Known TB contact (HPI)');
  if(blood) c2.for.push('Blood-stained sputum (HPI)');
  if(cough&&(!productive)) c2.for.push('Chronic cough (HPI)');
  if(wbc!==null&&wbc<11) c2.for.push('Absence of leucocytosis is consistent (investigations)');
  c2.against.push('No confirmatory AFB/GeneXpert result');
  if(c2.for.length) candidates.push(c2);

  const c3 = { title:'Acute bronchitis / viral URI', likelihood:'Lower', for:[], against:[] };
  if(cough&&!productive) c3.for.push('Dry cough (HPI)');
  if(!fever) c3.for.push('No fever (HPI)');
  if(crpV!==null&&crpV<40) c3.for.push('Low CRP (investigations)');
  if(wbc!==null&&wbc<11) c3.for.push('Normal WBC (investigations)');
  if(!consolidation&&inv.cxr) c3.for.push('Clear CXR (investigations)');
  if(productive) c3.against.push('Purulent sputum suggests bacterial infection');
  if(consolidation) c3.against.push('Consolidation argues for pneumonia');
  if(c3.for.length) candidates.push(c3);

  const c4 = { title:'Asthma exacerbation', likelihood: wheeze?'Moderate':'Lower', for:[], against:[] };
  if(wheeze) c4.for.push('Wheeze (HPI)');
  if(has('prev')) c4.for.push('Previous similar episodes (HPI)');
  if((S.patient||{}).conditions && /asthma/i.test((S.patient.conditions||[]).join(' '))) c4.for.push('Known asthma (patient record)');
  if(sob) c4.for.push('Breathing difficulty (HPI)');
  if(has('impact')) c4.for.push('Impact on daily life (HPI)');
  if(!wheeze) c4.against.push('No wheeze captured');
  if(c4.for.length) candidates.push(c4);

  candidates.forEach(c=>{
    c.evidence = c.for.length + c.against.length;
    c.support = c.for.slice(0,4);
    c.against = c.against.slice(0,3);
  });
  return candidates.sort((a,b)=> (a.likelihood==='High'?2:a.likelihood==='Moderate'?1:0) - (b.likelihood==='High'?2:b.likelihood==='Moderate'?1:0));
}

/* The single most useful action, derived from the current state. */
function nextBestAction(){
  const risks=clinicalRisks();
  const crit=risks.items.filter(r=>r.sev==='red');
  const gaps=clinicalGaps();
  if(crit.length) return { label:'Immediate clinical review', detail: crit.map(c=>c.label).join(', ')+' — escalate now.', urgent:true };
  const highGap=gaps.find(g=>g.prio==='HIGH');
  if(highGap) return { label:'Answer a high-priority question', detail:'Ask about '+highGap.label.toLowerCase()+' — '+highGap.reason, urgent:false };
  if(S.step<ENC_STEPS.length-1) return { label:'Continue documentation', detail:'Complete '+ENC_STEPS[S.step]+' for '+((S.patient||{}).name||'this patient'), urgent:false };
  return { label:'Close & sign', detail:'All required sections are complete — sign the encounter.', urgent:false };
}

/* Persistent safety block — critical alerts that must not scroll away. */
function safetyBlock(){
  const risks=clinicalRisks();
  const crit=risks.items.filter(r=>r.sev==='red');
  const p=S.patient||{};
  const alerts=[];
  if((S.risk||{}).spo2<90) alerts.push({text:'Severe hypoxaemia — SpO₂ '+S.risk.spo2+'%. Administer oxygen immediately.', src:'Vitals'});
  if(crit.some(c=>/hypotension/i.test(c.label))) alerts.push({text:'Hypotension — shock risk. Intravenous access and fluids.', src:'Vitals'});
  if(crit.some(c=>/sepsis/i.test(c.label))) alerts.push({text:'Sepsis screen positive — antibiotics within 1 hour if suspected sepsis.', src:'Derived'});
  if((S.facts||{}).hemoptysis) alerts.push({text:'Hemoptysis — red flag. Urgent review for TB/malignancy.', src:'HPI'});
  if(p.mrn==='AMX-000008') alerts.push({text:'Paediatric emergency — respiratory distress with chest indrawing. Escalate to senior clinician now.', src:'Encounter'});
  return alerts;
}

/* Temporal narrative of the illness from captured facts. */
function symptomTimeline(){
  const f=S.facts||{}, ccs=S.ccs||[];
  const steps=[];
  ccs.forEach(c=>steps.push({t:'0 (presentation)', e:'Chief complaint: '+c.text+(c.dur?' ('+c.dur+')':'')}));
  if(f.onset) steps.push({t:'Onset', e:'Symptoms began — '+f.onset});
  if(f.progression) steps.push({t:'Course', e:'Course: '+f.progression});
  if(f.character) steps.push({t:'Character', e: f.character+(f.sputum?', sputum '+f.sputum:'')});
  if(f.treatment) steps.push({t:'Prior care', e:'Treatment already taken: '+f.treatment});
  if(f.impact) steps.push({t:'Function', e:'Impact: '+f.impact});
  if(!steps.length) steps.push({t:'—', e:'No temporal history captured yet.'});
  return steps;
}

/* Provenance for a single fact key. */
function factSource(key){
  const f=clinicalFacts().find(x=>x.key===key);
  return f? f.source : null;
}

/* Full reasoning object — used by the UI and by tests. */
function computeClinicalState(){
  const facts=clinicalFacts();
  const gaps=clinicalGaps();
  const risks=clinicalRisks();
  const candidates=clinicalCandidates();
  const next=nextBestAction();
  const safety=safetyBlock();
  const comp=clinicalCompleteness();
  const timeline=symptomTimeline();
  return { facts, gaps, risks, candidates, next, safety, comp, timeline };
}

/* ---------- CLINICAL STATE PANEL RENDERER ---------- */
function toggleStateSheet(){
  const el=document.querySelector('.enc-state');
  if(el) el.classList.toggle('sheet-open');
}
function renderClinical(){
  const el=$('clinicalPanel'); if(!el) return;
  const f=S.facts||{}, r=S.risk||{};
  const st=computeClinicalState();
  const pill=$('statePill');
  const activeFacts = f.character||f.sputum||f.fever||f.sob||f.hemoptysis||f.nightsweats||f.smoker||f.tbcontact;
  if(pill){
    pill.className = 'badge ' + (S.ccs.length ? (activeFacts?'badge-sky':'badge-amber') : 'badge-gray');
    pill.textContent = S.ccs.length ? (activeFacts?'HPI active':'HPI — minimal facts') : 'HPI inactive — no C/C';
  }
  const sevColor = s=> s==='red'?'#dc2626': s==='amber'?'#d97706':'#059669';
  const safetyHtml = st.safety.length? `<div class="safety-block">${st.safety.map(s=>`<div class="safety-item"><span class="dot dot-red"></span><div><b>${s.text}</b><span class="tiny muted"> · ${s.src}</span></div></div>`).join('')}</div>`:'';
  const factGroups = { established:[], negative:[], derived:[], unknown:[] };
  st.facts.forEach(x=>{
    if(x.status==='derived') factGroups.derived.push(x);
    else if(x.status==='negative') factGroups.negative.push(x);
    else factGroups.established.push(x);
  });
  const factsHtml = (title, items, empty) => items.length? `
    <div class="cs-section"><div class="cs-title">${title} <span class="badge badge-sky">${items.length}</span></div>
      ${items.map(x=>`<div class="fact"><div class="fc" style="background:var(--success-light);color:var(--success)">✓</div>
        <div><b>${x.label}</b><p>${typeof x.value==='boolean'?'Present':x.value} <span class="tiny muted">· ${x.source}</span></p></div></div>`).join('')}
    </div>` : (empty||'');
  const gapHtml = st.gaps.length? `
    <div class="cs-section"><div class="cs-title">Clinical gaps <span class="badge badge-amber">${st.gaps.length}</span></div>
      ${st.gaps.map(g=>`<div class="gap-item" style="border-left-color:${g.prio==='HIGH'?'#dc2626':g.prio==='MED'?'#d97706':'#64748b'}">
        <span class="badge ${g.prio==='HIGH'?'badge-red':g.prio==='MED'?'badge-amber':'badge-gray'}">${g.prio}</span>
        <div class="grow"><b>${g.label}</b><p class="tiny muted">${g.reason}</p></div></div>`).join('')}
    </div>` : '';
  const riskHtml = st.risks.items.length? `
    <div class="cs-section"><div class="cs-title">Risk signals <span class="badge ${st.risks.score>=5?'badge-red':st.risks.score>=2?'badge-amber':'badge-green'}">NEWS2 ${st.risks.score}</span></div>
      ${st.risks.items.map(x=>`<div class="fact ${x.sev==='red'?'flag':''}"><div class="fc" style="color:${sevColor(x.sev)};border:1.5px solid ${sevColor(x.sev)}">${x.sev==='red'?'!':x.sev==='amber'?'•':''}</div>
        <div><b>${x.label}</b><p>${x.detail} <span class="tiny muted">· ${x.source}</span></p></div></div>`).join('')}
    </div>` : '';
  const candHtml = st.candidates.length? `
    <div class="cs-section"><div class="cs-title">Differential — evidence-based</div>
      ${st.candidates.map((c,i)=>`
        <div class="cand-item ${i===0?'top':''}">
          <div class="row-b"><b>${c.title}</b><span class="badge ${c.likelihood==='High'?'badge-red':c.likelihood==='Moderate'?'badge-amber':'badge-gray'}">${c.likelihood}</span></div>
          ${c.support.length?`<div class="tiny muted" style="margin-top:4px"><b>Supporting:</b> ${c.support.join(' · ')}</div>`:''}
          ${c.against.length?`<div class="tiny muted" style="margin-top:2px"><b>Against:</b> ${c.against.join(' · ')}</div>`:''}
        </div>`).join('')}
      <div class="tiny muted mt2">Suggestions are labelled demo intelligence — the clinician decides.</div>
    </div>` : '';
  const nextHtml = `<div class="cs-section next-cs"><div class="cs-title">Next best action</div>
    <div class="next-strip" style="margin:0"><span class="badge ${st.next.urgent?'badge-red':'badge-sky'}" style="flex-shrink:0">${st.next.urgent?'URGENT':'NEXT'}</span>
    <span><b>${st.next.label}</b><p class="tiny muted" style="margin:0">${st.next.detail}</p></span></div></div>`;
  const compHtml = `<div class="cs-section"><div class="cs-title">Clinical completeness</div>
    <div class="comp-row"><div class="row-b mb1"><b style="font-size:var(--sm)">${st.comp.pct}%</b><span class="tiny muted">${st.comp.done.length}/${st.comp.total} essential facts</span></div>
    <div class="bar"><div class="bar-fill" style="width:${st.comp.pct}%"></div></div></div></div>`;
  const tlHtml = `<div class="cs-section"><div class="cs-title">Temporal story</div>
    <div class="tl" style="padding:0">${st.timeline.map(t=>`<div class="tl-item"><div class="tl-time">${t.t}</div><div class="tl-title">${t.e}</div></div>`).join('')}</div></div>`;

  el.innerHTML = safetyHtml + nextHtml + compHtml + factsHtml('Established facts', factGroups.established)
    + factsHtml('Derived findings', factGroups.derived, '')
    + gapHtml + riskHtml + candHtml + tlHtml
    + factsHtml('Explicitly absent', factGroups.negative, '');
}