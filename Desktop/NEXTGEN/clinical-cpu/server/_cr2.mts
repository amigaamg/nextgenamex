import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT code FROM knowledge.examination_domain ORDER BY code`);
  console.log('domains:', r.rows.map((x: any) => x.code).join(', '));
  const r2 = await p.query(`
    SELECT ec.code, ec.fact_definition_code, ec.domain_code
    FROM knowledge.examination_concept ec
    WHERE ec.fact_definition_code IN ('BREATH_SOUND','ADDED_BREATH_SOUND','ADVENTITIOUS_BREATH_SOUND')
  `);
  console.log('\nbreath-sound concepts:');
  console.log(r2.rows.map((x: any) => `${x.code} | fact ${x.fact_definition_code} | domain ${x.domain_code}`).join('\n') || '(none)');
  const r3 = await p.query(`SELECT code, name, data_type FROM clinical.fact_definition WHERE code IN ('CRACKLES','CRACKLES_PRESENT','BREATH_SOUND','ADDED_BREATH_SOUND')`);
  console.log('\ncrackle fact defs:');
  console.log(r3.rows.map((x: any) => `${x.code} | ${x.name} | ${x.data_type}`).join('\n') || '(none)');
} finally { await p.end(); }