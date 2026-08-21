// =============================================================================
// AMEXAN Clinical CPU — ExaminationInterpreter
// =============================================================================
//
// PURPOSE
// -----------------------------------------------------------------------------
// Converts structured examination observations into canonical clinical facts
// and evidence-based interpretations.
//
// The examination is NOT a separate reasoning universe.
//
//                    HISTORY
//                       │
//                       ▼
//                clinical.fact
//                       ▲
//                       │
//                 EXAMINATION
//                       │
//                       ▼
//          ExaminationInterpreter
//                       │
//          ┌────────────┴────────────┐
//          ▼                         ▼
//   captured clinical fact     interpretation fact
//          │                         │
//          └────────────┬────────────┘
//                       ▼
//              AMEXAN Clinical CPU
//
// This ensures that symptoms, history, examination, vital signs and measured
// observations ultimately enter the SAME canonical reasoning substrate.
//
// CLINICAL PRINCIPLES
// -----------------------------------------------------------------------------
// 1. Examination findings are observations, not diagnoses.
// 2. A finding may establish a canonical clinical fact.
// 3. Numeric observations may additionally receive a knowledge-derived
//    interpretation against an age/sex-appropriate reference range.
// 4. Reference ranges MUST come from the knowledge layer.
// 5. The interpreter MUST NOT invent reference ranges.
// 6. Age and sex are contextual selectors, not diagnostic conclusions.
// 7. A missing reference range means "not interpreted", never "normal".
// 8. A value outside a reference range is an abnormal observation; it is not
//    automatically a diagnosis.
// 9. Criticality must be explicitly knowledge-governed.
// 10. Tachycardia, tachypnoea, hypertension, hypotension, hypoxaemia etc.
//     must remain distinct clinical concepts.
// 11. The engine must preserve the original captured fact.
// 12. Interpretations must be traceable to the observation and knowledge rule.
// 13. Negative examination findings are valid clinical facts when explicitly
//     captured.
// 14. Examination interpretation must never silently overwrite a clinician's
//     documented observation.
// 15. The clinician remains the final decision authority.
//
// =============================================================================

import type { Db, Row } from '../db.js';

// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface ConceptRow extends Row {
  code: string;
  fact_definition_code: string | null;
  unit_code: string | null;
  normal_range_code: string | null;

  min_value: number | null;
  max_value: number | null;
  nr_unit: string | null;
  normal_text: string | null;
  abnormal_interpretation_code: string | null;
}

interface NormalRangeRow extends Row {
  code: string;
  measurement_code: string;

  min_value: number | null;
  max_value: number | null;

  unit: string | null;
  normal_text: string | null;
  abnormal_interpretation_code: string | null;

  /**
   * Optional metadata retained when the knowledge schema exposes it.
   * These fields are useful for provenance and future conflict resolution.
   */
  age_min_months?: number | null;
  age_max_months?: number | null;
  sex?: string | null;
  sort_order?: number | null;
}

// =============================================================================
// CLINICAL TYPES
// =============================================================================

export interface ExaminationContext {
  ageMonths?: number | null;
  ageYears?: number | null;
  ageDays?: number | null;
  sex?: string | null;
}

export interface Derivation {
  /**
   * Canonical fact established by the examination observation.
   */
  factCode: string;

  /**
   * Knowledge-derived interpretation.
   *
   * Examples:
   *   VITAL_NORMAL
   *   VITAL_HIGH
   *   VITAL_LOW
   *   VITAL_TACHY
   *   VITAL_HYPOXAEMIA
   *
   * null means that no interpretation was safely established.
   */
  interpretationCode: string | null;

  /**
   * Human-readable interpretation.
   */
  label?: string | null;

  /**
   * Original numeric observation, where applicable.
   */
  observedValue?: number | null;

  /**
   * Unit used for the observation.
   */
  unitCode?: string | null;

  /**
   * Reference range used.
   */
  normalRangeCode?: string | null;

  /**
   * Minimum reference value.
   */
  normalMin?: number | null;

  /**
   * Maximum reference value.
   */
  normalMax?: number | null;

  /**
   * Timestamp at which the CPU generated the interpretation.
   */
  deducedAt?: string;

  /**
   * Provenance statement describing why the interpretation exists.
   */
  provenance?: string;
}

export interface InterpretResult {
  /**
   * Canonical fact-definition codes established by captured examination
   * findings.
   */
  capturedFacts: string[];

  /**
   * Knowledge-derived interpretations.
   */
  deductions: Derivation[];
}

export interface ConceptResolution {
  factDefinitionCode: string | null;
  unit: string | null;
  normalRange: NormalRangeRow | null;
}

// =============================================================================
// HELPERS
// =============================================================================

/**
 * Convert whatever patient-age representation is available into months.
 *
 * Priority:
 *
 *   ageMonths
 *   ageYears
 *   ageDays
 *
 * The calculation is contextual only. It does not alter the patient's stored
 * demographics.
 */
export function ageMonths(
  state: ExaminationContext,
): number | null {
  if (
    state.ageMonths != null &&
    Number.isFinite(state.ageMonths) &&
    state.ageMonths >= 0
  ) {
    return state.ageMonths;
  }

  if (
    state.ageYears != null &&
    Number.isFinite(state.ageYears) &&
    state.ageYears >= 0
  ) {
    return state.ageYears * 12;
  }

  if (
    state.ageDays != null &&
    Number.isFinite(state.ageDays) &&
    state.ageDays >= 0
  ) {
    return state.ageDays / 30.44;
  }

  return null;
}

/**
 * Normalize sex for knowledge-range matching.
 *
 * The knowledge layer may use "all", "male", "female".
 * Unknown/unspecified sex resolves to "all" rather than being guessed.
 */
function normalizeSex(sex: string | null | undefined): string {
  if (!sex) return 'all';

  const normalized = sex.trim().toLowerCase();

  if (
    normalized === 'male' ||
    normalized === 'm' ||
    normalized === 'man'
  ) {
    return 'male';
  }

  if (
    normalized === 'female' ||
    normalized === 'f' ||
    normalized === 'woman'
  ) {
    return 'female';
  }

  return 'all';
}

/**
 * Normalize a numeric database value.
 */
function finiteNumber(
  value: unknown,
): number | null {
  if (typeof value === 'number') {
    return Number.isFinite(value) ? value : null;
  }

  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

/**
 * Normalize an interpretation code.
 */
function normalizeCode(
  code: string | null | undefined,
): string | null {
  if (!code) return null;

  const normalized = code.trim().toUpperCase();

  return normalized.length > 0 ? normalized : null;
}

// =============================================================================
// EXAMINATION INTERPRETER
// =============================================================================

export class ExaminationInterpreter {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // FINDING → FACT
  // ===========================================================================

  /**
   * Resolve a UI examination finding code into the canonical clinical fact
   * definition represented by knowledge.examination_concept.
   *
   * Example:
   *
   *   FIND-RESP-RATE
   *          ↓
   *   RESP_RATE
   *
   * The UI may therefore use a presentation-specific finding identifier while
   * the CPU reasons over the canonical fact-definition vocabulary.
   */
  async resolveFinding(
    findingCode: string,
  ): Promise<{ factDefinitionCode: string | null } | null> {
    const code = findingCode?.trim();

    if (!code) {
      return null;
    }

    const row = await this.db.queryOne<{
      fact_definition_code: string | null;
    }>(
      `
      SELECT ec.fact_definition_code
        FROM knowledge.examination_concept ec
       WHERE ec.code = $1
         AND ec.status = 'active'
       LIMIT 1
      `,
      [code],
    );

    if (!row) {
      return null;
    }

    return {
      factDefinitionCode: row.fact_definition_code ?? null,
    };
  }

  // ===========================================================================
  // CONCEPT RESOLUTION
  // ===========================================================================

  /**
   * Resolve an examination concept against the patient's demographic context.
   *
   * This performs two independent knowledge lookups:
   *
   *   1. examination concept → canonical clinical fact
   *   2. clinical fact → applicable age/sex-specific normal range
   *
   * No normal range means no interpretation.
   */
  async resolveConcept(
    conceptCode: string,
    patientAgeMonths: number | null,
    sex: string | null,
  ): Promise<ConceptResolution | null> {
    const code = conceptCode?.trim();

    if (!code) {
      return null;
    }

    const normalizedSex = normalizeSex(sex);

    const age =
      patientAgeMonths != null &&
      Number.isFinite(patientAgeMonths) &&
      patientAgeMonths >= 0
        ? patientAgeMonths
        : null;

    const concept = await this.db.queryOne<ConceptRow>(
      `
      SELECT
          ec.code,
          ec.fact_definition_code,
          fd.unit_code,

          nr.code AS normal_range_code,
          nr.min_value,
          nr.max_value,
          nr.unit AS nr_unit,
          nr.normal_text,
          nr.abnormal_interpretation_code

        FROM knowledge.examination_concept ec

        LEFT JOIN clinical.fact_definitions fd
          ON fd.fact_code = ec.fact_definition_code

        LEFT JOIN LATERAL (
          SELECT
              nrc.code,
              nrc.min_value,
              nrc.max_value,
              nrc.unit,
              nrc.normal_text,
              nrc.abnormal_interpretation_code

            FROM knowledge.normal_range nrc

           WHERE nrc.measurement_code = ec.fact_definition_code

             AND (
               $1::numeric IS NULL
               OR nrc.age_min_months IS NULL
               OR $1::numeric >= nrc.age_min_months
             )

             AND (
               $1::numeric IS NULL
               OR nrc.age_max_months IS NULL
               OR $1::numeric <= nrc.age_max_months
             )

             AND (
               lower(COALESCE(nrc.sex, 'all')) = 'all'
               OR lower(COALESCE(nrc.sex, 'all')) = $2
             )

           ORDER BY
             CASE
               WHEN lower(COALESCE(nrc.sex, 'all')) = $2
                 THEN 0
               ELSE 1
             END,
             CASE
               WHEN nrc.age_min_months IS NOT NULL
                 THEN 0
               ELSE 1
             END,
             COALESCE(nrc.sort_order, 999999),
             nrc.code

           LIMIT 1
        ) nr
          ON TRUE

       WHERE ec.code = $3
         AND ec.status = 'active'

       LIMIT 1
      `,
      [age, normalizedSex, code],
    );

    if (!concept) {
      return null;
    }

    const normalRange: NormalRangeRow | null =
      concept.normal_range_code
        ? {
            code: concept.normal_range_code,
            measurement_code:
              concept.fact_definition_code ?? '',
            min_value: finiteNumber(concept.min_value),
            max_value: finiteNumber(concept.max_value),
            unit: concept.nr_unit ?? null,
            normal_text: concept.normal_text ?? null,
            abnormal_interpretation_code:
              normalizeCode(
                concept.abnormal_interpretation_code,
              ),
          }
        : null;

    return {
      factDefinitionCode:
        concept.fact_definition_code ?? null,

      unit:
        concept.unit_code ??
        normalRange?.unit ??
        null,

      normalRange,
    };
  }

  // ===========================================================================
  // NUMERIC INTERPRETATION
  // ===========================================================================

  /**
   * Interpret a numeric observation against a knowledge-derived reference
   * interval.
   *
   * Boundary behavior:
   *
   *   value < minimum → low
   *   value > maximum → high
   *   minimum <= value <= maximum → normal
   *
   * This deliberately does NOT decide whether an abnormal value is clinically
   * dangerous unless the knowledge layer explicitly supplies a critical
   * interpretation code.
   */
  deduce(
    value: number,
    normal: NormalRangeRow,
  ): {
    interpretationCode: string | null;
    label: string | null;
  } {
    if (!Number.isFinite(value)) {
      return {
        interpretationCode: null,
        label: null,
      };
    }

    if (!normal) {
      return {
        interpretationCode: null,
        label: null,
      };
    }

    const min = finiteNumber(normal.min_value);
    const max = finiteNumber(normal.max_value);

    /**
     * A reference range with neither boundary cannot establish normality.
     */
    if (min == null && max == null) {
      return {
        interpretationCode: null,
        label: null,
      };
    }

    if (min != null && value < min) {
      const code =
        normalizeCode(normal.abnormal_interpretation_code) ??
        'VITAL_LOW';

      return {
        interpretationCode: code,
        label: this.labelFor(
          code,
          'low',
          normal.normal_text,
        ),
      };
    }

    if (max != null && value > max) {
      const code =
        normalizeCode(normal.abnormal_interpretation_code) ??
        'VITAL_HIGH';

      return {
        interpretationCode: code,
        label: this.labelFor(
          code,
          'high',
          normal.normal_text,
        ),
      };
    }

    return {
      interpretationCode: 'VITAL_NORMAL',
      label:
        normal.normal_text ??
        'within the applicable reference range',
    };
  }

  // ===========================================================================
  // COMPLETE NUMERIC EXAMINATION INTERPRETATION
  // ===========================================================================

  /**
   * Resolve and interpret a single numeric examination observation.
   *
   * This is the preferred high-level API for vital signs and measurements.
   */
  async interpretMeasurement(
    conceptCode: string,
    value: number,
    context: ExaminationContext,
  ): Promise<Derivation | null> {
    if (!Number.isFinite(value)) {
      return null;
    }

    const months = ageMonths(context);

    const concept = await this.resolveConcept(
      conceptCode,
      months,
      context.sex ?? null,
    );

    if (!concept?.factDefinitionCode) {
      return null;
    }

    /**
     * No knowledge reference range:
     *
     * The observation is still a valid captured fact, but the CPU must not
     * manufacture an interpretation.
     */
    if (!concept.normalRange) {
      return {
        factCode: concept.factDefinitionCode,
        interpretationCode: null,
        label: null,
        observedValue: value,
        unitCode: concept.unit,
        normalRangeCode: null,
        provenance:
          'Observation captured; no applicable knowledge reference range was available.',
        deducedAt: new Date().toISOString(),
      };
    }

    const interpretation = this.deduce(
      value,
      concept.normalRange,
    );

    return {
      factCode: concept.factDefinitionCode,
      interpretationCode:
        interpretation.interpretationCode,
      label: interpretation.label,
      observedValue: value,
      unitCode:
        concept.unit ??
        concept.normalRange.unit ??
        null,
      normalRangeCode:
        concept.normalRange.code,
      normalMin:
        concept.normalRange.min_value,
      normalMax:
        concept.normalRange.max_value,
      provenance:
        `Interpretation derived from ${concept.normalRange.code} for ${concept.factDefinitionCode}.`,
      deducedAt: new Date().toISOString(),
    };
  }

  // ===========================================================================
  // COMPLETE EXAMINATION INTERPRETATION
  // ===========================================================================

  /**
   * Interpret a collection of captured examination observations.
   *
   * Input shape is deliberately generic so the interpreter can sit between
   * multiple examination UIs while producing the same canonical output.
   */
  async interpret(
    findings: Array<{
      findingCode: string;
      numericValue?: number | null;
    }>,
    context: ExaminationContext,
  ): Promise<InterpretResult> {
    const capturedFacts: string[] = [];
    const deductions: Derivation[] = [];

    const months = ageMonths(context);

    for (const finding of findings) {
      if (!finding?.findingCode) {
        continue;
      }

      const concept = await this.resolveConcept(
        finding.findingCode,
        months,
        context.sex ?? null,
      );

      if (!concept) {
        continue;
      }

      if (concept.factDefinitionCode) {
        capturedFacts.push(
          concept.factDefinitionCode,
        );
      }

      const value =
        finding.numericValue != null
          ? finiteNumber(finding.numericValue)
          : null;

      if (value == null) {
        continue;
      }

      const derivation =
        await this.interpretMeasurement(
          finding.findingCode,
          value,
          context,
        );

      if (derivation) {
        deductions.push(derivation);
      }
    }

    return {
      capturedFacts: unique(capturedFacts),
      deductions,
    };
  }

  // ===========================================================================
  // KNOWLEDGE-AWARE LABELING
  // ===========================================================================

  /**
   * Human-readable clinical interpretation.
   *
   * The code remains authoritative; this label exists for clinician-facing UI
   * and documentation.
   *
   * Importantly, related physiological concepts are NOT collapsed:
   *
   *   tachycardia ≠ tachypnoea
   *   hypoxaemia ≠ cyanosis
   *   hypertension ≠ tachycardia
   *
   * The knowledge code therefore takes precedence.
   */
  private labelFor(
    code: string | null,
    fallback: string,
    hint?: string | null,
  ): string {
    const normalized = normalizeCode(code);

    switch (normalized) {
      case 'VITAL_TACHY':
      case 'TACHYCARDIA':
      case 'HEART_RATE_HIGH':
        return 'tachycardia';

      case 'VITAL_TACHYPNEA':
      case 'TACHYPNOEA':
      case 'RESPIRATORY_RATE_HIGH':
        return 'tachypnoea';

      case 'VITAL_BRADYCARDIA':
      case 'BRADYCARDIA':
      case 'HEART_RATE_LOW':
        return 'bradycardia';

      case 'VITAL_BRADYPNOEA':
      case 'BRADYPNOEA':
      case 'RESPIRATORY_RATE_LOW':
        return 'bradypnoea';

      case 'VITAL_HYPOXAEMIA':
      case 'HYPOXAEMIA':
      case 'SPO2_LOW':
        return 'hypoxaemia';

      case 'VITAL_HYPERTHERMIA':
      case 'TEMPERATURE_HIGH':
        return 'elevated temperature';

      case 'VITAL_HYPOTHERMIA':
      case 'TEMPERATURE_LOW':
        return 'hypothermia';

      case 'VITAL_HYPERTENSION':
      case 'BLOOD_PRESSURE_HIGH':
        return 'hypertension';

      case 'VITAL_HYPOTENSION':
      case 'BLOOD_PRESSURE_LOW':
        return 'hypotension';

      case 'VITAL_CRIT_HIGH':
      case 'CRITICAL_HIGH':
        return 'critically high';

      case 'VITAL_CRIT_LOW':
      case 'CRITICAL_LOW':
        return 'critically low';

      case 'VITAL_NORMAL':
        return (
          hint ??
          'within the applicable reference range'
        );

      default:
        return hint ?? fallback;
    }
  }
}

// =============================================================================
// PURE CLINICAL RANGE EVALUATION
// =============================================================================

/**
 * Pure helper useful for tests and deterministic CPU processing.
 *
 * This function performs no database access and makes no diagnosis.
 */
export function evaluateAgainstRange(
  value: number,
  normal: NormalRangeRow,
): {
  status: 'normal' | 'low' | 'high' | 'not_interpretable';
  interpretationCode: string | null;
} {
  if (
    !Number.isFinite(value) ||
    !normal
  ) {
    return {
      status: 'not_interpretable',
      interpretationCode: null,
    };
  }

  const min = finiteNumber(normal.min_value);
  const max = finiteNumber(normal.max_value);

  if (min == null && max == null) {
    return {
      status: 'not_interpretable',
      interpretationCode: null,
    };
  }

  if (min != null && value < min) {
    return {
      status: 'low',
      interpretationCode:
        normalizeCode(
          normal.abnormal_interpretation_code,
        ) ?? 'VITAL_LOW',
    };
  }

  if (max != null && value > max) {
    return {
      status: 'high',
      interpretationCode:
        normalizeCode(
          normal.abnormal_interpretation_code,
        ) ?? 'VITAL_HIGH',
    };
  }

  return {
    status: 'normal',
    interpretationCode: 'VITAL_NORMAL',
  };
}

// =============================================================================
// DEDUPLICATION
// =============================================================================

function unique(values: string[]): string[] {
  return [...new Set(values)];
}