// =============================================================================
// AMEXAN Clinical CPU — ExaminationSelector
//
// Clinical examination orchestration layer.
//
// PURPOSE
// -------
// Determines the examination that should be available to the clinician for the
// current patient context. Examination is NOT a static checklist. It is a
// context-sensitive clinical acquisition system.
//
// The selector uses:
//   1. Patient age
//   2. Sex
//   3. Pregnancy state
//   4. Encounter type
//   5. Department/service
//   6. Active symptoms
//   7. Active body systems
//   8. Working differentials
//   9. Knowledge-defined examination domains
//  10. Knowledge-defined examination concepts
//  11. Normal ranges
//  12. Examination finding options
//
// IMPORTANT CLINICAL PRINCIPLES
// -----------------------------
// • Examination findings are captured as facts.
// • The same fact substrate feeds the CPU's reasoning engines.
// • The selector recommends WHAT TO EXAMINE.
// • The interpreter determines WHAT A CAPTURED FINDING MEANS.
// • The decision engine determines WHAT MAY BE RECOMMENDED.
// • The clinician remains the final clinical authority.
//
// No diagnosis is inferred merely because an examination concept is displayed.
//
// The knowledge database remains authoritative. This file provides the clinical
// orchestration, gating, prioritisation and safety behaviour around that
// knowledge.
//
// =============================================================================

import type { Db, Row } from '../db.js';

import type {
  DifferentialCandidate,
  ExaminationFindingView,
  ExaminationModuleView,
  PatientClinicalState,
} from '../types.js';

// =============================================================================
// DATABASE ROWS
// =============================================================================

interface ModuleRow extends Row {
  module_code: string;
  canonical_name: string;
  sort_order: number;
}

interface ConceptRow extends Row {
  code: string;
  domain_code: string;
  fact_definition_code: string | null;

  name: string;
  short_label: string | null;

  body_system_code: string | null;

  is_mandatory: boolean;
  base_priority: number;

  technique_codes: string[] | null;
  capture_method_codes: string[] | null;
  applies_to_context_codes: string[] | null;

  unit_code: string | null;
  normal_range_code: string | null;

  // Optional knowledge columns. The selector deliberately tolerates their
  // absence from older knowledge generations.
  sex_code?: string | null;
  pregnancy_required?: boolean | null;
  pregnancy_excluded?: boolean | null;
  encounter_type_codes?: string[] | null;
  department_codes?: string[] | null;
}

interface OptionRow extends Row {
  concept_code: string;
  answer_code: string;
  label: string;

  interpretation_code: string | null;
  value_text: string | null;

  sort_order: number;
}

interface DifferentialLinkRow extends Row {
  condition_code: string;
  phenotype_code: string;
}

interface ExaminationConditionRow extends Row {
  condition_code: string;
  examination_concept_code: string;
  priority: number;
}

interface ContextMatch {
  matched: boolean;
  constrained: boolean;
}

// =============================================================================
// ALWAYS-AVAILABLE EXAMINATION DOMAINS
// =============================================================================
//
// These are intentionally broad. The actual concepts are filtered below.
//
// EXAM-GENERAL
//     General appearance, hydration, pallor, jaundice, oedema, lymph nodes,
//     nutritional status, consciousness and general inspection.
//
// EXAM-PAEDIATRIC
//     Age-specific paediatric examination including growth, developmental and
//     paediatric-specific observations.
//
// EXAM-VITAL
//     Temperature, pulse, respiratory rate, blood pressure, SpO2 and other
//     physiological measurements.
//
// EXAM-SYSTEMIC
//     Cardiovascular, respiratory, neurological, abdominal and other systemic
//     examinations.
//
// EXAM-ENT
//     Ear, nose, throat and upper-airway examination.
//
// EXAM-SURGICAL
//     Local examination, wounds, masses, limbs, breasts, hernias, etc.
//
// The knowledge base determines the actual concepts.
// =============================================================================

const ALL_DOMAINS = [
  'EXAM-GENERAL',
  'EXAM-PAEDIATRIC',
  'EXAM-VITAL',
  'EXAM-SYSTEMIC',
  'EXAM-ENT',
  'EXAM-SURGICAL',
  'EXAM-RESPIRATORY',
] as const;

// =============================================================================
// CLINICAL PRIORITY
// =============================================================================
//
// Smaller number = higher clinical priority.
//
// Emergency physiology must outrank routine examination.
//
// =============================================================================

const PRIORITY = {
  CRITICAL: 0,
  EMERGENCY: 10,
  URGENT: 20,
  HIGH: 30,
  STANDARD: 50,
  LOW: 70,
  OPTIONAL: 90,
} as const;

// =============================================================================
// AGE HELPERS
// =============================================================================

function ageMonths(
  state: Pick<
    PatientClinicalState,
    'ageMonths' | 'ageYears' | 'ageDays'
  >,
): number | null {
  if (state.ageMonths != null && Number.isFinite(state.ageMonths)) {
    return state.ageMonths;
  }

  if (state.ageYears != null && Number.isFinite(state.ageYears)) {
    return state.ageYears * 12;
  }

  if (state.ageDays != null && Number.isFinite(state.ageDays)) {
    return state.ageDays / 30.44;
  }

  return null;
}

function ageDays(
  state: Pick<PatientClinicalState, 'ageDays' | 'ageMonths' | 'ageYears'>,
): number | null {
  if (state.ageDays != null && Number.isFinite(state.ageDays)) {
    return state.ageDays;
  }

  if (state.ageMonths != null && Number.isFinite(state.ageMonths)) {
    return state.ageMonths * 30.44;
  }

  if (state.ageYears != null && Number.isFinite(state.ageYears)) {
    return state.ageYears * 365.25;
  }

  return null;
}

// =============================================================================
// CANONICAL AGE CONTEXT
// =============================================================================

function ageBand(
  state: Pick<
    PatientClinicalState,
    'ageBand' | 'ageDays' | 'ageMonths' | 'ageYears'
  >,
): string | null {
  if (state.ageBand) {
    return state.ageBand.toUpperCase();
  }

  const days = ageDays(state);

  if (days == null) return null;

  if (days < 28) return 'NEONATE';
  if (days < 365) return 'INFANT';
  if (days < 4380) return 'CHILD';
  if (days < 6570) return 'ADOLESCENT';

  return 'ADULT';
}

// =============================================================================
// NORMALISATION HELPERS
// =============================================================================

function normalise(value: string | null | undefined): string {
  return String(value ?? '')
    .trim()
    .toLowerCase();
}

function normaliseArray(
  values: string[] | null | undefined,
): string[] {
  return (values ?? [])
    .map((v) => normalise(v))
    .filter(Boolean);
}

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}

// =============================================================================
// EXAMINATION SELECTOR
// =============================================================================

export class ExaminationSelector {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // MAIN SELECTOR
  // ===========================================================================
  //
  // Returns the live examination workspace.
  //
  // The result is:
  //
  //     DOMAIN
  //        └── examination concept
  //              ├── fact established
  //              ├── capture type
  //              ├── measurement unit
  //              ├── normal range
  //              ├── grading options
  //              ├── mandatory state
  //              └── clinical priority
  //
  // ===========================================================================

  async select(
    differentials: DifferentialCandidate[],
    state: PatientClinicalState,
  ): Promise<ExaminationModuleView[]> {
    const moduleRows = await this.loadModules();

    if (moduleRows.length === 0) {
      return [];
    }

    const [conceptRows, optionMap] = await Promise.all([
      this.loadConcepts(
        moduleRows.map((m) => m.module_code),
        state,
        differentials,
      ),
      this.loadOptions(),
    ]);

    const conceptsByDomain = new Map<string, ConceptRow[]>();

    for (const concept of conceptRows) {
      const list = conceptsByDomain.get(concept.domain_code) ?? [];
      list.push(concept);
      conceptsByDomain.set(concept.domain_code, list);
    }

    const result: ExaminationModuleView[] = [];

    for (const module of moduleRows) {
      const concepts = conceptsByDomain.get(module.module_code) ?? [];

      const findings = concepts
        .map((concept) =>
          this.toFindingView(
            concept,
            optionMap.get(concept.code) ?? [],
            state,
            differentials,
          ),
        )
        .sort((a, b) => {
          if (a.isMandatory !== b.isMandatory) {
            return a.isMandatory ? -1 : 1;
          }

          return a.priority - b.priority;
        });

      if (findings.length === 0) {
        continue;
      }

      result.push({
        moduleCode: module.module_code,
        name: module.canonical_name,
        findings,
      });
    }

    return result;
  }

  // ===========================================================================
  // MODULES
  // ===========================================================================

  private async loadModules(): Promise<ModuleRow[]> {
    return this.db.query<ModuleRow>(
      `
      SELECT
        ed.domain_code AS module_code,
        ed.label AS canonical_name,
        ed.sort_order
      FROM knowledge.examination_domain ed
      WHERE ed.domain_code = ANY($1::text[])
        AND ed.status = 'active'
      ORDER BY ed.sort_order, ed.domain_code
      `,
      [ALL_DOMAINS],
    );
  }

  // ===========================================================================
  // CONCEPT LOADING
  // ===========================================================================
  //
  // The query resolves the applicable normal range before the UI is built.
  //
  // This is important clinically:
  //
  //   RR 40/min
  //
  // cannot be labelled "normal" without knowing whether the patient is:
  //
  //   • a neonate
  //   • infant
  //   • child
  //   • adolescent
  //   • adult
  //
  // Likewise:
  //
  //   • MUAC
  //   • heart rate
  //   • respiratory rate
  //   • blood pressure
  //   • temperature
  //   • SpO2
  //
  // require contextual interpretation.
  //
  // ===========================================================================

  private async loadConcepts(
    domains: string[],
    state: PatientClinicalState,
    differentials: DifferentialCandidate[],
  ): Promise<ConceptRow[]> {
    const age = ageMonths(state);
    const sex = normalise(state.sex);

    const rows = await this.db.query<ConceptRow>(
      `
      SELECT
        ec.code,
        ec.domain_code,
        ec.fact_definition_code,
        ec.name,
        ec.short_label,
        ec.body_system_code,
        ec.is_mandatory,
        ec.base_priority,
        ec.technique_codes,
        ec.capture_method_codes,
        ec.applies_to_context_codes,

        fd.unit_code AS unit_code,

        nr.code AS normal_range_code

      FROM knowledge.examination_concept ec

      LEFT JOIN clinical.fact_definitions fd
        ON fd.fact_code = ec.fact_definition_code

      LEFT JOIN LATERAL (
        SELECT
          nrc.code
        FROM knowledge.normal_range nrc
        WHERE nrc.measurement_code = ec.fact_definition_code

          AND (
            nrc.age_min_months IS NULL
            OR $1::numeric >= nrc.age_min_months
          )

          AND (
            nrc.age_max_months IS NULL
            OR $1::numeric <= nrc.age_max_months
          )

          AND (
            lower(COALESCE(nrc.sex, 'all')) = 'all'
            OR lower(COALESCE(nrc.sex, 'all')) = $2
          )

        ORDER BY
          CASE
            WHEN lower(COALESCE(nrc.sex, 'all')) = $2 THEN 0
            ELSE 1
          END,
          CASE
            WHEN nrc.age_min_months IS NULL THEN 1
            ELSE 0
          END,
          nrc.sort_order

        LIMIT 1
      ) nr ON TRUE

      WHERE ec.domain_code = ANY($3::text[])
        AND ec.status = 'active'

      ORDER BY
        ec.domain_code,
        ec.base_priority,
        ec.code
      `,
      [age, sex || 'all', domains],
    );

    return rows.filter((concept) =>
      this.appliesToPatient(
        concept,
        state,
        differentials,
      ),
    );
  }

  // ===========================================================================
  // CONTEXT GATING
  // ===========================================================================
  //
  // This is deliberately conservative.
  //
  // A context-specific examination must not appear merely because the patient's
  // sex happens to match unless the knowledge rule explicitly requires it.
  //
  // Examples:
  //
  //   breast examination
  //       → female-specific concepts may be gated to females
  //
  //   pregnancy examination
  //       → requires pregnancy context
  //
  //   neonatal examination
  //       → neonatal age context
  //
  //   paediatric anthropometry
  //       → age-specific context
  //
  //   prostate examination
  //       → adult male context
  //
  // ===========================================================================

  private appliesToPatient(
    row: ConceptRow,
    state: PatientClinicalState,
    differentials: DifferentialCandidate[],
  ): boolean {
    const contextCodes = normaliseArray(row.applies_to_context_codes);

    // No explicit context restriction means universally eligible.
    if (contextCodes.length === 0) {
      return true;
    }

    const patientContext = this.patientContext(state, differentials);

    let hasExplicitRestriction = false;

    for (const code of contextCodes) {
      if (
        code.startsWith('age_') ||
        code.startsWith('sex_') ||
        code.startsWith('pregnancy_') ||
        code.startsWith('encounter_') ||
        code.startsWith('department_') ||
        code.startsWith('symptom_') ||
        code.startsWith('domain_') ||
        code.startsWith('condition_')
      ) {
        hasExplicitRestriction = true;
      }

      if (this.contextCodeMatches(code, patientContext, state)) {
        return true;
      }
    }

    // If the row contains restrictions but none matched, exclude it.
    if (hasExplicitRestriction) {
      return false;
    }

    // Unknown knowledge context codes are not silently interpreted as true.
    // This prevents future knowledge vocabulary from accidentally exposing an
    // inappropriate examination.
    return false;
  }

  // ===========================================================================
  // PATIENT CONTEXT
  // ===========================================================================

  private patientContext(
    state: PatientClinicalState,
    differentials: DifferentialCandidate[],
  ): Set<string> {
    const context = new Set<string>();

    const band = ageBand(state);

    if (band) {
      context.add(`age_band_${normalise(band)}`);
    }

    if (state.sex) {
      context.add(`sex_${normalise(state.sex)}`);
    }

    if (state.pregnant === true) {
      context.add('pregnancy_yes');
      context.add('pregnant');
    } else if (state.pregnant === false) {
      context.add('pregnancy_no');
      context.add('not_pregnant');
    }

    if (state.encounterTypeCode) {
      context.add(`encounter_${normalise(state.encounterTypeCode)}`);
    }

    if (state.departmentCode) {
      context.add(`department_${normalise(state.departmentCode)}`);
    }

    for (const symptom of state.activeSymptoms ?? []) {
      const value = normalise(symptom);

      if (value) {
        context.add(`symptom_${value}`);
      }
    }

    for (const domain of state.activeDomains ?? []) {
      const value = normalise(domain);

      if (value) {
        context.add(`domain_${value}`);
      }
    }

    for (const differential of differentials) {
      context.add(`condition_${normalise(differential.conditionCode)}`);
    }

    return context;
  }

  // ===========================================================================
  // CONTEXT CODE MATCHER
  // ===========================================================================

  private contextCodeMatches(
    code: string,
    context: Set<string>,
    state: PatientClinicalState,
  ): boolean {
    if (code === 'all_ages') {
      return true;
    }

    if (code === 'all') {
      return true;
    }

    // -------------------------------------------------------------------------
    // Age bands
    // -------------------------------------------------------------------------

    if (code === 'age_neonate') {
      return ageBand(state) === 'NEONATE';
    }

    if (code === 'age_infant') {
      return ageBand(state) === 'INFANT';
    }

    if (code === 'age_child') {
      return ageBand(state) === 'CHILD';
    }

    if (code === 'age_adolescent') {
      return ageBand(state) === 'ADOLESCENT';
    }

    if (code === 'age_adult') {
      return ageBand(state) === 'ADULT';
    }

    // -------------------------------------------------------------------------
    // Numeric age ranges
    // -------------------------------------------------------------------------

    const ageRange = code.match(
      /^age_(\d+)_to_(\d+)_months$/,
    );

    if (ageRange) {
      const age = ageMonths(state);

      if (age == null) return false;

      const minimum = Number(ageRange[1]);
      const maximum = Number(ageRange[2]);

      return age >= minimum && age <= maximum;
    }

    const ageOver = code.match(
      /^age_over_(\d+)_months$/,
    );

    if (ageOver) {
      const age = ageMonths(state);

      if (age == null) return false;

      return age > Number(ageOver[1]);
    }

    const ageUnder = code.match(
      /^age_under_(\d+)_months$/,
    );

    if (ageUnder) {
      const age = ageMonths(state);

      if (age == null) return false;

      return age < Number(ageUnder[1]);
    }

    // -------------------------------------------------------------------------
    // Sex
    // -------------------------------------------------------------------------

    if (code === 'sex_female') {
      return normalise(state.sex) === 'female';
    }

    if (code === 'sex_male') {
      return normalise(state.sex) === 'male';
    }

    // -------------------------------------------------------------------------
    // Pregnancy
    // -------------------------------------------------------------------------

    if (code === 'pregnancy_required' || code === 'pregnant') {
      return state.pregnant === true;
    }

    if (
      code === 'pregnancy_excluded' ||
      code === 'not_pregnant'
    ) {
      return state.pregnant === false;
    }

    // -------------------------------------------------------------------------
    // General context set
    // -------------------------------------------------------------------------

    return context.has(code);
  }

  // ===========================================================================
  // OPTION LOADING
  // ===========================================================================

  private async loadOptions(): Promise<Map<string, OptionRow[]>> {
    const rows = await this.db.query<OptionRow>(
      `
      SELECT
        ffo.examination_concept_code AS concept_code,
        ffo.answer_code,
        ffo.label,
        ffo.interpretation_code,
        ffo.value_text,
        ffo.sort_order
      FROM knowledge.examination_finding_option ffo
      WHERE ffo.is_active = true
      ORDER BY
        ffo.examination_concept_code,
        ffo.sort_order,
        ffo.answer_code
      `,
    );

    const map = new Map<string, OptionRow[]>();

    for (const row of rows) {
      const list = map.get(row.concept_code) ?? [];
      list.push(row);
      map.set(row.concept_code, list);
    }

    return map;
  }

  // ===========================================================================
  // VIEW CONSTRUCTION
  // ===========================================================================

  private toFindingView(
    concept: ConceptRow,
    options: OptionRow[],
    state: PatientClinicalState,
    differentials: DifferentialCandidate[],
  ): ExaminationFindingView {
    return {
      findingCode: concept.code,

      name: concept.short_label ?? concept.name,

      factDefinitionCode: concept.fact_definition_code,

      findingType: this.inferType(concept),

      unit: concept.unit_code,

      options: options.map((option) => ({
        answerCode: option.answer_code,
        label: option.label,
        interpretationCode: option.interpretation_code,
        valueText: option.value_text,
      })),

      normalRangeCode: concept.normal_range_code,

      isMandatory: this.isMandatory(
        concept,
        state,
      ),

      priority: this.priority(
        concept,
        state,
        differentials,
      ),
    };
  }

  // ===========================================================================
  // MANDATORY EXAMINATION
  // ===========================================================================
  //
  // Knowledge controls the baseline mandatory flag.
  //
  // The selector may additionally elevate physiological measurements that are
  // clinically essential for essentially every acute assessment.
  //
  // The goal is not to make everything mandatory. Excessive mandatory fields
  // destroy clinical usability and encourage false completion.
  //
  // ===========================================================================

  private isMandatory(
    concept: ConceptRow,
    state: PatientClinicalState,
  ): boolean {
    if (concept.is_mandatory) {
      return true;
    }

    const code = normalise(
      concept.fact_definition_code ?? concept.code,
    );

    // Vital signs are mandatory in acute clinical assessment.
    if (
      [
        'temperature',
        'heart_rate',
        'respiratory_rate',
        'spo2',
        'bp_systolic',
        'bp_diastolic',
      ].includes(code)
    ) {
      return this.isAcuteEncounter(state);
    }

    // Neonatal/paediatric emergency assessment.
    if (
      this.isAcuteEncounter(state) &&
      (
        code === 'muac' ||
        code === 'weight'
      ) &&
      ageBand(state) !== 'ADULT'
    ) {
      return true;
    }

    return false;
  }

  // ===========================================================================
  // PRIORITY
  // ===========================================================================

  private priority(
    concept: ConceptRow,
    state: PatientClinicalState,
    differentials: DifferentialCandidate[],
  ): number {
    let priority = Number.isFinite(Number(concept.base_priority))
      ? Number(concept.base_priority)
      : PRIORITY.STANDARD;

    const factCode = normalise(
      concept.fact_definition_code ?? concept.code,
    );

    // -------------------------------------------------------------------------
    // Universal physiological priority
    // -------------------------------------------------------------------------

    const vitalCodes = new Set([
      'temperature',
      'heart_rate',
      'respiratory_rate',
      'spo2',
      'bp_systolic',
      'bp_diastolic',
    ]);

    if (vitalCodes.has(factCode)) {
      priority = Math.min(priority, PRIORITY.EMERGENCY);
    }

    // -------------------------------------------------------------------------
    // Paediatric anthropometry
    // -------------------------------------------------------------------------

    if (
      ageBand(state) !== 'ADULT' &&
      [
        'muac',
        'weight',
        'height',
        'body_length',
        'head_circumference',
      ].includes(factCode)
    ) {
      priority = Math.min(priority, PRIORITY.HIGH);
    }

    // -------------------------------------------------------------------------
    // Respiratory presentation
    // -------------------------------------------------------------------------

    if (this.hasAnySymptom(state, [
      'cough',
      'dyspnoea',
      'shortness of breath',
      'chest pain',
      'wheeze',
    ])) {
      if (
        [
          'respiratory_rate',
          'spo2',
          'chest_indrawing',
          'respiratory_distress',
          'cyanosis',
          'chest_expansion',
          'breath_sounds',
          'crackles',
          'wheeze',
        ].includes(factCode)
      ) {
        priority = Math.min(priority, PRIORITY.URGENT);
      }
    }

    // -------------------------------------------------------------------------
    // Cardiovascular presentation
    // -------------------------------------------------------------------------

    if (this.hasAnySymptom(state, [
      'chest pain',
      'palpitations',
      'syncope',
      'dyspnoea',
    ])) {
      if (
        [
          'heart_rate',
          'blood_pressure',
          'bp_systolic',
          'bp_diastolic',
          'heart_sounds',
          'murmur',
          'peripheral_pulses',
          'peripheral_oedema',
          'jvp',
        ].includes(factCode)
      ) {
        priority = Math.min(priority, PRIORITY.URGENT);
      }
    }

    // -------------------------------------------------------------------------
    // Neurological presentation
    // -------------------------------------------------------------------------

    if (this.hasAnySymptom(state, [
      'headache',
      'seizure',
      'syncope',
      'weakness',
      'confusion',
      'altered consciousness',
    ])) {
      if (
        [
          'gcs',
          'consciousness',
          'pupils',
          'focal_neurological_deficit',
          'limb_power',
          'cranial_nerves',
          'meningeal_signs',
        ].includes(factCode)
      ) {
        priority = Math.min(priority, PRIORITY.URGENT);
      }
    }

    // -------------------------------------------------------------------------
    // Abdominal presentation
    // -------------------------------------------------------------------------

    if (this.hasAnySymptom(state, [
      'abdominal pain',
      'vomiting',
      'diarrhoea',
      'jaundice',
      'abdominal distension',
    ])) {
      if (
        [
          'abdominal_tenderness',
          'guarding',
          'rebound_tenderness',
          'bowel_sounds',
          'organomegaly',
          'abdominal_distension',
          'hernia',
        ].includes(factCode)
      ) {
        priority = Math.min(priority, PRIORITY.URGENT);
      }
    }

    // -------------------------------------------------------------------------
    // Fever / infection
    // -------------------------------------------------------------------------

    if (this.hasAnySymptom(state, ['fever'])) {
      if (
        [
          'temperature',
          'heart_rate',
          'respiratory_rate',
          'spo2',
          'hydration',
          'capillary_refill',
          'mental_status',
        ].includes(factCode)
      ) {
        priority = Math.min(priority, PRIORITY.URGENT);
      }
    }

    // -------------------------------------------------------------------------
    // Leading differential-specific escalation
    // -------------------------------------------------------------------------

    if (differentials.length > 0) {
      const conditionCodes = new Set(
        differentials
          .slice(0, 3)
          .map((d) => normalise(d.conditionCode)),
      );

      if (
        conditionCodes.has('pneumonia') ||
        conditionCodes.has('community_acquired_pneumonia')
      ) {
        if (
          [
            'spo2',
            'respiratory_rate',
            'chest_indrawing',
            'respiratory_distress',
            'cyanosis',
            'breath_sounds',
          ].includes(factCode)
        ) {
          priority = Math.min(priority, PRIORITY.URGENT);
        }
      }
    }

    return Math.max(0, Math.min(999, priority));
  }

  // ===========================================================================
  // ACUTE ENCOUNTER
  // ===========================================================================

  private isAcuteEncounter(
    state: PatientClinicalState,
  ): boolean {
    const encounter = normalise(
      state.encounterTypeCode,
    );

    if (
      [
        'emergency',
        'ed',
        'casualty',
        'acute',
        'inpatient',
        'ipd',
      ].includes(encounter)
    ) {
      return true;
    }

    return (
      (state.activeSymptoms?.length ?? 0) > 0
    );
  }

  // ===========================================================================
  // SYMPTOM HELPERS
  // ===========================================================================

  private hasAnySymptom(
    state: PatientClinicalState,
    symptoms: string[],
  ): boolean {
    const active = new Set(
      (state.activeSymptoms ?? []).map(normalise),
    );

    return symptoms.some((symptom) =>
      active.has(normalise(symptom)),
    );
  }

  // ===========================================================================
  // MEASUREMENT CLASSIFICATION
  // ===========================================================================
  //
  // Measurements are not limited to the existence of a unit. Some knowledge
  // generations may omit unit metadata while the clinical fact itself is
  // unmistakably quantitative.
  //
  // ===========================================================================

  private static readonly MEASUREMENT_FACTS = new Set([
    // Anthropometry
    'muac',
    'head_circumference',
    'body_length',
    'height',
    'weight',
    'bmi',

    // Vital signs
    'bp_systolic',
    'bp_diastolic',
    'blood_pressure',
    'heart_rate',
    'respiratory_rate',
    'temperature',
    'spo2',

    // Point-of-care / monitoring
    'rbs',
    'fbs',
    'blood_glucose',
    'urine_output_rate',
    'urine_output',

    // Other common measurements
    'peak_expiratory_flow',
    'pain_score',
    'gcs',
  ]);

  private inferType(
    concept: ConceptRow,
  ): ExaminationFindingView['findingType'] {
    const factCode = normalise(
      concept.fact_definition_code ?? '',
    );

    if (
      concept.unit_code ||
      ExaminationSelector.MEASUREMENT_FACTS.has(factCode)
    ) {
      return 'measurement';
    }

    const captureMethods = normaliseArray(
      concept.capture_method_codes,
    );

    if (
      captureMethods.includes('observation') ||
      captureMethods.includes('select') ||
      captureMethods.includes('single_select')
    ) {
      return 'select';
    }

    return 'observation';
  }

  // ===========================================================================
  // OPTIONAL CONDITION-SPECIFIC PRIORITY RESOLUTION
  // ===========================================================================
  //
  // If a knowledge base contains explicit examination-condition links, they can
  // be used without making the selector dependent on them. This keeps AMEXAN
  // compatible with installations where that table is not yet populated.
  //
  // The method is intentionally isolated so it can later become a full
  // examination knowledge graph.
  // ===========================================================================

  async selectConditionSpecific(
    conditionCodes: string[],
    state: PatientClinicalState,
  ): Promise<ExaminationFindingView[]> {
    if (conditionCodes.length === 0) {
      return [];
    }

    const rows = await this.db.query<ExaminationConditionRow>(
      `
      SELECT
        ec.condition_code,
        ec.examination_concept_code,
        ec.priority
      FROM knowledge.condition_examination ec
      WHERE ec.condition_code = ANY($1::text[])
      ORDER BY ec.priority ASC
      `,
      [unique(conditionCodes)],
    );

    if (rows.length === 0) {
      return [];
    }

    const conceptCodes = unique(
      rows.map((row) => row.examination_concept_code),
    );

    const concepts = await this.db.query<ConceptRow>(
      `
      SELECT
        ec.code,
        ec.domain_code,
        ec.fact_definition_code,
        ec.name,
        ec.short_label,
        ec.body_system_code,
        ec.is_mandatory,
        ec.base_priority,
        ec.technique_codes,
        ec.capture_method_codes,
        ec.applies_to_context_codes,

        fd.unit_code AS unit_code,

        nr.code AS normal_range_code

      FROM knowledge.examination_concept ec

      LEFT JOIN clinical.fact_definitions fd
        ON fd.fact_code = ec.fact_definition_code

      LEFT JOIN LATERAL (
        SELECT nrc.code
        FROM knowledge.normal_range nrc
        WHERE nrc.measurement_code = ec.fact_definition_code

          AND (
            nrc.age_min_months IS NULL
            OR $1::numeric >= nrc.age_min_months
          )

          AND (
            nrc.age_max_months IS NULL
            OR $1::numeric <= nrc.age_max_months
          )

          AND (
            lower(COALESCE(nrc.sex, 'all')) = 'all'
            OR lower(COALESCE(nrc.sex, 'all')) = $2
          )

        ORDER BY nrc.sort_order
        LIMIT 1
      ) nr ON TRUE

      WHERE ec.code = ANY($3::text[])
        AND ec.status = 'active'
      `,
      [
        ageMonths(state),
        normalise(state.sex) || 'all',
        conceptCodes,
      ],
    );

    const options = await this.loadOptions();

    return concepts
      .filter((concept) =>
        this.appliesToPatient(
          concept,
          state,
          [],
        ),
      )
      .map((concept) =>
        this.toFindingView(
          concept,
          options.get(concept.code) ?? [],
          state,
          [],
        ),
      )
      .sort((a, b) => a.priority - b.priority);
  }
}

// =============================================================================
// CLINICAL SEMANTIC NOTES
// =============================================================================
//
// ExaminationSelector deliberately DOES NOT:
//
//   • diagnose disease
//   • declare a finding abnormal
//   • generate treatment
//   • replace clinician examination
//   • fabricate an examination finding
//   • convert a screening recommendation into a documented finding
//
// It DOES:
//
//   • identify the examination concepts relevant to the patient
//   • enforce age/context safety gates
//   • surface essential physiological observations
//   • prioritise examination according to presentation
//   • provide measurement units
//   • expose applicable normal-range references
//   • expose structured examination grading options
//   • connect every examination concept to a clinical fact
//   • allow downstream interpretation to operate on the same fact substrate
//
// This preserves the AMEXAN CPU invariant:
//
//       CAPTURE → FACT → INTERPRET → EVIDENCE → DIFFERENTIAL →
//       CONTRADICTION → DECISION → DOCUMENTATION
//
// Examination is therefore not a separate UI subsystem.
// It is another clinical evidence-acquisition pathway into the CPU.
// =============================================================================