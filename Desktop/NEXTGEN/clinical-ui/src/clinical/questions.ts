// =============================================================================
// src/clinical/questions.ts
// AMEXAN UNIVERSAL CLINICAL QUESTION ENGINE
//
// PRINCIPLE
// -----------------------------------------------------------------------------
// The UI does NOT reason.
// The UI renders questions projected by the clinical CPU.
//
// This module defines:
//   1. Question vocabulary
//   2. Context applicability  (age, sex, pregnancy, department, encounter)
//   3. Question dependencies   (visibleWhen on captured facts)
//   4. Requirement levels
//   5. Validation
//   6. Priority metadata
//
// IMPORTANT
// -----------------------------------------------------------------------------
// A question must not be included merely because it is medically interesting.
// It must be:
//   - applicable to the patient's context,
//   - not already captured,
//   - visible under its dependency rules,
//   - and relevant to the active workflow.
//
// Hard context rules:
//   - A male patient NEVER receives obstetric/gynaecological/ANC questions.
//   - A young child NEVER receives marriage, alcohol, tobacco, sexual or
//     substance questions.
//   - Occupations are not asked of children or retirees below school age.
//   - Developmental milestones are only asked for the child's age window.
//
// The question engine does NOT diagnose.
// It does NOT select a disease.
// It does NOT calculate a differential.
// It does NOT decide treatment.
// =============================================================================

import type {
  ClinicalContext,
  ClinicalFact,
  CaptureQuestion,
  HistorySection,
  RequirementLevel,
} from './types';

import {
  type ComplaintSystem,
  complaintSystemCovered,
  hasChiefComplaints,
} from './complaints';

import {
  ageInMonths,
  milestoneFactCode,
  milestonesForAge,
} from './milestones';

// =============================================================================
// INTERNAL QUESTION DEFINITION
// =============================================================================

interface QuestionDefinition {
  questionCode: string;

  section: CaptureQuestion['section'];

  text: string;

  responseType: CaptureQuestion['responseType'];

  requirementLevel: RequirementLevel;

  /**
   * Higher priority questions are surfaced first when otherwise equivalent.
   */
  priority: number;

  /**
   * Fact produced when the question is answered.
   */
  factCode?: string;

  unitCode?: string;

  /**
   * Context-level applicability.
   *
   * This is NOT diagnostic reasoning.
   * It answers questions such as:
   *
   *   "Does this question belong to a paediatric encounter?"
   *   "Does this question belong to an obstetric encounter?"
   */
  applies?: (context: ClinicalContext) => boolean;

  /**
   * Fact-dependent visibility.
   *
   * This allows:
   *
   *   "Do you have chest pain?" -> YES
   *   "Where is the chest pain?"
   *
   * without making the UI itself reason about disease.
   */
  visibleWhen?: (
    context: ClinicalContext,
    facts: ClinicalFact[],
  ) => boolean;

  options?: CaptureQuestion['options'];

  validation?: CaptureQuestion['validation'];

  placeholder?: string | null;

  allowUnknown?: boolean;

  allowNotApplicable?: boolean;

  allowDefer?: boolean;

  reason?: string | null;

  source?: {
    knowledgeCode: string;
    version: string;
  } | null;
}

// =============================================================================
// HELPERS
// =============================================================================

function hasFact(
  facts: ClinicalFact[],
  factCode: string,
): boolean {
  return facts.some((fact) => fact.factCode === factCode);
}

function factValue(
  facts: ClinicalFact[],
  factCode: string,
): ClinicalFact['value'] | null {
  const fact = facts.find((item) => item.factCode === factCode);
  return fact?.value ?? null;
}

function factBoolean(
  facts: ClinicalFact[],
  factCode: string,
): boolean | null {
  const value = factValue(facts, factCode);

  if (!value) return null;

  if (typeof value.boolean === 'boolean') {
    return value.boolean;
  }

  if (value.code === 'YES') return true;
  if (value.code === 'NO') return false;

  if (value.text?.toLowerCase() === 'yes') return true;
  if (value.text?.toLowerCase() === 'no') return false;

  return null;
}

function isPaediatric(context: ClinicalContext): boolean {
  return (
    context.lifeStage === 'neonate' ||
    context.lifeStage === 'infant' ||
    context.lifeStage === 'child' ||
    context.lifeStage === 'adolescent'
  );
}

function noChiefComplaints(
  _context: ClinicalContext,
  facts: ClinicalFact[],
): boolean {
  return !hasChiefComplaints(facts);
}

/**
 * A chief complaint is "documented" when either structured complaints have
 * been saved, or the free-text presenting complaint has been captured.
 * Baseline HPI questions only appear once a complaint is documented.
 */
function chiefComplaintDocumented(
  _context: ClinicalContext,
  facts: ClinicalFact[],
): boolean {
  return (
    hasChiefComplaints(facts) ||
    hasFact(facts, 'PRESENTING_COMPLAINT')
  );
}

function baselineHPIRelevant(
  _context: ClinicalContext,
  facts: ClinicalFact[],
): boolean {
  // Baseline HPI (generic onset/duration/severity) is only relevant when a
  // complaint is documented but no structured complaints were saved.
  return (
    chiefComplaintDocumented(_context, facts) &&
    !hasChiefComplaints(facts)
  );
}

function systemNotCovered(
  facts: ClinicalFact[],
  system: ComplaintSystem,
): boolean {
  return !complaintSystemCovered(facts, system);
}

function booleanOptions(): CaptureQuestion['options'] {
  return [
    {
      answerCode: 'YES',
      label: 'Yes',
    },
    {
      answerCode: 'NO',
      label: 'No',
    },
    {
      answerCode: 'UNKNOWN',
      label: 'Unknown',
    },
  ];
}

function isNeonate(context: ClinicalContext): boolean {
  return context.lifeStage === 'neonate';
}

function isAdult(context: ClinicalContext): boolean {
  return (
    context.lifeStage === 'adult' ||
    context.lifeStage === 'older_adult'
  );
}

/** School-age children (≥5 years, <18 years) may be asked school/social items. */
function isSchoolAge(context: ClinicalContext): boolean {
  const months = ageInMonths(context);
  return months != null && months >= 60 && months < 216;
}

/** Adolescents (12–17 years) — old enough for selected substance items. */
function isAdolescentOrOlder(context: ClinicalContext): boolean {
  const months = ageInMonths(context);
  return months != null && months >= 144;
}

function isFemaleReproductiveAge(
  context: ClinicalContext,
): boolean {
  return (
    context.sex === 'female' &&
    context.ageYears != null &&
    context.ageYears >= 12 &&
    context.ageYears <= 55
  );
}

function isPregnant(
  context: ClinicalContext,
): boolean {
  return context.pregnancyState === 'pregnant';
}

export function isPsychiatry(
  context: ClinicalContext,
): boolean {
  return context.department === 'psychiatry';
}

function isEmergency(
  context: ClinicalContext,
): boolean {
  return context.emergency;
}

function isReviewOrFollowUp(
  context: ClinicalContext,
): boolean {
  const type = String(context.encounterType ?? '').toLowerCase();
  return (
    type === 'review' ||
    type === 'follow_up' ||
    type === 'followup' ||
    type === 'clinic'
  );
}

/** Surgical / post-operative patients receive post-op recovery questions. */
function isSurgical(
  context: ClinicalContext,
): boolean {
  return (
    context.department === 'surgical' ||
    context.department === 'obgyn'
  );
}

// =============================================================================
// UNIVERSAL QUESTIONS
// =============================================================================
//
// These are deliberately small and foundational.
// Patient demographic information already supplied in ClinicalContext should
// NOT be repeatedly requested by the UI.
//
// For example, BIO_SEX and BIO_AGE are not necessary when the encounter-start
// contract already contains sex and age.
//
// =============================================================================

const UNIVERSAL_QUESTIONS: QuestionDefinition[] = [

  // ===========================================================================
  // BIODATA / ADMISSION CONTEXT
  //
  // Ward forms record "doing day X post admission" and (for surgical and
  // gynaecological patients) "day X post-operative following [procedure]".
  // Religion is recorded for surgical and obstetric patients per the forms.
  // ===========================================================================

  {
    questionCode: 'BIODATA_RELIGION',
    section: 'biodata',
    text: 'What is the patient’s religion?',
    responseType: 'free_text',
    requirementLevel: 'optional',
    factCode: 'RELIGION',
    priority: 1995,
    applies: (context) =>
      context.department === 'surgical' ||
      context.department === 'obgyn',
    placeholder: 'e.g. Christian, Muslim',
  },

  {
    questionCode: 'BIODATA_POST_ADMISSION_DAY',
    section: 'biodata',
    text: 'Which post-admission day is the patient doing today?',
    responseType: 'numeric',
    requirementLevel: 'conditional',
    factCode: 'POST_ADMISSION_DAY',
    priority: 1990,
    applies: (context) =>
      String(context.encounterType ?? '').toLowerCase() === 'ipd' ||
      String(context.encounterType ?? '').toLowerCase() === 'inpatient',
    validation: {
      min: 0,
      step: 1,
    },
    placeholder: 'e.g. 2',
  },

  {
    questionCode: 'BIODATA_POST_OP_DAY',
    section: 'biodata',
    text: 'Which post-operative day is the patient doing today?',
    responseType: 'numeric',
    requirementLevel: 'conditional',
    factCode: 'POST_OPERATIVE_DAY',
    priority: 1989,
    applies: (context) =>
      context.department === 'surgical' ||
      context.department === 'obgyn',
    validation: {
      min: 0,
      step: 1,
      max: 60,
    },
    placeholder: 'e.g. 3',
    reason: 'Surgical and gynaecological ward forms record the post-operative day.',
  },

  {
    questionCode: 'BIODATA_POST_OP_PROCEDURE',
    section: 'biodata',
    text: 'What surgical procedure was performed?',
    responseType: 'free_text',
    requirementLevel: 'conditional',
    factCode: 'POST_OPERATIVE_PROCEDURE',
    priority: 1988,
    applies: (context) =>
      context.department === 'surgical' ||
      context.department === 'obgyn',
    placeholder:
      'e.g. Laparotomy — or "unknown to the patient" if not known',
    reason: 'The form allows "procedure unknown to the patient".',
  },

  {
    questionCode: 'BIODATA_POST_MVA_DC_DAYS',
    section: 'biodata',
    text: 'How many days post manual vacuum aspiration (MVA) / dilatation and curettage (D&C) is the patient?',
    responseType: 'numeric',
    requirementLevel: 'conditional',
    factCode: 'POST_MVA_DC_DAYS',
    priority: 1987,
    applies: (context) =>
      context.department === 'obgyn' &&
      context.sex === 'female',
    validation: {
      min: 0,
      step: 1,
      max: 60,
    },
    placeholder: 'e.g. 2',
  },

  {
    questionCode: 'BIODATA_SCHOOL',
    section: 'biodata',
    text: 'Which school does the child attend (and which grade/class)?',
    responseType: 'free_text',
    requirementLevel: 'conditional',
    factCode: 'SCHOOL_NAME',
    priority: 1986,
    applies: (context) =>
      isPaediatric(context) && isSchoolAge(context),
    placeholder: 'e.g. Greenhill Primary, Grade 3',
  },

  // ===========================================================================
  // CHIEF COMPLAINT
  // ===========================================================================

  {
    questionCode: 'CC_PRESENTING_COMPLAINT',
    section: 'chief_complaint',
    text: 'What is the main reason for attendance today?',
    responseType: 'free_text',
    requirementLevel: 'mandatory',
    factCode: 'PRESENTING_COMPLAINT',
    priority: 1000,
    placeholder: 'Describe the main problem in the patient’s own words',
    allowUnknown: false,
    allowNotApplicable: false,
    allowDefer: false,
    visibleWhen: noChiefComplaints,
    reason: 'Establishes the presenting problem before detailed history.',
  },

  {
    questionCode: 'CC_NO_COMPLAINTS_FOLLOWUP',
    section: 'chief_complaint',
    text: 'Is the patient on routine review / follow-up with no current complaints?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'FOLLOW_UP_NO_COMPLAINTS',
    priority: 999,
    applies: (context) =>
      isReviewOrFollowUp(context) && !isPregnant(context),
    visibleWhen: noChiefComplaints,
    options: booleanOptions(),
    reason: 'For review/follow-up visits where the patient reports no new symptoms.',
  },

  // ===========================================================================
  // HPI — UNIVERSAL CORE
  //
  // These baseline questions ONLY appear when a complaint has been documented
  // but no structured chief complaints were saved. When structured complaints
  // exist, per-complaint HPI questions (built dynamically) replace them.
  // ===========================================================================

  {
    questionCode: 'HPI_DURATION',
    section: 'hpi',
    text: 'How long has the main problem been present?',
    responseType: 'measurement',
    requirementLevel: 'mandatory',
    factCode: 'SYMPTOM_DURATION',
    priority: 990,
    unitCode: 'days',
    validation: {
      min: 0,
      step: 0.1,
    },
    placeholder: 'e.g. 4',
    visibleWhen: baselineHPIRelevant,
    reason: 'Establishes the temporal course of the presenting problem.',
  },

  {
    questionCode: 'HPI_ONSET',
    section: 'hpi',
    text: 'How did the problem begin?',
    responseType: 'single_select',
    requirementLevel: 'mandatory',
    factCode: 'SYMPTOM_ONSET',
    priority: 980,
    options: [
      {
        answerCode: 'SUDDEN',
        label: 'Sudden',
      },
      {
        answerCode: 'GRADUAL',
        label: 'Gradual',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
    visibleWhen: baselineHPIRelevant,
    reason: 'Clarifies the temporal pattern of onset.',
  },

  {
    questionCode: 'HPI_COURSE',
    section: 'hpi',
    text: 'How has the problem changed since it started?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'SYMPTOM_COURSE',
    priority: 970,
    options: [
      {
        answerCode: 'IMPROVING',
        label: 'Improving',
      },
      {
        answerCode: 'WORSENING',
        label: 'Worsening',
      },
      {
        answerCode: 'STABLE',
        label: 'About the same',
      },
      {
        answerCode: 'FLUCTUATING',
        label: 'Comes and goes / fluctuates',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
    visibleWhen: baselineHPIRelevant,
  },

  {
    questionCode: 'HPI_SEVERITY',
    section: 'hpi',
    text: 'How severe is the main problem at its worst?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'SYMPTOM_SEVERITY',
    priority: 960,
    options: [
      {
        answerCode: 'MILD',
        label: 'Mild',
      },
      {
        answerCode: 'MODERATE',
        label: 'Moderate',
      },
      {
        answerCode: 'SEVERE',
        label: 'Severe',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
    visibleWhen: baselineHPIRelevant,
  },

  {
    questionCode: 'HPI_IMPACT_FUNCTION',
    section: 'hpi',
    text: 'How has the problem affected the patient’s usual activities or function?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'SYMPTOM_FUNCTIONAL_IMPACT',
    priority: 950,
    options: [
      {
        answerCode: 'NONE',
        label: 'No significant effect',
      },
      {
        answerCode: 'MILD',
        label: 'Mild reduction',
      },
      {
        answerCode: 'MODERATE',
        label: 'Moderate reduction',
      },
      {
        answerCode: 'SEVERE',
        label: 'Unable to perform usual activities',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
    visibleWhen: baselineHPIRelevant,
  },

  {
    questionCode: 'HPI_ASSOCIATED_SYMPTOMS',
    section: 'hpi',
    text: 'What other symptoms have occurred with the main problem?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'ASSOCIATED_SYMPTOMS',
    priority: 940,
    placeholder: 'Record associated symptoms without interpreting them as a diagnosis.',
    visibleWhen: baselineHPIRelevant,
  },

  {
    questionCode: 'HPI_AGGRAVATING_FACTORS',
    section: 'hpi',
    text: 'What makes the problem worse?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'SYMPTOM_AGGRAVATING_FACTORS',
    priority: 930,
    visibleWhen: baselineHPIRelevant,
  },

  {
    questionCode: 'HPI_RELIEVING_FACTORS',
    section: 'hpi',
    text: 'What makes the problem better?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'SYMPTOM_RELIEVING_FACTORS',
    priority: 920,
    visibleWhen: baselineHPIRelevant,
  },

  {
    questionCode: 'HPI_PRIOR_EPISODES',
    section: 'hpi',
    text: 'Has the patient experienced this problem or similar episodes before?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'SIMILAR_PRIOR_EPISODES',
    priority: 910,
    options: [
      {
        answerCode: 'YES',
        label: 'Yes',
      },
      {
        answerCode: 'NO',
        label: 'No',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
    visibleWhen: baselineHPIRelevant,
  },

  // ===========================================================================
  // HPI — REVIEW / FOLLOW-UP DESCRIPTION
  //
  // When the patient is on routine follow-up with no new complaints, the
  // clinician records the course since the last visit in free text.
  // ===========================================================================

  {
    questionCode: 'HPI_FOLLOW_UP_COURSE',
    section: 'hpi',
    text: 'Describe the clinical course since the last review (progress, adherence, new concerns).',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'FOLLOW_UP_COURSE',
    priority: 1000,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'FOLLOW_UP_NO_COMPLAINTS') === true,
    placeholder: 'e.g. Reviewed monthly. Well on treatment, no new symptoms; medication well tolerated.',
  },

  // ===========================================================================
  // PAST MEDICAL HISTORY
  //
  // Fast negative capture: a single "no relevant history" gate avoids a wall
  // of questions when the patient has no significant past medical history.
  // ===========================================================================

  {
    questionCode: 'PMHX_MEDICAL',
    section: 'past_medical_history',
    text: 'Has the patient ever been diagnosed with any significant medical condition?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'PAST_MEDICAL_HISTORY_PRESENT',
    priority: 800,
    options: booleanOptions(),
    reason: 'A negative gate documents "no relevant past medical history" quickly.',
  },

  {
    questionCode: 'PMHX_CONDITIONS',
    section: 'past_medical_history',
    text: 'Which previous or chronic medical conditions apply?',
    responseType: 'multi_select',
    requirementLevel: 'conditional',
    factCode: 'CHRONIC_CONDITIONS',
    priority: 799,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'PAST_MEDICAL_HISTORY_PRESENT') === true,
    options: [
      { answerCode: 'TUBERCULOSIS', label: 'Tuberculosis (TB)' },
      { answerCode: 'HYPERTENSION', label: 'Hypertension (HTN)' },
      { answerCode: 'DIABETES', label: 'Diabetes mellitus (DM)' },
      { answerCode: 'ASTHMA', label: 'Asthma' },
      { answerCode: 'EPILEPSY', label: 'Epilepsy / seizures' },
      { answerCode: 'HEART_DISEASE', label: 'Heart disease (incl. rheumatic)' },
      { answerCode: 'SICKLE_CELL', label: 'Sickle cell disease' },
      { answerCode: 'HIV', label: 'HIV' },
      { answerCode: 'RENAL_DISEASE', label: 'Chronic kidney disease' },
      { answerCode: 'CANCER', label: 'Malignancy' },
      { answerCode: 'PEPTIC_ULCER', label: 'Peptic ulcer disease' },
      { answerCode: 'MENTAL_ILLNESS', label: 'Mental illness' },
    ],
  },

  {
    questionCode: 'PMHX_CONDITIONS_DETAILS',
    section: 'past_medical_history',
    text: 'Give details of the previous medical conditions and how they are managed.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'PAST_MEDICAL_HISTORY_DETAILS',
    priority: 798,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'PAST_MEDICAL_HISTORY_PRESENT') === true,
  },

  {
    questionCode: 'PMHX_HOSPITALIZATION',
    section: 'past_medical_history',
    text: 'Has the patient previously required hospital admission?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'PREVIOUS_HOSPITALIZATION',
    priority: 797,
    options: booleanOptions(),
  },

  {
    questionCode: 'PMHX_HOSPITALIZATION_DETAILS',
    section: 'past_medical_history',
    text: 'Details of previous hospital admissions (reason, year, duration).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'PREVIOUS_HOSPITALIZATION_DETAILS',
    priority: 796,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'PREVIOUS_HOSPITALIZATION') === true,
  },

  {
    questionCode: 'PMHX_BLOOD_TRANSFUSION',
    section: 'past_medical_history',
    text: 'Has the patient ever received a blood transfusion?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'BLOOD_TRANSFUSION',
    priority: 795,
    options: booleanOptions(),
  },

  {
    questionCode: 'PMHX_BLOOD_TRANSFUSION_DETAILS',
    section: 'past_medical_history',
    text: 'Details of the blood transfusion(s).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'BLOOD_TRANSFUSION_DETAILS',
    priority: 794,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'BLOOD_TRANSFUSION') === true,
  },

  {
    questionCode: 'PMHX_HIV_STATUS',
    section: 'past_medical_history',
    text: 'What is the patient’s HIV serostatus?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'HIV_SEROSTATUS',
    priority: 793,
    options: [
      { answerCode: 'NEGATIVE', label: 'Negative' },
      { answerCode: 'POSITIVE', label: 'Positive' },
      { answerCode: 'UNKNOWN', label: 'Unknown / not tested' },
    ],
    reason: 'Serostatus is routinely documented in the past medical history.',
  },

  {
    questionCode: 'PMHX_HIV_ART',
    section: 'past_medical_history',
    text: 'If HIV positive, is the patient on antiretroviral therapy (ART)?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ON_ART',
    priority: 792,
    visibleWhen: (_context, facts) =>
      factValue(facts, 'HIV_SEROSTATUS')?.code === 'POSITIVE',
    options: booleanOptions(),
  },

  // ===========================================================================
  // SURGICAL HISTORY
  // ===========================================================================

  {
    questionCode: 'PSHX_SURGERY',
    section: 'past_surgical_history',
    text: 'Has the patient had any previous operations or surgical procedures?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'PAST_SURGERY_PRESENT',
    priority: 770,
    options: booleanOptions(),
  },

  {
    questionCode: 'PSHX_SURGERY_DETAILS',
    section: 'past_surgical_history',
    text: 'List previous operations/procedures with year and reason.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'PAST_SURGICAL_HISTORY',
    priority: 769,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'PAST_SURGERY_PRESENT') === true,
    placeholder: 'e.g. Appendicectomy 2015; C-section 2020.',
  },

  // ===========================================================================
  // DRUG HISTORY
  // ===========================================================================

  {
    questionCode: 'DRUG_CURRENT',
    section: 'drug_history',
    text: 'Is the patient currently taking any medication (prescribed, over-the-counter, herbal)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'CURRENT_MEDICATION_PRESENT',
    priority: 760,
    options: booleanOptions(),
  },

  {
    questionCode: 'DRUG_CURRENT_LIST',
    section: 'drug_history',
    text: 'List the current medications, doses, and how long each has been taken.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'CURRENT_MEDICATIONS',
    priority: 759,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'CURRENT_MEDICATION_PRESENT') === true,
    placeholder: 'e.g. Metformin 500 mg BD for 3 years; Enalapril 10 mg OD.',
  },

  {
    questionCode: 'DRUG_RECENT',
    section: 'drug_history',
    text: 'Has the patient taken any medication or treatment recently for the current problem?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'RECENT_TREATMENT',
    priority: 750,
  },

  {
    questionCode: 'DRUG_ADHERENCE',
    section: 'drug_history',
    text: 'Does the patient take their medication as prescribed?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'DRUG_ADHERENCE',
    priority: 749,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'CURRENT_MEDICATION_PRESENT') === true,
    options: [
      { answerCode: 'GOOD', label: 'Good (always)' },
      { answerCode: 'PARTIAL', label: 'Partial / sometimes missed' },
      { answerCode: 'POOR', label: 'Poor / rarely taken' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  // ===========================================================================
  // ALLERGIES
  // ===========================================================================

  {
    questionCode: 'ALLERGY',
    section: 'allergy_history',
    text: 'Does the patient have any known drug, food, or other clinically relevant allergy?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ALLERGY_PRESENT',
    priority: 740,
    options: [
      {
        answerCode: 'YES',
        label: 'Yes',
      },
      {
        answerCode: 'NO',
        label: 'No known allergy',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  {
    questionCode: 'ALLERGY_TYPE',
    section: 'allergy_history',
    text: 'Which type(s) of allergy are present?',
    responseType: 'multi_select',
    requirementLevel: 'conditional',
    factCode: 'ALLERGY_TYPE',
    priority: 739,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ALLERGY_PRESENT') === true,
    options: [
      { answerCode: 'DRUG', label: 'Drug allergy' },
      { answerCode: 'FOOD', label: 'Food allergy' },
      { answerCode: 'LATEX', label: 'Latex allergy' },
      { answerCode: 'OTHER', label: 'Other' },
    ],
  },

  {
    questionCode: 'ALLERGY_DETAILS',
    section: 'allergy_history',
    text: 'Which allergen(s), and what reaction occurred (type, severity)?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ALLERGY_DETAILS',
    priority: 738,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ALLERGY_PRESENT') === true,
    placeholder: 'e.g. Penicillin — generalised rash; Peanuts — anaphylaxis.',
  },

  // ===========================================================================
  // FAMILY HISTORY
  //
  // Context rules:
  //   - Common adult conditions are only probed for adult patients.
  //   - For children, household contact / consanguinity / sickle-cell items
  //     are probed instead.
  // ===========================================================================

  {
    questionCode: 'FAMILY_HISTORY',
    section: 'family_history',
    text: 'Is there any relevant family history of illness?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_HISTORY_PRESENT',
    priority: 700,
    options: booleanOptions(),
  },

  {
    questionCode: 'FAMILY_HISTORY_DETAILS',
    section: 'family_history',
    text: 'Which family members have which conditions?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_HISTORY_DETAILS',
    priority: 699,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'FAMILY_HISTORY_PRESENT') === true,
  },

  // Adult-focused conditions
  {
    questionCode: 'FAMILY_HISTORY_CARDIOVASCULAR',
    section: 'family_history',
    text: 'Is there a family history of hypertension, diabetes, heart disease or stroke?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_HISTORY_CARDIOVASCULAR',
    priority: 698,
    applies: (context) => isAdult(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'FAMILY_HISTORY_PRESENT') === true,
    options: booleanOptions(),
  },

  {
    questionCode: 'FAMILY_HISTORY_CANCER',
    section: 'family_history',
    text: 'Is there a family history of cancer?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_HISTORY_CANCER',
    priority: 697,
    applies: (context) => isAdult(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'FAMILY_HISTORY_PRESENT') === true,
    options: booleanOptions(),
  },

  // Paediatric-focused items
  {
    questionCode: 'FAMILY_TB_CONTACT',
    section: 'family_history',
    text: 'Has the child had close contact with anyone with a chronic cough or tuberculosis?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_TB_CONTACT',
    priority: 696,
    applies: (context) => isPaediatric(context),
    options: booleanOptions(),
    reason: 'Household TB exposure is a key risk factor in child assessment.',
  },

  {
    questionCode: 'FAMILY_CONSANGUINITY',
    section: 'family_history',
    text: 'Are the parents related (consanguinity)?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_CONSANGUINITY',
    priority: 695,
    applies: (context) => isPaediatric(context),
    options: booleanOptions(),
    reason: 'Consanguinity increases the risk of recessive genetic conditions.',
  },

  {
    questionCode: 'FAMILY_SICKLE_CELL',
    section: 'family_history',
    text: 'Is there a family history of sickle cell disease or trait?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_SICKLE_CELL',
    priority: 694,
    applies: (context) => isPaediatric(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'FAMILY_HISTORY_PRESENT') === true,
    options: booleanOptions(),
  },

  {
    questionCode: 'FAMILY_SIBLING_DEATH',
    section: 'family_history',
    text: 'Have any siblings died, or had similar problems?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_SIBLING_DEATH',
    priority: 693,
    applies: (context) => isPaediatric(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'FAMILY_HISTORY_PRESENT') === true,
  },

  // ===========================================================================
  // SOCIAL HISTORY
  //
  // Hard age rules:
  //   - Marriage, alcohol, tobacco and recreation items are NEVER asked of
  //     children (age < 12 years).
  //   - School-age children get caregiver / schooling / home environment items.
  // ===========================================================================

  {
    questionCode: 'SOCIAL_LIVING',
    section: 'social_history',
    text: 'Who does the patient live with and what is the home environment like?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'LIVING_SITUATION',
    priority: 650,
  },

  {
    questionCode: 'SOCIAL_SUPPORT',
    section: 'social_history',
    text: 'Is adequate social or caregiver support available?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'SOCIAL_SUPPORT',
    priority: 640,
    options: [
      {
        answerCode: 'ADEQUATE',
        label: 'Adequate',
      },
      {
        answerCode: 'LIMITED',
        label: 'Limited',
      },
      {
        answerCode: 'NONE',
        label: 'None',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  // Adult-only items
  {
    questionCode: 'SOCIAL_MARITAL_STATUS',
    section: 'social_history',
    text: 'What is the marital status?',
    responseType: 'single_select',
    requirementLevel: 'optional',
    factCode: 'MARITAL_STATUS',
    priority: 639,
    applies: (context) => isAdolescentOrOlder(context),
    options: [
      { answerCode: 'SINGLE', label: 'Single' },
      { answerCode: 'MARRIED', label: 'Married' },
      { answerCode: 'DIVORCED', label: 'Divorced / separated' },
      { answerCode: 'WIDOWED', label: 'Widowed' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'SOCIAL_ALCOHOL',
    section: 'social_history',
    text: 'Does the patient drink alcohol?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'ALCOHOL_USE',
    priority: 638,
    applies: (context) => isAdult(context),
    options: [
      { answerCode: 'NONE', label: 'Never / none' },
      { answerCode: 'SOCIAL', label: 'Occasional / social' },
      { answerCode: 'REGULAR', label: 'Regular (daily or frequent)' },
      { answerCode: 'HEAVY', label: 'Heavy / binge' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'SOCIAL_ALCOHOL_DETAILS',
    section: 'social_history',
    text: 'Quantity and frequency of alcohol use (e.g. units per week).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ALCOHOL_DETAILS',
    priority: 637,
    applies: (context) => isAdult(context),
    visibleWhen: (_context, facts) => {
      const code = factValue(facts, 'ALCOHOL_USE')?.code;
      return (
        code === 'SOCIAL' ||
        code === 'REGULAR' ||
        code === 'HEAVY'
      );
    },
  },

  {
    questionCode: 'SOCIAL_SMOKING',
    section: 'social_history',
    text: 'Does the patient smoke tobacco?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'SMOKING_STATUS',
    priority: 636,
    applies: (context) => isAdolescentOrOlder(context),
    options: [
      { answerCode: 'NEVER', label: 'Never' },
      { answerCode: 'EX', label: 'Ex-smoker' },
      { answerCode: 'CURRENT', label: 'Current smoker' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'SOCIAL_SMOKING_DETAILS',
    section: 'social_history',
    text: 'Smoking history (e.g. pack-years, duration).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'SMOKING_DETAILS',
    priority: 635,
    applies: (context) => isAdolescentOrOlder(context),
    visibleWhen: (_context, facts) => {
      const code = factValue(facts, 'SMOKING_STATUS')?.code;
      return code === 'EX' || code === 'CURRENT';
    },
  },

  // Paediatric / school-age items
  {
    questionCode: 'SOCIAL_SCHOOL',
    section: 'social_history',
    text: 'Does the child attend school, and what is the school performance like?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'SCHOOL_ATTENDANCE',
    priority: 634,
    applies: (context) =>
      isPaediatric(context) && isSchoolAge(context),
  },

  {
    questionCode: 'SOCIAL_CAREGIVER',
    section: 'social_history',
    text: 'Who is the primary caregiver for the child?',
    responseType: 'free_text',
    requirementLevel: 'recommended',
    factCode: 'PRIMARY_CAREGIVER',
    priority: 633,
    applies: (context) => isPaediatric(context),
  },

  {
    questionCode: 'SOCIAL_HOME_SAFETY',
    section: 'social_history',
    text: 'Are there any home environment or safety concerns (crowding, water, sanitation, smoke exposure)?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'HOME_ENVIRONMENT_CONCERNS',
    priority: 632,
    applies: (context) => isPaediatric(context),
  },

  // Paediatric family/social detail (per the Paediatrics ward form section 9)
  {
    questionCode: 'PED_BIRTH_ORDER',
    section: 'social_history',
    text: 'What is the child’s birth order in the family?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'BIRTH_ORDER',
    priority: 631,
    unitCode: 'birth order',
    applies: (context) => isPaediatric(context),
    validation: {
      min: 1,
      max: 20,
      step: 1,
    },
  },

  {
    questionCode: 'PED_SIBLINGS',
    section: 'social_history',
    text: 'How many siblings does the child have (brothers and sisters), with their ages and school/occupation?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'SIBLING_DETAILS',
    priority: 630,
    applies: (context) => isPaediatric(context),
    placeholder: 'e.g. 2 brothers (8, 4 years) and 1 sister (10 years, in school).',
  },

  {
    questionCode: 'PED_PARENTS_MARITAL',
    section: 'social_history',
    text: 'Are both parents alive, and how long have they been married?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'PARENTS_MARITAL_STATUS',
    priority: 629,
    applies: (context) => isPaediatric(context),
    placeholder: 'e.g. Both parents alive, married for 12 years.',
  },

  {
    questionCode: 'PED_PARENTS_OCCUPATIONS',
    section: 'social_history',
    text: 'What are the mother’s and father’s ages and occupations?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'PARENTS_OCCUPATIONS',
    priority: 628,
    applies: (context) => isPaediatric(context),
    placeholder: 'e.g. Mother 34 years, teacher; father 40 years, farmer.',
  },

  {
    questionCode: 'PED_FAMILY_INCOME',
    section: 'social_history',
    text: 'What is the approximate cumulative family income, and are they beneficiaries of medical insurance?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'FAMILY_INCOME_INSURANCE',
    priority: 627,
    applies: (context) => isPaediatric(context),
  },

  {
    questionCode: 'PED_HOUSING',
    section: 'social_history',
    text: 'Describe the house (owned/rented, construction, number of windows and doors, who sleeps in the same bedroom).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'HOUSING_DETAILS',
    priority: 626,
    applies: (context) => isPaediatric(context),
  },

  {
    questionCode: 'PED_COOKING_WATER_SANITATION',
    section: 'social_history',
    text: 'What cooking fuel is used, is the kitchen separate, what is the water source, is water treated/boiled, and how is food stored?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'COOKING_WATER_SANITATION',
    priority: 625,
    applies: (context) => isPaediatric(context),
  },

  {
    questionCode: 'PED_LATRINES',
    section: 'social_history',
    text: 'What type of latrine is used, and how is it cleaned?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'LATRINE_DETAILS',
    priority: 624,
    applies: (context) => isPaediatric(context),
  },

  {
    questionCode: 'PED_HOUSEHOLD_SMOKING_ALCOHOL',
    section: 'social_history',
    text: 'Does anyone in the household smoke or take alcohol?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'HOUSEHOLD_SMOKING_ALCOHOL',
    priority: 623,
    applies: (context) => isPaediatric(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'PED_SIMILAR_SYMPTOMS_HOUSEHOLD',
    section: 'social_history',
    text: 'Is there anyone in the household with symptoms similar to the child’s?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'HOUSEHOLD_SIMILAR_SYMPTOMS',
    priority: 622,
    applies: (context) => isPaediatric(context),
    options: booleanOptions(),
  },

  // ===========================================================================
  // OCCUPATIONAL HISTORY
  // ===========================================================================

  {
    questionCode: 'OCCUPATION',
    section: 'occupational_history',
    text: 'What is the patient’s occupation or usual work?',
    responseType: 'free_text',
    requirementLevel: 'recommended',
    factCode: 'OCCUPATION',
    priority: 600,
    applies: (context) =>
      isAdult(context),
  },

  {
    questionCode: 'OCCUPATIONAL_EXPOSURE',
    section: 'occupational_history',
    text: 'Are there any important occupational, environmental, chemical, dust, radiation, or infectious exposures?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'OCCUPATIONAL_EXPOSURES',
    priority: 590,
    applies: (context) =>
      isAdult(context),
  },

  // ===========================================================================
  // REVIEW OF SYSTEMS
  //
  // One boolean probe per body system. A system already explored through the
  // chief complaints / HPI is NOT re-asked here (no contradictions, no
  // duplication). The visibleWhen guard consults the complaint vocabulary.
  // ===========================================================================

  {
    questionCode: 'ROS_GENERAL',
    section: 'review_of_systems',
    text: 'Are there any other general symptoms not yet captured (fever, chills, night sweats, weight change, fatigue, malaise)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ADDITIONAL_SYSTEM_SYMPTOMS',
    priority: 550,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'general'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_GENERAL_DETAILS',
    section: 'review_of_systems',
    text: 'Which additional general symptoms are present?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ADDITIONAL_SYSTEM_SYMPTOM_DETAILS',
    priority: 549,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'general') &&
      factBoolean(facts, 'ADDITIONAL_SYSTEM_SYMPTOMS') === true,
  },

  {
    questionCode: 'ROS_RESPIRATORY',
    section: 'review_of_systems',
    text: 'Any respiratory symptoms (cough, sputum, breathlessness, wheeze, blood in sputum)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_RESPIRATORY',
    priority: 548,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'respiratory'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_RESPIRATORY_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the respiratory symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_RESPIRATORY_DETAILS',
    priority: 547,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'respiratory') &&
      factBoolean(facts, 'ROS_RESPIRATORY') === true,
  },

  {
    questionCode: 'ROS_CARDIOVASCULAR',
    section: 'review_of_systems',
    text: 'Any cardiovascular symptoms (chest pain, palpitations, leg swelling, dizziness on standing)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_CARDIOVASCULAR',
    priority: 546,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'cardiovascular'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_CARDIOVASCULAR_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the cardiovascular symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_CARDIOVASCULAR_DETAILS',
    priority: 545,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'cardiovascular') &&
      factBoolean(facts, 'ROS_CARDIOVASCULAR') === true,
  },

  {
    questionCode: 'ROS_GASTROINTESTINAL',
    section: 'review_of_systems',
    text: 'Any gastrointestinal symptoms (abdominal pain, nausea, vomiting, diarrhoea, constipation, reflux, blood in stool)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_GASTROINTESTINAL',
    priority: 544,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'gastrointestinal'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_GASTROINTESTINAL_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the gastrointestinal symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_GASTROINTESTINAL_DETAILS',
    priority: 543,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'gastrointestinal') &&
      factBoolean(facts, 'ROS_GASTROINTESTINAL') === true,
  },

  {
    questionCode: 'ROS_NEUROLOGICAL',
    section: 'review_of_systems',
    text: 'Any neurological symptoms (headache, dizziness, weakness, numbness, fits, tremor, confusion)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_NEUROLOGICAL',
    priority: 542,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'neurological'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_NEUROLOGICAL_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the neurological symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_NEUROLOGICAL_DETAILS',
    priority: 541,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'neurological') &&
      factBoolean(facts, 'ROS_NEUROLOGICAL') === true,
  },

  {
    questionCode: 'ROS_MUSCULOSKELETAL',
    section: 'review_of_systems',
    text: 'Any musculoskeletal symptoms (joint pain, swelling, back pain, muscle pain)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_MUSCULOSKELETAL',
    priority: 540,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'musculoskeletal'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_MUSCULOSKELETAL_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the musculoskeletal symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_MUSCULOSKELETAL_DETAILS',
    priority: 539,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'musculoskeletal') &&
      factBoolean(facts, 'ROS_MUSCULOSKELETAL') === true,
  },

  {
    questionCode: 'ROS_GENITOURINARY',
    section: 'review_of_systems',
    text: 'Any genitourinary symptoms (painful urination, frequency, blood in urine, discharge)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_GENITOURINARY',
    priority: 538,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'genitourinary'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_GENITOURINARY_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the genitourinary symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_GENITOURINARY_DETAILS',
    priority: 537,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'genitourinary') &&
      factBoolean(facts, 'ROS_GENITOURINARY') === true,
  },

  {
    questionCode: 'ROS_DERMATOLOGICAL',
    section: 'review_of_systems',
    text: 'Any skin symptoms (rash, itching, lesions, hair loss)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_DERMATOLOGICAL',
    priority: 536,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'dermatological'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_DERMATOLOGICAL_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the skin symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_DERMATOLOGICAL_DETAILS',
    priority: 535,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'dermatological') &&
      factBoolean(facts, 'ROS_DERMATOLOGICAL') === true,
  },

  {
    questionCode: 'ROS_HEAD_ENT',
    section: 'review_of_systems',
    text: 'Any head, ear, nose or throat symptoms (sore throat, ear pain, hearing loss, toothache)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_HEAD_ENT',
    priority: 534,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'head_ent'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_HEAD_ENT_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the head, ear, nose or throat symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_HEAD_ENT_DETAILS',
    priority: 533,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'head_ent') &&
      factBoolean(facts, 'ROS_HEAD_ENT') === true,
  },

  {
    questionCode: 'ROS_OPHTHALMOLOGICAL',
    section: 'review_of_systems',
    text: 'Any eye symptoms (redness, pain, discharge, blurred vision)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_OPHTHALMOLOGICAL',
    priority: 532,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'ophthalmological'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_OPHTHALMOLOGICAL_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the eye symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_OPHTHALMOLOGICAL_DETAILS',
    priority: 531,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'ophthalmological') &&
      factBoolean(facts, 'ROS_OPHTHALMOLOGICAL') === true,
  },

  {
    questionCode: 'ROS_ENDOCRINE',
    section: 'review_of_systems',
    text: 'Any endocrine symptoms (excessive thirst, heat/cold intolerance, weight change)?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_ENDOCRINE',
    priority: 530,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'endocrine'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_ENDOCRINE_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the endocrine symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_ENDOCRINE_DETAILS',
    priority: 529,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'endocrine') &&
      factBoolean(facts, 'ROS_ENDOCRINE') === true,
  },

  {
    questionCode: 'ROS_PSYCHIATRIC',
    section: 'review_of_systems',
    text: 'Any mood, sleep, anxiety or psychiatric symptoms?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_PSYCHIATRIC',
    priority: 528,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'psychiatric'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_PSYCHIATRIC_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the mood or psychiatric symptoms.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_PSYCHIATRIC_DETAILS',
    priority: 527,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'psychiatric') &&
      factBoolean(facts, 'ROS_PSYCHIATRIC') === true,
  },

  {
    questionCode: 'ROS_HAEMATOLOGICAL',
    section: 'review_of_systems',
    text: 'Any bleeding, easy bruising or pallor?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_HAEMATOLOGICAL',
    priority: 526,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'haematological'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_HAEMATOLOGICAL_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the bleeding, bruising or pallor.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_HAEMATOLOGICAL_DETAILS',
    priority: 525,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'haematological') &&
      factBoolean(facts, 'ROS_HAEMATOLOGICAL') === true,
  },

  {
    questionCode: 'ROS_LYMPHATIC',
    section: 'review_of_systems',
    text: 'Any swollen glands or lymph node enlargement?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'ROS_LYMPHATIC',
    priority: 524,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'lymphatic'),
    options: booleanOptions(),
  },

  {
    questionCode: 'ROS_LYMPHATIC_DETAILS',
    section: 'review_of_systems',
    text: 'Describe the swollen glands or lymph node findings.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ROS_LYMPHATIC_DETAILS',
    priority: 523,
    visibleWhen: (_context, facts) =>
      systemNotCovered(facts, 'lymphatic') &&
      factBoolean(facts, 'ROS_LYMPHATIC') === true,
  },

  // ===========================================================================
  // FEMALE REPRODUCTIVE HISTORY
  // ===========================================================================

  {
    questionCode: 'GYN_MENARCHE',
    section: 'gynaecological_history',
    text: 'At what age did menstruation begin (menarche)?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'MENARCHE_AGE',
    priority: 625,
    unitCode: 'years',
    applies: (context) =>
      isFemaleReproductiveAge(context),
    validation: {
      min: 8,
      max: 20,
      step: 0.1,
    },
  },

  {
    questionCode: 'GYN_LMP',
    section: 'gynaecological_history',
    text: 'When was the first day of the last menstrual period?',
    responseType: 'date',
    requirementLevel: 'conditional',
    factCode: 'LMP_DATE',
    priority: 620,
    applies: (context) =>
      isFemaleReproductiveAge(context) &&
      context.pregnancyState !== 'pregnant',
  },

  {
    questionCode: 'GYN_CYCLE',
    section: 'gynaecological_history',
    text: 'What is the usual menstrual cycle pattern (regularity, duration, interval)?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'MENSTRUAL_PATTERN',
    priority: 610,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    placeholder: 'e.g. Regular 28-day cycles, 4–5 days of flow.',
  },

  {
    questionCode: 'GYN_MENSTRUAL_PROBLEM',
    section: 'gynaecological_history',
    text: 'Are there any significant menstrual problems (dysmenorrhoea, menorrhagia, irregularity, intermenstrual bleeding)?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'MENSTRUAL_PROBLEM_PRESENT',
    priority: 600,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'GYN_MENSTRUAL_PROBLEM_DETAILS',
    section: 'gynaecological_history',
    text: 'Describe the menstrual problems in detail.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'MENSTRUAL_PROBLEM_DETAILS',
    priority: 599,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'MENSTRUAL_PROBLEM_PRESENT') === true,
  },

  {
    questionCode: 'GYN_POSTMENOPAUSAL',
    section: 'gynaecological_history',
    text: 'Has the patient reached menopause?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'MENOPAUSAL_STATUS',
    priority: 598,
    applies: (context) =>
      context.sex === 'female' &&
      context.ageYears != null &&
      context.ageYears > 45,
    options: booleanOptions(),
  },

  {
    questionCode: 'GYN_POSTMENOPAUSAL_YEARS',
    section: 'gynaecological_history',
    text: 'How many years has the patient been post-menopausal?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'POSTMENOPAUSAL_YEARS',
    priority: 597,
    unitCode: 'years',
    applies: (context) =>
      context.sex === 'female' &&
      context.ageYears != null &&
      context.ageYears > 45,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'MENOPAUSAL_STATUS') === true,
    validation: {
      min: 0,
      max: 50,
      step: 0.5,
    },
  },

  {
    questionCode: 'GYN_POSTMENOPAUSAL_BLEEDING',
    section: 'gynaecological_history',
    text: 'Is there any postmenopausal bleeding?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'POSTMENOPAUSAL_BLEEDING',
    priority: 596,
    applies: (context) =>
      context.sex === 'female' &&
      context.ageYears != null &&
      context.ageYears > 45,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'MENOPAUSAL_STATUS') === true,
    options: booleanOptions(),
    reason: 'Postmenopausal bleeding is investigated as a possible malignancy.',
  },

  {
    questionCode: 'GYN_CONTRACEPTION',
    section: 'gynaecological_history',
    text: 'Does the patient use any method of contraception?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'CONTRACEPTION_USE',
    priority: 595,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'GYN_CONTRACEPTION_DETAILS',
    section: 'gynaecological_history',
    text: 'Which contraceptive method is used?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'CONTRACEPTION_DETAILS',
    priority: 596,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'CONTRACEPTION_USE') === true,
  },

  {
    questionCode: 'GYN_CONTRACEPTION_SIDE_EFFECTS',
    section: 'gynaecological_history',
    text: 'Are there any side effects from the contraceptive method used?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'CONTRACEPTION_SIDE_EFFECTS',
    priority: 595,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'CONTRACEPTION_USE') === true,
    placeholder: 'e.g. Intermenstrual spotting, weight gain, headaches.',
  },

  {
    questionCode: 'GYN_MENSTRUAL_FLOW_DETAILS',
    section: 'gynaecological_history',
    text: 'Describe the menstrual flow (number of pads per day, whether pads are fully soaked, any heavy bleeding).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'MENSTRUAL_FLOW_DETAILS',
    priority: 594,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    placeholder: 'e.g. Uses 3 pads per day which are not fully soaked.',
  },

  {
    questionCode: 'GYN_DYSPAREUNIA',
    section: 'gynaecological_history',
    text: 'Is there any pain during sexual intercourse (dyspareunia)?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'DYSPAREUNIA',
    priority: 593,
    applies: (context) =>
      isFemaleReproductiveAge(context) &&
      isAdolescentOrOlder(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'GYN_POSTCOITAL_BLEEDING',
    section: 'gynaecological_history',
    text: 'Is there any post-coital (bleeding after intercourse) bleeding?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'POSTCOITAL_BLEEDING',
    priority: 592,
    applies: (context) =>
      isFemaleReproductiveAge(context) &&
      isAdolescentOrOlder(context),
    options: booleanOptions(),
    reason: 'Post-coital bleeding is a classic presentation of cervical pathology.',
  },

  {
    questionCode: 'GYN_SEXUAL_DEBUT',
    section: 'gynaecological_history',
    text: 'At what age did sexual activity begin (sexual debut)?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'SEXUAL_DEBUT_AGE',
    priority: 591,
    unitCode: 'years',
    applies: (context) =>
      isFemaleReproductiveAge(context) &&
      isAdolescentOrOlder(context),
    validation: {
      min: 10,
      max: 60,
      step: 1,
    },
  },

  {
    questionCode: 'GYN_CANCER_SCREENING',
    section: 'gynaecological_history',
    text: 'Has the patient undergone breast or cervical cancer screening (e.g. Pap smear, VIA, clinical breast exam)?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'CANCER_SCREENING_HISTORY',
    priority: 590,
    applies: (context) =>
      isFemaleReproductiveAge(context) &&
      isAdolescentOrOlder(context),
    placeholder: 'e.g. Pap smear 2 years ago — normal.',
  },

  {
    questionCode: 'GYN_STD_HISTORY',
    section: 'gynaecological_history',
    text: 'Is there any history of sexually transmitted infections?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'STD_HISTORY',
    priority: 589,
    applies: (context) =>
      isFemaleReproductiveAge(context) &&
      isAdolescentOrOlder(context),
    placeholder: 'e.g. Treated for syphilis in 2020.',
  },

  {
    questionCode: 'GYN_TREATMENTS_OPS',
    section: 'gynaecological_history',
    text: 'Is there any history of gynaecological treatments or operations?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'GYNAECOLOGICAL_TREATMENTS',
    priority: 588,
    applies: (context) =>
      isFemaleReproductiveAge(context),
    placeholder: 'e.g. D&C for evacuation 2019; treated for fibroids.',
  },

  // ===========================================================================
  // SEXUAL HISTORY
  // ===========================================================================

  {
    questionCode: 'SEXUAL_HISTORY_RELEVANT',
    section: 'sexual_history',
    text: 'Is there any sexual or reproductive history relevant to the current presentation?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'SEXUAL_HISTORY_RELEVANT',
    priority: 580,
    applies: (context) =>
      (isFemaleReproductiveAge(context) ||
        context.department === 'obgyn' ||
        context.department === 'medical' ||
        context.department === 'emergency') &&
      isAdolescentOrOlder(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'SEXUAL_HISTORY_DETAILS',
    section: 'sexual_history',
    text: 'Record the relevant sexual or reproductive history.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'SEXUAL_HISTORY_DETAILS',
    priority: 579,
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'SEXUAL_HISTORY_RELEVANT') === true,
  },

  // ===========================================================================
  // OBSTETRIC / ANC
  // ===========================================================================

  {
    questionCode: 'OBGYN_PREGNANCY',
    section: 'anc_profile',
    text: 'Is the patient currently pregnant?',
    responseType: 'boolean',
    requirementLevel: 'mandatory',
    factCode: 'PREGNANCY_STATUS',
    priority: 900,
    applies: (context) =>
      context.sex === 'female' &&
      context.department === 'obgyn',
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_LMP',
    section: 'anc_profile',
    text: 'What was the first day of the last menstrual period?',
    responseType: 'date',
    requirementLevel: 'conditional',
    factCode: 'LMP_DATE',
    priority: 890,
    applies: (context) =>
      isPregnant(context),
  },

  {
    questionCode: 'ANC_GESTATIONAL_AGE',
    section: 'anc_profile',
    text: 'What is the current gestational age?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'GESTATIONAL_AGE',
    unitCode: 'weeks',
    priority: 880,
    applies: (context) =>
      isPregnant(context),
    validation: {
      min: 0,
      max: 45,
      step: 0.1,
    },
  },

  {
    questionCode: 'ANC_EDD',
    section: 'anc_profile',
    text: 'What is the expected date of delivery (EDD)?',
    responseType: 'date',
    requirementLevel: 'conditional',
    factCode: 'EDD',
    priority: 875,
    applies: (context) =>
      isPregnant(context),
  },

  {
    questionCode: 'ANC_ANTENATAL_CARE',
    section: 'anc_profile',
    text: 'Has the patient received antenatal care during this pregnancy?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'ANC_RECEIVED',
    priority: 870,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_VISITS',
    section: 'anc_profile',
    text: 'How many antenatal visits have been attended?',
    responseType: 'numeric',
    requirementLevel: 'conditional',
    factCode: 'ANC_VISITS',
    priority: 869,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    validation: {
      min: 0,
      step: 1,
    },
  },

  {
    questionCode: 'ANC_COMPLICATIONS',
    section: 'anc_profile',
    text: 'Have there been any complications or significant findings during this pregnancy (bleeding, hypertension, diabetes, infections)?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'CURRENT_PREGNANCY_COMPLICATIONS',
    priority: 860,
    applies: (context) =>
      isPregnant(context),
  },

  {
    questionCode: 'ANC_TETANUS',
    section: 'anc_profile',
    text: 'Is the tetanus toxoid immunization up to date for pregnancy?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_TETANUS_STATUS',
    priority: 855,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_SUPPLEMENTS',
    section: 'anc_profile',
    text: 'Is the patient taking iron, folate or calcium supplementation?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_SUPPLEMENT_USE',
    priority: 850,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
  },

  // ===========================================================================
  // ANC PROFILE — "8 THINGS YOU MUST ASK A PREGNANT WOMAN"
  //
  // Per the Obstetrics & Gynaecology ward form, every pregnant patient is asked
  // about: lower abdominal pain, lower back pain, leakage of blood per vagina,
  // sudden gush of liquid, vaginal discharge, perception of fetal movement,
  // headaches and blurring of vision. Each is captured as an individual fact so
  // the ANC profile can be documented thoroughly.
  // ===========================================================================

  {
    questionCode: 'ANC_8_LOWER_ABDO_PAIN',
    section: 'anc_profile',
    text: 'Does the patient have lower abdominal pain?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_LOWER_ABDOMINAL_PAIN',
    priority: 848,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_8_LOWER_BACK_PAIN',
    section: 'anc_profile',
    text: 'Does the patient have lower back pain?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_LOWER_BACK_PAIN',
    priority: 847,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_8_PV_BLEEDING',
    section: 'anc_profile',
    text: 'Is there any leakage of blood per vagina?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_PV_BLEEDING',
    priority: 846,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
    reason: 'PV bleeding is a key danger sign in pregnancy.',
  },

  {
    questionCode: 'ANC_8_SUDDEN_GUSH',
    section: 'anc_profile',
    text: 'Has there been a sudden gush of liquid from the vagina (suggesting membrane rupture)?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_SUDDEN_GUSH_LIQUID',
    priority: 845,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
    reason: 'Sudden gush of fluid suggests premature rupture of membranes.',
  },

  {
    questionCode: 'ANC_8_VAGINAL_DISCHARGE',
    section: 'anc_profile',
    text: 'Is there any abnormal vaginal discharge?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_VAGINAL_DISCHARGE',
    priority: 844,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_8_FETAL_MOVEMENT',
    section: 'anc_profile',
    text: 'Is the patient perceiving fetal movement?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_FETAL_MOVEMENT',
    priority: 843,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
    reason: 'Reduced fetal movements are a recognised fetal compromise warning.',
  },

  {
    questionCode: 'ANC_8_HEADACHE',
    section: 'anc_profile',
    text: 'Does the patient have headaches?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_HEADACHE',
    priority: 842,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
    reason: 'Headache is one of the warning signs of pre-eclampsia.',
  },

  {
    questionCode: 'ANC_8_BLURRED_VISION',
    section: 'anc_profile',
    text: 'Does the patient have blurring of vision?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_BLURRED_VISION',
    priority: 841,
    applies: (context) =>
      isPregnant(context),
    options: booleanOptions(),
    reason: 'Blurred vision is a warning sign of pre-eclampsia.',
  },

  // ===========================================================================
  // ANC PROFILE — FULL PROFILE DETAIL
  //
  // "Copy smart from the ANC book, and report it as if the patient told you."
  // First-visit details, blood group, Hb adequacy, urine test, HIV/VDRL
  // markers, Hepatitis B and TB screening, tetanus toxoid, deworming, blood
  // pressure, ultrasound scans, supplements and acute illness/medication use.
  // ===========================================================================

  {
    questionCode: 'ANC_FIRST_VISIT',
    section: 'anc_profile',
    text: 'When was the first ANC visit (date or gestational age at the time)?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ANC_FIRST_VISIT_DETAILS',
    priority: 840,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    placeholder: 'e.g. First visit at 16 weeks gestational age by dates.',
  },

  {
    questionCode: 'ANC_BLOOD_GROUP',
    section: 'anc_profile',
    text: 'What is the patient’s blood group (if known from antenatal tests)?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_BLOOD_GROUP',
    priority: 839,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: [
      { answerCode: 'A_POS', label: 'A positive' },
      { answerCode: 'A_NEG', label: 'A negative' },
      { answerCode: 'B_POS', label: 'B positive' },
      { answerCode: 'B_NEG', label: 'B negative' },
      { answerCode: 'AB_POS', label: 'AB positive' },
      { answerCode: 'AB_NEG', label: 'AB negative' },
      { answerCode: 'O_POS', label: 'O positive' },
      { answerCode: 'O_NEG', label: 'O negative' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'ANC_HB_STATUS',
    section: 'anc_profile',
    text: 'Was the blood (haemoglobin) level reported as adequate or inadequate?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_HB_STATUS',
    priority: 838,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: [
      { answerCode: 'ADEQUATE', label: 'Adequate' },
      { answerCode: 'INADEQUATE', label: 'Inadequate (low)' },
      { answerCode: 'NOT_DONE', label: 'Not done / not told' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'ANC_URINE_TEST',
    section: 'anc_profile',
    text: 'Was the antenatal urinary test reported as normal?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_URINE_TEST_NORMAL',
    priority: 837,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_HIV_STATUS',
    section: 'anc_profile',
    text: 'What was the antenatal HIV (P24 / rapid test) result?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_HIV_RESULT',
    priority: 836,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: [
      { answerCode: 'NEGATIVE', label: 'Negative' },
      { answerCode: 'POSITIVE', label: 'Positive' },
      { answerCode: 'NOT_DONE', label: 'Not done' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'ANC_VDRL_STATUS',
    section: 'anc_profile',
    text: 'What was the antenatal VDRL (syphilis) test result?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_VDRL_RESULT',
    priority: 835,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: [
      { answerCode: 'NEGATIVE', label: 'Negative' },
      { answerCode: 'POSITIVE', label: 'Positive' },
      { answerCode: 'NOT_DONE', label: 'Not done' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'ANC_HEPATITIS_B_SCREEN',
    section: 'anc_profile',
    text: 'Was Hepatitis B screening done, and what was the result?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_HEPATITIS_B_RESULT',
    priority: 834,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: [
      { answerCode: 'NEGATIVE', label: 'Negative' },
      { answerCode: 'POSITIVE', label: 'Positive' },
      { answerCode: 'NOT_DONE', label: 'Not done' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'ANC_TB_SCREEN',
    section: 'anc_profile',
    text: 'Was TB screening done during this pregnancy?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_TB_SCREENING',
    priority: 833,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: [
      { answerCode: 'DONE_NORMAL', label: 'Done — normal' },
      { answerCode: 'DONE_ABNORMAL', label: 'Done — abnormal / further review' },
      { answerCode: 'NOT_DONE', label: 'Not done' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'ANC_DEWORMING',
    section: 'anc_profile',
    text: 'Was the patient dewormed during the second trimester?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_DEWORMING',
    priority: 832,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_BP_STATUS',
    section: 'anc_profile',
    text: 'Was the blood pressure recorded as normal at antenatal visits?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'ANC_BP_NORMAL',
    priority: 831,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    options: booleanOptions(),
  },

  {
    questionCode: 'ANC_ULTRASOUND',
    section: 'anc_profile',
    text: 'How many ultrasound scans were done, at which gestational ages, and what were the findings?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ANC_ULTRASOUND_DETAILS',
    priority: 830,
    applies: (context) =>
      isPregnant(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'ANC_RECEIVED') === true,
    placeholder: 'e.g. Two scans at 20 and 32 weeks; reported normal (single baby).',
  },

  {
    questionCode: 'ANC_ACUTE_ILLNESS',
    section: 'anc_profile',
    text: 'Were there any acute illnesses during this pregnancy?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ANC_ACUTE_ILLNESSES',
    priority: 829,
    applies: (context) =>
      isPregnant(context),
    placeholder: 'e.g. Malaria at 24 weeks; treated and resolved.',
  },

  {
    questionCode: 'ANC_MEDICATION_USE',
    section: 'anc_profile',
    text: 'Has the patient used any medication during this pregnancy?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'ANC_MEDICATION_USE',
    priority: 828,
    applies: (context) =>
      isPregnant(context),
  },

  {
    questionCode: 'ANC_MALARIA_PROPHYLAXIS',
    section: 'anc_profile',
    text: 'Is the patient using malarial prophylaxis (IPT) and/or a long-lasting insecticide-treated net (LLIN)?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'ANC_MALARIA_PROPHYLAXIS',
    priority: 827,
    applies: (context) =>
      isPregnant(context),
    options: [
      { answerCode: 'IPT_AND_LLIN', label: 'IPT and LLIN' },
      { answerCode: 'IPT_ONLY', label: 'IPT only' },
      { answerCode: 'LLIN_ONLY', label: 'LLIN only' },
      { answerCode: 'NONE', label: 'None' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  // ===========================================================================
  // OBSTETRIC HISTORY
  // ===========================================================================

  {
    questionCode: 'OB_GRAVIDA',
    section: 'obstetric_history',
    text: 'How many times has the patient been pregnant (including current, if applicable)?',
    responseType: 'numeric',
    requirementLevel: 'recommended',
    factCode: 'GRAVIDA',
    priority: 850,
    applies: (context) =>
      context.sex === 'female' &&
      (context.department === 'obgyn' || isPregnant(context)) &&
      isAdolescentOrOlder(context),
    validation: {
      min: 0,
      step: 1,
    },
  },

  {
    questionCode: 'OB_PARA',
    section: 'obstetric_history',
    text: 'How many deliveries have reached the age of viability (para)?',
    responseType: 'numeric',
    requirementLevel: 'recommended',
    factCode: 'PARA',
    priority: 849,
    applies: (context) =>
      context.sex === 'female' &&
      (context.department === 'obgyn' || isPregnant(context)) &&
      isAdolescentOrOlder(context),
    validation: {
      min: 0,
      step: 1,
    },
  },

  {
    questionCode: 'OB_ABORTIONS',
    section: 'obstetric_history',
    text: 'How many abortions or miscarriages have there been?',
    responseType: 'numeric',
    requirementLevel: 'conditional',
    factCode: 'ABORTIONS',
    priority: 848,
    applies: (context) =>
      context.sex === 'female' &&
      (context.department === 'obgyn' || isPregnant(context)) &&
      isAdolescentOrOlder(context),
    validation: {
      min: 0,
      step: 1,
    },
  },

  {
    questionCode: 'OB_LIVING_CHILDREN',
    section: 'obstetric_history',
    text: 'How many living children does the patient have?',
    responseType: 'numeric',
    requirementLevel: 'conditional',
    factCode: 'LIVING_CHILDREN',
    priority: 847,
    applies: (context) =>
      context.sex === 'female' &&
      (context.department === 'obgyn' || isPregnant(context)) &&
      isAdolescentOrOlder(context),
    validation: {
      min: 0,
      step: 1,
    },
  },

  {
    questionCode: 'OB_PREVIOUS_OUTCOMES',
    section: 'obstetric_history',
    text: 'What were the outcomes of previous pregnancies (mode of delivery, complications, birth weights)?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'PREVIOUS_PREGNANCY_OUTCOMES',
    priority: 840,
    applies: (context) =>
      context.sex === 'female' &&
      (context.department === 'obgyn' || isPregnant(context)) &&
      isAdolescentOrOlder(context),
  },

  {
    questionCode: 'OB_PREVIOUS_CS',
    section: 'obstetric_history',
    text: 'Has the patient had a previous caesarean section?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'PREVIOUS_CAESAREAN',
    priority: 839,
    applies: (context) =>
      context.sex === 'female' &&
      (context.department === 'obgyn' || isPregnant(context)) &&
      isAdolescentOrOlder(context),
    options: booleanOptions(),
  },

  // ===========================================================================
  // PAEDIATRIC — BIRTH HISTORY
  //
  // Relevant to all paediatric life stages (neonate, infant, child), not just
  // the neonatal period, because birth details inform ongoing care.
  // ===========================================================================

  {
    questionCode: 'BIRTH_PLACE',
    section: 'birth_history',
    text: 'Where was the child delivered?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'BIRTH_PLACE',
    priority: 810,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: [
      { answerCode: 'HOSPITAL', label: 'Hospital' },
      { answerCode: 'HEALTH_CENTRE', label: 'Health centre' },
      { answerCode: 'HOME', label: 'Home' },
      { answerCode: 'OTHER', label: 'Other' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'BIRTH_MODE',
    section: 'birth_history',
    text: 'How was the child delivered?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'BIRTH_MODE',
    priority: 800,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: [
      {
        answerCode: 'SVD',
        label: 'Spontaneous vaginal delivery',
      },
      {
        answerCode: 'ASSISTED',
        label: 'Assisted vaginal delivery',
      },
      {
        answerCode: 'CS',
        label: 'Caesarean section',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  {
    questionCode: 'BIRTH_WEIGHT',
    section: 'birth_history',
    text: 'What was the birth weight?',
    responseType: 'measurement',
    requirementLevel: 'recommended',
    factCode: 'BIRTH_WEIGHT',
    priority: 799,
    unitCode: 'kg',
    applies: (context) => isPaediatric(context) && !isAdult(context),
    validation: {
      min: 0.4,
      max: 6,
      step: 0.01,
    },
  },

  {
    questionCode: 'BIRTH_GESTATIONAL_AGE',
    section: 'birth_history',
    text: 'What was the gestational age at birth (weeks)?',
    responseType: 'measurement',
    requirementLevel: 'recommended',
    factCode: 'BIRTH_GESTATIONAL_AGE',
    priority: 798,
    unitCode: 'weeks',
    applies: (context) => isPaediatric(context) && !isAdult(context),
    validation: {
      min: 24,
      max: 44,
      step: 0.1,
    },
  },

  {
    questionCode: 'BIRTH_COMPLICATIONS',
    section: 'birth_history',
    text: 'Were there any complications during labour, delivery, or immediately after birth?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'BIRTH_COMPLICATIONS',
    priority: 790,
    applies: (context) => isPaediatric(context) && !isAdult(context),
  },

  {
    questionCode: 'BIRTH_RESUSCITATION',
    section: 'birth_history',
    text: 'Did the child require resuscitation or significant support immediately after birth?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'BIRTH_RESUSCITATION',
    priority: 780,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'BIRTH_CRIED_IMMEDIATELY',
    section: 'birth_history',
    text: 'Did the baby cry immediately after birth?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'BIRTH_CRIED_IMMEDIATELY',
    priority: 779,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
    reason: 'Crying at birth is a key indicator of good birth condition (per natal history).',
  },

  {
    questionCode: 'BIRTH_BREASTFED_EARLY',
    section: 'birth_history',
    text: 'Was the baby breastfed immediately, or within 30 minutes of birth?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'BIRTH_BREASTFED_EARLY',
    priority: 778,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
    reason: 'Early initiation of breastfeeding is documented in natal history.',
  },

  {
    questionCode: 'BIRTH_NICU_ADMISSION',
    section: 'birth_history',
    text: 'Was the baby admitted to the newborn unit (NICU) after birth?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'BIRTH_NICU_ADMISSION',
    priority: 777,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'BIRTH_POSTNATAL_ILLNESS',
    section: 'birth_history',
    text: 'Were there any illnesses during the immediate neonatal (postnatal) period?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'BIRTH_POSTNATAL_ILLNESS',
    priority: 776,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    placeholder: 'e.g. Neonatal jaundice in first week; resolved.',
  },

  // ===========================================================================
  // PAEDIATRIC — MATERNAL / ANTENATAL HISTORY
  // ===========================================================================

  {
    questionCode: 'MAT_ANTENATAL_CARE',
    section: 'birth_history',
    text: 'Did the mother attend antenatal care during this pregnancy?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'MATERNAL_ANC_ATTENDANCE',
    priority: 770,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'MAT_ILLNESSES',
    section: 'birth_history',
    text: 'Did the mother have any illness during pregnancy (hypertension, diabetes, malaria, infections)?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'MATERNAL_ILLNESSES',
    priority: 760,
    applies: (context) => isPaediatric(context) && !isAdult(context),
  },

  {
    questionCode: 'MAT_HIV_STATUS',
    section: 'birth_history',
    text: 'What is the mother’s HIV status?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'MATERNAL_HIV_STATUS',
    priority: 750,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    options: [
      { answerCode: 'NEGATIVE', label: 'Negative' },
      { answerCode: 'POSITIVE', label: 'Positive' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'MAT_DRUGS',
    section: 'birth_history',
    text: 'Did the mother take any regular medication, smoke, drink alcohol, or have radiation exposure during pregnancy?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'MATERNAL_DRUGS',
    priority: 740,
    applies: (context) => isPaediatric(context) && !isAdult(context),
  },

  {
    questionCode: 'MAT_MATERNAL_ANC_PROFILE',
    section: 'birth_history',
    text: 'Record the maternal antenatal profile (blood group, Hb adequacy, HIV/VDRL tests, urine test, scans, tetanus toxoid, iron/folate supplements).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'MATERNAL_ANC_PROFILE',
    priority: 739,
    applies: (context) => isPaediatric(context) && !isAdult(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'MATERNAL_ANC_ATTENDANCE') === true,
    placeholder: 'e.g. Blood group O+, Hb adequate, HIV and VDRL negative, scans normal, tetanus toxoid given, iron and folate taken.',
  },

  // ===========================================================================
  // PAEDIATRIC — GROWTH & DEVELOPMENT
  //
  // Age-appropriate milestones are generated dynamically for the child's age
  // window (see buildMilestoneQuestions below). The two questions here capture
  // the global status and any parental concern.
  // ===========================================================================

  {
    questionCode: 'PED_DEVELOPMENT',
    section: 'growth_development',
    text: 'Overall, has the child been meeting expected developmental milestones?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'DEVELOPMENTAL_STATUS',
    priority: 830,
    applies: (context) =>
      isPaediatric(context) && !isNeonate(context),
    options: [
      {
        answerCode: 'APPROPRIATE',
        label: 'Appropriate for age',
      },
      {
        answerCode: 'DELAYED',
        label: 'Possible delay',
      },
      {
        answerCode: 'REGRESSION',
        label: 'Loss of previously acquired skills',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  {
    questionCode: 'PED_DEVELOPMENT_CONCERNS',
    section: 'growth_development',
    text: 'Are there any specific developmental concerns raised by the caregiver?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'DEVELOPMENTAL_CONCERNS',
    priority: 829,
    applies: (context) =>
      isPaediatric(context) && !isNeonate(context),
  },

  // ===========================================================================
  // PAEDIATRIC — IMMUNIZATION
  // ===========================================================================

  {
    questionCode: 'PED_IMMUNIZATION',
    section: 'immunization',
    text: 'Are the child’s immunizations up to date according to the applicable schedule?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'IMMUNIZATION_STATUS',
    priority: 820,
    applies: (context) =>
      isPaediatric(context),
    options: [
      {
        answerCode: 'UP_TO_DATE',
        label: 'Up to date',
      },
      {
        answerCode: 'INCOMPLETE',
        label: 'Incomplete',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  {
    questionCode: 'PED_IMMUNIZATION_DETAILS',
    section: 'immunization',
    text: 'Which vaccines are missing or overdue?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'IMMUNIZATION_DETAILS',
    priority: 819,
    applies: (context) =>
      isPaediatric(context),
    visibleWhen: (_context, facts) =>
      factValue(facts, 'IMMUNIZATION_STATUS')?.code === 'INCOMPLETE',
  },

  {
    questionCode: 'PED_IMMUNIZATION_NEXT',
    section: 'immunization',
    text: 'Which is the next vaccine due, and when is it scheduled?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'IMMUNIZATION_NEXT_VACCINE',
    priority: 818,
    applies: (context) =>
      isPaediatric(context),
    visibleWhen: (_context, facts) =>
      factValue(facts, 'IMMUNIZATION_STATUS')?.code !== 'INCOMPLETE',
    placeholder: 'e.g. Measles-rubella vaccine scheduled at 9 months.',
    reason: 'The KDVI schedule records the next due vaccine and date.',
  },

  // ===========================================================================
  // PAEDIATRIC — NUTRITION
  // ===========================================================================

  {
    questionCode: 'PED_FEEDING',
    section: 'nutrition',
    text: 'How is the child feeding compared with usual?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'FEEDING_STATUS',
    priority: 850,
    applies: (context) =>
      isPaediatric(context),
    options: [
      {
        answerCode: 'NORMAL',
        label: 'Normal',
      },
      {
        answerCode: 'REDUCED',
        label: 'Reduced',
      },
      {
        answerCode: 'UNABLE',
        label: 'Unable to feed',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  {
    questionCode: 'PED_BREASTFEEDING',
    section: 'nutrition',
    text: 'How is the child currently fed (breastfeeding, formula, mixed)?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'FEEDING_METHOD',
    priority: 845,
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    options: [
      { answerCode: 'EXCLUSIVE_BREAST', label: 'Exclusive breastfeeding' },
      { answerCode: 'MIXED', label: 'Mixed (breast + formula/complementary)' },
      { answerCode: 'FORMULA', label: 'Formula feeding' },
      { answerCode: 'COMPLEMENTARY', label: 'Complementary / family diet' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'PED_NUTRITIONAL_CHANGE',
    section: 'nutrition',
    text: 'Has there been a recent change in appetite, feeding pattern, or nutritional intake?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'RECENT_NUTRITION_CHANGE',
    priority: 840,
    applies: (context) =>
      isPaediatric(context),
  },

  {
    questionCode: 'PED_EBF_DURATION',
    section: 'nutrition',
    text: 'For how many months was the child exclusively breastfed?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'EXCLUSIVE_BREASTFEEDING_MONTHS',
    priority: 839,
    unitCode: 'months',
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    validation: {
      min: 0,
      max: 24,
      step: 0.5,
    },
    placeholder: 'e.g. 6',
  },

  {
    questionCode: 'PED_COMPLEMENTARY_AGE',
    section: 'nutrition',
    text: 'At how many months was complementary (weaning) food introduced?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'COMPLEMENTARY_FEEDING_MONTHS',
    priority: 838,
    unitCode: 'months',
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    validation: {
      min: 0,
      max: 24,
      step: 0.5,
    },
  },

  {
    questionCode: 'PED_FEED_CONTENT',
    section: 'nutrition',
    text: 'What does the feed contain, how much is given, and how often (every how many hours)?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'FEED_CONTENT_DETAILS',
    priority: 837,
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    placeholder: 'e.g. Porridge with milk, about 250 ml, every 4 hours; breastfed on demand until satisfaction.',
  },

  {
    questionCode: 'PED_RETAINS_FEED',
    section: 'nutrition',
    text: 'Does the baby retain feeds (no vomiting after feeding)?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'RETAINS_FEED',
    priority: 836,
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'PED_BOWEL_BLADDER',
    section: 'nutrition',
    text: 'Are the child’s bladder and bowel habits normal?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'PED_BOWEL_BLADDER_NORMAL',
    priority: 835,
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'PED_24HR_RECALL',
    section: 'nutrition',
    text: 'Record the 24-hour recall feeding schedule (breakfast, lunch, supper).',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'FEEDING_24HR_RECALL',
    priority: 834,
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    placeholder: 'Breakfast: … | Lunch: … | Supper: …',
    reason: 'The ward form concludes whether nutrition is of good quantity and quality.',
  },

  {
    questionCode: 'PED_MEALS_PER_DAY',
    section: 'nutrition',
    text: 'How many meals per day does the child (on family diet) eat?',
    responseType: 'measurement',
    requirementLevel: 'conditional',
    factCode: 'MEALS_PER_DAY',
    priority: 833,
    unitCode: 'meals',
    applies: (context) =>
      isPaediatric(context) && !isAdult(context),
    validation: {
      min: 1,
      max: 8,
      step: 1,
    },
  },

  // ===========================================================================
  // PAEDIATRIC — ACTIVITY (rendered within HPI)
  // ===========================================================================

  {
    questionCode: 'PED_ACTIVITY',
    section: 'hpi',
    text: 'How is the child’s activity compared with usual?',
    responseType: 'single_select',
    requirementLevel: 'recommended',
    factCode: 'ACTIVITY_STATUS',
    priority: 910,
    applies: (context) =>
      isPaediatric(context),
    visibleWhen: chiefComplaintDocumented,
    options: [
      {
        answerCode: 'NORMAL',
        label: 'Normal',
      },
      {
        answerCode: 'REDUCED',
        label: 'Reduced',
      },
      {
        answerCode: 'LETHARGIC',
        label: 'Very reduced / lethargic',
      },
      {
        answerCode: 'UNKNOWN',
        label: 'Unknown',
      },
    ],
  },

  // ===========================================================================
  // PAEDIATRIC — RESPIRATORY SAFETY QUESTIONS
  // ===========================================================================

  {
    questionCode: 'PED_BREATHING_DIFFICULTY',
    section: 'hpi',
    text: 'Has the child had difficulty breathing or breathing faster than usual?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'BREATHING_DIFFICULTY',
    priority: 950,
    applies: (context) =>
      isPaediatric(context),
    visibleWhen: chiefComplaintDocumented,
    options: booleanOptions(),
  },

  {
    questionCode: 'PED_GRUNTING',
    section: 'hpi',
    text: 'Has the child been grunting or making unusual noisy breathing sounds?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'GRUNTING_PRESENT',
    priority: 940,
    applies: (context) =>
      isPaediatric(context),
    visibleWhen: chiefComplaintDocumented,
    options: booleanOptions(),
  },

  {
    questionCode: 'PED_FEEDING_RESPIRATORY',
    section: 'hpi',
    text: 'Has breathing difficulty affected feeding or drinking?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'BREATHING_AFFECTING_FEEDING',
    priority: 930,
    applies: (context) =>
      isPaediatric(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'BREATHING_DIFFICULTY') === true,
    options: booleanOptions(),
  },

  // ===========================================================================
  // SURGICAL — POST-OPERATIVE OVERLAY
  //
  // Per the General Surgery ward form: "Can the patient pass stool/flatus, eat,
  // drink, walk, have normal bladder and bowel habits, any pain at the surgical
  // site, any discharge, hotness of body or any other complaints?" Only shown
  // once a post-operative day or procedure is recorded.
  // ===========================================================================

  {
    questionCode: 'SURG_POSTOP_GUT',
    section: 'hpi',
    text: 'Has the patient passed stool or flatus since the operation?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_PASSED_FLATUS',
    priority: 1500,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: [
      { answerCode: 'YES_FLATUS', label: 'Yes — passed flatus' },
      { answerCode: 'YES_STOOL', label: 'Yes — passed stool' },
      { answerCode: 'NO', label: 'No' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
    reason: 'Bowel recovery is a key post-operative milestone.',
  },

  {
    questionCode: 'SURG_POSTOP_DIET',
    section: 'hpi',
    text: 'Can the patient tolerate eating and drinking?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_DIET_TOLERANCE',
    priority: 1490,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: [
      { answerCode: 'TOLERATING', label: 'Yes — tolerating' },
      { answerCode: 'PARTIAL', label: 'Partial — small amounts only' },
      { answerCode: 'UNABLE', label: 'No — unable' },
      { answerCode: 'NPO', label: 'NPO / on fluids only' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'SURG_POSTOP_MOBILITY',
    section: 'hpi',
    text: 'Can the patient walk and mobilise normally?',
    responseType: 'single_select',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_MOBILITY',
    priority: 1480,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: [
      { answerCode: 'NORMAL', label: 'Yes — mobilising' },
      { answerCode: 'REDUCED', label: 'With difficulty' },
      { answerCode: 'BEDRIDDEN', label: 'No — bed-bound' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
  },

  {
    questionCode: 'SURG_POSTOP_BLADDER_BOWEL',
    section: 'hpi',
    text: 'Are bladder and bowel habits normal (voiding and defaecating) after surgery?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_BLADDER_BOWEL_NORMAL',
    priority: 1470,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: booleanOptions(),
  },

  {
    questionCode: 'SURG_POSTOP_WOUND_PAIN',
    section: 'hpi',
    text: 'Is there any pain at the surgical site?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_WOUND_PAIN',
    priority: 1460,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: booleanOptions(),
  },

  {
    questionCode: 'SURG_POSTOP_WOUND_DISCHARGE',
    section: 'hpi',
    text: 'Is there any discharge (bleeding or pus) from the surgical wound?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_WOUND_DISCHARGE',
    priority: 1450,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: booleanOptions(),
  },

  {
    questionCode: 'SURG_POSTOP_FEVER',
    section: 'hpi',
    text: 'Has there been any hotness of the body (fever) since the operation?',
    responseType: 'boolean',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_FEVER',
    priority: 1440,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
    options: booleanOptions(),
  },

  {
    questionCode: 'SURG_POSTOP_OTHER',
    section: 'hpi',
    text: 'Any other new complaints since the operation?',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'POSTOP_OTHER_COMPLAINTS',
    priority: 1430,
    applies: (context) => isSurgical(context),
    visibleWhen: (_context, facts) =>
      hasFact(facts, 'POST_OPERATIVE_DAY') ||
      hasFact(facts, 'POST_OPERATIVE_PROCEDURE'),
  },

  // ===========================================================================
  // PSYCHIATRY
  // ===========================================================================

  {
    questionCode: 'PSYCH_PRESENTATION',
    section: 'psychiatric_history',
    text: 'What change in mood, thought, perception, behaviour, or functioning has been observed?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'PSYCHIATRIC_PRESENTATION',
    priority: 900,
    applies: (context) =>
      isPsychiatry(context),
  },

  {
    questionCode: 'PSYCH_FUNCTION',
    section: 'psychiatric_history',
    text: 'How has the current problem affected the patient’s daily functioning?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'PSYCHIATRIC_FUNCTIONAL_IMPACT',
    priority: 890,
    applies: (context) =>
      isPsychiatry(context),
  },

  {
    questionCode: 'PSYCH_PREVIOUS_EPISODES',
    section: 'psychiatric_history',
    text: 'Has the patient had previous episodes of mental illness or psychiatric admissions?',
    responseType: 'long_text',
    requirementLevel: 'recommended',
    factCode: 'PSYCHIATRIC_HISTORY',
    priority: 880,
    applies: (context) =>
      isPsychiatry(context),
  },

  {
    questionCode: 'PSYCH_RISK',
    section: 'psychiatric_history',
    text: 'Any current suicidal or self-harm thoughts, plans or intent?',
    responseType: 'boolean',
    requirementLevel: 'mandatory',
    factCode: 'SUICIDAL_IDEATION',
    priority: 2000,
    applies: (context) =>
      isPsychiatry(context),
    options: booleanOptions(),
    reason: 'Safety assessment is mandatory in psychiatric encounters.',
  },

  {
    questionCode: 'PSYCH_SUBSTANCE',
    section: 'substance_history',
    text: 'Is there any current or recent alcohol, nicotine, medication, or other substance use relevant to the presentation?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'SUBSTANCE_USE_PRESENT',
    priority: 850,
    applies: (context) =>
      isPsychiatry(context) && isAdolescentOrOlder(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'PSYCH_SUBSTANCE_DETAILS',
    section: 'substance_history',
    text: 'Describe the substances used, frequency, and duration.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'SUBSTANCE_HISTORY',
    priority: 849,
    applies: (context) =>
      isPsychiatry(context) && isAdolescentOrOlder(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'SUBSTANCE_USE_PRESENT') === true,
  },

  {
    questionCode: 'PSYCH_COLLATERAL',
    section: 'collateral_history',
    text: 'Is collateral information from a family member, caregiver, or other source available and relevant?',
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: 'COLLATERAL_AVAILABLE',
    priority: 840,
    applies: (context) =>
      isPsychiatry(context),
    options: booleanOptions(),
  },

  {
    questionCode: 'PSYCH_COLLATERAL_DETAILS',
    section: 'collateral_history',
    text: 'Record the collateral information provided.',
    responseType: 'long_text',
    requirementLevel: 'conditional',
    factCode: 'COLLATERAL_HISTORY',
    priority: 839,
    applies: (context) =>
      isPsychiatry(context),
    visibleWhen: (_context, facts) =>
      factBoolean(facts, 'COLLATERAL_AVAILABLE') === true,
  },

  // ===========================================================================
  // EMERGENCY OVERLAY
  // ===========================================================================

  {
    questionCode: 'EMERGENCY_ACUTE_CHANGE',
    section: 'hpi',
    text: 'Has there been a sudden or significant deterioration in the patient’s condition?',
    responseType: 'boolean',
    requirementLevel: 'mandatory',
    factCode: 'ACUTE_DETERIORATION',
    priority: 2000,
    applies: (context) =>
      isEmergency(context),
    options: booleanOptions(),
    reason: 'Emergency encounters require immediate identification of acute deterioration.',
  },

  {
    questionCode: 'EMERGENCY_TIME_CRITICAL',
    section: 'hpi',
    text: 'When was the patient last known to be at their usual baseline?',
    responseType: 'datetime',
    requirementLevel: 'recommended',
    factCode: 'LAST_KNOWN_BASELINE',
    priority: 1990,
    applies: (context) =>
      isEmergency(context),
  },
];

// =============================================================================
// SECTION-SPECIFIC FILTER
// =============================================================================

function sectionMatches(
  question: QuestionDefinition,
  activeSection?: string,
): boolean {
  if (!activeSection) return true;

  return (
    question.section === activeSection ||
    question.requirementLevel === 'mandatory'
  );
}

// =============================================================================
// DEPENDENCY / VISIBILITY
// =============================================================================

function isVisible(
  question: QuestionDefinition,
  context: ClinicalContext,
  facts: ClinicalFact[],
): boolean {
  if (question.applies && !question.applies(context)) {
    return false;
  }

  if (
    question.visibleWhen &&
    !question.visibleWhen(context, facts)
  ) {
    return false;
  }

  return true;
}

// =============================================================================
// CAPTURED FILTER
// =============================================================================

function isAlreadyCaptured(
  question: QuestionDefinition,
  facts: ClinicalFact[],
): boolean {
  if (!question.factCode) {
    return false;
  }

  return hasFact(facts, question.factCode);
}

// =============================================================================
// REQUIREMENT WEIGHT
// =============================================================================

function requirementWeight(
  level: RequirementLevel,
): number {
  switch (level) {
    case 'mandatory':
      return 100000;

    case 'conditional':
      return 50000;

    case 'recommended':
      return 25000;

    case 'optional':
      return 0;

    default:
      return 0;
  }
}

// =============================================================================
// DEVELOPMENTAL MILESTONE QUESTIONS
//
// Age-appropriate milestones are projected for the child's age window. Each
// milestone becomes a boolean "achieved / not achieved" question with its own
// fact code (MILESTONE_<CODE>_ACHIEVED), so the documentation engine can
// deduce whether development is appropriate or delayed.
// =============================================================================

function buildMilestoneQuestions(
  context: ClinicalContext,
): QuestionDefinition[] {
  if (!isPaediatric(context) || isNeonate(context)) {
    return [];
  }

  const milestones = milestonesForAge(context);

  return milestones.map((milestone, index) => ({
    questionCode: `PED_${milestone.code}`,
    section: 'growth_development',
    text: `Has the child achieved: ${milestone.label}?`,
    responseType: 'boolean',
    requirementLevel: 'recommended',
    factCode: milestoneFactCode(milestone.code),
    priority: 500 - index,
    options: [
      { answerCode: 'YES', label: 'Achieved' },
      { answerCode: 'NO', label: 'Not yet' },
      { answerCode: 'UNKNOWN', label: 'Unknown' },
    ],
    reason: `Milestone expected around ${milestone.expectedAgeMonths} months (${milestone.domain.replace(/_/g, ' ')}).`,
  }));
}

// =============================================================================
// PER-PREGNANCY OBSTETRIC TABLE
//
// Per the Obstetrics & Gynaecology ward form, past obstetric history is a
// table of each previous pregnancy: year, gestational age, mode of delivery,
// location, birth weight, sex, fate of the child and complications. Questions
// are generated for the first N pregnancies (up to 5) when the patient is a
// female of reproductive age in an OBGYN context. Each pregnancy block is
// revealed progressively as the previous one is captured.
// =============================================================================

const PREGNANCY_ROW_LIMIT = 5;

function buildPregnancyTableQuestions(
  context: ClinicalContext,
  facts: ClinicalFact[],
): QuestionDefinition[] {
  if (
    !isFemaleReproductiveAge(context) &&
    context.department !== 'obgyn'
  ) {
    return [];
  }

  if (context.sex !== 'female') {
    return [];
  }

  const questions: QuestionDefinition[] = [];

  for (let index = 1; index <= PREGNANCY_ROW_LIMIT; index += 1) {
    const ordinal =
      index === 1
        ? 'first'
        : index === 2
          ? 'second'
          : index === 3
            ? 'third'
            : index === 4
              ? 'fourth'
              : 'fifth';

    const rowVisible = (): boolean => {
      if (index === 1) {
        return (
          hasFact(facts, 'GRAVIDA') ||
          hasFact(facts, 'PARA') ||
          hasFact(facts, 'ABORTIONS') ||
          hasFact(facts, 'PREGNANCY_STATUS')
        );
      }
      return hasFact(facts, `OB_PREGNANCY_${index - 1}_YEAR`);
    };

    const base = 830 - index * 10;

    questions.push(
      {
        questionCode: `OB_PREGNANCY_${index}_YEAR`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, which year did it occur?`,
        responseType: 'measurement',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_YEAR`,
        priority: base,
        unitCode: 'year',
        visibleWhen: rowVisible,
        validation: {
          min: 1980,
          max: 2100,
          step: 1,
        },
      },
      {
        questionCode: `OB_PREGNANCY_${index}_GA`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, what was the gestational age at delivery (weeks)?`,
        responseType: 'measurement',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_GA`,
        priority: base - 1,
        unitCode: 'weeks',
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_YEAR`),
        validation: {
          min: 20,
          max: 44,
          step: 0.1,
        },
      },
      {
        questionCode: `OB_PREGNANCY_${index}_MODE`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, what was the mode of delivery?`,
        responseType: 'single_select',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_MODE`,
        priority: base - 2,
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_GA`),
        options: [
          { answerCode: 'SVD', label: 'Spontaneous vaginal delivery' },
          { answerCode: 'ASSISTED', label: 'Assisted vaginal delivery' },
          { answerCode: 'CS', label: 'Caesarean section' },
          { answerCode: 'MVA', label: 'MVA / surgical evacuation' },
          { answerCode: 'DNC', label: 'D&C' },
          { answerCode: 'UNKNOWN', label: 'Unknown' },
        ],
      },
      {
        questionCode: `OB_PREGNANCY_${index}_LOCATION`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, where did the delivery occur?`,
        responseType: 'single_select',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_LOCATION`,
        priority: base - 3,
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_MODE`),
        options: [
          { answerCode: 'HOSPITAL', label: 'Hospital' },
          { answerCode: 'HEALTH_CENTRE', label: 'Health centre' },
          { answerCode: 'HOME', label: 'Home' },
          { answerCode: 'OTHER', label: 'Other' },
          { answerCode: 'UNKNOWN', label: 'Unknown' },
        ],
      },
      {
        questionCode: `OB_PREGNANCY_${index}_BIRTH_WEIGHT`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, what was the birth weight (kg)?`,
        responseType: 'measurement',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_BIRTH_WEIGHT`,
        priority: base - 4,
        unitCode: 'kg',
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_LOCATION`),
        validation: {
          min: 0.5,
          max: 6,
          step: 0.01,
        },
      },
      {
        questionCode: `OB_PREGNANCY_${index}_SEX`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, what was the sex of the child?`,
        responseType: 'single_select',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_SEX`,
        priority: base - 5,
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_BIRTH_WEIGHT`),
        options: [
          { answerCode: 'MALE', label: 'Male' },
          { answerCode: 'FEMALE', label: 'Female' },
          { answerCode: 'UNKNOWN', label: 'Unknown' },
        ],
      },
      {
        questionCode: `OB_PREGNANCY_${index}_FATE`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, what was the fate of the child (alive / dead / abortion)?`,
        responseType: 'single_select',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_FATE`,
        priority: base - 6,
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_SEX`),
        options: [
          { answerCode: 'ALIVE', label: 'Alive and well' },
          { answerCode: 'DEAD', label: 'Died' },
          { answerCode: 'ABORTION', label: 'Abortion / miscarriage' },
          { answerCode: 'UNKNOWN', label: 'Unknown' },
        ],
      },
      {
        questionCode: `OB_PREGNANCY_${index}_COMPLICATIONS`,
        section: 'obstetric_history',
        text: `For the ${ordinal} pregnancy, were there any complications?`,
        responseType: 'long_text',
        requirementLevel: 'conditional',
        factCode: `OB_PREGNANCY_${index}_COMPLICATIONS`,
        priority: base - 7,
        visibleWhen: (_context, currentFacts) =>
          hasFact(currentFacts, `OB_PREGNANCY_${index}_FATE`),
        placeholder: 'e.g. Postpartum haemorrhage; eclampsia.',
      },
    );
  }

  return questions;
}

// =============================================================================
// QUESTION RESOLUTION
// =============================================================================
//
// The CPU can call:
//
//   resolveQuestions(context, facts)
//
// or:
//
//   resolveQuestions(context, facts, 'hpi')
//
// The function returns questions the UI can render.
//
// It deliberately does NOT:
//   - diagnose
//   - rank diseases
//   - calculate phenotype scores
//   - calculate mechanisms
//   - choose treatment
//
// =============================================================================

export function resolveQuestions(
  context: ClinicalContext,
  facts: ClinicalFact[],
  activeSection?: string,
): CaptureQuestion[] {
  const catalogue = [
    ...UNIVERSAL_QUESTIONS,
    ...buildMilestoneQuestions(context),
    ...buildPregnancyTableQuestions(context, facts),
  ];

  return catalogue
    .filter((question) =>
      sectionMatches(question, activeSection),
    )
    .filter((question) =>
      isVisible(question, context, facts),
    )
    .filter((question) =>
      !isAlreadyCaptured(question, facts),
    )
    .sort((a, b) => {
      const requirementDifference =
        requirementWeight(b.requirementLevel) -
        requirementWeight(a.requirementLevel);

      if (requirementDifference !== 0) {
        return requirementDifference;
      }

      return b.priority - a.priority;
    })
    .map((question) => ({
      questionCode: question.questionCode,
      section: question.section,
      text: question.text,
      responseType: question.responseType,
      requirementLevel: question.requirementLevel,
      priority: question.priority,
      reason: question.reason ?? null,
      factCode: question.factCode ?? null,
      unitCode: question.unitCode ?? null,
      options: question.options ?? [],
      visible: true,
      enabled: true,
      validation: question.validation ?? null,
      placeholder: question.placeholder ?? null,
      allowUnknown: question.allowUnknown ?? true,
      allowNotApplicable:
        question.allowNotApplicable ?? true,
      allowDefer:
        question.allowDefer ?? true,
      source: question.source ?? null,
    }));
}

// =============================================================================
// SECTION QUESTION RESOLUTION
// =============================================================================
//
// Useful when the UI explicitly opens a section.
//
// =============================================================================

export function resolveQuestionsForSection(
  context: ClinicalContext,
  facts: ClinicalFact[],
  section: HistorySection,
): CaptureQuestion[] {
  return resolveQuestions(
    context,
    facts,
    section,
  ).filter(
    (question) =>
      question.section === section ||
      question.requirementLevel === 'mandatory',
  );
}

// =============================================================================
// REQUIRED QUESTIONS
// =============================================================================

export function resolveMandatoryQuestions(
  context: ClinicalContext,
  facts: ClinicalFact[],
  activeSection?: string,
): CaptureQuestion[] {
  return resolveQuestions(
    context,
    facts,
    activeSection,
  ).filter(
    (question) =>
      question.requirementLevel === 'mandatory',
  );
}

// =============================================================================
// QUESTION COMPLETION
// =============================================================================

export function countRemainingRequiredQuestions(
  context: ClinicalContext,
  facts: ClinicalFact[],
  activeSection?: string,
): number {
  return resolveMandatoryQuestions(
    context,
    facts,
    activeSection,
  ).length;
}

// =============================================================================
// PUBLIC QUESTION CATALOGUE ACCESS
// =============================================================================
//
// Useful for testing, administration, knowledge tooling and development.
// Returns a defensive copy so consumers cannot mutate the internal catalogue.
//
// =============================================================================

export function getQuestionDefinitions(): QuestionDefinition[] {
  return UNIVERSAL_QUESTIONS.map((question) => ({
    ...question,
    options: question.options
      ? [...question.options]
      : undefined,
  }));
}
