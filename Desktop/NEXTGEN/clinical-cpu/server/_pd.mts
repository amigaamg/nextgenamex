import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const c = await p.query(`SELECT conname, pg_get_constraintdef(oid) def FROM pg_constraint WHERE conrelid='knowledge.phenotype_differential'::regclass`);
  console.log(c.rows.map((x: any) => `${x.conname}: ${x.def}`).join('\n'));
  const r = await p.query(`SELECT DISTINCT relationship_type, polarity FROM knowledge.phenotype_differential LIMIT 20`);
  console.log('rel types:', r.rows.map((x: any) => `${x.relationship_type} (${x.polarity})`).join(', '));
} finally { await p.end(); }