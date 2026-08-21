import { Pool } from 'pg';
import { Db } from '../src/db.js';
import { SafetySentinel } from '../src/observability/SafetySentinel.js';

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: 'postgres',
  database: 'amexan',
});

const client = await pool.connect();
const db = new Db(client);
const sentinel = new SafetySentinel(db);

try {
  const result = await sentinel.evaluateDose({
    medicationCode: 'AMOXICILLIN',
    enteredDose: 500,
    doseUnit: 'mg',
    suggestedDose: 500,
    route: 'oral',
    frequency: 'every 8 hours',
    patientId: '7a24f680-2da5-40a6-974e-ddd322b56738',
    encounterId: '363b6488-5fbe-40c2-859a-7dedfbf8af77',
  });
  console.log('PASS case:', JSON.stringify(result, null, 2));
} catch (e) {
  console.error('FAILED:', e.message);
} finally {
  client.release();
  await pool.end();
}