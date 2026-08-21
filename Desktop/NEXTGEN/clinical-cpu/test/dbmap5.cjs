const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });

const CORE = ['clinical.event','clinical.events','clinical.audit_event','governance.audit_event','clinical.clinical_event','clinical.timeline_event','clinical.engine_provenance','clinical.engine_output','clinical.snapshot','clinical.rule_execution','clinical.question_answer_event','clinical.question_selection_event','clinical.alert','clinical.capture_session','clinical.capture_action','clinical.history_engine_run','clinical.history_completion_result','clinical.medications','clinical.prescriptions','cpu.event_log','cpu.event_checkpoint','audit.event','system.event','identity.user_session','identity.user_account','cpu.alert','cpu.run','cpu.decision','cpu.state_snapshot','cpu.state_version'];

(async () => {
  const client = await pool.connect();
  try {
    const r = await client.query(
      `SELECT n.nspname||'.'||c.relname AS tbl, ct.conname, ct.contype,
              pg_get_constraintdef(ct.oid) AS definition
       FROM pg_constraint ct
       JOIN pg_class c ON c.oid = ct.conrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE ct.contype IN ('p','u')
         AND n.nspname||'.'||c.relname = ANY($1::text[])
       ORDER BY tbl, ct.contype, ct.conname`,
      [CORE]
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
