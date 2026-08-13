-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP1: chest pain + abdominal pain symptoms
-- =============================================================================
-- Adds the two remaining universal MVP symptoms (chest pain, abdominal pain)
-- with their synonyms, systems, specialties, red flags and documentation.
-- Existing cough/fever/dyspnoea symptoms come from seed_zknowledge_symptoms.sql.
-- =============================================================================

INSERT INTO knowledge.symptom (id, concept_id, symptom_code, canonical_name, definition, is_emergency) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'f0a00000-0000-0000-0000-000000000017', 'SYM-CHEST-PAIN',
    'Chest pain', 'Pain or discomfort perceived in the chest', true),
   ('f0b00000-0000-0000-0000-000000000008', 'f0a00000-0000-0000-0000-000000000018', 'SYM-ABDO-PAIN',
    'Abdominal pain', 'Pain perceived within the abdomen', true)
ON CONFLICT (id) DO NOTHING;

-- Shortness of breath is a lay synonym of the existing dyspnoea symptom (no duplicate concept).
INSERT INTO knowledge.symptom_synonym (symptom_id, synonym, language_code, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000003', 'Shortness of breath', 'en', true)
ON CONFLICT (symptom_id, synonym) DO NOTHING;

INSERT INTO knowledge.symptom_synonym (symptom_id, synonym, language_code, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'Chest pain',            'en', true),
   ('f0b00000-0000-0000-0000-000000000007', 'Maumivu ya kifua',      'sw', true),
   ('f0b00000-0000-0000-0000-000000000008', 'Abdominal pain',        'en', true),
   ('f0b00000-0000-0000-0000-000000000008', 'Maumivu ya tumbo',      'sw', true)
ON CONFLICT (symptom_id, synonym) DO NOTHING;

INSERT INTO knowledge.symptom_translation (symptom_id, language_code, translation, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'sw', 'Maumivu ya kifua',   true),
   ('f0b00000-0000-0000-0000-000000000008', 'sw', 'Maumivu ya tumbo',   true)
ON CONFLICT (symptom_id, language_code, translation) DO NOTHING;

INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'CARDIOVASCULAR',  1.0),
   ('f0b00000-0000-0000-0000-000000000007', 'RESPIRATORY',     1.0),
   ('f0b00000-0000-0000-0000-000000000007', 'GASTROINTESTINAL',0.5),
   ('f0b00000-0000-0000-0000-000000000007', 'MUSCULOSKELETAL', 0.6),
   ('f0b00000-0000-0000-0000-000000000008', 'GASTROINTESTINAL',1.0),
   ('f0b00000-0000-0000-0000-000000000008', 'RENAL_URINARY',   0.7),
   ('f0b00000-0000-0000-0000-000000000008', 'REPRODUCTIVE',    0.6)
ON CONFLICT (symptom_id, body_system_code) DO NOTHING;

INSERT INTO knowledge.symptom_specialty (symptom_id, specialty_code, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'emergency_medicine',   1.0),
   ('f0b00000-0000-0000-0000-000000000007', 'cardiology',           1.0),
   ('f0b00000-0000-0000-0000-000000000007', 'respiratory_medicine', 0.8),
   ('f0b00000-0000-0000-0000-000000000007', 'internal_medicine',    0.8),
   ('f0b00000-0000-0000-0000-000000000008', 'emergency_medicine',   1.0),
   ('f0b00000-0000-0000-0000-000000000008', 'gastroenterology',     1.0),
   ('f0b00000-0000-0000-0000-000000000008', 'surgery',              0.8),
   ('f0b00000-0000-0000-0000-000000000008', 'family_medicine',      0.8)
ON CONFLICT (symptom_id, specialty_code) DO NOTHING;

INSERT INTO knowledge.symptom_red_flag (symptom_id, red_flag_code, description, urgency) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'RF-CHEST-PAIN-ACS',     'New severe crushing chest pain may indicate ACS - emergency', 'emergency'),
   ('f0b00000-0000-0000-0000-000000000007', 'RF-CHEST-PAIN-AORTIC',  'Tearing chest pain radiating to the back may indicate aortic dissection', 'emergency'),
   ('f0b00000-0000-0000-0000-000000000008', 'RF-ABDO-PAIN-PERFORATION', 'Sudden severe abdominal pain with rigidity suggests perforation', 'emergency'),
   ('f0b00000-0000-0000-0000-000000000008', 'RF-ABDO-PAIN-ETOPIC',   'Abdominal pain in a woman of reproductive age - exclude ectopic pregnancy', 'emergency')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.symptom_documentation (symptom_id, documentation_phrase, language_code, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'chest pain',   'en', true),
   ('f0b00000-0000-0000-0000-000000000008', 'abdominal pain', 'en', true)
ON CONFLICT DO NOTHING;
