-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 017: protocol / care-pathway primitives
-- =============================================================================
-- Clinical protocols are first-class action plans. A protocol is composed of
-- ordered steps (eligibility, red flags, assessment, investigation, treatment,
-- monitoring, escalation, disposition, education, follow-up). Actions reference
-- the reusable investigation / medication / monitoring / education objects by
-- code â€” the protocol coordinates, it never re-defines medicine.
-- =============================================================================

CREATE TABLE knowledge.protocol (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   protocol_code     text NOT NULL UNIQUE,       -- e.g. PROT-CAP-ADULT
   canonical_name    text NOT NULL,
   version_label     text,
   description       text,
   specialty_code    text REFERENCES organization.specialty(code),
   purpose           text,                        -- initial_workup / management / escalation / diagnostic
   status            text NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','approved','superseded','retired')),
   is_guideline      boolean NOT NULL DEFAULT false,
   source_reference  text,
   configurable      boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.protocol IS 'A clinical protocol / care pathway. Default knowledge; facilities override via knowledge_override.';

CREATE INDEX idx_knowledge_protocol_concept ON knowledge.protocol(concept_id);
CREATE INDEX idx_knowledge_protocol_specialty ON knowledge.protocol(specialty_code);

CREATE TRIGGER trg_knowledge_protocol_updated_at
   BEFORE UPDATE ON knowledge.protocol
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.protocol_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   protocol_id       uuid NOT NULL REFERENCES knowledge.protocol(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   is_primary        boolean NOT NULL DEFAULT true,
   UNIQUE (protocol_id, condition_id)
);
COMMENT ON TABLE knowledge.protocol_condition IS 'Conditions a protocol addresses.';

CREATE TABLE knowledge.protocol_step (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   protocol_id       uuid NOT NULL REFERENCES knowledge.protocol(id) ON DELETE CASCADE,
   step_code         text NOT NULL,               -- e.g. STEP-01
   step_label        text NOT NULL,
   step_type         text NOT NULL CHECK (step_type IN
                     ('eligibility','assessment','red_flag','investigation','diagnosis',
                      'treatment','monitoring','escalation','disposition','education','follow_up')),
   sequence_no       integer NOT NULL DEFAULT 0,
   instruction       text NOT NULL,
   rationale         text,
   required          boolean NOT NULL DEFAULT false,
   decision_rule     jsonb,                       -- machine-evaluable gate (fact conditions)
   UNIQUE (protocol_id, step_code)
);
COMMENT ON TABLE knowledge.protocol_step IS 'An ordered decision/action node within a protocol.';

CREATE INDEX idx_knowledge_protocol_step_protocol ON knowledge.protocol_step(protocol_id, sequence_no);

CREATE TABLE knowledge.protocol_action (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   protocol_id       uuid NOT NULL REFERENCES knowledge.protocol(id) ON DELETE CASCADE,
   step_id           uuid NOT NULL REFERENCES knowledge.protocol_step(id) ON DELETE CASCADE,
   action_type       text NOT NULL CHECK (action_type IN
                     ('investigate','medicate','monitor','educate','refer','admit','advice','order_set')),
   action_code       text NOT NULL,               -- INV-CXR / MED-AMOXICILLIN / MON-SPO2 / EDU-CAP-DANGER / ...
   action_name       text NOT NULL,
   detail            text,                        -- dose / frequency / timing / target
   urgency           text NOT NULL DEFAULT 'routine' CHECK (urgency IN ('immediate','urgent','routine')),
   sort_order        integer NOT NULL DEFAULT 0,
   UNIQUE (step_id, action_type, action_code)
);
COMMENT ON TABLE knowledge.protocol_action IS 'Concrete actions emitted when a protocol step fires. Referenced object by action_code.';

CREATE INDEX idx_knowledge_protocol_action_step ON knowledge.protocol_action(step_id);

CREATE TABLE knowledge.protocol_monitoring (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   protocol_id       uuid NOT NULL REFERENCES knowledge.protocol(id) ON DELETE CASCADE,
   monitoring_id     uuid NOT NULL REFERENCES knowledge.monitoring(id) ON DELETE CASCADE,
   frequency         text,                        -- e.g. 4-hourly
   deterioration_rule text,
   escalation_instruction text,
   UNIQUE (protocol_id, monitoring_id)
);
COMMENT ON TABLE knowledge.protocol_monitoring IS 'Monitoring touchpoints a protocol mandates.';
