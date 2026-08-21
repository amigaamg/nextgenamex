-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H8 seed zq9: universal differential-reasoning interface
-- =============================================================================
-- Seeds the H8 differential-reasoning knowledge base, GROUNDED IN HUTCHISON CLAIMS ONLY.
-- H8 answers: "WHAT does ALL the collected information collectively MEAN?"
--             "WHICH hypotheses are supported, by WHICH evidence, and WHY?"
--
-- Architectural law (H8), encoded as DATA:
--   HYPOTHESIS ≠ EVIDENCE ≠ WEIGHT ≠ RANK.
--   HYPOTHESIS = a candidate explanation, tied to a CONCEPT (condition or
--                mechanism) — never a raw symptom (H8 §1/§2).
--   EVIDENCE   = a fact/phenotype/mechanism/result-interpretation that
--                SUPPORTS or REFUTES a hypothesis, with a weight.
--   WEIGHT     = versioned multi-dimension scoring model (H8 §21).
--   RULE       = data-driven evidence→hypothesis activation (H8 §11).
--   RANK/REASON= runtime output (created-but-EMPTY per H6/H7 precedent).
--
-- Grounding claims (Hutchison 24e / CH12 respiratory + CH2 general):
--   HCH12-0002  dyspnoea may be due to CARDIAC disease as well as primary respiratory
--   HCH12-0004  cough acute <3wk / chronic >8wk; haemoptysis → baseline CXR;
--               chronic cough → baseline CXR + spirometry
--   HCH12-0005  cough discussion: dry cough at night/spasms may be ASTHMA
--   HCH12-0006  sputum: yellow/green purulent; a cupful daily → bronchiectasis
--   HCH12-0007  haemoptysis never dismissed without careful evaluation (TB/neoplasm)
--   HCH12-0009  pleuritic pain = pleura inflamed; spontaneous PNEUMOTHORAX pain
--               worse on breathing
--   HCH12-0010  postnasal drip = common cause of chronic cough; rhinosinusitis
--               coexists with asthma
--   HCH12-0016  SpO2 normal ≥95%; RR ~14-16; respiratory monitoring
--   HCH12-0018  bronchial breath sounds = CONSOLIDATION; wheezes in asthma/COPD/
--               infection/cardiac failure; crackles in fibrosis/cardiac failure/COPD;
--               coarse crackles → bronchiectasis; fine late-inspiratory → fibrosis
--   HCH12-0019  trachea deviated AWAY → PLEURAL EFFUSION / PNEUMOTHORAX (pushed);
--               deviated TOWARDS → fibrosis/collapse (pulled)
--   HCH12-0020  Box 12.5 chronic cough: acid reflux/indigestion (GERD), nocturnal
--               cough, fevers/night sweats, weight loss, coughed blood
--   HCH2-0005   Box 2.3 pathological-process framework (the skeleton of the differential)
--   HCH2-0006   Box 2.4 immediate workup (CBC, CRP, blood cultures)
--
-- New objects seeded here:
--   knowledge.differential_hypothesis  NEW (DH001..DH010 — candidate explanations)
--   knowledge.differential_evidence    NEW (EV001.. — SUPPORTS/REFUTES with weight)
--   knowledge.differential_rule        NEW (DR001.. — evidence→hypothesis activation)
--   knowledge.differential_rule_condition NEW (value guards)
--   knowledge.differential_weight      NEW (10-dimension scoring model, H8 §21)
--   knowledge.differential_source      NEW (provenance → HUTCHISON_24_2018)
--   knowledge.differential_version     NEW (temporal versioning)
--   knowledge.differential_status      NEW (reasoning lifecycle)
--   knowledge.concept                  NEW (CNS-PLEURAL-EFFUSION, CNS-PNEUMOTHORAX)
-- Runtime tables (differential_rank, differential_reason) remain EMPTY per H6/H7 precedent.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. New concepts required by H8 hypotheses (grounded HCH12-0019)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, description) VALUES
    ('f0a00000-0000-0000-0000-00000000004a', 'CNS-PLEURAL-EFFUSION', 'condition',
     'Pleural effusion', 'Pleural effusion', 'Fluid in the pleural space; trachea deviated away from the affected side (mediastinum pushed, HCH12-0019).'),
    ('f0a00000-0000-0000-0000-00000000004b', 'CNS-PNEUMOTHORAX', 'condition',
     'Pneumothorax', 'Pneumothorax', 'Air in the pleural space; trachea deviated away from the affected side (mediastinum pushed, HCH12-0019).')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. differential_status — reasoning lifecycle (H8 §12)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_status (status_code, label, description, sort_order, is_terminal, status) VALUES
    ('PENDING',           'Pending',           ' Hypothesis proposed; evidence not yet weighed.',  1, false, 'active'),
    ('ACTIVE',            'Active',            ' Currently under active differential consideration.',2, false, 'active'),
    ('REFINED',           'Refined',           ' Evidence narrowed or strengthened the hypothesis.',3, false, 'active'),
    ('RESOLVED',          'Resolved',          ' Clinical question answered; hypothesis adjudicated.',4, true,  'active'),
    ('DROPPED',           'Dropped',           ' Excluded by evidence or rule action.',             5, true,  'active'),
    ('CONFIRMED',         'Confirmed',         ' Hypothesis confirmed (e.g. molecular TB, HCH12-0007).',6, true, 'active'),
    ('ENTERED_IN_ERROR',  'Entered in error',  ' Hypothesis entered in error.',                     7, true,  'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. differential_hypothesis — candidate explanations (DH001..DH010)
--    Each is a CONCEPT (condition or mechanism), never a raw symptom.
--    base_weight = starting prior (H8 §21); the final score is evidence-derived.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_hypothesis
    (hypothesis_code, concept_id, concept_code, hypothesis_type, canonical_name, short_label, description,
     body_system_code, pathological_process_code, base_weight, is_critical, applies_to_context_codes, status)
VALUES
    ('DH001', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PNEUMONIA'), 'CNS-PNEUMONIA',
     'CONDITION','Pneumonia','Pneumonia',
     ' Bacterial/viral infection of the lung parenchyma; bronchial breath sounds and crackles indicate consolidation (HCH12-0018); haemoptysis warrants a baseline CXR (HCH12-0004).',
     'RESPIRATORY','INFECTIVE_INFLAMMATORY', 2.00, true,  ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','EMERGENCY','INPATIENT','TELEMEDICINE'], 'active'),
    ('DH002', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-TUBERCULOSIS'), 'CNS-TUBERCULOSIS',
     'CONDITION','Pulmonary tuberculosis','TB',
     ' Chronic granulomatous pulmonary infection; haemoptysis, weight loss, night sweats (HCH12-0007/0020); confirmed by molecular detection (RINT_MTB_DETECTED).',
     'RESPIRATORY','INFECTIVE_INFLAMMATORY', 1.20, true,  ARRAY['ADULT','OLDER_ADULT','CHILD','INPATIENT','OUTPATIENT','TELEMEDICINE'], 'active'),
    ('DH003', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-ASTHMA'), 'CNS-ASTHMA',
     'CONDITION','Asthma','Asthma',
     ' Variable airway obstruction; dry cough at night/spasms (HCH12-0005), wheeze (HCH12-0018), obstructive spirometry (HCH12-0004).',
     'RESPIRATORY',NULL, 1.50, false, ARRAY['ADULT','OLDER_ADULT','CHILD','OUTPATIENT','TELEMEDICINE'], 'active'),
    ('DH004', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-HEART-FAILURE'), 'CNS-HEART-FAILURE',
     'CONDITION','Heart failure','Heart failure',
     ' Dyspnoea from cardiac disease (HCH12-0002); crackles in cardiac failure (HCH12-0018); congestion pattern with oedema/JVP.',
     'CARDIOVASCULAR','VASCULAR', 1.20, true, ARRAY['ADULT','OLDER_ADULT','INPATIENT','EMERGENCY'], 'active'),
    ('DH005', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-ACUTE-BRONCHITIS'), 'CNS-ACUTE-BRONCHITIS',
     'CONDITION','Acute bronchitis','Acute bronchitis',
     ' Acute (self-limiting) tracheobronchitis; acute cough <3 weeks (HCH12-0004), purulent sputum (HCH12-0006).',
     'RESPIRATORY','INFECTIVE_INFLAMMATORY', 1.00, false, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','OUTPATIENT','TELEMEDICINE'], 'active'),
    ('DH006', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-GERD'), 'CNS-GERD',
     'CONDITION','Gastro-oesophageal reflux disease','GERD',
     ' Acid reflux/indigestion and coughing after meals are key questions in chronic cough (HCH12-0020).',
     'GASTROINTESTINAL',NULL, 0.80, false, ARRAY['ADULT','OLDER_ADULT','OUTPATIENT','TELEMEDICINE'], 'active'),
    ('DH007', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PLEURAL-EFFUSION'), 'CNS-PLEURAL-EFFUSION',
     'CONDITION','Pleural effusion','Effusion',
     ' Fluid in the pleural space; trachea deviated AWAY from the affected side (mediastinum pushed, HCH12-0019); pleuritic pain (HCH12-0009).',
     'RESPIRATORY',NULL, 0.60, false, ARRAY['ADULT','OLDER_ADULT','INPATIENT','EMERGENCY'], 'active'),
    ('DH008', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-PNEUMOTHORAX'), 'CNS-PNEUMOTHORAX',
     'CONDITION','Pneumothorax','Pneumothorax',
     ' Air in the pleural space; trachea deviated AWAY (mediastinum pushed, HCH12-0019); spontaneous pneumothorax pain worse on breathing (HCH12-0009).',
     'RESPIRATORY','TRAUMATIC', 0.60, true, ARRAY['ADULT','OLDER_ADULT','EMERGENCY','INPATIENT'], 'active'),
    ('DH009', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-ALVEOLAR-INFLAMMATION'), 'CNS-ALVEOLAR-INFLAMMATION',
     'MECHANISM','Alveolar inflammation','Alveolar inflammation',
     ' The disordered FUNCTION underlying consolidation: bronchial breath sounds = consolidation (HCH12-0018).',
     'RESPIRATORY','INFECTIVE_INFLAMMATORY', 1.00, false, ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'active'),
    ('DH010', (SELECT id FROM knowledge.concept WHERE concept_code='CNS-AIRWAY-OBSTRUCTION'), 'CNS-AIRWAY-OBSTRUCTION',
     'MECHANISM','Airway obstruction','Airway obstruction',
     ' The disordered FUNCTION underlying wheeze/obstructive spirometry (HCH12-0018/0004).',
     'RESPIRATORY',NULL, 0.80, false, ARRAY['ADULT','OLDER_ADULT','CHILD'], 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. differential_evidence — SUPPORTS/REFUTES with weight (EV001..)
--    The evidence is the OBJECT; the weight is DATA; the rank is COMPUTED.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_evidence
    (evidence_code, hypothesis_code, evidence_type, fact_definition_code, phenotype_code,
     mechanism_code, result_interpretation_code, context_code, direction, weight, certainty, description,
     evidence_claim_code, is_active)
VALUES
    -- DH001 PNEUMONIA
    ('EV001','DH001','EXAMINATION_FINDING','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.50,'DEFINITE','Bronchial breath sounds indicate consolidation (HCH12-0018).','HCH12-0018',true),
    ('EV002','DH001','EXAMINATION_FINDING','CRACKLES',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Crackles occur in infection/consolidation (HCH12-0018).','HCH12-0018',true),
    ('EV003','DH001','FACT','FEVER_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Fever supports infective/inflammatory process (Box 2.3, HCH2-0005); CBC in immediate workup (HCH2-0006).','HCH2-0006',true),
    ('EV004','DH001','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_CONSOLIDATION',NULL,
     'SUPPORTS',2.00,'DEFINITE','Consolidation on CXR (bronchial breath sounds/crackles, HCH12-0018).','HCH12-0018',true),
    ('EV005','DH001','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_LEUKOCYTOSIS',NULL,
     'SUPPORTS',0.80,'PROBABLE','Leukocytosis in bacterial infection (immediate workup, HCH2-0006).','HCH2-0006',true),
    ('EV006','DH001','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_ELEVATED_CRP',NULL,
     'SUPPORTS',0.80,'PROBABLE','Elevated CRP = acute-phase inflammation (HCH2-0006).','HCH2-0006',true),
    ('EV007','DH001','FACT','WHEEZE_PRESENT',NULL,NULL,NULL,NULL,
     'REFUTES',0.40,'POSSIBLE','Wheeze is more characteristic of asthma/COPD than pure consolidation (HCH12-0018).','HCH12-0018',true),
    ('EV008','DH001','MECHANISM',NULL,NULL,'MECH-ALVEOLAR-INFLAMMATION',NULL,NULL,
     'SUPPORTS',1.20,'DEFINITE','Pneumonia is an alveolar inflammatory process (HCH12-0018).','HCH12-0018',true),

    -- DH002 TUBERCULOSIS
    ('EV010','DH002','FACT','BLOOD_IN_SPUTUM',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.50,'DEFINITE','Haemoptysis must never be dismissed without careful evaluation (HCH12-0007).','HCH12-0007',true),
    ('EV011','DH002','FACT','NIGHT_SWEATS',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Fevers/night sweats are key questions in chronic cough (Box 12.5, HCH12-0020).','HCH12-0020',true),
    ('EV012','DH002','FACT','WEIGHT_LOSS',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Weight loss is a chronic-cough red flag (Box 12.5, HCH12-0020).','HCH12-0020',true),
    ('EV013','DH002','FACT','TB_CONTACT',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'PROBABLE','TB exposure risk in the history (respiratory red flags, HCH12-0007).','HCH12-0007',true),
    ('EV014','DH002','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_MTB_DETECTED',NULL,
     'SUPPORTS',2.50,'DEFINITE','Molecular detection of MTB confirms pulmonary TB (respiratory red flags, HCH12-0007).','HCH12-0007',true),

    -- DH003 ASTHMA
    ('EV020','DH003','FACT','COUGH_CHARACTER',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'PROBABLE','Dry cough at night/spasms may be asthma (HCH12-0005).','HCH12-0005',true),
    ('EV021','DH003','FACT','WHEEZE_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.50,'DEFINITE','Wheezes occur in asthma (HCH12-0018).','HCH12-0018',true),
    ('EV022','DH003','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_OBSTRUCTIVE_SPIROMETRY',NULL,
     'SUPPORTS',1.20,'DEFINITE','Obstructive pattern on baseline spirometry for chronic cough (HCH12-0004).','HCH12-0004',true),
    ('EV023','DH003','PHENOTYPE',NULL,'PHEN-AIRWAY-WHEEZE',NULL,NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Variable obstructive airway pattern (HCH12-0018).','HCH12-0018',true),
    ('EV024','DH003','FACT','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,
     'REFUTES',1.00,'DEFINITE','Bronchial breath sounds indicate consolidation, not asthma (HCH12-0018).','HCH12-0018',true),
    ('EV025','DH003','FACT','FEVER_PRESENT',NULL,NULL,NULL,NULL,
     'REFUTES',0.30,'POSSIBLE','Fever is not characteristic of asthma.','HCH2-0005',true),

    -- DH004 HEART FAILURE
    ('EV030','DH004','FACT','DYSPNOEA_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'PROBABLE','Dyspnoea may be due to cardiac disease as well as primary respiratory problems (HCH12-0002).','HCH12-0002',true),
    ('EV031','DH004','FACT','ORTHOPNOEA',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'PROBABLE','Orthopnoea is a cardiac congestion marker (HCH12-0002).','HCH12-0002',true),
    ('EV032','DH004','FACT','PND',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Paroxysmal nocturnal dyspnoea in cardiac congestion (HCH12-0002).','HCH12-0002',true),
    ('EV033','DH004','FACT','PERIPHERAL_OEDEMA',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Peripheral oedema in heart failure (cardiac examination, HCH2-0004).','HCH2-0004',true),
    ('EV034','DH004','FACT','JUGULAR_VENOUS_DISTENTION',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Elevated JVP in cardiac congestion (complete examination order, HCH2-0004).','HCH2-0004',true),
    ('EV035','DH004','FACT','CRACKLES',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'PROBABLE','Crackles occur in cardiac failure (HCH12-0018).','HCH12-0018',true),
    ('EV036','DH004','PHENOTYPE',NULL,'PHEN-CHF-CONGESTIVE',NULL,NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Cardiopulmonary congestion pattern (HCH12-0018).','HCH12-0018',true),
    ('EV037','DH004','MECHANISM',NULL,NULL,'MECH-PULMONARY-CONGESTION',NULL,NULL,
     'SUPPORTS',1.20,'DEFINITE','Pulmonary vascular congestion in cardiac failure (HCH12-0018).','HCH12-0018',true),

    -- DH005 ACUTE BRONCHITIS
    ('EV040','DH005','FACT','COUGH_DURATION_DAYS',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Acute cough lasts <3 weeks (HCH12-0004).','HCH12-0004',true),
    ('EV041','DH005','FACT','COUGH_PRODUCTIVITY',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.60,'PROBABLE','Productive cough in acute tracheobronchitis (HCH12-0006).','HCH12-0006',true),
    ('EV042','DH005','FACT','SPUTUM_COLOUR',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.60,'PROBABLE','Yellow/green purulent sputum (HCH12-0006).','HCH12-0006',true),
    ('EV043','DH005','PHENOTYPE',NULL,'PHEN-ACUTE-LRTI',NULL,NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Acute lower respiratory infection pattern (HCH12-0004).','HCH12-0004',true),
    ('EV044','DH005','FACT','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,
     'REFUTES',1.00,'DEFINITE','Bronchial breath sounds indicate consolidation (pneumonia), not simple bronchitis (HCH12-0018).','HCH12-0018',true),
    ('EV045','DH005','FACT','WHEEZE_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.40,'POSSIBLE','Wheezes occur in infection (HCH12-0018).','HCH12-0018',true),

    -- DH006 GERD
    ('EV050','DH006','FACT','HEARTBURN',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Acid reflux/indigestion is a key chronic-cough question (Box 12.5, HCH12-0020).','HCH12-0020',true),
    ('EV051','DH006','FACT','COUGH_POSITIONAL',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Coughing after meals suggests reflux (Box 12.5, HCH12-0020).','HCH12-0020',true),
    ('EV052','DH006','PHENOTYPE',NULL,'PHEN-REFLUX-COUGH',NULL,NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Reflux-associated cough pattern (HCH12-0020).','HCH12-0020',true),
    ('EV053','DH006','MECHANISM',NULL,NULL,'MECH-GASTROESOPHAGEAL-REFLUX',NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Gastro-oesophageal reflux mechanism (HCH12-0020).','HCH12-0020',true),
    ('EV054','DH006','FACT','BLOOD_IN_SPUTUM',NULL,NULL,NULL,NULL,
     'REFUTES',0.30,'POSSIBLE','Haemoptysis points away from reflux alone (HCH12-0007).','HCH12-0007',true),

    -- DH007 PLEURAL EFFUSION
    ('EV060','DH007','EXAMINATION_FINDING','RLL_DULLNESS',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.00,'PROBABLE','Percussion dullness in effusion (chest examination, HCH12-0017).','HCH12-0017',true),
    ('EV061','DH007','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_PLEURAL_EFFUSION',NULL,
     'SUPPORTS',2.00,'DEFINITE','Trachea deviated away from the affected side suggests pleural effusion (HCH12-0019).','HCH12-0019',true),
    ('EV062','DH007','FACT','CHEST_PAIN_PLEURITIC',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.60,'POSSIBLE','Pleuritic pain occurs when the pleura is inflamed (HCH12-0009).','HCH12-0009',true),
    ('EV063','DH007','FACT','DYSPNOEA_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.50,'POSSIBLE','Effusion restricts ventilation.','HCH12-0002',true),
    ('EV064','DH007','FACT','CRACKLES',NULL,NULL,NULL,NULL,
     'REFUTES',0.20,'POSSIBLE','Crackles are less characteristic of a simple effusion (HCH12-0018).','HCH12-0018',true),

    -- DH008 PNEUMOTHORAX
    ('EV070','DH008','FACT','DYSPNOEA_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Acute dyspnoea in pneumothorax (HCH12-0002).','HCH12-0002',true),
    ('EV071','DH008','FACT','CHEST_PAIN_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',0.80,'PROBABLE','Spontaneous pneumothorax pain is worse on breathing (HCH12-0009).','HCH12-0009',true),
    ('EV072','DH008','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_PNEUMOTHORAX',NULL,
     'SUPPORTS',2.00,'DEFINITE','Trachea deviated away suggests pneumothorax (HCH12-0019).','HCH12-0019',true),
    ('EV073','DH008','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_HYPOXAEMIA',NULL,
     'SUPPORTS',0.80,'DEFINITE','Hypoxaemia (SpO2 <95%) in respiratory compromise (HCH12-0016).','HCH12-0016',true),
    ('EV074','DH008','FACT','RLL_DULLNESS',NULL,NULL,NULL,NULL,
     'REFUTES',0.80,'PROBABLE','Pneumothorax is hyper-resonant, not dull to percussion (HCH12-0017).','HCH12-0017',true),

    -- DH009 ALVEOLAR INFLAMMATION
    ('EV080','DH009','FACT','RLL_BRONCHIAL_BREATH_SOUNDS',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.50,'DEFINITE','Bronchial breath sounds indicate consolidation (HCH12-0018).','HCH12-0018',true),
    ('EV081','DH009','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_CONSOLIDATION',NULL,
     'SUPPORTS',1.50,'DEFINITE','CXR consolidation = alveolar inflammation (HCH12-0018).','HCH12-0018',true),
    ('EV082','DH009','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_LEUKOCYTOSIS',NULL,
     'SUPPORTS',0.60,'PROBABLE','Raised WBC supports an inflammatory process (HCH2-0006).','HCH2-0006',true),

    -- DH010 AIRWAY OBSTRUCTION
    ('EV090','DH010','FACT','WHEEZE_PRESENT',NULL,NULL,NULL,NULL,
     'SUPPORTS',1.20,'DEFINITE','Wheezes indicate airway narrowing (HCH12-0018).','HCH12-0018',true),
    ('EV091','DH010','RESULT_INTERPRETATION',NULL,NULL,NULL,'RINT_OBSTRUCTIVE_SPIROMETRY',NULL,
     'SUPPORTS',1.50,'DEFINITE','FEV1/FVC <0.70 = obstructive airflow limitation (HCH12-0004).','HCH12-0004',true),
    ('EV092','DH010','MECHANISM',NULL,NULL,'MECH-AIRWAY-OBSTRUCTION',NULL,NULL,
     'SUPPORTS',1.00,'DEFINITE','Airway obstruction mechanism (HCH12-0018).','HCH12-0018',true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. differential_rule — data-driven evidence→hypothesis activation (H8 §11)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_rule
    (rule_code, trigger_type, trigger_code, target_hypothesis_code, modification, weight_delta, rationale,
     evidence_claim_code, applies_to_context_codes, is_active, status)
VALUES
    ('DR001','FACT','BLOOD_IN_SPUTUM','DH002','MARK_CRITICAL',1.00,
     'Haemoptysis must never be dismissed without careful evaluation — keeps TB on the critical list (HCH12-0007).',
     'HCH12-0007', ARRAY['ADULT','OLDER_ADULT','CHILD','INPATIENT','OUTPATIENT'], true, 'active'),
    ('DR002','FACT','BLOOD_IN_SPUTUM','DH001','ELEVATE',0.50,
     'Any cough with haemoptysis requires at least a baseline CXR (HCH12-0004).',
     'HCH12-0004', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('DR003','FACT','RLL_BRONCHIAL_BREATH_SOUNDS','DH001','ELEVATE',1.00,
     'Bronchial breath sounds = consolidation → pneumonia (HCH12-0018).',
     'HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('DR004','FACT','RLL_BRONCHIAL_BREATH_SOUNDS','DH005','SUPPRESS',-0.50,
     'Consolidation points away from simple acute bronchitis (HCH12-0018).',
     'HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('DR005','FACT','WHEEZE_PRESENT','DH003','ACTIVATE',1.00,
     'Wheezes occur in asthma (HCH12-0018).',
     'HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('DR006','FACT','WHEEZE_PRESENT','DH010','ELEVATE',0.50,
     'Wheezes indicate airway obstruction (HCH12-0018).',
     'HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('DR007','FACT','COUGH_DURATION_DAYS','DH003','ACTIVATE',0.80,
     'Chronic cough (>8 weeks) keeps asthma on the differential (HCH12-0004); baseline spirometry. (Guarded: >56 days.)',
     'HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('DR008','FACT','COUGH_DURATION_DAYS','DH005','SUPPRESS',-0.80,
     'A cough lasting >8 weeks is NOT acute bronchitis (HCH12-0004). (Guarded: >56 days.)',
     'HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('DR009','RESULT_INTERPRETATION','RINT_MTB_DETECTED','DH002','MARK_CRITICAL',2.00,
     'Molecular detection of MTB confirms pulmonary TB (HCH12-0007).',
     'HCH12-0007', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('DR010','RESULT_INTERPRETATION','RINT_CONSOLIDATION','DH001','ELEVATE',1.50,
     'CXR consolidation → pneumonia (HCH12-0018).',
     'HCH12-0018', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('DR011','RESULT_INTERPRETATION','RINT_OBSTRUCTIVE_SPIROMETRY','DH003','ELEVATE',1.50,
     'Obstructive spirometry (FEV1/FVC <0.70) → asthma/obstructive pattern (HCH12-0004).',
     'HCH12-0004', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('DR012','CONTEXT','OLDER_ADULT','DH004','ACTIVATE',0.50,
     'Cardiac disease is an important cause of dyspnoea in the older adult (HCH12-0002).',
     'HCH12-0002', ARRAY['OLDER_ADULT','INPATIENT','EMERGENCY'], true, 'active'),
    ('DR013','FACT','HEARTBURN','DH006','ACTIVATE',1.00,
     'Acid reflux is a key chronic-cough question (Box 12.5, HCH12-0020).',
     'HCH12-0020', ARRAY['ADULT','OLDER_ADULT','OUTPATIENT'], true, 'active'),
    ('DR014','FACT','POSTNASAL_DRIP','DH003','CONDITIONAL',0.30,
     'Post-nasal drip is a common cause of chronic cough and coexists with asthma (HCH12-0010).',
     'HCH12-0010', ARRAY['ADULT','OLDER_ADULT','OUTPATIENT'], true, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. differential_rule_condition — value guards on differential rules (H8 §11)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_rule_condition (rule_code, condition_code, fact_definition_code, operator, value, rationale, is_active) VALUES
    ('DR007','DRC001','COUGH_DURATION_DAYS','>','56',' Chronic cough = duration >8 weeks = 56 days (HCH12-0004).', true),
    ('DR008','DRC002','COUGH_DURATION_DAYS','>','56',' Chronic cough = duration >8 weeks = 56 days (HCH12-0004).', true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. differential_weight — the H8 §21 multi-dimension evidence-weighting model
--    score(h) = base_weight + Σ(dimension_weight × factor) + Σ(rule deltas) + Σ(evidence)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_weight
    (weight_code, dimension, direction, weight, description, version, effective_from, status)
VALUES
    ('DWT001','EVIDENCE_STRENGTH',     'POSITIVE', 2.00, ' How strong the piece of evidence itself is.',             1,'2024-01-01','active'),
    ('DWT002','HARD_SYMPTOM',          'POSITIVE', 1.50, ' How hard/objective the symptom or finding is.',            1,'2024-01-01','active'),
    ('DWT003','MECHANISM_PLAUSIBILITY','POSITIVE', 1.00, ' How plausibly the evidence fits the hypothesis mechanism.',1,'2024-01-01','active'),
    ('DWT004','TEMPORAL_FIT',          'POSITIVE', 0.80, ' How well the evidence matches the time course.',           1,'2024-01-01','active'),
    ('DWT005','SEVERITY_FIT',          'POSITIVE', 0.50, ' How well the evidence matches severity/acuity.',          1,'2024-01-01','active'),
    ('DWT006','RED_FLAG',              'POSITIVE', 1.20, ' Multiplier for must-not-miss/safety signals.',            1,'2024-01-01','active'),
    ('DWT007','CONTEXT_FIT',           'POSITIVE', 0.80, ' How well the evidence fits the active context.',          1,'2024-01-01','active'),
    ('DWT008','EXCLUSION_POWER',       'POSITIVE', 0.60, ' How much a REFUTES piece can remove a hypothesis.',       1,'2024-01-01','active'),
    ('DWT009','REFUTATION_PENALTY',    'NEGATIVE', 1.50, ' Penalty applied for REFUTES evidence.',                   1,'2024-01-01','active'),
    ('DWT010','PREVALENCE_PRIOR',      'POSITIVE', 0.30, ' Prior prevalence weighting of the hypothesis.',            1,'2024-01-01','active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. differential_source — provenance of differential knowledge (H8 §31/§45)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_source
    (hypothesis_code, source_version_id, reference, organization, publication, edition, year, chapter_ref, section_ref, version, effective_from, status)
VALUES
    ('DH001','HUTCHISON_24_2018','CH12 — auscultation: bronchial breath sounds = consolidation; cough/haemoptysis CXR.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH002','HUTCHISON_24_2018','CH12 — haemoptysis careful evaluation; chronic-cough red flags.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH003','HUTCHISON_24_2018','CH12 — cough discussion (nocturnal cough); wheeze; baseline spirometry.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH004','HUTCHISON_24_2018','CH12 — dyspnoea from cardiac disease; crackles in cardiac failure.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH005','HUTCHISON_24_2018','CH12 — acute cough <3 weeks; purulent sputum.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH006','HUTCHISON_24_2018','CH12 — Box 12.5 acid reflux/indigestion in chronic cough.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','Box 12.5','v1','2018-01-01','active'),
    ('DH007','HUTCHISON_24_2018','CH12 — tracheal deviation away → pleural effusion.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH008','HUTCHISON_24_2018','CH12 — tracheal deviation away → pneumothorax; spontaneous pneumothorax pain.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH009','HUTCHISON_24_2018','CH12 — bronchial breath sounds indicate consolidation (mechanism).','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active'),
    ('DH010','HUTCHISON_24_2018','CH12 — wheeze + FEV1/FVC <0.70 obstructive limitation.','Hutchison','Hutchison Clinical Methods','24',2018,'H1-C12','CH12','v1','2018-01-01','active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9. differential_version — temporal versioning of differential knowledge (H8)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.differential_version (hypothesis_code, version_no, effective_from, supersedes, change_note, status)
SELECT dh.hypothesis_code, 1, '2018-01-01', NULL, ' H8 seed from Hutchison Clinical Methods 24e.', 'active'
FROM knowledge.differential_hypothesis dh
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 10. provenance — Hutchison claims → H8 knowledge objects (H8 §31/§46)
-- ---------------------------------------------------------------------------
-- 10a. differential_hypothesis edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, dh.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0018','differential_hypothesis','DH001'),('HCH12-0007','differential_hypothesis','DH002'),
     ('HCH12-0005','differential_hypothesis','DH003'),('HCH12-0002','differential_hypothesis','DH004'),
     ('HCH12-0004','differential_hypothesis','DH005'),('HCH12-0020','differential_hypothesis','DH006'),
     ('HCH12-0019','differential_hypothesis','DH007'),('HCH12-0019','differential_hypothesis','DH008'),
     ('HCH12-0018','differential_hypothesis','DH009'),('HCH12-0018','differential_hypothesis','DH010')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.differential_hypothesis dh ON dh.hypothesis_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 10b. differential_evidence edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, e.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0018','differential_evidence','EV001'),('HCH12-0018','differential_evidence','EV002'),
     ('HCH2-0006','differential_evidence','EV003'),('HCH12-0018','differential_evidence','EV004'),
     ('HCH2-0006','differential_evidence','EV005'),('HCH2-0006','differential_evidence','EV006'),
     ('HCH12-0018','differential_evidence','EV007'),('HCH12-0018','differential_evidence','EV008'),
     ('HCH12-0007','differential_evidence','EV010'),('HCH12-0020','differential_evidence','EV011'),
     ('HCH12-0020','differential_evidence','EV012'),('HCH12-0007','differential_evidence','EV013'),
     ('HCH12-0007','differential_evidence','EV014'),
     ('HCH12-0005','differential_evidence','EV020'),('HCH12-0018','differential_evidence','EV021'),
     ('HCH12-0004','differential_evidence','EV022'),('HCH12-0018','differential_evidence','EV023'),
     ('HCH12-0018','differential_evidence','EV024'),('HCH2-0005','differential_evidence','EV025'),
     ('HCH12-0002','differential_evidence','EV030'),('HCH12-0002','differential_evidence','EV031'),
     ('HCH12-0002','differential_evidence','EV032'),('HCH2-0004','differential_evidence','EV033'),
     ('HCH2-0004','differential_evidence','EV034'),('HCH12-0018','differential_evidence','EV035'),
     ('HCH12-0018','differential_evidence','EV036'),('HCH12-0018','differential_evidence','EV037'),
     ('HCH12-0004','differential_evidence','EV040'),('HCH12-0006','differential_evidence','EV041'),
     ('HCH12-0006','differential_evidence','EV042'),('HCH12-0004','differential_evidence','EV043'),
     ('HCH12-0018','differential_evidence','EV044'),('HCH12-0018','differential_evidence','EV045'),
     ('HCH12-0020','differential_evidence','EV050'),('HCH12-0020','differential_evidence','EV051'),
     ('HCH12-0020','differential_evidence','EV052'),('HCH12-0020','differential_evidence','EV053'),
     ('HCH12-0007','differential_evidence','EV054'),
     ('HCH12-0017','differential_evidence','EV060'),('HCH12-0019','differential_evidence','EV061'),
     ('HCH12-0009','differential_evidence','EV062'),('HCH12-0002','differential_evidence','EV063'),
     ('HCH12-0018','differential_evidence','EV064'),
     ('HCH12-0002','differential_evidence','EV070'),('HCH12-0009','differential_evidence','EV071'),
     ('HCH12-0019','differential_evidence','EV072'),('HCH12-0016','differential_evidence','EV073'),
     ('HCH12-0017','differential_evidence','EV074'),
     ('HCH12-0018','differential_evidence','EV080'),('HCH12-0018','differential_evidence','EV081'),
     ('HCH2-0006','differential_evidence','EV082'),
     ('HCH12-0018','differential_evidence','EV090'),('HCH12-0004','differential_evidence','EV091'),
     ('HCH12-0018','differential_evidence','EV092')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.differential_evidence e ON e.evidence_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 10c. differential_rule + differential_rule_condition edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, x.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0007','differential_rule','DR001'),('HCH12-0004','differential_rule','DR002'),
     ('HCH12-0018','differential_rule','DR003'),('HCH12-0018','differential_rule','DR004'),
     ('HCH12-0018','differential_rule','DR005'),('HCH12-0018','differential_rule','DR006'),
     ('HCH12-0004','differential_rule','DR007'),('HCH12-0004','differential_rule','DR008'),
     ('HCH12-0007','differential_rule','DR009'),('HCH12-0018','differential_rule','DR010'),
     ('HCH12-0004','differential_rule','DR011'),('HCH12-0002','differential_rule','DR012'),
     ('HCH12-0020','differential_rule','DR013'),('HCH12-0010','differential_rule','DR014'),
     ('HCH12-0004','differential_rule_condition','DRC001'),('HCH12-0004','differential_rule_condition','DRC002')
) AS v(claim_code, object_type, object_code)
JOIN (
    SELECT dr.id, 'differential_rule' AS t, dr.rule_code AS obj FROM knowledge.differential_rule dr
    UNION ALL
    SELECT drc.condition_id, 'differential_rule_condition' AS t, drc.condition_code AS obj FROM knowledge.differential_rule_condition drc
) x ON x.t = v.object_type AND x.obj = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 10d. differential_weight edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, dw.weight_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0005','differential_weight','DWT001'),('HCH12-0004','differential_weight','DWT002'),
     ('HCH12-0018','differential_weight','DWT003'),('HCH12-0004','differential_weight','DWT004'),
     ('HCH12-0016','differential_weight','DWT005'),('HCH12-0007','differential_weight','DWT006'),
     ('HCH2-0002','differential_weight','DWT007'),('HCH12-0018','differential_weight','DWT008'),
     ('HCH12-0018','differential_weight','DWT009'),('HCH2-0005','differential_weight','DWT010')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.differential_weight dw ON dw.weight_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 10e. differential_source edges (source record counterpart of the hypothesis edges)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, dsrc.source_id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0018','differential_source','DH001'),('HCH12-0007','differential_source','DH002'),
     ('HCH12-0005','differential_source','DH003'),('HCH12-0002','differential_source','DH004'),
     ('HCH12-0004','differential_source','DH005'),('HCH12-0020','differential_source','DH006'),
     ('HCH12-0019','differential_source','DH007'),('HCH12-0019','differential_source','DH008'),
     ('HCH12-0018','differential_source','DH009'),('HCH12-0018','differential_source','DH010')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.differential_source dsrc ON dsrc.hypothesis_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 10f. new concept edges (CNS-PLEURAL-EFFUSION, CNS-PNEUMOTHORAX from HCH12-0019)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, c.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0019','concept','CNS-PLEURAL-EFFUSION'),
     ('HCH12-0019','concept','CNS-PNEUMOTHORAX')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.concept c ON c.concept_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;
