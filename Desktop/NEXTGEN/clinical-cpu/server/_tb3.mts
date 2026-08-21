import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };

  console.log('== evidence rules for TB (DA004) ==');
  console.log((await q('', `SELECT der.evidence_rule_code, der.diagnosis_code, der.fact_definition_code, der.phenotype_code, der.mechanism_code, der.relationship, der.required_fact_state, der.base_strength, der.operator, der.value, der.status FROM knowledge.differential_evidence_rule der WHERE der.diagnosis_code='DA004' ORDER BY der.evidence_rule_code`)).map((x: any) => `${x.evidence_rule_code} | ${x.fact_definition_code ?? x.phenotype_code ?? x.mechanism_code} | ${x.relationship} | ${x.required_fact_state} | ${x.base_strength} | ${x.operator} ${x.value} | ${x.status}`).join('\n'));

  console.log('\n== evidence rules for Pneumonia (DA001) count ==');
  const r = await q('', `SELECT count(*) n FROM knowledge.differential_evidence_rule WHERE diagnosis_code='DA001' AND status='active'`);
  console.log(r[0]?.n);

  console.log('\n== how does DifferentialEngine produce evidence? grep later. Check differential_evidence_ledger sample ==');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='differential_expected_feature' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));
  console.log('\n== differential_expected_feature for DA004 ==');
  const ef = await q('', `SELECT * FROM knowledge.differential_expected_feature WHERE diagnosis_code='DA004' LIMIT 20`);
  console.log(ef.map((x: any) => JSON.stringify(x)).join('\n') || '(none)');
} finally { await p.end(); }