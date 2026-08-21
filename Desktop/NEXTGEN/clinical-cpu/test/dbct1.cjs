const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });
(async () => {
  const c = await pool.connect();
  try {
    const r = await c.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns WHERE table_schema='cpu' AND table_name='event_log' ORDER BY ordinal_position
    `);
    console.log('EVENT_LOG:', JSON.stringify(r.rows, null, 1));
    const p = await c.query(`
      SELECT conname, pg_get_constraintdef(oid) AS def FROM pg_constraint
      WHERE conrelid = 'cpu.event_log'::regclass AND contype='c'
    `);
    console.log('CHECKS:', JSON.stringify(p.rows, null, 1));
  } catch (e) { console.error(e.stack); } finally { c.release(); await pool.end(); }
})();