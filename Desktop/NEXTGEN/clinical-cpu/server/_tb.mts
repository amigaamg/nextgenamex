import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };

  console.log('== PROT-CAP-ADULT / PAED protocol rows ==');
  console.log((await q('', `SELECT protocol_code, canonical_name, population, acuity, setting, priority, is_primary, version, effective_from, effective_to, requires_confirmation, status FROM knowledge.protocol WHERE protocol_code IN ('PROT-CAP-ADULT','PROT-PNEUMONIA-KENYA-PAED','PROT-PNEUMONIA-PAED')`)).map((x: any) => `${x.protocol_code} | ${x.population} | priority ${x.priority} | eff ${x.effective_from}->${x.effective_to} | ${x.status}`).join('\n'));

  console.log('\n== protocol_condition links ==');
  console.log((await q('', `SELECT pc.condition_id, c.condition_code, p.protocol_code, pc.is_primary, pc.priority_weight FROM knowledge.protocol_condition pc JOIN knowledge.protocol p ON p.id=pc.protocol_id JOIN knowledge.condition c ON c.id=pc.condition_id WHERE p.protocol_code IN ('PROT-CAP-ADULT','PROT-PNEUMONIA-KENYA-PAED','PROT-PNEUMONIA-PAED')`)).map((x: any) => `${x.protocol_code} <- ${x.condition_code} primary=${x.is_primary} w=${x.priority_weight}`).join('\n'));

  console.log('\n== governance knowledge_object for protocols ==');
  console.log((await q('', `SELECT object_code, object_type, jurisdiction_code, lifecycle_status FROM governance.knowledge_object WHERE object_code IN ('PROT-CAP-ADULT','PROT-PNEUMONIA-KENYA-PAED')`)).map((x: any) => `${x.object_code} | ${x.jurisdiction_code} | ${x.lifecycle_status}`).join('\n'));

  console.log('\n== TB differential: candidates with Tuberculosis ==');
  console.log((await q('', `SELECT dc.id, dc.diagnosis_code, dc.name, dc.status FROM knowledge.differential_candidate dc WHERE dc.name ILIKE '%tuberc%' OR dc.diagnosis_code ILIKE '%TB%' OR dc.diagnosis_code ILIKE '%TUBER%'`)).map((x: any) => `${x.id} | ${x.diagnosis_code} | ${x.name} | ${x.status}`).join('\n'));

  console.log('\n== diagnosis_concept columns ==');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='diagnosis_concept' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));

  console.log('\n== differential_candidate columns ==');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='differential_candidate' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));

  console.log('\n== differential_evidence_rule (TB-ish) ==');
  console.log((await q('', `SELECT der.id, der.rule_code, der.condition_code, der.fact_code, der.support, der.weight FROM knowledge.differential_evidence_rule der WHERE der.condition_code ILIKE '%TB%' OR der.condition_code ILIKE '%TUBER%' OR der.fact_code IN ('WEIGHT_LOSS','NIGHT_SWEATS','TB_CONTACT') LIMIT 30`)).map((x: any) => `${x.rule_code} | ${x.condition_code} | ${x.fact_code} | ${x.support} | w${x.weight}`).join('\n'));
} finally { await p.end(); }