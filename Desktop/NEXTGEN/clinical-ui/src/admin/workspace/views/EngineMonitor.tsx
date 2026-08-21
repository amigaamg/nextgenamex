// =============================================================================
// AMEXAN Engine Monitor — REAL-TIME CONTROL-PLANE OBSERVATORY
//
// OPERATE / INVESTIGATE
//
// PURPOSE
// -----------------------------------------------------------------------------
// This view is the administrative "eyes" of AMEXAN's engine layer.
//
// It monitors:
//   • every registered clinical/system engine
//   • engine lifecycle state
//   • engine health
//   • runtime execution
//   • event throughput
//   • failures / errors
//   • latency
//   • jobs
//   • health checks
//   • feature flags
//   • engine versions
//   • last execution
//   • engine dependencies
//   • safety state
//   • degraded / failed engines
//   • real-time activity
//
// ARCHITECTURAL RULE
// -----------------------------------------------------------------------------
// PostgreSQL is NEVER accessed directly by this UI.
// All information comes through the AMEXAN Control Plane API.
//
// REAL-TIME STRATEGY
// -----------------------------------------------------------------------------
// 1. Initial REST snapshot.
// 2. Control-plane event stream when available.
// 3. Automatic polling fallback.
// 4. Local state reconciliation.
// 5. Selected engine detail refresh.
// 6. Browser remains responsive even with thousands of events.
//
// SUPPORTED EVENT TYPES
// -----------------------------------------------------------------------------
// ENGINE_REGISTERED
// ENGINE_STARTED
// ENGINE_STOPPED
// ENGINE_HEALTH_CHANGED
// ENGINE_DEGRADED
// ENGINE_RECOVERED
// ENGINE_FAILED
// ENGINE_EXECUTION_STARTED
// ENGINE_EXECUTION_COMPLETED
// ENGINE_EXECUTION_FAILED
// ENGINE_HEARTBEAT
// ENGINE_VERSION_CHANGED
// ENGINE_CONFIG_CHANGED
// ENGINE_FLAG_CHANGED
// ENGINE_JOB_STARTED
// ENGINE_JOB_COMPLETED
// ENGINE_JOB_FAILED
// ENGINE_SAFETY_BLOCKED
// ENGINE_SAFETY_WARNING
// ENGINE_OVERRIDE
// ENGINE_TIMEOUT
// ENGINE_RETRY
//
// IMPORTANT
// -----------------------------------------------------------------------------
// This component remains read-only.
// Administrative actions belong to a separately permissioned Control Plane
// command surface.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import {
  getEngines,
  getEngineDetail,
  getFeatureFlags,
  getHealthChecks,
  getJobs,
} from '../api';

import type {
  EngineDetail,
  EngineEntry,
  EnginesResponse,
  FeatureFlagsResponse,
  HealthResponse,
  JobsResponse,
} from '../types';

import { formatEventId } from '../events';

// =============================================================================
// CONSTANTS
// =============================================================================

const POLL_INTERVAL_MS = 15_000;
const DETAIL_REFRESH_INTERVAL_MS = 10_000;
const MAX_LIVE_EVENTS = 100;

const ENGINE_EVENT_TYPES = new Set([
  'ENGINE_REGISTERED',
  'ENGINE_STARTED',
  'ENGINE_STOPPED',
  'ENGINE_HEALTH_CHANGED',
  'ENGINE_DEGRADED',
  'ENGINE_RECOVERED',
  'ENGINE_FAILED',
  'ENGINE_EXECUTION_STARTED',
  'ENGINE_EXECUTION_COMPLETED',
  'ENGINE_EXECUTION_FAILED',
  'ENGINE_HEARTBEAT',
  'ENGINE_VERSION_CHANGED',
  'ENGINE_CONFIG_CHANGED',
  'ENGINE_FLAG_CHANGED',
  'ENGINE_JOB_STARTED',
  'ENGINE_JOB_COMPLETED',
  'ENGINE_JOB_FAILED',
  'ENGINE_SAFETY_BLOCKED',
  'ENGINE_SAFETY_WARNING',
  'ENGINE_OVERRIDE',
  'ENGINE_TIMEOUT',
  'ENGINE_RETRY',
]);

// =============================================================================
// LOCAL TYPES
// =============================================================================

type HealthLevel = 'good' | 'warn' | 'bad' | 'idle';

type MonitorFilter =
  | 'ALL'
  | 'HEALTHY'
  | 'DEGRADED'
  | 'FAILED'
  | 'RUNNING'
  | 'INACTIVE';

type LiveEngineEvent = {
  id: string | number;
  eventType: string;
  engineCode?: string | null;
  status?: string | null;
  occurredAt: string;
  correlationId?: string | null;
  encounterId?: string | null;
  message?: string | null;
  latencyMs?: number | null;
};

type EngineRuntimeStats = {
  executions: number;
  successes: number;
  failures: number;
  blocked: number;
  retries: number;
  timeouts: number;
  lastExecutionAt: string | null;
  lastFailureAt: string | null;
  lastLatencyMs: number | null;
};

type EngineMonitorProps = {
  /**
   * Optional external event source.
   *
   * The Control Plane can dispatch:
   *
   * window.dispatchEvent(
   *   new CustomEvent('amexan:engine-event', {
   *     detail: {
   *       id,
   *       eventType,
   *       engineCode,
   *       status,
   *       occurredAt,
   *       correlationId,
   *       encounterId,
   *       message,
   *       latencyMs,
   *     },
   *   }),
   * );
   */
  eventTarget?: EventTarget;
};

// =============================================================================
// HELPERS
// =============================================================================

function normaliseStatus(status: string | null | undefined): string {
  return String(status ?? '').trim().toUpperCase();
}

function healthDot(status: string | null | undefined): HealthLevel {
  const s = normaliseStatus(status);

  if (
    s === 'ACTIVE' ||
    s === 'HEALTHY' ||
    s === 'COMPLETED' ||
    s === 'RUNNING' ||
    s === 'READY' ||
    s === 'ONLINE' ||
    s === 'RECOVERED'
  ) {
    return 'good';
  }

  if (
    s === 'DEGRADED' ||
    s === 'WARNING' ||
    s === 'PENDING' ||
    s === 'STARTING' ||
    s === 'RETRYING' ||
    s === 'TIMEOUT'
  ) {
    return 'warn';
  }

  if (
    s === 'FAILED' ||
    s === 'ERROR' ||
    s === 'INACTIVE' ||
    s === 'BLOCKED' ||
    s === 'OFFLINE' ||
    s === 'STOPPED'
  ) {
    return 'bad';
  }

  return 'idle';
}

function healthLabel(status: string | null | undefined): string {
  const level = healthDot(status);

  if (level === 'good') return 'Healthy';
  if (level === 'warn') return 'Degraded';
  if (level === 'bad') return 'Failed';

  return status ?? 'Unknown';
}

function eventLevel(eventType: string): HealthLevel {
  const type = eventType.toUpperCase();

  if (
    type.includes('FAILED') ||
    type.includes('ERROR') ||
    type.includes('TIMEOUT') ||
    type.includes('BLOCKED')
  ) {
    return 'bad';
  }

  if (
    type.includes('WARNING') ||
    type.includes('DEGRADED') ||
    type.includes('RETRY') ||
    type.includes('OVERRIDE')
  ) {
    return 'warn';
  }

  if (
    type.includes('COMPLETED') ||
    type.includes('RECOVERED') ||
    type.includes('STARTED') ||
    type.includes('HEARTBEAT')
  ) {
    return 'good';
  }

  return 'idle';
}

function safeDate(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}

function safeTime(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleTimeString();
}

function elapsedSince(value: string | null | undefined): string {
  if (!value) return '—';

  const timestamp = new Date(value).getTime();

  if (!Number.isFinite(timestamp)) {
    return '—';
  }

  const seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000));

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

  return `${Math.floor(hours / 24)}d ago`;
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat().format(Number.isFinite(value) ? value : 0);
}

function percent(value: number, total: number): string {
  if (!total) return '0%';

  return `${Math.round((value / total) * 100)}%`;
}

function eventMatchesFilter(
  engine: EngineEntry,
  filter: MonitorFilter,
): boolean {
  if (filter === 'ALL') return true;

  const status = normaliseStatus(engine.status);

  switch (filter) {
    case 'HEALTHY':
      return healthDot(status) === 'good';

    case 'DEGRADED':
      return healthDot(status) === 'warn';

    case 'FAILED':
      return healthDot(status) === 'bad';

    case 'RUNNING':
      return (
        status === 'RUNNING' ||
        status === 'ACTIVE' ||
        status === 'EXECUTING'
      );

    case 'INACTIVE':
      return (
        status === 'INACTIVE' ||
        status === 'STOPPED' ||
        !engine.isActive
      );

    default:
      return true;
  }
}

// =============================================================================
// MAIN COMPONENT
// =============================================================================

export function EngineMonitor({
  eventTarget,
}: EngineMonitorProps = {}) {
  // ===========================================================================
  // SNAPSHOT STATE
  // ===========================================================================

  const [engines, setEngines] = useState<EnginesResponse | null>(null);
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [jobs, setJobs] = useState<JobsResponse | null>(null);
  const [flags, setFlags] = useState<FeatureFlagsResponse | null>(null);

  // ===========================================================================
  // UI STATE
  // ===========================================================================

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [filter, setFilter] = useState<MonitorFilter>('ALL');
  const [search, setSearch] = useState('');

  // ===========================================================================
  // DETAIL STATE
  // ===========================================================================

  const [selected, setSelected] = useState<EngineDetail | null>(null);
  const [selectedCode, setSelectedCode] = useState<string | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);

  // ===========================================================================
  // LIVE STATE
  // ===========================================================================

  const [liveEvents, setLiveEvents] = useState<LiveEngineEvent[]>([]);
  const [lastLiveEventAt, setLastLiveEventAt] = useState<string | null>(null);

  const streamConnected = false;

  // ===========================================================================
  // LOCAL EXECUTION COUNTERS
  // ===========================================================================

  const [runtimeStats, setRuntimeStats] = useState<
    Record<string, EngineRuntimeStats>
  >({});

  // ===========================================================================
  // REFS
  // ===========================================================================

  const mountedRef = useRef(true);
  const pollInFlightRef = useRef(false);
  const detailRequestRef = useRef(0);
  const liveEventSequenceRef = useRef(0);

  // ===========================================================================
  // LOAD CONTROL-PLANE SNAPSHOT
  // ===========================================================================

  const load = useCallback(async (silent = false) => {
    if (pollInFlightRef.current) return;

    pollInFlightRef.current = true;

    if (!silent) {
      setLoading(true);
    } else {
      setRefreshing(true);
    }

    setError(null);

    try {
      const [engineResponse, healthResponse, jobsResponse, flagsResponse] =
        await Promise.all([
          getEngines(),
          getHealthChecks(),
          getJobs(),
          getFeatureFlags(),
        ]);

      if (!mountedRef.current) return;

      setEngines(engineResponse);
      setHealth(healthResponse);
      setJobs(jobsResponse);
      setFlags(flagsResponse);
    } catch (e) {
      if (!mountedRef.current) return;

      setError(
        e instanceof Error
          ? e.message
          : 'Failed to load engine monitor',
      );
    } finally {
      pollInFlightRef.current = false;

      if (!mountedRef.current) return;

      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  // ===========================================================================
  // INITIAL SNAPSHOT + FALLBACK POLLING
  // ===========================================================================

  useEffect(() => {
    mountedRef.current = true;

    void load(false);

    const timer = window.setInterval(() => {
      void load(true);
    }, POLL_INTERVAL_MS);

    return () => {
      mountedRef.current = false;
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // SELECTED ENGINE DETAIL
  // ===========================================================================

  const loadEngineDetail = useCallback(async (code: string) => {
    const requestId = ++detailRequestRef.current;

    setDetailLoading(true);
    setDetailError(null);
    setSelected(null);

    try {
      const detail = await getEngineDetail(code);

      if (!mountedRef.current) return;
      if (requestId !== detailRequestRef.current) return;

      setSelected(detail);
    } catch (e) {
      if (!mountedRef.current) return;
      if (requestId !== detailRequestRef.current) return;

      setDetailError(
        e instanceof Error
          ? e.message
          : 'Failed to load engine detail',
      );
    } finally {
      if (!mountedRef.current) return;
      if (requestId !== detailRequestRef.current) return;

      setDetailLoading(false);
    }
  }, []);

  const openEngine = useCallback(
    (code: string) => {
      setSelectedCode(code);
      void loadEngineDetail(code);
    },
    [loadEngineDetail],
  );

  const closeEngine = useCallback(() => {
    ++detailRequestRef.current;
    setSelectedCode(null);
    setSelected(null);
    setDetailError(null);
    setDetailLoading(false);
  }, []);

  // ===========================================================================
  // AUTO-REFRESH SELECTED ENGINE
  // ===========================================================================

  useEffect(() => {
    if (!selectedCode) return;

    const timer = window.setInterval(() => {
      void loadEngineDetail(selectedCode);
    }, DETAIL_REFRESH_INTERVAL_MS);

    return () => window.clearInterval(timer);
  }, [selectedCode, loadEngineDetail]);

  // ===========================================================================
  // REAL-TIME EVENT INGESTION
  // ===========================================================================

  const ingestLiveEvent = useCallback((incoming: unknown) => {
    if (!incoming || typeof incoming !== 'object') return;

    const raw = incoming as Record<string, unknown>;

    const eventType = String(
      raw.eventType ??
        raw.type ??
        raw.name ??
        '',
    ).toUpperCase();

    if (!eventType) return;

    if (
      ENGINE_EVENT_TYPES.size > 0 &&
      !ENGINE_EVENT_TYPES.has(eventType) &&
      !eventType.startsWith('ENGINE_')
    ) {
      return;
    }

    const occurredAt =
      typeof raw.occurredAt === 'string'
        ? raw.occurredAt
        : new Date().toISOString();

    const engineCode =
      typeof raw.engineCode === 'string'
        ? raw.engineCode
        : typeof raw.engine_code === 'string'
          ? raw.engine_code
          : typeof raw.sourceCode === 'string'
            ? raw.sourceCode
            : null;

    const id =
      typeof raw.id === 'string' || typeof raw.id === 'number'
        ? raw.id
        : `live-${Date.now()}-${++liveEventSequenceRef.current}`;

    const event: LiveEngineEvent = {
      id,
      eventType,
      engineCode,
      status:
        typeof raw.status === 'string'
          ? raw.status
          : null,
      occurredAt,
      correlationId:
        typeof raw.correlationId === 'string'
          ? raw.correlationId
          : null,
      encounterId:
        typeof raw.encounterId === 'string'
          ? raw.encounterId
          : null,
      message:
        typeof raw.message === 'string'
          ? raw.message
          : null,
      latencyMs:
        typeof raw.latencyMs === 'number'
          ? raw.latencyMs
          : null,
    };

    setLiveEvents((current) => {
      const deduplicated = current.filter(
        (item) => String(item.id) !== String(event.id),
      );

      return [event, ...deduplicated].slice(0, MAX_LIVE_EVENTS);
    });

    setLastLiveEventAt(occurredAt);

    if (!engineCode) return;

    setRuntimeStats((current) => {
      const previous = current[engineCode] ?? {
        executions: 0,
        successes: 0,
        failures: 0,
        blocked: 0,
        retries: 0,
        timeouts: 0,
        lastExecutionAt: null,
        lastFailureAt: null,
        lastLatencyMs: null,
      };

      const next: EngineRuntimeStats = {
        ...previous,
      };

      if (eventType === 'ENGINE_EXECUTION_STARTED') {
        next.executions += 1;
        next.lastExecutionAt = occurredAt;
      }

      if (eventType === 'ENGINE_EXECUTION_COMPLETED') {
        next.successes += 1;
        next.lastExecutionAt = occurredAt;
        next.lastLatencyMs = event.latencyMs ?? previous.lastLatencyMs;
      }

      if (
        eventType === 'ENGINE_EXECUTION_FAILED' ||
        eventType === 'ENGINE_FAILED'
      ) {
        next.failures += 1;
        next.lastFailureAt = occurredAt;
        next.lastLatencyMs = event.latencyMs ?? previous.lastLatencyMs;
      }

      if (eventType === 'ENGINE_SAFETY_BLOCKED') {
        next.blocked += 1;
      }

      if (eventType === 'ENGINE_RETRY') {
        next.retries += 1;
      }

      if (eventType === 'ENGINE_TIMEOUT') {
        next.timeouts += 1;
      }

      return {
        ...current,
        [engineCode]: next,
      };
    });

    // If an event concerns the currently selected engine, refresh its
    // authoritative Control Plane projection.
    if (
      selectedCode &&
      engineCode.toUpperCase() === selectedCode.toUpperCase()
    ) {
      void loadEngineDetail(selectedCode);
    }
  }, [loadEngineDetail, selectedCode]);

  // ===========================================================================
  // WINDOW EVENT BUS
  // ===========================================================================

  useEffect(() => {
    const target = eventTarget ?? window;

    const handler = (event: Event) => {
      const customEvent = event as CustomEvent;

      ingestLiveEvent(customEvent.detail);
    };

    target.addEventListener('amexan:engine-event', handler);

    return () => {
      target.removeEventListener('amexan:engine-event', handler);
    };
  }, [eventTarget, ingestLiveEvent]);

  // ===========================================================================
  // OPTIONAL BROAD AMEXAN EVENT BUS
  // ===========================================================================

  useEffect(() => {
    const target = eventTarget ?? window;

    const handler = (event: Event) => {
      const customEvent = event as CustomEvent;
      const detail = customEvent.detail;

      if (!detail || typeof detail !== 'object') return;

      const candidate = detail as Record<string, unknown>;

      const type = String(
        candidate.eventType ??
          candidate.type ??
          '',
      ).toUpperCase();

      if (!type.startsWith('ENGINE_')) return;

      ingestLiveEvent(detail);
    };

    target.addEventListener('amexan:event', handler);

    return () => {
      target.removeEventListener('amexan:event', handler);
    };
  }, [eventTarget, ingestLiveEvent]);

  // ===========================================================================
  // DERIVED DATA
  // ===========================================================================

  const productEngines: EngineEntry[] = useMemo(
    () => engines?.engines ?? [],
    [engines],
  );

  const registry = useMemo(
    () => engines?.engineRegistry ?? [],
    [engines],
  );

  const filteredEngines = useMemo(() => {
    const query = search.trim().toLowerCase();

    return productEngines.filter((engine) => {
      if (!eventMatchesFilter(engine, filter)) {
        return false;
      }

      if (!query) {
        return true;
      }

      return [
        engine.name,
        engine.code,
        engine.engineType,
        engine.status,
      ]
        .filter(Boolean)
        .some((value) =>
          String(value).toLowerCase().includes(query),
        );
    });
  }, [productEngines, filter, search]);

  const engineCounts = useMemo(() => {
    let healthy = 0;
    let degraded = 0;
    let failed = 0;
    let running = 0;
    let inactive = 0;

    for (const engine of productEngines) {
      const status = normaliseStatus(engine.status);
      const level = healthDot(status);

      if (level === 'good') healthy += 1;
      if (level === 'warn') degraded += 1;
      if (level === 'bad') failed += 1;

      if (
        status === 'RUNNING' ||
        status === 'ACTIVE' ||
        status === 'EXECUTING'
      ) {
        running += 1;
      }

      if (
        status === 'INACTIVE' ||
        status === 'STOPPED' ||
        !engine.isActive
      ) {
        inactive += 1;
      }
    }

    return {
      total: productEngines.length,
      healthy,
      degraded,
      failed,
      running,
      inactive,
    };
  }, [productEngines]);

  const liveFailureCount = useMemo(
    () =>
      liveEvents.filter(
        (event) => eventLevel(event.eventType) === 'bad',
      ).length,
    [liveEvents],
  );

  const liveWarningCount = useMemo(
    () =>
      liveEvents.filter(
        (event) => eventLevel(event.eventType) === 'warn',
      ).length,
    [liveEvents],
  );

  const executionCount = useMemo(
    () =>
      Object.values(runtimeStats).reduce(
        (sum, stats) => sum + stats.executions,
        0,
      ),
    [runtimeStats],
  );

  const executionFailures = useMemo(
    () =>
      Object.values(runtimeStats).reduce(
        (sum, stats) => sum + stats.failures,
        0,
      ),
    [runtimeStats],
  );

  const executionSuccesses = useMemo(
    () =>
      Object.values(runtimeStats).reduce(
        (sum, stats) => sum + stats.successes,
        0,
      ),
    [runtimeStats],
  );

  const executionSuccessRate = percent(
    executionSuccesses,
    executionSuccesses + executionFailures,
  );

  // ===========================================================================
  // RENDER: INITIAL LOADING
  // ===========================================================================

  if (loading && !engines) {
    return (
      <div className="admin-loading">
        <span className="admin-spinner" aria-hidden="true" />
        Loading engine monitor…
      </div>
    );
  }

  // ===========================================================================
  // RENDER: INITIAL ERROR
  // ===========================================================================

  if (error && !engines) {
    return (
      <div className="admin-panel">
        <div className="admin-error" role="alert">
          {error}
        </div>

        <button
          type="button"
          className="admin-page-btn"
          onClick={() => void load(false)}
        >
          Retry
        </button>
      </div>
    );
  }

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div>
      {/* =====================================================================
          CONTROL HEADER
          ===================================================================== */}

      <div className="admin-panel">
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'center',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div style={{ flex: 1, minWidth: 220 }}>
            <span className="admin-panel-title">
              Real-Time Engine Observatory
            </span>

            <span className="admin-panel-sub">
              Control Plane · engine registry · runtime · health · execution
              telemetry · safety
            </span>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              flexWrap: 'wrap',
            }}
          >
            <span
              className={`admin-badge ${
                streamConnected ? 'good' : 'warn'
              }`}
            >
              <span
                className={`admin-dot ${
                  streamConnected ? 'good' : 'warn'
                }`}
                aria-hidden="true"
              />
              {streamConnected ? 'LIVE STREAM' : 'POLLING FALLBACK'}
            </span>

            {lastLiveEventAt && (
              <span className="muted small">
                Last event {elapsedSince(lastLiveEventAt)}
              </span>
            )}

            <button
              type="button"
              className="admin-page-btn"
              onClick={() => void load(false)}
              disabled={refreshing}
            >
              {refreshing ? 'Refreshing…' : 'Refresh'}
            </button>
          </div>
        </div>

        {error && (
          <div className="admin-error" role="status">
            {error}
          </div>
        )}
      </div>

      {/* =====================================================================
          TOP-LEVEL RUNTIME TILES
          ===================================================================== */}

      <div className="admin-tile-grid">
        <div className="admin-tile">
          <span className="tile-label">Registered Engines</span>
          <span className="tile-value">
            {formatNumber(engineCounts.total)}
          </span>
          <span className="tile-note">
            {formatNumber(registry.length)} registry projections
          </span>
        </div>

        <div className="admin-tile tile-good">
          <span className="tile-label">Healthy</span>
          <span className="tile-value">
            {formatNumber(engineCounts.healthy)}
          </span>
          <span className="tile-note">
            {percent(engineCounts.healthy, engineCounts.total)} of engines
          </span>
        </div>

        <div className="admin-tile tile-brand">
          <span className="tile-label">Running</span>
          <span className="tile-value">
            {formatNumber(engineCounts.running)}
          </span>
          <span className="tile-note">
            currently executing / active
          </span>
        </div>

        <div className="admin-tile">
          <span className="tile-label">Degraded</span>
          <span className="tile-value">
            {formatNumber(engineCounts.degraded)}
          </span>
          <span className="tile-note">
            requires observation
          </span>
        </div>

        <div className="admin-tile tile-danger">
          <span className="tile-label">Failed</span>
          <span className="tile-value">
            {formatNumber(engineCounts.failed)}
          </span>
          <span className="tile-note">
            requires investigation
          </span>
        </div>

        <div className="admin-tile">
          <span className="tile-label">Live Executions</span>
          <span className="tile-value">
            {formatNumber(executionCount)}
          </span>
          <span className="tile-note">
            {executionSuccessRate} success rate
          </span>
        </div>
      </div>

      {/* =====================================================================
          RUNTIME / SAFETY SIGNALS
          ===================================================================== */}

      <div
        className="admin-grid-3"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Execution Runtime
            </span>
            <span className="admin-panel-sub">
              locally observed Control Plane stream
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">Executions started</span>
            <span className="v num">
              {formatNumber(executionCount)}
            </span>

            <span className="k">Completed</span>
            <span className="v num">
              {formatNumber(executionSuccesses)}
            </span>

            <span className="k">Failed</span>
            <span className="v num">
              {formatNumber(executionFailures)}
            </span>

            <span className="k">Success rate</span>
            <span className="v">
              {executionSuccessRate}
            </span>

            <span className="k">Live events</span>
            <span className="v num">
              {formatNumber(liveEvents.length)}
            </span>
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Safety / Fault Signals
            </span>
            <span className="admin-panel-sub">
              current live event buffer
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">Failed events</span>
            <span className="v num">
              {formatNumber(liveFailureCount)}
            </span>

            <span className="k">Warnings</span>
            <span className="v num">
              {formatNumber(liveWarningCount)}
            </span>

            <span className="k">Blocked executions</span>
            <span className="v num">
              {formatNumber(
                Object.values(runtimeStats).reduce(
                  (sum, stats) => sum + stats.blocked,
                  0,
                ),
              )}
            </span>

            <span className="k">Retries</span>
            <span className="v num">
              {formatNumber(
                Object.values(runtimeStats).reduce(
                  (sum, stats) => sum + stats.retries,
                  0,
                ),
              )}
            </span>

            <span className="k">Timeouts</span>
            <span className="v num">
              {formatNumber(
                Object.values(runtimeStats).reduce(
                  (sum, stats) => sum + stats.timeouts,
                  0,
                ),
              )}
            </span>
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Infrastructure Health
            </span>
            <span className="admin-panel-sub">
              latest health-check projection
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">Checks</span>
            <span className="v num">
              {formatNumber(health?.total ?? 0)}
            </span>

            <span className="k">Jobs</span>
            <span className="v num">
              {formatNumber(jobs?.jobs.length ?? 0)}
            </span>

            <span className="k">Feature flags</span>
            <span className="v num">
              {formatNumber(flags?.featureFlags.length ?? 0)}
            </span>

            <span className="k">Inactive engines</span>
            <span className="v num">
              {formatNumber(engineCounts.inactive)}
            </span>

            <span className="k">Snapshot</span>
            <span className="v">
              {refreshing ? 'Refreshing' : 'Current'}
            </span>
          </div>
        </div>
      </div>

      {/* =====================================================================
          FILTER BAR
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div
          className="admin-filters"
          style={{
            display: 'flex',
            gap: 8,
            flexWrap: 'wrap',
            alignItems: 'center',
          }}
        >
          <input
            className="admin-filter-input"
            type="search"
            placeholder="Search engine name, code, type…"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            aria-label="Search engines"
          />

          <div
            role="tablist"
            aria-label="Engine status filter"
            style={{
              display: 'flex',
              gap: 6,
              flexWrap: 'wrap',
            }}
          >
            {(
              [
                'ALL',
                'HEALTHY',
                'DEGRADED',
                'FAILED',
                'RUNNING',
                'INACTIVE',
              ] as MonitorFilter[]
            ).map((item) => (
              <button
                key={item}
                type="button"
                role="tab"
                aria-selected={filter === item}
                className={`admin-page-btn ${
                  filter === item ? 'active' : ''
                }`}
                onClick={() => setFilter(item)}
              >
                {item}
              </button>
            ))}
          </div>

          <span
            className="muted small"
            style={{ marginLeft: 'auto' }}
          >
            Showing {filteredEngines.length} / {productEngines.length}
          </span>
        </div>
      </div>

      {/* =====================================================================
          ENGINE GRID
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Product Engines
          </span>

          <span className="admin-panel-sub">
            system.engine registry · real-time operational state
          </span>
        </div>

        {filteredEngines.length === 0 && (
          <div className="admin-empty">
            No engines match the current filter.
          </div>
        )}

        {filteredEngines.length > 0 && (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns:
                'repeat(auto-fit, minmax(300px, 1fr))',
              gap: 10,
            }}
          >
            {filteredEngines.map((engine) => {
              const level = healthDot(engine.status);
              const runtime = runtimeStats[engine.code];

              const engineLiveEvents = liveEvents.filter(
                (event) =>
                  event.engineCode?.toUpperCase() ===
                  engine.code.toUpperCase(),
              );

              const lastLiveEvent =
                engineLiveEvents[0] ?? null;

              return (
                <button
                  key={engine.id}
                  type="button"
                  className="admin-engine-card"
                  onClick={() => openEngine(engine.code)}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    position: 'relative',
                    minHeight: 160,
                  }}
                >
                  <span
                    className={`admin-dot ${level}`}
                    aria-hidden="true"
                  />

                  <span
                    style={{
                      flex: 1,
                      minWidth: 0,
                    }}
                  >
                    <span className="engine-name">
                      {engine.name}
                    </span>

                    <span className="engine-code">
                      {engine.code}
                    </span>

                    <div className="engine-meta">
                      {engine.engineType}
                      {' · '}
                      status:{' '}
                      {engine.status ?? 'UNKNOWN'}
                      {' · '}
                      {engine.isActive
                        ? 'active'
                        : 'inactive'}
                    </div>

                    <div
                      className="engine-meta"
                      style={{
                        marginTop: 8,
                        display: 'grid',
                        gridTemplateColumns:
                          'repeat(2, minmax(0, 1fr))',
                        gap: 4,
                      }}
                    >
                      <span>
                        Runs:{' '}
                        {formatNumber(
                          runtime?.executions ?? 0,
                        )}
                      </span>

                      <span>
                        Failures:{' '}
                        {formatNumber(
                          runtime?.failures ?? 0,
                        )}
                      </span>

                      <span>
                        Last:{' '}
                        {runtime?.lastExecutionAt
                          ? elapsedSince(
                              runtime.lastExecutionAt,
                            )
                          : '—'}
                      </span>

                      <span>
                        Latency:{' '}
                        {runtime?.lastLatencyMs != null
                          ? `${runtime.lastLatencyMs}ms`
                          : '—'}
                      </span>
                    </div>

                    {lastLiveEvent && (
                      <div
                        className="engine-meta"
                        style={{ marginTop: 8 }}
                      >
                        <strong>
                          LIVE
                        </strong>{' '}
                        {lastLiveEvent.eventType}
                        {' · '}
                        {elapsedSince(
                          lastLiveEvent.occurredAt,
                        )}
                      </div>
                    )}
                  </span>

                  <span className="admin-activity-tag">
                    {engine.versions.length}{' '}
                    {engine.versions.length === 1
                      ? 'version'
                      : 'versions'}
                  </span>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* =====================================================================
          ENGINE GOVERNANCE REGISTRY
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Engine Registry
          </span>

          <span className="admin-panel-sub">
            governance.engine_registry · {registry.length}
          </span>
        </div>

        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Engine</th>
                <th>Type</th>
                <th>Version</th>
                <th>Status</th>
                <th>Runtime</th>
              </tr>
            </thead>

            <tbody>
              {registry.map((entry) => {
                const runtime =
                  runtimeStats[entry.engineCode];

                return (
                  <tr key={entry.engineCode}>
                    <td className="mono">
                      {entry.engineCode}
                    </td>

                    <td>
                      {entry.engineType}
                    </td>

                    <td className="mono">
                      {entry.engineVersion}
                    </td>

                    <td>
                      <span
                        className={`admin-badge ${healthDot(
                          entry.status,
                        )}`}
                      >
                        {healthLabel(entry.status)}
                      </span>
                    </td>

                    <td className="mono">
                      {runtime
                        ? `${runtime.executions} runs · ${runtime.failures} failures`
                        : 'No live telemetry'}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          HEALTH CHECKS
          ===================================================================== */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Health Checks
            </span>

            <span className="admin-panel-sub">
              {health?.total ?? 0} recorded
            </span>
          </div>

          {(health?.checks.length ?? 0) === 0 && (
            <div className="admin-empty">
              No health checks recorded yet.
            </div>
          )}

          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Service</th>
                  <th>Status</th>
                  <th>Latency</th>
                  <th>Checked</th>
                </tr>
              </thead>

              <tbody>
                {(health?.checks ?? [])
                  .slice(0, 25)
                  .map((check) => (
                    <tr key={check.id}>
                      <td className="mono">
                        {check.serviceId}
                      </td>

                      <td>
                        <span
                          className={`admin-badge ${healthDot(
                            check.status,
                          )}`}
                        >
                          {check.status}
                        </span>
                      </td>

                      <td className="num">
                        {check.latencyMs} ms
                      </td>

                      <td className="mono">
                        {safeTime(check.checkedAt)}
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* ===================================================================
            SCHEDULED JOBS
            =================================================================== */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Scheduled Jobs
            </span>

            <span className="admin-panel-sub">
              {jobs?.jobs.length ?? 0} registered
            </span>
          </div>

          {(jobs?.jobs.length ?? 0) === 0 && (
            <div className="admin-empty">
              No scheduled jobs registered.
            </div>
          )}

          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Name</th>
                  <th>Schedule</th>
                  <th>Last run</th>
                </tr>
              </thead>

              <tbody>
                {(jobs?.jobs ?? []).map((job) => (
                  <tr key={job.id}>
                    <td className="mono">
                      {job.code}
                    </td>

                    <td>
                      {job.name}
                    </td>

                    <td className="mono">
                      {job.schedule ?? '—'}
                    </td>

                    <td className="mono">
                      {job.lastRunAt
                        ? safeDate(job.lastRunAt)
                        : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* =====================================================================
          FEATURE FLAGS
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Feature Flags
          </span>

          <span className="admin-panel-sub">
            {flags?.featureFlags.length ?? 0} registered
          </span>
        </div>

        {(flags?.featureFlags.length ?? 0) === 0 && (
          <div className="admin-empty">
            No feature flags registered.
          </div>
        )}

        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Code</th>
                <th>Enabled</th>
                <th>Environment</th>
              </tr>
            </thead>

            <tbody>
              {(flags?.featureFlags ?? []).map(
                (flag) => (
                  <tr key={flag.id}>
                    <td className="mono">
                      {flag.code}
                    </td>

                    <td>
                      <span
                        className={`admin-badge ${
                          flag.enabled
                            ? 'good'
                            : 'idle'
                        }`}
                      >
                        {flag.enabled
                          ? 'ON'
                          : 'OFF'}
                      </span>
                    </td>

                    <td className="mono">
                      {flag.environment}
                    </td>
                  </tr>
                ),
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          LIVE ENGINE EVENT BUS
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Live Engine Event Bus
          </span>

          <span className="admin-panel-sub">
            {liveEvents.length} recent engine events · newest first
          </span>
        </div>

        {liveEvents.length === 0 && (
          <div className="admin-empty">
            Waiting for engine events…
          </div>
        )}

        {liveEvents.length > 0 && (
          <div className="admin-activity">
            {liveEvents.slice(0, 30).map((event) => {
              const level = eventLevel(
                event.eventType,
              );

              return (
                <div
                  key={String(event.id)}
                  className={`admin-activity-item ${
                    level === 'bad'
                      ? 'fail'
                      : level === 'warn'
                        ? 'warn'
                        : ''
                  }`}
                >
                  <span
                    className={`admin-dot ${level}`}
                    aria-hidden="true"
                  />

                  <span className="admin-activity-time">
                    {safeTime(event.occurredAt)}
                  </span>

                  <span className="admin-activity-type">
                    {event.eventType}
                  </span>

                  <span className="admin-activity-meta">
                    {event.engineCode ?? 'UNKNOWN ENGINE'}
                  </span>

                  {event.status && (
                    <span className="admin-activity-meta">
                      status:{' '}
                      {event.status}
                    </span>
                  )}

                  {event.latencyMs != null && (
                    <span className="admin-activity-meta">
                      {event.latencyMs}ms
                    </span>
                  )}

                  {event.encounterId && (
                    <span className="admin-activity-meta">
                      ENC-
                      {event.encounterId
                        .slice(0, 8)
                        .toUpperCase()}
                    </span>
                  )}

                  <span className="admin-activity-tag">
                    {formatEventId(event.id)}
                  </span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* =====================================================================
          ENGINE DETAIL DRAWER
          ===================================================================== */}

      {selectedCode !== null && (
        <div
          className="admin-drawer-backdrop"
          onClick={closeEngine}
        >
          <div
            className="admin-drawer"
            onClick={(event) =>
              event.stopPropagation()
            }
            role="dialog"
            aria-modal="true"
            aria-label={`Engine ${selectedCode} detail`}
          >
            {/* ===============================================================
                DRAWER HEADER
                =============================================================== */}

            <div className="admin-drawer-head">
              <div>
                <span className="admin-drawer-title">
                  {selectedCode}
                </span>

                {selected && (
                  <span
                    className="admin-panel-sub"
                    style={{
                      display: 'block',
                      marginTop: 3,
                    }}
                  >
                    {selected.name}
                  </span>
                )}
              </div>

              <button
                type="button"
                className="admin-drawer-close"
                onClick={closeEngine}
                aria-label="Close engine detail"
              >
                ✕
              </button>
            </div>

            {/* ===============================================================
                DRAWER BODY
                =============================================================== */}

            <div className="admin-drawer-body">
              {detailLoading && (
                <div className="admin-loading">
                  <span
                    className="admin-spinner"
                    aria-hidden="true"
                  />
                  Loading engine detail…
                </div>
              )}

              {detailError && !detailLoading && (
                <div
                  className="admin-error"
                  role="alert"
                >
                  {detailError}

                  <button
                    type="button"
                    className="admin-page-btn"
                    style={{ marginTop: 8 }}
                    onClick={() =>
                      void loadEngineDetail(
                        selectedCode,
                      )
                    }
                  >
                    Retry
                  </button>
                </div>
              )}

              {!detailLoading &&
                !detailError &&
                !selected && (
                  <div className="admin-error">
                    Engine not found.
                  </div>
                )}

              {!detailLoading &&
                !detailError &&
                selected && (
                  <>
                    {/* =======================================================
                        ENGINE IDENTITY
                        ======================================================= */}

                    <div className="admin-panel">
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Engine Identity
                        </span>
                      </div>

                      <div className="admin-kv">
                        <span className="k">
                          Name
                        </span>
                        <span className="v">
                          {selected.name}
                        </span>

                        <span className="k">
                          Code
                        </span>
                        <span className="v mono">
                          {selected.code}
                        </span>

                        <span className="k">
                          Type
                        </span>
                        <span className="v">
                          {selected.engineType}
                        </span>

                        <span className="k">
                          Status
                        </span>
                        <span className="v">
                          <span
                            className={`admin-badge ${healthDot(
                              selected.status,
                            )}`}
                          >
                            {healthLabel(
                              selected.status,
                            )}
                          </span>
                        </span>

                        <span className="k">
                          Active
                        </span>
                        <span className="v">
                          {selected.isActive
                            ? 'yes'
                            : 'no'}
                        </span>

                        <span className="k">
                          Last run
                        </span>
                        <span className="v mono">
                          {selected.lastRun
                            ? `${formatEventId(
                                selected.lastRun
                                  .eventId,
                              )} ${
                                selected.lastRun
                                  .eventType
                              }`
                            : '—'}
                        </span>
                      </div>
                    </div>

                    {/* =======================================================
                        LIVE TELEMETRY
                        ======================================================= */}

                    <div
                      className="admin-panel"
                      style={{ marginTop: 12 }}
                    >
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Live Telemetry
                        </span>

                        <span className="admin-panel-sub">
                          observed in this browser session
                        </span>
                      </div>

                      {(() => {
                        const runtime =
                          runtimeStats[
                            selected.code
                          ];

                        const selectedEvents =
                          liveEvents.filter(
                            (event) =>
                              event.engineCode?.toUpperCase() ===
                              selected.code.toUpperCase(),
                          );

                        return (
                          <div className="admin-kv">
                            <span className="k">
                              Executions
                            </span>
                            <span className="v num">
                              {runtime
                                ? formatNumber(
                                    runtime.executions,
                                  )
                                : '0'}
                            </span>

                            <span className="k">
                              Successful
                            </span>
                            <span className="v num">
                              {runtime
                                ? formatNumber(
                                    runtime.successes,
                                  )
                                : '0'}
                            </span>

                            <span className="k">
                              Failed
                            </span>
                            <span className="v num">
                              {runtime
                                ? formatNumber(
                                    runtime.failures,
                                  )
                                : '0'}
                            </span>

                            <span className="k">
                              Blocked
                            </span>
                            <span className="v num">
                              {runtime
                                ? formatNumber(
                                    runtime.blocked,
                                  )
                                : '0'}
                            </span>

                            <span className="k">
                              Retries
                            </span>
                            <span className="v num">
                              {runtime
                                ? formatNumber(
                                    runtime.retries,
                                  )
                                : '0'}
                            </span>

                            <span className="k">
                              Timeouts
                            </span>
                            <span className="v num">
                              {runtime
                                ? formatNumber(
                                    runtime.timeouts,
                                  )
                                : '0'}
                            </span>

                            <span className="k">
                              Last latency
                            </span>
                            <span className="v">
                              {runtime?.lastLatencyMs !=
                              null
                                ? `${runtime.lastLatencyMs} ms`
                                : '—'}
                            </span>

                            <span className="k">
                              Live events
                            </span>
                            <span className="v num">
                              {formatNumber(
                                selectedEvents.length,
                              )}
                            </span>
                          </div>
                        );
                      })()}
                    </div>

                    {/* =======================================================
                        VERSION HISTORY
                        ======================================================= */}

                    <div
                      className="admin-panel"
                      style={{ marginTop: 12 }}
                    >
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Version History
                        </span>

                        <span className="admin-panel-sub">
                          immutable release projection
                        </span>
                      </div>

                      <div className="admin-table-wrap">
                        <table className="admin-table">
                          <thead>
                            <tr>
                              <th>
                                Version
                              </th>
                              <th>
                                Released
                              </th>
                            </tr>
                          </thead>

                          <tbody>
                            {selected.versions.map(
                              (version) => (
                                <tr
                                  key={
                                    version.id
                                  }
                                >
                                  <td className="mono">
                                    {
                                      version.version
                                    }
                                  </td>

                                  <td className="mono">
                                    {version.releasedAt
                                      ? safeDate(
                                          version.releasedAt,
                                        )
                                      : '—'}
                                  </td>
                                </tr>
                              ),
                            )}
                          </tbody>
                        </table>
                      </div>
                    </div>

                    {/* =======================================================
                        SELECTED ENGINE EVENT STREAM
                        ======================================================= */}

                    <div
                      className="admin-panel"
                      style={{ marginTop: 12 }}
                    >
                      <div className="admin-panel-head">
                        <span className="admin-panel-title">
                          Engine Event Stream
                        </span>

                        <span className="admin-panel-sub">
                          latest events
                        </span>
                      </div>

                      {liveEvents.filter(
                        (event) =>
                          event.engineCode?.toUpperCase() ===
                          selected.code.toUpperCase(),
                      ).length === 0 && (
                        <div className="admin-empty">
                          No live events received
                          for this engine.
                        </div>
                      )}

                      <div className="admin-activity">
                        {liveEvents
                          .filter(
                            (event) =>
                              event.engineCode?.toUpperCase() ===
                              selected.code.toUpperCase(),
                          )
                          .slice(0, 25)
                          .map((event) => {
                            const level =
                              eventLevel(
                                event.eventType,
                              );

                            return (
                              <div
                                key={String(
                                  event.id,
                                )}
                                className="admin-activity-item"
                              >
                                <span
                                  className={`admin-dot ${level}`}
                                  aria-hidden="true"
                                />

                                <span className="admin-activity-time">
                                  {safeTime(
                                    event.occurredAt,
                                  )}
                                </span>

                                <span className="admin-activity-type">
                                  {
                                    event.eventType
                                  }
                                </span>

                                {event.status && (
                                  <span className="admin-activity-meta">
                                    {
                                      event.status
                                    }
                                  </span>
                                )}

                                {event.latencyMs !=
                                  null && (
                                  <span className="admin-activity-meta">
                                    {
                                      event.latencyMs
                                    }
                                    ms
                                  </span>
                                )}

                                <span className="admin-activity-tag">
                                  {formatEventId(
                                    event.id,
                                  )}
                                </span>
                              </div>
                            );
                          })}
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