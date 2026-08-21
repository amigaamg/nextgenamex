-- =============================================================================
-- AMEXAN Medical Knowledge Compiler
-- H6 MIGRATION 030 — UNIVERSAL PHYSICAL EXAMINATION KNOWLEDGE
-- HUTCHISON'S CLINICAL METHODS / GENERAL MEDICINE / CLINICAL INTELLIGENCE
-- =============================================================================
--
-- PURPOSE
-- -------
-- This migration populates the H6 examination engine with a broad universal
-- physical-examination vocabulary covering:
--
--   GENERAL MEDICINE
--   VITAL SIGNS
--   GENERAL APPEARANCE
--   HYDRATION / NUTRITION
--   SKIN
--   HEAD / FACE
--   EYES
--   EARS
--   NOSE / SINUSES
--   ORAL CAVITY / OROPHARYNX
--   NECK
--   LYMPH NODES
--   THYROID
--   BREAST
--   CARDIOVASCULAR
--   PERIPHERAL VASCULAR
--   RESPIRATORY
--   ABDOMEN
--   HEPATOSPLENIC
--   RENAL / UROLOGICAL
--   NEUROLOGICAL
--   MENTAL STATE / COGNITION
--   MUSCULOSKELETAL
--   SPINE
--   GAIT / FUNCTION
--   OBSTETRIC / PELVIC EXAMINATION
--   PAEDIATRIC EXAMINATION
--   DEVELOPMENTAL EXAMINATION
--   GERIATRIC / FUNCTIONAL EXAMINATION
--
-- IMPORTANT ARCHITECTURAL LAW
-- ----------------------------
-- The codes below NEVER become an alternative fact vocabulary.
-- Every observation_concept points to clinical.fact_definition(code).
--
-- If a canonical fact does not yet exist in the upstream H1-H5 compiler,
-- the corresponding observation concept is deliberately NOT created.
-- This keeps H6 dependent on the universal canonical fact vocabulary.
--
-- PostgreSQL = KNOWLEDGE
-- CPU        = DECISION / EXECUTION
-- UI         = RENDERING
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. SAFETY / SCHEMA
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;

-- [RECONCILED] knowledge.examination_domain was referenced (030/045/046 seeds,
-- 014 examination_module.examination_domain) but never created. Define it here
-- as the authoritative shared shape used by all three seed sources.
CREATE TABLE IF NOT EXISTS knowledge.examination_domain (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_code        text NOT NULL UNIQUE,
    code               text NOT NULL,
    body_system_code   text REFERENCES knowledge.body_system(code),
    label              text NOT NULL,
    description        text,
    sort_order         integer NOT NULL DEFAULT 0,
    is_mandatory       boolean NOT NULL DEFAULT false,
    status             text NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.examination_domain IS
'Reusable physical-examination domain grouping examination modules and components.';

CREATE INDEX IF NOT EXISTS idx_examination_domain_system
    ON knowledge.examination_domain(body_system_code);

-- [RECONCILED] The following examination-engine tables (technique, position, site,
-- interpretation, concept, observation, component, reference standard, rule,
-- phenotype link) are seeded by 030/045/046/047 but their DDL was never emitted by
-- any migration. Define them here with a union of the column shapes all seed
-- sources expect (030 uppercase vocabulary, 045/046 lowercase vocabulary).

CREATE TABLE IF NOT EXISTS knowledge.examination_technique (
    code          text PRIMARY KEY,
    name          text NOT NULL,
    description   text,
    sort_order    integer NOT NULL DEFAULT 0,
    status        text NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','draft','retired','deprecated')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.examination_position (
    position_code text PRIMARY KEY,
    name          text NOT NULL,
    description   text,
    sort_order    integer NOT NULL DEFAULT 0,
    status        text NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','draft','retired','deprecated')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.examination_site (
    code                  text PRIMARY KEY,
    body_system_code      text,
    name                  text NOT NULL,
    description           text,
    default_position_code text REFERENCES knowledge.examination_position(position_code),
    status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','draft','retired','deprecated')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.finding_interpretation (
    code                   text PRIMARY KEY,
    canonical_name         text NOT NULL,
    label                  text,
    value_type_constraint  text,
    is_abnormal            boolean NOT NULL DEFAULT false,
    is_critical            boolean NOT NULL DEFAULT false,
    description            text,
    sort_order             integer NOT NULL DEFAULT 0,
    status                 text NOT NULL DEFAULT 'active'
                           CHECK (status IN ('active','draft','retired','deprecated')),
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.examination_concept (
    code                     text PRIMARY KEY,
    domain_code              text,
    fact_definition_code     text,
    name                     text NOT NULL,
    short_label              text,
    description              text,
    body_system_code         text,
    is_mandatory             boolean NOT NULL DEFAULT false,
    base_priority            integer NOT NULL DEFAULT 0,
    technique_codes          text[] NOT NULL DEFAULT ARRAY[]::text[],
    capture_method_codes     text[] NOT NULL DEFAULT ARRAY[]::text[],
    applies_to_context_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
    status                   text NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active','draft','retired','deprecated')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.observation_concept (
    code                     text PRIMARY KEY,
    fact_definition_code     text,
    name                     text NOT NULL,
    short_label              text,
    value_type               text,
    unit                     text,
    value_set_code           text,
    normal_range             jsonb,
    applies_to_context_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
    capture_method_code      text,
    interpretation_default   text,
    status                   text NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active','draft','retired','deprecated')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.examination_component (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    examination_concept_code text NOT NULL,
    observation_concept_code text NOT NULL,
    is_mandatory             boolean NOT NULL DEFAULT false,
    sort_order               integer NOT NULL DEFAULT 0,
    status                   text NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active','draft','retired','deprecated')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (examination_concept_code, observation_concept_code)
);

CREATE TABLE IF NOT EXISTS knowledge.reference_standard (
    code                     text PRIMARY KEY,
    observation_concept_code text,
    applies_to_context_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
    range_low                numeric,
    range_high               numeric,
    range_unit               text,
    is_inclusive             boolean NOT NULL DEFAULT true,
    interpretation           text,
    source                   text,
    source_claim_code        text,
    evidence_strength        text,
    status                   text NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active','draft','retired','deprecated')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.examination_rule (
    rule_code                text PRIMARY KEY,
    trigger_type             text,
    trigger_code             text,
    target_type              text,
    target_code              text,
    modification             text,
    priority_delta           integer NOT NULL DEFAULT 0,
    rationale                text,
    evidence_claim_code      text,
    applies_to_context_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
    is_active                boolean NOT NULL DEFAULT true,
    status                   text NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active','draft','retired','deprecated')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (target_type, target_code, trigger_type, trigger_code, modification)
);

CREATE TABLE IF NOT EXISTS knowledge.finding_phenotype_link (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    observation_concept_code text NOT NULL,
    finding_value            text NOT NULL,
    associated_concept_code  text NOT NULL,
    strength                 text NOT NULL DEFAULT 'moderate'
                             CHECK (strength IN ('strong','moderate','weak','unknown')),
    description              text,
    evidence_claim_code      text,
    is_active                boolean NOT NULL DEFAULT true,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (observation_concept_code, finding_value, associated_concept_code)
);


-- =============================================================================
-- 1. EXAMINATION DOMAINS
-- =============================================================================

INSERT INTO knowledge.examination_domain
(
    domain_code,
    code,
    body_system_code,
    label,
    description,
    sort_order,
    is_mandatory
)
SELECT *
FROM
(
    VALUES
    ('DOM01','GENERAL','GENERAL','General Examination',
     'Overall clinical assessment including appearance, consciousness, distress, hydration, nutrition and functional state.',
     10,true),

    ('DOM02','VITAL_SIGNS','GENERAL','Vital Signs',
     'Core physiological measurements and immediate physiological stability.',
     20,true),

    ('DOM03','SKIN','INTEGUMENTARY','Skin and Integument',
     'Inspection and palpation of skin, hair, nails, colour, lesions, temperature and perfusion.',
     30,false),

    ('DOM04','HEAD_NECK','HEAD_NECK','Head and Neck',
     'Examination of skull, face, eyes, ears, nose, mouth, pharynx, neck and lymphatic structures.',
     40,false),

    ('DOM05','CARDIOVASCULAR','CARDIOVASCULAR','Cardiovascular Examination',
     'Precordial, peripheral vascular and haemodynamic examination.',
     50,false),

    ('DOM06','RESPIRATORY','RESPIRATORY','Respiratory Examination',
     'Inspection, palpation, percussion and auscultation of the respiratory system.',
     60,false),

    ('DOM07','ABDOMINAL','GASTROINTESTINAL','Abdominal Examination',
     'Abdominal, hepatosplenic, gastrointestinal and selected renal examination.',
     70,false),

    ('DOM08','NEUROLOGICAL','NERVOUS_SYSTEM','Neurological Examination',
     'Mental state, cranial nerves, motor, sensory, coordination, reflexes and gait.',
     80,false),

    ('DOM09','MUSCULOSKELETAL','MUSCULOSKELETAL','Musculoskeletal Examination',
     'Bones, joints, muscles, spine, posture, movement and functional examination.',
     90,false),

    ('DOM10','BREAST','REPRODUCTIVE','Breast Examination',
     'Inspection and palpation of breast, nipple and regional lymph nodes.',
     100,false),

    ('DOM11','GENITOURINARY','GENITOURINARY','Genitourinary Examination',
     'External genital, renal, urinary and relevant pelvic examination.',
     110,false),

    ('DOM12','OBSTETRIC','REPRODUCTIVE','Obstetric Examination',
     'Maternal and fetal physical examination during pregnancy.',
     120,false),

    ('DOM13','PAEDIATRIC','GENERAL','Paediatric Examination',
     'Age-adjusted examination of infants, children and adolescents.',
     130,false),

    ('DOM14','DEVELOPMENTAL','NERVOUS_SYSTEM','Developmental Examination',
     'Age-specific developmental, neurological and functional assessment.',
     140,false),

    ('DOM15','MENTAL_STATE','NERVOUS_SYSTEM','Mental State and Cognitive Examination',
     'Appearance, behaviour, speech, mood, affect, thought, perception, cognition and insight.',
     150,false),

    ('DOM16','FUNCTIONAL','GENERAL','Functional Examination',
     'Activities of daily living, mobility, exercise tolerance, falls and independence.',
     160,false),

    ('DOM17','GERIATRIC','GENERAL','Geriatric Examination',
     'Multidomain assessment of older adults including frailty, cognition, mobility and function.',
     170,false),

    ('DOM18','PERIPHERAL_VASCULAR','CARDIOVASCULAR','Peripheral Vascular Examination',
     'Peripheral pulses, perfusion, oedema, venous and arterial signs.',
     180,false),

    ('DOM19','LYMPHATIC','LYMPHATIC','Lymphatic Examination',
     'Systematic examination of superficial lymph-node groups and lymphatic signs.',
     190,false),

    ('DOM20','SPINE','MUSCULOSKELETAL','Spinal Examination',
     'Inspection, palpation, movement and neurological assessment of the spine.',
     200,false)

) AS x(domain_code,code,body_system_code,label,description,sort_order,is_mandatory)
WHERE EXISTS
(
    SELECT 1
    FROM knowledge.body_system bs
    WHERE bs.code = x.body_system_code
)
ON CONFLICT (domain_code)
DO UPDATE SET
    code = EXCLUDED.code,
    body_system_code = EXCLUDED.body_system_code,
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_mandatory = EXCLUDED.is_mandatory,
    updated_at = now();


-- =============================================================================
-- 2. FOUR FUNDAMENTAL TECHNIQUES
-- =============================================================================

INSERT INTO knowledge.examination_technique
(code,name,description,sort_order)
VALUES
(
 'TECH_INSPECTION',
 'Inspection',
 'Systematic visual assessment of appearance, colour, symmetry, movement, contour, lesions and visible abnormalities.',
 10
),
(
 'TECH_PALPATION',
 'Palpation',
 'Systematic assessment using touch for tenderness, temperature, texture, consistency, pulses, masses, organ enlargement and movement.',
 20
),
(
 'TECH_PERCUSSION',
 'Percussion',
 'Assessment of underlying structures through percussion notes and transmitted vibration.',
 30
),
(
 'TECH_AUSCULTATION',
 'Auscultation',
 'Assessment of transmitted physiological sounds including heart, lungs, bowel and vascular sounds.',
 40
)
ON CONFLICT (code)
DO UPDATE SET
 name = EXCLUDED.name,
 description = EXCLUDED.description,
 sort_order = EXCLUDED.sort_order,
 updated_at = now();


-- =============================================================================
-- 3. POSITIONS
-- =============================================================================

INSERT INTO knowledge.examination_position
(position_code,name,description,sort_order)
VALUES
('POS_STANDING','Standing',
 'Patient standing upright; used for general inspection, gait, posture, spine and selected cardiovascular/vascular manoeuvres.',
 10),

('POS_SITTING','Sitting',
 'Patient seated upright; commonly used for general, cardiovascular, respiratory and neurological examination.',
 20),

('POS_SEMI_RECUMBENT','Semi-recumbent',
 'Upper body elevated; commonly used for cardiovascular and respiratory examination.',
 30),

('POS_SUPINE','Supine',
 'Patient lying flat on the back.',
 40),

('POS_PRONE','Prone',
 'Patient lying face down.',
 50),

('POS_LEFT_LATERAL','Left lateral',
 'Patient lying on the left side; useful for cardiac auscultation and selected abdominal examination.',
 60),

('POS_RIGHT_LATERAL','Right lateral',
 'Patient lying on the right side for selected examination manoeuvres.',
 70),

('POS_LITHOTOMY','Lithotomy',
 'Patient supine with hips and knees flexed and legs supported; used for pelvic examination.',
 80),

('POS_KNEE_CHEST','Knee-chest',
 'Patient positioned on knees and chest for selected anorectal/spinal examination.',
 90),

('POS_SQUATTING','Squatting',
 'Functional position used for selected cardiovascular and lower-limb assessment.',
 100),

('POS_TRENDelenburg','Trendelenburg',
 'Supine position with head lower than feet; used selectively where clinically indicated.',
 110),

('POS_INFANT_SUPINE','Infant supine',
 'Age-adapted supine examination position for infants.',
 120),

('POS_INFANT_SITTING','Infant supported sitting',
 'Supported sitting for age-appropriate infant examination.',
 130)
ON CONFLICT (position_code)
DO UPDATE SET
 name = EXCLUDED.name,
 description = EXCLUDED.description,
 sort_order = EXCLUDED.sort_order,
 updated_at = now();


-- =============================================================================
-- 4. EXAMINATION SITES
-- =============================================================================

INSERT INTO knowledge.examination_site
(code,body_system_code,name,description,default_position_code)
SELECT
 x.code,
 x.body_system_code,
 x.name,
 x.description,
 x.default_position_code
FROM
(
 VALUES
 ('SITE_GENERAL','GENERAL','Whole patient',
  'Whole-person inspection and general assessment.','POS_SITTING'),

 ('SITE_HEAD','HEAD_NECK','Head',
  'Skull, scalp and facial structures.','POS_SITTING'),

 ('SITE_FACE','HEAD_NECK','Face',
  'Facial symmetry, expression, colour and movement.','POS_SITTING'),

 ('SITE_EYES','HEAD_NECK','Eyes',
  'External eye structures, pupils, movements and visual function.','POS_SITTING'),

 ('SITE_EARS','HEAD_NECK','Ears',
  'External auditory structures and hearing assessment.','POS_SITTING'),

 ('SITE_NOSE','HEAD_NECK','Nose and sinuses',
  'External nose, nasal passages and sinus regions.','SITTING'),

 ('SITE_ORAL_CAVITY','HEAD_NECK','Oral cavity',
  'Lips, teeth, gums, tongue, palate and mucosa.','POS_SITTING'),

 ('SITE_OROPHARYNX','HEAD_NECK','Oropharynx',
  'Tonsils, posterior pharynx and oropharyngeal structures.','POS_SITTING'),

 ('SITE_NECK','HEAD_NECK','Neck',
  'Cervical structures, trachea, thyroid, vessels and lymph nodes.','POS_SITTING'),

 ('SITE_LYMPH_NODES','LYMPHATIC','Superficial lymph nodes',
  'Systematic assessment of regional superficial lymph-node groups.','POS_SITTING'),

 ('SITE_PRECORDIUM','CARDIOVASCULAR','Precordium',
  'Cardiac area including apex and valve areas.','POS_SEMI_RECUMBENT'),

 ('SITE_CAROTIDS','CARDIOVASCULAR','Carotid arteries',
  'Carotid pulse and vascular assessment.','POS_SITTING'),

 ('SITE_PERIPHERAL_PULSES','CARDIOVASCULAR','Peripheral pulses',
  'Upper and lower limb arterial pulse points.','POS_SUPINE'),

 ('SITE_JVP','CARDIOVASCULAR','Jugular venous pressure',
  'Right internal jugular venous pressure assessment.','POS_SEMI_RECUMBENT'),

 ('SITE_LUNGS','RESPIRATORY','Chest and lungs',
  'Anterior, lateral and posterior thorax.','POS_SITTING'),

 ('SITE_POSTERIOR_CHEST','RESPIRATORY','Posterior chest',
  'Posterior thoracic respiratory examination.','POS_SITTING'),

 ('SITE_ANTERIOR_CHEST','RESPIRATORY','Anterior chest',
  'Anterior thoracic respiratory examination.','POS_SITTING'),

 ('SITE_ABDOMEN','GASTROINTESTINAL','Abdomen',
  'Four quadrants and nine abdominal regions.','POS_SUPINE'),

 ('SITE_LIVER','GASTROINTESTINAL','Liver',
  'Hepatic edge and liver span.','POS_SUPINE'),

 ('SITE_SPLEEN','GASTROINTESTINAL','Spleen',
  'Splenic enlargement assessment.','POS_SUPINE'),

 ('SITE_KIDNEYS','GENITOURINARY','Kidneys',
  'Renal palpation and renal angle assessment.','POS_SUPINE'),

 ('SITE_EXTERNAL_GENITALIA','GENITOURINARY','External genitalia',
  'External genital structures.','POS_SUPINE'),

 ('SITE_SPINE','MUSCULOSKELETAL','Spine',
  'Cervical, thoracic and lumbar spine.','POS_STANDING'),

 ('SITE_UPPER_LIMBS','MUSCULOSKELETAL','Upper limbs',
  'Shoulder, elbow, wrist and hand.','POS_SITTING'),

 ('SITE_LOWER_LIMBS','MUSCULOSKELETAL','Lower limbs',
  'Hip, knee, ankle and foot.','POS_STANDING'),

 ('SITE_BREAST','REPRODUCTIVE','Breast',
  'Breast and nipple examination.','POS_SITTING'),

 ('SITE_PELVIS','REPRODUCTIVE','Pelvis',
  'External and internal pelvic examination where indicated.','POS_LITHOTOMY'),

 ('SITE_PERINEUM','REPRODUCTIVE','Perineum',
  'Perineal examination.','POS_LITHOTOMY'),

 ('SITE_RECTUM','GASTROINTESTINAL','Anorectal region',
  'Perianal and digital rectal examination where indicated.','POS_LEFT_LATERAL'),

 ('SITE_NEUROLOGICAL','NERVOUS_SYSTEM','Neurological system',
  'Neurological examination sites across the body.','POS_SITTING')
) AS x(code,body_system_code,name,description,default_position_code)
WHERE
    x.body_system_code = 'GENERAL'
    OR EXISTS
    (
      SELECT 1
      FROM knowledge.body_system bs
      WHERE bs.code = x.body_system_code
    )
ON CONFLICT (code)
DO UPDATE SET
 body_system_code = EXCLUDED.body_system_code,
 name = EXCLUDED.name,
 description = EXCLUDED.description,
 default_position_code = EXCLUDED.default_position_code,
 updated_at = now();


-- =============================================================================
-- 5. FINDING INTERPRETATIONS
-- =============================================================================

INSERT INTO knowledge.finding_interpretation
(
 code,
 canonical_name,
 label,
 value_type_constraint,
 is_abnormal,
 is_critical,
 description,
 sort_order
)
VALUES

('FIN_NORMAL','NORMAL','Normal',NULL,false,false,
 'Finding within expected clinical range for the applicable context.',10),

('FIN_ABNORMAL','ABNORMAL','Abnormal',NULL,true,false,
 'Finding outside the expected clinical state but not automatically critical.',20),

('FIN_CRITICAL','CRITICAL','Critical',NULL,true,true,
 'Finding requiring immediate clinical attention according to applicable thresholds.',30),

('FIN_PRESENT','PRESENT','Present','BOOLEAN',true,false,
 'The finding is present.',40),

('FIN_ABSENT','ABSENT','Absent','BOOLEAN',false,false,
 'The finding is absent.',50),

('FIN_REDUCED','REDUCED','Reduced',NULL,true,false,
 'Finding is present but below expected level.',60),

('FIN_INCREASED','INCREASED','Increased',NULL,true,false,
 'Finding exceeds expected level.',70),

('FIN_TENDER','TENDER','Tender',NULL,true,false,
 'Pain or tenderness elicited on examination.',80),

('FIN_NON_TENDER','NON_TENDER','Non-tender',NULL,false,false,
 'No tenderness elicited.',90),

('FIN_VESICULAR','VESICULAR','Vesicular',NULL,false,false,
 'Expected vesicular breath sound pattern.',100),

('FIN_BRONCHIAL','BRONCHIAL','Bronchial',NULL,true,false,
 'Bronchial breath sounds detected in an unexpected peripheral location.',110),

('FIN_WHEEZE','WHEEZE','Wheeze',NULL,true,false,
 'Continuous musical respiratory sound.',120),

('FIN_CRACKLES','CRACKLES','Crackles',NULL,true,false,
 'Discontinuous adventitious respiratory sounds.',130),

('FIN_RHONCHI','RHONCHI','Rhonchi',NULL,true,false,
 'Low-pitched continuous respiratory sounds.',140),

('FIN_STRIDOR','STRIDOR','Stridor',NULL,true,true,
 'Upper-airway obstructive sound.',150),

('FIN_DULL','DULL','Dull percussion note',NULL,true,false,
 'Dull percussion note.',160),

('FIN_STONY_DULL','STONY_DULL','Stony dull',NULL,true,false,
 'Markedly dull percussion note classically associated with pleural fluid.',170),

('FIN_RESONANT','RESONANT','Resonant',NULL,false,false,
 'Expected resonant percussion note over lung.',180),

('FIN_HYPERRESONANT','HYPERRESONANT','Hyperresonant',NULL,true,false,
 'Increased resonance on percussion.',190),

('FIN_MURMUR','MURMUR','Cardiac murmur',NULL,true,false,
 'Abnormal cardiac sound associated with turbulent flow.',200),

('FIN_GALLOP','GALLOP','Gallop rhythm',NULL,true,false,
 'Additional diastolic heart sound producing a gallop rhythm.',210),

('FIN_PERICARDIAL_RUB','PERICARDIAL_RUB','Pericardial rub',NULL,true,false,
 'Characteristic friction sound from inflamed pericardial surfaces.',220),

('FIN_JVP_RAISED','JVP_RAISED','Raised JVP',NULL,true,false,
 'Elevated jugular venous pressure.',230),

('FIN_EDEMA','EDEMA','Oedema',NULL,true,false,
 'Clinically apparent tissue fluid accumulation.',240),

('FIN_CYANOSIS','CYANOSIS','Cyanosis',NULL,true,true,
 'Bluish discoloration associated with increased deoxygenated haemoglobin or abnormal haemoglobin.',250),

('FIN_PALLOR','PALLOR','Pallor',NULL,true,false,
 'Abnormally pale appearance.',260),

('FIN_JAUNDICE','JAUNDICE','Jaundice',NULL,true,false,
 'Yellow discoloration of skin or sclera.',270),

('FIN_CLUBBING','CLUBBING','Digital clubbing',NULL,true,false,
 'Characteristic enlargement and contour change of distal digits.',280),

('FIN_LYMPHADENOPATHY','LYMPHADENOPATHY','Lymphadenopathy',NULL,true,false,
 'Abnormal lymph-node enlargement or character.',290),

('FIN_HEPATOMEGALY','HEPATOMEGALY','Hepatomegaly',NULL,true,false,
 'Enlarged liver.',300),

('FIN_SPLENOMEGALY','SPLENOMEGALY','Splenomegaly',NULL,true,false,
 'Enlarged spleen.',310),

('FIN_ASCITES','ASCITES','Ascites',NULL,true,false,
 'Free fluid within the peritoneal cavity.',320),

('FIN_MASS','MASS','Mass',NULL,true,false,
 'Palpable or visible abnormal mass.',330),

('FIN_TACHYCARDIA','TACHYCARDIA','Tachycardia','NUMERIC',true,false,
 'Heart rate above applicable reference range.',340),

('FIN_BRADYCARDIA','BRADYCARDIA','Bradycardia','NUMERIC',true,false,
 'Heart rate below applicable reference range.',350),

('FIN_TACHYPNOEA','TACHYPNOEA','Tachypnoea','NUMERIC',true,false,
 'Respiratory rate above applicable reference range.',360),

('FIN_BRADYPNOEA','BRADYPNOEA','Bradypnoea','NUMERIC',true,false,
 'Respiratory rate below applicable reference range.',370),

('FIN_HYPERTENSION','HYPERTENSION','Hypertension','NUMERIC',true,false,
 'Blood pressure above applicable threshold.',380),

('FIN_HYPOTENSION','HYPOTENSION','Hypotension','NUMERIC',true,true,
 'Blood pressure below applicable clinical threshold.',390),

('FIN_HYPOXEMIA','HYPOXEMIA','Hypoxaemia','NUMERIC',true,true,
 'Oxygen saturation below the applicable clinical threshold.',400),

('FIN_FEVER','FEVER','Fever','NUMERIC',true,false,
 'Temperature above applicable threshold.',410),

('FIN_HYPOTHERMIA','HYPOTHERMIA','Hypothermia','NUMERIC',true,true,
 'Temperature below applicable threshold.',420)

ON CONFLICT (code)
DO UPDATE SET
 canonical_name = EXCLUDED.canonical_name,
 label = EXCLUDED.label,
 value_type_constraint = EXCLUDED.value_type_constraint,
 is_abnormal = EXCLUDED.is_abnormal,
 is_critical = EXCLUDED.is_critical,
 description = EXCLUDED.description,
 sort_order = EXCLUDED.sort_order,
 updated_at = now();


-- =============================================================================
-- 6. UNIVERSAL EXAMINATION CONCEPTS
-- =============================================================================

INSERT INTO knowledge.examination_concept
(
 code,
 domain_code,
 name,
 short_label,
 description,
 body_system_code,
 is_mandatory,
 base_priority,
 technique_codes,
 capture_method_codes
)
SELECT
 x.code,
 x.domain_code,
 x.name,
 x.short_label,
 x.description,
 x.body_system_code,
 x.is_mandatory,
 x.base_priority,
 x.technique_codes,
 x.capture_method_codes
FROM
(
 VALUES

 ('EX001','DOM01',
  'General Clinical Assessment',
  'General appearance',
  'Systematic overall inspection of the patient including apparent age, build, nutrition, hydration, distress, consciousness, posture, mobility and general clinical state.',
  'GENERAL',true,1000,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX002','DOM02',
  'Vital Signs',
  'Vital signs',
  'Measurement of temperature, pulse, respiratory rate, blood pressure and oxygen saturation where clinically indicated.',
  'GENERAL',true,1000,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['DEVICE_MEASURED','CLINICIAN_OBSERVED']),

 ('EX003','DOM03',
  'Skin Examination',
  'Skin',
  'Inspection and palpation of skin colour, temperature, moisture, texture, turgor, lesions, rashes, wounds and pressure areas.',
  'INTEGUMENTARY',false,300,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX004','DOM04',
  'Head and Neck Examination',
  'Head and neck',
  'Systematic examination of head, face, eyes, ears, nose, mouth, pharynx, neck, thyroid and lymph nodes.',
  'HEAD_NECK',false,300,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX005','DOM05',
  'Cardiovascular Examination',
  'Cardiovascular',
  'Systematic cardiovascular examination including pulse, blood pressure, JVP, precordium, heart sounds, murmurs, peripheral perfusion and oedema.',
  'CARDIOVASCULAR',false,700,
  ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_PERCUSSION','TECH_AUSCULTATION'],
  ARRAY['CLINICIAN_OBSERVED','DEVICE_MEASURED']),

 ('EX006','DOM06',
  'Respiratory Examination',
  'Respiratory',
  'Systematic respiratory examination using inspection, palpation, percussion and auscultation.',
  'RESPIRATORY',false,700,
  ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_PERCUSSION','TECH_AUSCULTATION'],
  ARRAY['CLINICIAN_OBSERVED','DEVICE_MEASURED']),

 ('EX007','DOM07',
  'Abdominal Examination',
  'Abdomen',
  'Systematic abdominal examination including inspection, auscultation, percussion and palpation, with assessment of liver, spleen, kidneys, masses, tenderness and ascites.',
  'GASTROINTESTINAL',false,600,
  ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_PERCUSSION','TECH_AUSCULTATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX008','DOM08',
  'Neurological Examination',
  'Neurology',
  'Systematic neurological examination including mental state, cranial nerves, motor, sensory, reflexes, coordination and gait.',
  'NERVOUS_SYSTEM',false,600,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX009','DOM09',
  'Musculoskeletal Examination',
  'Musculoskeletal',
  'Systematic examination of posture, gait, joints, range of movement, muscle bulk, tone, power, tenderness and deformity.',
  'MUSCULOSKELETAL',false,400,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX010','DOM10',
  'Breast Examination',
  'Breast',
  'Inspection and palpation of breast tissue, nipples, axillae and regional lymph nodes.',
  'REPRODUCTIVE',false,400,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX011','DOM11',
  'Genitourinary Examination',
  'Genitourinary',
  'Focused examination of external genitalia, renal angles and selected urinary-system findings.',
  'GENITOURINARY',false,400,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX012','DOM12',
  'Obstetric Examination',
  'Obstetric',
  'Maternal general assessment, fundal assessment, fetal lie, presentation, position, engagement and fetal wellbeing as clinically appropriate.',
  'REPRODUCTIVE',false,700,
  ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_AUSCULTATION'],
  ARRAY['CLINICIAN_OBSERVED','DEVICE_MEASURED']),

 ('EX013','DOM15',
  'Mental State Examination',
  'Mental state',
  'Systematic examination of appearance, behaviour, psychomotor activity, speech, mood, affect, thought, perception, cognition, insight and judgement.',
  'NERVOUS_SYSTEM',false,500,
  ARRAY['TECH_INSPECTION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX014','DOM16',
  'Functional Examination',
  'Function',
  'Assessment of mobility, transfers, gait, balance, activities of daily living and functional independence.',
  'GENERAL',false,300,
  ARRAY['TECH_INSPECTION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX015','DOM13',
  'Paediatric Examination',
  'Child examination',
  'Age-adjusted examination integrating growth, nutrition, development, vital signs and system examination.',
  'GENERAL',false,800,
  ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_AUSCULTATION'],
  ARRAY['CLINICIAN_OBSERVED','DEVICE_MEASURED']),

 ('EX016','DOM14',
  'Developmental Examination',
  'Development',
  'Assessment of age-appropriate gross motor, fine motor, language, communication, social and adaptive function.',
  'NERVOUS_SYSTEM',false,400,
  ARRAY['TECH_INSPECTION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX017','DOM17',
  'Geriatric Examination',
  'Older adult assessment',
  'Multidomain examination of frailty, mobility, cognition, continence, nutrition, vision, hearing and function.',
  'GENERAL',false,400,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED','DEVICE_MEASURED']),

 ('EX018','DOM18',
  'Peripheral Vascular Examination',
  'Peripheral vascular',
  'Assessment of peripheral pulses, perfusion, capillary refill, skin changes, oedema and arterial/venous signs.',
  'CARDIOVASCULAR',false,500,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX019','DOM19',
  'Lymphatic Examination',
  'Lymph nodes',
  'Systematic assessment of cervical, supraclavicular, axillary, epitrochlear and inguinal lymph nodes.',
  'LYMPHATIC',false,300,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED']),

 ('EX020','DOM20',
  'Spinal Examination',
  'Spine',
  'Inspection, palpation, movement and neurological assessment of the spine.',
  'MUSCULOSKELETAL',false,400,
  ARRAY['TECH_INSPECTION','TECH_PALPATION'],
  ARRAY['CLINICIAN_OBSERVED'])

) AS x(
 code,domain_code,name,short_label,description,body_system_code,
 is_mandatory,base_priority,technique_codes,capture_method_codes
)
WHERE EXISTS
(
 SELECT 1
 FROM knowledge.body_system bs
 WHERE bs.code = x.body_system_code
)
ON CONFLICT (code)
DO UPDATE SET
 domain_code = EXCLUDED.domain_code,
 name = EXCLUDED.name,
 short_label = EXCLUDED.short_label,
 description = EXCLUDED.description,
 body_system_code = EXCLUDED.body_system_code,
 is_mandatory = EXCLUDED.is_mandatory,
 base_priority = EXCLUDED.base_priority,
 technique_codes = EXCLUDED.technique_codes,
 capture_method_codes = EXCLUDED.capture_method_codes,
 updated_at = now();


-- =============================================================================
-- 7. OBSERVATION CONCEPTS
-- =============================================================================
-- Only created when the canonical H1-H5 fact_definition already exists.
-- =============================================================================

CREATE TEMP TABLE IF NOT EXISTS tmp_h6_observations
(
 code text PRIMARY KEY,
 fact_code text NOT NULL,
 name text NOT NULL,
 short_label text,
 value_type text NOT NULL,
 unit text,
 interpretation_default text
) ON COMMIT DROP;

INSERT INTO tmp_h6_observations
VALUES

-- -------------------------------------------------------------------------
-- GENERAL
-- -------------------------------------------------------------------------

('OC001','GENERAL_APPEARANCE','General appearance','Appearance','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC002','LEVEL_OF_CONSCIOUSNESS','Level of consciousness','Consciousness','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC003','DISTRESS','Clinical distress','Distress','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC004','POSTURE','Posture','Posture','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC005','NUTRITIONAL_STATE','Nutritional state','Nutrition','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC006','HYDRATION_STATUS','Hydration status','Hydration','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC007','BODY_BUILD','Body build','Build','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC008','FACIAL_EXPRESSION','Facial expression','Expression','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC009','MOBILITY','Mobility','Mobility','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC010','GENERAL_COLOUR','General colour','Colour','CATEGORICAL',NULL,'FIN_NORMAL'),

-- -------------------------------------------------------------------------
-- VITAL SIGNS
-- -------------------------------------------------------------------------

('OC011','BODY_TEMPERATURE','Body temperature','Temperature','NUMERIC','°C',NULL),
('OC012','HEART_RATE','Heart rate','Pulse','NUMERIC','bpm',NULL),
('OC013','RESPIRATORY_RATE','Respiratory rate','RR','NUMERIC','breaths/min',NULL),
('OC014','SYSTOLIC_BLOOD_PRESSURE','Systolic blood pressure','SBP','NUMERIC','mmHg',NULL),
('OC015','DIASTOLIC_BLOOD_PRESSURE','Diastolic blood pressure','DBP','NUMERIC','mmHg',NULL),
('OC016','OXYGEN_SATURATION','Peripheral oxygen saturation','SpO₂','NUMERIC','%',NULL),
('OC017','CAPILLARY_REFILL_TIME','Capillary refill time','CRT','NUMERIC','seconds',NULL),
('OC018','PAIN_SCORE','Pain intensity','Pain score','NUMERIC','/10',NULL),
('OC019','WEIGHT','Body weight','Weight','NUMERIC','kg',NULL),
('OC020','HEIGHT','Height','Height','NUMERIC','cm',NULL),
('OC021','BMI','Body mass index','BMI','NUMERIC','kg/m²',NULL),

-- -------------------------------------------------------------------------
-- SKIN
-- -------------------------------------------------------------------------

('OC022','SKIN_COLOUR','Skin colour','Colour','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC023','SKIN_TEMPERATURE','Skin temperature','Temperature','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC024','SKIN_MOISTURE','Skin moisture','Moisture','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC025','SKIN_TURGOR','Skin turgor','Turgor','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC026','SKIN_RASH','Skin rash','Rash','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC027','SKIN_LESION','Skin lesion','Lesion','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC028','PRESSURE_INJURY','Pressure injury','Pressure injury','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC029','CYANOSIS','Cyanosis','Cyanosis','BOOLEAN',NULL,'FIN_ABSENT'),
('OC030','PALLOR','Pallor','Pallor','BOOLEAN',NULL,'FIN_ABSENT'),
('OC031','JAUNDICE','Jaundice','Jaundice','BOOLEAN',NULL,'FIN_ABSENT'),
('OC032','CLUBBING','Digital clubbing','Clubbing','BOOLEAN',NULL,'FIN_ABSENT'),

-- -------------------------------------------------------------------------
-- HEAD / EYES / EARS / NOSE / MOUTH
-- -------------------------------------------------------------------------

('OC033','HEAD_SHAPE','Head shape','Head shape','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC034','SCALP_FINDING','Scalp finding','Scalp','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC035','FACIAL_SYMMETRY','Facial symmetry','Symmetry','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC036','PUPIL_SIZE','Pupil size','Pupils','CATEGORICAL','mm',NULL),
('OC037','PUPIL_REACTIVITY','Pupillary reaction','Pupil reaction','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC038','PUPILLARY_SYMMETRY','Pupillary symmetry','Pupil symmetry','BOOLEAN',NULL,'FIN_PRESENT'),
('OC039','EXTRAOCULAR_MOVEMENTS','Extraocular movements','EOM','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC040','VISUAL_ACUITY','Visual acuity','Visual acuity','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC041','CONJUNCTIVAL_COLOUR','Conjunctival colour','Conjunctiva','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC042','SCLERAL_COLOUR','Scleral colour','Sclera','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC043','FUNDOSCOPIC_FINDING','Fundoscopic finding','Fundoscopy','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC044','EXTERNAL_EAR_FINDING','External ear finding','External ear','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC045','HEARING','Hearing','Hearing','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC046','NASAL_FINDING','Nasal finding','Nose','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC047','ORAL_MUCOSA','Oral mucosa','Mucosa','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC048','DENTITION','Dentition','Teeth','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC049','TONGUE_FINDING','Tongue finding','Tongue','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC050','TONSIL_FINDING','Tonsillar finding','Tonsils','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC051','PHARYNGEAL_FINDING','Pharyngeal finding','Pharynx','CATEGORICAL',NULL,'FIN_NORMAL'),

-- -------------------------------------------------------------------------
-- NECK / LYMPHATIC
-- -------------------------------------------------------------------------

('OC052','CERVICAL_LYMPH_NODE','Cervical lymph node','Cervical nodes','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC053','SUPRACLAVICULAR_LYMPH_NODE','Supraclavicular lymph node','Supraclavicular nodes','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC054','AXILLARY_LYMPH_NODE','Axillary lymph node','Axillary nodes','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC055','INGUINAL_LYMPH_NODE','Inguinal lymph node','Inguinal nodes','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC056','EPITROCHLEAR_LYMPH_NODE','Epitrochlear lymph node','Epitrochlear nodes','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC057','THYROID_SIZE','Thyroid size','Thyroid','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC058','THYROID_NODULE','Thyroid nodule','Nodule','BOOLEAN',NULL,'FIN_ABSENT'),
('OC059','TRACHEAL_POSITION','Tracheal position','Trachea','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC060','NECK_MASS','Neck mass','Neck mass','CATEGORICAL',NULL,'FIN_ABSENT'),

-- -------------------------------------------------------------------------
-- CARDIOVASCULAR
-- -------------------------------------------------------------------------

('OC061','JVP_HEIGHT','Jugular venous pressure','JVP','NUMERIC','cmH₂O',NULL),
('OC062','JVP_WAVEFORM','JVP waveform','JVP waveform','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC063','CAROTID_PULSE','Carotid pulse','Carotid','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC064','RADIAL_PULSE','Radial pulse','Radial','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC065','BRACHIAL_PULSE','Brachial pulse','Brachial','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC066','FEMORAL_PULSE','Femoral pulse','Femoral','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC067','POPLITEAL_PULSE','Popliteal pulse','Popliteal','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC068','POSTERIOR_TIBIAL_PULSE','Posterior tibial pulse','PT','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC069','DORSALIS_PEDIS_PULSE','Dorsalis pedis pulse','DP','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC070','APEX_BEAT_LOCATION','Apex beat location','Apex','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC071','APEX_BEAT_CHARACTER','Apex beat character','Apex character','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC072','PRECORDIAL_HEAVE','Precordial heave','Heave','BOOLEAN',NULL,'FIN_ABSENT'),
('OC073','CARDIAC_THRILL','Cardiac thrill','Thrill','BOOLEAN',NULL,'FIN_ABSENT'),
('OC074','FIRST_HEART_SOUND','First heart sound','S1','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC075','SECOND_HEART_SOUND','Second heart sound','S2','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC076','THIRD_HEART_SOUND','Third heart sound','S3','BOOLEAN',NULL,'FIN_ABSENT'),
('OC077','FOURTH_HEART_SOUND','Fourth heart sound','S4','BOOLEAN',NULL,'FIN_ABSENT'),
('OC078','CARDIAC_MURMUR','Cardiac murmur','Murmur','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC079','MURMUR_TIMING','Murmur timing','Timing','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC080','MURMUR_LOCATION','Murmur location','Location','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC081','MURMUR_RADIATION','Murmur radiation','Radiation','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC082','MURMUR_INTENSITY','Murmur intensity','Grade','ORDINAL',NULL,'FIN_NORMAL'),
('OC083','PERICARDIAL_RUB','Pericardial rub','Rub','BOOLEAN',NULL,'FIN_ABSENT'),
('OC084','PERIPHERAL_OEDEMA','Peripheral oedema','Oedema','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC085','PERIPHERAL_PERFUSION','Peripheral perfusion','Perfusion','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC086','PULSE_SYMMETRY','Pulse symmetry','Symmetry','BOOLEAN',NULL,'FIN_PRESENT'),

-- -------------------------------------------------------------------------
-- RESPIRATORY
-- -------------------------------------------------------------------------

('OC087','WORK_OF_BREATHING','Work of breathing','WOB','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC088','RESPIRATORY_EFFORT','Respiratory effort','Effort','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC089','CHEST_SHAPE','Chest shape','Chest shape','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC090','CHEST_SYMMETRY','Chest symmetry','Symmetry','BOOLEAN',NULL,'FIN_PRESENT'),
('OC091','CHEST_EXPANSION','Chest expansion','Expansion','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC092','TRACHEAL_DEVIATION','Tracheal deviation','Trachea','BOOLEAN',NULL,'FIN_ABSENT'),
('OC093','TACTILE_VOCAL_FREMITUS','Tactile vocal fremitus','Fremitus','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC094','PERCUSSION_NOTE','Chest percussion note','Percussion','CATEGORICAL',NULL,'FIN_RESONANT'),
('OC095','BREATH_SOUND','Breath sound','Breath sounds','CATEGORICAL',NULL,'FIN_VESICULAR'),
('OC096','WHEEZE','Wheeze','Wheeze','BOOLEAN',NULL,'FIN_ABSENT'),
('OC097','CRACKLES','Crackles','Crackles','BOOLEAN',NULL,'FIN_ABSENT'),
('OC098','RHONCHI','Rhonchi','Rhonchi','BOOLEAN',NULL,'FIN_ABSENT'),
('OC099','STRIDOR','Stridor','Stridor','BOOLEAN',NULL,'FIN_ABSENT'),
('OC100','PLEURAL_RUB','Pleural rub','Pleural rub','BOOLEAN',NULL,'FIN_ABSENT'),
('OC101','VOCAL_RESONANCE','Vocal resonance','VR','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC102','BRONCHOPHONY','Bronchophony','Bronchophony','BOOLEAN',NULL,'FIN_ABSENT'),
('OC103','WHISPERED_PECTORILOQUY','Whispered pectoriloquy','Whispered pectoriloquy','BOOLEAN',NULL,'FIN_ABSENT'),

-- -------------------------------------------------------------------------
-- ABDOMEN
-- -------------------------------------------------------------------------

('OC104','ABDOMINAL_DISTENSION','Abdominal distension','Distension','BOOLEAN',NULL,'FIN_ABSENT'),
('OC105','ABDOMINAL_SCAR','Abdominal scar','Scars','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC106','ABDOMINAL_BOWEL_SOUNDS','Bowel sounds','Bowel sounds','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC107','ABDOMINAL_TENDERNESS','Abdominal tenderness','Tenderness','CATEGORICAL',NULL,'FIN_NON_TENDER'),
('OC108','ABDOMINAL_GUARDING','Abdominal guarding','Guarding','BOOLEAN',NULL,'FIN_ABSENT'),
('OC109','ABDOMINAL_RIGIDITY','Abdominal rigidity','Rigidity','BOOLEAN',NULL,'FIN_ABSENT'),
('OC110','ABDOMINAL_REBOUND','Rebound tenderness','Rebound','BOOLEAN',NULL,'FIN_ABSENT'),
('OC111','ABDOMINAL_MASS','Abdominal mass','Mass','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC112','LIVER_EDGE','Liver edge','Liver edge','CATEGORICAL','cm',NULL),
('OC113','LIVER_SURFACE','Liver surface','Surface','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC114','LIVER_TENDERNESS','Liver tenderness','Tender liver','BOOLEAN',NULL,'FIN_ABSENT'),
('OC115','SPLEEN_SIZE','Spleen size','Spleen','CATEGORICAL','cm',NULL),
('OC116','SPLENIC_TENDERNESS','Splenic tenderness','Tender spleen','BOOLEAN',NULL,'FIN_ABSENT'),
('OC117','ASCITES','Ascites','Ascites','BOOLEAN',NULL,'FIN_ABSENT'),
('OC118','FLUID_THRILL','Fluid thrill','Fluid thrill','BOOLEAN',NULL,'FIN_ABSENT'),
('OC119','SHIFTING_DULLNESS','Shifting dullness','Shifting dullness','BOOLEAN',NULL,'FIN_ABSENT'),
('OC120','RENAL_PALPABILITY','Renal palpability','Kidneys','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC121','RENAL_ANGLE_TENDERNESS','Renal angle tenderness','Renal angle','BOOLEAN',NULL,'FIN_ABSENT'),

-- -------------------------------------------------------------------------
-- NEUROLOGICAL
-- -------------------------------------------------------------------------

('OC122','MENTAL_STATUS','Mental status','Mental status','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC123','ORIENTATION','Orientation','Orientation','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC124','ATTENTION','Attention','Attention','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC125','MEMORY','Memory','Memory','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC126','SPEECH','Speech','Speech','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC127','LANGUAGE','Language','Language','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC128','MOOD','Mood','Mood','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC129','AFFECT','Affect','Affect','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC130','THOUGHT_PROCESS','Thought process','Thought','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC131','THOUGHT_CONTENT','Thought content','Content','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC132','PERCEPTION','Perception','Perception','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC133','INSIGHT','Insight','Insight','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC134','JUDGEMENT','Judgement','Judgement','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC135','CRANIAL_NERVE_I','Cranial nerve I','CN I','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC136','CRANIAL_NERVE_II','Cranial nerve II','CN II','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC137','CRANIAL_NERVE_III_IV_VI','Cranial nerves III IV VI','Ocular motor nerves','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC138','CRANIAL_NERVE_V','Trigeminal nerve','CN V','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC139','CRANIAL_NERVE_VII','Facial nerve','CN VII','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC140','CRANIAL_NERVE_VIII','Vestibulocochlear nerve','CN VIII','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC141','CRANIAL_NERVE_IX_X','Glossopharyngeal/vagus','CN IX/X','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC142','CRANIAL_NERVE_XI','Accessory nerve','CN XI','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC143','CRANIAL_NERVE_XII','Hypoglossal nerve','CN XII','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC144','MUSCLE_BULK','Muscle bulk','Bulk','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC145','MUSCLE_TONE','Muscle tone','Tone','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC146','MUSCLE_POWER','Muscle power','Power','ORDINAL','/5',NULL),
('OC147','REFLEXES','Deep tendon reflexes','Reflexes','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC148','PLANTAR_RESPONSE','Plantar response','Plantars','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC149','LIGHT_TOUCH','Light touch','Light touch','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC150','PINPRICK_SENSATION','Pinprick sensation','Pinprick','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC151','VIBRATION_SENSE','Vibration sense','Vibration','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC152','PROPRIOCEPTION','Proprioception','Position sense','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC153','COORDINATION','Coordination','Coordination','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC154','GAIT','Gait','Gait','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC155','ROMBERG_TEST','Romberg test','Romberg','BOOLEAN',NULL,'FIN_ABSENT'),

-- -------------------------------------------------------------------------
-- MUSCULOSKELETAL
-- -------------------------------------------------------------------------

('OC156','JOINT_SWELLING','Joint swelling','Swelling','BOOLEAN',NULL,'FIN_ABSENT'),
('OC157','JOINT_TENDERNESS','Joint tenderness','Tenderness','BOOLEAN',NULL,'FIN_ABSENT'),
('OC158','JOINT_DEFORMITY','Joint deformity','Deformity','BOOLEAN',NULL,'FIN_ABSENT'),
('OC159','JOINT_RANGE_OF_MOTION','Joint range of motion','ROM','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC160','MUSCLE_TENDERNESS','Muscle tenderness','Muscle tenderness','BOOLEAN',NULL,'FIN_ABSENT'),
('OC161','SPINAL_ALIGNMENT','Spinal alignment','Alignment','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC162','SPINAL_TENDERNESS','Spinal tenderness','Tenderness','BOOLEAN',NULL,'FIN_ABSENT'),
('OC163','SPINAL_RANGE_OF_MOTION','Spinal range of motion','Spinal ROM','CATEGORICAL',NULL,'FIN_NORMAL'),

-- -------------------------------------------------------------------------
-- BREAST
-- -------------------------------------------------------------------------

('OC164','BREAST_SYMMETRY','Breast symmetry','Symmetry','BOOLEAN',NULL,'FIN_PRESENT'),
('OC165','BREAST_SKIN_CHANGE','Breast skin change','Skin','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC166','BREAST_MASS','Breast mass','Mass','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC167','NIPPLE_DISCHARGE','Nipple discharge','Discharge','CATEGORICAL',NULL,'FIN_ABSENT'),
('OC168','NIPPLE_RETRACTION','Nipple retraction','Retraction','BOOLEAN',NULL,'FIN_ABSENT'),
('OC169','AXILLARY_NODE_BREAST','Axillary node finding','Axillary nodes','CATEGORICAL',NULL,'FIN_ABSENT'),

-- -------------------------------------------------------------------------
-- OBSTETRIC
-- -------------------------------------------------------------------------

('OC170','FUNDAL_HEIGHT','Fundal height','SFH','NUMERIC','cm',NULL),
('OC171','UTERINE_TONE','Uterine tone','Tone','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC172','FETAL_LIE','Fetal lie','Lie','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC173','FETAL_PRESENTATION','Fetal presentation','Presentation','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC174','FETAL_POSITION','Fetal position','Position','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC175','FETAL_ENGAGEMENT','Fetal engagement','Engagement','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC176','FETAL_HEART_RATE','Fetal heart rate','FHR','NUMERIC','bpm',NULL),
('OC177','UTERINE_CONTRACTIONS','Uterine contractions','Contractions','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC178','FETAL_MOVEMENT_OBSERVED','Fetal movement','Movement','CATEGORICAL',NULL,'FIN_NORMAL'),

-- -------------------------------------------------------------------------
-- FUNCTIONAL / GERIATRIC
-- -------------------------------------------------------------------------

('OC179','TRANSFER_ABILITY','Transfer ability','Transfers','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC180','BALANCE','Balance','Balance','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC181','FALL_RISK_FINDING','Fall-risk finding','Falls','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC182','ADL_FUNCTION','Activities of daily living','ADL','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC183','FRAILTY_FINDING','Frailty finding','Frailty','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC184','NUTRITIONAL_FUNCTION','Nutritional functional status','Nutrition function','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC185','VISION_FUNCTION','Functional vision','Vision','CATEGORICAL',NULL,'FIN_NORMAL'),
('OC186','HEARING_FUNCTION','Functional hearing','Hearing','CATEGORICAL',NULL,'FIN_NORMAL')

ON CONFLICT (code)
DO UPDATE SET
 fact_code = EXCLUDED.fact_code,
 name = EXCLUDED.name,
 short_label = EXCLUDED.short_label,
 value_type = EXCLUDED.value_type,
 unit = EXCLUDED.unit,
 interpretation_default = EXCLUDED.interpretation_default;


-- =============================================================================
-- 8. CREATE ONLY OBSERVATIONS WHOSE CANONICAL FACTS EXIST
-- =============================================================================

INSERT INTO knowledge.observation_concept
(
 code,
 fact_definition_code,
 name,
 short_label,
 value_type,
 unit,
 interpretation_default
)
SELECT
 t.code,
 t.fact_code,
 t.name,
 t.short_label,
 t.value_type,
 t.unit,
 t.interpretation_default
FROM tmp_h6_observations t
JOIN clinical.fact_definition f
  ON f.code = t.fact_code
ON CONFLICT (code)
DO UPDATE SET
 fact_definition_code = EXCLUDED.fact_definition_code,
 name = EXCLUDED.name,
 short_label = EXCLUDED.short_label,
 value_type = EXCLUDED.value_type,
 unit = EXCLUDED.unit,
 interpretation_default = EXCLUDED.interpretation_default,
 updated_at = now();


-- =============================================================================
-- 9. EXAMINATION COMPONENTS
-- =============================================================================

INSERT INTO knowledge.examination_component
(
 examination_concept_code,
 observation_concept_code,
 is_mandatory,
 sort_order
)
SELECT
 v.exam_code,
 v.obs_code,
 v.mandatory,
 v.sort_order
FROM
(
 VALUES

 -- GENERAL
 ('EX001','OC001',true,10),
 ('EX001','OC002',true,20),
 ('EX001','OC003',true,30),
 ('EX001','OC004',false,40),
 ('EX001','OC005',false,50),
 ('EX001','OC006',false,60),
 ('EX001','OC007',false,70),
 ('EX001','OC008',false,80),
 ('EX001','OC009',false,90),
 ('EX001','OC010',false,100),

 -- VITALS
 ('EX002','OC011',true,10),
 ('EX002','OC012',true,20),
 ('EX002','OC013',true,30),
 ('EX002','OC014',true,40),
 ('EX002','OC015',true,50),
 ('EX002','OC016',false,60),
 ('EX002','OC017',false,70),
 ('EX002','OC018',false,80),
 ('EX002','OC019',false,90),
 ('EX002','OC020',false,100),
 ('EX002','OC021',false,110),

 -- SKIN
 ('EX003','OC022',true,10),
 ('EX003','OC023',false,20),
 ('EX003','OC024',false,30),
 ('EX003','OC025',false,40),
 ('EX003','OC026',false,50),
 ('EX003','OC027',false,60),
 ('EX003','OC028',false,70),
 ('EX003','OC029',false,80),
 ('EX003','OC030',false,90),
 ('EX003','OC031',false,100),
 ('EX003','OC032',false,110),

 -- HEAD/NECK
 ('EX004','OC033',false,10),
 ('EX004','OC034',false,20),
 ('EX004','OC035',false,30),
 ('EX004','OC036',false,40),
 ('EX004','OC037',false,50),
 ('EX004','OC038',false,60),
 ('EX004','OC039',false,70),
 ('EX004','OC040',false,80),
 ('EX004','OC041',false,90),
 ('EX004','OC042',false,100),
 ('EX004','OC043',false,110),
 ('EX004','OC044',false,120),
 ('EX004','OC045',false,130),
 ('EX004','OC046',false,140),
 ('EX004','OC047',false,150),
 ('EX004','OC048',false,160),
 ('EX004','OC049',false,170),
 ('EX004','OC050',false,180),
 ('EX004','OC051',false,190),
 ('EX004','OC057',false,200),
 ('EX004','OC058',false,210),
 ('EX004','OC059',false,220),
 ('EX004','OC060',false,230),

 -- LYMPHATIC
 ('EX019','OC052',false,10),
 ('EX019','OC053',false,20),
 ('EX019','OC054',false,30),
 ('EX019','OC055',false,40),
 ('EX019','OC056',false,50),

 -- CARDIOVASCULAR
 ('EX005','OC061',false,10),
 ('EX005','OC062',false,20),
 ('EX005','OC063',false,30),
 ('EX005','OC064',true,40),
 ('EX005','OC065',false,50),
 ('EX005','OC066',false,60),
 ('EX005','OC067',false,70),
 ('EX005','OC068',false,80),
 ('EX005','OC069',false,90),
 ('EX005','OC070',false,100),
 ('EX005','OC071',false,110),
 ('EX005','OC072',false,120),
 ('EX005','OC073',false,130),
 ('EX005','OC074',true,140),
 ('EX005','OC075',true,150),
 ('EX005','OC076',false,160),
 ('EX005','OC077',false,170),
 ('EX005','OC078',false,180),
 ('EX005','OC079',false,190),
 ('EX005','OC080',false,200),
 ('EX005','OC081',false,210),
 ('EX005','OC082',false,220),
 ('EX005','OC083',false,230),
 ('EX005','OC084',false,240),
 ('EX005','OC085',false,250),
 ('EX005','OC086',false,260),

 -- RESPIRATORY
 ('EX006','OC087',true,10),
 ('EX006','OC088',true,20),
 ('EX006','OC089',false,30),
 ('EX006','OC090',false,40),
 ('EX006','OC091',true,50),
 ('EX006','OC092',false,60),
 ('EX006','OC093',false,70),
 ('EX006','OC094',true,80),
 ('EX006','OC095',true,90),
 ('EX006','OC096',false,100),
 ('EX006','OC097',false,110),
 ('EX006','OC098',false,120),
 ('EX006','OC099',false,130),
 ('EX006','OC100',false,140),
 ('EX006','OC101',false,150),
 ('EX006','OC102',false,160),
 ('EX006','OC103',false,170),

 -- ABDOMEN
 ('EX007','OC104',true,10),
 ('EX007','OC105',false,20),
 ('EX007','OC106',true,30),
 ('EX007','OC107',true,40),
 ('EX007','OC108',false,50),
 ('EX007','OC109',false,60),
 ('EX007','OC110',false,70),
 ('EX007','OC111',false,80),
 ('EX007','OC112',false,90),
 ('EX007','OC113',false,100),
 ('EX007','OC114',false,110),
 ('EX007','OC115',false,120),
 ('EX007','OC116',false,130),
 ('EX007','OC117',false,140),
 ('EX007','OC118',false,150),
 ('EX007','OC119',false,160),
 ('EX007','OC120',false,170),
 ('EX007','OC121',false,180),

 -- NEUROLOGY
 ('EX008','OC122',true,10),
 ('EX008','OC123',false,20),
 ('EX008','OC124',false,30),
 ('EX008','OC125',false,40),
 ('EX008','OC126',false,50),
 ('EX008','OC127',false,60),
 ('EX008','OC128',false,70),
 ('EX008','OC129',false,80),
 ('EX008','OC130',false,90),
 ('EX008','OC131',false,100),
 ('EX008','OC132',false,110),
 ('EX008','OC133',false,120),
 ('EX008','OC134',false,130),
 ('EX008','OC135',false,140),
 ('EX008','OC136',false,150),
 ('EX008','OC137',false,160),
 ('EX008','OC138',false,170),
 ('EX008','OC139',false,180),
 ('EX008','OC140',false,190),
 ('EX008','OC141',false,200),
 ('EX008','OC142',false,210),
 ('EX008','OC143',false,220),
 ('EX008','OC144',false,230),
 ('EX008','OC145',false,240),
 ('EX008','OC146',false,250),
 ('EX008','OC147',false,260),
 ('EX008','OC148',false,270),
 ('EX008','OC149',false,280),
 ('EX008','OC150',false,290),
 ('EX008','OC151',false,300),
 ('EX008','OC152',false,310),
 ('EX008','OC153',false,320),
 ('EX008','OC154',false,330),
 ('EX008','OC155',false,340),

 -- MUSCULOSKELETAL
 ('EX009','OC156',false,10),
 ('EX009','OC157',false,20),
 ('EX009','OC158',false,30),
 ('EX009','OC159',false,40),
 ('EX009','OC160',false,50),
 ('EX009','OC161',false,60),
 ('EX009','OC162',false,70),
 ('EX009','OC163',false,80),

 -- BREAST
 ('EX010','OC164',false,10),
 ('EX010','OC165',false,20),
 ('EX010','OC166',false,30),
 ('EX010','OC167',false,40),
 ('EX010','OC168',false,50),
 ('EX010','OC169',false,60),

 -- OBSTETRIC
 ('EX012','OC170',true,10),
 ('EX012','OC171',false,20),
 ('EX012','OC172',true,30),
 ('EX012','OC173',true,40),
 ('EX012','OC174',false,50),
 ('EX012','OC175',false,60),
 ('EX012','OC176',true,70),
 ('EX012','OC177',false,80),
 ('EX012','OC178',false,90),

 -- MENTAL STATE
 ('EX013','OC122',true,10),
 ('EX013','OC123',false,20),
 ('EX013','OC124',false,30),
 ('EX013','OC125',false,40),
 ('EX013','OC126',true,50),
 ('EX013','OC127',false,60),
 ('EX013','OC128',true,70),
 ('EX013','OC129',true,80),
 ('EX013','OC130',true,90),
 ('EX013','OC131',true,100),
 ('EX013','OC132',true,110),
 ('EX013','OC133',false,120),
 ('EX013','OC134',false,130),

 -- FUNCTIONAL
 ('EX014','OC009',true,10),
 ('EX014','OC154',true,20),
 ('EX014','OC179',false,30),
 ('EX014','OC180',false,40),
 ('EX014','OC181',false,50),
 ('EX014','OC182',false,60),

 -- PAEDIATRIC
 ('EX015','OC001',true,10),
 ('EX015','OC002',true,20),
 ('EX015','OC011',true,30),
 ('EX015','OC012',true,40),
 ('EX015','OC013',true,50),
 ('EX015','OC016',true,60),
 ('EX015','OC019',true,70),
 ('EX015','OC020',false,80),
 ('EX015','OC005',true,90),
 ('EX015','OC006',true,100),

 -- DEVELOPMENT
 ('EX016','OC009',false,10),
 ('EX016','OC126',false,20),
 ('EX016','OC127',false,30),
 ('EX016','OC153',false,40),
 ('EX016','OC154',false,50),

 -- GERIATRIC
 ('EX017','OC001',true,10),
 ('EX017','OC002',true,20),
 ('EX017','OC019',true,30),
 ('EX017','OC021',false,40),
 ('EX017','OC154',true,50),
 ('EX017','OC180',true,60),
 ('EX017','OC181',true,70),
 ('EX017','OC182',true,80),
 ('EX017','OC183',true,90),
 ('EX017','OC185',false,100),
 ('EX017','OC186',false,110),

 -- PERIPHERAL VASCULAR
 ('EX018','OC064',true,10),
 ('EX018','OC066',true,20),
 ('EX018','OC067',false,30),
 ('EX018','OC068',true,40),
 ('EX018','OC069',true,50),
 ('EX018','OC084',false,60),
 ('EX018','OC085',true,70),
 ('EX018','OC086',true,80),

 -- SPINE
 ('EX020','OC161',true,10),
 ('EX020','OC162',false,20),
 ('EX020','OC163',false,30)

) AS v(exam_code,obs_code,mandatory,sort_order)
JOIN knowledge.examination_concept ec
  ON ec.code = v.exam_code
JOIN knowledge.observation_concept oc
  ON oc.code = v.obs_code
ON CONFLICT (examination_concept_code,observation_concept_code)
DO UPDATE SET
 is_mandatory = EXCLUDED.is_mandatory,
 sort_order = EXCLUDED.sort_order,
 updated_at = now();


-- =============================================================================
-- 10. CONTEXT COUPLING
-- =============================================================================

UPDATE knowledge.examination_concept
SET applies_to_context_codes =
CASE code

WHEN 'EX015'
THEN ARRAY['NEONATE','INFANT','CHILD','ADOLESCENT']

WHEN 'EX016'
THEN ARRAY['NEONATE','INFANT','CHILD','ADOLESCENT']

WHEN 'EX017'
THEN ARRAY['OLDER_ADULT']

WHEN 'EX012'
THEN ARRAY['PREGNANT','LABOUR','POSTPARTUM']

WHEN 'EX010'
THEN ARRAY['ADULT','ADOLESCENT','PREGNANT','POSTPARTUM']

ELSE ARRAY[]::text[]

END,
updated_at = now();


-- =============================================================================
-- 11. VITAL-SIGN REFERENCE STANDARDS
-- =============================================================================

INSERT INTO knowledge.reference_standard
(
 code,
 observation_concept_code,
 applies_to_context_codes,
 range_low,
 range_high,
 range_unit,
 interpretation,
 source
)
SELECT
 x.code,
 x.obs_code,
 x.context_codes,
 x.low_value,
 x.high_value,
 x.unit,
 x.interpretation,
 x.source
FROM
(
 VALUES

 -- ADULT GENERAL RESTING
 ('RS001','OC012',ARRAY['ADULT'],60,100,'bpm','NORMAL',
  'General adult resting reference'),

 ('RS002','OC013',ARRAY['ADULT'],12,20,'breaths/min','NORMAL',
  'General adult resting reference'),

 ('RS003','OC011',ARRAY['ADULT'],36.0,37.5,'°C','NORMAL',
  'General adult reference'),

 ('RS004','OC016',ARRAY['ADULT'],95,100,'%','NORMAL',
  'General adult reference'),

 -- NEONATE
 ('RS010','OC012',ARRAY['NEONATE'],100,180,'bpm','NORMAL',
  'Neonatal reference'),

 ('RS011','OC013',ARRAY['NEONATE'],30,60,'breaths/min','NORMAL',
  'Neonatal reference'),

 ('RS012','OC011',ARRAY['NEONATE'],36.5,37.5,'°C','NORMAL',
  'Neonatal reference'),

 -- INFANT
 ('RS020','OC012',ARRAY['INFANT'],100,160,'bpm','NORMAL',
  'Infant reference'),

 ('RS021','OC013',ARRAY['INFANT'],30,50,'breaths/min','NORMAL',
  'Infant reference'),

 -- CHILD
 ('RS030','OC012',ARRAY['CHILD'],80,130,'bpm','NORMAL',
  'Child reference'),

 ('RS031','OC013',ARRAY['CHILD'],20,40,'breaths/min','NORMAL',
  'Child reference'),

 -- OLDER ADULT
 ('RS040','OC012',ARRAY['OLDER_ADULT'],60,100,'bpm','NORMAL',
  'Older adult resting reference'),

 ('RS041','OC013',ARRAY['OLDER_ADULT'],12,22,'breaths/min','NORMAL',
  'Older adult resting reference')

) AS x(code,obs_code,context_codes,low_value,high_value,unit,interpretation,source)
JOIN knowledge.observation_concept oc
 ON oc.code = x.obs_code
ON CONFLICT (code)
DO UPDATE SET
 observation_concept_code = EXCLUDED.observation_concept_code,
 applies_to_context_codes = EXCLUDED.applies_to_context_codes,
 range_low = EXCLUDED.range_low,
 range_high = EXCLUDED.range_high,
 range_unit = EXCLUDED.range_unit,
 interpretation = EXCLUDED.interpretation,
 source = EXCLUDED.source,
 updated_at = now();


-- =============================================================================
-- 12. EXAMINATION RULES
-- =============================================================================

INSERT INTO knowledge.examination_rule
(
 rule_code,
 trigger_type,
 trigger_code,
 target_type,
 target_code,
 modification,
 priority_delta,
 rationale
)
VALUES

-- ALWAYS
('ER001','ALWAYS',NULL,'examination_concept','EX001',
 'MANDATORY',1000,
 'Every complete clinical encounter requires an initial general clinical assessment.'),

('ER002','ALWAYS',NULL,'examination_concept','EX002',
 'MANDATORY',1000,
 'Core physiological observations are foundational to clinical assessment.'),

-- RESPIRATORY SYMPTOMS
('ER010','SYMPTOM_SIGN','DYSPNOEA','examination_concept','EX006',
 'ACTIVATE',500,
 'Respiratory symptoms increase priority of respiratory examination.'),

('ER011','SYMPTOM_SIGN','COUGH','examination_concept','EX006',
 'ACTIVATE',400,
 'Cough activates focused respiratory examination.'),

('ER012','SYMPTOM_SIGN','CHEST_PAIN','examination_concept','EX006',
 'ACTIVATE',400,
 'Chest pain may require respiratory examination.'),

-- CARDIAC
('ER020','SYMPTOM_SIGN','CHEST_PAIN','examination_concept','EX005',
 'ACTIVATE',700,
 'Chest pain requires cardiovascular assessment.'),

('ER021','SYMPTOM_SIGN','PALPITATIONS','examination_concept','EX005',
 'ACTIVATE',500,
 'Palpitations activate cardiovascular examination.'),

('ER022','SYMPTOM_SIGN','SYNCOPE','examination_concept','EX005',
 'ACTIVATE',600,
 'Syncope requires cardiovascular assessment among other examinations.'),

-- ABDOMINAL
('ER030','SYMPTOM_SIGN','ABDOMINAL_PAIN','examination_concept','EX007',
 'ACTIVATE',600,
 'Abdominal pain activates abdominal examination.'),

('ER031','SYMPTOM_SIGN','VOMITING','examination_concept','EX007',
 'ACTIVATE',300,
 'Vomiting may require abdominal examination.'),

('ER032','SYMPTOM_SIGN','DIARRHOEA','examination_concept','EX007',
 'ACTIVATE',300,
 'Diarrhoea may require abdominal and hydration assessment.'),

-- NEUROLOGY
('ER040','SYMPTOM_SIGN','HEADACHE','examination_concept','EX008',
 'ACTIVATE',400,
 'Headache activates neurological examination.'),

('ER041','SYMPTOM_SIGN','WEAKNESS','examination_concept','EX008',
 'ACTIVATE',600,
 'Weakness requires neurological assessment.'),

('ER042','SYMPTOM_SIGN','SEIZURE','examination_concept','EX008',
 'ACTIVATE',800,
 'Seizure requires neurological examination.'),

('ER043','SYMPTOM_SIGN','ALTERED_MENTAL_STATUS','examination_concept','EX008',
 'ACTIVATE',900,
 'Altered mental status requires urgent neurological examination.'),

-- PAEDIATRICS
('ER050','CONTEXT','NEONATE','examination_concept','EX015',
 'ACTIVATE',700,
 'Neonates require age-specific examination.'),

('ER051','CONTEXT','INFANT','examination_concept','EX015',
 'ACTIVATE',600,
 'Infants require age-specific examination.'),

('ER052','CONTEXT','CHILD','examination_concept','EX015',
 'ACTIVATE',600,
 'Children require age-specific examination.'),

-- PREGNANCY
('ER060','CONTEXT','PREGNANT','examination_concept','EX012',
 'ACTIVATE',600,
 'Pregnancy activates obstetric examination when clinically appropriate.'),

('ER061','CONTEXT','LABOUR','examination_concept','EX012',
 'ACTIVATE',900,
 'Labour requires obstetric assessment.'),

-- OLDER ADULT
('ER070','CONTEXT','OLDER_ADULT','examination_concept','EX017',
 'ACTIVATE',400,
 'Older adults require additional multidomain functional assessment.')

ON CONFLICT
(
 target_type,
 target_code,
 trigger_type,
 trigger_code,
 modification
)
DO UPDATE SET
 priority_delta = EXCLUDED.priority_delta,
 rationale = EXCLUDED.rationale,
 updated_at = now();


-- =============================================================================
-- 13. TELEMEDICINE / ENCOUNTER-MODE EXAMINATION RULES
-- =============================================================================

INSERT INTO knowledge.examination_rule
(
 rule_code,
 trigger_type,
 trigger_code,
 target_type,
 target_code,
 modification,
 priority_delta,
 rationale
)
VALUES

('ER100','CONTEXT','REMOTE_ENCOUNTER',
 'examination_concept','EX005',
 'UNAVAILABLE',0,
 'Direct cardiac auscultation is unavailable when no physical examination capability exists.'),

('ER101','CONTEXT','REMOTE_ENCOUNTER',
 'examination_concept','EX006',
 'UNAVAILABLE',0,
 'Direct chest auscultation and percussion may be unavailable in remote encounters.'),

('ER102','CONTEXT','REMOTE_ENCOUNTER',
 'examination_concept','EX007',
 'UNAVAILABLE',0,
 'Direct abdominal palpation/percussion is unavailable in standard remote encounters.'),

('ER103','CONTEXT','REMOTE_ENCOUNTER',
 'examination_concept','EX008',
 'ACTIVATE',100,
 'Remote neurological assessment can still use observation, speech, cognition and selected functional manoeuvres.'),

('ER104','CONTEXT','REMOTE_ENCOUNTER',
 'examination_concept','EX014',
 'ACTIVATE',150,
 'Functional examination is particularly useful in remote assessment.')

ON CONFLICT
(
 target_type,
 target_code,
 trigger_type,
 trigger_code,
 modification
)
DO UPDATE SET
 priority_delta = EXCLUDED.priority_delta,
 rationale = EXCLUDED.rationale,
 updated_at = now();


-- =============================================================================
-- 14. PAEDIATRIC CONTEXT RULES
-- =============================================================================

INSERT INTO knowledge.examination_rule
(
 rule_code,
 trigger_type,
 trigger_code,
 target_type,
 target_code,
 modification,
 priority_delta,
 rationale
)
VALUES

('ER120','CONTEXT','NEONATE',
 'examination_concept','EX016',
 'ACTIVATE',300,
 'Developmental/neurological assessment is age dependent in neonates.'),

('ER121','CONTEXT','INFANT',
 'examination_concept','EX016',
 'ACTIVATE',300,
 'Developmental assessment is essential in infancy.'),

('ER122','CONTEXT','CHILD',
 'examination_concept','EX016',
 'ACTIVATE',300,
 'Developmental assessment is relevant throughout childhood.'),

('ER123','CONTEXT','ADOLESCENT',
 'examination_concept','EX016',
 'ACTIVATE',200,
 'Developmental and functional assessment remains relevant during adolescence.')

ON CONFLICT
(
 target_type,
 target_code,
 trigger_type,
 trigger_code,
 modification
)
DO UPDATE SET
 priority_delta = EXCLUDED.priority_delta,
 rationale = EXCLUDED.rationale,
 updated_at = now();


-- =============================================================================
-- 15. H6 OBSERVATION PHENOTYPE LINKS
-- =============================================================================

INSERT INTO knowledge.finding_phenotype_link
(
 observation_concept_code,
 finding_value,
 associated_concept_code,
 strength,
 description
)
VALUES

('OC096','WHEEZE','WHEEZE','strong',
 'Wheeze is a canonical respiratory examination finding.'),

('OC097','CRACKLES','CRACKLES','strong',
 'Crackles are a canonical respiratory examination finding.'),

('OC098','RHONCHI','RHONCHI','moderate',
 'Rhonchi are a canonical respiratory examination finding.'),

('OC099','STRIDOR','STRIDOR','strong',
 'Stridor indicates an upper-airway respiratory sign.'),

('OC100','PRESENT','PLEURAL_RUB','strong',
 'Pleural rub is a respiratory examination sign.'),

('OC078','MURMUR','CARDIAC_MURMUR','strong',
 'Cardiac murmur is a cardiovascular examination finding.'),

('OC083','PRESENT','PERICARDIAL_RUB','strong',
 'Pericardial rub is a cardiovascular examination finding.'),

('OC029','PRESENT','CYANOSIS','strong',
 'Cyanosis is a clinical examination finding.'),

('OC030','PRESENT','PALLOR','strong',
 'Pallor is a clinical examination finding.'),

('OC031','PRESENT','JAUNDICE','strong',
 'Jaundice is a clinical examination finding.'),

('OC032','PRESENT','CLUBBING','strong',
 'Digital clubbing is a clinical examination finding.'),

('OC084','PRESENT','OEDEMA','strong',
 'Peripheral oedema is a clinical examination finding.'),

('OC117','PRESENT','ASCITES','strong',
 'Ascites is a physical examination finding.'),

('OC112','ENLARGED','HEPATOMEGALY','strong',
 'Enlarged liver is hepatomegaly.'),

('OC115','ENLARGED','SPLENOMEGALY','strong',
 'Enlarged spleen is splenomegaly.'),

('OC052','ENLARGED','LYMPHADENOPATHY','strong',
 'Abnormal cervical lymph-node enlargement is lymphadenopathy.'),

('OC053','ENLARGED','LYMPHADENOPATHY','strong',
 'Abnormal supraclavicular lymph-node enlargement is lymphadenopathy.'),

('OC054','ENLARGED','LYMPHADENOPATHY','strong',
 'Abnormal axillary lymph-node enlargement is lymphadenopathy.'),

('OC055','ENLARGED','LYMPHADENOPATHY','strong',
 'Abnormal inguinal lymph-node enlargement is lymphadenopathy.')

ON CONFLICT
(
 observation_concept_code,
 finding_value,
 associated_concept_code
)
DO UPDATE SET
 strength = EXCLUDED.strength,
 description = EXCLUDED.description,
 updated_at = now();


-- =============================================================================
-- 16. EXAMINATION DOMAIN ORDER
-- =============================================================================

UPDATE knowledge.examination_domain
SET sort_order =
CASE code
 WHEN 'GENERAL' THEN 10
 WHEN 'VITAL_SIGNS' THEN 20
 WHEN 'SKIN' THEN 30
 WHEN 'HEAD_NECK' THEN 40
 WHEN 'CARDIOVASCULAR' THEN 50
 WHEN 'RESPIRATORY' THEN 60
 WHEN 'ABDOMINAL' THEN 70
 WHEN 'NEUROLOGICAL' THEN 80
 WHEN 'MUSCULOSKELETAL' THEN 90
 WHEN 'BREAST' THEN 100
 WHEN 'GENITOURINARY' THEN 110
 WHEN 'OBSTETRIC' THEN 120
 WHEN 'PAEDIATRIC' THEN 130
 WHEN 'DEVELOPMENTAL' THEN 140
 WHEN 'MENTAL_STATE' THEN 150
 WHEN 'FUNCTIONAL' THEN 160
 WHEN 'GERIATRIC' THEN 170
 WHEN 'PERIPHERAL_VASCULAR' THEN 180
 WHEN 'LYMPHATIC' THEN 190
 WHEN 'SPINE' THEN 200
 ELSE sort_order
END,
updated_at = now();


-- =============================================================================
-- 17. EXAMINATION EXECUTION SUPPORT
-- =============================================================================

-- [RECONCILED] runtime tables ALTERed/indexed by this migration but never created:
-- knowledge.observation and knowledge.examination_plan_item. Define minimal shapes
-- here so the execution-support statements below apply cleanly.
CREATE TABLE IF NOT EXISTS knowledge.observation (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    observation_concept_code    text REFERENCES knowledge.observation_concept(code),
    value_numeric               numeric,
    value_text                  text,
    value_boolean               boolean,
    value_ordinal               integer,
    capture_method_code         text,
    site_code                   text,
    technique_code              text,
    position_code               text,
    source_historian_type_code  text,
    source_reliability_code     text,
    recorded_at                 timestamptz NOT NULL DEFAULT now(),
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS knowledge.examination_plan_item (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id           uuid,
    observation_concept_code text REFERENCES knowledge.observation_concept(code),
    priority_score    numeric NOT NULL DEFAULT 0,
    status            text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','active','completed','skipped','cancelled')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS value_ordinal integer;

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS capture_method_code text
REFERENCES knowledge.fact_capture_method(method_code);

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS site_code text
REFERENCES knowledge.examination_site(code);

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS technique_code text
REFERENCES knowledge.examination_technique(code);

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS position_code text
REFERENCES knowledge.examination_position(position_code);

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS source_historian_type_code text
REFERENCES knowledge.historian_type(type_code);

ALTER TABLE knowledge.observation
ADD COLUMN IF NOT EXISTS source_reliability_code text
REFERENCES knowledge.historian_reliability(reliability_code);

CREATE INDEX IF NOT EXISTS idx_observation_fact_provenance
ON knowledge.observation
(
 capture_method_code,
 source_historian_type_code,
 source_reliability_code
);


-- =============================================================================
-- 18. OBSERVATION INTEGRITY
-- =============================================================================

ALTER TABLE knowledge.observation
DROP CONSTRAINT IF EXISTS observation_single_value_chk;

ALTER TABLE knowledge.observation
ADD CONSTRAINT observation_single_value_chk
CHECK
(
 (
   (CASE WHEN value_numeric IS NOT NULL THEN 1 ELSE 0 END) +
   (CASE WHEN value_text IS NOT NULL THEN 1 ELSE 0 END) +
   (CASE WHEN value_boolean IS NOT NULL THEN 1 ELSE 0 END) +
   (CASE WHEN value_ordinal IS NOT NULL THEN 1 ELSE 0 END)
 ) <= 1
);


-- =============================================================================
-- 19. EXAMINATION PLAN INTEGRITY
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_exam_plan_item_priority
ON knowledge.examination_plan_item
(
 plan_id,
 priority_score DESC
);

CREATE INDEX IF NOT EXISTS idx_exam_plan_item_status
ON knowledge.examination_plan_item
(
 plan_id,
 status
);


-- =============================================================================
-- 20. H6 RUNTIME HELPER VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_h6_examination_catalogue AS
SELECT
    ec.code                         AS examination_code,
    ec.name                         AS examination_name,
    ed.code                         AS domain_code,
    ed.label                        AS domain_label,
    ec.base_priority,
    ec.is_mandatory,
    oc.code                         AS observation_code,
    oc.fact_definition_code,
    oc.name                         AS observation_name,
    oc.value_type,
    oc.unit,
    comp.is_mandatory               AS component_mandatory,
    comp.sort_order,
    oc.interpretation_default
FROM knowledge.examination_concept ec
JOIN knowledge.examination_domain ed
  ON ed.domain_code = ec.domain_code
JOIN knowledge.examination_component comp
  ON comp.examination_concept_code = ec.code
JOIN knowledge.observation_concept oc
  ON oc.code = comp.observation_concept_code
WHERE ec.status = 'active'
  AND oc.status = 'active'
  AND comp.status = 'active';


-- =============================================================================
-- 21. H6 PRIORITY VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_h6_examination_priority AS
SELECT
    ec.code AS examination_code,
    ec.name,
    ec.base_priority,
    COALESCE(
        SUM(
            CASE
                WHEN er.modification IN ('ACTIVATE','MANDATORY','SAFETY','PRIORITY')
                THEN er.priority_delta
                ELSE 0
            END
        ),
        0
    ) AS rule_priority_delta,
    ec.base_priority +
    COALESCE(
        SUM(
            CASE
                WHEN er.modification IN ('ACTIVATE','MANDATORY','SAFETY','PRIORITY')
                THEN er.priority_delta
                ELSE 0
            END
        ),
        0
    ) AS effective_priority
FROM knowledge.examination_concept ec
LEFT JOIN knowledge.examination_rule er
  ON er.target_type = 'examination_concept'
 AND er.target_code = ec.code
 AND er.is_active = true
 AND er.status = 'active'
GROUP BY
    ec.code,
    ec.name,
    ec.base_priority;


-- =============================================================================
-- 22. H6 UNIVERSAL EXAMINATION SEQUENCE
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_h6_universal_exam_sequence AS
SELECT
    ed.sort_order AS domain_order,
    ed.code AS domain_code,
    ed.label AS domain,
    ec.base_priority,
    ec.code AS examination_code,
    ec.name AS examination,
    comp.sort_order AS finding_order,
    oc.code AS observation_code,
    oc.fact_definition_code,
    oc.name AS finding,
    oc.value_type,
    oc.unit,
    comp.is_mandatory
FROM knowledge.examination_domain ed
JOIN knowledge.examination_concept ec
  ON ec.domain_code = ed.domain_code
JOIN knowledge.examination_component comp
  ON comp.examination_concept_code = ec.code
JOIN knowledge.observation_concept oc
  ON oc.code = comp.observation_concept_code
WHERE ed.status = 'active'
  AND ec.status = 'active'
  AND comp.status = 'active'
  AND oc.status = 'active'
ORDER BY
    ed.sort_order,
    ec.base_priority DESC,
    comp.sort_order;


-- =============================================================================
-- 23. H6 CLINICAL INTELLIGENCE VIEW
-- =============================================================================
-- This is intentionally an interpretation bridge.
-- It DOES NOT diagnose.
-- It exposes canonical examination findings to downstream H4/H5 reasoning.

CREATE OR REPLACE VIEW knowledge.v_h6_finding_intelligence AS
SELECT
    oc.code AS observation_code,
    oc.fact_definition_code,
    oc.name AS observation,
    fi.code AS interpretation_code,
    fi.canonical_name AS interpretation,
    fi.is_abnormal,
    fi.is_critical,
    fpl.associated_concept_code,
    fpl.strength AS phenotype_link_strength
FROM knowledge.observation_concept oc
LEFT JOIN knowledge.finding_interpretation fi
  ON fi.code = oc.interpretation_default
LEFT JOIN knowledge.finding_phenotype_link fpl
  ON fpl.observation_concept_code = oc.code
WHERE oc.status = 'active';


-- =============================================================================
-- 24. H6 EXAMINATION SAFETY RULES
-- =============================================================================

INSERT INTO knowledge.examination_rule
(
 rule_code,
 trigger_type,
 trigger_code,
 target_type,
 target_code,
 modification,
 priority_delta,
 rationale
)
VALUES

('ER200','ALWAYS',NULL,
 'examination_concept','EX002',
 'SAFETY',1000,
 'Vital signs identify immediate physiological instability.'),

('ER201','SYMPTOM_SIGN','SYNCOPE',
 'examination_concept','EX002',
 'SAFETY',1000,
 'Syncope requires immediate physiological assessment.'),

('ER202','SYMPTOM_SIGN','DYSPNOEA',
 'examination_concept','EX002',
 'SAFETY',1000,
 'Dyspnoea requires immediate respiratory and physiological assessment.'),

('ER203','SYMPTOM_SIGN','CHEST_PAIN',
 'examination_concept','EX002',
 'SAFETY',1000,
 'Chest pain requires immediate physiological assessment.'),

('ER204','SYMPTOM_SIGN','ALTERED_MENTAL_STATUS',
 'examination_concept','EX002',
 'SAFETY',1000,
 'Altered mental status requires immediate physiological assessment.'),

('ER205','SYMPTOM_SIGN','SEIZURE',
 'examination_concept','EX002',
 'SAFETY',1000,
 'Seizure requires immediate physiological assessment.')

ON CONFLICT
(
 target_type,
 target_code,
 trigger_type,
 trigger_code,
 modification
)
DO UPDATE SET
 priority_delta = EXCLUDED.priority_delta,
 rationale = EXCLUDED.rationale,
 updated_at = now();


-- =============================================================================
-- 25. CONTEXT-SPECIFIC EXAMINATION GATES
-- =============================================================================

INSERT INTO knowledge.examination_rule
(
 rule_code,
 trigger_type,
 trigger_code,
 target_type,
 target_code,
 modification,
 priority_delta,
 rationale
)
VALUES

('ER220','CONTEXT','UNCONSCIOUS',
 'examination_concept','EX013',
 'ACTIVATE',700,
 'Altered consciousness requires focused neurological and mental-state assessment to the extent possible.'),

('ER221','CONTEXT','UNCONSCIOUS',
 'examination_concept','EX008',
 'ACTIVATE',900,
 'Unconsciousness requires urgent neurological examination.'),

('ER222','CONTEXT','PREGNANT',
 'examination_concept','EX005',
 'ACTIVATE',100,
 'Cardiovascular assessment remains part of pregnancy assessment.'),

('ER223','CONTEXT','PREGNANT',
 'examination_concept','EX002',
 'ACTIVATE',300,
 'Vital signs are particularly important during pregnancy.'),

('ER224','CONTEXT','PREGNANT',
 'examination_concept','EX003',
 'ACTIVATE',100,
 'Skin and peripheral findings may be clinically relevant during pregnancy.'),

('ER225','CONTEXT','OLDER_ADULT',
 'examination_concept','EX014',
 'ACTIVATE',400,
 'Functional status is central to older-adult assessment.'),

('ER226','CONTEXT','OLDER_ADULT',
 'examination_concept','EX017',
 'MANDATORY',500,
 'Geriatric multidomain assessment should be considered in older-adult encounters.')

ON CONFLICT
(
 target_type,
 target_code,
 trigger_type,
 trigger_code,
 modification
)
DO UPDATE SET
 priority_delta = EXCLUDED.priority_delta,
 rationale = EXCLUDED.rationale,
 updated_at = now();


-- =============================================================================
-- 26. UPDATE TIMESTAMPS
-- =============================================================================

UPDATE knowledge.examination_domain
SET updated_at = now();

UPDATE knowledge.examination_concept
SET updated_at = now();

UPDATE knowledge.observation_concept
SET updated_at = now();

UPDATE knowledge.examination_component
SET updated_at = now();

UPDATE knowledge.examination_site
SET updated_at = now();

UPDATE knowledge.examination_position
SET updated_at = now();

UPDATE knowledge.examination_technique
SET updated_at = now();

UPDATE knowledge.finding_interpretation
SET updated_at = now();


-- =============================================================================
-- 27. PROVENANCE
-- =============================================================================

COMMENT ON TABLE knowledge.examination_domain
IS
'H6 examination domain vocabulary derived from structured clinical examination
knowledge. Domains organize examination concepts without creating alternative
clinical fact identities.';

COMMENT ON TABLE knowledge.examination_concept
IS
'H6 universal examination concepts. Examination concepts are executable
knowledge bundles and do not constitute independent clinical facts.';

COMMENT ON TABLE knowledge.observation_concept
IS
'H6 observation vocabulary. Every observation concept MUST resolve to one
canonical clinical.fact_definition.';

COMMENT ON TABLE knowledge.examination_component
IS
'H6 mapping from examination concepts to canonical observations.';

COMMENT ON TABLE knowledge.finding_interpretation
IS
'H6 controlled interpretation vocabulary for physical findings.';

COMMENT ON TABLE knowledge.finding_phenotype_link
IS
'H6-to-H4/H5 intelligence bridge. Physical findings may activate downstream
phenotype/concept reasoning without replacing the canonical fact vocabulary.';


-- =============================================================================
-- 28. FINAL VALIDATION QUERIES
-- =============================================================================

DO $$
DECLARE
    missing_fact_count integer;
    orphan_component_count integer;
    orphan_domain_count integer;
BEGIN

    SELECT COUNT(*)
    INTO missing_fact_count
    FROM knowledge.observation_concept oc
    LEFT JOIN clinical.fact_definition fd
      ON fd.code = oc.fact_definition_code
    WHERE fd.code IS NULL;

    IF missing_fact_count > 0 THEN
        RAISE EXCEPTION
        'H6 validation failed: % observation concepts have missing canonical fact definitions',
        missing_fact_count;
    END IF;


    SELECT COUNT(*)
    INTO orphan_component_count
    FROM knowledge.examination_component c
    LEFT JOIN knowledge.examination_concept ec
      ON ec.code = c.examination_concept_code
    LEFT JOIN knowledge.observation_concept oc
      ON oc.code = c.observation_concept_code
    WHERE ec.code IS NULL
       OR oc.code IS NULL;

    IF orphan_component_count > 0 THEN
        RAISE EXCEPTION
        'H6 validation failed: % orphan examination components',
        orphan_component_count;
    END IF;


    SELECT COUNT(*)
    INTO orphan_domain_count
    FROM knowledge.examination_concept ec
    LEFT JOIN knowledge.examination_domain ed
      ON ed.domain_code = ec.domain_code
    WHERE ed.domain_code IS NULL;

    IF orphan_domain_count > 0 THEN
        RAISE EXCEPTION
        'H6 validation failed: % examination concepts have invalid domains',
        orphan_domain_count;
    END IF;

END $$;


COMMIT;


-- =============================================================================
-- 29. POST-MIGRATION INTELLIGENCE CHECKS
-- =============================================================================

SELECT
    'EXAMINATION_DOMAINS' AS object,
    COUNT(*) AS count
FROM knowledge.examination_domain

UNION ALL

SELECT
    'EXAMINATION_CONCEPTS',
    COUNT(*)
FROM knowledge.examination_concept

UNION ALL

SELECT
    'OBSERVATION_CONCEPTS',
    COUNT(*)
FROM knowledge.observation_concept

UNION ALL

SELECT
    'EXAMINATION_COMPONENTS',
    COUNT(*)
FROM knowledge.examination_component

UNION ALL

SELECT
    'EXAMINATION_TECHNIQUES',
    COUNT(*)
FROM knowledge.examination_technique

UNION ALL

SELECT
    'EXAMINATION_SITES',
    COUNT(*)
FROM knowledge.examination_site

UNION ALL

SELECT
    'EXAMINATION_POSITIONS',
    COUNT(*)
FROM knowledge.examination_position

UNION ALL

SELECT
    'EXAMINATION_RULES',
    COUNT(*)
FROM knowledge.examination_rule

UNION ALL

SELECT
    'REFERENCE_STANDARDS',
    COUNT(*)
FROM knowledge.reference_standard

UNION ALL

SELECT
    'FINDING_INTERPRETATIONS',
    COUNT(*)
FROM knowledge.finding_interpretation

UNION ALL

SELECT
    'PHENOTYPE_LINKS',
    COUNT(*)
FROM knowledge.finding_phenotype_link;


-- =============================================================================
-- 30. COMPLETE H6 CATALOGUE
-- =============================================================================

SELECT *
FROM knowledge.v_h6_universal_exam_sequence
ORDER BY
    domain_order,
    base_priority DESC,
    finding_order;


-- =============================================================================
-- 31. H6 INTELLIGENCE CATALOGUE
-- =============================================================================

SELECT *
FROM knowledge.v_h6_finding_intelligence
ORDER BY
    is_critical DESC,
    is_abnormal DESC,
    observation_code;


-- =============================================================================
-- 32. H6 PRIORITY CATALOGUE
-- =============================================================================

SELECT *
FROM knowledge.v_h6_examination_priority
ORDER BY effective_priority DESC;


-- =============================================================================
-- END H6 MIGRATION 030
-- =============================================================================