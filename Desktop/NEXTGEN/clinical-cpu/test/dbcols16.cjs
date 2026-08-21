const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'amexan',
  user: 'postgres',
  password: 'postgres!',
  max: 1,
});

(async () => {
  const client = await pool.connect();
  try {
    const r = await client.query(`
      SELECT conname, pg_get_constraintdef(oid) AS definition
      FROM pg_constraint
      WHERE conname = 'person_sex_at_birth_check'
    `);
    console.log(r.rows);
  } catch (e) {
    console.error('ERROR:', e.stack || e.message);
  } finally {
    client.release();
    await pool.end();
  }
})();