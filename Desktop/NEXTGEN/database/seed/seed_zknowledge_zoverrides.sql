-- =============================================================================
-- AMEXAN Phase 2 — Seed Z9: knowledge override examples
-- =============================================================================
-- Demonstrates DEFAULT -> LOCAL -> WHY -> CURRENT. Original knowledge rows are
-- never mutated; each override is a row pointing at the original node.
-- scope_code reuses configuration.scope. scope_entity_id is NULL for the
-- AMEXAN DEFAULT baseline; at runtime a facility/clinician override would set
-- it to the real facility.id / professional.id (no FK here by design).
-- =============================================================================

-- Version 1 of the AMEXAN DEFAULT baseline for the pneumonia-investigation rule
INSERT INTO knowledge.knowledge_override
   (id, override_code, target_type, target_id, scope_code, scope_entity_id, config, reason, status, version) VALUES
   ('f1200000-0000-0000-0000-000000000001',
    'OVR-PNEUMONIA-DEFAULT-V1', 'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global', NULL,
    jsonb_build_object('priority', 65,
                       'investigation', 'INV-CXR',
                       'note', 'CXR when productive cough + fever'),
    'AMEXAN baseline: CXR recommended for suspected pneumonia.', 'active', 1)
ON CONFLICT (override_code) DO NOTHING;

-- Version 2 supersedes v1 (updated default, chained via supersedes_id)
INSERT INTO knowledge.knowledge_override
   (id, override_code, target_type, target_id, scope_code, scope_entity_id, config, reason, status, version, supersedes_id) VALUES
   ('f1200000-0000-0000-0000-000000000002',
    'OVR-PNEUMONIA-DEFAULT-V2', 'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global', NULL,
    jsonb_build_object('priority', 70,
                       'investigation', 'INV-CXR',
                       'note', 'CXR when productive cough + fever; defer in uncomplicated young outpatients'),
    '2026 update: defer CXR in uncomplicated young outpatients unless red flag.',
    'active', 2,
    'f1200000-0000-0000-0000-000000000001')
ON CONFLICT (override_code) DO NOTHING;

-- Facility-level override example (requires a real facility.id at runtime).
-- Shown commented because no facility exists in reference seed data.
-- INSERT INTO knowledge.knowledge_override
--    (override_code, target_type, target_id, scope_code, scope_entity_id, config, reason) VALUES
--    ('OVR-PNEUMONIA-FAC-KISII', 'rule',
--     'f1100000-0000-0000-0000-000000000004',
--     'facility', '<facility-uuid>',
--     jsonb_build_object('priority', 75, 'investigation', 'INV-CXR'),
--     'Kisii Teaching Hospital: CXR available 24/7, order freely.'),
-- ON CONFLICT (override_code) DO NOTHING;

-- Clinician-level override example (requires a real professional.id at runtime).
-- INSERT INTO knowledge.knowledge_override
--    (override_code, target_type, target_id, scope_code, scope_entity_id, config, reason) VALUES
--    ('OVR-PNEUMONIA-DOC-KIPRONO', 'rule',
--     'f1100000-0000-0000-0000-000000000004',
--     'clinician', '<professional-uuid>',
--     jsonb_build_object('priority', 80, 'investigation', 'INV-CXR'),
--     'Dr Kiprono: order CXR for all pneumonia suspects.'),
-- ON CONFLICT (override_code) DO NOTHING;
