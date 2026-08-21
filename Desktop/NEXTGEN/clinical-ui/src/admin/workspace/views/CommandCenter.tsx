// =============================================================================
// AMEXAN Command Center — Phase G Control Plane
//
// READ-ONLY ADMIN PROJECTION
//
// Purpose:
//   • Observe the complete AMEXAN clinical/runtime control plane.
//   • Surface live clinical activity.
//   • Surface event throughput and failures.
//   • Surface engine health and execution state.
//   • Surface safety alerts and unresolved failures.
//   • Surface clinician/system interaction patterns.
//   • Surface documentation completion.
//   • Surface workflow pressure.
//   • Surface dead-letter/event-bus pressure.
//   • Surface latency and processing health where available.
//   • Provide drill-down into an event/encounter trace.
//
// Architecture:
//
//   CLINICAL UI
//       ↓
//   APPLICATION SERVICES
//       ↓
//   DOMAIN / CLINICAL ENGINES
//       ↓
//   EVENT BUS / OBSERVERS
//       ↓
//   CONTROL PLANE PROJECTIONS
//       ↓
//   THIS ADMIN WORKSPACE
//
// PostgreSQL is NEVER queried directly from this component.
// All information comes from the Control Plane API.
//
// The component intentionally tolerates partially populated projections so
// that an unavailable individual subsystem does not destroy the whole command
// center.
//
// =============================================================================

import { useCallback, useEffect, useMemo, useState } from 'react';

import {
  getAdminSummary,
  getEvents,
  getObservatory,
} from '../api';

import type {
  AdminSummary,
  EventLogEntry,
  EventSelection,
  ObservatorySummary,
} from '../types';

import {
  formatEventId,
  formatEventTime,
} from '../events';

// =============================================================================
// TYPES
// =============================================================================

interface CommandCenterProps {
  onOpenEvent: (selection: EventSelection) => void;
}

type HealthState = 'healthy' | 'degraded' | 'failed' | 'unknown';

type ActivityFilter =
  | 'ALL'
  | 'CLINICAL'
  | 'SAFETY'
  | 'ENGINE'
  | 'WORKFLOW'
  | 'SECURITY'
  | 'SYSTEM';

type RefreshState = 'idle' | 'refreshing' | 'success' | 'error';

// =============================================================================
// CONSTANTS
// =============================================================================

const LIVE_ACTIVITY_LIMIT = 20;

const REFRESH_INTERVAL_MS = 30_000;

const HEALTH_THRESHOLDS = {
  engineFailureRatio: 0.05,
  engineDegradedRatio: 0.15,
  deadLetterWarning: 1,
  deadLetterCritical: 10,
};

const ACTIVITY_FILTERS: ActivityFilter[] = [
  'ALL',
  'CLINICAL',
  'SAFETY',
  'ENGINE',
  'WORKFLOW',
  'SECURITY',
  'SYSTEM',
];

// =============================================================================
// SAFE HELPERS
// =============================================================================

function safeNumber(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? value
    : fallback;
}

function safeString(value: unknown, fallback = '—'): string {
  return typeof value === 'string' && value.trim().length > 0
    ? value
    : fallback;
}

function safeLower(value: unknown): string {
  return typeof value === 'string'
    ? value.toLowerCase()
    : '';
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat().format(
    Number.isFinite(value) ? value : 0,
  );
}

function formatPercentage(
  numerator: number,
  denominator: number,
): string {
  if (!denominator || denominator <= 0) {
    return '0%';
  }

  return `${Math.round((numerator / denominator) * 100)}%`;
}

function eventMatchesFilter(
  event: EventLogEntry,
  filter: ActivityFilter,
): boolean {
  if (filter === 'ALL') {
    return true;
  }

  const type = safeLower(event.eventType);
  const source = safeLower(event.sourceType);

  switch (filter) {
    case 'CLINICAL':
      return (
        type.includes('encounter') ||
        type.includes('clinical') ||
        type.includes('patient') ||
        type.includes('history') ||
        type.includes('examination') ||
        type.includes('diagnosis') ||
        type.includes('management') ||
        source.includes('clinical')
      );

    case 'SAFETY':
      return (
        type.includes('alert') ||
        type.includes('safety') ||
        type.includes('dose') ||
        type.includes('override') ||
        type.includes('contraindication') ||
        source.includes('safety')
      );

    case 'ENGINE':
      return (
        type.includes('engine') ||
        type.includes('execution') ||
        type.includes('evaluation') ||
        source.includes('engine')
      );

    case 'WORKFLOW':
      return (
        type.includes('workflow') ||
        type.includes('task') ||
        type.includes('queue') ||
        type.includes('transition') ||
        source.includes('workflow')
      );

    case 'SECURITY':
      return (
        type.includes('auth') ||
        type.includes('login') ||
        type.includes('permission') ||
        type.includes('role') ||
        type.includes('security') ||
        type.includes('access') ||
        source.includes('security')
      );

    case 'SYSTEM':
      return (
        type.includes('system') ||
        type.includes('runtime') ||
        type.includes('integration') ||
        type.includes('database') ||
        type.includes('event') ||
        source.includes('system')
      );

    default:
      return true;
  }
}

// =============================================================================
// HEALTH DERIVATION
// =============================================================================

function deriveOverallHealth(
  summary: AdminSummary | null,
  observatory: ObservatorySummary | null,
): HealthState {
  if (!summary && !observatory) {
    return 'unknown';
  }

  const failed =
    safeNumber(summary?.registry.failedEngines) ||
    safeNumber(observatory?.engines.failed);

  const degraded =
    safeNumber(summary?.registry.degradedEngines) ||
    safeNumber(observatory?.engines.degraded);

  const total =
    safeNumber(summary?.registry.engines) ||
    safeNumber(
      safeNumber(observatory?.engines.healthy) +
      safeNumber(observatory?.engines.degraded) +
      safeNumber(observatory?.engines.failed),
    );

  const deadLetters = safeNumber(summary?.events?.deadLetterEvents);

  if (
    failed > 0 ||
    deadLetters >= HEALTH_THRESHOLDS.deadLetterCritical
  ) {
    return 'failed';
  }

  if (
    degraded > 0 ||
    (total > 0 &&
      failed / total >= HEALTH_THRESHOLDS.engineFailureRatio) ||
    (total > 0 &&
      degraded / total >= HEALTH_THRESHOLDS.engineDegradedRatio) ||
    deadLetters >= HEALTH_THRESHOLDS.deadLetterWarning
  ) {
    return 'degraded';
  }

  return 'healthy';
}

// =============================================================================
// SMALL PRESENTATIONAL COMPONENTS
// =============================================================================

function StatusDot({
  state,
}: {
  state: HealthState;
}) {
  return (
    <span
      className={`admin-health-dot ${state}`}
      aria-hidden="true"
    />
  );
}

function MetricTile({
  label,
  value,
  note,
  tone = 'neutral',
  loading = false,
}: {
  label: string;
  value: string | number;
  note?: string;
  tone?: 'neutral' | 'good' | 'warn' | 'danger' | 'brand';
  loading?: boolean;
}) {
  return (
    <div className={`admin-tile tile-${tone}`}>
      <span className="tile-label">
        {label}
      </span>

      <span className="tile-value">
        {loading ? '…' : value}
      </span>

      {note && (
        <span className="tile-note">
          {note}
        </span>
      )}
    </div>
  );
}

function SectionHeader({
  title,
  subtitle,
  right,
}: {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
}) {
  return (
    <div className="admin-panel-head">
      <div>
        <span className="admin-panel-title">
          {title}
        </span>

        {subtitle && (
          <span className="admin-panel-sub">
            {subtitle}
          </span>
        )}
      </div>

      {right}
    </div>
  );
}

function EmptyState({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="admin-empty">
      {children}
    </div>
  );
}

// =============================================================================
// COMMAND CENTER
// =============================================================================

export function CommandCenter({
  onOpenEvent,
}: CommandCenterProps) {
  const [summary, setSummary] =
    useState<AdminSummary | null>(null);

  const [observatory, setObservatory] =
    useState<ObservatorySummary | null>(null);

  const [recent, setRecent] =
    useState<EventLogEntry[]>([]);

  const [loading, setLoading] =
    useState(true);

  const [refreshState, setRefreshState] =
    useState<RefreshState>('idle');

  const [error, setError] =
    useState<string | null>(null);

  const [lastUpdated, setLastUpdated] =
    useState<Date | null>(null);

  const [activityFilter, setActivityFilter] =
    useState<ActivityFilter>('ALL');

  const [showOnlyFailures, setShowOnlyFailures] =
    useState(false);

  // ===========================================================================
  // LOAD CONTROL-PLANE PROJECTIONS
  // ===========================================================================

  const load = useCallback(async () => {
    setRefreshState('refreshing');

    try {
      const [summaryResult, observatoryResult, eventsResult] =
        await Promise.all([
          getAdminSummary().catch(() => null),

          getObservatory().catch(() => null),

          getEvents({
            limit: LIVE_ACTIVITY_LIMIT,
          }).catch(() => null),
        ]);

      setSummary(summaryResult);

      setObservatory(observatoryResult);

      setRecent(eventsResult?.events ?? []);

      setError(null);

      setLastUpdated(new Date());

      setRefreshState('success');
    } catch (e) {
      const message =
        e instanceof Error
          ? e.message
          : 'Failed to load command center';

      setError(message);

      setRefreshState('error');
    } finally {
      setLoading(false);
    }
  }, []);

  // ===========================================================================
  // INITIAL + CONTINUOUS OBSERVATION
  // ===========================================================================

  useEffect(() => {
    void load();

    const timer = window.setInterval(
      () => {
        void load();
      },
      REFRESH_INTERVAL_MS,
    );

    return () => {
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // EVENT SELECTION
  // ===========================================================================

  const openSelection = useCallback(
    (event: EventLogEntry): EventSelection => ({
      eventId: event.id,

      encounterId:
        event.encounterId ?? undefined,

      correlationId:
        event.correlationId ?? undefined,
    }),
    [],
  );

  // ===========================================================================
  // DERIVED CONTROL-PLANE METRICS
  // ===========================================================================

  const activeEncounters =
    safeNumber(
      summary?.clinical.activeEncounters,
    );

  const eventsTotal =
    safeNumber(summary?.clinical.eventLog);

  const openAlerts =
    safeNumber(summary?.clinical.openAlerts);

  const engineCount =
    safeNumber(summary?.registry.engines);

  const activeEngines =
    safeNumber(summary?.registry.activeEngines);

  const degradedEngines =
    safeNumber(summary?.registry.degradedEngines);

  const failedEngines =
    safeNumber(summary?.registry.failedEngines);

  const userAccounts =
    safeNumber(summary?.identity.userAccounts);

  const healthyEngines =
    safeNumber(observatory?.engines.healthy);

  const observatoryDegraded =
    safeNumber(observatory?.engines.degraded);

  const observatoryFailed =
    safeNumber(observatory?.engines.failed);

  const eventsLastMinute =
    safeNumber(
      observatory?.throughput.eventsLastMinute,
    );

  const eventsLastHour =
    safeNumber(
      summary?.events?.eventsLastHour,
    );

  const deadLetterEvents =
    safeNumber(
      summary?.events?.deadLetterEvents,
    );

  const clinicianAccepted =
    safeNumber(
      observatory?.clinicianBehaviour.accepted,
    );

  const clinicianModified =
    safeNumber(
      observatory?.clinicianBehaviour.modified,
    );

  const clinicianRejected =
    safeNumber(
      observatory?.clinicianBehaviour.rejected,
    );

  const clinicianOverrides =
    safeNumber(
      observatory?.clinicianBehaviour.overrides,
    );

  const documentationFinalized =
    safeNumber(
      observatory?.documentation.finalized,
    );

  const totalSuggestions =
    clinicianAccepted +
    clinicianModified +
    clinicianRejected +
    clinicianOverrides;

  const modificationRate =
    totalSuggestions > 0
      ? clinicianModified / totalSuggestions
      : 0;

  const overrideRate =
    totalSuggestions > 0
      ? clinicianOverrides / totalSuggestions
      : 0;

  const overallHealth =
    deriveOverallHealth(
      summary,
      observatory,
    );

  // ===========================================================================
  // EVENT FILTERING
  // ===========================================================================

  const filteredEvents = useMemo(() => {
    return recent.filter((event) => {
      if (
        !eventMatchesFilter(
          event,
          activityFilter,
        )
      ) {
        return false;
      }

      if (!showOnlyFailures) {
        return true;
      }

      const type = safeLower(
        event.eventType,
      );

      const source = safeLower(
        event.sourceType,
      );

      return (
        type.includes('fail') ||
        type.includes('error') ||
        type.includes('exception') ||
        type.includes('dead') ||
        type.includes('alert') ||
        type.includes('safety') ||
        source.includes('error') ||
        source.includes('safety')
      );
    });
  }, [
    recent,
    activityFilter,
    showOnlyFailures,
  ]);

  // ===========================================================================
  // INITIAL LOADING
  // ===========================================================================

  if (
    loading &&
    !summary &&
    !observatory
  ) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />

        Loading command center…
      </div>
    );
  }

  // ===========================================================================
  // COMPLETE CONTROL-PLANE FAILURE
  // ===========================================================================

  if (
    error &&
    !summary &&
    !observatory
  ) {
    return (
      <div>
        <div
          className="admin-error"
          role="alert"
        >
          <strong>
            Control Plane unavailable
          </strong>

          <div style={{ marginTop: 4 }}>
            {error}
          </div>

          <button
            type="button"
            className="admin-nav-btn"
            style={{ marginTop: 12 }}
            onClick={() => void load()}
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div>
      {/* =====================================================================
          CONTROL-PLANE HEALTH BANNER
          ===================================================================== */}

      <div className="admin-panel">
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'center',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <StatusDot state={overallHealth} />

            <div>
              <span className="admin-panel-title">
                AMEXAN Control Plane
              </span>

              <span className="admin-panel-sub">
                Clinical operations · event bus ·
                engines · safety · workflow
              </span>
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              flexWrap: 'wrap',
            }}
          >
            <span className="muted small">
              {lastUpdated
                ? `Updated ${lastUpdated.toLocaleTimeString()}`
                : 'Awaiting update'}
            </span>

            <button
              type="button"
              className="admin-nav-btn"
              disabled={
                refreshState === 'refreshing'
              }
              onClick={() => void load()}
            >
              {refreshState === 'refreshing'
                ? 'Refreshing…'
                : 'Refresh'}
            </button>
          </div>
        </div>

        {error && (
          <div
            className="admin-error"
            role="status"
            style={{ marginTop: 12 }}
          >
            Partial control-plane data unavailable:
            {' '}
            {error}
          </div>
        )}

        <div
          style={{
            display: 'flex',
            gap: 18,
            flexWrap: 'wrap',
            marginTop: 12,
            fontSize: '0.82rem',
          }}
        >
          <span>
            <StatusDot state={overallHealth} />
            {' '}
            {overallHealth.toUpperCase()}
          </span>

          <span>
            Event stream:
            {' '}
            <strong>
              {formatNumber(eventsLastMinute)}/min
            </strong>
          </span>

          <span>
            Engines:
            {' '}
            <strong>
              {formatNumber(activeEngines)}
            </strong>
            /
            {formatNumber(engineCount)}
          </span>

          <span>
            Dead-letter:
            {' '}
            <strong>
              {formatNumber(deadLetterEvents)}
            </strong>
          </span>
        </div>
      </div>

      {/* =====================================================================
          LIVE ACTIVITY
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <SectionHeader
          title="Live Activity"
          subtitle={`Latest ${LIVE_ACTIVITY_LIMIT} observed events across AMEXAN`}
          right={
            <span className="muted small">
              Auto-refresh 30s
            </span>
          }
        />

        {/* Activity filters */}

        <div
          style={{
            display: 'flex',
            gap: 6,
            flexWrap: 'wrap',
            marginBottom: 12,
          }}
        >
          {ACTIVITY_FILTERS.map(
            (filter) => (
              <button
                key={filter}
                type="button"
                className={`admin-nav-btn${
                  activityFilter === filter
                    ? ' active'
                    : ''
                }`}
                onClick={() =>
                  setActivityFilter(
                    filter,
                  )
                }
              >
                {filter}
              </button>
            ),
          )}

          <button
            type="button"
            className={`admin-nav-btn${
              showOnlyFailures
                ? ' active'
                : ''
            }`}
            onClick={() =>
              setShowOnlyFailures(
                (value) => !value,
              )
            }
          >
            Failures / Alerts
          </button>
        </div>

        <div className="admin-activity">
          {filteredEvents.length === 0 && (
            <EmptyState>
              {recent.length === 0
                ? 'No recent events recorded.'
                : 'No events match the selected filter.'}
            </EmptyState>
          )}

          {filteredEvents.map(
            (event) => (
              <button
                key={String(event.id)}
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
                  onOpenEvent(
                    openSelection(event),
                  )
                }
              >
                <span className="admin-activity-time">
                  {formatEventTime(
                    event.occurredAt,
                  )}
                </span>

                <span className="admin-activity-type">
                  {safeString(
                    event.eventType,
                    'UNKNOWN_EVENT',
                  )}
                </span>

                <span className="admin-activity-meta">
                  {safeString(
                    event.sourceType,
                    'unknown',
                  )}

                  {event.encounterId
                    ? ` · ENC-${event.encounterId
                        .slice(0, 6)
                        .toUpperCase()}`
                    : ''}

                  {event.correlationId
                    ? ` · COR-${event.correlationId
                        .slice(0, 6)
                        .toUpperCase()}`
                    : ''}
                </span>

                <span className="admin-activity-tag">
                  Event{' '}
                  {formatEventId(
                    event.id,
                  )}
                </span>
              </button>
            ),
          )}
        </div>
      </div>

      {/* =====================================================================
          PRIMARY OPERATIONAL METRICS
          ===================================================================== */}

      <div
        className="admin-tile-grid"
        style={{ marginTop: 16 }}
      >
        <MetricTile
          label="Active Encounters"
          value={formatNumber(
            activeEncounters,
          )}
          note="currently in progress"
          tone="brand"
        />

        <MetricTile
          label="Events / Minute"
          value={formatNumber(
            eventsLastMinute,
          )}
          note={`${formatNumber(eventsTotal)} total event records`}
          tone="neutral"
        />

        <MetricTile
          label="System Health"
          value={formatNumber(
            engineCount,
          )}
          note={`${formatNumber(
            activeEngines,
          )} active · ${formatNumber(
            degradedEngines,
          )} degraded · ${formatNumber(
            failedEngines,
          )} failed`}
          tone={
            failedEngines > 0
              ? 'danger'
              : degradedEngines > 0
                ? 'warn'
                : 'good'
          }
        />

        <MetricTile
          label="Open Safety Alerts"
          value={formatNumber(
            openAlerts,
          )}
          note="requiring resolution"
          tone={
            openAlerts > 0
              ? 'danger'
              : 'good'
          }
        />

        <MetricTile
          label="Dead-Letter Events"
          value={formatNumber(
            deadLetterEvents,
          )}
          note="events requiring replay/investigation"
          tone={
            deadLetterEvents > 0
              ? 'danger'
              : 'good'
          }
        />

        <MetricTile
          label="User Accounts"
          value={formatNumber(
            userAccounts,
          )}
          note="registered platform identities"
          tone="neutral"
        />
      </div>

      {/* =====================================================================
          ENGINE / EVENT BUS / SAFETY
          ===================================================================== */}

      <div
        className="admin-grid-3"
        style={{ marginTop: 16 }}
      >
        {/* ENGINE REGISTRY */}

        <div className="admin-panel">
          <SectionHeader
            title="Engine Registry"
            subtitle="runtime execution fleet"
          />

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Engines registered</td>
                <td className="num">
                  {formatNumber(
                    engineCount,
                  )}
                </td>
              </tr>

              <tr>
                <td>Engines active</td>
                <td className="num">
                  {formatNumber(
                    activeEngines,
                  )}
                </td>
              </tr>

              <tr>
                <td>Healthy</td>
                <td className="num">
                  {formatNumber(
                    healthyEngines,
                  )}
                </td>
              </tr>

              <tr>
                <td>Degraded</td>
                <td className="num">
                  {formatNumber(
                    degradedEngines ||
                    observatoryDegraded,
                  )}
                </td>
              </tr>

              <tr>
                <td>Failed</td>
                <td className="num">
                  {formatNumber(
                    failedEngines ||
                    observatoryFailed,
                  )}
                </td>
              </tr>

              <tr>
                <td>Availability</td>
                <td className="num">
                  {formatPercentage(
                    healthyEngines,
                    healthyEngines +
                      observatoryDegraded +
                      observatoryFailed,
                  )}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        {/* EVENT BUS */}

        <div className="admin-panel">
          <SectionHeader
            title="Event Bus"
            subtitle="observability stream"
          />

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Events / minute</td>
                <td className="num">
                  {formatNumber(
                    eventsLastMinute,
                  )}
                </td>
              </tr>

              <tr>
                <td>Events / hour</td>
                <td className="num">
                  {formatNumber(
                    eventsLastHour,
                  )}
                </td>
              </tr>

              <tr>
                <td>Total event log</td>
                <td className="num">
                  {formatNumber(
                    eventsTotal,
                  )}
                </td>
              </tr>

              <tr>
                <td>Dead-letter events</td>
                <td
                  className={`num ${
                    deadLetterEvents > 0
                      ? 'danger'
                      : ''
                  }`}
                >
                  {formatNumber(
                    deadLetterEvents,
                  )}
                </td>
              </tr>

              <tr>
                <td>Stream state</td>
                <td className="num">
                  {deadLetterEvents >
                  HEALTH_THRESHOLDS
                    .deadLetterCritical
                    ? 'PRESSURED'
                    : 'OBSERVING'}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        {/* SAFETY */}

        <div className="admin-panel">
          <SectionHeader
            title="Safety Plane"
            subtitle="clinical guardrails"
          />

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Open alerts</td>
                <td
                  className={`num ${
                    openAlerts > 0
                      ? 'danger'
                      : ''
                  }`}
                >
                  {formatNumber(
                    openAlerts,
                  )}
                </td>
              </tr>

              <tr>
                <td>Dead-letter events</td>
                <td className="num">
                  {formatNumber(
                    deadLetterEvents,
                  )}
                </td>
              </tr>

              <tr>
                <td>Failed engines</td>
                <td className="num">
                  {formatNumber(
                    failedEngines,
                  )}
                </td>
              </tr>

              <tr>
                <td>Safety state</td>
                <td className="num">
                  {openAlerts > 0 ||
                  failedEngines > 0
                    ? 'ATTENTION'
                    : 'CLEAR'}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          CLINICIAN BEHAVIOUR
          ===================================================================== */}

      <div
        className="admin-grid-3"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <SectionHeader
            title="Clinician Behaviour"
            subtitle="decision interaction telemetry"
          />

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Suggestions accepted</td>
                <td className="num">
                  {formatNumber(
                    clinicianAccepted,
                  )}
                </td>
              </tr>

              <tr>
                <td>Suggestions modified</td>
                <td className="num">
                  {formatNumber(
                    clinicianModified,
                  )}
                </td>
              </tr>

              <tr>
                <td>Suggestions rejected</td>
                <td className="num">
                  {formatNumber(
                    clinicianRejected,
                  )}
                </td>
              </tr>

              <tr>
                <td>Clinical overrides</td>
                <td className="num">
                  {formatNumber(
                    clinicianOverrides,
                  )}
                </td>
              </tr>

              <tr>
                <td>Modification rate</td>
                <td className="num">
                  {formatPercentage(
                    modificationRate,
                    1,
                  )}
                </td>
              </tr>

              <tr>
                <td>Override rate</td>
                <td className="num">
                  {formatPercentage(
                    overrideRate,
                    1,
                  )}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        {/* DOCUMENTATION */}

        <div className="admin-panel">
          <SectionHeader
            title="Clinical Documentation"
            subtitle="documentation completion telemetry"
          />

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Active encounters</td>
                <td className="num">
                  {formatNumber(
                    activeEncounters,
                  )}
                </td>
              </tr>

              <tr>
                <td>Documents finalized</td>
                <td className="num">
                  {formatNumber(
                    documentationFinalized,
                  )}
                </td>
              </tr>

              <tr>
                <td>Finalized / active</td>
                <td className="num">
                  {formatPercentage(
                    documentationFinalized,
                    activeEncounters,
                  )}
                </td>
              </tr>

              <tr>
                <td>Event records</td>
                <td className="num">
                  {formatNumber(
                    eventsTotal,
                  )}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        {/* SYSTEM PERFORMANCE */}

        <div className="admin-panel">
          <SectionHeader
            title="Operational Pressure"
            subtitle="signals requiring attention"
          />

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Active encounters</td>
                <td className="num">
                  {formatNumber(
                    activeEncounters,
                  )}
                </td>
              </tr>

              <tr>
                <td>Events / minute</td>
                <td className="num">
                  {formatNumber(
                    eventsLastMinute,
                  )}
                </td>
              </tr>

              <tr>
                <td>Open alerts</td>
                <td className="num">
                  {formatNumber(
                    openAlerts,
                  )}
                </td>
              </tr>

              <tr>
                <td>Failed engines</td>
                <td className="num">
                  {formatNumber(
                    failedEngines,
                  )}
                </td>
              </tr>

              <tr>
                <td>Dead letters</td>
                <td className="num">
                  {formatNumber(
                    deadLetterEvents,
                  )}
                </td>
              </tr>

              <tr>
                <td>Overall state</td>
                <td className="num">
                  {overallHealth.toUpperCase()}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          OBSERVABILITY MATRIX
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <SectionHeader
          title="AMEXAN Observability Matrix"
          subtitle="control-plane visibility across the clinical lifecycle"
        />

        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Domain</th>
                <th>Observed Signal</th>
                <th>Current Value</th>
                <th>State</th>
              </tr>
            </thead>

            <tbody>
              <tr>
                <td>Clinical</td>
                <td>Active encounters</td>
                <td className="num">
                  {formatNumber(
                    activeEncounters,
                  )}
                </td>
                <td>OBSERVED</td>
              </tr>

              <tr>
                <td>Event Bus</td>
                <td>Events per minute</td>
                <td className="num">
                  {formatNumber(
                    eventsLastMinute,
                  )}
                </td>
                <td>OBSERVED</td>
              </tr>

              <tr>
                <td>Engine Runtime</td>
                <td>Failed engines</td>
                <td className="num">
                  {formatNumber(
                    failedEngines,
                  )}
                </td>
                <td>
                  {failedEngines > 0
                    ? 'ATTENTION'
                    : 'HEALTHY'}
                </td>
              </tr>

              <tr>
                <td>Safety</td>
                <td>Open clinical alerts</td>
                <td className="num">
                  {formatNumber(
                    openAlerts,
                  )}
                </td>
                <td>
                  {openAlerts > 0
                    ? 'ACTION'
                    : 'CLEAR'}
                </td>
              </tr>

              <tr>
                <td>Workflow</td>
                <td>Clinical activity</td>
                <td className="num">
                  {formatNumber(
                    activeEncounters,
                  )}
                </td>
                <td>OBSERVED</td>
              </tr>

              <tr>
                <td>Documentation</td>
                <td>Finalized documents</td>
                <td className="num">
                  {formatNumber(
                    documentationFinalized,
                  )}
                </td>
                <td>OBSERVED</td>
              </tr>

              <tr>
                <td>Human Decision Layer</td>
                <td>Clinical overrides</td>
                <td className="num">
                  {formatNumber(
                    clinicianOverrides,
                  )}
                </td>
                <td>
                  {clinicianOverrides > 0
                    ? 'REVIEWABLE'
                    : 'NONE'}
                </td>
              </tr>

              <tr>
                <td>Reliability</td>
                <td>Dead-letter events</td>
                <td className="num">
                  {formatNumber(
                    deadLetterEvents,
                  )}
                </td>
                <td>
                  {deadLetterEvents > 0
                    ? 'REPLAY / INVESTIGATE'
                    : 'CLEAR'}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          CONTROL-PLANE FOOTER
          ===================================================================== */}

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
            alignItems: 'center',
          }}
        >
          <span>
            <strong>
              {formatNumber(
                activeEncounters,
              )}
            </strong>
            {' '}
            active encounters
          </span>

          <span>
            <strong>
              {formatNumber(
                openAlerts,
              )}
            </strong>
            {' '}
            open alerts
          </span>

          <span>
            <strong>
              {formatNumber(
                eventsTotal,
              )}
            </strong>
            {' '}
            events logged
          </span>

          <span>
            <strong>
              {formatNumber(
                engineCount,
              )}
            </strong>
            {' '}
            engines
          </span>

          <span>
            <strong>
              {formatNumber(
                userAccounts,
              )}
            </strong>
            {' '}
            users
          </span>

          <span>
            <strong>
              {formatNumber(
                clinicianOverrides,
              )}
            </strong>
            {' '}
            clinician overrides
          </span>

          <span className="muted small">
            Control Plane · read-only ·{' '}
            {summary?.generatedAt ??
              lastUpdated?.toISOString() ??
              '—'}
          </span>
        </div>
      </div>
    </div>
  );
}