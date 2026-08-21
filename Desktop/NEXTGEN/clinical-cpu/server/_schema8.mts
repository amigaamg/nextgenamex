import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  const r = await pool.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='section_context_rule' ORDER BY ordinal_position`);
  console.log(`knowledge.section_context_rule (${r.rowCount})`);
  console.log(r.rows.map(c => `  ${c.column_name} ${c.data_type}`).join('\n'));
} finally { await pool.end(); }