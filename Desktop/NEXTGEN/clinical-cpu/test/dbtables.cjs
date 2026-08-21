const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const client = await pool.connect();
  try {
    const r = await client.query(`
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_schema IN ('document','clinical','encounter','patient','identity')
      ORDER BY table_schema, table_name
    `);
    console.log(JSON.stringify(r.rows, null, 1));
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release(); await pool.end();
  }
})();