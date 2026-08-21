// =============================================================================
// AMEXAN Integrations — Interoperability Command Surface
//
// OPERATE / INVESTIGATE
//
// Responsibilities
// -----------------------------------------------------------------------------
// • External system registry
// • Endpoint registry
// • Connection health
// • Connection latency / heartbeat state
// • Integration message traffic
// • Inbound / outbound message health
// • Message failure visibility
// • Error visibility
// • Message throughput
// • Integration availability
// • Search / filtering
// • Realtime polling
// • Endpoint → connection → message correlation
// • System → endpoint → connection → message hierarchy
//
// IMPORTANT
// -----------------------------------------------------------------------------
// • Read-only administration projection.
// • No PostgreSQL access from the browser.
// • All data comes from the AMEXAN Control Plane API.
// • The browser never receives credentials/secrets.
// • Sensitive endpoint configuration must be redacted server-side.
// • Polling is used as the realtime transport fallback.
// • If the Control Plane later exposes SSE/WebSocket, this component can be
//   switched to that transport without changing the projection model.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { getIntegrationsOverview } from '../api';

import type {
  IntegrationsOverview,
} from '../types';

// =============================================================================
// TYPES
// =============================================================================

type IntegrationFilter =
  | 'all'
  | 'healthy'
  | 'degraded'
  | 'error'
  | 'disconnected';

type MessageFilter =
  | 'all'
  | 'inbound'
  | 'outbound'
  | 'success'
  | 'pending'
  | 'failed';

type IntegrationTab =
  | 'overview'
  | 'systems'
  | 'connections'
  | 'messages';

type SortDirection = 'asc' | 'desc';

interface SortState {
  field:
    | 'system'
    | 'endpoint'
    | 'status'
    | 'updated'
    | 'direction'
    | 'messageType'
    | 'created';
  direction: SortDirection;
}

// =============================================================================
// CONSTANTS
// =============================================================================

const REFRESH_INTERVAL = 15000;
const MESSAGE_LIMIT = 100;

const CONNECTION_STATUSES = {
  CONNECTED: 'connected',
  HEALTHY: 'healthy',
  DEGRADED: 'degraded',
  ERROR: 'error',
  DISCONNECTED: 'disconnected',
  PENDING: 'pending',
  UNKNOWN: 'unknown',
} as const;

const MESSAGE_STATUSES = {
  SUCCESS: 'success',
  COMPLETED: 'completed',
  DELIVERED: 'delivered',
  PROCESSED: 'processed',
  PENDING: 'pending',
  QUEUED: 'queued',
  FAILED: 'failed',
  ERROR: 'error',
} as const;

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

function shortId(value: unknown, length = 8): string {
  const text = safeString(value);
  if (!text) return '—';
  return text.length > length ? text.slice(0, length) : text;
}

function formatDate(
  value: string | number | Date | null | undefined,
): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '—';
  }

  return date.toLocaleString();
}

function formatRelativeTime(
  value: string | number | Date | null | undefined,
): string {
  if (!value) return '—';

  const timestamp = new Date(value).getTime();

  if (Number.isNaN(timestamp)) return '—';

  const diff = Date.now() - timestamp;

  if (diff < 0) return 'just now';

  const seconds = Math.floor(diff / 1000);

  if (seconds < 10) return 'just now';
  if (seconds < 60) return `${seconds}s ago`;

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);

  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);

  return `${days}d ago`;
}

function normalizeStatus(value: unknown): string {
  return safeString(value).trim().toLowerCase();
}

function isConnectionHealthy(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return (
    normalized === CONNECTION_STATUSES.CONNECTED ||
    normalized === CONNECTION_STATUSES.HEALTHY
  );
}

function isConnectionDegraded(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return (
    normalized === CONNECTION_STATUSES.DEGRADED ||
    normalized === CONNECTION_STATUSES.PENDING
  );
}

function isConnectionError(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return normalized === CONNECTION_STATUSES.ERROR;
}

function isConnectionDisconnected(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return normalized === CONNECTION_STATUSES.DISCONNECTED;
}

function isMessageSuccessful(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return (
    normalized === MESSAGE_STATUSES.SUCCESS ||
    normalized === MESSAGE_STATUSES.COMPLETED ||
    normalized === MESSAGE_STATUSES.DELIVERED ||
    normalized === MESSAGE_STATUSES.PROCESSED
  );
}

function isMessagePending(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return (
    normalized === MESSAGE_STATUSES.PENDING ||
    normalized === MESSAGE_STATUSES.QUEUED
  );
}

function isMessageFailed(status: unknown): boolean {
  const normalized = normalizeStatus(status);

  return (
    normalized === MESSAGE_STATUSES.FAILED ||
    normalized === MESSAGE_STATUSES.ERROR
  );
}

function normalizeDirection(value: unknown): string {
  return safeString(value).trim().toLowerCase();
}

function isInbound(value: unknown): boolean {
  return normalizeDirection(value) === 'inbound';
}

function isOutbound(value: unknown): boolean {
  return normalizeDirection(value) === 'outbound';
}

function getStatusClass(status: unknown): string {
  const normalized = normalizeStatus(status);

  if (isConnectionHealthy(normalized)) {
    return 'ok';
  }

  if (isConnectionError(normalized)) {
    return 'bad';
  }

  if (
    isConnectionDegraded(normalized) ||
    normalized === 'warning'
  ) {
    return 'warn';
  }

  if (isConnectionDisconnected(normalized)) {
    return 'bad';
  }

  return '';
}

function getMessageStatusClass(status: unknown): string {
  if (isMessageSuccessful(status)) return 'ok';
  if (isMessageFailed(status)) return 'bad';
  if (isMessagePending(status)) return 'warn';
  return '';
}

function getDirectionClass(direction: unknown): string {
  if (isInbound(direction)) return 'ok';
  if (isOutbound(direction)) return 'warn';
  return '';
}

function safeLower(value: unknown): string {
  return safeString(value).toLowerCase();
}

// =============================================================================
// STATUS BADGE
// =============================================================================

function StatusBadge({
  status,
}: {
  status: string | null | undefined;
}) {
  const normalized = normalizeStatus(status);

  return (
    <span className={`admin-badge ${getStatusClass(normalized)}`}>
      {displayValue(normalized, 'unknown')}
    </span>
  );
}

// =============================================================================
// MESSAGE BADGE
// =============================================================================

function MessageStatusBadge({
  status,
}: {
  status: string | null | undefined;
}) {
  const normalized = normalizeStatus(status);

  return (
    <span className={`admin-badge ${getMessageStatusClass(normalized)}`}>
      {displayValue(normalized, 'unknown')}
    </span>
  );
}

// =============================================================================
// DIRECTION BADGE
// =============================================================================

function DirectionBadge({
  direction,
}: {
  direction: string | null | undefined;
}) {
  const normalized = normalizeDirection(direction);

  return (
    <span
      className={`admin-badge ${getDirectionClass(normalized)}`}
    >
      {displayValue(normalized, 'unknown')}
    </span>
  );
}

// =============================================================================
// SORT ICON
// =============================================================================

function SortIndicator({
  active,
  direction,
}: {
  active: boolean;
  direction: SortDirection;
}) {
  if (!active) {
    return (
      <span
        aria-hidden="true"
        style={{
          opacity: 0.35,
          marginLeft: 4,
        }}
      >
        ↕
      </span>
    );
  }

  return (
    <span
      aria-hidden="true"
      style={{
        marginLeft: 4,
      }}
    >
      {direction === 'asc' ? '↑' : '↓'}
    </span>
  );
}

// =============================================================================
// SYSTEM CARD
// =============================================================================

function SystemCard({
  system,
  endpointCount,
  connectedCount,
  errorCount,
  onSelect,
}: {
  system: {
    id: string;
    name: string;
    code?: string | null;
  };
  endpointCount: number;
  connectedCount: number;
  errorCount: number;
  onSelect: () => void;
}) {
  const status =
    errorCount > 0
      ? 'error'
      : connectedCount === endpointCount && endpointCount > 0
        ? 'connected'
        : connectedCount > 0
          ? 'degraded'
          : endpointCount > 0
            ? 'disconnected'
            : 'unknown';

  return (
    <button
      type="button"
      className="admin-panel"
      onClick={onSelect}
      style={{
        textAlign: 'left',
        width: '100%',
        cursor: 'pointer',
        border: '1px solid var(--border, #e5e7eb)',
      }}
    >
      <div className="admin-panel-head">
        <span className="admin-panel-title">
          {displayValue(system.name)}
        </span>

        <StatusBadge status={status} />
      </div>

      <div
        className="admin-kv"
        style={{
          marginTop: 8,
        }}
      >
        <span className="k">Code</span>
        <span className="v mono">
          {displayValue(system.code)}
        </span>

        <span className="k">Endpoints</span>
        <span className="v num">
          {endpointCount}
        </span>

        <span className="k">Connected</span>
        <span className="v num">
          {connectedCount}
        </span>

        <span className="k">Errors</span>
        <span className="v num">
          {errorCount}
        </span>
      </div>
    </button>
  );
}

// =============================================================================
// MAIN VIEW
// =============================================================================

export function IntegrationsView() {
  const [data, setData] =
    useState<IntegrationsOverview | null>(null);

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [tab, setTab] =
    useState<IntegrationTab>('overview');

  const [integrationFilter, setIntegrationFilter] =
    useState<IntegrationFilter>('all');

  const [messageFilter, setMessageFilter] =
    useState<MessageFilter>('all');

  const [search, setSearch] = useState('');

  const [selectedSystemId, setSelectedSystemId] =
    useState<string | null>(null);

  const [selectedEndpointId, setSelectedEndpointId] =
    useState<string | null>(null);

  const [sort, setSort] = useState<SortState>({
    field: 'updated',
    direction: 'desc',
  });

  const [lastUpdated, setLastUpdated] =
    useState<Date | null>(null);

  const mountedRef = useRef(true);
  const requestRef = useRef(0);

  // ===========================================================================
  // LOAD
  // ===========================================================================

  const load = useCallback(
    async (background = false) => {
      const requestId = ++requestRef.current;

      if (background) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }

      try {
        const next = await getIntegrationsOverview();

        if (!mountedRef.current) return;

        if (requestId !== requestRef.current) return;

        setData(next);
        setError(null);
        setLastUpdated(new Date());
      } catch (e) {
        if (!mountedRef.current) return;

        if (e instanceof Error) {
          setError(e.message);
        } else {
          setError('Failed to load integrations');
        }
      } finally {
        if (!mountedRef.current) return;

        if (background) {
          setRefreshing(false);
        } else {
          setLoading(false);
        }
      }
    },
    [],
  );

  // ===========================================================================
  // INITIAL + REALTIME POLLING
  // ===========================================================================

  useEffect(() => {
    mountedRef.current = true;

    void load(false);

    const timer = window.setInterval(() => {
      void load(true);
    }, REFRESH_INTERVAL);

    return () => {
      mountedRef.current = false;
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // DATA NORMALIZATION
  // ===========================================================================

  const systems = useMemo(
    () => data?.systems ?? [],
    [data],
  );

  const endpoints = useMemo(
    () => data?.endpoints ?? [],
    [data],
  );

  const connections = useMemo(
    () => data?.connections ?? [],
    [data],
  );

  const messages = useMemo(
    () =>
      (data?.messages ?? []).slice(0, MESSAGE_LIMIT),
    [data],
  );

  const messageStats = useMemo(
    () => data?.messageStats ?? [],
    [data],
  );

  // ===========================================================================
  // RELATION MAPS
  // ===========================================================================

  const endpointById = useMemo(() => {
    const map = new Map<string, (typeof endpoints)[number]>();

    for (const endpoint of endpoints) {
      map.set(endpoint.id, endpoint);
    }

    return map;
  }, [endpoints]);

  const systemById = useMemo(() => {
    const map = new Map<string, (typeof systems)[number]>();

    for (const system of systems) {
      map.set(system.id, system);
    }

    return map;
  }, [systems]);

  const connectionsByEndpoint = useMemo(() => {
    const map = new Map<
      string,
      (typeof connections)
    >();

    for (const connection of connections) {
      if (!connection.endpointId) continue;

      const current =
        map.get(connection.endpointId) ?? [];

      current.push(connection);

      map.set(connection.endpointId, current);
    }

    return map;
  }, [connections]);

  const endpointsBySystem = useMemo(() => {
    const map = new Map<
      string,
      (typeof endpoints)
    >();

    for (const endpoint of endpoints) {
      const current =
        map.get(endpoint.systemId ?? '') ?? [];

      current.push(endpoint);

      map.set(endpoint.systemId ?? '', current);
    }

    return map;
  }, [endpoints]);

  // ===========================================================================
  // CONNECTION HEALTH
  // ===========================================================================

  const healthyConnections = useMemo(
    () =>
      connections.filter((connection) =>
        isConnectionHealthy(connection.status),
      ),
    [connections],
  );

  const degradedConnections = useMemo(
    () =>
      connections.filter((connection) =>
        isConnectionDegraded(connection.status),
      ),
    [connections],
  );

  const failedConnections = useMemo(
    () =>
      connections.filter((connection) =>
        isConnectionError(connection.status),
      ),
    [connections],
  );

  const disconnectedConnections = useMemo(
    () =>
      connections.filter((connection) =>
        isConnectionDisconnected(connection.status),
      ),
    [connections],
  );

  const connectionHealthPercentage = useMemo(() => {
    if (connections.length === 0) return 100;

    return Math.round(
      (healthyConnections.length / connections.length) *
        100,
    );
  }, [
    connections.length,
    healthyConnections.length,
  ]);

  // ===========================================================================
  // MESSAGE HEALTH
  // ===========================================================================

  const successfulMessages = useMemo(
    () =>
      messages.filter((message) =>
        isMessageSuccessful(message.status),
      ),
    [messages],
  );

  const pendingMessages = useMemo(
    () =>
      messages.filter((message) =>
        isMessagePending(message.status),
      ),
    [messages],
  );

  const failedMessages = useMemo(
    () =>
      messages.filter((message) =>
        isMessageFailed(message.status),
      ),
    [messages],
  );

  const inboundMessages = useMemo(
    () =>
      messages.filter((message) =>
        isInbound(message.direction),
      ),
    [messages],
  );

  const outboundMessages = useMemo(
    () =>
      messages.filter((message) =>
        isOutbound(message.direction),
      ),
    [messages],
  );

  const messageSuccessRate = useMemo(() => {
    if (messages.length === 0) return 100;

    return Math.round(
      (successfulMessages.length / messages.length) *
        100,
    );
  }, [
    messages.length,
    successfulMessages.length,
  ]);

  // ===========================================================================
  // SYSTEM STATUS
  // ===========================================================================

  const systemHealth = useCallback(
    (systemId: string) => {
      const systemEndpoints =
        endpointsBySystem.get(systemId) ?? [];

      const endpointIds = new Set(
        systemEndpoints.map((endpoint) => endpoint.id),
      );

      const systemConnections =
        connections.filter(
          (connection) =>
            connection.endpointId &&
            endpointIds.has(connection.endpointId),
        );

      const connected = systemConnections.filter(
        (connection) =>
          isConnectionHealthy(connection.status),
      ).length;

      const errors = systemConnections.filter(
        (connection) =>
          isConnectionError(connection.status),
      ).length;

      return {
        endpoints: systemEndpoints.length,
        connections: systemConnections.length,
        connected,
        errors,
      };
    },
    [
      connections,
      endpointsBySystem,
    ],
  );

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  const normalizedSearch = safeLower(search);

  // ===========================================================================
  // FILTERED CONNECTIONS
  // ===========================================================================

  const filteredConnections = useMemo(() => {
    return connections.filter((connection) => {
      const status =
        normalizeStatus(connection.status);

      if (
        integrationFilter === 'healthy' &&
        !isConnectionHealthy(status)
      ) {
        return false;
      }

      if (
        integrationFilter === 'degraded' &&
        !isConnectionDegraded(status)
      ) {
        return false;
      }

      if (
        integrationFilter === 'error' &&
        !isConnectionError(status)
      ) {
        return false;
      }

      if (
        integrationFilter === 'disconnected' &&
        !isConnectionDisconnected(status)
      ) {
        return false;
      }

      if (!normalizedSearch) return true;

      const endpoint =
        connection.endpointId
          ? endpointById.get(connection.endpointId)
          : undefined;

      const system =
        endpoint?.systemId
          ? systemById.get(endpoint.systemId)
          : undefined;

      const haystack = [
        connection.id,
        connection.endpointId,
        connection.status,
        connection.lastError,
        endpoint?.name,
        system?.name,
        system?.code,
      ]
        .map(safeLower)
        .join(' ');

      return haystack.includes(normalizedSearch);
    });
  }, [
    connections,
    endpointById,
    systemById,
    integrationFilter,
    normalizedSearch,
  ]);

  // ===========================================================================
  // FILTERED MESSAGES
  // ===========================================================================

  const filteredMessages = useMemo(() => {
    const result = messages.filter((message) => {
      const direction =
        normalizeDirection(message.direction);

      const status =
        normalizeStatus(message.status);

      if (
        messageFilter === 'inbound' &&
        direction !== 'inbound'
      ) {
        return false;
      }

      if (
        messageFilter === 'outbound' &&
        direction !== 'outbound'
      ) {
        return false;
      }

      if (
        messageFilter === 'success' &&
        !isMessageSuccessful(status)
      ) {
        return false;
      }

      if (
        messageFilter === 'pending' &&
        !isMessagePending(status)
      ) {
        return false;
      }

      if (
        messageFilter === 'failed' &&
        !isMessageFailed(status)
      ) {
        return false;
      }

      if (!normalizedSearch) return true;

      const system =
        message.systemId
          ? systemById.get(message.systemId)
          : undefined;

      const endpoint =
        message.endpointId
          ? endpointById.get(message.endpointId)
          : undefined;

      const haystack = [
        message.id,
        message.systemId,
        message.endpointId,
        message.direction,
        message.messageType,
        message.externalMessageId,
        message.status,
        system?.name,
        system?.code,
        endpoint?.name,
      ]
        .map(safeLower)
        .join(' ');

      return haystack.includes(normalizedSearch);
    });

    return result;
  }, [
    messages,
    messageFilter,
    normalizedSearch,
    systemById,
    endpointById,
  ]);

  // ===========================================================================
  // SORT CONNECTIONS
  // ===========================================================================

  const sortedConnections = useMemo(() => {
    const result = [...filteredConnections];

    result.sort((a, b) => {
      let left = '';
      let right = '';

      if (sort.field === 'status') {
        left = safeLower(a.status);
        right = safeLower(b.status);
      }

      if (sort.field === 'endpoint') {
        const endpointA = a.endpointId
          ? endpointById.get(a.endpointId)
          : undefined;

        const endpointB = b.endpointId
          ? endpointById.get(b.endpointId)
          : undefined;

        left = safeLower(endpointA?.name);
        right = safeLower(endpointB?.name);
      }

      if (sort.field === 'system') {
        const endpointA = a.endpointId
          ? endpointById.get(a.endpointId)
          : undefined;

        const endpointB = b.endpointId
          ? endpointById.get(b.endpointId)
          : undefined;

        const systemA = endpointA?.systemId
          ? systemById.get(endpointA.systemId)
          : undefined;

        const systemB = endpointB?.systemId
          ? systemById.get(endpointB.systemId)
          : undefined;

        left = safeLower(systemA?.name);
        right = safeLower(systemB?.name);
      }

      if (sort.field === 'updated') {
        left = safeString(
          new Date(a.updatedAt).getTime(),
        );

        right = safeString(
          new Date(b.updatedAt).getTime(),
        );
      }

      const comparison =
        left.localeCompare(right, undefined, {
          numeric: true,
          sensitivity: 'base',
        });

      return sort.direction === 'asc'
        ? comparison
        : -comparison;
    });

    return result;
  }, [
    filteredConnections,
    sort,
    endpointById,
    systemById,
  ]);

  // ===========================================================================
  // SORT MESSAGES
  // ===========================================================================

  const sortedMessages = useMemo(() => {
    const result = [...filteredMessages];

    result.sort((a, b) => {
      let left = '';
      let right = '';

      if (sort.field === 'direction') {
        left = safeLower(a.direction);
        right = safeLower(b.direction);
      }

      if (sort.field === 'messageType') {
        left = safeLower(a.messageType);
        right = safeLower(b.messageType);
      }

      if (sort.field === 'created') {
        left = safeString(
          new Date(a.createdAt).getTime(),
        );

        right = safeString(
          new Date(b.createdAt).getTime(),
        );
      }

      if (!left && !right) return 0;

      const comparison =
        left.localeCompare(right, undefined, {
          numeric: true,
          sensitivity: 'base',
        });

      return sort.direction === 'asc'
        ? comparison
        : -comparison;
    });

    return result;
  }, [
    filteredMessages,
    sort,
  ]);

  // ===========================================================================
  // SELECTED SYSTEM
  // ===========================================================================

  const selectedSystem = useMemo(() => {
    if (!selectedSystemId) return null;

    return (
      systemById.get(selectedSystemId) ?? null
    );
  }, [
    selectedSystemId,
    systemById,
  ]);

  const selectedSystemEndpoints = useMemo(() => {
    if (!selectedSystemId) return [];

    return (
      endpointsBySystem.get(selectedSystemId) ?? []
    );
  }, [
    selectedSystemId,
    endpointsBySystem,
  ]);

  const selectedSystemConnections = useMemo(() => {
    const endpointIds = new Set(
      selectedSystemEndpoints.map(
        (endpoint) => endpoint.id,
      ),
    );

    return connections.filter(
      (connection) =>
        connection.endpointId &&
        endpointIds.has(connection.endpointId),
    );
  }, [
    selectedSystemEndpoints,
    connections,
  ]);

  // ===========================================================================
  // SELECTED ENDPOINT
  // ===========================================================================

  const selectedEndpoint = useMemo(() => {
    if (!selectedEndpointId) return null;

    return (
      endpointById.get(selectedEndpointId) ??
      null
    );
  }, [
    selectedEndpointId,
    endpointById,
  ]);

  const selectedEndpointConnections = useMemo(() => {
    if (!selectedEndpointId) return [];

    return (
      connectionsByEndpoint.get(
        selectedEndpointId,
      ) ?? []
    );
  }, [
    selectedEndpointId,
    connectionsByEndpoint,
  ]);

  // ===========================================================================
  // SORT HANDLER
  // ===========================================================================

  const handleSort = useCallback(
    (
      field: SortState['field'],
    ) => {
      setSort((current) => {
        if (current.field === field) {
          return {
            ...current,
            direction:
              current.direction === 'asc'
                ? 'desc'
                : 'asc',
          };
        }

        return {
          field,
          direction: 'asc',
        };
      });
    },
    [],
  );

  // ===========================================================================
  // SELECT SYSTEM
  // ===========================================================================

  const openSystem = useCallback(
    (systemId: string) => {
      setSelectedSystemId(systemId);
    },
    [],
  );

  // ===========================================================================
  // CLOSE SYSTEM
  // ===========================================================================

  const closeSystem = useCallback(() => {
    setSelectedSystemId(null);
  }, []);

  // ===========================================================================
  // SELECT ENDPOINT
  // ===========================================================================

  const openEndpoint = useCallback(
    (endpointId: string) => {
      setSelectedEndpointId(endpointId);
    },
    [],
  );

  // ===========================================================================
  // CLOSE ENDPOINT
  // ===========================================================================

  const closeEndpoint = useCallback(() => {
    setSelectedEndpointId(null);
  }, []);

  // ===========================================================================
  // LOADING
  // ===========================================================================

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span
          className="admin-spinner"
          aria-hidden="true"
        />
        Loading integrations…
      </div>
    );
  }

  // ===========================================================================
  // COMPLETE FAILURE
  // ===========================================================================

  if (error && !data) {
    return (
      <div>
        <div className="admin-error">
          {error}
        </div>

        <button
          type="button"
          className="admin-page-btn"
          style={{ marginTop: 12 }}
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
    <div className="admin-integrations">
      {/* =====================================================================
          ERROR / DEGRADED API BANNER
          ===================================================================== */}

      {error && (
        <div
          className="admin-error"
          role="alert"
          style={{
            marginBottom: 12,
          }}
        >
          <strong>Integration Control Plane degraded:</strong>{' '}
          {error}
        </div>
      )}

      {/* =====================================================================
          HEADER
          ===================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">
          <div>
            <span className="admin-panel-title">
              Integration Command
            </span>

            <span
              className="admin-panel-sub"
              style={{
                display: 'block',
                marginTop: 4,
              }}
            >
              AMEXAN interoperability fabric · systems ·
              endpoints · connections · messages
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
            {refreshing && (
              <span className="admin-badge warn">
                synchronizing
              </span>
            )}

            <span className="muted small">
              {lastUpdated
                ? `updated ${formatRelativeTime(lastUpdated)}`
                : 'not synchronized'}
            </span>

            <button
              type="button"
              className="admin-page-btn"
              onClick={() => void load(true)}
              disabled={refreshing}
            >
              {refreshing
                ? 'Refreshing…'
                : 'Refresh'}
            </button>
          </div>
        </div>

        {/* ================================================================
            TABS
            ================================================================ */}

        <div
          className="admin-nav"
          style={{
            marginTop: 12,
          }}
          role="tablist"
          aria-label="Integration views"
        >
          {(
            [
              ['overview', 'Overview'],
              ['systems', 'Systems'],
              ['connections', 'Connections'],
              ['messages', 'Messages'],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              role="tab"
              aria-selected={tab === value}
              className={`admin-nav-btn${
                tab === value
                  ? ' active'
                  : ''
              }`}
              onClick={() => setTab(value)}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {/* =====================================================================
          GLOBAL METRICS
          ===================================================================== */}

      <div
        className="admin-tile-grid"
        style={{
          marginTop: 16,
        }}
      >
        <div className="admin-tile">
          <span className="admin-tile-value">
            {systems.length}
          </span>

          <span className="admin-tile-label">
            External systems
          </span>

          <span className="muted small">
            registered interoperability peers
          </span>
        </div>

        <div className="admin-tile">
          <span className="admin-tile-value">
            {endpoints.length}
          </span>

          <span className="admin-tile-label">
            Endpoints
          </span>

          <span className="muted small">
            configured integration surfaces
          </span>
        </div>

        <div className="admin-tile tile-good">
          <span className="admin-tile-value">
            {healthyConnections.length}
          </span>

          <span className="admin-tile-label">
            Healthy connections
          </span>

          <span className="muted small">
            {connectionHealthPercentage}% available
          </span>
        </div>

        <div className="admin-tile tile-brand">
          <span className="admin-tile-value">
            {messages.length}
          </span>

          <span className="admin-tile-label">
            Messages observed
          </span>

          <span className="muted small">
            latest control-plane window
          </span>
        </div>

        <div className="admin-tile tile-danger">
          <span className="admin-tile-value">
            {failedConnections.length}
          </span>

          <span className="admin-tile-label">
            Connection errors
          </span>

          <span className="muted small">
            require investigation
          </span>
        </div>

        <div className="admin-tile">
          <span className="admin-tile-value">
            {failedMessages.length}
          </span>

          <span className="admin-tile-label">
            Failed messages
          </span>

          <span className="muted small">
            latest message window
          </span>
        </div>
      </div>

      {/* =====================================================================
          OVERVIEW
          ===================================================================== */}

      {tab === 'overview' && (
        <div>
          {/* ================================================================
              CONNECTION + MESSAGE HEALTH
              ================================================================ */}

          <div
            className="admin-grid-2"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel">
              <div className="admin-panel-head">
                <span className="admin-panel-title">
                  Connection Health
                </span>

                <span className="admin-panel-sub">
                  live integration state
                </span>
              </div>

              <div className="admin-kv">
                <span className="k">
                  Healthy
                </span>

                <span className="v num">
                  {healthyConnections.length}
                </span>

                <span className="k">
                  Degraded
                </span>

                <span className="v num">
                  {degradedConnections.length}
                </span>

                <span className="k">
                  Errors
                </span>

                <span className="v num">
                  {failedConnections.length}
                </span>

                <span className="k">
                  Disconnected
                </span>

                <span className="v num">
                  {disconnectedConnections.length}
                </span>

                <span className="k">
                  Health
                </span>

                <span className="v">
                  <strong>
                    {connectionHealthPercentage}%
                  </strong>
                </span>
              </div>
            </div>

            <div className="admin-panel">
              <div className="admin-panel-head">
                <span className="admin-panel-title">
                  Message Health
                </span>

                <span className="admin-panel-sub">
                  latest interoperability traffic
                </span>
              </div>

              <div className="admin-kv">
                <span className="k">
                  Successful
                </span>

                <span className="v num">
                  {successfulMessages.length}
                </span>

                <span className="k">
                  Pending
                </span>

                <span className="v num">
                  {pendingMessages.length}
                </span>

                <span className="k">
                  Failed
                </span>

                <span className="v num">
                  {failedMessages.length}
                </span>

                <span className="k">
                  Inbound
                </span>

                <span className="v num">
                  {inboundMessages.length}
                </span>

                <span className="k">
                  Outbound
                </span>

                <span className="v num">
                  {outboundMessages.length}
                </span>

                <span className="k">
                  Success rate
                </span>

                <span className="v">
                  <strong>
                    {messageSuccessRate}%
                  </strong>
                </span>
              </div>
            </div>
          </div>

          {/* ================================================================
              SYSTEM OVERVIEW
              ================================================================ */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Interoperability Systems
              </span>

              <span className="admin-panel-sub">
                system → endpoint → connection
              </span>
            </div>

            {systems.length === 0 ? (
              <div className="admin-empty">
                No interoperability systems.
              </div>
            ) : (
              <div className="admin-grid-3">
                {systems.map((system) => {
                  const health =
                    systemHealth(system.id);

                  return (
                    <SystemCard
                      key={system.id}
                      system={system}
                      endpointCount={
                        health.endpoints
                      }
                      connectedCount={
                        health.connected
                      }
                      errorCount={
                        health.errors
                      }
                      onSelect={() =>
                        openSystem(system.id)
                      }
                    />
                  );
                })}
              </div>
            )}
          </div>

          {/* ================================================================
              CONNECTION ALERTS
              ================================================================ */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Connection Attention
              </span>

              <span className="admin-panel-sub">
                degraded, failed and disconnected
              </span>
            </div>

            {failedConnections.length === 0 &&
            degradedConnections.length === 0 &&
            disconnectedConnections.length === 0 ? (
              <div className="admin-empty">
                All recorded integration connections are
                healthy.
              </div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>System</th>
                      <th>Endpoint</th>
                      <th>Status</th>
                      <th>Last error</th>
                      <th>Updated</th>
                    </tr>
                  </thead>

                  <tbody>
                    {[
                      ...failedConnections,
                      ...degradedConnections,
                      ...disconnectedConnections,
                    ].map((connection) => {
                      const endpoint =
                        connection.endpointId
                          ? endpointById.get(
                              connection.endpointId,
                            )
                          : undefined;

                      const system =
                        endpoint?.systemId
                          ? systemById.get(
                              endpoint.systemId,
                            )
                          : undefined;

                      return (
                        <tr
                          key={connection.id}
                          className="admin-row-click"
                          onClick={() =>
                            endpoint?.id &&
                            openEndpoint(
                              endpoint.id,
                            )
                          }
                        >
                          <td>
                            {displayValue(
                              system?.name,
                            )}
                          </td>

                          <td className="mono">
                            {displayValue(
                              endpoint?.name,
                            )}
                          </td>

                          <td>
                            <StatusBadge
                              status={
                                connection.status
                              }
                            />
                          </td>

                          <td>
                            {connection.lastError ? (
                              <span
                                title={
                                  connection.lastError
                                }
                              >
                                {connection.lastError
                                  .length > 100
                                  ? `${connection.lastError.slice(
                                      0,
                                      100,
                                    )}…`
                                  : connection.lastError}
                              </span>
                            ) : (
                              '—'
                            )}
                          </td>

                          <td className="mono">
                            {formatDate(
                              connection.updatedAt,
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

          {/* ================================================================
              MESSAGE TRAFFIC
              ================================================================ */}

          <div
            className="admin-panel"
            style={{ marginTop: 16 }}
          >
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Message Traffic
              </span>

              <span className="admin-panel-sub">
                inbound / outbound interoperability
              </span>
            </div>

            {messages.length === 0 ? (
              <div className="admin-empty">
                No interoperability messages recorded.
              </div>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Direction</th>
                      <th>Type</th>
                      <th>System</th>
                      <th>External ID</th>
                      <th>Status</th>
                      <th>Created</th>
                    </tr>
                  </thead>

                  <tbody>
                    {messages
                      .slice(0, 20)
                      .map((message) => {
                        const system =
                          message.systemId
                            ? systemById.get(
                                message.systemId,
                              )
                            : undefined;

                        return (
                          <tr
                            key={message.id}
                          >
                            <td>
                              <DirectionBadge
                                direction={
                                  message.direction
                                }
                              />
                            </td>

                            <td className="mono">
                              {displayValue(
                                message.messageType,
                              )}
                            </td>

                            <td className="mono">
                              {displayValue(
                                system?.name,
                              )}
                            </td>

                            <td className="mono">
                              {displayValue(
                                message.externalMessageId,
                              )}
                            </td>

                            <td>
                              <MessageStatusBadge
                                status={
                                  message.status
                                }
                              />
                            </td>

                            <td className="mono">
                              {formatDate(
                                message.createdAt,
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
        </div>
      )}

      {/* =====================================================================
          SYSTEMS TAB
          ===================================================================== */}

      {tab === 'systems' && (
        <div
          className="admin-panel"
          style={{ marginTop: 16 }}
        >
          <div className="admin-panel-head">
            <span className="admin-panel-title">
              System Registry
            </span>

            <span className="admin-panel-sub">
              {systems.length} interoperability systems
            </span>
          </div>

          {systems.length === 0 ? (
            <div className="admin-empty">
              No systems registered.
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>System</th>
                    <th>Code</th>
                    <th>Endpoints</th>
                    <th>Connections</th>
                    <th>Healthy</th>
                    <th>Errors</th>
                  </tr>
                </thead>

                <tbody>
                  {systems
                    .filter((system) => {
                      if (!normalizedSearch) {
                        return true;
                      }

                      return [
                        system.name,
                        system.code,
                        system.id,
                      ]
                        .map(safeLower)
                        .join(' ')
                        .includes(
                          normalizedSearch,
                        );
                    })
                    .map((system) => {
                      const health =
                        systemHealth(system.id);

                      return (
                        <tr
                          key={system.id}
                          className="admin-row-click"
                          onClick={() =>
                            openSystem(
                              system.id,
                            )
                          }
                        >
                          <td>
                            <strong>
                              {displayValue(
                                system.name,
                              )}
                            </strong>
                          </td>

                          <td className="mono">
                            {displayValue(
                              system.code,
                            )}
                          </td>

                          <td className="num">
                            {health.endpoints}
                          </td>

                          <td className="num">
                            {health.connections}
                          </td>

                          <td className="num">
                            {health.connected}
                          </td>

                          <td className="num">
                            {health.errors}
                          </td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* =====================================================================
          CONNECTIONS TAB
          ===================================================================== */}

      {tab === 'connections' && (
        <div
          className="admin-panel"
          style={{ marginTop: 16 }}
        >
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">
                Connection Registry
              </span>

              <span
                className="admin-panel-sub"
                style={{
                  display: 'block',
                  marginTop: 4,
                }}
              >
                live connection state and endpoint
                correlation
              </span>
            </div>

            <div
              className="admin-filters"
              style={{
                margin: 0,
              }}
            >
              <select
                className="admin-input"
                value={integrationFilter}
                onChange={(event) =>
                  setIntegrationFilter(
                    event.target.value as IntegrationFilter,
                  )
                }
                aria-label="Connection status filter"
              >
                <option value="all">
                  all
                </option>
                <option value="healthy">
                  healthy
                </option>
                <option value="degraded">
                  degraded
                </option>
                <option value="error">
                  error
                </option>
                <option value="disconnected">
                  disconnected
                </option>
              </select>
            </div>
          </div>

          <div
            className="admin-filters"
            style={{
              marginTop: 12,
            }}
          >
            <input
              type="search"
              className="admin-filter-input"
              placeholder="Search systems, endpoints, errors…"
              value={search}
              onChange={(event) =>
                setSearch(event.target.value)
              }
              aria-label="Search integrations"
            />

            <button
              type="button"
              className="admin-page-btn"
              onClick={() => {
                setSearch('');
                setIntegrationFilter('all');
              }}
            >
              Clear
            </button>
          </div>

          {sortedConnections.length === 0 ? (
            <div className="admin-empty">
              No connections match the current filters.
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort('system')
                        }
                        className="admin-table-sort"
                      >
                        System
                        <SortIndicator
                          active={
                            sort.field ===
                            'system'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>

                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort('endpoint')
                        }
                        className="admin-table-sort"
                      >
                        Endpoint
                        <SortIndicator
                          active={
                            sort.field ===
                            'endpoint'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>

                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort('status')
                        }
                        className="admin-table-sort"
                      >
                        Status
                        <SortIndicator
                          active={
                            sort.field ===
                            'status'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>

                    <th>Last Error</th>

                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort('updated')
                        }
                        className="admin-table-sort"
                      >
                        Updated
                        <SortIndicator
                          active={
                            sort.field ===
                            'updated'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {sortedConnections.map(
                    (connection) => {
                      const endpoint =
                        connection.endpointId
                          ? endpointById.get(
                              connection.endpointId,
                            )
                          : undefined;

                      const system =
                        endpoint?.systemId
                          ? systemById.get(
                              endpoint.systemId,
                            )
                          : undefined;

                      return (
                        <tr
                          key={connection.id}
                          className="admin-row-click"
                          onClick={() =>
                            endpoint?.id &&
                            openEndpoint(
                              endpoint.id,
                            )
                          }
                        >
                          <td>
                            {displayValue(
                              system?.name,
                            )}
                          </td>

                          <td className="mono">
                            {displayValue(
                              endpoint?.name,
                            )}
                          </td>

                          <td>
                            <StatusBadge
                              status={
                                connection.status
                              }
                            />
                          </td>

                          <td>
                            {connection.lastError ? (
                              <span
                                title={
                                  connection.lastError
                                }
                              >
                                {connection.lastError
                                  .length > 120
                                  ? `${connection.lastError.slice(
                                      0,
                                      120,
                                    )}…`
                                  : connection.lastError}
                              </span>
                            ) : (
                              '—'
                            )}
                          </td>

                          <td className="mono">
                            {formatDate(
                              connection.updatedAt,
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
      )}

      {/* =====================================================================
          MESSAGES TAB
          ===================================================================== */}

      {tab === 'messages' && (
        <div
          className="admin-panel"
          style={{ marginTop: 16 }}
        >
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">
                Interoperability Messages
              </span>

              <span
                className="admin-panel-sub"
                style={{
                  display: 'block',
                  marginTop: 4,
                }}
              >
                inbound/outbound messages observed by
                the Control Plane
              </span>
            </div>

            <div className="admin-filters">
              <select
                className="admin-input"
                value={messageFilter}
                onChange={(event) =>
                  setMessageFilter(
                    event.target.value as MessageFilter,
                  )
                }
                aria-label="Message filter"
              >
                <option value="all">
                  all messages
                </option>
                <option value="inbound">
                  inbound
                </option>
                <option value="outbound">
                  outbound
                </option>
                <option value="success">
                  successful
                </option>
                <option value="pending">
                  pending
                </option>
                <option value="failed">
                  failed
                </option>
              </select>
            </div>
          </div>

          <div
            className="admin-filters"
            style={{
              marginTop: 12,
            }}
          >
            <input
              type="search"
              className="admin-filter-input"
              placeholder="Search message type, system, external ID…"
              value={search}
              onChange={(event) =>
                setSearch(event.target.value)
              }
              aria-label="Search messages"
            />

            <button
              type="button"
              className="admin-page-btn"
              onClick={() => {
                setSearch('');
                setMessageFilter('all');
              }}
            >
              Clear
            </button>
          </div>

          <div
            className="admin-kv"
            style={{
              marginTop: 16,
              marginBottom: 16,
            }}
          >
            <span className="k">
              Displayed
            </span>

            <span className="v num">
              {sortedMessages.length}
            </span>

            <span className="k">
              Inbound
            </span>

            <span className="v num">
              {inboundMessages.length}
            </span>

            <span className="k">
              Outbound
            </span>

            <span className="v num">
              {outboundMessages.length}
            </span>

            <span className="k">
              Failed
            </span>

            <span className="v num">
              {failedMessages.length}
            </span>

            <span className="k">
              Pending
            </span>

            <span className="v num">
              {pendingMessages.length}
            </span>
          </div>

          {sortedMessages.length === 0 ? (
            <div className="admin-empty">
              No interoperability messages match the
              current filters.
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort('direction')
                        }
                        className="admin-table-sort"
                      >
                        Direction
                        <SortIndicator
                          active={
                            sort.field ===
                            'direction'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>

                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort(
                            'messageType',
                          )
                        }
                        className="admin-table-sort"
                      >
                        Type
                        <SortIndicator
                          active={
                            sort.field ===
                            'messageType'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>

                    <th>System</th>
                    <th>Endpoint</th>
                    <th>External ID</th>
                    <th>Status</th>

                    <th>
                      <button
                        type="button"
                        onClick={() =>
                          handleSort('created')
                        }
                        className="admin-table-sort"
                      >
                        Created
                        <SortIndicator
                          active={
                            sort.field ===
                            'created'
                          }
                          direction={
                            sort.direction
                          }
                        />
                      </button>
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {sortedMessages.map(
                    (message) => {
                      const system =
                        message.systemId
                          ? systemById.get(
                              message.systemId,
                            )
                          : undefined;

                      const endpoint =
                        message.endpointId
                          ? endpointById.get(
                              message.endpointId,
                            )
                          : undefined;

                      return (
                        <tr key={message.id}>
                          <td>
                            <DirectionBadge
                              direction={
                                message.direction
                              }
                            />
                          </td>

                          <td className="mono">
                            {displayValue(
                              message.messageType,
                            )}
                          </td>

                          <td>
                            {displayValue(
                              system?.name,
                            )}
                          </td>

                          <td className="mono">
                            {displayValue(
                              endpoint?.name,
                            )}
                          </td>

                          <td className="mono">
                            {displayValue(
                              message.externalMessageId,
                            )}
                          </td>

                          <td>
                            <MessageStatusBadge
                              status={
                                message.status
                              }
                            />
                          </td>

                          <td className="mono">
                            {formatDate(
                              message.createdAt,
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
      )}

      {/* =====================================================================
          MESSAGE STATISTICS
          ===================================================================== */}

      {tab === 'messages' &&
        messageStats.length > 0 && (
          <div
            className="admin-panel"
            style={{
              marginTop: 16,
            }}
          >
            <div className="admin-panel-head">
              <span className="admin-panel-title">
                Message Statistics
              </span>

              <span className="admin-panel-sub">
                direction × status
              </span>
            </div>

            <div className="admin-table-wrap">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Direction</th>
                    <th>Status</th>
                    <th>Count</th>
                  </tr>
                </thead>

                <tbody>
                  {messageStats.map(
                    (stat, index) => (
                      <tr
                        key={`${stat.direction}-${stat.status}-${index}`}
                      >
                        <td>
                          <DirectionBadge
                            direction={
                              stat.direction
                            }
                          />
                        </td>

                        <td>
                          <MessageStatusBadge
                            status={stat.status}
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
          </div>
        )}

      {/* =====================================================================
          SYSTEM DRAWER
          ===================================================================== */}

      {selectedSystem && (
        <div
          className="admin-drawer-backdrop"
          onClick={closeSystem}
        >
          <div
            className="admin-drawer"
            role="dialog"
            aria-modal="true"
            aria-label="Integration system detail"
            onClick={(event) =>
              event.stopPropagation()
            }
          >
            <div className="admin-drawer-head">
              <div>
                <span className="admin-drawer-title">
                  {displayValue(
                    selectedSystem.name,
                  )}
                </span>

                <span
                  className="muted small mono"
                  style={{
                    display: 'block',
                    marginTop: 3,
                  }}
                >
                  {displayValue(
                    selectedSystem.code,
                  )}
                </span>
              </div>

              <button
                type="button"
                className="admin-drawer-close"
                onClick={closeSystem}
                aria-label="Close system detail"
              >
                ✕
              </button>
            </div>

            <div className="admin-drawer-body">
              <div className="admin-kv">
                <span className="k">
                  System ID
                </span>

                <span className="v mono">
                  {selectedSystem.id}
                </span>

                <span className="k">
                  Endpoints
                </span>

                <span className="v num">
                  {selectedSystemEndpoints.length}
                </span>

                <span className="k">
                  Connections
                </span>

                <span className="v num">
                  {selectedSystemConnections.length}
                </span>

                <span className="k">
                  Healthy
                </span>

                <span className="v num">
                  {
                    selectedSystemConnections.filter(
                      (connection) =>
                        isConnectionHealthy(
                          connection.status,
                        ),
                    ).length
                  }
                </span>

                <span className="k">
                  Errors
                </span>

                <span className="v num">
                  {
                    selectedSystemConnections.filter(
                      (connection) =>
                        isConnectionError(
                          connection.status,
                        ),
                    ).length
                  }
                </span>
              </div>

              <h4
                style={{
                  margin: '20px 0 8px',
                  fontSize: '0.85rem',
                }}
              >
                Endpoints
              </h4>

              {selectedSystemEndpoints.length ===
              0 ? (
                <div className="admin-empty">
                  No endpoints registered for this
                  system.
                </div>
              ) : (
                <div className="admin-table-wrap">
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>Name</th>
                        <th>Auth</th>
                        <th>Active</th>
                        <th>Connections</th>
                      </tr>
                    </thead>

                    <tbody>
                      {selectedSystemEndpoints.map(
                        (endpoint) => {
                          const endpointConnections =
                            connectionsByEndpoint.get(
                              endpoint.id,
                            ) ?? [];

                          return (
                            <tr
                              key={endpoint.id}
                              className="admin-row-click"
                              onClick={() =>
                                openEndpoint(
                                  endpoint.id,
                                )
                              }
                            >
                              <td>
                                {displayValue(
                                  endpoint.name,
                                )}
                              </td>

                              <td className="mono">
                                {displayValue(
                                  endpoint.authType,
                                )}
                              </td>

                              <td>
                                {endpoint.isActive
                                  ? 'yes'
                                  : 'no'}
                              </td>

                              <td className="num">
                                {
                                  endpointConnections.length
                                }
                              </td>
                            </tr>
                          );
                        },
                      )}
                    </tbody>
                  </table>
                </div>
              )}

              <h4
                style={{
                  margin: '20px 0 8px',
                  fontSize: '0.85rem',
                }}
              >
                Connections
              </h4>

              {selectedSystemConnections.length ===
              0 ? (
                <div className="admin-empty">
                  No connection records.
                </div>
              ) : (
                <div className="admin-table-wrap">
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>Endpoint</th>
                        <th>Status</th>
                        <th>Updated</th>
                      </tr>
                    </thead>

                    <tbody>
                      {selectedSystemConnections.map(
                        (connection) => {
                          const endpoint =
                            connection.endpointId
                              ? endpointById.get(
                                  connection.endpointId,
                                )
                              : undefined;

                          return (
                            <tr
                              key={connection.id}
                            >
                              <td className="mono">
                                {displayValue(
                                  endpoint?.name,
                                )}
                              </td>

                              <td>
                                <StatusBadge
                                  status={
                                    connection.status
                                  }
                                />
                              </td>

                              <td className="mono">
                                {formatDate(
                                  connection.updatedAt,
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
        </div>
      )}

      {/* =====================================================================
          ENDPOINT DRAWER
          ===================================================================== */}

      {selectedEndpoint && (
        <div
          className="admin-drawer-backdrop"
          onClick={closeEndpoint}
        >
          <div
            className="admin-drawer"
            role="dialog"
            aria-modal="true"
            aria-label="Integration endpoint detail"
            onClick={(event) =>
              event.stopPropagation()
            }
          >
            <div className="admin-drawer-head">
              <div>
                <span className="admin-drawer-title">
                  {displayValue(
                    selectedEndpoint.name,
                  )}
                </span>

                <span
                  className="muted small mono"
                  style={{
                    display: 'block',
                    marginTop: 3,
                  }}
                >
                  {displayValue(
                    selectedEndpoint.id,
                  )}
                </span>
              </div>

              <button
                type="button"
                className="admin-drawer-close"
                onClick={closeEndpoint}
                aria-label="Close endpoint detail"
              >
                ✕
              </button>
            </div>

            <div className="admin-drawer-body">
              <div className="admin-kv">
                <span className="k">
                  System
                </span>

                <span className="v">
                  {displayValue(
                    selectedEndpoint.systemId
                      ? systemById.get(
                          selectedEndpoint.systemId,
                        )?.name
                      : undefined,
                  )}
                </span>

                <span className="k">
                  Authentication
                </span>

                <span className="v mono">
                  {displayValue(
                    selectedEndpoint.authType,
                  )}
                </span>

                <span className="k">
                  Active
                </span>

                <span className="v">
                  {selectedEndpoint.isActive
                    ? 'yes'
                    : 'no'}
                </span>

                <span className="k">
                  Endpoint ID
                </span>

                <span className="v mono">
                  {selectedEndpoint.id}
                </span>
              </div>

              <div
                className="admin-panel"
                style={{
                  marginTop: 16,
                }}
              >
                <div className="admin-panel-head">
                  <span className="admin-panel-title">
                    Connections
                  </span>

                  <span className="admin-panel-sub">
                    {selectedEndpointConnections.length}
                  </span>
                </div>

                {selectedEndpointConnections.length ===
                0 ? (
                  <div className="admin-empty">
                    No connection records for this
                    endpoint.
                  </div>
                ) : (
                  <div className="admin-table-wrap">
                    <table className="admin-table">
                      <thead>
                        <tr>
                          <th>Connection</th>
                          <th>Status</th>
                          <th>Last Error</th>
                          <th>Updated</th>
                        </tr>
                      </thead>

                      <tbody>
                        {selectedEndpointConnections.map(
                          (connection) => (
                            <tr
                              key={connection.id}
                            >
                              <td className="mono">
                                {shortId(
                                  connection.id,
                                  12,
                                )}
                              </td>

                              <td>
                                <StatusBadge
                                  status={
                                    connection.status
                                  }
                                />
                              </td>

                              <td>
                                {displayValue(
                                  connection.lastError,
                                )}
                              </td>

                              <td className="mono">
                                {formatDate(
                                  connection.updatedAt,
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
                style={{
                  marginTop: 16,
                }}
              >
                <div className="admin-panel-head">
                  <span className="admin-panel-title">
                    Integration Boundary
                  </span>
                </div>

                <div className="admin-kv">
                  <span className="k">
                    Endpoint
                  </span>

                  <span className="v mono">
                    {selectedEndpoint.id}
                  </span>

                  <span className="k">
                    System
                  </span>

                  <span className="v mono">
                    {displayValue(
                      selectedEndpoint.systemId,
                    )}
                  </span>

                  <span className="k">
                    Authentication
                  </span>

                  <span className="v mono">
                    {displayValue(
                      selectedEndpoint.authType,
                    )}
                  </span>

                  <span className="k">
                    Operational
                  </span>

                  <span className="v">
                    {selectedEndpoint.isActive
                      ? 'enabled'
                      : 'disabled'}
                  </span>
                </div>
              </div>

              <div
                className="muted small"
                style={{
                  marginTop: 16,
                  lineHeight: 1.5,
                }}
              >
                Endpoint credentials, secrets, tokens,
                private keys and connection secrets are
                intentionally not rendered by the
                administration workspace.
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}