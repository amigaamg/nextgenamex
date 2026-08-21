const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const c = await pool.connect();
  try {
    const r = await c.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns WHERE table_schema='document' AND table_name='document_type' ORDER BY ordinal_position
    `);
    console.log(JSON.stringify(r.rows, null, 1));
  } catch (e) { console.error(e.stack); } finally { c.release(); await pool.end(); }
})();