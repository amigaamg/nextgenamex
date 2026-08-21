const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const c = await pool.connect();
  try {
    const r = await c.query(`
      SELECT DISTINCT f.fact_definition_code,
        COALESCE((SELECT fc.context_value FROM clinical.fact_context fc
          WHERE fc.fact_id = f.id AND fc.context_key='section' LIMIT 1), '?') AS section,
        fv.data_type AS dtype, fv.value_text AS textval
      FROM clinical.fact f
      LEFT JOIN clinical.fact_value fv ON fv.fact_id = f.id
      LIMIT 60
    `);
    console.log(JSON.stringify(r.rows, null, 1));
  } catch (e) {
    console.error(e.stack);
  } finally {
    c.release(); await pool.end();
  }
})();