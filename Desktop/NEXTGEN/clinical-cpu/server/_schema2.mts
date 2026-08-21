import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  const tables = [
    'mechanism_contradiction','mechanism_dependency','mechanism_feature','mechanism_phenotype',
    'investigation_dependency','investigation_context_rule','protocol_investigation','investigation_result_fact',
  ];
  for (const t of tables) {
    const r = await pool.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='knowledge' AND table_name=$1 ORDER BY ordinal_position`, [t]);
    console.log(`\n=== knowledge.${t} (${r.rowCount} cols) ===`);
    console.log(r.rows.map(c => `  ${c.column_name} ${c.data_type}`).join('\n'));
  }
} finally { await pool.end(); }