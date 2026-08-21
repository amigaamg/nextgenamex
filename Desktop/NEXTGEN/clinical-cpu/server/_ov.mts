import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };
  console.log('== knowledge_override rows ==');
  console.log((await q('', `SELECT override_code, target_type, target_id, scope_code, scope_entity_id, config, reason, status FROM knowledge.knowledge_override ORDER BY override_code`)).map((x: any) => `${x.override_code} | ${x.scope_code} | ${x.status} | ${x.reason}`).join('\n') || '(none)');
  console.log('\n== active_override rows ==');
  console.log((await q('', `SELECT override_code, target_type, target_id, scope_code, scope_entity_id, version, override_type, approval_status, status FROM knowledge.active_override ORDER BY override_code`)).map((x: any) => `${x.override_code} | ${x.scope_code} | v${x.version} | ${x.override_type} | ${x.approval_status} | ${x.status}`).join('\n') || '(none)');
  console.log('\n== v_z9_active_overrides ==');
  const v = await q('', `SELECT * FROM knowledge.v_z9_active_overrides ORDER BY 1 LIMIT 10`);
  console.log(v.map((x: any) => JSON.stringify(x)).join('\n') || '(none)');
  const r = await p.query(`SELECT pg_get_viewdef('knowledge.v_z9_active_overrides'::regclass, true)`);
  console.log('\nview def:\n' + r.rows[0].pg_get_viewdef);
} finally { await p.end(); }