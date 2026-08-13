-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 014: investigation + examination primitives
-- =============================================================================
-- Reusable investigation definitions (CBC, CRP, CXR, SpO2, U&E, ...) and
-- structured examination modules. Every examination finding maps to a clinical
-- fact so history + examination feed the SAME reasoning substrate.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extend the universal concept vocabulary (was locked in migration 012).
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.concept DROP CONSTRAINT IF EXISTS chk_knowledge_concept_type;
ALTER TABLE knowledge.concept
   ADD CONSTRAINT chk_knowledge_concept_type
   CHECK (concept_type IN ('symptom','sign','finding','fact','risk_factor',
                           'mechanism','phenotype','condition','investigation',
                           'medication','complication','body_system',
                           'examination_module','examination_finding',
                           'protocol','monitoring','education'));
COMMENT ON CONSTRAINT chk_knowledge_concept_type ON knowledge.concept IS
   'Universal vocabulary types including Phase 1E primitives (investigation, examination_module, examination_finding, protocol, monitoring, education).';

-- ---------------------------------------------------------------------------
-- INVESTIGATION â€” reusable definition (never disease-owned)
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.investigation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   investigation_code text NOT NULL UNIQUE,     -- e.g. INV-CBC / INV-CRP / INV-CXR
   canonical_name    text NOT NULL,
   description       text,
   investigation_type text NOT NULL DEFAULT 'laboratory'
                     CHECK (investigation_type IN ('laboratory','imaging','physiological','pathology','microbiology')),
   body_system_code  text REFERENCES knowledge.body_system(code),
   specimen          text,                       -- blood / sputum / urine / imaging
   turn_around_minutes integer,
   preparation       text,                       -- fasting / timing / special instructions
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation IS
   'Reusable investigation definitions. Rules/protocols reference these; never duplicated per disease.';

CREATE INDEX idx_knowledge_investigation_concept ON knowledge.investigation(concept_id);
CREATE INDEX idx_knowledge_investigation_system ON knowledge.investigation(body_system_code);

CREATE TRIGGER trg_knowledge_investigation_updated_at
   BEFORE UPDATE ON knowledge.investigation
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.investigation_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   investigation_id  uuid NOT NULL REFERENCES knowledge.investigation(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   rationale         text,
   UNIQUE (investigation_id, condition_id)
);
COMMENT ON TABLE knowledge.investigation_condition IS
   'When an investigation becomes relevant for a condition (rules decide activation).';

-- ---------------------------------------------------------------------------
-- EXAMINATION MODULE â€” reusable structured examination (respiratory, cardiac,...)
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.examination_module (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   module_code       text NOT NULL UNIQUE,       -- e.g. EXAM-RESPIRATORY
   canonical_name    text NOT NULL,
   description       text,
   body_system_code  text REFERENCES knowledge.body_system(code),
   sort_order        integer NOT NULL DEFAULT 0,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_module IS 'Reusable structured examination. Findings become clinical facts.';

CREATE INDEX idx_knowledge_exam_module_concept ON knowledge.examination_module(concept_id);
CREATE INDEX idx_knowledge_exam_module_system ON knowledge.examination_module(body_system_code);

CREATE TRIGGER trg_knowledge_examination_module_updated_at
   BEFORE UPDATE ON knowledge.examination_module
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE knowledge.examination_finding (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   module_id         uuid NOT NULL REFERENCES knowledge.examination_module(id) ON DELETE CASCADE,
   concept_id        uuid REFERENCES knowledge.concept(id),
   finding_code      text NOT NULL,              -- e.g. FIND-RR-ELEVATED
   canonical_name    text NOT NULL,
   description       text,
   fact_definition_code text REFERENCES clinical.fact_definition(code),
   parent_finding_id uuid REFERENCES knowledge.examination_finding(id),
   finding_type      text NOT NULL DEFAULT 'observation'
                     CHECK (finding_type IN ('observation','measurement','sign','maneuver')),
   sort_order        integer NOT NULL DEFAULT 0,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   UNIQUE (module_id, finding_code)
);
COMMENT ON TABLE knowledge.examination_finding IS
   'Codeable finding inside an examination module. Maps to clinical.fact_definition so the CPU reasons over it.';

CREATE INDEX idx_knowledge_exam_finding_module ON knowledge.examination_finding(module_id);
CREATE INDEX idx_knowledge_exam_finding_fact ON knowledge.examination_finding(fact_definition_code);
CREATE INDEX idx_knowledge_exam_finding_concept ON knowledge.examination_finding(concept_id);

CREATE TABLE knowledge.examination_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   examination_module_id uuid NOT NULL REFERENCES knowledge.examination_module(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (examination_module_id, condition_id)
);
COMMENT ON TABLE knowledge.examination_condition IS 'Which examination modules are relevant for a condition.';
