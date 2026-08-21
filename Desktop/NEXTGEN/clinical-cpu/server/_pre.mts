import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };
  const c = await p.query(`SELECT pg_get_constraintdef(oid) def, conname FROM pg_constraint WHERE conrelid='knowledge.phenotype'::regclass`);
  console.log('phenotype constraints:'); console.log(c.rows.map((x: any) => `${x.conname}: ${x.def}`).join('\n'));
  console.log('phenotype_class values:');
  console.log((await q('', `SELECT DISTINCT phenotype_class FROM knowledge.phenotype LIMIT 20`)).map((x: any) => x.phenotype_class).join(', '));
  console.log('\nCHEST_PAIN_PLEURITIC refs (phenotype_feature):');
  console.log((await q('', `SELECT ph.phenotype_code, count(*) n FROM knowledge.phenotype_feature pf JOIN knowledge.phenotype ph ON ph.id=pf.phenotype_id WHERE pf.feature_code='CHEST_PAIN_PLEURITIC' GROUP BY ph.phenotype_code`)).map((x: any) => `${x.phenotype_code} x${x.n}`).join('\n') || '(none)');
  console.log('\nquestion CHEST_PAIN_PLEURITIC?');
  console.log((await q('', `SELECT question_code, is_active FROM knowledge.question WHERE question_code ILIKE '%CHEST_PAIN_PLEURITIC%'`)).map((x: any) => `${x.question_code} active=${x.is_active}`).join('\n') || '(none)');
  console.log('\nfact_definition CHEST_PAIN_PLEURITIC?');
  console.log((await q('', `SELECT fact_code FROM clinical.fact_definition WHERE fact_code ILIKE '%CHEST_PAIN%'`)).map((x: any) => x.fact_code).join(', ') || '(none)');
  console.log('\nTUBERCULOSIS condition id:');
  console.log((await q('', `SELECT id, condition_code, canonical_name FROM knowledge.condition WHERE condition_code='TUBERCULOSIS'`)).map((x: any) => `${x.id} | ${x.canonical_name}`).join('\n'));
  console.log('\nphenotype_differential columns:');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='phenotype_differential' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));
} finally { await p.end(); }