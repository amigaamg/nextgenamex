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
      WHERE conname = 'audit_event_event_type_check'
    `);
    console.log('=== audit_event_event_type_check ===');
    console.log(r.rows);
    
    // Also check what columns audit_event has
    const cols = await client.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'governance' AND table_name = 'audit_event'
      ORDER BY ordinal_position
    `);
    console.log('\n=== governance.audit_event columns ===');
    console.log(cols.rows.map(x => `  ${x.column_name}: ${x.data_type} (nullable=${x.is_nullable}, default=${x.column_default ?? 'NULL'})`).join('\n'));
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();