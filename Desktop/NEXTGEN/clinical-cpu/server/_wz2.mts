import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT q.question_code, q.response_type,
           COALESCE(string_agg(ao.answer_code, ',' ORDER BY ao.sort_order), '') AS options
    FROM knowledge.question q
    LEFT JOIN knowledge.answer_option ao ON ao.question_id = q.id AND ao.is_active
    WHERE q.question_code ILIKE '%WHEEZE%' OR q.question_code ILIKE '%TB%'
       OR q.question_code ILIKE '%WEIGHT%' OR q.question_code ILIKE '%SWEAT%'
    GROUP BY q.question_code, q.response_type
    ORDER BY q.question_code
  `);
  console.log(r.rows.map(x => `${x.question_code} [${x.response_type}] options:${x.options || '(none)'}`).join('\n') || '(none)');
} finally { await p.end(); }