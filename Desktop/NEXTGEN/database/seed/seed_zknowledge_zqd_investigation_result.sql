-- =============================================================================
-- AMEXAN — Seed ZQD: investigation result mapping + CXR facility override
-- =============================================================================
-- Migration 020 seeded knowledge.investigation_result and the
-- OVR-CXR-FACILITY-DEFER override via JOIN on INV-CXR, but that row is created
-- by the investigation seeds (zp5/zpc) which run AFTER migrations — so the
-- inserts were silent no-ops. This seed runs after those seeds and makes the
-- two §3.16 / §3.19 capabilities real data:
--
--   1. INVESTIGATION RESULTS (§3.16 closed loop) — a CXR result returns to the
--      CPU as facts. knowledge.investigation_result maps a result code
--      (RLL_CONSOLIDATION) to the fact definitions it establishes, so the
--      ResultInterpreter can close the loop.
--
--   2. CONFIGURATION OVERRIDE (§3.19) — one facility-scoped override on the CXR
--      recommendation proves the DEFAULT -> LOCAL -> WHY -> CURRENT chain
--      through knowledge.active_override.
--
-- Both blocks are idempotent: re-running seed.ps1 is safe.
-- =============================================================================

-- 1. Investigation -> result -> facts mapping (the closed loop)
INSERT INTO knowledge.investigation_result (investigation_id, result_code, result_label, fact_definition_code)
SELECT inv.id, r.result_code, r.result_label, r.fact_definition_code
FROM (VALUES
    ('RLL_CONSOLIDATION', 'Right lower lobe consolidation', 'RLL_DULLNESS'),
    ('RLL_CONSOLIDATION', 'Right lower lobe consolidation', 'RLL_BRONCHIAL_BREATH_SOUNDS'),
    ('AIRSPACE_OPACITY',  'Airspace opacity / infiltrate',  'RLL_DULLNESS'),
    ('NORMAL',            'No acute radiological abnormality', NULL)
) r(result_code, result_label, fact_definition_code)
JOIN knowledge.investigation inv ON inv.investigation_code = 'INV-CXR'
WHERE NOT EXISTS (
    SELECT 1 FROM knowledge.investigation_result ir
    WHERE ir.investigation_id = inv.id
      AND ir.result_code = r.result_code
)  ON CONFLICT DO NOTHING;

-- 2. Facility-scoped CXR override (3.19) — provenance chain via active_override
--    Requires a real facility entity (non-global overrides need scope_entity_id),
--    so the demo hospital + facility are seeded idempotently first.
INSERT INTO organization.organization
    (id, organization_key, name, legal_name, organization_type, description, country_code, timezone, status, metadata)
VALUES
    ('d0000000-0000-0000-0000-000000000001', 'ORG-AMEXAN-DEMO-001', 'AMEXAN Demonstration Hospital',
     'AMEXAN Demonstration Hospital Ltd', 'hospital', 'Demo facility for the 3.19 configuration override chain.',
     'KE', 'Africa/Nairobi', 'active', '{}'::jsonb)
  ON CONFLICT DO NOTHING;

INSERT INTO organization.facility
    (id, organization_id, facility_key, name, legal_name, facility_type, ownership_type, status, country_code, county, timezone, metadata)
VALUES
    ('d0000000-0000-0000-0000-000000000101', 'd0000000-0000-0000-0000-000000000001', 'FAC-AMEXAN-DEMO-001',
     'AMEXAN Demo County Hospital', 'AMEXAN Demo County Hospital', 'county_hospital', 'public',
     'active', 'KE', 'Nairobi', 'Africa/Nairobi', '{}'::jsonb)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.knowledge_override
    (override_code, target_type, target_id, scope_code, scope_entity_id, config, reason, status, effective_from)
SELECT 'OVR-CXR-FACILITY-DEFER', 'investigation', inv.id, 'facility', 'd0000000-0000-0000-0000-000000000101',
       jsonb_build_object(
           'rationale', 'Defer CXR in uncomplicated community cases per facility guidance; review if danger signs present.',
           'weighting', 'consider'
       ),
       'Facility imaging constraints in stable CAP without danger signs.',
       'active', now()
FROM knowledge.investigation inv
WHERE inv.investigation_code = 'INV-CXR'
  ON CONFLICT DO NOTHING;
