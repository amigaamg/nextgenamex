// =============================================================================
// src/clinical/history.ts
// AMEXAN UNIVERSAL HISTORY FORMAT ENGINE
//
// RULE:
// The UI NEVER decides which history sections exist.
// The CPU resolves the format from:
//   sex + exact age + life stage + pregnancy state + department + encounter type.
//
// The UI receives HistorySectionDefinition[] and renders exactly what the CPU
// projects.
//
// UNIVERSAL FORMAT MATRIX
//
// ADULT MEDICAL / SURGICAL / EMERGENCY
//   Biodata
//   Chief Complaint
//   HPI
//   PMHx
//   PSHx
//   Drug History
//   Allergy History
//   Family History
//   Social History
//   Occupational History
//   ROS
//   Summary
//
// ADULT FEMALE OF REPRODUCTIVE POTENTIAL IN MEDICAL/SURGICAL/EMERGENCY
//   Biodata
//   Chief Complaint
//   HPI
//   Obstetric History
//   Gynaecological History
//   PMHx
//   PSHx
//   Drug History
//   Allergy History
//   Family History
//   Social History
//   Occupational History
//   ROS
//   Summary
//
// OBGYN
//   Biodata
//   Chief Complaint
//   HPI
//   ANC Profile              -> required when pregnant
//   Obstetric History
//   Gynaecological History
//   PMHx
//   PSHx
//   Drug History
//   Allergy History
//   Family History
//   Social History
//   Sexual History
//   ROS
//   Summary
//
// PEDIATRICS
//   Biodata
//   Chief Complaint
//   HPI
//   PMHx
//   PSHx
//   Birth History
//   Growth & Development
//   Immunization
//   Nutrition
//   Drug History
//   Allergy History
//   Family History
//   Social History
//   ROS
//   Summary
//
// NEONATOLOGY
//   Applies from birth through 28 completed days.
//   Biodata
//   Chief Complaint
//   HPI
//   Birth History
//   Maternal / Antenatal History
//   Neonatal History
//   Feeding / Nutrition
//   Drug History
//   Allergy History
//   Family History
//   ROS
//   Summary
//
// PSYCHIATRY
//   Biodata
//   Chief Complaint
//   HPI
//   Psychiatric History
//   PMHx
//   PSHx
//   Drug History
//   Allergy History
//   Substance History
//   Family History
//   Social History
//   Occupational History
//   Collateral History
//   ROS
//   Summary
//
// IMPORTANT:
// - A male patient NEVER receives obstetric, gynaecological or ANC sections.
// - A non-reproductive female does NOT automatically receive OBGYN history.
// - A reproductive-age female in medical/surgical/emergency DOES receive
//   obstetric + gynaecological history.
// - Pregnancy/postpartum or an OBGYN encounter resolves to OBGYN.
// - Neonates ALWAYS resolve to NEONATOLOGY.
// - Patients <18 years resolve to PEDIATRICS unless neonatology applies.
// - Psychiatry resolves to PSYCHIATRY for patients outside neonatal rules.
// - Medical and surgical use the same universal adult history structure,
//   while the department remains part of the clinical context.
// - Emergency uses the same universal adult history unless CPU knowledge
//   later activates an emergency-specific subsection.
// =============================================================================

import type {
  ClinicalContext,
  HistorySection,
  HistorySectionDefinition,
} from './types';

// =============================================================================
// FORMAT DEFINITIONS
// =============================================================================

const ADULT_CORE: HistorySection[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'past_medical_history',
  'past_surgical_history',
  'drug_history',
  'allergy_history',
  'family_history',
  'social_history',
  'occupational_history',
  'review_of_systems',
  'summary',
];

const ADULT_FEMALE_REPRODUCTIVE: HistorySection[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'obstetric_history',
  'gynaecological_history',
  'past_medical_history',
  'past_surgical_history',
  'drug_history',
  'allergy_history',
  'family_history',
  'social_history',
  'occupational_history',
  'review_of_systems',
  'summary',
];

const OBGYN_FORMAT: HistorySection[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'anc_profile',
  'obstetric_history',
  'gynaecological_history',
  'past_medical_history',
  'past_surgical_history',
  'drug_history',
  'allergy_history',
  'family_history',
  'social_history',
  'sexual_history',
  'review_of_systems',
  'summary',
];

const PAEDIATRIC_FORMAT: HistorySection[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'past_medical_history',
  'past_surgical_history',
  'birth_history',
  'growth_development',
  'immunization',
  'nutrition',
  'drug_history',
  'allergy_history',
  'family_history',
  'social_history',
  'review_of_systems',
  'summary',
];

const NEONATAL_FORMAT: HistorySection[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'birth_history',
  'anc_profile',
  'past_medical_history',
  'drug_history',
  'allergy_history',
  'family_history',
  'nutrition',
  'review_of_systems',
  'summary',
];

const PSYCHIATRY_FORMAT: HistorySection[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'psychiatric_history',
  'past_medical_history',
  'past_surgical_history',
  'drug_history',
  'allergy_history',
  'substance_history',
  'family_history',
  'social_history',
  'occupational_history',
  'collateral_history',
  'review_of_systems',
  'summary',
];

// =============================================================================
// AGE CONSTANTS
// =============================================================================

const NEONATAL_MAX_DAYS = 28;
const PAEDIATRIC_MAX_YEARS = 18;
const REPRODUCTIVE_MIN_YEARS = 12;
const REPRODUCTIVE_MAX_YEARS = 55;

// =============================================================================
// AGE RESOLUTION
// =============================================================================

function exactAgeInDays(context: ClinicalContext): number | null {
  if (context.ageDays != null) {
    return context.ageDays;
  }

  if (context.ageMonths != null) {
    return context.ageMonths * 30.4375;
  }

  if (context.ageYears != null) {
    return context.ageYears * 365.2425;
  }

  return null;
}

function isNeonate(context: ClinicalContext): boolean {
  const days = exactAgeInDays(context);

  return (
    context.lifeStage === 'neonate' ||
    (days != null && days >= 0 && days <= NEONATAL_MAX_DAYS)
  );
}

function isPaediatric(context: ClinicalContext): boolean {
  if (isNeonate(context)) return false;

  if (
    context.lifeStage === 'infant' ||
    context.lifeStage === 'child' ||
    context.lifeStage === 'adolescent'
  ) {
    return true;
  }

  if (context.ageYears != null) {
    return context.ageYears < PAEDIATRIC_MAX_YEARS;
  }

  return false;
}

// SEX / REPRODUCTIVE RULES
// =============================================================================

function isFemale(context: ClinicalContext): boolean {
  return context.sex === 'female';
}

function isReproductiveAgeFemale(context: ClinicalContext): boolean {
  if (!isFemale(context)) return false;

  if (context.ageYears == null) return false;

  return (
    context.ageYears >= REPRODUCTIVE_MIN_YEARS &&
    context.ageYears <= REPRODUCTIVE_MAX_YEARS
  );
}

function isPregnant(context: ClinicalContext): boolean {
  return (
    isFemale(context) &&
    context.pregnancyState === 'pregnant'
  );
}

function isPostpartum(context: ClinicalContext): boolean {
  return (
    isFemale(context) &&
    context.pregnancyState === 'postpartum'
  );
}

// =============================================================================
// DEPARTMENT RULES
// =============================================================================

function isObgynEncounter(context: ClinicalContext): boolean {
  return (
    context.department === 'obgyn' ||
    isPregnant(context) ||
    isPostpartum(context)
  );
}

function isPsychiatryEncounter(context: ClinicalContext): boolean {
  return context.department === 'psychiatry';
}

function isPaediatricEncounter(context: ClinicalContext): boolean {
  return (
    context.department === 'paediatrics' ||
    isPaediatric(context)
  );
}

function isNeonatalEncounter(context: ClinicalContext): boolean {
  return (
    context.department === 'neonatology' ||
    isNeonate(context)
  );
}

// =============================================================================
// FORMAT RESOLUTION
// =============================================================================

export type ClinicalHistoryFormat =
  | 'ADULT_MEDICAL'
  | 'ADULT_SURGICAL'
  | 'ADULT_FEMALE_REPRODUCTIVE'
  | 'EMERGENCY_ADULT'
  | 'OBGYN'
  | 'PAEDIATRIC'
  | 'NEONATAL'
  | 'PSYCHIATRY';

export function resolveHistoryFormat(
  context: ClinicalContext,
): ClinicalHistoryFormat {
  // Rule 1:
  // Neonatal age ALWAYS wins over department.
  if (isNeonate(context)) {
    return 'NEONATAL';
  }

  // Rule 2:
  // Anyone under 18 is paediatric unless neonatal.
  if (isPaediatricEncounter(context)) {
    return 'PAEDIATRIC';
  }

  // Rule 3:
  // Psychiatry gets psychiatric history.
  if (isPsychiatryEncounter(context)) {
    return 'PSYCHIATRY';
  }

  // Rule 4:
  // Pregnancy/postpartum/OBGYN automatically activates OBGYN.
  if (isObgynEncounter(context)) {
    return 'OBGYN';
  }

  // Rule 5:
  // Female reproductive-age patients in medical/surgical/emergency
  // receive OB + GYN history even though the encounter itself is not OBGYN.
  if (isReproductiveAgeFemale(context)) {
    return 'ADULT_FEMALE_REPRODUCTIVE';
  }

  // Rule 6:
  // Emergency adult patients use adult universal structure.
  if (context.department === 'emergency') {
    return 'EMERGENCY_ADULT';
  }

  // Rule 7:
  // Surgical and medical use the universal adult structure.
  if (context.department === 'surgical') {
    return 'ADULT_SURGICAL';
  }

  return 'ADULT_MEDICAL';
}

// =============================================================================
// SECTION SELECTION
// =============================================================================

export function selectHistorySections(
  context: ClinicalContext,
): HistorySection[] {
  const format = resolveHistoryFormat(context);

  switch (format) {
    case 'NEONATAL':
      return [...NEONATAL_FORMAT];

    case 'PAEDIATRIC':
      return [...PAEDIATRIC_FORMAT];

    case 'PSYCHIATRY':
      return [...PSYCHIATRY_FORMAT];

    case 'OBGYN':
      return [...OBGYN_FORMAT];

    case 'ADULT_FEMALE_REPRODUCTIVE':
      return [...ADULT_FEMALE_REPRODUCTIVE];

    case 'ADULT_SURGICAL':
    case 'ADULT_MEDICAL':
    case 'EMERGENCY_ADULT':
    default:
      return [...ADULT_CORE];
  }
}

// =============================================================================
// SECTION VISIBILITY
// =============================================================================

export function isHistorySectionVisible(
  section: HistorySection,
  context: ClinicalContext,
): boolean {
  // ---------------------------------------------------------------------------
  // Absolute sex safety rules
  // ---------------------------------------------------------------------------

  if (
    section === 'obstetric_history' ||
    section === 'gynaecological_history' ||
    section === 'anc_profile' ||
    section === 'sexual_history'
  ) {
    if (!isFemale(context)) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Neonatal-only sections
  // ---------------------------------------------------------------------------

  if (section === 'birth_history' && !isNeonatalEncounter(context)) {
    return isPaediatricEncounter(context);
  }

  if (
    section === 'anc_profile' &&
    !isObgynEncounter(context) &&
    !isNeonatalEncounter(context)
  ) {
    return false;
  }

  // ---------------------------------------------------------------------------
  // Paediatric sections
  // ---------------------------------------------------------------------------

  const paediatricOnly: HistorySection[] = [
    'growth_development',
    'immunization',
    'nutrition',
  ];

  if (
    paediatricOnly.includes(section) &&
    !isPaediatricEncounter(context) &&
    !isNeonatalEncounter(context)
  ) {
    return false;
  }

  // ---------------------------------------------------------------------------
  // Psychiatry-specific sections
  // ---------------------------------------------------------------------------

  const psychiatryOnly: HistorySection[] = [
    'psychiatric_history',
    'substance_history',
    'collateral_history',
  ];

  if (
    psychiatryOnly.includes(section) &&
    !isPsychiatryEncounter(context)
  ) {
    return false;
  }

  return true;
}

// =============================================================================
// REQUIREDNESS
// =============================================================================

export function isHistorySectionRequired(
  section: HistorySection,
  context: ClinicalContext,
): boolean {
  // Universal mandatory opening.
  if (
    section === 'biodata' ||
    section === 'chief_complaint' ||
    section === 'hpi'
  ) {
    return true;
  }

  // ---------------------------------------------------------------------------
  // Neonatal mandatory sections
  // ---------------------------------------------------------------------------

  if (isNeonatalEncounter(context)) {
    if (
      section === 'birth_history' ||
      section === 'anc_profile'
    ) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Paediatric mandatory sections
  // ---------------------------------------------------------------------------

  if (isPaediatricEncounter(context)) {
    if (
      section === 'birth_history' ||
      section === 'growth_development' ||
      section === 'immunization' ||
      section === 'nutrition'
    ) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // OBGYN rules
  // ---------------------------------------------------------------------------

  if (isObgynEncounter(context)) {
    if (
      section === 'obstetric_history' ||
      section === 'gynaecological_history'
    ) {
      return true;
    }

    if (
      section === 'anc_profile' &&
      context.pregnancyState === 'pregnant'
    ) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Reproductive-age female medical/surgical rules
  // ---------------------------------------------------------------------------

  if (
    isReproductiveAgeFemale(context) &&
    !isObgynEncounter(context)
  ) {
    if (
      section === 'obstetric_history' ||
      section === 'gynaecological_history'
    ) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Psychiatry rules
  // ---------------------------------------------------------------------------

  if (isPsychiatryEncounter(context)) {
    if (section === 'psychiatric_history') {
      return true;
    }

    if (section === 'substance_history') {
      return true;
    }

    if (section === 'collateral_history') {
      return true;
    }
  }

  return false;
}

// =============================================================================
// PRIORITY
// =============================================================================

export function historySectionPriority(
  section: HistorySection,
  context: ClinicalContext,
): number {
  if (section === 'biodata') return 100;
  if (section === 'chief_complaint') return 100;
  if (section === 'hpi') return 100;

  if (
    isNeonatalEncounter(context) &&
    section === 'birth_history'
  ) {
    return 100;
  }

  if (
    isObgynEncounter(context) &&
    context.pregnancyState === 'pregnant' &&
    section === 'anc_profile'
  ) {
    return 100;
  }

  if (
    isPaediatricEncounter(context) &&
    [
      'birth_history',
      'growth_development',
      'immunization',
      'nutrition',
    ].includes(section)
  ) {
    return 90;
  }

  if (
    isPsychiatryEncounter(context) &&
    section === 'psychiatric_history'
  ) {
    return 95;
  }

  if (
    isReproductiveAgeFemale(context) &&
    !isObgynEncounter(context) &&
    [
      'obstetric_history',
      'gynaecological_history',
    ].includes(section)
  ) {
    return 90;
  }

  return 50;
}

// =============================================================================
// LABELS
// =============================================================================

export function historyLabel(
  code: HistorySection,
): string {
  const labels: Record<HistorySection, string> = {
    biodata: 'Biodata',

    chief_complaint: 'Chief Complaint',

    hpi: 'History of Present Illness',

    past_medical_history: 'Past Medical History',

    past_surgical_history: 'Past Surgical History',

    drug_history: 'Drug History',

    allergy_history: 'Allergy History',

    family_history: 'Family History',

    social_history: 'Social History',

    occupational_history: 'Occupational History',

    sexual_history: 'Sexual History',

    review_of_systems: 'Review of Systems',

    obstetric_history: 'Obstetric History',

    gynaecological_history: 'Gynaecological History',

    anc_profile: 'ANC Profile',

    birth_history: 'Birth History',

    growth_development: 'Growth & Development',

    immunization: 'Immunization',

    nutrition: 'Nutrition',

    psychiatric_history: 'Psychiatric History',

    substance_history: 'Substance History',

    collateral_history: 'Collateral / Informant History',

    maternal_history: 'Maternal History',

    summary: 'Clinical Summary',
  };

  return labels[code];
}

// =============================================================================
// FULL SECTION PROJECTION
//
// This is the function the CPU should call when creating the navigation
// projection consumed by the clinical UI.
// =============================================================================

export function buildHistorySections(
  context: ClinicalContext,
): HistorySectionDefinition[] {
  const selected = selectHistorySections(context);

  return selected
    .filter((code) => isHistorySectionVisible(code, context))
    .map((code, index) => ({
      code,
      label: historyLabel(code),
      sequence: index + 1,
      required: isHistorySectionRequired(code, context),
      visible: true,
    }));
}

// =============================================================================
// FORMAT METADATA
//
// Useful for the CPU projection, documentation engine and UI header.
// =============================================================================

export interface HistoryFormatMetadata {
  format: ClinicalHistoryFormat;
  label: string;
  department: string;
  ageBand: string;
  femaleReproductiveModule: boolean;
  obstetricModule: boolean;
  gynaecologicalModule: boolean;
  neonatalModule: boolean;
  paediatricModule: boolean;
  psychiatryModule: boolean;
}

export function getHistoryFormatMetadata(
  context: ClinicalContext,
): HistoryFormatMetadata {
  const format = resolveHistoryFormat(context);

  return {
    format,

    label: format
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase()),

    department: context.department,

    ageBand: context.lifeStage,

    femaleReproductiveModule:
      format === 'ADULT_FEMALE_REPRODUCTIVE' ||
      format === 'OBGYN',

    obstetricModule:
      format === 'ADULT_FEMALE_REPRODUCTIVE' ||
      format === 'OBGYN' ||
      format === 'NEONATAL',

    gynaecologicalModule:
      format === 'ADULT_FEMALE_REPRODUCTIVE' ||
      format === 'OBGYN',

    neonatalModule:
      format === 'NEONATAL',

    paediatricModule:
      format === 'PAEDIATRIC',

    psychiatryModule:
      format === 'PSYCHIATRY',
  };
}

// =============================================================================
// HARD SAFETY VALIDATION
//
// This should be called before a projection is emitted.
// It prevents impossible UI states such as:
//   male + obstetric history
//   neonate + adult-only occupational history
//   child + ANC profile
//   non-psychiatric patient + psychiatric-only section
// =============================================================================

export function validateHistoryFormat(
  context: ClinicalContext,
  sections: HistorySection[],
): string[] {
  const errors: string[] = [];

  // Male patients can NEVER receive female reproductive sections.
  if (!isFemale(context)) {
    const forbiddenForMale: HistorySection[] = [
      'obstetric_history',
      'gynaecological_history',
      'anc_profile',
      'sexual_history',
    ];

    for (const section of sections) {
      if (forbiddenForMale.includes(section)) {
        errors.push(
          `INVALID_FORMAT: ${section} cannot be rendered for sex=${context.sex}`,
        );
      }
    }
  }

  // Neonates cannot receive adult occupational history.
  if (isNeonatalEncounter(context)) {
    if (sections.includes('occupational_history')) {
      errors.push(
        'INVALID_FORMAT: occupational_history cannot be rendered for a neonate',
      );
    }

    if (sections.includes('psychiatric_history')) {
      errors.push(
        'INVALID_FORMAT: psychiatric_history cannot be rendered for a neonate',
      );
    }
  }

  // Children should not receive adult reproductive history.
  if (isPaediatricEncounter(context)) {
    if (
      sections.includes('obstetric_history') ||
      sections.includes('gynaecological_history')
    ) {
      errors.push(
        'INVALID_FORMAT: adult obstetric/gynaecological history cannot be rendered in paediatric format',
      );
    }

    if (sections.includes('occupational_history')) {
      errors.push(
        'INVALID_FORMAT: occupational_history cannot be rendered in paediatric format',
      );
    }
  }

  // ANC is pregnancy/OBGYN/neonatal-context only.
  if (
    sections.includes('anc_profile') &&
    !isObgynEncounter(context) &&
    !isNeonatalEncounter(context)
  ) {
    errors.push(
      'INVALID_FORMAT: ANC profile requires an OBGYN, pregnancy, postpartum, or neonatal context',
    );
  }

  // Psychiatry-only sections.
  if (!isPsychiatryEncounter(context)) {
    const psychiatrySections: HistorySection[] = [
      'psychiatric_history',
      'substance_history',
      'collateral_history',
    ];

    for (const section of sections) {
      if (psychiatrySections.includes(section)) {
        errors.push(
          `INVALID_FORMAT: ${section} requires psychiatry context`,
        );
      }
    }
  }

  return errors;
}

// =============================================================================
// ASSERTION
// =============================================================================

export function assertValidHistoryFormat(
  context: ClinicalContext,
  sections: HistorySection[],
): void {
  const errors = validateHistoryFormat(context, sections);

  if (errors.length > 0) {
    throw new Error(errors.join('\n'));
  }
}