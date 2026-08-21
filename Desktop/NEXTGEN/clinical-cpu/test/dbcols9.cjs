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
    // Check if table exists
    const tables = ['knowledge.condition_question', 'knowledge.question', 'knowledge.condition'];
    for (const t of tables) {
      console.log(`\n=== ${t} ===`);
      try {
        const r = await client.query(
          `SELECT column_name, data_type, is_nullable, column_default
           FROM information_schema.columns
           WHERE table_schema = split_part($1, '.', 1)
             AND table_name = split_part($1, '.', 2)
           ORDER BY ordinal_position`,
          [t],
        );
        if (r.rows.length === 0) {
          console.log('  TABLE DOES NOT EXIST');
        } else {
          console.log(r.rows.map(x => `  ${x.column_name}: ${x.data_type} (nullable=${x.is_nullable}, default=${x.column_default ?? 'NULL'})`).join('\n'));
        }
      } catch (e) {
        console.log(`  ERROR: ${e.message}`);
      }
    }
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();