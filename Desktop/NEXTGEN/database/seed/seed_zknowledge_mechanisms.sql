-- =============================================================================
-- AMEXAN Phase 2 — Seed Z5: mechanisms + phenotype library
-- =============================================================================
-- Reusable pathophysiological patterns shared across conditions.
-- =============================================================================

INSERT INTO knowledge.mechanism (id, concept_id, mechanism_code, canonical_name, description, body_system_code) VALUES
   ('f0e00000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-00000000000b', 'MECH-AIRWAY-INFLAMMATION',
    'Airway inflammation', 'Inflammation of the conducting airways causing cough and secretions', 'RESPIRATORY'),
   ('f0e00000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-00000000000c', 'MECH-ALVEOLAR-INFLAMMATION',
    'Alveolar inflammation', 'Inflammation of the lung parenchyma and alveoli', 'RESPIRATORY'),
   ('f0e00000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-00000000000e', 'MECH-AIRWAY-OBSTRUCTION',
    'Airway obstruction', 'Obstruction or narrowing of the airways limiting airflow', 'RESPIRATORY'),
   ('f0e00000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-00000000000d', 'MECH-PLEURAL-INFLAMMATION',
    'Pleural inflammation', 'Inflammation of the pleural surfaces', 'RESPIRATORY')
ON CONFLICT (mechanism_code) DO NOTHING;

INSERT INTO knowledge.mechanism_feature (mechanism_id, feature_type, feature_code, weight, polarity) VALUES
   ('f0e00000-0000-0000-0000-000000000001', 'fact',    'COUGH_PRODUCTIVITY', 1.0, 'positive'),
   ('f0e00000-0000-0000-0000-000000000001', 'fact',    'COUGH_PRESENT',      0.8, 'positive'),
   ('f0e00000-0000-0000-0000-000000000001', 'symptom', 'SYM-COUGH',          1.0, 'positive'),
   ('f0e00000-0000-0000-0000-000000000002', 'fact',    'FEVER_PRESENT',      0.8, 'positive'),
   ('f0e00000-0000-0000-0000-000000000002', 'fact',    'DYSPNOEA_PRESENT',   0.7, 'positive'),
   ('f0e00000-0000-0000-0000-000000000003', 'fact',    'DYSPNOEA_PRESENT',   1.0, 'positive'),
   ('f0e00000-0000-0000-0000-000000000003', 'fact',    'COUGH_PRESENT',      0.5, 'positive'),
   ('f0e00000-0000-0000-0000-000000000004', 'symptom', 'SYM-COUGH',          0.7, 'positive'),
   ('f0e00000-0000-0000-0000-000000000004', 'fact',    'CHEST_PAIN_PLEURITIC', 0.9, 'positive')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype (id, concept_id, phenotype_code, canonical_name, description) VALUES
   ('f0f00000-0000-0000-0000-000000000001', NULL, 'PHEN-ACUTE-LRTI',
    'Acute lower respiratory infection', 'Acute productive cough with fever suggesting lower respiratory tract infection'),
   ('f0f00000-0000-0000-0000-000000000002', NULL, 'PHEN-CHRONIC-PRODUCTIVE',
    'Chronic productive cough', 'Chronic cough with sputum production, weight loss and night sweats - consider TB'),
   ('f0f00000-0000-0000-0000-000000000003', NULL, 'PHEN-HYPOXAEMIA',
    'Hypoxaemia', 'Low oxygen saturation with dyspnoea'),
   ('f0f00000-0000-0000-0000-000000000004', NULL, 'PHEN-RESPIRATORY-FAILURE',
    'Respiratory failure', 'Advanced respiratory compromise requiring urgent intervention')
ON CONFLICT (phenotype_code) DO NOTHING;

INSERT INTO knowledge.phenotype_feature (phenotype_id, feature_type, feature_code, operator, value, weight, polarity) VALUES
   ('f0f00000-0000-0000-0000-000000000001', 'fact',    'COUGH_PRODUCTIVITY', 'eq',    '"PRODUCTIVE"',  1.0, 'positive'),
   ('f0f00000-0000-0000-0000-000000000001', 'fact',    'FEVER_PRESENT',      'eq',    '"YES"',         0.8, 'positive'),
   ('f0f00000-0000-0000-0000-000000000001', 'fact',    'SPUTUM_COLOUR',      'in',    '["YELLOW_GREEN","RUSTY"]', 0.6, 'positive'),
   ('f0f00000-0000-0000-0000-000000000001', 'fact',    'COUGH_DURATION_DAYS','lte',   '14',            0.3, 'positive'),
   ('f0f00000-0000-0000-0000-000000000002', 'fact',    'COUGH_PRODUCTIVITY', 'eq',    '"PRODUCTIVE"',  0.8, 'positive'),
   ('f0f00000-0000-0000-0000-000000000002', 'fact',    'COUGH_DURATION_DAYS','gt',    '14',            0.9, 'positive'),
   ('f0f00000-0000-0000-0000-000000000002', 'fact',    'WEIGHT_LOSS',        'eq',    '"YES"',         0.9, 'positive'),
   ('f0f00000-0000-0000-0000-000000000002', 'fact',    'NIGHT_SWEATS',       'eq',    '"YES"',         0.8, 'positive'),
   ('f0f00000-0000-0000-0000-000000000002', 'fact',    'TB_CONTACT',         'eq',    '"YES"',         0.6, 'positive'),
   ('f0f00000-0000-0000-0000-000000000003', 'fact',    'DYSPNOEA_PRESENT',   'eq',    '"YES"',         0.8, 'positive'),
   ('f0f00000-0000-0000-0000-000000000003', 'measurement', 'SPO2',           'lt',    '92',            0.9, 'positive'),
   ('f0f00000-0000-0000-0000-000000000004', 'measurement', 'SPO2',           'lte',   '88',            1.0, 'positive'),
   ('f0f00000-0000-0000-0000-000000000004', 'fact',    'DYSPNOEA_PRESENT',   'eq',    '"YES"',         0.7, 'positive')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype_context (phenotype_id, context_type_code, context_value_id, applicability) VALUES
   ('f0f00000-0000-0000-0000-000000000001', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='65P'), 'applies'),
   ('f0f00000-0000-0000-0000-000000000002', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='65P'), 'applies')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype_documentation (phenotype_id, documentation_phrase, language_code, is_preferred) VALUES
   ('f0f00000-0000-0000-0000-000000000001', 'Acute lower respiratory tract infection', 'en', true),
   ('f0f00000-0000-0000-0000-000000000002', 'Chronic productive cough, constitutional symptoms', 'en', true),
   ('f0f00000-0000-0000-0000-000000000003', 'Hypoxaemia', 'en', true),
   ('f0f00000-0000-0000-0000-000000000004', 'Respiratory failure', 'en', true)
ON CONFLICT DO NOTHING;
