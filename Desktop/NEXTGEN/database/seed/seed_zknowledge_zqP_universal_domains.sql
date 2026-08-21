-- =============================================================================
-- AMEXAN Universal Entry — supplementary seed: departments + domain symptoms
-- Department/service rules need organization.service rows so a demo encounter can
-- be linked to a department through encounter_service (the CPU resolves
-- DEPARTMENT context through that chain). A small set of universal presenting
-- symptoms + body-system mappings lets SYMPTOM_DOMAIN format rules fire from the
-- knowledge graph (e.g. an obstetric complaint → OBGYN, a psychiatric complaint
-- → PSYCHIATRY).
-- =============================================================================

-- ---- 1. Core departments as organization.services ---------------------------
INSERT INTO organization.service (code, name, description, service_category, is_active) VALUES
  ('INTERNAL_MEDICINE',       'Internal Medicine',       'Adult medical care',               'CLINICAL', true),
  ('SURGERY',                 'Surgery',                 'Adult surgical care',              'CLINICAL', true),
  ('PEDIATRICS',              'Paediatrics',             'Child health',                     'CLINICAL', true),
  ('NEONATOLOGY',             'Neonatology',             'Newborn care',                     'CLINICAL', true),
  ('OBSTETRICS_GYNAECOLOGY',  'Obstetrics & Gynaecology','Women''s health, obstetrics',      'CLINICAL', true),
  ('PSYCHIATRY',              'Psychiatry',              'Mental health care',               'CLINICAL', true)
  ON CONFLICT DO NOTHING;

-- ---- 2. Universal presenting symptoms + their body-system domains -----------
-- A concept is required for each symptom row (knowledge.concept).
INSERT INTO knowledge.concept (concept_code, concept_type, canonical_name, description, status) VALUES
  ('CPT-LOW-MOOD',    'symptom', 'low mood',        'Persistently low or depressed mood', 'active'),
  ('CPT-ANXIETY',     'symptom', 'anxiety',         'Feelings of anxiety or worry',       'active'),
  ('CPT-VAG-BLEED',   'symptom', 'vaginal bleeding','Abnormal vaginal bleeding',          'active'),
  ('CPT-PREGNANCY',   'symptom', 'pregnancy',       'Pregnancy / expecting',              'active'),
  ('CPT-ABDO-PAIN',   'symptom', 'abdominal pain',  'Abdominal pain',                     'active'),
  ('CPT-CHEST-PAIN',  'symptom', 'chest pain',      'Chest pain',                         'active'),
  ('CPT-HEADACHE',    'symptom', 'headache',        'Headache',                           'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-LOW-MOOD',    'low mood',        'Persistently low or depressed mood', false, 'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-LOW-MOOD'
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-ANXIETY',     'anxiety',         'Feelings of anxiety or worry',       false, 'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-ANXIETY'
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-VAG-BLEED',   'vaginal bleeding','Abnormal vaginal bleeding',          true,  'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-VAG-BLEED'
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-PREGNANCY',   'pregnancy',       'Pregnancy / expecting',              false, 'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-PREGNANCY'
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-ABDO-PAIN',   'abdominal pain',  'Abdominal pain',                     true,  'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-ABDO-PAIN'
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-CHEST-PAIN',  'chest pain',      'Chest pain',                         true,  'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-CHEST-PAIN'
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom (symptom_code, canonical_name, definition, is_emergency, status, concept_id)
SELECT 'SYM-HEADACHE',    'headache',        'Headache',                           false, 'active', c.id FROM knowledge.concept c WHERE c.concept_code = 'CPT-HEADACHE'
    ON CONFLICT DO NOTHING;

-- Body-system mappings (domain resolution): psychiatric + obstetric + surgical.
INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance)
SELECT s.id, 'PSYCHIATRIC', 1.0 FROM knowledge.symptom s WHERE s.symptom_code IN ('SYM-LOW-MOOD', 'SYM-ANXIETY')
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance)
SELECT s.id, 'REPRODUCTIVE', 1.0 FROM knowledge.symptom s WHERE s.symptom_code IN ('SYM-VAG-BLEED', 'SYM-PREGNANCY')
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance)
SELECT s.id, 'GASTROINTESTINAL', 1.0 FROM knowledge.symptom s WHERE s.symptom_code IN ('SYM-ABDO-PAIN')
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance)
SELECT s.id, 'CARDIOVASCULAR', 1.0 FROM knowledge.symptom s WHERE s.symptom_code IN ('SYM-CHEST-PAIN')
    ON CONFLICT DO NOTHING;
INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance)
SELECT s.id, 'NEUROLOGICAL', 1.0 FROM knowledge.symptom s WHERE s.symptom_code IN ('SYM-HEADACHE')
    ON CONFLICT DO NOTHING;

SELECT 'Universal department + domain symptoms seeded';
