// =============================================================================
// AMEXAN Clinical CPU — FormatResolver (U2)
// =============================================================================
// PURPOSE
// -----------------------------------------------------------------------------
// Resolves the canonical clinical documentation/examination format for the
// current patient encounter from the patient's clinical context.
//
// The resolver is deliberately KNOWLEDGE-DRIVEN:
//
//   PatientClinicalState
//          │
//          ├── Age band
//          ├── Sex
//          ├── Pregnancy
//          ├── Gestational age
//          ├── Department / service
//          ├── Encounter type
//          └── Active symptom domains
//                    │
//                    ▼
//       buildContextVector()
//                    │
//                    ▼
//       knowledge.format_context_rule
//                    │
//             ┌──────┴──────┐
//             │             │
//          BLOCK          SELECT
//             │             │
//             ▼             ▼
//        eliminate       score
//                          │
//                          ▼
//                 deterministic winner
//                          │
//                          ▼
//          clinical_format_section
//                          │
//                          ▼
//              section_context_rule
//                          │
//                          ▼
//                 ClinicalFormatPlan
//
// CLINICAL SAFETY INVARIANTS
// -----------------------------------------------------------------------------
// 1. The UI NEVER decides which clinical format applies.
// 2. A matching BLOCK always excludes a format.
// 3. BLOCK wins over SELECT regardless of score.
// 4. Unknown/missing context never creates a positive match.
// 5. Sex is normalized before matching.
// 6. Pregnancy is never inferred from sex.
// 7. Gestational age is exposed as a separate clinical context.
// 8. Symptom-domain rules are additive.
// 9. Format selection is deterministic.
// 10. Section modifications cannot mutate the underlying knowledge base.
// 11. Required sections are represented independently from hidden sections.
// 12. A hidden section cannot simultaneously remain required.
// 13. A section modification applies only when its clinical context matches.
// 14. The resolver returns a PLAN, not a diagnosis or clinical decision.
// 15. The knowledge database remains the source of truth.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  ClinicalFormatPlan,
  PatientClinicalState,
} from '../types.js';

// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface FormatRow extends Row {
  format_code: string;
  name: string;
  sort_order: number;
}

interface RuleRow extends Row {
  rule_code: string;
  format_code: string;
  context_type: string;
  context_value: string;
  action: string;
  priority_weight: number;
  rationale: string | null;
}

interface SectionRow extends Row {
  format_code: string;
  section_code: string;
  label: string;
  section_group: string;
  sequence_no: number;
  is_required: boolean;
  default_state: string;
}

interface SectionRuleRow extends Row {
  rule_code: string;
  section_code: string;
  context_type: string;
  context_value: string;
  modification: string;
  priority_weight: number;
}

// =============================================================================
// INTERNAL TYPES
// =============================================================================

type ContextVector = Map<string, Set<string>>;

interface FormatEvaluation {
  formatCode: string;
  score: number;
  blocked: boolean;
  matchedSelectRules: RuleRow[];
  matchedBlockRules: RuleRow[];
}

interface SectionModification {
  sectionCode: string;
  modification: string;
  priorityWeight: number;
  ruleCode: string;
}

// =============================================================================
// CANONICAL CONSTANTS
// =============================================================================

const DEFAULT_FORMAT = 'ADULT_MEDICAL';

/**
 * Canonical clinical context dimensions.
 *
 * These are deliberately finite and explicit. New dimensions should be added
 * here rather than silently encoded inside UI components.
 */
const CONTEXT_TYPES = new Set([
  'AGE_BAND',
  'SEX',
  'PREGNANCY',
  'GESTATIONAL_AGE',
  'DEPARTMENT',
  'ENCOUNTER_TYPE',
  'SYMPTOM_DOMAIN',
  'SYMPTOM',
]);

/**
 * Supported rule actions.
 */
const ACTION_BLOCK = 'BLOCK';
const ACTION_SELECT = 'SELECT';

/**
 * Supported section modifications.
 */
const MOD_HIDE = 'HIDE';
const MOD_REQUIRE = 'REQUIRE';
const MOD_SHOW = 'SHOW';
const MOD_ADD = 'ADD';

// =============================================================================
// FORMAT RESOLVER
// =============================================================================

export class FormatResolver {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /**
   * Resolve the complete clinical format plan for the current patient state.
   *
   * This is intentionally pure from the perspective of clinical reasoning:
   * it does not diagnose, prescribe, or alter patient facts.
   */
  async resolve(state: PatientClinicalState): Promise<ClinicalFormatPlan> {
    // -------------------------------------------------------------------------
    // 1. Load active knowledge required for format resolution.
    // -------------------------------------------------------------------------
    const [formats, rules, sectionRules] = await Promise.all([
      this.loadFormats(),
      this.loadFormatRules(),
      this.loadSectionRules(),
    ]);

    // -------------------------------------------------------------------------
    // 2. Build canonical context vector.
    // -------------------------------------------------------------------------
    const context = buildContextVector(state);

    // -------------------------------------------------------------------------
    // 3. Evaluate every clinical format.
    // -------------------------------------------------------------------------
    const evaluations = formats.map((format) =>
      this.evaluateFormat(format, rules, context),
    );

    // -------------------------------------------------------------------------
    // 4. Select the winning format.
    //
    // BLOCK always wins over SELECT.
    // Highest SELECT score wins.
    // Ties are resolved using clinical_format.sort_order.
    // -------------------------------------------------------------------------
    const winner = this.selectWinningFormat(evaluations, formats);

    const baseFormat = winner?.formatCode ?? DEFAULT_FORMAT;

    // -------------------------------------------------------------------------
    // 5. Load the sections belonging to the selected format.
    // -------------------------------------------------------------------------
    let formatSections = await this.loadFormatSections(baseFormat);

    // -------------------------------------------------------------------------
    // 6. Apply context-specific section modifications.
    // -------------------------------------------------------------------------
    const sectionPlan = this.resolveSections(
      formatSections,
      sectionRules,
      context,
    );

    formatSections = sectionPlan.sections;

    // -------------------------------------------------------------------------
    // 7. Return the canonical context projection.
    //
    // ClinicalFormatPlan intentionally contains context information as well as
    // section modifications so the UI can render exactly what the CPU resolved.
    // -------------------------------------------------------------------------
    return {
      baseFormat,

      ageBand: state.ageBand ?? null,

      sex: normalizeSex(state.sex),

      pregnant: state.pregnant ?? null,

      gestationalAge:
        state.gestationalAgeWeeks != null
          ? `${state.gestationalAgeWeeks} weeks`
          : null,

      department: normalizeNullable(state.departmentCode),

      encounterType: normalizeNullable(state.encounterTypeCode),

      activeDomains: normalizeDomains(state.activeDomains),

      excludedSections: sectionPlan.excludedSections,

      additionalSections: sectionPlan.additionalSections,

      requiredSections: sectionPlan.requiredSections,
    };
  }

  // ===========================================================================
  // DATABASE LOADERS
  // ===========================================================================

  private async loadFormats(): Promise<FormatRow[]> {
    return this.db.query<FormatRow>(
      `
      SELECT
        format_code,
        name,
        sort_order
      FROM knowledge.clinical_format
      WHERE status = 'active'
      ORDER BY sort_order, format_code
      `,
    );
  }

  private async loadFormatRules(): Promise<RuleRow[]> {
    return this.db.query<RuleRow>(
      `
      SELECT
        rule_code,
        format_code,
        context_type,
        context_value,
        action,
        priority_weight,
        rationale
      FROM knowledge.format_context_rule
      WHERE status = 'active'
      ORDER BY format_code, context_type, context_value, rule_code
      `,
    );
  }

  private async loadSectionRules(): Promise<SectionRuleRow[]> {
    return this.db.query<SectionRuleRow>(
      `
      SELECT
        rule_code,
        section_code,
        context_type,
        context_value,
        modification,
        priority_weight
      FROM knowledge.section_context_rule
      WHERE status = 'active'
      ORDER BY
        section_code,
        priority_weight DESC,
        rule_code
      `,
    );
  }

  private async loadFormatSections(
    formatCode: string,
  ): Promise<SectionRow[]> {
    return this.db.query<SectionRow>(
      `
      SELECT
        format_code,
        section_code,
        label,
        section_group,
        sequence_no,
        is_required,
        default_state
      FROM knowledge.clinical_format_section
      WHERE format_code = $1
      ORDER BY sequence_no, section_code
      `,
      [formatCode],
    );
  }

  // ===========================================================================
  // FORMAT EVALUATION
  // ===========================================================================

  private evaluateFormat(
    format: FormatRow,
    rules: RuleRow[],
    context: ContextVector,
  ): FormatEvaluation {
    let score = 0;
    let blocked = false;

    const matchedSelectRules: RuleRow[] = [];
    const matchedBlockRules: RuleRow[] = [];

    for (const rule of rules) {
      if (!sameCode(rule.format_code, format.format_code)) {
        continue;
      }

      if (!isSupportedContextType(rule.context_type)) {
        continue;
      }

      if (
        !contextMatches(
          rule.context_type,
          rule.context_value,
          context,
        )
      ) {
        continue;
      }

      const action = normalizeAction(rule.action);

      // -----------------------------------------------------------------------
      // BLOCK
      // -----------------------------------------------------------------------
      //
      // A BLOCK is absolute. It cannot be outweighed by SELECT rules.
      //
      // Example:
      //
      //   SEX = male
      //   ACTION = BLOCK
      //   FORMAT = OBGYN
      //
      // OBGYN is excluded even if DEPARTMENT = obstetrics.
      // -----------------------------------------------------------------------
      if (action === ACTION_BLOCK) {
        blocked = true;
        matchedBlockRules.push(rule);
        continue;
      }

      // -----------------------------------------------------------------------
      // SELECT
      // -----------------------------------------------------------------------
      if (action === ACTION_SELECT) {
        const weight = finiteNumber(rule.priority_weight);

        score += weight;
        matchedSelectRules.push(rule);
      }
    }

    return {
      formatCode: format.format_code,
      score,
      blocked,
      matchedSelectRules,
      matchedBlockRules,
    };
  }

  // ===========================================================================
  // FORMAT WINNER
  // ===========================================================================

  private selectWinningFormat(
    evaluations: FormatEvaluation[],
    formats: FormatRow[],
  ): FormatEvaluation | null {
    if (evaluations.length === 0) {
      return null;
    }

    const sortOrder = new Map(
      formats.map((format) => [
        format.format_code,
        finiteNumber(format.sort_order),
      ]),
    );

    const eligible = evaluations.filter(
      (evaluation) => !evaluation.blocked,
    );

    if (eligible.length === 0) {
      return null;
    }

    return eligible.reduce<FormatEvaluation | null>(
      (best, candidate) => {
        if (!best) {
          return candidate;
        }

        // Highest clinical selection score wins.
        if (candidate.score > best.score) {
          return candidate;
        }

        if (candidate.score < best.score) {
          return best;
        }

        // Deterministic tie-break.
        const candidateOrder =
          sortOrder.get(candidate.formatCode) ??
          Number.MAX_SAFE_INTEGER;

        const bestOrder =
          sortOrder.get(best.formatCode) ??
          Number.MAX_SAFE_INTEGER;

        if (candidateOrder < bestOrder) {
          return candidate;
        }

        if (candidateOrder > bestOrder) {
          return best;
        }

        // Final deterministic tie-break.
        return candidate.formatCode.localeCompare(best.formatCode) < 0
          ? candidate
          : best;
      },
      null,
    );
  }

  // ===========================================================================
  // SECTION RESOLUTION
  // ===========================================================================

  private resolveSections(
    baseSections: SectionRow[],
    sectionRules: SectionRuleRow[],
    context: ContextVector,
  ): {
    sections: SectionRow[];
    excludedSections: string[];
    additionalSections: string[];
    requiredSections: string[];
  } {
    // -------------------------------------------------------------------------
    // Start from the sections explicitly attached to the selected format.
    // -------------------------------------------------------------------------
    const sectionMap = new Map<string, SectionRow>();

    for (const section of baseSections) {
      sectionMap.set(section.section_code, section);
    }

    // -------------------------------------------------------------------------
    // Only the strongest applicable rule for a given section/modification
    // should drive the result.
    //
    // This prevents duplicate seed generations from producing nondeterministic
    // section states.
    // -------------------------------------------------------------------------
    const applicable = this.collectApplicableSectionRules(
      sectionRules,
      context,
    );

    // -------------------------------------------------------------------------
    // Resolve HIDE first.
    //
    // HIDE has precedence over SHOW/ADD/REQUIRE because displaying a section
    // explicitly prohibited by a matching contextual rule would be unsafe.
    // -------------------------------------------------------------------------
    const hidden = new Set<string>();

    for (const modification of applicable.values()) {
      if (modification.modification === MOD_HIDE) {
        hidden.add(modification.sectionCode);
      }
    }

    // -------------------------------------------------------------------------
    // Apply HIDE.
    // -------------------------------------------------------------------------
    for (const sectionCode of hidden) {
      sectionMap.delete(sectionCode);
    }

    // -------------------------------------------------------------------------
    // Additional sections.
    // -------------------------------------------------------------------------
    const additionalSections: string[] = [];

    for (const modification of applicable.values()) {
      if (hidden.has(modification.sectionCode)) {
        continue;
      }

      if (
        modification.modification === MOD_ADD ||
        modification.modification === MOD_SHOW
      ) {
        if (!sectionMap.has(modification.sectionCode)) {
          const additional = this.makeAdditionalSection(
            modification.sectionCode,
            baseSections,
          );

          if (additional) {
            sectionMap.set(
              modification.sectionCode,
              additional,
            );
          }

          if (!additionalSections.includes(modification.sectionCode)) {
            additionalSections.push(modification.sectionCode);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Required sections.
    //
    // A required section must be visible. Therefore a HIDE rule wins.
    // -------------------------------------------------------------------------
    const requiredSections: string[] = [];

    for (const section of sectionMap.values()) {
      if (
        section.is_required &&
        !hidden.has(section.section_code)
      ) {
        requiredSections.push(section.section_code);
      }
    }

    for (const modification of applicable.values()) {
      if (
        modification.modification !== MOD_REQUIRE ||
        hidden.has(modification.sectionCode)
      ) {
        continue;
      }

      if (!requiredSections.includes(modification.sectionCode)) {
        requiredSections.push(modification.sectionCode);
      }

      // REQUIRE may refer to a section not originally present in the format.
      if (!sectionMap.has(modification.sectionCode)) {
        const additional = this.makeAdditionalSection(
          modification.sectionCode,
          baseSections,
        );

        if (additional) {
          sectionMap.set(
            modification.sectionCode,
            {
              ...additional,
              is_required: true,
            },
          );

          if (!additionalSections.includes(modification.sectionCode)) {
            additionalSections.push(modification.sectionCode);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Final deterministic section order.
    // -------------------------------------------------------------------------
    const sections = [...sectionMap.values()].sort((a, b) => {
      const sequence =
        finiteNumber(a.sequence_no) -
        finiteNumber(b.sequence_no);

      if (sequence !== 0) {
        return sequence;
      }

      return a.section_code.localeCompare(b.section_code);
    });

    return {
      sections,
      excludedSections: [...hidden].sort(),
      additionalSections: unique(additionalSections).sort(),
      requiredSections: unique(requiredSections).sort(),
    };
  }

  // ===========================================================================
  // APPLICABLE SECTION RULES
  // ===========================================================================

  private collectApplicableSectionRules(
    rules: SectionRuleRow[],
    context: ContextVector,
  ): Map<string, SectionModification> {
    const strongest = new Map<string, SectionModification>();

    for (const rule of rules) {
      if (!isSupportedContextType(rule.context_type)) {
        continue;
      }

      if (
        !contextMatches(
          rule.context_type,
          rule.context_value,
          context,
        )
      ) {
        continue;
      }

      const modification = normalizeModification(
        rule.modification,
      );

      if (!modification) {
        continue;
      }

      const candidate: SectionModification = {
        sectionCode: rule.section_code,
        modification,
        priorityWeight: finiteNumber(rule.priority_weight),
        ruleCode: rule.rule_code,
      };

      const existing = strongest.get(rule.section_code);

      if (!existing) {
        strongest.set(rule.section_code, candidate);
        continue;
      }

      // -----------------------------------------------------------------------
      // Conflict precedence:
      //
      // HIDE > REQUIRE > SHOW/ADD
      //
      // Within the same class, highest priority wins.
      // Final tie-break is rule_code for deterministic execution.
      // -----------------------------------------------------------------------
      const candidateRank = modificationRank(candidate.modification);
      const existingRank = modificationRank(existing.modification);

      if (candidateRank > existingRank) {
        strongest.set(rule.section_code, candidate);
        continue;
      }

      if (candidateRank < existingRank) {
        continue;
      }

      if (
        candidate.priorityWeight >
        existing.priorityWeight
      ) {
        strongest.set(rule.section_code, candidate);
        continue;
      }

      if (
        candidate.priorityWeight ===
          existing.priorityWeight &&
        candidate.ruleCode.localeCompare(existing.ruleCode) < 0
      ) {
        strongest.set(rule.section_code, candidate);
      }
    }

    return strongest;
  }

  // ===========================================================================
  // ADDITIONAL SECTION CONSTRUCTION
  // ===========================================================================

  /**
   * Section context rules may request a section that is not part of the base
   * format. The current schema does not carry a complete independent section
   * catalogue in section_context_rule, so we can only materialize a section
   * that exists somewhere in clinical_format_section.
   */
  private makeAdditionalSection(
    sectionCode: string,
    knownSections: SectionRow[],
  ): SectionRow | null {
    const known = knownSections.find(
      (section) => section.section_code === sectionCode,
    );

    if (!known) {
      return null;
    }

    return {
      ...known,
      is_required: false,
      default_state: 'visible',
    };
  }
}

// =============================================================================
// CONTEXT VECTOR
// =============================================================================

/**
 * Convert PatientClinicalState into a normalized multidimensional clinical
 * context vector.
 *
 * Multiple values may exist for one dimension:
 *
 *   SYMPTOM_DOMAIN → RESPIRATORY, SYSTEMIC
 *   SYMPTOM        → cough, fever, dyspnoea
 *
 * This permits rules such as:
 *
 *   SYMPTOM_DOMAIN = RESPIRATORY
 *   SYMPTOM = dyspnoea
 *
 * without requiring the UI to know how those rules work.
 */
function buildContextVector(
  state: PatientClinicalState,
): ContextVector {
  const vector: ContextVector = new Map();

  const add = (
    dimension: string,
    value: string | null | undefined,
  ): void => {
    const normalizedDimension = normalizeCode(dimension);
    const normalizedValue = normalizeContextValue(value);

    if (!normalizedValue) {
      return;
    }

    const set =
      vector.get(normalizedDimension) ??
      new Set<string>();

    set.add(normalizedValue);

    vector.set(normalizedDimension, set);
  };

  // ---------------------------------------------------------------------------
  // Demographic context
  // ---------------------------------------------------------------------------
  add('AGE_BAND', state.ageBand);

  add('SEX', normalizeSex(state.sex));

  // ---------------------------------------------------------------------------
  // Pregnancy context
  //
  // Pregnancy is explicitly resolved by ContextResolver. This resolver must
  // never infer pregnancy from sex.
  // ---------------------------------------------------------------------------
  if (state.pregnant !== null && state.pregnant !== undefined) {
    add(
      'PREGNANCY',
      state.pregnant
        ? 'pregnant'
        : 'not_pregnant',
    );
  }

  // ---------------------------------------------------------------------------
  // Gestational age context
  //
  // Expose useful canonical bands in addition to the exact week value.
  // ---------------------------------------------------------------------------
  if (state.gestationalAgeWeeks != null) {
    const weeks = Number(state.gestationalAgeWeeks);

    if (Number.isFinite(weeks) && weeks >= 0) {
      add(
        'GESTATIONAL_AGE',
        `weeks_${formatNumber(weeks)}`,
      );

      if (weeks < 20) {
        add('GESTATIONAL_AGE', 'first_half');
      } else if (weeks < 28) {
        add('GESTATIONAL_AGE', 'pre_viability');
      } else if (weeks < 37) {
        add('GESTATIONAL_AGE', 'preterm');
      } else if (weeks < 42) {
        add('GESTATIONAL_AGE', 'term');
      } else {
        add('GESTATIONAL_AGE', 'post_term');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Encounter context
  // ---------------------------------------------------------------------------
  add(
    'DEPARTMENT',
    state.departmentCode,
  );

  add(
    'ENCOUNTER_TYPE',
    normalizeEncounterType(state.encounterTypeCode),
  );

  // ---------------------------------------------------------------------------
  // Symptom context
  // ---------------------------------------------------------------------------
  for (const domain of normalizeDomains(state.activeDomains)) {
    add('SYMPTOM_DOMAIN', domain);
  }

  for (const symptom of normalizeSymptoms(state.activeSymptoms)) {
    add('SYMPTOM', symptom);
  }

  return vector;
}

// =============================================================================
// CONTEXT MATCHING
// =============================================================================

/**
 * Match one knowledge rule against the normalized clinical context.
 *
 * Rules are fail-closed:
 *
 *   missing context → false
 *
 * This is critical clinically. Lack of evidence that a patient is pregnant,
 * for example, must NOT satisfy a PREGNANCY=pregnant rule.
 */
function contextMatches(
  contextType: string,
  contextValue: string,
  vector: ContextVector,
): boolean {
  const dimension = normalizeCode(contextType);
  const expected = normalizeContextValue(contextValue);

  if (!dimension || !expected) {
    return false;
  }

  const values = vector.get(dimension);

  if (!values || values.size === 0) {
    return false;
  }

  // Exact normalized match.
  if (values.has(expected)) {
    return true;
  }

  // ---------------------------------------------------------------------------
  // Clinical wildcard support.
  //
  // Knowledge may explicitly use:
  //
  //   *
  //   ALL
  //   ANY
  //
  // only as an explicit rule value.
  // ---------------------------------------------------------------------------
  if (
    expected === '*' ||
    expected === 'ALL' ||
    expected === 'ANY'
  ) {
    return true;
  }

  // ---------------------------------------------------------------------------
  // Symptom/domain aliases.
  // ---------------------------------------------------------------------------
  for (const actual of values) {
    if (canonicalContextEquivalent(dimension, actual, expected)) {
      return true;
    }
  }

  return false;
}

// =============================================================================
// CONTEXT NORMALIZATION
// =============================================================================

function normalizeSex(
  sex: string | null | undefined,
): string | null {
  if (sex == null) {
    return null;
  }

  const value = sex.trim().toLowerCase();

  switch (value) {
    case 'm':
    case 'male':
      return 'male';

    case 'f':
    case 'female':
      return 'female';

    case 'other':
    case 'intersex':
    case 'non_binary':
    case 'non-binary':
      return value.replace('-', '_');

    default:
      return value || null;
  }
}

function normalizeEncounterType(
  value: string | null | undefined,
): string | null {
  if (value == null) {
    return null;
  }

  const normalized = value
    .trim()
    .toLowerCase();

  switch (normalized) {
    case 'ipd':
    case 'inpatient':
    case 'admission':
    case 'admitted':
      return 'inpatient';

    case 'opd':
    case 'outpatient':
    case 'clinic':
      return 'outpatient';

    case 'emergency':
    case 'ed':
    case 'a&e':
    case 'accident_and_emergency':
      return 'emergency';

    case 'day_case':
    case 'daycase':
      return 'day_case';

    default:
      return normalized || null;
  }
}

function normalizeDomains(
  domains: string[] | null | undefined,
): string[] {
  if (!domains) {
    return [];
  }

  return unique(
    domains
      .map((domain) => normalizeCode(domain))
      .filter(Boolean),
  ).sort();
}

function normalizeSymptoms(
  symptoms: string[] | null | undefined,
): string[] {
  if (!symptoms) {
    return [];
  }

  return unique(
    symptoms
      .map((symptom) => symptom.trim().toLowerCase())
      .filter(Boolean),
  ).sort();
}

function normalizeContextValue(
  value: string | null | undefined,
): string {
  if (value == null) {
    return '';
  }

  return value
    .trim()
    .toUpperCase();
}

function normalizeCode(
  value: string | null | undefined,
): string {
  if (value == null) {
    return '';
  }

  return value
    .trim()
    .toUpperCase();
}

function sameCode(
  a: string | null | undefined,
  b: string | null | undefined,
): boolean {
  return normalizeCode(a) === normalizeCode(b);
}

function normalizeNullable(
  value: string | null | undefined,
): string | null {
  if (value == null) {
    return null;
  }

  const normalized = value.trim();

  return normalized || null;
}

// =============================================================================
// CONTEXT EQUIVALENCE
// =============================================================================

function canonicalContextEquivalent(
  dimension: string,
  actual: string,
  expected: string,
): boolean {
  if (actual === expected) {
    return true;
  }

  // ---------------------------------------------------------------------------
  // Sex aliases.
  // ---------------------------------------------------------------------------
  if (dimension === 'SEX') {
    return (
      canonicalSexCode(actual) ===
      canonicalSexCode(expected)
    );
  }

  // ---------------------------------------------------------------------------
  // Encounter aliases.
  // ---------------------------------------------------------------------------
  if (dimension === 'ENCOUNTER_TYPE') {
    return (
      normalizeEncounterType(actual) ===
      normalizeEncounterType(expected)
    );
  }

  // ---------------------------------------------------------------------------
  // Common age-band aliases.
  // ---------------------------------------------------------------------------
  if (dimension === 'AGE_BAND') {
    return canonicalAgeBandCode(actual) ===
      canonicalAgeBandCode(expected);
  }

  // ---------------------------------------------------------------------------
  // Pregnancy aliases.
  // ---------------------------------------------------------------------------
  if (dimension === 'PREGNANCY') {
    return canonicalPregnancyCode(actual) ===
      canonicalPregnancyCode(expected);
  }

  return false;
}

function canonicalSexCode(value: string): string {
  switch (value.toLowerCase()) {
    case 'm':
    case 'male':
      return 'MALE';

    case 'f':
    case 'female':
      return 'FEMALE';

    default:
      return value.toUpperCase();
  }
}

function canonicalPregnancyCode(value: string): string {
  const normalized = value
    .trim()
    .toLowerCase();

  if (
    normalized === 'yes' ||
    normalized === 'true' ||
    normalized === 'pregnant'
  ) {
    return 'PREGNANT';
  }

  if (
    normalized === 'no' ||
    normalized === 'false' ||
    normalized === 'not_pregnant'
  ) {
    return 'NOT_PREGNANT';
  }

  return normalized.toUpperCase();
}

function canonicalAgeBandCode(value: string): string {
  const normalized = value
    .trim()
    .toUpperCase();

  const aliases: Record<string, string> = {
    NEONATE: 'NEONATE',
    NEWBORN: 'NEONATE',

    INFANT: 'INFANT',
    BABY: 'INFANT',

    CHILD: 'CHILD',
    PAEDIATRIC_CHILD: 'CHILD',
    PEDIATRIC_CHILD: 'CHILD',

    ADOLESCENT: 'ADOLESCENT',
    TEENAGER: 'ADOLESCENT',

    ADULT: 'ADULT',
  };

  return aliases[normalized] ?? normalized;
}

// =============================================================================
// RULE NORMALIZATION
// =============================================================================

function normalizeAction(
  value: string | null | undefined,
): string {
  return (value ?? '')
    .trim()
    .toUpperCase();
}

function normalizeModification(
  value: string | null | undefined,
): string | null {
  const normalized = (value ?? '')
    .trim()
    .toUpperCase();

  switch (normalized) {
    case MOD_HIDE:
      return MOD_HIDE;

    case MOD_REQUIRE:
      return MOD_REQUIRE;

    case MOD_SHOW:
      return MOD_SHOW;

    case MOD_ADD:
      return MOD_ADD;

    default:
      return null;
  }
}

function modificationRank(
  modification: string,
): number {
  switch (modification) {
    case MOD_HIDE:
      return 4;

    case MOD_REQUIRE:
      return 3;

    case MOD_SHOW:
    case MOD_ADD:
      return 2;

    default:
      return 0;
  }
}

function isSupportedContextType(
  contextType: string | null | undefined,
): boolean {
  if (!contextType) {
    return false;
  }

  return CONTEXT_TYPES.has(
    normalizeCode(contextType),
  );
}

// =============================================================================
// AGE / GESTATIONAL HELPERS
// =============================================================================

function formatNumber(value: number): string {
  if (Number.isInteger(value)) {
    return String(value);
  }

  return String(
    Math.round(value * 100) / 100,
  );
}

// =============================================================================
// GENERAL UTILITIES
// =============================================================================

function finiteNumber(
  value: unknown,
): number {
  const number = Number(value);

  return Number.isFinite(number)
    ? number
    : 0;
}

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}