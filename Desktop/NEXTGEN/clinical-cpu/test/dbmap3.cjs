const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });

const TABLES = [
  'clinical.event','clinical.events','clinical.clinical_event','clinical.timeline_event','clinical.audit_event','governance.audit_event',
  'clinical.engine_output','clinical.engine_provenance','clinical.snapshot','clinical.rule_execution','clinical.question_answer_event','clinical.question_selection_event',
  'clinical.alert','clinical.capture_session','clinical.capture_action','clinical.history_engine_run','clinical.history_completeness','clinical.history_completion_result',
  'clinical.medications','clinical.prescriptions','clinical.drug_dose_reference','clinical.prescription_safety_check','clinical.medication_contraindication','clinical.medication_interaction',
  'organization.facility','organization.service','organization.department','organization.clinic','organization.organization','organization.team','organization.unit',
  'identity.person','identity.user_account','identity.user_session',
  'audit.event','audit.integration_event','cpu.event_log','cpu.run_event','cpu.event_checkpoint','system.event',
  'workflow.queue','workflow.queue_item','workflow.instance_event','workflow.task_event',
  'identity.audit_event','governance.provenance_record','governance.rule_execution','governance.reasoning_snapshot','governance.engine_registry','governance.safety_review',
  'clinical.consent_event','clinical.order_event','clinical.fact_provenance','clinical.provenance_link',
  'knowledge.reasoning_event','knowledge.reasoning_run','knowledge.reasoning_provenance','knowledge.reasoning_trace'
];

(async () => {
  const client = await pool.connect();
  try {
    const r = await client.query(
      `SELECT tc.table_schema AS sch, tc.table_name AS tbl, kcu.column_name AS col,
              ccu.table_schema AS ref_sch, ccu.table_name AS ref_tbl, ccu.column_name AS ref_col
       FROM information_schema.table_constraints tc
       JOIN information_schema.key_column_usage kcu
         ON tc.constraint_name=kcu.constraint_name AND tc.table_schema=kcu.table_schema
       JOIN information_schema.constraint_column_usage ccu
         ON ccu.constraint_name=tc.constraint_name AND ccu.table_schema=tc.table_schema
       WHERE tc.constraint_type='FOREIGN KEY'
         AND (tc.table_schema||'.'||tc.table_name) IN (SELECT unnest($1::text[]))
       ORDER BY tc.table_schema, tc.table_name, kcu.ordinal_position`,
      [TABLES]
    );
    const fkMap = {};
    for (const row of r.rows) {
      const key = row.sch + '.' + row.tbl;
      (fkMap[key] = fkMap[key] || []).push(`${row.col} -> ${row.ref_sch}.${row.ref_tbl}.${row.ref_col}`);
    }
    for (const k of Object.keys(fkMap).sort()) {
      console.log(`  ${k}:`);
      fkMap[k].forEach(f => console.log(`    ${f}`));
    }
    if (Object.keys(fkMap).length === 0) console.log('  (no FKs found on these tables)');
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();
