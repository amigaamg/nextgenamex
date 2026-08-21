/* =================================================================
   AMEXAN ORGANIZATION LAYER — the facility as an operating system.
   Constitutional data: network, departments, workforce, services,
   infrastructure, assets, enterprise connections, reporting, finance,
   safety, research, security + chart helpers + provisioning engine.
   ================================================================= */

/* ---------- WORKFORCE ROLES + CONSTITUTIONAL WORKSPACE RESOLVER ---------- */
const WORKSPACES = {
  admin:'Facility Command Center', hospital_admin:'Administrative Operations', dept_head:'Department Command',
  ward_incharge:'Ward Operations', consultant:'Clinical Workspace', registrar:'Clinical Workspace',
  medical_officer:'Clinical Workspace', clinical_officer:'Clinical Workspace', surgeon:'Clinical Workspace',
  anaesthetist:'Clinical Workspace', nurse:'Nursing Workspace', midwife:'Maternity / Nursing Workspace',
  pharmacist:'Pharmacy Workspace', lab_tech:'Laboratory Workspace', lab_scientist:'Laboratory Workspace',
  radiographer:'Radiology Workspace', radiologist:'Radiology Workspace', finance_officer:'Finance Workspace',
  hr_officer:'Workforce Workspace', ict_officer:'Technology Workspace', researcher:'Research Workspace',
  med_student:'Teaching Workspace', telemedicine_officer:'Telemedicine Workspace', cho:'Community Health Workspace'
};
const WORKFORCE_ROLES = [
  {id:'admin', name:'Facility Administrator', grp:'Executive', dept:'hr', workspace:WORKSPACES.admin},
  {id:'hospital_admin', name:'Hospital Admin', grp:'Executive', dept:'hr', workspace:WORKSPACES.hospital_admin},
  {id:'dept_head', name:'Department Head', grp:'Department', dept:'—', workspace:WORKSPACES.dept_head},
  {id:'ward_incharge', name:'Ward In-charge', grp:'Department', dept:'—', workspace:WORKSPACES.ward_incharge},
  {id:'consultant', name:'Consultant', grp:'Clinical', dept:'—', workspace:WORKSPACES.consultant},
  {id:'registrar', name:'Registrar', grp:'Clinical', dept:'—', workspace:WORKSPACES.registrar},
  {id:'medical_officer', name:'Medical Officer', grp:'Clinical', dept:'—', workspace:WORKSPACES.medical_officer},
  {id:'clinical_officer', name:'Clinical Officer', grp:'Clinical', dept:'—', workspace:WORKSPACES.clinical_officer},
  {id:'surgeon', name:'Surgeon', grp:'Clinical', dept:'surgery', workspace:WORKSPACES.surgeon},
  {id:'anaesthetist', name:'Anaesthetist', grp:'Clinical', dept:'theatre', workspace:WORKSPACES.anaesthetist},
  {id:'nurse', name:'Nurse', grp:'Nursing', dept:'—', workspace:WORKSPACES.nurse},
  {id:'midwife', name:'Midwife', grp:'Nursing', dept:'obgyn', workspace:WORKSPACES.midwife},
  {id:'pharmacist', name:'Pharmacist', grp:'Pharmacy', dept:'pharmacy', workspace:WORKSPACES.pharmacist},
  {id:'lab_tech', name:'Lab Technologist', grp:'Laboratory', dept:'lab', workspace:WORKSPACES.lab_tech},
  {id:'lab_scientist', name:'Medical Lab Scientist', grp:'Laboratory', dept:'lab', workspace:WORKSPACES.lab_scientist},
  {id:'radiographer', name:'Radiographer', grp:'Radiology', dept:'radiology', workspace:WORKSPACES.radiographer},
  {id:'radiologist', name:'Radiologist', grp:'Radiology', dept:'radiology', workspace:WORKSPACES.radiologist},
  {id:'finance_officer', name:'Finance Officer', grp:'Finance', dept:'finance', workspace:WORKSPACES.finance_officer},
  {id:'hr_officer', name:'HR Officer', grp:'HR', dept:'hr', workspace:WORKSPACES.hr_officer},
  {id:'ict_officer', name:'ICT Officer', grp:'ICT', dept:'ict', workspace:WORKSPACES.ict_officer},
  {id:'researcher', name:'Researcher', grp:'Research', dept:'research', workspace:WORKSPACES.researcher},
  {id:'med_student', name:'Medical Student', grp:'Teaching', dept:'teaching', workspace:WORKSPACES.med_student},
  {id:'telemedicine_officer', name:'Telemedicine Officer', grp:'Telemedicine', dept:'telemedicine', workspace:WORKSPACES.telemedicine_officer},
  {id:'cho', name:'Community Health Officer', grp:'Community', dept:'community', workspace:WORKSPACES.cho}
];
const workspaceFor = rid => WORKSPACES[rid] || 'Constitutional Workspace';
window.WORKSPACES = WORKSPACES; window.WORKFORCE_ROLES = WORKFORCE_ROLES;

/* ---------- DEPARTMENTS ---------- */
const DEPARTMENTS = [
  {id:'emergency', code:'EM', name:'Emergency', color:'#dc2626'},
  {id:'opd', code:'OPD', name:'Outpatient Department', color:'#0284c7'},
  {id:'surgery', code:'SUR', name:'Surgery', color:'#0ea5e9'},
  {id:'medicine', code:'MED', name:'Medicine', color:'#059669'},
  {id:'paeds', code:'PAE', name:'Paediatrics', color:'#d97706'},
  {id:'obgyn', code:'OBG', name:'Obstetrics & Gynaecology', color:'#7c3aed'},
  {id:'icu', code:'ICU', name:'Intensive Care', color:'#dc2626'},
  {id:'theatre', code:'THE', name:'Theatre', color:'#0891b2'},
  {id:'lab', code:'LAB', name:'Laboratory', color:'#7c3aed'},
  {id:'radiology', code:'RAD', name:'Radiology', color:'#0ea5e9'},
  {id:'pharmacy', code:'PHA', name:'Pharmacy', color:'#059669'},
  {id:'hr', code:'HR', name:'Human Resources', color:'#64748b'},
  {id:'ict', code:'ICT', name:'ICT', color:'#0891b2'},
  {id:'finance', code:'FIN', name:'Finance', color:'#d97706'}
];
const dept = id => DEPARTMENTS.find(d=>d.id===id) || {id, code:'—', name:id, color:'#64748b'};
window.DEPARTMENTS = DEPARTMENTS;

/* ---------- WORKFORCE (base roster; provisioning appends) ---------- */
const WORKFORCE = [
  {id:'ADM-001', name:'Sarah Ochieng', dept:'Human Resources', deptId:'hr', role:'Facility Administrator', roleId:'admin', workspace:'Facility Command Center', status:'On duty', roster:'Day'},
  {id:'ADM-002', name:'Collins Mose', dept:'Human Resources', deptId:'hr', role:'Hospital Admin', roleId:'hospital_admin', workspace:'Administrative Operations', status:'On duty', roster:'Day'},
  {id:'EM-001', name:'Dr. Grace Kerubo', dept:'Emergency', deptId:'emergency', role:'Consultant', roleId:'consultant', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'EM-002', name:'Dr. Felix Otieno', dept:'Emergency', deptId:'emergency', role:'Medical Officer', roleId:'medical_officer', workspace:'Clinical Workspace', status:'On duty', roster:'Evening'},
  {id:'EM-003', name:'Nurse Alice Moraa', dept:'Emergency', deptId:'emergency', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'EM-004', name:'Nurse Cynthia Nyakundi', dept:'Emergency', deptId:'emergency', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Evening'},
  {id:'EM-005', name:'Nurse Paul Nyambane', dept:'Emergency', deptId:'emergency', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'Off duty', roster:'Night'},
  {id:'OPD-001', name:'Dr. Brian Kamau', dept:'Outpatient Department', deptId:'opd', role:'Consultant', roleId:'consultant', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'OPD-002', name:'Dr. Irene Bosibori', dept:'Outpatient Department', deptId:'opd', role:'Medical Officer', roleId:'medical_officer', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'OPD-003', name:'CO Jackson Manyara', dept:'Outpatient Department', deptId:'opd', role:'Clinical Officer', roleId:'clinical_officer', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'SUR-001', name:'Dr. Kevin Nyangena', dept:'Surgery', deptId:'surgery', role:'Surgeon', roleId:'surgeon', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'SUR-002', name:'Dr. Beatrice Mogaka', dept:'Surgery', deptId:'surgery', role:'Registrar', roleId:'registrar', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'SUR-003', name:'Dr. Ombati Sirma', dept:'Surgery', deptId:'surgery', role:'Registrar', roleId:'registrar', workspace:'Clinical Workspace', status:'Off duty', roster:'Night'},
  {id:'SUR-004', name:'Nurse Hellen Kemunto', dept:'Surgery', deptId:'surgery', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'SUR-005', name:'Nurse Justus Otieno', dept:'Surgery', deptId:'surgery', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'SUR-006', name:'Nurse Faith Kwamboka', dept:'Surgery', deptId:'surgery', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'Leave', roster:'—'},
  {id:'MED-001', name:'Dr. Tabitha Nyaboke', dept:'Medicine', deptId:'medicine', role:'Consultant', roleId:'consultant', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'MED-002', name:'Dr. Victor Obure', dept:'Medicine', deptId:'medicine', role:'Medical Officer', roleId:'medical_officer', workspace:'Clinical Workspace', status:'On duty', roster:'Evening'},
  {id:'MED-003', name:'Nurse Mercy Kerubo', dept:'Medicine', deptId:'medicine', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'MED-004', name:'Nurse Samuel Onchari', dept:'Medicine', deptId:'medicine', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Night'},
  {id:'PAE-001', name:'Dr. Phoebe Anyona', dept:'Paediatrics', deptId:'paeds', role:'Consultant', roleId:'consultant', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'PAE-002', name:'Nurse Lydia Otieno', dept:'Paediatrics', deptId:'paeds', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'OBG-001', name:'Dr. Rose Monari', dept:'Obstetrics & Gynaecology', deptId:'obgyn', role:'Consultant', roleId:'consultant', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'OBG-002', name:'Midwife Josephine Nyakerario', dept:'Obstetrics & Gynaecology', deptId:'obgyn', role:'Midwife', roleId:'midwife', workspace:'Maternity / Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'OBG-003', name:'Midwife Ednah Kwamboka', dept:'Obstetrics & Gynaecology', deptId:'obgyn', role:'Midwife', roleId:'midwife', workspace:'Maternity / Nursing Workspace', status:'On duty', roster:'Night'},
  {id:'ICU-001', name:'Dr. Stephen Nyabuto', dept:'Intensive Care', deptId:'icu', role:'Registrar', roleId:'registrar', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'ICU-002', name:'Nurse Beatrice Nyaboke', dept:'Intensive Care', deptId:'icu', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'THE-001', name:'Dr. Anita Mokua', dept:'Theatre', deptId:'theatre', role:'Anaesthetist', roleId:'anaesthetist', workspace:'Clinical Workspace', status:'On duty', roster:'Day'},
  {id:'THE-002', name:'Scrub Nurse Emily Moraa', dept:'Theatre', deptId:'theatre', role:'Nurse', roleId:'nurse', workspace:'Nursing Workspace', status:'On duty', roster:'Day'},
  {id:'LAB-001', name:'Philip Odongo', dept:'Laboratory', deptId:'lab', role:'Lab Technologist', roleId:'lab_tech', workspace:'Laboratory Workspace', status:'On duty', roster:'Day'},
  {id:'LAB-002', name:'Jane Chepkemoi', dept:'Laboratory', deptId:'lab', role:'Lab Technologist', roleId:'lab_tech', workspace:'Laboratory Workspace', status:'On duty', roster:'Evening'},
  {id:'LAB-003', name:'Dr. Bethwel Ogoti', dept:'Laboratory', deptId:'lab', role:'Medical Lab Scientist', roleId:'lab_scientist', workspace:'Laboratory Workspace', status:'On duty', roster:'Day'},
  {id:'RAD-001', name:'Radiographer Joseph Mwita', dept:'Radiology', deptId:'radiology', role:'Radiographer', roleId:'radiographer', workspace:'Radiology Workspace', status:'On duty', roster:'Day'},
  {id:'RAD-002', name:'Dr. Naomi Kemunto', dept:'Radiology', deptId:'radiology', role:'Radiologist', roleId:'radiologist', workspace:'Radiology Workspace', status:'On duty', roster:'Day'},
  {id:'PHA-001', name:'Linet Auma', dept:'Pharmacy', deptId:'pharmacy', role:'Pharmacist', roleId:'pharmacist', workspace:'Pharmacy Workspace', status:'On duty', roster:'Day'},
  {id:'PHA-002', name:'David Nyandoro', dept:'Pharmacy', deptId:'pharmacy', role:'Pharmacist', roleId:'pharmacist', workspace:'Pharmacy Workspace', status:'On duty', roster:'Evening'},
  {id:'FIN-001', name:'Gladys Moraa', dept:'Finance', deptId:'finance', role:'Finance Officer', roleId:'finance_officer', workspace:'Finance Workspace', status:'On duty', roster:'Day'},
  {id:'HR-001', name:'Patrick Nyaberi', dept:'Human Resources', deptId:'hr', role:'HR Officer', roleId:'hr_officer', workspace:'Workforce Workspace', status:'On duty', roster:'Day'},
  {id:'ICT-001', name:'Kelvin Ogechi', dept:'ICT', deptId:'ict', role:'ICT Officer', roleId:'ict_officer', workspace:'Technology Workspace', status:'On duty', roster:'Day'},
  {id:'ICT-002', name:'Brian Momanyi', dept:'ICT', deptId:'ict', role:'ICT Officer', roleId:'ict_officer', workspace:'Technology Workspace', status:'Off duty', roster:'Night'},
  {id:'TEL-001', name:'Dr. Irene Bosibori', dept:'Telemedicine', deptId:'telemedicine', role:'Telemedicine Officer', roleId:'telemedicine_officer', workspace:'Telemedicine Workspace', status:'On duty', roster:'Day'},
  {id:'COM-001', name:'Community CHV Leah Nyaboke', dept:'Community', deptId:'community', role:'Community Health Officer', roleId:'cho', workspace:'Community Health Workspace', status:'On duty', roster:'Outreach'},
  {id:'RSR-001', name:'Dr. Ken Owino', dept:'Research', deptId:'research', role:'Researcher', roleId:'researcher', workspace:'Research Workspace', status:'On duty', roster:'Academic'},
  {id:'TCH-001', name:'Med Student Yvonne Moraa', dept:'Teaching', deptId:'teaching', role:'Medical Student', roleId:'med_student', workspace:'Teaching Workspace', status:'On duty', roster:'Rotation'}
];
const COVERAGE_ALERTS = [
  {sev:'red', scope:'Emergency', msg:'Night shift short 2 nurses'},
  {sev:'amber', scope:'Theatre', msg:'Anaesthesia coverage ends 22:00'},
  {sev:'amber', scope:'Laboratory', msg:'Evening shift missing technologist'},
  {sev:'green', scope:'OPD', msg:'Full staffing — 3 doctors on duty'}
];
const WORKFORCE_SUMMARY = {total:421, onDuty:183, offDuty:201, leave:27, unassigned:10};
const WORKFORCE_ANALYTICS = {
  coverage:[['Nursing',92],['Doctors',88],['Laboratory',76],['Theatre',103],['Radiology',81],['Pharmacy',94]],
  trends:{
    overtime:[9,11,10,13,12,14,15],
    absenteeism:[3,4,3,5,4,6,5],
    ratio:[4.1,4.3,4.2,4.5,4.4,4.6,4.7],
    shiftCoverage:[91,93,90,92,89,91,90]
  },
  pressure:'Emergency demand increased 28% while nursing coverage decreased 12%.'
};
window.WORKFORCE = WORKFORCE; window.WORKFORCE_SUMMARY = WORKFORCE_SUMMARY; window.WORKFORCE_ANALYTICS = WORKFORCE_ANALYTICS;

/* ---------- SERVICE CATALOGUES ---------- */
const SERVICES = [
  {grp:'Clinical', name:'OPD', dept:'opd', loc:'Outpatient Complex', staff:12, workflow:'Register → Triage → Consult → Rx', pricing:'Per visit', codes:'HMIS 101'},
  {grp:'Clinical', name:'Emergency', dept:'emergency', loc:'Emergency Bay', staff:9, workflow:'Triage → Resuscitation → Admission/Discharge', pricing:'Per episode', codes:'HMIS 102'},
  {grp:'Clinical', name:'Inpatient', dept:'medicine', loc:'Wards 1–5', staff:28, workflow:'Admit → Ward care → Review → Discharge', pricing:'Per bed-day', codes:'HMIS 201'},
  {grp:'Clinical', name:'ICU', dept:'icu', loc:'Third Floor', staff:8, workflow:'Admit → Monitoring → Step-down', pricing:'Per bed-day', codes:'HMIS 205'},
  {grp:'Clinical', name:'Theatre', dept:'theatre', loc:'Theatre Suite', staff:6, workflow:'Pre-op → Anaesthesia → Surgery → Recovery', pricing:'Per procedure', codes:'HMIS 301'},
  {grp:'Clinical', name:'Maternity', dept:'obgyn', loc:'Maternity Ward', staff:10, workflow:'ANC → Labour → Delivery → Post-natal', pricing:'Per delivery', codes:'HMIS 401'},
  {grp:'Clinical', name:'Neonatal', dept:'obgyn', loc:'Neonatal Unit', staff:6, workflow:'Admit → Phototherapy → Feed → Discharge', pricing:'Per bed-day', codes:'HMIS 402'},
  {grp:'Clinical', name:'Paediatrics', dept:'paeds', loc:'Children Ward', staff:8, workflow:'Triage → Ward care → Review', pricing:'Per visit', codes:'HMIS 103'},
  {grp:'Diagnostics', name:'Laboratory', dept:'lab', loc:'Fourth Floor', staff:7, workflow:'Order → Collect → Analyse → Report', pricing:'Per test', codes:'HMIS 501'},
  {grp:'Diagnostics', name:'Radiology', dept:'radiology', loc:'Fourth Floor', staff:5, workflow:'Request → Screen → Report → Archive', pricing:'Per study', codes:'HMIS 502'},
  {grp:'Diagnostics', name:'Ultrasound', dept:'radiology', loc:'Fourth Floor', staff:2, workflow:'Request → Scan → Report', pricing:'Per study', codes:'HMIS 503'},
  {grp:'Diagnostics', name:'CT', dept:'radiology', loc:'CT Suite', staff:2, workflow:'Request → Screen → Scan → Report', pricing:'Per study', codes:'HMIS 504'},
  {grp:'Support', name:'Pharmacy', dept:'pharmacy', loc:'Fifth Floor', staff:5, workflow:'Prescribe → Verify → Dispense → Counsel', pricing:'Per prescription', codes:'HMIS 601'},
  {grp:'Support', name:'Blood Bank', dept:'lab', loc:'Fourth Floor', staff:3, workflow:'Request → Screen → Cross-match → Issue', pricing:'Per unit', codes:'HMIS 602'},
  {grp:'Support', name:'Nutrition', dept:'opd', loc:'Outpatient Complex', staff:2, workflow:'Assess → Plan → Counsel', pricing:'Per session', codes:'HMIS 701'},
  {grp:'Support', name:'Physiotherapy', dept:'opd', loc:'Outpatient Complex', staff:3, workflow:'Refer → Assess → Treat', pricing:'Per session', codes:'HMIS 702'}
];
window.SERVICES = SERVICES;

/* ---------- INFRASTRUCTURE / HOSPITAL BUILDER ---------- */
const INFRA = {
  name:'Kisii Teaching & Referral Hospital', kind:'Hospital',
  children:[
    {name:'Main Hospital', kind:'Building', children:[
      {name:'Ground Floor', kind:'Floor', children:[
        {name:'Emergency', kind:'Department', children:[{name:'Resuscitation Bay', beds:4},{name:'Acute Ward', beds:10}]},
        {name:'OPD', kind:'Department', children:[{name:'Consult Rooms 1–14', beds:0}]}
      ]},
      {name:'First Floor', kind:'Floor', children:[
        {name:'Surgery Dept', kind:'Department', children:[{name:'Male Surgical Ward', beds:22},{name:'Female Surgical Ward', beds:18}]},
        {name:'Theatre Suite', kind:'Department', children:[{name:'Theatre 1', beds:4},{name:'Theatre 2', beds:4}]}
      ]},
      {name:'Second Floor', kind:'Floor', children:[
        {name:'Medicine Dept', kind:'Department', children:[{name:'General Medical Ward', beds:42},{name:'Cardiology Bay', beds:12}]},
        {name:'Paediatrics', kind:'Department', children:[{name:'Children Ward', beds:24}]}
      ]},
      {name:'Third Floor', kind:'Floor', children:[
        {name:'Obstetrics & Gynaecology', kind:'Department', children:[{name:'Maternity Ward', beds:18},{name:'Labour Suite', beds:6},{name:'Neonatal Unit', beds:8}]},
        {name:'Intensive Care', kind:'Department', children:[{name:'Intensive Care Unit', beds:10}]}
      ]},
      {name:'Fourth Floor', kind:'Floor', children:[
        {name:'Laboratory', kind:'Department', children:[{name:'Biochemistry', beds:0},{name:'Haematology', beds:0}]},
        {name:'Radiology', kind:'Department', children:[{name:'X-ray', beds:0},{name:'CT Room', beds:0}]}
      ]},
      {name:'Fifth Floor', kind:'Floor', children:[
        {name:'Pharmacy', kind:'Department', children:[{name:'Dispensing', beds:0},{name:'Store', beds:0}]},
        {name:'Administration', kind:'Department', children:[]}
      ]}
    ]},
    {name:'Maternity Campus', kind:'Campus', children:[
      {name:'Labour & Delivery', beds:12, kind:'Ward'},{name:'Post-natal Ward', beds:20, kind:'Ward'},{name:'ANC Clinic', beds:0, kind:'Clinic'}
    ]},
    {name:'Community Clinics', kind:'Network', children:[
      {name:'Ogembo Clinic', beds:6, kind:'Clinic'},{name:'Nyaribari Clinic', beds:6, kind:'Clinic'}
    ]},
    {name:'External Network', kind:'Network', children:[
      {name:'Referral Partners', kind:'Partner'},{name:'Partner Laboratory', kind:'Partner'},{name:'Partner Pharmacy', kind:'Partner'},
      {name:'University', kind:'Partner'},{name:'Research Center', kind:'Partner'}
    ]}
  ]
};
const COUNT_INFRA = node => {
  let beds=0, nodes=1;
  (node.children||[]).forEach(c=>{ const r=COUNT_INFRA(c); beds+=r.beds+(c.beds||0); nodes+=r.nodes; });
  return {beds, nodes};
};
window.INFRA = INFRA;

/* ---------- ASSET INTELLIGENCE ---------- */
const ASSETS = [
  {id:'RAD-CT-001', name:'CT Scanner', type:'Imaging', loc:'CT Suite', status:'Operational', lastService:'12 Aug', nextService:'12 Nov', util:76, risk:'Moderate', impact:{investigations:17, depts:3, partners:2}},
  {id:'RAD-MRI-001', name:'MRI 1.5T', type:'Imaging', loc:'MRI Room', status:'Operational', lastService:'02 Jul', nextService:'02 Oct', util:54, risk:'Low', impact:{investigations:9, depts:2, partners:1}},
  {id:'LAB-AN-001', name:'Haematology analyser', type:'Laboratory', loc:'Haematology', status:'Operational', lastService:'20 Jul', nextService:'20 Oct', util:88, risk:'High', impact:{investigations:140, depts:8, partners:3}},
  {id:'LAB-BC-001', name:'Biochemistry analyser', type:'Laboratory', loc:'Biochemistry', status:'Operational', lastService:'05 Aug', nextService:'05 Nov', util:81, risk:'Moderate', impact:{investigations:112, depts:7, partners:2}},
  {id:'THE-01', name:'Anaesthesia machine — Theatre 1', type:'Theatre', loc:'Theatre 1', status:'Operational', lastService:'01 Aug', nextService:'01 Nov', util:64, risk:'Low', impact:{investigations:0, depts:1, partners:0}},
  {id:'MAT-01', name:'Cardiotocograph (CTG)', type:'Maternity', loc:'Labour Suite', status:'Operational', lastService:'15 Aug', nextService:'15 Nov', util:71, risk:'Low', impact:{investigations:0, depts:1, partners:0}},
  {id:'ICU-01', name:'Ventilator — ICU-02', type:'ICU', loc:'Intensive Care Unit', status:'In service', lastService:'10 Aug', nextService:'10 Nov', util:92, risk:'High', impact:{investigations:0, depts:1, partners:0}}
];
window.ASSETS = ASSETS;

/* ---------- ENTERPRISE INTEGRATIONS / ECOSYSTEM ---------- */
const ECOSYSTEM = [
  {system:'AMEXAN Clinical OS', status:'Online', last:'Live', data:'Core clinical records', dir:'—', freq:'Live'},
  {system:'HMIS', status:'Connected', last:'2 min ago', data:'Encounter dataset', dir:'⇄', freq:'Batch'},
  {system:'DHA reporting', status:'Connected', last:'Today', data:'National reporting dataset', dir:'→', freq:'Daily'},
  {system:'SHA', status:'Connected', last:'5 min ago', data:'Claims & eligibility', dir:'⇄', freq:'Live'},
  {system:'Laboratory', status:'Connected', last:'Live', data:'Orders & results', dir:'⇄', freq:'Live'},
  {system:'Pharmacy', status:'Connected', last:'Live', data:'Dispensing events', dir:'⇄', freq:'Live'},
  {system:'Finance', status:'Connected', last:'8 min ago', data:'Revenue & claims', dir:'⇄', freq:'Batch'},
  {system:'HR', status:'Connected', last:'12 min ago', data:'Staff records', dir:'⇄', freq:'Batch'},
  {system:'University', status:'Connected', last:'1 day ago', data:'Teaching & research', dir:'⇄', freq:'Daily'},
  {system:'Suppliers', status:'Connected', last:'3 hours ago', data:'Procurement', dir:'←', freq:'Daily'}
];
const PARTNERS = [
  {id:'kenyatta', name:'Kenyatta County Hospital', type:'Referral Hospital', rel:'Receives referrals', dir:'out', state:'ACTIVE', color:'#059669', cat:'referrals',
   agreement:{kind:'MOU', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2027', owner:'Facility Administration', renewal:'498 days'},
   activity:{when:'Today', what:'Referral accepted'},
   detail:{kind:'referral',
     facts:[['Outgoing referrals (this month)',12],['Accepted',9],['Pending',2],['Completed',1]],
     metrics:[['Acceptance rate','75%'],['Average acknowledgement','34 min']],
     services:['Orthopaedics','General Surgery','Internal Medicine','Imaging'],
     note:'Patient-level referral content requires authorization.'}},
  {id:'sunshine', name:'Sunshine Referral Hospital', type:'Referral Hospital', rel:'Referral exchange', dir:'bi', state:'LIMITED', color:'#dc2626', cat:'referrals',
   stateNote:'Receiving service temporarily unavailable',
   agreement:{kind:'MOU', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2026', owner:'Facility Administration', renewal:'45 days'},
   activity:{when:'3 days ago', what:'Referral exchange'},
   detail:{kind:'referral',
     facts:[['Outgoing referrals (this month)',4],['Accepted',2],['Pending',1],['Awaiting service',1]],
     metrics:[['Acceptance rate','50%'],['Average acknowledgement','2 h']],
     services:['General Surgery','Orthopaedics'],
     note:'Agreement review due in 45 days — relationship currently LIMITED because its receiving service is temporarily unavailable.'}},
  {id:'maternity', name:'Maternity & Women\'s Hospital', type:'Affiliated Facility', rel:'Shared services', dir:'bi', state:'ACTIVE', color:'#7c3aed', cat:'shared',
   agreement:{kind:'Operational', status:'Active', effective:'01 Jan 2026', expires:'—', owner:'Facility Administration', renewal:'—'},
   activity:{when:'Today', what:'Shared service used'},
   detail:{kind:'affiliate',
     facts:[['Shared services enabled',3],['Referrals received (this month)',6],['Bed availability',6]],
     metrics:[['Shared-service turnaround','18 min']],
     services:['Obstetric beds','Theatre','Imaging']}},
  {id:'christamarie', name:'Christamarie Health Centre', type:'Primary care', rel:'Refers to KTRH', dir:'in', state:'ACTIVE', color:'#d97706', cat:'referrals',
   agreement:{kind:'Operational', status:'Active', effective:'01 Jan 2026', expires:'—', owner:'Facility Administration', renewal:'—'},
   activity:{when:'Today', what:'Referral sent'},
   detail:{kind:'primary',
     facts:[['Referrals to KTRH (this month)',12],['Teleconsultations',4],['Pending referrals',1]],
     metrics:[['Referral acceptance','100%'],['Average handover time','22 min']],
     level:'Level 2 · Primary Care'}},
  {id:'ogembo', name:'Ogembo & Nyaribari Community Clinics', type:'Community', rel:'Refers to KTRH', dir:'in', state:'ACTIVE', color:'#0891b2', cat:'community',
   agreement:{kind:'Operational', status:'Active', effective:'01 Jan 2026', expires:'—', owner:'Facility Administration', renewal:'—'},
   activity:{when:'Yesterday', what:'Referral sent'},
   detail:{kind:'community',
     facts:[['Referrals to KTRH (this month)',18],['Teleconsultations',7],['Pending referrals',1]],
     metrics:[['Referral acceptance','100%'],['Average handover time','19 min']],
     level:'Level 2 · Community',
     shared:['Laboratory','Pharmacy']}},
  {id:'kisii_lab', name:'Kisii Medical Laboratory', type:'Partner Laboratory', rel:'Lab services', dir:'bi', state:'ACTIVE', color:'#0ea5e9', cat:'laboratory',
   agreement:{kind:'MOU', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2027', owner:'Facility Administration', renewal:'498 days'},
   activity:{when:'Today', what:'Laboratory result received'},
   detail:{kind:'lab',
     facts:[['Orders this month',248],['Results received',231],['Pending',17]],
     services:['CBC','Chemistry','Microbiology','Histopathology'],
     integration:'AMEXAN ↔ LIS', integrationState:'DEMO CONNECTION'}},
  {id:'wellness', name:'Wellness Pharmacy Network', type:'Partner Pharmacy', rel:'Supplies', dir:'in', state:'ACTIVE', color:'#059669', cat:'pharmacy',
   agreement:{kind:'Contract', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2026', owner:'Procurement', renewal:'133 days'},
   activity:{when:'Today', what:'Supply requisition fulfilled'},
   detail:{kind:'pharmacy',
     facts:[['Requisitions',14],['Fulfilled',11],['Pending',3]],
     metrics:[['Fulfillment rate','92%']]}},
  {id:'medtech', name:'MedTech & KEMSA Suppliers', type:'Supplier', rel:'Supplies', dir:'in', state:'ACTIVE', color:'#64748b', cat:'suppliers',
   agreement:{kind:'Contract', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2026', owner:'Procurement', renewal:'133 days'},
   activity:{when:'Today', what:'Supply order fulfilled'},
   detail:{kind:'supplier',
     dependencies:[['Critical','Medical oxygen',1,'#dc2626'],['High','Essential medicines',2,'#d97706'],['Normal','General consumables',4,'#059669']],
     risk:'Moderate', riskNote:'Single active supplier for medical oxygen.'}},
  {id:'egerton', name:'Egerton University Medical School', type:'University', rel:'Teaching', dir:'in', state:'ACTIVE', color:'#0284c7', cat:'education',
   agreement:{kind:'MOU', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2027', owner:'Facility Administration', renewal:'498 days'},
   activity:{when:'Today', what:'Teaching rotation updated'},
   detail:{kind:'teaching',
     facts:[['Medical students',24],['Residents',6],['Supervisors',4],['Active rotations',3]],
     departments:['Medicine','Surgery','Paediatrics','Obstetrics & Gynaecology'],
     capacity:82}},
  {id:'kisii_research', name:'Kisii Research Institute', type:'Research Center', rel:'Research', dir:'bi', state:'ACTIVE', color:'#7c3aed', cat:'research',
   agreement:{kind:'MOU', status:'Active', effective:'01 Jan 2026', expires:'31 Dec 2027', owner:'Research Governance', renewal:'498 days'},
   activity:{when:'Yesterday', what:'Research data-access request submitted'},
   detail:{kind:'research',
     facts:[['Active studies',3],['Approved data-access requests',2],['Pending review',1]],
     note:'Research access is governed by approved purpose, cohort, permissions and data-governance rules. The Facility Administrator does not automatically get access to research participant data.'}}
];
const ECO_ACTIVITY = [
  {t:'20:04', what:'Referral accepted', who:'Kenyatta County Hospital'},
  {t:'19:58', what:'Laboratory result received', who:'Kisii Medical Laboratory'},
  {t:'19:41', what:'Supply requisition fulfilled', who:'Wellness Pharmacy Network'},
  {t:'18:52', what:'Teaching rotation updated', who:'Egerton University'},
  {t:'17:33', what:'Research data-access request submitted', who:'Kisii Research Institute'}
];
const ECO_RISKS = [
  {sev:'🟠', cat:'Referral dependency', who:'Kenyatta County Hospital', issue:'Orthopaedics receiving capacity approaching configured threshold.', act:'Review referral network →'},
  {sev:'🟠', cat:'Supplier dependency', who:'Medical oxygen', issue:'Single active supplier.', act:'Review supply resilience →'},
  {sev:'🟡', cat:'Agreement', who:'Sunshine Referral Hospital', issue:'MOU review due in 45 days.', act:'Review agreement →'}
];
window.PARTNERS = PARTNERS; window.ECO_ACTIVITY = ECO_ACTIVITY; window.ECO_RISKS = ECO_RISKS;

/* ---------- DHA / NATIONAL REPORTING ---------- */
const REPORT_DOMAINS = [
  {name:'Patient demographics', pct:100},
  {name:'Encounters', pct:100},
  {name:'Diagnoses', pct:97},
  {name:'Procedures', pct:99},
  {name:'Laboratory', pct:95},
  {name:'Pharmacy', pct:93},
  {name:'Maternity', pct:98},
  {name:'Mortality', pct:100}
];
const REPORTING_ISSUES = [
  {record:'2 maternity records', issue:'Missing outcome'},
  {record:'1 discharge record', issue:'Incomplete diagnosis coding'},
  {record:'4 laboratory records', issue:'Missing service classification'},
  {record:'7 encounters', issue:'Inconsistent demographic field'},
  {record:'3 pharmacy records', issue:'Missing dose coding'}
];
const HMIS_PIPELINE = ['Clinical event','Structured AMEXAN record','Validation','Interoperability mapping','HMIS/DHA dataset','Submission','Acknowledgement'];
const MIGRATION = {patients:38492, matched:37921, duplicates:412, review:159, sources:['Legacy EMR','HMIS','Spreadsheets','Patient registry','Staff registry','Inventory','Finance','Laboratory','Pharmacy']};
const MIGRATION_PIPELINE = ['Source','Map','Validate','Normalize','Deduplicate','Reconcile','Preview','Commit','Audit'];
window.REPORT_DOMAINS = REPORT_DOMAINS; window.REPORTING_ISSUES = REPORTING_ISSUES;

/* ---------- PER-FACILITY OPERATIONAL DAY ---------- */
const FACILITY_DAY = {
  ktrh:{patients:128, encounters:42, admissions:18, discharges:12, occupancy:84,
    strip:{emergency:14, theatre:3, maternity:11, lab:38, radiology:17, pharmacy:29, blood:6},
    trend:{patients:[132,128,141,118,126,121,128], rev:[41,39,45,40,46,44,48]},
    wards:[['General Medical',42,32,76,'#0284c7'],['Paediatrics',24,20,83,'#d97706'],['Maternity',18,16,89,'#7c3aed'],['Surgical',40,34,85,'#059669'],['ICU',10,9,91,'#dc2626']]},
  kch:{patients:61, encounters:19, admissions:9, discharges:5, occupancy:71,
    strip:{emergency:6, theatre:1, maternity:4, lab:16, radiology:6, pharmacy:12, blood:2},
    trend:{patients:[58,63,55,66,61,59,61], rev:[18,17,20,16,19,18,19]},
    wards:[['General Medical',60,44,73,'#0284c7'],['Surgical',42,30,71,'#059669'],['Maternity',28,20,71,'#7c3aed'],['Paediatrics',30,21,70,'#d97706']]},
  mat:{patients:24, encounters:11, admissions:6, discharges:4, occupancy:82,
    strip:{emergency:2, theatre:0, maternity:8, lab:9, radiology:3, pharmacy:7, blood:3},
    trend:{patients:[22,25,24,21,26,24,24], rev:[9,10,9,8,11,9,9]},
    wards:[['Maternity Ward',18,15,83,'#7c3aed'],['Labour Suite',6,5,83,'#dc2626'],['Neonatal Unit',8,7,88,'#0284c7'],['Post-natal Ward',20,16,80,'#059669']]},
  chr:{patients:18, encounters:8, admissions:3, discharges:2, occupancy:65,
    strip:{emergency:1, theatre:0, maternity:0, lab:4, radiology:0, pharmacy:6, blood:0},
    trend:{patients:[16,19,17,20,18,17,18], rev:[6,6,7,6,7,6,6]},
    wards:[['Chronic Care',12,8,67,'#0284c7'],['General Ward',22,14,64,'#059669']]},
  obc:{patients:9, encounters:4, admissions:1, discharges:1, occupancy:50,
    strip:{emergency:0, theatre:0, maternity:0, lab:1, radiology:0, pharmacy:2, blood:0},
    trend:{patients:[8,10,9,9,10,8,9], rev:[3,3,3,4,3,3,3]},
    wards:[['Community Beds',12,6,50,'#0284c7']]}
};
const dayFor = id => FACILITY_DAY[id] || FACILITY_DAY.ktrh;
window.FACILITY_DAY = FACILITY_DAY;

/* ---------- FINANCE ---------- */
const FINANCE = {
  todayRevenue:'KES 4.8M', claims:'KES 2.1M', pendingClaims:'KES 740K', outstanding:'KES 1.3M',
  services:[['OPD',42],['Inpatient',18],['Theatre',6],['Maternity',11],['Laboratory',23],['Radiology',9],['Pharmacy',29]],
  shaLines:[['Submitted',86],['Accepted',74],['Rejected',3],['Pending',9]]
};
window.FINANCE = FINANCE;

/* ---------- QUALITY · SAFETY & GOVERNANCE ---------- */
const INCIDENTS = [
  {id:'IN-1041', type:'Medication incident', sev:'red', status:'Under review', dept:'Medicine', time:'13:20'},
  {id:'IN-1040', type:'Patient fall', sev:'red', status:'Investigation', dept:'Paediatrics', time:'12:05'},
  {id:'IN-1039', type:'Delayed investigation', sev:'amber', status:'Follow-up', dept:'Emergency', time:'11:40'},
  {id:'IN-1038', type:'Infection control event', sev:'amber', status:'Under review', dept:'ICU', time:'10:15'},
  {id:'IN-1037', type:'Equipment failure', sev:'green', status:'Resolved', dept:'Radiology', time:'09:30'},
  {id:'IN-1036', type:'Documentation gap', sev:'green', status:'Resolved', dept:'OPD', time:'08:22'},
  {id:'IN-1035', type:'Blood transfusion reaction', sev:'red', status:'Under review', dept:'Laboratory', time:'07:50'}
];
const GOVERNANCE = [
  {item:'Policy — Sharps handling review', status:'In approval', owner:'Safety committee', due:'22 Aug'},
  {item:'Audit — Controlled drugs register', status:'Scheduled', owner:'Pharmacy', due:'25 Aug'},
  {item:'Audit — Theatre checklists compliance', status:'Completed', owner:'Surgery', due:'19 Aug'},
  {item:'Corrective action — CT downtime protocol', status:'In progress', owner:'Radiology', due:'28 Aug'},
  {item:'Approval — Neonatal phototherapy protocol', status:'Pending', owner:'OBGYN', due:'30 Aug'}
];
window.INCIDENTS = INCIDENTS; window.GOVERNANCE = GOVERNANCE;

/* ---------- RESEARCH INTELLIGENCE ---------- */
const RESEARCH = {
  studies:12, enrolled:1482, review:3, requests:7,
  active:[
    {title:'Determinants of neonatal sepsis outcomes in Kisii County', pi:'Dr. R. Monari', enrolled:214, status:'Active', needs:2},
    {title:'AMR surveillance — Kisii Referral Laboratory', pi:'Dr. B. Ogoti', enrolled:388, status:'Active', needs:1},
    {title:'Hypertension control in community clinics', pi:'Dr. I. Bosibori', enrolled:512, status:'Active', needs:0},
    {title:'Telemedicine follow-up for diabetes in OPD', pi:'Dr. B. Kamau', enrolled:146, status:'Recruiting', needs:1}
  ]
};
const RESEARCH_REQUESTS = [
  {title:'De-identified encounter dataset — 2024 hypertension cohort', requester:'Kisii Research Institute', scope:'Patients with hypertension, de-identified', status:'Pending approval'},
  {title:'Laboratory AMR isolates — anonymised', requester:'Egerton University', scope:'Microbiology results, no identifiers', status:'Pending approval'},
  {title:'Maternity outcomes follow-up', requester:'Dr. R. Monari (internal)', scope:'OBGYN cohort 2023–2025', status:'Approved'},
  {title:'Community clinic workload data', requester:'MOH Research Unit', scope:'Aggregate counts only', status:'Pending approval'}
];
window.RESEARCH = RESEARCH; window.RESEARCH_REQUESTS = RESEARCH_REQUESTS;

/* ---------- SECURITY CENTER ---------- */
const SECURITY = {
  sessions:219, failedLogins:4, suspicious:1, privileged:17, reviews:8,
  api:[
    {name:'HMIS Bridge', owner:'ICT', last:'14:01', scopes:['encounters','diagnoses']},
    {name:'DHA Reporter', owner:'HMIS Clerk', last:'12:40', scopes:['national dataset']},
    {name:'SHA Gateway', owner:'Finance', last:'13:55', scopes:['claims','eligibility']},
    {name:'Lab Interface', owner:'Laboratory', last:'Live', scopes:['orders','results']}
  ],
  audit:[
    {who:'Sarah Ochieng', what:'Approved provisioning — 10 Surgery nurses', when:'13:45'},
    {who:'ICT Officer K. Ogechi', what:'Reconnected laboratory interface', when:'13:50'},
    {who:'Dr. G. Kerubo', what:'Closed encounter ENC-000140', when:'13:31'},
    {who:'HMIS Clerk', what:'Submitted daily DHA dataset', when:'12:40'}
  ]
};
window.SECURITY = SECURITY;

/* ---------- CLINICAL INTELLIGENCE STATUS ---------- */
const CLINICAL_INTEL = {
  engine:'Operational', baseline:'Active', kenya:'Active', facilityRules:24, pendingReview:3,
  versions:[
    {v:'v2.4', change:'NEWS2 risk thresholds applied', status:'Active', date:'12 Aug'},
    {v:'v2.3', change:'Kenya sepsis pathway rules', status:'Active', date:'28 Jul'},
    {v:'v2.2', change:'Local antibiotic stewardship edits', status:'Active', date:'14 Jul'},
    {v:'v2.5', change:'Proposed — neonatal jaundice thresholds', status:'Pending review', date:'18 Aug'}
  ]
};
window.CLINICAL_INTEL = CLINICAL_INTEL;

/* ---------- EDUCATION / COMMS / PROTOCOLS / MARKETPLACE ---------- */
const EDUCATION = {
  students:42, interns:18, residents:12, consultants:9, teachingCases:7, simSessions:3,
  rotations:[
    {cohort:'Medical Students — Block 4', dept:'Medicine', count:14, supervisor:'Dr. T. Nyaboke'},
    {cohort:'Interns — Surgical Rotation', dept:'Surgery', count:9, supervisor:'Dr. K. Nyangena'},
    {cohort:'Residents — Paediatrics', dept:'Paediatrics', count:6, supervisor:'Dr. P. Anyona'},
    {cohort:'Midwifery Students — OBGYN', dept:'Obstetrics & Gynaecology', count:11, supervisor:'Midwife J. Nyakerario'}
  ]
};
const COMMS = [
  {id:'COM-000421', kind:'alert', title:'Emergency — ED capacity', body:'Emergency is at 92% of capacity. Divert stable walk-ins to OPD.', scope:'Facility-wide', time:'13:15', author:'Dr. G. Kerubo', role:'Emergency Department Lead', pri:'🔴', priLabel:'Emergency', ack:true, recipients:42, acknowledged:41, pending:1, active:true, links:{service:'Emergency', asset:'—', incident:'—'}},
  {id:'COM-000420', kind:'announcement', title:'Blood drive — Friday 08:00', body:'Donor session in the main courtyard. Staff welcome.', scope:'Facility-wide', time:'11:00', author:'Blood Bank', role:'Blood Bank', pri:'🟢', priLabel:'Normal', ack:false, recipients:42, acknowledged:null, pending:null, active:true, links:null},
  {id:'COM-000419', kind:'notice', title:'Theatre schedule change', body:'Theatre 1 maintenance moved to Saturday 09:00.', scope:'Surgery + Theatre', time:'10:20', author:'Theatre In-charge', role:'Theatre In-charge', pri:'🟠', priLabel:'Important', ack:true, recipients:18, acknowledged:18, pending:0, active:true, links:null, effective:'Saturday 09:00', expires:'Saturday 18:00'},
  {id:'COM-000418', kind:'clinical', title:'Protocol — neonatal sepsis', body:'Updated protocol thresholds are under review in Protocol Center.', scope:'OBGYN + Paediatrics', time:'09:40', author:'Clinical Intelligence', role:'Clinical Intelligence', pri:'🔵', priLabel:'Clinical notice', ack:false, recipients:null, acknowledged:null, pending:null, active:true, links:{protocol:'Neonatal sepsis thresholds'}},
  {id:'COM-000417', kind:'announcement', title:'Parking gate closure — resolved', body:'Parking gate reopened after maintenance.', scope:'Facility-wide', time:'Yesterday', author:'Facilities', role:'Facilities', pri:'🟢', priLabel:'Normal', ack:false, recipients:null, acknowledged:null, pending:null, active:false, archived:true, links:null}
];
const COMM_DRAFT = [
  {id:'DRAFT-012', kind:'alert', title:'(draft) Lab reagent delivery delay', body:'Expected LIS reagent delivery delayed by 2 hours.', scope:'Laboratory', author:'Laboratory Lead', pri:'🟠', priLabel:'Important', ack:true}
];
const COMM_ALERTS = [
  {sev:'🔴', name:'Emergency capacity', detail:'Emergency at 92% configured capacity', source:'Clinical Operations', act:'Open clinical operations →'},
  {sev:'🟠', name:'Theatre maintenance', detail:'Theatre 1 out Saturday 09:00–18:00', source:'Service Catalogue', act:'Open service catalogue →'},
  {sev:'🟠', name:'CT availability', detail:'CT service availability in question', source:'Asset Intelligence · CT-RAD-001', act:'Open asset intelligence →'}
];
const COMM_SUGGEST = [
  {title:'Radiology CT service unavailable', body:'Radiology CT service unavailable. Emergency and inpatient teams should use approved alternative pathway.', recipients:['Radiology','Emergency','Inpatient','Theatre'], source:'Asset Intelligence · CT-RAD-001', auto:false},
  {title:'Emergency capacity threshold exceeded', body:'Emergency Department is at 92% configured capacity. Stable walk-in patients should be directed to General OPD.', recipients:['Emergency','General OPD','Triage','Security','Registration'], source:'Clinical Operations · capacity event', auto:false}
];
const COMM_AUDIT = [
  {id:'COM-000421', sender:'Dr. G. Kerubo', role:'Emergency Department Lead', sent:'13:15', audience:'Facility-wide', pri:'Emergency', delivery:'42/42', ack:'41/42', escalation:'1 pending'},
  {id:'COM-000420', sender:'Blood Bank', role:'Blood Bank', sent:'11:00', audience:'Facility-wide', pri:'Normal', delivery:'42/42', ack:'—', escalation:'—'},
  {id:'COM-000419', sender:'Theatre In-charge', role:'Theatre In-charge', sent:'10:20', audience:'Surgery + Theatre', pri:'Important', delivery:'18/18', ack:'18/18', escalation:'—'}
];
const PROTOCOLS = [
  {layer:'DEFAULT', name:'Global clinical baseline', owner:'AMEXAN clinical governance', status:'Active', count:120},
  {layer:'COUNTRY', name:'Kenya national guidelines', owner:'MOH Kenya', status:'Active', count:64},
  {layer:'FACILITY', name:'KTRH local adaptations', owner:'Facility Administrator', status:'Active', count:24, pending:3},
  {layer:'DEPARTMENT', name:'Department protocols', owner:'Department heads', status:'Active', count:41},
  {layer:'CLINICIAN', name:'Clinician preference rules', owner:'Individual clinicians', status:'Active', count:0},
  {layer:'PATIENT CONTEXT', name:'Patient-specific adaptations', owner:'Care team', status:'Active', count:0}
];
const MARKETPLACE = [
  {name:'MedTech Kenya Ltd', cat:'Medical equipment', rel:'Approved supplier', orders:4},
  {name:'KEMSA', cat:'Consumables & drugs', rel:'National supplier', orders:12},
  {name:'PharmaConnect East Africa', cat:'Pharmaceuticals', rel:'Approved supplier', orders:8},
  {name:'LabSupply Kisii', cat:'Laboratory reagents', rel:'Approved supplier', orders:6},
  {name:'SterileCare Services', cat:'Service provider', rel:'Contract', orders:1}
];
window.EDUCATION = EDUCATION; window.COMMS = COMMS; window.COMM_DRAFT = COMM_DRAFT; window.COMM_ALERTS = COMM_ALERTS; window.COMM_SUGGEST = COMM_SUGGEST; window.COMM_AUDIT = COMM_AUDIT; window.PROTOCOLS = PROTOCOLS; window.MARKETPLACE = MARKETPLACE;

/* ---------- CHART HELPERS (SVG, no libraries) ---------- */
function miniDonut(pct, color, size=116, label=''){
  const R=(size-20)/2, C=2*Math.PI*R, len=pct/100*C;
  return `<div class="donut-wrap" style="width:${size}px;height:${size}px">
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
      <circle r="${R}" cx="${size/2}" cy="${size/2}" fill="none" stroke="#eef2f7" stroke-width="16"/>
      <circle r="${R}" cx="${size/2}" cy="${size/2}" fill="none" stroke="${color}" stroke-width="16" stroke-linecap="round" stroke-dasharray="${len} ${C-len}" transform="rotate(-90 ${size/2} ${size/2})"/>
    </svg>
    <div class="donut-center"><b>${pct}%</b>${label?`<small>${label}</small>`:''}</div>
  </div>`;
}
function multiDonut(segments, size=148){
  const total=segments.reduce((a,s)=>a+s.v,0)||1;
  const R=(size-20)/2, C=2*Math.PI*R; let off=0;
  const arcs=segments.map(s=>{
    const frac=s.v/total, len=frac*C, rot=off*360; off+=frac;
    return `<circle r="${R}" cx="${size/2}" cy="${size/2}" fill="none" stroke="${s.color}" stroke-width="18" stroke-dasharray="${len} ${C-len}" stroke-dashoffset="${(-rot/360)*C}" transform="rotate(-90 ${size/2} ${size/2})"/>`;
  }).join('');
  return `<div class="donut-wrap" style="width:${size}px;height:${size}px">
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${arcs}</svg>
    <div class="donut-center"><b>${total}</b></div>
  </div>`;
}
function legend(segments){
  const total=segments.reduce((a,s)=>a+s.v,0)||1;
  return segments.map(s=>`<div class="row gap1" style="font-size:12px;color:var(--muted)"><span class="dot" style="background:${s.color}"></span>${s.label}<span class="mono" style="margin-left:auto;color:#0f172a">${Math.round(s.v/total*100)}%</span></div>`).join('');
}
function spark(series, w=150, h=42, color='#0284c7'){
  const min=Math.min(...series), max=Math.max(...series), range=(max-min)||1;
  const pts=series.map((v,i)=>`${(i/(series.length-1))*w},${(h-8)-((v-min)/range)*(h-16)}`).join(' ');
  return `<svg class="spark" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><polyline fill="none" stroke="${color}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" points="${pts}"/></svg>`;
}
function hbar(v, max, color, w=220){
  const pct=Math.min(100, Math.round(v/max*100));
  return `<div class="bar-h" style="max-width:${w}px"><div style="width:${pct}%;background:${color}"></div></div>`;
}
window.miniDonut = miniDonut; window.multiDonut = multiDonut; window.legend = legend; window.spark = spark; window.hbar = hbar;

/* ---------- PROVISIONING ENGINE ---------- */
const PROVISION_LOG = [];
function provisionStaff(deptId, roleId, count, seed){
  const d = dept(deptId);
  const role = WORKFORCE_ROLES.find(r=>r.id===roleId) || {name:roleId, workspace:workspaceFor(roleId)};
  const created=[];
  const base=(seed||d.code).toUpperCase();
  for(let i=1;i<=count;i++){
    const sid=String(i).padStart(3,'0');
    const rec={id:`${base}-${sid}`, name:`${role.name} ${sid}`, dept:d.name, deptId:d.id, role:role.name, roleId:role.id,
      workspace:role.workspace, status:'Pending activation', roster:'Unassigned', provisioned:true};
    WORKFORCE.unshift(rec); created.push(rec);
  }
  PROVISION_LOG.unshift({t:new Date().toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'}), dept:d.name, role:role.name, count, base, created});
  return created;
}
window.provisionStaff = provisionStaff; window.PROVISION_LOG = PROVISION_LOG;