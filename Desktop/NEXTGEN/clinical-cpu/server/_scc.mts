import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='severity_score_component' ORDER BY ordinal_position`);
  console.log('severity_score_component cols:');
  console.log(r.rows.map((c: any) => `${c.column_name} ${c.data_type}`).join('\n'));
} finally { await p.end(); }