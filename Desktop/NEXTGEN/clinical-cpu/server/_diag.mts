import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };

  // 1. protocols
  console.log('== ACTIVE PROTOCOLS ==');
  console.log((await q('', `SELECT code, name, status FROM knowledge.protocol WHERE status='active' ORDER BY code`)).map((x: any) => `${x.code} | ${x.name}`).join('\n'));

  // 2. CAP protocol steps
  console.log('\n== PROT-CAP-ADULT exists? ==');
  console.log((await q('', `SELECT count(*)::text c FROM knowledge.protocol WHERE code='PROT-CAP-ADULT'`))[0]?.c);
  console.log('\n== PROT-PNEUMONIA-KENYA-PAED steps ==');
  console.log((await q('', `SELECT ps.step_code, ps.name, ps.step_order FROM knowledge.protocol_step ps JOIN knowledge.protocol pr ON pr.id=ps.protocol_id WHERE pr.code='PROT-PNEUMONIA-KENYA-PAED' ORDER BY ps.step_order`)).map((x: any) => `${x.step_order}. ${x.step_code} ${x.name}`).join('\n'));

  // 3. monitoring codes
  console.log('\n== MONITORING CODES ==');
  console.log((await q('', `SELECT code, name FROM knowledge.monitoring ORDER BY code`)).map((x: any) => `${x.code} | ${x.name}`).join('\n'));

  // 4. PHEN-HYPOXAEMIA features
  console.log('\n== PHEN-HYPOXAEMIA features ==');
  console.log((await q('', `SELECT f.phenotype_code, f.feature_code, f.fact_code, f.matching_rule, f.threshold_value, f.weight, f.required FROM knowledge.phenotype_feature f WHERE f.phenotype_code IN ('PHEN-HYPOXAEMIA','PHEN-RESPIRATORY-FAILURE') ORDER BY f.phenotype_code, f.feature_code`)).map((x: any) => `${x.phenotype_code} | ${x.feature_code} | ${x.fact_code} | ${x.matching_rule} ${x.threshold_value} | w${x.weight} req${x.required}`).join('\n'));

  // 5. PHEN-ACUTE-LRTI / PHEN-PLEURITIC-RESPIRATORY features
  console.log('\n== PHEN-ACUTE-LRTI features ==');
  console.log((await q('', `SELECT f.phenotype_code, f.fact_code, f.matching_rule, f.threshold_value, f.weight, f.required FROM knowledge.phenotype_feature f WHERE f.phenotype_code='PHEN-ACUTE-LRTI' ORDER BY f.feature_code`)).map((x: any) => `${x.fact_code} | ${x.matching_rule} ${x.threshold_value} | w${x.weight} req${x.required}`).join('\n'));
  console.log('\n== PHEN-PLEURITIC-RESPIRATORY features ==');
  console.log((await q('', `SELECT f.phenotype_code, f.fact_code, f.matching_rule, f.threshold_value, f.weight, f.required FROM knowledge.phenotype_feature f WHERE f.phenotype_code='PHEN-PLEURITIC-RESPIRATORY' ORDER BY f.feature_code`)).map((x: any) => `${x.fact_code} | ${x.matching_rule} ${x.threshold_value} | w${x.weight} req${x.required}`).join('\n'));

  // 6. active_override + facility
  console.log('\n== ACTIVE OVERRIDES ==');
  console.log((await q('', `SELECT ov.code, ov.version, ov.scope_code, ov.scope_entity_id FROM knowledge.active_override ov ORDER BY ov.code`)).map((x: any) => `${x.code} | v${x.version} | ${x.scope_code} | ${x.scope_entity_id}`).join('\n'));
  console.log('\n== FACILITY ==');
  console.log((await q('', `SELECT id, name, code FROM clinical.facility ORDER BY name LIMIT 10`)).map((x: any) => `${x.id} | ${x.code} | ${x.name}`).join('\n'));
  console.log('\n== OVERRIDE TABLES ==');
  console.log((await q('', `SELECT table_name FROM information_schema.tables WHERE table_schema='knowledge' AND table_name LIKE '%override%'`)).map((x: any) => x.table_name).join(', '));

  // 7. EXAM-RESPIRATORY module
  console.log('\n== EXAM MODULES ==');
  console.log((await q('', `SELECT m.code, m.name, m.status FROM knowledge.examination_module m ORDER BY m.code`)).map((x: any) => `${x.code} | ${x.name} | ${x.status}`).join('\n'));
  console.log('\n== EXAM-RESPIRATORY trigger/condition cols ==');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='examination_module' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));

  // 8. TB differential - is Tuberculosis in the differential table
  console.log('\n== DIFFERENTIAL DIAGNOSES ==');
  console.log((await q('', `SELECT code, name FROM knowledge.differential_diagnosis WHERE name ILIKE '%tuberc%' OR name ILIKE '%pneumonia%' OR name ILIKE '%bronchitis%' ORDER BY name`)).map((x: any) => `${x.code} | ${x.name}`).join('\n'));

  // 9. alert rules for hypoxaemia
  console.log('\n== ALERT RULES ==');
  console.log((await q('', `SELECT a.alert_code, a.alert_label, a.threshold_score, a.level FROM knowledge.alert_rule a ORDER BY a.alert_code`)).map((x: any) => `${x.alert_code} | ${x.alert_label} | threshold ${x.threshold_score} | ${x.level}`).join('\n'));
} finally { await p.end(); }