// =============================================================================
// AMEXAN Phase 3 — benchmark test: one complete machine run
// =============================================================================
// The 35-year-old man: acute cough (4 days, productive), fever, dyspnoea,
// pleuritic chest pain, RLL consolidation signs. The CPU must:
//   capture each fact → adaptively ask the next question → activate the
//   respiratory phenotype → resolve the mechanism → rank the differential →
//   explain evidence → select examination → propose investigations →
//   activate the protocol → set monitoring → deliver education → compose
//   documentation → present recommendations → record clinician decisions →
//   and REASSESS when SpO2 drops 94 → 88.
//
// Runs inside a transaction and rolls back, leaving the database pristine.
// =============================================================================

import { Pool } from 'pg';
import { ClinicalCPU, Db } from '../src/index.js';
import type { Row } from '../src/db.js';
import type { ClinicalRuntimeProjection, ProcessRequest } from '../src/types.js';

class TraceDb extends Db {
  private seen = new Set<string>();
  override async query<T extends Row = Row>(sql: string, params: unknown[] = []): Promise<T[]> {
    try {
      return await super.query(sql, params);
    } catch (e) {
      const err = e as Error & { position?: string; code?: string };
      const key = sql.slice(0, 80);
      if (!this.seen.has(key)) {
        this.seen.add(key);
        console.error(`\n=== SQL FAILURE [${err.code}] ===`);
        console.error(sql.slice(0, 500));
        if (err.position) {
          const pos = Number(err.position);
          console.error('--- around ---');
          console.error(sql.slice(Math.max(0, pos - 100), pos + 30));
        }
      }
      throw e;
    }
  }
}

const POOL = new Pool({
  host: process.env.AMEXAN_PGHOST || 'localhost',
  port: Number(process.env.AMEXAN_PGPORT || 5432),
  user: process.env.AMEXAN_PGUSER || 'postgres',
  password: process.env.AMEXAN_PGPASSWORD || 'postgres',
  database: process.env.AMEXAN_PGDATABASE || 'amexan',
});

let failures = 0;
function check(label: string, ok: boolean, detail = ''): void {
  const marker = ok ? 'PASS' : 'FAIL';
  if (!ok) failures += 1;
  console.log(`  [${marker}] ${label}${detail ? ` — ${detail}` : ''}`);
}

function projectionSummary(projection: ClinicalRuntimeProjection): string {
  const topPhen = projection.phenotypes[0];
  const dx = projection.differentials[0];
  return [
    `phenotypes=${projection.phenotypes.slice(0, 3).map((p) => `${p.phenotypeCode}:${p.score}`).join(',')}`,
    `dx=${dx ? `${dx.name}:${dx.compatibility}` : 'none'}`,
    `q=${projection.nextQuestions.map((q) => q.questionCode).join(',')}`,
  ].join(' | ');
}

async function main(): Promise<void> {
  const client = await POOL.connect();
  try {
    await client.query('BEGIN');
    const db = new TraceDb(client);
    const cpu = new ClinicalCPU(db);

    // --- Set up the 35-year-old male patient + encounter -------------------
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

    console.log('\nAMEXAN CLINICAL CPU — benchmark run (35yo male, acute productive cough)');
    console.log(`patient ${patientId} / encounter ${encounterId}\n`);

    const send = (event: ProcessRequest['event']): Promise<ClinicalRuntimeProjection> =>
      cpu.process({ patientId, encounterId, event });

    // --- 1. Presenting symptom: cough --------------------------------------
    let projection = await send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    check('cough activates the respiratory question branch', projection.nextQuestions.length > 0, projectionSummary(projection));
    check('chest-pain questions NOT offered before chest pain is reported',
      !projection.nextQuestions.some((q) => q.questionCode === 'PLEURITIC_CHEST_PAIN'));

    // --- 2. Adaptive interview: cough branch -------------------------------
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    check('answer PRODUCTIVE resolves to fact COUGH_PRODUCTIVITY=PRODUCTIVE',
      projection.capturedFacts.some((f) => f.factCode === 'COUGH_PRODUCTIVITY' && f.values[0]?.text === 'PRODUCTIVE'));

    projection = await send({ type: 'FACT_CAPTURED', payload: { factCode: 'COUGH_DURATION_DAYS', value: 4, unit: 'days' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_ONSET', answerCode: 'ACUTE' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'YES' } });
    check('answering FEVER_PRESENT=YES makes fever active', projection.activeSymptoms.includes('fever'));

    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'DYSPNOEA_PRESENT', answerCode: 'YES' } });

    // --- 3. Pleuritic chest pain emerges during the interview --------------
    projection = await send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'chest pain' } });
    check('chest-pain questions appear once chest pain is reported',
      projection.nextQuestions.some((q) => q.questionCode === 'CHEST_PAIN_CHARACTER'), projectionSummary(projection));
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'CHEST_PAIN_PRESENT', answerCode: 'YES' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'PLEURITIC_CHEST_PAIN', answerCode: 'YES' } });
    check('pleuritic chest pain captured as a fact',
      projection.capturedFacts.some((f) => f.factCode === 'PLEURITIC_CHEST_PAIN' && f.values[0]?.boolean === true));

    // --- 4. Finish the interview (negatives + sputum) ----------------------
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'SPUTUM_COLOUR', answerCode: 'CLEAR' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WHEEZE_PRESENT', answerCode: 'NO' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'TB_CONTACT', answerCode: 'NO' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WEIGHT_LOSS', answerCode: 'NO' } });
    projection = await send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'NIGHT_SWEATS', answerCode: 'NO' } });

    // --- 4b. Contradiction engine: expected-but-undocumented findings --------
    // Anti-anchoring (3.9): for the leading differential, the CPU lists what it
    // EXPECTS but has not yet confirmed — the RLL signs are still unmeasured.
    check('contradiction probes list expected-but-undocumented signs for the leading differential',
      projection.contradictions.length >= 1 &&
        projection.contradictions.some((c) => c.factCode === 'RLL_DULLNESS' || c.factCode === 'RLL_BRONCHIAL_BREATH_SOUNDS'),
      projection.contradictions.map((c) => `${c.factCode}=${c.expectation}`).join(','));

    // --- 5. Examination ----------------------------------------------------
    // CRACKLES is captured through the ExaminationInterpreter (finding code →
    // fact) to prove examination feeds the same reasoning substrate as history.
    const examFacts: [string, number | boolean][] = [
      ['RESP_RATE', 24],
      ['SPO2', 94],
      ['TEMPERATURE', 38.2],
      ['RLL_DULLNESS', true],
      ['RLL_BRONCHIAL_BREATH_SOUNDS', true],
    ];
    for (const [factCode, value] of examFacts) {
      projection = await send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode, value } });
    }
    projection = await send({ type: 'EXAM_FINDING_CAPTURED', payload: { findingCode: 'FIND-CRACKLES', value: true } });
    check('examination finding code resolves to its fact (FIND-CRACKLES → CRACKLES)',
      projection.capturedFacts.some((f) => f.factCode === 'CRACKLES' && f.values[0]?.boolean === true));

    // --- 6. REASONING ASSERTIONS ------------------------------------------
    console.log('\nPost-examination reasoning:');
    console.log(`  phenotypes  : ${projection.phenotypes.slice(0, 3).map((p) => `${p.phenotypeCode}=${p.score}`).join(', ')}`);
    console.log(`  mechanisms  : ${projection.mechanisms.slice(0, 3).map((m) => `${m.mechanismCode}=${m.support}`).join(', ')}`);
    console.log(`  differential: ${projection.differentials.slice(0, 4).map((d) => `${d.name}=${d.compatibility}`).join(', ')}`);

    const leadingPhenotype = projection.phenotypes[0]?.phenotypeCode;
    check('leading phenotype is acute LRTI', leadingPhenotype === 'PHEN-ACUTE-LRTI', leadingPhenotype ?? 'none');

    const leadingMechanism = projection.mechanisms[0]?.mechanismCode;
    check('leading mechanism is alveolar inflammation', leadingMechanism === 'MECH-ALVEOLAR-INFLAMMATION', leadingMechanism ?? 'none');

    const workingDiagnosis = projection.differentials[0]?.name;
    check('working diagnosis is Pneumonia', workingDiagnosis === 'Pneumonia', workingDiagnosis ?? 'none');
    check('TB is low in the differential',
      (projection.differentials.find((d) => d.name === 'Tuberculosis')?.compatibility ?? 99) <
        (projection.differentials.find((d) => d.name === 'Pneumonia')?.compatibility ?? 0));

    const cap = projection.differentials.find((d) => d.name === 'Pneumonia');
    check('Pneumonia has supporting evidence (fever/dyspnoea/pleuritic/RLL signs)',
      (cap?.evidence.filter((e) => e.support === 'support').length ?? 0) >= 5,
      `${cap?.evidence.filter((e) => e.support === 'support').length ?? 0} supporting lines`);
    check('Pneumonia evidence is traceable to captured facts',
      cap?.evidence.every((e) => projection.capturedFacts.some((f) => f.factCode === e.factCode)) ?? false);

    // --- 7. Examination / investigation / protocol / monitoring ------------
    check('respiratory examination module offered', projection.examination.some((m) => m.moduleCode === 'EXAM-RESPIRATORY'));
    check('CXR proposed with a reason',
      projection.investigations.some((i) => i.investigationCode === 'INV-CXR' && !!i.rationale),
      projection.investigations.map((i) => `${i.investigationCode}:${i.weight}`).join(','));
    check('facility configuration override reshapes the CXR recommendation (3.19)',
      projection.investigations.some((i) => i.investigationCode === 'INV-CXR' && (i.rationale ?? '').includes('facility guidance')) &&
        projection.configuration.overrides.some((o) => o.overrideCode === 'OVR-CXR-FACILITY-DEFER' && o.version >= 1),
      JSON.stringify(projection.configuration.overrides.map((o) => `${o.overrideCode}:${o.scopeCode}:v${o.version}`)));
    check('SpO2 dropped from proposed investigations once measured',
      !projection.investigations.some((i) => i.investigationCode === 'INV-SPO2'));

    check('CAP protocol activated', projection.protocol?.protocolCode === 'PROT-CAP-ADULT', projection.protocol?.protocolCode ?? 'none');
    check('CAP protocol has 11 steps incl. CURB-65 severity classification',
      projection.protocol?.steps.length === 11 &&
        projection.protocol.steps.some((s) => s.stepCode === 'STEP-04A' && s.actions.some((a) => a.actionType === 'score' && a.actionCode === 'SCORE-CURB65')),
      String(projection.protocol?.steps.length));
    check('monitoring includes SpO2/RR/temp',
      ['MON-SPO2', 'MON-RR', 'MON-TEMP'].every((code) => projection.monitoring.some((m) => m.monitoringCode === code)));
    check('education includes danger signs', projection.education.some((e) => e.educationCode === 'EDU-CAP-DANGER-SIGNS'));
    check('treatment offers an eligible antibiotic (with verification flag)',
      projection.treatment.some((t) => t.role === 'treatment' && !t.verified && t.safetyNotes.length > 0),
      projection.treatment.map((t) => `${t.genericName}(${t.role})`).join(','));

    // --- 7b. CURB-65 severity score (structured scoring object) -------------
    const curb = projection.severityScores.find((s) => s.scoreCode === 'SCORE-CURB65');
    check('CURB-65 severity score computed for suspected CAP',
      !!curb, projection.severityScores.map((s) => s.scoreCode).join(','));
    check('CURB-65 = 0 for the stable 35yo (age<65, RR 24, no urea/BP/confusion)',
      curb?.score === 0 && curb?.severityLabel === 'Low' && curb?.disposition === 'Treat as outpatient',
      curb ? `${curb.score}/${curb.maxScore} ${curb.severityLabel}` : 'no score');
    check('CURB-65 component computation is transparent',
      (curb?.components.length ?? 0) === 5 &&
        curb!.components.every((c) => (c.matched ? c.points : 0) === (c.points === 1 && c.matched ? 1 : 0)),
      curb?.components.map((c) => `${c.componentCode}=${c.matched}`).join(','));

    // --- 8. Adaptive interview hygiene -------------------------------------
    const answeredSoFar = new Set([
      'COUGH_PRODUCTIVITY', 'COUGH_ONSET', 'FEVER_PRESENT', 'DYSPNOEA_PRESENT',
      'CHEST_PAIN_PRESENT', 'CHEST_PAIN_PLEURITIC', 'SPUTUM_COLOUR', 'WHEEZE_PRESENT',
      'TB_CONTACT', 'WEIGHT_LOSS', 'NIGHT_SWEATS',
    ]);
    check('no answered question is offered again',
      !projection.nextQuestions.some((q) => answeredSoFar.has(q.questionCode)),
      projection.nextQuestions.map((q) => q.questionCode).join(','));
    check('irrelevant cardiac/GI/systemic probes not pushed (no orthopnoea/heartburn questions)',
      !projection.nextQuestions.some((q) => ['ORTHOPNOEA', 'PND', 'HEARTBURN'].includes(q.questionCode)));

    // --- 9. Documentation is fact-traceable --------------------------------
    const hpi = projection.documentation.find((d) => d.section === 'History of Present Illness');
    check('HPI is composed', hpi?.sentences.length ? hpi.sentences.length >= 2 : false, JSON.stringify(hpi?.sentences[0]?.text));
    check('HPI reflects a productive cough', hpi?.sentences[0]?.text.toLowerCase().includes('productive') ?? false);

    // --- 10. Clinician decision loop ----------------------------------------
    const cxrRecommendation = projection.recommendations.find((r) => r.code === 'INV-CXR');
    check('CXR recommendation present', !!cxrRecommendation);
    if (cxrRecommendation) {
      await send({
        type: 'CLINICIAN_DECISION',
        payload: {
          type: 'investigation',
          code: 'INV-CXR',
          recommendation: cxrRecommendation.text,
          status: 'accepted',
          reason: 'Suspected pneumonia with focal signs',
        },
      });
      const decisionCount = await db.queryOne<{ count: string }>(`SELECT count(*)::text AS count FROM cpu.decision WHERE patient_id = $1`, [patientId]);
      check('clinician decision recorded with reason', Number(decisionCount?.count ?? 0) >= 1, `decisions=${decisionCount?.count}`);

      // --- 10b. Result interpreter: the CXR result returns to the CPU -------
      // The closed loop (3.16): an imaging result establishes the SAME facts
      // the reasoning engines score, with imaging provenance.
      projection = await send({
        type: 'IMAGING_RESULT_RECEIVED',
        payload: { investigationCode: 'INV-CXR', results: ['RLL_CONSOLIDATION'] },
      });
      check('CXR result returns to the CPU as facts (RLL consolidation → RLL_DULLNESS + bronchial sounds)',
        projection.capturedFacts.some((f) => f.factCode === 'RLL_DULLNESS' && f.sourceType === 'imaging') &&
          projection.capturedFacts.some((f) => f.factCode === 'RLL_BRONCHIAL_BREATH_SOUNDS' && f.sourceType === 'imaging'),
        projection.capturedFacts.filter((f) => ['RLL_DULLNESS', 'RLL_BRONCHIAL_BREATH_SOUNDS'].includes(f.factCode)).map((f) => `${f.factCode}:${f.sourceType}`).join(','));
      check('working diagnosis is preserved after the imaging result',
        projection.differentials[0]?.name === 'Pneumonia');
    }

    // --- 11. REASSESSMENT — SpO2 drops 94 → 88 ------------------------------
    const hypoxBefore = projection.phenotypes.find((p) => p.phenotypeCode === 'PHEN-HYPOXAEMIA')?.score ?? 0;
    const rfBefore = projection.phenotypes.find((p) => p.phenotypeCode === 'PHEN-RESPIRATORY-FAILURE')?.score ?? 0;
    projection = await send({ type: 'LAB_RESULT_RECEIVED', payload: { factCode: 'SPO2', value: 88, sourceType: 'lab' } });
    const hypoxAfter = projection.phenotypes.find((p) => p.phenotypeCode === 'PHEN-HYPOXAEMIA')?.score ?? 0;
    const rfAfter = projection.phenotypes.find((p) => p.phenotypeCode === 'PHEN-RESPIRATORY-FAILURE')?.score ?? 0;
    check('hypoxaemia phenotype rises when SpO2 drops', hypoxAfter > hypoxBefore, `${hypoxBefore} -> ${hypoxAfter}`);
    check('respiratory-failure phenotype rises when SpO2 drops', rfAfter > rfBefore, `${rfBefore} -> ${rfAfter}`);
    check('CPU raises an urgent deterioration alert',
      projection.alerts.some((a) => a.level === 'urgent' && a.code === 'PHEN-HYPOXAEMIA'),
      projection.alerts.map((a) => `${a.code}:${a.level}`).join(','));
    check('working diagnosis is preserved and re-confirmed after reassessment', projection.differentials[0]?.name === 'Pneumonia');

    // --- 11b. CURB-65 escalates with the laboratory picture -----------------
    // Urea >7 and RR >=30 (both now documented) push the score to 2 → admit.
    projection = await send({ type: 'LAB_RESULT_RECEIVED', payload: { factCode: 'UREA', value: 9.2, unit: 'mmol/l', sourceType: 'lab' } });
    projection = await send({ type: 'VITAL_CHANGED', payload: { factCode: 'RESP_RATE', value: 34, unit: 'min', sourceType: 'device' } });
    const curbEscalated = projection.severityScores.find((s) => s.scoreCode === 'SCORE-CURB65');
    check('CURB-65 rises to 2 when urea 9.2 + RR 34 are documented (admit)',
      curbEscalated?.score === 2 && curbEscalated?.severityLabel === 'Moderate' && curbEscalated?.disposition === 'Admit to hospital',
      curbEscalated ? `${curbEscalated.score}/${curbEscalated.maxScore} ${curbEscalated.severityLabel} (${curbEscalated.disposition})` : 'no score');

    // --- 12. Evidence ledger for the differential ---------------------------
    const tb = projection.differentials.find((d) => d.name === 'Tuberculosis');
    check('TB evidence lists against-lines (no weight loss, no night sweats, no TB contact)',
      (tb?.evidence.filter((e) => e.support === 'against').length ?? 0) >= 3,
      `${tb?.evidence.filter((e) => e.support === 'against').length ?? 0} against-lines`);

    // --- 13. Safety factors (3.17) — a penicillin allergy is applied -------
    projection = await send({ type: 'FACT_CAPTURED', payload: { factCode: 'DRUG_ALLERGY', value: 'Penicillin' } });
    const amoxicillin = projection.treatment.find((t) => t.medicationCode === 'MED-AMOXICILLIN');
    const azithromycin = projection.treatment.find((t) => t.medicationCode === 'MED-AZITHROMYCIN');
    check('beta-lactam allergy flags amoxicillin as contraindicated',
      amoxicillin?.contraindicated === true &&
        amoxicillin.safetyNotes.some((n) => n.startsWith('CONTRANDICATED')) &&
        amoxicillin.safetyNotes.some((n) => n.includes('beta-lactam')),
      amoxicillin?.safetyNotes.join(' | '));
    check('macrolide antibiotic remains eligible despite the beta-lactam allergy',
      azithromycin != null && azithromycin.contraindicated === false);

    // --- Final report --------------------------------------------------------
    const snapshotCount = await db.queryOne<{ count: string }>(`SELECT count(*)::text AS count FROM cpu.state_snapshot WHERE patient_id = $1`, [patientId]);
    check('state snapshots persisted per pass', Number(snapshotCount?.count ?? 0) >= 15, `snapshots=${snapshotCount?.count}`);

    console.log(`\n${failures === 0 ? 'BENCHMARK PASSED' : `BENCHMARK FAILED (${failures} assertion(s))`}`);
  } finally {
    try {
      await client.query('ROLLBACK');
    } finally {
      client.release();
    }
  }
}

main()
  .catch((error) => {
    failures += 1;
    console.error('\nBENCHMARK ERROR:', error);
  })
  .finally(async () => {
    await POOL.end();
    process.exit(failures === 0 ? 0 : 1);
  });
