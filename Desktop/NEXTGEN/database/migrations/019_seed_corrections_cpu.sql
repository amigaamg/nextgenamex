-- =============================================================================
-- AMEXAN Phase 3 — Migration 019: seed corrections for the CPU
-- =============================================================================
-- Phase 3 verification surfaced two knowledge-graph gaps:
--
--  1. Gate questions (CHEST_PAIN_PRESENT, FEVER_PRESENT, FEVER_ONSET,
--     COUGH_SEVERITY) had no question_trigger rows, so the adaptive interview
--     could not open their branches from the presenting symptom. The trigger
--     table is the activation mechanism — every gate question needs one.
--
--  2. (No data change) the CPU maps investigations to their result facts
--     in code; results already capture the fact, so the CPU never re-orders.
-- =============================================================================

INSERT INTO knowledge.question_trigger (question_id, trigger_type, trigger_code, priority)
SELECT q.id, t.trigger_type, t.trigger_code, t.priority
FROM (VALUES
    ('CHEST_PAIN_PRESENT', 'symptom', 'chest pain', 10),
    ('FEVER_PRESENT',      'symptom', 'fever',      10),
    ('FEVER_ONSET',        'symptom', 'fever',      20),
    ('COUGH_SEVERITY',     'symptom', 'cough',      20)
) t(question_code, trigger_type, trigger_code, priority)
JOIN knowledge.question q ON q.question_code = t.question_code
ON CONFLICT (question_id, trigger_type, trigger_code) DO NOTHING;

COMMENT ON TABLE knowledge.question_trigger IS 'A question may be activated by a symptom, phenotype, risk factor, mechanism, disease consideration or complication.';
