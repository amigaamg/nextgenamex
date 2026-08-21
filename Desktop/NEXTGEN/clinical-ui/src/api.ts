// =============================================================================
// AMEXAN Clinical Runtime UI — API Boundary
//
// ARCHITECTURE
// -----------------------------------------------------------------------------
// Clinical UI
//      │
//      │ HTTP / SSE only
//      ▼
// /api/clinical/*
//      │
//      ▼
// Clinical CPU
//      │
//      ▼
// PostgreSQL / clinical knowledge / rules / projections
//
// The UI NEVER:
// - reads PostgreSQL
// - evaluates clinical rules
// - selects clinical formats
// - decides which sections should exist
// - calculates differentials
// - calculates severity
// - decides pregnancy/age/department rules
//
// The CPU returns the authoritative projection.
// The UI renders that projection and emits clinician events.
// =============================================================================

import type {
  ClinicalEvent,
  ClinicalEventType,
  EnhancedClinicalRuntimeProjection,
  QuestionDisposition,
  TimelineEvent,
} from './types';

// =============================================================================
// API CONFIGURATION
// =============================================================================

const API_BASE = import.meta.env.VITE_API_BASE ?? '/api';

const ENDPOINTS = {
  encounters: '/clinical/encounters',
  events: '/clinical/events',
  timeline: '/clinical/timeline',
  stream: '/clinical/events/stream',
  exportPdf: '/clinical/export/pdf',
} as const;

// =============================================================================
// SAFETY ALERTS (AMEXAN Safety Sentinel surface)
// =============================================================================

export interface SafetyAlert {
  id: string;
  code: string;
  type: string;
  severity: string;
  title: string;
  message: string;
  acknowledged: boolean;
  createdAt: string;
}

export async function listEncounterAlerts(
  encounterId: string,
): Promise<SafetyAlert[]> {
  const response = await fetch(
    `${API_BASE}/clinical/encounters/${encodeURIComponent(encounterId)}/alerts`,
    { headers: { accept: 'application/json' } },
  );
  if (!response.ok) {
    throw new Error(
      `Failed to load safety alerts (${response.status})`,
    );
  }
  return (await response.json()) as SafetyAlert[];
}

export async function acknowledgeAlert(
  alertId: string,
  acknowledgedBy?: string | null,
): Promise<void> {
  const response = await fetch(
    `${API_BASE}/clinical/alerts/${encodeURIComponent(alertId)}/acknowledge`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ acknowledgedBy: acknowledgedBy ?? null }),
    },
  );
  if (!response.ok) {
    throw new Error(
      `Failed to acknowledge alert (${response.status})`,
    );
  }
}

// =============================================================================
// API TYPES
// =============================================================================

export interface EncounterSummary {
  encounterId: string;
  patientId: string;

  patientName: string;

  age: number | null;
  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  sex: string;

  department: string;
  encounterType?: string | null;

  presentingComplaint: string;

  startedAt: string;

  status:
    | 'in_progress'
    | 'completed'
    | 'reviewed';
}

export interface CreateEncounterContext {
  patientId?: string | null;

  sex:
    | 'male'
    | 'female'
    | 'intersex'
    | 'unknown';

  birthDate?: string | null;

  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  department:
    | 'medical'
    | 'surgical'
    | 'obgyn'
    | 'paediatrics'
    | 'neonatology'
    | 'psychiatry'
    | 'emergency'
    | 'other';

  encounterType:
    | 'opd'
    | 'emergency'
    | 'inpatient'
    | 'antenatal'
    | 'postnatal'
    | 'neonatal'
    | 'follow_up'
    | 'procedure'
    | 'other';

  pregnancyState:
    | 'not_applicable'
    | 'not_pregnant'
    | 'pregnant'
    | 'postpartum'
    | 'unknown';

  pregnant?: boolean;

  gestationalAge?: string | null;

  presentingComplaintCodes?: string[];

  activeSymptomCodes?: string[];
}

export interface CreateEncounterResult {
  patientId: string;
  encounterId: string;
  projection: EnhancedClinicalRuntimeProjection;
}

export interface TimelineResponse {
  entries: TimelineEvent[];
}

export interface ApiErrorResponse {
  error?: string;
  code?: string;
  message?: string;
  details?: unknown;
}

export interface ProjectionStreamMessage {
  type?:
    | 'projection'
    | 'heartbeat'
    | 'error'
    | 'complete';

  projection?: EnhancedClinicalRuntimeProjection;

  eventId?: number | null;

  error?: string;
}

// =============================================================================
// REQUEST HELPERS
// =============================================================================

function buildHeaders(init?: RequestInit): HeadersInit {
  const headers = new Headers(init?.headers);

  if (!headers.has('accept')) {
    headers.set('accept', 'application/json');
  }

  if (
    init?.body &&
    !headers.has('content-type')
  ) {
    headers.set('content-type', 'application/json');
  }

  return headers;
}

async function parseError(
  response: Response,
): Promise<string> {
  try {
    const body =
      (await response.json()) as ApiErrorResponse;

    return (
      body.error ??
      body.message ??
      `Request failed (${response.status})`
    );
  } catch {
    return `Request failed (${response.status})`;
  }
}

async function request<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(
    `${API_BASE}${path}`,
    {
      ...init,
      headers: buildHeaders(init),
      credentials: 'include',
    },
  );

  if (!response.ok) {
    throw new Error(
      await parseError(response),
    );
  }

  if (response.status === 204) {
    return undefined as T;
  }

  const contentType =
    response.headers.get('content-type') ?? '';

  if (!contentType.includes('application/json')) {
    throw new Error(
      'Expected JSON response from clinical API',
    );
  }

  return (await response.json()) as T;
}

// =============================================================================
// ENCOUNTERS
// =============================================================================

export async function listEncounters(
  signal?: AbortSignal,
): Promise<EncounterSummary[]> {
  return request<EncounterSummary[]>(
    ENDPOINTS.encounters,
    { signal },
  );
}

export async function createEncounter(
  context: CreateEncounterContext,
  signal?: AbortSignal,
): Promise<CreateEncounterResult> {
  return request<CreateEncounterResult>(
    ENDPOINTS.encounters,
    {
      method: 'POST',
      body: JSON.stringify({
        context,
      }),
      signal,
    },
  );
}

// =============================================================================
// EVENTS
// =============================================================================

export async function sendEvent(
  patientId: string,
  encounterId: string | null,
  clinicalEvent: ClinicalEvent,
  signal?: AbortSignal,
): Promise<EnhancedClinicalRuntimeProjection> {
  if (!patientId) {
    throw new Error(
      'Cannot send clinical event without patientId',
    );
  }

  return request<EnhancedClinicalRuntimeProjection>(
    ENDPOINTS.events,
    {
      method: 'POST',
      body: JSON.stringify({
        patientId,
        encounterId,
        event: clinicalEvent,
      }),
      signal,
    },
  );
}

// =============================================================================
// TIMELINE
// =============================================================================

export async function getTimeline(
  patientId: string,
  encounterId?: string | null,
  signal?: AbortSignal,
): Promise<TimelineEvent[]> {
  if (!patientId) {
    return [];
  }

  const params = new URLSearchParams();

  params.set('patientId', patientId);

  if (encounterId) {
    params.set('encounterId', encounterId);
  }

  const response = await request<
    TimelineEvent[] | TimelineResponse
  >(
    `${ENDPOINTS.timeline}?${params.toString()}`,
    { signal },
  );

  if (Array.isArray(response)) {
    return response;
  }

  return response.entries ?? [];
}

// =============================================================================
// DOCUMENTATION EXPORT
// =============================================================================

export async function exportDocumentation(
  patientId: string,
  encounterId: string,
  signal?: AbortSignal,
): Promise<Blob> {
  const params = new URLSearchParams({
    patientId,
    encounterId,
  });

  const response = await fetch(
    `${API_BASE}${ENDPOINTS.exportPdf}?${params.toString()}`,
    {
      method: 'GET',
      credentials: 'include',
      headers: {
        accept: 'application/pdf',
      },
      signal,
    },
  );

  if (!response.ok) {
    throw new Error(
      await parseError(response),
    );
  }

  return response.blob();
}

// =============================================================================
// EVENT BUILDER
// =============================================================================

export function event(
  type: ClinicalEventType,
  payload: Record<string, unknown>,
): ClinicalEvent {
  return {
    type,
    payload,
    timestamp: new Date().toISOString(),
  };
}

// =============================================================================
// HISTORY EVENTS
// =============================================================================

export function symptomPresented(
  symptomCode: string,
  label?: string,
): ClinicalEvent {
  return event(
    'SYMPTOM_PRESENTED',
    {
      symptomCode,
      label: label ?? null,
    },
  );
}

export function questionAnswered(
  questionCode: string,
  answerCodes: string[],
  rawValue?: string | number | boolean | null,
): ClinicalEvent {
  return event(
    'QUESTION_ANSWERED',
    {
      questionCode,
      answerCodes,
      rawValue:
        rawValue === undefined
          ? null
          : rawValue,
    },
  );
}

export function questionDispositioned(
  questionCode: string,
  disposition: QuestionDisposition,
): ClinicalEvent {
  return event(
    'QUESTION_DISPOSITIONED',
    {
      questionCode,
      disposition,
    },
  );
}

// =============================================================================
// EXAMINATION
// =============================================================================

export function examFindingCaptured(
  findingCode: string,
  value: unknown,
  unit?: string | null,
): ClinicalEvent {
  return event(
    'EXAM_FINDING_CAPTURED',
    {
      findingCode,
      value,
      unit: unit ?? null,
    },
  );
}

// =============================================================================
// INVESTIGATIONS
// =============================================================================

export function labResultReceived(
  factCode: string,
  value: number,
  unit?: string | null,
): ClinicalEvent {
  return event(
    'LAB_RESULT_RECEIVED',
    {
      factCode,
      value,
      unit: unit ?? null,
    },
  );
}

export function imagingResultReceived(
  investigationCode: string,
  results: string[],
): ClinicalEvent {
  return event(
    'IMAGING_RESULT_RECEIVED',
    {
      investigationCode,
      results,
    },
  );
}

// =============================================================================
// MANAGEMENT / CLINICIAN DECISION
// =============================================================================

export interface ClinicianDecisionInput {
  type: string;
  code: string;
  recommendation: string;

  reason?: string | null;

  status:
    | 'accepted'
    | 'modified'
    | 'dismissed';

  decisionReason?: string | null;
}

export function clinicianDecision(
  input: ClinicianDecisionInput,
): ClinicalEvent {
  return event(
    'CLINICIAN_DECISION',
    {
      type: input.type,
      code: input.code,
      recommendation:
        input.recommendation,
      reason: input.reason ?? null,
      status: input.status,
      decisionReason:
        input.decisionReason ?? null,
    },
  );
}

// =============================================================================
// VITALS
// =============================================================================

export function vitalChanged(
  vitalCode: string,
  value: number,
  unit?: string | null,
): ClinicalEvent {
  return event(
    'VITAL_CHANGED',
    {
      vitalCode,
      value,
      unit: unit ?? null,
    },
  );
}

// =============================================================================
// MEDICATION
// =============================================================================

export function medicationStarted(
  medicationCode: string,
  payload: Record<string, unknown> = {},
): ClinicalEvent {
  return event(
    'MEDICATION_STARTED',
    {
      medicationCode,
      ...payload,
    },
  );
}

// =============================================================================
// DOCUMENTATION
// =============================================================================

export function documentationAction(
  actionCode: string,
  payload: Record<string, unknown> = {},
): ClinicalEvent {
  return event(
    'DOCUMENTATION_ACTION',
    {
      actionCode,
      ...payload,
    },
  );
}

// =============================================================================
// REALTIME PROJECTION SUBSCRIPTION
//
// SSE is read-only from the UI perspective.
// CPU publishes projections.
// UI does not calculate or merge clinical state itself.
// =============================================================================

export interface ProjectionSubscription {
  close: () => void;
}

export function subscribeProjection(
  patientId: string,
  encounterId: string | null,
  onProjection: (
    projection: EnhancedClinicalRuntimeProjection,
  ) => void,
  onError: (error: Event | Error) => void,
): ProjectionSubscription {
  if (!patientId) {
    throw new Error(
      'Cannot subscribe without patientId',
    );
  }

  const params = new URLSearchParams();

  params.set('patientId', patientId);

  if (encounterId) {
    params.set(
      'encounterId',
      encounterId,
    );
  }

  const source = new EventSource(
    `${API_BASE}${ENDPOINTS.stream}?${params.toString()}`,
    {
      withCredentials: true,
    },
  );

  let closed = false;

  const handleProjection = (
    raw: string,
  ): void => {
    if (closed) return;

    try {
      const parsed = JSON.parse(
        raw,
      ) as
        | EnhancedClinicalRuntimeProjection
        | ProjectionStreamMessage;

      if (
        parsed &&
        typeof parsed === 'object' &&
        'projection' in parsed &&
        parsed.projection
      ) {
        onProjection(
          parsed.projection,
        );
        return;
      }

      onProjection(
        parsed as EnhancedClinicalRuntimeProjection,
      );
    } catch (error) {
      onError(
        error instanceof Error
          ? error
          : new Error(
              'Malformed projection received',
            ),
      );
    }
  };

  source.onmessage = (message) => {
    handleProjection(message.data);
  };

  source.addEventListener(
    'projection',
    (message) => {
      handleProjection(
        (message as MessageEvent).data,
      );
    },
  );

  source.addEventListener(
    'error',
    (message) => {
      if (!closed) {
        onError(
          message as Event,
        );
      }
    },
  );

  source.onerror = (error) => {
    if (!closed) {
      onError(error);
    }
  };

  return {
    close: () => {
      if (closed) return;

      closed = true;
      source.close();
    },
  };
}

// =============================================================================
// BACKWARD-COMPATIBLE SUBSCRIPTION
// =============================================================================

export function subscribeProjectionLegacy(
  patientId: string,
  onProjection: (
    projection: EnhancedClinicalRuntimeProjection,
  ) => void,
  onError: (error: Error | Event) => void,
): () => void {
  const subscription =
    subscribeProjection(
      patientId,
      null,
      onProjection,
      onError,
    );

  return subscription.close;
}

// =============================================================================
// HEALTH / CONNECTION
// =============================================================================

export interface ClinicalApiHealth {
  status: 'ok' | 'degraded' | 'down';
  cpu: 'connected' | 'disconnected';
  database: 'connected' | 'disconnected' | 'unknown';
  projectionStream:
    | 'available'
    | 'unavailable';
  timestamp?: string;
}

export async function getClinicalApiHealth(
  signal?: AbortSignal,
): Promise<ClinicalApiHealth> {
  return request<ClinicalApiHealth>(
    '/clinical/health',
    {
      signal,
      headers: {
        accept: 'application/json',
      },
    },
  );
}