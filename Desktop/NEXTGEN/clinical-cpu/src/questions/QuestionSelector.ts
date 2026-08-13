// =============================================================================
// AMEXAN Clinical CPU — QuestionSelector
// The adaptive interview. Instead of showing every cough question, the CPU
// selects the highest-value NEXT questions: only those whose trigger symptom is
// active, whose trigger fact exists, or whose answer feeds the current
// reasoning. Answered questions and already-captured facts drop out.
//
// Selection is an optimization: requirement level, trigger/question priority,
// information gain (does the mapped fact appear in the leading phenotype's
// features?) and safety value (does it probe a red flag?).
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, Fact, MechanismScore, NextQuestion, PatientClinicalState, PhenotypeScore } from '../types.js';

interface QuestionRow extends Row {
  question_code: string;
  text: string;
  response_type: string;
  priority: number;
  is_active: boolean;
}

interface TriggerRow extends Row {
  question_code: string;
  trigger_type: string;
  trigger_code: string;
  priority: number;
}

interface RequirementRow extends Row {
  question_code: string;
  requirement_level: string;
  condition: unknown;
  priority: number;
}

interface ContextExclusionRow extends Row {
  question_code: string;
  context_type_code: string;
  context_value: string;
  applicability: string;
}

interface OptionRow extends Row {
  question_code: string;
  answer_code: string;
  label: string;
  sort_order: number;
  is_active: boolean;
}

interface MappingRow extends Row {
  question_code: string;
  fact_definition_code: string;
}

interface QuestionFactRow extends Row {
  question_code: string;
  fact_definition_code: string;
  unit_code: string | null;
}

interface ModuleMemberRow extends Row {
  module_code: string;
  question_code: string;
}

interface RuleRow extends Row {
  rule_id: string;
  trigger_type: string;
  trigger_code: string;
  trigger_operator: string;
  trigger_value: unknown;
  action: string;
  target_type: string;
  target_code: string;
  priority_delta: number;
}

interface DependencyRow extends Row {
  question_code: string;
  prerequisite_type: string;
  prerequisite_code: string;
  operator: string;
  value: unknown;
  is_blocking: boolean;
}

interface RedFlagRuleRow extends Row {
  fact_definition_code: string | null;
  urgency: string;
}

// H4: red flags are DB-driven (knowledge.red_flag_rule = FACT + CONTEXT +
// SIGNIFICANCE), not a hardcoded list. Emergency-tier rules outrank urgent.
const RED_FLAG_BOOST: Record<string, number> = { emergency: 14, urgent: 8 };

// H3 levels: safety outranks mandatory (a red-flag probe is never delayed),
// high_priority sits between conditionally_required and optional.
const REQUIREMENT_RANK: Record<string, number> = {
  safety: 0,
  mandatory: 1,
  conditionally_required: 2,
  high_priority: 3,
  optional: 4,
  informational: 5,
};

export interface QuestionSelectionOptions {
  limit?: number;
}

export class QuestionSelector {
  constructor(private readonly db: Db) {}

  async select(
    state: PatientClinicalState,
    phenotypes: PhenotypeScore[],
    mechanisms: MechanismScore[],
    differentials: DifferentialCandidate[],
    options: QuestionSelectionOptions = {},
  ): Promise<NextQuestion[]> {
    const limit = options.limit ?? 8;
    const [questions, triggers, requirements, contextRows, optionsRows, mappings, questionFacts,
      moduleMembers, rules, dependencies, redFlagRules] = await Promise.all([
      this.db.query<QuestionRow>(
        `SELECT question_code, text, response_type, priority, is_active FROM knowledge.question WHERE is_active ORDER BY question_code`,
      ),
      this.db.query<TriggerRow>(
        `SELECT q.question_code, qt.trigger_type, qt.trigger_code, qt.priority
           FROM knowledge.question_trigger qt JOIN knowledge.question q ON q.id = qt.question_id`,
      ),
      this.db.query<RequirementRow>(
        `SELECT q.question_code, qr.requirement_level, qr.condition, qr.priority
           FROM knowledge.question_requirement qr JOIN knowledge.question q ON q.id = qr.question_id`,
      ),
      this.db.query<ContextExclusionRow>(
        `SELECT q.question_code, cv.context_type_code, cv.value AS context_value, qc.applicability
           FROM knowledge.question_context qc
           JOIN knowledge.question q ON q.id = qc.question_id
           JOIN knowledge.context_value cv ON cv.id = qc.context_value_id`,
      ),
      this.db.query<OptionRow>(
        `SELECT q.question_code, ao.answer_code, ao.label, ao.sort_order, ao.is_active
           FROM knowledge.answer_option ao JOIN knowledge.question q ON q.id = ao.question_id
          WHERE ao.is_active ORDER BY q.question_code, ao.sort_order`,
      ),
      this.db.query<MappingRow>(
        `SELECT q.question_code, fm.fact_definition_code
           FROM knowledge.fact_mapping fm
           JOIN knowledge.answer_option ao ON ao.id = fm.answer_option_id
           JOIN knowledge.question q ON q.id = ao.question_id`,
      ),
      this.db.query<QuestionFactRow>(
        `SELECT q.question_code, qf.fact_definition_code, qf.unit_code
           FROM knowledge.question_fact qf JOIN knowledge.question q ON q.id = qf.question_id`,
      ),
      this.db.query<ModuleMemberRow>(
        `SELECT qmm.module_code, q.question_code
           FROM knowledge.question_module_member qmm
           JOIN knowledge.question q ON q.id = qmm.question_id`,
      ),
      this.db.query<RuleRow>(
        `SELECT rule_id, trigger_type, trigger_code, trigger_operator, trigger_value, action,
                target_type, target_code, priority_delta
           FROM knowledge.question_rule
          WHERE status = 'active'`,
      ),
      this.db.query<DependencyRow>(
        `SELECT q.question_code, qd.prerequisite_type, qd.prerequisite_code, qd.operator, qd.value, qd.is_blocking
           FROM knowledge.question_dependency qd
           JOIN knowledge.question q ON q.id = qd.question_id
          WHERE qd.is_blocking = true`,
      ),
      // H4: red-flag rules (FACT + CONTEXT + SIGNIFICANCE) drive the safety boost.
      this.db.query<RedFlagRuleRow>(
        `SELECT fact_definition_code, urgency FROM knowledge.red_flag_rule
          WHERE status = 'active' AND fact_definition_code IS NOT NULL`,
      ),
    ]);

    const triggersByQuestion = groupBy<TriggerRow>(triggers, 'question_code');
    const requirementsByQuestion = groupBy<RequirementRow>(requirements, 'question_code');
    const contextByQuestion = groupBy<ContextExclusionRow>(contextRows, 'question_code');
    const optionsByQuestion = groupBy<OptionRow>(optionsRows, 'question_code');
    const mappingsByQuestion = groupBy<MappingRow>(mappings, 'question_code');
    const questionFactByQuestion = new Map<string, QuestionFactRow>(
      questionFacts.map((f) => [f.question_code, f]),
    );

    // H4: highest red-flag urgency tier among the facts a question can capture.
    const redFlagBoostByFact = new Map<string, number>();
    for (const rule of redFlagRules) {
      if (!rule.fact_definition_code) continue;
      const boost = RED_FLAG_BOOST[rule.urgency] ?? 0;
      const existing = redFlagBoostByFact.get(rule.fact_definition_code) ?? 0;
      if (boost > existing) redFlagBoostByFact.set(rule.fact_definition_code, boost);
    }

    // H3: expand question modules so a rule targeting a module applies to every
    // member question (cough_core → onset/duration/productivity/...).
    const modulesByQuestion = groupBy<ModuleMemberRow>(moduleMembers, 'question_code');
    const modulesByCode = new Map<string, string[]>();
    for (const m of moduleMembers) {
      const list = modulesByCode.get(m.module_code) ?? [];
      list.push(m.question_code);
      modulesByCode.set(m.module_code, list);
    }

    const patientAgeBucket = ageBucket(state.ageYears);
    const rulesByQuestion = new Map<string, { activateDelta: number; deactivated: boolean }>();
    for (const rule of rules) {
      if (!ruleFires(rule, state, patientAgeBucket)) continue;
      const targets: string[] =
        rule.target_type === 'module'
          ? (modulesByCode.get(rule.target_code) ?? [])
          : [rule.target_code];
      for (const target of targets) {
        if (rule.target_type === 'symptom') continue; // symptom activation is handled via triggers
        const entry = rulesByQuestion.get(target) ?? { activateDelta: 0, deactivated: false };
        if (rule.action === 'ACTIVATE') entry.activateDelta += rule.priority_delta;
        else entry.deactivated = true;
        rulesByQuestion.set(target, entry);
      }
    }

    const dependenciesByQuestion = groupBy<DependencyRow>(dependencies, 'question_code');
    const capturedCodes = new Set(state.facts.map((f) => f.factCode));
    const answered = new Set(state.answeredQuestions);
    const activeSymptomSet = state.activeSymptoms.map((s) => s.toLowerCase());

    // Facts referenced by the leading phenotypes = where the next question has
    // the most information value.
    const reasoningFacts = new Set<string>();
    for (const p of phenotypes.slice(0, 2)) {
      const featureRows = await this.db.query<{ feature_code: string }>(
        `SELECT pf.feature_code FROM knowledge.phenotype_feature pf
           JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
          WHERE ph.phenotype_code = $1`,
        [p.phenotypeCode],
      );
      for (const f of featureRows) reasoningFacts.add(f.feature_code);
    }

    const topPhenotypeCodes = new Set(phenotypes.slice(0, 3).map((p) => p.phenotypeCode));
    const topMechanismCodes = new Set(mechanisms.slice(0, 3).map((m) => m.mechanismCode));
    const topConditionCodes = new Set(differentials.slice(0, 3).map((d) => d.conditionCode));

    const nextQuestions: NextQuestion[] = [];
    for (const question of questions) {
      if (answered.has(question.question_code)) continue;

      const questionFact = questionFactByQuestion.get(question.question_code);
      const mappedFacts = (mappingsByQuestion.get(question.question_code) ?? []).map((m) => m.fact_definition_code);
      const factCodes = questionFact ? [...new Set([...mappedFacts, questionFact.fact_definition_code])] : mappedFacts;

      // A question that cannot become a fact (no mapped answer AND no raw-value
      // binding) has no clinical value — answering it would capture nothing.
      if (factCodes.length === 0) continue;
      if (factCodes.every((code) => capturedCodes.has(code))) continue;

      const requirementRows = requirementsByQuestion.get(question.question_code) ?? [];
      // H3 universal foundation: mandatory / safety questions are always
      // candidates even without a trigger or phenotype-feature link; their
      // requirement condition still gates them below (e.g. only when the gating
      // fact is present).
      const hasFoundationRequirement = requirementRows.some(
        (r) => r.requirement_level === 'mandatory' || r.requirement_level === 'safety',
      );

      const triggersFor = triggersByQuestion.get(question.question_code) ?? [];
      const activated = hasFoundationRequirement
        || (triggersFor.length > 0
          ? triggersFor.some((t) =>
              triggerMatches(t, activeSymptomSet, capturedCodes, topPhenotypeCodes, topMechanismCodes, topConditionCodes))
          : factCodes.some((code) => reasoningFacts.has(code)));

      if (!activated) continue;

      // Context exclusions (medical safety): never ask a question whose AGE
      // context excludes this patient (e.g. adult-only questions for infants).
      const excludedByContext =
        patientAgeBucket != null &&
        (contextByQuestion.get(question.question_code) ?? []).some(
          (c) =>
            c.context_type_code === 'AGE' &&
            c.applicability === 'excludes' &&
            c.context_value === patientAgeBucket,
        );
      if (excludedByContext) continue;

      // H3 blocking dependencies: a question whose blocking prerequisite is not
      // satisfied is not asked (e.g. sputum colour while the cough is dry).
      const blockingDeps = dependenciesByQuestion.get(question.question_code) ?? [];
      if (blockingDeps.some((d) => !dependencySatisfied(d, state))) continue;

      // H3 question rules: a fired DEACTIVATE rule suppresses the question even
      // if its symptom is active; a fired ACTIVATE rule boosts its priority.
      const ruleEffect = rulesByQuestion.get(question.question_code);
      if (ruleEffect?.deactivated) continue;

      // Value-aware socratic gating: a requirement condition only ever RULES A
      // QUESTION OUT — when the gating fact is captured with a value that
      // contradicts the condition (dry cough → no sputum questions, non-smoker
      // → no pack-years, short cough → no chronic-cough probes). When the
      // gating fact is unknown, the question stays eligible.
      if (!requirementRows.every((r) => conditionAllows(r.condition, state.facts))) continue;

      const requirement = bestRequirement(requirementRows);
      const requirementLevel = requirement?.level ?? 'informational';
      const requirementRank = REQUIREMENT_RANK[requirementLevel] ?? 4;

      const triggerPriority = triggersFor.length > 0
        ? Math.min(...triggersFor.map((t) => t.priority))
        : 50;
      const infoGain = factCodes.some((code) => reasoningFacts.has(code)) ? 5 : 0;
      // H4: red-flag rules (DB) boost safety probes above everything else.
      const safetyBoost = Math.max(0, ...factCodes.map((code) => redFlagBoostByFact.get(code) ?? 0));
      // H3 rule delta: ACTIVATE rules pull the question up the queue (lower score).
      const ruleDelta = ruleEffect?.activateDelta ?? 0;

      const utility = requirementRank * 1000 + (question.priority - infoGain - safetyBoost - ruleDelta) + triggerPriority / 100;

      const reason = activationReason(triggersFor, requirementLevel, state, topPhenotypeCodes, hasFoundationRequirement);

      nextQuestions.push({
        questionCode: question.question_code,
        text: question.text,
        responseType: question.response_type,
        requirementLevel,
        priority: round(utility),
        reason,
        options: (optionsByQuestion.get(question.question_code) ?? []).map((o) => ({ answerCode: o.answer_code, label: o.label })),
        factCode: questionFact?.fact_definition_code ?? null,
        unitCode: questionFact?.unit_code ?? null,
      });
    }

    return nextQuestions.sort((a, b) => a.priority - b.priority).slice(0, limit);
  }
}

// Does an H3 question rule fire for this patient?
//   trigger_type 'fact'    → the trigger fact is captured and matches trigger_value
//   trigger_type 'context' → the patient context (AGE bucket) matches
function ruleFires(rule: RuleRow, state: PatientClinicalState, ageBucket: string | null): boolean {
  if (rule.trigger_type === 'context') {
    if (rule.trigger_code === 'AGE') {
      const allowed = rule.trigger_value as string[] | null;
      return ageBucket != null && Array.isArray(allowed) && allowed.includes(ageBucket);
    }
    return false;
  }
  const fact = state.facts.find((f) => f.factCode === rule.trigger_code);
  if (!fact) return false;
  const value = fact.values[0];
  const text = value?.text ?? (value?.boolean != null ? String(value.boolean) : null);
  const numeric = value?.numeric;
  switch (rule.trigger_operator) {
    case 'eq':
      return text != null && text === String(rule.trigger_value);
    case 'gt':
      return numeric != null && numeric > Number(rule.trigger_value);
    case 'gte':
      return numeric != null && numeric >= Number(rule.trigger_value);
    case 'lt':
      return numeric != null && numeric < Number(rule.trigger_value);
    case 'lte':
      return numeric != null && numeric <= Number(rule.trigger_value);
    case 'in': {
      const allowed = rule.trigger_value as unknown[] | null;
      return text != null && Array.isArray(allowed) && allowed.includes(text);
    }
    default:
      return false;
  }
}

// Is a blocking dependency satisfied? A fact prerequisite is satisfied when the
// fact is captured with a matching value (or captured at all when no value set);
// a question prerequisite when the question has been answered.
function dependencySatisfied(dep: DependencyRow, state: PatientClinicalState): boolean {
  if (dep.prerequisite_type === 'question') return state.answeredQuestions.includes(dep.prerequisite_code);
  const fact = state.facts.find((f) => f.factCode === dep.prerequisite_code);
  if (!fact) return false;
  if (dep.value == null) return true;
  const value = fact.values[0];
  const text = value?.text ?? (value?.boolean != null ? String(value.boolean) : null);
  const numeric = value?.numeric;
  switch (dep.operator) {
    case 'eq':
      return text != null && text === String(dep.value);
    case 'in': {
      const allowed = dep.value as unknown[] | null;
      return text != null && Array.isArray(allowed) && allowed.includes(text);
    }
    case 'gt':
      return numeric != null && numeric > Number(dep.value);
    case 'gte':
      return numeric != null && numeric >= Number(dep.value);
    case 'lt':
      return numeric != null && numeric < Number(dep.value);
    case 'lte':
      return numeric != null && numeric <= Number(dep.value);
    default:
      return false;
  }
}

function triggerMatches(
  trigger: TriggerRow,
  activeSymptomSet: string[],
  capturedCodes: Set<string>,
  topPhenotypes: Set<string>,
  topMechanisms: Set<string>,
  topConditions: Set<string>,
): boolean {
  const code = trigger.trigger_code.toLowerCase();
  switch (trigger.trigger_type) {
    case 'symptom':
      return activeSymptomSet.some((s) => s === code || s.includes(code) || code.includes(s));
    case 'fact':
      return capturedCodes.has(trigger.trigger_code);
    case 'phenotype':
      return topPhenotypes.has(trigger.trigger_code);
    case 'mechanism':
      return topMechanisms.has(trigger.trigger_code);
    case 'condition':
      return topConditions.has(trigger.trigger_code);
    default:
      return false;
  }
}

function activationReason(
  triggers: TriggerRow[],
  requirementLevel: string,
  state: PatientClinicalState,
  topPhenotypes: Set<string>,
  foundation = false,
): string {
  if (triggers.length === 0) {
    return foundation
      ? `universal ${requirementLevel} foundation — always asked`
      : `Relevant to the current reasoning (${requirementLevel})`;
  }
  const parts: string[] = [];
  for (const t of triggers) {
    if (t.trigger_type === 'symptom') parts.push(`active symptom: ${t.trigger_code}`);
    else if (t.trigger_type === 'fact') parts.push(`fact present: ${t.trigger_code}`);
    else if (t.trigger_type === 'phenotype') parts.push(`phenotype active: ${t.trigger_code}`);
    else if (t.trigger_type === 'mechanism') parts.push(`mechanism active: ${t.trigger_code}`);
    else if (t.trigger_type === 'condition') parts.push(`differential: ${t.trigger_code}`);
  }
  return `${requirementLevel} — ${parts.join('; ')}`;
}

function bestRequirement(rows: RequirementRow[]): { level: string; priority: number } | null {
  if (rows.length === 0) return null;
  return rows.reduce((best, r) => (r.priority < best.priority ? { level: r.requirement_level, priority: r.priority } : best), {
    level: rows[0].requirement_level,
    priority: rows[0].priority,
  });
}

function groupBy<T extends Row>(rows: T[], key: string): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const row of rows) {
    const value = String((row as Record<string, unknown>)[key]);
    const list = map.get(value) ?? [];
    list.push(row);
    map.set(value, list);
  }
  return map;
}

interface FactCondition {
  code?: string;
  value?: unknown;
  in?: unknown[];
  gt?: number;
  lt?: number;
  gte?: number;
  lte?: number;
}

// A requirement condition is a medical eligibility rule of the form
//   {"fact": {"code": "COUGH_PRODUCTIVITY", "value": "PRODUCTIVE"}}
//   {"fact": {"code": "SMOKING_STATUS", "in": ["CURRENT","FORMER"]}}
//   {"fact": {"code": "COUGH_DURATION_DAYS", "gt": 14}}
// It RULES A QUESTION OUT only when the gating fact is captured with a value
// that contradicts the condition. An uncaptured gating fact never suppresses
// the question ("unknown ≠ no").
function conditionAllows(condition: unknown, facts: Fact[]): boolean {
  if (condition == null || typeof condition !== 'object') return true;
  const cond = condition as { fact?: FactCondition };
  const f = cond.fact;
  if (!f?.code) return true;
  const fact = facts.find((x) => x.factCode === f.code);
  if (!fact) return true;
  const value = fact.values[0];
  const text = value?.text ?? (value?.boolean != null ? String(value.boolean) : null);
  const numeric = value?.numeric;
  if (Array.isArray(f.in)) return text != null && f.in.includes(text);
  if (f.value !== undefined) return text === String(f.value);
  const hasNumericOp = f.gt !== undefined || f.lt !== undefined || f.gte !== undefined || f.lte !== undefined;
  if (hasNumericOp) {
    if (numeric == null) return false;
    if (f.gt !== undefined && !(numeric > f.gt)) return false;
    if (f.lt !== undefined && !(numeric < f.lt)) return false;
    if (f.gte !== undefined && !(numeric >= f.gte)) return false;
    if (f.lte !== undefined && !(numeric <= f.lte)) return false;
    return true;
  }
  return text != null;
}

// Map a patient's age in years to the knowledge AGE context bucket so that
// age-based exclusions can be applied (medical safety).
function ageBucket(ageYears: number | null): string | null {
  if (ageYears == null) return null;
  if (ageYears < 28 / 365.25) return '0-28D';
  if (ageYears < 1) return '1-11M';
  if (ageYears < 5) return '1-4Y';
  if (ageYears < 18) return '5-17Y';
  if (ageYears < 65) return '18-64Y';
  return '65P';
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}
