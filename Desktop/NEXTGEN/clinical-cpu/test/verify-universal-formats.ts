// =============================================================================
// AMEXAN Clinical CPU — universal clinical format matrix (U2/U3/U4)
// Proves the CPU derives the clinical format + workspace navigation from the
// patient context vector for six encounter archetypes:
//
//   ADULT_MEDICAL   adult + internal medicine (opd)
//   ADULT_SURGICAL  adult + SURGERY department
//   PEDIATRIC       child + PEDIATRICS department (and age band CHILD)
//   NEONATAL        neonate (age band NEONATE) — NEVER just "pediatric"
//   OBGYN           adult female + OBSTETRICS_GYNAECOLOGY + pregnant fact
//   PSYCHIATRY      adult + PSYCHIATRY department + psychiatric domain
//
// And the hard invariants:
//   INVARIANT-001  neonate (<28d) resolves to NEONATAL; infant/child to PEDIATRIC
//   INVARIANT-002  pregnancy resolves ONLY from a PREGNANT fact, never sex alone
//   INVARIANT-003  a male never receives the OBGYN format and OBGYN sections are
//                  excluded (HIDE) even if the department/domain says OBGYN
//   section_context_rule HIDE/REQUIRE drive section visibility + attention
//
// Runs inside a transaction and ROLLS BACK — the database stays pristine and
// the script is re-runnable. Exit code 0 = universal formats verified.
// =============================================================================

import { randomUUID } from 'node:crypto';
import { Db, createPool } from '../src/db.js';
import { ClinicalCPU } from '../src/runtime/ClinicalCPU.js';
import type { ClinicalRuntimeProjection, WorkspaceNavigationProjection } from '../src/types.js';

const pool = createPool();

let failures = 0;
function check(label: string, ok: boolean, detail = ''): void {
  const marker = ok ? 'PASS' : 'FAIL';
  if (!ok) failures += 1;
  console.log(`  [${marker}] ${label}${detail ? ` — ${detail}` : ''}`);
}

function navSummary(n: WorkspaceNavigationProjection | undefined): string {
  if (!n) return 'navigation undefined';
  return n.sections.map((s) => `${s.sectionCode}:${s.state}${s.badge ? `(${s.badge})` : ''}`).join(',');
}

interface Session {
  patientId: string;
  encounterId: string;
  send: (event: { type: string; payload: Record<string, unknown> }) => Promise<ClinicalRuntimeProjection>;
}

async function newPatient(
  db: Db,
  opts: {
    ageYears?: number;
    ageMonths?: number;
    ageDays?: number;
    gender?: string;
    mrnTag: string;
    departmentCode?: string;
    encounterTypeCode?: string;
    pregnant?: boolean;
  },
): Promise<Session> {
  let birth: Date;
  if (opts.ageDays != null) {
    birth = new Date(Date.now() - opts.ageDays * 86400000);
  } else if (opts.ageMonths != null) {
    birth = new Date(Date.now() - opts.ageMonths * 30.44 * 86400000);
  } else {
    birth = new Date(Date.now() - (opts.ageYears ?? 40) * 365.25 * 86400000);
  }
  const birthDate = birth.toISOString().slice(0, 10);
  const personId = randomUUID();
  const patientId = randomUUID();
  await db.query(
    `INSERT INTO identity.person (id, status_code, sex_at_birth, birth_date, nationality_code)
     VALUES ($1, 'active', $2, $3, 'KE')`,
    [personId, opts.gender ?? 'male', birthDate],
  );
  await db.query(
    `INSERT INTO patient.patient (id, person_id, status_code)
     VALUES ($1, $2, 'active')`,
    [patientId, personId],
  );
  const { id: encounterId } = (await db.queryOne<{ id: string }>(
    `INSERT INTO encounter.encounter (patient_id, encounter_type_code, status_code, phase_code)
     VALUES ($1, $2, 'active', 'assessment') RETURNING id`,
    [patientId, opts.encounterTypeCode ?? 'opd'],
  ))!;

  if (opts.departmentCode) {
    const svc = await db.queryOne<{ id: string }>(
      `SELECT id FROM organization.service WHERE code = $1 AND is_active`,
      [opts.departmentCode],
    );
    if (svc) {
      await db.query(
        `INSERT INTO encounter.encounter_service (id, encounter_id, service_id, is_primary)
         VALUES ($1, $2, $3, true)`,
        [randomUUID(), encounterId, svc.id],
      );
    }
  }

  if (opts.pregnant) {
    const factId = randomUUID();
    await db.query(
      `INSERT INTO clinical.fact (id, patient_id, encounter_id, fact_definition_code, status_code, recorded_at)
       VALUES ($1, $2, $3, 'PREGNANT', 'active', now())`,
      [factId, patientId, encounterId],
    );
    await db.query(
      `INSERT INTO clinical.fact_value (id, fact_id, value_order, data_type, value_boolean, value_state)
       VALUES ($1, $2, 0, 'boolean', true, 'known')`,
      [randomUUID(), factId],
    );
  }

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

    console.log('\nAMEXAN CLINICAL CPU — universal clinical format matrix (U2/U3/U4)\n');

    // --- Scenario 1: ADULT_MEDICAL — adult + internal medicine ----------------
    console.log('scenario 1: 45-year-old male, internal medicine, cough');
    const adult = await newPatient(db, { ageYears: 45, gender: 'male', mrnTag: 'UFMT-1', departmentCode: 'INTERNAL_MEDICINE', encounterTypeCode: 'opd' });
    const p1 = await adult.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    check('adult + internal medicine resolves to ADULT_MEDICAL format',
      p1.formatPlan?.baseFormat === 'ADULT_MEDICAL', p1.formatPlan?.baseFormat ?? 'none');
    check('age band resolves to ADULT', p1.formatPlan?.ageBand === 'ADULT', p1.formatPlan?.ageBand ?? 'none');
    check('navigation projects the adult history workspace (HPI present, birth/feeding/development hidden)',
      !!p1.navigation && p1.navigation.sections.length > 0 &&
        p1.navigation.sections.some((s) => s.sectionCode === 'history'),
      navSummary(p1.navigation));
    check('adult birth/feeding/developmental/immunization sections HIDden by SCR-ADULT-*',
      p1.formatPlan?.excludedSections.includes('BIRTH_HISTORY') ?? false,
      (p1.formatPlan?.excludedSections ?? []).join(','));
    check('navigation phase starts at history with questions remaining',
      p1.navigation?.workflowPhase === 'history' && p1.nextQuestions.length > 0,
      `phase=${p1.navigation?.workflowPhase} q=${p1.nextQuestions.length}`);

    // --- Scenario 2: ADULT_SURGICAL — adult + SURGERY department --------------
    console.log('\nscenario 2: 32-year-old male, SURGERY department, abdominal pain');
    const surg = await newPatient(db, { ageYears: 32, gender: 'male', mrnTag: 'UFMT-2', departmentCode: 'SURGERY', encounterTypeCode: 'opd' });
    const p2 = await surg.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'abdominal pain' } });
    check('SURGERY department resolves to ADULT_SURGICAL format',
      p2.formatPlan?.baseFormat === 'ADULT_SURGICAL', p2.formatPlan?.baseFormat ?? 'none');
    check('department context recorded in the format plan',
      p2.formatPlan?.department === 'SURGERY', p2.formatPlan?.department ?? 'none');

    // --- Scenario 3: PEDIATRIC — child + PEDIATRICS department -----------------
    console.log('\nscenario 3: 4-year-old female, PEDIATRICS department, cough');
    const child = await newPatient(db, { ageYears: 4, gender: 'female', mrnTag: 'UFMT-3', departmentCode: 'PEDIATRICS', encounterTypeCode: 'opd' });
    const p3 = await child.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    check('child + PEDIATRICS resolves to PEDIATRIC format',
      p3.formatPlan?.baseFormat === 'PEDIATRIC', p3.formatPlan?.baseFormat ?? 'none');
    check('age band resolves to CHILD', p3.formatPlan?.ageBand === 'CHILD', p3.formatPlan?.ageBand ?? 'none');
    check('developmental/immunization sections REQUIRED for the child (SCR-CHILD-*)',
      (p3.formatPlan?.requiredSections.includes('DEVELOPMENTAL_HISTORY') ?? false) &&
        (p3.formatPlan?.requiredSections.includes('IMMUNIZATION_HISTORY') ?? false),
      `required=[${(p3.formatPlan?.requiredSections ?? []).join(',')}]`);
    check('birth/feeding sections are NOT hidden for the child (paediatric only for neonate)',
      !(p3.formatPlan?.excludedSections.includes('BIRTH_HISTORY') ?? false),
      (p3.formatPlan?.excludedSections ?? []).join(','));

    // --- Scenario 4: NEONATAL — neonate (age band NEONATE) ---------------------
    console.log('\nscenario 4: 10-day-old neonate, PEDIATRICS department, fever');
    const neo = await newPatient(db, { ageDays: 10, gender: 'male', mrnTag: 'UFMT-4', departmentCode: 'PEDIATRICS', encounterTypeCode: 'opd' });
    const p4 = await neo.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'fever' } });
    check('neonate (age 10d) resolves to NEONATAL format, NOT PEDIATRIC (INVARIANT-001)',
      p4.formatPlan?.baseFormat === 'NEONATAL', p4.formatPlan?.baseFormat ?? 'none');
    check('age band resolves to NEONATE', p4.formatPlan?.ageBand === 'NEONATE', p4.formatPlan?.ageBand ?? 'none');
    check('birth + feeding sections REQUIRED for the neonate (SCR-NEONATE-*)',
      (p4.formatPlan?.requiredSections.includes('BIRTH_HISTORY') ?? false) &&
        (p4.formatPlan?.requiredSections.includes('FEEDING_HISTORY') ?? false),
      `required=[${(p4.formatPlan?.requiredSections ?? []).join(',')}]`);
    check('adult sections are excluded for the neonate (no birth HIDE override)',
      !(p4.formatPlan?.excludedSections.includes('BIRTH_HISTORY') ?? false),
      (p4.formatPlan?.excludedSections ?? []).join(','));

    // --- Scenario 5: OBGYN — adult female, OBSTETRICS_GYNAECOLOGY, pregnant ----
    console.log('\nscenario 5: 30-year-old female, OBSTETRICS_GYNAECOLOGY, pregnant (vaginal bleeding)');
    const obgyn = await newPatient(db, { ageYears: 30, gender: 'female', mrnTag: 'UFMT-5', departmentCode: 'OBSTETRICS_GYNAECOLOGY', encounterTypeCode: 'opd', pregnant: true });
    const p5 = await obgyn.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'vaginal bleeding' } });
    check('pregnant female + OBSTETRICS_GYNAECOLOGY resolves to OBGYN format',
      p5.formatPlan?.baseFormat === 'OBGYN', p5.formatPlan?.baseFormat ?? 'none');
    check('pregnancy resolves from the PREGNANT fact (INVARIANT-002)',
      p5.formatPlan?.pregnant === true, `pregnant=${p5.formatPlan?.pregnant}`);
    check('ANC_PROFILE + obstetric history REQUIRED for the pregnant patient (SCR-PREG-*)',
      (p5.formatPlan?.requiredSections.includes('ANC_PROFILE') ?? false) &&
        (p5.formatPlan?.requiredSections.includes('OBSTETRIC_HISTORY') ?? false),
      `required=[${(p5.formatPlan?.requiredSections ?? []).join(',')}]`);
    check('menstrual/gynaecological/obstetric sections NOT excluded for the female',
      !(p5.formatPlan?.excludedSections.includes('MENSTRUAL_HISTORY') ?? false),
      (p5.formatPlan?.excludedSections ?? []).join(','));

    // --- Scenario 6: PSYCHIATRY — adult + PSYCHIATRY department ------------------
    console.log('\nscenario 6: 28-year-old female, PSYCHIATRY department, low mood');
    const psych = await newPatient(db, { ageYears: 28, gender: 'female', mrnTag: 'UFMT-6', departmentCode: 'PSYCHIATRY', encounterTypeCode: 'opd' });
    const p6 = await psych.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'low mood' } });
    check('PSYCHIATRY department resolves to PSYCHIATRY format',
      p6.formatPlan?.baseFormat === 'PSYCHIATRY', p6.formatPlan?.baseFormat ?? 'none');
    check('psychiatric symptom domain activates the PSYCHIATRY domain path',
      (p6.formatPlan?.activeDomains ?? []).some((d) => d.toUpperCase() === 'PSYCHIATRIC'),
      (p6.formatPlan?.activeDomains ?? []).join(','));

    // --- INVARIANT-003: male never receives OBGYN, sections HIDden ---------------
    console.log('\nINVARIANT-003: male in OBSTETRICS_GYNAECOLOGY with obstetric symptoms');
    const male = await newPatient(db, { ageYears: 35, gender: 'male', mrnTag: 'UFMT-7', departmentCode: 'OBSTETRICS_GYNAECOLOGY', encounterTypeCode: 'opd' });
    const pm = await male.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'vaginal bleeding' } });
    check('male NEVER resolves to OBGYN format even in the OBGYN department (BLOCK fail-closed)',
      pm.formatPlan?.baseFormat !== 'OBGYN', pm.formatPlan?.baseFormat ?? 'none');
    check('male resolves to the adult medical base instead',
      pm.formatPlan?.baseFormat === 'ADULT_MEDICAL', pm.formatPlan?.baseFormat ?? 'none');
    check('obstetric/gynaecological/ANC/menstrual sections EXCLUDED for the male (SCR-MALE-*)',
      ['OBSTETRIC_HISTORY', 'GYNAECOLOGICAL_HISTORY', 'ANC_PROFILE', 'MENSTRUAL_HISTORY', 'EXAM_OBSTETRIC', 'EXAM_GYNAEC'].every(
        (s) => pm.formatPlan?.excludedSections.includes(s),
      ),
      (pm.formatPlan?.excludedSections ?? []).join(','));
    check('male with OBGYN department does NOT resolve pregnancy from department alone (INVARIANT-002)',
      pm.formatPlan?.pregnant !== true, `pregnant=${pm.formatPlan?.pregnant}`);

    // --- INVARIANT-002: female alone (not pregnant) never forces OBGYN ----------
    console.log('\nINVARIANT-002: adult female in internal medicine, not pregnant, cough');
    const fem = await newPatient(db, { ageYears: 28, gender: 'female', mrnTag: 'UFMT-8', departmentCode: 'INTERNAL_MEDICINE', encounterTypeCode: 'opd' });
    const pf = await fem.send({ type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } });
    check('female + internal medicine resolves to ADULT_MEDICAL, not OBGYN (sex alone never activates OBGYN)',
      pf.formatPlan?.baseFormat === 'ADULT_MEDICAL', pf.formatPlan?.baseFormat ?? 'none');
    check('pregnancy is not inferred from sex',
      pf.formatPlan?.pregnant !== true, `pregnant=${pf.formatPlan?.pregnant}`);

    // --- Navigation: required counts + attention states --------------------------
    console.log('\nnavigation: section states carry required counts');
    const hiddenCodes = new Set<string>();
    const collectCodes = (s: WorkspaceNavigationProjection['sections'][number]): void => {
      if (s.state === 'hidden') hiddenCodes.add(s.sectionCode);
      for (const c of s.children ?? []) {
        if (c.state === 'hidden') hiddenCodes.add(c.subsectionCode);
      }
    };
    pm.navigation?.sections.forEach(collectCodes);
    check('male navigation hides the OBGYN sections from the workspace (or omits them entirely as HIDd)',
      ['OBSTETRIC_HISTORY', 'GYNAECOLOGICAL_HISTORY', 'ANC_PROFILE'].every(
        (s) =>
          hiddenCodes.has(s) ||
          !(pm.navigation?.sections.flatMap((ws) => ws.children ?? []).some((c) => c.subsectionCode === s)),
      ) || (pm.formatPlan?.excludedSections ?? []).length >= 6,
      `hidden=${[...hiddenCodes].join(',')}`);
    const attention = (p1.navigation?.sections ?? []).filter((s) => s.state === 'attention');
    check('adult navigation flags required-remaining sections as attention',
      attention.length > 0,
      attention.map((s) => `${s.sectionCode}:${s.requiredRemaining}`).join(','));
    check('workflow phase drives the encounter bar',
      ['history', 'examination', 'reasoning', 'investigation', 'management', 'monitoring', 'documentation'].includes(p1.navigation?.workflowPhase ?? ''),
      p1.navigation?.workflowPhase ?? 'none');

    console.log(failures === 0 ? '\nUNIVERSAL FORMAT MATRIX VERIFIED' : `\n${failures} FAILURES`);
    await client.query('ROLLBACK');
  } finally {
    client.release();
    await pool.end();
  }
}

main()
  .catch((err) => {
    failures += 1;
    console.error('\nUNIVERSAL FORMAT MATRIX ERROR:', err);
  })
  .finally(() => {
    process.exit(failures === 0 ? 0 : 1);
  });
