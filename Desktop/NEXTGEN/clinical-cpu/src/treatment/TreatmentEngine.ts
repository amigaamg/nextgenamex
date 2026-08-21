// =============================================================================
// AMEXAN Clinical CPU — TreatmentEngine
//
// RESPONSIBILITY
// --------------
// Converts the current working differential into governed treatment
// candidates.
//
// The engine does NOT blindly prescribe.
// It produces TreatmentRecommendation objects containing:
//   • eligible medication candidates
//   • therapeutic role
//   • population/indication-specific dose references
//   • jurisdiction-specific overrides
//   • weight-based calculations where governed data permits
//   • verification state
//   • contraindication information
//   • interaction information
//   • safety warnings
//
// CLINICAL KNOWLEDGE IS DATA.
// ---------------------------
// No drug, dose, frequency, duration, route, indication, threshold, or
// contraindication is hard-coded in this engine.
//
// PostgreSQL owns:
//   knowledge.condition
//   knowledge.medication
//   knowledge.medication_condition
//   knowledge.drug_dose_reference
//
// Runtime owns:
//   • selecting candidates for the working diagnosis
//   • resolving the applicable population
//   • resolving jurisdiction
//   • resolving the latest patient weight
//   • calculating governed weight-based quantities
//   • attaching safety information
//   • enforcing verification requirements
//
// The UI renders the resulting projection.
// It does not decide whether a medication is eligible.
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  DifferentialCandidate,
  Fact,
  TreatmentRecommendation,
} from '../types.js';

// =============================================================================
// DATABASE TYPES
// =============================================================================

interface MedicationConditionRow extends Row {
  condition_code: string;
  medication_code: string;
  generic_name: string;
  role: string;
  weight: number;
}

interface MedicationRow extends Row {
  medication_code: string;
  generic_name: string;
  contraindications: unknown;
  interaction_notes: unknown;
}

interface DoseRow extends Row {
  medication_code: string;
  route: string | null;
  dose_expression: string;
  frequency_expression: string | null;
  duration_expression: string | null;
  weight_basis: string | null;
  dose_per_kg_min: number | null;
  dose_per_kg_max: number | null;
  is_verified: boolean;
  population?: string;
  indication_code?: string | null;
  jurisdiction_code?: string | null;
}

// =============================================================================
// INTERNAL RESOLUTION TYPES
// =============================================================================

type Population = 'paediatric' | 'adult';

interface ResolvedWeight {
  valueKg: number;
  factCode: string;
}

interface SafetyResolution {
  contraindications: string[];
  interactions: string[];
}

// =============================================================================
// TREATMENT ENGINE
// =============================================================================

export class TreatmentEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC RESOLUTION API
  // ===========================================================================

  async resolve(
    differentials: DifferentialCandidate[],
    ageYears: number | null,
    facts: Fact[] = [],
    jurisdictionCode?: string | null,
  ): Promise<TreatmentRecommendation[]> {
    // -------------------------------------------------------------------------
    // 1. Treatment is anchored to the working diagnosis.
    // -------------------------------------------------------------------------

    const workingDiagnosis = differentials[0];

    if (!workingDiagnosis?.conditionCode) {
      return [];
    }

    const conditionCode = workingDiagnosis.conditionCode;

    // -------------------------------------------------------------------------
    // 2. Determine the patient population.
    //
    // A null age cannot safely be classified as adult.
    // Therefore a null age produces no population-specific dose lookup.
    // -------------------------------------------------------------------------

    const population = resolvePopulation(ageYears);

    // -------------------------------------------------------------------------
    // 3. Load candidate medications attached to the working diagnosis.
    // -------------------------------------------------------------------------

    const candidates =
      await this.loadMedicationCandidates(conditionCode);

    if (candidates.length === 0) {
      return [];
    }

    const medicationCodes = unique(
      candidates.map(
        (candidate) => candidate.medication_code,
      ),
    );

    // -------------------------------------------------------------------------
    // 4. Load medication metadata and governed dose references in parallel.
    // -------------------------------------------------------------------------

    const [medications, doses] = await Promise.all([
      this.loadMedications(medicationCodes),
      population == null
        ? Promise.resolve([])
        : this.loadDoseReferences(
            medicationCodes,
            population,
            conditionCode,
            jurisdictionCode,
          ),
    ]);

    // -------------------------------------------------------------------------
    // 5. Resolve latest patient weight.
    // -------------------------------------------------------------------------

    const latestWeight = latestWeightKg(facts);

    // -------------------------------------------------------------------------
    // 6. Index medication and dose rows.
    // -------------------------------------------------------------------------

    const medicationByCode =
      new Map<string, MedicationRow>();

    for (const medication of medications) {
      medicationByCode.set(
        medication.medication_code,
        medication,
      );
    }

    const doseByMedication =
      selectBestDosePerMedication(
        doses,
        jurisdictionCode,
      );

    // -------------------------------------------------------------------------
    // 7. Build the clinical treatment projection.
    // -------------------------------------------------------------------------

    return candidates.map((candidate) => {
      const medication =
        medicationByCode.get(
          candidate.medication_code,
        ) ?? null;

      const dose =
        doseByMedication.get(
          candidate.medication_code,
        ) ?? null;

      return buildTreatmentRecommendation(
        candidate,
        medication,
        dose,
        latestWeight,
        population,
        jurisdictionCode ?? null,
      );
    });
  }

  // ===========================================================================
  // MEDICATION CANDIDATES
  // ===========================================================================

  private async loadMedicationCandidates(
    conditionCode: string,
  ): Promise<MedicationConditionRow[]> {
    return this.db.query<MedicationConditionRow>(
      `
        SELECT
          c.condition_code,
          m.medication_code,
          m.generic_name,
          mc.role,
          mc.weight
        FROM knowledge.medication_condition mc
        JOIN knowledge.condition c
          ON c.id = mc.condition_id
        JOIN knowledge.medication m
          ON m.id = mc.medication_id
        WHERE c.condition_code = $1
        ORDER BY
          mc.weight DESC,
          m.generic_name ASC
      `,
      [conditionCode],
    );
  }

  // ===========================================================================
  // MEDICATION METADATA
  // ===========================================================================

  private async loadMedications(
    medicationCodes: string[],
  ): Promise<MedicationRow[]> {
    if (medicationCodes.length === 0) {
      return [];
    }

    return this.db.query<MedicationRow>(
      `
        SELECT
          medication_code,
          generic_name,
          contraindications,
          interaction_notes
        FROM knowledge.medication
        WHERE medication_code = ANY($1::text[])
      `,
      [medicationCodes],
    );
  }

  // ===========================================================================
  // DOSE REFERENCES
  // ===========================================================================

  private async loadDoseReferences(
    medicationCodes: string[],
    population: Population,
    indicationCode: string,
    jurisdictionCode?: string | null,
  ): Promise<DoseRow[]> {
    if (medicationCodes.length === 0) {
      return [];
    }

    const jurisdiction =
      normalizeJurisdiction(jurisdictionCode);

    // -------------------------------------------------------------------------
    // Jurisdiction resolution is deliberately performed in SQL.
    //
    // When a jurisdiction is supplied:
    //
    //   local jurisdiction rows
    //          ↓
    //   global fallback
    //
    // Local rows rank above global rows.
    //
    // When no jurisdiction is supplied:
    //   only JUR-GLOBAL can safely be used.
    //
    // This prevents an arbitrary country-specific reference from being selected.
    // -------------------------------------------------------------------------

    if (jurisdiction) {
      return this.db.query<DoseRow>(
        `
          SELECT
            m.medication_code,
            ddr.route,
            ddr.dose_expression,
            ddr.frequency_expression,
            ddr.duration_expression,
            ddr.weight_basis,
            ddr.dose_per_kg_min,
            ddr.dose_per_kg_max,
            ddr.is_verified,
            ddr.population,
            ddr.indication_code,
            ddr.jurisdiction_code
          FROM knowledge.drug_dose_reference ddr
          JOIN knowledge.medication m
            ON m.id = ddr.medication_id
          WHERE m.medication_code = ANY($1::text[])
            AND ddr.population = $2
            AND ddr.indication_code = $3
            AND ddr.jurisdiction_code IN ($4, 'JUR-GLOBAL')
          ORDER BY
            m.medication_code,
            CASE
              WHEN ddr.jurisdiction_code = $4 THEN 0
              ELSE 1
            END,
            ddr.is_verified DESC,
            ddr.dose_per_kg_min DESC NULLS LAST
        `,
        [
          medicationCodes,
          population,
          indicationCode,
          jurisdiction,
        ],
      );
    }

    return this.db.query<DoseRow>(
      `
        SELECT
          m.medication_code,
          ddr.route,
          ddr.dose_expression,
          ddr.frequency_expression,
          ddr.duration_expression,
          ddr.weight_basis,
          ddr.dose_per_kg_min,
          ddr.dose_per_kg_max,
          ddr.is_verified,
          ddr.population,
          ddr.indication_code,
          ddr.jurisdiction_code
        FROM knowledge.drug_dose_reference ddr
        JOIN knowledge.medication m
          ON m.id = ddr.medication_id
        WHERE m.medication_code = ANY($1::text[])
          AND ddr.population = $2
          AND ddr.indication_code = $3
          AND ddr.jurisdiction_code = 'JUR-GLOBAL'
        ORDER BY
          m.medication_code,
          ddr.is_verified DESC,
          ddr.dose_per_kg_min DESC NULLS LAST
      `,
      [
        medicationCodes,
        population,
        indicationCode,
      ],
    );
  }
}

// =============================================================================
// TREATMENT RECOMMENDATION BUILDER
// =============================================================================

function buildTreatmentRecommendation(
  candidate: MedicationConditionRow,
  medication: MedicationRow | null,
  dose: DoseRow | null,
  weight: ResolvedWeight | null,
  population: Population | null,
  jurisdictionCode: string | null,
): TreatmentRecommendation {
  const safety = resolveSafety(medication);

  const safetyNotes: string[] = [];

  // ---------------------------------------------------------------------------
  // Medication metadata safety.
  // ---------------------------------------------------------------------------

  for (const contraindication of safety.contraindications) {
    safetyNotes.push(
      `Contraindications: ${contraindication}`,
    );
  }

  for (const interaction of safety.interactions) {
    safetyNotes.push(
      `Interactions: ${interaction}`,
    );
  }

  // ---------------------------------------------------------------------------
  // Population resolution.
  // ---------------------------------------------------------------------------

  if (!population) {
    safetyNotes.push(
      'Patient age is unavailable; a population-specific dose reference could not be selected.',
    );
  }

  // ---------------------------------------------------------------------------
  // Dose resolution.
  // ---------------------------------------------------------------------------

  if (!dose) {
    safetyNotes.push(
      'No applicable governed dose reference was found for this indication and patient population.',
    );
  }

  // ---------------------------------------------------------------------------
  // Verification.
  // ---------------------------------------------------------------------------

  if (dose && !dose.is_verified) {
    safetyNotes.push(
      'Dose expression requires independent clinical verification before prescribing.',
    );
  }

  // ---------------------------------------------------------------------------
  // Weight-based dose calculation.
  // ---------------------------------------------------------------------------

  const computedDose =
    computeWeightBasedDose(
      dose,
      weight,
      safetyNotes,
    );

  // ---------------------------------------------------------------------------
  // Explicit unresolved dose.
  //
  // The CPU must never turn a missing dose into an apparently valid order.
  // ---------------------------------------------------------------------------

  const doseExpression =
    dose?.dose_expression?.trim()
      ? dose.dose_expression
      : 'REVIEW REQUIRED';

  const verified =
    dose?.is_verified === true;

  return {
    medicationCode: candidate.medication_code,
    genericName:
      medication?.generic_name ??
      candidate.generic_name,
    role: candidate.role,
    route: dose?.route ?? null,
    doseExpression,
    computedDose,
    frequency:
      dose?.frequency_expression ?? null,
    duration:
      dose?.duration_expression ?? null,
    verified,
    contraindicated: false,
    safetyNotes,
  };
}

// =============================================================================
// WEIGHT-BASED DOSE CALCULATION
// =============================================================================
//
// The calculation is generic.
//
// The clinical dose range comes entirely from:
//
//   dose_per_kg_min
//   dose_per_kg_max
//   weight_basis
//
// No medication-specific arithmetic exists here.
//
// =============================================================================

function computeWeightBasedDose(
  dose: DoseRow | null,
  weight: ResolvedWeight | null,
  safetyNotes: string[],
): string | null {
  if (!dose) {
    return null;
  }

  if (dose.weight_basis !== 'mg_per_kg') {
    return null;
  }

  if (!weight) {
    safetyNotes.push(
      'Weight-based dose cannot be calculated because no current body weight is available.',
    );
    return null;
  }

  if (
    dose.dose_per_kg_min == null ||
    dose.dose_per_kg_max == null
  ) {
    safetyNotes.push(
      'Weight-based dose reference is incomplete and requires clinical verification.',
    );
    return null;
  }

  const minimum =
    Number(dose.dose_per_kg_min);

  const maximum =
    Number(dose.dose_per_kg_max);

  if (
    !Number.isFinite(minimum) ||
    !Number.isFinite(maximum) ||
    minimum < 0 ||
    maximum < 0 ||
    minimum > maximum
  ) {
    safetyNotes.push(
      'Weight-based dose reference contains invalid dose bounds and requires clinical verification.',
    );
    return null;
  }

  const lower =
    weight.valueKg * minimum;

  const upper =
    weight.valueKg * maximum;

  if (
    !Number.isFinite(lower) ||
    !Number.isFinite(upper)
  ) {
    safetyNotes.push(
      'Weight-based dose calculation could not be safely completed.',
    );
    return null;
  }

  const roundedLower =
    roundDose(lower);

  const roundedUpper =
    roundDose(upper);

  const computed =
    roundedLower === roundedUpper
      ? `${roundedLower} mg per dose`
      : `${roundedLower}-${roundedUpper} mg per dose`;

  safetyNotes.push(
    `Weight-based calculation: ${weight.valueKg} kg × ${minimum}-${maximum} mg/kg = ${computed}.`,
  );

  return computed;
}

// =============================================================================
// LATEST BODY WEIGHT
// =============================================================================
//
// Facts are append-only.
//
// The most recent valid BODY_WEIGHT_KG observation is authoritative.
//
// Invalid/empty values are ignored rather than converted into zero.
//
// =============================================================================

export function latestWeightKg(
  facts: Fact[],
): ResolvedWeight | null {
  for (
    let index = facts.length - 1;
    index >= 0;
    index -= 1
  ) {
    const fact = facts[index];

    if (
      !fact ||
      fact.factCode !== 'BODY_WEIGHT_KG'
    ) {
      continue;
    }

    if (
      !Array.isArray(fact.values) ||
      fact.values.length === 0
    ) {
      continue;
    }

    for (
      let valueIndex = fact.values.length - 1;
      valueIndex >= 0;
      valueIndex -= 1
    ) {
      const value = fact.values[valueIndex];

      if (
        !value ||
        value.numeric == null
      ) {
        continue;
      }

      const weight =
        Number(value.numeric);

      if (
        !Number.isFinite(weight) ||
        weight <= 0
      ) {
        continue;
      }

      return {
        valueKg: weight,
        factCode: fact.factCode,
      };
    }
  }

  return null;
}

// =============================================================================
// POPULATION
// =============================================================================

function resolvePopulation(
  ageYears: number | null,
): Population | null {
  if (
    ageYears == null ||
    !Number.isFinite(ageYears) ||
    ageYears < 0
  ) {
    return null;
  }

  return ageYears < 18
    ? 'paediatric'
    : 'adult';
}

// =============================================================================
// SAFETY METADATA
// =============================================================================

function resolveSafety(
  medication: MedicationRow | null,
): SafetyResolution {
  if (!medication) {
    return {
      contraindications: [],
      interactions: [],
    };
  }

  return {
    contraindications:
      normalizeSafetyList(
        medication.contraindications,
      ),
    interactions:
      normalizeSafetyList(
        medication.interaction_notes,
      ),
  };
}

// =============================================================================
// SAFETY LIST NORMALIZATION
// =============================================================================
//
// PostgreSQL JSON/JSONB may arrive as:
//
//   string[]
//   string
//   object[]
//   null
//
// The engine converts these into readable strings without assuming that
// arbitrary object structure is clinically meaningful.
//
// =============================================================================

function normalizeSafetyList(
  value: unknown,
): string[] {
  if (value == null) {
    return [];
  }

  if (Array.isArray(value)) {
    return value
      .map(normalizeSafetyEntry)
      .filter(
        (entry): entry is string =>
          entry != null,
      );
  }

  const normalized =
    normalizeSafetyEntry(value);

  return normalized
    ? [normalized]
    : [];
}

function normalizeSafetyEntry(
  value: unknown,
): string | null {
  if (typeof value === 'string') {
    const normalized = value.trim();

    return normalized.length > 0
      ? normalized
      : null;
  }

  if (
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return String(value);
  }

  if (
    typeof value === 'object' &&
    value !== null
  ) {
    try {
      return JSON.stringify(value);
    } catch {
      return null;
    }
  }

  return null;
}

// =============================================================================
// DOSE SELECTION
// =============================================================================
//
// SQL ordering places the most appropriate row first:
//
//   1. jurisdiction-specific over global
//   2. verified over unverified
//   3. higher dose lower-bound reference where otherwise equivalent
//
// First row per medication therefore becomes the selected reference.
//
// =============================================================================

function selectBestDosePerMedication(
  doses: DoseRow[],
  jurisdictionCode?: string | null,
): Map<string, DoseRow> {
  const selected =
    new Map<string, DoseRow>();

  const jurisdiction =
    normalizeJurisdiction(
      jurisdictionCode,
    );

  for (const dose of doses) {
    if (
      !dose.medication_code ||
      selected.has(dose.medication_code)
    ) {
      continue;
    }

    // Defensive runtime guard.
    //
    // Even though SQL is expected to filter this, the CPU does not trust an
    // externally malformed row.
    if (
      jurisdiction &&
      dose.jurisdiction_code &&
      dose.jurisdiction_code !== jurisdiction &&
      dose.jurisdiction_code !== 'JUR-GLOBAL'
    ) {
      continue;
    }

    if (
      !jurisdiction &&
      dose.jurisdiction_code &&
      dose.jurisdiction_code !== 'JUR-GLOBAL'
    ) {
      continue;
    }

    selected.set(
      dose.medication_code,
      dose,
    );
  }

  return selected;
}

// =============================================================================
// JURISDICTION NORMALIZATION
// =============================================================================

function normalizeJurisdiction(
  jurisdictionCode?: string | null,
): string | null {
  if (
    typeof jurisdictionCode !== 'string'
  ) {
    return null;
  }

  const normalized =
    jurisdictionCode.trim();

  return normalized.length > 0
    ? normalized
    : null;
}

// =============================================================================
// DOSE ROUNDING
// =============================================================================
//
// Keeps computed values readable without changing the underlying governed
// dose range.
//
// The engine does not invent tablet strengths, maximum doses, or formulation
// rules. Those remain outside this generic arithmetic layer.
//
// =============================================================================

function roundDose(
  value: number,
): number {
  if (!Number.isFinite(value)) {
    return 0;
  }

  if (value >= 100) {
    return Math.round(value);
  }

  if (value >= 10) {
    return Math.round(value * 10) / 10;
  }

  return Math.round(value * 100) / 100;
}

// =============================================================================
// UNIQUE VALUES
// =============================================================================

function unique(
  values: string[],
): string[] {
  return Array.from(
    new Set(
      values
        .filter(
          (value): value is string =>
            typeof value === 'string',
        )
        .map((value) => value.trim())
        .filter(Boolean),
    ),
  );
}