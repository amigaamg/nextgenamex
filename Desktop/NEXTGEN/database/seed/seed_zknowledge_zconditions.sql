-- =============================================================================
-- AMEXAN Phase 2 — Seed Z6: condition layer + knowledge graph
-- =============================================================================
-- Conditions reference shared phenotypes/mechanisms/risk factors; the
-- generalized knowledge.relationship table holds cross-cutting edges.
-- =============================================================================

INSERT INTO knowledge.condition (id, concept_id, condition_code, canonical_name, description, condition_type) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-00000000000f', 'PNEUMONIA',
    'Pneumonia', 'Acute infection of the lung parenchyma', 'infectious'),
   ('f1000000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000010', 'TUBERCULOSIS',
    'Tuberculosis', 'Chronic infectious disease caused by mycobacterium tuberculosis', 'infectious'),
   ('f1000000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000011', 'ACUTE-BRONCHITIS',
    'Acute bronchitis', 'Inflammation of the large airways', 'acute')
ON CONFLICT (condition_code) DO NOTHING;

INSERT INTO knowledge.condition_system (condition_id, body_system_code, weight) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'RESPIRATORY', 1.0),
   ('f1000000-0000-0000-0000-000000000001', 'IMMUNE',      0.5),
   ('f1000000-0000-0000-0000-000000000002', 'RESPIRATORY', 1.0),
   ('f1000000-0000-0000-0000-000000000002', 'IMMUNE',      0.8),
   ('f1000000-0000-0000-0000-000000000002', 'CONSTITUTIONAL', 0.7),
   ('f1000000-0000-0000-0000-000000000003', 'RESPIRATORY', 1.0)
ON CONFLICT (condition_id, body_system_code) DO NOTHING;

INSERT INTO knowledge.condition_specialty (condition_id, specialty_code, weight) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'internal_medicine', 1.0),
   ('f1000000-0000-0000-0000-000000000001', 'family_medicine',   0.9),
   ('f1000000-0000-0000-0000-000000000001', 'emergency_medicine',0.7),
   ('f1000000-0000-0000-0000-000000000002', 'internal_medicine', 1.0),
   ('f1000000-0000-0000-0000-000000000002', 'family_medicine',   0.7),
   ('f1000000-0000-0000-0000-000000000003', 'family_medicine',   1.0),
   ('f1000000-0000-0000-0000-000000000003', 'internal_medicine', 0.8)
ON CONFLICT (condition_id, specialty_code) DO NOTHING;

INSERT INTO knowledge.condition_risk_factor (condition_id, risk_factor_concept_id, risk_factor_code, weight, description) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000007', 'SMOKING',           0.7, 'Smoking predisposes to pneumonia'),
   ('f1000000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000008', 'IMMUNOCOMPROMISED', 0.8, 'Immunocompromise raises pneumonia risk'),
   ('f1000000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000006', 'TB_EXPOSURE',       1.0, 'Known TB contact'),
   ('f1000000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000008', 'IMMUNOCOMPROMISED', 0.9, 'Immunocompromise predisposes to TB')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_complication (condition_id, complication_concept_id, complication_code, weight, description) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000015', 'RESPIRATORY_FAILURE', 0.8, 'Pneumonia may progress to respiratory failure'),
   ('f1000000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000016', 'HYPOXAEMIA',          0.7, 'Pneumonia commonly causes hypoxaemia'),
   ('f1000000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000016', 'HYPOXAEMIA',          0.5, 'Advanced TB may cause hypoxaemia')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_differential (condition_id, differential_condition_id, relationship_type, weight) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000003', 'differentiates', 0.6),
   ('f1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 'overlaps',       0.5),
   ('f1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000003', 'differentiates', 0.6),
   ('f1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 'differentiates', 0.6)
ON CONFLICT DO NOTHING;

-- Cross-layer junctions
INSERT INTO knowledge.mechanism_phenotype (mechanism_id, phenotype_id, weight) VALUES
   ('f0e00000-0000-0000-0000-000000000001', 'f0f00000-0000-0000-0000-000000000001', 0.9),
   ('f0e00000-0000-0000-0000-000000000002', 'f0f00000-0000-0000-0000-000000000001', 0.7),
   ('f0e00000-0000-0000-0000-000000000003', 'f0f00000-0000-0000-0000-000000000003', 0.8)
ON CONFLICT (mechanism_id, phenotype_id) DO NOTHING;

INSERT INTO knowledge.mechanism_condition (mechanism_id, condition_id, weight) VALUES
   ('f0e00000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 0.9),
   ('f0e00000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000003', 1.0),
   ('f0e00000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f0e00000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', 0.7)
ON CONFLICT (mechanism_id, condition_id) DO NOTHING;

INSERT INTO knowledge.mechanism_investigation (mechanism_id, investigation_concept_id, investigation_code, weight, rationale) VALUES
   ('f0e00000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000012', 'INV-CXR', 0.9, 'Chest X-ray for any lower airway process'),
   ('f0e00000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000012', 'INV-CXR', 1.0, 'Chest X-ray to confirm consolidation'),
   ('f0e00000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000014', 'INV-SPO2', 1.0, 'Pulse oximetry to assess gas exchange')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype_differential (phenotype_id, condition_id, relationship_type, weight) VALUES
   ('f0f00000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'suggestive_of', 0.9),
   ('f0f00000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000003', 'suggestive_of', 0.7),
   ('f0f00000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', 'suggestive_of', 0.9)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_phenotype (condition_id, phenotype_id, weight, is_suggestive) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'f0f00000-0000-0000-0000-000000000001', 0.9, true),
   ('f1000000-0000-0000-0000-000000000003', 'f0f00000-0000-0000-0000-000000000001', 0.6, true),
   ('f1000000-0000-0000-0000-000000000002', 'f0f00000-0000-0000-0000-000000000002', 0.9, true),
   ('f1000000-0000-0000-0000-000000000001', 'f0f00000-0000-0000-0000-000000000003', 0.6, false)
ON CONFLICT (condition_id, phenotype_id) DO NOTHING;

INSERT INTO knowledge.condition_mechanism (condition_id, mechanism_id, weight) VALUES
   ('f1000000-0000-0000-0000-000000000001', 'f0e00000-0000-0000-0000-000000000001', 0.8),
   ('f1000000-0000-0000-0000-000000000001', 'f0e00000-0000-0000-0000-000000000002', 1.0),
   ('f1000000-0000-0000-0000-000000000002', 'f0e00000-0000-0000-0000-000000000002', 0.9),
   ('f1000000-0000-0000-0000-000000000003', 'f0e00000-0000-0000-0000-000000000001', 1.0)
ON CONFLICT (condition_id, mechanism_id) DO NOTHING;

-- Generalized relationship edges (knowledge graph)
INSERT INTO knowledge.relationship
   (source_type, source_id, relationship_type, target_type, target_id, weight, polarity, context, confidence, evidence) VALUES
   ('condition', 'f1000000-0000-0000-0000-000000000002', 'associated_with', 'symptom',
    'f0b00000-0000-0000-0000-000000000005', 0.9, 'positive',
    jsonb_build_object('chronicity', 'chronic'), 0.9, 'WHO TB guidance: weight loss is a cardinal symptom'),
   ('condition', 'f1000000-0000-0000-0000-000000000002', 'associated_with', 'symptom',
    'f0b00000-0000-0000-0000-000000000006', 0.8, 'positive', NULL, 0.85, 'Night sweats are characteristic of TB'),
   ('symptom', 'f0b00000-0000-0000-0000-000000000001', 'asks', 'question',
    'f0c00000-0000-0000-0000-000000000001', 1.0, 'positive', NULL, 1.0, 'Productivity is core to cough assessment'),
   ('symptom', 'f0b00000-0000-0000-0000-000000000001', 'triggers', 'concept',
    'f0a00000-0000-0000-0000-000000000012', 0.6, 'positive', NULL, 0.8, 'Chronic cough triggers imaging consideration')
ON CONFLICT DO NOTHING;
