-- =============================================================================
-- AMEXAN Phase 2 — Migration 017: UNIVERSAL PROTOCOL / CARE-PATHWAY ENGINE
-- =============================================================================
-- Clinical Operating System principle:
--
--   KNOWLEDGE
--      ↓
--   PROTOCOL
--      ↓
--   ELIGIBILITY → ASSESSMENT → SAFETY → DIAGNOSIS → ACTION
--      ↓                                      ↓
--   INVESTIGATION / MEDICATION / MONITORING / EDUCATION
--      ↓
--   RESPONSE → ESCALATION → DISPOSITION → FOLLOW-UP
--
-- Protocols are orchestration objects, NOT disease-specific knowledge stores.
--
-- A protocol coordinates reusable universal primitives:
--
--   concepts
--   symptoms
--   questions
--   facts
--   rules
--   phenotypes
--   mechanisms
--   conditions
--   investigations
--   medications
--   monitoring
--   education
--
-- A protocol must therefore be:
--
--   • versioned
--   • context-aware
--   • executable
--   • auditable
--   • interruptible by safety rules
--   • capable of branching
--   • capable of escalation
--   • capable of reassessment
--   • capable of facility/local override
--   • capable of explaining WHY every action occurred
--
-- The protocol engine NEVER embeds an isolated "pneumonia engine",
-- "diabetes engine", etc.
--
-- Disease-specific behaviour emerges from composition of universal knowledge.
-- =============================================================================


-- =============================================================================
-- 1. PROTOCOL — CARE-PATHWAY ROOT
-- =============================================================================

CREATE TABLE knowledge.protocol (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id               uuid REFERENCES knowledge.concept(id),

   protocol_code             text NOT NULL UNIQUE,
   canonical_name            text NOT NULL,
   version_label             text,

   description               text,

   specialty_code            text
                              REFERENCES organization.specialty(code),

   purpose                   text NOT NULL DEFAULT 'management'
                              CHECK (
                                 purpose IN (
                                    'screening',
                                    'triage',
                                    'initial_assessment',
                                    'diagnostic',
                                    'management',
                                    'escalation',
                                    'monitoring',
                                    'discharge',
                                    'follow_up',
                                    'preventive',
                                    'rehabilitation',
                                    'emergency',
                                    'comprehensive'
                                 )
                              ),

   protocol_type             text NOT NULL DEFAULT 'clinical'
                              CHECK (
                                 protocol_type IN (
                                    'clinical',
                                    'diagnostic',
                                    'therapeutic',
                                    'emergency',
                                    'screening',
                                    'preventive',
                                    'monitoring',
                                    'discharge',
                                    'follow_up',
                                    'order_set',
                                    'care_pathway'
                                 )
                              ),

   status                    text NOT NULL DEFAULT 'draft'
                              CHECK (
                                 status IN (
                                    'draft',
                                    'approved',
                                    'active',
                                    'superseded',
                                    'retired'
                                 )
                              ),

   is_guideline              boolean NOT NULL DEFAULT false,

   configurable              boolean NOT NULL DEFAULT true,

   executable                boolean NOT NULL DEFAULT true,

   requires_clinician_review boolean NOT NULL DEFAULT true,

   source_reference          text,

   evidence_level            text,

   effective_from            timestamptz,

   effective_to              timestamptz,

   created_at                timestamptz NOT NULL DEFAULT now(),
   updated_at                timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.protocol IS
'Universal executable clinical care pathway. Coordinates reusable medical knowledge without duplicating disease-specific intelligence.';


CREATE INDEX idx_knowledge_protocol_concept
   ON knowledge.protocol(concept_id);

CREATE INDEX idx_knowledge_protocol_specialty
   ON knowledge.protocol(specialty_code);

CREATE INDEX idx_knowledge_protocol_status
   ON knowledge.protocol(status);

CREATE INDEX idx_knowledge_protocol_purpose
   ON knowledge.protocol(purpose);


CREATE TRIGGER trg_knowledge_protocol_updated_at
   BEFORE UPDATE ON knowledge.protocol
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 2. PROTOCOL VERSION
-- =============================================================================
-- Immutable execution versions allow historical encounters to retain exactly
-- which pathway was executed.

CREATE TABLE knowledge.protocol_version (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   version_number           integer NOT NULL,

   version_label            text,

   definition               jsonb,

   status                   text NOT NULL DEFAULT 'draft'
                              CHECK (
                                 status IN (
                                    'draft',
                                    'review',
                                    'approved',
                                    'active',
                                    'superseded',
                                    'retired'
                                 )
                              ),

   effective_from           timestamptz,

   effective_to             timestamptz,

   change_summary           text,

   change_reason            text,

   created_by               text,
   approved_by              text,
   approved_at              timestamptz,

   created_at               timestamptz NOT NULL DEFAULT now(),

   UNIQUE (protocol_id, version_number)
);

COMMENT ON TABLE knowledge.protocol_version IS
'Immutable/versioned executable definition of a protocol. Historical clinical execution must remain reproducible.';

CREATE INDEX idx_protocol_version_protocol
   ON knowledge.protocol_version(protocol_id);

CREATE INDEX idx_protocol_version_status
   ON knowledge.protocol_version(status);


-- =============================================================================
-- 3. PROTOCOL → CONDITION
-- =============================================================================

CREATE TABLE knowledge.protocol_condition (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   condition_id             uuid NOT NULL
                              REFERENCES knowledge.condition(id)
                              ON DELETE CASCADE,

   relationship_type        text NOT NULL DEFAULT 'addresses'
                              CHECK (
                                 relationship_type IN (
                                    'primary',
                                    'addresses',
                                    'diagnostic_for',
                                    'management_of',
                                    'prevention_of',
                                    'monitoring_of',
                                    'follow_up_of',
                                    'escalation_of',
                                    'discharge_for'
                                 )
                              ),

   priority                 numeric(5,2) NOT NULL DEFAULT 1.0,

   is_primary               boolean NOT NULL DEFAULT true,

   UNIQUE (
      protocol_id,
      condition_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.protocol_condition IS
'Conditions to which a protocol is relevant. Conditions remain universal knowledge nodes.';


CREATE INDEX idx_protocol_condition_condition
   ON knowledge.protocol_condition(condition_id);

CREATE INDEX idx_protocol_condition_protocol
   ON knowledge.protocol_condition(protocol_id);


-- =============================================================================
-- 4. PROTOCOL CONTEXT
-- =============================================================================
-- Makes one protocol universally reusable across age, sex, pregnancy,
-- acuity, setting, geography, specialty, comorbidity, etc.

CREATE TABLE knowledge.protocol_context (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   context_type_code        text NOT NULL
                              REFERENCES knowledge.context_type(code),

   context_value_id         uuid
                              REFERENCES knowledge.context_value(id),

   applicability             text NOT NULL DEFAULT 'applies'
                              CHECK (
                                 applicability IN (
                                    'required',
                                    'applies',
                                    'preferred',
                                    'optional',
                                    'excluded'
                                 )
                              ),

   priority                 integer NOT NULL DEFAULT 0,

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   description              text,

   UNIQUE (
      protocol_id,
      context_type_code,
      context_value_id,
      applicability
   )
);

COMMENT ON TABLE knowledge.protocol_context IS
'Context gating for protocols: age, sex, pregnancy, acuity, care setting, geography, specialty, comorbidity and other universal dimensions.';

CREATE INDEX idx_protocol_context_lookup
   ON knowledge.protocol_context(
      context_type_code,
      context_value_id
   );


-- =============================================================================
-- 5. PROTOCOL ENTRY / EXIT CRITERIA
-- =============================================================================

CREATE TABLE knowledge.protocol_criterion (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   criterion_code           text NOT NULL,

   criterion_type           text NOT NULL
                              CHECK (
                                 criterion_type IN (
                                    'eligibility',
                                    'inclusion',
                                    'exclusion',
                                    'safety',
                                    'completion',
                                    'failure',
                                    'escalation',
                                    'disposition'
                                 )
                              ),

   entity_type              text NOT NULL,
   entity_code              text NOT NULL,

   operator                 text NOT NULL DEFAULT 'exists',

   value                    jsonb,

   severity                 text
                              CHECK (
                                 severity IS NULL OR
                                 severity IN (
                                    'information',
                                    'warning',
                                    'urgent',
                                    'emergency'
                                 )
                              ),

   action                   text
                              CHECK (
                                 action IS NULL OR
                                 action IN (
                                    'continue',
                                    'stop',
                                    'branch',
                                    'escalate',
                                    'refer',
                                    'admit',
                                    'discharge'
                                 )
                              ),

   rationale                text,

   UNIQUE (
      protocol_id,
      criterion_code
   )
);

COMMENT ON TABLE knowledge.protocol_criterion IS
'Universal protocol gates defining eligibility, exclusion, safety interruption, completion, failure and disposition.';


CREATE INDEX idx_protocol_criterion_protocol
   ON knowledge.protocol_criterion(protocol_id);

CREATE INDEX idx_protocol_criterion_entity
   ON knowledge.protocol_criterion(entity_type, entity_code);


-- =============================================================================
-- 6. PROTOCOL STEP
-- =============================================================================

CREATE TABLE knowledge.protocol_step (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   protocol_version_id      uuid
                              REFERENCES knowledge.protocol_version(id)
                              ON DELETE CASCADE,

   parent_step_id           uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   step_code                text NOT NULL,

   step_label               text NOT NULL,

   step_type                text NOT NULL
                              CHECK (
                                 step_type IN (
                                    'entry',
                                    'eligibility',
                                    'triage',
                                    'assessment',
                                    'history',
                                    'examination',
                                    'red_flag',
                                    'question',
                                    'investigation',
                                    'interpretation',
                                    'diagnosis',
                                    'risk_stratification',
                                    'treatment',
                                    'medication',
                                    'procedure',
                                    'monitoring',
                                    'reassessment',
                                    'escalation',
                                    'consultation',
                                    'referral',
                                    'disposition',
                                    'education',
                                    'discharge',
                                    'follow_up',
                                    'exit'
                                 )
                              ),

   sequence_no              integer NOT NULL DEFAULT 0,

   instruction              text NOT NULL,

   rationale                text,

   required                 boolean NOT NULL DEFAULT false,

   interruptible            boolean NOT NULL DEFAULT true,

   allows_parallel_actions  boolean NOT NULL DEFAULT false,

   decision_rule            jsonb,

   completion_rule          jsonb,

   failure_rule             jsonb,

   status                   text NOT NULL DEFAULT 'active'
                              CHECK (
                                 status IN (
                                    'draft',
                                    'active',
                                    'deprecated'
                                 )
                              ),

   UNIQUE (
      protocol_id,
      step_code
   )
);

COMMENT ON TABLE knowledge.protocol_step IS
'Executable node in a care pathway. A protocol is a directed clinical workflow rather than a static list.';

CREATE INDEX idx_protocol_step_execution
   ON knowledge.protocol_step(
      protocol_id,
      sequence_no
   );

CREATE INDEX idx_protocol_step_parent
   ON knowledge.protocol_step(parent_step_id);

CREATE INDEX idx_protocol_step_type
   ON knowledge.protocol_step(protocol_id, step_type);


-- =============================================================================
-- 7. PROTOCOL STEP CONTEXT
-- =============================================================================

CREATE TABLE knowledge.protocol_step_context (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   step_id                  uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   context_type_code        text NOT NULL
                              REFERENCES knowledge.context_type(code),

   context_value_id         uuid
                              REFERENCES knowledge.context_value(id),

   applicability             text NOT NULL DEFAULT 'applies'
                              CHECK (
                                 applicability IN (
                                    'required',
                                    'applies',
                                    'preferred',
                                    'excluded'
                                 )
                              ),

   priority                 integer NOT NULL DEFAULT 0,

   UNIQUE (
      step_id,
      context_type_code,
      context_value_id,
      applicability
   )
);

COMMENT ON TABLE knowledge.protocol_step_context IS
'Fine-grained context gating for individual pathway steps.';


-- =============================================================================
-- 8. PROTOCOL STEP RULES
-- =============================================================================
-- Connects executable steps to the universal rule engine.

CREATE TABLE knowledge.protocol_step_rule (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   step_id                  uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   rule_id                  uuid NOT NULL
                              REFERENCES knowledge.rule(id)
                              ON DELETE CASCADE,

   execution_role           text NOT NULL DEFAULT 'gate'
                              CHECK (
                                 execution_role IN (
                                    'gate',
                                    'activation',
                                    'safety',
                                    'decision',
                                    'interpretation',
                                    'escalation',
                                    'completion'
                                 )
                              ),

   priority                 integer NOT NULL DEFAULT 0,

   stop_on_match            boolean NOT NULL DEFAULT false,

   UNIQUE (
      step_id,
      rule_id,
      execution_role
   )
);

COMMENT ON TABLE knowledge.protocol_step_rule IS
'Associates protocol steps with universal machine-evaluable clinical rules.';


CREATE INDEX idx_protocol_step_rule_rule
   ON knowledge.protocol_step_rule(rule_id);


-- =============================================================================
-- 9. PROTOCOL ACTION
-- =============================================================================

CREATE TABLE knowledge.protocol_action (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   action_type              text NOT NULL
                              CHECK (
                                 action_type IN (
                                    'ask_question',
                                    'examine',
                                    'investigate',
                                    'interpret',
                                    'diagnose',
                                    'phenotype',
                                    'medicate',
                                    'procedure',
                                    'monitor',
                                    'reassess',
                                    'educate',
                                    'refer',
                                    'consult',
                                    'admit',
                                    'transfer',
                                    'discharge',
                                    'follow_up',
                                    'alert',
                                    'notify',
                                    'order_set',
                                    'documentation'
                                 )
                              ),

   target_type              text,

   action_code              text NOT NULL,

   action_name              text NOT NULL,

   target_id                uuid,

   detail                   text,

   parameters               jsonb NOT NULL DEFAULT '{}'::jsonb,

   condition_expression     jsonb,

   urgency                  text NOT NULL DEFAULT 'routine'
                              CHECK (
                                 urgency IN (
                                    'immediate',
                                    'emergency',
                                    'urgent',
                                    'routine',
                                    'scheduled'
                                 )
                              ),

   required                 boolean NOT NULL DEFAULT false,

   clinician_confirmation   boolean NOT NULL DEFAULT false,

   sort_order               integer NOT NULL DEFAULT 0,

   UNIQUE (
      step_id,
      action_type,
      action_code
   )
);

COMMENT ON TABLE knowledge.protocol_action IS
'Executable clinical action emitted by a protocol step. Actions reference universal knowledge primitives rather than embedding disease-specific medicine.';

CREATE INDEX idx_protocol_action_step
   ON knowledge.protocol_action(step_id);

CREATE INDEX idx_protocol_action_code
   ON knowledge.protocol_action(action_type, action_code);


-- =============================================================================
-- 10. PROTOCOL ACTION TARGETS
-- =============================================================================
-- Explicit typed references improve execution speed and eliminate repeated
-- string resolution in the clinical CPU.

CREATE TABLE knowledge.protocol_action_investigation (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   action_id                uuid NOT NULL
                              REFERENCES knowledge.protocol_action(id)
                              ON DELETE CASCADE,

   investigation_id         uuid NOT NULL
                              REFERENCES knowledge.investigation(id)
                              ON DELETE CASCADE,

   indication               text,

   timing                   text,

   repeatable               boolean NOT NULL DEFAULT false,

   UNIQUE (action_id, investigation_id)
);

CREATE TABLE knowledge.protocol_action_medication (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   action_id                uuid NOT NULL
                              REFERENCES knowledge.protocol_action(id)
                              ON DELETE CASCADE,

   medication_id            uuid NOT NULL
                              REFERENCES knowledge.medication(id)
                              ON DELETE CASCADE,

   dose_reference_id        uuid
                              REFERENCES knowledge.drug_dose_reference(id),

   route                    text,

   dose_expression          text,

   frequency_expression    text,

   duration_expression     text,

   maximum_expression      text,

   indication               text,

   verification_required   boolean NOT NULL DEFAULT true,

   UNIQUE (action_id, medication_id)
);

CREATE TABLE knowledge.protocol_action_monitoring (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   action_id                uuid NOT NULL
                              REFERENCES knowledge.protocol_action(id)
                              ON DELETE CASCADE,

   monitoring_id            uuid NOT NULL
                              REFERENCES knowledge.monitoring(id)
                              ON DELETE CASCADE,

   frequency                text,

   duration                 text,

   target_expression        jsonb,

   deterioration_rule       jsonb,

   escalation_rule          jsonb,

   UNIQUE (action_id, monitoring_id)
);

CREATE TABLE knowledge.protocol_action_education (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   action_id                uuid NOT NULL
                              REFERENCES knowledge.protocol_action(id)
                              ON DELETE CASCADE,

   education_id             uuid NOT NULL
                              REFERENCES knowledge.education(id)
                              ON DELETE CASCADE,

   delivery_mode            text
                              CHECK (
                                 delivery_mode IS NULL OR
                                 delivery_mode IN (
                                    'verbal',
                                    'written',
                                    'digital',
                                    'teach_back'
                                 )
                              ),

   required                 boolean NOT NULL DEFAULT false,

   UNIQUE (action_id, education_id)
);


-- =============================================================================
-- 11. PROTOCOL QUESTIONS
-- =============================================================================
-- Questions are sourced from the universal question engine.

CREATE TABLE knowledge.protocol_question (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   step_id                  uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   question_id              uuid NOT NULL
                              REFERENCES knowledge.question(id)
                              ON DELETE CASCADE,

   requirement_level        text NOT NULL DEFAULT 'optional'
                              CHECK (
                                 requirement_level IN (
                                    'mandatory',
                                    'conditionally_required',
                                    'optional',
                                    'informational'
                                 )
                              ),

   activation_rule          jsonb,

   repeatable               boolean NOT NULL DEFAULT false,

   sort_order               integer NOT NULL DEFAULT 0,

   UNIQUE (step_id, question_id)
);

COMMENT ON TABLE knowledge.protocol_question IS
'Protocol-specific orchestration of reusable clinical questions. Question content remains in the universal question engine.';


-- =============================================================================
-- 12. PROTOCOL EXAMINATION
-- =============================================================================

CREATE TABLE knowledge.protocol_examination (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   step_id                  uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   examination_module_id    uuid NOT NULL
                              REFERENCES knowledge.examination_module(id)
                              ON DELETE CASCADE,

   requirement_level        text NOT NULL DEFAULT 'optional'
                              CHECK (
                                 requirement_level IN (
                                    'mandatory',
                                    'conditional',
                                    'optional'
                                 )
                              ),

   activation_rule          jsonb,

   sort_order               integer NOT NULL DEFAULT 0,

   UNIQUE (step_id, examination_module_id)
);

COMMENT ON TABLE knowledge.protocol_examination IS
'Protocol orchestration of reusable structured physical examination modules.';


-- =============================================================================
-- 13. PROTOCOL INVESTIGATION
-- =============================================================================
-- Explicit orchestration layer for investigations.

CREATE TABLE knowledge.protocol_investigation (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   step_id                  uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   investigation_id         uuid NOT NULL
                              REFERENCES knowledge.investigation(id)
                              ON DELETE CASCADE,

   indication               text,

   timing                   text,

   priority                 integer NOT NULL DEFAULT 0,

   required                 boolean NOT NULL DEFAULT false,

   repeatable               boolean NOT NULL DEFAULT false,

   interpretation_rule      jsonb,

   abnormal_action_rule     jsonb,

   UNIQUE (step_id, investigation_id)
);

COMMENT ON TABLE knowledge.protocol_investigation IS
'Protocol-level investigation orchestration. The investigation definition remains universal.';


-- =============================================================================
-- 14. PROTOCOL MONITORING
-- =============================================================================

CREATE TABLE knowledge.protocol_monitoring (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   monitoring_id            uuid NOT NULL
                              REFERENCES knowledge.monitoring(id)
                              ON DELETE CASCADE,

   start_condition          jsonb,

   frequency                text,

   duration                 text,

   target_expression        jsonb,

   normal_response_rule     jsonb,

   deterioration_rule       jsonb,

   escalation_instruction   text,

   reassessment_required    boolean NOT NULL DEFAULT true,

   UNIQUE (
      protocol_id,
      step_id,
      monitoring_id
   )
);

COMMENT ON TABLE knowledge.protocol_monitoring IS
'Closed-loop monitoring: baseline → measurement → trend → deviation → alert → reassessment → escalation.';


CREATE INDEX idx_protocol_monitoring_monitoring
   ON knowledge.protocol_monitoring(monitoring_id);


-- =============================================================================
-- 15. PROTOCOL BRANCHES
-- =============================================================================
-- Converts protocols from linear checklists into executable clinical pathways.

CREATE TABLE knowledge.protocol_branch (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   from_step_id             uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   to_step_id               uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   branch_code              text NOT NULL,

   condition_expression     jsonb,

   branch_type              text NOT NULL DEFAULT 'conditional'
                              CHECK (
                                 branch_type IN (
                                    'sequential',
                                    'conditional',
                                    'positive',
                                    'negative',
                                    'safety',
                                    'escalation',
                                    'failure',
                                    'success',
                                    'parallel',
                                    'repeat',
                                    'exit'
                                 )
                              ),

   priority                 integer NOT NULL DEFAULT 0,

   label                    text,

   rationale                text,

   UNIQUE (
      protocol_id,
      from_step_id,
      to_step_id,
      branch_code
   )
);

COMMENT ON TABLE knowledge.protocol_branch IS
'Directed edges between protocol steps. Enables conditional branching, escalation, repetition, parallel actions and exits.';


CREATE INDEX idx_protocol_branch_from
   ON knowledge.protocol_branch(from_step_id);

CREATE INDEX idx_protocol_branch_to
   ON knowledge.protocol_branch(to_step_id);


-- =============================================================================
-- 16. PROTOCOL ESCALATION
-- =============================================================================

CREATE TABLE knowledge.protocol_escalation (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   escalation_code          text NOT NULL,

   trigger_expression       jsonb NOT NULL,

   severity                 text NOT NULL
                              CHECK (
                                 severity IN (
                                    'warning',
                                    'urgent',
                                    'emergency',
                                    'critical'
                                 )
                              ),

   action_type              text NOT NULL
                              CHECK (
                                 action_type IN (
                                    'reassess',
                                    'notify_clinician',
                                    'senior_review',
                                    'consult_specialist',
                                    'transfer',
                                    'admit',
                                    'resuscitate',
                                    'activate_emergency_response',
                                    'stop_protocol'
                                 )
                              ),

   action_instruction       text NOT NULL,

   target_specialty_code    text
                              REFERENCES organization.specialty(code),

   response_time_minutes    integer,

   rationale                text,

   UNIQUE (
      protocol_id,
      escalation_code
   )
);

COMMENT ON TABLE knowledge.protocol_escalation IS
'Safety escalation layer for deterioration, red flags, treatment failure and protocol failure.';


-- =============================================================================
-- 17. PROTOCOL DISPOSITION
-- =============================================================================

CREATE TABLE knowledge.protocol_disposition (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   disposition_code         text NOT NULL,

   disposition_type         text NOT NULL
                              CHECK (
                                 disposition_type IN (
                                    'discharge',
                                    'admit',
                                    'observation',
                                    'transfer',
                                    'referral',
                                    'icu',
                                    'theatre',
                                    'home_monitoring',
                                    'follow_up'
                                 )
                              ),

   eligibility_expression   jsonb NOT NULL,

   instructions             text,

   follow_up_required       boolean NOT NULL DEFAULT false,

   follow_up_interval       text,

   UNIQUE (
      protocol_id,
      disposition_code
   )
);

COMMENT ON TABLE knowledge.protocol_disposition IS
'Machine-evaluable disposition outcomes produced by protocol completion or escalation.';


-- =============================================================================
-- 18. PROTOCOL FOLLOW-UP
-- =============================================================================

CREATE TABLE knowledge.protocol_follow_up (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   follow_up_code            text NOT NULL,

   timing_expression         text NOT NULL,

   purpose                   text,

   required_assessment       jsonb,

   monitoring_requirements  jsonb,

   repeat_investigations     jsonb,

   treatment_review          jsonb,

   escalation_rule           jsonb,

   education_requirements   jsonb,

   UNIQUE (
      protocol_id,
      follow_up_code
   )
);

COMMENT ON TABLE knowledge.protocol_follow_up IS
'Post-encounter clinical loop: review → reassessment → monitoring → treatment adjustment → escalation or closure.';


-- =============================================================================
-- 19. PROTOCOL SAFETY
-- =============================================================================
-- Safety rules must be independently visible from ordinary actions.

CREATE TABLE knowledge.protocol_safety_rule (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   rule_id                  uuid
                              REFERENCES knowledge.rule(id)
                              ON DELETE CASCADE,

   safety_code              text NOT NULL,

   trigger_expression       jsonb NOT NULL,

   severity                 text NOT NULL
                              CHECK (
                                 severity IN (
                                    'warning',
                                    'urgent',
                                    'emergency',
                                    'critical'
                                 )
                              ),

   blocking                 boolean NOT NULL DEFAULT true,

   action_instruction       text NOT NULL,

   rationale                text,

   UNIQUE (
      protocol_id,
      safety_code
   )
);

COMMENT ON TABLE knowledge.protocol_safety_rule IS
'Independent safety barrier capable of interrupting ordinary protocol execution.';


-- =============================================================================
-- 20. PROTOCOL DEPENDENCIES
-- =============================================================================
-- Protocols may compose other universal protocols without duplicating them.

CREATE TABLE knowledge.protocol_dependency (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   dependency_protocol_id   uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   dependency_type          text NOT NULL
                              CHECK (
                                 dependency_type IN (
                                    'requires',
                                    'invokes',
                                    'optional',
                                    'fallback',
                                    'escalation',
                                    'follow_up'
                                 )
                              ),

   activation_rule          jsonb,

   priority                 integer NOT NULL DEFAULT 0,

   UNIQUE (
      protocol_id,
      dependency_protocol_id,
      dependency_type
   ),

   CHECK (protocol_id <> dependency_protocol_id)
);

COMMENT ON TABLE knowledge.protocol_dependency IS
'Composable protocols. Complex care pathways invoke smaller universal pathways rather than duplicating them.';


-- =============================================================================
-- 21. PROTOCOL EVIDENCE / PROVENANCE
-- =============================================================================

CREATE TABLE knowledge.protocol_source (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   source_type              text NOT NULL
                              CHECK (
                                 source_type IN (
                                    'guideline',
                                    'systematic_review',
                                    'trial',
                                    'textbook',
                                    'consensus',
                                    'expert',
                                    'national_guideline',
                                    'local_policy',
                                    'facility_policy',
                                    'regulatory'
                                 )
                              ),

   source_reference         text NOT NULL,

   citation                 text,

   url                      text,

   evidence_level           text,

   publication_date         date,

   accessed_at              timestamptz,

   notes                    text,

   UNIQUE (
      protocol_id,
      source_type,
      source_reference
   )
);

COMMENT ON TABLE knowledge.protocol_source IS
'Full provenance for protocol construction and clinical governance.';


CREATE INDEX idx_protocol_source_protocol
   ON knowledge.protocol_source(protocol_id);


-- =============================================================================
-- 22. PROTOCOL CHANGE HISTORY
-- =============================================================================

CREATE TABLE knowledge.protocol_change (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   version_id               uuid
                              REFERENCES knowledge.protocol_version(id)
                              ON DELETE CASCADE,

   change_type              text NOT NULL
                              CHECK (
                                 change_type IN (
                                    'created',
                                    'modified',
                                    'approved',
                                    'activated',
                                    'superseded',
                                    'retired',
                                    'local_override'
                                 )
                              ),

   changed_by               text,

   change_reason            text,

   previous_definition      jsonb,

   new_definition           jsonb,

   changed_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.protocol_change IS
'Governance audit trail for every protocol lifecycle transition.';


-- =============================================================================
-- 23. PROTOCOL PRIORITY
-- =============================================================================

CREATE TABLE knowledge.protocol_priority (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   context_type_code        text
                              REFERENCES knowledge.context_type(code),

   context_value_id         uuid
                              REFERENCES knowledge.context_value(id),

   priority_score           numeric(8,3) NOT NULL DEFAULT 0,

   basis                    text,

   rationale                text,

   UNIQUE (
      protocol_id,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.protocol_priority IS
'Context-sensitive protocol selection priority for the clinical CPU.';


-- =============================================================================
-- 24. PROTOCOL DOCUMENTATION
-- =============================================================================
-- What the system should automatically document when protocol actions occur.

CREATE TABLE knowledge.protocol_documentation (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   documentation_code       text NOT NULL,

   documentation_type       text NOT NULL
                              CHECK (
                                 documentation_type IN (
                                    'history',
                                    'examination',
                                    'assessment',
                                    'diagnosis',
                                    'investigation',
                                    'treatment',
                                    'monitoring',
                                    'escalation',
                                    'disposition',
                                    'education',
                                    'follow_up'
                                 )
                              ),

   template                 text NOT NULL,

   required_facts           jsonb,

   conditional_expression   jsonb,

   UNIQUE (
      protocol_id,
      documentation_code
   )
);

COMMENT ON TABLE knowledge.protocol_documentation IS
'Structured clinical documentation generated from protocol facts and actions rather than free-text duplication.';


-- =============================================================================
-- 25. PROTOCOL EDUCATION
-- =============================================================================

CREATE TABLE knowledge.protocol_education (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   step_id                  uuid
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   education_id             uuid NOT NULL
                              REFERENCES knowledge.education(id)
                              ON DELETE CASCADE,

   activation_rule          jsonb,

   required                 boolean NOT NULL DEFAULT false,

   teach_back_required      boolean NOT NULL DEFAULT false,

   UNIQUE (
      protocol_id,
      step_id,
      education_id
   )
);

COMMENT ON TABLE knowledge.protocol_education IS
'Protocol-specific delivery of reusable education and teach-back content.';


-- =============================================================================
-- 26. PROTOCOL MONITORING TRANSITIONS
-- =============================================================================
-- Allows monitoring to drive the pathway.

CREATE TABLE knowledge.protocol_monitoring_transition (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   monitoring_id            uuid NOT NULL
                              REFERENCES knowledge.monitoring(id)
                              ON DELETE CASCADE,

   from_step_id             uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   to_step_id               uuid NOT NULL
                              REFERENCES knowledge.protocol_step(id)
                              ON DELETE CASCADE,

   trigger_expression       jsonb NOT NULL,

   transition_type          text NOT NULL
                              CHECK (
                                 transition_type IN (
                                    'continue',
                                    'repeat',
                                    'reassess',
                                    'escalate',
                                    'stop',
                                    'discharge',
                                    'transfer'
                                 )
                              ),

   priority                 integer NOT NULL DEFAULT 0,

   UNIQUE (
      protocol_id,
      monitoring_id,
      from_step_id,
      to_step_id
   )
);

COMMENT ON TABLE knowledge.protocol_monitoring_transition IS
'Connects physiological deterioration or improvement directly to pathway transitions.';


-- =============================================================================
-- 27. PROTOCOL RULE → ACTION TRACEABILITY
-- =============================================================================
-- Every executable recommendation can expose why it exists.

CREATE TABLE knowledge.protocol_action_rule (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   action_id                uuid NOT NULL
                              REFERENCES knowledge.protocol_action(id)
                              ON DELETE CASCADE,

   rule_id                  uuid NOT NULL
                              REFERENCES knowledge.rule(id)
                              ON DELETE CASCADE,

   relationship_type        text NOT NULL
                              CHECK (
                                 relationship_type IN (
                                    'activated_by',
                                    'required_by',
                                    'supported_by',
                                    'blocked_by',
                                    'escalated_by',
                                    'completed_by'
                                 )
                              ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   UNIQUE (
      action_id,
      rule_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.protocol_action_rule IS
'Clinical explainability edge: action ← rule.';


-- =============================================================================
-- 28. PROTOCOL → UNIVERSAL KNOWLEDGE GRAPH
-- =============================================================================
-- Generalized graph edges allow protocol nodes to participate in the same
-- knowledge graph as concepts, symptoms, phenotypes, mechanisms and conditions.

CREATE TABLE knowledge.protocol_relationship (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   protocol_id              uuid NOT NULL
                              REFERENCES knowledge.protocol(id)
                              ON DELETE CASCADE,

   target_type              text NOT NULL,

   target_id                uuid NOT NULL,

   relationship_type        text NOT NULL
                              CHECK (
                                 relationship_type IN (
                                    'uses',
                                    'requires',
                                    'activates',
                                    'supports',
                                    'contradicts',
                                    'investigates',
                                    'treats',
                                    'monitors',
                                    'educates',
                                    'escalates',
                                    'follows',
                                    'depends_on',
                                    'supersedes',
                                    'alternative_to'
                                 )
                              ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   context                  jsonb,

   confidence               numeric(4,3)
                              CHECK (
                                 confidence IS NULL OR
                                 confidence BETWEEN 0 AND 1
                              ),

   evidence                 text,

   is_active                boolean NOT NULL DEFAULT true,

   created_at               timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      protocol_id,
      target_type,
      target_id,
      relationship_type,
      context
   )
);

COMMENT ON TABLE knowledge.protocol_relationship IS
'Protocol-specific graph edges connecting care pathways to the universal AMEXAN clinical knowledge graph.';


CREATE INDEX idx_protocol_relationship_protocol
   ON knowledge.protocol_relationship(protocol_id);

CREATE INDEX idx_protocol_relationship_target
   ON knowledge.protocol_relationship(target_type, target_id);

CREATE INDEX idx_protocol_relationship_type
   ON knowledge.protocol_relationship(relationship_type);


-- =============================================================================
-- 29. EXECUTION OPTIMIZATION INDEXES
-- =============================================================================

CREATE INDEX idx_protocol_active_execution
   ON knowledge.protocol(status, executable, effective_from, effective_to);

CREATE INDEX idx_protocol_condition_lookup
   ON knowledge.protocol_condition(condition_id, protocol_id);

CREATE INDEX idx_protocol_step_execution_fast
   ON knowledge.protocol_step(
      protocol_id,
      status,
      sequence_no
   );

CREATE INDEX idx_protocol_action_execution_fast
   ON knowledge.protocol_action(
      step_id,
      required,
      urgency,
      sort_order
   );

CREATE INDEX idx_protocol_safety_execution
   ON knowledge.protocol_safety_rule(
      protocol_id,
      blocking,
      severity
   );

CREATE INDEX idx_protocol_escalation_execution
   ON knowledge.protocol_escalation(
      protocol_id,
      severity,
      action_type
   );


-- =============================================================================
-- 30. CURRENT ACTIVE PROTOCOL VERSION
-- =============================================================================

CREATE VIEW knowledge.active_protocol_version AS
SELECT
   pv.id,
   pv.protocol_id,
   pv.version_number,
   pv.version_label,
   pv.definition,
   pv.effective_from,
   pv.effective_to,
   pv.approved_by,
   pv.approved_at
FROM knowledge.protocol_version pv
JOIN knowledge.protocol p
  ON p.id = pv.protocol_id
WHERE
   p.status = 'active'
   AND pv.status = 'active'
   AND (
      pv.effective_from IS NULL
      OR pv.effective_from <= now()
   )
   AND (
      pv.effective_to IS NULL
      OR pv.effective_to >= now()
   );


COMMENT ON VIEW knowledge.active_protocol_version IS
'Current executable version of each active AMEXAN protocol.';


-- =============================================================================
-- 31. PROTOCOL EXECUTION MAP
-- =============================================================================
-- Compact read model for the clinical CPU.
-- One row represents one executable protocol step.

CREATE VIEW knowledge.protocol_execution_map AS
SELECT
   p.id                         AS protocol_id,
   p.protocol_code,
   p.canonical_name,
   p.status                     AS protocol_status,

   s.id                         AS step_id,
   s.step_code,
   s.step_label,
   s.step_type,
   s.sequence_no,
   s.required,
   s.interruptible,
   s.decision_rule,
   s.completion_rule,
   s.failure_rule,

   a.id                         AS action_id,
   a.action_type,
   a.target_type,
   a.action_code,
   a.target_id,
   a.action_name,
   a.detail,
   a.parameters,
   a.condition_expression,
   a.urgency,
   a.required                    AS action_required,
   a.clinician_confirmation,
   a.sort_order

FROM knowledge.protocol p
JOIN knowledge.protocol_step s
  ON s.protocol_id = p.id
LEFT JOIN knowledge.protocol_action a
  ON a.step_id = s.id

WHERE
   p.status = 'active'
   AND s.status = 'active';


COMMENT ON VIEW knowledge.protocol_execution_map IS
'Optimized clinical CPU read model: active protocol → ordered executable steps → actions.';


-- =============================================================================
-- 32. PROTOCOL SAFETY MAP
-- =============================================================================

CREATE VIEW knowledge.protocol_safety_map AS
SELECT
   p.protocol_code,
   p.canonical_name,
   ps.safety_code,
   ps.severity,
   ps.blocking,
   ps.trigger_expression,
   ps.action_instruction,
   ps.rationale,
   r.rule_code,
   r.name AS rule_name
FROM knowledge.protocol_safety_rule ps
JOIN knowledge.protocol p
  ON p.id = ps.protocol_id
LEFT JOIN knowledge.rule r
  ON r.id = ps.rule_id
WHERE
   p.status = 'active';


COMMENT ON VIEW knowledge.protocol_safety_map IS
'Fast safety read model. Safety rules are evaluated independently of ordinary protocol actions.';


-- =============================================================================
-- 33. PROTOCOL PROVENANCE MAP
-- =============================================================================
-- Allows the clinical UI/AI to answer:
--
--   Why was this action produced?
--   Which rule fired?
--   Which protocol step produced it?
--   Which evidence supports the protocol?
--   Was it modified locally?
--
-- =============================================================================

CREATE VIEW knowledge.protocol_provenance_map AS
SELECT
   p.id                         AS protocol_id,
   p.protocol_code,
   p.canonical_name,

   s.id                         AS step_id,
   s.step_code,
   s.step_label,

   a.id                         AS action_id,
   a.action_type,
   a.action_code,
   a.action_name,

   r.id                         AS rule_id,
   r.rule_code,
   r.name                       AS rule_name,
   r.evidence_level,

   src.source_type,
   src.source_reference,
   src.citation,
   src.url

FROM knowledge.protocol p

JOIN knowledge.protocol_step s
  ON s.protocol_id = p.id

JOIN knowledge.protocol_action a
  ON a.step_id = s.id

LEFT JOIN knowledge.protocol_action_rule par
  ON par.action_id = a.id

LEFT JOIN knowledge.rule r
  ON r.id = par.rule_id

LEFT JOIN knowledge.protocol_source src
  ON src.protocol_id = p.id

WHERE
   p.status IN ('approved', 'active');


COMMENT ON VIEW knowledge.protocol_provenance_map IS
'Explainability map linking clinical actions to steps, rules and evidence sources.';


-- =============================================================================
-- 34. VALIDATION CONSTRAINTS
-- =============================================================================

ALTER TABLE knowledge.protocol_step
   ADD CONSTRAINT chk_protocol_step_sequence
   CHECK (sequence_no >= 0);

ALTER TABLE knowledge.protocol_action
   ADD CONSTRAINT chk_protocol_action_sort_order
   CHECK (sort_order >= 0);

ALTER TABLE knowledge.protocol_branch
   ADD CONSTRAINT chk_protocol_branch_not_self
   CHECK (from_step_id <> to_step_id);

ALTER TABLE knowledge.protocol_monitoring_transition
   ADD CONSTRAINT chk_protocol_monitoring_transition_not_self
   CHECK (from_step_id <> to_step_id);

ALTER TABLE knowledge.protocol_escalation
   ADD CONSTRAINT chk_protocol_escalation_response_time
   CHECK (
      response_time_minutes IS NULL
      OR response_time_minutes >= 0
   );


-- =============================================================================
-- 35. GOVERNANCE COMMENTS
-- =============================================================================

COMMENT ON COLUMN knowledge.protocol.executable IS
'Whether the protocol may participate in machine-executed clinical workflow.';

COMMENT ON COLUMN knowledge.protocol.requires_clinician_review IS
'Whether generated actions require clinician confirmation before execution.';

COMMENT ON COLUMN knowledge.protocol_step.decision_rule IS
'Machine-evaluable conditions controlling whether the step becomes active.';

COMMENT ON COLUMN knowledge.protocol_action.parameters IS
'Structured action parameters. Clinical truth should reference universal knowledge primitives rather than duplicated definitions.';

COMMENT ON COLUMN knowledge.protocol_action.clinician_confirmation IS
'Hard safety gate requiring clinician confirmation before the action can be executed.';

COMMENT ON COLUMN knowledge.protocol_monitoring.deterioration_rule IS
'Machine-evaluable deviation rule converting monitoring data into reassessment or escalation.';

COMMENT ON COLUMN knowledge.protocol_branch.condition_expression IS
'Machine-evaluable branch condition evaluated against the current patient fact/context state.';

COMMENT ON COLUMN knowledge.protocol_safety_rule.trigger_expression IS
'Independent safety expression capable of interrupting ordinary protocol execution.';


-- =============================================================================
-- 36. ARCHITECTURAL GUARANTEE
-- =============================================================================
--
-- The protocol layer does NOT become another disease database.
--
-- Example:
--
--   COUGH
--      ↓
--   QUESTION ENGINE
--      ↓
--   FACTS
--      ↓
--   PHENOTYPE
--      ↓
--   MECHANISM
--      ↓
--   DIFFERENTIAL
--      ↓
--   RULE ENGINE
--      ↓
--   PROTOCOL
--      ↓
--   INVESTIGATION
--   MEDICATION
--   MONITORING
--   EDUCATION
--      ↓
--   REASSESSMENT
--      ↓
--   ESCALATION / DISPOSITION / FOLLOW-UP
--
-- The same primitives can therefore operate across:
--
--   paediatrics
--   internal medicine
--   surgery
--   emergency medicine
--   obstetrics
--   gynaecology
--   psychiatry
--   anaesthesia
--   orthopaedics
--   ENT
--   ophthalmology
--   dermatology
--   oncology
--   infectious diseases
--   cardiology
--   pulmonology
--   nephrology
--   neurology
--   gastroenterology
--   ICU
--   primary care
--   community medicine
--   outpatient care
--   inpatient care
--   theatre
--   emergency care
--   telemedicine
--
-- WITHOUT creating separate disease engines.
-- =============================================================================