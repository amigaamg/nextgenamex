// =============================================================================
// src/clinical/navigation.ts
// AMEXAN UNIVERSAL CLINICAL NAVIGATION ENGINE
//
// RULE:
// CPU/context controls navigation.
// UI only renders the projection.
//
// Navigation is dynamically derived from:
// - age / life stage
// - sex
// - pregnancy state
// - department
// - encounter type
// - emergency state
// - section requirements
// - captured facts
// - unanswered mandatory questions
// - active clinical workflow
//
// The UI must NEVER decide that a section applies to a patient.
// =============================================================================

import type {
  ClinicalContext,
  ClinicalFact,
  ClinicalNavigationItem,
  HistorySectionDefinition,
  HistorySection,
} from './types';

// -----------------------------------------------------------------------------
// Internal section classification
// -----------------------------------------------------------------------------

const ALWAYS_VISIBLE_SECTIONS = new Set<HistorySection>([
  'biodata',
  'chief_complaint',
  'hpi',
  'past_medical_history',
  'past_surgical_history',
  'drug_history',
  'allergy_history',
  'family_history',
  'social_history',
  'review_of_systems',
  'summary',
]);

const FEMALE_ONLY_SECTIONS = new Set<HistorySection>([
  'obstetric_history',
  'gynaecological_history',
  'anc_profile',
  'sexual_history',
]);

const PAEDIATRIC_SECTIONS = new Set<HistorySection>([
  'birth_history',
  'growth_development',
  'immunization',
  'nutrition',
]);

const NEONATAL_SECTIONS = new Set<HistorySection>([
  'birth_history',
  'maternal_history' as HistorySection,
]);

const PSYCHIATRY_SECTIONS = new Set<HistorySection>([
  'psychiatric_history',
  'substance_history',
  'collateral_history',
  'occupational_history',
]);

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

function hasFactForSection(
  facts: ClinicalFact[],
  section: HistorySection,
): boolean {
  return facts.some((fact) => fact.section === section);
}

function countFactsForSection(
  facts: ClinicalFact[],
  section: HistorySection,
): number {
  return facts.filter((fact) => fact.section === section).length;
}

function isFemale(context: ClinicalContext): boolean {
  return context.sex === 'female';
}

function isReproductiveAge(context: ClinicalContext): boolean {
  if (!isFemale(context)) return false;

  if (context.ageYears == null) return false;

  return context.ageYears >= 12 && context.ageYears <= 55;
}

function isPregnant(context: ClinicalContext): boolean {
  return context.pregnancyState === 'pregnant';
}

function isPostpartum(context: ClinicalContext): boolean {
  return context.pregnancyState === 'postpartum';
}

function isObstetricContext(context: ClinicalContext): boolean {
  return (
    context.department === 'obgyn' ||
    isPregnant(context) ||
    isPostpartum(context)
  );
}

function isPaediatricContext(context: ClinicalContext): boolean {
  return (
    context.lifeStage === 'neonate' ||
    context.lifeStage === 'infant' ||
    context.lifeStage === 'child' ||
    context.lifeStage === 'adolescent' ||
    context.department === 'paediatrics' ||
    context.department === 'neonatology'
  );
}

function isNeonatalContext(context: ClinicalContext): boolean {
  return (
    context.lifeStage === 'neonate' ||
    context.department === 'neonatology'
  );
}

function isPsychiatricContext(context: ClinicalContext): boolean {
  return context.department === 'psychiatry';
}

// -----------------------------------------------------------------------------
// Section applicability
// -----------------------------------------------------------------------------

function sectionApplies(
  section: HistorySection,
  context: ClinicalContext,
): boolean {
  // ---------------------------------------------------------------------------
  // Universal sections
  // ---------------------------------------------------------------------------

  if (ALWAYS_VISIBLE_SECTIONS.has(section)) {
    return true;
  }

  // ---------------------------------------------------------------------------
  // Male patients NEVER receive female reproductive history
  // ---------------------------------------------------------------------------

  if (FEMALE_ONLY_SECTIONS.has(section)) {
    return isFemale(context);
  }

  // ---------------------------------------------------------------------------
  // Paediatric sections
  // ---------------------------------------------------------------------------

  if (PAEDIATRIC_SECTIONS.has(section)) {
    return isPaediatricContext(context);
  }

  // ---------------------------------------------------------------------------
  // Neonatal sections
  // ---------------------------------------------------------------------------

  if (NEONATAL_SECTIONS.has(section)) {
    return isNeonatalContext(context);
  }

  // ---------------------------------------------------------------------------
  // Psychiatry
  // ---------------------------------------------------------------------------

  if (PSYCHIATRY_SECTIONS.has(section)) {
    return isPsychiatricContext(context);
  }

  // ---------------------------------------------------------------------------
  // Pregnancy-specific ANC
  // ---------------------------------------------------------------------------

  if (section === 'anc_profile') {
    return isObstetricContext(context);
  }

  // ---------------------------------------------------------------------------
  // Obstetric history
  // ---------------------------------------------------------------------------

  if (section === 'obstetric_history') {
    return isObstetricContext(context);
  }

  // ---------------------------------------------------------------------------
  // Gynaecological history
  //
  // Female reproductive patients may require Gyn history even outside OBGYN.
  // In OBGYN it is always available.
  // ---------------------------------------------------------------------------

  if (section === 'gynaecological_history') {
    return (
      isFemale(context) &&
      (isReproductiveAge(context) || isObstetricContext(context))
    );
  }

  // ---------------------------------------------------------------------------
  // Sexual history
  //
  // Female reproductive / OBGYN / psychiatry contexts may expose it.
  // Male patients may also require sexual history in appropriate contexts.
  // Therefore this is NOT a blanket female-only section.
  // ---------------------------------------------------------------------------

  if (section === 'sexual_history') {
    return (
      isObstetricContext(context) ||
      isPsychiatricContext(context) ||
      isReproductiveAge(context)
    );
  }

  // ---------------------------------------------------------------------------
  // Substance history
  // ---------------------------------------------------------------------------

  if (section === 'substance_history') {
    return (
      context.lifeStage === 'adolescent' ||
      context.lifeStage === 'adult' ||
      context.lifeStage === 'older_adult' ||
      isPsychiatricContext(context)
    );
  }

  // ---------------------------------------------------------------------------
  // Collateral history
  // ---------------------------------------------------------------------------

  if (section === 'collateral_history') {
    return (
      isPsychiatricContext(context) ||
      context.lifeStage === 'neonate' ||
      context.lifeStage === 'infant' ||
      context.lifeStage === 'child'
    );
  }

  // ---------------------------------------------------------------------------
  // Occupational history
  // ---------------------------------------------------------------------------

  if (section === 'occupational_history') {
    return (
      context.lifeStage === 'adult' ||
      context.lifeStage === 'older_adult' ||
      isPsychiatricContext(context)
    );
  }

  // ---------------------------------------------------------------------------
  // Default: if the CPU explicitly supplied the section, allow it.
  // ----------------------------------------------------------------------------

  return true;
}

// -----------------------------------------------------------------------------
// Section priority
// -----------------------------------------------------------------------------

function sectionPriority(
  section: HistorySection,
  context: ClinicalContext,
): number {
  if (section === 'biodata') return 100;
  if (section === 'chief_complaint') return 95;

  if (context.emergency) {
    if (section === 'hpi') return 100;
    if (section === 'review_of_systems') return 85;
    if (section === 'past_medical_history') return 80;
  }

  if (section === 'hpi') return 90;

  if (isNeonatalContext(context)) {
    if (section === 'birth_history') return 88;
    if (section === 'maternal_history') return 87;
  }

  if (isObstetricContext(context)) {
    if (section === 'anc_profile' && isPregnant(context)) return 92;
    if (section === 'obstetric_history') return 88;
    if (section === 'gynaecological_history') return 82;
  }

  if (isPaediatricContext(context)) {
    if (section === 'birth_history') return 86;
    if (section === 'growth_development') return 84;
    if (section === 'immunization') return 82;
    if (section === 'nutrition') return 80;
  }

  if (isPsychiatricContext(context)) {
    if (section === 'psychiatric_history') return 88;
    if (section === 'substance_history') return 82;
    if (section === 'collateral_history') return 80;
  }

  if (section === 'family_history') return 65;
  if (section === 'social_history') return 60;
  if (section === 'occupational_history') return 58;
  if (section === 'sexual_history') return 55;
  if (section === 'review_of_systems') return 50;
  if (section === 'summary') return 10;

  return 40;
}

// -----------------------------------------------------------------------------
// Requiredness
// -----------------------------------------------------------------------------

function sectionIsRequired(
  section: HistorySection,
  context: ClinicalContext,
  definition: HistorySectionDefinition,
): boolean {
  // CPU-provided required state has highest authority.
  if (definition.required) return true;

  // Universal minimum.
  if (
    section === 'biodata' ||
    section === 'chief_complaint' ||
    section === 'hpi'
  ) {
    return true;
  }

  // Neonatal minimum.
  if (
    isNeonatalContext(context) &&
    section === 'birth_history'
  ) {
    return true;
  }

  // Paediatric core.
  if (
    isPaediatricContext(context) &&
    section === 'growth_development'
  ) {
    return true;
  }

  if (
    isPaediatricContext(context) &&
    section === 'immunization'
  ) {
    return true;
  }

  // OBGYN.
  if (isObstetricContext(context)) {
    if (section === 'obstetric_history') return true;
    if (section === 'gynaecological_history') return true;
  }

  // ANC is mandatory only when actually pregnant.
  if (
    section === 'anc_profile' &&
    isPregnant(context)
  ) {
    return true;
  }

  // Psychiatry.
  if (
    isPsychiatricContext(context) &&
    section === 'psychiatric_history'
  ) {
    return true;
  }

  return false;
}

// -----------------------------------------------------------------------------
// Locked-state rules
//
// A section may exist but remain locked until prerequisites are captured.
// -----------------------------------------------------------------------------

function sectionIsLocked(
  section: HistorySection,
  context: ClinicalContext,
  facts: ClinicalFact[],
): boolean {
  if (context.emergency) {
    // Emergency does not lock essential history.
    if (
      section === 'biodata' ||
      section === 'chief_complaint' ||
      section === 'hpi'
    ) {
      return false;
    }

    // In an emergency, non-critical historical sections may wait.
    if (
      section === 'summary' ||
      section === 'review_of_systems'
    ) {
      return false;
    }
  }

  // Nothing should block biodata.
  if (section === 'biodata') return false;

  // CC requires biodata.
  if (
    section === 'chief_complaint' &&
    !hasFactForSection(facts, 'biodata')
  ) {
    return true;
  }

  // HPI requires CC.
  if (
    section === 'hpi' &&
    !hasFactForSection(facts, 'chief_complaint')
  ) {
    return true;
  }

  // Other history sections require at least a started HPI,
  // unless the clinical context makes them independently urgent.
  const coreHistorySections: HistorySection[] = [
    'past_medical_history',
    'past_surgical_history',
    'drug_history',
    'allergy_history',
    'family_history',
    'social_history',
    'occupational_history',
    'sexual_history',
    'review_of_systems',
  ];

  if (
    coreHistorySections.includes(section) &&
    !hasFactForSection(facts, 'hpi')
  ) {
    return true;
  }

  return false;
}

// -----------------------------------------------------------------------------
// Attention rules
// -----------------------------------------------------------------------------

function sectionNeedsAttention(
  section: HistorySection,
  context: ClinicalContext,
  facts: ClinicalFact[],
): boolean {
  const count = countFactsForSection(facts, section);

  if (section === 'hpi' && count === 0) return true;

  if (
    section === 'family_history' &&
    count === 0 &&
    context.lifeStage !== 'neonate'
  ) {
    return true;
  }

  if (
    section === 'social_history' &&
    count === 0 &&
    (
      context.lifeStage === 'adult' ||
      context.lifeStage === 'older_adult'
    )
  ) {
    return true;
  }

  if (
    isPsychiatricContext(context) &&
    section === 'collateral_history' &&
    count === 0
  ) {
    return true;
  }

   if (
    isNeonatalContext(context) &&
    section === 'maternal_history' &&
    count === 0
  ) {
    return true;
  }

  return false;
}

// -----------------------------------------------------------------------------
// Completion calculation
// -----------------------------------------------------------------------------

function countRequiredFacts(
  section: HistorySection,
  facts: ClinicalFact[],
): number {
  return countFactsForSection(facts, section);
}

// -----------------------------------------------------------------------------
// Build navigation projection
// -----------------------------------------------------------------------------

export function buildNavigation(
  context: ClinicalContext,
  sections: HistorySectionDefinition[],
  facts: ClinicalFact[],
): ClinicalNavigationItem[] {
  const visibleSections = sections.filter((section) =>
    section.visible && sectionApplies(section.code, context),
  );

  return visibleSections
    .sort((a, b) => {
      const priorityA = sectionPriority(a.code, context);
      const priorityB = sectionPriority(b.code, context);

      if (priorityA !== priorityB) {
        return priorityB - priorityA;
      }

      return a.sequence - b.sequence;
    })
    .map((section) => {
      const sectionCode = section.code;

      const applicable = sectionApplies(sectionCode, context);

      if (!applicable) {
        return {
          id: sectionCode,
          label: section.label,
          visible: false,
          enabled: false,
          completed: false,
          pending: 0,
          urgent: 0,
        };
      }

      const factCount = countRequiredFacts(sectionCode, facts);

      const required =
        sectionIsRequired(
          sectionCode,
          context,
          section,
        );

      const locked =
        sectionIsLocked(
          sectionCode,
          context,
          facts,
        );

      const attention =
        sectionNeedsAttention(
          sectionCode,
          context,
          facts,
        );

      const completed =
        required
          ? factCount > 0
          : factCount > 0;

      const pending =
        required && !completed
          ? 1
          : 0;

      const urgent =
        context.emergency &&
        (
          sectionCode === 'hpi' ||
          sectionCode === 'chief_complaint'
        )
          ? 1
          : 0;

      return {
        id: sectionCode,
        label: section.label,
        visible: true,
        enabled: !locked,
        completed,
        pending,
        urgent,
        ...(attention && !completed
          ? { pending: Math.max(pending, 1) }
          : {}),
      };
    });
}

// -----------------------------------------------------------------------------
// Detailed navigation projection
//
// This is useful to the CPU runtime when it needs state/reason metadata,
// while the simpler buildNavigation() remains backward compatible.
// -----------------------------------------------------------------------------

export interface DetailedNavigationItem extends ClinicalNavigationItem {
  state:
    | 'hidden'
    | 'locked'
    | 'available'
    | 'active'
    | 'attention'
    | 'complete';

  reason: string | null;

  priority: number;

  required: boolean;

  requiredRemaining: number;

  requiredTotal: number;
}

export function buildDetailedNavigation(
  context: ClinicalContext,
  sections: HistorySectionDefinition[],
  facts: ClinicalFact[],
  activeSection?: string | null,
): DetailedNavigationItem[] {
  return sections.map((section) => {
    const applicable = section.visible &&
      sectionApplies(section.code, context);

    if (!applicable) {
      return {
        id: section.code,
        label: section.label,
        visible: false,
        enabled: false,
        completed: false,
        pending: 0,
        urgent: 0,
        state: 'hidden',
        reason: getHiddenReason(section.code, context),
        priority: sectionPriority(section.code, context),
        required: false,
        requiredRemaining: 0,
        requiredTotal: 0,
      };
    }

    const factCount = countFactsForSection(
      facts,
      section.code,
    );

    const required = sectionIsRequired(
      section.code,
      context,
      section,
    );

    const locked = sectionIsLocked(
      section.code,
      context,
      facts,
    );

    const attention = sectionNeedsAttention(
      section.code,
      context,
      facts,
    );

    const completed =
      required
        ? factCount > 0
        : factCount > 0;

    let state: DetailedNavigationItem['state'];

    if (locked) {
      state = 'locked';
    } else if (
      activeSection === section.code
    ) {
      state = 'active';
    } else if (completed) {
      state = 'complete';
    } else if (attention) {
      state = 'attention';
    } else {
      state = 'available';
    }

    return {
      id: section.code,
      label: section.label,
      visible: true,
      enabled: !locked,
      completed,
      pending: required && !completed ? 1 : 0,
      urgent:
        context.emergency &&
        (
          section.code === 'hpi' ||
          section.code === 'chief_complaint'
        )
          ? 1
          : 0,
      state,
      reason: getSectionReason(
        section.code,
        context,
        locked,
      ),
      priority: sectionPriority(
        section.code,
        context,
      ),
      required,
      requiredRemaining:
        required && !completed ? 1 : 0,
      requiredTotal: required ? 1 : 0,
    };
  });
}

// -----------------------------------------------------------------------------
// Reasons exposed to UI
// -----------------------------------------------------------------------------

function getHiddenReason(
  section: HistorySection,
  context: ClinicalContext,
): string {
  if (
    FEMALE_ONLY_SECTIONS.has(section) &&
    !isFemale(context)
  ) {
    return 'Not applicable to this patient context.';
  }

  if (
    PAEDIATRIC_SECTIONS.has(section) &&
    !isPaediatricContext(context)
  ) {
    return 'Paediatric history is not applicable at this age.';
  }

  if (
    NEONATAL_SECTIONS.has(section) &&
    !isNeonatalContext(context)
  ) {
    return 'Neonatal history is not applicable at this age.';
  }

  if (
    PSYCHIATRY_SECTIONS.has(section) &&
    !isPsychiatricContext(context)
  ) {
    return 'Psychiatric-specific history is not active for this encounter.';
  }

  return 'Section not applicable to the current clinical context.';
}

function getSectionReason(
  section: HistorySection,
  context: ClinicalContext,
  locked: boolean,
): string | null {
  if (!locked) {
    if (section === 'anc_profile' && isPregnant(context)) {
      return 'Active because the patient is pregnant.';
    }

    if (
      section === 'obstetric_history' &&
      isObstetricContext(context)
    ) {
      return 'Active obstetric history.';
    }

    if (
      section === 'gynaecological_history' &&
      isFemale(context)
    ) {
      return 'Active female reproductive history.';
    }

    if (
      section === 'birth_history' &&
      isPaediatricContext(context)
    ) {
      return 'Active because of paediatric/neonatal age.';
    }

    if (
      section === 'psychiatric_history' &&
      isPsychiatricContext(context)
    ) {
      return 'Active because this is a psychiatry encounter.';
    }

    return null;
  }

  if (section === 'chief_complaint') {
    return 'Capture biodata before continuing.';
  }

  if (section === 'hpi') {
    return 'Capture the presenting complaint before HPI.';
  }

  return 'Complete the preceding required clinical information first.';
}

// -----------------------------------------------------------------------------
// Active section resolution
//
// CPU chooses the active section. UI should render this value rather than
// independently deciding what comes next.
// -----------------------------------------------------------------------------

export function resolveActiveSection(
  context: ClinicalContext,
  sections: HistorySectionDefinition[],
  facts: ClinicalFact[],
  requestedSection?: string | null,
): string {
  const navigation = buildDetailedNavigation(
    context,
    sections,
    facts,
    requestedSection,
  );

  // Explicit valid active section wins.
  if (
    requestedSection &&
    navigation.some(
      (item) =>
        item.id === requestedSection &&
        item.visible &&
        item.enabled,
    )
  ) {
    return requestedSection;
  }

  // First emergency-relevant section.
  if (context.emergency) {
    const emergencySection = navigation.find(
      (item) =>
        item.visible &&
        item.enabled &&
        item.urgent > 0,
    );

    if (emergencySection) {
      return emergencySection.id;
    }
  }

  // First incomplete required section.
  const required = navigation.find(
    (item) =>
      item.visible &&
      item.enabled &&
      item.required &&
      !item.completed,
  );

  if (required) {
    return required.id;
  }

  // First attention section.
  const attention = navigation.find(
    (item) =>
      item.visible &&
      item.enabled &&
      item.state === 'attention',
  );

  if (attention) {
    return attention.id;
  }

  // First available section.
  const available = navigation.find(
    (item) =>
      item.visible &&
      item.enabled &&
      item.state === 'available',
  );

  if (available) {
    return available.id;
  }

  // Completed summary is the safest terminal destination.
  const summary = navigation.find(
    (item) =>
      item.visible &&
      item.id === 'summary',
  );

  if (summary) {
    return summary.id;
  }

  return navigation[0]?.id ?? 'biodata';
}

// -----------------------------------------------------------------------------
// Workflow completion
// -----------------------------------------------------------------------------

export function calculateNavigationCompletion(
  context: ClinicalContext,
  sections: HistorySectionDefinition[],
  facts: ClinicalFact[],
): {
  percentage: number;
  mandatoryRemaining: number;
  requiredTotal: number;
  requiredCompleted: number;
} {
  const navigation = buildDetailedNavigation(
    context,
    sections,
    facts,
  );

  const required = navigation.filter(
    (item) =>
      item.visible &&
      item.required,
  );

  const requiredTotal = required.length;

  const requiredCompleted = required.filter(
    (item) => item.completed,
  ).length;

  const mandatoryRemaining =
    requiredTotal - requiredCompleted;

  const percentage =
    requiredTotal === 0
      ? 100
      : Math.round(
          (requiredCompleted / requiredTotal) * 100,
        );

  return {
    percentage,
    mandatoryRemaining,
    requiredTotal,
    requiredCompleted,
  };
}