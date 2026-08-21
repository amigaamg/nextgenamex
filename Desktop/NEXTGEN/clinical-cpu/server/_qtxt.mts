import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT q.question_code, q.text, q.response_type
    FROM knowledge.question q
    WHERE q.question_code IN ('WHEEZE_PRESENT','TB_CONTACT','WEIGHT_LOSS','NIGHT_SWEATS')
  `);
  console.log(r.rows.map(x => `${x.question_code} [${x.response_type}] ${x.text}`).join('\n'));
} finally { await p.end(); }