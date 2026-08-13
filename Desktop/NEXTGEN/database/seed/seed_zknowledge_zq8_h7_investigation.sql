-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H7 seed zq8: universal investigation-selection engine
-- =============================================================================
-- Seeds the H7 investigation knowledge base, GROUNDED IN HUTCHISON CLAIMS ONLY:
--   HCH12-0004  cough thresholds (acute <3 wks, chronic >8 wks) → CXR + spirometry
--               as BASELINE investigations for chronic cough; haemoptysis → at
--               least a baseline CXR (H7 §44 grounding)
--   HCH12-0007  haemoptysis is a RED FLAG → prompt, careful evaluation (CXR at least)
--   HCH12-0016  respiratory monitoring: pulse oximetry / SpO2 normal ≥95 %,
--               RR ~14-16 breaths/min
--   HCH12-0018  auscultation INSIGHT → consolidation (bronchial breath sounds
--               / crackles) points to CXR
--   HCH12-0019  tracheal deviation → pleural effusion / pneumothorax → imaging
--   HCH2-0004   complete-examination order: cardiovascular/neck/abdomen first-pass
--   HCH2-0006   Box 2.4 provisional management plan: (2) investigations to do
--               IMMEDIATELY → CBC, electrolytes/blood cultures as the first-pass
--               workup; (4) investigations that may be needed LATER
--
-- H7 §2/§11 architectural law, encoded as DATA:
--   * An investigation_concept is a REUSABLE definition — never disease-owned,
--     never "the pneumonia test" (H7 §7).
--   * Selection/priority/safety/dependency = investigation_rule rows, not code.
--   * base_priority is H7 §8 absolute urgency (safety-critical = 1000).
--   * The 11-dimension priority model is versioned data (H7 §21).
--   * Result interpretation is SEPARATE from the raw result (H7 §29/§30/§32).
--   * Every object carries a provenance edge to the Hutchison claim that
--     teachers it (H7 §31/§46).
--
--   investigation_domain            NEW (IDOM01..IDOM06)
--   investigation_purpose           NEW (PUR001..PUR014 — the 14 purposes, H7 §6)
--   investigation_specimen          NEW (SPEC_*)
--   investigation_method            NEW (METHOD_*)
--   investigation_concept           NEW (I001..I012 — reusable investigations)
--   investigation_component         NEW (panel components: CBC/U&E/spirometry)
--   investigation_indication        NEW (WHY useful → clinical question, H7 §44)
--   investigation_rule              NEW (IR001.. — SAFETY/MANDATORY/ACTIVATE/UNAVAILABLE/CONDITIONAL/DEPENDENCY)
--   investigation_rule_condition    NEW (extra value guards, H7 §10)
--   investigation_rule_action       NEW (dependencies, H7 §25)
--   investigation_priority_rule     NEW (11-dimension weights, H7 §21)
--   investigation_status            NEW (operational lifecycle)
--   investigation_source            NEW (provenance → HUTCHISON_24_2018)
--   investigation_version           NEW (temporal versioning, H7 §24/§30)
--   result_reference_standard       NEW (contextual ranges, H7 §30)
--   result_interpretation           NEW (controlled finding vocabulary, H7 §32)
--   result_phenotype_link           NEW (interpretation → concept, H7 §33)
-- Runtime tables (request/result/specimen chains) are created-but-EMPTY per H6 precedent.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. New canonical fact_definitions for investigation RESULT facts (H7 §14/§15)
-- Reuses existing facts where already present (CREATININE, SPO2 existing).
-- ---------------------------------------------------------------------------
INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES
    ('HAEMOGLOBIN',              'Haemoglobin',                'Haemoglobin concentration (g/dL) on a full blood count.',                         'numeric', false, true),
    ('WHITE_CELL_COUNT',         'White blood cell count',     'White blood cell count (x10^9/L); raised in infection/inflammation.',             'numeric', false, true),
    ('NEUTROPHIL_COUNT',         'Neutrophil count',           'Neutrophil count (x10^9/L); dominant response to bacterial infection.',          'numeric', false, true),
    ('LYMPHOCYTE_COUNT',         'Lymphocyte count',           'Lymphocyte count (x10^9/L).',                                                    'numeric', false, true),
    ('PLATELET_COUNT',           'Platelet count',             'Platelet count (x10^9/L).',                                                       'numeric', false, true),
    ('MEAN_CELL_VOLUME',         'Mean cell volume',           'Mean cell volume (fL); micro/macrocytosis.',                                      'numeric', false, true),
    ('C_REACTIVE_PROTEIN',       'C-reactive protein',         'C-reactive protein (mg/L); acute-phase inflammation marker.',                    'numeric', false, true),
    ('UREA',                     'Urea',                       'Plasma urea (mmol/L).',                                                          'numeric', false, true),
    ('SODIUM',                   'Sodium',                     'Plasma sodium (mmol/L).',                                                        'numeric', false, true),
    ('POTASSIUM',                'Potassium',                  'Plasma potassium (mmol/L).',                                                     'numeric', false, true),
    ('FORCED_EXPIRATORY_VOLUME_1','FEV1',                      'Forced expiratory volume in 1 second (L).',                                       'numeric', false, true),
    ('FORCED_VITAL_CAPACITY',    'FVC',                        'Forced vital capacity (L).',                                                     'numeric', false, true),
    ('FEV1_FVC_RATIO',           'FEV1/FVC ratio',             'FEV1/FVC ratio; <0.70 suggests obstructive airflow limitation.',                 'numeric', false, true)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description,
    data_type = EXCLUDED.data_type, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 2. investigation_domain — the universal domains (H7 §12)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_domain (domain_code, code, body_system_code, label, description, sort_order, status) VALUES
    ('IDOM01','HAEMATOLOGY',   'HAEMATOLOGICAL', 'Haematology',        'Full blood count and its components (H7 §13 CBC; Box 2.4 first-pass workup, HCH2-0006).',  1, 'active'),
    ('IDOM02','BIOCHEMISTRY',  'CONSTITUTIONAL', 'Biochemistry',       'Inflammation (CRP), urea/electrolytes and creatinine (H7 §13; immediate workup, HCH2-0006).', 2, 'active'),
    ('IDOM03','MICROBIOLOGY',  'IMMUNE',         'Microbiology',       'Blood cultures, sputum microscopy and molecular TB testing (HCH12-0004/0007, HCH2-0006).',   3, 'active'),
    ('IDOM04','IMAGING',       'RESPIRATORY',    'Imaging',            'Chest radiography, CT and echocardiography (HCH12-0004 CXR, HCH12-0019 effusion/pneumothorax).', 4, 'active'),
    ('IDOM05','PHYSIOLOGY',    'CONSTITUTIONAL', 'Physiology',         'Pulse oximetry, ECG and spirometry (HCH12-0016 monitoring; HCH12-0004 baseline spirometry).', 5, 'active')
ON CONFLICT (domain_code) DO UPDATE SET code = EXCLUDED.code, body_system_code = EXCLUDED.body_system_code,
    label = EXCLUDED.label, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 3. investigation_purpose — the 14 clinical purposes, first-class objects (H7 §6/§7)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_purpose (purpose_code, code, label, description, sort_order, status) VALUES
    ('PUR001','DIAGNOSIS','Diagnosis','Establish or confirm the cause of the presentation (H7 §6).',1,'active'),
    ('PUR002','CONFIRMATION','Confirmation','Confirm a provisional diagnosis made on history/exam (H7 §6).',2,'active'),
    ('PUR003','EXCLUSION','Exclusion','Exclude an important differential diagnosis (H7 §6).',3,'active'),
    ('PUR004','DIFFERENTIATION','Differentiation','Separate between two plausible mechanisms (e.g. effusion vs pneumothorax, HCH12-0019) (H7 §6).',4,'active'),
    ('PUR005','SEVERITY_ASSESSMENT','Severity assessment','Grade severity or risk (H7 §6).',5,'active'),
    ('PUR006','BASELINE_ASSESSMENT','Baseline assessment','Capture a baseline to compare against (chronic cough spirometry, HCH12-0004) (H7 §6).',6,'active'),
    ('PUR007','COMPLICATION_DETECTION','Complication detection','Detect a complication of the illness (H7 §6).',7,'active'),
    ('PUR008','PROGNOSTICATION','Prognostication','Inform prognosis (H7 §6).',8,'active'),
    ('PUR009','TREATMENT_SELECTION','Treatment selection','Select the right treatment (culture sensitivity) (H7 §6).',9,'active'),
    ('PUR010','SAFETY_BEFORE_TREATMENT','Safety before treatment','Verify safety before prescribing (renal function before contrast/nephrotoxic) (H7 §6).',10,'active'),
    ('PUR011','MONITORING','Monitoring','Monitor a physiological variable over time (respiratory rate/Spo2, HCH12-0016) (H7 §6).',11,'active'),
    ('PUR012','RESPONSE_ASSESSMENT','Response assessment','Assess response to treatment (H7 §6).',12,'active'),
    ('PUR013','SCREENING','Screening','Screen a risk group (H7 §6).',13,'active'),
    ('PUR014','SURVEILLANCE','Surveillance','Ongoing monitoring for change (H7 §6).',14,'active')
ON CONFLICT (purpose_code) DO UPDATE SET code = EXCLUDED.code, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 4. investigation_specimen — specimens/studies (H7 §18)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_specimen (specimen_code, name, description, collection_site, collection_method, container_type, sort_order, status) VALUES
    ('SPEC_BLOOD', 'Venous blood',' Blood for haematology/biochemistry/microbiology.',' antecubital fossa',' venepuncture',' EDTA / plain / blood-culture bottle', 1, 'active'),
    ('SPEC_SPUTUM','Sputum',' Coughed sputum for microscopy / molecular TB testing.',' airways',' coughed specimen',' sterile universal container', 2, 'active'),
    ('SPEC_URINE','Urine',' Mid-stream urine sample.',' urethra',' clean-catch mid-stream',' sterile universal container', 3, 'active'),
    ('SPEC_IMAGE','Imaging study',' No physical specimen; the imaging series itself.',' n/a',' n/a',' imaging series', 4, 'active'),
    ('SPEC_NONE','No specimen',' Investigation requires no specimen (e.g. spirometry, ECG).',' n/a',' n/a',' n/a', 5, 'active')
ON CONFLICT (specimen_code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description,
    collection_site = EXCLUDED.collection_site, collection_method = EXCLUDED.collection_method,
    container_type = EXCLUDED.container_type, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 5. investigation_method — techniques/assays (H7 §12)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_method (method_code, name, description, sort_order, status) VALUES
    ('METHOD_LAB_ANALYSER',    'Laboratory analyser',' Automated haematology/biochemistry analyser.', 1, 'active'),
    ('METHOD_CULTURE',         'Microbiological culture',' Culture and sensitivity of blood or sputum.', 2, 'active'),
    ('METHOD_MICROSCOPY',      'Microscopy',' Direct microscopic examination of a specimen.', 3, 'active'),
    ('METHOD_PCR',             'Molecular PCR',' Nucleic-acid amplification for TB (HCH12-0004/0007 pulmonary TB workup).', 4, 'active'),
    ('METHOD_RADIOGRAPH',      'Radiograph',' Conventional chest radiography (HCH12-0004 CXR).', 5, 'active'),
    ('METHOD_ULTRASOUND',      'Ultrasound',' Transthoracic echocardiography.', 6, 'active'),
    ('METHOD_ECG',             'Electrocardiography',' 12-lead ECG recording.', 7, 'active'),
    ('METHOD_SPIROMETRY',      'Spirometry',' Flow-volume manoeuvre (baseline for chronic cough, HCH12-0004).', 8, 'active'),
    ('METHOD_PULSE_OXIMETRY',  'Pulse oximetry',' SpO2 monitoring (HCH12-0016).', 9, 'active')
ON CONFLICT (method_code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 6. investigation_concept — universal investigation definitions I001..I012 (H7 §13)
--    base_priority = H7 §8 absolute urgency (safety-critical = 1000).
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_concept
    (code, domain_code, concept_id, fact_definition_code, canonical_code, canonical_name, short_label, description,
     modality, specimen_type_code, preparation_requirements, patient_constraints, safety_requirements,
     result_structure, clinical_purposes, base_priority, applies_to_context_codes, capture_method_codes, is_mandatory, status)
VALUES
    ('I001','IDOM01', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-FBC'), NULL,
     'CBC','Full blood count','FBC',' Full blood count: haemoglobin, white cells, neutrophils, platelets, MCV. Immediate first-pass workup (Box 2.4, HCH2-0006).',
     'LAB','SPEC_BLOOD','No fasting needed','{}','',
     'COMPONENT_PANEL', ARRAY['PUR002','PUR005','PUR006','PUR012'], 700, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], ARRAY['LAB_MEASURED'], false, 'active'),
    ('I002','IDOM02', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-CRP'), 'C_REACTIVE_PROTEIN',
     'CRP','C-reactive protein','CRP',' Acute-phase inflammatory marker; used with CBC to grade severity and monitor therapy.',
     'LAB','SPEC_BLOOD','No fasting needed','{}','',
     'NUMERIC', ARRAY['PUR005','PUR012'], 650, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], ARRAY['LAB_MEASURED'], false, 'active'),
    ('I003','IDOM02', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-UREA-CREAT'), NULL,
     'U_E','Urea and electrolytes','U&E',' Urea, creatinine, sodium, potassium. Safety gate before nephrotoxic drugs/contrast; fluid/renal assessment.',
     'LAB','SPEC_BLOOD','No fasting needed','{}',' Result needed BEFORE iodinated contrast (safety, H7 §25/§26).',
     'COMPONENT_PANEL', ARRAY['PUR005','PUR006','PUR010'], 500, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], ARRAY['LAB_MEASURED'], false, 'active'),
    ('I004','IDOM03', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-BLOOD-CULTURE'), NULL,
     'BLOOD_CULTURE','Blood culture','Blood cx',' Blood cultures before antibiotics in suspected serious infection (immediate workup, Box 2.4 HCH2-0006).',
     'MICROBIOLOGY','SPEC_BLOOD','Ideally before antibiotics','{}','',
     'MICROBIOLOGY', ARRAY['PUR001','PUR002','PUR009'], 610, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], ARRAY['LAB_MEASURED'], false, 'active'),
    ('I005','IDOM04', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-CHEST-XRAY'), NULL,
     'CHEST_XRAY','Chest X-ray','CXR',' Chest radiograph. AT LEAST a baseline CXR for any cough with haemoptysis; baseline for chronic cough (HCH12-0004/0007).',
     'IMAGING','SPEC_IMAGE','','{}',' Radiation dose kept minimal in pregnancy (H7 §26).',
     'STRUCTURED_FINDINGS', ARRAY['PUR001','PUR002','PUR003','PUR004','PUR006'], 920, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], ARRAY['IMAGING_DERIVED'], false, 'active'),
    ('I006','IDOM05', NULL, NULL,
     'ECG','Electrocardiogram','ECG',' 12-lead ECG; chest pain/cardiac assessment and rhythm monitoring (HCH2-0004 cardiovascular examination).',
     'PHYSIOLOGY','SPEC_NONE','','{}','',
     'STRUCTURED_FINDINGS', ARRAY['PUR001','PUR003','PUR007'], 580, ARRAY['ADULT','OLDER_ADULT','CHILD'], ARRAY['DEVICE_MEASURED'], false, 'active'),
    ('I007','IDOM04', NULL, NULL,
     'ECHO','Echocardiogram','Echo',' Transthoracic echocardiography; assesses cardiac function/valvular disease/effusion.',
     'IMAGING','SPEC_IMAGE','','{}','',
     'STRUCTURED_FINDINGS', ARRAY['PUR001','PUR005'], 400, ARRAY['ADULT','OLDER_ADULT','CHILD'], ARRAY['IMAGING_DERIVED'], false, 'active'),
    ('I008','IDOM05', NULL, NULL,
     'SPIROMETRY','Spirometry','Spirometry',' Flow-volume manoeuvre. Baseline investigation for ANY chronic cough (>8 weeks) — alongside CXR (HCH12-0004).',
     'PHYSIOLOGY','SPEC_NONE','Maximal forced manoeuvre; withhold bronchodilators if assessing reversibility','{}','',
     'COMPONENT_PANEL', ARRAY['PUR002','PUR004','PUR006','PUR011'], 320, ARRAY['ADULT','OLDER_ADULT','CHILD'], ARRAY['DEVICE_MEASURED'], false, 'active'),
    ('I009','IDOM05', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PULSE-OXIMETRY'), 'SPO2',
     'PULSE_OXIMETRY','Pulse oximetry','SpO2',' Oxygen saturation monitoring. Respiratory safety gate; normal SpO2 ≥95 % (HCH12-0016).',
     'PHYSIOLOGY','SPEC_NONE','','{}','',
     'NUMERIC', ARRAY['PUR005','PUR011'], 1000, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','INPATIENT','OUTPATIENT'], ARRAY['DEVICE_MEASURED'], true, 'active'),
    ('I010','IDOM03', NULL, NULL,
     'SPUTUM_MICROSCOPY','Sputum microscopy','Sputum MC',' Direct microscopy of coughed sputum in haemoptysis/chronic cough (HCH12-0004/0007).',
     'MICROBIOLOGY','SPEC_SPUTUM','Early-morning coughed specimen','{}','',
     'MICROBIOLOGY', ARRAY['PUR001','PUR002'], 360, ARRAY['ADULT','OLDER_ADULT','CHILD'], ARRAY['LAB_MEASURED'], false, 'active'),
    ('I011','IDOM03', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-GENEXPERT'), NULL,
     'SPUTUM_TB_MOLECULAR','Sputum TB molecular test','TB PCR',' Molecular TB testing (nucleic-acid amplification) where TB is suspected (HCH12-0004/0007 respiratory red flags).',
     'MICROBIOLOGY','SPEC_SPUTUM','Early-morning coughed specimen','{}','',
     'MICROBIOLOGY', ARRAY['PUR001','PUR002','PUR003'], 390, ARRAY['ADULT','OLDER_ADULT','CHILD'], ARRAY['LAB_MEASURED'], false, 'active'),
    ('I012','IDOM04', NULL, NULL,
     'CT_CHEST','CT chest','CT chest',' CT of the thorax; advanced imaging for masses, complex effusions, mediastinal shift (HCH12-0019).',
     'IMAGING','SPEC_IMAGE','Iodinated contrast','{"PREGNANCY"}',' Renal function (U&E/creatinine) required BEFORE iodinated contrast (H7 §25/§26).',
     'STRUCTURED_FINDINGS', ARRAY['PUR001','PUR002','PUR004'], 220, ARRAY['ADULT','OLDER_ADULT'], ARRAY['IMAGING_DERIVED'], false, 'active')
ON CONFLICT (code) DO UPDATE SET domain_code = EXCLUDED.domain_code, concept_id = EXCLUDED.concept_id,
    fact_definition_code = EXCLUDED.fact_definition_code, canonical_code = EXCLUDED.canonical_code,
    canonical_name = EXCLUDED.canonical_name, short_label = EXCLUDED.short_label, description = EXCLUDED.description,
    modality = EXCLUDED.modality, specimen_type_code = EXCLUDED.specimen_type_code,
    preparation_requirements = EXCLUDED.preparation_requirements, patient_constraints = EXCLUDED.patient_constraints,
    safety_requirements = EXCLUDED.safety_requirements, result_structure = EXCLUDED.result_structure,
    clinical_purposes = EXCLUDED.clinical_purposes, base_priority = EXCLUDED.base_priority,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes, capture_method_codes = EXCLUDED.capture_method_codes,
    is_mandatory = EXCLUDED.is_mandatory, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 7. investigation_component — measurable parts of panel investigations (H7 §14/§15)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_component
    (investigation_concept_code, component_code, fact_definition_code, name, short_label, value_type, unit, normal_range, sort_order, is_mandatory, status)
VALUES
    ('I001','HAEMOGLOBIN','HAEMOGLOBIN','Haemoglobin','Hb',   'NUMERIC','g/dL',      '{"min":13.0,"max":17.0,"unit":"g/dL","inclusive":true}',   1,true,'active'),
    ('I001','WHITE_CELL_COUNT','WHITE_CELL_COUNT','White blood cell count','WBC','NUMERIC','x10^9/L','{"min":4.0,"max":11.0,"unit":"x10^9/L","inclusive":true}',   2,true,'active'),
    ('I001','NEUTROPHIL_COUNT','NEUTROPHIL_COUNT','Neutrophil count','Neut','NUMERIC','x10^9/L','{"min":2.0,"max":7.5,"unit":"x10^9/L","inclusive":true}',      3,true,'active'),
    ('I001','PLATELET_COUNT','PLATELET_COUNT','Platelet count','Plt', 'NUMERIC','x10^9/L','{"min":150.0,"max":400.0,"unit":"x10^9/L","inclusive":true}',   4,true,'active'),
    ('I001','MEAN_CELL_VOLUME','MEAN_CELL_VOLUME','Mean cell volume','MCV','NUMERIC','fL','{"min":80.0,"max":100.0,"unit":"fL","inclusive":true}',          5,true,'active'),
    ('I003','UREA','UREA','Urea','Urea',               'NUMERIC','mmol/L','{"min":2.5,"max":7.8,"unit":"mmol/L","inclusive":true}',                    1,true,'active'),
    ('I003','CREATININE','CREATININE','Creatinine','Cr', 'NUMERIC','umol/L','{"min":60.0,"max":110.0,"unit":"umol/L","inclusive":true}',               2,true,'active'),
    ('I003','SODIUM','SODIUM','Sodium','Na',            'NUMERIC','mmol/L','{"min":135.0,"max":145.0,"unit":"mmol/L","inclusive":true}',              3,true,'active'),
    ('I003','POTASSIUM','POTASSIUM','Potassium','K',     'NUMERIC','mmol/L','{"min":3.5,"max":5.0,"unit":"mmol/L","inclusive":true}',                 4,true,'active'),
    ('I008','FORCED_EXPIRATORY_VOLUME_1','FORCED_EXPIRATORY_VOLUME_1','FEV1','FEV1','NUMERIC','L','{"min":null,"max":null,"unit":"L","inclusive":true}',1,true,'active'),
    ('I008','FORCED_VITAL_CAPACITY','FORCED_VITAL_CAPACITY','FVC','FVC','NUMERIC','L','{"min":null,"max":null,"unit":"L","inclusive":true}',            2,true,'active'),
    ('I008','FEV1_FVC_RATIO','FEV1_FVC_RATIO','FEV1/FVC ratio','Ratio','NUMERIC','ratio','{"min":0.70,"max":1.00,"unit":"ratio","inclusive":true}',    3,true,'active')
ON CONFLICT (investigation_concept_code, component_code) DO UPDATE SET
    fact_definition_code = EXCLUDED.fact_definition_code, name = EXCLUDED.name, short_label = EXCLUDED.short_label,
    value_type = EXCLUDED.value_type, unit = EXCLUDED.unit, normal_range = EXCLUDED.normal_range,
    sort_order = EXCLUDED.sort_order, is_mandatory = EXCLUDED.is_mandatory, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 8. investigation_indication — "phenotype/fact X → investigation Y → question Z" (H7 §44)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_indication
    (investigation_concept_code, purpose_code, clinical_question, trigger_fact_codes, trigger_phenotype_codes, context_codes, evidence_claim_code, strength, is_active, status)
VALUES
    ('I005','PUR001','Is there consolidation or an opacity after haemoptysis?',        ARRAY['BLOOD_IN_SPUTUM'],'{}', ARRAY['ADULT','OLDER_ADULT','CHILD','TELEMEDICINE'],'HCH12-0007','strong', true, 'active'),
    ('I005','PUR006','Baseline chest radiograph for chronic cough (>8 weeks).',       ARRAY['COUGH_DURATION_DAYS'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0004','strong', true, 'active'),
    ('I005','PUR004','Effusion vs pneumothorax: trachea deviated away from the lesion.', ARRAY['RLL_DULLNESS'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0019','strong', true, 'active'),
    ('I005','PUR001','Does consolidation explain bronchial breath sounds/crackles?',     ARRAY['RLL_BRONCHIAL_BREATH_SOUNDS','CRACKLES'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0018','moderate', true, 'active'),
    ('I008','PUR006','Baseline spirometry for chronic cough (>8 weeks).',             ARRAY['COUGH_DURATION_DAYS'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0004','strong', true, 'active'),
    ('I008','PUR004','Is the limitation obstructive or restrictive (FEV1/FVC)?',      ARRAY['COUGH_DURATION_DAYS','WHEEZE_PRESENT'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0004','moderate', true, 'active'),
    ('I009','PUR011','Is the patient hypoxic?',                                        ARRAY['DYSPNOEA_PRESENT','RESPIRATORY_DISTRESS'],'{}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','INPATIENT'],'HCH12-0016','strong', true, 'active'),
    ('I001','PUR005','Is there infection/anaemia explaining the presentation?',         ARRAY['FEVER_PRESENT','WEIGHT_LOSS'],'{}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'],'HCH2-0006','moderate', true, 'active'),
    ('I010','PUR001','Is an infective organism present in the sputum?',                 ARRAY['BLOOD_IN_SPUTUM','SPUTUM_COLOUR'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0007','moderate', true, 'active'),
    ('I011','PUR002','Is TB confirmed by molecular testing?',                            ARRAY['TB_CONTACT','BLOOD_IN_SPUTUM','NIGHT_SWEATS'],'{}', ARRAY['ADULT','OLDER_ADULT'],'HCH12-0007','moderate', true, 'active')
ON CONFLICT (investigation_concept_code, purpose_code, clinical_question) DO UPDATE SET
    trigger_fact_codes = EXCLUDED.trigger_fact_codes, trigger_phenotype_codes = EXCLUDED.trigger_phenotype_codes,
    context_codes = EXCLUDED.context_codes, evidence_claim_code = EXCLUDED.evidence_claim_code,
    strength = EXCLUDED.strength, is_active = EXCLUDED.is_active, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 9. investigation_rule — the H7 selection/priority/safety/dependency engine (H7 §11/§25/§26)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_rule
    (rule_code, trigger_type, trigger_code, target_type, target_code, modification, priority_delta, rationale, evidence_claim_code, applies_to_context_codes, is_active, status)
VALUES
    ('IR001','ALWAYS',       NULL,              'investigation_concept','I009','SAFETY',     0,     'Pulse oximetry is a physiological safety gate (respiratory monitoring, HCH12-0016).',  'HCH12-0016', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','INPATIENT','OUTPATIENT'], true, 'active'),
    ('IR002','FACT',         'BLOOD_IN_SPUTUM', 'investigation_concept','I005','MANDATORY', 100,   'Haemoptysis requires prompt assessment with at least a baseline chest X-ray (HCH12-0004/0007).','HCH12-0007', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('IR003','FACT',         'COUGH_DURATION_DAYS', 'investigation_concept','I008','ACTIVATE', 40, 'Chronic cough (>8 weeks) → baseline spirometry (HCH12-0004).',                    'HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('IR004','FACT',         'COUGH_DURATION_DAYS', 'investigation_concept','I005','ACTIVATE', 40, 'Chronic cough (>8 weeks) → baseline chest X-ray (HCH12-0004).',                  'HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('IR005','FACT',         'DYSPNOEA_PRESENT','investigation_concept','I009','ACTIVATE',  90,   'Dyspnoea → pulse oximetry to detect hypoxaemia (HCH12-0016).',                   'HCH12-0016', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','EMERGENCY','INPATIENT'], true, 'active'),
    ('IR006','FACT',         'DYSPNOEA_PRESENT','investigation_concept','I005','ACTIVATE',  70,   'Dyspnoea with respiratory findings → chest X-ray for consolidation/effusion.',    'HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('IR007','FACT',         'RLL_DULLNESS',    'investigation_concept','I005','ACTIVATE',  60,   'Percussion dullness → imaging for consolidation/effusion/pneumothorax (HCH12-0019).','HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('IR008','FACT',         'CRACKLES',        'investigation_concept','I005','ACTIVATE',  60,   'Crackles on auscultation → chest X-ray (consolidation/fibrosis/failure, HCH12-0018).','HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('IR009','FACT',         'RLL_BRONCHIAL_BREATH_SOUNDS','investigation_concept','I005','ACTIVATE', 60, 'Bronchial breath sounds → chest X-ray for consolidation (HCH12-0018).','HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('IR010','CONTEXT',      'PREGNANCY',       'investigation_concept','I012','UNAVAILABLE', 0,  'CT with contrast is avoided in pregnancy (radiation safety, H7 §26).',           NULL,          ARRAY['PREGNANCY'], true, 'active'),
    ('IR011','FACT',         'FEVER_PRESENT',   'investigation_concept','I001','ACTIVATE',  50,   'Fever → full blood count as an immediate first-pass workup (Box 2.4, HCH2-0006).','HCH2-0006', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('IR012','CONTEXT',      'EMERGENCY',       'investigation_concept','I001','ACTIVATE',  30,   'Emergency → full blood count immediately (Box 2.4, HCH2-0006).',                 'HCH2-0006', ARRAY['EMERGENCY'], true, 'active'),
    ('IR013','FACT',         'TEMPERATURE',     'investigation_concept','I004','CONDITIONAL', 40, 'Fever ≥38.5 °C → blood cultures before antibiotics (Box 2.4, HCH2-0006).',       'HCH2-0006', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('IR014','ALWAYS',       NULL,              'investigation_concept','I012','DEPENDENCY',  0,  'Contrast CT requires renal function (U&E) result BEFORE contrast (H7 §25/§26).', NULL,          ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('IR015','FACT',         'BLOOD_IN_SPUTUM', 'investigation_concept','I010','ACTIVATE',  30,   'Haemoptysis → sputum microscopy for infective organisms (HCH12-0007).',         'HCH12-0007', ARRAY['ADULT','OLDER_ADULT'], true, 'active')
ON CONFLICT (rule_code) DO UPDATE SET trigger_type = EXCLUDED.trigger_type, trigger_code = EXCLUDED.trigger_code,
    target_type = EXCLUDED.target_type, target_code = EXCLUDED.target_code, modification = EXCLUDED.modification,
    priority_delta = EXCLUDED.priority_delta, rationale = EXCLUDED.rationale, evidence_claim_code = EXCLUDED.evidence_claim_code,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes, is_active = EXCLUDED.is_active, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 10. investigation_rule_condition — value guards (H7 §10 filter stage)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_rule_condition (rule_code, condition_code, fact_definition_code, operator, value, rationale, is_active) VALUES
    ('IR003','COND001','COUGH_DURATION_DAYS','>',   '56',' Chronic cough = duration > 8 weeks = 56 days (HCH12-0004: "more than 8 weeks").',      true),
    ('IR004','COND002','COUGH_DURATION_DAYS','>',   '56',' Chronic cough = duration > 8 weeks = 56 days (HCH12-0004).',                          true),
    ('IR013','COND003','TEMPERATURE','>=',          '38.5',' Significant fever threshold for blood cultures (HCH2-0006 immediate workup).',          true)
ON CONFLICT (rule_code, condition_code) DO UPDATE SET fact_definition_code = EXCLUDED.fact_definition_code,
    operator = EXCLUDED.operator, value = EXCLUDED.value, rationale = EXCLUDED.rationale, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 11. investigation_rule_action — dependencies and sequencing (H7 §25)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_rule_action
    (rule_code, action_type, target_investigation_code, rationale, sort_order, is_active)
SELECT ir.rule_code, v.action_type, v.target_investigation_code, v.rationale, v.sort_order, true
FROM (VALUES
     ('IR004','REQUEST_ALONGSIDE','I008',' Baseline CXR and spirometry are performed together for chronic cough (HCH12-0004).',1)
) AS v(rule_code, action_type, target_investigation_code, rationale, sort_order)
JOIN knowledge.investigation_rule ir ON ir.rule_code = v.rule_code
ON CONFLICT (rule_code, action_type, target_investigation_code) DO UPDATE SET
    rationale = EXCLUDED.rationale, sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

INSERT INTO knowledge.investigation_rule_action
    (rule_code, action_type, target_investigation_code, rationale, sort_order, is_active)
SELECT ir.rule_code, v.action_type, v.target_investigation_code, v.rationale, v.sort_order, true
FROM (VALUES
     ('IR014','REQUIRE_RESULT_BEFORE','I003',' Renal function (U&E/creatinine) must be available BEFORE iodinated contrast (H7 §25/§26).',1)
) AS v(rule_code, action_type, target_investigation_code, rationale, sort_order)
JOIN knowledge.investigation_rule ir ON ir.rule_code = v.rule_code
ON CONFLICT (rule_code, action_type, target_investigation_code) DO UPDATE SET
    rationale = EXCLUDED.rationale, sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 12. investigation_priority_rule — the H7 §21 multi-dimensional priority model
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_priority_rule
    (priority_code, dimension, direction, weight, description, version, effective_from, status)
VALUES
    ('IPR001','CLINICAL_URGENCY',     'POSITIVE', 3.00, ' How urgent the clinical situation makes this investigation.',          1, '2024-01-01','active'),
    ('IPR002','EXPECTED_INFORMATION', 'POSITIVE', 1.00, ' How much new information the result is expected to add.',             1, '2024-01-01','active'),
    ('IPR003','DIAGNOSTIC_RELEVANCE', 'POSITIVE', 1.50, ' How directly the result bears on the leading differential.',          1, '2024-01-01','active'),
    ('IPR004','SEVERITY_RELEVANCE',   'POSITIVE', 1.00, ' How well it grades severity/risk.',                                   1, '2024-01-01','active'),
    ('IPR005','MANAGEMENT_IMPACT',    'POSITIVE', 1.50, ' How much it would change management (culture → antibiotic choice).',  1, '2024-01-01','active'),
    ('IPR006','SAFETY_VALUE',         'POSITIVE', 1.00, ' How much it protects patient safety (renal function before contrast).',1, '2024-01-01','active'),
    ('IPR007','CONTEXT_FIT',          'POSITIVE', 0.50, ' How well it fits the active context (telemedicine/pregnancy/age).',   1, '2024-01-01','active'),
    ('IPR008','HARM_PENALTY',         'NEGATIVE', 2.00, ' Harm penalty (radiation, contrast nephrotoxicity).',                  1, '2024-01-01','active'),
    ('IPR009','COST_PENALTY',         'NEGATIVE', 0.50, ' Cost penalty of the investigation.',                                   1, '2024-01-01','active'),
    ('IPR010','REDUNDANCY_PENALTY',   'NEGATIVE', 0.50, ' Penalty for duplicating an already-captured result.',                 1, '2024-01-01','active'),
    ('IPR011','AVAILABILITY_PENALTY', 'NEGATIVE', 0.50, ' Penalty when the investigation is not locally available.',            1, '2024-01-01','active')
ON CONFLICT (priority_code) DO UPDATE SET dimension = EXCLUDED.dimension, direction = EXCLUDED.direction,
    weight = EXCLUDED.weight, description = EXCLUDED.description, version = EXCLUDED.version,
    effective_from = EXCLUDED.effective_from, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 13. investigation_status — operational lifecycle (H7 §20/§12)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_status (status_code, label, description, sort_order, is_terminal, status) VALUES
    ('RECOMMENDED',      'Recommended',       ' Proposed by the engine; not yet ordered.',                     1, false, 'active'),
    ('ORDERED',          'Ordered',           ' Ordered for the patient/encounter.',                           2, false, 'active'),
    ('SPECIMEN_COLLECTED','Specimen collected',' Specimen/study obtained.',                                    3, false, 'active'),
    ('IN_PROGRESS',      'In progress',       ' Sample being processed / imaging being reported.',             4, false, 'active'),
    ('RESULT_AVAILABLE', 'Result available',  ' Raw result available for interpretation.',                     5, false, 'active'),
    ('REPORTED',         'Reported',          ' Interpreted result reported.',                                 6, true,  'active'),
    ('CANCELLED',        'Cancelled',         ' Order cancelled (e.g. no longer indicated).',                  7, true,  'active'),
    ('ENTERED_IN_ERROR', 'Entered in error',  ' Order/result entered in error.',                               8, true,  'active')
ON CONFLICT (status_code) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order, is_terminal = EXCLUDED.is_terminal, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 14. investigation_source — provenance of investigation knowledge (H7 §31)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_source
    (investigation_concept_code, source_version_id, reference, organization, publication, edition, year, chapter_ref, section_ref, version, effective_from, status)
VALUES
    ('I001','HUTCHISON_24_2018','Box 2.4 — investigations to do immediately.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C02','Box 2.4','v1','2018-01-01','active'),
    ('I002','HUTCHISON_24_2018','Box 2.4 — investigations to do immediately.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C02','Box 2.4','v1','2018-01-01','active'),
    ('I003','HUTCHISON_24_2018','Box 2.4 — investigations to do immediately.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C02','Box 2.4','v1','2018-01-01','active'),
    ('I004','HUTCHISON_24_2018','Box 2.4 — investigations to do immediately.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C02','Box 2.4','v1','2018-01-01','active'),
    ('I005','HUTCHISON_24_2018','CH12 respiratory — cough thresholds + haemoptysis + tracheal deviation.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('I006','HUTCHISON_24_2018','Box 2.5 — complete examination order (cardiovascular).','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C02','Box 2.5','v1','2018-01-01','active'),
    ('I007','HUTCHISON_24_2018','Box 2.5 — complete examination order (cardiovascular).','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C02','Box 2.5','v1','2018-01-01','active'),
    ('I008','HUTCHISON_24_2018','CH12 — chronic cough (>8 weeks) baseline CXR + spirometry.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('I009','HUTCHISON_24_2018','CH12 — respiratory rate and rhythm / SpO2 monitoring.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('I010','HUTCHISON_24_2018','CH12 — cough/sputum + haemoptysis careful evaluation.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('I011','HUTCHISON_24_2018','CH12 — respiratory red flags (haemoptysis, weight loss, TB risk).','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('I012','HUTCHISON_24_2018','CH12 — tracheal deviation → effusion/pneumothorax → imaging.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active')
ON CONFLICT (investigation_concept_code, source_version_id) DO UPDATE SET
    reference = EXCLUDED.reference, organization = EXCLUDED.organization, publication = EXCLUDED.publication,
    edition = EXCLUDED.edition, year = EXCLUDED.year, chapter_ref = EXCLUDED.chapter_ref,
    section_ref = EXCLUDED.section_ref, version = EXCLUDED.version,
    effective_from = EXCLUDED.effective_from, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 15. investigation_version — temporal versioning of investigation knowledge (H7 §24/§30)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.investigation_version (investigation_concept_code, version_no, effective_from, supersedes, change_note, status)
SELECT ic.code, 1, '2018-01-01', NULL, ' H7 seed from Hutchison Clinical Methods 24e.', 'active'
FROM knowledge.investigation_concept ic
ON CONFLICT (investigation_concept_code, version_no) DO UPDATE SET
    effective_from = EXCLUDED.effective_from, change_note = EXCLUDED.change_note, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 16. result_reference_standard — contextual ranges for result classification (H7 §29/§30)
--    RAW RESULT → STANDARD → CLASSIFICATION → PHENOTYPE.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.result_reference_standard
    (code, investigation_concept_code, component_code, fact_definition_code, method_code, applies_to_context_codes, sex, range_low, range_high, range_unit, is_inclusive, classification, source, source_claim_code, evidence_strength, status)
VALUES
    ('RRS001','I001','HAEMOGLOBIN','HAEMOGLOBIN','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'MALE',   13.0,  17.0, 'g/dL',   true,'NORMAL','Hutchison 24e adult male FBC reference.',    'HCH2-0006','moderate','active'),
    ('RRS002','I001','HAEMOGLOBIN','HAEMOGLOBIN','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'FEMALE', 12.0,  16.0, 'g/dL',   true,'NORMAL','Hutchison 24e adult female FBC reference.',    'HCH2-0006','moderate','active'),
    ('RRS003','I001','WHITE_CELL_COUNT','WHITE_CELL_COUNT','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'ANY', 4.0, 11.0, 'x10^9/L', true,'NORMAL','Hutchison 24e adult WBC reference.',         'HCH2-0006','moderate','active'),
    ('RRS004','I001','NEUTROPHIL_COUNT','NEUTROPHIL_COUNT','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 2.0, 7.5, 'x10^9/L', true,'NORMAL','Hutchison 24e adult neutrophil reference.',    'HCH2-0006','moderate','active'),
    ('RRS005','I001','PLATELET_COUNT','PLATELET_COUNT','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 150.0, 400.0, 'x10^9/L', true,'NORMAL','Hutchison 24e adult platelet reference.',   'HCH2-0006','moderate','active'),
    ('RRS006','I001','MEAN_CELL_VOLUME','MEAN_CELL_VOLUME','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 80.0, 100.0, 'fL', true,'NORMAL','Hutchison 24e adult MCV reference.',        'HCH2-0006','moderate','active'),
    ('RRS007','I002',NULL,'C_REACTIVE_PROTEIN','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 0.0, 10.0, 'mg/L', true,'NORMAL','Hutchison 24e CRP (normal <10 mg/L).',        'HCH2-0006','moderate','active'),
    ('RRS008','I003','UREA','UREA','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 2.5, 7.8, 'mmol/L', true,'NORMAL','Hutchison 24e urea reference.',              'HCH2-0006','moderate','active'),
    ('RRS009','I003','CREATININE','CREATININE','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 60.0, 110.0, 'umol/L', true,'NORMAL','Hutchison 24e creatinine reference.',       'HCH2-0006','moderate','active'),
    ('RRS010','I003','SODIUM','SODIUM','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 135.0, 145.0, 'mmol/L', true,'NORMAL','Hutchison 24e sodium reference.',           'HCH2-0006','moderate','active'),
    ('RRS011','I003','POTASSIUM','POTASSIUM','METHOD_LAB_ANALYSER', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 3.5, 5.0, 'mmol/L', true,'NORMAL','Hutchison 24e potassium reference.',        'HCH2-0006','moderate','active'),
    ('RRS012','I008','FEV1_FVC_RATIO','FEV1_FVC_RATIO','METHOD_SPIROMETRY', ARRAY['ADULT','OLDER_ADULT'], 'ANY', 0.70, 1.00, 'ratio', true,'NORMAL','Obstructive limitation when FEV1/FVC <0.70 (baseline spirometry, HCH12-0004).','HCH12-0004','moderate','active'),
    ('RRS013','I009',NULL,'SPO2','METHOD_PULSE_OXIMETRY', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'ANY', 95.0, 100.0, '%', true,'NORMAL','Normal oxygen saturation ≥95 % (HCH12-0016).','HCH12-0016','strong','active')
ON CONFLICT (code) DO UPDATE SET
    investigation_concept_code = EXCLUDED.investigation_concept_code, component_code = EXCLUDED.component_code,
    fact_definition_code = EXCLUDED.fact_definition_code, method_code = EXCLUDED.method_code,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes, sex = EXCLUDED.sex,
    range_low = EXCLUDED.range_low, range_high = EXCLUDED.range_high,
    range_unit = EXCLUDED.range_unit, is_inclusive = EXCLUDED.is_inclusive, classification = EXCLUDED.classification,
    source = EXCLUDED.source, source_claim_code = EXCLUDED.source_claim_code,
    evidence_strength = EXCLUDED.evidence_strength, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 17. result_interpretation — controlled interpretation vocabulary (H7 §32)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.result_interpretation (code, canonical_name, label, result_type_constraint, is_abnormal, is_critical, description, sort_order, status) VALUES
    ('RINT_NORMAL','Normal','Normal',                    NULL,             false, false, ' Result within the applied reference standard.',                                             1,'active'),
    ('RINT_ABNORMAL','Abnormal','Abnormal',              NULL,             true,  false, ' Result outside the applied reference standard.',                                            2,'active'),
    ('RINT_LEUKOCYTOSIS','Leukocytosis','Raised WBC',     'LAB',           true,  false, ' WBC >11 x10^9/L — bacterial infection/inflammation.',                                       3,'active'),
    ('RINT_NEUTROPHILIA','Neutrophilia','Raised neutrophils', 'LAB',       true,  false, ' Neutrophils >7.5 x10^9/L — bacterial response.',                                            4,'active'),
    ('RINT_ANAEMIA','Anaemia','Low haemoglobin',          'LAB',           true,  false, ' Hb below sex-specific adult range.',                                                        5,'active'),
    ('RINT_MICROCYTOSIS','Microcytosis','Low MCV',        'LAB',           true,  false, ' MCV <80 fL — iron deficiency/thalassaemia.',                                                6,'active'),
    ('RINT_THROMBOCYTOPENIA','Thrombocytopenia','Low platelets', 'LAB',    true,  false, ' Platelets <150 x10^9/L.',                                                                  7,'active'),
    ('RINT_ELEVATED_CRP','Elevated CRP','Raised CRP',     'LAB',           true,  false, ' CRP >10 mg/L — acute-phase inflammation.',                                                  8,'active'),
    ('RINT_HYPOXAEMIA','Hypoxaemia','Low SpO2',           'PHYSIOLOGY',    true,  true,  ' SpO2 <95 % — treat as respiratory compromise (HCH12-0016).',                               9,'active'),
    ('RINT_CONSOLIDATION','Consolidation','Consolidation','IMAGING',       true,  false, ' CXR opacity — pulmonary consolidation (bronchial breath sounds/crackles, HCH12-0018).',   10,'active'),
    ('RINT_PLEURAL_EFFUSION','Pleural effusion','Effusion','IMAGING',       true,  false, ' CXR blunting/opacity — effusion when trachea deviated AWAY (HCH12-0019).',                11,'active'),
    ('RINT_PNEUMOTHORAX','Pneumothorax','Pneumothorax',   'IMAGING',        true,  true,  ' CXR lung-edge with mediastinal shift — trachea deviated away (HCH12-0019).',              12,'active'),
    ('RINT_OBSTRUCTIVE_SPIROMETRY','Obstructive spirometry','Obstructive pattern','PHYSIOLOGY', true, false, ' FEV1/FVC <0.70 — obstructive airflow limitation (baseline spirometry, HCH12-0004).', 13,'active'),
    ('RINT_MTB_DETECTED','TB detected','MTB detected',    'MICROBIOLOGY',   true,  false, ' Molecular amplification detects Mycobacterium tuberculosis.',                               14,'active'),
    ('RINT_ORGANISM_DETECTED','Organism detected','Organism','MICROBIOLOGY', true,  false, ' Microorganism identified by microscopy/culture.',                                          15,'active')
ON CONFLICT (code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, label = EXCLUDED.label,
    result_type_constraint = EXCLUDED.result_type_constraint, is_abnormal = EXCLUDED.is_abnormal, is_critical = EXCLUDED.is_critical,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 18. result_phenotype_link — interpretation → concept bridge for H8 (H7 §33)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.result_phenotype_link (result_interpretation_code, associated_concept_code, strength, description, evidence_claim_code, is_active) VALUES
    ('RINT_CONSOLIDATION','CNS-ALVEOLAR-INFLAMMATION','strong',    ' CXR consolidation supports alveolar inflammation (consolidation, HCH12-0018).',    'HCH12-0018', true),
    ('RINT_CONSOLIDATION','CNS-PNEUMONIA','moderate',    ' Consolidation on CXR is a strong radiological marker of pneumonia.',                'HCH12-0018', true),
    ('RINT_PLEURAL_EFFUSION','CNS-PLEURAL-INFLAMMATION','strong',    ' Trachea deviated away from the affected side — effusion pushes the mediastinum (HCH12-0019).','HCH12-0019', true),
    ('RINT_HYPOXAEMIA','CNS-HYPOXAEMIA','strong',    ' SpO2 <95 % = hypoxaemia; respiratory monitoring (HCH12-0016).',                     'HCH12-0016', true),
    ('RINT_OBSTRUCTIVE_SPIROMETRY','CNS-AIRWAY-OBSTRUCTION','strong',    ' FEV1/FVC <0.70 = obstructive airway limitation (baseline spirometry, HCH12-0004).','HCH12-0004', true),
    ('RINT_MTB_DETECTED','CNS-TUBERCULOSIS','strong',    ' Molecular detection of MTB confirms pulmonary tuberculosis (respiratory red flags).','HCH12-0007', true),
    ('RINT_LEUKOCYTOSIS','CNS-ALVEOLAR-INFLAMMATION','weak',    ' Raised WBC supports an inflammatory/consolidative process (HCH2-0006 workup).','HCH2-0006', true)
ON CONFLICT (result_interpretation_code, associated_concept_code) DO UPDATE SET
    strength = EXCLUDED.strength, description = EXCLUDED.description,
    evidence_claim_code = EXCLUDED.evidence_claim_code, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 19. provenance — Hutchison claims → H7 knowledge objects (H7 §31/§46)
-- ---------------------------------------------------------------------------
-- 19a. investigation_concept edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, ic.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0006','investigation_concept','I001'),('HCH2-0006','investigation_concept','I002'),
     ('HCH2-0006','investigation_concept','I003'),('HCH2-0006','investigation_concept','I004'),
     ('HCH12-0004','investigation_concept','I005'),('HCH12-0007','investigation_concept','I005'),
     ('HCH12-0019','investigation_concept','I005'),('HCH2-0004','investigation_concept','I006'),
     ('HCH2-0004','investigation_concept','I007'),('HCH12-0004','investigation_concept','I008'),
     ('HCH12-0016','investigation_concept','I009'),('HCH12-0007','investigation_concept','I010'),
     ('HCH12-0007','investigation_concept','I011'),('HCH12-0019','investigation_concept','I012')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.investigation_concept ic ON ic.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 19b. investigation_component edges (joined by concept|component composite code)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, cmp.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0006','investigation_component','I001|HAEMOGLOBIN'),('HCH2-0006','investigation_component','I001|WHITE_CELL_COUNT'),
     ('HCH2-0006','investigation_component','I001|NEUTROPHIL_COUNT'),('HCH2-0006','investigation_component','I001|PLATELET_COUNT'),
     ('HCH2-0006','investigation_component','I001|MEAN_CELL_VOLUME'),('HCH2-0006','investigation_component','I003|UREA'),
     ('HCH2-0006','investigation_component','I003|CREATININE'),('HCH2-0006','investigation_component','I003|SODIUM'),
     ('HCH2-0006','investigation_component','I003|POTASSIUM'),('HCH12-0004','investigation_component','I008|FORCED_EXPIRATORY_VOLUME_1'),
     ('HCH12-0004','investigation_component','I008|FORCED_VITAL_CAPACITY'),('HCH12-0004','investigation_component','I008|FEV1_FVC_RATIO')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.investigation_component cmp
       ON cmp.investigation_concept_code || '|' || cmp.component_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 19c. investigation_rule edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, ir.id, ir.rule_code, 'derived_from'
FROM (VALUES
     ('HCH12-0016','investigation_rule','IR001'),('HCH12-0007','investigation_rule','IR002'),
     ('HCH12-0004','investigation_rule','IR003'),('HCH12-0004','investigation_rule','IR004'),
     ('HCH12-0016','investigation_rule','IR005'),('HCH12-0018','investigation_rule','IR006'),
     ('HCH12-0018','investigation_rule','IR007'),('HCH12-0018','investigation_rule','IR008'),
     ('HCH12-0018','investigation_rule','IR009'),('HCH2-0006','investigation_rule','IR011'),
     ('HCH2-0006','investigation_rule','IR012'),('HCH2-0006','investigation_rule','IR013'),
     ('HCH12-0007','investigation_rule','IR015')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.investigation_rule ir ON ir.rule_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 19d. investigation_indication edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, ind.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0007','investigation_indication','I005|PUR001|Is there consolidation or an opacity after haemoptysis?'),
     ('HCH12-0004','investigation_indication','I005|PUR006|Baseline chest radiograph for chronic cough (>8 weeks).'),
     ('HCH12-0019','investigation_indication','I005|PUR004|Effusion vs pneumothorax: trachea deviated away from the lesion.'),
     ('HCH12-0018','investigation_indication','I005|PUR001|Does consolidation explain bronchial breath sounds/crackles?'),
     ('HCH12-0004','investigation_indication','I008|PUR006|Baseline spirometry for chronic cough (>8 weeks).'),
     ('HCH12-0004','investigation_indication','I008|PUR004|Is the limitation obstructive or restrictive (FEV1/FVC)?'),
     ('HCH12-0016','investigation_indication','I009|PUR011|Is the patient hypoxic?'),
     ('HCH2-0006','investigation_indication','I001|PUR005|Is there infection/anaemia explaining the presentation?'),
     ('HCH12-0007','investigation_indication','I010|PUR001|Is an infective organism present in the sputum?'),
     ('HCH12-0007','investigation_indication','I011|PUR002|Is TB confirmed by molecular testing?')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.investigation_indication ind
       ON ind.investigation_concept_code || '|' || ind.purpose_code || '|' || ind.clinical_question = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 19e. result_reference_standard edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, rrs.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0006','result_reference_standard','RRS001'),('HCH2-0006','result_reference_standard','RRS002'),
     ('HCH2-0006','result_reference_standard','RRS003'),('HCH2-0006','result_reference_standard','RRS004'),
     ('HCH2-0006','result_reference_standard','RRS005'),('HCH2-0006','result_reference_standard','RRS006'),
     ('HCH2-0006','result_reference_standard','RRS007'),('HCH2-0006','result_reference_standard','RRS008'),
     ('HCH2-0006','result_reference_standard','RRS009'),('HCH2-0006','result_reference_standard','RRS010'),
     ('HCH2-0006','result_reference_standard','RRS011'),('HCH12-0004','result_reference_standard','RRS012'),
     ('HCH12-0016','result_reference_standard','RRS013')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.result_reference_standard rrs ON rrs.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 19f. result_interpretation + result_phenotype_link edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, x.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0016','result_interpretation','RINT_HYPOXAEMIA'),
     ('HCH12-0018','result_interpretation','RINT_CONSOLIDATION'),
     ('HCH12-0019','result_interpretation','RINT_PLEURAL_EFFUSION'),
     ('HCH12-0019','result_interpretation','RINT_PNEUMOTHORAX'),
     ('HCH12-0004','result_interpretation','RINT_OBSTRUCTIVE_SPIROMETRY'),
     ('HCH12-0007','result_interpretation','RINT_MTB_DETECTED'),
     ('HCH2-0006','result_interpretation','RINT_LEUKOCYTOSIS'),
     ('HCH2-0006','result_interpretation','RINT_NEUTROPHILIA'),
     ('HCH12-0019','result_phenotype_link','RINT_PLEURAL_EFFUSION|CNS-PLEURAL-INFLAMMATION'),
     ('HCH12-0018','result_phenotype_link','RINT_CONSOLIDATION|CNS-ALVEOLAR-INFLAMMATION'),
     ('HCH12-0016','result_phenotype_link','RINT_HYPOXAEMIA|CNS-HYPOXAEMIA'),
     ('HCH12-0004','result_phenotype_link','RINT_OBSTRUCTIVE_SPIROMETRY|CNS-AIRWAY-OBSTRUCTION')
) AS v(claim_code, object_type, object_code)
JOIN (
    SELECT id, 'result_interpretation' AS t, code AS obj FROM knowledge.result_interpretation
    UNION ALL
    SELECT id, 'result_phenotype_link' AS t, result_interpretation_code || '|' || associated_concept_code AS obj FROM knowledge.result_phenotype_link
) x ON x.t = v.object_type AND x.obj = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 19g. investigation_source edges (source record counterpart of the concept edges)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, isrc.source_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0006','investigation_source','I001'),('HCH2-0006','investigation_source','I002'),
     ('HCH2-0006','investigation_source','I003'),('HCH2-0006','investigation_source','I004'),
     ('HCH12-0004','investigation_source','I005'),('HCH12-0007','investigation_source','I005'),
     ('HCH12-0019','investigation_source','I005'),('HCH2-0004','investigation_source','I006'),
     ('HCH2-0004','investigation_source','I007'),('HCH12-0004','investigation_source','I008'),
     ('HCH12-0016','investigation_source','I009'),('HCH12-0007','investigation_source','I010'),
     ('HCH12-0007','investigation_source','I011'),('HCH12-0019','investigation_source','I012')
) AS v(claim_code, object_type, object_code) JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
JOIN knowledge.investigation_source isrc ON isrc.investigation_concept_code = v.object_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;