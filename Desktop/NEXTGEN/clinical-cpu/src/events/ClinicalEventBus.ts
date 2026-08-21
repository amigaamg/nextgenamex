// =============================================================================
// AMEXAN Clinical CPU — ClinicalEventBus
// =============================================================================
//
// PURPOSE
// -----------------------------------------------------------------------------
// The ClinicalEventBus is the provenance and re-processing boundary of the
// AMEXAN Clinical Operating System.
//
// Every clinically meaningful change entering the CPU is:
//
//   1. validated,
//   2. enriched with immutable clinical context,
//   3. persisted to cpu.event_log,
//   4. assigned a provenance identity,
//   5. made available for downstream CPU processing.
//
// The event log is NOT merely an application log.
//
// It is the chronological clinical provenance chain from which AMEXAN can
// reconstruct:
//
//   WHAT happened
//   WHO caused it
//   WHEN it happened
//   TO WHICH patient
//   IN WHICH encounter
//   FROM WHICH clinical source
//   WHAT payload entered the CPU
//
// IMPORTANT CLINICAL PRINCIPLES
// -----------------------------------------------------------------------------
// • Events are facts about system activity, not diagnoses.
// • The EventBus does not make clinical decisions.
// • The EventBus does not mutate clinical facts.
// • The EventBus does not infer missing clinical information.
// • The clinician remains the clinical decision authority.
// • Reprocessing must be deterministic and traceable.
// • Patient and encounter identity are carried at the event boundary.
// • The original event payload is preserved.
// • Database transaction boundaries are respected by the caller/DB layer.
// • Event recording must fail closed: a clinically meaningful event must not
//   silently disappear.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ClinicalEvent, ProcessRequest } from '../types.js';

interface EventLogRow extends Row {
  id: number;
}

interface NormalizedEventPayload {
  patientId: string;
  encounterId: string | null;
  clinicianId: string | null;
  [key: string]: unknown;
}

const EVENT_TYPES = new Set<string>([
  'FACT_CAPTURED',
  'FACT_UPDATED',
  'FACT_RETRACTED',
  'QUESTION_ANSWERED',
  'QUESTION_SKIPPED',
  'QUESTION_DISPOSITIONED',
  'SYMPTOM_PRESENTED',
  'CHIEF_COMPLAINTS_SAVED',
  'ENCOUNTER_CREATED',
  'ENCOUNTER_UPDATED',
  'ENCOUNTER_DISPOSITIONED',
  'CLINICIAN_DECISION',
  'EXAM_FINDING_CAPTURED',
  'IMAGING_RESULT_RECEIVED',
  'LAB_RESULT_RECEIVED',
  'VITAL_CHANGED',
  'INVESTIGATION_RESULT_RECORDED',
  'MEDICATION_RECORDED',
  'VITAL_SIGN_RECORDED',
  'EXAMINATION_RECORDED',
  'ALLERGY_RECORDED',
  'PROBLEM_RECORDED',
  'DIAGNOSIS_RECORDED',
  'PROCEDURE_RECORDED',
  'REFERRAL_RECORDED',
  'ADMISSION_RECORDED',
  'DISCHARGE_RECORDED',
  'PATIENT_TRANSFERRED',
  'DOCUMENTATION_ACCEPTED',
  'DOCUMENTATION_MODIFIED',
  'DOCUMENTATION_REJECTED',
  'PROTOCOL_STARTED',
  'PROTOCOL_UPDATED',
  'PROTOCOL_COMPLETED',
]);

/**
 * ClinicalEventBus
 *
 * Thin persistence boundary for clinically meaningful CPU events.
 *
 * The bus deliberately does not contain diagnostic or therapeutic logic.
 * Its responsibility is provenance, identity propagation and durable event
 * recording.
 */
export class ClinicalEventBus {
  constructor(private readonly db: Db) {}

  /**
   * Record one clinical event.
   *
   * The request context is authoritative for patient/encounter/clinician
   * identity. These values are written both as structured columns and into
   * the JSON payload so that:
   *
   *   - SQL queries can efficiently filter events;
   *   - the event remains self-describing when inspected independently.
   */
  async record(request: ProcessRequest): Promise<number> {
    this.validateRequest(request);

    const payload = buildEventPayload(request);

    const row = await this.db.queryOne<EventLogRow>(
      `
      INSERT INTO cpu.event_log
        (
          event_type,
          payload,
          patient_id,
          encounter_id
        )
      VALUES
        (
          $1,
          $2::jsonb,
          $3,
          $4
        )
      RETURNING id
      `,
      [
        request.event.type,
        JSON.stringify(payload),
        request.patientId,
        request.encounterId ?? null,
      ],
    );

    if (!row?.id) {
      throw new Error(
        `AMEXAN ClinicalEventBus: event "${request.event.type}" was not persisted`,
      );
    }

    return Number(row.id);
  }

  /**
   * Record an event and return its provenance identifier.
   *
   * This alias makes intent explicit at orchestration boundaries.
   */
  async publish(request: ProcessRequest): Promise<number> {
    return this.record(request);
  }

  /**
   * Record several events in their supplied order.
   *
   * The database transaction belongs to the Db abstraction. This method does
   * not pretend that independent INSERTs constitute a transaction.
   *
   * If the underlying Db implementation exposes transactional execution,
   * callers should wrap this operation in that transaction.
   */
  async recordMany(requests: ProcessRequest[]): Promise<number[]> {
    if (requests.length === 0) return [];

    const ids: number[] = [];

    for (const request of requests) {
      ids.push(await this.record(request));
    }

    return ids;
  }

  /**
   * Validate the event at the CPU boundary.
   *
   * Clinical identity must never be silently absent.
   */
  private validateRequest(request: ProcessRequest): void {
    if (!request) {
      throw new Error(
        'AMEXAN ClinicalEventBus: ProcessRequest is required',
      );
    }

    if (!request.patientId || !request.patientId.trim()) {
      throw new Error(
        'AMEXAN ClinicalEventBus: patientId is required',
      );
    }

    if (!request.event) {
      throw new Error(
        'AMEXAN ClinicalEventBus: clinical event is required',
      );
    }

    if (!request.event.type || !request.event.type.trim()) {
      throw new Error(
        'AMEXAN ClinicalEventBus: event type is required',
      );
    }

    if (!EVENT_TYPES.has(request.event.type)) {
      throw new Error(
        `AMEXAN ClinicalEventBus: unsupported clinical event type "${request.event.type}"`,
      );
    }

    if (
      request.event.payload !== undefined &&
      (typeof request.event.payload !== 'object' ||
        request.event.payload === null ||
        Array.isArray(request.event.payload))
    ) {
      throw new Error(
        `AMEXAN ClinicalEventBus: payload for "${request.event.type}" must be an object`,
      );
    }
  }
}

/**
 * Construct the canonical event payload.
 *
 * Context fields from ProcessRequest deliberately overwrite any conflicting
 * values supplied by the UI/event producer. This prevents a client from
 * recording an event under a different patient or encounter merely by
 * injecting patientId/encounterId into its payload.
 */
function buildEventPayload(
  request: ProcessRequest,
): NormalizedEventPayload {
  const originalPayload =
    request.event.payload &&
    typeof request.event.payload === 'object' &&
    !Array.isArray(request.event.payload)
      ? request.event.payload
      : {};

  return {
    ...(originalPayload as Record<string, unknown>),

    // CPU execution context is authoritative.
    patientId: request.patientId,
    encounterId: request.encounterId ?? null,
    clinicianId: request.clinicianId ?? null,
  };
}

/**
 * Human-readable event label for clinical UI.
 *
 * Example:
 *
 *   FACT_CAPTURED
 *   →
 *   fact captured
 */
export function eventLabel(event: ClinicalEvent): string {
  if (!event?.type) return 'unknown event';

  return event.type
    .trim()
    .replaceAll('_', ' ')
    .toLowerCase();
}

/**
 * Human-readable title for clinical UI.
 *
 * Example:
 *
 *   QUESTION_ANSWERED
 *   →
 *   Question answered
 */
export function eventTitle(event: ClinicalEvent): string {
  const label = eventLabel(event);

  if (!label) return 'Unknown event';

  return label.charAt(0).toUpperCase() + label.slice(1);
}

/**
 * Determine whether an event changes clinical state.
 *
 * Administrative/UI-only events should not automatically re-run clinical
 * reasoning. This prevents unnecessary CPU cycles and, more importantly,
 * prevents non-clinical interface activity from appearing to alter clinical
 * reasoning.
 */
export function isClinicalStateEvent(event: ClinicalEvent): boolean {
  if (!event?.type) return false;

  return new Set([
    'FACT_CAPTURED',
    'FACT_UPDATED',
    'FACT_RETRACTED',
    'QUESTION_ANSWERED',
    'QUESTION_SKIPPED',
    'QUESTION_DISPOSITIONED',
    'SYMPTOM_PRESENTED',
    'CHIEF_COMPLAINTS_SAVED',
    'ENCOUNTER_DISPOSITIONED',
    'INVESTIGATION_RESULT_RECORDED',
    'MEDICATION_RECORDED',
    'VITAL_SIGN_RECORDED',
    'EXAMINATION_RECORDED',
    'ALLERGY_RECORDED',
    'PROBLEM_RECORDED',
    'DIAGNOSIS_RECORDED',
    'PROCEDURE_RECORDED',
    'REFERRAL_RECORDED',
    'ADMISSION_RECORDED',
    'DISCHARGE_RECORDED',
    'PATIENT_TRANSFERRED',
  ]).has(event.type);
}

/**
 * Events representing clinician acceptance/rejection/modification.
 *
 * These are provenance events and must be preserved, but they should not be
 * interpreted as newly captured patient facts.
 */
export function isClinicianDecisionEvent(
  event: ClinicalEvent,
): boolean {
  return event?.type === 'CLINICIAN_DECISION';
}

/**
 * Events that represent changes to generated documentation.
 */
export function isDocumentationEvent(
  event: ClinicalEvent,
): boolean {
  if (!event?.type) return false;

  return new Set([
    'DOCUMENTATION_ACCEPTED',
    'DOCUMENTATION_MODIFIED',
    'DOCUMENTATION_REJECTED',
  ]).has(event.type);
}

/**
 * Events that should normally trigger re-evaluation of the clinical CPU.
 *
 * The CPU should reason again when clinically relevant information changes,
 * but not merely because a clinician accepted or rejected a generated
 * sentence.
 */
export function shouldReprocess(event: ClinicalEvent): boolean {
  return isClinicalStateEvent(event);
}