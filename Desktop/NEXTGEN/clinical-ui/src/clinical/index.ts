// =============================================================================
// src/clinical/types.ts
// UNIVERSAL AMEXAN CLINICAL CAPTURE CONTRACT
// =============================================================================

export type Sex = 'male' | 'female' | 'intersex' | 'unknown';

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

export type PregnancyState =
  | 'not_applicable'
  | 'not_pregnant'
  | 'pregnant'
  | 'postpartum'
  | 'unknown';

/**
 * Universal history section vocabulary.
 *
 * IMPORTANT:
 * These are reusable sections, not a single fixed history.
 * The CPU selects the appropriate ordered subset from context.
 */
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
  | 'maternal_history'
  | 'growth_development'
  | 'immunization'
  | 'nutrition'
  | 'psychiatric_history'
  | 'substance_history'
  | 'collateral_history'
  | 'forensic_history'
  | 'mental_state'
  | 'risk_assessment'
  | 'summary';

export type ClinicalCaptureType =
  | 'text'
  | 'single_select'
  | 'multi_select'
  | 'boolean'
  | 'numeric'
  | 'measurement'
  | 'date'
  | 'datetime'
  | 'duration'
  | 'coded'
  | 'free_text'
  | 'long_text'
  | 'range';

export type RequirementLevel =
  | 'mandatory'
  | 'recommended'
  | 'conditional'
  | 'optional';

export interface ClinicalContext {
  patientId: string;
  encounterId: string | null;

  ageYears: number | null;
  ageMonths: number | null;
  ageDays: number | null;

  sex: Sex;
  lifeStage: LifeStage;

  pregnancyState: PregnancyState;

  department: EncounterDomain;
  encounterType: string | null;

  presentingComplaintCodes: string[];
  activeSymptomCodes: string[];

  firstVisit: boolean;
  emergency: boolean;
}

export interface HistorySectionDefinition {
  code: HistorySection;
  label: string;
  sequence: number;

  required: boolean;
  visible: boolean;
  enabled?: boolean;

  requirementLevel?: RequirementLevel;

  reason?: string | null;

  requiredRemaining?: number;
  requiredTotal?: number;

  children?: HistorySectionDefinition[];
}

export interface ClinicalFactValue {
  code?: string | null;
  text?: string | null;
  numeric?: number | null;
  boolean?: boolean | null;
  date?: string | null;
  datetime?: string | null;
  unitCode?: string | null;
}

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
    | 'management';

  value: ClinicalFactValue;

  sourceType: string;

  recordedAt: string;
}

export interface CaptureQuestion {
  questionCode: string;

  section:
    | HistorySection
    | 'examination';

  text: string;

  responseType: ClinicalCaptureType;

  requirementLevel: RequirementLevel;

  priority: number;

  reason: string | null;

  factCode: string | null;
  unitCode: string | null;

  options: {
    answerCode: string;
    label: string;
    factValue?: ClinicalFactValue;
  }[];

  visible: boolean;
  enabled: boolean;

  validation?: {
    min?: number | null;
    max?: number | null;
    step?: number | null;
    pattern?: string | null;
  } | null;

  placeholder?: string | null;

  allowUnknown?: boolean;
  allowNotApplicable?: boolean;
  allowDefer?: boolean;

  source?: {
    knowledgeCode: string;
    version: string;
  } | null;
}

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

export interface ClinicalNavigationItem {
  id: HistorySection | string;
  label: string;

  visible: boolean;
  enabled: boolean;

  completed: boolean;

  pending: number;
  urgent: number;

  reason?: string | null;
}

export interface UniversalClinicalProjection {
  context: ClinicalContext;

  sections: HistorySectionDefinition[];

  navigation: ClinicalNavigationItem[];

  capturedFacts: ClinicalFact[];

  questions: CaptureQuestion[];

  activeSection: string;

  completion: {
    percentage: number;
    mandatoryRemaining: number;
  };

  alerts: {
    level: 'emergency' | 'urgent' | 'warning' | 'info';
    code: string;
    message: string;
  }[];

  phenotypes: unknown[];
  mechanisms: unknown[];
  differentials: unknown[];
  examination: unknown[];
  investigations: unknown[];
  treatment: unknown[];
  protocol: unknown | null;
  monitoring: unknown[];
  documentation: unknown[];

  eventId: number | null;
}