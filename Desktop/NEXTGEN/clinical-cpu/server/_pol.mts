import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT pg_get_constraintdef(oid) AS def
    FROM pg_constraint
    WHERE conname = 'fact_mapping_polarity_check'
  `);
  console.log('constraint:', r.rows[0]?.def);
  const r2 = await p.query(`
    SELECT ao.answer_code, fm.value, fm.polarity
    FROM knowledge.answer_option ao
    JOIN knowledge.fact_mapping fm ON fm.answer_option_id = ao.id
    JOIN knowledge.question q ON q.id = ao.question_id
    WHERE q.question_code IN ('CHEST_PAIN_PRESENT')
    ORDER BY ao.answer_code
  `);
  console.log('\nCHEST_PAIN_PRESENT mappings:');
  console.log(r2.rows.map(x => `${x.answer_code} -> ${x.value} pol ${x.polarity}`).join('\n'));
  const r3 = await p.query(`
    SELECT ao.answer_code, ao.id, fm.fact_definition_code, fm.value, fm.polarity
    FROM knowledge.answer_option ao
    LEFT JOIN knowledge.fact_mapping fm ON fm.answer_option_id = ao.id
    JOIN knowledge.question q ON q.id = ao.question_id
    WHERE q.question_code = 'PLEURITIC_CHEST_PAIN'
    ORDER BY ao.answer_code
  `);
  console.log('\nPLEURITIC_CHEST_PAIN (after partial apply):');
  console.log(r3.rows.map(x => `${x.answer_code} (${x.id}) -> ${x.fact_definition_code} ${x.value} pol ${x.polarity}`).join('\n'));
} finally { await p.end(); }