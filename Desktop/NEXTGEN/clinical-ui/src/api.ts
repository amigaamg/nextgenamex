// =============================================================================
// API client — the ONLY boundary the UI talks to (4.37). The UI posts events
// and subscribes to realtime projections; it never touches PostgreSQL or the CPU.
// =============================================================================

import type {
  ClinicalEvent,
  ClinicalEventType,
  ClinicalRuntimeProjection,
  TimelineEvent,
} from './types';

const BASE = '';

export interface DemoResult {
  patientId: string;
  encounterId: string;
  projection: ClinicalRuntimeProjection;
}

export interface TimelineResponse {
  entries: TimelineEvent[];
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'content-type': 'application/json' },
    ...init,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { error?: string }).error ?? `request failed (${res.status})`);
  }
  return (await res.json()) as T;
}

export async function startDemo(symptom = 'cough'): Promise<DemoResult> {
  return request('/clinical/demo', { method: 'POST', body: JSON.stringify({ symptom }) });
}

export async function sendEvent(
  patientId: string,
  encounterId: string | null,
  event: ClinicalEvent,
): Promise<ClinicalRuntimeProjection> {
  return request('/clinical/events', {
    method: 'POST',
    body: JSON.stringify({ patientId, encounterId, event }),
  });
}

export async function getTimeline(patientId: string): Promise<TimelineEvent[]> {
  const res = await fetch(`/clinical/timeline?patientId=${encodeURIComponent(patientId)}`);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as { error?: string }).error ?? `timeline failed (${res.status})`);
  }
  return (await res.json()) as TimelineEvent[];
}

// ---------------------------------------------------------------------------
// Event builders (payload contract is fixed by the CPU ingestion engines)
// ---------------------------------------------------------------------------

export function event(type: ClinicalEventType, payload: Record<string, unknown>): ClinicalEvent {
  return { type, payload };
}

export function questionAnswered(questionCode: string, answerCode: string): ClinicalEvent {
  return event('QUESTION_ANSWERED', { questionCode, answerCode });
}

export function questionSkipped(questionCode: string): ClinicalEvent {
  return event('QUESTION_SKIPPED', { questionCode });
}

// Lab/physiological result → the fact substrate (spec 4.20). A numeric value
// on e.g. SPO2, TEMPERATURE, RESP_RATE, CREATININE re-enters reasoning as a fact.
export function labResultReceived(factCode: string, value: number, unit?: string): ClinicalEvent {
  return event('LAB_RESULT_RECEIVED', { factCode, value, unit: unit ?? null });
}

// Imaging result → investigation + result code (e.g. INV-CXR → RLL_CONSOLIDATION),
// interpreted by the ResultInterpreter into examination-style facts (spec 4.20).
export function imagingResultReceived(investigationCode: string, results: string[]): ClinicalEvent {
  return event('IMAGING_RESULT_RECEIVED', { investigationCode, results });
}

export function examFindingCaptured(findingCode: string, value: unknown, unit?: string): ClinicalEvent {
  return event('EXAM_FINDING_CAPTURED', { findingCode, value, unit: unit ?? null });
}

export function clinicianDecision(input: {
  type: string;
  code: string;
  recommendation: string;
  reason?: string;
  status: 'accepted' | 'modified' | 'dismissed';
  decisionReason?: string;
}): ClinicalEvent {
  return event('CLINICIAN_DECISION', {
    type: input.type,
    code: input.code,
    recommendation: input.recommendation,
    reason: input.reason ?? null,
    status: input.status,
    decisionReason: input.decisionReason ?? null,
  });
}

// Server-Sent Events: every event lands as a new projection, on every screen.
export function subscribeProjection(
  patientId: string,
  onProjection: (p: ClinicalRuntimeProjection) => void,
  onError: (e: Event) => void,
): () => void {
  const source = new EventSource(`/events/stream?patientId=${encodeURIComponent(patientId)}`);
  source.onmessage = (message) => {
    try {
      onProjection(JSON.parse(message.data as string) as ClinicalRuntimeProjection);
    } catch {
      // ignore malformed frames
    }
  };
  source.onerror = onError;
  return () => source.close();
}