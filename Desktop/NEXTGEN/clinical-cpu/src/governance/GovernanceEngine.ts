// =============================================================================
// AMEXAN Clinical CPU — GovernanceEngine (H10)
// -----------------------------------------------------------------------------
// The immutable trust/audit layer for every Clinical CPU nephron pass.
//
// Responsibilities
//   1. Create the reasoning_run computation envelope.
//   2. Record the clinical computation audit stream.
//   3. Record every phenotype and differential rule execution.
//   4. Create forward/backward provenance links.
//   5. Capture the exact patient state seen by the computation.
//   6. Capture the governed knowledge state used by the computation.
//   7. Capture the differential/reasoning snapshot.
//   8. Capture the compiled documentation snapshot.
//
// Design invariants
//   • This engine records decisions; it does not make clinical decisions.
//   • No clinical rule is hard-coded here.
//   • Runtime codes are resolved to governed knowledge objects by database
//     relationships, never by duplicated clinical mappings.
//   • Every snapshot is immutable and tied to a reasoning run.
//   • The caller's Db instance controls transaction boundaries.
//   • A governance failure must fail the CPU pass rather than silently create
//     an apparently trusted but incomplete audit trail.
// =============================================================================

import type { Db, Row } from '../db.js';
import { inputFingerprint } from './fingerprint.js';
import type {
  ClinicalRuntimeProjection,
  DifferentialCandidate,
  PatientClinicalState,
  ProcessRequest,
} from '../types.js';

// -----------------------------------------------------------------------------
// Database rows
// -----------------------------------------------------------------------------

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

interface RuleExecutionReference {
  ruleCode: string;
  executionId: string;
}

// -----------------------------------------------------------------------------
// Immutable fallback identifiers.
//
// These are runtime metadata defaults only. They are NOT clinical knowledge.
// A configured governance.system_version always takes precedence.
// -----------------------------------------------------------------------------

const DEFAULT_SYSTEM_VERSION: SystemVersionRow = {
  system_version_code: 'AMEXAN-1.0.0',
  reasoning_version_code: 'RV2024.01.001',
  documentation_version_code: 'RV2024.01.002',
  differential_version_code: 'RV2024.01.001',
  engine_version: 'CLINICAL-CPU-1.0',
};

const KNOWLEDGE_VERSION = 'HUTCHISON_24_2018';

const LIVE_LIFECYCLE_STATUSES = new Set([
  'ACTIVE',
  'APPROVED',
  'VALIDATED',
]);

export class GovernanceEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /**
   * Persist the complete governance record for one CPU computation.
   *
   * The method deliberately does not open or commit a transaction. The Db
   * supplied to the CPU determines the transaction boundary, allowing:
   *
   *   BEGIN
   *     clinical event
   *     clinical computation
   *     governance record
   *     snapshot
   *   COMMIT
   *
   * or a complete ROLLBACK.
   */
  async record(
    request: ProcessRequest,
    eventId: number | null,
    state: PatientClinicalState,
    projection: ClinicalRuntimeProjection,
  ): Promise<{ runId: string; clinicalSnapshotId: string }> {
    const systemVersion = await this.activeSystemVersion();

    const runId = await this.startRun(
      request,
      projection,
      systemVersion,
      eventId,
    );

    const governed = await this.loadGovernedObjects();

    await this.recordAudit(
      request,
      eventId,
      runId,
      systemVersion.system_version_code,
      projection,
    );

    const ruleExecutions = await this.recordRuleExecutions(
      runId,
      projection,
      governed,
    );

    await this.recordProvenance(
      runId,
      ruleExecutions,
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

    return {
      runId,
      clinicalSnapshotId,
    };
  }

  // ===========================================================================
  // 1. REASONING RUN
  // ===========================================================================

  private async startRun(
    request: ProcessRequest,
    projection: ClinicalRuntimeProjection,
    systemVersion: SystemVersionRow,
    eventId: number | null,
  ): Promise<string> {
    const row = await this.db.queryOne<IdRow>(
      `INSERT INTO knowledge.reasoning_run
          (
            patient_id,
            encounter_id,
            input_state_version,
            ruleset_version,
            knowledge_version,
            engine_version,
            status,
            started_at,
            completed_at
          )
       VALUES
          (
            $1,
            $2,
            $3,
            $4,
            $5,
            $6,
            $7,
            now(),
            now()
          )
       RETURNING run_id::text AS id`,
      [
        request.patientId,
        request.encounterId ?? null,

        // The event ID identifies the exact CPU input boundary.
        eventId != null
          ? `EVENT-${eventId}`
          : 'LIVE-PATIENT-STATE',

        systemVersion.differential_version_code ??
          systemVersion.reasoning_version_code ??
          'RV2024.01.001',

        KNOWLEDGE_VERSION,
        systemVersion.engine_version,
        'COMPLETED',
      ],
    );

    if (!row?.id) {
      throw new Error(
        'AMEXAN GovernanceEngine: failed to create reasoning_run',
      );
    }

    return row.id;
  }

  // ===========================================================================
  // 2. RULE EXECUTION
  // ===========================================================================

  /**
   * Records the computational outputs that can be traced to governed
   * phenotype/condition knowledge.
   *
   * Every execution gets its own database ID. Provenance later references
   * these exact IDs instead of reconstructing relationships from array
   * positions.
   */
  private async recordRuleExecutions(
    runId: string,
    projection: ClinicalRuntimeProjection,
    governed: Map<string, GovernedObjectRow>,
  ): Promise<RuleExecutionReference[]> {
    const executions: RuleExecutionReference[] = [];

    // -------------------------------------------------------------------------
    // Phenotypes
    // -------------------------------------------------------------------------

    for (const phenotype of projection.phenotypes) {
      const object = governed.get(phenotype.phenotypeCode);

      const row = await this.db.queryOne<IdRow>(
        `INSERT INTO governance.rule_execution
            (
              run_id,
              object_id,
              rule_code,
              knowledge_version,
              input_facts,
              output
            )
         VALUES
            (
              $1,
              $2,
              $3,
              $4,
              $5::jsonb,
              $6::jsonb
            )
         RETURNING id::text AS id`,
        [
          runId,
          object?.id ?? null,
          phenotype.phenotypeCode,
          KNOWLEDGE_VERSION,

          JSON.stringify({
            runtimeType: 'phenotype',
            phenotypeCode: phenotype.phenotypeCode,
          }),

          JSON.stringify({
            phenotypeCode: phenotype.phenotypeCode,
            name: phenotype.name,
            score: phenotype.score,
            maxScore: phenotype.maxScore,
            compatibility: phenotype.compatibility,
          }),
        ],
      );

      if (row?.id) {
        executions.push({
          ruleCode: phenotype.phenotypeCode,
          executionId: row.id,
        });
      }
    }

    // -------------------------------------------------------------------------
    // Differential candidates
    // -------------------------------------------------------------------------

    for (const candidate of projection.differentials) {
      const object = governed.get(candidate.conditionCode);

      const row = await this.db.queryOne<IdRow>(
        `INSERT INTO governance.rule_execution
            (
              run_id,
              object_id,
              rule_code,
              knowledge_version,
              input_facts,
              output
            )
         VALUES
            (
              $1,
              $2,
              $3,
              $4,
              $5::jsonb,
              $6::jsonb
            )
         RETURNING id::text AS id`,
        [
          runId,
          object?.id ?? null,
          candidate.conditionCode,
          KNOWLEDGE_VERSION,

          JSON.stringify({
            runtimeType: 'differential',
            conditionCode: candidate.conditionCode,
            facts: this.factCodesUsed(candidate),
          }),

          JSON.stringify({
            conditionCode: candidate.conditionCode,
            name: candidate.name,
            compatibility: candidate.compatibility,
            viaPhenotypes: candidate.viaPhenotypes,
            evidence: candidate.evidence.map((evidence) => ({
              factCode: evidence.factCode,
              expectation: evidence.expectation,
              found: evidence.found,
              weight: evidence.weight,
              polarity: evidence.polarity,
              support: evidence.support,
            })),
          }),
        ],
      );

      if (row?.id) {
        executions.push({
          ruleCode: candidate.conditionCode,
          executionId: row.id,
        });
      }
    }

    return executions;
  }

  // ===========================================================================
  // 3. AUDIT EVENT STREAM
  // ===========================================================================

  private async recordAudit(
    request: ProcessRequest,
    eventId: number | null,
    runId: string,
    systemVersionCode: string,
    projection: ClinicalRuntimeProjection,
  ): Promise<void> {
    const actorType = request.clinicianId ? 'CLINICIAN' : 'SYSTEM';
    const actorCode = request.clinicianId ?? null;

    type AuditEvent = {
      eventType: string;
      entityType: string;
      entityCode: string | null;
      newValue: string | null;
    };

    const events: AuditEvent[] = [];

    events.push({
      eventType: 'CPU_ENGINE_STARTED',
      entityType: 'clinical_computation',
      entityCode: runId,
      newValue: eventId != null ? `event:${eventId}` : null,
    });

    // -------------------------------------------------------------------------
    // Phenotype events
    // -------------------------------------------------------------------------

    for (const phenotype of projection.phenotypes) {
      events.push({
        eventType: 'PHENOTYPE_EVALUATED',
        entityType: 'phenotype',
        entityCode: phenotype.phenotypeCode,
        newValue: JSON.stringify({
          score: phenotype.score,
          maxScore: phenotype.maxScore,
          compatibility: phenotype.compatibility,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Differential events
    // -------------------------------------------------------------------------

    if (projection.differentials.length > 0) {
      const leading = projection.differentials[0];

      events.push({
        eventType: 'DDX_UPDATED',
        entityType: 'differential',
        entityCode: leading.conditionCode,
        newValue: JSON.stringify({
          leading: true,
          compatibility: leading.compatibility,
          candidateCount: projection.differentials.length,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Contradiction events
    // -------------------------------------------------------------------------

    for (const contradiction of projection.contradictions) {
      events.push({
        eventType: 'CONTRADICTION_PROBE_RAISED',
        entityType: 'contradiction',
        entityCode: contradiction.factCode,
        newValue: JSON.stringify({
          expectation: contradiction.expectation,
          weight: contradiction.weight,
          reason: contradiction.reason,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Alerts
    // -------------------------------------------------------------------------

    for (const alert of projection.alerts) {
      events.push({
        eventType: 'ALERT_GENERATED',
        entityType: 'alert',
        entityCode: alert.code,
        newValue: JSON.stringify({
          level: alert.level,
          message: alert.message,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Severity scores
    // -------------------------------------------------------------------------

    for (const score of projection.severityScores) {
      events.push({
        eventType: 'SEVERITY_SCORE_EVALUATED',
        entityType: 'severity_score',
        entityCode: score.scoreCode,
        newValue: JSON.stringify({
          score: score.score,
          maxScore: score.maxScore,
          severityLabel: score.severityLabel,
          disposition: score.disposition,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Treatment candidates
    // -------------------------------------------------------------------------

    for (const treatment of projection.treatment) {
      events.push({
        eventType: 'TREATMENT_CANDIDATE_GENERATED',
        entityType: 'medication',
        entityCode: treatment.medicationCode,
        newValue: JSON.stringify({
          genericName: treatment.genericName,
          role: treatment.role,
          verified: treatment.verified,
          contraindicated: treatment.contraindicated,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Governance gate
    // -------------------------------------------------------------------------

    if (projection.governance?.gate) {
      const gate = projection.governance.gate;

      events.push({
        eventType: 'KNOWLEDGE_GATE_EVALUATED',
        entityType: 'knowledge_gate',
        entityCode: runId,
        newValue: JSON.stringify({
          passes: gate.passes,
          checked: gate.checked,
          valid: gate.valid.length,
          blocked: gate.blocked.length,
          ungoverned: gate.ungoverned.length,
        }),
      });
    }

    // -------------------------------------------------------------------------
    // Documentation
    // -------------------------------------------------------------------------

    if (projection.documentation.length > 0) {
      events.push({
        eventType: 'DOCUMENT_GENERATED',
        entityType: 'documentation',
        entityCode: runId,
        newValue: JSON.stringify({
          sectionCount: projection.documentation.length,
        }),
      });
    }

    events.push({
      eventType: 'SYSTEM_VERSION_SELECTED',
      entityType: 'system_version',
      entityCode: systemVersionCode,
      newValue: null,
    });

// -------------------------------------------------------------------------
    // Event type mapping: internal event types → allowed DB constraint values
    // -------------------------------------------------------------------------
    function mapEventType(internal: string): string {
      switch (internal) {
        case 'PHENOTYPE_EVALUATED':
          return 'PHENOTYPE_MATCHED';
        case 'CONTRADICTION_PROBE_RAISED':
          return 'KNOWLEDGE_CONFLICT_DETECTED';
        case 'SEVERITY_SCORE_EVALUATED':
          return 'RULE_EVALUATED';
        case 'TREATMENT_CANDIDATE_GENERATED':
          return 'RULE_EVALUATED';
        case 'KNOWLEDGE_GATE_EVALUATED':
          return 'KNOWLEDGE_CONFLICT_DETECTED';
        default:
          return internal;
      }
    }

    // -------------------------------------------------------------------------
    // Persist in deterministic order.
    // -------------------------------------------------------------------------

    for (const event of events) {
      await this.db.query(
        `INSERT INTO governance.audit_event
            (
              event_type,
              actor_type,
              actor_code,
              entity_type,
              entity_code,
              new_value,
              encounter_id,
              run_id,
              correlation_id,
              occurred_at
             )
          VALUES
             (
               $1,
               $2,
               $3,
               $4,
               $5,
               $6,
               $7,
               $8,
               $9,
               now()
             )`,
        [
          mapEventType(event.eventType),
          actorType,
          actorCode,
          event.entityType,
          event.entityCode,
          event.newValue,
          request.encounterId ?? null,
          runId,
          runId,
        ],
      );
    }
  }

  // ===========================================================================
  // 4. PROVENANCE
  // ===========================================================================

  /**
   * Builds both sides of the trace:
   *
   * FORWARD
   *   source claim
   *       ↓
   *   governed knowledge object
   *       ↓
   *   reasoning run
   *       ↓
   *   rule execution
   *
   * BACKWARD
   *   reasoning run
   *       ↓
   *   rule execution
   *       ↓
   *   patient fact
   */
  private async recordProvenance(
    runId: string,
    executions: RuleExecutionReference[],
    projection: ClinicalRuntimeProjection,
    governed: Map<string, GovernedObjectRow>,
  ): Promise<void> {
    const executionByRule = new Map<string, string>();

    for (const execution of executions) {
      executionByRule.set(execution.ruleCode, execution.executionId);
    }

    for (const candidate of projection.differentials) {
      const object = governed.get(candidate.conditionCode);

      // A provenance link requires a governed object. An ungoverned candidate
      // remains visible in the computation but cannot be falsely represented
      // as having a source claim.
      if (!object) continue;

      const executionId =
        executionByRule.get(candidate.conditionCode) ?? null;

      // -----------------------------------------------------------------------
      // FORWARD provenance
      // -----------------------------------------------------------------------

      await this.db.query(
        `INSERT INTO governance.provenance_record
            (
              direction,
              source_claim_code,
              governance_object_code,
              reasoning_run_id,
              rule_execution_id,
              link_type
            )
         VALUES
            (
              'FORWARD',
              $1,
              $2,
              $3,
              $4,
              'derived_from'
            )`,
        [
          object.source_claim_code,
          object.object_code,
          runId,
          executionId,
        ],
      );

      // -----------------------------------------------------------------------
      // BACKWARD provenance
      // -----------------------------------------------------------------------

      for (const factCode of this.factCodes(candidate)) {
        await this.db.query(
          `INSERT INTO governance.provenance_record
              (
                direction,
                source_claim_code,
                governance_object_code,
                fact_code,
                reasoning_run_id,
                rule_execution_id,
                link_type
              )
           VALUES
              (
                'BACKWARD',
                $1,
                $2,
                $3,
                $4,
                $5,
                'used_in'
              )`,
          [
            object.source_claim_code,
            object.object_code,
            factCode,
            runId,
            executionId,
          ],
        );
      }
    }
  }

  // ===========================================================================
  // 5/6/7. SNAPSHOTS
  // ===========================================================================

  private async recordSnapshots(
    request: ProcessRequest,
    state: PatientClinicalState,
    projection: ClinicalRuntimeProjection,
    runId: string,
    systemVersion: SystemVersionRow,
  ): Promise<string> {
    /*
     * The fingerprint must represent the exact fact set used by the CPU.
     * It is stored alongside the snapshot so replay can detect divergence.
     */
    const fingerprint = inputFingerprint(state.facts);

    const clinicalSnapshot = await this.db.queryOne<IdRow>(
      `INSERT INTO governance.clinical_snapshot
          (
            patient_id,
            encounter_id,
            system_version_code,
            reasoning_version_code,
            documentation_version_code,
            patient_facts,
            knowledge_state,
            input_fingerprint,
            captured_at
          )
       VALUES
          (
            $1,
            $2,
            $3,
            $4,
            $5,
            $6::jsonb,
            $7::jsonb,
            $8,
            now()
          )
       RETURNING id::text AS id`,
      [
        request.patientId,
        request.encounterId ?? null,

        systemVersion.system_version_code,
        systemVersion.reasoning_version_code,
        systemVersion.documentation_version_code,

        JSON.stringify(
          this.buildPatientSnapshot(state, request, runId),
        ),

        JSON.stringify(
          this.buildKnowledgeSnapshot(
            projection,
            systemVersion,
          ),
        ),

        fingerprint,
      ],
    );

    if (!clinicalSnapshot?.id) {
      throw new Error(
        'AMEXAN GovernanceEngine: failed to create clinical_snapshot',
      );
    }

    const clinicalSnapshotId = clinicalSnapshot.id;

    // -------------------------------------------------------------------------
    // Reasoning snapshot
    // -------------------------------------------------------------------------

    await this.db.query(
      `INSERT INTO governance.reasoning_snapshot
          (
            clinical_snapshot_id,
            run_id,
            reasoning_version_code,
            candidate_states
          )
       VALUES
          (
            $1,
            $2,
            $3,
            $4::jsonb
          )`,
      [
        clinicalSnapshotId,
        runId,
        systemVersion.reasoning_version_code,
        JSON.stringify(
          projection.differentials.map((candidate) => ({
            conditionCode: candidate.conditionCode,
            name: candidate.name,
            compatibility: candidate.compatibility,
            viaPhenotypes: candidate.viaPhenotypes,
            evidence: candidate.evidence.map((evidence) => ({
              factCode: evidence.factCode,
              expectation: evidence.expectation,
              found: evidence.found,
              weight: evidence.weight,
              polarity: evidence.polarity,
              support: evidence.support,
            })),
          })),
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // Documentation snapshot
    // -------------------------------------------------------------------------

    await this.db.query(
      `INSERT INTO governance.documentation_snapshot
          (
            clinical_snapshot_id,
            documentation_version_code,
            sections,
            instance_id
          )
       VALUES
          (
            $1,
            $2,
            $3::jsonb,
            NULL
          )`,
      [
        clinicalSnapshotId,
        systemVersion.documentation_version_code,
        JSON.stringify(projection.documentation),
      ],
    );

    return clinicalSnapshotId;
  }

  // ===========================================================================
  // SNAPSHOT BUILDERS
  // ===========================================================================

  private buildPatientSnapshot(
    state: PatientClinicalState,
    request: ProcessRequest,
    runId: string,
  ): Record<string, unknown> {
    return {
      patientId: state.patientId,
      encounterId: state.encounterId,
      runId,

      // Context
      ageYears: state.ageYears,
      ageDays: state.ageDays ?? null,
      ageMonths: state.ageMonths ?? null,
      ageBand: state.ageBand ?? null,
      sex: state.sex,
      pregnant: state.pregnant ?? null,
      gestationalAgeWeeks: state.gestationalAgeWeeks ?? null,
      departmentCode: state.departmentCode ?? null,
      encounterTypeCode: state.encounterTypeCode ?? null,
      jurisdictionCode: state.jurisdictionCode ?? null,

      // Activated clinical context
      activeDomains: [...(state.activeDomains ?? [])],
      activeSymptoms: [...state.activeSymptoms],
      answeredQuestions: [...state.answeredQuestions],

      // Exact clinical facts used by the computation.
      facts: state.facts.map((fact) => ({
        id: fact.id,
        patientId: fact.patientId,
        encounterId: fact.encounterId,
        factCode: fact.factCode,
        statusCode: fact.statusCode,
        recordedAt: fact.recordedAt,
        sourceType: fact.sourceType,
        values: fact.values.map((value) => ({
          dataType: value.dataType,
          text: value.text ?? null,
          numeric: value.numeric ?? null,
          boolean: value.boolean ?? null,
          unitCode: value.unitCode ?? null,
        })),
      })),

      source: {
        eventId: null,
        requestClinicianId: request.clinicianId ?? null,
      },
    };
  }

  private buildKnowledgeSnapshot(
    projection: ClinicalRuntimeProjection,
    systemVersion: SystemVersionRow,
  ): Record<string, unknown> {
    return {
      systemVersion: systemVersion.system_version_code,
      engineVersion: systemVersion.engine_version,
      reasoningVersion: systemVersion.reasoning_version_code,
      documentationVersion: systemVersion.documentation_version_code,
      differentialVersion: systemVersion.differential_version_code,
      knowledgeVersion: KNOWLEDGE_VERSION,

      protocol: projection.protocol?.protocolCode ?? null,

      formatPlan: projection.formatPlan ?? null,

      configuration: projection.configuration ?? {
        overrides: [],
      },

      governanceGate: projection.governance?.gate ?? null,

      knowledgeCodes: {
        phenotypes: projection.phenotypes.map(
          (phenotype) => phenotype.phenotypeCode,
        ),
        differentials: projection.differentials.map(
          (candidate) => candidate.conditionCode,
        ),
        protocol: projection.protocol
          ? [projection.protocol.protocolCode]
          : [],
        questions: projection.nextQuestions.map(
          (question) => question.questionCode,
        ),
      },
    };
  }

  // ===========================================================================
  // SYSTEM VERSION
  // ===========================================================================

  private async activeSystemVersion(): Promise<SystemVersionRow> {
    const row = await this.db.queryOne<SystemVersionRow>(
      `SELECT
          system_version_code,
          reasoning_version_code,
          documentation_version_code,
          differential_version_code,
          engine_version
       FROM governance.system_version
       WHERE is_active = true
       ORDER BY released_at DESC NULLS LAST
       LIMIT 1`,
    );

    return row ?? { ...DEFAULT_SYSTEM_VERSION };
  }

  // ===========================================================================
  // GOVERNED KNOWLEDGE CATALOGUE
  // ===========================================================================

  /**
   * Load only LIVE governed objects for provenance.
   *
   * KnowledgeResolver is responsible for distinguishing:
   *
   *   VALID
   *   BLOCKED
   *   UNGOVERNED
   *
   * GovernanceEngine only needs live objects here because it is constructing
   * the provenance graph for knowledge actually permitted into the computation.
   */
  private async loadGovernedObjects(): Promise<
    Map<string, GovernedObjectRow>
  > {
    const rows = await this.db.query<GovernedObjectRow>(
      `SELECT
          ko.id::text AS id,
          ko.object_code,
          ko.source_claim_code,
          ph.phenotype_code AS key_code
       FROM governance.knowledge_object ko
       JOIN knowledge.phenotype ph
         ON ph.phenotype_code = ko.object_code
       WHERE ko.lifecycle_status = ANY($1::text[])

       UNION

       SELECT
          ko.id::text AS id,
          ko.object_code,
          ko.source_claim_code,
          c.condition_code AS key_code
       FROM governance.knowledge_object ko
       JOIN knowledge.diagnosis_concept dc
         ON dc.code = ko.object_code
       JOIN knowledge.condition c
         ON c.concept_id = dc.concept_id
       WHERE ko.knowledge_type = 'DIAGNOSIS'
         AND ko.lifecycle_status = ANY($1::text[])`,
      [[...LIVE_LIFECYCLE_STATUSES]],
    );

    const result = new Map<string, GovernedObjectRow>();

    for (const row of rows) {
      result.set(row.key_code, row);
    }

    return result;
  }

  // ===========================================================================
  // FACT TRACE HELPERS
  // ===========================================================================

  /**
   * Converts differential evidence into a compact machine-readable map.
   *
   * The evidence line itself remains the authoritative explanation; this helper
   * merely creates a convenient input_facts object for rule_execution.
   */
  private factCodesUsed(
    candidate: DifferentialCandidate,
  ): Record<string, string> {
    const used: Record<string, string> = {};

    for (const evidence of candidate.evidence) {
      used[evidence.factCode] =
        evidence.found ??
        evidence.expectation;
    }

    return used;
  }

  /**
   * Returns unique fact codes while preserving their first-seen order.
   */
  private factCodes(
    candidate: DifferentialCandidate,
  ): string[] {
    return [
      ...new Set(
        candidate.evidence.map(
          (evidence) => evidence.factCode,
        ),
      ),
    ];
  }
}