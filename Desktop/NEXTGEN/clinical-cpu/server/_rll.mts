import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT DISTINCT pf.feature_code
    FROM knowledge.phenotype_feature pf
    WHERE pf.feature_code ILIKE '%RLL%' OR pf.feature_code ILIKE '%RESP_RATE%'
       OR pf.feature_code ILIKE '%RESPIRATORY_RATE%' OR pf.feature_code ILIKE '%BRONCHIAL%'
       OR pf.feature_code ILIKE '%DULLNESS%'
  `);
  console.log('--- phenotype feature codes ---');
  console.log(r.rows.map((x: any) => x.feature_code).join(', ') || '(none)');
  const r2 = await p.query(`
    SELECT column_name FROM information_schema.columns
    WHERE table_schema='knowledge' AND table_name='severity_score_rule'
    ORDER BY ordinal_position
  `);
  console.log('\n--- severity_score_rule cols ---');
  console.log(r2.rows.map((x: any) => x.column_name).join(', ') || '(none)');
  const r3 = await p.query(`
    SELECT table_name FROM information_schema.tables
    WHERE table_schema='knowledge' AND table_name ILIKE '%severity%'
  `);
  console.log('\n--- severity tables ---');
  console.log(r3.rows.map((x: any) => x.table_name).join(', ') || '(none)');
} finally { await p.end(); }