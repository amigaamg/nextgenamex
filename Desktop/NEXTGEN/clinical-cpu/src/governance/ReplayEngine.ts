// =============================================================================
// AMEXAN Clinical CPU — ReplayEngine (H10 §30/§31)
// Deterministic, read-only reconstruction of a historical clinical computation.
//
// The replay engine:
//   1. Loads the original reasoning_run envelope.
//   2. Loads the exact clinical/reasoning/documentation snapshots.
//   3. Verifies the stored patient-state fingerprint.
//   4. Reconstructs the patient state from the historical snapshot.
//   5. Re-runs the CPU against that reconstructed state.
//   6. Re-evaluates the H10 knowledge gate.
//   7. Compares stored vs recomputed reasoning and documentation.
//   8. Returns the complete historical audit/provenance trail.
//
// IMPORTANT:
//   - Replay NEVER writes.
//   - Replay NEVER mutates historical records.
//   - Replay NEVER silently claims that current knowledge is historically
//     identical to the knowledge used at the original run.
//   - "matches" means the recorded state and current recomputation are equal
//     for the explicitly compared artifacts.
// =============================================================================

import type { Db, Row } from '../db.js';
import { canonicalize, inputFingerprint } from './fingerprint.js';
import type {
  ClinicalRuntimeProjection,
  DocumentationSection,
  Fact,
  KnowledgeGateResult,
  PatientClinicalState,
} from '../types.js';
import { CPUOrchestrator } from '../runtime/CPUOrchestrator.js';
import { KnowledgeResolver } from './KnowledgeResolver.js';

interface RunRow extends Row {
  run_id: string;
  patient_id: string | null;
  encounter_id: string | null;
  knowledge_version: string | null;
  engine_version: string | null;
  status: string;
  started_at: string;
}

export interface ReplayedCandidateState {
  conditionCode: string;
  name: string;
  compatibility: number;
  viaPhenotypes: { phenotypeCode: string; weight: number }[];
}

interface ReasoningSnapshotRow extends Row {
  clinical_snapshot_id: string;
  run_id: string | null;
  reasoning_version_code: string | null;
  candidate_states: ReplayedCandidateState[] | null;
}

interface SnapshotPatientFacts {
  ageYears: number | null;
  sex: string | null;
  activeSymptoms: string[];
  facts: {
    factCode: string;
    statusCode: string;
    values: Fact['values'];
  }[];
}

interface SnapshotKnowledgeState {
  reasoningVersion?: string | null;
  documentationVersion?: string | null;
  differentialRuleset?: string | null;
  protocol?: string | null;
  gate?: KnowledgeGateResult | null;
}

interface ClinicalSnapshotRow extends Row {
  id: string;
  patient_id: string | null;
  encounter_id: string | null;
  captured_at: string;
  system_version_code: string | null;
  reasoning_version_code: string | null;
  documentation_version_code: string | null;
  patient_facts: SnapshotPatientFacts | null;
  knowledge_state: SnapshotKnowledgeState | null;
  input_fingerprint: string | null;
}

interface DocumentationSnapshotRow extends Row {
  sections: DocumentationSection[] | null;
  documentation_version_code: string | null;
}

export interface ReplayRuleExecution extends Row {
  rule_code: string;
  object_code: string | null;
  knowledge_version: string | null;
  input_facts: unknown;
  output: unknown;
  executed_at: string;
}

export interface ReplayAuditEvent extends Row {
  event_type: string;
  actor_type: string;
  entity_type: string | null;
  entity_code: string | null;
  new_value: string | null;
  occurred_at: string;
}

export interface ReplayProvenance extends Row {
  direction: string;
  source_claim_code: string | null;
  governance_object_code: string | null;
  fact_code: string | null;
  link_type: string;
}

export interface ReplayResult {
  runId: string;
  snapshotId: string;
  capturedAt: string;

  run: {
    status: string;
    knowledgeVersion: string | null;
    engineVersion: string | null;
    startedAt: string;
  };

  versions: {
    system: string | null;
    reasoning: string | null;
    documentation: string | null;
    differentialRuleset: string | null;
  };

  patient: {
    patientId: string;
    encounterId: string | null;
    ageYears: number | null;
    sex: string | null;
    activeSymptoms: string[];
  };

  fingerprint: {
    stored: string | null;
    recomputed: string;
    matches: boolean;
  };

  gate: KnowledgeGateResult;

  reasoning: {
    stored: ReplayedCandidateState[];
    recomputed: ReplayedCandidateState[];
    matches: boolean;
  };

  documentation: {
    stored: DocumentationSection[];
    recomputed: DocumentationSection[];
    matches: boolean;
  };

  matches: boolean;

  ruleExecutions: ReplayRuleExecution[];
  auditEvents: ReplayAuditEvent[];
  provenance: ReplayProvenance[];
}

export class ReplayEngine {
  private readonly orchestrator: CPUOrchestrator;
  private readonly resolver: KnowledgeResolver;

  constructor(private readonly db: Db) {
    this.orchestrator = new CPUOrchestrator(db);
    this.resolver = new KnowledgeResolver(db);
  }

  // ===========================================================================
  // PUBLIC REPLAY API
  // ===========================================================================

  async reconstruct(runId: string): Promise<ReplayResult> {
    if (!runId || runId.trim().length === 0) {
      throw new Error('runId is required for replay');
    }

    // -------------------------------------------------------------------------
    // 1. Load the original computation envelope.
    // -------------------------------------------------------------------------
    const run = await this.db.queryOne<RunRow>(
      `SELECT
          run_id,
          patient_id,
          encounter_id,
          knowledge_version,
          engine_version,
          status,
          started_at
       FROM knowledge.reasoning_run
       WHERE run_id = $1`,
      [runId],
    );

    if (!run) {
      throw new Error(`no reasoning_run ${runId} to replay`);
    }

    // -------------------------------------------------------------------------
    // 2. Load the H8 reasoning snapshot.
    // -------------------------------------------------------------------------
    const reasoningSnapshot =
      await this.db.queryOne<ReasoningSnapshotRow>(
        `SELECT
            clinical_snapshot_id,
            run_id,
            reasoning_version_code,
            candidate_states
         FROM governance.reasoning_snapshot
         WHERE run_id = $1
         ORDER BY clinical_snapshot_id
         LIMIT 1`,
        [runId],
      );

    if (!reasoningSnapshot) {
      throw new Error(
        `no reasoning_snapshot recorded for run ${runId} — ` +
          'replay requires an H10 recorded computation',
      );
    }

    if (
      reasoningSnapshot.run_id !== null &&
      reasoningSnapshot.run_id !== runId
    ) {
      throw new Error(
        `reasoning_snapshot ${reasoningSnapshot.clinical_snapshot_id} ` +
          `does not belong to reasoning_run ${runId}`,
      );
    }

    // -------------------------------------------------------------------------
    // 3. Load the clinical snapshot.
    // -------------------------------------------------------------------------
    const snapshot = await this.db.queryOne<ClinicalSnapshotRow>(
      `SELECT
          id,
          patient_id,
          encounter_id,
          captured_at,
          system_version_code,
          reasoning_version_code,
          documentation_version_code,
          patient_facts,
          knowledge_state,
          input_fingerprint
       FROM governance.clinical_snapshot
       WHERE id = $1`,
      [reasoningSnapshot.clinical_snapshot_id],
    );

    if (!snapshot) {
      throw new Error(
        `no clinical_snapshot ${reasoningSnapshot.clinical_snapshot_id}`,
      );
    }

    if (
      snapshot.patient_id !== null &&
      run.patient_id !== null &&
      snapshot.patient_id !== run.patient_id
    ) {
      throw new Error(
        `clinical snapshot ${snapshot.id} does not belong to reasoning_run ${runId}`,
      );
    }

    if (
      snapshot.encounter_id !== null &&
      run.encounter_id !== null &&
      snapshot.encounter_id !== run.encounter_id
    ) {
      throw new Error(
        `clinical snapshot ${snapshot.id} has a different encounter from reasoning_run ${runId}`,
      );
    }

    // -------------------------------------------------------------------------
    // 4. Load the H9 documentation snapshot.
    // -------------------------------------------------------------------------
    const documentationSnapshot =
      await this.db.queryOne<DocumentationSnapshotRow>(
        `SELECT
            sections,
            documentation_version_code
         FROM governance.documentation_snapshot
         WHERE clinical_snapshot_id = $1
         ORDER BY clinical_snapshot_id
         LIMIT 1`,
        [snapshot.id],
      );

    // -------------------------------------------------------------------------
    // 5. Reconstruct the exact patient state captured at the time.
    // -------------------------------------------------------------------------
    const state = rebuildState(snapshot);

    // -------------------------------------------------------------------------
    // 6. Verify the historical fingerprint before replay.
    //
    // A fingerprint mismatch means the stored patient state and its integrity
    // hash no longer agree. Replay must still be possible for investigation,
    // but the result must explicitly report that integrity failure.
    // -------------------------------------------------------------------------
    const recomputedFingerprint = inputFingerprint(state.facts);
    const fingerprintMatches =
      snapshot.input_fingerprint !== null &&
      snapshot.input_fingerprint === recomputedFingerprint;

    // -------------------------------------------------------------------------
    // 7. Re-run the CPU against the reconstructed state.
    //
    // This is intentionally the CURRENT CPU/knowledge environment. The result
    // is therefore a reconstruction comparison, not a claim that the current
    // knowledge state is identical to the historical knowledge state.
    // -------------------------------------------------------------------------
    const recomputed = await this.orchestrator.run(state);

    // -------------------------------------------------------------------------
    // 8. Compare H8 reasoning.
    // -------------------------------------------------------------------------
    const storedReasoning =
      normalizeCandidateStates(reasoningSnapshot.candidate_states);

    const recomputedReasoning = normalizeCandidateStates(
      recomputed.differentials.map((candidate) => ({
        conditionCode: candidate.conditionCode,
        name: candidate.name,
        compatibility: candidate.compatibility,
        viaPhenotypes: candidate.viaPhenotypes,
      })),
    );

    const reasoningMatches = deepCanonicalEqual(
      storedReasoning,
      recomputedReasoning,
    );

    // -------------------------------------------------------------------------
    // 9. Compare H9 documentation.
    // -------------------------------------------------------------------------
    const storedDocumentation =
      documentationSnapshot?.sections ?? [];

    const recomputedDocumentation =
      recomputed.documentation ?? [];

    const documentationMatches = deepCanonicalEqual(
      storedDocumentation,
      recomputedDocumentation,
    );

    // -------------------------------------------------------------------------
    // 10. Re-run H10 governance against the knowledge actually touched by the
    // current reconstruction.
    // -------------------------------------------------------------------------
    const gate = await this.resolver.gate(
      usedTargets(recomputed),
    );

    // -------------------------------------------------------------------------
    // 11. Retrieve the immutable historical execution trail.
    // -------------------------------------------------------------------------
    const [ruleExecutions, auditEvents, provenance] =
      await Promise.all([
        this.loadRuleExecutions(runId),
        this.loadAuditEvents(runId),
        this.loadProvenance(runId),
      ]);

    // -------------------------------------------------------------------------
    // 12. Overall replay equality.
    //
    // "matches" is deliberately strict:
    //   fingerprint + H8 reasoning + H9 documentation
    //
    // Governance differences are exposed separately through `gate`; they are
    // not silently folded into the equality result.
    // -------------------------------------------------------------------------
    const matches =
      fingerprintMatches &&
      reasoningMatches &&
      documentationMatches;

    return {
      runId,
      snapshotId: snapshot.id,
      capturedAt: snapshot.captured_at,

      run: {
        status: run.status,
        knowledgeVersion: run.knowledge_version,
        engineVersion: run.engine_version,
        startedAt: run.started_at,
      },

      versions: {
        system: snapshot.system_version_code,
        reasoning:
          snapshot.reasoning_version_code ??
          reasoningSnapshot.reasoning_version_code ??
          null,
        documentation:
          snapshot.documentation_version_code ??
          documentationSnapshot?.documentation_version_code ??
          null,
        differentialRuleset:
          snapshot.knowledge_state?.differentialRuleset ??
          null,
      },

      patient: {
        patientId: snapshot.patient_id ?? '',
        encounterId: snapshot.encounter_id,
        ageYears: snapshot.patient_facts?.ageYears ?? null,
        sex: snapshot.patient_facts?.sex ?? null,
        activeSymptoms:
          snapshot.patient_facts?.activeSymptoms ?? [],
      },

      fingerprint: {
        stored: snapshot.input_fingerprint,
        recomputed: recomputedFingerprint,
        matches: fingerprintMatches,
      },

      gate,

      reasoning: {
        stored: storedReasoning,
        recomputed: recomputedReasoning,
        matches: reasoningMatches,
      },

      documentation: {
        stored: storedDocumentation,
        recomputed: recomputedDocumentation,
        matches: documentationMatches,
      },

      matches,

      ruleExecutions,
      auditEvents,
      provenance,
    };
  }

  // ===========================================================================
  // HISTORICAL EXECUTION TRAIL
  // ===========================================================================

  private async loadRuleExecutions(
    runId: string,
  ): Promise<ReplayRuleExecution[]> {
    return this.db.query<ReplayRuleExecution>(
      `SELECT
          re.rule_code,
          ko.object_code,
          re.knowledge_version,
          re.input_facts,
          re.output,
          re.executed_at
       FROM governance.rule_execution re
       LEFT JOIN governance.knowledge_object ko
         ON ko.id = re.object_id
       WHERE re.run_id = $1
       ORDER BY re.executed_at ASC`,
      [runId],
    );
  }

  private async loadAuditEvents(
    runId: string,
  ): Promise<ReplayAuditEvent[]> {
    return this.db.query<ReplayAuditEvent>(
      `SELECT
          event_type,
          actor_type,
          entity_type,
          entity_code,
          new_value,
          occurred_at
       FROM governance.audit_event
       WHERE run_id = $1
       ORDER BY occurred_at ASC`,
      [runId],
    );
  }

  private async loadProvenance(
    runId: string,
  ): Promise<ReplayProvenance[]> {
    return this.db.query<ReplayProvenance>(
      `SELECT
          direction,
          source_claim_code,
          governance_object_code,
          fact_code,
          link_type
       FROM governance.provenance_record
       WHERE reasoning_run_id = $1
       ORDER BY created_at ASC`,
      [runId],
    );
  }
}

// =============================================================================
// SNAPSHOT → PATIENT STATE
// =============================================================================

/**
 * Rebuild the exact PatientClinicalState represented by the historical
 * clinical_snapshot.
 *
 * The original snapshot intentionally contains the clinically relevant
 * captured state rather than live patient-table references. This prevents
 * later edits to the patient chart from changing what replay means.
 */
function rebuildState(
  snapshot: ClinicalSnapshotRow,
): PatientClinicalState {
  const stored = snapshot.patient_facts;

  const facts: Fact[] = (stored?.facts ?? []).map(
    (fact, index): Fact => ({
      id: `replay-${snapshot.id}-${index}`,
      patientId: snapshot.patient_id ?? '',
      encounterId: snapshot.encounter_id,
      factCode: fact.factCode,
      statusCode: fact.statusCode,
      recordedAt: snapshot.captured_at,
      sourceType: 'REPLAY_SNAPSHOT',
      values: fact.values,
    }),
  );

  return {
    patientId: snapshot.patient_id ?? '',
    encounterId: snapshot.encounter_id,

    ageYears: stored?.ageYears ?? null,
    sex: stored?.sex ?? null,

    activeSymptoms: [
      ...(stored?.activeSymptoms ?? []),
    ],

    facts,

    // The historical snapshot does not currently persist answered question
    // identifiers, so replay must not invent them.
    answeredQuestions: [],
  };
}

// =============================================================================
// KNOWLEDGE TARGET EXTRACTION
// =============================================================================

/**
 * Extract every runtime knowledge object exposed by the recomputed projection.
 *
 * Duplicates are removed before the H10 resolver is called. This makes the
 * gate deterministic and prevents the same object being counted multiple times
 * merely because several downstream outputs reference it.
 */
function usedTargets(
  projection: ClinicalRuntimeProjection,
): { kind: string; code: string }[] {
  const targets: { kind: string; code: string }[] = [];
  const seen = new Set<string>();

  const add = (kind: string, code: string | null | undefined): void => {
    if (!code) return;

    const key = `${kind}:${code}`;

    if (seen.has(key)) return;

    seen.add(key);
    targets.push({ kind, code });
  };

  for (const phenotype of projection.phenotypes) {
    add('phenotype', phenotype.phenotypeCode);
  }

  for (const candidate of projection.differentials) {
    add('condition', candidate.conditionCode);
  }

  if (projection.protocol) {
    add('protocol', projection.protocol.protocolCode);
  }

  for (const investigation of projection.investigations) {
    add('investigation', investigation.investigationCode);
  }

  for (const treatment of projection.treatment) {
    add('medication', treatment.medicationCode);
  }

  return targets;
}

// =============================================================================
// NORMALIZATION / COMPARISON
// =============================================================================

function normalizeCandidateStates(
  states: ReplayedCandidateState[] | null | undefined,
): ReplayedCandidateState[] {
  return (states ?? []).map((state) => ({
    conditionCode: state.conditionCode,
    name: state.name,
    compatibility: state.compatibility,
    viaPhenotypes: (state.viaPhenotypes ?? []).map((item) => ({
      phenotypeCode: item.phenotypeCode,
      weight: item.weight,
    })),
  }));
}

/**
 * Canonical structural comparison.
 *
 * JSON.stringify alone is unsafe for semantic equality when object-key order
 * differs. canonicalize() provides deterministic object ordering before
 * serialization.
 */
function deepCanonicalEqual(
  left: unknown,
  right: unknown,
): boolean {
  return (
    JSON.stringify(canonicalize(left)) ===
    JSON.stringify(canonicalize(right))
  );
}