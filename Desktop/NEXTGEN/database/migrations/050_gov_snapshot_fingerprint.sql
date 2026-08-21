-- =============================================================================
-- AMEXAN
-- PHASE 1 -- MIGRATION 050
-- GOVERNANCE SNAPSHOT FINGERPRINT — UNIQUE → INDEX
-- =============================================================================
--
-- `governance.clinical_snapshot.input_fingerprint` carries a hash of the
-- canonical fact set used by a CPU pass. Migration 036 created a UNIQUE index
-- on it, which is wrong:
--
--   * a snapshot is written once per CPU run, and
--   * two runs can legitimately evaluate the exact same fact set
--     (e.g. repeated demo passes, re-evaluation after a no-op event).
--
-- A unique fingerprint therefore rejects valid runs instead of protecting
-- replay. Replay divergence detection compares the stored fingerprint with a
-- recomputed one at read time (ReplayEngine) — it does not require the column
-- to be unique.
--
-- This migration drops the unique index and recreates it as a plain (non
-- unique) lookup index. It also backfills any duplicates that previous unique
-- enforcement prevented, then leaves only one row per (encounter, fingerprint)
-- occurrence of the newest rows intact.
--
-- IDEMPOTENT.
-- =============================================================================

BEGIN;

DROP INDEX IF EXISTS governance.uq_gov_snapshot_input_fingerprint;

CREATE INDEX IF NOT EXISTS ix_gov_snapshot_input_fingerprint
    ON governance.clinical_snapshot (input_fingerprint);

COMMIT;