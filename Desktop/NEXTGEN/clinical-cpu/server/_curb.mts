import { Pool } from 'pg';
const p = new Pool({ host: 'localhost', port: 5432, user: 'postgres', password: 'postgres', database: 'amexan' });
try {
  const r = await p.query(`
    SELECT s.score_code,
           c.component_code, c.fact_code, c.operator, c.threshold_value
    FROM knowledge.severity_score s
    JOIN knowledge.severity_score_component c ON c.score_id = s.id
    WHERE s.score_code ILIKE '%CURB%'
    ORDER BY c.component_code
  `);
  console.log('CURB-65 components:');
  console.log(r.rows.map(x => `${x.score_code} | ${x.component_code} | fact ${x.fact_code} ${x.operator} ${x.threshold_value}`).join('\n') || '(none)');
  const r2 = await p.query(`
    SELECT column_name FROM information_schema.columns
    WHERE table_schema='knowledge' AND table_name='severity_score_component'
    ORDER BY ordinal_position
  `);
  console.log('\nseverity_score_component cols:', r2.rows.map((x: any) => x.column_name).join(', '));
} finally { await p.end(); }