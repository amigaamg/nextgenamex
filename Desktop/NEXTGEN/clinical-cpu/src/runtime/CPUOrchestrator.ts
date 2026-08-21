// =============================================================================
// AMEXAN Clinical CPU — CPUOrchestrator
// =============================================================================
//
// AMEXAN is a universal clinical reasoning runtime.
//
// This orchestrator is the CLINICAL CPU, not a UI controller and not a
// diagnosis shortcut. It continuously transforms the patient's current
// evidence state into the safest, most relevant and most useful next clinical
// state.
//
// CORE LOOP
//
//   PATIENT STATE
//        │
//        ├── facts / symptoms / context / prior answers / results
//        │
//        ▼
//   PHENOTYPES
//        │
//        ▼
//   MECHANISMS
//        │
//        ▼
//   DIFFERENTIAL
//        │
//        ├── contradictions
//        ├── evidence
//        ├── severity
//        └── uncertainty
//        │
//        ▼
//   NEXT BEST QUESTIONS
//        │
//        ├── examination
//        ├── investigations
//        └── result interpretation
//        │
//        ▼
//   WORKING CLINICAL STATE
//        │
//        ├── protocol
//        ├── treatment
//        ├── monitoring
//        ├── education
//        ├── documentation
//        ├── recommendations
//        └── alerts
//
// Every new fact re-enters this loop.
//
// PRINCIPLES
//
// 1. Disease does not come first.
//    Facts → phenotypes → mechanisms → differential.
//
// 2. Differential diagnosis remains alive.
//    The CPU must not collapse prematurely onto one disease.
//
// 3. Unknown ≠ negative.
//    Missing evidence cannot be treated as absence of disease.
//
// 4. New evidence changes relevance.
//    Positive, negative and contradictory evidence continuously reshape the
//    ranking.
//
// 5. The next action must reduce meaningful uncertainty or protect safety.
//
// 6. Investigation results return to the SAME fact stream.
//    History, examination, laboratory and imaging facts are interchangeable
//    evidence once normalized.
//
// 7. Persistence is evidence continuity.
//    Previously captured facts, answered questions, investigation results,
//    context and prior clinical state are preserved through PatientClinicalState.
//
// 8. Knowledge is governed.
//    DRAFT / SUPERSEDED / DEPRECATED / RETIRED knowledge cannot silently
//    participate in live reasoning.
//
// 9. Local configuration can modify presentation and operational choices,
//    but cannot silently mutate the universal clinical knowledge model.
//
// 10. Protocol coordinates medicine; it does not redefine medicine.
//
// 11. The UI contains no clinical intelligence.
//     It renders ClinicalRuntimeProjection.
//
// 12. Speed matters.
//     Independent knowledge reads execute concurrently wherever possible.
//     Reasoning is staged so expensive work is only performed when relevant.
//
// 13. Universal medicine.
//     The same CPU works across medicine, surgery, paediatrics, OBGYN,
//     psychiatry, emergency medicine, oncology, infectious disease,
//     cardiology, nephrology, etc. Specialty knowledge lives in the database,
//     not in this orchestrator.
//
// =============================================================================

import type { Db } from '../db.js';

import type {
  ClinicalRuntimeProjection,
  DifferentialCandidate,
  KnowledgeGateResult,
  PatientClinicalState,
} from '../types.js';

import { ConfigurationResolver } from '../configuration/ConfigurationResolver.js';
import {
  AlertCandidate,
  DecisionEngine,
  RecommendationUrgency,
} from '../decisions/DecisionEngine.js';
import { ContradictionEngine } from '../differential/ContradictionEngine.js';
import { DocumentationEngine } from '../documentation/DocumentationEngine.js';
import { EducationEngine } from '../education/EducationEngine.js';
import { ExaminationSelector } from '../examination/ExaminationSelector.js';
import { FormatResolver } from '../format/FormatResolver.js';
import { InvestigationSelector } from '../investigation/InvestigationSelector.js';
import { MechanismEngine } from '../mechanism/MechanismEngine.js';
import { MonitoringEngine } from '../monitoring/MonitoringEngine.js';
import { PhenotypeEngine } from '../phenotype/PhenotypeEngine.js';
import { ProtocolEngine } from '../protocol/ProtocolEngine.js';
import { QuestionSelector } from '../questions/QuestionSelector.js';
import { SectionEngine } from '../section/SectionEngine.js';
import { DifferentialEngine } from '../differential/DifferentialEngine.js';
import { KnowledgeResolver } from '../governance/KnowledgeResolver.js';
import { SafetyEngine } from '../treatment/SafetyEngine.js';
import { SeverityScoreEngine } from '../severity/SeverityScoreEngine.js';
import { TreatmentEngine } from '../treatment/TreatmentEngine.js';


// =============================================================================
// RUNTIME CONSTANTS
// =============================================================================

/**
 * These are deliberately NOT the complete list of deterioration phenotypes.
 *
 * The database remains the source of truth.
 *
 * This set only provides an immediate universal safety layer for phenotypes
 * that should create an alert before a protocol-specific monitoring cycle has
 * necessarily been established.
 */
const IMMEDIATE_DETERIORATION_PHENOTYPES = new Set([
  'PHEN-HYPOXAEMIA',
  'PHEN-RESPIRATORY-FAILURE',
  'PHEN-SHOCK',
  'PHEN-ALTERED-CONSCIOUSNESS',
  'PHEN-SEVERE-RESPIRATORY-DISTRESS',
  'PHEN-SEVERE-DEHYDRATION',
]);

/**
 * Maximum number of differentials used for downstream operations.
 *
 * The differential itself remains larger.
 *
 * This prevents unnecessary database work while preserving a sufficiently
 * broad clinical reasoning field.
 */
const DIFFERENTIAL_REASONING_LIMIT = 8;

/**
 * Top candidates are used for immediate action generation.
 *
 * Keeping these values bounded is important for runtime performance.
 */
const TOP_DIFFERENTIAL_LIMIT = 3;
const TOP_PHENOTYPE_LIMIT = 5;
const TOP_MECHANISM_LIMIT = 5;


/**
 * Utility for measuring execution time without coupling the CPU to a logging
 * implementation.
 */
interface StageTiming {
  stage: string;
  milliseconds: number;
}

interface RuntimeMeta {
  generatedAt: string;
  timings?: StageTiming[];
  cycle: number;
}


/**
 * Optional extension shape.
 *
 * This is deliberately kept outside ClinicalRuntimeProjection so existing
 * consumers do not have to change immediately.
 */
interface RuntimeDiagnostics {
  stageCount: number;
  timings: StageTiming[];
}


// =============================================================================
// CPU ORCHESTRATOR
// =============================================================================

export class CPUOrchestrator {
  private readonly phenotype: PhenotypeEngine;
  private readonly mechanism: MechanismEngine;
  private readonly differential: DifferentialEngine;
  private readonly contradiction: ContradictionEngine;
  private readonly questions: QuestionSelector;
  private readonly examination: ExaminationSelector;
  private readonly investigation: InvestigationSelector;
  private readonly protocol: ProtocolEngine;
  private readonly monitoring: MonitoringEngine;
  private readonly education: EducationEngine;
  private readonly treatment: TreatmentEngine;
  private readonly safety: SafetyEngine;
  private readonly severity: SeverityScoreEngine;
  private readonly documentation: DocumentationEngine;
  private readonly decisions: DecisionEngine;
  private readonly configuration: ConfigurationResolver;
  private readonly governance: KnowledgeResolver;
  private readonly format: FormatResolver;
  private readonly sections: SectionEngine;

  /**
   * Runtime cycle counter.
   *
   * The CPU is stateless between calls by design.
   *
   * PatientClinicalState is the persistence boundary.
   *
   * This counter is only useful for diagnostics within a process.
   */
  private cycle = 0;

  constructor(private readonly db: Db) {
    this.phenotype = new PhenotypeEngine(db);
    this.mechanism = new MechanismEngine(db);
    this.differential = new DifferentialEngine(db);
    this.contradiction = new ContradictionEngine(db);
    this.questions = new QuestionSelector(db);
    this.examination = new ExaminationSelector(db);
    this.investigation = new InvestigationSelector(db);
    this.protocol = new ProtocolEngine(db);
    this.monitoring = new MonitoringEngine(db);
    this.education = new EducationEngine(db);
    this.treatment = new TreatmentEngine(db);
    this.safety = new SafetyEngine();
    this.severity = new SeverityScoreEngine(db);
    this.documentation = new DocumentationEngine(db);
    this.decisions = new DecisionEngine(db);
    this.configuration = new ConfigurationResolver(db);
    this.governance = new KnowledgeResolver(db);
    this.format = new FormatResolver(db);
    this.sections = new SectionEngine(db);
  }

  // ===========================================================================
  // MAIN CLINICAL CYCLE
  // ===========================================================================

  async run(
    state: PatientClinicalState,
  ): Promise<ClinicalRuntimeProjection> {
    const cycle = ++this.cycle;
    const timings: StageTiming[] = [];

    /*
     * -------------------------------------------------------------------------
     * STAGE 0 — NORMALIZE RUNTIME STATE
     * -------------------------------------------------------------------------
     *
     * We do not mutate the supplied state.
     *
     * The patient state is the persistent clinical memory.
     */
    const runtimeState = normalizeRuntimeState(state);

    /*
     * -------------------------------------------------------------------------
     * STAGE 1 — PHENOTYPE RESOLUTION
     * -------------------------------------------------------------------------
     *
     * Facts are converted into reusable clinical patterns.
     *
     * Example:
     *
     *   cough + fever + tachypnoea + crackles
     *
     * may produce:
     *
     *   infective respiratory syndrome
     *   lower respiratory involvement
     *   respiratory distress
     *
     * without immediately declaring "pneumonia".
     */
    const scoredPhenotypes = await timed(
      timings,
      'phenotype',
      () => this.phenotype.score(runtimeState.facts),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 2 — INITIAL DIFFERENTIAL
     * -------------------------------------------------------------------------
     *
     * Differential generation happens before protocol/treatment.
     *
     * This protects the architecture against premature disease anchoring.
     */
    const rankedDifferentials = await timed(
      timings,
      'differential',
      () => this.differential.rank(
        scoredPhenotypes,
        runtimeState.facts,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 3 — GOVERNANCE GATE
     * -------------------------------------------------------------------------
     *
     * The CPU never silently trusts stale clinical knowledge.
     *
     * Live:
     *   ACTIVE / governed live knowledge
     *
     * Block:
     *   DRAFT
     *   SUPERSEDED
     *   DEPRECATED
     *   RETIRED
     *
     * Ungoverned objects remain visible in governance diagnostics but are not
     * silently treated as equivalent to governed live knowledge.
     */
    const initialGate = await timed(
      timings,
      'governance',
      () => this.governance.gate([
        ...scoredPhenotypes.map((p) => ({
          kind: 'phenotype',
          code: p.phenotypeCode,
        })),
        ...rankedDifferentials.map((d) => ({
          kind: 'condition',
          code: d.conditionCode,
        })),
      ]),
    );

    const gate = cloneGate(initialGate);

    const phenotypes = keepLive(
      gate,
      scoredPhenotypes,
    );

    const differentials = keepLiveConditions(
      gate,
      rankedDifferentials,
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 4 — MECHANISM RESOLUTION
     * -------------------------------------------------------------------------
     *
     * Mechanisms consume BOTH:
     *
     *   facts
     *   phenotypes
     *
     * This gives AMEXAN reusable pathophysiological reasoning rather than a
     * disease-only lookup engine.
     */
    const mechanisms = await timed(
      timings,
      'mechanism',
      () => this.mechanism.resolve(
        runtimeState.facts,
        phenotypes,
        runtimeState.activeSymptoms,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 5 — NEXT BEST QUESTIONS
     * -------------------------------------------------------------------------
     *
     * Question selection is adaptive.
     *
     * The CPU does NOT ask every question in the database.
     *
     * It asks questions that are:
     *
     *   - currently applicable
     *   - clinically useful
     *   - safety relevant
     *   - unresolved
     *   - capable of changing the current reasoning
     *
     * Answered facts automatically disappear from the queue.
     */
    const nextQuestions = await timed(
      timings,
      'questions',
      () => this.questions.select(
        runtimeState,
        phenotypes,
        mechanisms,
        differentials,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 6 — PHYSICAL EXAMINATION
     * -------------------------------------------------------------------------
     *
     * Examination is selected from the active clinical state rather than
     * presenting a universal static examination checklist.
     */
    const examination = await timed(
      timings,
      'examination',
      () => this.examination.select(
        differentials,
        runtimeState,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 7 — SEVERITY
     * -------------------------------------------------------------------------
     *
     * Severity instruments are evaluated against all meaningful differential
     * candidates.
     *
     * Example:
     *
     *   pneumonia → CURB-65
     *   COPD → GOLD-related assessment
     *   stroke → relevant neurological severity instrument
     *
     * The instrument itself is selected by knowledge.
     */
    let severityScores = await timed(
      timings,
      'severity',
      () => this.severity.evaluate(
        differentials
          .slice(0, DIFFERENTIAL_REASONING_LIMIT)
          .map((d) => d.conditionCode),
        runtimeState.ageYears,
        runtimeState.facts,
      ),
    );

    /*
     * Severity instruments are knowledge objects too.
     *
     * Therefore they must pass governance.
     */
    if (severityScores.length > 0) {
      const scoreGate = await timed(
        timings,
        'severity-governance',
        () => this.governance.gate(
          severityScores.map((score) => ({
            kind: 'interpretation',
            code: score.scoreCode,
          })),
        ),
      );

      mergeGate(gate, scoreGate);

      const blockedScores = new Set(
        scoreGate.blocked.map((entry) => entry.code),
      );

      severityScores = severityScores.filter(
        (score) => !blockedScores.has(score.scoreCode),
      );
    }

    /*
     * -------------------------------------------------------------------------
     * STAGE 8 — INVESTIGATION SELECTION
     * -------------------------------------------------------------------------
     *
     * Investigations are question-driven.
     *
     * The CPU asks:
     *
     *   "What uncertainty does this investigation resolve?"
     *
     * rather than:
     *
     *   "What investigations are associated with this disease?"
     *
     * Existing facts prevent redundant recommendations.
     */
    const capturedCodes = new Set(
      runtimeState.facts.map((fact) => fact.factCode),
    );

    const investigationTargets = await timed(
      timings,
      'investigation-targets',
      () => this.investigationTargets(
        differentials,
        mechanisms,
      ),
    );

    const investigationOverrides = await timed(
      timings,
      'investigation-configuration',
      () => this.configuration.resolve(
        investigationTargets,
      ),
    );

    const investigations = await timed(
      timings,
      'investigations',
      () => this.investigation.select(
        differentials,
        mechanisms,
        capturedCodes,
        investigationOverrides,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 9 — PROTOCOL ACTIVATION
     * -------------------------------------------------------------------------
     *
     * Protocol is activated only AFTER:
     *
     *   facts
     *   phenotypes
     *   mechanisms
     *   differential
     *   governance
     *
     * have established a working clinical state.
     *
     * Protocol is coordination, not medical ontology.
     */
    let protocol = await timed(
      timings,
      'protocol',
      () => this.protocol.activate(
        differentials,
        runtimeState.ageYears,
        runtimeState.jurisdictionCode,
      ),
    );

    if (protocol) {
      const protocolGate = await timed(
        timings,
        'protocol-governance',
        () => this.governance.gate([
          {
            kind: 'protocol',
            code: protocol!.protocolCode,
          },
        ]),
      );

      mergeGate(gate, protocolGate);

      if (!protocolGate.passes) {
        protocol = null;
      }
    }

    /*
     * -------------------------------------------------------------------------
     * STAGE 10 — MONITORING
     * -------------------------------------------------------------------------
     *
     * Monitoring reads current facts.
     *
     * The next CPU cycle therefore naturally observes:
     *
     * baseline → current measurement → deviation → alert.
     */
    const monitoring = await timed(
      timings,
      'monitoring',
      () => this.monitoring.resolve(
        protocol?.protocolCode ?? null,
        runtimeState.facts,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 11 — EDUCATION
     * -------------------------------------------------------------------------
     *
     * Education follows the clinical state rather than being a static patient
     * handout catalogue.
     */
    const education = await timed(
      timings,
      'education',
      () => this.education.resolve(
        differentials,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 12 — TREATMENT
     * -------------------------------------------------------------------------
     *
     * Treatment is resolved from the working differential and patient context.
     *
     * SAFETY is applied AFTER treatment resolution and BEFORE the treatment
     * reaches the projection.
     *
     * This creates a final safety barrier.
     */
    const rawTreatment = await timed(
      timings,
      'treatment',
      () => this.treatment.resolve(
        differentials,
        runtimeState.ageYears,
        runtimeState.facts,
        runtimeState.jurisdictionCode,
      ),
    );

    const treatment = this.safety.apply(
      runtimeState.facts,
      rawTreatment,
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 13 — CONTRADICTION ANALYSIS
     * -------------------------------------------------------------------------
     *
     * Differential reasoning is not simply positive matching.
     *
     * Contradictory findings are explicitly represented so the CPU can avoid
     * treating a diagnosis as strong merely because several compatible facts
     * exist.
     */
    const contradictions = await timed(
      timings,
      'contradictions',
      () => this.contradiction.probe(
        runtimeState.facts,
        differentials,
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 14 — ALERT CONSTRUCTION
     * -------------------------------------------------------------------------
     *
     * Alerts combine:
     *
     *   protocol monitoring
     *   deterioration phenotypes
     *   safety-relevant current state
     */
    const alerts = buildAlerts(
      monitoring,
      phenotypes,
      runtimeState,
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 15 — CLINICAL DECISIONS
     * -------------------------------------------------------------------------
     *
     * Decisions are assembled only after the clinical state has been resolved.
     */
    const recommendations = this.decisions.build(
      investigations,
      treatment,
      monitoring,
      education,
      alerts,
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 16 — DOCUMENTATION
     * -------------------------------------------------------------------------
     *
     * Documentation is generated FROM the captured clinical stream.
     *
     * The documentation engine does not invent facts.
     */
    const documentation = await timed(
      timings,
      'documentation',
      () => this.documentation.build(
        runtimeState.facts,
        differentials,
        protocol,
        recommendations,
        hasChiefComplaint(runtimeState),
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 17 — WORKING CLINICAL STATE
     * -------------------------------------------------------------------------
     */
    const workingDiagnosis =
      differentials.length > 0
        ? differentials[0].name
        : null;

    const leadingPhenotype =
      phenotypes.length > 0
        ? phenotypes[0]
        : null;

    /*
     * -------------------------------------------------------------------------
     * STAGE 18 — CONFIGURATION PROJECTION
     * -------------------------------------------------------------------------
     *
     * Configuration is resolved separately from universal knowledge.
     *
     * This allows:
     *
     *   facility
     *   jurisdiction
     *   clinician
     *   service
     *   operational
     *
     * configuration without mutating universal clinical definitions.
     */
    const configurationOverrides = await timed(
      timings,
      'configuration',
      () => this.configuration.resolve(
        configTargets(
          differentials,
          investigations,
          protocol,
        ),
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 19 — UNIVERSAL FORMAT
     * -------------------------------------------------------------------------
     *
     * The clinical workspace is context-driven.
     *
     * The same clinical CPU can produce:
     *
     *   adult medicine
     *   paediatrics
     *   OBGYN
     *   emergency
     *   surgery
     *   inpatient
     *   outpatient
     *   neonatology
     *
     * without the orchestrator containing specialty-specific UI code.
     */
    const formatPlan = await timed(
      timings,
      'format',
      () => this.format.resolve(
        runtimeState,
      ),
    );

    const navigation = await timed(
      timings,
      'sections',
      () => this.sections.build(
        formatPlan,
        nextQuestions,
        runtimeState.facts.length > 0,
        hasChiefComplaint(runtimeState),
      ),
    );

    /*
     * -------------------------------------------------------------------------
     * STAGE 20 — PROJECTION
     * -------------------------------------------------------------------------
     *
     * This is the ONLY object the clinical workspace needs.
     *
     * The UI does not decide:
     *
     *   what to ask
     *   what to investigate
     *   what to monitor
     *   what diagnosis is leading
     *   what treatment is relevant
     *   what protocol applies
     *   what is urgent
     *
     * The CPU has already resolved those things.
     */
    return {
      currentPhase: determineClinicalPhase(runtimeState, {
        differentials,
        nextQuestions,
        investigations,
        treatment,
        protocol,
        alerts,
      }),

      patientId: runtimeState.patientId,
      encounterId: runtimeState.encounterId,

      /*
       * eventId remains null until the persistence/event layer assigns the
       * durable event identifier.
       *
       * The CPU should not invent persistence identifiers.
       */
      eventId: null,

      alerts,

      activeSymptoms: runtimeState.activeSymptoms,
      capturedFacts: runtimeState.facts,

      nextQuestions,

      phenotypes,
      mechanisms,
      differentials,

      examination,
      investigations,

      treatment,
      protocol,
      monitoring,

      severityScores,

      education,
      documentation,

      recommendations,

      explanations: buildExplanations(
        workingDiagnosis,
        phenotypes,
        mechanisms,
        contradictions,
      ),

      contradictions,

      configuration: {
        overrides: configurationOverrides,
      },

      confidence: {
        workingDiagnosis,
        leadingPhenotypeScore:
          leadingPhenotype?.score ?? 0,
      },

      governance: {
        gate,
      },

      formatPlan,
      navigation,

      /*
       * These are intentionally attached only if the existing TypeScript
       * projection type permits extension.
       *
       * If ClinicalRuntimeProjection is currently closed, keep this metadata
       * in server-side diagnostics rather than changing the public projection
       * contract.
       */
      ...(supportsRuntimeMeta()
        ? {
            runtime: {
              generatedAt: new Date().toISOString(),
              cycle,
              timings,
            },
          }
        : {}),
    } as ClinicalRuntimeProjection;
  }

  // ===========================================================================
  // INVESTIGATION TARGET RESOLUTION
  // ===========================================================================

  /**
   * Finds investigations relevant to the current leading clinical state.
   *
   * Only the leading condition/mechanism region is queried because the
   * InvestigationSelector itself performs the final ranking.
   *
   * This keeps the universal knowledge base large without turning every
   * clinical cycle into a full-database scan.
   */
  private async investigationTargets(
    differentials: Array<{ conditionCode: string }>,
    mechanisms: Array<{ mechanismCode: string }>,
  ): Promise<{ type: string; code: string }[]> {
    const conditionCodes = differentials
      .slice(0, TOP_DIFFERENTIAL_LIMIT)
      .map((d) => d.conditionCode);

    const mechanismCodes = mechanisms
      .slice(0, TOP_MECHANISM_LIMIT)
      .map((m) => m.mechanismCode);

    if (
      conditionCodes.length === 0 &&
      mechanismCodes.length === 0
    ) {
      return [];
    }

    const rows = await this.db.query<{
      investigation_code: string;
    }>(
      `
        SELECT DISTINCT i.investigation_code
          FROM knowledge.investigation_condition ic
          JOIN knowledge.condition c
            ON c.id = ic.condition_id
          JOIN knowledge.investigation i
            ON i.id = ic.investigation_id
         WHERE c.condition_code = ANY($1::text[])

        UNION

        SELECT DISTINCT i.investigation_code
          FROM knowledge.mechanism_investigation mi
          JOIN knowledge.mechanism m
            ON m.id = mi.mechanism_id
          JOIN knowledge.investigation i
            ON i.investigation_code = mi.investigation_code
         WHERE m.mechanism_code = ANY($2::text[])
      `,
      [
        conditionCodes,
        mechanismCodes,
      ],
    );

    return rows.map((row) => ({
      type: 'investigation',
      code: row.investigation_code,
    }));
  }
}


// =============================================================================
// RUNTIME STATE NORMALIZATION
// =============================================================================

/**
 * Never mutate the persistence object supplied by the caller.
 *
 * This protects the event/state layer from accidental modifications by a
 * downstream engine.
 */
function normalizeRuntimeState(
  state: PatientClinicalState,
): PatientClinicalState {
  return {
    ...state,

    activeSymptoms: [...(state.activeSymptoms ?? [])],

    facts: [...(state.facts ?? [])],

    answeredQuestions: [
      ...(state.answeredQuestions ?? []),
    ],
  };
}


/**
 * Whether a chief complaint has been recorded.
 *
 * A chief complaint exists when:
 *   - a presenting symptom has been activated (SYMPTOM_PRESENTED), or
 *   - the PRESENTING_COMPLAINT summary fact has been captured
 *     (CHIEF_COMPLAINTS_SAVED).
 *
 * HPI exploration is gated on this: without a chief complaint there is
 * nothing for the HPI to explore.
 */
function hasChiefComplaint(
  state: PatientClinicalState,
): boolean {
  if (
    Array.isArray(state.activeSymptoms)
    && state.activeSymptoms.length > 0
  ) {
    return true;
  }

  return (state.facts ?? []).some(
    (fact) => fact.factCode === 'PRESENTING_COMPLAINT',
  );
}


// =============================================================================
// GOVERNANCE HELPERS
// =============================================================================

function cloneGate(
  gate: KnowledgeGateResult,
): KnowledgeGateResult {
  return {
    checked: gate.checked,
    blocked: [...gate.blocked],
    ungoverned: [...gate.ungoverned],
    valid: [...gate.valid],
    passes: gate.passes,
  };
}


function mergeGate(
  target: KnowledgeGateResult,
  source: KnowledgeGateResult,
): void {
  target.checked += source.checked;

  target.blocked.push(
    ...source.blocked,
  );

  target.ungoverned.push(
    ...source.ungoverned,
  );

  target.valid.push(
    ...source.valid,
  );

  /*
   * A combined gate passes only if every participating gate passes.
   */
  target.passes =
    target.passes &&
    source.passes;
}


/**
 * Keep only governed/live phenotype objects.
 *
 * The original ranking order is preserved.
 */
function keepLive<
  T extends { phenotypeCode: string },
>(
  gate: KnowledgeGateResult,
  phenotypes: T[],
): T[] {
  const blocked = new Set(
    gate.blocked
      .filter((entry) => entry.kind === 'phenotype')
      .map((entry) => entry.code),
  );

  return phenotypes.filter(
    (phenotype) =>
      !blocked.has(phenotype.phenotypeCode),
  );
}


/**
 * Keep only governed/live disease hypotheses.
 *
 * A retired disease must disappear from the runtime differential.
 */
function keepLiveConditions<
  T extends { conditionCode: string },
>(
  gate: KnowledgeGateResult,
  differentials: T[],
): T[] {
  const blocked = new Set(
    gate.blocked
      .filter((entry) => entry.kind === 'condition')
      .map((entry) => entry.code),
  );

  return differentials.filter(
    (differential) =>
      !blocked.has(differential.conditionCode),
  );
}


// =============================================================================
// ALERT ENGINE
// =============================================================================

function alertLevelToUrgency(
  level: string,
): RecommendationUrgency {
  switch (level) {
    case 'emergency':
      return 'immediate';
    case 'urgent':
      return 'urgent';
    case 'info':
      return 'info';
    default:
      return 'urgent';
  }
}

function buildAlerts(
  monitoring: Array<{
    monitoringCode: string;
    alert: string | null;
  }>,
  phenotypes: Array<{
    phenotypeCode: string;
    score: number;
  }>,
  state: PatientClinicalState,
): AlertCandidate[] {
  const alerts: AlertCandidate[] = [];

  /*
   * Monitoring-derived alerts.
   */
  for (const monitor of monitoring) {
    if (!monitor.alert) continue;

    alerts.push({
      level: alertLevelToUrgency('warning'),
      code: monitor.monitoringCode,
      message: monitor.alert,
    });
  }

  /*
   * Phenotype-derived immediate safety alerts.
   *
   * This is intentionally conservative:
   * active phenotype + positive score → alert.
   */
  for (const phenotype of phenotypes) {
    if (
      phenotype.score <= 0 ||
      !IMMEDIATE_DETERIORATION_PHENOTYPES.has(
        phenotype.phenotypeCode,
      )
    ) {
      continue;
    }

    alerts.push({
      level: alertLevelToUrgency('urgent'),
      code: phenotype.phenotypeCode,
      message:
        `${phenotype.phenotypeCode} is active ` +
        `(score ${phenotype.score}) — reassess the patient's ` +
        `current physiological status and escalate according to ` +
        `the applicable clinical pathway`,
    });
  }

  /*
   * Duplicate protection.
   *
   * Multiple engines may converge on the same safety state.
   */
  return deduplicateAlerts(alerts);
}


function deduplicateAlerts(
  alerts: AlertCandidate[],
): AlertCandidate[] {
  const seen = new Set<string>();
  const result: AlertCandidate[] = [];

  for (const alert of alerts) {
    const key = `${alert.level}:${alert.code}`;

    if (seen.has(key)) continue;

    seen.add(key);
    result.push(alert);
  }

  return result;
}


// =============================================================================
// EXPLANATION BUILDER
// =============================================================================

/**
 * Explanations describe the current reasoning state without pretending that
 * compatibility equals certainty.
 *
 * This is deliberately not an LLM-generated narrative.
 *
 * The evidence objects themselves remain authoritative.
 */
function buildExplanations(
  workingDiagnosis: string | null,
  phenotypes: Array<{
    phenotypeCode: string;
    name: string;
    score: number;
  }>,
  mechanisms: Array<{
    mechanismCode: string;
    name: string;
    support: number;
  }>,
  contradictions: unknown[],
): Array<{
  label: string;
  body: string;
}> {
  const explanations: Array<{
    label: string;
    body: string;
  }> = [];

  if (workingDiagnosis) {
    explanations.push({
      label: 'Working diagnosis',
      body:
        `${workingDiagnosis}. This is the current leading ` +
        `working hypothesis, not an irreversible diagnosis.`,
    });
  }

  if (phenotypes.length > 0) {
    explanations.push({
      label: 'Clinical phenotype',
      body: phenotypes
        .slice(0, TOP_PHENOTYPE_LIMIT)
        .map(
          (phenotype) =>
            `${phenotype.name} (${phenotype.score})`,
        )
        .join(' → '),
    });
  }

  if (mechanisms.length > 0) {
    explanations.push({
      label: 'Mechanism interpretation',
      body: mechanisms
        .slice(0, TOP_MECHANISM_LIMIT)
        .map(
          (mechanism) =>
            `${mechanism.name} (${mechanism.support})`,
        )
        .join(' → '),
    });
  }

  if (contradictions.length > 0) {
    explanations.push({
      label: 'Contradictory evidence',
      body:
        `${contradictions.length} contradiction(s) require ` +
        `review before the differential is treated as settled.`,
    });
  }

  return explanations;
}


// =============================================================================
// CONFIGURATION TARGETS
// =============================================================================

/**
 * Configuration is deliberately separate from clinical knowledge.
 *
 * The universal medical model remains unchanged while facility/jurisdiction/
 * service-level configuration can reshape operational presentation.
 */
function configTargets(
  differentials: Array<{
    conditionCode: string;
  }>,
  investigations: Array<{
    investigationCode: string;
  }>,
  protocol: {
    protocolCode: string;
  } | null,
): Array<{
  type: string;
  code: string;
}> {
  const targets: Array<{
    type: string;
    code: string;
  }> = [];

  /*
   * Top conditions are sufficient for immediate configuration resolution.
   * The full differential remains available to the clinical projection.
   */
  for (
    const differential of differentials.slice(
      0,
      TOP_DIFFERENTIAL_LIMIT,
    )
  ) {
    targets.push({
      type: 'condition',
      code: differential.conditionCode,
    });
  }

  for (const investigation of investigations) {
    targets.push({
      type: 'investigation',
      code: investigation.investigationCode,
    });
  }

  if (protocol) {
    targets.push({
      type: 'protocol',
      code: protocol.protocolCode,
    });
  }

  return targets;
}


// =============================================================================
// CLINICAL PHASE
// =============================================================================

/**
 * Determines what the clinician is currently doing.
 *
 * This is a runtime state, not a disease classification.
 */
function determineClinicalPhase(
  state: PatientClinicalState,
  context: {
    differentials: unknown[];
    nextQuestions: unknown[];
    investigations: unknown[];
    treatment: unknown[];
    protocol: unknown | null;
     alerts: AlertCandidate[],
   },
): string {
  /*
   * Safety takes precedence over workflow.
   */
  if (
    context.alerts.some(
      (alert) =>
        alert.level === 'urgent' ||
        alert.level === 'immediate',
    )
  ) {
    return 'safety_review';
  }

  /*
   * If the patient has not supplied enough evidence, continue acquisition.
   */
  if (
    context.nextQuestions.length > 0 &&
    state.facts.length === 0
  ) {
    return 'history';
  }

  /*
   * Once evidence exists, unresolved questions remain part of clinical
   * information acquisition.
   */
  if (context.nextQuestions.length > 0) {
    return 'clinical_reasoning';
  }

  /*
   * Investigation phase.
   */
  if (context.investigations.length > 0) {
    return 'investigation';
  }

  /*
   * A protocol may now coordinate treatment/monitoring.
   */
  if (
    context.protocol &&
    context.treatment.length > 0
  ) {
    return 'management';
  }

  if (context.treatment.length > 0) {
    return 'management';
  }

  /*
   * Fallback.
   */
  if (context.differentials.length > 0) {
    return 'clinical_reasoning';
  }

  return 'information_acquisition';
}


// =============================================================================
// PERFORMANCE
// =============================================================================

/**
 * Measure a stage without changing its semantics.
 */
async function timed<T>(
  timings: StageTiming[],
  stage: string,
  operation: () => Promise<T>,
): Promise<T> {
  const start = performance.now();

  try {
    return await operation();
  } finally {
    timings.push({
      stage,
      milliseconds: round(
        performance.now() - start,
      ),
    });
  }
}


function round(
  value: number,
): number {
  return Math.round(value * 100) / 100;
}


/**
 * Kept isolated because ClinicalRuntimeProjection in older AMEXAN versions
 * may not yet contain a runtime metadata field.
 *
 * This allows the orchestrator to evolve without forcing the UI contract to
 * evolve simultaneously.
 */
function supportsRuntimeMeta(): boolean {
  return true;
}