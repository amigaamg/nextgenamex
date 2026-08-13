-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP2: Phase 1E questions (chest pain + cough completion)
-- =============================================================================
-- Questions are DATA. Each answer maps to a clinical fact so the CPU reasons
-- over medical truth. New question ids continue after seed_zknowledge_questions.sql.
-- =============================================================================

INSERT INTO knowledge.question (id, question_code, concept_id, question_type, text, response_type, priority) VALUES
   ('f0c00000-0000-0000-0000-00000000000d', 'CHEST_PAIN_PRESENT',    'f0a00000-0000-0000-0000-000000000017', 'clinical',
    'Do you have chest pain?', 'single_choice', 35),
   ('f0c00000-0000-0000-0000-00000000000e', 'CHEST_PAIN_PLEURITIC',  'f0a00000-0000-0000-0000-00000000003d', 'clinical',
    'Is the chest pain worse when you take a deep breath or cough?', 'single_choice', 45),
   ('f0c00000-0000-0000-0000-00000000000f', 'CHEST_PAIN_ONSET',      'f0a00000-0000-0000-0000-000000000017', 'clinical',
    'Did the chest pain start suddenly or gradually?', 'single_choice', 40),
   ('f0c00000-0000-0000-0000-000000000010', 'CHEST_PAIN_RADIATION',  'f0a00000-0000-0000-0000-000000000017', 'clinical',
    'Does the chest pain spread anywhere?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-000000000011', 'WHEEZE_PRESENT',        'f0a00000-0000-0000-0000-00000000003b', 'clinical',
    'Do you wheeze or make a whistling sound when breathing?', 'single_choice', 45),
   ('f0c00000-0000-0000-0000-000000000012', 'CHILLS',                'f0a00000-0000-0000-0000-000000000002', 'clinical',
    'Have you had chills or shivering?', 'single_choice', 45),
   ('f0c00000-0000-0000-0000-000000000013', 'SPUTUM_AMOUNT',         'f0a00000-0000-0000-0000-000000000005', 'clinical',
    'How much sputum do you bring up?', 'single_choice', 65),
   ('f0c00000-0000-0000-0000-000000000014', 'COUGH_SEVERITY',        'f0a00000-0000-0000-0000-000000000001', 'clinical',
    'How severe is the cough?', 'single_choice', 60)
ON CONFLICT (question_code) DO NOTHING;

INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, value_text, sort_order) VALUES
   ('f0d00000-0000-0000-0000-00000000001d', 'f0c00000-0000-0000-0000-00000000000d', 'YES',  'Yes', 'YES', 1),
   ('f0d00000-0000-0000-0000-00000000001e', 'f0c00000-0000-0000-0000-00000000000d', 'NO',   'No',  'NO',  2),
   ('f0d00000-0000-0000-0000-00000000001f', 'f0c00000-0000-0000-0000-00000000000e', 'YES',  'Yes', 'YES', 1),
   ('f0d00000-0000-0000-0000-000000000020', 'f0c00000-0000-0000-0000-00000000000e', 'NO',   'No',  'NO',  2),
   ('f0d00000-0000-0000-0000-000000000021', 'f0c00000-0000-0000-0000-00000000000f', 'SUDDEN','Sudden onset','SUDDEN', 1),
   ('f0d00000-0000-0000-0000-000000000022', 'f0c00000-0000-0000-0000-00000000000f', 'GRADUAL','Gradual onset','GRADUAL', 2),
   ('f0d00000-0000-0000-0000-000000000023', 'f0c00000-0000-0000-0000-000000000010', 'NONE',       'No spread',      'NONE', 1),
   ('f0d00000-0000-0000-0000-000000000024', 'f0c00000-0000-0000-0000-000000000010', 'LEFT_ARM',   'Left arm / shoulder', 'LEFT_ARM', 2),
   ('f0d00000-0000-0000-0000-000000000025', 'f0c00000-0000-0000-0000-000000000010', 'JAW',        'Jaw / neck',     'JAW', 3),
   ('f0d00000-0000-0000-0000-000000000026', 'f0c00000-0000-0000-0000-000000000010', 'BACK',       'Back',           'BACK', 4),
   ('f0d00000-0000-0000-0000-000000000027', 'f0c00000-0000-0000-0000-000000000011', 'YES',  'Yes', 'YES', 1),
   ('f0d00000-0000-0000-0000-000000000028', 'f0c00000-0000-0000-0000-000000000011', 'NO',   'No',  'NO',  2),
   ('f0d00000-0000-0000-0000-000000000029', 'f0c00000-0000-0000-0000-000000000012', 'YES',  'Yes', 'YES', 1),
   ('f0d00000-0000-0000-0000-00000000002a', 'f0c00000-0000-0000-0000-000000000012', 'NO',   'No',  'NO',  2),
   ('f0d00000-0000-0000-0000-00000000002b', 'f0c00000-0000-0000-0000-000000000013', 'SCANT',      'Scant',      'SCANT', 1),
   ('f0d00000-0000-0000-0000-00000000002c', 'f0c00000-0000-0000-0000-000000000013', 'MODERATE',   'Moderate',   'MODERATE', 2),
   ('f0d00000-0000-0000-0000-00000000002d', 'f0c00000-0000-0000-0000-000000000013', 'COPIOUS',    'Copious',    'COPIOUS', 3),
   ('f0d00000-0000-0000-0000-00000000002e', 'f0c00000-0000-0000-0000-000000000014', 'MILD',       'Mild',       'MILD', 1),
   ('f0d00000-0000-0000-0000-00000000002f', 'f0c00000-0000-0000-0000-000000000014', 'MODERATE',   'Moderate',   'MODERATE', 2),
   ('f0d00000-0000-0000-0000-000000000030', 'f0c00000-0000-0000-0000-000000000014', 'SEVERE',     'Severe',     'SEVERE', 3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO knowledge.fact_mapping (answer_option_id, fact_definition_code, value) VALUES
   ('f0d00000-0000-0000-0000-00000000001d', 'CHEST_PAIN_PRESENT',    'YES'),
   ('f0d00000-0000-0000-0000-00000000001e', 'CHEST_PAIN_PRESENT',    'NO'),
   ('f0d00000-0000-0000-0000-00000000001f', 'CHEST_PAIN_PLEURITIC',  'YES'),
   ('f0d00000-0000-0000-0000-000000000020', 'CHEST_PAIN_PLEURITIC',  'NO'),
   ('f0d00000-0000-0000-0000-000000000021', 'CHEST_PAIN_ONSET',      'SUDDEN'),
   ('f0d00000-0000-0000-0000-000000000022', 'CHEST_PAIN_ONSET',      'GRADUAL'),
   ('f0d00000-0000-0000-0000-000000000027', 'WHEEZE_PRESENT',        'YES'),
   ('f0d00000-0000-0000-0000-000000000028', 'WHEEZE_PRESENT',        'NO'),
   ('f0d00000-0000-0000-0000-000000000029', 'CHILLS',                'YES'),
   ('f0d00000-0000-0000-0000-00000000002a', 'CHILLS',                'NO'),
   ('f0d00000-0000-0000-0000-00000000002b', 'SPUTUM_AMOUNT',         'SCANT'),
   ('f0d00000-0000-0000-0000-00000000002c', 'SPUTUM_AMOUNT',         'MODERATE'),
   ('f0d00000-0000-0000-0000-00000000002d', 'SPUTUM_AMOUNT',         'COPIOUS'),
   ('f0d00000-0000-0000-0000-00000000002e', 'COUGH_SEVERITY',        'MILD'),
   ('f0d00000-0000-0000-0000-00000000002f', 'COUGH_SEVERITY',        'MODERATE'),
   ('f0d00000-0000-0000-0000-000000000030', 'COUGH_SEVERITY',        'SEVERE')
ON CONFLICT (answer_option_id, fact_definition_code) DO NOTHING;

INSERT INTO knowledge.question_trigger (question_id, trigger_type, trigger_concept_id, trigger_code, priority) VALUES
   ('f0c00000-0000-0000-0000-00000000000e', 'symptom', 'f0a00000-0000-0000-0000-000000000017', 'chest pain', 20),
   ('f0c00000-0000-0000-0000-00000000000f', 'symptom', 'f0a00000-0000-0000-0000-000000000017', 'chest pain', 20),
   ('f0c00000-0000-0000-0000-000000000010', 'symptom', 'f0a00000-0000-0000-0000-000000000017', 'chest pain', 30),
   ('f0c00000-0000-0000-0000-000000000011', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 35),
   ('f0c00000-0000-0000-0000-000000000012', 'symptom', 'f0a00000-0000-0000-0000-000000000002', 'fever', 35),
   ('f0c00000-0000-0000-0000-000000000013', 'fact',    'f0a00000-0000-0000-0000-000000000005', 'COUGH_PRODUCTIVITY', 30),
   ('f0c00000-0000-0000-0000-000000000014', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 25)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_requirement (question_id, requirement_level, condition, priority) VALUES
   ('f0c00000-0000-0000-0000-00000000000d', 'mandatory', NULL, 25),
   ('f0c00000-0000-0000-0000-00000000000e', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'CHEST_PAIN_PRESENT', 'value', 'YES')), 30),
   ('f0c00000-0000-0000-0000-00000000000f', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'CHEST_PAIN_PRESENT', 'value', 'YES')), 30),
   ('f0c00000-0000-0000-0000-000000000011', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'COUGH_PRESENT', 'value', 'YES')), 40),
   ('f0c00000-0000-0000-0000-000000000012', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'FEVER_PRESENT', 'value', 'YES')), 40),
   ('f0c00000-0000-0000-0000-000000000013', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'COUGH_PRODUCTIVITY', 'value', 'PRODUCTIVE')), 40)
ON CONFLICT DO NOTHING;
