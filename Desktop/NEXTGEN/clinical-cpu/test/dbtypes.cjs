const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const client = await pool.connect();
  try {
    for (const t of ['clinical.fact_definitions', 'clinical.fact_definition']) {
      const r = await client.query(`
        SELECT data_type, count(*) AS n FROM ${t} GROUP BY data_type ORDER BY data_type
      `);
      console.log(t, JSON.stringify(r.rows));
      const c = await client.query(`SELECT count(*) AS n FROM ${t}`);
      console.log('  total:', c.rows[0].n);
    }
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release(); await pool.end();
  }
})();