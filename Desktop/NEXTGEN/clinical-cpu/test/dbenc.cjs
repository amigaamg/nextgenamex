const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const client = await pool.connect();
  try {
    const r = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema='encounter' AND table_name='encounter'
      ORDER BY ordinal_position
    `);
    console.log('COLUMNS:'); console.log(JSON.stringify(r.rows, null, 1));
    const c = await client.query(`
      SELECT conname, pg_get_constraintdef(oid) AS def
      FROM pg_constraint
      WHERE conrelid = 'encounter.encounter'::regclass AND contype='c'
    `);
    console.log('CHECKS:'); console.log(JSON.stringify(c.rows, null, 1));
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release(); await pool.end();
  }
})();