// =============================================================================
// AMEXAN Clinical CPU — shared runtime types
// =============================================================================
// Canonical contracts shared by every Clinical CPU engine and by the clinical UI.
//
// Architectural invariants:
//   1. The CPU owns clinical interpretation; the UI renders projections.
//   2. Knowledge/rules are data-driven and are not hard-coded into UI contracts.
//   3. Facts are append-oriented clinical observations.
//   4. Every derived object carries enough structure for explanation/provenance.
//   5. Optional clinical context is explicitly nullable rather than inferred.
//   6. Runtime types remain serializable across API/database boundaries.
// =============================================================================

// -----------------------------------------------------------------------------
// Primitive / shared types
// -----------------------------------------------------------------------------

export type FactKind =
  | 'text'
  | 'boolean'
  | 'numeric'
  | 'date'
  | 'datetime'
  | 'coded';

export type QuestionResponseType =
  | 'single_choice'
  | 'multi_choice'
  | 'boolean'
  | 'numeric'
  | 'measurement'
  | 'text'
  | 'long_text'
  | 'date'
  | 'datetime'
  | 'duration'
  | 'coded'
  | 'range';

export type QuestionRequirementLevel =
  | 'mandatory'
  | 'conditionally_required'
  | 'recommended'
  | 'optional';

export type QuestionDisposition =
  | 'skipped'
  | 'not_applicable'
  | 'deferred';

export type WorkspaceSectionState =
  | 'hidden'
  | 'locked'
  | 'available'
  | 'active'
  | 'attention'
  | 'complete';

export type ClinicalEventType =
  | 'ENCOUNTER_CREATED'
  | 'ENCOUNTER_UPDATED'
  | 'ENCOUNTER_DISPOSITIONED'
  | 'SYMPTOM_PRESENTED'
  | 'CHIEF_COMPLAINTS_SAVED'
  | 'QUESTION_ANSWERED'
  | 'QUESTION_DISPOSITIONED'
  | 'QUESTION_SKIPPED'
  | 'FACT_CAPTURED'
  | 'EXAM_FINDING_CAPTURED'
  | 'LAB_RESULT_RECEIVED'
  | 'IMAGING_RESULT_RECEIVED'
  | 'MEDICATION_STARTED'
  | 'VITAL_CHANGED'
  | 'CLINICIAN_DECISION'
  | 'DOCUMENTATION_ACTION';

export type KnowledgeGateVerdict = 'VALID' | 'BLOCKED' | 'UNGOVERNED';

// -----------------------------------------------------------------------------
// Facts
// -----------------------------------------------------------------------------

/**
 * A single captured value belonging to a canonical clinical fact.
 *
 * `dataType` describes which value field is authoritative.
 * Only the matching value property should normally be populated.
 */
export interface FactValue {
  dataType: FactKind;

  text?: string | null;
  numeric?: number | null;
  boolean?: boolean | null;

  /**
   * ISO-8601 date/date-time representation for date/datetime facts.
   */
  date?: string | null;
  datetime?: string | null;

  /**
   * Canonical code for coded facts.
   */
  code?: string | null;

  /**
   * UCUM/canonical unit code where applicable.
   */
  unitCode?: string | null;

  /**
   * Optional display value retained for rendering/audit.
   */
  display?: string | null;
}

/**
 * Canonical patient fact.
 *
 * Facts are observations, not diagnoses. Engines derive clinical meaning from
 * them rather than mutating the facts themselves.
 */
export interface Fact {
  id: string;
  patientId: string;
  encounterId: string | null;
  factCode: string;
  statusCode: string;
  recordedAt: string;
  sourceType: string | null;
  values: FactValue[];
}

// -----------------------------------------------------------------------------
// Question contracts
// -----------------------------------------------------------------------------

export interface AnswerOptionView {
  answerCode: string;
  label: string;
  description?: string | null;
}

export interface QuestionValidation {
  min?: number | null;
  max?: number | null;
  step?: number | null;
  pattern?: string | null;
}

export interface QuestionReason {
  code?: string | null;
  text: string;

  phenotypeCodes?: string[];
  mechanismCodes?: string[];
  conditionCodes?: string[];
  protocolCodes?: string[];

  priorityBasis?: string | null;
}

/**
 * A question selected by the CPU for the clinician.
 *
 * The UI must render this contract rather than independently constructing
 * clinical questions or deciding which question should be asked next.
 */
export interface NextQuestion {
  questionCode: string;

  /**
   * Human-readable wording supplied by the CPU.
   */
  text: string;

  responseType: QuestionResponseType;
  requirementLevel: QuestionRequirementLevel;

  /**
   * CPU-calculated priority.
   * Higher number = higher priority.
   */
  priority: number;

  /**
   * Human-readable explanation of why this question is currently relevant.
   */
  reason: string;

  /**
   * Structured reasoning metadata when available.
   */
  reasoning?: QuestionReason | null;

  /**
   * Canonical fact produced when this question is answered.
   */
  factCode: string | null;

  unitCode: string | null;

  options: AnswerOptionView[];

  placeholder?: string | null;

  validation?: QuestionValidation | null;

  allowUnknown: boolean;
  allowNotApplicable: boolean;
  allowDefer: boolean;

  defaultValue?: string | null;

  /**
   * Knowledge provenance.
   */
  source?: {
    knowledgeCode: string;
    version: string;
  } | null;
}

// -----------------------------------------------------------------------------
// Events
// -----------------------------------------------------------------------------

/**
 * Every clinically meaningful runtime change enters the CPU as an event.
 *
 * The event payload is intentionally open-ended because event-specific schemas
 * belong to the corresponding event handlers/knowledge layer.
 */
export interface ClinicalEvent {
  type: ClinicalEventType;
  payload: Record<string, unknown>;
}

export interface ProcessRequest {
  patientId: string;
  encounterId?: string;
  event: ClinicalEvent;
  clinicianId?: string;
}

// -----------------------------------------------------------------------------
// Patient clinical state
// -----------------------------------------------------------------------------

/**
 * Canonical "what do we currently know about this patient?" state.
 *
 * This is reconstructed from persisted facts/context. It is not the permanent
 * source of truth; facts remain the underlying clinical record.
 */
export interface PatientClinicalState {
  patientId: string;
  encounterId: string | null;

  ageYears: number | null;

  /**
   * Exact age representations.
   *
   * The universal shell derives the canonical age band from the most precise
   * available age representation rather than approximating from ageYears.
   */
  ageDays?: number | null;
  ageMonths?: number | null;

  /**
   * Canonical age-band code:
   * NEONATE | INFANT | CHILD | ADOLESCENT | ADULT
   */
  ageBand?: string | null;

  sex: string | null;

  /**
   * Pregnancy is explicit.
   *
   * It must never be inferred from sex alone.
   */
  pregnant?: boolean | null;

  /**
   * Gestational age in completed weeks when pregnancy is established.
   */
  gestationalAgeWeeks?: number | null;

  /**
   * Encounter/service context.
   */
  departmentCode?: string | null;
  encounterTypeCode?: string | null;

  /**
   * Body-system domains activated by the presenting problem.
   */
  activeDomains?: string[];

  /**
   * Governance jurisdiction resolved for this patient/encounter.
   */
  jurisdictionCode?: string | null;

  /**
   * Canonical symptom codes currently active in the encounter.
   */
  activeSymptoms: string[];

  /**
   * All currently relevant facts.
   */
  facts: Fact[];

  /**
   * Canonical question codes already answered/dispositioned.
   */
  answeredQuestions: string[];
}

// -----------------------------------------------------------------------------
// Phenotype / mechanism / differential reasoning
// -----------------------------------------------------------------------------

export interface PhenotypeScore {
  phenotypeCode: string;
  name: string;
  score: number;
  maxScore: number;
  compatibility: number;
}

export interface MechanismScore {
  mechanismCode: string;
  name: string;
  support: number;
  viaFeatures: number;
  viaPhenotypes: {
    phenotypeCode: string;
    weight: number;
  }[];
}

export interface EvidenceLine {
  factCode: string;
  expectation: string;
  found: string | null;
  weight: number;
  polarity: 'positive' | 'negative';
  support: 'support' | 'against';
}

export interface DifferentialCandidate {
  conditionCode: string;
  name: string;
  compatibility: number;

  viaPhenotypes: {
    phenotypeCode: string;
    weight: number;
  }[];

  evidence: EvidenceLine[];
}

// -----------------------------------------------------------------------------
// Examination
// -----------------------------------------------------------------------------

export interface ExaminationFindingOptionView {
  answerCode: string;
  label: string;
  interpretationCode: string | null;
  valueText: string | null;
}

export interface ExaminationFindingView {
  findingCode: string;
  name: string;
  factDefinitionCode: string | null;
  findingType: string;
  unit: string | null;
  options: ExaminationFindingOptionView[];
  normalRangeCode: string | null;
  isMandatory: boolean;
  priority: number;
}

export interface ExaminationModuleView {
  moduleCode: string;
  name: string;
  findings: ExaminationFindingView[];
}

// -----------------------------------------------------------------------------
// Investigations
// -----------------------------------------------------------------------------

export interface InvestigationRecommendation {
  investigationCode: string;
  name: string;
  type: string;
  weight: number;
  rationale: string | null;
  source: 'condition' | 'mechanism' | 'protocol';
}

// -----------------------------------------------------------------------------
// Protocols
// -----------------------------------------------------------------------------

export interface ProtocolActionView {
  actionType: string;
  actionCode: string;
  actionName: string;
  detail: string | null;
  urgency: string;
}

export interface ProtocolStepView {
  stepCode: string;
  label: string;
  stepType: string;
  sequenceNo: number;
  instruction: string;
  rationale: string | null;
  required: boolean;
  actions: ProtocolActionView[];
}

export interface ProtocolView {
  protocolCode: string;
  name: string;
  purpose: string | null;
  status: string;
  steps: ProtocolStepView[];
}

// -----------------------------------------------------------------------------
// Monitoring
// -----------------------------------------------------------------------------

export interface MonitoringTarget {
  monitoringCode: string;
  name: string;
  targetType: string;
  unit: string | null;
  frequency: string | null;
  deteriorationRule: string | null;
  escalationInstruction: string | null;
  currentValue: string | null;
  alert: string | null;
}

// -----------------------------------------------------------------------------
// Severity scoring
// -----------------------------------------------------------------------------

/**
 * A structured scoring instrument evaluated against captured patient facts.
 *
 * Examples include CURB-65 and other database-defined instruments.
 *
 * The component list makes the calculation transparent and auditable.
 */
export interface SeverityScore {
  scoreCode: string;
  name: string;
  description: string | null;
  population: string;
  maxScore: number;

  score: number;

  severityLabel: string | null;
  disposition: string | null;
  recommendation: string | null;

  components: {
    componentCode: string;
    name: string;
    points: number;
    matched: boolean;
    rationale: string | null;
  }[];
}

// -----------------------------------------------------------------------------
// Treatment
// -----------------------------------------------------------------------------

/**
 * Treatment candidate produced by the TreatmentEngine.
 *
 * This represents an eligible clinical action candidate, not an automatic
 * prescription. SafetyEngine may subsequently mark it contraindicated.
 */
export interface TreatmentRecommendation {
  medicationCode: string;
  genericName: string;
  role: string;

  route: string | null;

  /**
   * Database-defined dose expression.
   */
  doseExpression: string;

  /**
   * Optional computed weight-based quantity.
   */
  computedDose: string | null;

  frequency: string | null;
  duration: string | null;

  /**
   * Whether the selected dose reference has passed knowledge verification.
   */
  verified: boolean;

  /**
   * Hard safety conflict identified by SafetyEngine.
   */
  contraindicated: boolean;

  /**
   * Human-readable safety/provenance notes.
   */
  safetyNotes: string[];
}

// -----------------------------------------------------------------------------
// Contradiction / anchoring prevention
// -----------------------------------------------------------------------------

/**
 * A finding the current leading differential would normally expect but which
 * has not yet been documented.
 *
 * The contradiction engine uses this to actively search for evidence against
 * the working hypothesis.
 */
export interface ContradictionProbe {
  factCode: string;
  expectation: string;
  weight: number;
  reason: string;
}

// -----------------------------------------------------------------------------
// Recommendations / alerts / documentation
// -----------------------------------------------------------------------------

export interface Recommendation {
  type: string;
  code: string;
  text: string;
  reason: string;
  urgency: string;
}

export type AlertLevel =
  | 'emergency'
  | 'urgent'
  | 'warning'
  | 'info';

export interface Alert {
  level: AlertLevel;
  code: string;
  message: string;
}

export interface DocumentationSection {
  section: string;
  sentences: {
    text: string;
    factCode: string | null;
  }[];
}

export interface EducationItem {
  educationCode: string;
  title: string;
  audience: string;
  contentType: string;
  body: string;
}

export interface Explanation {
  label: string;
  body: string;
}

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------

/**
 * A resolved configuration override.
 *
 * Represents baseline + applicable override + version + explanation.
 */
export interface ConfigurationOverride {
  overrideCode: string;
  targetType: string;
  targetCode: string;
  scopeCode: string;
  config: Record<string, unknown>;
  reason: string | null;
  version: number;
}

// -----------------------------------------------------------------------------
// H10 governance — knowledge gate / replay
// -----------------------------------------------------------------------------

/**
 * One governed knowledge entity the CPU is about to use.
 *
 * Examples:
 *   phenotype
 *   condition
 *   protocol
 *   question
 *   guideline
 */
export interface KnowledgeGateTarget {
  kind: string;
  code: string;
}

/**
 * Result for one knowledge object inspected by the runtime gate.
 */
export interface KnowledgeGateEntry {
  kind: string;
  code: string;

  governed: boolean;

  /**
   * Actual governed knowledge-object identifier where available.
   */
  objectCode: string | null;

  /**
   * Lifecycle state of the governed object.
   */
  lifecycleStatus: string | null;

  verdict: KnowledgeGateVerdict;

  reason: string;
}

/**
 * Aggregate knowledge gate result for a CPU pass.
 */
export interface KnowledgeGateResult {
  /**
   * True iff no knowledge object is BLOCKED.
   */
  passes: boolean;

  checked: number;

  valid: KnowledgeGateEntry[];
  blocked: KnowledgeGateEntry[];
  ungoverned: KnowledgeGateEntry[];
}

// -----------------------------------------------------------------------------
// Universal format plan — U2
// -----------------------------------------------------------------------------

/**
 * Clinical structure derived for this specific encounter.
 *
 * The plan is resolved from database-backed format/context rules. The UI does
 * not decide which clinical sections apply.
 */
export interface ClinicalFormatPlan {
  baseFormat: string;

  ageBand?: string | null;
  sex?: string | null;
  pregnant?: boolean | null;
  gestationalAge?: string | null;

  department?: string | null;
  encounterType?: string | null;

  /**
   * Active body-system domains.
   */
  activeDomains: string[];

  /**
   * Contextually excluded sections.
   */
  excludedSections: string[];

  /**
   * Contextually added sections.
   */
  additionalSections: string[];

  /**
   * Sections elevated to required status by context rules.
   */
  requiredSections: string[];
}

// -----------------------------------------------------------------------------
// Workspace navigation — U3/U4
// -----------------------------------------------------------------------------

export interface WorkspaceSubsectionProjection {
  subsectionCode: string;
  label: string;
  state: WorkspaceSectionState;

  requiredRemaining: number;
  requiredTotal: number;

  badge?: number | null;
}

export interface WorkspaceSectionProjection {
  sectionCode: string;
  label: string;
  state: WorkspaceSectionState;

  priority: number;

  badge?: number | null;
  reason?: string | null;

  requiredRemaining: number;
  requiredTotal: number;

  children?: WorkspaceSubsectionProjection[];
}

export type WorkspaceWorkflowPhase =
  | 'history'
  | 'examination'
  | 'reasoning'
  | 'investigation'
  | 'management'
  | 'monitoring'
  | 'documentation'
  | 'complete';

export interface WorkspaceNavigationProjection {
  /**
   * Flat workspace entries with nested history/examination children where
   * applicable.
   */
  sections: WorkspaceSectionProjection[];

  /**
   * Section currently selected/recommended by the CPU.
   */
  activeSection: string;

  /**
   * Current clinical workflow phase.
   */
  workflowPhase: WorkspaceWorkflowPhase;

  /**
   * Context used to derive this navigation projection.
   */
  currentContext: {
    ageBand?: string | null;
    sex?: string | null;
    pregnant?: boolean | null;
    gestationalAge?: string | null;
    department?: string | null;
    encounterType?: string | null;
  };
}

// -----------------------------------------------------------------------------
// Clinical runtime projection
// -----------------------------------------------------------------------------

/**
 * The canonical projection consumed by the clinical UI.
 *
 * IMPORTANT:
 * The UI renders this object. It does not independently perform clinical
 * reasoning, choose questions, determine differential diagnoses, select
 * protocols, decide applicable sections, or reinterpret safety decisions.
 */
export interface ClinicalRuntimeProjection {
  /**
   * High-level CPU phase.
   */
  currentPhase: string;

  patientId: string;
  encounterId: string | null;

  /**
   * Persisted CPU event identifier.
   */
  eventId: number | null;

  alerts: Alert[];

  /**
   * Currently active symptom codes.
   */
  activeSymptoms: string[];

  /**
   * Current clinical facts available to the runtime pass.
   */
  capturedFacts: Fact[];

  /**
   * Questions currently selected by the QuestionSelector.
   */
  nextQuestions: NextQuestion[];

  /**
   * Phenotypic reasoning.
   */
  phenotypes: PhenotypeScore[];

  /**
   * Mechanistic reasoning.
   */
  mechanisms: MechanismScore[];

  /**
   * Differential diagnosis.
   */
  differentials: DifferentialCandidate[];

  /**
   * Structured physical examination workspace.
   */
  examination: ExaminationModuleView[];

  /**
   * Investigation candidates.
   */
  investigations: InvestigationRecommendation[];

  /**
   * Treatment candidates after treatment resolution and safety evaluation.
   */
  treatment: TreatmentRecommendation[];

  /**
   * Applicable protocol, if one has been resolved.
   */
  protocol: ProtocolView | null;

  /**
   * Monitoring plan.
   */
  monitoring: MonitoringTarget[];

  /**
   * Structured severity scores.
   */
  severityScores: SeverityScore[];

  /**
   * Patient/clinician education.
   */
  education: EducationItem[];

  /**
   * Structured documentation projection.
   */
  documentation: DocumentationSection[];

  /**
   * General CPU recommendations.
   */
  recommendations: Recommendation[];

  /**
   * Human-readable reasoning explanations.
   */
  explanations: Explanation[];

  /**
   * Contradiction probes generated for anchoring prevention.
   */
  contradictions: ContradictionProbe[];

  /**
   * Active configuration overrides used by this pass.
   */
  configuration: {
    overrides: ConfigurationOverride[];
  };

  /**
   * High-level confidence projection.
   */
  confidence: {
    workingDiagnosis: string | null;
    leadingPhenotypeScore: number;
  };

  /**
   * H10 runtime governance.
   *
   * The UI may render this for transparency/audit. BLOCKED knowledge must not
   * be represented as active clinical intelligence.
   */
  governance?: {
    gate: KnowledgeGateResult;

    /**
     * Forward trace: rendered projection -> reasoning run.
     */
    runId?: string;

    /**
     * Forward/backward trace: rendered projection -> clinical snapshot.
     */
    clinicalSnapshotId?: string;
  };

  /**
   * Universal clinical format derived for this encounter.
   */
  formatPlan?: ClinicalFormatPlan;

  /**
   * Workspace navigation derived by SectionEngine.
   */
  navigation?: WorkspaceNavigationProjection;

  /**
   * Runtime metadata for the observability layer: when the pass was generated,
   * which CPU cycle, and per-stage engine timings. Rendered for the AMEXAN
   * System Observatory and encounter journey views.
   */
  runtime?: {
    generatedAt: string;
    cycle: number;
    timings: { stage: string; milliseconds: number }[];
  };
}