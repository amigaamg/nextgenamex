-- =============================================================================
-- AMEXAN Phase 3 — Migration 020: safety factors, result interpretation,
-- configuration override demonstration
-- =============================================================================
-- Completes three Phase 3 runtime capabilities the CPU needs as data:
--
--   1. PATIENT SAFETY FACTORS (3.17) — the CPU must account for allergies,
--      pregnancy, renal and hepatic function before offering treatment.
--      These fact definitions let a safety factor be captured like any other
--      observation, so the SafetyEngine reasons over the SAME substrate.
--
--   2. INVESTIGATION RESULTS (3.16) — the closed loop: a lab/imaging result
--      returns to the CPU as facts. knowledge.investigation_result is the
--      reusable mapping from a result code (e.g. "RLL_CONSOLIDATION") to the
--      fact definitions it establishes. The ResultInterpreter reads this.
--
--   3. CONFIGURATION / OVERRIDE (3.19) — one facility-scoped override on the
--      CXR recommendation proves the baseline + override + version + reason
--      chain through knowledge.active_override.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Safety fact definitions (universal, never disease-owned)
-- ---------------------------------------------------------------------------

INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active)
VALUES
  ('DRUG_ALLERGY',       'Drug allergy',        'A documented drug allergy (e.g. Penicillin, Macrolide, Sulfonamide).', 'text', true,  true),
  ('PREGNANT',           'Pregnant',            'Whether the patient is currently pregnant.',                         'boolean', false, true),
  ('CREATININE',         'Serum creatinine',    'Serum creatinine in mg/dL; raised values flag renal impairment.',    'numeric', false, true),
  ('HEPATIC_IMPAIRMENT', 'Hepatic impairment',  'Known hepatic impairment that may affect drug handling.',             'boolean', false, true)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Investigation → result → facts mapping (the closed loop)
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.investigation_result (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_id     uuid NOT NULL REFERENCES knowledge.investigation(id) ON DELETE CASCADE,
    result_code          text NOT NULL,           -- e.g. RLL_CONSOLIDATION / NORMAL
    result_label         text NOT NULL,           -- human label shown in the report
    fact_definition_code text REFERENCES clinical.fact_definition(code),  -- the fact this result establishes
    status               text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
    created_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_result IS
   'Maps an investigation result code to the clinical facts it establishes. The ResultInterpreter consumes this to close the loop (3.16).';

CREATE INDEX idx_knowledge_investigation_result ON knowledge.investigation_result(investigation_id, result_code);

-- CXR: a right-lower-lobe consolidation on the film establishes the two
-- alveolar-sign facts the reasoning engines already score.
INSERT INTO knowledge.investigation_result (investigation_id, result_code, result_label, fact_definition_code)
SELECT inv.id, r.result_code, r.result_label, r.fact_definition_code
FROM (VALUES
    ('RLL_CONSOLIDATION', 'Right lower lobe consolidation', 'RLL_DULLNESS'),
    ('RLL_CONSOLIDATION', 'Right lower lobe consolidation', 'RLL_BRONCHIAL_BREATH_SOUNDS'),
    ('AIRSPACE_OPACITY',  'Airspace opacity / infiltrate',  'RLL_DULLNESS'),
    ('NORMAL',            'No acute radiological abnormality', NULL)
) r(result_code, result_label, fact_definition_code)
JOIN knowledge.investigation inv ON inv.investigation_code = 'INV-CXR';

-- ---------------------------------------------------------------------------
-- 3. Configuration override demonstration (facility scope)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
    (override_code, target_type, target_id, scope_code, scope_entity_id, config, reason, status, effective_from)
SELECT 'OVR-CXR-FACILITY-DEFER', 'investigation', inv.id, 'facility', NULL,
       jsonb_build_object(
           'rationale', 'Defer CXR in uncomplicated community cases per facility guidance; review if danger signs present.',
           'weighting', 'consider'
       ),
       'Facility imaging constraints in stable CAP without danger signs.',
       'active', now()
FROM knowledge.investigation inv
WHERE inv.investigation_code = 'INV-CXR'
  AND NOT EXISTS (SELECT 1 FROM knowledge.knowledge_override WHERE override_code = 'OVR-CXR-FACILITY-DEFER');
