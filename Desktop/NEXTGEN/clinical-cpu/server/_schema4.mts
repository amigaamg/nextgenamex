import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  for (const t of ['question', 'question_trigger', 'question_requirement', 'question_context_exclusion', 'question_objective', 'answer_option']) {
    const r = await pool.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='knowledge' AND table_name=$1 ORDER BY ordinal_position`, [t]);
    console.log(`\n=== knowledge.${t} (${r.rowCount}) ===`);
    console.log(r.rows.map(c => `  ${c.column_name} ${c.data_type}`).join('\n'));
  }
} finally { await pool.end(); }