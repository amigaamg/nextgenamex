// =============================================================================
// AMEXAN Admin Workspace — Control Plane Shell
//
// Context bar : AMEXAN │ Network │ Facility │ Admin │ ● System Status
// Modes       : OPERATE / INVESTIGATE / IMPROVE
//
// OPERATE
//   Command · Engine · Safety · Runtime · Integrations · Notifications
//
// INVESTIGATE
//   Events · Trace · Safety · Incidents · Workflow · Configuration
//
// IMPROVE
//   Configuration · Versions · Security · Analytics · Database · Engines
//
// PRINCIPLES
//   1. Browser NEVER touches PostgreSQL directly.
//   2. Views consume Control Plane projections.
//   3. Every clinically/systemically meaningful action is traceable.
//   4. Navigation remains typed and deterministic.
//   5. Event focus is communicated through a typed AMEXAN browser event.
//   6. Summary polling must not create overlapping requests.
//   7. A stale summary must never silently appear as "Healthy".
//   8. Admin Workspace is READ-ONLY at this shell layer.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { getAdminSummary } from './api';
import type {
  AdminSummary,
  EventSelection,
  SystemHealthProjection,
} from './types';

import { CommandCenter } from './views/CommandCenter';
import { EventExplorer } from './views/EventExplorer';
import { EncounterTrace } from './views/EncounterTrace';
import { EngineMonitor } from './views/EngineMonitor';
import { SafetyCenter } from './views/SafetyCenter';
import { ConfigView } from './views/ConfigView';
import { VersionsView } from './views/VersionsView';
import { SecurityView } from './views/SecurityView';
import { DatabaseView } from './views/DatabaseView';
import { RuntimeView } from './views/RuntimeView';
import { WorkflowView } from './views/WorkflowView';
import { IncidentsView } from './views/IncidentsView';
import { IntegrationsView } from './views/IntegrationsView';
import { NotificationsView } from './views/NotificationsView';
import { AnalyticsView } from './views/AnalyticsView';
import { ServiceCatalogueView } from './views/ServiceCatalogueView';
import { AssetIntelligenceView } from './views/AssetIntelligenceView';
import { FinancialView } from './views/FinancialView';
import { ResearchView } from './views/ResearchView';
import { CrossIcon } from '../../components/Icons';

// =============================================================================
// Types
// =============================================================================

type AdminMode =
  | 'OPERATE'
  | 'INVESTIGATE'
  | 'IMPROVE';

type AdminView =
  | 'command'
  | 'events'
  | 'trace'
  | 'engines'
  | 'safety'
  | 'config'
  | 'versions'
  | 'security'
  | 'database'
  | 'runtime'
  | 'workflow'
  | 'incidents'
  | 'integrations'
  | 'notifications'
  | 'analytics'
  | 'catalogues'
  | 'assets'
  | 'financial'
  | 'research';

type HealthClass =
  | 'good'
  | 'warn'
  | 'bad'
  | 'unknown';

interface AdminWorkspaceProps {
  onExit: () => void;
}

interface AdminNavItem {
  view: AdminView;
  label: string;
  description: string;
}

interface AdminSummaryExtended
  extends AdminSummary {
  system: SystemHealthProjection & {
    status?:
      | 'healthy'
      | 'degraded'
      | 'critical'
      | 'unknown';

    technicalStatus?:
      | 'healthy'
      | 'degraded'
      | 'critical'
      | 'unknown';

    clinicalSafetyStatus?:
      | 'healthy'
      | 'degraded'
      | 'critical'
      | 'unknown';

    eventPipelineStatus?:
      | 'healthy'
      | 'degraded'
      | 'critical'
      | 'unknown';

    databaseStatus?:
      | 'healthy'
      | 'degraded'
      | 'critical'
      | 'unknown';

    runtimeStatus?:
      | 'healthy'
      | 'degraded'
      | 'critical'
      | 'unknown';

    lastHeartbeatAt?: string;
  };

  events?: {
    eventsLastMinute?: number;
    eventsLastHour?: number;
    failedDeliveries?: number;
    pendingDeliveries?: number;
    deadLetterEvents?: number;
  };

  safety?: {
    critical?: number;
    high?: number;
    medium?: number;
    low?: number;
    unresolved?: number;
    overrides?: number;
  };

  registry: AdminSummary['registry'] & {
    activeEngines?: number;
    degradedEngines?: number;
    failedEngines?: number;
  };
}

// =============================================================================
// Navigation Registry
// =============================================================================

const MODE_NAV: Record<
  AdminMode,
  AdminNavItem[]
> = {
  OPERATE: [
    {
      view: 'command',
      label: 'Command Center',
      description:
        'Live AMEXAN operational state',
    },
    {
      view: 'engines',
      label: 'Engine Monitor',
      description:
        'Clinical and platform engine execution',
    },
    {
      view: 'safety',
      label: 'Safety Center',
      description:
        'Clinical safety surveillance',
    },
    {
      view: 'runtime',
      label: 'Runtime',
      description:
        'CPU, workers, queues and services',
    },
    {
      view: 'integrations',
      label: 'Integrations',
      description:
        'External systems and connections',
    },
    {
      view: 'notifications',
      label: 'Notifications',
      description:
        'System and safety notifications',
    },
    {
      view: 'catalogues',
      label: 'Service Catalogues',
      description:
        'Facility operational service registry',
    },
    {
      view: 'assets',
      label: 'Asset Intelligence',
      description:
        'Care continuity through asset intelligence',
    },
    {
      view: 'financial',
      label: 'Financial',
      description:
        'Facility financial operating picture',
    },
    {
      view: 'research',
      label: 'Research Intelligence',
      description:
        'Governed clinical research environment',
    },
  ],

  INVESTIGATE: [
    {
      view: 'events',
      label: 'Event Explorer',
      description:
        'Inspect individual system events',
    },
    {
      view: 'trace',
      label: 'Encounter Trace',
      description:
        'Follow the complete clinical journey',
    },
    {
      view: 'safety',
      label: 'Safety Center',
      description:
        'Investigate safety decisions',
    },
    {
      view: 'incidents',
      label: 'Incidents',
      description:
        'Investigate failures and incidents',
    },
    {
      view: 'workflow',
      label: 'Workflow',
      description:
        'Inspect workflow execution',
    },
    {
      view: 'config',
      label: 'Configuration',
      description:
        'Inspect effective configuration',
    },
  ],

  IMPROVE: [
    {
      view: 'config',
      label: 'Configuration',
      description:
        'Configuration and policy registry',
    },
    {
      view: 'versions',
      label: 'System Versions',
      description:
        'Engine and platform versions',
    },
    {
      view: 'security',
      label: 'Security / RBAC',
      description:
        'Identity, roles and authorization',
    },
    {
      view: 'analytics',
      label: 'Analytics',
      description:
        'Operational and clinical-system analytics',
    },
    {
      view: 'database',
      label: 'Database',
      description:
        'Data layer health and projections',
    },
    {
      view: 'engines',
      label: 'Engine Monitor',
      description:
        'Engine performance and learning signals',
    },
    {
      view: 'catalogues',
      label: 'Service Catalogues',
      description:
        'Configure the facility service registry',
    },
    {
      view: 'assets',
      label: 'Asset Intelligence',
      description:
        'Configure facility asset resilience',
    },
  ],
};

const VIEW_TITLES: Record<
  AdminView,
  string
> = {
  command: 'Command Center',
  events: 'Event Explorer',
  trace: 'Encounter Trace',
  engines: 'Engine Monitor',
  safety: 'Safety Center',
  config: 'Configuration',
  versions: 'System Versions',
  security: 'Security / RBAC',
  database: 'Database',
  runtime: 'Runtime',
  workflow: 'Workflow',
  incidents: 'Incidents',
  integrations: 'Integrations',
  notifications: 'Notifications',
  analytics: 'Analytics',
  catalogues: 'Service Catalogues',
  assets: 'Asset Intelligence',
  financial: 'Financial',
  research: 'Research Intelligence',
};

const VIEW_DESCRIPTIONS: Record<
  AdminView,
  string
> = {
  command:
    'Observe what is happening across AMEXAN right now.',
  events:
    'Inspect the immutable event journey and processing state.',
  trace:
    'Trace an encounter from creation through documentation and close-out.',
  engines:
    'Monitor every registered AMEXAN engine and its execution behaviour.',
  safety:
    'Monitor clinical safety signals, overrides, warnings and escalations.',
  config:
    'Inspect effective configuration, provenance and overrides.',
  versions:
    'Monitor engine, rule, protocol and platform versions.',
  security:
    'Observe identity, access, RBAC, sessions and security events.',
  database:
    'Observe PostgreSQL, projections, transactions and data-layer health.',
  runtime:
    'Observe API processes, workers, queues, CPU, memory and runtime health.',
  workflow:
    'Inspect workflow state, transitions, waiting states and failures.',
  incidents:
    'Investigate system, clinical-safety and integration incidents.',
  integrations:
    'Observe connected systems, APIs, queues and synchronization.',
  notifications:
    'Observe alert delivery and administrative notifications.',
  analytics:
    'Understand usage, performance, documentation and system improvement.',
  catalogues:
    'Inspect the facility operational service registry and its configuration.',
  assets:
    'Care continuity through asset intelligence — what happens to care if this asset fails.',
  financial:
    'Facility financial operating picture — clinical activity, revenue, claims, receivables and service economics.',
  research:
    'Governed clinical research environment — studies, participants, data requests, approvals, de-identification and audit.',
};

const MODE_DESCRIPTIONS: Record<
  AdminMode,
  string
> = {
  OPERATE: 'what is happening',
  INVESTIGATE: 'why did it happen',
  IMPROVE: 'what to change',
};

const SUMMARY_REFRESH_INTERVAL = 30_000;

// =============================================================================
// Helpers
// =============================================================================

function deriveInitialView(
  mode: AdminMode,
  current: AdminView,
): AdminView {
  const available =
    MODE_NAV[mode].map(
      (entry) => entry.view,
    );

  return available.includes(current)
    ? current
    : available[0];
}

function getSummaryHealth(
  summary: AdminSummaryExtended | null,
  error: string | null,
): HealthClass {
  if (error) {
    return 'bad';
  }

  if (!summary) {
    return 'unknown';
  }

  const systemStatus =
    summary.system?.overall?.status ??
    summary.system?.status;

  if (systemStatus === 'critical') {
    return 'bad';
  }

  if (systemStatus === 'degraded') {
    return 'warn';
  }

  if (systemStatus === 'healthy') {
    return 'good';
  }

  /*
   * Backward-compatible behaviour for the existing AdminSummary.
   *
   * We deliberately do NOT call the system "healthy" merely because the
   * summary request succeeded. Until the backend exposes an explicit
   * system-health projection, "unknown" is the safe state.
   */
  return 'unknown';
}

function getHealthLabel(
  health: HealthClass,
): string {
  switch (health) {
    case 'good':
      return 'Healthy';

    case 'warn':
      return 'Degraded';

    case 'bad':
      return 'Critical';

    default:
      return 'Unknown';
  }
}

function getHealthDotClass(
  health: HealthClass,
): string {
  switch (health) {
    case 'good':
      return 'good';

    case 'warn':
      return 'warn';

    case 'bad':
      return 'bad';

    default:
      return 'unknown';
  }
}

// =============================================================================
// Component
// =============================================================================

export function AdminWorkspace({
  onExit,
}: AdminWorkspaceProps) {
  // ---------------------------------------------------------------------------
  // Navigation state
  // ---------------------------------------------------------------------------

  const [mode, setMode] =
    useState<AdminMode>('OPERATE');

  const [view, setView] =
    useState<AdminView>('command');

  // ---------------------------------------------------------------------------
  // Control Plane state
  // ---------------------------------------------------------------------------

  const [summary, setSummary] =
    useState<AdminSummary | null>(null);

  const [error, setError] =
    useState<string | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [refreshing, setRefreshing] =
    useState(false);

  const [lastSuccessfulRefresh, setLastSuccessfulRefresh] =
    useState<Date | null>(null);

  // ---------------------------------------------------------------------------
  // Request lifecycle
  // ---------------------------------------------------------------------------

  const mountedRef =
    useRef(true);

  const refreshInFlightRef =
    useRef(false);

  const intervalRef =
    useRef<ReturnType<typeof setInterval> | null>(
      null,
    );

  // ---------------------------------------------------------------------------
  // Keep component lifecycle safe
  // ---------------------------------------------------------------------------

  useEffect(() => {
    mountedRef.current = true;

    return () => {
      mountedRef.current = false;

      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, []);

  // ---------------------------------------------------------------------------
  // Summary refresh
  // ---------------------------------------------------------------------------

  const refreshSummary = useCallback(
    async (
      manual = false,
    ) => {
      /*
       * Do not allow multiple overlapping summary requests.
       *
       * This matters when:
       * - the network is slow;
       * - the Control Plane is degraded;
       * - the administrator repeatedly presses Refresh;
       * - a timer fires while a manual refresh is running.
       */
      if (refreshInFlightRef.current) {
        return;
      }

      refreshInFlightRef.current = true;

      if (manual) {
        setRefreshing(true);
      }

      try {
        const nextSummary =
          await getAdminSummary();

        if (!mountedRef.current) {
          return;
        }

        setSummary(nextSummary);
        setError(null);
        setLastSuccessfulRefresh(
          new Date(),
        );
      } catch (cause) {
        if (!mountedRef.current) {
          return;
        }

        const message =
          cause instanceof Error
            ? cause.message
            : 'Control plane unreachable';

        setError(message);
      } finally {
        refreshInFlightRef.current = false;

        if (mountedRef.current) {
          setLoading(false);
          setRefreshing(false);
        }
      }
    },
    [],
  );

  // ---------------------------------------------------------------------------
  // Initial summary + polling
  // ---------------------------------------------------------------------------

  useEffect(() => {
    void refreshSummary();

    intervalRef.current =
      setInterval(() => {
        void refreshSummary();
      }, SUMMARY_REFRESH_INTERVAL);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [refreshSummary]);

  // ---------------------------------------------------------------------------
  // Keep view valid after mode change
  // ---------------------------------------------------------------------------

  useEffect(() => {
    setView(
      (current) =>
        deriveInitialView(
          mode,
          current,
        ),
    );
  }, [mode]);

  // ---------------------------------------------------------------------------
  // Event focus
  //
  // Selection is props-based: CommandCenter -> AdminWorkspace ->
  // EventExplorer(initialSelection). No window CustomEvents.
  // ---------------------------------------------------------------------------

  const [selectedEvent, setSelectedEvent] =
    useState<EventSelection | null>(null);

  const handleOpenEvent = useCallback(
    (selection: EventSelection) => {
      setSelectedEvent(selection);
      setMode('INVESTIGATE');
      setView('events');
    },
    [],
  );

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  const navItems = useMemo(
    () => MODE_NAV[mode],
    [mode],
  );

  // ---------------------------------------------------------------------------
  // Summary values
  // ---------------------------------------------------------------------------

  const activeEncounters =
    summary?.clinical.activeEncounters ??
    0;

  const openAlerts =
    summary?.clinical.openAlerts ??
    0;

  const eventsTotal =
    summary?.clinical.eventLog ??
    0;

  const engineCount =
    summary?.registry.engines ??
    0;

  const userAccounts =
    summary?.identity.userAccounts ??
    0;

  // ---------------------------------------------------------------------------
  // Extended projections
  // ---------------------------------------------------------------------------

  const extendedSummary =
    summary as AdminSummaryExtended | null;

  const activeEngines =
    extendedSummary?.registry
      ?.activeEngines;

  const degradedEngines =
    extendedSummary?.registry
      ?.degradedEngines;

  const failedEngines =
    extendedSummary?.registry
      ?.failedEngines;

  const eventsLastMinute =
    extendedSummary?.events
      ?.eventsLastMinute;

  const pendingEvents =
    extendedSummary?.events
      ?.pendingDeliveries;

  const failedEvents =
    extendedSummary?.events
      ?.failedDeliveries;

  const deadLetterEvents =
    extendedSummary?.events
      ?.deadLetterEvents;

  const safetyCritical =
    extendedSummary?.safety
      ?.critical;

  const safetyUnresolved =
    extendedSummary?.safety
      ?.unresolved;

  // ---------------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------------

  const health =
    getSummaryHealth(
      extendedSummary,
      error,
    );

  const healthLabel =
    getHealthLabel(health);

  const healthDot =
    getHealthDotClass(health);

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------

  return (
    <div
      className="admin-workspace"
      data-admin-mode={mode}
      data-admin-view={view}
      data-control-plane-status={health}
    >
      {/* =====================================================================
          CONTEXT BAR
          ===================================================================== */}

      <div
        className="admin-context-bar"
        role="banner"
      >
        <span className="admin-context-brand">
          <CrossIcon size={16} />
          <span>AMEXAN</span>
        </span>

        <span
          className="admin-context-sep"
          aria-hidden="true"
        >
          │
        </span>

        <span className="admin-context-item">
          <span className="label">
            Network
          </span>

          <span className="value">
            AMEXAN Platform
          </span>
        </span>

        <span className="admin-context-item">
          <span className="label">
            Scope
          </span>

          <span className="value">
            Global
          </span>
        </span>

        <span className="admin-context-item">
          <span className="label">
            Administering
          </span>

          <span className="value">
            Control Plane
          </span>
        </span>

        <span
          className="admin-context-health"
          title={
            error ??
            extendedSummary?.system
              ?.lastHeartbeatAt ??
            'Control Plane status'
          }
        >
          <span
            className={`admin-health-dot ${healthDot}`}
            aria-hidden="true"
          />

          <span>
            {error
              ? 'Control Plane Error'
              : healthLabel}
          </span>
        </span>

        <button
          type="button"
          className="admin-exit-btn"
          onClick={onExit}
        >
          Exit Admin →
        </button>
      </div>

      {/* =====================================================================
          SYSTEM ERROR
          ===================================================================== */}

      {error && (
        <div
          className="admin-error"
          role="alert"
        >
          <div>
            <strong>
              Control Plane connection failure
            </strong>

            <span>
              {error}
            </span>
          </div>

          <button
            type="button"
            onClick={() => {
              void refreshSummary(true);
            }}
            disabled={refreshing}
          >
            {refreshing
              ? 'Retrying…'
              : 'Retry'}
          </button>
        </div>
      )}

      {/* =====================================================================
          INITIAL LOADING
          ===================================================================== */}

      {loading &&
        !summary &&
        !error && (
          <div
            className="admin-loading"
            role="status"
            aria-live="polite"
          >
            <span
              className="admin-health-dot unknown"
              aria-hidden="true"
            />

            Loading Control Plane
            projections…
          </div>
        )}

      {/* =====================================================================
          MODE SWITCHER
          ===================================================================== */}

      <div
        className="admin-mode-switch"
        role="tablist"
        aria-label="Admin mode"
      >
        {(
          [
            'OPERATE',
            'INVESTIGATE',
            'IMPROVE',
          ] as AdminMode[]
        ).map((candidateMode) => {
          const active =
            mode === candidateMode;

          return (
            <button
              key={candidateMode}
              type="button"
              role="tab"
              aria-selected={active}
              className={
                `admin-mode-btn${
                  active
                    ? ' active'
                    : ''
                }`
              }
              onClick={() => {
                setMode(
                  candidateMode,
                );
              }}
            >
              <span>
                {candidateMode}
              </span>

              <span className="mode-desc">
                {MODE_DESCRIPTIONS[
                  candidateMode
                ]}
              </span>
            </button>
          );
        })}
      </div>

      {/* =====================================================================
          DOMAIN NAVIGATION
          ===================================================================== */}

      <nav
        className="admin-nav"
        aria-label="Admin domain"
      >
        {navItems.map((item) => {
          const active =
            view === item.view;

          return (
            <button
              key={item.view}
              type="button"
              className={
                `admin-nav-btn${
                  active
                    ? ' active'
                    : ''
                }`
              }
              aria-current={
                active
                  ? 'page'
                  : undefined
              }
              title={
                item.description
              }
              onClick={() => {
                setView(item.view);
              }}
            >
              {item.label}
            </button>
          );
        })}
      </nav>

      {/* =====================================================================
          VIEW HEADER
          ===================================================================== */}

      <div className="admin-view-header">
        <div>
          <div className="admin-view-kicker">
            AMEXAN CONTROL PLANE
          </div>

          <h1>
            {VIEW_TITLES[view]}
          </h1>

          <p>
            {VIEW_DESCRIPTIONS[view]}
          </p>
        </div>

        <div className="admin-view-actions">
          {lastSuccessfulRefresh && (
            <span
              className="admin-refresh-time"
              title={
                lastSuccessfulRefresh.toISOString()
              }
            >
              Updated{' '}
              {lastSuccessfulRefresh.toLocaleTimeString()}
            </span>
          )}

          <button
            type="button"
            className="admin-refresh-btn"
            onClick={() => {
              void refreshSummary(
                true,
              );
            }}
            disabled={
              refreshing ||
              loading
            }
          >
            {refreshing
              ? 'Refreshing…'
              : 'Refresh'}
          </button>
        </div>
      </div>

      {/* =====================================================================
          CURRENT VIEW
          ===================================================================== */}

      <div
        key={view}
        className="admin-view"
        aria-label={
          VIEW_TITLES[view]
        }
      >
        {view === 'command' && (
          <CommandCenter
            onOpenEvent={
              handleOpenEvent
            }
          />
        )}

        {view === 'events' && (
          <EventExplorer
            initialSelection={selectedEvent}
          />
        )}

        {view === 'trace' && (
          <EncounterTrace />
        )}

        {view === 'engines' && (
          <EngineMonitor />
        )}

        {view === 'safety' && (
          <SafetyCenter />
        )}

        {view === 'config' && (
          <ConfigView />
        )}

        {view === 'versions' && (
          <VersionsView />
        )}

        {view === 'security' && (
          <SecurityView />
        )}

        {view === 'database' && (
          <DatabaseView />
        )}

        {view === 'runtime' && (
          <RuntimeView />
        )}

        {view === 'workflow' && (
          <WorkflowView />
        )}

        {view === 'incidents' && (
          <IncidentsView />
        )}

        {view === 'integrations' && (
          <IntegrationsView />
        )}

        {view === 'notifications' && (
          <NotificationsView />
        )}

        {view === 'analytics' && (
          <AnalyticsView />
        )}

        {view === 'catalogues' && (
          <ServiceCatalogueView />
        )}

        {view === 'assets' && (
          <AssetIntelligenceView />
        )}

        {view === 'financial' && (
          <FinancialView
            onBack={() => setView('command')}
          />
        )}

        {view === 'research' && (
          <ResearchView
            onBack={() => setView('command')}
          />
        )}
      </div>

      {/* =====================================================================
          CONTROL PLANE STATUS STRIP
          ===================================================================== */}

      <div
        className="admin-panel admin-status-panel"
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
          {/* Clinical workload */}

          <span>
            <strong>
              {activeEncounters.toLocaleString()}
            </strong>{' '}
            active encounters
          </span>

          <span>
            <strong>
              {openAlerts.toLocaleString()}
            </strong>{' '}
            open alerts
          </span>

          <span>
            <strong>
              {eventsTotal.toLocaleString()}
            </strong>{' '}
            events logged
          </span>

          {/* Engine registry */}

          <span>
            <strong>
              {engineCount.toLocaleString()}
            </strong>{' '}
            engines
          </span>

          {activeEngines !==
            undefined && (
            <span>
              <strong>
                {activeEngines.toLocaleString()}
              </strong>{' '}
              active engines
            </span>
          )}

          {degradedEngines !==
            undefined && (
            <span
              className={
                degradedEngines > 0
                  ? 'warning'
                  : undefined
              }
            >
              <strong>
                {degradedEngines.toLocaleString()}
              </strong>{' '}
              degraded engines
            </span>
          )}

          {failedEngines !==
            undefined && (
            <span
              className={
                failedEngines > 0
                  ? 'danger'
                  : undefined
              }
            >
              <strong>
                {failedEngines.toLocaleString()}
              </strong>{' '}
              failed engines
            </span>
          )}

          {/* Event pipeline */}

          {eventsLastMinute !==
            undefined && (
            <span>
              <strong>
                {eventsLastMinute.toLocaleString()}
              </strong>{' '}
              events/min
            </span>
          )}

          {pendingEvents !==
            undefined && (
            <span>
              <strong>
                {pendingEvents.toLocaleString()}
              </strong>{' '}
              pending events
            </span>
          )}

          {failedEvents !==
            undefined && (
            <span
              className={
                failedEvents > 0
                  ? 'warning'
                  : undefined
              }
            >
              <strong>
                {failedEvents.toLocaleString()}
              </strong>{' '}
              failed deliveries
            </span>
          )}

          {deadLetterEvents !==
            undefined && (
            <span
              className={
                deadLetterEvents > 0
                  ? 'danger'
                  : undefined
              }
            >
              <strong>
                {deadLetterEvents.toLocaleString()}
              </strong>{' '}
              dead-letter events
            </span>
          )}

          {/* Safety */}

          {safetyCritical !==
            undefined && (
            <span
              className={
                safetyCritical > 0
                  ? 'danger'
                  : undefined
              }
            >
              <strong>
                {safetyCritical.toLocaleString()}
              </strong>{' '}
              critical safety
            </span>
          )}

          {safetyUnresolved !==
            undefined && (
            <span
              className={
                safetyUnresolved > 0
                  ? 'warning'
                  : undefined
              }
            >
              <strong>
                {safetyUnresolved.toLocaleString()}
              </strong>{' '}
              unresolved safety
            </span>
          )}

          {/* Identity */}

          <span>
            <strong>
              {userAccounts.toLocaleString()}
            </strong>{' '}
            user accounts
          </span>

          {/* Control plane */}

          <span className="muted small">
            Control Plane · read-only ·{' '}
            generated{' '}
            {summary?.generatedAt ??
              '—'}
          </span>
        </div>
      </div>
    </div>
  );
}