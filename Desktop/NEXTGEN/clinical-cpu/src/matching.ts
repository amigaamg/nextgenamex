// =============================================================================
// AMEXAN Clinical CPU — Feature Matcher
//
// PURPOSE
// -------
// Provides the single canonical feature-evaluation implementation used by
// phenotype and mechanism reasoning.
//
// Clinical knowledge defines:
//
//     feature → operator → expected value → weight → polarity
//
// Patient state provides:
//
//     factCode → captured value(s)
//
// This module determines whether the captured facts satisfy the knowledge
// feature and calculates that feature's contribution to the resulting score.
//
// ARCHITECTURAL RULE
// ------------------
// This module contains NO disease-specific medical rules.
//
// It does not know what pneumonia, asthma, heart failure, sepsis, anaemia, or
// any other condition is.
//
// All clinical meaning comes from knowledge data. The matcher only evaluates
// machine-readable conditions consistently.
//
// Therefore:
//
//     PostgreSQL knowledge
//             ↓
//        FeatureDef
//             ↓
//     evaluateFeature()
//             ↓
//        Evaluation
//             ↓
//       contribution()
//             ↓
//       phenotype / mechanism score
//
// The phenotype engine and mechanism engine must use this module rather than
// implementing their own feature comparison logic.
//
// =============================================================================

import type { Fact, FactValue } from './types.js';

// =============================================================================
// Public Types
// =============================================================================

/**
 * Machine-readable definition of one clinical knowledge feature.
 *
 * featureCode
 * -----------
 * Must correspond to a patient's Fact.factCode.
 *
 * operator
 * --------
 * Defines how the captured fact value is compared with `value`.
 *
 * Supported operators:
 *
 *   eq / equals / =
 *   neq / !=
 *   in
 *   lt / <
 *   lte / <=
 *   gt / >
 *   gte / >=
 *   exists
 *   not_exists
 *
 * value
 * -----
 * Expected value for the comparison.
 *
 * weight
 * ------
 * Contribution to the parent phenotype/mechanism score.
 *
 * polarity
 * --------
 * Normally `positive` or `negative`.
 *
 * A negative-polarity feature that matches subtracts its weight from the
 * phenotype/mechanism score.
 */
export interface FeatureDef {
  featureCode: string;
  operator: string;
  value: unknown;
  weight: number;
  polarity: string;
}

/**
 * Result of evaluating one feature against the patient's captured facts.
 *
 * matched
 * -------
 * Whether at least one captured value satisfied the feature condition.
 *
 * found
 * -----
 * Human-readable representation of the value that was found.
 *
 * This is intentionally informational. It must never be interpreted as a
 * clinical conclusion.
 */
export interface Evaluation {
  matched: boolean;
  found: string | null;
}

// =============================================================================
// Internal Value Utilities
// =============================================================================

/**
 * Convert a FactValue into a deterministic textual representation.
 *
 * Used for explanations, traces, debugging, and runtime projections.
 *
 * Precedence:
 *
 *     text → boolean → numeric → null
 *
 * FactValue is expected to represent one logical captured value, so normally
 * only one primitive field is populated.
 */
function valueToString(value: FactValue): string | null {
  if (value.text != null) return value.text;

  if (value.boolean != null) {
    return value.boolean ? 'TRUE' : 'FALSE';
  }

  if (value.numeric != null) {
    return String(value.numeric);
  }

  return null;
}

/**
 * Determine whether a FactValue satisfies a feature comparison.
 *
 * This is deliberately kept private so every caller uses evaluateFeature()
 * rather than bypassing the canonical evaluation path.
 */
function compareValue(
  value: FactValue,
  operator: string,
  expected: unknown,
): boolean {
  const normalizedOperator = operator.trim().toLowerCase();

  switch (normalizedOperator) {
    // -------------------------------------------------------------------------
    // Equality
    // -------------------------------------------------------------------------

    case 'eq':
    case 'equals':
    case '=':
      return equalsValue(value, expected);

    // -------------------------------------------------------------------------
    // Inequality
    // -------------------------------------------------------------------------

    case 'neq':
    case '!=':
      return !equalsValue(value, expected);

    // -------------------------------------------------------------------------
    // Membership
    // -------------------------------------------------------------------------

    case 'in': {
      if (!Array.isArray(expected)) return false;

      return expected.some((candidate) =>
        equalsValue(value, candidate),
      );
    }

    // -------------------------------------------------------------------------
    // Numeric comparisons
    // -------------------------------------------------------------------------

    case 'lt':
    case '<':
      return numericComparison(value, expected, (actual, target) => actual < target);

    case 'lte':
    case '<=':
      return numericComparison(value, expected, (actual, target) => actual <= target);

    case 'gt':
    case '>':
      return numericComparison(value, expected, (actual, target) => actual > target);

    case 'gte':
    case '>=':
      return numericComparison(value, expected, (actual, target) => actual >= target);

    // -------------------------------------------------------------------------
    // Presence
    // -------------------------------------------------------------------------

    case 'exists':
      return hasValue(value);

    case 'not_exists':
      return !hasValue(value);

    // -------------------------------------------------------------------------
    // Unknown operator
    // -------------------------------------------------------------------------

    default:
      return false;
  }
}

/**
 * Type-aware equality.
 *
 * Strings, booleans, and numbers are compared against their corresponding
 * FactValue primitive instead of coercing unrelated types.
 *
 * This prevents values such as:
 *
 *     "65"
 *
 * from silently becoming equivalent to:
 *
 *     true
 *
 * or other unrelated primitive representations.
 */
function equalsValue(
  value: FactValue,
  expected: unknown,
): boolean {
  if (typeof expected === 'boolean') {
    return value.boolean === expected;
  }

  if (typeof expected === 'number') {
    return (
      value.numeric != null &&
      Number.isFinite(value.numeric) &&
      Number.isFinite(expected) &&
      value.numeric === expected
    );
  }

  if (typeof expected === 'string') {
    return value.text === expected;
  }

  /**
   * Null explicitly means no primitive value is expected.
   */
  if (expected === null) {
    return !hasValue(value);
  }

  /**
   * For structured values, equality is intentionally not guessed.
   *
   * Structured clinical facts should have a dedicated operator or normalized
   * primitive representation in the knowledge model rather than relying on
   * JavaScript object coercion.
   */
  return false;
}

/**
 * Numeric comparison helper.
 *
 * Invalid thresholds and non-numeric patient values fail closed.
 */
function numericComparison(
  value: FactValue,
  expected: unknown,
  comparator: (actual: number, target: number) => boolean,
): boolean {
  if (value.numeric == null) return false;

  const target = typeof expected === 'number'
    ? expected
    : Number(expected);

  if (!Number.isFinite(value.numeric)) return false;
  if (!Number.isFinite(target)) return false;

  return comparator(value.numeric, target);
}

/**
 * Determine whether a FactValue contains a meaningful primitive value.
 */
function hasValue(value: FactValue): boolean {
  return (
    value.text != null ||
    value.numeric != null ||
    value.boolean != null
  );
}

// =============================================================================
// Feature Evaluation
// =============================================================================

/**
 * Evaluate one knowledge feature against all captured facts.
 *
 * Multiple facts with the same factCode are allowed because AMEXAN clinical
 * state is append-oriented. A feature matches if ANY captured value satisfies
 * the feature condition.
 *
 * Example:
 *
 *     {
 *       featureCode: 'RESP_RATE',
 *       operator: 'gte',
 *       value: 30,
 *       weight: 2,
 *       polarity: 'positive'
 *     }
 *
 * If the patient has:
 *
 *     RESP_RATE = 24
 *     RESP_RATE = 34
 *
 * the feature matches because the latest/any captured value satisfying the
 * configured feature is sufficient under this matcher contract.
 *
 * NOTE:
 * Temporal selection is deliberately not performed here. If a clinical rule
 * requires the latest value, that temporal requirement belongs in the relevant
 * knowledge/engine layer. This function evaluates the supplied fact set.
 */
export function evaluateFeature(
  facts: Fact[],
  feature: FeatureDef,
): Evaluation {
  if (!feature.featureCode) {
    return {
      matched: false,
      found: null,
    };
  }

  const candidates = facts.filter(
    (fact) => fact.factCode === feature.featureCode,
  );

  /**
   * Search every captured value for a match.
   */
  for (const fact of candidates) {
    for (const value of fact.values) {
      if (
        compareValue(
          value,
          feature.operator,
          feature.value,
        )
      ) {
        return {
          matched: true,
          found: valueToString(value),
        };
      }
    }
  }

  /**
   * No value matched.
   *
   * Still expose the first captured value when available. This is useful for
   * explanation/tracing because "not matched" does not necessarily mean
   * "not captured".
   */
  const firstValue = candidates[0]?.values[0];

  return {
    matched: false,
    found: firstValue ? valueToString(firstValue) : null,
  };
}

// =============================================================================
// Score Contribution
// =============================================================================

/**
 * Calculate the feature's contribution to its parent score.
 *
 * Positive polarity:
 *
 *     matched     → +weight
 *     not matched → 0
 *
 * Negative polarity:
 *
 *     matched     → -weight
 *     not matched → 0
 *
 * This allows knowledge to express both supporting and contradicting features
 * without embedding disease-specific logic inside the CPU.
 */
export function contribution(
  feature: FeatureDef,
  evaluation: Evaluation,
): number {
  if (!evaluation.matched) {
    return 0;
  }

  const weight = Number(feature.weight);

  /**
   * Invalid weights fail closed rather than allowing NaN to contaminate the
   * clinical reasoning score.
   */
  if (!Number.isFinite(weight)) {
    return 0;
  }

  const polarity = feature.polarity.trim().toLowerCase();

  if (
    polarity === 'negative' ||
    polarity === 'contra' ||
    polarity === 'contradictory'
  ) {
    return -weight;
  }

  /**
   * Positive/default polarity.
   *
   * Unknown polarity values are treated as positive for backwards-compatible
   * knowledge rows, while explicit negative polarity is handled above.
   */
  return weight;
}