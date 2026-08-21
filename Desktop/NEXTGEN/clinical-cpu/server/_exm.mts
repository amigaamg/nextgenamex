import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT domain_code, label, status FROM knowledge.examination_domain ORDER BY domain_code`);
  console.log('examination_domain rows:');
  console.log(r.rows.map((x: any) => `${x.domain_code} | ${x.label} | ${x.status}`).join('\n'));
  const r2 = await p.query(`
    SELECT ec.domain_code, count(*) n FROM knowledge.examination_concept ec
    WHERE ec.status='active' GROUP BY ec.domain_code ORDER BY ec.domain_code
  `);
  console.log('\nconcepts per domain:');
  console.log(r2.rows.map((x: any) => `${x.domain_code}: ${x.n}`).join('\n'));
  const r3 = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='examination_domain' ORDER BY ordinal_position`);
  console.log('\nexamination_domain cols:', r3.rows.map((x: any) => x.column_name).join(', '));
  const r4 = await p.query(`SELECT concept_id, module_code, canonical_name, body_system_code, examination_domain, status FROM knowledge.examination_module WHERE module_code='EXAM-RESPIRATORY'`);
  console.log('\nEXAM-RESPIRATORY module:', JSON.stringify(r4.rows));
} finally { await p.end(); }