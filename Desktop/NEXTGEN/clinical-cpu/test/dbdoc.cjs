const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const client = await pool.connect();
  try {
    for (const t of ['document.document','document.document_version','document.document_export','encounter.encounter_status','encounter.encounter_phase']) {
      const parts = t.split('.');
      const r = await client.query(`
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns WHERE table_schema=$1 AND table_name=$2 ORDER BY ordinal_position
      `, [parts[0], parts[1]]);
      console.log('===', t, '===');
      console.log(JSON.stringify(r.rows));
      const c = await client.query(`
        SELECT conname, pg_get_constraintdef(oid) AS def FROM pg_constraint
        WHERE conrelid = $1::regclass AND contype='c'
      `, [t]);
      if (c.rows.length) { console.log('CHECKS:'); console.log(JSON.stringify(c.rows)); }
    }
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release(); await pool.end();
  }
})();