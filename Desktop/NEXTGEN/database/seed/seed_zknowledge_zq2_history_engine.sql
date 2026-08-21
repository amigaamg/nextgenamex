-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H2 seed zq2: universal question engine
-- =============================================================================
-- Seeds the H2 QUESTION layer compiled from H1 Hutchison claims:
--   knowledge.question              — the 5 universal history questions (Q001-Q005)
--   knowledge.question_variant      — context/language variants (QV001-QV004)
--   knowledge.question_priority_rule — data-driven prioritisation factors (P001-P010)
--   knowledge.history_context_rule  — context adaptations (R001-R007)
--
-- Design law: the DATABASE holds the rules; the CPU decides; the UI renders.
-- These questions are UNIVERSAL (symptom-agnostic). Symptom-specific question
-- banks remain in knowledge.question_trigger (wired by H3 modules) and are
-- answered using the same universal structures.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. The 5 universal history questions (Q001-Q005)
-- ---------------------------------------------------------------------------
-- question_mode == the Hutchison question category that drives phrasing:
--   OPEN (indirect) | DIRECT (closed) | CLARIFYING | SCALE | FUNCTIONAL ...
INSERT INTO knowledge.question
    (question_code, question_type, response_type, text, priority, is_active,
     history_concept_id, question_mode) VALUES
   ('OPEN_PRESENTING_CONCERN', 'clinical', 'text',
        'Tell me what has led up to you coming here today.',
        1, true, 'HC001', 'OPEN'),
   ('SYMPTOM_ONSET', 'clinical', 'text',
        'When did this start?',
        2, true, 'HC002', 'OPEN'),
   ('SYMPTOM_DURATION', 'clinical', 'numeric',
        'How long has this been happening?',
        2, true, 'HC003', 'DIRECT'),
   ('SYMPTOM_SEVERITY', 'clinical', 'numeric',
        'How much does this bother you? (scale 1-10)',
        2, true, 'HC008', 'SCALE'),
   ('SYMPTOM_ASSOCIATED', 'clinical', 'text',
        'What other symptoms have you noticed?',
        3, true, 'HC011', 'OPEN')
ON CONFLICT (question_code) DO UPDATE SET
    question_type      = EXCLUDED.question_type,
    response_type      = EXCLUDED.response_type,
    text               = EXCLUDED.text,
    priority           = EXCLUDED.priority,
    is_active          = EXCLUDED.is_active,
    history_concept_id = EXCLUDED.history_concept_id,
    question_mode      = EXCLUDED.question_mode;

-- ---------------------------------------------------------------------------
-- 2. Question variants — the fact stays ONSET, only the presentation changes
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_variant
    (question_id, context, language_code, audience, wording, is_active)
SELECT q.id, v.context, v.language_code, 'patient', v.wording, true
FROM (VALUES
   ('SYMPTOM_ONSET',    'adult',       'en', 'When did this start?'),
   ('SYMPTOM_ONSET',    'child_proxy', 'en', 'When did you first notice this?'),
   ('SYMPTOM_ONSET',    'caregiver',   'en', 'When did you first notice this in the child?'),
   ('SYMPTOM_ONSET',    'adult',       'sw', 'Ulipotokea lini?'),
   ('OPEN_PRESENTING_CONCERN', 'adult','en', 'Tell me what has led up to you coming here today.'),
   ('OPEN_PRESENTING_CONCERN', 'child_proxy', 'en', 'Tell me what has been going on with your child.'),
   ('SYMPTOM_DURATION', 'adult',       'en', 'How long has this been happening?'),
   ('SYMPTOM_DURATION', 'child_proxy', 'en', 'How long has this been going on?')
) AS v(question_code, context, language_code, wording)
JOIN knowledge.question q ON q.question_code = v.question_code
ON CONFLICT (question_id, context, language_code, audience) DO UPDATE SET
    wording = EXCLUDED.wording;

-- ---------------------------------------------------------------------------
-- 3. Question-priority rules (P001-P010) — data, not code
-- ---------------------------------------------------------------------------
-- The CPU scores every candidate question and shows only the next small group.
-- +1000 mandatory foundation  -> -1000 suppress. Everything between is nuance.
INSERT INTO knowledge.question_priority_rule (rule_code, factor, effect, description) VALUES
   ('P001', 'mandatory_foundation',              1000, 'Foundation questions that must be asked for the active symptom.'),
   ('P002', 'emergency_red_flag',                 900, 'Red-flag / emergency probes (e.g. haemoptysis) — ask early, never skip.'),
   ('P003', 'active_symptom_characterization',    800, 'Characterise the active presenting symptom (site, character, severity...).'),
   ('P004', 'high-value_differential_feature',    700, 'Features that discriminate between the current differentials.'),
   ('P005', 'missing_required_documentation',     600, 'Missing facts the care standard requires for this presentation.'),
   ('P006', 'context_specific',                   500, 'Context-required adaptations (child, pregnant, immunocompromised...).'),
   ('P007', 'functional_impact',                  300, 'Functional-impact assessment (exercise, work, sleep, social).'),
   ('P008', 'general_screening',                  100, 'General screening (systems review) once the acute problem is characterised.'),
   ('P009', 'already_known',                    -1000, 'Fact already captured for this encounter — suppress.'),
   ('P010', 'irrelevant_to_context',            -1000, 'Irrelevant for this patient context — suppress.')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. History-context rules (R001-R007)
-- ---------------------------------------------------------------------------
-- subject_code is polymorphic (history_concept code / symptom code / fact code).
-- context_type_code + context_value bind to the formal context vocabulary
-- (AGE / SEX / PREGNANCY / CARE_SETTING / ACUITY / ...) when they exist.
INSERT INTO knowledge.history_context_rule
    (rule_id, subject_code, context_label, context_type_code, context_value_id, action, description, sort_order) VALUES
   ('R001', 'COUGH_PRODUCTIVITY',    'adult',        'AGE',    (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'),
        'ask productive/non-productive cough directly',
        'Adults report productivity; a direct question is appropriate.', 1),
   ('R002', 'COUGH_PRODUCTIVITY',    'young_child',  'AGE',    (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '1-4Y'),
        'use observed descriptors (wet/dry cough, vomiting after coughing) instead of productivity',
        'Young children cannot report sputum; ask what is observed.', 1),
   ('R003', 'DYSPNOEA',              'adult',        'AGE',    (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'),
        'ask exertion threshold: how far can you walk at a normal pace?',
        'Exercise tolerance is the reliable dyspnoea gauge in adults (Box 12.3).', 1),
   ('R004', 'DYSPNOEA',              'child',        'AGE',    (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '1-4Y'),
        'ask about feeding, play and tummy-breathing impact instead of stairs',
        'Children: dyspnoea presents as feeding difficulty and reduced activity.', 1),
   ('R005', 'PRESENTING_CONCERN',    'emergency',    'ACUITY', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'ACUITY' AND value = 'emergency'),
        'prioritise immediate-danger questions over the full open narrative',
        'In emergencies the opening question is still open-ended but danger questions come first.', 1),
   ('R006', 'HISTORY_SOURCE',        'unconscious',  NULL,     NULL,
        'must be obtained as collateral history from those accompanying the patient',
        'When the patient cannot give the history, collateral history is mandatory (Hutchison part II).', 1),
   ('R007', 'REPRODUCTIVE_HISTORY',  'reproductive_context', NULL, NULL,
        'activate reproductive history questions for women of reproductive age',
        'Reproductive history is contextually relevant, not universally mandatory.', 1)
ON CONFLICT DO NOTHING;
