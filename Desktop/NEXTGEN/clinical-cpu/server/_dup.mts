import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT ph.phenotype_code,
           count(*) AS n,
           count(DISTINCT (pf.feature_code, pf.operator, pf.value::text, pf.weight::text, pf.polarity, pf.requiredness)) AS distinct_n
    FROM knowledge.phenotype_feature pf
    JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
    GROUP BY ph.phenotype_code
    ORDER BY n DESC
    LIMIT 30
  `);
  console.log('phenotype feature counts (total vs distinct):');
  console.log(r.rows.map((x: any) => `${x.phenotype_code}: ${x.n} (distinct ${x.distinct_n})`).join('\n'));

  const dup = await p.query(`
    SELECT ph.phenotype_code, pf.feature_code, count(*) c
    FROM knowledge.phenotype_feature pf
    JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
    WHERE ph.phenotype_code = 'PHEN-RESPIRATORY-FAILURE'
    GROUP BY ph.phenotype_code, pf.feature_code, pf.operator, pf.value::text, pf.weight::text, pf.polarity, pf.requiredness
    HAVING count(*) > 1
    ORDER BY c DESC
  `);
  console.log('\nduplicate groups in PHEN-RESPIRATORY-FAILURE:');
  console.log(dup.rows.map((x: any) => `${x.feature_code} x${x.c}`).join('\n'));

  const uniq = await p.query(`
    SELECT conname, conrelid::regclass, pg_get_constraintdef(oid) AS def
    FROM pg_constraint
    WHERE conrelid = 'knowledge.phenotype_feature'::regclass
  `);
  console.log('\nphenotype_feature constraints:');
  console.log(uniq.rows.map((x: any) => `${x.conname}: ${x.def}`).join('\n'));

  const hypox = await p.query(`SELECT id, phenotype_code, canonical_name, status FROM knowledge.phenotype WHERE phenotype_code ILIKE '%HYPOX%'`);
  console.log('\nPHEN-HYPOXAEMIA row(s):');
  console.log(hypox.rows.map((x: any) => `${x.id} | ${x.phenotype_code} | ${x.canonical_name} | ${x.status}`).join('\n'));

  const feats = await p.query(`
    SELECT pf.id, pf.feature_code, pf.operator, pf.value, pf.weight, pf.polarity
    FROM knowledge.phenotype_feature pf
    JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
    WHERE ph.phenotype_code ILIKE '%HYPOX%'
  `);
  console.log(`\nPHEN-HYPOXAEMIA features: ${feats.rows.length}`);
} finally { await p.end(); }