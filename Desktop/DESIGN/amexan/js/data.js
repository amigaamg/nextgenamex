/* =================================================================
   AMEXAN SINGLE-FILE DEMO — minimal JS, data-driven
   ================================================================= */

/* ---------- DUMMY DATA ---------- */
const ROLES = [
  {id:'clinician', label:'Clinician', icon:'✚', color:'#0284c7', desc:'Doctor / nurse / officer', def:'Dr. Brian Kamau', defEmail:'dr-kamau@ktrh.ke', facility:'ktrh', nav:'clinical'},
  {id:'admin', label:'Facility Administrator', icon:'⚙', color:'#059669', desc:'Operations & management', def:'Sarah Ochieng', defEmail:'sarah@ktrh.ke', facility:'ktrh', nav:'admin'},
  {id:'nurse', label:'Nurse', icon:'✚', color:'#7c3aed', desc:'Triage & nursing care', def:'Nurse Jane Wambui', defEmail:'nurse@ktrh.ke', facility:'ktrh', nav:'clinical'},
  {id:'lab', label:'Laboratory', icon:'☌', color:'#0891b2', desc:'Worklist, orders & results', def:'Lab Tech Philip Odongo', defEmail:'lab@ktrh.ke', facility:'ktrh', nav:'lab'},
  {id:'pharmacy', label:'Pharmacy', icon:'☤', color:'#059669', desc:'Dispensing & inventory', def:'Pharm. Linet Auma', defEmail:'pharm@ktrh.ke', facility:'ktrh', nav:'pharmacy'},
  {id:'patient', label:'Patient', icon:'☺', color:'#d97706', desc:'Personal health portal', def:'John Otieno', defEmail:'john@demo.ke', facility:'—', nav:'patient'}
];

const FACILITIES = [
  {id:'ktrh', code:'KTRH', name:'Kisii Teaching & Referral Hospital', level:'Level 6 — Teaching & Referral', beds:420, color:'#0284c7', count:'128 patients • 42 encounters today', workspace:'Emergency + General OPD', status:'Operational'},
  {id:'kch', code:'KCH', name:'Kenyatta County Hospital, Kisii', level:'Level 5 — County Referral', beds:210, color:'#059669', count:'61 patients • 19 encounters today', workspace:'Referral & Surgical', status:'Operational'},
  {id:'mat', code:'MAT', name:'Maternity & Women\'s Hospital', level:'Level 4 — Specialised', beds:90, color:'#7c3aed', count:'24 patients • 11 encounters today', workspace:'Maternity & ANC', status:'Operational'},
  {id:'chr', code:'CHR', name:'Christamarie Health Centre', level:'Level 3 — Primary Care', beds:34, color:'#d97706', count:'18 patients • 8 encounters today', workspace:'Primary Care & Chronic', status:'Operational'},
  {id:'obc', code:'OBC', name:'Ogembo & Nyaribari Community Clinics', level:'Level 2 — Community', beds:12, color:'#0891b2', count:'9 patients • 4 encounters today', workspace:'Community Outreach', status:'Operational'}
];

const QUEUE_FLOW = [
  {stage:'Registration', count:8, note:'Front desk'},
  {stage:'Waiting', count:12, note:'General OPD'},
  {stage:'Triage', count:9, note:'Vitals pending'},
  {stage:'Consultation', count:15, note:'3 doctors'},
  {stage:'Investigation', count:7, note:'Lab / imaging'},
  {stage:'Treatment', count:5, note:'Pharmacy'},
  {stage:'Discharge', count:4, note:'Documentation'},
  {stage:'Admitted', count:3, note:'Wards'},
  {stage:'Referred', count:2, note:'Outbound'}
];

const TASKS = [
  {id:'T1', label:'Review CBC — John Otieno', cat:'Results', due:'Now', prio:'high', go:'diagnostics', note:'WBC 23.1 · Hb 9.8 — flag high'},
  {id:'T2', label:'Complete encounter — Mary Achieng', cat:'Clinical', due:'Today 15:30', prio:'high', go:'encounter', note:'HPI pending · step 3/9'},
  {id:'T3', label:'Sign referral — James Mwangi', cat:'Operations', due:'Overdue 13:30', prio:'high', go:'ops', note:'Orthopaedics → Kenyatta County Hospital'},
  {id:'T4', label:'Vitals capture — Baby A.', cat:'Clinical', due:'Today 14:00', prio:'med', go:'encounter', note:'SpO₂ 84% · severe pneumonia'},
  {id:'T5', label:'Discharge documentation — Faith Njeri', cat:'Documents', due:'Tomorrow', prio:'low', go:'documents', note:'COPD exacerbation'},
  {id:'T6', label:'Review chronic-care follow-ups', cat:'Clinical', due:'Today', prio:'med', go:'patients', note:'4 patients due this week'}
];

const NOTIFICATIONS = [
  {type:'Results', icon:'lab', color:'#7c3aed', text:'CBC result ready — John Otieno', time:'14:03', go:'diagnostics'},
  {type:'Clinical', icon:'alert', color:'#dc2626', text:'Baby A. — SpO₂ 84%, requires immediate review', time:'14:02', go:'encounter'},
  {type:'Tasks', icon:'task', color:'#0284c7', text:'Referral awaits signature — James Mwangi', time:'13:55', go:'ops'},
  {type:'Operations', icon:'op', color:'#059669', text:'Mary Achieng checked in for consultation', time:'13:58', go:'ops'},
  {type:'Results', icon:'lab', color:'#7c3aed', text:'Chest X-ray available — review required', time:'13:47', go:'diagnostics'},
  {type:'System', icon:'sys', color:'#0891b2', text:'Laboratory interface reconnected', time:'13:50', go:'integrations'}
];

const ACTIVITY_FEED = [
  {t:'14:03', cat:'Results', msg:'CBC result reviewed — WBC 23.1 (John Otieno)'},
  {t:'14:02', cat:'Clinical', msg:'Vitals captured — Baby A. · SpO₂ 84%, RR 68'},
  {t:'13:58', cat:'Operations', msg:'Mary Achieng checked in — General OPD'},
  {t:'13:55', cat:'Operations', msg:'Referral ENC-000141 flagged pending signature'},
  {t:'13:50', cat:'System', msg:'Laboratory interface reconnected'},
  {t:'13:47', cat:'Results', msg:'Chest X-ray uploaded — RLL consolidation'},
  {t:'13:40', cat:'Documents', msg:'Discharge summary drafted — Faith Njeri'},
  {t:'13:32', cat:'Clinical', msg:'Encounter ENC-000145 opened — John Otieno'}
];

const PATIENTS = [
  {mrn:'AMX-000001', name:'John Otieno', sex:'Male', age:37, dob:'1989-03-14', phone:'+254 712 000 001', kin:'Mary Otieno', kinPhone:'+254 722 000 001', blood:'O+', allergies:['Penicillin'], conditions:['Asthma (mild)'], occupation:'Teacher', address:'Kisii Town', status:'Active', avat:'JO', color:'#0284c7'},
  {mrn:'AMX-000002', name:'Mary Achieng', sex:'Female', age:29, dob:'1997-08-02', phone:'+254 712 000 002', kin:'Peter Achieng', kinPhone:'+254 722 000 002', blood:'A+', allergies:[], conditions:['Hypertension'], occupation:'Shopkeeper', address:'Riana', status:'Active', avat:'MA', color:'#d97706'},
  {mrn:'AMX-000003', name:'David Omondi', sex:'Male', age:54, dob:'1972-01-19', phone:'+254 712 000 003', kin:'Grace Omondi', kinPhone:'+254 722 000 003', blood:'B+', allergies:['Sulfa'], conditions:['Type 2 Diabetes','Hypertension'], occupation:'Farmer', address:'Iveti', status:'Active', avat:'DO', color:'#059669'},
  {mrn:'AMX-000004', name:'Esther Nyambura', sex:'Female', age:41, dob:'1985-05-27', phone:'+254 712 000 004', kin:'James Maina', kinPhone:'+254 722 000 004', blood:'AB-', allergies:[], conditions:['Asthma'], occupation:'Nurse', address:'Keroka', status:'Active', avat:'EN', color:'#7c3aed'},
  {mrn:'AMX-000005', name:'Peter Kiprop', sex:'Male', age:8, dob:'2018-09-30', phone:'+254 712 000 005', kin:'Jane Kiprop', kinPhone:'+254 722 000 005', blood:'A-', allergies:[], conditions:[], occupation:'Student', address:'Sotik', status:'Active', avat:'PK', color:'#0891b2'},
  {mrn:'AMX-000006', name:'Faith Njeri', sex:'Female', age:62, dob:'1964-02-11', phone:'+254 712 000 006', kin:'Samuel Njeri', kinPhone:'+254 722 000 006', blood:'O-', allergies:[], conditions:['Type 2 Diabetes','COPD'], occupation:'Retired', address:'Kisii Town', status:'Active', avat:'FN', color:'#dc2626'},
  {mrn:'AMX-000007', name:'Brian Mose', sex:'Male', age:25, dob:'2001-06-08', phone:'+254 712 000 007', kin:'Ann Mose', kinPhone:'+254 722 000 007', blood:'B-', allergies:[], conditions:[], occupation:'Driver', address:'Suna', status:'Registered', avat:'BM', color:'#0ea5e9'},
  {mrn:'AMX-000008', name:'Baby A.', sex:'Male', age:2, ageLabel:'2y8m', dob:'2024-01-05', phone:'+254 712 000 008', kin:'Lydia Achieng', kinPhone:'+254 722 000 008', blood:'O+', allergies:[], conditions:[], occupation:'Infant', address:'Kisii Town', status:'Active', avat:'BA', color:'#dc2626'},
  {mrn:'AMX-000009', name:'John Koech', sex:'Male', age:45, dob:'1981-07-22', phone:'+254 712 000 009', kin:'Doris Koech', kinPhone:'+254 722 000 009', blood:'A+', allergies:[], conditions:['Hypertension'], occupation:'Businessman', address:'Kisii Town', status:'Active', avat:'JK', color:'#0ea5e9'},
  {mrn:'AMX-000010', name:'Mary Wanjiku', sex:'Female', age:33, dob:'1993-03-09', phone:'+254 712 000 010', kin:'Simon Wanjiku', kinPhone:'+254 722 000 010', blood:'O+', allergies:[], conditions:[], occupation:'Farmer', address:'Sotik', status:'Active', avat:'MW', color:'#d97706'},
  {mrn:'AMX-000011', name:'Lydia Achieng', sex:'Female', age:26, dob:'2000-11-17', phone:'+254 712 000 011', kin:'Kevin Achieng', kinPhone:'+254 722 000 011', blood:'B+', allergies:[], conditions:[], occupation:'Secretary', address:'Kisii Town', status:'Active', avat:'LA', color:'#7c3aed'},
  {mrn:'AMX-000012', name:'Peter Mwangi', sex:'Male', age:30, dob:'1996-05-01', phone:'+254 712 000 012', kin:'Lilian Mwangi', kinPhone:'+254 722 000 012', blood:'O-', allergies:[], conditions:[], occupation:'Carpenter', address:'Keroka', status:'Active', avat:'PM', color:'#0891b2'},
  {mrn:'AMX-000013', name:'Amani Kipchoge', sex:'Male', age:39, dob:'1987-12-04', phone:'+254 712 000 013', kin:'Mercy Kipchoge', kinPhone:'+254 722 000 013', blood:'A-', allergies:[], conditions:['Type 2 Diabetes'], occupation:'Teacher', address:'Iveti', status:'Active', avat:'AK', color:'#059669'},
  {mrn:'AMX-000014', name:'James Mwangi', sex:'Male', age:51, dob:'1975-09-28', phone:'+254 712 000 014', kin:'Lucy Mwangi', kinPhone:'+254 722 000 014', blood:'B-', allergies:['Penicillin'], conditions:[], occupation:'Farmer', address:'Riana', status:'Active', avat:'JM', color:'#dc2626'}
];

/* Single source of truth for demo patients — every screen resolves a person by MRN, never by a bare name.
   Use P(mrn) to get the record, PName(mrn) for the display name. */
const P = mrn => PATIENTS.find(p=>p.mrn===mrn) || null;
const PName = mrn => { const p=P(mrn); return p?p.name:(mrn||'—'); };
window.P = P; window.PName = PName;

const ENC_STEPS = ['Biodata','Chief Complaint','HPI','Examination','Investigations','Assessment','Plan','Documentation','Closure'];

/* Question contract — the UI renders these; the engine decides what comes next.
   type: single (pick one) | yn (yes/no → boolean) | text (free text) */
const HPI_QUESTIONS = [
  {id:'onset', prompt:'When did it begin?', key:'onset', type:'single', options:['Sudden','5 days ago','2 weeks ago','1 month ago','Chronic'], prio:'HIGH', why:'Tempo of onset separates acute infection / aspiration from chronic disease.'},
  {id:'progression', prompt:'How has it progressed?', key:'progression', type:'single', options:['Worsening','Static','Improving','On and off'], prio:'HIGH', why:'Progressive deterioration is a key signal for severity and admission.'},
  {id:'character', prompt:'How would you describe it?', key:'character', type:'single', options:['Productive cough','Dry cough','Barking cough','Wheezy'], prio:'HIGH', why:'Cough character drives the differential and unlocks follow-up questions.'},
  {id:'sputum', prompt:'Is it productive — what is the sputum like?', key:'sputum', type:'single', options:['Purulent, yellowish','Clear','Blood-stained','None'], dep:{key:'character', value:'Productive cough'}, prio:'HIGH', why:'Purulent sputum supports bacterial infection; blood-stained raises TB or malignancy.'},
  {id:'fever', prompt:'Associated fever?', key:'fever', type:'yn', options:['Yes','No'], prio:'HIGH', why:'Fever with cough/tachypnoea supports infection and sepsis screening.'},
  {id:'sob', prompt:'Shortness of breath / breathing difficulty?', key:'sob', type:'yn', options:['Yes','No'], prio:'HIGH', why:'Breathing difficulty predicts severity and the need for oxygen/observation.'},
  {id:'chestpain', prompt:'Chest pain?', key:'chestpain', type:'yn', options:['Yes','No'], prio:'HIGH', why:'Pleuritic chest pain suggests consolidation; any chest pain needs risk assessment.'},
  {id:'hemoptysis', prompt:'Any blood in the sputum (hemoptysis)?', key:'hemoptysis', type:'yn', options:['Yes','No'], prio:'HIGH', why:'Hemoptysis is a red flag — prompt evaluation for TB, bronchiectasis or malignancy.'},
  {id:'nightsweats', prompt:'Night sweats?', key:'nightsweats', type:'yn', options:['Yes','No'], prio:'MED', why:'Night sweats with cough raise the probability of tuberculosis.'},
  {id:'weightloss', prompt:'Weight loss?', key:'weightloss', type:'yn', options:['Yes','No'], prio:'MED', why:'Unexplained weight loss points to chronic infection or malignancy.'},
  {id:'smoker', prompt:'Smoking history?', key:'smoker', type:'yn', options:['Yes','No'], prio:'MED', why:'Smoking is a major risk factor for pneumonia, COPD and lung cancer.'},
  {id:'tbcontact', prompt:'Known TB contact?', key:'tbcontact', type:'yn', options:['Yes','No'], prio:'MED', why:'Known TB contact materially raises the prior probability of tuberculosis.'},
  {id:'prev', prompt:'Previous similar episodes?', key:'prev', type:'single', options:['None','1–2 per year','Frequent'], prio:'LOW', why:'Recurrent episodes suggest asthma, COPD or bronchiectasis rather than a single infection.'},
  {id:'impact', prompt:'Impact on daily life?', key:'impact', type:'single', options:['Missed days of work','Unable to sleep','Minimal'], prio:'LOW', why:'Functional impact helps judge severity and the urgency of follow-up.'},
  {id:'treatment', prompt:'Any treatment already taken?', key:'treatment', type:'text', placeholder:'e.g. Paracetamol PRN, no antibiotics', prio:'LOW', why:'Prior treatment (or failure) influences antibiotic choice and escalation.'}
];

/* Clinical-completeness: which facts the reasoning engine treats as essential before it will suggest signing.
   Keys map to HPI_QUESTIONS + vitals/exam/investigations. */
const CLINICAL_ESSENTIAL = {
  HPI:['onset','character','fever','sob','hemoptysis'],
  VITALS:['temp','hr','rr','spo2'],
  EXAM:['general','respiratory'],
  INVESTIGATIONS:['cbc','crp','cxr']
};
function clinicalCompleteness(){
  const f=S.facts, r=S.risk, ex=S.exam, inv=S.inv;
  const done=[];
  CLINICAL_ESSENTIAL.HPI.forEach(k=>{ if(f[k]!==undefined) done.push(k); });
  CLINICAL_ESSENTIAL.VITALS.forEach(k=>{ if(r[k]) done.push(k); });
  CLINICAL_ESSENTIAL.EXAM.forEach(k=>{ if(ex[k]) done.push(k); });
  CLINICAL_ESSENTIAL.INVESTIGATIONS.forEach(k=>{ if(inv[k]) done.push(k); });
  const total=CLINICAL_ESSENTIAL.HPI.length+CLINICAL_ESSENTIAL.VITALS.length+CLINICAL_ESSENTIAL.EXAM.length+CLINICAL_ESSENTIAL.INVESTIGATIONS.length;
  return { done, total, pct: Math.round(done.length/total*100) };
}
function hpiAnswered(q){ return S.facts[q.key]!==undefined; }
function hpiDepOk(q){ return !q.dep || S.facts[q.dep.key]===q.dep.value; }
function hpiPending(){ return HPI_QUESTIONS.filter(q=>!hpiAnswered(q) && hpiDepOk(q)); }
function hpiDone(){ return hpiAnsweredCount()===HPI_QUESTIONS.length; }
function hpiAnsweredCount(){ return HPI_QUESTIONS.filter(hpiAnswered).length; }
function hpiAnswer(key,val){ S.facts[key]=val; saveEnc(); renderClinical(); const p=hpiPending(); S.qEdit = p.length? HPI_QUESTIONS.indexOf(p[0]) : -1; renderStep(); }
function hpiBack(){ const ans=HPI_QUESTIONS.map((q,i)=>hpiAnswered(q)?i:-1).filter(i=>i>=0); const cur=S.qEdit!=null?S.qEdit:-1; const prev=ans.filter(i=>i<cur).pop(); S.qEdit=prev!=null?prev:-1; renderStep(); }
function renderHpiWidget(){
  const total=HPI_QUESTIONS.length, done=hpiAnsweredCount();
  const pending=hpiPending();
  const comp=clinicalCompleteness();
  const idx = S.qEdit!=null && S.qEdit>=0 ? S.qEdit : (pending.length? HPI_QUESTIONS.indexOf(pending[0]) : -1);
  const q = idx>=0? HPI_QUESTIONS[idx] : null;
  const compBar = `<div class="comp-row mb3"><div class="row-b mb1"><b style="font-size:var(--sm)">Clinical picture completeness</b><span class="small mono">${comp.pct}%</span></div>
    <div class="bar"><div class="bar-fill" style="width:${comp.pct}%"></div></div>
    <div class="tiny muted mt1">Essential facts captured: ${comp.done.join(', ')||'none yet'}</div></div>`;
  const whyHtml = q? `<div class="why-box"><button class="why-toggle" onclick="this.parentElement.classList.toggle('open')">Why this question? <span class="caret">▾</span></button>
    <div class="why-body">${q.why||'This question refines the differential and severity assessment.'}</div></div>`:'';
  if(!q){
    const chips=HPI_QUESTIONS.map(q=>S.facts[q.key]).filter(v=>v!==undefined && v!==false && v!=='' && v!=='No' && v!=='None').map(v=>`<span class="chip green">${v}</span>`);
    return `
      <div class="card card-pad mb3">${compBar}
        <div class="row-b mb3"><b style="font-size:var(--sm)">HPI complete</b><span class="badge badge-green">${done}/${total} questions</span></div>
        <div class="row gap2 wrap">${chips.join('')||'<span class="muted">No positive findings captured.</span>'}</div>
      </div>
      <div class="row gap2"><button class="btn btn-ghost btn-sm" onclick="hpiBack()">← Back</button><button class="btn btn-primary" onclick="stepDone(2);setStep(3)">Continue to Examination →</button></div>`;
  }
  const val=S.facts[q.key];
  const selCls=v=> val===v?'sel':'';
  const opts = q.type==='text'
    ? `<input class="input" id="hpiText" placeholder="${q.placeholder||''}" value="${q.key==='treatment'&&S.facts.treatment?S.facts.treatment:''}" onkeydown="if(event.key==='Enter')hpiAnswer('${q.key}',this.value)">
       <div class="mt2"><button class="btn btn-primary btn-sm" onclick="hpiAnswer('${q.key}',document.getElementById('hpiText').value)">Save answer</button></div>`
    : `<div class="stack gap2">${q.options.map(v=>{
        const stored = q.type==='yn'? (v==='Yes'): v;
        return `<button class="qopt ${val===stored?'sel':''}" onclick="hpiAnswer('${q.key}',${typeof stored==='boolean'?stored:'\''+v.replace(/'/g,'')+'\''})"><span class="radio ${val===stored?'on':''}"></span>${v}</button>`;
      }).join('')}</div>`;
  const dots=HPI_QUESTIONS.map((qq,i)=>`<span class="${hpiAnswered(qq)?'on':''} ${qq===q?'cur':''}" title="${qq.prompt}"></span>`).join('');
  const backBtn = done>0? `<button class="btn btn-ghost btn-sm" onclick="hpiBack()">← Back</button>`:'';
  const skipBtn = q.type!=='text'? `<button class="btn btn-ghost btn-sm" onclick="hpiAnswer('${q.key}', null)">Skip / unknown</button>`:'';
  return `
    <div class="card card-pad mb3">${compBar}</div>
    <div class="card card-pad">
      <div class="row-b wrap gap2 mb3">
        <div class="row gap2"><span class="badge ${q.prio==='HIGH'?'badge-red':q.prio==='MED'?'badge-amber':'badge-gray'}">${q.prio||'LOW'} priority</span><span class="small muted">${done+1}/${total} answered</span></div>
        <div class="qdots">${dots}</div>
      </div>
      <h4 style="font-size:var(--md);margin-bottom:var(--sp3)">${q.prompt}</h4>
      ${opts}
      ${whyHtml}
      <div class="row gap2 mt3">${backBtn}${skipBtn}<button class="btn btn-primary btn-sm" style="margin-left:auto" onclick="if(S.ccs.length&&!hpiPending().length){stepDone(2);setStep(3)}">Next →</button></div>
    </div>`;
}

/* Per-encounter clinical state (one patient, one story — never shared across encounters) */
const ENC_DEFAULTS = (over={})=>Object.assign({
  ccs:[], facts:{}, risk:{temp:36.8,hr:80,rr:18,spo2:98,sbp:118,dbp:76},
  exam:{general:'',respiratory:'',cardio:'',abdomen:''},
  inv:{cbc:'',crp:'',cxr:''}, reviewed:{cbc:false,crp:false,cxr:false},
  dx:'', dxCode:'', dxConf:0,
  plan:{admit:'Treat ambulatory',meds:[],obs:''},
  step:2, stepDone:[0,1]
},over);

const ENCOUNTERS = [
  {id:'ENC-000145', mrn:'AMX-000001', type:'Outpatient', date:'20 Aug 2026, 08:12', clinician:'Dr. Brian Kamau', status:'In progress', cc:'Cough for 5 days', queue:'General OPD',
   d:ENC_DEFAULTS({ccs:[{text:'Cough for 5 days',dur:'5 days'}],facts:{onset:'5 days ago',progression:'Worsening',character:'Productive cough',sputum:'Purulent, yellowish',fever:true,sob:true,smoker:true},risk:{temp:38.2,hr:112,rr:26,spo2:92,sbp:118,dbp:76},exam:{general:'Acyanosed, alert',respiratory:'Widespread crackles right base',cardio:'S1S2 audible, no murmurs',abdomen:'Soft, non-tender'},inv:{cbc:'WBC 23.1 ×10⁹/L, Hb 9.8 g/dL',crp:'CRP 148 mg/L (elevated)',cxr:'Right lower lobe consolidation — awaiting review'},dx:'Severe community-acquired pneumonia',dxCode:'CA40.2',dxConf:82,plan:{admit:'Admit — short-stay ward',meds:['IV Ceftriaxone 1g BD','IV Azithromycin 500mg OD','Paracetamol 1g PRN'],obs:'SatO₂ target ≥94%, repeat WBC at 48h'}})},
  {id:'ENC-000146', mrn:'AMX-000002', type:'Outpatient', date:'20 Aug 2026, 07:50', clinician:'Dr. Brian Kamau', status:'Waiting', cc:'Headache for 2 days', queue:'General OPD',
   d:ENC_DEFAULTS({ccs:[{text:'Headache for 2 days',dur:'2 days'}],risk:{temp:36.9,hr:88,rr:20,spo2:98,sbp:110,dbp:72}})},
  {id:'ENC-000144', mrn:'AMX-000003', type:'Review', date:'20 Aug 2026, 07:15', clinician:'Dr. Brian Kamau', status:'Waiting', cc:'Diabetes review — hyperglycaemia', queue:'Ward 4A',
   d:ENC_DEFAULTS({ccs:[{text:'Diabetes review',dur:'routine'}],facts:{onset:'Chronic',progression:'Static',fever:false,sob:false,chestpain:false,hemoptysis:false,nightsweats:false,weightloss:true,prev:'Frequent'},risk:{temp:36.7,hr:96,rr:20,spo2:97,sbp:128,dbp:82},exam:{general:'Alert, obese',respiratory:'Clear',cardio:'S1S2, no murmur',abdomen:'Soft, distended'},inv:{cbc:'WBC 7.2 ×10⁹/L (normal)',crp:'CRP 8 mg/L (normal)',cxr:'No acute changes'},dx:'Type 2 diabetes — hyperglycaemia',dxCode:'5A11',dxConf:80,plan:{admit:'Admit — Medical (short-stay)',meds:['Insulin glargine 12U nocte','Metformin 500mg BD','IV 0.9% saline'],obs:'RBS 4-hourly · ketone check'},step:6,stepDone:[0,1,2,3,4,5,6]})},
  {id:'ENC-000143', mrn:'AMX-000004', type:'Outpatient', date:'20 Aug 2026, 06:40', clinician:'Dr. Brian Kamau', status:'Waiting', cc:'Wheeze — asthma exacerbation', queue:'Ward 4A',
   d:ENC_DEFAULTS({ccs:[{text:'Wheeze',dur:'1 day'}],facts:{onset:'Sudden',progression:'Worsening',character:'Wheezy',fever:false,sob:true,chestpain:false,hemoptysis:false,nightsweats:false,smoker:false,prev:'Frequent'},risk:{temp:37.1,hr:96,rr:24,spo2:94,sbp:112,dbp:74},exam:{general:'Alert, mild respiratory distress',respiratory:'Diffuse expiratory wheeze',cardio:'S1S2, no murmur',abdomen:'Soft'},inv:{cbc:'WBC 9.1 ×10⁹/L (normal)',crp:'CRP 12 mg/L (normal)',cxr:'No acute changes — hyperinflation'},dx:'Asthma exacerbation',dxCode:'SA60.0',dxConf:78,plan:{admit:'Treat — short-stay ward',meds:['Salbutamol nebulisation PRN','Prednisolone 40mg OD','Oxygen 2 L/min as needed'],obs:'SpO₂ target ≥94% · reassess peak flow in 2h'},step:6,stepDone:[0,1,2,3,4,5,6]})},
  {id:'ENC-000147', mrn:'AMX-000008', type:'Emergency', date:'20 Aug 2026, 08:02', clinician:'Dr. Brian Kamau', status:'Waiting', cc:'Respiratory distress', queue:'Casualty',
   d:ENC_DEFAULTS({ccs:[{text:'Respiratory distress',dur:'3 hours'}],facts:{onset:'Sudden',sob:true,character:'Barking cough'},risk:{temp:39.2,hr:158,rr:68,spo2:84,sbp:70,dbp:45},exam:{general:'Ill-looking, grunting',respiratory:'Chest indrawing, bilateral crackles',cardio:'Tachycardic, no murmur',abdomen:'Soft'},inv:{cbc:'WBC 27.4 ×10⁹/L, Hb 10.2 g/dL',crp:'CRP 210 mg/L (elevated)',cxr:'Right lower lobe consolidation — reviewed'},dx:'Severe pneumonia',dxCode:'CA40.2',dxConf:88,reviewed:{cbc:true,crp:true,cxr:true},plan:{admit:'Admit — Paediatric ward',meds:['IV Ceftriaxone 50mg/kg BD','IV Ampicillin 50mg/kg QID','Oxygen 2L/min'],obs:'SpO₂ target ≥94%, review in 30 min'},step:2,stepDone:[0,1]})},
  {id:'ENC-000142', mrn:'AMX-000006', type:'Review', date:'19 Aug 2026, 09:15', clinician:'Dr. Brian Kamau', status:'Completed', cc:'COPD follow-up', queue:'Ward 4A',
   d:ENC_DEFAULTS({ccs:[{text:'COPD follow-up',dur:'routine'}],facts:{onset:'Sudden',progression:'Improving',character:'Productive cough',sputum:'Purulent, yellowish',fever:false,sob:true,hemoptysis:false,nightsweats:false,smoker:true,prev:'Frequent'},risk:{temp:36.6,hr:82,rr:20,spo2:93,sbp:124,dbp:78},exam:{general:'Alert, comfortable',respiratory:'Bilateral expiratory wheeze, prolonged expiration',cardio:'S1S2, no murmur',abdomen:'Soft'},inv:{cbc:'WBC 9.8 ×10⁹/L (normal)',crp:'CRP 14 mg/L (normal)',cxr:'Emphysematous changes — no acute consolidation'},dx:'COPD exacerbation — improving',dxCode:'CA23.0',dxConf:76,plan:{admit:'Treat — ward',meds:['Salbutamol nebulisation PRN','Prednisolone 30mg OD'],obs:'SpO₂ target ≥92% · review in 24h'},step:8,stepDone:[0,1,2,3,4,5,6,7,8]})},
  {id:'ENC-000141', mrn:'AMX-000007', type:'Outpatient', date:'18 Aug 2026, 11:40', clinician:'Dr. Grace Moraa', status:'Completed', cc:'Laceration — left hand', queue:'Casualty',
   d:ENC_DEFAULTS({ccs:[{text:'Laceration — left hand',dur:'2 hours'}],step:8,stepDone:[0,1,2,3,4,5,6,7,8]})},
{id:'ENC-000140', mrn:'AMX-000001', type:'Review', date:'12 Aug 2026, 10:20', clinician:'Dr. Grace Moraa', status:'Completed', cc:'Asthma review', queue:'Chronic Care',
    d:ENC_DEFAULTS({ccs:[{text:'Asthma review',dur:'routine'}],step:8,stepDone:[0,1,2,3,4,5,6,7,8]})},
  {id:'ENC-000148', mrn:'AMX-000014', type:'Outpatient', date:'18 Aug 2026, 16:20', clinician:'Dr. Brian Kamau', status:'Waiting', cc:'Wrist injury — referred to orthopaedics', queue:'Casualty',
    d:ENC_DEFAULTS({ccs:[{text:'Wrist injury',dur:'1 day'}],risk:{temp:36.8,hr:84,rr:18,spo2:97,sbp:120,dbp:78},inv:{cbc:'WBC 8.2 ×10⁹/L (normal)',crp:'CRP 6 mg/L (normal)',cxr:'No fracture seen'},dx:'Distal radial injury',dxCode:'ND15.0',dxConf:74,plan:{admit:'Refer — Orthopaedics (KCH)',meds:['Paracetamol 1g PRN'],obs:'Review in ortho clinic in 3 days'},step:6,stepDone:[0,1,2,3,4,5,6]})},
  {id:'ENC-000149', mrn:'AMX-000009', type:'Inpatient', date:'20 Aug 2026, 07:30', clinician:'Dr. Brian Kamau', status:'In progress', cc:'Chest pain — observation', queue:'Ward 4A',
    d:ENC_DEFAULTS({ccs:[{text:'Chest pain',dur:'1 day'}],facts:{onset:'Sudden',progression:'Static',character:'—',chestpain:true,sob:false,fever:false,hemoptysis:false},risk:{temp:36.8,hr:92,rr:20,spo2:97,sbp:142,dbp:88},exam:{general:'Alert, anxious',respiratory:'Clear',cardio:'S1S2, no murmurs',abdomen:'Soft'},inv:{cbc:'WBC 8.9 ×10⁹/L (normal)',crp:'CRP 9 mg/L (normal)',cxr:'Normal heart and lungs'},dx:'Hypertensive urgency — observation',dxCode:'8D80.1',dxConf:70,plan:{admit:'Admit — observation (Ward 4A)',meds:['Amlodipine 5mg OD','Aspirin 81mg OD'],obs:'BP 4-hourly · ECG + troponin · review in 6h'},step:6,stepDone:[0,1,2,3,4,5,6]})}
];

/* Longitudinal timeline per patient */
const TIMELINE = [
  {mrn:'AMX-000001', date:'20 Aug 2026', time:'08:12', type:'Encounter', title:'Outpatient — cough × 5 days', detail:'ENC-000145 · in progress', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000001', date:'18 Jul 2026', time:'14:30', type:'Laboratory', title:'Full blood count', detail:'Within normal limits', icon:'M6 3v12M18 3v6M6 9h12'},
  {mrn:'AMX-000001', date:'02 Jun 2026', time:'09:00', type:'Encounter', title:'Outpatient — fever', detail:'Viral illness · discharged', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000001', date:'11 Apr 2026', time:'13:15', type:'Pharmacy', title:'Prescription — Amoxicillin', detail:'500mg TDS × 7 days', icon:'M12 3 5 6v6c0 4 3 7 7 9'},
  {mrn:'AMX-000002', date:'20 Aug 2026', time:'07:50', type:'Encounter', title:'ANC review — headache', detail:'ENC-000146 · waiting', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000002', date:'05 Aug 2026', time:'11:00', type:'Encounter', title:'ANC booking visit', detail:'Gestation 26 weeks · completed', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000002', date:'21 Jul 2026', time:'15:45', type:'Laboratory', title:'ANC panel — Hb, syphilis, HIV', detail:'All within normal limits', icon:'M6 3v12M18 3v6M6 9h12'},
  {mrn:'AMX-000008', date:'20 Aug 2026', time:'08:02', type:'Encounter', title:'Emergency — respiratory distress', detail:'ENC-000147 · urgent', icon:'M12 9v5M12 17h.01'},
  {mrn:'AMX-000008', date:'09 Mar 2026', time:'10:00', type:'Encounter', title:'Outpatient — fever & rash', detail:'Viral exanthem · completed', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000008', date:'15 Jan 2026', time:'09:30', type:'Immunisation', title:'Immunisations — 2nd dose', detail:'Recorded', icon:'M12 3 5 6v6c0 4 3 7 7 9'},
  {mrn:'AMX-000009', date:'20 Aug 2026', time:'07:30', type:'Encounter', title:'Inpatient — chest pain observation', detail:'ENC-000149 · Ward 4A · admitted', icon:'M5 21V7l7-4 7 4v14'},
  {mrn:'AMX-000009', date:'18 Jul 2026', time:'11:20', type:'Pharmacy', title:'Prescription — Amlodipine 5mg', detail:'30 tablets · hypertension', icon:'M12 3 5 6v6c0 4 3 7 7 9'},
  {mrn:'AMX-000003', date:'20 Aug 2026', time:'07:15', type:'Encounter', title:'Diabetes review — hyperglycaemia', detail:'ENC-000144 · Ward 4A', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000003', date:'02 Aug 2026', time:'09:10', type:'Laboratory', title:'HbA1c', detail:'8.2% — elevated', icon:'M6 3v12M18 3v6M6 9h12'},
  {mrn:'AMX-000004', date:'20 Aug 2026', time:'06:40', type:'Encounter', title:'Asthma exacerbation — wheeze', detail:'ENC-000143 · Ward 4A', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000004', date:'11 Jul 2026', time:'10:00', type:'Encounter', title:'Outpatient — asthma review', detail:'Salbutamol + prednisolone · completed', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000006', date:'19 Aug 2026', time:'09:15', type:'Encounter', title:'COPD review — improving', detail:'ENC-000142 · Ward 4A', icon:'M12 8v5l3 2'},
  {mrn:'AMX-000006', date:'11 Aug 2026', time:'14:30', type:'Encounter', title:'COPD exacerbation', detail:'Admitted · nebulisation · discharged', icon:'M5 21V7l7-4 7 4v14'}
];
window.TIMELINE = TIMELINE;

const ICD11 = [
  {code:'CA40.0', label:'Pneumonia', syn:['lung infection','chest infection','pneumonia']},
  {code:'CA40.1', label:'Community-acquired pneumonia', syn:['cap','community pneumonia']},
  {code:'CA40.2', label:'Severe pneumonia', syn:['severe pneumonia','bilateral pneumonia']},
  {code:'CA07.1', label:'Acute bronchitis', syn:['bronchitis','chest cold']},
  {code:'CA23.0', label:'Unspecified acute lower respiratory infection', syn:['lrti','lower respiratory tract infection']},
  {code:'SA60.0', label:'Asthma', syn:['asthma','wheezy chest','bronchial asthma']},
  {code:'MG24.0', label:'Tension-type headache', syn:['headache','tension headache']},
  {code:'8D80.1', label:'Essential hypertension', syn:['hypertension','high blood pressure','raised bp']},
  {code:'5A11', label:'Type 2 diabetes mellitus', syn:['diabetes','type 2','dm']},
  {code:'CA20.0', label:'Upper respiratory infection', syn:['uri','upper respiratory tract infection','flu']}
];

const INTEGRATIONS = [
  {id:'national', name:'National Health Information / DHIS2', kind:'National reporting', purpose:'Facility reporting and aggregate health information exchange.', data:['OPD activity','admissions','discharges','selected disease reporting','mortality','service utilization','facility indicators'], direction:'AMEXAN → National reporting', dir:'outbound', state:'demo', badge:'DEMO CONNECTED', color:'#059669', last:'20:05', owner:'Facility Administrator', extra:'Reporting readiness 96%', action:'Open connection →', note:'National reporting connector — simulated'},
  {id:'dha', name:'Digital Health Agency (DHA) Interoperability', kind:'National exchange', purpose:'Exchange of appropriately authorized health information through supported national digital-health interoperability mechanisms.', data:['patient identity','facility identity','encounter summaries','referrals','clinical summaries','selected health information'], direction:'AMEXAN ↔ National interoperability layer', dir:'bidir', state:'demo', badge:'DEMO CONNECTION', color:'#0284c7', last:'19:48', owner:'Facility Administrator', extra:'Configured for simulated patient-summary exchange', action:'View interoperability mapping →', note:'Simulated patient-summary exchange'},
  {id:'hie', name:'Kenya Health Information Exchange', kind:'Cross-facility exchange', purpose:'Support authorized information exchange between participating facilities.', data:['referral context','encounter summary','authorized clinical summary','receiving-facility acknowledgement'], direction:'Bidirectional', dir:'bidir', state:'demo', badge:'DEMO CONNECTION', color:'#0284c7', last:'19:42', owner:'Facility Administrator', extra:'KTRH ↔ Kenyatta County Hospital', action:'Open exchange →', note:'Simulated cross-facility exchange'},
  {id:'pharmacy', name:'County Pharmacy Supply', kind:'Supply network', purpose:'Facility stock and requisition exchange.', data:['stock levels','reorder thresholds','requisitions','fulfillment','delivery status'], direction:'AMEXAN ↔ Supply network', dir:'bidir', state:'demo', badge:'DEMO CONNECTED', color:'#059669', last:'20:02', owner:'Facility Administrator', extra:'Stock exceptions 3', action:'Open supply connection →', note:'Amoxicillin syrup below reorder level'},
  {id:'sha', name:'SHA Claims', kind:'Kenya health coverage / claims workflow', purpose:'Claim preparation, submission and status tracking.', data:['encounter billing data','service codes','claim lines','authorization references','claim status','rejection/exception information'], direction:'AMEXAN → Claims service', dir:'outbound', state:'demo', badge:'DEMO CONNECTION', color:'#0284c7', last:'19:55', owner:'Finance Officer', extra:'Claims today 42 · Pending 7 · Exceptions 2', action:'Open claims integration →', note:'No real claim has been submitted from this demo'},
  {id:'lis', name:'Laboratory LIS', kind:'Clinical', purpose:'Exchange laboratory orders and results.', data:['test orders (AMEXAN → LIS)','results / status (LIS → AMEXAN)'], direction:'AMEXAN ↔ LIS', dir:'bidir', state:'demo', badge:'DEMO CONNECTED', color:'#059669', last:'20:11', owner:'Laboratory', extra:'Orders today 38 · Results received 29 · Pending 9', action:'Open LIS connection →', note:'No patient-level clinical values on this administrative screen'},
  {id:'ris', name:'Radiology RIS / PACS', kind:'Imaging', purpose:'Imaging workflow and study exchange.', data:['imaging requests','scheduling','study status','reports','imaging references'], direction:'AMEXAN ↔ RIS/PACS', dir:'bidir', state:'pending', badge:'PENDING CONFIGURATION', color:'#d97706', last:'—', owner:'ICT Officer', extra:'Reason: endpoint and authentication configuration required', action:'Configure connection →', note:'Demo preview: 17 imaging requests'},
  {id:'ambulance', name:'Emergency & Ambulance', kind:'Pre-hospital', purpose:'Pre-arrival and triage handover.', data:['transport status','ETA','triage handover','destination','receiving service','arrival confirmation'], direction:'Ambulance → AMEXAN · AMEXAN → Receiving service', dir:'in', state:'demo', badge:'DEMO CONNECTION', color:'#0284c7', last:'20:07', owner:'Emergency', extra:'Active transfers 2 · Incoming 1', action:'Open emergency integration →', note:'Simulated pre-arrival feed'}
];
const INTEGRATION_SUMMARY = {configured:8, demoActive:5, internal:2, pending:1, critical:0, health:94, evaluated:'20:14', tx:{today:1842, ok:1824, pendingTx:14, failed:4}};
const INTEGRATION_FAILURES = [
  {id:'LIS', type:'Order transmission', time:'20:02', reason:'Validation failure', action:'Retry / inspect mapping'},
  {id:'SHA', type:'Claim submission', time:'19:51', reason:'Authorization reference missing', action:'Review claim line'}
];
const INTEGRATION_ARCH = {
  layer:'AMEXAN Interoperability Layer',
  core:[['Identity Registry','External identity mapping'],['Exchange Services','HIE / DHA exchange'],['Reporting Services','National aggregate reporting']],
  external:['External identity','HIE / DHA exchange','National reporting · aggregate data']
};
const INTEGRATION_MAPPINGS = [
  {from:'AMEXAN Patient', mid:'National Patient Identifier', to:'External patient identifier'},
  {from:'AMEXAN Encounter', mid:'Encounter representation', to:'External encounter identifier'},
  {from:'AMEXAN Laboratory Order', mid:'Mapped laboratory request', to:'LIS order'}
];
const INTEGRATION_GOVERNANCE = [
  ['Purpose','Every exchange has a defined operational purpose'],
  ['Data domain','Only the domain the connection is licensed for'],
  ['Direction','Outbound / inbound / bidirectional as configured'],
  ['Authorization','Role → purpose → minimum necessary access'],
  ['Minimum necessary data','Never the full clinical record'],
  ['Destination','Only the configured endpoint'],
  ['Identity matching','National identifier & facility identity matching'],
  ['Validation','Schema, consent and coding validation before send'],
  ['Audit trail','Every transmission recorded and traceable'],
  ['Failure handling','Failures surface — never silently disappear']
];
window.INTEGRATIONS = INTEGRATIONS; window.INTEGRATION_SUMMARY = INTEGRATION_SUMMARY; window.INTEGRATION_FAILURES = INTEGRATION_FAILURES; window.INTEGRATION_ARCH = INTEGRATION_ARCH; window.INTEGRATION_MAPPINGS = INTEGRATION_MAPPINGS; window.INTEGRATION_GOVERNANCE = INTEGRATION_GOVERNANCE;

/* Expose the demo data on window — a single, shared source of truth that
   every screen and every test reads from. One identity per MRN, everywhere. */
window.PATIENTS = PATIENTS;
window.ENCOUNTERS = ENCOUNTERS;
window.TASKS = TASKS;
window.NOTIFICATIONS = NOTIFICATIONS;
window.ACTIVITY_FEED = ACTIVITY_FEED;
window.ROLES = ROLES;
window.FACILITIES = FACILITIES;
window.QUEUE_FLOW = QUEUE_FLOW;
window.ICD11 = ICD11;
window.HPI_QUESTIONS = HPI_QUESTIONS;
window.ENC_STEPS = ENC_STEPS;