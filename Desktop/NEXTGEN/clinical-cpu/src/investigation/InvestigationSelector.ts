// =============================================================================
// AMEXAN Clinical CPU — InvestigationSelector
// =============================================================================
//
// PURPOSE
// -------
// Selects investigations that are clinically useful for the CURRENT patient
// state.
//
// The selector answers:
//
//   "What investigation, if any, would most usefully reduce an important
//    clinical uncertainty, establish severity, detect a dangerous complication,
//    identify an actionable cause, or satisfy an active protocol?"
//
// This is NOT a static:
//      disease -> test
//
// lookup.
//
// It is a clinical intelligence layer combining:
//
//   1. Leading differential diagnoses
//   2. Leading pathophysiological mechanisms
//   3. Clinical severity / red flags
//   4. Already-captured facts
//   5. Investigation/result closure
//   6. Investigation prerequisites
//   7. Diagnostic / therapeutic consequences
//   8. Protocol requirements
//   9. Configuration overrides
//  10. Patient-context applicability
//  11. Duplicate / redundant investigation suppression
//  12. Rationale + provenance
//
// CLINICAL PRINCIPLE
// ------------------
// Investigation is not automatically indicated merely because a disease
// exists in the differential.
//
// A useful investigation should answer a clinically meaningful question.
//
// Examples:
//
//   "Is this patient hypoxaemic?"
//       -> SpO2 / ABG where appropriate
//
//   "Is there focal pulmonary consolidation?"
//       -> CXR when imaging is clinically justified
//
//   "How severe is the physiological disturbance?"
//       -> CBC, renal profile, lactate, blood gas etc. depending on context
//
//   "Will the result change immediate management?"
//       -> high decision-impact investigation
//
//   "Has the same question already been answered?"
//       -> suppress redundant recommendation
//
// IMPORTANT SAFETY RULE
// ---------------------
// The engine NEVER treats the absence of a test as proof of disease absence.
// It only models:
//
//      known fact
//      unresolved uncertainty
//      candidate investigation
//      expected clinical utility
//
// The clinician remains responsible for the final decision.
//
// =============================================================================

import type { Db, Row } from '../db.js';

import type {
  ConfigurationOverride,
  DifferentialCandidate,
  InvestigationRecommendation,
  MechanismScore,
  PatientClinicalState,
} from '../types.js';


// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface ConditionInvestigationRow extends Row {
  condition_code: string;
  investigation_code: string;
  canonical_name: string;
  investigation_type: string;

  /**
   * Clinical relevance of the investigation to the condition.
   */
  weight: number;

  /**
   * Human-readable reason maintained in knowledge.
   */
  rationale: string | null;

  /**
   * Optional knowledge-level classification.
   *
   * Examples:
   *   confirmatory
   *   supportive
   *   severity
   *   complication
   *   baseline
   *   exclusion
   *   monitoring
   */
  role: string | null;

  /**
   * Optional clinical question answered by the investigation.
   */
  clinical_question: string | null;

  /**
   * Optional consequence if positive/abnormal.
   */
  decision_impact: number | null;
}


interface MechanismInvestigationRow extends Row {
  mechanism_code: string;
  investigation_code: string;
  canonical_name: string;
  investigation_type: string;
  weight: number;
  rationale: string | null;

  role: string | null;
  clinical_question: string | null;
  decision_impact: number | null;
}


interface InvestigationRow extends Row {
  investigation_code: string;
  canonical_name: string;
  investigation_type: string;

  /**
   * Whether the investigation is currently active.
   */
  status?: string;

  /**
   * Knowledge-level characteristics.
   */
  default_priority?: number | null;
  invasiveness?: string | null;
  turnaround_category?: string | null;
}


interface InvestigationFactRow extends Row {
  investigation_code: string;
  fact_definition_code: string;
}


interface ProtocolInvestigationRow extends Row {
  investigation_code: string;
  protocol_code?: string | null;
  priority_weight?: number | null;
  rationale?: string | null;
}


interface ContextRuleRow extends Row {
  investigation_code: string;
  context_type: string;
  context_value: string;
  action: string;
  priority_weight: number;
  rationale: string | null;
}


interface ExistingInvestigationRow extends Row {
  investigation_code: string;
  status: string;
  performed_at: string | null;
}


interface InvestigationDependencyRow extends Row {
  investigation_code: string;
  prerequisite_investigation_code: string;
  rationale: string | null;
}


// =============================================================================
// INTERNAL TYPES
// =============================================================================

type RecommendationSource =
  | 'condition'
  | 'mechanism'
  | 'severity'
  | 'protocol'
  | 'baseline'
  | 'monitoring'
  | 'context'
  | 'configuration';


type InvestigationRole =
  | 'diagnostic'
  | 'confirmatory'
  | 'supportive'
  | 'severity'
  | 'complication'
  | 'baseline'
  | 'monitoring'
  | 'exclusion'
  | 'screening'
  | 'pre_treatment';


interface CandidateAccumulator {
  investigationCode: string;
  name: string;
  type: string;

  /**
   * Aggregate clinical score.
   */
  weight: number;

  /**
   * Human-readable rationale.
   */
  rationale: string | null;

  /**
   * Why this candidate entered the recommendation set.
   */
  source: RecommendationSource;

  /**
   * Multiple reasons can coexist.
   */
  sources: Set<RecommendationSource>;

  /**
   * Clinical role.
   */
  role: InvestigationRole | null;

  /**
   * Question the investigation is intended to answer.
   */
  clinicalQuestion: string | null;

  /**
   * Expected decision impact.
   */
  decisionImpact: number;

  /**
   * Whether the investigation is protocol-relevant.
   */
  protocolRequired: boolean;

  /**
   * Whether a contextual rule specifically supports it.
   */
  contextSupported: boolean;

  /**
   * Whether the investigation is a baseline/safety investigation.
   */
  safetyRelevant: boolean;
}


// =============================================================================
// RESULT CLOSURE
// =============================================================================
//
// This is intentionally explicit rather than assuming that every investigation
// code is itself a fact.
//
// Example:
//
//   INV-SPO2 -> SPO2
//
// But:
//
//   INV-CXR -> CXR_RESULT
//
// or multiple structured radiology facts may be returned.
//
// The mapping should ultimately live in PostgreSQL. The static mapping below
// provides compatibility with the existing system while the database evolves.
//
// =============================================================================

const FALLBACK_INVESTIGATION_RESULT_FACTS: Record<string, string[]> = {
  'INV-SPO2': ['SPO2'],

  'INV-FBC': [
    'HAEMOGLOBIN',
    'WBC',
    'PLATELET_COUNT',
  ],

  'INV-CRP': [
    'CRP',
  ],

  'INV-UREA-CREAT': [
    'UREA',
    'CREATININE',
  ],

  'INV-RBS': [
    'RANDOM_BLOOD_GLUCOSE',
  ],

  'INV-FBS': [
    'FASTING_BLOOD_GLUCOSE',
  ],

  'INV-HBA1C': [
    'HBA1C',
  ],

  'INV-URINALYSIS': [
    'URINALYSIS',
  ],

  'INV-PREGNANCY-TEST': [
    'PREGNANCY_TEST',
  ],

  // Imaging studies generally return structured findings rather than a single
  // numeric fact. These are deliberately NOT treated as satisfied merely
  // because an unrelated examination finding exists.
  'INV-CXR': [],

  'INV-ABG': [
    'PH',
    'PCO2',
    'PO2',
    'HCO3',
  ],

  'INV-VBG': [
    'PH',
    'PCO2',
    'HCO3',
  ],

  'INV-LACTATE': [
    'LACTATE',
  ],

  'INV-BLOOD-CULTURE': [
    'BLOOD_CULTURE_RESULT',
  ],

  'INV-SPUTUM-AFB': [
    'SPUTUM_AFB_RESULT',
  ],

  'INV-GENE-XPERT-TB': [
    'TB_MOLECULAR_RESULT',
  ],
};


// =============================================================================
// CLASS
// =============================================================================

export class InvestigationSelector {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  async select(
    differentials: DifferentialCandidate[],
    mechanisms: MechanismScore[],
    capturedCodes: Set<string>,
    overrides: ConfigurationOverride[] = [],
    state?: PatientClinicalState,
  ): Promise<InvestigationRecommendation[]> {

    // -------------------------------------------------------------------------
    // 1. Normalize patient context.
    // -------------------------------------------------------------------------

    const context = state
      ? buildPatientContext(state)
      : new Map<string, Set<string>>();

    // -------------------------------------------------------------------------
    // 2. Identify leading diagnoses and mechanisms.
    //
    // We deliberately avoid taking the entire differential because doing so
    // creates "investigation explosion".
    //
    // The first two diagnoses and mechanisms represent the current working
    // diagnostic frontier.
    // -------------------------------------------------------------------------

    const topConditionCodes = uniqueStrings(
      differentials
        .slice(0, 3)
        .map((d) => d.conditionCode),
    );

    const topMechanismCodes = uniqueStrings(
      mechanisms
        .slice(0, 3)
        .map((m) => m.mechanismCode),
    );

    // -------------------------------------------------------------------------
    // 3. Load knowledge in parallel.
    // -------------------------------------------------------------------------

    const [
      conditionRows,
      mechanismRows,
      investigations,
      resultMappings,
      protocolRows,
      contextRules,
      existingInvestigations,
    ] = await Promise.all([
      this.loadConditionInvestigations(topConditionCodes),

      this.loadMechanismInvestigations(topMechanismCodes),

      this.loadInvestigations(),

      this.loadInvestigationResultFacts(),

      this.loadProtocolInvestigations(),

      this.loadContextRules(),

      this.loadExistingInvestigations(
        state?.encounterId ?? null,
        state?.patientId ?? null,
      ),
    ]);

    // -------------------------------------------------------------------------
    // 4. Build lookup maps.
    // -------------------------------------------------------------------------

    const investigationMap = new Map(
      investigations.map((i) => [i.investigation_code, i]),
    );

    const resultFactMap = new Map<string, string[]>();

    for (const row of resultMappings) {
      const current = resultFactMap.get(row.investigation_code) ?? [];
      current.push(row.fact_definition_code);
      resultFactMap.set(row.investigation_code, current);
    }

    // Compatibility fallback.
    for (const [code, facts] of Object.entries(
      FALLBACK_INVESTIGATION_RESULT_FACTS,
    )) {
      if (!resultFactMap.has(code)) {
        resultFactMap.set(code, facts);
      }
    }

    // -------------------------------------------------------------------------
    // 5. Existing investigation suppression.
    //
    // A test that was already performed during the relevant encounter should
    // not automatically be recommended again.
    //
    // NOTE:
    // Repeat testing may still be appropriate for monitoring. Therefore we do
    // not globally suppress every existing test. The role determines whether
    // repetition can be meaningful.
    // -------------------------------------------------------------------------

    const existingMap = new Map<string, ExistingInvestigationRow>();

    for (const row of existingInvestigations) {
      existingMap.set(row.investigation_code, row);
    }

    // -------------------------------------------------------------------------
    // 6. Aggregate condition-driven candidates.
    // -------------------------------------------------------------------------

    const aggregate = new Map<string, CandidateAccumulator>();

    for (const row of conditionRows) {
      if (!investigationMap.has(row.investigation_code)) continue;

      if (
        this.isSatisfied(
          row.investigation_code,
          capturedCodes,
          resultFactMap,
        )
      ) {
        continue;
      }

      const entry = this.getOrCreate(
        aggregate,
        row.investigation_code,
        row.canonical_name,
        row.investigation_type,
        'condition',
      );

      entry.weight += Number(row.weight ?? 0);

      entry.rationale =
        entry.rationale ??
        row.rationale ??
        `Relevant to ${row.condition_code}.`;

      entry.role =
        entry.role ??
        normalizeRole(row.role);

      entry.clinicalQuestion =
        entry.clinicalQuestion ??
        row.clinical_question;

      entry.decisionImpact += Number(row.decision_impact ?? 0);

      entry.sources.add('condition');
    }

    // -------------------------------------------------------------------------
    // 7. Aggregate mechanism-driven candidates.
    // -------------------------------------------------------------------------

    for (const row of mechanismRows) {
      if (!investigationMap.has(row.investigation_code)) continue;

      if (
        this.isSatisfied(
          row.investigation_code,
          capturedCodes,
          resultFactMap,
        )
      ) {
        continue;
      }

      const entry = this.getOrCreate(
        aggregate,
        row.investigation_code,
        row.canonical_name,
        row.investigation_type,
        'mechanism',
      );

      entry.weight += Number(row.weight ?? 0);

      entry.rationale =
        entry.rationale ??
        row.rationale ??
        `Relevant to mechanism ${row.mechanism_code}.`;

      entry.role =
        entry.role ??
        normalizeRole(row.role);

      entry.clinicalQuestion =
        entry.clinicalQuestion ??
        row.clinical_question;

      entry.decisionImpact += Number(row.decision_impact ?? 0);

      entry.sources.add('mechanism');
    }

    // -------------------------------------------------------------------------
    // 8. Clinical severity intelligence.
    //
    // Investigations may be needed because the patient is physiologically
    // unstable even before the exact diagnosis is known.
    //
    // This is deliberately conservative. It only adds generic severity
    // investigations when the existing patient state contains explicit severe
    // physiological signals.
    // -------------------------------------------------------------------------

    if (state) {
      await this.applySeverityCandidates(
        aggregate,
        capturedCodes,
        resultFactMap,
        state,
        investigationMap,
      );
    }

    // -------------------------------------------------------------------------
    // 9. Protocol investigations.
    // -------------------------------------------------------------------------

    for (const row of protocolRows) {
      if (!investigationMap.has(row.investigation_code)) continue;

      if (
        this.isSatisfied(
          row.investigation_code,
          capturedCodes,
          resultFactMap,
        )
      ) {
        continue;
      }

      const entry = this.getOrCreate(
        aggregate,
        row.investigation_code,
        investigationMap.get(row.investigation_code)!.canonical_name,
        investigationMap.get(row.investigation_code)!.investigation_type,
        'protocol',
      );

      entry.protocolRequired = true;
      entry.sources.add('protocol');

      entry.weight += Number(row.priority_weight ?? 1);

      if (row.rationale) {
        entry.rationale =
          entry.rationale ??
          row.rationale;
      }

      entry.role =
        entry.role ??
        'diagnostic';
    }

    // -------------------------------------------------------------------------
    // 10. Contextual investigation rules.
    //
    // Example:
    //
    //   pregnancy + abdominal pain
    //       -> pregnancy test / ultrasound may become more relevant
    //
    //   suspected severe infection
    //       -> lactate / cultures may become relevant
    //
    // Context rules remain data-driven.
    // -------------------------------------------------------------------------

    for (const rule of contextRules) {
      if (!contextMatches(
        rule.context_type,
        rule.context_value,
        context,
      )) {
        continue;
      }

      const investigation = investigationMap.get(
        rule.investigation_code,
      );

      if (!investigation) continue;

      if (
        this.isSatisfied(
          rule.investigation_code,
          capturedCodes,
          resultFactMap,
        )
      ) {
        continue;
      }

      if (rule.action === 'BLOCK') {
        aggregate.delete(rule.investigation_code);
        continue;
      }

      if (
        rule.action !== 'SELECT' &&
        rule.action !== 'BOOST'
      ) {
        continue;
      }

      const entry = this.getOrCreate(
        aggregate,
        investigation.investigation_code,
        investigation.canonical_name,
        investigation.investigation_type,
        'context',
      );

      entry.weight += Number(rule.priority_weight ?? 0);
      entry.contextSupported = true;
      entry.sources.add('context');

      if (rule.rationale) {
        entry.rationale =
          entry.rationale ??
          rule.rationale;
      }
    }

    // -------------------------------------------------------------------------
    // 11. Apply knowledge-level defaults.
    //
    // A high-value investigation gets a modest boost. This must NOT dominate
    // disease/mechanism relevance.
    // -------------------------------------------------------------------------

    for (const entry of aggregate.values()) {
      const investigation = investigationMap.get(
        entry.investigationCode,
      );

      if (!investigation) continue;

      const defaultPriority =
        Number(investigation.default_priority ?? 0);

      entry.weight += defaultPriority * 0.10;
    }

    // -------------------------------------------------------------------------
    // 12. Apply configuration overrides.
    // -------------------------------------------------------------------------

    this.applyOverrides(
      aggregate,
      overrides,
      investigationMap,
    );

    // -------------------------------------------------------------------------
    // 13. Remove candidates that are clinically redundant.
    // -------------------------------------------------------------------------

    for (const [code, entry] of aggregate.entries()) {
      const existing = existingMap.get(code);

      if (!existing) continue;

      // Monitoring investigations may legitimately repeat.
      if (
        entry.role === 'monitoring' ||
        entry.safetyRelevant
      ) {
        continue;
      }

      // If already completed and there is no explicit reason to repeat it,
      // suppress it.
      if (
        existing.status === 'completed' ||
        existing.status === 'resulted' ||
        existing.status === 'final'
      ) {
        aggregate.delete(code);
      }
    }

    // -------------------------------------------------------------------------
    // 14. Apply prerequisite logic.
    //
    // This does not silently order the prerequisite. Instead, it can suppress
    // an investigation whose prerequisite is clearly unmet and leave the
    // ordering problem to the investigation workflow.
    // -------------------------------------------------------------------------

    const dependencies = await this.loadDependencies(
      [...aggregate.keys()],
    );

    for (const dependency of dependencies) {
      const prerequisiteSatisfied =
        capturedCodes.has(
          dependency.prerequisite_investigation_code,
        );

      if (!prerequisiteSatisfied) {
        const prerequisiteExists =
          aggregate.has(
            dependency.prerequisite_investigation_code,
          );

        if (!prerequisiteExists) {
          const candidate =
            aggregate.get(
              dependency.investigation_code,
            );

          if (candidate) {
            candidate.rationale =
              candidate.rationale
                ? `${candidate.rationale} Prerequisite consideration: ${dependency.rationale ?? dependency.prerequisite_investigation_code}.`
                : `Prerequisite consideration: ${dependency.rationale ?? dependency.prerequisite_investigation_code}.`;
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 15. Final scoring.
    //
    // Clinical utility =
    //
    //   disease relevance
    // + mechanism relevance
    // + decision impact
    // + protocol importance
    // + contextual support
    // + severity
    //
    // The exact numerical values remain implementation details. The important
    // architectural property is that every score has a traceable source.
    // -------------------------------------------------------------------------

    const recommendations = [...aggregate.values()]
      .map((entry) => {
        let score = entry.weight;

        score += entry.decisionImpact * 0.25;

        if (entry.protocolRequired) {
          score += 2;
        }

        if (entry.contextSupported) {
          score += 0.5;
        }

        if (entry.safetyRelevant) {
          score += 1.5;
        }

        return {
          entry,
          score: round(score),
        };
      })
      .sort((a, b) => {
        if (b.score !== a.score) {
          return b.score - a.score;
        }

        if (
          a.entry.protocolRequired !==
          b.entry.protocolRequired
        ) {
          return a.entry.protocolRequired ? -1 : 1;
        }

        return a.entry.name.localeCompare(
          b.entry.name,
        );
      });

    // -------------------------------------------------------------------------
    // 16. Project into public Clinical CPU type.
    // -------------------------------------------------------------------------

    return recommendations.map(
      ({ entry, score }) =>
        this.projectRecommendation(
          entry,
          score,
        ),
    );
  }


  // ===========================================================================
  // DATABASE LOADERS
  // ===========================================================================

  private async loadConditionInvestigations(
    conditionCodes: string[],
  ): Promise<ConditionInvestigationRow[]> {

    if (conditionCodes.length === 0) {
      return [];
    }

    return this.db.query<ConditionInvestigationRow>(
      `
      SELECT
        c.condition_code,
        i.investigation_code,
        i.canonical_name,
        i.investigation_type,
        ic.weight,
        ic.rationale,

        COALESCE(ic.role, 'diagnostic') AS role,

        ic.clinical_question,
        ic.decision_impact

      FROM knowledge.investigation_condition ic

      JOIN knowledge.condition c
        ON c.id = ic.condition_id

      JOIN knowledge.investigation i
        ON i.id = ic.investigation_id

      WHERE c.condition_code = ANY($1::text[])

        AND COALESCE(c.status, 'active') = 'active'

        AND COALESCE(i.status, 'active') = 'active'

      ORDER BY
        ic.weight DESC,
        i.investigation_code
      `,
      [conditionCodes],
    );
  }


  private async loadMechanismInvestigations(
    mechanismCodes: string[],
  ): Promise<MechanismInvestigationRow[]> {

    if (mechanismCodes.length === 0) {
      return [];
    }

    return this.db.query<MechanismInvestigationRow>(
      `
      SELECT
        m.mechanism_code,
        i.investigation_code,
        i.canonical_name,
        i.investigation_type,
        mi.weight,
        mi.rationale,

        COALESCE(mi.role, 'diagnostic') AS role,

        mi.clinical_question,
        mi.decision_impact

      FROM knowledge.mechanism_investigation mi

      JOIN knowledge.mechanism m
        ON m.id = mi.mechanism_id

      JOIN knowledge.investigation i
        ON i.investigation_code = mi.investigation_code

      WHERE m.mechanism_code = ANY($1::text[])

        AND COALESCE(m.status, 'active') = 'active'

        AND COALESCE(i.status, 'active') = 'active'

      ORDER BY
        mi.weight DESC,
        i.investigation_code
      `,
      [mechanismCodes],
    );
  }


  private async loadInvestigations(): Promise<
    InvestigationRow[]
  > {

    return this.db.query<InvestigationRow>(
      `
      SELECT
        investigation_code,
        canonical_name,
        investigation_type,

        status,

        0 AS default_priority,

        invasiveness,
        turn_around_minutes AS turnaround_category

      FROM knowledge.investigation

      WHERE COALESCE(status, 'active') = 'active'

      ORDER BY investigation_code
      `,
    );
  }


  private async loadInvestigationResultFacts(): Promise<
    InvestigationFactRow[]
  > {

    // Preferred schema: explicit investigation → result fact mapping.
    //
    // If the table has not yet been deployed, the fallback map above keeps
    // compatibility with earlier AMEXAN seeds.
    try {
      return await this.db.query<InvestigationFactRow>(
        `
        SELECT
          i.investigation_code,
          irf.fact_definition_code

        FROM knowledge.investigation_result_fact irf

        JOIN knowledge.investigation_result ir
          ON ir.id = irf.investigation_result_id

        JOIN knowledge.investigation i
          ON i.id = ir.investigation_id

        WHERE COALESCE(irf.polarity, 'positive') = 'positive'

          AND COALESCE(ir.status, 'active') = 'active'
        `,
      );
    } catch {
      return [];
    }
  }


  private async loadProtocolInvestigations(): Promise<
    ProtocolInvestigationRow[]
  > {

    // AMEXAN installations can expose active protocol investigations through
    // different knowledge structures. The preferred structure is attempted
    // first. Failure falls back to an empty set rather than breaking clinical
    // capture.
    try {
      return await this.db.query<ProtocolInvestigationRow>(
        `
        SELECT
          i.investigation_code,
          p.protocol_code,
          pi.priority::numeric(5,4) AS priority_weight,
          pi.indication AS rationale

        FROM knowledge.protocol_investigation pi

        JOIN knowledge.protocol_step ps
          ON ps.id = pi.step_id

        JOIN knowledge.protocol p
          ON p.id = ps.protocol_id

        JOIN knowledge.investigation i
          ON i.id = pi.investigation_id

        WHERE COALESCE(p.status, 'active') = 'active'

          AND COALESCE(ps.status, 'active') = 'active'
        `,
      );
    } catch {
      return [];
    }
  }


  private async loadContextRules(): Promise<
    ContextRuleRow[]
  > {

    try {
      return await this.db.query<ContextRuleRow>(
        `
        SELECT
          investigation_code,
          context_type,
          context_value,
          action,
          priority_weight,
          rationale

        FROM knowledge.investigation_context_rule

        WHERE COALESCE(status, 'active') = 'active'
        `,
      );
    } catch {
      return [];
    }
  }


  private async loadExistingInvestigations(
    encounterId: string | null,
    patientId: string | null,
  ): Promise<ExistingInvestigationRow[]> {

    if (!encounterId && !patientId) {
      return [];
    }

    try {
      if (encounterId) {
        return await this.db.query<ExistingInvestigationRow>(
          `
          SELECT
            investigation_code,
            status,
            performed_at::text AS performed_at

          FROM clinical.investigation_order

          WHERE encounter_id = $1

          ORDER BY performed_at DESC NULLS LAST
          `,
          [encounterId],
        );
      }

      return await this.db.query<ExistingInvestigationRow>(
        `
        SELECT
          investigation_code,
          status,
          performed_at::text AS performed_at

        FROM clinical.investigation_order

        WHERE patient_id = $1

        ORDER BY performed_at DESC NULLS LAST
        `,
        [patientId],
      );
    } catch {
      return [];
    }
  }


  private async loadDependencies(
    investigationCodes: string[],
  ): Promise<InvestigationDependencyRow[]> {

    if (investigationCodes.length === 0) {
      return [];
    }

    try {
      return await this.db.query<InvestigationDependencyRow>(
        `
        SELECT
          investigation_code,
          prerequisite_investigation_code,
          rationale

        FROM knowledge.investigation_dependency

        WHERE investigation_code = ANY($1::text[])

          AND COALESCE(status, 'active') = 'active'
        `,
        [investigationCodes],
      );
    } catch {
      return [];
    }
  }


  // ===========================================================================
  // SEVERITY INTELLIGENCE
  // ===========================================================================

  private async applySeverityCandidates(
    aggregate: Map<string, CandidateAccumulator>,
    capturedCodes: Set<string>,
    resultFactMap: Map<string, string[]>,
    state: PatientClinicalState,
    investigationMap: Map<string, InvestigationRow>,
  ): Promise<void> {

    const facts = new Set(
      (state.facts ?? []).map((f) => f.factCode),
    );

    for (const fact of capturedCodes) {
      facts.add(fact);
    }

    // -------------------------------------------------------------------------
    // HYPOXAEMIA
    // -------------------------------------------------------------------------

    if (
      facts.has('HYPOXAEMIA') ||
      facts.has('SEVERE_RESPIRATORY_DISTRESS') ||
      facts.has('RESPIRATORY_DISTRESS')
    ) {
      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-ABG',
        5,
        'Assess oxygenation and acid-base status in significant respiratory compromise.',
        'severity',
        'severity',
      );
    }

    // -------------------------------------------------------------------------
    // SHOCK / POOR PERFUSION
    // -------------------------------------------------------------------------

    if (
      facts.has('SHOCK') ||
      facts.has('POOR_PERFUSION') ||
      facts.has('HYPOTENSION') ||
      facts.has('SEPSIS')
    ) {
      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-LACTATE',
        5,
        'Assess physiological severity and tissue hypoperfusion.',
        'severity',
        'severity',
      );

      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-UREA-CREAT',
        3,
        'Assess renal function and metabolic consequences of severe illness.',
        'severity',
        'severity',
      );
    }

    // -------------------------------------------------------------------------
    // SUSPECTED SEVERE INFECTION / SEPSIS
    // -------------------------------------------------------------------------

    if (
      facts.has('SEPSIS') ||
      facts.has('SEVERE_INFECTION') ||
      facts.has('BACTERAEMIA_SUSPECTED')
    ) {
      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-BLOOD-CULTURE',
        5,
        'Evaluate for bloodstream infection when clinically indicated.',
        'severity',
        'complication',
      );

      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-LACTATE',
        4,
        'Assess severity of systemic illness and tissue hypoperfusion.',
        'severity',
        'severity',
      );
    }

    // -------------------------------------------------------------------------
    // RENAL / ELECTROLYTE RISK
    // -------------------------------------------------------------------------

    if (
      facts.has('DEHYDRATION') ||
      facts.has('AKI_RISK') ||
      facts.has('RENAL_DYSFUNCTION') ||
      facts.has('OLIGURIA')
    ) {
      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-UREA-CREAT',
        5,
        'Assess renal function in the context of volume depletion or renal risk.',
        'severity',
        'severity',
      );
    }

    // -------------------------------------------------------------------------
    // HYPOGLYCAEMIA / ALTERED CONSCIOUSNESS
    // -------------------------------------------------------------------------

    if (
      facts.has('ALTERED_CONSCIOUSNESS') ||
      facts.has('REDUCED_LEVEL_OF_CONSCIOUSNESS') ||
      facts.has('SEIZURE') ||
      facts.has('HYPOGLYCAEMIA_RISK')
    ) {
      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-RBS',
        5,
        'Check glucose as a potentially reversible cause or complication.',
        'severity',
        'severity',
      );
    }

    // -------------------------------------------------------------------------
    // ANEMIA / BLEEDING / CHRONIC DISEASE
    // -------------------------------------------------------------------------

    if (
      facts.has('BLEEDING') ||
      facts.has('HAEMORRHAGE') ||
      facts.has('PALLOR') ||
      facts.has('ANEMIA_SUSPECTED')
    ) {
      this.boostCandidate(
        aggregate,
        investigationMap,
        'INV-FBC',
        4,
        'Assess haemoglobin and blood-cell indices in suspected anaemia or bleeding.',
        'severity',
        'severity',
      );
    }

    // Keep TypeScript aware that this argument is intentionally part of the
    // clinical closure interface.
    void resultFactMap;
  }


  private boostCandidate(
    aggregate: Map<string, CandidateAccumulator>,
    investigationMap: Map<string, InvestigationRow>,
    investigationCode: string,
    weight: number,
    rationale: string,
    source: RecommendationSource,
    role: InvestigationRole,
  ): void {

    const investigation =
      investigationMap.get(investigationCode);

    if (!investigation) {
      return;
    }

    const entry = this.getOrCreate(
      aggregate,
      investigationCode,
      investigation.canonical_name,
      investigation.investigation_type,
      source,
    );

    entry.weight += weight;
    entry.rationale =
      entry.rationale ??
      rationale;

    entry.role =
      entry.role ??
      role;

    entry.safetyRelevant = true;
    entry.sources.add(source);
  }


  // ===========================================================================
  // OVERRIDES
  // ===========================================================================

  private applyOverrides(
    aggregate: Map<string, CandidateAccumulator>,
    overrides: ConfigurationOverride[],
    investigationMap: Map<string, InvestigationRow>,
  ): void {

    const overrideByCode = new Map(
      overrides.map((o) => [
        o.targetCode,
        o,
      ]),
    );

    for (const [code, entry] of aggregate) {
      const override =
        overrideByCode.get(code);

      if (!override) {
        continue;
      }

      entry.sources.add('configuration');

      const config =
        override.config ?? {};

      // Configuration may replace the rationale.
      const rationale =
        config.rationale;

      if (
        typeof rationale === 'string' &&
        rationale.trim()
      ) {
        entry.rationale =
          rationale.trim();
      }

      // Optional weight adjustment.
      const weightAdjustment =
        readNumber(
          config.weightAdjustment,
        );

      if (weightAdjustment != null) {
        entry.weight +=
          weightAdjustment;
      }

      // Optional priority multiplier.
      const multiplier =
        readNumber(
          config.priorityMultiplier,
        );

      if (
        multiplier != null &&
        multiplier >= 0
      ) {
        entry.weight *= multiplier;
      }

      const role =
        typeof config.role === 'string'
          ? normalizeRole(config.role)
          : null;

      if (role) {
        entry.role = role;
      }

      const investigation =
        investigationMap.get(code);

      if (
        investigation &&
        typeof config.clinicalQuestion === 'string'
      ) {
        entry.clinicalQuestion =
          config.clinicalQuestion;
      }
    }
  }


  // ===========================================================================
  // CANDIDATE CREATION
  // ===========================================================================

  private getOrCreate(
    aggregate: Map<string, CandidateAccumulator>,
    investigationCode: string,
    name: string,
    type: string,
    source: RecommendationSource,
  ): CandidateAccumulator {

    const existing =
      aggregate.get(investigationCode);

    if (existing) {
      existing.sources.add(source);
      return existing;
    }

    const created: CandidateAccumulator = {
      investigationCode,
      name,
      type,

      weight: 0,

      rationale: null,

      source,

      sources: new Set([
        source,
      ]),

      role: null,

      clinicalQuestion: null,

      decisionImpact: 0,

      protocolRequired: false,

      contextSupported: false,

      safetyRelevant: false,
    };

    aggregate.set(
      investigationCode,
      created,
    );

    return created;
  }


  // ===========================================================================
  // RESULT SATISFACTION
  // ===========================================================================

  private isSatisfied(
    investigationCode: string,
    capturedCodes: Set<string>,
    resultFactMap: Map<string, string[]>,
  ): boolean {

    const resultFacts =
      resultFactMap.get(
        investigationCode,
      ) ?? [];

    // No mapped result facts means that the CPU cannot safely infer that the
    // investigation has been completed merely from current facts.
    if (resultFacts.length === 0) {
      return false;
    }

    return resultFacts.every(
      (factCode) =>
        capturedCodes.has(factCode),
    );
  }


  // ===========================================================================
  // PUBLIC PROJECTION
  // ===========================================================================

  private projectRecommendation(
    entry: CandidateAccumulator,
    score: number,
  ): InvestigationRecommendation {

    const rationale =
      this.buildRationale(entry);

    return {
      investigationCode:
        entry.investigationCode,

      name:
        entry.name,

      type:
        entry.type,

      weight:
        round(score),

      rationale,

      source:
        this.primarySource(entry),

      // These fields are intentionally added only if the project's public type
      // supports them. If the current type is narrower, retain the first
      // five fields above and extend InvestigationRecommendation in types.ts.
      ...(entry.role
        ? { role: entry.role }
        : {}),

      ...(entry.clinicalQuestion
        ? {
            clinicalQuestion:
              entry.clinicalQuestion,
          }
        : {}),

      ...(entry.protocolRequired
        ? {
            protocolRequired:
              true,
          }
        : {}),

      ...(entry.safetyRelevant
        ? {
            safetyRelevant:
              true,
          }
        : {}),
    } as InvestigationRecommendation;
  }


  private primarySource(
    entry: CandidateAccumulator,
  ): RecommendationSource {

    // Preserve clinically meaningful provenance.
    if (entry.sources.has('severity')) {
      return 'severity';
    }

    if (entry.sources.has('protocol')) {
      return 'protocol';
    }

    if (entry.sources.has('condition')) {
      return 'condition';
    }

    if (entry.sources.has('mechanism')) {
      return 'mechanism';
    }

    if (entry.sources.has('context')) {
      return 'context';
    }

    if (entry.sources.has('configuration')) {
      return 'configuration';
    }

    return entry.source;
  }


  private buildRationale(
    entry: CandidateAccumulator,
  ): string {

    const base =
      entry.rationale ??
      'Potentially useful for the current clinical assessment.';

    const reasons: string[] = [];

    if (
      entry.sources.has('condition') &&
      entry.sources.has('mechanism')
    ) {
      reasons.push(
        'supported by both the leading differential and mechanism',
      );
    }

    if (
      entry.sources.has('severity')
    ) {
      reasons.push(
        'also relevant to severity assessment',
      );
    }

    if (
      entry.protocolRequired
    ) {
      reasons.push(
        'also supported by an active protocol',
      );
    }

    if (
      entry.contextSupported
    ) {
      reasons.push(
        'supported by the current patient context',
      );
    }

    if (
      entry.safetyRelevant
    ) {
      reasons.push(
        'relevant to safety/severity assessment',
      );
    }

    if (reasons.length === 0) {
      return base;
    }

    return `${base} ${capitalize(reasons.join('; '))}.`;
  }
}


// =============================================================================
// PATIENT CONTEXT
// =============================================================================

function buildPatientContext(
  state: PatientClinicalState,
): Map<string, Set<string>> {

  const vector =
    new Map<string, Set<string>>();

  const add = (
    dimension: string,
    value:
      | string
      | null
      | undefined,
  ) => {

    if (
      value == null ||
      value.trim?.() === ''
    ) {
      return;
    }

    const normalized =
      value.trim();

    const set =
      vector.get(dimension) ??
      new Set<string>();

    set.add(normalized);

    vector.set(
      dimension,
      set,
    );
  };

  add(
    'AGE_BAND',
    state.ageBand,
  );

  add(
    'SEX',
    normalizeSex(state.sex),
  );

  add(
    'DEPARTMENT',
    state.departmentCode,
  );

  add(
    'ENCOUNTER_TYPE',
    state.encounterTypeCode,
  );

  if (
    state.pregnant != null
  ) {
    add(
      'PREGNANCY',
      state.pregnant
        ? 'pregnant'
        : 'not_pregnant',
    );
  }

  if (
    state.gestationalAgeWeeks != null
  ) {
    add(
      'GESTATIONAL_AGE',
      `${state.gestationalAgeWeeks}`,
    );
  }

  for (
    const domain of
    state.activeDomains ?? []
  ) {
    add(
      'SYMPTOM_DOMAIN',
      domain.toUpperCase(),
    );
  }

  for (
    const fact of
    (state.facts ?? []).map((f) => f.factCode)
  ) {
    add(
      'FACT',
      fact.toUpperCase(),
    );
  }

  return vector;
}


// =============================================================================
// CONTEXT MATCHER
// =============================================================================

function contextMatches(
  contextType: string,
  contextValue: string,
  vector: Map<string, Set<string>>,
): boolean {

  const set =
    vector.get(contextType);

  if (!set) {
    return false;
  }

  if (
    set.has(contextValue)
  ) {
    return true;
  }

  const target =
    contextValue
      .trim()
      .toLowerCase();

  for (
    const value of set
  ) {
    if (
      value
        .trim()
        .toLowerCase() === target
    ) {
      return true;
    }
  }

  return false;
}


// =============================================================================
// ROLE NORMALIZATION
// =============================================================================

function normalizeRole(
  role:
    | string
    | null
    | undefined,
): InvestigationRole {

  const normalized =
    (role ?? '')
      .trim()
      .toLowerCase();

  switch (normalized) {

    case 'confirmatory':
      return 'confirmatory';

    case 'supportive':
      return 'supportive';

    case 'severity':
      return 'severity';

    case 'complication':
      return 'complication';

    case 'baseline':
      return 'baseline';

    case 'monitoring':
      return 'monitoring';

    case 'exclusion':
      return 'exclusion';

    case 'screening':
      return 'screening';

    case 'pre_treatment':
    case 'pretreatment':
      return 'pre_treatment';

    case 'diagnostic':
    default:
      return 'diagnostic';
  }
}


// =============================================================================
// SEX NORMALIZATION
// =============================================================================

function normalizeSex(
  sex:
    | string
    | null
    | undefined,
): string | null {

  if (!sex) {
    return null;
  }

  const value =
    sex
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
      return 'intersex';

    case 'unknown':
      return 'unknown';

    default:
      return value;
  }
}


// =============================================================================
// UTILITIES
// =============================================================================

function uniqueStrings(
  values: string[],
): string[] {

  return [
    ...new Set(
      values.filter(
        (value) =>
          Boolean(value),
      ),
    ),
  ];
}


function readNumber(
  value: unknown,
): number | null {

  if (
    typeof value === 'number' &&
    Number.isFinite(value)
  ) {
    return value;
  }

  if (
    typeof value === 'string' &&
    value.trim() !== ''
  ) {
    const number =
      Number(value);

    if (
      Number.isFinite(number)
    ) {
      return number;
    }
  }

  return null;
}


function round(
  value: number,
): number {

  return Math.round(
    value * 1000,
  ) / 1000;
}


function capitalize(
  value: string,
): string {

  if (!value) {
    return value;
  }

  return (
    value.charAt(0).toUpperCase() +
    value.slice(1)
  );
}