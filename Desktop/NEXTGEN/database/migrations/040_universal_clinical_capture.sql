-- =============================================================================
-- AMEXAN UNIVERSAL CLINICAL OPERATING SYSTEM
-- MIGRATION 040 â€” UNIVERSAL CLINICAL CAPTURE + CLINICAL KNOWLEDGE GRAPH
-- =============================================================================
--
-- PURPOSE
-- -------
-- This migration establishes the clinical capture layer of AMEXAN.
--
-- It is deliberately organized around the actual clinical workflow:
--
--   PATIENT
--      â†“
--   ENCOUNTER / CONTEXT
--      â†“
--   CHIEF COMPLAINT / PRESENTING PROBLEM
--      â†“
--   HISTORY
--      â†“
--   REVIEW OF SYSTEMS
--      â†“
--   PAST / DRUG / ALLERGY / FAMILY / SOCIAL / EXPOSURE HISTORY
--      â†“
--   DEVELOPMENTAL / PAEDIATRIC / NEONATAL / OBGYN CONTEXT
--      â†“
--   EXAMINATION
--      â†“
--   VITALS / ANTHROPOMETRY
--      â†“
--   INVESTIGATIONS
--      â†“
--   RESULTS / INTERPRETATION
--      â†“
--   SYNDROMES / PHENOTYPES / MECHANISMS
--      â†“
--   DIFFERENTIAL DIAGNOSIS
--      â†“
--   SEVERITY
--      â†“
--   DIAGNOSIS
--      â†“
--   PROTOCOL / GUIDELINE
--      â†“
--   MEDICATION / PRESCRIPTION / NON-PHARMACOLOGICAL MANAGEMENT
--      â†“
--   MONITORING / FOLLOW-UP / ESCALATION
--      â†“
--   DOCUMENTATION
--
-- ARCHITECTURAL LAW
-- -----------------
-- PostgreSQL = clinical vocabulary, rules, configuration, provenance and
--              durable structured clinical state.
-- CPU        = context resolution, question selection, rule evaluation,
--              scoring, protocol execution, prescription calculation,
--              documentation compilation and event processing.
-- UI         = renders CPU projections and captures clinician/patient input.
--
-- The UI MUST NOT independently decide:
--   â€¢ which questions apply
--   â€¢ which examination sections apply
--   â€¢ which diagnosis is present
--   â€¢ which drug/dose is appropriate
--   â€¢ whether a protocol applies
--   â€¢ whether a contraindication exists
--   â€¢ whether a patient should be admitted
--   â€¢ how clinical documentation should be compiled
--
-- This migration is intentionally extensible for:
--   â€¢ adult medicine
--   â€¢ paediatrics
--   â€¢ neonatology
--   â€¢ OBGYN
--   â€¢ surgery
--   â€¢ emergency medicine
--   â€¢ psychiatry
--   â€¢ orthopaedics
--   â€¢ ICU
--   â€¢ outpatient medicine
--   â€¢ inpatient medicine
--   â€¢ nursing
--   â€¢ pharmacy
--   â€¢ allied health
--
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS clinical;

COMMENT ON SCHEMA clinical IS
'AMEXAN Universal Clinical Capture Layer: patient context, history, examination, investigations, reasoning, diagnosis, protocols, prescribing, monitoring and clinical event capture.';


-- =============================================================================
-- 001. CLINICAL PATIENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.patients (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    external_id         text UNIQUE,

    date_of_birth       date,

    sex_code            text NOT NULL
        CHECK (sex_code IN (
            'MALE',
            'FEMALE',
            'INTERSEX',
            'UNKNOWN'
        )),

    blood_group_code    text
        CHECK (blood_group_code IN (
            'A_POSITIVE',
            'A_NEGATIVE',
            'B_POSITIVE',
            'B_NEGATIVE',
            'AB_POSITIVE',
            'AB_NEGATIVE',
            'O_POSITIVE',
            'O_NEGATIVE',
            'UNKNOWN'
        )),

    deceased_at         timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_patients_dob
ON clinical.patients(date_of_birth);

CREATE INDEX IF NOT EXISTS idx_clinical_patients_sex
ON clinical.patients(sex_code);


-- =============================================================================
-- 002. PATIENT IDENTIFIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.patient_identifier (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    identifier_type     text NOT NULL,
    identifier_value    text NOT NULL,

    issuing_authority   text,

    is_primary          boolean NOT NULL DEFAULT false,
    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE(identifier_type, identifier_value)
);

CREATE INDEX IF NOT EXISTS idx_clinical_patient_identifier_patient
ON clinical.patient_identifier(patient_id);


-- =============================================================================
-- 003. CLINICAL ENCOUNTER
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.encounters (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    parent_encounter_id uuid
        REFERENCES clinical.encounters(id),

    department_code     text NOT NULL,

    service_code        text,

    encounter_type      text NOT NULL DEFAULT 'OUTPATIENT'
        CHECK (encounter_type IN (
            'OUTPATIENT',
            'INPATIENT',
            'EMERGENCY',
            'TELEMEDICINE',
            'HOME',
            'WARD',
            'ICU',
            'THEATRE',
            'MATERNITY',
            'NEONATAL',
            'COMMUNITY',
            'SCREENING',
            'FOLLOW_UP',
            'OTHER'
        )),

    pregnancy_state     text NOT NULL DEFAULT 'NOT_APPLICABLE'
        CHECK (pregnancy_state IN (
            'NOT_APPLICABLE',
            'NOT_PREGNANT',
            'POSSIBLE',
            'PREGNANT',
            'POSTPARTUM'
        )),

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'PLANNED',
            'ACTIVE',
            'COMPLETED',
            'CANCELLED',
            'ABANDONED'
        )),

    started_at          timestamptz NOT NULL DEFAULT now(),
    ended_at            timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CHECK (
        ended_at IS NULL
        OR ended_at >= started_at
    )
);

CREATE INDEX IF NOT EXISTS idx_clinical_encounters_patient
ON clinical.encounters(patient_id);

CREATE INDEX IF NOT EXISTS idx_clinical_encounters_department
ON clinical.encounters(department_code);

CREATE INDEX IF NOT EXISTS idx_clinical_encounters_status
ON clinical.encounters(status);

CREATE INDEX IF NOT EXISTS idx_clinical_encounters_started
ON clinical.encounters(started_at);


-- =============================================================================
-- 004. ENCOUNTER CONTEXT VECTOR
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.encounter_context CASCADE;
CREATE TABLE IF NOT EXISTS clinical.encounter_context (
    encounter_id        uuid PRIMARY KEY
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    age_in_days         integer,
    age_in_years        numeric(8,3),

    age_band_code       text,

    sex_code            text
        CHECK (sex_code IN (
            'MALE',
            'FEMALE',
            'INTERSEX',
            'UNKNOWN'
        )),

    life_stage_code     text,

    pregnancy_state     text,

    gestational_age_weeks numeric(5,2),

    trimester_code      text
        CHECK (trimester_code IS NULL OR trimester_code IN (
            'FIRST',
            'SECOND',
            'THIRD',
            'POSTPARTUM'
        )),

    department_code     text,
    service_code        text,
    encounter_type      text,

    symptom_domain_code text,

    weight_kg           numeric(8,3),
    height_cm           numeric(8,3),
    bmi                 numeric(8,3),

    head_circumference_cm numeric(8,3),
    muac_cm             numeric(8,3),

    context_resolved_at timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CHECK (age_in_days IS NULL OR age_in_days >= 0),
    CHECK (weight_kg IS NULL OR weight_kg > 0),
    CHECK (height_cm IS NULL OR height_cm > 0),
    CHECK (head_circumference_cm IS NULL OR head_circumference_cm > 0),
    CHECK (muac_cm IS NULL OR muac_cm > 0)
);


-- =============================================================================
-- 005. CLINICAL FACT DEFINITIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.fact_definitions (
    fact_code               text PRIMARY KEY,

    label                   text NOT NULL,

    data_type               text NOT NULL
        CHECK (data_type IN (
            'TEXT',
            'CODE',
            'INTEGER',
            'DECIMAL',
            'BOOLEAN',
            'DATE',
            'DATETIME',
            'TIME',
            'QUANTITY',
            'RANGE',
            'CODE_LIST',
            'TEXT_LIST',
            'JSON'
        )),

    clinical_domain          text,

    section_code             text,

    unit_code                text,

    terminology_system       text,

    terminology_code         text,

    description              text,

    min_numeric_value        numeric,

    max_numeric_value        numeric,

    active                   boolean NOT NULL DEFAULT true,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_fact_definition_section
ON clinical.fact_definitions(section_code);

CREATE INDEX IF NOT EXISTS idx_fact_definition_domain
ON clinical.fact_definitions(clinical_domain);


-- =============================================================================
-- 006. FACT VALUE TYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.fact_value_type (
    fact_code               text PRIMARY KEY
        REFERENCES clinical.fact_definitions(fact_code)
        ON DELETE CASCADE,

    allowed_code_system     text,

    allowed_values          jsonb,

    validation_expression   text,

    normal_range            jsonb,

    critical_range          jsonb,

    required_unit_code      text,

    created_at              timestamptz NOT NULL DEFAULT now(),

    updated_at              timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 007. CAPTURED CLINICAL FACTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.facts (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id              uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id            uuid
        REFERENCES clinical.encounters(id),

    parent_fact_id          uuid
        REFERENCES clinical.facts(id),

    fact_code               text NOT NULL
        REFERENCES clinical.fact_definitions(fact_code),

    section_code            text NOT NULL,

    value_code              text,
    value_text              text,
    value_numeric           numeric,
    value_boolean           boolean,
    value_date              date,
    value_time              time,
    value_datetime          timestamptz,

    value_json              jsonb,

    unit_code               text,

    laterality_code         text
        CHECK (laterality_code IS NULL OR laterality_code IN (
            'LEFT',
            'RIGHT',
            'BILATERAL',
            'MIDLINE',
            'NOT_APPLICABLE',
            'UNKNOWN'
        )),

    anatomical_site_code    text,

    onset_at                timestamptz,
    resolution_at           timestamptz,

    source_type             text NOT NULL
        CHECK (source_type IN (
            'PATIENT_REPORTED',
            'CAREGIVER_REPORTED',
            'CLINICIAN_OBSERVED',
            'DEVICE_MEASURED',
            'LAB_MEASURED',
            'IMAGING_DERIVED',
            'SYSTEM_DERIVED'
        )),

    source_reference        text,

    certainty               text NOT NULL DEFAULT 'POSSIBLE'
        CHECK (certainty IN (
            'DEFINITE',
            'PROBABLE',
            'POSSIBLE',
            'UNCERTAIN'
        )),

    status                  text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'CORRECTED',
            'VOID',
            'SUPERSEDED'
        )),

    recorded_by             uuid,

    recorded_at             timestamptz NOT NULL DEFAULT now(),

    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),

    CHECK (
        value_code IS NOT NULL OR
        value_text IS NOT NULL OR
        value_numeric IS NOT NULL OR
        value_boolean IS NOT NULL OR
        value_date IS NOT NULL OR
        value_time IS NOT NULL OR
        value_datetime IS NOT NULL OR
        value_json IS NOT NULL
    ),

    CHECK (
        resolution_at IS NULL
        OR onset_at IS NULL
        OR resolution_at >= onset_at
    )
);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_patient
ON clinical.facts(patient_id);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_encounter
ON clinical.facts(encounter_id);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_code
ON clinical.facts(fact_code);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_encounter_code
ON clinical.facts(encounter_id, fact_code);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_patient_code
ON clinical.facts(patient_id, fact_code);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_source
ON clinical.facts(source_type);

CREATE INDEX IF NOT EXISTS idx_clinical_facts_recorded
ON clinical.facts(recorded_at);


-- =============================================================================
-- 008. FACT PROVENANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.fact_provenance (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id             uuid NOT NULL
        REFERENCES clinical.facts(id)
        ON DELETE CASCADE,

    source_type         text NOT NULL,

    source_identifier   text,

    source_claim_code   text,

    captured_by         uuid,

    captured_at         timestamptz NOT NULL DEFAULT now(),

    provenance_note     text
);

CREATE INDEX IF NOT EXISTS idx_clinical_fact_provenance_fact
ON clinical.fact_provenance(fact_id);


-- =============================================================================
-- 009. CLINICAL SECTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_sections (
    section_code        text PRIMARY KEY,

    label               text NOT NULL,

    section_group       text NOT NULL
        CHECK (section_group IN (
            'IDENTIFICATION',
            'HISTORY',
            'REVIEW_OF_SYSTEMS',
            'PAST_HISTORY',
            'MEDICATIONS',
            'ALLERGIES',
            'FAMILY_HISTORY',
            'SOCIAL_HISTORY',
            'EXPOSURE_HISTORY',
            'PAEDIATRIC',
            'NEONATAL',
            'DEVELOPMENTAL',
            'OBGYN',
            'EXAMINATION',
            'INVESTIGATION',
            'ASSESSMENT',
            'DIAGNOSIS',
            'MANAGEMENT',
            'MONITORING',
            'FOLLOW_UP',
            'DOCUMENTATION'
        )),

    sequence_no         integer NOT NULL DEFAULT 0,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_history_sections_group
ON clinical.history_sections(section_group);


-- =============================================================================
-- 010. SECTION CONTEXT RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_section_rules (
    id                  bigserial PRIMARY KEY,

    section_code        text NOT NULL
        REFERENCES clinical.history_sections(section_code)
        ON DELETE CASCADE,

    age_min_years       numeric,
    age_max_years       numeric,

    age_band_code       text,

    life_stage_code     text,

    sex_code            text,

    department_code     text,

    service_code        text,

    encounter_type      text,

    pregnancy_state     text,

    symptom_domain_code text,

    visible             boolean NOT NULL DEFAULT true,

    required            boolean NOT NULL DEFAULT false,

    locked              boolean NOT NULL DEFAULT false,

    sequence_override   integer,

    priority            integer NOT NULL DEFAULT 0,

    rationale           text,

    active              boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_section_rules_section
ON clinical.history_section_rules(section_code);

CREATE INDEX IF NOT EXISTS idx_section_rules_context
ON clinical.history_section_rules(
    age_band_code,
    sex_code,
    pregnancy_state,
    department_code,
    encounter_type
);


-- =============================================================================
-- 011. QUESTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_definitions (
    question_code       text PRIMARY KEY,

    section_code        text NOT NULL
        REFERENCES clinical.history_sections(section_code),

    question_text       text NOT NULL,

    clinical_objective  text,

    response_type       text NOT NULL
        CHECK (response_type IN (
            'YES_NO',
            'SINGLE_CHOICE',
            'MULTI_CHOICE',
            'TEXT',
            'LONG_TEXT',
            'INTEGER',
            'DECIMAL',
            'DATE',
            'DATETIME',
            'TIME',
            'QUANTITY',
            'RANGE',
            'BODY_SITE',
            'DURATION',
            'FREQUENCY',
            'SCALE',
            'FILE',
            'STRUCTURED'
        )),

    requirement_level   text NOT NULL DEFAULT 'OPTIONAL'
        CHECK (requirement_level IN (
            'MANDATORY',
            'REQUIRED_IF_APPLICABLE',
            'IMPORTANT',
            'OPTIONAL',
            'CONDITIONAL'
        )),

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    unit_code           text,

    base_priority       integer NOT NULL DEFAULT 0,

    reason              text,

    help_text           text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_questions_section
ON clinical.question_definitions(section_code);

CREATE INDEX IF NOT EXISTS idx_questions_fact
ON clinical.question_definitions(fact_code);


-- =============================================================================
-- 012. QUESTION OPTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_options (
    id                      bigserial PRIMARY KEY,

    question_code           text NOT NULL
        REFERENCES clinical.question_definitions(question_code)
        ON DELETE CASCADE,

    answer_code             text NOT NULL,

    label                   text NOT NULL,

    clinical_description    text,

    fact_value_code         text,

    fact_value_text         text,

    fact_value_numeric      numeric,

    fact_value_boolean      boolean,

    sequence_no             integer NOT NULL DEFAULT 0,

    is_exclusion            boolean NOT NULL DEFAULT false,

    is_red_flag             boolean NOT NULL DEFAULT false,

    active                  boolean NOT NULL DEFAULT true,

    UNIQUE(question_code, answer_code)
);

CREATE INDEX IF NOT EXISTS idx_question_options_question
ON clinical.question_options(question_code);


-- =============================================================================
-- 013. QUESTION CONTEXT / DEPENDENCY RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_rules (
    id                      bigserial PRIMARY KEY,

    question_code           text NOT NULL
        REFERENCES clinical.question_definitions(question_code)
        ON DELETE CASCADE,

    rule_type               text NOT NULL
        CHECK (rule_type IN (
            'CONTEXT',
            'FACT',
            'QUESTION',
            'SYMPTOM',
            'PHENOTYPE',
            'RISK',
            'RED_FLAG',
            'SAFETY',
            'TEMPORAL'
        )),

    source_question_code    text
        REFERENCES clinical.question_definitions(question_code),

    age_min_years           numeric,
    age_max_years           numeric,

    age_band_code           text,

    sex_code                text,

    life_stage_code         text,

    department_code         text,

    service_code            text,

    encounter_type          text,

    pregnancy_state         text,

    symptom_domain_code     text,

    fact_code               text
        REFERENCES clinical.fact_definitions(fact_code),

    fact_operator           text
        CHECK (
            fact_operator IS NULL OR
            fact_operator IN (
                'EQ',
                'NEQ',
                'GT',
                'GTE',
                'LT',
                'LTE',
                'IN',
                'NOT_IN',
                'EXISTS',
                'NOT_EXISTS'
            )
        ),

    fact_value_code         text,

    fact_value_text         text,

    fact_value_numeric      numeric,

    fact_value_boolean      boolean,

    priority_delta          integer NOT NULL DEFAULT 0,

    requirement_override    text
        CHECK (
            requirement_override IS NULL OR
            requirement_override IN (
                'MANDATORY',
                'REQUIRED_IF_APPLICABLE',
                'IMPORTANT',
                'OPTIONAL',
                'CONDITIONAL'
            )
        ),

    visible                 boolean NOT NULL DEFAULT true,

    reason                  text,

    active                  boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_question_rules_question
ON clinical.question_rules(question_code);

CREATE INDEX IF NOT EXISTS idx_question_rules_fact
ON clinical.question_rules(fact_code);

CREATE INDEX IF NOT EXISTS idx_question_rules_context
ON clinical.question_rules(
    age_band_code,
    sex_code,
    pregnancy_state,
    department_code
);


-- =============================================================================
-- 014. QUESTION RESPONSE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.question_response CASCADE;
CREATE TABLE IF NOT EXISTS clinical.question_response (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    question_code       text NOT NULL
        REFERENCES clinical.question_definitions(question_code),

    answer_code         text,

    response_text       text,

    response_numeric    numeric,

    response_boolean    boolean,

    response_date       date,

    response_datetime   timestamptz,

    response_json       jsonb,

    answered_by         uuid,

    source_type         text NOT NULL DEFAULT 'CLINICIAN_OBSERVED'
        CHECK (source_type IN (
            'PATIENT_REPORTED',
            'CAREGIVER_REPORTED',
            'CLINICIAN_OBSERVED',
            'DEVICE_MEASURED',
            'LAB_MEASURED',
            'IMAGING_DERIVED',
            'SYSTEM_DERIVED'
        )),

    answered_at         timestamptz NOT NULL DEFAULT now(),

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'CORRECTED',
            'VOID'
        ))
);

CREATE INDEX IF NOT EXISTS idx_question_response_encounter
ON clinical.question_response(encounter_id);

CREATE INDEX IF NOT EXISTS idx_question_response_question
ON clinical.question_response(question_code);


-- =============================================================================
-- 015. CHIEF COMPLAINT / PRESENTING PROBLEM
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.presenting_problem (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    symptom_code        text,

    problem_text        text NOT NULL,

    onset_at            timestamptz,

    chronology_text     text,

    primary_problem     boolean NOT NULL DEFAULT false,

    sequence_no         integer NOT NULL DEFAULT 0,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'RESOLVED',
            'VOID'
        )),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_presenting_problem_encounter
ON clinical.presenting_problem(encounter_id);


-- =============================================================================
-- 016. SYMPTOM CATALOGUE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.symptoms (
    symptom_code        text PRIMARY KEY,

    name                text NOT NULL,

    clinical_domain     text,

    description         text,

    canonical_question  text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS clinical.symptom_contexts (
    id                  bigserial PRIMARY KEY,

    symptom_code        text NOT NULL
        REFERENCES clinical.symptoms(symptom_code)
        ON DELETE CASCADE,

    system_code         text,

    department_code     text,

    service_code        text,

    life_stage_code     text,

    age_band_code       text,

    sex_code            text,

    pregnancy_state     text,

    priority            integer NOT NULL DEFAULT 0,

    active              boolean NOT NULL DEFAULT true,

    UNIQUE(
        symptom_code,
        system_code,
        department_code,
        life_stage_code,
        age_band_code,
        sex_code,
        pregnancy_state
    )
);


-- =============================================================================
-- 017. SYMPTOM CHARACTERISTICS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.symptom_characteristic (
    characteristic_code text PRIMARY KEY,

    name                text NOT NULL,

    description         text,

    active              boolean NOT NULL DEFAULT true
);


CREATE TABLE IF NOT EXISTS clinical.symptom_characteristic_rule (
    id                  bigserial PRIMARY KEY,

    symptom_code        text NOT NULL
        REFERENCES clinical.symptoms(symptom_code)
        ON DELETE CASCADE,

    characteristic_code text NOT NULL
        REFERENCES clinical.symptom_characteristic(characteristic_code)
        ON DELETE CASCADE,

    required             boolean NOT NULL DEFAULT false,

    sequence_no          integer NOT NULL DEFAULT 0,

    active               boolean NOT NULL DEFAULT true,

    UNIQUE(symptom_code, characteristic_code)
);


-- =============================================================================
-- 018. REVIEW OF SYSTEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.system_domains (
    system_code         text PRIMARY KEY,

    name                text NOT NULL,

    sequence_no         integer NOT NULL DEFAULT 0,

    active              boolean NOT NULL DEFAULT true
);


CREATE TABLE IF NOT EXISTS clinical.review_of_systems (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    system_code         text NOT NULL
        REFERENCES clinical.system_domains(system_code),

    finding_code        text,

    response            text,

    positive            boolean,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    recorded_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ros_encounter
ON clinical.review_of_systems(encounter_id);


-- =============================================================================
-- 019. PAST MEDICAL HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.past_medical_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    condition_code      text,

    condition_text      text NOT NULL,

    onset_date          date,

    resolved_date       date,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'RESOLVED',
            'RECURRENT',
            'UNKNOWN'
        )),

    treatment_text      text,

    complications_text  text,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pmh_patient
ON clinical.past_medical_history(patient_id);


-- =============================================================================
-- 020. PAST SURGICAL HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.past_surgical_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    procedure_code      text,

    procedure_name      text NOT NULL,

    indication          text,

    date_of_procedure   date,

    facility             text,

    complications       text,

    anaesthesia_type    text,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 021. MEDICATION HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.patient_medications (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    medication_code     text,

    medication_name     text NOT NULL,

    formulation         text,

    strength            text,

    dose                numeric,

    dose_unit           text,

    route               text,

    frequency            text,

    indication          text,

    started_at          date,

    stopped_at          date,

    adherence_status    text
        CHECK (adherence_status IS NULL OR adherence_status IN (
            'TAKING_AS_PRESCRIBED',
            'PARTIALLY_ADHERENT',
            'NOT_TAKING',
            'UNKNOWN'
        )),

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patient_medications_patient
ON clinical.patient_medications(patient_id);


-- =============================================================================
-- 022. ALLERGIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.allergies (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    allergen_code       text,

    allergen_name       text NOT NULL,

    allergy_type        text
        CHECK (allergy_type IN (
            'DRUG',
            'FOOD',
            'ENVIRONMENTAL',
            'LATEX',
            'OTHER',
            'UNKNOWN'
        )),

    reaction_type       text,

    reaction_description text,

    severity            text
        CHECK (severity IS NULL OR severity IN (
            'MILD',
            'MODERATE',
            'SEVERE',
            'ANAPHYLAXIS',
            'UNKNOWN'
        )),

    onset_date          date,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'INACTIVE',
            'UNCONFIRMED'
        )),

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_allergies_patient
ON clinical.allergies(patient_id);

CREATE INDEX IF NOT EXISTS idx_allergies_type
ON clinical.allergies(allergy_type);


-- =============================================================================
-- 023. FAMILY HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.family_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    relative_type       text NOT NULL,

    condition_code      text,

    condition_text      text NOT NULL,

    age_at_diagnosis    integer,

    deceased            boolean,

    cause_of_death      text,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 024. SOCIAL HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.social_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    smoking_status      text,

    alcohol_status      text,

    substance_use       text,

    occupation          text,

    housing             text,

    household_size      integer,

    ventilation         text,

    cooking_fuel        text,

    socioeconomic_context text,

    nutrition_context   text,

    exercise_context    text,

    sexual_health_context text,

    safeguarding_context text,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    recorded_at         timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 025. EXPOSURE HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.exposure_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    exposure_type       text NOT NULL,

    exposure_name       text,

    description         text,

    intensity           text,

    duration_text       text,

    start_date          date,

    end_date            date,

    ongoing             boolean,

    source_type         text NOT NULL DEFAULT 'PATIENT_REPORTED',

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 026. PAEDIATRIC / DEVELOPMENTAL HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.developmental_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    developmental_domain text NOT NULL,

    milestone_code      text,

    milestone_name      text NOT NULL,

    achieved            boolean,

    age_achieved_months numeric(8,2),

    regression          boolean NOT NULL DEFAULT false,

    comment             text,

    source_type         text NOT NULL DEFAULT 'CAREGIVER_REPORTED',

    recorded_at         timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 027. NEONATAL HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.neonatal_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    gestational_age_weeks numeric(5,2),

    birth_weight_kg    numeric(6,3),

    birth_length_cm   numeric(6,2),

    head_circumference_cm numeric(6,2),

    delivery_mode      text,

    delivery_place     text,

    apgar_1_min        integer,

    apgar_5_min        integer,

    apgar_10_min       integer,

    resuscitation_required boolean,

    neonatal_admission boolean,

    neonatal_complications text,

    feeding_mode       text,

    immunization_status text,

    source_type        text NOT NULL DEFAULT 'CAREGIVER_REPORTED',

    recorded_at        timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 028. OBGYN HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.obgyn_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    menarche_age_years  numeric(4,1),

    cycle_length_days   integer,

    cycle_regularity    text,

    flow_duration_days  numeric(5,2),

    dysmenorrhoea       boolean,

    lmp_date            date,

    edd_date             date,

    gravida             integer,

    para                 integer,

    term_births         integer,

    preterm_births      integer,

    abortions           integer,

    living_children     integer,

    previous_cesarean   integer,

    previous_pregnancy_complications text,

    contraceptive_method text,

    sexual_history_relevant boolean,

    fertility_history   text,

    cervical_screening_history text,

    menopause_status   text,

    menopause_age      numeric(5,2),

    source_type        text NOT NULL DEFAULT 'PATIENT_REPORTED',

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    CHECK (gravida IS NULL OR gravida >= 0),
    CHECK (para IS NULL OR para >= 0)
);

CREATE INDEX IF NOT EXISTS idx_obgyn_history_patient
ON clinical.obgyn_history(patient_id);


-- =============================================================================
-- 029. VITAL SIGN DEFINITIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.vital_definitions (
    vital_code          text PRIMARY KEY,

    label               text NOT NULL,

    unit_code           text NOT NULL,

    data_type           text NOT NULL DEFAULT 'DECIMAL',

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 030. VITAL SIGN OBSERVATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.vital_observations (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    vital_code          text NOT NULL
        REFERENCES clinical.vital_definitions(vital_code),

    value_numeric       numeric NOT NULL,

    unit_code           text NOT NULL,

    position_code       text,

    measurement_site    text,

    device_code         text,

    source_type         text NOT NULL DEFAULT 'DEVICE_MEASURED',

    measured_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vitals_encounter
ON clinical.vital_observations(encounter_id, vital_code, measured_at);


-- =============================================================================
-- 031. ANTHROPOMETRY
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.anthropometry (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    weight_kg           numeric(8,3),

    height_cm           numeric(8,3),

    bmi                 numeric(8,3),

    head_circumference_cm numeric(8,3),

    mid_upper_arm_circumference_cm numeric(8,3),

    waist_cm            numeric(8,3),

    hip_cm              numeric(8,3),

    gestational_age_weeks numeric(5,2),

    weight_for_age_z    numeric(6,3),

    height_for_age_z    numeric(6,3),

    weight_for_height_z numeric(6,3),

    bmi_for_age_z       numeric(6,3),

    head_circumference_for_age_z numeric(6,3),

    source_type         text NOT NULL DEFAULT 'DEVICE_MEASURED',

    measured_at         timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 032. EXAMINATION FINDINGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.examination_findings (
    finding_code        text PRIMARY KEY,

    name                text NOT NULL,

    system_code         text,

    examination_domain  text,

    finding_type        text NOT NULL
        CHECK (finding_type IN (
            'OBSERVATION',
            'MEASUREMENT',
            'POSITIVE_FINDING',
            'NEGATIVE_FINDING',
            'SIGN',
            'FUNCTIONAL'
        )),

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    description         text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 033. EXAMINATION RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.examination_rules (
    id                  bigserial PRIMARY KEY,

    finding_code        text NOT NULL
        REFERENCES clinical.examination_findings(finding_code)
        ON DELETE CASCADE,

    age_min_years       numeric,
    age_max_years       numeric,

    age_band_code       text,

    life_stage_code     text,

    sex_code            text,

    department_code     text,

    service_code        text,

    encounter_type      text,

    pregnancy_state     text,

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    fact_operator       text,

    fact_value_code     text,

    fact_value_numeric  numeric,

    fact_value_boolean  boolean,

    priority            integer NOT NULL DEFAULT 0,

    required            boolean NOT NULL DEFAULT false,

    red_flag            boolean NOT NULL DEFAULT false,

    rationale           text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 034. CAPTURED EXAMINATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.examination_observation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    finding_code        text NOT NULL
        REFERENCES clinical.examination_findings(finding_code),

    value_code          text,

    value_text          text,

    value_numeric       numeric,

    value_boolean       boolean,

    anatomical_site_code text,

    laterality_code     text,

    severity_code       text,

    source_type         text NOT NULL DEFAULT 'CLINICIAN_OBSERVED',

    observed_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
);

CREATE INDEX IF NOT EXISTS idx_exam_observation_encounter
ON clinical.examination_observation(encounter_id);

CREATE INDEX IF NOT EXISTS idx_exam_observation_finding
ON clinical.examination_observation(finding_code);


-- =============================================================================
-- 035. INVESTIGATION CATALOGUE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigations (
    investigation_code  text PRIMARY KEY,

    name                text NOT NULL,

    investigation_type  text NOT NULL
        CHECK (investigation_type IN (
            'LABORATORY',
            'IMAGING',
            'MICROBIOLOGY',
            'PATHOLOGY',
            'PHYSIOLOGY',
            'CARDIOLOGY',
            'ENDOSCOPY',
            'GENETIC',
            'POINT_OF_CARE',
            'OTHER'
        )),

    specimen_type       text,

    description         text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 036. INVESTIGATION PARAMETERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_parameters (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_code  text NOT NULL
        REFERENCES clinical.investigations(investigation_code)
        ON DELETE CASCADE,

    parameter_code      text NOT NULL,

    parameter_name      text NOT NULL,

    data_type           text NOT NULL,

    unit_code           text,

    reference_range     jsonb,

    critical_range     jsonb,

    sequence_no         integer NOT NULL DEFAULT 0,

    active              boolean NOT NULL DEFAULT true,

    UNIQUE(investigation_code, parameter_code)
);


-- =============================================================================
-- 037. INVESTIGATION RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_rules (
    id                  bigserial PRIMARY KEY,

    investigation_code  text NOT NULL
        REFERENCES clinical.investigations(investigation_code)
        ON DELETE CASCADE,

    condition_code      text,

    phenotype_code      text,

    mechanism_code      text,

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    fact_operator       text,

    fact_value_code     text,

    fact_value_numeric  numeric,

    weight              numeric NOT NULL DEFAULT 0,

    minimum_age_years   numeric,

    maximum_age_years   numeric,

    age_band_code       text,

    life_stage_code     text,

    pregnancy_state     text,

    department_code     text,

    urgency             text
        CHECK (urgency IS NULL OR urgency IN (
            'ROUTINE',
            'URGENT',
            'EMERGENCY'
        )),

    rationale           text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 038. INVESTIGATION ORDER
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_orders (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    investigation_code  text NOT NULL
        REFERENCES clinical.investigations(investigation_code),

    clinical_indication text,

    priority            text NOT NULL DEFAULT 'ROUTINE'
        CHECK (priority IN (
            'ROUTINE',
            'URGENT',
            'EMERGENCY'
        )),

    ordered_by          uuid,

    ordered_at          timestamptz NOT NULL DEFAULT now(),

    status              text NOT NULL DEFAULT 'ORDERED'
        CHECK (status IN (
            'ORDERED',
            'COLLECTED',
            'IN_PROGRESS',
            'COMPLETED',
            'CANCELLED',
            'REJECTED'
        ))
);

CREATE INDEX IF NOT EXISTS idx_investigation_orders_encounter
ON clinical.investigation_orders(encounter_id);


-- =============================================================================
-- 039. INVESTIGATION RESULT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_results (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id            uuid
        REFERENCES clinical.investigation_orders(id),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    investigation_code  text NOT NULL
        REFERENCES clinical.investigations(investigation_code),

    parameter_code      text,

    result_code         text,

    result_text         text,

    result_numeric      numeric,

    result_boolean      boolean,

    result_json         jsonb,

    unit_code           text,

    reference_range     jsonb,

    abnormal_flag       text,

    critical_flag       boolean NOT NULL DEFAULT false,

    interpretation     text,

    source_type         text NOT NULL DEFAULT 'LAB_MEASURED'
        CHECK (source_type IN (
            'LAB_MEASURED',
            'IMAGING_DERIVED',
            'DEVICE_MEASURED',
            'CLINICIAN_OBSERVED',
            'SYSTEM_DERIVED'
        )),

    specimen_collected_at timestamptz,

    resulted_at         timestamptz NOT NULL DEFAULT now(),

    verified_by         uuid,

    verified_at         timestamptz
);

CREATE INDEX IF NOT EXISTS idx_investigation_results_patient
ON clinical.investigation_results(patient_id);

CREATE INDEX IF NOT EXISTS idx_investigation_results_encounter
ON clinical.investigation_results(encounter_id);

CREATE INDEX IF NOT EXISTS idx_investigation_results_order
ON clinical.investigation_results(order_id);


-- =============================================================================
-- 040. PHENOTYPES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.phenotypes (
    phenotype_code      text PRIMARY KEY,

    name                text NOT NULL,

    description         text,

    clinical_domain     text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 041. PHENOTYPE EVIDENCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.phenotype_evidence (
    id                  bigserial PRIMARY KEY,

    phenotype_code      text NOT NULL
        REFERENCES clinical.phenotypes(phenotype_code)
        ON DELETE CASCADE,

    fact_code           text NOT NULL
        REFERENCES clinical.fact_definitions(fact_code),

    expected_value_code text,

    expected_value_text text,

    expected_value_boolean boolean,

    expected_value_numeric numeric,

    operator            text DEFAULT 'EQ',

    polarity            text NOT NULL
        CHECK (polarity IN (
            'SUPPORT',
            'AGAINST'
        )),

    weight              numeric NOT NULL,

    minimum_age_years   numeric,

    maximum_age_years   numeric,

    age_band_code       text,

    sex_code            text,

    department_code     text,

    rationale            text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 042. MECHANISMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.mechanisms (
    mechanism_code      text PRIMARY KEY,

    name                text NOT NULL,

    description         text,

    clinical_domain     text,

    active              boolean NOT NULL DEFAULT true
);


CREATE TABLE IF NOT EXISTS clinical.mechanism_evidence (
    id                  bigserial PRIMARY KEY,

    mechanism_code      text NOT NULL
        REFERENCES clinical.mechanisms(mechanism_code)
        ON DELETE CASCADE,

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    phenotype_code      text
        REFERENCES clinical.phenotypes(phenotype_code),

    result_interpretation_code text,

    weight              numeric NOT NULL,

    polarity            text NOT NULL
        CHECK (polarity IN (
            'SUPPORT',
            'AGAINST'
        )),

    rationale           text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 043. CONDITIONS / DIAGNOSES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.conditions (
    condition_code      text PRIMARY KEY,

    name                text NOT NULL,

    clinical_domain     text,

    department_code     text,

    description         text,

    icd_code            text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 044. CONDITION EVIDENCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.condition_evidence (
    id                  bigserial PRIMARY KEY,

    condition_code      text NOT NULL
        REFERENCES clinical.conditions(condition_code)
        ON DELETE CASCADE,

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    phenotype_code      text
        REFERENCES clinical.phenotypes(phenotype_code),

    mechanism_code      text
        REFERENCES clinical.mechanisms(mechanism_code),

    result_interpretation_code text,

    expected_value_code text,

    expected_value_text text,

    expected_value_boolean boolean,

    expected_value_numeric numeric,

    operator            text DEFAULT 'EQ',

    polarity            text NOT NULL
        CHECK (polarity IN (
            'SUPPORT',
            'AGAINST'
        )),

    weight              numeric NOT NULL,

    reason              text,

    active              boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_condition_evidence_condition
ON clinical.condition_evidence(condition_code);


-- =============================================================================
-- 045. DIFFERENTIAL DIAGNOSIS CANDIDATES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.differential_candidate (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    condition_code      text NOT NULL
        REFERENCES clinical.conditions(condition_code),

    score               numeric,

    rank                integer,

    certainty            text NOT NULL DEFAULT 'POSSIBLE'
        CHECK (certainty IN (
            'DEFINITE',
            'PROBABLE',
            'POSSIBLE',
            'UNCERTAIN'
        )),

    supporting_evidence jsonb,

    opposing_evidence  jsonb,

    information_gaps   jsonb,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'FAVOURED',
            'EXCLUDED',
            'CONFIRMED',
            'REJECTED'
        )),

    generated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ddx_encounter
ON clinical.differential_candidate(encounter_id);

CREATE INDEX IF NOT EXISTS idx_ddx_condition
ON clinical.differential_candidate(condition_code);


-- =============================================================================
-- 046. DIAGNOSIS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.diagnoses (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    condition_code      text NOT NULL
        REFERENCES clinical.conditions(condition_code),

    diagnosis_type      text NOT NULL
        CHECK (diagnosis_type IN (
            'PRESENTING',
            'WORKING',
            'DIFFERENTIAL',
            'PROVISIONAL',
            'CONFIRMED',
            'COMPLICATION',
            'COEXISTING',
            'HISTORICAL'
        )),

    certainty            text NOT NULL DEFAULT 'POSSIBLE'
        CHECK (certainty IN (
            'DEFINITE',
            'PROBABLE',
            'POSSIBLE',
            'UNCERTAIN'
        )),

    evidence_summary    text,

    diagnosed_by        uuid,

    diagnosed_at        timestamptz NOT NULL DEFAULT now(),

    active              boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_diagnoses_encounter
ON clinical.diagnoses(encounter_id);

CREATE INDEX IF NOT EXISTS idx_diagnoses_patient
ON clinical.diagnoses(patient_id);


-- =============================================================================
-- 047. SEVERITY SCORE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.severity_score (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_code          text NOT NULL UNIQUE,

    canonical_name      text NOT NULL,

    description         text,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    population          text NOT NULL DEFAULT 'BOTH',

    max_score           integer NOT NULL DEFAULT 0,

    source_claim_code   text,

    status              text NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN (
            'DRAFT',
            'ACTIVE',
            'SUPERSEDED',
            'RETIRED'
        )),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 048. SEVERITY SCORE COMPONENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.severity_score_component (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id            uuid NOT NULL
        REFERENCES clinical.severity_score(id)
        ON DELETE CASCADE,

    component_code      text NOT NULL,

    component_name      text NOT NULL,

    condition_json      jsonb NOT NULL,

    points              integer NOT NULL DEFAULT 1,

    rationale           text,

    sort_order          integer NOT NULL DEFAULT 0,

    UNIQUE(score_id, component_code)
);


-- =============================================================================
-- 049. SEVERITY SCORE INTERPRETATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.severity_score_interpretation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id            uuid NOT NULL
        REFERENCES clinical.severity_score(id)
        ON DELETE CASCADE,

    min_score           integer NOT NULL,

    max_score           integer NOT NULL,

    severity_label      text NOT NULL,

    disposition         text,

    recommendation      text,

    urgency             text,

    UNIQUE(score_id, min_score, max_score),

    CHECK(max_score >= min_score)
);


-- =============================================================================
-- 050. PATIENT SEVERITY SCORE RESULT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.severity_score_result (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    score_id            uuid NOT NULL
        REFERENCES clinical.severity_score(id),

    total_score         integer NOT NULL,

    interpretation_id   uuid
        REFERENCES clinical.severity_score_interpretation(id),

    component_results   jsonb NOT NULL,

    calculated_at       timestamptz NOT NULL DEFAULT now(),

    calculated_by       uuid,

    engine_version      text
);

CREATE INDEX IF NOT EXISTS idx_severity_result_encounter
ON clinical.severity_score_result(encounter_id);


-- =============================================================================
-- 051. PROTOCOLS / GUIDELINES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.protocols (
    protocol_code       text PRIMARY KEY,

    name                text NOT NULL,

    purpose             text,

    clinical_domain     text,

    population          text,

    jurisdiction_code   text,

    version             text NOT NULL,

    source_claim_code   text,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'DRAFT',
            'REVIEW',
            'ACTIVE',
            'SUPERSEDED',
            'RETIRED'
        )),

    effective_from      timestamptz NOT NULL DEFAULT now(),

    effective_to        timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 052. PROTOCOL CONDITIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.protocol_conditions (
    protocol_code       text NOT NULL
        REFERENCES clinical.protocols(protocol_code)
        ON DELETE CASCADE,

    condition_code      text NOT NULL
        REFERENCES clinical.conditions(condition_code),

    PRIMARY KEY(protocol_code, condition_code)
);


-- =============================================================================
-- 053. PROTOCOL ELIGIBILITY RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.protocol_rules (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    protocol_code       text NOT NULL
        REFERENCES clinical.protocols(protocol_code)
        ON DELETE CASCADE,

    rule_code           text NOT NULL,

    trigger_type        text NOT NULL
        CHECK (trigger_type IN (
            'CONDITION',
            'PHENOTYPE',
            'FACT',
            'SEVERITY',
            'CONTEXT',
            'RED_FLAG',
            'CONTRAINDICATION',
            'INVESTIGATION'
        )),

    trigger_code        text,

    condition_json      jsonb NOT NULL,

    action              text NOT NULL
        CHECK (action IN (
            'ACTIVATE',
            'BLOCK',
            'ESCALATE',
            'REQUEST_INFORMATION',
            'REQUIRE_REVIEW'
        )),

    priority            integer NOT NULL DEFAULT 0,

    rationale           text,

    active              boolean NOT NULL DEFAULT true,

    UNIQUE(protocol_code, rule_code)
);


-- =============================================================================
-- 054. PROTOCOL STEPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.protocol_steps (
    id                  bigserial PRIMARY KEY,

    protocol_code       text NOT NULL
        REFERENCES clinical.protocols(protocol_code)
        ON DELETE CASCADE,

    step_code           text NOT NULL,

    sequence_no         integer NOT NULL,

    section_code        text,

    label               text NOT NULL,

    step_type           text NOT NULL
        CHECK (step_type IN (
            'ASSESS',
            'TRIAGE',
            'SCORE',
            'INVESTIGATE',
            'INTERPRET',
            'MEDICATE',
            'PRESCRIBE',
            'MONITOR',
            'REFER',
            'ADMIT',
            'DISCHARGE',
            'EDUCATE',
            'FOLLOW_UP',
            'ESCALATE',
            'DOCUMENT',
            'ADVICE',
            'ORDER_SET'
        )),

    instruction         text NOT NULL,

    rationale           text,

    required            boolean NOT NULL DEFAULT false,

    human_authorization_required boolean NOT NULL DEFAULT false,

    active              boolean NOT NULL DEFAULT true,

    UNIQUE(protocol_code, step_code)
);


-- =============================================================================
-- 055. PROTOCOL ACTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.protocol_actions (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    protocol_step_id    bigint NOT NULL
        REFERENCES clinical.protocol_steps(id)
        ON DELETE CASCADE,

    action_type         text NOT NULL
        CHECK (action_type IN (
            'INVESTIGATE',
            'MEDICATE',
            'MONITOR',
            'EDUCATE',
            'REFER',
            'ADMIT',
            'ADVICE',
            'ORDER_SET',
            'SCORE',
            'DOCUMENT',
            'FOLLOW_UP',
            'ESCALATE'
        )),

    action_code         text,

    action_payload      jsonb NOT NULL DEFAULT '{}'::jsonb,

    priority            integer NOT NULL DEFAULT 0,

    human_authorization_required boolean NOT NULL DEFAULT false,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 056. MEDICATION CATALOGUE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.medications (
    medication_code     text PRIMARY KEY,

    generic_name        text NOT NULL,

    brand_name          text,

    formulation         text,

    dosage_form         text,

    route               text,

    strength            text,

    strength_numeric    numeric,

    strength_unit       text,

    concentration      text,

    therapeutic_class  text,

    pharmacological_class text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 057. MEDICATION INGREDIENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.medication_ingredients (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES clinical.medications(medication_code)
        ON DELETE CASCADE,

    ingredient_name     text NOT NULL,

    ingredient_code     text,

    amount_numeric      numeric,

    amount_unit         text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 058. MEDICATION INDICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.medication_indications (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES clinical.medications(medication_code)
        ON DELETE CASCADE,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    indication_code     text,

    indication_text     text,

    population          text,

    jurisdiction_code   text,

    evidence_level      text,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 059. TREATMENT RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.treatment_rules (
    id                  bigserial PRIMARY KEY,

    medication_code     text NOT NULL
        REFERENCES clinical.medications(medication_code),

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    protocol_code       text
        REFERENCES clinical.protocols(protocol_code),

    age_min_years       numeric,

    age_max_years       numeric,

    age_band_code       text,

    life_stage_code     text,

    pregnancy_state     text,

    weight_min_kg       numeric,

    weight_max_kg       numeric,

    dose_expression     text,

    dose_basis          text
        CHECK (dose_basis IS NULL OR dose_basis IN (
            'FIXED',
            'MG_PER_KG',
            'MG_PER_KG_PER_DOSE',
            'MG_PER_KG_PER_DAY',
            'MG_PER_M2',
            'MG_PER_M2_PER_DOSE',
            'MG_PER_M2_PER_DAY',
            'PERCENT',
            'UNIT_PER_KG',
            'UNIT_PER_KG_PER_DOSE',
            'UNIT_PER_KG_PER_DAY'
        )),

    dose_min            numeric,

    dose_max            numeric,

    dose_unit           text,

    frequency           text,

    frequency_code      text,

    route               text,

    duration            text,

    duration_days_min   integer,

    duration_days_max   integer,

    max_single_dose     numeric,

    max_single_dose_unit text,

    max_daily_dose      numeric,

    max_daily_dose_unit text,

    contraindication    text,

    priority            integer NOT NULL DEFAULT 0,

    jurisdiction_code   text,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_treatment_rules_medication
ON clinical.treatment_rules(medication_code);

CREATE INDEX IF NOT EXISTS idx_treatment_rules_condition
ON clinical.treatment_rules(condition_code);

CREATE INDEX IF NOT EXISTS idx_treatment_rules_protocol
ON clinical.treatment_rules(protocol_code);


-- =============================================================================
-- 060. CONTRAINDICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.medication_contraindication (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES clinical.medications(medication_code)
        ON DELETE CASCADE,

    contraindication_code text NOT NULL,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    severity            text
        CHECK (severity IS NULL OR severity IN (
            'ABSOLUTE',
            'MAJOR',
            'PRECAUTION'
        )),

    condition_json      jsonb,

    rationale           text,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 061. DRUG INTERACTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.medication_interaction (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_a_code   text NOT NULL
        REFERENCES clinical.medications(medication_code)
        ON DELETE CASCADE,

    medication_b_code   text NOT NULL
        REFERENCES clinical.medications(medication_code)
        ON DELETE CASCADE,

    interaction_type    text NOT NULL
        CHECK (interaction_type IN (
            'CONTRAINDICATED',
            'MAJOR',
            'MODERATE',
            'MINOR',
            'MONITOR'
        )),

    mechanism           text,

    clinical_effect     text,

    management         text,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true,

    CHECK (medication_a_code <> medication_b_code)
);


-- =============================================================================
-- 062. DRUG-DOSE REFERENCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.drug_dose_reference (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES clinical.medications(medication_code)
        ON DELETE CASCADE,

    population          text NOT NULL,

    indication_code     text,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    route               text NOT NULL,

    dose_expression     text NOT NULL,

    dose_basis          text,

    dose_min            numeric,

    dose_max            numeric,

    dose_unit           text,

    frequency           text,

    frequency_code      text,

    duration_expression text,

    max_single_dose     numeric,

    max_single_dose_unit text,

    max_daily_dose      numeric,

    max_daily_dose_unit text,

    weight_min_kg       numeric,

    weight_max_kg       numeric,

    age_min_years       numeric,

    age_max_years       numeric,

    gestational_age_min_weeks numeric,

    gestational_age_max_weeks numeric,

    trimester_code      text,

    jurisdiction_code   text NOT NULL DEFAULT 'JUR-GLOBAL',

    source_claim_code   text,

    evidence_level      text,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'DRAFT',
            'ACTIVE',
            'SUPERSEDED',
            'RETIRED'
        )),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        medication_code,
        population,
        indication_code,
        route,
        jurisdiction_code
    )
);


-- =============================================================================
-- 063. PRESCRIPTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.prescriptions (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    medication_code     text NOT NULL
        REFERENCES clinical.medications(medication_code),

    indication_code     text,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    dose_numeric        numeric,

    dose_unit           text,

    calculated_dose     numeric,

    calculated_dose_unit text,

    frequency_code      text,

    frequency_text      text,

    route               text NOT NULL,

    formulation         text,

    quantity_numeric    numeric,

    quantity_unit       text,

    duration_days       numeric,

    duration_text       text,

    dose_expression     text,

    weight_used_kg      numeric,

    bsa_used_m2         numeric,

    renal_adjustment    jsonb,

    hepatic_adjustment  jsonb,

    dose_calculation    jsonb,

    safety_check        jsonb,

    instruction_text    text,

    prescription_status text NOT NULL DEFAULT 'DRAFT'
        CHECK (prescription_status IN (
            'DRAFT',
            'PENDING_REVIEW',
            'AUTHORIZED',
            'DISPENSED',
            'STARTED',
            'COMPLETED',
            'CANCELLED',
            'REJECTED'
        )),

    prescribed_by       uuid,

    authorized_by       uuid,

    prescribed_at       timestamptz NOT NULL DEFAULT now(),

    authorized_at       timestamptz,

    started_at          timestamptz,

    completed_at        timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prescriptions_patient
ON clinical.prescriptions(patient_id);

CREATE INDEX IF NOT EXISTS idx_prescriptions_encounter
ON clinical.prescriptions(encounter_id);

CREATE INDEX IF NOT EXISTS idx_prescriptions_medication
ON clinical.prescriptions(medication_code);


-- =============================================================================
-- 064. PRESCRIPTION SAFETY CHECK
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.prescription_safety_check (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_id     uuid NOT NULL
        REFERENCES clinical.prescriptions(id)
        ON DELETE CASCADE,

    check_type          text NOT NULL
        CHECK (check_type IN (
            'ALLERGY',
            'CONTRAINDICATION',
            'INTERACTION',
            'DUPLICATION',
            'DOSE',
            'WEIGHT',
            'AGE',
            'PREGNANCY',
            'RENAL',
            'HEPATIC',
            'MAX_DAILY_DOSE',
            'MAX_SINGLE_DOSE',
            'ROUTE',
            'FORMULATION',
            'JURISDICTION',
            'PROTOCOL'
        )),

    result              text NOT NULL
        CHECK (result IN (
            'PASS',
            'WARN',
            'FAIL',
            'NOT_EVALUATED'
        )),

    severity            text
        CHECK (severity IS NULL OR severity IN (
            'LOW',
            'MODERATE',
            'HIGH',
            'CRITICAL'
        )),

    message             text,

    evidence_json       jsonb,

    evaluated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prescription_safety_prescription
ON clinical.prescription_safety_check(prescription_id);


-- =============================================================================
-- 065. MEDICATION ADMINISTRATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.medication_administration (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_id     uuid NOT NULL
        REFERENCES clinical.prescriptions(id),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    scheduled_at        timestamptz,

    administered_at     timestamptz,

    dose_numeric        numeric,

    dose_unit           text,

    route               text,

    administration_site text,

    status              text NOT NULL
        CHECK (status IN (
            'SCHEDULED',
            'GIVEN',
            'HELD',
            'REFUSED',
            'MISSED',
            'CANCELLED'
        )),

    reason              text,

    administered_by     uuid,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_admin_patient
ON clinical.medication_administration(patient_id);

CREATE INDEX IF NOT EXISTS idx_med_admin_prescription
ON clinical.medication_administration(prescription_id);


-- =============================================================================
-- 066. MONITORING RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.monitoring_rules (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    monitoring_code     text NOT NULL UNIQUE,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    protocol_code       text
        REFERENCES clinical.protocols(protocol_code),

    medication_code     text
        REFERENCES clinical.medications(medication_code),

    parameter_code      text NOT NULL,

    interval_expression text,

    target_range        jsonb,

    alert_range         jsonb,

    critical_range      jsonb,

    action_if_abnormal  text,

    escalation_level    text,

    population          text,

    jurisdiction_code   text,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- 067. MONITORING OBSERVATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.monitoring_observation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    monitoring_code     text
        REFERENCES clinical.monitoring_rules(monitoring_code),

    parameter_code      text NOT NULL,

    value_numeric       numeric,

    value_text          text,

    value_boolean       boolean,

    unit_code           text,

    abnormal_flag       text,

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
);

CREATE INDEX IF NOT EXISTS idx_monitoring_patient
ON clinical.monitoring_observation(patient_id);

CREATE INDEX IF NOT EXISTS idx_monitoring_encounter
ON clinical.monitoring_observation(encounter_id);


-- =============================================================================
-- 068. REFERRAL
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.referrals (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    from_department_code text,

    to_department_code   text,

    specialty_code       text,

    urgency              text
        CHECK (urgency IN (
            'ROUTINE',
            'URGENT',
            'EMERGENCY'
        )),

    reason               text NOT NULL,

    clinical_summary     text,

    requested_at         timestamptz NOT NULL DEFAULT now(),

    requested_by         uuid,

    status               text NOT NULL DEFAULT 'REQUESTED'
        CHECK (status IN (
            'REQUESTED',
            'ACCEPTED',
            'DECLINED',
            'COMPLETED',
            'CANCELLED'
        ))
);


-- =============================================================================
-- 069. ADMISSION / DISPOSITION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.disposition CASCADE;
CREATE TABLE IF NOT EXISTS clinical.disposition (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    disposition_type    text NOT NULL
        CHECK (disposition_type IN (
            'DISCHARGE_HOME',
            'ADMIT',
            'TRANSFER',
            'REFERRAL',
            'OBSERVATION',
            'ICU',
            'THEATRE',
            'DEATH'
        )),

    destination         text,

    rationale            text,

    instructions         text,

    follow_up_required  boolean NOT NULL DEFAULT false,

    follow_up_interval  text,

    decided_by          uuid,

    decided_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 070. FOLLOW-UP PLAN
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.follow_up_plan CASCADE;
CREATE TABLE IF NOT EXISTS clinical.follow_up_plan (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    follow_up_type      text NOT NULL,

    interval_expression text,

    target_date         date,

    purpose             text,

    investigations      jsonb,

    warning_signs       jsonb,

    escalation_instructions text,

    responsible_service text,

    status              text NOT NULL DEFAULT 'PLANNED'
        CHECK (status IN (
            'PLANNED',
            'DUE',
            'COMPLETED',
            'MISSED',
            'CANCELLED'
        )),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 071. CLINICAL DOCUMENTATION RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.documentation_rules (
    id                  bigserial PRIMARY KEY,

    section_code        text NOT NULL,

    fact_code           text
        REFERENCES clinical.fact_definitions(fact_code),

    symptom_code        text,

    finding_code        text,

    condition_code      text
        REFERENCES clinical.conditions(condition_code),

    template            text NOT NULL,

    clinical_narrative_position text,

    sequence_no         integer NOT NULL DEFAULT 0,

    age_min_years       numeric,

    age_max_years       numeric,

    age_band_code       text,

    life_stage_code     text,

    sex_code            text,

    department_code     text,

    pregnancy_state     text,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_documentation_rules_section
ON clinical.documentation_rules(section_code);


-- =============================================================================
-- 072. DOCUMENTATION CAPTURE PROJECTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.document_section_state (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    section_code        text NOT NULL,

    state               text NOT NULL
        CHECK (state IN (
            'HIDDEN',
            'LOCKED',
            'AVAILABLE',
            'ACTIVE',
            'COMPLETE'
        )),

    completeness        numeric(5,2) NOT NULL DEFAULT 0
        CHECK (completeness BETWEEN 0 AND 100),

    sequence_no         integer NOT NULL DEFAULT 0,

    calculated_at       timestamptz NOT NULL DEFAULT now(),

    UNIQUE(encounter_id, section_code)
);


-- =============================================================================
-- 073. KNOWLEDGE SOURCES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.provenance_sources (
    source_code         text PRIMARY KEY,

    title               text NOT NULL,

    author              text,

    edition             text,

    chapter             text,

    section             text,

    publisher           text,

    publication_year    integer,

    source_type         text NOT NULL
        CHECK (source_type IN (
            'TEXTBOOK',
            'GUIDELINE',
            'PROTOCOL',
            'SYSTEMATIC_REVIEW',
            'META_ANALYSIS',
            'TRIAL',
            'CONSENSUS',
            'REGULATORY',
            'FORMULARY',
            'LOCAL_POLICY',
            'OTHER'
        )),

    jurisdiction_code   text,

    citation            text,

    url                 text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 074. KNOWLEDGE CLAIMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.knowledge_claims (
    claim_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_code         text NOT NULL
        REFERENCES clinical.provenance_sources(source_code),

    claim_type          text NOT NULL,

    subject_code        text NOT NULL,

    predicate            text NOT NULL,

    object_code         text,

    object_text         text,

    weight              numeric,

    certainty           text,

    evidence_level      text,

    page_reference      text,

    chapter_reference   text,

    extraction_version  text,

    verified            boolean NOT NULL DEFAULT false,

    verified_by         text,

    verified_at         timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_claims_subject
ON clinical.knowledge_claims(subject_code);

CREATE INDEX IF NOT EXISTS idx_claims_source
ON clinical.knowledge_claims(source_code);

CREATE INDEX IF NOT EXISTS idx_claims_type
ON clinical.knowledge_claims(claim_type);


-- =============================================================================
-- 075. CLINICAL EVENTS â€” EVENT SOURCING
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.events (
    event_id            bigserial PRIMARY KEY,

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    event_type          text NOT NULL,

    entity_type         text,

    entity_id           uuid,

    payload             jsonb NOT NULL,

    occurred_at         timestamptz NOT NULL DEFAULT now(),

    actor_id            uuid,

    actor_type          text
        CHECK (actor_type IS NULL OR actor_type IN (
            'PATIENT',
            'CAREGIVER',
            'CLINICIAN',
            'SYSTEM',
            'DEVICE',
            'LAB',
            'API'
        )),

    idempotency_key     uuid UNIQUE,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_encounter
ON clinical.events(encounter_id, event_id);

CREATE INDEX IF NOT EXISTS idx_events_patient
ON clinical.events(patient_id, event_id);

CREATE INDEX IF NOT EXISTS idx_events_entity
ON clinical.events(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_events_payload
ON clinical.events USING GIN(payload);


-- =============================================================================
-- 076. CLINICAL TIMELINE
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.timeline_event (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    event_type          text NOT NULL,

    event_code          text,

    event_time          timestamptz NOT NULL,

    end_time            timestamptz,

    description         text,

    source_entity_type  text,

    source_entity_id    uuid,

    source_type         text,

    created_at          timestamptz NOT NULL DEFAULT now(),

    CHECK (
        end_time IS NULL
        OR end_time >= event_time
    )
);

CREATE INDEX IF NOT EXISTS idx_timeline_patient_time
ON clinical.timeline_event(patient_id, event_time);

CREATE INDEX IF NOT EXISTS idx_timeline_encounter_time
ON clinical.timeline_event(encounter_id, event_time);


-- =============================================================================
-- 077. CLINICAL INFORMATION GAPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.information_gap (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    gap_code            text NOT NULL,

    domain              text NOT NULL,

    question_code       text,

    description         text NOT NULL,

    importance          text NOT NULL
        CHECK (importance IN (
            'LOW',
            'MEDIUM',
            'HIGH',
            'CRITICAL'
        )),

    reason              text,

    resolution_status   text NOT NULL DEFAULT 'OPEN'
        CHECK (resolution_status IN (
            'OPEN',
            'ASKED',
            'ANSWERED',
            'CLOSED',
            'NOT_APPLICABLE'
        )),

    created_at          timestamptz NOT NULL DEFAULT now(),

    resolved_at         timestamptz
);

CREATE INDEX IF NOT EXISTS idx_information_gap_encounter
ON clinical.information_gap(encounter_id);

CREATE INDEX IF NOT EXISTS idx_information_gap_status
ON clinical.information_gap(resolution_status);


-- =============================================================================
-- 078. CLINICAL ALERTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.alert (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    alert_code          text NOT NULL,

    alert_type          text NOT NULL
        CHECK (alert_type IN (
            'RED_FLAG',
            'SAFETY',
            'ALLERGY',
            'CONTRAINDICATION',
            'DRUG_INTERACTION',
            'CRITICAL_RESULT',
            'CLINICAL_DETERIORATION',
            'PROTOCOL',
            'DOCUMENTATION',
            'FOLLOW_UP'
        )),

    severity            text NOT NULL
        CHECK (severity IN (
            'LOW',
            'MODERATE',
            'HIGH',
            'CRITICAL'
        )),

    title               text NOT NULL,

    message             text NOT NULL,

    evidence_json       jsonb,

    action_required     boolean NOT NULL DEFAULT true,

    acknowledged        boolean NOT NULL DEFAULT false,

    acknowledged_by    uuid,

    acknowledged_at    timestamptz,

    resolved            boolean NOT NULL DEFAULT false,

    resolved_at        timestamptz,

    created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_alert_patient
ON clinical.alert(patient_id);

CREATE INDEX IF NOT EXISTS idx_alert_encounter
ON clinical.alert(encounter_id);

CREATE INDEX IF NOT EXISTS idx_alert_active
ON clinical.alert(resolved, acknowledged);


-- =============================================================================
-- 079. CLINICAL DECISION / RULE EXECUTION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.rule_execution CASCADE;
CREATE TABLE IF NOT EXISTS clinical.rule_execution (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    rule_type            text NOT NULL,

    rule_code            text NOT NULL,

    knowledge_version    text,

    input_facts          jsonb NOT NULL DEFAULT '{}'::jsonb,

    context_snapshot     jsonb NOT NULL DEFAULT '{}'::jsonb,

    output               jsonb NOT NULL DEFAULT '{}'::jsonb,

    decision             text,

    executed_at          timestamptz NOT NULL DEFAULT now(),

    engine_version       text,

    correlation_id       uuid
);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_execution_encounter
ON clinical.rule_execution(encounter_id);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_execution_rule
ON clinical.rule_execution(rule_code);


-- =============================================================================
-- 080. CLINICAL CAPTURE SESSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.capture_session (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid NOT NULL
        REFERENCES clinical.encounters(id)
        ON DELETE CASCADE,

    session_type        text NOT NULL
        CHECK (session_type IN (
            'HISTORY',
            'EXAMINATION',
            'INVESTIGATION',
            'ASSESSMENT',
            'MANAGEMENT',
            'PRESCRIPTION',
            'DOCUMENTATION',
            'FULL_CLERKING'
        )),

    started_at          timestamptz NOT NULL DEFAULT now(),

    ended_at            timestamptz,

    active_section_code text,

    current_question_code text,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'ACTIVE',
            'PAUSED',
            'COMPLETED',
            'ABANDONED'
        )),

    context_snapshot    jsonb,

    created_by          uuid
);


-- =============================================================================
-- 081. CLINICAL CAPTURE ACTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.capture_action (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    session_id          uuid NOT NULL
        REFERENCES clinical.capture_session(id)
        ON DELETE CASCADE,

    action_type         text NOT NULL
        CHECK (action_type IN (
            'QUESTION_PRESENTED',
            'QUESTION_ANSWERED',
            'FACT_CAPTURED',
            'FACT_CORRECTED',
            'SECTION_OPENED',
            'SECTION_COMPLETED',
            'EXAM_CAPTURED',
            'INVESTIGATION_ORDERED',
            'RESULT_RECEIVED',
            'DIAGNOSIS_UPDATED',
            'PROTOCOL_ACTIVATED',
            'PRESCRIPTION_CREATED',
            'ALERT_GENERATED',
            'DOCUMENT_GENERATED'
        )),

    entity_type         text,

    entity_id           uuid,

    payload             jsonb,

    occurred_at         timestamptz NOT NULL DEFAULT now(),

    actor_id            uuid
);

CREATE INDEX IF NOT EXISTS idx_capture_action_session
ON clinical.capture_action(session_id, occurred_at);


-- =============================================================================
-- 082. CLINICAL KNOWLEDGE OBJECT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.knowledge_object (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    object_code         text NOT NULL UNIQUE,

    object_type         text NOT NULL
        CHECK (object_type IN (
            'FACT',
            'QUESTION',
            'SYMPTOM',
            'PHENOTYPE',
            'MECHANISM',
            'CONDITION',
            'INVESTIGATION',
            'INTERPRETATION',
            'PROTOCOL',
            'MEDICATION',
            'DOSING_RULE',
            'MONITORING_RULE',
            'DOCUMENTATION_RULE',
            'SEVERITY_SCORE'
        )),

    canonical_name      text NOT NULL,

    description         text,

    source_claim_code   text,

    status              text NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN (
            'DRAFT',
            'REVIEW',
            'APPROVED',
            'ACTIVE',
            'SUPERSEDED',
            'RETIRED'
        )),

    jurisdiction_code   text DEFAULT 'JUR-GLOBAL',

    population_code     text,

    evidence_level      text,

    effective_from      date,

    effective_to        date,

    created_at          timestamptz NOT NULL DEFAULT now(),

    updated_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 083. KNOWLEDGE RELATIONSHIPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.knowledge_relationship (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    from_object_code    text NOT NULL
        REFERENCES clinical.knowledge_object(object_code)
        ON DELETE CASCADE,

    to_object_code      text NOT NULL
        REFERENCES clinical.knowledge_object(object_code)
        ON DELETE CASCADE,

    relationship_type   text NOT NULL
        CHECK (relationship_type IN (
            'SUPPORTS',
            'OPPOSES',
            'CAUSES',
            'PRESENTS_AS',
            'SUGGESTS',
            'REQUIRES',
            'TRIGGERS',
            'INVESTIGATES',
            'TREATS',
            'MONITORS',
            'DOCUMENTS',
            'CONTRAINDICATES',
            'PRECEDES',
            'DERIVED_FROM'
        )),

    weight              numeric NOT NULL DEFAULT 1,

    source_claim_code   text,

    active              boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE(
        from_object_code,
        to_object_code,
        relationship_type
    )
);


-- =============================================================================
-- 084. CLINICAL PROVENANCE LINKS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.provenance_link (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_type         text NOT NULL,

    source_code         text,

    source_claim_id     uuid,

    target_type         text NOT NULL,

    target_id           uuid,

    target_code         text,

    relationship_type   text NOT NULL,

    evidence_level      text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_provenance_link_target
ON clinical.provenance_link(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_provenance_link_source
ON clinical.provenance_link(source_type, source_code);


-- =============================================================================
-- 085. CLINICAL VERSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.knowledge_version (
    version_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    version_code        text NOT NULL UNIQUE,

    knowledge_version   text NOT NULL,

    protocol_version    text,

    formulary_version   text,

    ruleset_version     text,

    engine_version      text,

    jurisdiction_code   text,

    effective_from      date,

    effective_to        date,

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN (
            'DRAFT',
            'ACTIVE',
            'SUPERSEDED',
            'RETIRED'
        )),

    change_note         text,

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 086. CLINICAL SNAPSHOT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.snapshot (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    knowledge_version_code text,

    captured_at         timestamptz NOT NULL DEFAULT now(),

    context_state       jsonb,

    fact_state          jsonb,

    examination_state   jsonb,

    investigation_state jsonb,

    reasoning_state     jsonb,

    treatment_state     jsonb,

    prescription_state  jsonb,

    input_fingerprint   text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_snapshot_patient
ON clinical.snapshot(patient_id);

CREATE INDEX IF NOT EXISTS idx_clinical_snapshot_encounter
ON clinical.snapshot(encounter_id);


-- =============================================================================
-- 087. CLINICAL AUDIT EVENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.audit_event (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid
        REFERENCES clinical.patients(id),

    encounter_id        uuid
        REFERENCES clinical.encounters(id),

    event_type          text NOT NULL,

    actor_type          text NOT NULL
        CHECK (actor_type IN (
            'CLINICIAN',
            'SYSTEM',
            'PATIENT',
            'CAREGIVER',
            'DEVICE',
            'LAB',
            'API'
        )),

    actor_id            uuid,

    entity_type         text,

    entity_id           uuid,

    previous_value      jsonb,

    new_value           jsonb,

    correlation_id      uuid,

    occurred_at         timestamptz NOT NULL DEFAULT now(),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_audit_patient
ON clinical.audit_event(patient_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_clinical_audit_encounter
ON clinical.audit_event(encounter_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_clinical_audit_entity
ON clinical.audit_event(entity_type, entity_id);


-- =============================================================================
-- 088. UNIVERSAL CAPTURE VIEWS
-- =============================================================================

CREATE OR REPLACE VIEW clinical.v_current_encounter_context AS
SELECT
    e.id AS encounter_id,
    e.patient_id,
    e.department_code,
    e.service_code,
    e.encounter_type,
    e.pregnancy_state,
    e.status,
    p.date_of_birth,
    p.sex_code,
    c.age_in_days,
    c.age_in_years,
    c.age_band_code,
    c.life_stage_code,
    c.gestational_age_weeks,
    c.trimester_code,
    c.symptom_domain_code,
    c.weight_kg,
    c.height_cm,
    c.bmi,
    c.muac_cm
FROM clinical.encounters e
JOIN clinical.patients p
    ON p.id = e.patient_id
LEFT JOIN clinical.encounter_context c
    ON c.encounter_id = e.id;


CREATE OR REPLACE VIEW clinical.v_active_clinical_facts AS
SELECT
    f.id,
    f.patient_id,
    f.encounter_id,
    f.fact_code,
    fd.label,
    fd.data_type,
    f.section_code,
    f.value_code,
    f.value_text,
    f.value_numeric,
    f.value_boolean,
    f.value_date,
    f.value_time,
    f.value_datetime,
    f.value_json,
    f.unit_code,
    f.source_type,
    f.certainty,
    f.recorded_at
FROM clinical.facts f
JOIN clinical.fact_definitions fd
    ON fd.fact_code = f.fact_code
WHERE f.status = 'ACTIVE';


CREATE OR REPLACE VIEW clinical.v_active_diagnoses AS
SELECT
    d.id,
    d.patient_id,
    d.encounter_id,
    d.condition_code,
    c.name AS condition_name,
    d.diagnosis_type,
    d.certainty,
    d.evidence_summary,
    d.diagnosed_at
FROM clinical.diagnoses d
JOIN clinical.conditions c
    ON c.condition_code = d.condition_code
WHERE d.active = true;


CREATE OR REPLACE VIEW clinical.v_active_prescriptions AS
SELECT
    p.id,
    p.patient_id,
    p.encounter_id,
    p.medication_code,
    m.generic_name,
    m.formulation,
    m.strength,
    p.dose_numeric,
    p.dose_unit,
    p.calculated_dose,
    p.calculated_dose_unit,
    p.frequency_code,
    p.frequency_text,
    p.route,
    p.duration_days,
    p.quantity_numeric,
    p.quantity_unit,
    p.prescription_status,
    p.prescribed_at
FROM clinical.prescriptions p
JOIN clinical.medications m
    ON m.medication_code = p.medication_code
WHERE p.prescription_status NOT IN ('CANCELLED','REJECTED');


-- =============================================================================
-- 089. UPDATED_AT TRIGGERS
-- =============================================================================

DROP TRIGGER IF EXISTS trg_clinical_patients_updated_at
ON clinical.patients;

CREATE TRIGGER trg_clinical_patients_updated_at
BEFORE UPDATE ON clinical.patients
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_encounters_updated_at
ON clinical.encounters;

CREATE TRIGGER trg_clinical_encounters_updated_at
BEFORE UPDATE ON clinical.encounters
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_context_updated_at
ON clinical.encounter_context;

CREATE TRIGGER trg_clinical_context_updated_at
BEFORE UPDATE ON clinical.encounter_context
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_fact_definitions_updated_at
ON clinical.fact_definitions;

CREATE TRIGGER trg_clinical_fact_definitions_updated_at
BEFORE UPDATE ON clinical.fact_definitions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_facts_updated_at
ON clinical.facts;

CREATE TRIGGER trg_clinical_facts_updated_at
BEFORE UPDATE ON clinical.facts
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_medications_updated_at
ON clinical.medications;

CREATE TRIGGER trg_clinical_medications_updated_at
BEFORE UPDATE ON clinical.medications
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_protocols_updated_at
ON clinical.protocols;

CREATE TRIGGER trg_clinical_protocols_updated_at
BEFORE UPDATE ON clinical.protocols
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_conditions_updated_at
ON clinical.conditions;

CREATE TRIGGER trg_clinical_conditions_updated_at
BEFORE UPDATE ON clinical.conditions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_severity_score_updated_at
ON clinical.severity_score;

CREATE TRIGGER trg_clinical_severity_score_updated_at
BEFORE UPDATE ON clinical.severity_score
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 090. CLINICAL INTEGRITY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_facts_temporal
ON clinical.facts(patient_id, recorded_at);

CREATE INDEX IF NOT EXISTS idx_facts_section
ON clinical.facts(encounter_id, section_code);

CREATE INDEX IF NOT EXISTS idx_exam_temporal
ON clinical.examination_observation(encounter_id, observed_at);

CREATE INDEX IF NOT EXISTS idx_results_temporal
ON clinical.investigation_results(patient_id, resulted_at);

CREATE INDEX IF NOT EXISTS idx_prescription_status
ON clinical.prescriptions(patient_id, prescription_status);

CREATE INDEX IF NOT EXISTS idx_protocol_status
ON clinical.protocols(status);

CREATE INDEX IF NOT EXISTS idx_medication_active
ON clinical.medications(active);

CREATE INDEX IF NOT EXISTS idx_condition_active
ON clinical.conditions(active);

CREATE INDEX IF NOT EXISTS idx_question_active
ON clinical.question_definitions(active);

CREATE INDEX IF NOT EXISTS idx_investigation_active
ON clinical.investigations(active);


-- =============================================================================
-- 091. CAPTURE INTEGRITY FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION clinical.validate_fact_value_type()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    expected_type text;
BEGIN
    SELECT data_type
    INTO expected_type
    FROM clinical.fact_definitions
    WHERE fact_code = NEW.fact_code;

    IF expected_type IS NULL THEN
        RAISE EXCEPTION
            'Unknown clinical fact definition: %',
            NEW.fact_code;
    END IF;

    IF expected_type = 'BOOLEAN'
       AND NEW.value_boolean IS NULL THEN
        RAISE EXCEPTION
            'Fact % requires BOOLEAN value',
            NEW.fact_code;
    END IF;

    IF expected_type IN ('INTEGER','DECIMAL','QUANTITY')
       AND NEW.value_numeric IS NULL THEN
        RAISE EXCEPTION
            'Fact % requires numeric value',
            NEW.fact_code;
    END IF;

    IF expected_type IN ('TEXT','CODE')
       AND NEW.value_text IS NULL
       AND NEW.value_code IS NULL THEN
        RAISE EXCEPTION
            'Fact % requires text/code value',
            NEW.fact_code;
    END IF;

    IF expected_type = 'DATE'
       AND NEW.value_date IS NULL THEN
        RAISE EXCEPTION
            'Fact % requires date value',
            NEW.fact_code;
    END IF;

    IF expected_type = 'DATETIME'
       AND NEW.value_datetime IS NULL THEN
        RAISE EXCEPTION
            'Fact % requires datetime value',
            NEW.fact_code;
    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_validate_clinical_fact_value
ON clinical.facts;

CREATE TRIGGER trg_validate_clinical_fact_value
BEFORE INSERT OR UPDATE ON clinical.facts
FOR EACH ROW
EXECUTE FUNCTION clinical.validate_fact_value_type();


-- =============================================================================
-- 092. CLINICAL EVENT APPEND FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION clinical.append_event(
    p_patient_id uuid,
    p_encounter_id uuid,
    p_event_type text,
    p_entity_type text,
    p_entity_id uuid,
    p_payload jsonb,
    p_actor_id uuid DEFAULT NULL,
    p_actor_type text DEFAULT 'SYSTEM',
    p_idempotency_key uuid DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id bigint;
BEGIN

    IF p_idempotency_key IS NOT NULL THEN

        SELECT event_id
        INTO v_event_id
        FROM clinical.events
        WHERE idempotency_key = p_idempotency_key;

        IF v_event_id IS NOT NULL THEN
            RETURN v_event_id;
        END IF;

    END IF;

    INSERT INTO clinical.events (
        patient_id,
        encounter_id,
        event_type,
        entity_type,
        entity_id,
        payload,
        actor_id,
        actor_type,
        idempotency_key
    )
    VALUES (
        p_patient_id,
        p_encounter_id,
        p_event_type,
        p_entity_type,
        p_entity_id,
        COALESCE(p_payload, '{}'::jsonb),
        p_actor_id,
        p_actor_type,
        p_idempotency_key
    )
    RETURNING event_id
    INTO v_event_id;

    RETURN v_event_id;
END;
$$;


-- =============================================================================
-- 093. PRESCRIPTION TOTAL DAILY DOSE HELPER
-- =============================================================================

CREATE OR REPLACE FUNCTION clinical.calculate_daily_dose(
    p_dose numeric,
    p_frequency_per_day numeric
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT
        CASE
            WHEN p_dose IS NULL OR p_frequency_per_day IS NULL
                THEN NULL
            ELSE p_dose * p_frequency_per_day
        END;
$$;


-- =============================================================================
-- 094. UNIVERSAL CLINICAL CAPTURE COMPLETION CHECK
-- =============================================================================

DO $clinical_capture_completion$
BEGIN

    IF to_regclass('clinical.patients') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: patients table missing';
    END IF;

    IF to_regclass('clinical.encounters') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: encounters table missing';
    END IF;

    IF to_regclass('clinical.facts') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: facts table missing';
    END IF;

    IF to_regclass('clinical.question_definitions') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: question catalogue missing';
    END IF;

    IF to_regclass('clinical.examination_observation') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: examination capture missing';
    END IF;

    IF to_regclass('clinical.investigation_results') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: investigation results missing';
    END IF;

    IF to_regclass('clinical.diagnoses') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: diagnosis layer missing';
    END IF;

    IF to_regclass('clinical.protocols') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: protocol layer missing';
    END IF;

    IF to_regclass('clinical.medications') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: medication layer missing';
    END IF;

    IF to_regclass('clinical.prescriptions') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: prescription layer missing';
    END IF;

    IF to_regclass('clinical.events') IS NULL THEN
        RAISE EXCEPTION 'Clinical capture installation failed: event layer missing';
    END IF;

    RAISE NOTICE
        'AMEXAN Clinical Capture 040 READY: universal patient -> encounter -> history -> examination -> investigation -> reasoning -> diagnosis -> severity -> protocol -> medication -> prescription -> monitoring -> documentation pipeline installed';

END;
$clinical_capture_completion$;


-- =============================================================================
-- 095. FINAL ARCHITECTURAL GUARANTEE
-- =============================================================================
--
-- The following tables constitute the minimum clinical operating chain:
--
-- clinical.patients
-- clinical.encounters
-- clinical.encounter_context
-- clinical.history_sections
-- clinical.question_definitions
-- clinical.question_rules
-- clinical.question_response
-- clinical.facts
-- clinical.presenting_problem
-- clinical.review_of_systems
-- clinical.past_medical_history
-- clinical.past_surgical_history
-- clinical.patient_medications
-- clinical.allergies
-- clinical.family_history
-- clinical.social_history
-- clinical.exposure_history
-- clinical.developmental_history
-- clinical.neonatal_history
-- clinical.obgyn_history
-- clinical.vital_observations
-- clinical.anthropometry
-- clinical.examination_findings
-- clinical.examination_rules
-- clinical.examination_observation
-- clinical.investigations
-- clinical.investigation_parameters
-- clinical.investigation_rules
-- clinical.investigation_orders
-- clinical.investigation_results
-- clinical.symptoms
-- clinical.phenotypes
-- clinical.mechanisms
-- clinical.conditions
-- clinical.differential_candidate
-- clinical.diagnoses
-- clinical.severity_score
-- clinical.severity_score_component
-- clinical.severity_score_interpretation
-- clinical.severity_score_result
-- clinical.protocols
-- clinical.protocol_rules
-- clinical.protocol_steps
-- clinical.protocol_actions
-- clinical.medications
-- clinical.medication_ingredients
-- clinical.medication_indications
-- clinical.treatment_rules
-- clinical.medication_contraindication
-- clinical.medication_interaction
-- clinical.drug_dose_reference
-- clinical.prescriptions
-- clinical.prescription_safety_check
-- clinical.medication_administration
-- clinical.monitoring_rules
-- clinical.monitoring_observation
-- clinical.referrals
-- clinical.disposition
-- clinical.follow_up_plan
-- clinical.documentation_rules
-- clinical.document_section_state
-- clinical.information_gap
-- clinical.alert
-- clinical.rule_execution
-- clinical.capture_session
-- clinical.capture_action
-- clinical.knowledge_object
-- clinical.knowledge_relationship
-- clinical.provenance_link
-- clinical.knowledge_version
-- clinical.snapshot
-- clinical.audit_event
-- clinical.events
-- clinical.timeline_event
--
-- NO clinical decision is intended to be hidden inside the UI.
-- All clinically material decisions are represented as structured data,
-- governed rules, captured evidence, provenance, or auditable execution.
--
-- =============================================================================
