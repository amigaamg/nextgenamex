-- =============================================================================
-- AMEXAN Phase 2 — Seed Z3: symptom library
-- =============================================================================
-- Symptoms reference knowledge.concept ids defined in seed_zknowledge_base.sql.
-- =============================================================================

INSERT INTO knowledge.symptom (id, concept_id, symptom_code, canonical_name, definition, is_emergency) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000001', 'SYM-COUGH',
    'Cough', 'Expulsive expulsion of air from the airways', false),
   ('f0b00000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000002', 'SYM-FEVER',
    'Fever', 'Elevated body temperature', false),
   ('f0b00000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000003', 'SYM-DYSPNOEA',
    'Dyspnoea', 'Difficulty breathing / shortness of breath', true),
   ('f0b00000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000004', 'SYM-HAEMOPTYSIS',
    'Haemoptysis', 'Expectoration of blood from the airways', true),
   ('f0b00000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000009', 'SYM-WEIGHT-LOSS',
    'Unintentional weight loss', 'Unintentional weight loss over time', false),
   ('f0b00000-0000-0000-0000-000000000006', 'f0a00000-0000-0000-0000-00000000000a', 'SYM-NIGHT-SWEATS',
    'Night sweats', 'Profuse sweating during sleep', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO knowledge.symptom_synonym (symptom_id, synonym, language_code, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'Cough',       'en', true),
   ('f0b00000-0000-0000-0000-000000000001', 'Kikohozi',    'sw', true),
   ('f0b00000-0000-0000-0000-000000000002', 'Fever',       'en', true),
   ('f0b00000-0000-0000-0000-000000000002', 'Homa',        'sw', true),
   ('f0b00000-0000-0000-0000-000000000003', 'Shortness of breath', 'en', false),
   ('f0b00000-0000-0000-0000-000000000003', 'Upungufu wa pumzi',   'sw', true),
   ('f0b00000-0000-0000-0000-000000000004', 'Coughing blood',      'en', false),
   ('f0b00000-0000-0000-0000-000000000004', 'Kukohoa damu',        'sw', true),
   ('f0b00000-0000-0000-0000-000000000005', 'Weight loss', 'en', true),
   ('f0b00000-0000-0000-0000-000000000005', 'Kupoteza uzito', 'sw', true),
   ('f0b00000-0000-0000-0000-000000000006', 'Night sweats', 'en', true),
   ('f0b00000-0000-0000-0000-000000000006', 'Jasho usiku',  'sw', true)
ON CONFLICT (symptom_id, synonym) DO NOTHING;

INSERT INTO knowledge.symptom_translation (symptom_id, language_code, translation, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'sw', 'Kikohozi',          true),
   ('f0b00000-0000-0000-0000-000000000002', 'sw', 'Homa',              true),
   ('f0b00000-0000-0000-0000-000000000003', 'sw', 'Upungufu wa pumzi', true),
   ('f0b00000-0000-0000-0000-000000000004', 'sw', 'Kukohoa damu',      true),
   ('f0b00000-0000-0000-0000-000000000005', 'sw', 'Kupoteza uzito',    true),
   ('f0b00000-0000-0000-0000-000000000006', 'sw', 'Jasho usiku',       true)
ON CONFLICT (symptom_id, language_code, translation) DO NOTHING;

INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'RESPIRATORY',     1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'CARDIOVASCULAR',  0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'GASTROINTESTINAL',0.2),
   ('f0b00000-0000-0000-0000-000000000002', 'CONSTITUTIONAL',  1.0),
   ('f0b00000-0000-0000-0000-000000000002', 'RESPIRATORY',     0.5),
   ('f0b00000-0000-0000-0000-000000000002', 'IMMUNE',          0.6),
   ('f0b00000-0000-0000-0000-000000000003', 'RESPIRATORY',     1.0),
   ('f0b00000-0000-0000-0000-000000000003', 'CARDIOVASCULAR',  0.8),
   ('f0b00000-0000-0000-0000-000000000004', 'RESPIRATORY',     1.0),
   ('f0b00000-0000-0000-0000-000000000005', 'CONSTITUTIONAL',  1.0),
   ('f0b00000-0000-0000-0000-000000000005', 'GASTROINTESTINAL',0.4),
   ('f0b00000-0000-0000-0000-000000000005', 'ENDOCRINE',       0.3),
   ('f0b00000-0000-0000-0000-000000000006', 'CONSTITUTIONAL',  1.0),
   ('f0b00000-0000-0000-0000-000000000006', 'IMMUNE',          0.7)
ON CONFLICT (symptom_id, body_system_code) DO NOTHING;

INSERT INTO knowledge.symptom_specialty (symptom_id, specialty_code, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'internal_medicine',  1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'family_medicine',    1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'paediatrics',        0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'emergency_medicine', 0.7),
   ('f0b00000-0000-0000-0000-000000000002', 'family_medicine',    1.0),
   ('f0b00000-0000-0000-0000-000000000002', 'internal_medicine',  0.8),
   ('f0b00000-0000-0000-0000-000000000002', 'paediatrics',        0.9),
   ('f0b00000-0000-0000-0000-000000000002', 'emergency_medicine', 0.7),
   ('f0b00000-0000-0000-0000-000000000003', 'emergency_medicine', 1.0),
   ('f0b00000-0000-0000-0000-000000000003', 'internal_medicine',  0.9),
   ('f0b00000-0000-0000-0000-000000000003', 'family_medicine',    0.8),
   ('f0b00000-0000-0000-0000-000000000004', 'emergency_medicine', 1.0),
   ('f0b00000-0000-0000-0000-000000000004', 'internal_medicine',  0.9),
   ('f0b00000-0000-0000-0000-000000000004', 'family_medicine',    0.7),
   ('f0b00000-0000-0000-0000-000000000005', 'internal_medicine',  0.8),
   ('f0b00000-0000-0000-0000-000000000005', 'family_medicine',    1.0),
   ('f0b00000-0000-0000-0000-000000000006', 'internal_medicine',  0.9),
   ('f0b00000-0000-0000-0000-000000000006', 'family_medicine',    0.8)
ON CONFLICT (symptom_id, specialty_code) DO NOTHING;

INSERT INTO knowledge.symptom_relationship
   (symptom_id, related_symptom_id, relationship_type, weight, polarity) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000002', 'associated_with', 0.6, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000003', 'aggravates',      0.5, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000004', 'precedes',        0.2, 'positive'),
   ('f0b00000-0000-0000-0000-000000000002', 'f0b00000-0000-0000-0000-000000000006', 'associated_with', 0.5, 'positive'),
   ('f0b00000-0000-0000-0000-000000000002', 'f0b00000-0000-0000-0000-000000000005', 'associated_with', 0.4, 'positive'),
   ('f0b00000-0000-0000-0000-000000000006', 'f0b00000-0000-0000-0000-000000000005', 'associated_with', 0.6, 'positive')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.symptom_red_flag (symptom_id, red_flag_code, description, urgency) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-HAEMOPTYSIS', 'Coughing blood requires urgent evaluation', 'urgent'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-WEIGHT-LOSS', 'Cough with weight loss >2 weeks - rule out TB', 'urgent'),
   ('f0b00000-0000-0000-0000-000000000003', 'RF-DYSPNOEA-SPO2',     'Dyspnoea with SpO2 below 92% requires urgent oxygen', 'emergency'),
   ('f0b00000-0000-0000-0000-000000000003', 'RF-DYSPNOEA-STRIDOR',  'Stridor suggests upper airway obstruction - emergency', 'emergency'),
   ('f0b00000-0000-0000-0000-000000000004', 'RF-HAEMOPTYSIS-MASS',  'Major haemoptysis may indicate mass lesion', 'emergency'),
   ('f0b00000-0000-0000-0000-000000000002', 'RF-FEVER-MENINGISM',   'Fever with neck stiffness suggests meningitis', 'emergency')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.symptom_context (symptom_id, context_type_code, context_value_id, relevance, description) VALUES
   ('f0b00000-0000-0000-0000-000000000002', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='0-28D'), 1.0,
    'Fever in a neonate is a medical emergency'),
   ('f0b00000-0000-0000-0000-000000000002', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='65P'), 0.9,
    'Fever may be blunted in the elderly'),
   ('f0b00000-0000-0000-0000-000000000001', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='0-28D'), 0.7,
    'Cough in a neonate is uncommon - consider congenital disease')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.symptom_documentation (symptom_id, documentation_phrase, language_code, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'cough',                     'en', true),
   ('f0b00000-0000-0000-0000-000000000002', 'fever',                     'en', true),
   ('f0b00000-0000-0000-0000-000000000003', 'shortness of breath',       'en', true),
   ('f0b00000-0000-0000-0000-000000000004', 'haemoptysis',               'en', true),
   ('f0b00000-0000-0000-0000-000000000005', 'unintentional weight loss', 'en', true),
   ('f0b00000-0000-0000-0000-000000000006', 'night sweats',              'en', true)
ON CONFLICT DO NOTHING;
