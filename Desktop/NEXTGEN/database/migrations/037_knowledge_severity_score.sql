-- =============================================================================
-- AMEXAN CLINICAL OS
-- PHASE 2 — MIGRATION 037
-- STRUCTURED CLINICAL SEVERITY SCORING ENGINE
-- =============================================================================
--
-- PURPOSE
-- -------
-- H10 governs whether AMEXAN may trust and use clinical knowledge.
-- H11/Phase-2 severity scoring provides the machine-executable structure for
-- validated clinical severity instruments.
--
-- A severity instrument is NOT a diagnosis and is NOT an autonomous treatment
-- decision. It is a structured clinical measurement of severity/risk which:
--
--      CAPTURED FACTS
--            ↓
--      SCORE COMPONENT EVALUATION
--            ↓
--      POINT TOTAL
--            ↓
--      VALIDATED INTERPRETATION
--            ↓
--      GOVERNED CLINICAL ACTION / DISPOSITION SUPPORT
--
-- Examples:
--      CURB-65
--      CRB-65
--      qSOFA
--      NEWS2
--      GCS-derived severity structures
--      Wells scores
--      PERC
--      CHA2DS2-VASc
--      HAS-BLED
--      PESI
--      PSI
--      APACHE-derived instruments
--      disease-specific validated scores
--
-- IMPORTANT CLINICAL LAW
-- ----------------------
-- 1. A score NEVER creates a clinical fact.
-- 2. A score NEVER changes the source fact.
-- 3. Missing information is not silently interpreted as negative.
-- 4. A component may only receive points when its required evidence exists.
-- 5. Age/sex/pregnancy/population applicability is evaluated explicitly.
-- 6. The score definition is versioned and provenance-bound.
-- 7. Interpretation is separated from calculation.
-- 8. Disposition/recommendation is advisory unless a governed protocol
--    explicitly authorizes an action.
-- 9. Human override is preserved.
-- 10. Every runtime score is reproducible from its captured inputs.
-- 11. The UI renders the CPU result; the UI does not calculate the score.
-- 12. Clinical knowledge remains in PostgreSQL; execution remains CPU-side.
--
-- ARCHITECTURE
-- ------------
-- PostgreSQL = scoring knowledge + configuration + governance
-- CPU        = score evaluation + execution + audit
-- UI         = rendering only
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. REQUIRED SCHEMA
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;


-- =============================================================================
-- 1. CONDITION COMPATIBILITY
-- =============================================================================
--
-- Earlier AMEXAN layers may use either:
--      knowledge.condition
-- or:
--      knowledge.diagnosis_concept
--
-- This migration does NOT silently create a second clinical condition system.
--
-- The severity_score.condition_code is therefore the canonical portable
-- association key. Where an existing condition registry is available, the
-- optional FK below may be added by the deployment-specific migration layer.
--
-- =============================================================================


-- =============================================================================
-- 2. SEVERITY SCORE
-- =============================================================================
--
-- One row = one named scoring instrument/version family.
--
-- Examples:
--      SCORE-CURB65
--      SCORE-CRB65
--      SCORE-QSOFA
--      SCORE-NEWS2
--
-- A score is a clinical knowledge object.
-- It must therefore have:
--      provenance
--      population
--      applicability
--      lifecycle
--      version
--      validation policy
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_code               text NOT NULL UNIQUE,
    canonical_name           text NOT NULL,

    description              text,

    -- Portable clinical association.
    -- Example: CONDITION-COMMUNITY-ACQUIRED-PNEUMONIA
    condition_code           text,

    -- Optional compatibility with deployments that already possess
    -- knowledge.condition.
    condition_id             uuid,

    -- Population applicability.
    population               text NOT NULL DEFAULT 'both'
        CHECK (
            population IN (
                'adult',
                'paediatric',
                'neonate',
                'geriatric',
                'pregnancy',
                'postpartum',
                'both',
                'all'
            )
        ),

    minimum_age_years        numeric(6,3),
    maximum_age_years        numeric(6,3),

    sex_restriction          text NOT NULL DEFAULT 'ALL'
        CHECK (
            sex_restriction IN (
                'ALL',
                'MALE',
                'FEMALE'
            )
        ),

    pregnancy_allowed        boolean NOT NULL DEFAULT true,

    -- Score arithmetic.
    minimum_score            integer NOT NULL DEFAULT 0,
    maximum_score            integer NOT NULL DEFAULT 0,

    -- Missing-data policy.
    missing_data_policy      text NOT NULL DEFAULT 'INCOMPLETE'
        CHECK (
            missing_data_policy IN (
                'INCOMPLETE',
                'TREAT_AS_ABSENT',
                'REQUEST_INFORMATION',
                'BLOCK_CALCULATION'
            )
        ),

    -- Whether the score is intended for:
    -- risk estimation, severity classification, or both.
    clinical_use             text NOT NULL DEFAULT 'SEVERITY'
        CHECK (
            clinical_use IN (
                'SEVERITY',
                'RISK',
                'SEVERITY_AND_RISK'
            )
        ),

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    source_reference         text,

    -- Governance linkage.
    governance_object_code   text,

    -- Lifecycle.
    status                   text NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'active',
                'superseded',
                'retired'
            )
        ),

    effective_from           date,
    effective_to             date,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_severity_score_age_range
        CHECK (
            minimum_age_years IS NULL
            OR maximum_age_years IS NULL
            OR minimum_age_years <= maximum_age_years
        ),

    CONSTRAINT chk_severity_score_range
        CHECK (minimum_score <= maximum_score)
);


COMMENT ON TABLE knowledge.severity_score IS
'First-class AMEXAN clinical severity/risk scoring instrument. Stores the governed definition, applicability, arithmetic boundaries, provenance and lifecycle. CPU evaluates the instrument; UI only renders the result.';


COMMENT ON COLUMN knowledge.severity_score.missing_data_policy IS
'Controls behaviour when required score inputs are absent. AMEXAN must never silently convert an unknown clinical fact into a negative criterion unless the governed score explicitly permits that policy.';


COMMENT ON COLUMN knowledge.severity_score.clinical_use IS
'Clinical purpose of the scoring instrument: severity, risk, or both.';


CREATE INDEX IF NOT EXISTS
    idx_severity_score_condition
ON knowledge.severity_score(condition_code);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_population
ON knowledge.severity_score(population);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_status
ON knowledge.severity_score(status);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_source
ON knowledge.severity_score(source_claim_code);


DROP TRIGGER IF EXISTS
    trg_knowledge_severity_score_updated_at
ON knowledge.severity_score;


CREATE TRIGGER
    trg_knowledge_severity_score_updated_at
BEFORE UPDATE ON knowledge.severity_score
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. SEVERITY SCORE VERSION
-- =============================================================================
--
-- A score definition must never be silently changed after it has been used
-- clinically.
--
-- CURB-65 version A and CURB-65 version B may therefore coexist historically.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_version (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    version_no               integer NOT NULL
        CHECK (version_no >= 1),

    version_code             text NOT NULL UNIQUE,

    scoring_definition_hash  text,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    change_note              text,

    effective_from           date,
    effective_to             date,

    status                   text NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'active',
                'superseded',
                'retired'
            )
        ),

    supersedes_version_id    uuid
        REFERENCES knowledge.severity_score_version(id),

    created_by               text,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (score_id, version_no)
);


COMMENT ON TABLE knowledge.severity_score_version IS
'Immutable clinical scoring definition lineage. A runtime score result is bound to the exact scoring version used for calculation.';


CREATE INDEX IF NOT EXISTS
    idx_severity_score_version_score
ON knowledge.severity_score_version(score_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_version_status
ON knowledge.severity_score_version(status);


DROP TRIGGER IF EXISTS
    trg_knowledge_severity_score_version_updated_at
ON knowledge.severity_score_version;


CREATE TRIGGER
    trg_knowledge_severity_score_version_updated_at
BEFORE UPDATE ON knowledge.severity_score_version
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 4. SEVERITY SCORE COMPONENT
-- =============================================================================
--
-- One row = one criterion capable of contributing points.
--
-- Examples for CURB-65:
--
--      CONFUSION
--      UREA
--      RESPIRATORY_RATE
--      BLOOD_PRESSURE
--      AGE
--
-- condition_json is retained as the machine-readable expression because
-- AMEXAN's scoring engine must not contain hard-coded score-specific if/else
-- chains.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_component (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES knowledge.severity_score_version(id)
        ON DELETE CASCADE,

    component_code           text NOT NULL,

    component_name           text NOT NULL,

    description              text,

    -- Machine-evaluable expression.
    --
    -- Example:
    --
    -- {
    --   "fact_code": "RESPIRATORY_RATE",
    --   "operator": ">=",
    --   "value": 30,
    --   "unit": "breaths/min"
    -- }
    --
    condition_json           jsonb NOT NULL,

    -- Optional explicit input requirement.
    fact_code                text,

    -- Expected source hierarchy for the input.
    source_method_code       text
        REFERENCES knowledge.fact_capture_method(method_code),

    -- Optional unit expected by the evaluator.
    expected_unit            text,

    -- Numeric scoring contribution.
    points                   integer NOT NULL DEFAULT 1,

    -- Whether this criterion can contribute a negative score.
    allow_negative_points    boolean NOT NULL DEFAULT false,

    rationale                text,

    sort_order               integer NOT NULL DEFAULT 0,

    -- Clinical applicability.
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',

    -- Whether the criterion is mandatory for calculation.
    required_for_calculation boolean NOT NULL DEFAULT true,

    -- Lifecycle.
    status                   text NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'draft',
                'active',
                'retired'
            )
        ),

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (score_id, component_code)
);


COMMENT ON TABLE knowledge.severity_score_component IS
'Machine-evaluable point-bearing criterion belonging to a governed severity score. The CPU evaluates condition_json against structured clinical facts; the UI never calculates points.';


COMMENT ON COLUMN knowledge.severity_score_component.condition_json IS
'Declarative scoring expression. Must identify the required fact and comparator without embedding executable SQL or application code.';


CREATE INDEX IF NOT EXISTS
    idx_severity_score_component_score
ON knowledge.severity_score_component(score_id, sort_order);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_component_version
ON knowledge.severity_score_component(version_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_component_fact
ON knowledge.severity_score_component(fact_code);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_component_source
ON knowledge.severity_score_component(source_claim_code);


DROP TRIGGER IF EXISTS
    trg_knowledge_severity_score_component_updated_at
ON knowledge.severity_score_component;


CREATE TRIGGER
    trg_knowledge_severity_score_component_updated_at
BEFORE UPDATE ON knowledge.severity_score_component
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 5. SEVERITY SCORE COMPONENT ALTERNATIVE
-- =============================================================================
--
-- Some clinical scores have OR logic:
--
--     SBP below threshold OR DBP below threshold
--
-- This table prevents the component itself from becoming an opaque blob.
--
-- A component may have several machine-evaluable alternatives.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_component_condition (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    component_id             uuid NOT NULL
        REFERENCES knowledge.severity_score_component(id)
        ON DELETE CASCADE,

    condition_code            text NOT NULL,

    fact_code                 text,

    condition_json            jsonb NOT NULL,

    evaluation_group          integer NOT NULL DEFAULT 1,

    logical_operator          text NOT NULL DEFAULT 'AND'
        CHECK (
            logical_operator IN (
                'AND',
                'OR'
            )
        ),

    sort_order                integer NOT NULL DEFAULT 0,

    source_claim_code         text
        REFERENCES knowledge.source_claim(claim_code),

    created_at                timestamptz NOT NULL DEFAULT now(),

    UNIQUE (component_id, condition_code)
);


COMMENT ON TABLE knowledge.severity_score_component_condition IS
'Normalized alternatives and compound conditions for severity-score components. Supports clinically explicit AND/OR logic without hard-coded application branches.';


CREATE INDEX IF NOT EXISTS
    idx_severity_component_condition_component
ON knowledge.severity_score_component_condition(component_id);


-- =============================================================================
-- 6. SCORE INTERPRETATION
-- =============================================================================
--
-- Calculation and interpretation are deliberately separate.
--
-- Score = arithmetic.
-- Interpretation = governed clinical meaning.
--
-- Disposition must NOT be interpreted as an automatic order.
--
-- Example:
--
--      0–1  lower risk
--      2    intermediate risk
--      >=3  higher risk
--
-- Actual ranges must come from the authoritative version-specific source.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_interpretation (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES knowledge.severity_score_version(id)
        ON DELETE CASCADE,

    min_score                integer NOT NULL,

    max_score                integer NOT NULL,

    severity_code            text NOT NULL,

    severity_label           text NOT NULL,

    risk_class               text
        CHECK (
            risk_class IS NULL
            OR risk_class IN (
                'LOW',
                'INTERMEDIATE',
                'HIGH',
                'CRITICAL',
                'UNKNOWN'
            )
        ),

    disposition_code         text,

    disposition_label        text,

    recommendation           text,

    clinical_action_level    text
        CHECK (
            clinical_action_level IS NULL
            OR clinical_action_level IN (
                'INFORMATIONAL',
                'CLINICAL_SUGGESTION',
                'DECISION_SUPPORT',
                'HIGH_RISK_RECOMMENDATION',
                'HUMAN_AUTHORIZATION_REQUIRED'
            )
        ),

    human_review_required    boolean NOT NULL DEFAULT true,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    sort_order               integer NOT NULL DEFAULT 0,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_score_interpretation_range
        CHECK (min_score <= max_score),

    UNIQUE (
        score_id,
        version_id,
        min_score,
        max_score
    )
);


COMMENT ON TABLE knowledge.severity_score_interpretation IS
'Governed interpretation of a calculated score range. Interpretation is distinct from calculation and cannot itself create an autonomous clinical order.';


CREATE INDEX IF NOT EXISTS
    idx_severity_interpretation_score
ON knowledge.severity_score_interpretation(score_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_interpretation_version
ON knowledge.severity_score_interpretation(version_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_interpretation_risk
ON knowledge.severity_score_interpretation(risk_class);


DROP TRIGGER IF EXISTS
    trg_knowledge_severity_score_interpretation_updated_at
ON knowledge.severity_score_interpretation;


CREATE TRIGGER
    trg_knowledge_severity_score_interpretation_updated_at
BEFORE UPDATE ON knowledge.severity_score_interpretation
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 7. SCORE SAFETY RULE
-- =============================================================================
--
-- A score may be mathematically valid but clinically inappropriate.
--
-- Examples:
--      wrong age group
--      pregnancy
--      score not validated for the population
--      missing key input
--      conflicting observations
--      score superseded
--
-- Safety rules prevent inappropriate execution.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_safety_rule (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code                text NOT NULL UNIQUE,

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    rule_type                text NOT NULL
        CHECK (
            rule_type IN (
                'POPULATION_EXCLUSION',
                'AGE_EXCLUSION',
                'SEX_EXCLUSION',
                'PREGNANCY_EXCLUSION',
                'MISSING_DATA',
                'CONFLICTING_DATA',
                'STALE_DATA',
                'CONTRAINDICATION',
                'VALIDITY_WINDOW',
                'MANUAL_REVIEW'
            )
        ),

    condition_json            jsonb NOT NULL,

    action                    text NOT NULL
        CHECK (
            action IN (
                'BLOCK',
                'WARN',
                'REQUEST_INFORMATION',
                'REQUIRE_HUMAN_REVIEW'
            )
        ),

    message                   text NOT NULL,

    severity                  text NOT NULL DEFAULT 'WARNING'
        CHECK (
            severity IN (
                'INFO',
                'WARNING',
                'HIGH',
                'CRITICAL'
            )
        ),

    source_claim_code         text
        REFERENCES knowledge.source_claim(claim_code),

    is_active                 boolean NOT NULL DEFAULT true,

    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.severity_score_safety_rule IS
'Governed safety gates for severity scoring. A score is not clinically usable merely because arithmetic can be completed.';


CREATE INDEX IF NOT EXISTS
    idx_severity_safety_score
ON knowledge.severity_score_safety_rule(score_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_safety_type
ON knowledge.severity_score_safety_rule(rule_type);


DROP TRIGGER IF EXISTS
    trg_knowledge_severity_score_safety_rule_updated_at
ON knowledge.severity_score_safety_rule;


CREATE TRIGGER
    trg_knowledge_severity_score_safety_rule_updated_at
BEFORE UPDATE ON knowledge.severity_score_safety_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 8. SCORE VALIDATION DEFINITION
-- =============================================================================
--
-- Governance record showing that the instrument itself has undergone review.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_validation (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    validation_code          text NOT NULL UNIQUE,

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES knowledge.severity_score_version(id)
        ON DELETE CASCADE,

    validation_type          text NOT NULL
        CHECK (
            validation_type IN (
                'STRUCTURAL',
                'CALCULATION',
                'CLINICAL',
                'POPULATION',
                'IMPLEMENTATION',
                'SAFETY'
            )
        ),

    status                   text NOT NULL
        CHECK (
            status IN (
                'PENDING',
                'PASS',
                'FAIL',
                'PASS_WITH_NOTES'
            )
        ),

    validator                text,

    validation_method        text,

    validation_details       jsonb,

    notes                    text,

    validated_at             timestamptz,

    created_at               timestamptz NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.severity_score_validation IS
'Validation history for the scoring instrument itself. A mathematically correct implementation is not considered clinically validated until the appropriate validation gates pass.';


CREATE INDEX IF NOT EXISTS
    idx_severity_validation_score
ON knowledge.severity_score_validation(score_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_validation_version
ON knowledge.severity_score_validation(version_id);


-- =============================================================================
-- 9. RUNTIME SCORE EXECUTION
-- =============================================================================
--
-- One row = one CPU execution of one score for one patient/encounter/run.
--
-- Runtime rows remain empty during migration.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_run (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id),

    version_id               uuid
        REFERENCES knowledge.severity_score_version(id),

    patient_id               uuid
        REFERENCES patient.patient(id),

    encounter_id             uuid,

    reasoning_run_id         uuid
        REFERENCES knowledge.reasoning_run(run_id),

    clinical_event_id        uuid
        REFERENCES clinical.clinical_event(id)
        ON DELETE SET NULL,

    executed_at              timestamptz NOT NULL DEFAULT now(),

    status                   text NOT NULL DEFAULT 'RUNNING'
        CHECK (
            status IN (
                'RUNNING',
                'COMPLETED',
                'INCOMPLETE',
                'BLOCKED',
                'FAILED',
                'SUPERSEDED'
            )
        ),

    total_score              integer,

    maximum_possible_score   integer,

    severity_code            text,

    severity_label           text,

    risk_class               text,

    disposition_code         text,

    disposition_label        text,

    recommendation           text,

    completeness_status      text NOT NULL DEFAULT 'UNKNOWN'
        CHECK (
            completeness_status IN (
                'COMPLETE',
                'INCOMPLETE',
                'UNKNOWN'
            )
        ),

    calculation_fingerprint  text,

    input_fingerprint        text,

    engine_version           text,

    knowledge_version        text,

    governance_version       text,

    human_review_required    boolean NOT NULL DEFAULT true,

    reviewed_by              text,

    reviewed_at              timestamptz,

    clinician_override       boolean NOT NULL DEFAULT false,

    clinician_override_note  text,

    created_at               timestamptz NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.severity_score_run IS
'Runtime execution of a governed severity score for a patient/encounter. Every result is bound to the exact score definition, input state and engine version used.';


CREATE INDEX IF NOT EXISTS
    idx_severity_score_run_patient
ON knowledge.severity_score_run(patient_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_run_encounter
ON knowledge.severity_score_run(encounter_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_run_score
ON knowledge.severity_score_run(score_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_run_reasoning
ON knowledge.severity_score_run(reasoning_run_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_run_status
ON knowledge.severity_score_run(status);


-- =============================================================================
-- 10. RUNTIME COMPONENT RESULT
-- =============================================================================
--
-- Every point in a score must be explainable.
--
-- Example:
--
--      respiratory rate = 34 breaths/min
--      threshold = >=30
--      criterion met = true
--      points = 1
--
-- This table is the clinical audit trail for arithmetic.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_component_result (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_run_id             uuid NOT NULL
        REFERENCES knowledge.severity_score_run(id)
        ON DELETE CASCADE,

    component_id             uuid NOT NULL
        REFERENCES knowledge.severity_score_component(id),

    component_code           text NOT NULL,

    fact_code                text,

    fact_id                  uuid,

    fact_value               text,

    normalized_value         numeric,

    normalized_unit          text,

    observed_at              timestamptz,

    source_method_code       text
        REFERENCES knowledge.fact_capture_method(method_code),

    condition_evaluated      jsonb,

    condition_met            boolean,

    points_awarded           integer NOT NULL DEFAULT 0,

    evaluation_status        text NOT NULL DEFAULT 'PENDING'
        CHECK (
            evaluation_status IN (
                'PENDING',
                'MET',
                'NOT_MET',
                'MISSING',
                'CONFLICTING',
                'INVALID',
                'NOT_APPLICABLE'
            )
        ),

    explanation              text,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    created_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (score_run_id, component_id)
);


COMMENT ON TABLE knowledge.severity_score_component_result IS
'Machine-readable and human-auditable result of evaluating each score component against captured clinical evidence.';


CREATE INDEX IF NOT EXISTS
    idx_severity_component_result_run
ON knowledge.severity_score_component_result(score_run_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_component_result_fact
ON knowledge.severity_score_component_result(fact_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_component_result_status
ON knowledge.severity_score_component_result(evaluation_status);


-- =============================================================================
-- 11. SCORE SAFETY EVALUATION
-- =============================================================================
--
-- Records every safety gate evaluated during execution.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_safety_result (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_run_id             uuid NOT NULL
        REFERENCES knowledge.severity_score_run(id)
        ON DELETE CASCADE,

    safety_rule_id           uuid NOT NULL
        REFERENCES knowledge.severity_score_safety_rule(id),

    rule_code                text NOT NULL,

    evaluation_status        text NOT NULL
        CHECK (
            evaluation_status IN (
                'PASS',
                'WARN',
                'BLOCK',
                'REQUEST_INFORMATION',
                'REQUIRE_HUMAN_REVIEW'
            )
        ),

    condition_evaluated      jsonb,

    message                  text,

    created_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (score_run_id, safety_rule_id)
);


COMMENT ON TABLE knowledge.severity_score_safety_result IS
'Runtime record of every safety gate evaluated for a severity-score execution.';


CREATE INDEX IF NOT EXISTS
    idx_severity_safety_result_run
ON knowledge.severity_score_safety_result(score_run_id);


-- =============================================================================
-- 12. SCORE INTERPRETATION RESULT
-- =============================================================================
--
-- Keeps the calculated score and the selected interpretation explicitly
-- separate.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_interpretation_result (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_run_id             uuid NOT NULL
        REFERENCES knowledge.severity_score_run(id)
        ON DELETE CASCADE,

    interpretation_id        uuid
        REFERENCES knowledge.severity_score_interpretation(id),

    total_score              integer NOT NULL,

    severity_code            text,

    severity_label           text,

    risk_class               text,

    disposition_code         text,

    disposition_label        text,

    recommendation           text,

    human_review_required    boolean NOT NULL DEFAULT true,

    selected_at              timestamptz NOT NULL DEFAULT now(),

    UNIQUE (score_run_id)
);


COMMENT ON TABLE knowledge.severity_score_interpretation_result IS
'Runtime mapping of the calculated score to its governed interpretation. The interpretation does not itself authorize clinical action.';


-- =============================================================================
-- 13. SCORE AUDIT EVENT
-- =============================================================================
--
-- Dedicated score-level event stream.
-- Also integrates naturally with H10 governance.audit_event.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_event (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_run_id             uuid NOT NULL
        REFERENCES knowledge.severity_score_run(id)
        ON DELETE CASCADE,

    event_type               text NOT NULL
        CHECK (
            event_type IN (
                'SCORE_STARTED',
                'APPLICABILITY_CHECKED',
                'COMPONENT_EVALUATED',
                'COMPONENT_MISSING',
                'COMPONENT_CONFLICTING',
                'SAFETY_RULE_EVALUATED',
                'SCORE_COMPLETED',
                'SCORE_INCOMPLETE',
                'SCORE_BLOCKED',
                'INTERPRETATION_SELECTED',
                'HUMAN_REVIEW_REQUESTED',
                'CLINICIAN_OVERRIDE',
                'SCORE_FINALIZED',
                'SCORE_SUPERSEDED'
            )
        ),

    component_id             uuid
        REFERENCES knowledge.severity_score_component(id),

    safety_rule_id           uuid
        REFERENCES knowledge.severity_score_safety_rule(id),

    payload                  jsonb,

    actor_type               text
        CHECK (
            actor_type IS NULL
            OR actor_type IN (
                'SYSTEM',
                'CLINICIAN',
                'API_CLIENT'
            )
        ),

    actor_code               text,

    event_time               timestamptz NOT NULL DEFAULT now(),

    created_at               timestamptz NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.severity_score_event IS
'Auditable severity-score execution stream. Captures calculation, missing data, safety gates, interpretation, review and clinician override events.';


CREATE INDEX IF NOT EXISTS
    idx_severity_score_event_run
ON knowledge.severity_score_event(score_run_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_score_event_time
ON knowledge.severity_score_event(event_time);


-- =============================================================================
-- 14. SCORE PROVENANCE
-- =============================================================================
--
-- Connects:
--
-- source claim
--      ↓
-- score definition
--      ↓
-- component
--      ↓
-- clinical fact
--      ↓
-- score result
--
-- H10 remains the universal governance layer; this table is the score-specific
-- execution bridge.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.severity_score_provenance (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_run_id             uuid
        REFERENCES knowledge.severity_score_run(id)
        ON DELETE CASCADE,

    component_result_id      uuid
        REFERENCES knowledge.severity_score_component_result(id)
        ON DELETE CASCADE,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    fact_code                text,

    fact_id                  uuid,

    relationship_type        text NOT NULL
        CHECK (
            relationship_type IN (
                'SCORE_DEFINED_BY',
                'COMPONENT_DEFINED_BY',
                'INPUT_DERIVED_FROM',
                'INTERPRETATION_DEFINED_BY',
                'SAFETY_DEFINED_BY'
            )
        ),

    created_at               timestamptz NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.severity_score_provenance IS
'Clinical provenance bridge for severity scoring. Every score calculation can be traced from its governing source through its component definitions to the patient facts used at runtime.';


CREATE INDEX IF NOT EXISTS
    idx_severity_provenance_run
ON knowledge.severity_score_provenance(score_run_id);


CREATE INDEX IF NOT EXISTS
    idx_severity_provenance_claim
ON knowledge.severity_score_provenance(source_claim_code);


-- =============================================================================
-- 15. PROTOCOL ACTION — SCORE ACTION
-- =============================================================================
--
-- A protocol may request evaluation of a score.
--
-- It does not mean the protocol can blindly act on the score.
--
-- The existing protocol_action table is extended only if it exists.
--
-- =============================================================================

DO $protocol_score_action$
BEGIN

    IF to_regclass('knowledge.protocol_action') IS NOT NULL THEN

        ALTER TABLE knowledge.protocol_action
            DROP CONSTRAINT IF EXISTS protocol_action_action_type_check;

        ALTER TABLE knowledge.protocol_action
            ADD CONSTRAINT protocol_action_action_type_check
            CHECK (
                action_type IN (
                    'investigate',
                    'medicate',
                    'monitor',
                    'educate',
                    'refer',
                    'admit',
                    'advice',
                    'order_set',
                    'score'
                )
            );

    END IF;

END
$protocol_score_action$;


-- =============================================================================
-- 16. PROTOCOL → SCORE LINK
-- =============================================================================
--
-- Explicit linkage is safer than storing score codes in arbitrary JSON.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.protocol_severity_score (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    protocol_code            text NOT NULL,

    score_id                 uuid NOT NULL
        REFERENCES knowledge.severity_score(id),

    score_version_id         uuid
        REFERENCES knowledge.severity_score_version(id),

    trigger_condition        jsonb,

    required                 boolean NOT NULL DEFAULT true,

    human_review_required    boolean NOT NULL DEFAULT true,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code),

    is_active                boolean NOT NULL DEFAULT true,

    created_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        protocol_code,
        score_id,
        score_version_id
    )
);


COMMENT ON TABLE knowledge.protocol_severity_score IS
'Explicit protocol-to-severity-score linkage. A protocol may request scoring, but the resulting score remains a governed clinical decision-support output rather than an automatic treatment order.';


CREATE INDEX IF NOT EXISTS
    idx_protocol_severity_score_protocol
ON knowledge.protocol_severity_score(protocol_code);


CREATE INDEX IF NOT EXISTS
    idx_protocol_severity_score_score
ON knowledge.protocol_severity_score(score_id);


-- =============================================================================
-- 17. SCORE RESULT → H10 AUDIT BRIDGE
-- =============================================================================
--
-- Only created when H10 audit_event exists.
--
-- =============================================================================

DO $h10_score_bridge$
BEGIN

    IF to_regclass('governance.audit_event') IS NOT NULL THEN

        CREATE INDEX IF NOT EXISTS
            idx_gov_audit_severity_score
        ON governance.audit_event(entity_type, entity_id);

    END IF;

END
$h10_score_bridge$;


-- =============================================================================
-- 18. SCORE VALIDATION VIEW
-- =============================================================================
--
-- A score is clinically publishable only when:
--
--      score active
--      version active
--      components present
--      interpretations present
--      provenance present where required
--      safety definition present
--
-- This view exposes structural readiness.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_readiness AS
SELECT
    s.id,
    s.score_code,
    s.canonical_name,
    s.status AS score_status,

    sv.id AS version_id,
    sv.version_code,
    sv.status AS version_status,

    COUNT(DISTINCT c.id) AS component_count,
    COUNT(DISTINCT i.id) AS interpretation_count,
    COUNT(DISTINCT sr.id) AS safety_rule_count,

    COUNT(DISTINCT CASE
        WHEN c.required_for_calculation THEN c.id
    END) AS required_component_count,

    CASE
        WHEN s.status <> 'active'
            THEN 'NOT_READY_SCORE_INACTIVE'

        WHEN sv.id IS NULL
            THEN 'NOT_READY_NO_VERSION'

        WHEN sv.status <> 'active'
            THEN 'NOT_READY_VERSION_INACTIVE'

        WHEN COUNT(DISTINCT c.id) = 0
            THEN 'NOT_READY_NO_COMPONENTS'

        WHEN COUNT(DISTINCT i.id) = 0
            THEN 'NOT_READY_NO_INTERPRETATIONS'

        ELSE 'STRUCTURALLY_READY'
    END AS readiness_status

FROM knowledge.severity_score s

LEFT JOIN knowledge.severity_score_version sv
    ON sv.score_id = s.id
   AND sv.status = 'active'

LEFT JOIN knowledge.severity_score_component c
    ON c.score_id = s.id
   AND (
        c.version_id IS NULL
        OR c.version_id = sv.id
   )
   AND c.status = 'active'

LEFT JOIN knowledge.severity_score_interpretation i
    ON i.score_id = s.id
   AND (
        i.version_id IS NULL
        OR i.version_id = sv.id
   )

LEFT JOIN knowledge.severity_score_safety_rule sr
    ON sr.score_id = s.id
   AND sr.is_active = true

GROUP BY
    s.id,
    s.score_code,
    s.canonical_name,
    s.status,
    sv.id,
    sv.version_code,
    sv.status;


-- =============================================================================
-- 19. SCORE COMPONENT COVERAGE VIEW
-- =============================================================================
--
-- Makes incomplete score definitions visible before activation.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_component_coverage AS
SELECT
    s.score_code,
    s.canonical_name,

    c.component_code,
    c.component_name,

    c.fact_code,
    c.expected_unit,
    c.points,

    c.required_for_calculation,

    CASE
        WHEN c.fact_code IS NULL
             AND c.condition_json = '{}'::jsonb
            THEN 'MISSING_INPUT_DEFINITION'

        WHEN c.source_method_code IS NULL
            THEN 'SOURCE_METHOD_NOT_DECLARED'

        WHEN c.points IS NULL
            THEN 'POINTS_NOT_DEFINED'

        ELSE 'DEFINED'
    END AS component_definition_status

FROM knowledge.severity_score s

JOIN knowledge.severity_score_component c
    ON c.score_id = s.id

WHERE c.status = 'active';


-- =============================================================================
-- 20. SCORE INTERPRETATION OVERLAP CHECK VIEW
-- =============================================================================
--
-- Interpretation ranges must not overlap.
--
-- Example of invalid definition:
--
--      0–2
--      2–4
--
-- because score 2 has two meanings.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_interpretation_conflicts AS
SELECT
    a.score_id,

    a.id AS interpretation_a_id,
    a.min_score AS a_min_score,
    a.max_score AS a_max_score,

    b.id AS interpretation_b_id,
    b.min_score AS b_min_score,
    b.max_score AS b_max_score

FROM knowledge.severity_score_interpretation a

JOIN knowledge.severity_score_interpretation b
    ON a.score_id = b.score_id
   AND a.id < b.id
   AND a.min_score <= b.max_score
   AND b.min_score <= a.max_score;


-- =============================================================================
-- 21. SCORE EXECUTION COMPLETENESS VIEW
-- =============================================================================
--
-- Runtime clinical safety:
--
-- A score cannot be represented as complete merely because total_score exists.
--
-- All required components must have an acceptable evaluation state.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_run_completeness AS
SELECT
    r.id AS score_run_id,
    r.score_id,
    r.version_id,

    COUNT(c.id) AS required_component_count,

    COUNT(cr.id) AS evaluated_component_count,

    COUNT(
        CASE
            WHEN cr.evaluation_status IN ('MET','NOT_MET')
                THEN 1
        END
    ) AS valid_component_count,

    COUNT(
        CASE
            WHEN cr.evaluation_status IN (
                'MISSING',
                'CONFLICTING',
                'INVALID',
                'NOT_APPLICABLE'
            )
                THEN 1
        END
    ) AS unresolved_component_count,

    CASE
        WHEN COUNT(c.id) = 0
            THEN 'NO_COMPONENTS'

        WHEN COUNT(cr.id) < COUNT(c.id)
            THEN 'INCOMPLETE'

        WHEN COUNT(
            CASE
                WHEN cr.evaluation_status IN (
                    'MISSING',
                    'CONFLICTING',
                    'INVALID'
                )
                    THEN 1
            END
        ) > 0
            THEN 'INCOMPLETE'

        ELSE 'COMPLETE'
    END AS calculated_completeness

FROM knowledge.severity_score_run r

JOIN knowledge.severity_score_component c
    ON c.score_id = r.score_id
   AND c.required_for_calculation = true
   AND c.status = 'active'

LEFT JOIN knowledge.severity_score_component_result cr
    ON cr.score_run_id = r.id
   AND cr.component_id = c.id

GROUP BY
    r.id,
    r.score_id,
    r.version_id;


-- =============================================================================
-- 22. CURB-65 KNOWLEDGE DEFINITION
-- =============================================================================
--
-- The following seed is deliberately provenance-aware.
--
-- CURB-65:
--
-- C = confusion
-- U = urea elevation
-- R = respiratory rate >= 30/min
-- B = low blood pressure:
--       systolic < 90 mmHg
--       OR diastolic <= 60 mmHg
-- 65 = age >= 65 years
--
-- Each criterion contributes 1 point.
--
-- The score is a severity/risk stratification instrument for adults with
-- community-acquired pneumonia.
--
-- IMPORTANT:
-- CURB-65 is not itself a substitute for clinical assessment.
-- Oxygenation, work of breathing, sepsis, comorbidity, social circumstances,
-- ability to take oral therapy, organ dysfunction and clinician judgement may
-- independently change management.
--
-- The interpretation ranges below are kept as governed knowledge and must be
-- linked to the AMEXAN-approved source before activation.
--
-- =============================================================================


INSERT INTO knowledge.severity_score (
    score_code,
    canonical_name,
    description,
    condition_code,
    population,
    minimum_age_years,
    maximum_age_years,
    clinical_use,
    missing_data_policy,
    minimum_score,
    maximum_score,
    status
)
VALUES (
    'SCORE-CURB65',
    'CURB-65',
    'Clinical severity and mortality-risk scoring instrument for adults with community-acquired pneumonia using confusion, urea, respiratory rate, blood pressure and age 65 years or older.',
    'CONDITION-COMMUNITY-ACQUIRED-PNEUMONIA',
    'adult',
    18,
    NULL,
    'SEVERITY_AND_RISK',
    'REQUEST_INFORMATION',
    0,
    5,
    'draft'
)
ON CONFLICT (score_code) DO NOTHING;


-- =============================================================================
-- 23. CURB-65 VERSION
-- =============================================================================

INSERT INTO knowledge.severity_score_version (
    score_id,
    version_no,
    version_code,
    change_note,
    status
)
SELECT
    s.id,
    1,
    'SCORE-CURB65-V1',
    'Initial AMEXAN structured implementation of CURB-65. Clinical activation requires source validation and governance approval.',
    'draft'
FROM knowledge.severity_score s
WHERE s.score_code = 'SCORE-CURB65'
  AND NOT EXISTS (
      SELECT 1
      FROM knowledge.severity_score_version v
      WHERE v.version_code = 'SCORE-CURB65-V1'
  );


-- =============================================================================
-- 24. CURB-65 COMPONENTS
-- =============================================================================

INSERT INTO knowledge.severity_score_component (
    score_id,
    version_id,
    component_code,
    component_name,
    description,
    condition_json,
    fact_code,
    expected_unit,
    points,
    rationale,
    sort_order,
    required_for_calculation,
    status
)
SELECT
    s.id,
    v.id,
    x.component_code,
    x.component_name,
    x.description,
    x.condition_json,
    x.fact_code,
    x.expected_unit,
    x.points,
    x.rationale,
    x.sort_order,
    true,
    'active'
FROM knowledge.severity_score s
JOIN knowledge.severity_score_version v
    ON v.score_id = s.id
   AND v.version_code = 'SCORE-CURB65-V1'
CROSS JOIN (
    VALUES
    (
        'CURB65-CONFUSION',
        'Confusion',
        'New mental-status disturbance / confusion criterion.',
        '{"type":"clinical_fact","fact_code":"MENTAL_STATUS_CONFUSION","operator":"=","value":true}'::jsonb,
        'MENTAL_STATUS_CONFUSION',
        NULL,
        1,
        'One point when the governed clinical definition of confusion is met.',
        1
    ),
    (
        'CURB65-UREA',
        'Urea',
        'Raised blood urea criterion.',
        '{"type":"laboratory_value","fact_code":"UREA","operator":">","value":7,"unit":"mmol/L"}'::jsonb,
        'UREA',
        'mmol/L',
        1,
        'One point when blood urea exceeds the governed threshold.',
        2
    ),
    (
        'CURB65-RESPIRATORY-RATE',
        'Respiratory rate',
        'Tachypnoea criterion.',
        '{"type":"vital_sign","fact_code":"RESPIRATORY_RATE","operator":">=","value":30,"unit":"breaths/min"}'::jsonb,
        'RESPIRATORY_RATE',
        'breaths/min',
        1,
        'One point when respiratory rate is at least 30 breaths per minute.',
        3
    ),
    (
        'CURB65-BLOOD-PRESSURE',
        'Blood pressure',
        'Hypotension criterion.',
        '{"type":"compound","operator":"OR","conditions":[{"fact_code":"SYSTOLIC_BP","operator":"<","value":90,"unit":"mmHg"},{"fact_code":"DIASTOLIC_BP","operator":"<=","value":60,"unit":"mmHg"}]}'::jsonb,
        NULL,
        'mmHg',
        1,
        'One point when systolic blood pressure is below 90 mmHg or diastolic blood pressure is 60 mmHg or below.',
        4
    ),
    (
        'CURB65-AGE',
        'Age 65 years or older',
        'Age criterion.',
        '{"type":"demographic","fact_code":"AGE_YEARS","operator":">=","value":65,"unit":"years"}'::jsonb,
        'AGE_YEARS',
        'years',
        1,
        'One point when age is 65 years or older.',
        5
    )
) AS x(
    component_code,
    component_name,
    description,
    condition_json,
    fact_code,
    expected_unit,
    points,
    rationale,
    sort_order
)
ON CONFLICT (score_id, component_code) DO NOTHING;


-- =============================================================================
-- 25. CURB-65 BLOOD PRESSURE COMPOUND CONDITIONS
-- =============================================================================

INSERT INTO knowledge.severity_score_component_condition (
    component_id,
    condition_code,
    fact_code,
    condition_json,
    evaluation_group,
    logical_operator,
    sort_order
)
SELECT
    c.id,
    x.condition_code,
    x.fact_code,
    x.condition_json,
    1,
    'OR',
    x.sort_order
FROM knowledge.severity_score_component c
JOIN knowledge.severity_score s
    ON s.id = c.score_id
CROSS JOIN (
    VALUES
    (
        'CURB65-BP-SBP',
        'SYSTOLIC_BP',
        '{"fact_code":"SYSTOLIC_BP","operator":"<","value":90,"unit":"mmHg"}'::jsonb,
        1
    ),
    (
        'CURB65-BP-DBP',
        'DIASTOLIC_BP',
        '{"fact_code":"DIASTOLIC_BP","operator":"<=","value":60,"unit":"mmHg"}'::jsonb,
        2
    )
) AS x(
    condition_code,
    fact_code,
    condition_json,
    sort_order
)
WHERE c.component_code = 'CURB65-BLOOD-PRESSURE'
  AND s.score_code = 'SCORE-CURB65'
ON CONFLICT (component_id, condition_code) DO NOTHING;


-- =============================================================================
-- 26. CURB-65 INTERPRETATION
-- =============================================================================
--
-- These are structured interpretation bands.
--
-- Disposition is intentionally expressed as clinical guidance rather than
-- an automatic order.
--
-- The exact disposition policy may vary by guideline, setting and patient.
--
-- =============================================================================

INSERT INTO knowledge.severity_score_interpretation (
    score_id,
    version_id,
    min_score,
    max_score,
    severity_code,
    severity_label,
    risk_class,
    disposition_code,
    disposition_label,
    recommendation,
    clinical_action_level,
    human_review_required,
    sort_order
)
SELECT
    s.id,
    v.id,
    x.min_score,
    x.max_score,
    x.severity_code,
    x.severity_label,
    x.risk_class,
    x.disposition_code,
    NULL,
    x.recommendation,
    x.clinical_action_level,
    true,
    x.sort_order
FROM knowledge.severity_score s
JOIN knowledge.severity_score_version v
    ON v.score_id = s.id
   AND v.version_code = 'SCORE-CURB65-V1'
CROSS JOIN (
    VALUES
    (
        0,
        1,
        'CURB65-LOW',
        'Lower severity',
        'LOW',
        'ASSESS_OUTPATIENT',
        'Consider outpatient management when clinically appropriate.',
        'DECISION_SUPPORT',
        1
    ),
    (
        2,
        2,
        'CURB65-MODERATE',
        'Intermediate severity',
        'INTERMEDIATE',
        'CONSIDER_ADMISSION',
        'Consider hospital assessment/admission according to the complete clinical picture and local protocol.',
        'DECISION_SUPPORT',
        2
    ),
    (
        3,
        5,
        'CURB65-HIGH',
        'Higher severity',
        'HIGH',
        'URGENT_HOSPITAL_ASSESSMENT',
        'Urgent hospital assessment is appropriate; consider higher-acuity care according to physiology, organ dysfunction and local protocol.',
        'HIGH_RISK_RECOMMENDATION',
        3
    )
) AS x(
    min_score,
    max_score,
    severity_code,
    severity_label,
    risk_class,
    disposition_code,
    recommendation,
    clinical_action_level,
    sort_order
)
WHERE s.score_code = 'SCORE-CURB65'
ON CONFLICT (
    score_id,
    version_id,
    min_score,
    max_score
) DO NOTHING;


-- =============================================================================
-- 27. CURB-65 SAFETY RULES
-- =============================================================================

INSERT INTO knowledge.severity_score_safety_rule (
    rule_code,
    score_id,
    rule_type,
    condition_json,
    action,
    message,
    severity,
    is_active
)
SELECT
    x.rule_code,
    s.id,
    x.rule_type,
    x.condition_json,
    x.action,
    x.message,
    x.severity,
    true
FROM knowledge.severity_score s
CROSS JOIN (
    VALUES
    (
        'CURB65-SAFETY-ADULT',
        'POPULATION_EXCLUSION',
        '{"population":{"operator":"not_equals","value":"adult"}}'::jsonb,
        'BLOCK',
        'CURB-65 is being evaluated outside its governed adult population.',
        'HIGH'
    ),
    (
        'CURB65-SAFETY-MISSING',
        'MISSING_DATA',
        '{"required_components_missing":true}'::jsonb,
        'REQUEST_INFORMATION',
        'Required CURB-65 information is missing; do not assume absent findings.',
        'HIGH'
    ),
    (
        'CURB65-SAFETY-CONFLICT',
        'CONFLICTING_DATA',
        '{"conflicting_source_facts":true}'::jsonb,
        'REQUIRE_HUMAN_REVIEW',
        'Conflicting clinical inputs are present; resolve the source discrepancy before relying on the score.',
        'HIGH'
    ),
    (
        'CURB65-SAFETY-CLINICAL',
        'MANUAL_REVIEW',
        '{"always":true}'::jsonb,
        'REQUIRE_HUMAN_REVIEW',
        'CURB-65 supplements clinical assessment and must not replace assessment of hypoxaemia, respiratory distress, sepsis, organ dysfunction, comorbidity or other immediate clinical risk.',
        'WARNING'
    )
) AS x(
    rule_code,
    rule_type,
    condition_json,
    action,
    message,
    severity
)
WHERE s.score_code = 'SCORE-CURB65'
ON CONFLICT (rule_code) DO NOTHING;


-- =============================================================================
-- 28. STRUCTURAL VALIDATION FOR EVERY SCORE
-- =============================================================================
--
-- Database-level validation trigger:
-- active score versions cannot be empty.
--
-- The trigger is deliberately not used to force clinical approval because
-- governance approval belongs to H10.
--
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_severity_score_definition(
    p_score_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_component_count integer;
    v_interpretation_count integer;
BEGIN

    SELECT COUNT(*)
    INTO v_component_count
    FROM knowledge.severity_score_component
    WHERE score_id = p_score_id
      AND status = 'active';

    SELECT COUNT(*)
    INTO v_interpretation_count
    FROM knowledge.severity_score_interpretation
    WHERE score_id = p_score_id;

    IF v_component_count = 0 THEN
        RAISE EXCEPTION
            'Severity score % has no active components',
            p_score_id;
    END IF;

    IF v_interpretation_count = 0 THEN
        RAISE EXCEPTION
            'Severity score % has no interpretations',
            p_score_id;
    END IF;

END;
$$;


-- =============================================================================
-- 29. NO-OVERLAPPING INTERPRETATIONS
-- =============================================================================
--
-- PostgreSQL exclusion constraints are not used because integer ranges and
-- versioned NULL semantics vary between installations. Validation is exposed
-- through the conflict view and can be enforced by the CPU publication gate.
--
-- =============================================================================


-- =============================================================================
-- 30. SCORE PUBLICATION READINESS FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.severity_score_publication_ready(
    p_score_id uuid,
    p_version_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_score_status text;
    v_version_status text;
    v_component_count integer;
    v_interpretation_count integer;
    v_safety_count integer;
    v_conflicts integer;
BEGIN

    SELECT status
    INTO v_score_status
    FROM knowledge.severity_score
    WHERE id = p_score_id;

    SELECT status
    INTO v_version_status
    FROM knowledge.severity_score_version
    WHERE id = p_version_id
      AND score_id = p_score_id;

    IF v_score_status IS DISTINCT FROM 'active' THEN
        RETURN false;
    END IF;

    IF v_version_status IS DISTINCT FROM 'active' THEN
        RETURN false;
    END IF;

    SELECT COUNT(*)
    INTO v_component_count
    FROM knowledge.severity_score_component
    WHERE score_id = p_score_id
      AND (
          version_id IS NULL
          OR version_id = p_version_id
      )
      AND status = 'active';

    IF v_component_count = 0 THEN
        RETURN false;
    END IF;

    SELECT COUNT(*)
    INTO v_interpretation_count
    FROM knowledge.severity_score_interpretation
    WHERE score_id = p_score_id
      AND (
          version_id IS NULL
          OR version_id = p_version_id
      );

    IF v_interpretation_count = 0 THEN
        RETURN false;
    END IF;

    SELECT COUNT(*)
    INTO v_safety_count
    FROM knowledge.severity_score_safety_rule
    WHERE score_id = p_score_id
      AND is_active = true;

    IF v_safety_count = 0 THEN
        RETURN false;
    END IF;

    SELECT COUNT(*)
    INTO v_conflicts
    FROM knowledge.v_severity_score_interpretation_conflicts c
    WHERE c.score_id = p_score_id;

    IF v_conflicts > 0 THEN
        RETURN false;
    END IF;

    RETURN true;

END;
$$;


COMMENT ON FUNCTION knowledge.severity_score_publication_ready(uuid, uuid) IS
'Governance gate for activating a severity score version. Structural validity is necessary but does not replace H10 clinical approval.';


-- =============================================================================
-- 31. SCORE CALCULATION CONTRACT
-- =============================================================================
--
-- This function does NOT perform the clinical calculation.
--
-- It defines the runtime contract exposed to the CPU.
--
-- The application/CPU must:
--
-- 1. resolve patient population;
-- 2. resolve exact score version;
-- 3. resolve source facts;
-- 4. normalize units;
-- 5. evaluate each condition;
-- 6. record component_result;
-- 7. enforce missing/conflicting-data policy;
-- 8. apply safety rules;
-- 9. sum points;
-- 10. select interpretation;
-- 11. write score_run;
-- 12. write audit/provenance;
-- 13. request human review where required.
--
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.get_severity_score_contract(
    p_score_code text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_score_id uuid;
BEGIN

    SELECT id
    INTO v_score_id
    FROM knowledge.severity_score
    WHERE score_code = p_score_code;

    IF v_score_id IS NULL THEN
        RAISE EXCEPTION
            'Unknown severity score: %',
            p_score_code;
    END IF;

    RETURN jsonb_build_object(
        'score_code', p_score_code,

        'execution_order', jsonb_build_array(
            'RESOLVE_SCORE_VERSION',
            'CHECK_POPULATION',
            'RESOLVE_REQUIRED_FACTS',
            'NORMALIZE_UNITS',
            'EVALUATE_COMPONENTS',
            'CHECK_MISSING_DATA',
            'CHECK_CONFLICTING_DATA',
            'EVALUATE_SAFETY_RULES',
            'CALCULATE_TOTAL',
            'SELECT_INTERPRETATION',
            'WRITE_PROVENANCE',
            'WRITE_AUDIT_EVENT',
            'REQUEST_HUMAN_REVIEW'
        ),

        'clinical_laws', jsonb_build_array(
            'UNKNOWN_IS_NOT_NEGATIVE',
            'SCORE_DOES_NOT_CREATE_FACTS',
            'SCORE_DOES_NOT_REPLACE_CLINICAL_ASSESSMENT',
            'INTERPRETATION_IS_SEPARATE_FROM_CALCULATION',
            'DISPOSITION_IS_NOT_AN_AUTOMATIC_ORDER',
            'EVERY_COMPONENT_MUST_BE_AUDITABLE',
            'EVERY_RESULT_IS_VERSION_BOUND',
            'CLINICIAN_OVERRIDE_MUST_BE_PRESERVED'
        )
    );

END;
$$;


-- =============================================================================
-- 32. RUNTIME SCORE RESULT VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_result AS
SELECT
    r.id AS score_run_id,

    s.score_code,
    s.canonical_name,

    r.patient_id,
    r.encounter_id,
    r.reasoning_run_id,

    r.status,

    r.total_score,
    r.maximum_possible_score,

    r.completeness_status,

    r.severity_code,
    r.severity_label,

    r.risk_class,

    r.disposition_code,
    r.disposition_label,

    r.recommendation,

    r.human_review_required,

    r.clinician_override,

    r.engine_version,
    r.knowledge_version,
    r.governance_version,

    r.executed_at

FROM knowledge.severity_score_run r

JOIN knowledge.severity_score s
    ON s.id = r.score_id;


-- =============================================================================
-- 33. RUNTIME SCORE EXPLANATION VIEW
-- =============================================================================
--
-- Designed for AMEXAN clinical UI rendering.
--
-- The UI receives already-evaluated information.
-- It does not calculate points.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_explanation AS
SELECT
    r.id AS score_run_id,

    s.score_code,
    s.canonical_name,

    c.component_code,
    c.component_name,

    cr.fact_code,
    cr.fact_value,
    cr.normalized_value,
    cr.normalized_unit,

    cr.condition_evaluated,

    cr.condition_met,
    cr.points_awarded,

    cr.evaluation_status,

    cr.explanation,

    cr.observed_at

FROM knowledge.severity_score_run r

JOIN knowledge.severity_score s
    ON s.id = r.score_id

JOIN knowledge.severity_score_component c
    ON c.score_id = s.id

LEFT JOIN knowledge.severity_score_component_result cr
    ON cr.score_run_id = r.id
   AND cr.component_id = c.id;


-- =============================================================================
-- 34. SCORE EVENT → H10 AUDIT INTEGRATION
-- =============================================================================
--
-- If H10 is present, the CPU may mirror score events into governance.audit_event.
-- The trigger intentionally records only state-changing score events.
--
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.audit_severity_score_event()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF to_regclass('governance.audit_event') IS NOT NULL THEN

        INSERT INTO governance.audit_event (
            event_type,
            actor_type,
            actor_code,
            entity_type,
            entity_id,
            entity_code,
            run_id,
            occurred_at
        )
        SELECT
            CASE
                WHEN NEW.event_type = 'SCORE_STARTED'
                    THEN 'RULE_EVALUATED'
                WHEN NEW.event_type = 'SCORE_COMPLETED'
                    THEN 'RULE_EVALUATED'
                WHEN NEW.event_type = 'INTERPRETATION_SELECTED'
                    THEN 'RULE_EVALUATED'
                WHEN NEW.event_type = 'CLINICIAN_OVERRIDE'
                    THEN 'SENTENCE_EDITED'
                ELSE 'RULE_EVALUATED'
            END,
            COALESCE(NEW.actor_type, 'SYSTEM'),
            NEW.actor_code,
            'severity_score_run',
            NEW.score_run_id,
            s.score_code,
            r.reasoning_run_id,
            NEW.event_time

        FROM knowledge.severity_score_run r

        JOIN knowledge.severity_score s
            ON s.id = r.score_id

        WHERE r.id = NEW.score_run_id;

    END IF;

    RETURN NEW;

END;
$$;


DROP TRIGGER IF EXISTS
    trg_severity_score_event_h10_audit
ON knowledge.severity_score_event;


CREATE TRIGGER
    trg_severity_score_event_h10_audit
AFTER INSERT ON knowledge.severity_score_event
FOR EACH ROW
EXECUTE FUNCTION knowledge.audit_severity_score_event();


-- =============================================================================
-- 35. SCORE VERSION FINGERPRINT
-- =============================================================================
--
-- Used by the CPU when generating deterministic calculation_fingerprint.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_version_fingerprint AS
SELECT
    v.id AS version_id,
    v.version_code,

    md5(
        concat_ws(
            '|',

            v.version_code,

            COALESCE(
                string_agg(
                    c.component_code
                    || ':'
                    || c.condition_json::text
                    || ':'
                    || c.points::text,
                    '||'
                    ORDER BY c.sort_order, c.component_code
                ),
                ''
            ),

            COALESCE(
                string_agg(
                    i.min_score::text
                    || ':'
                    || i.max_score::text
                    || ':'
                    || i.severity_code,
                    '||'
                    ORDER BY i.min_score, i.max_score
                ),
                ''
            )
        )
    ) AS definition_fingerprint

FROM knowledge.severity_score_version v

LEFT JOIN knowledge.severity_score_component c
    ON c.version_id = v.id
   AND c.status = 'active'

LEFT JOIN knowledge.severity_score_interpretation i
    ON i.version_id = v.id

GROUP BY
    v.id,
    v.version_code;


-- =============================================================================
-- 36. CLINICAL SCORE CATALOGUE
-- =============================================================================
--
-- Central registry view for future score families.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_severity_score_catalogue AS
SELECT
    s.score_code,
    s.canonical_name,
    s.condition_code,
    s.population,
    s.clinical_use,

    s.minimum_score,
    s.maximum_score,

    s.status,

    v.version_code,
    v.status AS version_status,

    COUNT(DISTINCT c.id) AS component_count,
    COUNT(DISTINCT i.id) AS interpretation_count,
    COUNT(DISTINCT sr.id) AS safety_rule_count,

    CASE
        WHEN s.status = 'active'
         AND v.status = 'active'
         AND COUNT(DISTINCT c.id) > 0
         AND COUNT(DISTINCT i.id) > 0
         AND COUNT(DISTINCT sr.id) > 0
        THEN true
        ELSE false
    END AS executable_structure_ready

FROM knowledge.severity_score s

LEFT JOIN knowledge.severity_score_version v
    ON v.score_id = s.id
   AND v.status = 'active'

LEFT JOIN knowledge.severity_score_component c
    ON c.score_id = s.id
   AND c.status = 'active'
   AND (
        c.version_id IS NULL
        OR c.version_id = v.id
   )

LEFT JOIN knowledge.severity_score_interpretation i
    ON i.score_id = s.id
   AND (
        i.version_id IS NULL
        OR i.version_id = v.id
   )

LEFT JOIN knowledge.severity_score_safety_rule sr
    ON sr.score_id = s.id
   AND sr.is_active = true

GROUP BY
    s.score_code,
    s.canonical_name,
    s.condition_code,
    s.population,
    s.clinical_use,
    s.minimum_score,
    s.maximum_score,
    s.status,
    v.version_code,
    v.status;


-- =============================================================================
-- 37. CONSTITUTIONAL COMMENTS
-- =============================================================================

COMMENT ON SCHEMA knowledge IS
'AMEXAN Clinical Knowledge Layer. Severity scoring definitions are governed clinical knowledge; runtime evaluation belongs to the CPU.';


COMMENT ON FUNCTION knowledge.severity_score_publication_ready(uuid, uuid) IS
'AMEXAN clinical governance gate: a severity instrument must have an active score, active version, active components, interpretations, safety rules and no interpretation overlap before executable publication. H10 human approval remains mandatory for clinical activation.';


-- =============================================================================
-- 38. MIGRATION SELF-CHECK
-- =============================================================================

DO $severity_migration_check$
DECLARE
    v_missing integer := 0;
BEGIN

    IF to_regclass('knowledge.severity_score') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_version') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_component') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_interpretation') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_safety_rule') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_run') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_component_result') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF to_regclass('knowledge.severity_score_event') IS NULL THEN
        v_missing := v_missing + 1;
    END IF;

    IF v_missing > 0 THEN
        RAISE EXCEPTION
            'AMEXAN Migration 037 failed structural self-check: % required objects missing',
            v_missing;
    END IF;

    RAISE NOTICE
        'AMEXAN Phase 2 Migration 037 OK: structured severity scoring, versioning, safety, runtime evaluation, provenance, audit and CURB-65 definition installed.';

END
$severity_migration_check$;


COMMIT;