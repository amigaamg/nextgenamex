-- =============================================================================
-- AMEXAN â€” PHASE 1
-- MIGRATION 004 â€” CLINICAL PRIMITIVES
-- VERSION 2.0
-- =============================================================================
--
-- PURPOSE
-- -------
-- Universal, longitudinal clinical data infrastructure.
--
-- ARCHITECTURAL LAW
-- -----------------
-- Patient
--   -> Encounter
--      -> Clinical Facts / Observations
--      -> Problems
--      -> Diagnoses
--      -> Orders
--      -> Results
--      -> Plans
--      -> Care Teams
--      -> Consent
--
-- This migration contains NO disease-specific clinical knowledge.
--
-- Disease knowledge, protocols, guidelines, drug intelligence, diagnostic
-- reasoning, clinical pathways and CPU inference belong to the AMEXAN
-- knowledge / intelligence layers built above these primitives.
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. Structured clinical data is authoritative.
-- 2. Narrative is supplementary, never the sole representation of a fact.
-- 3. Clinical history is append-preserving and auditable.
-- 4. Corrections supersede; they do not erase historical truth.
-- 5. Every important clinical assertion has provenance.
-- 6. Human, device, imported and AMEXAN-engine generated data are distinct.
-- 7. Terminology is externally anchored through terminology.concept.
-- 8. Temporal information is explicit.
-- 9. The model supports lifelong records across facilities.
-- 10. The model is designed for future CPU/clinical-intelligence workloads.
--
-- DEPENDENCIES
-- ------------
-- Migration 001+:
--   public.set_updated_at()
--   identity.person
--   identity.user_account
--   organization.facility
--   organization.department
--   organization.unit
--   organization.clinic
--   organization.room
--   organization.bed
--   organization.service
--   organization.professional
--   terminology.concept
--   terminology.value_set
--   terminology.unit
--   patient.patient
--   encounter.encounter
--
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS clinical;

COMMENT ON SCHEMA clinical IS
'AMEXAN universal clinical primitives: structured facts, observations, problems,
diagnoses, plans, orders, results, care teams, consent and clinical workflow.';


-- =============================================================================
-- COMMON VALIDATION FUNCTIONS
-- =============================================================================

CREATE OR REPLACE FUNCTION clinical.validate_temporal_range(
    p_start timestamptz,
    p_end   timestamptz
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_end IS NULL OR p_start IS NULL OR p_end >= p_start;
$$;


-- =============================================================================
-- FACT SYSTEM
-- =============================================================================
-- Atomic clinical assertions.
--
-- Example:
--   COUGH_PRESENT = true
--   COUGH_ONSET = 2026-08-12
--   SMOKING_STATUS = current
--   BODY_WEIGHT = 72 kg
--
-- A fact is NOT a diagnosis.
-- A fact is NOT a disease.
-- A fact is an atomic piece of patient-specific clinical information.
-- =============================================================================


CREATE TABLE clinical.fact_status (
    code         text PRIMARY KEY,
    label        text NOT NULL,
    description  text
);

COMMENT ON TABLE clinical.fact_status IS
'Lifecycle state of an atomic clinical fact.';


INSERT INTO clinical.fact_status (code, label, description)
VALUES
    ('entered',     'Entered',     'Fact has been recorded.'),
    ('active',      'Active',      'Fact is currently considered valid.'),
    ('corrected',   'Corrected',   'Fact was corrected; original history remains.'),
    ('superseded',  'Superseded',  'Fact has been replaced by a later assertion.'),
    ('retracted',   'Retracted',   'Fact has been explicitly withdrawn.'),
    ('entered_in_error', 'Entered in Error', 'Fact was recorded incorrectly.')
ON CONFLICT (code) DO NOTHING;


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.fact_definition CASCADE;
CREATE TABLE clinical.fact_definition (
    code                 text PRIMARY KEY,
    name                 text NOT NULL,
    description          text,

    data_type            text NOT NULL CHECK (
        data_type IN (
            'text',
            'boolean',
            'numeric',
            'integer',
            'date',
            'datetime',
            'coded',
            'quantity',
            'range',
            'ratio',
            'json'
        )
    ),

    value_set_id         uuid REFERENCES terminology.value_set(id),
    concept_id           uuid REFERENCES terminology.concept(id),

    allow_multiple       boolean NOT NULL DEFAULT false,
    requires_unit        boolean NOT NULL DEFAULT false,
    is_patient_reportable boolean NOT NULL DEFAULT true,
    is_machine_readable  boolean NOT NULL DEFAULT true,
    is_active            boolean NOT NULL DEFAULT true,

    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.fact_definition IS
'Universal definitions of atomic clinical facts.';


CREATE INDEX idx_fact_definition_valueset
    ON clinical.fact_definition(value_set_id);

CREATE INDEX idx_fact_definition_concept
    ON clinical.fact_definition(concept_id);

CREATE TRIGGER trg_fact_definition_updated_at
BEFORE UPDATE ON clinical.fact_definition
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE clinical.fact_unit (
    fact_definition_code text NOT NULL
        REFERENCES clinical.fact_definition(code)
        ON DELETE CASCADE,

    unit_code text NOT NULL
        REFERENCES terminology.unit(code)
        ON DELETE CASCADE,

    is_default boolean NOT NULL DEFAULT false,

    PRIMARY KEY (fact_definition_code, unit_code)
);

COMMENT ON TABLE clinical.fact_unit IS
'Units permitted for quantitative clinical facts.';


CREATE UNIQUE INDEX uq_fact_unit_default
    ON clinical.fact_unit(fact_definition_code)
    WHERE is_default;


CREATE TABLE clinical.fact (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id           uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id         uuid
        REFERENCES encounter.encounter(id),

    fact_definition_code text NOT NULL
        REFERENCES clinical.fact_definition(code),

    status_code          text NOT NULL DEFAULT 'entered'
        REFERENCES clinical.fact_status(code),

    -- Clinical truth time.
    observed_at          timestamptz,

    -- Time the assertion entered AMEXAN.
    recorded_at          timestamptz NOT NULL DEFAULT now(),

    -- Optional validity interval.
    valid_from           timestamptz,
    valid_to             timestamptz,

    recorded_by          uuid
        REFERENCES identity.user_account(id),

    -- Provenance classification.
    source_type          text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'patient',
                'caregiver',
                'clinician',
                'device',
                'laboratory',
                'imaging',
                'external_system',
                'import',
                'protocol',
                'engine',
                'ai',
                'unknown'
            )
        ),

    source_ref           text,

    notes                text,

    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_fact_temporal_order
        CHECK (
            valid_to IS NULL
            OR valid_from IS NULL
            OR valid_to >= valid_from
        )
);

COMMENT ON TABLE clinical.fact IS
'Patient-specific atomic clinical assertion with explicit provenance and temporal state.';


CREATE INDEX idx_fact_patient
    ON clinical.fact(patient_id);

CREATE INDEX idx_fact_encounter
    ON clinical.fact(encounter_id);

CREATE INDEX idx_fact_definition
    ON clinical.fact(fact_definition_code);

CREATE INDEX idx_fact_status
    ON clinical.fact(status_code);

CREATE INDEX idx_fact_observed
    ON clinical.fact(observed_at);

CREATE INDEX idx_fact_patient_observed
    ON clinical.fact(patient_id, observed_at DESC);

CREATE INDEX idx_fact_source_type
    ON clinical.fact(source_type);

CREATE TRIGGER trg_fact_updated_at
BEFORE UPDATE ON clinical.fact
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE clinical.fact_value (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    value_order integer NOT NULL DEFAULT 0
        CHECK (value_order >= 0),

    data_type text NOT NULL CHECK (
        data_type IN (
            'text',
            'boolean',
            'numeric',
            'integer',
            'date',
            'datetime',
            'coded',
            'quantity',
            'range',
            'ratio',
            'json'
        )
    ),

    value_text       text,
    value_numeric    numeric,
    value_integer    bigint,
    value_boolean    boolean,
    value_date       date,
    value_datetime   timestamptz,
    value_concept_id uuid REFERENCES terminology.concept(id),
    value_json       jsonb,

    unit_code        text REFERENCES terminology.unit(code),

    -- Quantity/range support.
    value_numeric_low  numeric,
    value_numeric_high numeric,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_fact_value_type
    CHECK (
        (
            data_type = 'text'
            AND value_text IS NOT NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'boolean'
            AND value_boolean IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'numeric'
            AND value_numeric IS NOT NULL
            AND value_text IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'integer'
            AND value_integer IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'date'
            AND value_date IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'datetime'
            AND value_datetime IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'coded'
            AND value_concept_id IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'json'
            AND value_json IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
        )
        OR
        (
            data_type = 'quantity'
            AND value_numeric IS NOT NULL
            AND value_text IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
        )
        OR
        (
            data_type = 'range'
            AND value_numeric_low IS NOT NULL
            AND value_numeric_high IS NOT NULL
            AND value_text IS NULL
            AND value_numeric IS NULL
            AND value_integer IS NULL
            AND value_boolean IS NULL
            AND value_date IS NULL
            AND value_datetime IS NULL
            AND value_concept_id IS NULL
            AND value_json IS NULL
            AND value_numeric_low <= value_numeric_high
        )
        OR
        (
            data_type = 'ratio'
            AND value_numeric IS NOT NULL
            AND value_numeric_low IS NOT NULL
        )
    ),

    CONSTRAINT chk_fact_value_range
        CHECK (
            value_numeric_low IS NULL
            OR value_numeric_high IS NULL
            OR value_numeric_low <= value_numeric_high
        )
);

COMMENT ON TABLE clinical.fact_value IS
'Typed value storage for an atomic clinical fact.';


CREATE INDEX idx_fact_value_fact
    ON clinical.fact_value(fact_id);

CREATE INDEX idx_fact_value_concept
    ON clinical.fact_value(value_concept_id);

CREATE INDEX idx_fact_value_numeric
    ON clinical.fact_value(value_numeric)
    WHERE value_numeric IS NOT NULL;


CREATE TABLE clinical.fact_context (
    fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    context_key text NOT NULL,
    context_value text NOT NULL,

    PRIMARY KEY (fact_id, context_key)
);

COMMENT ON TABLE clinical.fact_context IS
'Context required to correctly interpret a clinical fact.';


CREATE INDEX idx_fact_context_key_value
    ON clinical.fact_context(context_key, context_value);


CREATE TABLE clinical.fact_source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    source_type text NOT NULL
        CHECK (
            source_type IN (
                'patient_history',
                'caregiver_history',
                'clinical_examination',
                'device',
                'laboratory',
                'imaging',
                'document',
                'external',
                'protocol',
                'engine',
                'ai',
                'import'
            )
        ),

    source_ref text,

    source_system text,

    detail jsonb,

    recorded_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.fact_source IS
'Provenance chain identifying where a clinical fact originated.';


CREATE INDEX idx_fact_source_fact
    ON clinical.fact_source(fact_id);


CREATE TABLE clinical.fact_confidence (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    confidence numeric(5,4) NOT NULL
        CHECK (confidence >= 0 AND confidence <= 1),

    method text NOT NULL
        CHECK (
            method IN (
                'reported',
                'measured',
                'observed',
                'verified',
                'inferred',
                'machine_estimate',
                'ai_estimate',
                'imported'
            )
        ),

    assessed_by uuid REFERENCES identity.user_account(id),

    assessed_at timestamptz NOT NULL DEFAULT now(),

    rationale text
);

COMMENT ON TABLE clinical.fact_confidence IS
'Confidence and evidentiary characterization attached to a clinical fact.';


CREATE INDEX idx_fact_confidence_fact
    ON clinical.fact_confidence(fact_id);


CREATE TABLE clinical.fact_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    changed_at timestamptz NOT NULL DEFAULT now(),

    changed_by uuid
        REFERENCES identity.user_account(id),

    change_type text NOT NULL
        CHECK (
            change_type IN (
                'created',
                'corrected',
                'superseded',
                'retracted',
                'entered_in_error',
                'restored'
            )
        ),

    previous_snapshot jsonb,

    reason text
);

COMMENT ON TABLE clinical.fact_history IS
'Immutable clinical history for fact lifecycle changes.';


CREATE INDEX idx_fact_history_fact
    ON clinical.fact_history(fact_id);

CREATE INDEX idx_fact_history_changed
    ON clinical.fact_history(changed_at);


CREATE TABLE clinical.fact_relationship (
    source_fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    target_fact_id uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    relationship text NOT NULL
        CHECK (
            relationship IN (
                'supports',
                'contradicts',
                'implies',
                'derived_from',
                'related_to',
                'supersedes',
                'refines'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (source_fact_id, target_fact_id),

    CONSTRAINT chk_fact_relationship_not_self
        CHECK (source_fact_id <> target_fact_id)
);

COMMENT ON TABLE clinical.fact_relationship IS
'Typed semantic relationships between atomic clinical facts.';


CREATE INDEX idx_fact_relationship_target
    ON clinical.fact_relationship(target_fact_id);


CREATE TABLE clinical.fact_observation (
    fact_id uuid PRIMARY KEY
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    effective_time timestamptz,

    method text
        CHECK (
            method IS NULL OR method IN (
                'measured',
                'self_reported',
                'caregiver_reported',
                'observed',
                'reviewed',
                'device_generated',
                'imported',
                'engine_generated'
            )
        ),

    observer_id uuid
        REFERENCES organization.professional(id),

    is_abnormal boolean,

    interpretation text,

    device text,

    device_identifier text,

    body_site text,

    laterality text,

    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.fact_observation IS
'Observation-specific metadata for an atomic fact.';


-- =============================================================================
-- GENERIC OBSERVATIONS
-- =============================================================================


CREATE TABLE clinical.observation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    observation_type text NOT NULL
        CHECK (
            observation_type IN (
                'measurement',
                'vital_sign',
                'physical_finding',
                'symptom',
                'functional',
                'behavioral',
                'device',
                'laboratory',
                'imaging',
                'procedure',
                'other'
            )
        ),

    concept_id uuid
        REFERENCES terminology.concept(id),

    status text NOT NULL DEFAULT 'final'
        CHECK (
            status IN (
                'registered',
                'preliminary',
                'final',
                'amended',
                'corrected',
                'cancelled',
                'entered_in_error'
            )
        ),

    effective_time timestamptz,

    effective_end_time timestamptz,

    recorded_at timestamptz NOT NULL DEFAULT now(),

    recorded_by uuid
        REFERENCES identity.user_account(id),

    source_type text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'patient',
                'caregiver',
                'clinician',
                'device',
                'laboratory',
                'imaging',
                'external_system',
                'import',
                'engine',
                'ai',
                'unknown'
            )
        ),

    note text,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_observation_time
        CHECK (
            effective_end_time IS NULL
            OR effective_time IS NULL
            OR effective_end_time >= effective_time
        )
);

COMMENT ON TABLE clinical.observation IS
'Universal observation container. Specialized clinical observations attach to it.';


CREATE INDEX idx_observation_patient
    ON clinical.observation(patient_id);

CREATE INDEX idx_observation_encounter
    ON clinical.observation(encounter_id);

CREATE INDEX idx_observation_concept
    ON clinical.observation(concept_id);

CREATE INDEX idx_observation_effective
    ON clinical.observation(effective_time);

CREATE INDEX idx_observation_patient_time
    ON clinical.observation(patient_id, effective_time DESC);

CREATE TRIGGER trg_observation_updated_at
BEFORE UPDATE ON clinical.observation
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE clinical.measurement (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    observation_id uuid NOT NULL
        REFERENCES clinical.observation(id)
        ON DELETE CASCADE,

    parameter_code text NOT NULL,

    value_numeric numeric,

    value_text text,

    unit_code text
        REFERENCES terminology.unit(code),

    reference_low numeric,

    reference_high numeric,

    interpretation text,

    CONSTRAINT chk_measurement_value
        CHECK (
            value_numeric IS NOT NULL
            OR value_text IS NOT NULL
        )
);

COMMENT ON TABLE clinical.measurement IS
'Generic quantitative or textual measurement.';


CREATE INDEX idx_measurement_observation
    ON clinical.measurement(observation_id);

CREATE INDEX idx_measurement_parameter
    ON clinical.measurement(parameter_code);


CREATE TABLE clinical.vital_sign (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    observation_id uuid NOT NULL
        REFERENCES clinical.observation(id)
        ON DELETE CASCADE,

    parameter_code text NOT NULL,

    value_numeric numeric NOT NULL,

    unit_code text
        REFERENCES terminology.unit(code),

    patient_position text,

    body_site text,

    device text,

    measurement_method text
);

COMMENT ON TABLE clinical.vital_sign IS
'Vital-sign measurement attached to an observation.';


CREATE INDEX idx_vital_sign_observation
    ON clinical.vital_sign(observation_id);

CREATE INDEX idx_vital_sign_parameter
    ON clinical.vital_sign(parameter_code);


CREATE TABLE clinical.physical_finding (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    observation_id uuid NOT NULL
        REFERENCES clinical.observation(id)
        ON DELETE CASCADE,

    finding_code text NOT NULL,

    present boolean NOT NULL DEFAULT true,

    laterality text,

    body_site text,

    severity text,

    description text
);

COMMENT ON TABLE clinical.physical_finding IS
'Structured physical examination finding.';


CREATE INDEX idx_physical_finding_observation
    ON clinical.physical_finding(observation_id);

CREATE INDEX idx_physical_finding_code
    ON clinical.physical_finding(finding_code);


CREATE TABLE clinical.symptom_report (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    observation_id uuid NOT NULL
        REFERENCES clinical.observation(id)
        ON DELETE CASCADE,

    symptom_code text NOT NULL,

    severity text,

    onset_date date,

    onset_datetime timestamptz,

    duration_value numeric,

    duration_unit text,

    chronicity text
        CHECK (
            chronicity IS NULL OR chronicity IN (
                'acute',
                'subacute',
                'chronic',
                'recurrent',
                'intermittent',
                'persistent'
            )
        ),

    description text
);

COMMENT ON TABLE clinical.symptom_report IS
'Structured patient-reported symptom representation.';


CREATE INDEX idx_symptom_report_observation
    ON clinical.symptom_report(observation_id);

CREATE INDEX idx_symptom_report_code
    ON clinical.symptom_report(symptom_code);


CREATE TABLE clinical.functional_status (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    observation_id uuid NOT NULL
        REFERENCES clinical.observation(id)
        ON DELETE CASCADE,

    domain text NOT NULL,

    score numeric,

    scale_code text,

    interpretation text,

    description text
);

COMMENT ON TABLE clinical.functional_status IS
'Functional status assessment.';


CREATE TABLE clinical.behavioral_observation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    observation_id uuid NOT NULL
        REFERENCES clinical.observation(id)
        ON DELETE CASCADE,

    behavior_code text NOT NULL,

    status text,

    severity text,

    description text
);

COMMENT ON TABLE clinical.behavioral_observation IS
'Structured behavioral observation.';


-- =============================================================================
-- ASSESSMENT
-- =============================================================================


CREATE TABLE clinical.assessment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    assessment_type text NOT NULL
        CHECK (
            assessment_type IN (
                'subjective',
                'objective',
                'assessment',
                'plan',
                'clinical_note',
                'general'
            )
        ),

    concept_id uuid
        REFERENCES terminology.concept(id),

    content text NOT NULL,

    recorded_at timestamptz NOT NULL DEFAULT now(),

    recorded_by uuid
        REFERENCES identity.user_account(id),

    source_type text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'patient',
                'caregiver',
                'clinician',
                'device',
                'external_system',
                'import',
                'engine',
                'ai'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.assessment IS
'Narrative or structured clinical assessment. Structured primitives remain authoritative.';


CREATE INDEX idx_assessment_patient
    ON clinical.assessment(patient_id);

CREATE INDEX idx_assessment_encounter
    ON clinical.assessment(encounter_id);

CREATE INDEX idx_assessment_concept
    ON clinical.assessment(concept_id);

CREATE TRIGGER trg_assessment_updated_at
BEFORE UPDATE ON clinical.assessment
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- PROBLEMS
-- =============================================================================


CREATE TABLE clinical.problem_status (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text
);


INSERT INTO clinical.problem_status (code, label, description)
VALUES
    ('active', 'Active', 'Currently active problem.'),
    ('resolved', 'Resolved', 'Problem has resolved.'),
    ('inactive', 'Inactive', 'Problem remains relevant but is not currently active.'),
    ('recurred', 'Recurred', 'Previously resolved problem has recurred.'),
    ('entered_in_error', 'Entered in Error', 'Problem was entered incorrectly.')
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.problem (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    concept_id uuid
        REFERENCES terminology.concept(id),

    label text NOT NULL,

    status_code text NOT NULL DEFAULT 'active'
        REFERENCES clinical.problem_status(code),

    is_chronic boolean NOT NULL DEFAULT false,

    onset_date date,

    resolved_date date,

    added_by uuid
        REFERENCES identity.user_account(id),

    added_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_problem_dates
        CHECK (
            resolved_date IS NULL
            OR onset_date IS NULL
            OR resolved_date >= onset_date
        )
);

COMMENT ON TABLE clinical.problem IS
'Longitudinal patient problem list entry.';


CREATE INDEX idx_problem_patient
    ON clinical.problem(patient_id);

CREATE INDEX idx_problem_status
    ON clinical.problem(status_code);

CREATE INDEX idx_problem_concept
    ON clinical.problem(concept_id);

CREATE TRIGGER trg_problem_updated_at
BEFORE UPDATE ON clinical.problem
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- DIAGNOSIS
-- =============================================================================


CREATE TABLE clinical.diagnosis_status (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text
);


INSERT INTO clinical.diagnosis_status (code, label, description)
VALUES
    ('suspected', 'Suspected', 'Diagnosis suspected but not sufficiently established.'),
    ('working', 'Working', 'Current working diagnosis.'),
    ('confirmed', 'Confirmed', 'Diagnosis clinically confirmed.'),
    ('final', 'Final', 'Final diagnosis for the relevant clinical context.'),
    ('ruled_out', 'Ruled Out', 'Diagnosis has been ruled out.'),
    ('entered_in_error', 'Entered in Error', 'Diagnosis was entered incorrectly.')
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.diagnosis (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    problem_id uuid
        REFERENCES clinical.problem(id),

    concept_id uuid
        REFERENCES terminology.concept(id),

    label text NOT NULL,

    status_code text NOT NULL DEFAULT 'working'
        REFERENCES clinical.diagnosis_status(code),

    diagnosis_type text NOT NULL DEFAULT 'primary'
        CHECK (
            diagnosis_type IN (
                'primary',
                'secondary',
                'complication',
                'comorbidity',
                'differential',
                'historical'
            )
        ),

    certainty text
        CHECK (
            certainty IS NULL OR certainty IN (
                'excluded',
                'unlikely',
                'possible',
                'probable',
                'confirmed'
            )
        ),

    onset_date date,

    diagnosed_on date,

    diagnosed_by uuid
        REFERENCES identity.user_account(id),

    source_type text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'clinician',
                'laboratory',
                'imaging',
                'protocol',
                'engine',
                'ai',
                'external_system',
                'import'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.diagnosis IS
'Patient diagnosis with explicit status, certainty, type and provenance.';


CREATE INDEX idx_diagnosis_patient
    ON clinical.diagnosis(patient_id);

CREATE INDEX idx_diagnosis_encounter
    ON clinical.diagnosis(encounter_id);

CREATE INDEX idx_diagnosis_problem
    ON clinical.diagnosis(problem_id);

CREATE INDEX idx_diagnosis_concept
    ON clinical.diagnosis(concept_id);

CREATE TRIGGER trg_diagnosis_updated_at
BEFORE UPDATE ON clinical.diagnosis
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- CLINICAL SUMMARY
-- =============================================================================


CREATE TABLE clinical.clinical_summary (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    summary_type text NOT NULL,

    content text,

    generated_at timestamptz NOT NULL DEFAULT now(),

    generated_by uuid
        REFERENCES identity.user_account(id),

    generation_source text NOT NULL DEFAULT 'human'
        CHECK (
            generation_source IN (
                'human',
                'template',
                'engine',
                'ai'
            )
        ),

    supersedes_id uuid
        REFERENCES clinical.clinical_summary(id)
);

COMMENT ON TABLE clinical.clinical_summary IS
'Point-in-time clinical summary; may be human-authored or generated by AMEXAN engines.';


CREATE INDEX idx_clinical_summary_patient
    ON clinical.clinical_summary(patient_id);

CREATE INDEX idx_clinical_summary_encounter
    ON clinical.clinical_summary(encounter_id);


-- =============================================================================
-- PLAN
-- =============================================================================


CREATE TABLE clinical.plan (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    plan_type text NOT NULL DEFAULT 'management',

    title text,

    created_at timestamptz NOT NULL DEFAULT now(),

    created_by uuid
        REFERENCES identity.user_account(id),

    source_type text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'clinician',
                'protocol',
                'engine',
                'ai',
                'patient',
                'system'
            )
        ),

    is_active boolean NOT NULL DEFAULT true,

    superseded_by uuid
        REFERENCES clinical.plan(id)
);

COMMENT ON TABLE clinical.plan IS
'Universal clinical plan container. AMEXAN CPU may assemble plans from evidence and primitives.';


CREATE INDEX idx_plan_patient
    ON clinical.plan(patient_id);

CREATE INDEX idx_plan_encounter
    ON clinical.plan(encounter_id);

CREATE INDEX idx_plan_active
    ON clinical.plan(patient_id, is_active);


CREATE TABLE clinical.plan_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    plan_id uuid NOT NULL
        REFERENCES clinical.plan(id)
        ON DELETE CASCADE,

    item_order integer NOT NULL DEFAULT 0
        CHECK (item_order >= 0),

    action_type text NOT NULL
        CHECK (
            action_type IN (
                'order',
                'medication',
                'procedure',
                'referral',
                'follow_up',
                'education',
                'observation',
                'monitoring',
                'consultation',
                'other'
            )
        ),

    description text NOT NULL,

    related_order_id uuid,

    status text NOT NULL DEFAULT 'planned'
        CHECK (
            status IN (
                'planned',
                'in_progress',
                'completed',
                'cancelled',
                'deferred'
            )
        ),

    due_at timestamptz,

    completed_at timestamptz,

    completed_by uuid
        REFERENCES identity.user_account(id),

    source_type text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'clinician',
                'protocol',
                'engine',
                'ai',
                'system'
            )
        )
);

COMMENT ON TABLE clinical.plan_item IS
'Atomic actionable component of a clinical plan.';


CREATE INDEX idx_plan_item_plan
    ON clinical.plan_item(plan_id);


-- =============================================================================
-- FOLLOW-UP
-- =============================================================================


CREATE TABLE clinical.follow_up_plan (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    follow_up_type text,

    instructions text,

    due_date date NOT NULL,

    facility_id uuid
        REFERENCES organization.facility(id),

    clinic_id uuid
        REFERENCES organization.clinic(id),

    clinician_id uuid
        REFERENCES organization.professional(id),

    status text NOT NULL DEFAULT 'open'
        CHECK (
            status IN (
                'open',
                'completed',
                'cancelled',
                'overdue'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    completed_at timestamptz,

    completed_by uuid
        REFERENCES identity.user_account(id)
);

COMMENT ON TABLE clinical.follow_up_plan IS
'Planned clinical follow-up.';


CREATE INDEX idx_follow_up_patient
    ON clinical.follow_up_plan(patient_id);

CREATE INDEX idx_follow_up_due
    ON clinical.follow_up_plan(due_date);

CREATE INDEX idx_follow_up_status
    ON clinical.follow_up_plan(status);


-- =============================================================================
-- DISPOSITION
-- =============================================================================


CREATE TABLE clinical.disposition (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid NOT NULL
        REFERENCES encounter.encounter(id),

    disposition_type text NOT NULL
        CHECK (
            disposition_type IN (
                'discharge',
                'admit',
                'referral',
                'transfer',
                'observe',
                'follow_up',
                'expired',
                'left_against_advice',
                'other'
            )
        ),

    destination text,

    decided_at timestamptz NOT NULL DEFAULT now(),

    decided_by uuid
        REFERENCES identity.user_account(id),

    notes text,

    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.disposition IS
'Outcome/disposition of an encounter.';


CREATE INDEX idx_disposition_patient
    ON clinical.disposition(patient_id);

CREATE INDEX idx_disposition_encounter
    ON clinical.disposition(encounter_id);


-- =============================================================================
-- REFERRAL
-- =============================================================================


CREATE TABLE clinical.referral (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    from_professional uuid
        REFERENCES organization.professional(id),

    to_professional uuid
        REFERENCES organization.professional(id),

    to_facility_id uuid
        REFERENCES organization.facility(id),

    to_department_id uuid
        REFERENCES organization.department(id),

    reason text,

    reason_concept_id uuid
        REFERENCES terminology.concept(id),

    priority text NOT NULL DEFAULT 'routine'
        CHECK (
            priority IN (
                'routine',
                'urgent',
                'emergency',
                'stat'
            )
        ),

    status text NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'accepted',
                'declined',
                'completed',
                'cancelled'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    closed_at timestamptz
);

COMMENT ON TABLE clinical.referral IS
'Clinical referral between professionals, departments or facilities.';


CREATE INDEX idx_referral_patient
    ON clinical.referral(patient_id);

CREATE INDEX idx_referral_status
    ON clinical.referral(status);

CREATE INDEX idx_referral_destination
    ON clinical.referral(to_facility_id, to_department_id);


-- =============================================================================
-- ORDERS
-- =============================================================================


CREATE TABLE clinical.order_type (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text
);


INSERT INTO clinical.order_type (code, label, description)
VALUES
    ('laboratory',   'Laboratory',   'Laboratory investigation.'),
    ('imaging',      'Imaging',      'Diagnostic imaging request.'),
    ('medication',   'Medication',   'Medication order.'),
    ('procedure',    'Procedure',    'Procedure request.'),
    ('nursing',      'Nursing',      'Nursing order.'),
    ('consultation', 'Consultation', 'Clinical consultation.'),
    ('diet',         'Diet',         'Dietary order.'),
    ('monitoring',   'Monitoring',   'Clinical monitoring order.'),
    ('other',        'Other',        'Other clinical order.')
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.order_status (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text
);


INSERT INTO clinical.order_status (code, label, description)
VALUES
    ('draft',     'Draft',     'Order being prepared.'),
    ('pending',   'Pending',   'Order submitted and awaiting action.'),
    ('active',    'Active',    'Order currently active.'),
    ('on_hold',   'On Hold',   'Order temporarily suspended.'),
    ('completed', 'Completed', 'Order fulfilled.'),
    ('cancelled', 'Cancelled', 'Order cancelled.'),
    ('resulted',  'Resulted',  'Order has produced result(s).'),
    ('entered_in_error', 'Entered in Error', 'Order entered incorrectly.')
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.order_priority (
    code text PRIMARY KEY,
    label text NOT NULL,
    sort_order integer NOT NULL DEFAULT 0
);


INSERT INTO clinical.order_priority (code, label, sort_order)
VALUES
    ('routine',  'Routine',  10),
    ('urgent',   'Urgent',   20),
    ('asap',     'ASAP',     30),
    ('stat',     'STAT',     40)
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.order (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    order_type_code text NOT NULL
        REFERENCES clinical.order_type(code),

    status_code text NOT NULL DEFAULT 'pending'
        REFERENCES clinical.order_status(code),

    priority_code text NOT NULL DEFAULT 'routine'
        REFERENCES clinical.order_priority(code),

    concept_id uuid
        REFERENCES terminology.concept(id),

    service_id uuid
        REFERENCES organization.service(id),

    requested_by uuid
        REFERENCES organization.professional(id),

    requested_at timestamptz NOT NULL DEFAULT now(),

    requested_start timestamptz,

    requested_end timestamptz,

    instructions text,

    reason_text text,

    is_stat boolean NOT NULL DEFAULT false,

    source_type text NOT NULL DEFAULT 'clinician'
        CHECK (
            source_type IN (
                'clinician',
                'protocol',
                'engine',
                'ai',
                'system',
                'external_system',
                'import'
            )
        ),

    source_ref text,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_order_dates
        CHECK (
            requested_end IS NULL
            OR requested_start IS NULL
            OR requested_end >= requested_start
        )
);

COMMENT ON TABLE clinical.order IS
'Universal clinical order infrastructure. Specialized engines attach above it.';


CREATE INDEX idx_order_patient
    ON clinical.order(patient_id);

CREATE INDEX idx_order_encounter
    ON clinical.order(encounter_id);

CREATE INDEX idx_order_status
    ON clinical.order(status_code);

CREATE INDEX idx_order_priority
    ON clinical.order(priority_code);

CREATE INDEX idx_order_requested
    ON clinical.order(requested_at DESC);

CREATE INDEX idx_order_patient_status
    ON clinical.order(patient_id, status_code);

CREATE TRIGGER trg_order_updated_at
BEFORE UPDATE ON clinical.order
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


ALTER TABLE clinical.plan_item
ADD CONSTRAINT fk_plan_item_order
FOREIGN KEY (related_order_id)
REFERENCES clinical.order(id);


CREATE TABLE clinical.order_reason (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id uuid NOT NULL
        REFERENCES clinical.order(id)
        ON DELETE CASCADE,

    reason_type text NOT NULL
        CHECK (
            reason_type IN (
                'symptom',
                'indication',
                'diagnosis',
                'follow_up',
                'monitoring',
                'screening',
                'differential',
                'protocol',
                'other'
            )
        ),

    reason text NOT NULL,

    concept_id uuid
        REFERENCES terminology.concept(id)
);

COMMENT ON TABLE clinical.order_reason IS
'Clinical rationale for an order.';


CREATE INDEX idx_order_reason_order
    ON clinical.order_reason(order_id);


CREATE TABLE clinical.order_source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id uuid NOT NULL
        REFERENCES clinical.order(id)
        ON DELETE CASCADE,

    source_type text NOT NULL
        CHECK (
            source_type IN (
                'manual',
                'protocol',
                'differential',
                'engine',
                'clinical_decision_support',
                'ai',
                'external_system',
                'import'
            )
        ),

    source_ref text,

    engine_id text,

    engine_version text,

    reasoning_ref text
);

COMMENT ON TABLE clinical.order_source IS
'Provenance of an order, including AMEXAN engine and AI generation.';


CREATE INDEX idx_order_source_order
    ON clinical.order_source(order_id);


CREATE TABLE clinical.order_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id uuid NOT NULL
        REFERENCES clinical.order(id)
        ON DELETE CASCADE,

    event_type text NOT NULL
        CHECK (
            event_type IN (
                'created',
                'submitted',
                'accepted',
                'rejected',
                'started',
                'collected',
                'performed',
                'resulted',
                'completed',
                'cancelled',
                'held',
                'resumed',
                'amended'
            )
        ),

    event_at timestamptz NOT NULL DEFAULT now(),

    event_by uuid
        REFERENCES identity.user_account(id),

    detail jsonb
);

COMMENT ON TABLE clinical.order_event IS
'Complete order lifecycle event stream.';


CREATE INDEX idx_order_event_order
    ON clinical.order_event(order_id);

CREATE INDEX idx_order_event_time
    ON clinical.order_event(event_at);


CREATE TABLE clinical.order_cancellation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id uuid NOT NULL
        REFERENCES clinical.order(id)
        ON DELETE CASCADE,

    cancelled_by uuid NOT NULL
        REFERENCES identity.user_account(id),

    cancelled_at timestamptz NOT NULL DEFAULT now(),

    reason text,

    previous_status text
);

COMMENT ON TABLE clinical.order_cancellation IS
'Explicit cancellation record for a clinical order.';


CREATE INDEX idx_order_cancellation_order
    ON clinical.order_cancellation(order_id);


-- =============================================================================
-- RESULTS
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.result CASCADE;
CREATE TABLE clinical.result (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    result_type text NOT NULL
        CHECK (
            result_type IN (
                'numeric',
                'coded',
                'text',
                'quantity',
                'range',
                'ratio',
                'document',
                'json'
            )
        ),

    concept_id uuid
        REFERENCES terminology.concept(id),

    value_numeric numeric,

    value_text text,

    value_concept_id uuid
        REFERENCES terminology.concept(id),

    value_json jsonb,

    unit_code text
        REFERENCES terminology.unit(code),

    reference_low numeric,

    reference_high numeric,

    status text NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'partial',
                'preliminary',
                'final',
                'corrected',
                'cancelled',
                'entered_in_error'
            )
        ),

    collected_at timestamptz,

    resulted_at timestamptz,

    resulted_by uuid
        REFERENCES identity.user_account(id),

    source_type text NOT NULL DEFAULT 'laboratory'
        CHECK (
            source_type IN (
                'laboratory',
                'imaging',
                'pathology',
                'device',
                'external_system',
                'import',
                'clinician',
                'engine'
            )
        ),

    notes text,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_result_value
        CHECK (
            value_numeric IS NOT NULL
            OR value_text IS NOT NULL
            OR value_concept_id IS NOT NULL
            OR value_json IS NOT NULL
        )
);

COMMENT ON TABLE clinical.result IS
'Universal clinical result container for laboratory, imaging, pathology, device and other result engines.';


CREATE INDEX idx_result_patient
    ON clinical.result(patient_id);

CREATE INDEX idx_result_encounter
    ON clinical.result(encounter_id);

CREATE INDEX idx_result_concept
    ON clinical.result(concept_id);

CREATE INDEX idx_result_status
    ON clinical.result(status);

CREATE INDEX idx_result_resulted
    ON clinical.result(resulted_at DESC);

CREATE TRIGGER trg_result_updated_at
BEFORE UPDATE ON clinical.result
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE clinical.order_result_link (
    order_id uuid NOT NULL
        REFERENCES clinical.order(id)
        ON DELETE CASCADE,

    result_id uuid NOT NULL
        REFERENCES clinical.result(id)
        ON DELETE CASCADE,

    link_type text NOT NULL DEFAULT 'produced'
        CHECK (
            link_type IN (
                'produced',
                'supports',
                'supersedes',
                'corrects',
                'related'
            )
        ),

    PRIMARY KEY (order_id, result_id)
);

COMMENT ON TABLE clinical.order_result_link IS
'Relationship between clinical orders and their resulting data.';


CREATE INDEX idx_order_result_result
    ON clinical.order_result_link(result_id);


-- =============================================================================
-- CARE TEAM
-- =============================================================================


CREATE TABLE clinical.care_team (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    name text NOT NULL,

    team_type text,

    is_active boolean NOT NULL DEFAULT true,

    created_at timestamptz NOT NULL DEFAULT now(),

    ended_at timestamptz
);

COMMENT ON TABLE clinical.care_team IS
'Clinical team responsible for a patient or encounter.';


CREATE INDEX idx_care_team_patient
    ON clinical.care_team(patient_id);

CREATE INDEX idx_care_team_encounter
    ON clinical.care_team(encounter_id);


CREATE TABLE clinical.care_team_role (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text
);


INSERT INTO clinical.care_team_role (code, label, description)
VALUES
    ('attending', 'Attending', 'Attending clinician.'),
    ('consultant', 'Consultant', 'Consultant specialist.'),
    ('registrar', 'Registrar', 'Registrar/resident clinician.'),
    ('intern', 'Intern', 'Intern/junior clinician.'),
    ('nurse_in_charge', 'Nurse in Charge', 'Nurse responsible for the clinical area/patient.'),
    ('nurse', 'Nurse', 'Nursing professional.'),
    ('pharmacist', 'Pharmacist', 'Pharmacy professional.'),
    ('therapist', 'Therapist', 'Therapy professional.'),
    ('care_coordinator', 'Care Coordinator', 'Care coordination role.'),
    ('other', 'Other', 'Other care-team role.')
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.care_team_member (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    care_team_id uuid NOT NULL
        REFERENCES clinical.care_team(id)
        ON DELETE CASCADE,

    professional_id uuid NOT NULL
        REFERENCES organization.professional(id),

    role_code text
        REFERENCES clinical.care_team_role(code),

    is_lead boolean NOT NULL DEFAULT false,

    valid_from timestamptz NOT NULL DEFAULT now(),

    valid_to timestamptz,

    CONSTRAINT chk_care_team_member_dates
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        )
);

COMMENT ON TABLE clinical.care_team_member IS
'Professional membership within a clinical care team.';


CREATE INDEX idx_care_team_member_team
    ON clinical.care_team_member(care_team_id);

CREATE INDEX idx_care_team_member_professional
    ON clinical.care_team_member(professional_id);


CREATE TABLE clinical.care_team_assignment (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    care_team_id uuid
        REFERENCES clinical.care_team(id),

    professional_id uuid NOT NULL
        REFERENCES organization.professional(id),

    assignment_type text NOT NULL,

    valid_from timestamptz NOT NULL DEFAULT now(),

    valid_to timestamptz,

    CONSTRAINT chk_assignment_dates
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        )
);

COMMENT ON TABLE clinical.care_team_assignment IS
'Explicit clinical responsibility assignment.';


CREATE INDEX idx_care_team_assignment_patient
    ON clinical.care_team_assignment(patient_id);

CREATE INDEX idx_care_team_assignment_professional
    ON clinical.care_team_assignment(professional_id);


CREATE TABLE clinical.handover (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    from_professional uuid
        REFERENCES organization.professional(id),

    to_professional uuid
        REFERENCES organization.professional(id),

    summary text,

    status text NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'accepted',
                'completed',
                'cancelled'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now(),

    accepted_at timestamptz,

    completed_at timestamptz
);

COMMENT ON TABLE clinical.handover IS
'Clinical handover between providers.';


CREATE INDEX idx_handover_patient
    ON clinical.handover(patient_id);

CREATE INDEX idx_handover_encounter
    ON clinical.handover(encounter_id);


CREATE TABLE clinical.handover_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    handover_id uuid NOT NULL
        REFERENCES clinical.handover(id)
        ON DELETE CASCADE,

    item_order integer NOT NULL DEFAULT 0,

    item_type text,

    concept_id uuid
        REFERENCES terminology.concept(id),

    description text NOT NULL,

    action_required text,

    status text NOT NULL DEFAULT 'open'
        CHECK (
            status IN (
                'open',
                'done',
                'cancelled'
            )
        )
);

COMMENT ON TABLE clinical.handover_item IS
'Individual actionable component of a clinical handover.';


CREATE INDEX idx_handover_item_handover
    ON clinical.handover_item(handover_id);


-- =============================================================================
-- CLINICAL CONSENT
-- =============================================================================


CREATE TABLE clinical.consent_type (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text
);


INSERT INTO clinical.consent_type (code, label, description)
VALUES
    ('treatment',        'Treatment',        'General clinical treatment.'),
    ('procedure',        'Procedure',        'Clinical procedure.'),
    ('surgery',          'Surgery',          'Surgical intervention.'),
    ('anesthesia',       'Anesthesia',       'Anesthesia.'),
    ('blood_transfusion','Blood Transfusion','Blood or blood-product transfusion.'),
    ('imaging',          'Imaging',          'Imaging procedure where consent is required.'),
    ('research',         'Research',         'Research participation.'),
    ('data_sharing',     'Data Sharing',     'Data sharing.'),
    ('telemedicine',     'Telemedicine',     'Remote clinical care.')
ON CONFLICT (code) DO NOTHING;


CREATE TABLE clinical.consent_version (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    consent_type_code text NOT NULL
        REFERENCES clinical.consent_type(code),

    version integer NOT NULL
        CHECK (version > 0),

    content text NOT NULL,

    effective_from date NOT NULL DEFAULT current_date,

    effective_to date,

    created_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (consent_type_code, version),

    CONSTRAINT chk_consent_version_dates
        CHECK (
            effective_to IS NULL
            OR effective_to >= effective_from
        )
);

COMMENT ON TABLE clinical.consent_version IS
'Immutable versioned consent document definition.';


CREATE TABLE clinical.consent (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    consent_type_code text NOT NULL
        REFERENCES clinical.consent_type(code),

    consent_version_id uuid
        REFERENCES clinical.consent_version(id),

    decision text NOT NULL
        CHECK (
            decision IN (
                'granted',
                'denied',
                'withdrawn',
                'expired'
            )
        ),

    signed_by uuid
        REFERENCES identity.person(id),

    signed_at timestamptz,

    witnessed_by uuid
        REFERENCES identity.person(id),

    valid_from timestamptz NOT NULL DEFAULT now(),

    valid_to timestamptz,

    notes text,

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_consent_dates
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        )
);

COMMENT ON TABLE clinical.consent IS
'Patient-specific clinical consent decision.';


CREATE INDEX idx_consent_patient
    ON clinical.consent(patient_id);

CREATE INDEX idx_consent_encounter
    ON clinical.consent(encounter_id);

CREATE INDEX idx_consent_type
    ON clinical.consent(consent_type_code);


CREATE TABLE clinical.consent_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    consent_id uuid NOT NULL
        REFERENCES clinical.consent(id)
        ON DELETE CASCADE,

    event_type text NOT NULL
        CHECK (
            event_type IN (
                'created',
                'viewed',
                'amended',
                'withdrawn',
                'expired',
                'verified'
            )
        ),

    event_at timestamptz NOT NULL DEFAULT now(),

    event_by uuid
        REFERENCES identity.user_account(id),

    detail jsonb
);

COMMENT ON TABLE clinical.consent_event IS
'Immutable lifecycle events for clinical consent.';


CREATE INDEX idx_consent_event_consent
    ON clinical.consent_event(consent_id);

CREATE INDEX idx_consent_event_time
    ON clinical.consent_event(event_at);


-- =============================================================================
-- PATIENT CLINICAL PREFERENCES
-- =============================================================================


CREATE TABLE clinical.patient_preference (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    preference_type text NOT NULL,

    preference_key text NOT NULL,

    preference_value text,

    recorded_at timestamptz NOT NULL DEFAULT now(),

    recorded_by uuid
        REFERENCES identity.user_account(id),

    is_active boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE clinical.patient_preference IS
'Clinical care preferences distinct from administrative patient contact preferences.';


CREATE INDEX idx_clinical_patient_preference_patient
    ON clinical.patient_preference(patient_id);

CREATE INDEX idx_clinical_patient_preference_key
    ON clinical.patient_preference(preference_type, preference_key);


-- =============================================================================
-- ADVANCE DIRECTIVES
-- =============================================================================


CREATE TABLE clinical.advance_directive (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    directive_type text NOT NULL,

    content text,

    surrogate_person_id uuid
        REFERENCES identity.person(id),

    status text NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'draft',
                'active',
                'superseded',
                'withdrawn',
                'expired'
            )
        ),

    recorded_at timestamptz NOT NULL DEFAULT now(),

    recorded_by uuid
        REFERENCES identity.user_account(id),

    effective_from timestamptz,

    expires_at timestamptz,

    supersedes_id uuid
        REFERENCES clinical.advance_directive(id),

    CONSTRAINT chk_advance_directive_dates
        CHECK (
            expires_at IS NULL
            OR effective_from IS NULL
            OR expires_at >= effective_from
        )
);

COMMENT ON TABLE clinical.advance_directive IS
'Patient advance directives and legally/clinically relevant future-care instructions.';


CREATE INDEX idx_advance_directive_patient
    ON clinical.advance_directive(patient_id);

CREATE INDEX idx_advance_directive_status
    ON clinical.advance_directive(status);


-- =============================================================================
-- CLINICAL EVENT STREAM
-- =============================================================================
-- Generic clinical event ledger for future CPU/event-driven infrastructure.
-- This does not replace domain-specific history tables.
-- =============================================================================


CREATE TABLE clinical.event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id uuid
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    event_type text NOT NULL,

    aggregate_type text,

    aggregate_id uuid,

    occurred_at timestamptz NOT NULL DEFAULT now(),

    recorded_at timestamptz NOT NULL DEFAULT now(),

    actor_user_id uuid
        REFERENCES identity.user_account(id),

    actor_professional_id uuid
        REFERENCES organization.professional(id),

    source_type text NOT NULL DEFAULT 'system'
        CHECK (
            source_type IN (
                'patient',
                'caregiver',
                'clinician',
                'device',
                'external_system',
                'protocol',
                'engine',
                'ai',
                'system',
                'import'
            )
        ),

    source_ref text,

    payload jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE clinical.event IS
'Universal append-oriented clinical event stream supporting audit, integrations and AMEXAN CPU processing.';


CREATE INDEX idx_clinical_event_patient
    ON clinical.event(patient_id, occurred_at DESC);

CREATE INDEX idx_clinical_event_encounter
    ON clinical.event(encounter_id, occurred_at DESC);

CREATE INDEX idx_clinical_event_type
    ON clinical.event(event_type);

CREATE INDEX idx_clinical_event_aggregate
    ON clinical.event(aggregate_type, aggregate_id);

CREATE INDEX idx_clinical_event_occurred
    ON clinical.event(occurred_at DESC);


-- =============================================================================
-- CLINICAL ENGINE PROVENANCE
-- =============================================================================
-- Allows future CPU/AI systems to identify exactly which engine/version
-- generated or modified a clinical assertion.
-- =============================================================================


CREATE TABLE clinical.engine_provenance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    engine_id text NOT NULL,

    engine_version text,

    execution_id text,

    model_id text,

    model_version text,

    rule_set_id text,

    rule_set_version text,

    execution_type text NOT NULL
        CHECK (
            execution_type IN (
                'rule',
                'protocol',
                'decision_support',
                'ai',
                'scoring',
                'summarization',
                'classification',
                'recommendation',
                'data_transformation'
            )
        ),

    executed_at timestamptz NOT NULL DEFAULT now(),

    executed_by uuid
        REFERENCES identity.user_account(id),

    input_hash text,

    output_hash text,

    input_snapshot jsonb,

    output_snapshot jsonb,

    explanation text,

    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.engine_provenance IS
'AMEXAN CPU/engine provenance for machine-generated clinical outputs.';


CREATE INDEX idx_engine_provenance_engine
    ON clinical.engine_provenance(engine_id, executed_at DESC);

CREATE INDEX idx_engine_provenance_execution
    ON clinical.engine_provenance(execution_id);


-- =============================================================================
-- LINK ENGINE EXECUTIONS TO CLINICAL OBJECTS
-- =============================================================================


CREATE TABLE clinical.engine_output (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    engine_provenance_id uuid NOT NULL
        REFERENCES clinical.engine_provenance(id)
        ON DELETE CASCADE,

    patient_id uuid
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id uuid
        REFERENCES encounter.encounter(id),

    object_type text NOT NULL,

    object_id uuid,

    output_role text NOT NULL
        CHECK (
            output_role IN (
                'input',
                'derived_fact',
                'risk',
                'recommendation',
                'diagnosis_candidate',
                'order_candidate',
                'plan_candidate',
                'alert',
                'summary',
                'classification'
            )
        ),

    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.engine_output IS
'Links AMEXAN intelligence executions to clinical objects they consumed or produced.';


CREATE INDEX idx_engine_output_execution
    ON clinical.engine_output(engine_provenance_id);

CREATE INDEX idx_engine_output_patient
    ON clinical.engine_output(patient_id, created_at DESC);

CREATE INDEX idx_engine_output_object
    ON clinical.engine_output(object_type, object_id);


-- =============================================================================
-- FINAL INTEGRITY INDEXES
-- =============================================================================


CREATE INDEX IF NOT EXISTS idx_fact_patient_active
    ON clinical.fact(patient_id, fact_definition_code)
    WHERE status_code IN ('entered', 'active');


CREATE INDEX IF NOT EXISTS idx_problem_patient_active
    ON clinical.problem(patient_id, concept_id)
    WHERE status_code IN ('active', 'recurred');


CREATE INDEX IF NOT EXISTS idx_diagnosis_patient_active
    ON clinical.diagnosis(patient_id, concept_id)
    WHERE status_code IN ('suspected', 'working', 'confirmed', 'final');


CREATE INDEX IF NOT EXISTS idx_order_patient_active
    ON clinical.order(patient_id, order_type_code)
    WHERE status_code IN ('pending', 'active', 'on_hold');


-- =============================================================================
-- MIGRATION COMPLETION MARKER
-- =============================================================================
-- Migration frameworks may replace this with their own migration ledger.
-- =============================================================================


COMMENT ON SCHEMA clinical IS
'AMEXAN Phase 1 Clinical Primitives v2.0 â€” universal structured clinical
infrastructure for lifelong patient records, encounter workflows, orders,
results, care teams, consent, provenance and future clinical intelligence.';
