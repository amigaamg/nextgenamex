-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 012: universal concept junctions
-- =============================================================================
-- UNIVERSAL CLINICAL OPERATING SYSTEM
--
-- Architectural law:
--
--   ONE CONCEPT
--       â†“
--   MANY BODY SYSTEMS
--   MANY SPECIALTIES
--   MANY CONTEXTS
--   MANY POPULATIONS
--   MANY CARE SETTINGS
--   MANY GEOGRAPHIES
--   MANY CLINICAL ROLES
--   MANY RELATIONSHIPS
--
-- Nothing is duplicated merely because its clinical relevance changes.
--
-- A concept such as COUGH, FEVER, ANAEMIA, HYPOTENSION, PREGNANCY,
-- RENAL FAILURE, SEPSIS, ECG, CREATININE, AMOXICILLIN, etc. exists ONCE.
--
-- Clinical meaning is generated through relationships and context.
--
-- This migration therefore provides the universal attachment layer from
-- knowledge.concept to the rest of the AMEXAN clinical universe.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 0. HARDEN UNIVERSAL VOCABULARY
-- =============================================================================

DO $$
BEGIN
   IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'chk_knowledge_concept_type'
   ) THEN
      ALTER TABLE knowledge.concept
         ADD CONSTRAINT chk_knowledge_concept_type
         CHECK (
            concept_type IN (
               'symptom',
               'sign',
               'finding',
               'fact',
               'risk_factor',
               'mechanism',
               'phenotype',
               'condition',
               'investigation',
               'medication',
               'complication',
               'body_system'
            )
         );
   END IF;
END
$$;


DO $$
BEGIN
   IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'chk_knowledge_concept_status'
   ) THEN
      ALTER TABLE knowledge.concept
         ADD CONSTRAINT chk_knowledge_concept_status
         CHECK (status IN ('active','deprecated'));
   END IF;
END
$$;


-- =============================================================================
-- 1. CONCEPT â†’ BODY SYSTEM
-- =============================================================================
-- Universal replacement/extension of symptom_system and condition_system.
--
-- Example:
--
-- COUGH
--   respiratory     primary
--   ENT             secondary
--   cardiovascular  possible
--   gastrointestinal related
--
-- No second "cardiac cough" concept is created.
-- =============================================================================

CREATE TABLE knowledge.concept_system (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   body_system_code  text NOT NULL
                     REFERENCES knowledge.body_system(code),

   relevance          text NOT NULL DEFAULT 'related'
                     CHECK (
                        relevance IN (
                           'primary',
                           'secondary',
                           'cross_system',
                           'related'
                        )
                     ),

   weight             numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (weight >= 0 AND weight <= 1),

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (concept_id, body_system_code)
);

COMMENT ON TABLE knowledge.concept_system IS
'Universal concept-to-body-system attachment. One concept may belong to multiple systems without duplication.';

CREATE INDEX idx_concept_system_concept
   ON knowledge.concept_system(concept_id);

CREATE INDEX idx_concept_system_body
   ON knowledge.concept_system(body_system_code);

CREATE INDEX idx_concept_system_relevance
   ON knowledge.concept_system(relevance);

CREATE TRIGGER trg_concept_system_updated_at
   BEFORE UPDATE ON knowledge.concept_system
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 2. CONCEPT â†’ SPECIALTY / DEPARTMENT
-- =============================================================================
-- A clinical concept may be relevant to medicine, surgery, paediatrics,
-- obstetrics, emergency medicine, psychiatry, ENT, dermatology, etc.
--
-- Specialty is a routing/context relationship, NOT ownership.
-- =============================================================================

CREATE TABLE knowledge.concept_specialty (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   specialty_code    text NOT NULL
                     REFERENCES organization.specialty(code),

   relevance          text NOT NULL DEFAULT 'possible'
                     CHECK (
                        relevance IN (
                           'primary',
                           'secondary',
                           'possible',
                           'related'
                        )
                     ),

   weight             numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (weight >= 0 AND weight <= 1),

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (concept_id, specialty_code)
);

COMMENT ON TABLE knowledge.concept_specialty IS
'Universal concept-to-specialty attachment. Concepts are shared across departments rather than duplicated.';

CREATE INDEX idx_concept_specialty_concept
   ON knowledge.concept_specialty(concept_id);

CREATE INDEX idx_concept_specialty_specialty
   ON knowledge.concept_specialty(specialty_code);

CREATE INDEX idx_concept_specialty_relevance
   ON knowledge.concept_specialty(relevance);

CREATE TRIGGER trg_concept_specialty_updated_at
   BEFORE UPDATE ON knowledge.concept_specialty
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. CONCEPT â†’ CLINICAL CONTEXT
-- =============================================================================
-- Universal context attachment.
--
-- Examples:
--
-- COUGH â†’ AGE â†’ infant
-- COUGH â†’ AGE â†’ adult
-- COUGH â†’ PREGNANCY â†’ pregnant
-- COUGH â†’ CARE_SETTING â†’ emergency
-- COUGH â†’ ACUITY â†’ acute
-- COUGH â†’ GEOGRAPHY â†’ TB_endemic
--
-- The concept itself never changes.
-- Context changes its relevance.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.concept_context CASCADE;
CREATE TABLE knowledge.concept_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   context_type_code text NOT NULL
                     REFERENCES knowledge.context_type(code),

   context_value_id  uuid
                     REFERENCES knowledge.context_value(id)
                     ON DELETE CASCADE,

   applicability     text NOT NULL DEFAULT 'applies'
                     CHECK (
                        applicability IN (
                           'applies',
                           'excludes',
                           'conditional'
                        )
                     ),

   relevance          numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (relevance >= 0 AND relevance <= 1),

   priority           integer NOT NULL DEFAULT 0,

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      concept_id,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.concept_context IS
'Universal contextual attachment of concepts to age, sex, pregnancy, acuity, geography, specialty, care setting and other dimensions.';

CREATE INDEX idx_concept_context_concept
   ON knowledge.concept_context(concept_id);

CREATE INDEX idx_concept_context_type
   ON knowledge.concept_context(context_type_code);

CREATE INDEX idx_concept_context_value
   ON knowledge.concept_context(context_value_id);

CREATE INDEX idx_concept_context_lookup
   ON knowledge.concept_context(
      context_type_code,
      context_value_id,
      applicability
   );

CREATE TRIGGER trg_concept_context_updated_at
   BEFORE UPDATE ON knowledge.concept_context
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 4. CONCEPT â†’ CARE SETTING
-- =============================================================================
-- Explicit operational routing layer.
--
-- Examples:
--   chest pain â†’ emergency
--   chest pain â†’ outpatient
--   chest pain â†’ inpatient
--   chest pain â†’ ICU
--
-- Uses context values rather than duplicating concepts.
-- =============================================================================

CREATE TABLE knowledge.concept_care_setting (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   context_value_id  uuid NOT NULL
                     REFERENCES knowledge.context_value(id)
                     ON DELETE CASCADE,

   relevance          text NOT NULL DEFAULT 'related'
                     CHECK (
                        relevance IN (
                           'critical',
                           'primary',
                           'secondary',
                           'related'
                        )
                     ),

   weight             numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (weight >= 0 AND weight <= 1),

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (concept_id, context_value_id)
);

COMMENT ON TABLE knowledge.concept_care_setting IS
'Operational routing of concepts to care settings represented by context values.';

CREATE INDEX idx_concept_care_setting_concept
   ON knowledge.concept_care_setting(concept_id);

CREATE INDEX idx_concept_care_setting_context
   ON knowledge.concept_care_setting(context_value_id);

CREATE TRIGGER trg_concept_care_setting_updated_at
   BEFORE UPDATE ON knowledge.concept_care_setting
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 5. CONCEPT â†’ POPULATION
-- =============================================================================
-- Population-level applicability without creating population-specific copies
-- of the same concept.
-- =============================================================================

CREATE TABLE knowledge.concept_population (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   context_value_id  uuid NOT NULL
                     REFERENCES knowledge.context_value(id)
                     ON DELETE CASCADE,

   applicability     text NOT NULL DEFAULT 'applies'
                     CHECK (
                        applicability IN (
                           'applies',
                           'preferred',
                           'higher_risk',
                           'lower_risk',
                           'excluded'
                        )
                     ),

   weight             numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (weight >= 0 AND weight <= 1),

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (concept_id, context_value_id)
);

COMMENT ON TABLE knowledge.concept_population IS
'Population-specific applicability of universal concepts.';

CREATE INDEX idx_concept_population_concept
   ON knowledge.concept_population(concept_id);

CREATE INDEX idx_concept_population_context
   ON knowledge.concept_population(context_value_id);

CREATE TRIGGER trg_concept_population_updated_at
   BEFORE UPDATE ON knowledge.concept_population
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 6. CONCEPT â†’ CLINICAL ROLE
-- =============================================================================
-- Determines how a concept functions clinically.
--
-- Examples:
--   fever â†’ presenting_symptom
--   fever â†’ diagnostic_finding
--   fever â†’ red_flag
--   fever â†’ severity_marker
--
-- This prevents separate copies of concepts for different clinical uses.
-- =============================================================================

CREATE TABLE knowledge.concept_role (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   role_code         text NOT NULL,

   role_weight       numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (role_weight >= 0 AND role_weight <= 1),

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (concept_id, role_code)
);

COMMENT ON TABLE knowledge.concept_role IS
'Universal clinical roles performed by a concept.';

CREATE INDEX idx_concept_role_concept
   ON knowledge.concept_role(concept_id);

CREATE INDEX idx_concept_role_code
   ON knowledge.concept_role(role_code);

CREATE TRIGGER trg_concept_role_updated_at
   BEFORE UPDATE ON knowledge.concept_role
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 7. CONCEPT â†’ SPECIALTY + CONTEXT
-- =============================================================================
-- High-performance contextual routing.
--
-- Example:
--   COUGH + PAEDIATRICS + EMERGENCY
--   CHEST PAIN + ADULT MEDICINE + EMERGENCY
--   BLEEDING + OBSTETRICS + PREGNANCY
--
-- This is not a duplicate concept.
-- It is a context-specific relevance edge.
-- =============================================================================

CREATE TABLE knowledge.concept_specialty_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   specialty_code    text NOT NULL
                     REFERENCES organization.specialty(code),

   context_type_code text NOT NULL
                     REFERENCES knowledge.context_type(code),

   context_value_id  uuid
                     REFERENCES knowledge.context_value(id)
                     ON DELETE CASCADE,

   relevance          numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (relevance >= 0 AND relevance <= 1),

   priority           integer NOT NULL DEFAULT 0,

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      concept_id,
      specialty_code,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.concept_specialty_context IS
'Composite routing edge for context-aware clinical intelligence.';

CREATE INDEX idx_concept_specialty_context_concept
   ON knowledge.concept_specialty_context(concept_id);

CREATE INDEX idx_concept_specialty_context_specialty
   ON knowledge.concept_specialty_context(specialty_code);

CREATE INDEX idx_concept_specialty_context_context
   ON knowledge.concept_specialty_context(
      context_type_code,
      context_value_id
   );


-- =============================================================================
-- 8. CONCEPT â†’ BODY SYSTEM + CONTEXT
-- =============================================================================
-- Allows the CPU to determine that the same concept has different system
-- relevance depending on the patient context.
-- =============================================================================

CREATE TABLE knowledge.concept_system_context (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id        uuid NOT NULL
                     REFERENCES knowledge.concept(id)
                     ON DELETE CASCADE,

   body_system_code  text NOT NULL
                     REFERENCES knowledge.body_system(code),

   context_type_code text NOT NULL
                     REFERENCES knowledge.context_type(code),

   context_value_id  uuid
                     REFERENCES knowledge.context_value(id)
                     ON DELETE CASCADE,

   relevance          numeric(5,4) NOT NULL DEFAULT 1.0000
                     CHECK (relevance >= 0 AND relevance <= 1),

   description       text,

   created_at        timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      concept_id,
      body_system_code,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.concept_system_context IS
'Context-dependent body-system relevance for universal concepts.';

CREATE INDEX idx_concept_system_context_concept
   ON knowledge.concept_system_context(concept_id);

CREATE INDEX idx_concept_system_context_system
   ON knowledge.concept_system_context(body_system_code);

CREATE INDEX idx_concept_system_context_context
   ON knowledge.concept_system_context(
      context_type_code,
      context_value_id
   );


-- =============================================================================
-- 9. CONCEPT â†’ CONCEPT SEMANTIC EDGE
-- =============================================================================
-- Optimized typed edge layer for the most common graph operation.
--
-- knowledge.relationship remains the universal graph skeleton.
-- This table provides a strongly indexed semantic layer for concept-to-concept
-- traversal without forcing the CPU to scan polymorphic source/target rows.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.concept_relationship CASCADE;
CREATE TABLE knowledge.concept_relationship (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_concept_id     uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   target_concept_id     uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL,

   directionality        text NOT NULL DEFAULT 'directed'
                         CHECK (
                            directionality IN (
                               'directed',
                               'bidirectional'
                            )
                         ),

   weight                numeric(5,4) NOT NULL DEFAULT 1.0000
                         CHECK (weight >= 0 AND weight <= 1),

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),

   confidence            numeric(5,4)
                         CHECK (
                            confidence IS NULL
                            OR (
                               confidence >= 0
                               AND confidence <= 1
                            )
                         ),

   evidence              text,

   context               jsonb,

   is_active             boolean NOT NULL DEFAULT true,

   version               text,

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now(),

   CHECK (source_concept_id <> target_concept_id),

   UNIQUE (
      source_concept_id,
      target_concept_id,
      relationship_type,
      polarity,
      context
   )
);

COMMENT ON TABLE knowledge.concept_relationship IS
'Optimized strongly typed concept-to-concept clinical graph edges.';

CREATE INDEX idx_concept_relationship_source
   ON knowledge.concept_relationship(source_concept_id);

CREATE INDEX idx_concept_relationship_target
   ON knowledge.concept_relationship(target_concept_id);

CREATE INDEX idx_concept_relationship_type
   ON knowledge.concept_relationship(relationship_type);

CREATE INDEX idx_concept_relationship_source_type
   ON knowledge.concept_relationship(
      source_concept_id,
      relationship_type
   );

CREATE INDEX idx_concept_relationship_target_type
   ON knowledge.concept_relationship(
      target_concept_id,
      relationship_type
   );

CREATE INDEX idx_concept_relationship_active
   ON knowledge.concept_relationship(is_active);

CREATE TRIGGER trg_concept_relationship_updated_at
   BEFORE UPDATE ON knowledge.concept_relationship
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 10. CONCEPT â†’ CONTEXT RULE
-- =============================================================================
-- Defines context combinations that alter the interpretation of a concept.
--
-- Example:
--   cough + child + acute
--   cough + adult + smoker
--   vaginal bleeding + pregnancy
--
-- This is an interpretation layer, not a disease-specific engine.
-- =============================================================================

CREATE TABLE knowledge.concept_context_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   rule_code             text NOT NULL UNIQUE,

   rule_type             text NOT NULL
                         CHECK (
                            rule_type IN (
                               'activation',
                               'relevance',
                               'severity',
                               'routing',
                               'safety',
                               'documentation',
                               'differential',
                               'investigation'
                            )
                         ),

   condition             jsonb NOT NULL,

   effect                jsonb NOT NULL,

   priority              integer NOT NULL DEFAULT 50,

   is_active             boolean NOT NULL DEFAULT true,

   version               text,

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.concept_context_rule IS
'Context-dependent interpretation rules for universal concepts.';

CREATE INDEX idx_concept_context_rule_concept
   ON knowledge.concept_context_rule(concept_id);

CREATE INDEX idx_concept_context_rule_type
   ON knowledge.concept_context_rule(rule_type);

CREATE INDEX idx_concept_context_rule_active
   ON knowledge.concept_context_rule(is_active);

CREATE TRIGGER trg_concept_context_rule_updated_at
   BEFORE UPDATE ON knowledge.concept_context_rule
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 11. CONCEPT â†’ DOCUMENTATION
-- =============================================================================
-- Universal rendering layer.
-- One concept can render differently according to language, specialty,
-- clinical context and documentation purpose.
-- =============================================================================

CREATE TABLE knowledge.concept_documentation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   documentation_type    text NOT NULL,
   phrase                text NOT NULL,

   language_code         text,
   context_type_code     text
                         REFERENCES knowledge.context_type(code),
   context_value_id      uuid
                         REFERENCES knowledge.context_value(id)
                         ON DELETE CASCADE,

   specialty_code        text
                         REFERENCES organization.specialty(code),

   is_preferred          boolean NOT NULL DEFAULT false,

   priority              integer NOT NULL DEFAULT 0,

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      concept_id,
      documentation_type,
      phrase,
      language_code,
      context_type_code,
      context_value_id,
      specialty_code
   )
);

COMMENT ON TABLE knowledge.concept_documentation IS
'Universal documentation rendering layer for clinical concepts.';

CREATE INDEX idx_concept_documentation_concept
   ON knowledge.concept_documentation(concept_id);

CREATE INDEX idx_concept_documentation_type
   ON knowledge.concept_documentation(documentation_type);

CREATE INDEX idx_concept_documentation_context
   ON knowledge.concept_documentation(
      context_type_code,
      context_value_id
   );

CREATE INDEX idx_concept_documentation_specialty
   ON knowledge.concept_documentation(specialty_code);

CREATE TRIGGER trg_concept_documentation_updated_at
   BEFORE UPDATE ON knowledge.concept_documentation
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 12. CONCEPT â†’ EVIDENCE / PROVENANCE
-- =============================================================================
-- Clinical concepts themselves require provenance.
-- This permits AMEXAN to distinguish:
--
--   guideline-derived
--   textbook-derived
--   literature-derived
--   expert-derived
--   regulatory
--   local protocol
--   institutional
--   machine-generated
--
-- The database stores provenance; the clinical CPU determines how it affects
-- confidence and execution.
-- =============================================================================

CREATE TABLE knowledge.concept_source (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   source_type            text NOT NULL
                         CHECK (
                            source_type IN (
                               'guideline',
                               'textbook',
                               'literature',
                               'systematic_review',
                               'meta_analysis',
                               'regulatory',
                               'expert_consensus',
                               'local_protocol',
                               'institutional',
                               'machine_generated',
                               'other'
                            )
                         ),

   source_ref             text,
   citation               text,
   url                    text,

   evidence_level         text,

   publication_date       date,

   notes                  text,

   created_at             timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      concept_id,
      source_type,
      source_ref
   )
);

COMMENT ON TABLE knowledge.concept_source IS
'Provenance and evidence sources for universal clinical concepts.';

CREATE INDEX idx_concept_source_concept
   ON knowledge.concept_source(concept_id);

CREATE INDEX idx_concept_source_type
   ON knowledge.concept_source(source_type);

CREATE INDEX idx_concept_source_evidence
   ON knowledge.concept_source(evidence_level);


-- =============================================================================
-- 13. CONCEPT VERSION
-- =============================================================================
-- Clinical knowledge must be versionable without destroying previous truth.
-- =============================================================================

CREATE TABLE knowledge.concept_version (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   version               integer NOT NULL,

   canonical_name        text NOT NULL,
   display_name          text,
   description           text,

   change_summary        text,

   status                text NOT NULL DEFAULT 'draft'
                         CHECK (
                            status IN (
                               'draft',
                               'review',
                               'approved',
                               'retired'
                            )
                         ),

   effective_from        timestamptz,
   effective_to          timestamptz,

   created_by            uuid
                         REFERENCES identity.user_account(id),

   reviewed_by           uuid
                         REFERENCES identity.user_account(id),

   created_at            timestamptz NOT NULL DEFAULT now(),

   UNIQUE (concept_id, version)
);

COMMENT ON TABLE knowledge.concept_version IS
'Immutable version history of universal clinical concepts.';


CREATE INDEX idx_concept_version_concept
   ON knowledge.concept_version(concept_id);

CREATE INDEX idx_concept_version_status
   ON knowledge.concept_version(status);


-- =============================================================================
-- 14. CONCEPT ACTIVATION
-- =============================================================================
-- Controls which version is clinically active.
-- =============================================================================

CREATE TABLE knowledge.concept_activation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid NOT NULL
                         REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   concept_version_id    uuid NOT NULL
                         REFERENCES knowledge.concept_version(id),

   context_type_code     text
                         REFERENCES knowledge.context_type(code),

   context_value_id      uuid
                         REFERENCES knowledge.context_value(id)
                         ON DELETE CASCADE,

   activated_at          timestamptz NOT NULL DEFAULT now(),

   activated_by          uuid
                         REFERENCES identity.user_account(id),

   is_active             boolean NOT NULL DEFAULT true,

   UNIQUE (
      concept_id,
      context_type_code,
      context_value_id
   )
);

COMMENT ON TABLE knowledge.concept_activation IS
'Active version of a concept globally or within a clinical context.';

CREATE INDEX idx_concept_activation_concept
   ON knowledge.concept_activation(concept_id);

CREATE INDEX idx_concept_activation_context
   ON knowledge.concept_activation(
      context_type_code,
      context_value_id
   );


-- =============================================================================
-- 15. CONCEPT SEARCH INDEX
-- =============================================================================
-- Fast lexical discovery for clinical terminology.
-- =============================================================================

CREATE INDEX idx_knowledge_concept_canonical_trgm
   ON knowledge.concept
   USING gin (canonical_name gin_trgm_ops);

CREATE INDEX idx_knowledge_concept_display_trgm
   ON knowledge.concept
   USING gin (display_name gin_trgm_ops);


-- =============================================================================
-- 16. UNIVERSAL CONCEPT GRAPH MATERIALIZATION
-- =============================================================================
-- High-speed lookup view combining the principal universal attachments.
-- This is deliberately a VIEW, not duplicated storage.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_concept_universal_context AS
SELECT
   c.id AS concept_id,
   c.concept_code,
   c.concept_type,
   c.canonical_name,
   c.display_name,
   cs.body_system_code,
   cs.relevance AS system_relevance,
   cs.weight AS system_weight,
   csp.specialty_code,
   csp.relevance AS specialty_relevance,
   csp.weight AS specialty_weight,
   cc.context_type_code,
   cc.context_value_id,
   cc.applicability AS context_applicability,
   cc.relevance AS context_relevance,
   cc.priority AS context_priority
FROM knowledge.concept c
LEFT JOIN knowledge.concept_system cs
   ON cs.concept_id = c.id
LEFT JOIN knowledge.concept_specialty csp
   ON csp.concept_id = c.id
LEFT JOIN knowledge.concept_context cc
   ON cc.concept_id = c.id
WHERE c.status = 'active';


COMMENT ON VIEW knowledge.v_concept_universal_context IS
'Unified non-duplicating contextual projection of the AMEXAN universal concept layer.';


-- =============================================================================
-- 17. BACKFILL LEGACY TYPE-SPECIFIC SYSTEM JUNCTIONS
-- =============================================================================
-- Existing Phase 2 tables remain valid for backward compatibility.
-- Their relationships are promoted into the universal concept layer.
-- =============================================================================

INSERT INTO knowledge.concept_system (
   concept_id,
   body_system_code,
   relevance,
   weight,
   description
)
SELECT
   s.concept_id,
   ss.body_system_code,
   CASE
      WHEN ss.relevance >= 0.90 THEN 'primary'
      WHEN ss.relevance >= 0.60 THEN 'secondary'
      ELSE 'related'
   END,
   LEAST(GREATEST(ss.relevance, 0), 1),
   'Backfilled from knowledge.symptom_system'
FROM knowledge.symptom_system ss
JOIN knowledge.symptom s
   ON s.id = ss.symptom_id
ON CONFLICT (concept_id, body_system_code)
DO UPDATE SET
   weight = GREATEST(
      knowledge.concept_system.weight,
      EXCLUDED.weight
   );


INSERT INTO knowledge.concept_system (
   concept_id,
   body_system_code,
   relevance,
   weight,
   description
)
SELECT
   c.concept_id,
   cs.body_system_code,
   CASE
      WHEN cs.weight >= 0.90 THEN 'primary'
      WHEN cs.weight >= 0.60 THEN 'secondary'
      ELSE 'related'
   END,
   LEAST(GREATEST(cs.weight, 0), 1),
   'Backfilled from knowledge.condition_system'
FROM knowledge.condition_system cs
JOIN knowledge.condition c
   ON c.id = cs.condition_id
WHERE c.concept_id IS NOT NULL
ON CONFLICT (concept_id, body_system_code)
DO UPDATE SET
   weight = GREATEST(
      knowledge.concept_system.weight,
      EXCLUDED.weight
   );


-- =============================================================================
-- 18. BACKFILL LEGACY TYPE-SPECIFIC SPECIALTY JUNCTIONS
-- =============================================================================

INSERT INTO knowledge.concept_specialty (
   concept_id,
   specialty_code,
   relevance,
   weight,
   description
)
SELECT
   s.concept_id,
   ss.specialty_code,
   CASE
      WHEN ss.relevance >= 0.90 THEN 'primary'
      WHEN ss.relevance >= 0.60 THEN 'secondary'
      ELSE 'related'
   END,
   LEAST(GREATEST(ss.relevance, 0), 1),
   'Backfilled from knowledge.symptom_specialty'
FROM knowledge.symptom_specialty ss
JOIN knowledge.symptom s
   ON s.id = ss.symptom_id
ON CONFLICT (concept_id, specialty_code)
DO UPDATE SET
   weight = GREATEST(
      knowledge.concept_specialty.weight,
      EXCLUDED.weight
   );


INSERT INTO knowledge.concept_specialty (
   concept_id,
   specialty_code,
   relevance,
   weight,
   description
)
SELECT
   c.concept_id,
   cs.specialty_code,
   CASE
      WHEN cs.weight >= 0.90 THEN 'primary'
      WHEN cs.weight >= 0.60 THEN 'secondary'
      ELSE 'related'
   END,
   LEAST(GREATEST(cs.weight, 0), 1),
   'Backfilled from knowledge.condition_specialty'
FROM knowledge.condition_specialty cs
JOIN knowledge.condition c
   ON c.id = cs.condition_id
WHERE c.concept_id IS NOT NULL
ON CONFLICT (concept_id, specialty_code)
DO UPDATE SET
   weight = GREATEST(
      knowledge.concept_specialty.weight,
      EXCLUDED.weight
   );


-- =============================================================================
-- 19. PROMOTE SYMPTOM CONTEXT TO UNIVERSAL CONCEPT CONTEXT
-- =============================================================================

INSERT INTO knowledge.concept_context (
   concept_id,
   context_type_code,
   context_value_id,
   applicability,
   relevance,
   description
)
SELECT
   s.concept_id,
   sc.context_type_code,
   sc.context_value_id,
   'applies',
   LEAST(GREATEST(sc.relevance, 0), 1),
   'Backfilled from knowledge.symptom_context'
FROM knowledge.symptom_context sc
JOIN knowledge.symptom s
   ON s.id = sc.symptom_id
WHERE s.concept_id IS NOT NULL
ON CONFLICT (
   concept_id,
   context_type_code,
   context_value_id
)
DO UPDATE SET
   relevance = GREATEST(
      knowledge.concept_context.relevance,
      EXCLUDED.relevance
   );


-- =============================================================================
-- 20. PROMOTE CONDITION CONTEXT TO UNIVERSAL CONCEPT CONTEXT
-- =============================================================================

INSERT INTO knowledge.concept_context (
   concept_id,
   context_type_code,
   context_value_id,
   applicability,
   relevance,
   description
)
SELECT
   c.concept_id,
   cc.context_type_code,
   cc.context_value_id,
   cc.applicability,
   LEAST(GREATEST(COALESCE(cc.likelihood_modifier, 1), 0), 1),
   'Backfilled from knowledge.condition_context'
FROM knowledge.condition_context cc
JOIN knowledge.condition c
   ON c.id = cc.condition_id
WHERE c.concept_id IS NOT NULL
ON CONFLICT (
   concept_id,
   context_type_code,
   context_value_id
)
DO UPDATE SET
   relevance = GREATEST(
      knowledge.concept_context.relevance,
      EXCLUDED.relevance
   );


-- =============================================================================
-- 21. UNIVERSAL CONCEPT LOOKUP FUNCTION
-- =============================================================================
-- High-speed clinical CPU lookup.
--
-- Returns a concept's relevance for a supplied context without requiring
-- disease-specific code.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_concept_context(
   p_concept_id uuid,
   p_context_type_code text DEFAULT NULL,
   p_context_value_id uuid DEFAULT NULL
)
RETURNS TABLE (
   concept_id uuid,
   concept_code text,
   concept_type text,
   canonical_name text,
   system_code text,
   system_relevance text,
   system_weight numeric,
   specialty_code text,
   specialty_relevance text,
   specialty_weight numeric,
   context_type_code text,
   context_value_id uuid,
   context_applicability text,
   context_relevance numeric,
   context_priority integer
)
LANGUAGE sql
STABLE
AS $$
   SELECT
      c.id,
      c.concept_code,
      c.concept_type,
      c.canonical_name,
      cs.body_system_code,
      cs.relevance,
      cs.weight,
      csp.specialty_code,
      csp.relevance,
      csp.weight,
      cc.context_type_code,
      cc.context_value_id,
      cc.applicability,
      cc.relevance,
      cc.priority
   FROM knowledge.concept c
   LEFT JOIN knowledge.concept_system cs
      ON cs.concept_id = c.id
   LEFT JOIN knowledge.concept_specialty csp
      ON csp.concept_id = c.id
   LEFT JOIN knowledge.concept_context cc
      ON cc.concept_id = c.id
   WHERE c.id = p_concept_id
     AND c.status = 'active'
     AND (
        p_context_type_code IS NULL
        OR cc.context_type_code = p_context_type_code
        OR cc.context_type_code IS NULL
     )
     AND (
        p_context_value_id IS NULL
        OR cc.context_value_id = p_context_value_id
        OR cc.context_value_id IS NULL
     )
   ORDER BY
      cc.priority DESC,
      cc.relevance DESC,
      cs.weight DESC,
      csp.weight DESC;
$$;


-- =============================================================================
-- 22. UNIVERSAL CONCEPT GRAPH TRAVERSAL FUNCTION
-- =============================================================================
-- Provides the clinical CPU with direct concept-neighbour traversal.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.related_concepts(
   p_concept_id uuid,
   p_relationship_type text DEFAULT NULL,
   p_limit integer DEFAULT 100
)
RETURNS TABLE (
   relationship_id uuid,
   source_concept_id uuid,
   source_code text,
   source_type text,
   source_name text,
   relationship_type text,
   target_concept_id uuid,
   target_code text,
   target_type text,
   target_name text,
   weight numeric,
   polarity text,
   confidence numeric
)
LANGUAGE sql
STABLE
AS $$
   SELECT
      cr.id,
      cr.source_concept_id,
      sc.concept_code,
      sc.concept_type,
      sc.canonical_name,
      cr.relationship_type,
      cr.target_concept_id,
      tc.concept_code,
      tc.concept_type,
      tc.canonical_name,
      cr.weight,
      cr.polarity,
      cr.confidence
   FROM knowledge.concept_relationship cr
   JOIN knowledge.concept sc
      ON sc.id = cr.source_concept_id
   JOIN knowledge.concept tc
      ON tc.id = cr.target_concept_id
   WHERE cr.source_concept_id = p_concept_id
     AND cr.is_active = true
     AND (
        p_relationship_type IS NULL
        OR cr.relationship_type = p_relationship_type
     )
   ORDER BY
      cr.weight DESC,
      cr.confidence DESC NULLS LAST
   LIMIT GREATEST(p_limit, 1);
$$;


-- =============================================================================
-- 23. UNIVERSAL CONCEPT SEARCH FUNCTION
-- =============================================================================
-- Fast semantic-entry point for the clinical operating system.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.search_concepts(
   p_query text,
   p_concept_type text DEFAULT NULL,
   p_limit integer DEFAULT 50
)
RETURNS TABLE (
   concept_id uuid,
   concept_code text,
   concept_type text,
   canonical_name text,
   display_name text,
   similarity_score real
)
LANGUAGE sql
STABLE
AS $$
   SELECT
      c.id,
      c.concept_code,
      c.concept_type,
      c.canonical_name,
      c.display_name,
      GREATEST(
         similarity(c.canonical_name, p_query),
         similarity(COALESCE(c.display_name, ''), p_query)
      ) AS similarity_score
   FROM knowledge.concept c
   WHERE c.status = 'active'
     AND (
        p_concept_type IS NULL
        OR c.concept_type = p_concept_type
     )
     AND (
        c.canonical_name ILIKE '%' || p_query || '%'
        OR c.display_name ILIKE '%' || p_query || '%'
        OR similarity(c.canonical_name, p_query) >= 0.20
        OR similarity(COALESCE(c.display_name, ''), p_query) >= 0.20
     )
   ORDER BY similarity_score DESC
   LIMIT GREATEST(p_limit, 1);
$$;


-- =============================================================================
-- 24. UNIVERSAL KNOWLEDGE INTEGRITY CHECKS
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_concept_junction(
   p_concept_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
   v_result jsonb;
BEGIN
   SELECT jsonb_build_object(
      'concept_id', c.id,
      'concept_code', c.concept_code,
      'concept_type', c.concept_type,

      'body_systems',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_system x
         WHERE x.concept_id = c.id
      ),

      'specialties',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_specialty x
         WHERE x.concept_id = c.id
      ),

      'contexts',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_context x
         WHERE x.concept_id = c.id
      ),

      'relationships_out',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_relationship x
         WHERE x.source_concept_id = c.id
           AND x.is_active = true
      ),

      'relationships_in',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_relationship x
         WHERE x.target_concept_id = c.id
           AND x.is_active = true
      ),

      'documentations',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_documentation x
         WHERE x.concept_id = c.id
      ),

      'sources',
      (
         SELECT COUNT(*)
         FROM knowledge.concept_source x
         WHERE x.concept_id = c.id
      )
   )
   INTO v_result
   FROM knowledge.concept c
   WHERE c.id = p_concept_id;

   RETURN COALESCE(
      v_result,
      jsonb_build_object(
         'concept_id', p_concept_id,
         'found', false
      )
   );
END;
$$;


-- =============================================================================
-- 25. PERFORMANCE INDEXES FOR CLINICAL RESOLUTION
-- =============================================================================

CREATE INDEX idx_concept_context_fast
   ON knowledge.concept_context(
      concept_id,
      context_type_code,
      context_value_id,
      applicability,
      priority DESC
   );

CREATE INDEX idx_concept_system_fast
   ON knowledge.concept_system(
      concept_id,
      body_system_code,
      weight DESC
   );

CREATE INDEX idx_concept_specialty_fast
   ON knowledge.concept_specialty(
      concept_id,
      specialty_code,
      weight DESC
   );

CREATE INDEX idx_concept_relationship_fast_out
   ON knowledge.concept_relationship(
      source_concept_id,
      is_active,
      relationship_type,
      weight DESC
   );

CREATE INDEX idx_concept_relationship_fast_in
   ON knowledge.concept_relationship(
      target_concept_id,
      is_active,
      relationship_type,
      weight DESC
   );


-- =============================================================================
-- 26. UNIVERSAL KNOWLEDGE GRAPH STATISTICS
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_concept_graph_statistics AS
SELECT
   c.id AS concept_id,
   c.concept_code,
   c.concept_type,
   c.canonical_name,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_system cs
      WHERE cs.concept_id = c.id
   ) AS body_system_count,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_specialty cs
      WHERE cs.concept_id = c.id
   ) AS specialty_count,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_context cc
      WHERE cc.concept_id = c.id
   ) AS context_count,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_relationship cr
      WHERE cr.source_concept_id = c.id
        AND cr.is_active = true
   ) AS outgoing_relationship_count,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_relationship cr
      WHERE cr.target_concept_id = c.id
        AND cr.is_active = true
   ) AS incoming_relationship_count,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_source cs
      WHERE cs.concept_id = c.id
   ) AS source_count,

   (
      SELECT COUNT(*)
      FROM knowledge.concept_documentation cd
      WHERE cd.concept_id = c.id
   ) AS documentation_count

FROM knowledge.concept c
WHERE c.status = 'active';


COMMENT ON VIEW knowledge.v_concept_graph_statistics IS
'Operational graph statistics for AMEXAN clinical knowledge coverage and completeness.';


-- =============================================================================
-- 27. FINAL ARCHITECTURAL GUARANTEE
-- =============================================================================
-- The following objects establish the universal concept substrate:
--
-- knowledge.concept
--      â”‚
--      â”œâ”€â”€ concept_system
--      â”œâ”€â”€ concept_specialty
--      â”œâ”€â”€ concept_context
--      â”œâ”€â”€ concept_care_setting
--      â”œâ”€â”€ concept_population
--      â”œâ”€â”€ concept_role
--      â”œâ”€â”€ concept_specialty_context
--      â”œâ”€â”€ concept_system_context
--      â”œâ”€â”€ concept_relationship
--      â”œâ”€â”€ concept_context_rule
--      â”œâ”€â”€ concept_documentation
--      â”œâ”€â”€ concept_source
--      â”œâ”€â”€ concept_version
--      â””â”€â”€ concept_activation
--
-- This makes the concept the single reusable atomic clinical object.
--
-- Disease, symptom, mechanism, phenotype, investigation, medication,
-- complication, sign, finding and fact remain specialized knowledge layers,
-- while their universal identity is carried by knowledge.concept.
--
-- NO TYPE-SPECIFIC CONCEPT DUPLICATION IS REQUIRED FOR:
--
--      body system
--      specialty
--      department
--      age
--      sex
--      pregnancy
--      gestational age
--      acuity
--      geography
--      care setting
--      population
--      clinical role
--      documentation context
--
-- The clinical CPU resolves these dimensions through junctions,
-- relationships, context and weighted evidence.
-- =============================================================================
