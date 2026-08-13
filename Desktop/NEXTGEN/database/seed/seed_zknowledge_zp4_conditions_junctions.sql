-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP4: Phase 1E conditions + knowledge graph junctions
-- =============================================================================
-- Adds the three MVP conditions (asthma, heart failure, GERD) and completes the
-- cross-layer graph so the full chain works:
--
--   symptom -> fact -> phenotype -> mechanism -> condition -> investigation
--                                                  -> medication -> protocol
--                                                  -> monitoring -> education
--
-- CAP/TB conditions and their junctions come from seed_zknowledge_zconditions.sql.
-- =============================================================================

INSERT INTO knowledge.condition (id, concept_id, condition_code, canonical_name, description, condition_type) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000019', 'ASTHMA',
    'Asthma', 'Chronic inflammatory airway disease with variable airflow limitation', 'chronic'),
   ('f1000000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-00000000001a', 'HEART-FAILURE',
    'Heart failure', 'Impaired cardiac pump function with pulmonary/systemic congestion', 'chronic'),
   ('f1000000-0000-0000-0000-000000000006', 'f0a00000-0000-0000-0000-00000000001b', 'GERD',
    'Gastroesophageal reflux disease', 'Reflux of gastric contents causing troublesome symptoms', 'chronic')
ON CONFLICT (condition_code) DO NOTHING;

INSERT INTO knowledge.condition_system (condition_id, body_system_code, weight) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'RESPIRATORY', 1.0),
   ('f1000000-0000-0000-0000-000000000005', 'CARDIOVASCULAR', 1.0),
   ('f1000000-0000-0000-0000-000000000005', 'RESPIRATORY', 0.7),
   ('f1000000-0000-0000-0000-000000000006', 'GASTROINTESTINAL', 1.0),
   ('f1000000-0000-0000-0000-000000000006', 'RESPIRATORY', 0.3)
ON CONFLICT (condition_id, body_system_code) DO NOTHING;

INSERT INTO knowledge.condition_specialty (condition_id, specialty_code, weight) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'respiratory_medicine', 1.0),
   ('f1000000-0000-0000-0000-000000000004', 'family_medicine',      0.9),
   ('f1000000-0000-0000-0000-000000000004', 'paediatrics',          0.8),
   ('f1000000-0000-0000-0000-000000000005', 'cardiology',           1.0),
   ('f1000000-0000-0000-0000-000000000005', 'internal_medicine',    0.9),
   ('f1000000-0000-0000-0000-000000000006', 'gastroenterology',     1.0),
   ('f1000000-0000-0000-0000-000000000006', 'family_medicine',      0.9)
ON CONFLICT (condition_id, specialty_code) DO NOTHING;

INSERT INTO knowledge.condition_risk_factor (condition_id, risk_factor_concept_id, risk_factor_code, weight, description) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000007', 'SMOKING',      0.6, 'Smoking aggravates asthma'),
   ('f1000000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000007', 'SMOKING',      0.6, 'Smoking is a cardiovascular risk factor'),
   ('f1000000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000008', 'IMMUNOCOMPROMISED', 0.3, 'Indirect cardiac risk')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_complication (condition_id, complication_concept_id, complication_code, weight, description) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000015', 'RESPIRATORY_FAILURE', 0.7, 'Severe acute asthma may cause respiratory failure'),
   ('f1000000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000016', 'HYPOXAEMIA',         0.6, 'Acute asthma may cause hypoxaemia'),
   ('f1000000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000016', 'HYPOXAEMIA',         0.8, 'Pulmonary oedema causes hypoxaemia')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_differential (condition_id, differential_condition_id, relationship_type, weight) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 'overlaps',       0.5),
   ('f1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000003', 'differentiates', 0.6),
   ('f1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 'mimics',         0.5),
   ('f1000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000002', 'differentiates', 0.4),
   ('f1000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000002', 'differentiates', 0.4),
   ('f1000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000001', 'differentiates', 0.3)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Cross-layer junctions completing the graph
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.mechanism_phenotype (mechanism_id, phenotype_id, weight) VALUES
   ('f0e00000-0000-0000-0000-000000000005', 'f0f00000-0000-0000-0000-000000000002', 0.9),
   ('f0e00000-0000-0000-0000-000000000006', 'f0f00000-0000-0000-0000-000000000006', 1.0),
   ('f0e00000-0000-0000-0000-000000000007', 'f0f00000-0000-0000-0000-000000000007', 1.0)
ON CONFLICT (mechanism_id, phenotype_id) DO NOTHING;

INSERT INTO knowledge.mechanism_condition (mechanism_id, condition_id, weight) VALUES
   ('f0e00000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000002', 1.0),
   ('f0e00000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000005', 1.0),
   ('f0e00000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000006', 1.0)
ON CONFLICT (mechanism_id, condition_id) DO NOTHING;

INSERT INTO knowledge.mechanism_investigation (mechanism_id, investigation_concept_id, investigation_code, weight, rationale) VALUES
   ('f0e00000-0000-0000-0000-000000000006', 'f0a00000-0000-0000-0000-000000000012', 'INV-CXR', 0.9, 'Chest X-ray to assess congestion/effusion'),
   ('f0e00000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000013', 'INV-SPUTUM-AFB', 1.0, 'Sputum AFB when chronic granulomatous infection suspected')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype_differential (phenotype_id, condition_id, relationship_type, weight) VALUES
   ('f0f00000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000004', 'suggestive_of', 0.9),
   ('f0f00000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000005', 'suggestive_of', 0.9),
   ('f0f00000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000001', 'suggestive_of', 0.3),
   ('f0f00000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000006', 'suggestive_of', 0.9)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_phenotype (condition_id, phenotype_id, weight, is_suggestive) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'f0f00000-0000-0000-0000-000000000005', 0.9, true),
   ('f1000000-0000-0000-0000-000000000005', 'f0f00000-0000-0000-0000-000000000006', 0.9, true),
   ('f1000000-0000-0000-0000-000000000006', 'f0f00000-0000-0000-0000-000000000007', 0.9, true)
ON CONFLICT (condition_id, phenotype_id) DO NOTHING;

INSERT INTO knowledge.condition_mechanism (condition_id, mechanism_id, weight) VALUES
   ('f1000000-0000-0000-0000-000000000004', 'f0e00000-0000-0000-0000-000000000003', 0.9),
   ('f1000000-0000-0000-0000-000000000004', 'f0e00000-0000-0000-0000-000000000001', 0.8),
   ('f1000000-0000-0000-0000-000000000005', 'f0e00000-0000-0000-0000-000000000006', 1.0),
   ('f1000000-0000-0000-0000-000000000006', 'f0e00000-0000-0000-0000-000000000007', 1.0)
ON CONFLICT (condition_id, mechanism_id) DO NOTHING;

-- Generalized relationship edges
INSERT INTO knowledge.relationship
   (source_type, source_id, relationship_type, target_type, target_id, weight, polarity, confidence, evidence) VALUES
   ('condition', 'f1000000-0000-0000-0000-000000000004', 'associated_with', 'symptom',
    'f0b00000-0000-0000-0000-000000000001', 0.8, 'positive', 0.9, 'Asthma commonly causes cough'),
   ('condition', 'f1000000-0000-0000-0000-000000000004', 'associated_with', 'symptom',
    'f0b00000-0000-0000-0000-000000000003', 0.9, 'positive', 0.9, 'Asthma causes episodic dyspnoea'),
   ('condition', 'f1000000-0000-0000-0000-000000000005', 'associated_with', 'symptom',
    'f0b00000-0000-0000-0000-000000000003', 1.0, 'positive', 0.95, 'Dyspnoea is cardinal in heart failure'),
   ('condition', 'f1000000-0000-0000-0000-000000000006', 'associated_with', 'symptom',
    'f0b00000-0000-0000-0000-000000000001', 0.6, 'positive', 0.7, 'Reflux may cause chronic cough')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Universal concept junctions for the new MVP concepts
-- (ONE concept, MANY systems, MANY departments, NO duplication)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.concept_system (concept_id, body_system_code, relevance, weight, description) VALUES
   ('f0a00000-0000-0000-0000-000000000017', 'CARDIOVASCULAR',   'primary',   1.0, 'Chest pain is a cardinal cardiovascular symptom'),
   ('f0a00000-0000-0000-0000-000000000017', 'RESPIRATORY',      'primary',   1.0, 'Pleuritic/respiratory causes of chest pain'),
   ('f0a00000-0000-0000-0000-000000000017', 'GASTROINTESTINAL', 'secondary', 0.5, 'Reflux/oesophageal causes of chest pain'),
   ('f0a00000-0000-0000-0000-000000000017', 'MUSCULOSKELETAL',  'secondary', 0.6, 'Chest wall / musculoskeletal pain'),
   ('f0a00000-0000-0000-0000-000000000018', 'GASTROINTESTINAL', 'primary',   1.0, 'Abdominal pain is a primary GI symptom'),
   ('f0a00000-0000-0000-0000-000000000018', 'RENAL_URINARY',    'secondary', 0.7, 'Renal/urinary causes of abdominal pain'),
   ('f0a00000-0000-0000-0000-000000000018', 'REPRODUCTIVE',     'secondary', 0.6, 'Gynaecological causes of abdominal pain'),
   ('f0a00000-0000-0000-0000-000000000019', 'RESPIRATORY',      'primary',   1.0, 'Asthma is a respiratory condition'),
   ('f0a00000-0000-0000-0000-00000000001a', 'CARDIOVASCULAR',   'primary',   1.0, 'Heart failure is a cardiac condition'),
   ('f0a00000-0000-0000-0000-00000000001a', 'RESPIRATORY',      'secondary', 0.7, 'Pulmonary congestion affects respiration'),
   ('f0a00000-0000-0000-0000-00000000001b', 'GASTROINTESTINAL', 'primary',   1.0, 'GERD is a GI condition'),
   ('f0a00000-0000-0000-0000-00000000001b', 'RESPIRATORY',      'related',   0.3, 'Reflux may cause cough'),
   ('f0a00000-0000-0000-0000-00000000003b', 'RESPIRATORY',      'primary',   1.0, 'Wheeze is a respiratory finding'),
   ('f0a00000-0000-0000-0000-00000000003c', 'RESPIRATORY',      'primary',   1.0, 'Crackles are a respiratory finding'),
   ('f0a00000-0000-0000-0000-00000000003d', 'RESPIRATORY',      'primary',   1.0, 'Pleuritic pain is a respiratory sign')
ON CONFLICT (concept_id, body_system_code) DO NOTHING;

INSERT INTO knowledge.concept_specialty (concept_id, specialty_code, relevance, weight, description) VALUES
   ('f0a00000-0000-0000-0000-000000000017', 'emergency_medicine',   'primary',   1.0, 'Chest pain is an emergency presentation'),
   ('f0a00000-0000-0000-0000-000000000017', 'cardiology',           'primary',   1.0, 'Cardiac causes of chest pain'),
   ('f0a00000-0000-0000-0000-000000000017', 'respiratory_medicine', 'secondary', 0.8, 'Respiratory causes of chest pain'),
   ('f0a00000-0000-0000-0000-000000000018', 'emergency_medicine',   'primary',   1.0, 'Abdominal pain is an emergency presentation'),
   ('f0a00000-0000-0000-0000-000000000018', 'gastroenterology',     'primary',   1.0, 'GI causes of abdominal pain'),
   ('f0a00000-0000-0000-0000-000000000018', 'surgery',              'secondary', 0.8, 'Surgical causes of abdominal pain'),
   ('f0a00000-0000-0000-0000-000000000019', 'respiratory_medicine', 'primary',   1.0, 'Asthma managed in respiratory medicine'),
   ('f0a00000-0000-0000-0000-000000000019', 'family_medicine',      'primary',   0.9, 'Asthma managed in primary care'),
   ('f0a00000-0000-0000-0000-00000000001a', 'cardiology',           'primary',   1.0, 'Heart failure managed in cardiology'),
   ('f0a00000-0000-0000-0000-00000000001a', 'internal_medicine',    'secondary', 0.9, 'Heart failure in general medicine'),
   ('f0a00000-0000-0000-0000-00000000001b', 'gastroenterology',     'primary',   1.0, 'GERD managed in gastroenterology'),
   ('f0a00000-0000-0000-0000-00000000001b', 'family_medicine',      'secondary', 0.9, 'GERD in primary care'),
   ('f0a00000-0000-0000-0000-00000000003b', 'respiratory_medicine', 'primary',   1.0, 'Wheeze assessed in respiratory medicine'),
   ('f0a00000-0000-0000-0000-00000000003c', 'respiratory_medicine', 'primary',   1.0, 'Crackles assessed in respiratory medicine')
ON CONFLICT (concept_id, specialty_code) DO NOTHING;
