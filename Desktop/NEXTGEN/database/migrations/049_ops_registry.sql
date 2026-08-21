-- =============================================================================
-- AMEXAN
-- PHASE 1 -- MIGRATION 049
-- OPERATIONS REGISTRY (MIGRATIONS + INCIDENTS)
-- =============================================================================
--
-- 1. system.migration          durable record of applied migrations (§61)
--      run_migrations.ps1 upserts one row per applied migration file, so the
--      admin surface can show which version the database is on and spot
--      drift between what the repo has and what the database has.
--
-- 2. governance.incident       incident management (§59) — a persistent
--      record of an investigation across a set of related events, with a
--      severity, an owning queue, and lifecycle states.
--
-- 3. governance.incident_event append-only timeline of an incident
--      (created, triaged, escalated, resolved, reopened ...).
--
-- IDEMPOTENT: all statements are guarded.
-- =============================================================================

BEGIN;


-- =============================================================================
-- 1. MIGRATION REGISTRY
-- =============================================================================

CREATE TABLE IF NOT EXISTS system.migration (
    version      integer PRIMARY KEY,
    name         text NOT NULL,
    applied_at   timestamptz NOT NULL DEFAULT now(),
    applied_by   text,
    checksum     text
);

CREATE INDEX IF NOT EXISTS ix_migration_applied_at
    ON system.migration (applied_at DESC);


-- =============================================================================
-- 2. INCIDENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS governance.incident (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_code     text NOT NULL UNIQUE,
    title             text NOT NULL,
    description       text,
    severity          text NOT NULL DEFAULT 'medium'
                        CHECK (severity IN ('critical','high','medium','low')),
    status            text NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open','triaged','investigating',
                                          'resolved','closed','cancelled')),
    category          text,
    owning_team       text,
    reported_by       text,
    related_entity_type text,
    related_entity_id   uuid,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    resolved_at       timestamptz
);

CREATE TABLE IF NOT EXISTS governance.incident_event (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id   uuid NOT NULL REFERENCES governance.incident (id) ON DELETE CASCADE,
    event_type    text NOT NULL,
    detail        jsonb,
    occurred_at   timestamptz NOT NULL DEFAULT now(),
    actor_id      text
);

CREATE INDEX IF NOT EXISTS ix_incident_status
    ON governance.incident (status);
CREATE INDEX IF NOT EXISTS ix_incident_severity
    ON governance.incident (severity);
CREATE INDEX IF NOT EXISTS ix_incident_updated
    ON governance.incident (updated_at DESC);
CREATE INDEX IF NOT EXISTS ix_incident_event_incident
    ON governance.incident_event (incident_id, occurred_at DESC);


COMMIT;