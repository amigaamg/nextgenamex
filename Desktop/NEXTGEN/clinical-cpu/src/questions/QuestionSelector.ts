// =============================================================================
// AMEXAN Clinical CPU — QuestionSelector
// =============================================================================
//
// PURPOSE
// -------
// The QuestionSelector is the adaptive clinical interview engine.
//
// It does NOT attempt to diagnose the patient.
// It determines:
//
//   "Given everything currently known, what is the most clinically useful,
//    safe and context-appropriate NEXT question to ask?"
//
// The selector therefore sits between:
//
//   PATIENT INPUT
//        ↓
//   FACT STREAM
//        ↓
//   PHENOTYPES
//        ↓
//   MECHANISMS
//        ↓
//   DIFFERENTIALS
//        ↓
//   QUESTION SELECTOR
//        ↓
//   NEXT BEST QUESTION
//
// The important invariant is:
//
//       UNKNOWN ≠ NO
//
// Absence of a fact means that the question may still be required.
//
// A question is removed only when:
//
//   1. it has already been answered,
//   2. its clinical information is already captured,
//   3. its context makes it genuinely inapplicable,
//   4. a blocking dependency is not satisfied,
//   5. a clinical rule explicitly suppresses it.
//
// The selector optimizes:
//
//   SAFETY
//   > REQUIREMENT
//   > CLINICAL RELEVANCE
//   > INFORMATION GAIN
//   > DIFFERENTIAL DISCRIMINATION
//   > MECHANISM DISCRIMINATION
//   > QUESTION PRIORITY
//   > TRIGGER PRIORITY
//
// IMPORTANT
// ---------
// The CPU does NOT contain disease-specific questions in code.
// Disease knowledge remains in PostgreSQL.
//
// TypeScript evaluates knowledge.
// PostgreSQL defines medicine.
//
// =============================================================================

import type { Db, Row } from '../db.js';

import type {
  DifferentialCandidate,
  Fact,
  MechanismScore,
  NextQuestion,
  PatientClinicalState,
  PhenotypeScore,
  QuestionResponseType,
  QuestionRequirementLevel,
} from '../types.js';

// =============================================================================
// DATABASE TYPES
// =============================================================================

interface QuestionRow extends Row {
  question_code: string;
  text: string;
  response_type: string;
  priority: number;
  is_active: boolean;
  default_value: string | null;
}

interface TriggerRow extends Row {
  question_code: string;
  trigger_type: string;
  trigger_code: string;
  priority: number;
}

interface RequirementRow extends Row {
  question_code: string;
  requirement_level: string;
  condition: unknown;
  priority: number;
}

interface ContextExclusionRow extends Row {
  question_code: string;
  context_type_code: string;
  context_value: string;
  applicability: string;
}

interface OptionRow extends Row {
  question_code: string;
  answer_code: string;
  label: string;
  sort_order: number;
  is_active: boolean;
}

interface MappingRow extends Row {
  question_code: string;
  fact_definition_code: string;
}

interface QuestionFactRow extends Row {
  question_code: string;
  fact_definition_code: string;
  unit_code: string | null;
}

interface ModuleMemberRow extends Row {
  module_code: string;
  question_code: string;
}

interface HpiObjectiveRow extends Row {
  question_code: string;
  objective_code: string;
  sequence_no: number;
}

interface RuleRow extends Row {
  rule_id: string;
  trigger_type: string;
  trigger_code: string;
  trigger_operator: string;
  trigger_value: unknown;
  action: string;
  target_type: string;
  target_code: string;
  priority_delta: number;
}

interface DependencyRow extends Row {
  question_code: string;
  prerequisite_type: string;
  prerequisite_code: string;
  operator: string;
  value: unknown;
  is_blocking: boolean;
}

interface RedFlagRuleRow extends Row {
  fact_definition_code: string | null;
  urgency: string;
}

interface VariantRow extends Row {
  question_code: string;
  context: string;
  wording: string;
}

interface PhenotypeFeatureRow extends Row {
  phenotype_code: string;
  feature_code: string;
}

interface ConditionQuestionRow extends Row {
  condition_code: string;
  question_code: string;
  weight: number;
}

interface MechanismQuestionRow extends Row {
  mechanism_code: string;
  question_code: string;
  weight: number;
}

// =============================================================================
// AGE CONTEXT
// =============================================================================
//
// ONE universal question identity.
// The wording changes according to developmental context.
//
// This is critical.
//
// Example:
//
// Adult:
//   "Does the cough produce sputum?"
//
// Child:
//   "Has he/she been bringing up phlegm or mucus when coughing?"
//
// Infant:
//   "Have you noticed mucus or phlegm coming from the mouth during coughing?"
//
// Neonate:
//   The question may be completely different and may be directed to the
//   caregiver.
//
// =============================================================================

const VARIANT_CONTEXT_BY_BUCKET: Record<string, string> = {
  '0-28D': 'neonate',
  '1-11M': 'infant',
  '1-4Y': 'child',
  '5-17Y': 'child',
  '18-64Y': 'adult',
  '65P': 'older_adult',
};

// =============================================================================
// SAFETY PRIORITY
// =============================================================================

const RED_FLAG_BOOST: Record<string, number> = {
  emergency: 100,
  emergent: 100,
  critical: 100,
  urgent: 60,
  high: 45,
  moderate: 20,
};

// =============================================================================
// REQUIREMENT RANK
// =============================================================================
//
// Lower number = higher priority.
//
// Safety questions must outrank ordinary mandatory history.
//
// =============================================================================

const REQUIREMENT_RANK: Record<string, number> = {
  safety: 0,
  mandatory: 1,
  conditionally_required: 2,
  high_priority: 3,
  optional: 4,
  informational: 5,
};

// =============================================================================
// REQUIREMENT BAND STEP
// =============================================================================
//
// Each requirement level is its own band, but the band is deliberately NARROW.
// A strongly pathway-relevant conditional question must be able to overtake a
// weak mandatory administrative question. Safety (rank 0) still always leads.
//
// =============================================================================

const REQUIREMENT_STEP = 900;

// =============================================================================
// HPI EXPLORATION PHASE
// =============================================================================
//
// Presenting-symptom exploration follows a fixed clinical flow rather than a
// flat requirement ranking: SOCRATES characterization → chronology →
// associated symptoms → possible diagnosis / differential → aetiology / risk
// factors → complications of the likely diagnosis → previous episodes →
// health-seeking → functional impact.
//
// Each question is assigned an HPI objective in the knowledge base
// (knowledge.question_hpi_objective → knowledge.hpi_objective). The objective
// sequence_no (10, 20, 30, ...) becomes the primary ordering axis for those
// questions, exactly as biodata uses a workflow stage. Safety (red-flag) and
// identity-foundation questions are exempt and keep leading.
//
// =============================================================================

const HPI_PHASE_STEP = 60;

// =============================================================================
// CLINICAL PATHWAY REGISTRY
// =============================================================================
//
// Pathways are activated by patient/encounter context (sex, age, pregnancy,
// department). Once active they lift every question that establishes a
// pathway fact, is gated by a pathway context rule, or belongs to a pathway
// module — so reproductive questions surface before administrative ones.
//
// =============================================================================

const PATHWAY_FACT_CODES: Record<string, string[]> = {
  REPRODUCTIVE: [
    'LMP_DATE',
    'PREGNANCY_POSSIBILITY',
    'PREGNANCY_STATUS',
    'GRAVIDA',
    'PARITY',
    'GESTATIONAL_AGE_WEEKS',
    'EDD',
    'CONTRACEPTION',
    'MENARCHE',
    'MENSTRUAL_CYCLE',
    'BREAST_FEEDING',
  ],
  OBSTETRIC: [
    'LMP_DATE',
    'GESTATIONAL_AGE_WEEKS',
    'EDD',
    'PREGNANCY_STATUS',
    'PREGNANCY_POSSIBILITY',
    'FETAL_MOVEMENTS',
    'UTERINE_CONTRACTIONS',
    'MEMBRANE_RUPTURE',
    'PRENATAL_VISITS',
  ],
  PAEDIATRIC: [
    'BIRTH_WEIGHT_KG',
    'FEEDING_METHOD',
    'BIRTH_HISTORY',
    'APGAR',
    'IMMUNIZATION_STATUS',
    'DEVELOPMENTAL_MILESTONES',
  ],
  GERIATRIC: [
    'FALL_RISK',
    'POLYPHARMACY',
    'FRAILTY',
    'COGNITIVE_STATUS',
  ],
};

const PATHWAY_CONTEXT_TYPES: Record<string, string[]> = {
  REPRODUCTIVE: [
    'REPRODUCTIVE',
    'PREGNANCY',
    'MENSTRUAL',
    'OBSTETRIC',
    'GYNAECOLOGICAL',
    'GYNECOLOGICAL',
  ],
  OBSTETRIC: ['PREGNANCY', 'OBSTETRIC'],
  PAEDIATRIC: ['AGE', 'AGE_BAND', 'NEONATAL'],
  GERIATRIC: ['AGE', 'AGE_BAND'],
};

const PATHWAY_MODULES: Record<string, string[]> = {
  REPRODUCTIVE: ['REPRODUCTIVE', 'OBSTETRIC', 'GYNAECOLOGICAL'],
  OBSTETRIC: ['OBSTETRIC'],
  PAEDIATRIC: ['PAEDIATRIC', 'NEONATAL'],
  GERIATRIC: ['GERIATRIC'],
};

// =============================================================================
// REDUNDANCY
// =============================================================================
//
// A question whose answer is already derivable from captured facts or patient
// context is de-prioritised (never silently asked when it can be derived).
//
// =============================================================================

const DERIVABLE_FACTS: Record<string, string[]> = {
  REPORTED_AGE: ['DATE_OF_BIRTH', 'AGE_YEARS'],
  AGE_YEARS: ['DATE_OF_BIRTH'],
  AGE_MONTHS: ['DATE_OF_BIRTH', 'AGE_YEARS'],
  AGE_DAYS: ['DATE_OF_BIRTH', 'AGE_YEARS'],
};

// =============================================================================
// IDENTITY FOUNDATION
// =============================================================================
//
// Patient identity (name / sex / age / date of birth) is the clinical entry
// gate. Identity capture leads its requirement band so that clinical intake
// never waits behind administrative housekeeping.
//
// =============================================================================

const IDENTITY_FACTS: string[] = [
  'PATIENT_NAME',
  'SEX',
  'DATE_OF_BIRTH',
  'REPORTED_AGE',
  'AGE_YEARS',
  'AGE_MONTHS',
  'AGE_DAYS',
];

// =============================================================================
// BIODATA WORKFLOW STAGES
// =============================================================================
//
// Biodata is a WORKFLOW, not a requirement ladder. The doctor reads it
// top-to-bottom in clinical stages:
//
//   1. Identity        → name, sex, DOB / age
//   2. Demographics    → occupation, residence, county
//   3. Informant       → who provided the history + reliability
//   4. Encounter       → encounter class + disposition
//   5. Admission       → ONLY when the encounter is inpatient
//   6. Reproductive    → ONLY when female + appropriate age/context
//   7. Social / Contact→ next of kin + phone (opportunistic, never blocking)
//
// A question is placed by its stage, not by its requirement band. Requirement
// only orders questions WITHIN the same stage. Admission and reproductive
// stages are context-gated upstream, so they vanish entirely when they do not
// apply.
//
// =============================================================================

const BIODATA_STAGE = {
  IDENTITY: 10,
  DEMOGRAPHICS: 20,
  INFORMANT: 30,
  ENCOUNTER_CONTEXT: 40,
  ADMISSION_CONTEXT: 50,
  REPRODUCTIVE_CONTEXT: 60,
  SOCIAL_CONTEXT: 70,
  CONTACT_CONTEXT: 80,
  COMPLETE: 100,
} as const;

const BIODATA_STAGE_BY_QUESTION: Record<string, number> = {
  BIODATA_PATIENT_NAME: BIODATA_STAGE.IDENTITY,
  BIODATA_SEX: BIODATA_STAGE.IDENTITY,
  BIODATA_DATE_OF_BIRTH: BIODATA_STAGE.IDENTITY,
  BIODATA_REPORTED_AGE: BIODATA_STAGE.IDENTITY,

  BIODATA_OCCUPATION: BIODATA_STAGE.DEMOGRAPHICS,
  BIODATA_RESIDENCE: BIODATA_STAGE.DEMOGRAPHICS,
  BIODATA_COUNTY: BIODATA_STAGE.DEMOGRAPHICS,

  BIODATA_INFORMANT_RELATION: BIODATA_STAGE.INFORMANT,
  BIODATA_INFORMANT_RELIABILITY: BIODATA_STAGE.INFORMANT,

  BIODATA_ENCOUNTER_CLASS: BIODATA_STAGE.ENCOUNTER_CONTEXT,
  BIODATA_ENCOUNTER_TYPE: BIODATA_STAGE.ENCOUNTER_CONTEXT,

  BIODATA_ADMISSION_STATUS: BIODATA_STAGE.ADMISSION_CONTEXT,
  BIODATA_ADMISSION_DATE: BIODATA_STAGE.ADMISSION_CONTEXT,

  BIODATA_PREGNANCY_STATUS: BIODATA_STAGE.REPRODUCTIVE_CONTEXT,
  BIODATA_LMP: BIODATA_STAGE.REPRODUCTIVE_CONTEXT,
  BIODATA_LMP_CERTAINTY: BIODATA_STAGE.REPRODUCTIVE_CONTEXT,

  BIODATA_NEXT_OF_KIN: BIODATA_STAGE.SOCIAL_CONTEXT,
  BIODATA_NEXT_OF_KIN_PHONE: BIODATA_STAGE.CONTACT_CONTEXT,
};

// =============================================================================
// CLINICAL UTILITY WEIGHTS
// =============================================================================
//
// These are intentionally generic.
//
// The actual disease-specific relevance comes from knowledge tables.
//
// =============================================================================

const WEIGHTS = {
  safety: 1000,

  differential: 140,
  mechanism: 90,
  phenotype: 70,

  reasoningFact: 80,

  symptomTrigger: 45,
  factTrigger: 35,

  // Active clinical pathway (sex/age/pregnancy/complaint activated).
  pathway: 200,

  // Identity foundation capture (name/sex/age/DOB) leads its requirement band.
  identity: 350,

  // Question whose answer is already derivable from known context.
  redundancy: 1600,

  required: 100,

  duplicatePenalty: 10000,

  uncertaintyPenalty: 0,

  lowPriorityPenalty: 1,
};

// =============================================================================
// PUBLIC OPTIONS
// =============================================================================

export interface QuestionSelectionOptions {
  limit?: number;

  /**
   * Optional hard cap on how many questions may be returned from one module.
   *
   * This prevents the interview from becoming dominated by one question family
   * such as cough characterization.
   */
  maxPerModule?: number;

  /**
   * When true, foundation questions are allowed even if the patient has no
   * active symptom domain yet.
   */
  includeFoundation?: boolean;

  /**
   * When true, informational questions may be returned.
   */
  includeInformational?: boolean;
}

// =============================================================================
// INTERNAL CANDIDATE
// =============================================================================

export interface Candidate {
  question: QuestionRow;

  requirementLevel: string;
  requirementRank: number;

  factCodes: string[];
  primaryFactCode: string | null;

  triggerPriority: number;

  safetyBoost: number;
  informationGain: number;
  differentialGain: number;
  mechanismGain: number;
  phenotypeGain: number;

  pathwayGain: number;
  redundancyPenalty: number;

  biodataStage: number | null;

  activationReason: string;

  ruleDelta: number;

  moduleCodes: string[];

  variantText: string | null;
}

// =============================================================================
// CLINICAL PATHWAY ACTIVATION
// =============================================================================
//
// A pathway is a live clinical state (reproductive-age female, established
// pregnancy, paediatric patient, elderly patient). It is NOT a static list of
// questions — it is a context switch that lifts the questions that matter for
// this patient RIGHT NOW.
//
// =============================================================================

function deriveActivePathways(
  state: PatientClinicalState,
): Set<string> {
  const pathways = new Set<string>();
  const sex = normalizeSex(state.sex);
  const age = state.ageYears;

  if (
    sex === 'female'
    && age != null
    && age >= 12
    && age <= 55
  ) {
    pathways.add('REPRODUCTIVE');
  }

  if (
    state.pregnant === true
    || state.gestationalAgeWeeks != null
  ) {
    pathways.add('OBSTETRIC');
  }

  if (age != null && age < 18) {
    pathways.add('PAEDIATRIC');
  }

  if (age != null && age >= 60) {
    pathways.add('GERIATRIC');
  }

  return pathways;
}

const PATHWAY_LABELS: Record<string, string> = {
  REPRODUCTIVE: 'reproductive health',
  OBSTETRIC: 'obstetric',
  PAEDIATRIC: 'paediatric',
  GERIATRIC: 'geriatric',
};

/**
 * How strongly a candidate belongs to the currently active clinical pathways.
 *
 * Every signal is a consequence of patient context — no hard-coded per-question
 * score. A question gains affinity when it establishes a pathway fact, is gated
 * by a pathway context rule that is currently applicable, or belongs to a
 * pathway module.
 */
function pathwayAffinity(
  activePathways: Set<string>,
  factCodes: string[],
  appliesContext: ContextExclusionRow[],
  moduleCodes: string[],
): number {
  let gain = 0;

  for (const pathway of activePathways) {
    const pathwayFacts = PATHWAY_FACT_CODES[pathway] ?? [];
    const factMatches = factCodes.filter(
      (fact) => pathwayFacts.includes(fact),
    ).length;
    gain += Math.min(2, factMatches) * 2;

    const contextMatches = appliesContext.some(
      (row) =>
        (PATHWAY_CONTEXT_TYPES[pathway] ?? []).includes(
          row.context_type_code.trim().toUpperCase(),
        ),
    );
    if (contextMatches) gain += 2;

    const moduleMatches = moduleCodes.some(
      (module) =>
        (PATHWAY_MODULES[pathway] ?? []).includes(module),
    );
    if (moduleMatches) gain += 1;
  }

  return Math.min(5, gain);
}

// =============================================================================
// REDUNDANCY
// =============================================================================

function redundancyPenaltyFor(
  state: PatientClinicalState,
  capturedCodes: Set<string>,
  factCodes: string[],
): number {
  // UNKNOWN/'' is "not yet established", not a definitive answer. Only a
  // definitive value makes a question redundant.
  const definitive = (value: string | null | undefined): boolean => {
    if (value == null) return false;
    const text = String(value).trim().toLowerCase();
    return text !== '' && text !== 'unknown';
  };

  const knownOrCaptured = (fact: string): boolean => {
    if (capturedCodes.has(fact)) return true;
    if (fact === 'SEX' && definitive(state.sex)) return true;
    if (
      (fact === 'AGE_YEARS'
        || fact === 'AGE_MONTHS'
        || fact === 'AGE_DAYS'
        || fact === 'REPORTED_AGE')
      && state.ageYears != null
    ) {
      return true;
    }
    return false;
  };

  let penalty = 0;

  for (const fact of factCodes) {
    if (fact === 'SEX' && definitive(state.sex)) {
      penalty += 1;
      continue;
    }
    if (
      (DERIVABLE_FACTS[fact] ?? []).some(
        knownOrCaptured,
      )
    ) {
      penalty += 1;
    }
  }

  return Math.min(2, penalty);
}

// =============================================================================
// QUESTION SELECTOR
// =============================================================================

export class QuestionSelector {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // MAIN ENTRY
  // ===========================================================================

  async select(
    state: PatientClinicalState,
    phenotypes: PhenotypeScore[],
    mechanisms: MechanismScore[],
    differentials: DifferentialCandidate[],
    options: QuestionSelectionOptions = {},
  ): Promise<NextQuestion[]> {
    const limit = Math.max(1, Math.min(options.limit ?? 24, 100));
    const maxPerModule = options.maxPerModule ?? Number.POSITIVE_INFINITY;

    const includeFoundation = options.includeFoundation ?? true;
    const includeInformational = options.includeInformational ?? false;

    // -------------------------------------------------------------------------
    // NORMALIZED PATIENT CONTEXT
    // -------------------------------------------------------------------------

    const ageBucket = ageBucketFromState(state);
    const capturedCodes = new Set(
      (state.facts ?? []).map((f) => f.factCode),
    );

    const answeredQuestions = new Set(
      state.answeredQuestions ?? [],
    );

    const activeSymptoms = normalizeTokens(
      state.activeSymptoms ?? [],
    );

    // -------------------------------------------------------------------------
    // REASONING CONTEXT
    // -------------------------------------------------------------------------

    const topPhenotypes = new Set(
      phenotypes.slice(0, 5).map((p) => p.phenotypeCode),
    );

    const topMechanisms = new Set(
      mechanisms.slice(0, 5).map((m) => m.mechanismCode),
    );

    const topConditions = new Set(
      differentials.slice(0, 5).map((d) => d.conditionCode),
    );

    const leadingCondition = differentials[0]?.conditionCode ?? null;

    // -------------------------------------------------------------------------
    // DATABASE LOAD
    // -------------------------------------------------------------------------
    //
    // Everything is loaded in parallel.
    //
    // IMPORTANT PERFORMANCE RULE:
    //
    // NEVER query phenotype_feature once for every question.
    //
    // The previous implementation contained an N+1 pattern here.
    //
    // We fetch the complete relevant relationship set once.
    //
    // -------------------------------------------------------------------------

    const [
      questions,
      triggers,
      requirements,
      contextRows,
      optionRows,
      mappings,
      questionFacts,
      moduleMembers,
      rules,
      dependencies,
      redFlagRules,
      variants,
      phenotypeFeatures,
      conditionQuestions,
      mechanismQuestions,
      questionObjectives,
    ] = await Promise.all([
      this.db.query<QuestionRow>(
        `
        SELECT
          question_code,
          text,
          response_type,
          priority,
          is_active,
          default_value
        FROM knowledge.question
        WHERE is_active = true
        `,
      ),

      this.db.query<TriggerRow>(
        `
        SELECT
          q.question_code,
          qt.trigger_type,
          qt.trigger_code,
          qt.priority
        FROM knowledge.question_trigger qt
        JOIN knowledge.question q
          ON q.id = qt.question_id
        WHERE q.is_active = true
        `,
      ),

      this.db.query<RequirementRow>(
        `
        SELECT
          q.question_code,
          qr.requirement_level,
          qr.condition,
          qr.priority
        FROM knowledge.question_requirement qr
        JOIN knowledge.question q
          ON q.id = qr.question_id
        WHERE q.is_active = true
        `,
      ),

      this.db.query<ContextExclusionRow>(
        `
        SELECT
          q.question_code,
          cv.context_type_code,
          cv.value AS context_value,
          qc.applicability
        FROM knowledge.question_context qc
        JOIN knowledge.question q
          ON q.id = qc.question_id
        JOIN knowledge.context_value cv
          ON cv.id = qc.context_value_id
        WHERE q.is_active = true
        `,
      ),

      this.db.query<OptionRow>(
        `
        SELECT
          q.question_code,
          ao.answer_code,
          ao.label,
          ao.sort_order,
          ao.is_active
        FROM knowledge.answer_option ao
        JOIN knowledge.question q
          ON q.id = ao.question_id
        WHERE ao.is_active = true
        ORDER BY q.question_code, ao.sort_order
        `,
      ),

      this.db.query<MappingRow>(
        `
        SELECT
          q.question_code,
          fm.fact_definition_code
        FROM knowledge.fact_mapping fm
        JOIN knowledge.answer_option ao
          ON ao.id = fm.answer_option_id
        JOIN knowledge.question q
          ON q.id = ao.question_id
        `,
      ),

      this.db.query<QuestionFactRow>(
        `
        SELECT
          q.question_code,
          qf.fact_definition_code,
          qf.unit_code
        FROM knowledge.question_fact qf
        JOIN knowledge.question q
          ON q.id = qf.question_id
        `,
      ),

      this.db.query<ModuleMemberRow>(
        `
        SELECT
          qmm.module_code,
          q.question_code
        FROM knowledge.question_module_member qmm
        JOIN knowledge.question q
          ON q.id = qmm.question_id
        `,
      ),

      this.db.query<RuleRow>(
        `
        SELECT
          rule_id,
          trigger_type,
          trigger_code,
          trigger_operator,
          trigger_value,
          action,
          target_type,
          target_code,
          priority_delta
        FROM knowledge.question_rule
        WHERE status = 'active'
        `,
      ),

      this.db.query<DependencyRow>(
        `
        SELECT
          q.question_code,
          qd.prerequisite_type,
          qd.prerequisite_code,
          qd.operator,
          qd.value,
          qd.is_blocking
        FROM knowledge.question_dependency qd
        JOIN knowledge.question q
          ON q.id = qd.question_id
        WHERE qd.is_blocking = true
        `,
      ),

      this.db.query<RedFlagRuleRow>(
        `
        SELECT
          fact_definition_code,
          urgency
        FROM knowledge.red_flag_rule
        WHERE status = 'active'
          AND fact_definition_code IS NOT NULL
        `,
      ),

      this.db.query<VariantRow>(
        `
        SELECT
          q.question_code,
          qv.context,
          qv.wording
        FROM knowledge.question_variant qv
        JOIN knowledge.question q
          ON q.id = qv.question_id
        WHERE qv.is_active = true
          AND qv.is_disabled = false
        `,
      ),

      this.db.query<PhenotypeFeatureRow>(
        `
        SELECT
          ph.phenotype_code,
          pf.feature_code
        FROM knowledge.phenotype_feature pf
        JOIN knowledge.phenotype ph
          ON ph.id = pf.phenotype_id
        WHERE ph.status = 'active'
        `,
      ),

      this.db.query<ConditionQuestionRow>(
        `
        SELECT
          c.condition_code,
          q.question_code,
          sc.weight
        FROM knowledge.condition c
        JOIN knowledge.symptom_condition sc ON sc.condition_id = c.id
        JOIN knowledge.symptom_question sq ON sq.symptom_id = sc.symptom_id
        JOIN knowledge.question q ON q.id = sq.question_id
        WHERE q.is_active = true
        `,
      ),

      this.db.query<MechanismQuestionRow>(
        `
        SELECT
          m.mechanism_code,
          q.question_code,
          sm.weight
        FROM knowledge.mechanism m
        JOIN knowledge.symptom_mechanism sm ON sm.mechanism_id = m.id
        JOIN knowledge.symptom_question sq ON sq.symptom_id = sm.symptom_id
        JOIN knowledge.question q ON q.id = sq.question_id
        WHERE q.is_active = true
        `,
      ),

      this.db.query<HpiObjectiveRow>(
        `
        SELECT
          q.question_code,
          qho.objective_code,
          ho.sequence_no
        FROM knowledge.question_hpi_objective qho
        JOIN knowledge.question q ON q.id = qho.question_id
        JOIN knowledge.hpi_objective ho
          ON ho.objective_code = qho.objective_code
        WHERE q.is_active = true
        `,
      ),
    ]);

    // =========================================================================
    // INDEX DATABASE RESULTS
    // =========================================================================

    const triggersByQuestion = groupBy(
      triggers,
      (x) => x.question_code,
    );

    const requirementsByQuestion = groupBy(
      requirements,
      (x) => x.question_code,
    );

    const contextByQuestion = groupBy(
      contextRows,
      (x) => x.question_code,
    );

    const mappingsByQuestion = groupBy(
      mappings,
      (x) => x.question_code,
    );

    const modulesByQuestion = groupBy(
      moduleMembers,
      (x) => x.question_code,
    );

    const dependenciesByQuestion = groupBy(
      dependencies,
      (x) => x.question_code,
    );

    // -------------------------------------------------------------------------
    // QUESTION → FACT
    // -------------------------------------------------------------------------

    const questionFactByQuestion = new Map<string, QuestionFactRow>();

    for (const row of questionFacts) {
      questionFactByQuestion.set(row.question_code, row);
    }

    // -------------------------------------------------------------------------
    // PHENOTYPE → FACTS
    // -------------------------------------------------------------------------

    const phenotypeFacts = new Map<string, Set<string>>();

    for (const row of phenotypeFeatures) {
      const set = phenotypeFacts.get(row.phenotype_code) ?? new Set<string>();
      set.add(row.feature_code);
      phenotypeFacts.set(row.phenotype_code, set);
    }

    // -------------------------------------------------------------------------
    // CONDITION → QUESTIONS
    // -------------------------------------------------------------------------

    const conditionQuestionWeight = new Map<string, Map<string, number>>();

    for (const row of conditionQuestions) {
      const map =
        conditionQuestionWeight.get(row.condition_code)
        ?? new Map<string, number>();

      map.set(
        row.question_code,
        Number(row.weight),
      );

      conditionQuestionWeight.set(
        row.condition_code,
        map,
      );
    }

    // -------------------------------------------------------------------------
    // MECHANISM → QUESTIONS
    // -------------------------------------------------------------------------

    const mechanismQuestionWeight = new Map<string, Map<string, number>>();

    for (const row of mechanismQuestions) {
      const map =
        mechanismQuestionWeight.get(row.mechanism_code)
        ?? new Map<string, number>();

      map.set(
        row.question_code,
        Number(row.weight),
      );

      mechanismQuestionWeight.set(
        row.mechanism_code,
        map,
      );
    }

    // -------------------------------------------------------------------------
    // QUESTION → HPI OBJECTIVE (earliest exploration phase)
    // -------------------------------------------------------------------------
    //
    // A question may serve several objectives (e.g. sputum colour is both a
    // characterization and a diagnostic discriminator). The CPU uses the
    // earliest objective sequence_no as the question's primary exploration
    // phase, so characterization precedes differential reasoning which
    // precedes risk factors which precedes complications.

    const hpiPhaseByQuestion = new Map<string, number>();

    for (const row of questionObjectives) {
      const existing = hpiPhaseByQuestion.get(row.question_code);
      const phase = row.sequence_no;

      if (existing == null || phase < existing) {
        hpiPhaseByQuestion.set(row.question_code, phase);
      }
    }

    // =========================================================================
    // RED FLAG INDEX
    // =========================================================================

    const redFlagBoostByFact = new Map<string, number>();

    for (const rule of redFlagRules) {
      if (!rule.fact_definition_code) continue;

      const boost =
        RED_FLAG_BOOST[
          rule.urgency.trim().toLowerCase()
        ] ?? 0;

      const existing =
        redFlagBoostByFact.get(rule.fact_definition_code) ?? 0;

      if (boost > existing) {
        redFlagBoostByFact.set(
          rule.fact_definition_code,
          boost,
        );
      }
    }

    // =========================================================================
    // AGE-SPECIFIC QUESTION WORDING
    // =========================================================================

    const variantByQuestion = new Map<string, string>();

    const variantContext =
      ageBucket
        ? VARIANT_CONTEXT_BY_BUCKET[ageBucket]
        : null;

    if (variantContext) {
      for (const variant of variants) {
        if (
          variant.context === variantContext
          && !variantByQuestion.has(variant.question_code)
        ) {
          variantByQuestion.set(
            variant.question_code,
            variant.wording,
          );
        }
      }
    }

    // =========================================================================
    // MODULE INDEX
    // =========================================================================

    const modulesForQuestion = new Map<string, string[]>();

    for (const row of moduleMembers) {
      const list =
        modulesForQuestion.get(row.question_code)
        ?? [];

      list.push(row.module_code);

      modulesForQuestion.set(
        row.question_code,
        list,
      );
    }

    // =========================================================================
    // QUESTION RULES
    // =========================================================================

    const ruleEffects = new Map<
      string,
      {
        activateDelta: number;
        deactivated: boolean;
      }
    >();

    for (const rule of rules) {
      if (!ruleFires(rule, state, ageBucket)) {
        continue;
      }

      // Modules expand to their member questions.
      let targets: string[];

      if (rule.target_type === 'module') {
        targets = moduleMembers
          .filter((m) => m.module_code === rule.target_code)
          .map((m) => m.question_code);
      } else if (rule.target_type === 'question') {
        targets = [rule.target_code];
      } else {
        // Symptom activation is handled by question triggers.
        continue;
      }

      for (const target of targets) {
        const effect =
          ruleEffects.get(target)
          ?? {
            activateDelta: 0,
            deactivated: false,
          };

        if (rule.action === 'ACTIVATE') {
          effect.activateDelta +=
            Number(rule.priority_delta) || 0;
        }

        if (
          rule.action === 'DEACTIVATE'
          || rule.action === 'SUPPRESS'
        ) {
          effect.deactivated = true;
        }

        ruleEffects.set(target, effect);
      }
    }

    // =========================================================================
    // BUILD CANDIDATES
    // =========================================================================

    // Clinical pathways are derived once from patient context (sex, age,
    // pregnancy, gestational age) and drive dynamic question relevance.
    const activePathways = deriveActivePathways(state);

    const candidates: Candidate[] = [];

    for (const question of questions) {
      const code = question.question_code;

      // -----------------------------------------------------------------------
      // Already answered
      // -----------------------------------------------------------------------

      if (answeredQuestions.has(code)) {
        continue;
      }

      // -----------------------------------------------------------------------
      // Fact coverage
      // -----------------------------------------------------------------------

      const questionFact = questionFactByQuestion.get(code);

      const mappedFacts = unique(
        (mappingsByQuestion.get(code) ?? [])
          .map((x) => x.fact_definition_code),
      );

      const factCodes = unique([
        ...mappedFacts,
        ...(questionFact
          ? [questionFact.fact_definition_code]
          : []),
      ]);

      // A question without a clinical fact has no reasoning value.
      if (factCodes.length === 0) {
        continue;
      }

      // If every fact it can establish already exists, don't repeat it.
      //
      // IMPORTANT:
      // A captured fact may be revisited by a deliberately repeatable
      // measurement/question elsewhere; those questions should be represented
      // using a distinct capture identity or explicit repeat policy in the
      // knowledge layer rather than by silently repeating here.
      if (
        factCodes.every((fact) =>
          capturedCodes.has(fact),
        )
      ) {
        continue;
      }

      // -----------------------------------------------------------------------
      // Primary fact
      // -----------------------------------------------------------------------

      const primaryFactCode =
        questionFact?.fact_definition_code
        ?? (
          mappedFacts.length === 1
            ? mappedFacts[0]
            : null
        );

      // -----------------------------------------------------------------------
      // Requirements
      // -----------------------------------------------------------------------

      const requirementRows =
        requirementsByQuestion.get(code) ?? [];

      const requirement =
        bestRequirement(requirementRows);

      const requirementLevel =
        requirement?.level ?? 'informational';

      if (
        requirementLevel === 'informational'
        && !includeInformational
      ) {
        continue;
      }

      const requirementRank =
        REQUIREMENT_RANK[requirementLevel] ?? 5;

      const hasFoundationRequirement =
        requirementRows.some(
          (r) =>
            r.requirement_level === 'mandatory'
            || r.requirement_level === 'safety',
        );

      const hasUnconditionalRequirement =
        requirementRows.some(
          (r) => r.condition == null,
        );

      // -----------------------------------------------------------------------
      // Modules
      // -----------------------------------------------------------------------

      const moduleCodes =
        modulesForQuestion.get(code) ?? [];

      const isBiodata =
        moduleCodes.includes('BIODATA');

      // -----------------------------------------------------------------------
      // Context
      // -----------------------------------------------------------------------

      const questionContext =
        contextByQuestion.get(code) ?? [];

      const appliesRows =
        questionContext.filter(
          (c) => c.applicability === 'applies',
        );

      const excludesRows =
        questionContext.filter(
          (c) => c.applicability === 'excludes',
        );

      // Hard clinical exclusion.
      if (
        excludesRows.some(
          (c) =>
            contextExcludes(
              c,
              state,
              ageBucket,
            ),
        )
      ) {
        continue;
      }

      const contextApplicable =
        appliesRows.length === 0
          ? false
          : appliesRows.some(
              (c) =>
                contextApplies(
                  c,
                  state,
                  ageBucket,
                ),
            );

      // Fail closed for positive applicability rules.
      if (
        appliesRows.length > 0
        && !contextApplicable
      ) {
        continue;
      }

      // -----------------------------------------------------------------------
      // FOUNDATION
      // -----------------------------------------------------------------------

      const foundation =
        includeFoundation
        && (
          hasFoundationRequirement
          || (
            isBiodata
            && hasUnconditionalRequirement
          )
        );

      // -----------------------------------------------------------------------
      // TRIGGERS
      // -----------------------------------------------------------------------

      const questionTriggers =
        triggersByQuestion.get(code) ?? [];

      const triggerActivated =
        questionTriggers.length > 0
          ? questionTriggers.some((trigger) =>
              triggerMatches(
                trigger,
                activeSymptoms,
                capturedCodes,
                topPhenotypes,
                topMechanisms,
                topConditions,
              ),
            )
          : false;

      // -----------------------------------------------------------------------
      // REASONING RELEVANCE
      // -----------------------------------------------------------------------

      const phenotypeGain =
        phenotypeQuestionGain(
          code,
          phenotypes,
          phenotypeFacts,
          capturedCodes,
        );

      const mechanismGain =
        mechanismQuestionGain(
          code,
          mechanisms,
          mechanismQuestionWeight,
        );

      const differentialGain =
        differentialQuestionGain(
          code,
          differentials,
          conditionQuestionWeight,
        );

      const reasoningFactGain =
        questionFactGain(
          factCodes,
          phenotypes,
          phenotypeFacts,
          capturedCodes,
        );

      const reasoningActivated =
        phenotypeGain > 0
        || mechanismGain > 0
        || differentialGain > 0
        || reasoningFactGain > 0;

      // -----------------------------------------------------------------------
      // FOUNDATION / CONTEXT / TRIGGER / REASONING
      // -----------------------------------------------------------------------

      const activated =
        foundation
        || contextApplicable
        || triggerActivated
        || reasoningActivated;

      if (!activated) {
        continue;
      }

      // -----------------------------------------------------------------------
      // HPI GATING — HPI exploration requires a chief complaint
      // -----------------------------------------------------------------------
      //
      // Questions that serve an HPI objective (characterise, chronology,
      // associated symptoms, risk, aetiology, complications, safety context)
      // explore symptoms entered in the chief complaint. Without a chief
      // complaint there is nothing for the HPI to explore, so these questions
      // must not be offered until a presenting concern has been recorded.
      //
      // CC-entry questions (presenting concern, symptom onset/duration, biodata)
      // carry no HPI objective and are unaffected by this gate.
      if (
        hpiPhaseByQuestion.has(code)
        && activeSymptoms.length === 0
        && !capturedCodes.has('PRESENTING_COMPLAINT')
      ) {
        continue;
      }

      // -----------------------------------------------------------------------
      // SYMPTOM PRECONDITION — HPI is strictly confined to the symptoms
      // entered in the chief complaint and the associated symptoms answered
      // during the HPI.
      // -----------------------------------------------------------------------
      //
      // A question that presumes a symptom must not be offered while that
      // symptom is not present, even when a mandatory or context requirement
      // would otherwise force it. This prevents e.g. chest-pain character
      // questions appearing before any chest pain has been reported.
      //
      const symptomTriggers =
        questionTriggers.filter(
          (trigger) =>
            trigger.trigger_type === 'symptom',
        );

      if (
        symptomTriggers.length > 0
        && !symptomTriggers.some((trigger) =>
            triggerMatches(
              trigger,
              activeSymptoms,
              capturedCodes,
              topPhenotypes,
              topMechanisms,
              topConditions,
            ),
          )
      ) {
        continue;
      }

      // -----------------------------------------------------------------------
      // DEPENDENCIES
      // -----------------------------------------------------------------------

      const dependencies =
        dependenciesByQuestion.get(code) ?? [];

      const dependencyBlocked =
        dependencies.some(
          (dependency) =>
            !dependencySatisfied(
              dependency,
              state,
            ),
        );

      if (dependencyBlocked) {
        continue;
      }

      // -----------------------------------------------------------------------
      // REQUIREMENT CONDITIONS
      // -----------------------------------------------------------------------
      //
      // This is deliberately value-aware.
      //
      // Example:
      //
      // cough productive?
      //   UNKNOWN → ask sputum questions remains possible
      //
      // cough = dry
      //   → sputum-character questions may be suppressed
      //
      // smoking = never
      //   → pack-year calculation can be suppressed
      //
      // -----------------------------------------------------------------------

      if (
        !requirementsAllow(
          requirementRows,
          state.facts,
        )
      ) {
        continue;
      }

      // -----------------------------------------------------------------------
      // QUESTION RULES
      // -----------------------------------------------------------------------

      const ruleEffect =
        ruleEffects.get(code);

      if (ruleEffect?.deactivated) {
        continue;
      }

      // -----------------------------------------------------------------------
      // RED FLAG / SAFETY
      // -----------------------------------------------------------------------

      const safetyBoost =
        Math.max(
          0,
          ...factCodes.map(
            (fact) =>
              redFlagBoostByFact.get(fact) ?? 0,
          ),
        );

      // -----------------------------------------------------------------------
      // TRIGGER PRIORITY
      // -----------------------------------------------------------------------

      const triggerPriority =
        questionTriggers.length > 0
          ? Math.min(
              ...questionTriggers.map(
                (t) => Number(t.priority) || 50,
              ),
            )
          : 50;

      // -----------------------------------------------------------------------
      // INFORMATION GAIN
      // -----------------------------------------------------------------------
      //
      // Asking a question whose answer creates a fact relevant to the current
      // phenotype is more useful than an unrelated question.
      //
      // -----------------------------------------------------------------------

      const informationGain =
        reasoningFactGain;

      // -----------------------------------------------------------------------
      // CLINICAL PATHWAY AFFINITY
      // -----------------------------------------------------------------------

      const pathwayGain = pathwayAffinity(
        activePathways,
        factCodes,
        appliesRows,
        moduleCodes,
      );

      // -----------------------------------------------------------------------
      // REDUNDANCY
      // -----------------------------------------------------------------------

      const redundancyPenalty = redundancyPenaltyFor(
        state,
        capturedCodes,
        factCodes,
      );

      // -----------------------------------------------------------------------
      // BIODATA WORKFLOW STAGE
      // -----------------------------------------------------------------------

      const biodataStage = isBiodata
        ? (
            BIODATA_STAGE_BY_QUESTION[code]
            ?? null
          )
        : null;

      // -----------------------------------------------------------------------
      // ACTIVATION REASON
      // -----------------------------------------------------------------------

      const reason =
        activationReason({
          triggers: questionTriggers,
          requirementLevel,
          foundation,
          contextApplicable,
          differentialGain,
          mechanismGain,
          phenotypeGain,
          reasoningFactGain,
          leadingCondition,
          pathwayLabels: [...activePathways]
            .map(
              (pathway) =>
                PATHWAY_LABELS[pathway] ?? pathway,
            ),
          pathwayGain,
        });

      candidates.push({
        question,
        requirementLevel,
        requirementRank,
        factCodes,
        primaryFactCode,
        triggerPriority,
        safetyBoost,
        informationGain,
        differentialGain,
        mechanismGain,
        phenotypeGain,
        pathwayGain,
        redundancyPenalty,
        biodataStage,
        activationReason: reason,
        ruleDelta: ruleEffect?.activateDelta ?? 0,
        moduleCodes,
        variantText:
          variantByQuestion.get(code)
          ?? null,
      });
    }

    // =========================================================================
    // SORT
    // =========================================================================
    //
    // The queue is clinically ordered.
    //
    // Safety dominates.
    // Requirement level dominates ordinary relevance.
    // Differential/mechanism/phenotype relevance then discriminate.
    //
    // =========================================================================

    candidates.sort(
      (a, b) =>
        candidateScore(a, hpiPhaseByQuestion)
          - candidateScore(b, hpiPhaseByQuestion),
    );

    // =========================================================================
    // MODULE DIVERSITY
    // =========================================================================
    //
    // Avoid returning 20 cough questions when there are also critical general
    // or safety questions.
    //
    // =========================================================================

    const selected: Candidate[] = [];
    const moduleCounts = new Map<string, number>();

    for (const candidate of candidates) {
      if (selected.length >= limit) {
        break;
      }

      const eligibleModules =
        candidate.moduleCodes.length > 0
          ? candidate.moduleCodes
          : ['__UNMODULED__'];

      const hasAvailableModule =
        eligibleModules.some(
          (module) =>
            (moduleCounts.get(module) ?? 0)
              < maxPerModule,
        );

      if (!hasAvailableModule) {
        continue;
      }

      selected.push(candidate);

      for (const module of eligibleModules) {
        moduleCounts.set(
          module,
          (moduleCounts.get(module) ?? 0) + 1,
        );
      }
    }

    // =========================================================================
    // PROJECT TO PUBLIC CONTRACT
    // =========================================================================

    const optionsByQuestion =
      groupBy(
        optionRows,
        (x) => x.question_code,
      );

    return selected.map(
      (candidate) => ({
        questionCode:
          candidate.question.question_code,

        text:
          candidate.variantText
          ?? candidate.question.text,

        responseType:
          candidate.question.response_type as
          QuestionResponseType,

        requirementLevel:
          candidate.requirementLevel as
          QuestionRequirementLevel,

        priority:
          round(candidateScore(candidate, hpiPhaseByQuestion)),

        reason:
          candidate.activationReason,

        options:
          (
            optionsByQuestion.get(
              candidate.question.question_code,
            ) ?? []
          ).map(
            (option) => ({
              answerCode: option.answer_code,
              label: option.label,
            }),
          ),

        factCode:
          candidate.primaryFactCode,

        unitCode:
          questionFactByQuestion.get(
            candidate.question.question_code,
          )?.unit_code ?? null,

        // Clinical uncertainty is legitimate and must be representable.
        allowUnknown: true,

        // Not applicable is not the same as negative.
        allowNotApplicable: true,

        // Deferral is allowed only when the knowledge/UI contract explicitly
        // supports it. The safer default is false.
        allowDefer: false,

        defaultValue:
          candidate.question.default_value ?? null,
      }),
    );
  }
}

// =============================================================================
// CANDIDATE SCORE
// =============================================================================
//
// Lower score = earlier question.
//
// Safety is represented as a large negative score.
//
// Requirement is represented as the primary ordering axis.
//
// Relevance then moves the question upward.
//
// =============================================================================

export function candidateScore(
  candidate: Candidate,
  hpiPhaseByQuestion: Map<string, number>,
): number {
  // Biodata is a clinical workflow: the stage (identity → demographics →
  // informant → encounter → admission → reproductive → social) is the primary
  // axis. Within a stage the question's own sequence number (priority) is the
  // reading order, exactly as a clinician reads the card grid — name, then
  // age/DOB, then sex, then occupation. Requirement is only a tiebreak.
  //
  // Presenting-symptom exploration uses the same staged idea: each HPI
  // question belongs to an exploration phase (characterize → chronology →
  // associated → differential → aetiology/risk → complications →
  // health-seeking → function). The phase is the primary axis and the
  // requirement level is only a small tiebreak within the phase.
  //
  // Safety (red-flag) questions are exempt and keep the requirement-band
  // model so danger always leads the interview.
  const isStagedBiodata =
    candidate.biodataStage != null;

  const rawPriority =
    Number(candidate.question.priority) || 0;

  const hpiPhase = hpiPhaseByQuestion.get(
    candidate.question.question_code,
  );

  const usesHpiPhase =
    !isStagedBiodata
    && hpiPhase != null
    && candidate.safetyBoost === 0;

  const requirementComponent =
    isStagedBiodata
      ? (candidate.biodataStage as number) * 100
        + rawPriority * 2
        + candidate.requirementRank
      : usesHpiPhase
        ? (hpiPhase as number) / 10 * HPI_PHASE_STEP
          + candidate.requirementRank * 8
        : candidate.requirementRank * REQUIREMENT_STEP;

  const safetyComponent =
    candidate.safetyBoost * WEIGHTS.safety;

  const differentialComponent =
    candidate.differentialGain
    * WEIGHTS.differential;

  const mechanismComponent =
    candidate.mechanismGain
    * WEIGHTS.mechanism;

  const phenotypeComponent =
    candidate.phenotypeGain
    * WEIGHTS.phenotype;

  const informationComponent =
    candidate.informationGain
    * WEIGHTS.reasoningFact;

  const triggerComponent =
    Math.max(
      0,
      100 - candidate.triggerPriority,
    )
    * WEIGHTS.symptomTrigger;

  const ruleComponent =
    candidate.ruleDelta * 10;

  // Pathway relevance lifts a question within its requirement band. The lift
  // is clamped below a full band so a pathway question can overtake its band
  // peers but never silently leapfrog an entire requirement level.
  const pathwayComponent =
    Math.min(
      REQUIREMENT_STEP - 150,
      candidate.pathwayGain * WEIGHTS.pathway,
    );

  // Identity foundation leads the band so clinical intake never waits behind
  // administrative housekeeping.
  const identityComponent =
    candidate.factCodes.some(
      (fact) => IDENTITY_FACTS.includes(fact),
    )
      ? WEIGHTS.identity
      : 0;

  const redundancyComponent =
    candidate.redundancyPenalty * WEIGHTS.redundancy;

  return (
    requirementComponent
    - safetyComponent
    - differentialComponent
    - mechanismComponent
    - phenotypeComponent
    - informationComponent
    - triggerComponent
    - ruleComponent
    - pathwayComponent
    - identityComponent
    + redundancyComponent
    + (isStagedBiodata ? 0 : rawPriority)
  );
}

// =============================================================================
// PHENOTYPE QUESTION GAIN
// =============================================================================
//
// A question is useful if it can establish a fact that is part of one of the
// leading phenotypes and that fact is not already captured.
//
// =============================================================================

function phenotypeQuestionGain(
  questionCode: string,
  phenotypes: PhenotypeScore[],
  phenotypeFacts: Map<string, Set<string>>,
  capturedCodes: Set<string>,
): number {
  let gain = 0;

  for (const phenotype of phenotypes.slice(0, 5)) {
    const facts =
      phenotypeFacts.get(
        phenotype.phenotypeCode,
      );

    if (!facts) continue;

    // This function is intentionally called with questionCode only, so the
    // actual question→fact relationship is handled separately by
    // questionFactGain. Phenotype score contributes a baseline relevance here.
    //
    // The stronger the phenotype currently is, the more valuable questions
    // associated with it become.
    const uncaptured =
      [...facts].some(
        (fact) => !capturedCodes.has(fact),
      );

    if (uncaptured) {
      gain += Math.max(
        0,
        Number(phenotype.score) || 0,
      );
    }
  }

  return round(gain);
}

// =============================================================================
// MECHANISM QUESTION GAIN
// =============================================================================

function mechanismQuestionGain(
  questionCode: string,
  mechanisms: MechanismScore[],
  mechanismQuestions: Map<string, Map<string, number>>,
): number {
  let gain = 0;

  for (const mechanism of mechanisms.slice(0, 5)) {
    const weight =
      mechanismQuestions
        .get(mechanism.mechanismCode)
        ?.get(questionCode);

    if (weight == null) continue;

    gain +=
      Math.max(0, Number(weight))
      * Math.max(
        0,
        Number(mechanism.support) || 0,
      );
  }

  return round(gain);
}

// =============================================================================
// DIFFERENTIAL QUESTION GAIN
// =============================================================================
//
// Questions associated with the leading differential receive more weight.
//
// However, we deliberately consider several leading differentials.
//
// This prevents the engine from becoming prematurely anchored to diagnosis #1.
//
// =============================================================================

function differentialQuestionGain(
  questionCode: string,
  differentials: DifferentialCandidate[],
  conditionQuestions: Map<string, Map<string, number>>,
): number {
  let gain = 0;

  const top = differentials.slice(0, 5);

  top.forEach((differential, index) => {
    const weight =
      conditionQuestions
        .get(differential.conditionCode)
        ?.get(questionCode);

    if (weight == null) return;

    // Earlier differential = greater discrimination value.
    const rankMultiplier =
      1 / (index + 1);

    gain +=
      Math.max(0, Number(weight))
      * rankMultiplier;
  });

  return round(gain);
}

// =============================================================================
// QUESTION FACT INFORMATION GAIN
// =============================================================================

function questionFactGain(
  factCodes: string[],
  phenotypes: PhenotypeScore[],
  phenotypeFacts: Map<string, Set<string>>,
  capturedCodes: Set<string>,
): number {
  let gain = 0;

  for (const fact of factCodes) {
    if (capturedCodes.has(fact)) {
      continue;
    }

    for (const phenotype of phenotypes.slice(0, 5)) {
      const facts =
        phenotypeFacts.get(
          phenotype.phenotypeCode,
        );

      if (
        facts?.has(fact)
      ) {
        gain += Math.max(
          0,
          Number(phenotype.score) || 0,
        );
      }
    }
  }

  return round(gain);
}

// =============================================================================
// RULE EVALUATION
// =============================================================================

function ruleFires(
  rule: RuleRow,
  state: PatientClinicalState,
  ageBucket: string | null,
): boolean {
  // ---------------------------------------------------------------------------
  // CONTEXT RULE
  // ---------------------------------------------------------------------------

  if (rule.trigger_type === 'context') {
    if (
      rule.trigger_code === 'AGE'
      || rule.trigger_code === 'AGE_BAND'
    ) {
      const allowed =
        Array.isArray(rule.trigger_value)
          ? rule.trigger_value
          : [];

      return (
        ageBucket != null
        && allowed.includes(ageBucket)
      );
    }

    if (rule.trigger_code === 'SEX') {
      const expected =
        String(rule.trigger_value)
          .toLowerCase();

      const actual =
        normalizeSex(state.sex);

      return actual === expected;
    }

    if (rule.trigger_code === 'PREGNANCY') {
      const expected =
        String(rule.trigger_value)
          .toLowerCase();

      if (state.pregnant == null) {
        return false;
      }

      return (
        state.pregnant
          ? expected === 'pregnant'
          : expected === 'not_pregnant'
      );
    }

    if (rule.trigger_code === 'ENCOUNTER_TYPE') {
      return (
        normalizeEncounterType(
          state.encounterTypeCode,
        )
        === normalizeEncounterType(
          String(rule.trigger_value),
        )
      );
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // FACT RULE
  // ---------------------------------------------------------------------------

  const fact =
    state.facts.find(
      (f) =>
        f.factCode === rule.trigger_code,
    );

  if (!fact) {
    return false;
  }

  const value =
    fact.values[0];

  const text =
    value?.text
    ?? (
      value?.boolean != null
        ? String(value.boolean)
        : null
    );

  const numeric =
    value?.numeric;

  const expected =
    rule.trigger_value;

  switch (rule.trigger_operator) {
    case 'exists':
      return true;

    case 'eq':
      return (
        text != null
        && text === String(expected)
      );

    case 'neq':
      return (
        text != null
        && text !== String(expected)
      );

    case 'gt':
      return (
        numeric != null
        && numeric > Number(expected)
      );

    case 'gte':
      return (
        numeric != null
        && numeric >= Number(expected)
      );

    case 'lt':
      return (
        numeric != null
        && numeric < Number(expected)
      );

    case 'lte':
      return (
        numeric != null
        && numeric <= Number(expected)
      );

    case 'in': {
      const allowed =
        Array.isArray(expected)
          ? expected.map(String)
          : [];

      return (
        text != null
        && allowed.includes(text)
      );
    }

    case 'not_in': {
      const blocked =
        Array.isArray(expected)
          ? expected.map(String)
          : [];

      return (
        text != null
        && !blocked.includes(text)
      );
    }

    default:
      return false;
  }
}

// =============================================================================
// DEPENDENCY EVALUATION
// =============================================================================

function dependencySatisfied(
  dependency: DependencyRow,
  state: PatientClinicalState,
): boolean {
  // ---------------------------------------------------------------------------
  // QUESTION DEPENDENCY
  // ---------------------------------------------------------------------------

  if (
    dependency.prerequisite_type === 'question'
  ) {
    return (
      state.answeredQuestions.includes(
        dependency.prerequisite_code,
      )
    );
  }

  // ---------------------------------------------------------------------------
  // FACT DEPENDENCY
  // ---------------------------------------------------------------------------

  const fact =
    state.facts.find(
      (f) =>
        f.factCode
        === dependency.prerequisite_code,
    );

  if (!fact) {
    return false;
  }

  // Presence alone is sufficient.
  if (dependency.value == null) {
    return true;
  }

  const value =
    fact.values[0];

  const text =
    value?.text
    ?? (
      value?.boolean != null
        ? String(value.boolean)
        : null
    );

  const numeric =
    value?.numeric;

  switch (dependency.operator) {
    case 'eq':
      return (
        text != null
        && text === String(
          dependency.value,
        )
      );

    case 'neq':
      return (
        text != null
        && text !== String(
          dependency.value,
        )
      );

    case 'in': {
      const allowed =
        Array.isArray(dependency.value)
          ? dependency.value.map(String)
          : [];

      return (
        text != null
        && allowed.includes(text)
      );
    }

    case 'gt':
      return (
        numeric != null
        && numeric > Number(
          dependency.value,
        )
      );

    case 'gte':
      return (
        numeric != null
        && numeric >= Number(
          dependency.value,
        )
      );

    case 'lt':
      return (
        numeric != null
        && numeric < Number(
          dependency.value,
        )
      );

    case 'lte':
      return (
        numeric != null
        && numeric <= Number(
          dependency.value,
        )
      );

    default:
      return false;
  }
}

// =============================================================================
// REQUIREMENT CONDITIONS
// =============================================================================
//
// Conditions are eligibility rules.
//
// IMPORTANT:
//
// An unknown prerequisite does NOT make a clinical condition false.
//
// It simply means the question remains potentially eligible.
//
// =============================================================================

function bestRequirement(
  rows: RequirementRow[],
): { level: string } | null {
  if (rows.length === 0) {
    return null;
  }

  let best: RequirementRow | null = null;
  let bestRank = Number.POSITIVE_INFINITY;

  for (const row of rows) {
    const rank =
      REQUIREMENT_RANK[row.requirement_level] ?? 5;

    if (rank < bestRank) {
      bestRank = rank;
      best = row;
    }
  }

  return best
    ? { level: best.requirement_level }
    : null;
}

function requirementsAllow(
  rows: RequirementRow[],
  facts: Fact[],
): boolean {
  for (const row of rows) {
    if (
      row.condition == null
    ) {
      continue;
    }

    if (
      !conditionAllows(
        row.condition,
        facts,
      )
    ) {
      return false;
    }
  }

  return true;
}

interface FactCondition {
  code?: string;
  value?: unknown;
  in?: unknown[];
  not_in?: unknown[];
  gt?: number;
  gte?: number;
  lt?: number;
  lte?: number;
}

// =============================================================================
// CONDITION EVALUATOR
// =============================================================================

function conditionAllows(
  condition: unknown,
  facts: Fact[],
): boolean {
  if (
    condition == null
    || typeof condition !== 'object'
  ) {
    return true;
  }

  const object =
    condition as {
      fact?: FactCondition;
      all?: unknown[];
      any?: unknown[];
      not?: unknown;
    };

  // ---------------------------------------------------------------------------
  // ALL
  // ---------------------------------------------------------------------------

  if (Array.isArray(object.all)) {
    return object.all.every(
      (child) =>
        conditionAllows(
          child,
          facts,
        ),
    );
  }

  // ---------------------------------------------------------------------------
  // ANY
  // ---------------------------------------------------------------------------

  if (Array.isArray(object.any)) {
    return object.any.some(
      (child) =>
        conditionAllows(
          child,
          facts,
        ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOT
  // ---------------------------------------------------------------------------

  if (object.not != null) {
    return !conditionAllows(
      object.not,
      facts,
    );
  }

  // ---------------------------------------------------------------------------
  // FACT CONDITION
  // ---------------------------------------------------------------------------

  const requirement =
    object.fact;

  if (!requirement?.code) {
    return true;
  }

  const fact =
    facts.find(
      (f) =>
        f.factCode
        === requirement.code,
    );

  // Unknown ≠ negative.
  //
  // This is one of the most important clinical invariants in AMEXAN.
  if (!fact) {
    return true;
  }

  const value =
    fact.values[0];

  const text =
    value?.text
    ?? (
      value?.boolean != null
        ? String(value.boolean)
        : null
    );

  const numeric =
    value?.numeric;

  // ---------------------------------------------------------------------------
  // IN
  // ---------------------------------------------------------------------------

  if (
    Array.isArray(
      requirement.in,
    )
  ) {
    return (
      text != null
      && requirement.in
        .map(String)
        .includes(text)
    );
  }

  // ---------------------------------------------------------------------------
  // NOT IN
  // ---------------------------------------------------------------------------

  if (
    Array.isArray(
      requirement.not_in,
    )
  ) {
    return (
      text != null
      && !requirement.not_in
        .map(String)
        .includes(text)
    );
  }

  // ---------------------------------------------------------------------------
  // EXACT VALUE
  // ---------------------------------------------------------------------------

  if (
    requirement.value !== undefined
  ) {
    return (
      text != null
      && text
        === String(
          requirement.value,
        )
    );
  }

  // ---------------------------------------------------------------------------
  // NUMERIC CONDITIONS
  // ---------------------------------------------------------------------------

  if (
    requirement.gt !== undefined
    || requirement.gte !== undefined
    || requirement.lt !== undefined
    || requirement.lte !== undefined
  ) {
    if (numeric == null) {
      return false;
    }

    if (
      requirement.gt !== undefined
      && !(numeric > requirement.gt)
    ) {
      return false;
    }

    if (
      requirement.gte !== undefined
      && !(numeric >= requirement.gte)
    ) {
      return false;
    }

    if (
      requirement.lt !== undefined
      && !(numeric < requirement.lt)
    ) {
      return false;
    }

    if (
      requirement.lte !== undefined
      && !(numeric <= requirement.lte)
    ) {
      return false;
    }

    return true;
  }

  return true;
}

// =============================================================================
// TRIGGER MATCHING
// =============================================================================

function triggerMatches(
  trigger: TriggerRow,
  activeSymptoms: string[],
  capturedCodes: Set<string>,
  topPhenotypes: Set<string>,
  topMechanisms: Set<string>,
  topConditions: Set<string>,
): boolean {
  const code =
    normalizeClinicalToken(
      trigger.trigger_code,
    );

  switch (
    trigger.trigger_type
      .toLowerCase()
  ) {
    case 'symptom':
      return activeSymptoms.some(
        (symptom) =>
          symptom === code
          || symptom.includes(code)
          || code.includes(symptom),
      );

    case 'fact':
      return capturedCodes.has(
        trigger.trigger_code,
      );

    case 'phenotype':
      return topPhenotypes.has(
        trigger.trigger_code,
      );

    case 'mechanism':
      return topMechanisms.has(
        trigger.trigger_code,
      );

    case 'condition':
      return topConditions.has(
        trigger.trigger_code,
      );

    default:
      return false;
  }
}

// =============================================================================
// ACTIVATION REASON
// =============================================================================
//
// This is clinician-facing provenance.
//
// It tells the UI WHY the question is being asked.
//
// This is important for transparency and auditability.
//
// =============================================================================

function activationReason(input: {
  triggers: TriggerRow[];
  requirementLevel: string;
  foundation: boolean;
  contextApplicable: boolean;
  differentialGain: number;
  mechanismGain: number;
  phenotypeGain: number;
  reasoningFactGain: number;
  leadingCondition: string | null;
  pathwayLabels: string[];
  pathwayGain: number;
}): string {
  const reasons: string[] = [];

  if (input.foundation) {
    reasons.push(
      `clinical foundation: ${input.requirementLevel}`,
    );
  }

  if (input.contextApplicable) {
    reasons.push(
      'patient-context applicable',
    );
  }

  if (
    input.pathwayLabels.length > 0
    && input.pathwayGain > 0
  ) {
    reasons.push(
      `prioritised by active ${input.pathwayLabels.join(' / ')} pathway`,
    );
  }

  for (const trigger of input.triggers) {
    switch (
      trigger.trigger_type
        .toLowerCase()
    ) {
      case 'symptom':
        reasons.push(
          `active symptom: ${trigger.trigger_code}`,
        );
        break;

      case 'fact':
        reasons.push(
          `fact present: ${trigger.trigger_code}`,
        );
        break;

      case 'phenotype':
        reasons.push(
          `phenotype relevance: ${trigger.trigger_code}`,
        );
        break;

      case 'mechanism':
        reasons.push(
          `mechanism relevance: ${trigger.trigger_code}`,
        );
        break;

      case 'condition':
        reasons.push(
          `differential relevance: ${trigger.trigger_code}`,
        );
        break;
    }
  }

  if (input.differentialGain > 0) {
    reasons.push(
      'helps discriminate the active differential',
    );
  }

  if (input.mechanismGain > 0) {
    reasons.push(
      'helps distinguish the leading pathophysiological mechanism',
    );
  }

  if (input.phenotypeGain > 0) {
    reasons.push(
      'refines an active clinical phenotype',
    );
  }

  if (input.reasoningFactGain > 0) {
    reasons.push(
      'answer contributes directly to current clinical reasoning',
    );
  }

  if (
    reasons.length === 0
    && input.leadingCondition
  ) {
    reasons.push(
      `relevant to current differential: ${input.leadingCondition}`,
    );
  }

  if (reasons.length === 0) {
    reasons.push(
      'relevant to current clinical assessment',
    );
  }

  return `${input.requirementLevel} — ${unique(reasons).join('; ')}`;
}

// =============================================================================
// CONTEXT EXCLUSION
// =============================================================================
//
// These are HARD constraints.
//
// Examples:
//
// male + excludes SEX=female → excluded
// pregnant + excludes PREGNANCY=not_pregnant → excluded
// infant + excludes AGE=18-64Y → excluded
//
// =============================================================================

function contextExcludes(
  row: ContextExclusionRow,
  state: PatientClinicalState,
  ageBucket: string | null,
): boolean {
  const type =
    row.context_type_code
      .trim()
      .toUpperCase();

  if (
    type === 'AGE'
    || type === 'AGE_BAND'
  ) {
    return (
      ageBucket != null
      && ageBucket
        === row.context_value
    );
  }

  if (type === 'SEX') {
    const patientSex =
      normalizeSex(state.sex);

    const ruleSex =
      normalizeSex(
        row.context_value,
      );

    return (
      patientSex != null
      && ruleSex != null
      && patientSex === ruleSex
    );
  }

  if (
    type === 'PREGNANCY'
  ) {
    if (
      state.pregnant == null
    ) {
      return false;
    }

    const expected =
      row.context_value
        .trim()
        .toLowerCase();

    return state.pregnant
      ? expected === 'not_pregnant'
      : expected === 'pregnant';
  }

  if (
    type === 'ENCOUNTER_TYPE'
  ) {
    return (
      normalizeEncounterType(
        state.encounterTypeCode,
      )
      === normalizeEncounterType(
        row.context_value,
      )
    );
  }

  return false;
}

// =============================================================================
// POSITIVE CONTEXT APPLICABILITY
// =============================================================================

function contextApplies(
  row: ContextExclusionRow,
  state: PatientClinicalState,
  ageBucket: string | null,
): boolean {
  const type =
    row.context_type_code
      .trim()
      .toUpperCase();

  // ---------------------------------------------------------------------------
  // AGE
  // ---------------------------------------------------------------------------

  if (
    type === 'AGE'
    || type === 'AGE_BAND'
  ) {
    return (
      ageBucket != null
      && ageBucket
        === row.context_value
    );
  }

  // ---------------------------------------------------------------------------
  // SEX
  // ---------------------------------------------------------------------------

  if (type === 'SEX') {
    const patientSex =
      normalizeSex(state.sex);

    const requiredSex =
      normalizeSex(
        row.context_value,
      );

    return (
      patientSex != null
      && requiredSex != null
      && patientSex === requiredSex
    );
  }

  // ---------------------------------------------------------------------------
  // REPRODUCTIVE CONTEXT
  // ---------------------------------------------------------------------------

  if (
    type === 'REPRODUCTIVE'
  ) {
    if (
      state.ageYears == null
    ) {
      return false;
    }

    return (
      normalizeSex(state.sex)
        === 'female'
      && state.ageYears >= 12
      && state.ageYears <= 55
    );
  }

  // ---------------------------------------------------------------------------
  // PREGNANCY
  // ---------------------------------------------------------------------------

  if (
    type === 'PREGNANCY'
  ) {
    if (
      state.pregnant == null
    ) {
      return false;
    }

    const expected =
      row.context_value
        .trim()
        .toLowerCase();

    return state.pregnant
      ? expected === 'pregnant'
      : expected === 'not_pregnant';
  }

  // ---------------------------------------------------------------------------
  // ENCOUNTER TYPE
  // ---------------------------------------------------------------------------

  if (
    type === 'ENCOUNTER_TYPE'
  ) {
    return (
      normalizeEncounterType(
        state.encounterTypeCode,
      )
      === normalizeEncounterType(
        row.context_value,
      )
    );
  }

  return false;
}

// =============================================================================
// AGE BUCKET
// =============================================================================

function ageBucketFromState(
  state: PatientClinicalState,
): string | null {
  const years =
    state.ageYears;

  if (years != null) {
    if (
      years < 28 / 365.25
    ) {
      return '0-28D';
    }

    if (years < 1) {
      return '1-11M';
    }

    if (years < 5) {
      return '1-4Y';
    }

    if (years < 18) {
      return '5-17Y';
    }

    if (years < 65) {
      return '18-64Y';
    }

    return '65P';
  }

  if (
    state.ageDays != null
  ) {
    if (
      state.ageDays <= 28
    ) {
      return '0-28D';
    }

    if (
      state.ageDays < 365
    ) {
      return '1-11M';
    }

    if (
      state.ageDays < 5 * 365
    ) {
      return '1-4Y';
    }

    if (
      state.ageDays < 18 * 365
    ) {
      return '5-17Y';
    }

    return null;
  }

  if (
    state.ageMonths != null
  ) {
    if (
      state.ageMonths <= 1
    ) {
      return '0-28D';
    }

    if (
      state.ageMonths < 12
    ) {
      return '1-11M';
    }

    if (
      state.ageMonths < 60
    ) {
      return '1-4Y';
    }

    if (
      state.ageMonths < 216
    ) {
      return '5-17Y';
    }

    if (
      state.ageMonths < 780
    ) {
      return '18-64Y';
    }

    return '65P';
  }

  return null;
}

// =============================================================================
// NORMALIZATION
// =============================================================================

function normalizeSex(
  value: string | null | undefined,
): string | null {
  if (value == null) {
    return null;
  }

  const normalized =
    value
      .trim()
      .toLowerCase();

  if (
    normalized === 'm'
    || normalized === 'male'
  ) {
    return 'male';
  }

  if (
    normalized === 'f'
    || normalized === 'female'
  ) {
    return 'female';
  }

  if (
    normalized === 'intersex'
    || normalized === 'other'
  ) {
    return 'other';
  }

  if (
    normalized === 'unknown'
    || normalized === 'unspecified'
  ) {
    return 'unknown';
  }

  return normalized;
}

// =============================================================================
// ENCOUNTER TYPE NORMALIZATION
// =============================================================================

function normalizeEncounterType(
  value: string | null | undefined,
): string | null {
  if (value == null) {
    return null;
  }

  const v =
    value
      .trim()
      .toLowerCase();

  if (
    v === 'inpatient'
    || v === 'ipd'
  ) {
    return 'inpatient';
  }

  if (
    v === 'outpatient'
    || v === 'opd'
  ) {
    return 'outpatient';
  }

  if (
    v === 'emergency'
    || v === 'ed'
    || v === 'casualty'
  ) {
    return 'emergency';
  }

  return v;
}

// =============================================================================
// CLINICAL TOKEN NORMALIZATION
// =============================================================================

function normalizeClinicalToken(
  value: string,
): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/^sym[-_]/i, '')
    .replace(/[-_]+/g, ' ')
    .replace(/\s+/g, ' ');
}

function normalizeTokens(
  values: string[],
): string[] {
  return unique(
    values
      .map(normalizeClinicalToken)
      .filter(Boolean),
  );
}

// =============================================================================
// GENERIC GROUP BY
// =============================================================================

function groupBy<T>(
  rows: T[],
  key: (row: T) => string,
): Map<string, T[]> {
  const map =
    new Map<string, T[]>();

  for (const row of rows) {
    const k = key(row);

    const list =
      map.get(k)
      ?? [];

    list.push(row);

    map.set(k, list);
  }

  return map;
}

// =============================================================================
// UNIQUE
// =============================================================================

function unique<T>(
  values: T[],
): T[] {
  return [
    ...new Set(values),
  ];
}

// =============================================================================
// ROUNDING
// =============================================================================

function round(
  value: number,
): number {
  return Math.round(
    value * 100,
  ) / 100;
}