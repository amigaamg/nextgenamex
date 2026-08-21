/* =================================================================
   AMEXAN — CONTEXT-AWARE CLINICAL INTELLIGENCE ENGINE
   Computes intelligent workspace content based on:
   1. Patient's longitudinal record
   2. Active encounter data
   3. Selected clinical context (clinic type)
   ================================================================= */

const ContextIntelligence = {
  currentContext: null,
  patientData: null,
  encounterData: null,
  longitudinalData: null,

  setContext(contextId) {
    this.currentContext = getContext(contextId);
    return this.currentContext;
  },

  setPatient(patient, encounter = null) {
    this.patientData = patient;
    this.encounterData = encounter;
    this.longitudinalData = this.buildLongitudinalData(patient.mrn);
  },

  buildLongitudinalData(mrn) {
    const timeline = (window.TIMELINE || []).filter(t => t.mrn === mrn);
    const encounters = (window.ENCOUNTERS || []).filter(e => e.mrn === mrn);
    const labs = this.extractLabTrends(encounters);
    const vitals = this.extractVitalTrends(encounters);

    return {
      timeline,
      encounters,
      labs,
      vitals,
      problems: this.patientData?.conditions || [],
      allergies: this.patientData?.allergies || [],
      medications: this.getCurrentMedications(encounters)
    };
  },

  extractLabTrends(encounters) {
    const trends = {
      hba1c: [], fastingGlucose: [], bp: [], weight: [], egfr: [],
      hb: [], wbc: [], crp: [], creatinine: [], ldl: [], urineACR: []
    };

    encounters.forEach(enc => {
      const d = enc.d;
      if (!d) return;
      const date = enc.date;
      const inv = d.inv || {};

      if (inv.hba1c) {
        const val = parseFloat(inv.hba1c.match(/([\d.]+)/)?.[1]);
        if (!isNaN(val)) trends.hba1c.push({ date, value: val, encounter: enc.id });
      }
      if (inv.fastingGlucose || inv.glucose) {
        const val = parseFloat((inv.fastingGlucose || inv.glucose).match(/([\d.]+)/)?.[1]);
        if (!isNaN(val)) trends.fastingGlucose.push({ date, value: val, encounter: enc.id });
      }
      if (d.risk?.sbp && d.risk?.dbp) {
        trends.bp.push({ date, sbp: d.risk.sbp, dbp: d.risk.dbp, encounter: enc.id });
      }
      if (d.risk?.weight) {
        trends.weight.push({ date, value: d.risk.weight, encounter: enc.id });
      }
      if (inv.egfr) {
        const val = parseFloat(inv.egfr.match(/([\d.]+)/)?.[1]);
        if (!isNaN(val)) trends.egfr.push({ date, value: val, encounter: enc.id });
      }
      if (inv.urineACR) {
        const val = parseFloat(inv.urineACR.match(/([\d.]+)/)?.[1]);
        if (!isNaN(val)) trends.urineACR.push({ date, value: val, encounter: enc.id });
      }
      if (inv.cbc) {
        const hbMatch = inv.cbc.match(/Hb\s+([\d.]+)/);
        const wbcMatch = inv.cbc.match(/WBC\s+([\d.]+)/);
        if (hbMatch) trends.hb.push({ date, value: parseFloat(hbMatch[1]), encounter: enc.id });
        if (wbcMatch) trends.wbc.push({ date, value: parseFloat(wbcMatch[1]), encounter: enc.id });
      }
      if (inv.crp) {
        const val = parseFloat(inv.crp.match(/([\d.]+)/)?.[1]);
        if (!isNaN(val)) trends.crp.push({ date, value: val, encounter: enc.id });
      }
      if (inv.creatinine) {
        const val = parseFloat(inv.creatinine.match(/([\d.]+)/)?.[1]);
        if (!isNaN(val)) trends.creatinine.push({ date, value: val, encounter: enc.id });
      }
    });

    return trends;
  },

  extractVitalTrends(encounters) {
    const trends = { bp: [], weight: [], temp: [], hr: [], rr: [], spo2: [] };
    encounters.forEach(enc => {
      const d = enc.d;
      if (!d?.risk) return;
      const date = enc.date;
      if (d.risk.sbp && d.risk.dbp) trends.bp.push({ date, sbp: d.risk.sbp, dbp: d.risk.dbp });
      if (d.risk.weight) trends.weight.push({ date, value: d.risk.weight });
      if (d.risk.temp) trends.temp.push({ date, value: d.risk.temp });
      if (d.risk.hr) trends.hr.push({ date, value: d.risk.hr });
      if (d.risk.rr) trends.rr.push({ date, value: d.risk.rr });
      if (d.risk.spo2) trends.spo2.push({ date, value: d.risk.spo2 });
    });
    return trends;
  },

  getCurrentMedications(encounters) {
    const completed = encounters.filter(e => e.status === 'Completed' && e.d?.plan?.meds?.length);
    if (completed.length === 0) return [];
    return completed[completed.length - 1].d.plan.meds;
  },

  computeSnapshot() {
    if (!this.currentContext || !this.patientData) return null;

    const ctx = this.currentContext;
    const snap = {};
    const p = this.patientData;
    const e = this.encounterData;
    const long = this.longitudinalData;

    ctx.intelligence.snapshotKeys.forEach(key => {
      snap[key] = this.getSnapshotValue(key, p, e, long);
    });

    return snap;
  },

  getSnapshotValue(key, patient, encounter, longitudinal) {
    const d = encounter?.d;
    const risk = d?.risk || {};
    const inv = d?.inv || {};
    const facts = d?.facts || {};
    const exam = d?.exam || {};

    const labTrends = longitudinal?.labs || {};
    const vitalTrends = longitudinal?.vitals || {};

    const latest = (arr) => arr.length ? arr[arr.length - 1] : null;

    switch (key) {
      case 'chiefComplaint':
        return encounter?.cc || 'No active complaint';
      case 'vitals':
        return {
          temp: risk.temp, hr: risk.hr, rr: risk.rr,
          spo2: risk.spo2, bp: risk.sbp && risk.dbp ? `${risk.sbp}/${risk.dbp}` : null,
          weight: risk.weight
        };
      case 'recentEncounters':
        return longitudinal?.encounters?.slice(-3).reverse() || [];
      case 'activeProblems':
        return patient?.conditions || [];
      case 'allergies':
        return patient?.allergies || [];
      case 'medications':
        return this.getCurrentMedications(longitudinal?.encounters || []);

      case 'hba1c':
        const hba1c = latest(labTrends.hba1c);
        return hba1c ? { value: hba1c.value, date: hba1c.date, trend: this.computeTrend(labTrends.hba1c) } : null;
      case 'fastingGlucose':
        const fg = latest(labTrends.fastingGlucose);
        return fg ? { value: fg.value, date: fg.date, trend: this.computeTrend(labTrends.fastingGlucose) } : null;
      case 'bp':
        const bp = latest(vitalTrends.bp);
        return bp ? { value: `${bp.sbp}/${bp.dbp}`, date: bp.date, trend: this.computeTrend(vitalTrends.bp.map(b => b.sbp)) } : null;
      case 'weight':
        const wt = latest(vitalTrends.weight);
        return wt ? { value: wt.value, date: wt.date, trend: this.computeTrend(vitalTrends.weight.map(w => w.value)) } : null;
      case 'egfr':
        const egfr = latest(labTrends.egfr);
        return egfr ? { value: egfr.value, date: egfr.date, trend: this.computeTrend(labTrends.egfr.map(e => e.value)) } : null;
      case 'urineACR':
        const acr = latest(labTrends.urineACR);
        return acr ? { value: acr.value, date: acr.date, trend: this.computeTrend(labTrends.urineACR.map(a => a.value)) } : null;
      case 'lipids':
        return null;
      case 'lastEyeExam':
        return 'Not recorded';
      case 'lastFootExam':
        return 'Not recorded';

      case 'bpTrend':
        return vitalTrends.bp.slice(-6).map(b => ({ date: b.date, sbp: b.sbp, dbp: b.dbp }));
      case 'homeBP':
        return null;

      case 'genotype':
        return patient?.conditions?.find(c => c.includes('SC') || c.includes('Sickle')) || 'SS (assumed)';
      case 'baselineHb':
        const hb = latest(labTrends.hb);
        return hb ? `${hb.value} g/dL` : 'Not recorded';
      case 'crisisFrequency':
        return '3 crises in past year (demo)';
      case 'recentAdmissions':
        return longitudinal?.encounters?.filter(e => e.type === 'Inpatient' || e.type === 'Emergency').slice(-3) || [];
      case 'painEpisodes':
        return 'Demo data — crisis log';
      case 'transfusionHistory':
        return 'Demo data — transfusion log';
      case 'hydroxyureaDose':
        return '15 mg/kg/day (demo)';
      case 'renalFunction':
        const egfr2 = latest(labTrends.egfr);
        return egfr2 ? `eGFR ${egfr2.value} mL/min` : 'Not recorded';
      case 'liverFunction':
        return 'Normal (demo)';
      case 'vaccinationStatus':
        return 'Pneumococcal: 2024, Meningococcal: 2023 (demo)';
      case 'complications':
        return ['Avascular necrosis (L hip)', 'Retinopathy (mild)'];
      case 'cbcTrends':
        return {
          hb: labTrends.hb.slice(-6),
          wbc: labTrends.wbc.slice(-6),
          plt: [] // demo
        };
      case 'specialistReviews':
        return ['Ophthalmology: 2024-06', 'Orthopaedics: 2024-03'];

      case 'gestationalAge':
        return '26 weeks (demo)';
      case 'edd':
        return '2026-11-15 (demo)';
      case 'gravida':
        return 'G2P1';
      case 'parity':
        return '1';
      case 'fundalHeight':
        return '26 cm';
      case 'fhr':
        return '142 bpm';
      case 'presentation':
        return 'Cephalic';
      case 'bloodGroup':
        return patient?.blood || 'A+';
      case 'hiv':
        return 'Negative (21 Jul 2026)';
      case 'syphilis':
        return 'Negative (21 Jul 2026)';
      case 'hepatitis':
        return 'HBsAg Negative (21 Jul 2026)';
      case 'urineProtein':
        return 'Negative';
      case 'glucose':
        return 'Normal (OGTT pending)';
      case 'scanHistory':
        return ['Booking scan: 21 Jul 2026', 'Anatomy scan: pending'];
      case 'riskFactors':
        return ['Age > 35: No', 'Previous CS: No', 'Hypertension: No'];

      case 'acuity':
        return encounter?.queue === 'Casualty' ? 'high' : 'medium';
      case 'presentingComplaint':
        return encounter?.cc || 'Awaiting triage';
      case 'gcs':
        return facts.gcs || '15';
      case 'trauma':
        return facts.trauma || 'No';
      case 'investigationsPending':
        return ['CBC', 'CXR', 'ECG'].filter(t => !inv[t.toLowerCase()]);
      case 'disposition':
        return 'Awaiting doctor review';

      case 'age':
        return patient?.age || 0;
      case 'height':
        return 'Not recorded';
      case 'headCircumference':
        return 'Not recorded';
      case 'immunization':
        return 'Up to date (demo)';
      case 'growthPercentiles':
        return { weight: '50th', height: '45th', bmi: '55th' };
      case 'developmentalMilestones':
        return 'Age-appropriate (demo)';
      case 'feedingHistory':
        return 'Mixed feeding (demo)';
      case 'chronicConditions':
        return patient?.conditions || [];

      case 'diagnosis':
        return encounter?.dx || 'Under investigation';
      case 'stage':
        return 'Stage III (demo)';
      case 'treatmentProtocol':
        return 'FOLFOX (demo)';
      case 'cycleNumber':
        return 'Cycle 3 of 6';
      case 'lastTreatment':
        return '2026-08-10';
      case 'performanceStatus':
        return 'ECOG 1';
      case 'recentBloods':
        return { hb: 10.2, wbc: 3.8, anc: 1.8, plt: 145, crea: 88, alt: 32 };
      case 'imagingSchedule':
        return 'CT chest/abdomen: due cycle 4';
      case 'toxicityProfile':
        return { neuropathy: 'Grade 1', nausea: 'Grade 2', fatigue: 'Grade 1' };
      case 'supportiveCare':
        return ['G-CSF prophylaxis', 'Antiemetics', 'Loperamide PRN'];

      case 'ef':
        return '35% (2026-07-15)';
      case 'nyhaClass':
        return 'Class II';
      case 'rhythm':
        return 'Sinus rhythm';
      case 'deviceStatus':
        return 'None';
      case 'recentEcho':
        return '2026-07-15: EF 35%, mild MR';
      case 'recentECG':
        return '2026-08-01: Sinus rhythm, LBBB';
      case 'biomarkers':
        return { ntprobnp: 1240, troponin: '<5' };

      default:
        return null;
    }
  },

  computeTrend(arr) {
    if (!arr || arr.length < 2) return 'stable';
    const recent = arr.slice(-3);
    const first = recent[0].value;
    const last = recent[recent.length - 1].value;
    const diff = last - first;
    const pct = first !== 0 ? (diff / first) * 100 : 0;
    if (Math.abs(pct) < 5) return 'stable';
    return diff > 0 ? 'up' : 'down';
  },

  computePriorities() {
    if (!this.currentContext) return [];
    const priorities = [];
    const ctx = this.currentContext;
    const snap = this.computeSnapshot();

    ctx.intelligence.clinicalPriorities.forEach(priority => {
      const triggered = this.evaluateCondition(priority.condition, snap);
      if (triggered) {
        priorities.push({
          label: priority.label,
          severity: priority.severity,
          condition: priority.condition
        });
      }
    });

    return priorities;
  },

  evaluateCondition(condition, snapshot) {
    try {
      const evalFn = new Function('snap', 'long', 'return ' + condition);
      return evalFn(snapshot, this.longitudinalData);
    } catch {
      return false;
    }
  },

  computeDueMonitoring() {
    if (!this.currentContext) return [];
    const due = [];
    const ctx = this.currentContext;
    const long = this.longitudinalData;

    ctx.intelligence.dueMonitoring.forEach(item => {
      const status = this.checkDueStatus(item.key, long);
      due.push({
        ...item,
        status: status.due ? 'due' : status.overdue ? 'overdue' : 'current',
        lastDone: status.lastDone,
        nextDue: status.nextDue
      });
    });

    return due;
  },

  checkDueStatus(key, longitudinal) {
    const labs = longitudinal?.labs || {};
    const encounters = longitudinal?.encounters || [];

    const findLast = (pattern) => {
      for (let i = encounters.length - 1; i >= 0; i--) {
        const inv = encounters[i].d?.inv || {};
        const keys = Object.keys(inv);
        if (keys.some(k => k.toLowerCase().includes(pattern.toLowerCase()))) {
          return { date: encounters[i].date, value: inv[keys.find(k => k.toLowerCase().includes(pattern.toLowerCase()))] };
        }
      }
      return null;
    };

    switch (key) {
      case 'hba1c':
        const lastHba1c = findLast('hba1c');
        return this.computeDue(lastHba1c, 90);
      case 'renal':
        const lastRen = findLast('creat') || findLast('egfr') || findLast('urea');
        return this.computeDue(lastRen, 180);
      case 'urineACR':
        const lastAcr = findLast('acr');
        return this.computeDue(lastAcr, 365);
      case 'foot':
      case 'retinal':
      case 'lipids':
      case 'ecg':
      case 'fundoscopy':
      case 'transcranial':
      case 'eye':
      case 'vaccines':
        return { due: true, overdue: false, lastDone: 'Not recorded', nextDue: 'Now' };
      case 'bp':
        return { due: true, overdue: false, lastDone: 'Today', nextDue: '1 month' };
      case 'cbc':
        return { due: true, overdue: false, lastDone: 'Not recorded', nextDue: 'Now' };
      case 'growth':
      case 'development':
      case 'immunization':
        return { due: false, overdue: false, lastDone: 'Current', nextDue: 'Per schedule' };
      case 'fbc':
      case 'lfts':
      case 'biomarkers':
      case 'cardiac':
        return { due: true, overdue: false, lastDone: 'Not recorded', nextDue: 'Per protocol' };
      case 'echo':
        return { due: true, overdue: false, lastDone: 'Not recorded', nextDue: '6-12 months' };
      default:
        return { due: false, overdue: false, lastDone: 'Unknown', nextDue: 'Unknown' };
    }
  },

  computeDue(lastDone, intervalDays) {
    if (!lastDone) return { due: true, overdue: true, lastDone: 'Never', nextDue: 'Now' };
    const lastDate = new Date(lastDone.date);
    const now = new Date();
    const daysSince = (now - lastDate) / (1000 * 60 * 60 * 24);
    const due = daysSince >= intervalDays;
    const overdue = daysSince >= intervalDays * 1.5;
    return { due, overdue, lastDone: lastDone.date, nextDue: due ? 'Now' : `${Math.round(intervalDays - daysSince)} days` };
  },

  computeDifferentials() {
    if (!this.currentContext || !this.encounterData) return [];
    const ctx = this.currentContext;
    const triggers = ctx.intelligence.differentialTriggers;
    const facts = this.encounterData.d?.facts || {};
    const cc = (this.encounterData.cc || '').toLowerCase();

    return triggers.filter(t => {
      const factKey = t.toLowerCase().replace(/\s+/g, '');
      return facts[factKey] || cc.includes(t.toLowerCase());
    }).map(t => ({
      trigger: t,
      suggested: this.getDifferentialForTrigger(t)
    }));
  },

  getDifferentialForTrigger(trigger) {
    const map = {
      'fever': ['Infection', 'Sepsis', 'Malignancy', 'Autoimmune'],
      'pain': ['Musculoskeletal', 'Visceral', 'Neuropathic', 'Referred'],
      'cough': ['Pneumonia', 'Bronchitis', 'TB', 'Asthma', 'COPD', 'Heart failure'],
      'sob': ['Pneumonia', 'Heart failure', 'Asthma/COPD', 'PE', 'Anxiety'],
      'headache': ['Tension', 'Migraine', 'Hypertensive', 'Secondary (space-occupying, bleed)'],
      'abdominal': ['Gastroenteritis', 'Appendicitis', 'Cholecystitis', 'Pancreatitis', 'Renal colic', 'Obstruction'],
      'polyuria': ['Diabetes mellitus', 'Diabetes insipidus', 'Hypercalcaemia'],
      'polydipsia': ['Diabetes mellitus', 'DI', 'Psychogenic polydipsia'],
      'weight loss': ['Malignancy', 'TB', 'Hyperthyroidism', 'Malabsorption', 'HIV'],
      'fatigue': ['Anaemia', 'Hypothyroidism', 'Depression', 'Chronic disease', 'Malignancy'],
      'blurred vision': ['Refractive error', 'Diabetic retinopathy', 'Hypertensive retinopathy', 'Cataract'],
      'foot ulcer': ['Diabetic foot', 'Peripheral vascular disease', 'Neuropathic ulcer'],
      'dizziness': ['Orthostatic hypotension', 'Arrhythmia', 'Vestibular', 'Anaemia'],
      'chest pain': ['ACS', 'Pericarditis', 'PE', 'Aortic dissection', 'MSK', 'GERD'],
      'visual changes': ['Hypertensive retinopathy', 'Papilloedema', 'Migraine aura', 'Stroke'],
      'epistaxis': ['Hypertension', 'Trauma', 'Coagulopathy', 'Local'],
      'bone pain': ['SCD crisis', 'Osteomyelitis', 'Malignancy', 'AVN'],
      'pallor': ['Anaemia', 'Acute blood loss', 'Haemolysis'],
      'jaundice': ['Haemolysis', 'Hepatitis', 'Obstruction', 'Gilbert'],
      'priapism': ['SCD', 'Leukaemia', 'Medication', 'Trauma'],
      'stroke symptoms': ['CVA', 'TIA', 'SCD stroke', 'Meningitis'],
      'acute chest syndrome': ['SCD ACS', 'Pneumonia', 'PE', 'Fat embolism'],
      'reducedMovements': ['Fetal compromise', 'Oligohydramnios', 'Placental insufficiency'],
      'vaginal bleeding': ['Placenta praevia', 'Abruption', 'Cervical', 'Show'],
      'fluid leak': ['PROM', 'PPROM', 'Urine', 'Discharge'],
      'contractions': ['Preterm labour', 'Term labour', 'Braxton Hicks'],
      'seizure': ['Febrile seizure', 'Epilepsy', 'Meningitis', 'Metabolic', 'Space-occupying'],
      'poor feeding': ['Sepsis', 'Heart failure', 'Cleft', 'Neurological'],
      'lethargy': ['Sepsis', 'Meningitis', 'Metabolic', 'Intracranial'],
      'rash': ['Viral exanthem', 'Drug reaction', 'Meningococcal', 'Kawasaki', 'Henoch-Schonlein'],
      'diarrhoea': ['Gastroenteritis', 'Food intolerance', 'IBD', 'Celiac', 'Antibiotic-associated'],
      'vomiting': ['Gastroenteritis', 'Obstruction', 'Raised ICP', 'Metabolic', 'Drug'],
      'fever': ['Infection', 'Sepsis', 'Malignancy', 'Autoimmune', 'Drug fever'],
      'cough': ['Pneumonia', 'Bronchitis', 'TB', 'Asthma', 'COPD', 'Heart failure'],
      'sob': ['Pneumonia', 'Heart failure', 'Asthma/COPD', 'PE', 'Anxiety'],
      'headache': ['Tension', 'Migraine', 'Hypertensive', 'Secondary'],
      'abdominal': ['Gastroenteritis', 'Appendicitis', 'Cholecystitis', 'Pancreatitis', 'Renal colic', 'Obstruction']
    };
    return map[trigger.toLowerCase()] || ['Clinical assessment needed'];
  },

  computeEducationTopics() {
    if (!this.currentContext) return [];
    return this.currentContext.intelligence.educationTopics || [];
  },

  computePlanTemplate(planType = 'standard') {
    if (!this.currentContext) return null;
    return this.currentContext.intelligence.planTemplates?.[planType] || null;
  },

  computeLongitudinalTrajectories() {
    if (!this.currentContext || !this.longitudinalData) return {};
    const ctx = this.currentContext;
    const trajectories = {};
    const labs = this.longitudinalData.labs || {};

    ctx.intelligence.trends?.forEach(key => {
      const data = labs[key] || [];
      if (data.length > 0) {
        trajectories[key] = data.map(d => ({ date: d.date, value: d.value, encounter: d.encounter }));
      }
    });

    return trajectories;
  },

  getFullIntelligence() {
    return {
      context: this.currentContext,
      snapshot: this.computeSnapshot(),
      priorities: this.computePriorities(),
      dueMonitoring: this.computeDueMonitoring(),
      differentials: this.computeDifferentials(),
      education: this.computeEducationTopics(),
      planTemplate: this.computePlanTemplate(),
      trajectories: this.computeLongitudinalTrajectories()
    };
  }
};

window.ContextIntelligence = ContextIntelligence;