-- =============================================================================
-- AMEXAN Medical Knowledge Compiler â€” H3
-- UNIVERSAL ADAPTIVE HISTORY / QUESTION / CLINICAL INTERVIEW ENGINE
-- =============================================================================
--
-- PURPOSE
-- -------
-- H3 answers:
--
--   "Given everything currently known about this patient, what should AMEXAN
--    ask next, why should it ask it, what clinical truth will the answer
--    establish, what differential will it change, what safety issue could it
--    uncover, and when is the history clinically complete?"
--
-- H1 = SOURCE / METHOD
-- H2 = UNIVERSAL HISTORY ONTOLOGY
-- H3 = ADAPTIVE QUESTION + RULE ENGINE
--
-- ARCHITECTURAL LAW
-- -----------------
-- PostgreSQL = KNOWLEDGE + CONFIGURATION + PROVENANCE
-- CPU        = DECISION / EXECUTION
-- UI         = RENDERING
--
-- The CPU MUST NOT contain:
--   - disease-specific question sequences
--   - hard-coded red-flag lists
--   - hard-coded question priorities
--   - hidden differential weights
--   - hard-coded completion criteria
--   - specialty-specific interview trees
--
-- The CPU DOES:
--   1. read the current PatientClinicalState
--   2. retrieve candidate questions
--   3. evaluate database rules
--   4. calculate priority
--   5. apply safety precedence
--   6. select the next question(s)
--   7. persist the answer as facts/events
--   8. recompute the state
--   9. repeat until clinically complete / terminated
--
-- UNIVERSAL CLINICAL LOOP
--
--   PRESENTATION
--       â†“
--   ACTIVE SYMPTOM / CONTEXT
--       â†“
--   REQUIRED FOUNDATION
--       â†“
--   SAFETY / RED FLAGS
--       â†“
--   CHARACTERIZATION
--       â†“
--   ASSOCIATED FEATURES
--       â†“
--   SYSTEMIC / ETIOLOGICAL / RISK EXPLORATION
--       â†“
--   DIFFERENTIAL DISCRIMINATION
--       â†“
--   FUNCTIONAL IMPACT
--       â†“
--   PREVIOUS EPISODES / TREATMENT
--       â†“
--   HEALTH SEEKING
--       â†“
--   PATIENT PERSPECTIVE
--       â†“
--   COMPLETION TEST
--       â†“
--   DOCUMENTATION ENGINE
--
-- The same architecture can therefore drive:
--
--   respiratory
--   cardiovascular
--   gastrointestinal
--   neurological
--   renal
--   endocrine
--   infectious disease
--   rheumatology
--   haematology
--   oncology
--   surgery
--   OBG
--   paediatrics
--   geriatrics
--   psychiatry
--   emergency medicine
--
-- without changing the CPU.
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. REQUIRED EXTENSIONS / SCHEMA ASSUMPTIONS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;
CREATE SCHEMA IF NOT EXISTS clinical;


-- =============================================================================
-- 1. QUESTION RULE
-- =============================================================================
--
-- A question rule is the fundamental adaptive-interview rule.
--
-- Example:
--
--   FEVER_PRESENT = TRUE
--        â†’
--   ACTIVATE FEVER_ONSET
--
--   CHEST_PAIN_PRESENT = TRUE
--        â†’
--   ACTIVATE CHEST_PAIN_CHARACTER
--
--   HAEMOPTYSIS = TRUE
--        â†’
--   ACTIVATE HAEMOPTYSIS_SEVERITY
--
--   PREGNANT = TRUE
--        â†’
--   ACTIVATE PREGNANCY_RELEVANT_HISTORY
--
-- A rule can activate or deactivate:
--   QUESTION
--   SYMPTOM
--   MODULE
--
-- The CPU never invents this relationship.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_rule (
    rule_id             text PRIMARY KEY,
    rule_name           text NOT NULL,

    trigger_type        text NOT NULL DEFAULT 'fact'
                        CHECK (
                            trigger_type IN (
                                'fact',
                                'context'
                            )
                        ),

    trigger_code        text NOT NULL,

    trigger_operator    text NOT NULL DEFAULT 'eq'
                        CHECK (
                            trigger_operator IN (
                                'eq',
                                'ne',
                                'gt',
                                'gte',
                                'lt',
                                'lte',
                                'in',
                                'not_in',
                                'exists',
                                'not_exists'
                            )
                        ),

    trigger_value       jsonb,

    action              text NOT NULL
                        CHECK (
                            action IN (
                                'ACTIVATE',
                                'DEACTIVATE'
                            )
                        ),

    target_type         text NOT NULL
                        CHECK (
                            target_type IN (
                                'question',
                                'symptom',
                                'module'
                            )
                        ),

    target_code         text NOT NULL,

    priority_delta      integer NOT NULL DEFAULT 0,

    rationale           text,

    context             jsonb,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    version             integer NOT NULL DEFAULT 1,

    status              text NOT NULL DEFAULT 'active'
                        CHECK (
                            status IN (
                                'active',
                                'draft',
                                'superseded',
                                'retired'
                            )
                        ),

    effective_from      timestamptz NOT NULL DEFAULT now(),
    effective_to        timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        trigger_type,
        trigger_code,
        trigger_operator,
        trigger_value,
        action,
        target_type,
        target_code,
        version
    ),

    CHECK (
        effective_to IS NULL
        OR effective_to >= effective_from
    )
);

COMMENT ON TABLE knowledge.question_rule IS
'Universal adaptive-history rule. A captured fact or patient context can activate/deactivate a question, symptom, or question module.';

COMMENT ON COLUMN knowledge.question_rule.trigger_value IS
'Machine-evaluable expected value. Scalar for ordinary comparisons; array for IN/NOT_IN.';

COMMENT ON COLUMN knowledge.question_rule.priority_delta IS
'Additional CPU ranking weight applied when this rule fires. Safety rules should use explicit safety requirements rather than relying only on this value.';

CREATE INDEX IF NOT EXISTS idx_question_rule_trigger
    ON knowledge.question_rule(trigger_type, trigger_code, status);

CREATE INDEX IF NOT EXISTS idx_question_rule_target
    ON knowledge.question_rule(target_type, target_code, status);

CREATE INDEX IF NOT EXISTS idx_question_rule_effective
    ON knowledge.question_rule(status, effective_from, effective_to);

DROP TRIGGER IF EXISTS trg_knowledge_question_rule_updated_at
    ON knowledge.question_rule;

CREATE TRIGGER trg_knowledge_question_rule_updated_at
    BEFORE UPDATE ON knowledge.question_rule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 2. COMPOUND QUESTION-RULE CONDITIONS
-- =============================================================================
--
-- A single trigger is useful but insufficient for a universal clinical system.
--
-- Real medicine often needs:
--
--   IF
--      CHEST_PAIN_PRESENT = TRUE
--      AND
--      AGE >= 18
--   THEN
--      ACTIVATE ADULT_CHEST_PAIN_RISK_QUESTIONS
--
-- Or:
--
--   IF
--      PREGNANT = TRUE
--      OR
--      POSTPARTUM = TRUE
--   THEN
--      ACTIVATE THROMBOEMBOLIC / OB-SPECIFIC QUESTIONS
--
-- The rule remains declarative.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_rule_condition (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_id             text NOT NULL
                        REFERENCES knowledge.question_rule(rule_id)
                        ON DELETE CASCADE,

    condition_group     integer NOT NULL DEFAULT 0,

    condition_type      text NOT NULL
                        CHECK (
                            condition_type IN (
                                'fact',
                                'context'
                            )
                        ),

    subject_code        text NOT NULL,

    operator            text NOT NULL DEFAULT 'eq'
                        CHECK (
                            operator IN (
                                'eq',
                                'ne',
                                'gt',
                                'gte',
                                'lt',
                                'lte',
                                'in',
                                'not_in',
                                'exists',
                                'not_exists'
                            )
                        ),

    expected_value      jsonb,

    logical_operator    text NOT NULL DEFAULT 'AND'
                        CHECK (
                            logical_operator IN (
                                'AND',
                                'OR'
                            )
                        ),

    sequence_no         integer NOT NULL DEFAULT 0,

    UNIQUE (
        rule_id,
        condition_group,
        sequence_no
    )
);

COMMENT ON TABLE knowledge.question_rule_condition IS
'Compound conditions for adaptive rules. Allows declarative AND/OR clinical eligibility without hard-coded CPU logic.';

CREATE INDEX IF NOT EXISTS idx_question_rule_condition_rule
    ON knowledge.question_rule_condition(rule_id);

CREATE INDEX IF NOT EXISTS idx_question_rule_condition_subject
    ON knowledge.question_rule_condition(condition_type, subject_code);


-- =============================================================================
-- 3. QUESTION MODULES
-- =============================================================================
--
-- Modules are reusable question banks.
--
-- Examples:
--
--   PRESENTING_CONCERN
--   COUGH_CORE
--   DYSPNOEA_CORE
--   CHEST_PAIN_CORE
--   FEVER_CORE
--   SPUTUM
--   HAEMOPTYSIS
--   TB_EXPOSURE
--   CARDIOVASCULAR_RISK
--   MEDICATION_HISTORY
--   ALLERGY_HISTORY
--   FUNCTIONAL_IMPACT
--   PATIENT_PERSPECTIVE
--
-- Modules are NOT disease entities.
-- They are reusable clinical interview components.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_module (
    module_code         text PRIMARY KEY,

    module_name         text NOT NULL,

    description         text,

    module_type         text NOT NULL DEFAULT 'history'
                        CHECK (
                            module_type IN (
                                'history',
                                'safety',
                                'red_flag',
                                'risk',
                                'functional',
                                'perspective',
                                'system_review',
                                'background',
                                'reproductive',
                                'medication',
                                'exposure',
                                'context',
                                'completion'
                            )
                        ),

    sort_order          integer NOT NULL DEFAULT 0,

    configurable        boolean NOT NULL DEFAULT true,

    status              text NOT NULL DEFAULT 'active'
                        CHECK (
                            status IN (
                                'active',
                                'draft',
                                'retired'
                            )
                        ),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.question_module IS
'Reusable clinical interview module. Modules group questions without embedding disease logic into the CPU or UI.';

DROP TRIGGER IF EXISTS trg_knowledge_question_module_updated_at
    ON knowledge.question_module;

CREATE TRIGGER trg_knowledge_question_module_updated_at
    BEFORE UPDATE ON knowledge.question_module
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE IF NOT EXISTS knowledge.question_module_member (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    module_code         text NOT NULL
                        REFERENCES knowledge.question_module(module_code)
                        ON DELETE CASCADE,

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    sort_order          integer NOT NULL DEFAULT 0,

    priority_override   integer NOT NULL DEFAULT 0,

    required_in_module  boolean NOT NULL DEFAULT false,

    UNIQUE (
        module_code,
        question_id
    )
);

CREATE INDEX IF NOT EXISTS idx_question_module_member_question
    ON knowledge.question_module_member(question_id);

CREATE INDEX IF NOT EXISTS idx_question_module_member_module_order
    ON knowledge.question_module_member(module_code, sort_order);


-- =============================================================================
-- 4. QUESTION DEPENDENCY
-- =============================================================================
--
-- Dependency is different from activation.
--
-- Activation:
--   "this question is relevant."
--
-- Dependency:
--   "this question should not be asked until prerequisite X is satisfied."
--
-- Example:
--
--   CHEST_PAIN_PRESENT
--          â†“
--   CHEST_PAIN_ONSET
--          â†“
--   CHEST_PAIN_CHARACTER
--          â†“
--   CHEST_PAIN_RADIATION
--
-- But red flags may remain non-blocking so that safety questions can jump
-- ahead of ordinary characterization.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_dependency CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_dependency (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    prerequisite_type   text NOT NULL
                        CHECK (
                            prerequisite_type IN (
                                'fact',
                                'question',
                                'context',
                                'module'
                            )
                        ),

    prerequisite_code   text NOT NULL,

    operator            text NOT NULL DEFAULT 'eq'
                        CHECK (
                            operator IN (
                                'eq',
                                'ne',
                                'gt',
                                'gte',
                                'lt',
                                'lte',
                                'in',
                                'not_in',
                                'exists',
                                'not_exists'
                            )
                        ),

    value               jsonb,

    is_blocking         boolean NOT NULL DEFAULT false,

    priority            integer NOT NULL DEFAULT 0,

    description         text,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (
        question_id,
        prerequisite_type,
        prerequisite_code,
        operator,
        value
    )
);

COMMENT ON TABLE knowledge.question_dependency IS
'Clinical ordering graph. Dependencies can block a question or simply raise its priority.';

CREATE INDEX IF NOT EXISTS idx_question_dependency_question
    ON knowledge.question_dependency(question_id);

CREATE INDEX IF NOT EXISTS idx_question_dependency_prerequisite
    ON knowledge.question_dependency(
        prerequisite_type,
        prerequisite_code
    );


-- =============================================================================
-- 5. QUESTION RATIONALE
-- =============================================================================
--
-- Every question must be explainable.
--
-- AMEXAN should be able to answer:
--
--   "Why did you ask this?"
--
-- Possible reasons:
--
--   clinical
--   safety
--   differential
--   documentation
--   context
--   functional
--   temporal
--   exposure
--   treatment
--   prognosis
--   educational
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_rationale (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    rationale_type      text NOT NULL
                        CHECK (
                            rationale_type IN (
                                'clinical',
                                'safety',
                                'differential',
                                'documentation',
                                'context',
                                'functional',
                                'temporal',
                                'exposure',
                                'treatment',
                                'prognosis',
                                'educational'
                            )
                        ),

    rationale            text NOT NULL,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    priority             integer NOT NULL DEFAULT 0,

    UNIQUE (
        question_id,
        rationale_type
    )
);

CREATE INDEX IF NOT EXISTS idx_question_rationale_question
    ON knowledge.question_rationale(question_id);


-- =============================================================================
-- 6. QUESTION DIFFERENTIAL WEIGHTS
-- =============================================================================
--
-- A question can alter consideration of a condition.
--
-- IMPORTANT:
-- This is NOT a diagnosis.
--
-- It is a transparent evidence-weighting mechanism.
--
-- Positive:
--   answer supports condition
--
-- Negative:
--   answer argues against condition
--
-- The CPU combines these with the rest of the clinical state.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_differential_weight (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    condition_id        uuid NOT NULL
                        REFERENCES knowledge.condition(id)
                        ON DELETE CASCADE,

    answer_value        text,

    weight              integer NOT NULL,

    weight_type         text NOT NULL DEFAULT 'diagnostic'
                        CHECK (
                            weight_type IN (
                                'diagnostic',
                                'safety',
                                'etiologic',
                                'severity',
                                'prognostic'
                            )
                        ),

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    rationale            text,

    UNIQUE (
        question_id,
        condition_id,
        answer_value,
        weight_type
    )
);

COMMENT ON TABLE knowledge.question_differential_weight IS
'Transparent clinical evidence weights linking question answers to diagnostic, safety, etiologic, severity or prognostic considerations.';

CREATE INDEX IF NOT EXISTS idx_question_diff_weight_question
    ON knowledge.question_differential_weight(question_id);

CREATE INDEX IF NOT EXISTS idx_question_diff_weight_condition
    ON knowledge.question_differential_weight(condition_id);


-- =============================================================================
-- 7. QUESTION â†’ FACT REQUIREMENT
-- =============================================================================
--
-- H2 already supports question â†’ fact acquisition through:
--
--   knowledge.question_fact
--
-- H3 explicitly documents WHY the fact matters.
--
-- This prevents a beautiful question from becoming clinically meaningless.
-- Every important question should acquire or resolve a known clinical fact.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_fact_requirement (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    fact_definition_code text NOT NULL
                         REFERENCES clinical.fact_definition(code),

    acquisition_role    text NOT NULL DEFAULT 'primary'
                        CHECK (
                            acquisition_role IN (
                                'primary',
                                'secondary',
                                'safety',
                                'differential',
                                'documentation',
                                'severity',
                                'functional',
                                'temporal',
                                'context'
                            )
                        ),

    required_for_completion boolean NOT NULL DEFAULT false,

    priority             integer NOT NULL DEFAULT 0,

    rationale            text,

    UNIQUE (
        question_id,
        fact_definition_code,
        acquisition_role
    )
);

COMMENT ON TABLE knowledge.question_fact_requirement IS
'Declares the clinical truth that a question is intended to acquire or resolve.';


CREATE INDEX IF NOT EXISTS idx_question_fact_requirement_question
    ON knowledge.question_fact_requirement(question_id);

CREATE INDEX IF NOT EXISTS idx_question_fact_requirement_fact
    ON knowledge.question_fact_requirement(fact_definition_code);


-- =============================================================================
-- 8. DOCUMENTATION REQUIREMENT
-- =============================================================================
--
-- Documentation is not an afterthought.
--
-- AMEXAN must distinguish:
--
--   ASKED
--   ANSWERED
--   UNKNOWN
--   NOT_ASKED
--   NOT_APPLICABLE
--
-- and determine which facts MUST appear in the final medical record.
--
-- Examples:
--
--   HPI:
--      onset
--      duration
--      progression
--      relevant associated symptoms
--
--   RED FLAGS:
--      haemoptysis
--      severe dyspnoea
--      altered consciousness
--
--   SAFETY:
--      allergy
--      pregnancy where relevant
--      renal/hepatic considerations where relevant
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.documentation_requirement (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    section_code        text NOT NULL,

    required_fact_code  text NOT NULL
                        REFERENCES clinical.fact_definition(code),

    condition           jsonb,

    priority            integer NOT NULL DEFAULT 0,

    requirement_level   text NOT NULL DEFAULT 'required'
                        CHECK (
                            requirement_level IN (
                                'required',
                                'high_priority',
                                'conditional',
                                'safety',
                                'optional'
                            )
                        ),

    is_required         boolean NOT NULL DEFAULT true,

    omission_action     text NOT NULL DEFAULT 'flag'
                        CHECK (
                            omission_action IN (
                                'flag',
                                'block_completion',
                                'warn',
                                'allow'
                            )
                        ),

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    rationale            text,

    UNIQUE (
        section_code,
        required_fact_code
    )
);

COMMENT ON TABLE knowledge.documentation_requirement IS
'Clinical documentation standard. Determines which clinical truths must be established or explicitly marked unknown before a presentation can be considered documented.';

CREATE INDEX IF NOT EXISTS idx_documentation_requirement_section
    ON knowledge.documentation_requirement(section_code);

CREATE INDEX IF NOT EXISTS idx_documentation_requirement_fact
    ON knowledge.documentation_requirement(required_fact_code);


-- =============================================================================
-- 9. DOCUMENTATION SECTION
-- =============================================================================
--
-- Gives the documentation engine a universal ordering language.
--
-- This directly supports your high-speed medical narrative engine.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.documentation_section CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.documentation_section (
    section_code       text PRIMARY KEY,

    section_name       text NOT NULL,

    narrative_order    integer NOT NULL,

    section_type       text NOT NULL DEFAULT 'clinical'
                       CHECK (
                           section_type IN (
                               'clinical',
                               'safety',
                               'context',
                               'documentation',
                               'assessment'
                           )
                       ),

    description        text,

    status             text NOT NULL DEFAULT 'active'
                       CHECK (
                           status IN (
                               'active',
                               'deprecated'
                           )
                       )
);

COMMENT ON TABLE knowledge.documentation_section IS
'Universal medical-documentation ordering vocabulary used by the DocumentationEngine.';


-- =============================================================================
-- 10. HISTORY COMPLETION RULE
-- =============================================================================
--
-- IMPORTANT:
--
-- A history is NOT complete because every question has been asked.
--
-- It is complete when the clinically discriminating information required for
-- the presentation has been established, resolved, or explicitly marked
-- unknown/not obtainable.
--
-- Example:
--
-- {
--   "and": [
--      {"fact": "COUGH_ONSET"},
--      {"fact": "COUGH_DURATION_DAYS"},
--      {
--         "or": [
--             {"fact": "COUGH_PRODUCTIVE", "value": "false"},
--             {"fact": "SPUTUM_PRESENT", "value": "true"}
--         ]
--      }
--   ]
-- }
--
-- The CPU evaluates the tree.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.history_completion_rule (
    rule_id             text PRIMARY KEY,

    subject_type        text NOT NULL
                        CHECK (
                            subject_type IN (
                                'symptom',
                                'presentation',
                                'encounter',
                                'module',
                                'condition'
                            )
                        ),

    subject_code        text NOT NULL,

    condition           jsonb NOT NULL,

    completion_policy   text NOT NULL DEFAULT 'clinical'
                        CHECK (
                            completion_policy IN (
                                'clinical',
                                'minimum_dataset',
                                'safety',
                                'discharge',
                                'referral'
                            )
                        ),

    description         text,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    version             integer NOT NULL DEFAULT 1,

    status              text NOT NULL DEFAULT 'active'
                        CHECK (
                            status IN (
                                'active',
                                'draft',
                                'superseded',
                                'retired'
                            )
                        ),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        subject_type,
        subject_code,
        version
    )
);

COMMENT ON TABLE knowledge.history_completion_rule IS
'Clinical completion criteria. AMEXAN stops when the clinically necessary information is established, not when the entire question bank is exhausted.';

CREATE INDEX IF NOT EXISTS idx_history_completion_subject
    ON knowledge.history_completion_rule(subject_type, subject_code, status);

DROP TRIGGER IF EXISTS trg_history_completion_rule_updated_at
    ON knowledge.history_completion_rule;

CREATE TRIGGER trg_history_completion_rule_updated_at
    BEFORE UPDATE ON knowledge.history_completion_rule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 11. QUESTION PRIORITY RULE
-- =============================================================================
--
-- The selector should not have magic numbers hidden in TypeScript.
--
-- These are reusable priority dimensions.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_priority_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_priority_rule (
    rule_code          text PRIMARY KEY,

    factor             text NOT NULL UNIQUE,

    effect             integer NOT NULL DEFAULT 0,

    precedence_class   integer NOT NULL DEFAULT 0,

    description        text,

    safety_override    boolean NOT NULL DEFAULT false,

    status             text NOT NULL DEFAULT 'active'
                       CHECK (
                           status IN (
                               'active',
                               'deprecated'
                           )
                       )
);

COMMENT ON TABLE knowledge.question_priority_rule IS
'Universal priority factors consumed by QuestionSelector. Safety overrides can force safety questions above ordinary completion ordering.';


-- =============================================================================
-- 12. QUESTION REQUIREMENT
-- =============================================================================
--
-- Preserve existing architecture while strengthening the requirement levels.
-- =============================================================================
--
-- [RECONCILED] Migration 026 authoritatively redefines knowledge.question_requirement
-- with requirement_type/requirement_code and its own CHECK constraint. The original
-- requirement_level column and its check no longer exist, so this ALTER is obsolete.
-- The active requirement vocabulary lives in Migration 026 (knowledge.question_requirement)
-- and Migration 027 (knowledge.question_context_requirement.requirement_level).


-- =============================================================================
-- 13. QUESTION SAFETY PROFILE
-- =============================================================================
--
-- A question may be clinically important specifically because failure to ask
-- it could allow a dangerous state to remain undiscovered.
--
-- Safety is therefore represented independently of ordinary priority.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_safety_profile (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    safety_domain       text NOT NULL
                        CHECK (
                            safety_domain IN (
                                'airway',
                                'breathing',
                                'circulation',
                                'neurological',
                                'sepsis',
                                'bleeding',
                                'pregnancy',
                                'allergy',
                                'medication',
                                'toxicology',
                                'trauma',
                                'infection',
                                'organ_failure',
                                'self_harm',
                                'safeguarding',
                                'other'
                            )
                        ),

    urgency             text NOT NULL DEFAULT 'urgent'
                        CHECK (
                            urgency IN (
                                'immediate',
                                'urgent',
                                'routine'
                            )
                        ),

    safety_weight       integer NOT NULL DEFAULT 0,

    rationale            text,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (
        question_id,
        safety_domain
    )
);

COMMENT ON TABLE knowledge.question_safety_profile IS
'Safety metadata for questions. Safety questions can outrank ordinary history sequencing.';


CREATE INDEX IF NOT EXISTS idx_question_safety_profile_question
    ON knowledge.question_safety_profile(question_id);

CREATE INDEX IF NOT EXISTS idx_question_safety_profile_domain
    ON knowledge.question_safety_profile(safety_domain);


-- =============================================================================
-- 14. QUESTION ACTIVATION / DEACTIVATION AUDIT SEMANTICS
-- =============================================================================
--
-- The CPU may evaluate many rules during a pass. We preserve the resulting
-- decision so the system can later explain:
--
--   "Why was this question active?"
--
-- This is runtime evidence rather than knowledge.
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_selection_event (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id)
                        ON DELETE SET NULL,

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    selected            boolean NOT NULL,

    rank                integer,

    calculated_priority numeric,

    selection_reason    jsonb,

    rule_ids            jsonb NOT NULL DEFAULT '[]'::jsonb,

    selected_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.question_selection_event IS
'Runtime audit of QuestionSelector decisions. Stores why a question was selected or not selected without moving execution logic into PostgreSQL.';

CREATE INDEX IF NOT EXISTS idx_question_selection_patient
    ON clinical.question_selection_event(patient_id, selected_at);

CREATE INDEX IF NOT EXISTS idx_question_selection_encounter
    ON clinical.question_selection_event(encounter_id, selected_at);

CREATE INDEX IF NOT EXISTS idx_question_selection_question
    ON clinical.question_selection_event(question_id, selected_at);


-- =============================================================================
-- 15. QUESTION ANSWER EVENT
-- =============================================================================
--
-- The answer itself is a clinical event.
--
-- The definitive clinical truth still enters the normal:
--
--     clinical.fact
--     clinical.fact_value
--
-- substrate.
--
-- This table records the interaction:
--
--     question asked
--     answer received
--     who answered
--     who recorded it
--     when
--     reliability
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.question_answer_event (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id)
                        ON DELETE SET NULL,

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE RESTRICT,

    answer_status       text NOT NULL
                        CHECK (
                            answer_status IN (
                                'answered',
                                'unknown',
                                'declined',
                                'not_obtainable',
                                'not_applicable'
                            )
                        ),

    answer_payload      jsonb,

    source_type         text NOT NULL DEFAULT 'patient'
                        CHECK (
                            source_type IN (
                                'patient',
                                'caregiver',
                                'clinician',
                                'record',
                                'interpreter',
                                'device',
                                'external'
                            )
                        ),

    reliability         text
                        CHECK (
                            reliability IN (
                                'reliable',
                                'partially_reliable',
                                'uncertain',
                                'unreliable'
                            )
                        ),

    recorded_by         uuid
                        REFERENCES identity.user_account(id),

    answered_at         timestamptz NOT NULL DEFAULT now(),

    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.question_answer_event IS
'Runtime interaction record. The normalized clinical truth is written into clinical.fact/fact_value; this table preserves how the answer was obtained.';

CREATE INDEX IF NOT EXISTS idx_question_answer_patient
    ON clinical.question_answer_event(patient_id, answered_at);

CREATE INDEX IF NOT EXISTS idx_question_answer_encounter
    ON clinical.question_answer_event(encounter_id, answered_at);

CREATE INDEX IF NOT EXISTS idx_question_answer_question
    ON clinical.question_answer_event(question_id, answered_at);


-- =============================================================================
-- 16. HISTORY SOURCE
-- =============================================================================
--
-- Universal history must distinguish:
--
--   patient report
--   caregiver report
--   previous record
--   clinician observation
--   interpreter-mediated report
--
-- This prevents the CPU from treating every statement as equally reliable.
-- =============================================================================

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
                                'caregiver',
                                'relative',
                                'clinician',
                                'previous_record',
                                'referral',
                                'interpreter',
                                'device',
                                'other'
                            )
                        ),

    source_name         text,

    relationship        text,

    reliability         text
                        CHECK (
                            reliability IN (
                                'reliable',
                                'partially_reliable',
                                'uncertain',
                                'unreliable'
                            )
                        ),

    note                text,

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
                        REFERENCES identity.user_account(id)
);

COMMENT ON TABLE clinical.history_source IS
'Identifies who or what supplied historical information and its reliability.';


CREATE INDEX IF NOT EXISTS idx_history_source_encounter
    ON clinical.history_source(encounter_id);


-- =============================================================================
-- 17. QUESTION REPEAT / DUPLICATION CONTROL
-- =============================================================================
--
-- AMEXAN must be fast.
--
-- It must never repeatedly ask:
--
--   "Do you have fever?"
--
-- after FEVER_PRESENT is already established.
--
-- The CPU uses this knowledge to determine whether a question may be repeated.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_repeat_policy (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    repeat_policy       text NOT NULL DEFAULT 'avoid_if_known'
                        CHECK (
                            repeat_policy IN (
                                'avoid_if_known',
                                'allow_if_changed',
                                'allow_if_stale',
                                'always_allow'
                            )
                        ),

    stale_after_minutes integer,

    repeat_reason       text,

    UNIQUE (question_id)
);

COMMENT ON TABLE knowledge.question_repeat_policy IS
'Controls repeated questioning. Prevents redundant interview loops while allowing reassessment when facts may have changed.';


-- =============================================================================
-- 18. QUESTION FRESHNESS
-- =============================================================================
--
-- A fact can be true when captured but no longer current.
--
-- This is especially important for:
--
--   pain
--   fever
--   dyspnoea
--   medication use
--   bleeding
--   pregnancy status
--   symptoms evolving during an encounter
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_freshness_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    freshness_minutes   integer NOT NULL,

    trigger_context     jsonb,

    rationale            text,

    UNIQUE (question_id, freshness_minutes)
);

COMMENT ON TABLE knowledge.question_freshness_rule IS
'Defines when previously acquired information should be considered stale enough to reassess.';


-- =============================================================================
-- 19. CONTEXT-SPECIFIC QUESTION REQUIREMENTS
-- =============================================================================
--
-- A question may be mandatory in one context and irrelevant in another.
--
-- Examples:
--
--   reproductive history
--   neonatal history
--   developmental history
--   occupational exposure
--   trauma mechanism
--   psychiatric safety
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_context_requirement (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    context_type_code   text
                        REFERENCES knowledge.context_type(code),

    context_value       text,

    requirement_level   text NOT NULL
                        CHECK (
                            requirement_level IN (
                                'mandatory',
                                'high_priority',
                                'conditional',
                                'optional',
                                'safety',
                                'excluded'
                            )
                        ),

    priority_delta      integer NOT NULL DEFAULT 0,

    rationale            text,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (
        question_id,
        context_type_code,
        context_value
    )
);

COMMENT ON TABLE knowledge.question_context_requirement IS
'Context-specific relevance of questions. The same universal question may have different priority or eligibility in different patient contexts.';


-- =============================================================================
-- 20. QUESTION NEGATIVE / EXCLUSION SEMANTICS
-- =============================================================================
--
-- Negative answers are clinical information.
--
-- "No haemoptysis" is NOT absence of documentation.
--
-- It becomes:
--
--   HAEMOPTYSIS = FALSE
--
-- This table makes explicit that a question may establish a negative fact.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_negative_semantic (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    fact_definition_code text NOT NULL
                         REFERENCES clinical.fact_definition(code),

    negative_value       text NOT NULL DEFAULT 'false',

    documentation_value text,

    differential_effect  integer NOT NULL DEFAULT 0,

    rationale            text,

    UNIQUE (
        question_id,
        fact_definition_code
    )
);

COMMENT ON TABLE knowledge.question_negative_semantic IS
'Explicit semantics for negative answers. Negative clinical findings remain first-class facts and can affect differential reasoning.';


-- =============================================================================
-- 21. QUESTION ANSWER CONSEQUENCE
-- =============================================================================
--
-- One answer may cause several things:
--
--   establish fact
--   activate another question
--   deactivate irrelevant question
--   activate red flag
--   raise a differential
--   require documentation
--   trigger reassessment
--
-- Most of these are represented through other tables, but this table provides
-- a clean declarative coordination layer for clinically significant effects.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_consequence (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id         uuid NOT NULL
                        REFERENCES knowledge.question(id)
                        ON DELETE CASCADE,

    answer_value        text,

    consequence_type    text NOT NULL
                        CHECK (
                            consequence_type IN (
                                'activate_question',
                                'deactivate_question',
                                'activate_module',
                                'activate_symptom',
                                'raise_safety',
                                'raise_differential',
                                'require_documentation',
                                'request_reassessment'
                            )
                        ),

    target_code         text,

    priority_delta      integer NOT NULL DEFAULT 0,

    rationale            text,

    evidence_claim_code text
                        REFERENCES knowledge.source_claim(claim_code)
);

COMMENT ON TABLE knowledge.question_consequence IS
'Declarative downstream consequences of answers. Used to coordinate adaptive interview behaviour without hard-coded disease trees.';

CREATE INDEX IF NOT EXISTS idx_question_consequence_question
    ON knowledge.question_consequence(question_id);

CREATE INDEX IF NOT EXISTS idx_question_consequence_target
    ON knowledge.question_consequence(consequence_type, target_code);


-- =============================================================================
-- 22. UNIVERSAL PRESENTATION STATE
-- =============================================================================
--
-- A presentation is not necessarily a diagnosis.
--
-- Examples:
--
--   cough
--   chest pain
--   fever
--   abdominal pain
--   headache
--   vomiting
--   weakness
--   jaundice
--
-- This lets the adaptive interview begin from what the patient actually
-- presents with.
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.presentation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id)
                        ON DELETE CASCADE,

    presentation_type   text NOT NULL
                        CHECK (
                            presentation_type IN (
                                'symptom',
                                'sign',
                                'finding',
                                'screening',
                                'follow_up',
                                'preventive',
                                'administrative'
                            )
                        ),

    presentation_code   text NOT NULL,

    primary_presentation boolean NOT NULL DEFAULT false,

    onset_at            timestamptz,

    status              text NOT NULL DEFAULT 'active'
                        CHECK (
                            status IN (
                                'active',
                                'resolved',
                                'uncertain',
                                'historical'
                            )
                        ),

    recorded_at         timestamptz NOT NULL DEFAULT now(),

    recorded_by         uuid
                        REFERENCES identity.user_account(id)
);

COMMENT ON TABLE clinical.presentation IS
'Patient-facing clinical presentation that starts an adaptive clinical interview without assuming a diagnosis.';

CREATE INDEX IF NOT EXISTS idx_clinical_presentation_patient
    ON clinical.presentation(patient_id, status);

CREATE INDEX IF NOT EXISTS idx_clinical_presentation_encounter
    ON clinical.presentation(encounter_id, status);


-- =============================================================================
-- 23. HISTORY ENGINE RUN
-- =============================================================================
--
-- Each adaptive interview is a resumable CPU process.
--
-- This gives AMEXAN:
--
--   start
--   pause
--   resume
--   complete
--   abandon
--   audit
--
-- without losing the clinical state.
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_engine_run (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id)
                        ON DELETE CASCADE,

    presentation_id     uuid
                        REFERENCES clinical.presentation(id)
                        ON DELETE SET NULL,

    engine_version      text NOT NULL,

    status              text NOT NULL DEFAULT 'active'
                        CHECK (
                            status IN (
                                'active',
                                'paused',
                                'completed',
                                'terminated',
                                'superseded'
                            )
                        ),

    current_stage       text,

    question_count      integer NOT NULL DEFAULT 0,

    answered_count      integer NOT NULL DEFAULT 0,

    safety_count        integer NOT NULL DEFAULT 0,

    started_at          timestamptz NOT NULL DEFAULT now(),

    completed_at        timestamptz,

    last_activity_at    timestamptz NOT NULL DEFAULT now(),

    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.history_engine_run IS
'Resumable adaptive-history execution state. The CPU can stop and resume without losing interview context.';

CREATE INDEX IF NOT EXISTS idx_history_engine_run_patient
    ON clinical.history_engine_run(patient_id, status);

CREATE INDEX IF NOT EXISTS idx_history_engine_run_encounter
    ON clinical.history_engine_run(encounter_id, status);


-- =============================================================================
-- 24. HISTORY COMPLETION RESULT
-- =============================================================================
--
-- The CPU should explain completion.
--
-- Example:
--
--   complete = TRUE
--
--   reasons:
--      - onset established
--      - duration established
--      - severity established
--      - major safety questions resolved
--      - required differential discriminators addressed
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical.history_completion_result (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    history_run_id      uuid NOT NULL
                        REFERENCES clinical.history_engine_run(id)
                        ON DELETE CASCADE,

    completion_rule_id  text
                        REFERENCES knowledge.history_completion_rule(rule_id),

    is_complete         boolean NOT NULL,

    completion_score    numeric(5,2),

    unresolved_items    jsonb NOT NULL DEFAULT '[]'::jsonb,

    satisfied_items     jsonb NOT NULL DEFAULT '[]'::jsonb,

    safety_unresolved   jsonb NOT NULL DEFAULT '[]'::jsonb,

    rationale            text,

    evaluated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE clinical.history_completion_result IS
'Explains why the adaptive history is or is not clinically complete.';


-- =============================================================================
-- 25. QUESTION PRIORITY DEFAULT SEED
-- =============================================================================
--
-- These are generic interview principles, not disease-specific rules.
--
-- SAFETY must dominate ordinary completeness.
-- =============================================================================

INSERT INTO knowledge.question_priority_rule
    (rule_code, factor, effect, precedence_class, description, safety_override)
VALUES
    (
        'P001',
        'safety',
        1000,
        100,
        'Safety and red-flag questions receive highest precedence.',
        true
    ),
    (
        'P002',
        'mandatory_foundation',
        800,
        90,
        'Required foundational history information is prioritized.',
        false
    ),
    (
        'P003',
        'high_priority',
        600,
        80,
        'High-priority clinical information is collected before optional detail.',
        false
    ),
    (
        'P004',
        'active_symptom',
        500,
        70,
        'Questions characterizing an active presenting symptom receive priority.',
        false
    ),
    (
        'P005',
        'differential_discrimination',
        450,
        65,
        'Questions capable of materially distinguishing active clinical considerations are prioritized.',
        false
    ),
    (
        'P006',
        'temporal',
        400,
        60,
        'Chronology and temporal relationships are prioritized because they organize the clinical story.',
        false
    ),
    (
        'P007',
        'documentation',
        350,
        50,
        'Required documentation facts are prioritized when not already established.',
        false
    ),
    (
        'P008',
        'functional',
        300,
        40,
        'Functional impact is explored where clinically relevant.',
        false
    ),
    (
        'P009',
        'context',
        250,
        30,
        'Context-specific questions are prioritized when activated.',
        false
    ),
    (
        'P010',
        'optional',
        100,
        10,
        'Optional enrichment questions receive lower priority.',
        false
    )
ON CONFLICT (rule_code) DO UPDATE SET
    factor = EXCLUDED.factor,
    effect = EXCLUDED.effect,
    precedence_class = EXCLUDED.precedence_class,
    description = EXCLUDED.description,
    safety_override = EXCLUDED.safety_override;


-- =============================================================================
-- 26. UNIVERSAL DOCUMENTATION ORDER
-- =============================================================================
--
-- This becomes the backbone for the high-speed DocumentationEngine.
--
-- The order is intentionally presentation-first and chronology-first.
-- =============================================================================

INSERT INTO knowledge.documentation_section
    (section_code, section_name, narrative_order, section_type, description)
VALUES
    (
        'PRESENTING',
        'Presenting complaint',
        10,
        'clinical',
        'What brought the patient for care.'
    ),
    (
        'CHRONOLOGY',
        'Chronology',
        20,
        'clinical',
        'Onset, sequence, duration and progression.'
    ),
    (
        'CHARACTER',
        'Symptom characteristics',
        30,
        'clinical',
        'Site, character, severity, radiation, triggers and relieving factors where applicable.'
    ),
    (
        'ASSOCIATED',
        'Associated symptoms',
        40,
        'clinical',
        'Symptoms that accompany or interact with the presenting problem.'
    ),
    (
        'SYSTEMIC',
        'Systemic features',
        50,
        'clinical',
        'Fever, constitutional features and other systemic manifestations when relevant.'
    ),
    (
        'RISK',
        'Risk factors and exposures',
        60,
        'clinical',
        'Relevant epidemiological, occupational, behavioural, environmental and host risk factors.'
    ),
    (
        'PREVIOUS',
        'Previous episodes and relevant history',
        70,
        'clinical',
        'Previous episodes, diagnoses, admissions, investigations and relevant treatment.'
    ),
    (
        'HEALTH_SEEKING',
        'Health-seeking and treatment already received',
        80,
        'clinical',
        'Prior consultation, medication, self-treatment, response and reason for current presentation.'
    ),
    (
        'SEVERITY',
        'Severity and complications',
        90,
        'safety',
        'Progression, functional severity and relevant danger signs/complications.'
    ),
    (
        'FUNCTIONAL',
        'Functional impact',
        100,
        'clinical',
        'Effect on activities of daily living, work, exercise, sleep, feeding and social function.'
    ),
    (
        'PERSPECTIVE',
        'Patient perspective',
        110,
        'clinical',
        'Ideas, concerns, expectations and goals.'
    ),
    (
        'EXAMINATION',
        'Examination',
        120,
        'clinical',
        'Relevant examination findings associated with the presentation.'
    )
ON CONFLICT (section_code) DO UPDATE SET
    section_name = EXCLUDED.section_name,
    narrative_order = EXCLUDED.narrative_order,
    section_type = EXCLUDED.section_type,
    description = EXCLUDED.description;


-- =============================================================================
-- 27. STANDARD UNIVERSAL MODULES
-- =============================================================================
--
-- These are architecture-level modules, not disease-specific engines.
-- =============================================================================

INSERT INTO knowledge.question_module
    (module_code, module_name, module_type, description, sort_order)
VALUES
    (
        'PRESENTING_CONCERN',
        'Presenting concern',
        'history',
        'Establishes what brought the patient for care and the primary concern.',
        10
    ),
    (
        'CHRONOLOGY',
        'Chronology',
        'history',
        'Establishes onset, duration, sequence and progression.',
        20
    ),
    (
        'CHARACTERIZATION',
        'Symptom characterization',
        'history',
        'Explores symptom dimensions appropriate to the active presentation.',
        30
    ),
    (
        'ASSOCIATED_FEATURES',
        'Associated features',
        'history',
        'Explores relevant associated symptoms and findings.',
        40
    ),
    (
        'SYSTEMIC_FEATURES',
        'Systemic features',
        'system_review',
        'Explores relevant constitutional and systemic manifestations.',
        50
    ),
    (
        'RED_FLAGS',
        'Safety and red flags',
        'red_flag',
        'Safety-critical questions activated by presentation and context.',
        60
    ),
    (
        'RISK_FACTORS',
        'Risk factors and exposures',
        'risk',
        'Explores relevant host, environmental, behavioural and exposure risks.',
        70
    ),
    (
        'PREVIOUS_HISTORY',
        'Previous episodes and relevant history',
        'background',
        'Previous episodes, diagnoses, admissions and relevant history.',
        80
    ),
    (
        'HEALTH_SEEKING',
        'Health-seeking and prior treatment',
        'medication',
        'Previous consultation, self-treatment, medications and response.',
        90
    ),
    (
        'FUNCTIONAL_IMPACT',
        'Functional impact',
        'functional',
        'Effect of illness on function and daily life.',
        100
    ),
    (
        'PATIENT_PERSPECTIVE',
        'Patient perspective',
        'perspective',
        'Ideas, concerns, expectations and goals.',
        110
    ),
    (
        'SAFETY_HISTORY',
        'Universal safety history',
        'safety',
        'Universal safety information such as allergy and other context-dependent safety factors.',
        120
    )
ON CONFLICT (module_code) DO UPDATE SET
    module_name = EXCLUDED.module_name,
    module_type = EXCLUDED.module_type,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order;


-- =============================================================================
-- 28. UNIVERSAL QUESTION RULE INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_question_dependency_blocking
    ON knowledge.question_dependency(question_id, is_blocking);

CREATE INDEX IF NOT EXISTS idx_question_context_requirement
    ON knowledge.question_context_requirement(
        question_id,
        context_type_code,
        requirement_level
    );

CREATE INDEX IF NOT EXISTS idx_question_fact_requirement_completion
    ON knowledge.question_fact_requirement(
        fact_definition_code,
        required_for_completion
    );

CREATE INDEX IF NOT EXISTS idx_question_consequence_answer
    ON knowledge.question_consequence(
        question_id,
        answer_value
    );


-- =============================================================================
-- 29. PROVENANCE
-- =============================================================================
--
-- H3 objects can be traced to H1 source claims.
-- =============================================================================

COMMENT ON TABLE knowledge.provenance IS
'AMEXAN derivation graph: authoritative source claims â†’ compiled history concepts â†’ questions â†’ rules â†’ rationales â†’ differential weights â†’ documentation requirements â†’ completion criteria.';


-- =============================================================================
-- 30. FINAL SAFETY INVARIANTS
-- =============================================================================
--
-- These constraints encode architectural laws rather than disease knowledge.
-- =============================================================================

DO $$
BEGIN

    -- Ensure the question table has the H2 history link.
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'knowledge'
          AND table_name = 'question'
    ) THEN

        ALTER TABLE knowledge.question
            ADD COLUMN IF NOT EXISTS history_concept_id text
            REFERENCES knowledge.history_concept(history_concept_id);

        ALTER TABLE knowledge.question
            ADD COLUMN IF NOT EXISTS question_mode text;

        -- Only add the constraint if the expected column exists and the
        -- constraint does not already exist.
        IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = 'question_question_mode_check'
        ) THEN
            ALTER TABLE knowledge.question
                ADD CONSTRAINT question_question_mode_check
                CHECK (
                    question_mode IS NULL
                    OR question_mode IN (
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
        END IF;

    END IF;

END $$;


-- =============================================================================
-- 31. ANALYZE / QUERY PERFORMANCE
-- =============================================================================
--
-- These tables are read constantly by the CPU.
-- Keep planner statistics current after large seed loads.
-- =============================================================================

ANALYZE knowledge.question_rule;
ANALYZE knowledge.question_rule_condition;
ANALYZE knowledge.question_module;
ANALYZE knowledge.question_module_member;
ANALYZE knowledge.question_dependency;
ANALYZE knowledge.question_rationale;
ANALYZE knowledge.question_differential_weight;
ANALYZE knowledge.question_fact_requirement;
ANALYZE knowledge.documentation_requirement;
ANALYZE knowledge.history_completion_rule;
ANALYZE knowledge.question_priority_rule;


COMMIT;


-- =============================================================================
-- END H3
-- =============================================================================
