const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost', port: 5432, database: 'amexan',
  user: 'postgres', password: 'postgres!', max: 1,
});

(async () => {
  const client = await pool.connect();
  try {
    const r = await client.query(`
      SELECT conname, pg_get_constraintdef(oid) AS definition
      FROM pg_constraint
      WHERE conname = 'chk_fact_value_type'
    `);
    console.log(JSON.stringify(r.rows, null, 2));
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release();
    await pool.end();
  }
})();