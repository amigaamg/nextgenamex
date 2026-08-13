-- =============================================================================
-- AMEXAN Phase 2 — Seed Z2: context types/values + body systems
-- =============================================================================
-- Named seed_z* so it runs AFTER seed_reference (specialties exist).
-- =============================================================================

INSERT INTO knowledge.context_type (code, label, description) VALUES
   ('AGE',                      'Age band',            'Age range of the patient'),
   ('SEX',                      'Sex',                 'Biological sex'),
   ('PREGNANCY',                'Pregnancy status',    'Whether the patient is pregnant'),
   ('IMMUNOCOMPROMISED_STATUS', 'Immune status',       'Whether the patient is immunocompromised'),
   ('CARE_SETTING',             'Care setting',        'Where care is delivered'),
   ('ACUITY',                   'Acuity',              'Urgency of presentation'),
   ('SEASON',                   'Season',              'Seasonal context relevant to infectious diseases')
ON CONFLICT (code) DO NOTHING;

INSERT INTO knowledge.context_value (context_type_code, value, label, sort_order) VALUES
   ('AGE', '0-28D',  'Neonate (0-28 days)',    1),
   ('AGE', '1-11M',  'Infant (1-11 months)',   2),
   ('AGE', '1-4Y',   'Toddler (1-4 years)',    3),
   ('AGE', '5-17Y',  'Child (5-17 years)',     4),
   ('AGE', '18-64Y', 'Adult (18-64 years)',    5),
   ('AGE', '65P',    'Elderly (65+)',          6),
   ('SEX', 'male',   'Male',                   1),
   ('SEX', 'female', 'Female',                 2),
   ('PREGNANCY', 'pregnant',     'Pregnant',             1),
   ('PREGNANCY', 'not_pregnant', 'Not pregnant',         2),
   ('PREGNANCY', 'unknown',      'Unknown',              3),
   ('IMMUNOCOMPROMISED_STATUS', 'immunocompetent',    'Immunocompetent',    1),
   ('IMMUNOCOMPROMISED_STATUS', 'immunocompromised',  'Immunocompromised',  2),
   ('CARE_SETTING', 'outpatient',  'Outpatient',  1),
   ('CARE_SETTING', 'inpatient',   'Inpatient',   2),
   ('CARE_SETTING', 'emergency',   'Emergency',   3),
   ('ACUITY', 'routine',   'Routine',   1),
   ('ACUITY', 'urgent',    'Urgent',    2),
   ('ACUITY', 'emergency','Emergency', 3),
   ('SEASON', 'rainy', 'Rainy season', 1),
   ('SEASON', 'dry',   'Dry season',   2),
   ('SEASON', 'none',   'Not seasonal', 3)
ON CONFLICT (context_type_code, value) DO NOTHING;

INSERT INTO knowledge.context_relationship
   (context_type_code, source_value_id, target_value_id, relationship, description)
SELECT 'PREGNANCY', s.id, t.id, 'implies', 'Pregnancy implies the patient is female'
FROM knowledge.context_value s, knowledge.context_value t
WHERE s.context_type_code = 'PREGNANCY' AND s.value = 'pregnant'
  AND t.context_type_code = 'SEX'       AND t.value = 'female'
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.body_system (code, label, description) VALUES
   ('RESPIRATORY',     'Respiratory',      'Lungs, airways, pleura'),
   ('CARDIOVASCULAR',  'Cardiovascular',   'Heart and blood vessels'),
   ('GASTROINTESTINAL','Gastrointestinal','GI tract, liver, pancreas'),
   ('NEUROLOGICAL',    'Neurological',     'Brain, spinal cord, nerves'),
   ('MUSCULOSKELETAL', 'Musculoskeletal',  'Bones, joints, muscles'),
   ('RENAL_URINARY',   'Renal & Urinary',  'Kidneys, bladder, urinary tract'),
   ('ENDOCRINE',       'Endocrine',        'Hormone-producing glands'),
   ('HAEMATOLOGICAL',  'Haematological',   'Blood and blood-forming organs'),
   ('IMMUNE',          'Immune',           'Immune system'),
   ('INTEGUMENTARY',   'Skin',             'Skin, hair, nails'),
   ('REPRODUCTIVE',    'Reproductive',     'Reproductive organs'),
   ('PSYCHIATRIC',     'Psychiatric',      'Mental health'),
   ('CONSTITUTIONAL',  'Constitutional',   'Whole-body / general symptoms'),
   ('HEAD_NECK',       'Head & Neck',      'ENT, eyes, mouth, neck')
ON CONFLICT (code) DO NOTHING;
