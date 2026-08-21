import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT code, data_type FROM clinical.fact_definition WHERE code IN ('PLEURITIC_CHEST_PAIN','CHEST_PAIN_PRESENT')`);
  console.log('--- clinical.fact_definition ---');
  console.log(r.rows.map(x => `${x.code} | ${x.data_type} | ${x.canonical_name}`).join('\n') || '(none)');
  const r2 = await p.query(`SELECT fact_code, data_type FROM clinical.fact_definitions WHERE fact_code IN ('PLEURITIC_CHEST_PAIN','CHEST_PAIN_PRESENT')`);
  console.log('\n--- clinical.fact_definitions ---');
  console.log(r2.rows.map((x: any) => `${x.fact_code} | ${x.data_type}`).join('\n') || '(none)');
  const r3 = await p.query(`SELECT id, question_code FROM knowledge.question WHERE question_code = 'PLEURITIC_CHEST_PAIN'`);
  console.log('\n--- question row ---');
  console.log(JSON.stringify(r3.rows[0]));
  const r4 = await p.query(`
    SELECT ao.answer_code, fm.fact_definition_code, fm.value
    FROM knowledge.answer_option ao
    JOIN knowledge.fact_mapping fm ON fm.answer_option_id = ao.id
    JOIN knowledge.question q ON q.id = ao.question_id
    WHERE q.question_code = 'CHEST_PAIN_PRESENT'
  `);
  console.log('\n--- CHEST_PAIN_PRESENT options+mappings ---');
  console.log(r4.rows.map(x => `${x.answer_code} -> ${x.fact_definition_code} = ${JSON.stringify(x.value)}`).join('\n'));
  const r5 = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='fact_mapping' ORDER BY ordinal_position`);
  console.log('\n--- knowledge.fact_mapping columns ---');
  console.log(r5.rows.map((x: any) => x.column_name).join(', '));
} finally { await p.end(); }