-- =============================================================================
-- AMEXAN Phase 4 — Migration 021: question → fact mapping for raw-value questions
-- =============================================================================
-- The answer_option / fact_mapping path covers choice questions. Numeric, free-
-- text and date questions have no options; their answer IS the medical value.
-- knowledge.question_fact binds such a question directly to the fact definition
-- it acquires, so a typed answer becomes a fact through the same substrate.
--
-- Also repairs two knowledge gaps found while smoke-testing the Phase 4 UI:
--  1. COUGH_DURATION (numeric) had no way to become a fact.
--  2. CHEST_PAIN_RADIATION had answer options but no fact mappings, so answering
--     it would capture nothing (no clinical truth). It is now mapped to the
--     CHEST_PAIN_RADIATION fact it was meant to acquire.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Units the numeric questions need
-- ---------------------------------------------------------------------------

INSERT INTO terminology.unit (code, label, dimension, symbol, si_unit_code)
VALUES
   ('day',  'day',   'duration', 'd', NULL),
   ('days', 'days',  'duration', 'd', NULL)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. The question → fact binding
-- ---------------------------------------------------------------------------

CREATE TABLE knowledge.question_fact (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   question_id           uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
   fact_definition_code  text NOT NULL REFERENCES clinical.fact_definition(code),
   unit_code             text REFERENCES terminology.unit(code),
   UNIQUE (question_id, fact_definition_code)
);
COMMENT ON TABLE knowledge.question_fact
   IS 'Binds a raw-value question (numeric / text / date — no answer_option) to the fact definition it acquires, with an optional unit.';

-- ---------------------------------------------------------------------------
-- 3. Bind COUGH_DURATION → COUGH_DURATION_DAYS (numeric, days)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_fact (question_id, fact_definition_code, unit_code)
SELECT q.id, 'COUGH_DURATION_DAYS', 'days'
  FROM knowledge.question q
 WHERE q.question_code = 'COUGH_DURATION'
ON CONFLICT (question_id, fact_definition_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Repair CHEST_PAIN_RADIATION: define the fact and map each option to it
-- ---------------------------------------------------------------------------

INSERT INTO clinical.fact_definition (code, name, data_type, description)
VALUES ('CHEST_PAIN_RADIATION', 'Chest pain radiation', 'coded', 'Where the chest pain radiates (neck/arm/back)')
ON CONFLICT (code) DO NOTHING;

INSERT INTO knowledge.fact_mapping (answer_option_id, fact_definition_code, value)
SELECT ao.id, 'CHEST_PAIN_RADIATION', ao.value_text
  FROM knowledge.answer_option ao
  JOIN knowledge.question q ON q.id = ao.question_id
 WHERE q.question_code = 'CHEST_PAIN_RADIATION'
ON CONFLICT (answer_option_id, fact_definition_code) DO NOTHING;