-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 015: monitoring + education primitives
-- =============================================================================
-- Monitoring targets (SpO2, RR, HR, temp, work of breathing) prove the system
-- does not stop at diagnosis: baseline -> measurement -> trend -> deviation ->
-- alert -> clinical reassessment. Patient education is a reusable content node
-- bound to conditions so every plan can surface teach-back material.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- MONITORING â€” reusable physiological trajectory targets
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.monitoring (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   monitoring_code   text NOT NULL UNIQUE,       -- e.g. MON-SPO2
   canonical_name    text NOT NULL,
   description       text,
   target_type       text NOT NULL DEFAULT 'numeric'
                     CHECK (target_type IN ('numeric','coded','boolean','trend')),
   unit              text,                        -- % / breaths/min / degC / beats/min
   body_system_code  text REFERENCES knowledge.body_system(code),
   normal_low        numeric,
   normal_high       numeric,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.monitoring IS
   'Reusable monitoring targets. A protocol links targets to timing, deterioration rules and escalation.';

CREATE INDEX idx_knowledge_monitoring_concept ON knowledge.monitoring(concept_id);

CREATE TRIGGER trg_knowledge_monitoring_updated_at
   BEFORE UPDATE ON knowledge.monitoring
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.monitoring_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   monitoring_id     uuid NOT NULL REFERENCES knowledge.monitoring(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   rationale         text,
   UNIQUE (monitoring_id, condition_id)
);
COMMENT ON TABLE knowledge.monitoring_condition IS 'Monitoring targets relevant to a condition.';

-- ---------------------------------------------------------------------------
-- EDUCATION â€” reusable, condition-bound patient/clinician content
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.education (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   education_code    text NOT NULL UNIQUE,       -- e.g. EDU-CAP-DANGER-SIGNS
   title             text NOT NULL,
   audience          text NOT NULL DEFAULT 'patient'
                     CHECK (audience IN ('patient','caregiver','clinician','community')),
   content_type      text NOT NULL DEFAULT 'explanation'
                     CHECK (content_type IN ('explanation','warning','instruction','teach_back','discharge')),
   language_code     text NOT NULL DEFAULT 'en',
   literacy_level    text,                        -- plain / professional
   body              text NOT NULL,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.education IS 'Reusable education content bound to conditions/plans.';

CREATE INDEX idx_knowledge_education_concept ON knowledge.education(concept_id);

CREATE TRIGGER trg_knowledge_education_updated_at
   BEFORE UPDATE ON knowledge.education
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.education_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   education_id      uuid NOT NULL REFERENCES knowledge.education(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (education_id, condition_id)
);
COMMENT ON TABLE knowledge.education_condition IS 'Education content delivered when a condition is active.';
