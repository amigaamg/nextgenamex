/* ---------- DOCUMENT GENERATOR (fact-derived) ---------- */
/* Every document is generated from the captured clinical state. The header
   states how many facts were used and each sentence carries a source trace. */

function docProvenance(){
  const facts=clinicalFacts();
  const n={HPI:0, Vitals:0, Examination:0, Investigations:0, Derived:0};
  facts.forEach(f=>{ if(n[f.source]!==undefined) n[f.source]++; });
  const total=facts.length;
  return {
    total,
    summary: 'Generated from '+total+' captured fact'+(total===1?'':'s')+
      ' ('+n.HPI+' HPI · '+n.Vitals+' vitals · '+n.Examination+' exam · '+n.Investigations+' investigations · '+n.Derived+' derived)',
    sources: n
  };
}

function srcChip(key){
  const src=factSource(key);
  const names={HPI:'HPI',Vitals:'Vitals',Examination:'Exam',Investigations:'Ix',Derived:'Derived'};
  return `<span class="src-chip" title="Source: ${src||'—'}">${names[src]||'—'}</span>`;
}

function docFooter(p,e){
  const prov=docProvenance();
  return `<div class="doc-prov">
    <b>${prov.summary}</b>
    <div class="tiny muted">Sources: HPI history · vitals · physical examination · investigations · derived reasoning. Every claim above can be traced to a captured fact.</div>
  </div>
  <div class="sig"><div>Dr. Brian Kamau<br><span style="font-weight:400">Clinician · Signed digitally (demo)</span></div><div>Date: ${e.date}</div></div>`;
}

function renderDoc(mode){
  const el=$('docPreview'); if(!el) return;
  const p=S.patient, e=S.encounter, f=S.facts, r=S.risk;
  const full = `<div class="doc">
    <h1>AMEXAN — Clinical Encounter Note</h1>
    <div class="doc-head">${e.id} · ${e.type} · ${e.date}<br>${'Fact-derived document — generated from the clinical state'}</div>
    <h2>Patient</h2>
    <p>${srcChip('onset')}<b>${p.name}</b>, ${p.sex}, ${p.ageLabel||(p.age+' years')} · MRN ${p.mrn} · ${p.blood} · ${p.phone}</p>
    <h2>Chief complaint</h2>
    <p>${ccText()||'Not recorded'}</p>
    <h2>History of presenting illness</h2>
    <p>${f.onset?('Onset '+f.onset+'.'+srcChip('onset')):''} ${f.character?('Cough: '+f.character+'.'+srcChip('character')):''} ${f.sputum?('Sputum: '+f.sputum+'.'+srcChip('sputum')):''} ${f.progression?('Progression: '+f.progression+'.'+srcChip('progression')):''} ${f.fever?'Associated fever.'+srcChip('fever'):''} ${f.sob?'Shortness of breath.'+srcChip('sob'):''} ${f.chestpain?'Chest pain.'+srcChip('chestpain'):''} ${f.weightloss?'Weight loss.'+srcChip('weightloss'):''} ${f.hemoptysis?'Hemoptysis — red flag.'+srcChip('hemoptysis'):''} ${f.nightsweats?'Night sweats.'+srcChip('nightsweats'):''} ${f.smoker?'Smoker.'+srcChip('smoker'):''} ${f.tbcontact?'TB contact.'+srcChip('tbcontact'):''}${(f.onset||f.character||f.fever)?'':'<span class="muted">No HPI facts captured yet.</span>'}</p>
    <h2>Examination</h2>
    <p>${srcChip('general')}<b>General:</b> ${S.exam.general||'—'}. ${srcChip('respiratory')}<b>Respiratory:</b> ${S.exam.respiratory||'—'}. ${srcChip('cardio')}<b>Cardiovascular:</b> ${S.exam.cardio||'—'}.</p>
    <p>${srcChip('temp')}<b>Vitals:</b> T ${r.temp}°C, HR ${r.hr}, RR ${r.rr}, SpO₂ ${r.spo2}%, BP ${r.sbp}/${r.dbp}</p>
    <h2>Investigations</h2>
    <p>${srcChip('cbc')}${S.inv.cbc||'CBC not available'}. ${srcChip('crp')}${S.inv.crp||'CRP not available'}. ${srcChip('cxr')}${S.inv.cxr||'CXR not reviewed'}.</p>
    <h2>Assessment</h2>
    <p><b>${S.dx||'No signed diagnosis'}</b> ${S.dxCode?'(ICD-11 '+S.dxCode+')':''}${S.dxConf?' — clinician confidence '+S.dxConf+'% (demo)':''}</p>
    <h2>Plan</h2>
    <p>${S.plan.admit||'Disposition not set'}. Medications: ${S.plan.meds.length?S.plan.meds.join(', '):'none recorded'}. Monitoring: ${S.plan.obs||'—'}.</p>
    ${docFooter(p,e)}
  </div>`;
  const soap = `<div class="doc">
    <h1>SOAP Note</h1><div class="doc-head">${e.id} · ${p.name} · ${e.date}</div>
    <h2>S</h2><p>${ccText()||'No C/C'}. ${f.character||''}${srcChip('character')} ${f.sputum?('sputum '+f.sputum+srcChip('sputum')):''} for ${f.onset||'5 days'}${srcChip('onset')}. ${f.fever?'Fever.':''}${srcChip('fever')} ${f.sob?'SOB.':''}${srcChip('sob')} ${f.hemoptysis?'Hemoptysis.':''}${srcChip('hemoptysis')}</p>
    <h2>O</h2><p>${srcChip('temp')}T ${r.temp}, HR ${r.hr}, RR ${r.rr}, SpO₂ ${r.spo2}%. ${S.exam.respiratory||'—'}${srcChip('respiratory')}. ${S.inv.cbc||''}${srcChip('cbc')} ${S.inv.cxr||''}${srcChip('cxr')}</p>
    <h2>A</h2><p>${S.dx||'Assessment pending'} (ICD-11 ${S.dxCode||'—'}) — NEWS2 ${clinicalRisks().score}.</p>
    <h2>P</h2><p>${S.plan.admit}. ${S.plan.meds.join('; ')}. ${S.plan.obs}.</p>
    ${docFooter(p,e)}
  </div>`;
  const short = `<div class="doc">
    <h1>Clinician Shorthand</h1><div class="doc-head">${e.id} · ${p.name}</div>
    <p>Cough, ${f.character?f.character.toLowerCase():'productive'}, ${f.progression?f.progression.toLowerCase():'worsening'}${srcChip('progression')}. ${f.sputum?('Sputum '+f.sputum+'.'+srcChip('sputum')):''} ${f.fever?'Fever.':''}${srcChip('fever')} ${f.sob?'SOB.':''}${srcChip('sob')}</p>
    <p>OX: T ${r.temp} HR ${r.hr} RR ${r.rr} SpO₂ ${r.spo2}%.${srcChip('temp')} Resp: ${S.exam.respiratory||'—'}.${srcChip('respiratory')}</p>
    <p>Ix: ${S.inv.cbc||'—'}${srcChip('cbc')} ${S.inv.crp||''}${srcChip('crp')} ${S.inv.cxr||''}${srcChip('cxr')}</p>
    <p>Ax: ${S.dx||'Assessment pending'} (ICD-11 ${S.dxCode||'—'}).</p>
    <p>Rx: ${S.plan.meds.join(', ')||'—'}. ${S.plan.admit||'—'}.</p>
    ${docFooter(p,e)}
  </div>`;
  el.innerHTML = mode==='soap'?soap : mode==='short'?short : full;
}