-- =============================================================================
-- AMEXAN Medical Knowledge Compiler â€” H2
-- UNIVERSAL HISTORY ONTOLOGY + CLINICAL HISTORY RUNTIME SUBSTRATE
-- =============================================================================
--
-- PURPOSE
-- -------
-- H2 defines the universal machinery through which AMEXAN takes, structures,
-- stores, interprets, documents and reuses clinical history.
--
-- This is NOT a pneumonia engine.
-- This is NOT a TB engine.
-- This is NOT an OBG engine.
-- This is NOT a paediatric engine.
--
-- It is the universal substrate into which those domains plug.
--
--
-- CORE CLINICAL LOOP
-- ------------------
--
--     PRESENTING CONCERN
--            |
--            v
--     ACTIVE SYMPTOM(S)
--            |
--            v
--     HISTORY DIMENSIONS
--            |
--            v
--     CONTEXT ADAPTATION
--            |
--            v
--     QUESTION CANDIDATES
--            |
--            v
--     CPU PRIORITIZATION
--            |
--            v
--     UI QUESTION
--            |
--            v
--     STRUCTURED ANSWER
--            |
--            v
--     CLINICAL FACT
--            |
--            +--------------------+
--            |                    |
--            v                    v
--        TIMELINE             KNOWLEDGE GRAPH
--            |                    |
--            +---------+----------+
--                      |
--                      v
--                CLINICAL STATE
--                      |
--                      v
--               DOCUMENTATION
--                      |
--                      v
--               REASSESSMENT
--
--
-- ARCHITECTURAL LAW
-- -----------------
--
-- PostgreSQL:
--     KNOWLEDGE
--     CONFIGURATION
--     PROVENANCE
--     STRUCTURED CLINICAL DATA
--
-- CPU:
--     DECISION
--     QUESTION RANKING
--     CONTEXT RESOLUTION
--     EXECUTION
--     REASONING
--
-- UI:
--     RENDERING
--     INPUT
--     DISPLAY
--
-- The UI MUST NOT contain medical decision logic.
--
-- =============================================================================


BEGIN;


-- ============================================================================
-- 0. EXTEND THE UNIVERSAL CONCEPT VOCABULARY
-- ============================================================================
--
-- History concepts are not necessarily symptoms.
-- Examples:
--
--     ONSET
--     DURATION
--     PROGRESSION
--     SITE
--     CHARACTER
--     SEVERITY
--     RADIATION
--     TIMING
--     PRECIPITANTS
--     RELIEVING_FACTORS
--     ASSOCIATED_SYMPTOMS
--     FUNCTIONAL_IMPACT
--     PREVIOUS_EPISODES
--     HEALTH_SEEKING
--     MEDICATION_USE
--     ALLERGY
--     EXPOSURE
--     PATIENT_IDEA
--     PATIENT_CONCERN
--     PATIENT_EXPECTATION
--
-- They are reusable clinical primitives.
--
-- ============================================================================

ALTER TABLE knowledge.concept
    DROP CONSTRAINT IF EXISTS chk_knowledge_concept_type;

ALTER TABLE knowledge.concept
    ADD CONSTRAINT chk_knowledge_concept_type
    CHECK (
        concept_type IN (
            'symptom',
            'sign',
            'finding',
            'fact',
            'risk_factor',
            'mechanism',
            'phenotype',
            'condition',
            'investigation',
            'medication',
            'complication',
            'body_system',
            'examination_module',
            'examination_finding',
            'protocol',
            'monitoring',
            'education',
            'history_concept'
        )
    );


-- ============================================================================
-- 1. HISTORY CONCEPT
-- ============================================================================
--
-- Universal vocabulary for anything that can be captured during history.
--
-- IMPORTANT:
-- A history concept is not a question.
--
-- ONSET is a concept.
-- "When did the cough begin?" is a question.
-- The answer becomes a fact.
--
-- This separation allows:
--
--     one concept
--     many questions
--     many contexts
--     many languages
--     many UI presentations
--     one underlying clinical truth
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.history_concept (
    history_concept_id   text PRIMARY KEY,

    concept_code         text NOT NULL UNIQUE,

    concept_name         text NOT NULL,

    concept_type         text NOT NULL
        CHECK (
            concept_type IN (
                'encounter',
                'temporal',
                'symptom',
                'character',
                'location',
                'severity',
                'function',
                'associated',
                'background',
                'exposure',
                'reproductive',
                'medication',
                'allergy',
                'social',
                'family',
                'screening',
                'patient_perspective',
                'health_seeking',
                'source',
                'other'
            )
        ),

    reusable             boolean NOT NULL DEFAULT true,

    description          text,

    concept_id           uuid
        REFERENCES knowledge.concept(id)
        ON DELETE SET NULL,

    status               text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.history_concept IS
'Universal vocabulary of capturable clinical history concepts. Concepts are reusable across symptoms, diseases, specialties, age groups and encounters.';

COMMENT ON COLUMN knowledge.history_concept.concept_code IS
'Stable machine identifier for the history concept. The code represents the clinical meaning, not the wording of a question.';

COMMENT ON COLUMN knowledge.history_concept.concept_id IS
'Optional bridge into the universal AMEXAN knowledge graph concept layer.';


CREATE INDEX IF NOT EXISTS idx_history_concept_type
    ON knowledge.history_concept(concept_type);

CREATE INDEX IF NOT EXISTS idx_history_concept_status
    ON knowledge.history_concept(status);

CREATE INDEX IF NOT EXISTS idx_history_concept_concept
    ON knowledge.history_concept(concept_id);


DROP TRIGGER IF EXISTS trg_knowledge_history_concept_updated_at
    ON knowledge.history_concept;

CREATE TRIGGER trg_knowledge_history_concept_updated_at
    BEFORE UPDATE ON knowledge.history_concept
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 2. SYMPTOM â†’ HISTORY DIMENSION
-- ============================================================================
--
-- The symptom determines which dimensions are clinically meaningful.
--
-- Example:
--
-- COUGH:
--     onset
--     duration
--     progression
--     character
--     sputum
--     haemoptysis
--     triggers
--     relieving factors
--     associated symptoms
--     systemic symptoms
--     functional impact
--
-- The UI does NOT hardcode these.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_history_dimension (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    history_concept_id  text NOT NULL
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE CASCADE,

    priority            integer NOT NULL DEFAULT 50,

    mandatory           boolean NOT NULL DEFAULT false,

    applicable          boolean NOT NULL DEFAULT true,

    repeatable          boolean NOT NULL DEFAULT false,

    documentation_group text,

    rationale           text,

    UNIQUE (symptom_id, history_concept_id)
);

COMMENT ON TABLE knowledge.symptom_history_dimension IS
'Defines which history dimensions are meaningful for a symptom. Prevents irrelevant questioning and enables symptom-driven adaptive history taking.';


CREATE INDEX IF NOT EXISTS idx_symptom_history_dimension_symptom
    ON knowledge.symptom_history_dimension(symptom_id, priority);

CREATE INDEX IF NOT EXISTS idx_symptom_history_dimension_concept
    ON knowledge.symptom_history_dimension(history_concept_id);


-- ============================================================================
-- 3. HISTORY CONTEXT RULE
-- ============================================================================
--
-- History is contextual.
--
-- The same clinical concept can require different questioning in:
--
--     adult
--     child
--     neonate
--     older adult
--     pregnancy
--     emergency
--     unconscious patient
--     cognitively impaired patient
--     caregiver-mediated history
--     psychiatric assessment
--     trauma
--
-- The database stores the adaptation.
-- The CPU executes it.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.history_context_rule (
    rule_id             text PRIMARY KEY,

    subject_code        text NOT NULL,

    context_label       text NOT NULL,

    context_type_code   text
        REFERENCES knowledge.context_type(code),

    context_value_id    uuid
        REFERENCES knowledge.context_value(id)
        ON DELETE SET NULL,

    action              text NOT NULL,

    action_type         text NOT NULL DEFAULT 'modify'
        CHECK (
            action_type IN (
                'include',
                'exclude',
                'modify',
                'prioritize',
                'deprioritize',
                'replace',
                'require',
                'repeat'
            )
        ),

    priority_delta      integer NOT NULL DEFAULT 0,

    description         text,

    sort_order          integer NOT NULL DEFAULT 0,

    is_active           boolean NOT NULL DEFAULT true,

    UNIQUE (subject_code, context_label, action_type)
);

COMMENT ON TABLE knowledge.history_context_rule IS
'Context-dependent adaptations to history taking. The CPU resolves these rules before presenting candidate questions.';


CREATE INDEX IF NOT EXISTS idx_history_context_rule_subject
    ON knowledge.history_context_rule(subject_code);

CREATE INDEX IF NOT EXISTS idx_history_context_rule_context
    ON knowledge.history_context_rule(context_label);

CREATE INDEX IF NOT EXISTS idx_history_context_rule_active
    ON knowledge.history_context_rule(is_active);


-- ============================================================================
-- 4. EXISTING QUESTION REGISTRY â€” ADD HISTORY SEMANTICS
-- ============================================================================

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS history_concept_id
        text REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE SET NULL;

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS question_mode
        text
        CHECK (
            question_mode IN (
                'OPEN',
                'DIRECT',
                'CLARIFYING',
                'SCALE',
                'FUNCTIONAL',
                'PROBING',
                'NEGATIVE_EXCLUSION',
                'CONTEXT'
            )
        );

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS question_purpose
        text;

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS expected_answer_type
        text;

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS is_foundational
        boolean NOT NULL DEFAULT false;

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS is_safety_critical
        boolean NOT NULL DEFAULT false;

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS repeatable
        boolean NOT NULL DEFAULT false;

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS documentation_relevant
        boolean NOT NULL DEFAULT true;


CREATE INDEX IF NOT EXISTS idx_question_history_concept
    ON knowledge.question(history_concept_id);

CREATE INDEX IF NOT EXISTS idx_question_mode
    ON knowledge.question(question_mode);

CREATE INDEX IF NOT EXISTS idx_question_safety
    ON knowledge.question(is_safety_critical)
    WHERE is_safety_critical = true;


-- ============================================================================
-- 5. QUESTION VARIANTS
-- ============================================================================
--
-- One clinical question.
-- Many ways of asking it.
--
-- Example:
--
-- Adult:
--     "When did the cough begin?"
--
-- Child/caregiver:
--     "When did you first notice the child coughing?"
--
-- The underlying concept and resulting fact remain identical.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_variant (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    context             text NOT NULL DEFAULT 'default',

    language_code       text NOT NULL DEFAULT 'en',

    audience            text NOT NULL DEFAULT 'patient'
        CHECK (
            audience IN (
                'patient',
                'caregiver',
                'clinician',
                'interpreter',
                'collateral'
            )
        ),

    wording             text NOT NULL,

    help_text           text,

    placeholder         text,

    is_active           boolean NOT NULL DEFAULT true,

    UNIQUE (question_id, context, language_code, audience)
);

COMMENT ON TABLE knowledge.question_variant IS
'Presentation variants of the same clinical question. The semantic clinical object remains unchanged.';


CREATE INDEX IF NOT EXISTS idx_question_variant_question
    ON knowledge.question_variant(question_id);

CREATE INDEX IF NOT EXISTS idx_question_variant_context
    ON knowledge.question_variant(context, language_code);


-- ============================================================================
-- 6. QUESTION PRIORITY RULES
-- ============================================================================
--
-- The CPU does not simply iterate through a questionnaire.
--
-- Candidate questions receive priority from multiple factors.
--
-- Typical factors:
--
--     presenting_concern
--     mandatory_foundation
--     emergency_red_flag
--     safety_critical
--     diagnostic_discrimination
--     unanswered_high_value
--     context_specific
--     chronology
--     documentation_completeness
--     functional_impact
--     patient_goal
--
-- The CPU combines these with current facts.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_priority_rule (
    rule_code           text PRIMARY KEY,

    factor              text NOT NULL UNIQUE,

    effect              integer NOT NULL DEFAULT 0,

    description         text,

    is_active           boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.question_priority_rule IS
'Data-driven factors used by the CPU to rank candidate clinical questions.';


CREATE INDEX IF NOT EXISTS idx_question_priority_active
    ON knowledge.question_priority_rule(is_active);


-- ============================================================================
-- 7. QUESTION PRIORITY BINDING
-- ============================================================================
--
-- Allows an individual question to receive a specific priority contribution
-- from a named factor.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_priority (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    rule_code           text NOT NULL
        REFERENCES knowledge.question_priority_rule(rule_code)
        ON DELETE CASCADE,

    weight              numeric(6,2) NOT NULL DEFAULT 1.0,

    UNIQUE (question_id, rule_code)
);

CREATE INDEX IF NOT EXISTS idx_question_priority_question
    ON knowledge.question_priority(question_id);


-- ============================================================================
-- 8. QUESTION TRIGGERS
-- ============================================================================
--
-- A trigger answers:
--
-- "What existing clinical state makes this question relevant?"
--
-- Examples:
--
--     COUGH_PRESENT
--          -> activate COUGH_PRODUCTIVITY
--
--     CHEST_PAIN_PRESENT
--          -> activate RADIATION
--
--     HAEMOPTYSIS_PRESENT
--          -> activate QUANTITY
--
--     PREGNANT
--          -> activate REPRODUCTIVE / OBSTETRIC branches
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_trigger CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_trigger (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    trigger_type        text NOT NULL,

    trigger_code        text NOT NULL,

    priority            integer NOT NULL DEFAULT 50,

    activation_mode     text NOT NULL DEFAULT 'when_present'
        CHECK (
            activation_mode IN (
                'when_present',
                'when_absent',
                'when_unknown',
                'when_changed'
            )
        ),

    description         text,

    UNIQUE (
        question_id,
        trigger_type,
        trigger_code,
        activation_mode
    )
);

COMMENT ON TABLE knowledge.question_trigger IS
'Activates adaptive-history questions from captured clinical state.';


CREATE INDEX IF NOT EXISTS idx_question_trigger_question
    ON knowledge.question_trigger(question_id);

CREATE INDEX IF NOT EXISTS idx_question_trigger_lookup
    ON knowledge.question_trigger(trigger_type, trigger_code, priority);


-- ============================================================================
-- 9. QUESTION REQUIREMENTS
-- ============================================================================
--
-- A requirement is different from a trigger.
--
-- Trigger:
--     "This question becomes relevant."
--
-- Requirement:
--     "This condition must be satisfied before the question is asked."
--
-- This allows sophisticated gating without embedding logic in the UI.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_requirement CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_requirement (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    requirement_type    text NOT NULL
        CHECK (
            requirement_type IN (
                'requires_fact',
                'requires_context',
                'requires_symptom',
                'requires_question_answer',
                'excludes_fact',
                'excludes_context'
            )
        ),

    requirement_code    text NOT NULL,

    operator            text NOT NULL DEFAULT 'present'
        CHECK (
            operator IN (
                'present',
                'absent',
                'equals',
                'not_equals',
                'greater_than',
                'less_than',
                'greater_or_equal',
                'less_or_equal',
                'in'
            )
        ),

    expected_value      text,

    required            boolean NOT NULL DEFAULT true,

    UNIQUE (
        question_id,
        requirement_type,
        requirement_code,
        operator,
        expected_value
    )
);

COMMENT ON TABLE knowledge.question_requirement IS
'Machine-evaluable prerequisites and exclusions controlling adaptive question eligibility.';


CREATE INDEX IF NOT EXISTS idx_question_requirement_question
    ON knowledge.question_requirement(question_id);

CREATE INDEX IF NOT EXISTS idx_question_requirement_lookup
    ON knowledge.question_requirement(
        requirement_type,
        requirement_code
    );


-- ============================================================================
-- 10. RAW-VALUE QUESTION â†’ FACT
-- ============================================================================
--
-- Choice questions use answer_option/fact_mapping.
--
-- Numeric/text/date questions have no answer options.
--
-- Their answer itself is the medical value.
--
-- Example:
--
--     Question:
--         "How many days have you had the cough?"
--
--     Answer:
--         4
--
--     Fact:
--         COUGH_DURATION_DAYS = 4
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_fact CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_fact (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id            uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    fact_definition_code   text NOT NULL
        REFERENCES clinical.fact_definition(code),

    unit_code              text
        REFERENCES terminology.unit(code),

    value_transform        jsonb,

    UNIQUE (question_id, fact_definition_code)
);

COMMENT ON TABLE knowledge.question_fact IS
'Binds raw-value questions to the clinical facts acquired directly from their typed answers.';


CREATE INDEX IF NOT EXISTS idx_question_fact_question
    ON knowledge.question_fact(question_id);

CREATE INDEX IF NOT EXISTS idx_question_fact_fact
    ON knowledge.question_fact(fact_definition_code);


-- ============================================================================
-- 11. THREE-STATE CLINICAL KNOWLEDGE
-- ============================================================================
--
-- TRUE and FALSE are both clinical information.
--
-- UNKNOWN means:
--     the question was asked/considered,
--     but the clinical state could not be established.
--
-- NOT ASKED is represented by absence of a corresponding fact.
--
-- Therefore:
--
--     no row          = NOT ASKED
--     unknown row    = ASKED / UNKNOWN
--     known + true   = TRUE
--     known + false  = FALSE
--
-- ============================================================================

ALTER TABLE clinical.fact_value
    ADD COLUMN IF NOT EXISTS value_state text
        NOT NULL DEFAULT 'known'
        CHECK (value_state IN ('known','unknown'));


DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fact_value_unknown_has_no_value'
    ) THEN

        ALTER TABLE clinical.fact_value
            ADD CONSTRAINT fact_value_unknown_has_no_value
            CHECK (
                value_state = 'known'
                OR (
                    value_text IS NULL
                    AND value_numeric IS NULL
                    AND value_boolean IS NULL
                    AND value_date IS NULL
                    AND value_datetime IS NULL
                    AND value_concept_id IS NULL
                )
            );

    END IF;
END
$$;


CREATE INDEX IF NOT EXISTS idx_fact_value_state
    ON clinical.fact_value(value_state);


-- ============================================================================
-- 12. FACT SOURCE / PROVENANCE HARDENING
-- ============================================================================
--
-- The CPU must know where a clinical fact came from.
--
--     patient
--     caregiver
--     clinician
--     laboratory
--     imaging
--     device
--     imported_record
--     previous_encounter
--     inferred
--
-- The source is not merely metadata.
-- It changes how confidently the CPU may use the information.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.fact_source CASCADE;
CREATE TABLE IF NOT EXISTS clinical.fact_source (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id             uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    source_type         text NOT NULL
        CHECK (
            source_type IN (
                'patient',
                'caregiver',
                'clinician',
                'collateral',
                'laboratory',
                'imaging',
                'device',
                'previous_encounter',
                'imported_record',
                'protocol',
                'system',
                'inferred'
            )
        ),

    source_id           uuid,

    encounter_id        uuid
        REFERENCES encounter.encounter(id)
        ON DELETE SET NULL,

    recorded_by         uuid
        REFERENCES identity.user_account(id),

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    note                text
);

COMMENT ON TABLE clinical.fact_source IS
'Provenance of a clinical fact. Enables the CPU to distinguish patient report, clinician observation, investigation result, imported information and inference.';


CREATE INDEX IF NOT EXISTS idx_fact_source_fact
    ON clinical.fact_source(fact_id);

CREATE INDEX IF NOT EXISTS idx_fact_source_encounter
    ON clinical.fact_source(encounter_id);

CREATE INDEX IF NOT EXISTS idx_fact_source_type2
    ON clinical.fact_source(source_type);


-- ============================================================================
-- 13. FACT CONFIDENCE
-- ============================================================================
--
-- Reliability and confidence are distinct.
--
-- Reliability:
--     how trustworthy is the history source?
--
-- Confidence:
--     how confident are we in this particular fact?
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.fact_confidence CASCADE;
CREATE TABLE IF NOT EXISTS clinical.fact_confidence (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id             uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    confidence          numeric(4,3) NOT NULL
        CHECK (confidence >= 0 AND confidence <= 1),

    basis               text,

    assessed_by         uuid
        REFERENCES identity.user_account(id),

    assessed_at         timestamptz NOT NULL DEFAULT now(),

    UNIQUE (fact_id)
);

COMMENT ON TABLE clinical.fact_confidence IS
'Confidence attached to an individual clinical fact.';


-- ============================================================================
-- 14. FACT RELATIONSHIPS
-- ============================================================================
--
-- Facts rarely exist independently.
--
-- Examples:
--
--     COUGH
--        |
--        +-- started_before --> FEVER
--
--     CHEST_PAIN
--        |
--        +-- radiates_to --> LEFT_ARM
--
--     DYSPNOEA
--        |
--        +-- worsened_by --> EXERTION
--
-- Keep relationships universal.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.fact_relationship CASCADE;
CREATE TABLE IF NOT EXISTS clinical.fact_relationship (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_fact_id      uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    relationship        text NOT NULL,

    target_fact_id      uuid
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    target_code         text,

    weight              numeric(3,2) NOT NULL DEFAULT 1.0,

    confidence           numeric(4,3)
        CHECK (confidence >= 0 AND confidence <= 1),

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        source_fact_id,
        relationship,
        target_fact_id
    )
);

COMMENT ON TABLE clinical.fact_relationship IS
'Universal relationships between clinical facts. Supports temporal, causal, anatomical, functional and contextual connections.';


CREATE INDEX IF NOT EXISTS idx_fact_relationship_source
    ON clinical.fact_relationship(source_fact_id);

CREATE INDEX IF NOT EXISTS idx_fact_relationship_target
    ON clinical.fact_relationship(target_fact_id);

CREATE INDEX IF NOT EXISTS idx_fact_relationship_type
    ON clinical.fact_relationship(relationship);


-- ============================================================================
-- 15. CLINICAL EVENT / TIMELINE
-- ============================================================================
--
-- A flat fact list is not a history.
--
-- AMEXAN needs to reconstruct:
--
--     Day 1  â†’ cough
--     Day 2  â†’ fever
--     Day 3  â†’ sputum
--     Day 4  â†’ dyspnoea
--
-- The CPU therefore requires explicit timeline objects.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.clinical_event (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES encounter.encounter(id)
        ON DELETE SET NULL,

    event_type          text NOT NULL,

    event_time          timestamptz,

    event_end_time      timestamptz,

    event_order         integer,

    time_precision      text NOT NULL DEFAULT 'exact'
        CHECK (
            time_precision IN (
                'exact',
                'day',
                'week',
                'month',
                'year',
                'approximate',
                'relative',
                'unknown'
            )
        ),

    relative_day        integer,

    fact_id             uuid
        REFERENCES clinical.fact(id)
        ON DELETE SET NULL,

    description         text,

    source_type         text,

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
        REFERENCES identity.user_account(id)
);

COMMENT ON TABLE clinical.clinical_event IS
'Universal patient timeline. Anchors clinical facts to time so the CPU can reconstruct chronology rather than reason over a flat fact list.';


CREATE INDEX IF NOT EXISTS idx_clinical_event_patient_time
    ON clinical.clinical_event(patient_id, event_time);

CREATE INDEX IF NOT EXISTS idx_clinical_event_encounter_time
    ON clinical.clinical_event(encounter_id, event_time);

CREATE INDEX IF NOT EXISTS idx_clinical_event_fact
    ON clinical.clinical_event(fact_id);

CREATE INDEX IF NOT EXISTS idx_clinical_event_type2
    ON clinical.clinical_event(event_type);


-- ============================================================================
-- 16. HISTORY RELIABILITY
-- ============================================================================
--
-- Reliability can vary by dimension.
--
-- Example:
--
--     overall              = reliable
--     chronology           = uncertain
--     medication_history   = unreliable
--     collateral_available= yes
--
-- This prevents the CPU from treating every history statement as equally
-- trustworthy.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_reliability (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    dimension           text NOT NULL,

    value               text NOT NULL
        CHECK (
            value IN (
                'reliable',
                'partially_reliable',
                'uncertain',
                'unreliable',
                'yes',
                'no',
                'unknown',
                'not_assessed'
            )
        ),

    assessed_at         timestamptz NOT NULL DEFAULT now(),

    assessed_by         uuid
        REFERENCES identity.user_account(id),

    note                text,

    UNIQUE (encounter_id, dimension)
);

COMMENT ON TABLE clinical.history_reliability IS
'Reliability of different components of the clinical history. The CPU must account for reliability before using facts as verified clinical truth.';


CREATE INDEX IF NOT EXISTS idx_history_reliability_encounter
    ON clinical.history_reliability(encounter_id);


-- ============================================================================
-- 17. PATIENT PERSPECTIVE
-- ============================================================================
--
-- These are not diagnoses.
--
-- They capture the patient's illness framework:
--
--     IDEA
--     CONCERN
--     EXPECTATION
--     GOAL
--
-- This is clinically meaningful but must remain distinct from objective facts.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.patient_perspective (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    encounter_id        uuid
        REFERENCES encounter.encounter(id)
        ON DELETE SET NULL,

    perspective_type    text NOT NULL
        CHECK (
            perspective_type IN (
                'IDEA',
                'CONCERN',
                'EXPECTATION',
                'GOAL'
            )
        ),

    value               text NOT NULL,

    patient_quote       text,

    language_code       text NOT NULL DEFAULT 'en',

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
        REFERENCES identity.user_account(id)
);

COMMENT ON TABLE clinical.patient_perspective IS
'Patient-reported ideas, concerns, expectations and goals. These are part of the clinical encounter but are never converted into diagnostic conclusions by documentation logic.';


CREATE INDEX IF NOT EXISTS idx_patient_perspective_patient
    ON clinical.patient_perspective(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_perspective_encounter
    ON clinical.patient_perspective(encounter_id);


-- ============================================================================
-- 18. FUNCTIONAL IMPACT VOCABULARY
-- ============================================================================
--
-- Function is universal medicine.
--
-- Examples:
--
--     walking
--     exercise
--     work
--     education
--     eating
--     sleep
--     activities of daily living
--     social activity
--     communication
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.functional_impact (
    function_code       text PRIMARY KEY,

    domain              text NOT NULL
        CHECK (
            domain IN (
                'mobility',
                'physical_activity',
                'occupation',
                'education',
                'nutrition',
                'sleep',
                'social',
                'adl',
                'communication',
                'self_care',
                'sexual_health',
                'recreation',
                'other'
            )
        ),

    label               text NOT NULL,

    description         text,

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

COMMENT ON TABLE knowledge.functional_impact IS
'Universal functional-impact vocabulary shared by every symptom, specialty and disease.';


-- ============================================================================
-- 19. SYMPTOM â†’ FUNCTIONAL IMPACT
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_functional_impact CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.symptom_functional_impact (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    functional_impact_code text NOT NULL
        REFERENCES knowledge.functional_impact(function_code),

    priority            integer NOT NULL DEFAULT 50,

    mandatory           boolean NOT NULL DEFAULT false,

    rationale           text,

    UNIQUE (
        symptom_id,
        functional_impact_code
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_functional_impact_symptom
    ON knowledge.symptom_functional_impact(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_functional_impact_function
    ON knowledge.symptom_functional_impact(functional_impact_code);


-- ============================================================================
-- 20. QUESTION â†’ FUNCTIONAL IMPACT
-- ============================================================================
--
-- Allows the question itself to acquire functional information.
--
-- Example:
--
--     "Does the breathlessness limit your normal activities?"
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_functional_impact (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    function_code       text NOT NULL
        REFERENCES knowledge.functional_impact(function_code),

    UNIQUE (question_id, function_code)
);


-- ============================================================================
-- 21. HISTORY SOURCE
-- ============================================================================
--
-- WHO supplied this part of the history?
--
-- Patient is not always the source.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.history_source CASCADE;
CREATE TABLE IF NOT EXISTS clinical.history_source (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    source_type         text NOT NULL
        CHECK (
            source_type IN (
                'patient',
                'parent',
                'caregiver',
                'relative',
                'partner',
                'guardian',
                'clinician',
                'interpreter',
                'previous_record',
                'emergency_services',
                'other'
            )
        ),

    source_name         text,

    relationship_to_patient text,

    limitations         text,

    is_primary_source   boolean NOT NULL DEFAULT false,

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
        REFERENCES identity.user_account(id)
);

COMMENT ON TABLE clinical.history_source IS
'Identifies the source of the clinical history and limitations affecting reliability.';


CREATE INDEX IF NOT EXISTS idx_history_source_encounter
    ON clinical.history_source(encounter_id);


-- ============================================================================
-- 22. HISTORY CONCEPT â†’ QUESTION
-- ============================================================================
--
-- Usually a question maps to one history concept.
-- Keeping an explicit junction allows future compound questions.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_history_concept (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    history_concept_id  text NOT NULL
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE CASCADE,

    role                text NOT NULL DEFAULT 'captures'
        CHECK (
            role IN (
                'captures',
                'clarifies',
                'qualifies',
                'screens',
                'excludes',
                'contextualizes'
            )
        ),

    UNIQUE (question_id, history_concept_id, role)
);

CREATE INDEX IF NOT EXISTS idx_question_history_concept_question
    ON knowledge.question_history_concept(question_id);

CREATE INDEX IF NOT EXISTS idx_question_history_concept_concept
    ON knowledge.question_history_concept(history_concept_id);


-- ============================================================================
-- 23. HISTORY DOCUMENTATION GROUPS
-- ============================================================================
--
-- Documentation must follow medical narrative order rather than database
-- insertion order.
--
-- Universal groups:
--
--     presenting
--     chronology
--     character
--     sputum
--     associated
--     systemic
--     ent_gi
--     risk
--     previous
--     health_seeking
--     severity
--     functional
--     examination
--
-- A symptom may populate only the groups that are clinically relevant.
--
-- ============================================================================

ALTER TABLE knowledge.symptom_hpi_template
    ADD COLUMN IF NOT EXISTS documentation_group text;

UPDATE knowledge.symptom_hpi_template
SET documentation_group = 'associated'
WHERE documentation_group IS NULL;


ALTER TABLE knowledge.symptom_hpi_template
    DROP CONSTRAINT IF EXISTS symptom_hpi_template_documentation_group_check;


ALTER TABLE knowledge.symptom_hpi_template
    ADD CONSTRAINT symptom_hpi_template_documentation_group_check
    CHECK (
        documentation_group IN (
            'presenting',
            'chronology',
            'character',
            'sputum',
            'associated',
            'systemic',
            'ent_gi',
            'risk',
            'previous',
            'health_seeking',
            'severity',
            'functional',
            'examination'
        )
    );


-- ============================================================================
-- 24. DOCUMENTATION ORDER
-- ============================================================================
--
-- Centralizes narrative ordering instead of relying on UI ordering.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.documentation_group CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.documentation_group (
    group_code          text PRIMARY KEY,

    label               text NOT NULL,

    sequence_no         integer NOT NULL UNIQUE,

    description         text,

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

COMMENT ON TABLE knowledge.documentation_group IS
'Universal clinical documentation ordering. Documentation engines use this ordering to reconstruct coherent medical narratives from structured facts.';


INSERT INTO knowledge.documentation_group
    (group_code, label, sequence_no, description)
VALUES
    ('presenting',      'Presenting complaint',       10,
     'What brought the patient for care.'),
    ('chronology',      'Chronology',                 20,
     'Onset, duration, progression and temporal sequence.'),
    ('character',       'Character and characteristics', 30,
     'Nature and specific characteristics of the presenting symptom.'),
    ('sputum',          'Sputum / product',            40,
     'Relevant produced material where applicable.'),
    ('associated',      'Associated symptoms',         50,
     'Symptoms occurring with or around the presenting complaint.'),
    ('systemic',        'Systemic symptoms',           60,
     'General/systemic manifestations.'),
    ('ent_gi',          'ENT / gastrointestinal',     70,
     'Relevant ENT or GI associated features.'),
    ('risk',             'Risk factors and exposures', 80,
     'Relevant predispositions, exposures and contextual factors.'),
    ('previous',         'Previous history of problem', 90,
     'Previous episodes, diagnosis, investigations and treatment.'),
    ('health_seeking',   'Health-seeking history',     100,
     'Prior consultation, treatment, self-medication and response.'),
    ('severity',         'Severity / progression / red flags', 110,
     'Severity, deterioration, complications and danger features.'),
    ('functional',       'Functional impact',          120,
     'Effect on normal activity and patient life.'),
    ('examination',      'Examination',               130,
     'Examination findings documented separately from the history.')
ON CONFLICT (group_code) DO NOTHING;


-- ============================================================================
-- 25. HISTORY SECTION INSTANCE
-- ============================================================================
--
-- Allows a live encounter to know which documentation sections are applicable.
--
-- This is configuration/state, not prose.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_section (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    group_code          text NOT NULL
        REFERENCES knowledge.documentation_group(group_code),

    sequence_no         integer NOT NULL,

    status              text NOT NULL DEFAULT 'open'
        CHECK (
            status IN (
                'open',
                'complete',
                'not_applicable',
                'deferred'
            )
        ),

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (encounter_id, group_code)
);

CREATE INDEX IF NOT EXISTS idx_history_section_encounter
    ON clinical.history_section(encounter_id, sequence_no);


-- ============================================================================
-- 26. HISTORY COMPLETENESS
-- ============================================================================
--
-- Completeness is NOT diagnosis.
--
-- It answers:
--
--     What relevant history has been captured?
--     What remains unknown?
--     What has not been asked?
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_completeness (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    symptom_id          uuid
        REFERENCES knowledge.symptom(id)
        ON DELETE SET NULL,

    history_concept_id  text
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE SET NULL,

    state               text NOT NULL
        CHECK (
            state IN (
                'captured',
                'unknown',
                'not_asked',
                'not_applicable',
                'deferred'
            )
        ),

    last_question_id    uuid
        REFERENCES knowledge.question(id)
        ON DELETE SET NULL,

    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        encounter_id,
        symptom_id,
        history_concept_id
    )
);

COMMENT ON TABLE clinical.history_completeness IS
'Tracks whether clinically relevant history dimensions have been captured, remain unknown, were not asked, or are not applicable.';


CREATE INDEX IF NOT EXISTS idx_history_completeness_encounter
    ON clinical.history_completeness(encounter_id);

CREATE INDEX IF NOT EXISTS idx_history_completeness_state
    ON clinical.history_completeness(encounter_id, state);


-- ============================================================================
-- 27. QUESTION RESPONSE AUDIT
-- ============================================================================
--
-- A clinical answer should be auditable independently from the resulting fact.
--
-- This allows:
--
--     question asked
--     wording presented
--     answer supplied
--     who answered
--     when answered
--     resulting fact
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.question_response CASCADE;
CREATE TABLE IF NOT EXISTS clinical.question_response (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id),

    variant_id          uuid
        REFERENCES knowledge.question_variant(id)
        ON DELETE SET NULL,

    answer_state        text NOT NULL DEFAULT 'answered'
        CHECK (
            answer_state IN (
                'answered',
                'unknown',
                'declined',
                'unable',
                'not_applicable',
                'skipped'
            )
        ),

    raw_answer          jsonb,

    answered_by         uuid
        REFERENCES identity.user_account(id),

    source_type         text,

    answered_at         timestamptz NOT NULL DEFAULT now(),

    cpu_pass_id         uuid,

    UNIQUE (
        encounter_id,
        question_id,
        answered_at
    )
);

COMMENT ON TABLE clinical.question_response IS
'Auditable record of the question presented and the answer supplied before transformation into clinical facts.';


CREATE INDEX IF NOT EXISTS idx_question_response_encounter
    ON clinical.question_response(encounter_id, answered_at);

CREATE INDEX IF NOT EXISTS idx_question_response_patient
    ON clinical.question_response(patient_id, answered_at);

CREATE INDEX IF NOT EXISTS idx_question_response_question
    ON clinical.question_response(question_id);


-- ============================================================================
-- 28. QUESTION RESPONSE â†’ FACT
-- ============================================================================
--
-- One response can establish one or more facts.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_response_fact (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    response_id         uuid NOT NULL
        REFERENCES clinical.question_response(id)
        ON DELETE CASCADE,

    fact_id             uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    transformation     text,

    UNIQUE (response_id, fact_id)
);

CREATE INDEX IF NOT EXISTS idx_question_response_fact_response
    ON clinical.question_response_fact(response_id);

CREATE INDEX IF NOT EXISTS idx_question_response_fact_fact
    ON clinical.question_response_fact(fact_id);


-- ============================================================================
-- 29. FACT REVISION / HISTORY
-- ============================================================================
--
-- Clinical truth can change.
--
-- Example:
--
--     initially: cough = dry
--     later:     cough = productive
--
-- The old fact should not simply disappear.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.fact_history CASCADE;
CREATE TABLE IF NOT EXISTS clinical.fact_history (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_id             uuid NOT NULL
        REFERENCES clinical.fact(id)
        ON DELETE CASCADE,

    action              text NOT NULL
        CHECK (
            action IN (
                'created',
                'corrected',
                'superseded',
                'retracted',
                'confirmed'
            )
        ),

    previous_fact_id    uuid
        REFERENCES clinical.fact(id)
        ON DELETE SET NULL,

    reason              text,

    changed_by          uuid
        REFERENCES identity.user_account(id),

    changed_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fact_history_fact
    ON clinical.fact_history(fact_id, changed_at);


-- ============================================================================
-- 30. QUESTION ATTEMPT / DUPLICATION CONTROL
-- ============================================================================
--
-- AMEXAN should be intelligent enough not to repeatedly ask the same question
-- unless:
--
--     the answer is unknown,
--     the clinical state changed,
--     the question is repeatable,
--     reassessment is clinically appropriate.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_attempt (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    question_id         uuid NOT NULL
        REFERENCES knowledge.question(id),

    attempted_at        timestamptz NOT NULL DEFAULT now(),

    result_state        text NOT NULL
        CHECK (
            result_state IN (
                'answered',
                'unknown',
                'declined',
                'unable',
                'skipped'
            )
        ),

    cpu_pass_id         uuid,

    UNIQUE (
        encounter_id,
        question_id,
        attempted_at
    )
);

CREATE INDEX IF NOT EXISTS idx_question_attempt_lookup
    ON clinical.question_attempt(encounter_id, question_id, attempted_at);


-- ============================================================================
-- 31. HISTORY CONCEPT â†’ DOCUMENTATION GROUP
-- ============================================================================
--
-- Prevents documentation order from being inferred from question order.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.history_concept_documentation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    history_concept_id  text NOT NULL
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE CASCADE,

    group_code          text NOT NULL
        REFERENCES knowledge.documentation_group(group_code),

    priority            integer NOT NULL DEFAULT 50,

    UNIQUE (history_concept_id, group_code)
);

CREATE INDEX IF NOT EXISTS idx_history_concept_documentation_group
    ON knowledge.history_concept_documentation(group_code);


-- ============================================================================
-- 32. HISTORY CONCEPT â†’ FACT
-- ============================================================================
--
-- Gives the compiler a universal relationship:
--
--     HISTORY CONCEPT
--          â†“
--     FACT DEFINITION
--
-- Example:
--
--     COUGH_DURATION
--          â†“
--     COUGH_DURATION_DAYS
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.history_concept_fact (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    history_concept_id  text NOT NULL
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE CASCADE,

    fact_definition_code text NOT NULL
        REFERENCES clinical.fact_definition(code),

    role                text NOT NULL DEFAULT 'captures'
        CHECK (
            role IN (
                'captures',
                'qualifies',
                'contextualizes',
                'supports'
            )
        ),

    UNIQUE (
        history_concept_id,
        fact_definition_code,
        role
    )
);

CREATE INDEX IF NOT EXISTS idx_history_concept_fact_concept
    ON knowledge.history_concept_fact(history_concept_id);

CREATE INDEX IF NOT EXISTS idx_history_concept_fact_fact
    ON knowledge.history_concept_fact(fact_definition_code);


-- ============================================================================
-- 33. SYMPTOM â†’ HISTORY CONCEPT â†’ FACT PATH
-- ============================================================================
--
-- This is one of the most important universal pathways in AMEXAN.
--
--     SYMPTOM
--        â†“
--     HISTORY CONCEPT
--        â†“
--     QUESTION
--        â†“
--     ANSWER
--        â†“
--     FACT
--
-- It permits disease-independent clinical history.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_history_fact (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    history_concept_id  text NOT NULL
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE CASCADE,

    fact_definition_code text NOT NULL
        REFERENCES clinical.fact_definition(code),

    priority            integer NOT NULL DEFAULT 50,

    mandatory           boolean NOT NULL DEFAULT false,

    rationale            text,

    UNIQUE (
        symptom_id,
        history_concept_id,
        fact_definition_code
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_history_fact_symptom
    ON knowledge.symptom_history_fact(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_history_fact_fact
    ON knowledge.symptom_history_fact(fact_definition_code);


-- ============================================================================
-- 34. PROVENANCE HARDENING
-- ============================================================================
--
-- H1 claims â†’ H2 history concepts/questions/facts/documentation rules.
--
-- ============================================================================

COMMENT ON TABLE knowledge.provenance IS
'AMEXAN provenance graph linking compiled operational knowledge objects back to atomic source claims. H1 source claims may generate H2 history concepts, questions, facts, documentation structures and subsequent clinical knowledge objects.';


-- ============================================================================
-- 35. UNIVERSAL HISTORY CONCEPT SEEDS
-- ============================================================================
--
-- These are foundational concepts, NOT disease-specific.
--
-- They are intentionally reusable across all medicine.
--
-- ============================================================================

INSERT INTO knowledge.history_concept
(
    history_concept_id,
    concept_code,
    concept_name,
    concept_type,
    description
)
VALUES

('HC001','PRESENTING_CONCERN','Presenting concern','encounter',
 'The primary concern or reason for seeking care.'),

('HC002','ONSET','Onset','temporal',
 'When the symptom or problem began.'),

('HC003','DURATION','Duration','temporal',
 'How long the symptom or problem has been present.'),

('HC004','PROGRESSION','Progression','temporal',
 'How the problem has changed over time.'),

('HC005','SITE','Site','location',
 'Anatomical location of the symptom or problem.'),

('HC006','CHARACTER','Character','character',
 'The qualitative nature of the symptom.'),

('HC007','SEVERITY','Severity','severity',
 'Intensity or clinical severity as experienced or measured.'),

('HC008','RADIATION','Radiation','location',
 'Spread of a symptom from its primary site.'),

('HC009','TIMING','Timing','temporal',
 'Temporal pattern, periodicity or relationship to time.'),

('HC010','PRECIPITATING_FACTOR','Precipitating factor','associated',
 'Factor that brings on or worsens the symptom.'),

('HC011','RELIEVING_FACTOR','Relieving factor','associated',
 'Factor that reduces the symptom.'),

('HC012','ASSOCIATED_SYMPTOM','Associated symptom','associated',
 'Other symptoms occurring in association with the presenting problem.'),

('HC013','SYSTEMIC_SYMPTOM','Systemic symptom','associated',
 'General/systemic manifestations associated with the problem.'),

('HC014','FUNCTIONAL_IMPACT','Functional impact','function',
 'Effect of the problem on normal physical, occupational, educational, social or daily function.'),

('HC015','PREVIOUS_EPISODE','Previous episode','background',
 'Whether the problem has occurred previously.'),

('HC016','PREVIOUS_DIAGNOSIS','Previous diagnosis','background',
 'Previous clinical diagnosis relevant to the presenting problem.'),

('HC017','PREVIOUS_INVESTIGATION','Previous investigation','background',
 'Previous investigations relevant to the presenting problem.'),

('HC018','PREVIOUS_TREATMENT','Previous treatment','background',
 'Previous treatment received for the presenting problem.'),

('HC019','TREATMENT_RESPONSE','Treatment response','health_seeking',
 'Response to treatment already received.'),

('HC020','HEALTH_SEEKING','Health-seeking','health_seeking',
 'Previous consultation, self-treatment or other healthcare seeking.'),

('HC021','EXPOSURE','Exposure','exposure',
 'Relevant environmental, occupational, infectious, travel or other exposure.'),

('HC022','MEDICATION_USE','Medication use','medication',
 'Current, recent or relevant medication exposure.'),

('HC023','ALLERGY','Allergy','allergy',
 'Relevant allergy history, particularly medication allergy.'),

('HC024','FAMILY_HISTORY','Family history','family',
 'Relevant familial disease or predisposition.'),

('HC025','SOCIAL_CONTEXT','Social context','social',
 'Social circumstances relevant to the clinical presentation or care.'),

('HC026','PATIENT_IDEA','Patient idea','patient_perspective',
 'What the patient thinks may be happening.'),

('HC027','PATIENT_CONCERN','Patient concern','patient_perspective',
 'What particularly worries the patient.'),

('HC028','PATIENT_EXPECTATION','Patient expectation','patient_perspective',
 'What the patient expects from the encounter.'),

('HC029','PATIENT_GOAL','Patient goal','patient_perspective',
 'What the patient wants to achieve from care.'),

('HC030','SOURCE_OF_HISTORY','Source of history','source',
 'Who provides the history and relevant limitations.'),

('HC031','RELIABILITY','History reliability','source',
 'Reliability of the history or particular history dimension.'),

('HC032','SLEEP_IMPACT','Sleep impact','function',
 'Effect on sleep.'),

('HC033','WORK_IMPACT','Work impact','function',
 'Effect on occupation or work.'),

('HC034','ACTIVITY_IMPACT','Activity impact','function',
 'Effect on usual activity or exercise.'),

('HC035','ADL_IMPACT','Activities of daily living impact','function',
 'Effect on activities of daily living.'),

('HC036','NUTRITIONAL_IMPACT','Nutritional impact','function',
 'Effect on eating, drinking or nutritional intake.'),

('HC037','SOCIAL_IMPACT','Social impact','function',
 'Effect on social participation and relationships.'),

('HC038','HEALTHCARE_ACCESS','Healthcare access','social',
 'Access barriers affecting presentation or treatment.'),

('HC039','ADHERENCE','Treatment adherence','medication',
 'Adherence to prescribed or recommended treatment.'),

('HC040','SELF_MEDICATION','Self-medication','medication',
 'Medication taken without or before professional assessment.')

ON CONFLICT (history_concept_id) DO NOTHING;


-- ============================================================================
-- 36. FOUNDATIONAL PRIORITY RULES
-- ============================================================================
--
-- These are factors, not hardcoded CPU decisions.
--
-- ============================================================================

INSERT INTO knowledge.question_priority_rule
(
    rule_code,
    factor,
    effect,
    description
)
VALUES

('P001','presenting_concern',1000,
 'Questions directly characterizing the presenting concern.'),

('P002','mandatory_foundation',900,
 'Mandatory foundational history questions.'),

('P003','emergency_red_flag',1000,
 'Questions needed to identify potentially time-critical danger features.'),

('P004','safety_critical',950,
 'Questions whose answers may materially affect treatment safety.'),

('P005','chronology',700,
 'Questions establishing onset, duration and temporal progression.'),

('P006','diagnostic_discrimination',650,
 'Questions with high discriminatory value between plausible clinical possibilities.'),

('P007','context_specific',600,
 'Questions activated by age, sex, pregnancy, emergency or other context.'),

('P008','functional_impact',500,
 'Questions determining effect on function and daily life.'),

('P009','documentation_completeness',300,
 'Questions needed to complete clinically relevant documentation.'),

('P010','patient_goal',250,
 'Questions relevant to the patient''s goals and expectations.'),

('P011','previous_history',350,
 'Questions concerning previous episodes, diagnosis, investigation or treatment.'),

('P012','health_seeking',300,
 'Questions concerning prior healthcare contact and treatment response.')

ON CONFLICT (rule_code) DO NOTHING;


-- ============================================================================
-- 37. FOUNDATIONAL FUNCTIONAL DOMAINS
-- ============================================================================

INSERT INTO knowledge.functional_impact
(
    function_code,
    domain,
    label,
    description
)
VALUES

('WALKING_LIMITATION','mobility',
 'Walking limitation',
 'Effect on walking ability.'),

('EXERCISE_TOLERANCE','physical_activity',
 'Exercise tolerance',
 'Effect on usual exertion or exercise.'),

('OCCUPATIONAL_FUNCTION','occupation',
 'Occupational function',
 'Effect on ability to work or perform usual occupational duties.'),

('EDUCATIONAL_FUNCTION','education',
 'Educational function',
 'Effect on school, study or educational participation.'),

('EATING_IMPACT','nutrition',
 'Eating impact',
 'Effect on eating.'),

('DRINKING_IMPACT','nutrition',
 'Drinking impact',
 'Effect on oral fluid intake.'),

('SLEEP_DISRUPTION','sleep',
 'Sleep disruption',
 'Effect on sleep.'),

('SOCIAL_PARTICIPATION','social',
 'Social participation',
 'Effect on social interaction and participation.'),

('ADL_LIMITATION','adl',
 'Activities of daily living',
 'Effect on normal activities of daily living.'),

('SELF_CARE_LIMITATION','self_care',
 'Self-care limitation',
 'Effect on ability to care for oneself.'),

('COMMUNICATION_LIMITATION','communication',
 'Communication limitation',
 'Effect on communication.'),

('RECREATIONAL_LIMITATION','recreation',
 'Recreational limitation',
 'Effect on recreational activities.')

ON CONFLICT (function_code) DO NOTHING;


-- ============================================================================
-- 38. UNIVERSAL DOCUMENTATION GROUPS
-- ============================================================================

INSERT INTO knowledge.documentation_group
(
    group_code,
    label,
    sequence_no,
    description
)
VALUES

('presenting','Presenting complaint',10,
 'The presenting concern and immediate reason for consultation.'),

('chronology','Chronology',20,
 'Onset, duration and temporal progression.'),

('character','Character and characteristics',30,
 'Relevant characteristics of the presenting symptom.'),

('sputum','Sputum / product',40,
 'Productive features where clinically applicable.'),

('associated','Associated symptoms',50,
 'Relevant associated symptoms.'),

('systemic','Systemic symptoms',60,
 'Relevant systemic manifestations.'),

('ent_gi','ENT / gastrointestinal',70,
 'Relevant ENT or gastrointestinal associations.'),

('risk','Risk factors and exposures',80,
 'Relevant risk factors, exposures and predispositions.'),

('previous','Previous history of the problem',90,
 'Previous episodes, diagnoses, investigations and treatment.'),

('health_seeking','Health-seeking history',100,
 'Prior consultation, self-treatment, treatment and response.'),

('severity','Severity, progression and red flags',110,
 'Severity, deterioration and danger features.'),

('functional','Functional impact',120,
 'Effect on daily activities, work, sleep, eating and social function.'),

('examination','Examination',130,
 'Objective examination findings, documented separately from history.')

ON CONFLICT (group_code) DO NOTHING;


-- ============================================================================
-- 39. PERFORMANCE INDEXES FOR REAL-TIME HISTORY CPU
-- ============================================================================
--
-- The history engine will repeatedly ask:
--
--     What is active?
--     What has already been answered?
--     What remains unknown?
--     Which questions are triggered?
--     Which facts changed recently?
--
-- These indexes support those hot paths.
--
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_question_trigger_hotpath
    ON knowledge.question_trigger(
        trigger_type,
        trigger_code,
        priority DESC
    );

CREATE INDEX IF NOT EXISTS idx_question_requirement_hotpath
    ON knowledge.question_requirement(
        requirement_type,
        requirement_code
    );

CREATE INDEX IF NOT EXISTS idx_symptom_dimension_hotpath
    ON knowledge.symptom_history_dimension(
        symptom_id,
        applicable,
        priority
    );

CREATE INDEX IF NOT EXISTS idx_fact_relationship_hotpath
    ON clinical.fact_relationship(
        source_fact_id,
        relationship
    );

CREATE INDEX IF NOT EXISTS idx_event_hotpath
    ON clinical.clinical_event(
        patient_id,
        encounter_id,
        event_time
    );

CREATE INDEX IF NOT EXISTS idx_response_hotpath
    ON clinical.question_response(
        encounter_id,
        answered_at DESC
    );

CREATE INDEX IF NOT EXISTS idx_completeness_hotpath
    ON clinical.history_completeness(
        encounter_id,
        state,
        symptom_id
    );


-- ============================================================================
-- 40. PROVENANCE CONTRACT
-- ============================================================================

COMMENT ON TABLE knowledge.provenance IS
'Universal AMEXAN provenance graph. Every compiled history concept, question, fact, documentation structure and clinical knowledge object may be linked back to its atomic authoritative source claim.';


-- ============================================================================
-- 41. FINAL ARCHITECTURAL GUARANTEES
-- ============================================================================
--
-- This migration establishes the following universal path:
--
--     SOURCE CLAIM
--          |
--          v
--     HISTORY CONCEPT
--          |
--          +-----------------------------+
--          |                             |
--          v                             v
--     SYMPTOM DIMENSION             CONTEXT RULE
--          |                             |
--          +--------------+--------------+
--                         |
--                         v
--                  QUESTION CANDIDATE
--                         |
--                 +-------+-------+
--                 |               |
--                 v               v
--              TRIGGER        REQUIREMENT
--                 |               |
--                 +-------+-------+
--                         |
--                         v
--                    CPU RANKING
--                         |
--                         v
--                     UI RENDER
--                         |
--                         v
--                  QUESTION RESPONSE
--                         |
--               +---------+---------+
--               |                   |
--               v                   v
--             FACT              FACT SOURCE
--               |                   |
--               v                   v
--            TIMELINE          CONFIDENCE
--               |
--               v
--        FACT RELATIONSHIPS
--               |
--               v
--        CLINICAL STATE / CPU
--               |
--               v
--       DOCUMENTATION ENGINE
--
-- ============================================================================

COMMIT;
