-- =============================================================================
-- AMEXAN Phase 2 — Migration 011: condition layer + knowledge graph
-- =============================================================================
-- Diseases/conditions reference symptoms, phenotypes, mechanisms, risk factors
-- and complications — they do NOT own isolated universes. The generalized
-- knowledge.relationship table is the relational skeleton of the clinical
-- knowledge graph.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 8. DISEASE/CONDITION LAYER
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   condition_code    text NOT NULL UNIQUE,      -- e.g. PNEUMONIA
   canonical_name    text NOT NULL,
   description       text,
   condition_type    text,                      -- acute / chronic / infectious / non_infectious / congenital / traumatic
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.condition IS 'A disease/condition as a node that references shared knowledge.';

CREATE TRIGGER trg_knowledge_condition_updated_at
   BEFORE UPDATE ON knowledge.condition
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.condition_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id  uuid REFERENCES knowledge.context_value(id),
   applicability     text NOT NULL DEFAULT 'applies' CHECK (applicability IN ('applies','excludes')),
   risk_weight       numeric(3,2) NOT NULL DEFAULT 1.0
);
COMMENT ON TABLE knowledge.condition_context IS 'Contexts in which a condition is more/less likely.';

CREATE TABLE knowledge.condition_system (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   body_system_code  text NOT NULL REFERENCES knowledge.body_system(code),
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (condition_id, body_system_code)
);
COMMENT ON TABLE knowledge.condition_system IS 'Body systems a condition affects.';

CREATE TABLE knowledge.condition_specialty (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   specialty_code    text NOT NULL REFERENCES organization.specialty(code),
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (condition_id, specialty_code)
);
COMMENT ON TABLE knowledge.condition_specialty IS 'Specialties that manage a condition.';

CREATE TABLE knowledge.condition_risk_factor (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   risk_factor_concept_id uuid REFERENCES knowledge.concept(id),
   risk_factor_code  text NOT NULL,             -- e.g. SMOKING / IMMUNOCOMPROMISED / TB_EXPOSURE
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   description       text,
   UNIQUE (condition_id, risk_factor_code)
);
COMMENT ON TABLE knowledge.condition_risk_factor IS 'Risk factors for a condition.';

CREATE TABLE knowledge.condition_complication (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   complication_concept_id uuid REFERENCES knowledge.concept(id),
   complication_code  text NOT NULL,            -- e.g. RESPIRATORY_FAILURE
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   description       text,
   UNIQUE (condition_id, complication_code)
);
COMMENT ON TABLE knowledge.condition_complication IS 'Complications of a condition.';

CREATE TABLE knowledge.condition_differential (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   differential_condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   relationship_type text NOT NULL DEFAULT 'mimics',   -- mimics / overlaps / excludes / must_rule_out
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   CHECK (condition_id <> differential_condition_id),
   UNIQUE (condition_id, differential_condition_id, relationship_type)
);
COMMENT ON TABLE knowledge.condition_differential IS 'Conditions to consider alongside / against a condition.';

-- ---------------------------------------------------------------------------
-- 9. CROSS-LAYER JUNCTIONS (created now that all base tables exist)
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_phenotype (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (mechanism_id, phenotype_id)
);
COMMENT ON TABLE knowledge.mechanism_phenotype IS 'Mechanism <-> phenotype association.';

CREATE TABLE knowledge.mechanism_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (mechanism_id, condition_id)
);
COMMENT ON TABLE knowledge.mechanism_condition IS 'Mechanism <-> condition association.';

CREATE TABLE knowledge.mechanism_investigation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   investigation_concept_id uuid REFERENCES knowledge.concept(id),
   investigation_code text NOT NULL,            -- e.g. INV-CXR
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   rationale         text,
   UNIQUE (mechanism_id, investigation_code)
);
COMMENT ON TABLE knowledge.mechanism_investigation IS 'Investigations suggested by a mechanism.';

CREATE TABLE knowledge.mechanism_management (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   management_concept_id uuid REFERENCES knowledge.concept(id),
   management_code   text NOT NULL,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   rationale         text,
   UNIQUE (mechanism_id, management_code)
);
COMMENT ON TABLE knowledge.mechanism_management IS 'Management actions suggested by a mechanism.';

CREATE TABLE knowledge.phenotype_differential (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   relationship_type text NOT NULL DEFAULT 'suggestive_of',
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (phenotype_id, condition_id, relationship_type)
);
COMMENT ON TABLE knowledge.phenotype_differential IS 'Which conditions a phenotype points to.';

CREATE TABLE knowledge.phenotype_mechanism (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (phenotype_id, mechanism_id)
);
COMMENT ON TABLE knowledge.phenotype_mechanism IS 'Phenotype <-> mechanism association.';

CREATE TABLE knowledge.condition_phenotype (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   phenotype_id      uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   is_suggestive     boolean NOT NULL DEFAULT true,
   UNIQUE (condition_id, phenotype_id)
);
COMMENT ON TABLE knowledge.condition_phenotype IS 'Phenotypes a condition expresses. Pneumonia and TB can share phenotypes with different weights.';

CREATE TABLE knowledge.condition_mechanism (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   mechanism_id      uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (condition_id, mechanism_id)
);
COMMENT ON TABLE knowledge.condition_mechanism IS 'Mechanisms a condition works through.';

-- ---------------------------------------------------------------------------
-- 10. GENERALIZED RELATIONSHIP — the relational skeleton of the knowledge graph
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   source_type       text NOT NULL,             -- concept / symptom / question / answer / fact / phenotype / mechanism / condition
   source_id         uuid NOT NULL,
   relationship_type text NOT NULL,             -- supports / contradicts / requires / triggers / occurs_in / caused_by / associated_with / produces / asks / treats / investigates
   target_type       text NOT NULL,
   target_id         uuid NOT NULL,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   polarity          text NOT NULL DEFAULT 'positive' CHECK (polarity IN ('positive','negative')),
   context           jsonb,
   confidence        numeric(4,3) CHECK (confidence >= 0 AND confidence <= 1),
   evidence          text,
   version           text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (source_type, source_id, relationship_type, target_type, target_id, context, polarity)
);
COMMENT ON TABLE knowledge.relationship IS 'Generalized typed edges between any knowledge nodes — the clinical knowledge graph.';

CREATE INDEX idx_knowledge_relationship_source ON knowledge.relationship(source_type, source_id);
CREATE INDEX idx_knowledge_relationship_target ON knowledge.relationship(target_type, target_id);
CREATE INDEX idx_knowledge_relationship_type ON knowledge.relationship(relationship_type);

CREATE TRIGGER trg_knowledge_relationship_updated_at
   BEFORE UPDATE ON knowledge.relationship
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
