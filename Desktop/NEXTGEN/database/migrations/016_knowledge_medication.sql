-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 016: medication / drug intelligence primitives
-- =============================================================================
-- Drugs are created ONCE as reusable intelligence (formulations, routes,
-- contraindications, interactions, special-population notes), then referenced
-- by protocols. Dose references are population/indication-aware. MVP rows carry
-- VERIFY_* placeholders: production deployment requires jurisdiction-specific
-- formulary verification â€” the architecture is the deliverable, not invented doses.
-- =============================================================================

CREATE TABLE knowledge.medication (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid REFERENCES knowledge.concept(id),
   medication_code   text NOT NULL UNIQUE,       -- e.g. MED-AMOXICILLIN
   generic_name      text NOT NULL,
   drug_class        text,
   route_options     jsonb NOT NULL DEFAULT '[]'::jsonb,
   formulations      jsonb NOT NULL DEFAULT '[]'::jsonb,
   contraindications jsonb NOT NULL DEFAULT '[]'::jsonb,
   interaction_notes jsonb NOT NULL DEFAULT '[]'::jsonb,
   monitoring_notes  jsonb NOT NULL DEFAULT '[]'::jsonb,
   renal_adjustment_notes text,
   hepatic_adjustment_notes text,
   pregnancy_notes   text,
   lactation_notes   text,
   formulary_status  text NOT NULL DEFAULT 'reference'
                     CHECK (formulary_status IN ('reference','facility','restricted','retired')),
   evidence_source   text,
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.medication IS 'Reusable drug intelligence. Protocols reference drugs; they never duplicate them.';

CREATE INDEX idx_knowledge_medication_concept ON knowledge.medication(concept_id);

CREATE TRIGGER trg_knowledge_medication_updated_at
   BEFORE UPDATE ON knowledge.medication
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Dose references: population + indication aware. VERIFY_* = clinical review required.
CREATE TABLE knowledge.drug_dose_reference (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   medication_id     uuid NOT NULL REFERENCES knowledge.medication(id) ON DELETE CASCADE,
   population        text NOT NULL
                     CHECK (population IN ('adult','paediatric','neonatal','geriatric','renal','hepatic','pregnancy')),
   indication_code   text,                        -- e.g. COND-CAP (references condition code)
   route             text,
   dose_expression   text NOT NULL,
   frequency_expression text,
   duration_expression  text,
   maximum_expression   text,
   evidence_source   text,
   is_verified       boolean NOT NULL DEFAULT false,
   UNIQUE (medication_id, population, indication_code, route)
);
COMMENT ON TABLE knowledge.drug_dose_reference IS
   'Population/indication-aware dose references. is_verified=false forces clinical review before prescribing.';

CREATE INDEX idx_knowledge_dose_reference_med ON knowledge.drug_dose_reference(medication_id);

CREATE TABLE knowledge.medication_condition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   medication_id     uuid NOT NULL REFERENCES knowledge.medication(id) ON DELETE CASCADE,
   condition_id      uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
   role              text NOT NULL DEFAULT 'treatment',   -- treatment / prophylaxis / symptomatic / adjunct
   weight            numeric(3,2) NOT NULL DEFAULT 1.0,
   UNIQUE (medication_id, condition_id, role)
);
COMMENT ON TABLE knowledge.medication_condition IS 'Drugs relevant to a condition, with their role.';
