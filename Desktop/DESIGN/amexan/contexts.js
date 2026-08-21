/* =================================================================
   AMEXAN — CLINICAL CONTEXT DEFINITIONS
   Each context defines the workspace intelligence for a clinic type
   ================================================================= */

const CLINIC_CONTEXTS = {
  'general-opd': {
    id: 'general-opd',
    name: 'General OPD',
    department: 'Internal Medicine',
    icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
    color: '#0284c7',
    bgColor: '#e0f2fe',
    sessionTypes: ['AM', 'PM'],
    intelligence: {
      snapshotKeys: ['chiefComplaint', 'vitals', 'recentEncounters', 'activeProblems', 'allergies', 'medications'],
      dueMonitoring: [],
      clinicalPriorities: [],
      differentialTriggers: ['fever', 'pain', 'cough', 'sob', 'headache', 'abdominal'],
      educationTopics: []
    },
    queueView: 'standard',
    quickActions: ['New encounter', 'Order labs', 'Refer', 'Prescribe']
  },

  'diabetes': {
    id: 'diabetes',
    name: 'Diabetes & Metabolic Clinic',
    department: 'Internal Medicine',
    icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z',
    color: '#059669',
    bgColor: '#ecfdf5',
    sessionTypes: ['Mon AM', 'Wed AM', 'Fri AM'],
    intelligence: {
      snapshotKeys: ['hba1c', 'fastingGlucose', 'bp', 'weight', 'egfr', 'urineACR', 'lipids', 'lastEyeExam', 'lastFootExam'],
      trends: ['hba1c', 'fastingGlucose', 'bp', 'weight', 'egfr'],
      dueMonitoring: [
        { key: 'hba1c', label: 'HbA1c', interval: '3 months', critical: true },
        { key: 'renal', label: 'Renal function (U&E, eGFR)', interval: '6 months' },
        { key: 'urineACR', label: 'Urine ACR', interval: '12 months', critical: true },
        { key: 'foot', label: 'Foot assessment', interval: '12 months' },
        { key: 'retinal', label: 'Retinal screening', interval: '12 months' },
        { key: 'lipids', label: 'Lipid profile', interval: '12 months' }
      ],
      clinicalPriorities: [
        { condition: 'hba1c > 8.0', label: 'HbA1c above target', severity: 'red' },
        { condition: 'bp > 140/90', label: 'BP above target', severity: 'amber' },
        { condition: 'egfr < 60', label: 'Renal impairment', severity: 'amber' },
        { condition: 'urineACR > 30', label: 'Albuminuria', severity: 'amber' },
        { condition: 'footExamOverdue', label: 'Foot assessment due', severity: 'amber' },
        { condition: 'retinalOverdue', label: 'Retinal screening due', severity: 'amber' }
      ],
      differentialTriggers: ['polyuria', 'polydipsia', 'weight loss', 'fatigue', 'blurred vision', 'foot ulcer'],
      educationTopics: [
        { id: 'diet', label: 'Diabetes diet & nutrition', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'hypo', label: 'Hypoglycemia recognition & management', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' },
        { id: 'meds', label: 'Medication adherence', icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z' },
        { id: 'foot', label: 'Foot care & daily inspection', icon: 'M3 21h18M5 21V5l6-3 8 5v14' },
        { id: 'exercise', label: 'Exercise & physical activity', icon: 'M3 12h4l2 6 4-14 2 8h6' }
      ],
      planTemplates: {
        'standard': {
          followUp: '4 weeks',
          requiredBeforeVisit: ['HbA1c', 'U&E', 'Urine ACR'],
          futureMonitoring: ['Retinal screening', 'Foot assessment', 'Lipid profile']
        },
        'intensive': {
          followUp: '2 weeks',
          requiredBeforeVisit: ['HbA1c', 'Fasting glucose', 'U&E', 'Ketones'],
          futureMonitoring: ['Retinal screening', 'Foot assessment', 'CGM review']
        }
      }
    },
    queueView: 'chronic',
    quickActions: ['Review glucose trends', 'Adjust insulin', 'Order HbA1c', 'Foot exam', 'Eye referral']
  },

  'hypertension': {
    id: 'hypertension',
    name: 'Hypertension Clinic',
    department: 'Internal Medicine',
    icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
    color: '#0891b2',
    bgColor: '#f0f9ff',
    sessionTypes: ['Tue AM', 'Thu AM'],
    intelligence: {
      snapshotKeys: ['bp', 'bpTrend', 'homeBP', 'egfr', 'electrolytes', 'lipids', 'ecg', 'fundoscopy'],
      trends: ['sbp', 'dbp', 'homeSbp', 'homeDbp'],
      dueMonitoring: [
        { key: 'bp', label: 'Blood pressure', interval: '1 month', critical: true },
        { key: 'renal', label: 'Renal function (U&E, eGFR)', interval: '6 months' },
        { key: 'lipids', label: 'Lipid profile', interval: '12 months' },
        { key: 'ecg', label: 'ECG', interval: '12 months' },
        { key: 'fundoscopy', label: 'Fundoscopy', interval: '24 months' }
      ],
      clinicalPriorities: [
        { condition: 'bp > 140/90', label: 'BP not at target', severity: 'red' },
        { condition: 'bp > 160/100', label: 'Stage 2 hypertension', severity: 'red' },
        { condition: 'egfr < 60', label: 'Renal impairment', severity: 'amber' },
        { condition: 'adherence < 80%', label: 'Medication adherence concern', severity: 'amber' },
        { condition: 'homeBP > 135/85', label: 'Home BP above target', severity: 'amber' }
      ],
      differentialTriggers: ['headache', 'dizziness', 'chest pain', 'sob', 'visual changes', 'epistaxis'],
      educationTopics: [
        { id: 'bp-monitoring', label: 'Home BP monitoring technique', icon: 'M12 8v5l3 2' },
        { id: 'salt', label: 'Salt reduction & DASH diet', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'meds', label: 'Medication adherence', icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z' },
        { id: 'warning', label: 'Warning symptoms (stroke, MI)', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' },
        { id: 'lifestyle', label: 'Exercise & weight management', icon: 'M3 12h4l2 6 4-14 2 8h6' }
      ],
      planTemplates: {
        'standard': {
          followUp: '4 weeks',
          requiredBeforeVisit: ['Home BP log', 'U&E', 'Lipids (annual)'],
          futureMonitoring: ['ECG', 'Fundoscopy', 'Renal function']
        }
      }
    },
    queueView: 'chronic',
    quickActions: ['Review BP trend', 'Adjust meds', 'Order U&E', 'ECG', 'Home BP review']
  },

  'scd': {
    id: 'scd',
    name: 'Sickle Cell Disease Clinic',
    department: 'Hematology',
    icon: 'M12 3a9 9 0 1 0 9 9M12 3v8l6 4',
    color: '#7c3aed',
    bgColor: '#f5f3ff',
    sessionTypes: ['Mon PM', 'Thu PM'],
    intelligence: {
      snapshotKeys: ['genotype', 'baselineHb', 'crisisFrequency', 'recentAdmissions', 'painEpisodes', 'transfusionHistory', 'hydroxyureaDose', 'renalFunction', 'liverFunction', 'vaccinationStatus', 'complications', 'cbcTrends', 'specialistReviews'],
      trends: ['hb', 'wbc', 'plt', 'retic', 'bilirubin', 'ldh'],
      dueMonitoring: [
        { key: 'cbc', label: 'FBC + reticulocyte count', interval: '3 months', critical: true },
        { key: 'renal', label: 'Renal function + urine protein', interval: '6 months' },
        { key: 'liver', label: 'Liver function', interval: '6 months' },
        { key: 'transcranial', label: 'Transcranial doppler (if <16y)', interval: '12 months' },
        { key: 'eye', label: 'Ophthalmology review', interval: '12 months' },
        { key: 'vaccines', label: 'Vaccination status (pneumococcal, meningococcal, Hib)', interval: 'review annually' }
      ],
      clinicalPriorities: [
        { condition: 'hb < 7', label: 'Severe anemia — consider transfusion', severity: 'red' },
        { condition: 'crisisFrequency > 3/year', label: 'Frequent crises — review hydroxyurea', severity: 'red' },
        { condition: 'hydroxyureaNotMaximized', label: 'Hydroxyurea dose not optimized', severity: 'amber' },
        { condition: 'renalImpairment', label: 'Renal impairment', severity: 'amber' },
        { condition: 'vaccinesIncomplete', label: 'Vaccinations incomplete', severity: 'amber' },
        { condition: 'ironOverload', label: 'Transfusional iron overload risk', severity: 'amber' }
      ],
      differentialTriggers: ['bone pain', 'fever', 'pallor', 'jaundice', 'priapism', 'stroke symptoms', 'acute chest syndrome'],
      educationTopics: [
        { id: 'crisis', label: 'Pain crisis recognition & early management', icon: 'M12 8v5l3 2' },
        { id: 'hydration', label: 'Hydration — 3-4L daily', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'fever', label: 'Fever precautions — seek care immediately', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' },
        { id: 'meds', label: 'Hydroxyurea adherence', icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z' },
        { id: 'urgent', label: 'When to seek urgent care', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' }
      ],
      planTemplates: {
        'standard': {
          followUp: '3 months',
          requiredBeforeVisit: ['FBC + retic', 'Renal function', 'Liver function'],
          futureMonitoring: ['TCD (if pediatric)', 'Eye exam', 'Vaccines', 'Iron studies if transfused']
        }
      }
    },
    queueView: 'chronic',
    quickActions: ['Review crisis history', 'Adjust hydroxyurea', 'Order FBC', 'Transfusion history', 'Pain plan']
  },

  'anc': {
    id: 'anc',
    name: 'Antenatal Clinic',
    department: 'Obstetrics & Gynaecology',
    icon: 'M12 5v14M5 12h14M19 15c2 0 3 1.5 3 3',
    color: '#db2777',
    bgColor: '#fdf2f8',
    sessionTypes: ['Mon AM', 'Wed AM', 'Fri AM'],
    intelligence: {
      snapshotKeys: ['gestationalAge', 'edd', 'gravida', 'parity', 'bp', 'weight', 'fundalHeight', 'fhr', 'presentation', 'hb', 'bloodGroup', 'hiv', 'syphilis', 'hepatitis', 'urineProtein', 'glucose', 'scanHistory', 'riskFactors'],
      trends: ['bp', 'weight', 'fundalHeight', 'hb'],
      dueMonitoring: [
        { key: 'bp', label: 'Blood pressure', interval: 'every visit', critical: true },
        { key: 'urineProtein', label: 'Urine protein', interval: 'every visit', critical: true },
        { key: 'fundalHeight', label: 'Fundal height / growth', interval: 'every visit' },
        { key: 'fhr', label: 'Fetal heart rate', interval: 'every visit', critical: true },
        { key: 'hb', label: 'Haemoglobin', interval: '28w, 36w' },
        { key: 'glucose', label: 'OGTT (24-28w)', interval: 'once' },
        { key: 'scan', label: 'Anatomy scan (18-22w)', interval: 'once' },
        { key: 'growthScan', label: 'Growth scan (32-36w if indicated)', interval: 'as needed' },
        { key: 'vaccines', label: 'Tetanus, Influenza, COVID-19', interval: 'per schedule' }
      ],
      clinicalPriorities: [
        { condition: 'bp >= 140/90', label: 'Hypertension in pregnancy', severity: 'red' },
        { condition: 'proteinuria', label: 'Proteinuria — pre-eclampsia screen', severity: 'red' },
        { condition: 'hb < 10', label: 'Anaemia in pregnancy', severity: 'amber' },
        { condition: 'fhr < 110 or > 160', label: 'FHR abnormality', severity: 'red' },
        { condition: 'reducedMovements', label: 'Reduced fetal movements', severity: 'red' },
        { condition: 'gestationalAge >= 37', label: 'Term — discuss birth plan', severity: 'amber' }
      ],
      differentialTriggers: ['headache', 'visual disturbance', 'epigastric pain', 'reduced movements', 'vaginal bleeding', 'fluid leak', 'contractions', 'fever'],
      educationTopics: [
        { id: 'danger', label: 'Danger signs in pregnancy', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' },
        { id: 'nutrition', label: 'Nutrition & supplements (iron, folate, calcium)', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'meds', label: 'Medications in pregnancy', icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z' },
        { id: 'birth', label: 'Birth planning & facility delivery', icon: 'M19 15c2 0 3 1.5 3 3' },
        { id: 'followup', label: 'Follow-up schedule & postnatal care', icon: 'M7 3v4M17 3v4M3 10h18' }
      ],
      planTemplates: {
        'standard': {
          followUp: '4 weeks (until 28w), 2 weeks (28-36w), weekly (36w+)',
          requiredBeforeVisit: ['Urine dipstick', 'BP', 'Weight', 'Fundal height', 'FHR'],
          futureMonitoring: ['OGTT (24-28w)', 'Anatomy scan', 'Growth scan', 'GBS screen (35-37w)']
        }
      }
    },
    queueView: 'maternal',
    quickActions: ['Record vitals', 'Order OGTT', 'Request scan', 'Review bloods', 'Birth plan']
  },

  'casualty': {
    id: 'casualty',
    name: 'Casualty / Emergency',
    department: 'Emergency Medicine',
    icon: 'M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Z M12 8v6M12 17h.01',
    color: '#dc2626',
    bgColor: '#fef2f2',
    sessionTypes: ['24/7'],
    intelligence: {
      snapshotKeys: ['acuity', 'presentingComplaint', 'vitals', 'gcs', 'trauma', 'investigationsPending', 'disposition'],
      trends: [],
      dueMonitoring: [],
      clinicalPriorities: [
        { condition: 'acuity === "resus"', label: 'Resuscitation / immediate', severity: 'red' },
        { condition: 'acuity === "high"', label: 'High acuity — urgent', severity: 'red' },
        { condition: 'acuity === "medium"', label: 'Medium acuity', severity: 'amber' },
        { condition: 'acuity === "low"', label: 'Low acuity / review', severity: 'green' },
        { condition: 'spo2 < 90', label: 'Hypoxia — oxygen immediately', severity: 'red' },
        { condition: 'gcs < 13', label: 'Altered consciousness', severity: 'red' },
        { condition: 'sbp < 90', label: 'Hypotension — shock', severity: 'red' },
        { condition: 'awaitingDisposition', label: 'Awaiting admission/discharge decision', severity: 'amber' }
      ],
      differentialTriggers: [],
      educationTopics: [],
      acuityLevels: {
        resus: { label: 'Resuscitation', color: '#dc2626', order: 1 },
        high: { label: 'High acuity', color: '#dc2626', order: 2 },
        medium: { label: 'Medium acuity', color: '#d97706', order: 3 },
        low: { label: 'Low acuity', color: '#059669', order: 4 },
        review: { label: 'Review / disposition', color: '#0284c7', order: 5 }
      }
    },
    queueView: 'acuity',
    quickActions: ['Resus bay', 'Fast track', 'Order stat labs', 'Imaging', 'Admit', 'Discharge', 'Refer']
  },

  'pediatrics': {
    id: 'pediatrics',
    name: 'Paediatrics Clinic',
    department: 'Paediatrics',
    icon: 'M3 20c0-3 3-5 6-5s6 2 6 5M16 4a3 3 0 0 1 0 6M19 15c2 0 3 1.5 3 3',
    color: '#0ea5e9',
    bgColor: '#f0f9ff',
    sessionTypes: ['Mon AM', 'Tue AM', 'Wed AM', 'Thu AM', 'Fri AM'],
    intelligence: {
      snapshotKeys: ['age', 'weight', 'height', 'immunization', 'growthPercentiles', 'developmentalMilestones', 'feedingHistory', 'allergies', 'chronicConditions'],
      trends: ['weight', 'height', 'headCircumference', 'bmi'],
      dueMonitoring: [
        { key: 'immunization', label: 'Immunization schedule', interval: 'per EPI schedule', critical: true },
        { key: 'growth', label: 'Growth monitoring', interval: 'every visit' },
        { key: 'development', label: 'Developmental screening', interval: '9m, 18m, 30m' }
      ],
      clinicalPriorities: [
        { condition: 'immunizationOverdue', label: 'Immunizations overdue', severity: 'amber' },
        { condition: 'weightFaldering', label: 'Faltering growth', severity: 'red' },
        { condition: 'developmentalDelay', label: 'Developmental concern', severity: 'amber' }
      ],
      differentialTriggers: ['fever', 'cough', 'diarrhoea', 'vomiting', 'rash', 'seizure', 'poor feeding', 'lethargy'],
      educationTopics: [
        { id: 'nutrition', label: 'Infant & young child feeding', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'immunization', label: 'Immunization schedule', icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z' },
        { id: 'danger', label: 'Danger signs in children', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' },
        { id: 'hygiene', label: 'Hygiene & sanitation', icon: 'M12 3 5 6v6c0 4 3 7 7 9' }
      ],
      planTemplates: {
        'standard': {
          followUp: 'per schedule',
          requiredBeforeVisit: [],
          futureMonitoring: ['Immunizations', 'Growth', 'Development']
        }
      }
    },
    queueView: 'standard',
    quickActions: ['Growth chart', 'Immunizations', 'Developmental screen', 'Prescribe', 'Refer']
  },

  'oncology': {
    id: 'oncology',
    name: 'Oncology Clinic',
    department: 'Oncology',
    icon: 'M12 3a9 9 0 1 0 9 9M12 3v8l6 4',
    color: '#7c3aed',
    bgColor: '#f5f3ff',
    sessionTypes: ['Tue AM', 'Fri AM'],
    intelligence: {
      snapshotKeys: ['diagnosis', 'stage', 'treatmentProtocol', 'cycleNumber', 'lastTreatment', 'performanceStatus', 'recentBloods', 'imagingSchedule', 'toxicityProfile', 'supportiveCare'],
      trends: ['hb', 'wbc', 'anc', 'plt', 'creatinine', 'lfts', 'tumourMarkers'],
      dueMonitoring: [
        { key: 'fbc', label: 'FBC before each cycle', interval: 'per protocol', critical: true },
        { key: 'renal', label: 'Renal function', interval: 'per protocol' },
        { key: 'lfts', label: 'Liver function', interval: 'per protocol' },
        { key: 'imaging', label: 'Restaging imaging', interval: 'per protocol' },
        { key: 'cardiac', label: 'Echo/MUGA (if anthracycline)', interval: 'cumulative dose' }
      ],
      clinicalPriorities: [
        { condition: 'anc < 1.0', label: 'Neutropenia — infection risk', severity: 'red' },
        { condition: 'plt < 50', label: 'Thrombocytopenia — bleeding risk', severity: 'red' },
        { condition: 'hb < 8', label: 'Anaemia — consider transfusion', severity: 'amber' },
        { condition: 'toxicityGrade >= 3', label: 'Grade 3+ toxicity — dose modification', severity: 'red' },
        { condition: 'performanceStatus > 2', label: 'Poor PS — review treatment intent', severity: 'amber' }
      ],
      differentialTriggers: ['fever', 'bleeding', 'new pain', 'neurological symptoms', 'sob', 'nausea/vomiting'],
      educationTopics: [
        { id: 'neutropenia', label: 'Neutropenic precautions', icon: 'M12 8v5l3 2' },
        { id: 'meds', label: 'Oral chemotherapy adherence', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'nutrition', label: 'Nutrition during treatment', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'support', label: 'Psychosocial support & palliative care', icon: 'M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-4 0-8 2-8 5v1h16v-1c0-3-4-5-8-5Z' }
      ],
      planTemplates: {
        'standard': {
          followUp: 'per protocol',
          requiredBeforeVisit: ['FBC', 'Renal', 'LFTs', 'Tumour markers (if applicable)'],
          futureMonitoring: ['Restaging imaging', 'Cardiac monitoring', 'Long-term survivorship']
        }
      }
    },
    queueView: 'chronic',
    quickActions: ['Review toxicity', 'Order pre-chemo bloods', 'Adjust dose', 'Supportive meds', 'Restaging']
  },

  'cardiology': {
    id: 'cardiology',
    name: 'Cardiology Clinic',
    department: 'Cardiology',
    icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
    color: '#dc2626',
    bgColor: '#fef2f2',
    sessionTypes: ['Mon AM', 'Wed AM'],
    intelligence: {
      snapshotKeys: ['diagnosis', 'ef', 'nyhaClass', 'bp', 'hr', 'rhythm', 'medications', 'deviceStatus', 'recentEcho', 'recentECG', 'biomarkers'],
      trends: ['bp', 'hr', 'weight', 'ef', 'ntprobnp'],
      dueMonitoring: [
        { key: 'echo', label: 'Echocardiogram', interval: '6-12 months' },
        { key: 'ecg', label: 'ECG', interval: '6 months' },
        { key: 'biomarkers', label: 'NT-proBNP', interval: '6 months' },
        { key: 'renal', label: 'Renal function', interval: '3-6 months' },
        { key: 'device', label: 'Device check (if pacemaker/ICD)', interval: '6-12 months' }
      ],
      clinicalPriorities: [
        { condition: 'nyhaClass >= 3', label: 'Advanced heart failure', severity: 'red' },
        { condition: 'ef < 35', label: 'Reduced EF — ICD/CRT indication', severity: 'amber' },
        { condition: 'weightGain > 2kg/week', label: 'Fluid overload', severity: 'red' },
        { condition: 'bp > 140/90', label: 'Uncontrolled BP', severity: 'amber' },
        { condition: 'medAdherence < 80%', label: 'Medication adherence', severity: 'amber' }
      ],
      differentialTriggers: ['chest pain', 'sob', 'orthopnea', 'PND', 'palpitations', 'syncope', 'edema', 'fatigue'],
      educationTopics: [
        { id: 'fluid', label: 'Fluid & salt restriction', icon: 'M12 3 5 6v6c0 4 3 7 7 9' },
        { id: 'weight', label: 'Daily weight monitoring', icon: 'M12 8v5l3 2' },
        { id: 'meds', label: 'Medication adherence (ACEi/ARB, BB, MRA, SGLT2i)', icon: 'M12 3 5 6v6c0 4 3 7 7 9 4-2 7-5 7-9V6Z' },
        { id: 'exercise', label: 'Cardiac rehabilitation', icon: 'M3 12h4l2 6 4-14 2 8h6' },
        { id: 'warning', label: 'When to seek urgent care', icon: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z' }
      ],
      planTemplates: {
        'standard': {
          followUp: '3 months',
          requiredBeforeVisit: ['Echo', 'ECG', 'Renal function', 'NT-proBNP'],
          futureMonitoring: ['Device check', 'Cardiac rehab', 'Advance care planning']
        }
      }
    },
    queueView: 'chronic',
    quickActions: ['Review echo', 'Adjust HF meds', 'Order BNP', 'Device check', 'Weight review']
  }
};

function getContext(id) {
  return CLINIC_CONTEXTS[id] || CLINIC_CONTEXTS['general-opd'];
}

function getAllContexts() {
  return Object.values(CLINIC_CONTEXTS);
}

function getContextsByDepartment(department) {
  return Object.values(CLINIC_CONTEXTS).filter(c => c.department === department);
}

window.CLINIC_CONTEXTS = CLINIC_CONTEXTS;
window.getContext = getContext;
window.getAllContexts = getAllContexts;
window.getContextsByDepartment = getContextsByDepartment;