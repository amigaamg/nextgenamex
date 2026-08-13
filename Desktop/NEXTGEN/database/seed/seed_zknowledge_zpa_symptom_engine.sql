-- =============================================================================
-- AMEXAN Universal Symptom Engine — Seed A: cough symptom objects, facts,
-- activation map, associated-symptom network, red flags
-- =============================================================================
-- Turns COUGH from a stub into a symptom knowledge object. Diseases (Pneumonia,
-- TB, Asthma, HF, GERD) are consumers of this infrastructure, not duplicated.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. New facts (clinical.fact_definition)
-- ---------------------------------------------------------------------------

INSERT INTO clinical.fact_definition (code, name, data_type, description) VALUES
   ('COUGH_TIMING',          'Cough timing',               'coded',   'When the cough is most prominent (morning / night / throughout)'),
   ('COUGH_CHARACTER',       'Cough character',            'coded',   'Quality of the cough (hacking / barking / paroxysmal / whooping)'),
   ('COUGH_TRIGGERS',        'Cough triggers',             'coded',   'What provokes the cough (cold air / exercise / lying flat / eating / talking)'),
   ('COUGH_RELIEVING',       'Cough relieving factors',    'coded',   'What eases the cough'),
   ('COUGH_POSITIONAL',      'Positional cough',           'boolean', 'Cough worse when lying flat'),
   ('SPUTUM_CONSISTENCY',    'Sputum consistency',         'coded',   'Watery / mucoid / purulent / frothy'),
   ('SPUTUM_ODOUR',          'Sputum odour',               'coded',   'Foul-smelling sputum'),
   ('RHINORRHOEA',           'Rhinorrhoea',                'coded',   'Runny nose'),
   ('SORE_THROAT',           'Sore throat',                'coded',   'Sore throat'),
   ('HOARSENESS',            'Hoarseness',                 'coded',   'Hoarse voice / loss of voice'),
   ('POSTNASAL_DRIP',        'Post-nasal drip',            'coded',   'Mucus dripping down the back of the throat'),
   ('LEG_SWELLING',          'Leg swelling',               'coded',   'Ankle / leg swelling'),
   ('HIV_STATUS',            'HIV status',                 'coded',   'Known HIV status'),
   ('IMMUNOSUPPRESSED',      'Immunosuppressed',           'coded',   'Immunosuppression (steroids / chemotherapy / transplant)'),
   ('SMOKING_PACK_YEARS',    'Smoking pack-years',         'numeric', 'Cumulative smoking exposure in pack-years'),
   ('OCCUPATIONAL_DUST',     'Occupational dust exposure', 'coded',   'Dust / fume / chemical exposure at work'),
   ('BIOMASS_EXPOSURE',      'Biomass fuel exposure',      'coded',   'Indoor cooking with wood / charcoal / dung'),
   ('ASPIRATION_RISK',       'Aspiration risk',            'coded',   'Cough or choke when eating / drinking'),
   ('DYSPHAGIA',             'Dysphagia',                  'coded',   'Difficulty swallowing'),
   ('ACE_INHIBITOR',         'ACE inhibitor use',          'coded',   'Current ACE inhibitor therapy'),
   ('VOICE_CHANGE',          'Voice change',               'coded',   'Deepening / change of voice'),
   ('SLEEP_DISTURBANCE',     'Sleep disturbance',          'coded',   'Cough keeps the patient awake at night'),
   ('WORK_ABSENCE',          'Work / school absence',      'coded',   'Missed work or school due to cough'),
   ('EXERCISE_INTOLERANCE',  'Exercise intolerance',       'coded',   'Cough limits walking / exercise'),
   ('FEEDING_DIFFICULTY',    'Feeding difficulty',         'coded',   'Cough makes feeding difficult (paediatric)'),
   ('DYSPNOEA_ONSET',        'Dyspnoea onset',             'coded',   'Sudden or gradual onset of breathlessness'),
   ('DYSPNOEA_SEVERITY',     'Dyspnoea severity',          'coded',   'Severity of breathlessness (mMRC-like)')
ON CONFLICT (code) DO NOTHING;

INSERT INTO terminology.unit (code, label, dimension, symbol, si_unit_code)
VALUES ('pack-years', 'pack-years', 'exposure', 'pk-yr', NULL)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Associated-symptom concepts + symptom objects (universal symptom library)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, description) VALUES
   ('f0a00000-0000-0000-0000-00000000003e', 'CNS-RHINORRHOEA',    'symptom', 'Rhinorrhoea',   'Rhinorrhoea',   'Runny / watery nasal discharge'),
   ('f0a00000-0000-0000-0000-00000000003f', 'CNS-SORE-THROAT',    'symptom', 'Sore throat',   'Sore throat',   'Pain or irritation of the throat'),
   ('f0a00000-0000-0000-0000-000000000040', 'CNS-HOARSENESS',     'symptom', 'Hoarseness',    'Hoarseness',    'Rough / breathy / strained voice'),
   ('f0a00000-0000-0000-0000-000000000041', 'CNS-POSTNASAL-DRIP', 'symptom', 'Post-nasal drip','Post-nasal drip','Mucus dripping down the throat from the nose'),
   ('f0a00000-0000-0000-0000-000000000042', 'CNS-ORTHOPNOEA',     'symptom', 'Orthopnoea',    'Orthopnoea',    'Breathlessness when lying flat'),
   ('f0a00000-0000-0000-0000-000000000043', 'CNS-PND',            'symptom', 'Paroxysmal nocturnal dyspnoea','PND','Sudden breathlessness waking from sleep'),
   ('f0a00000-0000-0000-0000-000000000044', 'CNS-LEG-SWELLING',   'symptom', 'Leg swelling',  'Leg swelling',  'Swelling of the ankles / legs'),
   ('f0a00000-0000-0000-0000-000000000045', 'CNS-HEARTBURN',      'symptom', 'Heartburn',     'Heartburn',     'Burning retrosternal discomfort / regurgitation')
ON CONFLICT (id) DO NOTHING;

INSERT INTO knowledge.symptom (id, concept_id, symptom_code, canonical_name, definition, is_emergency) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'f0a00000-0000-0000-0000-00000000003e', 'SYM-RHINORRHOEA',    'Rhinorrhoea',   'Runny / watery nasal discharge', false),
   ('f0b00000-0000-0000-0000-000000000008', 'f0a00000-0000-0000-0000-00000000003f', 'SYM-SORE-THROAT',    'Sore throat',   'Pain or irritation of the throat', false),
   ('f0b00000-0000-0000-0000-000000000009', 'f0a00000-0000-0000-0000-000000000040', 'SYM-HOARSENESS',     'Hoarseness',    'Rough / breathy / strained voice', false),
   ('f0b00000-0000-0000-0000-00000000000a', 'f0a00000-0000-0000-0000-000000000041', 'SYM-POSTNASAL-DRIP', 'Post-nasal drip','Mucus dripping down the throat', false),
   ('f0b00000-0000-0000-0000-00000000000b', 'f0a00000-0000-0000-0000-000000000042', 'SYM-ORTHOPNOEA',     'Orthopnoea',    'Breathlessness when lying flat', true),
   ('f0b00000-0000-0000-0000-00000000000c', 'f0a00000-0000-0000-0000-000000000043', 'SYM-PND',            'Paroxysmal nocturnal dyspnoea','Sudden nocturnal breathlessness', true),
   ('f0b00000-0000-0000-0000-00000000000d', 'f0a00000-0000-0000-0000-000000000044', 'SYM-LEG-SWELLING',   'Leg swelling',  'Swelling of the ankles / legs', false),
   ('f0b00000-0000-0000-0000-00000000000e', 'f0a00000-0000-0000-0000-000000000045', 'SYM-HEARTBURN',      'Heartburn',     'Burning retrosternal discomfort / regurgitation', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO knowledge.symptom_synonym (symptom_id, synonym, language_code, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'Runny nose',    'en', false),
   ('f0b00000-0000-0000-0000-000000000008', 'Throat pain',   'en', false),
   ('f0b00000-0000-0000-0000-00000000000b', 'Short of breath lying flat', 'en', false),
   ('f0b00000-0000-0000-0000-00000000000d', 'Ankle swelling', 'en', false)
ON CONFLICT (symptom_id, synonym) DO NOTHING;

INSERT INTO knowledge.symptom_translation (symptom_id, language_code, translation, is_preferred) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'sw', 'Utafutaji wa pua',   true),
   ('f0b00000-0000-0000-0000-000000000008', 'sw', 'Koo kuumwa',         true),
   ('f0b00000-0000-0000-0000-00000000000b', 'sw', 'Kukosa pumzi ukilala', true),
   ('f0b00000-0000-0000-0000-00000000000d', 'sw', 'Kuvimba kwa miguu',  true)
ON CONFLICT (symptom_id, language_code, translation) DO NOTHING;

INSERT INTO knowledge.symptom_system (symptom_id, body_system_code, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'RESPIRATORY', 0.9),
   ('f0b00000-0000-0000-0000-000000000008', 'RESPIRATORY', 0.8),
   ('f0b00000-0000-0000-0000-000000000009', 'RESPIRATORY', 0.7),
   ('f0b00000-0000-0000-0000-00000000000a', 'RESPIRATORY', 0.8),
   ('f0b00000-0000-0000-0000-00000000000b', 'CARDIOVASCULAR', 0.9),
   ('f0b00000-0000-0000-0000-00000000000b', 'RESPIRATORY', 0.7),
   ('f0b00000-0000-0000-0000-00000000000c', 'CARDIOVASCULAR', 0.9),
   ('f0b00000-0000-0000-0000-00000000000d', 'CARDIOVASCULAR', 0.9),
   ('f0b00000-0000-0000-0000-00000000000e', 'GASTROINTESTINAL', 1.0)
ON CONFLICT (symptom_id, body_system_code) DO NOTHING;

INSERT INTO knowledge.symptom_specialty (symptom_id, specialty_code, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000007', 'family_medicine', 1.0),
   ('f0b00000-0000-0000-0000-000000000008', 'family_medicine', 1.0),
   ('f0b00000-0000-0000-0000-000000000009', 'family_medicine', 0.9),
   ('f0b00000-0000-0000-0000-00000000000a', 'family_medicine', 0.9),
   ('f0b00000-0000-0000-0000-00000000000b', 'cardiology', 0.9),
   ('f0b00000-0000-0000-0000-00000000000b', 'internal_medicine', 0.8),
   ('f0b00000-0000-0000-0000-00000000000c', 'cardiology', 0.9),
   ('f0b00000-0000-0000-0000-00000000000d', 'cardiology', 0.9),
   ('f0b00000-0000-0000-0000-00000000000e', 'gastroenterology', 1.0)
ON CONFLICT (symptom_id, specialty_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Cough activation facts (data-driven symptom activation for ContextResolver)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_activation_fact (symptom_id, fact_definition_code, active_value, priority) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'COUGH_PRESENT',    'YES', 0),
   ('f0b00000-0000-0000-0000-000000000002', 'FEVER_PRESENT',    'YES', 0),
   ('f0b00000-0000-0000-0000-000000000003', 'DYSPNOEA_PRESENT', 'YES', 0),
   ('f0b00000-0000-0000-0000-000000000003', 'ORTHOPNOEA',       'YES', 5),
   ('f0b00000-0000-0000-0000-000000000004', 'BLOOD_IN_SPUTUM',  'YES', 0),
   ('f0b00000-0000-0000-0000-000000000007', 'RHINORRHOEA',      'YES', 0),
   ('f0b00000-0000-0000-0000-000000000008', 'SORE_THROAT',      'YES', 0),
   ('f0b00000-0000-0000-0000-000000000009', 'HOARSENESS',       'YES', 0),
   ('f0b00000-0000-0000-0000-00000000000a', 'POSTNASAL_DRIP',   'YES', 0),
   ('f0b00000-0000-0000-0000-00000000000b', 'ORTHOPNOEA',       'YES', 0),
   ('f0b00000-0000-0000-0000-00000000000c', 'PND',              'YES', 0),
   ('f0b00000-0000-0000-0000-00000000000d', 'LEG_SWELLING',     'YES', 0),
   ('f0b00000-0000-0000-0000-00000000000e', 'HEARTBURN',        'YES', 0)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Cough associated-symptom relationships
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_relationship
   (symptom_id, related_symptom_id, relationship_type, weight, polarity) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000007', 'associated_with', 0.7, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000008', 'associated_with', 0.7, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000009', 'associated_with', 0.3, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-00000000000a', 'associated_with', 0.5, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-00000000000b', 'aggravates',      0.4, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-00000000000c', 'aggravates',      0.4, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-00000000000d', 'associated_with', 0.3, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-00000000000e', 'aggravates',      0.4, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000005', 'associated_with', 0.6, 'positive'),
   ('f0b00000-0000-0000-0000-000000000001', 'f0b00000-0000-0000-0000-000000000006', 'associated_with', 0.5, 'positive')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Cough red flags (bound to facts so the CPU boosts them from data)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_red_flag (symptom_id, red_flag_code, description, urgency, evidence, fact_definition_code) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-STRIDOR',        'Stridor or high-pitched breathing with cough - airway obstruction', 'emergency', 'Immediate airway assessment', NULL),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-CYANOSIS',       'Cyanosis with cough suggests severe hypoxaemia', 'emergency', 'Emergency oxygenation', 'CYANOSIS'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-RESP-DISTRESS',  'Respiratory distress with cough requires urgent care', 'emergency', 'Assess work of breathing', 'RESPIRATORY_DISTRESS'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-CHEST-INDRAWING','Chest indrawing with cough - severe respiratory effort', 'emergency', 'Paediatric danger sign', 'CHEST_INDRAWING'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-SEVERE-DYSPNOEA','Cough with breathlessness at rest', 'emergency', 'Consider hypoxia / PE / severe pneumonia', 'DYSPNOEA_SEVERITY'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-FOUL-SPUTUM',    'Foul-smelling sputum - consider lung abscess / anaerobes', 'urgent', 'Sputum culture + CXR', 'SPUTUM_ODOUR'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-VOICE-CHANGE',   'Chronic cough with voice change in a smoker - exclude malignancy', 'urgent', 'CXR / referral', 'VOICE_CHANGE'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-ASPIRATION',     'Cough on eating/drinking - aspiration risk', 'urgent', 'Swallow assessment', 'ASPIRATION_RISK'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-FEEDING',        'Cough interfering with feeding (infant)', 'urgent', 'Paediatric assessment', 'FEEDING_DIFFICULTY'),
   ('f0b00000-0000-0000-0000-000000000001', 'RF-COUGH-IMMUNOCOMPROMISE','Cough in an immunocompromised patient - broad pathogens', 'urgent', 'Consider opportunistic infection', 'IMMUNOSUPPRESSED')
ON CONFLICT DO NOTHING;
