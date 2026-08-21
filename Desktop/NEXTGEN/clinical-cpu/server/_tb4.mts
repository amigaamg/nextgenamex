import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };
  console.log('== conditions (TB/Pneumonia/Bronchitis/COPD/HF) ==');
  console.log((await q('', `SELECT condition_code, canonical_name, status FROM knowledge.condition WHERE canonical_name ILIKE '%tuberc%' OR canonical_name ILIKE '%pneumonia%' OR canonical_name ILIKE '%bronchitis%' OR canonical_name ILIKE '%heart failure%' OR canonical_name ILIKE '%copd%' ORDER BY canonical_name`)).map((x: any) => `${x.condition_code} | ${x.canonical_name} | ${x.status}`).join('\n'));

  console.log('\n== phenotype_differential for hypoxaemia/TB-related phenotypes ==');
  console.log((await q('', `SELECT ph.phenotype_code, c.condition_code, c.canonical_name, pd.weight FROM knowledge.phenotype_differential pd JOIN knowledge.phenotype ph ON ph.id=pd.phenotype_id JOIN knowledge.condition c ON c.id=pd.condition_id WHERE c.canonical_name ILIKE '%tuberc%' ORDER BY c.canonical_name, pd.weight DESC`)).map((x: any) => `${x.phenotype_code} -> ${x.canonical_name} (${x.condition_code}) w${x.weight}`).join('\n'));

  console.log('\n== TB_CONTACT fact rules/evidence anywhere ==');
  console.log((await q('', `SELECT table_name FROM information_schema.tables WHERE table_schema='knowledge' AND table_name ILIKE '%evidence%' ORDER BY table_name`)).map((x: any) => x.table_name).join(', '));
  const er = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='differential_evidence_rule' ORDER BY ordinal_position`);
  const cols = er.rows.map((x: any) => x.column_name);
  console.log('\ndifferential_evidence_rule cols:', cols.join(', '));
} finally { await p.end(); }