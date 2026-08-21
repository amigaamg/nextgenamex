// =============================================================================
// AMEXAN Workflow — Control Plane Workflow Observatory
//
// INVESTIGATE / OPERATE / IMPROVE
//
// Purpose:
// - Observe every workflow instance, state transition, task, queue and worker.
// - Correlate workflow activity with encounters, users, facilities and events.
// - Surface stalled, failed, overdue, retried and manually-intervened work.
// - Show workflow throughput, latency, failure and intervention patterns.
// - Remain READ-ONLY from the Admin Workspace.
// - PostgreSQL is NEVER touched directly by this UI.
// - All data comes from the AMEXAN Control Plane API projections.
//
// AMEXAN WORKFLOW CHAIN:
//
//   Clinical UI
//       ↓
//   Domain Command
//       ↓
//   Application Service
//       ↓
//   Transaction
//       ↓
//   Domain Event
//       ↓
//   Event Bus / Outbox
//       ↓
//   Workflow Orchestrator
//       ↓
//   Workflow Instance
//       ↓
//   State Transition
//       ↓
//   Task / Queue
//       ↓
//   Worker / Engine
//       ↓
//   Result
//       ↓
//   Safety / Policy Evaluation
//       ↓
//   Event + Trace + Audit
//       ↓
//   Control Plane projections
//       ↓
//   THIS VIEW
//
// The UI is an OBSERVATORY, not the workflow engine itself.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { getWorkflowOverview } from '../api';
import type { WorkflowOverview } from '../types';

// =============================================================================
// TYPES
// =============================================================================

type WorkflowTab =
  | 'overview'
  | 'instances'
  | 'tasks'
  | 'queues'
  | 'interventions'
  | 'failures'
  | 'throughput';

type StatusTone =
  | 'ok'
  | 'warn'
  | 'bad'
  | 'info'
  | 'muted';

type WorkflowStatus =
  | 'RUNNING'
  | 'ACTIVE'
  | 'PENDING'
  | 'WAITING'
  | 'BLOCKED'
  | 'PAUSED'
  | 'COMPLETED'
  | 'FAILED'
  | 'CANCELLED'
  | 'RETRYING'
  | 'TIMED_OUT'
  | 'MANUAL'
  | string;

// =============================================================================
// OPTIONAL EXTENDED PROJECTION TYPES
//
// These are intentionally tolerant because the Control Plane may evolve while
// the admin workspace remains compatible with older projections.
//
// The API remains the source of truth.
// =============================================================================

interface WorkflowInstanceProjection {
  id: string;
  entityType?: string | null;
  entityId?: string | null;

  workflowCode?: string | null;
  workflowName?: string | null;
  workflowVersion?: string | number | null;

  currentStateCode?: string | null;
  currentStateId?: string | null;

  status?: WorkflowStatus | null;

  startedAt: string;
  updatedAt?: string | null;
  completedAt?: string | null;

  ownerType?: string | null;
  ownerId?: string | null;

  facilityId?: string | null;
  actorId?: string | null;

  retryCount?: number | null;
  attemptCount?: number | null;

  lastErrorCode?: string | null;
  lastErrorMessage?: string | null;

  manualIntervention?: boolean | null;
  interventionCount?: number | null;

  elapsedMs?: number | null;
}

interface WorkflowTaskProjection {
  id: string;

  name: string;
  taskType?: string | null;

  workflowInstanceId?: string | null;
  entityType?: string | null;
  entityId?: string | null;

  status?: WorkflowStatus | null;

  priority?: number | null;

  assignedTo?: string | null;
  assignedRole?: string | null;

  queueId?: string | null;

  createdAt?: string | null;
  startedAt?: string | null;
  completedAt?: string | null;
  dueAt?: string | null;

  retryCount?: number | null;
  attemptCount?: number | null;

  manual?: boolean | null;
  manualReason?: string | null;

  errorCode?: string | null;
  errorMessage?: string | null;
}

interface WorkflowQueueProjection {
  id: string;

  code: string;
  name: string;

  isActive: boolean;

  workerCount?: number | null;
  depth?: number | null;

  processingCount?: number | null;
  failedCount?: number | null;
  retryingCount?: number | null;

  oldestItemAt?: string | null;

  avgWaitMs?: number | null;
  avgProcessingMs?: number | null;
}

interface WorkflowQueueItemProjection {
  id: string;

  queueId: string;

  entityType?: string | null;
  entityId?: string | null;

  workflowInstanceId?: string | null;
  taskId?: string | null;

  priority?: number | null;

  status?: WorkflowStatus | null;

  enteredAt: string;
  startedAt?: string | null;
  completedAt?: string | null;

  attemptCount?: number | null;
  retryCount?: number | null;

  lockedBy?: string | null;
  lockExpiresAt?: string | null;

  lastErrorCode?: string | null;
  lastErrorMessage?: string | null;
}

interface WorkflowInterventionProjection {
  id: string;

  workflowInstanceId?: string | null;
  taskId?: string | null;
  queueItemId?: string | null;

  entityType?: string | null;
  entityId?: string | null;

  interventionType?: string | null;
  reason?: string | null;

  actorId?: string | null;
  actorType?: string | null;

  createdAt: string;

  beforeState?: string | null;
  afterState?: string | null;
}

interface WorkflowFailureProjection {
  id: string;

  workflowInstanceId?: string | null;
  taskId?: string | null;
  queueItemId?: string | null;

  entityType?: string | null;
  entityId?: string | null;

  errorCode?: string | null;
  message?: string | null;

  occurredAt: string;

  retryable?: boolean | null;
  retryCount?: number | null;

  resolved?: boolean | null;
}

interface WorkflowMetricsProjection {
  startedPerHour?: number | null;
  completedPerHour?: number | null;

  successRate?: number | null;
  failureRate?: number | null;

  interventionRate?: number | null;
  retryRate?: number | null;

  averageLatencyMs?: number | null;
  p95LatencyMs?: number | null;

  throughputPerMinute?: number | null;

  stalledCount?: number | null;
  overdueTaskCount?: number | null;
  failedTaskCount?: number | null;
}

// =============================================================================
// COMPATIBLE DATA ACCESS
// =============================================================================

type WorkflowProjection = WorkflowOverview & {
  interventions?: WorkflowInterventionProjection[];
  failures?: WorkflowFailureProjection[];
  metrics?: WorkflowMetricsProjection;
};

function getProjection(
  data: WorkflowOverview | null,
): WorkflowProjection | null {
  return data as WorkflowProjection | null;
}

function getInstances(
  data: WorkflowOverview | null,
): WorkflowInstanceProjection[] {
  return ((data?.instances ?? []) as unknown) as WorkflowInstanceProjection[];
}

function getTasks(
  data: WorkflowOverview | null,
): WorkflowTaskProjection[] {
  return ((data?.tasks ?? []) as unknown) as WorkflowTaskProjection[];
}

function getQueues(
  data: WorkflowOverview | null,
): WorkflowQueueProjection[] {
  return ((data?.queues ?? []) as unknown) as WorkflowQueueProjection[];
}

function getQueueItems(
  data: WorkflowOverview | null,
): WorkflowQueueItemProjection[] {
  return ((data?.queueItems ?? []) as unknown) as WorkflowQueueItemProjection[];
}

// =============================================================================
// HELPERS
// =============================================================================

function safeDate(value?: string | null): Date | null {
  if (!value) return null;

  const date = new Date(value);

  return Number.isNaN(date.getTime()) ? null : date;
}

function formatDate(value?: string | null): string {
  const date = safeDate(value);

  if (!date) return '—';

  return date.toLocaleString();
}

function formatRelative(value?: string | null): string {
  const date = safeDate(value);

  if (!date) return '—';

  const diff = Date.now() - date.getTime();

  if (diff < 0) return 'in future';

  const seconds = Math.floor(diff / 1000);

  if (seconds < 60) return `${seconds}s ago`;

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);

  if (hours < 24) return `${hours}h ago`;

  return `${Math.floor(hours / 24)}d ago`;
}

function formatDuration(ms?: number | null): string {
  if (ms == null || !Number.isFinite(ms)) return '—';

  if (ms < 1000) return `${Math.round(ms)} ms`;

  const seconds = ms / 1000;

  if (seconds < 60) return `${seconds.toFixed(1)} s`;

  const minutes = seconds / 60;

  if (minutes < 60) return `${minutes.toFixed(1)} min`;

  const hours = minutes / 60;

  return `${hours.toFixed(1)} h`;
}

function truncate(value?: string | null, length = 10): string {
  if (!value) return '—';

  if (value.length <= length) return value;

  return `${value.slice(0, length)}…`;
}

function normaliseStatus(
  status?: string | null,
): WorkflowStatus {
  return status?.toUpperCase() || 'UNKNOWN';
}

function statusTone(status?: string | null): StatusTone {
  switch (normaliseStatus(status)) {
    case 'COMPLETED':
      return 'ok';

    case 'RUNNING':
    case 'ACTIVE':
      return 'info';

    case 'PENDING':
    case 'WAITING':
    case 'RETRYING':
    case 'PAUSED':
    case 'MANUAL':
      return 'warn';

    case 'BLOCKED':
    case 'FAILED':
    case 'TIMED_OUT':
      return 'bad';

    case 'CANCELLED':
      return 'muted';

    default:
      return 'muted';
  }
}

function isActiveStatus(status?: string | null): boolean {
  return [
    'RUNNING',
    'ACTIVE',
    'PENDING',
    'WAITING',
    'BLOCKED',
    'PAUSED',
    'RETRYING',
    'MANUAL',
  ].includes(normaliseStatus(status));
}

function isFailureStatus(status?: string | null): boolean {
  return ['FAILED', 'TIMED_OUT'].includes(
    normaliseStatus(status),
  );
}

function isCompletedStatus(status?: string | null): boolean {
  return normaliseStatus(status) === 'COMPLETED';
}

// =============================================================================
// STATUS BADGE
// =============================================================================

function StatusBadge({
  status,
}: {
  status?: string | null;
}) {
  const tone = statusTone(status);
  const label = normaliseStatus(status);

  return (
    <span className={`admin-status-badge ${tone}`}>
      <span className="admin-status-dot" aria-hidden="true" />
      {label}
    </span>
  );
}

// =============================================================================
// METRIC TILE
// =============================================================================

function MetricTile({
  value,
  label,
  tone = 'default',
  detail,
}: {
  value: ReactNode;
  label: string;
  tone?: 'default' | 'ok' | 'warn' | 'bad' | 'info';
  detail?: ReactNode;
}) {
  return (
    <div className={`admin-tile workflow-metric ${tone}`}>
      <span className="admin-tile-value">
        {value}
      </span>

      <span className="admin-tile-label">
        {label}
      </span>

      {detail && (
        <span className="workflow-metric-detail">
          {detail}
        </span>
      )}
    </div>
  );
}

// =============================================================================
// SECTION HEADER
// =============================================================================

function SectionHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="admin-panel-head">
      <div>
        <div className="admin-panel-title">
          {title}
        </div>

        {subtitle && (
          <div className="admin-panel-sub">
            {subtitle}
          </div>
        )}
      </div>

      {actions}
    </div>
  );
}

// =============================================================================
// TABLE EMPTY
// =============================================================================

function EmptyState({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <div className="admin-empty">
      {children}
    </div>
  );
}

// =============================================================================
// WORKFLOW VIEW
// =============================================================================

export function WorkflowView() {
  const [data, setData] =
    useState<WorkflowOverview | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [error, setError] =
    useState<string | null>(null);

  const [tab, setTab] =
    useState<WorkflowTab>('overview');

  const [autoRefresh, setAutoRefresh] =
    useState(true);

  const [lastRefresh, setLastRefresh] =
    useState<Date | null>(null);

  const [selectedInstanceId, setSelectedInstanceId] =
    useState<string | null>(null);

  const [selectedTaskId, setSelectedTaskId] =
    useState<string | null>(null);

  const [search, setSearch] =
    useState('');

  const load = useCallback(async () => {
    setError(null);

    try {
      const result = await getWorkflowOverview();

      setData(result);
      setLastRefresh(new Date());
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : 'Failed to load workflow overview',
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (!autoRefresh) return;

    const timer = window.setInterval(() => {
      void load();
    }, 15000);

    return () => {
      window.clearInterval(timer);
    };
  }, [autoRefresh, load]);

  const projection = getProjection(data);

  const instances = useMemo(
    () => getInstances(data),
    [data],
  );

  const tasks = useMemo(
    () => getTasks(data),
    [data],
  );

  const queues = useMemo(
    () => getQueues(data),
    [data],
  );

  const queueItems = useMemo(
    () => getQueueItems(data),
    [data],
  );

  const interventions = useMemo(
    () => projection?.interventions ?? [],
    [projection],
  );

  const failures = useMemo(
    () => projection?.failures ?? [],
    [projection],
  );

  const metrics = projection?.metrics;

  // ===========================================================================
  // DERIVED WORKFLOW STATE
  // ===========================================================================

  const activeInstances = useMemo(
    () =>
      instances.filter((i) =>
        isActiveStatus(i.status),
      ),
    [instances],
  );

  const completedInstances = useMemo(
    () =>
      instances.filter((i) =>
        isCompletedStatus(i.status),
      ),
    [instances],
  );

  const failedInstances = useMemo(
    () =>
      instances.filter((i) =>
        isFailureStatus(i.status),
      ),
    [instances],
  );

  const blockedInstances = useMemo(
    () =>
      instances.filter(
        (i) =>
          normaliseStatus(i.status) === 'BLOCKED',
      ),
    [instances],
  );

  const manualInstances = useMemo(
    () =>
      instances.filter(
        (i) =>
          Boolean(i.manualIntervention) ||
          Number(i.interventionCount ?? 0) > 0,
      ),
    [instances],
  );

  const activeTasks = useMemo(
    () =>
      tasks.filter((t) =>
        isActiveStatus(t.status),
      ),
    [tasks],
  );

  const failedTasks = useMemo(
    () =>
      tasks.filter((t) =>
        isFailureStatus(t.status),
      ),
    [tasks],
  );

  const overdueTasks = useMemo(
    () =>
      tasks.filter((task) => {
        if (!task.dueAt) return false;

        const due = safeDate(task.dueAt);

        if (!due) return false;

        if (isCompletedStatus(task.status)) {
          return false;
        }

        return due.getTime() < Date.now();
      }),
    [tasks],
  );

  const failedQueues = useMemo(
    () =>
      queues.filter(
        (q) => Number(q.failedCount ?? 0) > 0,
      ),
    [queues],
  );

  const retryingQueues = useMemo(
    () =>
      queues.filter(
        (q) => Number(q.retryingCount ?? 0) > 0,
      ),
    [queues],
  );

  const blockedQueueItems = useMemo(
    () =>
      queueItems.filter((q) =>
        ['BLOCKED', 'FAILED'].includes(
          normaliseStatus(q.status),
        ),
      ),
    [queueItems],
  );

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  const normalizedSearch = search
    .trim()
    .toLowerCase();

  const filteredInstances = useMemo(() => {
    if (!normalizedSearch) return instances;

    return instances.filter((instance) =>
      [
        instance.id,
        instance.entityType,
        instance.entityId,
        instance.workflowCode,
        instance.workflowName,
        instance.currentStateCode,
        instance.status,
        instance.actorId,
        instance.facilityId,
      ]
        .filter(Boolean)
        .some((value) =>
          String(value)
            .toLowerCase()
            .includes(normalizedSearch),
        ),
    );
  }, [instances, normalizedSearch]);

  const filteredTasks = useMemo(() => {
    if (!normalizedSearch) return tasks;

    return tasks.filter((task) =>
      [
        task.id,
        task.name,
        task.taskType,
        task.workflowInstanceId,
        task.entityType,
        task.entityId,
        task.status,
        task.assignedTo,
        task.assignedRole,
        task.queueId,
      ]
        .filter(Boolean)
        .some((value) =>
          String(value)
            .toLowerCase()
            .includes(normalizedSearch),
        ),
    );
  }, [tasks, normalizedSearch]);

  const filteredQueues = useMemo(() => {
    if (!normalizedSearch) return queues;

    return queues.filter((queue) =>
      [
        queue.id,
        queue.code,
        queue.name,
      ]
        .filter(Boolean)
        .some((value) =>
          String(value)
            .toLowerCase()
            .includes(normalizedSearch),
        ),
    );
  }, [queues, normalizedSearch]);

  // ===========================================================================
  // SELECTED INSTANCE
  // ===========================================================================

  const selectedInstance = useMemo(
    () =>
      instances.find(
        (instance) =>
          instance.id === selectedInstanceId,
      ) ?? null,
    [instances, selectedInstanceId],
  );

  const selectedInstanceTasks = useMemo(
    () => {
      if (!selectedInstanceId) return [];

      return tasks.filter(
        (task) =>
          task.workflowInstanceId ===
          selectedInstanceId,
      );
    },
    [selectedInstanceId, tasks],
  );

  const selectedTask = useMemo(
    () =>
      tasks.find(
        (task) => task.id === selectedTaskId,
      ) ?? null,
    [tasks, selectedTaskId],
  );

  // ===========================================================================
  // INITIAL LOADING
  // ===========================================================================

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />

        Loading AMEXAN workflow control-plane…
      </div>
    );
  }

  if (error && !data) {
    return (
      <div
        className="admin-error"
        role="alert"
      >
        <strong>Workflow projection unavailable.</strong>

        <span style={{ display: 'block', marginTop: 6 }}>
          {error}
        </span>

        <button
          type="button"
          className="admin-nav-btn"
          style={{ marginTop: 12 }}
          onClick={() => void load()}
        >
          Retry
        </button>
      </div>
    );
  }

  // ===========================================================================
  // TAB NAVIGATION
  // ===========================================================================

  const tabs: {
    id: WorkflowTab;
    label: string;
    count?: number;
  }[] = [
    {
      id: 'overview',
      label: 'Overview',
    },
    {
      id: 'instances',
      label: 'Instances',
      count: instances.length,
    },
    {
      id: 'tasks',
      label: 'Tasks',
      count: tasks.length,
    },
    {
      id: 'queues',
      label: 'Queues',
      count: queues.length,
    },
    {
      id: 'interventions',
      label: 'Interventions',
      count: interventions.length,
    },
    {
      id: 'failures',
      label: 'Failures',
      count:
        failures.length ||
        failedInstances.length ||
        failedTasks.length,
    },
    {
      id: 'throughput',
      label: 'Throughput',
    },
  ];

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div className="amexan-workflow-view">

      {/* =====================================================================
          CONTROL HEADER
          ===================================================================== */}

      <div
        className="admin-panel"
        style={{ marginBottom: 16 }}
      >
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'center',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <div>
            <div className="admin-panel-title">
              Workflow Observatory
            </div>

            <div className="admin-panel-sub">
              Instances · State machines · Tasks · Queues · Workers ·
              Interventions · Failures
            </div>
          </div>

          <div
            style={{
              marginLeft: 'auto',
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              flexWrap: 'wrap',
            }}
          >
            <label
              className="admin-inline-control"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
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

              Live
            </label>

            <button
              type="button"
              className="admin-nav-btn"
              onClick={() => void load()}
              disabled={loading}
            >
              {loading ? 'Refreshing…' : 'Refresh'}
            </button>
          </div>
        </div>

        <div
          style={{
            display: 'flex',
            gap: 8,
            alignItems: 'center',
            flexWrap: 'wrap',
            marginTop: 12,
          }}
        >
          <input
            type="search"
            value={search}
            onChange={(event) =>
              setSearch(event.target.value)
            }
            placeholder="Search instance, encounter, task, queue, workflow, actor…"
            aria-label="Search workflow"
            className="admin-search-input"
            style={{
              minWidth: 260,
              flex: 1,
            }}
          />

          {lastRefresh && (
            <span className="muted small">
              Updated {lastRefresh.toLocaleTimeString()}
            </span>
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
          TAB BAR
          ===================================================================== */}

      <nav
        className="admin-nav"
        aria-label="Workflow domain"
      >
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            className={`admin-nav-btn${
              tab === item.id ? ' active' : ''
            }`}
            onClick={() => setTab(item.id)}
          >
            {item.label}

            {item.count != null && (
              <span
                style={{
                  marginLeft: 6,
                  opacity: 0.65,
                }}
              >
                {item.count}
              </span>
            )}
          </button>
        ))}
      </nav>

      {/* =====================================================================
          OVERVIEW
          ===================================================================== */}

      {tab === 'overview' && (
        <div>

          <div className="admin-tile-grid">

            <MetricTile
              value={instances.length}
              label="Workflow instances"
            />

            <MetricTile
              value={activeInstances.length}
              label="Active instances"
              tone={
                activeInstances.length > 0
                  ? 'warn'
                  : 'ok'
              }
            />

            <MetricTile
              value={completedInstances.length}
              label="Completed"
              tone="ok"
            />

            <MetricTile
              value={failedInstances.length}
              label="Failed"
              tone={
                failedInstances.length > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={blockedInstances.length}
              label="Blocked"
              tone={
                blockedInstances.length > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={activeTasks.length}
              label="Active tasks"
              tone={
                activeTasks.length > 0
                  ? 'info'
                  : 'ok'
              }
            />

            <MetricTile
              value={overdueTasks.length}
              label="Overdue tasks"
              tone={
                overdueTasks.length > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={queueItems.length}
              label="Queue items"
              tone={
                queueItems.length > 0
                  ? 'info'
                  : 'ok'
              }
            />

          </div>

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >

            {/* WORKFLOW HEALTH */}

            <div className="admin-panel">
              <SectionHeader
                title="Workflow health"
                subtitle="Current control-plane state"
              />

              <div
                className="workflow-health-list"
                style={{
                  display: 'grid',
                  gap: 10,
                }}
              >

                <div className="workflow-health-row">
                  <span>Active instances</span>
                  <strong>
                    {activeInstances.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Blocked instances</span>
                  <strong>
                    {blockedInstances.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Failed instances</span>
                  <strong>
                    {failedInstances.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Manual interventions</span>
                  <strong>
                    {manualInstances.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Overdue tasks</span>
                  <strong>
                    {overdueTasks.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Failed queues</span>
                  <strong>
                    {failedQueues.length}
                  </strong>
                </div>

              </div>
            </div>

            {/* ENGINE / QUEUE HEALTH */}

            <div className="admin-panel">
              <SectionHeader
                title="Execution fabric"
                subtitle="Queues and worker pressure"
              />

              <div
                className="workflow-health-list"
                style={{
                  display: 'grid',
                  gap: 10,
                }}
              >

                <div className="workflow-health-row">
                  <span>Queues</span>
                  <strong>
                    {queues.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Queue depth</span>
                  <strong>
                    {queues.reduce(
                      (sum, queue) =>
                        sum +
                        Number(queue.depth ?? 0),
                      0,
                    )}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Processing</span>
                  <strong>
                    {queues.reduce(
                      (sum, queue) =>
                        sum +
                        Number(
                          queue.processingCount ?? 0,
                        ),
                      0,
                    )}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Retrying</span>
                  <strong>
                    {queues.reduce(
                      (sum, queue) =>
                        sum +
                        Number(
                          queue.retryingCount ?? 0,
                        ),
                      0,
                    )}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Failed queue items</span>
                  <strong>
                    {blockedQueueItems.length}
                  </strong>
                </div>

              </div>
            </div>

          </div>

          {/* ACTIVE WORK */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Active workflow activity"
              subtitle="Work currently moving through AMEXAN"
              actions={
                <button
                  type="button"
                  className="admin-nav-btn"
                  onClick={() =>
                    setTab('instances')
                  }
                >
                  View all
                </button>
              }
            />

            {activeInstances.length === 0 ? (
              <EmptyState>
                No active workflow instances.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Workflow</th>
                      <th>Entity</th>
                      <th>State</th>
                      <th>Status</th>
                      <th>Retries</th>
                      <th>Updated</th>
                    </tr>
                  </thead>

                  <tbody>
                    {activeInstances
                      .slice(0, 20)
                      .map((instance) => (
                        <tr
                          key={instance.id}
                          onClick={() =>
                            setSelectedInstanceId(
                              instance.id,
                            )
                          }
                          style={{
                            cursor: 'pointer',
                          }}
                        >
                          <td>
                            <strong>
                              {instance.workflowName ??
                                instance.workflowCode ??
                                'Workflow'}
                            </strong>

                            <div className="muted small mono">
                              {truncate(
                                instance.id,
                                12,
                              )}
                            </div>
                          </td>

                          <td className="mono">
                            {instance.entityType ?? '—'}{' '}
                            {truncate(
                              instance.entityId,
                              10,
                            )}
                          </td>

                          <td className="mono">
                            {instance.currentStateCode ??
                              truncate(
                                instance.currentStateId,
                                10,
                              )}
                          </td>

                          <td>
                            <StatusBadge
                              status={
                                instance.status
                              }
                            />
                          </td>

                          <td className="num">
                            {instance.retryCount ??
                              0}
                          </td>

                          <td className="mono">
                            {formatRelative(
                              instance.updatedAt ??
                                instance.startedAt,
                            )}
                          </td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

        </div>
      )}

      {/* =====================================================================
          INSTANCES
          ===================================================================== */}

      {tab === 'instances' && (
        <div className="admin-panel">

          <SectionHeader
            title="Workflow instances"
            subtitle="State machines executing AMEXAN business and clinical workflows"
          />

          {filteredInstances.length === 0 ? (
            <EmptyState>
              No workflow instances match the current filter.
            </EmptyState>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Workflow</th>
                    <th>Entity</th>
                    <th>State</th>
                    <th>Status</th>
                    <th>Version</th>
                    <th>Retries</th>
                    <th>Intervention</th>
                    <th>Started</th>
                  </tr>
                </thead>

                <tbody>
                  {filteredInstances.map(
                    (instance) => (
                      <tr
                        key={instance.id}
                        onClick={() =>
                          setSelectedInstanceId(
                            instance.id,
                          )
                        }
                        style={{
                          cursor: 'pointer',
                        }}
                      >
                        <td>
                          <strong>
                            {instance.workflowName ??
                              instance.workflowCode ??
                              '—'}
                          </strong>

                          <div className="muted small mono">
                            {truncate(
                              instance.id,
                              14,
                            )}
                          </div>
                        </td>

                        <td className="mono">
                          {instance.entityType ??
                            '—'}{' '}
                          {truncate(
                            instance.entityId,
                            12,
                          )}
                        </td>

                        <td className="mono">
                          {instance.currentStateCode ??
                            truncate(
                              instance.currentStateId,
                              12,
                            )}
                        </td>

                        <td>
                          <StatusBadge
                            status={
                              instance.status
                            }
                          />
                        </td>

                        <td className="mono">
                          {instance.workflowVersion ??
                            '—'}
                        </td>

                        <td className="num">
                          {instance.retryCount ??
                            0}
                        </td>

                        <td>
                          {instance.manualIntervention ||
                          Number(
                            instance.interventionCount ??
                              0,
                          ) > 0 ? (
                            <span className="admin-status-badge warn">
                              manual
                            </span>
                          ) : (
                            <span className="muted">
                              none
                            </span>
                          )}
                        </td>

                        <td className="mono">
                          {formatDate(
                            instance.startedAt,
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
      )}

      {/* =====================================================================
          TASKS
          ===================================================================== */}

      {tab === 'tasks' && (
        <div className="admin-panel">

          <SectionHeader
            title="Workflow tasks"
            subtitle="Human tasks and machine work items emitted by workflow execution"
          />

          {filteredTasks.length === 0 ? (
            <EmptyState>
              No workflow tasks match the current filter.
            </EmptyState>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Task</th>
                    <th>Type</th>
                    <th>Instance</th>
                    <th>Status</th>
                    <th>Priority</th>
                    <th>Assigned</th>
                    <th>Attempts</th>
                    <th>Due</th>
                  </tr>
                </thead>

                <tbody>
                  {filteredTasks.map((task) => (
                    <tr
                      key={task.id}
                      onClick={() =>
                        setSelectedTaskId(
                          task.id,
                        )
                      }
                      style={{
                        cursor: 'pointer',
                      }}
                    >
                      <td>
                        <strong>
                          {task.name ||
                            truncate(
                              task.id,
                              12,
                            )}
                        </strong>

                        {task.manual && (
                          <div className="muted small">
                            manual
                          </div>
                        )}
                      </td>

                      <td className="mono">
                        {task.taskType ?? '—'}
                      </td>

                      <td className="mono">
                        {truncate(
                          task.workflowInstanceId,
                          12,
                        )}
                      </td>

                      <td>
                        <StatusBadge
                          status={task.status}
                        />
                      </td>

                      <td className="num">
                        {task.priority ?? 0}
                      </td>

                      <td>
                        {task.assignedTo ??
                          task.assignedRole ??
                          '—'}
                      </td>

                      <td className="num">
                        {task.attemptCount ??
                          task.retryCount ??
                          0}
                      </td>

                      <td
                        className={`mono${
                          overdueTasks.some(
                            (item) =>
                              item.id === task.id,
                          )
                            ? ' warn'
                            : ''
                        }`}
                      >
                        {formatDate(task.dueAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

        </div>
      )}

      {/* =====================================================================
          QUEUES
          ===================================================================== */}

      {tab === 'queues' && (
        <div>

          <div className="admin-tile-grid">

            <MetricTile
              value={queues.length}
              label="Queues"
            />

            <MetricTile
              value={queues.reduce(
                (sum, queue) =>
                  sum +
                  Number(queue.depth ?? 0),
                0,
              )}
              label="Queue depth"
              tone="info"
            />

            <MetricTile
              value={queues.reduce(
                (sum, queue) =>
                  sum +
                  Number(
                    queue.processingCount ?? 0,
                  ),
                0,
              )}
              label="Processing"
            />

            <MetricTile
              value={queues.reduce(
                (sum, queue) =>
                  sum +
                  Number(
                    queue.retryingCount ?? 0,
                  ),
                0,
              )}
              label="Retrying"
              tone={
                retryingQueues.length > 0
                  ? 'warn'
                  : 'ok'
              }
            />

            <MetricTile
              value={queues.reduce(
                (sum, queue) =>
                  sum +
                  Number(
                    queue.failedCount ?? 0,
                  ),
                0,
              )}
              label="Failed"
              tone={
                failedQueues.length > 0
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
              title="Queue fabric"
              subtitle="Routing, worker pressure and execution latency"
            />

            {filteredQueues.length === 0 ? (
              <EmptyState>
                No workflow queues.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Queue</th>
                      <th>State</th>
                      <th>Workers</th>
                      <th>Depth</th>
                      <th>Processing</th>
                      <th>Retrying</th>
                      <th>Failed</th>
                      <th>Avg wait</th>
                      <th>Avg processing</th>
                    </tr>
                  </thead>

                  <tbody>
                    {filteredQueues.map(
                      (queue) => (
                        <tr key={queue.id}>
                          <td>
                            <strong>
                              {queue.name}
                            </strong>

                            <div className="muted small mono">
                              {queue.code}
                            </div>
                          </td>

                          <td>
                            {queue.isActive ? (
                              <span className="admin-status-badge ok">
                                active
                              </span>
                            ) : (
                              <span className="admin-status-badge muted">
                                inactive
                              </span>
                            )}
                          </td>

                          <td className="num">
                            {queue.workerCount ??
                              0}
                          </td>

                          <td className="num">
                            {queue.depth ?? 0}
                          </td>

                          <td className="num">
                            {queue.processingCount ??
                              0}
                          </td>

                          <td className="num">
                            {queue.retryingCount ??
                              0}
                          </td>

                          <td className="num">
                            {queue.failedCount ??
                              0}
                          </td>

                          <td className="mono">
                            {formatDuration(
                              queue.avgWaitMs,
                            )}
                          </td>

                          <td className="mono">
                            {formatDuration(
                              queue.avgProcessingMs,
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

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Queue items"
              subtitle="Individual messages waiting for workflow execution"
            />

            {queueItems.length === 0 ? (
              <EmptyState>
                No queue items.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Queue</th>
                      <th>Entity</th>
                      <th>Workflow</th>
                      <th>Task</th>
                      <th>Priority</th>
                      <th>Status</th>
                      <th>Attempts</th>
                      <th>Entered</th>
                    </tr>
                  </thead>

                  <tbody>
                    {queueItems.map(
                      (item) => (
                        <tr key={item.id}>
                          <td className="mono">
                            {truncate(
                              item.queueId,
                              12,
                            )}
                          </td>

                          <td className="mono">
                            {item.entityType ??
                              '—'}{' '}
                            {truncate(
                              item.entityId,
                              10,
                            )}
                          </td>

                          <td className="mono">
                            {truncate(
                              item.workflowInstanceId,
                              10,
                            )}
                          </td>

                          <td className="mono">
                            {truncate(
                              item.taskId,
                              10,
                            )}
                          </td>

                          <td className="num">
                            {item.priority ?? 0}
                          </td>

                          <td>
                            <StatusBadge
                              status={
                                item.status
                              }
                            />
                          </td>

                          <td className="num">
                            {item.attemptCount ??
                              item.retryCount ??
                              0}
                          </td>

                          <td className="mono">
                            {formatDate(
                              item.enteredAt,
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
      )}

      {/* =====================================================================
          INTERVENTIONS
          ===================================================================== */}

      {tab === 'interventions' && (
        <div className="admin-panel">

          <SectionHeader
            title="Manual interventions"
            subtitle="Human interaction with otherwise automated workflow execution"
          />

          {interventions.length === 0 ? (
            <EmptyState>
              No recorded workflow interventions in the current projection.
            </EmptyState>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Intervention</th>
                    <th>Entity</th>
                    <th>Workflow</th>
                    <th>Actor</th>
                    <th>Before</th>
                    <th>After</th>
                    <th>Reason</th>
                  </tr>
                </thead>

                <tbody>
                  {interventions.map(
                    (intervention) => (
                      <tr
                        key={intervention.id}
                      >
                        <td className="mono">
                          {formatDate(
                            intervention.createdAt,
                          )}
                        </td>

                        <td>
                          {intervention.interventionType ??
                            'manual'}
                        </td>

                        <td className="mono">
                          {intervention.entityType ??
                            '—'}{' '}
                          {truncate(
                            intervention.entityId,
                            10,
                          )}
                        </td>

                        <td className="mono">
                          {truncate(
                            intervention.workflowInstanceId,
                            10,
                          )}
                        </td>

                        <td>
                          {intervention.actorId ??
                            intervention.actorType ??
                            '—'}
                        </td>

                        <td className="mono">
                          {intervention.beforeState ??
                            '—'}
                        </td>

                        <td className="mono">
                          {intervention.afterState ??
                            '—'}
                        </td>

                        <td>
                          {intervention.reason ??
                            '—'}
                        </td>
                      </tr>
                    ),
                  )}
                </tbody>
              </table>
            </div>
          )}

        </div>
      )}

      {/* =====================================================================
          FAILURES
          ===================================================================== */}

      {tab === 'failures' && (
        <div>

          <div className="admin-tile-grid">

            <MetricTile
              value={failures.length}
              label="Recorded failures"
              tone={
                failures.length > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={failedInstances.length}
              label="Failed instances"
              tone={
                failedInstances.length > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={failedTasks.length}
              label="Failed tasks"
              tone={
                failedTasks.length > 0
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={blockedQueueItems.length}
              label="Blocked queue items"
              tone={
                blockedQueueItems.length > 0
                  ? 'warn'
                  : 'ok'
              }
            />

          </div>

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Failure stream"
              subtitle="Workflow execution failures projected by the Control Plane"
            />

            {failures.length === 0 ? (
              <EmptyState>
                No recorded workflow failures.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Occurred</th>
                      <th>Error</th>
                      <th>Message</th>
                      <th>Workflow</th>
                      <th>Entity</th>
                      <th>Retryable</th>
                      <th>Retries</th>
                      <th>Resolved</th>
                    </tr>
                  </thead>

                  <tbody>
                    {failures.map(
                      (failure) => (
                        <tr key={failure.id}>
                          <td className="mono">
                            {formatDate(
                              failure.occurredAt,
                            )}
                          </td>

                          <td className="mono">
                            {failure.errorCode ??
                              'UNKNOWN'}
                          </td>

                          <td>
                            {failure.message ??
                              '—'}
                          </td>

                          <td className="mono">
                            {truncate(
                              failure.workflowInstanceId,
                              12,
                            )}
                          </td>

                          <td className="mono">
                            {failure.entityType ??
                              '—'}{' '}
                            {truncate(
                              failure.entityId,
                              10,
                            )}
                          </td>

                          <td>
                            {failure.retryable
                              ? 'yes'
                              : 'no'}
                          </td>

                          <td className="num">
                            {failure.retryCount ??
                              0}
                          </td>

                          <td>
                            {failure.resolved
                              ? 'yes'
                              : 'no'}
                          </td>
                        </tr>
                      ),
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {/* INSTANCE FAILURES */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Failed workflow instances"
              subtitle="State machines requiring investigation"
            />

            {failedInstances.length === 0 ? (
              <EmptyState>
                No failed workflow instances.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Workflow</th>
                      <th>Entity</th>
                      <th>State</th>
                      <th>Error</th>
                      <th>Retries</th>
                      <th>Updated</th>
                    </tr>
                  </thead>

                  <tbody>
                    {failedInstances.map(
                      (instance) => (
                        <tr
                          key={instance.id}
                          onClick={() =>
                            setSelectedInstanceId(
                              instance.id,
                            )
                          }
                          style={{
                            cursor: 'pointer',
                          }}
                        >
                          <td>
                            {instance.workflowName ??
                              instance.workflowCode ??
                              '—'}
                          </td>

                          <td className="mono">
                            {instance.entityType ??
                              '—'}{' '}
                            {truncate(
                              instance.entityId,
                              10,
                            )}
                          </td>

                          <td className="mono">
                            {instance.currentStateCode ??
                              '—'}
                          </td>

                          <td>
                            <span className="mono">
                              {instance.lastErrorCode ??
                                'UNKNOWN'}
                            </span>

                            {instance.lastErrorMessage && (
                              <div className="muted small">
                                {
                                  instance.lastErrorMessage
                                }
                              </div>
                            )}
                          </td>

                          <td className="num">
                            {instance.retryCount ??
                              0}
                          </td>

                          <td className="mono">
                            {formatDate(
                              instance.updatedAt,
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
      )}

      {/* =====================================================================
          THROUGHPUT
          ===================================================================== */}

      {tab === 'throughput' && (
        <div>

          <div className="admin-tile-grid">

            <MetricTile
              value={
                metrics?.throughputPerMinute !=
                null
                  ? metrics.throughputPerMinute.toFixed(
                      2,
                    )
                  : '—'
              }
              label="Throughput / min"
              tone="info"
            />

            <MetricTile
              value={
                metrics?.startedPerHour != null
                  ? metrics.startedPerHour.toFixed(
                      1,
                    )
                  : '—'
              }
              label="Started / hour"
            />

            <MetricTile
              value={
                metrics?.completedPerHour !=
                null
                  ? metrics.completedPerHour.toFixed(
                      1,
                    )
                  : '—'
              }
              label="Completed / hour"
              tone="ok"
            />

            <MetricTile
              value={
                metrics?.successRate != null
                  ? `${(
                      metrics.successRate * 100
                    ).toFixed(1)}%`
                  : '—'
              }
              label="Success rate"
              tone="ok"
            />

            <MetricTile
              value={
                metrics?.failureRate != null
                  ? `${(
                      metrics.failureRate * 100
                    ).toFixed(1)}%`
                  : '—'
              }
              label="Failure rate"
              tone={
                (metrics?.failureRate ?? 0) >
                0.05
                  ? 'bad'
                  : 'ok'
              }
            />

            <MetricTile
              value={
                metrics?.interventionRate !=
                null
                  ? `${(
                      metrics.interventionRate *
                      100
                    ).toFixed(1)}%`
                  : `${manualInstances.length}`
              }
              label="Intervention rate"
              tone={
                (metrics?.interventionRate ?? 0) >
                0.1
                  ? 'warn'
                  : 'ok'
              }
            />

            <MetricTile
              value={
                metrics?.averageLatencyMs !=
                null
                  ? formatDuration(
                      metrics.averageLatencyMs,
                    )
                  : '—'
              }
              label="Average latency"
            />

            <MetricTile
              value={
                metrics?.p95LatencyMs != null
                  ? formatDuration(
                      metrics.p95LatencyMs,
                    )
                  : '—'
              }
              label="P95 latency"
              tone={
                (metrics?.p95LatencyMs ?? 0) >
                5000
                  ? 'warn'
                  : 'ok'
              }
            />

          </div>

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >

            <div className="admin-panel">
              <SectionHeader
                title="Execution performance"
                subtitle="Workflow processing behaviour"
              />

              <div
                className="workflow-health-list"
                style={{
                  display: 'grid',
                  gap: 10,
                }}
              >
                <div className="workflow-health-row">
                  <span>
                    Average latency
                  </span>

                  <strong>
                    {formatDuration(
                      metrics?.averageLatencyMs,
                    )}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>P95 latency</span>

                  <strong>
                    {formatDuration(
                      metrics?.p95LatencyMs,
                    )}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>
                    Retry rate
                  </span>

                  <strong>
                    {metrics?.retryRate !=
                    null
                      ? `${(
                          metrics.retryRate *
                          100
                        ).toFixed(1)}%`
                      : '—'}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>
                    Intervention rate
                  </span>

                  <strong>
                    {metrics?.interventionRate !=
                    null
                      ? `${(
                          metrics.interventionRate *
                          100
                        ).toFixed(1)}%`
                      : '—'}
                  </strong>
                </div>
              </div>
            </div>

            <div className="admin-panel">
              <SectionHeader
                title="Operational pressure"
                subtitle="Signals requiring investigation"
              />

              <div
                className="workflow-health-list"
                style={{
                  display: 'grid',
                  gap: 10,
                }}
              >
                <div className="workflow-health-row">
                  <span>Stalled workflows</span>

                  <strong>
                    {metrics?.stalledCount ??
                      blockedInstances.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Overdue tasks</span>

                  <strong>
                    {metrics?.overdueTaskCount ??
                      overdueTasks.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Failed tasks</span>

                  <strong>
                    {metrics?.failedTaskCount ??
                      failedTasks.length}
                  </strong>
                </div>

                <div className="workflow-health-row">
                  <span>Queue pressure</span>

                  <strong>
                    {queueItems.length}
                  </strong>
                </div>
              </div>
            </div>

          </div>

          {/* WORKFLOW DISTRIBUTION */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <SectionHeader
              title="Workflow distribution"
              subtitle="Current workflow families represented in the projection"
            />

            {instances.length === 0 ? (
              <EmptyState>
                No workflow instances.
              </EmptyState>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Workflow</th>
                      <th>Total</th>
                      <th>Active</th>
                      <th>Completed</th>
                      <th>Failed</th>
                      <th>Manual</th>
                    </tr>
                  </thead>

                  <tbody>
                    {Array.from(
                      instances.reduce(
                        (
                          map,
                          instance,
                        ) => {
                          const key =
                            instance.workflowCode ??
                            instance.workflowName ??
                            'UNKNOWN';

                          const current =
                            map.get(key) ?? {
                              total: 0,
                              active: 0,
                              completed: 0,
                              failed: 0,
                              manual: 0,
                            };

                          current.total += 1;

                          if (
                            isActiveStatus(
                              instance.status,
                            )
                          ) {
                            current.active += 1;
                          }

                          if (
                            isCompletedStatus(
                              instance.status,
                            )
                          ) {
                            current.completed += 1;
                          }

                          if (
                            isFailureStatus(
                              instance.status,
                            )
                          ) {
                            current.failed += 1;
                          }

                          if (
                            instance.manualIntervention ||
                            Number(
                              instance.interventionCount ??
                                0,
                            ) > 0
                          ) {
                            current.manual += 1;
                          }

                          map.set(
                            key,
                            current,
                          );

                          return map;
                        },
                        new Map<
                          string,
                          {
                            total: number;
                            active: number;
                            completed: number;
                            failed: number;
                            manual: number;
                          }
                        >(),
                      ),
                    ).map(
                      ([
                        workflow,
                        stats,
                      ]) => (
                        <tr key={workflow}>
                          <td>
                            {workflow}
                          </td>

                          <td className="num">
                            {stats.total}
                          </td>

                          <td className="num">
                            {stats.active}
                          </td>

                          <td className="num">
                            {stats.completed}
                          </td>

                          <td className="num">
                            {stats.failed}
                          </td>

                          <td className="num">
                            {stats.manual}
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
      )}

      {/* =====================================================================
          INSTANCE DETAIL DRAWER
          ===================================================================== */}

      {selectedInstance && (
        <div
          className="admin-drawer-backdrop"
          role="presentation"
          onClick={() =>
            setSelectedInstanceId(null)
          }
        >
          <aside
            className="admin-drawer"
            role="dialog"
            aria-modal="true"
            aria-label="Workflow instance details"
            onClick={(event) =>
              event.stopPropagation()
            }
          >

            <div className="admin-panel-head">
              <div>
                <div className="admin-panel-title">
                  Workflow instance
                </div>

                <div className="admin-panel-sub mono">
                  {selectedInstance.id}
                </div>
              </div>

              <button
                type="button"
                className="admin-exit-btn"
                onClick={() =>
                  setSelectedInstanceId(null)
                }
                aria-label="Close"
              >
                ×
              </button>
            </div>

            <div
              style={{
                display: 'grid',
                gap: 12,
                marginTop: 16,
              }}
            >

              <div className="workflow-detail-row">
                <span>Workflow</span>

                <strong>
                  {selectedInstance.workflowName ??
                    selectedInstance.workflowCode ??
                    '—'}
                </strong>
              </div>

              <div className="workflow-detail-row">
                <span>Entity</span>

                <span className="mono">
                  {selectedInstance.entityType ??
                    '—'}{' '}
                  {selectedInstance.entityId ??
                    ''}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>State</span>

                <span className="mono">
                  {selectedInstance.currentStateCode ??
                    selectedInstance.currentStateId ??
                    '—'}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Status</span>

                <StatusBadge
                  status={
                    selectedInstance.status
                  }
                />
              </div>

              <div className="workflow-detail-row">
                <span>Version</span>

                <span className="mono">
                  {selectedInstance.workflowVersion ??
                    '—'}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Started</span>

                <span>
                  {formatDate(
                    selectedInstance.startedAt,
                  )}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Updated</span>

                <span>
                  {formatDate(
                    selectedInstance.updatedAt,
                  )}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Retries</span>

                <span>
                  {selectedInstance.retryCount ??
                    0}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Manual intervention</span>

                <span>
                  {selectedInstance.manualIntervention ||
                  Number(
                    selectedInstance.interventionCount ??
                      0,
                  ) > 0
                    ? 'yes'
                    : 'no'}
                </span>
              </div>

              {selectedInstance.lastErrorCode && (
                <div
                  className="admin-error"
                  style={{ marginTop: 8 }}
                >
                  <strong>
                    {selectedInstance.lastErrorCode}
                  </strong>

                  {selectedInstance.lastErrorMessage && (
                    <div style={{ marginTop: 6 }}>
                      {
                        selectedInstance.lastErrorMessage
                      }
                    </div>
                  )}
                </div>
              )}

            </div>

            <div
              className="admin-panel"
              style={{ marginTop: 20 }}
            >
              <SectionHeader
                title="Instance tasks"
                subtitle={`${selectedInstanceTasks.length} task(s)`}
              />

              {selectedInstanceTasks.length ===
              0 ? (
                <EmptyState>
                  No projected tasks for this instance.
                </EmptyState>
              ) : (
                <div
                  style={{
                    display: 'grid',
                    gap: 8,
                  }}
                >
                  {selectedInstanceTasks.map(
                    (task) => (
                      <button
                        key={task.id}
                        type="button"
                        className="workflow-detail-card"
                        onClick={() => {
                          setSelectedTaskId(
                            task.id,
                          );
                          setSelectedInstanceId(
                            null,
                          );
                        }}
                      >
                        <span>
                          <strong>
                            {task.name}
                          </strong>

                          <span className="muted small">
                            {task.taskType ??
                              'task'}
                          </span>
                        </span>

                        <StatusBadge
                          status={task.status}
                        />
                      </button>
                    ),
                  )}
                </div>
              )}
            </div>

          </aside>
        </div>
      )}

      {/* =====================================================================
          TASK DETAIL DRAWER
          ===================================================================== */}

      {selectedTask && (
        <div
          className="admin-drawer-backdrop"
          role="presentation"
          onClick={() =>
            setSelectedTaskId(null)
          }
        >
          <aside
            className="admin-drawer"
            role="dialog"
            aria-modal="true"
            aria-label="Workflow task details"
            onClick={(event) =>
              event.stopPropagation()
            }
          >

            <div className="admin-panel-head">
              <div>
                <div className="admin-panel-title">
                  Workflow task
                </div>

                <div className="admin-panel-sub mono">
                  {selectedTask.id}
                </div>
              </div>

              <button
                type="button"
                className="admin-exit-btn"
                onClick={() =>
                  setSelectedTaskId(null)
                }
              >
                ×
              </button>
            </div>

            <div
              style={{
                display: 'grid',
                gap: 12,
                marginTop: 16,
              }}
            >

              <div className="workflow-detail-row">
                <span>Name</span>

                <strong>
                  {selectedTask.name}
                </strong>
              </div>

              <div className="workflow-detail-row">
                <span>Type</span>

                <span className="mono">
                  {selectedTask.taskType ??
                    '—'}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Status</span>

                <StatusBadge
                  status={selectedTask.status}
                />
              </div>

              <div className="workflow-detail-row">
                <span>Priority</span>

                <span>
                  {selectedTask.priority ??
                    0}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Queue</span>

                <span className="mono">
                  {selectedTask.queueId ??
                    '—'}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Assigned to</span>

                <span>
                  {selectedTask.assignedTo ??
                    selectedTask.assignedRole ??
                    '—'}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Attempts</span>

                <span>
                  {selectedTask.attemptCount ??
                    selectedTask.retryCount ??
                    0}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Created</span>

                <span>
                  {formatDate(
                    selectedTask.createdAt,
                  )}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Started</span>

                <span>
                  {formatDate(
                    selectedTask.startedAt,
                  )}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Completed</span>

                <span>
                  {formatDate(
                    selectedTask.completedAt,
                  )}
                </span>
              </div>

              <div className="workflow-detail-row">
                <span>Due</span>

                <span>
                  {formatDate(
                    selectedTask.dueAt,
                  )}
                </span>
              </div>

              {selectedTask.manual && (
                <div
                  className="admin-error"
                  style={{ marginTop: 8 }}
                >
                  <strong>
                    Manual task
                  </strong>

                  {selectedTask.manualReason && (
                    <div style={{ marginTop: 6 }}>
                      {
                        selectedTask.manualReason
                      }
                    </div>
                  )}
                </div>
              )}

              {selectedTask.errorCode && (
                <div
                  className="admin-error"
                  style={{ marginTop: 8 }}
                >
                  <strong>
                    {selectedTask.errorCode}
                  </strong>

                  {selectedTask.errorMessage && (
                    <div style={{ marginTop: 6 }}>
                      {
                        selectedTask.errorMessage
                      }
                    </div>
                  )}
                </div>
              )}

            </div>

          </aside>
        </div>
      )}

    </div>
  );
}