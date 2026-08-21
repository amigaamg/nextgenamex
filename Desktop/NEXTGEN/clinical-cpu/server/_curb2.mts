import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT s.score_code, s.canonical_name,
           c.component_code, c.points, c.condition::text AS condition
    FROM knowledge.severity_score s
    LEFT JOIN knowledge.severity_score_component c ON c.score_id = s.id
    WHERE s.score_code ILIKE '%CURB%'
    ORDER BY c.sort_order
  `);
  console.log(r.rows.map(x => `${x.score_code} | ${x.component_code} (+${x.points}) | ${x.condition}`).join('\n---\n') || '(none)');
  const cols = await p.query(`SELECT column_name FROM information_schema.columns WHERE table_schema='knowledge' AND table_name='severity_score' ORDER BY ordinal_position`);
  console.log('\nseverity_score cols:', cols.rows.map((c: any) => c.column_name).join(', '));
} finally { await p.end(); }