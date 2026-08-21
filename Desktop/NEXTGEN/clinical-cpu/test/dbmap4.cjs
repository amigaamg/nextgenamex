const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });

const EXTRA = [
  'cpu.alert','cpu.open_alerts','cpu.run','cpu.decision','cpu.decision_evidence','cpu.performance_sample','cpu.processing_error','cpu.state_snapshot','cpu.state_version','cpu.patient_state','cpu.current_fact','cpu.fact_history','cpu.knowledge_resolution','cpu.question_activation','cpu.patient_lease',
  'audit.access','audit.authentication','audit.entity_change','audit.document_change','audit.clinical_decision','audit.order_decision','audit.configuration_change','audit.data_export',
  'system.health_check','system.job_execution','system.job','system.instance','system.service','system.engine','system.engine_version',
  'governance.clinical_snapshot','governance.documentation_snapshot','governance.conflict_record','governance.system_version','governance.model_registry'
];

(async () => {
  const client = await pool.connect();
  try {
    console.log('========== EXTRA OBSERVABILITY TABLES: COLUMNS + CHECKS ==========');
    for (const t of EXTRA) {
      const [sch, nam] = t.split('.');
      const exists = await client.query(`SELECT to_regclass($1) AS reg`, [t]);
      if (!exists.rows[0].reg) { console.log(`\n### ${t} ==> DOES NOT EXIST`); continue; }
      console.log(`\n### ${t}`);
      const cols = await client.query(
        `SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns WHERE table_schema=$1 AND table_name=$2 ORDER BY ordinal_position`,
        [sch, nam]);
      console.log(cols.rows.map(x => `  ${x.column_name}: ${x.data_type} (nullable=${x.is_nullable}, default=${x.column_default ?? 'NULL'})`).join('\n'));
      const chk = await client.query(
        `SELECT conname, pg_get_constraintdef(oid) AS definition FROM pg_constraint
         WHERE conrelid=$1::regclass AND contype='c' ORDER BY conname`, [t]);
      if (chk.rows.length) console.log('  CHECKS:\n' + chk.rows.map(x => `    ${x.conname}: ${x.definition}`).join('\n'));
      else console.log('  CHECKS: (none)');
    }

    console.log('\n========== PK + UNIQUE CONSTRAINTS ON CORE EVENT/PROVENANCE TABLES ==========');
    const core = ['clinical.event','clinical.events','clinical.audit_event','governance.audit_event','clinical.clinical_event','clinical.timeline_event','clinical.engine_provenance','clinical.engine_output','clinical.snapshot','clinical.rule_execution','clinical.question_answer_event','clinical.question_selection_event','clinical.alert','clinical.capture_session','clinical.capture_action','clinical.history_engine_run','clinical.history_completion_result','clinical.medications','clinical.prescriptions','cpu.event_log','cpu.event_checkpoint','audit.event','system.event','identity.user_session','identity.user_account'];
    const r = await client.query(
      `SELECT tc.table_schema||'.'||tc.table_name AS tbl, tc.constraint_name, tc.constraint_type,
              pg_get_constraintdef(tc.oid) AS definition
       FROM pg_constraint tc
       WHERE tc.conrelid IN (SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname||'.'||c.relname = ANY($1::text[]))
         AND tc.contype IN ('p','u')
       ORDER BY tbl, tc.contype`,
      [core]
    );
    console.log(JSON.stringify(r.rows, null, 1));
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();
