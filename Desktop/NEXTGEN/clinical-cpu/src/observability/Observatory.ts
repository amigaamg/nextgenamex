// =============================================================================
// AMEXAN Event Core (AEC) — CPU EVENT JOURNEY SPINE
// =============================================================================
//
// PURPOSE
// -----------------------------------------------------------------------------
// The AMEXAN Event Core is the durable observability nervous system underneath
// every clinical, computational, safety, workflow, integration and document
// operation.
//
// Nothing important should happen silently.
//
//                         AMEXAN
//                            │
//                            ▼
//                 ┌─────────────────────┐
//                 │   Event Core (AEC)  │
//                 └──────────┬──────────┘
//                            │
//                            ▼
//                    cpu.event_log
//                            │
//        ┌───────────────────┼────────────────────┐
//        ▼                   ▼                    ▼
//     Journey             Audit                Safety
//        │                   │                    │
//        ├───────────────────┼────────────────────┤
//        ▼                   ▼                    ▼
//     Workflow          Analytics          Notifications
//                            │
//                            ▼
//                       Observatory
//
// Canonical flow:
//
//   user / API / engine
//          │
//          ▼
//   recordJourneyEvent()
//          │
//          ▼
//   cpu.event_log
//          │
//          ├── correlation_id  → workflow lineage
//          ├── parent_event_id → causality
//          ├── idempotency_key → deduplication
//          ├── source_type     → producer classification
//          ├── source_id       → producer identity
//          ├── payload         → event-specific data
//          ├── fact_code/value → clinical fact linkage
//          └── processing_*    → CPU processing state
//
// IMPORTANT
// -----------------------------------------------------------------------------
// 1. This module is the SINGLE write helper for journey events.
// 2. No Admin UI should write directly to cpu.event_log.
// 3. Engines should use this helper rather than duplicating INSERT statements.
// 4. Clinical work and its journey event should preferably share the same
//    database transaction / connection.
// 5. idempotency_key is caller-controlled whenever deterministic deduplication
//    is required.
// 6. Automatically generated idempotency keys are unique per invocation but
//    do not provide retry deduplication.
// 7. User/patient identifiers are never fabricated here.
// 8. Read queries are strictly parameterized.
// 9. Read limits are bounded to protect the observability surface.
// 10. Event history is append-only from this module's perspective.
// =============================================================================

import { randomUUID } from 'node:crypto';
import type { Db, Row } from '../db.js';

// =============================================================================
// CANONICAL JOURNEY VOCABULARY
// =============================================================================
//
// Event names are intentionally stable strings.
//
// Do NOT casually rename an existing event type. Event types are consumed by
// observability, audit, safety, workflow, analytics and notification surfaces.
//
// New event types should be added here rather than scattered as string
// literals throughout the codebase.
// =============================================================================

export const JourneyEventType = {
  // ---------------------------------------------------------------------------
  // Encounter lifecycle
  // ---------------------------------------------------------------------------

  ENCOUNTER_CREATED: 'ENCOUNTER_CREATED',
  ENCOUNTER_OPENED: 'ENCOUNTER_OPENED',
  ENCOUNTER_COMPLETED: 'ENCOUNTER_COMPLETED',
  ENCOUNTER_CANCELLED: 'ENCOUNTER_CANCELLED',

  // ---------------------------------------------------------------------------
  // Clinical capture
  // ---------------------------------------------------------------------------

  BIODATA_CAPTURED: 'BIODATA_CAPTURED',
  FACT_CAPTURED: 'FACT_CAPTURED',
  FACT_CORRECTED: 'FACT_CORRECTED',

  QUESTION_DISPLAYED: 'QUESTION_DISPLAYED',
  ANSWER_RECEIVED: 'ANSWER_RECEIVED',

  // ---------------------------------------------------------------------------
  // CPU / engine lifecycle
  // ---------------------------------------------------------------------------

  CPU_PASS_STARTED: 'CPU_PASS_STARTED',
  CPU_PASS_COMPLETED: 'CPU_PASS_COMPLETED',
  CPU_PASS_FAILED: 'CPU_PASS_FAILED',

  CPU_ENGINE_STARTED: 'CPU_ENGINE_STARTED',
  CPU_ENGINE_COMPLETED: 'CPU_ENGINE_COMPLETED',
  CPU_ENGINE_FAILED: 'CPU_ENGINE_FAILED',

  // ---------------------------------------------------------------------------
  // Suggestions / clinician response
  // ---------------------------------------------------------------------------

  SUGGESTION_GENERATED: 'SUGGESTION_GENERATED',
  SUGGESTION_ACCEPTED: 'SUGGESTION_ACCEPTED',
  SUGGESTION_MODIFIED: 'SUGGESTION_MODIFIED',
  SUGGESTION_REJECTED: 'SUGGESTION_REJECTED',
  SUGGESTION_IGNORED: 'SUGGESTION_IGNORED',

  MEDICATION_OVERRIDE: 'MEDICATION_OVERRIDE',

  // ---------------------------------------------------------------------------
  // Safety
  // ---------------------------------------------------------------------------

  DOSE_SAFETY_CHECK: 'DOSE_SAFETY_CHECK',
  SAFETY_ALERT_GENERATED: 'SAFETY_ALERT_GENERATED',
  ALERT_ACKNOWLEDGED: 'ALERT_ACKNOWLEDGED',

  // ---------------------------------------------------------------------------
  // Documents
  // ---------------------------------------------------------------------------

  DOCUMENT_GENERATED: 'DOCUMENT_GENERATED',
  DOCUMENT_FINALIZED: 'DOCUMENT_FINALIZED',
  DOCUMENT_AMENDED: 'DOCUMENT_AMENDED',

  // ---------------------------------------------------------------------------
  // System
  // ---------------------------------------------------------------------------

  SYSTEM_SYNC: 'SYSTEM_SYNC',
  SYSTEM_CHECKPOINT: 'SYSTEM_CHECKPOINT',
} as const;

export type JourneyEventTypeName =
  (typeof JourneyEventType)[keyof typeof JourneyEventType];

// =============================================================================
// SOURCE TYPES
// =============================================================================

export const JOURNEY_SOURCE_TYPES = [
  'clinical',
  'clinician',
  'patient',
  'device',
  'laboratory',
  'imaging',
  'medication',
  'system',
  'integration',
  'import',
] as const;

export type JourneySourceType =
  (typeof JOURNEY_SOURCE_TYPES)[number];

// =============================================================================
// EVENT ENVELOPE
// =============================================================================

/**
 * Input contract for the Event Core.
 *
 * This is intentionally narrower than the database row.
 *
 * The caller describes what happened.
 * The Event Core is responsible for persistence.
 */
export interface JourneyEventEnvelope {
  /**
   * Canonical journey event type.
   *
   * string is retained for forward compatibility with newly introduced
   * event vocabulary that may be deployed before this package is upgraded.
   */
  eventType: JourneyEventTypeName | string;

  /**
   * Clinical patient context.
   */
  patientId?: string | null;

  /**
   * Encounter context.
   */
  encounterId?: string | null;

  /**
   * Producer classification.
   *
   * Must map to cpu.event_log.source_type.
   */
  sourceType?: JourneySourceType | string | null;

  /**
   * Producer identity.
   *
   * Examples:
   * - engine run ID
   * - API request ID
   * - integration message ID
   * - worker ID
   */
  sourceId?: string | null;

  /**
   * Logical workflow grouping.
   */
  correlationId?: string | null;

  /**
   * Direct causal predecessor.
   *
   * cpu.event_log currently uses a numeric event-log ID.
   */
  parentEventId?: number | null;

  /**
   * Retry / delivery deduplication key.
   *
   * IMPORTANT:
   * For deterministic retries, callers should supply a stable key.
   */
  idempotencyKey?: string | null;

  /**
   * Domain-specific event payload.
   */
  payload?: Record<string, unknown>;

  /**
   * Optional linked clinical fact.
   */
  factCode?: string | null;

  /**
   * Optional linked fact value.
   *
   * It will be serialized to JSON for persistence.
   */
  factValue?: unknown;

  /**
   * Actual occurrence time.
   *
   * Defaults to database time when omitted.
   */
  occurredAt?: Date;
}

// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface EventLogRow extends Row {
  id: number;
}

interface JourneyLogRow extends Row {
  id: number;

  event_type: string;

  patient_id: string | null;
  encounter_id: string | null;

  source_type: string;
  source_id: string | null;

  correlation_id: string | null;
  parent_event_id: number | null;

  payload: unknown;

  fact_code: string | null;
  fact_value: unknown;

  occurred_at: Date;
  created_at: Date;

  processing_status: string;
}

// =============================================================================
// LIMIT SAFETY
// =============================================================================

const DEFAULT_JOURNEY_LIMIT = 500;
const MAX_JOURNEY_LIMIT = 5000;

/**
 * Keep observability queries bounded.
 *
 * This prevents accidental requests such as LIMIT 999999999 from turning
 * the Admin Workspace into an uncontrolled database export mechanism.
 */
function normalizeJourneyLimit(limit: number | undefined): number {
  if (limit === undefined) {
    return DEFAULT_JOURNEY_LIMIT;
  }

  if (!Number.isFinite(limit)) {
    return DEFAULT_JOURNEY_LIMIT;
  }

  return Math.min(
    MAX_JOURNEY_LIMIT,
    Math.max(1, Math.floor(limit)),
  );
}

// =============================================================================
// SOURCE NORMALISATION
// =============================================================================

/**
 * Normalize arbitrary source input to the values accepted by
 * cpu.event_log.source_type.
 *
 * Unknown sources deliberately become `system`.
 *
 * This protects the database CHECK constraint and prevents engines from
 * failing merely because a new/unregistered source string was supplied.
 */
export function normalizeSourceType(
  value?: string | null,
): JourneySourceType {
  if (!value) {
    return 'system';
  }

  return JOURNEY_SOURCE_TYPES.includes(
    value as JourneySourceType,
  )
    ? (value as JourneySourceType)
    : 'system';
}

// =============================================================================
// STRING NORMALISATION
// =============================================================================

function nullableString(
  value?: string | null,
): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  const trimmed = value.trim();

  return trimmed === ''
    ? null
    : trimmed;
}

// =============================================================================
// FACT VALUE SERIALISATION
// =============================================================================

/**
 * Convert a fact value into a PostgreSQL JSON-compatible value.
 *
 * PostgreSQL JSON/JSONB columns can accept a serialized JSON string.
 *
 * `undefined` becomes NULL rather than the literal string "undefined".
 */
function serializeFactValue(
  value: unknown,
): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  if (
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return JSON.stringify(value);
  }

  try {
    return JSON.stringify(value);
  } catch {
    throw new TypeError(
      'AMEXAN Event Core: factValue is not JSON serializable',
    );
  }
}

// =============================================================================
// PAYLOAD VALIDATION
// =============================================================================

function normalizePayload(
  payload?: Record<string, unknown>,
): Record<string, unknown> {
  if (!payload) {
    return {};
  }

  if (
    typeof payload !== 'object' ||
    Array.isArray(payload)
  ) {
    throw new TypeError(
      'AMEXAN Event Core: event payload must be an object',
    );
  }

  return payload;
}

// =============================================================================
// EVENT VALIDATION
// =============================================================================

function validateJourneyEvent(
  input: JourneyEventEnvelope,
): void {
  if (
    typeof input.eventType !== 'string' ||
    input.eventType.trim() === ''
  ) {
    throw new TypeError(
      'AMEXAN Event Core: eventType is required',
    );
  }

  if (
    input.parentEventId !== undefined &&
    input.parentEventId !== null &&
    (
      !Number.isInteger(input.parentEventId) ||
      input.parentEventId < 1
    )
  ) {
    throw new TypeError(
      'AMEXAN Event Core: parentEventId must be a positive integer or null',
    );
  }

  if (
    input.occurredAt !== undefined &&
    !(
      input.occurredAt instanceof Date &&
      !Number.isNaN(input.occurredAt.getTime())
    )
  ) {
    throw new TypeError(
      'AMEXAN Event Core: occurredAt must be a valid Date',
    );
  }

  normalizePayload(input.payload);
}

// =============================================================================
// WRITE — CANONICAL EVENT RECORDER
// =============================================================================

/**
 * Record one durable journey event.
 *
 * IMPORTANT TRANSACTION SEMANTICS
 * -----------------------------------------------------------------------------
 * This function does not start or commit a transaction itself.
 *
 * If the caller is already executing inside a transaction, the event is
 * inserted through the supplied Db connection and therefore participates in
 * that transaction.
 *
 * Recommended engine pattern:
 *
 *   BEGIN
 *      clinical write
 *      CPU work
 *      recordJourneyEvent(db, ...)
 *   COMMIT
 *
 * This provides transactional-outbox-style durability:
 *
 *   clinical state + journey event
 *
 * either commit together or fail together.
 */
export async function recordJourneyEvent(
  db: Db,
  input: JourneyEventEnvelope,
): Promise<number> {
  validateJourneyEvent(input);

  const eventType = input.eventType.trim();

  const patientId =
    nullableString(input.patientId);

  const encounterId =
    nullableString(input.encounterId);

  const sourceType =
    normalizeSourceType(input.sourceType);

  const sourceId =
    nullableString(input.sourceId);

  const correlationId =
    nullableString(input.correlationId);

  const idempotencyKey =
    nullableString(input.idempotencyKey) ??
    randomUUID();

  const payload =
    normalizePayload(input.payload);

  const factCode =
    nullableString(input.factCode);

  const factValue =
    serializeFactValue(input.factValue);

  const occurredAt =
    input.occurredAt ?? null;

  // ---------------------------------------------------------------------------
  // IDEMPOTENCY
  // ---------------------------------------------------------------------------
  //
  // The actual uniqueness guarantee must be enforced by a UNIQUE constraint
  // or unique index on cpu.event_log.idempotency_key.
  //
  // Do not rely solely on an application-level SELECT-before-INSERT check:
  // concurrent requests could still race.
  //
  // ON CONFLICT returns the existing event ID when the idempotency key has
  // already been committed.
  // ---------------------------------------------------------------------------

  const row = await db.queryOne<EventLogRow>(
    `INSERT INTO cpu.event_log
      (
        event_type,
        patient_id,
        encounter_id,
        source_type,
        source_id,
        idempotency_key,
        correlation_id,
        parent_event_id,
        payload,
        fact_code,
        fact_value,
        occurred_at,
        created_at,
        processed_at,
        processing_status,
        processing_attempts
      )
     VALUES
      (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9::jsonb,
        $10,
        $11::jsonb,
        COALESCE($12::timestamptz, now()),
        now(),
        now(),
        'processed',
        1
      )
     ON CONFLICT (idempotency_key)
     DO UPDATE
       SET idempotency_key = EXCLUDED.idempotency_key
     RETURNING id`,
    [
      eventType,
      patientId,
      encounterId,
      sourceType,
      sourceId,
      idempotencyKey,
      correlationId,
      input.parentEventId ?? null,
      JSON.stringify(payload),
      factCode,
      factValue,
      occurredAt,
    ],
  );

  if (!row) {
    throw new Error(
      'AMEXAN Event Core: event insert returned no event ID',
    );
  }

  return row.id;
}

// =============================================================================
// WRITE HELPERS
// =============================================================================

/**
 * Record an event using a deterministic idempotency key.
 *
 * Useful when an operation has a stable business identity.
 */
export async function recordIdempotentJourneyEvent(
  db: Db,
  input: JourneyEventEnvelope,
  idempotencyKey: string,
): Promise<number> {
  return recordJourneyEvent(db, {
    ...input,
    idempotencyKey,
  });
}

/**
 * Record an event caused by another event.
 */
export async function recordChildJourneyEvent(
  db: Db,
  parentEventId: number,
  input: JourneyEventEnvelope,
): Promise<number> {
  return recordJourneyEvent(db, {
    ...input,
    parentEventId,
  });
}

// =============================================================================
// READ PROJECTION
// =============================================================================

export interface JourneyEventRow {
  id: number;

  eventType: string;

  patientId: string | null;
  encounterId: string | null;

  sourceType: string;
  sourceId: string | null;

  correlationId: string | null;
  parentEventId: number | null;

  payload: unknown;

  factCode: string | null;
  factValue: unknown;

  occurredAt: string;
  createdAt: string;

  processingStatus: string;
}

// =============================================================================
// DATABASE ROW → API PROJECTION
// =============================================================================

function mapJourneyRow(
  row: JourneyLogRow,
): JourneyEventRow {
  return {
    id: row.id,

    eventType: row.event_type,

    patientId: row.patient_id,
    encounterId: row.encounter_id,

    sourceType: row.source_type,
    sourceId: row.source_id,

    correlationId: row.correlation_id,
    parentEventId: row.parent_event_id,

    payload: row.payload,

    factCode: row.fact_code,
    factValue: row.fact_value,

    occurredAt:
      new Date(row.occurred_at).toISOString(),

    createdAt:
      new Date(row.created_at).toISOString(),

    processingStatus:
      row.processing_status,
  };
}

// =============================================================================
// SHARED SELECT
// =============================================================================

const JOURNEY_SELECT = `
  SELECT
    id,
    event_type,
    patient_id,
    encounter_id,
    source_type,
    source_id,
    correlation_id,
    parent_event_id,
    payload,
    fact_code,
    fact_value,
    occurred_at,
    created_at,
    processing_status
  FROM cpu.event_log
`;

// =============================================================================
// ENCOUNTER JOURNEY
// =============================================================================

/**
 * Full journey timeline for one encounter.
 *
 * Oldest event first.
 *
 * The query is intentionally ordered by the immutable event-log ID rather
 * than relying only on timestamps. This provides deterministic ordering when
 * several events have the same timestamp.
 */
export async function journeyForEncounter(
  db: Db,
  encounterId: string,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const normalizedEncounterId =
    nullableString(encounterId);

  if (!normalizedEncounterId) {
    return [];
  }

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE encounter_id = $1
     ORDER BY id ASC
     LIMIT $2`,
    [
      normalizedEncounterId,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// PATIENT JOURNEY
// =============================================================================

/**
 * Journey timeline for a patient across encounters.
 *
 * Oldest event first.
 */
export async function journeyForPatient(
  db: Db,
  patientId: string,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const normalizedPatientId =
    nullableString(patientId);

  if (!normalizedPatientId) {
    return [];
  }

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE patient_id = $1
     ORDER BY id ASC
     LIMIT $2`,
    [
      normalizedPatientId,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// CORRELATION JOURNEY
// =============================================================================

/**
 * Return every event belonging to a correlation/workflow.
 *
 * This is particularly important for the AMEXAN Admin Workspace because
 * correlation_id is the bridge between:
 *
 *   API request
 *      ↓
 *   encounter event
 *      ↓
 *   CPU pass
 *      ↓
 *   engine execution
 *      ↓
 *   suggestion
 *      ↓
 *   safety evaluation
 *      ↓
 *   clinician response
 */
export async function journeyForCorrelation(
  db: Db,
  correlationId: string,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const normalizedCorrelationId =
    nullableString(correlationId);

  if (!normalizedCorrelationId) {
    return [];
  }

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE correlation_id = $1
     ORDER BY id ASC
     LIMIT $2`,
    [
      normalizedCorrelationId,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// SOURCE JOURNEY
// =============================================================================

/**
 * Return events produced by a particular source identity.
 *
 * Useful for engine/runtime investigations.
 */
export async function journeyForSource(
  db: Db,
  sourceType: string,
  sourceId: string,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const normalizedSourceId =
    nullableString(sourceId);

  if (!normalizedSourceId) {
    return [];
  }

  const normalizedSourceType =
    normalizeSourceType(sourceType);

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE source_type = $1
       AND source_id = $2
     ORDER BY id ASC
     LIMIT $3`,
    [
      normalizedSourceType,
      normalizedSourceId,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// EVENT LOOKUP
// =============================================================================

/**
 * Retrieve one journey event by its numeric cpu.event_log ID.
 */
export async function getJourneyEvent(
  db: Db,
  eventId: number,
): Promise<JourneyEventRow | null> {
  if (
    !Number.isInteger(eventId) ||
    eventId < 1
  ) {
    return null;
  }

  const row = await db.queryOne<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE id = $1
     LIMIT 1`,
    [eventId],
  );

  return row
    ? mapJourneyRow(row)
    : null;
}

// =============================================================================
// CHILD EVENTS
// =============================================================================

/**
 * Retrieve direct children of an event.
 *
 * This allows the Admin Workspace to follow causality:
 *
 *   parent
 *      ├── child
 *      ├── child
 *      └── child
 */
export async function childJourneyEvents(
  db: Db,
  parentEventId: number,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  if (
    !Number.isInteger(parentEventId) ||
    parentEventId < 1
  ) {
    return [];
  }

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE parent_event_id = $1
     ORDER BY id ASC
     LIMIT $2`,
    [
      parentEventId,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// EVENT PROCESSING STATE
// =============================================================================

/**
 * Retrieve recent events by CPU processing status.
 *
 * Useful for runtime / worker observability.
 */
export async function journeyByProcessingStatus(
  db: Db,
  processingStatus: string,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const status =
    nullableString(processingStatus);

  if (!status) {
    return [];
  }

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE processing_status = $1
     ORDER BY id DESC
     LIMIT $2`,
    [
      status,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// RECENT GLOBAL JOURNEY
// =============================================================================

/**
 * Return the most recent AMEXAN journey events globally.
 *
 * This powers live operational/event-observatory surfaces.
 */
export async function recentJourneyEvents(
  db: Db,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     ORDER BY id DESC
     LIMIT $1`,
    [safeLimit],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// RECENT EVENTS BY TYPE
// =============================================================================

/**
 * Return recent events of one type.
 */
export async function recentJourneyEventsByType(
  db: Db,
  eventType: string,
  limit = DEFAULT_JOURNEY_LIMIT,
): Promise<JourneyEventRow[]> {
  const normalizedEventType =
    nullableString(eventType);

  if (!normalizedEventType) {
    return [];
  }

  const safeLimit =
    normalizeJourneyLimit(limit);

  const rows = await db.query<JourneyLogRow>(
    `${JOURNEY_SELECT}
     WHERE event_type = $1
     ORDER BY id DESC
     LIMIT $2`,
    [
      normalizedEventType,
      safeLimit,
    ],
  );

  return rows.map(mapJourneyRow);
}

// =============================================================================
// JOURNEY COUNT
// =============================================================================

/**
 * Count journey events for an encounter.
 *
 * Kept separate from the timeline query so dashboards do not need to retrieve
 * hundreds/thousands of event rows merely to display a count.
 */
export async function countJourneyEventsForEncounter(
  db: Db,
  encounterId: string,
): Promise<number> {
  const normalizedEncounterId =
    nullableString(encounterId);

  if (!normalizedEncounterId) {
    return 0;
  }

  const row = await db.queryOne<{
    count: string | number;
  }>(
    `SELECT COUNT(*)::bigint AS count
     FROM cpu.event_log
     WHERE encounter_id = $1`,
    [normalizedEncounterId],
  );

  return Number(row?.count ?? 0);
}

// =============================================================================
// CORRELATION COUNT
// =============================================================================

export async function countJourneyEventsForCorrelation(
  db: Db,
  correlationId: string,
): Promise<number> {
  const normalizedCorrelationId =
    nullableString(correlationId);

  if (!normalizedCorrelationId) {
    return 0;
  }

  const row = await db.queryOne<{
    count: string | number;
  }>(
    `SELECT COUNT(*)::bigint AS count
     FROM cpu.event_log
     WHERE correlation_id = $1`,
    [normalizedCorrelationId],
  );

  return Number(row?.count ?? 0);
}

// =============================================================================
// EVENT CORE HEALTH
// =============================================================================

export interface EventCoreHealth {
  totalEvents: number;
  pendingEvents: number;
  processingEvents: number;
  processedEvents: number;
  failedEvents: number;
  ignoredEvents: number;
}

/**
 * Lightweight Event Core health projection.
 *
 * This is designed for the AMEXAN Runtime / Command Center rather than
 * replacing the dedicated runtime metrics subsystem.
 */
export async function getEventCoreHealth(
  db: Db,
): Promise<EventCoreHealth> {
  const rows = await db.query<{
    processing_status: string;
    count: string | number;
  }>(
    `SELECT
       processing_status,
       COUNT(*)::bigint AS count
     FROM cpu.event_log
     GROUP BY processing_status`,
  );

  let pendingEvents = 0;
  let processingEvents = 0;
  let processedEvents = 0;
  let failedEvents = 0;
  let ignoredEvents = 0;

  for (const row of rows) {
    const count =
      Number(row.count ?? 0);

    switch (row.processing_status) {
      case 'pending':
        pendingEvents += count;
        break;

      case 'processing':
        processingEvents += count;
        break;

      case 'processed':
        processedEvents += count;
        break;

      case 'failed':
        failedEvents += count;
        break;

      case 'ignored':
        ignoredEvents += count;
        break;

      default:
        break;
    }
  }

  return {
    totalEvents:
      pendingEvents +
      processingEvents +
      processedEvents +
      failedEvents +
      ignoredEvents,

    pendingEvents,
    processingEvents,
    processedEvents,
    failedEvents,
    ignoredEvents,
  };
}

// =============================================================================
// END OF AMEXAN EVENT CORE
// =============================================================================