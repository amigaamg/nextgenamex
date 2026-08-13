-- =============================================================================
-- AMEXAN Phase 2 — Migration 010: mechanisms + phenotype library
-- =============================================================================
-- Mechanisms and phenotypes are reusable patterns of facts. Diseases reference
-- these; they are never rebuilt per disease.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 6. MECHANISMS — reusable pathophysiological patterns
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   mechanism_code    text NOT NULL UNIQUE,      -- e.g. MECH-AIRWAY-INFLAMMATION
   canonical_name    text NOT NULL,
   description       text,
   body_system_code  text REFERENCES knowledge.body_system(code),
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.mechanism IS 'Pathophysiological mechanism reusable across hundreds of conditions.';

CREATE TRIGGER trg_knowledge_mechanism_updated_at
   BEFORE UPDATE ON knowledge.mechanism
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.mechanism_feature (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   feature_type      text NOT NULL,             -- fact / symptom / sign
   feature_code      text NOT NULL,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   polarity          text NOT NULL DEFAULT 'positive' CHECK (polarity IN ('positive','negative')),
   UNIQUE (mechanism_id, feature_type, feature_code, polarity)
);
COMMENT ON TABLE knowledge.mechanism_feature IS 'Facts/symptoms that support or contradict a mechanism.';

CREATE INDEX idx_knowledge_mechanism_feature ON knowledge.mechanism_feature(mechanism_id);

-- ---------------------------------------------------------------------------
-- 7. PHENOTYPE LIBRARY — patterns of facts
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   phenotype_code    text NOT NULL UNIQUE,      -- e.g. PHEN-PRODUCTIVE-LRTI
   canonical_name    text NOT NULL,
   description       text,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.phenotype IS 'A reusable pattern of facts with weights and contradictions.';

CREATE TRIGGER trg_knowledge_phenotype_updated_at
   BEFORE UPDATE ON knowledge.phenotype
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.phenotype_feature (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   feature_type      text NOT NULL,             -- fact / symptom / sign / measurement
   feature_code      text NOT NULL,             -- e.g. COUGH.PRODUCTIVITY / FEVER
   operator          text NOT NULL DEFAULT 'eq',
   value             jsonb,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,  -- +++ / ++ / +
   polarity          text NOT NULL DEFAULT 'positive' CHECK (polarity IN ('positive','negative')), -- negative = contradicts
   UNIQUE (phenotype_id, feature_type, feature_code, operator, polarity)
);
COMMENT ON TABLE knowledge.phenotype_feature IS 'Facts that support (positive weight) or contradict (negative polarity) a phenotype.';

CREATE INDEX idx_knowledge_phenotype_feature ON knowledge.phenotype_feature(phenotype_id);
CREATE INDEX idx_knowledge_phenotype_feature_code ON knowledge.phenotype_feature(feature_code);

CREATE TABLE knowledge.phenotype_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id  uuid REFERENCES knowledge.context_value(id),
   applicability     text NOT NULL DEFAULT 'applies' CHECK (applicability IN ('applies','excludes')),
   UNIQUE (phenotype_id, context_type_code, context_value_id)
);
COMMENT ON TABLE knowledge.phenotype_context IS 'Contexts in which a phenotype pattern applies.';

CREATE TABLE knowledge.phenotype_relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   related_phenotype_id uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   relationship_type text NOT NULL,             -- overlaps / extends / excludes / differentiates
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   CHECK (phenotype_id <> related_phenotype_id),
   UNIQUE (phenotype_id, related_phenotype_id, relationship_type)
);
COMMENT ON TABLE knowledge.phenotype_relationship IS 'Relationships between phenotypes.';

CREATE TABLE knowledge.phenotype_documentation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   documentation_phrase text NOT NULL,
   language_code     text,
   is_preferred      boolean NOT NULL DEFAULT false,
   UNIQUE (phenotype_id, documentation_phrase, language_code)
);
COMMENT ON TABLE knowledge.phenotype_documentation IS 'Phrases that render a phenotype into documentation.';
