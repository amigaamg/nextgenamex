-- =============================================================================
-- AMEXAN CLINICAL OPERATING SYSTEM
-- H5 — UNIVERSAL CLINICAL CONTEXT SEED
-- =============================================================================
--
-- PURPOSE
-- -------
-- Seeds the universal context vocabulary consumed by the AMEXAN CPU.
--
-- The CPU must NOT depend on hard-coded chains such as:
--
--     if age < 28 days ...
--     else if age < 1 year ...
--     else if female ...
--
-- Instead, the patient/encounter state is resolved into a CONTEXT STACK.
--
-- Example:
--
--   AGE            = CHILD
--   SEX            = FEMALE
--   REPRODUCTIVE   = REPRODUCTIVE_AGE
--   SETTING        = OPD
--   DEPARTMENT     = PEDIATRICS
--   PRESENTATION   = RESPIRATORY
--   ACUITY         = URGENT
--   ENCOUNTER      = OUTPATIENT
--
-- Questions, examination concepts, rules and workflows consume this stack.
--
-- IMPORTANT:
--   This file is KNOWLEDGE SEEDING.
--   It does not contain diagnostic reasoning.
--   It defines the universal contextual vocabulary on which the CPU reasons.
--
-- H5 UNIVERSAL CONTEXT DOMAINS
-- ----------------------------
-- 01 AGE / DEVELOPMENT
-- 02 SEX
-- 03 REPRODUCTIVE STATE
-- 04 LACTATION
-- 05 CARE SETTING
-- 06 DEPARTMENT / SERVICE
-- 07 PRESENTATION SYSTEM
-- 08 ACUITY
-- 09 ENCOUNTER DISPOSITION
-- 10 FUNCTIONAL / COGNITIVE CONTEXT
-- 11 SPECIAL CLINICAL CONTEXT
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. SAFETY / UPDATED-AT INFRASTRUCTURE
-- =============================================================================

-- The same trigger function may already exist from previous migrations.
-- CREATE OR REPLACE is intentionally used so this seed remains re-runnable.

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


-- =============================================================================
-- 1. DEVELOPMENTAL STAGES
-- =============================================================================
--
-- IMPORTANT AGE SEMANTICS
-- -----------------------
-- developmental_stage stores age boundaries in DAYS.
--
-- Canonical AMEXAN stages:
--
--   NEONATE       0–27 completed days
--   INFANT        28–364 completed days
--   CHILD         1–<12 years
--   ADOLESCENT    12–<18 years
--   ADULT         >=18 years
--
-- The database stores day boundaries because the existing schema requires
-- min_age_days / max_age_days.
--
-- The CPU should preferably calculate exact age from DOB using calendar
-- arithmetic and use these boundaries as the canonical classification.
--
-- The maximum values below are deliberately expressed as day boundaries.
--
-- 1 year  = 365 days
-- 12 years = 4380 days
-- 18 years = 6570 days
--
-- The CPU remains responsible for leap-year-aware DOB calculation.
-- =============================================================================


INSERT INTO knowledge.developmental_stage
(
    stage_code,
    label,
    min_age_days,
    max_age_days,
    sort_order,
    description
)
VALUES

(
    'NEONATE',
    'Neonate',
    0,
    27,
    1,
    'Patient from birth through 27 completed days. Neonatal physiology, examination, feeding, thermoregulation, neonatal jaundice, congenital conditions and perinatal history apply.'
),

(
    'INFANT',
    'Infant',
    28,
    364,
    2,
    'Patient from 28 completed days through less than 1 year. Infant developmental, nutritional, immunisation, feeding and age-specific clinical contexts apply.'
),

(
    'CHILD',
    'Child',
    365,
    4379,
    3,
    'Patient aged 1 year through less than 12 years. Paediatric age-specific history, examination, growth and developmental contexts apply.'
),

(
    'ADOLESCENT',
    'Adolescent',
    4380,
    6569,
    4,
    'Patient aged 12 years through less than 18 years. Adolescent developmental, psychosocial, reproductive and age-specific clinical contexts apply.'
),

(
    'ADULT',
    'Adult',
    6570,
    NULL,
    5,
    'Patient aged 18 years or older. Adult clinical history, examination and management contexts apply.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. UNIVERSAL CLINICAL CONTEXTS
-- =============================================================================
--
-- Context categories are intentionally orthogonal.
--
-- AGE is not SEX.
-- SEX is not PREGNANCY.
-- PREGNANCY is not DEPARTMENT.
-- DEPARTMENT is not PRESENTATION.
--
-- The CPU can therefore combine them without creating thousands of compound
-- contexts.
--
-- Example:
--
-- FEMALE + ADOLESCENT + PREGNANT + EMERGENCY + ABDOMINAL + OBGYN
--
-- rather than requiring a single hard-coded context such as:
--
-- "pregnant adolescent female emergency abdominal OBGYN patient".
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 2A. AGE CONTEXTS
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'AGE-NEONATE',
    'NEONATE',
    'AGE',
    'Neonate',
    'Birth through 27 completed days.',
    TRUE,
    TRUE,
    1.50
),

(
    'AGE-INFANT',
    'INFANT',
    'AGE',
    'Infant',
    '28 completed days through less than 1 year.',
    TRUE,
    TRUE,
    1.30
),

(
    'AGE-CHILD',
    'CHILD',
    'AGE',
    'Child',
    '1 year through less than 12 years.',
    TRUE,
    TRUE,
    1.20
),

(
    'AGE-ADOLESCENT',
    'ADOLESCENT',
    'AGE',
    'Adolescent',
    '12 years through less than 18 years.',
    TRUE,
    TRUE,
    1.10
),

(
    'AGE-ADULT',
    'ADULT',
    'AGE',
    'Adult',
    '18 years and older.',
    TRUE,
    TRUE,
    1.00
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2B. SEX CONTEXTS
-- -----------------------------------------------------------------------------
--
-- "SEX" is used here as the biological clinical context required by physiology,
-- reference ranges, reproductive medicine and sex-specific examination.
--
-- This is deliberately distinct from gender identity because the CPU may need
-- different clinical attributes for different clinical purposes.
--
-- Additional demographic/identity modelling belongs elsewhere in the patient
-- identity model rather than being conflated with this clinical context table.
-- -----------------------------------------------------------------------------


INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'SEX-MALE',
    'MALE',
    'SEX',
    'Male',
    'Patient with male biological/clinical sex context.',
    TRUE,
    TRUE,
    1.00
),

(
    'SEX-FEMALE',
    'FEMALE',
    'SEX',
    'Female',
    'Patient with female biological/clinical sex context.',
    TRUE,
    TRUE,
    1.00
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2C. REPRODUCTIVE CONTEXT
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'REP-PREGNANT',
    'PREGNANT',
    'REPRODUCTIVE',
    'Pregnant',
    'Patient currently pregnant. Activates pregnancy-specific history, examination, investigations and obstetric pathways.',
    TRUE,
    TRUE,
    1.50
),

(
    'REP-NOT-PREGNANT',
    'NOT_PREGNANT',
    'REPRODUCTIVE',
    'Not pregnant',
    'Patient currently not pregnant.',
    TRUE,
    TRUE,
    0.90
),

(
    'REP-REPRODUCTIVE-AGE',
    'REPRODUCTIVE_AGE',
    'REPRODUCTIVE',
    'Reproductive age',
    'Female patient in the reproductive-age clinical context. Used to determine whether pregnancy, menstrual and reproductive questions should be considered.',
    TRUE,
    TRUE,
    1.10
),

(
    'REP-POSTPARTUM',
    'POSTPARTUM',
    'REPRODUCTIVE',
    'Postpartum',
    'Patient in the postpartum period following delivery. Activates postpartum history, examination and complication surveillance.',
    TRUE,
    TRUE,
    1.40
),

(
    'REP-POSTMENOPAUSAL',
    'POSTMENOPAUSAL',
    'REPRODUCTIVE',
    'Postmenopausal',
    'Patient with established postmenopausal clinical context.',
    TRUE,
    TRUE,
    1.10
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2D. LACTATION CONTEXT
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'LACT-LACTATING',
    'LACTATING',
    'LACTATION',
    'Lactating',
    'Patient currently breastfeeding/lactating. Relevant to maternal history, breast examination, medication safety and postpartum care.',
    TRUE,
    TRUE,
    1.20
),

(
    'LACT-NOT-LACTATING',
    'NOT_LACTATING',
    'LACTATION',
    'Not lactating',
    'Patient is not currently breastfeeding/lactating.',
    TRUE,
    TRUE,
    0.80
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2E. CARE SETTING
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'SETTING-EMERGENCY',
    'EMERGENCY',
    'SETTING',
    'Emergency',
    'Encounter occurring in an emergency or acute receiving environment.',
    TRUE,
    TRUE,
    1.50
),

(
    'SETTING-OPD',
    'OPD',
    'SETTING',
    'Outpatient Department',
    'Encounter occurring in an outpatient clinic or ambulatory care setting.',
    TRUE,
    TRUE,
    1.00
),

(
    'SETTING-WARD',
    'WARD',
    'SETTING',
    'Inpatient Ward',
    'Encounter occurring during inpatient ward care.',
    TRUE,
    TRUE,
    1.10
),

(
    'SETTING-ICU',
    'ICU',
    'SETTING',
    'Intensive Care Unit',
    'Encounter occurring in an intensive care environment.',
    TRUE,
    TRUE,
    1.70
),

(
    'SETTING-THEATRE',
    'THEATRE',
    'SETTING',
    'Operating Theatre',
    'Perioperative or operative clinical environment.',
    TRUE,
    TRUE,
    1.50
),

(
    'SETTING-LABOUR-WARD',
    'LABOUR_WARD',
    'SETTING',
    'Labour Ward',
    'Obstetric labour and delivery environment.',
    TRUE,
    TRUE,
    1.50
),

(
    'SETTING-NEONATAL',
    'NEONATAL_UNIT',
    'SETTING',
    'Neonatal Unit',
    'Specialised neonatal clinical environment.',
    TRUE,
    TRUE,
    1.60
),

(
    'SETTING-PEDIATRIC',
    'PAEDIATRIC_UNIT',
    'SETTING',
    'Paediatric Unit',
    'Specialised paediatric clinical environment.',
    TRUE,
    TRUE,
    1.30
),

(
    'SETTING-TELEMEDICINE',
    'TELEMEDICINE',
    'SETTING',
    'Telemedicine',
    'Remote clinical consultation environment.',
    TRUE,
    FALSE,
    1.00
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2F. DEPARTMENT / CLINICAL SERVICE
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'DEPT-INTERNAL-MEDICINE',
    'INTERNAL_MEDICINE',
    'DEPARTMENT',
    'Internal Medicine',
    'Adult medical clinical service.',
    TRUE,
    TRUE,
    1.00
),

(
    'DEPT-PEDIATRICS',
    'PEDIATRICS',
    'DEPARTMENT',
    'Paediatrics',
    'Clinical service for children.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-OBGYN',
    'OBGYN',
    'DEPARTMENT',
    'Obstetrics and Gynaecology',
    'Obstetric and gynaecological clinical service.',
    TRUE,
    TRUE,
    1.30
),

(
    'DEPT-GENERAL-SURGERY',
    'GENERAL_SURGERY',
    'DEPARTMENT',
    'General Surgery',
    'General surgical clinical service.',
    TRUE,
    TRUE,
    1.30
),

(
    'DEPT-ORTHOPAEDICS',
    'ORTHOPAEDICS',
    'DEPARTMENT',
    'Orthopaedics',
    'Orthopaedic and musculoskeletal clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-ENT',
    'ENT',
    'DEPARTMENT',
    'Ear Nose and Throat',
    'Otorhinolaryngology clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-OPHTHALMOLOGY',
    'OPHTHALMOLOGY',
    'DEPARTMENT',
    'Ophthalmology',
    'Ophthalmic clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-DERMATOLOGY',
    'DERMATOLOGY',
    'DEPARTMENT',
    'Dermatology',
    'Dermatological clinical service.',
    TRUE,
    TRUE,
    1.10
),

(
    'DEPT-PSYCHIATRY',
    'PSYCHIATRY',
    'DEPARTMENT',
    'Psychiatry',
    'Psychiatric clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-NEUROLOGY',
    'NEUROLOGY',
    'DEPARTMENT',
    'Neurology',
    'Neurological clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-CARDIOLOGY',
    'CARDIOLOGY',
    'DEPARTMENT',
    'Cardiology',
    'Cardiovascular clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-RESPIRATORY',
    'RESPIRATORY_MEDICINE',
    'DEPARTMENT',
    'Respiratory Medicine',
    'Respiratory clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-GASTROENTEROLOGY',
    'GASTROENTEROLOGY',
    'DEPARTMENT',
    'Gastroenterology',
    'Gastrointestinal and hepatobiliary clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-NEPHROLOGY',
    'NEPHROLOGY',
    'DEPARTMENT',
    'Nephrology',
    'Renal clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-UROLOGY',
    'UROLOGY',
    'DEPARTMENT',
    'Urology',
    'Urological clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-INFECTIOUS-DISEASE',
    'INFECTIOUS_DISEASE',
    'DEPARTMENT',
    'Infectious Diseases',
    'Infectious disease clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-ONCOLOGY',
    'ONCOLOGY',
    'DEPARTMENT',
    'Oncology',
    'Cancer clinical service.',
    TRUE,
    TRUE,
    1.20
),

(
    'DEPT-ANAESTHESIA',
    'ANAESTHESIA',
    'DEPARTMENT',
    'Anaesthesia',
    'Anaesthesia and perioperative medicine.',
    TRUE,
    TRUE,
    1.30
),

(
    'DEPT-EMERGENCY-MEDICINE',
    'EMERGENCY_MEDICINE',
    'DEPARTMENT',
    'Emergency Medicine',
    'Acute and emergency clinical service.',
    TRUE,
    TRUE,
    1.50
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2G. PRESENTATION / SYMPTOM-SYSTEM CONTEXT
-- -----------------------------------------------------------------------------
--
-- These are NOT diagnoses.
--
-- They represent the presenting clinical domain and allow the CPU to activate
-- the appropriate symptom/HPI and examination pathway.
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'PRES-GENERAL',
    'GENERAL',
    'PRESENTATION',
    'General / constitutional',
    'General constitutional presentation including fever, fatigue, weight change, malaise or non-localising symptoms.',
    TRUE,
    TRUE,
    1.00
),

(
    'PRES-RESPIRATORY',
    'RESPIRATORY',
    'PRESENTATION',
    'Respiratory',
    'Respiratory presentation involving cough, dyspnoea, chest symptoms, wheeze or other respiratory complaints.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-CARDIOVASCULAR',
    'CARDIOVASCULAR',
    'PRESENTATION',
    'Cardiovascular',
    'Cardiovascular presentation including chest pain, palpitations, syncope, oedema or exercise intolerance.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-NEUROLOGICAL',
    'NEUROLOGICAL',
    'PRESENTATION',
    'Neurological',
    'Neurological presentation including headache, weakness, seizures, altered consciousness, sensory or motor symptoms.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-ABDOMINAL',
    'ABDOMINAL',
    'PRESENTATION',
    'Abdominal',
    'Abdominal or gastrointestinal presentation including abdominal pain, vomiting, diarrhoea, distension or gastrointestinal bleeding.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-GENITOURINARY',
    'GENITOURINARY',
    'PRESENTATION',
    'Genitourinary',
    'Urinary, renal or genital presentation.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-REPRODUCTIVE',
    'REPRODUCTIVE',
    'PRESENTATION',
    'Reproductive',
    'Obstetric or gynaecological presentation.',
    TRUE,
    TRUE,
    1.30
),

(
    'PRES-MUSCULOSKELETAL',
    'MUSCULOSKELETAL',
    'PRESENTATION',
    'Musculoskeletal',
    'Bone, joint, muscle, limb or movement-related presentation.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-SKIN',
    'DERMATOLOGICAL',
    'PRESENTATION',
    'Skin / dermatological',
    'Skin, hair, nail or mucocutaneous presentation.',
    TRUE,
    TRUE,
    1.10
),

(
    'PRES-ENT',
    'ENT',
    'PRESENTATION',
    'ENT',
    'Ear, nose, throat or upper-airway presentation.',
    TRUE,
    TRUE,
    1.10
),

(
    'PRES-OPHTHALMIC',
    'OPHTHALMIC',
    'PRESENTATION',
    'Ophthalmic',
    'Eye or visual presentation.',
    TRUE,
    TRUE,
    1.10
),

(
    'PRES-BREAST',
    'BREAST',
    'PRESENTATION',
    'Breast',
    'Breast-related presentation including mass, pain, discharge or skin/nipple change.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-HAEMATOLOGICAL',
    'HAEMATOLOGICAL',
    'PRESENTATION',
    'Haematological',
    'Bleeding, bruising, anaemia-related or other haematological presentation.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-MENTAL-HEALTH',
    'MENTAL_HEALTH',
    'PRESENTATION',
    'Mental health',
    'Psychological, behavioural, emotional, cognitive or psychiatric presentation.',
    TRUE,
    TRUE,
    1.20
),

(
    'PRES-PAIN',
    'PAIN',
    'PRESENTATION',
    'Pain',
    'Pain as a principal presenting symptom. The CPU should subsequently resolve anatomical site and characteristics through the symptom engine.',
    TRUE,
    TRUE,
    1.20
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2H. ACUITY CONTEXT
-- -----------------------------------------------------------------------------
--
-- Acuity is distinct from diagnosis.
--
-- A patient may have:
--
--   ACUITY = EMERGENCY
--   PRESENTATION = RESPIRATORY
--   DIAGNOSIS = UNKNOWN
--
-- The CPU must be able to prioritise immediate assessment before diagnostic
-- certainty is established.
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'ACUITY-ROUTINE',
    'ROUTINE',
    'ACUITY',
    'Routine',
    'No immediate clinical instability identified at the current stage of assessment.',
    TRUE,
    TRUE,
    0.80
),

(
    'ACUITY-URGENT',
    'URGENT',
    'ACUITY',
    'Urgent',
    'Requires prompt clinical assessment or intervention but does not currently meet the emergency context.',
    TRUE,
    TRUE,
    1.20
),

(
    'ACUITY-EMERGENCY',
    'EMERGENCY_ACUITY',
    'ACUITY',
    'Emergency',
    'Potentially life-threatening or time-critical clinical presentation requiring immediate assessment.',
    TRUE,
    TRUE,
    1.70
),

(
    'ACUITY-CRITICAL',
    'CRITICAL',
    'ACUITY',
    'Critical',
    'Critical physiological instability or immediate threat to life requiring resuscitative/critical-care response.',
    TRUE,
    TRUE,
    2.00
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2I. ENCOUNTER DISPOSITION
-- -----------------------------------------------------------------------------
--
-- This corresponds to migration 044.
-- The same vocabulary is deliberately reused rather than creating a second
-- incompatible representation.
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'ENC-INPATIENT',
    'INPATIENT',
    'ENCOUNTER',
    'Inpatient',
    'Current encounter is an inpatient/admitted encounter.',
    TRUE,
    TRUE,
    1.20
),

(
    'ENC-OUTPATIENT',
    'OUTPATIENT',
    'ENCOUNTER',
    'Outpatient',
    'Current encounter is an outpatient/review encounter.',
    TRUE,
    TRUE,
    1.00
),

(
    'ENC-EMERGENCY',
    'EMERGENCY_ENCOUNTER',
    'ENCOUNTER',
    'Emergency encounter',
    'Current encounter is being managed as an emergency encounter.',
    TRUE,
    TRUE,
    1.50
),

(
    'ENC-FOLLOWUP',
    'FOLLOW_UP',
    'ENCOUNTER',
    'Follow-up',
    'Current encounter is a planned follow-up/review of a previous clinical episode.',
    TRUE,
    TRUE,
    0.90
),

(
    'ENC-FIRST',
    'FIRST_PRESENTATION',
    'ENCOUNTER',
    'First presentation',
    'Current encounter represents the initial clinical presentation for the active problem.',
    TRUE,
    TRUE,
    1.10
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2J. FUNCTIONAL / COGNITIVE CONTEXT
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'FUNC-INDEPENDENT',
    'FUNCTIONALLY_INDEPENDENT',
    'FUNCTION',
    'Functionally independent',
    'Patient performs usual activities independently for their developmental/clinical context.',
    TRUE,
    TRUE,
    0.90
),

(
    'FUNC-DEPENDENT',
    'FUNCTIONALLY_DEPENDENT',
    'FUNCTION',
    'Functionally dependent',
    'Patient requires assistance with usual activities.',
    TRUE,
    TRUE,
    1.10
),

(
    'COG-INTACT',
    'COGNITIVELY_INTACT',
    'COGNITION',
    'Cognitively intact',
    'No current clinical evidence of altered cognition on the available assessment.',
    TRUE,
    TRUE,
    0.90
),

(
    'COG-IMPAIRED',
    'COGNITIVELY_IMPAIRED',
    'COGNITION',
    'Cognitive impairment',
    'Current cognitive impairment or altered cognition is present or documented.',
    TRUE,
    TRUE,
    1.40
),

(
    'LOC-ALERT',
    'ALERT',
    'CONSCIOUSNESS',
    'Alert',
    'Patient is clinically alert at the time of assessment.',
    TRUE,
    TRUE,
    0.90
),

(
    'LOC-ALTERED',
    'ALTERED_CONSCIOUSNESS',
    'CONSCIOUSNESS',
    'Altered consciousness',
    'Reduced or altered level of consciousness requiring appropriate neurological assessment.',
    TRUE,
    TRUE,
    1.60
)

  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2K. SPECIAL CLINICAL CONTEXTS
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES

(
    'SPECIAL-IMMUNOCOMPROMISED',
    'IMMUNOCOMPROMISED',
    'SPECIAL_CLINICAL',
    'Immunocompromised',
    'Clinical context in which immune function is impaired or clinically significant immunosuppression is present.',
    TRUE,
    TRUE,
    1.40
),

(
    'SPECIAL-CHRONIC-DISEASE',
    'CHRONIC_DISEASE',
    'SPECIAL_CLINICAL',
    'Chronic disease context',
    'Patient has a clinically relevant established chronic disease requiring context-sensitive assessment.',
    TRUE,
    TRUE,
    1.10
),

(
    'SPECIAL-PREOPERATIVE',
    'PREOPERATIVE',
    'SPECIAL_CLINICAL',
    'Preoperative',
    'Patient is undergoing preoperative clinical assessment.',
    TRUE,
    TRUE,
    1.40
),

(
    'SPECIAL-POSTOPERATIVE',
    'POSTOPERATIVE',
    'SPECIAL_CLINICAL',
    'Postoperative',
    'Patient is undergoing postoperative assessment.',
    TRUE,
    TRUE,
    1.40
),

(
    'SPECIAL-TRAUMA',
    'TRAUMA',
    'SPECIAL_CLINICAL',
    'Trauma',
    'Clinical context involving traumatic injury requiring trauma-oriented assessment.',
    TRUE,
    TRUE,
    1.50
),

(
    'SPECIAL-INFECTIOUS-RISK',
    'INFECTIOUS_RISK',
    'SPECIAL_CLINICAL',
    'Infectious risk',
    'Clinical context requiring infection-focused assessment or precautions.',
    TRUE,
    TRUE,
    1.20
),

(
    'SPECIAL-FALL-RISK',
    'FALL_RISK',
    'SPECIAL_CLINICAL',
    'Fall risk',
    'Patient has a clinically relevant risk of falls requiring appropriate assessment.',
    TRUE,
    TRUE,
    1.10
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. UPDATED_AT TRIGGERS
-- =============================================================================
--
-- PostgreSQL does not support CREATE TRIGGER IF NOT EXISTS.
-- Therefore we explicitly test pg_trigger before creating each trigger.
-- This makes the seed safely re-runnable.
-- =============================================================================


DO $$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_knowledge_developmental_stage_updated_at'
          AND tgrelid = 'knowledge.developmental_stage'::regclass
    )
    THEN
        CREATE TRIGGER trg_knowledge_developmental_stage_updated_at
        BEFORE UPDATE ON knowledge.developmental_stage
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_knowledge_clinical_context_updated_at'
          AND tgrelid = 'knowledge.clinical_context'::regclass
    )
    THEN
        CREATE TRIGGER trg_knowledge_clinical_context_updated_at
        BEFORE UPDATE ON knowledge.clinical_context
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;

END
$$;


-- =============================================================================
-- 4. DATA-INTEGRITY CHECKS
-- =============================================================================
--
-- These checks deliberately fail the migration if the foundational age
-- vocabulary becomes invalid.
-- =============================================================================


DO $$
DECLARE
    v_count integer;
BEGIN

    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.developmental_stage
    WHERE stage_code IN
    (
        'NEONATE',
        'INFANT',
        'CHILD',
        'ADOLESCENT',
        'ADULT'
    );

    IF v_count <> 5 THEN
        RAISE EXCEPTION
            'AMEXAN H5 integrity failure: expected 5 developmental stages, found %',
            v_count;
    END IF;


    IF EXISTS
    (
        SELECT 1
        FROM knowledge.developmental_stage
        WHERE min_age_days IS NULL
          AND stage_code <> 'ADULT'
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN H5 integrity failure: non-adult developmental stage has NULL minimum age.';
    END IF;


    IF EXISTS
    (
        SELECT 1
        FROM knowledge.developmental_stage
        WHERE stage_code = 'ADULT'
          AND min_age_days <> 6570
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN H5 integrity failure: ADULT minimum age is not 6570 days.';
    END IF;


    IF EXISTS
    (
        SELECT 1
        FROM knowledge.developmental_stage
        WHERE stage_code = 'CHILD'
          AND min_age_days <> 365
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN H5 integrity failure: CHILD minimum age is not 365 days.';
    END IF;


    IF EXISTS
    (
        SELECT 1
        FROM knowledge.developmental_stage
        WHERE stage_code = 'ADOLESCENT'
          AND min_age_days <> 4380
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN H5 integrity failure: ADOLESCENT minimum age is not 4380 days.';
    END IF;

END
$$;


-- =============================================================================
-- 5. CONTEXT VOCABULARY INTEGRITY CHECK
-- =============================================================================


DO $$
DECLARE
    v_count integer;
BEGIN

    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.clinical_context;

    IF v_count < 50 THEN
        RAISE EXCEPTION
            'AMEXAN H5 integrity failure: expected at least 50 universal clinical contexts, found %',
            v_count;
    END IF;

END
$$;


-- =============================================================================
-- 6. HUMAN-READABLE VERIFICATION
-- =============================================================================


SELECT
    stage_code,
    label,
    min_age_days,
    max_age_days,
    sort_order,
    description
FROM knowledge.developmental_stage
ORDER BY sort_order;


SELECT
    context_id,
    code,
    category,
    label,
    priority_weight
FROM knowledge.clinical_context
ORDER BY
    category,
    priority_weight DESC,
    label;


-- =============================================================================
-- 7. CPU-ORIENTED SUMMARY
-- =============================================================================


SELECT
    category,
    COUNT(*) AS context_count
FROM knowledge.clinical_context
GROUP BY category
ORDER BY category;


-- =============================================================================
-- 8. FINAL STATUS
-- =============================================================================


SELECT
    'AMEXAN H5 UNIVERSAL CLINICAL CONTEXT SEED COMPLETE' AS status,
    (
        SELECT COUNT(*)
        FROM knowledge.developmental_stage
    ) AS developmental_stage_count,
    (
        SELECT COUNT(*)
        FROM knowledge.clinical_context
    ) AS clinical_context_count;


COMMIT;


-- =============================================================================
-- END OF H5
-- =============================================================================