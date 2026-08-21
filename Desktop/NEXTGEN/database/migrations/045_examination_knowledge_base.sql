-- =============================================================================
-- AMEXAN UNIVERSAL ENTRY / CLINICAL OS
-- MIGRATION 045 â€” COMPREHENSIVE EXAMINATION KNOWLEDGE BASE
--
-- PURPOSE
-- -------
-- Establish the foundational knowledge layer for the AMEXAN clinical
-- examination engine.
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. Examination is observation/documentation first.
-- 2. Interpretation is generated from captured observations/measurements.
-- 3. Disease-specific examination is NOT hard-coded into the UI.
-- 4. Age, sex and clinical context determine applicability.
-- 5. Paediatric anthropometry is reference-driven, not guessed from adult
--    ranges or isolated "normal weight" values.
-- 6. Vital signs have age-aware interpretation.
-- 7. Positive findings can trigger deeper/systemic examination.
-- 8. Local/surgical examination is conditional.
-- 9. Every finding remains traceable to a coded fact.
-- 10. The knowledge layer must support adult medicine, paediatrics,
--     O&G, surgery, emergency medicine and subspecialty examination.
--
-- IMPORTANT
-- ---------
-- This migration assumes the foundational examination schema already exists:
--
--   knowledge.body_system
--   knowledge.examination_domain
--   knowledge.examination_technique
--   knowledge.examination_site
--   knowledge.examination_concept
--   knowledge.finding_interpretation
--   knowledge.examination_module
--   knowledge.examination_condition
--   knowledge.condition
--
-- It also assumes:
--
--   clinical.fact_definition
--
-- already exists.
--
-- =============================================================================

BEGIN;

-- =============================================================================
-- 0. EXTENSIONS / SAFETY
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- =============================================================================
-- 1. NORMAL RANGE / INTERPRETATION TABLE
-- =============================================================================
--
-- This table deliberately stores reference information rather than pretending
-- that one universal "normal" value exists.
--
-- For paediatric growth, AMEXAN should ultimately use WHO LMS/z-score tables
-- rather than only fixed min/max values. This migration therefore provides the
-- structural layer while allowing exact reference tables to be added later.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.normal_range (
    code                           text PRIMARY KEY,

    measurement_code               text NOT NULL,

    label                          text NOT NULL,

    value_type                     text NOT NULL
        CHECK (
            value_type IN (
                'measurement',
                'interpretation'
            )
        ),

    age_min_months                 integer,

    age_max_months                 integer,

    sex                            text NOT NULL DEFAULT 'all'
        CHECK (
            sex IN ('all','male','female')
        ),

    min_value                      numeric,

    max_value                      numeric,

    unit                           text,

    normal_text                    text,

    abnormal_interpretation_code   text,

    sort_order                     integer NOT NULL DEFAULT 0,

    reference_source               text,

    reference_version              text,

    is_active                      boolean NOT NULL DEFAULT TRUE,

    CONSTRAINT ck_normal_range_age
        CHECK (
            age_min_months IS NULL
            OR age_max_months IS NULL
            OR age_min_months <= age_max_months
        )
);

COMMENT ON TABLE knowledge.normal_range IS
'Age/sex/context-aware reference ranges and interpretation rules for clinical measurements.';


-- =============================================================================
-- 2. EXAMINATION FINDING OPTIONS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.examination_finding_option CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.examination_finding_option (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    examination_concept_code   text NOT NULL
        REFERENCES knowledge.examination_concept(code)
        ON DELETE CASCADE,

    answer_code                text NOT NULL,

    label                      text NOT NULL,

    interpretation_code        text NOT NULL
        REFERENCES knowledge.finding_interpretation(code),

    value_text                 text,

    sort_order                 integer NOT NULL DEFAULT 0,

    is_active                  boolean NOT NULL DEFAULT TRUE,

    CONSTRAINT ux_exam_finding_option
        UNIQUE (
            examination_concept_code,
            answer_code
        )
);

COMMENT ON TABLE knowledge.examination_finding_option IS
'Controlled answer vocabulary for examination concepts, including graded signs and categorical observations.';


-- =============================================================================
-- 3. BODY SYSTEMS
-- =============================================================================

INSERT INTO knowledge.body_system
(
    code,
    label,
    description
)
VALUES

('general',
 'General',
 'General physical examination'),

('neuro',
 'Neurological',
 'Neurological examination'),

('respiratory',
 'Respiratory',
 'Respiratory system examination'),

('cardiovascular',
 'Cardiovascular',
 'Cardiovascular system examination'),

('gastrointestinal',
 'Gastrointestinal',
 'Gastrointestinal and abdominal examination'),

('genitourinary',
 'Genitourinary',
 'Genitourinary examination'),

('reproductive',
 'Reproductive',
 'Male and female reproductive examination'),

('obstetric',
 'Obstetric',
 'Pregnancy and obstetric examination'),

('breast',
 'Breast',
 'Breast and axillary examination'),

('skin',
 'Skin',
 'Skin and integumentary examination'),

('head_neck',
 'Head & Neck',
 'Head and neck examination'),

('mouth',
 'Mouth',
 'Oral cavity and dental examination'),

('eye',
 'Ophthalmic',
 'Eye examination'),

('ear',
 'Otologic',
 'Ear examination'),

('lymph',
 'Lymphatic',
 'Lymph node examination'),

('vascular',
 'Vascular',
 'Peripheral vascular examination'),

('musculoskeletal',
 'Musculoskeletal',
 'Bones, joints, muscles and soft tissue'),

('endocrine',
 'Endocrine',
 'Endocrine physical signs'),

('haematologic',
 'Haematological',
 'Clinical signs of haematological disease'),

('paediatric',
 'Paediatric',
 'Paediatric examination'),

('neonatal',
 'Neonatal',
 'Neonatal examination')

ON CONFLICT (code)
DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description;


-- =============================================================================
-- 4. EXAMINATION DOMAINS
-- =============================================================================

INSERT INTO knowledge.examination_domain
(
    domain_code,
    code,
    body_system_code,
    label,
    description,
    sort_order,
    is_mandatory,
    status
)
VALUES

(
 'EXAM-GENERAL',
 'general',
 'general',
 'General Examination',
 'General appearance, consciousness, distress, hydration, nutrition, build, posture, mobility and visible devices.',
 10,
 TRUE,
 'active'
),

(
 'EXAM-PAEDIATRIC',
 'paediatric',
 'paediatric',
 'Paediatric Measurements',
 'Age-appropriate anthropometry and developmental observations.',
 15,
 FALSE,
 'active'
),

(
 'EXAM-VITAL',
 'vital',
 'general',
 'Vital Signs',
 'Core physiological measurements and age-aware interpretation.',
 20,
 TRUE,
 'active'
),

(
 'EXAM-SYSTEMIC',
 'systemic',
 'general',
 'Systemic Signs',
 'Pallor, jaundice, cyanosis, clubbing, oedema, lymphadenopathy and other systemic observations.',
 30,
 TRUE,
 'active'
),

(
 'EXAM-RESPIRATORY',
 'respiratory',
 'respiratory',
 'Respiratory Examination',
 'Inspection, palpation, percussion and auscultation of the respiratory system.',
 35,
 FALSE,
 'active'
),

(
 'EXAM-CARDIOVASCULAR',
 'cardiovascular',
 'cardiovascular',
 'Cardiovascular Examination',
 'Pulse, JVP, precordium, heart sounds, murmurs and peripheral perfusion.',
 36,
 FALSE,
 'active'
),

(
 'EXAM-ABDOMEN',
 'abdomen',
 'gastrointestinal',
 'Abdominal Examination',
 'Inspection, palpation, percussion and auscultation of the abdomen.',
 37,
 FALSE,
 'active'
),

(
 'EXAM-NEURO',
 'neurological',
 'neuro',
 'Neurological Examination',
 'Mental status, cranial nerves, motor, sensory, reflexes, coordination and gait.',
 38,
 FALSE,
 'active'
),

(
 'EXAM-MSK',
 'musculoskeletal',
 'musculoskeletal',
 'Musculoskeletal Examination',
 'Inspection, palpation, movement, strength, deformity and function.',
 39,
 FALSE,
 'active'
),

(
 'EXAM-ENT',
 'ent',
 'head_neck',
 'ENT / Oral',
 'Head, neck, oral cavity, pharynx, tonsils and related findings.',
 40,
 FALSE,
 'active'
),

(
 'EXAM-EYE',
 'eye',
 'eye',
 'Ophthalmic Examination',
 'External eye and basic visual examination.',
 41,
 FALSE,
 'active'
),

(
 'EXAM-BREAST',
 'breast',
 'breast',
 'Breast Examination',
 'Inspection, palpation, axillary nodes and nipple findings.',
 42,
 FALSE,
 'active'
),

(
 'EXAM-GU',
 'genitourinary',
 'genitourinary',
 'Genitourinary Examination',
 'External genitalia, urinary and related findings.',
 43,
 FALSE,
 'active'
),

(
 'EXAM-OBSTETRIC',
 'obstetric',
 'obstetric',
 'Obstetric Examination',
 'Pregnancy-specific abdominal and obstetric examination.',
 44,
 FALSE,
 'active'
),

(
 'EXAM-SURGICAL',
 'surgical',
 'general',
 'Local / Surgical Examination',
 'Masses, wounds, ulcers, sinuses, discharge, scars and condition-triggered local examination.',
 50,
 FALSE,
 'active'
)

ON CONFLICT (domain_code)
DO NOTHING;


-- =============================================================================
-- 5. EXAMINATION TECHNIQUES
-- =============================================================================

INSERT INTO knowledge.examination_technique
(
    code,
    name,
    sort_order,
    status
)
VALUES

('INSPECTION','Inspection',1,'active'),
('PALPATION','Palpation',2,'active'),
('PERCUSSION','Percussion',3,'active'),
('AUSCULTATION','Auscultation',4,'active'),
('MENSURATION','Mensuration',5,'active'),
('SPECIAL_TEST','Special test',6,'active'),
('FUNCTIONAL_ASSESSMENT','Functional assessment',7,'active')

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 6. EXAMINATION SITES
-- =============================================================================

INSERT INTO knowledge.examination_site
(
    code,
    body_system_code,
    name,
    status
)
VALUES

-- General
('SITE-GENERAL','general','General appearance','active'),
('SITE-BUILD','general','Body build','active'),
('SITE-HYDRATION','general','Hydration status','active'),
('SITE-NUTRITION','general','Nutritional status','active'),
('SITE-POSTURE','general','Posture','active'),
('SITE-GAIT','musculoskeletal','Gait','active'),
('SITE-SKIN','skin','Skin','active'),
('SITE-NAILS','skin','Nails','active'),

-- Head / neck
('SITE-HEAD','head_neck','Head','active'),
('SITE-FACE','head_neck','Face','active'),
('SITE-EYES','eye','Eyes','active'),
('SITE-EARS','ear','Ears','active'),
('SITE-NOSE','head_neck','Nose','active'),
('SITE-ORAL-CAVITY','mouth','Oral cavity','active'),
('SITE-TONGUE','mouth','Tongue','active'),
('SITE-TONSILS','head_neck','Tonsils','active'),
('SITE-PHARYNX','head_neck','Pharynx','active'),
('SITE-NECK','head_neck','Neck','active'),
('SITE-LYMPH','lymph','Lymph nodes','active'),
('SITE-THYROID','endocrine','Thyroid','active'),

-- Respiratory
('SITE-CHEST','respiratory','Chest','active'),
('SITE-TRACHEA','respiratory','Trachea','active'),
('SITE-LUNGS','respiratory','Lungs','active'),
('SITE-POSTERIOR-CHEST','respiratory','Posterior chest','active'),

-- Cardiovascular
('SITE-PULSE','vascular','Peripheral pulse','active'),
('SITE-JVP','cardiovascular','Jugular venous pressure','active'),
('SITE-PRECORDIUM','cardiovascular','Precordium','active'),
('SITE-APEX','cardiovascular','Apex beat','active'),
('SITE-HEART','cardiovascular','Heart','active'),
('SITE-PERIPHERAL-PERFUSION','vascular','Peripheral perfusion','active'),

-- Abdomen
('SITE-ABDOMEN','gastrointestinal','Abdomen','active'),
('SITE-LIVER','gastrointestinal','Liver','active'),
('SITE-SPLEEN','gastrointestinal','Spleen','active'),
('SITE-KIDNEY','genitourinary','Kidneys','active'),
('SITE-ASCITES','gastrointestinal','Ascites','active'),
('SITE-INGUINAL','genitourinary','Inguinal region','active'),

-- Neuro
('SITE-MENTAL-STATUS','neuro','Mental status','active'),
('SITE-CRANIAL-NERVES','neuro','Cranial nerves','active'),
('SITE-MOTOR','neuro','Motor system','active'),
('SITE-SENSORY','neuro','Sensory system','active'),
('SITE-REFLEXES','neuro','Reflexes','active'),
('SITE-CEREBELLAR','neuro','Coordination','active'),

-- MSK
('SITE-JOINT','musculoskeletal','Joint','active'),
('SITE-SPINE','musculoskeletal','Spine','active'),
('SITE-MUSCLE','musculoskeletal','Muscle','active'),

-- Breast
('SITE-BREAST','breast','Breast','active'),
('SITE-NIPPLE','breast','Nipple','active'),
('SITE-AXILLA','lymph','Axilla','active'),

-- GU
('SITE-GENITALIA','genitourinary','External genitalia','active'),
('SITE-PERINEUM','genitourinary','Perineum','active'),
('SITE-CATHETER','urinary','Urinary catheter','active'),

-- Obstetric
('SITE-FUNDUS','obstetric','Uterine fundus','active'),
('SITE-FETAL-POSITION','obstetric','Fetal lie/presentation','active'),
('SITE-FETAL-HEART','obstetric','Fetal heart','active'),

-- Surgical
('SITE-MASS','general','Mass / swelling','active'),
('SITE-WOUND','general','Wound','active'),
('SITE-ULCER','skin','Ulcer','active'),
('SITE-SINUS','skin','Sinus / fistula','active'),
('SITE-DISCHARGE','general','Discharge','active'),
('SITE-SCAR','skin','Scar','active')

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 7. FACT DEFINITIONS â€” GENERAL EXAMINATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('GENERAL_APPEARANCE','coded','General appearance / alertness',TRUE),
('CONSCIOUSNESS_LEVEL','coded','Level of consciousness',TRUE),
('GCS_TOTAL','numeric','Glasgow Coma Scale total',TRUE),
('PATIENT_POSITION','coded','Patient positioning',TRUE),
('DISTRESS_OBSERVED','boolean','Clinical distress observed',TRUE),
('RESPIRATORY_DISTRESS','boolean','Respiratory distress',TRUE),
('PAIN_BEHAVIOUR','coded','Observed pain behaviour',TRUE),
('HYDRATION_STATUS','coded','Hydration status',TRUE),
('NUTRITION_STATUS','coded','Nutritional status',TRUE),
('BODY_BUILD','coded','Body build',TRUE),
('MOBILITY_STATUS','coded','Mobility status',TRUE),
('SKIN_INTEGRITY','coded','Skin integrity',TRUE),
('CANNULA_PRESENT','boolean','Intravenous cannula present',TRUE),
('CANNULA_TYPE','text','Cannula type / site',TRUE),
('CATHETER_PRESENT','boolean','Urinary catheter present',TRUE),
('CATHETER_DETAILS','text','Urinary catheter details',TRUE),
('URINE_OUTPUT_RATE','numeric','Urine output rate',TRUE),
('OXYGEN_DEVICE_PRESENT','boolean','Oxygen device present',TRUE),
('OXYGEN_DEVICE_TYPE','coded','Oxygen delivery device',TRUE),
('OXYGEN_FLOW_RATE','numeric','Oxygen flow rate',TRUE),
('OXYGEN_FLOW_UNIT','text','Oxygen flow unit',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 8. ANTHROPOMETRY
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('MUAC','numeric','Mid-upper arm circumference',TRUE),
('HEAD_CIRCUMFERENCE','numeric','Head circumference',TRUE),
('BODY_LENGTH','numeric','Recumbent body length',TRUE),
('HEIGHT','numeric','Standing height',TRUE),
('WEIGHT','numeric','Body weight',TRUE),
('BMI','numeric','Body mass index',TRUE),
('WEIGHT_FOR_AGE_Z','numeric','Weight-for-age Z score',TRUE),
('HEIGHT_FOR_AGE_Z','numeric','Height/length-for-age Z score',TRUE),
('WEIGHT_FOR_HEIGHT_Z','numeric','Weight-for-height/length Z score',TRUE),
('BMI_FOR_AGE_Z','numeric','BMI-for-age Z score',TRUE),
('HEAD_CIRCUMFERENCE_FOR_AGE_Z','numeric','Head circumference-for-age Z score',TRUE),
('MUAC_FOR_AGE_Z','numeric','MUAC-for-age Z score',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 9. VITAL SIGNS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('BP_SYSTOLIC','numeric','Systolic blood pressure',TRUE),
('BP_DIASTOLIC','numeric','Diastolic blood pressure',TRUE),
('HEART_RATE','numeric','Heart rate',TRUE),
('RESPIRATORY_RATE','numeric','Respiratory rate',TRUE),
('TEMPERATURE','numeric','Body temperature',TRUE),
('SPO2','numeric','Peripheral oxygen saturation',TRUE),
('CAPILLARY_REFILL_TIME','numeric','Capillary refill time',TRUE),
('PULSE_CHARACTER','coded','Pulse character',TRUE),
('PULSE_VOLUME','coded','Pulse volume',TRUE),
('PULSE_RHYTHM','coded','Pulse rhythm',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 10. SYSTEMIC SIGNS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('PALLOR','coded','Pallor',TRUE),
('ICTERUS','coded','Jaundice / icterus',TRUE),
('CYANOSIS','coded','Cyanosis',TRUE),
('CLUBBING','coded','Digital clubbing',TRUE),
('EDEMA','coded','Peripheral oedema',TRUE),
('LYMPHADENOPATHY','coded','Lymphadenopathy',TRUE),
('DEHYDRATION_SIGN','coded','Clinical dehydration signs',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 11. RESPIRATORY FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('CHEST_SHAPE','coded','Chest shape',TRUE),
('CHEST_SYMMETRY','coded','Chest symmetry',TRUE),
('CHEST_EXPANSION','coded','Chest expansion',TRUE),
('TRACHEAL_POSITION','coded','Tracheal position',TRUE),
('TACTILE_VOCAL_FREMITUS','coded','Tactile vocal fremitus',TRUE),
('CHEST_PERCUSSION_NOTE','coded','Chest percussion note',TRUE),
('BREATH_SOUND','coded','Breath sounds',TRUE),
('ADVENTITIOUS_BREATH_SOUND','coded','Added/adventitious breath sounds',TRUE),
('WHEEZE','coded','Wheeze',TRUE),
('CREPITATIONS','coded','Crepitations/crackles',TRUE),
('BRONCHIAL_BREATHING','coded','Bronchial breathing',TRUE),
('PLEURAL_RUB','coded','Pleural friction rub',TRUE),
('VOCAL_RESONANCE','coded','Vocal resonance',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 12. CARDIOVASCULAR FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('JVP_HEIGHT','numeric','Jugular venous pressure',TRUE),
('JVP_CHARACTER','coded','JVP waveform/character',TRUE),
('APEX_BEAT_POSITION','text','Apex beat position',TRUE),
('APEX_BEAT_CHARACTER','coded','Apex beat character',TRUE),
('HEAVE_PRESENT','boolean','Precordial heave',TRUE),
('THRILL_PRESENT','boolean','Precordial thrill',TRUE),
('HEART_SOUND_S1','coded','First heart sound',TRUE),
('HEART_SOUND_S2','coded','Second heart sound',TRUE),
('ADDED_HEART_SOUND','coded','Added heart sound',TRUE),
('MURMUR_PRESENT','boolean','Heart murmur present',TRUE),
('MURMUR_TIMING','coded','Murmur timing',TRUE),
('MURMUR_LOCATION','coded','Murmur location',TRUE),
('MURMUR_RADIATION','text','Murmur radiation',TRUE),
('MURMUR_GRADE','coded','Murmur intensity grade',TRUE),
('PERIPHERAL_PERFUSION','coded','Peripheral perfusion',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 13. ABDOMINAL FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('ABDOMINAL_DISTENSION','boolean','Abdominal distension',TRUE),
('ABDOMINAL_SCAR','boolean','Abdominal scar',TRUE),
('ABDOMINAL_TENDERNESS','coded','Abdominal tenderness',TRUE),
('ABDOMINAL_GUARDING','coded','Abdominal guarding',TRUE),
('ABDOMINAL_RIGIDITY','boolean','Abdominal rigidity',TRUE),
('REBOUND_TENDERNESS','boolean','Rebound tenderness',TRUE),
('ABDOMINAL_MASS','boolean','Abdominal mass',TRUE),
('LIVER_SIZE','numeric','Liver span / enlargement',TRUE),
('SPLEEN_SIZE','numeric','Splenic enlargement',TRUE),
('ASCITES','coded','Ascites',TRUE),
('BOWEL_SOUNDS','coded','Bowel sounds',TRUE),
('RENAL_BALLOTABLE','boolean','Kidney ballotable',TRUE),
('AORTIC_PULSATION','coded','Aortic pulsation',TRUE),
('HERNIA_PRESENT','boolean','Hernia present',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 14. NEUROLOGICAL FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('MENTAL_STATUS','coded','Mental status',TRUE),
('ORIENTATION','coded','Orientation',TRUE),
('SPEECH','coded','Speech',TRUE),
('PUPIL_SIZE_LEFT','numeric','Left pupil size',TRUE),
('PUPIL_SIZE_RIGHT','numeric','Right pupil size',TRUE),
('PUPIL_REACTION_LEFT','coded','Left pupil reaction',TRUE),
('PUPIL_REACTION_RIGHT','coded','Right pupil reaction',TRUE),
('CRANIAL_NERVE_FINDING','coded','Cranial nerve finding',TRUE),
('MOTOR_POWER_RUL','numeric','Right upper limb power',TRUE),
('MOTOR_POWER_LUL','numeric','Left upper limb power',TRUE),
('MOTOR_POWER_RLL','numeric','Right lower limb power',TRUE),
('MOTOR_POWER_LLL','numeric','Left lower limb power',TRUE),
('MUSCLE_TONE','coded','Muscle tone',TRUE),
('REFLEXES','coded','Deep tendon reflexes',TRUE),
('PLANTAR_RESPONSE','coded','Plantar response',TRUE),
('SENSATION','coded','Sensation',TRUE),
('COORDINATION','coded','Coordination',TRUE),
('GAIT','coded','Gait',TRUE),
('MENINGISM','coded','Meningeal signs',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 15. MUSCULOSKELETAL FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('JOINT_SWELLING','boolean','Joint swelling',TRUE),
('JOINT_TENDERNESS','boolean','Joint tenderness',TRUE),
('JOINT_WARMTH','boolean','Joint warmth',TRUE),
('JOINT_RANGE_OF_MOTION','coded','Joint range of movement',TRUE),
('JOINT_DEFORMITY','boolean','Joint deformity',TRUE),
('MUSCLE_WASTING','boolean','Muscle wasting',TRUE),
('LIMB_LENGTH_DIFFERENCE','numeric','Limb length difference',TRUE),
('SPINAL_DEFORMITY','coded','Spinal deformity',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 16. ENT / ORAL FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('ORAL_MUCOSA','coded','Oral mucosa',TRUE),
('ORAL_THRUSH','coded','Oral candidiasis/thrush',TRUE),
('TONSILS','coded','Tonsillar appearance',TRUE),
('PHARYNX','coded','Pharyngeal appearance',TRUE),
('DENTITION','coded','Dentition',TRUE),
('ORAL_ULCER','boolean','Oral ulcer',TRUE),
('NECK_SWELLING','boolean','Neck swelling',TRUE),
('THYROID_SIZE','coded','Thyroid size',TRUE),
('CERVICAL_NODES','coded','Cervical lymph nodes',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 17. EYE FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('VISUAL_ACUITY_LEFT','text','Visual acuity left eye',TRUE),
('VISUAL_ACUITY_RIGHT','text','Visual acuity right eye',TRUE),
('CONJUNCTIVA','coded','Conjunctiva',TRUE),
('SCLERA','coded','Sclera',TRUE),
('CORNEA','coded','Cornea',TRUE),
('PUPILS','coded','Pupils',TRUE),
('EYE_MOVEMENTS','coded','Extraocular movements',TRUE),
('RED_REFLEX','coded','Red reflex',TRUE),
('FUNDOSCOPY_FINDING','text','Fundoscopic finding',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 18. BREAST FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('BREAST_SYMMETRY','coded','Breast symmetry',TRUE),
('BREAST_MASS','boolean','Breast mass',TRUE),
('BREAST_MASS_SITE','text','Breast mass site',TRUE),
('BREAST_MASS_SIZE','text','Breast mass dimensions',TRUE),
('BREAST_MASS_MOBILITY','coded','Breast mass mobility',TRUE),
('BREAST_MASS_CONSISTENCY','coded','Breast mass consistency',TRUE),
('BREAST_TENDERNESS','boolean','Breast tenderness',TRUE),
('NIPPLE_DISCHARGE','coded','Nipple discharge',TRUE),
('NIPPLE_RETRACTION','boolean','Nipple retraction',TRUE),
('SKIN_DIMPLE','boolean','Skin dimpling',TRUE),
('PEAU_D_ORANGE','boolean','Peau d''orange',TRUE),
('AXILLARY_NODES','coded','Axillary lymph nodes',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 19. GENITOURINARY FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('EXTERNAL_GENITALIA','coded','External genital examination',TRUE),
('URETHRAL_DISCHARGE','boolean','Urethral discharge',TRUE),
('GENITAL_ULCER','boolean','Genital ulcer',TRUE),
('SCROTAL_SWELLING','boolean','Scrotal swelling',TRUE),
('TESTICULAR_TENDERNESS','boolean','Testicular tenderness',TRUE),
('TESTICULAR_MASS','boolean','Testicular mass',TRUE),
('INGUINAL_NODES','coded','Inguinal lymph nodes',TRUE),
('URINARY_CATHETER','boolean','Urinary catheter present',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 20. OBSTETRIC FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('UTERINE_SIZE','numeric','Symphysis-fundal height',TRUE),
('UTERINE_TONE','coded','Uterine tone',TRUE),
('FETAL_LIE','coded','Fetal lie',TRUE),
('FETAL_PRESENTATION','coded','Fetal presentation',TRUE),
('FETAL_POSITION','coded','Fetal position',TRUE),
('FETAL_HEART_RATE','numeric','Fetal heart rate',TRUE),
('UTERINE_CONTRACTIONS','coded','Uterine contractions',TRUE),
('CERVICAL_DILATATION','numeric','Cervical dilatation',TRUE),
('CERVICAL_EFFACEMENT','numeric','Cervical effacement',TRUE),
('CERVICAL_POSITION','coded','Cervical position',TRUE),
('CERVICAL_CONSISTENCY','coded','Cervical consistency',TRUE),
('MEMBRANE_STATUS','coded','Membrane status',TRUE),
('LIQUOR_CHARACTER','coded','Liquor character',TRUE),
('VAGINAL_BLEEDING','coded','Vaginal bleeding',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 21. SURGICAL / LOCAL FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('MASS_FOUND','coded','Mass present',TRUE),
('MASS_SITE','text','Mass anatomical site',TRUE),
('MASS_SIZE','text','Mass size',TRUE),
('MASS_SHAPE','coded','Mass shape',TRUE),
('MASS_SURFACE','coded','Mass surface',TRUE),
('MASS_CONSISTENCY','coded','Mass consistency',TRUE),
('MASS_TENDERNESS','boolean','Mass tenderness',TRUE),
('MASS_MOBILITY','coded','Mass mobility',TRUE),
('MASS_FLUCTUANCE','boolean','Mass fluctuation',TRUE),
('MASS_PULSATION','boolean','Mass pulsation',TRUE),
('MASS_TRANSLUMINATION','coded','Mass transillumination',TRUE),
('ULCER_FOUND','boolean','Ulcer present',TRUE),
('ULCER_SIZE','text','Ulcer size',TRUE),
('ULCER_EDGE','coded','Ulcer edge',TRUE),
('ULCER_FLOOR','coded','Ulcer floor',TRUE),
('ULCER_BASE','coded','Ulcer base',TRUE),
('ULCER_DISCHARGE','coded','Ulcer discharge',TRUE),
('WOUND_FOUND','boolean','Wound present',TRUE),
('WOUND_APPEARANCE','coded','Wound appearance',TRUE),
('WOUND_DISCHARGE','coded','Wound discharge',TRUE),
('SINUS_PRESENT','boolean','Sinus/fistula present',TRUE),
('DISCHARGE_FOUND','boolean','Discharge present',TRUE),
('DISCHARGE_CHARACTER','coded','Discharge character',TRUE),
('SCAR_PRESENT','boolean','Scar present',TRUE),
('SCAR_APPEARANCE','coded','Scar appearance',TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 22. EXAMINATION CONCEPTS â€” PAEDIATRIC
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-MUAC',
 'EXAM-PAEDIATRIC',
 'MUAC',
 'Mid-upper arm circumference',
 'MUAC',
 'paediatric',
 FALSE,
 101,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['age_6_to_59_months'],
 'active'
),

(
 'EXAM-CON-HC',
 'EXAM-PAEDIATRIC',
 'HEAD_CIRCUMFERENCE',
 'Head circumference',
 'Head circumference',
 'paediatric',
 FALSE,
 102,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['age_0_to_59_months'],
 'active'
),

(
 'EXAM-CON-LENGTH',
 'EXAM-PAEDIATRIC',
 'BODY_LENGTH',
 'Recumbent length',
 'Length',
 'paediatric',
 FALSE,
 103,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['age_0_to_23_months'],
 'active'
),

(
 'EXAM-CON-HEIGHT',
 'EXAM-PAEDIATRIC',
 'HEIGHT',
 'Standing height',
 'Height',
 'paediatric',
 FALSE,
 104,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['age_24_to_228_months'],
 'active'
),

(
 'EXAM-CON-WEIGHT',
 'EXAM-PAEDIATRIC',
 'WEIGHT',
 'Body weight',
 'Weight',
 'paediatric',
 FALSE,
 105,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-BMI',
 'EXAM-PAEDIATRIC',
 'BMI',
 'Body mass index',
 'BMI',
 'paediatric',
 FALSE,
 106,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['age_over_60_months'],
 'active'
),

(
 'EXAM-CON-WFA-Z',
 'EXAM-PAEDIATRIC',
 'WEIGHT_FOR_AGE_Z',
 'Weight-for-age Z score',
 'WFA Z',
 'paediatric',
 FALSE,
 107,
 ARRAY['SPECIAL_TEST'],
 ARRAY['derived'],
 ARRAY['age_0_to_228_months'],
 'active'
),

(
 'EXAM-CON-HFA-Z',
 'EXAM-PAEDIATRIC',
 'HEIGHT_FOR_AGE_Z',
 'Height/length-for-age Z score',
 'HFA Z',
 'paediatric',
 FALSE,
 108,
 ARRAY['SPECIAL_TEST'],
 ARRAY['derived'],
 ARRAY['age_0_to_228_months'],
 'active'
),

(
 'EXAM-CON-WFH-Z',
 'EXAM-PAEDIATRIC',
 'WEIGHT_FOR_HEIGHT_Z',
 'Weight-for-height/length Z score',
 'WFH Z',
 'paediatric',
 FALSE,
 109,
 ARRAY['SPECIAL_TEST'],
 ARRAY['derived'],
 ARRAY['age_0_to_60_months'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 23. GENERAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-APPEARANCE',
 'EXAM-GENERAL',
 'GENERAL_APPEARANCE',
 'General appearance',
 'Appearance',
 'general',
 TRUE,
 10,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CONSCIOUSNESS',
 'EXAM-GENERAL',
 'CONSCIOUSNESS_LEVEL',
 'Level of consciousness',
 'Consciousness',
 'neuro',
 TRUE,
 11,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-POSITION',
 'EXAM-GENERAL',
 'PATIENT_POSITION',
 'Patient position',
 'Position',
 'general',
 TRUE,
 12,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-DISTRESS',
 'EXAM-GENERAL',
 'DISTRESS_OBSERVED',
 'Clinical distress',
 'Distress',
 'general',
 TRUE,
 13,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-HYDRATION',
 'EXAM-GENERAL',
 'HYDRATION_STATUS',
 'Hydration status',
 'Hydration',
 'general',
 TRUE,
 14,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-NUTRITION',
 'EXAM-GENERAL',
 'NUTRITION_STATUS',
 'Nutritional status',
 'Nutrition',
 'general',
 TRUE,
 15,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-SKIN',
 'EXAM-GENERAL',
 'SKIN_INTEGRITY',
 'Skin integrity',
 'Skin',
 'skin',
 FALSE,
 16,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CANNULA',
 'EXAM-GENERAL',
 'CANNULA_PRESENT',
 'Intravenous cannula / line',
 'Cannula',
 'vascular',
 FALSE,
 17,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CATHETER',
 'EXAM-GENERAL',
 'CATHETER_PRESENT',
 'Urinary catheter',
 'Catheter',
 'genitourinary',
 FALSE,
 18,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-OXYGEN',
 'EXAM-GENERAL',
 'OXYGEN_DEVICE_PRESENT',
 'Oxygen therapy/device',
 'Oxygen',
 'respiratory',
 FALSE,
 19,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 24. VITAL SIGN CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-BP',
 'EXAM-VITAL',
 'BP_SYSTOLIC',
 'Blood pressure',
 'BP',
 'cardiovascular',
 TRUE,
 20,
 ARRAY['PALPATION','AUSCULTATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-HR',
 'EXAM-VITAL',
 'HEART_RATE',
 'Heart rate',
 'HR',
 'cardiovascular',
 TRUE,
 21,
 ARRAY['PALPATION','AUSCULTATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-RR',
 'EXAM-VITAL',
 'RESPIRATORY_RATE',
 'Respiratory rate',
 'RR',
 'respiratory',
 TRUE,
 22,
 ARRAY['INSPECTION'],
 ARRAY['measurement','observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-TEMP',
 'EXAM-VITAL',
 'TEMPERATURE',
 'Temperature',
 'Temp',
 'general',
 TRUE,
 23,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-SPO2',
 'EXAM-VITAL',
 'SPO2',
 'Oxygen saturation',
 'SpO2',
 'respiratory',
 FALSE,
 24,
 ARRAY['MENSURATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CAPREF',
 'EXAM-VITAL',
 'CAPILLARY_REFILL_TIME',
 'Capillary refill time',
 'CRT',
 'vascular',
 FALSE,
 25,
 ARRAY['PALPATION'],
 ARRAY['measurement'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 25. SYSTEMIC SIGN CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-PALLOR',
 'EXAM-SYSTEMIC',
 'PALLOR',
 'Pallor',
 'Pallor',
 'haematologic',
 TRUE,
 30,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ICTERIC',
 'EXAM-SYSTEMIC',
 'ICTERUS',
 'Jaundice / icterus',
 'Jaundice',
 'gastrointestinal',
 TRUE,
 31,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CYANOSIS',
 'EXAM-SYSTEMIC',
 'CYANOSIS',
 'Cyanosis',
 'Cyanosis',
 'respiratory',
 TRUE,
 32,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CLUBBING',
 'EXAM-SYSTEMIC',
 'CLUBBING',
 'Digital clubbing',
 'Clubbing',
 'respiratory',
 FALSE,
 33,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-EDEMA',
 'EXAM-SYSTEMIC',
 'EDEMA',
 'Peripheral oedema',
 'Oedema',
 'cardiovascular',
 TRUE,
 34,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-LYMPH',
 'EXAM-SYSTEMIC',
 'LYMPHADENOPATHY',
 'Lymphadenopathy',
 'Lymph nodes',
 'lymph',
 TRUE,
 35,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 26. RESPIRATORY EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-CHEST-SHAPE',
 'EXAM-RESPIRATORY',
 'CHEST_SHAPE',
 'Chest shape',
 'Chest shape',
 'respiratory',
 FALSE,
 100,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CHEST-SYMMETRY',
 'EXAM-RESPIRATORY',
 'CHEST_SYMMETRY',
 'Chest symmetry',
 'Symmetry',
 'respiratory',
 FALSE,
 101,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CHEST-EXPANSION',
 'EXAM-RESPIRATORY',
 'CHEST_EXPANSION',
 'Chest expansion',
 'Expansion',
 'respiratory',
 FALSE,
 102,
 ARRAY['PALPATION'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-TRACHEA',
 'EXAM-RESPIRATORY',
 'TRACHEAL_POSITION',
 'Tracheal position',
 'Trachea',
 'respiratory',
 FALSE,
 103,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-VOCAL-FREMITUS',
 'EXAM-RESPIRATORY',
 'TACTILE_VOCAL_FREMITUS',
 'Tactile vocal fremitus',
 'Fremitus',
 'respiratory',
 FALSE,
 104,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-PERCUSSION',
 'EXAM-RESPIRATORY',
 'CHEST_PERCUSSION_NOTE',
 'Chest percussion',
 'Percussion',
 'respiratory',
 FALSE,
 105,
 ARRAY['PERCUSSION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-BREATH-SOUND',
 'EXAM-RESPIRATORY',
 'BREATH_SOUND',
 'Breath sounds',
 'Breath sounds',
 'respiratory',
 FALSE,
 106,
 ARRAY['AUSCULTATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ADDED-SOUNDS',
 'EXAM-RESPIRATORY',
 'ADVENTITIOUS_BREATH_SOUND',
 'Added breath sounds',
 'Added sounds',
 'respiratory',
 FALSE,
 107,
 ARRAY['AUSCULTATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 27. CARDIOVASCULAR EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-PULSE',
 'EXAM-CARDIOVASCULAR',
 'PULSE_VOLUME',
 'Peripheral pulses',
 'Pulses',
 'vascular',
 FALSE,
 110,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-JVP',
 'EXAM-CARDIOVASCULAR',
 'JVP_HEIGHT',
 'Jugular venous pressure',
 'JVP',
 'cardiovascular',
 FALSE,
 111,
 ARRAY['INSPECTION'],
 ARRAY['measurement','observation'],
 ARRAY['age_over_12_years'],
 'active'
),

(
 'EXAM-CON-APEX',
 'EXAM-CARDIOVASCULAR',
 'APEX_BEAT_POSITION',
 'Apex beat',
 'Apex',
 'cardiovascular',
 FALSE,
 112,
 ARRAY['PALPATION'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-HEAVE',
 'EXAM-CARDIOVASCULAR',
 'HEAVE_PRESENT',
 'Precordial heave',
 'Heave',
 'cardiovascular',
 FALSE,
 113,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-THRILL',
 'EXAM-CARDIOVASCULAR',
 'THRILL_PRESENT',
 'Precordial thrill',
 'Thrill',
 'cardiovascular',
 FALSE,
 114,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-MURMUR',
 'EXAM-CARDIOVASCULAR',
 'MURMUR_PRESENT',
 'Cardiac murmur',
 'Murmur',
 'cardiovascular',
 FALSE,
 115,
 ARRAY['AUSCULTATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-HEART-SOUNDS',
 'EXAM-CARDIOVASCULAR',
 'HEART_SOUND_S1',
 'Heart sounds',
 'Heart sounds',
 'cardiovascular',
 FALSE,
 116,
 ARRAY['AUSCULTATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 28. ABDOMINAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-ABD-INSPECTION',
 'EXAM-ABDOMEN',
 'ABDOMINAL_DISTENSION',
 'Abdominal inspection',
 'Inspection',
 'gastrointestinal',
 FALSE,
 120,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ABD-TENDERNESS',
 'EXAM-ABDOMEN',
 'ABDOMINAL_TENDERNESS',
 'Abdominal tenderness',
 'Tenderness',
 'gastrointestinal',
 FALSE,
 121,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ABD-GUARDING',
 'EXAM-ABDOMEN',
 'ABDOMINAL_GUARDING',
 'Guarding',
 'Guarding',
 'gastrointestinal',
 FALSE,
 122,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ABD-MASS',
 'EXAM-ABDOMEN',
 'ABDOMINAL_MASS',
 'Abdominal mass',
 'Mass',
 'gastrointestinal',
 FALSE,
 123,
 ARRAY['PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-LIVER',
 'EXAM-ABDOMEN',
 'LIVER_SIZE',
 'Liver examination',
 'Liver',
 'gastrointestinal',
 FALSE,
 124,
 ARRAY['PALPATION','PERCUSSION'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-SPLEEN',
 'EXAM-ABDOMEN',
 'SPLEEN_SIZE',
 'Spleen examination',
 'Spleen',
 'gastrointestinal',
 FALSE,
 125,
 ARRAY['PALPATION','PERCUSSION'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-BOWEL',
 'EXAM-ABDOMEN',
 'BOWEL_SOUNDS',
 'Bowel sounds',
 'Bowel sounds',
 'gastrointestinal',
 FALSE,
 126,
 ARRAY['AUSCULTATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 29. NEUROLOGICAL CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-MENTAL',
 'EXAM-NEURO',
 'MENTAL_STATUS',
 'Mental status',
 'Mental status',
 'neuro',
 FALSE,
 130,
 ARRAY['INSPECTION','SPECIAL_TEST'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-PUPILS',
 'EXAM-NEURO',
 'PUPILS',
 'Pupillary examination',
 'Pupils',
 'eye',
 FALSE,
 131,
 ARRAY['INSPECTION','SPECIAL_TEST'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-CRANIAL',
 'EXAM-NEURO',
 'CRANIAL_NERVE_FINDING',
 'Cranial nerves',
 'Cranial nerves',
 'neuro',
 FALSE,
 132,
 ARRAY['SPECIAL_TEST'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-MOTOR',
 'EXAM-NEURO',
 'MOTOR_POWER_RUL',
 'Motor system',
 'Motor',
 'neuro',
 FALSE,
 133,
 ARRAY['INSPECTION','PALPATION','SPECIAL_TEST'],
 ARRAY['observation','measurement'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-REFLEX',
 'EXAM-NEURO',
 'REFLEXES',
 'Reflexes',
 'Reflexes',
 'neuro',
 FALSE,
 134,
 ARRAY['SPECIAL_TEST'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-SENSORY',
 'EXAM-NEURO',
 'SENSATION',
 'Sensory examination',
 'Sensation',
 'neuro',
 FALSE,
 135,
 ARRAY['SPECIAL_TEST'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-COORDINATION',
 'EXAM-NEURO',
 'COORDINATION',
 'Coordination',
 'Coordination',
 'neuro',
 FALSE,
 136,
 ARRAY['SPECIAL_TEST'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 30. ENT / ORAL CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-THRUSH',
 'EXAM-ENT',
 'ORAL_THRUSH',
 'Oral thrush',
 'Thrush',
 'mouth',
 FALSE,
 140,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-TONSILS',
 'EXAM-ENT',
 'TONSILS',
 'Tonsils',
 'Tonsils',
 'head_neck',
 FALSE,
 141,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-PHARYNX',
 'EXAM-ENT',
 'PHARYNX',
 'Pharynx',
 'Pharynx',
 'head_neck',
 FALSE,
 142,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ORAL',
 'EXAM-ENT',
 'ORAL_MUCOSA',
 'Oral cavity',
 'Oral cavity',
 'mouth',
 FALSE,
 143,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-NECK-NODES',
 'EXAM-ENT',
 'CERVICAL_NODES',
 'Cervical lymph nodes',
 'Cervical nodes',
 'lymph',
 FALSE,
 144,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-THYROID',
 'EXAM-ENT',
 'THYROID_SIZE',
 'Thyroid examination',
 'Thyroid',
 'endocrine',
 FALSE,
 145,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['age_over_12_years'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 31. BREAST CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-BREAST-INSPECTION',
 'EXAM-BREAST',
 'BREAST_SYMMETRY',
 'Breast inspection',
 'Inspection',
 'breast',
 FALSE,
 150,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['female','male'],
 'active'
),

(
 'EXAM-CON-BREAST-MASS',
 'EXAM-BREAST',
 'BREAST_MASS',
 'Breast mass',
 'Mass',
 'breast',
 FALSE,
 151,
 ARRAY['PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['female','male'],
 'active'
),

(
 'EXAM-CON-NIPPLE',
 'EXAM-BREAST',
 'NIPPLE_DISCHARGE',
 'Nipple examination',
 'Nipple',
 'breast',
 FALSE,
 152,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['female','male'],
 'active'
),

(
 'EXAM-CON-AXILLA',
 'EXAM-BREAST',
 'AXILLARY_NODES',
 'Axillary lymph nodes',
 'Axilla',
 'lymph',
 FALSE,
 153,
 ARRAY['PALPATION'],
 ARRAY['palpation'],
 ARRAY['female','male'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 32. SURGICAL LOCAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
    code,
    domain_code,
    fact_definition_code,
    name,
    short_label,
    body_system_code,
    is_mandatory,
    base_priority,
    technique_codes,
    capture_method_codes,
    applies_to_context_codes,
    status
)
VALUES

(
 'EXAM-CON-MASS',
 'EXAM-SURGICAL',
 'MASS_FOUND',
 'Mass / lump',
 'Mass',
 'general',
 FALSE,
 160,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-ULCER',
 'EXAM-SURGICAL',
 'ULCER_FOUND',
 'Ulcer',
 'Ulcer',
 'skin',
 FALSE,
 161,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-WOUND',
 'EXAM-SURGICAL',
 'WOUND_FOUND',
 'Wound',
 'Wound',
 'skin',
 FALSE,
 162,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-DISCHARGE',
 'EXAM-SURGICAL',
 'DISCHARGE_FOUND',
 'Discharge',
 'Discharge',
 'general',
 FALSE,
 163,
 ARRAY['INSPECTION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-SINUS',
 'EXAM-SURGICAL',
 'SINUS_PRESENT',
 'Sinus / fistula',
 'Sinus',
 'skin',
 FALSE,
 164,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation','palpation'],
 ARRAY['all_ages'],
 'active'
),

(
 'EXAM-CON-SCAR',
 'EXAM-SURGICAL',
 'SCAR_PRESENT',
 'Scar',
 'Scar',
 'skin',
 FALSE,
 165,
 ARRAY['INSPECTION','PALPATION'],
 ARRAY['observation'],
 ARRAY['all_ages'],
 'active'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 33. FINDING INTERPRETATIONS
-- =============================================================================

INSERT INTO knowledge.finding_interpretation
(
    code,
    canonical_name,
    label,
    value_type_constraint,
    is_abnormal,
    is_critical,
    sort_order,
    status
)
VALUES

-- Generic findings
('SIGN_ABSENT',
 'Absent',
 'Absent',
 'sign',
 FALSE,
 FALSE,
 1,
 'active'),

('SIGN_MILD',
 'Mild',
 'Mild / +',
 'sign',
 TRUE,
 FALSE,
 2,
 'active'),

('SIGN_MODERATE',
 'Moderate',
 'Moderate / ++',
 'sign',
 TRUE,
 FALSE,
 3,
 'active'),

('SIGN_SEVERE',
 'Severe',
 'Severe / +++',
 'sign',
 TRUE,
 TRUE,
 4,
 'active'),

-- Measurement interpretations
('VITAL_NORMAL',
 'Within reference range',
 'Normal',
 'measurement',
 FALSE,
 FALSE,
 10,
 'active'),

('VITAL_LOW',
 'Below reference range',
 'Low',
 'measurement',
 TRUE,
 FALSE,
 11,
 'active'),

('VITAL_HIGH',
 'Above reference range',
 'High',
 'measurement',
 TRUE,
 FALSE,
 12,
 'active'),

('VITAL_CRIT_HIGH',
 'Critical high',
 'Critical high',
 'measurement',
 TRUE,
 TRUE,
 13,
 'active'),

('VITAL_CRIT_LOW',
 'Critical low',
 'Critical low',
 'measurement',
 TRUE,
 TRUE,
 14,
 'active'),

('VITAL_TACHY',
 'Tachycardia',
 'Tachycardia',
 'measurement',
 TRUE,
 FALSE,
 15,
 'active'),

('VITAL_BRADY',
 'Bradycardia',
 'Bradycardia',
 'measurement',
 TRUE,
 FALSE,
 16,
 'active'),

('VITAL_TACHYPNEA',
 'Tachypnoea',
 'Tachypnoea',
 'measurement',
 TRUE,
 FALSE,
 17,
 'active'),

('VITAL_BRADYPNEA',
 'Bradypnoea',
 'Bradypnoea',
 'measurement',
 TRUE,
 FALSE,
 18,
 'active'),

('VITAL_FEVER',
 'Fever',
 'Fever',
 'measurement',
 TRUE,
 FALSE,
 19,
 'active'),

('VITAL_HYPOXEMIA',
 'Low oxygen saturation',
 'Hypoxaemia',
 'measurement',
 TRUE,
 TRUE,
 20,
 'active'),

-- Clinical interpretation
('FINDING_POSITIVE',
 'Positive finding',
 'Present',
 'sign',
 TRUE,
 FALSE,
 30,
 'active'),

('FINDING_CRITICAL',
 'Critical finding',
 'Critical',
 'sign',
 TRUE,
 TRUE,
 31,
 'active')

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 34. SIGN OPTIONS â€” GENERAL APPEARANCE
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-APPEARANCE',
 'APP_WELL',
 'Well appearing',
 'SIGN_ABSENT',
 'well_appearing',
 1
),

(
 'EXAM-CON-APPEARANCE',
 'APP_UNWELL',
 'Unwell appearing',
 'SIGN_MILD',
 'unwell',
 2
),

(
 'EXAM-CON-APPEARANCE',
 'APP_LETHARGIC',
 'Lethargic',
 'SIGN_MODERATE',
 'lethargic',
 3
),

(
 'EXAM-CON-APPEARANCE',
 'APP_TOXIC',
 'Toxic / severely ill appearing',
 'SIGN_SEVERE',
 'toxic',
 4
),

(
 'EXAM-CON-CONSCIOUSNESS',
 'CONSCIOUS_ALERT',
 'Alert and conscious',
 'SIGN_ABSENT',
 'alert',
 1
),

(
 'EXAM-CON-CONSCIOUSNESS',
 'CONSCIOUS_DROWSY',
 'Drowsy',
 'SIGN_MODERATE',
 'drowsy',
 2
),

(
 'EXAM-CON-CONSCIOUSNESS',
 'CONSCIOUS_CONFUSED',
 'Confused',
 'SIGN_MODERATE',
 'confused',
 3
),

(
 'EXAM-CON-CONSCIOUSNESS',
 'CONSCIOUS_UNCONSCIOUS',
 'Unconscious',
 'SIGN_SEVERE',
 'unconscious',
 4
),

(
 'EXAM-CON-POSITION',
 'POS_COMFORTABLE',
 'Comfortable / normal position',
 'SIGN_ABSENT',
 'comfortable',
 1
),

(
 'EXAM-CON-POSITION',
 'POS_SITTING',
 'Sitting upright',
 'SIGN_ABSENT',
 'sitting_upright',
 2
),

(
 'EXAM-CON-POSITION',
 'POS_SUPINE',
 'Supine',
 'SIGN_ABSENT',
 'supine',
 3
),

(
 'EXAM-CON-POSITION',
 'POS_TRIPOD',
 'Tripod position',
 'SIGN_MODERATE',
 'tripod',
 4
),

(
 'EXAM-CON-POSITION',
 'POS_FOWLER',
 'Fowler position',
 'SIGN_ABSENT',
 'fowlers',
 5
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 35. HYDRATION / NUTRITION
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-HYDRATION',
 'HYD_WELL',
 'Clinically well hydrated',
 'SIGN_ABSENT',
 'well_hydrated',
 1
),

(
 'EXAM-CON-HYDRATION',
 'HYD_MILD',
 'Mild dehydration features',
 'SIGN_MILD',
 'mild_dehydration',
 2
),

(
 'EXAM-CON-HYDRATION',
 'HYD_MOD',
 'Moderate dehydration features',
 'SIGN_MODERATE',
 'moderate_dehydration',
 3
),

(
 'EXAM-CON-HYDRATION',
 'HYD_SEVERE',
 'Severe dehydration / shock features',
 'SIGN_SEVERE',
 'severe_dehydration',
 4
),

(
 'EXAM-CON-NUTRITION',
 'NUT_WELL',
 'Well nourished',
 'SIGN_ABSENT',
 'well_nourished',
 1
),

(
 'EXAM-CON-NUTRITION',
 'NUT_THIN',
 'Thin / undernourished',
 'SIGN_MILD',
 'thin',
 2
),

(
 'EXAM-CON-NUTRITION',
 'NUT_EMACIATED',
 'Marked wasting',
 'SIGN_MODERATE',
 'wasting',
 3
),

(
 'EXAM-CON-NUTRITION',
 'NUT_SAM',
 'Severe acute malnutrition phenotype',
 'SIGN_SEVERE',
 'sam_phenotype',
 4
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 36. SYSTEMIC SIGN GRADING
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

-- PALLOR
(
 'EXAM-CON-PALLOR',
 'SIGN_ABSENT',
 'No pallor',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-PALLOR',
 'SIGN_MILD',
 'Mild pallor',
 'SIGN_MILD',
 'mild',
 2
),

(
 'EXAM-CON-PALLOR',
 'SIGN_MODERATE',
 'Moderate pallor',
 'SIGN_MODERATE',
 'moderate',
 3
),

(
 'EXAM-CON-PALLOR',
 'SIGN_SEVERE',
 'Severe pallor',
 'SIGN_SEVERE',
 'severe',
 4
),

-- ICTERUS
(
 'EXAM-CON-ICTERIC',
 'SIGN_ABSENT',
 'No icterus',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-ICTERIC',
 'SIGN_MILD',
 'Mild icterus',
 'SIGN_MILD',
 'mild',
 2
),

(
 'EXAM-CON-ICTERIC',
 'SIGN_MODERATE',
 'Moderate icterus',
 'SIGN_MODERATE',
 'moderate',
 3
),

(
 'EXAM-CON-ICTERIC',
 'SIGN_SEVERE',
 'Marked icterus',
 'SIGN_SEVERE',
 'severe',
 4
),

-- CYANOSIS
(
 'EXAM-CON-CYANOSIS',
 'SIGN_ABSENT',
 'No cyanosis',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-CYANOSIS',
 'SIGN_MILD',
 'Mild peripheral cyanosis',
 'SIGN_MILD',
 'peripheral',
 2
),

(
 'EXAM-CON-CYANOSIS',
 'SIGN_MODERATE',
 'Central cyanosis',
 'SIGN_MODERATE',
 'central',
 3
),

(
 'EXAM-CON-CYANOSIS',
 'SIGN_SEVERE',
 'Severe/generalised cyanosis',
 'SIGN_SEVERE',
 'severe',
 4
),

-- CLUBBING
(
 'EXAM-CON-CLUBBING',
 'SIGN_ABSENT',
 'No clubbing',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-CLUBBING',
 'SIGN_MILD',
 'Early clubbing',
 'SIGN_MILD',
 'mild',
 2
),

(
 'EXAM-CON-CLUBBING',
 'SIGN_MODERATE',
 'Established clubbing',
 'SIGN_MODERATE',
 'moderate',
 3
),

(
 'EXAM-CON-CLUBBING',
 'SIGN_SEVERE',
 'Marked clubbing',
 'SIGN_SEVERE',
 'severe',
 4
),

-- OEDEMA
(
 'EXAM-CON-EDEMA',
 'SIGN_ABSENT',
 'No oedema',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-EDEMA',
 'SIGN_MILD',
 'Mild pitting oedema (+1)',
 'SIGN_MILD',
 '1_plus',
 2
),

(
 'EXAM-CON-EDEMA',
 'SIGN_MODERATE',
 'Moderate pitting oedema (+2)',
 'SIGN_MODERATE',
 '2_plus',
 3
),

(
 'EXAM-CON-EDEMA',
 'SIGN_SEVERE',
 'Severe pitting oedema (+3/+4)',
 'SIGN_SEVERE',
 '3_plus_or_4_plus',
 4
),

-- LYMPH
(
 'EXAM-CON-LYMPH',
 'SIGN_ABSENT',
 'No lymphadenopathy',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-LYMPH',
 'SIGN_MILD',
 'Small/non-tender lymphadenopathy',
 'SIGN_MILD',
 'mild',
 2
),

(
 'EXAM-CON-LYMPH',
 'SIGN_MODERATE',
 'Significant lymphadenopathy',
 'SIGN_MODERATE',
 'moderate',
 3
),

(
 'EXAM-CON-LYMPH',
 'SIGN_SEVERE',
 'Marked / matted lymphadenopathy',
 'SIGN_SEVERE',
 'severe',
 4
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 37. RESPIRATORY FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-CHEST-SHAPE',
 'CHEST_NORMAL',
 'Normal chest configuration',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-CHEST-SHAPE',
 'CHEST_BARREL',
 'Barrel-shaped chest',
 'SIGN_MODERATE',
 'barrel',
 2
),

(
 'EXAM-CON-CHEST-SHAPE',
 'CHEST_DEFORMITY',
 'Chest wall deformity',
 'SIGN_MODERATE',
 'deformity',
 3
),

(
 'EXAM-CON-CHEST-SYMMETRY',
 'CHEST_SYMMETRIC',
 'Symmetrical',
 'SIGN_ABSENT',
 'symmetric',
 1
),

(
 'EXAM-CON-CHEST-SYMMETRY',
 'CHEST_ASYMMETRIC',
 'Asymmetrical expansion',
 'SIGN_MODERATE',
 'asymmetric',
 2
),

(
 'EXAM-CON-CHEST-EXPANSION',
 'EXP_NORMAL',
 'Normal expansion',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-CHEST-EXPANSION',
 'EXP_REDUCED_UNILATERAL',
 'Reduced unilateral expansion',
 'SIGN_MODERATE',
 'reduced_unilateral',
 2
),

(
 'EXAM-CON-CHEST-EXPANSION',
 'EXP_REDUCED_BILATERAL',
 'Reduced bilateral expansion',
 'SIGN_MODERATE',
 'reduced_bilateral',
 3
),

(
 'EXAM-CON-TRACHEA',
 'TRACHEA_CENTRAL',
 'Central',
 'SIGN_ABSENT',
 'central',
 1
),

(
 'EXAM-CON-TRACHEA',
 'TRACHEA_DEVIATED',
 'Deviated',
 'SIGN_MODERATE',
 'deviated',
 2
),

(
 'EXAM-CON-PERCUSSION',
 'PERC_RESONANT',
 'Resonant',
 'SIGN_ABSENT',
 'resonant',
 1
),

(
 'EXAM-CON-PERCUSSION',
 'PERC_DULL',
 'Dull',
 'SIGN_MODERATE',
 'dull',
 2
),

(
 'EXAM-CON-PERCUSSION',
 'PERC_STONY_DULL',
 'Stony dull',
 'SIGN_SEVERE',
 'stony_dull',
 3
),

(
 'EXAM-CON-PERCUSSION',
 'PERC_HYPERRES',
 'Hyper-resonant',
 'SIGN_MODERATE',
 'hyperresonant',
 4
),

(
 'EXAM-CON-BREATH-SOUND',
 'BS_VESICULAR',
 'Vesicular',
 'SIGN_ABSENT',
 'vesicular',
 1
),

(
 'EXAM-CON-BREATH-SOUND',
 'BS_REDUCED',
 'Reduced',
 'SIGN_MODERATE',
 'reduced',
 2
),

(
 'EXAM-CON-BREATH-SOUND',
 'BS_ABSENT',
 'Absent',
 'SIGN_SEVERE',
 'absent',
 3
),

(
 'EXAM-CON-BREATH-SOUND',
 'BS_BRONCHIAL',
 'Bronchial',
 'SIGN_MODERATE',
 'bronchial',
 4
),

(
 'EXAM-CON-ADDED-SOUNDS',
 'ADDED_NONE',
 'No added sounds',
 'SIGN_ABSENT',
 'none',
 1
),

(
 'EXAM-CON-ADDED-SOUNDS',
 'ADDED_WHEEZE',
 'Wheeze',
 'SIGN_MODERATE',
 'wheeze',
 2
),

(
 'EXAM-CON-ADDED-SOUNDS',
 'ADDED_FINE_CRACKLES',
 'Fine crackles',
 'SIGN_MODERATE',
 'fine_crackles',
 3
),

(
 'EXAM-CON-ADDED-SOUNDS',
 'ADDED_COARSE_CRACKLES',
 'Coarse crackles',
 'SIGN_MODERATE',
 'coarse_crackles',
 4
),

(
 'EXAM-CON-ADDED-SOUNDS',
 'ADDED_PLEURAL_RUB',
 'Pleural rub',
 'SIGN_MODERATE',
 'pleural_rub',
 5
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 38. CARDIOVASCULAR FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-PULSE',
 'PULSE_NORMAL',
 'Normal volume',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-PULSE',
 'PULSE_LOW',
 'Low volume',
 'SIGN_MODERATE',
 'low_volume',
 2
),

(
 'EXAM-CON-PULSE',
 'PULSE_BOUNDING',
 'Bounding',
 'SIGN_MODERATE',
 'bounding',
 3
),

(
 'EXAM-CON-PULSE',
 'PULSE_IRREGULAR',
 'Irregular rhythm',
 'SIGN_MODERATE',
 'irregular',
 4
),

(
 'EXAM-CON-HEAVE',
 'HEAVE_ABSENT',
 'No heave',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-HEAVE',
 'HEAVE_PRESENT',
 'Heave present',
 'SIGN_MODERATE',
 'present',
 2
),

(
 'EXAM-CON-THRILL',
 'THRILL_ABSENT',
 'No thrill',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-THRILL',
 'THRILL_PRESENT',
 'Thrill present',
 'SIGN_SEVERE',
 'present',
 2
),

(
 'EXAM-CON-MURMUR',
 'MURMUR_ABSENT',
 'No murmur',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-MURMUR',
 'MURMUR_PRESENT',
 'Murmur present',
 'SIGN_MODERATE',
 'present',
 2
),

(
 'EXAM-CON-HEART-SOUNDS',
 'HS_NORMAL',
 'Normal S1 and S2',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-HEART-SOUNDS',
 'HS_ADDED',
 'Added heart sound',
 'SIGN_MODERATE',
 'added',
 2
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 39. ABDOMINAL FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-ABD-INSPECTION',
 'ABD_NORMAL',
 'No visible abnormality',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-ABD-INSPECTION',
 'ABD_DISTENDED',
 'Distended',
 'SIGN_MODERATE',
 'distended',
 2
),

(
 'EXAM-CON-ABD-TENDERNESS',
 'ABD_NON_TENDER',
 'Non-tender',
 'SIGN_ABSENT',
 'non_tender',
 1
),

(
 'EXAM-CON-ABD-TENDERNESS',
 'ABD_TENDER',
 'Tender',
 'SIGN_MODERATE',
 'tender',
 2
),

(
 'EXAM-CON-ABD-GUARDING',
 'ABD_NO_GUARDING',
 'No guarding',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-ABD-GUARDING',
 'ABD_GUARDING',
 'Guarding',
 'SIGN_SEVERE',
 'present',
 2
),

(
 'EXAM-CON-ABD-MASS',
 'ABD_NO_MASS',
 'No mass',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-ABD-MASS',
 'ABD_MASS',
 'Mass palpable',
 'SIGN_MODERATE',
 'present',
 2
),

(
 'EXAM-CON-BOWEL',
 'BOWEL_NORMAL',
 'Normal bowel sounds',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-BOWEL',
 'BOWEL_REDUCED',
 'Reduced bowel sounds',
 'SIGN_MODERATE',
 'reduced',
 2
),

(
 'EXAM-CON-BOWEL',
 'BOWEL_ABSENT',
 'Absent bowel sounds',
 'SIGN_SEVERE',
 'absent',
 3
),

(
 'EXAM-CON-BOWEL',
 'BOWEL_HYPERACTIVE',
 'Hyperactive bowel sounds',
 'SIGN_MODERATE',
 'hyperactive',
 4
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 40. ENT / ORAL FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-THRUSH',
 'THRUSH_ABSENT',
 'No oral thrush',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-THRUSH',
 'THRUSH_PRESENT',
 'Oral thrush present',
 'SIGN_MODERATE',
 'present',
 2
),

(
 'EXAM-CON-TONSILS',
 'TONSILS_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-TONSILS',
 'TONSILS_ENLARGED',
 'Enlarged',
 'SIGN_MILD',
 'enlarged',
 2
),

(
 'EXAM-CON-TONSILS',
 'TONSILS_INFLAMED',
 'Inflamed',
 'SIGN_MODERATE',
 'inflamed',
 3
),

(
 'EXAM-CON-TONSILS',
 'TONSILS_MEMBRANOUS',
 'Membranous / exudative',
 'SIGN_SEVERE',
 'membranous',
 4
),

(
 'EXAM-CON-PHARYNX',
 'PHARYNX_NORMAL',
 'Normal',
 'SIGN_ABSENT',
 'normal',
 1
),

(
 'EXAM-CON-PHARYNX',
 'PHARYNX_INFLAMED',
 'Inflamed',
 'SIGN_MODERATE',
 'inflamed',
 2
),

(
 'EXAM-CON-PHARYNX',
 'PHARYNX_EXUDATIVE',
 'Exudative',
 'SIGN_MODERATE',
 'exudative',
 3
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 41. SURGICAL FINDING OPTIONS
-- =============================================================================

INSERT INTO knowledge.examination_finding_option
(
    examination_concept_code,
    answer_code,
    label,
    interpretation_code,
    value_text,
    sort_order
)
VALUES

(
 'EXAM-CON-MASS',
 'MASS_ABSENT',
 'No mass',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-MASS',
 'MASS_PRESENT',
 'Mass present',
 'FINDING_POSITIVE',
 'present',
 2
),

(
 'EXAM-CON-ULCER',
 'ULCER_ABSENT',
 'No ulcer',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-ULCER',
 'ULCER_PRESENT',
 'Ulcer present',
 'FINDING_POSITIVE',
 'present',
 2
),

(
 'EXAM-CON-WOUND',
 'WOUND_ABSENT',
 'No wound',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-WOUND',
 'WOUND_PRESENT',
 'Wound present',
 'FINDING_POSITIVE',
 'present',
 2
),

(
 'EXAM-CON-DISCHARGE',
 'DISCHARGE_ABSENT',
 'No discharge',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-DISCHARGE',
 'DISCHARGE_PRESENT',
 'Discharge present',
 'FINDING_POSITIVE',
 'present',
 2
),

(
 'EXAM-CON-SINUS',
 'SINUS_ABSENT',
 'No sinus',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-SINUS',
 'SINUS_PRESENT',
 'Sinus / fistula present',
 'FINDING_POSITIVE',
 'present',
 2
),

(
 'EXAM-CON-SCAR',
 'SCAR_ABSENT',
 'No significant scar',
 'SIGN_ABSENT',
 'absent',
 1
),

(
 'EXAM-CON-SCAR',
 'SCAR_PRESENT',
 'Scar present',
 'FINDING_POSITIVE',
 'present',
 2
)

ON CONFLICT (examination_concept_code, answer_code)
DO NOTHING;


-- =============================================================================
-- 42. INTERPRETATION FACT DEFINITIONS
-- =============================================================================
--
-- These are deliberately separate from the raw measurement.
--
-- Example:
--
--     HEART_RATE = 148
--     HEART_RATE_INTERPRETATION = VITAL_TACHY
--
-- The raw clinical observation remains intact.
--
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES

('HEART_RATE_INTERPRETATION',
 'coded',
 'Heart rate interpretation',
 TRUE),

('RESPIRATORY_RATE_INTERPRETATION',
 'coded',
 'Respiratory rate interpretation',
 TRUE),

('BP_SYSTOLIC_INTERPRETATION',
 'coded',
 'Systolic blood pressure interpretation',
 TRUE),

('BP_DIASTOLIC_INTERPRETATION',
 'coded',
 'Diastolic blood pressure interpretation',
 TRUE),

('SPO2_INTERPRETATION',
 'coded',
 'Oxygen saturation interpretation',
 TRUE),

('TEMPERATURE_INTERPRETATION',
 'coded',
 'Temperature interpretation',
 TRUE),

('CAPILLARY_REFILL_INTERPRETATION',
 'coded',
 'Capillary refill interpretation',
 TRUE),

('MUAC_INTERPRETATION',
 'coded',
 'MUAC interpretation',
 TRUE),

('WEIGHT_INTERPRETATION',
 'coded',
 'Weight interpretation',
 TRUE),

('HEIGHT_INTERPRETATION',
 'coded',
 'Height interpretation',
 TRUE),

('HEAD_CIRCUMFERENCE_INTERPRETATION',
 'coded',
 'Head circumference interpretation',
 TRUE),

('BMI_INTERPRETATION',
 'coded',
 'BMI interpretation',
 TRUE),

('BODY_LENGTH_INTERPRETATION',
 'coded',
 'Body length interpretation',
 TRUE)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 43. BASIC ADULT VITAL REFERENCE RANGES
-- =============================================================================
--
-- These are broad clinical reference ranges, NOT disease diagnostic criteria.
-- The interpretation engine must not convert every out-of-range measurement
-- into a diagnosis.
--
-- =============================================================================

INSERT INTO knowledge.normal_range
(
    code,
    measurement_code,
    label,
    value_type,
    age_min_months,
    age_max_months,
    sex,
    min_value,
    max_value,
    unit,
    normal_text,
    abnormal_interpretation_code,
    sort_order,
    reference_source,
    reference_version
)
VALUES

(
 'NR-HR-ADULT',
 'HEART_RATE',
 'Adult resting heart rate',
 'measurement',
 216,
 NULL,
 'all',
 60,
 100,
 'bpm',
 'Resting adult reference range; interpret with clinical context.',
 'VITAL_TACHY',
 100,
 'General clinical reference',
 'AMEXAN-045'
),

(
 'NR-RR-ADULT',
 'RESPIRATORY_RATE',
 'Adult respiratory rate',
 'measurement',
 216,
 NULL,
 'all',
 12,
 20,
 'breaths/min',
 'Resting adult respiratory rate.',
 'VITAL_TACHYPNEA',
 101,
 'General clinical reference',
 'AMEXAN-045'
),

(
 'NR-TEMP-ADULT',
 'TEMPERATURE',
 'Adult temperature',
 'measurement',
 216,
 NULL,
 'all',
 36.0,
 37.5,
 'degC',
 'Clinical interpretation depends on measurement route and context.',
 'VITAL_FEVER',
 102,
 'General clinical reference',
 'AMEXAN-045'
),

(
 'NR-SPO2-GENERAL',
 'SPO2',
 'Oxygen saturation at sea level',
 'measurement',
 0,
 NULL,
 'all',
 95,
 100,
 '%',
 'Interpret according to clinical context, altitude and underlying disease.',
 'VITAL_HYPOXEMIA',
 103,
 'General clinical reference',
 'AMEXAN-045'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 44. PAEDIATRIC RESPIRATORY RATE INTERPRETATION
-- =============================================================================
--
-- WHO IMCI uses:
--
-- 2 months to <12 months: >=50 breaths/min
-- 12 months to 5 years:   >=40 breaths/min
--
-- Do not replace this with the adult 12â€“20 reference range.
--
-- =============================================================================

INSERT INTO knowledge.normal_range
(
    code,
    measurement_code,
    label,
    value_type,
    age_min_months,
    age_max_months,
    sex,
    min_value,
    max_value,
    unit,
    normal_text,
    abnormal_interpretation_code,
    sort_order,
    reference_source,
    reference_version
)
VALUES

(
 'NR-RR-2M-12M',
 'RESPIRATORY_RATE',
 'WHO IMCI fast-breathing threshold: 2â€“12 months',
 'interpretation',
 2,
 11,
 'all',
 NULL,
 49,
 'breaths/min',
 'Fast breathing at 50 breaths/min or more.',
 'VITAL_TACHYPNEA',
 200,
 'WHO IMCI',
 'Model IMCI'
),

(
 'NR-RR-12M-60M',
 'RESPIRATORY_RATE',
 'WHO IMCI fast-breathing threshold: 12 monthsâ€“5 years',
 'interpretation',
 12,
 60,
 'all',
 NULL,
 39,
 'breaths/min',
 'Fast breathing at 40 breaths/min or more.',
 'VITAL_TACHYPNEA',
 201,
 'WHO IMCI',
 'Model IMCI'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 45. PAEDIATRIC ANTHROPOMETRY REFERENCE METADATA
-- =============================================================================
--
-- IMPORTANT:
--
-- Do NOT encode arbitrary "normal weight" values as the definitive paediatric
-- assessment.
--
-- AMEXAN should calculate:
--
--   weight-for-age
--   length/height-for-age
--   weight-for-length/height
--   BMI-for-age
--   head circumference-for-age
--
-- using sex-specific WHO reference data and Z scores.
--
-- The following rows establish the reference domains used by the engine.
--
-- =============================================================================

INSERT INTO knowledge.normal_range
(
    code,
    measurement_code,
    label,
    value_type,
    age_min_months,
    age_max_months,
    sex,
    min_value,
    max_value,
    unit,
    normal_text,
    abnormal_interpretation_code,
    sort_order,
    reference_source,
    reference_version
)
VALUES

(
 'NR-WFA-WHO',
 'WEIGHT_FOR_AGE_Z',
 'WHO weight-for-age',
 'interpretation',
 0,
 228,
 'all',
 NULL,
 NULL,
 'z',
 'Interpret using sex-specific WHO weight-for-age Z-score reference.',
 'VITAL_LOW',
 300,
 'WHO Child Growth Standards',
 'WHO 2006 / WHO 2007'
),

(
 'NR-HFA-WHO',
 'HEIGHT_FOR_AGE_Z',
 'WHO height/length-for-age',
 'interpretation',
 0,
 228,
 'all',
 NULL,
 NULL,
 'z',
 'Interpret using sex-specific WHO height/length-for-age Z-score reference.',
 'VITAL_LOW',
 301,
 'WHO Child Growth Standards',
 'WHO 2006 / WHO 2007'
),

(
 'NR-WFH-WHO',
 'WEIGHT_FOR_HEIGHT_Z',
 'WHO weight-for-height/length',
 'interpretation',
 0,
 60,
 'all',
 NULL,
 NULL,
 'z',
 'Interpret using sex-specific WHO weight-for-length/height Z-score reference.',
 'VITAL_LOW',
 302,
 'WHO Child Growth Standards',
 'WHO 2006'
),

(
 'NR-BFA-WHO',
 'BMI_FOR_AGE_Z',
 'WHO BMI-for-age',
 'interpretation',
 60,
 228,
 'all',
 NULL,
 NULL,
 'z',
 'Interpret using sex-specific WHO BMI-for-age reference.',
 'VITAL_LOW',
 303,
 'WHO Child Growth Reference',
 'WHO 2007'
),

(
 'NR-HCFA-WHO',
 'HEAD_CIRCUMFERENCE_FOR_AGE_Z',
 'WHO head circumference-for-age',
 'interpretation',
 0,
 60,
 'all',
 NULL,
 NULL,
 'z',
 'Interpret using sex-specific WHO head circumference-for-age reference.',
 'VITAL_LOW',
 304,
 'WHO Child Growth Standards',
 'WHO 2006'
)

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 46. SPECIAL CLINICAL INTERPRETATION CODES
-- =============================================================================

INSERT INTO knowledge.finding_interpretation
(
    code,
    canonical_name,
    label,
    value_type_constraint,
    is_abnormal,
    is_critical,
    sort_order,
    status
)
VALUES

('GROWTH_WITHIN_EXPECTED',
 'Growth within expected reference',
 'Within expected reference',
 'measurement',
 FALSE,
 FALSE,
 100,
 'active'),

('GROWTH_LOW',
 'Growth below expected reference',
 'Below expected',
 'measurement',
 TRUE,
 FALSE,
 101,
 'active'),

('GROWTH_HIGH',
 'Growth above expected reference',
 'Above expected',
 'measurement',
 TRUE,
 FALSE,
 102,
 'active'),

('HYPOXEMIA',
 'Hypoxaemia',
 'Hypoxaemia',
 'measurement',
 TRUE,
 TRUE,
 103,
 'active'),

('FEVER',
 'Fever',
 'Fever',
 'measurement',
 TRUE,
 FALSE,
 104,
 'active'),

('HYPOTHERMIA',
 'Hypothermia',
 'Hypothermia',
 'measurement',
 TRUE,
 TRUE,
 105,
 'active'),

('CAP_REFILL_PROLONGED',
 'Prolonged capillary refill',
 'Prolonged CRT',
 'measurement',
 TRUE,
 FALSE,
 106,
 'active')

ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 47. CONDITION-TRIGGERED SURGICAL EXAMINATION
-- =============================================================================
--
-- The local surgical module should not automatically appear for every patient.
--
-- It should be offered when:
--
--   a) the diagnostic knowledge engine identifies a surgical condition;
--   b) a relevant symptom/findings indicate a local examination is needed;
--   c) the clinician explicitly requests the examination.
--
-- =============================================================================

INSERT INTO knowledge.examination_condition
(
    examination_module_id,
    condition_id,
    weight
)
SELECT
    em.id,
    c.id,
    1.0
FROM knowledge.examination_module em
JOIN knowledge.condition c
  ON c.condition_code IN
     (
       'CONDITION-SURGICAL-DISEASE',
       'CONDITION-BREAST-DISEASE',
       'CONDITION-GI-DISEASE',
       'CONDITION-GU-DISEASE'
     )
WHERE em.module_code = 'EXAM-SURGICAL'

ON CONFLICT DO NOTHING;


-- =============================================================================
-- 48. EXAMINATION MODULE ORDER
-- =============================================================================
--
-- If these modules already exist, only missing modules are inserted.
--
-- =============================================================================

INSERT INTO knowledge.examination_module
(
    id,
    module_code,
    canonical_name,
    description,
    sort_order,
    status
)
VALUES

(
 'f1400000-0000-0000-0000-000000000001',
 'EXAM-GENERAL',
 'General Examination',
 'General physical examination.',
 10,
 'active'
),

(
 'f1400000-0000-0000-0000-000000000006',
 'EXAM-VITAL',
 'Vital Signs',
 'Core physiological measurements.',
 20,
 'active'
),

(
 'f1400000-0000-0000-0000-000000000007',
 'EXAM-SYSTEMIC',
 'Systemic Signs',
 'General systemic clinical signs.',
 30,
 'active'
),

(
 'f1400000-0000-0000-0000-000000000008',
 'EXAM-PAEDIATRIC',
 'Paediatric Examination',
 'Age-appropriate paediatric anthropometry and observations.',
 40,
 'active'
),

(
 'f1400000-0000-0000-0000-000000000002',
 'EXAM-RESPIRATORY',
 'Respiratory Examination',
 'Respiratory system examination.',
 50,
 'active'
),

(
 'f1400000-0000-0000-0000-000000000003',
 'EXAM-CARDIOVASCULAR',
 'Cardiovascular Examination',
 'Cardiovascular system examination.',
 60,
 'active'
),

(
 'f1400000-0000-0000-0000-000000000009',
 'EXAM-ABDOMEN',
 'Abdominal Examination',
 'Abdominal examination.',
 70,
 'active'
),

(
 'f1400000-0000-0000-0000-00000000000a',
 'EXAM-NEURO',
 'Neurological Examination',
 'Neurological examination.',
 80,
 'active'
),

(
 'f1400000-0000-0000-0000-00000000000b',
 'EXAM-ENT',
 'ENT Examination',
 'Ear, nose, throat and oral examination.',
 90,
 'active'
),

(
 'f1400000-0000-0000-0000-00000000000c',
 'EXAM-BREAST',
 'Breast Examination',
 'Breast and axillary examination.',
 100,
 'active'
),

(
 'f1400000-0000-0000-0000-00000000000d',
 'EXAM-GU',
 'Genitourinary Examination',
 'Genitourinary examination.',
 110,
 'active'
),

(
 'f1400000-0000-0000-0000-00000000000e',
 'EXAM-OBSTETRIC',
 'Obstetric Examination',
 'Pregnancy-specific examination.',
 120,
 'active'
),

(
 'f1400000-0000-0000-0000-00000000000f',
 'EXAM-SURGICAL',
 'Local / Surgical Examination',
 'Condition-triggered local examination.',
 130,
 'active'
)

ON CONFLICT (module_code)
DO NOTHING;


-- =============================================================================
-- 49. DATA QUALITY / CORRECTION
-- =============================================================================
--
-- The original draft incorrectly used RBS for capillary refill.
--
-- Preserve RBS if another migration has already created it, but make the
-- correct clinical fact available.
--
-- =============================================================================

INSERT INTO clinical.fact_definition
(
    code,
    data_type,
    name,
    is_active
)
VALUES
(
 'RBS',
 'numeric',
 'Random blood glucose',
 TRUE
)
ON CONFLICT (code)
DO NOTHING;


-- =============================================================================
-- 50. INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_normal_range_measurement
    ON knowledge.normal_range
    (
      measurement_code,
      age_min_months,
      age_max_months,
      sex
    );

CREATE INDEX IF NOT EXISTS ix_normal_range_active
    ON knowledge.normal_range
    (
      measurement_code,
      is_active
    );

CREATE INDEX IF NOT EXISTS ix_exam_finding_option_concept
    ON knowledge.examination_finding_option
    (
      examination_concept_code,
      sort_order
    );

CREATE INDEX IF NOT EXISTS ix_exam_concept_domain
    ON knowledge.examination_concept
    (
      domain_code,
      base_priority
    );


-- =============================================================================
-- 51. COMMENTS â€” CLINICAL SEMANTICS
-- =============================================================================

COMMENT ON COLUMN clinical.fact_definition.code IS
'Canonical AMEXAN fact code. Raw observations and derived interpretations must remain separately addressable.';

COMMENT ON TABLE knowledge.normal_range IS
'Reference knowledge only. It must not be treated as a diagnostic rule without clinical context.';

COMMENT ON TABLE knowledge.examination_finding_option IS
'Controlled examination vocabulary used by the clinical examination UI.';


-- =============================================================================
-- 52. VALIDATION QUERIES
-- =============================================================================

-- Concepts without their underlying fact definition
DO $$
DECLARE
    missing_count integer;
BEGIN

    SELECT COUNT(*)
    INTO missing_count
    FROM knowledge.examination_concept ec
    LEFT JOIN clinical.fact_definition fd
      ON fd.code = ec.fact_definition_code
    WHERE fd.code IS NULL;

    IF missing_count > 0 THEN
        RAISE WARNING
        'AMEXAN EXAMINATION KB: % examination concepts have missing fact definitions.',
        missing_count;
    END IF;

END $$;


-- Finding options without interpretation
DO $$
DECLARE
    missing_count integer;
BEGIN

    SELECT COUNT(*)
    INTO missing_count
    FROM knowledge.examination_finding_option fo
    LEFT JOIN knowledge.finding_interpretation fi
      ON fi.code = fo.interpretation_code
    WHERE fi.code IS NULL;

    IF missing_count > 0 THEN
        RAISE WARNING
        'AMEXAN EXAMINATION KB: % finding options have missing interpretations.',
        missing_count;
    END IF;

END $$;


-- =============================================================================
-- 53. FINAL MIGRATION MARKER
-- =============================================================================

COMMIT;

SELECT
    'AMEXAN 045 â€” Comprehensive Examination Knowledge Base seeded successfully'
    AS migration_status;
