// =============================================================================
// AMEXAN Clinical CPU — feature matcher
// The single place that decides "does this patient's captured facts match this
// knowledge feature?" Used identically by the phenotype engine and the
// mechanism engine, so scoring is always consistent.
// =============================================================================

import type { Fact, FactValue } from './types.js';

export interface FeatureDef {
  featureCode: string;
  operator: string;
  value: unknown;
  weight: number;
  polarity: string;
}

export interface Evaluation {
  matched: boolean;
  found: string | null;
}

function valueToString(v: FactValue): string | null {
  if (v.text != null) return v.text;
  if (v.boolean != null) return v.boolean ? 'TRUE' : 'FALSE';
  if (v.numeric != null) return String(v.numeric);
  return null;
}

function compareValue(v: FactValue, operator: string, expected: unknown): boolean {
  switch (operator) {
    case 'eq':
    case 'equals':
    case '=':
      if (typeof expected === 'boolean') return v.boolean === expected;
      if (typeof expected === 'number') return v.numeric === Number(expected);
      return v.text === String(expected);
    case 'neq':
    case '!=':
      return !compareValue(v, 'eq', expected);
    case 'in': {
      if (!Array.isArray(expected)) return false;
      const values = expected.map(String);
      return v.text != null && values.includes(v.text);
    }
    case 'lt':
    case '<':
      return v.numeric != null && v.numeric < Number(expected);
    case 'lte':
    case '<=':
      return v.numeric != null && v.numeric <= Number(expected);
    case 'gt':
    case '>':
      return v.numeric != null && v.numeric > Number(expected);
    case 'gte':
    case '>=':
      return v.numeric != null && v.numeric >= Number(expected);
    case 'exists':
      return v.text != null || v.numeric != null || v.boolean != null;
    case 'not_exists':
      return v.text == null && v.numeric == null && v.boolean == null;
    default:
      return false;
  }
}

export function evaluateFeature(facts: Fact[], feature: FeatureDef): Evaluation {
  const candidates = facts.filter((f) => f.factCode === feature.featureCode);
  for (const fact of candidates) {
    for (const v of fact.values) {
      if (compareValue(v, feature.operator, feature.value)) {
        return { matched: true, found: valueToString(v) };
      }
    }
  }
  const found = candidates.length > 0 ? valueToString(candidates[0].values[0]) : null;
  return { matched: false, found };
}

export function contribution(feature: FeatureDef, evaluation: Evaluation): number {
  if (feature.polarity === 'negative') {
    // A negative-polarity feature that MATCHES counts AGAINST the phenotype.
    return evaluation.matched ? -feature.weight : 0;
  }
  return evaluation.matched ? feature.weight : 0;
}
