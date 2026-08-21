import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='clinical' AND table_name='fact_definition' ORDER BY ordinal_position`);
  console.log('fact_definition cols:', r.rows.map((x: any) => x.column_name).join(', '));
  const r2 = await p.query(`SELECT * FROM clinical.fact_definition LIMIT 3`);
  console.log('sample:', JSON.stringify(r2.rows[0]));
  const r3 = await p.query(`SELECT code, data_type FROM clinical.fact_definition WHERE code ILIKE '%WHEEZE%' OR code ILIKE '%WEIGHT_LOSS%' OR code ILIKE '%NIGHT_SWEATS%' OR code ILIKE '%TB_CONTACT%'`);
  console.log('target facts:');
  console.log(r3.rows.map((x: any) => `${x.code} | ${x.data_type}`).join('\n'));
  const r4 = await p.query(`SELECT code, data_type FROM clinical.fact_definition WHERE code IN ('WEIGHT_LOSS','NIGHT_SWEATS','TB_CONTACT','WHEEZE_PRESENT','COUGH_WEIGHT_LOSS','COUGH_NIGHT_SWEATS')`);
  console.log('exact facts:');
  console.log(r4.rows.map((x: any) => `${x.code} | ${x.data_type}`).join('\n'));
} finally { await p.end(); }