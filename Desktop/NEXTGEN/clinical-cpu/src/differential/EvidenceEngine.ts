// =============================================================================
// AMEXAN Clinical CPU — EvidenceEngine
//
// PURPOSE
// -------
// Produces the traceable clinical evidence ledger for one or more phenotypes.
//
// The EvidenceEngine answers:
//
//     "Why does AMEXAN support this phenotype?"
//     "What evidence argues against it?"
//     "Which captured fact produced that conclusion?"
//     "Which knowledge feature was responsible?"
//
// Every evidence line is derived from:
//     Patient Fact
//          ↓
//     Knowledge Phenotype Feature
//          ↓
//     Feature Evaluation
//          ↓
//     EvidenceLine
//
// IMPORTANT CLINICAL PRINCIPLE
// ----------------------------
// ABSENCE OF EVIDENCE IS NOT EVIDENCE AGAINST.
//
// If a required feature has never been captured, the EvidenceEngine must NOT
// manufacture an "against" line.
//
// Example:
//
//     Expected: fever = TRUE
//     Found:    null
//
// This means:
//
//     "Not assessed / not captured"
//
// NOT:
//
//     "Against pneumonia"
//
// However:
//
//     Expected: fever = TRUE
//     Found:    FALSE
//
// is genuine contradictory evidence and may be recorded as "against".
//
// NEGATIVE-POLARITY FEATURES
// --------------------------
// Knowledge polarity describes how a matched feature contributes to the
// phenotype.
//
//     positive polarity + matched
//         => SUPPORT
//
//     positive polarity + contradictory captured value
//         => AGAINST
//
//     negative polarity + matched
//         => AGAINST
//
//     negative polarity + contradictory captured value
//         => SUPPORT
//
// Therefore polarity MUST be interpreted together with the feature result.
// =============================================================================

import type { Db, Row } from '../db.js';
import { evaluateFeature } from '../matching.js';
import { parseValue } from '../phenotype/PhenotypeEngine.js';
import type {
  EvidenceLine,
  Fact,
} from '../types.js';


// =============================================================================
// DATABASE ROW
// =============================================================================

interface FeatureRow extends Row {
  phenotype_code: string;
  feature_code: string;
  operator: string;
  value: unknown;
  weight: number;
  polarity: string;
}


// =============================================================================
// INTERNAL EVIDENCE REPRESENTATION
// =============================================================================

interface InternalEvidenceLine {
  phenotypeCode: string;

  factCode: string;

  expectation: string;

  found: string | null;

  weight: number;

  polarity: 'positive' | 'negative';

  support: 'support' | 'against';

  /**
   * Whether a fact was actually captured and evaluated.
   *
   * This is deliberately kept internal unless EvidenceLine is later expanded.
   */
  factCaptured: boolean;

  /**
   * Knowledge feature that generated the line.
   */
  featureCode: string;
}


// =============================================================================
// POLARITY
// =============================================================================

type EvidencePolarity =
  | 'positive'
  | 'negative';


// =============================================================================
// SUPPORT DIRECTION
// =============================================================================

type EvidenceDirection =
  | 'support'
  | 'against';


// =============================================================================
// EVIDENCE ENGINE
// =============================================================================

export class EvidenceEngine {
  constructor(
    private readonly db: Db,
  ) {}


  // ===========================================================================
  // EVIDENCE FOR PHENOTYPES
  // ===========================================================================
  //
  // Returns the supporting/against ledger for the supplied phenotypes.
  //
  // The input facts are assumed to be the canonical facts already resolved
  // for the patient/encounter by the Clinical CPU.
  //
  // This engine does NOT fetch patient facts itself.
  //
  // That separation is intentional:
  //
  //     ContextResolver
  //             ↓
  //     PatientClinicalState
  //             ↓
  //     EvidenceEngine
  //
  // This prevents multiple engines from independently constructing different
  // versions of patient reality.
  //
  // ===========================================================================

  async evidenceFor(
    facts: Fact[],
    phenotypeCodes: string[],
  ): Promise<EvidenceLine[]> {

    // -------------------------------------------------------------------------
    // Normalize phenotype codes.
    // -------------------------------------------------------------------------

    const normalizedPhenotypes = uniqueNormalizedCodes(
      phenotypeCodes,
    );


    if (normalizedPhenotypes.length === 0) {
      return [];
    }


    // -------------------------------------------------------------------------
    // Query only active phenotype features.
    //
    // The knowledge layer remains the source of truth for phenotype-feature
    // relationships.
    // -------------------------------------------------------------------------

    const features = await this.db.query<FeatureRow>(
      `
      SELECT
        ph.phenotype_code,
        pf.feature_code,
        pf.operator,
        pf.value,
        pf.weight,
        pf.polarity

      FROM knowledge.phenotype_feature pf

      JOIN knowledge.phenotype ph
        ON ph.id = pf.phenotype_id

      WHERE ph.status = 'active'
        AND ph.phenotype_code = ANY($1::text[])

      ORDER BY
        ph.phenotype_code,
        pf.weight DESC,
        pf.feature_code
      `,
      [normalizedPhenotypes],
    );


    if (features.length === 0) {
      return [];
    }


    // -------------------------------------------------------------------------
    // Evaluate every knowledge feature against the captured clinical facts.
    // -------------------------------------------------------------------------

    const internalLines: InternalEvidenceLine[] = [];


    for (const feature of features) {

      const line = this.evaluateFeature(
        facts,
        feature,
      );


      if (line) {
        internalLines.push(line);
      }
    }


    // -------------------------------------------------------------------------
    // Remove duplicate evidence generated by duplicated knowledge rows or
    // repeated fact/value representations.
    // -------------------------------------------------------------------------

    const deduplicated =
      deduplicateEvidence(internalLines);


    // -------------------------------------------------------------------------
    // Sort deterministically.
    //
    // Clinically important/high-weight evidence comes first.
    // Supporting evidence is kept ahead of against evidence only when weights
    // are equal; urgency/diagnostic probability should be handled by the
    // phenotype engine rather than fabricated here.
    // -------------------------------------------------------------------------

    deduplicated.sort(compareEvidence);


    // -------------------------------------------------------------------------
    // Convert internal representation to the public EvidenceLine contract.
    // -------------------------------------------------------------------------

    return deduplicated.map(toEvidenceLine);
  }


  // ===========================================================================
  // SINGLE FEATURE EVALUATION
  // ===========================================================================

  private evaluateFeature(
    facts: Fact[],
    feature: FeatureRow,
  ): InternalEvidenceLine | null {

    // -------------------------------------------------------------------------
    // Validate knowledge row.
    //
    // A malformed knowledge feature should not crash the entire clinical CPU.
    // It is better to omit invalid evidence than to manufacture unsafe clinical
    // reasoning.
    // -------------------------------------------------------------------------

    const phenotypeCode =
      normalizeCode(feature.phenotype_code);

    const featureCode =
      normalizeCode(feature.feature_code);

    const operator =
      normalizeOperator(feature.operator);

    const polarity =
      normalizePolarity(feature.polarity);


    if (!phenotypeCode || !featureCode || !operator || !polarity) {
      return null;
    }


    // -------------------------------------------------------------------------
    // Parse knowledge value.
    //
    // parseValue is the canonical conversion used by the phenotype engine.
    // We deliberately do not duplicate its parsing rules here.
    // -------------------------------------------------------------------------

    let expectedValue: unknown;

    try {
      expectedValue =
        parseValue(feature.value);
    } catch {
      // Invalid knowledge data must not produce clinical evidence.
      return null;
    }


    const weight =
      normalizeWeight(feature.weight);


    // -------------------------------------------------------------------------
    // Evaluate against the canonical patient facts.
    // -------------------------------------------------------------------------

    let evaluation;

    try {
      evaluation = evaluateFeature(
        facts,
        {
          featureCode,
          operator,
          value: expectedValue,
          weight,
          polarity,
        },
      );
    } catch {
      // A malformed feature must not break evidence generation for all other
      // phenotypes.
      return null;
    }


    // -------------------------------------------------------------------------
    // Determine whether the feature was actually assessed.
    //
    // The matching layer returns found === null when no relevant captured
    // value exists.
    //
    // This distinction is clinically essential.
    // -------------------------------------------------------------------------

    const factCaptured =
      evaluation.found !== null &&
      evaluation.found !== undefined;


    // -------------------------------------------------------------------------
    // NO CAPTURED FACT
    //
    // Do NOT create an "against" line.
    //
    // Example:
    //
    //     feature: HEMOPTYSIS = FALSE
    //     patient: hemoptysis not asked
    //
    // This is NOT evidence of absence.
    // -------------------------------------------------------------------------

    if (!factCaptured) {
      return null;
    }


    // -------------------------------------------------------------------------
    // MATCHED FEATURE
    //
    // For positive polarity:
    //
    //     matched => SUPPORT
    //
    // For negative polarity:
    //
    //     matched => AGAINST
    //
    // Example:
    //
    //     Feature:
    //         smoking = TRUE
    //         polarity = negative
    //
    // If smoking is TRUE and the phenotype is one for which smoking argues
    // against it, the line is AGAINST.
    // -------------------------------------------------------------------------

    const support: EvidenceDirection =
      evaluation.matched
        ? matchedDirection(polarity)
        : oppositeDirection(polarity);


    return {
      phenotypeCode,

      factCode: featureCode,

      expectation:
        stringify(expectedValue),

      found:
        stringifyFound(evaluation.found),

      weight,

      polarity,

      support,

      factCaptured: true,

      featureCode,
    };
  }
}


// =============================================================================
// MATCHED POLARITY → CLINICAL DIRECTION
// =============================================================================

function matchedDirection(
  polarity: EvidencePolarity,
): EvidenceDirection {

  return polarity === 'positive'
    ? 'support'
    : 'against';
}


// =============================================================================
// CONTRADICTED POLARITY → CLINICAL DIRECTION
// =============================================================================

function oppositeDirection(
  polarity: EvidencePolarity,
): EvidenceDirection {

  return polarity === 'positive'
    ? 'against'
    : 'support';
}


// =============================================================================
// PUBLIC EVIDENCE LINE CONVERSION
// =============================================================================

function toEvidenceLine(
  line: InternalEvidenceLine,
): EvidenceLine {

  return {
    factCode: line.factCode,

    expectation: line.expectation,

    found: line.found,

    weight: line.weight,

    polarity: line.polarity,

    support: line.support,
  };
}


// =============================================================================
// DEDUPLICATION
// =============================================================================
//
// A single clinical fact may be represented through several rows/value records.
// We do not want the clinician seeing:
//
//     Fever 39.2°C — support
//     Fever 39.2°C — support
//     Fever 39.2°C — support
//
// three times simply because the database contains duplicated feature mappings.
//
// =============================================================================

function deduplicateEvidence(
  lines: InternalEvidenceLine[],
): InternalEvidenceLine[] {

  const map =
    new Map<string, InternalEvidenceLine>();


  for (const line of lines) {

    const key = [
      line.phenotypeCode,
      line.featureCode,
      line.factCode,
      line.expectation,
      line.found ?? '',
      line.support,
    ]
      .map((value) => String(value).trim().toUpperCase())
      .join('|');


    const existing = map.get(key);


    if (!existing) {
      map.set(key, line);
      continue;
    }


    // If the same evidence is generated more than once, retain the strongest
    // weight rather than multiplying the evidence.
    if (line.weight > existing.weight) {
      map.set(key, line);
    }
  }


  return [...map.values()];
}


// =============================================================================
// DETERMINISTIC EVIDENCE ORDER
// =============================================================================

function compareEvidence(
  a: InternalEvidenceLine,
  b: InternalEvidenceLine,
): number {

  // Higher weight first.
  if (a.weight !== b.weight) {
    return b.weight - a.weight;
  }


  // Supporting evidence first when weights are equal.
  if (a.support !== b.support) {
    return a.support === 'support'
      ? -1
      : 1;
  }


  // Stable feature order.
  return a.featureCode.localeCompare(
    b.featureCode,
  );
}


// =============================================================================
// WEIGHT NORMALIZATION
// =============================================================================
//
// Knowledge data must never generate NaN or Infinity in the evidence ledger.
//
// Negative weights are permitted only if the knowledge model explicitly
// supports them. For this evidence layer, we normalize them to zero rather
// than allowing pathological sorting behaviour.
//
// =============================================================================

function normalizeWeight(
  value: unknown,
): number {

  const weight =
    Number(value);


  if (!Number.isFinite(weight)) {
    return 0;
  }


  if (weight < 0) {
    return 0;
  }


  return weight;
}


// =============================================================================
// POLARITY NORMALIZATION
// =============================================================================

function normalizePolarity(
  value: unknown,
): EvidencePolarity | null {

  const polarity =
    normalizeCode(value);


  if (
    polarity === 'POSITIVE' ||
    polarity === 'SUPPORT' ||
    polarity === 'FOR'
  ) {
    return 'positive';
  }


  if (
    polarity === 'NEGATIVE' ||
    polarity === 'AGAINST'
  ) {
    return 'negative';
  }


  return null;
}


// =============================================================================
// OPERATOR NORMALIZATION
// =============================================================================

function normalizeOperator(
  value: unknown,
): string | null {

  if (typeof value !== 'string') {
    return null;
  }


  const operator =
    value.trim();


  return operator.length > 0
    ? operator
    : null;
}


// =============================================================================
// CODE NORMALIZATION
// =============================================================================

function normalizeCode(
  value: unknown,
): string | null {

  if (typeof value !== 'string') {
    return null;
  }


  const code =
    value.trim().toUpperCase();


  return code.length > 0
    ? code
    : null;
}


// =============================================================================
// UNIQUE NORMALIZED CODES
// =============================================================================

function uniqueNormalizedCodes(
  values: string[],
): string[] {

  return [
    ...new Set(
      values
        .map(normalizeCode)
        .filter(
          (value): value is string =>
            value !== null,
        ),
    ),
  ];
}


// =============================================================================
// FOUND VALUE STRINGIFICATION
// =============================================================================
//
// null means "not captured" and is intentionally different from:
//
//     "FALSE"
//     "NONE"
//     "0"
//     "UNKNOWN"
//
// This distinction is clinically important.
// =============================================================================

function stringifyFound(
  value: unknown,
): string | null {

  if (value === null || value === undefined) {
    return null;
  }


  return stringify(value);
}


// =============================================================================
// KNOWLEDGE VALUE STRINGIFICATION
// =============================================================================

function stringify(
  value: unknown,
): string {

  if (Array.isArray(value)) {
    return value
      .map((item) => stringify(item))
      .join(' / ');
  }


  if (typeof value === 'boolean') {
    return value
      ? 'TRUE'
      : 'FALSE';
  }


  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      return '?';
    }

    return String(value);
  }


  if (value == null) {
    return '?';
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