// =============================================================================
// AMEXAN Clinical CPU — shared runtime types
// =============================================================================

export type FactKind = 'text' | 'boolean' | 'numeric' | 'date' | 'datetime' | 'coded';

export interface FactValue {
  dataType: FactKind;
  text?: string | null;
  numeric?: number | null;
  boolean?: boolean | null;
  unitCode?: string | null;
}

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

// ---------------------------------------------------------------------------
// Events — the CPU is event-driven. Every clinically meaningful change is an
// event; the CPU re-runs the nephron over the resulting patient state.
// ---------------------------------------------------------------------------

export type ClinicalEventType =
  | 'ENCOUNTER_STARTED'
  | 'SYMPTOM_PRESENTED'
  | 'QUESTION_ANSWERED'
  | 'QUESTION_SKIPPED'
  | 'FACT_CAPTURED'
  | 'EXAM_FINDING_CAPTURED'
  | 'LAB_RESULT_RECEIVED'
  | 'IMAGING_RESULT_RECEIVED'
  | 'MEDICATION_STARTED'
  | 'VITAL_CHANGED'
  | 'CLINICIAN_DECISION'
  | 'DOCUMENTATION_ACTION';

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

// ---------------------------------------------------------------------------
// Patient state — the canonical "what do we currently know about this patient"
// ---------------------------------------------------------------------------

export interface PatientClinicalState {
  patientId: string;
  encounterId: string | null;
  ageYears: number | null;
  sex: string | null;
  activeSymptoms: string[];
  facts: Fact[];
  answeredQuestions: string[];
}

// ---------------------------------------------------------------------------
// Reasoning results
// ---------------------------------------------------------------------------

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
  viaPhenotypes: { phenotypeCode: string; weight: number }[];
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
  viaPhenotypes: { phenotypeCode: string; weight: number }[];
  evidence: EvidenceLine[];
}

export interface AnswerOptionView {
  answerCode: string;
  label: string;
}

export interface NextQuestion {
  questionCode: string;
  text: string;
  responseType: string;
  requirementLevel: string;
  priority: number;
  reason: string;
  options: AnswerOptionView[];
  factCode: string | null;
  unitCode: string | null;
}

export interface ExaminationFindingView {
  findingCode: string;
  name: string;
  factDefinitionCode: string | null;
  findingType: string;
}

export interface ExaminationModuleView {
  moduleCode: string;
  name: string;
  findings: ExaminationFindingView[];
}

export interface InvestigationRecommendation {
  investigationCode: string;
  name: string;
  type: string;
  weight: number;
  rationale: string | null;
  source: 'condition' | 'mechanism' | 'protocol';
}

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

export interface EducationItem {
  educationCode: string;
  title: string;
  audience: string;
  contentType: string;
  body: string;
}

export interface TreatmentRecommendation {
  medicationCode: string;
  genericName: string;
  role: string;
  route: string | null;
  doseExpression: string;
  frequency: string | null;
  duration: string | null;
  verified: boolean;
  contraindicated: boolean;
  safetyNotes: string[];
}

// A probe the Contradiction Engine raises for the leading differential: an
// expected finding that is not yet documented. The CPU actively looks for
// evidence AGAINST its current hypothesis (anchoring prevention, 3.9).
export interface ContradictionProbe {
  factCode: string;
  expectation: string;
  weight: number;
  reason: string;
}

// A resolved configuration override (baseline + override + version + reason,
// 3.19). Read from knowledge.active_override so the CPU can explain WHY the
// current rule applies.
export interface ConfigurationOverride {
  overrideCode: string;
  targetType: string;
  targetCode: string;
  scopeCode: string;
  config: Record<string, unknown>;
  reason: string | null;
  version: number;
}

export interface Recommendation {
  type: string;
  code: string;
  text: string;
  reason: string;
  urgency: string;
}

export interface Alert {
  level: 'emergency' | 'urgent' | 'warning' | 'info';
  code: string;
  message: string;
}

export interface DocumentationSection {
  section: string;
  sentences: { text: string; factCode: string | null }[];
}

// ---------------------------------------------------------------------------
// H10 governance — the runtime knowledge gate (§37) and replay verdict (§31)
// ---------------------------------------------------------------------------

export type KnowledgeGateVerdict = 'VALID' | 'BLOCKED' | 'UNGOVERNED';

// One knowledge entity the CPU is about to use: a phenotype, a differential
// condition, a protocol, a question, a guideline, …
export interface KnowledgeGateTarget {
  kind: string; // 'phenotype' | 'condition' | 'protocol' | 'question' | lower(governed knowledge_type) …
  code: string; // the runtime code, e.g. PHEN-HYPOXAEMIA / PNEUMONIA / PROT-CAP-ADULT
}

export interface KnowledgeGateEntry {
  kind: string;
  code: string;
  governed: boolean;
  objectCode: string | null;
  lifecycleStatus: string | null;
  verdict: KnowledgeGateVerdict;
  reason: string;
}

export interface KnowledgeGateResult {
  passes: boolean; // true iff nothing is BLOCKED
  checked: number;
  valid: KnowledgeGateEntry[];
  blocked: KnowledgeGateEntry[];
  ungoverned: KnowledgeGateEntry[];
}

export interface Explanation {
  label: string;
  body: string;
}

// ---------------------------------------------------------------------------
// The runtime projection — what the UI renders. The UI is not the intelligence.
// ---------------------------------------------------------------------------

export interface ClinicalRuntimeProjection {
  currentPhase: string;
  patientId: string;
  encounterId: string | null;
  eventId: number | null;
  alerts: Alert[];
  activeSymptoms: string[];
  capturedFacts: Fact[];
  nextQuestions: NextQuestion[];
  phenotypes: PhenotypeScore[];
  mechanisms: MechanismScore[];
  differentials: DifferentialCandidate[];
  examination: ExaminationModuleView[];
  investigations: InvestigationRecommendation[];
  treatment: TreatmentRecommendation[];
  protocol: ProtocolView | null;
  monitoring: MonitoringTarget[];
  education: EducationItem[];
  documentation: DocumentationSection[];
  recommendations: Recommendation[];
  explanations: Explanation[];
  contradictions: ContradictionProbe[];
  configuration: { overrides: ConfigurationOverride[] };
  confidence: { workingDiagnosis: string | null; leadingPhenotypeScore: number };
  // H10 §37: the runtime knowledge-gate verdict for everything this pass used.
  // The UI renders governed knowledge only — anything BLOCKED is excluded.
  // runId / clinicalSnapshotId make the forward+backward trace (§34-36) directly
  // reachable from the rendered projection.
  governance?: {
    gate: KnowledgeGateResult;
    runId?: string;
    clinicalSnapshotId?: string;
  };
}
