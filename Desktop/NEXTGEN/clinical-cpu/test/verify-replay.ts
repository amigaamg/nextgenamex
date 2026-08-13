// =============================================================================
// AMEXAN Clinical CPU — verify H10 replay (§30/§31) + runtime knowledge gate (§37)
// Creates a real patient + CAP facts, runs the full ClinicalCPU once (records a
// reasoning_run + snapshots inside the transaction), then:
//
//   • ReplayEngine.reconstruct(runId) rebuilds the snapshot's patient state,
//     re-runs the nephron, and compares the input fingerprint, H8 reasoning and
//     H9 documentation against what was recorded — must match byte-for-byte.
//   • KnowledgeResolver.gate verifies: governed-live knowledge is VALID, the
//     DRAFT Kenya guideline is BLOCKED (§41 fails closed), and unregistered
//     knowledge is flagged UNGOVERNED (§27/§49) rather than silently trusted.
//
// Runs inside a transaction and ROLLS BACK — the database stays pristine and
// the script is re-runnable. Exit code 0 = H10 replay + gate verified.
// =============================================================================

import { randomUUID } from 'node:crypto';
import { Db, createPool } from '../src/db.js';
import { ClinicalCPU } from '../src/runtime/ClinicalCPU.js';
import { KnowledgeResolver } from '../src/governance/KnowledgeResolver.js';
import { ReplayEngine } from '../src/governance/ReplayEngine.js';
import type { KnowledgeGateEntry } from '../src/types.js';

const pool = createPool();

async function main() {
  const client = await pool.connect();
  const db = new Db(client);
  const cpu = new ClinicalCPU(db);

  try {
    await client.query('BEGIN');

    const personId = randomUUID();
    const patientId = randomUUID();

    await client.query(
      `INSERT INTO identity.person (id, status_code, gender, birth_date, nationality, occupation)
       VALUES ($1, 'active', 'male', DATE '1990-02-14', 'Kenya', 'Farmer')`,
      [personId],
    );
    await client.query(
      `INSERT INTO patient.patient (id, person_id, mrn, status_code)
       VALUES ($1, $2, 'MRN-GOV-REPLAY', 'active')`,
      [patientId, personId],
    );
    const { rows: [enc] } = await client.query(
      `INSERT INTO encounter.encounter (patient_id, encounter_type_code)
       VALUES ($1, 'opd') RETURNING id`,
      [patientId],
    );
    const encounterId = enc.id as string;

    const facts: [string, string, string | null, number | null, boolean | null][] = [
      ['COUGH_PRESENT', 'coded', 'YES', null, null],
      ['COUGH_DURATION_DAYS', 'numeric', null, 4, null],
      ['COUGH_PRODUCTIVITY', 'coded', 'PRODUCTIVE', null, null],
      ['SPUTUM_COLOUR', 'coded', 'CLEAR', null, null],
      ['FEVER_PRESENT', 'coded', 'YES', null, null],
      ['DYSPNOEA_PRESENT', 'coded', 'YES', null, null],
      ['CHEST_PAIN_PLEURITIC', 'coded', 'YES', null, null],
      ['RESP_RATE', 'numeric', null, 24, null],
      ['SPO2', 'numeric', null, 94, null],
      ['RLL_DULLNESS', 'boolean', null, null, true],
      ['RLL_BRONCHIAL_BREATH_SOUNDS', 'boolean', null, null, true],
      ['CRACKLES', 'boolean', null, null, true],
    ];
    for (const [code, kind, text, num, bool] of facts) {
      await client.query(
        `INSERT INTO clinical.fact (patient_id, encounter_id, fact_definition_code, status_code)
         VALUES ($1, $2, $3, 'active') RETURNING id`,
        [patientId, encounterId, code],
      ).then(({ rows: [row] }) =>
        client.query(
          `INSERT INTO clinical.fact_value (fact_id, data_type, value_text, value_numeric, value_boolean)
           VALUES ($1, $2, $3, $4, $5)`,
          [row.id, kind, text, num, bool],
        ),
      );
    }

    const projection = await cpu.process({
      patientId,
      encounterId,
      event: { type: 'SYMPTOM_PRESENTED', payload: { symptom: 'cough' } },
    });

    if (!projection.governance?.runId || !projection.governance.clinicalSnapshotId) {
      throw new Error('projection must expose governance.runId + clinicalSnapshotId (§34-36)');
    }

    // ---- 1. REPLAY (§30/§31) -------------------------------------------------
    const replay = new ReplayEngine(db);
    const result = await replay.reconstruct(projection.governance.runId);

    console.log(`replay run:            ${result.runId}`);
    console.log(`versions:              ${result.versions.system} (reasoning ${result.versions.reasoning}, documentation ${result.versions.documentation})`);
    console.log(`fingerprint match:     ${result.fingerprint.matches}`);
    console.log(`reasoning match:       ${result.reasoning.matches}`);
    console.log(`documentation match:   ${result.documentation.matches}`);
    console.log(`rule executions:       ${result.ruleExecutions.length}`);
    console.log(`audit events:          ${result.auditEvents.length}`);
    console.log(`provenance links:      ${result.provenance.length}`);
    console.log(`gate checked/blocked:  ${result.gate.checked} / ${result.gate.blocked.length}`);

    if (!result.fingerprint.matches) throw new Error('replay fingerprint mismatch (§30)');
    if (!result.reasoning.matches) throw new Error('replay H8 reasoning mismatch (§31)');
    if (!result.documentation.matches) throw new Error('replay H9 documentation mismatch (§31)');
    if (!result.matches) throw new Error('replay overall mismatch');
    if (result.ruleExecutions.length < 4) throw new Error('replay should return the recorded rule executions');
    if (result.auditEvents.length < 6) throw new Error('replay should return the recorded audit stream');
    if (result.provenance.length < 2) throw new Error('replay should return the recorded provenance');

    // ---- 2. KNOWLEDGE GATE (§37) ---------------------------------------------
    const resolver = new KnowledgeResolver(db);
    const gateOf = async (kind: string, code: string): Promise<KnowledgeGateEntry> => {
      const g = await resolver.gate([{ kind, code }]);
      return g.valid[0] ?? g.blocked[0] ?? g.ungoverned[0];
    };

    const livePhenotype = await gateOf('phenotype', 'PHEN-HYPOXAEMIA');
    const liveCondition = await gateOf('condition', 'PNEUMONIA');
    const liveProtocol = await gateOf('protocol', 'PROT-CAP-ADULT');
    const draftGuideline = await gateOf('guideline', 'GL-KENYA-ASTHMA-2021');
    const ungoverned = await gateOf('phenotype', 'PHEN-RESPIRATORY-FAILURE');

    console.log(`gate PHEN-HYPOXAEMIA:     ${livePhenotype.verdict} (${livePhenotype.objectCode} / ${livePhenotype.lifecycleStatus})`);
    console.log(`gate PNEUMONIA:           ${liveCondition.verdict} (${liveCondition.objectCode})`);
    console.log(`gate PROT-CAP-ADULT:      ${liveProtocol.verdict} (${liveProtocol.lifecycleStatus})`);
    console.log(`gate GL-KENYA-ASTHMA-2021:${draftGuideline.verdict} (${draftGuideline.lifecycleStatus})`);
    console.log(`gate PHEN-RESPIRATORY-FAILURE: ${ungoverned.verdict}`);

    if (livePhenotype.verdict !== 'VALID') throw new Error('governed live phenotype must be VALID (§37)');
    if (liveCondition.verdict !== 'VALID') throw new Error('governed live condition must be VALID (§37)');
    if (liveProtocol.verdict !== 'VALID') throw new Error('governed live protocol must be VALID (§37)');
    if (draftGuideline.verdict !== 'BLOCKED') throw new Error('DRAFT guideline must be BLOCKED — must not be used (§41/§49)');
    if (ungoverned.verdict !== 'UNGOVERNED') throw new Error('unregistered knowledge must be flagged UNGOVERNED (§27/§49)');

    // the computation itself must have passed the gate (nothing governed-but-not-live used)
    if (!result.gate.passes) {
      throw new Error(`runtime gate failed: ${result.gate.blocked.map((e) => e.code).join(', ')}`);
    }

    await client.query('ROLLBACK');

    console.log('\nH10 replay (§30/§31) + knowledge gate (§37) verified: snapshot reproduced byte-for-byte, DRAFT knowledge blocked, ungoverned knowledge flagged (rolled back).');
  } finally {
    await client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});