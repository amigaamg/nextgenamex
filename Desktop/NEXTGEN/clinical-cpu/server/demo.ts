// =============================================================================
// Demo encounter — the benchmark patient, created live so the UI has something
// to drive. The same pattern the benchmark uses, wrapped for the API.
// =============================================================================

import { randomUUID } from 'node:crypto';
import type { Db } from '../src/index.js';

export async function createDemoEncounter(db: Db): Promise<{ patientId: string; encounterId: string }> {
  const personId = randomUUID();
  const patientId = randomUUID();
  await db.query(
    `INSERT INTO identity.person (id, status_code, gender, birth_date, nationality, occupation)
     VALUES ($1, 'active', 'male', $2, 'Kenya', 'Driver')`,
    [personId, '1990-02-14'],
  );
  await db.query(
    `INSERT INTO patient.patient (id, person_id, mrn, status_code)
     VALUES ($1, $2, $3, 'active')`,
    [patientId, personId, `MRN-DEMO-${Date.now()}`],
  );
  const row = await db.queryOne<{ id: string }>(
    `INSERT INTO encounter.encounter (patient_id, encounter_type_code, status_code, phase_code)
     VALUES ($1, 'opd', 'active', 'assessment') RETURNING id`,
    [patientId],
  );
  return { patientId, encounterId: row!.id };
}
