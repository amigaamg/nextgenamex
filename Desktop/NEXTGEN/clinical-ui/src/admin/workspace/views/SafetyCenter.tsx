// =============================================================================
// AMEXAN Safety Center
// =============================================================================
// PURPOSE
// -----------------------------------------------------------------------------
// Clinical safety observability surface for the AMEXAN Control Plane.
//
// SAFETY PRINCIPLES
// -----------------------------------------------------------------------------
// 1. READ-ONLY — this component never acknowledges, resolves, overrides,
//    dismisses, modifies, or otherwise mutates a clinical safety signal.
//
// 2. FAIL-SAFE DISPLAY — failure to load audit data must not hide an available
//    safety block, and failure to load the safety block must never be replaced
//    with fabricated "zero" safety data.
//
// 3. REAL-TIME OBSERVABILITY — refreshes frequently while preserving the last
//    known-good snapshot during transient failures.
//
// 4. NO CLINICAL DECISION-MAKING — this screen displays signals produced by
//    AMEXAN. It does not diagnose, reprioritize, suppress, or reinterpret them.
//
// 5. SEVERITY IS DISPLAYED AS RECEIVED — severity normalization is only used
//    for presentation styling. The underlying clinical value is never changed.
//
// 6. NO SENSITIVE PAYLOAD EXPANSION — only fields explicitly supplied by the
//    API contract are rendered.
//
// 7. ACCESSIBILITY — alerts, severity, refresh state, and errors are exposed
//    to assistive technologies.
//
// 8. STALE-DATA VISIBILITY — if a refresh fails after a successful load, the
//    last known-good data remains visible while the stale/error state is shown.
//
// 9. RACE-SAFE REFRESH — overlapping refreshes cannot allow an older response
//    to overwrite a newer response.
//
// 10. UNMOUNT-SAFE — asynchronous refreshes cannot update state after the
//     component has been unmounted.
//
// =============================================================================

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { getAuditEvents, getObservatory } from '../api';
import type {
  AuditEvent,
  ObservatoryAlert,
  ObservatorySummary,
} from '../types';
import { formatEventTime } from '../events';

// =============================================================================
// CONFIGURATION
// =============================================================================

const SAFETY_REFRESH_INTERVAL_MS = 5_000;
const AUDIT_EVENT_LIMIT = 100;
const MAX_VISIBLE_ALERTS = 100;
const MAX_VISIBLE_AUDIT_EVENTS = 100;

// =============================================================================
// TYPES
// =============================================================================

type RefreshState = 'idle' | 'loading' | 'refreshing' | 'error';

interface SafetySnapshot {
  observatory: ObservatorySummary;
  audit: AuditEvent[];
  receivedAt: number;
}

// =============================================================================
// HELPERS
// =============================================================================

function safeString(value: unknown): string {
  if (value === null || value === undefined) return '';
  return String(value);
}

function displayValue(value: unknown, fallback = '—'): string {
  const text = safeString(value).trim();
  return text || fallback;
}

function formatCount(value: unknown): string {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return '0';
  }

  return new Intl.NumberFormat().format(value);
}

function severityClass(severity: unknown): string {
  const normalized = safeString(severity).trim().toUpperCase();

  switch (normalized) {
    case 'CRITICAL':
    case 'EMERGENCY':
      return 'bad';

    case 'HIGH':
    case 'URGENT':
      return 'warn';

    case 'MEDIUM':
      return 'warn';

    case 'LOW':
    case 'INFO':
    case 'INFORMATIONAL':
      return 'idle';

    default:
      return 'idle';
  }
}

function severityRank(severity: unknown): number {
  const normalized = safeString(severity).trim().toUpperCase();

  switch (normalized) {
    case 'CRITICAL':
    case 'EMERGENCY':
      return 4;

    case 'HIGH':
    case 'URGENT':
      return 3;

    case 'MEDIUM':
      return 2;

    case 'LOW':
    case 'INFO':
    case 'INFORMATIONAL':
      return 1;

    default:
      return 0;
  }
}

function severityBadge(severity: unknown): string {
  return `admin-badge ${severityClass(severity)}`;
}

function safeDateTime(value: unknown): string {
  if (!value) return '—';

  const date = new Date(String(value));

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleString();
}

function safeEventTime(value: unknown): string {
  if (!value) return '—';

  try {
    return formatEventTime(String(value));
  } catch {
    return safeDateTime(value);
  }
}

function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }

  if (typeof error === 'string' && error.trim()) {
    return error;
  }

  return fallback;
}

// =============================================================================
// SAFE NUMERIC ACCESS
// =============================================================================

function numeric(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

// =============================================================================
// STATUS COMPONENTS
// =============================================================================

function RefreshIndicator({
  state,
  lastUpdated,
}: {
  state: RefreshState;
  lastUpdated: number | null;
}) {
  const refreshing = state === 'loading' || state === 'refreshing';

  return (
    <div
      className="admin-refresh-state"
      aria-live="polite"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        flexWrap: 'wrap',
      }}
    >
      {refreshing && (
        <>
          <span
            className="admin-spinner"
            aria-hidden="true"
            style={{ width: 14, height: 14 }}
          />
          <span className="muted small">
            {state === 'loading' ? 'Loading safety data…' : 'Refreshing…'}
          </span>
        </>
      )}

      {!refreshing && state !== 'error' && lastUpdated !== null && (
        <span className="muted small">
          Last updated {new Date(lastUpdated).toLocaleTimeString()}
        </span>
      )}

      {state === 'error' && lastUpdated !== null && (
        <span className="admin-badge warn">
          Refresh failed · showing last known data
        </span>
      )}
    </div>
  );
}

// =============================================================================
// SAFETY SUMMARY TILE
// =============================================================================

function SafetyTile({
  label,
  value,
  note,
  variant,
}: {
  label: string;
  value: number;
  note: string;
  variant?: 'danger' | 'warn' | 'brand' | 'default';
}) {
  const className =
    variant === 'danger'
      ? 'admin-tile tile-danger'
      : variant === 'warn'
        ? 'admin-tile tile-warn'
        : variant === 'brand'
          ? 'admin-tile tile-brand'
          : 'admin-tile';

  return (
    <div className={className}>
      <span className="tile-label">{label}</span>
      <span className="tile-value">{formatCount(value)}</span>
      <span className="tile-note">{note}</span>
    </div>
  );
}

// =============================================================================
// RECENT ALERT ROW
// =============================================================================

function SafetyAlertRow({
  alert,
}: {
  alert: ObservatoryAlert;
}) {
  const severity = displayValue(alert.severity, 'unknown');

  return (
    <div
      className="admin-activity-item"
      role="article"
      aria-label={`${severity} safety alert`}
    >
      <span className="admin-activity-time">
        {safeEventTime(alert.createdAt)}
      </span>

      <span className={severityBadge(severity)}>
        {severity}
      </span>

      <span
        style={{
          flex: 1,
          minWidth: 0,
          display: 'flex',
          flexDirection: 'column',
          gap: 3,
        }}
      >
        <strong
          style={{
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
          title={displayValue(alert.title)}
        >
          {displayValue(alert.title, 'Clinical safety alert')}
        </strong>

        {alert.message && (
          <span
            className="admin-activity-meta"
            style={{
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
            title={safeString(alert.message)}
          >
            {safeString(alert.message)}
          </span>
        )}
      </span>

      <span className="admin-activity-tag mono">
        {displayValue(alert.alertCode)}
      </span>
    </div>
  );
}

// =============================================================================
// AUDIT ROW
// =============================================================================

function AuditRow({
  event,
}: {
  event: AuditEvent;
}) {
  const eventType = displayValue(event.eventType, 'unknown');

  return (
    <div className="admin-activity-item" role="article">
      <span className="admin-activity-time">
        {safeEventTime(event.occurredAt)}
      </span>

      <span className="admin-activity-type mono">
        {eventType}
      </span>

      <span className="admin-activity-meta">
        {displayValue(event.actorType)}
        {event.entityType ? ` · ${event.entityType}` : ''}
        {event.actorCode ? ` · ${event.actorCode}` : ''}
      </span>
    </div>
  );
}

// =============================================================================
// ALERT SORTING
// =============================================================================

function sortAlerts(alerts: ObservatoryAlert[]): ObservatoryAlert[] {
  return [...alerts].sort((a, b) => {
    const severityDifference =
      severityRank(b.severity) - severityRank(a.severity);

    if (severityDifference !== 0) {
      return severityDifference;
    }

    const aTime = new Date(String(a.createdAt)).getTime();
    const bTime = new Date(String(b.createdAt)).getTime();

    const safeATime = Number.isFinite(aTime) ? aTime : 0;
    const safeBTime = Number.isFinite(bTime) ? bTime : 0;

    return safeBTime - safeATime;
  });
}

// =============================================================================
// SAFETY CENTER
// =============================================================================

export function SafetyCenter() {
  const [snapshot, setSnapshot] = useState<SafetySnapshot | null>(null);

  const [refreshState, setRefreshState] =
    useState<RefreshState>('loading');

  const [error, setError] = useState<string | null>(null);

  const mountedRef = useRef(true);
  const refreshSequenceRef = useRef(0);
  const refreshingRef = useRef(false);

  // ===========================================================================
  // MOUNT / UNMOUNT
  // ===========================================================================

  useEffect(() => {
    mountedRef.current = true;

    return () => {
      mountedRef.current = false;
    };
  }, []);

  // ===========================================================================
  // LOAD
  // ===========================================================================

  const load = useCallback(async () => {
    // Prevent overlapping polling requests.
    if (refreshingRef.current) {
      return;
    }

    refreshingRef.current = true;

    const requestSequence = ++refreshSequenceRef.current;
    const hasExistingSnapshot = snapshot !== null;

    if (mountedRef.current) {
      setRefreshState(hasExistingSnapshot ? 'refreshing' : 'loading');
      setError(null);
    }

    try {
      // Safety and audit data are intentionally fetched independently.
      //
      // This means an audit failure does NOT make the clinical safety block
      // disappear, and a safety failure does NOT make the audit stream appear
      // as though it represents a healthy safety state.
      const [observatoryResult, auditResult] = await Promise.allSettled([
        getObservatory(),
        getAuditEvents({ limit: AUDIT_EVENT_LIMIT }),
      ]);

      if (!mountedRef.current) {
        return;
      }

      // Ignore stale responses.
      if (requestSequence !== refreshSequenceRef.current) {
        return;
      }

      const previous = snapshot;

      // -----------------------------------------------------------------------
      // Observatory
      // -----------------------------------------------------------------------

      let nextObservatory: ObservatorySummary | null = null;

      if (observatoryResult.status === 'fulfilled') {
        nextObservatory = observatoryResult.value;
      } else {
        nextObservatory = previous?.observatory ?? null;
      }

      // -----------------------------------------------------------------------
      // Audit
      // -----------------------------------------------------------------------

      let nextAudit: AuditEvent[] | null = null;

      if (auditResult.status === 'fulfilled') {
        nextAudit = auditResult.value.events ?? [];
      } else {
        nextAudit = previous?.audit ?? null;
      }

      // -----------------------------------------------------------------------
      // No safety data available
      // -----------------------------------------------------------------------

      if (!nextObservatory) {
        const observatoryError =
          observatoryResult.status === 'rejected'
            ? getErrorMessage(
                observatoryResult.reason,
                'Failed to load clinical safety data',
              )
            : 'Clinical safety data is unavailable';

        setError(observatoryError);
        setRefreshState('error');

        return;
      }

      // -----------------------------------------------------------------------
      // Preserve audit snapshot if audit endpoint failed.
      // -----------------------------------------------------------------------

      const finalAudit = nextAudit ?? [];

      setSnapshot({
        observatory: nextObservatory,
        audit: finalAudit,
        receivedAt: Date.now(),
      });

      // -----------------------------------------------------------------------
      // Partial failure
      // -----------------------------------------------------------------------

      if (
        observatoryResult.status === 'rejected' ||
        auditResult.status === 'rejected'
      ) {
        const failures: string[] = [];

        if (observatoryResult.status === 'rejected') {
          failures.push('safety data');
        }

        if (auditResult.status === 'rejected') {
          failures.push('audit stream');
        }

        setError(
          `Unable to refresh ${failures.join(
            ' and ',
          )}. Last known data is being displayed.`,
        );

        setRefreshState('error');
      } else {
        setError(null);
        setRefreshState('idle');
      }
    } catch (e) {
      if (!mountedRef.current) {
        return;
      }

      if (requestSequence !== refreshSequenceRef.current) {
        return;
      }

      setError(
        getErrorMessage(
          e,
          'Failed to refresh safety center',
        ),
      );

      setRefreshState('error');
    } finally {
      refreshingRef.current = false;
    }
  }, [snapshot]);

  // ===========================================================================
  // INITIAL LOAD + REAL-TIME POLLING
  // ===========================================================================

  useEffect(() => {
    void load();

    const timer = window.setInterval(() => {
      void load();
    }, SAFETY_REFRESH_INTERVAL_MS);

    return () => {
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // VISIBILITY-AWARE REFRESH
  // ===========================================================================
  //
  // When the administrator returns to the browser tab, immediately refresh
  // rather than waiting for the next polling interval.
  //
  // This does not replace the polling mechanism.
  //

  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        void load();
      }
    };

    document.addEventListener(
      'visibilitychange',
      handleVisibilityChange,
    );

    return () => {
      document.removeEventListener(
        'visibilitychange',
        handleVisibilityChange,
      );
    };
  }, [load]);

  // ===========================================================================
  // DERIVED SAFETY DATA
  // ===========================================================================

  const observatory = snapshot?.observatory ?? null;
  const audit = snapshot?.audit ?? [];

  const safety = observatory?.safety;

  const openAlerts = numeric(safety?.openAlerts);
  const critical = numeric(safety?.criticalAlerts);
  const high = numeric(safety?.highAlerts);
  const acknowledged = numeric(safety?.acknowledgedAlerts);

  const overrides = numeric(
    observatory?.clinicianBehaviour?.overrides,
  );

  const recentAlerts = useMemo(() => {
    const alerts = safety?.recentAlerts ?? [];

    return sortAlerts(alerts).slice(
      0,
      MAX_VISIBLE_ALERTS,
    );
  }, [safety?.recentAlerts]);

  const recentAudit = useMemo(() => {
    return audit.slice(
      0,
      MAX_VISIBLE_AUDIT_EVENTS,
    );
  }, [audit]);

  // ===========================================================================
  // INITIAL LOADING STATE
  // ===========================================================================

  if (!snapshot && refreshState === 'loading') {
    return (
      <div
        className="admin-loading"
        role="status"
        aria-live="polite"
      >
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Loading safety center…
      </div>
    );
  }

  // ===========================================================================
  // COMPLETE FAILURE
  // ===========================================================================

  if (!snapshot && refreshState === 'error') {
    return (
      <div
        className="admin-error"
        role="alert"
      >
        {error ?? 'Clinical safety data is unavailable.'}
      </div>
    );
  }

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div>
      {/* =====================================================================
          SAFETY HEADER
          ===================================================================== */}

      <div className="admin-panel">
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'flex-start',
            gap: 12,
          }}
        >
          <div style={{ minWidth: 0 }}>
            <span className="admin-panel-title">
              Safety Center
            </span>

            <span className="admin-panel-sub">
              Clinical safety signals · read-only observability
            </span>
          </div>

          <RefreshIndicator
            state={refreshState}
            lastUpdated={
              snapshot?.receivedAt ?? null
            }
          />
        </div>

        {error && (
          <div
            className="admin-error"
            role="status"
            aria-live="polite"
            style={{ marginTop: 12 }}
          >
            {error}
          </div>
        )}
      </div>

      {/* =====================================================================
          SAFETY METRICS
          ===================================================================== */}

      <div
        className="admin-tile-grid"
        style={{ marginTop: 16 }}
      >
        <SafetyTile
          label="Open Alerts"
          value={openAlerts}
          note="unresolved clinical alerts"
          variant="danger"
        />

        <SafetyTile
          label="Critical"
          value={critical}
          note="require immediate attention"
          variant="danger"
        />

        <SafetyTile
          label="High"
          value={high}
          note="require urgent review"
          variant="warn"
        />

        <SafetyTile
          label="Acknowledged"
          value={acknowledged}
          note="seen by a clinician"
          variant="brand"
        />

        <SafetyTile
          label="Medication Overrides"
          value={overrides}
          note="documented clinician overrides"
        />
      </div>

      {/* =====================================================================
          SAFETY STATUS BANNER
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Clinical Safety Status
          </span>

          <span className="admin-panel-sub">
            current observatory state
          </span>
        </div>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns:
              'repeat(auto-fit, minmax(150px, 1fr))',
            gap: 12,
          }}
        >
          <div className="admin-kv">
            <span className="k">
              Open
            </span>
            <span className="v num">
              {formatCount(openAlerts)}
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              Critical
            </span>
            <span className="v num">
              {formatCount(critical)}
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              High
            </span>
            <span className="v num">
              {formatCount(high)}
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              Acknowledged
            </span>
            <span className="v num">
              {formatCount(acknowledged)}
            </span>
          </div>

          <div className="admin-kv">
            <span className="k">
              Overrides
            </span>
            <span className="v num">
              {formatCount(overrides)}
            </span>
          </div>
        </div>
      </div>

      {/* =====================================================================
          ALERTS + AUDIT
          ===================================================================== */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        {/* ===================================================================
            RECENT SAFETY ALERTS
            =================================================================== */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">
                Recent Safety Alerts
              </span>

              <span className="admin-panel-sub">
                clinical.alert · severity surfaced
              </span>
            </div>

            <span className="admin-badge">
              {formatCount(recentAlerts.length)}
            </span>
          </div>

          {recentAlerts.length === 0 && (
            <div className="admin-empty">
              No safety alerts recorded.
            </div>
          )}

          {recentAlerts.length > 0 && (
            <div
              className="admin-activity"
              aria-label="Recent clinical safety alerts"
            >
              {recentAlerts.map((alert) => (
                <SafetyAlertRow
                  key={alert.id}
                  alert={alert}
                />
              ))}
            </div>
          )}
        </div>

        {/* ===================================================================
            GOVERNANCE AUDIT STREAM
            =================================================================== */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">
                Governance Audit Stream
              </span>

              <span className="admin-panel-sub">
                governance.audit_event · recent
              </span>
            </div>

            <span className="admin-badge">
              {formatCount(recentAudit.length)}
            </span>
          </div>

          {recentAudit.length === 0 && (
            <div className="admin-empty">
              No audit events recorded.
            </div>
          )}

          {recentAudit.length > 0 && (
            <div
              className="admin-activity"
              aria-label="Recent governance audit events"
            >
              {recentAudit.map((event) => (
                <AuditRow
                  key={event.id}
                  event={event}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* =====================================================================
          CRITICAL SAFETY BREAKDOWN
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Safety Signal Breakdown
          </span>

          <span className="admin-panel-sub">
            severity distribution
          </span>
        </div>

        <div className="admin-grid-3">
          <div className="admin-panel">
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Critical
              </span>
            </div>

            <div className="admin-tile-value bad">
              {formatCount(critical)}
            </div>

            <div className="muted small">
              Immediate clinical attention
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                High
              </span>
            </div>

            <div className="admin-tile-value warn">
              {formatCount(high)}
            </div>

            <div className="muted small">
              Urgent clinical review
            </div>
          </div>

          <div className="admin-panel">
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Other / acknowledged
              </span>
            </div>

            <div className="admin-tile-value">
              {formatCount(
                Math.max(
                  0,
                  openAlerts -
                    critical -
                    high,
                ),
              )}
            </div>

            <div className="muted small">
              Remaining safety signals
            </div>
          </div>
        </div>
      </div>

      {/* =====================================================================
          SAFETY ALERT TABLE
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Alert Register
          </span>

          <span className="admin-panel-sub">
            read-only clinical safety projection
          </span>
        </div>

        {recentAlerts.length === 0 ? (
          <div className="admin-empty">
            No safety alerts recorded.
          </div>
        ) : (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Severity</th>
                  <th>Alert</th>
                  <th>Code</th>
                  <th>Message</th>
                </tr>
              </thead>

              <tbody>
                {recentAlerts.map((alert) => {
                  const severity = displayValue(
                    alert.severity,
                    'unknown',
                  );

                  return (
                    <tr key={`table-${alert.id}`}>
                      <td className="mono">
                        {safeDateTime(
                          alert.createdAt,
                        )}
                      </td>

                      <td>
                        <span
                          className={severityBadge(
                            severity,
                          )}
                        >
                          {severity}
                        </span>
                      </td>

                      <td>
                        {displayValue(
                          alert.title,
                          'Clinical safety alert',
                        )}
                      </td>

                      <td className="mono">
                        {displayValue(
                          alert.alertCode,
                        )}
                      </td>

                      <td
                        style={{
                          maxWidth: 360,
                        }}
                        title={safeString(
                          alert.message,
                        )}
                      >
                        {displayValue(
                          alert.message,
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* =====================================================================
          GOVERNANCE AUDIT TABLE
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Governance Audit Register
          </span>

          <span className="admin-panel-sub">
            recent governance events · read-only
          </span>
        </div>

        {recentAudit.length === 0 ? (
          <div className="admin-empty">
            No audit events recorded.
          </div>
        ) : (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Time</th>
                  <th>Event</th>
                  <th>Actor</th>
                  <th>Entity</th>
                  <th>Actor Code</th>
                </tr>
              </thead>

              <tbody>
                {recentAudit.map((event) => (
                  <tr key={`audit-${event.id}`}>
                    <td className="mono">
                      {safeDateTime(
                        event.occurredAt,
                      )}
                    </td>

                    <td className="mono">
                      {displayValue(
                        event.eventType,
                      )}
                    </td>

                    <td>
                      {displayValue(
                        event.actorType,
                      )}
                    </td>

                    <td className="mono">
                      {displayValue(
                        event.entityType,
                      )}
                    </td>

                    <td className="mono">
                      {displayValue(
                        event.actorCode,
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* =====================================================================
          OBSERVABILITY NOTICE
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Safety Observability
          </span>

          <span className="admin-panel-sub">
            platform monitoring state
          </span>
        </div>

        <div className="admin-kv">
          <span className="k">
            Refresh interval
          </span>

          <span className="v mono">
            {SAFETY_REFRESH_INTERVAL_MS / 1000}s
          </span>

          <span className="k">
            Alert records loaded
          </span>

          <span className="v num">
            {formatCount(
              recentAlerts.length,
            )}
          </span>

          <span className="k">
            Audit records loaded
          </span>

          <span className="v num">
            {formatCount(
              recentAudit.length,
            )}
          </span>

          <span className="k">
            Last successful snapshot
          </span>

          <span className="v mono">
            {snapshot
              ? new Date(
                  snapshot.receivedAt,
                ).toLocaleString()
              : '—'}
          </span>

          <span className="k">
            Display mode
          </span>

          <span className="v">
            Read-only
          </span>
        </div>
      </div>
    </div>
  );
}