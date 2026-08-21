-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 009: universal clinical rule engine
-- =============================================================================
-- Universal, composable, versioned, provenance-aware clinical reasoning substrate.
-- No disease-specific engine is hard-coded here.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.rule CASCADE;
CREATE TABLE knowledge.rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code             text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description           text,
    rule_type             text NOT NULL DEFAULT 'clinical'
                          CHECK (rule_type IN (
                              'clinical',
                              'activation',
                              'safety',
                              'differential',
                              'investigation',
                              'diagnostic',
                              'screening',
                              'management',
                              'prognostic',
                              'documentation',
                              'workflow',
                              'drug',
                              'interaction',
                              'triage',
                              'referral',
                              'follow_up'
                          )),
    status                text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','active','retired','superseded')),
    priority              integer NOT NULL DEFAULT 50,
    confidence_threshold  numeric(5,4),
    evidence_level        text,
    evidence_grade        text,
    guideline             text,
    guideline_version     text,
    effective_from        date,
    effective_to          date,
    author                text,
    reviewer              text,
    approval_status       text NOT NULL DEFAULT 'pending'
                          CHECK (approval_status IN ('pending','approved','rejected')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
    CHECK (confidence_threshold IS NULL OR confidence_threshold BETWEEN 0 AND 1)
);

COMMENT ON TABLE knowledge.rule IS
'Universal clinical rule. Rules compose primitive knowledge into reasoning, activation, safety, investigation, diagnosis, management, triage and documentation behavior.';

CREATE INDEX idx_rule_type_status
    ON knowledge.rule(rule_type, status);

CREATE INDEX idx_rule_effective
    ON knowledge.rule(effective_from, effective_to);

CREATE TRIGGER trg_knowledge_rule_updated_at
BEFORE UPDATE ON knowledge.rule
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- RULE VERSION
-- =============================================================================

CREATE TABLE knowledge.rule_version (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    version               integer NOT NULL,
    body                  jsonb NOT NULL,
    rationale             text,
    change_summary        text,
    is_active             boolean NOT NULL DEFAULT false,
    changed_at            timestamptz NOT NULL DEFAULT now(),
    changed_by            uuid REFERENCES identity.user_account(id),
    UNIQUE (rule_id, version)
);

COMMENT ON TABLE knowledge.rule_version IS
'Immutable machine-readable rule versions.';

CREATE INDEX idx_rule_version_rule
    ON knowledge.rule_version(rule_id);

CREATE UNIQUE INDEX uq_rule_active_version
    ON knowledge.rule_version(rule_id)
    WHERE is_active = true;


-- =============================================================================
-- RULE CONDITION
-- =============================================================================

CREATE TABLE knowledge.rule_condition (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    condition_group       integer NOT NULL DEFAULT 1,
    condition_order       integer NOT NULL DEFAULT 0,
    entity_type            text NOT NULL,
    entity_code            text NOT NULL,
    operator               text NOT NULL
                           CHECK (operator IN (
                               'eq',
                               'neq',
                               'gt',
                               'gte',
                               'lt',
                               'lte',
                               'in',
                               'not_in',
                               'contains',
                               'not_contains',
                               'exists',
                               'not_exists',
                               'between',
                               'matches',
                               'before',
                               'after',
                               'overlaps'
                           )),
    value                 jsonb,
    is_not                boolean NOT NULL DEFAULT false,
    negation_reason       text,
    created_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (rule_id, rule_version_id, condition_group, condition_order)
);

COMMENT ON TABLE knowledge.rule_condition IS
'Atomic predicates evaluated against facts, symptoms, measurements, concepts, context, observations and other universal clinical state.';

CREATE INDEX idx_rule_condition_rule
    ON knowledge.rule_condition(rule_id);

CREATE INDEX idx_rule_condition_entity
    ON knowledge.rule_condition(entity_type, entity_code);


-- =============================================================================
-- RULE CONDITION GROUP
-- =============================================================================

CREATE TABLE knowledge.rule_condition_group (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    group_number          integer NOT NULL,
    logical_operator      text NOT NULL DEFAULT 'AND'
                          CHECK (logical_operator IN ('AND','OR','XOR')),
    parent_group_id       uuid REFERENCES knowledge.rule_condition_group(id),
    description           text,
    UNIQUE (rule_id, rule_version_id, group_number)
);

COMMENT ON TABLE knowledge.rule_condition_group IS
'Nested logical structure for complex clinical rules.';


-- =============================================================================
-- RULE ACTION
-- =============================================================================

CREATE TABLE knowledge.rule_action (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    action_order          integer NOT NULL DEFAULT 0,
    action_type            text NOT NULL
                           CHECK (action_type IN (
                               'activate_question',
                               'deactivate_question',
                               'activate_phenotype',
                               'deactivate_phenotype',
                               'set_fact',
                               'clear_fact',
                               'raise_red_flag',
                               'clear_red_flag',
                               'recommend_investigation',
                               'suppress_investigation',
                               'recommend_management',
                               'suppress_management',
                               'recommend_medication',
                               'suppress_medication',
                               'recommend_referral',
                               'set_priority',
                               'set_urgency',
                               'set_confidence',
                               'generate_alert',
                               'generate_notification',
                               'create_task',
                               'advance_workflow',
                               'request_confirmation',
                               'request_supervision',
                               'generate_document',
                               'record_reason',
                               'record_provenance'
                           )),
    action_entity_type    text,
    action_code           text,
    action_concept_id     uuid REFERENCES knowledge.concept(id),
    params                jsonb,
    rationale              text,
    UNIQUE (rule_id, rule_version_id, action_order)
);

COMMENT ON TABLE knowledge.rule_action IS
'Deterministic consequences of a satisfied clinical rule.';


CREATE INDEX idx_rule_action_rule
    ON knowledge.rule_action(rule_id);

CREATE INDEX idx_rule_action_type
    ON knowledge.rule_action(action_type);


-- =============================================================================
-- RULE CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.rule_context CASCADE;
CREATE TABLE knowledge.rule_context (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    context_type_code     text NOT NULL REFERENCES knowledge.context_type(code),
    context_value_id      uuid REFERENCES knowledge.context_value(id),
    applicability         text NOT NULL DEFAULT 'applies'
                          CHECK (applicability IN ('applies','excludes','preferred','required')),
    weight                numeric(6,3) NOT NULL DEFAULT 1.0,
    UNIQUE (
        rule_id,
        rule_version_id,
        context_type_code,
        context_value_id,
        applicability
    )
);

COMMENT ON TABLE knowledge.rule_context IS
'Contextual applicability of a rule across age, sex, pregnancy, setting, acuity, geography, specialty and other dimensions.';


-- =============================================================================
-- CONTEXT RULE
-- =============================================================================

CREATE TABLE knowledge.context_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    context_type_code     text NOT NULL REFERENCES knowledge.context_type(code),
    context_value_id      uuid REFERENCES knowledge.context_value(id),
    applicability         text NOT NULL DEFAULT 'required'
                          CHECK (applicability IN ('required','optional','excluded','preferred')),
    weight                numeric(6,3) NOT NULL DEFAULT 1.0,
    description            text,
    UNIQUE (
        rule_id,
        context_type_code,
        context_value_id,
        applicability
    )
);

COMMENT ON TABLE knowledge.context_rule IS
'Explicit contextual constraints used by the universal reasoning engine.';


-- =============================================================================
-- RULE PRIORITY
-- =============================================================================

CREATE TABLE knowledge.rule_priority (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    priority_score        integer NOT NULL DEFAULT 0,
    basis                 text,
    description           text,
    context_type_code     text REFERENCES knowledge.context_type(code),
    context_value_id      uuid REFERENCES knowledge.context_value(id),
    UNIQUE (rule_id, context_type_code, context_value_id)
);

COMMENT ON TABLE knowledge.rule_priority IS
'Context-sensitive rule priority.';


CREATE INDEX idx_rule_priority_score
    ON knowledge.rule_priority(priority_score DESC);


-- =============================================================================
-- RULE SOURCE / EVIDENCE PROVENANCE
-- =============================================================================

CREATE TABLE knowledge.rule_source (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    source_type            text NOT NULL
                           CHECK (source_type IN (
                               'guideline',
                               'systematic_review',
                               'meta_analysis',
                               'randomized_trial',
                               'observational_study',
                               'textbook',
                               'monograph',
                               'consensus',
                               'expert',
                               'local_protocol',
                               'facility_protocol',
                               'regulatory',
                               'public_health',
                               'pharmacopoeia',
                               'other'
                           )),
    source_ref             text,
    citation               text,
    url                    text,
    title                  text,
    publisher               text,
    publication_date       date,
    evidence_level         text,
    evidence_grade         text,
    page_reference         text,
    excerpt                text,
    accessed_at            timestamptz,
    UNIQUE (rule_id, rule_version_id, source_type, source_ref)
);

COMMENT ON TABLE knowledge.rule_source IS
'Full provenance supporting a clinical rule and its specific version.';


CREATE INDEX idx_rule_source_rule
    ON knowledge.rule_source(rule_id);


-- =============================================================================
-- RULE RELATIONSHIPS
-- =============================================================================

CREATE TABLE knowledge.rule_relationship (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_rule_id        uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    target_rule_id        uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    relationship_type     text NOT NULL
                          CHECK (relationship_type IN (
                              'depends_on',
                              'refines',
                              'extends',
                              'overrides',
                              'conflicts_with',
                              'supports',
                              'precedes',
                              'follows',
                              'alternative_to',
                              'requires'
                          )),
    weight                numeric(6,3) NOT NULL DEFAULT 1.0,
    description           text,
    CHECK (source_rule_id <> target_rule_id),
    UNIQUE (source_rule_id, target_rule_id, relationship_type)
);

COMMENT ON TABLE knowledge.rule_relationship IS
'Graph relationships between reusable clinical rules.';


-- =============================================================================
-- RULE EXCEPTION
-- =============================================================================

CREATE TABLE knowledge.rule_exception (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    exception_code        text NOT NULL,
    description           text NOT NULL,
    condition             jsonb NOT NULL,
    action                text NOT NULL
                          CHECK (action IN (
                              'suppress',
                              'modify',
                              'replace',
                              'escalate',
                              'require_supervision'
                          )),
    replacement_rule_id   uuid REFERENCES knowledge.rule(id),
    priority              integer NOT NULL DEFAULT 0,
    is_active             boolean NOT NULL DEFAULT true,
    UNIQUE (rule_id, exception_code)
);

COMMENT ON TABLE knowledge.rule_exception IS
'Explicit exceptions preventing unsafe universal application of a rule.';


-- =============================================================================
-- RULE SAFETY
-- =============================================================================

CREATE TABLE knowledge.rule_safety (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    safety_type            text NOT NULL
                           CHECK (safety_type IN (
                               'contraindication',
                               'interaction',
                               'allergy',
                               'pregnancy',
                               'paediatric',
                               'geriatric',
                               'renal',
                               'hepatic',
                               'dose_limit',
                               'maximum_frequency',
                               'minimum_age',
                               'maximum_age',
                               'red_flag',
                               'requires_supervision',
                               'requires_confirmation'
                           )),
    condition             jsonb NOT NULL,
    severity              text NOT NULL DEFAULT 'warning'
                           CHECK (severity IN ('information','warning','high','critical')),
    message               text NOT NULL,
    action                text NOT NULL
                           CHECK (action IN (
                               'warn',
                               'block',
                               'require_confirmation',
                               'require_supervision',
                               'redirect'
                           )),
    UNIQUE (rule_id, safety_type, message)
);

COMMENT ON TABLE knowledge.rule_safety IS
'Safety constraints evaluated before a rule action is allowed to execute.';


-- =============================================================================
-- RULE TEST CASES
-- =============================================================================

CREATE TABLE knowledge.rule_test_case (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    name                  text NOT NULL,
    description           text,
    input_state           jsonb NOT NULL,
    expected_result       jsonb NOT NULL,
    expected_actions      jsonb,
    expected_questions    jsonb,
    expected_flags        jsonb,
    is_regression         boolean NOT NULL DEFAULT true,
    created_at             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_id, rule_version_id, name)
);

COMMENT ON TABLE knowledge.rule_test_case IS
'Executable clinical regression cases for rule validation.';


CREATE TABLE knowledge.rule_test_result (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    test_case_id          uuid NOT NULL REFERENCES knowledge.rule_test_case(id) ON DELETE CASCADE,
    executed_at           timestamptz NOT NULL DEFAULT now(),
    engine_version         text,
    passed                 boolean NOT NULL,
    actual_result          jsonb,
    actual_actions         jsonb,
    actual_questions       jsonb,
    actual_flags           jsonb,
    error                  text,
    execution_ms           integer
);

COMMENT ON TABLE knowledge.rule_test_result IS
'Historical execution results of rule regression tests.';


-- =============================================================================
-- RULE EXECUTION
-- =============================================================================

CREATE TABLE knowledge.rule_execution (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id),
    rule_version_id       uuid REFERENCES knowledge.rule_version(id),
    patient_id            uuid REFERENCES patient.patient(id),
    encounter_id          uuid REFERENCES encounter.encounter(id),
    workflow_instance_id  uuid REFERENCES workflow.instance(id),
    executed_at           timestamptz NOT NULL DEFAULT now(),
    execution_mode        text NOT NULL DEFAULT 'clinical'
                          CHECK (execution_mode IN (
                              'clinical',
                              'simulation',
                              'testing',
                              'audit'
                          )),
    matched               boolean NOT NULL,
    input_snapshot        jsonb,
    output_snapshot       jsonb,
    actions_emitted       jsonb,
    safety_results        jsonb,
    confidence             numeric(6,5),
    execution_ms           integer
);

COMMENT ON TABLE knowledge.rule_execution IS
'Trace of rule execution for clinical explainability, auditing and debugging.';


CREATE INDEX idx_rule_execution_patient
    ON knowledge.rule_execution(patient_id);

CREATE INDEX idx_rule_execution_encounter
    ON knowledge.rule_execution(encounter_id);

CREATE INDEX idx_rule_execution_rule
    ON knowledge.rule_execution(rule_id);

CREATE INDEX idx_rule_execution_time
    ON knowledge.rule_execution(executed_at);


-- =============================================================================
-- RULE EXPLANATION
-- =============================================================================

CREATE TABLE knowledge.rule_explanation (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    rule_version_id       uuid REFERENCES knowledge.rule_version(id) ON DELETE CASCADE,
    explanation_type      text NOT NULL
                          CHECK (explanation_type IN (
                              'why_question',
                              'why_flag',
                              'why_investigation',
                              'why_differential',
                              'why_management',
                              'why_referral',
                              'why_safety',
                              'why_priority'
                          )),
    explanation            text NOT NULL,
    language_code          text NOT NULL DEFAULT 'en',
    UNIQUE (rule_id, rule_version_id, explanation_type, language_code)
);

COMMENT ON TABLE knowledge.rule_explanation IS
'Human-readable explanations generated or curated for transparent clinical reasoning.';


-- =============================================================================
-- UNIVERSAL KNOWLEDGE LINK
-- =============================================================================

CREATE TABLE knowledge.rule_concept_link (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    concept_id            uuid NOT NULL REFERENCES knowledge.concept(id) ON DELETE CASCADE,
    role                  text NOT NULL
                          CHECK (role IN (
                              'trigger',
                              'condition',
                              'outcome',
                              'differential',
                              'investigation',
                              'management',
                              'safety',
                              'context',
                              'mechanism',
                              'phenotype',
                              'complication'
                          )),
    weight                numeric(6,3) NOT NULL DEFAULT 1.0,
    UNIQUE (rule_id, concept_id, role)
);

COMMENT ON TABLE knowledge.rule_concept_link IS
'Universal graph links connecting rules to the atomic clinical vocabulary.';


CREATE INDEX idx_rule_concept_link_concept
    ON knowledge.rule_concept_link(concept_id);


-- =============================================================================
-- RULE INPUT / OUTPUT CONTRACTS
-- =============================================================================

CREATE TABLE knowledge.rule_input (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    input_code            text NOT NULL,
    entity_type           text NOT NULL,
    entity_code           text NOT NULL,
    required              boolean NOT NULL DEFAULT false,
    default_value         jsonb,
    validation             jsonb,
    description            text,
    UNIQUE (rule_id, input_code)
);

COMMENT ON TABLE knowledge.rule_input IS
'Declared inputs required or accepted by a universal clinical rule.';


CREATE TABLE knowledge.rule_output (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    output_code            text NOT NULL,
    entity_type            text NOT NULL,
    entity_code            text NOT NULL,
    output_type            text NOT NULL,
    description            text,
    UNIQUE (rule_id, output_code)
);

COMMENT ON TABLE knowledge.rule_output IS
'Declared outputs emitted by a universal clinical rule.';


-- =============================================================================
-- RULE SET
-- =============================================================================

CREATE TABLE knowledge.rule_set (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_set_code         text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description           text,
    version               text,
    status                text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','active','retired')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.rule_set IS
'Reusable collections of rules forming clinical pathways without creating disease-specific engines.';

CREATE TRIGGER trg_rule_set_updated_at
BEFORE UPDATE ON knowledge.rule_set
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE knowledge.rule_set_member (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_set_id            uuid NOT NULL REFERENCES knowledge.rule_set(id) ON DELETE CASCADE,
    rule_id                uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    execution_order       integer NOT NULL DEFAULT 0,
    required              boolean NOT NULL DEFAULT false,
    UNIQUE (rule_set_id, rule_id)
);

COMMENT ON TABLE knowledge.rule_set_member IS
'Rules composing a reusable universal pathway or protocol.';


-- =============================================================================
-- RULE CONFLICT RESOLUTION
-- =============================================================================

CREATE TABLE knowledge.rule_conflict_policy (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_set_id            uuid REFERENCES knowledge.rule_set(id) ON DELETE CASCADE,
    conflict_type         text NOT NULL,
    resolution_strategy   text NOT NULL
                          CHECK (resolution_strategy IN (
                              'highest_priority',
                              'highest_evidence',
                              'most_specific',
                              'latest_effective',
                              'require_supervision',
                              'block'
                          )),
    description            text
);

COMMENT ON TABLE knowledge.rule_conflict_policy IS
'Deterministic conflict-resolution policy for competing clinical rules.';


-- =============================================================================
-- KNOWLEDGE PACK
-- =============================================================================

CREATE TABLE knowledge.knowledge_pack (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_code             text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description            text,
    specialty             text,
    source_type            text,
    source_version        text,
    jurisdiction           text,
    language_code          text NOT NULL DEFAULT 'en',
    version               text NOT NULL,
    status                 text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','validated','active','retired')),
    effective_from        date,
    effective_to          date,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.knowledge_pack IS
'A versioned package of clinical knowledge imported from textbooks, guidelines, protocols, formularies and validated local knowledge.';

CREATE TRIGGER trg_knowledge_pack_updated_at
BEFORE UPDATE ON knowledge.knowledge_pack
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE knowledge.knowledge_pack_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_pack_id     uuid NOT NULL REFERENCES knowledge.knowledge_pack(id) ON DELETE CASCADE,
    rule_id               uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    UNIQUE (knowledge_pack_id, rule_id)
);

COMMENT ON TABLE knowledge.knowledge_pack_rule IS
'Rules contributed by a knowledge pack.';


CREATE TABLE knowledge.knowledge_pack_concept (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_pack_id     uuid NOT NULL REFERENCES knowledge.knowledge_pack(id) ON DELETE CASCADE,
    concept_id            uuid NOT NULL REFERENCES knowledge.concept(id) ON DELETE CASCADE,
    UNIQUE (knowledge_pack_id, concept_id)
);

COMMENT ON TABLE knowledge.knowledge_pack_concept IS
'Concept vocabulary contributed by a knowledge pack.';


-- =============================================================================
-- KNOWLEDGE VALIDATION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.validation_run CASCADE;
CREATE TABLE knowledge.validation_run (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_pack_id     uuid REFERENCES knowledge.knowledge_pack(id),
    started_at            timestamptz NOT NULL DEFAULT now(),
    completed_at          timestamptz,
    validator_version     text,
    status                text NOT NULL DEFAULT 'running'
                          CHECK (status IN ('running','passed','failed','warning')),
    summary               jsonb,
    error                 text
);

COMMENT ON TABLE knowledge.validation_run IS
'Validation of imported medical knowledge before activation.';


CREATE TABLE knowledge.validation_issue (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    validation_run_id     uuid NOT NULL REFERENCES knowledge.validation_run(id) ON DELETE CASCADE,
    entity_type           text NOT NULL,
    entity_id             uuid,
    severity              text NOT NULL
                          CHECK (severity IN ('info','warning','error','critical')),
    issue_code             text NOT NULL,
    message                text NOT NULL,
    detail                 jsonb,
    resolved               boolean NOT NULL DEFAULT false,
    resolved_at            timestamptz,
    UNIQUE (validation_run_id, issue_code, entity_type, entity_id)
);

COMMENT ON TABLE knowledge.validation_issue IS
'Machine-detected problems in clinical knowledge before deployment.';


-- =============================================================================
-- CLINICAL REASONING TRACE
-- =============================================================================

CREATE TABLE knowledge.reasoning_trace (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id            uuid REFERENCES patient.patient(id),
    encounter_id          uuid REFERENCES encounter.encounter(id),
    rule_execution_id     uuid REFERENCES knowledge.rule_execution(id),
    trace_type             text NOT NULL
                          CHECK (trace_type IN (
                              'observation',
                              'inference',
                              'differential',
                              'question_selection',
                              'investigation_selection',
                              'management_selection',
                              'safety_check',
                              'explanation'
                          )),
    sequence_no            integer NOT NULL,
    source_entity_type     text,
    source_entity_id       uuid,
    derived_entity_type    text,
    derived_entity_id      uuid,
    confidence             numeric(6,5),
    rationale              text,
    evidence               jsonb,
    created_at             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_execution_id, sequence_no)
);

COMMENT ON TABLE knowledge.reasoning_trace IS
'Structured trace of clinical inference and action selection.';

CREATE INDEX idx_reasoning_trace_encounter
    ON knowledge.reasoning_trace(encounter_id);

CREATE INDEX idx_reasoning_trace_patient
    ON knowledge.reasoning_trace(patient_id);


-- =============================================================================
-- KNOWLEDGE ACTIVATION
-- =============================================================================

CREATE TABLE knowledge.activation (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_pack_id     uuid REFERENCES knowledge.knowledge_pack(id),
    rule_id               uuid REFERENCES knowledge.rule(id),
    rule_version_id       uuid REFERENCES knowledge.rule_version(id),
    context_type_code     text REFERENCES knowledge.context_type(code),
    context_value_id      uuid REFERENCES knowledge.context_value(id),
    activated_at          timestamptz NOT NULL DEFAULT now(),
    activated_by          uuid REFERENCES identity.user_account(id),
    status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','disabled','expired')),
    UNIQUE (
        knowledge_pack_id,
        rule_id,
        rule_version_id,
        context_type_code,
        context_value_id
    )
);

COMMENT ON TABLE knowledge.activation IS
'Explicit activation state of validated clinical knowledge.';


-- =============================================================================
-- UNIVERSAL CLINICAL PROVENANCE
-- =============================================================================

CREATE TABLE knowledge.provenance (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type           text NOT NULL,
    entity_id             uuid NOT NULL,
    source_type           text NOT NULL,
    source_ref            text,
    source_title          text,
    source_version        text,
    author                text,
    reviewer              text,
    evidence_level        text,
    evidence_grade        text,
    imported_at           timestamptz NOT NULL DEFAULT now(),
    imported_by           uuid REFERENCES identity.user_account(id),
    notes                 text
);

COMMENT ON TABLE knowledge.provenance IS
'Universal provenance layer for concepts, symptoms, rules, protocols, mappings and other knowledge objects.';

CREATE INDEX idx_knowledge_provenance_entity
    ON knowledge.provenance(entity_type, entity_id);


-- =============================================================================
-- KNOWLEDGE CHANGE HISTORY
-- =============================================================================

CREATE TABLE knowledge.change_history (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    change_type            text NOT NULL
                           CHECK (change_type IN (
                               'created',
                               'updated',
                               'deprecated',
                               'activated',
                               'deactivated',
                               'superseded',
                               'validated',
                               'rejected'
                           )),
    version                text,
    changed_at             timestamptz NOT NULL DEFAULT now(),
    changed_by             uuid REFERENCES identity.user_account(id),
    before_state           jsonb,
    after_state            jsonb,
    reason                 text
);

COMMENT ON TABLE knowledge.change_history IS
'Immutable history of medical knowledge lifecycle changes.';

CREATE INDEX idx_knowledge_change_history_entity
    ON knowledge.change_history(entity_type, entity_id);

CREATE INDEX idx_knowledge_change_history_time
    ON knowledge.change_history(changed_at);
