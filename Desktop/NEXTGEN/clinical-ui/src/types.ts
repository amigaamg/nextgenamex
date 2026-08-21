// =============================================================================
// AMEXAN Clinical Runtime UI — types
// Core type definitions for the Clinical UI.
// The UI renders CPU projections and emits typed clinical events.
// Rules/knowledge/reasoning remain authoritative in the clinical CPU.
// =============================================================================

export type FactKind =
  | 'text'
  | 'boolean'
  | 'numeric'
  | 'date'
  | 'datetime'
  | 'coded';

export interface FactValue {
  dataType: FactKind;
  text?: string | null;
  numeric?: number | null;
  boolean?: boolean | null;
  unitCode?: string | null;
  code?: string | null;
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
  section?: string | null;
}

// =============================================================================
// CLINICAL EVENTS
// =============================================================================

export type ClinicalEventType =
  | 'ENCOUNTER_STARTED'
  | 'SYMPTOM_PRESENTED'
  | 'QUESTION_ANSWERED'
  | 'QUESTION_DISPOSITIONED'
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
  timestamp: string;
}

// =============================================================================
// QUESTION SYSTEM
// =============================================================================

export type QuestionResponseType =
  | 'single_choice'
  | 'coded'
  | 'boolean'
  | 'multi_choice'
  | 'numeric'
  | 'measurement'
  | 'range'
  | 'date'
  | 'datetime'
  | 'duration'
  | 'text'
  | 'long_text';

export type QuestionRequirementLevel =
  | 'mandatory'
  | 'conditionally_required'
  | 'recommended'
  | 'optional';

export type QuestionDisposition =
  | 'skipped'
  | 'not_applicable'
  | 'deferred';

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

export interface QuestionSource {
  knowledgeCode: string;
  version: string;
  sectionCode?: string | null;
}

export interface NextQuestion {
  questionCode: string;
  text: string;

  responseType: QuestionResponseType;
  requirementLevel: QuestionRequirementLevel;

  priority: number;

  reason: string;
  reasoning?: QuestionReason | null;

  factCode: string | null;
  unitCode: string | null;

  options: AnswerOptionView[];

  placeholder?: string | null;
  validation?: QuestionValidation | null;

  allowUnknown: boolean;
  allowNotApplicable: boolean;
  allowDefer: boolean;

  defaultValue?: string | null;

  source?: QuestionSource | null;

  sectionCode?: string | null;
  subsectionCode?: string | null;

  section?: string | null;
  visible?: boolean;
  enabled?: boolean;
}

// =============================================================================
// CLINICAL REASONING
// =============================================================================

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
  rank?: number;
  confidence?: number;
  viaPhenotypes: {
    phenotypeCode: string;
    weight: number;
  }[];
  evidence: EvidenceLine[];
  supportingFactCodes?: string[];
  opposingFactCodes?: string[];
  reasoning?: string | null;
}

export interface ContradictionProbe {
  factCode: string;
  expectation: string;
  weight: number;
  reason: string;
}

export interface Explanation {
  label: string;
  body: string;
}

// =============================================================================
// EXAMINATION
// =============================================================================

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

// =============================================================================
// INVESTIGATIONS
// =============================================================================

export interface InvestigationRecommendation {
  investigationCode: string;
  name: string;
  type: string;
  weight: number;
  rationale: string | null;
  source: 'condition' | 'mechanism' | 'protocol';
}

// =============================================================================
// MANAGEMENT / PROTOCOL
// =============================================================================

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

export interface TreatmentRecommendation {
  medicationCode: string;
  genericName: string;
  role: string;
  route: string | null;
  doseExpression: string;
  computedDose: string | null;
  frequency: string | null;
  duration: string | null;
  verified: boolean;
  contraindicated: boolean;
  safetyNotes: string[];
}

// =============================================================================
// MONITORING
// =============================================================================

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

// =============================================================================
// EDUCATION
// =============================================================================

export interface EducationItem {
  educationCode: string;
  title: string;
  audience: string;
  contentType: string;
  body: string;
}

// =============================================================================
// SEVERITY
// =============================================================================

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

// =============================================================================
// RECOMMENDATIONS / ALERTS
// =============================================================================

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

export interface ClinicalAlert {
  level: AlertLevel;
  code?: string;
  message?: string;
}

// =============================================================================
// DOCUMENTATION
// =============================================================================

export interface DocumentationSentence {
  text: string;
  factCode: string | null;
}

export interface DocumentationSection {
  section: string;
  sentences: DocumentationSentence[];
}

// =============================================================================
// CONFIGURATION
// =============================================================================

export interface ConfigurationOverride {
  overrideCode: string;
  targetType: string;
  targetCode: string;
  scopeCode: string;
  config: Record<string, unknown>;
  reason: string | null;
  version: number;
}

// =============================================================================
// UNIVERSAL CLINICAL FORMAT
// =============================================================================

export type ClinicalDepartment =
  | 'medical'
  | 'surgical'
  | 'obgyn'
  | 'paediatrics'
  | 'neonatology'
  | 'psychiatry'
  | 'emergency'
  | 'other';

export type ClinicalSex =
  | 'male'
  | 'female'
  | 'intersex'
  | 'unknown';

export type LifeStage =
  | 'neonate'
  | 'infant'
  | 'young_child'
  | 'older_child'
  | 'adolescent'
  | 'adult'
  | 'older_adult'
  | 'unknown';

export type PregnancyState =
  | 'not_applicable'
  | 'not_pregnant'
  | 'pregnant'
  | 'postpartum'
  | 'unknown';

export type EncounterType =
  | 'opd'
  | 'emergency'
  | 'inpatient'
  | 'antenatal'
  | 'postnatal'
  | 'neonatal'
  | 'follow_up'
  | 'procedure'
  | 'other';

export type ClinicalFormatCode =
  | 'ADULT_MEDICAL'
  | 'ADULT_SURGICAL'
  | 'ADULT_FEMALE_MEDICAL'
  | 'ADULT_FEMALE_SURGICAL'
  | 'OBGYN'
  | 'PAEDIATRIC'
  | 'NEONATAL'
  | 'PSYCHIATRY'
  | 'EMERGENCY'
  | 'OTHER';

export interface ClinicalFormatPlan {
  baseFormat: ClinicalFormatCode;

  ageBand: LifeStage;
  sex: ClinicalSex;

  pregnant: boolean;
  pregnancyState: PregnancyState;
  gestationalAge?: string | null;

  department: ClinicalDepartment;
  encounterType?: EncounterType | null;

  activeDomains: string[];

  excludedSections: string[];
  additionalSections: string[];
  requiredSections: string[];

  formatVersion?: string | null;
}

// =============================================================================
// UNIVERSAL HISTORY SECTION CODES
// =============================================================================

export type HistorySectionCode =
  | 'BIODATA'
  | 'CHIEF_COMPLAINT'
  | 'HISTORY_OF_PRESENT_ILLNESS'
  | 'PAST_MEDICAL_HISTORY'
  | 'PAST_SURGICAL_HISTORY'
  | 'FAMILY_HISTORY'
  | 'SOCIAL_HISTORY'
  | 'REVIEW_OF_SYSTEMS'
  | 'SUMMARY'

  // Adult female reproductive history
  | 'OBSTETRIC_HISTORY'
  | 'GYNAECOLOGICAL_HISTORY'

  // Paediatrics
  | 'BIRTH_HISTORY'
  | 'GROWTH_HISTORY'
  | 'DEVELOPMENTAL_HISTORY'
  | 'IMMUNIZATION_HISTORY'
  | 'NUTRITIONAL_HISTORY'

  // Neonatal
  | 'MATERNAL_HISTORY'
  | 'ANTENATAL_HISTORY'
  | 'INTRAPARTUM_HISTORY'
  | 'NEONATAL_HISTORY'
  | 'FEEDING_HISTORY'
  | 'NEWBORN_SCREENING'

  // OBGYN
  | 'ANC_PROFILE'
  | 'OBSTETRIC_HISTORY_CURRENT'
  | 'GYNAECOLOGICAL_HISTORY_CURRENT'
  | 'PREGNANCY_HISTORY'
  | 'DELIVERY_HISTORY'
  | 'POSTNATAL_HISTORY'

  // Psychiatry
  | 'PSYCHIATRIC_CHIEF_COMPLAINT'
  | 'PSYCHIATRIC_HISTORY_PRESENT_ILLNESS'
  | 'PAST_PSYCHIATRIC_HISTORY'
  | 'SUBSTANCE_USE_HISTORY'
  | 'FORENSIC_HISTORY'
  | 'PERSONAL_HISTORY'
  | 'PREMORBID_PERSONALITY'
  | 'MENTAL_STATE_EXAMINATION'
  | 'RISK_ASSESSMENT'
  | 'PSYCHIATRIC_FORMULATION';

export interface ClinicalHistorySection {
  sectionCode: HistorySectionCode | string;
  label: string;
  sequence: number;

  visible: boolean;
  enabled: boolean;

  required: boolean;
  state: WorkspaceSectionState;

  requiredRemaining: number;
  requiredTotal: number;

  badge?: number | null;
  reason?: string | null;

  children?: WorkspaceSubsectionProjection[];
}

// =============================================================================
// WORKSPACE NAVIGATION
// =============================================================================

export type WorkspaceSectionState =
  | 'hidden'
  | 'locked'
  | 'available'
  | 'active'
  | 'attention'
  | 'complete';

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

  completion?: {
    percentage: number;
    mandatoryRemaining: number;
    requiredSectionsRemaining?: number;
  };

  urgency?: 'routine' | 'important' | 'urgent' | 'emergency';

  sequenceNo?: number;
}

export interface WorkspaceNavigationProjection {
  sections: WorkspaceSectionProjection[];

  activeSection: string;

  workflowPhase:
    | 'history'
    | 'examination'
    | 'reasoning'
    | 'investigation'
    | 'management'
    | 'monitoring'
    | 'documentation'
    | 'complete';

  currentContext: {
    ageBand?: LifeStage;
    sex?: ClinicalSex;
    pregnant?: boolean;
    pregnancyState?: PregnancyState;
    gestationalAge?: string | null;
    department?: ClinicalDepartment;
    encounterType?: EncounterType;
  };

  completionPercentage?: number;
}

// =============================================================================
// CLINICAL RUNTIME PROJECTION
// =============================================================================

export interface ClinicalRuntimeProjection {
  patientId: string;
  encounterId: string | null;

  currentPhase: string;
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

  severityScores: SeverityScore[];

  education: EducationItem[];

  documentation: DocumentationSection[];

  recommendations: Recommendation[];

  explanations: Explanation[];

  contradictions: ContradictionProbe[];

  configuration: {
    overrides: ConfigurationOverride[];
  };

  confidence: {
    workingDiagnosis: string | null;
    leadingPhenotypeScore: number;
  };

  formatPlan?: ClinicalFormatPlan;
  navigation?: WorkspaceNavigationProjection;

  context?: ClinicalContext;
}

export interface EnhancedClinicalRuntimeProjection
  extends ClinicalRuntimeProjection {
  formatPlan?: ClinicalFormatPlan;
  navigation?: WorkspaceNavigationProjection;
}

// =============================================================================
// UI STATE
// =============================================================================

export type ConnectionState =
  | 'online'
  | 'offline'
  | 'syncing';

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

export interface ClinicalUIState {
  activeWorkspace: TabId;

  task: {
    type:
      | 'history'
      | 'examination'
      | 'reasoning'
      | 'investigation'
      | 'management'
      | 'monitoring'
      | 'documentation';

    code: string;

    priority:
      | 'routine'
      | 'important'
      | 'urgent'
      | 'emergency';
  };

  nextAction: {
    type: string;
    code: string;
    label: string;
    rationale: string;
  };

  blockingIssues: string[];

  alerts: Alert[];

  confidence?: number;
}

// =============================================================================
// TIMELINE
// =============================================================================

export interface TimelineEvent {
  eventId: number;
  eventType: string;
  payload: Record<string, unknown>;
  occurredAt: string;
}

// =============================================================================
// UNIVERSAL CLINICAL CONTEXT
// =============================================================================

export interface ClinicalContext {
  patientId: string;
  encounterId: string | null;

  ageYears: number | null;
  ageMonths: number | null;
  ageDays: number | null;

  sex: ClinicalSex;
  lifeStage: LifeStage;

  pregnancyState: PregnancyState;
  gestationalAge: string | null;

  department: ClinicalDepartment;
  encounterType: EncounterType | null;

  presentingComplaintCodes: string[];
  activeSymptomCodes: string[];

  firstVisit: boolean;
  emergency: boolean;
}

// =============================================================================
// UNIVERSAL SECTION PROJECTION
// =============================================================================

export interface ClinicalSectionProjection {
  code: string;
  label: string;

  sequence: number;

  visible: boolean;
  enabled: boolean;

  required: boolean;

  state: WorkspaceSectionState;

  requiredRemaining: number;
  requiredTotal: number;

  badge?: number | null;

  reason?: string | null;

  children?: WorkspaceSubsectionProjection[];
}

// =============================================================================
// UNIVERSAL QUESTION PROJECTION
// =============================================================================

export interface UniversalQuestionProjection extends NextQuestion {
  sectionCode: string;
  subsectionCode?: string | null;

  visible: boolean;
  enabled: boolean;
}

// =============================================================================
// UNIVERSAL CAPTURED FACT
// =============================================================================

export interface UniversalCapturedFact {
  id: string;

  patientId: string;
  encounterId: string | null;

  factCode: string;

  sectionCode: string;
  subsectionCode?: string | null;

  value: {
    text?: string | null;
    code?: string | null;
    numeric?: number | null;
    boolean?: boolean | null;
    unitCode?: string | null;
  };

  sourceType: string;

  recordedAt: string;
}

// =============================================================================
// UNIVERSAL CLINICAL PROJECTION
// =============================================================================

export interface UniversalClinicalProjection {
  context: ClinicalContext;

  formatPlan?: ClinicalFormatPlan;

  sections: ClinicalSectionProjection[];

  navigation: WorkspaceSectionProjection[];

  activeSection: string;

  completion: {
    percentage: number;
    mandatoryRemaining: number;
  };

  capturedFacts: UniversalCapturedFact[];

  questions: UniversalQuestionProjection[];

  alerts: Alert[];

  phenotypes: PhenotypeScore[];
  mechanisms: MechanismScore[];
  differentials: DifferentialCandidate[];

  examination: ExaminationModuleView[];

  investigations: InvestigationRecommendation[];

  treatment: TreatmentRecommendation[];

  protocol: ProtocolView | null;

  monitoring: MonitoringTarget[];

  documentation: DocumentationSection[];

  eventId: number | null;
}

// =============================================================================
// HELPERS
// =============================================================================

export function factDisplayValue(f: Fact): string {
  const v = f.values[0];

  if (!v) return '—';

  if (v.text != null) {
    return v.text;
  }

  if (v.numeric != null) {
    return v.unitCode
      ? `${v.numeric} ${v.unitCode}`
      : String(v.numeric);
  }

  if (v.boolean != null) {
    return v.boolean ? 'Yes' : 'No';
  }

  return '—';
}

export function sourceNice(
  sourceType: string | null | undefined,
): string {
  return (sourceType ?? 'unknown')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export function nicer(code: string): string {
  return code
    .replace(/_/g, ' ')
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}