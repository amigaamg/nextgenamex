import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT q.question_code, q.text, q.response_type,
           qf.fact_definition_code, qf.unit_code
    FROM knowledge.question q
    LEFT JOIN knowledge.question_fact qf ON qf.question_id = q.id
    WHERE q.question_code IN ('PLEURITIC_CHEST_PAIN','CHEST_PAIN_PRESENT','CHEST_PAIN_CHARACTER')
  `);
  console.log(r.rows.map(x => `${x.question_code} | resp ${x.response_type} | fact ${x.fact_definition_code} | ${x.text}`).join('\n'));
  const ao = await p.query(`
    SELECT q.question_code, ao.answer_code, ao.label
    FROM knowledge.answer_option ao
    JOIN knowledge.question q ON q.id = ao.question_id
    WHERE q.question_code IN ('PLEURITIC_CHEST_PAIN')
  `);
  console.log('\n--- answer options PLEURITIC_CHEST_PAIN ---');
  console.log(ao.rows.map(x => `${x.answer_code} | ${x.label}`).join('\n') || '(none)');
} finally { await p.end(); }