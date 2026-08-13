-- =============================================================================
-- AMEXAN Phase 2 — Migration 012: universal concept junctions
-- =============================================================================
-- Hardening rule: ONE concept, MANY systems, MANY departments, NO duplication.
-- Cough is a single concept (CNS-COUGH); its relevance to respiratory,
-- cardiovascular, GI, ENT, paediatrics, emergency etc. is a RELATIONSHIP,
-- never a duplicate concept. Junctions are universal (keyed on concept), so a
-- sign, finding, risk factor, mechanism or condition also attaches here — the
-- design no longer needs symptom_system/condition_system-style per-type tables.
-- =============================================================================

-- Lock concept_type to the universal vocabulary (was free text).
DO $$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_knowledge_concept_type') THEN
      ALTER TABLE knowledge.concept
         ADD CONSTRAINT chk_knowledge_concept_type
         CHECK (concept_type IN ('symptom','sign','finding','fact','risk_factor',
                                 'mechanism','phenotype','condition','investigation',
                                 'medication','complication','body_system'));
   END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- CONCEPT -> BODY SYSTEM  (universal multi-system attachment)
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.concept_system (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid NOT NULL REFERENCES knowledge.concept(id) ON DELETE CASCADE,
   body_system_code  text NOT NULL REFERENCES knowledge.body_system(code),
   relevance         text NOT NULL DEFAULT 'related'
                     CHECK (relevance IN ('primary','secondary','cross_system','related')),
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   description       text,
   UNIQUE (concept_id, body_system_code)
);
COMMENT ON TABLE knowledge.concept_system IS
   'One concept attaches to MANY body systems with a relevance label. CNS-COUGH: respiratory=primary, cardiovascular=secondary, GI=secondary, ENT=related.';

CREATE INDEX idx_concept_system_body ON knowledge.concept_system(body_system_code);
CREATE INDEX idx_concept_system_concept ON knowledge.concept_system(concept_id);

-- ---------------------------------------------------------------------------
-- CONCEPT -> DEPARTMENT / SPECIALTY  (universal multi-department attachment)
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.concept_specialty (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid NOT NULL REFERENCES knowledge.concept(id) ON DELETE CASCADE,
   specialty_code    text NOT NULL REFERENCES organization.specialty(code),
   relevance         text NOT NULL DEFAULT 'possible'
                     CHECK (relevance IN ('primary','secondary','possible','related')),
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   description       text,
   UNIQUE (concept_id, specialty_code)
);
COMMENT ON TABLE knowledge.concept_specialty IS
   'One concept attaches to MANY departments/specialties. CNS-COUGH: respiratory=primary, medicine=primary, paediatrics=primary, emergency=primary, surgery=possible.';

CREATE INDEX idx_concept_specialty_spec ON knowledge.concept_specialty(specialty_code);
CREATE INDEX idx_concept_specialty_concept ON knowledge.concept_specialty(concept_id);
