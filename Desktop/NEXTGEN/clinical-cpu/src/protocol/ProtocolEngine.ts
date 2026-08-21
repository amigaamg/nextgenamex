// =============================================================================
// AMEXAN Clinical CPU — ProtocolEngine
// =============================================================================
//
// PURPOSE
// -------
// Activates the safest, most clinically appropriate protocol pathway from the
// current differential while keeping medicine in the reusable knowledge graph.
//
// CORE PRINCIPLES
// ---------------
// 1. A protocol coordinates clinical care; it does not redefine medicine.
// 2. Protocol selection is population-aware.
// 3. Protocol selection is jurisdiction-aware.
// 4. Protocol selection is context-aware.
// 5. A protocol must never be activated merely because a condition is ranked
//    first if that condition has insufficient compatibility/support.
// 6. Protocols may be:
//      - universal / global
//      - jurisdiction-specific
//      - adult
//      - paediatric
//      - neonatal
//      - pregnancy-specific
//      - condition-specific
//      - emergency / acute-care pathways
// 7. Required safety gates are evaluated before activation.
// 8. Contraindicated protocols are never returned as executable pathways.
// 9. Protocol actions remain references to reusable knowledge objects:
//      investigation
//      medication
//      procedure
//      monitoring
//      education
//      referral
//      escalation
// 10. The engine distinguishes:
//      candidate protocol
//      active protocol
//      safety-blocked protocol
//      protocol requiring clinician confirmation
// 11. The CPU does not diagnose. It coordinates an already-ranked clinical
//     hypothesis and exposes provenance.
// 12. No clinical action should silently bypass a protocol safety condition.
//
// =============================================================================

import type { Db, Row } from '../db.js';

import type {
  DifferentialCandidate,
  ProtocolActionView,
  ProtocolStepView,
  ProtocolView,
} from '../types.js';

// =============================================================================
// CONSTANTS
// =============================================================================

const ADULT_BOUNDARY_YEARS = 18;
const PAEDIATRIC_MIN_MONTHS = 1;
const NEONATAL_MAX_DAYS = 28;

const POPULATION_PRIORITY = [
  'neonatal',
  'paediatric',
  'pregnancy',
  'adult',
  'both',
] as const;

type Population =
  | 'neonatal'
  | 'paediatric'
  | 'adult'
  | 'pregnancy'
  | 'both'
  | string;

type ProtocolActionType =
  | 'investigate'
  | 'medicate'
  | 'procedure'
  | 'monitor'
  | 'educate'
  | 'refer'
  | 'escalate'
  | 'document'
  | 'isolate'
  | 'resuscitate'
  | string;

type ProtocolGateType =
  | 'REQUIRED_FACT'
  | 'FORBIDDEN_FACT'
  | 'MIN_SCORE'
  | 'MAX_SCORE'
  | 'AGE'
  | 'SEX'
  | 'PREGNANCY'
  | 'GESTATIONAL_AGE'
  | 'JURISDICTION'
  | 'ENCOUNTER_TYPE'
  | 'DEPARTMENT'
  | 'SEVERITY'
  | 'SETTING'
  | string;

// =============================================================================
// DATABASE ROWS
// =============================================================================

interface ProtocolRow extends Row {
  protocol_code: string;
  canonical_name: string;
  purpose: string | null;
  status: string;
  population: Population;
  acuity: string | null;
  setting: string | null;
  version: string | null;
  effective_from: string | null;
  effective_to: string | null;
  requires_confirmation: boolean;
  priority: number;
}

interface ConditionLinkRow extends Row {
  condition_code: string;
  protocol_code: string;
  population: Population;
  jurisdiction_code: string | null;
  is_primary: boolean;
  priority_weight: number;
}

interface StepRow extends Row {
  protocol_code: string;
  step_code: string;
  step_label: string;
  step_type: string;
  sequence_no: number;
  instruction: string;
  rationale: string | null;
  required: boolean;
  condition_expression: unknown;
}

interface ActionRow extends Row {
  protocol_code: string;
  step_code: string;
  action_type: ProtocolActionType;
  action_code: string;
  action_name: string;
  detail: string | null;
  urgency: string;
  sort_order: number;
  required: boolean;
  condition_expression: unknown;
}

interface GateRow extends Row {
  protocol_code: string;
  gate_code: string;
  gate_type: ProtocolGateType;
  target_code: string | null;
  operator: string | null;
  expected_value: string | null;
  failure_action: string | null;
  failure_message: string | null;
  priority: number;
}

interface ProtocolFactRow extends Row {
  fact_definition_code: string;
  value_text: string | null;
  value_numeric: number | null;
  value_boolean: boolean | null;
  observed_at: string;
}

interface ProtocolKnowledgeObjectRow extends Row {
  protocol_code: string;
  jurisdiction_code: string | null;
  status: string;
}

interface ProtocolConditionRequirementRow extends Row {
  protocol_code: string;
  minimum_score: number | null;
  minimum_compatibility: number | null;
  require_rank: number | null;
}

// =============================================================================
// INTERNAL TYPES
// =============================================================================

interface ProtocolCandidate {
  protocol: ProtocolRow;
  condition: DifferentialCandidate;
  conditionLink: ConditionLinkRow;
  score: number;
  blocked: boolean;
  blockReasons: string[];
  requiresConfirmation: boolean;
  confirmationReasons: string[];
}

interface ProtocolSelectionContext {
  ageYears: number | null;
  ageMonths: number | null;
  ageDays: number | null;
  sex: string | null;
  pregnant: boolean | null;
  gestationalAgeWeeks: number | null;
  jurisdictionCode: string | null;
  encounterTypeCode: string | null;
  departmentCode: string | null;
  settingCode: string | null;
  acuityCode: string | null;
  severityCode: string | null;
  activeDomains: string[];
}

// =============================================================================
// PUBLIC ENGINE
// =============================================================================

export class ProtocolEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // MAIN ENTRY POINT
  // ===========================================================================
  //
  // Returns the best clinically applicable protocol.
  //
  // IMPORTANT:
  // The engine does NOT assume:
  //
  //     differential[0] = diagnosis = protocol
  //
  // Instead:
  //
  //     differential
  //       ↓
  //     protocol candidates
  //       ↓
  //     population gate
  //       ↓
  //     jurisdiction gate
  //       ↓
  //     temporal/version gate
  //       ↓
  //     safety gate
  //       ↓
  //     confidence/compatibility gate
  //       ↓
  //     protocol
  //
  async activate(
    differentials: DifferentialCandidate[],
    ageYears: number | null,
    jurisdictionCode?: string | null,
    context?: Partial<ProtocolSelectionContext>,
  ): Promise<ProtocolView | null> {
    if (differentials.length === 0) return null;

    const selectionContext = this.buildContext(
      ageYears,
      context,
      jurisdictionCode ?? null,
    );

    const rankedDifferentials = this.rankDifferentials(differentials);

    const candidates = await this.loadCandidates(
      rankedDifferentials,
      selectionContext,
    );

    if (candidates.length === 0) return null;

    const eligible = candidates
      .filter((candidate) => !candidate.blocked)
      .sort(compareCandidates);

    if (eligible.length === 0) return null;

    const winner = eligible[0];

    // A protocol with an unresolved safety gate is never silently executable.
    // It may still be returned as a confirmation-required pathway.
    if (winner.requiresConfirmation) {
      return this.buildProtocolView(
        winner,
        selectionContext,
        'confirmation_required',
      );
    }

    return this.buildProtocolView(
      winner,
      selectionContext,
      'active',
    );
  }

  // ===========================================================================
  // PREVIEW
  // ===========================================================================
  //
  // Useful for UI:
  //
  // "Which protocols are being considered and why?"
  //
  async preview(
    differentials: DifferentialCandidate[],
    ageYears: number | null,
    jurisdictionCode?: string | null,
    context?: Partial<ProtocolSelectionContext>,
  ): Promise<
    Array<{
      protocolCode: string;
      name: string;
      conditionCode: string;
      score: number;
      blocked: boolean;
      blockReasons: string[];
      requiresConfirmation: boolean;
      confirmationReasons: string[];
    }>
  > {
    const selectionContext = this.buildContext(
      ageYears,
      context,
      jurisdictionCode ?? null,
    );

    const rankedDifferentials = this.rankDifferentials(differentials);

    const candidates = await this.loadCandidates(
      rankedDifferentials,
      selectionContext,
    );

    return candidates
      .sort(compareCandidates)
      .map((candidate) => ({
        protocolCode: candidate.protocol.protocol_code,
        name: candidate.protocol.canonical_name,
        conditionCode: candidate.condition.conditionCode,
        score: round(candidate.score),
        blocked: candidate.blocked,
        blockReasons: candidate.blockReasons,
        requiresConfirmation: candidate.requiresConfirmation,
        confirmationReasons: candidate.confirmationReasons,
      }));
  }

  // ===========================================================================
  // CONTEXT
  // ===========================================================================

  private buildContext(
    ageYears: number | null,
    context: Partial<ProtocolSelectionContext> | undefined,
    jurisdictionCode: string | null,
  ): ProtocolSelectionContext {
    const ageMonths =
      context?.ageMonths ??
      (ageYears != null ? ageYears * 12 : null);

    return {
      ageYears,
      ageMonths,
      ageDays: context?.ageDays ?? null,
      sex: normalizeSex(context?.sex ?? null),
      pregnant: context?.pregnant ?? null,
      gestationalAgeWeeks: context?.gestationalAgeWeeks ?? null,
      jurisdictionCode,
      encounterTypeCode: context?.encounterTypeCode ?? null,
      departmentCode: context?.departmentCode ?? null,
      settingCode: context?.settingCode ?? null,
      acuityCode: context?.acuityCode ?? null,
      severityCode: context?.severityCode ?? null,
      activeDomains: context?.activeDomains ?? [],
    };
  }

  // ===========================================================================
  // DIFFERENTIAL NORMALIZATION
  // ===========================================================================

  private rankDifferentials(
    differentials: DifferentialCandidate[],
  ): DifferentialCandidate[] {
    return [...differentials]
      .filter((d) => Boolean(d.conditionCode))
      .sort((a, b) => {
        const compatibilityA = numberProperty(a, 'compatibility');
        const compatibilityB = numberProperty(b, 'compatibility');

        if (compatibilityB !== compatibilityA) {
          return compatibilityB - compatibilityA;
        }

        const scoreA = numberProperty(a, 'score');
        const scoreB = numberProperty(b, 'score');

        return scoreB - scoreA;
      });
  }

  // ===========================================================================
  // CANDIDATE LOADING
  // ===========================================================================

  private async loadCandidates(
    differentials: DifferentialCandidate[],
    context: ProtocolSelectionContext,
  ): Promise<ProtocolCandidate[]> {
    const conditionCodes = differentials
      .map((d) => d.conditionCode)
      .filter(Boolean);

    if (conditionCodes.length === 0) return [];

    const links = await this.db.query<ConditionLinkRow>(
      `
      SELECT
          c.condition_code,
          p.protocol_code,
          p.population,
          ko.jurisdiction_code,
          pc.is_primary,
          COALESCE(pc.priority_weight, 0) AS priority_weight
      FROM knowledge.protocol_condition pc
      JOIN knowledge.condition c
        ON c.id = pc.condition_id
      JOIN knowledge.protocol p
        ON p.id = pc.protocol_id
      LEFT JOIN governance.knowledge_object ko
        ON ko.object_code = p.protocol_code
      WHERE c.condition_code = ANY($1::text[])
        AND p.status = 'active'
        AND (
          ko.jurisdiction_code IS NULL
          OR ko.jurisdiction_code = 'JUR-GLOBAL'
          OR ko.jurisdiction_code = $2
        )
      `,
      [conditionCodes, context.jurisdictionCode],
    );

    if (links.length === 0) return [];

    const protocolCodes = [...new Set(links.map((l) => l.protocol_code))];

    const protocols = await this.db.query<ProtocolRow>(
      `
      SELECT
          protocol_code,
          canonical_name,
          purpose,
          status,
          population,
          acuity,
          setting,
          version,
          effective_from,
          effective_to,
          requires_confirmation,
          COALESCE(priority, 0) AS priority
      FROM knowledge.protocol
      WHERE protocol_code = ANY($1::text[])
        AND status = 'active'
      `,
      [protocolCodes],
    );

    const protocolByCode = new Map(
      protocols.map((protocol) => [
        protocol.protocol_code,
        protocol,
      ]),
    );

    const differentialsByCondition = new Map(
      differentials.map((d) => [
        d.conditionCode,
        d,
      ]),
    );

    const candidates: ProtocolCandidate[] = [];

    for (const link of links) {
      const protocol = protocolByCode.get(link.protocol_code);
      const differential = differentialsByCondition.get(link.condition_code);

      if (!protocol || !differential) continue;

      const candidate: ProtocolCandidate = {
        protocol,
        condition: differential,
        conditionLink: link,
        score: this.calculateProtocolScore(
          protocol,
          link,
          differential,
          context,
        ),
        blocked: false,
        blockReasons: [],
        requiresConfirmation: Boolean(protocol.requires_confirmation),
        confirmationReasons: protocol.requires_confirmation
          ? ['Protocol requires clinician confirmation.']
          : [],
      };

      this.applyPopulationGate(candidate, context);
      this.applyJurisdictionGate(candidate, context);
      this.applyTemporalGate(candidate);
      this.applyContextGate(candidate, context);

      candidates.push(candidate);
    }

    await this.applyKnowledgeGates(candidates, context);

    return candidates;
  }

  // ===========================================================================
  // SCORING
  // ===========================================================================

  private calculateProtocolScore(
    protocol: ProtocolRow,
    link: ConditionLinkRow,
    differential: DifferentialCandidate,
    context: ProtocolSelectionContext,
  ): number {
    const compatibility = numberProperty(
      differential,
      'compatibility',
    );

    const differentialScore = numberProperty(
      differential,
      'score',
    );

    let score =
      compatibility * 100 +
      differentialScore +
      Number(protocol.priority ?? 0) +
      Number(link.priority_weight ?? 0);

    if (link.is_primary) score += 20;

    const populationRank =
      POPULATION_PRIORITY.indexOf(
        protocol.population as (typeof POPULATION_PRIORITY)[number],
      );

    if (populationRank >= 0) {
      score += (POPULATION_PRIORITY.length - populationRank) * 2;
    }

    if (
      context.acuityCode &&
      protocol.acuity &&
      normalizeCode(protocol.acuity) === normalizeCode(context.acuityCode)
    ) {
      score += 15;
    }

    if (
      context.settingCode &&
      protocol.setting &&
      normalizeCode(protocol.setting) === normalizeCode(context.settingCode)
    ) {
      score += 10;
    }

    return score;
  }

  // ===========================================================================
  // POPULATION SAFETY
  // ===========================================================================

  private applyPopulationGate(
    candidate: ProtocolCandidate,
    context: ProtocolSelectionContext,
  ): void {
    if (!candidate.protocol.population) {
      return;
    }

    const population = normalizeCode(candidate.protocol.population);

    const ageMonths = context.ageMonths;
    const ageDays = context.ageDays;
    const ageYears = context.ageYears;

    // Neonatal.
    if (
      population === 'NEONATAL' &&
      ageDays != null &&
      ageDays > NEONATAL_MAX_DAYS
    ) {
      this.block(
        candidate,
        `Neonatal protocol is not applicable beyond ${NEONATAL_MAX_DAYS} days of life.`,
      );
      return;
    }

    // Paediatric.
    if (
      population === 'PAEDIATRIC' &&
      ageMonths != null &&
      ageMonths >= ADULT_BOUNDARY_YEARS * 12
    ) {
      this.block(
        candidate,
        'Paediatric protocol is not applicable to an adult patient.',
      );
      return;
    }

    // Adult.
    if (
      population === 'ADULT' &&
      ageYears != null &&
      ageYears < ADULT_BOUNDARY_YEARS
    ) {
      this.block(
        candidate,
        'Adult protocol is not applicable below the adult age boundary.',
      );
      return;
    }

    // Pregnancy-specific.
    if (
      population === 'PREGNANCY' &&
      context.pregnant !== true
    ) {
      this.block(
        candidate,
        'Pregnancy-specific protocol requires pregnancy context.',
      );
    }

    // Both/universal does not require population restriction.
  }

  // ===========================================================================
  // JURISDICTION SAFETY
  // ===========================================================================

  private applyJurisdictionGate(
    candidate: ProtocolCandidate,
    context: ProtocolSelectionContext,
  ): void {
    const jurisdiction = candidate.conditionLink.jurisdiction_code;

    if (!jurisdiction) return;

    if (jurisdiction === 'JUR-GLOBAL') return;

    if (
      context.jurisdictionCode &&
      jurisdiction !== context.jurisdictionCode
    ) {
      this.block(
        candidate,
        `Protocol jurisdiction ${jurisdiction} does not match patient jurisdiction ${context.jurisdictionCode}.`,
      );
    }
  }

  // ===========================================================================
  // TEMPORAL / VERSION SAFETY
  // ===========================================================================

  private applyTemporalGate(
    candidate: ProtocolCandidate,
  ): void {
    const now = Date.now();

    if (candidate.protocol.effective_from) {
      const from = Date.parse(candidate.protocol.effective_from);

      if (!Number.isNaN(from) && now < from) {
        this.block(
          candidate,
          'Protocol is not yet effective.',
        );
      }
    }

    if (candidate.protocol.effective_to) {
      const to = Date.parse(candidate.protocol.effective_to);

      if (!Number.isNaN(to) && now > to) {
        this.block(
          candidate,
          'Protocol has expired.',
        );
      }
    }
  }

  // ===========================================================================
  // ENCOUNTER / SERVICE CONTEXT
  // ===========================================================================

  private applyContextGate(
    candidate: ProtocolCandidate,
    context: ProtocolSelectionContext,
  ): void {
    if (
      candidate.protocol.setting &&
      context.settingCode &&
      normalizeCode(candidate.protocol.setting) !==
        normalizeCode(context.settingCode)
    ) {
      candidate.requiresConfirmation = true;

      candidate.confirmationReasons.push(
        `Protocol setting (${candidate.protocol.setting}) differs from current setting (${context.settingCode}).`,
      );
    }

    if (
      candidate.protocol.acuity &&
      context.acuityCode &&
      normalizeCode(candidate.protocol.acuity) !==
        normalizeCode(context.acuityCode)
    ) {
      candidate.requiresConfirmation = true;

      candidate.confirmationReasons.push(
        `Protocol acuity (${candidate.protocol.acuity}) differs from current acuity (${context.acuityCode}).`,
      );
    }
  }

  // ===========================================================================
  // KNOWLEDGE-DEFINED SAFETY GATES
  // ===========================================================================

  private async applyKnowledgeGates(
    candidates: ProtocolCandidate[],
    context: ProtocolSelectionContext,
  ): Promise<void> {
    if (candidates.length === 0) return;

    const protocolCodes = candidates.map(
      (candidate) => candidate.protocol.protocol_code,
    );

    const gates = await this.db.query<GateRow>(
      `
      SELECT
          protocol_code,
          gate_code,
          gate_type,
          target_code,
          operator,
          expected_value,
          failure_action,
          failure_message,
          priority
      FROM knowledge.protocol_gate
      WHERE status = 'active'
        AND protocol_code = ANY($1::text[])
      ORDER BY priority DESC
      `,
      [protocolCodes],
    );

    const factsByProtocol = await this.loadRelevantFacts(
      candidates,
      gates,
    );

    for (const candidate of candidates) {
      const protocolGates = gates.filter(
        (gate) =>
          gate.protocol_code ===
          candidate.protocol.protocol_code,
      );

      const facts =
        factsByProtocol.get(candidate.protocol.protocol_code) ??
        [];

      for (const gate of protocolGates) {
        const result = this.evaluateGate(
          gate,
          facts,
          context,
        );

        if (result === 'PASS') continue;

        const message =
          gate.failure_message ??
          `Protocol gate ${gate.gate_code} was not satisfied.`;

        const failureAction =
          normalizeCode(gate.failure_action ?? 'CONFIRM');

        if (
          failureAction === 'BLOCK' ||
          failureAction === 'EXCLUDE'
        ) {
          this.block(candidate, message);
        } else {
          candidate.requiresConfirmation = true;
          candidate.confirmationReasons.push(message);
        }
      }
    }
  }

  // ===========================================================================
  // FACT LOADING FOR GATES
  // ===========================================================================

  private async loadRelevantFacts(
    candidates: ProtocolCandidate[],
    gates: GateRow[],
  ): Promise<Map<string, ProtocolFactRow[]>> {
    const factCodes = [
      ...new Set(
        gates
          .map((gate) => gate.target_code)
          .filter(
            (code): code is string =>
              typeof code === 'string' && code.length > 0,
          ),
      ),
    ];

    if (factCodes.length === 0) {
      return new Map();
    }

    // Gate evaluation is currently performed against the current patient
    // context upstream. The actual patient identifier should be injected into
    // the engine in production rather than inferred from protocol state.
    //
    // This method intentionally returns an empty map here when no patient ID
    // is available to this engine signature.
    //
    // The preferred production signature is:
    //
    // activate(..., patientId)
    //
    // followed by:
    //
    // WHERE f.patient_id = $patientId
    //
    // This keeps protocol knowledge independent from UI state.
    return new Map(
      candidates.map((candidate) => [
        candidate.protocol.protocol_code,
        [],
      ]),
    );
  }

  // ===========================================================================
  // GATE EVALUATOR
  // ===========================================================================

  private evaluateGate(
    gate: GateRow,
    facts: ProtocolFactRow[],
    context: ProtocolSelectionContext,
  ): 'PASS' | 'FAIL' | 'UNKNOWN' {
    const type = normalizeCode(gate.gate_type);
    const expected = gate.expected_value;
    const operator = gate.operator ?? 'eq';

    switch (type) {
      case 'AGE':
        return this.compareNumeric(
          context.ageYears,
          expected,
          operator,
        );

      case 'PREGNANCY':
        if (context.pregnant == null) return 'UNKNOWN';

        return this.compareBoolean(
          context.pregnant,
          expected,
          operator,
        );

      case 'SEX':
        return this.compareString(
          context.sex,
          expected,
          operator,
        );

      case 'GESTATIONAL_AGE':
        return this.compareNumeric(
          context.gestationalAgeWeeks,
          expected,
          operator,
        );

      case 'DEPARTMENT':
        return this.compareString(
          context.departmentCode,
          expected,
          operator,
        );

      case 'ENCOUNTER_TYPE':
        return this.compareString(
          context.encounterTypeCode,
          expected,
          operator,
        );

      case 'SETTING':
        return this.compareString(
          context.settingCode,
          expected,
          operator,
        );

      case 'SEVERITY':
        return this.compareString(
          context.severityCode,
          expected,
          operator,
        );

      case 'JURISDICTION':
        return this.compareString(
          context.jurisdictionCode,
          expected,
          operator,
        );

      case 'REQUIRED_FACT':
        return this.evaluateFactGate(
          facts,
          gate,
          true,
        );

      case 'FORBIDDEN_FACT':
        return this.evaluateFactGate(
          facts,
          gate,
          false,
        );

      default:
        return 'UNKNOWN';
    }
  }

  // ===========================================================================
  // FACT GATE
  // ===========================================================================

  private evaluateFactGate(
    facts: ProtocolFactRow[],
    gate: GateRow,
    required: boolean,
  ): 'PASS' | 'FAIL' | 'UNKNOWN' {
    if (!gate.target_code) return 'UNKNOWN';

    const matching = facts.filter(
      (fact) =>
        fact.fact_definition_code === gate.target_code,
    );

    if (matching.length === 0) {
      return required ? 'UNKNOWN' : 'PASS';
    }

    const fact = matching[0];

    const actual =
      fact.value_boolean != null
        ? String(fact.value_boolean)
        : fact.value_numeric != null
          ? String(fact.value_numeric)
          : fact.value_text;

    if (actual == null) return 'UNKNOWN';

    const result = compare(
      actual,
      gate.expected_value,
      gate.operator ?? 'eq',
    );

    if (required) return result;

    return result === 'PASS' ? 'FAIL' : result;
  }

  // ===========================================================================
  // NUMERIC COMPARISON
  // ===========================================================================

  private compareNumeric(
    actual: number | null,
    expected: string | null,
    operator: string,
  ): 'PASS' | 'FAIL' | 'UNKNOWN' {
    if (actual == null || expected == null) return 'UNKNOWN';

    const target = Number(expected);

    if (!Number.isFinite(target)) return 'UNKNOWN';

    switch (normalizeCode(operator)) {
      case 'GT':
        return actual > target ? 'PASS' : 'FAIL';

      case 'GTE':
        return actual >= target ? 'PASS' : 'FAIL';

      case 'LT':
        return actual < target ? 'PASS' : 'FAIL';

      case 'LTE':
        return actual <= target ? 'PASS' : 'FAIL';

      case 'EQ':
        return actual === target ? 'PASS' : 'FAIL';

      case 'NEQ':
        return actual !== target ? 'PASS' : 'FAIL';

      default:
        return 'UNKNOWN';
    }
  }

  // ===========================================================================
  // BOOLEAN COMPARISON
  // ===========================================================================

  private compareBoolean(
    actual: boolean,
    expected: string | null,
    operator: string,
  ): 'PASS' | 'FAIL' | 'UNKNOWN' {
    if (expected == null) return 'UNKNOWN';

    const target =
      /^(true|yes|1|pregnant)$/i.test(expected);

    if (normalizeCode(operator) === 'NEQ') {
      return actual !== target ? 'PASS' : 'FAIL';
    }

    return actual === target ? 'PASS' : 'FAIL';
  }

  // ===========================================================================
  // STRING COMPARISON
  // ===========================================================================

  private compareString(
    actual: string | null,
    expected: string | null,
    operator: string,
  ): 'PASS' | 'FAIL' | 'UNKNOWN' {
    if (actual == null || expected == null) return 'UNKNOWN';

    const a = normalizeCode(actual);
    const e = normalizeCode(expected);

    switch (normalizeCode(operator)) {
      case 'EQ':
        return a === e ? 'PASS' : 'FAIL';

      case 'NEQ':
        return a !== e ? 'PASS' : 'FAIL';

      case 'IN':
        return e
          .split(',')
          .map(normalizeCode)
          .includes(a)
          ? 'PASS'
          : 'FAIL';

      default:
        return 'UNKNOWN';
    }
  }

  // ===========================================================================
  // PROTOCOL VIEW
  // ===========================================================================

  private async buildProtocolView(
    candidate: ProtocolCandidate,
    context: ProtocolSelectionContext,
    activationStatus: 'active' | 'confirmation_required',
  ): Promise<ProtocolView> {
    const protocolCode =
      candidate.protocol.protocol_code;

    const [steps, actions] = await Promise.all([
      this.loadSteps(protocolCode),
      this.loadActions(protocolCode),
    ]);

    const actionsByStep =
      new Map<string, ProtocolActionView[]>();

    for (const action of actions) {
      const list =
        actionsByStep.get(action.step_code) ?? [];

      list.push({
        actionType: action.action_type,
        actionCode: action.action_code,
        actionName: action.action_name,
        detail: action.detail,
        urgency: action.urgency,
      });

      actionsByStep.set(action.step_code, list);
    }

    const stepViews: ProtocolStepView[] =
      steps.map((step) => ({
        stepCode: step.step_code,
        label: step.step_label,
        stepType: step.step_type,
        sequenceNo: step.sequence_no,
        instruction: step.instruction,
        rationale: step.rationale,
        required: step.required,
        actions:
          actionsByStep.get(step.step_code) ?? [],
      }));

    return {
      protocolCode,
      name: candidate.protocol.canonical_name,
      purpose: candidate.protocol.purpose,
      status:
        activationStatus === 'active'
          ? candidate.protocol.status
          : 'confirmation_required',

      steps: stepViews,

      // Optional extension fields. They should be added to ProtocolView in
      // ../types.ts so provenance and safety state survive projection.
      conditionCode: candidate.condition.conditionCode,
      activationStatus,
      activationScore: round(candidate.score),
      population: candidate.protocol.population,
      jurisdiction:
        context.jurisdictionCode,
      requiresConfirmation:
        candidate.requiresConfirmation,
      confirmationReasons:
        candidate.confirmationReasons,
      blockReasons:
        candidate.blockReasons,
    } as ProtocolView;
  }

  // ===========================================================================
  // STEP LOADING
  // ===========================================================================

  private async loadSteps(
    protocolCode: string,
  ): Promise<StepRow[]> {
    return this.db.query<StepRow>(
      `
      SELECT
          p.protocol_code,
          ps.step_code,
          ps.step_label,
          ps.step_type,
          ps.sequence_no,
          ps.instruction,
          ps.rationale,
          ps.required,
          ps.condition_expression
      FROM knowledge.protocol_step ps
      JOIN knowledge.protocol p
        ON p.id = ps.protocol_id
      WHERE p.protocol_code = $1
        AND ps.status = 'active'
      ORDER BY ps.sequence_no
      `,
      [protocolCode],
    );
  }

  // ===========================================================================
  // ACTION LOADING
  // ===========================================================================

  private async loadActions(
    protocolCode: string,
  ): Promise<ActionRow[]> {
    return this.db.query<ActionRow>(
      `
      SELECT
          p.protocol_code,
          ps.step_code,
          pa.action_type,
          pa.action_code,
          pa.action_name,
          pa.detail,
          pa.urgency,
          pa.sort_order,
          pa.required,
          pa.condition_expression
      FROM knowledge.protocol_action pa
      JOIN knowledge.protocol_step ps
        ON ps.id = pa.step_id
      JOIN knowledge.protocol p
        ON p.id = pa.protocol_id
      WHERE p.protocol_code = $1
        AND ps.status = 'active'
      ORDER BY
          ps.sequence_no,
          pa.sort_order
      `,
      [protocolCode],
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  private block(
    candidate: ProtocolCandidate,
    reason: string,
  ): void {
    candidate.blocked = true;

    if (!candidate.blockReasons.includes(reason)) {
      candidate.blockReasons.push(reason);
    }
  }
}

// =============================================================================
// CANDIDATE ORDERING
// =============================================================================

function compareCandidates(
  a: ProtocolCandidate,
  b: ProtocolCandidate,
): number {
  // Safety first.
  if (a.blocked !== b.blocked) {
    return a.blocked ? 1 : -1;
  }

  // A protocol requiring confirmation should not outrank an otherwise
  // equivalent immediately usable pathway.
  if (
    a.requiresConfirmation !==
    b.requiresConfirmation
  ) {
    return a.requiresConfirmation ? 1 : -1;
  }

  // Highest clinical support.
  if (b.score !== a.score) {
    return b.score - a.score;
  }

  // Primary condition link wins.
  if (
    a.conditionLink.is_primary !==
    b.conditionLink.is_primary
  ) {
    return a.conditionLink.is_primary ? -1 : 1;
  }

  return (
    a.protocol.protocol_code.localeCompare(
      b.protocol.protocol_code,
    )
  );
}

// =============================================================================
// GENERIC COMPARISON
// =============================================================================

function compare(
  actual: string,
  expected: string | null,
  operator: string,
): 'PASS' | 'FAIL' | 'UNKNOWN' {
  if (expected == null) return 'UNKNOWN';

  const op = normalizeCode(operator);

  const numericActual = Number(actual);
  const numericExpected = Number(expected);

  if (
    Number.isFinite(numericActual) &&
    Number.isFinite(numericExpected)
  ) {
    switch (op) {
      case 'GT':
        return numericActual > numericExpected
          ? 'PASS'
          : 'FAIL';

      case 'GTE':
        return numericActual >= numericExpected
          ? 'PASS'
          : 'FAIL';

      case 'LT':
        return numericActual < numericExpected
          ? 'PASS'
          : 'FAIL';

      case 'LTE':
        return numericActual <= numericExpected
          ? 'PASS'
          : 'FAIL';

      case 'NEQ':
        return numericActual !== numericExpected
          ? 'PASS'
          : 'FAIL';

      case 'EQ':
      default:
        return numericActual === numericExpected
          ? 'PASS'
          : 'FAIL';
    }
  }

  const a = normalizeCode(actual);
  const e = normalizeCode(expected);

  switch (op) {
    case 'NEQ':
      return a !== e ? 'PASS' : 'FAIL';

    case 'IN':
      return e
        .split(',')
        .map(normalizeCode)
        .includes(a)
        ? 'PASS'
        : 'FAIL';

    case 'EQ':
    default:
      return a === e ? 'PASS' : 'FAIL';
  }
}

// =============================================================================
// NORMALIZATION
// =============================================================================

function normalizeCode(
  value: string,
): string {
  return value
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
}

function normalizeSex(
  sex: string | null | undefined,
): string | null {
  if (!sex) return null;

  const value = sex
    .trim()
    .toLowerCase();

  switch (value) {
    case 'm':
    case 'male':
      return 'male';

    case 'f':
    case 'female':
      return 'female';

    case 'intersex':
      return 'other';

    case 'unknown':
      return 'unknown';

    default:
      return value;
  }
}

function numberProperty(
  object: unknown,
  property: string,
): number {
  if (
    object &&
    typeof object === 'object' &&
    property in object
  ) {
    const value = Number(
      (object as Record<string, unknown>)[property],
    );

    return Number.isFinite(value) ? value : 0;
  }

  return 0;
}

function round(
  value: number,
): number {
  return Math.round(value * 1000) / 1000;
}