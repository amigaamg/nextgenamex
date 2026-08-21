// =============================================================================
// Demo encounter — created live so the UI has something to drive. Accepts a
// patient context (age/birth date, sex, department/service, encounter type,
// pregnancy) so the universal format engine resolves to the right clinical
// format for the scenario the caller wants to exercise.
// =============================================================================

import { randomUUID } from 'node:crypto';
import type { Db } from '../src/index.js';

export interface DemoPatientContext {
  gender?: string;
  birthDate?: string;
  nationality?: string;
  occupation?: string;
  departmentCode?: string;
  encounterTypeCode?: string;
  pregnant?: boolean;
}

export async function createDemoEncounter(
  db: Db,
  context: DemoPatientContext = {},
): Promise<{ patientId: string; encounterId: string }> {
  const personId = randomUUID();
  const patientId = randomUUID();
  await db.query(
    `INSERT INTO identity.person (id, status_code, sex_at_birth, birth_date, nationality_code, occupation)
     VALUES ($1, 'active', $2, $3, $4, $5)`,
    [personId, context.gender ?? 'male', context.birthDate ?? '1990-02-14', context.nationality ?? 'KE', context.occupation ?? 'Driver'],
  );
  await db.query(
    `INSERT INTO patient.patient (id, person_id, status_code)
     VALUES ($1, $2, 'active')`,
    [patientId, personId],
  );
  const row = await db.queryOne<{ id: string }>(
    `INSERT INTO encounter.encounter (patient_id, encounter_type_code, status_code, phase_code)
     VALUES ($1, $2, 'active', 'assessment') RETURNING id`,
    [patientId, context.encounterTypeCode ?? 'opd'],
  );
  const encounterId = row!.id;

  // Bind the encounter to a department/service when supplied, so DEPARTMENT
  // format rules (knowledge.format_context_rule) fire from the real chain
  // encounter → encounter_service → organization.service.
  if (context.departmentCode) {
    const svc = await db.queryOne<{ id: string }>(
      `SELECT id FROM organization.service WHERE code = $1 AND is_active`,
      [context.departmentCode],
    );
    if (svc) {
      await db.query(
        `INSERT INTO encounter.encounter_service (id, encounter_id, service_id, is_primary)
         VALUES ($1, $2, $3, true)`,
        [randomUUID(), encounterId, svc.id],
      );
    }
  }

  // Record pregnancy as a fact so the context resolver (INVARIANT-002) resolves
  // it from facts — never from sex alone.
  if (context.pregnant) {
    const factId = randomUUID();
    await db.query(
      `INSERT INTO clinical.fact (id, patient_id, encounter_id, fact_definition_code, status_code, recorded_at)
       VALUES ($1, $2, $3, 'PREGNANT', 'active', now())`,
      [factId, patientId, encounterId],
    );
    await db.query(
      `INSERT INTO clinical.fact_value (id, fact_id, value_order, data_type, value_boolean, value_state)
       VALUES ($1, $2, 0, 'boolean', true, 'known')`,
      [randomUUID(), factId],
    );
  }

  return { patientId, encounterId };
}
