import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT ec.code, ec.domain_code, ec.fact_definition_code, ec.name, ec.short_label,
           ec.body_system_code, ec.is_mandatory, ec.base_priority, ec.status,
           ec.technique_codes, ec.capture_method_codes, ec.applies_to_context_codes
    FROM knowledge.examination_concept ec
    WHERE ec.code = 'EXAM-CON-ADDED-SOUNDS'
  `);
  console.log('sample concept:', JSON.stringify(r.rows[0], null, 2));
  const r2 = await p.query(`SELECT code FROM knowledge.body_system ORDER BY code`);
  console.log('body_systems:', r2.rows.map((x: any) => x.code).join(', '));
} finally { await p.end(); }