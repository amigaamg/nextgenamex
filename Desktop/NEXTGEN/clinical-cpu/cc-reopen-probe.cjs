const { Client } = require('pg');
const c = new Client({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
c.connect().then(async () => {
  const defs = await c.query(
    `SELECT code, name, data_type FROM clinical.fact_definition
     WHERE code LIKE '%CHIEF%' OR code = 'PRESENTING_COMPLAINT'
     ORDER BY code`
  );
  console.log('CHIEF fact definitions:');
  defs.rows.forEach((r) => console.log('  ', r.code, '|', r.name, '|', r.data_type));

  const stored = await c.query(
    `SELECT DISTINCT f.fact_definition_code FROM clinical.fact f
     WHERE f.fact_definition_code LIKE 'CHIEF%'
        OR f.fact_definition_code = 'PRESENTING_COMPLAINT'
        OR f.fact_definition_code LIKE '%_PRESENT'
     ORDER BY f.fact_definition_code`
  );
  console.log('CHIEF/PRESENT fact codes actually stored in DB:');
  stored.rows.forEach((r) => console.log('  ', r.fact_definition_code));

  const sample = await c.query(
    `SELECT f.fact_definition_code, f.value, f.source_ref, f.observed_at
     FROM clinical.fact f
     WHERE f.fact_definition_code LIKE 'CHIEF%' OR f.fact_definition_code = 'PRESENTING_COMPLAINT'
     ORDER BY f.observed_at DESC LIMIT 15`
  );
  console.log('Sample stored rows:');
  sample.rows.forEach((r) => console.log('  ', r.fact_definition_code, '| value=', JSON.stringify(r.value), '| source_ref=', r.source_ref, '| at=', r.observed_at));
  await c.end();
}).catch((e) => { console.error(e.message); process.exit(1); });