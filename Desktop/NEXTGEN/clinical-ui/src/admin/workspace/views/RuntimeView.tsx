// =============================================================================
// AMEXAN Runtime Control Plane — REALTIME ENGINE
// =============================================================================
// Purpose:
// - Live CPU execution monitoring
// - Live processing / DLQ monitoring
// - Live worker checkpoint monitoring
// - Automatic high-frequency refresh
// - Immediate refresh after tab becomes visible
// - Preserves current API/types contract
// - Read-only operational surface
//
// AMEXAN principle:
// Clinical execution is observable end-to-end:
// EVENT → CPU RUN → ENGINE PROCESSING → RECOMMENDATION → ERROR/DLQ
// → WORKER CHECKPOINT
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { getRuntimeOverview } from '../api';

import type {
  CpuRun,
  RuntimeOverview,
} from '../types';

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------

const REFRESH_INTERVAL_MS = 1500;
const ERROR_RETRY_INTERVAL_MS = 3000;
const STALE_AFTER_MS = 5000;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

function formatDate(value: string | number | Date | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return '—';

  return date.toLocaleString();
}

function formatTime(value: string | number | Date | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return '—';

  return date.toLocaleTimeString();
}

function formatDuration(milliseconds: number | null | undefined): string {
  if (milliseconds === null || milliseconds === undefined) return '—';

  if (milliseconds < 1000) {
    return `${milliseconds}ms`;
  }

  if (milliseconds < 60_000) {
    return `${(milliseconds / 1000).toFixed(2)}s`;
  }

  return `${(milliseconds / 60_000).toFixed(2)}m`;
}

function safeString(value: unknown): string {
  if (value === null || value === undefined) return '—';

  if (typeof value === 'string') return value;

  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

// -----------------------------------------------------------------------------
// Status badge
// -----------------------------------------------------------------------------

function RunBadge({ status }: { status: string }) {
  const normalized = String(status ?? '').toLowerCase();

  const cls =
    normalized === 'completed'
      ? 'admin-badge ok'
      : normalized === 'failed'
        ? 'admin-badge bad'
        : normalized === 'running'
          ? 'admin-badge warn'
          : normalized === 'cancelled'
            ? 'admin-badge bad'
            : 'admin-badge';

  return (
    <span className={cls}>
      {status || 'unknown'}
    </span>
  );
}

// -----------------------------------------------------------------------------
// Realtime indicator
// -----------------------------------------------------------------------------

function RealtimeIndicator({
  connected,
  refreshing,
  lastUpdated,
  error,
}: {
  connected: boolean;
  refreshing: boolean;
  lastUpdated: number | null;
  error: string | null;
}) {
  const stale =
    lastUpdated !== null &&
    Date.now() - lastUpdated > STALE_AFTER_MS;

  const healthy = connected && !error && !stale;

  return (
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
          healthy
            ? 'ok'
            : error || stale
              ? 'bad'
              : 'warn'
        }`}
      >
        <span
          aria-hidden="true"
          style={{
            display: 'inline-block',
            width: 7,
            height: 7,
            borderRadius: '50%',
            marginRight: 6,
            background: 'currentColor',
          }}
        />
        {healthy
          ? 'LIVE'
          : error
            ? 'ERROR'
            : stale
              ? 'STALE'
              : 'CONNECTING'}
      </span>

      {refreshing && (
        <span className="muted small">
          synchronizing…
        </span>
      )}

      {lastUpdated !== null && (
        <span className="muted small mono">
          updated {formatTime(lastUpdated)}
        </span>
      )}
    </div>
  );
}

// -----------------------------------------------------------------------------
// CPU run row
// -----------------------------------------------------------------------------

function RunRow({
  run,
  expanded,
  onToggle,
}: {
  run: CpuRun;
  expanded: boolean;
  onToggle: () => void;
}) {
  const timings =
    (run.metadata?.engineTimings as
      | {
          stage: string;
          milliseconds: number;
        }[]
      | undefined) ?? [];

  const phase =
    typeof run.metadata?.phase === 'string'
      ? run.metadata.phase
      : undefined;

  const isFailed = run.status === 'failed';
  const isRunning = run.status === 'running';

  return (
    <div
      className={`admin-run-row${
        isFailed ? ' admin-run-failed' : ''
      }${isRunning ? ' admin-run-running' : ''}`}
    >
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        style={{
          width: '100%',
          border: 0,
          background: 'transparent',
          cursor: 'pointer',
          textAlign: 'left',
          padding: 0,
          color: 'inherit',
        }}
      >
        <div
          style={{
            display: 'grid',
            gridTemplateColumns:
              '90px minmax(80px,110px) minmax(100px,1fr) minmax(80px,1fr) 80px 90px 90px 80px 30px',
            gap: 10,
            alignItems: 'center',
            minWidth: 850,
          }}
        >
          <span className="mono">
            {run.id.slice(0, 8)}
          </span>

          <RunBadge status={run.status} />

          <span className="mono">
            {run.triggerType || '—'}
          </span>

          <span>
            {phase || '—'}
          </span>

          <span className="num">
            {formatDuration(run.durationMs)}
          </span>

          <span className="num">
            {run.eventsConsumed} ev
          </span>

          <span className="num">
            {run.rulesEvaluated} rules
          </span>

          <span className="num">
            {run.recommendations} rec
          </span>

          <span
            className="mono"
            aria-hidden="true"
            style={{
              textAlign: 'center',
              fontSize: 16,
            }}
          >
            {expanded ? '−' : '+'}
          </span>
        </div>
      </button>

      {expanded && (
        <div
          className="admin-run-body"
          style={{
            marginTop: 14,
          }}
        >
          <div className="admin-kv">
            <span className="k">Run ID</span>
            <span className="v mono">{run.id}</span>

            <span className="k">Status</span>
            <span className="v">
              <RunBadge status={run.status} />
            </span>

            <span className="k">Trigger</span>
            <span className="v mono">
              {run.triggerType || '—'}
            </span>

            <span className="k">Phase</span>
            <span className="v mono">
              {phase || '—'}
            </span>

            <span className="k">Patient</span>
            <span className="v mono">
              {run.patientId || '—'}
            </span>

            <span className="k">Encounter</span>
            <span className="v mono">
              {run.encounterId || '—'}
            </span>

            <span className="k">Started</span>
            <span className="v mono">
              {formatDate(run.startedAt)}
            </span>

            <span className="k">Completed</span>
            <span className="v mono">
              {formatDate(run.completedAt)}
            </span>

            <span className="k">Duration</span>
            <span className="v num">
              {formatDuration(run.durationMs)}
            </span>

            <span className="k">Events consumed</span>
            <span className="v num">
              {run.eventsConsumed}
            </span>

            <span className="k">Rules evaluated</span>
            <span className="v num">
              {run.rulesEvaluated}
            </span>

            <span className="k">Recommendations</span>
            <span className="v num">
              {run.recommendations}
            </span>
          </div>

          {run.errorMessage && (
            <div
              className="admin-error"
              style={{ marginTop: 12 }}
            >
              <strong>
                {run.errorCode || 'RUNTIME_ERROR'}
              </strong>
              {': '}
              {run.errorMessage}
            </div>
          )}

          {timings.length > 0 && (
            <>
              <h4
                style={{
                  margin: '16px 0 8px',
                  fontSize: '0.85rem',
                }}
              >
                Engine stage timings
              </h4>

              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Stage</th>
                      <th>Milliseconds</th>
                      <th>Relative</th>
                    </tr>
                  </thead>

                  <tbody>
                    {timings.map((timing) => {
                      const total = timings.reduce(
                        (sum, item) =>
                          sum +
                          Number(item.milliseconds || 0),
                        0,
                      );

                      const percentage =
                        total > 0
                          ? (Number(timing.milliseconds || 0) /
                              total) *
                            100
                          : 0;

                      return (
                        <tr key={timing.stage}>
                          <td className="mono">
                            {timing.stage}
                          </td>

                          <td className="num">
                            {timing.milliseconds}ms
                          </td>

                          <td className="num">
                            {percentage.toFixed(1)}%
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </>
          )}

          {run.metadata && (
            <details style={{ marginTop: 14 }}>
              <summary
                style={{
                  cursor: 'pointer',
                  fontSize: '0.82rem',
                }}
              >
                Runtime metadata
              </summary>

              <pre
                style={{
                  marginTop: 8,
                  padding: 12,
                  overflow: 'auto',
                  fontSize: '0.75rem',
                  lineHeight: 1.45,
                  borderRadius: 6,
                }}
              >
                {safeString(run.metadata)}
              </pre>
            </details>
          )}
        </div>
      )}
    </div>
  );
}

// -----------------------------------------------------------------------------
// Processing error
// -----------------------------------------------------------------------------

function ProcessingErrorCard({
  error,
}: {
  error: RuntimeOverview['processingErrors']['items'][number];
}) {
  return (
    <div
      className="admin-error-item"
      style={{
        borderLeft:
          error.retryable
            ? '3px solid currentColor'
            : '3px solid currentColor',
      }}
    >
      <div className="admin-error-item-head">
        <span className="admin-badge bad">
          {error.errorCode}
        </span>

        <span className="num">
          attempt {error.attemptNo}
        </span>

        <span
          className={`admin-badge ${
            error.retryable ? 'warn' : 'bad'
          }`}
        >
          {error.retryable
            ? 'retryable'
            : 'terminal'}
        </span>
      </div>

      <div
        style={{
          marginTop: 7,
          fontWeight: 500,
        }}
      >
        {error.errorMessage}
      </div>

      <div
        className="muted small mono"
        style={{ marginTop: 7 }}
      >
        run {error.runId?.slice(0, 8) ?? '—'}
        {' · '}
        event {error.eventId ?? '—'}
        {' · '}
        {formatDate(error.createdAt)}
      </div>
    </div>
  );
}

// -----------------------------------------------------------------------------
// Main runtime view
// -----------------------------------------------------------------------------

export function RuntimeView() {
  const [data, setData] =
    useState<RuntimeOverview | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [refreshing, setRefreshing] =
    useState(false);

  const [error, setError] =
    useState<string | null>(null);

  const [lastUpdated, setLastUpdated] =
    useState<number | null>(null);

  const [expandedRun, setExpandedRun] =
    useState<string | null>(null);

  const requestInFlight =
    useRef(false);

  const mounted =
    useRef(true);

  // ---------------------------------------------------------------------------
  // Load runtime
  // ---------------------------------------------------------------------------

  const load = useCallback(
    async (background = false) => {
      if (requestInFlight.current) {
        return;
      }

      requestInFlight.current = true;

      if (background) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }

      try {
        const next =
          await getRuntimeOverview();

        if (!mounted.current) {
          return;
        }

        setData(next);
        setError(null);
        setLastUpdated(Date.now());
      } catch (e) {
        if (!mounted.current) {
          return;
        }

        setError(
          e instanceof Error
            ? e.message
            : 'Failed to load runtime overview',
        );
      } finally {
        requestInFlight.current = false;

        if (!mounted.current) {
          return;
        }

        setLoading(false);
        setRefreshing(false);
      }
    },
    [],
  );

  // ---------------------------------------------------------------------------
  // Initial load + realtime polling
  // ---------------------------------------------------------------------------

  useEffect(() => {
    mounted.current = true;

    void load(false);

    let timer: ReturnType<typeof setTimeout>;

    const schedule = () => {
      timer = setTimeout(async () => {
        if (!mounted.current) {
          return;
        }

        if (
          document.visibilityState === 'visible'
        ) {
          await load(true);
        }

        schedule();
      }, error
        ? ERROR_RETRY_INTERVAL_MS
        : REFRESH_INTERVAL_MS);
    };

    schedule();

    return () => {
      mounted.current = false;
      clearTimeout(timer);
    };
  }, [load, error]);

  // ---------------------------------------------------------------------------
  // Immediate refresh when browser tab returns
  // ---------------------------------------------------------------------------

  useEffect(() => {
    const handleVisibility = () => {
      if (
        document.visibilityState === 'visible'
      ) {
        void load(true);
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
  }, [load]);

  // ---------------------------------------------------------------------------
  // Derived runtime data
  // ---------------------------------------------------------------------------

  const stats = data?.runStats;

  const runs = useMemo(
    () => data?.runs ?? [],
    [data?.runs],
  );

  const errors = useMemo(
    () =>
      data?.processingErrors?.items ?? [],
    [data?.processingErrors?.items],
  );

  const checkpoints = useMemo(
    () => data?.checkpoints ?? [],
    [data?.checkpoints],
  );

  const runningRuns = useMemo(
    () =>
      runs.filter(
        (run) => run.status === 'running',
      ).length,
    [runs],
  );

  const failedRuns = useMemo(
    () =>
      runs.filter(
        (run) => run.status === 'failed',
      ).length,
    [runs],
  );

  const completedRuns = useMemo(
    () =>
      runs.filter(
        (run) => run.status === 'completed',
      ).length,
    [runs],
  );

  const retryableErrors = useMemo(
    () =>
      errors.filter(
        (item) => item.retryable,
      ).length,
    [errors],
  );

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Initializing AMEXAN runtime monitor…
      </div>
    );
  }

  // ---------------------------------------------------------------------------
  // Fatal initial error
  // ---------------------------------------------------------------------------

  if (error && !data) {
    return (
      <div>
        <div className="admin-error">
          {error}
        </div>

        <button
          type="button"
          className="admin-page-btn"
          style={{ marginTop: 10 }}
          onClick={() => void load(false)}
        >
          Retry
        </button>
      </div>
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  return (
    <div>
      {/* =====================================================================
          REALTIME HEADER
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginBottom: 16 }}
      >
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              AMEXAN Runtime Control Plane
            </span>

            <span className="admin-panel-sub">
              Live clinical computation, workers,
              processing and DLQ
            </span>
          </div>

          <RealtimeIndicator
            connected={Boolean(data)}
            refreshing={refreshing}
            lastUpdated={lastUpdated}
            error={error}
          />
        </div>

        {error && data && (
          <div
            className="admin-error"
            style={{ marginTop: 10 }}
          >
            Runtime refresh error: {error}
          </div>
        )}
      </div>

      {/* =====================================================================
          PRIMARY RUNTIME KPIs
          ===================================================================== */}

      <div className="admin-tile-grid">
        <div className="admin-tile">
          <span className="admin-tile-value">
            {stats?.total ?? 0}
          </span>

          <span className="admin-tile-label">
            CPU runs
          </span>

          <span className="muted small">
            total executions
          </span>
        </div>

        <div className="admin-tile tile-good">
          <span className="admin-tile-value ok">
            {stats?.completed ??
              completedRuns}
          </span>

          <span className="admin-tile-label">
            Completed
          </span>

          <span className="muted small">
            successful execution
          </span>
        </div>

        <div className="admin-tile tile-brand">
          <span className="admin-tile-value warn">
            {stats?.running ??
              runningRuns}
          </span>

          <span className="admin-tile-label">
            Running now
          </span>

          <span className="muted small">
            active computation
          </span>
        </div>

        <div className="admin-tile tile-danger">
          <span className="admin-tile-value bad">
            {stats?.failed ??
              failedRuns}
          </span>

          <span className="admin-tile-label">
            Failed
          </span>

          <span className="muted small">
            execution failures
          </span>
        </div>

        <div className="admin-tile">
          <span className="admin-tile-value bad">
            {data?.processingErrors?.unresolved ??
              0}
          </span>

          <span className="admin-tile-label">
            Unresolved DLQ
          </span>

          <span className="muted small">
            requires investigation
          </span>
        </div>

        <div className="admin-tile">
          <span className="admin-tile-value">
            {checkpoints.length}
          </span>

          <span className="admin-tile-label">
            Workers
          </span>

          <span className="muted small">
            checkpoint streams
          </span>
        </div>
      </div>

      {/* =====================================================================
          LIVE EXECUTION SUMMARY
          ===================================================================== */}

      <div
        className="admin-grid-3"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Execution State
            </span>

            <span className="admin-panel-sub">
              live
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              Total runs
            </span>

            <span className="v num">
              {stats?.total ?? 0}
            </span>

            <span className="k">
              Running
            </span>

            <span className="v num">
              {stats?.running ??
                runningRuns}
            </span>

            <span className="k">
              Completed
            </span>

            <span className="v num">
              {stats?.completed ??
                completedRuns}
            </span>

            <span className="k">
              Failed
            </span>

            <span className="v num">
              {stats?.failed ??
                failedRuns}
            </span>
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Dead-Letter State
            </span>

            <span className="admin-panel-sub">
              processing failures
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              Unresolved
            </span>

            <span className="v num">
              {data?.processingErrors
                ?.unresolved ?? 0}
            </span>

            <span className="k">
              Visible errors
            </span>

            <span className="v num">
              {errors.length}
            </span>

            <span className="k">
              Retryable
            </span>

            <span className="v num">
              {retryableErrors}
            </span>

            <span className="k">
              Terminal
            </span>

            <span className="v num">
              {errors.length -
                retryableErrors}
            </span>
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Worker State
            </span>

            <span className="admin-panel-sub">
              consumption
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              Checkpoints
            </span>

            <span className="v num">
              {checkpoints.length}
            </span>

            <span className="k">
              Active runs
            </span>

            <span className="v num">
              {runningRuns}
            </span>

            <span className="k">
              Last synchronization
            </span>

            <span className="v mono">
              {lastUpdated
                ? formatTime(lastUpdated)
                : '—'}
            </span>
          </div>
        </div>
      </div>

      {/* =====================================================================
          CPU RUN STREAM
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              Live CPU Runs
            </span>

            <span className="admin-panel-sub">
              one execution pass per clinical event
            </span>
          </div>

          <span className="admin-badge ok">
            {runs.length} visible
          </span>
        </div>

        {runs.length === 0 && (
          <div className="admin-empty">
            No CPU runs recorded yet.
          </div>
        )}

        {runs.length > 0 && (
          <div
            style={{
              overflowX: 'auto',
            }}
          >
            <div
              style={{
                minWidth: 850,
              }}
            >
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns:
                    '90px minmax(80px,110px) minmax(100px,1fr) minmax(80px,1fr) 80px 90px 90px 80px 30px',
                  gap: 10,
                  padding:
                    '8px 10px',
                  fontSize:
                    '0.72rem',
                  textTransform:
                    'uppercase',
                  letterSpacing:
                    '0.04em',
                  opacity: 0.65,
                  fontWeight: 600,
                }}
              >
                <span>Run</span>
                <span>Status</span>
                <span>Trigger</span>
                <span>Phase</span>
                <span>Duration</span>
                <span>Events</span>
                <span>Rules</span>
                <span>Rec.</span>
                <span />
              </div>

              {runs.map((run) => (
                <RunRow
                  key={run.id}
                  run={run}
                  expanded={
                    expandedRun === run.id
                  }
                  onToggle={() =>
                    setExpandedRun(
                      (current) =>
                        current === run.id
                          ? null
                          : run.id,
                    )
                  }
                />
              ))}
            </div>
          </div>
        )}
      </div>

      {/* =====================================================================
          PROCESSING + WORKERS
          ===================================================================== */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        {/* -------------------------------------------------------------------
            PROCESSING ERRORS
            ------------------------------------------------------------------- */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">
                Processing Errors
              </span>

              <span className="admin-panel-sub">
                dead-letter / failure surface
              </span>
            </div>

            {errors.length > 0 && (
              <span className="admin-badge bad">
                {errors.length}
              </span>
            )}
          </div>

          {errors.length === 0 && (
            <div className="admin-empty">
              No processing errors detected.
            </div>
          )}

          {errors.map((item) => (
            <ProcessingErrorCard
              key={item.id}
              error={item}
            />
          ))}
        </div>

        {/* -------------------------------------------------------------------
            WORKER CHECKPOINTS
            ------------------------------------------------------------------- */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">
                Worker Checkpoints
              </span>

              <span className="admin-panel-sub">
                event consumption progress
              </span>
            </div>

            <span className="admin-badge ok">
              live
            </span>
          </div>

          {checkpoints.length === 0 && (
            <div className="admin-empty">
              No worker checkpoints.
            </div>
          )}

          {checkpoints.length > 0 && (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Worker</th>
                    <th>Last event</th>
                    <th>Lease owner</th>
                    <th>Updated</th>
                  </tr>
                </thead>

                <tbody>
                  {checkpoints.map(
                    (checkpoint) => (
                      <tr
                        key={
                          checkpoint.workerCode
                        }
                      >
                        <td className="mono">
                          {
                            checkpoint.workerCode
                          }
                        </td>

                        <td className="num">
                          {
                            checkpoint.lastEventId ??
                            '—'
                          }
                        </td>

                        <td className="mono">
                          {
                            checkpoint.leaseOwner ??
                            '—'
                          }
                        </td>

                        <td className="mono">
                          {formatDate(
                            checkpoint.updatedAt,
                          )}
                        </td>
                      </tr>
                    ),
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* =====================================================================
          LIVE FOOTER
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{
          marginTop: 16,
          opacity: 0.9,
        }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent:
              'space-between',
            alignItems: 'center',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div>
            <strong>
              AMEXAN Runtime Monitor
            </strong>

            <div className="muted small">
              EVENT → CPU → ENGINE → RULES →
              RECOMMENDATION → AUDIT
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
            }}
          >
            <span
              className={`admin-badge ${
                error
                  ? 'bad'
                  : refreshing
                    ? 'warn'
                    : 'ok'
              }`}
            >
              {error
                ? 'SYNC ERROR'
                : refreshing
                  ? 'SYNCING'
                  : 'RUNTIME LIVE'}
            </span>

            <span className="muted small mono">
              {lastUpdated
                ? `poll ${REFRESH_INTERVAL_MS}ms`
                : 'initializing'}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}