import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const want = ['RESP_RATE','SPO2','TEMPERATURE','RLL_DULLNESS','RLL_BRONCHIAL_BREATH_SOUNDS','CRACKLES','ALTERED_CONSCIOUSNESS','UREA','CURB65'];
  const r = await p.query(`SELECT code, data_type FROM clinical.fact_definition WHERE code = ANY($1::text[])`, [want]);
  console.log('--- exact match ---');
  console.log(r.rows.map((x: any) => `${x.code} | ${x.data_type}`).join('\n') || '(none)');
  const r2 = await p.query(`
    SELECT code, data_type FROM clinical.fact_definition
    WHERE code ILIKE '%RESP%' OR code ILIKE '%RATE%' OR code ILIKE '%SPO2%' OR code ILIKE '%SATURATION%'
       OR code ILIKE '%TEMPERATURE%' OR code ILIKE '%RLL%' OR code ILIKE '%CRACKLE%' OR code ILIKE '%UREA%'
  `);
  console.log('\n--- fuzzy match ---');
  console.log(r2.rows.map((x: any) => `${x.code} | ${x.data_type}`).join('\n') || '(none)');
  const r3 = await p.query(`SELECT count(*)::text AS c FROM clinical.fact_definition`);
  console.log('\ntotal fact_definition:', r3.rows[0].c);
} finally { await p.end(); }