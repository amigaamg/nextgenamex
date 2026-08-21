// =============================================================================
// AMEXAN Encounter Trace — Full Clinical + Control-Plane Journey
//
// INVESTIGATE
//
// Purpose:
//   • Trace one encounter from creation → closure.
//   • Correlate clinical events, workflow events, audit events and engine work.
//   • Show the actual chronological journey rather than only a flat event list.
//   • Identify failures, warnings, safety events, overrides and manual actions.
//   • Preserve clinician agency: a clinician override is shown as an explicit
//     human decision, never silently treated as a system error.
//   • Provide enough context to investigate:
//       encounter
//       patient
//       clinician
//       facility
//       workflow
//       event
//       engine
//       safety
//       documentation
//       audit
//       correlation
//
// Read-only.
// PostgreSQL is never accessed directly.
// All data comes through the AMEXAN Control Plane API.
// =============================================================================

import {
  Fragment,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import {
  getAuditEvents,
  getJourneyEncounter,
} from '../api';

import type {
  AuditEvent,
  JourneyEvent,
} from '../types';

import {
  formatEventId,
  formatEventTime,
} from '../events';

// =============================================================================
// LOCAL TYPES
// =============================================================================

type TraceSeverity =
  | 'INFO'
  | 'SUCCESS'
  | 'WARNING'
  | 'ERROR'
  | 'CRITICAL'
  | 'OVERRIDE'
  | 'MANUAL';

type TraceCategory =
  | 'ENCOUNTER'
  | 'CLINICAL'
  | 'DOCUMENTATION'
  | 'WORKFLOW'
  | 'ENGINE'
  | 'SAFETY'
  | 'SECURITY'
  | 'INTEGRATION'
  | 'AUDIT'
  | 'SYSTEM'
  | 'UNKNOWN';

interface NormalizedTraceEvent {
  id: string;
  eventType: string;
  occurredAt: string;
  payload?: Record<string, unknown>;
  category: TraceCategory;
  severity: TraceSeverity;
  status: string;
  source: string;
  actor: string;
  engine: string;
  correlationId: string;
  workflowId: string;
  step: string;
  entityType: string;
  entityId: string;
  isFailure: boolean;
  isWarning: boolean;
  isOverride: boolean;
  isManual: boolean;
  isSafety: boolean;
  raw: JourneyEvent;
}

interface NormalizedAuditEvent {
  id: string;
  eventType: string;
  occurredAt: string;
  actor: string;
  actorType: string;
  entityType: string;
  entityCode: string;
  payload?: Record<string, unknown>;
  raw: AuditEvent;
}

interface TraceMetrics {
  total: number;
  successful: number;
  warnings: number;
  failures: number;
  critical: number;
  overrides: number;
  manualActions: number;
  safetyEvents: number;
  engines: number;
  workflowEvents: number;
  documentationEvents: number;
  durationMs: number | null;
}

interface TraceFilterState {
  query: string;
  category: 'ALL' | TraceCategory;
  severity: 'ALL' | TraceSeverity;
  failuresOnly: boolean;
  overridesOnly: boolean;
  safetyOnly: boolean;
}

// =============================================================================
// CONSTANTS
// =============================================================================

const AUDIT_LIMIT = 500;

const INITIAL_FILTERS: TraceFilterState = {
  query: '',
  category: 'ALL',
  severity: 'ALL',
  failuresOnly: false,
  overridesOnly: false,
  safetyOnly: false,
};

const CATEGORY_ORDER: TraceCategory[] = [
  'ENCOUNTER',
  'CLINICAL',
  'DOCUMENTATION',
  'WORKFLOW',
  'ENGINE',
  'SAFETY',
  'SECURITY',
  'INTEGRATION',
  'AUDIT',
  'SYSTEM',
  'UNKNOWN',
];

const SEVERITY_ORDER: TraceSeverity[] = [
  'CRITICAL',
  'ERROR',
  'WARNING',
  'OVERRIDE',
  'MANUAL',
  'SUCCESS',
  'INFO',
];

// =============================================================================
// SAFE HELPERS
// =============================================================================

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function asString(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (
    typeof value === 'number' ||
    typeof value === 'boolean' ||
    typeof value === 'bigint'
  ) {
    return String(value);
  }

  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function getPayloadValue(
  payload: Record<string, unknown> | undefined,
  keys: string[],
): string {
  if (!payload) return '';

  for (const key of keys) {
    if (payload[key] !== undefined && payload[key] !== null) {
      const value = asString(payload[key]).trim();
      if (value) return value;
    }
  }

  return '';
}

function upper(value: unknown): string {
  return asString(value).trim().toUpperCase();
}

function containsAny(value: string, terms: string[]): boolean {
  const normalized = value.toUpperCase();
  return terms.some((term) => normalized.includes(term));
}

function safeDate(value: string | undefined): number {
  if (!value) return 0;

  const timestamp = new Date(value).getTime();

  return Number.isFinite(timestamp) ? timestamp : 0;
}

function formatDuration(milliseconds: number | null): string {
  if (milliseconds === null || !Number.isFinite(milliseconds)) {
    return '—';
  }

  if (milliseconds < 1000) {
    return `${Math.max(0, Math.round(milliseconds))} ms`;
  }

  const seconds = milliseconds / 1000;

  if (seconds < 60) {
    return `${seconds.toFixed(1)} s`;
  }

  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = Math.round(seconds % 60);

  if (minutes < 60) {
    return `${minutes}m ${remainingSeconds}s`;
  }

  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;

  return `${hours}h ${remainingMinutes}m`;
}

function payloadSummary(
  payload: Record<string, unknown> | undefined,
): string {
  if (!payload) return '';

  const entries = Object.entries(payload)
    .filter(
      ([, value]) =>
        value !== null &&
        value !== undefined &&
        value !== '',
    )
    .slice(0, 5)
    .map(([key, value]) => {
      let rendered: string;

      if (typeof value === 'object') {
        try {
          rendered = JSON.stringify(value);
        } catch {
          rendered = '[object]';
        }
      } else {
        rendered = String(value);
      }

      return `${key}: ${
        rendered.length > 100
          ? `${rendered.slice(0, 100)}…`
          : rendered
      }`;
    });

  return entries.join(' · ');
}

function prettyJson(value: unknown): string {
  if (value === undefined) return '—';

  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

// =============================================================================
// EVENT CLASSIFICATION
// =============================================================================

function classifyCategory(
  eventType: string,
  payload: Record<string, unknown> | undefined,
): TraceCategory {
  const type = upper(eventType);
  const context = `${type} ${payloadSummary(payload)}`.toUpperCase();

  if (
    containsAny(context, [
      'SAFETY',
      'DOSE_ALERT',
      'MEDICATION_ALERT',
      'CONTRAINDICATION',
      'ALLERGY_ALERT',
      'INTERACTION_ALERT',
      'HIGH_DOSE',
      'LOW_DOSE',
      'RED_FLAG',
    ])
  ) {
    return 'SAFETY';
  }

  if (
    containsAny(context, [
      'WORKFLOW',
      'TASK',
      'QUEUE',
      'STATE_TRANSITION',
      'WORKFLOW_STARTED',
      'WORKFLOW_COMPLETED',
      'WORKFLOW_FAILED',
    ])
  ) {
    return 'WORKFLOW';
  }

  if (
    containsAny(context, [
      'ENGINE',
      'RULE_ENGINE',
      'DECISION_ENGINE',
      'SAFETY_ENGINE',
      'DOSE_ENGINE',
      'DIAGNOSTIC_ENGINE',
      'KNOWLEDGE_ENGINE',
      'INTELLIGENCE_ENGINE',
    ])
  ) {
    return 'ENGINE';
  }

  if (
    containsAny(context, [
      'DOCUMENT',
      'HPI',
      'EXAMINATION',
      'ASSESSMENT',
      'PLAN',
      'DIAGNOSIS',
      'DIFFERENTIAL',
      'NOTE',
      'SIGN',
      'FINALIZE',
      'AMEND',
    ])
  ) {
    return 'DOCUMENTATION';
  }

  if (
    containsAny(context, [
      'AUTH',
      'LOGIN',
      'SESSION',
      'PERMISSION',
      'ROLE',
      'RBAC',
      'SECURITY',
      'ACCESS',
    ])
  ) {
    return 'SECURITY';
  }

  if (
    containsAny(context, [
      'INTEGRATION',
      'FHIR',
      'HL7',
      'HMIS',
      'API',
      'WEBHOOK',
      'EXTERNAL',
      'SYNC',
      'IMPORT',
      'EXPORT',
    ])
  ) {
    return 'INTEGRATION';
  }

  if (
    containsAny(context, [
      'ENCOUNTER',
      'PATIENT',
      'ADMISSION',
      'DISCHARGE',
      'TRIAGE',
      'REGISTRATION',
      'CHECK_IN',
      'CHECKOUT',
    ])
  ) {
    return 'ENCOUNTER';
  }

  if (
    containsAny(context, [
      'CLINICAL',
      'SYMPTOM',
      'VITAL',
      'HISTORY',
      'EXAM',
      'LAB',
      'IMAGING',
      'MEDICATION',
      'PRESCRIPTION',
      'PROCEDURE',
      'DIAGNOSIS',
      'TREATMENT',
    ])
  ) {
    return 'CLINICAL';
  }

  if (
    containsAny(context, [
      'AUDIT',
      'GOVERNANCE',
      'PROVENANCE',
      'OVERRIDE_RECORDED',
    ])
  ) {
    return 'AUDIT';
  }

  if (
    containsAny(context, [
      'SYSTEM',
      'RUNTIME',
      'CPU',
      'DATABASE',
      'CACHE',
      'SERVER',
      'HEALTH',
      'HEARTBEAT',
    ])
  ) {
    return 'SYSTEM';
  }

  return 'UNKNOWN';
}

function classifySeverity(
  eventType: string,
  payload: Record<string, unknown> | undefined,
): TraceSeverity {
  const type = upper(eventType);
  const context = `${type} ${payloadSummary(payload)}`.toUpperCase();

  if (
    containsAny(context, [
      'CRITICAL',
      'FATAL',
      'SAFETY_CRITICAL',
      'SYSTEM_CRITICAL',
    ])
  ) {
    return 'CRITICAL';
  }

  if (
    containsAny(context, [
      'FAILED',
      'FAILURE',
      'ERROR',
      'EXCEPTION',
      'TIMEOUT',
      'DEAD_LETTER',
      'REJECTED_BY_SYSTEM',
    ])
  ) {
    return 'ERROR';
  }

  if (
    containsAny(context, [
      'WARNING',
      'WARN',
      'ALERT',
      'CAUTION',
      'REVIEW_REQUIRED',
      'SAFETY_ALERT',
    ])
  ) {
    return 'WARNING';
  }

  if (
    containsAny(context, [
      'OVERRIDE',
      'CLINICIAN_OVERRIDE',
      'MANUAL_OVERRIDE',
      'DOCTOR_OVERRIDE',
      'PROVIDER_OVERRIDE',
    ])
  ) {
    return 'OVERRIDE';
  }

  if (
    containsAny(context, [
      'MANUAL',
      'HUMAN_ACTION',
      'USER_ACTION',
      'CLINICIAN_ACTION',
      'DOCTOR_ACTION',
    ])
  ) {
    return 'MANUAL';
  }

  if (
    containsAny(context, [
      'SUCCESS',
      'SUCCEEDED',
      'COMPLETED',
      'CREATED',
      'SAVED',
      'FINALIZED',
      'ACCEPTED',
    ])
  ) {
    return 'SUCCESS';
  }

  return 'INFO';
}

function normalizeJourneyEvent(
  event: JourneyEvent,
): NormalizedTraceEvent {
  const payload = isRecord(event.payload)
    ? event.payload
    : undefined;

  const eventType = event.eventType ?? 'UNKNOWN_EVENT';
  const type = upper(eventType);

  const category = classifyCategory(eventType, payload);
  const severity = classifySeverity(eventType, payload);

  const source =
    getPayloadValue(payload, [
      'sourceType',
      'source',
      'origin',
      'producer',
      'service',
      'component',
    ]) || '—';

  const actor =
    getPayloadValue(payload, [
      'actorCode',
      'actorId',
      'clinicianId',
      'userId',
      'performedBy',
      'createdBy',
      'updatedBy',
    ]) || 'SYSTEM';

  const engine =
    getPayloadValue(payload, [
      'engineCode',
      'engineId',
      'engine',
      'processor',
      'ruleEngine',
    ]) || '—';

  const correlationId =
    getPayloadValue(payload, [
      'correlationId',
      'traceId',
      'requestId',
      'causationId',
    ]) || '—';

  const workflowId =
    getPayloadValue(payload, [
      'workflowInstanceId',
      'workflowId',
      'instanceId',
    ]) || '—';

  const step =
    getPayloadValue(payload, [
      'workflowStep',
      'step',
      'stepCode',
      'stage',
      'state',
    ]) || '—';

  const entityType =
    getPayloadValue(payload, [
      'entityType',
      'resourceType',
      'targetType',
    ]) || '—';

  const entityId =
    getPayloadValue(payload, [
      'entityId',
      'resourceId',
      'targetId',
    ]) || '—';

  const isFailure =
    severity === 'ERROR' ||
    severity === 'CRITICAL' ||
    containsAny(type, [
      'FAILED',
      'FAILURE',
      'ERROR',
      'EXCEPTION',
    ]);

  const isWarning =
    severity === 'WARNING' ||
    category === 'SAFETY';

  const isOverride =
    severity === 'OVERRIDE' ||
    containsAny(type, [
      'OVERRIDE',
      'CLINICIAN_DECISION',
      'CLINICIAN_OVERRIDE',
      'MANUAL_DECISION',
    ]);

  const isManual =
    severity === 'MANUAL' ||
    isOverride ||
    containsAny(type, [
      'MANUAL',
      'USER_ACTION',
      'CLINICIAN_ACTION',
      'DOCTOR_ACTION',
    ]);

  const isSafety =
    category === 'SAFETY' ||
    containsAny(type, [
      'SAFETY',
      'DOSE',
      'CONTRAINDICATION',
      'ALLERGY',
      'INTERACTION',
    ]);

  return {
    id: String(event.eventId),
    eventType,
    occurredAt: event.occurredAt,
    payload,
    category,
    severity,
    status:
      getPayloadValue(payload, [
        'status',
        'result',
        'outcome',
        'decision',
      ]) || '—',
    source,
    actor,
    engine,
    correlationId,
    workflowId,
    step,
    entityType,
    entityId,
    isFailure,
    isWarning,
    isOverride,
    isManual,
    isSafety,
    raw: event,
  };
}

function normalizeAuditEvent(
  event: AuditEvent,
): NormalizedAuditEvent {
  const raw = event as AuditEvent & {
    payload?: Record<string, unknown>;
  };

  return {
    id: String(event.id),
    eventType: event.eventType ?? 'UNKNOWN_AUDIT_EVENT',
    occurredAt: event.occurredAt,
    actor:
      event.actorCode ??
      event.actorType ??
      '—',
    actorType:
      event.actorType ??
      '—',
    entityType:
      event.entityType ??
      '—',
    entityCode:
      event.entityCode ??
      '—',
    payload: isRecord(raw.payload)
      ? raw.payload
      : undefined,
    raw: event,
  };
}

// =============================================================================
// METRICS
// =============================================================================

function calculateMetrics(
  events: NormalizedTraceEvent[],
): TraceMetrics {
  if (events.length === 0) {
    return {
      total: 0,
      successful: 0,
      warnings: 0,
      failures: 0,
      critical: 0,
      overrides: 0,
      manualActions: 0,
      safetyEvents: 0,
      engines: 0,
      workflowEvents: 0,
      documentationEvents: 0,
      durationMs: null,
    };
  }

  const timestamps = events
    .map((event) => safeDate(event.occurredAt))
    .filter((value) => value > 0);

  const uniqueEngines = new Set(
    events
      .map((event) => event.engine)
      .filter((engine) => engine && engine !== '—'),
  );

  const durationMs =
    timestamps.length >= 2
      ? Math.max(...timestamps) - Math.min(...timestamps)
      : null;

  return {
    total: events.length,
    successful: events.filter(
      (event) => event.severity === 'SUCCESS',
    ).length,
    warnings: events.filter(
      (event) => event.isWarning,
    ).length,
    failures: events.filter(
      (event) => event.isFailure,
    ).length,
    critical: events.filter(
      (event) => event.severity === 'CRITICAL',
    ).length,
    overrides: events.filter(
      (event) => event.isOverride,
    ).length,
    manualActions: events.filter(
      (event) => event.isManual,
    ).length,
    safetyEvents: events.filter(
      (event) => event.isSafety,
    ).length,
    engines: uniqueEngines.size,
    workflowEvents: events.filter(
      (event) => event.category === 'WORKFLOW',
    ).length,
    documentationEvents: events.filter(
      (event) => event.category === 'DOCUMENTATION',
    ).length,
    durationMs,
  };
}

// =============================================================================
// SMALL UI COMPONENTS
// =============================================================================

function TraceBadge({
  children,
  tone = 'neutral',
}: {
  children: React.ReactNode;
  tone?:
    | 'neutral'
    | 'good'
    | 'warn'
    | 'bad'
    | 'critical'
    | 'override'
    | 'manual';
}) {
  return (
    <span className={`admin-trace-badge ${tone}`}>
      {children}
    </span>
  );
}

function MetricTile({
  label,
  value,
  tone,
  detail,
}: {
  label: string;
  value: string | number;
  tone?: string;
  detail?: string;
}) {
  return (
    <div className={`admin-tile ${tone ? `tile-${tone}` : ''}`}>
      <span className="admin-tile-label">
        {label}
      </span>

      <span className="admin-tile-value">
        {value}
      </span>

      {detail && (
        <span className="admin-tile-note">
          {detail}
        </span>
      )}
    </div>
  );
}

function getSeverityTone(
  severity: TraceSeverity,
): 'neutral' | 'good' | 'warn' | 'bad' | 'critical' | 'override' | 'manual' {
  switch (severity) {
    case 'SUCCESS':
      return 'good';

    case 'WARNING':
      return 'warn';

    case 'ERROR':
      return 'bad';

    case 'CRITICAL':
      return 'critical';

    case 'OVERRIDE':
      return 'override';

    case 'MANUAL':
      return 'manual';

    default:
      return 'neutral';
  }
}

// =============================================================================
// MAIN COMPONENT
// =============================================================================

export function EncounterTrace() {
  const [encounterId, setEncounterId] = useState('');
  const [submitted, setSubmitted] = useState('');

  const [journey, setJourney] = useState<JourneyEvent[] | null>(null);
  const [audit, setAudit] = useState<AuditEvent[]>([]);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [filters, setFilters] =
    useState<TraceFilterState>(INITIAL_FILTERS);

  const [selectedEventId, setSelectedEventId] =
    useState<string | null>(null);

  const [selectedAuditId, setSelectedAuditId] =
    useState<string | null>(null);

  const [showRawPayload, setShowRawPayload] =
    useState(false);

  const [autoRefresh, setAutoRefresh] =
    useState(false);

  const refreshTimerRef =
    useRef<ReturnType<typeof setInterval> | null>(null);

  // ===========================================================================
  // LOAD TRACE
  // ===========================================================================

  const load = useCallback(async (id: string) => {
    const normalizedId = id.trim();

    if (!normalizedId) {
      setError('Encounter ID is required.');
      return;
    }

    setLoading(true);
    setError(null);
    setJourney(null);
    setAudit([]);
    setSelectedEventId(null);
    setSelectedAuditId(null);

    try {
      const [
        journeyResponse,
        auditResponse,
      ] = await Promise.all([
        getJourneyEncounter(normalizedId),
        getAuditEvents({
          encounterId: normalizedId,
          limit: AUDIT_LIMIT,
        }).catch(() => null),
      ]);

      setJourney(
        Array.isArray(journeyResponse)
          ? journeyResponse
          : [],
      );

      setAudit(
        auditResponse?.events ?? [],
      );
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : 'Failed to load encounter trace',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  // ===========================================================================
  // SUBMISSION
  // ===========================================================================

  const handleSubmit = useCallback(() => {
    const trimmed = encounterId.trim();

    if (!trimmed) {
      setError('Enter an encounter ID.');
      return;
    }

    setSubmitted(trimmed);
    void load(trimmed);
  }, [encounterId, load]);

  // ===========================================================================
  // AUTO REFRESH
  // ===========================================================================

  useEffect(() => {
    if (refreshTimerRef.current) {
      clearInterval(refreshTimerRef.current);
      refreshTimerRef.current = null;
    }

    if (!autoRefresh || !submitted) {
      return;
    }

    refreshTimerRef.current = setInterval(() => {
      void load(submitted);
    }, 15000);

    return () => {
      if (refreshTimerRef.current) {
        clearInterval(refreshTimerRef.current);
        refreshTimerRef.current = null;
      }
    };
  }, [autoRefresh, submitted, load]);

  // ===========================================================================
  // NORMALIZED EVENTS
  // ===========================================================================

  const normalizedEvents = useMemo<NormalizedTraceEvent[]>(
    () =>
      (journey ?? [])
        .map(normalizeJourneyEvent)
        .sort(
          (a, b) =>
            safeDate(a.occurredAt) -
            safeDate(b.occurredAt),
        ),
    [journey],
  );

  const normalizedAudit = useMemo<NormalizedAuditEvent[]>(
    () =>
      audit
        .map(normalizeAuditEvent)
        .sort(
          (a, b) =>
            safeDate(a.occurredAt) -
            safeDate(b.occurredAt),
        ),
    [audit],
  );

  // ===========================================================================
  // METRICS
  // ===========================================================================

  const metrics = useMemo(
    () => calculateMetrics(normalizedEvents),
    [normalizedEvents],
  );

  // ===========================================================================
  // FILTERING
  // ===========================================================================

  const filteredEvents = useMemo(() => {
    const query = filters.query
      .trim()
      .toLowerCase();

    return normalizedEvents.filter((event) => {
      if (
        filters.category !== 'ALL' &&
        event.category !== filters.category
      ) {
        return false;
      }

      if (
        filters.severity !== 'ALL' &&
        event.severity !== filters.severity
      ) {
        return false;
      }

      if (
        filters.failuresOnly &&
        !event.isFailure
      ) {
        return false;
      }

      if (
        filters.overridesOnly &&
        !event.isOverride
      ) {
        return false;
      }

      if (
        filters.safetyOnly &&
        !event.isSafety
      ) {
        return false;
      }

      if (!query) {
        return true;
      }

      const searchable = [
        event.id,
        event.eventType,
        event.category,
        event.severity,
        event.status,
        event.source,
        event.actor,
        event.engine,
        event.correlationId,
        event.workflowId,
        event.step,
        event.entityType,
        event.entityId,
        payloadSummary(event.payload),
      ]
        .join(' ')
        .toLowerCase();

      return searchable.includes(query);
    });
  }, [
    normalizedEvents,
    filters,
  ]);

  // ===========================================================================
  // SELECTED EVENT
  // ===========================================================================

  const selectedEvent = useMemo(
    () =>
      normalizedEvents.find(
        (event) => event.id === selectedEventId,
      ) ?? null,
    [normalizedEvents, selectedEventId],
  );

  const selectedAudit = useMemo(
    () =>
      normalizedAudit.find(
        (event) => event.id === selectedAuditId,
      ) ?? null,
    [normalizedAudit, selectedAuditId],
  );

  // ===========================================================================
  // CORRELATION
  // ===========================================================================

  const correlatedAuditForSelectedEvent = useMemo(() => {
    if (!selectedEvent) return [];

    const correlationId =
      selectedEvent.correlationId;

    if (!correlationId || correlationId === '—') {
      return [];
    }

    return normalizedAudit.filter((event) => {
      const payload = event.payload;

      if (!payload) return false;

      const auditCorrelation =
        getPayloadValue(payload, [
          'correlationId',
          'traceId',
          'requestId',
          'causationId',
        ]);

      return auditCorrelation === correlationId;
    });
  }, [
    selectedEvent,
    normalizedAudit,
  ]);

  // ===========================================================================
  // CATEGORY SUMMARY
  // ===========================================================================

  const categorySummary = useMemo(() => {
    const counts = new Map<
      TraceCategory,
      number
    >();

    for (const event of normalizedEvents) {
      counts.set(
        event.category,
        (counts.get(event.category) ?? 0) + 1,
      );
    }

    return CATEGORY_ORDER
      .map((category) => ({
        category,
        count: counts.get(category) ?? 0,
      }))
      .filter((entry) => entry.count > 0);
  }, [normalizedEvents]);

  // ===========================================================================
  // FAILURE / SAFETY SUMMARY
  // ===========================================================================

  const failureEvents = useMemo(
    () =>
      normalizedEvents.filter(
        (event) => event.isFailure,
      ),
    [normalizedEvents],
  );

  const safetyEvents = useMemo(
    () =>
      normalizedEvents.filter(
        (event) => event.isSafety,
      ),
    [normalizedEvents],
  );

  const overrideEvents = useMemo(
    () =>
      normalizedEvents.filter(
        (event) => event.isOverride,
      ),
    [normalizedEvents],
  );

  // ===========================================================================
  // CLEAR TRACE
  // ===========================================================================

  const clearTrace = useCallback(() => {
    setEncounterId('');
    setSubmitted('');
    setJourney(null);
    setAudit([]);
    setError(null);
    setSelectedEventId(null);
    setSelectedAuditId(null);
    setFilters(INITIAL_FILTERS);
    setAutoRefresh(false);
  }, []);

  // ===========================================================================
  // LOADING
  // ===========================================================================

  if (
    loading &&
    !journey &&
    !submitted
  ) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Loading encounter trace…
      </div>
    );
  }

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div className="amexan-encounter-trace">

      {/* =====================================================================
          TRACE HEADER
          ===================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">

          <div>
            <span className="admin-panel-title">
              Encounter Trace
            </span>

            <span className="admin-panel-sub">
              Complete encounter journey across clinical,
              workflow, engine, safety, documentation and audit layers
            </span>
          </div>

          <div
            style={{
              display: 'flex',
              gap: 8,
              alignItems: 'center',
              flexWrap: 'wrap',
            }}
          >
            {submitted && (
              <TraceBadge tone="neutral">
                ENC-{submitted.slice(0, 8).toUpperCase()}
              </TraceBadge>
            )}

            {autoRefresh && (
              <TraceBadge tone="good">
                LIVE
              </TraceBadge>
            )}
          </div>
        </div>

        {/* ================================================================
            SEARCH
            ================================================================ */}

        <div className="admin-filters">

          <input
            className="admin-filter-input"
            type="text"
            placeholder="Encounter ID / UUID"
            value={encounterId}
            onChange={(event) =>
              setEncounterId(event.target.value)
            }
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                handleSubmit();
              }
            }}
            aria-label="Encounter ID"
          />

          <button
            type="button"
            className="admin-page-btn"
            onClick={handleSubmit}
            disabled={loading}
          >
            {loading ? 'Tracing…' : 'Trace Encounter'}
          </button>

          {submitted && (
            <button
              type="button"
              className="admin-page-btn"
              onClick={() => void load(submitted)}
              disabled={loading}
            >
              Refresh
            </button>
          )}

          {submitted && (
            <button
              type="button"
              className="admin-page-btn"
              onClick={clearTrace}
            >
              Clear
            </button>
          )}

          {submitted && (
            <label
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 7,
                fontSize: '0.82rem',
              }}
            >
              <input
                type="checkbox"
                checked={autoRefresh}
                onChange={(event) =>
                  setAutoRefresh(
                    event.target.checked,
                  )
                }
              />
              Auto-refresh
            </label>
          )}
        </div>

        {error && (
          <div
            className="admin-error"
            role="alert"
            style={{ marginTop: 12 }}
          >
            {error}
          </div>
        )}
      </div>

      {/* =====================================================================
          LOADING STATE
          ===================================================================== */}

      {loading && submitted && (
        <div
          className="admin-loading"
          style={{ marginTop: 16 }}
        >
          <span
            className="admin-spinner"
            aria-hidden="true"
          />
          Refreshing encounter journey…
        </div>
      )}

      {/* =====================================================================
          NO DATA
          ===================================================================== */}

      {!loading &&
        submitted &&
        journey &&
        normalizedEvents.length === 0 && (
          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <div className="admin-empty">
              No journey events were recorded for this
              encounter.
            </div>
          </div>
        )}

      {/* =====================================================================
          TRACE CONTENT
          ===================================================================== */}

      {submitted &&
        journey &&
        normalizedEvents.length > 0 && (
          <>

            {/* ===============================================================
                TOP METRICS
                =============================================================== */}

            <div
              className="admin-tile-grid"
              style={{ marginTop: 16 }}
            >
              <MetricTile
                label="Total events"
                value={metrics.total}
                detail="complete event stream"
              />

              <MetricTile
                label="Successful"
                value={metrics.successful}
                tone="good"
                detail="completed operations"
              />

              <MetricTile
                label="Warnings"
                value={metrics.warnings}
                tone="warn"
                detail="review / safety signals"
              />

              <MetricTile
                label="Failures"
                value={metrics.failures}
                tone="danger"
                detail="failed operations"
              />

              <MetricTile
                label="Safety events"
                value={metrics.safetyEvents}
                tone="danger"
                detail="clinical safety layer"
              />

              <MetricTile
                label="Clinician overrides"
                value={metrics.overrides}
                detail="explicit human decisions"
              />

              <MetricTile
                label="Engines involved"
                value={metrics.engines}
                detail="observed processors"
              />

              <MetricTile
                label="Journey duration"
                value={formatDuration(metrics.durationMs)}
                detail="first → last event"
              />
            </div>

            {/* ===============================================================
                SAFETY / FAILURE / OVERRIDE STRIP
                =============================================================== */}

            {(failureEvents.length > 0 ||
              safetyEvents.length > 0 ||
              overrideEvents.length > 0) && (
              <div
                className="admin-grid-3"
                style={{ marginTop: 16 }}
              >

                <div className="admin-panel">
                  <div className="admin-panel-head">
                    <span className="admin-panel-title">
                      Failures
                    </span>

                    <TraceBadge tone="bad">
                      {failureEvents.length}
                    </TraceBadge>
                  </div>

                  {failureEvents.length === 0 ? (
                    <div className="admin-empty">
                      No failures detected.
                    </div>
                  ) : (
                    <div className="admin-activity">
                      {failureEvents
                        .slice(-8)
                        .reverse()
                        .map((event) => (
                          <button
                            key={event.id}
                            type="button"
                            className="admin-activity-item admin-row-click"
                            onClick={() =>
                              setSelectedEventId(
                                event.id,
                              )
                            }
                          >
                            <span className="admin-activity-time">
                              {formatEventTime(
                                event.occurredAt,
                              )}
                            </span>

                            <span className="admin-activity-type">
                              {event.eventType}
                            </span>

                            <span className="admin-activity-meta">
                              {event.engine !== '—'
                                ? event.engine
                                : event.source}
                            </span>
                          </button>
                        ))}
                    </div>
                  )}
                </div>

                <div className="admin-panel">
                  <div className="admin-panel-head">
                    <span className="admin-panel-title">
                      Safety
                    </span>

                    <TraceBadge tone="warn">
                      {safetyEvents.length}
                    </TraceBadge>
                  </div>

                  {safetyEvents.length === 0 ? (
                    <div className="admin-empty">
                      No safety events detected.
                    </div>
                  ) : (
                    <div className="admin-activity">
                      {safetyEvents
                        .slice(-8)
                        .reverse()
                        .map((event) => (
                          <button
                            key={event.id}
                            type="button"
                            className="admin-activity-item admin-row-click"
                            onClick={() =>
                              setSelectedEventId(
                                event.id,
                              )
                            }
                          >
                            <span className="admin-activity-time">
                              {formatEventTime(
                                event.occurredAt,
                              )}
                            </span>

                            <span className="admin-activity-type">
                              {event.eventType}
                            </span>

                            <span className="admin-activity-meta">
                              {event.status}
                            </span>
                          </button>
                        ))}
                    </div>
                  )}
                </div>

                <div className="admin-panel">
                  <div className="admin-panel-head">
                    <span className="admin-panel-title">
                      Human Decisions
                    </span>

                    <TraceBadge tone="override">
                      {overrideEvents.length}
                    </TraceBadge>
                  </div>

                  {overrideEvents.length === 0 ? (
                    <div className="admin-empty">
                      No clinician overrides detected.
                    </div>
                  ) : (
                    <div className="admin-activity">
                      {overrideEvents
                        .slice(-8)
                        .reverse()
                        .map((event) => (
                          <button
                            key={event.id}
                            type="button"
                            className="admin-activity-item admin-row-click"
                            onClick={() =>
                              setSelectedEventId(
                                event.id,
                              )
                            }
                          >
                            <span className="admin-activity-time">
                              {formatEventTime(
                                event.occurredAt,
                              )}
                            </span>

                            <span className="admin-activity-type">
                              {event.eventType}
                            </span>

                            <span className="admin-activity-meta">
                              {event.actor}
                            </span>
                          </button>
                        ))}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* ===============================================================
                FILTERS
                =============================================================== */}

            <div
              className="admin-panel"
              style={{ marginTop: 16 }}
            >
              <div className="admin-panel-head">
                <span className="admin-panel-title">
                  Journey Filters
                </span>

                <span className="admin-panel-sub">
                  Showing {filteredEvents.length} of{' '}
                  {normalizedEvents.length} events
                </span>
              </div>

              <div
                className="admin-filters"
                style={{
                  alignItems: 'center',
                }}
              >

                <input
                  className="admin-filter-input"
                  type="search"
                  placeholder="Search events, engines, actors, IDs…"
                  value={filters.query}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      query: event.target.value,
                    }))
                  }
                />

                <select
                  className="admin-input"
                  value={filters.category}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      category:
                        event.target.value as
                          | 'ALL'
                          | TraceCategory,
                    }))
                  }
                >
                  <option value="ALL">
                    All categories
                  </option>

                  {CATEGORY_ORDER.map(
                    (category) => (
                      <option
                        key={category}
                        value={category}
                      >
                        {category}
                      </option>
                    ),
                  )}
                </select>

                <select
                  className="admin-input"
                  value={filters.severity}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      severity:
                        event.target.value as
                          | 'ALL'
                          | TraceSeverity,
                    }))
                  }
                >
                  <option value="ALL">
                    All severities
                  </option>

                  {SEVERITY_ORDER.map(
                    (severity) => (
                      <option
                        key={severity}
                        value={severity}
                      >
                        {severity}
                      </option>
                    ),
                  )}
                </select>

                <label
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 6,
                    fontSize: '0.82rem',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={filters.failuresOnly}
                    onChange={(event) =>
                      setFilters((current) => ({
                        ...current,
                        failuresOnly:
                          event.target.checked,
                      }))
                    }
                  />
                  Failures
                </label>

                <label
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 6,
                    fontSize: '0.82rem',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={filters.safetyOnly}
                    onChange={(event) =>
                      setFilters((current) => ({
                        ...current,
                        safetyOnly:
                          event.target.checked,
                      }))
                    }
                  />
                  Safety
                </label>

                <label
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 6,
                    fontSize: '0.82rem',
                  }}
                >
                  <input
                    type="checkbox"
                    checked={filters.overridesOnly}
                    onChange={(event) =>
                      setFilters((current) => ({
                        ...current,
                        overridesOnly:
                          event.target.checked,
                      }))
                    }
                  />
                  Overrides
                </label>

                <button
                  type="button"
                  className="admin-page-btn"
                  onClick={() =>
                    setFilters(
                      INITIAL_FILTERS,
                    )
                  }
                >
                  Reset
                </button>
              </div>
            </div>

            {/* ===============================================================
                JOURNEY + EVENT DETAIL
                =============================================================== */}

            <div
              className="admin-grid-2"
              style={{ marginTop: 16 }}
            >

              {/* =============================================================
                  JOURNEY TIMELINE
                  ============================================================= */}

              <div className="admin-panel">

                <div className="admin-panel-head">
                  <div>
                    <span className="admin-panel-title">
                      Clinical Journey
                    </span>

                    <span className="admin-panel-sub">
                      Chronological event stream
                    </span>
                  </div>

                  <span className="admin-panel-sub">
                    {filteredEvents.length} events
                  </span>
                </div>

                {filteredEvents.length === 0 && (
                  <div className="admin-empty">
                    No events match the current filters.
                  </div>
                )}

                <div className="admin-trace-rail">
                  {filteredEvents.map(
                    (event, index) => {
                      const tone =
                        getSeverityTone(
                          event.severity,
                        );

                      const selected =
                        event.id ===
                        selectedEventId;

                      return (
                        <button
                          key={`${event.id}-${index}`}
                          type="button"
                          className={`admin-trace-item ${
                            selected
                              ? 'selected'
                              : ''
                          } ${
                            event.isFailure
                              ? 'fail'
                              : ''
                          } ${
                            event.isSafety
                              ? 'safety'
                              : ''
                          }`}
                          onClick={() =>
                            setSelectedEventId(
                              event.id,
                            )
                          }
                          style={{
                            width: '100%',
                            textAlign: 'left',
                            cursor: 'pointer',
                          }}
                        >

                          <span className="trace-time">
                            {formatEventTime(
                              event.occurredAt,
                            )}

                            {' · '}

                            {formatEventId(
                              event.id,
                            )}
                          </span>

                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: 7,
                              flexWrap: 'wrap',
                            }}
                          >
                            <div className="trace-type">
                              {event.eventType}
                            </div>

                            <TraceBadge tone={tone}>
                              {event.severity}
                            </TraceBadge>

                            <TraceBadge>
                              {event.category}
                            </TraceBadge>
                          </div>

                          <div
                            style={{
                              display: 'flex',
                              gap: 12,
                              flexWrap: 'wrap',
                              marginTop: 5,
                              fontSize: '0.75rem',
                              opacity: 0.8,
                            }}
                          >
                            <span>
                              Source:{' '}
                              <strong>
                                {event.source}
                              </strong>
                            </span>

                            <span>
                              Actor:{' '}
                              <strong>
                                {event.actor}
                              </strong>
                            </span>

                            {event.engine !== '—' && (
                              <span>
                                Engine:{' '}
                                <strong>
                                  {event.engine}
                                </strong>
                              </span>
                            )}

                            {event.step !== '—' && (
                              <span>
                                Step:{' '}
                                <strong>
                                  {event.step}
                                </strong>
                              </span>
                            )}
                          </div>

                          {payloadSummary(
                            event.payload,
                          ) && (
                            <div className="trace-payload">
                              {payloadSummary(
                                event.payload,
                              )}
                            </div>
                          )}
                        </button>
                      );
                    },
                  )}
                </div>
              </div>

              {/* =============================================================
                  EVENT INSPECTOR
                  ============================================================= */}

              <div className="admin-panel">

                <div className="admin-panel-head">
                  <div>
                    <span className="admin-panel-title">
                      Event Inspector
                    </span>

                    <span className="admin-panel-sub">
                      Provenance, actor, engine and payload
                    </span>
                  </div>
                </div>

                {!selectedEvent && (
                  <div className="admin-empty">
                    Select an event from the journey to
                    inspect its complete provenance.
                  </div>
                )}

                {selectedEvent && (
                  <div>

                    <div
                      className="admin-kv"
                      style={{
                        marginBottom: 16,
                      }}
                    >

                      <span className="k">
                        Event ID
                      </span>

                      <span className="v mono">
                        {selectedEvent.id}
                      </span>

                      <span className="k">
                        Event type
                      </span>

                      <span className="v mono">
                        {selectedEvent.eventType}
                      </span>

                      <span className="k">
                        Occurred
                      </span>

                      <span className="v mono">
                        {new Date(
                          selectedEvent.occurredAt,
                        ).toLocaleString()}
                      </span>

                      <span className="k">
                        Category
                      </span>

                      <span className="v">
                        <TraceBadge>
                          {selectedEvent.category}
                        </TraceBadge>
                      </span>

                      <span className="k">
                        Severity
                      </span>

                      <span className="v">
                        <TraceBadge
                          tone={getSeverityTone(
                            selectedEvent.severity,
                          )}
                        >
                          {selectedEvent.severity}
                        </TraceBadge>
                      </span>

                      <span className="k">
                        Status
                      </span>

                      <span className="v mono">
                        {selectedEvent.status}
                      </span>

                      <span className="k">
                        Source
                      </span>

                      <span className="v mono">
                        {selectedEvent.source}
                      </span>

                      <span className="k">
                        Actor
                      </span>

                      <span className="v mono">
                        {selectedEvent.actor}
                      </span>

                      <span className="k">
                        Engine
                      </span>

                      <span className="v mono">
                        {selectedEvent.engine}
                      </span>

                      <span className="k">
                        Correlation
                      </span>

                      <span className="v mono">
                        {selectedEvent.correlationId}
                      </span>

                      <span className="k">
                        Workflow
                      </span>

                      <span className="v mono">
                        {selectedEvent.workflowId}
                      </span>

                      <span className="k">
                        Step
                      </span>

                      <span className="v mono">
                        {selectedEvent.step}
                      </span>

                      <span className="k">
                        Entity
                      </span>

                      <span className="v mono">
                        {selectedEvent.entityType}
                        {' / '}
                        {selectedEvent.entityId}
                      </span>
                    </div>

                    {/* =======================================================
                        HUMAN DECISION
                        ======================================================= */}

                    {selectedEvent.isOverride && (
                      <div
                        className="admin-panel"
                        style={{
                          marginBottom: 16,
                        }}
                      >
                        <div className="admin-panel-head">
                          <span className="admin-panel-title">
                            Clinician Decision / Override
                          </span>

                          <TraceBadge tone="override">
                            HUMAN DECISION
                          </TraceBadge>
                        </div>

                        <div className="admin-kv">
                          <span className="k">
                            Actor
                          </span>

                          <span className="v mono">
                            {selectedEvent.actor}
                          </span>

                          <span className="k">
                            Decision
                          </span>

                          <span className="v">
                            {selectedEvent.status}
                          </span>

                          <span className="k">
                            Event
                          </span>

                          <span className="v mono">
                            {selectedEvent.eventType}
                          </span>

                          <span className="k">
                            Recorded
                          </span>

                          <span className="v mono">
                            {formatEventTime(
                              selectedEvent.occurredAt,
                            )}
                          </span>
                        </div>
                      </div>
                    )}

                    {/* =======================================================
                        PAYLOAD
                        ======================================================= */}

                    <div className="admin-panel">
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Event Payload
                        </span>

                        <button
                          type="button"
                          className="admin-page-btn"
                          onClick={() =>
                            setShowRawPayload(
                              (value) => !value,
                            )
                          }
                        >
                          {showRawPayload
                            ? 'Summary'
                            : 'Raw payload'}
                        </button>
                      </div>

                      {showRawPayload ? (
                        <pre
                          style={{
                            margin: 0,
                            padding: 12,
                            overflow: 'auto',
                            fontSize: '0.72rem',
                            lineHeight: 1.5,
                            whiteSpace: 'pre-wrap',
                            wordBreak: 'break-word',
                          }}
                        >
                          {prettyJson(
                            selectedEvent.payload,
                          )}
                        </pre>
                      ) : (
                        <div
                          className="admin-kv"
                        >
                          {Object.entries(
                            selectedEvent.payload ??
                              {},
                          ).map(
                            ([key, value]) => (
                              <Fragment
                                key={key}
                              >
                                <span className="k">
                                  {key}
                                </span>

                                <span className="v mono">
                                  {typeof value ===
                                    'object'
                                    ? prettyJson(
                                        value,
                                      )
                                    : String(
                                        value,
                                      )}
                                </span>
                              </Fragment>
                            ),
                          )}

                          {Object.keys(
                            selectedEvent.payload ??
                              {},
                          ).length === 0 && (
                            <span className="muted">
                              No payload supplied.
                            </span>
                          )}
                        </div>
                      )}
                    </div>

                    {/* =======================================================
                        CORRELATED AUDIT
                        ======================================================= */}

                    {correlatedAuditForSelectedEvent.length >
                      0 && (
                      <div
                        className="admin-panel"
                        style={{
                          marginTop: 16,
                        }}
                      >
                        <div className="admin-panel-head">
                          <span className="admin-panel-title">
                            Correlated Audit
                          </span>

                          <span className="admin-panel-sub">
                            {
                              correlatedAuditForSelectedEvent.length
                            }{' '}
                            governance records
                          </span>
                        </div>

                        <div className="admin-table-wrap">
                          <table className="admin-table">
                            <thead>
                              <tr>
                                <th>
                                  Time
                                </th>
                                <th>
                                  Event
                                </th>
                                <th>
                                  Actor
                                </th>
                                <th>
                                  Entity
                                </th>
                              </tr>
                            </thead>

                            <tbody>
                              {correlatedAuditForSelectedEvent.map(
                                (auditEvent) => (
                                  <tr
                                    key={
                                      auditEvent.id
                                    }
                                  >
                                    <td className="mono">
                                      {formatEventTime(
                                        auditEvent.occurredAt,
                                      )}
                                    </td>

                                    <td className="mono">
                                      {
                                        auditEvent.eventType
                                      }
                                    </td>

                                    <td>
                                      {
                                        auditEvent.actor
                                      }
                                    </td>

                                    <td className="mono">
                                      {
                                        auditEvent.entityType
                                      }

                                      {' / '}

                                      {
                                        auditEvent.entityCode
                                      }
                                    </td>
                                  </tr>
                                ),
                              )}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>

            {/* ===============================================================
                JOURNEY CATEGORIES
                =============================================================== */}

            <div
              className="admin-panel"
              style={{ marginTop: 16 }}
            >
              <div className="admin-panel-head">
                <span className="admin-panel-title">
                  Journey Composition
                </span>

                <span className="admin-panel-sub">
                  distribution of observed activity
                </span>
              </div>

              <div className="admin-bar-list">
                {categorySummary.map(
                  (entry) => {
                    const maximum =
                      Math.max(
                        1,
                        ...categorySummary.map(
                          (item) =>
                            item.count,
                        ),
                      );

                    return (
                      <div
                        className="admin-bar-row"
                        key={entry.category}
                      >
                        <span className="admin-bar-label mono">
                          {entry.category}
                        </span>

                        <div className="admin-bar-track">
                          <div
                            className="admin-bar-fill"
                            style={{
                              width: `${
                                (entry.count /
                                  maximum) *
                                100
                              }%`,
                            }}
                          />
                        </div>

                        <span className="admin-bar-value num">
                          {entry.count}
                        </span>
                      </div>
                    );
                  },
                )}
              </div>
            </div>

            {/* ===============================================================
                AUDIT TRAIL
                =============================================================== */}

            <div
              className="admin-panel"
              style={{ marginTop: 16 }}
            >
              <div className="admin-panel-head">
                <div>
                  <span className="admin-panel-title">
                    Governance Audit Trail
                  </span>

                  <span className="admin-panel-sub">
                    {normalizedAudit.length} correlated audit
                    records
                  </span>
                </div>

                {selectedAuditId && (
                  <button
                    type="button"
                    className="admin-page-btn"
                    onClick={() =>
                      setSelectedAuditId(null)
                    }
                  >
                    Close selection
                  </button>
                )}
              </div>

              {normalizedAudit.length === 0 && (
                <div className="admin-empty">
                  No correlated audit events found for this
                  encounter.
                </div>
              )}

              {normalizedAudit.length > 0 && (
                <div className="admin-table-wrap">
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>
                          Time
                        </th>

                        <th>
                          Event
                        </th>

                        <th>
                          Actor
                        </th>

                        <th>
                          Actor Type
                        </th>

                        <th>
                          Entity
                        </th>

                        <th>
                          ID
                        </th>
                      </tr>
                    </thead>

                    <tbody>
                      {normalizedAudit.map(
                        (event) => {
                          const selected =
                            event.id ===
                            selectedAuditId;

                          return (
                            <tr
                              key={event.id}
                              onClick={() =>
                                setSelectedAuditId(
                                  event.id,
                                )
                              }
                              style={{
                                cursor:
                                  'pointer',
                                background:
                                  selected
                                    ? 'var(--admin-selected-row, rgba(0,0,0,0.035))'
                                    : undefined,
                              }}
                            >
                              <td className="mono">
                                {formatEventTime(
                                  event.occurredAt,
                                )}
                              </td>

                              <td className="mono">
                                {
                                  event.eventType
                                }
                              </td>

                              <td>
                                {
                                  event.actor
                                }
                              </td>

                              <td>
                                {
                                  event.actorType
                                }
                              </td>

                              <td className="mono">
                                {
                                  event.entityType
                                }

                                {event.entityCode !==
                                  '—' &&
                                  ` / ${event.entityCode}`}
                              </td>

                              <td className="mono">
                                {
                                  event.id
                                }
                              </td>
                            </tr>
                          );
                        },
                      )}
                    </tbody>
                  </table>
                </div>
              )}

              {selectedAudit && (
                <div
                  className="admin-panel"
                  style={{
                    marginTop: 16,
                  }}
                >
                  <div className="admin-panel-head">
                    <span className="admin-panel-title">
                      Audit Record
                    </span>

                    <TraceBadge>
                      {
                        selectedAudit.eventType
                      }
                    </TraceBadge>
                  </div>

                  <div className="admin-kv">
                    <span className="k">
                      ID
                    </span>

                    <span className="v mono">
                      {selectedAudit.id}
                    </span>

                    <span className="k">
                      Time
                    </span>

                    <span className="v mono">
                      {new Date(
                        selectedAudit.occurredAt,
                      ).toLocaleString()}
                    </span>

                    <span className="k">
                      Actor
                    </span>

                    <span className="v mono">
                      {selectedAudit.actor}
                    </span>

                    <span className="k">
                      Actor type
                    </span>

                    <span className="v mono">
                      {selectedAudit.actorType}
                    </span>

                    <span className="k">
                      Entity
                    </span>

                    <span className="v mono">
                      {selectedAudit.entityType}
                      {' / '}
                      {selectedAudit.entityCode}
                    </span>
                  </div>

                  {selectedAudit.payload && (
                    <pre
                      style={{
                        marginTop: 16,
                        marginBottom: 0,
                        padding: 12,
                        overflow: 'auto',
                        fontSize: '0.72rem',
                        lineHeight: 1.5,
                        whiteSpace: 'pre-wrap',
                        wordBreak: 'break-word',
                      }}
                    >
                      {prettyJson(
                        selectedAudit.payload,
                      )}
                    </pre>
                  )}
                </div>
              )}
            </div>

            {/* ===============================================================
                TRACE FOOTER
                =============================================================== */}

            <div
              className="admin-panel"
              style={{
                marginTop: 16,
                marginBottom: 20,
              }}
            >
              <div
                className="admin-activity-meta"
                style={{
                  display: 'flex',
                  gap: 24,
                  flexWrap: 'wrap',
                }}
              >
                <span>
                  <strong>
                    {normalizedEvents.length}
                  </strong>{' '}
                  journey events
                </span>

                <span>
                  <strong>
                    {normalizedAudit.length}
                  </strong>{' '}
                  audit records
                </span>

                <span>
                  <strong>
                    {metrics.workflowEvents}
                  </strong>{' '}
                  workflow events
                </span>

                <span>
                  <strong>
                    {metrics.documentationEvents}
                  </strong>{' '}
                  documentation events
                </span>

                <span>
                  <strong>
                    {metrics.engines}
                  </strong>{' '}
                  engines observed
                </span>

                <span>
                  <strong>
                    {metrics.manualActions}
                  </strong>{' '}
                  human actions
                </span>

                <span className="muted small">
                  Read-only Control Plane projection
                </span>
              </div>
            </div>
          </>
        )}
    </div>
  );
}