import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };

  console.log('== PROT-CAP-ADULT protocol row ==');
  console.log((await q('', `SELECT protocol_code, canonical_name, population, acuity, setting, priority, version, effective_from, effective_to, requires_confirmation, status FROM knowledge.protocol WHERE protocol_code IN ('PROT-CAP-ADULT','PROT-PNEUMONIA-KENYA-PAED')`)).map((x: any) => `${x.protocol_code} | ${x.population} | acuity=${x.acuity} | setting=${x.setting} | priority ${x.priority} | eff ${x.effective_from}->${x.effective_to} | conf=${x.requires_confirmation} | ${x.status}`).join('\n'));

  console.log('\n== diagnosis_concept TB/PNEUMONIA ==');
  console.log((await q('', `SELECT code, canonical_name, diagnosis_type, base_weight, status FROM knowledge.diagnosis_concept WHERE canonical_name ILIKE '%tuberc%' OR canonical_name ILIKE '%pneumonia%' OR canonical_name ILIKE '%bronchitis%' ORDER BY canonical_name`)).map((x: any) => `${x.code} | ${x.canonical_name} | ${x.diagnosis_type} | w${x.base_weight} | ${x.status}`).join('\n'));

  console.log('\n== differential_evidence_rule cols ==');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='differential_evidence_rule' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));
  const er = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='differential_evidence_rule' ORDER BY ordinal_position`);
  const erCols = er.rows.map((x: any) => x.column_name);

  console.log('\n== differential_evidence_rule rows (TB-related) ==');
  let tbWhere = '';
  if (erCols.includes('condition_code')) tbWhere = "condition_code ILIKE '%TB%' OR condition_code ILIKE '%TUBER%' OR ";
  const erRows = await p.query(`SELECT * FROM knowledge.differential_evidence_rule WHERE ${tbWhere} fact_code IN ('WEIGHT_LOSS','NIGHT_SWEATS','TB_CONTACT') LIMIT 40`);
  console.log(erRows.rows.map((x: any) => JSON.stringify(x)).join('\n') || '(none)');

  console.log('\n== differential_evidence_rule sample (3 rows) ==');
  console.log((await q('', `SELECT * FROM knowledge.differential_evidence_rule LIMIT 3`)).map((x: any) => JSON.stringify(x)).join('\n') || '(none)');
} finally { await p.end(); }