-- =============================================================================
-- 060. PLEURITIC_CHEST_PAIN ANSWER OPTIONS + FACT MAPPING
-- =============================================================================
--
-- The question PLEURITIC_CHEST_PAIN ("Does the chest pain become worse when
-- you breathe deeply or cough?") was introduced by the respiratory knowledge
-- compiler but never wired up with answer options or fact mappings. It is
-- triggered by the chest-pain symptom branch, so answering it previously
-- failed with "Unknown answer" and the pleuritic signal was never captured.
--
-- Mirror the CHEST_PAIN_PRESENT wiring so the question is fully answerable and
-- feeds the fact substrate the differential engine scores:
--
--     YES      -> PLEURITIC_CHEST_PAIN = true
--     NO       -> PLEURITIC_CHEST_PAIN = false
--     UNKNOWN  -> PLEURITIC_CHEST_PAIN = unknown
--
-- Fact definitions for PLEURITIC_CHEST_PAIN already exist in both
-- clinical.fact_definition and clinical.fact_definitions (boolean).
-- =============================================================================

DO $$
DECLARE
    v_question_id   uuid;
    v_yes_id        uuid;
    v_no_id         uuid;
    v_unknown_id    uuid;
BEGIN
    SELECT id INTO v_question_id
      FROM knowledge.question
     WHERE question_code = 'PLEURITIC_CHEST_PAIN'
     LIMIT 1;

    IF v_question_id IS NULL THEN
        RAISE EXCEPTION 'question PLEURITIC_CHEST_PAIN does not exist';
    END IF;

    INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, value_text, sort_order, is_active)
    VALUES (gen_random_uuid(), v_question_id, 'YES', 'Yes', 'YES', 1, true)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_yes_id;

    IF v_yes_id IS NULL THEN
        SELECT id INTO v_yes_id
          FROM knowledge.answer_option
         WHERE question_id = v_question_id AND answer_code = 'YES'
         LIMIT 1;
    END IF;

    INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, value_text, sort_order, is_active)
    VALUES (gen_random_uuid(), v_question_id, 'NO', 'No', 'NO', 2, true)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_no_id;

    IF v_no_id IS NULL THEN
        SELECT id INTO v_no_id
          FROM knowledge.answer_option
         WHERE question_id = v_question_id AND answer_code = 'NO'
         LIMIT 1;
    END IF;

    INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, value_text, sort_order, is_active)
    VALUES (gen_random_uuid(), v_question_id, 'UNKNOWN', 'Unknown', 'UNKNOWN', 3, true)
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_unknown_id;

    IF v_unknown_id IS NULL THEN
        SELECT id INTO v_unknown_id
          FROM knowledge.answer_option
         WHERE question_id = v_question_id AND answer_code = 'UNKNOWN'
         LIMIT 1;
    END IF;

    INSERT INTO knowledge.fact_mapping (id, answer_option_id, fact_definition_code, value, polarity, confidence, is_active)
    VALUES (gen_random_uuid(), v_yes_id,    'PLEURITIC_CHEST_PAIN', 'true',  'positive', 1.0, true)
    ON CONFLICT DO NOTHING;

    INSERT INTO knowledge.fact_mapping (id, answer_option_id, fact_definition_code, value, polarity, confidence, is_active)
    VALUES (gen_random_uuid(), v_no_id,     'PLEURITIC_CHEST_PAIN', 'false', 'negative', 1.0, true)
    ON CONFLICT DO NOTHING;

    INSERT INTO knowledge.fact_mapping (id, answer_option_id, fact_definition_code, value, polarity, confidence, is_active)
    VALUES (gen_random_uuid(), v_unknown_id, 'PLEURITIC_CHEST_PAIN', 'unknown', 'positive', 1.0, true)
    ON CONFLICT DO NOTHING;
END
$$;