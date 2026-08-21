-- =============================================================================
-- 055. HPI OBJECTIVE BRIDGES
-- =============================================================================
--
-- knowledge.question_hpi_objective was created in migration 008 referencing
-- knowledge.hpi_objective(code). Migration 022 dropped hpi_objective with
-- CASCADE and recreated it with a new column (objective_code), which silently
-- removed the bridge table's foreign-key constraint and left it orphaned and
-- empty.
--
-- This migration restores the bridge table (idempotently) and re-establishes
-- the foreign key against the 022 schema. The population of the bridges is
-- knowledge data, so it lives in the seed suite (after questions are seeded).

CREATE TABLE IF NOT EXISTS knowledge.question_hpi_objective (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id    uuid NOT NULL
                   REFERENCES knowledge.question(id)
                   ON DELETE CASCADE,

    objective_code text NOT NULL
                   REFERENCES knowledge.hpi_objective(objective_code),

    weight         numeric(8,4) NOT NULL DEFAULT 1.0,

    UNIQUE (question_id, objective_code)
);

CREATE INDEX IF NOT EXISTS idx_question_hpi_objective_objective
    ON knowledge.question_hpi_objective(objective_code);

CREATE INDEX IF NOT EXISTS idx_question_hpi_objective_question
    ON knowledge.question_hpi_objective(question_id);

-- Re-establish the foreign key that migration 022's CASCADE drop removed.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'question_hpi_objective_objective_code_fkey'
    ) THEN
        ALTER TABLE knowledge.question_hpi_objective
            ADD CONSTRAINT question_hpi_objective_objective_code_fkey
            FOREIGN KEY (objective_code)
            REFERENCES knowledge.hpi_objective(objective_code);
    END IF;
END $$;