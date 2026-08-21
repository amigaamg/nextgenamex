import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`SELECT override_code, scope_code, approval_status, review_required, effective_from FROM knowledge.active_override WHERE override_code='OVR-CXR-FACILITY-DEFER'`);
  console.log('active_override OVR-CXR rows:', r.rows.length);
  for (const x of r.rows) console.log(JSON.stringify(x));
  const r2 = await p.query(`SELECT override_code, approval_status, review_required, status FROM knowledge.knowledge_override WHERE override_code='OVR-CXR-FACILITY-DEFER'`);
  console.log('knowledge_override row:', JSON.stringify(r2.rows));
} finally { await p.end(); }