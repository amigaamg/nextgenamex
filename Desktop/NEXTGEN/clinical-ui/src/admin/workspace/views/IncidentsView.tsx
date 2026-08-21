// =============================================================================
// AMEXAN Incidents — Control Plane Incident Observatory
//
// INVESTIGATE / IMPROVE
//
// PURPOSE
// -----------------------------------------------------------------------------
// Incident registry for the entire AMEXAN platform.
//
// The incident layer is deliberately connected to the AMEXAN observability
// model:
//
//   CLINICAL UI
//       ↓
//   DOMAIN / CLINICAL ENGINES
//       ↓
//   EVENT BUS
//       ↓
//   EVENT LOG / AUDIT / TRACE
//       ↓
//   SAFETY RULES / DETECTION
//       ↓
//   INCIDENT CORRELATION
//       ↓
//   INCIDENT REGISTRY
//       ↓
//   ADMIN CONTROL PLANE
//
// This view is READ-ONLY.
//
// It does not mutate incidents, acknowledge alerts, close incidents, or
// directly access PostgreSQL.
//
// Realtime behaviour:
//   1. Refreshes periodically.
//   2. Reacts to AMEXAN browser events when available.
//   3. Keeps the last known projection visible if the API temporarily fails.
//   4. Automatically reloads selected incident detail.
//   5. Separates critical/high/medium/low operational risk.
//   6. Correlates incidents with encounters, engines, events and actors.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import {
  getIncidentDetail,
  getIncidents,
} from '../api';

import type {
  Incident,
  IncidentDetail,
  IncidentsResponse,
} from '../types';

// =============================================================================
// CONSTANTS
// =============================================================================

const INCIDENT_REFRESH_MS = 5000;
const DETAIL_REFRESH_MS = 5000;
const MAX_INCIDENTS = 200;

const SEVERITIES = [
  '',
  'critical',
  'high',
  'medium',
  'low',
] as const;

const STATUSES = [
  '',
  'open',
  'triaged',
  'investigating',
  'resolved',
  'closed',
  'cancelled',
] as const;

type Severity = (typeof SEVERITIES)[number];
type IncidentStatus = (typeof STATUSES)[number];

type SortKey =
  | 'severity'
  | 'status'
  | 'updatedAt'
  | 'eventCount'
  | 'title';

type SortDirection = 'asc' | 'desc';

// =============================================================================
// HELPERS
// =============================================================================

function safeDate(value: string | undefined | null): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleString();
}

function relativeTime(value: string | undefined | null): string {
  if (!value) return '—';

  const time = new Date(value).getTime();

  if (!Number.isFinite(time)) return '—';

  const seconds = Math.max(
    0,
    Math.floor((Date.now() - time) / 1000),
  );

  if (seconds < 10) return 'just now';
  if (seconds < 60) return `${seconds}s ago`;

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) {
    return `${minutes}m ago`;
  }

  const hours = Math.floor(minutes / 60);

  if (hours < 24) {
    return `${hours}h ago`;
  }

  const days = Math.floor(hours / 24);

  return `${days}d ago`;
}

function severityRank(value: string | undefined | null): number {
  switch (String(value ?? '').toLowerCase()) {
    case 'critical':
      return 4;
    case 'high':
      return 3;
    case 'medium':
      return 2;
    case 'low':
      return 1;
    default:
      return 0;
  }
}

function statusRank(value: string | undefined | null): number {
  switch (String(value ?? '').toLowerCase()) {
    case 'open':
      return 6;
    case 'investigating':
      return 5;
    case 'triaged':
      return 4;
    case 'resolved':
      return 3;
    case 'closed':
      return 2;
    case 'cancelled':
      return 1;
    default:
      return 0;
  }
}

function isActiveIncident(incident: Incident): boolean {
  const status = String(incident.status ?? '').toLowerCase();

  return (
    status === 'open' ||
    status === 'triaged' ||
    status === 'investigating'
  );
}

function isCriticalIncident(incident: Incident): boolean {
  return (
    String(incident.severity ?? '').toLowerCase() === 'critical'
  );
}

function isHighRiskIncident(incident: Incident): boolean {
  const severity = String(incident.severity ?? '').toLowerCase();

  return severity === 'critical' || severity === 'high';
}

function incidentSearchText(incident: Incident): string {
  return [
    incident.incidentCode,
    incident.title,
    incident.severity,
    incident.status,
    incident.category,
    incident.owningTeam,
    incident.relatedEntityType,
    incident.relatedEntityId,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
}

// =============================================================================
// BADGES
// =============================================================================

function SeverityBadge({
  severity,
}: {
  severity: string | undefined | null;
}) {
  const normalized = String(severity ?? 'unknown').toLowerCase();

  const cls =
    normalized === 'critical'
      ? 'admin-badge bad'
      : normalized === 'high'
        ? 'admin-badge warn'
        : normalized === 'medium'
          ? 'admin-badge'
          : normalized === 'low'
            ? 'admin-badge ok'
            : 'admin-badge';

  return (
    <span className={cls}>
      {normalized}
    </span>
  );
}

function StatusBadge({
  status,
}: {
  status: string | undefined | null;
}) {
  const normalized = String(status ?? 'unknown').toLowerCase();

  const cls =
    normalized === 'open'
      ? 'admin-badge bad'
      : normalized === 'investigating'
        ? 'admin-badge warn'
        : normalized === 'triaged'
          ? 'admin-badge'
          : normalized === 'resolved' || normalized === 'closed'
            ? 'admin-badge ok'
            : 'admin-badge';

  return (
    <span className={cls}>
      {normalized}
    </span>
  );
}

// =============================================================================
// METRIC TILE
// =============================================================================

function MetricTile({
  label,
  value,
  note,
  tone,
}: {
  label: string;
  value: number | string;
  note?: string;
  tone?: 'default' | 'good' | 'warn' | 'bad';
}) {
  const toneClass =
    tone === 'good'
      ? ' ok'
      : tone === 'warn'
        ? ' warn'
        : tone === 'bad'
          ? ' bad'
          : '';

  return (
    <div className="admin-tile">
      <span className="admin-tile-value">
        <span className={toneClass}>{value}</span>
      </span>

      <span className="admin-tile-label">
        {label}
      </span>

      {note && (
        <span className="admin-tile-note">
          {note}
        </span>
      )}
    </div>
  );
}

// =============================================================================
// SORT HEADER
// =============================================================================

function SortHeader({
  label,
  column,
  sortKey,
  direction,
  onSort,
}: {
  label: string;
  column: SortKey;
  sortKey: SortKey;
  direction: SortDirection;
  onSort: (key: SortKey) => void;
}) {
  const active = sortKey === column;

  return (
    <th>
      <button
        type="button"
        className="admin-sort-button"
        onClick={() => onSort(column)}
        aria-label={`Sort by ${label}`}
      >
        {label}

        <span
          className="admin-sort-indicator"
          aria-hidden="true"
        >
          {active
            ? direction === 'asc'
              ? ' ↑'
              : ' ↓'
            : ' ↕'}
        </span>
      </button>
    </th>
  );
}

// =============================================================================
// INCIDENT TIMELINE
// =============================================================================

function IncidentTimeline({
  timeline,
}: {
  timeline: IncidentDetail['timeline'];
}) {
  if (!timeline || timeline.length === 0) {
    return (
      <div className="admin-empty">
        No timeline events recorded.
      </div>
    );
  }

  return (
    <div className="admin-trace-rail">
      {timeline.map((entry) => (
        <div
          className="admin-trace-item"
          key={entry.id}
        >
          <span
            className="admin-trace-marker"
            aria-hidden="true"
          />

          <div style={{ minWidth: 0 }}>
            <div
              style={{
                display: 'flex',
                gap: 8,
                flexWrap: 'wrap',
                alignItems: 'center',
              }}
            >
              <span className="admin-badge">
                {entry.eventType}
              </span>

              <span className="muted small mono">
                {entry.actorId ?? 'system'}
              </span>
            </div>

            <div
              className="muted small mono"
              style={{ marginTop: 4 }}
            >
              {safeDate(entry.occurredAt)}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

// =============================================================================
// INCIDENT DETAIL DRAWER
// =============================================================================

function IncidentDrawer({
  detail,
  loading,
  onClose,
}: {
  detail: IncidentDetail | null;
  loading: boolean;
  onClose: () => void;
}) {
  return (
    <div
      className="admin-drawer-backdrop"
      onClick={onClose}
    >
      <aside
        className="admin-drawer"
        onClick={(event) => event.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="Incident detail"
      >
        <div className="admin-drawer-head">
          <div style={{ minWidth: 0 }}>
            <div className="admin-drawer-title">
              {detail?.incidentCode ?? 'Incident'}
            </div>

            {detail?.title && (
              <div
                className="muted small"
                style={{
                  marginTop: 4,
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {detail.title}
              </div>
            )}
          </div>

          <button
            type="button"
            className="admin-drawer-close"
            onClick={onClose}
            aria-label="Close incident detail"
          >
            ✕
          </button>
        </div>

        <div className="admin-drawer-body">
          {loading && !detail && (
            <div className="admin-loading">
              <span
                className="admin-spinner"
                aria-hidden="true"
              />
              Loading incident…
            </div>
          )}

          {loading && detail && (
            <div
              className="admin-panel"
              style={{
                marginBottom: 12,
                padding: '8px 12px',
              }}
            >
              <span className="muted small">
                Refreshing incident projection…
              </span>
            </div>
          )}

          {!loading && !detail && (
            <div className="admin-error">
              Incident detail is unavailable.
            </div>
          )}

          {detail && (
            <>
              <div className="admin-panel">
                <div className="admin-panel-head">
                  <span className="admin-panel-title">
                    Incident
                  </span>

                  <span className="admin-panel-sub">
                    Control Plane projection
                  </span>
                </div>

                <div className="admin-kv">
                  <span className="k">Code</span>
                  <span className="v mono">
                    {detail.incidentCode ?? '—'}
                  </span>

                  <span className="k">Title</span>
                  <span className="v">
                    {detail.title ?? '—'}
                  </span>

                  <span className="k">Severity</span>
                  <span className="v">
                    <SeverityBadge
                      severity={detail.severity}
                    />
                  </span>

                  <span className="k">Status</span>
                  <span className="v">
                    <StatusBadge
                      status={detail.status}
                    />
                  </span>

                  <span className="k">Category</span>
                  <span className="v">
                    {detail.category ?? '—'}
                  </span>

                  <span className="k">Owning team</span>
                  <span className="v">
                    {detail.owningTeam ?? '—'}
                  </span>

                  <span className="k">Reported by</span>
                  <span className="v">
                    {detail.reportedBy ?? '—'}
                  </span>

                  <span className="k">Related entity</span>
                  <span className="v mono">
                    {detail.relatedEntityType
                      ? `${detail.relatedEntityType} ${
                          detail.relatedEntityId
                            ? detail.relatedEntityId
                            : ''
                        }`
                      : '—'}
                  </span>
                </div>
              </div>

              {detail.description && (
                <div
                  className="admin-panel"
                  style={{ marginTop: 12 }}
                >
                  <div className="admin-panel-head">
                    <span className="admin-panel-title">
                      Description
                    </span>
                  </div>

                  <div
                    style={{
                      whiteSpace: 'pre-wrap',
                      lineHeight: 1.55,
                    }}
                  >
                    {detail.description}
                  </div>
                </div>
              )}

              <div
                className="admin-panel"
                style={{ marginTop: 12 }}
              >
                <div className="admin-panel-head">
                  <span className="admin-panel-title">
                    Incident Timeline
                  </span>

                  <span className="admin-panel-sub">
                    {detail.timeline?.length ?? 0} events
                  </span>
                </div>

                <IncidentTimeline
                  timeline={detail.timeline ?? []}
                />
              </div>
            </>
          )}
        </div>
      </aside>
    </div>
  );
}

// =============================================================================
// MAIN INCIDENT VIEW
// =============================================================================

export function IncidentsView() {
  const [data, setData] =
    useState<IncidentsResponse | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [refreshing, setRefreshing] =
    useState(false);

  const [error, setError] =
    useState<string | null>(null);

  const [lastUpdated, setLastUpdated] =
    useState<number | null>(null);

  const [severity, setSeverity] =
    useState<Severity>('');

  const [status, setStatus] =
    useState<IncidentStatus>('');

  const [search, setSearch] =
    useState('');

  const [selectedId, setSelectedId] =
    useState<string | null>(null);

  const [detail, setDetail] =
    useState<IncidentDetail | null>(null);

  const [detailLoading, setDetailLoading] =
    useState(false);

  const [sortKey, setSortKey] =
    useState<SortKey>('updatedAt');

  const [sortDirection, setSortDirection] =
    useState<SortDirection>('desc');

  const [showOnlyActive, setShowOnlyActive] =
    useState(false);

  const mountedRef = useRef(true);

  // ===========================================================================
  // INCIDENT LIST
  // ===========================================================================

  const load = useCallback(
    async (background = false) => {
      if (background) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }

      try {
        const result = await getIncidents({
          severity,
          status,
          limit: MAX_INCIDENTS,
        });

        if (!mountedRef.current) return;

        setData(result);
        setError(null);
        setLastUpdated(Date.now());
      } catch (e) {
        if (!mountedRef.current) return;

        setError(
          e instanceof Error
            ? e.message
            : 'Failed to load incidents',
        );
      } finally {
        if (!mountedRef.current) return;

        if (background) {
          setRefreshing(false);
        } else {
          setLoading(false);
        }
      }
    },
    [severity, status],
  );

  // ===========================================================================
  // INITIAL + FILTER LOAD
  // ===========================================================================

  useEffect(() => {
    mountedRef.current = true;

    void load(false);

    return () => {
      mountedRef.current = false;
    };
  }, [load]);

  // ===========================================================================
  // REALTIME POLLING
  // ===========================================================================

  useEffect(() => {
    const timer = window.setInterval(() => {
      void load(true);
    }, INCIDENT_REFRESH_MS);

    return () => {
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // AMEXAN EVENT BUS BRIDGE
  //
  // Any frontend event producer can dispatch:
  //
  // window.dispatchEvent(
  //   new CustomEvent('amexan:event', {
  //     detail: {
  //       eventType: 'INCIDENT_CREATED'
  //     }
  //   })
  // )
  //
  // The incident projection refreshes immediately.
  // ===========================================================================

  useEffect(() => {
    const handleAmexanEvent = (
      event: Event,
    ) => {
      const customEvent =
        event as CustomEvent<{
          eventType?: string;
          type?: string;
          incidentId?: string;
          severity?: string;
        }>;

      const eventType = String(
        customEvent.detail?.eventType ??
          customEvent.detail?.type ??
          '',
      ).toUpperCase();

      const relevant =
        eventType.includes('INCIDENT') ||
        eventType.includes('SAFETY') ||
        eventType.includes('ENGINE_FAILED') ||
        eventType.includes('ENGINE_DEGRADED') ||
        eventType.includes('DEAD_LETTER') ||
        eventType.includes('RULE_VIOLATION') ||
        eventType.includes('CLINICAL_ALERT');

      if (relevant) {
        void load(true);
      }
    };

    window.addEventListener(
      'amexan:event',
      handleAmexanEvent,
    );

    window.addEventListener(
      'amexan:incident',
      handleAmexanEvent,
    );

    return () => {
      window.removeEventListener(
        'amexan:event',
        handleAmexanEvent,
      );

      window.removeEventListener(
        'amexan:incident',
        handleAmexanEvent,
      );
    };
  }, [load]);

  // ===========================================================================
  // INCIDENT DETAIL
  // ===========================================================================

  const loadDetail = useCallback(
    async (id: string, background = false) => {
      if (!background) {
        setDetailLoading(true);
        setDetail(null);
      }

      try {
        const result =
          await getIncidentDetail(id);

        if (!mountedRef.current) return;

        setDetail(result);
      } catch {
        if (!mountedRef.current) return;

        if (!background) {
          setDetail(null);
        }
      } finally {
        if (!mountedRef.current) return;

        if (!background) {
          setDetailLoading(false);
        }
      }
    },
    [],
  );

  useEffect(() => {
    if (!selectedId) {
      setDetail(null);
      return;
    }

    void loadDetail(
      selectedId,
      false,
    );

    const timer = window.setInterval(() => {
      void loadDetail(
        selectedId,
        true,
      );
    }, DETAIL_REFRESH_MS);

    return () => {
      window.clearInterval(timer);
    };
  }, [selectedId, loadDetail]);

  // ===========================================================================
  // DETAIL EVENT REFRESH
  // ===========================================================================

  useEffect(() => {
    if (!selectedId) return;

    const handleIncidentEvent = (
      event: Event,
    ) => {
      const customEvent =
        event as CustomEvent<{
          incidentId?: string;
          eventType?: string;
        }>;

      const incomingId =
        customEvent.detail?.incidentId;

      if (
        !incomingId ||
        incomingId === selectedId
      ) {
        void loadDetail(
          selectedId,
          true,
        );
      }
    };

    window.addEventListener(
      'amexan:event',
      handleIncidentEvent,
    );

    window.addEventListener(
      'amexan:incident',
      handleIncidentEvent,
    );

    return () => {
      window.removeEventListener(
        'amexan:event',
        handleIncidentEvent,
      );

      window.removeEventListener(
        'amexan:incident',
        handleIncidentEvent,
      );
    };
  }, [selectedId, loadDetail]);

  // ===========================================================================
  // KEYBOARD / ESCAPE
  // ===========================================================================

  useEffect(() => {
    if (!selectedId) return;

    const handleKeyDown = (
      event: KeyboardEvent,
    ) => {
      if (event.key === 'Escape') {
        setSelectedId(null);
      }
    };

    window.addEventListener(
      'keydown',
      handleKeyDown,
    );

    return () => {
      window.removeEventListener(
        'keydown',
        handleKeyDown,
      );
    };
  }, [selectedId]);

  // ===========================================================================
  // SORT
  // ===========================================================================

  const handleSort = useCallback(
    (key: SortKey) => {
      if (sortKey === key) {
        setSortDirection((current) =>
          current === 'asc'
            ? 'desc'
            : 'asc',
        );

        return;
      }

      setSortKey(key);
      setSortDirection(
        key === 'title'
          ? 'asc'
          : 'desc',
      );
    },
    [sortKey],
  );

  // ===========================================================================
  // FILTERED + SORTED DATA
  // ===========================================================================

  const incidents = useMemo(() => {
    const source =
      data?.incidents ?? [];

    const query =
      search.trim().toLowerCase();

    const filtered =
      source.filter((incident) => {
        if (
          showOnlyActive &&
          !isActiveIncident(incident)
        ) {
          return false;
        }

        if (
          query &&
          !incidentSearchText(incident).includes(
            query,
          )
        ) {
          return false;
        }

        return true;
      });

    return [...filtered].sort(
      (a, b) => {
        let result = 0;

        switch (sortKey) {
          case 'severity':
            result =
              severityRank(
                a.severity,
              ) -
              severityRank(
                b.severity,
              );
            break;

          case 'status':
            result =
              statusRank(
                a.status,
              ) -
              statusRank(
                b.status,
              );
            break;

          case 'eventCount':
            result =
              (a.eventCount ?? 0) -
              (b.eventCount ?? 0);
            break;

          case 'title':
            result =
              String(
                a.title ?? '',
              ).localeCompare(
                String(
                  b.title ?? '',
                ),
              );
            break;

          case 'updatedAt':
          default:
            result =
              new Date(
                a.updatedAt,
              ).getTime() -
              new Date(
                b.updatedAt,
              ).getTime();
            break;
        }

        return sortDirection === 'asc'
          ? result
          : -result;
      },
    );
  }, [
    data,
    search,
    showOnlyActive,
    sortKey,
    sortDirection,
  ]);

  // ===========================================================================
  // DERIVED PLATFORM METRICS
  // ===========================================================================

  const allIncidents =
    data?.incidents ?? [];

  const total =
    data?.total ??
    allIncidents.length;

  const active =
    allIncidents.filter(
      isActiveIncident,
    ).length;

  const critical =
    allIncidents.filter(
      isCriticalIncident,
    ).length;

  const highRisk =
    allIncidents.filter(
      isHighRiskIncident,
    ).length;

  const investigating =
    allIncidents.filter(
      (incident) =>
        String(
          incident.status ?? '',
        ).toLowerCase() ===
        'investigating',
    ).length;

  const resolved =
    allIncidents.filter(
      (incident) => {
        const status =
          String(
            incident.status ?? '',
          ).toLowerCase();

        return (
          status === 'resolved' ||
          status === 'closed'
        );
      },
    ).length;

  const totalEvents =
    allIncidents.reduce(
      (sum, incident) =>
        sum +
        Number(
          incident.eventCount ?? 0,
        ),
      0,
    );

  const criticalActive =
    allIncidents.filter(
      (incident) =>
        isCriticalIncident(
          incident,
        ) &&
        isActiveIncident(
          incident,
        ),
    ).length;

  // ===========================================================================
  // LOADING
  // ===========================================================================

  if (
    loading &&
    !data
  ) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Loading incident observatory…
      </div>
    );
  }

  // ===========================================================================
  // HARD FAILURE
  // ===========================================================================

  if (
    error &&
    !data
  ) {
    return (
      <div
        className="admin-error"
        role="alert"
      >
        {error}
      </div>
    );
  }

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div>
      {/* =====================================================================
          HEADER
          ================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              Incident Observatory
            </span>

            <span className="admin-panel-sub">
              AMEXAN incident registry · safety
              detection · engine failures · event
              correlation
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
              className={
                refreshing
                  ? 'admin-badge warn'
                  : 'admin-badge ok'
              }
            >
              {refreshing
                ? 'refreshing'
                : 'live projection'}
            </span>

            {lastUpdated && (
              <span className="muted small mono">
                {new Date(
                  lastUpdated,
                ).toLocaleTimeString()}
              </span>
            )}
          </div>
        </div>

        {error && data && (
          <div
            className="admin-error"
            role="status"
            style={{
              marginTop: 10,
            }}
          >
            Projection refresh failed:
            {' '}
            {error}
            {' '}
            · displaying last known state
          </div>
        )}
      </div>

      {/* =====================================================================
          TOP METRICS
          ================================================================== */}

      <div className="admin-tile-grid">
        <MetricTile
          label="Total incidents"
          value={total}
          note="registry projection"
        />

        <MetricTile
          label="Active"
          value={active}
          note="open · triaged · investigating"
          tone={active > 0 ? 'warn' : 'good'}
        />

        <MetricTile
          label="Critical"
          value={critical}
          note={`${criticalActive} currently active`}
          tone={
            criticalActive > 0
              ? 'bad'
              : 'good'
          }
        />

        <MetricTile
          label="High risk"
          value={highRisk}
          note="critical + high severity"
          tone={
            highRisk > 0
              ? 'warn'
              : 'good'
          }
        />

        <MetricTile
          label="Investigating"
          value={investigating}
          note="under active investigation"
          tone={
            investigating > 0
              ? 'warn'
              : 'good'
          }
        />

        <MetricTile
          label="Resolved / closed"
          value={resolved}
          note="historical resolution"
          tone="good"
        />

        <MetricTile
          label="Correlated events"
          value={totalEvents}
          note="events attached to incidents"
        />
      </div>

      {/* =====================================================================
          CRITICAL OPERATING PICTURE
          ================================================================== */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Critical Active Incidents
            </span>

            <span className="admin-panel-sub">
              highest-risk conditions
            </span>
          </div>

          {criticalActive === 0 && (
            <div className="admin-empty">
              No active critical incidents in
              the current projection.
            </div>
          )}

          {criticalActive > 0 && (
            <div className="admin-activity">
              {allIncidents
                .filter(
                  (incident) =>
                    isCriticalIncident(
                      incident,
                    ) &&
                    isActiveIncident(
                      incident,
                    ),
                )
                .slice(0, 10)
                .map((incident) => (
                  <button
                    key={incident.id}
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
                      setSelectedId(
                        incident.id,
                      )
                    }
                  >
                    <span className="admin-activity-time">
                      {relativeTime(
                        incident.updatedAt,
                      )}
                    </span>

                    <span className="admin-activity-type">
                      {incident.incidentCode}
                    </span>

                    <span className="admin-activity-meta">
                      {incident.title}
                    </span>

                    <SeverityBadge
                      severity={
                        incident.severity
                      }
                    />
                  </button>
                ))}
            </div>
          )}
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Incident Health
            </span>

            <span className="admin-panel-sub">
              current registry distribution
            </span>
          </div>

          <table className="admin-table">
            <tbody>
              <tr>
                <td>Open</td>
                <td className="num">
                  {
                    allIncidents.filter(
                      (i) =>
                        String(
                          i.status,
                        ).toLowerCase() ===
                        'open',
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Triaged</td>
                <td className="num">
                  {
                    allIncidents.filter(
                      (i) =>
                        String(
                          i.status,
                        ).toLowerCase() ===
                        'triaged',
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Investigating</td>
                <td className="num">
                  {investigating}
                </td>
              </tr>

              <tr>
                <td>Resolved</td>
                <td className="num">
                  {
                    allIncidents.filter(
                      (i) =>
                        String(
                          i.status,
                        ).toLowerCase() ===
                        'resolved',
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Closed</td>
                <td className="num">
                  {
                    allIncidents.filter(
                      (i) =>
                        String(
                          i.status,
                        ).toLowerCase() ===
                        'closed',
                    ).length
                  }
                </td>
              </tr>

              <tr>
                <td>Cancelled</td>
                <td className="num">
                  {
                    allIncidents.filter(
                      (i) =>
                        String(
                          i.status,
                        ).toLowerCase() ===
                        'cancelled',
                    ).length
                  }
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          FILTERS
          ================================================================== */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              Incident Registry
            </span>

            <span className="admin-panel-sub">
              {incidents.length} displayed ·{' '}
              {allIncidents.length} loaded
            </span>
          </div>
        </div>

        <div
          className="admin-filters"
          style={{
            alignItems: 'flex-end',
            flexWrap: 'wrap',
          }}
        >
          <label
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            <span className="muted small">
              Search
            </span>

            <input
              type="search"
              className="admin-filter-input"
              placeholder="Code, title, team, entity…"
              value={search}
              onChange={(event) =>
                setSearch(
                  event.target.value,
                )
              }
            />
          </label>

          <label
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            <span className="muted small">
              Severity
            </span>

            <select
              value={severity}
              onChange={(event) =>
                setSeverity(
                  event.target
                    .value as Severity,
                )
              }
              className="admin-input"
            >
              {SEVERITIES.map(
                (value) => (
                  <option
                    key={value}
                    value={value}
                  >
                    {value || 'all'}
                  </option>
                ),
              )}
            </select>
          </label>

          <label
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
            }}
          >
            <span className="muted small">
              Status
            </span>

            <select
              value={status}
              onChange={(event) =>
                setStatus(
                  event.target
                    .value as IncidentStatus,
                )
              }
              className="admin-input"
            >
              {STATUSES.map(
                (value) => (
                  <option
                    key={value}
                    value={value}
                  >
                    {value || 'all'}
                  </option>
                ),
              )}
            </select>
          </label>

          <label
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              minHeight: 38,
              cursor: 'pointer',
            }}
          >
            <input
              type="checkbox"
              checked={showOnlyActive}
              onChange={(event) =>
                setShowOnlyActive(
                  event.target.checked,
                )
              }
            />

            <span>
              Active only
            </span>
          </label>

          <button
            type="button"
            className="admin-page-btn"
            onClick={() =>
              void load(true)
            }
          >
            Refresh
          </button>
        </div>

        {/* ===================================================================
            TABLE
            ================================================================= */}

        {incidents.length === 0 && (
          <div className="admin-empty">
            No incidents match the current
            filters.
          </div>
        )}

        {incidents.length > 0 && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <SortHeader
                    label="Code"
                    column="title"
                    sortKey={sortKey}
                    direction={
                      sortDirection
                    }
                    onSort={
                      handleSort
                    }
                  />

                  <SortHeader
                    label="Title"
                    column="title"
                    sortKey={sortKey}
                    direction={
                      sortDirection
                    }
                    onSort={
                      handleSort
                    }
                  />

                  <SortHeader
                    label="Severity"
                    column="severity"
                    sortKey={sortKey}
                    direction={
                      sortDirection
                    }
                    onSort={
                      handleSort
                    }
                  />

                  <SortHeader
                    label="Status"
                    column="status"
                    sortKey={sortKey}
                    direction={
                      sortDirection
                    }
                    onSort={
                      handleSort
                    }
                  />

                  <th>
                    Category
                  </th>

                  <th>
                    Owning team
                  </th>

                  <SortHeader
                    label="Events"
                    column="eventCount"
                    sortKey={sortKey}
                    direction={
                      sortDirection
                    }
                    onSort={
                      handleSort
                    }
                  />

                  <SortHeader
                    label="Updated"
                    column="updatedAt"
                    sortKey={sortKey}
                    direction={
                      sortDirection
                    }
                    onSort={
                      handleSort
                    }
                  />
                </tr>
              </thead>

              <tbody>
                {incidents.map(
                  (incident) => (
                    <tr
                      key={
                        incident.id
                      }
                      className="admin-row-click"
                      onClick={() =>
                        setSelectedId(
                          incident.id,
                        )
                      }
                      tabIndex={0}
                      onKeyDown={(
                        event,
                      ) => {
                        if (
                          event.key ===
                            'Enter' ||
                          event.key ===
                            ' '
                        ) {
                          event.preventDefault();

                          setSelectedId(
                            incident.id,
                          );
                        }
                      }}
                    >
                      <td className="mono">
                        {
                          incident.incidentCode
                        }
                      </td>

                      <td>
                        <div
                          style={{
                            fontWeight:
                              isCriticalIncident(
                                incident,
                              )
                                ? 600
                                : undefined,
                          }}
                        >
                          {
                            incident.title
                          }
                        </div>

                        {incident.relatedEntityType && (
                          <div className="muted small mono">
                            {
                              incident.relatedEntityType
                            }
                            {' '}
                            {incident.relatedEntityId ??
                              ''}
                          </div>
                        )}
                      </td>

                      <td>
                        <SeverityBadge
                          severity={
                            incident.severity
                          }
                        />
                      </td>

                      <td>
                        <StatusBadge
                          status={
                            incident.status
                          }
                        />
                      </td>

                      <td>
                        {
                          incident.category ??
                          '—'
                        }
                      </td>

                      <td>
                        {
                          incident.owningTeam ??
                          '—'
                        }
                      </td>

                      <td className="num">
                        {
                          incident.eventCount ??
                          0
                        }
                      </td>

                      <td className="mono">
                        <div>
                          {safeDate(
                            incident.updatedAt,
                          )}
                        </div>

                        <div className="muted small">
                          {relativeTime(
                            incident.updatedAt,
                          )}
                        </div>
                      </td>
                    </tr>
                  ),
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* =====================================================================
          RISK DISTRIBUTION
          ================================================================== */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Severity Distribution
            </span>

            <span className="admin-panel-sub">
              loaded incidents
            </span>
          </div>

          <table className="admin-table">
            <tbody>
              {[
                'critical',
                'high',
                'medium',
                'low',
              ].map((level) => {
                const count =
                  allIncidents.filter(
                    (incident) =>
                      String(
                        incident.severity,
                      ).toLowerCase() ===
                      level,
                  ).length;

                return (
                  <tr key={level}>
                    <td>
                      <SeverityBadge
                        severity={
                          level
                        }
                      />
                    </td>

                    <td className="num">
                      {count}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Operational Interpretation
            </span>

            <span className="admin-panel-sub">
              current control-plane state
            </span>
          </div>

          <table className="admin-table">
            <tbody>
              <tr>
                <td>
                  Active incidents
                </td>

                <td className="num">
                  {active}
                </td>
              </tr>

              <tr>
                <td>
                  Active critical
                </td>

                <td className="num">
                  {criticalActive}
                </td>
              </tr>

              <tr>
                <td>
                  High-risk incidents
                </td>

                <td className="num">
                  {highRisk}
                </td>
              </tr>

              <tr>
                <td>
                  Correlated events
                </td>

                <td className="num">
                  {totalEvents}
                </td>
              </tr>

              <tr>
                <td>
                  Investigation queue
                </td>

                <td className="num">
                  {investigating}
                </td>
              </tr>

              <tr>
                <td>
                  Resolution history
                </td>

                <td className="num">
                  {resolved}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          INCIDENT DETAIL
          ================================================================== */}

      {selectedId !== null && (
        <IncidentDrawer
          detail={detail}
          loading={detailLoading}
          onClose={() =>
            setSelectedId(null)
          }
        />
      )}
    </div>
  );
}

export type { Incident };