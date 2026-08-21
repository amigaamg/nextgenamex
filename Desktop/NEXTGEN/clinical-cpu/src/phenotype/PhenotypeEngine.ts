// =============================================================================
// AMEXAN Clinical CPU — PhenotypeEngine
// =============================================================================
//
// PURPOSE
// -------
// The PhenotypeEngine is the first major clinical-intelligence layer between
// captured patient facts and higher-order clinical hypotheses.
//
// It does NOT diagnose.
//
// It computes:
//
//   PATIENT FACTS
//        ↓
//   FEATURE EVALUATION
//        ↓
//   POSITIVE SUPPORT
//   NEGATIVE / CONTRADICTORY SUPPORT
//   MISSING / UNKNOWN FEATURES
//        ↓
//   PHENOTYPE COMPATIBILITY
//        ↓
//   DIFFERENTIAL / MECHANISM / INVESTIGATION ENGINES
//
// A phenotype is a reusable clinical pattern defined in PostgreSQL:
//
//   knowledge.phenotype
//   knowledge.phenotype_feature
//
// Each feature may represent:
//
//   - presence of a symptom
//   - absence of a symptom
//   - examination finding
//   - laboratory abnormality
//   - imaging finding
//   - vital-sign abnormality
//   - demographic/contextual feature
//   - numeric threshold
//   - categorical value
//   - boolean value
//
// IMPORTANT CLINICAL PRINCIPLE
// ----------------------------
// "Not documented" MUST NOT automatically mean "absent".
//
// Therefore:
//
//   PRESENT  ≠  ABSENT
//   ABSENT   ≠  UNKNOWN
//   UNKNOWN  ≠  NEGATIVE
//
// The matching layer must preserve this distinction.
//
// The engine also preserves provenance so downstream systems can explain:
//
//   "Why does AMEXAN consider this phenotype compatible?"
//
// Example:
//
//   Fever + cough + tachypnea + focal crackles
//              ↓
//        respiratory phenotype
//              ↓
//        bacterial-infective phenotype
//              ↓
//       pneumonia candidates
//
// This engine does not make the final disease diagnosis.
// =============================================================================

import type { Db, Row } from '../db.js';
import { contribution, evaluateFeature } from '../matching.js';
import type { Fact, PhenotypeScore } from '../types.js';

// =============================================================================
// DATABASE ROWS
// =============================================================================

interface PhenotypeRow extends Row {
  phenotype_code: string;
  canonical_name: string;

  // Optional metadata. These fields may be absent from older schemas.
  description?: string | null;
  phenotype_class?: string | null;
  status: string;
}

interface FeatureRow extends Row {
  phenotype_code: string;

  feature_code: string;

  // Supported operators should correspond to the AMEXAN matching contract.
  //
  // Examples:
  //   exists
  //   equals
  //   not_equals
  //   gt
  //   gte
  //   lt
  //   lte
  //   in
  //   not_in
  //   contains
  //   starts_with
  //   between
  //
  operator: string;

  // PostgreSQL JSONB may arrive as:
  //   object
  //   number
  //   boolean
  //   string
  // depending on the driver/configuration.
  value: unknown;

  weight: number;

  // positive = evidence supporting the phenotype
  // negative = evidence contradicting the phenotype
  polarity: string;

  // Optional feature metadata.
  requiredness?: string | null;
  description?: string | null;
  minimum_duration?: string | null;
  maximum_duration?: string | null;
}

// =============================================================================
// INTERNAL EVALUATION TYPES
// =============================================================================

type FeatureMatchState =
  | 'present'
  | 'absent'
  | 'unknown'
  | 'conflicting';

interface FeatureEvaluation {
  featureCode: string;
  operator: string;
  expectedValue: unknown;
  weight: number;
  polarity: string;

  state: FeatureMatchState;

  matched: boolean;

  // Contribution after polarity is applied.
  contribution: number;

  // Raw evaluator output is retained for explainability.
  evaluatorResult: unknown;

  rationale: string | null;
}

interface PhenotypeEvaluation {
  phenotypeCode: string;
  name: string;

  positiveSupport: number;
  negativeSupport: number;

  positiveMax: number;
  negativeMax: number;

  requiredSatisfied: number;
  requiredTotal: number;

  matchedFeatures: FeatureEvaluation[];
  contradictoryFeatures: FeatureEvaluation[];
  unknownFeatures: FeatureEvaluation[];

  compatibility: number;

  confidenceClass:
    | 'none'
    | 'weak'
    | 'moderate'
    | 'strong'
    | 'very_strong';
}

// =============================================================================
// PUBLIC EXPLANATION MODEL
// =============================================================================

export interface PhenotypeEvidence {
  featureCode: string;
  state: FeatureMatchState;
  polarity: string;
  weight: number;
  contribution: number;
  expectedValue: unknown;
  rationale: string | null;
}

export interface PhenotypeExplanation {
  phenotypeCode: string;
  name: string;

  compatibility: number;

  positiveSupport: number;
  negativeSupport: number;

  supportingEvidence: PhenotypeEvidence[];
  contradictoryEvidence: PhenotypeEvidence[];
  unknownEvidence: PhenotypeEvidence[];

  requiredFeaturesSatisfied: number;
  requiredFeaturesTotal: number;

  confidenceClass:
    | 'none'
    | 'weak'
    | 'moderate'
    | 'strong'
    | 'very_strong';
}

// =============================================================================
// ENGINE
// =============================================================================

export class PhenotypeEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // MAIN ENTRY POINT
  // ===========================================================================
  //
  // Scores every active phenotype against the current patient facts.
  //
  // The engine deliberately does not receive a diagnosis or disease list.
  // Phenotypes remain reusable clinical building blocks.
  //
  // ===========================================================================

  async score(facts: Fact[]): Promise<PhenotypeScore[]> {
    if (!facts || facts.length === 0) {
      return this.emptyScores();
    }

    const [phenotypes, features] = await Promise.all([
      this.loadPhenotypes(),
      this.loadFeatures(),
    ]);

    if (phenotypes.length === 0) {
      return [];
    }

    const featuresByPhenotype = this.groupFeatures(features);

    const results: PhenotypeScore[] = [];

    for (const phenotype of phenotypes) {
      const phenotypeFeatures =
        featuresByPhenotype.get(phenotype.phenotype_code) ?? [];

      const evaluation = this.evaluatePhenotype(
        phenotype,
        phenotypeFeatures,
        facts,
      );

      results.push(this.toPhenotypeScore(evaluation));
    }

    return this.rankResults(results);
  }

  // ===========================================================================
  // EXPLAIN ONE PHENOTYPE
  // ===========================================================================
  //
  // This is important for clinical transparency.
  //
  // Example:
  //
  //   "Respiratory distress"
  //
  //       + RR 68
  //       + nasal flaring
  //       + chest indrawing
  //       + SpO2 84%
  //
  //       - no evidence against
  //
  //       compatibility = 0.91
  //
  // The UI / audit layer can consume this explanation.
  //
  // ===========================================================================

  async explain(
    phenotypeCode: string,
    facts: Fact[],
  ): Promise<PhenotypeExplanation | null> {
    const [phenotype, features] = await Promise.all([
      this.db.queryOne<PhenotypeRow>(
        `
        SELECT
          phenotype_code,
          canonical_name,
          description,
          phenotype_class,
          status
        FROM knowledge.phenotype
        WHERE phenotype_code = $1
          AND status = 'active'
        LIMIT 1
        `,
        [phenotypeCode],
      ),

      this.db.query<FeatureRow>(
        `
        SELECT
          ph.phenotype_code,
          pf.feature_code,
          pf.operator,
          pf.value,
          pf.weight,
          pf.polarity,
          pf.requiredness,
          pf.description,
          pf.minimum_duration,
          pf.maximum_duration
        FROM knowledge.phenotype_feature pf
        JOIN knowledge.phenotype ph
          ON ph.id = pf.phenotype_id
        WHERE ph.phenotype_code = $1
          AND ph.status = 'active'
        ORDER BY
          CASE WHEN pf.requiredness = 'required' THEN 1 ELSE 0 END DESC,
          ABS(pf.weight) DESC
        `,
        [phenotypeCode],
      ),
    ]);

    if (!phenotype) {
      return null;
    }

    const evaluation = this.evaluatePhenotype(
      phenotype,
      features,
      facts,
    );

    return {
      phenotypeCode: evaluation.phenotypeCode,
      name: evaluation.name,
      compatibility: evaluation.compatibility,
      positiveSupport: evaluation.positiveSupport,
      negativeSupport: evaluation.negativeSupport,
      supportingEvidence: evaluation.matchedFeatures.map(
        this.toEvidence,
      ),
      contradictoryEvidence: evaluation.contradictoryFeatures.map(
        this.toEvidence,
      ),
      unknownEvidence: evaluation.unknownFeatures.map(
        this.toEvidence,
      ),
      requiredFeaturesSatisfied: evaluation.requiredSatisfied,
      requiredFeaturesTotal: evaluation.requiredTotal,
      confidenceClass: evaluation.confidenceClass,
    };
  }

  // ===========================================================================
  // LOAD PHENOTYPES
  // ===========================================================================

  private async loadPhenotypes(): Promise<PhenotypeRow[]> {
    return this.db.query<PhenotypeRow>(
      `
      SELECT
        phenotype_code,
        canonical_name,
        description,
        phenotype_class,
        status
      FROM knowledge.phenotype
      WHERE status = 'active'
      ORDER BY phenotype_code
      `,
    );
  }

  // ===========================================================================
  // LOAD FEATURES
  // ===========================================================================

  private async loadFeatures(): Promise<FeatureRow[]> {
    return this.db.query<FeatureRow>(
      `
      SELECT
        ph.phenotype_code,
        pf.feature_code,
        pf.operator,
        pf.value,
        pf.weight,
        pf.polarity,
        pf.requiredness,
        pf.description,
        pf.minimum_duration,
        pf.maximum_duration
      FROM knowledge.phenotype_feature pf
      JOIN knowledge.phenotype ph
        ON ph.id = pf.phenotype_id
      WHERE ph.status = 'active'
      ORDER BY
        ph.phenotype_code,
        CASE WHEN pf.requiredness = 'required' THEN 1 ELSE 0 END DESC,
        ABS(pf.weight) DESC
      `,
    );
  }

  // ===========================================================================
  // GROUP FEATURES
  // ===========================================================================

  private groupFeatures(
    features: FeatureRow[],
  ): Map<string, FeatureRow[]> {
    const result = new Map<string, FeatureRow[]>();

    for (const feature of features) {
      const existing =
        result.get(feature.phenotype_code) ?? [];

      existing.push(feature);
      result.set(feature.phenotype_code, existing);
    }

    return result;
  }

  // ===========================================================================
  // PHENOTYPE EVALUATION
  // ===========================================================================

  private evaluatePhenotype(
    phenotype: PhenotypeRow,
    features: FeatureRow[],
    facts: Fact[],
  ): PhenotypeEvaluation {
    let positiveSupport = 0;
    let negativeSupport = 0;

    let positiveMax = 0;
    let negativeMax = 0;

    let requiredSatisfied = 0;
    let requiredTotal = 0;

    const matchedFeatures: FeatureEvaluation[] = [];
    const contradictoryFeatures: FeatureEvaluation[] = [];
    const unknownFeatures: FeatureEvaluation[] = [];

    for (const feature of features) {
      const weight = Math.abs(Number(feature.weight) || 0);
      const polarity = normalizePolarity(feature.polarity);

      if (polarity === 'positive') {
        positiveMax += weight;
      } else {
        negativeMax += weight;
      }

      if (feature.requiredness === 'required') {
        requiredTotal += 1;
      }

      const expectedValue = parseValue(feature.value);

      const evaluatorResult = evaluateFeature(
        facts,
        {
          featureCode: feature.feature_code,
          operator: feature.operator,
          value: expectedValue,
          weight,
          polarity,
        },
      );

      const matched = Boolean(
        (evaluatorResult as { matched?: unknown })?.matched,
      );

      const state = this.determineMatchState(
        matched,
        facts,
        feature,
      );

      const contributionValue = this.safeContribution(
        feature,
        evaluatorResult,
      );

      const evaluation: FeatureEvaluation = {
        featureCode: feature.feature_code,
        operator: feature.operator,
        expectedValue,
        weight,
        polarity,
        state,
        matched,
        contribution: contributionValue,
        evaluatorResult,
        rationale: feature.description ?? null,
      };

      // -----------------------------------------------------------------------
      // REQUIRED FEATURES
      // -----------------------------------------------------------------------

      if (feature.requiredness === 'required' && state === 'present') {
        requiredSatisfied += 1;
      }

      // -----------------------------------------------------------------------
      // EVIDENCE ACCOUNTING
      // -----------------------------------------------------------------------

      if (state === 'unknown') {
        unknownFeatures.push(evaluation);
        continue;
      }

      if (polarity === 'positive') {
        if (state === 'present') {
          positiveSupport += contributionValue;
          matchedFeatures.push(evaluation);
        }

        if (state === 'absent') {
          // An explicit absence of a positive feature is contradiction.
          negativeSupport += weight;
          contradictoryFeatures.push(evaluation);
        }

        continue;
      }

      // Negative-polarity feature:
      //
      // Example:
      //   "no wheeze" supports phenotype
      //
      // Therefore an observed absence can support the phenotype.
      if (polarity === 'negative') {
        if (state === 'present') {
          positiveSupport += contributionValue;
          matchedFeatures.push(evaluation);
        } else if (state === 'absent') {
          negativeSupport += weight;
          contradictoryFeatures.push(evaluation);
        }
      }
    }

    const compatibility = this.calculateCompatibility({
      positiveSupport,
      negativeSupport,
      positiveMax,
      requiredSatisfied,
      requiredTotal,
    });

    return {
      phenotypeCode: phenotype.phenotype_code,
      name: phenotype.canonical_name,

      positiveSupport: round(positiveSupport),
      negativeSupport: round(negativeSupport),

      positiveMax: round(positiveMax),
      negativeMax: round(negativeMax),

      requiredSatisfied,
      requiredTotal,

      matchedFeatures,
      contradictoryFeatures,
      unknownFeatures,

      compatibility,

      confidenceClass: confidenceClass(compatibility),
    };
  }

  // ===========================================================================
  // MATCH STATE
  // ===========================================================================
  //
  // The matching layer tells us whether a feature matched. However, clinical
  // intelligence needs to distinguish:
  //
  //   PRESENT
  //   ABSENT
  //   UNKNOWN
  //
  // We therefore inspect the patient's facts as well.
  //
  // ===========================================================================

  private determineMatchState(
    matched: boolean,
    facts: Fact[],
    feature: FeatureRow,
  ): FeatureMatchState {
    if (matched) {
      return 'present';
    }

    const relevantFacts = facts.filter(
      (fact) => fact.factCode === feature.feature_code,
    );

    if (relevantFacts.length === 0) {
      return 'unknown';
    }

    const hasExplicitNegative = relevantFacts.some(
      (fact) => fact.values.some((value) =>
        value.boolean === false ||
        isNegativeText(value.text),
      ),
    );

    if (hasExplicitNegative) {
      return 'absent';
    }

    const hasPositive = relevantFacts.some(
      (fact) => fact.values.some((value) =>
        value.boolean === true ||
        value.numeric != null ||
        (value.text != null && !isNegativeText(value.text)),
      ),
    );

    if (hasPositive) {
      return 'absent';
    }

    return 'unknown';
  }

  // ===========================================================================
  // CONTRIBUTION SAFETY
  // ===========================================================================

  private safeContribution(
    feature: FeatureRow,
    evaluatorResult: unknown,
  ): number {
    try {
      const result = contribution(
        {
          featureCode: feature.feature_code,
          operator: feature.operator,
          value: parseValue(feature.value),
          weight: Math.abs(Number(feature.weight) || 0),
          polarity: normalizePolarity(feature.polarity),
        },
        evaluatorResult as Parameters<typeof contribution>[1],
      );

      if (!Number.isFinite(result)) {
        return 0;
      }

      return Math.abs(Number(result));
    } catch {
      return 0;
    }
  }

  // ===========================================================================
  // COMPATIBILITY CALCULATION
  // ===========================================================================
  //
  // A simple sum is insufficient clinically because:
  //
  //   1. A phenotype with 20 weak features should not automatically beat one
  //      with several strong features.
  //
  //   2. Contradictory evidence must reduce compatibility.
  //
  //   3. Missing data should not be treated as negative evidence.
  //
  //   4. Required features can act as an important gate.
  //
  // The resulting score is therefore bounded to [0,1].
  //
  // ===========================================================================

  private calculateCompatibility(input: {
    positiveSupport: number;
    negativeSupport: number;
    positiveMax: number;
    requiredSatisfied: number;
    requiredTotal: number;
  }): number {
    const {
      positiveSupport,
      negativeSupport,
      positiveMax,
      requiredSatisfied,
      requiredTotal,
    } = input;

    if (positiveMax <= 0) {
      return 0;
    }

    const positiveRatio = clamp01(
      positiveSupport / positiveMax,
    );

    const contradictionPenalty =
      negativeSupport <= 0
        ? 0
        : clamp01(
            negativeSupport /
              Math.max(positiveMax, 1),
          );

    let compatibility =
      positiveRatio *
      (1 - contradictionPenalty);

    // Required features are not treated as absolute diagnostic criteria.
    // They reduce compatibility when explicitly absent, while unknown required
    // features do not create a negative penalty.
    if (requiredTotal > 0) {
      const requiredRatio =
        requiredSatisfied / requiredTotal;

      compatibility *=
        0.65 + 0.35 * requiredRatio;
    }

    return round(clamp01(compatibility));
  }

  // ===========================================================================
  // CONVERT TO PUBLIC SCORE
  // ===========================================================================

  private toPhenotypeScore(
    evaluation: PhenotypeEvaluation,
  ): PhenotypeScore {
    return {
      phenotypeCode: evaluation.phenotypeCode,
      name: evaluation.name,

      score: round(
        evaluation.positiveSupport -
          evaluation.negativeSupport,
      ),

      maxScore: evaluation.positiveMax,

      compatibility: evaluation.compatibility,
    };
  }

  // ===========================================================================
  // EMPTY RESULT
  // ===========================================================================

  private emptyScores(): PhenotypeScore[] {
    return [];
  }

  // ===========================================================================
  // RANKING
  // ===========================================================================

  private rankResults(
    scores: PhenotypeScore[],
  ): PhenotypeScore[] {
    return scores
      .filter(
        (score) =>
          score.maxScore > 0 ||
          score.compatibility > 0,
      )
      .sort((a, b) => {
        if (b.compatibility !== a.compatibility) {
          return b.compatibility - a.compatibility;
        }

        return b.score - a.score;
      });
  }

  // ===========================================================================
  // EVIDENCE CONVERTER
  // ===========================================================================

  private readonly toEvidence = (
    item: FeatureEvaluation,
  ): PhenotypeEvidence => ({
    featureCode: item.featureCode,
    state: item.state,
    polarity: item.polarity,
    weight: item.weight,
    contribution: item.contribution,
    expectedValue: item.expectedValue,
    rationale: item.rationale,
  });
}

// =============================================================================
// VALUE PARSER
// =============================================================================
//
// PostgreSQL JSONB may already be decoded. If it arrives as a string:
//
//   '{"min": 38}' → object
//   'true'        → boolean
//   '5'           → number
//   '"productive"' → string
//
// If parsing fails, preserve the original string.
//
// =============================================================================

export function parseValue(value: unknown): unknown {
  if (value == null) {
    return null;
  }

  if (typeof value !== 'string') {
    return value;
  }

  const trimmed = value.trim();

  if (!trimmed) {
    return value;
  }

  try {
    return JSON.parse(trimmed);
  } catch {
    return value;
  }
}

// =============================================================================
// POLARITY NORMALIZATION
// =============================================================================

function normalizePolarity(
  polarity: string | null | undefined,
): 'positive' | 'negative' {
  const normalized =
    String(polarity ?? 'positive')
      .trim()
      .toLowerCase();

  if (
    normalized === 'negative' ||
    normalized === 'contra' ||
    normalized === 'contradictory' ||
    normalized === 'against'
  ) {
    return 'negative';
  }

  return 'positive';
}

// =============================================================================
// NEGATIVE TEXT DETECTION
// =============================================================================
//
// This is deliberately conservative.
//
// "not present", "absent", "no", etc. are interpreted as explicit negative
// values. Arbitrary free text must NOT automatically become negative.
//
// =============================================================================

function isNegativeText(
  value: string | null | undefined,
): boolean {
  if (value == null) {
    return false;
  }

  const normalized =
    value.trim().toLowerCase();

  return (
    normalized === 'no' ||
    normalized === 'false' ||
    normalized === 'absent' ||
    normalized === 'negative' ||
    normalized === 'not present' ||
    normalized === 'none' ||
    normalized === 'nil' ||
    normalized === '0'
  );
}

// =============================================================================
// CONFIDENCE CLASS
// =============================================================================
//
// IMPORTANT:
// These labels are NOT diagnostic certainty.
//
// They describe computational compatibility only.
//
// =============================================================================

function confidenceClass(
  compatibility: number,
):
  | 'none'
  | 'weak'
  | 'moderate'
  | 'strong'
  | 'very_strong' {
  if (compatibility <= 0) {
    return 'none';
  }

  if (compatibility < 0.25) {
    return 'weak';
  }

  if (compatibility < 0.5) {
    return 'moderate';
  }

  if (compatibility < 0.75) {
    return 'strong';
  }

  return 'very_strong';
}

// =============================================================================
// NUMERIC SAFETY
// =============================================================================

function round(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }

  return Math.round(value * 1000) / 1000;
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }

  return Math.max(
    0,
    Math.min(1, value),
  );
}