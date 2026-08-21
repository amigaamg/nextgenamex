import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  for (const t of ['investigation_result', 'investigation_result_fact']) {
    const r = await pool.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='knowledge' AND table_name=$1 ORDER BY ordinal_position`, [t]);
    console.log(`\n=== knowledge.${t} (${r.rowCount}) ===`);
    console.log(r.rows.map(c => `  ${c.column_name} ${c.data_type}`).join('\n'));
  }
  const cnt = await pool.query(`SELECT count(*)::text AS c FROM knowledge.investigation_result_fact`);
  console.log('\ninvestigation_result_fact rows:', cnt.rows[0].c);
} finally { await pool.end(); }