import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const tables = [
    'knowledge.protocol', 'knowledge.protocol_step', 'knowledge.protocol_trigger',
    'knowledge.monitoring', 'knowledge.protocol_monitoring',
    'knowledge.phenotype_feature', 'knowledge.phenotype',
    'knowledge.active_override', 'knowledge.override_rule', 'knowledge.override_provenance',
    'knowledge.examination_module',
    'knowledge.alert_rule', 'knowledge.phenotype_alert',
  ];
  for (const t of tables) {
    const r = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema=split_part($1,'.',1) AND table_name=split_part($1,'.',2) ORDER BY ordinal_position`, [t]);
    console.log(`\n${t}: ${r.rows.map((x: any) => x.column_name).join(', ')}`);
  }
  const t2 = await p.query(`SELECT table_name FROM information_schema.tables WHERE table_schema='knowledge' AND (table_name ILIKE '%differential%' OR table_name ILIKE '%diagnosis%' OR table_name ILIKE '%alert%') ORDER BY table_name`);
  console.log('\ndifferential/alert tables:', t2.rows.map((x: any) => x.table_name).join(', '));
} finally { await p.end(); }