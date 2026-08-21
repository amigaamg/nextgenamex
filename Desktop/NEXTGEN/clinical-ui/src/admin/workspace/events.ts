// =============================================================================
// AMEXAN Admin Workspace — Event Envelope
//
// CANONICAL EVENT CONTRACT
//
// Every observable event generated anywhere in AMEXAN should ultimately
// conform to AmexanEventEnvelope.
//
// Event flow:
//
//   Clinical / Admin / Integration / Runtime
//                    │
//                    ▼
//          AmexanEventEnvelope
//                    │
//          ┌─────────┼──────────┬──────────┬──────────┐
//          ▼         ▼          ▼          ▼          ▼
//        Audit     Safety     Workflow   Analytics  Notifications
//          │         │          │          │          │
//          └─────────┴──────────┴──────────┴──────────┘
//                              │
//                              ▼
//                       Observability
//
// IMPORTANT DESIGN RULES
// 1. eventId is the canonical immutable event identity.
// 2. correlationId groups events belonging to one operation / clinical journey.
// 3. causationId identifies the event that directly caused this event.
// 4. occurredAt represents event occurrence time, not ingestion time.
// 5. payload contains domain-specific information.
// 6. metadata contains non-domain observability/context information.
// 7. Patient/encounter identifiers are optional and must never be fabricated.
// 8. The Admin Workspace observes events; it does not mutate event history.
// 9. Numeric legacy IDs remain display-compatible, but canonical IDs are strings.
// =============================================================================

import type { EventSelection } from './types';

// =============================================================================
// CANONICAL ENUMERATIONS
// =============================================================================

export type AmexanEventSeverity =
  | 'debug'
  | 'info'
  | 'notice'
  | 'warning'
  | 'high'
  | 'critical';

export interface AmexanEventSource {
  /**
   * Service/process which emitted the event.
   *
   * Examples:
   * - clinical-runtime
   * - control-plane
   * - notification-service
   * - integration-service
   */
  service: string;

  /**
   * Optional AMEXAN engine responsible for the event.
   */
  engine?: string;

  /**
   * Engine version responsible for the event.
   */
  engineVersion?: string;
}

// =============================================================================
// CANONICAL EVENT ENVELOPE
// =============================================================================

/**
 * Canonical AMEXAN event envelope.
 *
 * This is the event-bus-level contract.
 *
 * `TPayload` allows individual domains to provide strongly typed payloads
 * without weakening the envelope itself.
 */
export interface AmexanEventEnvelope<TPayload = unknown> {
  /**
   * Immutable globally unique event identity.
   *
   * This must never be reused for another event.
   *
   * Examples:
   * - evt_01J...
   * - 8f8c...
   * - legacy numeric IDs represented as strings
   */
  eventId: string;

  /**
   * Stable event type.
   *
   * Examples:
   * - clinical.encounter.created
   * - clinical.alert.raised
   * - workflow.step.completed
   * - governance.audit_event
   */
  eventType: string;

  /**
   * Schema version of this event type.
   */
  eventVersion: number;

  /**
   * Time at which the event actually occurred.
   *
   * ISO-8601 timestamp.
   */
  occurredAt: string;

  /**
   * Groups events belonging to the same logical operation,
   * clinical journey, request, workflow, or transaction.
   */
  correlationId: string;

  /**
   * Direct causal predecessor.
   *
   * Example:
   *
   * Event A:
   *   encounter.created
   *
   * Event B:
   *   clinical.alert.raised
   *   causationId = Event A.eventId
   */
  causationId?: string;

  /**
   * Identity of the actor responsible for producing or initiating
   * the event.
   *
   * This may be a human, service account, worker, engine, or system actor.
   */
  actorId?: string;

  /**
   * AMEXAN organization context.
   */
  organizationId?: string;

  /**
   * Facility context.
   */
  facilityId?: string;

  /**
   * Department / clinical-unit context.
   */
  departmentId?: string;

  /**
   * Patient context.
   *
   * Optional because many events are not patient-related.
   */
  patientId?: string;

  /**
   * Encounter context.
   */
  encounterId?: string;

  /**
   * Event-producing service / engine context.
   */
  source: AmexanEventSource;

  /**
   * Operational / clinical severity.
   */
  severity: AmexanEventSeverity;

  /**
   * Domain-specific event data.
   */
  payload: TPayload;

  /**
   * Additional observability metadata.
   *
   * This must not be used as a replacement for canonical envelope fields.
   */
  metadata?: Record<string, unknown>;
}

// =============================================================================
// ADMIN / OBSERVABILITY PROJECTION
// =============================================================================

/**
 * Minimal event descriptor used by the Admin Workspace.
 *
 * This represents a projection of the canonical event envelope rather than
 * another competing event model.
 */
export interface EventEnvelope {
  /**
   * Canonical event identity.
   */
  id: string;

  /**
   * Event occurrence time.
   */
  occurredAt: string;

  /**
   * Canonical event type.
   */
  eventType: string;

  /**
   * Legacy / projection source classification.
   *
   * Example:
   * - clinical
   * - workflow
   * - governance
   * - integration
   * - runtime
   */
  sourceType: string | null;

  /**
   * Optional clinical context.
   */
  patientId?: string | null;
  encounterId?: string | null;

  /**
   * Logical event correlation.
   */
  correlationId?: string | null;
}

// =============================================================================
// EVENT ID HELPERS
// =============================================================================

/**
 * Strictly convert an unknown identifier to its canonical string form.
 *
 * Rules:
 * - finite numbers → decimal string
 * - non-empty strings → unchanged
 * - everything else → ''
 *
 * This helper intentionally does NOT stringify arbitrary objects because
 * event identifiers must never become accidental values such as
 * "[object Object]".
 */
export function eventId(value: unknown): string {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }

  if (typeof value === 'string' && value.trim() !== '') {
    return value;
  }

  return '';
}

/**
 * Extract an event ID from an event-like object.
 *
 * Supports both:
 *
 *   { id: ... }
 *
 * and canonical envelopes:
 *
 *   { eventId: ... }
 *
 * This is important because the Admin Workspace consumes both canonical
 * envelopes and database/API projections.
 */
export function getEventId(
  event:
    | {
        id?: unknown;
        eventId?: unknown;
      }
    | null
    | undefined,
): string {
  if (!event) {
    return '';
  }

  const canonical = eventId(event.eventId);

  if (canonical) {
    return canonical;
  }

  return eventId(event.id);
}

/**
 * Return true when the supplied value is a usable canonical event ID.
 */
export function hasEventId(value: unknown): boolean {
  return eventId(value) !== '';
}

// =============================================================================
// EVENT REFERENCE NORMALISATION
// =============================================================================

/**
 * Resolve an EventSelection, primitive ID, or empty value to its raw ID.
 *
 * EventSelection is intentionally handled structurally so this utility stays
 * compatible with the existing Admin Workspace type without duplicating its
 * definition.
 */
function resolveEventReference(
  value: EventSelection | string | number | null | undefined,
): unknown {
  if (
    value !== null &&
    typeof value === 'object' &&
    'eventId' in value
  ) {
    return value.eventId;
  }

  return value;
}

/**
 * Convert an event reference into its canonical display ID.
 *
 * Numeric legacy IDs are displayed as:
 *
 *   1824 → #1824
 *
 * Opaque IDs are displayed unchanged:
 *
 *   evt_01J... → evt_01J...
 */
export function formatEventId(
  id: EventSelection | string | number | null | undefined,
): string {
  const value = eventId(resolveEventReference(id));

  if (!value) {
    return '';
  }

  return /^\d+$/.test(value)
    ? `#${value}`
    : value;
}

// =============================================================================
// EVENT TYPE HELPERS
// =============================================================================

/**
 * Safely normalise an event type for display.
 */
export function formatEventType(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim();
}

/**
 * Convert an event type into a human-readable label without destroying
 * the canonical event type itself.
 *
 * Example:
 *
 *   clinical.alert.raised
 *   → Clinical Alert Raised
 */
export function formatEventTypeLabel(value: unknown): string {
  const type = formatEventType(value);

  if (!type) {
    return '';
  }

  return type
    .split(/[._:-]+/)
    .filter(Boolean)
    .map(
      (part) =>
        part.charAt(0).toUpperCase() + part.slice(1),
    )
    .join(' ');
}

// =============================================================================
// SEVERITY HELPERS
// =============================================================================

/**
 * Severity ordering used by observability surfaces.
 *
 * Higher number = greater severity.
 */
export const EVENT_SEVERITY_RANK: Record<
  AmexanEventSeverity,
  number
> = {
  debug: 0,
  info: 1,
  notice: 2,
  warning: 3,
  high: 4,
  critical: 5,
};

/**
 * Return the numerical severity rank.
 */
export function getEventSeverityRank(
  severity: unknown,
): number {
  if (
    typeof severity !== 'string' ||
    !(severity.toLowerCase() in EVENT_SEVERITY_RANK)
  ) {
    return EVENT_SEVERITY_RANK.info;
  }

  return EVENT_SEVERITY_RANK[
    severity.toLowerCase() as AmexanEventSeverity
  ];
}

/**
 * Safely normalise a severity value.
 *
 * Unknown values are intentionally mapped to `info` rather than
 * being silently treated as critical.
 */
export function normalizeEventSeverity(
  severity: unknown,
): AmexanEventSeverity {
  if (typeof severity !== 'string') {
    return 'info';
  }

  const normalized = severity.toLowerCase();

  switch (normalized) {
    case 'debug':
    case 'info':
    case 'notice':
    case 'warning':
    case 'high':
    case 'critical':
      return normalized;

    default:
      return 'info';
  }
}

/**
 * Determine whether an event represents a high-risk operational state.
 */
export function isHighSeverityEvent(
  severity: unknown,
): boolean {
  const normalized = normalizeEventSeverity(severity);

  return (
    normalized === 'high' ||
    normalized === 'critical'
  );
}

/**
 * Determine whether an event is critical.
 */
export function isCriticalEvent(
  severity: unknown,
): boolean {
  return normalizeEventSeverity(severity) === 'critical';
}

// =============================================================================
// DATE / TIME HELPERS
// =============================================================================

/**
 * Parse an ISO timestamp safely.
 *
 * Returns null for invalid timestamps.
 */
export function parseEventDate(
  iso: unknown,
): Date | null {
  if (typeof iso !== 'string' || iso.trim() === '') {
    return null;
  }

  const date = new Date(iso);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date;
}

/**
 * Format an event timestamp as HH:MM:SS.
 *
 * Invalid timestamps are returned unchanged rather than producing
 * "Invalid Date".
 */
export function formatEventTime(
  iso: string,
): string {
  const date = parseEventDate(iso);

  if (!date) {
    return iso;
  }

  return date.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

/**
 * Format an event timestamp using the user's local locale.
 */
export function formatDateTime(
  iso: string,
): string {
  const date = parseEventDate(iso);

  if (!date) {
    return iso;
  }

  return date.toLocaleString();
}

/**
 * Format an event timestamp as a compact date.
 */
export function formatEventDate(
  iso: string,
): string {
  const date = parseEventDate(iso);

  if (!date) {
    return iso;
  }

  return date.toLocaleDateString();
}

/**
 * Return a relative time such as:
 *
 *   just now
 *   12s ago
 *   4m ago
 *   2h ago
 *   3d ago
 */
export function formatRelativeEventTime(
  iso: string,
  now = Date.now(),
): string {
  const date = parseEventDate(iso);

  if (!date) {
    return iso;
  }

  const difference = Math.max(
    0,
    now - date.getTime(),
  );

  const seconds = Math.floor(difference / 1000);

  if (seconds < 10) {
    return 'just now';
  }

  if (seconds < 60) {
    return `${seconds}s ago`;
  }

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) {
    return `${minutes}m ago`;
  }

  const hours = Math.floor(minutes / 60);

  if (hours < 24) {
    return `${hours}h ago`;
  }

  const days = Math.floor(hours / 24);

  if (days < 30) {
    return `${days}d ago`;
  }

  return formatEventDate(iso);
}

// =============================================================================
// CORRELATION / LINEAGE HELPERS
// =============================================================================

/**
 * Return the canonical correlation ID.
 */
export function getCorrelationId(
  event:
    | {
        correlationId?: unknown;
      }
    | null
    | undefined,
): string {
  return eventId(event?.correlationId);
}

/**
 * Return the canonical causation ID.
 */
export function getCausationId(
  event:
    | {
        causationId?: unknown;
      }
    | null
    | undefined,
): string {
  return eventId(event?.causationId);
}

/**
 * Determine whether two events belong to the same logical correlation.
 */
export function isSameCorrelation(
  a:
    | {
        correlationId?: unknown;
      }
    | null
    | undefined,
  b:
    | {
        correlationId?: unknown;
      }
    | null
    | undefined,
): boolean {
  const correlationA = getCorrelationId(a);
  const correlationB = getCorrelationId(b);

  return (
    correlationA !== '' &&
    correlationB !== '' &&
    correlationA === correlationB
  );
}

/**
 * Determine whether event B was directly caused by event A.
 */
export function isDirectlyCausedBy(
  event:
    | {
        causationId?: unknown;
      }
    | null
    | undefined,
  cause:
    | {
        id?: unknown;
        eventId?: unknown;
      }
    | null
    | undefined,
): boolean {
  const causationId = getCausationId(event);
  const causeId = getEventId(cause);

  return (
    causationId !== '' &&
    causeId !== '' &&
    causationId === causeId
  );
}

// =============================================================================
// PAYLOAD SAFETY
// =============================================================================

/**
 * Safely convert an event payload value to a short display string.
 *
 * This helper is intended for Admin/Observability summaries only.
 *
 * It deliberately:
 * - never throws because JSON.stringify failed;
 * - never renders undefined;
 * - limits output size;
 * - does not mutate the original payload.
 */
export function formatEventPayloadValue(
  value: unknown,
  maxLength = 120,
): string {
  let text: string;

  if (value === null) {
    text = 'null';
  } else if (value === undefined) {
    return '';
  } else if (typeof value === 'string') {
    text = value;
  } else if (
    typeof value === 'number' ||
    typeof value === 'boolean' ||
    typeof value === 'bigint'
  ) {
    text = String(value);
  } else {
    try {
      const serialized = JSON.stringify(value);

      text =
        serialized === undefined
          ? String(value)
          : serialized;
    } catch {
      text = '[unserializable]';
    }
  }

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}…`;
}

/**
 * Produce a compact payload summary for event lists.
 *
 * This intentionally exposes only the first few fields and is therefore
 * suitable for high-volume observability surfaces.
 */
export function summarizeEventPayload(
  payload: Record<string, unknown> | null | undefined,
  maxEntries = 3,
  maxValueLength = 60,
): string {
  if (!payload || typeof payload !== 'object') {
    return '';
  }

  return Object.entries(payload)
    .filter(
      ([, value]) =>
        value !== null &&
        value !== undefined &&
        value !== '',
    )
    .slice(0, Math.max(0, maxEntries))
    .map(([key, value]) => {
      const formatted =
        formatEventPayloadValue(
          value,
          maxValueLength,
        );

      return formatted
        ? `${key}: ${formatted}`
        : key;
    })
    .join(' · ');
}

// =============================================================================
// ENVELOPE GUARDS
// =============================================================================

/**
 * Runtime guard for an AMEXAN event envelope.
 *
 * This does not attempt to validate the domain payload because that belongs
 * to the individual event schema.
 */
export function isAmexanEventEnvelope(
  value: unknown,
): value is AmexanEventEnvelope {
  if (
    value === null ||
    typeof value !== 'object'
  ) {
    return false;
  }

  const event = value as Record<string, unknown>;

  return (
    typeof event.eventId === 'string' &&
    event.eventId.trim() !== '' &&
    typeof event.eventType === 'string' &&
    event.eventType.trim() !== '' &&
    typeof event.eventVersion === 'number' &&
    Number.isFinite(event.eventVersion) &&
    typeof event.occurredAt === 'string' &&
    event.occurredAt.trim() !== '' &&
    typeof event.correlationId === 'string' &&
    event.correlationId.trim() !== '' &&
    typeof event.source === 'object' &&
    event.source !== null &&
    typeof (event.source as Record<string, unknown>).service ===
      'string' &&
    typeof event.severity === 'string' &&
    typeof event.payload !== 'undefined'
  );
}

// =============================================================================
// EVENT DISPLAY HELPERS
// =============================================================================

/**
 * Produce a compact human-readable description of an event source.
 */
export function formatEventSource(
  source:
    | AmexanEventSource
    | null
    | undefined,
): string {
  if (!source) {
    return '—';
  }

  const service =
    typeof source.service === 'string'
      ? source.service
      : '';

  const engine =
    typeof source.engine === 'string'
      ? source.engine
      : '';

  if (service && engine) {
    return `${service} · ${engine}`;
  }

  return service || engine || '—';
}

/**
 * Produce a compact context label for an event.
 */
export function formatEventContext(
  event: Pick<
    AmexanEventEnvelope,
    | 'organizationId'
    | 'facilityId'
    | 'departmentId'
    | 'patientId'
    | 'encounterId'
  >,
): string {
  const context: string[] = [];

  if (event.organizationId) {
    context.push(`org:${event.organizationId}`);
  }

  if (event.facilityId) {
    context.push(`facility:${event.facilityId}`);
  }

  if (event.departmentId) {
    context.push(`dept:${event.departmentId}`);
  }

  if (event.patientId) {
    context.push(`patient:${event.patientId}`);
  }

  if (event.encounterId) {
    context.push(`encounter:${event.encounterId}`);
  }

  return context.join(' · ');
}

// =============================================================================
// LEGACY / PROJECTION ADAPTER
// =============================================================================

/**
 * Convert an API/database event projection into the minimal Admin envelope.
 *
 * This keeps legacy `/admin/events` projections compatible with the canonical
 * event model without pretending that missing information exists.
 */
export function toEventEnvelope(
  event: {
    id?: unknown;
    eventId?: unknown;
    occurredAt?: unknown;
    eventType?: unknown;
    sourceType?: unknown;
    patientId?: unknown;
    encounterId?: unknown;
    correlationId?: unknown;
  },
): EventEnvelope {
  return {
    id:
      getEventId(event) ||
      '',
    occurredAt:
      typeof event.occurredAt === 'string'
        ? event.occurredAt
        : '',
    eventType:
      typeof event.eventType === 'string'
        ? event.eventType
        : '',
    sourceType:
      typeof event.sourceType === 'string'
        ? event.sourceType
        : null,
    patientId:
      typeof event.patientId === 'string'
        ? event.patientId
        : null,
    encounterId:
      typeof event.encounterId === 'string'
        ? event.encounterId
        : null,
    correlationId:
      typeof event.correlationId === 'string'
        ? event.correlationId
        : null,
  };
}

// =============================================================================
// EVENT ORDERING
// =============================================================================

/**
 * Compare events chronologically.
 *
 * Invalid timestamps are placed after valid timestamps.
 */
export function compareEventTime(
  a: Pick<AmexanEventEnvelope, 'occurredAt'>,
  b: Pick<AmexanEventEnvelope, 'occurredAt'>,
): number {
  const timeA = parseEventDate(a.occurredAt)?.getTime();
  const timeB = parseEventDate(b.occurredAt)?.getTime();

  if (timeA === undefined || timeA === null) {
    return timeB === undefined || timeB === null
      ? 0
      : 1;
  }

  if (timeB === undefined || timeB === null) {
    return -1;
  }

  return timeA - timeB;
}

/**
 * Sort a copy of an event array chronologically.
 *
 * The input array is never mutated.
 */
export function sortEventsChronologically<
  T extends Pick<AmexanEventEnvelope, 'occurredAt'>,
>(
  events: readonly T[],
): T[] {
  return [...events].sort(compareEventTime);
}

/**
 * Sort a copy of an event array newest-first.
 */
export function sortEventsNewestFirst<
  T extends Pick<AmexanEventEnvelope, 'occurredAt'>,
>(
  events: readonly T[],
): T[] {
  return [...events].sort(
    (a, b) => compareEventTime(b, a),
  );
}

// =============================================================================
// END OF AMEXAN EVENT ENVELOPE
// =============================================================================