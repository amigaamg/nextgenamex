-- =============================================================================
-- AMEXAN Phase 2 — Migration 007: knowledge substrate (concept + context)
-- =============================================================================
-- Phase 1 gave the database memory. Phase 2 gives it medical meaning.
-- Architecture rule: universal primitives and relationships built ONCE, then
-- composed into diseases, departments, ages, services and protocols. There is
-- NO pneumonia engine, NO diabetes engine — only knowledge loaded into a
-- universal machine.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;
COMMENT ON SCHEMA knowledge IS 'Universal clinical knowledge: concepts, contexts, symptoms, questions, rules, phenotypes, mechanisms, conditions.';

-- ---------------------------------------------------------------------------
-- 1. UNIVERSAL CONCEPT — the atomic vocabulary
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.concept (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_code      text NOT NULL UNIQUE,      -- stable AMEXAN code, e.g. CNS-COUGH
   concept_type      text NOT NULL,             -- symptom / sign / finding / fact / risk_factor / mechanism / phenotype / condition / investigation / medication / complication / body_system
   canonical_name    text NOT NULL,
   display_name      text,
   description       text,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   version           text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.concept IS 'Universal atomic medical vocabulary. Every other knowledge object references it.';

CREATE INDEX idx_knowledge_concept_type ON knowledge.concept(concept_type);
CREATE INDEX idx_knowledge_concept_name ON knowledge.concept(canonical_name);
CREATE TRIGGER trg_knowledge_concept_updated_at
   BEFORE UPDATE ON knowledge.concept
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. UNIVERSAL CONTEXT
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.context_type (
   code              text PRIMARY KEY,          -- AGE / SEX / PREGNANCY / GESTATIONAL_AGE / BODY_SYSTEM / SPECIALTY / DEPARTMENT / CARE_SETTING / ACUITY / COMORBIDITY / IMMUNOCOMPROMISED_STATUS / GEOGRAPHY / SEASON / ...
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE knowledge.context_type IS 'A dimension of clinical context.';

CREATE TABLE knowledge.context_value (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   value             text NOT NULL,             -- AGE: 0-28D / 1-11M / 1-4Y / 5-17Y / 18-64Y / 65+; SEX: male/female
   label             text,
   sort_order        integer NOT NULL DEFAULT 0,
   UNIQUE (context_type_code, value)
);
COMMENT ON TABLE knowledge.context_value IS 'Allowed values within a context type.';

CREATE INDEX idx_context_value_type ON knowledge.context_value(context_type_code);

CREATE TABLE knowledge.body_system (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE knowledge.body_system IS 'Body systems used to attach symptoms/conditions to systems.';

CREATE TABLE knowledge.context_relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   source_value_id   uuid NOT NULL REFERENCES knowledge.context_value(id),
   target_value_id   uuid NOT NULL REFERENCES knowledge.context_value(id),
   relationship      text NOT NULL,             -- implies / conflicts_with / overlaps
   description       text,
   UNIQUE (context_type_code, source_value_id, target_value_id, relationship)
);
COMMENT ON TABLE knowledge.context_relationship IS 'Relationships between context values (pregnancy implies sex=female).';
