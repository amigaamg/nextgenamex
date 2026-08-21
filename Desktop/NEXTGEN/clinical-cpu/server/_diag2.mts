import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };

  console.log('== ACTIVE PROTOCOLS ==');
  console.log((await q('', `SELECT protocol_code, canonical_name, version, status FROM knowledge.protocol WHERE status='active' ORDER BY protocol_code`)).map((x: any) => `${x.protocol_code} | ${x.canonical_name} | v${x.version}`).join('\n'));

  console.log('\n== PROT-CAP-ADULT exists? ==');
  console.log(JSON.stringify(await q('', `SELECT protocol_code, version, status FROM knowledge.protocol WHERE protocol_code='PROT-CAP-ADULT'`)));

  console.log('\n== PROT-PNEUMONIA-KENYA-PAED steps ==');
  console.log((await q('', `SELECT ps.step_code, ps.step_label, ps.step_type, ps.sequence_no FROM knowledge.protocol_step ps JOIN knowledge.protocol pr ON pr.id=ps.protocol_id WHERE pr.protocol_code='PROT-PNEUMONIA-KENYA-PAED' ORDER BY ps.sequence_no`)).map((x: any) => `${x.sequence_no}. ${x.step_code} ${x.step_label} (${x.step_type})`).join('\n'));

  console.log('\n== MONITORING CODES ==');
  console.log((await q('', `SELECT monitoring_code, canonical_name, target_type, measurement_code FROM knowledge.monitoring ORDER BY monitoring_code`)).map((x: any) => `${x.monitoring_code} | ${x.canonical_name} | ${x.measurement_code}`).join('\n'));

  console.log('\n== PHEN-HYPOXAEMIA features ==');
  console.log((await q('', `SELECT f.feature_code, f.feature_type, f.operator, f.value, f.weight, f.polarity, f.requiredness FROM knowledge.phenotype_feature f JOIN knowledge.phenotype ph ON ph.id=f.phenotype_id WHERE ph.phenotype_code='PHEN-HYPOXAEMIA' ORDER BY f.feature_code`)).map((x: any) => `${x.feature_code} | ${x.feature_type} | ${x.operator} ${x.value} | w${x.weight} pol${x.polarity} req${x.requiredness}`).join('\n'));
  console.log('\n== PHEN-RESPIRATORY-FAILURE features ==');
  console.log((await q('', `SELECT f.feature_code, f.feature_type, f.operator, f.value, f.weight, f.polarity, f.requiredness FROM knowledge.phenotype_feature f JOIN knowledge.phenotype ph ON ph.id=f.phenotype_id WHERE ph.phenotype_code='PHEN-RESPIRATORY-FAILURE' ORDER BY f.feature_code`)).map((x: any) => `${x.feature_code} | ${x.feature_type} | ${x.operator} ${x.value} | w${x.weight} pol${x.polarity} req${x.requiredness}`).join('\n'));

  console.log('\n== PHEN-ACUTE-LRTI features ==');
  console.log((await q('', `SELECT f.feature_code, f.feature_type, f.operator, f.value, f.weight, f.polarity, f.requiredness FROM knowledge.phenotype_feature f JOIN knowledge.phenotype ph ON ph.id=f.phenotype_id WHERE ph.phenotype_code='PHEN-ACUTE-LRTI' ORDER BY f.feature_code`)).map((x: any) => `${x.feature_code} | ${x.feature_type} | ${x.operator} ${x.value} | w${x.weight} pol${x.polarity} req${x.requiredness}`).join('\n'));
  console.log('\n== PHEN-PLEURITIC-RESPIRATORY features ==');
  console.log((await q('', `SELECT f.feature_code, f.feature_type, f.operator, f.value, f.weight, f.polarity, f.requiredness FROM knowledge.phenotype_feature f JOIN knowledge.phenotype ph ON ph.id=f.phenotype_id WHERE ph.phenotype_code='PHEN-PLEURITIC-RESPIRATORY' ORDER BY f.feature_code`)).map((x: any) => `${x.feature_code} | ${x.feature_type} | ${x.operator} ${x.value} | w${x.weight} pol${x.polarity} req${x.requiredness}`).join('\n'));

  console.log('\n== ACTIVE OVERRIDES ==');
  console.log((await q('', `SELECT override_code, version, scope_code, scope_entity_id, target_type, target_id FROM knowledge.active_override ORDER BY override_code`)).map((x: any) => `${x.override_code} | v${x.version} | ${x.scope_code} | ${x.scope_entity_id} | ${x.target_type} ${x.target_id}`).join('\n'));

  console.log('\n== FACILITY (clinical) ==');
  console.log((await q('', `SELECT table_schema, table_name FROM information_schema.tables WHERE table_name ILIKE '%facility%'`)).map((x: any) => `${x.table_schema}.${x.table_name}`).join('\n'));

  console.log('\n== EXAM MODULES ==');
  console.log((await q('', `SELECT module_code, canonical_name, status, body_system_code FROM knowledge.examination_module ORDER BY module_code`)).map((x: any) => `${x.module_code} | ${x.canonical_name} | ${x.status} | ${x.body_system_code}`).join('\n'));

  console.log('\n== Differential: Tuberculosis/Pneumonia/Bronchitis ==');
  console.log((await q('', `SELECT table_name, column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name IN ('differential_candidate','diagnosis_concept','differential_hypothesis') AND column_name IN ('code','name','concept_code','differential_code','differential_name','diagnosis_code') ORDER BY table_name, column_name`)).map((x: any) => `${x.table_name}.${x.column_name}`).join('\n'));

  console.log('\n== ALERT: monitoring_alert cols ==');
  console.log((await q('', `SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='monitoring_alert' ORDER BY ordinal_position`)).map((x: any) => x.column_name).join(', '));
  console.log('\n== monitoring_alert rows ==');
  console.log((await q('', `SELECT * FROM knowledge.monitoring_alert ORDER BY 1 LIMIT 20`)).map((x: any) => JSON.stringify(x)).join('\n'));
} finally { await p.end(); }