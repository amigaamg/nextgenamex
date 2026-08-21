import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT count(*)::text AS c FROM knowledge.question`);
  console.log('questions:', r.rows[0].c);
  const r2 = await p.query(`SELECT question_code FROM knowledge.question WHERE question_code ILIKE '%PAIN%' OR question_code ILIKE '%CHEST%' OR text ILIKE '%chest%' ORDER BY question_code LIMIT 80`);
  console.log('--- chest/pain questions ---');
  console.log(r2.rows.map((x: any) => x.question_code).join('\n') || '(none)');
} finally { await p.end(); }