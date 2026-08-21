// =============================================================================
// AMEXAN Admin Workspace — Control Plane API Client
//
// ARCHITECTURE
// -----------------------------------------------------------------------------
// This client communicates ONLY with the AMEXAN Control Plane API.
//
// It MUST NOT:
//   - connect directly to PostgreSQL
//   - connect directly to Firestore
//   - query any database from the browser
//   - contain database credentials
//   - expose service credentials
//   - bypass the Control Plane authorization layer
//
// Development:
//   /api/control-plane/*
//        -> Vite proxy
//        -> AMEXAN Clinical Runtime / Control Plane API
//
// Production:
//   /api/control-plane/*
//        -> runtime/API gateway
//        -> read-only /admin/*
//        -> /observatory
//        -> /journey/*
//
// DESIGN PRINCIPLES
// -----------------------------------------------------------------------------
// 1. Browser is a read-only Control Plane client.
// 2. Every request is authenticated by the server-side session/cookie.
// 3. Every request disables browser caching.
// 4. Every response is validated at the transport boundary.
// 5. Request IDs are preserved for operational investigation.
// 6. Errors are normalized into ControlPlaneError.
// 7. Query parameters are encoded centrally.
// 8. IDs are always URL encoded.
// 9. No endpoint silently falls back to another data source.
// 10. No secrets are accepted from the frontend.
// 11. Requests have a timeout so a dead runtime cannot hang the UI forever.
// 12. AbortController is supported for safe page/component cancellation.
// =============================================================================

import type {
  AdminSummary,
  AnalyticsOverview,
  AssetEntry,
  AssetIntelligenceOverview,
  AuditResponse,
  ConfigurationDetail,
  ConfigurationResponse,
  DatabaseOverview,
  EngineDetail,
  EnginesResponse,
  EventDetail,
  EventSelection,
  EventsResponse,
  FeatureFlagsResponse,
  HealthResponse,
  IncidentDetail,
  IncidentsResponse,
  IntegrationsOverview,
  JourneyEvent,
  JobsResponse,
  NotificationsOverview,
  ObservatorySummary,
  RuntimeOverview,
  SecurityOverview,
  ServiceCatalogueOverview,
  SystemVersionsResponse,
  WorkflowOverview,
} from './types';

// =============================================================================
// BASE CONFIGURATION
// =============================================================================

const CONTROL_PLANE_BASE =
  (import.meta.env.VITE_AMEXAN_CONTROL_PLANE_URL as string | undefined) ??
  '/api/control-plane';

const CONTROL_PLANE_TIMEOUT_MS = 15_000;

// =============================================================================
// ERROR MODEL
// =============================================================================

export class ControlPlaneError extends Error {
  readonly status: number;
  readonly requestId?: string;
  readonly code?: string;
  readonly details?: unknown;

  constructor(
    message: string,
    status: number,
    requestId?: string,
    code?: string,
    details?: unknown,
  ) {
    super(message);

    this.name = 'ControlPlaneError';

    this.status = status;
    this.requestId = requestId;
    this.code = code;
    this.details = details;

    Object.setPrototypeOf(this, ControlPlaneError.prototype);
  }
}

// =============================================================================
// REQUEST OPTIONS
// =============================================================================

export interface ControlPlaneRequestOptions extends RequestInit {
  /**
   * Optional timeout override.
   * Defaults to CONTROL_PLANE_TIMEOUT_MS.
   */
  timeoutMs?: number;
}

// =============================================================================
// RESPONSE ERROR HELPERS
// =============================================================================

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function extractErrorMessage(payload: unknown, status: number): string {
  if (isRecord(payload)) {
    if (
      typeof payload.message === 'string' &&
      payload.message.trim().length > 0
    ) {
      return payload.message;
    }

    if (
      typeof payload.error === 'string' &&
      payload.error.trim().length > 0
    ) {
      return payload.error;
    }
  }

  return `Control Plane request failed (${status})`;
}

function extractErrorCode(payload: unknown): string | undefined {
  if (!isRecord(payload)) {
    return undefined;
  }

  if (typeof payload.code === 'string' && payload.code.trim()) {
    return payload.code;
  }

  return undefined;
}

function extractErrorDetails(payload: unknown): unknown {
  if (!isRecord(payload)) {
    return undefined;
  }

  return payload.details;
}

// =============================================================================
// RESPONSE PARSING
// =============================================================================

async function parseResponsePayload(
  response: Response,
): Promise<unknown> {
  const contentType =
    response.headers.get('content-type')?.toLowerCase() ?? '';

  /*
   * A successful 204 response has no body.
   */
  if (response.status === 204) {
    return null;
  }

  /*
   * Prefer JSON when the server declares JSON.
   */
  if (contentType.includes('application/json')) {
    try {
      return await response.json();
    } catch {
      return null;
    }
  }

  /*
   * Some development proxies/API gateways occasionally omit the
   * content-type header. Try JSON anyway, then safely fall back to text.
   */
  try {
    const text = await response.text();

    if (!text) {
      return null;
    }

    try {
      return JSON.parse(text) as unknown;
    } catch {
      return text;
    }
  } catch {
    return null;
  }
}

// =============================================================================
// URL NORMALISATION
// =============================================================================

function normaliseBaseUrl(base: string): string {
  const trimmed = base.trim();

  if (!trimmed) {
    return '/api/control-plane';
  }

  return trimmed.endsWith('/')
    ? trimmed.slice(0, -1)
    : trimmed;
}

const NORMALISED_CONTROL_PLANE_BASE =
  normaliseBaseUrl(CONTROL_PLANE_BASE);

// =============================================================================
// QUERY BUILDER
// =============================================================================

function toQuery(
  params: object = {},
): string {
  const search = new URLSearchParams();

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null) {
      continue;
    }

    if (typeof value === 'string' && value.trim() === '') {
      continue;
    }

    search.set(key, String(value));
  }

  const query = search.toString();

  return query ? `?${query}` : '';
}

// =============================================================================
// CORE CONTROL PLANE FETCH
// =============================================================================

export async function controlPlaneFetch<T>(
  path: string,
  init: ControlPlaneRequestOptions = {},
): Promise<T> {
  const {
    timeoutMs = CONTROL_PLANE_TIMEOUT_MS,
    signal: callerSignal,
    headers: callerHeaders,
    ...requestInit
  } = init;

  const controller = new AbortController();

  let timedOut = false;

  const timeout = window.setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);

  /*
   * If the caller supplied its own AbortSignal, propagate cancellation
   * into the internal controller used by this request.
   */
  let removeCallerAbortListener: (() => void) | undefined;

  if (callerSignal) {
    if (callerSignal.aborted) {
      controller.abort();
    } else {
      const handleCallerAbort = () => {
        controller.abort();
      };

      callerSignal.addEventListener(
        'abort',
        handleCallerAbort,
        { once: true },
      );

      removeCallerAbortListener = () => {
        callerSignal.removeEventListener(
          'abort',
          handleCallerAbort,
        );
      };
    }
  }

  const headers = new Headers(callerHeaders);

  if (!headers.has('Accept')) {
    headers.set('Accept', 'application/json');
  }

  /*
   * This client is intentionally read-only.
   *
   * GET is used by every public method below. We do not send an
   * Authorization token from frontend configuration. Authentication
   * remains controlled by the server-side session/cookie layer.
   */
  let response: Response;

  try {
    response = await fetch(
      `${NORMALISED_CONTROL_PLANE_BASE}${path}`,
      {
        ...requestInit,
        method: requestInit.method ?? 'GET',
        credentials: 'include',
        headers,
        signal: controller.signal,

        /*
         * Prevent stale administrative/control-plane observations.
         */
        cache: 'no-store',
      },
    );
  } catch (error) {
    if (timedOut) {
      throw new ControlPlaneError(
        `Control Plane request timed out after ${timeoutMs}ms`,
        408,
      );
    }

    if (
      error instanceof DOMException &&
      error.name === 'AbortError'
    ) {
      throw error;
    }

    if (error instanceof Error) {
      throw new ControlPlaneError(
        `Unable to reach the AMEXAN Control Plane: ${error.message}`,
        0,
      );
    }

    throw new ControlPlaneError(
      'Unable to reach the AMEXAN Control Plane',
      0,
    );
  } finally {
    window.clearTimeout(timeout);
    removeCallerAbortListener?.();
  }

  const requestId =
    response.headers.get('x-request-id') ??
    response.headers.get('x-correlation-id') ??
    undefined;

  const payload = await parseResponsePayload(response);

  if (!response.ok) {
    const message = extractErrorMessage(
      payload,
      response.status,
    );

    const code = extractErrorCode(payload);

    const details = extractErrorDetails(payload);

    throw new ControlPlaneError(
      message,
      response.status,
      requestId,
      code,
      details,
    );
  }

  /*
   * A successful empty response is permitted for endpoints that
   * legitimately return no body.
   */
  return payload as T;
}

// =============================================================================
// INTERNAL SAFE GET
// =============================================================================

function get<T>(
  path: string,
  signal?: AbortSignal,
): Promise<T> {
  return controlPlaneFetch<T>(
    path,
    signal ? { signal } : undefined,
  );
}

// =============================================================================
// SUMMARY
// =============================================================================

export function getAdminSummary(
  signal?: AbortSignal,
): Promise<AdminSummary> {
  return get<AdminSummary>(
    '/admin/summary',
    signal,
  );
}

// =============================================================================
// EVENTS
// =============================================================================

export interface EventFilters {
  eventType?: string;
  sourceType?: string;
  patientId?: string;
  encounterId?: string;
  status?: string;
  limit?: number;
  offset?: number;
}

export function getEvents(
  filters: EventFilters = {},
  signal?: AbortSignal,
): Promise<EventsResponse> {
  return get<EventsResponse>(
    `/admin/events${toQuery(filters)}`,
    signal,
  );
}

export function getEvent(
  selection: EventSelection,
  signal?: AbortSignal,
): Promise<EventDetail> {
  const eventId = encodeURIComponent(
    selection.eventId,
  );

  const params = new URLSearchParams();

  params.set(
    'eventId',
    selection.eventId,
  );

  if (selection.encounterId) {
    params.set(
      'encounterId',
      selection.encounterId,
    );
  }

  if (selection.correlationId) {
    params.set(
      'correlationId',
      selection.correlationId,
    );
  }

  return get<EventDetail>(
    `/events/${eventId}?${params.toString()}`,
    signal,
  );
}

// =============================================================================
// ENGINES
// =============================================================================

export function getEngines(
  signal?: AbortSignal,
): Promise<EnginesResponse> {
  return get<EnginesResponse>(
    '/admin/engines',
    signal,
  );
}

export function getEngineDetail(
  code: string,
  signal?: AbortSignal,
): Promise<EngineDetail> {
  return get<EngineDetail>(
    `/admin/engines/${encodeURIComponent(code)}`,
    signal,
  );
}

// =============================================================================
// HEALTH
// =============================================================================

export function getHealthChecks(
  signal?: AbortSignal,
): Promise<HealthResponse> {
  return get<HealthResponse>(
    '/admin/health',
    signal,
  );
}

// =============================================================================
// JOBS
// =============================================================================

export function getJobs(
  signal?: AbortSignal,
): Promise<JobsResponse> {
  return get<JobsResponse>(
    '/admin/jobs',
    signal,
  );
}

// =============================================================================
// FEATURE FLAGS
// =============================================================================

export function getFeatureFlags(
  signal?: AbortSignal,
): Promise<FeatureFlagsResponse> {
  return get<FeatureFlagsResponse>(
    '/admin/feature-flags',
    signal,
  );
}

// =============================================================================
// CONFIGURATION
// =============================================================================

export function getConfiguration(
  signal?: AbortSignal,
): Promise<ConfigurationResponse> {
  return get<ConfigurationResponse>(
    '/admin/config',
    signal,
  );
}

export function getConfigurationDetail(
  key: string,
  signal?: AbortSignal,
): Promise<ConfigurationDetail> {
  return get<ConfigurationDetail>(
    `/admin/config/${encodeURIComponent(key)}`,
    signal,
  );
}

// =============================================================================
// SYSTEM VERSIONS
// =============================================================================

export function getSystemVersions(
  signal?: AbortSignal,
): Promise<SystemVersionsResponse> {
  return get<SystemVersionsResponse>(
    '/admin/versions',
    signal,
  );
}

// =============================================================================
// AUDIT
// =============================================================================

export interface AuditFilters {
  eventType?: string;
  actorType?: string;
  entityType?: string;
  encounterId?: string;
  limit?: number;
  offset?: number;
}

export function getAuditEvents(
  filters: AuditFilters = {},
  signal?: AbortSignal,
): Promise<AuditResponse> {
  return get<AuditResponse>(
    `/admin/audit${toQuery(filters)}`,
    signal,
  );
}

// =============================================================================
// SECURITY / RBAC
// =============================================================================

export function getSecurityOverview(
  signal?: AbortSignal,
): Promise<SecurityOverview> {
  return get<SecurityOverview>(
    '/admin/security',
    signal,
  );
}

// =============================================================================
// OBSERVATORY
// =============================================================================

export function getObservatory(
  signal?: AbortSignal,
): Promise<ObservatorySummary> {
  return get<ObservatorySummary>(
    '/observatory',
    signal,
  );
}

// =============================================================================
// ENCOUNTER JOURNEY
// =============================================================================

export function getJourneyEncounter(
  encounterId: string,
  signal?: AbortSignal,
): Promise<JourneyEvent[]> {
  return get<JourneyEvent[]>(
    `/journey/encounter/${encodeURIComponent(encounterId)}`,
    signal,
  );
}

// =============================================================================
// DATABASE (§61)
// =============================================================================

export function getDatabaseOverview(
  signal?: AbortSignal,
): Promise<DatabaseOverview> {
  return get<DatabaseOverview>(
    '/admin/database',
    signal,
  );
}

// =============================================================================
// RUNTIME
// =============================================================================

export function getRuntimeOverview(
  signal?: AbortSignal,
): Promise<RuntimeOverview> {
  return get<RuntimeOverview>(
    '/admin/runtime',
    signal,
  );
}

// =============================================================================
// WORKFLOW
// =============================================================================

export function getWorkflowOverview(
  signal?: AbortSignal,
): Promise<WorkflowOverview> {
  return get<WorkflowOverview>(
    '/admin/workflow',
    signal,
  );
}

// =============================================================================
// INCIDENTS (§59)
// =============================================================================

export interface IncidentFilters {
  status?: string;
  severity?: string;
  limit?: number;
  offset?: number;
}

export function getIncidents(
  filters: IncidentFilters = {},
  signal?: AbortSignal,
): Promise<IncidentsResponse> {
  return get<IncidentsResponse>(
    `/admin/incidents${toQuery(filters)}`,
    signal,
  );
}

export function getIncidentDetail(
  id: string,
  signal?: AbortSignal,
): Promise<IncidentDetail> {
  return get<IncidentDetail>(
    `/admin/incidents/${encodeURIComponent(id)}`,
    signal,
  );
}

// =============================================================================
// INTEGRATIONS
// =============================================================================

export function getIntegrationsOverview(
  signal?: AbortSignal,
): Promise<IntegrationsOverview> {
  return get<IntegrationsOverview>(
    '/admin/integrations',
    signal,
  );
}

// =============================================================================
// NOTIFICATIONS
// =============================================================================

export function getNotificationsOverview(
  signal?: AbortSignal,
): Promise<NotificationsOverview> {
  return get<NotificationsOverview>(
    '/admin/notifications',
    signal,
  );
}

// =============================================================================
// ANALYTICS — PHASE G
// =============================================================================

export function getAnalyticsOverview(
  signal?: AbortSignal,
): Promise<AnalyticsOverview> {
  return get<AnalyticsOverview>(
    '/admin/analytics',
    signal,
  );
}

// =============================================================================
// SERVICE CATALOGUE
// =============================================================================

export function getServiceCatalogue(
  signal?: AbortSignal,
): Promise<ServiceCatalogueOverview> {
  return get<ServiceCatalogueOverview>(
    '/admin/catalogues',
    signal,
  );
}

export function getServiceCatalogueEntry(
  code: string,
  signal?: AbortSignal,
): Promise<ServiceCatalogueOverview['services'][number]> {
  return get<ServiceCatalogueOverview['services'][number]>(
    `/admin/catalogues/${encodeURIComponent(code)}`,
    signal,
  );
}

// =============================================================================
// ASSET INTELLIGENCE
// =============================================================================

export function getAssetIntelligence(
  signal?: AbortSignal,
): Promise<AssetIntelligenceOverview> {
  return get<AssetIntelligenceOverview>(
    '/admin/assets',
    signal,
  );
}

export function getAssetIntelligenceEntry(
  code: string,
  signal?: AbortSignal,
): Promise<AssetEntry> {
  return get<AssetEntry>(
    `/admin/assets/${encodeURIComponent(code)}`,
    signal,
  );
}

// =============================================================================
// REALTIME CONTROL-PLANE SUPPORT
//
// These helpers do not create a second transport layer and do not access
// databases. They simply provide a safe way for realtime/polling views to
// cancel obsolete requests when filters, routes, or components change.
// =============================================================================

export interface ControlPlaneRealtimeOptions {
  signal?: AbortSignal;
  timeoutMs?: number;
}

/**
 * Generic GET helper for future read-only Control Plane projections.
 *
 * Keep endpoint construction server-owned. Do not use this helper to access
 * database URLs or arbitrary external URLs.
 */
export function getControlPlaneProjection<T>(
  path: string,
  options: ControlPlaneRealtimeOptions = {},
): Promise<T> {
  return controlPlaneFetch<T>(
    path,
    {
      signal: options.signal,
      timeoutMs: options.timeoutMs,
    },
  );
}

// =============================================================================
// DEFAULT EXPORT
// =============================================================================

const controlPlaneApi = {
  getAdminSummary,

  getEvents,
  getEvent,

  getEngines,
  getEngineDetail,

  getHealthChecks,
  getJobs,
  getFeatureFlags,

  getConfiguration,
  getConfigurationDetail,

  getSystemVersions,

  getAuditEvents,

  getSecurityOverview,

  getObservatory,
  getJourneyEncounter,

  getDatabaseOverview,

  getRuntimeOverview,

  getWorkflowOverview,

  getIncidents,
  getIncidentDetail,

  getIntegrationsOverview,

  getNotificationsOverview,

  getAnalyticsOverview,

  getServiceCatalogue,
  getServiceCatalogueEntry,

  getAssetIntelligence,
  getAssetIntelligenceEntry,

  getControlPlaneProjection,
};

export default controlPlaneApi;