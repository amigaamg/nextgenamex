// =============================================================================
// AMEXAN Clinical CPU — verify H10 governance runtime recording
// Builds a real patient + CAP facts, runs the full ClinicalCPU (one event in,
// one nephron + governance record out), then prints the H10 ledger it wrote:
//   reasoning_run, audit_event, rule_execution, provenance_record,
//   clinical_snapshot, reasoning_snapshot, documentation_snapshot
// Runs inside a transaction and ROLLS BACK: the database stays pristine and
// the script is re-runnable. Exit code 0 = H10 runtime recording verified.
// =============================================================================

import { randomUUID } from 'node:crypto';
import { Db, createPool } from '../src/db.js';
import type { Row } from '../src/db.js';
import { ClinicalCPU } from '../src/runtime/ClinicalCPU.js';

const pool = createPool();

async function main() {
  const client = await pool.connect();
  const db = new Db(client);
  const cpu = new ClinicalCPU(db);

  try {
    await client.query('BEGIN');

    const personId = randomUUID();
    const patientId = randomUUID();

    await client.query(
      `INSERT INTO identity.person (id, status_code, gender, birth_date, nationality, occupation)
       VALUES ($1, 'active', 'male', DATE '1990-02-14', 'Kenya', 'Farmer')`,
      [personId],
    );
    await client.query(
      `INSERT INTO patient.patient (id, person_id, mrn, status_code)
       VALUES ($1, $2, 'MRN-GOV-RUNTIME', 'active')`,
      [patientId, personId],
    );
    const { rows: [enc] } = await client.query(
      `INSERT INTO encounter.encounter (patient_id, encounter_type_code)
       VALUES ($1, 'opd') RETURNING id`,
      [patientId],
    );
    const encounterId = enc.id as string;

    const facts: [string, string, string | null, number | null, boolean | null][] = [
      ['COUGH_PRESENT', 'coded', 'YES', null, null],
      ['COUGH_DURATION_DAYS', 'numeric', null, 4, null],
      ['COUGH_PRODUCTIVITY', 'coded', 'PRODUCTIVE', null, null],
      ['SPUTUM_COLOUR', 'coded', 'CLEAR', null, null],
      ['FEVER_PRESENT', 'coded', 'YES', null, null],
      ['DYSPNOEA_PRESENT', 'coded', 'YES', null, null],
      ['CHEST_PAIN_PLEURITIC', 'coded', 'YES', null, null],
      ['RESP_RATE', 'numeric', null, 24, null],
      ['SPO2', 'numeric', null, 94, null],
      ['RLL_DULLNESS', 'boolean', null, null, true],
      ['RLL_BRONCHIAL_BREATH_SOUNDS', 'boolean', null, null, true],
      ['CRACKLES', 'boolean', null, null, true],
    ];
    for (const [code, kind, text, num, bool] of facts) {
      await client.query(
        `INSERT INTO clinical.fact (patient_id, encounter_id, fact_definition_code, status_code)
         VALUES ($1, $2, $3, 'active') RETURNING id`,
        [patientId, encounterId, code],
      ).then(({ rows: [row] }) =>
        client.query(
          `INSERT INTO clinical.fact_value (fact_id, data_type, value_text, value_numeric, value_boolean)
           VALUES ($1, $2, $3, $4, $5)`,
          [row.id, kind, text, num, bool],
        ),
      );
    }

    const projection = await cpu.process({
      patientId,
      encounterId,
      event: { type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } },
    });

    interface CountRow extends Row { n: number }
    const count = async (sql: string): Promise<number> =>
      Number((await db.queryOne<CountRow>(sql))?.n ?? 0);

    const reasoningRuns = await count(`SELECT count(*) AS n FROM knowledge.reasoning_run`);
    const audits = await count(`SELECT count(*) AS n FROM governance.audit_event WHERE run_id IS NOT NULL`);
    const rules = await count(`SELECT count(*) AS n FROM governance.rule_execution`);
    const provenance = await count(`SELECT count(*) AS n FROM governance.provenance_record`);
    const snapshots = await count(`SELECT count(*) AS n FROM governance.clinical_snapshot`);
    const reasonSnap = await count(`SELECT count(*) AS n FROM governance.reasoning_snapshot`);
    const docSnap = await count(`SELECT count(*) AS n FROM governance.documentation_snapshot`);

    const rows = await db.query<{ object_code: string }>(
      `SELECT DISTINCT p.governance_object_code AS object_code
         FROM governance.provenance_record p
        WHERE p.reasoning_run_id IS NOT NULL`,
    );

    console.log(`leading differential: ${projection.differentials?.[0]?.name ?? 'none'}`);
    console.log(`reasoning_run rows: ${reasoningRuns}`);
    console.log(`audit_event rows:   ${audits}`);
    console.log(`rule_execution rows:${rules}`);
    console.log(`provenance rows:    ${provenance}`);
    console.log(`clinical_snapshots: ${snapshots}`);
    console.log(`reasoning_snaps:    ${reasonSnap}`);
    console.log(`documentation_snaps:${docSnap}`);
    console.log(`provenance-objects: ${rows.map((r) => r.object_code).join(', ')}`);

    const auditKinds = await db.query<{ event_type: string }>(
      `SELECT event_type, count(*) FROM governance.audit_event GROUP BY event_type ORDER BY event_type`,
    );
    console.log(`audit stream:       ${auditKinds.map((a) => `${a.event_type}=${(a as unknown as { count: string }).count}`).join(' ')}`);

    const auditSample = await db.query<{ run_id: string | null; correlation_id: string | null }>(
      `SELECT run_id, correlation_id FROM governance.audit_event LIMIT 1`,
    );
    const provSample = await db.query<{ reasoning_run_id: string | null }>(
      `SELECT reasoning_run_id FROM governance.provenance_record LIMIT 1`,
    );
    console.log(`audit sample run_id: ${auditSample[0]?.run_id} correlation: ${auditSample[0]?.correlation_id}`);
    console.log(`prov sample reasoning_run_id: ${provSample[0]?.reasoning_run_id}`);

    const ok =
      reasoningRuns === 1 &&
      audits >= 6 &&
      rules >= 4 &&
      provenance >= 2 &&
      snapshots === 1 &&
      reasonSnap === 1 &&
      docSnap === 1;

    await client.query('ROLLBACK');

    if (!ok) {
      console.error('\nH10 governance runtime recording FAILED an expected-row check.');
      process.exit(1);
    }
    console.log('\nH10 runtime recording verified: reasoning_run + audit + rule_execution + provenance + snapshots created (rolled back).');
  } finally {
    await client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});