-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H3 seed zq3: the question & rule engine
-- =============================================================================
-- Compiles the H3 QUESTION layer from H1 Hutchison claims. The DATABASE is the
-- engine: every "which question next?" decision here is DATA, never CPU code.
--
--    knowledge.question_module               — named banks (cough_core, sputum, ...)
--    knowledge.question_module_member        — bank → question membership
--    knowledge.question_rule                 — QR001..QR013 (the H3 heart)
--    knowledge.question_dependency           — socratic ordering / blocking
--    knowledge.question_rationale            — WHY each question is asked
--    knowledge.question_differential_weight  — how answers move the differentials
--    knowledge.documentation_requirement     — care-standard documentation
--    knowledge.history_completion_rule       — clinical completion (never 100%)
--    knowledge.question_requirement          — + 'safety' and 'high_priority' rows
--    knowledge.provenance                    — H1 claim → H3 object derivation edges
--
-- Every rule is deterministic and auditable: the claim code that grounds it is
-- stored on the row and mirrored as a provenance edge.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. question_module — named question banks
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_module (module_code, module_name, description, sort_order) VALUES
   ('COUGH_CORE',            'Cough core',           'Onset, duration, productivity, character and timing of the presenting cough.', 1),
   ('SPUTUM',                'Sputum bank',          'Sputum colour, amount, consistency and odour — only meaningful for a productive cough.', 2),
   ('DYSPNOEA',              'Dyspnoea bank',        'Breathlessness onset, severity (MRC), orthopnoea, PND and exercise tolerance.', 3),
   ('CHEST_PAIN',            'Chest pain bank',      'Pleuritic pain clarification: onset, character and radiation.', 4),
   ('FEVER',                 'Fever bank',           'Fever onset and chills — characterization of the systemic component.', 5),
   ('CHRONIC_COUGH',         'Chronic cough bank',   'Chronic-cough discrimination: timing, triggers, reflux, PND, TB, ACE-I, weight loss.', 6),
   ('HAEMOPTYSIS',           'Haemoptysis safety',   'Red-flag haemoptysis evaluation that must never be skipped.', 7),
   ('PAEDIATRIC_RESPIRATORY','Paediatric respiratory','Child-appropriate respiratory probes (feeding difficulty as dyspnoea surrogate).', 8),
   ('ADULT_RESPIRATORY',     'Adult respiratory',    'Adult risk history: smoking (status + pack-years), dust, biomass exposure.', 9),
   ('PREGNANCY_CONTEXT',     'Pregnancy context',    'Context adaptations for pregnant patients (reserved for disease modules).', 10)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. question_module_member — bank → question membership
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_module_member (module_code, question_id, sort_order)
SELECT m.module_code, q.id, x.sort_order
FROM (VALUES
   ('COUGH_CORE', 'COUGH_ONSET',       1),
   ('COUGH_CORE', 'COUGH_DURATION',    2),
   ('COUGH_CORE', 'COUGH_PRODUCTIVITY',3),
   ('COUGH_CORE', 'COUGH_CHARACTER',   4),
   ('COUGH_CORE', 'COUGH_TIMING',      5),
   ('COUGH_CORE', 'COUGH_SEVERITY',    6),
   ('SPUTUM',     'SPUTUM_COLOUR',     1),
   ('SPUTUM',     'SPUTUM_AMOUNT',     2),
   ('SPUTUM',     'SPUTUM_CONSISTENCY',3),
   ('SPUTUM',     'SPUTUM_ODOUR',      4),
   ('DYSPNOEA',   'DYSPNOEA_ONSET',    1),
   ('DYSPNOEA',   'DYSPNOEA_SEVERITY', 2),
   ('DYSPNOEA',   'ORTHOPNOEA_ASK',    3),
   ('DYSPNOEA',   'PND_ASK',           4),
   ('DYSPNOEA',   'EXERCISE_INTOLERANCE',5),
   ('CHEST_PAIN', 'CHEST_PAIN_ONSET',     1),
   ('CHEST_PAIN', 'CHEST_PAIN_PLEURITIC', 2),
   ('CHEST_PAIN', 'CHEST_PAIN_RADIATION', 3),
   ('FEVER',      'FEVER_ONSET',          1),
   ('FEVER',      'CHILLS',               2),
   ('CHRONIC_COUGH', 'COUGH_TIMING',      1),
   ('CHRONIC_COUGH', 'COUGH_POSITIONAL',  2),
   ('CHRONIC_COUGH', 'COUGH_TRIGGERS',    3),
   ('CHRONIC_COUGH', 'COUGH_RELIEVING',   4),
   ('CHRONIC_COUGH', 'POSTNASAL_DRIP',    5),
   ('CHRONIC_COUGH', 'HEARTBURN_ASK',     6),
   ('CHRONIC_COUGH', 'ACE_INHIBITOR',     7),
   ('CHRONIC_COUGH', 'TB_CONTACT',        8),
   ('CHRONIC_COUGH', 'NIGHT_SWEATS',      9),
   ('CHRONIC_COUGH', 'WEIGHT_LOSS',       10),
   ('HAEMOPTYSIS',   'BLOOD_IN_SPUTUM',   1),
   ('PAEDIATRIC_RESPIRATORY', 'FEEDING_DIFFICULTY', 1),
   ('ADULT_RESPIRATORY', 'SMOKING_STATUS',  1),
   ('ADULT_RESPIRATORY', 'SMOKING_PACK_YEARS', 2),
   ('ADULT_RESPIRATORY', 'OCCUPATIONAL_DUST', 3),
   ('ADULT_RESPIRATORY', 'BIOMASS_EXPOSURE',  4)
) AS x(module_code, question_code, sort_order)
JOIN knowledge.question_module m ON m.module_code = x.module_code
JOIN knowledge.question q ON q.question_code = x.question_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. question_rule — the H3 heart (QR001-QR013)
-- ---------------------------------------------------------------------------
-- trigger_type 'fact'    → fires when the fact is captured with the value below
-- trigger_type 'context' → fires when the patient context matches (AGE/PREGNANCY)
-- action ACTIVATE/DEACTIVATE; target_type question|symptom|module; priority_delta
-- re-weights the target without hard-coding order (delta is added by the CPU).
INSERT INTO knowledge.question_rule
    (rule_id, rule_name, trigger_type, trigger_code, trigger_operator, trigger_value,
     action, target_type, target_code, priority_delta, rationale, evidence_claim_code,
     version, status) VALUES
   ('QR001', 'cough present opens cough core', 'fact', 'COUGH_PRESENT', 'eq', '"YES"',
     'ACTIVATE', 'module', 'COUGH_CORE', 1000,
     'A cough that is present is the active problem; open the core cough bank.',
     'HCH12-0001', 1, 'active'),
   ('QR002', 'productive cough opens sputum bank', 'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"',
     'ACTIVATE', 'module', 'SPUTUM', 800,
     'Productive cough requires sputum characterization (colour, amount, consistency, odour).',
     'HCH12-0006', 1, 'active'),
   ('QR003', 'dry cough closes sputum bank', 'fact', 'COUGH_PRODUCTIVITY', 'eq', '"NON_PRODUCTIVE"',
     'DEACTIVATE', 'module', 'SPUTUM', -800,
     'Dry cough: sputum characterization is irrelevant and must not be asked.',
     'HCH12-0006', 1, 'active'),
   ('QR004', 'haemoptysis escalates to safety', 'fact', 'BLOOD_IN_SPUTUM', 'eq', '"YES"',
     'ACTIVATE', 'symptom', 'SYM-HAEMOPTYSIS', 950,
     'Haemoptysis must never be dismissed; escalate to the haemoptysis safety bank.',
     'HCH12-0007', 1, 'active'),
   ('QR005', 'dyspnoea opens dyspnoea bank', 'fact', 'DYSPNOEA_PRESENT', 'eq', '"YES"',
     'ACTIVATE', 'module', 'DYSPNOEA', 800,
     'Breathlessness is a cardinal respiratory symptom; characterize onset, severity, orthopnoea and PND.',
     'HCH12-0003', 1, 'active'),
   ('QR006', 'child uses paediatric bank', 'context', 'AGE', 'in', '["0-28D","1-11M","1-4Y"]',
     'ACTIVATE', 'module', 'PAEDIATRIC_RESPIRATORY', 500,
     'Children cannot report sputum or exertion; use observed descriptors (feeding difficulty).',
     'HCH1-0006', 1, 'active'),
   ('QR007', 'adult uses adult risk bank', 'context', 'AGE', 'in', '["5-17Y","18-64Y","65P"]',
     'ACTIVATE', 'module', 'ADULT_RESPIRATORY', 500,
     'Adults report productivity and exertion thresholds directly; capture smoking and exposure.',
     'HCH1-0006', 1, 'active'),
   ('QR008', 'pregnancy opens context bank', 'context', 'PREGNANCY', 'eq', '"pregnant"',
     'ACTIVATE', 'module', 'PREGNANCY_CONTEXT', 500,
     'Pregnancy changes the differential and investigation safety; activate context adaptations.',
     'HCH1-0006', 1, 'active'),
   ('QR009', 'fever opens fever bank', 'fact', 'FEVER_PRESENT', 'eq', '"YES"',
     'ACTIVATE', 'module', 'FEVER', 700,
     'Fever with cough points toward an infective lower-respiratory process; characterize it.',
     'HCH12-0020', 1, 'active'),
   ('QR010', 'chest pain opens chest pain bank', 'fact', 'CHEST_PAIN_PRESENT', 'eq', '"YES"',
     'ACTIVATE', 'module', 'CHEST_PAIN', 800,
     'Chest pain in respiratory disease needs site, character and radiation clarification.',
     'HCH12-0009', 1, 'active'),
   ('QR011', 'orthopnoea prioritizes dyspnoea severity', 'fact', 'ORTHOPNOEA', 'eq', '"YES"',
     'ACTIVATE', 'module', 'DYSPNOEA', 700,
     'Orthopnoea suggests a cardiopulmonary pattern; prioritize breathlessness severity.',
     'HCH12-0003', 1, 'active'),
   ('QR012', 'dyspnoea always graded (MRC)', 'fact', 'DYSPNOEA_PRESENT', 'eq', '"YES"',
     'ACTIVATE', 'question', 'DYSPNOEA_SEVERITY', 900,
     'Grade breathlessness on the MRC scale — a safety-relevant severity measure.',
     'HCH12-0021', 1, 'active'),
   ('QR013', 'subacute cough opens chronic bank', 'fact', 'COUGH_DURATION_DAYS', 'gt', '14',
     'ACTIVATE', 'module', 'CHRONIC_COUGH', 800,
     'A cough beyond two weeks is no longer clearly acute; open the chronic-cough discrimination bank.',
     'HCH12-0004', 1, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. question_dependency — socratic ordering / blocking
-- ---------------------------------------------------------------------------
-- A blocked question cannot be asked until the prerequisite holds; a
-- non-blocking dependency merely raises priority (ordering hint).
INSERT INTO knowledge.question_dependency
    (question_id, prerequisite_type, prerequisite_code, operator, value, is_blocking, priority, description)
SELECT q.id, x.prerequisite_type, x.prerequisite_code, x.operator, x.value::jsonb, x.is_blocking, x.priority, x.description
FROM (VALUES
   ('SPUTUM_COLOUR',      'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"',     true, 10, 'Sputum colour only if the cough is productive.'),
   ('SPUTUM_AMOUNT',      'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"',     true, 10, 'Sputum amount only if the cough is productive.'),
   ('SPUTUM_CONSISTENCY', 'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"',     true, 10, 'Sputum consistency only if the cough is productive.'),
   ('SPUTUM_ODOUR',       'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"',     true, 10, 'Sputum odour only if the cough is productive.'),
   ('CHILLS',             'fact', 'FEVER_PRESENT',      'eq', '"YES"',            true, 10, 'Chills belong to the fever characterization.'),
   ('FEVER_ONSET',        'fact', 'FEVER_PRESENT',      'eq', '"YES"',            true, 10, 'Fever onset belongs to the fever characterization.'),
   ('ORTHOPNOEA_ASK',     'fact', 'DYSPNOEA_PRESENT',   'eq', '"YES"',            true, 10, 'Orthopnoea is a dyspnoea characterization probe.'),
   ('PND_ASK',            'fact', 'DYSPNOEA_PRESENT',   'eq', '"YES"',            true, 10, 'PND is a dyspnoea characterization probe.'),
   ('DYSPNOEA_SEVERITY',  'fact', 'DYSPNOEA_PRESENT',   'eq', '"YES"',            true, 10, 'MRC grading only when breathlessness is present.'),
   ('CHEST_PAIN_ONSET',      'fact', 'CHEST_PAIN_PRESENT', 'eq', '"YES"',         true, 10, 'Pain onset belongs to the chest pain characterization.'),
   ('CHEST_PAIN_PLEURITIC',  'fact', 'CHEST_PAIN_PRESENT', 'eq', '"YES"',         true, 10, 'Pleuritic character belongs to the chest pain characterization.'),
   ('CHEST_PAIN_RADIATION',  'fact', 'CHEST_PAIN_PRESENT', 'eq', '"YES"',         true, 10, 'Radiation belongs to the chest pain characterization.'),
   ('SMOKING_PACK_YEARS', 'fact', 'SMOKING_STATUS',     'in', '["CURRENT","FORMER"]', false, 20, 'Pack-years only for current or former smokers (never for never-smokers).')
) AS x(question_code, prerequisite_type, prerequisite_code, operator, value, is_blocking, priority, description)
JOIN knowledge.question q ON q.question_code = x.question_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. question_rationale — WHY we ask (grounded in H1 claims)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_rationale (question_id, rationale_type, rationale, evidence_claim_code)
SELECT q.id, x.rationale_type, x.rationale, x.evidence_claim_code
FROM (VALUES
   ('FEVER_PRESENT',      'differential', 'Fever discriminates infective lower-respiratory disease (pneumonia) from non-infective airway disease.', 'HCH12-0020'),
   ('BLOOD_IN_SPUTUM',    'safety',       'Haemoptysis must never be dismissed; ask it explicitly because fear often makes patients hide it.', 'HCH12-0007'),
   ('ORTHOPNOEA_ASK',     'clinical',     'Orthopnoea suggests a cardiac (heart-failure) rather than pulmonary pattern of breathlessness.', 'HCH12-0003'),
   ('TB_CONTACT',         'differential', 'Exposure history is a core epidemiological discriminator for chronic cough and tuberculosis.', 'HCH12-0020'),
   ('SMOKING_STATUS',     'clinical',     '"Do you smoke?" is not enough; smoking history is required for respiratory risk assessment.', 'HCH12-0011'),
   ('FEEDING_DIFFICULTY', 'context',      'In young children feeding difficulty is the observable surrogate for breathlessness.', 'HCH1-0006'),
   ('CHEST_PAIN_PLEURITIC','differential','Pleuritic pain (sharp, worsened by breathing) points to pleural inflammation.', 'HCH12-0009'),
   ('DYSPNOEA_SEVERITY',  'clinical',     'The MRC scale grades breathlessness and is a safety-relevant severity measure.', 'HCH12-0021'),
   ('NIGHT_SWEATS',       'differential', 'Night sweats are a constitutional feature of TB and other chronic infections.', 'HCH12-0020'),
   ('COUGH_PRODUCTIVITY', 'clinical',     'Productivity splits the differential: productive favours infection, dry favours airway/reflux.', 'HCH12-0006'),
   ('WHEEZE_PRESENT',     'differential', 'Wheeze may be noticed by others, not the patient; ask explicitly for airway disease.', 'HCH12-0008'),
   ('HEARTBURN_ASK',      'differential', 'Reflux (GORD) is a common chronic-cough cause; ask about it directly.', 'HCH12-0020')
) AS x(question_code, rationale_type, rationale, evidence_claim_code)
JOIN knowledge.question q ON q.question_code = x.question_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. question_differential_weight — how answers move the differentials
-- ---------------------------------------------------------------------------
-- condition_id resolves to knowledge.condition by condition_code. answer_value
-- carries the weight; NULL would mean "any answer".
INSERT INTO knowledge.question_differential_weight
    (question_id, condition_id, answer_value, weight, evidence_claim_code)
SELECT q.id, c.id, x.answer_value, x.weight, x.evidence_claim_code
FROM (VALUES
   ('FEVER_PRESENT',       'PNEUMONIA',     'YES',        3,  'HCH12-0020'),
   ('FEVER_PRESENT',       'PNEUMONIA',     'NO',        -2,  'HCH12-0020'),
   ('CHILLS',              'PNEUMONIA',     'YES',        2,  'HCH12-0020'),
   ('TB_CONTACT',          'TUBERCULOSIS',  'YES',        5,  'HCH12-0020'),
   ('TB_CONTACT',          'TUBERCULOSIS',  'NO',        -1,  'HCH12-0020'),
   ('ORTHOPNOEA_ASK',      'HEART-FAILURE', 'YES',        5,  'HCH12-0003'),
   ('ORTHOPNOEA_ASK',      'HEART-FAILURE', 'NO',        -3,  'HCH12-0003'),
   ('WHEEZE_PRESENT',      'ASTHMA',        'YES',        4,  'HCH12-0008'),
   ('BLOOD_IN_SPUTUM',     'TUBERCULOSIS',  'YES',        4,  'HCH12-0007'),
   ('BLOOD_IN_SPUTUM',     'PNEUMONIA',     'YES',        2,  'HCH12-0007'),
   ('SMOKING_STATUS',      'ACUTE-BRONCHITIS','CURRENT',  2,  'HCH12-0011'),
   ('SMOKING_STATUS',      'ACUTE-BRONCHITIS','FORMER',   1,  'HCH12-0011'),
   ('NIGHT_SWEATS',        'TUBERCULOSIS',  'YES',        3,  'HCH12-0020'),
   ('WEIGHT_LOSS',         'TUBERCULOSIS',  'YES',        2,  'HCH12-0020'),
   ('COUGH_PRODUCTIVITY',  'ACUTE-BRONCHITIS','PRODUCTIVE',2, 'HCH12-0006'),
   ('HEARTBURN_ASK',       'GERD',          'YES',        4,  'HCH12-0020'),
   ('CHEST_PAIN_PLEURITIC','PNEUMONIA',     'YES',        2,  'HCH12-0009'),
   ('FEEDING_DIFFICULTY',  'PNEUMONIA',     'YES',        1,  'HCH1-0006')
) AS x(question_code, condition_code, answer_value, weight, evidence_claim_code)
JOIN knowledge.question q ON q.question_code = x.question_code
JOIN knowledge.condition c ON c.condition_code = x.condition_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. documentation_requirement — the care standard for a cough presentation
-- ---------------------------------------------------------------------------
-- condition uses the CPU fact-condition shape:
--   NULL → always required; {"fact":{"code":"COUGH_PRESENT","value":"YES"}} → required when present.
INSERT INTO knowledge.documentation_requirement
    (section_code, required_fact_code, condition, priority, is_required, evidence_claim_code)
SELECT x.section_code, x.required_fact_code, x.condition::jsonb, x.priority, true, x.evidence_claim_code
FROM (VALUES
   ('HPI',       'COUGH_ONSET',        '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 10, 'HCH12-0005'),
   ('HPI',       'COUGH_DURATION_DAYS','{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 10, 'HCH12-0004'),
   ('HPI',       'COUGH_PRODUCTIVITY', '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 10, 'HCH12-0006'),
   ('HPI',       'SPUTUM_COLOUR',      '{"fact":{"code":"COUGH_PRODUCTIVITY","value":"PRODUCTIVE"}}', 10, 'HCH12-0006'),
   ('HPI',       'SPUTUM_AMOUNT',      '{"fact":{"code":"COUGH_PRODUCTIVITY","value":"PRODUCTIVE"}}', 10, 'HCH12-0006'),
   ('HPI',       'DYSPNOEA_PRESENT',   '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 10, 'HCH12-0001'),
   ('HPI',       'DYSPNOEA_SEVERITY',  '{"fact":{"code":"DYSPNOEA_PRESENT","value":"YES"}}', 10, 'HCH12-0021'),
   ('RED_FLAGS', 'BLOOD_IN_SPUTUM',    '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 20, 'HCH12-0007'),
   ('HPI',       'FEVER_PRESENT',      '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 10, 'HCH12-0020')
) AS x(section_code, required_fact_code, condition, priority, evidence_claim_code)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. history_completion_rule — clinical completion, never 100%
-- ---------------------------------------------------------------------------
-- A cough history is complete when onset, duration and productivity are
-- established AND sputum is either non-applicable (dry) or characterized AND
-- breathlessness is either excluded or graded AND the haemoptysis red flag is
-- resolved. The engine must not chase the whole bank.
INSERT INTO knowledge.history_completion_rule (rule_id, subject_type, subject_code, condition, description) VALUES
   ('HCR-COUGH', 'symptom', 'SYM-COUGH',
     '{"and":[{"fact":"COUGH_ONSET"},{"fact":"COUGH_DURATION_DAYS"},{"fact":"COUGH_PRODUCTIVITY"},{"or":[{"fact":"COUGH_PRODUCTIVITY","value":"NON_PRODUCTIVE"},{"and":[{"fact":"SPUTUM_COLOUR"},{"fact":"SPUTUM_AMOUNT"}]}]},{"or":[{"fact":"DYSPNOEA_PRESENT","value":"NO"},{"fact":"DYSPNOEA_SEVERITY"}]},{"fact":"BLOOD_IN_SPUTUM"}]}',
     'Cough history is complete when onset, duration, productivity (and sputum when productive), dyspnoea status/severity and the haemoptysis red flag are established.'),
   ('HCR-CHEST-PAIN', 'symptom', 'SYM-CHEST-PAIN',
     '{"and":[{"fact":"CHEST_PAIN_PRESENT"},{"or":[{"fact":"CHEST_PAIN_ONSET"},{"fact":"CHEST_PAIN_PLEURITIC"},{"fact":"CHEST_PAIN_RADIATION"}]},{"or":[{"fact":"CHEST_PAIN_PLEURITIC","value":"YES"},{"fact":"CHEST_PAIN_PLEURITIC","value":"NO"}]}]}',
     'Chest pain history is complete when presence, character (pleuritic vs not) and at least one characterization dimension are established.')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9. question_requirement — H3 mandatory levels (safety / high_priority)
-- ---------------------------------------------------------------------------
-- L1 universal foundations stay 'mandatory'. L3 safety probes outrank them.
-- high_priority sits between conditionally_required and optional.
INSERT INTO knowledge.question_requirement (question_id, requirement_level, condition, priority)
SELECT q.id, x.requirement_level, x.condition::jsonb, x.priority
FROM (VALUES
   ('DYSPNOEA_SEVERITY', 'safety', '{"fact":{"code":"DYSPNOEA_PRESENT","value":"YES"}}', 1),
   ('BLOOD_IN_SPUTUM',   'safety', '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}',    1),
   ('CHEST_PAIN_ONSET',  'safety', '{"fact":{"code":"CHEST_PAIN_PRESENT","value":"YES"}}',1),
   ('DYSPNOEA_PRESENT',  'high_priority', '{"fact":{"code":"COUGH_PRESENT","value":"YES"}}', 1),
   ('COUGH_PRODUCTIVITY','high_priority', '{}', 2),
   ('FEVER_PRESENT',     'high_priority', '{}', 2),
   ('SMOKING_STATUS',    'high_priority', '{}', 3)
) AS x(question_code, requirement_level, condition, priority)
JOIN knowledge.question q ON q.question_code = x.question_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 10. provenance — H1 claim → H3 object derivation edges
-- ---------------------------------------------------------------------------
-- Deterministic uuid5 object ids (namespace 6ba7b810-9dad-11d1-80b4-00c04fd430c8,
-- scheme "H3:<object_type>:<object_code>") so edges are stable across rebuilds.
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, x.object_type, x.object_id::uuid, x.object_code, 'derived_from'
FROM (VALUES
   -- question_rules
   ('HCH12-0001', 'question_rule', 'bf78a8f5-3126-5cfa-ae72-4d4d7024e536', 'QR001'),
   ('HCH12-0006', 'question_rule', '7bb733f5-98bb-55e4-88fe-e20751c959c7', 'QR002'),
   ('HCH12-0006', 'question_rule', '35dcdf45-19c2-5414-9740-6ac0c43f7260', 'QR003'),
   ('HCH12-0007', 'question_rule', 'ba4fd598-b026-54b2-856b-299aafc739dc', 'QR004'),
   ('HCH12-0003', 'question_rule', '343c6114-e409-5e34-adbc-0ffedb925888', 'QR005'),
   ('HCH1-0006',  'question_rule', '97d54826-607f-59b0-bc6f-e3775f56cd03', 'QR006'),
   ('HCH1-0006',  'question_rule', '4b243d13-1d4d-54fa-a52a-d91b59152576', 'QR007'),
   ('HCH1-0006',  'question_rule', '014e6082-724e-5506-a2c8-6bbaa24396b6', 'QR008'),
   ('HCH12-0020', 'question_rule', 'f5726e9b-9d21-5840-a741-9a7336869ee0', 'QR009'),
   ('HCH12-0009', 'question_rule', '1a2da0b5-61d2-52c4-b7bf-fe4baba2021d', 'QR010'),
   ('HCH12-0003', 'question_rule', '9fd53fb4-5894-50a1-a857-ae262db402f1', 'QR011'),
   ('HCH12-0021', 'question_rule', 'ec2e15b7-b23b-5617-a03a-f83ca765c588', 'QR012'),
   ('HCH12-0004', 'question_rule', '75ca0cfc-4fe2-5c13-b150-57016e5dbba9', 'QR013'),
   -- question_dependencies
   ('HCH12-0006', 'question_dependency', 'c628f33e-4a53-56be-908a-5a7ac1d4459a', 'SPUTUM_COLOUR'),
   ('HCH12-0006', 'question_dependency', 'cc15baed-76ef-5817-99ed-b6ac34584b44', 'SPUTUM_AMOUNT'),
   ('HCH12-0006', 'question_dependency', 'fecab624-663e-5c91-a073-7847fd2874b7', 'SPUTUM_CONSISTENCY'),
   ('HCH12-0006', 'question_dependency', '804926d6-9d42-5d8d-9689-111849c4cec1', 'SPUTUM_ODOUR'),
   ('HCH12-0020', 'question_dependency', 'a2f2f249-3deb-544f-9982-98d482af450f', 'CHILLS'),
   ('HCH12-0020', 'question_dependency', 'bb60a729-789e-5093-94aa-5a7befff7ec1', 'FEVER_ONSET'),
   ('HCH12-0003', 'question_dependency', 'efdda46b-71c2-5dce-9bbf-c9854f8d10aa', 'ORTHOPNOEA_ASK'),
   ('HCH12-0003', 'question_dependency', '59fcad9f-c8db-510b-acf4-091854b43b31', 'PND_ASK'),
   ('HCH12-0021', 'question_dependency', 'b78590d7-3276-5ac6-a858-4b6ed84f7610', 'DYSPNOEA_SEVERITY'),
   ('HCH12-0009', 'question_dependency', 'f57b77ab-a9d9-5131-a81d-e3cecfa595b6', 'CHEST_PAIN_ONSET'),
   ('HCH12-0009', 'question_dependency', '85a3b2d1-8277-54f8-8ad2-2b8927fad71a', 'CHEST_PAIN_PLEURITIC'),
   ('HCH12-0009', 'question_dependency', '613265d9-60a2-5cdd-a03c-bd3bf3a24562', 'CHEST_PAIN_RADIATION'),
   ('HCH12-0011', 'question_dependency', '12d54816-cf2c-5427-beef-e451d0bd8bde', 'SMOKING_PACK_YEARS'),
   -- question_rationales
   ('HCH12-0020', 'question_rationale', '1c15d6d3-f098-5fae-89bc-3d3489ed36ed', 'FEVER_PRESENT'),
   ('HCH12-0007', 'question_rationale', '9f153ad5-52a8-58ec-818e-fc225513444d', 'BLOOD_IN_SPUTUM'),
   ('HCH12-0003', 'question_rationale', '08aae430-742c-5427-9d46-2e4d53b3773f', 'ORTHOPNOEA_ASK'),
   ('HCH12-0020', 'question_rationale', '2d4e53e0-acd2-572a-97b0-5aaa5cb18bc5', 'TB_CONTACT'),
   ('HCH12-0011', 'question_rationale', 'd3cb622e-ad69-5a25-b746-d6186de7e1cf', 'SMOKING_STATUS'),
   ('HCH1-0006',  'question_rationale', '84188367-52c3-5308-bc9f-f2a92a865de7', 'FEEDING_DIFFICULTY'),
   ('HCH12-0009', 'question_rationale', 'f49da71d-ceb8-589c-a7c8-9040dfe4b04f', 'CHEST_PAIN_PLEURITIC'),
   ('HCH12-0021', 'question_rationale', '0ee59e19-c359-56d6-bc46-859e6b5c3a62', 'DYSPNOEA_SEVERITY'),
   ('HCH12-0020', 'question_rationale', 'e4cfd13b-5ab3-5694-a799-47daab34bd1e', 'NIGHT_SWEATS'),
   ('HCH12-0006', 'question_rationale', 'ef2cf0fc-e9ae-5f1d-b7b9-f0a09102a26a', 'COUGH_PRODUCTIVITY'),
   ('HCH12-0008', 'question_rationale', '0aafb63d-75e9-5fb6-bacc-445b79a4f7c9', 'WHEEZE_PRESENT'),
   ('HCH12-0020', 'question_rationale', '42e006cd-729f-50ba-a0d6-709531713c5b', 'HEARTBURN_ASK'),
   -- question_differential_weights
   ('HCH12-0020', 'question_differential_weight', 'a56ea2dc-ba03-5fc8-a3e4-8bb19777c915', 'FEVER_PRESENT:PNEUMONIA:YES'),
   ('HCH12-0020', 'question_differential_weight', '617fe9c3-2e8a-5432-9d5b-151f5d476db8', 'FEVER_PRESENT:PNEUMONIA:NO'),
   ('HCH12-0020', 'question_differential_weight', '8a91e915-6707-55b9-97b2-ca58a1071cde', 'CHILLS:PNEUMONIA:YES'),
   ('HCH12-0020', 'question_differential_weight', 'b8054b74-047a-59af-8d7f-0f615bbeed02', 'TB_CONTACT:TUBERCULOSIS:YES'),
   ('HCH12-0020', 'question_differential_weight', 'e922387f-8ad5-5652-a9a6-ae575c9b0420', 'TB_CONTACT:TUBERCULOSIS:NO'),
   ('HCH12-0003', 'question_differential_weight', 'b60e5822-75a6-53c3-9a74-4f4eddad8860', 'ORTHOPNOEA_ASK:HEART-FAILURE:YES'),
   ('HCH12-0003', 'question_differential_weight', '20777b9a-d85d-5358-8c8f-06e0326ea36d', 'ORTHOPNOEA_ASK:HEART-FAILURE:NO'),
   ('HCH12-0008', 'question_differential_weight', 'dbce1d93-16ff-51df-9c4a-7597adf4d84c', 'WHEEZE_PRESENT:ASTHMA:YES'),
   ('HCH12-0007', 'question_differential_weight', '60236586-ca05-5639-b4a6-8d959a65fe28', 'BLOOD_IN_SPUTUM:TUBERCULOSIS:YES'),
   ('HCH12-0007', 'question_differential_weight', '5e95ac42-8fe5-5dd5-8864-a778d42b3eb9', 'BLOOD_IN_SPUTUM:PNEUMONIA:YES'),
   ('HCH12-0011', 'question_differential_weight', '43228e5b-67a7-58d3-9c8c-78bf47c57750', 'SMOKING_STATUS:ACUTE-BRONCHITIS:CURRENT'),
   ('HCH12-0011', 'question_differential_weight', '087f2629-bb38-50f5-add7-a8094fd5efd9', 'SMOKING_STATUS:ACUTE-BRONCHITIS:FORMER'),
   ('HCH12-0020', 'question_differential_weight', 'e48d51a0-e71b-56ba-8d5e-3312044e1b4a', 'NIGHT_SWEATS:TUBERCULOSIS:YES'),
   ('HCH12-0020', 'question_differential_weight', 'b210ccd2-1074-58c5-8752-6cf1c81bbe62', 'WEIGHT_LOSS:TUBERCULOSIS:YES'),
   ('HCH12-0006', 'question_differential_weight', 'd77dcf81-3fdc-5e9e-995e-36d77aee19ae', 'COUGH_PRODUCTIVITY:ACUTE-BRONCHITIS:PRODUCTIVE'),
   ('HCH12-0020', 'question_differential_weight', '2558d2ee-f627-5f7e-a846-0f7d638dd3ef', 'HEARTBURN_ASK:GERD:YES'),
   ('HCH12-0009', 'question_differential_weight', '3b709317-727c-5f0b-85e0-414c4fb6df90', 'CHEST_PAIN_PLEURITIC:PNEUMONIA:YES'),
   ('HCH1-0006',  'question_differential_weight', '17301817-31ae-59f5-9c9c-1bb9a926f9b2', 'FEEDING_DIFFICULTY:PNEUMONIA:YES'),
   -- documentation_requirements
   ('HCH12-0005', 'documentation_requirement', '85a34b81-088c-57ea-8c50-c72503884262', 'HPI:COUGH_ONSET'),
   ('HCH12-0004', 'documentation_requirement', '8f22021e-6221-53f3-99e5-64625cc2956b', 'HPI:COUGH_DURATION_DAYS'),
   ('HCH12-0006', 'documentation_requirement', '4834de91-f58d-540b-8972-0f42b7918b06', 'HPI:COUGH_PRODUCTIVITY'),
   ('HCH12-0006', 'documentation_requirement', '9f01e4f8-c69b-508a-9135-e06676eaf0c3', 'HPI:SPUTUM_COLOUR'),
   ('HCH12-0006', 'documentation_requirement', 'bcddbcb9-fa8b-566f-b289-07b0de59ed87', 'HPI:SPUTUM_AMOUNT'),
   ('HCH12-0001', 'documentation_requirement', '084ece0f-7208-5449-a2a1-bcfca1355360', 'HPI:DYSPNOEA_PRESENT'),
   ('HCH12-0021', 'documentation_requirement', '6f79150c-1321-5494-8f88-b173f41510c6', 'HPI:DYSPNOEA_SEVERITY'),
   ('HCH12-0007', 'documentation_requirement', 'fb316590-0c65-5b35-8117-ae6a781aad25', 'RED_FLAGS:BLOOD_IN_SPUTUM'),
   ('HCH12-0020', 'documentation_requirement', 'df15738e-9a94-5736-8a9c-0060a587e4d2', 'HPI:FEVER_PRESENT'),
   -- history_completion_rules
   ('HCH12-0005', 'history_completion_rule', 'e57406ee-fcd4-5c07-9e5f-c7c74942040b', 'HCR-COUGH'),
   ('HCH12-0009', 'history_completion_rule', '2d8f1c8a-6828-556a-b1c2-b1fe2d6ccca1', 'HCR-CHEST-PAIN')
) AS x(claim_code, object_type, object_id, object_code)
JOIN knowledge.source_claim s ON s.claim_code = x.claim_code
  ON CONFLICT DO NOTHING;
