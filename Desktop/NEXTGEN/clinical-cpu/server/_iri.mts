import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT r.id, r.result_code, r.result_label, r.fact_definition_code, r.interpretation_type,
           r.interpretation, r.status
    FROM knowledge.investigation_result r
    ORDER BY r.result_code
  `);
  console.log('investigation_result rows:', r.rows.length);
  for (const x of r.rows) console.log(`${x.result_code} | fact ${x.fact_definition_code} | itype ${x.interpretation_type} | interp ${x.interpretation} | ${x.status}`);
  const r2 = await p.query(`
    SELECT table_name FROM information_schema.tables WHERE table_schema='knowledge' AND table_name LIKE '%interpret%'
  `);
  console.log('interpret tables:', r2.rows.map((x: any) => x.table_name).join(', ') || '(none)');
} finally { await p.end(); }