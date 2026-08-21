const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const client = await pool.connect();
  try {
    const s = await client.query(`SELECT code, label FROM encounter.encounter_status ORDER BY code`);
    console.log('ENCOUNTER_STATUS:', JSON.stringify(s.rows));
    const p = await client.query(`SELECT code, label FROM encounter.encounter_phase ORDER BY sort_order`);
    console.log('ENCOUNTER_PHASE:', JSON.stringify(p.rows));
    const t = await client.query(`SELECT code, label FROM document.document_type ORDER BY code`);
    console.log('DOCUMENT_TYPE:', JSON.stringify(t.rows));
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release(); await pool.end();
  }
})();