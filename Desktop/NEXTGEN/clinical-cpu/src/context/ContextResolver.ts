// =============================================================================
// AMEXAN Clinical CPU — ContextResolver
// Builds the canonical PatientClinicalState for one patient from live rows:
// demographics, encounter, every captured fact, and every answered question.
// This is what every engine reasons over.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { Fact, FactKind, FactValue, PatientClinicalState } from '../types.js';

interface FactRow extends Row {
  fact_id: string;
  encounter_id: string | null;
  fact_code: string;
  status_code: string;
  recorded_at: string;
  data_type: FactKind;
  value_text: string | null;
  value_numeric: number | null;
  value_boolean: boolean | null;
  unit_code: string | null;
  source_type: string | null;
}

// Mapping from a captured fact to the body-system symptom it makes "active".
// This drives the adaptive question engine (a question is only offered if its
// trigger symptom is active or its trigger fact exists).
const FACT_TO_SYMPTOM: Record<string, string> = {
  COUGH_PRESENT: 'cough',
  FEVER_PRESENT: 'fever',
  DYSPNOEA_PRESENT: 'dyspnoea',
  CHEST_PAIN_PRESENT: 'chest pain',
  CHEST_PAIN_PLEURITIC: 'chest pain',
  ABDO_PAIN_PRESENT: 'abdominal pain',
  HEARTBURN: 'heartburn',
};

const NEGATIVE_CODED: ReadonlySet<string> = new Set(['NO', 'NONE', 'FALSE', 'UNKNOWN', 'NON_PRODUCTIVE', 'NEVER']);

export function symptomIsActive(valueText: string | null): boolean {
  if (!valueText) return true;
  return !NEGATIVE_CODED.has(valueText.toUpperCase());
}

export function activeSymptomsFromFacts(facts: Fact[]): string[] {
  const symptoms = new Set<string>();
  for (const fact of facts) {
    const symptom = FACT_TO_SYMPTOM[fact.factCode];
    if (!symptom) continue;
    for (const value of fact.values) {
      const active = value.text != null ? symptomIsActive(value.text) : value.boolean !== false;
      if (active) symptoms.add(symptom);
    }
  }
  return [...symptoms];
}

export class ContextResolver {
  constructor(private readonly db: Db) {}

  async resolve(patientId: string, encounterId: string | null): Promise<PatientClinicalState> {
    const person = await this.db.queryOne<{ gender: string | null; birth_date: string | null }>(
      `SELECT pe.gender, pe.birth_date
         FROM patient.patient pa
         JOIN identity.person pe ON pe.id = pa.person_id
        WHERE pa.id = $1`,
      [patientId],
    );

    const ageYears = person?.birth_date ? ageInYears(person.birth_date) : null;

    const factRows = await this.db.query<FactRow>(
      `SELECT f.id AS fact_id, f.encounter_id, f.fact_definition_code AS fact_code,
              f.status_code, f.recorded_at,
              fv.data_type, fv.value_text, fv.value_numeric, fv.value_boolean, fv.unit_code,
              fs.source_type
         FROM clinical.fact f
         LEFT JOIN clinical.fact_value fv ON fv.fact_id = f.id
         LEFT JOIN clinical.fact_source fs ON fs.fact_id = f.id
        WHERE f.patient_id = $1
          AND f.status_code <> 'retracted'
        ORDER BY f.recorded_at, f.id`,
      [patientId],
    );

    const facts = groupFactRows(factRows);
    const answeredRows = await this.db.query<{ question_code: string }>(
      `SELECT DISTINCT payload->>'questionCode' AS question_code
         FROM cpu.event_log
        WHERE event_type IN ('QUESTION_ANSWERED', 'QUESTION_SKIPPED')
          AND payload->>'patientId' = $1
          AND payload->>'questionCode' IS NOT NULL`,
      [patientId],
    );
    const answeredQuestions = answeredRows.map((r) => r.question_code as string);

    const presentedRows = await this.db.query<{ symptom: string }>(
      `SELECT DISTINCT payload->>'symptom' AS symptom
         FROM cpu.event_log
        WHERE event_type = 'SYMPTOM_PRESENTED'
          AND payload->>'patientId' = $1
          AND payload->>'symptom' IS NOT NULL`,
      [patientId],
    );

    const symptomSet = new Set<string>(activeSymptomsFromFacts(facts));
    for (const row of presentedRows) {
      const symptom = (row.symptom as string).trim().toLowerCase();
      if (symptom) symptomSet.add(symptom);
    }

    return {
      patientId,
      encounterId,
      ageYears,
      sex: person?.gender ?? null,
      activeSymptoms: [...symptomSet],
      facts,
      answeredQuestions,
    };
  }
}

function groupFactRows(rows: FactRow[]): Fact[] {
  const byId = new Map<string, Fact>();
  for (const row of rows) {
    let fact = byId.get(row.fact_id);
    if (!fact) {
      fact = {
        id: row.fact_id,
        patientId: '',
        encounterId: row.encounter_id,
        factCode: row.fact_code,
        statusCode: row.status_code,
        recordedAt: row.recorded_at,
        sourceType: row.source_type,
        values: [],
      };
      byId.set(row.fact_id, fact);
    }
    if (row.data_type) {
      const value: FactValue = { dataType: row.data_type };
      if (row.value_text != null) value.text = row.value_text;
      if (row.value_numeric != null) value.numeric = Number(row.value_numeric);
      if (row.value_boolean != null) value.boolean = row.value_boolean;
      if (row.unit_code != null) value.unitCode = row.unit_code;
      fact.values.push(value);
    }
  }
  return [...byId.values()];
}

function ageInYears(birthDate: string): number {
  const birth = new Date(birthDate);
  const now = new Date();
  let years = now.getFullYear() - birth.getFullYear();
  const m = now.getMonth() - birth.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < birth.getDate())) years -= 1;
  return years;
}
