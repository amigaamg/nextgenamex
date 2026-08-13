-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H8 seed zqA: universal differential-reasoning COMPLETION
-- NOTE: named zqA (not zq10) so it sorts AFTER zq1..zq9 in seed.ps1 lexical ordering.
--   zq10 would sort BEFORE zq8/zq9 ('1' < '8'), breaking the RINT_* result_interpretation
--   and other dependencies that this seed consumes from the earlier H-layers.
-- =============================================================================
-- Seeds the H8 completion knowledge layer (migration 033), GROUNDED IN HUTCHISON
-- CLAIMS ONLY. Migration 032 + seed zq9 built the reasoning SKELETON
-- (hypotheses, evidence, rules, weights). This seed builds the SPECS' reasoning
-- CATALOGUE that the CPU uses to structure a clinical interpretation:
--
--   diagnosis_concept           — universal registry of diagnoses (§34)
--   diagnosis_category          — grouping + reasoning level + Box 2.3 process (§4/§45)
--   diagnosis_etiology          — bacterial/viral/cardiac/malignant/... (§4)
--   diagnosis_complication      — separable complication concepts (§4/§44)
--   diagnosis_phenotype         — diagnosis ↔ phenotype relationships (§35)
--   diagnosis_mechanism         — diagnosis ↔ mechanism relationships (§36/§17)
--   diagnostic_expected_evidence — EXPECTED evidence tables (§37/§19/§20)
--   diagnostic_criterion/condition — ALL/ANY/AT_LEAST_N/REQUIRED/... (§23/§24)
--   diagnostic_exclusion        — critical exclusions (§25)
--   clinical_hypothesis_state   — explicit candidate lifecycle CONSIDERED..REJECTED (§22)
--   reasoning_rule/condition/action — IF THEN rules + H3⇄H8 / H7⇄H8 closed loop (§25/§30/§31)
--   differential_evidence_rule  — versioned candidate+proposition→effect (§38/§39)
--   reasoning_version           — what ruleset/knowledge/engine produced this (§39/§40)
--   reasoning_provenance        — claim → reasoning object edges (§45/§46)
--
-- §42 constitutional rule: the CPU (not the UI) computes differential_score and
-- differential_rank. The runtime tables (differential_candidate, differential_score,
-- differential_evidence_ledger, clinical_hypothesis, clinical_uncertainty,
-- clinical_information_gap, information_gap_question, information_gap_investigation,
-- reasoning_run, reasoning_event) stay EMPTY here — they are CPU output, as the
-- H6/H7 precedent established and the H8 test asserts.
--
-- Grounding claims (Hutchison 24e):
--   HCH12-0002  dyspnoea from cardiac disease as well as respiratory
--   HCH12-0004  cough acute <3 wk / chronic >8 wk; CXR + spirometry baseline
--   HCH12-0005  dry cough at night/spasms may be asthma
--   HCH12-0006  sputum colour/consistency/amount
--   HCH12-0007  haemoptysis never dismissed; TB careful evaluation
--   HCH12-0009  pleuritic pain; spontaneous pneumothorax pain worse on breathing
--   HCH12-0010  postnasal drip chronic cough; rhinosinusitis with asthma
--   HCH12-0016  SpO2 normal ≥95%; RR ~14-16 respiratory monitoring
--   HCH12-0017  chest examination: percussion resonance/dullness
--   HCH12-0018  bronchial breath sounds = consolidation; wheezes; crackles
--   HCH12-0019  trachea deviated away → effusion/pneumothorax; towards → fibrosis
--   HCH12-0020  Box 12.5 chronic-cough questions (reflux, night sweats, weight loss)
--   HCH2-0005   Box 2.3 pathological-process framework
--   HCH2-0006   Box 2.4 immediate workup (CBC, CRP, blood cultures)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. diagnosis_category — grouping + reasoning level + Box 2.3 (§4/§34/§45)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnosis_category
    (category_code, label, reasoning_level, pathological_process, description, sort_order, status)
VALUES
    ('DCAT-SYNDROME', 'Syndrome',              'SYNDROME',      'NONE',                      'A symptom/syndrome grouping before disease labeling (§45).',        1,'active'),
    ('DCAT-SYSTEM',   'Organ-system process',   'ORGAN_SYSTEM',  'NONE',                      'The body-system process under consideration (§45).',                2,'active'),
    ('DCAT-MECH',     'Mechanism',              'MECHANISM',     'NONE',                      'The disordered function underlying the phenotype (§17/§45).',       3,'active'),
    ('DCAT-DX-INF',   'Infective/inflammatory disease', 'DISEASE', 'INFECTIVE_INFLAMMATORY',  'Diseases of the Box 2.3 infective/inflammatory class (HCH2-0005).', 4,'active'),
    ('DCAT-DX-VASC',  'Vascular disease',       'DISEASE',       'VASCULAR',                  'Diseases of the Box 2.3 vascular class (HCH2-0005) — e.g. HF. ',    5,'active'),
    ('DCAT-DX-MISC',  'Disease',                'DISEASE',       'NONE',                      'Other diseases (Box 2.3; HCH2-0005).',                              6,'active'),
    ('DCAT-AET',      'Aetiology',              'AETIOLOGY',     'NONE',                      'The causative agent/mechanism class (§4).',                         7,'active'),
    ('DCAT-COMP',     'Complication',           'COMPLICATION',  'NONE',                      'A separable complication of an illness (§4/§44).',                  8,'active'),
    ('DCAT-SEV',      'Severity',               'SEVERITY',      'NONE',                      'Severity state (mild..critical; §4).',                              9,'active')
ON CONFLICT (category_code) DO UPDATE SET
    label = EXCLUDED.label, reasoning_level = EXCLUDED.reasoning_level,
    pathological_process = EXCLUDED.pathological_process, description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 2. diagnosis_concept — universal diagnosis registry (H8 §34)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnosis_concept
    (code, concept_id, concept_code, canonical_name, short_label, description, category_code,
     diagnosis_type, base_weight, applies_to_context_codes, status)
VALUES
    ('DA001', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PNEUMONIA'),'CNS-PNEUMONIA',
     'Pneumonia','Pneumonia','Bacterial/viral lung parenchymal infection; consolidation, fever, acute LRTI pattern (HCH12-0018/0004).',
     'DCAT-DX-INF','DIAGNOSIS',2.00, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','EMERGENCY','INPATIENT','TELEMEDICINE'],'active'),
    ('DA002', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-ACUTE-BRONCHITIS'),'CNS-ACUTE-BRONCHITIS',
     'Acute bronchitis','Acute bronchitis','Self-limiting tracheobronchitis, acute cough <3 weeks (HCH12-0004), purulent sputum (HCH12-0006).',
     'DCAT-DX-INF','DIAGNOSIS',1.00, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','OUTPATIENT','TELEMEDICINE'],'active'),
    ('DA003', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-HEART-FAILURE'),'CNS-HEART-FAILURE',
     'Heart failure','Heart failure','Dyspnoea from cardiac disease (HCH12-0002); crackles (HCH12-0018); congestion with oedema/JVP.',
     'DCAT-DX-VASC','DIAGNOSIS',1.20, ARRAY['ADULT','OLDER_ADULT','INPATIENT','EMERGENCY'],'active'),
    ('DA004', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-TUBERCULOSIS'),'CNS-TUBERCULOSIS',
     'Pulmonary tuberculosis','TB','Chronic granulomatous pulmonary infection; haemoptysis, weight loss, night sweats (HCH12-0007/0020).',
     'DCAT-DX-INF','DIAGNOSIS',1.20, ARRAY['ADULT','OLDER_ADULT','CHILD','INPATIENT','OUTPATIENT','TELEMEDICINE'],'active'),
    ('DA005', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-ASTHMA'),'CNS-ASTHMA',
     'Asthma','Asthma','Variable airway obstruction; dry cough at night/spasms (HCH12-0005), wheeze (HCH12-0018), obstructive spirometry (HCH12-0004).',
     'DCAT-DX-MISC','DIAGNOSIS',1.50, ARRAY['ADULT','OLDER_ADULT','CHILD','OUTPATIENT','TELEMEDICINE'],'active'),
    ('DA006', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-GERD'),'CNS-GERD',
     'Gastro-oesophageal reflux disease','GERD','Acid reflux/indigestion and coughing after meals in chronic cough (Box 12.5, HCH12-0020).',
     'DCAT-DX-MISC','DIAGNOSIS',0.80, ARRAY['ADULT','OLDER_ADULT','OUTPATIENT','TELEMEDICINE'],'active'),
    ('DA007', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PLEURAL-EFFUSION'),'CNS-PLEURAL-EFFUSION',
     'Pleural effusion','Effusion','Fluid in the pleural space; trachea deviated away (HCH12-0019), dull to percussion (HCH12-0017).',
     'DCAT-DX-MISC','DIAGNOSIS',0.60, ARRAY['ADULT','OLDER_ADULT','INPATIENT','EMERGENCY'],'active'),
    ('DA008', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PNEUMOTHORAX'),'CNS-PNEUMOTHORAX',
     'Pneumothorax','Pneumothorax','Air in the pleural space; trachea deviated away (HCH12-0019); pain worse on breathing (HCH12-0009).',
     'DCAT-DX-MISC','DIAGNOSIS',0.60, ARRAY['ADULT','OLDER_ADULT','EMERGENCY','INPATIENT'],'active'),
    ('DA009', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-ALVEOLAR-INFLAMMATION'),'CNS-ALVEOLAR-INFLAMMATION',
     'Alveolar inflammation','Alveolar inflammation','Disordered function underlying consolidation (HCH12-0018) — mechanism.','DCAT-MECH','MECHANISM',1.00,
     ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'],'active'),
    ('DA010', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-AIRWAY-OBSTRUCTION'),'CNS-AIRWAY-OBSTRUCTION',
     'Airway obstruction','Airway obstruction','Disordered function underlying wheeze/obstructive spirometry (HCH12-0018/0004) — mechanism.','DCAT-MECH','MECHANISM',0.80,
     ARRAY['ADULT','OLDER_ADULT','CHILD'],'active'),
    ('DA011', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-RESPIRATORY-FAILURE'),'CNS-RESPIRATORY-FAILURE',
     'Respiratory failure','Respiratory failure','Hypoxaemic respiratory compromise; SpO2 <95% (HCH12-0016) — complication.','DCAT-COMP','COMPLICATION',0.00,
     ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','EMERGENCY','INPATIENT'],'active'),
    ('DA012', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-HYPOXAEMIA'),'CNS-HYPOXAEMIA',
     'Hypoxaemia','Hypoxaemia','Low oxygen saturation <95% (HCH12-0016) — severity/complication state.','DCAT-COMP','COMPLICATION',0.00,
     ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','INPATIENT'],'active')
ON CONFLICT (code) DO UPDATE SET
    concept_id = EXCLUDED.concept_id, concept_code = EXCLUDED.concept_code,
    canonical_name = EXCLUDED.canonical_name, short_label = EXCLUDED.short_label,
    description = EXCLUDED.description, category_code = EXCLUDED.category_code,
    diagnosis_type = EXCLUDED.diagnosis_type, base_weight = EXCLUDED.base_weight,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 3. diagnosis_etiology — the causal dimension, SEPARATE from diagnosis (§4)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnosis_etiology (etiology_code, code, canonical_name, label, description, sort_order, status) VALUES
    ('AET-001','BACTERIAL',    'Bacterial','Bacterial',' Bacterial lung parenchymal infection (S. pneumoniae etc.).',  1,'active'),
    ('AET-002','VIRAL',        'Viral','Viral',' Viral respiratory tract infection (influenza, RSV, SARS-CoV-2).', 2,'active'),
    ('AET-003','MYCOBACTERIAL','Mycobacterial','Mycobacterial',' Mycobacterium tuberculosis infection (HCH12-0007).',    3,'active'),
    ('AET-004','ASPIRATION',   'Aspiration','Aspiration',' Aspiration of oropharyngeal/gastric contents.',              4,'active'),
    ('AET-005','CARDIAC',      'Cardiac','Cardiac',' Cardiac pump dysfunction causing congestion (HCH12-0002).',      5,'active'),
    ('AET-006','MALIGNANT',    'Malignant','Malignant',' Neoplastic process (Box 2.3; invasive chest-wall pain, HCH12-0009).', 6,'active'),
    ('AET-007','REFLUX',       'Gastro-oesophageal reflux','Reflux',' Acid reflux causing cough (Box 12.5, HCH12-0020).',  7,'active')
ON CONFLICT (etiology_code) DO UPDATE SET code = EXCLUDED.code, canonical_name = EXCLUDED.canonical_name,
    label = EXCLUDED.label, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 4. diagnosis_complication — separable complications (§4/§44)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnosis_complication
    (complication_code, concept_id, canonical_name, label, description, is_critical, sort_order, status)
VALUES
    ('DC-001', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-RESPIRATORY-FAILURE'),
     'Respiratory failure','Respiratory failure','Hypoxaemic respiratory compromise (SpO2 <95%, HCH12-0016).',true,  1,'active'),
    ('DC-002', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-HYPOXAEMIA'),
     'Hypoxaemia','Hypoxaemia','Oxygen saturation below 95% — treat as respiratory compromise (HCH12-0016).',true,  2,'active'),
    ('DC-003', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PLEURAL-EFFUSION'),
     'Pleural effusion','Effusion','Fluid collecting in the pleural space (trachea pushed away, HCH12-0019).',false, 3,'active')
ON CONFLICT (complication_code) DO UPDATE SET
    concept_id = EXCLUDED.concept_id, canonical_name = EXCLUDED.canonical_name,
    label = EXCLUDED.label, description = EXCLUDED.description,
    is_critical = EXCLUDED.is_critical, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 5. diagnosis_phenotype — diagnosis ↔ phenotype relationships (H8 §35)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnosis_phenotype
    (diagnosis_code, phenotype_code, relationship, weight, description, evidence_claim_code, is_active)
VALUES
    ('DA001','PHEN-ACUTE-LRTI','STRONGLY_ASSOCIATED',1.20,' Pneumonia typically presents as an acute lower respiratory illness (HCH12-0004).','HCH12-0004',true),
    ('DA001','PHEN-HYPOXAEMIA','COMMONLY_ASSOCIATED',0.80,' Parenchymal consolidation may cause hypoxaemia (HCH12-0016/0018).','HCH12-0018',true),
    ('DA002','PHEN-ACUTE-LRTI','COMMONLY_ASSOCIATED',0.60,' Bronchitis is the archetypal acute LRTI (HCH12-0004).','HCH12-0004',true),
    ('DA003','PHEN-CHF-CONGESTIVE','STRONGLY_ASSOCIATED',1.20,' Cardiac congestion phenotype with crackles/oedema (HCH12-0018).','HCH12-0018',true),
    ('DA003','PHEN-HYPOXAEMIA','COMMONLY_ASSOCIATED',0.60,' Congestive heart failure may cause hypoxaemia (HCH12-0002).','HCH12-0002',true),
    ('DA004','PHEN-CHRONIC-PRODUCTIVE','STRONGLY_ASSOCIATED',1.00,' TB is a chronic productive respiratory illness (Box 12.5, HCH12-0020).','HCH12-0020',true),
    ('DA005','PHEN-AIRWAY-WHEEZE','CHARACTERISTIC',1.30,' Variable airway obstruction with wheeze (HCH12-0018).','HCH12-0018',true),
    ('DA006','PHEN-REFLUX-COUGH','CHARACTERISTIC',1.20,' Reflux-associated cough pattern (Box 12.5, HCH12-0020).','HCH12-0020',true),
    ('DA007','PHEN-HYPOXAEMIA','COMMONLY_ASSOCIATED',0.50,' Effusion restricts ventilation (HCH12-0002).','HCH12-0002',true),
    ('DA008','PHEN-HYPOXAEMIA','COMMONLY_ASSOCIATED',0.60,' Pneumothorax causes acute hypoxaemia (HCH12-0019).','HCH12-0019',true),
    ('DA011','PHEN-RESPIRATORY-FAILURE','CHARACTERISTIC',1.40,' Respiratory failure is the terminal respiratory phenotype (HCH12-0016).','HCH12-0016',true),
    ('DA011','PHEN-HYPOXAEMIA','STRONGLY_ASSOCIATED',1.20,' Hypoxaemia is the defining feature of hypoxaemic respiratory failure (HCH12-0016).','HCH12-0016',true)
ON CONFLICT (diagnosis_code, phenotype_code) DO UPDATE SET
    relationship = EXCLUDED.relationship, weight = EXCLUDED.weight,
    description = EXCLUDED.description, evidence_claim_code = EXCLUDED.evidence_claim_code,
    is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 6. diagnosis_mechanism — diagnosis ↔ mechanism relationships (H8 §36)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnosis_mechanism
    (diagnosis_code, mechanism_code, weight, description, evidence_claim_code, is_active)
VALUES
    ('DA001','MECH-ALVEOLAR-INFLAMMATION',1.20,' Pneumonia is an alveolar inflammatory filling process (HCH12-0018).','HCH12-0018',true),
    ('DA002','MECH-AIRWAY-INFLAMMATION',1.00,' Bronchitis is airway mucosal inflammation (HCH12-0004).','HCH12-0004',true),
    ('DA003','MECH-PULMONARY-CONGESTION',1.20,' Heart failure is pulmonary vascular congestion (HCH12-0018).','HCH12-0018',true),
    ('DA004','MECH-GRANULOMATOUS-INFECTION',1.20,' TB is a chronic granulomatous infection.','HCH12-0007',true),
    ('DA005','MECH-AIRWAY-OBSTRUCTION',1.20,' Asthma is reversible airway obstruction (HCH12-0018).','HCH12-0018',true),
    ('DA006','MECH-GASTROESOPHAGEAL-REFLUX',1.00,' GERD is retrograde acid reflux causing cough (HCH12-0020).','HCH12-0020',true),
    ('DA007','MECH-PLEURAL-INFLAMMATION',0.80,' Effusion commonly follows pleural inflammation (HCH12-0009).','HCH12-0009',true)
ON CONFLICT (diagnosis_code, mechanism_code) DO UPDATE SET
    weight = EXCLUDED.weight, description = EXCLUDED.description,
    evidence_claim_code = EXCLUDED.evidence_claim_code, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 7. diagnostic_expected_evidence — EXPECTED vs OBSERVED (H8 §19/§20/§37)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnostic_expected_evidence
    (diagnosis_code, evidence_type, fact_definition_code, phenotype_code, mechanism_code,
     result_interpretation_code, context_code, expected_strength, what_it_means, evidence_claim_code,
     is_must_not_miss, is_active)
VALUES
    -- Pneumonia
    ('DA001','FACT','FEVER_PRESENT',NULL,NULL,NULL,NULL,'HIGH',     ' Fever supports an infective/inflammatory process (Box 2.3).','HCH2-0006',false,true),
    ('DA001','FACT','COUGH_PRESENT',NULL,NULL,NULL,NULL,'HIGH',     ' Cough is the cardinal respiratory symptom (HCH12-0004).','HCH12-0004',false,true),
    ('DA001','FACT','DYSPNOEA_PRESENT',NULL,NULL,NULL,NULL,'MODERATE',' Dyspnoea reflects ventilatory involvement (HCH12-0002).','HCH12-0002',false,true),
    ('DA001','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'VERY_HIGH',' Bronchial breath sounds directly indicate consolidation.','HCH12-0018',true,true),
    ('DA001','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_CONSOLIDATION',NULL,'VERY_HIGH',' Radiographic consolidation confirms the consolidative process.','HCH12-0018',true,true),
    ('DA001','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_LEUKOCYTOSIS',NULL,'MODERATE',' Leukocytosis supports bacterial infection (Box 2.4).','HCH2-0006',false,true),
    -- Acute bronchitis
    ('DA002','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'HIGH',' Acutely it <3 weeks; >8 weeks is chronic, not bronchitis (HCH12-0004).','HCH12-0004',false,true),
    ('DA002','FACT','COUGH_PRODUCTIVITY',NULL,NULL,NULL,NULL,'MODERATE',' Productive cough in tracheobronchitis (HCH12-0006).','HCH12-0006',false,true),
    ('DA002','FACT','SPUTUM_COLOUR',NULL,NULL,NULL,NULL,'MODERATE',' Purulent yellow/green sputum (HCH12-0006).','HCH12-0006',false,true),
    -- Heart failure
    ('DA003','FACT','ORTHOPNOEA',NULL,NULL,NULL,NULL,'HIGH',' Orthopnoea is a cardiac congestion marker (HCH12-0002).','HCH12-0002',false,true),
    ('DA003','FACT','PND',NULL,NULL,NULL,NULL,'HIGH',' Paroxysmal nocturnal dyspnoea in cardiac congestion (HCH12-0002).','HCH12-0002',false,true),
    ('DA003','FACT','PERIPHERAL_OEDEMA',NULL,NULL,NULL,NULL,'MODERATE',' Peripheral oedema in right-sided congestion (HCH2-0004).','HCH2-0004',false,true),
    ('DA003','FACT','JUGULAR_VENOUS_DISTENTION',NULL,NULL,NULL,NULL,'HIGH',' Elevated JVP indicates congestion (complete exam, HCH2-0004).','HCH2-0004',false,true),
    ('DA003','FACT','CRACKLES',NULL,NULL,NULL,NULL,'MODERATE',' Crackles occur in cardiac failure (HCH12-0018).','HCH12-0018',false,true),
    -- Pulmonary TB
    ('DA004','FACT','BLOOD_IN_SPUTUM',NULL,NULL,NULL,NULL,'VERY_HIGH',' Haemoptysis must never be dismissed without careful evaluation (HCH12-0007).','HCH12-0007',true,true),
    ('DA004','FACT','NIGHT_SWEATS',NULL,NULL,NULL,NULL,'MODERATE',' Fevers/night sweats are chronic-cough questions (Box 12.5).','HCH12-0020',false,true),
    ('DA004','FACT','WEIGHT_LOSS',NULL,NULL,NULL,NULL,'MODERATE',' Weight loss is a chronic-cough red flag (Box 12.5).','HCH12-0020',false,true),
    ('DA004','FACT','TB_CONTACT',NULL,NULL,NULL,NULL,'MODERATE',' TB exposure in the history.','HCH12-0007',false,true),
    ('DA004','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_MTB_DETECTED',NULL,'VERY_HIGH',' Molecular MTB detection confirms TB (HCH12-0007).','HCH12-0007',true,true),
    -- Asthma
    ('DA005','FACT','WHEEZE_PRESENT',NULL,NULL,NULL,NULL,'HIGH',' Wheezes occur in asthma (HCH12-0018).','HCH12-0018',false,true),
    ('DA005','FACT','COUGH_CHARACTER',NULL,NULL,NULL,NULL,'MODERATE',' Dry cough at night/spasms may be asthma (HCH12-0005).','HCH12-0005',false,true),
    ('DA005','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_OBSTRUCTIVE_SPIROMETRY',NULL,'HIGH',' Obstructive limitation on baseline spirometry (HCH12-0004).','HCH12-0004',false,true),
    -- GERD
    ('DA006','FACT','HEARTBURN',NULL,NULL,NULL,NULL,'HIGH',' Acid reflux/indigestion is a key chronic-cough question (Box 12.5).','HCH12-0020',false,true),
    ('DA006','FACT','COUGH_POSITIONAL',NULL,NULL,NULL,NULL,'MODERATE',' Coughing after meals suggests reflux (Box 12.5).','HCH12-0020',false,true),
    -- Pleural effusion
    ('DA007','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_PLEURAL_EFFUSION',NULL,'VERY_HIGH',' Trachea deviated away from the lesion — effusion pushes the mediastinum (HCH12-0019).','HCH12-0019',false,true),
    ('DA007','EXAMINATION_FINDING','RLL_DULLNESS',NULL,NULL,NULL,NULL,'HIGH',' Effusion is dull to percussion (HCH12-0017).','HCH12-0017',false,true),
    -- Pneumothorax
    ('DA008','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_PNEUMOTHORAX',NULL,'VERY_HIGH',' Trachea deviated away from the lesion — pneumothorax (HCH12-0019).','HCH12-0019',true,true),
    ('DA008','FACT','CHEST_PAIN_PRESENT',NULL,NULL,NULL,NULL,'MODERATE',' Pneumothorax pain is worse on breathing (HCH12-0009).','HCH12-0009',false,true),
    ('DA008','FACT','DYSPNOEA_PRESENT',NULL,NULL,NULL,NULL,'HIGH',' Acute dyspnoea in pneumothorax (HCH12-0002).','HCH12-0002',false,true),
    -- Respiratory failure (complication)
    ('DA011','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_HYPOXAEMIA',NULL,'VERY_HIGH',' SpO2 <95% is respiratory compromise (HCH12-0016).','HCH12-0016',true,true),
    -- Hypoxaemia (complication)
    ('DA012','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_HYPOXAEMIA',NULL,'VERY_HIGH',' SpO2 <95% = hypoxaemia (HCH12-0016).','HCH12-0016',true,true)
ON CONFLICT (diagnosis_code, evidence_type, fact_definition_code, phenotype_code, mechanism_code,
            result_interpretation_code, context_code) DO UPDATE SET
    expected_strength = EXCLUDED.expected_strength, what_it_means = EXCLUDED.what_it_means,
    evidence_claim_code = EXCLUDED.evidence_claim_code, is_must_not_miss = EXCLUDED.is_must_not_miss,
    is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 8. diagnostic_criterion + condition — structured confirmation (§23/§24)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnostic_criterion
    (criterion_code, diagnosis_code, criterion_name, logic, min_count, description, diagnostic_standard, evidence_claim_code, is_active)
VALUES
    ('DCRIT001','DA001','Pneumonia — acute LRTI syndrome','AT_LEAST_N',3,
     ' Acute febrile lower respiratory syndrome: fever + cough + dyspnoea (HCH12-0004).',' Acute LRTI syndrome', 'HCH12-0004',true),
    ('DCRIT002','DA001','Pneumonia — consolidative confirmation','REQUIRED',NULL,
     ' Bronchial breath sounds or CXR consolidation confirm the consolidative process.',' Consolidation evidence', 'HCH12-0018',true),
    ('DCRIT003','DA004','TB — molecular confirmation','TEST_REQUIRED',NULL,
     ' Molecular MTB detection confirms pulmonary TB (HCH12-0007).',' Molecular TB confirmation', 'HCH12-0007',true),
    ('DCRIT004','DA004','TB — chronic constitutional syndrome','ALL',NULL,
     ' Chronic cough + weight loss + night sweats (Box 12.5, HCH12-0020).',' Chronic constitutional syndrome', 'HCH12-0020',true),
    ('DCRIT005','DA005','Asthma — obstructive pattern','TEST_REQUIRED',NULL,
     ' Obstructive spirometry (FEV1/FVC <0.70) supports asthma (HCH12-0004).',' Baseline spirometry', 'HCH12-0004',true),
    ('DCRIT006','DA003','Heart failure — congestion syndrome','AT_LEAST_N',2,
     ' At least 2 of: orthopnoea, PND, JVP distention, peripheral oedema (HCH12-0002, HCH2-0004).',' Congestion syndrome', 'HCH12-0002',true),
    ('DCRIT007','DA002','Acute bronchitis — acute cough','TIME_REQUIREMENT',NULL,
     ' Cough duration <21 days (acute <3 weeks, HCH12-0004).',' Duration threshold', 'HCH12-0004',true),
    ('DCRIT008','DA006','GERD — reflux syndrome','ALL',NULL,
     ' Heartburn + cough after meals (Box 12.5, HCH12-0020).',' Reflux syndrome', 'HCH12-0020',true)
ON CONFLICT (criterion_code) DO UPDATE SET
    diagnosis_code = EXCLUDED.diagnosis_code, criterion_name = EXCLUDED.criterion_name,
    logic = EXCLUDED.logic, min_count = EXCLUDED.min_count, description = EXCLUDED.description,
    diagnostic_standard = EXCLUDED.diagnostic_standard, evidence_claim_code = EXCLUDED.evidence_claim_code,
    is_active = EXCLUDED.is_active;

INSERT INTO knowledge.diagnostic_criterion_condition
    (criterion_code, condition_code, evidence_type, fact_definition_code, phenotype_code, mechanism_code,
     result_interpretation_code, context_code, presence, operator, value, rationale, is_active)
VALUES
    ('DCRIT001','DCC001','FACT','FEVER_PRESENT',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Fever required for the acute febrile syndrome.',true),
    ('DCRIT001','DCC002','FACT','COUGH_PRESENT',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Cough required for the acute LRTI syndrome.',true),
    ('DCRIT001','DCC003','FACT','DYSPNOEA_PRESENT',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Dyspnoea required for the lower respiratory syndrome.',true),
    ('DCRIT002','DCC004','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Bronchial breath sounds OR consolidation core evidences.',true),
    ('DCRIT002','DCC005','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_CONSOLIDATION',NULL,'PRESENT',NULL,NULL,' CXR consolidation core evidence.',true),
    ('DCRIT003','DCC006','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_MTB_DETECTED',NULL,'PRESENT',NULL,NULL,' Molecular MTB detection required.',true),
    ('DCRIT004','DCC007','FACT','WEIGHT_LOSS',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Weight loss part of the constitutional syndrome (Box 12.5).',true),
    ('DCRIT004','DCC008','FACT','NIGHT_SWEATS',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Night sweats part of the constitutional syndrome (Box 12.5).',true),
    ('DCRIT004','DCC009','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'PRESENT','>','56',' Chronic cough >8 weeks = 56 days (HCH12-0004).',true),
    ('DCRIT005','DCC010','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_OBSTRUCTIVE_SPIROMETRY',NULL,'PRESENT',NULL,NULL,' Obstructive spirometry required (HCH12-0004).',true),
    ('DCRIT006','DCC011','FACT','ORTHOPNOEA',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Congestion marker 1 (HCH12-0002).',true),
    ('DCRIT006','DCC012','FACT','PND',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Congestion marker 2 (HCH12-0002).',true),
    ('DCRIT006','DCC013','FACT','JUGULAR_VENOUS_DISTENTION',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Congestion marker 3 (HCH2-0004).',true),
    ('DCRIT006','DCC014','FACT','PERIPHERAL_OEDEMA',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Congestion marker 4 (HCH2-0004).',true),
    ('DCRIT007','DCC015','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'PRESENT','<','21',' Acute cough lasts <3 weeks = 21 days (HCH12-0004).',true),
    ('DCRIT008','DCC016','FACT','HEARTBURN',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Heartburn in reflux syndrome (Box 12.5).',true),
    ('DCRIT008','DCC017','FACT','COUGH_POSITIONAL',NULL,NULL,NULL,NULL,'PRESENT',NULL,NULL,' Cough after meals in reflux syndrome (Box 12.5).',true)
ON CONFLICT (criterion_code, condition_code) DO UPDATE SET
    evidence_type = EXCLUDED.evidence_type, fact_definition_code = EXCLUDED.fact_definition_code,
    phenotype_code = EXCLUDED.phenotype_code, mechanism_code = EXCLUDED.mechanism_code,
    result_interpretation_code = EXCLUDED.result_interpretation_code, context_code = EXCLUDED.context_code,
    presence = EXCLUDED.presence, operator = EXCLUDED.operator, value = EXCLUDED.value,
    rationale = EXCLUDED.rationale, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 9. diagnostic_exclusion — critical exclusions (H8 §25)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.diagnostic_exclusion
    (exclusion_code, diagnosis_code, evidence_type, fact_definition_code, phenotype_code, mechanism_code,
     result_interpretation_code, context_code, does_what, rationale, evidence_claim_code, is_active)
VALUES
    ('DEX001','DA002','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'EXCLUDES',
     ' A cough lasting >8 weeks is NOT acute bronchitis (HCH12-0004).','HCH12-0004',true),
    ('DEX002','DA005','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'DEPRIORITIZE',
     ' Bronchial breath sounds indicate consolidation, not reversible asthma (HCH12-0018).','HCH12-0018',true),
    ('DEX003','DA005','FACT','RLL_DULLNESS',NULL,NULL,NULL,NULL,'DEPRIORITIZE',
     ' Pneumothorax is hyper-resonant, not dull to percussion (HCH12-0017).','HCH12-0017',true),
    ('DEX004','DA003','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'DO_NOT_CONFIRM',
     ' Pure bronchial-breath-sound consolidation points to pneumonic consolidation, not HF congestion (HCH12-0018).','HCH12-0018',true)
ON CONFLICT (exclusion_code) DO UPDATE SET
    diagnosis_code = EXCLUDED.diagnosis_code, evidence_type = EXCLUDED.evidence_type,
    fact_definition_code = EXCLUDED.fact_definition_code, phenotype_code = EXCLUDED.phenotype_code,
    mechanism_code = EXCLUDED.mechanism_code, result_interpretation_code = EXCLUDED.result_interpretation_code,
    context_code = EXCLUDED.context_code, does_what = EXCLUDED.does_what, rationale = EXCLUDED.rationale,
    evidence_claim_code = EXCLUDED.evidence_claim_code, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 10. clinical_hypothesis_state — explicit candidate lifecycle (H8 §22)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.clinical_hypothesis_state (state_code, label, description, sort_order, is_terminal, status) VALUES
    ('CONSIDERED',    'Considered',    ' Entered into the differential; not yet weighed.',                    1,  false, 'active'),
    ('SUPPORTED',     'Supported',     ' Evidence supports the hypothesis but others remain.',                2,  false, 'active'),
    ('LEADING',       'Leading',       ' The best-supported hypothesis on current evidence.',                 3,  false, 'active'),
    ('POSSIBLE',      'Possible',      ' Plausible and not refuted, but only weakly supported.',              4,  false, 'active'),
    ('UNLIKELY',      'Unlikely',      ' Little support and/or substantive opposing evidence.',               5,  false, 'active'),
    ('DEPRIORITIZED', 'Deprioritized',' Lowered but not eliminated by an exclusion signal.',                 6,  false, 'active'),
    ('EXCLUDED',      'Excluded',      ' Removed by explicit exclusion evidence/criteria.',                   7,  true,  'active'),
    ('CONFIRMED',     'Confirmed',     ' Meets its diagnostic standard (e.g. molecular TB, HCH12-0007).',     8,  true,  'active'),
    ('REJECTED',      'Rejected',      ' Overturned after being considered.',                                9,  true,  'active')
ON CONFLICT (state_code) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order, is_terminal = EXCLUDED.is_terminal, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 11. reasoning_rule + condition + action — versioned IF/THEN (H8 §25/§30/§31)
--     Including the closed loops: H8 emits gaps/questions (H3) and investigations (H7).
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.reasoning_rule
    (rule_code, trigger_type, trigger_code, target_diagnosis_code, action, weight_delta, message,
     evidence_claim_code, applies_to_context_codes, is_active, status)
VALUES
    ('RR001','FACT','FEVER_PRESENT','DA001','SUPPORT',0.80,
     ' Fever supports an infective/inflammatory process (Box 2.3).','HCH2-0006', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true,'active'),
    ('RR002','FACT','RLL_BRONCHIAL_BREATH_SOUNDS','DA001','STRONGLY_SUPPORT',1.50,
     ' Bronchial breath sounds = consolidation → pneumonia (HCH12-0018).','HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true,'active'),
    ('RR003','RESULT_INTERPRETATION','RINT_CONSOLIDATION','DA001','STRONGLY_SUPPORT',2.00,
     ' CXR consolidation confirms the consolidative process (HCH12-0018).','HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true,'active'),
    ('RR004','FACT','BLOOD_IN_SPUTUM','DA004','MARK_CRITICAL',1.00,
     ' Haemoptysis must never be dismissed without careful evaluation — keeps TB critical (HCH12-0007).','HCH12-0007', ARRAY['ADULT','OLDER_ADULT','CHILD','INPATIENT','OUTPATIENT'], true,'active'),
    ('RR005','RESULT_INTERPRETATION','RINT_MTB_DETECTED','DA004','STRONGLY_SUPPORT',2.50,
     ' Molecular detection of MTB confirms pulmonary TB (HCH12-0007).','HCH12-0007', ARRAY['ADULT','OLDER_ADULT'], true,'active'),
    ('RR006','FACT','WHEEZE_PRESENT','DA005','SUPPORT',1.20,
     ' Wheezes occur in asthma (HCH12-0018).','HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true,'active'),
    ('RR007','RESULT_INTERPRETATION','RINT_OBSTRUCTIVE_SPIROMETRY','DA005','STRONGLY_SUPPORT',1.50,
     ' Obstructive spirometry (FEV1/FVC <0.70) → asthmatic/obstructive pattern (HCH12-0004).','HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true,'active'),
    ('RR008','FACT','ORTHOPNOEA','DA003','SUPPORT',1.00,
     ' Orthopnoea is a cardiac congestion marker (HCH12-0002).','HCH12-0002', ARRAY['ADULT','OLDER_ADULT','INPATIENT','EMERGENCY'], true,'active'),
    ('RR009','CONTEXT','OLDER_ADULT','DA003','ACTIVATE',0.50,
     ' Cardiac disease is an important cause of dyspnoea in the older adult (HCH12-0002).','HCH12-0002', ARRAY['OLDER_ADULT','INPATIENT','EMERGENCY'], true,'active'),
    ('RR010','FACT','COUGH_DURATION_DAYS','DA002','DEPRIORITIZE',-0.80,
     ' A cough lasting >8 weeks is NOT acute bronchitis (HCH12-0004). (Guarded: >56 days.)','HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true,'active'),
    ('RR011','FACT','HEARTBURN','DA006','SUPPORT',1.00,
     ' Acid reflux is a key chronic-cough question (Box 12.5, HCH12-0020).','HCH12-0020', ARRAY['ADULT','OLDER_ADULT','OUTPATIENT'], true,'active'),
    ('RR012','RESULT_INTERPRETATION','RINT_PNEUMOTHORAX','DA008','MARK_CRITICAL',2.00,
     ' Trachea deviated away → pneumothorax needs urgent imaging (HCH12-0019).','HCH12-0019', ARRAY['ADULT','OLDER_ADULT','EMERGENCY','INPATIENT'], true,'active'),
    ('RR013','RESULT_INTERPRETATION','RINT_HYPOXAEMIA','DA011','STRONGLY_SUPPORT',2.00,
     ' SpO2 <95% = hypoxaemic respiratory compromise (HCH12-0016).','HCH12-0016', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','EMERGENCY','INPATIENT'], true,'active'),
    ('RR014','RESULT_INTERPRETATION','RINT_HYPOXAEMIA','DA012','STRONGLY_SUPPORT',2.00,
     ' SpO2 <95% = hypoxaemia (HCH12-0016).','HCH12-0016', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','INPATIENT'], true,'active')
ON CONFLICT (rule_code) DO UPDATE SET
    trigger_type = EXCLUDED.trigger_type, trigger_code = EXCLUDED.trigger_code,
    target_diagnosis_code = EXCLUDED.target_diagnosis_code, action = EXCLUDED.action,
    weight_delta = EXCLUDED.weight_delta, message = EXCLUDED.message,
    evidence_claim_code = EXCLUDED.evidence_claim_code,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes, is_active = EXCLUDED.is_active,
    status = EXCLUDED.status;

INSERT INTO knowledge.reasoning_rule_condition
    (rule_code, condition_code, evidence_type, fact_definition_code, phenotype_code, mechanism_code,
     result_interpretation_code, context_code, operator, value, rationale, is_active)
VALUES
    ('RR010','RRC001','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'>','56',' Chronic cough = duration >8 weeks = 56 days (HCH12-0004).',true)
ON CONFLICT (rule_code, condition_code) DO UPDATE SET
    evidence_type = EXCLUDED.evidence_type, fact_definition_code = EXCLUDED.fact_definition_code,
    phenotype_code = EXCLUDED.phenotype_code, mechanism_code = EXCLUDED.mechanism_code,
    result_interpretation_code = EXCLUDED.result_interpretation_code, context_code = EXCLUDED.context_code,
    operator = EXCLUDED.operator, value = EXCLUDED.value, rationale = EXCLUDED.rationale,
    is_active = EXCLUDED.is_active;

-- reasoning_rule_action — the H8⇄H7 / H8⇄H3 closed loop (§29/§30/§31)
INSERT INTO knowledge.reasoning_rule_action (rule_code, action_type, question_code, investigation_code, message, sort_order, is_active) VALUES
    ('RR004','TRIGGER_INVESTIGATION','','I005',' Haemoptysis → at least a baseline chest X-ray (HCH12-0004/0007).',1,true),
    ('RR004','TRIGGER_INVESTIGATION','','I011',' Haemoptysis/TB risk → sputum TB molecular test (HCH12-0007).',2,true),
    ('RR004','CREATE_QUESTION_GAP','TB_CONTACT','',' TB exposure needs to be asked to weigh TB (HCH12-0007).',3,true),
    ('RR007','CREATE_QUESTION_GAP','WHEEZE_PRESENT','',' Wheeze status needed to weigh obstructive causes (HCH12-0018).',1,true),
    ('RR010','TRIGGER_INVESTIGATION','','I005',' Chronic cough → baseline CXR (HCH12-0004).',1,true),
    ('RR010','TRIGGER_INVESTIGATION','','I008',' Chronic cough → baseline spirometry (HCH12-0004).',2,true),
    ('RR003','CREATE_QUESTION_GAP','COUGH_PRESENT','',' Pneumonia needs cough in the working profile (HCH12-0004).',1,true),
    ('RR013','ESCALATE','','',' Hypoxaemia is a safety signal — escalate respiratory monitoring (HCH12-0016).',1,true)
ON CONFLICT (rule_code, action_type, question_code, investigation_code) DO UPDATE SET
    message = EXCLUDED.message, sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

-- ---------------------------------------------------------------------------
-- 12. differential_evidence_rule — versioned candidate+proposition→effect (§38/§39)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_evidence_rule
    (evidence_rule_code, diagnosis_code, evidence_type, fact_definition_code, phenotype_code, mechanism_code,
     result_interpretation_code, context_code, relationship, base_strength, operator, value, rationale, evidence_claim_code,
     rule_version, effective_from, status)
VALUES
    ('DEV-001','DA001','FACT','FEVER_PRESENT',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' Fever supports an infective/inflammatory disease (Box 2.3).','HCH2-0006',1,'2018-01-01','active'),
    ('DEV-002','DA001','FACT','COUGH_PRESENT',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' Cough is cardinal in pneumonia (HCH12-0004).','HCH12-0004',1,'2018-01-01','active'),
    ('DEV-003','DA001','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'STRONGLY_SUPPORTS',1.50,NULL,NULL,
     ' Bronchial breath sounds indicate consolidation (HCH12-0018).','HCH12-0018',1,'2018-01-01','active'),
    ('DEV-004','DA001','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_CONSOLIDATION',NULL,'STRONGLY_SUPPORTS',2.00,NULL,NULL,
     ' CXR consolidation is the consolidative marker (HCH12-0018).','HCH12-0018',1,'2018-01-01','active'),
    ('DEV-005','DA001','ABSENCE','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'WEAKLY_OPPOSES',0.30,NULL,NULL,
     ' Absence of consolidation signs weakens—but never eliminates—pneumonia (four-state rule, §11).','HCH12-0018',1,'2018-01-01','active'),
    ('DEV-006','DA002','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'SUPPORTS',0.60,'<','21',
     ' Acute cough (<3 weeks = <21 days) fits acute bronchitis (HCH12-0004).','HCH12-0004',1,'2018-01-01','active'),
    ('DEV-007','DA002','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,'OPPOSES',0.80,'>','56',
     ' Chronic cough (>8 weeks = >56 days) opposes acute bronchitis (HCH12-0004).','HCH12-0004',1,'2018-01-01','active'),
    ('DEV-008','DA002','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'OPPOSES',1.00,NULL,NULL,
     ' Consolidation points to pneumonia, not simple bronchitis (HCH12-0018).','HCH12-0018',1,'2018-01-01','active'),
    ('DEV-009','DA003','FACT','ORTHOPNOEA',NULL,NULL,NULL,NULL,'SUPPORTS',1.00,NULL,NULL,
     ' Orthopnoea indicates cardiac congestion (HCH12-0002).','HCH12-0002',1,'2018-01-01','active'),
    ('DEV-010','DA003','FACT','PND',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' PND in cardiac congestion (HCH12-0002).','HCH12-0002',1,'2018-01-01','active'),
    ('DEV-011','DA003','FACT','PERIPHERAL_OEDEMA',NULL,NULL,NULL,NULL,'SUPPORTS',0.60,NULL,NULL,
     ' Peripheral oedema in congestion (HCH2-0004).','HCH2-0004',1,'2018-01-01','active'),
    ('DEV-012','DA004','FACT','BLOOD_IN_SPUTUM',NULL,NULL,NULL,NULL,'STRONGLY_SUPPORTS',1.50,NULL,NULL,
     ' Haemoptysis requires careful TB evaluation (HCH12-0007).','HCH12-0007',1,'2018-01-01','active'),
    ('DEV-013','DA004','FACT','NIGHT_SWEATS',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' Night sweats are a TB-compatible constitutional feature (Box 12.5).','HCH12-0020',1,'2018-01-01','active'),
    ('DEV-014','DA004','FACT','WEIGHT_LOSS',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' Weight loss is a TB-compatible red flag (Box 12.5).','HCH12-0020',1,'2018-01-01','active'),
    ('DEV-015','DA004','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_MTB_DETECTED',NULL,'STRONGLY_SUPPORTS',2.50,NULL,NULL,
     ' Molecular MTB detection confirms TB (HCH12-0007).','HCH12-0007',1,'2018-01-01','active'),
    ('DEV-016','DA005','FACT','WHEEZE_PRESENT',NULL,NULL,NULL,NULL,'STRONGLY_SUPPORTS',1.20,NULL,NULL,
     ' Wheezes in asthma (HCH12-0018).','HCH12-0018',1,'2018-01-01','active'),
    ('DEV-017','DA005','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_OBSTRUCTIVE_SPIROMETRY',NULL,'STRONGLY_SUPPORTS',1.50,NULL,NULL,
     ' Obstructive spirometry supports asthma (HCH12-0004).','HCH12-0004',1,'2018-01-01','active'),
    ('DEV-018','DA005','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,'OPPOSES',0.80,NULL,NULL,
     ' Consolidation is not reversible asthma (HCH12-0018).','HCH12-0018',1,'2018-01-01','active'),
    ('DEV-019','DA006','FACT','HEARTBURN',NULL,NULL,NULL,NULL,'STRONGLY_SUPPORTS',1.00,NULL,NULL,
     ' Reflux in chronic cough (Box 12.5, HCH12-0020).','HCH12-0020',1,'2018-01-01','active'),
    ('DEV-020','DA006','FACT','COUGH_POSITIONAL',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' Cough after meals suggests reflux (Box 12.5).','HCH12-0020',1,'2018-01-01','active'),
    ('DEV-021','DA007','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_PLEURAL_EFFUSION',NULL,'STRONGLY_SUPPORTS',2.00,NULL,NULL,
     ' Trachea deviated away → effusion (HCH12-0019).','HCH12-0019',1,'2018-01-01','active'),
    ('DEV-022','DA007','EXAMINATION_FINDING','RLL_DULLNESS',NULL,NULL,NULL,NULL,'SUPPORTS',0.80,NULL,NULL,
     ' Effusion dull to percussion (HCH12-0017).','HCH12-0017',1,'2018-01-01','active'),
    ('DEV-023','DA008','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_PNEUMOTHORAX',NULL,'STRONGLY_SUPPORTS',2.00,NULL,NULL,
     ' Trachea deviated away → pneumothorax (HCH12-0019).','HCH12-0019',1,'2018-01-01','active'),
    ('DEV-024','DA008','EXAMINATION_FINDING','RLL_DULLNESS',NULL,NULL,NULL,NULL,'OPPOSES',0.80,NULL,NULL,
     ' Pneumothorax is hyper-resonant, not dull (HCH12-0017).','HCH12-0017',1,'2018-01-01','active'),
    ('DEV-025','DA011','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_HYPOXAEMIA',NULL,'STRONGLY_SUPPORTS',2.00,NULL,NULL,
     ' SpO2 <95% = respiratory failure risk (HCH12-0016).','HCH12-0016',1,'2018-01-01','active')
ON CONFLICT (evidence_rule_code) DO UPDATE SET
    diagnosis_code = EXCLUDED.diagnosis_code, evidence_type = EXCLUDED.evidence_type,
    fact_definition_code = EXCLUDED.fact_definition_code, phenotype_code = EXCLUDED.phenotype_code,
    mechanism_code = EXCLUDED.mechanism_code, result_interpretation_code = EXCLUDED.result_interpretation_code,
    context_code = EXCLUDED.context_code, relationship = EXCLUDED.relationship,
    base_strength = EXCLUDED.base_strength, operator = EXCLUDED.operator, value = EXCLUDED.value,
    rationale = EXCLUDED.rationale, evidence_claim_code = EXCLUDED.evidence_claim_code,
    rule_version = EXCLUDED.rule_version, effective_from = EXCLUDED.effective_from, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 13. reasoning_version — version registry (§39/§40)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.reasoning_version
    (version_code, ruleset_version, knowledge_version, engine_version, effective_from, change_note, status)
VALUES
    ('RV2024.01.001','H8-RULESET-1.0','HUTCHISON_24_2018','CLINICAL-CPU-1.0','2024-01-01',
     ' H8 completion knowledge compiled from Hutchison Clinical Methods 24e.','active')
ON CONFLICT (version_code) DO UPDATE SET
    ruleset_version = EXCLUDED.ruleset_version, knowledge_version = EXCLUDED.knowledge_version,
    engine_version = EXCLUDED.engine_version, effective_from = EXCLUDED.effective_from,
    change_note = EXCLUDED.change_note, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- 14. reasoning_provenance — claim → reasoning knowledge edges (H8 §45/§46)
-- ---------------------------------------------------------------------------
-- 14a. diagnosis_concept edges
INSERT INTO knowledge.reasoning_provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, dc.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0018','diagnosis_concept','DA001'),('HCH12-0004','diagnosis_concept','DA002'),
     ('HCH12-0002','diagnosis_concept','DA003'),('HCH12-0007','diagnosis_concept','DA004'),
     ('HCH12-0005','diagnosis_concept','DA005'),('HCH12-0020','diagnosis_concept','DA006'),
     ('HCH12-0019','diagnosis_concept','DA007'),('HCH12-0019','diagnosis_concept','DA008'),
     ('HCH12-0018','diagnosis_concept','DA009'),('HCH12-0018','diagnosis_concept','DA010'),
     ('HCH12-0016','diagnosis_concept','DA011'),('HCH12-0016','diagnosis_concept','DA012')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.diagnosis_concept dc ON dc.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 14b. diagnosis_phenotype + diagnosis_mechanism edges
INSERT INTO knowledge.reasoning_provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, x.obj_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0004','diagnosis_phenotype','DA001|PHEN-ACUTE-LRTI'),
     ('HCH12-0018','diagnosis_phenotype','DA001|PHEN-HYPOXAEMIA'),
     ('HCH12-0004','diagnosis_phenotype','DA002|PHEN-ACUTE-LRTI'),
     ('HCH12-0018','diagnosis_phenotype','DA003|PHEN-CHF-CONGESTIVE'),
     ('HCH12-0002','diagnosis_phenotype','DA003|PHEN-HYPOXAEMIA'),
     ('HCH12-0020','diagnosis_phenotype','DA004|PHEN-CHRONIC-PRODUCTIVE'),
     ('HCH12-0018','diagnosis_phenotype','DA005|PHEN-AIRWAY-WHEEZE'),
     ('HCH12-0020','diagnosis_phenotype','DA006|PHEN-REFLUX-COUGH'),
     ('HCH12-0002','diagnosis_phenotype','DA007|PHEN-HYPOXAEMIA'),
     ('HCH12-0019','diagnosis_phenotype','DA008|PHEN-HYPOXAEMIA'),
     ('HCH12-0016','diagnosis_phenotype','DA011|PHEN-RESPIRATORY-FAILURE'),
     ('HCH12-0016','diagnosis_phenotype','DA011|PHEN-HYPOXAEMIA'),
     ('HCH12-0018','diagnosis_mechanism','DA001|MECH-ALVEOLAR-INFLAMMATION'),
     ('HCH12-0004','diagnosis_mechanism','DA002|MECH-AIRWAY-INFLAMMATION'),
     ('HCH12-0018','diagnosis_mechanism','DA003|MECH-PULMONARY-CONGESTION'),
     ('HCH12-0007','diagnosis_mechanism','DA004|MECH-GRANULOMATOUS-INFECTION'),
     ('HCH12-0018','diagnosis_mechanism','DA005|MECH-AIRWAY-OBSTRUCTION'),
     ('HCH12-0020','diagnosis_mechanism','DA006|MECH-GASTROESOPHAGEAL-REFLUX'),
     ('HCH12-0009','diagnosis_mechanism','DA007|MECH-PLEURAL-INFLAMMATION')
) AS v(claim_code, object_type, object_code)
JOIN (
    SELECT dph.id AS obj_id, 'diagnosis_phenotype' AS t, dph.diagnosis_code || '|' || dph.phenotype_code AS obj FROM knowledge.diagnosis_phenotype dph
    UNION ALL
    SELECT dme.id AS obj_id, 'diagnosis_mechanism' AS t, dme.diagnosis_code || '|' || dme.mechanism_code AS obj FROM knowledge.diagnosis_mechanism dme
) x ON x.t = v.object_type AND x.obj = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 14c. diagnostic_expected_evidence edges
INSERT INTO knowledge.reasoning_provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, dee.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0006','diagnostic_expected_evidence','DA001|FACT|FEVER_PRESENT'),
     ('HCH12-0004','diagnostic_expected_evidence','DA001|FACT|COUGH_PRESENT'),
     ('HCH12-0002','diagnostic_expected_evidence','DA001|FACT|DYSPNOEA_PRESENT'),
     ('HCH12-0018','diagnostic_expected_evidence','DA001|EXAMINATION_FINDING|RLL_BRONCHIAL_BREATH_SOUNDS'),
     ('HCH12-0018','diagnostic_expected_evidence','DA001|RESULT_INTERPRETATION|RINT_CONSOLIDATION'),
     ('HCH2-0006','diagnostic_expected_evidence','DA001|RESULT_INTERPRETATION|RINT_LEUKOCYTOSIS'),
     ('HCH12-0004','diagnostic_expected_evidence','DA002|FACT|COUGH_DURATION_DAYS'),
     ('HCH12-0006','diagnostic_expected_evidence','DA002|FACT|COUGH_PRODUCTIVITY'),
     ('HCH12-0006','diagnostic_expected_evidence','DA002|FACT|SPUTUM_COLOUR'),
     ('HCH12-0002','diagnostic_expected_evidence','DA003|FACT|ORTHOPNOEA'),
     ('HCH12-0002','diagnostic_expected_evidence','DA003|FACT|PND'),
     ('HCH2-0004','diagnostic_expected_evidence','DA003|FACT|PERIPHERAL_OEDEMA'),
     ('HCH2-0004','diagnostic_expected_evidence','DA003|FACT|JUGULAR_VENOUS_DISTENTION'),
     ('HCH12-0018','diagnostic_expected_evidence','DA003|FACT|CRACKLES'),
     ('HCH12-0007','diagnostic_expected_evidence','DA004|FACT|BLOOD_IN_SPUTUM'),
     ('HCH12-0020','diagnostic_expected_evidence','DA004|FACT|NIGHT_SWEATS'),
     ('HCH12-0020','diagnostic_expected_evidence','DA004|FACT|WEIGHT_LOSS'),
     ('HCH12-0007','diagnostic_expected_evidence','DA004|FACT|TB_CONTACT'),
     ('HCH12-0007','diagnostic_expected_evidence','DA004|RESULT_INTERPRETATION|RINT_MTB_DETECTED'),
     ('HCH12-0018','diagnostic_expected_evidence','DA005|FACT|WHEEZE_PRESENT'),
     ('HCH12-0005','diagnostic_expected_evidence','DA005|FACT|COUGH_CHARACTER'),
     ('HCH12-0004','diagnostic_expected_evidence','DA005|RESULT_INTERPRETATION|RINT_OBSTRUCTIVE_SPIROMETRY'),
     ('HCH12-0020','diagnostic_expected_evidence','DA006|FACT|HEARTBURN'),
     ('HCH12-0020','diagnostic_expected_evidence','DA006|FACT|COUGH_POSITIONAL'),
     ('HCH12-0019','diagnostic_expected_evidence','DA007|RESULT_INTERPRETATION|RINT_PLEURAL_EFFUSION'),
     ('HCH12-0017','diagnostic_expected_evidence','DA007|EXAMINATION_FINDING|RLL_DULLNESS'),
     ('HCH12-0019','diagnostic_expected_evidence','DA008|RESULT_INTERPRETATION|RINT_PNEUMOTHORAX'),
     ('HCH12-0009','diagnostic_expected_evidence','DA008|FACT|CHEST_PAIN_PRESENT'),
     ('HCH12-0002','diagnostic_expected_evidence','DA008|FACT|DYSPNOEA_PRESENT'),
     ('HCH12-0016','diagnostic_expected_evidence','DA011|RESULT_INTERPRETATION|RINT_HYPOXAEMIA'),
     ('HCH12-0016','diagnostic_expected_evidence','DA012|RESULT_INTERPRETATION|RINT_HYPOXAEMIA')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.diagnostic_expected_evidence dee
       ON dee.diagnosis_code || '|' || dee.evidence_type || '|' || COALESCE(dee.fact_definition_code, dee.result_interpretation_code) = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 14d. diagnostic_criterion + criterion_condition + exclusion edges
INSERT INTO knowledge.reasoning_provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, x.obj_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0004','diagnostic_criterion','DCRIT001'),
     ('HCH12-0018','diagnostic_criterion','DCRIT002'),
     ('HCH12-0007','diagnostic_criterion','DCRIT003'),
     ('HCH12-0020','diagnostic_criterion','DCRIT004'),
     ('HCH12-0004','diagnostic_criterion','DCRIT005'),
     ('HCH12-0002','diagnostic_criterion','DCRIT006'),
     ('HCH12-0004','diagnostic_criterion','DCRIT007'),
     ('HCH12-0020','diagnostic_criterion','DCRIT008'),
     ('HCH12-0004','diagnostic_exclusion','DEX001'),
     ('HCH12-0018','diagnostic_exclusion','DEX002'),
     ('HCH12-0017','diagnostic_exclusion','DEX003'),
     ('HCH12-0018','diagnostic_exclusion','DEX004')
) AS v(claim_code, object_type, object_code)
JOIN (
    SELECT dcr.criterion_id AS obj_id, 'diagnostic_criterion' AS t, dcr.criterion_code AS obj FROM knowledge.diagnostic_criterion dcr
    UNION ALL
    SELECT dx.exclusion_id AS obj_id, 'diagnostic_exclusion' AS t, dx.exclusion_code AS obj FROM knowledge.diagnostic_exclusion dx
) x ON x.t = v.object_type AND x.obj = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

INSERT INTO knowledge.reasoning_provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, dcc.condition_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0004','diagnostic_criterion_condition','DCC001'),('HCH12-0004','diagnostic_criterion_condition','DCC002'),
     ('HCH12-0004','diagnostic_criterion_condition','DCC003'),('HCH12-0018','diagnostic_criterion_condition','DCC004'),
     ('HCH12-0018','diagnostic_criterion_condition','DCC005'),('HCH12-0007','diagnostic_criterion_condition','DCC006'),
     ('HCH12-0020','diagnostic_criterion_condition','DCC007'),('HCH12-0020','diagnostic_criterion_condition','DCC008'),
     ('HCH12-0004','diagnostic_criterion_condition','DCC009'),('HCH12-0004','diagnostic_criterion_condition','DCC010'),
     ('HCH12-0002','diagnostic_criterion_condition','DCC011'),('HCH12-0002','diagnostic_criterion_condition','DCC012'),
     ('HCH2-0004','diagnostic_criterion_condition','DCC013'),('HCH2-0004','diagnostic_criterion_condition','DCC014'),
     ('HCH12-0004','diagnostic_criterion_condition','DCC015'),('HCH12-0020','diagnostic_criterion_condition','DCC016'),
     ('HCH12-0020','diagnostic_criterion_condition','DCC017')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.diagnostic_criterion_condition dcc ON dcc.condition_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;

-- 14e. reasoning_rule (+ actions) + differential_evidence_rule edges
INSERT INTO knowledge.reasoning_provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, x.obj_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0006','reasoning_rule','RR001'),('HCH12-0018','reasoning_rule','RR002'),
     ('HCH12-0018','reasoning_rule','RR003'),('HCH12-0007','reasoning_rule','RR004'),
     ('HCH12-0007','reasoning_rule','RR005'),('HCH12-0018','reasoning_rule','RR006'),
     ('HCH12-0004','reasoning_rule','RR007'),('HCH12-0002','reasoning_rule','RR008'),
     ('HCH12-0002','reasoning_rule','RR009'),('HCH12-0004','reasoning_rule','RR010'),
     ('HCH12-0020','reasoning_rule','RR011'),('HCH12-0019','reasoning_rule','RR012'),
     ('HCH12-0016','reasoning_rule','RR013'),('HCH12-0016','reasoning_rule','RR014'),
     ('HCH2-0006','differential_evidence_rule','DEV-001'),('HCH12-0004','differential_evidence_rule','DEV-002'),
     ('HCH12-0018','differential_evidence_rule','DEV-003'),('HCH12-0018','differential_evidence_rule','DEV-004'),
     ('HCH12-0018','differential_evidence_rule','DEV-005'),('HCH12-0004','differential_evidence_rule','DEV-006'),
     ('HCH12-0004','differential_evidence_rule','DEV-007'),('HCH12-0018','differential_evidence_rule','DEV-008'),
     ('HCH12-0002','differential_evidence_rule','DEV-009'),('HCH12-0002','differential_evidence_rule','DEV-010'),
     ('HCH2-0004','differential_evidence_rule','DEV-011'),('HCH12-0007','differential_evidence_rule','DEV-012'),
     ('HCH12-0020','differential_evidence_rule','DEV-013'),('HCH12-0020','differential_evidence_rule','DEV-014'),
     ('HCH12-0007','differential_evidence_rule','DEV-015'),('HCH12-0018','differential_evidence_rule','DEV-016'),
     ('HCH12-0004','differential_evidence_rule','DEV-017'),('HCH12-0018','differential_evidence_rule','DEV-018'),
     ('HCH12-0020','differential_evidence_rule','DEV-019'),('HCH12-0020','differential_evidence_rule','DEV-020'),
     ('HCH12-0019','differential_evidence_rule','DEV-021'),('HCH12-0017','differential_evidence_rule','DEV-022'),
     ('HCH12-0019','differential_evidence_rule','DEV-023'),('HCH12-0017','differential_evidence_rule','DEV-024'),
     ('HCH12-0016','differential_evidence_rule','DEV-025')
) AS v(claim_code, object_type, object_code)
JOIN (
    SELECT rr.id AS obj_id, 'reasoning_rule' AS t, rr.rule_code AS obj FROM knowledge.reasoning_rule rr
    UNION ALL
    SELECT dv.id AS obj_id, 'differential_evidence_rule' AS t, dv.evidence_rule_code AS obj FROM knowledge.differential_evidence_rule dv
) x ON x.t = v.object_type AND x.obj = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;