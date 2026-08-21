-- =============================================================================
-- AMEXAN Medical Knowledge Compiler
-- H5 â€” UNIVERSAL CONTEXT ENGINE
-- Migration 029
--
-- PURPOSE
-- -------
-- H4 answers:
--     "What can be explored about a symptom?"
--
-- H5 answers:
--     "How should that same clinical information be elicited,
--      captured, interpreted and documented for THIS patient,
--      THIS historian, THIS encounter and THIS communication context?"
--
-- ARCHITECTURAL LAW
-- -----------------
--
-- PostgreSQL = KNOWLEDGE + CONFIGURATION
-- CPU        = DECISION / EXECUTION
-- UI         = RENDERING
--
-- The CPU MUST NOT invent medical adaptation rules.
-- The UI MUST NOT decide medical relevance.
--
-- CONSTITUTIONAL FACT IDENTITY RULE
-- ---------------------------------
--
-- Context may alter:
--     â€¢ wording
--     â€¢ historian
--     â€¢ capture method
--     â€¢ response surface
--     â€¢ priority
--     â€¢ availability
--     â€¢ functional interpretation
--     â€¢ documentation pathway
--
-- Context MUST NOT alter:
--     â€¢ canonical fact identity
--
-- Example:
--
-- Adult:
--     "How far can you walk before becoming short of breath?"
--
-- Parent of child:
--     "Does he stop playing or running because he becomes short of breath?"
--
-- Infant:
--     "Does the baby stop feeding, pause frequently or become breathless
--      during feeds?"
--
-- These may all normalize to:
--
--     EXERCISE_TOLERANCE / FUNCTIONAL_RESPIRATORY_LIMITATION
--
-- They are NOT separate clinical facts merely because their elicitation
-- pathways differ.
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. EXTENSIONS / SCHEMA SAFETY
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS knowledge;


-- =============================================================================
-- 1. CLINICAL CONTEXT
-- =============================================================================
--
-- A patient can simultaneously possess multiple contexts:
--
--     CHILD
--     FEMALE
--     PREGNANCY
--     EMERGENCY
--     CAREGIVER_HISTORIAN
--     LANGUAGE_BARRIER
--     IN_PERSON
--
-- The CPU therefore constructs a CONTEXT STACK rather than executing a single
-- age-based IF statement.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_context (
    context_id                 text PRIMARY KEY,
    code                       text NOT NULL UNIQUE,

    category                   text NOT NULL
        CHECK (
            category IN (
                'AGE',
                'REPRODUCTIVE',
                'SETTING',
                'MODE',
                'HISTORIAN',
                'COMMUNICATION',
                'COGNITION',
                'ENCOUNTER_PURPOSE'
            )
        ),

    label                      text NOT NULL,
    description                text,

    applies_to_questions       boolean NOT NULL DEFAULT true,
    applies_to_exam            boolean NOT NULL DEFAULT true,

    priority_weight            numeric(5,3) NOT NULL DEFAULT 1.000
        CHECK (priority_weight >= 0),

    status                     text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at                 timestamptz NOT NULL DEFAULT now(),
    updated_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_context_category
    ON knowledge.clinical_context(category);

CREATE INDEX IF NOT EXISTS idx_clinical_context_status
    ON knowledge.clinical_context(status);

DROP TRIGGER IF EXISTS trg_knowledge_clinical_context_updated_at
    ON knowledge.clinical_context;

CREATE TRIGGER trg_knowledge_clinical_context_updated_at
    BEFORE UPDATE ON knowledge.clinical_context
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


COMMENT ON TABLE knowledge.clinical_context IS
'Canonical clinical contexts. A patient may carry multiple contexts simultaneously; the CPU evaluates the complete context stack.';


-- =============================================================================
-- 2. DEVELOPMENTAL STAGE
-- =============================================================================
--
-- Age is clinically contextual.
--
-- These are ENGINE DEFAULTS, not immutable medical truth.
-- Institutional protocols may later override or extend them.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.developmental_stage (
    stage_code          text PRIMARY KEY,
    label               text NOT NULL,

    min_age_days        numeric NOT NULL
        CHECK (min_age_days >= 0),

    max_age_days        numeric
        CHECK (max_age_days IS NULL OR max_age_days >= min_age_days),

    sort_order          integer NOT NULL,

    description         text,

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (min_age_days, max_age_days)
);

CREATE INDEX IF NOT EXISTS idx_developmental_stage_range
    ON knowledge.developmental_stage(min_age_days, max_age_days);

DROP TRIGGER IF EXISTS trg_knowledge_developmental_stage_updated_at
    ON knowledge.developmental_stage;

CREATE TRIGGER trg_knowledge_developmental_stage_updated_at
    BEFORE UPDATE ON knowledge.developmental_stage
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. HISTORIAN TYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.historian_type (
    type_code           text PRIMARY KEY,
    label               text NOT NULL,

    is_patient           boolean NOT NULL DEFAULT false,

    description         text,
    sort_order          integer NOT NULL,

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_knowledge_historian_type_updated_at
    ON knowledge.historian_type;

CREATE TRIGGER trg_knowledge_historian_type_updated_at
    BEFORE UPDATE ON knowledge.historian_type
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 4. HISTORIAN RELIABILITY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.historian_reliability (
    reliability_code   text PRIMARY KEY,
    label              text NOT NULL,

    sort_order         integer NOT NULL,

    description        text,

    status             text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_knowledge_historian_reliability_updated_at
    ON knowledge.historian_reliability;

CREATE TRIGGER trg_knowledge_historian_reliability_updated_at
    BEFORE UPDATE ON knowledge.historian_reliability
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 5. COMMUNICATION CONTEXT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.communication_context (
    factor_code        text PRIMARY KEY,

    context_type_code  text
        REFERENCES knowledge.context_type(code),

    label              text NOT NULL,
    description        text,

    sort_order         integer NOT NULL,

    status             text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_communication_context_type
    ON knowledge.communication_context(context_type_code);

DROP TRIGGER IF EXISTS trg_knowledge_communication_context_updated_at
    ON knowledge.communication_context;

CREATE TRIGGER trg_knowledge_communication_context_updated_at
    BEFORE UPDATE ON knowledge.communication_context
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 6. ENCOUNTER MODE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.encounter_mode (
    mode_code                    text PRIMARY KEY,

    label                        text NOT NULL,

    supports_auscultation        boolean NOT NULL DEFAULT true,
    supports_inspection          boolean NOT NULL DEFAULT true,
    supports_device_readings     boolean NOT NULL DEFAULT true,
    supports_palpation          boolean NOT NULL DEFAULT true,
    supports_percussion         boolean NOT NULL DEFAULT true,
    supports_direct_observation boolean NOT NULL DEFAULT true,

    description                  text,

    sort_order                   integer NOT NULL,

    status                       text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at                   timestamptz NOT NULL DEFAULT now(),
    updated_at                   timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_knowledge_encounter_mode_updated_at
    ON knowledge.encounter_mode;

CREATE TRIGGER trg_knowledge_encounter_mode_updated_at
    BEFORE UPDATE ON knowledge.encounter_mode
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 7. RESPONSE MODE
-- =============================================================================
--
-- How information enters the system.
--
-- This is NOT the same as the historian.
--
-- Example:
--
--     historian = PARENT
--     response_mode = CAREGIVER_REPORT
--
-- OR:
--
--     historian = PATIENT
--     response_mode = SELF_REPORT
--
-- OR:
--
--     historian = PATIENT
--     response_mode = OBSERVATION
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.response_mode (
    mode_code            text PRIMARY KEY,

    label                text NOT NULL,

    is_patient_facing    boolean NOT NULL DEFAULT true,

    description          text,

    sort_order           integer NOT NULL,

    status               text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_knowledge_response_mode_updated_at
    ON knowledge.response_mode;

CREATE TRIGGER trg_knowledge_response_mode_updated_at
    BEFORE UPDATE ON knowledge.response_mode
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 8. RESPONSE VARIANT
-- =============================================================================
--
-- Same canonical response.
-- Different presentation.
--
-- Adult pain:
--     numeric 0-10
--
-- Young child:
--     faces scale
--
-- Infant:
--     observable behavioural indicators
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.response_variant (
    variant_id                   text PRIMARY KEY,

    response_type                text NOT NULL,
    variant_name                 text NOT NULL,

    applicable_context_codes     text[] NOT NULL DEFAULT '{}',

    min_age_days                 numeric,
    max_age_days                 numeric,

    is_active                    boolean NOT NULL DEFAULT true,

    description                  text,

    created_at                   timestamptz NOT NULL DEFAULT now(),
    updated_at                   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_response_variant_type
    ON knowledge.response_variant(response_type);

CREATE INDEX IF NOT EXISTS idx_response_variant_context
    ON knowledge.response_variant
    USING GIN(applicable_context_codes);


-- =============================================================================
-- 9. FUNCTIONAL DOMAIN
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.functional_domain (
    domain_code       text PRIMARY KEY,

    code              text NOT NULL UNIQUE,

    label             text NOT NULL,

    category          text NOT NULL
        CHECK (
            category IN (
                'developmental',
                'adult',
                'geriatric'
            )
        ),

    age_relevance     text,

    description       text,

    sort_order        integer NOT NULL,

    status            text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_functional_domain_category
    ON knowledge.functional_domain(category);

DROP TRIGGER IF EXISTS trg_knowledge_functional_domain_updated_at
    ON knowledge.functional_domain;

CREATE TRIGGER trg_knowledge_functional_domain_updated_at
    BEFORE UPDATE ON knowledge.functional_domain
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 10. CONTEXT ADAPTATION RULE
-- =============================================================================
--
-- THE CORE H5 ENGINE.
--
-- Context
--     â†“
-- Target
--     â†“
-- Modification
--
-- Examples:
--
-- CHILD
--   â†’ DYSPNOEA_FUNCTIONAL_MODULE
--   â†’ ACTIVATE
--
-- UNCONSCIOUS
--   â†’ SELF_REPORT questions
--   â†’ DISABLE
--
-- UNCONSCIOUS
--   â†’ CAREGIVER_REPORT / OBSERVATION
--   â†’ ACTIVATE
--
-- VIDEO
--   â†’ AUSCULTATION
--   â†’ UNAVAILABLE
--
-- LANGUAGE_BARRIER
--   â†’ DIRECT_COMPLEX_MEDICAL_WORDING
--   â†’ DISABLE
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.context_adaptation_rule (
    rule_code            text PRIMARY KEY,

    context_code         text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    target_type          text NOT NULL
        CHECK (
            target_type IN (
                'question',
                'question_module',
                'symptom',
                'fact_definition',
                'functional_domain',
                'examination_modality'
            )
        ),

    target_code          text NOT NULL,

    modification         text NOT NULL
        CHECK (
            modification IN (
                'ACTIVATE',
                'UNAVAILABLE',
                'DISABLE'
            )
        ),

    priority_delta       integer NOT NULL DEFAULT 0,

    required_historian   text
        REFERENCES knowledge.historian_type(type_code),

    rationale            text,

    evidence_claim_code  text
        REFERENCES knowledge.source_claim(claim_code),

    condition            jsonb,

    status               text NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    version              integer NOT NULL DEFAULT 1,

    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        context_code,
        target_type,
        target_code,
        modification
    )
);

CREATE INDEX IF NOT EXISTS idx_context_adaptation_rule_context
    ON knowledge.context_adaptation_rule(context_code);

CREATE INDEX IF NOT EXISTS idx_context_adaptation_rule_target
    ON knowledge.context_adaptation_rule(target_type, target_code);

DROP TRIGGER IF EXISTS trg_knowledge_context_adaptation_rule_updated_at
    ON knowledge.context_adaptation_rule;

CREATE TRIGGER trg_knowledge_context_adaptation_rule_updated_at
    BEFORE UPDATE ON knowledge.context_adaptation_rule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 11. CONTEXT FACT MAPPING
-- =============================================================================
--
-- Converts patient/caregiver/observed language into the canonical vocabulary.
--
-- IMPORTANT:
--     This is semantic normalization.
--
-- It does NOT create:
--
--     "STOPS_PLAYING"
--
-- as a new clinical fact.
--
-- It maps:
--
--     "stops playing after running"
--
-- into an existing canonical fact such as:
--
--     EXERCISE_TOLERANCE = REDUCED
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.context_fact_mapping (
    mapping_code          text PRIMARY KEY,

    context_code          text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    raw_expression        text NOT NULL,

    normalized_expression text,

    target_type           text NOT NULL
        CHECK (
            target_type IN (
                'fact_definition',
                'functional_domain'
            )
        ),

    target_code           text NOT NULL,

    canonical_value       text,

    strength              text NOT NULL DEFAULT 'strong'
        CHECK (
            strength IN (
                'strong',
                'moderate',
                'weak'
            )
        ),

    description           text,

    status                text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        context_code,
        raw_expression,
        target_code
    )
);

CREATE INDEX IF NOT EXISTS idx_context_fact_mapping_target
    ON knowledge.context_fact_mapping(target_type, target_code);

CREATE INDEX IF NOT EXISTS idx_context_fact_mapping_context
    ON knowledge.context_fact_mapping(context_code);

DROP TRIGGER IF EXISTS trg_knowledge_context_fact_mapping_updated_at
    ON knowledge.context_fact_mapping;

CREATE TRIGGER trg_knowledge_context_fact_mapping_updated_at
    BEFORE UPDATE ON knowledge.context_fact_mapping
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 12. FACT CAPTURE METHOD
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.fact_capture_method (
    method_code          text PRIMARY KEY,

    label                text NOT NULL,

    is_patient_source    boolean NOT NULL DEFAULT true,

    description          text,

    sort_order           integer NOT NULL,

    status               text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_knowledge_fact_capture_method_updated_at
    ON knowledge.fact_capture_method;

CREATE TRIGGER trg_knowledge_fact_capture_method_updated_at
    BEFORE UPDATE ON knowledge.fact_capture_method
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 13. FACT PROVENANCE
-- =============================================================================
--
-- IMPORTANT DATABASE CORRECTION:
--
-- The original specification used nullable columns in a PRIMARY KEY.
-- PostgreSQL PRIMARY KEY columns cannot be NULL.
--
-- Therefore this implementation uses a surrogate UUID plus a unique index
-- using NULLS NOT DISTINCT so that "NULL = any" remains semantically possible.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.fact_provenance (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_definition_code  text NOT NULL
        REFERENCES clinical.fact_definition(code)
        ON DELETE CASCADE,

    capture_method_code   text NOT NULL
        REFERENCES knowledge.fact_capture_method(method_code),

    historian_type_code   text
        REFERENCES knowledge.historian_type(type_code),

    min_reliability_code  text
        REFERENCES knowledge.historian_reliability(reliability_code),

    is_valid              boolean NOT NULL DEFAULT true,

    evidence_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_fact_provenance_semantic
ON knowledge.fact_provenance (
    fact_definition_code,
    capture_method_code,
    historian_type_code,
    min_reliability_code
) NULLS NOT DISTINCT;

CREATE INDEX IF NOT EXISTS idx_fact_provenance_fact
    ON knowledge.fact_provenance(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_fact_provenance_method
    ON knowledge.fact_provenance(capture_method_code);


-- =============================================================================
-- 14. QUESTION â†’ FUNCTIONAL DOMAIN
-- =============================================================================

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS functional_domain_code
        text REFERENCES knowledge.functional_domain(code);

DROP INDEX IF EXISTS idx_question_functional_domain;

CREATE INDEX IF NOT EXISTS idx_question_func_domain
    ON knowledge.question(functional_domain_code)
    WHERE functional_domain_code IS NOT NULL;


-- =============================================================================
-- 15. QUESTION VARIANT â†’ RESPONSE MODE + HISTORIAN
-- =============================================================================

ALTER TABLE knowledge.question_variant
    ADD COLUMN IF NOT EXISTS response_mode
        text REFERENCES knowledge.response_mode(mode_code);

ALTER TABLE knowledge.question_variant
    ADD COLUMN IF NOT EXISTS historian_type
        text REFERENCES knowledge.historian_type(type_code);

ALTER TABLE knowledge.question_variant
    ADD COLUMN IF NOT EXISTS priority_delta
        integer NOT NULL DEFAULT 0;

ALTER TABLE knowledge.question_variant
    ADD COLUMN IF NOT EXISTS is_disabled
        boolean NOT NULL DEFAULT false;


-- =============================================================================
-- 16. QUESTION VARIANT â†’ RESPONSE VARIANT
-- =============================================================================

ALTER TABLE knowledge.question_variant
    ADD COLUMN IF NOT EXISTS response_variant_id
        text REFERENCES knowledge.response_variant(variant_id);

CREATE INDEX IF NOT EXISTS idx_question_variant_response_variant
    ON knowledge.question_variant(response_variant_id);


-- =============================================================================
-- 17. PATIENT-CONTEXT INSTANCE
-- =============================================================================
--
-- H5 defines the vocabulary/rules.
--
-- A runtime patient may carry:
--
--     CHILD
--     FEMALE
--     CAREGIVER_HISTORIAN
--     LANGUAGE_BARRIER
--     EMERGENCY
--     IN_PERSON
--
-- This table is the persistent encounter context stack.
--
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.encounter_context CASCADE;
CREATE TABLE IF NOT EXISTS clinical.encounter_context (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    context_code        text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    source_type         text NOT NULL DEFAULT 'derived'
        CHECK (
            source_type IN (
                'derived',
                'declared',
                'observed',
                'system',
                'clinician'
            )
        ),

    source_fact_id      uuid
        REFERENCES clinical.fact(id)
        ON DELETE SET NULL,

    effective_from      timestamptz NOT NULL DEFAULT now(),
    effective_to        timestamptz,

    confidence          numeric(3,2) NOT NULL DEFAULT 1.00
        CHECK (confidence BETWEEN 0 AND 1),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','inactive','superseded')),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        encounter_id,
        context_code,
        effective_from
    )
);

CREATE INDEX IF NOT EXISTS idx_encounter_context_encounter
    ON clinical.encounter_context(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_context_code
    ON clinical.encounter_context(context_code);

DROP TRIGGER IF EXISTS trg_encounter_context_updated_at
    ON clinical.encounter_context;

CREATE TRIGGER trg_encounter_context_updated_at
    BEFORE UPDATE ON clinical.encounter_context
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 18. CONTEXT CONFLICT / PRECEDENCE
-- =============================================================================
--
-- Multiple contexts can conflict.
--
-- Example:
--
--     PATIENT
--     CAREGIVER
--
--     IN_PERSON
--     VIDEO
--
-- A deterministic precedence layer prevents the CPU from guessing.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.context_precedence_rule (
    rule_code              text PRIMARY KEY,

    higher_context_code    text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    lower_context_code     text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    effect                 text NOT NULL DEFAULT 'override'
        CHECK (
            effect IN (
                'override',
                'augment',
                'suppress',
                'coexist'
            )
        ),

    rationale              text,

    priority               integer NOT NULL DEFAULT 0,

    status                 text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),

    CHECK (higher_context_code <> lower_context_code),

    UNIQUE (
        higher_context_code,
        lower_context_code
    )
);

CREATE INDEX IF NOT EXISTS idx_context_precedence_higher
    ON knowledge.context_precedence_rule(higher_context_code);

CREATE INDEX IF NOT EXISTS idx_context_precedence_lower
    ON knowledge.context_precedence_rule(lower_context_code);


-- =============================================================================
-- 19. CONTEXT-SPECIFIC FACT CAPTURE AVAILABILITY
-- =============================================================================
--
-- A fact may be clinically relevant but not currently obtainable.
--
-- Example:
--
--     LUNG_AUSCULTATION
--     VIDEO
--     UNAVAILABLE
--
-- This prevents AMEXAN from documenting that something was assessed when the
-- encounter mode could not actually support the assessment.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.context_capture_constraint (
    constraint_code       text PRIMARY KEY,

    context_code          text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    fact_definition_code  text
        REFERENCES clinical.fact_definition(code)
        ON DELETE CASCADE,

    capture_method_code   text
        REFERENCES knowledge.fact_capture_method(method_code),

    availability          text NOT NULL
        CHECK (
            availability IN (
                'AVAILABLE',
                'CONDITIONAL',
                'UNAVAILABLE'
            )
        ),

    rationale             text,

    evidence_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status                text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        context_code,
        fact_definition_code,
        capture_method_code
    )
);


-- =============================================================================
-- 20. CONTEXT DOCUMENTATION ADAPTATION
-- =============================================================================
--
-- The clinical truth remains the same, but documentation may need a different
-- source qualifier:
--
--     patient-reported
--     caregiver-reported
--     observed
--     record-derived
--     device-measured
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.context_documentation_rule (
    rule_code             text PRIMARY KEY,

    context_code          text NOT NULL
        REFERENCES knowledge.clinical_context(code),

    target_fact_code      text
        REFERENCES clinical.fact_definition(code)
        ON DELETE CASCADE,

    required_capture_method text
        REFERENCES knowledge.fact_capture_method(method_code),

    documentation_label   text NOT NULL,

    require_source_qualifier boolean NOT NULL DEFAULT true,

    priority              integer NOT NULL DEFAULT 50,

    rationale             text,

    evidence_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status                text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        context_code,
        target_fact_code,
        required_capture_method
    )
);


-- =============================================================================
-- 21. UNIVERSAL DEVELOPMENTAL STAGES
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
    'Birth through 27 completed days.'
),
(
    'INFANT',
    'Infant',
    28,
    364,
    2,
    '28 days through 11 completed months.'
),
(
    'TODDLER',
    'Toddler',
    365,
    1094,
    3,
    'Approximately 1 through 2 completed years.'
),
(
    'PRESCHOOL_CHILD',
    'Preschool child',
    1095,
    2189,
    4,
    'Approximately 3 through 5 completed years.'
),
(
    'SCHOOL_AGE_CHILD',
    'School-age child',
    2190,
    4379,
    5,
    'Approximately 6 through 11 completed years.'
),
(
    'ADOLESCENT',
    'Adolescent',
    4380,
    6569,
    6,
    'Approximately 12 through 17 completed years.'
),
(
    'ADULT',
    'Adult',
    6570,
    23724,
    7,
    'Adult life stage.'
),
(
    'OLDER_ADULT',
    'Older adult',
    23725,
    NULL,
    8,
    'Older-adult life stage. Exact institutional boundary may be configured.'
)
ON CONFLICT (stage_code)
DO UPDATE SET
    label = EXCLUDED.label,
    min_age_days = EXCLUDED.min_age_days,
    max_age_days = EXCLUDED.max_age_days,
    sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description,
    updated_at = now();


-- =============================================================================
-- 22. UNIVERSAL HISTORIANS
-- =============================================================================

INSERT INTO knowledge.historian_type
(
    type_code,
    label,
    is_patient,
    description,
    sort_order
)
VALUES
(
    'PATIENT',
    'Patient',
    true,
    'The patient provides the history directly.',
    1
),
(
    'PARENT',
    'Parent',
    false,
    'Parent provides history for or alongside the patient.',
    2
),
(
    'CAREGIVER',
    'Caregiver',
    false,
    'Non-parent caregiver provides history.',
    3
),
(
    'FAMILY_MEMBER',
    'Family member',
    false,
    'Family member provides collateral history.',
    4
),
(
    'INTERPRETER',
    'Interpreter',
    false,
    'Interpreter facilitates communication but does not become the clinical source unless independently providing collateral information.',
    5
),
(
    'CLINICIAN',
    'Clinician / observer',
    false,
    'Clinician contributes observations or examination-derived information.',
    6
),
(
    'RECORD',
    'Previous clinical record',
    false,
    'Information derived from prior clinical documentation.',
    7
)
ON CONFLICT (type_code)
DO UPDATE SET
    label = EXCLUDED.label,
    is_patient = EXCLUDED.is_patient,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- 23. HISTORIAN RELIABILITY
-- =============================================================================

INSERT INTO knowledge.historian_reliability
(
    reliability_code,
    label,
    sort_order,
    description
)
VALUES
(
    'GOOD',
    'Good reliability',
    1,
    'History is internally coherent and sufficiently supported for clinical use.'
),
(
    'FAIR',
    'Fair reliability',
    2,
    'Some limitations are present but most information is usable.'
),
(
    'POOR',
    'Poor reliability',
    3,
    'Important limitations reduce confidence in the history.'
),
(
    'UNRELIABLE',
    'Unreliable',
    4,
    'Information cannot safely be treated as verified history without corroboration.'
),
(
    'UNKNOWN',
    'Reliability not established',
    5,
    'Reliability has not yet been adequately assessed.'
)
ON CONFLICT (reliability_code)
DO UPDATE SET
    label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description,
    updated_at = now();


-- =============================================================================
-- 24. COMMUNICATION CONTEXTS
-- =============================================================================

INSERT INTO knowledge.communication_context
(
    factor_code,
    label,
    description,
    sort_order
)
VALUES
(
    'LANGUAGE_BARRIER',
    'Language barrier',
    'The patient and clinician do not share adequate language proficiency.',
    1
),
(
    'INTERPRETER_REQUIRED',
    'Interpreter required',
    'Professional or appropriate interpretation is required for accurate communication.',
    2
),
(
    'HEARING_IMPAIRMENT',
    'Hearing impairment',
    'Communication must be adapted to the patient''s hearing ability.',
    3
),
(
    'VISUAL_IMPAIRMENT',
    'Visual impairment',
    'Visual response surfaces may require adaptation.',
    4
),
(
    'SPEECH_IMPAIRMENT',
    'Speech impairment',
    'Spoken communication may be limited while cognition may remain intact.',
    5
),
(
    'COGNITIVE_COMMUNICATION_LIMITATION',
    'Cognitive communication limitation',
    'Question complexity and response strategy require adaptation.',
    6
),
(
    'LITERACY_LIMITATION',
    'Limited health literacy',
    'Medical terminology and written response interfaces require adaptation.',
    7
),
(
    'CHILD_DIRECTED_COMMUNICATION',
    'Child-directed communication',
    'Questions are adapted to developmental comprehension.',
    8
),
(
    'CAREGIVER_MEDIATED_COMMUNICATION',
    'Caregiver-mediated communication',
    'History is primarily obtained through another person.',
    9
)
ON CONFLICT (factor_code)
DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- 25. ENCOUNTER MODES
-- =============================================================================

INSERT INTO knowledge.encounter_mode
(
    mode_code,
    label,
    supports_auscultation,
    supports_inspection,
    supports_device_readings,
    supports_palpation,
    supports_percussion,
    supports_direct_observation,
    description,
    sort_order
)
VALUES
(
    'IN_PERSON',
    'In person',
    true,
    true,
    true,
    true,
    true,
    true,
    'Direct clinical encounter with physical examination capability.',
    1
),
(
    'VIDEO',
    'Video consultation',
    false,
    true,
    true,
    false,
    false,
    true,
    'Remote visual encounter. Device readings may be available if separately supplied.',
    2
),
(
    'AUDIO',
    'Audio consultation',
    false,
    false,
    false,
    false,
    false,
    false,
    'Remote encounter without direct visual or physical examination.',
    3
),
(
    'CHAT',
    'Text / chat encounter',
    false,
    false,
    false,
    false,
    false,
    false,
    'Text-based clinical interaction.',
    4
),
(
    'REMOTE_MONITORING',
    'Remote monitoring',
    false,
    false,
    true,
    true,
    false,
    false,
    'Clinical information may be supplied through connected or patient-generated monitoring.',
    5
)
ON CONFLICT (mode_code)
DO UPDATE SET
    label = EXCLUDED.label,
    supports_auscultation = EXCLUDED.supports_auscultation,
    supports_inspection = EXCLUDED.supports_inspection,
    supports_device_readings = EXCLUDED.supports_device_readings,
    supports_palpation = EXCLUDED.supports_palpation,
    supports_percussion = EXCLUDED.supports_percussion,
    supports_direct_observation = EXCLUDED.supports_direct_observation,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- NOTE:
-- PostgreSQL does not support the named assignment syntax used above.
-- Normalize the remote-mode rows explicitly.
-- =============================================================================

UPDATE knowledge.encounter_mode
SET
    supports_device_readings = true
WHERE mode_code IN ('VIDEO','REMOTE_MONITORING');

UPDATE knowledge.encounter_mode
SET
    supports_inspection = true,
    supports_direct_observation = true
WHERE mode_code = 'VIDEO';

UPDATE knowledge.encounter_mode
SET
    supports_inspection = true,
    supports_direct_observation = true
WHERE mode_code = 'REMOTE_MONITORING';


-- =============================================================================
-- 26. RESPONSE MODES
-- =============================================================================

INSERT INTO knowledge.response_mode
(
    mode_code,
    label,
    is_patient_facing,
    description,
    sort_order
)
VALUES
(
    'SELF_REPORT',
    'Patient self-report',
    true,
    'Patient directly describes the experience.',
    1
),
(
    'CAREGIVER_REPORT',
    'Caregiver report',
    true,
    'Parent or caregiver reports the patient''s experience or observed behaviour.',
    2
),
(
    'COLLATERAL_REPORT',
    'Collateral report',
    true,
    'Another source provides corroborating history.',
    3
),
(
    'OBSERVATION',
    'Clinical observation',
    false,
    'Information captured from direct observation.',
    4
),
(
    'CLINICIAN_ASSESSMENT',
    'Clinician assessment',
    false,
    'Clinician-derived assessment based on clinical examination or interpretation.',
    5
),
(
    'RECORD_DERIVED',
    'Record-derived',
    false,
    'Information derived from previous clinical records.',
    6
),
(
    'DEVICE_MEASURED',
    'Device measured',
    false,
    'Information generated by a validated clinical device or measurement system.',
    7
),
(
    'DOCUMENT_DERIVED',
    'Document-derived',
    false,
    'Information derived from an external clinical document.',
    8
)
ON CONFLICT (mode_code)
DO UPDATE SET
    label = EXCLUDED.label,
    is_patient_facing = EXCLUDED.is_patient_facing,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- 27. FACT CAPTURE METHODS
-- =============================================================================

INSERT INTO knowledge.fact_capture_method
(
    method_code,
    label,
    is_patient_source,
    description,
    sort_order
)
VALUES
(
    'PATIENT_REPORTED',
    'Patient reported',
    true,
    'Direct report from the patient.',
    1
),
(
    'CAREGIVER_REPORTED',
    'Caregiver reported',
    false,
    'Report supplied by a caregiver.',
    2
),
(
    'COLLATERAL_REPORTED',
    'Collateral reported',
    false,
    'Information supplied by another collateral historian.',
    3
),
(
    'CLINICIAN_OBSERVED',
    'Clinician observed',
    false,
    'Direct observation by the clinician.',
    4
),
(
    'CLINICIAN_EXAMINED',
    'Clinician examined',
    false,
    'Information obtained through physical examination.',
    5
),
(
    'DEVICE_MEASURED',
    'Device measured',
    false,
    'Objective measurement obtained using an appropriate device.',
    6
),
(
    'RECORD_DERIVED',
    'Record derived',
    false,
    'Derived from an existing clinical record.',
    7
),
(
    'DOCUMENT_DERIVED',
    'Document derived',
    false,
    'Derived from another clinical document.',
    8
),
(
    'LABORATORY_DERIVED',
    'Laboratory derived',
    false,
    'Derived from laboratory testing.',
    9
),
(
    'IMAGING_DERIVED',
    'Imaging derived',
    false,
    'Derived from diagnostic imaging interpretation.',
    10
)
ON CONFLICT (method_code)
DO UPDATE SET
    label = EXCLUDED.label,
    is_patient_source = EXCLUDED.is_patient_source,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- 28. FUNCTIONAL DOMAINS
-- =============================================================================

INSERT INTO knowledge.functional_domain
(
    domain_code,
    code,
    label,
    category,
    age_relevance,
    description,
    sort_order
)
VALUES
(
    'FD001',
    'FEEDING',
    'Feeding',
    'developmental',
    'neonate, infant, child',
    'Ability to feed adequately and tolerate feeding.',
    1
),
(
    'FD002',
    'NUTRITION',
    'Nutrition',
    'developmental',
    'all ages',
    'Impact on nutritional intake and nutritional function.',
    2
),
(
    'FD003',
    'SLEEP',
    'Sleep',
    'adult',
    'all ages',
    'Impact on sleep initiation, maintenance or quality.',
    3
),
(
    'FD004',
    'MOBILITY',
    'Mobility',
    'geriatric',
    'child through older adult',
    'Ability to move, walk and transfer.',
    4
),
(
    'FD005',
    'PHYSICAL_ACTIVITY',
    'Physical activity',
    'adult',
    'school-age through older adult',
    'Impact on physical activity and exercise tolerance.',
    5
),
(
    'FD006',
    'EXERCISE_TOLERANCE',
    'Exercise tolerance',
    'adult',
    'adolescent through older adult',
    'Ability to perform exertion without clinically important limitation.',
    6
),
(
    'FD007',
    'ACTIVITIES_OF_DAILY_LIVING',
    'Activities of daily living',
    'geriatric',
    'adult and older adult',
    'Impact on basic and instrumental activities of daily living.',
    7
),
(
    'FD008',
    'OCCUPATION',
    'Occupation',
    'adult',
    'working-age patients',
    'Impact on occupational activities and work capacity.',
    8
),
(
    'FD009',
    'EDUCATION',
    'Education',
    'developmental',
    'school-age and adolescent',
    'Impact on attendance, participation and learning.',
    9
),
(
    'FD010',
    'PLAY',
    'Play',
    'developmental',
    'infant through child',
    'Impact on age-appropriate play and activity.',
    10
),
(
    'FD011',
    'SPEECH',
    'Speech',
    'developmental',
    'infant through child',
    'Impact on communication and speech function.',
    11
),
(
    'FD012',
    'DEVELOPMENT',
    'Development',
    'developmental',
    'infant through adolescent',
    'Impact on developmental progression and age-appropriate function.',
    12
),
(
    'FD013',
    'SOCIAL_FUNCTION',
    'Social function',
    'adult',
    'all ages',
    'Impact on social interaction and participation.',
    13
),
(
    'FD014',
    'SELF_CARE',
    'Self-care',
    'geriatric',
    'adolescent through older adult',
    'Ability to perform personal self-care.',
    14
),
(
    'FD015',
    'SEXUAL_FUNCTION',
    'Sexual function',
    'adult',
    'adolescent and adult where clinically appropriate',
    'Impact on sexual function and intimate activity.',
    15
),
(
    'FD016',
    'CONTINENCE',
    'Continence',
    'geriatric',
    'developmentally and clinically relevant ages',
    'Bladder and bowel continence/function.',
    16
),
(
    'FD017',
    'COMMUNICATION',
    'Communication',
    'developmental',
    'all ages',
    'Ability to communicate needs and experiences.',
    17
),
(
    'FD018',
    'FUNCTIONAL_RESPIRATORY_LIMITATION',
    'Functional respiratory limitation',
    'adult',
    'all ages with context adaptation',
    'Functional limitation attributable to respiratory symptoms.',
    18
),
(
    'FD019',
    'FUNCTIONAL_PAIN_LIMITATION',
    'Functional pain limitation',
    'adult',
    'all ages',
    'Impact of pain on normal activities.',
    19
),
(
    'FD020',
    'CAREGIVER_BURDEN',
    'Caregiver burden',
    'geriatric',
    'clinically relevant chronic illness contexts',
    'Impact of patient illness on caregiver function and demands.',
    20
)
ON CONFLICT (domain_code)
DO UPDATE SET
    code = EXCLUDED.code,
    label = EXCLUDED.label,
    category = EXCLUDED.category,
    age_relevance = EXCLUDED.age_relevance,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- 29. RESPONSE VARIANTS
-- =============================================================================

INSERT INTO knowledge.response_variant
(
    variant_id,
    response_type,
    variant_name,
    applicable_context_codes,
    min_age_days,
    max_age_days,
    description
)
VALUES
(
    'RV001',
    'numeric_scale',
    'Adult numeric 0-10 scale',
    ARRAY['ADULT','OLDER_ADULT'],
    6570,
    NULL,
    'Numeric scale suitable when the patient can understand and reliably use a numeric rating.'
),
(
    'RV002',
    'faces_scale',
    'Child faces scale',
    ARRAY['PRESCHOOL_CHILD','SCHOOL_AGE_CHILD'],
    1095,
    4379,
    'Faces-based response surface where developmentally appropriate.'
),
(
    'RV003',
    'caregiver_observation',
    'Caregiver observation checklist',
    ARRAY['NEONATE','INFANT','TODDLER'],
    0,
    1094,
    'Observable behavioural and functional indicators reported by a caregiver.'
),
(
    'RV004',
    'single_choice',
    'Single choice',
    ARRAY['ADULT','OLDER_ADULT','ADOLESCENT','SCHOOL_AGE_CHILD'],
    NULL,
    NULL,
    'Controlled single-choice response surface.'
),
(
    'RV005',
    'multi_choice',
    'Multiple choice',
    ARRAY['ADULT','OLDER_ADULT','ADOLESCENT','SCHOOL_AGE_CHILD'],
    NULL,
    NULL,
    'Multiple controlled response selection.'
),
(
    'RV006',
    'free_text',
    'Free-text patient narrative',
    ARRAY['ADULT','OLDER_ADULT','ADOLESCENT'],
    NULL,
    NULL,
    'Free narrative response where an exact patient description is clinically valuable.'
),
(
    'RV007',
    'observational_checklist',
    'Clinical observation checklist',
    ARRAY['NEONATE','INFANT','TODDLER','PRESCHOOL_CHILD','SCHOOL_AGE_CHILD','ADOLESCENT','ADULT','OLDER_ADULT'],
    NULL,
    NULL,
    'Clinician observation rather than self-report.'
)
ON CONFLICT (variant_id)
DO UPDATE SET
    response_type = EXCLUDED.response_type,
    variant_name = EXCLUDED.variant_name,
    applicable_context_codes = EXCLUDED.applicable_context_codes,
    min_age_days = EXCLUDED.min_age_days,
    max_age_days = EXCLUDED.max_age_days,
    description = EXCLUDED.description,
    updated_at = now();


-- =============================================================================
-- 30. CANONICAL CLINICAL CONTEXT SEED
-- =============================================================================
--
-- Universal context vocabulary.
--
-- =============================================================================

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

-- AGE
(
    'C001',
    'NEONATE',
    'AGE',
    'Neonate',
    'Patient in the neonatal developmental stage.',
    true,
    true,
    1.20
),
(
    'C002',
    'INFANT',
    'AGE',
    'Infant',
    'Patient in infancy.',
    true,
    true,
    1.15
),
(
    'C003',
    'CHILD',
    'AGE',
    'Child',
    'Paediatric patient requiring child-adapted communication and clinical history.',
    true,
    true,
    1.15
),
(
    'C004',
    'ADOLESCENT',
    'AGE',
    'Adolescent',
    'Adolescent patient.',
    true,
    true,
    1.10
),
(
    'C005',
    'ADULT',
    'AGE',
    'Adult',
    'Adult patient.',
    true,
    true,
    1.00
),
(
    'C006',
    'OLDER_ADULT',
    'AGE',
    'Older adult',
    'Older adult patient.',
    true,
    true,
    1.15
),

-- HISTORIAN
(
    'C007',
    'CAREGIVER_HISTORIAN',
    'HISTORIAN',
    'Caregiver historian',
    'History is provided wholly or partly by a caregiver.',
    true,
    false,
    1.10
),
(
    'C008',
    'COLLATERAL_HISTORIAN',
    'HISTORIAN',
    'Collateral historian',
    'History is obtained from a collateral source.',
    true,
    false,
    1.10
),

-- COMMUNICATION
(
    'C009',
    'LANGUAGE_BARRIER',
    'COMMUNICATION',
    'Language barrier',
    'Language mismatch may compromise direct history.',
    true,
    false,
    1.05
),
(
    'C010',
    'HEARING_IMPAIRMENT',
    'COMMUNICATION',
    'Hearing impairment',
    'Hearing impairment affects ordinary spoken communication.',
    true,
    false,
    1.05
),
(
    'C011',
    'COGNITIVE_COMMUNICATION_LIMITATION',
    'COGNITION',
    'Cognitive communication limitation',
    'Cognitive or communication limitations affect history acquisition.',
    true,
    true,
    1.20
),

-- ENCOUNTER SETTING
(
    'C012',
    'EMERGENCY',
    'SETTING',
    'Emergency encounter',
    'Time-critical presentation requiring safety-first prioritisation.',
    true,
    true,
    2.00
),
(
    'C013',
    'INPATIENT',
    'SETTING',
    'Inpatient encounter',
    'Patient is being assessed within an inpatient episode.',
    true,
    true,
    1.10
),
(
    'C014',
    'OUTPATIENT',
    'SETTING',
    'Outpatient encounter',
    'Ambulatory clinical encounter.',
    true,
    true,
    1.00
),

-- MODE
(
    'C015',
    'REMOTE_ENCOUNTER',
    'MODE',
    'Remote encounter',
    'Encounter occurs without full direct physical examination.',
    true,
    true,
    1.10
),
(
    'C016',
    'IN_PERSON_ENCOUNTER',
    'MODE',
    'In-person encounter',
    'Direct physical clinical encounter.',
    true,
    true,
    1.00
),

-- PURPOSE
(
    'C017',
    'INITIAL_ASSESSMENT',
    'ENCOUNTER_PURPOSE',
    'Initial assessment',
    'First substantive assessment of the presenting problem.',
    true,
    true,
    1.20
),
(
    'C018',
    'FOLLOW_UP',
    'ENCOUNTER_PURPOSE',
    'Follow-up',
    'Assessment of an already established clinical episode.',
    true,
    true,
    0.90
),
(
    'C019',
    'CHRONIC_REVIEW',
    'ENCOUNTER_PURPOSE',
    'Chronic disease review',
    'Review of established long-term clinical problems.',
    true,
    true,
    1.00
),
(
    'C020',
    'PREVENTIVE_ASSESSMENT',
    'ENCOUNTER_PURPOSE',
    'Preventive assessment',
    'Assessment primarily focused on prevention and health maintenance.',
    true,
    true,
    0.90
),

-- COGNITION / CAPACITY
(
    'C021',
    'UNCONSCIOUS',
    'COGNITION',
    'Unconscious / unable to provide direct history',
    'Patient cannot provide a direct self-report at the time of assessment.',
    true,
    true,
    2.00
),
(
    'C022',
    'ALTERED_MENTAL_STATUS',
    'COGNITION',
    'Altered mental status',
    'Mental status limits or changes the reliability of direct history.',
    true,
    true,
    1.80
),
(
    'C023',
    'INTACT_DIRECT_HISTORIAN',
    'HISTORIAN',
    'Direct historian available',
    'Patient can directly participate in history acquisition.',
    true,
    false,
    1.00
),

-- REPRODUCTIVE
(
    'C024',
    'PREGNANCY_CONTEXT',
    'REPRODUCTIVE',
    'Pregnancy context',
    'Pregnancy is clinically relevant to the encounter.',
    true,
    true,
    1.50
),
(
    'C025',
    'POSTPARTUM_CONTEXT',
    'REPRODUCTIVE',
    'Postpartum context',
    'Recent postpartum state is clinically relevant.',
    true,
    true,
    1.50
),
(
    'C026',
    'REPRODUCTIVE_CONTEXT',
    'REPRODUCTIVE',
    'Reproductive context',
    'Reproductive history or physiology is clinically relevant.',
    true,
    true,
    1.20
),

-- SPECIAL CLINICAL CONTEXT
(
    'C027',
    'PAIN_PRESENTATION',
    'ENCOUNTER_PURPOSE',
    'Pain presentation',
    'Encounter is principally driven by pain.',
    true,
    true,
    1.30
),
(
    'C028',
    'FEVER_PRESENTATION',
    'ENCOUNTER_PURPOSE',
    'Fever presentation',
    'Encounter is principally driven by fever or febrile illness.',
    true,
    true,
    1.30
),
(
    'C029',
    'RESPIRATORY_PRESENTATION',
    'ENCOUNTER_PURPOSE',
    'Respiratory presentation',
    'Encounter contains a clinically relevant respiratory presentation.',
    true,
    true,
    1.30
),
(
    'C030',
    'FRAILTY_CONTEXT',
    'SETTING',
    'Frailty context',
    'Frailty materially affects functional assessment or history interpretation.',
    true,
    true,
    1.30
)

ON CONFLICT (context_id)
DO UPDATE SET
    code = EXCLUDED.code,
    category = EXCLUDED.category,
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    applies_to_questions = EXCLUDED.applies_to_questions,
    applies_to_exam = EXCLUDED.applies_to_exam,
    priority_weight = EXCLUDED.priority_weight,
    updated_at = now();


-- =============================================================================
-- 31. CONTEXT PRECEDENCE
-- =============================================================================

INSERT INTO knowledge.context_precedence_rule
(
    rule_code,
    higher_context_code,
    lower_context_code,
    effect,
    rationale,
    priority
)
VALUES
(
    'CP001',
    'UNCONSCIOUS',
    'INTACT_DIRECT_HISTORIAN',
    'override',
    'A current inability to provide direct history overrides an otherwise expected direct-historian pathway.',
    100
),
(
    'CP002',
    'ALTERED_MENTAL_STATUS',
    'INTACT_DIRECT_HISTORIAN',
    'override',
    'Altered mental status may invalidate an assumption of fully reliable direct self-report.',
    90
),
(
    'CP003',
    'EMERGENCY',
    'OUTPATIENT',
    'override',
    'Emergency status changes prioritisation toward immediate safety assessment.',
    80
),
(
    'CP004',
    'CAREGIVER_HISTORIAN',
    'INTACT_DIRECT_HISTORIAN',
    'augment',
    'Caregiver collateral information may supplement, rather than necessarily replace, patient history.',
    50
)
ON CONFLICT (rule_code)
DO UPDATE SET
    higher_context_code = EXCLUDED.higher_context_code,
    lower_context_code = EXCLUDED.lower_context_code,
    effect = EXCLUDED.effect,
    rationale = EXCLUDED.rationale,
    priority = EXCLUDED.priority,
    updated_at = now();


-- =============================================================================
-- 32. UNIVERSAL CONTEXT ADAPTATION RULES
-- =============================================================================
--
-- These are generic rules.
--
-- They do not encode disease-specific treatment.
-- They control how the history is obtained.
--
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    required_historian,
    rationale
)
VALUES

-- -------------------------------------------------------------------------
-- NEONATE
-- -------------------------------------------------------------------------

(
    'CR001',
    'NEONATE',
    'question_module',
    'ADULT_SELF_REPORT',
    'DISABLE',
    0,
    NULL,
    'Neonates cannot provide ordinary direct verbal self-report.'
),
(
    'CR002',
    'NEONATE',
    'question_module',
    'CAREGIVER_HISTORY',
    'ACTIVATE',
    -100,
    'PARENT',
    'Neonatal history is primarily obtained from parent/caregiver and available records.'
),

-- -------------------------------------------------------------------------
-- CHILD
-- -------------------------------------------------------------------------

(
    'CR003',
    'CHILD',
    'question_module',
    'CHILD_DIRECT_HISTORY',
    'ACTIVATE',
    -50,
    'PATIENT',
    'Children may provide direct history when developmentally capable.'
),
(
    'CR004',
    'CHILD',
    'question_module',
    'CAREGIVER_HISTORY',
    'ACTIVATE',
    -40,
    'CAREGIVER',
    'Caregiver information is often required to supplement developmental, behavioural and symptom history.'
),

-- -------------------------------------------------------------------------
-- UNCONSCIOUS
-- -------------------------------------------------------------------------

(
    'CR005',
    'UNCONSCIOUS',
    'question_module',
    'DIRECT_SELF_REPORT',
    'DISABLE',
    0,
    NULL,
    'An unconscious patient cannot provide direct verbal self-report.'
),
(
    'CR006',
    'UNCONSCIOUS',
    'question_module',
    'COLLATERAL_HISTORY',
    'ACTIVATE',
    -150,
    'CAREGIVER',
    'Collateral information should be prioritised when direct history cannot be obtained.'
),
(
    'CR007',
    'UNCONSCIOUS',
    'question_module',
    'CLINICAL_OBSERVATION',
    'ACTIVATE',
    -150,
    'CLINICIAN',
    'Direct observation and examination become primary sources of immediate information.'
),

-- -------------------------------------------------------------------------
-- ALTERED MENTAL STATUS
-- -------------------------------------------------------------------------

(
    'CR008',
    'ALTERED_MENTAL_STATUS',
    'question_module',
    'SIMPLE_DIRECT_QUESTIONS',
    'ACTIVATE',
    -50,
    'PATIENT',
    'Questions should be simplified and focused on information the patient can reliably provide.'
),
(
    'CR009',
    'ALTERED_MENTAL_STATUS',
    'question_module',
    'COLLATERAL_HISTORY',
    'ACTIVATE',
    -100,
    'CAREGIVER',
    'Collateral history may be required when direct reliability is limited.'
),

-- -------------------------------------------------------------------------
-- LANGUAGE
-- -------------------------------------------------------------------------

(
    'CR010',
    'LANGUAGE_BARRIER',
    'question_module',
    'MEDICAL_COMPLEX_WORDING',
    'DISABLE',
    0,
    NULL,
    'Complex medical terminology can reduce accuracy when language compatibility is limited.'
),
(
    'CR011',
    'LANGUAGE_BARRIER',
    'question_module',
    'PLAIN_LANGUAGE_HISTORY',
    'ACTIVATE',
    -80,
    'PATIENT',
    'Use understandable language while preserving the same canonical fact being elicited.'
),

-- -------------------------------------------------------------------------
-- HEARING
-- -------------------------------------------------------------------------

(
    'CR012',
    'HEARING_IMPAIRMENT',
    'question_module',
    'SPOKEN_ONLY_HISTORY',
    'DISABLE',
    0,
    NULL,
    'Spoken-only communication may be inadequate when hearing impairment is present.'
),
(
    'CR013',
    'HEARING_IMPAIRMENT',
    'question_module',
    'VISUAL_OR_WRITTEN_HISTORY',
    'ACTIVATE',
    -70,
    'PATIENT',
    'Visual or written communication may improve accurate history acquisition.'
),

-- -------------------------------------------------------------------------
-- EMERGENCY
-- -------------------------------------------------------------------------

(
    'CR014',
    'EMERGENCY',
    'question_module',
    'SAFETY_SCREEN',
    'ACTIVATE',
    -500,
    NULL,
    'Emergency presentations require immediate prioritisation of safety-critical information.'
),
(
    'CR015',
    'EMERGENCY',
    'question_module',
    'LONG_FORM_HISTORY',
    'DISABLE',
    0,
    NULL,
    'Non-essential long-form history must not delay immediate safety assessment.'
),

-- -------------------------------------------------------------------------
-- PREGNANCY
-- -------------------------------------------------------------------------

(
    'CR016',
    'PREGNANCY_CONTEXT',
    'question_module',
    'REPRODUCTIVE_CONTEXT_HISTORY',
    'ACTIVATE',
    -100,
    'PATIENT',
    'Pregnancy changes the relevance of reproductive and pregnancy-specific history.'
),

-- -------------------------------------------------------------------------
-- OLDER ADULT / FRAILTY
-- -------------------------------------------------------------------------

(
    'CR017',
    'OLDER_ADULT',
    'functional_domain',
    'ACTIVITIES_OF_DAILY_LIVING',
    'ACTIVATE',
    -70,
    NULL,
    'Functional status and independence may materially influence assessment in older adults.'
),
(
    'CR018',
    'FRAILTY_CONTEXT',
    'functional_domain',
    'ACTIVITIES_OF_DAILY_LIVING',
    'ACTIVATE',
    -100,
    NULL,
    'Frailty requires explicit attention to baseline and current functional status.'
)

ON CONFLICT (
    context_code,
    target_type,
    target_code,
    modification
)
DO UPDATE SET
    priority_delta = EXCLUDED.priority_delta,
    required_historian = EXCLUDED.required_historian,
    rationale = EXCLUDED.rationale,
    updated_at = now();


-- =============================================================================
-- 33. CONTEXT FACT MAPPINGS
-- =============================================================================
--
-- UNIVERSAL NORMALISATION EXAMPLES.
--
-- =============================================================================

INSERT INTO knowledge.context_fact_mapping
(
    mapping_code,
    context_code,
    raw_expression,
    normalized_expression,
    target_type,
    target_code,
    canonical_value,
    strength,
    description
)
VALUES
(
    'CFM001',
    'CHILD',
    'stops playing when running',
    'activity stops because of symptom',
    'functional_domain',
    'PHYSICAL_ACTIVITY',
    'reduced',
    'strong',
    'Child functional expression mapped into universal activity limitation.'
),
(
    'CFM002',
    'CHILD',
    'cannot keep up with other children',
    'reduced age-appropriate exercise tolerance',
    'functional_domain',
    'EXERCISE_TOLERANCE',
    'reduced',
    'strong',
    'Functional paediatric expression normalized to exercise tolerance.'
),
(
    'CFM003',
    'INFANT',
    'stops feeding to breathe',
    'feeding interrupted by respiratory difficulty',
    'functional_domain',
    'FEEDING',
    'reduced',
    'strong',
    'Observed feeding behaviour may represent clinically relevant respiratory functional limitation.'
),
(
    'CFM004',
    'NEONATE',
    'feeds poorly',
    'reduced feeding effectiveness',
    'functional_domain',
    'FEEDING',
    'reduced',
    'moderate',
    'Neonatal caregiver description normalized into feeding function.'
),
(
    'CFM005',
    'OLDER_ADULT',
    'needs help bathing',
    'assistance required for self-care',
    'functional_domain',
    'SELF_CARE',
    'reduced',
    'strong',
    'Functional limitation normalized to self-care domain.'
),
(
    'CFM006',
    'OLDER_ADULT',
    'no longer walks to the market',
    'reduced community mobility',
    'functional_domain',
    'MOBILITY',
    'reduced',
    'strong',
    'Reported activity change normalized into mobility.'
)
ON CONFLICT (
    context_code,
    raw_expression,
    target_code
)
DO UPDATE SET
    normalized_expression = EXCLUDED.normalized_expression,
    canonical_value = EXCLUDED.canonical_value,
    strength = EXCLUDED.strength,
    description = EXCLUDED.description,
    updated_at = now();


-- =============================================================================
-- 34. FACT PROVENANCE UNIVERSAL RULES
-- =============================================================================
--
-- Only insert fact codes that actually exist in the current schema.
-- Therefore this section intentionally uses an INSERT ... SELECT against
-- clinical.fact_definition.
--
-- This allows the migration to remain safe when the fact library is larger
-- or smaller than the current H5 seed set.
--
-- =============================================================================

INSERT INTO knowledge.fact_provenance
(
    fact_definition_code,
    capture_method_code,
    historian_type_code,
    min_reliability_code,
    is_valid
)
SELECT
    fd.code,
    x.capture_method,
    x.historian,
    x.reliability,
    true
FROM clinical.fact_definition fd
CROSS JOIN (
    VALUES
        ('PATIENT_REPORTED', 'PATIENT', 'GOOD'),
        ('CAREGIVER_REPORTED', 'PARENT', 'GOOD'),
        ('CAREGIVER_REPORTED', 'CAREGIVER', 'GOOD'),
        ('COLLATERAL_REPORTED', 'FAMILY_MEMBER', 'GOOD'),
        ('CLINICIAN_OBSERVED', 'CLINICIAN', NULL),
        ('RECORD_DERIVED', 'RECORD', NULL),
        ('DEVICE_MEASURED', 'CLINICIAN', NULL)
) AS x(capture_method, historian, reliability)
WHERE
    (
        x.capture_method = 'PATIENT_REPORTED'
        AND x.historian = 'PATIENT'
    )
    OR
    (
        x.capture_method = 'CAREGIVER_REPORTED'
        AND x.historian IN ('PARENT', 'CAREGIVER')
    )
    OR
    (
        x.capture_method = 'COLLATERAL_REPORTED'
        AND x.historian = 'FAMILY_MEMBER'
    )
    OR
    (
        x.capture_method IN (
            'CLINICIAN_OBSERVED',
            'RECORD_DERIVED',
            'DEVICE_MEASURED'
        )
    )
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 35. CONTEXT CAPTURE CONSTRAINTS
-- =============================================================================
--
-- Universal encounter-mode constraints.
--
-- =============================================================================

INSERT INTO knowledge.context_capture_constraint
(
    constraint_code,
    context_code,
    fact_definition_code,
    capture_method_code,
    availability,
    rationale
)
SELECT
    'CCC_VIDEO_AUSCULTATION_' || md5(fd.code),
    'REMOTE_ENCOUNTER',
    fd.code,
    'CLINICIAN_EXAMINED',
    'CONDITIONAL',
    'Direct physical examination may not be available during a remote encounter.'
FROM clinical.fact_definition fd
WHERE lower(fd.code) LIKE '%auscult%'
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 36. CONTEXT DOCUMENTATION RULES
-- =============================================================================
--
-- Preserve source provenance in the final clinical record.
--
-- =============================================================================

INSERT INTO knowledge.context_documentation_rule
(
    rule_code,
    context_code,
    target_fact_code,
    required_capture_method,
    documentation_label,
    require_source_qualifier,
    priority,
    rationale
)
SELECT
    'CDR_' || md5(c.code || ':PATIENT'),
    'INTACT_DIRECT_HISTORIAN',
    c.code,
    'PATIENT_REPORTED',
    'Patient reported',
    true,
    50,
    'The clinical record should preserve that the information was patient-reported.'
FROM clinical.fact_definition c
WHERE c.code IS NOT NULL
ON CONFLICT DO NOTHING;


INSERT INTO knowledge.context_documentation_rule
(
    rule_code,
    context_code,
    target_fact_code,
    required_capture_method,
    documentation_label,
    require_source_qualifier,
    priority,
    rationale
)
SELECT
    'CDR_' || md5(c.code || ':CAREGIVER'),
    'CAREGIVER_HISTORIAN',
    c.code,
    'CAREGIVER_REPORTED',
    'Caregiver reported',
    true,
    60,
    'The clinical record should preserve collateral/caregiver provenance.'
FROM clinical.fact_definition c
WHERE c.code IS NOT NULL
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 37. QUESTION VARIANT DEFAULT GOVERNANCE
-- =============================================================================
--
-- Existing question variants remain one QUESTION identity.
--
-- H5 adds:
--
--     response_mode
--     historian_type
--     response_variant_id
--     priority_delta
--     is_disabled
--
-- =============================================================================

COMMENT ON COLUMN knowledge.question_variant.response_mode IS
'H5 capture strategy. Changes HOW information is obtained, not WHAT canonical fact the question represents.';

COMMENT ON COLUMN knowledge.question_variant.historian_type IS
'H5 historian selection. Identifies who should supply the response.';

COMMENT ON COLUMN knowledge.question_variant.response_variant_id IS
'H5 response surface. Changes how the answer is captured without creating a new canonical fact.';

COMMENT ON COLUMN knowledge.question_variant.priority_delta IS
'H5 context-specific priority adjustment applied by the CPU.';

COMMENT ON COLUMN knowledge.question_variant.is_disabled IS
'H5 execution gate. Disabled variants are not eligible for the current context.';


-- =============================================================================
-- 38. H5 PROVENANCE
-- =============================================================================

COMMENT ON TABLE knowledge.provenance IS
'Derivation edges from authoritative source claims to compiled AMEXAN objects across H1-H5. H5 objects include contexts, developmental stages, historian rules, response modes, response variants, adaptation rules, canonical mappings and provenance constraints.';


-- =============================================================================
-- 39. H5 ARCHITECTURAL COMMENTS
-- =============================================================================

COMMENT ON TABLE knowledge.context_precedence_rule IS
'Deterministic conflict-resolution layer for simultaneous patient contexts. Prevents hidden CPU assumptions when multiple contexts coexist.';

COMMENT ON TABLE knowledge.context_capture_constraint IS
'Declares whether a canonical fact/capture pathway is available in a particular clinical context or encounter mode.';

COMMENT ON TABLE knowledge.context_documentation_rule IS
'Controls preservation of capture-source provenance in documentation.';

COMMENT ON TABLE clinical.encounter_context IS
'Runtime context stack for an encounter. H5 knowledge defines possible contexts; this table records which contexts actually apply to this encounter.';


-- =============================================================================
-- 40. H5 VALIDATION VIEWS
-- =============================================================================
--
-- These views make the compiled medical intelligence auditable.
--
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_h5_context_rule_audit AS
SELECT
    r.rule_code,
    c.code AS context_code,
    c.label AS context_label,
    r.target_type,
    r.target_code,
    r.modification,
    r.priority_delta,
    r.required_historian,
    r.rationale,
    r.status
FROM knowledge.context_adaptation_rule r
JOIN knowledge.clinical_context c
    ON c.code = r.context_code;


CREATE OR REPLACE VIEW knowledge.v_h5_fact_provenance_audit AS
SELECT
    fp.id,
    fp.fact_definition_code,
    fp.capture_method_code,
    fcm.label AS capture_method,
    fp.historian_type_code,
    ht.label AS historian,
    fp.min_reliability_code,
    hr.label AS minimum_reliability,
    fp.is_valid
FROM knowledge.fact_provenance fp
JOIN knowledge.fact_capture_method fcm
    ON fcm.method_code = fp.capture_method_code
LEFT JOIN knowledge.historian_type ht
    ON ht.type_code = fp.historian_type_code
LEFT JOIN knowledge.historian_reliability hr
    ON hr.reliability_code = fp.min_reliability_code;


CREATE OR REPLACE VIEW knowledge.v_h5_question_variant_audit AS
SELECT
    qv.id,
    qv.question_id,
    qv.context,
    qv.language_code,
    qv.wording,
    qv.response_mode,
    rm.label AS response_mode_label,
    qv.historian_type,
    ht.label AS historian_label,
    qv.response_variant_id,
    rv.variant_name,
    qv.priority_delta,
    qv.is_disabled,
    qv.is_active
FROM knowledge.question_variant qv
LEFT JOIN knowledge.response_mode rm
    ON rm.mode_code = qv.response_mode
LEFT JOIN knowledge.historian_type ht
    ON ht.type_code = qv.historian_type
LEFT JOIN knowledge.response_variant rv
    ON rv.variant_id = qv.response_variant_id;


CREATE OR REPLACE VIEW knowledge.v_h5_encounter_context_stack AS
SELECT
    ec.id,
    ec.encounter_id,
    ec.context_code,
    cc.category,
    cc.label,
    cc.priority_weight,
    ec.source_type,
    ec.confidence,
    ec.effective_from,
    ec.effective_to,
    ec.status
FROM clinical.encounter_context ec
JOIN knowledge.clinical_context cc
    ON cc.code = ec.context_code;


-- =============================================================================
-- 41. H5 COMPLETENESS AUDIT
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_h5_context_completeness AS
SELECT
    cc.code AS context_code,
    cc.label,

    EXISTS (
        SELECT 1
        FROM knowledge.context_adaptation_rule r
        WHERE r.context_code = cc.code
          AND r.status = 'active'
    ) AS has_adaptation_rule,

    EXISTS (
        SELECT 1
        FROM knowledge.context_fact_mapping m
        WHERE m.context_code = cc.code
          AND m.status = 'active'
    ) AS has_fact_mapping,

    EXISTS (
        SELECT 1
        FROM knowledge.context_documentation_rule d
        WHERE d.context_code = cc.code
          AND d.status = 'active'
    ) AS has_documentation_rule

FROM knowledge.clinical_context cc
WHERE cc.status = 'active';


-- =============================================================================
-- 42. DATA INTEGRITY CHECKS
-- =============================================================================

DO $$
BEGIN

    -- Context codes must not be empty.
    IF EXISTS (
        SELECT 1
        FROM knowledge.clinical_context
        WHERE trim(code) = ''
    ) THEN
        RAISE EXCEPTION
            'H5 validation failed: empty clinical_context.code found';
    END IF;


    -- Developmental ranges must not overlap.
    IF EXISTS (
        SELECT 1
        FROM knowledge.developmental_stage a
        JOIN knowledge.developmental_stage b
          ON a.stage_code < b.stage_code
        WHERE
            a.min_age_days <= COALESCE(b.max_age_days, 999999999)
            AND b.min_age_days <= COALESCE(a.max_age_days, 999999999)
    ) THEN
        RAISE EXCEPTION
            'H5 validation failed: overlapping developmental-stage ranges found';
    END IF;


    -- Adaptation rules must point to active contexts.
    IF EXISTS (
        SELECT 1
        FROM knowledge.context_adaptation_rule r
        LEFT JOIN knowledge.clinical_context c
          ON c.code = r.context_code
        WHERE c.code IS NULL
    ) THEN
        RAISE EXCEPTION
            'H5 validation failed: adaptation rule references missing context';
    END IF;


    -- Functional domains must have stable codes.
    IF EXISTS (
        SELECT 1
        FROM knowledge.functional_domain
        WHERE trim(code) = ''
    ) THEN
        RAISE EXCEPTION
            'H5 validation failed: empty functional domain code found';
    END IF;

END $$;


-- =============================================================================
-- 43. H5 EXECUTION CONTRACT
-- =============================================================================
--
-- This comment is intentionally explicit because it is the contract between
-- PostgreSQL and the AMEXAN CPU.
--
-- =============================================================================

COMMENT ON SCHEMA knowledge IS
'AMEXAN Medical Knowledge Layer. H5 context rules are declarative knowledge/configuration. The CPU executes them and never invents medical adaptation logic.';


COMMIT;


-- =============================================================================
-- END H5 MIGRATION 029
-- =============================================================================
