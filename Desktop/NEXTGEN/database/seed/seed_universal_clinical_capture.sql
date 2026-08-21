-- =============================================================================
-- AMEXAN H5 / PHASE 1+
-- postgres/seed_universal_clinical_capture_intelligence.sql
--
-- UNIVERSAL CLINICAL CAPTURE + MEDICAL KNOWLEDGE FOUNDATION
-- =============================================================================
--
-- PURPOSE
-- -------
-- This seed establishes the clinical vocabulary required for the AMEXAN
-- Clinical CPU to reason from:
--
--   PATIENT
--      ↓
--   CONTEXT
--      ↓
--   PRESENTATION / SYMPTOM
--      ↓
--   CHARACTERISTICS
--      ↓
--   ASSOCIATED FEATURES
--      ↓
--   RISK FACTORS / EXPOSURES
--      ↓
--   PHENOTYPE
--      ↓
--   MECHANISM
--      ↓
--   DIFFERENTIAL DIAGNOSIS
--      ↓
--   EXAMINATION
--      ↓
--   INVESTIGATION
--      ↓
--   DIAGNOSIS
--      ↓
--   MANAGEMENT
--      ↓
--   FOLLOW-UP / OUTCOME
--
-- IMPORTANT DESIGN RULES
-- ----------------------
-- 1. Disease does NOT come first.
--    The CPU starts from the patient's presentation.
--
-- 2. The HPI records facts, not hidden clinician deductions.
--
-- 3. The CPU may reason over facts, but generated documentation must
--    distinguish:
--       reported
--       observed
--       measured
--       documented
--       inferred
--       suspected
--       confirmed
--
-- 4. Age, sex, pregnancy, setting, communication capability and other
--    contexts modify the capture pathway.
--
-- 5. A symptom can map to many conditions.
--    A condition can produce many symptoms.
--
-- 6. AMEXAN must remain longitudinal:
--       one patient → multiple encounters → multiple episodes →
--       multiple facts → evolving diagnoses → treatments → outcomes.
--
-- 7. This seed is REFERENCE DATA ONLY.
--    It does not contain patient-identifiable information.
--
-- 8. Clinical knowledge is represented as structured vocabulary.
--    It is not a replacement for local protocols, formularies,
--    clinician judgement, or jurisdiction-specific guidelines.
--
-- REFERENCE KNOWLEDGE DOMAINS
-- ---------------------------
-- Designed to accommodate knowledge derived from major clinical references
-- such as:
--   Davidson's Principles and Practice of Medicine
--   Kumar & Clark's Clinical Medicine
--   Hutchison's Clinical Methods
--   Oxford Handbook series
--   Nelson Textbook of Pediatrics
--   Bailey & Love's Short Practice of Surgery
--   Schwartz's Principles of Surgery
--   Sabiston Textbook of Surgery
--   Williams Obstetrics
--   standard O&G / neonatology / psychiatry / pharmacology / pathology /
--   radiology / microbiology / public-health frameworks
--
-- DO NOT COPY COPYRIGHTED TEXT.
-- Store concepts, structured clinical relationships and internally authored
-- rules rather than reproducing textbook chapters.
--
-- IDEMPOTENT
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. HISTORY SECTION REGISTRY
-- =============================================================================

INSERT INTO clinical.history_sections
(section_code, label, section_group, sequence_no)
VALUES
('biodata',               'Biodata',                         'IDENTIFICATION', 1),
('chief_complaint',       'Chief Complaint',                 'HISTORY', 2),
('hpi',                   'History of Present Illness',      'HISTORY', 3),
('past_medical_history',  'Past Medical History',             'PAST_HISTORY', 4),
('past_surgical_history', 'Past Surgical History',            'PAST_HISTORY', 5),
('drug_history',          'Drug History',                     'MEDICATIONS', 6),
('allergy_history',       'Allergy History',                  'ALLERGIES', 7),
('family_history',        'Family History',                   'FAMILY_HISTORY', 8),
('social_history',        'Social History',                   'SOCIAL_HISTORY', 9),
('occupational_history',  'Occupational History',             'EXPOSURE_HISTORY', 10),
('sexual_history',        'Sexual History',                   'HISTORY', 11),
('obstetric_history',     'Obstetric History',                'OBGYN', 12),
('gynaecological_history','Gynaecological History',            'OBGYN', 13),
('anc_profile',           'Antenatal Profile',                'OBGYN', 14),
('birth_history',         'Birth History',                     'NEONATAL', 15),
('growth_development',    'Growth and Development',            'DEVELOPMENTAL', 16),
('immunization',          'Immunization History',               'HISTORY', 17),
('nutrition',             'Nutrition History',                  'HISTORY', 18),
('psychiatric_history',   'Psychiatric History',                'HISTORY', 19),
('substance_history',     'Substance Use History',              'HISTORY', 20),
('collateral_history',    'Collateral History',                 'HISTORY', 21),
('review_of_systems',     'Review of Systems',                  'REVIEW_OF_SYSTEMS', 22),
('examination',           'Physical Examination',                'EXAMINATION', 23),
('vital_signs',            'Vital Signs',                        'EXAMINATION', 24),
('general_examination',    'General Examination',                 'EXAMINATION', 25),
('systemic_examination',   'Systemic Examination',                'EXAMINATION', 26),
('investigations',         'Investigations',                      'INVESTIGATION', 27),
('assessment',             'Clinical Assessment',                 'ASSESSMENT', 28),
('differential',           'Differential Diagnosis',               'DIAGNOSIS', 29),
('diagnosis',              'Diagnosis',                           'DIAGNOSIS', 30),
('management',             'Management',                          'MANAGEMENT', 31),
('procedure',              'Procedure',                           'MANAGEMENT', 32),
('disposition',            'Disposition',                         'MANAGEMENT', 33),
('follow_up',              'Follow-up',                           'FOLLOW_UP', 34),
('outcome',                'Outcome',                             'FOLLOW_UP', 35),
('summary',                'Clinical Summary',                    'DOCUMENTATION', 36)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 1. UNIVERSAL FACT DEFINITIONS
-- =============================================================================

INSERT INTO clinical.fact_definitions
(fact_code, label, data_type, section_code, unit_code)
VALUES

-- ---------------------------------------------------------------------------
-- BIODATA
-- ---------------------------------------------------------------------------

('SEX',                         'Sex',                         'coded',   'biodata', NULL),
('AGE_YEARS',                   'Age in years',                'numeric', 'biodata', 'years'),
('AGE_MONTHS',                  'Age in months',               'numeric', 'biodata', NULL),
('AGE_DAYS',                    'Age in days',                 'numeric', 'biodata', 'days'),
('GESTATIONAL_AGE',             'Gestational age',             'numeric', 'biodata', 'weeks'),
('WEIGHT',                      'Weight',                      'numeric', 'biodata', 'kg'),
('HEIGHT',                      'Height',                      'numeric', 'biodata', 'cm'),
('BMI',                         'Body mass index',              'numeric', 'biodata', 'kg/m2'),

-- ---------------------------------------------------------------------------
-- CHIEF COMPLAINT
-- ---------------------------------------------------------------------------

('PRESENTING_COMPLAINT',        'Presenting complaint',        'text',    'chief_complaint', NULL),
('COMPLAINT_COUNT',             'Number of presenting complaints','numeric','chief_complaint',NULL),
('PRIMARY_COMPLAINT',           'Primary presenting complaint','coded',   'chief_complaint', NULL),

-- ---------------------------------------------------------------------------
-- UNIVERSAL HPI
-- ---------------------------------------------------------------------------

('SYMPTOM_ONSET',               'Symptom onset',               'coded',   'hpi', NULL),
('SYMPTOM_DURATION',            'Symptom duration',            'numeric', 'hpi', 'days'),
('SYMPTOM_FREQUENCY',            'Symptom frequency',            'coded',   'hpi', NULL),
('SYMPTOM_PROGRESS',             'Symptom progression',           'coded',   'hpi', NULL),
('SYMPTOM_SEVERITY',             'Symptom severity',             'coded',   'hpi', NULL),
('SYMPTOM_CHARACTER',            'Symptom character',            'coded',   'hpi', NULL),
('SYMPTOM_SITE',                 'Symptom site',                 'coded',   'hpi', NULL),
('SYMPTOM_RADIATION',            'Symptom radiation',            'coded',   'hpi', NULL),
('SYMPTOM_AGGRAVATING_FACTOR',   'Aggravating factor',           'text',    'hpi', NULL),
('SYMPTOM_RELIEVING_FACTOR',     'Relieving factor',             'text',    'hpi', NULL),
('ASSOCIATED_SYMPTOM_PRESENT',   'Associated symptom present',   'boolean', 'hpi', NULL),
('FUNCTIONAL_IMPACT',             'Functional impact',             'coded',   'hpi', NULL),
('HEALTH_SEEKING',                'Health seeking before encounter','text', 'hpi', NULL),
('PREVIOUS_EPISODE',              'Previous similar episode',     'boolean', 'hpi', NULL),
('PREVIOUS_TREATMENT',            'Previous treatment',            'text',    'hpi', NULL),

-- ---------------------------------------------------------------------------
-- GENERAL HISTORY
-- ---------------------------------------------------------------------------

('PAST_MEDICAL_HISTORY_PRESENT', 'Previous medical condition', 'boolean', 'past_medical_history', NULL),
('PAST_SURGERY_PRESENT',         'Previous surgery',            'boolean', 'past_surgical_history', NULL),
('CURRENT_MEDICATION_PRESENT',  'Current medication',          'boolean', 'drug_history', NULL),
('ALLERGY_PRESENT',              'Allergy',                     'boolean', 'allergy_history', NULL),
('FAMILY_HISTORY_PRESENT',       'Relevant family history',     'boolean', 'family_history', NULL),
('SOCIAL_RISK_PRESENT',          'Relevant social risk',        'boolean', 'social_history', NULL),
('OCCUPATIONAL_EXPOSURE',        'Occupational exposure',       'text',    'occupational_history', NULL),
('SUBSTANCE_USE_PRESENT',        'Substance use',               'boolean', 'substance_history', NULL),

-- ---------------------------------------------------------------------------
-- FEMALE / OBGYN
-- ---------------------------------------------------------------------------

('LMP_DATE',                     'Last menstrual period',       'date',    'gynaecological_history', NULL),
('MENSTRUAL_CYCLE',              'Menstrual cycle pattern',     'coded',   'gynaecological_history', NULL),
('MENSTRUAL_FLOW',               'Menstrual flow',              'coded',   'gynaecological_history', NULL),
('MENSTRUAL_PAIN',               'Menstrual pain',              'boolean', 'gynaecological_history', NULL),
('PREGNANCY_STATUS',             'Pregnancy status',             'coded',   'anc_profile', NULL),
('GRAVIDITY',                    'Gravidity',                    'numeric', 'obstetric_history', NULL),
('PARITY',                       'Parity',                       'numeric', 'obstetric_history', NULL),
('GESTATIONAL_AGE_CURRENT',      'Current gestational age',      'numeric', 'anc_profile', 'weeks'),
('EDD',                          'Estimated date of delivery',  'date',    'anc_profile', NULL),
('ANC_ATTENDANCE',               'Antenatal attendance',          'coded',   'anc_profile', NULL),
('POSTPARTUM_STATUS',            'Postpartum status',             'boolean', 'obstetric_history', NULL),
('LACTATION_STATUS',             'Lactation status',              'coded',   'obstetric_history', NULL),

-- ---------------------------------------------------------------------------
-- NEONATAL / PAEDIATRIC
-- ---------------------------------------------------------------------------

('BIRTH_MODE',                   'Mode of birth',                'coded',   'birth_history', NULL),
('BIRTH_WEIGHT',                 'Birth weight',                 'numeric', 'birth_history', 'kg'),
('PREMATURITY',                  'Prematurity',                  'boolean', 'birth_history', NULL),
('NICU_ADMISSION',               'Neonatal intensive care admission','boolean','birth_history',NULL),
('NEONATAL_JAUNDICE',            'Neonatal jaundice',             'boolean', 'birth_history', NULL),
('FEEDING_STATUS',               'Feeding status',               'coded',   'nutrition', NULL),
('BREASTFEEDING_STATUS',         'Breastfeeding status',          'coded',   'nutrition', NULL),
('IMMUNIZATION_STATUS',          'Immunization status',           'coded',   'immunization', NULL),
('DEVELOPMENTAL_MILESTONE',      'Developmental milestone',       'coded',   'growth_development', NULL),
('GROWTH_STATUS',                'Growth status',                 'coded',   'growth_development', NULL),

-- ---------------------------------------------------------------------------
-- RESPIRATORY
-- ---------------------------------------------------------------------------

('COUGH_PRESENT',                'Cough present',                'boolean', 'hpi', NULL),
('COUGH_DURATION',               'Cough duration',                'numeric', 'hpi', 'days'),
('COUGH_CHARACTER',              'Cough character',               'coded',   'hpi', NULL),
('COUGH_PRODUCTIVITY',           'Cough productivity',             'coded',   'hpi', NULL),
('SPUTUM_PRESENT',               'Sputum present',                'boolean', 'hpi', NULL),
('SPUTUM_COLOUR',                'Sputum colour',                 'coded',   'hpi', NULL),
('HAEMOPTYSIS_PRESENT',          'Haemoptysis',                   'boolean', 'hpi', NULL),
('DYSPNOEA_PRESENT',             'Dyspnoea',                      'boolean', 'hpi', NULL),
('WHEEZE_PRESENT',               'Wheeze',                        'boolean', 'hpi', NULL),
('STRIDOR_PRESENT',              'Stridor',                       'boolean', 'hpi', NULL),
('CHEST_PAIN_PRESENT',           'Chest pain',                    'boolean', 'hpi', NULL),
('PLEURITIC_CHEST_PAIN',         'Pleuritic chest pain',           'boolean', 'hpi', NULL),
('ORTHOPNOEA',                   'Orthopnoea',                    'boolean', 'hpi', NULL),
('PND',                          'Paroxysmal nocturnal dyspnoea',  'boolean', 'hpi', NULL),
('CYANOS',                       'Cyanosis',                      'boolean', 'hpi', NULL),
('GRUNTING_PRESENT',             'Grunting',                      'boolean', 'hpi', NULL),
('CHEST_INDRAWING',              'Chest indrawing',                'boolean', 'hpi', NULL),

-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR
-- ---------------------------------------------------------------------------

('PALPITATIONS',                 'Palpitations',                  'boolean', 'hpi', NULL),
('SYNCOPE',                      'Syncope',                       'boolean', 'hpi', NULL),
('PRESYNCOPE',                   'Presyncope',                    'boolean', 'hpi', NULL),
('PERIPHERAL_OEDEMA',            'Peripheral oedema',              'boolean', 'hpi', NULL),
('EXERTIONAL_DYSPNOEA',          'Exertional dyspnoea',            'boolean', 'hpi', NULL),

-- ---------------------------------------------------------------------------
-- GASTROINTESTINAL
-- ---------------------------------------------------------------------------

('ABDOMINAL_PAIN_PRESENT',       'Abdominal pain',                 'boolean', 'hpi', NULL),
('NAUSEA_PRESENT',               'Nausea',                         'boolean', 'hpi', NULL),
('VOMITING_PRESENT',             'Vomiting',                       'boolean', 'hpi', NULL),
('DIARRHOEA_PRESENT',            'Diarrhoea',                      'boolean', 'hpi', NULL),
('CONSTIPATION_PRESENT',         'Constipation',                   'boolean', 'hpi', NULL),
('GI_BLEEDING',                  'Gastrointestinal bleeding',      'boolean', 'hpi', NULL),
('JAUNDICE_PRESENT',             'Jaundice',                       'boolean', 'hpi', NULL),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL
-- ---------------------------------------------------------------------------

('HEADACHE_PRESENT',             'Headache',                      'boolean', 'hpi', NULL),
('SEIZURE_PRESENT',              'Seizure',                       'boolean', 'hpi', NULL),
('WEAKNESS_PRESENT',             'Weakness',                      'boolean', 'hpi', NULL),
('NUMBNESS_PRESENT',             'Numbness',                      'boolean', 'hpi', NULL),
('SPEECH_CHANGE',                'Speech change',                 'boolean', 'hpi', NULL),
('VISION_CHANGE',                'Visual change',                 'boolean', 'hpi', NULL),
('ALTERED_CONSCIOUSNESS',        'Altered consciousness',          'boolean', 'hpi', NULL),

-- ---------------------------------------------------------------------------
-- GENITOURINARY
-- ---------------------------------------------------------------------------

('DYSURIA',                      'Dysuria',                       'boolean', 'hpi', NULL),
('URINARY_FREQUENCY',            'Urinary frequency',              'boolean', 'hpi', NULL),
('URGENCY',                      'Urinary urgency',                'boolean', 'hpi', NULL),
('HAEMATURIA',                   'Haematuria',                    'boolean', 'hpi', NULL),
('URINE_OUTPUT_CHANGE',          'Change in urine output',         'coded',   'hpi', NULL),

-- ---------------------------------------------------------------------------
-- GENERAL / SYSTEMIC
-- ---------------------------------------------------------------------------

('FEVER_PRESENT',                'Fever',                         'boolean', 'hpi', NULL),
('CHILLS',                       'Chills',                        'boolean', 'hpi', NULL),
('RIGORS',                       'Rigors',                        'boolean', 'hpi', NULL),
('NIGHT_SWEATS',                 'Night sweats',                  'boolean', 'hpi', NULL),
('WEIGHT_LOSS',                  'Weight loss',                   'boolean', 'hpi', NULL),
('WEIGHT_GAIN',                  'Weight gain',                   'boolean', 'hpi', NULL),
('FATIGUE_PRESENT',              'Fatigue',                       'boolean', 'hpi', NULL),

-- ---------------------------------------------------------------------------
-- PSYCHIATRY
-- ---------------------------------------------------------------------------

('PSYCHIATRIC_PRESENTATION',     'Psychiatric presentation',      'text',    'psychiatric_history', NULL),
('MOOD_CHANGE',                  'Mood change',                   'boolean', 'psychiatric_history', NULL),
('ANXIETY_PRESENT',              'Anxiety',                       'boolean', 'psychiatric_history', NULL),
('PSYCHOSIS_PRESENT',            'Psychotic symptoms',             'boolean', 'psychiatric_history', NULL),
('SELF_HARM_RISK',               'Self-harm risk',                 'coded',   'psychiatric_history', NULL),

-- ---------------------------------------------------------------------------
-- EXAMINATION
-- ---------------------------------------------------------------------------

('TEMPERATURE',                  'Temperature',                   'numeric', 'vital_signs', 'degC'),
('HEART_RATE',                   'Heart rate',                    'numeric', 'vital_signs', 'bpm'),
('RESPIRATORY_RATE',             'Respiratory rate',              'numeric', 'vital_signs', 'breaths/min'),
('BLOOD_PRESSURE_SYSTOLIC',      'Systolic blood pressure',       'numeric', 'vital_signs', 'mmHg'),
('BLOOD_PRESSURE_DIASTOLIC',     'Diastolic blood pressure',      'numeric', 'vital_signs', 'mmHg'),
('OXYGEN_SATURATION',            'Oxygen saturation',             'numeric', 'vital_signs', '%'),
('GCS',                          'Glasgow Coma Scale',             'numeric', 'vital_signs', NULL),
('CAPILLARY_REFILL',             'Capillary refill time',          'numeric', 'vital_signs', 'seconds'),

-- ---------------------------------------------------------------------------
-- INVESTIGATION / ASSESSMENT
-- ---------------------------------------------------------------------------

('LAB_RESULT_PRESENT',           'Laboratory result present',     'boolean', 'investigations', NULL),
('IMAGING_RESULT_PRESENT',        'Imaging result present',         'boolean', 'investigations', NULL),
('ASSESSMENT_TEXT',              'Clinical assessment',             'text',    'assessment', NULL),
('DIFFERENTIAL_PRESENT',         'Differential diagnosis present', 'boolean', 'differential', NULL),
('DIAGNOSIS_TEXT',               'Diagnosis',                       'text',    'diagnosis', NULL),
('MANAGEMENT_PLAN',              'Management plan',                 'text',    'management', NULL),
('FOLLOW_UP_PLAN',               'Follow-up plan',                  'text',    'follow_up', NULL)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. UNIVERSAL SYMPTOM CATALOGUE
-- =============================================================================

INSERT INTO clinical.symptoms
(symptom_code, name)
VALUES
('COUGH','Cough'),
('FEVER','Fever'),
('DYSPNOEA','Dyspnoea'),
('WHEEZE','Wheeze'),
('STRIDOR','Stridor'),
('CHEST_PAIN','Chest pain'),
('HAEMOPTYSIS','Haemoptysis'),
('FATIGUE','Fatigue'),
('WEIGHT_LOSS','Weight loss'),
('NIGHT_SWEATS','Night sweats'),
('CHILLS','Chills'),
('RIGORS','Rigors'),

('HEADACHE','Headache'),
('DIZZINESS','Dizziness'),
('SYNCOPE','Syncope'),
('SEIZURE','Seizure'),
('WEAKNESS','Weakness'),
('NUMBNESS','Numbness'),
('VISION_CHANGE','Visual disturbance'),
('SPEECH_CHANGE','Speech disturbance'),
('ALTERED_CONSCIOUSNESS','Altered consciousness'),

('PALPITATIONS','Palpitations'),
('PERIPHERAL_OEDEMA','Peripheral oedema'),
('ORTHOPNOEA','Orthopnoea'),
('PND','Paroxysmal nocturnal dyspnoea'),

('ABDOMINAL_PAIN','Abdominal pain'),
('NAUSEA','Nausea'),
('VOMITING','Vomiting'),
('DIARRHOEA','Diarrhoea'),
('CONSTIPATION','Constipation'),
('JAUNDICE','Jaundice'),
('GI_BLEEDING','Gastrointestinal bleeding'),

('DYSURIA','Dysuria'),
('URINARY_FREQUENCY','Urinary frequency'),
('URGENCY','Urinary urgency'),
('HAEMATURIA','Haematuria'),
('URINE_OUTPUT_CHANGE','Change in urine output'),

('JOINT_PAIN','Joint pain'),
('JOINT_SWELLING','Joint swelling'),
('BACK_PAIN','Back pain'),
('MUSCLE_PAIN','Muscle pain'),

('RASH','Rash'),
('ITCHING','Pruritus'),
('SKIN_ULCER','Skin ulcer'),

('BLEEDING','Abnormal bleeding'),
('VAGINAL_BLEEDING','Vaginal bleeding'),
('VAGINAL_DISCHARGE','Vaginal discharge'),
('PELVIC_PAIN','Pelvic pain'),
('DYSMENORRHOEA','Dysmenorrhoea'),

('BREAST_LUMP','Breast lump'),
('BREAST_PAIN','Breast pain'),
('NIPPLE_DISCHARGE','Nipple discharge'),

('LOW_MOOD','Low mood'),
('ANXIETY','Anxiety'),
('HALLUCINATION','Hallucination'),
('DELUSION','Delusion'),
('SLEEP_DISTURBANCE','Sleep disturbance'),

('POOR_FEEDING','Poor feeding'),
('FAILURE_TO_THRIVE','Failure to thrive'),
('DEVELOPMENTAL_DELAY','Developmental delay'),
('IRRITABILITY','Irritability'),
('LETHARGY','Lethargy'),

('PAIN','Pain'),
('SWELLING','Swelling'),
('LUMP','Lump'),
('DISCHARGE','Discharge'),
('LOSS_OF_FUNCTION','Loss of function')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. UNIVERSAL CLINICAL CONDITIONS
-- =============================================================================

INSERT INTO clinical.conditions
(condition_code, name, department_code)
VALUES

-- ---------------------------------------------------------------------------
-- RESPIRATORY MEDICINE
-- ---------------------------------------------------------------------------

('PNEUMONIA','Pneumonia','medical'),
('COMMUNITY_ACQUIRED_PNEUMONIA','Community-acquired pneumonia','medical'),
('HOSPITAL_ACQUIRED_PNEUMONIA','Hospital-acquired pneumonia','medical'),
('ASPIRATION_PNEUMONIA','Aspiration pneumonia','medical'),
('ACUTE_BRONCHITIS','Acute bronchitis','medical'),
('ASTHMA','Asthma','medical'),
('COPD','Chronic obstructive pulmonary disease','medical'),
('PULMONARY_TB','Pulmonary tuberculosis','medical'),
('PLEURAL_EFFUSION','Pleural effusion','medical'),
('PNEUMOTHORAX','Pneumothorax','medical'),
('PULMONARY_EDEMA','Pulmonary oedema','medical'),
('ARDS','Acute respiratory distress syndrome','medical'),
('PULMONARY_EMBOLISM','Pulmonary embolism','medical'),
('INTERSTITIAL_LUNG_DISEASE','Interstitial lung disease','medical'),
('LUNG_CANCER','Lung cancer','medical'),
('BRONCHIECTASIS','Bronchiectasis','medical'),
('OBSTRUCTIVE_SLEEP_APNOEA','Obstructive sleep apnoea','medical'),

-- ---------------------------------------------------------------------------
-- PAEDIATRICS
-- ---------------------------------------------------------------------------

('BRONCHIOLITIS','Bronchiolitis','paediatrics'),
('CROUP','Croup','paediatrics'),
('EPIGLOTTITIS','Epiglottitis','paediatrics'),
('FOREIGN_BODY_ASPIRATION','Foreign body aspiration','paediatrics'),
('NEONATAL_RESPIRATORY_DISTRESS','Neonatal respiratory distress','paediatrics'),
('NEONATAL_SEPSIS','Neonatal sepsis','paediatrics'),
('PAEDIATRIC_PNEUMONIA','Paediatric pneumonia','paediatrics'),
('PAEDIATRIC_ASTHMA','Paediatric asthma','paediatrics'),

-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR
-- ---------------------------------------------------------------------------

('HEART_FAILURE','Heart failure','medical'),
('ACUTE_CORONARY_SYNDROME','Acute coronary syndrome','medical'),
('MYOCARDIAL_INFARCTION','Myocardial infarction','medical'),
('ANGINA','Angina','medical'),
('ATRIAL_FIBRILLATION','Atrial fibrillation','medical'),
('HYPERTENSION','Hypertension','medical'),
('HYPERTENSIVE_EMERGENCY','Hypertensive emergency','medical'),
('INFECTIVE_ENDOCARDITIS','Infective endocarditis','medical'),
('RHEUMATIC_HEART_DISEASE','Rheumatic heart disease','medical'),
('PERICARDITIS','Pericarditis','medical'),

-- ---------------------------------------------------------------------------
-- GASTROENTEROLOGY
-- ---------------------------------------------------------------------------

('GASTROENTERITIS','Gastroenteritis','medical'),
('PEPTIC_ULCER_DISEASE','Peptic ulcer disease','medical'),
('GASTRO_OESOPHAGEAL_REFLUX','Gastro-oesophageal reflux disease','medical'),
('UPPER_GI_BLEED','Upper gastrointestinal bleeding','medical'),
('LOWER_GI_BLEED','Lower gastrointestinal bleeding','medical'),
('HEPATITIS','Hepatitis','medical'),
('CIRRHOSIS','Cirrhosis','medical'),
('ACUTE_LIVER_FAILURE','Acute liver failure','medical'),
('CHRONIC_LIVER_DISEASE','Chronic liver disease','medical'),
('ACUTE_PANCREATITIS','Acute pancreatitis','medical'),
('INFLAMMATORY_BOWEL_DISEASE','Inflammatory bowel disease','medical'),

-- ---------------------------------------------------------------------------
-- RENAL / ENDOCRINE
-- ---------------------------------------------------------------------------

('ACUTE_KIDNEY_INJURY','Acute kidney injury','medical'),
('CHRONIC_KIDNEY_DISEASE','Chronic kidney disease','medical'),
('NEPHROTIC_SYNDROME','Nephrotic syndrome','medical'),
('NEPHRITIC_SYNDROME','Nephritic syndrome','medical'),
('DIABETES_MELLITUS','Diabetes mellitus','medical'),
('DIABETIC_KETOACIDOSIS','Diabetic ketoacidosis','medical'),
('HYPEROSMOLAR_HYPERGLYCAEMIC_STATE','Hyperosmolar hyperglycaemic state','medical'),
('THYROID_DISEASE','Thyroid disease','medical'),
('HYPERTHYROIDISM','Hyperthyroidism','medical'),
('HYPOTHYROIDISM','Hypothyroidism','medical'),
('ADRENAL_INSUFFICIENCY','Adrenal insufficiency','medical'),

-- ---------------------------------------------------------------------------
-- NEUROLOGY
-- ---------------------------------------------------------------------------

('STROKE','Stroke','medical'),
('TIA','Transient ischaemic attack','medical'),
('EPILEPSY','Epilepsy','medical'),
('MENINGITIS','Meningitis','medical'),
('ENCEPHALITIS','Encephalitis','medical'),
('DELIRIUM','Delirium','medical'),
('PERIPHERAL_NEUROPATHY','Peripheral neuropathy','medical'),
('PARKINSONISM','Parkinsonism','medical'),

-- ---------------------------------------------------------------------------
-- INFECTIOUS DISEASE
-- ---------------------------------------------------------------------------

('SEPSIS','Sepsis','medical'),
('SEPTIC_SHOCK','Septic shock','medical'),
('MALARIA','Malaria','medical'),
('HIV_INFECTION','HIV infection','medical'),
('TYPHOID_FEVER','Typhoid fever','medical'),
('URINARY_TRACT_INFECTION','Urinary tract infection','medical'),
('PYELONEPHRITIS','Pyelonephritis','medical'),

-- ---------------------------------------------------------------------------
-- HAEMATOLOGY
-- ---------------------------------------------------------------------------

('ANAEMIA','Anaemia','medical'),
('IRON_DEFICIENCY_ANAEMIA','Iron deficiency anaemia','medical'),
('SICKLE_CELL_DISEASE','Sickle cell disease','medical'),
('THROMBOCYTOPENIA','Thrombocytopenia','medical'),
('LEUKAEMIA','Leukaemia','medical'),
('LYMPHOMA','Lymphoma','medical'),

-- ---------------------------------------------------------------------------
-- SURGERY
-- ---------------------------------------------------------------------------

('ACUTE_APPENDICITIS','Acute appendicitis','surgery'),
('ACUTE_CHOLECYSTITIS','Acute cholecystitis','surgery'),
('ACUTE_CHOLANGITIS','Acute cholangitis','surgery'),
('BOWEL_OBSTRUCTION','Bowel obstruction','surgery'),
('PERFORATED_VISCUS','Perforated viscus','surgery'),
('ACUTE_MESENTERIC_ISCHAEMIA','Acute mesenteric ischaemia','surgery'),
('INGUINAL_HERNIA','Inguinal hernia','surgery'),
('INCISIONAL_HERNIA','Incisional hernia','surgery'),
('BREAST_CANCER','Breast cancer','surgery'),
('BENIGN_BREAST_DISEASE','Benign breast disease','surgery'),
('FRACTURE','Fracture','surgery'),
('DISLOCATION','Dislocation','surgery'),
('BURNS','Burns','surgery'),

-- ---------------------------------------------------------------------------
-- OBGYN
-- ---------------------------------------------------------------------------

('NORMAL_PREGNANCY','Normal pregnancy','obgyn'),
('ECTOPIC_PREGNANCY','Ectopic pregnancy','obgyn'),
('MISCARRIAGE','Miscarriage','obgyn'),
('PLACENTA_PREVIA','Placenta previa','obgyn'),
('PLACENTAL_ABRUPTION','Placental abruption','obgyn'),
('PRE_ECLAMPSIA','Pre-eclampsia','obgyn'),
('ECLAMPSIA','Eclampsia','obgyn'),
('GESTATIONAL_DIABETES','Gestational diabetes mellitus','obgyn'),
('POSTPARTUM_HAEMORRHAGE','Postpartum haemorrhage','obgyn'),
('PUERPERAL_SEPSIS','Puerperal sepsis','obgyn'),
('PRETERM_LABOUR','Preterm labour','obgyn'),
('PROLONGED_LABOUR','Prolonged labour','obgyn'),
('UTERINE_RUPTURE','Uterine rupture','obgyn'),
('POLYHYDRAMNIOS','Polyhydramnios','obgyn'),
('OLIGOHYDRAMNIOS','Oligohydramnios','obgyn'),
('FIBROIDS','Uterine fibroids','obgyn'),
('ENDOMETRIOSIS','Endometriosis','obgyn'),
('PELVIC_INFLAMMATORY_DISEASE','Pelvic inflammatory disease','obgyn'),
('CERVICAL_CANCER','Cervical cancer','obgyn'),
('OVARIAN_CANCER','Ovarian cancer','obgyn'),

-- ---------------------------------------------------------------------------
-- PSYCHIATRY
-- ---------------------------------------------------------------------------

('MAJOR_DEPRESSIVE_DISORDER','Major depressive disorder','psychiatry'),
('BIPOLAR_DISORDER','Bipolar disorder','psychiatry'),
('SCHIZOPHRENIA','Schizophrenia','psychiatry'),
('GENERALIZED_ANXIETY_DISORDER','Generalized anxiety disorder','psychiatry'),
('PANIC_DISORDER','Panic disorder','psychiatry'),
('SUBSTANCE_USE_DISORDER','Substance use disorder','psychiatry'),

-- ---------------------------------------------------------------------------
-- DERMATOLOGY / RHEUMATOLOGY
-- ---------------------------------------------------------------------------

('CELLULITIS','Cellulitis','medical'),
('ERYSEPELAS','Erysipelas','medical'),
('ATOPIC_DERMATITIS','Atopic dermatitis','medical'),
('PSORIASIS','Psoriasis','medical'),
('SYSTEMIC_LUPUS_ERYTHEMATOSUS','Systemic lupus erythematosus','medical'),
('RHEUMATOID_ARTHRITIS','Rheumatoid arthritis','medical'),
('OSTEOARTHRITIS','Osteoarthritis','medical'),
('GOUT','Gout','medical')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. CLINICAL PHENOTYPES
-- =============================================================================

INSERT INTO clinical.phenotypes
(phenotype_code, name)
VALUES

-- Respiratory
('ACUTE_INFECTIVE_RESPIRATORY','Acute infective respiratory phenotype'),
('ACUTE_HYPOXAEMIC_RESPIRATORY','Acute hypoxaemic respiratory phenotype'),
('OBSTRUCTIVE_AIRWAY','Obstructive airway phenotype'),
('CHRONIC_INFECTIVE_RESPIRATORY','Chronic infective respiratory phenotype'),
('CARDIOPULMONARY_CONGESTIVE','Cardiopulmonary congestive phenotype'),
('THROMBOEMBOLIC_RESPIRATORY','Thromboembolic respiratory phenotype'),
('PLEURAL_AIR_FLUID_PHENOTYPE','Pleural air/fluid phenotype'),
('PAEDIATRIC_LOWER_RESPIRATORY','Paediatric lower respiratory phenotype'),
('UPPER_AIRWAY_INFLAMMATORY','Upper airway inflammatory phenotype'),
('FOREIGN_BODY_AIRWAY','Foreign body airway phenotype'),

-- Cardiovascular
('ACUTE_CORONARY','Acute coronary phenotype'),
('CONGESTIVE_CARDIAC','Congestive cardiac phenotype'),
('ARRHYTHMIC','Arrhythmic phenotype'),
('HYPERTENSIVE','Hypertensive phenotype'),
('INFECTIVE_CARDIAC','Infective cardiac phenotype'),

-- Neurology
('FOCAL_NEUROLOGICAL_DEFICIT','Focal neurological deficit phenotype'),
('ALTERED_CONSCIOUSNESS','Altered consciousness phenotype'),
('MENINGEAL_INFLAMMATORY','Meningeal inflammatory phenotype'),
('SEIZURE_PHENOTYPE','Seizure phenotype'),

-- GI
('ACUTE_ABDOMINAL','Acute abdominal phenotype'),
('OBSTRUCTIVE_GI','Gastrointestinal obstructive phenotype'),
('GI_BLEEDING','Gastrointestinal bleeding phenotype'),
('HEPATOCELLULAR','Hepatocellular phenotype'),
('CHOLESTATIC','Cholestatic phenotype'),

-- Renal
('ACUTE_KIDNEY_INJURY','Acute kidney injury phenotype'),
('NEPHROTIC','Nephrotic phenotype'),
('NEPHRITIC','Nephritic phenotype'),

-- Infection
('SYSTEMIC_INFLAMMATORY','Systemic inflammatory phenotype'),
('SEPTIC','Septic phenotype'),
('TROPICAL_FEVER','Tropical febrile illness phenotype'),

-- Haematology
('ANAEMIC','Anaemic phenotype'),
('BLEEDING_DISORDER','Bleeding phenotype'),
('THROMBOTIC','Thrombotic phenotype'),

-- OBGYN
('FIRST_TRIMESTER_BLEEDING','First trimester bleeding phenotype'),
('ANTEPARTUM_HAEMORRHAGE','Antepartum haemorrhage phenotype'),
('HYPERTENSIVE_PREGNANCY','Hypertensive pregnancy phenotype'),
('LABOUR_DYSFUNCTION','Labour dysfunction phenotype'),
('POSTPARTUM_BLEEDING','Postpartum bleeding phenotype'),
('PUERPERAL_INFECTION','Puerperal infection phenotype'),

-- Surgery
('ACUTE_SURGICAL_ABDOMEN','Acute surgical abdomen phenotype'),
('TRAUMA','Trauma phenotype'),
('BREAST_LUMP','Breast lump phenotype'),
('LIMB_TRAUMA','Limb trauma phenotype'),

-- Psychiatry
('DEPRESSIVE','Depressive phenotype'),
('MANIC','Manic phenotype'),
('PSYCHOTIC','Psychotic phenotype'),
('ANXIETY','Anxiety phenotype'),

-- Paediatrics
('PAEDIATRIC_FEVER','Paediatric fever phenotype'),
('PAEDIATRIC_DEHYDRATION','Paediatric dehydration phenotype'),
('PAEDIATRIC_MALNUTRITION','Paediatric malnutrition phenotype'),
('FAILURE_TO_THRIVE','Failure-to-thrive phenotype'),
('DEVELOPMENTAL_DELAY','Developmental delay phenotype')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. PATHOPHYSIOLOGICAL MECHANISMS
-- =============================================================================

INSERT INTO clinical.mechanisms
(mechanism_code, name)
VALUES

('AIRWAY_INFLAMMATION','Airway inflammation'),
('AIRWAY_HYPERRESPONSIVENESS','Airway hyperresponsiveness'),
('AIRWAY_OBSTRUCTION','Airway obstruction'),
('ALVEOLAR_INFECTION','Alveolar infection'),
('ALVEOLAR_COLLAPSE','Alveolar collapse'),
('ALVEOLAR_FLOODING','Alveolar flooding'),
('IMPAIRED_GAS_EXCHANGE','Impaired gas exchange'),
('VENTILATION_PERFUSION_MISMATCH','Ventilation-perfusion mismatch'),
('PULMONARY_VASCULAR_OCCLUSION','Pulmonary vascular occlusion'),
('PLEURAL_INFLAMMATION','Pleural inflammation'),
('PLEURAL_FLUID_ACCUMULATION','Pleural fluid accumulation'),
('PLEURAL_AIR_ACCUMULATION','Pleural air accumulation'),
('UPPER_AIRWAY_INFLAMMATION','Upper airway inflammation'),
('FOREIGN_BODY_OBSTRUCTION','Foreign body airway obstruction'),

('CARDIAC_PUMP_FAILURE','Cardiac pump failure'),
('MYOCARDIAL_ISCHAEMIA','Myocardial ischaemia'),
('VALVULAR_DYSFUNCTION','Valvular dysfunction'),
('ELECTRICAL_INSTABILITY','Cardiac electrical instability'),
('SYSTEMIC_VASCULAR_RESISTANCE','Increased systemic vascular resistance'),

('SYSTEMIC_INFLAMMATION','Systemic inflammation'),
('MICROBIAL_INVASION','Microbial invasion'),
('BACTERAEMIA','Bacteraemia'),
('SEPSIS_PATHOPHYSIOLOGY','Sepsis-associated organ dysfunction'),

('TISSUE_HYPOPERFUSION','Tissue hypoperfusion'),
('CELLULAR_HYPOXIA','Cellular hypoxia'),
('ANAEROBIC_METABOLISM','Anaerobic metabolism'),

('GASTROINTESTINAL_OBSTRUCTION','Gastrointestinal obstruction'),
('GASTROINTESTINAL_INFLAMMATION','Gastrointestinal inflammation'),
('PERITONEAL_INFLAMMATION','Peritoneal inflammation'),
('VISCERAL_ISCHAEMIA','Visceral ischaemia'),
('HEPATOCELLULAR_INJURY','Hepatocellular injury'),
('BILIARY_OBSTRUCTION','Biliary obstruction'),

('GLOMERULAR_INJURY','Glomerular injury'),
('REDUCED_RENAL_PERFUSION','Reduced renal perfusion'),
('TUBULAR_INJURY','Tubular injury'),

('NEUROVASCULAR_OCCLUSION','Neurovascular occlusion'),
('NEUROVASCULAR_BLEEDING','Intracranial bleeding'),
('MENINGEAL_INFLAMMATION','Meningeal inflammation'),
('CORTICAL_ELECTRICAL_DISCHARGE','Abnormal cortical electrical discharge'),

('ENDOCRINE_HORMONE_DEFICIENCY','Endocrine hormone deficiency'),
('ENDOCRINE_HORMONE_EXCESS','Endocrine hormone excess'),
('INSULIN_DEFICIENCY','Insulin deficiency'),
('INSULIN_RESISTANCE','Insulin resistance'),

('THROMBOGENESIS','Thrombogenesis'),
('VENOUS_STASIS','Venous stasis'),
('ENDOTHELIAL_INJURY','Endothelial injury'),

('TISSUE_INJURY','Tissue injury'),
('HAEMORRHAGE','Haemorrhage'),
('OBSTRUCTION','Mechanical obstruction'),
('INFECTION','Local infection'),
('MALIGNANT_PROLIFERATION','Malignant cellular proliferation'),
('BENIGN_PROLIFERATION','Benign cellular proliferation'),

('AUTOIMMUNE_INFLAMMATION','Autoimmune inflammation'),
('IMMUNE_COMPLEX_DEPOSITION','Immune complex deposition'),
('HYPERSENSITIVITY','Hypersensitivity response'),

('NEUROTRANSMITTER_DYSREGULATION','Neurotransmitter dysregulation'),
('MOOD_REGULATION_DYSFUNCTION','Mood regulation dysfunction'),
('PSYCHOTIC_PROCESS','Psychotic process')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. SYMPTOM CHARACTER VOCABULARY
-- =============================================================================

-- These are deliberately stored as vocabulary concepts rather than prose.
-- The CPU can combine them without hard-coding English sentences.

INSERT INTO clinical.symptoms
(symptom_code, name)
VALUES

-- Onset / time
('ONSET_SUDDEN','Sudden onset'),
('ONSET_GRADUAL','Gradual onset'),
('ONSET_ACUTE','Acute onset'),
('ONSET_SUBACUTE','Subacute onset'),
('ONSET_CHRONIC','Chronic onset'),

-- Course
('COURSE_PROGRESSIVE','Progressive course'),
('COURSE_STATIC','Static course'),
('COURSE_INTERMITTENT','Intermittent course'),
('COURSE_RELAPSING','Relapsing course'),
('COURSE_RECURRENT','Recurrent course'),

-- Pain
('PAIN_SHARP','Sharp pain'),
('PAIN_DULL','Dull pain'),
('PAIN_BURNING','Burning pain'),
('PAIN_CRAMPING','Cramping pain'),
('PAIN_COLICKY','Colicky pain'),
('PAIN_STABBING','Stabbing pain'),
('PAIN_PRESSURE','Pressure-like pain'),
('PAIN_TEARING','Tearing pain'),

-- Respiratory
('COUGH_DRY','Dry cough'),
('COUGH_PRODUCTIVE','Productive cough'),
('SPUTUM_CLEAR','Clear sputum'),
('SPUTUM_PURULENT','Purulent sputum'),
('SPUTUM_BLOOD_STAINED','Blood-stained sputum'),
('SPUTUM_FROTHY','Frothy sputum'),

-- Fever
('FEVER_INTERMITTENT','Intermittent fever'),
('FEVER_CONTINUOUS','Continuous fever'),
('FEVER_REMITS','Remitting fever'),

-- Severity
('SEVERITY_MILD','Mild severity'),
('SEVERITY_MODERATE','Moderate severity'),
('SEVERITY_SEVERE','Severe severity'),

-- Functional impact
('IMPACT_SLEEP','Impairs sleep'),
('IMPACT_FEEDING','Impairs feeding'),
('IMPACT_MOBILITY','Impairs mobility'),
('IMPACT_WORK','Impairs work'),
('IMPACT_DAILY_ACTIVITY','Impairs activities of daily living')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. UNIVERSAL CLINICAL CONTEXT VOCABULARY
-- =============================================================================

INSERT INTO clinical.conditions
(condition_code, name, department_code)
VALUES
('NORMAL_STATE','No disease state identified','general'),
('ACUTE_PRESENTATION','Acute clinical presentation','general'),
('CHRONIC_PRESENTATION','Chronic clinical presentation','general'),
('RECURRENT_PRESENTATION','Recurrent clinical presentation','general'),
('POST_PROCEDURE_STATE','Post-procedure state','general'),
('POST_OPERATIVE_STATE','Post-operative state','surgery'),
('PREGNANCY_STATE','Pregnancy state','obgyn'),
('POSTPARTUM_STATE','Postpartum state','obgyn'),
('NEONATAL_STATE','Neonatal state','paediatrics'),
('PAEDIATRIC_STATE','Paediatric state','paediatrics'),
('GERIATRIC_STATE','Older adult state','medical'),
('IMMUNOCOMPROMISED_STATE','Immunocompromised state','medical'),
('CRITICALLY_ILL_STATE','Critical illness state','medical')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. CORE CLINICAL EXAMINATION VOCABULARY
-- =============================================================================

INSERT INTO clinical.symptoms
(symptom_code, name)
VALUES

-- General
('PALLOR','Pallor'),
('ICTERUS','Icterus'),
('CYANOS','Cyanosis'),
('CLUBBING','Clubbing'),
('LYMPHADENOPATHY','Lymphadenopathy'),
('OEDEMA','Oedema'),
('DEHYDRATION','Dehydration'),

-- Respiratory examination
('REDUCED_AIR_ENTRY','Reduced air entry'),
('BRONCHIAL_BREATH_SOUNDS','Bronchial breath sounds'),
('VESICULAR_BREATH_SOUNDS','Vesicular breath sounds'),
('CRACKLES','Crackles'),
('WHEEZE_ON_EXAMINATION','Wheeze on examination'),
('STRIDOR_ON_EXAMINATION','Stridor on examination'),
('PLEURAL_RUB','Pleural rub'),
('DULLNESS_TO_PERCUSSION','Dullness to percussion'),
('HYPERRESONANCE','Hyperresonance'),

-- Cardiovascular
('MURMUR','Cardiac murmur'),
('GALLOP','Gallop rhythm'),
('RAISED_JVP','Raised JVP'),
('DISPLACED_APEX','Displaced apex beat'),
('WEAK_PULSE','Weak pulse'),

-- Abdomen
('ABDOMINAL_TENDERNESS','Abdominal tenderness'),
('GUARDING','Guarding'),
('RIGIDITY','Rigidity'),
('REBOUND_TENDERNESS','Rebound tenderness'),
('ORGANOMEGALY','Organomegaly'),
('ASCITES','Ascites'),
('PALPABLE_MASS','Palpable abdominal mass'),

-- Neurological
('ALTERED_MENTAL_STATUS','Altered mental status'),
('FOCAL_NEUROLOGICAL_SIGN','Focal neurological sign'),
('MENINGISM','Meningism'),
('ABNORMAL_REFLEXES','Abnormal reflexes'),

-- Musculoskeletal
('JOINT_TENDERNESS','Joint tenderness'),
('JOINT_EFFUSION','Joint effusion'),
('LIMITED_RANGE_OF_MOTION','Limited range of motion'),
('DEFORMITY','Deformity'),

-- Breast
('BREAST_MASS','Breast mass'),
('NIPPLE_RETRACTION','Nipple retraction'),
('SKIN_DIMPLING','Skin dimpling'),
('AXILLARY_NODES','Axillary lymphadenopathy')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. CORE CLINICAL STATES / RED-FLAG VOCABULARY
-- =============================================================================

INSERT INTO clinical.phenotypes
(phenotype_code, name)
VALUES

('LIFE_THREATENING','Potentially life-threatening presentation'),
('AIRWAY_COMPROMISE','Potential airway compromise'),
('BREATHING_COMPROMISE','Potential breathing failure'),
('CIRCULATORY_COMPROMISE','Potential circulatory compromise'),
('NEUROLOGICAL_COMPROMISE','Potential neurological compromise'),
('SEVERE_SEPSIS_PHENOTYPE','Severe systemic infection phenotype'),
('SEVERE_BLEEDING_PHENOTYPE','Severe bleeding phenotype'),
('ACUTE_ORGAN_DYSFUNCTION','Acute organ dysfunction phenotype'),
('HIGH_RISK_PREGNANCY','High-risk pregnancy phenotype'),
('PAEDIATRIC_EMERGENCY','Paediatric emergency phenotype'),
('NEONATAL_EMERGENCY','Neonatal emergency phenotype'),
('SURGICAL_EMERGENCY','Surgical emergency phenotype'),
('PSYCHIATRIC_EMERGENCY','Psychiatric emergency phenotype')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. CORE MEDICAL PRESENTATION FAMILIES
-- =============================================================================

INSERT INTO clinical.symptoms
(symptom_code, name)
VALUES

('ACUTE_FEVER_PRESENTATION','Acute febrile presentation'),
('CHRONIC_FEVER_PRESENTATION','Chronic febrile presentation'),
('ACUTE_CHEST_PAIN_PRESENTATION','Acute chest pain presentation'),
('CHRONIC_CHEST_PAIN_PRESENTATION','Chronic chest pain presentation'),
('ACUTE_DYSPNOEA_PRESENTATION','Acute dyspnoea presentation'),
('CHRONIC_DYSPNOEA_PRESENTATION','Chronic dyspnoea presentation'),
('ACUTE_ABDOMINAL_PAIN_PRESENTATION','Acute abdominal pain presentation'),
('CHRONIC_ABDOMINAL_PAIN_PRESENTATION','Chronic abdominal pain presentation'),
('ACUTE_HEADACHE_PRESENTATION','Acute headache presentation'),
('CHRONIC_HEADACHE_PRESENTATION','Chronic headache presentation'),
('ACUTE_CONFUSION_PRESENTATION','Acute confusion presentation'),
('SYNCOPE_PRESENTATION','Syncope presentation'),
('OEDEMA_PRESENTATION','Oedema presentation'),
('WEIGHT_LOSS_PRESENTATION','Weight loss presentation'),
('BLEEDING_PRESENTATION','Bleeding presentation'),
('LUMP_PRESENTATION','Lump presentation'),
('JOINT_PAIN_PRESENTATION','Joint pain presentation'),
('URINARY_SYMPTOM_PRESENTATION','Urinary symptom presentation'),
('VAGINAL_BLEEDING_PRESENTATION','Vaginal bleeding presentation'),
('PREGNANCY_COMPLICATION_PRESENTATION','Pregnancy complication presentation')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. UNIVERSAL HISTORY CAPTURE PRINCIPLES AS SYSTEM VOCABULARY
-- =============================================================================

INSERT INTO clinical.fact_definitions
(fact_code, label, data_type, section_code, unit_code)
VALUES

('SOURCE_PATIENT','History source is patient','boolean','biodata',NULL),
('SOURCE_CAREGIVER','History source is caregiver','boolean','collateral_history',NULL),
('SOURCE_RELATIVE','History source is relative','boolean','collateral_history',NULL),
('SOURCE_RECORD','Information sourced from prior record','boolean','collateral_history',NULL),
('SOURCE_EMERGENCY_PROVIDER','Information sourced from emergency provider','boolean','collateral_history',NULL),

('HISTORY_RELIABILITY','Reliability of history','coded','collateral_history',NULL),
('LANGUAGE_USED','Language used for history','coded','biodata',NULL),
('INTERPRETER_REQUIRED','Interpreter required','boolean','biodata',NULL),
('COGNITIVE_LIMITATION','Cognitive limitation affecting history','boolean','collateral_history',NULL),
('ALTERED_CONSCIOUSNESS_HISTORY_LIMIT','History limited by altered consciousness','boolean','collateral_history',NULL),

('CLINICAL_CERTAINTY','Clinical certainty level','coded','assessment',NULL),
('EVIDENCE_SOURCE','Evidence source','coded','assessment',NULL),
('ASSESSMENT_CONFIDENCE','Assessment confidence','coded','assessment',NULL)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 12. LONGITUDINAL CLINICAL FACT STATES
-- =============================================================================

INSERT INTO clinical.fact_status
(code, label, description)
VALUES
('entered',    'Entered',    'Fact has been entered but not independently confirmed'),
('active',     'Active',     'Fact is currently active'),
('corrected',  'Corrected',  'Fact was corrected'),
('superseded', 'Superseded', 'Fact was replaced by a newer fact'),
('retracted',  'Retracted',  'Fact was withdrawn'),
('historical', 'Historical', 'Fact remains clinically relevant but is historical'),
('resolved',   'Resolved',   'Fact/event has resolved'),
('unknown',    'Unknown',    'Status cannot currently be established')
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. DIAGNOSIS STATES
-- =============================================================================

INSERT INTO clinical.diagnosis_status
(code, label, description)
VALUES
('suspected',       'Suspected',       'Diagnosis suspected from available evidence'),
('working',         'Working',         'Current working diagnosis'),
('confirmed',       'Confirmed',       'Diagnosis supported by adequate evidence'),
('final',           'Final',           'Final diagnosis for the encounter/episode'),
('ruled_out',       'Ruled out',       'Diagnosis excluded based on available evidence'),
('entered_in_error','Entered in error','Diagnosis recorded in error'),
('differential',    'Differential',    'Condition retained in differential diagnosis'),
('historical',      'Historical',      'Previously established diagnosis'),
('recurrent',       'Recurrent',       'Previously established condition has recurred')
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 14. CLINICAL ORDER VOCABULARY
-- =============================================================================

INSERT INTO clinical.order_type
(code, label, description)
VALUES
('laboratory','Laboratory','Laboratory investigation'),
('imaging','Imaging','Diagnostic imaging'),
('medication','Medication','Medication order'),
('procedure','Procedure','Procedure order'),
('nursing','Nursing','Nursing order'),
('consultation','Consultation','Clinical consultation'),
('diet','Diet','Dietary order'),
('monitoring','Monitoring','Clinical monitoring order'),
('referral','Referral','Referral to another service'),
('other','Other','Other clinical order')
  ON CONFLICT DO NOTHING;


INSERT INTO clinical.order_status
(code, label, description)
VALUES
('draft','Draft','Order being prepared'),
('pending','Pending','Order submitted and awaiting processing'),
('active','Active','Order currently active'),
('on_hold','On hold','Order temporarily suspended'),
('completed','Completed','Order completed'),
('cancelled','Cancelled','Order cancelled'),
('resulted','Resulted','Result available'),
('discontinued','Discontinued','Order discontinued')
  ON CONFLICT DO NOTHING;


INSERT INTO clinical.order_priority
(code, label, sort_order)
VALUES
('routine','Routine',10),
('urgent','Urgent',20),
('asap','ASAP',30),
('stat','STAT',40),
('emergency','Emergency',50)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 15. CARE TEAM VOCABULARY
-- =============================================================================

INSERT INTO clinical.care_team_role
(code, label, description)
VALUES
('attending','Attending clinician','Clinician responsible for care'),
('consultant','Consultant','Specialist consultant'),
('specialist','Specialist','Specialist clinician'),
('registrar','Registrar','Senior postgraduate clinician'),
('medical_officer','Medical officer','Medical officer'),
('clinical_officer','Clinical officer','Clinical officer'),
('intern','Intern','Intern clinician'),
('nurse_in_charge','Nurse in charge','Nurse responsible for nursing care'),
('nurse','Nurse','Nursing professional'),
('midwife','Midwife','Midwifery professional'),
('pharmacist','Pharmacist','Pharmacy professional'),
('laboratory_scientist','Laboratory scientist','Laboratory professional'),
('radiographer','Radiographer','Radiography professional'),
('physiotherapist','Physiotherapist','Physiotherapy professional'),
('nutritionist','Nutritionist','Nutrition professional'),
('social_worker','Social worker','Social work professional'),
('psychologist','Psychologist','Psychology professional')
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 16. CONSENT VOCABULARY
-- =============================================================================

INSERT INTO clinical.consent_type
(code, label, description)
VALUES
('assessment','Assessment','Consent associated with clinical assessment where required'),
('treatment','Treatment','Consent for treatment'),
('procedure','Procedure','Consent for procedure'),
('surgery','Surgery','Consent for surgery'),
('anaesthesia','Anaesthesia','Consent for anaesthesia'),
('blood_transfusion','Blood transfusion','Consent for transfusion'),
('imaging','Imaging','Consent for imaging where required'),
('research','Research','Consent for research participation'),
('data_use','Data use','Consent for specified secondary data use'),
('telemedicine','Telemedicine','Consent for telemedicine where required')
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 17. UNIVERSAL UNITS
-- =============================================================================

INSERT INTO terminology.unit
(code, label, dimension, symbol, si_unit_code)
VALUES
('years','years','time','yr',NULL),
('months','months','time','mo',NULL),
('days','days','time','d',NULL),
('hours','hours','time','h',NULL),
('minutes','minutes','time','min',NULL),
('seconds','seconds','time','s',NULL),

('%','percent','ratio','%',NULL),
('mmHg','millimetres of mercury','pressure','mmHg',NULL),
('bpm','beats per minute','rate','bpm',NULL),
('breaths/min','breaths per minute','rate','/min',NULL),
('degC','degrees Celsius','temperature','degC',NULL),
('degF','degrees Fahrenheit','temperature','degF','degC'),

('kg','kilogram','mass','kg',NULL),
('g','gram','mass','g',NULL),
('mg','milligram','mass','mg',NULL),
('mcg','microgram','mass','mcg',NULL),

('cm','centimetre','length','cm',NULL),
('m','metre','length','m','cm'),

('mg/dL','milligrams per decilitre','mass concentration','mg/dL',NULL),
('g/dL','grams per decilitre','mass concentration','g/dL',NULL),
('mmol/L','millimoles per litre','amount concentration','mmol/L',NULL),
('mEq/L','milliequivalents per litre','amount concentration','mEq/L',NULL),

('L/min','litres per minute','flow','L/min',NULL),
('mL/min','millilitres per minute','flow','mL/min',NULL),

('cmH2O','centimetres water','pressure','cmH2O',NULL)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 18. UNIT CONVERSIONS
-- =============================================================================

INSERT INTO terminology.unit_conversion
(from_unit_code, to_unit_code, factor, offset_value)
VALUES
('degC','degF',1.8,32),
('degF','degC',0.5555555556,-17.77777778),
('m','cm',100,0),
('cm','m',0.01,0),
('kg','g',1000,0),
('g','mg',1000,0),
('mg','mcg',1000,0)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 19. CORE TERMINOLOGY CONCEPTS
-- =============================================================================

INSERT INTO terminology.concept
(id, display_name, definition)
VALUES

('00000000-0000-0000-0000-00000000a001',
 'Cough',
 'A symptom involving forceful expiration of air through the respiratory tract.'),

('00000000-0000-0000-0000-00000000a002',
 'Fever',
 'A regulated elevation of body temperature associated with an increased thermoregulatory set point.'),

('00000000-0000-0000-0000-00000000a003',
 'Dyspnoea',
 'Subjective experience of difficult or uncomfortable breathing.'),

('00000000-0000-0000-0000-00000000a004',
 'Tuberculosis',
 'Infectious disease caused by organisms of the Mycobacterium tuberculosis complex.'),

('00000000-0000-0000-0000-00000000a005',
 'Chest pain',
 'Pain or discomfort perceived in the chest region.'),

('00000000-0000-0000-0000-00000000a006',
 'Abdominal pain',
 'Pain perceived within the abdominal region.'),

('00000000-0000-0000-0000-00000000a007',
 'Syncope',
 'Transient loss of consciousness and postural tone caused by transient global cerebral hypoperfusion with spontaneous recovery.'),

('00000000-0000-0000-0000-00000000a008',
 'Seizure',
 'A transient occurrence of signs or symptoms due to abnormal excessive or synchronous neuronal activity in the brain.'),

('00000000-0000-0000-0000-00000000a009',
 'Sepsis',
 'Life-threatening organ dysfunction caused by a dysregulated host response to infection.'),

('00000000-0000-0000-0000-00000000a010',
 'Shock',
 'A state of circulatory or cellular dysfunction resulting in inadequate tissue perfusion and/or oxygen utilisation.'),

('00000000-0000-0000-0000-00000000a011',
 'Anaemia',
 'A reduction in haemoglobin concentration below the appropriate reference threshold for the relevant population.'),

('00000000-0000-0000-0000-00000000a012',
 'Jaundice',
 'Yellow discoloration of tissues resulting from increased bilirubin accumulation.'),

('00000000-0000-0000-0000-00000000a013',
 'Oedema',
 'Abnormal accumulation of fluid within the interstitial space.'),

('00000000-0000-0000-0000-00000000a014',
 'Hypoxaemia',
 'Abnormally low oxygen level in arterial blood.'),

('00000000-0000-0000-0000-00000000a015',
 'Hypotension',
 'Blood pressure below the clinically appropriate threshold for the patient and context.'),

('00000000-0000-0000-0000-00000000a016',
 'Hypertension',
 'Persistently elevated arterial blood pressure according to the applicable diagnostic threshold and measurement context.')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 20. MULTILINGUAL TERMINOLOGY
-- =============================================================================

INSERT INTO terminology.concept_synonym
(concept_id, synonym, language_code, is_preferred)
VALUES

('00000000-0000-0000-0000-00000000a001','Cough','en',true),
('00000000-0000-0000-0000-00000000a001','Kikohozi','sw',true),

('00000000-0000-0000-0000-00000000a002','Fever','en',true),
('00000000-0000-0000-0000-00000000a002','Homa','sw',true),

('00000000-0000-0000-0000-00000000a003','Dyspnoea','en',true),
('00000000-0000-0000-0000-00000000a003','Shortness of breath','en',false),
('00000000-0000-0000-0000-00000000a003','Upungufu wa pumzi','sw',true),

('00000000-0000-0000-0000-00000000a004','Tuberculosis','en',true),
('00000000-0000-0000-0000-00000000a004','TB','en',false),
('00000000-0000-0000-0000-00000000a004','Kifua kikuu','sw',true),

('00000000-0000-0000-0000-00000000a005','Chest pain','en',true),
('00000000-0000-0000-0000-00000000a005','Maumivu ya kifua','sw',true),

('00000000-0000-0000-0000-00000000a006','Abdominal pain','en',true),
('00000000-0000-0000-0000-00000000a006','Maumivu ya tumbo','sw',true)

  ON CONFLICT DO NOTHING;


INSERT INTO terminology.concept_translation
(concept_id, language_code, translation, is_preferred)
VALUES
('00000000-0000-0000-0000-00000000a001','sw','Kikohozi',true),
('00000000-0000-0000-0000-00000000a002','sw','Homa',true),
('00000000-0000-0000-0000-00000000a003','sw','Upungufu wa pumzi',true),
('00000000-0000-0000-0000-00000000a004','sw','Kifua kikuu',true),
('00000000-0000-0000-0000-00000000a005','sw','Maumivu ya kifua',true),
('00000000-0000-0000-0000-00000000a006','sw','Maumivu ya tumbo',true)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 21. STANDARD CODE SYSTEM REGISTRY
-- =============================================================================

INSERT INTO terminology.code_system
(id, name, oid, canonical_uri, version)
VALUES
(
 '00000000-0000-0000-0000-000000000101',
 'SNOMED CT',
 '2.16.840.1.113883.6.96',
 'http://snomed.info/sct',
 '2025-01'
),
(
 '00000000-0000-0000-0000-000000000102',
 'ICD-10',
 '2.16.840.1.113883.6.3',
 'http://hl7.org/fhir/sid/icd-10',
 '2019'
),
(
 '00000000-0000-0000-0000-000000000103',
 'LOINC',
 '2.16.840.1.113883.6.1',
 'http://loinc.org',
 '2.77'
),
(
 '00000000-0000-0000-0000-000000000104',
 'Local AMEXAN',
 NULL,
 NULL,
 '1.0'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 22. TERMINOLOGY CODE MAP
-- =============================================================================

INSERT INTO terminology.code
(id, code_system_id, code, display)
VALUES
(
 '00000000-0000-0000-0000-00000000b001',
 '00000000-0000-0000-0000-000000000101',
 '49727002',
 'Cough'
),
(
 '00000000-0000-0000-0000-00000000b002',
 '00000000-0000-0000-0000-000000000101',
 '386661006',
 'Fever'
),
(
 '00000000-0000-0000-0000-00000000b003',
 '00000000-0000-0000-0000-000000000102',
 'R05',
 'Cough'
),
(
 '00000000-0000-0000-0000-00000000b004',
 '00000000-0000-0000-0000-000000000102',
 'A15',
 'Respiratory tuberculosis'
)
  ON CONFLICT DO NOTHING;


INSERT INTO terminology.concept_code
(concept_id, code_id, relationship)
VALUES
(
 '00000000-0000-0000-0000-00000000a001',
 '00000000-0000-0000-0000-00000000b001',
 'equivalent'
),
(
 '00000000-0000-0000-0000-00000000a001',
 '00000000-0000-0000-0000-00000000b003',
 'equivalent'
),
(
 '00000000-0000-0000-0000-00000000a002',
 '00000000-0000-0000-0000-00000000b002',
 'equivalent'
),
(
 '00000000-0000-0000-0000-00000000a004',
 '00000000-0000-0000-0000-00000000b004',
 'equivalent'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 23. STANDARD CLINICAL VALUE SETS
-- =============================================================================

INSERT INTO terminology.value_set
(id, key, name, description)
VALUES
(
 '00000000-0000-0000-0000-00000000c001',
 'vital_sign_parameters',
 'Vital Sign Parameters',
 'Standard parameters used for physiological observations.'
),
(
 '00000000-0000-0000-0000-00000000c002',
 'clinical_certainty',
 'Clinical Certainty',
 'Levels of certainty used when representing clinical assessment.'
),
(
 '00000000-0000-0000-0000-00000000c003',
 'history_source',
 'History Source',
 'Sources from which clinical history may be obtained.'
),
(
 '00000000-0000-0000-0000-00000000c004',
 'symptom_course',
 'Symptom Course',
 'Standard symptom temporal-course vocabulary.'
),
(
 '00000000-0000-0000-0000-00000000c005',
 'symptom_severity',
 'Symptom Severity',
 'Standard symptom severity vocabulary.'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 24. VERIFICATION
-- =============================================================================

SELECT
    'history_sections' AS dataset,
    COUNT(*) AS records
FROM clinical.history_sections

UNION ALL

SELECT
    'fact_definitions',
    COUNT(*)
FROM clinical.fact_definitions

UNION ALL

SELECT
    'symptoms',
    COUNT(*)
FROM clinical.symptoms

UNION ALL

SELECT
    'conditions',
    COUNT(*)
FROM clinical.conditions

UNION ALL

SELECT
    'phenotypes',
    COUNT(*)
FROM clinical.phenotypes

UNION ALL

SELECT
    'mechanisms',
    COUNT(*)
FROM clinical.mechanisms

UNION ALL

SELECT
    'fact_status',
    COUNT(*)
FROM clinical.fact_status

UNION ALL

SELECT
    'diagnosis_status',
    COUNT(*)
FROM clinical.diagnosis_status

UNION ALL

SELECT
    'order_type',
    COUNT(*)
FROM clinical.order_type

UNION ALL

SELECT
    'order_status',
    COUNT(*)
FROM clinical.order_status

UNION ALL

SELECT
    'care_team_role',
    COUNT(*)
FROM clinical.care_team_role

UNION ALL

SELECT
    'consent_type',
    COUNT(*)
FROM clinical.consent_type

UNION ALL

SELECT
    'units',
    COUNT(*)
FROM terminology.unit

UNION ALL

SELECT
    'concepts',
    COUNT(*)
FROM terminology.concept

UNION ALL

SELECT
    'code_systems',
    COUNT(*)
FROM terminology.code_system;


COMMIT;


-- =============================================================================
-- END
-- =============================================================================