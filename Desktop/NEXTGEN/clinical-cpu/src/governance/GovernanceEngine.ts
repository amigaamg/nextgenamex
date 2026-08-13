// =============================================================================
// AMEXAN Clinical CPU — GovernanceEngine (H10)
// The trust layer. After every nephron pass the CPU hands this engine the full
// computation so H10 can answer, without any narrative guesswork:
//
//   "What did AMEXAN know, where did it come from, which rule fired, which
//    patient facts were used, and can we reproduce the decision?"
//
//  Per computation it records, inside the same transaction as the run:
//     1. knowledge.reasoning_run             — the computation envelope
//     2. governance.rule_execution           — every phenotype/condition rule fired
//     3. governance.audit_event              — the clinical computation event stream
//     4. governance.provenance_record        — two-way trace (source → rule → facts)
//     5. governance.clinical_snapshot        — patient facts + knowledge state (#10)
//     6. governance.reasoning_snapshot       — H8 differential state (#31)
//     7. governance.documentation_snapshot   — H9 compiled output (#51)
//
// The runtime tables are EMPTY at seed time; the CPU fills them per
// computation (spec §19/§32/§50). Nothing here changes clinical logic — it
// records what the logic already decided.
// =============================================================================

import type { Db, Row } from '../db.js';
import { inputFingerprint } from './fingerprint.js';
import {
  ClinicalRuntimeProjection,
  DifferentialCandidate,
  PatientClinicalState,
  ProcessRequest,
} from '../types.js';

interface SystemVersionRow extends Row {
  system_version_code: string;
  reasoning_version_code: string | null;
  documentation_version_code: string | null;
  differential_version_code: string | null;
  engine_version: string;
}

interface IdRow extends Row {
  id: string;
}

interface GovernedObjectRow extends Row {
  key_code: string;
  object_code: string;
  id: string;
  source_claim_code: string | null;
}

const KNOWLEDGE_VERSION = 'HUTCHISON_24_2018';

export class GovernanceEngine {
  constructor(private readonly db: Db) {}

  // -------------------------------------------------------------------------
  // Record one full computation. Returns the reasoning run id so callers can
  // correlate every audit event, rule execution and snapshot.
  // -------------------------------------------------------------------------
  async record(
    request: ProcessRequest,
    eventId: number | null,
    state: PatientClinicalState,
    projection: ClinicalRuntimeProjection,
  ): Promise<{ runId: string; clinicalSnapshotId: string }> {
    const systemVersion = await this.activeSystemVersion();
    const runId = await this.startRun(request, projection, systemVersion);

    const governed = await this.loadGovernedObjects();

    await this.recordAudit(
      request,
      runId,
      systemVersion.system_version_code,
      projection,
    );

    const ruleExecutionIds = await this.recordRuleExecutions(
      runId,
      projection,
      governed,
    );

    await this.recordProvenance(
      runId,
      ruleExecutionIds,
      projection,
      governed,
    );

    const clinicalSnapshotId = await this.recordSnapshots(
      request,
      state,
      projection,
      runId,
      systemVersion,
    );

    return { runId, clinicalSnapshotId };
  }

  // -------------------------------------------------------------------------
  // 1. The computation envelope — one reasoning_run per pass (H8 runtime ledger)
  // -------------------------------------------------------------------------
  private async startRun(
    request: ProcessRequest,
    projection: ClinicalRuntimeProjection,
    systemVersion: SystemVersionRow,
  ): Promise<string> {
    const row = await this.db.queryOne<IdRow>(
      `INSERT INTO knowledge.reasoning_run
          (patient_id, encounter_id, input_state_version, ruleset_version,
           knowledge_version, engine_version, status, started_at, completed_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, now(), now())
       RETURNING run_id AS id`,
      [
        request.patientId,
        request.encounterId ?? null,
        'LIVE-PATIENT-STATE',
        systemVersion.differential_version_code ?? 'RV2024.01.001',
        KNOWLEDGE_VERSION,
        systemVersion.engine_version,
        'COMPLETED',
      ],
    );
    return row!.id;
  }

  // -------------------------------------------------------------------------
  // 2. Rule executions — the decision black box (#19): which rule, which
  //    facts, which output. One row per matched phenotype and one per ranked
  //    condition, cross-referenced to the governed object when available.
  // -------------------------------------------------------------------------
  private async recordRuleExecutions(
    runId: string,
    projection: ClinicalRuntimeProjection,
    governed: Map<string, GovernedObjectRow>,
  ): Promise<string[]> {
    const ids: string[] = [];

    for (const phenotype of projection.phenotypes) {
      const object = governed.get(phenotype.phenotypeCode);
      const row = await this.db.queryOne<IdRow>(
        `INSERT INTO governance.rule_execution
            (run_id, object_id, rule_code, knowledge_version, input_facts, output)
         VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb)
         RETURNING id`,
        [
          runId,
          object?.id ?? null,
          phenotype.phenotypeCode,
          KNOWLEDGE_VERSION,
          JSON.stringify({ phenotype_matcher: phenotype.phenotypeCode }),
          JSON.stringify({
            score: phenotype.score,
            maxScore: phenotype.maxScore,
            compatibility: phenotype.compatibility,
            name: phenotype.name,
          }),
        ],
      );
      if (row) ids.push(row.id);
    }

    for (const candidate of projection.differentials) {
      const object = governed.get(candidate.conditionCode);
      const row = await this.db.queryOne<IdRow>(
        `INSERT INTO governance.rule_execution
            (run_id, object_id, rule_code, knowledge_version, input_facts, output)
         VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb)
         RETURNING id`,
        [
          runId,
          object?.id ?? null,
          candidate.conditionCode,
          KNOWLEDGE_VERSION,
          JSON.stringify(this.factCodesUsed(candidate)),
          JSON.stringify({
            name: candidate.name,
            compatibility: candidate.compatibility,
            viaPhenotypes: candidate.viaPhenotypes,
            evidence: candidate.evidence.map((e) => ({
              factCode: e.factCode,
              expectation: e.expectation,
              found: e.found,
              weight: e.weight,
              support: e.support,
            })),
          }),
        ],
      );
      if (row) ids.push(row.id);
    }

    return ids;
  }

  // -------------------------------------------------------------------------
  // 3. Audit events — the clinical computation event stream (#16/#18)
  // -------------------------------------------------------------------------
  private async recordAudit(
    request: ProcessRequest,
    runId: string,
    systemVersionCode: string,
    projection: ClinicalRuntimeProjection,
  ): Promise<void> {
    const actorType = request.clinicianId ? 'CLINICIAN' : 'SYSTEM';
    const actorCode = request.clinicianId ?? null;

    const events: [string, string, string | null, string | null][] = [];

    events.push(['CPU_ENGINE_STARTED', 'clinical_computation', runId, null]);

    for (const phenotype of projection.phenotypes) {
      events.push(['PHENOTYPE_MATCHED', 'phenotype', phenotype.phenotypeCode, `${phenotype.score}`]);
    }

    if (projection.differentials.length > 0) {
      const top = projection.differentials[0];
      events.push(['DDX_UPDATED', 'differential', top.conditionCode,
        `leading ${top.conditionCode} compatibility ${top.compatibility}`]);
    }

    for (const alert of projection.alerts) {
      events.push(['ALERT_GENERATED', 'alert', alert.code, alert.message]);
    }

    if (projection.documentation.length > 0) {
      events.push(['DOCUMENT_GENERATED', 'documentation', runId,
        `${projection.documentation.length} sections compiled`]);
    }

    events.push(['SYSTEM_VERSION_SELECTED', 'system_version', systemVersionCode, null]);

    for (const [eventType, entityType, entityCode, newValue] of events) {
      await this.db.query(
        `INSERT INTO governance.audit_event
            (event_type, actor_type, actor_code, entity_type, entity_code,
             new_value, encounter_id, run_id, correlation_id, occurred_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())`,
        [
          eventType,
          actorType,
          actorCode,
          entityType,
          entityCode,
          newValue,
          request.encounterId ?? null,
          runId,
          runId,
        ],
      );
    }
  }

  // -------------------------------------------------------------------------
  // 4. Provenance — two-way trace (§34/§35/§36): FORWARD from source claim →
  //    governed object → rule; BACKWARD from the run → the facts used.
  // -------------------------------------------------------------------------
  private async recordProvenance(
    runId: string,
    ruleExecutionIds: string[],
    projection: ClinicalRuntimeProjection,
    governed: Map<string, GovernedObjectRow>,
  ): Promise<void> {
    const executionsByRule = new Map<string, string>();
    const phenotypeCount = projection.phenotypes.length;
    projection.differentials.forEach((candidate, index) => {
      executionsByRule.set(candidate.conditionCode, ruleExecutionIds[phenotypeCount + index]);
    });

    for (const candidate of projection.differentials) {
      const object = governed.get(candidate.conditionCode);
      if (!object) continue;

      // FORWARD: source claim → governed object → reasoning run (rule produced it)
      await this.db.query(
        `INSERT INTO governance.provenance_record
            (direction, source_claim_code, governance_object_code,
             reasoning_run_id, rule_execution_id, link_type)
         VALUES ('FORWARD', $1, $2, $3, $4, 'derived_from')`,
        [object.source_claim_code, object.object_code, runId, executionsByRule.get(candidate.conditionCode) ?? null],
      );

      // BACKWARD: reasoning run → each fact the rule used
      for (const factCode of this.factCodes(candidate)) {
        await this.db.query(
          `INSERT INTO governance.provenance_record
              (direction, source_claim_code, governance_object_code,
               fact_code, reasoning_run_id, rule_execution_id, link_type)
           VALUES ('BACKWARD', $1, $2, $3, $4, $5, 'used_in')`,
          [object.source_claim_code, object.object_code, factCode, runId, executionsByRule.get(candidate.conditionCode) ?? null],
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // 5/6/7. Snapshots — the SNAPSHOT PRINCIPLE (#10): a reproducible capture of
  //         patient, knowledge, reasoning and documentation state.
  // -------------------------------------------------------------------------
  private async recordSnapshots(
    request: ProcessRequest,
    state: PatientClinicalState,
    projection: ClinicalRuntimeProjection,
    runId: string,
    systemVersion: SystemVersionRow,
  ): Promise<string> {
    const fingerprint = inputFingerprint(state.facts);

    const snapshot = await this.db.queryOne<IdRow>(
      `INSERT INTO governance.clinical_snapshot
          (patient_id, encounter_id, system_version_code,
           reasoning_version_code, documentation_version_code,
           patient_facts, knowledge_state, input_fingerprint, captured_at)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8, now())
       RETURNING id`,
      [
        request.patientId,
        request.encounterId ?? null,
        systemVersion.system_version_code,
        systemVersion.reasoning_version_code,
        systemVersion.documentation_version_code,
        JSON.stringify({
          // Replayable patient state (§30/§31): exactly what the computation saw.
          ageYears: state.ageYears,
          sex: state.sex,
          activeSymptoms: state.activeSymptoms,
          facts: state.facts.map((f) => ({
            factCode: f.factCode,
            statusCode: f.statusCode,
            values: f.values,
          })),
        }),
        JSON.stringify({
          reasoningVersion: systemVersion.reasoning_version_code,
          documentationVersion: systemVersion.documentation_version_code,
          differentialRuleset: systemVersion.differential_version_code,
          protocol: projection.protocol?.protocolCode ?? null,
          gate: projection.governance?.gate ?? null, // H10 §37 verdict captured
        }),
        fingerprint,
      ],
    );
    const clinicalSnapshotId = snapshot!.id;

    await this.db.query(
      `INSERT INTO governance.reasoning_snapshot
          (clinical_snapshot_id, run_id, reasoning_version_code, candidate_states)
       VALUES ($1, $2, $3, $4::jsonb)`,
      [
        clinicalSnapshotId,
        runId,
        systemVersion.reasoning_version_code,
        JSON.stringify(projection.differentials.map((d) => ({
          conditionCode: d.conditionCode,
          name: d.name,
          compatibility: d.compatibility,
          viaPhenotypes: d.viaPhenotypes,
        }))),
      ],
    );

    await this.db.query(
      `INSERT INTO governance.documentation_snapshot
          (clinical_snapshot_id, documentation_version_code, sections, instance_id)
       VALUES ($1, $2, $3::jsonb, NULL)`,
      [
        clinicalSnapshotId,
        systemVersion.documentation_version_code,
        JSON.stringify(projection.documentation),
      ],
    );

    return clinicalSnapshotId;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  private async activeSystemVersion(): Promise<SystemVersionRow> {
    const row = await this.db.queryOne<SystemVersionRow>(
      `SELECT system_version_code, reasoning_version_code, documentation_version_code,
              differential_version_code, engine_version
         FROM governance.system_version
        WHERE is_active = true
        ORDER BY released_at DESC
        LIMIT 1`,
    );
    return row ?? {
      system_version_code: 'AMEXAN-1.0.0',
      reasoning_version_code: 'RV2024.01.001',
      documentation_version_code: 'RV2024.01.002',
      differential_version_code: 'RV2024.01.001',
      engine_version: 'CLINICAL-CPU-1.0',
    };
  }

  private async loadGovernedObjects(): Promise<Map<string, GovernedObjectRow>> {
    // Governed objects are keyed by the ENGINE'S runtime codes: a phenotype
    // matches its governed object by object_code; a differential condition
    // matches through diagnosis_concept.code (DA001 …) via the shared concept
    // id (§34 trace: runtime condition → governed diagnosis → source claim).
    const rows = await this.db.query<GovernedObjectRow>(
      `SELECT ko.id::text AS id, ko.object_code, ko.source_claim_code,
              ph.phenotype_code AS key_code
         FROM governance.knowledge_object ko
         JOIN knowledge.phenotype ph ON ph.phenotype_code = ko.object_code
        WHERE ko.lifecycle_status IN ('ACTIVE','APPROVED','VALIDATED')
       UNION
       SELECT ko.id::text AS id, ko.object_code, ko.source_claim_code,
              c.condition_code AS key_code
         FROM governance.knowledge_object ko
         JOIN knowledge.diagnosis_concept dc ON dc.code = ko.object_code
         JOIN knowledge.condition c ON c.concept_id = dc.concept_id
        WHERE ko.knowledge_type = 'DIAGNOSIS'
          AND ko.lifecycle_status IN ('ACTIVE','APPROVED','VALIDATED')`,
    );
    return new Map(rows.map((r) => [r.key_code, r]));
  }

  private factCodesUsed(candidate: DifferentialCandidate): Record<string, string> {
    const used: Record<string, string> = {};
    for (const line of candidate.evidence) {
      used[line.factCode] = line.found ?? line.expectation;
    }
    return used;
  }

  private factCodes(candidate: DifferentialCandidate): string[] {
    return [...new Set(candidate.evidence.map((e) => e.factCode))];
  }
}