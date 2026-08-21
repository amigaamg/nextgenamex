import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT ec.code, ec.name, ec.fact_definition_code, ec.status
    FROM knowledge.examination_concept ec
    WHERE ec.code ILIKE '%CRACKLE%' OR ec.name ILIKE '%crackle%'
    ORDER BY ec.code
  `);
  console.log('--- examination_concept (crackle) ---');
  console.log(r.rows.map(x => `${x.code} | ${x.name} | fact ${x.fact_definition_code} | ${x.status}`).join('\n') || '(none)');
  const r2 = await p.query(`
    SELECT column_name FROM information_schema.columns
    WHERE table_schema='knowledge' AND table_name='examination_concept'
    ORDER BY ordinal_position
  `);
  console.log('\nexamination_concept cols:', r2.rows.map((x: any) => x.column_name).join(', '));
} finally { await p.end(); }