// =============================================================================
// AMEXAN Clinical CPU — SeverityScoreEngine
//
// PURPOSE
// -------
// Evaluates governed, structured clinical severity instruments against the
// current PatientClinicalState.
//
// Architecture:
//
//   ranked conditions
//          │
//          ▼
//   active severity instruments
//          │
//          ▼
//   instrument components
//          │
//          ▼
//   fact resolution
//          │
//          ▼
//   component evaluation
//          │
//          ▼
//   total score
//          │
//          ▼
//   governed interpretation
//          │
//          ▼
//   SeverityScore[]
//
// DESIGN PRINCIPLES
// -----------------
// 1. No clinical instrument is hard-coded in TypeScript.
// 2. Instrument definitions live in PostgreSQL.
// 3. Components are machine-readable JSON conditions.
// 4. Facts are evaluated against the current clinical state.
// 5. Historical observations are resolved deterministically.
// 6. Missing facts never become positive findings.
// 7. Invalid conditions fail closed.
// 8. Unknown condition operators fail closed.
// 9. Patient population constraints are enforced before evaluation.
// 10. Score interpretations are resolved from database ranges.
// 11. The engine does not diagnose, prescribe, or invent thresholds.
// 12. The engine returns an auditable component-by-component result.
// 13. Multiple instruments may be evaluated for the same ranked condition.
// 14. Instruments may target any condition present in the supplied differential.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { Fact, SeverityScore } from '../types.js';

// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface ScoreRow extends Row {
  score_code: string;
  canonical_name: string;
  description: string | null;
  population: string;
  max_score: number;
  status?: string;
}

interface ComponentRow extends Row {
  score_code: string;
  component_code: string;
  component_name: string;
  condition: Record<string, unknown>;
  points: number;
  rationale: string | null;
  sort_order: number;
}

interface InterpretationRow extends Row {
  score_code: string;
  min_score: number;
  max_score: number;
  severity_label: string;
  disposition: string | null;
  recommendation: string | null;
}

interface FactValue {
  numeric?: number | null;
  boolean?: boolean | null;
  text?: string | null;
  code?: string | null;
  unit?: string | null;
}

interface ResolvedFact {
  factCode: string;
  value: FactValue;
}

// =============================================================================
// SUPPORTED CONDITION TYPES
// =============================================================================
//
// The database owns the clinical definitions.
//
// TypeScript only provides the generic execution primitives.
//
// Supported:
//
//   boolean
//   numeric_gt
//   numeric_gte
//   numeric_lt
//   numeric_lte
//   numeric_eq
//   numeric_neq
//   numeric_between
//   age_gte
//   age_gt
//   age_lte
//   age_lt
//   age_between
//   text_equals
//   code_equals
//   exists
//   not_exists
//   and
//   or
//   not
//
// Example:
//
// {
//   "type": "numeric_gte",
//   "fact_code": "RESP_RATE",
//   "threshold": 30
// }
//
// Example:
//
// {
//   "type": "and",
//   "conditions": [
//     {
//       "type": "age_gte",
//       "threshold": 65
//     },
//     {
//       "type": "numeric_gte",
//       "fact_code": "RESP_RATE",
//       "threshold": 30
//     }
//   ]
// }
//
// =============================================================================

type ConditionObject = Record<string, unknown>;

// =============================================================================
// ENGINE
// =============================================================================

export class SeverityScoreEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================
  //
  // Evaluates every active severity instrument associated with any supplied
  // condition.
  //
  // conditionCodes:
  //   Conditions currently present in the ranked differential.
  //
  // ageYears:
  //   Patient age in years.
  //
  // facts:
  //   Current accumulated clinical facts.
  //
  // Returns:
  //   One SeverityScore projection per applicable active instrument.
  //
  // ===========================================================================

  async evaluate(
    conditionCodes: string[],
    ageYears: number | null,
    facts: Fact[],
  ): Promise<SeverityScore[]> {
    const normalizedConditions = uniqueNonEmptyStrings(conditionCodes);

    if (normalizedConditions.length === 0) {
      return [];
    }

    const scores = await this.loadScores(normalizedConditions);

    if (scores.length === 0) {
      return [];
    }

    const scoreCodes = uniqueNonEmptyStrings(
      scores.map((score) => score.score_code),
    );

    const [components, interpretations] = await Promise.all([
      this.loadComponents(scoreCodes),
      this.loadInterpretations(scoreCodes),
    ]);

    const componentsByScore = groupComponentsByScore(components);
    const interpretationsByScore =
      groupInterpretationsByScore(interpretations);

    const resolvedFacts = resolveLatestFacts(facts);

    const result: SeverityScore[] = [];

    for (const score of scores) {
      if (!isPopulationApplicable(score.population, ageYears)) {
        continue;
      }

      const scoreComponents =
        componentsByScore.get(score.score_code) ?? [];

      const scoreInterpretations =
        interpretationsByScore.get(score.score_code) ?? [];

      const evaluated = evaluateScore(
        score,
        scoreComponents,
        scoreInterpretations,
        resolvedFacts,
        ageYears,
        facts,
      );

      result.push(evaluated);
    }

    return result;
  }

  // ===========================================================================
  // LOAD ACTIVE INSTRUMENTS
  // ===========================================================================

  private async loadScores(
    conditionCodes: string[],
  ): Promise<ScoreRow[]> {
    return this.db.query<ScoreRow>(
      `
        SELECT
          ss.score_code,
          ss.canonical_name,
          ss.description,
          ss.population,
          ss.max_score,
          ss.status
        FROM knowledge.severity_score ss
        JOIN knowledge.condition c
          ON c.id = ss.condition_id
        WHERE c.condition_code = ANY($1::text[])
          AND ss.status = 'active'
        ORDER BY ss.score_code
      `,
      [conditionCodes],
    );
  }

  // ===========================================================================
  // LOAD COMPONENTS
  // ===========================================================================

  private async loadComponents(
    scoreCodes: string[],
  ): Promise<ComponentRow[]> {
    if (scoreCodes.length === 0) {
      return [];
    }

    return this.db.query<ComponentRow>(
      `
        SELECT
          ss.score_code,
          c.component_code,
          c.component_name,
          c.condition,
          c.points,
          c.rationale,
          c.sort_order
        FROM knowledge.severity_score_component c
        JOIN knowledge.severity_score ss
          ON ss.id = c.score_id
        WHERE ss.score_code = ANY($1::text[])
        ORDER BY
          ss.score_code,
          c.sort_order,
          c.component_code
      `,
      [scoreCodes],
    );
  }

  // ===========================================================================
  // LOAD INTERPRETATIONS
  // ===========================================================================

  private async loadInterpretations(
    scoreCodes: string[],
  ): Promise<InterpretationRow[]> {
    if (scoreCodes.length === 0) {
      return [];
    }

    return this.db.query<InterpretationRow>(
      `
        SELECT
          ss.score_code,
          i.min_score,
          i.max_score,
          i.severity_label,
          i.disposition,
          i.recommendation
        FROM knowledge.severity_score_interpretation i
        JOIN knowledge.severity_score ss
          ON ss.id = i.score_id
        WHERE ss.score_code = ANY($1::text[])
        ORDER BY
          ss.score_code,
          i.min_score,
          i.max_score
      `,
      [scoreCodes],
    );
  }
}

// =============================================================================
// SCORE EVALUATION
// =============================================================================

function evaluateScore(
  score: ScoreRow,
  components: ComponentRow[],
  interpretations: InterpretationRow[],
  resolvedFacts: Map<string, ResolvedFact>,
  ageYears: number | null,
  facts: Fact[],
): SeverityScore {
  let total = 0;

  const evaluatedComponents: SeverityScore['components'] = [];

  for (const component of components) {
    const matched = evaluateCondition(
      component.condition,
      resolvedFacts,
      ageYears,
      facts,
    );

    if (matched) {
      total += normalizePoints(component.points);
    }

    evaluatedComponents.push({
      componentCode: component.component_code,
      name: component.component_name,
      points: normalizePoints(component.points),
      matched,
      rationale: component.rationale,
    });
  }

  const interpretation = resolveInterpretation(
    total,
    interpretations,
  );

  return {
    scoreCode: score.score_code,
    name: score.canonical_name,
    description: score.description,
    population: score.population,
    maxScore: normalizeMaxScore(score.max_score),
    score: total,
    severityLabel: interpretation?.severity_label ?? null,
    disposition: interpretation?.disposition ?? null,
    recommendation: interpretation?.recommendation ?? null,
    components: evaluatedComponents,
  };
}

// =============================================================================
// INTERPRETATION RESOLUTION
// =============================================================================

function resolveInterpretation(
  score: number,
  interpretations: InterpretationRow[],
): InterpretationRow | null {
  if (interpretations.length === 0) {
    return null;
  }

  return (
    interpretations.find(
      (interpretation) =>
        score >= interpretation.min_score &&
        score <= interpretation.max_score,
    ) ?? null
  );
}

// =============================================================================
// FACT RESOLUTION
// =============================================================================
//
// Facts are append-only observations.
//
// The runtime therefore needs a deterministic "current value" for instruments
// that operate on a single current vital/laboratory value.
//
// The latest fact wins.
//
// A fact without a usable value does not erase an earlier valid value.
// This prevents malformed/partial events from silently replacing a valid
// observation.
//
// ============================================================================

function resolveLatestFacts(
  facts: Fact[],
): Map<string, ResolvedFact> {
  const resolved = new Map<string, ResolvedFact>();

  for (let index = 0; index < facts.length; index += 1) {
    const fact = facts[index];

    if (!fact || !fact.factCode) {
      continue;
    }

    const value = extractFactValue(fact);

    if (!value) {
      continue;
    }

    resolved.set(fact.factCode, {
      factCode: fact.factCode,
      value,
    });
  }

  return resolved;
}

// =============================================================================
// VALUE EXTRACTION
// =============================================================================

function extractFactValue(
  fact: Fact,
): FactValue | null {
  if (!Array.isArray(fact.values) || fact.values.length === 0) {
    return null;
  }

  for (let index = fact.values.length - 1; index >= 0; index -= 1) {
    const candidate = fact.values[index];

    if (!candidate) {
      continue;
    }

    if (candidate.numeric != null) {
      const numeric = Number(candidate.numeric);

      if (Number.isFinite(numeric)) {
        return {
          numeric,
          unit: candidate.unitCode ?? null,
        };
      }
    }

    if (candidate.boolean != null) {
      return {
        boolean: Boolean(candidate.boolean),
      };
    }

    if (candidate.text != null) {
      return {
        text: String(candidate.text),
      };
    }

    if (candidate.code != null) {
      return {
        code: String(candidate.code),
      };
    }
  }

  return null;
}

// =============================================================================
// CONDITION EVALUATOR
// =============================================================================
//
// This is deliberately generic.
//
// There are no clinical thresholds here.
//
// Thresholds come from:
//
//   knowledge.severity_score_component.condition
//
// ============================================================================

export function evaluateCondition(
  condition: ConditionObject,
  factsByCode: Map<string, ResolvedFact>,
  ageYears: number | null,
  facts: Fact[],
): boolean {
  if (!condition || typeof condition !== 'object') {
    return false;
  }

  const type = normalizeConditionType(condition.type);

  switch (type) {
    // -------------------------------------------------------------------------
    // BOOLEAN
    // -------------------------------------------------------------------------

    case 'boolean': {
      const factCode = readFactCode(condition);

      if (!factCode) {
        return false;
      }

      const expected = readBoolean(condition.expect);

      if (expected == null) {
        return false;
      }

      const actual = latestBooleanFromResolvedFacts(
        factsByCode,
        factCode,
      );

      return actual != null && actual === expected;
    }

    // -------------------------------------------------------------------------
    // NUMERIC >
    // -------------------------------------------------------------------------

    case 'numeric_gt': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const threshold = readFiniteNumber(condition.threshold);

      if (value == null || threshold == null) {
        return false;
      }

      return value > threshold;
    }

    // -------------------------------------------------------------------------
    // NUMERIC >=
    // -------------------------------------------------------------------------

    case 'numeric_gte': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const threshold = readFiniteNumber(condition.threshold);

      if (value == null || threshold == null) {
        return false;
      }

      return value >= threshold;
    }

    // -------------------------------------------------------------------------
    // NUMERIC <
    // -------------------------------------------------------------------------

    case 'numeric_lt': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const threshold = readFiniteNumber(condition.threshold);

      if (value == null || threshold == null) {
        return false;
      }

      return value < threshold;
    }

    // -------------------------------------------------------------------------
    // NUMERIC <=
    // -------------------------------------------------------------------------

    case 'numeric_lte': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const threshold = readFiniteNumber(condition.threshold);

      if (value == null || threshold == null) {
        return false;
      }

      return value <= threshold;
    }

    // -------------------------------------------------------------------------
    // NUMERIC ==
    // -------------------------------------------------------------------------

    case 'numeric_eq': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const expected = readFiniteNumber(condition.value);

      if (value == null || expected == null) {
        return false;
      }

      return value === expected;
    }

    // -------------------------------------------------------------------------
    // NUMERIC !=
    // -------------------------------------------------------------------------

    case 'numeric_neq': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const expected = readFiniteNumber(condition.value);

      if (value == null || expected == null) {
        return false;
      }

      return value !== expected;
    }

    // -------------------------------------------------------------------------
    // NUMERIC BETWEEN
    // -------------------------------------------------------------------------

    case 'numeric_between': {
      const value = numericFact(
        factsByCode,
        readFactCode(condition),
      );

      const min = readFiniteNumber(condition.min);
      const max = readFiniteNumber(condition.max);

      if (
        value == null ||
        min == null ||
        max == null ||
        min > max
      ) {
        return false;
      }

      return value >= min && value <= max;
    }

    // -------------------------------------------------------------------------
    // AGE >=
    // -------------------------------------------------------------------------

    case 'age_gte': {
      const threshold = readFiniteNumber(condition.threshold);

      if (ageYears == null || threshold == null) {
        return false;
      }

      return ageYears >= threshold;
    }

    // -------------------------------------------------------------------------
    // AGE >
    // -------------------------------------------------------------------------

    case 'age_gt': {
      const threshold = readFiniteNumber(condition.threshold);

      if (ageYears == null || threshold == null) {
        return false;
      }

      return ageYears > threshold;
    }

    // -------------------------------------------------------------------------
    // AGE <=
    // -------------------------------------------------------------------------

    case 'age_lte': {
      const threshold = readFiniteNumber(condition.threshold);

      if (ageYears == null || threshold == null) {
        return false;
      }

      return ageYears <= threshold;
    }

    // -------------------------------------------------------------------------
    // AGE <
    // -------------------------------------------------------------------------

    case 'age_lt': {
      const threshold = readFiniteNumber(condition.threshold);

      if (ageYears == null || threshold == null) {
        return false;
      }

      return ageYears < threshold;
    }

    // -------------------------------------------------------------------------
    // AGE BETWEEN
    // -------------------------------------------------------------------------

    case 'age_between': {
      const min = readFiniteNumber(condition.min);
      const max = readFiniteNumber(condition.max);

      if (
        ageYears == null ||
        min == null ||
        max == null ||
        min > max
      ) {
        return false;
      }

      return ageYears >= min && ageYears <= max;
    }

    // -------------------------------------------------------------------------
    // TEXT EQUALS
    // -------------------------------------------------------------------------

    case 'text_equals': {
      const factCode = readFactCode(condition);
      const expected = readString(condition.value);

      if (!factCode || expected == null) {
        return false;
      }

      const actual = textFact(
        factsByCode,
        factCode,
      );

      return actual != null && actual === expected;
    }

    // -------------------------------------------------------------------------
    // CODE EQUALS
    // -------------------------------------------------------------------------

    case 'code_equals': {
      const factCode = readFactCode(condition);
      const expected = readString(condition.value);

      if (!factCode || expected == null) {
        return false;
      }

      const actual = codeFact(
        factsByCode,
        factCode,
      );

      return actual != null && actual === expected;
    }

    // -------------------------------------------------------------------------
    // EXISTS
    // -------------------------------------------------------------------------

    case 'exists': {
      const factCode = readFactCode(condition);

      if (!factCode) {
        return false;
      }

      return factsByCode.has(factCode);
    }

    // -------------------------------------------------------------------------
    // NOT EXISTS
    // -------------------------------------------------------------------------

    case 'not_exists': {
      const factCode = readFactCode(condition);

      if (!factCode) {
        return false;
      }

      return !factsByCode.has(factCode);
    }

    // -------------------------------------------------------------------------
    // OR
    // -------------------------------------------------------------------------

    case 'or': {
      const conditions = readConditions(
        condition.conditions,
      );

      if (conditions.length === 0) {
        return false;
      }

      return conditions.some((subCondition) =>
        evaluateCondition(
          subCondition,
          factsByCode,
          ageYears,
          facts,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // AND
    // -------------------------------------------------------------------------

    case 'and': {
      const conditions = readConditions(
        condition.conditions,
      );

      if (conditions.length === 0) {
        return false;
      }

      return conditions.every((subCondition) =>
        evaluateCondition(
          subCondition,
          factsByCode,
          ageYears,
          facts,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // NOT
    // -------------------------------------------------------------------------

    case 'not': {
      const nested = condition.condition;

      if (
        typeof nested !== 'object' ||
        nested === null ||
        Array.isArray(nested)
      ) {
        return false;
      }

      return !evaluateCondition(
        nested as ConditionObject,
        factsByCode,
        ageYears,
        facts,
      );
    }

    // -------------------------------------------------------------------------
    // FAIL CLOSED
    // -------------------------------------------------------------------------

    default:
      return false;
  }
}

// =============================================================================
// CONDITION TYPE NORMALIZATION
// =============================================================================

function normalizeConditionType(
  value: unknown,
): string {
  if (typeof value !== 'string') {
    return '';
  }

  return value
    .trim()
    .toLowerCase();
}

// =============================================================================
// FACT HELPERS
// =============================================================================

function numericFact(
  factsByCode: Map<string, ResolvedFact>,
  factCode: string | null,
): number | null {
  if (!factCode) {
    return null;
  }

  const fact = factsByCode.get(factCode);

  if (!fact) {
    return null;
  }

  const value = fact.value.numeric;

  if (value == null) {
    return null;
  }

  return Number.isFinite(value)
    ? value
    : null;
}

function latestBooleanFromResolvedFacts(
  factsByCode: Map<string, ResolvedFact>,
  factCode: string,
): boolean | null {
  const fact = factsByCode.get(factCode);

  if (!fact) {
    return null;
  }

  return fact.value.boolean == null
    ? null
    : Boolean(fact.value.boolean);
}

function textFact(
  factsByCode: Map<string, ResolvedFact>,
  factCode: string,
): string | null {
  const fact = factsByCode.get(factCode);

  if (!fact || fact.value.text == null) {
    return null;
  }

  return String(fact.value.text);
}

function codeFact(
  factsByCode: Map<string, ResolvedFact>,
  factCode: string,
): string | null {
  const fact = factsByCode.get(factCode);

  if (!fact || fact.value.code == null) {
    return null;
  }

  return String(fact.value.code);
}

// =============================================================================
// RAW FACT BOOLEAN HELPER
// =============================================================================
//
// Retained as a public-compatible utility for callers that still evaluate
// boolean conditions directly against the Fact[] representation.
//
// ============================================================================

export function latestBoolean(
  facts: Fact[],
  code: string,
): boolean | null {
  for (let index = facts.length - 1; index >= 0; index -= 1) {
    const fact = facts[index];

    if (!fact || fact.factCode !== code) {
      continue;
    }

    if (!Array.isArray(fact.values)) {
      continue;
    }

    for (
      let valueIndex = fact.values.length - 1;
      valueIndex >= 0;
      valueIndex -= 1
    ) {
      const value = fact.values[valueIndex];

      if (!value || value.boolean == null) {
        continue;
      }

      return Boolean(value.boolean);
    }
  }

  return null;
}

// =============================================================================
// FACT CODE READER
// =============================================================================

function readFactCode(
  condition: ConditionObject,
): string | null {
  const value = condition.fact_code;

  if (typeof value !== 'string') {
    return null;
  }

  const code = value.trim();

  return code.length > 0
    ? code
    : null;
}

// =============================================================================
// GENERIC VALUE READERS
// =============================================================================

function readFiniteNumber(
  value: unknown,
): number | null {
  if (
    value === null ||
    value === undefined ||
    value === '' ||
    typeof value === 'boolean'
  ) {
    return null;
  }

  const number = Number(value);

  return Number.isFinite(number)
    ? number
    : null;
}

function readBoolean(
  value: unknown,
): boolean | null {
  if (typeof value === 'boolean') {
    return value;
  }

  if (value === 'true') {
    return true;
  }

  if (value === 'false') {
    return false;
  }

  return null;
}

function readString(
  value: unknown,
): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();

  return normalized.length > 0
    ? normalized
    : null;
}

// =============================================================================
// NESTED CONDITION READER
// =============================================================================

function readConditions(
  value: unknown,
): ConditionObject[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const result: ConditionObject[] = [];

  for (const item of value) {
    if (
      typeof item !== 'object' ||
      item === null ||
      Array.isArray(item)
    ) {
      continue;
    }

    result.push(item as ConditionObject);
  }

  return result;
}

// =============================================================================
// GROUPING
// =============================================================================

function groupComponentsByScore(
  components: ComponentRow[],
): Map<string, ComponentRow[]> {
  const result = new Map<string, ComponentRow[]>();

  for (const component of components) {
    const list =
      result.get(component.score_code) ?? [];

    list.push(component);

    result.set(
      component.score_code,
      list,
    );
  }

  return result;
}

function groupInterpretationsByScore(
  interpretations: InterpretationRow[],
): Map<string, InterpretationRow[]> {
  const result = new Map<string, InterpretationRow[]>();

  for (const interpretation of interpretations) {
    const list =
      result.get(interpretation.score_code) ?? [];

    list.push(interpretation);

    result.set(
      interpretation.score_code,
      list,
    );
  }

  return result;
}

// =============================================================================
// POPULATION RESOLUTION
// =============================================================================
//
// Population strings are intentionally generic.
//
// Examples supported:
//
//   adult
//   adult_only
//   pediatric
//   child
//   paediatric
//   all
//   universal
//   age_gte:65
//   age_lt:18
//   age_between:18:64
//
// Unknown population declarations fail closed rather than assuming that an
// instrument applies to everybody.
//
// ============================================================================

function isPopulationApplicable(
  population: string,
  ageYears: number | null,
): boolean {
  const normalized = String(population ?? '')
    .trim()
    .toLowerCase();

  if (!normalized) {
    return false;
  }

  switch (normalized) {
    case 'all':
    case 'universal':
    case 'any':
      return true;

    case 'adult':
    case 'adult_only':
      return ageYears != null && ageYears >= 18;

    case 'pediatric':
    case 'paediatric':
    case 'child':
      return ageYears != null && ageYears < 18;

    default:
      break;
  }

  if (normalized.startsWith('age_gte:')) {
    const threshold = Number(
      normalized.slice('age_gte:'.length),
    );

    return (
      Number.isFinite(threshold) &&
      ageYears != null &&
      ageYears >= threshold
    );
  }

  if (normalized.startsWith('age_gt:')) {
    const threshold = Number(
      normalized.slice('age_gt:'.length),
    );

    return (
      Number.isFinite(threshold) &&
      ageYears != null &&
      ageYears > threshold
    );
  }

  if (normalized.startsWith('age_lt:')) {
    const threshold = Number(
      normalized.slice('age_lt:'.length),
    );

    return (
      Number.isFinite(threshold) &&
      ageYears != null &&
      ageYears < threshold
    );
  }

  if (normalized.startsWith('age_lte:')) {
    const threshold = Number(
      normalized.slice('age_lte:'.length),
    );

    return (
      Number.isFinite(threshold) &&
      ageYears != null &&
      ageYears <= threshold
    );
  }

  if (normalized.startsWith('age_between:')) {
    const values = normalized
      .slice('age_between:'.length)
      .split(':')
      .map(Number);

    if (
      values.length !== 2 ||
      !Number.isFinite(values[0]) ||
      !Number.isFinite(values[1]) ||
      ageYears == null
    ) {
      return false;
    }

    return (
      ageYears >= values[0] &&
      ageYears <= values[1]
    );
  }

  return false;
}

// =============================================================================
// NORMALIZATION
// =============================================================================

function uniqueNonEmptyStrings(
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

function normalizePoints(
  value: number,
): number {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return 0;
  }

  return number;
}

function normalizeMaxScore(
  value: number,
): number {
  const number = Number(value);

  if (!Number.isFinite(number) || number < 0) {
    return 0;
  }

  return number;
}