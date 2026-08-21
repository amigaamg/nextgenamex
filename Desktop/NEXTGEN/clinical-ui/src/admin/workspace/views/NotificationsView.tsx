// =============================================================================
// AMEXAN Notifications — REAL-TIME COMMUNICATION CONTROL CENTER
// =============================================================================
//
// OPERATE
//
// PURPOSE
// -------
// Live read-only observability of AMEXAN communication infrastructure:
//
//   • communication messages
//   • channel deliveries
//   • delivery success/failure
//   • pending / queued communication
//   • provider activity
//   • delivery latency indicators
//   • channel distribution
//   • message-type distribution
//   • live activity stream
//   • failed-delivery attention queue
//   • automatic rapid refresh
//   • visibility-aware polling
//   • manual refresh
//   • stale-data indication
//   • request race protection
//
// IMPORTANT
// ---------
// This component remains read-only.
// It communicates only through the Control Plane API.
// PostgreSQL is never accessed directly.
//
// REALTIME MODEL
// --------------
// The current API exposes getNotificationsOverview(), not a websocket/SSE
// subscription. Therefore this implementation provides near-real-time
// synchronization through rapid Control Plane polling.
//
// Polling is:
//   • 2 seconds while the browser tab is visible
//   • 10 seconds while hidden
//   • paused while an identical request is already running
//   • immediately resumed when the tab becomes visible
//
// This keeps the UI extremely responsive without creating overlapping requests.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { getNotificationsOverview } from '../api';

import type {
  NotificationsOverview,
} from '../types';

// =============================================================================
// CONFIGURATION
// =============================================================================

const LIVE_POLL_MS = 2000;
const HIDDEN_POLL_MS = 10000;

const MAX_LIVE_ACTIVITY = 40;
const MAX_FAILURES = 30;

const RECENT_WINDOW_MS = 60 * 1000;

type ConnectionState =
  | 'connecting'
  | 'live'
  | 'degraded'
  | 'offline';

type FilterChannel = 'ALL' | string;
type FilterStatus = 'ALL' | string;

interface DeliveryView {
  id: string;
  channel: string;
  provider?: string | null;
  status?: string | null;
  messageId: string;
  attemptedAt: string;
}

interface MessageView {
  id: string;
  messageType: string;
  senderType: string;
  senderId?: string | null;
  body?: string | null;
  status?: string | null;
  sentAt: string;
}

interface LiveActivity {
  key: string;
  kind: 'message' | 'delivery';
  id: string;
  timestamp: string;
  primary: string;
  secondary: string;
  status: string;
  channel?: string;
  provider?: string;
}

// =============================================================================
// SAFE HELPERS
// =============================================================================

function normalizeStatus(value: unknown): string {
  return String(value ?? 'unknown').trim().toLowerCase();
}

function normalizeChannel(value: unknown): string {
  return String(value ?? 'unknown').trim();
}

function statusClass(status: unknown): string {
  const normalized = normalizeStatus(status);

  if (
    normalized === 'delivered' ||
    normalized === 'sent' ||
    normalized === 'success' ||
    normalized === 'completed' ||
    normalized === 'acknowledged'
  ) {
    return 'ok';
  }

  if (
    normalized === 'failed' ||
    normalized === 'error' ||
    normalized === 'rejected' ||
    normalized === 'dead'
  ) {
    return 'bad';
  }

  if (
    normalized === 'pending' ||
    normalized === 'queued' ||
    normalized === 'processing' ||
    normalized === 'retrying' ||
    normalized === 'sending'
  ) {
    return 'warn';
  }

  return '';
}

function formatDate(value: unknown): string {
  if (!value) return '—';

  const date = new Date(String(value));

  if (Number.isNaN(date.getTime())) {
    return String(value);
  }

  return date.toLocaleString();
}

function formatTime(value: unknown): string {
  if (!value) return '—';

  const date = new Date(String(value));

  if (Number.isNaN(date.getTime())) {
    return String(value);
  }

  return date.toLocaleTimeString();
}

function relativeAge(value: unknown): string {
  if (!value) return '—';

  const time = new Date(String(value)).getTime();

  if (!Number.isFinite(time)) {
    return '—';
  }

  const seconds = Math.max(0, Math.floor((Date.now() - time) / 1000));

  if (seconds < 5) return 'now';
  if (seconds < 60) return `${seconds}s ago`;

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

function truncate(value: unknown, length = 90): string {
  const text = String(value ?? '');

  if (!text) return '—';

  return text.length > length
    ? `${text.slice(0, length)}…`
    : text;
}

function safeTimestamp(value: unknown): number {
  const time = new Date(String(value ?? '')).getTime();

  return Number.isFinite(time) ? time : 0;
}

// =============================================================================
// BADGE
// =============================================================================

function StatusBadge({
  status,
}: {
  status: string | null | undefined;
}) {
  const normalized = normalizeStatus(status);

  return (
    <span className={`admin-badge ${statusClass(normalized)}`}>
      {normalized || 'unknown'}
    </span>
  );
}

// =============================================================================
// LIVE INDICATOR
// =============================================================================

function LiveIndicator({
  state,
  lastUpdated,
}: {
  state: ConnectionState;
  lastUpdated: number | null;
}) {
  const label =
    state === 'live'
      ? 'LIVE'
      : state === 'connecting'
        ? 'CONNECTING'
        : state === 'degraded'
          ? 'DEGRADED'
          : 'OFFLINE';

  return (
    <div
      className={`admin-live-indicator ${state}`}
      title={
        lastUpdated
          ? `Last synchronized ${formatDate(lastUpdated)}`
          : 'No successful synchronization yet'
      }
    >
      <span
        className="admin-live-dot"
        aria-hidden="true"
      />
      <span>{label}</span>
    </div>
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
  tone?: 'good' | 'warn' | 'bad' | 'brand';
}) {
  return (
    <div className={`admin-tile ${tone ? `tile-${tone}` : ''}`}>
      <span className="tile-label">
        {label}
      </span>

      <span className="tile-value">
        {value}
      </span>

      {note && (
        <span className="tile-note">
          {note}
        </span>
      )}
    </div>
  );
}

// =============================================================================
// MAIN COMPONENT
// =============================================================================

export function NotificationsView() {
  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  const [data, setData] =
    useState<NotificationsOverview | null>(null);

  const [loading, setLoading] =
    useState(true);

  const [error, setError] =
    useState<string | null>(null);

  const [connectionState, setConnectionState] =
    useState<ConnectionState>('connecting');

  const [lastUpdated, setLastUpdated] =
    useState<number | null>(null);

  const [refreshing, setRefreshing] =
    useState(false);

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  const [channelFilter, setChannelFilter] =
    useState<FilterChannel>('ALL');

  const [statusFilter, setStatusFilter] =
    useState<FilterStatus>('ALL');

  const [messageSearch, setMessageSearch] =
    useState('');

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  const [showOnlyFailures, setShowOnlyFailures] =
    useState(false);

  const [showOnlyRecent, setShowOnlyRecent] =
    useState(false);

  // ---------------------------------------------------------------------------
  // REQUEST CONTROL
  // ---------------------------------------------------------------------------

  const requestInFlight =
    useRef(false);

  const mountedRef =
    useRef(true);

  const pollTimerRef =
    useRef<ReturnType<typeof setTimeout> | null>(null);

  const lastSuccessfulSnapshot =
    useRef<string | null>(null);

  // ---------------------------------------------------------------------------
  // MOUNT / UNMOUNT
  // ---------------------------------------------------------------------------

  useEffect(() => {
    mountedRef.current = true;

    return () => {
      mountedRef.current = false;

      if (pollTimerRef.current) {
        clearTimeout(pollTimerRef.current);
        pollTimerRef.current = null;
      }
    };
  }, []);

  // =============================================================================
  // LOAD
  // =============================================================================

  const load = useCallback(
    async (background = false) => {
      if (requestInFlight.current) {
        return;
      }

      requestInFlight.current = true;

      if (!background) {
        setRefreshing(true);
      }

      try {
        const response =
          await getNotificationsOverview();

        if (!mountedRef.current) {
          return;
        }

        setData(response);
        setError(null);
        setConnectionState('live');
        setLastUpdated(Date.now());

        try {
          const snapshot = JSON.stringify(response);

          if (
            lastSuccessfulSnapshot.current !== null &&
            lastSuccessfulSnapshot.current !== snapshot
          ) {
            // State replacement is intentionally enough to trigger the live UI.
            // No mutation is performed on the server.
          }

          lastSuccessfulSnapshot.current = snapshot;
        } catch {
          // Snapshot comparison is optional and must never affect operation.
        }
      } catch (e) {
        if (!mountedRef.current) {
          return;
        }

        const message =
          e instanceof Error
            ? e.message
            : 'Failed to load notifications';

        setError(message);

        if (data) {
          setConnectionState('degraded');
        } else {
          setConnectionState('offline');
        }
      } finally {
        requestInFlight.current = false;

        if (mountedRef.current) {
          setLoading(false);
          setRefreshing(false);
        }
      }
    },
    [data],
  );

  // =============================================================================
  // POLLING LOOP
  // =============================================================================

  const scheduleNextPoll = useCallback(() => {
    if (!mountedRef.current) {
      return;
    }

    if (pollTimerRef.current) {
      clearTimeout(pollTimerRef.current);
    }

    const delay =
      typeof document !== 'undefined' &&
      document.visibilityState === 'hidden'
        ? HIDDEN_POLL_MS
        : LIVE_POLL_MS;

    pollTimerRef.current = setTimeout(() => {
      void load(true);
      scheduleNextPoll();
    }, delay);
  }, [load]);

  useEffect(() => {
    void load(false);
    scheduleNextPoll();

    return () => {
      if (pollTimerRef.current) {
        clearTimeout(pollTimerRef.current);
        pollTimerRef.current = null;
      }
    };
  }, [load, scheduleNextPoll]);

  // =============================================================================
  // VISIBILITY
  // =============================================================================

  useEffect(() => {
    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        void load(true);
      }

      scheduleNextPoll();
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
  }, [load, scheduleNextPoll]);

  // =============================================================================
  // RAW ARRAYS
  // =============================================================================

  const messages = useMemo<MessageView[]>(
    () =>
      ((data?.messages ?? []) as MessageView[])
        .slice()
        .sort(
          (a, b) =>
            safeTimestamp(b.sentAt) -
            safeTimestamp(a.sentAt),
        ),
    [data],
  );

  const deliveries = useMemo<DeliveryView[]>(
    () =>
      ((data?.deliveries ?? []) as DeliveryView[])
        .slice()
        .sort(
          (a, b) =>
            safeTimestamp(b.attemptedAt) -
            safeTimestamp(a.attemptedAt),
        ),
    [data],
  );

  const stats = data?.messageStats ?? [];

  // =============================================================================
  // CHANNEL OPTIONS
  // =============================================================================

  const channelOptions = useMemo(() => {
    const channels = new Set<string>();

    deliveries.forEach((delivery) => {
      channels.add(
        normalizeChannel(delivery.channel),
      );
    });

    return Array.from(channels).sort(
      (a, b) => a.localeCompare(b),
    );
  }, [deliveries]);

  // =============================================================================
  // STATUS OPTIONS
  // =============================================================================

  const statusOptions = useMemo(() => {
    const statuses = new Set<string>();

    messages.forEach((message) => {
      statuses.add(
        normalizeStatus(message.status),
      );
    });

    deliveries.forEach((delivery) => {
      statuses.add(
        normalizeStatus(delivery.status),
      );
    });

    return Array.from(statuses)
      .filter(Boolean)
      .sort(
        (a, b) => a.localeCompare(b),
      );
  }, [messages, deliveries]);

  // =============================================================================
  // FILTERED DATA
  // =============================================================================

  const filteredMessages = useMemo(() => {
    const search =
      messageSearch.trim().toLowerCase();

    return messages.filter((message) => {
      const status =
        normalizeStatus(message.status);

      const matchesStatus =
        statusFilter === 'ALL' ||
        status === statusFilter;

      const matchesSearch =
        !search ||
        message.id.toLowerCase().includes(search) ||
        message.messageType
          .toLowerCase()
          .includes(search) ||
        message.senderType
          .toLowerCase()
          .includes(search) ||
        String(message.senderId ?? '')
          .toLowerCase()
          .includes(search) ||
        String(message.body ?? '')
          .toLowerCase()
          .includes(search);

      const matchesRecent =
        !showOnlyRecent ||
        Date.now() -
          safeTimestamp(message.sentAt) <=
          RECENT_WINDOW_MS;

      const matchesFailure =
        !showOnlyFailures ||
        status === 'failed' ||
        status === 'error' ||
        status === 'rejected' ||
        status === 'dead';

      return (
        matchesStatus &&
        matchesSearch &&
        matchesRecent &&
        matchesFailure
      );
    });
  }, [
    messages,
    messageSearch,
    statusFilter,
    showOnlyFailures,
    showOnlyRecent,
  ]);

  const filteredDeliveries = useMemo(() => {
    return deliveries.filter((delivery) => {
      const status =
        normalizeStatus(delivery.status);

      const channel =
        normalizeChannel(delivery.channel);

      const matchesChannel =
        channelFilter === 'ALL' ||
        channel === channelFilter;

      const matchesStatus =
        statusFilter === 'ALL' ||
        status === statusFilter;

      const matchesRecent =
        !showOnlyRecent ||
        Date.now() -
          safeTimestamp(delivery.attemptedAt) <=
          RECENT_WINDOW_MS;

      const matchesFailure =
        !showOnlyFailures ||
        status === 'failed' ||
        status === 'error' ||
        status === 'rejected' ||
        status === 'dead';

      return (
        matchesChannel &&
        matchesStatus &&
        matchesRecent &&
        matchesFailure
      );
    });
  }, [
    deliveries,
    channelFilter,
    statusFilter,
    showOnlyFailures,
    showOnlyRecent,
  ]);

  // =============================================================================
  // DERIVED METRICS
  // =============================================================================

  const deliveryStats = useMemo(() => {
    let delivered = 0;
    let failed = 0;
    let pending = 0;
    let retrying = 0;
    let processing = 0;

    deliveries.forEach((delivery) => {
      const status =
        normalizeStatus(delivery.status);

      if (
        status === 'delivered' ||
        status === 'success' ||
        status === 'completed'
      ) {
        delivered += 1;
      } else if (
        status === 'failed' ||
        status === 'error' ||
        status === 'rejected' ||
        status === 'dead'
      ) {
        failed += 1;
      } else if (
        status === 'retrying'
      ) {
        retrying += 1;
      } else if (
        status === 'processing' ||
        status === 'sending'
      ) {
        processing += 1;
      } else {
        pending += 1;
      }
    });

    return {
      delivered,
      failed,
      pending,
      retrying,
      processing,
      total: deliveries.length,
    };
  }, [deliveries]);

  const recentMessages = useMemo(
    () =>
      messages.filter(
        (message) =>
          Date.now() -
            safeTimestamp(message.sentAt) <=
          RECENT_WINDOW_MS,
      ).length,
    [messages, lastUpdated],
  );

  const recentDeliveries = useMemo(
    () =>
      deliveries.filter(
        (delivery) =>
          Date.now() -
            safeTimestamp(delivery.attemptedAt) <=
          RECENT_WINDOW_MS,
      ).length,
    [deliveries, lastUpdated],
  );

  const deliverySuccessRate = useMemo(() => {
    if (deliveryStats.total === 0) {
      return 0;
    }

    return Math.round(
      (deliveryStats.delivered /
        deliveryStats.total) *
        100,
    );
  }, [deliveryStats]);

  // =============================================================================
  // CHANNEL DISTRIBUTION
  // =============================================================================

  const channelDistribution = useMemo(() => {
    const map = new Map<
      string,
      {
        total: number;
        delivered: number;
        failed: number;
        pending: number;
      }
    >();

    deliveries.forEach((delivery) => {
      const channel =
        normalizeChannel(delivery.channel);

      const current =
        map.get(channel) ?? {
          total: 0,
          delivered: 0,
          failed: 0,
          pending: 0,
        };

      current.total += 1;

      const status =
        normalizeStatus(delivery.status);

      if (
        status === 'delivered' ||
        status === 'success' ||
        status === 'completed'
      ) {
        current.delivered += 1;
      } else if (
        status === 'failed' ||
        status === 'error' ||
        status === 'rejected' ||
        status === 'dead'
      ) {
        current.failed += 1;
      } else {
        current.pending += 1;
      }

      map.set(channel, current);
    });

    return Array.from(map.entries())
      .map(([channel, value]) => ({
        channel,
        ...value,
      }))
      .sort(
        (a, b) =>
          b.total - a.total,
      );
  }, [deliveries]);

  const maxChannelVolume = Math.max(
    1,
    ...channelDistribution.map(
      (entry) => entry.total,
    ),
  );

  // =============================================================================
  // MESSAGE TYPE DISTRIBUTION
  // =============================================================================

  const messageTypeDistribution = useMemo(() => {
    const map = new Map<string, number>();

    messages.forEach((message) => {
      const type =
        message.messageType || 'unknown';

      map.set(
        type,
        (map.get(type) ?? 0) + 1,
      );
    });

    return Array.from(map.entries())
      .map(([messageType, count]) => ({
        messageType,
        count,
      }))
      .sort(
        (a, b) =>
          b.count - a.count,
      )
      .slice(0, 20);
  }, [messages]);

  const maxMessageTypeVolume = Math.max(
    1,
    ...messageTypeDistribution.map(
      (entry) => entry.count,
    ),
  );

  // =============================================================================
  // LIVE ACTIVITY
  // =============================================================================

  const liveActivity = useMemo<LiveActivity[]>(() => {
    const activity: LiveActivity[] = [];

    messages.forEach((message) => {
      activity.push({
        key: `message-${message.id}`,
        kind: 'message',
        id: message.id,
        timestamp: message.sentAt,
        primary: message.messageType,
        secondary:
          `${message.senderType} ${message.senderId ?? ''}`.trim(),
        status:
          normalizeStatus(message.status),
      });
    });

    deliveries.forEach((delivery) => {
      activity.push({
        key: `delivery-${delivery.id}`,
        kind: 'delivery',
        id: delivery.id,
        timestamp: delivery.attemptedAt,
        primary: delivery.channel,
        secondary:
          `${delivery.provider ?? 'provider'} · message ${delivery.messageId.slice(0, 8)}`,
        status:
          normalizeStatus(delivery.status),
        channel:
          normalizeChannel(delivery.channel),
        provider:
          delivery.provider ?? undefined,
      });
    });

    return activity
      .sort(
        (a, b) =>
          safeTimestamp(b.timestamp) -
          safeTimestamp(a.timestamp),
      )
      .slice(0, MAX_LIVE_ACTIVITY);
  }, [messages, deliveries]);

  // =============================================================================
  // FAILED DELIVERIES
  // =============================================================================

  const failedDeliveries = useMemo(
    () =>
      deliveries
        .filter((delivery) => {
          const status =
            normalizeStatus(delivery.status);

          return (
            status === 'failed' ||
            status === 'error' ||
            status === 'rejected' ||
            status === 'dead'
          );
        })
        .slice(0, MAX_FAILURES),
    [deliveries],
  );

  // =============================================================================
  // RENDER — INITIAL LOAD
  // =============================================================================

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Connecting to AMEXAN notification control plane…
      </div>
    );
  }

  // =============================================================================
  // RENDER — COMPLETE FAILURE
  // =============================================================================

  if (error && !data) {
    return (
      <div>
        <div className="admin-error">
          {error}
        </div>

        <button
          type="button"
          className="admin-page-btn"
          onClick={() => void load(false)}
          style={{ marginTop: 12 }}
        >
          Retry connection
        </button>
      </div>
    );
  }

  // =============================================================================
  // RENDER
  // =============================================================================

  return (
    <div>
      {/* =======================================================================
          LIVE HEADER
          ======================================================================= */}

      <div
        className="admin-panel"
        style={{ marginBottom: 16 }}
      >
        <div
          className="admin-panel-head"
          style={{
            alignItems: 'center',
            gap: 12,
          }}
        >
          <div>
            <span className="admin-panel-title">
              Notification Control Center
            </span>

            <span className="admin-panel-sub">
              Live communication delivery telemetry
            </span>
          </div>

          <div
            style={{
              marginLeft: 'auto',
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              flexWrap: 'wrap',
            }}
          >
            <LiveIndicator
              state={connectionState}
              lastUpdated={lastUpdated}
            />

            <button
              type="button"
              className="admin-page-btn"
              disabled={refreshing}
              onClick={() => void load(false)}
              aria-label="Refresh notifications"
            >
              {refreshing
                ? 'Refreshing…'
                : 'Refresh'}
            </button>
          </div>
        </div>

        {error && data && (
          <div
            className="admin-error"
            role="status"
            style={{ marginTop: 10 }}
          >
            {error}
          </div>
        )}

        <div
          className="admin-activity-meta"
          style={{
            display: 'flex',
            gap: 20,
            flexWrap: 'wrap',
            marginTop: 10,
          }}
        >
          <span>
            <strong>2s</strong> live polling
          </span>

          <span>
            <strong>{relativeAge(lastUpdated)}</strong>{' '}
            last sync
          </span>

          <span>
            <strong>{recentMessages}</strong>{' '}
            messages / 60s
          </span>

          <span>
            <strong>{recentDeliveries}</strong>{' '}
            deliveries / 60s
          </span>
        </div>
      </div>

      {/* =======================================================================
          PRIMARY TELEMETRY
          ======================================================================= */}

      <div className="admin-tile-grid">
        <MetricTile
          label="Total Messages"
          value={data?.messageTotal ?? 0}
          note="communication records"
          tone="brand"
        />

        <MetricTile
          label="Recent Messages"
          value={recentMessages}
          note="last 60 seconds"
        />

        <MetricTile
          label="Deliveries"
          value={deliveryStats.total}
          note="latest delivery records"
        />

        <MetricTile
          label="Delivered"
          value={deliveryStats.delivered}
          note={`${deliverySuccessRate}% success rate`}
          tone="good"
        />

        <MetricTile
          label="Pending"
          value={
            deliveryStats.pending +
            deliveryStats.processing +
            deliveryStats.retrying
          }
          note={`${deliveryStats.processing} processing · ${deliveryStats.retrying} retrying`}
          tone="warn"
        />

        <MetricTile
          label="Failed"
          value={deliveryStats.failed}
          note="requires attention"
          tone={
            deliveryStats.failed > 0
              ? 'bad'
              : 'good'
          }
        />
      </div>

      {/* =======================================================================
          FILTER BAR
          ======================================================================= */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Live Filters
          </span>

          <span className="admin-panel-sub">
            applied locally to the current control-plane projection
          </span>
        </div>

        <div
          className="admin-filters"
          style={{
            alignItems: 'flex-end',
            flexWrap: 'wrap',
          }}
        >
          <label>
            Channel
            <select
              className="admin-input"
              value={channelFilter}
              onChange={(e) =>
                setChannelFilter(
                  e.target.value,
                )
              }
            >
              <option value="ALL">
                all channels
              </option>

              {channelOptions.map(
                (channel) => (
                  <option
                    key={channel}
                    value={channel}
                  >
                    {channel}
                  </option>
                ),
              )}
            </select>
          </label>

          <label>
            Status
            <select
              className="admin-input"
              value={statusFilter}
              onChange={(e) =>
                setStatusFilter(
                  e.target.value,
                )
              }
            >
              <option value="ALL">
                all statuses
              </option>

              {statusOptions.map(
                (status) => (
                  <option
                    key={status}
                    value={status}
                  >
                    {status}
                  </option>
                ),
              )}
            </select>
          </label>

          <label
            style={{
              minWidth: 220,
            }}
          >
            Search
            <input
              className="admin-input"
              type="search"
              placeholder="message, sender, type, ID…"
              value={messageSearch}
              onChange={(e) =>
                setMessageSearch(
                  e.target.value,
                )
              }
            />
          </label>

          <button
            type="button"
            className={`admin-page-btn${
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
            {showOnlyFailures
              ? 'All delivery states'
              : 'Failures only'}
          </button>

          <button
            type="button"
            className={`admin-page-btn${
              showOnlyRecent
                ? ' active'
                : ''
            }`}
            onClick={() =>
              setShowOnlyRecent(
                (value) => !value,
              )
            }
          >
            {showOnlyRecent
              ? 'All time'
              : 'Last 60 seconds'}
          </button>

          <button
            type="button"
            className="admin-page-btn"
            onClick={() => {
              setChannelFilter('ALL');
              setStatusFilter('ALL');
              setMessageSearch('');
              setShowOnlyFailures(false);
              setShowOnlyRecent(false);
            }}
          >
            Reset
          </button>
        </div>
      </div>

      {/* =======================================================================
          LIVE ACTIVITY + FAILURE ATTENTION
          ======================================================================= */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        {/* LIVE ACTIVITY */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Live Communication Activity
            </span>

            <span className="admin-panel-sub">
              latest message + delivery events
            </span>
          </div>

          {liveActivity.length === 0 && (
            <div className="admin-empty">
              No communication activity recorded.
            </div>
          )}

          {liveActivity.length > 0 && (
            <div className="admin-activity">
              {liveActivity.map(
                (activity) => (
                  <div
                    key={activity.key}
                    className="admin-activity-item"
                  >
                    <span className="admin-activity-time">
                      {formatTime(
                        activity.timestamp,
                      )}
                    </span>

                    <span className="admin-activity-type">
                      {activity.kind ===
                      'message'
                        ? 'MESSAGE'
                        : 'DELIVERY'}
                    </span>

                    <span className="admin-activity-meta">
                      {activity.primary}
                      {activity.secondary
                        ? ` · ${truncate(
                            activity.secondary,
                            70,
                          )}`
                        : ''}
                    </span>

                    <span className="admin-activity-tag">
                      <StatusBadge
                        status={
                          activity.status
                        }
                      />
                    </span>
                  </div>
                ),
              )}
            </div>
          )}
        </div>

        {/* FAILURES */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Delivery Attention Queue
            </span>

            <span className="admin-panel-sub">
              failed communication attempts
            </span>
          </div>

          {failedDeliveries.length === 0 && (
            <div className="admin-empty">
              No failed deliveries in the current projection.
            </div>
          )}

          {failedDeliveries.length > 0 && (
            <div
              className="admin-table-wrap"
            >
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>
                      Channel
                    </th>
                    <th>
                      Provider
                    </th>
                    <th>
                      Status
                    </th>
                    <th>
                      Message
                    </th>
                    <th>
                      Attempted
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {failedDeliveries.map(
                    (delivery) => (
                      <tr
                        key={delivery.id}
                      >
                        <td className="mono">
                          {
                            delivery.channel
                          }
                        </td>

                        <td className="mono">
                          {
                            delivery.provider ??
                            '—'
                          }
                        </td>

                        <td>
                          <StatusBadge
                            status={
                              delivery.status
                            }
                          />
                        </td>

                        <td className="mono">
                          {delivery.messageId.slice(
                            0,
                            8,
                          )}
                        </td>

                        <td className="mono">
                          {formatDate(
                            delivery.attemptedAt,
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

      {/* =======================================================================
          CHANNEL + MESSAGE TYPE TELEMETRY
          ======================================================================= */}

      <div
        className="admin-grid-2"
        style={{ marginTop: 16 }}
      >
        {/* CHANNELS */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Channel Telemetry
            </span>

            <span className="admin-panel-sub">
              communication routing distribution
            </span>
          </div>

          {channelDistribution.length ===
            0 && (
            <div className="admin-empty">
              No channel delivery data.
            </div>
          )}

          {channelDistribution.length >
            0 && (
            <div className="admin-bar-list">
              {channelDistribution.map(
                (entry) => (
                  <div
                    className="admin-bar-row"
                    key={entry.channel}
                  >
                    <span className="admin-bar-label mono">
                      {entry.channel}
                    </span>

                    <div className="admin-bar-track">
                      <div
                        className="admin-bar-fill"
                        style={{
                          width: `${
                            (entry.total /
                              maxChannelVolume) *
                            100
                          }%`,
                        }}
                      />
                    </div>

                    <span className="admin-bar-value num">
                      {entry.total}
                    </span>

                    <span className="muted small">
                      ✓{' '}
                      {entry.delivered}
                      {' · '}
                      ✕{' '}
                      {entry.failed}
                    </span>
                  </div>
                ),
              )}
            </div>
          )}
        </div>

        {/* MESSAGE TYPES */}

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              Message Types
            </span>

            <span className="admin-panel-sub">
              latest communication projection
            </span>
          </div>

          {messageTypeDistribution.length ===
            0 && (
            <div className="admin-empty">
              No message types recorded.
            </div>
          )}

          {messageTypeDistribution.length >
            0 && (
            <div className="admin-bar-list">
              {messageTypeDistribution.map(
                (entry) => (
                  <div
                    className="admin-bar-row"
                    key={entry.messageType}
                  >
                    <span className="admin-bar-label mono">
                      {entry.messageType}
                    </span>

                    <div className="admin-bar-track">
                      <div
                        className="admin-bar-fill"
                        style={{
                          width: `${
                            (entry.count /
                              maxMessageTypeVolume) *
                            100
                          }%`,
                        }}
                      />
                    </div>

                    <span className="admin-bar-value num">
                      {entry.count}
                    </span>
                  </div>
                ),
              )}
            </div>
          )}
        </div>
      </div>

      {/* =======================================================================
          MESSAGE STREAM
          ======================================================================= */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Message Stream
          </span>

          <span className="admin-panel-sub">
            {filteredMessages.length} of{' '}
            {messages.length} loaded messages
          </span>
        </div>

        {filteredMessages.length === 0 && (
          <div className="admin-empty">
            No messages match the active filters.
          </div>
        )}

        {filteredMessages.length > 0 && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>
                    Type
                  </th>

                  <th>
                    Sender
                  </th>

                  <th>
                    Message
                  </th>

                  <th>
                    Status
                  </th>

                  <th>
                    Sent
                  </th>

                  <th>
                    Age
                  </th>
                </tr>
              </thead>

              <tbody>
                {filteredMessages.map(
                  (message) => (
                    <tr
                      key={message.id}
                    >
                      <td className="mono">
                        {
                          message.messageType
                        }
                      </td>

                      <td className="mono">
                        {
                          message.senderType
                        }

                        {message.senderId
                          ? ` ${message.senderId.slice(
                              0,
                              8,
                            )}`
                          : ''}
                      </td>

                      <td
                        className="mono"
                        title={
                          message.body ??
                          ''
                        }
                      >
                        {truncate(
                          message.body,
                          100,
                        )}
                      </td>

                      <td>
                        <StatusBadge
                          status={
                            message.status
                          }
                        />
                      </td>

                      <td className="mono">
                        {formatDate(
                          message.sentAt,
                        )}
                      </td>

                      <td className="muted small">
                        {relativeAge(
                          message.sentAt,
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

      {/* =======================================================================
          DELIVERY STREAM
          ======================================================================= */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Delivery Stream
          </span>

          <span className="admin-panel-sub">
            {filteredDeliveries.length} of{' '}
            {deliveries.length} loaded delivery attempts
          </span>
        </div>

        {filteredDeliveries.length === 0 && (
          <div className="admin-empty">
            No deliveries match the active filters.
          </div>
        )}

        {filteredDeliveries.length > 0 && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>
                    Channel
                  </th>

                  <th>
                    Provider
                  </th>

                  <th>
                    Status
                  </th>

                  <th>
                    Message
                  </th>

                  <th>
                    Attempted
                  </th>

                  <th>
                    Age
                  </th>
                </tr>
              </thead>

              <tbody>
                {filteredDeliveries.map(
                  (delivery) => (
                    <tr
                      key={delivery.id}
                    >
                      <td className="mono">
                        {
                          delivery.channel
                        }
                      </td>

                      <td className="mono">
                        {
                          delivery.provider ??
                          '—'
                        }
                      </td>

                      <td>
                        <StatusBadge
                          status={
                            delivery.status
                          }
                        />
                      </td>

                      <td className="mono">
                        {
                          delivery.messageId.slice(
                            0,
                            12,
                          )
                        }
                      </td>

                      <td className="mono">
                        {formatDate(
                          delivery.attemptedAt,
                        )}
                      </td>

                      <td className="muted small">
                        {relativeAge(
                          delivery.attemptedAt,
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

      {/* =======================================================================
          MESSAGE STATISTICS
          ======================================================================= */}

      <div
        className="admin-panel"
        style={{ marginTop: 16 }}
      >
        <div className="admin-panel-head">
          <span className="admin-panel-title">
            Message Status Matrix
          </span>

          <span className="admin-panel-sub">
            control-plane aggregate
          </span>
        </div>

        {stats.length === 0 && (
          <div className="admin-empty">
            No message statistics available.
          </div>
        )}

        {stats.length > 0 && (
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>
                    Message Type
                  </th>

                  <th>
                    Status
                  </th>

                  <th>
                    Count
                  </th>
                </tr>
              </thead>

              <tbody>
                {stats.map(
                  (stat) => (
                    <tr
                      key={`${stat.messageType}-${stat.status}`}
                    >
                      <td className="mono">
                        {
                          stat.messageType
                        }
                      </td>

                      <td>
                        <StatusBadge
                          status={
                            stat.status
                          }
                        />
                      </td>

                      <td className="num">
                        {stat.count}
                      </td>
                    </tr>
                  ),
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* =======================================================================
          FOOTER TELEMETRY
          ======================================================================= */}

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
              {data?.messageTotal ?? 0}
            </strong>{' '}
            total messages
          </span>

          <span>
            <strong>
              {deliveryStats.delivered}
            </strong>{' '}
            delivered
          </span>

          <span>
            <strong>
              {deliveryStats.failed}
            </strong>{' '}
            failed
          </span>

          <span>
            <strong>
              {deliveryStats.pending}
            </strong>{' '}
            pending
          </span>

          <span>
            <strong>
              {deliveryStats.retrying}
            </strong>{' '}
            retrying
          </span>

          <span>
            <strong>
              {channelDistribution.length}
            </strong>{' '}
            active channels
          </span>

          <span className="muted small">
            AMEXAN Control Plane · read-only ·{' '}
            {lastUpdated
              ? `synchronized ${formatDate(
                  lastUpdated,
                )}`
              : 'awaiting synchronization'}
          </span>
        </div>
      </div>
    </div>
  );
}