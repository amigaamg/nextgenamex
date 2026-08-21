-- =============================================================================
-- 046_systemic_examination_knowledge_base.sql
--
-- AMEXAN Universal Clinical Examination Knowledge Base
--
-- PURPOSE
-- -------
-- Migration 045 established:
--   - examination domains
--   - examination techniques
--   - examination sites
--   - examination concepts
--   - vital/reference-range infrastructure
--   - graded findings
--
-- Migration 046 extends that foundation into a FULL GENERALISED SYSTEMIC
-- EXAMINATION KNOWLEDGE BASE.
--
-- SYSTEMS COVERED
-- ---------------
--   1. Respiratory
--   2. Cardiovascular
--   3. Abdomen / Gastrointestinal
--   4. Neurological
--   5. Musculoskeletal
--   6. Peripheral vascular
--   7. Genitourinary
--   8. Breast
--   9. Head / neck
--  10. Skin
--
-- DESIGN PRINCIPLES
-- -----------------
--   • Examination is observation-first and finding-driven.
--   • A normal finding must be representable explicitly.
--   • Abnormal findings must be structured rather than buried in free text.
--   • Findings may have graded severity where clinically appropriate.
--   • Examination concepts are reusable across diseases.
--   • Disease does NOT own the examination finding.
--   • Disease/condition knowledge may trigger examination concepts.
--   • The clinician records findings; the reasoning engine may interpret them.
--   • The examination record must preserve what was actually observed.
--
-- IMPORTANT
-- ---------
-- This migration intentionally does NOT attempt to diagnose from findings.
-- Interpretation/diagnosis belongs to the clinical reasoning layer.
--
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. ADDITIONAL BODY SYSTEMS
-- =============================================================================

INSERT INTO knowledge.body_system
  (code, label, description)
VALUES
  ('respiratory',
   'Respiratory',
   'Lungs, airways, chest wall and respiratory mechanics'),

  ('cardiovascular',
   'Cardiovascular',
   'Heart, circulation, pulses and peripheral cardiovascular signs'),

  ('gastrointestinal',
   'Gastrointestinal',
   'Abdominal and gastrointestinal examination'),

  ('neurological',
   'Neurological',
   'Mental status, cranial nerves, motor, sensory, reflexes and coordination'),

  ('musculoskeletal',
   'Musculoskeletal',
   'Bones, joints, muscles, movement and functional examination'),

  ('vascular',
   'Peripheral vascular',
   'Arterial and venous peripheral vascular examination'),

  ('genitourinary',
   'Genitourinary',
   'External genitourinary and urinary examination'),

  ('breast',
   'Breast',
   'Breast and regional lymphatic examination'),

  ('head_neck',
   'Head and Neck',
   'Head, face, eyes, ears, nose, oral cavity and neck'),

  ('skin',
   'Skin',
   'Skin, hair, nails and peripheral integument')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 2. SYSTEMIC EXAMINATION DOMAINS
-- =============================================================================

INSERT INTO knowledge.examination_domain
  (domain_code, code, body_system_code, label, description,
   sort_order, is_mandatory, status)
VALUES

  ('EXAM-RESPIRATORY',
   'respiratory',
   'respiratory',
   'Respiratory Examination',
   'Inspection, palpation, percussion and auscultation of the respiratory system.',
   100, FALSE, 'active'),

  ('EXAM-CARDIOVASCULAR',
   'cardiovascular',
   'cardiovascular',
   'Cardiovascular Examination',
   'Peripheral cardiovascular examination, precordium, pulses, JVP and heart sounds.',
   110, FALSE, 'active'),

  ('EXAM-ABDOMINAL',
   'abdominal',
   'gastrointestinal',
   'Abdominal Examination',
   'Inspection, palpation, percussion and auscultation of the abdomen.',
   120, FALSE, 'active'),

  ('EXAM-NEUROLOGICAL',
   'neurological',
   'neurological',
   'Neurological Examination',
   'Mental status, cranial nerves, motor, sensory, reflexes and coordination.',
   130, FALSE, 'active'),

  ('EXAM-MSK',
   'musculoskeletal',
   'musculoskeletal',
   'Musculoskeletal Examination',
   'Inspection, palpation, movement, strength and functional examination.',
   140, FALSE, 'active'),

  ('EXAM-VASCULAR',
   'vascular',
   'vascular',
   'Peripheral Vascular Examination',
   'Peripheral arterial and venous examination.',
   150, FALSE, 'active'),

  ('EXAM-GU',
   'genitourinary',
   'genitourinary',
   'Genitourinary Examination',
   'External genital, urinary and relevant regional examination.',
   160, FALSE, 'active'),

  ('EXAM-BREAST',
   'breast',
   'breast',
   'Breast Examination',
   'Systematic breast and regional lymph node examination.',
   170, FALSE, 'active'),

  ('EXAM-HEAD-NECK',
   'head_neck_systemic',
   'head_neck',
   'Head and Neck Examination',
   'Eyes, ears, nose, oral cavity and neck.',
   180, FALSE, 'active')
ON CONFLICT (domain_code) DO NOTHING;


-- =============================================================================
-- 3. EXAMINATION SITES
-- =============================================================================

INSERT INTO knowledge.examination_site
  (code, body_system_code, name, status)
VALUES

-- Respiratory
('SITE-CHEST',             'respiratory', 'Chest', 'active'),
('SITE-ANTERIOR-CHEST',    'respiratory', 'Anterior chest', 'active'),
('SITE-POSTERIOR-CHEST',   'respiratory', 'Posterior chest', 'active'),
('SITE-LATERAL-CHEST',     'respiratory', 'Lateral chest', 'active'),
('SITE-TRACHEA',           'respiratory', 'Trachea', 'active'),
('SITE-CHEST-EXPANSION',   'respiratory', 'Chest expansion', 'active'),
('SITE-VOCAL-RESONANCE',   'respiratory', 'Vocal resonance', 'active'),

-- Cardiovascular
('SITE-PRECORDIUM',        'cardiovascular', 'Precordium', 'active'),
('SITE-APEX',              'cardiovascular', 'Apex beat', 'active'),
('SITE-JVP',               'cardiovascular', 'Jugular venous pressure', 'active'),
('SITE-CAROTID',           'vascular', 'Carotid pulse', 'active'),
('SITE-RADIAL',            'vascular', 'Radial pulse', 'active'),
('SITE-BRACHIAL',          'vascular', 'Brachial pulse', 'active'),
('SITE-FEMORAL',           'vascular', 'Femoral pulse', 'active'),
('SITE-POPLITEAL',         'vascular', 'Popliteal pulse', 'active'),
('SITE-POST-TIBIAL',       'vascular', 'Posterior tibial pulse', 'active'),
('SITE-DORSALIS-PEDIS',    'vascular', 'Dorsalis pedis pulse', 'active'),
('SITE-HEART-SOUNDS',      'cardiovascular', 'Cardiac auscultation areas', 'active'),

-- Abdomen
('SITE-ABDOMEN',           'gastrointestinal', 'Abdomen', 'active'),
('SITE-RUQ',               'gastrointestinal', 'Right upper quadrant', 'active'),
('SITE-LUQ',               'gastrointestinal', 'Left upper quadrant', 'active'),
('SITE-RLQ',               'gastrointestinal', 'Right lower quadrant', 'active'),
('SITE-LLQ',               'gastrointestinal', 'Left lower quadrant', 'active'),
('SITE-EPIGASTRIUM',       'gastrointestinal', 'Epigastrium', 'active'),
('SITE-SUPRAPUBIC',        'gastrointestinal', 'Suprapubic region', 'active'),
('SITE-LIVER',             'gastrointestinal', 'Liver', 'active'),
('SITE-SPLEEN',            'gastrointestinal', 'Spleen', 'active'),
('SITE-KIDNEY',            'gastrointestinal', 'Kidneys / renal angle', 'active'),
('SITE-ASCITES',           'gastrointestinal', 'Ascites', 'active'),
('SITE-INGUINAL',          'gastrointestinal', 'Inguinal region', 'active'),

-- Neurology
('SITE-MENTAL-STATUS',     'neurological', 'Mental status', 'active'),
('SITE-CRANIAL-NERVES',    'neurological', 'Cranial nerves', 'active'),
('SITE-UPPER-LIMB',        'neurological', 'Upper limbs', 'active'),
('SITE-LOWER-LIMB',        'neurological', 'Lower limbs', 'active'),
('SITE-SPINE',             'musculoskeletal', 'Spine', 'active'),
('SITE-GAIT',              'neurological', 'Gait', 'active'),
('SITE-CEREBELLAR',        'neurological', 'Cerebellar function', 'active'),

-- Musculoskeletal
('SITE-JOINT',             'musculoskeletal', 'Joint', 'active'),
('SITE-MUSCLE',            'musculoskeletal', 'Muscle', 'active'),
('SITE-BONE',              'musculoskeletal', 'Bone', 'active'),
('SITE-SPINE-MS',          'musculoskeletal', 'Spine', 'active'),

-- GU
('SITE-EXTERNAL-GENITALIA','genitourinary', 'External genitalia', 'active'),
('SITE-MALE-GENITALIA',   'genitourinary', 'Male genitalia', 'active'),
('SITE-FEMALE-GENITALIA', 'genitourinary', 'Female external genitalia', 'active'),
('SITE-CVA',              'genitourinary', 'Costovertebral angle', 'active'),

-- Breast
('SITE-BREAST-RIGHT',     'breast', 'Right breast', 'active'),
('SITE-BREAST-LEFT',      'breast', 'Left breast', 'active'),
('SITE-AXILLARY-NODES',   'breast', 'Axillary lymph nodes', 'active'),
('SITE-SUPRACLAVICULAR',  'breast', 'Supraclavicular lymph nodes', 'active'),

-- Head / neck
('SITE-EYES',             'head_neck', 'Eyes', 'active'),
('SITE-EARS',             'head_neck', 'Ears', 'active'),
('SITE-NOSE',             'head_neck', 'Nose', 'active'),
('SITE-NECK',             'head_neck', 'Neck', 'active'),
('SITE-THYROID',          'head_neck', 'Thyroid', 'active')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 4. ADDITIONAL FACT DEFINITIONS
-- =============================================================================

INSERT INTO clinical.fact_definition
  (code, data_type, name, is_active)
VALUES

-- Respiratory
('CHEST_SHAPE',              'coded',    'Chest shape', TRUE),
('CHEST_MOVEMENT',           'coded',    'Chest movement', TRUE),
('CHEST_EXPANSION',          'numeric',  'Chest expansion', TRUE),
('TRACHEAL_POSITION',        'coded',    'Tracheal position', TRUE),
('TACTILE_FREMitus',         'coded',    'Tactile vocal fremitus', TRUE),
('CHEST_TENDERNESS',         'boolean',  'Chest wall tenderness', TRUE),
('PERCUSSION_NOTE',          'coded',    'Chest percussion note', TRUE),
('BREATH_SOUND',             'coded',    'Breath sound', TRUE),
('ADDED_BREATH_SOUND',       'coded',    'Added breath sounds', TRUE),
('VOCAL_RESONANCE',          'coded',    'Vocal resonance', TRUE),
('PLEURAL_RUB',              'boolean',  'Pleural friction rub', TRUE),

-- Cardiovascular
('JVP_HEIGHT',               'numeric',  'Jugular venous pressure', TRUE),
('JVP_CHARACTER',            'coded',    'Jugular venous waveform/character', TRUE),
('APEX_POSITION',            'coded',    'Apex beat position', TRUE),
('APEX_CHARACTER',           'coded',    'Apex beat character', TRUE),
('HEAVE',                    'boolean',  'Precordial heave', TRUE),
('THRILL',                   'boolean',  'Precordial thrill', TRUE),
('HEART_SOUND_S1',           'coded',    'First heart sound', TRUE),
('HEART_SOUND_S2',           'coded',    'Second heart sound', TRUE),
('ADDITIONAL_HEART_SOUND',   'coded',    'Additional heart sound', TRUE),
('HEART_MURMUR',             'coded',    'Cardiac murmur', TRUE),
('MURMUR_TIMING',            'coded',    'Murmur timing', TRUE),
('MURMUR_LOCATION',          'coded',    'Murmur location', TRUE),
('MURMUR_RADIATION',         'coded',    'Murmur radiation', TRUE),
('PERIPHERAL_PULSE_RATE',    'numeric',  'Peripheral pulse rate', TRUE),
('PULSE_RHYTHM',             'coded',    'Pulse rhythm', TRUE),
('PULSE_VOLUME',             'coded',    'Pulse volume', TRUE),
('PULSE_CHARACTER',          'coded',    'Pulse character', TRUE),

-- Abdomen
('ABDOMINAL_DISTENSION',     'boolean',  'Abdominal distension', TRUE),
('ABDOMINAL_CONTOUR',        'coded',    'Abdominal contour', TRUE),
('ABDOMINAL_SCAR',           'boolean',  'Abdominal scar', TRUE),
('ABDOMINAL_VENOUS_PATTERN', 'coded',    'Abdominal venous pattern', TRUE),
('BOWEL_SOUNDS',             'coded',    'Bowel sounds', TRUE),
('ABDOMINAL_TENDERNESS',     'coded',    'Abdominal tenderness', TRUE),
('GUARDING',                 'boolean',  'Abdominal guarding', TRUE),
('RIGIDITY',                 'boolean',  'Abdominal rigidity', TRUE),
('REBOUND_TENDERNESS',       'boolean',  'Rebound tenderness', TRUE),
('ABDOMINAL_MASS',           'coded',    'Abdominal mass', TRUE),
('LIVER_SIZE',               'numeric',  'Liver span', TRUE),
('LIVER_EDGE',               'coded',    'Liver edge', TRUE),
('SPLENIC_ENLARGEMENT',      'coded',    'Splenic enlargement', TRUE),
('KIDNEY_PALPABILITY',       'coded',    'Kidney palpability', TRUE),
('ASCITES',                  'coded',    'Ascites', TRUE),
('FLUID_THRILL',             'boolean',  'Fluid thrill', TRUE),
('SHIFTING_DULLNESS',        'boolean',  'Shifting dullness', TRUE),
('ABDOMINAL_PERCUSSION',     'coded',    'Abdominal percussion', TRUE),

-- Neurology
('GCS_TOTAL',                'numeric',  'Glasgow Coma Scale total', TRUE),
('MENTAL_STATUS',            'coded',    'Mental status', TRUE),
('ORIENTATION',              'coded',    'Orientation', TRUE),
('SPEECH',                   'coded',    'Speech', TRUE),
('CRANIAL_NERVE_FINDING',    'coded',    'Cranial nerve finding', TRUE),
('MOTOR_POWER',              'numeric',  'Motor power MRC grade', TRUE),
('MUSCLE_TONE',              'coded',    'Muscle tone', TRUE),
('MUSCLE_BULK',              'coded',    'Muscle bulk', TRUE),
('TREMOR',                   'coded',    'Tremor', TRUE),
('FASCICULATION',            'boolean',  'Fasciculation', TRUE),
('REFLEX_FINDING',           'coded',    'Deep tendon reflex', TRUE),
('PLANTAR_RESPONSE',         'coded',    'Plantar response', TRUE),
('LIGHT_TOUCH',              'coded',    'Light touch sensation', TRUE),
('PAIN_SENSATION',           'coded',    'Pain sensation', TRUE),
('VIBRATION_SENSE',          'coded',    'Vibration sensation', TRUE),
('PROPRIOCEPTION',           'coded',    'Joint position sense', TRUE),
('COORDINATION',             'coded',    'Coordination', TRUE),
('GAIT',                     'coded',    'Gait', TRUE),
('ROMBERG',                  'coded',    'Romberg test', TRUE),

-- Musculoskeletal
('JOINT_SWELLING',           'coded',    'Joint swelling', TRUE),
('JOINT_TENDERNESS',         'boolean',  'Joint tenderness', TRUE),
('JOINT_WARMTH',             'boolean',  'Joint warmth', TRUE),
('JOINT_DEFORMITY',          'coded',    'Joint deformity', TRUE),
('JOINT_RANGE_ACTIVE',       'coded',    'Active range of movement', TRUE),
('JOINT_RANGE_PASSIVE',      'coded',    'Passive range of movement', TRUE),
('CREPITUS',                 'boolean',  'Crepitus', TRUE),
('MUSCLE_TENDERNESS',        'boolean',  'Muscle tenderness', TRUE),
('LIMB_LENGTH',              'numeric',  'Limb length', TRUE),

-- Vascular
('LIMB_TEMPERATURE',         'coded',    'Peripheral limb temperature', TRUE),
('CAPILLARY_REFILL',         'numeric',  'Capillary refill time', TRUE),
('PERIPHERAL_PULSES',        'coded',    'Peripheral pulses', TRUE),
('VARICOSITIES',             'boolean',  'Varicose veins', TRUE),
('VENOUS_EDEMA',             'coded',    'Venous edema', TRUE),
('ARTERIAL_TROPHIC_CHANGE',  'coded',    'Arterial trophic changes', TRUE),

-- GU
('GENITAL_APPEARANCE',       'coded',    'Genital appearance', TRUE),
('URETHRAL_DISCHARGE',       'coded',    'Urethral discharge', TRUE),
('TESTICULAR_FINDING',       'coded',    'Testicular finding', TRUE),
('SCROTAL_SWELLING',         'coded',    'Scrotal swelling', TRUE),
('PENILE_LESION',            'coded',    'Penile lesion', TRUE),
('CVA_TENDERNESS',           'boolean',  'Costovertebral angle tenderness', TRUE),

-- Breast
('BREAST_SYMMETRY',          'coded',    'Breast symmetry', TRUE),
('BREAST_SKIN',              'coded',    'Breast skin', TRUE),
('NIPPLE_APPEARANCE',        'coded',    'Nipple appearance', TRUE),
('NIPPLE_DISCHARGE',         'coded',    'Nipple discharge', TRUE),
('BREAST_MASS',              'coded',    'Breast mass', TRUE),
('BREAST_TENDERNESS',        'boolean',  'Breast tenderness', TRUE),
('BREAST_NODES',             'coded',    'Regional lymph nodes', TRUE),

-- Head / neck
('PUPIL_SIZE',               'coded',    'Pupil size', TRUE),
('PUPIL_REACTION',            'coded',    'Pupillary reaction', TRUE),
('EYE_MOVEMENT',              'coded',    'Extraocular movements', TRUE),
('CONJUNCTIVA',               'coded',    'Conjunctival appearance', TRUE),
('SCLERA',                   'coded',    'Scleral appearance', TRUE),
('ORAL_MUCOSA',              'coded',    'Oral mucosa', TRUE),
('NECK_MASS',                'coded',    'Neck mass', TRUE),
('THYROID_SIZE',             'coded',    'Thyroid size', TRUE),
('THYROID_TEXTURE',          'coded',    'Thyroid texture', TRUE)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 5. RESPIRATORY EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-RESP-CHEST-SHAPE',
 'EXAM-RESPIRATORY','CHEST_SHAPE',
 'Chest shape','Chest shape','respiratory',
 FALSE,100,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-CHEST-MOVEMENT',
 'EXAM-RESPIRATORY','CHEST_MOVEMENT',
 'Chest movement','Chest movement','respiratory',
 FALSE,101,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-EXPANSION',
 'EXAM-RESPIRATORY','CHEST_EXPANSION',
 'Chest expansion','Expansion','respiratory',
 FALSE,102,
 ARRAY['PALPATION','MENSURATION'],
 ARRAY['measurement','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-TRACHEA',
 'EXAM-RESPIRATORY','TRACHEAL_POSITION',
 'Tracheal position','Trachea','respiratory',
 FALSE,103,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-FREMITUS',
 'EXAM-RESPIRATORY','TACTILE_FREMitus',
 'Tactile vocal fremitus','Fremitus','respiratory',
 FALSE,104,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-PERCUSSION',
 'EXAM-RESPIRATORY','PERCUSSION_NOTE',
 'Chest percussion','Percussion','respiratory',
 FALSE,105,
 ARRAY['PERCUSSION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-BREATH-SOUNDS',
 'EXAM-RESPIRATORY','BREATH_SOUND',
 'Breath sounds','Breath sounds','respiratory',
 FALSE,106,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-ADDED-SOUNDS',
 'EXAM-RESPIRATORY','ADDED_BREATH_SOUND',
 'Added breath sounds','Added sounds','respiratory',
 FALSE,107,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-VOCAL-RESONANCE',
 'EXAM-RESPIRATORY','VOCAL_RESONANCE',
 'Vocal resonance','Vocal resonance','respiratory',
 FALSE,108,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-RESP-PLEURAL-RUB',
 'EXAM-RESPIRATORY','PLEURAL_RUB',
 'Pleural friction rub','Pleural rub','respiratory',
 FALSE,109,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 6. CARDIOVASCULAR EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-CVS-JVP',
 'EXAM-CARDIOVASCULAR','JVP_HEIGHT',
 'Jugular venous pressure','JVP','cardiovascular',
 FALSE,200,
 ARRAY['INSPECTION'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-APEX',
 'EXAM-CARDIOVASCULAR','APEX_POSITION',
 'Apex beat','Apex','cardiovascular',
 FALSE,201,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-HEAVE',
 'EXAM-CARDIOVASCULAR','HEAVE',
 'Precordial heave','Heave','cardiovascular',
 FALSE,202,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-THRILL',
 'EXAM-CARDIOVASCULAR','THRILL',
 'Precordial thrill','Thrill','cardiovascular',
 FALSE,203,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-S1',
 'EXAM-CARDIOVASCULAR','HEART_SOUND_S1',
 'First heart sound','S1','cardiovascular',
 FALSE,204,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-S2',
 'EXAM-CARDIOVASCULAR','HEART_SOUND_S2',
 'Second heart sound','S2','cardiovascular',
 FALSE,205,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-ADDED',
 'EXAM-CARDIOVASCULAR','ADDITIONAL_HEART_SOUND',
 'Additional heart sounds','Added sounds','cardiovascular',
 FALSE,206,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-MURMUR',
 'EXAM-CARDIOVASCULAR','HEART_MURMUR',
 'Cardiac murmur','Murmur','cardiovascular',
 FALSE,207,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-CVS-PULSE',
 'EXAM-CARDIOVASCULAR','PULSE_VOLUME',
 'Peripheral pulse','Pulse','vascular',
 FALSE,208,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 7. ABDOMINAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-ABD-CONTOUR',
 'EXAM-ABDOMINAL','ABDOMINAL_CONTOUR',
 'Abdominal contour','Contour','gastrointestinal',
 FALSE,300,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-SCAR',
 'EXAM-ABDOMINAL','ABDOMINAL_SCAR',
 'Abdominal scars','Scars','gastrointestinal',
 FALSE,301,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-VEINS',
 'EXAM-ABDOMINAL','ABDOMINAL_VENOUS_PATTERN',
 'Abdominal venous pattern','Veins','gastrointestinal',
 FALSE,302,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-BOWEL',
 'EXAM-ABDOMINAL','BOWEL_SOUNDS',
 'Bowel sounds','Bowel sounds','gastrointestinal',
 FALSE,303,
 ARRAY['AUSCULTATION'],
 ARRAY['auscultation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-TENDERNESS',
 'EXAM-ABDOMINAL','ABDOMINAL_TENDERNESS',
 'Abdominal tenderness','Tenderness','gastrointestinal',
 FALSE,304,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-GUARDING',
 'EXAM-ABDOMINAL','GUARDING',
 'Guarding','Guarding','gastrointestinal',
 FALSE,305,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-RIGIDITY',
 'EXAM-ABDOMINAL','RIGIDITY',
 'Abdominal rigidity','Rigidity','gastrointestinal',
 FALSE,306,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-REBOUND',
 'EXAM-ABDOMINAL','REBOUND_TENDERNESS',
 'Rebound tenderness','Rebound','gastrointestinal',
 FALSE,307,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-MASS',
 'EXAM-ABDOMINAL','ABDOMINAL_MASS',
 'Abdominal mass','Mass','gastrointestinal',
 FALSE,308,
 ARRAY['PALPATION','PERCUSSION'],
 ARRAY['palpation','observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-LIVER',
 'EXAM-ABDOMINAL','LIVER_SIZE',
 'Liver examination','Liver','gastrointestinal',
 FALSE,309,
 ARRAY['PALPATION','PERCUSSION'],
 ARRAY['palpation','measurement'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-SPLEEN',
 'EXAM-ABDOMINAL','SPLENIC_ENLARGEMENT',
 'Spleen examination','Spleen','gastrointestinal',
 FALSE,310,
 ARRAY['PALPATION','PERCUSSION'],
 ARRAY['palpation','observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-KIDNEY',
 'EXAM-ABDOMINAL','KIDNEY_PALPABILITY',
 'Kidney examination','Kidneys','gastrointestinal',
 FALSE,311,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-ABD-ASCITES',
 'EXAM-ABDOMINAL','ASCITES',
 'Ascites','Ascites','gastrointestinal',
 FALSE,312,
 ARRAY['INSPECTION','PERCUSSION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 8. NEUROLOGICAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-NEURO-MENTAL',
 'EXAM-NEUROLOGICAL','MENTAL_STATUS',
 'Mental status','Mental status','neurological',
 FALSE,400,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-GCS',
 'EXAM-NEUROLOGICAL','GCS_TOTAL',
 'Glasgow Coma Scale','GCS','neurological',
 FALSE,401,
 ARRAY['INSPECTION'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-ORIENTATION',
 'EXAM-NEUROLOGICAL','ORIENTATION',
 'Orientation','Orientation','neurological',
 FALSE,402,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-SPEECH',
 'EXAM-NEUROLOGICAL','SPEECH',
 'Speech','Speech','neurological',
 FALSE,403,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-CRANIAL',
 'EXAM-NEUROLOGICAL','CRANIAL_NERVE_FINDING',
 'Cranial nerve examination','Cranial nerves','neurological',
 FALSE,404,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-POWER',
 'EXAM-NEUROLOGICAL','MOTOR_POWER',
 'Motor power','Power','neurological',
 FALSE,405,
 ARRAY['PALPATION'],
 ARRAY['measurement','examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-TONE',
 'EXAM-NEUROLOGICAL','MUSCLE_TONE',
 'Muscle tone','Tone','neurological',
 FALSE,406,
 ARRAY['PALPATION'],
 ARRAY['examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-BULK',
 'EXAM-NEUROLOGICAL','MUSCLE_BULK',
 'Muscle bulk','Bulk','neurological',
 FALSE,407,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-REFLEX',
 'EXAM-NEUROLOGICAL','REFLEX_FINDING',
 'Deep tendon reflexes','Reflexes','neurological',
 FALSE,408,
 ARRAY['PALPATION'],
 ARRAY['examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-PLANTAR',
 'EXAM-NEUROLOGICAL','PLANTAR_RESPONSE',
 'Plantar response','Plantar','neurological',
 FALSE,409,
 ARRAY['PALPATION'],
 ARRAY['examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-SENSORY',
 'EXAM-NEUROLOGICAL','LIGHT_TOUCH',
 'Sensory examination','Sensation','neurological',
 FALSE,410,
 ARRAY['PALPATION'],
 ARRAY['examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-COORDINATION',
 'EXAM-NEUROLOGICAL','COORDINATION',
 'Coordination','Coordination','neurological',
 FALSE,411,
 ARRAY['PALPATION'],
 ARRAY['examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-GAIT',
 'EXAM-NEUROLOGICAL','GAIT',
 'Gait','Gait','neurological',
 FALSE,412,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-NEURO-ROMBERG',
 'EXAM-NEUROLOGICAL','ROMBERG',
 'Romberg test','Romberg','neurological',
 FALSE,413,
 ARRAY['INSPECTION'],
 ARRAY['examination'],
 ARRAY['age_over_5_years'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 9. MUSCULOSKELETAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-MSK-SWELLING',
 'EXAM-MSK','JOINT_SWELLING',
 'Joint swelling','Swelling','musculoskeletal',
 FALSE,500,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-MSK-TENDERNESS',
 'EXAM-MSK','JOINT_TENDERNESS',
 'Joint tenderness','Tenderness','musculoskeletal',
 FALSE,501,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-MSK-WARMTH',
 'EXAM-MSK','JOINT_WARMTH',
 'Joint warmth','Warmth','musculoskeletal',
 FALSE,502,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-MSK-DEFORMITY',
 'EXAM-MSK','JOINT_DEFORMITY',
 'Joint deformity','Deformity','musculoskeletal',
 FALSE,503,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-MSK-ROM',
 'EXAM-MSK','JOINT_RANGE_ACTIVE',
 'Range of movement','ROM','musculoskeletal',
 FALSE,504,
 ARRAY['PALPATION'],
 ARRAY['examination'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-MSK-CREPITUS',
 'EXAM-MSK','CREPITUS',
 'Crepitus','Crepitus','musculoskeletal',
 FALSE,505,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-MSK-MUSCLE',
 'EXAM-MSK','MUSCLE_TENDERNESS',
 'Muscle examination','Muscles','musculoskeletal',
 FALSE,506,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 10. PERIPHERAL VASCULAR EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-VASC-PULSES',
 'EXAM-VASCULAR','PERIPHERAL_PULSES',
 'Peripheral pulses','Pulses','vascular',
 FALSE,600,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-VASC-TEMP',
 'EXAM-VASCULAR','LIMB_TEMPERATURE',
 'Limb temperature','Temperature','vascular',
 FALSE,601,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-VASC-CAPREFILL',
 'EXAM-VASCULAR','CAPILLARY_REFILL',
 'Peripheral capillary refill','Cap refill','vascular',
 FALSE,602,
 ARRAY['PALPATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-VASC-VARICOSE',
 'EXAM-VASCULAR','VARICOSITIES',
 'Varicose veins','Varicosities','vascular',
 FALSE,603,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-VASC-EDEMA',
 'EXAM-VASCULAR','VENOUS_EDEMA',
 'Peripheral edema','Edema','vascular',
 FALSE,604,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-VASC-TROPHIC',
 'EXAM-VASCULAR','ARTERIAL_TROPHIC_CHANGE',
 'Arterial trophic changes','Trophic changes','vascular',
 FALSE,605,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 11. GENITOURINARY EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-GU-EXTERNAL',
 'EXAM-GU','GENITAL_APPEARANCE',
 'External genital examination','External genitalia','genitourinary',
 FALSE,700,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-GU-DISCHARGE',
 'EXAM-GU','URETHRAL_DISCHARGE',
 'Urethral discharge','Discharge','genitourinary',
 FALSE,701,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-GU-TESTIS',
 'EXAM-GU','TESTICULAR_FINDING',
 'Testicular examination','Testes','genitourinary',
 FALSE,702,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['male'],'active'),

('EXAM-CON-GU-SCROTUM',
 'EXAM-GU','SCROTAL_SWELLING',
 'Scrotal examination','Scrotum','genitourinary',
 FALSE,703,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['male'],'active'),

('EXAM-CON-GU-PENIS',
 'EXAM-GU','PENILE_LESION',
 'Penile examination','Penis','genitourinary',
 FALSE,704,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['male'],'active'),

('EXAM-CON-GU-CVA',
 'EXAM-GU','CVA_TENDERNESS',
 'Costovertebral angle examination','CVA','genitourinary',
 FALSE,705,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 12. BREAST EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-BREAST-SYMMETRY',
 'EXAM-BREAST','BREAST_SYMMETRY',
 'Breast symmetry','Symmetry','breast',
 FALSE,800,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['female'],'active'),

('EXAM-CON-BREAST-SKIN',
 'EXAM-BREAST','BREAST_SKIN',
 'Breast skin','Skin','breast',
 FALSE,801,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['female'],'active'),

('EXAM-CON-BREAST-NIPPLE',
 'EXAM-BREAST','NIPPLE_APPEARANCE',
 'Nipple examination','Nipple','breast',
 FALSE,802,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['female'],'active'),

('EXAM-CON-BREAST-DISCHARGE',
 'EXAM-BREAST','NIPPLE_DISCHARGE',
 'Nipple discharge','Discharge','breast',
 FALSE,803,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation'],
 ARRAY['female'],'active'),

('EXAM-CON-BREAST-MASS',
 'EXAM-BREAST','BREAST_MASS',
 'Breast mass','Mass','breast',
 FALSE,804,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['female'],'active'),

('EXAM-CON-BREAST-TENDER',
 'EXAM-BREAST','BREAST_TENDERNESS',
 'Breast tenderness','Tenderness','breast',
 FALSE,805,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['female'],'active'),

('EXAM-CON-BREAST-NODES',
 'EXAM-BREAST','BREAST_NODES',
 'Regional lymph nodes','Nodes','breast',
 FALSE,806,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['female'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 13. HEAD / NECK EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_concept
  (code, domain_code, fact_definition_code, name, short_label,
   body_system_code, is_mandatory, base_priority,
   technique_codes, capture_method_codes,
   applies_to_context_codes, status)
VALUES

('EXAM-CON-HN-PUPILS',
 'EXAM-HEAD-NECK','PUPIL_REACTION',
 'Pupils','Pupils','head_neck',
 FALSE,900,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-HN-EOM',
 'EXAM-HEAD-NECK','EYE_MOVEMENT',
 'Extraocular movements','Eye movements','head_neck',
 FALSE,901,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-HN-CONJUNCTIVA',
 'EXAM-HEAD-NECK','CONJUNCTIVA',
 'Conjunctiva','Conjunctiva','head_neck',
 FALSE,902,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-HN-SCLERA',
 'EXAM-HEAD-NECK','SCLERA',
 'Sclera','Sclera','head_neck',
 FALSE,903,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-HN-ORAL',
 'EXAM-HEAD-NECK','ORAL_MUCOSA',
 'Oral mucosa','Mucosa','head_neck',
 FALSE,904,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-HN-NECK',
 'EXAM-HEAD-NECK','NECK_MASS',
 'Neck examination','Neck','head_neck',
 FALSE,905,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active'),

('EXAM-CON-HN-THYROID',
 'EXAM-HEAD-NECK','THYROID_SIZE',
 'Thyroid examination','Thyroid','head_neck',
 FALSE,906,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],'active')

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 14. STANDARD RESPIRATORY FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-RESP-CHEST-SHAPE',
 'CHEST_NORMAL',
 'Normal chest shape',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-RESP-CHEST-SHAPE',
 'CHEST_BARREL',
 'Barrel-shaped chest',
 'SIGN_MILD',
 'barrel',
 2),

('EXAM-CON-RESP-CHEST-SHAPE',
 'CHEST_PIGEON',
 'Pigeon chest',
 'SIGN_MILD',
 'pectus_carinatum',
 3),

('EXAM-CON-RESP-CHEST-SHAPE',
 'CHEST_FUNNEL',
 'Funnel chest',
 'SIGN_MILD',
 'pectus_excavatum',
 4),

('EXAM-CON-RESP-TRACHEA',
 'TRACHEA_CENTRAL',
 'Central',
 'SIGN_ABSENT',
 'central',
 1),

('EXAM-CON-RESP-TRACHEA',
 'TRACHEA_DEVIATED_RIGHT',
 'Deviated to the right',
 'SIGN_MODERATE',
 'right',
 2),

('EXAM-CON-RESP-TRACHEA',
 'TRACHEA_DEVIATED_LEFT',
 'Deviated to the left',
 'SIGN_MODERATE',
 'left',
 3),

('EXAM-CON-RESP-PERCUSSION',
 'PERC_RESONANT',
 'Resonant',
 'SIGN_ABSENT',
 'resonant',
 1),

('EXAM-CON-RESP-PERCUSSION',
 'PERC_DULL',
 'Dull',
 'SIGN_MODERATE',
 'dull',
 2),

('EXAM-CON-RESP-PERCUSSION',
 'PERC_STONY_DULL',
 'Stony dull',
 'SIGN_SEVERE',
 'stony_dull',
 3),

('EXAM-CON-RESP-PERCUSSION',
 'PERC_HYPER',
 'Hyper-resonant',
 'SIGN_MODERATE',
 'hyperresonant',
 4),

('EXAM-CON-RESP-BREATH-SOUNDS',
 'BS_VESICULAR',
 'Vesicular',
 'SIGN_ABSENT',
 'vesicular',
 1),

('EXAM-CON-RESP-BREATH-SOUNDS',
 'BS_BRONCHIAL',
 'Bronchial',
 'SIGN_MODERATE',
 'bronchial',
 2),

('EXAM-CON-RESP-BREATH-SOUNDS',
 'BS_REDUCED',
 'Reduced',
 'SIGN_MODERATE',
 'reduced',
 3),

('EXAM-CON-RESP-BREATH-SOUNDS',
 'BS_ABSENT',
 'Absent',
 'SIGN_SEVERE',
 'absent',
 4),

('EXAM-CON-RESP-ADDED-SOUNDS',
 'ADDED_NONE',
 'No added sounds',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-RESP-ADDED-SOUNDS',
 'ADDED_CRACKLES',
 'Crackles',
 'SIGN_MODERATE',
 'crackles',
 2),

('EXAM-CON-RESP-ADDED-SOUNDS',
 'ADDED_WHEEZE',
 'Wheeze',
 'SIGN_MODERATE',
 'wheeze',
 3),

('EXAM-CON-RESP-ADDED-SOUNDS',
 'ADDED_RHONCHI',
 'Rhonchi',
 'SIGN_MILD',
 'rhonchi',
 4),

('EXAM-CON-RESP-ADDED-SOUNDS',
 'ADDED_STRIDOR',
 'Stridor',
 'SIGN_SEVERE',
 'stridor',
 5),

('EXAM-CON-RESP-PLEURAL-RUB',
 'PLEURAL_RUB_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-RESP-PLEURAL-RUB',
 'PLEURAL_RUB_PRESENT',
 'Present',
 'SIGN_MODERATE',
 'present',
 2)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 15. CARDIOVASCULAR FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-CVS-APEX',
 'APEX_NORMAL',
 '5th intercostal space, mid-clavicular line',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-CVS-APEX',
 'APEX_DISPLACED_LATERAL',
 'Laterally displaced',
 'SIGN_MODERATE',
 'lateral_displacement',
 2),

('EXAM-CON-CVS-APEX',
 'APEX_DISPLACED_INFERIOR',
 'Inferior displacement',
 'SIGN_MODERATE',
 'inferior_displacement',
 3),

('EXAM-CON-CVS-HEAVE',
 'HEAVE_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-CVS-HEAVE',
 'HEAVE_PRESENT',
 'Present',
 'SIGN_MODERATE',
 'present',
 2),

('EXAM-CON-CVS-THRILL',
 'THRILL_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-CVS-THRILL',
 'THRILL_PRESENT',
 'Present',
 'SIGN_SEVERE',
 'present',
 2),

('EXAM-CON-CVS-S1',
 'S1_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-CVS-S1',
 'S1_LOUD',
 'Loud',
 'SIGN_MILD',
 'loud',
 2),

('EXAM-CON-CVS-S1',
 'S1_SOFT',
 'Soft',
 'SIGN_MILD',
 'soft',
 3),

('EXAM-CON-CVS-S2',
 'S2_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-CVS-S2',
 'S2_LOUD',
 'Loud',
 'SIGN_MILD',
 'loud',
 2),

('EXAM-CON-CVS-S2',
 'S2_SPLIT',
 'Split',
 'SIGN_MODERATE',
 'split',
 3),

('EXAM-CON-CVS-ADDED',
 'ADDED_HEART_NONE',
 'None',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-CVS-ADDED',
 'ADDED_S3',
 'S3',
 'SIGN_MODERATE',
 's3',
 2),

('EXAM-CON-CVS-ADDED',
 'ADDED_S4',
 'S4',
 'SIGN_MODERATE',
 's4',
 3),

('EXAM-CON-CVS-MURMUR',
 'MURMUR_NONE',
 'No murmur',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-CVS-MURMUR',
 'MURMUR_PRESENT',
 'Murmur present',
 'SIGN_MODERATE',
 'present',
 2),

('EXAM-CON-CVS-PULSE',
 'PULSE_NORMAL',
 'Normal volume and rhythm',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-CVS-PULSE',
 'PULSE_WEAK',
 'Weak',
 'SIGN_MODERATE',
 'weak',
 2),

('EXAM-CON-CVS-PULSE',
 'PULSE_BOUNDING',
 'Bounding',
 'SIGN_MODERATE',
 'bounding',
 3),

('EXAM-CON-CVS-PULSE',
 'PULSE_IRREGULAR',
 'Irregular',
 'SIGN_MODERATE',
 'irregular',
 4)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 16. ABDOMINAL FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-ABD-CONTOUR',
 'ABD_FLAT',
 'Flat',
 'SIGN_ABSENT',
 'flat',
 1),

('EXAM-CON-ABD-CONTOUR',
 'ABD_DISTENDED',
 'Distended',
 'SIGN_MODERATE',
 'distended',
 2),

('EXAM-CON-ABD-CONTOUR',
 'ABD_SCAPHOID',
 'Scaphoid',
 'SIGN_MODERATE',
 'scaphoid',
 3),

('EXAM-CON-ABD-BOWEL',
 'BOWEL_NORMAL',
 'Normal bowel sounds',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-ABD-BOWEL',
 'BOWEL_REDUCED',
 'Reduced',
 'SIGN_MODERATE',
 'reduced',
 2),

('EXAM-CON-ABD-BOWEL',
 'BOWEL_ABSENT',
 'Absent',
 'SIGN_SEVERE',
 'absent',
 3),

('EXAM-CON-ABD-BOWEL',
 'BOWEL_HYPERACTIVE',
 'Hyperactive',
 'SIGN_MILD',
 'hyperactive',
 4),

('EXAM-CON-ABD-TENDERNESS',
 'ABD_TENDER_NONE',
 'No tenderness',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-ABD-TENDERNESS',
 'ABD_TENDER_MILD',
 'Mild tenderness',
 'SIGN_MILD',
 'mild',
 2),

('EXAM-CON-ABD-TENDERNESS',
 'ABD_TENDER_MOD',
 'Moderate tenderness',
 'SIGN_MODERATE',
 'moderate',
 3),

('EXAM-CON-ABD-TENDERNESS',
 'ABD_TENDER_SEVERE',
 'Severe tenderness',
 'SIGN_SEVERE',
 'severe',
 4),

('EXAM-CON-ABD-GUARDING',
 'GUARDING_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-ABD-GUARDING',
 'GUARDING_PRESENT',
 'Present',
 'SIGN_SEVERE',
 'present',
 2),

('EXAM-CON-ABD-RIGIDITY',
 'RIGIDITY_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-ABD-RIGIDITY',
 'RIGIDITY_PRESENT',
 'Present',
 'SIGN_SEVERE',
 'present',
 2),

('EXAM-CON-ABD-REBOUND',
 'REBOUND_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-ABD-REBOUND',
 'REBOUND_PRESENT',
 'Present',
 'SIGN_SEVERE',
 'present',
 2),

('EXAM-CON-ABD-ASCITES',
 'ASCITES_NONE',
 'No clinical ascites',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-ABD-ASCITES',
 'ASCITES_PRESENT',
 'Ascites present',
 'SIGN_MODERATE',
 'present',
 2)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 17. NEUROLOGICAL FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-NEURO-MENTAL',
 'MENTAL_ALERT',
 'Alert',
 'SIGN_ABSENT',
 'alert',
 1),

('EXAM-CON-NEURO-MENTAL',
 'MENTAL_CONFUSED',
 'Confused',
 'SIGN_MODERATE',
 'confused',
 2),

('EXAM-CON-NEURO-MENTAL',
 'MENTAL_DROWSY',
 'Drowsy',
 'SIGN_MODERATE',
 'drowsy',
 3),

('EXAM-CON-NEURO-MENTAL',
 'MENTAL_UNRESPONSIVE',
 'Unresponsive',
 'SIGN_SEVERE',
 'unresponsive',
 4),

('EXAM-CON-NEURO-TONE',
 'TONE_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-NEURO-TONE',
 'TONE_HYPO',
 'Hypotonia',
 'SIGN_MODERATE',
 'hypotonia',
 2),

('EXAM-CON-NEURO-TONE',
 'TONE_HYPER',
 'Hypertonia',
 'SIGN_MODERATE',
 'hypertonia',
 3),

('EXAM-CON-NEURO-BULK',
 'BULK_NORMAL',
 'Normal bulk',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-NEURO-BULK',
 'BULK_WASTING',
 'Wasting',
 'SIGN_MODERATE',
 'wasting',
 2),

('EXAM-CON-NEURO-BULK',
 'BULK_HYPERTROPHY',
 'Hypertrophy',
 'SIGN_MILD',
 'hypertrophy',
 3),

('EXAM-CON-NEURO-PLANTAR',
 'PLANTAR_DOWN',
 'Flexor',
 'SIGN_ABSENT',
 'flexor',
 1),

('EXAM-CON-NEURO-PLANTAR',
 'PLANTAR_UP',
 'Extensor',
 'SIGN_SEVERE',
 'extensor',
 2),

('EXAM-CON-NEURO-GAIT',
 'GAIT_NORMAL',
 'Normal gait',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-NEURO-GAIT',
 'GAIT_ATAXIC',
 'Ataxic',
 'SIGN_MODERATE',
 'ataxic',
 2),

('EXAM-CON-NEURO-GAIT',
 'GAIT_HEMIPARETIC',
 'Hemiparetic',
 'SIGN_MODERATE',
 'hemiparetic',
 3),

('EXAM-CON-NEURO-GAIT',
 'GAIT_PARKINSONIAN',
 'Parkinsonian',
 'SIGN_MODERATE',
 'parkinsonian',
 4)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 18. MUSCULOSKELETAL FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-MSK-SWELLING',
 'JOINT_NO_SWELLING',
 'No swelling',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-MSK-SWELLING',
 'JOINT_MILD_SWELLING',
 'Mild swelling',
 'SIGN_MILD',
 'mild',
 2),

('EXAM-CON-MSK-SWELLING',
 'JOINT_MOD_SWELLING',
 'Moderate swelling',
 'SIGN_MODERATE',
 'moderate',
 3),

('EXAM-CON-MSK-SWELLING',
 'JOINT_SEV_SWELLING',
 'Marked swelling',
 'SIGN_SEVERE',
 'severe',
 4),

('EXAM-CON-MSK-WARMTH',
 'JOINT_WARMTH_NONE',
 'No increased warmth',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-MSK-WARMTH',
 'JOINT_WARMTH_PRESENT',
 'Increased warmth',
 'SIGN_MODERATE',
 'increased',
 2),

('EXAM-CON-MSK-DEFORMITY',
 'JOINT_NO_DEFORMITY',
 'No deformity',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-MSK-DEFORMITY',
 'JOINT_DEFORMITY_PRESENT',
 'Deformity present',
 'SIGN_MODERATE',
 'present',
 2),

('EXAM-CON-MSK-CREPITUS',
 'CREPITUS_ABSENT',
 'Absent',
 'SIGN_ABSENT',
 'absent',
 1),

('EXAM-CON-MSK-CREPITUS',
 'CREPITUS_PRESENT',
 'Present',
 'SIGN_MODERATE',
 'present',
 2)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 19. VASCULAR FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-VASC-PULSES',
 'PULSES_PRESENT',
 'Pulses palpable',
 'SIGN_ABSENT',
 'present',
 1),

('EXAM-CON-VASC-PULSES',
 'PULSES_REDUCED',
 'Reduced',
 'SIGN_MODERATE',
 'reduced',
 2),

('EXAM-CON-VASC-PULSES',
 'PULSES_ABSENT',
 'Absent',
 'SIGN_SEVERE',
 'absent',
 3),

('EXAM-CON-VASC-TEMP',
 'LIMB_WARM',
 'Warm',
 'SIGN_ABSENT',
 'warm',
 1),

('EXAM-CON-VASC-TEMP',
 'LIMB_COOL',
 'Cool',
 'SIGN_MODERATE',
 'cool',
 2),

('EXAM-CON-VASC-TEMP',
 'LIMB_COLD',
 'Cold',
 'SIGN_SEVERE',
 'cold',
 3),

('EXAM-CON-VASC-VARICOSE',
 'VARICOSE_NONE',
 'No varicosities',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-VASC-VARICOSE',
 'VARICOSE_PRESENT',
 'Varicosities present',
 'SIGN_MODERATE',
 'present',
 2),

('EXAM-CON-VASC-EDEMA',
 'VASC_EDEMA_NONE',
 'No edema',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-VASC-EDEMA',
 'VASC_EDEMA_PRESENT',
 'Edema present',
 'SIGN_MODERATE',
 'present',
 2)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 20. BREAST FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-BREAST-SYMMETRY',
 'BREAST_SYMMETRIC',
 'Symmetrical',
 'SIGN_ABSENT',
 'symmetric',
 1),

('EXAM-CON-BREAST-SYMMETRY',
 'BREAST_ASYMMETRIC',
 'Asymmetrical',
 'SIGN_MODERATE',
 'asymmetric',
 2),

('EXAM-CON-BREAST-SKIN',
 'BREAST_SKIN_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-BREAST-SKIN',
 'BREAST_SKIN_DIMPLE',
 'Dimpling / tethering',
 'SIGN_MODERATE',
 'dimpling',
 2),

('EXAM-CON-BREAST-SKIN',
 'BREAST_SKIN_PE_DORANGE',
 'Peau d''orange',
 'SIGN_SEVERE',
 'peau_d_orange',
 3),

('EXAM-CON-BREAST-NIPPLE',
 'NIPPLE_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-BREAST-NIPPLE',
 'NIPPLE_RETRACTED',
 'Retracted',
 'SIGN_MODERATE',
 'retracted',
 2),

('EXAM-CON-BREAST-NIPPLE',
 'NIPPLE_INVERTED',
 'Inverted',
 'SIGN_MILD',
 'inverted',
 3),

('EXAM-CON-BREAST-DISCHARGE',
 'NIPPLE_NO_DISCHARGE',
 'No discharge',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-BREAST-DISCHARGE',
 'NIPPLE_DISCHARGE_PRESENT',
 'Discharge present',
 'SIGN_MODERATE',
 'present',
 2),

('EXAM-CON-BREAST-MASS',
 'BREAST_NO_MASS',
 'No mass',
 'SIGN_ABSENT',
 'none',
 1),

('EXAM-CON-BREAST-MASS',
 'BREAST_MASS_PRESENT',
 'Mass present',
 'SIGN_MODERATE',
 'present',
 2)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 21. HEAD / NECK FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
  (examination_concept_code, answer_code, label,
   interpretation_code, value_text, sort_order)
VALUES

('EXAM-CON-HN-PUPILS',
 'PUPILS_EQUAL_REACTIVE',
 'Equal and reactive',
 'SIGN_ABSENT',
 'equal_reactive',
 1),

('EXAM-CON-HN-PUPILS',
 'PUPILS_ANISOCORIA',
 'Unequal pupils',
 'SIGN_MODERATE',
 'anisocoria',
 2),

('EXAM-CON-HN-EOM',
 'EOM_NORMAL',
 'Full and normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-HN-EOM',
 'EOM_ABNORMAL',
 'Abnormal eye movement',
 'SIGN_MODERATE',
 'abnormal',
 2),

('EXAM-CON-HN-CONJUNCTIVA',
 'CONJ_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-HN-CONJUNCTIVA',
 'CONJ_PALE',
 'Pale',
 'SIGN_MODERATE',
 'pale',
 2),

('EXAM-CON-HN-CONJUNCTIVA',
 'CONJ_INJECTED',
 'Injected',
 'SIGN_MODERATE',
 'injected',
 3),

('EXAM-CON-HN-SCLERA',
 'SCLERA_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-HN-SCLERA',
 'SCLERA_ICTERIC',
 'Icteric',
 'SIGN_MODERATE',
 'icteric',
 2),

('EXAM-CON-HN-NECK',
 'NECK_NORMAL',
 'No abnormality',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-HN-NECK',
 'NECK_MASS',
 'Neck mass',
 'SIGN_MODERATE',
 'mass',
 2),

('EXAM-CON-HN-THYROID',
 'THYROID_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1),

('EXAM-CON-HN-THYROID',
 'THYROID_ENLARGED',
 'Enlarged',
 'SIGN_MODERATE',
 'enlarged',
 2)

ON CONFLICT (examination_concept_code, answer_code) DO NOTHING;


-- =============================================================================
-- 22. EXAMINATION MODULE MEMBERSHIP
-- =============================================================================
--
-- Every systemic concept is attached to its examination module.
--
-- This permits the UI to render:
--
--   Examination
--      ├── General
--      ├── Vitals
--      ├── Systemic signs
--      ├── Respiratory
--      ├── Cardiovascular
--      ├── Abdomen
--      ├── Neurological
--      ├── Musculoskeletal
--      ├── Vascular
--      ├── GU
--      ├── Breast
--      └── Head & Neck
--
-- without hard-coding every concept into React.
-- =============================================================================

INSERT INTO knowledge.question_module_member
  (module_code, question_id, sort_order)
SELECT
  'EXAMINATION',
  q.id,
  q.priority
FROM knowledge.question q
WHERE FALSE
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 23. SYSTEMIC EXAMINATION CONDITION TRIGGERS
-- =============================================================================
--
-- These are intentionally conservative.
--
-- A condition should REQUEST an examination pathway; it should never fabricate
-- an examination finding.
--
-- The actual condition identifiers are attached only when present in the
-- knowledge base.
-- =============================================================================

INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-RESPIRATORY-DISEASE',
    'CONDITION-PNEUMONIA',
    'CONDITION-ASTHMA',
    'CONDITION-COPD',
    'CONDITION-PLEURAL-DISEASE',
    'CONDITION-TB'
  )
WHERE em.module_code = 'EXAM-RESPIRATORY'
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-CARDIAC-DISEASE',
    'CONDITION-HEART-FAILURE',
    'CONDITION-HYPERTENSION',
    'CONDITION-VALVULAR-HEART-DISEASE'
  )
WHERE em.module_code = 'EXAM-CARDIOVASCULAR'
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-GI-DISEASE',
    'CONDITION-ACUTE-ABDOMEN',
    'CONDITION-LIVER-DISEASE',
    'CONDITION-ASCITES'
  )
WHERE em.module_code = 'EXAM-ABDOMINAL'
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-NEUROLOGICAL-DISEASE',
    'CONDITION-STROKE',
    'CONDITION-SEIZURE',
    'CONDITION-MENINGITIS'
  )
WHERE em.module_code = 'EXAM-NEUROLOGICAL'
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-MSK-DISEASE',
    'CONDITION-ARTHRITIS',
    'CONDITION-FRACTURE',
    'CONDITION-JOINT-DISEASE'
  )
WHERE em.module_code = 'EXAM-MSK'
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-VASCULAR-DISEASE',
    'CONDITION-PERIPHERAL-ARTERIAL-DISEASE',
    'CONDITION-VENOUS-DISEASE'
  )
WHERE em.module_code = 'EXAM-VASCULAR'
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.examination_condition
  (examination_module_id, condition_id, weight)
SELECT
  em.id,
  c.id,
  1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN (
    'CONDITION-BREAST-DISEASE',
    'CONDITION-BREAST-MASS',
    'CONDITION-BREAST-CANCER'
  )
WHERE em.module_code = 'EXAM-BREAST'
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 24. EXAMINATION KNOWLEDGE BASE INTEGRITY CHECKS
-- =============================================================================

-- Every active systemic concept should have a body system.
DO $$
DECLARE
  missing_count integer;
BEGIN
  SELECT COUNT(*)
  INTO missing_count
  FROM knowledge.examination_concept ec
  LEFT JOIN knowledge.body_system bs
    ON bs.code = ec.body_system_code
  WHERE ec.status = 'active'
    AND ec.domain_code IN (
      'EXAM-RESPIRATORY',
      'EXAM-CARDIOVASCULAR',
      'EXAM-ABDOMINAL',
      'EXAM-NEUROLOGICAL',
      'EXAM-MSK',
      'EXAM-VASCULAR',
      'EXAM-GU',
      'EXAM-BREAST',
      'EXAM-HEAD-NECK'
    )
    AND bs.code IS NULL;

  IF missing_count > 0 THEN
    RAISE EXCEPTION
      '046 integrity failure: % active examination concepts have no body system',
      missing_count;
  END IF;
END $$;


-- Every active examination concept should have a fact definition.
DO $$
DECLARE
  missing_count integer;
BEGIN
  SELECT COUNT(*)
  INTO missing_count
  FROM knowledge.examination_concept ec
  LEFT JOIN clinical.fact_definition fd
    ON fd.code = ec.fact_definition_code
  WHERE ec.status = 'active'
    AND ec.domain_code IN (
      'EXAM-RESPIRATORY',
      'EXAM-CARDIOVASCULAR',
      'EXAM-ABDOMINAL',
      'EXAM-NEUROLOGICAL',
      'EXAM-MSK',
      'EXAM-VASCULAR',
      'EXAM-GU',
      'EXAM-BREAST',
      'EXAM-HEAD-NECK'
    )
    AND fd.code IS NULL;

  IF missing_count > 0 THEN
    RAISE EXCEPTION
      '046 integrity failure: % examination concepts have no fact definition',
      missing_count;
  END IF;
END $$;


-- Every active finding option must point to an existing interpretation.
DO $$
DECLARE
  missing_count integer;
BEGIN
  SELECT COUNT(*)
  INTO missing_count
  FROM knowledge.examination_finding_option efo
  LEFT JOIN knowledge.finding_interpretation fi
    ON fi.code = efo.interpretation_code
  WHERE efo.is_active = TRUE
    AND fi.code IS NULL;

  IF missing_count > 0 THEN
    RAISE EXCEPTION
      '046 integrity failure: % finding options have invalid interpretations',
      missing_count;
  END IF;
END $$;


-- =============================================================================
-- 25. SUMMARY
-- =============================================================================

SELECT
  '046_systemic_examination_knowledge_base' AS migration,
  (
    SELECT COUNT(*)
    FROM knowledge.examination_concept
    WHERE domain_code IN (
      'EXAM-RESPIRATORY',
      'EXAM-CARDIOVASCULAR',
      'EXAM-ABDOMINAL',
      'EXAM-NEUROLOGICAL',
      'EXAM-MSK',
      'EXAM-VASCULAR',
      'EXAM-GU',
      'EXAM-BREAST',
      'EXAM-HEAD-NECK'
    )
  ) AS systemic_concepts,
  (
    SELECT COUNT(*)
    FROM knowledge.examination_finding_option
    WHERE examination_concept_code LIKE 'EXAM-CON-%'
  ) AS finding_options;

COMMIT;