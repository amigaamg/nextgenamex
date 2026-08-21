import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT p.protocol_code, m.monitoring_code, m.canonical_name, pm.start_condition, pm.frequency
    FROM knowledge.protocol_monitoring pm
    JOIN knowledge.protocol p ON p.id = pm.protocol_id
    JOIN knowledge.monitoring m ON m.id = pm.monitoring_id
    WHERE p.protocol_code IN ('PROT-CAP-ADULT','PROT-PNEUMONIA-KENYA-PAED')
    ORDER BY p.protocol_code, m.monitoring_code
  `);
  console.log('protocol_monitoring rows:');
  console.log(r.rows.map((x: any) => `${x.protocol_code} | ${x.monitoring_code} | ${x.canonical_name} | start=${x.start_condition} | freq=${x.frequency}`).join('\n') || '(none)');

  const steps = await p.query(`
    SELECT pr.protocol_code, ps.step_code, ps.step_label, ps.step_type, ps.sequence_no
    FROM knowledge.protocol_step ps JOIN knowledge.protocol pr ON pr.id = ps.protocol_id
    WHERE pr.protocol_code = 'PROT-CAP-ADULT' ORDER BY ps.sequence_no
  `);
  console.log('\nPROT-CAP-ADULT steps:');
  console.log(steps.rows.map((x: any) => `${x.sequence_no}. ${x.step_code} ${x.step_label} (${x.step_type})`).join('\n') || '(none)');

  const trig = await p.query(`
    SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='protocol_trigger' ORDER BY ordinal_position
  `);
  console.log('\nprotocol_trigger cols:', trig.rows.map((x: any) => x.column_name).join(', '));
  const tr = await p.query(`
    SELECT pt.* FROM knowledge.protocol_trigger pt
    JOIN knowledge.protocol pr ON pr.id = pt.protocol_id
    WHERE pr.protocol_code IN ('PROT-CAP-ADULT','PROT-PNEUMONIA-KENYA-PAED')
  `);
  console.log('\nprotocol triggers:');
  console.log(tr.rows.map((x: any) => JSON.stringify(x)).join('\n') || '(none)');
} finally { await p.end(); }