import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT q.question_code, ao.answer_code, ao.label,
           fm.fact_definition_code, fm.value
    FROM knowledge.question q
    LEFT JOIN knowledge.answer_option ao ON ao.question_id = q.id
    LEFT JOIN knowledge.fact_mapping fm ON fm.answer_option_id = ao.id
    WHERE q.question_code IN ('CHEST_PAIN_PRESENT','CHEST_PAIN_CHARACTER','PLEURITIC_CHEST_PAIN')
    ORDER BY q.question_code, ao.answer_code
  `);
  console.log(r.rows.map(x => `${x.question_code} | opt ${x.answer_code} | fact ${x.fact_definition_code} => ${x.value}`).join('\n') || '(none)');
} finally { await p.end(); }