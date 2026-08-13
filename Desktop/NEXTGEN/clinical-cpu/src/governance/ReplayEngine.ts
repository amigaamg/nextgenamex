// =============================================================================
// AMEXAN Clinical CPU — ReplayEngine (H10 §30/§31)
// The replay engine. Spec §30: "Reconstruct exactly what AMEXAN knew and what
// it did." Given a historical reasoning run, this engine rebuilds the recorded
// clinical snapshot (patient facts + knowledge versions + input fingerprint),
// re-runs the current orchestrator over those exact facts, and reports whether
// the recomputed reasoning/documentation matches the stored result.
//
//   reconstruct(runId):
//     1. load the reasoning_run envelope + clinical/reasoning/documentation
//        snapshots recorded by GovernanceEngine at the original computation
//     2. verify the input fingerprint (deterministic sha256 of the fact state)
//     3. rebuild the PatientClinicalState exactly as captured
//     4. re-run the nephron against those historical facts (current knowledge)
//     5. compare stored vs recomputed H8 reasoning + H9 documentation
//     6. return rule_executions / audit_events / provenance for the run
//
// Replay is a READ-ONLY investigation — nothing is written, nothing changes.
// A historical computation is never silently reinterpreted (§9/§49): the
// system_version in the snapshot records which knowledge was active then.
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

// The H8 differential state captured in a reasoning_snapshot (the engine's
// per-condition view — not the full evidence detail).
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

interface ClinicalSnapshotRow extends Row {
  id: string;
  patient_id: string | null;
  encounter_id: string | null;
  captured_at: string;
  system_version_code: string | null;
  reasoning_version_code: string | null;
  documentation_version_code: string | null;
  patient_facts: {
    ageYears: number | null;
    sex: string | null;
    activeSymptoms: string[];
    facts: { factCode: string; statusCode: string; values: Fact['values'] }[];
  } | null;
  knowledge_state: { differentialRuleset: string | null; gate: KnowledgeGateResult | null } | null;
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
  run: { status: string; knowledgeVersion: string | null; engineVersion: string | null; startedAt: string };
  versions: {
    system: string | null;
    reasoning: string | null;
    documentation: string | null;
    differentialRuleset: string | null;
  };
  patient: { patientId: string; encounterId: string | null; ageYears: number | null; sex: string | null; activeSymptoms: string[] };
  fingerprint: { stored: string | null; recomputed: string; matches: boolean };
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

  async reconstruct(runId: string): Promise<ReplayResult> {
    const run = await this.db.queryOne<RunRow>(
      `SELECT run_id, patient_id, encounter_id, knowledge_version, engine_version, status, started_at
         FROM knowledge.reasoning_run WHERE run_id = $1`,
      [runId],
    );
    if (!run) throw new Error(`no reasoning_run ${runId} to replay`);

    const reasonSnap = await this.db.queryOne<ReasoningSnapshotRow>(
      `SELECT clinical_snapshot_id, run_id, reasoning_version_code, candidate_states
         FROM governance.reasoning_snapshot WHERE run_id = $1`,
      [runId],
    );
    if (!reasonSnap) throw new Error(`no reasoning_snapshot recorded for run ${runId} — replay requires an H10 recorded computation`);

    const snapshot = await this.db.queryOne<ClinicalSnapshotRow>(
      `SELECT id, patient_id, encounter_id, captured_at, system_version_code,
              reasoning_version_code, documentation_version_code,
              patient_facts, knowledge_state, input_fingerprint
         FROM governance.clinical_snapshot WHERE id = $1`,
      [reasonSnap.clinical_snapshot_id],
    );
    if (!snapshot) throw new Error(`no clinical_snapshot ${reasonSnap.clinical_snapshot_id}`);

    const docSnap = await this.db.queryOne<DocumentationSnapshotRow>(
      `SELECT sections, documentation_version_code
         FROM governance.documentation_snapshot WHERE clinical_snapshot_id = $1`,
      [snapshot.id],
    );

    const state = rebuildState(snapshot);
    const recomputed = await this.orchestrator.run(state);
    const recomputedFingerprint = inputFingerprint(state.facts);

    const storedReasoning = reasonSnap.candidate_states ?? [];
    const recomputedReasoning = recomputed.differentials.map((d) => ({
      conditionCode: d.conditionCode,
      name: d.name,
      compatibility: d.compatibility,
      viaPhenotypes: d.viaPhenotypes,
    }));
    const reasoningMatches = JSON.stringify(canonicalize(storedReasoning)) === JSON.stringify(canonicalize(recomputedReasoning));

    const storedDocumentation = docSnap?.sections ?? [];
    const recomputedDocumentation = recomputed.documentation;
    const documentationMatches = JSON.stringify(canonicalize(storedDocumentation)) === JSON.stringify(canonicalize(recomputedDocumentation));

    const gate = await this.resolver.gate(usedTargets(recomputed));

    const ruleExecutions = await this.db.query<ReplayRuleExecution>(
      `SELECT re.rule_code, ko.object_code, re.knowledge_version, re.input_facts, re.output, re.executed_at
         FROM governance.rule_execution re
         LEFT JOIN governance.knowledge_object ko ON ko.id = re.object_id
        WHERE re.run_id = $1
        ORDER BY re.executed_at`,
      [runId],
    );
    const auditEvents = await this.db.query<ReplayAuditEvent>(
      `SELECT event_type, actor_type, entity_type, entity_code, new_value, occurred_at
         FROM governance.audit_event WHERE run_id = $1 ORDER BY occurred_at`,
      [runId],
    );
    const provenance = await this.db.query<ReplayProvenance>(
      `SELECT direction, source_claim_code, governance_object_code, fact_code, link_type
         FROM governance.provenance_record WHERE reasoning_run_id = $1 ORDER BY created_at`,
      [runId],
    );

    const fingerprintMatches = snapshot.input_fingerprint === recomputedFingerprint;
    const matches = fingerprintMatches && reasoningMatches && documentationMatches;

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
        reasoning: snapshot.reasoning_version_code,
        documentation: snapshot.documentation_version_code,
        differentialRuleset: snapshot.knowledge_state?.differentialRuleset ?? null,
      },
      patient: {
        patientId: snapshot.patient_id ?? '',
        encounterId: snapshot.encounter_id,
        ageYears: snapshot.patient_facts?.ageYears ?? null,
        sex: snapshot.patient_facts?.sex ?? null,
        activeSymptoms: snapshot.patient_facts?.activeSymptoms ?? [],
      },
      fingerprint: { stored: snapshot.input_fingerprint, recomputed: recomputedFingerprint, matches: fingerprintMatches },
      gate,
      reasoning: { stored: storedReasoning, recomputed: recomputedReasoning, matches: reasoningMatches },
      documentation: { stored: storedDocumentation, recomputed: recomputedDocumentation, matches: documentationMatches },
      matches,
      ruleExecutions,
      auditEvents,
      provenance,
    };
  }
}

// Rebuild the exact PatientClinicalState the original computation saw, so the
// recomputation is reproducible (§30). Facts are reconstructed 1:1 from the
// snapshot's patient_facts jsonb (factCode, statusCode, values, order).
function rebuildState(snapshot: ClinicalSnapshotRow): PatientClinicalState {
  const stored = snapshot.patient_facts;
  const facts: Fact[] = (stored?.facts ?? []).map((f, index) => ({
    id: `replay-${snapshot.id}-${index}`,
    patientId: snapshot.patient_id ?? '',
    encounterId: snapshot.encounter_id,
    factCode: f.factCode,
    statusCode: f.statusCode,
    recordedAt: snapshot.captured_at,
    sourceType: null,
    values: f.values,
  }));
  return {
    patientId: snapshot.patient_id ?? '',
    encounterId: snapshot.encounter_id,
    ageYears: stored?.ageYears ?? null,
    sex: stored?.sex ?? null,
    activeSymptoms: stored?.activeSymptoms ?? [],
    facts,
    answeredQuestions: [],
  };
}

// The knowledge the recomputed projection used — the targets H10 gates (§37).
function usedTargets(projection: ClinicalRuntimeProjection): { kind: string; code: string }[] {
  const targets: { kind: string; code: string }[] = [];
  for (const phenotype of projection.phenotypes) targets.push({ kind: 'phenotype', code: phenotype.phenotypeCode });
  for (const candidate of projection.differentials) targets.push({ kind: 'condition', code: candidate.conditionCode });
  if (projection.protocol) targets.push({ kind: 'protocol', code: projection.protocol.protocolCode });
  return targets;
}
