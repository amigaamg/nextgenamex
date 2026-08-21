// =============================================================================
// AMEXAN Clinical CPU — R1/R2 respiratory vertical slice: paediatric overlay
// Proves the universal COUGH graph + PNEUMONIA slice adapts to a child:
//
//   • the PAEDIATRIC danger-sign questions (fast breathing, chest indrawing,
//     grunting, nasal flaring, poor feeding) SURFACE in the adaptive interview
//     for a child and an infant — safety-ranked probes grounded to Baby Nelson
//   • the SAME canonical question COUGH_PRODUCTIVITY is offered to a child with
//     the caregiver wording variant ("wet or dry") and to an infant with the
//     observable wording ("rattly and chesty") — one fact, age-adapted capture
//   • answering a danger sign captures a boolean fact that raises the
//     PHEN-PAEDIATRIC-PNEUMONIA-ALARM phenotype
//   • adult-facing probes (smoking pack-years etc.) do not fire for a child
//
// Runs inside a transaction and ROLLS BACK — the database stays pristine and
// the script is re-runnable. Exit code 0 = paediatric slice verified.
// =============================================================================

import { randomUUID } from 'node:crypto';
import { Db, createPool } from '../src/db.js';
import { ClinicalCPU } from '../src/runtime/ClinicalCPU.js';
import type { ClinicalRuntimeProjection, NextQuestion } from '../src/types.js';

const pool = createPool();

let failures = 0;
function check(label: string, ok: boolean, detail = ''): void {
  const marker = ok ? 'PASS' : 'FAIL';
  if (!ok) failures += 1;
  console.log(`  [${marker}] ${label}${detail ? ` — ${detail}` : ''}`);
}

function summary(p: ClinicalRuntimeProjection): string {
  return [
    `phen=${p.phenotypes.slice(0, 3).map((x) => `${x.phenotypeCode}:${x.score}`).join(',')}`,
    `q=${p.nextQuestions.map((q) => q.questionCode).join(',')}`,
  ].join(' | ');
}

// The adaptive selector only offers the top ~8 questions per pass. To reach a
// lower-ranked question we drive the interview: answer the top offered question
// with a benign value until the target appears (or the pass budget is spent).
const BENIGN_OPTION = /^(no|none|absent|clear|well|normal)$/i;
function benignAnswer(q: NextQuestion): string {
  if (q.options.length > 0) {
    const preferred = q.options.find((o) => BENIGN_OPTION.test(o.answerCode));
    return preferred?.answerCode ?? q.options[0].answerCode;
  }
  return q.responseType === 'numeric' ? '1' : 'none';
}

type SendEvent = (event: { type: string; payload: Record<string, unknown> }) => Promise<ClinicalRuntimeProjection>;

async function drive(
  send: SendEvent,
  predicate: (q: NextQuestion) => boolean,
  maxPasses = 20,
): Promise<ClinicalRuntimeProjection> {
  const projection = await send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
  return driveFrom(projection, send, predicate, maxPasses);
}

async function driveFrom(
  projection: ClinicalRuntimeProjection,
  send: SendEvent,
  predicate: (q: NextQuestion) => boolean,
  maxPasses = 20,
): Promise<ClinicalRuntimeProjection> {
  for (let i = 0; i < maxPasses; i++) {
    if (projection.nextQuestions.some(predicate)) return projection;
    const top = projection.nextQuestions[0];
    if (!top) return projection;
    projection = await send({
      type: 'QUESTION_ANSWERED',
      payload: { questionCode: top.questionCode, answerCode: benignAnswer(top) },
    });
  }
  return projection;
}

interface Session {
  patientId: string;
  encounterId: string;
  send: SendEvent;
}

async function newPatient(db: Db, monthsBeforeNow: number, gender: string, mrnTag: string): Promise<Session> {
  const birthDate = new Date(Date.now() - monthsBeforeNow * 30.44 * 86400000).toISOString().slice(0, 10);
  const personId = randomUUID();
  const patientId = randomUUID();
  await db.query(
    `INSERT INTO identity.person (id, status_code, sex_at_birth, birth_date, nationality_code)
     VALUES ($1, 'active', $2, $3, 'KE')`,
    [personId, gender, birthDate],
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
  const cpu = new ClinicalCPU(db);
  return {
    patientId,
    encounterId,
    send: (event) => cpu.process({ patientId, encounterId, event } as never),
  };
}

async function main(): Promise<void> {
  const client = await pool.connect();
  const db = new Db(client);

  try {
    await client.query('BEGIN');

    console.log('\nAMEXAN CLINICAL CPU — respiratory vertical slice: paediatric overlay');
    console.log('scenario A: 2-year-old, cough + fever + grunting (positive danger signs)\n');

    // --- Scenario A: 2-year-old with positive danger signs -------------------
    const child = await newPatient(db, 24, 'female', 'PAED-A');
    let projection = await child.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });

    check('cough activates the respiratory branch for a child', projection.nextQuestions.length > 0, summary(projection));

    const dangerOffered = projection.nextQuestions.filter((q) => q.questionCode.startsWith('PAEDIATRIC_'));
    check('paediatric danger-sign questions are offered for a child (safety-ranked, Baby Nelson grounding)',
      dangerOffered.some((q) => q.questionCode === 'PAEDIATRIC_GRUNTING' || q.questionCode === 'PAEDIATRIC_FAST_BREATHING'),
      dangerOffered.map((q) => q.questionCode).join(','));

    const adultProbes = projection.nextQuestions.filter((q) =>
      ['SMOKING_PACK_YEARS', 'SMOKING_STATUS', 'BIOMASS_EXPOSURE', 'OCCUPATIONAL_DUST'].includes(q.questionCode));
    check('adult-facing probes (smoking/occupational) do not fire for a child',
      adultProbes.length === 0, adultProbes.map((q) => q.questionCode).join(','));

    projection = await child.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    check('caregiver answer PRODUCTIVE resolves to the canonical fact',
      projection.capturedFacts.some((f) => f.factCode === 'COUGH_PRODUCTIVITY' && f.values[0]?.text === 'PRODUCTIVE'));

    projection = await child.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'YES' } });
    projection = await child.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'PAEDIATRIC_GRUNTING', answerCode: 'YES' } });
    check('answering PAEDIATRIC_GRUNTING captures a boolean danger-sign fact',
      projection.capturedFacts.some((f) => f.factCode === 'GRUNTING' && f.values[0]?.boolean === true),
      projection.capturedFacts.map((f) => `${f.factCode}=${f.values[0]?.boolean ?? f.values[0]?.text}`).join(','));

    check('paediatric pneumonia danger-sign phenotype rises (Baby Nelson p166 grounding)',
      projection.phenotypes.some((p) => p.phenotypeCode === 'PHEN-PAEDIATRIC-PNEUMONIA-ALARM' && p.score > 0),
      projection.phenotypes.slice(0, 4).map((p) => `${p.phenotypeCode}:${p.score}`).join(','));

    check('pneumonia remains the leading differential for a child with cough+fever+grunting',
      projection.differentials[0]?.conditionCode === 'PNEUMONIA' || projection.differentials[0]?.name === 'Pneumonia',
      projection.differentials.slice(0, 3).map((d) => `${d.name}:${d.compatibility}`).join(','));

    const coherent = projection.phenotypes.map((p) => p.phenotypeCode).join(',');
    check('no crash and the state is coherent after the paediatric interview', coherent.length > 0, coherent.slice(0, 120));

    // --- Scenario B: 2-year-old — caregiver wording variant ------------------
    console.log('\nscenario B: 2-year-old — COUGH_PRODUCTIVITY uses the paediatric wording variant');
    const childB = await newPatient(db, 24, 'male', 'PAED-B');
    const varChild = await drive(childB.send, (q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    const childQ = varChild.nextQuestions.find((q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    check('COUGH_PRODUCTIVITY offered to a child with caregiver "wet or dry" wording',
      !!childQ && childQ.text.toLowerCase().includes('wet'),
      childQ ? `text="${childQ.text}"` : 'question never offered within drive budget');

    // --- Scenario C: 6-month-old — observable wording variant ----------------
    console.log('\nscenario C: 6-month-old infant — COUGH_PRODUCTIVITY uses the observable wording variant');
    const infant = await newPatient(db, 6, 'female', 'PAED-C');
    const infantFirst = await infant.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    const dangerInfant = infantFirst.nextQuestions.filter((q) => q.questionCode.startsWith('PAEDIATRIC_'));
    check('paediatric danger-sign questions also offered for the infant',
      dangerInfant.length > 0, dangerInfant.map((q) => q.questionCode).join(','));

    const varInfant = await driveFrom(infantFirst, infant.send, (q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    const infantQ = varInfant.nextQuestions.find((q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    check('COUGH_PRODUCTIVITY offered to an infant with observable "rattly and chesty" wording',
      !!infantQ && /rattly|chesty|hacking/.test(infantQ.text),
      infantQ ? `text="${infantQ.text}"` : 'question never offered within drive budget');

    // --- Scenario D: management — age-aware protocol + weight-based dosing ----
    console.log('\nscenario D: 2-year-old with cough + fever + chest indrawing — management slice');
    const childD = await newPatient(db, 24, 'female', 'PAED-D');
    let projD = await childD.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    projD = await driveFrom(projD, childD.send, (q) => q.questionCode === 'PAEDIATRIC_CHEST_INDRAWING');
    projD = await childD.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'PAEDIATRIC_CHEST_INDRAWING', answerCode: 'YES' } });
    projD = await driveFrom(projD, childD.send, (q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    projD = await childD.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    projD = await driveFrom(projD, childD.send, (q) => q.questionCode === 'FEVER_PRESENT');
    projD = await childD.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'YES' } });
    projD = await childD.send({ type: 'FACT_CAPTURED', payload: { factCode: 'BODY_WEIGHT_KG', value: 12, unit: 'kg' } });
    projD = await childD.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'SPO2', value: 94 } });

    check('age-aware protocol selection: a CHILD activates PROT-PNEUMONIA-PAED (not the adult CAP pathway)',
      projD.protocol?.protocolCode === 'PROT-PNEUMONIA-PAED', projD.protocol?.protocolCode ?? 'none');

    const paedProtocolSteps = projD.protocol?.steps.length ?? 0;
    check('paediatric pneumonia protocol is a full 12-step management pathway',
      paedProtocolSteps === 12, String(paedProtocolSteps));

    const amox = projD.treatment.find((t) => t.medicationCode === 'MED-AMOXICILLIN');
    check('weight-based amoxicillin dose is COMPUTED for the child (12 kg × 50-90 mg/kg = 600-1080 mg/dose)',
      !!amox && amox.computedDose === '600-1080 mg per dose',
      amox ? `computedDose="${amox.computedDose}"` : 'amoxicillin not offered');

    check('real source-grounded dose expression replaces the VERIFY placeholder',
      !!amox && amox.doseExpression.includes('50-90 mg/kg') && amox.verified,
      amox ? `expr="${amox.doseExpression}" verified=${amox.verified}` : 'no amoxicillin');

    check('monitoring for the paediatric protocol includes SpO2/RR/work-of-breathing',
      ['MON-SPO2', 'MON-RR', 'MON-WOB'].every((code) => projD.monitoring.some((m) => m.monitoringCode === code)),
      projD.monitoring.map((m) => m.monitoringCode).join(','));

    // --- Scenario E: adult isolation — age-aware selection must NOT regress -----
    console.log('\nscenario E: 40-year-old with the same pneumonia picture — adult isolation');
    const adult = await newPatient(db, 480, 'male', 'PAED-E'); // 40 years
    let projE = await adult.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    projE = await driveFrom(projE, adult.send, (q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    projE = await adult.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    projE = await adult.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'YES' } });
    projE = await adult.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'SPO2', value: 94 } });
    check('age-aware protocol selection: an ADULT still activates PROT-CAP-ADULT',
      projE.protocol?.protocolCode === 'PROT-CAP-ADULT', projE.protocol?.protocolCode ?? 'none');
    check('paediatric danger-sign questions do NOT fire for the adult',
      !projE.nextQuestions.some((q) => q.questionCode.startsWith('PAEDIATRIC_')),
      projE.nextQuestions.map((q) => q.questionCode).join(','));
    check('adult amoxicillin dose retains its verification requirement (no paediatric shortcut)',
      projE.treatment.some((t) => t.medicationCode === 'MED-AMOXICILLIN' && !t.verified),
      projE.treatment.map((t) => `${t.medicationCode}:${t.verified}`).join(','));

    // --- Scenario F: child with wheeze — asthma pathway -----------------------
    console.log('\nscenario F: 6-year-old with recurrent wheeze — asthma pathway (both populations)');
    const childF = await newPatient(db, 72, 'female', 'PAED-F');
    let projF = await childF.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    projF = await driveFrom(projF, childF.send, (q) => q.questionCode === 'WHEEZE_PRESENT');
    projF = await childF.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WHEEZE_PRESENT', answerCode: 'YES' } });
    projF = await childF.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'NON_PRODUCTIVE' } });
    projF = await driveFrom(projF, childF.send, (q) => q.questionCode === 'COUGH_TRIGGERS');
    projF = await childF.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_TRIGGERS', answerCode: 'EXERCISE' } });
    projF = await driveFrom(projF, childF.send, (q) => q.questionCode === 'COUGH_TIMING');
    projF = await childF.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_TIMING', answerCode: 'NIGHT' } });
    projF = await childF.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'NO' } });
    projF = await childF.send({ type: 'FACT_CAPTURED', payload: { factCode: 'DYSPNOEA_PRESENT', value: 'YES' } });
    projF = await childF.send({ type: 'FACT_CAPTURED', payload: { factCode: 'BODY_WEIGHT_KG', value: 20, unit: 'kg' } });
    projF = await childF.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'SPO2', value: 96 } });

    check('wheeze + exercise + nocturnal facts elevate ASTHMA in the differential',
      projF.differentials.some((d) => d.conditionCode === 'ASTHMA'),
      projF.differentials.slice(0, 4).map((d) => `${d.name}:${d.compatibility}`).join(','));

    check('child with asthma activates PROT-ASTHMA-ACUTE (population both)',
      projF.protocol?.protocolCode === 'PROT-ASTHMA-ACUTE', projF.protocol?.protocolCode ?? 'none');

    const asthmaSteps = projF.protocol?.steps.length ?? 0;
    check('asthma protocol is a full 12-step acute pathway (severity → treatment → escalation → action plan)',
      asthmaSteps === 12, String(asthmaSteps));

    const salb = projF.treatment.find((t) => t.medicationCode === 'MED-SALBUTAMOL');
    check('SABA (salbutamol) offered for the asthma exacerbation with a grounded dose',
      !!salb && salb.verified && salb.doseExpression.includes('2.5-5 mg'),
      salb ? `expr="${salb.doseExpression}" verified=${salb.verified}` : 'salbutamol not offered');

    const pred = projF.treatment.find((t) => t.medicationCode === 'MED-PREDNISOLONE');
    check('weight-based prednisolone dose is COMPUTED for the child (20 kg × 1-2 mg/kg = 20-40 mg)',
      !!pred && pred.computedDose === '20-40 mg per dose',
      pred ? `computedDose="${pred.computedDose}"` : 'prednisolone not offered');

    check('asthma monitoring includes peak expiratory flow',
      projF.monitoring.some((m) => m.monitoringCode === 'MON-PEF'),
      projF.monitoring.map((m) => m.monitoringCode).join(','));

    check('asthma education includes the written action plan',
      projF.education.some((e) => e.educationCode === 'EDU-ASTHMA-ACTION-PLAN'),
      projF.education.map((e) => e.educationCode).join(','));

    const asthmaPEFStep = projF.protocol?.steps.find((s) => s.stepCode === 'STEP-02');
    check('severity assessment step uses the PEF/Speech severity grid grounding',
      !!asthmaPEFStep && asthmaPEFStep.actions.some((a) => a.actionCode === 'MON-PEF'),
      asthmaPEFStep ? asthmaPEFStep.actions.map((a) => a.actionCode).join(',') : 'STEP-02 not present');

    // --- Scenario G: adult with wheeze — asthma pathway (both populations) -----
    console.log('\nscenario G: 35-year-old with recurrent wheeze — asthma pathway keeps adult isolation');
    const adultG = await newPatient(db, 420, 'male', 'PAED-G'); // 35 years
    let projG = await adultG.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    projG = await driveFrom(projG, adultG.send, (q) => q.questionCode === 'WHEEZE_PRESENT');
    projG = await adultG.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WHEEZE_PRESENT', answerCode: 'YES' } });
    projG = await adultG.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'NON_PRODUCTIVE' } });
    projG = await driveFrom(projG, adultG.send, (q) => q.questionCode === 'COUGH_TRIGGERS');
    projG = await adultG.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_TRIGGERS', answerCode: 'EXERCISE' } });
    projG = await adultG.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'NO' } });
    projG = await adultG.send({ type: 'FACT_CAPTURED', payload: { factCode: 'DYSPNOEA_PRESENT', value: 'YES' } });
    projG = await adultG.send({ type: 'FACT_CAPTURED', payload: { factCode: 'BODY_WEIGHT_KG', value: 70, unit: 'kg' } });
    projG = await adultG.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'SPO2', value: 95 } });

    check('adult with asthma also activates PROT-ASTHMA-ACUTE (both-population protocol)',
      projG.protocol?.protocolCode === 'PROT-ASTHMA-ACUTE', projG.protocol?.protocolCode ?? 'none');

    const salbG = projG.treatment.find((t) => t.medicationCode === 'MED-SALBUTAMOL');
    check('adult SABA dose resolves from the adult dose row (no paediatric shortcut)',
      !!salbG && salbG.doseExpression.includes('2.5-5 mg') && salbG.verified,
      salbG ? `expr="${salbG.doseExpression}" verified=${salbG.verified}` : 'salbutamol not offered');

    check('paediatric danger-sign questions do NOT fire for the adult asthma patient',
      !projG.nextQuestions.some((q) => q.questionCode.startsWith('PAEDIATRIC_')),
      projG.nextQuestions.map((q) => q.questionCode).join(','));

    // --- Scenario H: adult chronic smoker — COPD exacerbation + GOLD scoring -----
    console.log('\nscenario H: 58-year-old chronic smoker — COPD exacerbation (GOLD severity + NIV escalation)');
    const copd = await newPatient(db, 696, 'male', 'PAED-H'); // 58 years
    let projH = await copd.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    projH = await driveFrom(projH, copd.send, (q) => q.questionCode === 'COUGH_PRODUCTIVITY');
    projH = await copd.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'COUGH_PRODUCTIVITY', answerCode: 'PRODUCTIVE' } });
    projH = await driveFrom(projH, copd.send, (q) => q.questionCode === 'WHEEZE_PRESENT');
    projH = await copd.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'WHEEZE_PRESENT', answerCode: 'YES' } });
    projH = await copd.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'NO' } });
    projH = await copd.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'DYSPNOEA_PRESENT', answerCode: 'YES' } });
    projH = await driveFrom(projH, copd.send, (q) => q.questionCode === 'SMOKING_STATUS');
    projH = await copd.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'SMOKING_STATUS', answerCode: 'CURRENT' } });
    projH = await copd.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'SMOKING_PACK_YEARS', answerCode: '40' } });
    projH = await copd.send({ type: 'FACT_CAPTURED', payload: { factCode: 'COUGH_DURATION_DAYS', value: 120 } });
    projH = await copd.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'SPO2', value: 88 } });
    projH = await copd.send({ type: 'FACT_CAPTURED', payload: { factCode: 'FEV1_FVC_RATIO', value: 0.55 } });
    projH = await copd.send({ type: 'FACT_CAPTURED', payload: { factCode: 'FEV1_PERCENT', value: 35 } });
    projH = await copd.send({ type: 'FACT_CAPTURED', payload: { factCode: 'BODY_WEIGHT_KG', value: 70, unit: 'kg' } });

    check('chronic productive cough + wheeze + smoking elevates COPD / COPD-EXACERBATION in the differential',
      projH.differentials.some((d) => d.conditionCode === 'COND-COPD' || d.conditionCode === 'COND-COPD-EXACERBATION'),
      projH.differentials.slice(0, 4).map((d) => `${d.name}:${d.compatibility}`).join(','));

    check('adult COPD exacerbation activates PROT-COPD-EXACERBATION (adult pathway)',
      projH.protocol?.protocolCode === 'PROT-COPD-EXACERBATION', projH.protocol?.protocolCode ?? 'none');

    const copdSteps = projH.protocol?.steps.length ?? 0;
    check('COPD exacerbation protocol is a full 12-step pathway (ABC → O2 → ABG → treatment → NIV → plan)',
      copdSteps === 12, String(copdSteps));

    const gold = projH.severityScores.find((s) => s.scoreCode === 'SCORE-GOLD');
    check('GOLD score evaluates from spirometry facts (FEV1/FVC 0.55 + FEV1 35% → GOLD 3 Severe, score 3)',
      !!gold && gold.score === 3 && (gold.severityLabel?.includes('Severe') ?? false),
      gold ? `score=${gold.score} label="${gold.severityLabel}" disp="${gold.disposition}"` : 'SCORE-GOLD not evaluated');

    const goldComponents = gold?.components.filter((c) => c.matched).map((c) => c.componentCode) ?? [];
    check('exactly the GOLD-3 band matched (mutually-exclusive grade components)',
      goldComponents.length === 1 && goldComponents[0] === 'GOLD-3',
      goldComponents.join(','));

    const salbH = projH.treatment.find((t) => t.medicationCode === 'MED-SALBUTAMOL');
    check('nebulised salbutamol offered for the exacerbation with a verified adult dose',
      !!salbH && salbH.verified && salbH.doseExpression.includes('2.5-5 mg'),
      salbH ? `expr="${salbH.doseExpression}" verified=${salbH.verified}` : 'salbutamol not offered');

    const ipraH = projH.treatment.find((t) => t.medicationCode === 'MED-IPRATROPIUM');
    check('nebulised ipratropium offered alongside salbutamol for the acute exacerbation',
      !!ipraH && ipraH.verified && ipraH.doseExpression.includes('250-500 mcg'),
      ipraH ? `expr="${ipraH.doseExpression}" verified=${ipraH.verified}` : 'ipratropium not offered');

    const predH = projH.treatment.find((t) => t.medicationCode === 'MED-PREDNISOLONE');
    check('systemic prednisolone offered for the exacerbation (verified adult dose)',
      !!predH && predH.verified, predH ? `expr="${predH.doseExpression}"` : 'prednisolone not offered');

    const abgAction = projH.protocol?.steps.find((s) => s.stepCode === 'STEP-04');
    check('ABG investigation step present to classify respiratory failure (Type I vs II)',
      !!abgAction && abgAction.actions.some((a) => a.actionCode === 'INV-ABG'),
      abgAction ? abgAction.actions.map((a) => a.actionCode).join(',') : 'STEP-04 not present');

    const o2Action = projH.protocol?.steps.find((s) => s.stepCode === 'STEP-03');
    check('controlled oxygen advice with 88-92% target (Venturi) when hypercapnia risk',
      !!o2Action && o2Action.actions.some((a) => a.actionCode === 'ADV-COPD-TARGETED-O2' && /88-92%/.test(a.detail ?? '')),
      o2Action ? o2Action.actions.map((a) => `${a.actionCode}:${a.detail}`).join(' | ') : 'STEP-03 not present');

    const nivAction = projH.protocol?.steps.find((s) => s.stepCode === 'STEP-09');
    check('NIV escalation step present (ABG pH<7.35 + PaCO2>6.5 → NIV, KCR-0018 grounding)',
      !!nivAction && nivAction.actions.some((a) => a.actionCode === 'REF-NIV'),
      nivAction ? nivAction.actions.map((a) => a.actionCode).join(',') : 'STEP-09 not present');

    check('COPD monitoring includes SpO2 with 88-92% target and RR',
      projH.monitoring.some((m) => m.monitoringCode === 'MON-SPO2' && /88-92%/.test(m.frequency ?? '')) &&
      projH.monitoring.some((m) => m.monitoringCode === 'MON-RR'),
      projH.monitoring.map((m) => `${m.monitoringCode}:${m.frequency}`).join(','));

    check('COPD education includes smoking cessation and the exacerbation action plan',
      projH.education.some((e) => e.educationCode === 'EDU-COPD-SMOKING-CESSATION') &&
      projH.education.some((e) => e.educationCode === 'EDU-COPD-EXACERBATION-PLAN'),
      projH.education.map((e) => e.educationCode).join(','));

    check('paediatric danger-sign questions do NOT fire for the adult COPD patient',
      !projH.nextQuestions.some((q) => q.questionCode.startsWith('PAEDIATRIC_')),
      projH.nextQuestions.map((q) => q.questionCode).join(','));

    // --- Scenario I: adult heart failure decompensation (NYHA IV + pathway) ------
    console.log('\nscenario I: 68-year-old with dyspnoea + orthopnoea + PND + leg swelling — heart failure decompensation (NYHA IV)');
    const hf = await newPatient(db, 816, 'male', 'PAED-I'); // 68 years
    let projI = await hf.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'dyspnoea' } });
    projI = await hf.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'DYSPNOEA_PRESENT', answerCode: 'YES' } });
    projI = await hf.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'DYSPNOEA_SEVERITY', answerCode: 'AT_REST' } });
    projI = await hf.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'ORTHOPNOEA_ASK', answerCode: 'YES' } });
    projI = await hf.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'PND_ASK', answerCode: 'YES' } });
    projI = await hf.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'LEG_SWELLING_ASK', answerCode: 'YES' } });
    projI = await hf.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'CRACKLES', value: true } });
    projI = await hf.send({ type: 'EXAM_FINDING_CAPTURED', payload: { factCode: 'JUGULAR_VENOUS_DISTENTION', value: true } });
    projI = await hf.send({ type: 'QUESTION_ANSWERED', payload: { questionCode: 'FEVER_PRESENT', answerCode: 'NO' } });

    check('PHEN-CHF-CONGESTIVE fires from dyspnoea + orthopnoea + PND + oedema + crackles',
      projI.phenotypes.some((p) => p.phenotypeCode === 'PHEN-CHF-CONGESTIVE'),
      projI.phenotypes.slice(0, 3).map((p) => `${p.phenotypeCode}:${p.score}`).join(','));

    check('heart failure decompensation + heart failure are the top-2 differentials',
      projI.differentials.length >= 2 &&
        projI.differentials[0].conditionCode === 'COND-HF-DECOMPENSATION' &&
        projI.differentials[1].conditionCode === 'HEART-FAILURE',
      projI.differentials.slice(0, 4).map((d) => `${d.conditionCode}:${d.compatibility}`).join(','));

    check('adult HF decompensation activates PROT-HF-DECOMP (12-step adult pathway)',
      projI.protocol?.protocolCode === 'PROT-HF-DECOMP' && (projI.protocol.steps.length ?? 0) === 12,
      `${projI.protocol?.protocolCode ?? 'none'} steps=${projI.protocol?.steps.length}`);

    const nyha = projI.severityScores.find((s) => s.scoreCode === 'SCORE-NYHA');
    check('NYHA score evaluates to IV (score 4) from dyspnoea at rest',
      !!nyha && nyha.score === 4 && (nyha.severityLabel?.includes('NYHA IV') ?? false),
      nyha ? `score=${nyha.score} label="${nyha.severityLabel}" disp="${nyha.disposition}"` : 'SCORE-NYHA not evaluated');

    const nyhaComponents = nyha?.components.filter((c) => c.matched).map((c) => c.componentCode) ?? [];
    check('exactly the NYHA-4 grade matched (mutually-exclusive functional bands)',
      nyhaComponents.length === 1 && nyhaComponents[0] === 'NYHA-4',
      nyhaComponents.join(','));

    check('ECG + echo + BNP recommended for the heart failure differential',
      projI.investigations.some((i) => i.investigationCode === 'INV-ECG') &&
      projI.investigations.some((i) => i.investigationCode === 'INV-ECHO') &&
      projI.investigations.some((i) => i.investigationCode === 'INV-BNP'),
      projI.investigations.map((i) => i.investigationCode).join(','));

    check('monitoring includes daily weight + SpO2 (decongestion tracking)',
      projI.monitoring.some((m) => m.monitoringCode === 'MON-WEIGHT') &&
      projI.monitoring.some((m) => m.monitoringCode === 'MON-SPO2'),
      projI.monitoring.map((m) => m.monitoringCode).join(','));

    check('heart failure education offered (self-care + symptom recognition)',
      projI.education.some((e) => e.educationCode === 'EDU-HF-SELF-CARE') &&
      projI.education.some((e) => e.educationCode === 'EDU-HF-SYMPTOM-RECOGNITION'),
      projI.education.map((e) => e.educationCode).join(','));

    check('advice-level diuretic + ACE appear in the decompensation pathway (no dose rows)',
      !!projI.protocol?.steps.find((s) => s.stepCode === 'STEP-08')?.actions.some((a) => a.actionCode === 'ADV-HF-DIURETIC' || a.actionCode === 'ADV-HF-ACE'),
      projI.protocol?.steps.find((s) => s.stepCode === 'STEP-08')?.actions.map((a) => a.actionCode).join(',') ?? 'STEP-08 not present');

    check('paediatric danger-sign questions do NOT fire for the adult heart failure patient',
      !projI.nextQuestions.some((q) => q.questionCode.startsWith('PAEDIATRIC_')),
      projI.nextQuestions.map((q) => q.questionCode).join(','));

    console.log(failures === 0 ? '\nPAEDIATRIC SLICE VERIFIED' : `\n${failures} FAILURES`);
    await client.query('ROLLBACK');
  } finally {
    client.release();
    await pool.end();
  }
}

main()
  .catch((err) => {
    failures += 1;
    console.error('\nPAEDIATRIC SLICE ERROR:', err);
  })
  .finally(() => {
    process.exit(failures === 0 ? 0 : 1);
  });
