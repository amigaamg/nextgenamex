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
    // Get ALL columns from all tables in relevant schemas
    const r = await client.query(`
      SELECT
        table_schema,
        table_name,
        column_name,
        data_type,
        is_nullable,
        column_default
      FROM information_schema.columns
      WHERE table_schema IN ('knowledge', 'clinical', 'patient', 'encounter', 'identity', 'governance', 'organization')
      ORDER BY table_schema, table_name, ordinal_position
    `);
    
    // Group by table
    const schema = {};
    for (const row of r.rows) {
      const key = `${row.table_schema}.${row.table_name}`;
      if (!schema[key]) schema[key] = [];
      schema[key].push({
        column: row.column_name,
        type: row.data_type,
        nullable: row.is_nullable === 'YES',
        default: row.column_default
      });
    }
    
    console.log('=== AMEXAN DB SCHEMA INVENTORY ===\n');
    for (const [table, cols] of Object.entries(schema)) {
      console.log(`${table}:`);
      for (const c of cols) {
        console.log(`  ${c.column}: ${c.type} (nullable=${c.nullable}${c.default ? ', default=' + c.default : ''})`);
      }
      console.log();
    }
    
    // Save to file for comparison
    fs.writeFileSync('test/db-schema.json', JSON.stringify(schema, null, 2));
    console.log('Schema saved to test/db-schema.json');
    
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();