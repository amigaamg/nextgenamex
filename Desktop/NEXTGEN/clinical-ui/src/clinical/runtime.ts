// =============================================================================
// src/clinical/runtime.ts
// UNIVERSAL AMEXAN CLINICAL CPU PROJECTION
// =============================================================================

import { buildClinicalContext } from './context';
import { buildHistorySections } from './history';
import { buildNavigation } from './navigation';
import { resolveQuestions } from './questions';
import { compileDocumentation } from './documentation';

import type {
  ClinicalFact,
  UniversalClinicalProjection,
} from './types';

export interface BuildProjectionInput {
  patientId: string;
  encounterId: string | null;

  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  sex: 'male' | 'female' | 'intersex' | 'unknown';

  pregnancyState?:
    | 'not_applicable'
    | 'not_pregnant'
    | 'pregnant'
    | 'postpartum'
    | 'unknown';

  requestedDepartment?:
    | 'medical'
    | 'surgical'
    | 'obgyn'
    | 'paediatrics'
    | 'neonatology'
    | 'psychiatry'
    | 'emergency'
    | 'other';

  encounterType?: string | null;

  presentingComplaintCodes?: string[];
  activeSymptomCodes?: string[];

  firstVisit?: boolean;
  emergency?: boolean;

  facts: ClinicalFact[];

  activeSection?: string;

  eventId?: number | null;
}

function hasFactForSection(
  facts: ClinicalFact[],
  section: string,
): boolean {
  return facts.some((fact) => fact.section === section);
}

function calculateCompletion(
  sections: ReturnType<typeof buildHistorySections>,
  facts: ClinicalFact[],
): {
  percentage: number;
  mandatoryRemaining: number;
} {
  if (sections.length === 0) {
    return {
      percentage: 0,
      mandatoryRemaining: 0,
    };
  }

  const completedSections = sections.filter((section) =>
    hasFactForSection(facts, section.code),
  );

  const mandatorySections = sections.filter(
    (section) => section.required,
  );

  const mandatoryRemaining = mandatorySections.filter(
    (section) => !hasFactForSection(facts, section.code),
  ).length;

  const percentage = Math.round(
    (completedSections.length / sections.length) * 100,
  );

  return {
    percentage,
    mandatoryRemaining,
  };
}

function buildAlerts(
  input: BuildProjectionInput,
): UniversalClinicalProjection['alerts'] {
  const alerts: UniversalClinicalProjection['alerts'] = [];

  if (input.emergency) {
    alerts.push({
      level: 'emergency',
      code: 'ENCOUNTER_EMERGENCY',
      message: 'Emergency encounter requires priority clinical assessment.',
    });
  }

  return alerts;
}

function normalizeFacts(
  facts: ClinicalFact[],
): ClinicalFact[] {
  const seen = new Set<string>();

  return facts.filter((fact) => {
    const key =
      fact.id ||
      [
        fact.patientId,
        fact.encounterId ?? '',
        fact.factCode,
        fact.recordedAt,
      ].join('|');

    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}

export function buildProjection(
  input: BuildProjectionInput,
): UniversalClinicalProjection {
  const facts = normalizeFacts(input.facts);

  const context = buildClinicalContext({
    patientId: input.patientId,
    encounterId: input.encounterId,

    ageYears: input.ageYears,
    ageMonths: input.ageMonths,
    ageDays: input.ageDays,

    sex: input.sex,

    pregnancyState: input.pregnancyState,

    requestedDepartment: input.requestedDepartment,
    encounterType: input.encounterType,

    presentingComplaintCodes:
      input.presentingComplaintCodes ?? [],

    activeSymptomCodes:
      input.activeSymptomCodes ?? [],

    firstVisit: input.firstVisit ?? true,
    emergency: input.emergency ?? false,
  });

  const sections = buildHistorySections(context);

  const activeSection =
    input.activeSection &&
    sections.some(
      (section) => section.code === input.activeSection,
    )
      ? input.activeSection
      : sections[0]?.code ?? 'biodata';

  const navigation = buildNavigation(
    context,
    sections,
    facts,
  );

  const questions = resolveQuestions(
    context,
    facts,
    activeSection,
  );

  const documentation = compileDocumentation(
    context,
    facts,
  );

  const completion = calculateCompletion(
    sections,
    facts,
  );

  const alerts = buildAlerts(input);

  return {
    context,

    sections,

    navigation,

    capturedFacts: facts,

    questions,

    activeSection,

    completion,

    alerts,

    phenotypes: [],
    mechanisms: [],
    differentials: [],

    examination: [],
    investigations: [],
    treatment: [],
    protocol: null,
    monitoring: [],

    documentation,

    eventId: input.eventId ?? null,
  };
}