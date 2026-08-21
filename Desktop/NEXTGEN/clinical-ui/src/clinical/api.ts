// =============================================================================
// src/clinical/api.ts
// AMEXAN Clinical UI → Clinical CPU API boundary
//
// UI responsibility:
//   - send context/events
//   - receive CPU projections
//
// CPU responsibility:
//   - determine clinical format
//   - determine age/life-stage rules
//   - determine sex/pregnancy rules
//   - determine sections/navigation
//   - determine questions
//   - determine clinical reasoning
//
// PostgreSQL is NEVER accessed directly from this file.
// =============================================================================

import type {
  ClinicalEvent,
  UniversalClinicalProjection,
} from './types';

const API_BASE = '/api';

const ENDPOINTS = {
  encounters: `${API_BASE}/clinical/encounters`,
  events: `${API_BASE}/clinical/events`,
} as const;

// =============================================================================
// TYPES
// =============================================================================

export type ClinicalSex =
  | 'male'
  | 'female'
  | 'intersex'
  | 'unknown';

export type PregnancyState =
  | 'not_applicable'
  | 'not_pregnant'
  | 'pregnant'
  | 'postpartum'
  | 'unknown';

export type ClinicalDepartment =
  | 'medical'
  | 'surgical'
  | 'obgyn'
  | 'paediatrics'
  | 'neonatology'
  | 'psychiatry'
  | 'emergency'
  | 'other';

export type EncounterType =
  | 'opd'
  | 'emergency'
  | 'inpatient'
  | 'antenatal'
  | 'postnatal'
  | 'neonatal'
  | 'follow_up'
  | 'procedure'
  | 'other';

export interface StartEncounterInput {
  patientId: string;

  encounterId?: string | null;

  // Patient identity / biodata (persisted by the server).
  name?: string | null;
  occupation?: string | null;

  // Preferred source of age truth.
  birthDate?: string | null;

  // CPU may receive explicit age values when already known.
  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  sex?: ClinicalSex;

  pregnancyState?: PregnancyState;

  // Convenience input from UI.
  pregnant?: boolean;

  gestationalAge?: string | null;

  department?: ClinicalDepartment;

  encounterType?: EncounterType;

  encounterTypeCode?: string;

  presentingComplaintCodes?: string[];

  activeSymptomCodes?: string[];

  firstVisit?: boolean;

  emergency?: boolean;
}

export interface StartEncounterResponse {
  projection: UniversalClinicalProjection;
}

export interface EncounterFactSnapshot {
  id: string;
  factCode: string;
  section: string;
  statusCode: string;
  sourceType: string;
  recordedAt: string;
  dataType: string;
  text: string | null;
  numeric: number | null;
  boolean: boolean | null;
  unitCode: string | null;
}

export interface EncounterSnapshot {
  patientId: string;
  encounterId: string;
  context: {
    sex: string;
    birthDate: string | null;
    department: string | null;
    encounterTypeCode: string | null;
    presentingComplaint: string | null;
  };
  facts: EncounterFactSnapshot[];
}

export interface CaptureClinicalEventInput {
  patientId: string;
  encounterId: string;
  event: ClinicalEvent;
}

export interface ApiError {
  error?: string;
  message?: string;
  code?: string;
  details?: unknown;
}

// =============================================================================
// ERROR HANDLING
// =============================================================================

async function getErrorMessage(
  response: Response,
): Promise<string> {
  const contentType =
    response.headers.get('content-type') ?? '';

  if (contentType.includes('application/json')) {
    try {
      const body =
        (await response.json()) as ApiError;

      return (
        body.error ??
        body.message ??
        `Clinical API request failed (${response.status})`
      );
    } catch {
      // Fall through.
    }
  }

  try {
    const text = await response.text();

    if (text.trim()) {
      return text;
    }
  } catch {
    // Ignore.
  }

  return `Clinical API request failed (${response.status})`;
}

// =============================================================================
// GENERIC JSON REQUEST
// =============================================================================

async function postJson<T>(
  url: string,
  body: unknown,
  signal?: AbortSignal,
): Promise<T> {
  const response = await fetch(url, {
    method: 'POST',
    credentials: 'include',
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
    signal,
  });

  if (!response.ok) {
    throw new Error(
      await getErrorMessage(response),
    );
  }

  const contentType =
    response.headers.get('content-type') ?? '';

  if (!contentType.includes('application/json')) {
    throw new Error(
      'Clinical API returned a non-JSON response.',
    );
  }

  return response.json() as Promise<T>;
}

// =============================================================================
// CONTEXT NORMALIZATION
//
// The UI may provide convenience fields.
// The CPU remains authoritative.
// =============================================================================

function normalizePregnancyState(
  input: StartEncounterInput,
): PregnancyState {
  // Pregnancy is biologically not applicable for male patients.
  if (input.sex === 'male') {
    return 'not_applicable';
  }

  if (input.pregnancyState) {
    return input.pregnancyState;
  }

  if (input.pregnant === true) {
    return 'pregnant';
  }

  if (input.pregnant === false) {
    return 'not_pregnant';
  }

  return 'unknown';
}

function normalizeInput(
  input: StartEncounterInput,
): StartEncounterInput {
  return {
    ...input,

    patientId: input.patientId,

    sex: input.sex,

    name: input.name ?? null,

    occupation: input.occupation ?? null,

    pregnancyState:
      normalizePregnancyState(input),

    presentingComplaintCodes:
      input.presentingComplaintCodes ?? [],

    activeSymptomCodes:
      input.activeSymptomCodes ?? [],
  };
}

// =============================================================================
// START ENCOUNTER
//
// IMPORTANT:
// The UI does NOT choose ADULT_MEDICAL / PEDIATRIC / OBGYN / NEONATAL etc.
// It supplies patient context.
// The CPU resolves the authoritative ClinicalFormatPlan.
// =============================================================================

export async function startEncounter(
  input: StartEncounterInput,
  signal?: AbortSignal,
): Promise<StartEncounterResponse> {
  if (!input.patientId) {
    throw new Error(
      'patientId is required to start a clinical encounter.',
    );
  }

  const normalized =
    normalizeInput(input);

  return postJson<StartEncounterResponse>(
    ENDPOINTS.encounters,
    normalized,
    signal,
  );
}

// =============================================================================
// OPEN EXISTING ENCOUNTER
//
// Rehydrates the universal projection from facts persisted in PostgreSQL.
// =============================================================================

export async function getEncounterSnapshot(
  encounterId: string,
  signal?: AbortSignal,
): Promise<EncounterSnapshot> {
  const response = await fetch(
    `${API_BASE}/clinical/encounters/${encodeURIComponent(encounterId)}`,
    {
      method: 'GET',
      credentials: 'include',
      headers: {
        accept: 'application/json',
      },
      signal,
    },
  );

  if (!response.ok) {
    throw new Error(await getErrorMessage(response));
  }

  return response.json() as Promise<EncounterSnapshot>;
}

// =============================================================================
// CAPTURE CLINICAL EVENT
//
// Every answer, disposition, symptom, examination finding, investigation,
// clinician decision, vital, medication event, etc. travels through here.
//
// The CPU receives the event, persists/updates state, applies rules, then
// returns a NEW projection.
//
// The UI replaces its state with that projection.
// =============================================================================

export async function captureClinicalEvent(
  input: CaptureClinicalEventInput,
  signal?: AbortSignal,
): Promise<UniversalClinicalProjection> {
  if (!input.patientId) {
    throw new Error(
      'patientId is required when capturing a clinical event.',
    );
  }

  if (!input.encounterId) {
    throw new Error(
      'encounterId is required when capturing a clinical event.',
    );
  }

  if (!input.event?.type) {
    throw new Error(
      'Clinical event type is required.',
    );
  }

  return postJson<UniversalClinicalProjection>(
    ENDPOINTS.events,
    input,
    signal,
  );
}

// =============================================================================
// BACKWARD-COMPATIBLE ALIAS
// =============================================================================

export const sendClinicalEvent =
  captureClinicalEvent;

// =============================================================================
// CLINICAL EVENT BUILDERS
// =============================================================================

export function createClinicalEvent(
  type: ClinicalEvent['type'],
  payload: Record<string, unknown>,
): ClinicalEvent {
  return {
    type,
    payload,
    timestamp: new Date().toISOString(),
  };
}

// =============================================================================
// SYMPTOM
// =============================================================================

export function symptomPresented(
  symptomCode: string,
  payload: Record<string, unknown> = {},
): ClinicalEvent {
  return createClinicalEvent(
    'SYMPTOM_PRESENTED',
    {
      symptomCode,
      ...payload,
    },
  );
}

// =============================================================================
// QUESTION ANSWER
// =============================================================================

export function questionAnswered(
  questionCode: string,
  answerCodes: string[],
  rawValue?: unknown,
): ClinicalEvent {
  return createClinicalEvent(
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

// =============================================================================
// QUESTION DISPOSITION
// =============================================================================

export function questionDispositioned(
  questionCode: string,
  disposition:
    | 'skipped'
    | 'not_applicable'
    | 'deferred',
): ClinicalEvent {
  return createClinicalEvent(
    'QUESTION_DISPOSITIONED',
    {
      questionCode,
      disposition,
    },
  );
}

// =============================================================================
// FACT
// =============================================================================

export function factCaptured(
  factCode: string,
  value: unknown,
  payload: Record<string, unknown> = {},
): ClinicalEvent {
  return createClinicalEvent(
    'FACT_CAPTURED',
    {
      factCode,
      value,
      ...payload,
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
  return createClinicalEvent(
    'EXAM_FINDING_CAPTURED',
    {
      findingCode,
      value,
      unit: unit ?? null,
    },
  );
}

// =============================================================================
// LAB
// =============================================================================

export function labResultReceived(
  factCode: string,
  value: unknown,
  unit?: string | null,
): ClinicalEvent {
  return createClinicalEvent(
    'LAB_RESULT_RECEIVED',
    {
      factCode,
      value,
      unit: unit ?? null,
    },
  );
}

// =============================================================================
// IMAGING
// =============================================================================

export function imagingResultReceived(
  investigationCode: string,
  results: string[],
): ClinicalEvent {
  return createClinicalEvent(
    'IMAGING_RESULT_RECEIVED',
    {
      investigationCode,
      results,
    },
  );
}

// =============================================================================
// VITALS
// =============================================================================

export function vitalChanged(
  vitalCode: string,
  value: unknown,
  unit?: string | null,
): ClinicalEvent {
  return createClinicalEvent(
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
  return createClinicalEvent(
    'MEDICATION_STARTED',
    {
      medicationCode,
      ...payload,
    },
  );
}

// =============================================================================
// CLINICIAN DECISION
// =============================================================================

export function clinicianDecision(
  input: {
    type: string;
    code: string;
    recommendation: string;
    reason?: string | null;
    status:
      | 'accepted'
      | 'modified'
      | 'dismissed';
    decisionReason?: string | null;
  },
): ClinicalEvent {
  return createClinicalEvent(
    'CLINICIAN_DECISION',
    {
      type: input.type,
      code: input.code,
      recommendation:
        input.recommendation,
      reason:
        input.reason ?? null,
      status: input.status,
      decisionReason:
        input.decisionReason ?? null,
    },
  );
}

// =============================================================================
// DOCUMENTATION ACTION
// =============================================================================

export function documentationAction(
  actionCode: string,
  payload: Record<string, unknown> = {},
): ClinicalEvent {
  return createClinicalEvent(
    'DOCUMENTATION_ACTION',
    {
      actionCode,
      ...payload,
    },
  );
}

// =============================================================================
// ENCOUNTER START EVENT
// =============================================================================

export function encounterStarted(
  payload: Record<string, unknown> = {},
): ClinicalEvent {
  return createClinicalEvent(
    'ENCOUNTER_STARTED',
    payload,
  );
}