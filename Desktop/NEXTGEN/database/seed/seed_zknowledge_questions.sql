-- =============================================================================
-- AMEXAN Phase 2 â€” Seed Z4: question engine (questions are DATA)
-- =============================================================================
-- Answers map to clinical facts so the CPU reasons over medical truth.
-- =============================================================================

INSERT INTO knowledge.question (id, question_code, concept_id, question_type, text, response_type, priority) VALUES
   ('f0c00000-0000-0000-0000-000000000001', 'COUGH_PRODUCTIVITY', 'f0a00000-0000-0000-0000-000000000001', 'clinical',
    'Is the cough productive?', 'single_choice', 40),
   ('f0c00000-0000-0000-0000-000000000002', 'COUGH_DURATION', 'f0a00000-0000-0000-0000-000000000001', 'clinical',
    'How long have you had the cough?', 'numeric', 30),
   ('f0c00000-0000-0000-0000-000000000003', 'COUGH_ONSET', 'f0a00000-0000-0000-0000-000000000001', 'clinical',
    'How did the cough begin?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-000000000004', 'SPUTUM_COLOUR', 'f0a00000-0000-0000-0000-000000000005', 'clinical',
    'What is the colour of the sputum?', 'single_choice', 60),
   ('f0c00000-0000-0000-0000-000000000005', 'BLOOD_IN_SPUTUM', 'f0a00000-0000-0000-0000-000000000004', 'clinical',
    'Have you noticed blood in your sputum?', 'single_choice', 55),
   ('f0c00000-0000-0000-0000-000000000006', 'FEVER_PRESENT', 'f0a00000-0000-0000-0000-000000000002', 'clinical',
    'Do you have a fever?', 'single_choice', 40),
   ('f0c00000-0000-0000-0000-000000000007', 'FEVER_ONSET', 'f0a00000-0000-0000-0000-000000000002', 'clinical',
    'When did the fever start?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-000000000008', 'TB_CONTACT', 'f0a00000-0000-0000-0000-000000000006', 'risk',
    'Have you had contact with anyone diagnosed with TB?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-000000000009', 'WEIGHT_LOSS', 'f0a00000-0000-0000-0000-000000000009', 'clinical',
    'Have you lost weight unintentionally?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-00000000000a', 'NIGHT_SWEATS', 'f0a00000-0000-0000-0000-00000000000a', 'clinical',
    'Do you experience night sweats?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-00000000000b', 'SMOKING_STATUS', 'f0a00000-0000-0000-0000-000000000007', 'risk',
    'Do you currently smoke or have you ever smoked?', 'single_choice', 50),
   ('f0c00000-0000-0000-0000-00000000000c', 'DYSPNOEA_PRESENT', 'f0a00000-0000-0000-0000-000000000003', 'clinical',
    'Do you feel short of breath?', 'single_choice', 45)
ON CONFLICT (question_code) DO NOTHING;

INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, value_text, sort_order) VALUES
   ('f0d00000-0000-0000-0000-000000000001', 'f0c00000-0000-0000-0000-000000000001', 'PRODUCTIVE',     'Yes, productive', 'PRODUCTIVE', 1),
   ('f0d00000-0000-0000-0000-000000000002', 'f0c00000-0000-0000-0000-000000000001', 'NON_PRODUCTIVE', 'No, dry',         'NON_PRODUCTIVE', 2),
   ('f0d00000-0000-0000-0000-000000000003', 'f0c00000-0000-0000-0000-000000000003', 'ACUTE',        'Acute (days)',     'ACUTE', 1),
   ('f0d00000-0000-0000-0000-000000000004', 'f0c00000-0000-0000-0000-000000000003', 'SUBACUTE',     'Subacute (weeks)', 'SUBACUTE', 2),
   ('f0d00000-0000-0000-0000-000000000005', 'f0c00000-0000-0000-0000-000000000003', 'CHRONIC',      'Chronic (months)', 'CHRONIC', 3),
   ('f0d00000-0000-0000-0000-000000000006', 'f0c00000-0000-0000-0000-000000000004', 'CLEAR',         'Clear / white',    'CLEAR', 1),
   ('f0d00000-0000-0000-0000-000000000007', 'f0c00000-0000-0000-0000-000000000004', 'YELLOW_GREEN', 'Yellow / green',   'YELLOW_GREEN', 2),
   ('f0d00000-0000-0000-0000-000000000008', 'f0c00000-0000-0000-0000-000000000004', 'RUSTY',        'Rusty / brown',    'RUSTY', 3),
   ('f0d00000-0000-0000-0000-000000000009', 'f0c00000-0000-0000-0000-000000000005', 'YES',          'Yes',              'YES', 1),
   ('f0d00000-0000-0000-0000-00000000000a', 'f0c00000-0000-0000-0000-000000000005', 'NO',           'No',               'NO', 2),
   ('f0d00000-0000-0000-0000-00000000000b', 'f0c00000-0000-0000-0000-000000000006', 'YES',          'Yes',              'YES', 1),
   ('f0d00000-0000-0000-0000-00000000000c', 'f0c00000-0000-0000-0000-000000000006', 'NO',           'No',               'NO', 2),
   ('f0d00000-0000-0000-0000-00000000000d', 'f0c00000-0000-0000-0000-000000000007', 'LESS_3_DAYS',  'Less than 3 days', 'LESS_3_DAYS', 1),
   ('f0d00000-0000-0000-0000-00000000000e', 'f0c00000-0000-0000-0000-000000000007', '3_7_DAYS',     '3 to 7 days',      '3_7_DAYS', 2),
   ('f0d00000-0000-0000-0000-00000000000f', 'f0c00000-0000-0000-0000-000000000007', 'OVER_7_DAYS',  'More than 7 days', 'OVER_7_DAYS', 3),
   ('f0d00000-0000-0000-0000-000000000010', 'f0c00000-0000-0000-0000-000000000008', 'YES',          'Yes',              'YES', 1),
   ('f0d00000-0000-0000-0000-000000000011', 'f0c00000-0000-0000-0000-000000000008', 'NO',           'No',               'NO', 2),
   ('f0d00000-0000-0000-0000-000000000012', 'f0c00000-0000-0000-0000-000000000008', 'UNKNOWN',      'Not sure',         'UNKNOWN', 3),
   ('f0d00000-0000-0000-0000-000000000013', 'f0c00000-0000-0000-0000-000000000009', 'YES',          'Yes',              'YES', 1),
   ('f0d00000-0000-0000-0000-000000000014', 'f0c00000-0000-0000-0000-000000000009', 'NO',           'No',               'NO', 2),
   ('f0d00000-0000-0000-0000-000000000015', 'f0c00000-0000-0000-0000-000000000009', 'UNKNOWN',      'Not sure',         'UNKNOWN', 3),
   ('f0d00000-0000-0000-0000-000000000016', 'f0c00000-0000-0000-0000-00000000000a', 'YES',          'Yes',              'YES', 1),
   ('f0d00000-0000-0000-0000-000000000017', 'f0c00000-0000-0000-0000-00000000000a', 'NO',           'No',               'NO', 2),
   ('f0d00000-0000-0000-0000-000000000018', 'f0c00000-0000-0000-0000-00000000000b', 'CURRENT',      'Current smoker',   'CURRENT', 1),
   ('f0d00000-0000-0000-0000-000000000019', 'f0c00000-0000-0000-0000-00000000000b', 'FORMER',       'Former smoker',    'FORMER', 2),
   ('f0d00000-0000-0000-0000-00000000001a', 'f0c00000-0000-0000-0000-00000000000b', 'NEVER',        'Never smoked',     'NEVER', 3),
   ('f0d00000-0000-0000-0000-00000000001b', 'f0c00000-0000-0000-0000-00000000000c', 'YES',          'Yes',              'YES', 1),
   ('f0d00000-0000-0000-0000-00000000001c', 'f0c00000-0000-0000-0000-00000000000c', 'NO',           'No',               'NO', 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO knowledge.fact_mapping (answer_option_id, fact_definition_code, value) VALUES
   ('f0d00000-0000-0000-0000-000000000001', 'COUGH_PRODUCTIVITY',  'PRODUCTIVE'),
   ('f0d00000-0000-0000-0000-000000000002', 'COUGH_PRODUCTIVITY',  'NON_PRODUCTIVE'),
   ('f0d00000-0000-0000-0000-000000000003', 'COUGH_ONSET',         'ACUTE'),
   ('f0d00000-0000-0000-0000-000000000004', 'COUGH_ONSET',         'SUBACUTE'),
   ('f0d00000-0000-0000-0000-000000000005', 'COUGH_ONSET',         'CHRONIC'),
   ('f0d00000-0000-0000-0000-000000000006', 'SPUTUM_COLOUR',       'CLEAR'),
   ('f0d00000-0000-0000-0000-000000000007', 'SPUTUM_COLOUR',       'YELLOW_GREEN'),
   ('f0d00000-0000-0000-0000-000000000008', 'SPUTUM_COLOUR',       'RUSTY'),
   ('f0d00000-0000-0000-0000-000000000009', 'BLOOD_IN_SPUTUM',     'YES'),
   ('f0d00000-0000-0000-0000-00000000000a', 'BLOOD_IN_SPUTUM',     'NO'),
   ('f0d00000-0000-0000-0000-00000000000b', 'FEVER_PRESENT',       'YES'),
   ('f0d00000-0000-0000-0000-00000000000c', 'FEVER_PRESENT',       'NO'),
   ('f0d00000-0000-0000-0000-00000000000d', 'FEVER_ONSET',         'LESS_3_DAYS'),
   ('f0d00000-0000-0000-0000-00000000000e', 'FEVER_ONSET',         '3_7_DAYS'),
   ('f0d00000-0000-0000-0000-00000000000f', 'FEVER_ONSET',         'OVER_7_DAYS'),
   ('f0d00000-0000-0000-0000-000000000010', 'TB_CONTACT',          'YES'),
   ('f0d00000-0000-0000-0000-000000000011', 'TB_CONTACT',          'NO'),
   ('f0d00000-0000-0000-0000-000000000012', 'TB_CONTACT',          'UNKNOWN'),
   ('f0d00000-0000-0000-0000-000000000013', 'WEIGHT_LOSS',         'YES'),
   ('f0d00000-0000-0000-0000-000000000014', 'WEIGHT_LOSS',         'NO'),
   ('f0d00000-0000-0000-0000-000000000015', 'WEIGHT_LOSS',         'UNKNOWN'),
   ('f0d00000-0000-0000-0000-000000000016', 'NIGHT_SWEATS',        'YES'),
   ('f0d00000-0000-0000-0000-000000000017', 'NIGHT_SWEATS',        'NO'),
   ('f0d00000-0000-0000-0000-000000000018', 'SMOKING_STATUS',      'CURRENT'),
   ('f0d00000-0000-0000-0000-000000000019', 'SMOKING_STATUS',      'FORMER'),
   ('f0d00000-0000-0000-0000-00000000001a', 'SMOKING_STATUS',      'NEVER'),
   ('f0d00000-0000-0000-0000-00000000001b', 'DYSPNOEA_PRESENT',    'YES'),
   ('f0d00000-0000-0000-0000-00000000001c', 'DYSPNOEA_PRESENT',    'NO')
ON CONFLICT (answer_option_id, fact_definition_code) DO NOTHING;

INSERT INTO knowledge.question_trigger (question_id, trigger_type, trigger_concept_id, trigger_code, priority) VALUES
   ('f0c00000-0000-0000-0000-000000000002', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 10),
   ('f0c00000-0000-0000-0000-000000000003', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 10),
   ('f0c00000-0000-0000-0000-000000000004', 'fact',    'f0a00000-0000-0000-0000-000000000005', 'COUGH_PRODUCTIVITY', 10),
   ('f0c00000-0000-0000-0000-000000000005', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 20),
   ('f0c00000-0000-0000-0000-000000000007', 'symptom', 'f0a00000-0000-0000-0000-000000000002', 'fever', 10),
   ('f0c00000-0000-0000-0000-000000000008', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 30),
   ('f0c00000-0000-0000-0000-000000000009', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 40),
   ('f0c00000-0000-0000-0000-00000000000a', 'symptom', 'f0a00000-0000-0000-0000-000000000002', 'fever', 30),
   ('f0c00000-0000-0000-0000-00000000000b', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 30),
   ('f0c00000-0000-0000-0000-00000000000c', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 30)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_requirement (question_id, requirement_level, condition, priority) VALUES
   ('f0c00000-0000-0000-0000-000000000002', 'mandatory', NULL, 10),
   ('f0c00000-0000-0000-0000-000000000003', 'mandatory', NULL, 10),
   ('f0c00000-0000-0000-0000-000000000001', 'mandatory', NULL, 20),
   ('f0c00000-0000-0000-0000-000000000004', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'COUGH_PRODUCTIVITY', 'value', 'PRODUCTIVE')), 20),
   ('f0c00000-0000-0000-0000-000000000005', 'mandatory', NULL, 20),
   ('f0c00000-0000-0000-0000-000000000006', 'mandatory', NULL, 20),
   ('f0c00000-0000-0000-0000-000000000008', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'COUGH_DURATION_DAYS', 'gt', 14)), 30),
   ('f0c00000-0000-0000-0000-000000000009', 'optional', NULL, 40),
   ('f0c00000-0000-0000-0000-00000000000a', 'optional', NULL, 40),
   ('f0c00000-0000-0000-0000-00000000000b', 'optional', NULL, 40),
   ('f0c00000-0000-0000-0000-00000000000c', 'conditionally_required',
    jsonb_build_object('fact', jsonb_build_object('code', 'COUGH_DURATION_DAYS', 'gt', 14)), 30)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_context (question_id, context_type_code, context_value_id, applicability, priority) VALUES
   ('f0c00000-0000-0000-0000-000000000008', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='0-28D'), 'excludes', 10),
   ('f0c00000-0000-0000-0000-00000000000b', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='0-28D'), 'excludes', 10),
   ('f0c00000-0000-0000-0000-00000000000b', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='1-11M'), 'excludes', 10)
ON CONFLICT DO NOTHING;
