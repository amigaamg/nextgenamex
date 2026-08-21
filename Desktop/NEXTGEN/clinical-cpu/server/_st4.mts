import { Pool } from 'pg';
import { ClinicalCPU, Db } from '../src/index.js';
import type { Row } from '../src/db.js';

const POOL = new Pool({
  host: 'localhost', port: 5432, user: 'postgres',
  password: 'postgres', database: 'amexan',
});

class TDb extends Db {
  override async query<T extends Row = Row>(sql: string, params: unknown[] = []): Promise<T[]> {
    return super.query(sql, params);
  }
}

async function main(): Promise<void> {
  const client = await POOL.connect();
  try {
    await client.query('BEGIN');
    const db = new TDb(client);
    const cpu = new ClinicalCPU(db);

    const personId = crypto.randomUUID();
    const patientId = crypto.randomUUID();
    await db.query(
      `INSERT INTO identity.person (id, status_code, sex_at_birth, birth_date, nationality_code, occupation)
       VALUES ($1, 'active', 'male', $2, 'KE', 'Farmer')`,
      [personId, '1990-02-14'],
    );
    await db.query(
      `INSERT INTO patient.patient (id, person_id, status_code)
       VALUES ($1, $2, 'active')`,
      [patientId, personId],
    );
    const { id: encounterId } = (await db.queryOne<{ id: string }>(
      `INSERT INTO encounter.encounter (patient_id, encounter_type_code, status_code, phase_code)
       VALUES ($1, 'opd', 'active', 'assessment') RETURNING id`,
      [patientId],
    ))!;

    const send = (event: Parameters<typeof cpu.process>[0]['event']) =>
      cpu.process({ patientId, encounterId, event });

    // No chief complaint at all
    const empty = await cpu.process({ patientId, encounterId, event: { type: 'ENCOUNTER_CREATED', payload: {} } });
    console.log('=== BEFORE any c/c ===');
    console.log('nextQuestions:', empty.nextQuestions.map((q) => q.questionCode).join(',') || '(none)');
    const emptyHpi = empty.documentation.find((d) => d.section === 'History of Present Illness');
    console.log('HPI:', emptyHpi?.sentences.map((s) => s.text).join(' | ') || '(none)');
    console.log('sections:', (empty as any).sections?.map((s: any) => `${s.sectionCode}:${s.state}`).join(',') ?? '(n/a)');
    console.log('=== /BEFORE ===');

    // Add a chief complaint
    await send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'YES' } });
    const afterCc = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'DYSPNOEA_PRESENT', answerCode: 'YES' } });
    console.log('=== AFTER c/c (cough) ===');
    console.log('nextQuestions:', afterCc.nextQuestions.map((q) => q.questionCode).join(','));
    const hpi = afterCc.documentation.find((d) => d.section === 'History of Present Illness');
    console.log('HPI:', hpi?.sentences.map((s) => s.text).join(' | '));
    console.log('=== /AFTER ===');
  } finally {
    await client.query('ROLLBACK');
    await client.end();
  }
}

main().catch((e) => { console.error('ERROR', e); process.exit(1); });