-- =============================================================================
-- AMEXAN Phase 3 — Migration 018
-- CPU RUNTIME LEDGER — HIGH-PERFORMANCE CLINICAL OPERATING SYSTEM
-- =============================================================================
-- Design goals:
--   1. Extremely fast event ingestion.
--   2. Idempotent event processing.
--   3. Deterministic CPU replay.
--   4. Append-heavy audit architecture.
--   5. Fast patient / encounter retrieval.
--   6. Fast "latest state" resolution.
--   7. Complete recommendation provenance.
--   8. Optimistic/concurrent CPU workers.
--   9. Knowledge-version traceability.
--  10. No clinical reasoning stored as executable SQL.
--
-- Runtime model:
--
--   EVENT
--      ↓
--   CPU INGESTION
--      ↓
--   FACT / STATE UPDATE
--      ↓
--   KNOWLEDGE RESOLUTION
--      ↓
--   RULE EVALUATION
--      ↓
--   CLINICAL STATE
--      ↓
--   RECOMMENDATIONS
--      ↓
--   CLINICIAN DECISION
--
-- PostgreSQL = durable runtime memory + audit ledger.
-- TypeScript CPU = reasoning engine.
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS cpu;

COMMENT ON SCHEMA cpu IS
'AMEXAN clinical CPU runtime: high-performance event ingestion, state persistence,
clinical recommendations, decisions, replay and complete computational provenance.';


-- =============================================================================
-- 1. CPU EVENT LEDGER
-- =============================================================================
-- Immutable append-oriented event stream.
--
-- Events represent observations entering the CPU:
--   history
--   examination
--   investigation
--   medication
--   diagnosis
--   monitoring
--   encounter changes
--   clinician actions
--   system events
--
-- event_id is globally ordered and therefore provides a cheap replay cursor.
-- =============================================================================

CREATE TABLE cpu.event_log (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    event_type          text NOT NULL,

    patient_id          uuid,
    encounter_id        uuid,

    source_type         text NOT NULL DEFAULT 'clinical'
                        CHECK (
                            source_type IN (
                                'clinical',
                                'clinician',
                                'patient',
                                'device',
                                'laboratory',
                                'imaging',
                                'medication',
                                'system',
                                'integration',
                                'import'
                            )
                        ),

    source_id           text,

    -- Idempotency key supplied by the producing subsystem.
    idempotency_key     text,

    -- Correlation across one clinical operation.
    correlation_id      uuid,

    -- Parent event for causality / replay.
    parent_event_id     bigint REFERENCES cpu.event_log(id),

    payload             jsonb NOT NULL DEFAULT '{}'::jsonb,

    -- Optional compact fact representation.
    fact_code           text,
    fact_value          jsonb,

    occurred_at         timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now(),

    -- CPU processing metadata.
    processed_at        timestamptz,
    processing_status   text NOT NULL DEFAULT 'pending'
                        CHECK (
                            processing_status IN (
                                'pending',
                                'processing',
                                'processed',
                                'failed',
                                'ignored'
                            )
                        ),

    processing_attempts integer NOT NULL DEFAULT 0,

    processing_error    text,

    -- Knowledge/runtime version used to process the event.
    knowledge_version   text,
    cpu_version         text
);

COMMENT ON TABLE cpu.event_log IS
'Immutable clinical event ledger consumed by the AMEXAN CPU. Every CPU input
is persisted for replay, provenance, audit and deterministic reconstruction.';

COMMENT ON COLUMN cpu.event_log.id IS
'Monotonically increasing CPU event sequence used as a replay cursor.';

COMMENT ON COLUMN cpu.event_log.idempotency_key IS
'Producer supplied unique key preventing duplicate clinical event ingestion.';

COMMENT ON COLUMN cpu.event_log.parent_event_id IS
'Causal parent event allowing the CPU to reconstruct event lineage.';


-- -----------------------------------------------------------------------------
-- Fast event ingestion / replay indexes
-- -----------------------------------------------------------------------------

CREATE INDEX idx_cpu_event_patient_time
    ON cpu.event_log (patient_id, occurred_at DESC, id DESC);

CREATE INDEX idx_cpu_event_encounter_time
    ON cpu.event_log (encounter_id, occurred_at DESC, id DESC);

CREATE INDEX idx_cpu_event_patient_id
    ON cpu.event_log (patient_id, id DESC);

CREATE INDEX idx_cpu_event_encounter_id
    ON cpu.event_log (encounter_id, id DESC);

CREATE INDEX idx_cpu_event_processing
    ON cpu.event_log (processing_status, id)
    WHERE processing_status IN ('pending', 'failed');

CREATE INDEX idx_cpu_event_type_time
    ON cpu.event_log (event_type, occurred_at DESC);

CREATE INDEX idx_cpu_event_correlation
    ON cpu.event_log (correlation_id, id);

CREATE INDEX idx_cpu_event_parent
    ON cpu.event_log (parent_event_id);

CREATE INDEX idx_cpu_event_fact
    ON cpu.event_log (fact_code, id DESC)
    WHERE fact_code IS NOT NULL;

CREATE INDEX idx_cpu_event_payload_gin
    ON cpu.event_log
    USING GIN (payload jsonb_path_ops);


-- -----------------------------------------------------------------------------
-- Idempotent ingestion
-- -----------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_cpu_event_idempotency
    ON cpu.event_log (idempotency_key)
    WHERE idempotency_key IS NOT NULL;


-- =============================================================================
-- 2. CPU EVENT CHECKPOINT
-- =============================================================================
-- Worker checkpoints allow multiple CPU workers to consume the event stream
-- without rescanning the entire ledger.
-- =============================================================================

CREATE TABLE cpu.event_checkpoint (
    worker_code         text PRIMARY KEY,

    last_event_id       bigint NOT NULL DEFAULT 0,

    lease_owner         text,

    lease_expires_at    timestamptz,

    heartbeat_at        timestamptz,

    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.event_checkpoint IS
'Durable CPU worker cursors and leases for high-throughput event processing.';


CREATE INDEX idx_cpu_checkpoint_lease
    ON cpu.event_checkpoint (lease_expires_at);


-- =============================================================================
-- 3. PATIENT CPU STATE
-- =============================================================================
-- HOT STATE.
--
-- state_snapshot is the historical/audit representation.
-- current_state is the fast operational representation.
--
-- The CPU should normally read this table instead of reconstructing a patient
-- from thousands of historical events.
-- =============================================================================

CREATE TABLE cpu.patient_state (
    patient_id              uuid PRIMARY KEY
                            REFERENCES patient.patient(id)
                            ON DELETE CASCADE,

    encounter_id            uuid,

    state                   jsonb NOT NULL DEFAULT '{}'::jsonb,

    -- Latest processed event.
    last_event_id           bigint REFERENCES cpu.event_log(id),

    -- Number of events incorporated into this state.
    event_sequence          bigint NOT NULL DEFAULT 0,

    knowledge_version       text,
    cpu_version             text,

    state_hash              text,

    status                  text NOT NULL DEFAULT 'active'
                            CHECK (
                                status IN (
                                    'active',
                                    'paused',
                                    'closed',
                                    'error'
                                )
                            ),

    updated_at              timestamptz NOT NULL DEFAULT now(),

    created_at              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.patient_state IS
'Hot operational PatientClinicalState used by the CPU for low-latency clinical reasoning.';

COMMENT ON COLUMN cpu.patient_state.state IS
'Current normalized clinical state consumed by the CPU. Historical states live in cpu.state_snapshot.';


CREATE INDEX idx_cpu_patient_state_encounter
    ON cpu.patient_state (encounter_id);

CREATE INDEX idx_cpu_patient_state_event
    ON cpu.patient_state (last_event_id DESC);

CREATE INDEX idx_cpu_patient_state_updated
    ON cpu.patient_state (updated_at DESC);


CREATE INDEX idx_cpu_patient_state_json
    ON cpu.patient_state
    USING GIN (state jsonb_path_ops);


-- =============================================================================
-- 4. STATE VERSION
-- =============================================================================
-- Optimistic concurrency / deterministic state transitions.
-- =============================================================================

CREATE TABLE cpu.state_version (
    patient_id          uuid PRIMARY KEY
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    version             bigint NOT NULL DEFAULT 0,

    last_event_id       bigint REFERENCES cpu.event_log(id),

    state_hash          text,

    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.state_version IS
'Atomic patient state version used for optimistic concurrency and deterministic CPU updates.';


-- =============================================================================
-- 5. STATE SNAPSHOT
-- =============================================================================
-- Historical PatientClinicalState after CPU passes.
--
-- This is intentionally append-only.
-- =============================================================================

CREATE TABLE cpu.state_snapshot (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid,

    event_id            bigint
                        REFERENCES cpu.event_log(id),

    state_version       bigint NOT NULL DEFAULT 0,

    state               jsonb NOT NULL,

    state_hash          text,

    knowledge_version   text,

    cpu_version         text,

    snapshot_reason     text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.state_snapshot IS
'Immutable historical PatientClinicalState after CPU computation. Enables replay,
audit, temporal reasoning and reconstruction of exactly what the CPU knew.';


CREATE INDEX idx_cpu_snapshot_patient_time
    ON cpu.state_snapshot (patient_id, created_at DESC, id DESC);

CREATE INDEX idx_cpu_snapshot_encounter_time
    ON cpu.state_snapshot (encounter_id, created_at DESC, id DESC);

CREATE INDEX idx_cpu_snapshot_event
    ON cpu.state_snapshot (event_id);

CREATE INDEX idx_cpu_snapshot_patient_version
    ON cpu.state_snapshot (patient_id, state_version DESC);


-- =============================================================================
-- 6. CLINICAL DECISION / RECOMMENDATION LEDGER
-- =============================================================================
-- CPU recommendation ≠ clinician decision.
--
-- The CPU proposes.
-- The clinician accepts / modifies / dismisses.
--
-- Every recommendation retains enough provenance to explain:
--
--   WHAT
--   WHY
--   FROM WHICH STATE
--   FROM WHICH KNOWLEDGE
--   GENERATED BY WHICH CPU VERSION
--   WHAT DID THE CLINICIAN DO?
-- =============================================================================

CREATE TABLE cpu.decision (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id              uuid NOT NULL
                            REFERENCES patient.patient(id)
                            ON DELETE CASCADE,

    encounter_id            uuid
                            REFERENCES encounter.encounter(id),

    -- Event/state that caused this recommendation.
    triggering_event_id     bigint
                            REFERENCES cpu.event_log(id),

    state_snapshot_id       uuid
                            REFERENCES cpu.state_snapshot(id),

    recommendation_type     text NOT NULL,

    recommendation_code     text,

    recommendation_text     text NOT NULL,

    recommendation_reason   text,

    -- Machine-readable explanation.
    reasoning               jsonb NOT NULL DEFAULT '{}'::jsonb,

    -- Knowledge provenance.
    knowledge_version       text,

    rule_code               text,

    rule_version            integer,

    protocol_code           text,

    protocol_version        text,

    -- CPU provenance.
    cpu_version             text,

    status                  text NOT NULL DEFAULT 'pending'
                            CHECK (
                                status IN (
                                    'pending',
                                    'accepted',
                                    'modified',
                                    'dismissed',
                                    'expired',
                                    'superseded'
                                )
                            ),

    decision_reason         text,

    modified_recommendation text,

    decision_by             uuid
                            REFERENCES identity.user_account(id),

    decided_at              timestamptz,

    priority                integer NOT NULL DEFAULT 50,

    urgency                 text NOT NULL DEFAULT 'routine'
                            CHECK (
                                urgency IN (
                                    'emergency',
                                    'urgent',
                                    'routine',
                                    'informational'
                                )
                            ),

    confidence              numeric(5,4)
                            CHECK (
                                confidence IS NULL
                                OR (
                                    confidence >= 0
                                    AND confidence <= 1
                                )
                            ),

    created_at              timestamptz NOT NULL DEFAULT now(),

    updated_at              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.decision IS
'Complete CPU recommendation and clinician decision ledger. Machine recommendations
are advisory; clinician decisions remain authoritative.';


CREATE INDEX idx_cpu_decision_patient_time
    ON cpu.decision (patient_id, created_at DESC, id DESC);

CREATE INDEX idx_cpu_decision_encounter_time
    ON cpu.decision (encounter_id, created_at DESC, id DESC);

CREATE INDEX idx_cpu_decision_pending
    ON cpu.decision (patient_id, priority DESC, created_at DESC)
    WHERE status = 'pending';

CREATE INDEX idx_cpu_decision_status
    ON cpu.decision (status, created_at DESC);

CREATE INDEX idx_cpu_decision_trigger
    ON cpu.decision (triggering_event_id);

CREATE INDEX idx_cpu_decision_state
    ON cpu.decision (state_snapshot_id);

CREATE INDEX idx_cpu_decision_rule
    ON cpu.decision (rule_code, rule_version);

CREATE INDEX idx_cpu_decision_json
    ON cpu.decision
    USING GIN (reasoning jsonb_path_ops);


-- =============================================================================
-- 7. DECISION EVIDENCE
-- =============================================================================
-- Explicit links between a recommendation and the facts/observations that
-- contributed to it.
--
-- This prevents reasoning from being buried inside an opaque JSON blob.
-- =============================================================================

CREATE TABLE cpu.decision_evidence (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    decision_id         uuid NOT NULL
                        REFERENCES cpu.decision(id)
                        ON DELETE CASCADE,

    evidence_type       text NOT NULL
                        CHECK (
                            evidence_type IN (
                                'event',
                                'fact',
                                'symptom',
                                'sign',
                                'finding',
                                'measurement',
                                'phenotype',
                                'mechanism',
                                'condition',
                                'investigation',
                                'risk_factor',
                                'context'
                            )
                        ),

    evidence_code       text,

    event_id            bigint
                        REFERENCES cpu.event_log(id),

    source_id           uuid,

    polarity            text NOT NULL DEFAULT 'supporting'
                        CHECK (
                            polarity IN (
                                'supporting',
                                'contradicting',
                                'neutral'
                            )
                        ),

    contribution        numeric(6,4),

    explanation         text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.decision_evidence IS
'Atomic evidence contributing to a CPU recommendation, enabling explainable clinical reasoning.';


CREATE INDEX idx_cpu_decision_evidence_decision
    ON cpu.decision_evidence (decision_id);

CREATE INDEX idx_cpu_decision_evidence_event
    ON cpu.decision_evidence (event_id);

CREATE INDEX idx_cpu_decision_evidence_code
    ON cpu.decision_evidence (evidence_type, evidence_code);


-- =============================================================================
-- 8. CPU RUN
-- =============================================================================
-- One CPU invocation.
--
-- A run may consume one or many events and produce state snapshots,
-- recommendations and decisions.
-- =============================================================================

CREATE TABLE cpu.run (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id),

    trigger_event_id    bigint
                        REFERENCES cpu.event_log(id),

    trigger_type        text NOT NULL,

    status              text NOT NULL DEFAULT 'running'
                        CHECK (
                            status IN (
                                'queued',
                                'running',
                                'completed',
                                'failed',
                                'cancelled'
                            )
                        ),

    started_at          timestamptz NOT NULL DEFAULT now(),

    completed_at        timestamptz,

    duration_ms         bigint,

    events_consumed     integer NOT NULL DEFAULT 0,

    rules_evaluated     integer NOT NULL DEFAULT 0,

    rules_triggered     integer NOT NULL DEFAULT 0,

    questions_activated integer NOT NULL DEFAULT 0,

    recommendations     integer NOT NULL DEFAULT 0,

    state_version_before bigint,

    state_version_after  bigint,

    knowledge_version   text,

    cpu_version         text,

    error_code          text,

    error_message       text,

    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE cpu.run IS
'One deterministic CPU reasoning pass over a clinical event/state.';


CREATE INDEX idx_cpu_run_patient_time
    ON cpu.run (patient_id, started_at DESC);

CREATE INDEX idx_cpu_run_encounter_time
    ON cpu.run (encounter_id, started_at DESC);

CREATE INDEX idx_cpu_run_status
    ON cpu.run (status, started_at);

CREATE INDEX idx_cpu_run_trigger
    ON cpu.run (trigger_event_id);


-- =============================================================================
-- 9. CPU RUN EVENT
-- =============================================================================
-- Exact event set consumed by each CPU run.
-- =============================================================================

CREATE TABLE cpu.run_event (
    run_id              uuid NOT NULL
                        REFERENCES cpu.run(id)
                        ON DELETE CASCADE,

    event_id            bigint NOT NULL
                        REFERENCES cpu.event_log(id),

    sequence_no         integer NOT NULL,

    consumed_at         timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (run_id, event_id),

    UNIQUE (run_id, sequence_no)
);

COMMENT ON TABLE cpu.run_event IS
'Exact event-to-CPU-run mapping used for deterministic replay and audit.';


CREATE INDEX idx_cpu_run_event_event
    ON cpu.run_event (event_id);

CREATE INDEX idx_cpu_run_event_run_sequence
    ON cpu.run_event (run_id, sequence_no);


-- =============================================================================
-- 10. CPU RULE EXECUTION LEDGER
-- =============================================================================
-- Records which rules actually fired / did not fire.
--
-- This is critical for:
--   "Why did the CPU NOT recommend X?"
-- =============================================================================

CREATE TABLE cpu.rule_execution (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    run_id              uuid NOT NULL
                        REFERENCES cpu.run(id)
                        ON DELETE CASCADE,

    patient_id          uuid
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id),

    rule_code           text NOT NULL,

    rule_version        integer,

    evaluation_order    integer NOT NULL DEFAULT 0,

    result              text NOT NULL
                        CHECK (
                            result IN (
                                'matched',
                                'not_matched',
                                'skipped',
                                'blocked',
                                'error'
                            )
                        ),

    score               numeric(8,4),

    conditions_evaluated integer NOT NULL DEFAULT 0,

    conditions_matched   integer NOT NULL DEFAULT 0,

    condition_trace      jsonb NOT NULL DEFAULT '[]'::jsonb,

    action_trace         jsonb NOT NULL DEFAULT '[]'::jsonb,

    execution_time_us    bigint,

    created_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.rule_execution IS
'Runtime trace of clinical rule evaluation, including matched and non-matched rules.';


CREATE INDEX idx_cpu_rule_execution_run
    ON cpu.rule_execution (run_id, evaluation_order);

CREATE INDEX idx_cpu_rule_execution_patient
    ON cpu.rule_execution (patient_id, created_at DESC);

CREATE INDEX idx_cpu_rule_execution_rule
    ON cpu.rule_execution (rule_code, rule_version, created_at DESC);

CREATE INDEX idx_cpu_rule_execution_matched
    ON cpu.rule_execution (patient_id, result, created_at DESC);


-- =============================================================================
-- 11. CPU QUESTION ACTIVATION
-- =============================================================================
-- The CPU can dynamically decide which clinical question should be asked next.
-- =============================================================================

CREATE TABLE cpu.question_activation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id              uuid
                        REFERENCES cpu.run(id)
                        ON DELETE CASCADE,

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id),

    question_code       text NOT NULL,

    trigger_rule_code   text,

    trigger_event_id    bigint
                        REFERENCES cpu.event_log(id),

    priority            integer NOT NULL DEFAULT 50,

    requirement_level   text NOT NULL DEFAULT 'optional'
                        CHECK (
                            requirement_level IN (
                                'mandatory',
                                'conditionally_required',
                                'optional',
                                'informational'
                            )
                        ),

    reason              text,

    activation_context  jsonb NOT NULL DEFAULT '{}'::jsonb,

    status              text NOT NULL DEFAULT 'active'
                        CHECK (
                            status IN (
                                'active',
                                'answered',
                                'skipped',
                                'expired',
                                'superseded'
                            )
                        ),

    created_at          timestamptz NOT NULL DEFAULT now(),

    answered_at         timestamptz
);

COMMENT ON TABLE cpu.question_activation IS
'Dynamically activated clinical questions generated by the CPU based on current patient state.';


CREATE INDEX idx_cpu_question_patient
    ON cpu.question_activation
    (patient_id, status, priority DESC, created_at DESC);

CREATE INDEX idx_cpu_question_encounter
    ON cpu.question_activation
    (encounter_id, status, priority DESC);

CREATE INDEX idx_cpu_question_code
    ON cpu.question_activation
    (question_code, created_at DESC);


-- =============================================================================
-- 12. CPU ALERT
-- =============================================================================
-- High-priority runtime signals.
--
-- Examples:
--   hypoxaemia
--   shock
--   rapidly worsening respiratory rate
--   abnormal investigation
--   drug safety issue
--   missing mandatory assessment
-- =============================================================================

CREATE TABLE cpu.alert (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid
                        REFERENCES encounter.encounter(id),

    event_id            bigint
                        REFERENCES cpu.event_log(id),

    run_id              uuid
                        REFERENCES cpu.run(id),

    alert_code          text NOT NULL,

    alert_type          text NOT NULL
                        CHECK (
                            alert_type IN (
                                'red_flag',
                                'deterioration',
                                'critical_result',
                                'drug_safety',
                                'missing_information',
                                'protocol_deviation',
                                'system'
                            )
                        ),

    severity            text NOT NULL
                        CHECK (
                            severity IN (
                                'critical',
                                'high',
                                'moderate',
                                'low',
                                'informational'
                            )
                        ),

    title               text NOT NULL,

    message             text NOT NULL,

    evidence             jsonb NOT NULL DEFAULT '{}'::jsonb,

    status              text NOT NULL DEFAULT 'open'
                        CHECK (
                            status IN (
                                'open',
                                'acknowledged',
                                'resolved',
                                'dismissed'
                            )
                        ),

    acknowledged_by     uuid
                        REFERENCES identity.user_account(id),

    acknowledged_at    timestamptz,

    resolved_by         uuid
                        REFERENCES identity.user_account(id),

    resolved_at         timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),

    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.alert IS
'Real-time clinical safety and deterioration alert ledger generated by the CPU.';


CREATE INDEX idx_cpu_alert_patient_open
    ON cpu.alert (patient_id, severity, created_at DESC)
    WHERE status IN ('open', 'acknowledged');

CREATE INDEX idx_cpu_alert_encounter_open
    ON cpu.alert (encounter_id, severity, created_at DESC)
    WHERE status IN ('open', 'acknowledged');

CREATE INDEX idx_cpu_alert_status
    ON cpu.alert (status, severity, created_at DESC);

CREATE INDEX idx_cpu_alert_code
    ON cpu.alert (alert_code, created_at DESC);


-- =============================================================================
-- 13. CPU CLINICAL FACT CACHE
-- =============================================================================
-- High-speed fact lookup.
--
-- The CPU should not repeatedly traverse JSON state to answer:
--
--   "Does this patient currently have fever?"
--   "What is the latest SpO2?"
--   "Is cough productive?"
--
-- This table provides indexed access to the current normalized fact set.
-- =============================================================================

CREATE TABLE cpu.current_fact (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid,

    fact_code            text NOT NULL,

    value                jsonb,

    value_text           text,

    numeric_value        numeric,

    boolean_value        boolean,

    observed_at          timestamptz,

    source_event_id      bigint
                        REFERENCES cpu.event_log(id),

    confidence            numeric(5,4)
                         CHECK (
                             confidence IS NULL
                             OR (
                                 confidence >= 0
                                 AND confidence <= 1
                             )
                         ),

    status               text NOT NULL DEFAULT 'active'
                         CHECK (
                             status IN (
                                 'active',
                                 'resolved',
                                 'unknown',
                                 'superseded'
                             )
                         ),

    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (patient_id, encounter_id, fact_code)
);

COMMENT ON TABLE cpu.current_fact IS
'Indexed hot cache of the latest normalized clinical facts consumed by CPU rules.';


CREATE INDEX idx_cpu_fact_patient
    ON cpu.current_fact (patient_id, fact_code);

CREATE INDEX idx_cpu_fact_encounter
    ON cpu.current_fact (encounter_id, fact_code);

CREATE INDEX idx_cpu_fact_numeric
    ON cpu.current_fact (fact_code, numeric_value)
    WHERE numeric_value IS NOT NULL;

CREATE INDEX idx_cpu_fact_boolean
    ON cpu.current_fact (fact_code, boolean_value)
    WHERE boolean_value IS NOT NULL;

CREATE INDEX idx_cpu_fact_observed
    ON cpu.current_fact (patient_id, observed_at DESC);


-- =============================================================================
-- 14. FACT HISTORY
-- =============================================================================
-- Current_fact is hot state.
-- Fact_history preserves temporal clinical trajectory.
-- =============================================================================

CREATE TABLE cpu.fact_history (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    encounter_id        uuid,

    fact_code           text NOT NULL,

    value               jsonb,

    numeric_value       numeric,

    boolean_value       boolean,

    source_event_id     bigint
                        REFERENCES cpu.event_log(id),

    observed_at         timestamptz NOT NULL,

    recorded_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.fact_history IS
'Temporal history of normalized clinical facts used for trend analysis and replay.';


CREATE INDEX idx_cpu_fact_history_patient_code_time
    ON cpu.fact_history
    (patient_id, fact_code, observed_at DESC);

CREATE INDEX idx_cpu_fact_history_encounter_code_time
    ON cpu.fact_history
    (encounter_id, fact_code, observed_at DESC);

CREATE INDEX idx_cpu_fact_history_event
    ON cpu.fact_history (source_event_id);


-- =============================================================================
-- 15. CPU PROCESSING ERROR LEDGER
-- =============================================================================
-- Errors never disappear into application logs.
-- =============================================================================

CREATE TABLE cpu.processing_error (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    run_id              uuid
                        REFERENCES cpu.run(id)
                        ON DELETE SET NULL,

    event_id            bigint
                        REFERENCES cpu.event_log(id)
                        ON DELETE SET NULL,

    patient_id          uuid,

    error_code          text NOT NULL,

    error_message       text NOT NULL,

    stack_trace         text,

    retryable            boolean NOT NULL DEFAULT true,

    attempt_no           integer NOT NULL DEFAULT 1,

    created_at           timestamptz NOT NULL DEFAULT now(),

    resolved_at          timestamptz
);

COMMENT ON TABLE cpu.processing_error IS
'Durable CPU processing failures for retry, observability and operational diagnosis.';


CREATE INDEX idx_cpu_error_retryable
    ON cpu.processing_error (retryable, created_at)
    WHERE resolved_at IS NULL;

CREATE INDEX idx_cpu_error_run
    ON cpu.processing_error (run_id);

CREATE INDEX idx_cpu_error_event
    ON cpu.processing_error (event_id);

CREATE INDEX idx_cpu_error_patient
    ON cpu.processing_error (patient_id, created_at DESC);


-- =============================================================================
-- 16. CPU PERFORMANCE METRICS
-- =============================================================================
-- Keeps performance telemetry close to the clinical runtime.
-- =============================================================================

CREATE TABLE cpu.performance_sample (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    run_id              uuid
                        REFERENCES cpu.run(id)
                        ON DELETE CASCADE,

    patient_id          uuid,

    phase               text NOT NULL,

    duration_us         bigint NOT NULL,

    rows_examined       bigint,

    rows_returned       bigint,

    cache_hit           boolean,

    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,

    created_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.performance_sample IS
'Fine-grained CPU execution telemetry for identifying clinical reasoning bottlenecks.';


CREATE INDEX idx_cpu_perf_run
    ON cpu.performance_sample (run_id, phase);

CREATE INDEX idx_cpu_perf_phase_time
    ON cpu.performance_sample (phase, created_at DESC);


-- =============================================================================
-- 17. CPU KNOWLEDGE RESOLUTION TRACE
-- =============================================================================
-- Records the exact knowledge graph objects resolved during a run.
--
-- This makes:
--
--   DEFAULT KNOWLEDGE
--       ↓
--   CONTEXT
--       ↓
--   OVERRIDE
--       ↓
--   ACTIVE RULE
--
-- auditable.
-- =============================================================================

CREATE TABLE cpu.knowledge_resolution (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    run_id              uuid NOT NULL
                        REFERENCES cpu.run(id)
                        ON DELETE CASCADE,

    patient_id          uuid,

    encounter_id        uuid,

    target_type         text NOT NULL,

    target_id           uuid NOT NULL,

    resolved_source     text NOT NULL
                        CHECK (
                            resolved_source IN (
                                'default',
                                'organization',
                                'department',
                                'facility',
                                'clinician'
                            )
                        ),

    override_id         uuid,

    version             text,

    resolution_reason   text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.knowledge_resolution IS
'Exact knowledge source selected by the CPU after context and override resolution.';


CREATE INDEX idx_cpu_knowledge_resolution_run
    ON cpu.knowledge_resolution (run_id);

CREATE INDEX idx_cpu_knowledge_resolution_target
    ON cpu.knowledge_resolution (target_type, target_id, created_at DESC);

CREATE INDEX idx_cpu_knowledge_resolution_patient
    ON cpu.knowledge_resolution (patient_id, created_at DESC);


-- =============================================================================
-- 18. CPU RUN LOCK / LEASE
-- =============================================================================
-- Prevents concurrent CPU workers from mutating the same patient state.
-- =============================================================================

CREATE TABLE cpu.patient_lease (
    patient_id          uuid PRIMARY KEY
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,

    owner_id            text NOT NULL,

    acquired_at         timestamptz NOT NULL DEFAULT now(),

    expires_at          timestamptz NOT NULL,

    heartbeat_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE cpu.patient_lease IS
'Short-lived patient-scoped CPU lease preventing conflicting concurrent state transitions.';


CREATE INDEX idx_cpu_patient_lease_expiry
    ON cpu.patient_lease (expires_at);


-- =============================================================================
-- 19. LATEST STATE VIEW
-- =============================================================================

CREATE VIEW cpu.latest_state AS
SELECT
    ps.patient_id,
    ps.encounter_id,
    ps.state,
    ps.last_event_id,
    ps.event_sequence,
    ps.knowledge_version,
    ps.cpu_version,
    ps.state_hash,
    ps.status,
    ps.updated_at
FROM cpu.patient_state ps;

COMMENT ON VIEW cpu.latest_state IS
'Fast operational view of the current PatientClinicalState.';


-- =============================================================================
-- 20. OPEN CLINICAL ALERT VIEW
-- =============================================================================

CREATE VIEW cpu.open_alerts AS
SELECT
    a.id,
    a.patient_id,
    a.encounter_id,
    a.alert_code,
    a.alert_type,
    a.severity,
    a.title,
    a.message,
    a.evidence,
    a.status,
    a.created_at
FROM cpu.alert a
WHERE a.status IN ('open', 'acknowledged');

COMMENT ON VIEW cpu.open_alerts IS
'Current unresolved CPU-generated clinical safety alerts.';


-- =============================================================================
-- 21. PENDING CPU WORK VIEW
-- =============================================================================
-- Small indexed queue view. SKIP LOCKED can be used by workers against the
-- underlying event table.
-- =============================================================================

CREATE VIEW cpu.pending_events AS
SELECT
    id,
    event_type,
    patient_id,
    encounter_id,
    occurred_at,
    created_at,
    processing_attempts
FROM cpu.event_log
WHERE processing_status IN ('pending', 'failed');

COMMENT ON VIEW cpu.pending_events IS
'Pending and retryable CPU event queue. Workers should claim rows with FOR UPDATE SKIP LOCKED.';


-- =============================================================================
-- 22. UPDATED_AT TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_cpu_patient_state_updated
BEFORE UPDATE ON cpu.patient_state
FOR EACH ROW
EXECUTE FUNCTION cpu.touch_updated_at();


CREATE TRIGGER trg_cpu_decision_updated
BEFORE UPDATE ON cpu.decision
FOR EACH ROW
EXECUTE FUNCTION cpu.touch_updated_at();


CREATE TRIGGER trg_cpu_alert_updated
BEFORE UPDATE ON cpu.alert
FOR EACH ROW
EXECUTE FUNCTION cpu.touch_updated_at();


-- =============================================================================
-- 23. FAST PATIENT STATE UPSERT FUNCTION
-- =============================================================================
-- Atomic hot-state replacement.
--
-- The CPU supplies the expected event sequence.
-- If another worker already advanced the patient, the update affects zero rows.
-- This prevents stale CPU workers from overwriting newer clinical state.
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.commit_patient_state(
    p_patient_id uuid,
    p_encounter_id uuid,
    p_state jsonb,
    p_event_id bigint,
    p_event_sequence bigint,
    p_state_hash text,
    p_knowledge_version text,
    p_cpu_version text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated integer;
BEGIN

    UPDATE cpu.patient_state
    SET
        encounter_id      = p_encounter_id,
        state              = p_state,
        last_event_id      = p_event_id,
        event_sequence     = p_event_sequence,
        state_hash         = p_state_hash,
        knowledge_version  = p_knowledge_version,
        cpu_version        = p_cpu_version,
        updated_at         = now()
    WHERE patient_id = p_patient_id
      AND event_sequence < p_event_sequence;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 1 THEN
        INSERT INTO cpu.state_version (
            patient_id,
            version,
            last_event_id,
            state_hash,
            updated_at
        )
        VALUES (
            p_patient_id,
            p_event_sequence,
            p_event_id,
            p_state_hash,
            now()
        )
        ON CONFLICT (patient_id)
        DO UPDATE SET
            version      = EXCLUDED.version,
            last_event_id = EXCLUDED.last_event_id,
            state_hash   = EXCLUDED.state_hash,
            updated_at   = now();

        RETURN true;
    END IF;

    RETURN false;
END;
$$;


COMMENT ON FUNCTION cpu.commit_patient_state IS
'Atomic monotonic PatientClinicalState commit. Prevents stale CPU workers from overwriting newer state.';


-- =============================================================================
-- 24. INITIALIZE PATIENT CPU STATE
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.ensure_patient_state(
    p_patient_id uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO cpu.patient_state (
        patient_id,
        state,
        event_sequence
    )
    VALUES (
        p_patient_id,
        '{}'::jsonb,
        0
    )
    ON CONFLICT (patient_id) DO NOTHING;

    INSERT INTO cpu.state_version (
        patient_id,
        version
    )
    VALUES (
        p_patient_id,
        0
    )
    ON CONFLICT (patient_id) DO NOTHING;

END;
$$;


-- =============================================================================
-- 25. FAST CURRENT FACT UPSERT
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.upsert_current_fact(
    p_patient_id uuid,
    p_encounter_id uuid,
    p_fact_code text,
    p_value jsonb,
    p_numeric_value numeric,
    p_boolean_value boolean,
    p_observed_at timestamptz,
    p_source_event_id bigint,
    p_confidence numeric
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO cpu.current_fact (
        patient_id,
        encounter_id,
        fact_code,
        value,
        numeric_value,
        boolean_value,
        observed_at,
        source_event_id,
        confidence,
        status,
        updated_at
    )
    VALUES (
        p_patient_id,
        p_encounter_id,
        p_fact_code,
        p_value,
        p_numeric_value,
        p_boolean_value,
        p_observed_at,
        p_source_event_id,
        p_confidence,
        'active',
        now()
    )

    ON CONFLICT (
        patient_id,
        encounter_id,
        fact_code
    )

    DO UPDATE SET
        value          = EXCLUDED.value,
        numeric_value  = EXCLUDED.numeric_value,
        boolean_value  = EXCLUDED.boolean_value,
        observed_at    = EXCLUDED.observed_at,
        source_event_id = EXCLUDED.source_event_id,
        confidence     = EXCLUDED.confidence,
        status         = 'active',
        updated_at     = now()
    WHERE
        cpu.current_fact.observed_at IS NULL
        OR EXCLUDED.observed_at >= cpu.current_fact.observed_at;

END;
$$;


-- =============================================================================
-- 26. CPU EVENT CLAIM FUNCTION
-- =============================================================================
-- High-throughput worker primitive.
--
-- Multiple workers can execute this concurrently.
-- FOR UPDATE SKIP LOCKED ensures one worker claims a row.
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.claim_next_event(
    p_worker_id text
)
RETURNS TABLE (
    event_id bigint,
    event_type text,
    patient_id uuid,
    encounter_id uuid,
    payload jsonb,
    occurred_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN

    RETURN QUERY
    WITH candidate AS (
        SELECT e.id
        FROM cpu.event_log e
        WHERE e.processing_status IN ('pending', 'failed')
          AND e.processing_attempts < 10
        ORDER BY e.id
        FOR UPDATE SKIP LOCKED
        LIMIT 1
    )

    UPDATE cpu.event_log e
    SET
        processing_status   = 'processing',
        processing_attempts = e.processing_attempts + 1
    FROM candidate c
    WHERE e.id = c.id
    RETURNING
        e.id,
        e.event_type,
        e.patient_id,
        e.encounter_id,
        e.payload,
        e.occurred_at;

END;
$$;


-- =============================================================================
-- 27. EVENT PROCESSING COMPLETION
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.complete_event(
    p_event_id bigint,
    p_knowledge_version text,
    p_cpu_version text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE cpu.event_log
    SET
        processing_status = 'processed',
        processed_at      = now(),
        knowledge_version = p_knowledge_version,
        cpu_version       = p_cpu_version,
        processing_error  = NULL
    WHERE id = p_event_id;

END;
$$;


-- =============================================================================
-- 28. EVENT PROCESSING FAILURE
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.fail_event(
    p_event_id bigint,
    p_error text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE cpu.event_log
    SET
        processing_status = 'failed',
        processing_error  = p_error
    WHERE id = p_event_id;

END;
$$;


-- =============================================================================
-- 29. HOT PATIENT CLINICAL STATE
-- =============================================================================

CREATE OR REPLACE VIEW cpu.patient_clinical_state AS
SELECT
    ps.patient_id,
    ps.encounter_id,
    ps.state,
    ps.last_event_id,
    ps.event_sequence,
    ps.knowledge_version,
    ps.cpu_version,
    ps.state_hash,
    ps.status,
    ps.updated_at
FROM cpu.patient_state ps
WHERE ps.status = 'active';


-- =============================================================================
-- 30. ACTIVE PATIENT FACTS
-- =============================================================================

CREATE OR REPLACE VIEW cpu.active_patient_facts AS
SELECT
    cf.patient_id,
    cf.encounter_id,
    cf.fact_code,
    cf.value,
    cf.value_text,
    cf.numeric_value,
    cf.boolean_value,
    cf.observed_at,
    cf.source_event_id,
    cf.confidence
FROM cpu.current_fact cf
WHERE cf.status = 'active';


-- =============================================================================
-- 31. PATIENT CPU SUMMARY
-- =============================================================================
-- One fast query gives the application everything required for the command
-- surface without traversing the complete historical ledger.
-- =============================================================================

CREATE OR REPLACE VIEW cpu.patient_runtime_summary AS
SELECT
    ps.patient_id,
    ps.encounter_id,
    ps.event_sequence,
    ps.last_event_id,
    ps.knowledge_version,
    ps.cpu_version,
    ps.updated_at,

    (
        SELECT count(*)
        FROM cpu.alert a
        WHERE a.patient_id = ps.patient_id
          AND a.status IN ('open', 'acknowledged')
    ) AS open_alert_count,

    (
        SELECT count(*)
        FROM cpu.decision d
        WHERE d.patient_id = ps.patient_id
          AND d.status = 'pending'
    ) AS pending_decision_count,

    (
        SELECT count(*)
        FROM cpu.question_activation q
        WHERE q.patient_id = ps.patient_id
          AND q.status = 'active'
    ) AS active_question_count

FROM cpu.patient_state ps;


-- =============================================================================
-- 32. DATA INTEGRITY
-- =============================================================================

ALTER TABLE cpu.event_log
    ADD CONSTRAINT chk_cpu_event_processing_attempts
    CHECK (processing_attempts >= 0);

ALTER TABLE cpu.state_snapshot
    ADD CONSTRAINT chk_cpu_snapshot_version
    CHECK (state_version >= 0);

ALTER TABLE cpu.run
    ADD CONSTRAINT chk_cpu_run_counters
    CHECK (
        events_consumed >= 0
        AND rules_evaluated >= 0
        AND rules_triggered >= 0
        AND questions_activated >= 0
        AND recommendations >= 0
    );

ALTER TABLE cpu.rule_execution
    ADD CONSTRAINT chk_cpu_rule_execution_counts
    CHECK (
        conditions_evaluated >= 0
        AND conditions_matched >= 0
    );


-- =============================================================================
-- 33. IMMUTABILITY GUARD FOR EVENT LEDGER
-- =============================================================================
-- Clinical event history must not be silently rewritten.
-- Processing metadata remains mutable.
-- Payload / event identity / occurrence are protected.
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.protect_event_identity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.id <> OLD.id
       OR NEW.event_type <> OLD.event_type
       OR NEW.payload <> OLD.payload
       OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
       OR NEW.encounter_id IS DISTINCT FROM OLD.encounter_id
       OR NEW.occurred_at <> OLD.occurred_at
       OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
    THEN
        RAISE EXCEPTION
            'CPU event identity is immutable: event_id=%',
            OLD.id;
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_cpu_event_identity
BEFORE UPDATE ON cpu.event_log
FOR EACH ROW
EXECUTE FUNCTION cpu.protect_event_identity();


-- =============================================================================
-- 34. IMMUTABILITY GUARD FOR STATE SNAPSHOTS
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.prevent_snapshot_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'CPU state snapshots are immutable: snapshot_id=%',
        OLD.id;
END;
$$;


CREATE TRIGGER trg_cpu_snapshot_immutable
BEFORE UPDATE OR DELETE ON cpu.state_snapshot
FOR EACH ROW
EXECUTE FUNCTION cpu.prevent_snapshot_update();


-- =============================================================================
-- 35. IMMUTABILITY GUARD FOR RULE EXECUTION
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.prevent_rule_execution_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'CPU rule execution records are immutable: execution_id=%',
        OLD.id;
END;
$$;


CREATE TRIGGER trg_cpu_rule_execution_immutable
BEFORE UPDATE OR DELETE ON cpu.rule_execution
FOR EACH ROW
EXECUTE FUNCTION cpu.prevent_rule_execution_update();


-- =============================================================================
-- 36. EVENT RETENTION SUPPORT
-- =============================================================================
-- Do NOT automatically delete clinical events here.
-- Retention must be jurisdiction/facility-policy driven.
--
-- This index supports time-window archival jobs.
-- =============================================================================

CREATE INDEX idx_cpu_event_created_retention
    ON cpu.event_log (created_at, id);


CREATE INDEX idx_cpu_snapshot_created_retention
    ON cpu.state_snapshot (created_at, id);


CREATE INDEX idx_cpu_fact_history_recorded_retention
    ON cpu.fact_history (recorded_at, id);


-- =============================================================================
-- 37. HIGH-SPEED LATEST EVENT LOOKUP
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.latest_event(
    p_patient_id uuid
)
RETURNS cpu.event_log
LANGUAGE sql
STABLE
AS $$
    SELECT e
    FROM cpu.event_log e
    WHERE e.patient_id = p_patient_id
    ORDER BY e.id DESC
    LIMIT 1;
$$;


-- =============================================================================
-- 38. HIGH-SPEED CURRENT FACT LOOKUP
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.get_current_fact(
    p_patient_id uuid,
    p_fact_code text
)
RETURNS cpu.current_fact
LANGUAGE sql
STABLE
AS $$
    SELECT cf
    FROM cpu.current_fact cf
    WHERE cf.patient_id = p_patient_id
      AND cf.fact_code = p_fact_code
      AND cf.status = 'active'
    LIMIT 1;
$$;


-- =============================================================================
-- 39. HIGH-SPEED PATIENT STATE LOOKUP
-- =============================================================================

CREATE OR REPLACE FUNCTION cpu.get_patient_state(
    p_patient_id uuid
)
RETURNS cpu.patient_state
LANGUAGE sql
STABLE
AS $$
    SELECT ps
    FROM cpu.patient_state ps
    WHERE ps.patient_id = p_patient_id
    LIMIT 1;
$$;


-- =============================================================================
-- 40. CPU RUNTIME HEALTH
-- =============================================================================

CREATE OR REPLACE VIEW cpu.runtime_health AS
SELECT
    (
        SELECT count(*)
        FROM cpu.event_log
        WHERE processing_status = 'pending'
    ) AS pending_events,

    (
        SELECT count(*)
        FROM cpu.event_log
        WHERE processing_status = 'processing'
    ) AS processing_events,

    (
        SELECT count(*)
        FROM cpu.event_log
        WHERE processing_status = 'failed'
    ) AS failed_events,

    (
        SELECT count(*)
        FROM cpu.decision
        WHERE status = 'pending'
    ) AS pending_decisions,

    (
        SELECT count(*)
        FROM cpu.alert
        WHERE status IN ('open', 'acknowledged')
    ) AS open_alerts,

    (
        SELECT count(*)
        FROM cpu.question_activation
        WHERE status = 'active'
    ) AS active_questions,

    (
        SELECT max(id)
        FROM cpu.event_log
    ) AS latest_event_id,

    (
        SELECT max(created_at)
        FROM cpu.event_log
    ) AS latest_event_at;


COMMENT ON VIEW cpu.runtime_health IS
'Low-cost CPU runtime health surface for AMEXAN operational monitoring.';


-- =============================================================================
-- 41. PERFORMANCE SETTINGS / STORAGE HINTS
-- =============================================================================
-- PostgreSQL remains the durable clinical ledger.
-- Large append-only tables receive aggressive autovacuum/analyze settings.
-- =============================================================================

ALTER TABLE cpu.event_log SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.005
);

ALTER TABLE cpu.state_snapshot SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_analyze_scale_factor = 0.01
);

ALTER TABLE cpu.fact_history SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_analyze_scale_factor = 0.01
);

ALTER TABLE cpu.rule_execution SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_analyze_scale_factor = 0.01
);


-- =============================================================================
-- 42. CPU RUNTIME ARCHITECTURE
-- =============================================================================
--
-- FAST PATH
--
--   clinical event
--        │
--        ▼
--   cpu.event_log
--        │
--        ├──────────────► current_fact
--        │
--        ├──────────────► patient_state
--        │
--        ▼
--   cpu.run
--        │
--        ├──► knowledge resolution
--        │
--        ├──► rule execution
--        │
--        ├──► question activation
--        │
--        ├──► alerts
--        │
--        └──► decisions
--
--
-- AUDIT PATH
--
--   event
--      ↓
--   run
--      ↓
--   state_snapshot
--      ↓
--   rule_execution
--      ↓
--   knowledge_resolution
--      ↓
--   decision
--      ↓
--   decision_evidence
--
--
-- HOT DATA
--
--   cpu.patient_state
--   cpu.current_fact
--   cpu.alert
--   cpu.question_activation
--   cpu.decision
--
--
-- COLD / AUDIT DATA
--
--   cpu.event_log
--   cpu.state_snapshot
--   cpu.fact_history
--   cpu.rule_execution
--   cpu.knowledge_resolution
--   cpu.performance_sample
--
-- =============================================================================
-- END MIGRATION 018
-- =============================================================================