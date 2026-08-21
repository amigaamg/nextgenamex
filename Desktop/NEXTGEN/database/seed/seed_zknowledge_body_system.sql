-- =============================================================================
-- AMEXAN Phase 2 — Seed Z2
-- CLINICAL CONTEXT ONTOLOGY + BODY SYSTEM INTELLIGENCE
-- =============================================================================
--
-- PURPOSE
-- -------
-- This seed establishes the contextual vocabulary used by AMEXAN clinical
-- intelligence to understand WHO the patient is, WHERE care occurs, HOW sick
-- the patient is, and WHICH physiological/clinical domain is involved.
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. Context is orthogonal to disease.
-- 2. Disease logic must never be hard-coded into an age/sex label.
-- 3. Multiple contexts may coexist:
--
--      ADULT + FEMALE + PREGNANT + EMERGENCY
--      CHILD + MALE + IMMUNOCOMPROMISED + INPATIENT
--      OLDER_ADULT + FEMALE + OUTPATIENT
--
-- 4. Context modifies clinical intelligence rather than replacing it.
-- 5. Context values are stable machine-readable identifiers.
-- 6. Clinical reasoning must operate longitudinally over the patient's
--    history rather than treating every encounter as an isolated event.
-- 7. This seed contains reference ontology only.
--    It does NOT itself diagnose or prescribe.
--
-- COMPATIBILITY
-- -------------
-- Uses only:
--   knowledge.context_type
--   knowledge.context_value
--   knowledge.context_relationship
--   knowledge.body_system
--
-- It is intended to run after the base knowledge/reference schema exists.
-- Idempotent.
-- =============================================================================


-- =============================================================================
-- 1. CONTEXT TYPES
-- =============================================================================

INSERT INTO knowledge.context_type
(code, label, description)
VALUES

-- ---------------------------------------------------------------------------
-- Demographic / life-stage context
-- ---------------------------------------------------------------------------

(
    'AGE',
    'Age / Life Stage',
    'Patient developmental and life-stage context used to adapt clinical
     history, examination, reference ranges, differential diagnosis,
     investigation thresholds, treatment considerations and documentation.'
),

(
    'SEX',
    'Biological Sex',
    'Biological sex context relevant to anatomy, physiology, epidemiology,
     reference ranges, disease probability and sex-specific clinical pathways.'
),

-- ---------------------------------------------------------------------------
-- Reproductive context
-- ---------------------------------------------------------------------------

(
    'PREGNANCY',
    'Pregnancy Status',
    'Pregnancy state affecting differential diagnosis, investigation safety,
     medication considerations, physiology and obstetric clinical pathways.'
),

-- ---------------------------------------------------------------------------
-- Immune / physiological reserve
-- ---------------------------------------------------------------------------

(
    'IMMUNOCOMPROMISED_STATUS',
    'Immune Status',
    'Immune competence context affecting infection risk, atypical presentation,
     differential diagnosis, investigation strategy and treatment considerations.'
),

-- ---------------------------------------------------------------------------
-- Care environment
-- ---------------------------------------------------------------------------

(
    'CARE_SETTING',
    'Care Setting',
    'Clinical environment in which assessment and management occur.'
),

(
    'ACUITY',
    'Clinical Acuity',
    'Urgency and physiological severity context used to prioritize assessment,
     escalation, monitoring and immediate clinical actions.'
),

-- ---------------------------------------------------------------------------
-- Epidemiological context
-- ---------------------------------------------------------------------------

(
    'SEASON',
    'Seasonal Context',
    'Temporal epidemiological context relevant to diseases and presentations
     whose prevalence varies with season or environmental conditions.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. AGE / LIFE-STAGE VOCABULARY
-- =============================================================================
--
-- AMEXAN must distinguish chronological age from developmental context.
-- The values below are intentionally compatible with the broader AMEXAN
-- vocabulary used by context adaptation rules.
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES

-- ---------------------------------------------------------------------------
-- Neonatal
-- ---------------------------------------------------------------------------

(
    'AGE',
    'NEONATE',
    'Neonate (birth–28 days)',
    10
),

-- ---------------------------------------------------------------------------
-- Infancy
-- ---------------------------------------------------------------------------

(
    'AGE',
    'INFANT',
    'Infant (29 days–<1 year)',
    20
),

-- ---------------------------------------------------------------------------
-- Early childhood
-- ---------------------------------------------------------------------------

(
    'AGE',
    'PRESCHOOL',
    'Preschool child (1–4 years)',
    30
),

-- ---------------------------------------------------------------------------
-- School age
-- ---------------------------------------------------------------------------

(
    'AGE',
    'SCHOOL_AGE',
    'School-age child (5–11 years)',
    40
),

-- ---------------------------------------------------------------------------
-- Adolescence
-- ---------------------------------------------------------------------------

(
    'AGE',
    'ADOLESCENT',
    'Adolescent (12–17 years)',
    50
),

-- ---------------------------------------------------------------------------
-- Adult
-- ---------------------------------------------------------------------------

(
    'AGE',
    'ADULT',
    'Adult (18–64 years)',
    60
),

-- ---------------------------------------------------------------------------
-- Older adult
-- ---------------------------------------------------------------------------

(
    'AGE',
    'OLDER_ADULT',
    'Older adult (65 years and above)',
    70
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. SEX VOCABULARY
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES
(
    'SEX',
    'male',
    'Male',
    10
),
(
    'SEX',
    'female',
    'Female',
    20
),
(
    'SEX',
    'intersex',
    'Intersex',
    30
),
(
    'SEX',
    'unknown',
    'Unknown / not recorded',
    40
),
(
    'SEX',
    'not_stated',
    'Not stated',
    50
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. PREGNANCY / REPRODUCTIVE CONTEXT
-- =============================================================================
--
-- The table is named PREGNANCY, therefore values describe pregnancy state.
-- Gestational age/trimester should be represented elsewhere when the schema
-- provides a dedicated reproductive/obstetric fact model.
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES
(
    'PREGNANCY',
    'pregnant',
    'Pregnant',
    10
),
(
    'PREGNANCY',
    'not_pregnant',
    'Not pregnant',
    20
),
(
    'PREGNANCY',
    'unknown',
    'Pregnancy status unknown',
    30
),
(
    'PREGNANCY',
    'not_applicable',
    'Not applicable',
    40
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. IMMUNE STATUS
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES
(
    'IMMUNOCOMPROMISED_STATUS',
    'immunocompetent',
    'Immunocompetent',
    10
),
(
    'IMMUNOCOMPROMISED_STATUS',
    'immunocompromised',
    'Immunocompromised',
    20
),
(
    'IMMUNOCOMPROMISED_STATUS',
    'unknown',
    'Immune status unknown',
    30
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. CARE SETTING
-- =============================================================================
--
-- Setting affects workflow, urgency, documentation and available resources.
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES
(
    'CARE_SETTING',
    'outpatient',
    'Outpatient',
    10
),
(
    'CARE_SETTING',
    'inpatient',
    'Inpatient',
    20
),
(
    'CARE_SETTING',
    'emergency',
    'Emergency',
    30
),
(
    'CARE_SETTING',
    'telemedicine',
    'Telemedicine',
    40
),
(
    'CARE_SETTING',
    'home',
    'Home / domiciliary care',
    50
),
(
    'CARE_SETTING',
    'community',
    'Community / outreach',
    60
),
(
    'CARE_SETTING',
    'critical_care',
    'Critical care / intensive care',
    70
),
(
    'CARE_SETTING',
    'operating_theatre',
    'Operating theatre / procedure area',
    80
),
(
    'CARE_SETTING',
    'maternity',
    'Maternity / obstetric care',
    90
),
(
    'CARE_SETTING',
    'neonatal',
    'Neonatal care',
    100
),
(
    'CARE_SETTING',
    'paediatric',
    'Paediatric care',
    110
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. ACUITY
-- =============================================================================
--
-- Acuity is NOT equivalent to diagnosis.
-- It represents the urgency/severity state of the current presentation.
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES
(
    'ACUITY',
    'routine',
    'Routine',
    10
),
(
    'ACUITY',
    'urgent',
    'Urgent',
    20
),
(
    'ACUITY',
    'emergency',
    'Emergency',
    30
),
(
    'ACUITY',
    'critical',
    'Critical / life-threatening',
    40
),
(
    'ACUITY',
    'unknown',
    'Acuity not yet established',
    50
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. SEASONAL CONTEXT
-- =============================================================================

INSERT INTO knowledge.context_value
(context_type_code, value, label, sort_order)
VALUES
(
    'SEASON',
    'rainy',
    'Rainy season',
    10
),
(
    'SEASON',
    'dry',
    'Dry season',
    20
),
(
    'SEASON',
    'transition',
    'Seasonal transition',
    30
),
(
    'SEASON',
    'none',
    'Not seasonally relevant',
    40
),
(
    'SEASON',
    'unknown',
    'Seasonal context unknown',
    50
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. CLINICAL CONTEXT RELATIONSHIPS
-- =============================================================================
--
-- These relationships express ontological implications.
--
-- They are NOT diagnostic rules.
--
-- Example:
--     pregnant -> female
--
-- does not mean:
--     female -> pregnant
--
-- This distinction is critical for safe clinical intelligence.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Pregnancy implies female biological context
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.context_relationship
(
    context_type_code,
    source_value_id,
    target_value_id,
    relationship,
    description
)
SELECT
    'PREGNANCY',
    source.id,
    target.id,
    'implies',
    'A confirmed pregnancy establishes a female reproductive context for
     clinical pathway selection.'
FROM knowledge.context_value source
JOIN knowledge.context_value target
  ON target.context_type_code = 'SEX'
 AND target.value = 'female'
WHERE source.context_type_code = 'PREGNANCY'
  AND source.value = 'pregnant'
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- Neonatal age implies neonatal care context when applicable
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.context_relationship
(
    context_type_code,
    source_value_id,
    target_value_id,
    relationship,
    description
)
SELECT
    'AGE',
    source.id,
    target.id,
    'supports',
    'Neonatal age supports neonatal care pathway selection.'
FROM knowledge.context_value source
JOIN knowledge.context_value target
  ON target.context_type_code = 'CARE_SETTING'
 AND target.value = 'neonatal'
WHERE source.context_type_code = 'AGE'
  AND source.value = 'NEONATE'
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. BODY SYSTEM ONTOLOGY
-- =============================================================================
--
-- The body-system layer allows AMEXAN to organize:
--
--     symptom
--        ↓
--     sign/finding
--        ↓
--     mechanism
--        ↓
--     body system
--        ↓
--     phenotype
--        ↓
--     condition
--
-- It therefore becomes possible for downstream clinical intelligence to reason
-- across organ systems without making the disease itself the starting point.
-- =============================================================================

INSERT INTO knowledge.body_system
(code, label, description)
VALUES

-- ===========================================================================
-- RESPIRATORY
-- ===========================================================================

(
    'RESPIRATORY',
    'Respiratory',
    'Nose, upper airway, pharynx, larynx, trachea, bronchi, bronchioles,
     lungs, alveoli, pleura and respiratory mechanics.'
),

-- ===========================================================================
-- CARDIOVASCULAR
-- ===========================================================================

(
    'CARDIOVASCULAR',
    'Cardiovascular',
    'Heart, myocardium, endocardium, valves, pericardium, arteries, veins,
     microcirculation and systemic cardiovascular physiology.'
),

-- ===========================================================================
-- GASTROINTESTINAL
-- ===========================================================================

(
    'GASTROINTESTINAL',
    'Gastrointestinal',
    'Oral gastrointestinal tract, oesophagus, stomach, small intestine,
     large intestine, rectum and anal canal, with associated digestive
     physiology.'
),

-- ===========================================================================
-- HEPATOBILIARY / PANCREATIC
-- ===========================================================================

(
    'HEPATOBILIARY',
    'Hepatobiliary',
    'Liver, intrahepatic biliary tree, gallbladder and extrahepatic biliary
     system.'
),

(
    'PANCREATIC',
    'Pancreatic',
    'Exocrine and endocrine pancreas and pancreatic physiology.'
),

-- ===========================================================================
-- NEUROLOGICAL
-- ===========================================================================

(
    'NEUROLOGICAL',
    'Neurological',
    'Brain, spinal cord, peripheral nerves, neuromuscular junction and
     neurological function.'
),

-- ===========================================================================
-- MUSCULOSKELETAL
-- ===========================================================================

(
    'MUSCULOSKELETAL',
    'Musculoskeletal',
    'Bones, joints, cartilage, skeletal muscle, tendons, ligaments and
     associated connective tissues.'
),

-- ===========================================================================
-- RENAL / URINARY
-- ===========================================================================

(
    'RENAL_URINARY',
    'Renal & Urinary',
    'Kidneys, glomeruli, renal tubules, ureters, bladder and urethra,
     including fluid, electrolyte and acid-base regulation.'
),

-- ===========================================================================
-- ENDOCRINE
-- ===========================================================================

(
    'ENDOCRINE',
    'Endocrine',
    'Pituitary, thyroid, parathyroid, adrenal glands, pancreatic endocrine
     function and other hormone-regulating systems.'
),

-- ===========================================================================
-- HAEMATOLOGICAL
-- ===========================================================================

(
    'HAEMATOLOGICAL',
    'Haematological',
    'Red cells, white cells, platelets, bone marrow, coagulation and
     haematological physiology.'
),

-- ===========================================================================
-- IMMUNE
-- ===========================================================================

(
    'IMMUNE',
    'Immune',
    'Innate and adaptive immune systems, lymphoid tissues, immune responses
     and immunological disorders.'
),

-- ===========================================================================
-- INTEGUMENTARY
-- ===========================================================================

(
    'INTEGUMENTARY',
    'Integumentary',
    'Skin, epidermis, dermis, subcutaneous tissue, hair, nails and associated
     cutaneous structures.'
),

-- ===========================================================================
-- REPRODUCTIVE
-- ===========================================================================

(
    'REPRODUCTIVE',
    'Reproductive',
    'Male and female reproductive organs, reproductive physiology and
     reproductive health.'
),

-- ===========================================================================
-- OBSTETRIC
-- ===========================================================================

(
    'OBSTETRIC',
    'Obstetric',
    'Pregnancy, placenta, fetal-maternal physiology, labour, delivery,
     puerperium and pregnancy-related disorders.'
),

-- ===========================================================================
-- PSYCHIATRIC
-- ===========================================================================

(
    'PSYCHIATRIC',
    'Psychiatric',
    'Mental health, cognition, mood, thought, perception, behaviour and
     psychiatric syndromes.'
),

-- ===========================================================================
-- CONSTITUTIONAL
-- ===========================================================================

(
    'CONSTITUTIONAL',
    'Constitutional',
    'General systemic manifestations including fever, fatigue, weight change,
     malaise, night sweats and other whole-body symptoms.'
),

-- ===========================================================================
-- HEAD AND NECK
-- ===========================================================================

(
    'HEAD_NECK',
    'Head & Neck',
    'Ear, nose, throat, oral cavity, pharynx, larynx, salivary glands,
     cervical structures and related head-and-neck systems.'
),

-- ===========================================================================
-- OPHTHALMOLOGICAL
-- ===========================================================================

(
    'OPHTHALMOLOGICAL',
    'Ophthalmological',
    'Eyes, orbit, visual pathways and ocular adnexa.'
),

-- ===========================================================================
-- LYMPHATIC
-- ===========================================================================

(
    'LYMPHATIC',
    'Lymphatic',
    'Lymph nodes, lymphatic vessels, spleen and lymphoid structures.'
),

-- ===========================================================================
-- INFECTIOUS DISEASE
-- ===========================================================================

(
    'INFECTIOUS_DISEASE',
    'Infectious Disease',
    'Clinical manifestations and host-pathogen interactions involving
     bacterial, viral, fungal, parasitic and other infectious processes.'
),

-- ===========================================================================
-- REPRODUCTIVE / SEXUAL HEALTH
-- ===========================================================================

(
    'SEXUAL_HEALTH',
    'Sexual Health',
    'Sexual function, sexually transmitted infections, sexual health,
     reproductive counselling and related clinical conditions.'
),

-- ===========================================================================
-- CRITICAL CARE / MULTISYSTEM
-- ===========================================================================

(
    'MULTISYSTEM',
    'Multisystem',
    'Clinical conditions involving multiple organ systems or systemic
     physiological disturbance.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. CLINICAL BODY-SYSTEM HIERARCHY RELATIONSHIPS
-- =============================================================================
--
-- The current schema does not expose a dedicated body_system_parent table.
-- Therefore hierarchy is represented conceptually through descriptions rather
-- than invented relational structures.
--
-- Future AMEXAN releases can introduce:
--
--     knowledge.body_system_relationship
--
-- if formal anatomical hierarchy is required.
-- =============================================================================


-- =============================================================================
-- 12. MEDICAL INTELLIGENCE SEMANTIC GROUPS
-- =============================================================================
--
-- These descriptions establish how AMEXAN should interpret the ontology.
--
-- IMPORTANT:
-- These are reference semantics, not executable diagnostic rules.
-- =============================================================================

COMMENT ON TABLE knowledge.context_type IS
'AMEXAN clinical context ontology. Context describes patient state, care
environment, acuity and epidemiological conditions that modify clinical
intelligence without itself constituting a diagnosis.';

COMMENT ON TABLE knowledge.context_value IS
'AMEXAN controlled vocabulary of clinical context values. Values must remain
stable machine identifiers because clinical rules, longitudinal records and
interoperability depend on semantic stability.';

COMMENT ON TABLE knowledge.context_relationship IS
'AMEXAN semantic relationships between clinical contexts. Relationships such
as implies or supports must not be interpreted as bidirectional clinical
diagnostic rules.';

COMMENT ON TABLE knowledge.body_system IS
'AMEXAN organ-system ontology used to organize symptoms, findings, mechanisms,
phenotypes, conditions, investigations and clinical pathways.';


-- =============================================================================
-- 13. VERIFICATION — CONTEXT TYPES
-- =============================================================================

SELECT
    code,
    label,
    description
FROM knowledge.context_type
ORDER BY code;


-- =============================================================================
-- 14. VERIFICATION — CONTEXT VALUES
-- =============================================================================

SELECT
    cv.context_type_code,
    ct.label AS context_type,
    cv.value,
    cv.label,
    cv.sort_order
FROM knowledge.context_value cv
JOIN knowledge.context_type ct
  ON ct.code = cv.context_type_code
ORDER BY
    cv.context_type_code,
    cv.sort_order;


-- =============================================================================
-- 15. VERIFICATION — CONTEXT RELATIONSHIPS
-- =============================================================================

SELECT
    cr.context_type_code,
    source.value AS source_value,
    target.value AS target_value,
    cr.relationship,
    cr.description
FROM knowledge.context_relationship cr
JOIN knowledge.context_value source
  ON source.id = cr.source_value_id
JOIN knowledge.context_value target
  ON target.id = cr.target_value_id
ORDER BY
    cr.context_type_code,
    source.value,
    target.value;


-- =============================================================================
-- 16. VERIFICATION — BODY SYSTEMS
-- =============================================================================

SELECT
    code,
    label,
    description
FROM knowledge.body_system
ORDER BY code;


-- =============================================================================
-- 17. FINAL SEED STATUS
-- =============================================================================

SELECT
    'AMEXAN Z2 clinical context + body-system intelligence seeded successfully'
        AS status,
    (SELECT COUNT(*) FROM knowledge.context_type)
        AS context_types,
    (SELECT COUNT(*) FROM knowledge.context_value)
        AS context_values,
    (SELECT COUNT(*) FROM knowledge.context_relationship)
        AS context_relationships,
    (SELECT COUNT(*) FROM knowledge.body_system)
        AS body_systems;