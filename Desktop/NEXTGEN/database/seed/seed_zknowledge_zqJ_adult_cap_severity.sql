-- =============================================================================
-- AMEXAN Medical Knowledge Compiler - R4 adult CAP severity (CURB-65)
-- Structured severity scoring object grounded to Kumar & Clark 10e (KCR-0005).
-- GENERATED FILE - do not edit by hand. Regenerate with:
--   python knowledge-compiler/build_r4_adult_cap_severity.py <out>
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. clinical.fact_definition - CURB-65 components
-- ---------------------------------------------------------------------------
INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES
   ('CONFUSION', 'Acute confusion', 'New mental confusion - one point on the CURB-65 severity score.', 'coded', false, true),
   ('SYSTOLIC_BP', 'Systolic blood pressure', 'Systolic blood pressure in mmHg - CURB-65 component.', 'numeric', false, true),
   ('DIASTOLIC_BP', 'Diastolic blood pressure', 'Diastolic blood pressure in mmHg - CURB-65 component.', 'numeric', false, true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 1. knowledge.severity_score - SCORE-CURB65
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.severity_score (id, score_code, canonical_name, description, condition_id, population, max_score, source_reference, status) VALUES
   ('bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'SCORE-CURB65', 'CURB-65 severity score', 'Community-acquired pneumonia severity: 1 point each for confusion, urea >7 mmol/L, RR >=30/min, systolic BP <90 or diastolic BP <60 mmHg, age >=65. 0-1 outpatient, 2 admit, 3+ ITU.', (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'adult', 5, 'Kumar & Clark 10e (KCR-0005)', 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.severity_score_component (id, score_id, component_code, component_name, condition, points, rationale, sort_order) VALUES
   ('76631d16-06b3-5659-a4b0-01c8ae147824', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'CURR-CONFUSION', 'New mental confusion', '{"type":"boolean","fact_code":"CONFUSION","expect":true}'::jsonb, '1', 'Confusion is an independent predictor of mortality in CAP (KCR-0005).', '10'),
   ('cda53ad2-b893-5cf5-a559-235c7353122b', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'CURR-UREA', 'Urea > 7 mmol/L', '{"type":"numeric_gt","fact_code":"UREA","threshold":7}'::jsonb, '1', 'Elevated urea indicates impaired renal/perfusion status (KCR-0005).', '20'),
   ('cfb6461d-b659-5223-a92d-bb0252a6222a', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'CURR-RR', 'Respiratory rate >= 30/min', '{"type":"numeric_gte","fact_code":"RESP_RATE","threshold":30}'::jsonb, '1', 'Tachypnoea reflects the ventilatory burden of infection (KCR-0005).', '30'),
   ('612f71d9-1369-54ff-86c9-3aae0c871829', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'CURR-BP', 'Systolic BP < 90 or diastolic BP < 60 mmHg', '{"type":"or","conditions":[{"type":"numeric_lt","fact_code":"SYSTOLIC_BP","threshold":90},{"type":"numeric_lt","fact_code":"DIASTOLIC_BP","threshold":60}]}'::jsonb, '1', 'Hypotension signals severe sepsis / septic shock (KCR-0005).', '40'),
   ('a7530128-000a-5dea-97bc-a86cecac2570', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'CURR-AGE', 'Age >= 65 years', '{"type":"age_gte","threshold":65}'::jsonb, '1', 'Older age carries higher CAP mortality (KCR-0005).', '50')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.severity_score_interpretation (id, score_id, min_score, max_score, severity_label, disposition, recommendation) VALUES
   ('8cc5952d-c01c-5918-8adb-95fb7be84cf7', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', '0', '1', 'Low', 'Treat as outpatient', 'Mild CAP (CURB-65 0-1): standard oral antibiotics at home (KCR-0006), no routine CXR unless no improvement at 48-72h.'),
   ('3f159487-897b-5ebb-81d4-e829d2486cfd', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', '2', '2', 'Moderate', 'Admit to hospital', 'CURB-65 2: admit to hospital for observation and parenteral therapy as indicated.'),
   ('4260a389-9547-5520-ad2d-5cbba5124b30', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', '3', '5', 'Severe', 'Admit to hospital; often requires ITU', 'CURB-65 3+: severe CAP - first antibiotic dose within 1 hour of identifying high-risk criteria; ITU care often required (KCR-0009).')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('bf9e0c96-5b48-5cb1-b90a-be5eeed64a7d', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'KCR-0005'), 'severity_score', 'bb16f04c-201b-5578-ab12-c417ff1cf4d6', 'SCORE-CURB65', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. PROT-CAP-ADULT - severity scoring step + action
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required)
VALUES ('0d38553f-a2c3-5588-8b65-baf800d2107e', (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-CAP-ADULT'), 'STEP-04A', 'Classify severity with CURB-65', 'assessment', 45, 'Score 1 point each for confusion, urea >7 mmol/L, RR >=30/min, SBP <90 or DBP <60 mmHg, age >=65. 0-1: outpatient; 2: admit; 3+: ITU.', 'CURB-65 guides disposition and intensity of care in CAP (KCR-0005).', true)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order)
VALUES ('e2579a8e-3e2d-53af-8985-580f87823954', (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-CAP-ADULT'), (SELECT ps.id FROM knowledge.protocol_step ps JOIN knowledge.protocol p ON p.id = ps.protocol_id WHERE p.protocol_code = 'PROT-CAP-ADULT' AND ps.step_code = 'STEP-04A'), 'score', 'SCORE-CURB65', 'CURB-65 severity score', 'Compute the CURB-65 score from captured facts and age; use it for disposition.', 'routine', 10)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. governance.knowledge_object - SCORE-CURB65
-- ---------------------------------------------------------------------------
INSERT INTO governance.knowledge_object (id, object_code, knowledge_type, canonical_name, description, source_claim_code, jurisdiction_code, population_code, evidence_level_code, lifecycle_status, confidence, is_active, status) VALUES
   ('6c54e566-ccda-543f-bf61-c2efa8677ce7', 'SCORE-CURB65', 'INTERPRETATION', 'CURB-65 severity score', 'Adult community-acquired pneumonia severity stratification (confusion, urea, RR, BP, age). Kumar & Clark 10e.', 'KCR-0005', 'JUR-GLOBAL', 'POP-ADULT', 'EV-C', 'ACTIVE', 0.95, true, 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO governance.knowledge_object_version (object_id, version_no, version_code, change_note, lifecycle_status, source_claim_code, created_by)
SELECT ko.id, 1, 'GO-V-R4-' || ko.object_code, 'R4 adult CAP severity release (KCR-0005).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'
FROM governance.knowledge_object ko WHERE ko.object_code = 'SCORE-CURB65'
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. tracking.respiratory_master_matrix - CURB-65 status
-- ---------------------------------------------------------------------------
INSERT INTO tracking.respiratory_master_matrix (id, family_code, family_name, item_code, item_name, population, status, source_ground, notes) VALUES
   ('70386eb6-2212-54cf-ac8c-2bd10a9d834c', 'B', 'Infectious respiratory disease', 'SCORE-CURB65', 'CURB-65 severity score (adult CAP)', 'A', 'EXECUTABLE', 'Kumar & Clark 10e (KCR-0005)', NULL)
  ON CONFLICT DO NOTHING;

UPDATE tracking.respiratory_master_matrix SET status='EXECUTABLE', source_ground='Kumar & Clark 10e (KCR-0005)',
       notes='Structured severity score object: SCORE-CURB65 + components + interpretations; SeverityScoreEngine computes from captured facts and age.',
       updated_at=now() WHERE item_code='SCORE-CURB65';
UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Kumar & Clark 10e (KCR-0005)',
       notes='Adult CAP severity stratification live on the PROT-CAP-ADULT pathway.',
       updated_at=now() WHERE item_code='COND-CAP';
