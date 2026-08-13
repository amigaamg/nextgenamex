-- =============================================================================
-- AMEXAN Phase 3 — Migration 018: CPU runtime ledger
-- =============================================================================
-- The CPU is the runtime intelligence layer. It consumes events, reasons over
-- the knowledge graph, and emits state + recommendations. This schema persists
-- three things the CPU produces so the whole loop is auditable and resumable:
--
--   cpu.event_log     - every clinical event the CPU ingested (provenance)
--   cpu.decision      - every recommendation + the clinician's accept/modify/
--                       dismiss decision, with reason (the decision loop)
--   cpu.state_snapshot- the full PatientClinicalState at each CPU pass, so the
--                       system can answer "what did the machine think, when?"
--
-- The CPU itself lives in /clinical-cpu (TypeScript). PostgreSQL stores state
-- and the audit trail; it does not hold the reasoning process.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS cpu;
COMMENT ON SCHEMA cpu IS 'AMEXAN CPU runtime ledger: events, decisions, state snapshots.';

CREATE TABLE cpu.event_log (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type   text NOT NULL,
    payload      jsonb NOT NULL DEFAULT '{}'::jsonb,
    patient_id   uuid,
    encounter_id uuid,
    occurred_at  timestamptz NOT NULL DEFAULT now(),
    created_at   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cpu.event_log IS 'Every event ingested by the CPU, with full payload provenance.';

CREATE INDEX idx_cpu_event_patient ON cpu.event_log(patient_id, occurred_at);
CREATE INDEX idx_cpu_event_encounter ON cpu.event_log(encounter_id, occurred_at);

CREATE TABLE cpu.decision (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id            uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
    encounter_id          uuid REFERENCES encounter.encounter(id),
    recommendation_type   text NOT NULL,
    recommendation_code   text,
    recommendation_text   text NOT NULL,
    recommendation_reason text,
    status                text NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','accepted','modified','dismissed')),
    decision_reason       text,
    decision_by           uuid REFERENCES identity.user_account(id),
    patient_state         jsonb,
    knowledge_version     text,
    decided_at            timestamptz,
    created_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cpu.decision IS 'A recommendation plus the clinician decision. The clinician remains the decision authority; the machine records every reason.';

CREATE INDEX idx_cpu_decision_patient ON cpu.decision(patient_id, created_at);
CREATE INDEX idx_cpu_decision_encounter ON cpu.decision(encounter_id);

CREATE TABLE cpu.state_snapshot (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id  uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
    encounter_id uuid,
    event_id    bigint REFERENCES cpu.event_log(id),
    state       jsonb NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE cpu.state_snapshot IS 'Full PatientClinicalState after each CPU pass (re-runnable, audit).';

CREATE INDEX idx_cpu_snapshot_patient ON cpu.state_snapshot(patient_id, created_at);
