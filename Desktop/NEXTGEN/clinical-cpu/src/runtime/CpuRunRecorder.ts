// =============================================================================
// AMEXAN — CpuRunRecorder
// =============================================================================
//
// Durable lifecycle tracking for every ClinicalCPU pass on `cpu.run`.
//
// One `cpu.run` row is opened when a pass starts and finalised to
// `completed` / `failed` once the pass settles. This gives the admin Runtime
// view (§ runtime observability) run lifecycle, throughput, failure rate and
// per-stage engine timings without coupling the orchestrator to the admin API.
//
// `cpu.run` columns (subset used here):
//
//   id                     uuid (gen_random_uuid)
//   patient_id, encounter_id
//   trigger_event_id       bigint — the immutable event that caused the pass
//   trigger_type           text   — request.event.type
//   status                 'running' | 'completed' | 'failed'
//   started_at             timestamptz (now() by default)
//   completed_at           timestamptz
//   duration_ms            bigint
//   events_consumed        integer
//   rules_evaluated        integer
//   rules_triggered        integer
//   questions_activated    integer
//   recommendations        integer
//   state_version_before   bigint
//   state_version_after    bigint
//   knowledge_version      text
//   cpu_version            text
//   error_code, error_message
//   metadata               jsonb
// =============================================================================

import type { Db, Row } from '../db.js';

export interface RecordedRun {
  id: string;
}interface RunRow extends Row {
  id: string;
}

export interface CpuRunStart {
  patientId: string;
  encounterId?: string | null;
  triggerEventId: number;
  triggerType: string;
  stateVersionBefore?: number | null;
}

export interface CpuRunFinalize {
  status: 'completed' | 'failed';
  completedAt?: Date;
  durationMs?: number;
  eventsConsumed?: number;
  rulesEvaluated?: number;
  rulesTriggered?: number;
  questionsActivated?: number;
  recommendations?: number;
  knowledgeVersion?: string | null;
  cpuVersion?: string | null;
  errorCode?: string | null;
  errorMessage?: string | null;
  metadata?: Record<string, unknown>;
}

/**
 * Open a CPU run row. Durable once awaited; caller retains `run.id` to
 * finalise the same row after the pass settles.
 */
export async function recordCpuRun(
  db: Db,
  input: CpuRunStart,
): Promise<RecordedRun> {
  const row = await db.queryOne<RunRow>(
    `INSERT INTO cpu.run
       (patient_id, encounter_id, trigger_event_id, trigger_type,
        state_version_before)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id`,
    [
      input.patientId,
      input.encounterId ?? null,
      input.triggerEventId,
      input.triggerType,
      input.stateVersionBefore ?? null,
    ],
  );
  return { id: row!.id };
}

/**
 * Close a CPU run row. Intended to be invoked once per run, either on the
 * completed path or the failure path.
 */
export async function recordCpuRunFinalize(
  db: Db,
  runId: string,
  input: CpuRunFinalize,
): Promise<void> {
  await db.query(
    `UPDATE cpu.run SET
       status             = $2,
       completed_at       = COALESCE($3::timestamptz, now()),
       duration_ms        = $4,
       events_consumed    = $5,
       rules_evaluated    = $6,
       rules_triggered    = $7,
       questions_activated = $8,
       recommendations    = $9,
       knowledge_version  = $10,
       cpu_version        = $11,
       error_code         = $12,
       error_message      = $13,
       metadata           = $14::jsonb
     WHERE id = $1`,
    [
      runId,
      input.status,
      input.completedAt ?? null,
      input.durationMs ?? null,
      input.eventsConsumed ?? 0,
      input.rulesEvaluated ?? 0,
      input.rulesTriggered ?? 0,
      input.questionsActivated ?? 0,
      input.recommendations ?? 0,
      input.knowledgeVersion ?? null,
      input.cpuVersion ?? null,
      input.errorCode ?? null,
      input.errorMessage ?? null,
      JSON.stringify(input.metadata ?? {}),
    ],
  );
}

// =============================================================================
// PROCESSING ERROR — DEAD LETTER
// =============================================================================
//
// A failed CPU pass writes a durable dead-letter row to `cpu.processing_error`
// so the Runtime view can show unresolved failures, retry counters and the
// stack trace behind each failed run. Idempotent per run id.

export interface ProcessingErrorInput {
  runId: string;
  eventId?: number | null;
  patientId: string;
  errorCode: string;
  errorMessage: string;
  stackTrace?: string | null;
  retryable?: boolean;
  attemptNo?: number;
}

export async function recordProcessingError(
  db: Db,
  input: ProcessingErrorInput,
): Promise<void> {
  await db.query(
    `INSERT INTO cpu.processing_error
       (run_id, event_id, patient_id, error_code, error_message,
        stack_trace, retryable, attempt_no)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (run_id) DO NOTHING`,
    [
      input.runId,
      input.eventId ?? null,
      input.patientId,
      input.errorCode,
      input.errorMessage,
      input.stackTrace ?? null,
      input.retryable ?? false,
      input.attemptNo ?? 1,
    ],
  );
}

// =============================================================================
// EVENT CHECKPOINT — WORKER POSITION
// =============================================================================
//
// Records the highest event id consumed by a worker so the Runtime view can
// show each worker's position, lease ownership and heartbeat. Upsert per
// worker_code (the table's unique key).

export interface EventCheckpointInput {
  workerCode: string;
  lastEventId: number;
  leaseOwner?: string | null;
  leaseSeconds?: number;
}

export async function recordEventCheckpoint(
  db: Db,
  input: EventCheckpointInput,
): Promise<void> {
  await db.query(
    `INSERT INTO cpu.event_checkpoint
       (worker_code, last_event_id, lease_owner, lease_expires_at, heartbeat_at)
     VALUES ($1, $2, $3, now() + make_interval(secs => $4), now())
     ON CONFLICT (worker_code) DO UPDATE SET
       last_event_id    = EXCLUDED.last_event_id,
       lease_owner      = EXCLUDED.lease_owner,
       lease_expires_at = EXCLUDED.lease_expires_at,
       heartbeat_at     = now(),
       updated_at       = now()`,
    [
      input.workerCode,
      input.lastEventId,
      input.leaseOwner ?? null,
      input.leaseSeconds ?? 60,
    ],
  );
}

// =============================================================================
// RULE EXECUTION — OBSERVABILITY MIRROR
// =============================================================================
//
// `cpu.rule_execution` is the runtime observability projection of the governed
// rule executions already written to `governance.rule_execution`. It adds the
// run/patient/encounter dimensions the Runtime analytics aggregate on, plus a
// result/score extracted from the governance output payload.

export interface RuleExecutionMirrorInput {
  cpuRunId: string;
  governanceRunId: string;
  patientId: string;
  encounterId?: string | null;
}

export async function mirrorRuleExecutions(
  db: Db,
  input: RuleExecutionMirrorInput,
): Promise<number> {
  const row = await db.queryOne<Row>(
    `WITH inserted AS (
       INSERT INTO cpu.rule_execution
         (run_id, patient_id, encounter_id, rule_code, result, score)
       SELECT
         $1,
         $2,
         $3,
         g.rule_code,
         CASE
           WHEN (g.output->>'compatibility')::numeric IS NOT NULL
                AND (g.output->>'compatibility')::numeric >= 0.5 THEN 'matched'
           WHEN (g.output->>'compatibility')::numeric IS NOT NULL THEN 'not_matched'
           ELSE 'skipped'
         END,
         COALESCE(
           (g.output->>'compatibility')::numeric,
           (g.output->>'score')::numeric
         )
       FROM governance.rule_execution g
       WHERE g.run_id = $4
       ON CONFLICT (run_id, rule_code) DO NOTHING
       RETURNING 1
     )
     SELECT count(*)::text AS n FROM inserted`,
    [
      input.cpuRunId,
      input.patientId,
      input.encounterId ?? null,
      input.governanceRunId,
    ],
  );
  return Number(row?.n ?? 0);
}