-- =============================================================================
-- AMEXAN Phase 2 — Migration 015: monitoring + education intelligence layer
-- =============================================================================
-- UNIVERSAL CLINICAL OPERATING SYSTEM PRINCIPLES
--
-- 1. Monitoring is not merely a list of vitals.
--    It is:
--       TARGET
--       -> BASELINE
--       -> MEASUREMENT
--       -> TREND
--       -> DEVIATION
--       -> ALERT
--       -> REASSESSMENT
--       -> ESCALATION
--       -> OUTCOME
--
-- 2. Monitoring primitives are universal.
--    SpO2, respiratory rate, heart rate, temperature, GCS, urine output,
--    pain, blood pressure, work of breathing, neurological status, etc.
--    are defined ONCE and reused across all conditions.
--
-- 3. Disease-specific behavior belongs in relationships/rules/protocols,
--    NOT inside the monitoring primitive.
--
-- 4. A monitoring target may be:
--       numeric
--       coded
--       boolean
--       ordinal
--       text
--       trend
--       composite
--
-- 5. Normality is contextual.
--    Age, sex, pregnancy, altitude, disease, treatment, care setting,
--    baseline physiology and clinical trajectory can modify interpretation.
--
-- 6. Education is also a clinical primitive.
--    Education is structured, versioned, multilingual, audience-specific,
--    literacy-aware and capable of teach-back verification.
--
-- 7. Education is not merely static text.
--    It can contain:
--       explanation
--       warning
--       instruction
--       preparation
--       medication instruction
--       monitoring instruction
--       discharge instruction
--       follow-up instruction
--       teach-back question
--       emergency return instruction
--
-- 8. The CPU must be able to answer:
--       What are we monitoring?
--       Why are we monitoring it?
--       What was the baseline?
--       What is the current value?
--       Is it changing?
--       Is the change clinically significant?
--       What action should occur?
--       Who must be notified?
--       How urgently?
--       What education should this patient/caregiver receive?
--       Did they understand it?
--
-- =============================================================================


-- ============================================================================
-- 1. MONITORING TARGET
-- ============================================================================

CREATE TABLE knowledge.monitoring (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid REFERENCES knowledge.concept(id),

   monitoring_code       text NOT NULL UNIQUE,
   canonical_name        text NOT NULL,
   display_name          text,

   description           text,

   target_type           text NOT NULL DEFAULT 'numeric'
                         CHECK (
                            target_type IN (
                               'numeric',
                               'coded',
                               'boolean',
                               'ordinal',
                               'text',
                               'trend',
                               'composite'
                            )
                         ),

   measurement_domain    text,
   unit                  text,

   body_system_code      text REFERENCES knowledge.body_system(code),

   -- Generic reference range only.
   -- Clinical interpretation MUST be context-aware.
   normal_low            numeric,
   normal_high           numeric,

   preferred_precision   integer CHECK (
                            preferred_precision IS NULL
                            OR preferred_precision >= 0
                         ),

   minimum_value         numeric,
   maximum_value         numeric,

   directionality        text
                         CHECK (
                            directionality IS NULL
                            OR directionality IN (
                               'higher_is_worse',
                               'lower_is_worse',
                               'bidirectional',
                               'context_dependent',
                               'informational'
                            )
                         ),

   acquisition_method    text,
   measurement_frequency text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.monitoring IS
'Universal physiological/clinical monitoring target. The target is defined once; condition-specific thresholds, timing, interpretation and escalation are attached through reusable rules, protocols and context.';

COMMENT ON COLUMN knowledge.monitoring.normal_low IS
'Generic reference lower bound only. Never assume this is the clinically applicable threshold for every patient.';

COMMENT ON COLUMN knowledge.monitoring.normal_high IS
'Generic reference upper bound only. Clinical interpretation must resolve patient/context-specific thresholds.';

CREATE INDEX idx_knowledge_monitoring_concept
   ON knowledge.monitoring(concept_id);

CREATE INDEX idx_knowledge_monitoring_system
   ON knowledge.monitoring(body_system_code);

CREATE INDEX idx_knowledge_monitoring_type
   ON knowledge.monitoring(target_type);

CREATE INDEX idx_knowledge_monitoring_status
   ON knowledge.monitoring(status);

CREATE TRIGGER trg_knowledge_monitoring_updated_at
   BEFORE UPDATE ON knowledge.monitoring
   FOR EACH ROW
   EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 2. MONITORING -> CONDITION
-- ============================================================================

CREATE TABLE knowledge.monitoring_condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   condition_id          uuid NOT NULL
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   weight                numeric(5,3) NOT NULL DEFAULT 1.0
                         CHECK (weight >= 0),

   relevance             text NOT NULL DEFAULT 'routine'
                         CHECK (
                            relevance IN (
                               'critical',
                               'high',
                               'routine',
                               'optional',
                               'context_dependent'
                            )
                         ),

   rationale              text,

   UNIQUE (monitoring_id, condition_id)
);

COMMENT ON TABLE knowledge.monitoring_condition IS
'Associates universal monitoring targets with conditions without duplicating the monitoring definition.';


-- ============================================================================
-- 3. MONITORING CONTEXT
-- ============================================================================
-- Normal values and interpretation vary with age, pregnancy, altitude,
-- baseline disease, care setting, etc.
-- ============================================================================

CREATE TABLE knowledge.monitoring_context (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   context_type_code     text NOT NULL
                         REFERENCES knowledge.context_type(code),

   context_value_id      uuid
                         REFERENCES knowledge.context_value(id),

   applicability         text NOT NULL DEFAULT 'applies'
                         CHECK (
                            applicability IN (
                               'applies',
                               'excludes'
                            )
                         ),

   reference_low         numeric,

   reference_high        numeric,

   interpretation        text,

   weight                numeric(5,3) NOT NULL DEFAULT 1.0
                         CHECK (weight >= 0),

   UNIQUE (
      monitoring_id,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.monitoring_context IS
'Context-sensitive interpretation of a monitoring target. Prevents unsafe universal reference ranges.';

CREATE INDEX idx_monitoring_context_lookup
   ON knowledge.monitoring_context(
      monitoring_id,
      context_type_code,
      context_value_id
   );


-- ============================================================================
-- 4. MONITORING METHOD
-- ============================================================================
-- The same target may be measured by different methods.
-- Example:
--   SpO2 -> pulse oximeter
--   temperature -> oral / axillary / tympanic / rectal
--   BP -> invasive / non-invasive
-- ============================================================================

CREATE TABLE knowledge.monitoring_method (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   method_code           text NOT NULL,

   method_name           text NOT NULL,

   description           text,

   unit                  text,

   reliability_rank      integer NOT NULL DEFAULT 50,

   limitations            text,

   prerequisites         text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (monitoring_id, method_code)
);

COMMENT ON TABLE knowledge.monitoring_method IS
'Permitted acquisition methods for a universal monitoring target.';


-- ============================================================================
-- 5. MONITORING VALUE TYPE / CODE
-- ============================================================================
-- Required for coded, boolean and ordinal monitoring.
-- ============================================================================

CREATE TABLE knowledge.monitoring_option (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   option_code           text NOT NULL,

   label                 text NOT NULL,

   ordinal_value         numeric,

   severity_rank         integer,

   clinical_meaning      text,

   sort_order            integer NOT NULL DEFAULT 0,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (monitoring_id, option_code)
);

COMMENT ON TABLE knowledge.monitoring_option IS
'Structured values for coded/boolean/ordinal monitoring targets.';


-- ============================================================================
-- 6. MONITORING BASELINE DEFINITION
-- ============================================================================
-- Defines what constitutes a baseline without storing patient observations.
-- Actual patient observations belong in the clinical/runtime layer.
-- ============================================================================

CREATE TABLE knowledge.monitoring_baseline_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   condition_id          uuid
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   context_type_code     text
                         REFERENCES knowledge.context_type(code),

   context_value_id      uuid
                         REFERENCES knowledge.context_value(id),

   baseline_type         text NOT NULL DEFAULT 'first_valid'
                         CHECK (
                            baseline_type IN (
                               'first_valid',
                               'pre_treatment',
                               'post_stabilization',
                               'admission',
                               'pre_procedure',
                               'custom'
                            )
                         ),

   minimum_measurements  integer NOT NULL DEFAULT 1
                         CHECK (minimum_measurements > 0),

   baseline_window_minutes integer,

   description           text,

   UNIQUE (
      monitoring_id,
      condition_id,
      context_type_code,
      context_value_id,
      baseline_type
   )
);

COMMENT ON TABLE knowledge.monitoring_baseline_rule IS
'Defines how the clinical runtime should establish a baseline for a monitoring target.';


-- ============================================================================
-- 7. MONITORING TREND DEFINITION
-- ============================================================================
-- A single value may be normal while the trajectory is dangerous.
-- ============================================================================

CREATE TABLE knowledge.monitoring_trend_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   condition_id          uuid
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   trend_code            text NOT NULL,

   direction             text NOT NULL
                         CHECK (
                            direction IN (
                               'rising',
                               'falling',
                               'stable',
                               'worsening',
                               'improving',
                               'volatile',
                               'crossing_threshold',
                               'deviation_from_baseline'
                            )
                         ),

   window_minutes        integer
                         CHECK (
                            window_minutes IS NULL
                            OR window_minutes > 0
                         ),

   minimum_points        integer NOT NULL DEFAULT 2
                         CHECK (minimum_points >= 2),

   delta_absolute        numeric,

   delta_percent         numeric,

   threshold_crossings   integer,

   severity              text NOT NULL DEFAULT 'moderate'
                         CHECK (
                            severity IN (
                               'informational',
                               'mild',
                               'moderate',
                               'severe',
                               'critical'
                            )
                         ),

   interpretation        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      monitoring_id,
      condition_id,
      trend_code
   )
);

COMMENT ON TABLE knowledge.monitoring_trend_rule IS
'Reusable trajectory logic. The system can detect deterioration even when an isolated measurement is not independently abnormal.';

CREATE INDEX idx_monitoring_trend_monitoring
   ON knowledge.monitoring_trend_rule(monitoring_id);

CREATE INDEX idx_monitoring_trend_condition
   ON knowledge.monitoring_trend_rule(condition_id);


-- ============================================================================
-- 8. MONITORING THRESHOLD
-- ============================================================================
-- Thresholds are deliberately separate from the monitoring primitive.
-- This permits different thresholds for different conditions/contexts.
-- ============================================================================

CREATE TABLE knowledge.monitoring_threshold (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   condition_id          uuid
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   context_type_code     text
                         REFERENCES knowledge.context_type(code),

   context_value_id      uuid
                         REFERENCES knowledge.context_value(id),

   threshold_code        text NOT NULL,

   operator              text NOT NULL
                         CHECK (
                            operator IN (
                               'eq',
                               'neq',
                               'gt',
                               'gte',
                               'lt',
                               'lte',
                               'between',
                               'outside',
                               'exists',
                               'not_exists',
                               'change_gt',
                               'change_lt',
                               'change_pct_gt',
                               'change_pct_lt'
                            )
                         ),

   lower_value           numeric,

   upper_value           numeric,

   threshold_value       numeric,

   severity              text NOT NULL DEFAULT 'moderate'
                         CHECK (
                            severity IN (
                               'informational',
                               'mild',
                               'moderate',
                               'severe',
                               'critical'
                            )
                         ),

   interpretation        text,

   clinical_significance text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      monitoring_id,
      condition_id,
      context_type_code,
      context_value_id,
      threshold_code
   )
);

COMMENT ON TABLE knowledge.monitoring_threshold IS
'Context-aware clinical threshold definitions. Thresholds belong to interpretation rules, not to the universal monitoring primitive.';

CREATE INDEX idx_monitoring_threshold_lookup
   ON knowledge.monitoring_threshold(
      monitoring_id,
      condition_id,
      context_type_code,
      context_value_id
   );


-- ============================================================================
-- 9. MONITORING ALERT
-- ============================================================================
-- Defines the clinical signal produced when a threshold/trend becomes true.
-- ============================================================================

CREATE TABLE knowledge.monitoring_alert (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   threshold_id          uuid
                         REFERENCES knowledge.monitoring_threshold(id)
                         ON DELETE SET NULL,

   trend_rule_id         uuid
                         REFERENCES knowledge.monitoring_trend_rule(id)
                         ON DELETE SET NULL,

   alert_code            text NOT NULL UNIQUE,

   alert_level           text NOT NULL
                         CHECK (
                            alert_level IN (
                               'info',
                               'warning',
                               'urgent',
                               'emergency'
                            )
                         ),

   alert_title           text NOT NULL,

   alert_message         text,

   clinical_meaning      text,

   recommended_response  text,

   requires_reassessment boolean NOT NULL DEFAULT true,

   requires_notification boolean NOT NULL DEFAULT false,

   notification_priority integer NOT NULL DEFAULT 50,

   auto_escalate         boolean NOT NULL DEFAULT false,

   escalation_minutes    integer,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      monitoring_id,
      threshold_id,
      trend_rule_id,
      alert_code
   )
);

COMMENT ON TABLE knowledge.monitoring_alert IS
'Clinical alert definition generated from monitoring deviation or trajectory.';


-- ============================================================================
-- 10. MONITORING ESCALATION
-- ============================================================================

CREATE TABLE knowledge.monitoring_escalation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   alert_id              uuid NOT NULL
                         REFERENCES knowledge.monitoring_alert(id)
                         ON DELETE CASCADE,

   escalation_order      integer NOT NULL DEFAULT 1,

   escalation_level      text NOT NULL
                         CHECK (
                            escalation_level IN (
                               'clinician',
                               'senior_clinician',
                               'team_lead',
                               'specialist',
                               'rapid_response',
                               'emergency_response',
                               'critical_care'
                            )
                         ),

   target_role_code      text,

   response_minutes      integer,

   action_code           text,

   instruction           text,

   UNIQUE (alert_id, escalation_order)
);

COMMENT ON TABLE knowledge.monitoring_escalation IS
'Ordered escalation pathway for clinically significant monitoring alerts.';

CREATE INDEX idx_monitoring_escalation_alert
   ON knowledge.monitoring_escalation(alert_id);


-- ============================================================================
-- 11. MONITORING ACTION
-- ============================================================================
-- Converts a monitoring signal into an executable clinical response.
-- ============================================================================

CREATE TABLE knowledge.monitoring_action (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   alert_id              uuid
                         REFERENCES knowledge.monitoring_alert(id)
                         ON DELETE CASCADE,

   trend_rule_id         uuid
                         REFERENCES knowledge.monitoring_trend_rule(id)
                         ON DELETE CASCADE,

   action_order          integer NOT NULL DEFAULT 0,

   action_type           text NOT NULL
                         CHECK (
                            action_type IN (
                               'recheck',
                               'reassess',
                               'repeat_measurement',
                               'activate_question',
                               'activate_examination',
                               'recommend_investigation',
                               'recommend_management',
                               'notify_clinician',
                               'escalate',
                               'transfer',
                               'activate_protocol',
                               'document',
                               'educate'
                            )
                         ),

   action_code           text,

   target_type           text,

   target_code           text,

   parameters            jsonb,

   rationale             text,

   UNIQUE (
      alert_id,
      trend_rule_id,
      action_order
   )
);

COMMENT ON TABLE knowledge.monitoring_action IS
'Executable clinical response to monitoring deterioration or significant trajectory change.';


-- ============================================================================
-- 12. MONITORING SCHEDULE
-- ============================================================================
-- Defines how frequently a target should be measured in a clinical protocol.
-- ============================================================================

CREATE TABLE knowledge.monitoring_schedule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   condition_id          uuid
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   schedule_code         text NOT NULL UNIQUE,

   phase                 text,
   frequency_type        text NOT NULL DEFAULT 'interval'
                         CHECK (
                            frequency_type IN (
                               'once',
                               'interval',
                               'continuous',
                               'event_driven',
                               'prn',
                               'custom'
                            )
                         ),

   interval_minutes      integer
                         CHECK (
                            interval_minutes IS NULL
                            OR interval_minutes > 0
                         ),

   start_trigger         text,

   stop_trigger          text,

   duration_minutes      integer,

   priority              integer NOT NULL DEFAULT 50,

   instructions          text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      monitoring_id,
      condition_id,
      schedule_code
   )
);

COMMENT ON TABLE knowledge.monitoring_schedule IS
'Defines when a monitoring target should be measured. The schedule is protocol/context dependent and is not embedded in the target.';


-- ============================================================================
-- 13. MONITORING SCHEDULE CONTEXT
-- ============================================================================

CREATE TABLE knowledge.monitoring_schedule_context (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   schedule_id           uuid NOT NULL
                         REFERENCES knowledge.monitoring_schedule(id)
                         ON DELETE CASCADE,

   context_type_code     text NOT NULL
                         REFERENCES knowledge.context_type(code),

   context_value_id      uuid
                         REFERENCES knowledge.context_value(id),

   applicability         text NOT NULL DEFAULT 'applies'
                         CHECK (
                            applicability IN (
                               'applies',
                               'excludes'
                            )
                         ),

   priority              integer NOT NULL DEFAULT 0,

   UNIQUE (
      schedule_id,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.monitoring_schedule_context IS
'Context rules determining when a monitoring schedule applies.';


-- ============================================================================
-- 14. MONITORING COMPOSITE
-- ============================================================================
-- Some clinical states are not represented by one variable.
-- Example:
--   work of breathing = RR + accessory muscle use + nasal flaring + grunting
-- ============================================================================

CREATE TABLE knowledge.monitoring_component (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   parent_monitoring_id  uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   component_monitoring_id uuid NOT NULL
                           REFERENCES knowledge.monitoring(id)
                           ON DELETE CASCADE,

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   required              boolean NOT NULL DEFAULT false,

   contribution_type     text NOT NULL DEFAULT 'supporting'
                         CHECK (
                            contribution_type IN (
                               'required',
                               'supporting',
                               'contradicting'
                            )
                         ),

   UNIQUE (
      parent_monitoring_id,
      component_monitoring_id
   ),

   CHECK (
      parent_monitoring_id <> component_monitoring_id
   )
);

COMMENT ON TABLE knowledge.monitoring_component IS
'Composes multiple universal monitoring targets into a higher-order clinical trajectory or composite state.';


-- ============================================================================
-- 15. MONITORING RELATIONSHIP
-- ============================================================================
-- Universal graph edge for monitoring behavior without proliferating tables.
-- ============================================================================

CREATE TABLE knowledge.monitoring_relationship (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   related_monitoring_id uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL
                         CHECK (
                            relationship_type IN (
                               'correlates_with',
                               'precedes',
                               'follows',
                               'confirms',
                               'contradicts',
                               'co_deteriorates',
                               'co_improves',
                               'component_of'
                            )
                         ),

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   description           text,

   UNIQUE (
      monitoring_id,
      related_monitoring_id,
      relationship_type
   ),

   CHECK (
      monitoring_id <> related_monitoring_id
   )
);

COMMENT ON TABLE knowledge.monitoring_relationship IS
'Typed relationships between monitoring targets, enabling multi-variable clinical trajectory reasoning.';


-- ============================================================================
-- 16. MONITORING DOCUMENTATION
-- ============================================================================
-- Converts structured monitoring events into clinically usable documentation.
-- ============================================================================

CREATE TABLE knowledge.monitoring_documentation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   alert_id              uuid
                         REFERENCES knowledge.monitoring_alert(id)
                         ON DELETE SET NULL,

   documentation_code    text NOT NULL UNIQUE,

   phrase_template       text NOT NULL,

   language_code         text NOT NULL DEFAULT 'en',

   context_code          text,

   is_preferred          boolean NOT NULL DEFAULT false,

   UNIQUE (
      monitoring_id,
      phrase_template,
      language_code,
      context_code
   )
);

COMMENT ON TABLE knowledge.monitoring_documentation IS
'Structured documentation templates for monitoring observations and clinically significant changes.';


-- ============================================================================
-- 17. EDUCATION CONTENT
-- ============================================================================
-- Education is a reusable clinical knowledge node.
-- ============================================================================

CREATE TABLE knowledge.education (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid REFERENCES knowledge.concept(id),

   education_code        text NOT NULL UNIQUE,

   title                 text NOT NULL,

   audience              text NOT NULL DEFAULT 'patient'
                         CHECK (
                            audience IN (
                               'patient',
                               'caregiver',
                               'clinician',
                               'community',
                               'mixed'
                            )
                         ),

   content_type          text NOT NULL DEFAULT 'explanation'
                         CHECK (
                            content_type IN (
                               'explanation',
                               'warning',
                               'instruction',
                               'preparation',
                               'medication_instruction',
                               'monitoring_instruction',
                               'teach_back',
                               'follow_up',
                               'discharge',
                               'prevention',
                               'lifestyle',
                               'emergency_return',
                               'procedure',
                               'other'
                            )
                         ),

   language_code         text NOT NULL DEFAULT 'en',

   literacy_level        text
                         CHECK (
                            literacy_level IS NULL
                            OR literacy_level IN (
                               'plain',
                               'basic',
                               'intermediate',
                               'professional'
                            )
                         ),

   title_short           text,

   body                  text NOT NULL,

   clinical_purpose      text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   version               integer NOT NULL DEFAULT 1
                         CHECK (version > 0),

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.education IS
'Reusable, versioned clinical education content for patients, caregivers, clinicians and communities. Education is part of the clinical knowledge substrate, not merely UI text.';

CREATE INDEX idx_knowledge_education_concept
   ON knowledge.education(concept_id);

CREATE INDEX idx_knowledge_education_audience
   ON knowledge.education(audience);

CREATE INDEX idx_knowledge_education_language
   ON knowledge.education(language_code);

CREATE INDEX idx_knowledge_education_type
   ON knowledge.education(content_type);

CREATE TRIGGER trg_knowledge_education_updated_at
   BEFORE UPDATE ON knowledge.education
   FOR EACH ROW
   EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 18. EDUCATION -> CONDITION
-- ============================================================================

CREATE TABLE knowledge.education_condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   condition_id          uuid NOT NULL
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   weight                numeric(5,3) NOT NULL DEFAULT 1.0
                         CHECK (weight >= 0),

   relevance             text NOT NULL DEFAULT 'routine'
                         CHECK (
                            relevance IN (
                               'critical',
                               'high',
                               'routine',
                               'optional',
                               'context_dependent'
                            )
                         ),

   UNIQUE (education_id, condition_id)
);

COMMENT ON TABLE knowledge.education_condition IS
'Conditions for which education is clinically relevant.';


-- ============================================================================
-- 19. EDUCATION CONTEXT
-- ============================================================================
-- The same concept may need different education for:
--   neonate caregiver
--   child caregiver
--   adult patient
--   pregnancy
--   low literacy
--   clinician
-- ============================================================================

CREATE TABLE knowledge.education_context (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   context_type_code     text NOT NULL
                         REFERENCES knowledge.context_type(code),

   context_value_id      uuid
                         REFERENCES knowledge.context_value(id),

   applicability         text NOT NULL DEFAULT 'applies'
                         CHECK (
                            applicability IN (
                               'applies',
                               'excludes'
                            )
                         ),

   priority              integer NOT NULL DEFAULT 0,

   UNIQUE (
      education_id,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.education_context IS
'Context-aware education selection.';


-- ============================================================================
-- 20. EDUCATION TRANSLATION
-- ============================================================================
-- Keeps the education concept separate from presentation language.
-- ============================================================================

CREATE TABLE knowledge.education_translation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   language_code         text NOT NULL,

   title                 text NOT NULL,

   title_short           text,

   body                  text NOT NULL,

   literacy_level        text
                         CHECK (
                            literacy_level IS NULL
                            OR literacy_level IN (
                               'plain',
                               'basic',
                               'intermediate',
                               'professional'
                            )
                         ),

   is_preferred          boolean NOT NULL DEFAULT false,

   UNIQUE (
      education_id,
      language_code,
      literacy_level
   )
);

COMMENT ON TABLE knowledge.education_translation IS
'Localized education content while preserving one universal education concept.';


-- ============================================================================
-- 21. EDUCATION DELIVERY RULE
-- ============================================================================
-- Determines when education should appear.
-- Example:
--   pneumonia + discharge -> danger signs
--   new antibiotic -> adherence/adverse effects
--   abnormal SpO2 -> emergency warning
-- ============================================================================

CREATE TABLE knowledge.education_trigger (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   trigger_type          text NOT NULL
                         CHECK (
                            trigger_type IN (
                               'condition',
                               'symptom',
                               'sign',
                               'fact',
                               'phenotype',
                               'mechanism',
                               'investigation',
                               'medication',
                               'complication',
                               'monitoring',
                               'alert',
                               'procedure',
                               'discharge',
                               'follow_up',
                               'context'
                            )
                         ),

   trigger_code          text NOT NULL,

   trigger_concept_id    uuid
                         REFERENCES knowledge.concept(id),

   condition             jsonb,

   priority              integer NOT NULL DEFAULT 50,

   mandatory             boolean NOT NULL DEFAULT false,

   UNIQUE (
      education_id,
      trigger_type,
      trigger_code
   )
);

COMMENT ON TABLE knowledge.education_trigger IS
'Clinical activation triggers for patient/caregiver/clinician education.';


CREATE INDEX idx_knowledge_education_trigger
   ON knowledge.education_trigger(trigger_type, trigger_code);


-- ============================================================================
-- 22. EDUCATION REQUIREMENT
-- ============================================================================
-- Allows AMEXAN to measure whether required education was delivered.
-- ============================================================================

CREATE TABLE knowledge.education_requirement (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   requirement_type      text NOT NULL
                         CHECK (
                            requirement_type IN (
                               'required',
                               'conditionally_required',
                               'recommended',
                               'optional'
                            )
                         ),

   condition             jsonb,

   priority              integer NOT NULL DEFAULT 50,

   rationale             text,

   UNIQUE (
      education_id,
      requirement_type,
      priority
   )
);

COMMENT ON TABLE knowledge.education_requirement IS
'Defines whether education is mandatory, conditional, recommended or optional in a clinical context.';


-- ============================================================================
-- 23. TEACH-BACK DEFINITION
-- ============================================================================
-- Education is not complete merely because content was displayed.
-- The system can verify understanding.
-- ============================================================================

CREATE TABLE knowledge.education_teach_back (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   teach_back_code       text NOT NULL UNIQUE,

   question_text         text NOT NULL,

   response_type         text NOT NULL DEFAULT 'free_text'
                         CHECK (
                            response_type IN (
                               'boolean',
                               'single_choice',
                               'multiple_choice',
                               'numeric',
                               'free_text'
                            )
                         ),

   expected_answer       jsonb,

   acceptable_answers    jsonb,

   failure_instruction   text,

   retry_allowed         boolean NOT NULL DEFAULT true,

   max_attempts          integer
                         CHECK (
                            max_attempts IS NULL
                            OR max_attempts > 0
                         ),

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated'))
);

COMMENT ON TABLE knowledge.education_teach_back IS
'Structured teach-back definition used to verify patient/caregiver understanding.';


-- ============================================================================
-- 24. EDUCATION DELIVERY CHANNEL
-- ============================================================================
-- Same education may be rendered in multiple modalities.
-- ============================================================================

CREATE TABLE knowledge.education_channel (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   channel_code          text NOT NULL
                         CHECK (
                            channel_code IN (
                               'clinical_note',
                               'patient_portal',
                               'mobile',
                               'print',
                               'sms',
                               'voice',
                               'video',
                               'bedside',
                               'discharge_summary'
                            )
                         ),

   content_variant       text,

   enabled               boolean NOT NULL DEFAULT true,

   UNIQUE (
      education_id,
      channel_code
   )
);

COMMENT ON TABLE knowledge.education_channel IS
'Presentation channels for reusable clinical education content.';


-- ============================================================================
-- 25. EDUCATION RELATIONSHIP
-- ============================================================================

CREATE TABLE knowledge.education_relationship (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   related_education_id  uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL
                         CHECK (
                            relationship_type IN (
                               'prerequisite',
                               'follow_up',
                               'complements',
                               'replaces',
                               'contradicts',
                               'related'
                            )
                         ),

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   UNIQUE (
      education_id,
      related_education_id,
      relationship_type
   ),

   CHECK (
      education_id <> related_education_id
   )
);

COMMENT ON TABLE knowledge.education_relationship IS
'Typed relationships between education nodes, enabling sequenced and context-aware education.';


-- ============================================================================
-- 26. EDUCATION DOCUMENTATION
-- ============================================================================
-- Standardized statements proving education occurred.
-- ============================================================================

CREATE TABLE knowledge.education_documentation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   documentation_code    text NOT NULL UNIQUE,

   phrase_template       text NOT NULL,

   language_code         text NOT NULL DEFAULT 'en',

   context_code          text,

   is_preferred          boolean NOT NULL DEFAULT false,

   UNIQUE (
      education_id,
      phrase_template,
      language_code,
      context_code
   )
);

COMMENT ON TABLE knowledge.education_documentation IS
'Documentation templates for recording education delivered, understanding assessed and instructions provided.';


-- ============================================================================
-- 27. UNIVERSAL MONITORING <-> EDUCATION BRIDGE
-- ============================================================================
-- Example:
--   MON-SPO2 abnormal
--       -> EDU-OXYGEN-DANGER-SIGNS
--
-- This remains universal rather than hardcoding disease behavior.
-- ============================================================================

CREATE TABLE knowledge.monitoring_education (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   education_id          uuid NOT NULL
                         REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   trigger_type          text NOT NULL
                         CHECK (
                            trigger_type IN (
                               'baseline',
                               'abnormal',
                               'worsening',
                               'improving',
                               'alert',
                               'discharge',
                               'follow_up'
                            )
                         ),

   threshold_id          uuid
                         REFERENCES knowledge.monitoring_threshold(id)
                         ON DELETE SET NULL,

   alert_id              uuid
                         REFERENCES knowledge.monitoring_alert(id)
                         ON DELETE SET NULL,

   priority              integer NOT NULL DEFAULT 50,

   UNIQUE (
      monitoring_id,
      education_id,
      trigger_type,
      threshold_id,
      alert_id
   )
);

COMMENT ON TABLE knowledge.monitoring_education IS
'Universal bridge from monitoring events to appropriate patient/caregiver/clinician education.';


-- ============================================================================
-- 28. MONITORING -> QUESTION ENGINE BRIDGE
-- ============================================================================
-- Monitoring abnormalities can trigger further history.
-- Example:
--   tachycardia -> pain/fever/bleeding/dehydration questions
--   hypoxaemia -> respiratory symptom questions
-- ============================================================================

CREATE TABLE knowledge.monitoring_question (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   question_id           uuid NOT NULL
                         REFERENCES knowledge.question(id)
                         ON DELETE CASCADE,

   trigger_type          text NOT NULL
                         CHECK (
                            trigger_type IN (
                               'abnormal',
                               'worsening',
                               'critical',
                               'trend',
                               'context'
                            )
                         ),

   threshold_id          uuid
                         REFERENCES knowledge.monitoring_threshold(id)
                         ON DELETE SET NULL,

   trend_rule_id         uuid
                         REFERENCES knowledge.monitoring_trend_rule(id)
                         ON DELETE SET NULL,

   priority              integer NOT NULL DEFAULT 50,

   UNIQUE (
      monitoring_id,
      question_id,
      trigger_type,
      threshold_id,
      trend_rule_id
   )
);

COMMENT ON TABLE knowledge.monitoring_question IS
'Allows monitoring abnormalities to activate targeted history questions through the universal question engine.';


-- ============================================================================
-- 29. MONITORING -> EXAMINATION BRIDGE
-- ============================================================================
-- Abnormal monitoring may activate focused examination.
-- ============================================================================

CREATE TABLE knowledge.monitoring_examination (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   examination_module_id uuid NOT NULL
                         REFERENCES knowledge.examination_module(id)
                         ON DELETE CASCADE,

   trigger_type          text NOT NULL
                         CHECK (
                            trigger_type IN (
                               'abnormal',
                               'worsening',
                               'critical',
                               'trend'
                            )
                         ),

   threshold_id          uuid
                         REFERENCES knowledge.monitoring_threshold(id)
                         ON DELETE SET NULL,

   trend_rule_id         uuid
                         REFERENCES knowledge.monitoring_trend_rule(id)
                         ON DELETE SET NULL,

   priority              integer NOT NULL DEFAULT 50,

   UNIQUE (
      monitoring_id,
      examination_module_id,
      trigger_type,
      threshold_id,
      trend_rule_id
   )
);

COMMENT ON TABLE knowledge.monitoring_examination IS
'Allows monitoring deterioration to activate focused physical examination modules.';


-- ============================================================================
-- 30. MONITORING -> INVESTIGATION BRIDGE
-- ============================================================================

CREATE TABLE knowledge.monitoring_investigation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   trigger_type          text NOT NULL
                         CHECK (
                            trigger_type IN (
                               'abnormal',
                               'worsening',
                               'critical',
                               'trend',
                               'persistent_abnormality'
                            )
                         ),

   threshold_id          uuid
                         REFERENCES knowledge.monitoring_threshold(id)
                         ON DELETE SET NULL,

   trend_rule_id         uuid
                         REFERENCES knowledge.monitoring_trend_rule(id)
                         ON DELETE SET NULL,

   priority              integer NOT NULL DEFAULT 50,

   rationale              text,

   UNIQUE (
      monitoring_id,
      investigation_id,
      trigger_type,
      threshold_id,
      trend_rule_id
   )
);

COMMENT ON TABLE knowledge.monitoring_investigation IS
'Allows monitoring abnormalities to suggest appropriate investigations through reusable clinical logic.';


-- ============================================================================
-- 31. UNIVERSAL MONITORING GRAPH EDGES
-- ============================================================================
-- Extends the generalized knowledge graph without making monitoring a
-- disease-specific universe.
-- ============================================================================

CREATE TABLE knowledge.monitoring_knowledge_edge (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   monitoring_id         uuid NOT NULL
                         REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   target_type           text NOT NULL
                         CHECK (
                            target_type IN (
                               'concept',
                               'fact',
                               'symptom',
                               'sign',
                               'finding',
                               'phenotype',
                               'mechanism',
                               'condition',
                               'investigation',
                               'medication',
                               'complication',
                               'protocol',
                               'monitoring',
                               'education'
                            )
                         ),

   target_id             uuid NOT NULL,

   relationship_type     text NOT NULL
                         CHECK (
                            relationship_type IN (
                               'supports',
                               'contradicts',
                               'indicates',
                               'associated_with',
                               'precedes',
                               'follows',
                               'triggers',
                               'requires',
                               'explains',
                               'monitors',
                               'educates'
                            )
                         ),

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (
                            polarity IN (
                               'positive',
                               'negative'
                            )
                         ),

   context               jsonb,

   confidence            numeric(4,3)
                         CHECK (
                            confidence IS NULL
                            OR (
                               confidence >= 0
                               AND confidence <= 1
                            )
                         ),

   evidence              text,

   version               text,

   is_active             boolean NOT NULL DEFAULT true,

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.monitoring_knowledge_edge IS
'Typed knowledge-graph edges connecting monitoring targets to universal clinical concepts without creating disease-specific monitoring schemas.';

CREATE INDEX idx_monitoring_knowledge_edge_source
   ON knowledge.monitoring_knowledge_edge(monitoring_id);

CREATE INDEX idx_monitoring_knowledge_edge_target
   ON knowledge.monitoring_knowledge_edge(target_type, target_id);

CREATE INDEX idx_monitoring_knowledge_edge_type
   ON knowledge.monitoring_knowledge_edge(relationship_type);

CREATE TRIGGER trg_knowledge_monitoring_knowledge_edge_updated_at
   BEFORE UPDATE ON knowledge.monitoring_knowledge_edge
   FOR EACH ROW
   EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 32. DATA-INTEGRITY CHECKS
-- ============================================================================

ALTER TABLE knowledge.monitoring
   ADD CONSTRAINT chk_monitoring_range
   CHECK (
      normal_low IS NULL
      OR normal_high IS NULL
      OR normal_low <= normal_high
   );

ALTER TABLE knowledge.monitoring
   ADD CONSTRAINT chk_monitoring_minmax
   CHECK (
      minimum_value IS NULL
      OR maximum_value IS NULL
      OR minimum_value <= maximum_value
   );

ALTER TABLE knowledge.monitoring_threshold
   ADD CONSTRAINT chk_monitoring_threshold_range
   CHECK (
      (
         operator IN ('between','outside')
         AND lower_value IS NOT NULL
         AND upper_value IS NOT NULL
         AND lower_value <= upper_value
      )
      OR
      (
         operator NOT IN ('between','outside')
      )
   );

ALTER TABLE knowledge.monitoring_threshold
   ADD CONSTRAINT chk_monitoring_threshold_scalar
   CHECK (
      operator IN ('between','outside')
      OR operator IN ('exists','not_exists')
      OR threshold_value IS NOT NULL
      OR (
         operator IN (
            'change_gt',
            'change_lt',
            'change_pct_gt',
            'change_pct_lt'
         )
         AND threshold_value IS NOT NULL
      )
   );

ALTER TABLE knowledge.monitoring_alert
   ADD CONSTRAINT chk_monitoring_alert_escalation
   CHECK (
      auto_escalate = false
      OR escalation_minutes IS NOT NULL
   );

ALTER TABLE knowledge.monitoring_trend_rule
   ADD CONSTRAINT chk_monitoring_trend_delta
   CHECK (
      delta_absolute IS NULL
      OR delta_absolute >= 0
   );

ALTER TABLE knowledge.monitoring_trend_rule
   ADD CONSTRAINT chk_monitoring_trend_percent
   CHECK (
      delta_percent IS NULL
      OR delta_percent >= 0
   );


-- ============================================================================
-- 33. HIGH-SPEED LOOKUP INDEXES
-- ============================================================================
-- These indexes support the clinical CPU path:
--
-- patient context
--      ->
-- active condition
--      ->
-- monitoring targets
--      ->
-- applicable thresholds
--      ->
-- trends
--      ->
-- alerts
--      ->
-- actions
--      ->
-- education
-- ============================================================================

CREATE INDEX idx_monitoring_condition_condition
   ON knowledge.monitoring_condition(condition_id, monitoring_id);

CREATE INDEX idx_monitoring_context_context
   ON knowledge.monitoring_context(
      context_type_code,
      context_value_id,
      monitoring_id
   );

CREATE INDEX idx_monitoring_threshold_monitoring_condition
   ON knowledge.monitoring_threshold(
      monitoring_id,
      condition_id
   );

CREATE INDEX idx_monitoring_alert_threshold
   ON knowledge.monitoring_alert(threshold_id);

CREATE INDEX idx_monitoring_alert_trend
   ON knowledge.monitoring_alert(trend_rule_id);

CREATE INDEX idx_monitoring_action_alert
   ON knowledge.monitoring_action(alert_id);

CREATE INDEX idx_monitoring_action_trend
   ON knowledge.monitoring_action(trend_rule_id);

CREATE INDEX idx_monitoring_schedule_condition
   ON knowledge.monitoring_schedule(condition_id, monitoring_id);

CREATE INDEX idx_education_condition_condition
   ON knowledge.education_condition(condition_id, education_id);

CREATE INDEX idx_education_context_context
   ON knowledge.education_context(
      context_type_code,
      context_value_id,
      education_id
   );

CREATE INDEX idx_education_trigger_lookup
   ON knowledge.education_trigger(
      trigger_type,
      trigger_code,
      education_id
   );

CREATE INDEX idx_monitoring_education_monitoring
   ON knowledge.monitoring_education(
      monitoring_id,
      trigger_type
   );

CREATE INDEX idx_monitoring_question_monitoring
   ON knowledge.monitoring_question(
      monitoring_id,
      trigger_type
   );

CREATE INDEX idx_monitoring_examination_monitoring
   ON knowledge.monitoring_examination(
      monitoring_id,
      trigger_type
   );

CREATE INDEX idx_monitoring_investigation_monitoring
   ON knowledge.monitoring_investigation(
      monitoring_id,
      trigger_type
   );


-- ============================================================================
-- 34. UNIVERSAL ACTIVE MONITORING VIEW
-- ============================================================================
-- Fast resolution surface for the clinical CPU.
-- ============================================================================

CREATE VIEW knowledge.active_monitoring AS
SELECT
   m.id,
   m.monitoring_code,
   m.canonical_name,
   m.display_name,
   m.description,
   m.target_type,
   m.measurement_domain,
   m.unit,
   m.body_system_code,
   m.normal_low,
   m.normal_high,
   m.directionality,
   m.status
FROM knowledge.monitoring m
WHERE m.status = 'active';

COMMENT ON VIEW knowledge.active_monitoring IS
'Active universal monitoring primitives available to the clinical reasoning CPU.';


-- ============================================================================
-- 35. UNIVERSAL ACTIVE EDUCATION VIEW
-- ============================================================================

CREATE VIEW knowledge.active_education AS
SELECT
   e.id,
   e.education_code,
   e.title,
   e.audience,
   e.content_type,
   e.language_code,
   e.literacy_level,
   e.title_short,
   e.body,
   e.clinical_purpose,
   e.version,
   e.status
FROM knowledge.education e
WHERE e.status = 'active';

COMMENT ON VIEW knowledge.active_education IS
'Active universal education nodes available to the clinical education engine.';


-- ============================================================================
-- 36. CLINICAL MONITORING RESOLUTION VIEW
-- ============================================================================
-- Provides the CPU with a compact target -> condition -> threshold surface.
-- ============================================================================

CREATE VIEW knowledge.monitoring_resolution AS
SELECT
   m.id                    AS monitoring_id,
   m.monitoring_code,
   m.canonical_name,

   mc.condition_id,
   c.condition_code,
   c.canonical_name        AS condition_name,

   mc.relevance,
   mc.weight               AS condition_weight,

   mt.id                   AS threshold_id,
   mt.threshold_code,
   mt.operator,
   mt.lower_value,
   mt.upper_value,
   mt.threshold_value,
   mt.severity,
   mt.interpretation,
   mt.clinical_significance

FROM knowledge.monitoring m

LEFT JOIN knowledge.monitoring_condition mc
   ON mc.monitoring_id = m.id

LEFT JOIN knowledge.condition c
   ON c.id = mc.condition_id

LEFT JOIN knowledge.monitoring_threshold mt
   ON mt.monitoring_id = m.id
  AND (
       mt.condition_id = mc.condition_id
       OR mt.condition_id IS NULL
  )

WHERE m.status = 'active';

COMMENT ON VIEW knowledge.monitoring_resolution IS
'Compact clinical CPU resolution surface connecting universal monitoring targets to applicable conditions and thresholds.';


-- ============================================================================
-- 37. EDUCATION RESOLUTION VIEW
-- ============================================================================

CREATE VIEW knowledge.education_resolution AS
SELECT
   e.id                    AS education_id,
   e.education_code,
   e.title,
   e.audience,
   e.content_type,
   e.language_code,
   e.literacy_level,

   ec.condition_id,
   c.condition_code,
   c.canonical_name        AS condition_name,

   et.trigger_type,
   et.trigger_code,
   et.priority,
   et.mandatory,

   e.body

FROM knowledge.education e

LEFT JOIN knowledge.education_condition ec
   ON ec.education_id = e.id

LEFT JOIN knowledge.condition c
   ON c.id = ec.condition_id

LEFT JOIN knowledge.education_trigger et
   ON et.education_id = e.id

WHERE e.status = 'active';

COMMENT ON VIEW knowledge.education_resolution IS
'Clinical education CPU surface resolving active education against conditions and clinical triggers.';


-- ============================================================================
-- 38. ARCHITECTURAL GUARANTEE
-- ============================================================================
-- The Phase 2 monitoring/education layer now follows:
--
--                  UNIVERSAL CONCEPT
--                         |
--          +--------------+--------------+
--          |              |              |
--      MONITORING     EDUCATION       CLINICAL GRAPH
--          |              |
--      +---+---+      +---+---+
--      |       |      |       |
--  TARGET    TREND  CONTEXT  TRIGGER
--      |       |      |       |
--  THRESHOLD  ALERT  LANGUAGE AUDIENCE
--      |       |              |
--      +---+---+              |
--          |                  |
--        ACTION            TEACH-BACK
--          |                  |
--   QUESTION / EXAM /     UNDERSTANDING
--   INVESTIGATION /       VERIFIED
--   MANAGEMENT
--
-- This deliberately prevents:
--
--   pneumonia_monitoring
--   pneumonia_education
--   asthma_monitoring
--   asthma_education
--
-- from becoming separate knowledge universes.
--
-- Instead:
--
--   SpO2
--   respiratory rate
--   heart rate
--   temperature
--   blood pressure
--   pain
--   GCS
--   urine output
--   work of breathing
--   etc.
--
-- are UNIVERSAL primitives.
--
-- Conditions, phenotypes, mechanisms, rules, contexts and protocols determine
-- how those primitives are interpreted and acted upon.
--
-- Education follows the same architecture:
--
--   UNIVERSAL EDUCATION NODE
--          ->
--   CONDITION / FACT / ALERT / MONITORING / CONTEXT
--          ->
--   AUDIENCE
--          ->
--   LANGUAGE
--          ->
--   LITERACY
--          ->
--   DELIVERY
--          ->
--   TEACH-BACK
--          ->
--   VERIFIED UNDERSTANDING
--
-- Therefore the clinical operating system can execute:
--
--   HISTORY
--      ->
--   EXAMINATION
--      ->
--   FACTS
--      ->
--   PHENOTYPES
--      ->
--   MECHANISMS
--      ->
--   DIFFERENTIALS
--      ->
--   INVESTIGATIONS
--      ->
--   DIAGNOSIS
--      ->
--   MANAGEMENT
--      ->
--   MONITORING
--      ->
--   TREND DETECTION
--      ->
--   ALERT
--      ->
--   REASSESSMENT
--      ->
--   ESCALATION
--      ->
--   EDUCATION
--      ->
--   TEACH-BACK
--      ->
--   FOLLOW-UP
--
-- without creating disease-specific engines.
-- =============================================================================