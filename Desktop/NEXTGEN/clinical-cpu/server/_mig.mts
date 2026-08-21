import { Pool } from 'pg';
const pool = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan', max: 2 });
try {
  const r = await pool.query('SELECT version, name FROM system.migration ORDER BY version');
  console.log('Applied migrations:', r.rowCount);
  r.rows.forEach(x => console.log(x.version, x.name));
} catch (e) {
  console.error('ERR', e.message);
} finally { await pool.end(); }