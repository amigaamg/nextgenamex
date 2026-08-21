import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  await pool.query(`INSERT INTO system.migration (version, name, applied_by)
    VALUES (57, '057_investigation_junction_clinical_attributes.sql', CURRENT_USER)
    ON CONFLICT (version) DO UPDATE SET name = EXCLUDED.name, applied_by = EXCLUDED.applied_by`);
  console.log('recorded migration 057');
} finally { await pool.end(); }