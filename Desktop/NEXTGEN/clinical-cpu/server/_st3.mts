import { Pool } from 'pg';
import { ClinicalCPU, Db } from '../src/index.js';
import { ProtocolEngine } from '../src/protocol/ProtocolEngine.js';
import { PhenotypeEngine } from '../src/phenotype/PhenotypeEngine.js';
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

    await send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    await send({ type: 'FACT_CAPTURED', payload: { factCode: 'COUGH_DURATION_DAYS', value: 4, unit: 'days' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_ONSET', answerCode: 'ACUTE' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'YES' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'DYSPNOEA_PRESENT', answerCode: 'YES' } });
    await send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'chest pain' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'CHEST_PAIN_PRESENT', answerCode: 'YES' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'PLEURITIC_CHEST_PAIN', answerCode: 'YES' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'SPUTUM_COLOUR', answerCode: 'CLEAR' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WHEEZE_PRESENT', answerCode: 'NO' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'TB_CONTACT', answerCode: 'NO' } });
    await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WEIGHT_LOSS', answerCode: 'NO' } });
    const p4b = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'NIGHT_SWEATS', answerCode: 'NO' } });

    console.log('=== 4b state ===');
    console.log('leading dx:', p4b.differentials[0]?.name);
    console.log('viaPhenotypes:', (p4b.differentials[0] as any)?.viaPhenotypes?.map((v: any) => `${v.phenotypeCode}:${v.score ?? v.compatibility ?? ''}`).join(',') ?? 'none');
    console.log('contradictions:', p4b.contradictions.map((c) => `${c.factCode}=${c.expectation}`).join(','));
    console.log('phenotypes at 4b:', p4b.phenotypes.slice(0, 8).map((p: any) => `${p.phenotypeCode}:${p.score}`).join(','));
    console.log('=== /4b ===');

    for (const [factCode, value] of [
      ['RESP_RATE', 24], ['SPO2', 94], ['TEMPERATURE', 38.2],
      ['RLL_DULLNESS', true], ['RLL_BRONCHIAL_BREATH_SOUNDS', true],
    ] as [string, number | boolean][]) {
      await send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode, value } });
    }
    const p = await send({ type: 'EXAM_FINDING_CAPTURED', payload: { findingCode: 'FIND-CRACKLES', value: true } });

    const phen = new PhenotypeEngine(db);
    const scores = await phen.score((p as any).capturedFacts);
    console.log('post-exam phenotypes:');
    for (const s of scores.slice(0, 6)) {
      console.log('  ', s.phenotypeCode, 'score', s.score, 'compat', s.compatibility, 'max', s.maxScore);
    }
    const lrti = await phen.explain('PHEN-ACUTE-LRTI', (p as any).capturedFacts);
    console.log('ACUTE-LRTI:', lrti ? `compat=${lrti.compatibility} pos=${lrti.positiveSupport} neg=${lrti.negativeSupport}` : 'null');

    const afterUrea = await send({ type: 'LAB_RESULT_RECEIVED', payload: { factCode: 'UREA', value: 9.2, unit: 'mmol/l', sourceType: 'lab' } });
    const afterRR = await send({ type: 'VITAL_CHANGED', payload: { factCode: 'RESP_RATE', value: 34, unit: 'min', sourceType: 'device' } });
    const curb2 = afterRR.severityScores.find((s) => s.scoreCode === 'SCORE-CURB65');
    console.log('CURB-65 escalated:', curb2 ? `${curb2.score}/${curb2.maxScore} ${curb2.severityLabel}` : 'none');
    for (const c of curb2?.components ?? []) {
      console.log('  ', c.componentCode, 'matched=', c.matched, 'points=', c.points);
    }
    console.log('UREA facts:', (afterRR as any).capturedFacts.filter((f: any) => f.factCode === 'UREA').map((f: any) => JSON.stringify(f.values)).join(','));
    console.log('RESP_RATE facts:', (afterRR as any).capturedFacts.filter((f: any) => f.factCode === 'RESP_RATE').map((f: any) => JSON.stringify(f.values)).join(','));
  } finally {
    await client.query('ROLLBACK');
    await client.end();
  }
}

main().catch((e) => { console.error('ERROR', e); process.exit(1); });