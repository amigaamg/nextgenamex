import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
const codes = ['WHEEZE_PRESENT','TB_CONTACT','WEIGHT_LOSS','NIGHT_SWEATS','SPUTUM_COLOUR','COUGH_ONSET','DYSPNOEA_PRESENT','FEVER_PRESENT'];
try {
  const r = await p.query(`
    SELECT q.question_code, q.response_type,
           COALESCE(string_agg(ao.answer_code, ',' ORDER BY ao.sort_order), '') AS options,
           COALESCE(string_agg(DISTINCT qf.fact_definition_code, ','), '') AS qf_facts
    FROM knowledge.question q
    LEFT JOIN knowledge.answer_option ao ON ao.question_id = q.id AND ao.is_active
    LEFT JOIN knowledge.question_fact qf ON qf.question_id = q.id
    WHERE q.question_code = ANY($1::text[])
    GROUP BY q.question_code, q.response_type
    ORDER BY q.question_code
  `, [codes]);
  console.log(r.rows.map(x => `${x.question_code} [${x.response_type}] options:${x.options || '(none)'} qf:${x.qf_facts || '(none)'}`).join('\n'));
} finally { await p.end(); }