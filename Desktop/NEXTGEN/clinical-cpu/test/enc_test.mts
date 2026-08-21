import { Pool } from 'pg';
import { Db } from '../src/db.js';
import { createPersistentEncounter } from '../server/encounters.js';
import { ClinicalCPU } from '../src/runtime/ClinicalCPU.js';

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: 'postgres',
  database: 'amexan',
});

try {
  const client = await pool.connect();
  const db = new Db(client);
  const created = await createPersistentEncounter(db, {
    department: 'outpatient',
    encounterTypeCode: 'OUTPATIENT',
    presentingComplaintCodes: ['cough'],
  });
  console.log('created', created.patientId, created.encounterId);

  const cpu = new ClinicalCPU(db);
  const projection = await cpu.process({
    patientId: created.patientId,
    encounterId: created.encounterId,
    event: {
      type: 'ENCOUNTER_CREATED',
      payload: {
        department: 'outpatient',
        encounterType: 'OUTPATIENT',
        presentingComplaintCodes: ['cough'],
      },
    },
  });
  console.log('projection ok, runtime:', JSON.stringify(projection.runtime?.timings?.length));
  client.release();
} catch (e) {
  console.error('FAILED:', e.message);
  if (e.stack) console.error(e.stack.split('\n').slice(0, 8).join('\n'));
}
await pool.end();