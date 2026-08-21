// =============================================================================
// AMEXAN CLINICAL UI
// src/clinical/types.ts
//
// UNIVERSAL CLINICAL CAPTURE CONTRACT
//
// Architecture:
//   Clinical UI  ->  API boundary  ->  Clinical CPU  ->  PostgreSQL
//                                            |
//                                            v
//                                      Clinical Projection
//                                            |
//                                            v
//                                        Clinical UI
//
// RULE:
//   UI captures and renders.
//   CPU owns clinical knowledge, rules, reasoning, sequencing and decisions.
//   PostgreSQL persists canonical clinical state.
// =============================================================================

// =============================================================================
// 1. PATIENT CONTEXT
// =============================================================================

export type Sex =
  | 'male'
  | 'female'
  | 'intersex'
  | 'unknown';

export type LifeStage =
  | 'neonate'
  | 'infant'
  | 'child'
  | 'adolescent'
  | 'adult'
  | 'older_adult';

export type EncounterDomain =
  | 'medical'
  | 'surgical'
  | 'obgyn'
  | 'paediatrics'
  | 'neonatology'
  | 'psychiatry'
  | 'emergency'
  | 'other';

export type EncounterType =
  | 'opd'
  | 'ipd'
  | 'emergency'
  | 'clinic'
  | 'theatre'
  | 'antenatal'
  | 'postnatal'
  | 'neonatal'
  | 'follow_up'
  | 'review'
  | 'telemedicine'
  | 'other';

export type PregnancyState =
  | 'not_applicable'
  | 'not_pregnant'
  | 'pregnant'
  | 'postpartum'
  | 'unknown';

export interface ClinicalContext {
  patientId: string;
  encounterId: string | null;

  ageYears: number | null;
  ageMonths: number | null;
  ageDays: number | null;

  dateOfBirth?: string | null;

  sex: Sex;
  lifeStage: LifeStage;

  pregnancyState: PregnancyState;
  gestationalAgeWeeks?: number | null;

  department: EncounterDomain;
  encounterType: EncounterType | string | null;

  presentingComplaintCodes: string[];
  activeSymptomCodes: string[];

  firstVisit: boolean;
  emergency: boolean;

  contextVersion?: string;
  determinedAt?: string;
}

// =============================================================================
// 2. UNIVERSAL HISTORY SECTIONS
// =============================================================================

export type HistorySection =
  | 'biodata'
  | 'chief_complaint'
  | 'hpi'
  | 'past_medical_history'
  | 'past_surgical_history'
  | 'drug_history'
  | 'allergy_history'
  | 'family_history'
  | 'social_history'
  | 'occupational_history'
  | 'sexual_history'
  | 'review_of_systems'
  | 'obstetric_history'
  | 'gynaecological_history'
  | 'anc_profile'
  | 'birth_history'
  | 'growth_development'
  | 'immunization'
  | 'nutrition'
  | 'psychiatric_history'
  | 'substance_history'
  | 'collateral_history'
  | 'maternal_history'
  | 'summary';

export type ClinicalWorkspaceSection =
  | HistorySection
  | 'examination'
  | 'clinical_reasoning'
  | 'investigations'
  | 'management'
  | 'monitoring'
  | 'documentation'
  | 'education'
  | 'timeline'
  | 'configuration';

export interface HistorySectionDefinition {
  code: HistorySection;

  label: string;

  sequence: number;

  required: boolean;
  visible: boolean;

  reason?: string | null;

  requiredRemaining?: number;
  requiredTotal?: number;

  subsections?: HistorySubsectionDefinition[];
}

export interface HistorySubsectionDefinition {
  code: string;
  label: string;

  sequence: number;

  required: boolean;
  visible: boolean;

  requiredRemaining?: number;
  requiredTotal?: number;
}

// =============================================================================
// 3. CLINICAL FORMAT
// =============================================================================
//
// CPU determines this.
// UI does not infer whether OBGYN, paediatrics, neonatology etc. applies.
//
// Examples:
//   ADULT_MEDICAL_MALE
//   ADULT_MEDICAL_FEMALE
//   ADULT_SURGICAL_MALE
//   ADULT_SURGICAL_FEMALE
//   PAEDIATRIC
//   NEONATAL
//   OBGYN_NONPREGNANT
//   OBGYN_PREGNANT
//   PSYCHIATRY
//   EMERGENCY
// =============================================================================

export interface ClinicalFormatPlan {
  baseFormat: string;

  ageBand: LifeStage;

  sex: Sex;

  pregnancyState: PregnancyState;

  pregnant: boolean;

  gestationalAgeWeeks?: number | null;

  gestationalAge?: string | null;

  department: EncounterDomain;

  encounterType: EncounterType | string | null;

  activeDomains: string[];

  includedSections: string[];

  excludedSections: string[];

  additionalSections: string[];

  requiredSections: string[];

  formatVersion?: string;

  generatedAt?: string;
}

// =============================================================================
// 4. CAPTURE TYPES
// =============================================================================

export type ClinicalCaptureType =
  | 'text'
  | 'free_text'
  | 'long_text'
  | 'single_select'
  | 'multi_select'
  | 'boolean'
  | 'numeric'
  | 'measurement'
  | 'range'
  | 'date'
  | 'datetime'
  | 'duration'
  | 'coded';

export type RequirementLevel =
  | 'mandatory'
  | 'recommended'
  | 'conditional'
  | 'optional';

export type QuestionDisposition =
  | 'skipped'
  | 'not_applicable'
  | 'deferred';

export type QuestionPriority =
  | 'routine'
  | 'important'
  | 'urgent'
  | 'emergency';

// =============================================================================
// 5. FACT VALUES
// =============================================================================

export interface ClinicalFactValue {
  code?: string | null;

  text?: string | null;

  numeric?: number | null;

  boolean?: boolean | null;

  date?: string | null;

  datetime?: string | null;

  durationSeconds?: number | null;

  rangeMin?: number | null;
  rangeMax?: number | null;

  unitCode?: string | null;

  displayValue?: string | null;
}

// =============================================================================
// 6. CLINICAL FACT
// =============================================================================

export interface ClinicalFact {
  id: string;

  patientId: string;

  encounterId: string | null;

  factCode: string;

  section:
    | HistorySection
    | 'examination'
    | 'investigation'
    | 'assessment'
    | 'management'
    | 'monitoring'
    | 'documentation';

  value: ClinicalFactValue;

  status?: 'active' | 'entered_in_error' | 'superseded';

  sourceType:
    | 'clinician'
    | 'patient'
    | 'caregiver'
    | 'system'
    | 'device'
    | 'laboratory'
    | 'imaging'
    | 'import'
    | string;

  recordedAt: string;

  recordedBy?: string | null;

  provenance?: {
    sourceId?: string | null;
    sourceSystem?: string | null;
    confidence?: number | null;
  };
}

// =============================================================================
// 7. QUESTION OPTIONS
// =============================================================================

export interface ClinicalAnswerOption {
  answerCode: string;

  label: string;

  description?: string | null;

  factValue?: ClinicalFactValue;

  disabled?: boolean;

  reasonDisabled?: string | null;
}

// =============================================================================
// 8. QUESTION VALIDATION
// =============================================================================

export interface QuestionValidation {
  min?: number | null;

  max?: number | null;

  step?: number | null;

  pattern?: string | null;

  minLength?: number | null;

  maxLength?: number | null;

  allowedUnits?: string[];
}

// =============================================================================
// 9. QUESTION REASON
// =============================================================================

export interface QuestionReason {
  code?: string | null;

  text: string;

  phenotypeCodes?: string[];

  mechanismCodes?: string[];

  conditionCodes?: string[];

  protocolCodes?: string[];

  factCodes?: string[];

  priorityBasis?: string | null;
}

// =============================================================================
// 10. CAPTURE QUESTION
// =============================================================================

export interface CaptureQuestion {
  questionCode: string;

  section:
    | HistorySection
    | 'examination'
    | 'investigation'
    | 'management'
    | 'monitoring';

  subsectionCode?: string | null;

  text: string;

  responseType: ClinicalCaptureType;

  requirementLevel: RequirementLevel;

  priority: number;

  priorityClass?: QuestionPriority;

  reason: string | null;

  reasoning?: QuestionReason | null;

  factCode: string | null;

  unitCode: string | null;

  options: ClinicalAnswerOption[];

  visible: boolean;

  enabled: boolean;

  answered?: boolean;

  disposition?: QuestionDisposition | null;

  validation?: QuestionValidation | null;

  placeholder?: string | null;

  allowUnknown?: boolean;

  allowNotApplicable?: boolean;

  allowDefer?: boolean;

  defaultAnswer?: string | null;

  source?: {
    knowledgeCode: string;

    version: string;
  } | null;
}

// =============================================================================
// 11. NAVIGATION
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
}

export interface ClinicalNavigationItem {
  id: ClinicalWorkspaceSection | string;

  label: string;

  visible: boolean;

  enabled: boolean;

  completed: boolean;

  pending: number;

  urgent: number;

  state?: WorkspaceSectionState;

  priority?: number;

  reason?: string | null;
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
    sex?: Sex;
    pregnancyState?: PregnancyState;
    pregnant?: boolean;
    gestationalAgeWeeks?: number | null;
    gestationalAge?: string | null;
    department?: EncounterDomain;
    encounterType?: EncounterType | string | null;
  };
}

// =============================================================================
// 12. EXAMINATION
// =============================================================================

export interface ExaminationFinding {
  findingCode: string;

  name: string;

  factDefinitionCode?: string | null;

  findingType: string;

  unitCode?: string | null;

  responseType?: ClinicalCaptureType;

  options?: ClinicalAnswerOption[];

  normalValue?: string | null;

  abnormal?: boolean;

  value?: ClinicalFactValue | null;
}

export interface ExaminationModule {
  moduleCode: string;

  name: string;

  sequence?: number;

  required?: boolean;

  visible?: boolean;

  findings: ExaminationFinding[];
}

// =============================================================================
// 13. INVESTIGATIONS
// =============================================================================

export type InvestigationStatus =
  | 'recommended'
  | 'ordered'
  | 'collected'
  | 'pending'
  | 'resulted'
  | 'reviewed'
  | 'cancelled';

export interface InvestigationRecommendation {
  investigationCode: string;

  name: string;

  type: string;

  weight: number;

  rationale: string | null;

  source:
    | 'condition'
    | 'mechanism'
    | 'protocol'
    | 'guideline'
    | 'safety'
    | 'screening';

  priority?: QuestionPriority;

  status?: InvestigationStatus;

  indicationCodes?: string[];

  contraindications?: string[];

  result?: {
    value?: string | null;
    unit?: string | null;
    interpretation?: string | null;
    abnormal?: boolean;
    critical?: boolean;
  } | null;
}

// =============================================================================
// 14. PHENOTYPES
// =============================================================================

export interface PhenotypeScore {
  phenotypeCode: string;

  name: string;

  score: number;

  maxScore: number;

  compatibility: number;

  supportingFactCodes?: string[];

  opposingFactCodes?: string[];
}

// =============================================================================
// 15. MECHANISMS
// =============================================================================

export interface MechanismScore {
  mechanismCode: string;

  name: string;

  support: number;

  viaFeatures: number;

  viaPhenotypes: {
    phenotypeCode: string;

    weight: number;
  }[];

  supportingFactCodes?: string[];
}

// =============================================================================
// 16. DIFFERENTIALS
// =============================================================================

export interface EvidenceLine {
  factCode: string;

  expectation: string;

  found: string | null;

  weight: number;

  polarity: 'positive' | 'negative';

  support: 'support' | 'against' | 'neutral';
}

export interface DifferentialCandidate {
  conditionCode: string;

  name: string;

  compatibility: number;

  confidence?: number;

  rank?: number;

  viaPhenotypes: {
    phenotypeCode: string;

    weight: number;
  }[];

  evidence: EvidenceLine[];

  supportingFactCodes?: string[];

  opposingFactCodes?: string[];

  reasoning?: string | null;
}

// =============================================================================
// 17. SEVERITY
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
// 18. MANAGEMENT
// =============================================================================

export interface ProtocolActionView {
  actionType: string;

  actionCode: string;

  actionName: string;

  detail: string | null;

  urgency: string;

  status?: 'pending' | 'accepted' | 'completed' | 'dismissed';
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

  version?: string;

  source?: string | null;

  steps: ProtocolStepView[];
}

// =============================================================================
// 19. TREATMENT
// =============================================================================

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

  indication?: string | null;

  alternatives?: string[];

  monitoringRequirements?: string[];

  status?: 'recommended' | 'accepted' | 'modified' | 'dismissed' | 'started';
}

// =============================================================================
// 20. MONITORING
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

  targetRange?: {
    min?: number | null;
    max?: number | null;
  };

  status?: 'stable' | 'warning' | 'critical';
}

// =============================================================================
// 21. ALERTS
// =============================================================================

export type AlertLevel =
  | 'emergency'
  | 'urgent'
  | 'warning'
  | 'info';

export interface ClinicalAlert {
  level: AlertLevel;

  code: string;

  message: string;

  title?: string;

  source?: string;

  factCodes?: string[];

  acknowledged?: boolean;

  requiresAction?: boolean;

  createdAt?: string;
}

// =============================================================================
// 22. RECOMMENDATIONS
// =============================================================================

export interface Recommendation {
  type: string;

  code: string;

  text: string;

  reason: string;

  urgency: string;

  source?: string;

  status?: 'pending' | 'accepted' | 'modified' | 'dismissed' | 'completed';
}

// =============================================================================
// 23. CONTRADICTIONS
// =============================================================================

export interface ContradictionProbe {
  factCode: string;

  expectation: string;

  weight: number;

  reason: string;

  severity?: AlertLevel;
}

// =============================================================================
// 24. CONFIGURATION
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
// 25. EDUCATION
// =============================================================================

export interface EducationItem {
  educationCode: string;

  title: string;

  audience: string;

  contentType: string;

  body: string;

  priority?: number;

  source?: string | null;
}

// =============================================================================
// 26. DOCUMENTATION
// =============================================================================

export interface DocumentationSentence {
  text: string;

  factCode: string | null;
}

export interface DocumentationSection {
  section: string;

  sentences: DocumentationSentence[];

  complete?: boolean;

  required?: boolean;
}

// =============================================================================
// 27. REASONING EXPLANATIONS
// =============================================================================

export interface Explanation {
  label: string;

  body: string;

  source?: string | null;

  evidenceFactCodes?: string[];
}

// =============================================================================
// 28. CLINICAL EVENT CONTRACT
// =============================================================================
//
// UI sends events.
// CPU validates, interprets, persists and projects.
// UI never directly writes clinical truth to PostgreSQL.
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

  eventId?: string;

  patientId?: string;

  encounterId?: string | null;

  actorId?: string | null;

  source?: 'ui' | 'device' | 'system' | 'import';
}

// =============================================================================
// 29. CLINICIAN DECISION
// =============================================================================

export interface ClinicianDecision {
  type: string;

  code: string;

  recommendation: string;

  reason?: string;

  status:
    | 'accepted'
    | 'modified'
    | 'dismissed';

  decisionReason?: string;
}

// =============================================================================
// 30. COMPLETION
// =============================================================================

export interface ClinicalCompletion {
  percentage: number;

  mandatoryRemaining: number;

  requiredSectionsRemaining?: number;

  requiredQuestionsRemaining?: number;

  currentSectionComplete?: boolean;

  encounterComplete?: boolean;
}

// =============================================================================
// 31. CONFIDENCE
// =============================================================================

export interface ClinicalConfidence {
  workingDiagnosis: string | null;

  leadingPhenotypeScore: number;

  leadingDifferentialScore?: number;

  overall?: number;

  confidenceBand?: 'low' | 'moderate' | 'high';

  explanation?: string | null;
}

// =============================================================================
// 32. UNIVERSAL CLINICAL PROJECTION
// =============================================================================
//
// THIS IS THE MAIN CONTRACT RETURNED BY THE CPU TO THE UI.
//
// PostgreSQL -> CPU
// CPU rules/knowledge -> CPU projection
// CPU projection -> API
// API -> UI
//
// The UI renders this object.
// =============================================================================

export interface UniversalClinicalProjection {
  context: ClinicalContext;

  formatPlan?: ClinicalFormatPlan;

  sections: HistorySectionDefinition[];

  navigation: ClinicalNavigationItem[];

  workspaceNavigation?: WorkspaceNavigationProjection;

  capturedFacts: ClinicalFact[];

  questions: CaptureQuestion[];

  activeSection: string;

  completion: ClinicalCompletion;

  alerts: ClinicalAlert[];

  phenotypes: PhenotypeScore[];

  mechanisms: MechanismScore[];

  differentials: DifferentialCandidate[];

  examination: ExaminationModule[];

  investigations: InvestigationRecommendation[];

  severityScores?: SeverityScore[];

  treatment: TreatmentRecommendation[];

  protocol: ProtocolView | null;

  monitoring: MonitoringTarget[];

  documentation: DocumentationSection[];

  education?: EducationItem[];

  recommendations?: Recommendation[];

  explanations?: Explanation[];

  contradictions?: ContradictionProbe[];

  configuration?: {
    overrides: ConfigurationOverride[];
  };

  confidence?: ClinicalConfidence;

  eventId: number | null;

  projectionVersion?: string;

  generatedAt?: string;
}

// =============================================================================
// 33. REALTIME CONNECTION
// =============================================================================

export type ConnectionState =
  | 'online'
  | 'offline'
  | 'syncing';

// =============================================================================
// 34. TIMELINE
// =============================================================================

export interface TimelineEvent {
  eventId: number;

  eventType: string;

  payload: Record<string, unknown>;

  occurredAt: string;

  actorId?: string | null;

  source?: string | null;
}

// =============================================================================
// 35. ENCOUNTER SUMMARY
// =============================================================================

export interface EncounterSummary {
  encounterId: string;

  patientId: string;

  patientName: string;

  age: number;

  sex: Sex;

  department: EncounterDomain;

  presentingComplaint: string;

  startedAt: string;

  status:
    | 'in_progress'
    | 'completed'
    | 'reviewed';

  format?: string | null;
}

// =============================================================================
// 36. API CONTRACTS
// =============================================================================

export interface StartEncounterInput {
  patientId: string;

  encounterId?: string | null;

  ageYears?: number | null;

  ageMonths?: number | null;

  ageDays?: number | null;

  dateOfBirth?: string | null;

  sex: Sex;

  pregnancyState?: PregnancyState;

  gestationalAgeWeeks?: number | null;

  department?: EncounterDomain;

  encounterType?: EncounterType | string;

  encounterTypeCode?: string;

  presentingComplaintCodes?: string[];

  activeSymptomCodes?: string[];
}

export interface StartEncounterResponse {
  projection: UniversalClinicalProjection;
}

export interface CaptureClinicalEventInput {
  patientId: string;

  encounterId: string;

  event: ClinicalEvent;
}

export interface TimelineResponse {
  entries: TimelineEvent[];
}

// =============================================================================
// 37. UI WORKSPACE STATE
// =============================================================================

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

  alerts: ClinicalAlert[];

  confidence?: number;
}

// =============================================================================
// 38. BACKWARD-COMPATIBILITY ALIASES
// =============================================================================

export type FactValue = ClinicalFactValue;

export type Fact = ClinicalFact;

export type NextQuestion = CaptureQuestion;

export type ExaminationFindingView = ExaminationFinding;

export type ExaminationModuleView = ExaminationModule;

// =============================================================================
// 39. DISPLAY HELPERS
// =============================================================================

export function factDisplayValue(fact: ClinicalFact): string {
  const value = fact.value;

  if (!value) {
    return 'â€”';
  }

  if (value.text != null) {
    return value.text;
  }

  if (value.code != null) {
    return value.code;
  }

  if (value.numeric != null) {
    return value.unitCode
      ? `${value.numeric} ${value.unitCode}`
      : String(value.numeric);
  }

  if (value.boolean != null) {
    return value.boolean ? 'Yes' : 'No';
  }

  if (value.date != null) {
    return value.date;
  }

  if (value.datetime != null) {
    return value.datetime;
  }

  if (
    value.rangeMin != null ||
    value.rangeMax != null
  ) {
    return `${value.rangeMin ?? 'â€”'} â€“ ${value.rangeMax ?? 'â€”'}`;
  }

  return 'â€”';
}

export function sourceNice(
  sourceType: string | null | undefined,
): string {
  return (sourceType ?? 'unknown')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export function nicer(code: string): string {
  return code
    .replace(/_/g, ' ')
    .toLowerCase()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

// =============================================================================
// 40. CONTEXT HELPERS
// =============================================================================

export function isFemale(context: ClinicalContext): boolean {
  return context.sex === 'female';
}

export function isMale(context: ClinicalContext): boolean {
  return context.sex === 'male';
}

export function isPregnant(context: ClinicalContext): boolean {
  return context.pregnancyState === 'pregnant';
}

export function isPostpartum(context: ClinicalContext): boolean {
  return context.pregnancyState === 'postpartum';
}

export function isNeonate(context: ClinicalContext): boolean {
  return context.lifeStage === 'neonate';
}

export function isPaediatric(context: ClinicalContext): boolean {
  return (
    context.lifeStage === 'neonate' ||
    context.lifeStage === 'infant' ||
    context.lifeStage === 'child'
  );
}

export function isAdult(context: ClinicalContext): boolean {
  return (
    context.lifeStage === 'adult' ||
    context.lifeStage === 'older_adult'
  );
}

// =============================================================================
// 41. SECTION HELPERS
// =============================================================================

export function sectionIsVisible(
  projection: UniversalClinicalProjection,
  sectionCode: string,
): boolean {
  const section = projection.navigation.find(
    (item) => item.id === sectionCode,
  );

  return section?.visible ?? false;
}

export function sectionIsEnabled(
  projection: UniversalClinicalProjection,
  sectionCode: string,
): boolean {
  const section = projection.navigation.find(
    (item) => item.id === sectionCode,
  );

  return section?.enabled ?? false;
}

export function sectionIsComplete(
  projection: UniversalClinicalProjection,
  sectionCode: string,
): boolean {
  const section = projection.navigation.find(
    (item) => item.id === sectionCode,
  );

  return section?.completed ?? false;
}

// =============================================================================
// 42. QUESTION HELPERS
// =============================================================================

export function mandatoryQuestions(
  projection: UniversalClinicalProjection,
): CaptureQuestion[] {
  return projection.questions.filter(
    (question) =>
      question.visible &&
      question.enabled &&
      question.requirementLevel === 'mandatory' &&
      !question.answered &&
      !question.disposition,
  );
}

export function nextMandatoryQuestion(
  projection: UniversalClinicalProjection,
): CaptureQuestion | null {
  return (
    mandatoryQuestions(projection)
      .sort((a, b) => b.priority - a.priority)[0] ?? null
  );
}

// =============================================================================
// 43. ALERT HELPERS
// =============================================================================

export function hasEmergency(
  projection: UniversalClinicalProjection,
): boolean {
  return projection.alerts.some(
    (alert) => alert.level === 'emergency',
  );
}

export function hasUrgent(
  projection: UniversalClinicalProjection,
): boolean {
  return projection.alerts.some(
    (alert) =>
      alert.level === 'urgent' ||
      alert.level === 'emergency',
  );
}

// =============================================================================
// END OF UNIVERSAL CLINICAL CAPTURE CONTRACT
// =============================================================================
