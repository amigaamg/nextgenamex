// =============================================================================
// AMEXAN Clinical Runtime UI — types
// This mirrors the CPU's `ClinicalRuntimeProjection` (clinical-cpu/src/types.ts).
// The UI is a projection of CPU state: it never reasons; it renders.
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

export interface ContradictionProbe {
  factCode: string;
  expectation: string;
  weight: number;
  reason: string;
}

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

export interface Explanation {
  label: string;
  body: string;
}

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
}

export interface TimelineEvent {
  eventId: number;
  eventType: string;
  payload: Record<string, unknown>;
  occurredAt: string;
}

// ---------------------------------------------------------------------------
// UI-level types (rendering concerns ONLY)
// ---------------------------------------------------------------------------

export type TabId =
  | 'history'
  | 'reasoning'
  | 'exam'
  | 'investigations'
  | 'management'
  | 'monitoring'
  | 'docs'
  | 'education'
  | 'timeline'
  | 'configuration';

export interface PhaseStep {
  id: string;
  label: string;
}

export type ConnectionState = 'offline' | 'syncing' | 'online';

export function factDisplayValue(fact: Fact): string {
  const v = fact.values[0];
  if (!v) return '—';
  if (v.boolean != null) return v.boolean ? 'Yes' : 'No';
  if (v.numeric != null) return `${v.numeric}${v.unitCode ? ` ${v.unitCode}` : ''}`;
  if (v.text != null) return nicer(v.text);
  return '—';
}

export function nicer(code: string): string {
  if (code === 'PRODUCTIVE' || code === 'NON_PRODUCTIVE') {
    return code === 'PRODUCTIVE' ? 'Productive' : 'Dry';
  }
  return code
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export function sourceNice(source: string | null): string {
  switch (source) {
    case 'patient_history':
      return 'Patient history';
    case 'examination':
      return 'Examination';
    case 'lab':
      return 'Lab';
    case 'imaging':
      return 'Imaging';
    case 'device':
      return 'Device';
    default:
      return source ? nicer(source) : 'Unknown';
  }
}