const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'amexan',
  user: 'postgres',
  password: 'postgres!',
  max: 1,
});

async function testCPU() {
  const client = await pool.connect();
  try {
    const { ClinicalCPU } = await import('../dist/src/runtime/ClinicalCPU.js');
    const { Db } = await import('../dist/src/db.js');
    
    const db = new Db(client);
    const cpu = new ClinicalCPU(db);
    
    // First create an encounter
    const personId = crypto.randomUUID();
    const patientId = crypto.randomUUID();
    
    await client.query(`
      INSERT INTO identity.person (id, status_code, sex_at_birth, birth_date, nationality_code)
      VALUES ($1, 'active', 'male', '1989-01-01', 'KE')
    `, [personId]);
    
    await client.query(`
      INSERT INTO patient.patient (id, person_id, status_code)
      VALUES ($1, $2, 'active')
    `, [patientId, personId]);
    
    const encounterResult = await client.query(`
      INSERT INTO encounter.encounter (patient_id, encounter_type_code, status_code, phase_code, started_at)
      VALUES ($1, 'opd', 'active', 'assessment', now())
      RETURNING id
    `, [patientId]);
    
    const encounterId = encounterResult.rows[0].id;
    
    // Add presenting complaint
    await client.query(`
      INSERT INTO encounter.encounter_reason (id, encounter_id, reason, is_primary)
      VALUES ($1, $2, 'Cough and fever for 3 days', true)
    `, [crypto.randomUUID(), encounterId]);
    
    console.log('Created encounter:', encounterId);
    
    // Now run CPU
    const result = await cpu.process({
      patientId,
      encounterId,
      event: {
        type: 'ENCOUNTER_CREATED',
        payload: {
          department: 'Outpatient',
          encounterType: 'opd',
          presentingComplaintCodes: ['COUGH', 'FEVER']
        }
      }
    });
    
    console.log('CPU Result:', JSON.stringify(result, null, 2));
    
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release();
    await pool.end();
  }
}

testCPU();