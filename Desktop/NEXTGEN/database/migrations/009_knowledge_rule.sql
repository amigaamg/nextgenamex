-- =============================================================================
-- AMEXAN Phase 2 — Migration 009: rule engine substrate
-- =============================================================================
-- Reusable, composable, versioned clinical rules with full provenance so the
-- system can always answer "why did you ask this?" and "why this recommendation?"
-- =============================================================================

CREATE TABLE knowledge.rule (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_code         text NOT NULL UNIQUE,
   name              text NOT NULL,
   description       text,
   rule_type         text NOT NULL DEFAULT 'clinical' CHECK (rule_type IN ('clinical','activation','safety','differential','investigation')),
   status            text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','retired')),
   priority          integer NOT NULL DEFAULT 50,
   evidence_level    text,                      -- A1 / B2 / C / expert_opinion / local
   guideline         text,
   guideline_version text,
   effective_from    date,
   effective_to      date,
   author            text,
   reviewer          text,
   approval_status   text NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending','approved','rejected')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.rule IS 'Reusable clinical rule with full provenance.';

CREATE TRIGGER trg_knowledge_rule_updated_at
   BEFORE UPDATE ON knowledge.rule
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.rule_version (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   version           integer NOT NULL,
   body              jsonb,                     -- machine-evaluable rule expression
   is_active         boolean NOT NULL DEFAULT false,
   changed_at        timestamptz NOT NULL DEFAULT now(),
   changed_by        text,
   UNIQUE (rule_id, version)
);
COMMENT ON TABLE knowledge.rule_version IS 'Versioned bodies of a rule.';

CREATE TABLE knowledge.rule_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   condition_group   integer NOT NULL DEFAULT 1, -- AND-groups; conditions within a group are OR-ed
   condition_order   integer NOT NULL DEFAULT 0,
   entity_type       text NOT NULL,             -- fact / symptom / context / concept / measurement
   entity_code       text NOT NULL,             -- e.g. COUGH.PRODUCTIVITY / AGE / FEVER
   operator          text NOT NULL,             -- eq / neq / gt / gte / lt / lte / in / contains / exists / not_exists
   value             jsonb,
   is_not            boolean NOT NULL DEFAULT false,
   UNIQUE (rule_id, condition_group, condition_order)
);
COMMENT ON TABLE knowledge.rule_condition IS 'Composable rule conditions.';

CREATE INDEX idx_knowledge_rule_condition ON knowledge.rule_condition(rule_id);

CREATE TABLE knowledge.rule_action (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   action_order      integer NOT NULL DEFAULT 0,
   action_type       text NOT NULL,             -- activate_question / activate_phenotype / set_fact / raise_red_flag / recommend_investigation / recommend_management / set_priority
   action_entity_type text,
   action_code       text,
   action_concept_id uuid REFERENCES knowledge.concept(id),
   params            jsonb,
   UNIQUE (rule_id, action_order)
);
COMMENT ON TABLE knowledge.rule_action IS 'What a rule does when its conditions hold.';

CREATE INDEX idx_knowledge_rule_action ON knowledge.rule_action(rule_id);

CREATE TABLE knowledge.rule_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id  uuid REFERENCES knowledge.context_value(id),
   applicability     text NOT NULL DEFAULT 'applies' CHECK (applicability IN ('applies','excludes')),
   UNIQUE (rule_id, context_type_code, context_value_id)
);
COMMENT ON TABLE knowledge.rule_context IS 'Contexts in which a rule applies.';

CREATE TABLE knowledge.rule_priority (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   priority_score    integer NOT NULL DEFAULT 0,
   basis             text,
   description       text
);
COMMENT ON TABLE knowledge.rule_priority IS 'Priority metadata for a rule.';

CREATE TABLE knowledge.rule_source (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   source_type       text NOT NULL,             -- guideline / literature / expert / local / facility
   source_ref        text,
   citation          text,
   url               text,
   evidence_level    text,
   UNIQUE (rule_id, source_type, source_ref)
);
COMMENT ON TABLE knowledge.rule_source IS 'Provenance of a rule.';

CREATE TABLE knowledge.context_rule (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   rule_id           uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id  uuid REFERENCES knowledge.context_value(id),
   applicability     text NOT NULL DEFAULT 'required' CHECK (applicability IN ('required','optional','excluded')),
   description       text
);
COMMENT ON TABLE knowledge.context_rule IS 'Associates a rule with the contexts in which it applies.';
