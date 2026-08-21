import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT code, data_type FROM clinical.fact_definition
    WHERE code ILIKE '%BREATH_SOUND%' OR code ILIKE '%DULL%' OR code ILIKE '%CONSOLIDATION%'
       OR code ILIKE '%PERCUSSION%' OR code ILIKE '%AUSCULT%'
    ORDER BY code
  `);
  console.log('--- respiratory sign facts ---');
  console.log(r.rows.map((x: any) => `${x.code} | ${x.data_type}`).join('\n') || '(none)');
} finally { await p.end(); }