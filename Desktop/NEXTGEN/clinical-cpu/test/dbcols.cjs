const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

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
    const tables = ['clinical.fact_source', 'clinical.fact_value', 'clinical.fact', 'clinical.fact_context'];
    for (const t of tables) {
      console.log(`\n=== information_schema.columns for ${t} ===`);
      const r = await client.query(
        `SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema = split_part($1, '.', 1)
           AND table_name = split_part($1, '.', 2)
         ORDER BY ordinal_position`,
        [t],
      );
      console.log(r.rows.map(x => `  ${x.column_name}: ${x.data_type} (nullable=${x.is_nullable}, default=${x.column_default ?? 'NULL'})`).join('\n'));
    }

    console.log('\n=== constraint: fact_source_source_type_check ===');
    let r = await client.query(
      `SELECT conname, pg_get_constraintdef(oid) AS definition
         FROM pg_constraint
        WHERE conname = 'fact_source_source_type_check'`,
    );
    console.log(r.rows);

    console.log('\n=== all check constraints on clinical.fact_source ===');
    r = await client.query(
      `SELECT conname, pg_get_constraintdef(oid) AS definition
         FROM pg_constraint
        WHERE conrelid = 'clinical.fact_source'::regclass`,
    );
    console.log(r.rows);
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();
