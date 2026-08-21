// =============================================================================
// src/clinical/context.ts
// AMEXAN UNIVERSAL CLINICAL CONTEXT RESOLUTION
//
// This file resolves CONTEXT only.
// It does NOT decide diagnoses, treatment, investigations, or clinical
// reasoning. It determines which universal clinical format/domain applies.
//
// CORE RULES
// -----------------------------------------------------------------------------
// 1. Neonate:            0–28 completed days
// 2. Paediatrics:        >28 days through <13 years
// 3. Adult:              >=13 years
// 4. Older adult:        >=65 years
//
// 5. Male:
//      pregnancy/obstetric/gynaecological context = NOT APPLICABLE
//
// 6. Female does NOT automatically mean OBGYN.
//      A reproductive-age woman can be managed under:
//        - Medical
//        - Surgical
//        - Emergency
//        - Psychiatry
//        - Other
//      unless pregnancy/postpartum or an obstetric/gynaecological context
//      makes OBGYN applicable.
//
// 7. Pregnant/postpartum:
//      OBGYN context is mandatory.
//
// 8. Neonates:
//      Neonatology overrides ordinary department selection.
//
// 9. Children:
//      Paediatrics overrides ordinary adult medical/surgical/OBGYN selection.
//
// 10. Emergency:
//      Emergency context may be preserved as the encounter domain, while
//      age-specific history/examination formats remain age appropriate.
//
// 11. Psychiatry:
//      Psychiatry is selected when explicitly requested for an adult/adolescent
//      psychiatric encounter, subject to emergency/age-specific precedence.
//
// 12. Department determines the BASE format.
//      Age/sex/pregnancy/context then activates additional sections.
//
// 13. The UI must NEVER independently reproduce these rules.
//      CPU/context projection is authoritative.
// =============================================================================

import type {
  ClinicalContext,
  EncounterDomain,
  LifeStage,
  PregnancyState,
  Sex,
} from './types';

// =============================================================================
// CONSTANTS
// =============================================================================

export const NEONATAL_MAX_DAYS = 28;
export const PAEDIATRIC_MAX_YEARS = 13;
export const OLDER_ADULT_MIN_YEARS = 65;
export const REPRODUCTIVE_AGE_MIN_YEARS = 12;
export const REPRODUCTIVE_AGE_MAX_YEARS = 55;

// =============================================================================
// PRESENTING-COMPLAINT / CONTEXT CLASSIFICATION
// =============================================================================

/**
 * Codes which strongly indicate an obstetric context.
 *
 * These are intentionally code-based rather than text-based.
 * The database/knowledge layer should use stable vocabulary codes.
 */
const OBSTETRIC_CONTEXT_CODES = new Set([
  'PREGNANCY',
  'PREGNANCY_CONFIRMED',
  'PREGNANCY_SUSPECTED',
  'ANTENATAL_CARE',
  'ANC',
  'LABOUR',
  'DELIVERY',
  'INTRAPARTUM',
  'POSTPARTUM',
  'PUERPERIUM',
  'POSTPARTUM_HAEMORRHAGE',
  'ECTOPIC_PREGNANCY',
  'MISCARRIAGE',
  'ABORTION',
  'THREATENED_ABORTION',
  'PLACENTA_PREVIA',
  'ABRUPTION',
  'PRE_ECLAMPSIA',
  'ECLAMPSIA',
  'GESTATIONAL_DIABETES',
  'GESTATIONAL_HYPERTENSION',
  'FETAL_MOVEMENT',
  'REDUCED_FETAL_MOVEMENT',
  'PROM',
  'PPROM',
  'HYPEREMESIS_GRAVIDARUM',
  'OBSTETRIC_EMERGENCY',
]);

/**
 * Codes which strongly indicate a gynaecological context.
 */
const GYNAECOLOGICAL_CONTEXT_CODES = new Set([
  'MENSTRUAL_DISORDER',
  'ABNORMAL_UTERINE_BLEEDING',
  'MENORRHAGIA',
  'AMENORRHOEA',
  'DYSMENORRHOEA',
  'PELVIC_PAIN',
  'VAGINAL_BLEEDING',
  'VAGINAL_DISCHARGE',
  'VULVAL_SYMPTOM',
  'VULVAL_LUMP',
  'VAGINAL_LUMP',
  'CERVICAL_SYMPTOM',
  'UTERINE_SYMPTOM',
  'OVARIAN_SYMPTOM',
  'ADNEXAL_MASS',
  'FIBROID',
  'ENDOMETRIOSIS',
  'OVARIAN_CYST',
  'PCOS',
  'INFERTILITY',
  'SUBFERTILITY',
  'FERTILITY',
  'CONTRACEPTION',
  'FAMILY_PLANNING',
  'MENOPAUSE',
  'PERIMENOPAUSE',
  'CLIMACTERIC',
  'DYSPAREUNIA',
  'SEXUAL_HEALTH',
  'CERVICAL_SCREENING',
  'PAP_SMEAR',
  'HPV',
  'BREAST_SYMPTOM',
]);

const PSYCHIATRIC_CONTEXT_CODES = new Set([
  'DEPRESSION',
  'ANXIETY',
  'PSYCHOSIS',
  'SCHIZOPHRENIA',
  'MANIA',
  'BIPOLAR_DISORDER',
  'SUICIDAL_IDEATION',
  'SELF_HARM',
  'HOMICIDAL_IDEATION',
  'HALLUCINATION',
  'DELUSION',
  'PANIC_ATTACK',
  'SUBSTANCE_USE',
  'ALCOHOL_USE',
  'DRUG_USE',
  'PSYCHIATRIC_EMERGENCY',
]);

// =============================================================================
// NORMALIZATION
// =============================================================================

function normalizeCode(code: string | null | undefined): string {
  return String(code ?? '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
}

function hasAnyCode(
  codes: string[],
  vocabulary: Set<string>,
): boolean {
  for (const code of codes) {
    if (vocabulary.has(normalizeCode(code))) {
      return true;
    }
  }

  return false;
}

// =============================================================================
// AGE RESOLUTION
// =============================================================================

/**
 * Resolve life stage using the most precise available age unit.
 *
 * Neonatal period:
 *      birth through 28 completed days.
 *
 * Paediatric period:
 *      >28 days through <13 years.
 *
 * Adolescent:
 *      >=13 through <18.
 *
 * Adult:
 *      >=18 through <65.
 *
 * Older adult:
 *      >=65.
 *
 * IMPORTANT:
 * The historical clinical format rules may treat adolescents as part of
 * paediatrics in some services. Therefore the context layer exposes
 * "adolescent" separately, while format resolution may still attach an
 * adolescent to a paediatric or adult format according to departmental rules.
 */
export function resolveLifeStage(
  ageYears: number | null,
  ageMonths: number | null,
  ageDays: number | null,
): LifeStage {
  // Most precise neonatal test.
  if (ageDays != null && Number.isFinite(ageDays)) {
    if (ageDays >= 0 && ageDays <= NEONATAL_MAX_DAYS) {
      return 'neonate';
    }
  }

  // Precise infant test.
  if (ageMonths != null && Number.isFinite(ageMonths)) {
    if (ageMonths > 0 && ageMonths < 12) {
      return 'infant';
    }
  }

  // Children under 13 years.
  if (ageYears != null && Number.isFinite(ageYears)) {
    if (ageYears >= 0 && ageYears < 13) {
      return 'child';
    }

    if (ageYears >= 13 && ageYears < 18) {
      return 'adolescent';
    }

    if (ageYears >= 65) {
      return 'older_adult';
    }

    if (ageYears >= 18) {
      return 'adult';
    }
  }

  // If age is incomplete/unknown, default to adult rather than inventing
  // paediatric or neonatal status.
  return 'adult';
}

// =============================================================================
// FORMAT AGE BAND
// =============================================================================

/**
 * Clinical format age band.
 *
 * This is deliberately separate from LifeStage because UI/format engines
 * may group several life stages into one documentation format.
 */
export function resolveAgeBand(
  lifeStage: LifeStage,
): 'NEONATE' | 'PAEDIATRIC' | 'ADULT' | 'OLDER_ADULT' {
  if (lifeStage === 'neonate') {
    return 'NEONATE';
  }

  if (
    lifeStage === 'infant' ||
    lifeStage === 'child' ||
    lifeStage === 'adolescent'
  ) {
    return 'PAEDIATRIC';
  }

  if (lifeStage === 'older_adult') {
    return 'OLDER_ADULT';
  }

  return 'ADULT';
}

// =============================================================================
// REPRODUCTIVE AGE
// =============================================================================

export function isReproductiveAge(
  ageYears: number | null,
  sex: Sex,
): boolean {
  if (sex !== 'female') {
    return false;
  }

  if (ageYears == null || !Number.isFinite(ageYears)) {
    return false;
  }

  return (
    ageYears >= REPRODUCTIVE_AGE_MIN_YEARS &&
    ageYears <= REPRODUCTIVE_AGE_MAX_YEARS
  );
}

// =============================================================================
// SEX / PREGNANCY RULES
// =============================================================================

/**
 * Pregnancy is biologically applicable only to female context in this
 * vocabulary model.
 *
 * Male patients must NEVER receive pregnancy/obstetric/gynaecological
 * history merely because a department or UI component requested it.
 */
export function resolvePregnancyState(
  sex: Sex,
  pregnancyState: PregnancyState | null | undefined,
): PregnancyState {
  if (sex !== 'female') {
    return 'not_applicable';
  }

  return pregnancyState ?? 'unknown';
}

export function isPregnant(
  pregnancyState: PregnancyState,
): boolean {
  return pregnancyState === 'pregnant';
}

export function isPostpartum(
  pregnancyState: PregnancyState,
): boolean {
  return pregnancyState === 'postpartum';
}

export function hasActiveObstetricState(
  pregnancyState: PregnancyState,
): boolean {
  return (
    pregnancyState === 'pregnant' ||
    pregnancyState === 'postpartum'
  );
}

// =============================================================================
// FEMALE OBGYN CONTEXT
// =============================================================================

/**
 * Female reproductive age alone does NOT activate OBGYN.
 *
 * Example:
 *
 * 24-year-old woman + cough
 *     -> medical format
 *
 * 24-year-old woman + abdominal surgical complaint
 *     -> surgical format
 *
 * 24-year-old woman + abnormal uterine bleeding
 *     -> OBGYN format
 *
 * 24-year-old woman + confirmed pregnancy
 *     -> OBGYN format
 */
export function hasGynaecologicalContext(
  sex: Sex,
  ageYears: number | null,
  presentingComplaintCodes: string[],
): boolean {
  if (sex !== 'female') {
    return false;
  }

  if (!isReproductiveAge(ageYears, sex)) {
    // Gynaecological problems can still occur outside reproductive age,
    // e.g. menopause or postmenopausal bleeding.
    return hasAnyCode(
      presentingComplaintCodes,
      GYNAECOLOGICAL_CONTEXT_CODES,
    );
  }

  return hasAnyCode(
    presentingComplaintCodes,
    GYNAECOLOGICAL_CONTEXT_CODES,
  );
}

export function hasObstetricContext(
  sex: Sex,
  pregnancyState: PregnancyState,
  presentingComplaintCodes: string[],
): boolean {
  if (sex !== 'female') {
    return false;
  }

  if (hasActiveObstetricState(pregnancyState)) {
    return true;
  }

  return hasAnyCode(
    presentingComplaintCodes,
    OBSTETRIC_CONTEXT_CODES,
  );
}

export function hasObgynContext(input: {
  sex: Sex;
  ageYears: number | null;
  pregnancyState: PregnancyState;
  presentingComplaintCodes: string[];
}): boolean {
  if (input.sex !== 'female') {
    return false;
  }

  return (
    hasObstetricContext(
      input.sex,
      input.pregnancyState,
      input.presentingComplaintCodes,
    ) ||
    hasGynaecologicalContext(
      input.sex,
      input.ageYears,
      input.presentingComplaintCodes,
    )
  );
}

// =============================================================================
// PSYCHIATRY CONTEXT
// =============================================================================

export function hasPsychiatricContext(
  presentingComplaintCodes: string[],
): boolean {
  return hasAnyCode(
    presentingComplaintCodes,
    PSYCHIATRIC_CONTEXT_CODES,
  );
}

// =============================================================================
// EMERGENCY CONTEXT
// =============================================================================

export function hasEmergencyContext(
  emergency: boolean,
  presentingComplaintCodes: string[],
): boolean {
  if (emergency) {
    return true;
  }

  return hasAnyCode(
    presentingComplaintCodes,
    new Set([
      'EMERGENCY',
      'MEDICAL_EMERGENCY',
      'SURGICAL_EMERGENCY',
      'OBSTETRIC_EMERGENCY',
      'PAEDIATRIC_EMERGENCY',
      'TRAUMA',
      'MAJOR_TRAUMA',
      'CARDIAC_ARREST',
      'RESPIRATORY_ARREST',
      'SHOCK',
      'SEPSIS',
    ]),
  );
}

// =============================================================================
// DOMAIN RESOLUTION
// =============================================================================

export interface ClinicalDomainResolutionInput {
  sex: Sex;
  ageYears: number | null;
  lifeStage: LifeStage;
  pregnancyState: PregnancyState;
  requestedDepartment?: EncounterDomain | null;
  presentingComplaintCodes: string[];
  emergency: boolean;
}

/**
 * Resolve the operational clinical domain.
 *
 * PRECEDENCE:
 *
 * 1. Neonatology
 * 2. Paediatrics
 * 3. Emergency when explicitly emergency
 * 4. OBGYN when pregnancy/obstetric/gynaecological context exists
 * 5. Explicit psychiatry
 * 6. Explicit surgical
 * 7. Explicit medical
 * 8. Other
 *
 * The important rule is that FEMALE != OBGYN.
 */
export function resolveClinicalDomain(
  input: ClinicalDomainResolutionInput,
): EncounterDomain {
  const {
    sex,
    ageYears,
    lifeStage,
    pregnancyState,
    requestedDepartment,
    presentingComplaintCodes,
    emergency,
  } = input;

  // ---------------------------------------------------------------------------
  // 1. NEONATE
  // ---------------------------------------------------------------------------
  if (lifeStage === 'neonate') {
    return 'neonatology';
  }

  // ---------------------------------------------------------------------------
  // 2. PAEDIATRICS
  //
  // Children and adolescents remain age-specific rather than being treated as
  // adult patients simply because an adult department was requested.
  // ---------------------------------------------------------------------------
  if (
    lifeStage === 'infant' ||
    lifeStage === 'child' ||
    lifeStage === 'adolescent'
  ) {
    // Emergency can remain the operational encounter domain when the service
    // explicitly starts as emergency, but the age-specific format still
    // remains paediatric.
    if (
      emergency &&
      requestedDepartment === 'emergency'
    ) {
      return 'emergency';
    }

    return 'paediatrics';
  }

  // ---------------------------------------------------------------------------
  // 3. EMERGENCY
  // ---------------------------------------------------------------------------
  if (
    emergency ||
    hasEmergencyContext(
      false,
      presentingComplaintCodes,
    )
  ) {
    if (
      requestedDepartment === 'emergency' ||
      emergency
    ) {
      return 'emergency';
    }
  }

  // ---------------------------------------------------------------------------
  // 4. OBGYN
  //
  // ONLY FEMALE PATIENTS CAN ENTER THIS DOMAIN.
  // Pregnancy/postpartum automatically activates it.
  // Gynaecological complaints can activate it even when not pregnant.
  // ---------------------------------------------------------------------------
  if (
    sex === 'female' &&
    hasObgynContext({
      sex,
      ageYears,
      pregnancyState,
      presentingComplaintCodes,
    })
  ) {
    return 'obgyn';
  }

  // ---------------------------------------------------------------------------
  // 5. EXPLICIT PSYCHIATRY
  // ---------------------------------------------------------------------------
  if (
    requestedDepartment === 'psychiatry' ||
    hasPsychiatricContext(presentingComplaintCodes)
  ) {
    return 'psychiatry';
  }

  // ---------------------------------------------------------------------------
  // 6. EXPLICIT SURGERY
  // ---------------------------------------------------------------------------
  if (requestedDepartment === 'surgical') {
    return 'surgical';
  }

  // ---------------------------------------------------------------------------
  // 7. EXPLICIT MEDICINE
  // ---------------------------------------------------------------------------
  if (requestedDepartment === 'medical') {
    return 'medical';
  }

  // ---------------------------------------------------------------------------
  // 8. OTHER
  // ---------------------------------------------------------------------------
  if (requestedDepartment === 'other') {
    return 'other';
  }

  // Safe adult default.
  return 'medical';
}

// =============================================================================
// HISTORY FORMAT CLASSIFICATION
// =============================================================================

export type ClinicalHistoryFormat =
  | 'ADULT_MEDICAL'
  | 'ADULT_SURGICAL'
  | 'ADULT_OBGYN'
  | 'PAEDIATRIC'
  | 'NEONATAL'
  | 'PSYCHIATRY'
  | 'EMERGENCY_MEDICAL'
  | 'EMERGENCY_SURGICAL'
  | 'EMERGENCY_PAEDIATRIC'
  | 'EMERGENCY_OBSTETRIC';

export function resolveHistoryFormat(input: {
  context: ClinicalContext;
}): ClinicalHistoryFormat {
  const {
    context,
  } = input;

  // Neonatal format always wins.
  if (context.lifeStage === 'neonate') {
    return 'NEONATAL';
  }

  // Paediatric format.
  if (
    context.lifeStage === 'infant' ||
    context.lifeStage === 'child' ||
    context.lifeStage === 'adolescent'
  ) {
    if (context.emergency) {
      return 'EMERGENCY_PAEDIATRIC';
    }

    return 'PAEDIATRIC';
  }

  // Emergency adult/OBGYN formats.
  if (context.emergency) {
    if (
      context.sex === 'female' &&
      hasObgynContext({
        sex: context.sex,
        ageYears: context.ageYears,
        pregnancyState: context.pregnancyState,
        presentingComplaintCodes:
          context.presentingComplaintCodes,
      })
    ) {
      return 'EMERGENCY_OBSTETRIC';
    }

    if (context.department === 'surgical') {
      return 'EMERGENCY_SURGICAL';
    }

    return 'EMERGENCY_MEDICAL';
  }

  // Psychiatry.
  if (context.department === 'psychiatry') {
    return 'PSYCHIATRY';
  }

  // OBGYN.
  if (
    context.department === 'obgyn' &&
    context.sex === 'female'
  ) {
    return 'ADULT_OBGYN';
  }

  // Surgery.
  if (context.department === 'surgical') {
    return 'ADULT_SURGICAL';
  }

  // Default adult medicine.
  return 'ADULT_MEDICAL';
}

// =============================================================================
// UNIVERSAL SECTION ACTIVATION
// =============================================================================

export interface ClinicalSectionRules {
  /**
   * Sections always present in every ordinary clinical history.
   */
  base: string[];

  /**
   * Sections activated by context.
   */
  additional: string[];

  /**
   * Sections explicitly excluded by context.
   */
  excluded: string[];

  /**
   * Sections elevated to mandatory.
   */
  required: string[];
}

/**
 * These are the canonical AMEXAN history structures.
 *
 * MEDICAL / SURGICAL:
 *   Biodata
 *   Chief Complaint
 *   HPI
 *   PMHx
 *   PSHx
 *   Family History
 *   Social History
 *   ROS
 *   Summary
 *
 * FEMALE MEDICAL/SURGICAL:
 *   Same structure.
 *
 *   Add Obstetric + Gynaecological history ONLY when the clinical context
 *   requires it.
 *
 * PAEDIATRIC:
 *   Biodata
 *   Chief Complaint
 *   HPI
 *   Past Medical/Surgical History
 *   Birth History
 *   Growth & Development
 *   Immunization
 *   Nutrition
 *   Family History
 *   Social History
 *   ROS
 *   Summary
 *
 * NEONATAL:
 *   Neonatal-specific structure.
 *
 * OBGYN:
 *   Biodata
 *   Chief Complaint
 *   HPI
 *   ANC Profile
 *   Obstetric History
 *   Gynaecological History
 *   PMHx/PSHx/Drug/Allergy History
 *   Family History
 *   Social History
 *   ROS
 *   Summary
 *
 * PSYCHIATRY:
 *   Biodata
 *   Chief Complaint
 *   HPI
 *   Psychiatric History
 *   Past Medical History
 *   Past Surgical History
 *   Drug/Substance History
 *   Family History
 *   Personal/Social History
 *   Collateral History
 *   Mental-State-specific ROS / ROS
 *   Risk Assessment
 *   Summary
 */
export function resolveHistorySections(
  context: ClinicalContext,
): ClinicalSectionRules {
  const base = [
    'biodata',
    'chief_complaint',
    'hpi',
  ];

  const additional: string[] = [];
  const excluded: string[] = [];
  const required: string[] = [];

  // ---------------------------------------------------------------------------
  // NEONATAL
  // ---------------------------------------------------------------------------
  if (context.lifeStage === 'neonate') {
    additional.push(
      'birth_history',
      'past_medical_history',
      'drug_history',
      'allergy_history',
      'family_history',
      'social_history',
      'nutrition',
      'review_of_systems',
      'summary',
    );

    required.push(
      'biodata',
      'chief_complaint',
      'hpi',
      'birth_history',
      'nutrition',
      'summary',
    );

    excluded.push(
      'obstetric_history',
      'gynaecological_history',
      'anc_profile',
      'growth_development',
      'immunization',
      'psychiatric_history',
      'sexual_history',
    );

    return {
      base,
      additional,
      excluded,
      required,
    };
  }

  // ---------------------------------------------------------------------------
  // PAEDIATRICS
  // ---------------------------------------------------------------------------
  if (
    context.lifeStage === 'infant' ||
    context.lifeStage === 'child' ||
    context.lifeStage === 'adolescent'
  ) {
    additional.push(
      'past_medical_history',
      'past_surgical_history',
      'drug_history',
      'allergy_history',
      'birth_history',
      'growth_development',
      'immunization',
      'nutrition',
      'family_history',
      'social_history',
      'review_of_systems',
      'summary',
    );

    required.push(
      'biodata',
      'chief_complaint',
      'hpi',
      'birth_history',
      'growth_development',
      'immunization',
      'nutrition',
      'summary',
    );

    excluded.push(
      'obstetric_history',
      'gynaecological_history',
      'anc_profile',
      'psychiatric_history',
    );

    return {
      base,
      additional,
      excluded,
      required,
    };
  }

  // ---------------------------------------------------------------------------
  // PSYCHIATRY
  // ---------------------------------------------------------------------------
  if (context.department === 'psychiatry') {
    additional.push(
      'psychiatric_history',
      'past_medical_history',
      'past_surgical_history',
      'drug_history',
      'allergy_history',
      'substance_history',
      'family_history',
      'social_history',
      'occupational_history',
      'sexual_history',
      'collateral_history',
      'review_of_systems',
      'summary',
    );

    required.push(
      'biodata',
      'chief_complaint',
      'hpi',
      'psychiatric_history',
      'substance_history',
      'collateral_history',
      'summary',
    );

    excluded.push(
      'obstetric_history',
      'gynaecological_history',
      'anc_profile',
      'birth_history',
      'growth_development',
      'immunization',
      'nutrition',
    );

    return {
      base,
      additional,
      excluded,
      required,
    };
  }

  // ---------------------------------------------------------------------------
  // OBGYN
  // ---------------------------------------------------------------------------
  if (
    context.department === 'obgyn' &&
    context.sex === 'female'
  ) {
    additional.push(
      'anc_profile',
      'obstetric_history',
      'gynaecological_history',
      'past_medical_history',
      'past_surgical_history',
      'drug_history',
      'allergy_history',
      'family_history',
      'social_history',
      'review_of_systems',
      'summary',
    );

    required.push(
      'biodata',
      'chief_complaint',
      'hpi',
      'obstetric_history',
      'gynaecological_history',
      'summary',
    );

    // ANC is mandatory specifically for an active pregnancy/antenatal context.
    if (
      context.pregnancyState === 'pregnant' ||
      hasAnyCode(
        context.presentingComplaintCodes,
        new Set([
          'ANTENATAL_CARE',
          'ANC',
          'PREGNANCY',
        ]),
      )
    ) {
      required.push('anc_profile');
    }

    excluded.push(
      'birth_history',
      'growth_development',
      'immunization',
      'nutrition',
      'psychiatric_history',
    );

    return {
      base,
      additional,
      excluded,
      required,
    };
  }

  // ---------------------------------------------------------------------------
  // ADULT MEDICAL / SURGICAL
  // ---------------------------------------------------------------------------
  additional.push(
    'past_medical_history',
    'past_surgical_history',
    'drug_history',
    'allergy_history',
    'family_history',
    'social_history',
    'occupational_history',
    'review_of_systems',
    'summary',
  );

  required.push(
    'biodata',
    'chief_complaint',
    'hpi',
    'summary',
  );

  // Female reproductive-age medical/surgical patients do NOT automatically
  // receive OBGYN sections.
  //
  // They are activated only if the complaint/context is OBGYN relevant.
  if (
    context.sex === 'female' &&
    hasObgynContext({
      sex: context.sex,
      ageYears: context.ageYears,
      pregnancyState: context.pregnancyState,
      presentingComplaintCodes:
        context.presentingComplaintCodes,
    })
  ) {
    additional.push(
      'obstetric_history',
      'gynaecological_history',
    );
  } else {
    excluded.push(
      'obstetric_history',
      'gynaecological_history',
      'anc_profile',
    );
  }

  excluded.push(
    'birth_history',
    'growth_development',
    'immunization',
    'nutrition',
    'psychiatric_history',
    'collateral_history',
  );

  return {
    base,
    additional,
    excluded,
    required,
  };
}

// =============================================================================
// COMPLETE CONTEXT BUILDER
// =============================================================================

export function buildClinicalContext(input: {
  patientId: string;
  encounterId: string | null;

  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  sex: Sex;

  pregnancyState?: PregnancyState | null;

  requestedDepartment?: EncounterDomain | null;
  encounterType?: string | null;

  presentingComplaintCodes?: string[];
  activeSymptomCodes?: string[];

  firstVisit?: boolean;
  emergency?: boolean;
}): ClinicalContext {
  const ageYears =
    input.ageYears != null && Number.isFinite(input.ageYears)
      ? Math.max(0, input.ageYears)
      : null;

  const ageMonths =
    input.ageMonths != null && Number.isFinite(input.ageMonths)
      ? Math.max(0, input.ageMonths)
      : null;

  const ageDays =
    input.ageDays != null && Number.isFinite(input.ageDays)
      ? Math.max(0, input.ageDays)
      : null;

  const presentingComplaintCodes =
    input.presentingComplaintCodes ?? [];

  const activeSymptomCodes =
    input.activeSymptomCodes ?? [];

  // ---------------------------------------------------------------------------
  // AGE
  // ---------------------------------------------------------------------------
  const lifeStage = resolveLifeStage(
    ageYears,
    ageMonths,
    ageDays,
  );

  // ---------------------------------------------------------------------------
  // PREGNANCY
  // ---------------------------------------------------------------------------
  const pregnancyState = resolvePregnancyState(
    input.sex,
    input.pregnancyState,
  );

  // ---------------------------------------------------------------------------
  // EMERGENCY
  // ---------------------------------------------------------------------------
  const emergency = hasEmergencyContext(
    input.emergency ?? false,
    presentingComplaintCodes,
  );

  // ---------------------------------------------------------------------------
  // DEPARTMENT
  // ---------------------------------------------------------------------------
  const department = resolveClinicalDomain({
    sex: input.sex,
    ageYears,
    lifeStage,
    pregnancyState,
    requestedDepartment:
      input.requestedDepartment,
    presentingComplaintCodes,
    emergency,
  });

  return {
    patientId: input.patientId,
    encounterId: input.encounterId,

    ageYears,
    ageMonths,
    ageDays,

    sex: input.sex,
    lifeStage,

    pregnancyState,

    department,
    encounterType:
      input.encounterType ?? null,

    presentingComplaintCodes,
    activeSymptomCodes,

    firstVisit:
      input.firstVisit ?? true,

    emergency,
  };
}

// =============================================================================
// PUBLIC CONTEXT RESOLUTION
// =============================================================================

export interface ResolvedClinicalContext {
  context: ClinicalContext;

  ageBand:
    | 'NEONATE'
    | 'PAEDIATRIC'
    | 'ADULT'
    | 'OLDER_ADULT';

  historyFormat: ClinicalHistoryFormat;

  sections: ClinicalSectionRules;

  femaleReproductiveAge: boolean;

  obgynContext: boolean;

  obstetricContext: boolean;

  gynaecologicalContext: boolean;

  psychiatricContext: boolean;

  emergencyContext: boolean;
}

export function resolveClinicalContext(input: {
  patientId: string;
  encounterId: string | null;

  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  sex: Sex;

  pregnancyState?: PregnancyState | null;

  requestedDepartment?: EncounterDomain | null;
  encounterType?: string | null;

  presentingComplaintCodes?: string[];
  activeSymptomCodes?: string[];

  firstVisit?: boolean;
  emergency?: boolean;
}): ResolvedClinicalContext {
  const context = buildClinicalContext(input);

  const femaleReproductiveAge = isReproductiveAge(
    context.ageYears,
    context.sex,
  );

  const obstetricContext = hasObstetricContext(
    context.sex,
    context.pregnancyState,
    context.presentingComplaintCodes,
  );

  const gynaecologicalContext =
    hasGynaecologicalContext(
      context.sex,
      context.ageYears,
      context.presentingComplaintCodes,
    );

  const obgynContext =
    obstetricContext ||
    gynaecologicalContext;

  const psychiatricContext =
    hasPsychiatricContext(
      context.presentingComplaintCodes,
    ) ||
    context.department === 'psychiatry';

  const emergencyContext =
    context.emergency;

  const ageBand =
    resolveAgeBand(context.lifeStage);

  const historyFormat =
    resolveHistoryFormat({ context });

  const sections =
    resolveHistorySections(context);

  return {
    context,
    ageBand,
    historyFormat,
    sections,
    femaleReproductiveAge,
    obgynContext,
    obstetricContext,
    gynaecologicalContext,
    psychiatricContext,
    emergencyContext,
  };
}

// =============================================================================
// HARD SAFETY / CONSISTENCY ASSERTIONS
// =============================================================================

/**
 * These checks are useful before the context reaches the CPU projection
 * layer. They prevent impossible UI/database states.
 */
export function validateClinicalContext(
  context: ClinicalContext,
): string[] {
  const errors: string[] = [];

  // ---------------------------------------------------------------------------
  // Male pregnancy state is impossible.
  // ---------------------------------------------------------------------------
  if (
    context.sex !== 'female' &&
    context.pregnancyState !== 'not_applicable'
  ) {
    errors.push(
      'Non-female patient cannot have a pregnancy state other than not_applicable.',
    );
  }

  // ---------------------------------------------------------------------------
  // Neonates must be neonatology.
  // ---------------------------------------------------------------------------
  if (
    context.lifeStage === 'neonate' &&
    context.department !== 'neonatology' &&
    context.department !== 'emergency'
  ) {
    errors.push(
      'Neonatal patient must use neonatology or an emergency operational domain.',
    );
  }

  // ---------------------------------------------------------------------------
  // Paediatric ages must not use adult-only medical/surgical/OBGYN domains.
  // ---------------------------------------------------------------------------
  if (
    (
      context.lifeStage === 'infant' ||
      context.lifeStage === 'child' ||
      context.lifeStage === 'adolescent'
    ) &&
    (
      context.department === 'obgyn' ||
      context.department === 'medical' ||
      context.department === 'surgical'
    )
  ) {
    errors.push(
      'Paediatric/adolescent patient cannot use an adult-only operational domain.',
    );
  }

  // ---------------------------------------------------------------------------
  // OBGYN must be female.
  // ---------------------------------------------------------------------------
  if (
    context.department === 'obgyn' &&
    context.sex !== 'female'
  ) {
    errors.push(
      'OBGYN domain cannot be assigned to a non-female patient.',
    );
  }

  return errors;
}

// =============================================================================
// FORMAT SUMMARY FOR CPU / DEBUG / TESTING
// =============================================================================

export function describeClinicalContext(
  resolved: ResolvedClinicalContext,
): Record<string, unknown> {
  return {
    patientId: resolved.context.patientId,
    encounterId: resolved.context.encounterId,

    ageYears: resolved.context.ageYears,
    ageMonths: resolved.context.ageMonths,
    ageDays: resolved.context.ageDays,

    lifeStage: resolved.context.lifeStage,
    ageBand: resolved.ageBand,

    sex: resolved.context.sex,
    pregnancyState:
      resolved.context.pregnancyState,

    department:
      resolved.context.department,

    historyFormat:
      resolved.historyFormat,

    femaleReproductiveAge:
      resolved.femaleReproductiveAge,

    obgynContext:
      resolved.obgynContext,

    obstetricContext:
      resolved.obstetricContext,

    gynaecologicalContext:
      resolved.gynaecologicalContext,

    psychiatricContext:
      resolved.psychiatricContext,

    emergencyContext:
      resolved.emergencyContext,

    visibleSections:
      resolved.sections.base
        .concat(resolved.sections.additional)
        .filter(
          (section) =>
            !resolved.sections.excluded.includes(
              section,
            ),
        ),

    requiredSections:
      resolved.sections.required,
  };
}