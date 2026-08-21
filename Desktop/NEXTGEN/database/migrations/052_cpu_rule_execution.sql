-- =============================================================================
-- AMEXAN
-- PHASE 1 -- MIGRATION 052
-- CPU RULE EXECUTION — UNIQUE (RUN, RULE)
-- =============================================================================
--
-- `cpu.rule_execution` is the observability mirror of the governed rule
-- executions. Each governance rule may be executed at most once per CPU run,
-- so (run_id, rule_code) is naturally unique; enforce it so the idempotent
-- mirror writer (`ON CONFLICT (run_id, rule_code) DO NOTHING`) is valid.
--
-- IDEMPOTENT.
-- =============================================================================

BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS uq_cpu_rule_execution_run_rule
    ON cpu.rule_execution (run_id, rule_code);

COMMIT;