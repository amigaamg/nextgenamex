import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT q.question_code, qt.trigger_type, qt.trigger_code, qt.priority, q.is_active
    FROM knowledge.question_trigger qt
    JOIN knowledge.question q ON q.id = qt.question_id
    WHERE q.question_code IN ('CHEST_PAIN_PRESENT','CHEST_PAIN_CHARACTER','PLEURITIC_CHEST_PAIN','CHEST_PAIN_PLEURITIC')
      OR qt.trigger_code IN ('CHEST_PAIN_PRESENT','CHEST_PAIN_CHARACTER','PLEURITIC_CHEST_PAIN','chest pain','chest_pain')
    ORDER BY q.question_code, qt.priority
  `);
  console.log('--- question_trigger ---');
  console.log(r.rows.map(x => `${x.question_code} | ${x.trigger_type} ${x.trigger_code} | pri ${x.priority} | active ${x.is_active}`).join('\n') || '(none)');
  const r2 = await p.query(`
    SELECT q.question_code, qr.requirement_level, qr.condition, qr.priority
    FROM knowledge.question_requirement qr
    JOIN knowledge.question q ON q.id = qr.question_id
    WHERE q.question_code IN ('CHEST_PAIN_PRESENT','CHEST_PAIN_CHARACTER','PLEURITIC_CHEST_PAIN')
  `);
  console.log('\n--- question_requirement ---');
  console.log(r2.rows.map(x => `${x.question_code} | ${x.requirement_level} | ${JSON.stringify(x.condition)}`).join('\n') || '(none)');
} finally { await p.end(); }