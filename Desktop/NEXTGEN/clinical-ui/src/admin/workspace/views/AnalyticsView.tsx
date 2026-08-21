// =============================================================================
// AMEXAN Analytics — Operational Intelligence / IMPROVE
//
// READ-ONLY CONTROL-PLANE PROJECTION
//
// PURPOSE
// -----------------------------------------------------------------------------
// This view is the AMEXAN operational intelligence surface.
//
// It observes:
//   • clinical activity
//   • encounter lifecycle
//   • event-bus activity
//   • event failures
//   • alert generation
//   • engine/suggestion activity
//   • clinician/system decision patterns
//   • source distribution
//   • daily event volume
//   • workflow distribution
//
// IMPORTANT
// -----------------------------------------------------------------------------
// The UI NEVER talks directly to PostgreSQL.
// The UI consumes Control Plane API projections only.
//
// Expected flow:
//
//   Clinical UI
//       ↓
//   Application / Clinical Services
//       ↓
//   Event Bus / Event Store
//       ↓
//   Control Plane / Projection Layer
//       ↓
//   getAnalyticsOverview()
//       ↓
//   AnalyticsView
//
// Analytics is observational. It must not silently mutate clinical data,
// configuration, protocols, encounters, events, or engine state.
//
// =============================================================================

import { useCallback, useEffect, useMemo, useState } from 'react';
import { getAnalyticsOverview } from '../api';
import type { AnalyticsOverview } from '../types';

// =============================================================================
// TYPES
// =============================================================================

type AnalyticsSection =
  | 'overview'
  | 'events'
  | 'encounters'
  | 'decisions'
  | 'safety'
  | 'sources';

type RefreshState = 'idle' | 'loading' | 'success' | 'error';

// =============================================================================
// SAFE HELPERS
// =============================================================================

function safeNumber(value: unknown, fallback = 0): number {
  if (typeof value !== 'number') return fallback;
  if (!Number.isFinite(value)) return fallback;
  return value;
}

function formatNumber(value: unknown): string {
  return safeNumber(value).toLocaleString();
}

function percentage(part: number, total: number): number {
  if (!total || total <= 0) return 0;
  return Math.min(100, Math.max(0, (part / total) * 100));
}

function formatPercentage(part: number, total: number): string {
  return `${percentage(part, total).toFixed(1)}%`;
}

function formatDate(value: string): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  });
}

function formatDateTime(value: string | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString();
}

// =============================================================================
// STATUS CLASSIFICATION
// =============================================================================

function statusClass(status: string | undefined): string {
  const normalized = (status ?? '').toLowerCase();

  if (
    normalized.includes('complete') ||
    normalized.includes('closed') ||
    normalized.includes('resolved') ||
    normalized.includes('success')
  ) {
    return 'ok';
  }

  if (
    normalized.includes('fail') ||
    normalized.includes('error') ||
    normalized.includes('critical') ||
    normalized.includes('cancel')
  ) {
    return 'bad';
  }

  if (
    normalized.includes('pending') ||
    normalized.includes('active') ||
    normalized.includes('progress') ||
    normalized.includes('warning')
  ) {
    return 'warn';
  }

  return '';
}

function severityClass(severity: string | undefined): string {
  const normalized = (severity ?? '').toLowerCase();

  if (
    normalized === 'critical' ||
    normalized === 'high' ||
    normalized === 'danger'
  ) {
    return 'bad';
  }

  if (
    normalized === 'medium' ||
    normalized === 'moderate' ||
    normalized === 'warning'
  ) {
    return 'warn';
  }

  if (
    normalized === 'low' ||
    normalized === 'info' ||
    normalized === 'informational'
  ) {
    return 'ok';
  }

  return '';
}

// =============================================================================
// SMALL PRESENTATIONAL COMPONENTS
// =============================================================================

function MetricTile({
  value,
  label,
  detail,
  tone,
}: {
  value: string | number;
  label: string;
  detail?: string;
  tone?: 'default' | 'ok' | 'warn' | 'bad';
}) {
  return (
    <div className="admin-tile">
      <span
        className={`admin-tile-value${
          tone && tone !== 'default' ? ` ${tone}` : ''
        }`}
      >
        {value}
      </span>

      <span className="admin-tile-label">{label}</span>

      {detail && <span className="admin-tile-sub">{detail}</span>}
    </div>
  );
}

function SectionHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="admin-panel-head">
      <div>
        <span className="admin-panel-title">{title}</span>

        {subtitle && (
          <span className="admin-panel-sub">{subtitle}</span>
        )}
      </div>

      {action}
    </div>
  );
}

function EmptyState({ children }: { children: React.ReactNode }) {
  return <div className="admin-empty">{children}</div>;
}

function MiniProgress({
  value,
  max,
}: {
  value: number;
  max: number;
}) {
  const width = percentage(value, max);

  return (
    <div
      className="admin-bar-track"
      aria-label={`${width.toFixed(1)} percent`}
    >
      <div
        className="admin-bar-fill"
        style={{ width: `${width}%` }}
      />
    </div>
  );
}

// =============================================================================
// MAIN COMPONENT
// =============================================================================

export function AnalyticsView() {
  const [data, setData] = useState<AnalyticsOverview | null>(null);

  const [loading, setLoading] = useState(true);

  const [error, setError] = useState<string | null>(null);

  const [refreshState, setRefreshState] =
    useState<RefreshState>('idle');

  const [activeSection, setActiveSection] =
    useState<AnalyticsSection>('overview');

  const [lastUpdated, setLastUpdated] =
    useState<string | null>(null);

  const load = useCallback(async () => {
    setRefreshState('loading');

    setError(null);

    try {
      const result = await getAnalyticsOverview();

      setData(result);

      setLastUpdated(new Date().toISOString());

      setRefreshState('success');
    } catch (e) {
      const message =
        e instanceof Error
          ? e.message
          : 'Failed to load analytics';

      setError(message);

      setRefreshState('error');
    } finally {
      setLoading(false);
    }
  }, []);

  // ===========================================================================
  // INITIAL LOAD
  // ===========================================================================

  useEffect(() => {
    void load();
  }, [load]);

  // ===========================================================================
  // AUTO REFRESH
  // ===========================================================================
  //
  // Analytics is operational telemetry. A slower refresh interval prevents
  // unnecessary pressure on the Control Plane while keeping the workspace
  // reasonably current.
  //
  // ===========================================================================

  useEffect(() => {
    const timer = window.setInterval(() => {
      void load();
    }, 60_000);

    return () => {
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // NORMALIZED DATA
  // ===========================================================================

  const encounters = data?.encounters;

  const events = data?.events;

  const alerts = data?.alerts ?? [];

  const suggestions = data?.suggestions ?? [];

  const eventByType = events?.byType ?? [];

  const eventByDay = events?.byDay ?? [];

  const eventBySource = events?.bySource ?? [];

  const encounterByStatus = encounters?.byStatus ?? [];

  // ===========================================================================
  // DERIVED METRICS
  // ===========================================================================

  const totalEncounters =
    safeNumber(encounters?.total);

  const totalEvents =
    safeNumber(events?.total);

  const activePatients =
    safeNumber(events?.patients);

  const failedEvents =
    safeNumber(events?.failed);

  const totalAlerts = useMemo(
    () =>
      alerts.reduce(
        (sum, entry) =>
          sum + safeNumber(entry.count),
        0,
      ),
    [alerts],
  );

  const totalDecisions = useMemo(
    () =>
      suggestions.reduce(
        (sum, entry) =>
          sum + safeNumber(entry.count),
        0,
      ),
    [suggestions],
  );

  const failedEventRate = percentage(
    failedEvents,
    totalEvents,
  );

  const alertRate = percentage(
    totalAlerts,
    totalEvents,
  );

  const decisionRate = percentage(
    totalDecisions,
    totalEvents,
  );

  const maxByType = useMemo(
    () =>
      Math.max(
        1,
        ...eventByType.map((entry) =>
          safeNumber(entry.count),
        ),
      ),
    [eventByType],
  );

  const maxByDay = useMemo(
    () =>
      Math.max(
        1,
        ...eventByDay.map((entry) =>
          safeNumber(entry.count),
        ),
      ),
    [eventByDay],
  );

  const maxBySource = useMemo(
    () =>
      Math.max(
        1,
        ...eventBySource.map((entry) =>
          safeNumber(entry.count),
        ),
      ),
    [eventBySource],
  );

  const maxByEncounterStatus = useMemo(
    () =>
      Math.max(
        1,
        ...encounterByStatus.map((entry) =>
          safeNumber(entry.count),
        ),
      ),
    [encounterByStatus],
  );

  const maxByAlertSeverity = useMemo(
    () =>
      Math.max(
        1,
        ...alerts.map((entry) =>
          safeNumber(entry.count),
        ),
      ),
    [alerts],
  );

  // ===========================================================================
  // ERROR / INITIAL LOADING
  // ===========================================================================

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />

        Loading analytics…
      </div>
    );
  }

  if (error && !data) {
    return (
      <div
        className="admin-error"
        role="alert"
      >
        <strong>Analytics unavailable</strong>

        <span>{error}</span>

        <button
          type="button"
          className="admin-button"
          onClick={() => void load()}
        >
          Retry
        </button>
      </div>
    );
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  const sections: {
    id: AnalyticsSection;
    label: string;
  }[] = [
    {
      id: 'overview',
      label: 'Overview',
    },
    {
      id: 'events',
      label: 'Events',
    },
    {
      id: 'encounters',
      label: 'Encounters',
    },
    {
      id: 'decisions',
      label: 'Decisions',
    },
    {
      id: 'safety',
      label: 'Safety',
    },
    {
      id: 'sources',
      label: 'Sources',
    },
  ];

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div className="admin-analytics">
      {/* ================================================================= */}
      {/* HEADER                                                           */}
      {/* ================================================================= */}

      <div className="admin-panel">
        <SectionHeader
          title="AMEXAN Operational Analytics"
          subtitle="Clinical activity · event telemetry · safety · decisions · system behaviour"
          action={
            <button
              type="button"
              className="admin-button"
              onClick={() => void load()}
              disabled={refreshState === 'loading'}
              aria-busy={refreshState === 'loading'}
            >
              {refreshState === 'loading'
                ? 'Refreshing…'
                : 'Refresh'}
            </button>
          }
        />

        <div
          className="admin-activity-meta"
          style={{
            display: 'flex',
            gap: 16,
            flexWrap: 'wrap',
            paddingTop: 10,
          }}
        >
          <span>
            <strong>Control Plane</strong>
          </span>

          <span>
            Telemetry projection
          </span>

          <span>
            Last refreshed:{' '}
            <strong>
              {formatDateTime(lastUpdated ?? undefined)}
            </strong>
          </span>

          {error && (
            <span className="bad">
              Refresh warning: {error}
            </span>
          )}
        </div>
      </div>

      {/* ================================================================= */}
      {/* SECTION NAVIGATION                                               */}
      {/* ================================================================= */}

      <nav
        className="admin-nav"
        aria-label="Analytics sections"
        style={{ marginTop: 16 }}
      >
        {sections.map((section) => (
          <button
            key={section.id}
            type="button"
            className={`admin-nav-btn${
              activeSection === section.id
                ? ' active'
                : ''
            }`}
            onClick={() =>
              setActiveSection(section.id)
            }
          >
            {section.label}
          </button>
        ))}
      </nav>

      {/* ================================================================= */}
      {/* GLOBAL METRICS                                                   */}
      {/* ================================================================= */}

      <div className="admin-tile-grid">
        <MetricTile
          value={formatNumber(totalEncounters)}
          label="Encounters"
          detail="clinical workflow instances"
        />

        <MetricTile
          value={formatNumber(totalEvents)}
          label="Events logged"
          detail="event-bus telemetry"
        />

        <MetricTile
          value={formatNumber(activePatients)}
          label="Patients represented"
          detail="event-linked patient activity"
        />

        <MetricTile
          value={formatNumber(failedEvents)}
          label="Failed events"
          detail={`${failedEventRate.toFixed(1)}% of events`}
          tone={failedEvents > 0 ? 'bad' : 'ok'}
        />

        <MetricTile
          value={formatNumber(totalAlerts)}
          label="Alerts"
          detail={`${alertRate.toFixed(1)}% of events`}
          tone={totalAlerts > 0 ? 'warn' : 'ok'}
        />

        <MetricTile
          value={formatNumber(totalDecisions)}
          label="Decision activity"
          detail={`${decisionRate.toFixed(1)}% of events`}
        />
      </div>

      {/* ================================================================= */}
      {/* OVERVIEW                                                         */}
      {/* ================================================================= */}

      {activeSection === 'overview' && (
        <div>
          {/* ------------------------------------------------------------- */}
          {/* HEALTH SIGNALS                                                */}
          {/* ------------------------------------------------------------- */}

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel">
              <SectionHeader
                title="Operational Health"
                subtitle="Telemetry-derived system signals"
              />

              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Signal</th>
                      <th>Value</th>
                      <th>Interpretation</th>
                    </tr>
                  </thead>

                  <tbody>
                    <tr>
                      <td>Event ingestion</td>

                      <td className="num">
                        {formatNumber(totalEvents)}
                      </td>

                      <td>
                        {totalEvents > 0
                          ? 'Receiving telemetry'
                          : 'No events observed'}
                      </td>
                    </tr>

                    <tr>
                      <td>Event failures</td>

                      <td className="num">
                        {formatNumber(failedEvents)}
                      </td>

                      <td
                        className={
                          failedEvents > 0
                            ? 'bad'
                            : 'ok'
                        }
                      >
                        {failedEvents > 0
                          ? `${failedEventRate.toFixed(
                              1,
                            )}% failure rate`
                          : 'No failures observed'}
                      </td>
                    </tr>

                    <tr>
                      <td>Clinical activity</td>

                      <td className="num">
                        {formatNumber(
                          totalEncounters,
                        )}
                      </td>

                      <td>
                        Encounter activity represented
                      </td>
                    </tr>

                    <tr>
                      <td>Safety signalling</td>

                      <td className="num">
                        {formatNumber(totalAlerts)}
                      </td>

                      <td>
                        {totalAlerts > 0
                          ? 'Alerts require operational awareness'
                          : 'No alerts represented'}
                      </td>
                    </tr>

                    <tr>
                      <td>Decision activity</td>

                      <td className="num">
                        {formatNumber(
                          totalDecisions,
                        )}
                      </td>

                      <td>
                        Suggestions / decision records
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            {/* ----------------------------------------------------------- */}
            {/* EVENT VOLUME                                                */}
            {/* ----------------------------------------------------------- */}

            <div className="admin-panel">
              <SectionHeader
                title="Event Volume"
                subtitle="Recent event-bus activity"
              />

              {eventByDay.length === 0 ? (
                <EmptyState>
                  No daily event telemetry available.
                </EmptyState>
              ) : (
                <div className="admin-bar-list">
                  {eventByDay.map((entry) => {
                    const count =
                      safeNumber(entry.count);

                    return (
                      <div
                        className="admin-bar-row"
                        key={entry.day}
                      >
                        <span className="admin-bar-label mono">
                          {formatDate(entry.day)}
                        </span>

                        <MiniProgress
                          value={count}
                          max={maxByDay}
                        />

                        <span className="admin-bar-value num">
                          {formatNumber(count)}
                        </span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          {/* ------------------------------------------------------------- */}
          {/* TOP EVENT TYPES                                               */}
          {/* ------------------------------------------------------------- */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Event Activity by Type"
              subtitle="Highest-volume event classes"
            />

            {eventByType.length === 0 ? (
              <EmptyState>
                No event type data available.
              </EmptyState>
            ) : (
              <div className="admin-bar-list">
                {eventByType.map((entry) => {
                  const count =
                    safeNumber(entry.count);

                  return (
                    <div
                      className="admin-bar-row"
                      key={entry.eventType}
                    >
                      <span className="admin-bar-label mono">
                        {entry.eventType}
                      </span>

                      <MiniProgress
                        value={count}
                        max={maxByType}
                      />

                      <span className="admin-bar-value num">
                        {formatNumber(count)}
                      </span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* ------------------------------------------------------------- */}
          {/* ENCOUNTER + SAFETY                                           */}
          {/* ------------------------------------------------------------- */}

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel">
              <SectionHeader
                title="Encounter Distribution"
                subtitle="Current encounter lifecycle states"
              />

              {encounterByStatus.length === 0 ? (
                <EmptyState>
                  No encounter data.
                </EmptyState>
              ) : (
                <div className="admin-bar-list">
                  {encounterByStatus.map(
                    (entry) => {
                      const count =
                        safeNumber(entry.count);

                      return (
                        <div
                          className="admin-bar-row"
                          key={entry.status}
                        >
                          <span
                            className={`admin-bar-label mono ${statusClass(
                              entry.status,
                            )}`}
                          >
                            {entry.status}
                          </span>

                          <MiniProgress
                            value={count}
                            max={
                              maxByEncounterStatus
                            }
                          />

                          <span className="admin-bar-value num">
                            {formatNumber(count)}
                          </span>
                        </div>
                      );
                    },
                  )}
                </div>
              )}
            </div>

            <div className="admin-panel">
              <SectionHeader
                title="Alert Severity"
                subtitle="Safety signals represented in telemetry"
              />

              {alerts.length === 0 ? (
                <EmptyState>
                  No alert telemetry available.
                </EmptyState>
              ) : (
                <div className="admin-bar-list">
                  {alerts.map((entry) => {
                    const count =
                      safeNumber(entry.count);

                    return (
                      <div
                        className="admin-bar-row"
                        key={entry.severity}
                      >
                        <span
                          className={`admin-bar-label mono ${severityClass(
                            entry.severity,
                          )}`}
                        >
                          {entry.severity}
                        </span>

                        <MiniProgress
                          value={count}
                          max={
                            maxByAlertSeverity
                          }
                        />

                        <span className="admin-bar-value num">
                          {formatNumber(count)}
                        </span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ================================================================= */}
      {/* EVENTS                                                            */}
      {/* ================================================================= */}

      {activeSection === 'events' && (
        <div>
          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel">
              <SectionHeader
                title="Events by Type"
                subtitle={`Top ${eventByType.length} represented event types`}
              />

              {eventByType.length === 0 ? (
                <EmptyState>
                  No events available.
                </EmptyState>
              ) : (
                <div className="admin-table-wrap">
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>Event type</th>
                        <th>Count</th>
                        <th>Share</th>
                      </tr>
                    </thead>

                    <tbody>
                      {eventByType.map(
                        (entry) => {
                          const count =
                            safeNumber(
                              entry.count,
                            );

                          return (
                            <tr
                              key={
                                entry.eventType
                              }
                            >
                              <td className="mono">
                                {
                                  entry.eventType
                                }
                              </td>

                              <td className="num">
                                {formatNumber(
                                  count,
                                )}
                              </td>

                              <td className="num">
                                {formatPercentage(
                                  count,
                                  totalEvents,
                                )}
                              </td>
                            </tr>
                          );
                        },
                      )}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            <div className="admin-panel">
              <SectionHeader
                title="Event Volume by Day"
                subtitle="Recent event ingestion"
              />

              {eventByDay.length === 0 ? (
                <EmptyState>
                  No daily event data.
                </EmptyState>
              ) : (
                <div className="admin-table-wrap">
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>Day</th>
                        <th>Events</th>
                        <th>Share</th>
                      </tr>
                    </thead>

                    <tbody>
                      {eventByDay.map(
                        (entry) => {
                          const count =
                            safeNumber(
                              entry.count,
                            );

                          return (
                            <tr
                              key={entry.day}
                            >
                              <td className="mono">
                                {formatDate(
                                  entry.day,
                                )}
                              </td>

                              <td className="num">
                                {formatNumber(
                                  count,
                                )}
                              </td>

                              <td className="num">
                                {formatPercentage(
                                  count,
                                  totalEvents,
                                )}
                              </td>
                            </tr>
                          );
                        },
                      )}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Event Failure Signal"
              subtitle="Events that did not complete successfully"
            />

            <div className="admin-tile-grid">
              <MetricTile
                value={formatNumber(
                  totalEvents,
                )}
                label="Total events"
              />

              <MetricTile
                value={formatNumber(
                  failedEvents,
                )}
                label="Failed events"
                tone={
                  failedEvents > 0
                    ? 'bad'
                    : 'ok'
                }
              />

              <MetricTile
                value={`${failedEventRate.toFixed(
                  2,
                )}%`}
                label="Failure rate"
                tone={
                  failedEvents > 0
                    ? 'warn'
                    : 'ok'
                }
              />
            </div>
          </div>
        </div>
      )}

      {/* ================================================================= */}
      {/* ENCOUNTERS                                                        */}
      {/* ================================================================= */}

      {activeSection === 'encounters' && (
        <div
          className="admin-panel"
          style={{ marginTop: 16 }}
        >
          <SectionHeader
            title="Encounters by Status"
            subtitle="Clinical workflow distribution"
          />

          {encounterByStatus.length === 0 ? (
            <EmptyState>
              No encounter data.
            </EmptyState>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Status</th>
                    <th>Count</th>
                    <th>Share</th>
                    <th>Distribution</th>
                  </tr>
                </thead>

                <tbody>
                  {encounterByStatus.map(
                    (entry) => {
                      const count =
                        safeNumber(
                          entry.count,
                        );

                      return (
                        <tr
                          key={entry.status}
                        >
                          <td>
                            <span
                              className={`mono ${statusClass(
                                entry.status,
                              )}`}
                            >
                              {entry.status}
                            </span>
                          </td>

                          <td className="num">
                            {formatNumber(
                              count,
                            )}
                          </td>

                          <td className="num">
                            {formatPercentage(
                              count,
                              totalEncounters,
                            )}
                          </td>

                          <td style={{ minWidth: 180 }}>
                            <MiniProgress
                              value={count}
                              max={
                                maxByEncounterStatus
                              }
                            />
                          </td>
                        </tr>
                      );
                    },
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ================================================================= */}
      {/* DECISIONS                                                         */}
      {/* ================================================================= */}

      {activeSection === 'decisions' && (
        <div>
          <div
            className="admin-tile-grid"
            style={{ marginTop: 16 }}
          >
            <MetricTile
              value={formatNumber(
                totalDecisions,
              )}
              label="Decision / suggestion records"
            />

            <MetricTile
              value={formatPercentage(
                totalDecisions,
                totalEvents,
              )}
              label="Decision activity / events"
            />
          </div>

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Decision Activity"
              subtitle="Suggestion / decision telemetry"
            />

            {suggestions.length === 0 ? (
              <EmptyState>
                No decision telemetry available.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Decision type</th>
                      <th>Count</th>
                      <th>Share</th>
                    </tr>
                  </thead>

                  <tbody>
                    {suggestions.map(
                      (entry, index) => {
                        const count =
                          safeNumber(
                            entry.count,
                          );

                        const type =
                          entry.recommendationType ??
                          `decision-${index + 1}`;

                        return (
                          <tr
                            key={`${type}-${index}`}
                          >
                            <td className="mono">
                              {type}
                            </td>

                            <td className="num">
                              {formatNumber(
                                count,
                              )}
                            </td>

                            <td className="num">
                              {formatPercentage(
                                count,
                                totalDecisions,
                              )}
                            </td>
                          </tr>
                        );
                      },
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Clinical Decision Telemetry"
              subtitle="Observed activity, not an override of clinician authority"
            />

            <div className="admin-grid-2">
              <div>
                <div className="admin-panel-sub">
                  Recorded decision activity
                </div>

                <strong className="admin-tile-value">
                  {formatNumber(
                    totalDecisions,
                  )}
                </strong>
              </div>

              <div>
                <div className="admin-panel-sub">
                  Decision activity relative to events
                </div>

                <strong className="admin-tile-value">
                  {decisionRate.toFixed(1)}%
                </strong>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ================================================================= */}
      {/* SAFETY                                                            */}
      {/* ================================================================= */}

      {activeSection === 'safety' && (
        <div>
          <div
            className="admin-tile-grid"
            style={{ marginTop: 16 }}
          >
            <MetricTile
              value={formatNumber(
                totalAlerts,
              )}
              label="Total alerts"
              tone={
                totalAlerts > 0
                  ? 'warn'
                  : 'ok'
              }
            />

            <MetricTile
              value={`${alertRate.toFixed(
                2,
              )}%`}
              label="Alerts / events"
            />

            <MetricTile
              value={formatNumber(
                failedEvents,
              )}
              label="Failed events"
              tone={
                failedEvents > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={`${failedEventRate.toFixed(
                2,
              )}%`}
              label="Event failure rate"
              tone={
                failedEvents > 0
                  ? 'bad'
                  : 'ok'
              }
            />
          </div>

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Alert Severity Distribution"
              subtitle="Safety telemetry by severity"
            />

            {alerts.length === 0 ? (
              <EmptyState>
                No safety alert telemetry available.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Severity</th>
                      <th>Count</th>
                      <th>Share</th>
                      <th>Distribution</th>
                    </tr>
                  </thead>

                  <tbody>
                    {alerts.map((entry) => {
                      const count =
                        safeNumber(
                          entry.count,
                        );

                      return (
                        <tr
                          key={
                            entry.severity
                          }
                        >
                          <td>
                            <span
                              className={`mono ${severityClass(
                                entry.severity,
                              )}`}
                            >
                              {entry.severity}
                            </span>
                          </td>

                          <td className="num">
                            {formatNumber(
                              count,
                            )}
                          </td>

                          <td className="num">
                            {formatPercentage(
                              count,
                              totalAlerts,
                            )}
                          </td>

                          <td
                            style={{
                              minWidth: 180,
                            }}
                          >
                            <MiniProgress
                              value={count}
                              max={
                                maxByAlertSeverity
                              }
                            />
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Safety Telemetry Interpretation"
              subtitle="Operational visibility"
            />

            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Signal</th>
                    <th>Observed</th>
                    <th>Rate</th>
                  </tr>
                </thead>

                <tbody>
                  <tr>
                    <td>Events</td>

                    <td className="num">
                      {formatNumber(
                        totalEvents,
                      )}
                    </td>

                    <td className="num">
                      100%
                    </td>
                  </tr>

                  <tr>
                    <td>Failed events</td>

                    <td className="num bad">
                      {formatNumber(
                        failedEvents,
                      )}
                    </td>

                    <td className="num">
                      {failedEventRate.toFixed(
                        2,
                      )}
                      %
                    </td>
                  </tr>

                  <tr>
                    <td>Alerts</td>

                    <td className="num warn">
                      {formatNumber(
                        totalAlerts,
                      )}
                    </td>

                    <td className="num">
                      {alertRate.toFixed(2)}
                      %
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ================================================================= */}
      {/* SOURCES                                                           */}
      {/* ================================================================= */}

      {activeSection === 'sources' && (
        <div>
          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Event Sources"
              subtitle="Where telemetry originates"
            />

            {eventBySource.length === 0 ? (
              <EmptyState>
                No source telemetry available.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Source</th>
                      <th>Events</th>
                      <th>Share</th>
                      <th>Distribution</th>
                    </tr>
                  </thead>

                  <tbody>
                    {eventBySource.map(
                      (entry) => {
                        const count =
                          safeNumber(
                            entry.count,
                          );

                        return (
                          <tr
                            key={
                              entry.sourceType
                            }
                          >
                            <td className="mono">
                              {
                                entry.sourceType
                              }
                            </td>

                            <td className="num">
                              {formatNumber(
                                count,
                              )}
                            </td>

                            <td className="num">
                              {formatPercentage(
                                count,
                                totalEvents,
                              )}
                            </td>

                            <td
                              style={{
                                minWidth: 180,
                              }}
                            >
                              <MiniProgress
                                value={count}
                                max={
                                  maxBySource
                                }
                              />
                            </td>
                          </tr>
                        );
                      },
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel">
              <SectionHeader
                title="Sources & Decisions"
                subtitle="Combined operational telemetry"
              />

              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Source / Type</th>
                      <th>Count</th>
                    </tr>
                  </thead>

                  <tbody>
                    {eventBySource.map(
                      (entry) => (
                        <tr
                          key={`src-${entry.sourceType}`}
                        >
                          <td className="mono">
                            src:{' '}
                            {
                              entry.sourceType
                            }
                          </td>

                          <td className="num">
                            {formatNumber(
                              safeNumber(
                                entry.count,
                              ),
                            )}
                          </td>
                        </tr>
                      ),
                    )}

                    {alerts.map(
                      (entry) => (
                        <tr
                          key={`sev-${entry.severity}`}
                        >
                          <td
                            className={`mono ${severityClass(
                              entry.severity,
                            )}`}
                          >
                            alert:{' '}
                            {
                              entry.severity
                            }
                          </td>

                          <td className="num">
                            {formatNumber(
                              safeNumber(
                                entry.count,
                              ),
                            )}
                          </td>
                        </tr>
                      ),
                    )}

                    {suggestions.map(
                      (entry, index) => {
                        const type =
                          entry.recommendationType ??
                          `decision-${index + 1}`;

                        return (
                          <tr
                            key={`decision-${type}-${index}`}
                          >
                            <td className="mono">
                              decision:{' '}
                              {type}
                            </td>

                            <td className="num">
                              {formatNumber(
                                safeNumber(
                                  entry.count,
                                ),
                              )}
                            </td>
                          </tr>
                        );
                      },
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="admin-panel">
              <SectionHeader
                title="Telemetry Coverage"
                subtitle="Available analytical dimensions"
              />

              <div className="admin-table-wrap">
                <table className="admin-table">
                  <tbody>
                    <tr>
                      <td>Encounter telemetry</td>
                      <td className="num">
                        {encounterByStatus.length >
                        0
                          ? 'available'
                          : 'none'}
                      </td>
                    </tr>

                    <tr>
                      <td>Event type telemetry</td>
                      <td className="num">
                        {eventByType.length >
                        0
                          ? 'available'
                          : 'none'}
                      </td>
                    </tr>

                    <tr>
                      <td>Daily telemetry</td>
                      <td className="num">
                        {eventByDay.length >
                        0
                          ? 'available'
                          : 'none'}
                      </td>
                    </tr>

                    <tr>
                      <td>Source telemetry</td>
                      <td className="num">
                        {eventBySource.length >
                        0
                          ? 'available'
                          : 'none'}
                      </td>
                    </tr>

                    <tr>
                      <td>Safety telemetry</td>
                      <td className="num">
                        {alerts.length > 0
                          ? 'available'
                          : 'none'}
                      </td>
                    </tr>

                    <tr>
                      <td>Decision telemetry</td>
                      <td className="num">
                        {suggestions.length >
                        0
                          ? 'available'
                          : 'none'}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ================================================================= */}
      {/* FOOTER                                                           */}
      {/* ================================================================= */}

      <div
        className="admin-panel"
        style={{
          marginTop: 16,
          padding: '10px 16px',
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
              {formatNumber(totalEncounters)}
            </strong>{' '}
            encounters
          </span>

          <span>
            <strong>
              {formatNumber(totalEvents)}
            </strong>{' '}
            events
          </span>

          <span>
            <strong>
              {formatNumber(failedEvents)}
            </strong>{' '}
            failed
          </span>

          <span>
            <strong>
              {formatNumber(totalAlerts)}
            </strong>{' '}
            alerts
          </span>

          <span>
            <strong>
              {formatNumber(totalDecisions)}
            </strong>{' '}
            decisions
          </span>

          <span className="muted small">
            AMEXAN Control Plane · Analytics ·
            read-only
          </span>
        </div>
      </div>
    </div>
  );
}