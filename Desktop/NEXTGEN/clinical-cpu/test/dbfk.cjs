const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const client = await pool.connect();
  try {
    const fk = await client.query(`
      SELECT tc.table_name, kcu.column_name, ccu.table_schema||'.'||ccu.table_name AS ref
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
      JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
      WHERE tc.constraint_type='FOREIGN KEY' AND tc.table_schema='document'
      ORDER BY tc.table_name
    `);
    console.log('DOCUMENT FKs:', JSON.stringify(fk.rows, null, 1));
    const s = await client.query(`
      SELECT DISTINCT context_value AS section FROM clinical.fact_context WHERE context_key='section' ORDER BY section
    `);
    console.log('SECTIONS:', JSON.stringify(s.rows));
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release(); await pool.end();
  }
})();