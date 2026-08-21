-- =============================================================================
-- AMEXAN Clinical CPU — Admission context gating
--
-- PURPOSE
-- -------
-- Admission capture is an inpatient concern. It must never front-load an
-- ordinary outpatient biodata interview:
--
--   * BIODATA_ADMISSION_STATUS is only applicable once the encounter has been
--     classified as ENCOUNTER_TYPE = INPATIENT.
--
--   * BIODATA_ENCOUNTER_TYPE (the disposition) is the pivot question for that
--     gate, so it is asked right after identity (DOB/age) and BEFORE
--     administrative biodata (occupation/residence/county).
--
-- This keeps "admission context — only if applicable" and guarantees that
-- ADMISSION_STATUS / ADMISSION_DATE can never delay an outpatient from
-- reaching the chief complaint.
--
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BIODATA_ENCOUNTER_TYPE — ask the disposition as soon as identity is known
-- ---------------------------------------------------------------------------
-- priority 4 = immediately after DATE_OF_BIRTH (2) and REPORTED_AGE (3), and
-- before OCCUPATION (5) / RESIDENCE (6) / COUNTY (7). Across requirement bands
-- this is independent of the mandatory identity cards (rank 1).
-- ---------------------------------------------------------------------------

UPDATE knowledge.question
   SET priority = 4
 WHERE question_code = 'BIODATA_ENCOUNTER_TYPE'
   AND priority <> 4;

UPDATE knowledge.question_module_member
   SET sort_order = 4
 WHERE module_code = 'BIODATA'
   AND question_id = (
         SELECT id FROM knowledge.question
          WHERE question_code = 'BIODATA_ENCOUNTER_TYPE'
       );

-- ---------------------------------------------------------------------------
-- 2. BIODATA_ADMISSION_STATUS — gate on INPATIENT disposition
-- ---------------------------------------------------------------------------
-- (a) Requirement becomes value-aware: only allowed while the encounter is
--     classified INPATIENT.
-- (b) The 'applies' context rule fails closed for anything else, so the
--     question disappears from the active queue for outpatient encounters.
-- ---------------------------------------------------------------------------

UPDATE knowledge.question_requirement
   SET condition = '{"fact":{"code":"ENCOUNTER_TYPE","value":"INPATIENT"}}'::jsonb
 WHERE question_id = (
         SELECT id FROM knowledge.question
          WHERE question_code = 'BIODATA_ADMISSION_STATUS'
       )
   AND condition IS NULL;

INSERT INTO knowledge.question_context
    (question_id, context_type_code, context_value_id, applicability, priority)
SELECT
    q.id,
    'ENCOUNTER_TYPE',
    cv.id,
    'applies',
    10
FROM knowledge.question q
JOIN knowledge.context_value cv
    ON cv.context_type_code = 'ENCOUNTER_TYPE'
   AND cv.value = 'INPATIENT'
WHERE q.question_code = 'BIODATA_ADMISSION_STATUS'
ON CONFLICT
    (question_id, context_type_code, context_value_id)
DO NOTHING;
