import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT phenotype_code, count(*) n, count(DISTINCT id) ids, count(DISTINCT concept_id) concepts
    FROM knowledge.phenotype
    GROUP BY phenotype_code
    HAVING count(*) > 1
    ORDER BY n DESC LIMIT 15
  `);
  console.log('duplicate phenotype rows:');
  console.log(r.rows.map((x: any) => `${x.phenotype_code}: ${x.n} rows (${x.ids} ids, ${x.concepts} concepts)`).join('\n'));

  const ch = await p.query(`
    SELECT q.id, q.question_code, q.question_text, q.answer_option_mode
    FROM knowledge.question q
    WHERE q.question_code IN ('CHEST_PAIN_PLEURITIC','PLEURITIC_CHEST_PAIN')
  `);
  console.log('\npleuritic questions:');
  for (const x of ch.rows) console.log(`${x.question_code} | ${x.question_text}`);
  const fm = await p.query(`
    SELECT q.question_code, fm.fact_definition_code, fm.value, fm.polarity
    FROM knowledge.fact_mapping fm
    JOIN knowledge.answer_option ao ON ao.id = fm.answer_option_id
    JOIN knowledge.question q ON q.id = ao.question_id
    WHERE q.question_code IN ('CHEST_PAIN_PLEURITIC','PLEURITIC_CHEST_PAIN')
  `);
  console.log('\npleuritic fact mappings:');
  for (const x of fm.rows) console.log(`${x.question_code} -> ${x.fact_definition_code} value=${x.value} pol=${x.polarity}`);
} finally { await p.end(); }