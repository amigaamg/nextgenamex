// =============================================================================
// AMEXAN Event Observatory — REAL-TIME PLATFORM EVENT CONTROL
//
// OPERATE / INVESTIGATE
//
// Purpose:
//   - Continuously observe cpu.event_log.
//   - Detect newly arriving events without requiring manual refresh.
//   - Keep an in-memory live event stream while preserving server pagination.
//   - Show processing failures, retries, warnings, dead-letter candidates,
//     engine events, clinical events, workflow events, safety events,
//     integration events and human/AI provenance.
//   - Correlate event -> patient -> encounter -> source -> CPU -> knowledge.
//   - Inspect complete event payloads and lineage.
//   - Track event throughput, failures, pending processing and live latency.
//   - Highlight event bursts and newly arrived events.
//   - Continue operating when the browser tab is backgrounded.
//   - Pause expensive polling when the document is hidden and resume safely.
//   - Prevent duplicate events.
//   - Never write to PostgreSQL.
//   - Never mutate clinical data.
//   - Never execute clinical actions.
//   - This component is an observation surface only.
//
// Backend contract used:
//   getEvents(filters)
//   getEvent(selection)
//
// Existing AMEXAN API/types are preserved.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import {
  getEvent,
  getEvents,
} from '../api';

import type {
  EventDetail,
  EventLogEntry,
  EventsResponse,
  EventSelection,
} from '../types';

import {
  formatEventId,
  formatEventTime,
} from '../events';

// =============================================================================
// CONSTANTS
// =============================================================================

const PAGE_SIZE = 50;

const LIVE_POLL_ACTIVE_MS = 3000;
const LIVE_POLL_BACKGROUND_MS = 15000;

const MAX_LIVE_EVENTS = 250;
const MAX_SEEN_EVENT_IDS = 5000;

const FAILURE_WORDS = [
  'FAILED',
  'ERROR',
  'EXCEPTION',
  'DEAD',
  'REJECTED',
];

const WARNING_WORDS = [
  'WARNING',
  'WARN',
  'DEGRADED',
  'RETRY',
  'TIMEOUT',
];

const SAFETY_WORDS = [
  'SAFETY',
  'DOSE',
  'MEDICATION',
  'DRUG',
  'ALLERGY',
  'CONTRAINDICATION',
  'INTERACTION',
  'OVERRIDE',
  'HIGH_RISK',
];

const CLINICAL_WORDS = [
  'ENCOUNTER',
  'PATIENT',
  'CLINICAL',
  'DOCUMENT',
  'HPI',
  'EXAM',
  'DIAGNOSIS',
  'MANAGEMENT',
  'PRESCRIPTION',
  'ORDER',
  'OBSERVATION',
];

const ENGINE_WORDS = [
  'ENGINE',
  'CPU',
  'RULE',
  'KNOWLEDGE',
  'INFERENCE',
  'EVALUATION',
  'RESOLVER',
  'AGENT',
];

const WORKFLOW_WORDS = [
  'WORKFLOW',
  'TASK',
  'QUEUE',
  'STATE',
  'TRANSITION',
];

const INTEGRATION_WORDS = [
  'INTEGRATION',
  'FHIR',
  'HMIS',
  'API',
  'WEBHOOK',
  'MESSAGE',
  'SYNC',
];

const HUMAN_WORDS = [
  'CLINICIAN',
  'DOCTOR',
  'USER',
  'ACTOR',
  'MANUAL',
  'OVERRIDE',
  'ACCEPTED',
  'MODIFIED',
  'REJECTED',
];

const AI_WORDS = [
  'AI',
  'AGENT',
  'MODEL',
  'SUGGESTION',
  'RECOMMENDATION',
  'INFERENCE',
];

type EventHealth =
  | 'good'
  | 'warn'
  | 'bad'
  | 'idle';

type EventDomain =
  | 'clinical'
  | 'safety'
  | 'engine'
  | 'workflow'
  | 'integration'
  | 'human'
  | 'ai'
  | 'system'
  | 'unknown';

type LiveFilter =
  | 'ALL'
  | 'NEW'
  | 'FAILED'
  | 'WARNINGS'
  | 'SAFETY'
  | 'CLINICAL'
  | 'ENGINES'
  | 'WORKFLOW'
  | 'INTEGRATIONS'
  | 'HUMAN'
  | 'AI';

type ConnectionState =
  | 'connecting'
  | 'live'
  | 'stale'
  | 'error';

interface EventExplorerProps {
  initialSelection?: EventSelection | null;
}

// =============================================================================
// HELPERS
// =============================================================================

function normalize(value: unknown): string {
  return String(value ?? '').trim().toUpperCase();
}

function eventHealth(event: EventLogEntry): EventHealth {
  const type = normalize(event.eventType);
  const status = normalize(event.processingStatus);

  if (
    status === 'FAILED' ||
    FAILURE_WORDS.some((word) => type.includes(word))
  ) {
    return 'bad';
  }

  if (
    status === 'PENDING' ||
    status === 'PROCESSING' ||
    status === 'RETRYING' ||
    WARNING_WORDS.some((word) => type.includes(word))
  ) {
    return 'warn';
  }

  if (status === 'PROCESSED' || status === 'COMPLETED') {
    return 'good';
  }

  return 'idle';
}

function eventDomain(event: EventLogEntry): EventDomain {
  const type = normalize(event.eventType);
  const source = normalize(event.sourceType);

  if (
    SAFETY_WORDS.some((word) => type.includes(word)) ||
    SAFETY_WORDS.some((word) => source.includes(word))
  ) {
    return 'safety';
  }

  if (
    ENGINE_WORDS.some((word) => type.includes(word)) ||
    ENGINE_WORDS.some((word) => source.includes(word))
  ) {
    return 'engine';
  }

  if (
    CLINICAL_WORDS.some((word) => type.includes(word)) ||
    CLINICAL_WORDS.some((word) => source.includes(word))
  ) {
    return 'clinical';
  }

  if (
    WORKFLOW_WORDS.some((word) => type.includes(word)) ||
    WORKFLOW_WORDS.some((word) => source.includes(word))
  ) {
    return 'workflow';
  }

  if (
    INTEGRATION_WORDS.some((word) => type.includes(word)) ||
    INTEGRATION_WORDS.some((word) => source.includes(word))
  ) {
    return 'integration';
  }

  if (
    HUMAN_WORDS.some((word) => type.includes(word)) ||
    HUMAN_WORDS.some((word) => source.includes(word))
  ) {
    return 'human';
  }

  if (
    AI_WORDS.some((word) => type.includes(word)) ||
    AI_WORDS.some((word) => source.includes(word))
  ) {
    return 'ai';
  }

  if (type || source) {
    return 'system';
  }

  return 'unknown';
}

function eventMatchesLiveFilter(
  event: EventLogEntry,
  filter: LiveFilter,
): boolean {
  if (filter === 'ALL') return true;

  const health = eventHealth(event);
  const domain = eventDomain(event);

  switch (filter) {
    case 'NEW':
      return true;

    case 'FAILED':
      return health === 'bad';

    case 'WARNINGS':
      return health === 'warn';

    case 'SAFETY':
      return domain === 'safety';

    case 'CLINICAL':
      return domain === 'clinical';

    case 'ENGINES':
      return domain === 'engine';

    case 'WORKFLOW':
      return domain === 'workflow';

    case 'INTEGRATIONS':
      return domain === 'integration';

    case 'HUMAN':
      return domain === 'human';

    case 'AI':
      return domain === 'ai';

    default:
      return true;
  }
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
    .slice(0, 4)
    .map(([key, value]) => {
      let rendered: string;

      try {
        rendered =
          typeof value === 'object'
            ? JSON.stringify(value)
            : String(value);
      } catch {
        rendered = '[unserializable]';
      }

      return `${key}: ${
        rendered.length > 80
          ? `${rendered.slice(0, 80)}…`
          : rendered
      }`;
    });

  return entries.join(' · ');
}

function eventAgeMs(event: EventLogEntry): number | null {
  const timestamp = new Date(event.occurredAt).getTime();

  if (!Number.isFinite(timestamp)) {
    return null;
  }

  return Math.max(0, Date.now() - timestamp);
}

function eventAgeLabel(event: EventLogEntry): string {
  const age = eventAgeMs(event);

  if (age === null) return '—';

  if (age < 1000) return 'now';

  if (age < 60_000) {
    return `${Math.floor(age / 1000)}s ago`;
  }

  if (age < 3_600_000) {
    return `${Math.floor(age / 60_000)}m ago`;
  }

  return `${Math.floor(age / 3_600_000)}h ago`;
}

function shortIdentifier(
  value: string | null | undefined,
  prefix: string,
  length = 8,
): string {
  if (!value) return '—';

  return `${prefix}-${value
    .slice(0, length)
    .toUpperCase()}`;
}

function mergeUniqueEvents(
  current: EventLogEntry[],
  incoming: EventLogEntry[],
): EventLogEntry[] {
  const map = new Map<string, EventLogEntry>();

  for (const event of current) {
    map.set(event.id, event);
  }

  for (const event of incoming) {
    map.set(event.id, event);
  }

  return Array.from(map.values())
    .sort(
      (a, b) =>
        new Date(b.occurredAt).getTime() -
        new Date(a.occurredAt).getTime(),
    )
    .slice(0, MAX_LIVE_EVENTS);
}

function sortNewestFirst(
  events: EventLogEntry[],
): EventLogEntry[] {
  return [...events].sort(
    (a, b) =>
      new Date(b.occurredAt).getTime() -
      new Date(a.occurredAt).getTime(),
  );
}

function safeJson(value: unknown): string {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return '[Unable to serialize payload]';
  }
}

// =============================================================================
// BADGE
// =============================================================================

function HealthBadge({
  health,
}: {
  health: EventHealth;
}) {
  return (
    <span className={`admin-badge ${health}`}>
      {health === 'good'
        ? 'processed'
        : health === 'bad'
          ? 'failed'
          : health === 'warn'
            ? 'attention'
            : 'observed'}
    </span>
  );
}

// =============================================================================
// DOMAIN BADGE
// =============================================================================

function DomainBadge({
  domain,
}: {
  domain: EventDomain;
}) {
  return (
    <span
      className={`admin-badge domain-${domain}`}
      title={`Event domain: ${domain}`}
    >
      {domain}
    </span>
  );
}

// =============================================================================
// REALTIME STATUS
// =============================================================================

function LiveStatus({
  state,
  lastPollAt,
  secondsSincePoll,
}: {
  state: ConnectionState;
  lastPollAt: number | null;
  secondsSincePoll: number;
}) {
  const label =
    state === 'live'
      ? 'LIVE'
      : state === 'connecting'
        ? 'CONNECTING'
        : state === 'stale'
          ? 'STALE'
          : 'ERROR';

  return (
    <div
      className={`admin-live-status ${state}`}
      title={
        lastPollAt
          ? `Last event observation ${new Date(
              lastPollAt,
            ).toLocaleString()}`
          : 'No event observation yet'
      }
    >
      <span
        className="admin-health-dot"
        aria-hidden="true"
      />

      <span>{label}</span>

      {state !== 'connecting' && (
        <span className="muted small">
          {secondsSincePoll}s
        </span>
      )}
    </div>
  );
}

// =============================================================================
// MAIN COMPONENT
// =============================================================================

export function EventExplorer({
  initialSelection,
}: EventExplorerProps) {
  // ===========================================================================
  // SERVER DATA
  // ===========================================================================

  const [data, setData] =
    useState<EventsResponse | null>(null);

  const [liveEvents, setLiveEvents] =
    useState<EventLogEntry[]>([]);

  // ===========================================================================
  // UI STATE
  // ===========================================================================

  const [loading, setLoading] = useState(true);

  const [liveLoading, setLiveLoading] =
    useState(false);

  const [error, setError] =
    useState<string | null>(null);

  const [liveError, setLiveError] =
    useState<string | null>(null);

  const [eventType, setEventType] = useState('');

  const [sourceType, setSourceType] =
    useState('');

  const [patientId, setPatientId] =
    useState('');

  const [encounterId, setEncounterId] =
    useState('');

  const [status, setStatus] =
    useState('');

  const [liveFilter, setLiveFilter] =
    useState<LiveFilter>('ALL');

  const [liveOnly, setLiveOnly] =
    useState(false);

  const [offset, setOffset] = useState(0);

  const [selectedEvent, setSelectedEvent] =
    useState<EventSelection | null>(
      initialSelection ?? null,
    );

  const [selected, setSelected] =
    useState<EventDetail | null>(null);

  const [detailLoading, setDetailLoading] =
    useState(false);

  const [connectionState, setConnectionState] =
    useState<ConnectionState>('connecting');

  const [lastPollAt, setLastPollAt] =
    useState<number | null>(null);

  const [now, setNow] =
    useState(() => Date.now());

  const [newEventsCount, setNewEventsCount] =
    useState(0);

  // ===========================================================================
  // REFS
  // ===========================================================================

  const seenIdsRef = useRef<Set<string>>(
    new Set(),
  );

  const liveEventsRef = useRef<EventLogEntry[]>(
    [],
  );

  const pollInFlightRef = useRef(false);

  const mountedRef = useRef(true);

  const lastSuccessfulPollRef =
    useRef<number | null>(null);

  // ===========================================================================
  // CLEANUP
  // ===========================================================================

  useEffect(() => {
    mountedRef.current = true;

    return () => {
      mountedRef.current = false;
    };
  }, []);

  // ===========================================================================
  // CLOCK
  // ===========================================================================

  useEffect(() => {
    const timer = window.setInterval(() => {
      setNow(Date.now());
    }, 1000);

    return () => {
      window.clearInterval(timer);
    };
  }, []);

  // ===========================================================================
  // REGISTER SEEN EVENTS
  // ===========================================================================

  const registerSeen = useCallback(
    (events: EventLogEntry[]) => {
      for (const event of events) {
        seenIdsRef.current.add(event.id);
      }

      if (
        seenIdsRef.current.size >
        MAX_SEEN_EVENT_IDS
      ) {
        const values = Array.from(
          seenIdsRef.current,
        );

        seenIdsRef.current = new Set(
          values.slice(
            Math.max(
              0,
              values.length -
                MAX_SEEN_EVENT_IDS,
            ),
          ),
        );
      }
    },
    [],
  );

  // ===========================================================================
  // INITIAL / FILTERED PAGE LOAD
  // ===========================================================================

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await getEvents({
        eventType:
          eventType || undefined,

        sourceType:
          sourceType || undefined,

        patientId:
          patientId || undefined,

        encounterId:
          encounterId || undefined,

        status:
          status || undefined,

        limit: PAGE_SIZE,
        offset,
      });

      if (!mountedRef.current) return;

      setData(response);

      registerSeen(response.events);

      setConnectionState('live');
      setLiveError(null);
      setLastPollAt(Date.now());
      lastSuccessfulPollRef.current =
        Date.now();
    } catch (e) {
      if (!mountedRef.current) return;

      const message =
        e instanceof Error
          ? e.message
          : 'Failed to load events';

      setError(message);
      setConnectionState('error');
    } finally {
      if (mountedRef.current) {
        setLoading(false);
      }
    }
  }, [
    eventType,
    sourceType,
    patientId,
    encounterId,
    status,
    offset,
    registerSeen,
  ]);

  // ===========================================================================
  // FILTER LOAD
  // ===========================================================================

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    setOffset(0);
  }, [
    eventType,
    sourceType,
    patientId,
    encounterId,
    status,
  ]);

  // ===========================================================================
  // REAL-TIME OBSERVER
  //
  // The existing getEvents API is used as the observation transport.
  //
  // If the Control Plane later exposes SSE/WebSocket, this surface can swap
  // transport without changing the event model or UI.
  // ===========================================================================

  const pollLiveEvents = useCallback(
    async () => {
      if (
        pollInFlightRef.current ||
        !mountedRef.current
      ) {
        return;
      }

      pollInFlightRef.current = true;
      setLiveLoading(true);

      try {
        const response =
          await getEvents({
            eventType:
              eventType || undefined,

            sourceType:
              sourceType || undefined,

            patientId:
              patientId || undefined,

            encounterId:
              encounterId || undefined,

            status:
              status || undefined,

            limit: PAGE_SIZE,
            offset: 0,
          });

        if (!mountedRef.current) return;

        const incoming =
          response.events ?? [];

        const newEvents =
          incoming.filter(
            (event) =>
              !seenIdsRef.current.has(
                event.id,
              ),
          );

        registerSeen(incoming);

        if (newEvents.length > 0) {
          setLiveEvents((current) => {
            const merged =
              mergeUniqueEvents(
                current,
                newEvents,
              );

            liveEventsRef.current =
              merged;

            return merged;
          });

          setNewEventsCount(
            (count) =>
              count + newEvents.length,
          );
        }

        setConnectionState('live');
        setLiveError(null);

        setLastPollAt(Date.now());
        lastSuccessfulPollRef.current =
          Date.now();
      } catch (e) {
        if (!mountedRef.current) return;

        const message =
          e instanceof Error
            ? e.message
            : 'Live event observation failed';

        setLiveError(message);

        const last =
          lastSuccessfulPollRef.current;

        if (
          !last ||
          Date.now() - last >
            LIVE_POLL_ACTIVE_MS * 4
        ) {
          setConnectionState('stale');
        }
      } finally {
        pollInFlightRef.current =
          false;

        if (mountedRef.current) {
          setLiveLoading(false);
        }
      }
    },
    [
      eventType,
      sourceType,
      patientId,
      encounterId,
      status,
      registerSeen,
    ],
  );

  // ===========================================================================
  // REALTIME POLLING LOOP
  // ===========================================================================

  useEffect(() => {
    let timer: number | null = null;

    const schedule = () => {
      const hidden =
        document.visibilityState ===
        'hidden';

      const delay = hidden
        ? LIVE_POLL_BACKGROUND_MS
        : LIVE_POLL_ACTIVE_MS;

      timer = window.setTimeout(
        async () => {
          await pollLiveEvents();
          schedule();
        },
        delay,
      );
    };

    void pollLiveEvents();
    schedule();

    return () => {
      if (timer !== null) {
        window.clearTimeout(timer);
      }
    };
  }, [pollLiveEvents]);

  // ===========================================================================
  // VISIBILITY CHANGE
  // ===========================================================================

  useEffect(() => {
    const handleVisibility = () => {
      if (
        document.visibilityState ===
        'visible'
      ) {
        void pollLiveEvents();
      }
    };

    document.addEventListener(
      'visibilitychange',
      handleVisibility,
    );

    return () => {
      document.removeEventListener(
        'visibilitychange',
        handleVisibility,
      );
    };
  }, [pollLiveEvents]);

  // ===========================================================================
  // INITIAL SELECTION
  // ===========================================================================

  useEffect(() => {
    if (initialSelection?.eventId) {
      setSelectedEvent(
        initialSelection,
      );
    }
  }, [initialSelection]);

  // ===========================================================================
  // OPEN EVENT
  // ===========================================================================

  const openEvent = useCallback(
    (event: EventLogEntry) => {
      setSelectedEvent({
        eventId: event.id,
        encounterId:
          event.encounterId ??
          undefined,
        correlationId:
          event.correlationId ??
          undefined,
      });

      setNewEventsCount(0);
    },
    [],
  );

  // ===========================================================================
  // CLOSE EVENT
  // ===========================================================================

  const closeEvent = useCallback(() => {
    setSelectedEvent(null);
    setSelected(null);
  }, []);

  // ===========================================================================
  // LOAD DETAIL
  // ===========================================================================

  useEffect(() => {
    if (!selectedEvent?.eventId) {
      setSelected(null);
      return;
    }

    let cancelled = false;

    setDetailLoading(true);
    setSelected(null);

    getEvent(selectedEvent)
      .then((detail) => {
        if (!cancelled) {
          setSelected(detail);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setSelected(null);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setDetailLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [selectedEvent]);

  // ===========================================================================
  // RESET FILTERS
  // ===========================================================================

  const resetFilters = useCallback(() => {
    setEventType('');
    setSourceType('');
    setPatientId('');
    setEncounterId('');
    setStatus('');
    setOffset(0);
  }, []);

  // ===========================================================================
  // MERGED DISPLAY DATA
  // ===========================================================================

  const currentPageEvents =
    data?.events ?? [];

  const mergedEvents = useMemo(() => {
    return mergeUniqueEvents(
      liveEvents,
      currentPageEvents,
    );
  }, [
    liveEvents,
    currentPageEvents,
  ]);

  const filteredLiveEvents =
    useMemo(() => {
      let events = mergedEvents;

      if (liveOnly) {
        events = liveEvents;
      }

      return sortNewestFirst(
        events.filter((event) =>
          eventMatchesLiveFilter(
            event,
            liveFilter,
          ),
        ),
      );
    }, [
      mergedEvents,
      liveEvents,
      liveOnly,
      liveFilter,
    ]);

  // ===========================================================================
  // METRICS
  // ===========================================================================

  const total =
    data?.total ?? 0;

  const selectedId =
    selectedEvent?.eventId ?? null;

  const allObservedCount =
    mergedEvents.length;

  const failedCount =
    mergedEvents.filter(
      (event) =>
        eventHealth(event) === 'bad',
    ).length;

  const warningCount =
    mergedEvents.filter(
      (event) =>
        eventHealth(event) === 'warn',
    ).length;

  const safetyCount =
    mergedEvents.filter(
      (event) =>
        eventDomain(event) === 'safety',
    ).length;

  const clinicalCount =
    mergedEvents.filter(
      (event) =>
        eventDomain(event) === 'clinical',
    ).length;

  const engineCount =
    mergedEvents.filter(
      (event) =>
        eventDomain(event) === 'engine',
    ).length;

  const workflowCount =
    mergedEvents.filter(
      (event) =>
        eventDomain(event) === 'workflow',
    ).length;

  const lastPollSeconds =
    lastPollAt === null
      ? 0
      : Math.max(
          0,
          Math.floor(
            (now - lastPollAt) /
              1000,
          ),
        );

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div>
      {/* =====================================================================
          LIVE CONTROL HEADER
          ===================================================================== */}

      <div className="admin-panel">
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'center',
          }}
        >
          <div>
            <span className="admin-panel-title">
              Event Observatory
            </span>

            <span className="admin-panel-sub">
              Real-time AMEXAN event bus
              observation · cpu.event_log
              · read-only
            </span>
          </div>

          <LiveStatus
            state={connectionState}
            lastPollAt={lastPollAt}
            secondsSincePoll={
              lastPollSeconds
            }
          />
        </div>

        {/* ================================================================
            REALTIME METRICS
            ================================================================ */}

        <div className="admin-tile-grid">
          <div className="admin-tile tile-brand">
            <span className="tile-label">
              LIVE OBSERVED
            </span>

            <span className="tile-value">
              {allObservedCount}
            </span>

            <span className="tile-note">
              events retained in this
              observer window
            </span>
          </div>

          <div className="admin-tile">
            <span className="tile-label">
              NEW
            </span>

            <span className="tile-value">
              {newEventsCount}
            </span>

            <span className="tile-note">
              arrivals since last
              acknowledgement
            </span>
          </div>

          <div className="admin-tile tile-danger">
            <span className="tile-label">
              FAILURES
            </span>

            <span className="tile-value">
              {failedCount}
            </span>

            <span className="tile-note">
              failed/error events observed
            </span>
          </div>

          <div className="admin-tile tile-warning">
            <span className="tile-label">
              WARNINGS
            </span>

            <span className="tile-value">
              {warningCount}
            </span>

            <span className="tile-note">
              warning-level events observed
            </span>
          </div>

          <div className="admin-tile tile-good">
            <span className="tile-label">
              SAFETY
            </span>

            <span className="tile-value">
              {safetyCount}
            </span>

            <span className="tile-note">
              safety-domain events observed
            </span>
          </div>

          <div className="admin-tile">
            <span className="tile-label">
              CLINICAL
            </span>

            <span className="tile-value">
              {clinicalCount}
            </span>

            <span className="tile-note">
              clinical-domain events
            </span>
          </div>

          <div className="admin-tile">
            <span className="tile-label">
              ENGINES
            </span>

            <span className="tile-value">
              {engineCount}
            </span>

            <span className="tile-note">
              CPU / knowledge / engine
              events
            </span>
          </div>

          <div className="admin-tile">
            <span className="tile-label">
              WORKFLOW
            </span>

            <span className="tile-value">
              {workflowCount}
            </span>

            <span className="tile-note">
              state / task / queue events
            </span>
          </div>

          <div className="admin-tile">
            <span className="tile-label">
              SERVER LOG
            </span>

            <span className="tile-value">
              {total}
            </span>

            <span className="tile-note">
              events available from API
            </span>
          </div>
        </div>

        {/* ================================================================
            LIVE ERROR
            ================================================================ */}

        {liveError && (
          <div
            className="admin-error"
            role="alert"
            style={{
              marginTop: 12,
            }}
          >
            Live observer:
            {' '}
            {liveError}
          </div>
        )}

        {/* ================================================================
            LIVE FILTERS
            ================================================================ */}

        <div
          className="admin-filters"
          style={{
            marginTop: 16,
          }}
        >
          {(
            [
              'ALL',
              'NEW',
              'FAILED',
              'WARNINGS',
              'SAFETY',
              'CLINICAL',
              'ENGINES',
              'WORKFLOW',
              'INTEGRATIONS',
              'HUMAN',
              'AI',
            ] as LiveFilter[]
          ).map((filter) => (
            <button
              key={filter}
              type="button"
              className={`admin-page-btn${
                liveFilter === filter
                  ? ' active'
                  : ''
              }`}
              onClick={() =>
                setLiveFilter(filter)
              }
            >
              {filter}
            </button>
          ))}

          <button
            type="button"
            className={`admin-page-btn${
              liveOnly ? ' active' : ''
            }`}
            onClick={() =>
              setLiveOnly(
                (value) => !value,
              )
            }
          >
            {liveOnly
              ? 'Live only ✓'
              : 'Live only'}
          </button>

          <button
            type="button"
            className="admin-page-btn"
            onClick={() => {
              setNewEventsCount(0);
              void pollLiveEvents();
            }}
            disabled={liveLoading}
          >
            {liveLoading
              ? 'Watching…'
              : 'Observe now'}
          </button>
        </div>
      </div>

      {/* =====================================================================
          FULL SERVER FILTERS
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{
          marginTop: 16,
        }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Event Search
          </span>

          <span className="admin-panel-sub">
            Server-side filters
          </span>
        </div>

        <div className="admin-filters">
          <input
            className="admin-filter-input"
            type="text"
            placeholder="Event type"
            value={eventType}
            onChange={(e) =>
              setEventType(
                e.target.value,
              )
            }
          />

          <input
            className="admin-filter-input"
            type="text"
            placeholder="Source type"
            value={sourceType}
            onChange={(e) =>
              setSourceType(
                e.target.value,
              )
            }
          />

          <input
            className="admin-filter-input"
            type="text"
            placeholder="Patient ID"
            value={patientId}
            onChange={(e) =>
              setPatientId(
                e.target.value,
              )
            }
          />

          <input
            className="admin-filter-input"
            type="text"
            placeholder="Encounter ID"
            value={encounterId}
            onChange={(e) =>
              setEncounterId(
                e.target.value,
              )
            }
          />

          <input
            className="admin-filter-input"
            type="text"
            placeholder="Processing status"
            value={status}
            onChange={(e) =>
              setStatus(
                e.target.value,
              )
            }
          />

          <button
            type="button"
            className="admin-page-btn"
            onClick={() => {
              setOffset(0);
              void load();
            }}
          >
            Apply
          </button>

          <button
            type="button"
            className="admin-page-btn"
            onClick={resetFilters}
          >
            Clear
          </button>
        </div>
      </div>

      {/* =====================================================================
          REALTIME EVENT STREAM
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{
          marginTop: 16,
        }}
      >
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              Live Event Stream
            </span>

            <span className="admin-panel-sub">
              Continuous observation of
              events reaching the Control
              Plane
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
            <span className="admin-badge good">
              observer
            </span>

            <span className="muted small">
              polling every{' '}
              {document.visibilityState ===
              'hidden'
                ? '15s'
                : '3s'}
            </span>
          </div>
        </div>

        {filteredLiveEvents.length === 0 && (
          <div className="admin-empty">
            No live events match the
            selected observation filter.
          </div>
        )}

        {filteredLiveEvents.length > 0 && (
          <div className="admin-activity">
            {filteredLiveEvents.map(
              (event) => {
                const health =
                  eventHealth(event);

                const domain =
                  eventDomain(event);

                return (
                  <button
                    key={`live-${event.id}`}
                    type="button"
                    className="admin-activity-item admin-row-click"
                    style={{
                      border: 'none',
                      background:
                        'transparent',
                      textAlign: 'left',
                      width: '100%',
                      cursor: 'pointer',
                    }}
                    onClick={() =>
                      openEvent(event)
                    }
                  >
                    <span className="admin-activity-time">
                      {eventAgeLabel(
                        event,
                      )}
                    </span>

                    <span
                      className={`admin-health-dot ${
                        health === 'bad'
                          ? 'bad'
                          : health ===
                              'warn'
                            ? 'warn'
                            : 'good'
                      }`}
                      aria-hidden="true"
                    />

                    <span className="admin-activity-type">
                      {event.eventType}
                    </span>

                    <DomainBadge
                      domain={domain}
                    />

                    <span className="admin-activity-meta">
                      {event.sourceType ??
                        '—'}

                      {event.encounterId
                        ? ` · ${shortIdentifier(
                            event.encounterId,
                            'ENC',
                            6,
                          )}`
                        : ''}

                      {event.patientId
                        ? ` · ${shortIdentifier(
                            event.patientId,
                            'PT',
                            8,
                          )}`
                        : ''}
                    </span>

                    <HealthBadge
                      health={health}
                    />

                    <span className="admin-activity-tag">
                      {formatEventId(
                        event.id,
                      )}
                    </span>
                  </button>
                );
              },
            )}
          </div>
        )}
      </div>

      {/* =====================================================================
          SERVER EVENT TABLE
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{
          marginTop: 16,
        }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Event Log
          </span>

          <span className="admin-panel-sub">
            {total} events · cpu.event_log
          </span>
        </div>

        {loading && (
          <div className="admin-loading">
            <span
              className="admin-spinner"
              aria-hidden="true"
            />
            Loading events…
          </div>
        )}

        {error && (
          <div
            className="admin-error"
            role="alert"
          >
            {error}
          </div>
        )}

        {!loading && !error && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Event</th>
                  <th>Domain</th>
                  <th>Source</th>
                  <th>Patient</th>
                  <th>Encounter</th>
                  <th>Status</th>
                </tr>
              </thead>

              <tbody>
                {(data?.events ?? []).map(
                  (event) => {
                    const health =
                      eventHealth(
                        event,
                      );

                    return (
                      <tr
                        key={event.id}
                        className="admin-row-click"
                        onClick={() =>
                          openEvent(
                            event,
                          )
                        }
                      >
                        <td className="mono">
                          {formatEventTime(
                            event.occurredAt,
                          )}
                        </td>

                        <td className="mono">
                          {event.eventType}
                        </td>

                        <td>
                          <DomainBadge
                            domain={eventDomain(
                              event,
                            )}
                          />
                        </td>

                        <td>
                          {event.sourceType ??
                            '—'}
                        </td>

                        <td className="mono">
                          {event.patientId
                            ? shortIdentifier(
                                event.patientId,
                                'PT',
                              )
                            : '—'}
                        </td>

                        <td className="mono">
                          {event.encounterId
                            ? shortIdentifier(
                                event.encounterId,
                                'ENC',
                                6,
                              )
                            : '—'}
                        </td>

                        <td>
                          <HealthBadge
                            health={health}
                          />
                        </td>
                      </tr>
                    );
                  },
                )}
              </tbody>
            </table>

            {(data?.events.length ??
              0) === 0 && (
              <div className="admin-empty">
                No events match the
                current filters.
              </div>
            )}

            {/* ==============================================================
                PAGINATION
                ============================================================== */}

            <div className="admin-pagination">
              <button
                type="button"
                className="admin-page-btn"
                disabled={
                  offset === 0
                }
                onClick={() =>
                  setOffset(
                    (value) =>
                      Math.max(
                        0,
                        value -
                          PAGE_SIZE,
                      ),
                  )
                }
              >
                ← Previous
              </button>

              <span>
                {total === 0
                  ? '0 events'
                  : `Showing ${
                      offset + 1
                    }–${Math.min(
                      offset +
                        PAGE_SIZE,
                      total,
                    )} of ${total}`}
              </span>

              <button
                type="button"
                className="admin-page-btn"
                disabled={
                  offset +
                    PAGE_SIZE >=
                  total
                }
                onClick={() =>
                  setOffset(
                    (value) =>
                      value +
                      PAGE_SIZE,
                  )
                }
              >
                Next →
              </button>
            </div>
          </div>
        )}
      </div>

      {/* =====================================================================
          EVENT DETAIL DRAWER
          ===================================================================== */}

      {selectedId !== null && (
        <div
          className="admin-drawer-backdrop"
          onClick={closeEvent}
          role="presentation"
        >
          <div
            className="admin-drawer"
            onClick={(e) =>
              e.stopPropagation()
            }
            role="dialog"
            aria-modal="true"
            aria-label={`Event ${selectedId} detail`}
          >
            {/* ==============================================================
                DRAWER HEADER
                ============================================================== */}

            <div className="admin-drawer-head">
              <div>
                <span className="admin-drawer-title">
                  Event{' '}
                  {formatEventId(
                    selectedId,
                  )}
                </span>

                {selected && (
                  <div
                    className="muted small"
                    style={{
                      marginTop: 4,
                    }}
                  >
                    {selected.eventType}
                  </div>
                )}
              </div>

              <button
                type="button"
                className="admin-drawer-close"
                onClick={closeEvent}
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            {/* ==============================================================
                DRAWER BODY
                ============================================================== */}

            <div className="admin-drawer-body">
              {detailLoading && (
                <div className="admin-loading">
                  <span
                    className="admin-spinner"
                    aria-hidden="true"
                  />
                  Loading complete event
                  detail…
                </div>
              )}

              {!detailLoading &&
                !selected && (
                  <div className="admin-error">
                    Event not found.
                  </div>
                )}

              {!detailLoading &&
                selected && (
                  <>
                    {/* ======================================================
                        CORE EVENT IDENTITY
                        ====================================================== */}

                    <div className="admin-panel">
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Event Identity
                        </span>

                        <span className="admin-panel-sub">
                          immutable event
                          observation
                        </span>
                      </div>

                      <div className="admin-kv">
                        <span className="k">
                          Event ID
                        </span>

                        <span className="v mono">
                          {selected.id}
                        </span>

                        <span className="k">
                          Event type
                        </span>

                        <span className="v mono">
                          {
                            selected.eventType
                          }
                        </span>

                        <span className="k">
                          Domain
                        </span>

                        <span className="v">
                          <DomainBadge
                            domain={eventDomain(
                              {
                                id:
                                  selected.id,
                                eventType:
                                  selected.eventType,
                                sourceType:
                                  selected.sourceType,
                                patientId:
                                  selected.patientId,
                                encounterId:
                                  selected.encounterId,
                                processingStatus:
                                  selected.processingStatus,
                                occurredAt:
                                  selected.occurredAt,
                              } as EventLogEntry,
                            )}
                          />
                        </span>

                        <span className="k">
                          Occurred
                        </span>

                        <span className="v mono">
                          {
                            selected.occurredAt
                          }
                        </span>

                        <span className="k">
                          Age
                        </span>

                        <span className="v">
                          {eventAgeLabel(
                            {
                              id:
                                selected.id,
                              eventType:
                                selected.eventType,
                              sourceType:
                                selected.sourceType,
                              patientId:
                                selected.patientId,
                              encounterId:
                                selected.encounterId,
                              processingStatus:
                                selected.processingStatus,
                              occurredAt:
                                selected.occurredAt,
                            } as EventLogEntry,
                          )}
                        </span>

                        <span className="k">
                          Processing
                        </span>

                        <span className="v">
                          {selected.processingStatus ??
                            '—'}
                        </span>

                        <span className="k">
                          Source
                        </span>

                        <span className="v">
                          {selected.sourceType ??
                            '—'}

                          {selected.sourceId
                            ? ` / ${selected.sourceId}`
                            : ''}
                        </span>

                        <span className="k">
                          Patient
                        </span>

                        <span className="v mono">
                          {selected.patientId ??
                            '—'}
                        </span>

                        <span className="k">
                          Encounter
                        </span>

                        <span className="v mono">
                          {selected.encounterId ??
                            '—'}
                        </span>

                        <span className="k">
                          Correlation
                        </span>

                        <span className="v mono">
                          {selected.correlationId ??
                            '—'}
                        </span>
                      </div>
                    </div>

                    {/* ======================================================
                        CPU / KNOWLEDGE PROVENANCE
                        ====================================================== */}

                    <div
                      className="admin-panel"
                      style={{
                        marginTop: 16,
                      }}
                    >
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          AMEXAN Provenance
                        </span>

                        <span className="admin-panel-sub">
                          execution context
                        </span>
                      </div>

                      <div className="admin-kv">
                        <span className="k">
                          CPU version
                        </span>

                        <span className="v mono">
                          {selected.cpuVersion ??
                            '—'}
                        </span>

                        <span className="k">
                          Knowledge
                          version
                        </span>

                        <span className="v mono">
                          {
                            selected.knowledgeVersion ??
                            '—'
                          }
                        </span>

                        <span className="k">
                          Fact
                        </span>

                        <span className="v mono">
                          {selected.factCode
                            ? `${
                                selected.factCode
                              } = ${
                                selected.factValue ??
                                '—'
                              }`
                            : '—'}
                        </span>
                      </div>
                    </div>

                    {/* ======================================================
                        PAYLOAD
                        ====================================================== */}

                    {selected.payload && (
                      <div
                        className="admin-panel"
                        style={{
                          marginTop: 16,
                        }}
                      >
                        <div className="admin-panel-head">
                          <span className="admin-panel-title">
                            Event Payload
                          </span>

                          <span className="admin-panel-sub">
                            captured event
                            data
                          </span>
                        </div>

                        <pre className="admin-json">
                          {safeJson(
                            selected.payload,
                          )}
                        </pre>
                      </div>
                    )}

                    {/* ======================================================
                        CORRELATION LINEAGE
                        ====================================================== */}

                    <div
                      className="admin-panel"
                      style={{
                        marginTop: 16,
                      }}
                    >
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Correlation Lineage
                        </span>

                        <span className="admin-panel-sub">
                          {
                            selected.lineage
                              ?.length ??
                            0
                          }{' '}
                          correlated
                          events
                        </span>
                      </div>

                      {(!selected.lineage ||
                        selected.lineage
                          .length ===
                          0) && (
                        <div className="admin-empty">
                          No correlated
                          lineage events
                          were returned.
                        </div>
                      )}

                      {selected.lineage &&
                        selected.lineage
                          .length >
                          0 && (
                          <div className="admin-trace-rail">
                            {selected.lineage.map(
                              (
                                entry,
                              ) => (
                                <div
                                  key={
                                    entry.id
                                  }
                                  className="admin-trace-item"
                                >
                                  <span className="trace-time">
                                    {formatEventTime(
                                      entry.occurredAt,
                                    )}
                                  </span>

                                  <span className="trace-type">
                                    {formatEventId(
                                      entry.id,
                                    )}{' '}
                                    {
                                      entry.eventType
                                    }
                                  </span>
                                </div>
                              ),
                            )}
                          </div>
                        )}
                    </div>

                    {/* ======================================================
                        OPERATIONAL INTERPRETATION
                        ====================================================== */}

                    <div
                      className="admin-panel"
                      style={{
                        marginTop: 16,
                      }}
                    >
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Observer Classification
                        </span>

                        <span className="admin-panel-sub">
                          non-clinical
                          monitoring
                          metadata
                        </span>
                      </div>

                      <div className="admin-kv">
                        <span className="k">
                          Health
                        </span>

                        <span className="v">
                          <HealthBadge
                            health={eventHealth(
                              {
                                id:
                                  selected.id,
                                eventType:
                                  selected.eventType,
                                sourceType:
                                  selected.sourceType,
                                patientId:
                                  selected.patientId,
                                encounterId:
                                  selected.encounterId,
                                processingStatus:
                                  selected.processingStatus,
                                occurredAt:
                                  selected.occurredAt,
                              } as EventLogEntry,
                            )}
                          />
                        </span>

                        <span className="k">
                          Domain
                        </span>

                        <span className="v">
                          {
                            eventDomain(
                              {
                                id:
                                  selected.id,
                                eventType:
                                  selected.eventType,
                                sourceType:
                                  selected.sourceType,
                                patientId:
                                  selected.patientId,
                                encounterId:
                                  selected.encounterId,
                                processingStatus:
                                  selected.processingStatus,
                                occurredAt:
                                  selected.occurredAt,
                              } as EventLogEntry,
                            )
                          }
                        </span>

                        <span className="k">
                          Payload
                          summary
                        </span>

                        <span className="v">
                          {payloadSummary(
                            selected.payload ?? undefined,
                          ) ||
                            'No summarizable payload'}
                        </span>
                      </div>
                    </div>
                  </>
                )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}