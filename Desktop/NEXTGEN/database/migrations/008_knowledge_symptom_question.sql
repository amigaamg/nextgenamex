-- =============================================================================
-- AMEXAN Phase 2 — Migration 008: symptom library + question engine
-- =============================================================================
-- Symptoms are rich nodes (not strings), and questions are DATA (not hard-coded
-- UI). Answers map to clinical facts so the CPU reasons over medical truth.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 3. SYMPTOM LIBRARY
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.symptom (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid NOT NULL REFERENCES knowledge.concept(id),
   symptom_code      text NOT NULL UNIQUE,      -- e.g. SYM-COUGH
   canonical_name    text NOT NULL,
   definition        text,
   is_emergency      boolean NOT NULL DEFAULT false,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.symptom IS 'The universal symptom registry. A symptom is a rich node, not a string.';

CREATE INDEX idx_knowledge_symptom_concept ON knowledge.symptom(concept_id);
CREATE TRIGGER trg_knowledge_symptom_updated_at
   BEFORE UPDATE ON knowledge.symptom
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.symptom_synonym (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   synonym           text NOT NULL,
   language_code     text,
   is_preferred      boolean NOT NULL DEFAULT false,
   UNIQUE (symptom_id, synonym)
);
COMMENT ON TABLE knowledge.symptom_synonym IS 'Alternate names including lay terms.';

CREATE TABLE knowledge.symptom_translation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   language_code     text NOT NULL,
   translation       text NOT NULL,
   is_preferred      boolean NOT NULL DEFAULT false,
   UNIQUE (symptom_id, language_code, translation)
);
COMMENT ON TABLE knowledge.symptom_translation IS 'Translations of a symptom.';

CREATE TABLE knowledge.symptom_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id  uuid REFERENCES knowledge.context_value(id),
   relevance         numeric(3,2) NOT NULL DEFAULT 1.0,   -- how relevant the symptom is in this context
   description       text,
   UNIQUE (symptom_id, context_type_code, context_value_id)
);
COMMENT ON TABLE knowledge.symptom_context IS 'How a symptom behaves differently across contexts (2-month vs 80-year-old).';

CREATE TABLE knowledge.symptom_system (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   body_system_code  text NOT NULL REFERENCES knowledge.body_system(code),
   relevance         numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (symptom_id, body_system_code)
);
COMMENT ON TABLE knowledge.symptom_system IS 'A symptom belongs to MANY body systems (cough: respiratory, cardiovascular, GI...). The CPU decides relevance.';

CREATE TABLE knowledge.symptom_specialty (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   specialty_code    text NOT NULL REFERENCES organization.specialty(code),
   relevance         numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (symptom_id, specialty_code)
);
COMMENT ON TABLE knowledge.symptom_specialty IS 'A symptom belongs to MANY specialties. No primary_department hardcoding.';

CREATE TABLE knowledge.symptom_relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   related_symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   relationship_type text NOT NULL,             -- associated_with / precedes / aggravates / mimics / differentiates
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   polarity          text NOT NULL DEFAULT 'positive' CHECK (polarity IN ('positive','negative')),
   CHECK (symptom_id <> related_symptom_id),
   UNIQUE (symptom_id, related_symptom_id, relationship_type)
);
COMMENT ON TABLE knowledge.symptom_relationship IS 'Typed relationships between symptoms.';

CREATE TABLE knowledge.symptom_red_flag (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   red_flag_code     text NOT NULL,             -- e.g. RF-HAEMOPTYSIS
   description       text NOT NULL,
   urgency           text NOT NULL DEFAULT 'urgent' CHECK (urgency IN ('emergency','urgent','routine')),
   evidence          text,
   UNIQUE (symptom_id, red_flag_code)
);
COMMENT ON TABLE knowledge.symptom_red_flag IS 'Emergency/urgent associations of a symptom.';

CREATE TABLE knowledge.symptom_documentation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
   documentation_phrase text NOT NULL,
   language_code     text,
   context_code      text,
   is_preferred      boolean NOT NULL DEFAULT false,
   UNIQUE (symptom_id, documentation_phrase, language_code)
);
COMMENT ON TABLE knowledge.symptom_documentation IS 'Phrases used to render this symptom into documentation.';

-- ---------------------------------------------------------------------------
-- 4. QUESTION ENGINE — questions are DATA
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.question (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   question_code     text NOT NULL UNIQUE,      -- e.g. COUGH_PRODUCTIVITY
   concept_id        uuid REFERENCES knowledge.concept(id),
   question_type     text NOT NULL DEFAULT 'clinical' CHECK (question_type IN ('clinical','risk','screening','follow_up')),
   text              text NOT NULL,
   response_type     text NOT NULL DEFAULT 'single_choice'
                     CHECK (response_type IN ('single_choice','multiple_choice','boolean','numeric','text','date')),
   priority          integer NOT NULL DEFAULT 50,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.question IS 'A question used to acquire a clinical fact.';

CREATE INDEX idx_knowledge_question_concept ON knowledge.question(concept_id);
CREATE TRIGGER trg_knowledge_question_updated_at
   BEFORE UPDATE ON knowledge.question
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.answer_option (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   question_id       uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
   answer_code       text NOT NULL,             -- PRODUCTIVE / NON_PRODUCTIVE / UNKNOWN
   label             text NOT NULL,             -- UI label: Yes / No / Unable to determine
   value_text        text,
   sort_order        integer NOT NULL DEFAULT 0,
   is_active         boolean NOT NULL DEFAULT true,
   UNIQUE (question_id, answer_code)
);
COMMENT ON TABLE knowledge.answer_option IS 'Structured answers. UI labels are presentation; answer_code is medical truth.';

CREATE INDEX idx_answer_option_question ON knowledge.answer_option(question_id);

CREATE TABLE knowledge.fact_mapping (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   answer_option_id  uuid NOT NULL REFERENCES knowledge.answer_option(id) ON DELETE CASCADE,
   fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
   value              text NOT NULL,             -- mapped fact value, e.g. PRODUCTIVE
   is_active          boolean NOT NULL DEFAULT true,
   UNIQUE (answer_option_id, fact_definition_code)
);
COMMENT ON TABLE knowledge.fact_mapping IS 'Answer -> Fact. The CPU reasons over facts (PRODUCTIVE_COUGH), never over "Yes".';

CREATE TABLE knowledge.question_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   question_id       uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id  uuid REFERENCES knowledge.context_value(id),
   applicability     text NOT NULL DEFAULT 'applies' CHECK (applicability IN ('applies','excludes')),
   priority          integer NOT NULL DEFAULT 0,
   UNIQUE (question_id, context_type_code, context_value_id)
);
COMMENT ON TABLE knowledge.question_context IS 'Determines when a question applies in a given context.';

CREATE TABLE knowledge.question_trigger (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   question_id       uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
   trigger_type      text NOT NULL,             -- symptom / phenotype / risk_factor / mechanism / condition / complication / context / fact
   trigger_concept_id uuid REFERENCES knowledge.concept(id),
   trigger_code      text NOT NULL,             -- e.g. cough / TB / hypoxaemia
   condition         jsonb,                     -- optional additional conditions for activation
   priority          integer NOT NULL DEFAULT 0,
   UNIQUE (question_id, trigger_type, trigger_code)
);
COMMENT ON TABLE knowledge.question_trigger IS 'A question may be activated by a symptom, phenotype, risk factor, mechanism, disease consideration or complication.';

CREATE INDEX idx_knowledge_question_trigger ON knowledge.question_trigger(trigger_type, trigger_code);

CREATE TABLE knowledge.question_requirement (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   question_id       uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
   requirement_level text NOT NULL CHECK (requirement_level IN ('mandatory','conditionally_required','optional','informational')),
   condition         jsonb,                     -- when the requirement applies
   priority          integer NOT NULL DEFAULT 0,
   UNIQUE (question_id, requirement_level, condition)
);
COMMENT ON TABLE knowledge.question_requirement IS 'Mandatory / conditional / optional / informational, enabling HPI completeness scoring.';
