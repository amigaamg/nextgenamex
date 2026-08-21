const { Pool } = require('pg');
const pool = new Pool({ host: 'localhost', port: 5432, database: 'amexan', user: 'postgres', password: 'postgres!', max: 1 });

const TARGETS = [
  'clinical.event','clinical.events','clinical.clinical_event','clinical.timeline_event','clinical.audit_event','governance.audit_event',
  'clinical.engine_output','clinical.engine_provenance','clinical.snapshot','clinical.rule_execution','clinical.question_answer_event','clinical.question_selection_event',
  'clinical.alert','clinical.capture_session','clinical.capture_action','clinical.history_engine_run','clinical.history_completeness','clinical.history_completion_result',
  'clinical.medications','clinical.prescriptions','clinical.drug_dose_reference','clinical.prescription_safety_check','clinical.medication_contraindication','clinical.medication_interaction',
  'organization.facility','organization.service','organization.department','organization.clinic','organization.organization','organization.team','organization.unit',
  'identity.person','identity.user_account','identity.user_session'
];

(async () => {
  const client = await pool.connect();
  try {
    console.log('========== 1. ALL SCHEMAS ==========');
    let r = await client.query(
      `SELECT schema_name FROM information_schema.schemata
       WHERE schema_name NOT IN ('pg_catalog','information_schema','pg_toast')
       ORDER BY schema_name`
    );
    console.log(r.rows.map(x => x.schema_name).join(', '));

    console.log('\n========== 2. ALL TABLES/VIEWS IN governance & organization ==========');
    r = await client.query(
      `SELECT table_schema, table_name, table_type FROM information_schema.tables
       WHERE table_schema IN ('governance','organization')
       ORDER BY table_schema, table_name`
    );
    console.log(JSON.stringify(r.rows, null, 1));

    console.log('\n========== 3. OBSERVABILITY-NAMED TABLES (audit/log/event/telemetry/metric/monitor/outbox/queue) ==========');
    r = await client.query(
      `SELECT table_schema, table_name, table_type FROM information_schema.tables
       WHERE table_schema NOT IN ('pg_catalog','information_schema')
         AND (table_name ILIKE '%audit%' OR table_name ILIKE '%log%' OR table_name ILIKE '%event%'
              OR table_name ILIKE '%telemetry%' OR table_name ILIKE '%metric%' OR table_name ILIKE '%monitor%'
              OR table_name ILIKE '%outbox%' OR table_name ILIKE '%queue%')
       ORDER BY table_schema, table_name`
    );
    console.log(JSON.stringify(r.rows, null, 1));

    console.log('\n========== 4. TARGET TABLE SCHEMAS + CHECK CONSTRAINTS ==========');
    for (const t of TARGETS) {
      const [sch, nam] = t.split('.');
      const exists = await client.query(
        `SELECT to_regclass($1) AS reg`,
        [t]
      );
      if (!exists.rows[0].reg) {
        console.log(`\n### ${t} ==> DOES NOT EXIST`);
        continue;
      }
      console.log(`\n### ${t}`);
      const cols = await client.query(
        `SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema = $1 AND table_name = $2
         ORDER BY ordinal_position`,
        [sch, nam]
      );
      console.log('  COLUMNS:');
      console.log(cols.rows.map(x =>
        `    ${x.column_name}: ${x.data_type} (nullable=${x.is_nullable}, default=${x.column_default ?? 'NULL'})`
      ).join('\n'));
      const chk = await client.query(
        `SELECT conname, pg_get_constraintdef(oid) AS definition
         FROM pg_constraint
         WHERE conrelid = $1::regclass AND contype = 'c'
         ORDER BY conname`,
        [t]
      );
      if (chk.rows.length) {
        console.log('  CHECK CONSTRAINTS:');
        console.log(chk.rows.map(x => `    ${x.conname}: ${x.definition}`).join('\n'));
      } else {
        console.log('  CHECK CONSTRAINTS: (none)');
      }
    }
  } catch (e) {
    console.error('PROBE ERROR:', e.stack || e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
})();
