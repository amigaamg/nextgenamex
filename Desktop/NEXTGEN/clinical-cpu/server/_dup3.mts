import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT pf.id, pf.phenotype_id, ph.phenotype_code, pf.feature_code, pf.operator, pf.value, pf.weight
    FROM knowledge.phenotype_feature pf
    JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
    WHERE ph.phenotype_code = 'PHEN-RESPIRATORY-FAILURE'
    ORDER BY pf.feature_code, pf.value, pf.weight
  `);
  console.log('PHEN-RESPIRATORY-FAILURE raw features:');
  for (const x of r.rows) console.log(`${x.feature_code} | ${x.operator} ${x.value} | w${x.weight} | phenotype_id=${x.phenotype_id}`);

  const ph = await p.query(`SELECT id, phenotype_code, concept_id FROM knowledge.phenotype WHERE phenotype_code='PHEN-RESPIRATORY-FAILURE'`);
  console.log('\nphenotype rows:', ph.rows.map((x: any) => `${x.id} (concept ${x.concept_id})`).join('; '));

  const q = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='question' ORDER BY ordinal_position`);
  console.log('\nquestion cols:', q.rows.map((x: any) => x.column_name).join(', '));
} finally { await p.end(); }