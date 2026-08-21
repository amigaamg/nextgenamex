// =============================================================================
// src/clinical/exam/types.ts
// AMEXAN — EXAMINATION UI STATE TYPES
//
// Local capture state for the examination workspace. This file only describes
// what the clinician is entering; the CPU remains the authority on reasoning.
// =============================================================================

export type SignPresence = 'present' | 'absent' | 'not_assessed';

export interface SignCapture {
  /** Overall presence: present / absent / not yet assessed. */
  presence: SignPresence;
  /** Free-text site(s) — e.g. "palmar creases", "conjunctival". */
  site?: string;
  /** Severity as plus-string: '+', '++', '+++'. */
  severity?: string;
}

export interface VitalCapture {
  value: number | null;
  entered: boolean;
}

export interface AnthroCapture {
  value: number | null;
  entered: boolean;
}

export interface UrineCapture {
  catheterPresent: boolean;
  color: string;
  volumeMl: number | null;
  durationHours: number | null;
  weightKg: number | null;
}

export type CapturedSelect = string | null;
export type CapturedText = string;

export interface ExamCaptureState {
  /** per finding code -> captured value (booleans, numbers, strings). */
  findings: Record<string, unknown>;
}
