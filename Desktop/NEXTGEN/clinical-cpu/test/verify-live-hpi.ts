import { Db, createPool } from '../src/db.js';
import type { Pool } from 'pg';
import { ContextResolver } from '../src/context/ContextResolver.js';
import { CPUOrchestrator } from '../src/runtime/CPUOrchestrator.js';

const pool: Pool = createPool();
const db = new Db(pool);

async function main() {
  const patientId = process.argv[2] ?? 'bdad304d-e0db-44d1-8fd5-324c49533dd0';
  const encounterId = process.argv[3] ?? 'e21cb265-a9ad-409e-aa3e-e76897dbbe0f';

  const resolver = new ContextResolver(db);
  const state = await resolver.resolve(patientId, encounterId);
  console.log(`facts loaded: ${state.facts.length}\n`);

  const orchestrator = new CPUOrchestrator(db);
  const projection = await orchestrator.run(state);

  console.log('=== NEXT QUESTIONS (adaptive, top 8) ===');
  for (const q of projection.nextQuestions) {
    console.log(`  [${q.priority}] ${q.questionCode} (${q.requirementLevel}) — ${q.reason}`);
  }

  for (const section of projection.documentation) {
    console.log(`\n=== ${section.section} ===`);
    for (const s of section.sentences) console.log(s.text);
  }

  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
