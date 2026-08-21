// =============================================================================
// AMEXAN Clinical CPU — ContradictionEngine
// =============================================================================
// PURPOSE
// -------
// Anti-anchoring / contradiction engine.
//
// The engine examines the LEADING differential diagnosis and deliberately asks:
//
//   "What findings would we reasonably expect if this diagnosis were true,
//    and which of those findings have NOT yet been established?"
//
// It therefore distinguishes:
//
//   1. CONFIRMED SUPPORT
//      The expected feature is present.
//
//   2. TRUE CONTRADICTION / AGAINST EVIDENCE
//      The feature was captured, but its value conflicts with the expected
//      phenotype. This is NOT returned as a probe because it is already
//      evidence against the diagnosis.
//
//   3. UNRESOLVED / UNDOCUMENTED FEATURE
//      The feature has not been captured at all. This becomes a probe that
//      can guide the next history question, examination, investigation, or
//      other appropriate clinical data acquisition.
//
// IMPORTANT CLINICAL SAFETY PRINCIPLES
// ------------------------------------
// - A missing finding is NOT treated as an absent finding.
// - "Not documented" != "negative".
// - The engine does not diagnose.
// - The engine does not calculate probability.
// - The engine does not override clinician judgement.
// - The engine does not manufacture evidence.
// - Probes are ranked by knowledge weight.
// - Only active knowledge contributes.
// - Only positive phenotype features are eligible to become contradiction
//   probes.
// - Already-captured contradictory findings remain evidence AGAINST and are
//   intentionally excluded from the probe list.
// - Duplicate phenotype-feature rows are deduplicated.
// - The result is deterministic.
// - The returned probes identify knowledge gaps, not diagnoses.
//
// This engine is deliberately conservative: absence of documentation must
// trigger information acquisition rather than diagnostic exclusion.
// =============================================================================

import type { Db, Row } from '../db.js';
import { evaluateFeature } from '../matching.js';
import { parseValue } from '../phenotype/PhenotypeEngine.js';
import type {
  ContradictionProbe,
  DifferentialCandidate,
  Fact,
} from '../types.js';

interface FeatureRow extends Row {
  phenotype_code: string;
  feature_code: string;
  operator: string;
  value: unknown;
  weight: number;
}

interface CanonicalFeature {
  phenotypeCode: string;
  featureCode: string;
  operator: string;
  value: unknown;
  weight: number;
}

export class ContradictionEngine {
  constructor(private readonly db: Db) {}

  /**
   * Identify the highest-value undocumented positive features for the leading
   * differential diagnosis.
   *
   * `differentals[0]` is assumed to be the already-ranked leading candidate.
   *
   * The method deliberately does NOT inspect all differentials. Anti-anchoring
   * at this layer is focused on the current leading hypothesis. A separate
   * engine may compare competing hypotheses.
   */
  async probe(
    facts: Fact[],
    differentials: DifferentialCandidate[],
    limit = 5,
  ): Promise<ContradictionProbe[]> {
    if (!Array.isArray(facts)) return [];
    if (!Array.isArray(differentials) || differentials.length === 0) return [];

    const safeLimit = normalizeLimit(limit);
    if (safeLimit === 0) return [];

    const leading = differentials[0];

    if (!leading) return [];

    const phenotypeCodes = uniqueStrings(
      leading.viaPhenotypes
        .map((item) => item.phenotypeCode)
        .filter(Boolean),
    );

    if (phenotypeCodes.length === 0) return [];

    const rawFeatures = await this.loadPositiveFeatures(phenotypeCodes);

    if (rawFeatures.length === 0) return [];

    const features = deduplicateFeatures(rawFeatures);

    const probes: ContradictionProbe[] = [];

    for (const feature of features) {
      const expectedValue = parseValue(feature.value);

      const evaluation = evaluateFeature(facts, {
        featureCode: feature.featureCode,
        operator: feature.operator,
        value: expectedValue,
        weight: feature.weight,
        polarity: 'positive',
      });

      // ---------------------------------------------------------------------
      // CASE 1 — FEATURE CONFIRMED
      // ---------------------------------------------------------------------
      // The expected finding has already been established.
      //
      // Do NOT ask for it again.
      // ---------------------------------------------------------------------
      if (evaluation.matched) {
        continue;
      }

      // ---------------------------------------------------------------------
      // CASE 2 — FEATURE CAPTURED BUT DOES NOT MATCH
      // ---------------------------------------------------------------------
      // This is genuine against-evidence.
      //
      // It must NOT become a "missing information" probe because the CPU
      // already knows something about this feature.
      // ---------------------------------------------------------------------
      if (evaluation.found !== null) {
        continue;
      }

      // ---------------------------------------------------------------------
      // CASE 3 — FEATURE NOT DOCUMENTED
      // ---------------------------------------------------------------------
      // This is the critical anti-anchoring state:
      //
      //      expected != documented
      //
      // We do NOT infer that the feature is absent.
      //
      // Instead, create a probe so the question engine / clinician can obtain
      // the information.
      // ---------------------------------------------------------------------
      probes.push({
        factCode: feature.featureCode,
        expectation: expectationLabel(expectedValue),
        weight: feature.weight,
        reason: buildProbeReason(
          leading.name,
          feature.featureCode,
          expectedValue,
        ),
      });
    }

    return probes
      .sort(compareProbes)
      .slice(0, safeLimit);
  }

  /**
   * Load only POSITIVE phenotype features.
   *
   * Negative phenotype features are useful to the EvidenceEngine, but they
   * should not generate "what should we see?" probes here. Their semantics
   * are different: they represent findings whose presence/absence weighs
   * against a phenotype rather than expected positive findings to acquire.
   */
  private async loadPositiveFeatures(
    phenotypeCodes: string[],
  ): Promise<FeatureRow[]> {
    if (phenotypeCodes.length === 0) return [];

    return this.db.query<FeatureRow>(
      `
        SELECT
          ph.phenotype_code,
          pf.feature_code,
          pf.operator,
          pf.value,
          pf.weight
        FROM knowledge.phenotype_feature pf
        JOIN knowledge.phenotype ph
          ON ph.id = pf.phenotype_id
        WHERE ph.status = 'active'
          AND pf.polarity = 'positive'
          AND ph.phenotype_code = ANY($1::text[])
        ORDER BY
          pf.weight DESC,
          ph.phenotype_code ASC,
          pf.feature_code ASC
      `,
      [phenotypeCodes],
    );
  }
}

/**
 * Remove duplicate phenotype-feature definitions.
 *
 * Multiple seed generations may contain the same logical relationship.
 * We must not create multiple identical probes for the same clinical feature.
 *
 * If the same phenotype + feature + operator + expected value appears more
 * than once, retain the highest knowledge weight.
 */
function deduplicateFeatures(rows: FeatureRow[]): CanonicalFeature[] {
  const byKey = new Map<string, CanonicalFeature>();

  for (const row of rows) {
    const featureCode = normalizeCode(row.feature_code);

    if (!featureCode) continue;

    const operator = normalizeOperator(row.operator);
    const value = parseValue(row.value);
    const weight = normalizeWeight(row.weight);

    const key = [
      normalizeCode(row.phenotype_code),
      featureCode,
      operator,
      stableValueKey(value),
    ].join('|');

    const existing = byKey.get(key);

    if (!existing || weight > existing.weight) {
      byKey.set(key, {
        phenotypeCode: normalizeCode(row.phenotype_code),
        featureCode,
        operator,
        value,
        weight,
      });
    }
  }

  return [...byKey.values()];
}

/**
 * Sort highest-value contradiction probes first.
 *
 * Secondary ordering makes output deterministic when two features have the
 * same knowledge weight.
 */
function compareProbes(
  a: ContradictionProbe,
  b: ContradictionProbe,
): number {
  const weightDifference = Number(b.weight) - Number(a.weight);

  if (weightDifference !== 0) {
    return weightDifference;
  }

  const factDifference = a.factCode.localeCompare(b.factCode);

  if (factDifference !== 0) {
    return factDifference;
  }

  return a.expectation.localeCompare(b.expectation);
}

/**
 * Convert the knowledge representation into a clinician-readable expectation.
 *
 * This is intentionally descriptive rather than interpretive.
 */
function expectationLabel(value: unknown): string {
  if (Array.isArray(value)) {
    const values = value
      .map((item) => expectationLabel(item))
      .filter(Boolean);

    if (values.length === 0) {
      return 'present';
    }

    return `one of ${values.join(' / ')}`;
  }

  if (typeof value === 'boolean') {
    return value ? 'TRUE' : 'FALSE';
  }

  if (typeof value === 'number') {
    return Number.isFinite(value) ? String(value) : 'present';
  }

  if (typeof value === 'string') {
    const normalized = value.trim();

    if (!normalized) {
      return 'present';
    }

    return normalized;
  }

  if (value == null) {
    return 'present';
  }

  return String(value);
}

/**
 * Build a transparent explanation for the clinician.
 *
 * This intentionally says "expected" and "not yet documented".
 * It must NEVER say:
 *
 *   "the patient does not have X"
 *
 * because lack of a captured fact is not equivalent to a negative finding.
 */
function buildProbeReason(
  conditionName: string,
  featureCode: string,
  expectedValue: unknown,
): string {
  const expectation = expectationLabel(expectedValue);

  return (
    `Expected with ${conditionName}: ${featureCode} = ${expectation}; ` +
    `this finding has not yet been documented.`
  );
}

/**
 * Keep limits safe and deterministic.
 */
function normalizeLimit(limit: number): number {
  if (!Number.isFinite(limit)) {
    return 5;
  }

  return Math.max(0, Math.floor(limit));
}

/**
 * Normalize clinical knowledge codes without changing their semantic value.
 */
function normalizeCode(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim().toUpperCase();
}

/**
 * Operators are part of the semantic identity of a phenotype feature.
 */
function normalizeOperator(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim().toLowerCase();
}

/**
 * Knowledge weights must never propagate NaN into ranking.
 */
function normalizeWeight(value: unknown): number {
  const numeric = Number(value);

  if (!Number.isFinite(numeric)) {
    return 0;
  }

  return numeric;
}

/**
 * Produce a deterministic key for expected phenotype values.
 *
 * JSON.stringify is used for structured values so that duplicate definitions
 * with the same semantic value collapse into one probe.
 */
function stableValueKey(value: unknown): string {
  if (value === null) {
    return 'null';
  }

  if (typeof value === 'undefined') {
    return 'undefined';
  }

  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }

  return String(value);
}

/**
 * Remove empty and duplicate strings while preserving first-seen order.
 */
function uniqueStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const value of values) {
    const normalized = value.trim();

    if (!normalized || seen.has(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.push(normalized);
  }

  return result;
}