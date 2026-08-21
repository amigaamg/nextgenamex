import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };
  console.log('PHEN-HYPOXAEMIA:', JSON.stringify(await q('', `SELECT id, phenotype_code, status FROM knowledge.phenotype WHERE phenotype_code='PHEN-HYPOXAEMIA'`)));
  console.log('PHEN-TUBERCULOSIS:', JSON.stringify(await q('', `SELECT id, phenotype_code, status FROM knowledge.phenotype WHERE phenotype_code='PHEN-TUBERCULOSIS'`)));
  console.log('features for a101/a102:', JSON.stringify(await q('', `SELECT id, feature_code FROM knowledge.phenotype_feature WHERE phenotype_id IN ('f0f00000-0000-0000-0000-00000000a101','f0f00000-0000-0000-0000-00000000a102')`)));
  console.log('existing a2xx/a3xx ids used?', JSON.stringify(await q('', `SELECT id FROM knowledge.phenotype_feature WHERE id::text LIKE 'f0f00000-0000-0000-0000-00000000a2%'`)));
  console.log('existing 101/102 old:', JSON.stringify(await q('', `SELECT id, phenotype_code FROM knowledge.phenotype WHERE id IN ('f0f00000-0000-0000-0000-000000000101','f0f00000-0000-0000-0000-000000000102')`)));
  console.log('value column type:', JSON.stringify((await q('', `SELECT data_type FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='phenotype_feature' AND column_name='value'`))[0]));
} finally { await p.end(); }