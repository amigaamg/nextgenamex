// =============================================================================
// AMEXAN Clinical CPU — ContextResolver
// =============================================================================
//
// PURPOSE
// -------
// Compiles the patient's distributed clinical data into ONE canonical,
// deterministic PatientClinicalState.
//
// This object is the clinical state boundary for the AMEXAN CPU.
//
// DOWNSTREAM ENGINES MUST NOT independently query:
//   - patient demographics
//   - encounters
//   - clinical.fact
//   - fact_value
//   - question events
//   - symptom presentation events
//
// They reason over PatientClinicalState produced here.
//
// CLINICAL PRINCIPLES
// -------------------
// 1. Symptoms are activated from explicit clinical assertions, not guesses.
// 2. A negative assertion must be able to supersede an older positive assertion.
// 3. UNKNOWN is not the same as NO.
// 4. Historical longitudinal facts remain available but must not silently
//    become current encounter symptoms.
// 5. Encounter-specific question state must be encounter-specific.
// 6. Pregnancy must never be inferred from sex.
// 7. Age bands are deterministic and clinically canonical.
// 8. Every derived state must be traceable to captured data.
// 9. The resolver performs state compilation, not diagnosis.
// 10. The resolver MUST NOT make diagnostic deductions.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  Fact,
  FactKind,
  FactValue,
  PatientClinicalState,
} from '../types.js';

// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface FactRow extends Row {
  fact_id: string;
  patient_id: string;
  encounter_id: string | null;

  fact_code: string;
  status_code: string;
  recorded_at: string;

  data_type: FactKind | null;

  value_text: string | null;
  value_numeric: number | null;
  value_boolean: boolean | null;
  unit_code: string | null;

  source_type: string | null;
}

// =============================================================================
// CLINICAL ASSERTION SEMANTICS
// =============================================================================
//
// IMPORTANT:
//
// We intentionally DO NOT use a generic:
//
//     "if value isn't NO then symptom is active"
//
// approach.
//
// A clinical fact has semantics.
//
// Example:
//
// COUGH_PRESENT = YES
//     -> establishes active cough.
//
// COUGH_PRESENT = NO
//     -> establishes absent cough.
//
// COUGH_PRESENT = UNKNOWN
//     -> establishes neither.
//
// COUGH_CHARACTER = BARKING
//     -> describes a cough.
//     -> does NOT independently establish cough.
//
// SPUTUM_ODOUR = FOUL
//     -> describes sputum.
//     -> does NOT independently establish cough.
//
// =============================================================================

const SYMPTOM_ASSERTION_FACTS: Readonly<Record<string, string>> = {
  COUGH_PRESENT: 'cough',
  FEVER_PRESENT: 'fever',
  DYSPNOEA_PRESENT: 'dyspnoea',
  CHEST_PAIN_PRESENT: 'chest pain',
  ABDO_PAIN_PRESENT: 'abdominal pain',
  HEADACHE_PRESENT: 'headache',
  VOMITING_PRESENT: 'vomiting',
  DIARRHOEA_PRESENT: 'diarrhoea',
  WHEEZE_PRESENT: 'wheeze',
  PALPITATIONS_PRESENT: 'palpitations',
  DIZZINESS_PRESENT: 'dizziness',
  SYNCOPE_PRESENT: 'syncope',
  SEIZURE_PRESENT: 'seizure',
  RASH_PRESENT: 'rash',
  PRURITUS_PRESENT: 'pruritus',
  FATIGUE_PRESENT: 'fatigue',
  WEIGHT_LOSS_PRESENT: 'weight loss',
  HAEMOPTYSIS_PRESENT: 'haemoptysis',
  OEDema_PRESENT: 'oedema',
};

// Descriptive facts that may only describe an already active symptom.
//
// These are deliberately NOT placed in SYMPTOM_ASSERTION_FACTS.
const SYMPTOM_DESCRIPTIVE_FACTS: ReadonlySet<string> = new Set([
  'COUGH_CHARACTER',
  'COUGH_TIMING',
  'COUGH_TRIGGERS',
  'COUGH_RELIEVING',
  'COUGH_POSITIONAL',
  'COUGH_DURATION_DAYS',
  'COUGH_PRODUCTIVITY',

  'SPUTUM_CONSISTENCY',
  'SPUTUM_ODOUR',
  'SPUTUM_COLOUR',
  'SPUTUM_VOLUME',

  'CHEST_PAIN_PLEURITIC',
  'CHEST_PAIN_CHARACTER',
  'CHEST_PAIN_LOCATION',
  'CHEST_PAIN_RADIATION',

  'DYSPNOEA_ONSET',
  'DYSPNOEA_SEVERITY',
]);

// Facts representing knowledge about another symptom that may itself be
// clinically useful but should not accidentally activate the original symptom.
const ASSOCIATED_SYMPTOM_FACTS: ReadonlySet<string> = new Set([
  'RHINORRHOEA',
  'SORE_THROAT',
  'HOARSENESS',
  'POSTNASAL_DRIP',
  'ORTHOPNOEA',
  'PND',
  'LEG_SWELLING',
  'HEARTBURN',
]);

// Values that explicitly establish absence.
//
// UNKNOWN IS DELIBERATELY NOT HERE.
const NEGATIVE_VALUES: ReadonlySet<string> = new Set([
  'NO',
  'FALSE',
  'NONE',
  'NEVER',
  'ABSENT',
]);

// Values that explicitly establish presence.
const POSITIVE_VALUES: ReadonlySet<string> = new Set([
  'YES',
  'TRUE',
  'PRESENT',
]);

// Values that establish uncertainty.
//
// These must never be converted to false.
const UNKNOWN_VALUES: ReadonlySet<string> = new Set([
  'UNKNOWN',
  'NOT_KNOWN',
  'UNSURE',
  'UNCERTAIN',
  'NOT_TESTED',
]);

// =============================================================================
// TRI-STATE CLINICAL ASSERTION
// =============================================================================

export type ClinicalAssertion =
  | 'present'
  | 'absent'
  | 'unknown';

function classifyAssertion(value: FactValue): ClinicalAssertion {
  if (value.boolean != null) {
    return value.boolean ? 'present' : 'absent';
  }

  if (value.text != null) {
    const normalized = normalizeCode(value.text);

    if (POSITIVE_VALUES.has(normalized)) {
      return 'present';
    }

    if (NEGATIVE_VALUES.has(normalized)) {
      return 'absent';
    }

    if (UNKNOWN_VALUES.has(normalized)) {
      return 'unknown';
    }
  }

  return 'unknown';
}

// =============================================================================
// NORMALIZATION
// =============================================================================

function normalizeCode(value: string): string {
  return value
    .trim()
    .replace(/[\s-]+/g, '_')
    .toUpperCase();
}

function normalizeSymptom(value: string): string {
  return value
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

// =============================================================================
// PUBLIC HELPERS
// =============================================================================

/**
 * Returns whether a value explicitly asserts that something is present.
 *
 * IMPORTANT:
 * UNKNOWN returns false.
 * It does NOT mean absent.
 */
export function valueIsPresent(value: FactValue): boolean {
  return classifyAssertion(value) === 'present';
}

/**
 * Returns whether a value explicitly asserts absence.
 */
export function valueIsAbsent(value: FactValue): boolean {
  return classifyAssertion(value) === 'absent';
}

/**
 * Returns whether the value is unknown / indeterminate.
 */
export function valueIsUnknown(value: FactValue): boolean {
  return classifyAssertion(value) === 'unknown';
}

/**
 * Converts a fact collection into currently asserted symptoms.
 *
 * Only explicit *_PRESENT facts can establish symptom presence.
 *
 * Descriptive facts such as COUGH_CHARACTER or SPUTUM_ODOUR do not create
 * symptoms on their own.
 */
export function activeSymptomsFromFacts(facts: Fact[]): string[] {
  const symptoms = new Set<string>();

  // -------------------------------------------------------------------------
  // Resolve only explicit symptom assertion facts.
  // -------------------------------------------------------------------------

  const latestAssertions = latestFactByCode(facts);

  for (const [factCode, fact] of latestAssertions.entries()) {
    const symptom = SYMPTOM_ASSERTION_FACTS[factCode];

    if (!symptom) continue;

    const assertion = factAssertion(fact);

    if (assertion === 'present') {
      symptoms.add(symptom);
    }
  }

  // Chief complaints also establish symptom presence. The structured
  // CHIEF_COMPLAINT_ORDER fact records the complaint codes (oldest first).
  // Deriving symptoms here makes the question battery robust even before the
  // *_PRESENT mirror facts are persisted by ingestion.
  const orderFact = latestAssertions.get('CHIEF_COMPLAINT_ORDER');

  if (orderFact) {
    const orderText = firstTextValue(orderFact);

    if (orderText) {
      for (const rawCode of orderText.split(',')) {
        const symptom = normalizeSymptom(
          rawCode.trim().replace(/_+/g, ' '),
        );

        if (symptom) {
          symptoms.add(symptom);
        }
      }
    }
  }

  return [...symptoms].sort();
}

/**
 * Return the assertion represented by the values of a fact.
 *
 * If multiple values exist, affirmative values take precedence only within
 * that single captured fact. The temporal precedence between facts is handled
 * separately by latestFactByCode().
 */
function factAssertion(fact: Fact): ClinicalAssertion {
  let sawUnknown = false;

  for (const value of fact.values) {
    const assertion = classifyAssertion(value);

    if (assertion === 'present') return 'present';
    if (assertion === 'unknown') sawUnknown = true;
  }

  return sawUnknown ? 'unknown' : 'absent';
}

// =============================================================================
// CONTEXT RESOLVER
// =============================================================================

export class ContextResolver {
  constructor(private readonly db: Db) {}

  async resolve(
    patientId: string,
    encounterId: string | null,
  ): Promise<PatientClinicalState> {

    // =========================================================================
    // 1. PATIENT IDENTITY / DEMOGRAPHICS
    // =========================================================================

    const person = await this.db.queryOne<{
      gender: string | null;
      birth_date: string | null;
      jurisdiction_code: string | null;
    }>(
      `
      SELECT
          pe.sex_at_birth AS gender,
          pe.birth_date,
          j.jurisdiction_code
        FROM patient.patient pa
        JOIN identity.person pe
          ON pe.id = pa.person_id
        LEFT JOIN governance.jurisdiction j
          ON j.country_code = upper(pe.nationality_code)
         AND j.is_active
       WHERE pa.id = $1
      `,
      [patientId],
    );

    // =========================================================================
    // 2. AGE
    // =========================================================================

    const age = person?.birth_date
      ? calculateAge(person.birth_date)
      : {
          years: null,
          months: null,
          days: null,
        };

    const ageBand =
      age.days != null
        ? canonicalAgeBand(age.days)
        : null;

    // =========================================================================
    // 3. ALL LIVE FACTS
    // =========================================================================
    //
    // We deliberately retrieve all non-retracted facts.
    //
    // Why?
    //
    // Because the CPU needs:
    //   - current assertions
    //   - longitudinal risk factors
    //   - historical clinical information
    //   - provenance
    //   - encounter association
    //
    // Temporal resolution occurs AFTER retrieval.
    //
    // =========================================================================

    const factRows = await this.db.query<FactRow>(
      `
      SELECT
          f.id AS fact_id,
          f.patient_id,
          f.encounter_id,
          f.fact_definition_code AS fact_code,
          f.status_code,
          f.recorded_at,

          fv.data_type,
          fv.value_text,
          fv.value_numeric,
          fv.value_boolean,
          fv.unit_code,

          fs.source_type

        FROM clinical.fact f

        LEFT JOIN clinical.fact_value fv
          ON fv.fact_id = f.id

        LEFT JOIN clinical.fact_source fs
          ON fs.fact_id = f.id

       WHERE f.patient_id = $1
         AND f.status_code <> 'retracted'

       ORDER BY
          f.recorded_at ASC,
          f.id ASC
      `,
      [patientId],
    );

    const facts = groupFactRows(factRows);

    // =========================================================================
    // 4. QUESTION STATE
    // =========================================================================
    //
    // Question completion is an encounter workflow state.
    //
    // A question answered six months ago should NOT suppress the same question
    // in today's encounter.
    //
    // For longitudinal questions, the question engine should use the captured
    // fact instead.
    // =========================================================================

    const answeredQuestions = await this.resolveAnsweredQuestions(
      patientId,
      encounterId,
    );

    // =========================================================================
    // 5. PRESENTED SYMPTOMS
    // =========================================================================
    //
    // SYMPTOM_PRESENTED is encounter-level narrative state.
    //
    // We therefore constrain it to the active encounter whenever an encounter
    // is supplied.
    // =========================================================================

    const presentedSymptoms = await this.resolvePresentedSymptoms(
      patientId,
      encounterId,
    );

    // =========================================================================
    // 6. ACTIVE SYMPTOMS
    // =========================================================================

    const symptomSet = new Set<string>(
      activeSymptomsFromFacts(facts),
    );

    for (const symptom of presentedSymptoms) {
      symptomSet.add(normalizeSymptom(symptom));
    }

    // =========================================================================
    // 7. PREGNANCY
    // =========================================================================
    //
    // INVARIANT:
    //
    // Pregnancy is NEVER inferred from sex.
    //
    // Pregnancy requires an explicit affirmative pregnancy assertion or a
    // gestational-age fact that belongs to the current clinical episode.
    //
    // =========================================================================

    const pregnant = resolvePregnancy(
      facts,
      encounterId,
    );

    const gestationalAgeWeeksValue =
      gestationalAgeWeeks(facts, encounterId);

    // =========================================================================
    // 8. ENCOUNTER CONTEXT
    // =========================================================================

    let departmentCode: string | null = null;
    let encounterTypeCode: string | null = null;

    if (encounterId) {
      const encounter = await this.db.queryOne<{
        encounter_type_code: string | null;
        department_code: string | null;
      }>(
        `
        SELECT
            e.encounter_type_code,
            os.code AS department_code
          FROM encounter.encounter e
          LEFT JOIN encounter.encounter_service es
            ON es.encounter_id = e.id
           AND es.is_primary = TRUE
          LEFT JOIN organization.service os
            ON os.id = es.service_id
         WHERE e.id = $1
        `,
        [encounterId],
      );

      encounterTypeCode =
        encounter?.encounter_type_code ?? null;

      departmentCode =
        encounter?.department_code ?? null;
    }

    // =========================================================================
    // 9. ENCOUNTER TYPE OVERRIDE
    // =========================================================================
    //
    // The registration/narrative workflow may have captured the actual
    // encounter type as a fact.
    //
    // The explicit clinical fact therefore takes precedence over a UI default.
    //
    // =========================================================================

    const encounterTypeFact =
      latestFactForCode(facts, 'ENCOUNTER_TYPE');

    if (encounterTypeFact) {
      const value =
        firstTextValue(encounterTypeFact);

      const normalized =
        normalizeEncounterType(value);

      if (normalized) {
        encounterTypeCode = normalized;
      }
    }

    // =========================================================================
    // 10. DOMAIN RESOLUTION
    // =========================================================================

    const activeDomains =
      await this.resolveDomains([...symptomSet]);

    // =========================================================================
    // 11. BUILD CANONICAL STATE
    // =========================================================================

    return {
      patientId,
      encounterId,

      ageYears: age.years,
      ageDays: age.days,
      ageMonths: age.months,

      ageBand,

      sex: person?.gender ?? null,

      pregnant,

      gestationalAgeWeeks:
        gestationalAgeWeeksValue,

      departmentCode,
      encounterTypeCode,

      activeDomains,

      jurisdictionCode:
        person?.jurisdiction_code ?? null,

      activeSymptoms:
        [...symptomSet].sort(),

      facts,

      answeredQuestions,
    };
  }

  // ===========================================================================
  // QUESTION EVENTS
  // ===========================================================================

  private async resolveAnsweredQuestions(
    patientId: string,
    encounterId: string | null,
  ): Promise<string[]> {

    const rows = await this.db.query<{
      question_code: string;
    }>(
      `
      SELECT DISTINCT
          payload->>'questionCode' AS question_code

        FROM cpu.event_log

       WHERE event_type IN (
          'QUESTION_ANSWERED',
          'QUESTION_SKIPPED',
          'QUESTION_DISPOSITIONED'
       )

         AND payload->>'patientId' = $1

         AND payload->>'questionCode' IS NOT NULL

         AND (
              $2::uuid IS NULL
              OR payload->>'encounterId' = $2::text
         )
      `,
      [patientId, encounterId],
    );

    return rows
      .map((row) => row.question_code)
      .filter(Boolean)
      .map(normalizeCode)
      .sort();
  }

  // ===========================================================================
  // PRESENTED SYMPTOMS
  // ===========================================================================

  private async resolvePresentedSymptoms(
    patientId: string,
    encounterId: string | null,
  ): Promise<string[]> {

    const rows = await this.db.query<{
      symptom: string;
    }>(
      `
      SELECT DISTINCT
          payload->>'symptom' AS symptom

        FROM cpu.event_log

       WHERE event_type = 'SYMPTOM_PRESENTED'

         AND payload->>'patientId' = $1

         AND payload->>'symptom' IS NOT NULL

         AND (
              $2::uuid IS NULL
              OR payload->>'encounterId' = $2::text
         )
      `,
      [patientId, encounterId],
    );

    return rows
      .map((row) => normalizeSymptom(row.symptom))
      .filter(Boolean)
      .sort();
  }

  // ===========================================================================
  // DOMAIN RESOLUTION
  // ===========================================================================

  private async resolveDomains(
    symptoms: string[],
  ): Promise<string[]> {

    const normalizedSymptoms = [
      ...new Set(
        symptoms
          .map(normalizeSymptom)
          .filter(Boolean),
      ),
    ];

    if (normalizedSymptoms.length === 0) {
      return [];
    }

    // =========================================================================
    // ONE QUERY.
    //
    // Do NOT execute one database query per symptom.
    // =========================================================================

    const rows = await this.db.query<{
      body_system_code: string;
    }>(
      `
      SELECT DISTINCT
          ss.body_system_code

        FROM knowledge.symptom_system ss

        JOIN knowledge.symptom s
          ON s.id = ss.symptom_id

       WHERE lower(s.canonical_name) = ANY($1::text[])
      `,
      [normalizedSymptoms],
    );

    return [
      ...new Set(
        rows
          .map((row) => row.body_system_code)
          .filter(Boolean),
      ),
    ].sort();
  }
}

// =============================================================================
// FACT GROUPING
// =============================================================================
//
// Converts normalized database rows into the domain Fact[] structure.
//
// IMPORTANT:
// The original implementation lost patientId by setting:
//
//     patientId: ''
//
// That is corrected here.
//
// =============================================================================

function groupFactRows(rows: FactRow[]): Fact[] {

  const byId = new Map<string, Fact>();

  for (const row of rows) {

    let fact = byId.get(row.fact_id);

    if (!fact) {
      fact = {
        id: row.fact_id,

        patientId: row.patient_id,

        encounterId: row.encounter_id,

        factCode: normalizeCode(row.fact_code),

        statusCode: normalizeCode(row.status_code),

        recordedAt: row.recorded_at,

        sourceType: row.source_type,

        values: [],
      };

      byId.set(row.fact_id, fact);
    }

    // A fact may exist without a value row.
    if (!row.data_type) {
      continue;
    }

    const value: FactValue = {
      dataType: row.data_type,
    };

    if (row.value_text != null) {
      value.text = row.value_text;
    }

    if (row.value_numeric != null) {
      value.numeric = Number(row.value_numeric);
    }

    if (row.value_boolean != null) {
      value.boolean = row.value_boolean;
    }

    if (row.unit_code != null) {
      value.unitCode = row.unit_code;
    }

    fact.values.push(value);
  }

  return [...byId.values()];
}

// =============================================================================
// TEMPORAL FACT RESOLUTION
// =============================================================================
//
// The patient can have:
//
// 10:00 COUGH_PRESENT = YES
// 14:00 COUGH_PRESENT = NO
//
// The current clinical state is NOT:
//
//     cough = true
//
// simply because a historical positive exists.
//
// The latest valid assertion wins for assertion-type facts.
//
// =============================================================================

function latestFactByCode(
  facts: Fact[],
): Map<string, Fact> {

  const map = new Map<string, Fact>();

  const sorted = [...facts].sort(
    (a, b) => {
      const time =
        new Date(b.recordedAt).getTime() -
        new Date(a.recordedAt).getTime();

      if (time !== 0) return time;

      return b.id.localeCompare(a.id);
    },
  );

  for (const fact of sorted) {
    const code = normalizeCode(fact.factCode);

    if (!map.has(code)) {
      map.set(code, fact);
    }
  }

  return map;
}

function latestFactForCode(
  facts: Fact[],
  code: string,
): Fact | null {

  return latestFactByCode(facts)
    .get(normalizeCode(code)) ?? null;
}

// =============================================================================
// TEXT VALUE EXTRACTION
// =============================================================================

function firstTextValue(
  fact: Fact,
): string | null {

  for (const value of fact.values) {
    if (value.text != null) {
      return value.text;
    }
  }

  return null;
}

// =============================================================================
// AGE ENGINE
// =============================================================================
//
// We deliberately calculate calendar age rather than:
//
//     elapsedMilliseconds / 365.25
//
// because clinical age bands depend on exact birthday boundaries.
//
// =============================================================================

function calculateAge(
  birthDateString: string,
): {
  years: number;
  months: number;
  days: number;
} {

  // Dates stored as YYYY-MM-DD should be interpreted as calendar dates,
  // not UTC timestamps.
  const birth = parseCalendarDate(birthDateString);

  const now = new Date();

  let years =
    now.getFullYear() -
    birth.getFullYear();

  let months =
    now.getMonth() -
    birth.getMonth();

  let days =
    now.getDate() -
    birth.getDate();

  if (days < 0) {
    months -= 1;

    const previousMonth =
      new Date(
        now.getFullYear(),
        now.getMonth(),
        0,
      );

    days += previousMonth.getDate();
  }

  if (months < 0) {
    years -= 1;
    months += 12;
  }

  const birthMs = birth.getTime();
  const nowMs = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  ).getTime();

  const totalDays = Math.max(
    0,
    Math.floor(
      (nowMs - birthMs) /
      (24 * 3600 * 1000),
    ),
  );

  return {
    years,
    months,
    days: totalDays,
  };
}

function parseCalendarDate(
  value: string,
): Date {

  const match =
    /^(\d{4})-(\d{2})-(\d{2})/.exec(value);

  if (!match) {
    const parsed = new Date(value);

    if (Number.isNaN(parsed.getTime())) {
      throw new Error(
        `Invalid birth date: ${value}`,
      );
    }

    return parsed;
  }

  return new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
  );
}

// =============================================================================
// CANONICAL AGE BANDS
// =============================================================================
//
// AMEXAN INVARIANT-001
//
// NEONATE:     0–27 completed days
// INFANT:      28 days–<1 year
// CHILD:       1–<12 years
// ADOLESCENT:  12–<18 years
// ADULT:       >=18 years
//
// =============================================================================

export function canonicalAgeBand(
  ageDays: number,
): string {

  if (ageDays < 0) {
    throw new Error(
      `Invalid negative patient age: ${ageDays} days`,
    );
  }

  if (ageDays < 28) {
    return 'NEONATE';
  }

  if (ageDays < 365) {
    return 'INFANT';
  }

  if (ageDays < 4383) {
    return 'CHILD';
  }

  if (ageDays < 6574) {
    return 'ADOLESCENT';
  }

  return 'ADULT';
}

// =============================================================================
// PREGNANCY RESOLUTION
// =============================================================================
//
// AMEXAN INVARIANT-002
//
// NEVER:
//     sex = female -> pregnant
//
// NEVER:
//     historical pregnancy -> currently pregnant
//
// NEVER:
//     gestational age from an unrelated historical encounter -> current
//     pregnancy
//
// Pregnancy is resolved from explicit current clinical facts.
//
// =============================================================================

function resolvePregnancy(
  facts: Fact[],
  encounterId: string | null,
): boolean | null {

  const pregnancyFacts =
    facts
      .filter(
        (fact) =>
          normalizeCode(fact.factCode) === 'PREGNANT',
      )
      .filter(
        (fact) =>
          isCurrentClinicalFact(
            fact,
            encounterId,
          ),
      )
      .sort(compareFactsDescending);

  if (pregnancyFacts.length > 0) {

    const latest =
      pregnancyFacts[0];

    const assertion =
      factAssertion(latest);

    if (assertion === 'present') {
      return true;
    }

    if (assertion === 'absent') {
      return false;
    }

    return null;
  }

  // A current gestational-age fact can establish pregnancy.
  const currentGestationalAge =
    facts.some(
      (fact) =>
        normalizeCode(fact.factCode) ===
          'GESTATIONAL_AGE_WEEKS' &&
        isCurrentClinicalFact(
          fact,
          encounterId,
        ) &&
        fact.values.some(
          (value) =>
            value.numeric != null &&
            value.numeric >= 0 &&
            value.numeric <= 45,
        ),
    );

  if (currentGestationalAge) {
    return true;
  }

  return null;
}

// =============================================================================
// GESTATIONAL AGE
// =============================================================================

function gestationalAgeWeeks(
  facts: Fact[],
  encounterId: string | null,
): number | null {

  const candidates =
    facts
      .filter(
        (fact) =>
          normalizeCode(fact.factCode) ===
          'GESTATIONAL_AGE_WEEKS',
      )
      .filter(
        (fact) =>
          isCurrentClinicalFact(
            fact,
            encounterId,
          ),
      )
      .sort(compareFactsDescending);

  for (const fact of candidates) {

    for (const value of fact.values) {

      if (
        value.numeric != null &&
        value.numeric >= 0 &&
        value.numeric <= 45
      ) {
        return value.numeric;
      }
    }
  }

  return null;
}

// =============================================================================
// CURRENT CLINICAL FACT
// =============================================================================
//
// Encounter facts belong to the encounter.
//
// Longitudinal facts can remain valid across encounters.
//
// We therefore use the following rule:
//
//   encounterId matches -> current
//
//   encounterId is null -> longitudinal/currently applicable
//
//   encounterId belongs to another encounter -> not treated as current for
//   encounter-specific state derivation.
//
// =============================================================================

function isCurrentClinicalFact(
  fact: Fact,
  encounterId: string | null,
): boolean {

  if (fact.encounterId == null) {
    return true;
  }

  if (encounterId == null) {
    return false;
  }

  return fact.encounterId === encounterId;
}

function compareFactsDescending(
  a: Fact,
  b: Fact,
): number {

  const time =
    new Date(b.recordedAt).getTime() -
    new Date(a.recordedAt).getTime();

  if (time !== 0) return time;

  return b.id.localeCompare(a.id);
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
    normalizeCode(value);

  switch (v) {

    case 'INPATIENT':
    case 'IPD':
      return 'ipd';

    case 'OUTPATIENT':
    case 'OPD':
      return 'opd';

    case 'EMERGENCY':
    case 'ED':
    case 'ER':
      return 'emergency';

    default:
      return v.toLowerCase();
  }
}