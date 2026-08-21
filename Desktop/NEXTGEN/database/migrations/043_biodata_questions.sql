-- =============================================================================
-- AMEXAN — 043: UNIVERSAL PATIENT ENTRY + CLINICAL CONTEXT RESOLUTION
--
-- PURPOSE
-- -------
-- Establishes the canonical registration/context layer for the AMEXAN
-- Clinical Operating System.
--
-- This migration provides:
--
--   1. Patient identity / demographic facts
--   2. Reported age vs derived age separation
--   3. Canonical age-band classification
--   4. Sex capture
--   5. Informant provenance and reliability
--   6. Reproductive-context capture
--   7. Pregnancy-context capture
--   8. Menstrual / LMP capture where clinically applicable
--   9. EDD / gestational-age derivation targets
--  10. Pediatric weight capture
--  11. Universal clinical formats
--  12. Format sections
--  13. Deterministic age compatibility
--  14. Department/service specialization
--  15. Sex-based exclusion of incompatible sections
--  16. Pregnancy-dependent activation
--  17. Neonatal/pediatric adaptive capture
--  18. Idempotent seeding
--
-- CORE PRINCIPLE
-- --------------
-- Patient identity is not the same thing as encounter state.
--
-- DOB is preferred as the canonical temporal source.
-- Entered age is retained as reported information and reconciled.
-- Clinical measurements such as weight are encounter/time dependent.
--
-- FORMAT RESOLUTION PRINCIPLE
-- ---------------------------
--
-- AGE COMPATIBILITY IS A HARD CONSTRAINT.
--
-- Department/service may specialize a clinically compatible format,
-- but may NEVER violate the patient's canonical age/developmental class.
--
-- Examples:
--
--   10-day-old + surgery       -> NEONATAL-compatible surgical workflow
--   10-year-old + surgery      -> PEDIATRIC-compatible surgical workflow
--   25-year-old + surgery      -> ADULT_SURGICAL
--   25-year-old + neonatology  -> invalid format combination
--
-- =============================================================================


-- ============================================================================
-- 1. UNIVERSAL FACT DEFINITIONS
-- ============================================================================

INSERT INTO clinical.fact_definition
    (code, name, description, data_type, is_active)
VALUES

-- Identity ---------------------------------------------------------------

('MRN',
 'Medical record number',
 'Permanent medical record identifier assigned to the patient.',
 'text',
 true),

('PATIENT_NAME',
 'Patient name',
 'Full legal or recorded name of the patient.',
 'text',
 true),

('DATE_OF_BIRTH',
 'Date of birth',
 'Canonical date of birth when known.',
 'date',
 true),

('REPORTED_AGE',
 'Reported age',
 'Age stated by the patient or informant before reconciliation against date of birth.',
 'numeric',
 true),

('AGE_YEARS',
 'Derived age in years',
 'Chronological age in completed years derived from date of birth.',
 'numeric',
 true),

('AGE_MONTHS',
 'Derived age in months',
 'Chronological age in completed months derived from date of birth.',
 'numeric',
 true),

('AGE_DAYS',
 'Derived age in days',
 'Chronological age in completed days derived from date of birth.',
 'numeric',
 true),

('AGE_BAND',
 'Canonical age band',
 'Canonical developmental/clinical age classification derived from chronological age.',
 'coded',
 true),

-- Sex --------------------------------------------------------------------

('SEX',
 'Sex',
 'Recorded biological/clinical sex classification relevant to clinical care.',
 'coded',
 true),

-- Geography --------------------------------------------------------------

('RESIDENCE',
 'Residence',
 'Current usual place of residence.',
 'text',
 true),

('COUNTY',
 'County',
 'County of residence.',
 'text',
 true),

-- Informant --------------------------------------------------------------

('INFORMANT_RELATION',
 'Informant relationship',
 'Relationship of the person providing history to the patient.',
 'coded',
 true),

('INFORMANT_RELIABILITY',
 'Informant reliability',
 'Clinical assessment of the reliability of the history source.',
 'coded',
 true),

('INFORMANT_IDENTITY',
 'Informant identity',
 'Name or identifying description of the person providing collateral history.',
 'text',
 true),

-- Next of kin ------------------------------------------------------------

('NEXT_OF_KIN_NAME',
 'Next of kin name',
 'Name of the nominated next of kin.',
 'text',
 true),

('NEXT_OF_KIN_PHONE',
 'Next of kin phone',
 'Telephone contact for the nominated next of kin.',
 'text',
 true),

-- Reproductive context ---------------------------------------------------

('REPRODUCTIVE_CONTEXT',
 'Reproductive context',
 'Clinical reproductive context used to determine whether reproductive history is relevant.',
 'coded',
 true),

('PREGNANCY_STATUS',
 'Pregnancy status',
 'Current pregnancy state.',
 'coded',
 true),

('LMP_DATE',
 'Last menstrual period',
 'Date of the first day of the last menstrual period when known and clinically applicable.',
 'date',
 true),

('LMP_CERTAINTY',
 'LMP certainty',
 'Confidence in the recorded last menstrual period.',
 'coded',
 true),

('EDD',
 'Expected date of delivery',
 'Estimated date of delivery derived from the documented dating method.',
 'date',
 true),

('GESTATIONAL_AGE_WEEKS',
 'Gestational age in weeks',
 'Estimated gestational age in completed weeks at the reference date.',
 'numeric',
 true),

('GESTATIONAL_DATING_METHOD',
 'Gestational dating method',
 'Method used to establish gestational age.',
 'coded',
 true),

-- Pediatric --------------------------------------------------------------

('BODY_WEIGHT_KG',
 'Body weight',
 'Current measured body weight in kilograms. Encounter/time dependent.',
 'numeric',
 true),

('WEIGHT_MEASUREMENT_DATE',
 'Weight measurement date',
 'Date/time associated with the recorded body weight.',
 'date',
 true),

-- Clinical context ------------------------------------------------------

('CARE_SETTING',
 'Care setting',
 'Clinical setting in which the encounter occurs.',
 'coded',
 true),

('DEPARTMENT',
 'Clinical department',
 'Clinical department/service responsible for the encounter.',
 'coded',
 true),

-- [RECONCILED] Legacy symptom facts referenced by earlier fact_mapping rows
-- (019_seed_corrections_cpu) but never added to the fact dictionary. 041's
-- canonical redefinition does not carry these codes; re-register them so the
-- question_fact / fact_mapping integrity checks in this migration resolve.
('CHEST_PAIN_PRESENT',
 'Chest pain present',
 'Patient reports chest pain.',
 'boolean',
 true),

('COUGH_SEVERITY',
 'Cough severity',
 'Subjective severity of cough.',
 'coded',
 true),

('DYSPNOEA_PRESENT',
 'Dyspnoea present',
 'Patient reports breathlessness.',
 'boolean',
 true)

ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    data_type = EXCLUDED.data_type,
    is_active = EXCLUDED.is_active;


-- ============================================================================
-- 2. CONTEXT TYPES
-- ============================================================================

INSERT INTO knowledge.context_type
    (code, label, description)
VALUES

('AGE_BAND',
 'Canonical age band',
 'Chronological age classification used for clinical format compatibility.'),

('SEX',
 'Sex',
 'Recorded sex classification relevant to clinical care.'),

('REPRODUCTIVE',
 'Reproductive context',
 'Determines whether reproductive/menstrual/pregnancy capture is clinically relevant.'),

('PREGNANCY',
 'Pregnancy state',
 'Current pregnancy state.'),

('DEPARTMENT',
 'Clinical department',
 'Clinical service responsible for the encounter.'),

('CARE_SETTING',
 'Care setting',
 'Clinical environment in which care is delivered.')

ON CONFLICT (code) DO NOTHING;


-- ============================================================================
-- 3. CONTEXT VALUES
-- ============================================================================

INSERT INTO knowledge.context_value
    (context_type_code, value, label, sort_order)
VALUES

-- Age --------------------------------------------------------------------

('AGE_BAND', 'NEONATE',    'Neonate: 0–27 days',       1),
('AGE_BAND', 'INFANT',     'Infant: 28 days–<1 year',  2),
('AGE_BAND', 'CHILD',      'Child: 1–<12 years',       3),
('AGE_BAND', 'ADOLESCENT', 'Adolescent: 12–<18 years', 4),
('AGE_BAND', 'ADULT',      'Adult: ≥18 years',         5),

-- Sex --------------------------------------------------------------------

('SEX', 'MALE',    'Male',    1),
('SEX', 'FEMALE',  'Female',  2),
('SEX', 'INTERSEX', 'Intersex', 3),
('SEX', 'UNKNOWN', 'Unknown/not recorded', 4),

-- Reproductive -----------------------------------------------------------

('REPRODUCTIVE', 'NOT_APPLICABLE',
 'Reproductive history not clinically applicable',
 1),

('REPRODUCTIVE', 'REPRODUCTIVE_CONTEXT_RELEVANT',
 'Reproductive history may be clinically relevant',
 2),

('REPRODUCTIVE', 'POST_REPRODUCTIVE',
 'Post-reproductive context',
 3),

('REPRODUCTIVE', 'UNKNOWN',
 'Reproductive context unknown',
 4),

-- Pregnancy -------------------------------------------------------------

('PREGNANCY', 'PREGNANT',
 'Currently pregnant',
 1),

('PREGNANCY', 'NOT_PREGNANT',
 'Not currently pregnant',
 2),

('PREGNANCY', 'POSSIBLE',
 'Pregnancy possible/not yet excluded',
 3),

('PREGNANCY', 'UNKNOWN',
 'Pregnancy status unknown',
 4),

('PREGNANCY', 'POSTPARTUM',
 'Postpartum state',
 5),

('PREGNANCY', 'NOT_APPLICABLE',
 'Pregnancy not applicable',
 6)

ON CONFLICT (context_type_code, value)
DO NOTHING;


-- ============================================================================
-- 4. CLINICAL SERVICES
-- ============================================================================

INSERT INTO organization.service
    (code, name, description, service_category, is_active)
VALUES

('medical',
 'Internal Medicine',
 'Adult medical clinical service.',
 'clinical',
 true),

('surgical',
 'General Surgery',
 'Adult surgical clinical service.',
 'clinical',
 true),

('obgyn',
 'Obstetrics & Gynaecology',
 'Obstetric and gynaecological clinical service.',
 'clinical',
 true),

('paediatrics',
 'Paediatrics',
 'Paediatric clinical service.',
 'clinical',
 true),

('neonatology',
 'Neonatology',
 'Neonatal clinical service.',
 'clinical',
 true),

('psychiatry',
 'Psychiatry',
 'Psychiatric clinical service.',
 'clinical',
 true),

('emergency',
 'Emergency Medicine',
 'Emergency and acute care clinical service.',
 'clinical',
 true),

('other',
 'Other',
 'Other clinical service.',
 'clinical',
 true)

ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    service_category = EXCLUDED.service_category,
    is_active = EXCLUDED.is_active;


-- ============================================================================
-- 5. UNIVERSAL CLINICAL FORMATS
-- ============================================================================

INSERT INTO knowledge.clinical_format
    (format_code, name, description, sort_order, status)
VALUES

(
 'ADULT_MEDICAL',
 'Adult Medical',
 'Adult medical clinical workflow.',
 1,
 'active'
),

(
 'ADULT_SURGICAL',
 'Adult Surgical',
 'Adult surgical clinical workflow.',
 2,
 'active'
),

(
 'PEDIATRIC',
 'Paediatric',
 'Paediatric clinical workflow for patients from 28 days to under 18 years, with age-specific adaptation.',
 3,
 'active'
),

(
 'NEONATAL',
 'Neonatal',
 'Neonatal clinical workflow for patients from birth through 27 completed days.',
 4,
 'active'
),

(
 'OBGYN',
 'Obstetrics & Gynaecology',
 'Female reproductive and pregnancy-related clinical workflow where clinically applicable.',
 5,
 'active'
),

(
 'PSYCHIATRY',
 'Psychiatry',
 'Psychiatric clinical workflow.',
 6,
 'active'
)

ON CONFLICT (format_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    status = EXCLUDED.status;


-- ============================================================================
-- 6. UNIVERSAL FORMAT SECTIONS
--
-- NOTE:
-- Assessment, differential diagnosis, investigations and management remain
-- locked until the preceding clinical evidence permits them.
-- The CPU must never fabricate them from registration data alone.
-- ============================================================================

-- [RECONCILED] 039's universal section catalogue uses hyphenated section
-- codes; the format definitions below reference underscore-coded sections
-- (BIODATA, EXAM_CVS, ...) that are not part of that catalogue. Register the
-- missing section codes here so the clinical_format_section FKs resolve.
INSERT INTO knowledge.clinical_section
(
    section_code,
    name,
    description,
    clinical_purpose,
    section_group,
    clinical_sequence,
    repeatable,
    default_required
)
VALUES
    ('BIODATA',                    'Biodata',                       'Demographic identifiers and registration data.',                                'Establish identity, age, sex, residence and informant reliability.',        'IDENTIFICATION', 5, false, true),
    ('ANC_PROFILE',                'Antenatal Profile',             'Antenatal booking and pregnancy baseline.',                                    'Capture obstetric baseline for antenatal care.',                            'HISTORY', 105, false, false),
    ('BIRTH_HISTORY',              'Birth History',                 'Perinatal and delivery history.',                                              'Capture mode of delivery, gestation and neonatal course.',                   'HISTORY', 115, false, false),
    ('DEVELOPMENTAL_HISTORY',      'Developmental History',         'Developmental milestones.',                                                   'Capture developmental progress for paediatric assessment.',                   'HISTORY', 116, false, false),
    ('FEEDING_HISTORY',            'Feeding History',               'Infant feeding pattern.',                                                     'Capture breastfeeding and complementary feeding.',                            'HISTORY', 117, false, false),
    ('IMMUNIZATION_HISTORY',       'Immunization History',          'Vaccination status.',                                                        'Capture immunisation record for prevention review.',                         'HISTORY', 118, false, false),
    ('GYNAECOLOGICAL_HISTORY',     'Gynaecological History',        'Menstrual and gynaecological history.',                                        'Capture menstrual, sexual and gynaecological history.',                      'HISTORY', 119, false, false),
    ('MENSTRUAL_HISTORY',          'Menstrual History',             'Menstrual cycle details.',                                                    'Capture last menstrual period and cycle pattern.',                           'HISTORY', 120, false, false),
    ('OBSTETRIC_HISTORY',          'Obstetric History',             'Previous and current pregnancy history.',                                      'Capture gravidity, parity and pregnancy course.',                            'HISTORY', 121, false, false),
    ('PSYCHIATRIC_HISTORY',        'Psychiatric History',           'Psychiatric and mental health history.',                                       'Capture psychiatric presentation and risk factors.',                         'HISTORY', 122, false, false),
    ('SUBSTANCE_USE',              'Substance Use History',         'Alcohol, tobacco and other substance use.',                                    'Capture substance use for risk assessment.',                                 'HISTORY', 123, false, false),
    ('SUICIDE_RISK',               'Suicide & Self-harm Risk',      'Suicide and self-harm risk factors.',                                          'Assess self-harm and suicide risk for safety planning.',                     'HISTORY', 124, false, false),
    ('PMHX',                       'Past Medical History',          'Past and ongoing medical conditions.',                                         'Capture chronic and prior medical problems.',                                'HISTORY', 125, false, false),
    ('SOCIAL',                     'Social & Occupational History', 'Social, occupational and environmental history.',                              'Capture social context, occupation and exposures.',                          'HISTORY', 126, false, false),
    ('FAMILY',                     'Family History',                'Family and hereditary conditions.',                                            'Capture familial disease patterns.',                                         'HISTORY', 127, false, false),
    ('EXAM_GENERAL',               'General Examination',           'General systemic examination.',                                                'Overall appearance, vital signs and general systems.',                       'EXAMINATION', 200, false, false),
    ('EXAM_CVS',                   'Cardiovascular Examination',    'Cardiovascular system examination.',                                           'Inspect, palpate, percuss and auscultate cardiovascular system.',            'EXAMINATION', 210, false, false),
    ('EXAM_RESP',                  'Respiratory Examination',       'Respiratory system examination.',                                             'Inspect, palpate, percuss and auscultate respiratory system.',               'EXAMINATION', 220, false, false),
    ('EXAM_ABDO',                  'Abdominal Examination',         'Abdominal and gastrointestinal examination.',                                 'Inspect, palpate, percuss and auscultate abdomen.',                          'EXAMINATION', 230, false, false),
    ('EXAM_NEURO',                 'Neurological Examination',      'Neurological system examination.',                                            'Cranial nerves, motor, sensory, cerebellar and gait assessment.',            'EXAMINATION', 240, false, false),
    ('EXAM_GYNAEC',                'Gynaecological Examination',    'Gynaecological and pelvic examination.',                                      'Speculum, bimanual and related pelvic assessment.',                          'EXAMINATION', 250, false, false),
    ('EXAM_OBSTETRIC',             'Obstetric Examination',         'Obstetric abdominal examination.',                                            'Uterine size, lie, presentation, fetal heart and fetal monitoring.',         'EXAMINATION', 260, false, false),
    ('EXAM_MSK',                   'Musculoskeletal Examination',   'Musculoskeletal system examination.',                                          'Inspect, palpate and move joints and muscles.',                              'EXAMINATION', 270, false, false),
    ('EXAM_PSYCH',                 'Mental State Examination',      'Mental state and cognitive examination.',                                      'Appearance, behaviour, speech, mood, cognition and insight.',                'EXAMINATION', 280, false, false),
    ('ASSESSMENT',                 'Assessment & Differential',     'Clinical assessment and differential diagnosis.',                              'Synthesise findings into assessment and differentials.',                     'ASSESSMENT', 400, false, false),
    ('MANAGEMENT',                 'Management & Treatment',        'Management plan and treatment.',                                               'Document management plan, treatment and prescriptions.',                     'MANAGEMENT', 500, false, false),
    ('DOCUMENTATION',              'Documentation',                 'Clinical documentation.',                                                      'Compile the clinical record for the encounter.',                             'DOCUMENTATION', 700, false, false)
ON CONFLICT (section_code) DO NOTHING;

INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group,
     sequence_no, is_required, default_state)
VALUES

-- ADULT MEDICAL ----------------------------------------------------------

('ADULT_MEDICAL','BIODATA','Patient & Demographics','HISTORY',1,true,'complete'),
('ADULT_MEDICAL','CC','Chief Complaint','HISTORY',2,true,'available'),
('ADULT_MEDICAL','HPI','History of Present Illness','HISTORY',3,true,'active'),
('ADULT_MEDICAL','ROS','Review of Systems','HISTORY',4,false,'available'),
('ADULT_MEDICAL','PMHX','Past Medical History','HISTORY',5,false,'available'),
('ADULT_MEDICAL','MEDICATIONS','Medications & Allergies','HISTORY',6,false,'available'),
('ADULT_MEDICAL','SOCIAL','Social & Occupational History','HISTORY',7,false,'available'),
('ADULT_MEDICAL','FAMILY','Family History','HISTORY',8,false,'available'),
('ADULT_MEDICAL','EXAM_GENERAL','General Examination','EXAMINATION',9,false,'available'),
('ADULT_MEDICAL','EXAM_CVS','Cardiovascular Examination','EXAMINATION',10,false,'available'),
('ADULT_MEDICAL','EXAM_RESP','Respiratory Examination','EXAMINATION',11,false,'available'),
('ADULT_MEDICAL','EXAM_ABDO','Abdominal Examination','EXAMINATION',12,false,'available'),
('ADULT_MEDICAL','EXAM_NEURO','Neurological Examination','EXAMINATION',13,false,'available'),
('ADULT_MEDICAL','ASSESSMENT','Assessment & Differential','ASSESSMENT',14,false,'locked'),
('ADULT_MEDICAL','INVESTIGATIONS','Investigations','INVESTIGATIONS',15,false,'locked'),
('ADULT_MEDICAL','MANAGEMENT','Management & Treatment','MANAGEMENT',16,false,'locked'),
('ADULT_MEDICAL','MONITORING','Monitoring & Escalation','MONITORING',17,false,'locked'),
('ADULT_MEDICAL','DOCUMENTATION','Documentation','DOCUMENTATION',18,false,'locked'),

-- ADULT SURGICAL ---------------------------------------------------------

('ADULT_SURGICAL','BIODATA','Patient & Demographics','HISTORY',1,true,'complete'),
('ADULT_SURGICAL','CC','Chief Complaint','HISTORY',2,true,'available'),
('ADULT_SURGICAL','HPI','History of Present Illness','HISTORY',3,true,'active'),
('ADULT_SURGICAL','ROS','Review of Systems','HISTORY',4,false,'available'),
('ADULT_SURGICAL','PMHX','Past Medical History','HISTORY',5,false,'available'),
('ADULT_SURGICAL','MEDICATIONS','Medications & Allergies','HISTORY',6,false,'available'),
('ADULT_SURGICAL','SOCIAL','Social & Occupational History','HISTORY',7,false,'available'),
('ADULT_SURGICAL','FAMILY','Family History','HISTORY',8,false,'available'),
('ADULT_SURGICAL','EXAM_GENERAL','General Examination','EXAMINATION',9,false,'available'),
('ADULT_SURGICAL','EXAM_ABDO','Abdominal Examination','EXAMINATION',10,false,'available'),
('ADULT_SURGICAL','EXAM_MSK','Musculoskeletal Examination','EXAMINATION',11,false,'available'),
('ADULT_SURGICAL','EXAM_NEURO','Neurological Examination','EXAMINATION',12,false,'available'),
('ADULT_SURGICAL','ASSESSMENT','Assessment & Differential','ASSESSMENT',13,false,'locked'),
('ADULT_SURGICAL','INVESTIGATIONS','Investigations','INVESTIGATIONS',14,false,'locked'),
('ADULT_SURGICAL','MANAGEMENT','Management & Treatment','MANAGEMENT',15,false,'locked'),
('ADULT_SURGICAL','MONITORING','Monitoring & Escalation','MONITORING',16,false,'locked'),
('ADULT_SURGICAL','DOCUMENTATION','Documentation','DOCUMENTATION',17,false,'locked'),

-- PEDIATRIC --------------------------------------------------------------

('PEDIATRIC','BIODATA','Patient & Demographics','HISTORY',1,true,'complete'),
('PEDIATRIC','CC','Chief Complaint','HISTORY',2,true,'available'),
('PEDIATRIC','HPI','History of Present Illness','HISTORY',3,true,'active'),
('PEDIATRIC','ROS','Review of Systems','HISTORY',4,false,'available'),
('PEDIATRIC','PMHX','Past Medical History','HISTORY',5,false,'available'),
('PEDIATRIC','MEDICATIONS','Medications & Allergies','HISTORY',6,false,'available'),
('PEDIATRIC','SOCIAL','Social & Caregiver History','HISTORY',7,false,'available'),
('PEDIATRIC','FAMILY','Family History','HISTORY',8,false,'available'),
('PEDIATRIC','BIRTH_HISTORY','Birth History','HISTORY',9,false,'available'),
('PEDIATRIC','FEEDING_HISTORY','Feeding History','HISTORY',10,false,'available'),
('PEDIATRIC','DEVELOPMENTAL_HISTORY','Developmental History','HISTORY',11,false,'available'),
('PEDIATRIC','IMMUNIZATION_HISTORY','Immunization History','HISTORY',12,false,'available'),
('PEDIATRIC','EXAM_GENERAL','General Examination','EXAMINATION',13,false,'available'),
('PEDIATRIC','EXAM_RESP','Respiratory Examination','EXAMINATION',14,false,'available'),
('PEDIATRIC','EXAM_CVS','Cardiovascular Examination','EXAMINATION',15,false,'available'),
('PEDIATRIC','EXAM_ABDO','Abdominal Examination','EXAMINATION',16,false,'available'),
('PEDIATRIC','EXAM_NEURO','Neurological Examination','EXAMINATION',17,false,'available'),
('PEDIATRIC','ASSESSMENT','Assessment & Differential','ASSESSMENT',18,false,'locked'),
('PEDIATRIC','INVESTIGATIONS','Investigations','INVESTIGATIONS',19,false,'locked'),
('PEDIATRIC','MANAGEMENT','Management & Treatment','MANAGEMENT',20,false,'locked'),
('PEDIATRIC','MONITORING','Monitoring & Escalation','MONITORING',21,false,'locked'),
('PEDIATRIC','DOCUMENTATION','Documentation','DOCUMENTATION',22,false,'locked'),

-- NEONATAL ---------------------------------------------------------------

('NEONATAL','BIODATA','Neonate & Demographics','HISTORY',1,true,'complete'),
('NEONATAL','CC','Chief Complaint','HISTORY',2,true,'available'),
('NEONATAL','HPI','History of Present Illness','HISTORY',3,true,'active'),
('NEONATAL','BIRTH_HISTORY','Birth History','HISTORY',4,true,'available'),
('NEONATAL','FEEDING_HISTORY','Feeding History','HISTORY',5,true,'available'),
('NEONATAL','IMMUNIZATION_HISTORY','Birth Immunization','HISTORY',6,false,'available'),
('NEONATAL','EXAM_GENERAL','General Examination','EXAMINATION',7,true,'available'),
('NEONATAL','EXAM_RESP','Respiratory Examination','EXAMINATION',8,true,'available'),
('NEONATAL','EXAM_CVS','Cardiovascular Examination','EXAMINATION',9,false,'available'),
('NEONATAL','EXAM_ABDO','Abdominal Examination','EXAMINATION',10,false,'available'),
('NEONATAL','EXAM_NEURO','Neurological Examination','EXAMINATION',11,false,'available'),
('NEONATAL','ASSESSMENT','Assessment & Differential','ASSESSMENT',12,false,'locked'),
('NEONATAL','INVESTIGATIONS','Investigations','INVESTIGATIONS',13,false,'locked'),
('NEONATAL','MANAGEMENT','Management & Treatment','MANAGEMENT',14,false,'locked'),
('NEONATAL','MONITORING','Monitoring & Escalation','MONITORING',15,false,'locked'),
('NEONATAL','DOCUMENTATION','Documentation','DOCUMENTATION',16,false,'locked'),

-- OBGYN ------------------------------------------------------------------

('OBGYN','BIODATA','Patient & Demographics','HISTORY',1,true,'complete'),
('OBGYN','CC','Chief Complaint','HISTORY',2,true,'available'),
('OBGYN','HPI','History of Present Illness','HISTORY',3,true,'active'),
('OBGYN','ROS','Review of Systems','HISTORY',4,false,'available'),
('OBGYN','PMHX','Past Medical History','HISTORY',5,false,'available'),
('OBGYN','MEDICATIONS','Medications & Allergies','HISTORY',6,false,'available'),
('OBGYN','SOCIAL','Social History','HISTORY',7,false,'available'),
('OBGYN','FAMILY','Family History','HISTORY',8,false,'available'),
('OBGYN','MENSTRUAL_HISTORY','Menstrual History','HISTORY',9,false,'available'),
('OBGYN','OBSTETRIC_HISTORY','Obstetric History','HISTORY',10,false,'available'),
('OBGYN','GYNAECOLOGICAL_HISTORY','Gynaecological History','HISTORY',11,false,'available'),
('OBGYN','ANC_PROFILE','Antenatal Care Profile','HISTORY',12,false,'available'),
('OBGYN','EXAM_GENERAL','General Examination','EXAMINATION',13,false,'available'),
('OBGYN','EXAM_ABDO','Abdominal Examination','EXAMINATION',14,false,'available'),
('OBGYN','EXAM_OBSTETRIC','Obstetric Examination','EXAMINATION',15,false,'available'),
('OBGYN','EXAM_GYNAEC','Gynaecological Examination','EXAMINATION',16,false,'available'),
('OBGYN','ASSESSMENT','Assessment & Differential','ASSESSMENT',17,false,'locked'),
('OBGYN','INVESTIGATIONS','Investigations','INVESTIGATIONS',18,false,'locked'),
('OBGYN','MANAGEMENT','Management & Treatment','MANAGEMENT',19,false,'locked'),
('OBGYN','MONITORING','Monitoring & Escalation','MONITORING',20,false,'locked'),
('OBGYN','DOCUMENTATION','Documentation','DOCUMENTATION',21,false,'locked'),

-- PSYCHIATRY -------------------------------------------------------------

('PSYCHIATRY','BIODATA','Patient & Demographics','HISTORY',1,true,'complete'),
('PSYCHIATRY','CC','Chief Complaint','HISTORY',2,true,'available'),
('PSYCHIATRY','HPI','History of Present Illness','HISTORY',3,true,'active'),
('PSYCHIATRY','ROS','Review of Systems','HISTORY',4,false,'available'),
('PSYCHIATRY','PMHX','Past Medical History','HISTORY',5,false,'available'),
('PSYCHIATRY','MEDICATIONS','Medications & Allergies','HISTORY',6,false,'available'),
('PSYCHIATRY','SOCIAL','Social History','HISTORY',7,false,'available'),
('PSYCHIATRY','FAMILY','Family History','HISTORY',8,false,'available'),
('PSYCHIATRY','PSYCHIATRIC_HISTORY','Psychiatric History','HISTORY',9,true,'available'),
('PSYCHIATRY','SUBSTANCE_USE','Substance Use History','HISTORY',10,false,'available'),
('PSYCHIATRY','SUICIDE_RISK','Suicide & Self-harm Risk','HISTORY',11,true,'available'),
('PSYCHIATRY','EXAM_GENERAL','General Examination','EXAMINATION',12,false,'available'),
('PSYCHIATRY','EXAM_NEURO','Neurological Examination','EXAMINATION',13,false,'available'),
('PSYCHIATRY','EXAM_PSYCH','Mental State Examination','EXAMINATION',14,true,'available'),
('PSYCHIATRY','ASSESSMENT','Assessment & Differential','ASSESSMENT',15,false,'locked'),
('PSYCHIATRY','INVESTIGATIONS','Investigations','INVESTIGATIONS',16,false,'locked'),
('PSYCHIATRY','MANAGEMENT','Management & Treatment','MANAGEMENT',17,false,'locked'),
('PSYCHIATRY','MONITORING','Monitoring & Escalation','MONITORING',18,false,'locked'),
('PSYCHIATRY','DOCUMENTATION','Documentation','DOCUMENTATION',19,false,'locked')

ON CONFLICT (format_code, section_code)
DO NOTHING;


-- ============================================================================
-- 7. HARD FORMAT COMPATIBILITY RULES
--
-- IMPORTANT:
-- These are NOT merely weighted preferences.
-- The resolver must treat these as hard compatibility constraints.
-- ============================================================================

INSERT INTO knowledge.format_context_rule
    (rule_code, format_code, context_type, context_value,
     action, priority_weight, rationale, status)
VALUES

-- Neonatal ---------------------------------------------------------------

(
 'FCR-AGE-NEONATE',
 'NEONATAL',
 'AGE_BAND',
 'NEONATE',
 'SELECT',
 1000,
 'Canonical age compatibility: 0–27 completed days.',
 'active'
),

(
 'FCR-NONNEONATE-BLOCK-NEONATAL',
 'NEONATAL',
 'AGE_BAND',
 'ADULT',
 'BLOCK',
 2000,
 'A patient in the adult age band cannot resolve to neonatal format.',
 'active'
),

(
 'FCR-NONNEONATE-BLOCK-NEONATAL-ADOLESCENT',
 'NEONATAL',
 'AGE_BAND',
 'ADOLESCENT',
 'BLOCK',
 2000,
 'An adolescent cannot resolve to neonatal format.',
 'active'
),

(
 'FCR-NONNEONATE-BLOCK-NEONATAL-CHILD',
 'NEONATAL',
 'AGE_BAND',
 'CHILD',
 'BLOCK',
 2000,
 'A child cannot resolve to neonatal format.',
 'active'
),

(
 'FCR-NONNEONATE-BLOCK-NEONATAL-INFANT',
 'NEONATAL',
 'AGE_BAND',
 'INFANT',
 'BLOCK',
 2000,
 'An infant aged 28 days or older cannot resolve to neonatal format.',
 'active'
),

-- Pediatric --------------------------------------------------------------

(
 'FCR-AGE-INFANT',
 'PEDIATRIC',
 'AGE_BAND',
 'INFANT',
 'SELECT',
 1000,
 'Canonical age compatibility for infants.',
 'active'
),

(
 'FCR-AGE-CHILD',
 'PEDIATRIC',
 'AGE_BAND',
 'CHILD',
 'SELECT',
 1000,
 'Canonical age compatibility for children.',
 'active'
),

(
 'FCR-AGE-ADOLESCENT',
 'PEDIATRIC',
 'AGE_BAND',
 'ADOLESCENT',
 'SELECT',
 1000,
 'Adolescents remain developmentally paediatric until adulthood, while receiving adolescent-specific adaptations.',
 'active'
),

-- Adult ------------------------------------------------------------------

(
 'FCR-AGE-ADULT-MEDICAL',
 'ADULT_MEDICAL',
 'AGE_BAND',
 'ADULT',
 'SELECT',
 1000,
 'Adults resolve to the adult medical base.',
 'active'
),

(
 'FCR-AGE-ADULT-SURGICAL',
 'ADULT_SURGICAL',
 'AGE_BAND',
 'ADULT',
 'SELECT',
 1000,
 'Adult surgical format is compatible only with adult age.',
 'active'
),

-- Sex invariant ----------------------------------------------------------

(
 'FCR-OBGYN-MALE-BLOCK',
 'OBGYN',
 'SEX',
 'MALE',
 'BLOCK',
 5000,
 'Hard invariant: male patients cannot resolve to the OBGYN format.',
 'active'
),

-- Pregnancy --------------------------------------------------------------

(
 'FCR-OBGYN-PREGNANCY',
 'OBGYN',
 'PREGNANCY',
 'PREGNANT',
 'SELECT',
 2500,
 'Pregnancy establishes obstetric relevance.',
 'active'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- ============================================================================
-- 8. SECTION SAFETY RULES
-- ============================================================================

INSERT INTO knowledge.section_context_rule
    (rule_code, section_code, context_type, context_value,
     modification, priority_weight, rationale, status)
VALUES

-- Male exclusions --------------------------------------------------------

(
 'SCR-MALE-MENSTRUAL',
 'MENSTRUAL_HISTORY',
 'SEX',
 'MALE',
 'HIDE',
 5000,
 'Menstrual history is not presented to a male patient.',
 'active'
),

(
 'SCR-MALE-OBSTETRIC',
 'OBSTETRIC_HISTORY',
 'SEX',
 'MALE',
 'HIDE',
 5000,
 'Obstetric history is not presented to a male patient.',
 'active'
),

(
 'SCR-MALE-GYNAE',
 'GYNAECOLOGICAL_HISTORY',
 'SEX',
 'MALE',
 'HIDE',
 5000,
 'Gynaecological history is not presented to a male patient.',
 'active'
),

(
 'SCR-MALE-ANC',
 'ANC_PROFILE',
 'SEX',
 'MALE',
 'HIDE',
 5000,
 'Antenatal care capture is not presented to a male patient.',
 'active'
),

(
 'SCR-MALE-OBSTETRIC-EXAM',
 'EXAM_OBSTETRIC',
 'SEX',
 'MALE',
 'HIDE',
 5000,
 'Obstetric examination is not presented to a male patient.',
 'active'
),

(
 'SCR-MALE-GYNAE-EXAM',
 'EXAM_GYNAEC',
 'SEX',
 'MALE',
 'HIDE',
 5000,
 'Gynaecological examination is not presented to a male patient.',
 'active'
),

-- Pregnancy activation --------------------------------------------------

(
 'SCR-PREGNANCY-ANC',
 'ANC_PROFILE',
 'PREGNANCY',
 'PREGNANT',
 'REQUIRE',
 2000,
 'Pregnancy requires antenatal/obstetric context capture where applicable.',
 'active'
),

(
 'SCR-PREGNANCY-OBSTETRIC',
 'OBSTETRIC_HISTORY',
 'PREGNANCY',
 'PREGNANT',
 'REQUIRE',
 2000,
 'Pregnancy requires obstetric history.',
 'active'
),

(
 'SCR-PREGNANCY-OBSTETRIC-EXAM',
 'EXAM_OBSTETRIC',
 'PREGNANCY',
 'PREGNANT',
 'REQUIRE',
 2000,
 'Pregnancy requires appropriate obstetric examination when clinically indicated.',
 'active'
),

-- Neonatal ---------------------------------------------------------------

(
 'SCR-NEONATE-BIRTH',
 'BIRTH_HISTORY',
 'AGE_BAND',
 'NEONATE',
 'REQUIRE',
 3000,
 'Neonatal clinical entry requires birth history.',
 'active'
),

(
 'SCR-NEONATE-FEEDING',
 'FEEDING_HISTORY',
 'AGE_BAND',
 'NEONATE',
 'REQUIRE',
 3000,
 'Neonatal clinical entry requires feeding history.',
 'active'
),

-- Pediatric --------------------------------------------------------------

(
 'SCR-PEDIATRIC-BIRTH',
 'BIRTH_HISTORY',
 'AGE_BAND',
 'CHILD',
 'REQUIRE',
 1000,
 'Birth history remains available where clinically relevant in paediatric care.',
 'active'
),

(
 'SCR-PEDIATRIC-FEEDING',
 'FEEDING_HISTORY',
 'AGE_BAND',
 'INFANT',
 'REQUIRE',
 1500,
 'Feeding assessment is clinically important in infants.',
 'active'
),

(
 'SCR-PEDIATRIC-DEVELOPMENT',
 'DEVELOPMENTAL_HISTORY',
 'AGE_BAND',
 'CHILD',
 'REQUIRE',
 1500,
 'Developmental assessment is clinically relevant in childhood.',
 'active'
),

(
 'SCR-PEDIATRIC-IMMUNIZATION',
 'IMMUNIZATION_HISTORY',
 'AGE_BAND',
 'CHILD',
 'REQUIRE',
 1500,
 'Immunization status is clinically relevant in childhood.',
 'active'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- ============================================================================
-- 9. BIODATA MODULE
-- ============================================================================

INSERT INTO knowledge.question_module
    (module_code, module_name, description, sort_order, status)
VALUES
(
 'BIODATA',
 'Universal Patient Entry',
 'Universal clinical registration and context-resolution interview.',
 1,
 'active'
)

ON CONFLICT (module_code)
DO NOTHING;

UPDATE knowledge.question_module
SET section_code = 'BIODATA'
WHERE module_code = 'BIODATA';


-- ============================================================================
-- 10. UNIVERSAL QUESTIONS
-- ============================================================================

INSERT INTO knowledge.question
    (question_code, question_type, text, response_type,
     priority, question_mode, is_active)
VALUES

(
 'BIODATA_PATIENT_NAME',
 'clinical',
 'What is the patient''s full name?',
 'text',
 1,
 'DIRECT',
 true
),

(
 'BIODATA_DATE_OF_BIRTH',
 'clinical',
 'What is the patient''s date of birth?',
 'date',
 2,
 'DIRECT',
 true
),

(
 'BIODATA_REPORTED_AGE',
 'clinical',
 'What is the patient''s age?',
 'numeric',
 3,
 'DIRECT',
 true
),

(
 'BIODATA_SEX',
 'clinical',
 'What is the patient''s sex?',
 'single_choice',
 4,
 'DIRECT',
 true
),

(
 'BIODATA_OCCUPATION',
 'clinical',
 'What is the patient''s occupation or usual activity?',
 'text',
 5,
 'DIRECT',
 true
),

(
 'BIODATA_RESIDENCE',
 'clinical',
 'Where does the patient usually reside?',
 'text',
 6,
 'DIRECT',
 true
),

(
 'BIODATA_COUNTY',
 'clinical',
 'Which county does the patient reside in?',
 'text',
 7,
 'DIRECT',
 true
),

(
 'BIODATA_INFORMANT_RELATION',
 'clinical',
 'What is the informant''s relationship to the patient?',
 'single_choice',
 8,
 'DIRECT',
 true
),

(
 'BIODATA_INFORMANT_RELIABILITY',
 'clinical',
 'How reliable is the history provided by the informant?',
 'single_choice',
 9,
 'DIRECT',
 true
),

(
 'BIODATA_NEXT_OF_KIN',
 'clinical',
 'Who is the patient''s next of kin?',
 'text',
 10,
 'DIRECT',
 true
),

(
 'BIODATA_NEXT_OF_KIN_PHONE',
 'clinical',
 'What is the next of kin''s telephone number?',
 'text',
 11,
 'DIRECT',
 true
),

(
 'BIODATA_PREGNANCY_STATUS',
 'clinical',
 'What is the patient''s current pregnancy status?',
 'single_choice',
 12,
 'DIRECT',
 true
),

(
 'BIODATA_LMP',
 'clinical',
 'What was the first day of the last menstrual period?',
 'date',
 13,
 'DIRECT',
 true
),

(
 'BIODATA_LMP_CERTAINTY',
 'clinical',
 'How certain is the recorded last menstrual period?',
 'single_choice',
 14,
 'DIRECT',
 true
),

(
 'BIODATA_WEIGHT',
 'clinical',
 'What is the patient''s current body weight?',
 'numeric',
 15,
 'DIRECT',
 true
)

ON CONFLICT (question_code)
DO NOTHING;


-- ============================================================================
-- 11. ANSWER OPTIONS
-- ============================================================================

INSERT INTO knowledge.answer_option
    (question_id, answer_code, label, value_text, sort_order, is_active)

SELECT
    q.id,
    o.answer_code,
    o.label,
    o.value_text,
    o.sort_order,
    true

FROM knowledge.question q

CROSS JOIN
(
    VALUES

    -- Sex ---------------------------------------------------------------

    ('BIODATA_SEX','MALE','Male','MALE',1),
    ('BIODATA_SEX','FEMALE','Female','FEMALE',2),
    ('BIODATA_SEX','INTERSEX','Intersex','INTERSEX',3),
    ('BIODATA_SEX','UNKNOWN','Unknown/not recorded','UNKNOWN',4),

    -- Informant ---------------------------------------------------------

    ('BIODATA_INFORMANT_RELATION','SELF','Self','SELF',1),
    ('BIODATA_INFORMANT_RELATION','PARENT','Parent','PARENT',2),
    ('BIODATA_INFORMANT_RELATION','GUARDIAN','Guardian','GUARDIAN',3),
    ('BIODATA_INFORMANT_RELATION','SPOUSE','Spouse','SPOUSE',4),
    ('BIODATA_INFORMANT_RELATION','SIBLING','Sibling','SIBLING',5),
    ('BIODATA_INFORMANT_RELATION','CHILD','Child','CHILD',6),
    ('BIODATA_INFORMANT_RELATION','OTHER','Other','OTHER',7),

    -- Reliability -------------------------------------------------------

    ('BIODATA_INFORMANT_RELIABILITY','GOOD','Good','GOOD',1),
    ('BIODATA_INFORMANT_RELIABILITY','FAIR','Fair','FAIR',2),
    ('BIODATA_INFORMANT_RELIABILITY','POOR','Poor','POOR',3),
    ('BIODATA_INFORMANT_RELIABILITY','UNRELIABLE','Unreliable','UNRELIABLE',4),

    -- Pregnancy ---------------------------------------------------------

    ('BIODATA_PREGNANCY_STATUS','PREGNANT','Pregnant','PREGNANT',1),
    ('BIODATA_PREGNANCY_STATUS','NOT_PREGNANT','Not pregnant','NOT_PREGNANT',2),
    ('BIODATA_PREGNANCY_STATUS','POSSIBLE','Pregnancy possible','POSSIBLE',3),
    ('BIODATA_PREGNANCY_STATUS','UNKNOWN','Unknown','UNKNOWN',4),
    ('BIODATA_PREGNANCY_STATUS','POSTPARTUM','Postpartum','POSTPARTUM',5),

    -- LMP certainty -----------------------------------------------------

    ('BIODATA_LMP_CERTAINTY','CERTAIN','Certain','CERTAIN',1),
    ('BIODATA_LMP_CERTAINTY','UNCERTAIN','Uncertain','UNCERTAIN',2),
    ('BIODATA_LMP_CERTAINTY','UNKNOWN','Unknown','UNKNOWN',3)

) AS o(question_code, answer_code, label, value_text, sort_order)

WHERE q.question_code = o.question_code

ON CONFLICT (question_id, answer_code)
DO NOTHING;


-- ============================================================================
-- 12. QUESTION → FACT BINDINGS
-- ============================================================================

-- [RECONCILED] BODY_WEIGHT_KG binds unit 'kg', which is not part of the
-- unit catalogue registered by earlier migrations. Register the units used
-- by the biodata fact bindings so the question_fact.unit_code FK resolves.
INSERT INTO terminology.unit
    (code, label, symbol, dimension, si_unit_code)
VALUES
    ('kg', 'kilogram', 'kg', 'mass', NULL),
    ('g', 'gram', 'g', 'mass', 'kg'),
    ('mg', 'milligram', 'mg', 'mass', 'g')
ON CONFLICT (code) DO NOTHING;

INSERT INTO knowledge.question_fact
    (question_id, fact_definition_code, unit_code)

SELECT
    q.id,
    x.fact_code,
    x.unit

FROM knowledge.question q

CROSS JOIN
(
    VALUES

    ('BIODATA_PATIENT_NAME','PATIENT_NAME',NULL),
    ('BIODATA_DATE_OF_BIRTH','DATE_OF_BIRTH',NULL),
    ('BIODATA_REPORTED_AGE','REPORTED_AGE',NULL),
    ('BIODATA_OCCUPATION','OCCUPATION',NULL),
    ('BIODATA_RESIDENCE','RESIDENCE',NULL),
    ('BIODATA_COUNTY','COUNTY',NULL),
    ('BIODATA_NEXT_OF_KIN','NEXT_OF_KIN_NAME',NULL),
    ('BIODATA_NEXT_OF_KIN_PHONE','NEXT_OF_KIN_PHONE',NULL),
    ('BIODATA_LMP','LMP_DATE',NULL),
    ('BIODATA_WEIGHT','BODY_WEIGHT_KG','kg')

) AS x(question_code, fact_code, unit)

WHERE q.question_code = x.question_code

ON CONFLICT (question_id, fact_definition_code)
DO NOTHING;


-- ============================================================================
-- 13. ANSWER → FACT MAPPINGS
-- ============================================================================

INSERT INTO knowledge.fact_mapping
    (answer_option_id, fact_definition_code, value)

SELECT
    ao.id,
    x.fact_code,
    x.value

FROM knowledge.answer_option ao

JOIN knowledge.question q
    ON q.id = ao.question_id

CROSS JOIN
(
    VALUES

    ('BIODATA_SEX','MALE','SEX','MALE'),
    ('BIODATA_SEX','FEMALE','SEX','FEMALE'),
    ('BIODATA_SEX','INTERSEX','SEX','INTERSEX'),
    ('BIODATA_SEX','UNKNOWN','SEX','UNKNOWN'),

    ('BIODATA_INFORMANT_RELATION','SELF','INFORMANT_RELATION','SELF'),
    ('BIODATA_INFORMANT_RELATION','PARENT','INFORMANT_RELATION','PARENT'),
    ('BIODATA_INFORMANT_RELATION','GUARDIAN','INFORMANT_RELATION','GUARDIAN'),
    ('BIODATA_INFORMANT_RELATION','SPOUSE','INFORMANT_RELATION','SPOUSE'),
    ('BIODATA_INFORMANT_RELATION','SIBLING','INFORMANT_RELATION','SIBLING'),
    ('BIODATA_INFORMANT_RELATION','CHILD','INFORMANT_RELATION','CHILD'),
    ('BIODATA_INFORMANT_RELATION','OTHER','INFORMANT_RELATION','OTHER'),

    ('BIODATA_INFORMANT_RELIABILITY','GOOD','INFORMANT_RELIABILITY','GOOD'),
    ('BIODATA_INFORMANT_RELIABILITY','FAIR','INFORMANT_RELIABILITY','FAIR'),
    ('BIODATA_INFORMANT_RELIABILITY','POOR','INFORMANT_RELIABILITY','POOR'),
    ('BIODATA_INFORMANT_RELIABILITY','UNRELIABLE','INFORMANT_RELIABILITY','UNRELIABLE'),

    ('BIODATA_PREGNANCY_STATUS','PREGNANT','PREGNANCY_STATUS','PREGNANT'),
    ('BIODATA_PREGNANCY_STATUS','NOT_PREGNANT','PREGNANCY_STATUS','NOT_PREGNANT'),
    ('BIODATA_PREGNANCY_STATUS','POSSIBLE','PREGNANCY_STATUS','POSSIBLE'),
    ('BIODATA_PREGNANCY_STATUS','UNKNOWN','PREGNANCY_STATUS','UNKNOWN'),
    ('BIODATA_PREGNANCY_STATUS','POSTPARTUM','PREGNANCY_STATUS','POSTPARTUM'),

    ('BIODATA_LMP_CERTAINTY','CERTAIN','LMP_CERTAINTY','CERTAIN'),
    ('BIODATA_LMP_CERTAINTY','UNCERTAIN','LMP_CERTAINTY','UNCERTAIN'),
    ('BIODATA_LMP_CERTAINTY','UNKNOWN','LMP_CERTAINTY','UNKNOWN')

) AS x(question_code, answer_code, fact_code, value)

WHERE q.question_code = x.question_code
  AND ao.answer_code = x.answer_code

ON CONFLICT (answer_option_id, fact_definition_code, value)
DO NOTHING;


-- ============================================================================
-- 14. QUESTION MODULE MEMBERSHIP
-- ============================================================================

INSERT INTO knowledge.question_module_member
    (module_code, question_id, sort_order)

SELECT
    'BIODATA',
    q.id,
    q.priority

FROM knowledge.question q

WHERE q.question_code LIKE 'BIODATA_%'

ON CONFLICT (module_code, question_id)
DO NOTHING;


-- ============================================================================
-- 15. QUESTION CONTEXT
-- ============================================================================

INSERT INTO knowledge.question_context
    (question_id, context_type_code, context_value_id,
     applicability, priority)

SELECT
    q.id,
    x.context_type_code,
    cv.id,
    x.applicability,
    x.priority

FROM knowledge.question q

CROSS JOIN
(
    VALUES

    -- Pregnancy question only when reproductive context makes it relevant.
    (
      'BIODATA_PREGNANCY_STATUS',
      'REPRODUCTIVE',
      'REPRODUCTIVE_CONTEXT_RELEVANT',
      'applies',
      100
    ),

    -- LMP only when pregnancy/reproductive history is clinically relevant.
    (
      'BIODATA_LMP',
      'PREGNANCY',
      'PREGNANT',
      'applies',
      200
    ),

    (
      'BIODATA_LMP_CERTAINTY',
      'PREGNANCY',
      'PREGNANT',
      'applies',
      200
    ),

    -- Weight is particularly important in younger patients.
    (
      'BIODATA_WEIGHT',
      'AGE_BAND',
      'NEONATE',
      'applies',
      200
    ),

    (
      'BIODATA_WEIGHT',
      'AGE_BAND',
      'INFANT',
      'applies',
      200
    ),

    (
      'BIODATA_WEIGHT',
      'AGE_BAND',
      'CHILD',
      'applies',
      200
    )

) AS x(question_code, context_type_code, context_value,
       applicability, priority)

JOIN knowledge.context_value cv
    ON cv.context_type_code = x.context_type_code
   AND cv.value = x.context_value

WHERE q.question_code = x.question_code

ON CONFLICT
    (question_id, context_type_code, context_value_id)
DO NOTHING;


-- ============================================================================
-- 16. QUESTION REQUIREMENTS
-- ============================================================================

-- [RECONCILED] Migration 026 redefined knowledge.question_requirement with a
-- machine-evaluable requirement_type/requirement_code schema. The completion
-- model below (requirement_level/condition/priority) is the 008-era shape the
-- QuestionSelector and SectionEngine read. Re-add those columns so the legacy
-- requirement vocabulary coexists with 026's eligibility vocabulary.
ALTER TABLE knowledge.question_requirement
    ADD COLUMN IF NOT EXISTS requirement_level text
        CHECK (
            requirement_level IS NULL
            OR requirement_level IN (
                'mandatory',
                'conditionally_required',
                'optional',
                'informational',
                'safety'
            )
        );

ALTER TABLE knowledge.question_requirement
    ADD COLUMN IF NOT EXISTS condition jsonb;

ALTER TABLE knowledge.question_requirement
    ADD COLUMN IF NOT EXISTS priority integer NOT NULL DEFAULT 0;

INSERT INTO knowledge.question_requirement
    (question_id, requirement_type, requirement_code, required,
     requirement_level, condition, priority)

SELECT
    q.id,
    'requires_question_answer',
    q.question_code,
    x.requirement_level IN ('mandatory', 'safety'),
    x.requirement_level,
    x.condition::jsonb,
    x.priority

FROM knowledge.question q

CROSS JOIN
(
    VALUES

    ('BIODATA_PATIENT_NAME',
     'mandatory',
     NULL,
     10),

    ('BIODATA_DATE_OF_BIRTH',
     'conditionally_required',
     NULL,
     20),

    ('BIODATA_REPORTED_AGE',
     'conditionally_required',
     NULL,
     20),

    ('BIODATA_SEX',
     'mandatory',
     NULL,
     10),

    ('BIODATA_OCCUPATION',
     'conditionally_required',
     NULL,
     30),

    ('BIODATA_RESIDENCE',
     'conditionally_required',
     NULL,
     30),

    ('BIODATA_COUNTY',
     'conditionally_required',
     NULL,
     30),

    ('BIODATA_INFORMANT_RELATION',
     'mandatory',
     NULL,
     20),

    ('BIODATA_INFORMANT_RELIABILITY',
     'mandatory',
     NULL,
     20),

    ('BIODATA_NEXT_OF_KIN',
     'optional',
     NULL,
     40),

    ('BIODATA_NEXT_OF_KIN_PHONE',
     'optional',
     NULL,
     40),

    ('BIODATA_PREGNANCY_STATUS',
     'conditionally_required',
     NULL,
     50),

    ('BIODATA_LMP',
     'conditionally_required',
     NULL,
     60),

    ('BIODATA_LMP_CERTAINTY',
     'conditionally_required',
     NULL,
     60),

    ('BIODATA_WEIGHT',
     'conditionally_required',
     NULL,
     50)

) AS x(question_code, requirement_level, condition, priority)

WHERE q.question_code = x.question_code;


-- ============================================================================
-- 17. PATIENT NUMBER GENERATOR
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS patient.patient_no_seq
START WITH 1
INCREMENT BY 1
MINVALUE 1
NO CYCLE;


-- ============================================================================
-- 18. SAFETY / CONSISTENCY CHECKS
-- ============================================================================

DO $$
BEGIN

    -- Every mapped fact must exist.
    IF EXISTS (
        SELECT 1
        FROM knowledge.fact_mapping fm
        LEFT JOIN clinical.fact_definition fd
          ON fd.code = fm.fact_definition_code
        WHERE fd.code IS NULL
    ) THEN
        RAISE EXCEPTION
            'AMEXAN 043 integrity failure: fact_mapping references undefined fact_definition';
    END IF;


    -- Every question fact must exist.
    IF EXISTS (
        SELECT 1
        FROM knowledge.question_fact qf
        LEFT JOIN clinical.fact_definition fd
          ON fd.code = qf.fact_definition_code
        WHERE fd.code IS NULL
    ) THEN
        RAISE EXCEPTION
            'AMEXAN 043 integrity failure: question_fact references undefined fact_definition';
    END IF;


    -- Every context reference must resolve.
    IF EXISTS (
        SELECT 1
        FROM knowledge.question_context qc
        LEFT JOIN knowledge.context_value cv
          ON cv.id = qc.context_value_id
        WHERE cv.id IS NULL
    ) THEN
        RAISE EXCEPTION
            'AMEXAN 043 integrity failure: question_context references undefined context_value';
    END IF;

END $$;


SELECT
    'AMEXAN 043 UNIVERSAL PATIENT ENTRY + CLINICAL CONTEXT RESOLUTION SEEDED'
    AS migration_status;