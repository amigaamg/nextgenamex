import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT q.question_code,
           ao.answer_code,
           fm.fact_definition_code,
           fm.value
    FROM knowledge.question q
    LEFT JOIN knowledge.answer_option ao ON ao.question_id = q.id AND ao.is_active
    LEFT JOIN knowledge.fact_mapping fm ON fm.answer_option_id = ao.id
    WHERE q.question_code IN ('COUGH_TB_CONTACT','COUGH_WEIGHT_LOSS','COUGH_NIGHT_SWEATS','CHEST_PAIN_WHEEZE')
    ORDER BY q.question_code, ao.sort_order
  `);
  console.log(r.rows.map(x => `${x.question_code} | ${x.answer_code} -> ${x.fact_definition_code} = ${x.value}`).join('\n'));
  const r2 = await p.query(`
    SELECT q.question_code, q.text, q.response_type
    FROM knowledge.question q
    WHERE q.text ILIKE '%wheeze%' OR q.question_code ILIKE '%WHEEZE%'
  `);
  console.log('\n--- wheeze questions ---');
  console.log(r2.rows.map(x => `${x.question_code} [${x.response_type}] ${x.text}`).join('\n'));
  const r3 = await p.query(`
    SELECT DISTINCT code
    FROM clinical.fact_definition
    WHERE code ILIKE '%WHEEZE%' OR code ILIKE '%TB%' OR code ILIKE '%WEIGHT%' OR code ILIKE '%SWEAT%'
  `);
  console.log('\n--- fact definitions (wheeze/tb/weight/sweat) ---');
  console.log(r3.rows.map((x: any) => x.fact_definition_code).join(', '));
} finally { await p.end(); }