-- =============================================================================
-- 061. WHEEZE/TB/WEIGHT/SWEAT QUESTION ANSWER WIRING
-- =============================================================================
--
-- The respiratory knowledge compiler introduced four presence questions that
-- were never wired up with answer options or fact mappings:
--
--     WHEEZE_PRESENT   Have you noticed wheezing or a whistling sound when
--                      breathing?
--     TB_CONTACT       Have you had close contact with anyone diagnosed with
--                      tuberculosis?
--     WEIGHT_LOSS      Have you lost weight unintentionally?
--     NIGHT_SWEATS     Do you have drenching night sweats?
--
-- Answering them previously failed with "Unknown answer". Mirror the
-- CHEST_PAIN_PRESENT wiring so each question is answerable and feeds the fact
-- substrate the differential engine scores. The underlying fact definitions
-- already exist in clinical.fact_definition (WHEEZE_PRESENT/TB_CONTACT/
-- NIGHT_SWEATS boolean; WEIGHT_LOSS quantity stored as text).
-- =============================================================================

DO $$
DECLARE
    rec record;
    v_question_id uuid;
    v_option_id uuid;
    v_answer_code text;
    v_value text;
BEGIN
    FOR rec IN (
        SELECT 'WHEEZE_PRESENT' AS question_code, 'WHEEZE_PRESENT' AS fact_code
        UNION ALL SELECT 'TB_CONTACT', 'TB_CONTACT'
        UNION ALL SELECT 'NIGHT_SWEATS', 'NIGHT_SWEATS'
        UNION ALL SELECT 'WEIGHT_LOSS', 'WEIGHT_LOSS'
    ) LOOP
        SELECT id INTO v_question_id
          FROM knowledge.question
         WHERE question_code = rec.question_code
         LIMIT 1;

        IF v_question_id IS NULL THEN
            RAISE EXCEPTION 'question % does not exist', rec.question_code;
        END IF;

        FOR v_answer_code, v_value IN (
            VALUES ('YES', 'true'),
                   ('NO', 'false'),
                   ('UNKNOWN', 'unknown')
        ) LOOP
            INSERT INTO knowledge.answer_option
                (id, question_id, answer_code, label, value_text, sort_order, is_active)
            VALUES (gen_random_uuid(), v_question_id, v_answer_code,
                    initcap(v_answer_code), v_answer_code,
                    CASE v_answer_code WHEN 'YES' THEN 1 WHEN 'NO' THEN 2 ELSE 3 END,
                    true)
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_option_id;

            IF v_option_id IS NULL THEN
                SELECT id INTO v_option_id
                  FROM knowledge.answer_option
                 WHERE question_id = v_question_id AND answer_code = v_answer_code
                 LIMIT 1;
            END IF;

            INSERT INTO knowledge.fact_mapping
                (id, answer_option_id, fact_definition_code, value, polarity, confidence, is_active)
            VALUES (gen_random_uuid(), v_option_id, rec.fact_code, v_value,
                    'positive', 1.0, true)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END
$$;