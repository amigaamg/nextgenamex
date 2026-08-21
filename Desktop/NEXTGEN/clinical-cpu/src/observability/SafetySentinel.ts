// =============================================================================
// AMEXAN Safety Sentinel — Clinical Safety Reflex
// =============================================================================
//
// The Safety Sentinel is a permanent safety subscriber/service for AMEXAN.
//
// RESPONSIBILITIES
//   1. Resolve the applicable clinical dose protocol.
//   2. Evaluate the entered dose against the protocol.
//   3. Persist the prescription.
//   4. Persist the immutable safety-check result.
//   5. Persist a safety alert when a clinically relevant deviation exists.
//   6. Record the complete journey in cpu.event_log.
//   7. Preserve the distinction between:
//        SYSTEM_SUGGESTION
//        CLINICIAN_DECISION
//   8. Record clinician overrides as explicit human decisions.
//
// SAFETY PRINCIPLE
//   The Sentinel does NOT silently prescribe, reject, or modify medication.
//   It evaluates, records, alerts, and preserves the clinician's decision.
//
// DATABASE BOUNDARY
//   Operational patient/encounter data:
//       patient.patient
//       encounter.encounter
//       identity.person
//
//   Clinical safety mirror:
//       clinical.patients
//       clinical.encounters
//       clinical.prescriptions
//       clinical.prescription_safety_check
//       clinical.alert
//
//   Observability:
//       cpu.event_log
//
// =============================================================================

import { randomUUID } from 'node:crypto';
import type { Db, Row } from '../db.js';
import {
  JourneyEventType,
  recordJourneyEvent,
} from './EventCore.js';

// =============================================================================
// INPUT / OUTPUT TYPES
// =============================================================================

export interface DoseEvaluationInput {
  patientId?: string | null;
  encounterId?: string | null;

  medicationCode: string;
  medicationName?: string | null;

  /** Dose proposed by AMEXAN, if a system suggestion exists. */
  suggestedDose?: number | null;
  suggestedDoseUnit?: string | null;

  /** Dose actually entered/selected by the clinician. */
  enteredDose?: number | null;
  doseUnit?: string | null;

  route?: string | null;
  frequency?: string | null;
  doseExpression?: string | null;

  weightKg?: number | null;
  ageYears?: number | null;

  clinicianId?: string | null;

  /** Origin of the request: UI, API, engine, external system, etc. */
  source?: string | null;

  /** Optional workflow correlation identifier. */
  correlationId?: string | null;

  /** Optional causality link to the originating event. */
  parentEventId?: number | null;
}

export type SafetyCheckResult =
  | 'PASS'
  | 'WARN'
  | 'FAIL'
  | 'NOT_EVALUATED';

export type SafetySeverity =
  | 'LOW'
  | 'MODERATE'
  | 'HIGH'
  | 'CRITICAL';

export type SafetyDecisionSource =
  | 'SYSTEM_SUGGESTION'
  | 'CLINICIAN_DECISION';

export interface DoseEvaluationOutcome {
  medicationCode: string;

  result: SafetyCheckResult;
  severity: SafetySeverity | null;

  message: string;

  protocol: {
    referenceId: string | null;
    doseMin: number | null;
    doseMax: number | null;
    doseUnit: string | null;
    maxSingleDose: number | null;
    maxSingleDoseUnit: string | null;
    maxDailyDose: number | null;
    maxDailyDoseUnit: string | null;
  };

  enteredDose: number | null;
  suggestedDose: number | null;
  deviationPct: number | null;

  alertId: string | null;
  checkId: string;
  prescriptionId: string;

  sourceOfDecision: SafetyDecisionSource;
}

// =============================================================================
// DATABASE TYPES
// =============================================================================

interface DoseReferenceRow extends Row {
  id: string;
  medication_code: string;

  route: string | null;
  dose_expression: string | null;
  dose_basis: string | null;

  dose_min: string | null;
  dose_max: string | null;
  dose_unit: string | null;

  max_single_dose: string | null;
  max_single_dose_unit: string | null;

  max_daily_dose: string | null;
  max_daily_dose_unit: string | null;

  weight_min_kg: string | null;
  weight_max_kg: string | null;

  age_min_years: string | null;
  age_max_years: string | null;

  status: string;
}

interface AlertRow extends Row {
  id: string;
}

interface CheckRow extends Row {
  id: string;
}

interface ClinicalPatientRow extends Row {
  id: string;
}

interface ClinicalEncounterRow extends Row {
  id: string;
}

interface OperationalPersonRow extends Row {
  birth_date: string | Date | null;
  sex_at_birth: string | null;
  blood_type: string | null;
}

interface OperationalEncounterRow extends Row {
  patient_id: string;
  encounter_type_code: string | null;
  department_id: string | null;
  started_at: string | Date | null;
}

// =============================================================================
// CONSTANTS
// =============================================================================

const SOURCE_TYPES = [
  'clinical',
  'clinician',
  'patient',
  'device',
  'laboratory',
  'imaging',
  'medication',
  'system',
  'integration',
  'import',
] as const;

type SentinelSourceType = (typeof SOURCE_TYPES)[number];

const SEX_CODES = [
  'MALE',
  'FEMALE',
  'INTERSEX',
  'UNKNOWN',
] as const;

const BLOOD_CODES = [
  'A_POSITIVE',
  'A_NEGATIVE',
  'B_POSITIVE',
  'B_NEGATIVE',
  'AB_POSITIVE',
  'AB_NEGATIVE',
  'O_POSITIVE',
  'O_NEGATIVE',
  'UNKNOWN',
] as const;

const ENCOUNTER_TYPE_MAP: Record<string, string> = {
  opd: 'OUTPATIENT',
  outpatient: 'OUTPATIENT',

  ed: 'EMERGENCY',
  emergency: 'EMERGENCY',

  ipd: 'INPATIENT',
  inpatient: 'INPATIENT',

  telemedicine: 'TELEMEDICINE',

  home_visit: 'HOME',
  home: 'HOME',

  community: 'COMMUNITY',

  procedure: 'THEATRE',

  consultation: 'OUTPATIENT',

  follow_up: 'FOLLOW_UP',

  day_care: 'INPATIENT',
};

// =============================================================================
// NORMALIZATION / VALIDATION
// =============================================================================

function toNumber(value: unknown): number | null {
  if (value == null || value === '') {
    return null;
  }

  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }

  if (typeof value === 'string') {
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
  }

  return null;
}

function normalizeOptionalPositiveNumber(
  value: number | null | undefined,
): number | null {
  if (value == null) {
    return null;
  }

  if (!Number.isFinite(value) || value < 0) {
    return null;
  }

  return value;
}

function normalizeSexCode(value?: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toUpperCase();

  return (SEX_CODES as readonly string[]).includes(normalized)
    ? normalized
    : 'UNKNOWN';
}

function normalizeBloodGroup(value?: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toUpperCase();

  return (BLOOD_CODES as readonly string[]).includes(normalized)
    ? normalized
    : 'UNKNOWN';
}

function mapEncounterType(value?: unknown): string {
  if (typeof value !== 'string') {
    return 'OTHER';
  }

  return ENCOUNTER_TYPE_MAP[value.trim().toLowerCase()] ?? 'OTHER';
}

function normalizeSourceType(value?: string | null): SentinelSourceType {
  if (!value) {
    return 'system';
  }

  const normalized = value.trim().toLowerCase();

  return (SOURCE_TYPES as readonly string[]).includes(normalized)
    ? (normalized as SentinelSourceType)
    : 'system';
}

function normalizeLimit(value: number): number {
  if (!Number.isFinite(value)) {
    return 500;
  }

  return Math.max(1, Math.min(Math.floor(value), 5000));
}

function sameNumericValue(
  left: number | null | undefined,
  right: number | null | undefined,
): boolean {
  if (left == null || right == null) {
    return false;
  }

  return Math.abs(left - right) <= Number.EPSILON;
}

function calculateDeviationPct(
  suggestedDose: number | null | undefined,
  enteredDose: number | null | undefined,
): number | null {
  if (
    suggestedDose == null ||
    enteredDose == null ||
    !Number.isFinite(suggestedDose) ||
    !Number.isFinite(enteredDose) ||
    suggestedDose === 0
  ) {
    return null;
  }

  return (
    Math.round(
      ((enteredDose - suggestedDose) / suggestedDose) * 10000,
    ) / 100
  );
}

function isUuid(value?: string | null): boolean {
  return (
    value != null &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      value,
    )
  );
}

// =============================================================================
// PROTOCOL MATCHING
// =============================================================================

interface ReferenceMatch {
  reference: DoseReferenceRow | null;
  score: number;
}

/**
 * Select the most appropriate active protocol row.
 *
 * Matching deliberately rewards supplied patient/context information:
 *
 *   route       +4
 *   weight      +2
 *   age         +2
 *
 * A bounded row only receives its context score when the supplied value
 * actually falls inside that row's range.
 */
function pickReference(
  rows: DoseReferenceRow[],
  route: string | null,
  weightKg: number | null,
  ageYears: number | null,
): ReferenceMatch {
  if (rows.length === 0) {
    return {
      reference: null,
      score: 0,
    };
  }

  const active = rows.filter(
    (row) => row.status.trim().toUpperCase() === 'ACTIVE',
  );

  const pool = active.length > 0 ? active : rows;

  let best: DoseReferenceRow | null = null;
  let bestScore = -1;

  for (const row of pool) {
    let score = 0;

    if (
      route &&
      row.route &&
      row.route.trim().toLowerCase() === route.trim().toLowerCase()
    ) {
      score += 4;
    }

    if (weightKg != null) {
      const min = toNumber(row.weight_min_kg);
      const max = toNumber(row.weight_max_kg);

      const matchesMin = min == null || weightKg >= min;
      const matchesMax = max == null || weightKg <= max;

      if (matchesMin && matchesMax) {
        score += 2;
      }
    }

    if (ageYears != null) {
      const min = toNumber(row.age_min_years);
      const max = toNumber(row.age_max_years);

      const matchesMin = min == null || ageYears >= min;
      const matchesMax = max == null || ageYears <= max;

      if (matchesMin && matchesMax) {
        score += 2;
      }
    }

    if (score > bestScore) {
      bestScore = score;
      best = row;
    }
  }

  return {
    reference: best ?? pool[0] ?? null,
    score: bestScore,
  };
}

// =============================================================================
// SAFETY EVALUATION
// =============================================================================

interface EvaluationState {
  result: SafetyCheckResult;
  severity: SafetySeverity | null;
  message: string;
}

function evaluateAgainstProtocol(
  medicationCode: string,
  enteredDose: number | null,
  doseUnit: string | null,
  reference: DoseReferenceRow | null,
): EvaluationState {
  if (!reference) {
    return {
      result: 'NOT_EVALUATED',
      severity: null,
      message:
        'Dose not evaluated because no matching active protocol reference was found.',
    };
  }

  if (enteredDose == null) {
    return {
      result: 'NOT_EVALUATED',
      severity: null,
      message:
        'Dose not evaluated because no entered dose was supplied.',
    };
  }

  const doseMin = toNumber(reference.dose_min);
  const doseMax = toNumber(reference.dose_max);
  const maxSingleDose = toNumber(reference.max_single_dose);

  const protocolUnit =
    reference.dose_unit?.trim() ||
    doseUnit?.trim() ||
    null;

  const enteredUnit = doseUnit?.trim() || null;

  /*
   * A numerical comparison is only safe when the entered dose and protocol
   * dose are expressed in the same unit.
   *
   * The Sentinel does not silently perform medication-unit conversions.
   * Unit conversion belongs to a dedicated medication/units service.
   */
  if (
    protocolUnit &&
    enteredUnit &&
    protocolUnit.toLowerCase() !== enteredUnit.toLowerCase()
  ) {
    return {
      result: 'NOT_EVALUATED',
      severity: null,
      message:
        `Dose not evaluated because entered unit "${enteredUnit}" does not match protocol unit "${protocolUnit}".`,
    };
  }

  if (
    doseMin != null &&
    enteredDose < doseMin
  ) {
    return {
      result: 'WARN',
      severity: 'MODERATE',
      message:
        `Entered dose ${enteredDose} ${protocolUnit ?? ''}`.trim() +
        ` is below the protocol minimum ${doseMin} ${protocolUnit ?? ''}`.trim() +
        ` for ${medicationCode}.`,
    };
  }

  if (
    doseMax != null &&
    enteredDose > doseMax
  ) {
    return {
      result: 'FAIL',
      severity: determineExcessSeverity(
        enteredDose,
        doseMax,
      ),
      message:
        `Entered dose ${enteredDose} ${protocolUnit ?? ''}`.trim() +
        ` exceeds the protocol maximum ${doseMax} ${protocolUnit ?? ''}`.trim() +
        ` for ${medicationCode}.`,
    };
  }

  if (
    maxSingleDose != null &&
    enteredDose > maxSingleDose
  ) {
    const unit =
      reference.max_single_dose_unit?.trim() ||
      protocolUnit;

    if (
      protocolUnit &&
      unit &&
      protocolUnit.toLowerCase() !== unit.toLowerCase()
    ) {
      return {
        result: 'NOT_EVALUATED',
        severity: null,
        message:
          `Maximum single-dose rule could not be evaluated because protocol units differ (${protocolUnit} vs ${unit}).`,
      };
    }

    return {
      result: 'FAIL',
      severity: determineExcessSeverity(
        enteredDose,
        maxSingleDose,
      ),
      message:
        `Entered dose ${enteredDose} ${unit ?? ''}`.trim() +
        ` exceeds the maximum single dose ${maxSingleDose} ${unit ?? ''}`.trim() +
        ` for ${medicationCode}.`,
    };
  }

  return {
    result: 'PASS',
    severity: null,
    message:
      `Dose ${enteredDose} ${protocolUnit ?? ''}`.trim() +
      ` is within the evaluated protocol limits for ${medicationCode}.`,
  };
}

function determineExcessSeverity(
  enteredDose: number,
  upperLimit: number,
): SafetySeverity {
  if (
    upperLimit > 0 &&
    enteredDose >= upperLimit * 2
  ) {
    return 'CRITICAL';
  }

  if (
    upperLimit > 0 &&
    enteredDose >= upperLimit * 1.5
  ) {
    return 'HIGH';
  }

  return 'HIGH';
}

// =============================================================================
// SAFETY SENTINEL
// =============================================================================

export class SafetySentinel {
  constructor(
    private readonly db: Db,
  ) {}

  // ===========================================================================
  // DOSE EVALUATION
  // ===========================================================================

  /**
   * Evaluate a medication dose and persist the complete safety chain.
   *
   * Chain:
   *
   *   prescription
   *       ↓
   *   prescription_safety_check
   *       ↓
   *   alert (when required)
   *       ↓
   *   cpu.event_log
   *
   * No medication is silently changed or blocked.
   */
  async evaluateDose(
    input: DoseEvaluationInput,
  ): Promise<DoseEvaluationOutcome> {
    this.validateInput(input);

    const patientId = input.patientId ?? null;
    const encounterId = input.encounterId ?? null;

    const enteredDose =
      normalizeOptionalPositiveNumber(
        input.enteredDose,
      );

    const suggestedDose =
      normalizeOptionalPositiveNumber(
        input.suggestedDose,
      );

    const weightKg =
      normalizeOptionalPositiveNumber(
        input.weightKg,
      );

    const ageYears =
      normalizeOptionalPositiveNumber(
        input.ageYears,
      );

    // -------------------------------------------------------------------------
    // Resolve protocol.
    // -------------------------------------------------------------------------

    const references =
      await this.db.query<DoseReferenceRow>(
        `SELECT
            id,
            medication_code,
            route,
            dose_expression,
            dose_basis,
            dose_min,
            dose_max,
            dose_unit,
            max_single_dose,
            max_single_dose_unit,
            max_daily_dose,
            max_daily_dose_unit,
            weight_min_kg,
            weight_max_kg,
            age_min_years,
            age_max_years,
            status
         FROM clinical.drug_dose_reference
         WHERE medication_code = $1
         ORDER BY
           CASE
             WHEN status = 'ACTIVE' THEN 0
             ELSE 1
           END,
           id`,
        [input.medicationCode],
      );

    const { reference: ref } =
      pickReference(
        references,
        input.route ?? null,
        weightKg,
        ageYears,
      );

    const doseMin =
      ref ? toNumber(ref.dose_min) : null;

    const doseMax =
      ref ? toNumber(ref.dose_max) : null;

    const doseUnit =
      ref?.dose_unit?.trim() ||
      input.doseUnit?.trim() ||
      null;

    const maxSingleDose =
      ref ? toNumber(ref.max_single_dose) : null;

    const maxSingleDoseUnit =
      ref?.max_single_dose_unit?.trim() ||
      doseUnit;

    const maxDailyDose =
      ref ? toNumber(ref.max_daily_dose) : null;

    const maxDailyDoseUnit =
      ref?.max_daily_dose_unit?.trim() ||
      doseUnit;

    // -------------------------------------------------------------------------
    // Evaluate.
    // -------------------------------------------------------------------------

    const evaluation =
      evaluateAgainstProtocol(
        input.medicationCode,
        enteredDose,
        input.doseUnit ?? null,
        ref,
      );

    const deviationPct =
      calculateDeviationPct(
        suggestedDose,
        enteredDose,
      );

    const sourceOfDecision: SafetyDecisionSource =
      enteredDose != null &&
      suggestedDose != null &&
      !sameNumericValue(
        enteredDose,
        suggestedDose,
      )
        ? 'CLINICIAN_DECISION'
        : 'SYSTEM_SUGGESTION';

    // -------------------------------------------------------------------------
    // Ensure clinical FK mirrors exist.
    // -------------------------------------------------------------------------

    await this.ensureClinicalMirror(
      patientId,
      encounterId,
    );

    // -------------------------------------------------------------------------
    // Create prescription.
    // -------------------------------------------------------------------------

    const prescriptionId = randomUUID();

    await this.db.query(
      `INSERT INTO clinical.prescriptions
        (
          id,
          patient_id,
          encounter_id,
          medication_code,
          indication_code,
          dose_numeric,
          dose_unit,
          frequency_text,
          route,
          dose_expression,
          weight_used_kg,
          prescription_status,
          prescribed_by,
          prescribed_at
        )
       VALUES
        (
          $1,
          $2,
          $3,
          $4,
          NULL,
          $5,
          $6,
          $7,
          $8,
          $9,
          $10,
          'DRAFT',
          $11,
          now()
        )`,
      [
        prescriptionId,
        patientId,
        encounterId,
        input.medicationCode,
        enteredDose,
        input.doseUnit ?? null,
        input.frequency ?? null,
        input.route ?? null,
        input.doseExpression ?? null,
        weightKg,
        input.clinicianId ?? null,
      ],
    );

    // -------------------------------------------------------------------------
    // Persist safety check.
    // -------------------------------------------------------------------------

    const checkId = randomUUID();

    const evidence = {
      medicationCode: input.medicationCode,
      medicationName: input.medicationName ?? null,

      enteredDose,
      enteredDoseUnit: input.doseUnit ?? null,

      suggestedDose,
      suggestedDoseUnit:
        input.suggestedDoseUnit ?? null,

      deviationPct,

      route: input.route ?? null,
      frequency: input.frequency ?? null,
      doseExpression:
        input.doseExpression ?? null,

      weightKg,
      ageYears,

      protocol: {
        referenceId: ref?.id ?? null,
        doseMin,
        doseMax,
        doseUnit,

        maxSingleDose,
        maxSingleDoseUnit,

        maxDailyDose,
        maxDailyDoseUnit,

        doseBasis:
          ref?.dose_basis ?? null,
      },

      source: input.source ?? null,
      sourceOfDecision,

      clinicianId:
        input.clinicianId ?? null,

      correlationId:
        input.correlationId ?? null,
    };

    await this.db.query(
      `INSERT INTO clinical.prescription_safety_check
        (
          id,
          prescription_id,
          check_type,
          result,
          severity,
          message,
          evidence_json,
          evaluated_at
        )
       VALUES
        (
          $1,
          $2,
          'DOSE',
          $3,
          $4,
          $5,
          $6,
          now()
        )`,
      [
        checkId,
        prescriptionId,
        evaluation.result,
        evaluation.severity,
        evaluation.message,
        evidence,
      ],
    );

    // -------------------------------------------------------------------------
    // Generate safety alert.
    // -------------------------------------------------------------------------

    let alertId: string | null = null;

    if (
      evaluation.result === 'FAIL' ||
      evaluation.result === 'WARN'
    ) {
      const generatedAlertId =
        randomUUID();

      const alertRow =
        await this.db.queryOne<AlertRow>(
          `INSERT INTO clinical.alert
            (
              id,
              patient_id,
              encounter_id,
              alert_code,
              alert_type,
              severity,
              title,
              message,
              evidence_json,
              action_required,
              acknowledged,
              resolved,
              created_at
            )
           VALUES
            (
              $1,
              $2,
              $3,
              'DOSE_SAFETY',
              'SAFETY',
              $4,
              'Dose safety',
              $5,
              $6,
              true,
              false,
              false,
              now()
            )
           RETURNING id`,
          [
            generatedAlertId,
            patientId,
            encounterId,
            evaluation.severity ?? 'HIGH',
            evaluation.message,
            {
              ...evidence,
              prescriptionId,
              safetyCheckId: checkId,
            },
          ],
        );

      alertId =
        alertRow?.id ??
        generatedAlertId;
    }

    // -------------------------------------------------------------------------
    // Record DOSE_SAFETY_CHECK journey event.
    // -------------------------------------------------------------------------

    const commonJourney = {
      patientId,
      encounterId,

      correlationId:
        input.correlationId ?? null,

      parentEventId:
        input.parentEventId ?? null,
    };

    await recordJourneyEvent(
      this.db,
      {
        ...commonJourney,

        eventType:
          JourneyEventType.DOSE_SAFETY_CHECK,

        sourceType: 'system',
        sourceId: 'safety-sentinel',

        idempotencyKey:
          `dose-safety:${prescriptionId}`,

        payload: {
          prescriptionId,
          checkId,

          medicationCode:
            input.medicationCode,

          enteredDose,
          suggestedDose,
          deviationPct,

          result:
            evaluation.result,

          severity:
            evaluation.severity,

          message:
            evaluation.message,

          sourceOfDecision,
        },

        factCode:
          input.medicationCode,

        factValue: {
          result:
            evaluation.result,

          severity:
            evaluation.severity,

          enteredDose,
          doseUnit:
            input.doseUnit ?? null,
        },
      },
    );

    // -------------------------------------------------------------------------
    // Record explicit clinician override.
    // -------------------------------------------------------------------------

    if (
      sourceOfDecision ===
      'CLINICIAN_DECISION'
    ) {
      await recordJourneyEvent(
        this.db,
        {
          ...commonJourney,

          eventType:
            JourneyEventType.MEDICATION_OVERRIDE,

          sourceType: 'clinician',

          sourceId:
            input.clinicianId ?? null,

          idempotencyKey:
            `medication-override:${prescriptionId}`,

          payload: {
            prescriptionId,

            medicationCode:
              input.medicationCode,

            suggestedDose,
            suggestedDoseUnit:
              input.suggestedDoseUnit ?? null,

            clinicianSelectedDose:
              enteredDose,

            clinicianSelectedDoseUnit:
              input.doseUnit ?? null,

            deviationPct,

            sourceOfDecision:
              'CLINICIAN_DECISION',

            reason:
              'Clinician selected a dose different from the system suggestion. AMEXAN records the decision and does not silently modify it.',
          },
        },
      );
    }

    // -------------------------------------------------------------------------
    // Record generated alert.
    // -------------------------------------------------------------------------

    if (alertId) {
      await recordJourneyEvent(
        this.db,
        {
          ...commonJourney,

          eventType:
            JourneyEventType.SAFETY_ALERT_GENERATED,

          sourceType: 'system',
          sourceId: 'safety-sentinel',

          idempotencyKey:
            `safety-alert:${alertId}`,

          payload: {
            alertId,

            prescriptionId,
            checkId,

            medicationCode:
              input.medicationCode,

            result:
              evaluation.result,

            severity:
              evaluation.severity,

            message:
              evaluation.message,
          },
        },
      );
    }

    // -------------------------------------------------------------------------
    // Return canonical outcome.
    // -------------------------------------------------------------------------

    return {
      medicationCode:
        input.medicationCode,

      result:
        evaluation.result,

      severity:
        evaluation.severity,

      message:
        evaluation.message,

      protocol: {
        referenceId:
          ref?.id ?? null,

        doseMin,
        doseMax,
        doseUnit,

        maxSingleDose,
        maxSingleDoseUnit,

        maxDailyDose,
        maxDailyDoseUnit,
      },

      enteredDose,
      suggestedDose,

      deviationPct,

      alertId,
      checkId,
      prescriptionId,

      sourceOfDecision,
    };
  }

  // ===========================================================================
  // INPUT VALIDATION
  // ===========================================================================

  private validateInput(
    input: DoseEvaluationInput,
  ): void {
    if (
      typeof input.medicationCode !==
        'string' ||
      input.medicationCode.trim() === ''
    ) {
      throw new Error(
        'Medication code is required for dose safety evaluation.',
      );
    }

    if (
      input.enteredDose != null &&
      (
        !Number.isFinite(
          input.enteredDose,
        ) ||
        input.enteredDose < 0
      )
    ) {
      throw new Error(
        'Entered dose must be a finite non-negative number.',
      );
    }

    if (
      input.suggestedDose != null &&
      (
        !Number.isFinite(
          input.suggestedDose,
        ) ||
        input.suggestedDose < 0
      )
    ) {
      throw new Error(
        'Suggested dose must be a finite non-negative number.',
      );
    }

    if (
      input.weightKg != null &&
      (
        !Number.isFinite(
          input.weightKg,
        ) ||
        input.weightKg < 0
      )
    ) {
      throw new Error(
        'Weight must be a finite non-negative number.',
      );
    }

    if (
      input.ageYears != null &&
      (
        !Number.isFinite(
          input.ageYears,
        ) ||
        input.ageYears < 0
      )
    ) {
      throw new Error(
        'Age must be a finite non-negative number.',
      );
    }
  }

  // ===========================================================================
  // CLINICAL MIRROR
  // ===========================================================================

  /**
   * Ensure clinical safety/audit mirrors exist for the supplied operational
   * patient and encounter.
   *
   * The mirror contains only the minimum identity/context required by the
   * clinical safety schema. It does not become a second source of truth.
   */
  private async ensureClinicalMirror(
    patientId: string | null,
    encounterId: string | null,
  ): Promise<void> {
    // -------------------------------------------------------------------------
    // Patient mirror.
    // -------------------------------------------------------------------------

    if (patientId) {
      const patient =
        await this.db.queryOne<ClinicalPatientRow>(
          `SELECT id
             FROM clinical.patients
            WHERE id = $1`,
          [patientId],
        );

      if (!patient) {
        const person =
          await this.db.queryOne<OperationalPersonRow>(
            `SELECT
                p.birth_date,
                p.sex_at_birth,
                p.blood_type
             FROM identity.person p
             JOIN patient.patient pp
               ON pp.person_id = p.id
            WHERE pp.id = $1`,
            [patientId],
          );

        await this.db.query(
          `INSERT INTO clinical.patients
            (
              id,
              external_id,
              date_of_birth,
              sex_code,
              blood_group_code,
              created_at,
              updated_at
            )
           VALUES
            (
              $1,
              $2,
              $3,
              $4,
              $5,
              now(),
              now()
            )
           ON CONFLICT (id) DO NOTHING`,
          [
            patientId,
            patientId,

            person?.birth_date ??
              null,

            normalizeSexCode(
              person?.sex_at_birth,
            ),

            normalizeBloodGroup(
              person?.blood_type,
            ),
          ],
        );
      }
    }

    // -------------------------------------------------------------------------
    // Encounter mirror.
    // -------------------------------------------------------------------------

    if (encounterId) {
      const encounter =
        await this.db.queryOne<ClinicalEncounterRow>(
          `SELECT id
             FROM clinical.encounters
            WHERE id = $1`,
          [encounterId],
        );

      if (!encounter) {
        const source =
          await this.db.queryOne<OperationalEncounterRow>(
            `SELECT
                patient_id,
                encounter_type_code,
                department_id,
                started_at
             FROM encounter.encounter
            WHERE id = $1`,
            [encounterId],
          );

        if (source) {
          // Ensure the operational encounter's patient also exists in the
          // clinical mirror before satisfying the clinical encounter FK.
          await this.ensureClinicalMirror(
            source.patient_id ?? patientId,
            null,
          );

          await this.db.query(
            `INSERT INTO clinical.encounters
              (
                id,
                patient_id,
                department_code,
                encounter_type,
                pregnancy_state,
                status,
                started_at,
                created_at,
                updated_at
              )
             VALUES
              (
                $1,
                $2,
                $3,
                $4,
                'NOT_APPLICABLE',
                'ACTIVE',
                $5,
                now(),
                now()
              )
             ON CONFLICT (id) DO NOTHING`,
            [
              encounterId,

              source.patient_id ??
                patientId,

              source.department_id ??
                'opd',

              mapEncounterType(
                source.encounter_type_code,
              ),

              source.started_at ??
                new Date(),
            ],
          );
        }
      }
    }
  }

  // ===========================================================================
  // ALERT ACKNOWLEDGEMENT
  // ===========================================================================

  /**
   * Acknowledge an active safety alert.
   *
   * The Sentinel does not resolve the clinical decision itself. It records
   * acknowledgement as a human/system interaction with the alert.
   */
  async acknowledgeAlert(
    alertId: string,
    acknowledgedBy?: string | null,
    correlationId?: string | null,
  ): Promise<boolean> {
    if (
      typeof alertId !== 'string' ||
      alertId.trim() === ''
    ) {
      throw new Error(
        'Alert id is required.',
      );
    }

    const actor =
      acknowledgedBy ?? null;

    const actorForDatabase =
      isUuid(actor)
        ? actor
        : null;

    const row =
      await this.db.queryOne<Row>(
        `UPDATE clinical.alert
            SET
              acknowledged = true,
              acknowledged_by = $2,
              acknowledged_at = now()
          WHERE id = $1
            AND acknowledged = false
          RETURNING id, patient_id, encounter_id`,
        [
          alertId,
          actorForDatabase,
        ],
      );

    if (!row) {
      return false;
    }

    await recordJourneyEvent(
      this.db,
      {
        eventType:
          JourneyEventType.ALERT_ACKNOWLEDGED,

        patientId:
          typeof row.patient_id === 'string'
            ? row.patient_id
            : null,

        encounterId:
          typeof row.encounter_id === 'string'
            ? row.encounter_id
            : null,

        sourceType:
          'clinician',

        sourceId:
          actor,

        correlationId:
          correlationId ?? null,

        idempotencyKey:
          `alert-ack:${alertId}`,

        payload: {
          alertId,
          acknowledgedBy: actor,
        },
      },
    );

    return true;
  }
}