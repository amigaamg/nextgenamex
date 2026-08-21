-- =============================================================================
-- AMEXAN
-- PHASE 1 -- MIGRATION 051
-- CPU PROCESSING ERROR — UNIQUE RUN DEAD-LETTER
-- =============================================================================
--
-- A failed CPU pass writes exactly one dead-letter row per run to
-- `cpu.processing_error`. Enforce uniqueness on run_id so retry/idempotent
-- writers cannot duplicate a failure for the same run.
--
-- IDEMPOTENT.
-- =============================================================================

BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS uq_cpu_processing_error_run
    ON cpu.processing_error (run_id);

COMMIT;