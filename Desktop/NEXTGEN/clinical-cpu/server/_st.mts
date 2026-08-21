import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const q = async (label: string, sql: string) => {
    try { const r = await p.query(sql); console.log(`\n=== ${label} ===`); return r.rows; }
    catch (e: any) { console.log(`\n=== ${label} === ERROR: ${e.message}`); return []; }
  };
  console.log('override:', JSON.stringify((await q('', `SELECT override_code, approval_status, review_required FROM knowledge.knowledge_override WHERE override_code='OVR-CXR-FACILITY-DEFER'`))[0]));
  console.log('protocol:', JSON.stringify((await q('', `SELECT protocol_code, status FROM knowledge.protocol WHERE protocol_code='PROT-CAP-ADULT'`))[0]));
  console.log('features:', JSON.stringify((await q('', `SELECT count(*) n FROM knowledge.phenotype_feature pf JOIN knowledge.phenotype ph ON ph.id=pf.phenotype_id WHERE pf.feature_code='CHEST_PAIN_PLEURITIC'`))[0]));
  console.log('phenotype ids 101/102:', JSON.stringify(await q('', `SELECT id, phenotype_code FROM knowledge.phenotype WHERE id IN ('f0f00000-0000-0000-0000-000000000101','f0f00000-0000-0000-0000-000000000102')`)));
  console.log('\nmax numeric suffix phenotype ids:');
  console.log((await q('', `SELECT id, phenotype_code FROM knowledge.phenotype WHERE id LIKE 'f0f00000-%' ORDER BY id DESC LIMIT 12`)).map((x: any) => `${x.id} | ${x.phenotype_code}`).join('\n'));
} finally { await p.end(); }