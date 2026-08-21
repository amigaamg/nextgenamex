import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  const codes = await pool.query(`SELECT protocol_code, canonical_name FROM knowledge.protocol WHERE status='active' ORDER BY protocol_code LIMIT 10`);
  console.log('active protocols:', codes.rowCount);
  codes.rows.forEach(r => console.log(' ', r.protocol_code, '|', r.canonical_name));

  const pc = codes.rows[0]?.protocol_code;
  if (pc) {
    const r = await pool.query(`
      SELECT
          p.protocol_code,
          ps.step_code,
          pa.action_type,
          pa.action_code,
          pa.action_name,
          pa.detail,
          pa.urgency,
          pa.sort_order,
          pa.required,
          pa.condition_expression
      FROM knowledge.protocol_action pa
      JOIN knowledge.protocol_step ps ON ps.id = pa.step_id
      JOIN knowledge.protocol p ON p.id = pa.protocol_id
      WHERE p.protocol_code = $1
        AND ps.status = 'active'
      ORDER BY ps.sequence_no, pa.sort_order
    `, [pc]);
    console.log(`\nactions for ${pc}: ${r.rowCount}`);
    r.rows.slice(0, 5).forEach(row => console.log('  ', row.action_type, row.action_code, row.action_name));
  }
} catch (e) {
  console.error('ERR', (e as Error).message);
} finally { await pool.end(); }