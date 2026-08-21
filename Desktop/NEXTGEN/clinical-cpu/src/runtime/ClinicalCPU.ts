// =============================================================================
// AMEXAN Clinical CPU — ClinicalCPU
// =============================================================================
//
// THE UNIVERSAL CLINICAL RUNTIME ENTRY POINT
//
// ClinicalCPU is the boundary between the external clinical world and the
// AMEXAN Clinical Intelligence runtime.
//
// The outside world submits ONE clinical event:
//
//   clinicalCPU.process({
//     patientId,
//     encounterId,
//     event,
//   });
//
// The CPU then performs one complete deterministic clinical cycle:
//
//   EVENT
//     ↓
//   EVENT PERSISTENCE
//     ↓
//   CLINICAL INGESTION / CLINICIAN DECISION
//     ↓
//   PATIENT CONTEXT RECONSTRUCTION
//     ↓
//   PHENOTYPES
//     ↓
//   MECHANISMS
//     ↓
//   DIFFERENTIAL
//     ↓
//   CONTRADICTIONS
//     ↓
//   QUESTIONS
//     ↓
//   EXAMINATION
//     ↓
//   INVESTIGATIONS
//     ↓
//   PROTOCOL
//     ↓
//   MONITORING
//     ↓
//   SEVERITY
//     ↓
//   TREATMENT
//     ↓
//   SAFETY
//     ↓
//   EDUCATION
//     ↓
//   DOCUMENTATION
//     ↓
//   RECOMMENDATIONS
//     ↓
//   GOVERNANCE / TRACE
//     ↓
//   CLINICAL SNAPSHOT
//     ↓
//   RUNTIME PROJECTION
//
// IMPORTANT ARCHITECTURAL INVARIANTS
//
// 1. The UI is NOT the clinical intelligence.
//    The UI renders ClinicalRuntimeProjection.
//
// 2. The CPU is STATE-RECONSTRUCTING.
//    It does not reason from only the latest answer. It rebuilds the current
//    patient/encounter state from the persisted clinical event stream.
//
// 3. Facts are the universal clinical currency.
//    History, examination, investigations and other inputs eventually become
//    facts that downstream engines can consume.
//
// 4. A clinician decision is NOT treated as an ordinary patient fact.
//    It is handled through DecisionEngine so human decisions remain distinct
//    from machine-derived observations.
//
// 5. Every clinically meaningful computation must be traceable.
//    GovernanceEngine records the reasoning run and clinical snapshot.
//
// 6. Every returned projection is persistable.
//    The exact projection rendered to the UI is also stored as a state snapshot.
//
// 7. The CPU is closed-loop.
//    A new fact/result/decision causes the entire reasoning state to be
//    recalculated so relevance, differential, questions, investigations,
//    treatment and monitoring remain synchronized.
//
// 8. The CPU does not hard-code medicine.
//    Medical knowledge belongs in the knowledge layer and reusable engines.
//
// 9. The CPU must remain universal.
//    The same runtime supports medicine, surgery, paediatrics, O&G,
//    emergency care, chronic disease, inpatient and outpatient workflows.
//    Specialty behaviour comes from governed knowledge and context.
//
// 10. Unknown is NOT equivalent to negative.
//     Missing information remains unknown unless the event explicitly records
//     a negative finding.
//
// 11. Historical events are immutable.
//     A new event creates a new clinical state; previous events/snapshots remain
//     part of the audit trail.
//
// 12. The returned projection is the current clinical truth available to the
//     runtime at this computation point, not an irreversible diagnosis.
//
// =============================================================================

import type { Db } from '../db.js';

import { ContextResolver } from '../context/ContextResolver.js';
import { FactIngestionEngine } from '../ingestion/FactIngestionEngine.js';
import {
  DecisionEngine,
  isClinicianDecision,
} from '../decisions/DecisionEngine.js';
import { GovernanceEngine } from '../governance/GovernanceEngine.js';
import { ClinicalEventBus } from '../events/ClinicalEventBus.js';

import type {
  ClinicalRuntimeProjection,
  PatientClinicalState,
  ProcessRequest,
} from '../types.js';

import { CPUOrchestrator } from './CPUOrchestrator.js';
import { WorkflowEngine } from './WorkflowEngine.js';
import {
  JourneyEventType,
  recordJourneyEvent,
} from '../observability/EventCore.js';
import {
  RecordedRun,
  mirrorRuleExecutions,
  recordCpuRun,
  recordCpuRunFinalize,
  recordEventCheckpoint,
  recordProcessingError,
} from './CpuRunRecorder.js';


// =============================================================================
// ClinicalCPU
// =============================================================================
//
// This is intentionally the single public runtime entry point.
//
// Consumers should not have to know:
//
// - how facts are stored
// - how context is reconstructed
// - how phenotypes are calculated
// - how mechanisms are scored
// - how differentials are ranked
// - how questions are selected
// - how investigations are selected
// - how treatment is resolved
// - how governance is evaluated
// - how snapshots are persisted
//
// They submit an event and receive the current ClinicalRuntimeProjection.
//
// =============================================================================

export class ClinicalCPU {
  private readonly eventBus: ClinicalEventBus;
  private readonly contextResolver: ContextResolver;
  private readonly ingestion: FactIngestionEngine;
  private readonly decisions: DecisionEngine;
  private readonly orchestrator: CPUOrchestrator;
  private readonly governance: GovernanceEngine;
  private readonly workflow: WorkflowEngine;

  constructor(private readonly db: Db) {
    this.eventBus = new ClinicalEventBus(db);
    this.contextResolver = new ContextResolver(db);
    this.ingestion = new FactIngestionEngine(db);
    this.decisions = new DecisionEngine(db);
    this.orchestrator = new CPUOrchestrator(db);
    this.governance = new GovernanceEngine(db);
    this.workflow = new WorkflowEngine(db);
  }

  // ===========================================================================
  // PROCESS ONE CLINICAL EVENT
  // ===========================================================================
  //
  // This is the canonical AMEXAN clinical runtime operation.
  //
  // One event enters.
  // One complete reasoning pass occurs.
  // One projection leaves.
  //
  // Examples of events:
  //
  // - demographic information
  // - chief complaint
  // - symptom answer
  // - history answer
  // - examination finding
  // - laboratory result
  // - imaging result
  // - medication/allergy information
  // - clinician decision
  // - treatment response
  // - monitoring measurement
  //
  // The caller does NOT need to manually invoke PhenotypeEngine,
  // DifferentialEngine, QuestionSelector, etc.
  //
  // ===========================================================================

  async process(
    request: ProcessRequest,
  ): Promise<ClinicalRuntimeProjection> {

    // -------------------------------------------------------------------------
    // STEP 0 — BASIC REQUEST VALIDATION
    // -------------------------------------------------------------------------
    //
    // The CPU should never attempt clinical reasoning against an unidentified
    // patient or an empty event.
    //
    // Detailed event validation remains the responsibility of the event schema /
    // ingestion layer, but the runtime boundary should reject obviously invalid
    // identity information immediately.
    //
    if (!request.patientId || request.patientId.trim().length === 0) {
      throw new Error('ClinicalCPU.process requires patientId');
    }

    if (!request.event) {
      throw new Error('ClinicalCPU.process requires a clinical event');
    }

    // -------------------------------------------------------------------------
    // STEP 1 — IMMUTABLE EVENT RECORD
    // -------------------------------------------------------------------------
    //
    // The event is recorded BEFORE downstream computation.
    //
    // This gives AMEXAN an immutable chronological clinical event trail and
    // provides the eventId that identifies this CPU pass.
    //
    // The event is the cause.
    // The projection is the computed consequence.
    //
    const eventId = await this.eventBus.record(request);

    // -------------------------------------------------------------------------
    // EVENT CORE — CPU RUN TRACKING
    // -------------------------------------------------------------------------
    // A durable `cpu.run` row is opened for this pass so the admin Runtime view
    // can show run lifecycle, throughput and failure rates per engine pass. It
    // is finalised to `completed`/`failed` once the pass settles.
    // -------------------------------------------------------------------------
    const startedAt = new Date();
    const run = await recordCpuRun(this.db, {
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
      triggerEventId: eventId,
      triggerType: request.event.type,
    });

    // -------------------------------------------------------------------------
    // WORKFLOW — INSTANTIATE / ATTACH
    // -------------------------------------------------------------------------
    // Ensure the encounter has a durable workflow instance (drawn from the
    // governed definition for its encounter type). Subsequent passes attach
    // to the same instance and advance it toward the state its phase implies.
    // -------------------------------------------------------------------------
    if (request.encounterId) {
      const encounterType =
        (request.event.payload?.encounterType as string | undefined) ??
        (request.event.payload?.encounterTypeCode as string | undefined) ??
        null;
      await this.workflow.ensureInstance({
        patientId: request.patientId,
        encounterId: request.encounterId,
        encounterTypeCode: encounterType,
        createdBy: request.clinicianId ?? null,
      });
    }

    // -------------------------------------------------------------------------
    // EVENT CORE — CPU PASS STARTED
    // -------------------------------------------------------------------------
    // The Event Core is the nervous system. Every CPU pass announces itself so
    // the observatory can follow the journey and reconstruct causality.
    // -------------------------------------------------------------------------
    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.CPU_PASS_STARTED,
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
      sourceType: 'system',
      sourceId: 'clinical-cpu',
      parentEventId: eventId,
      payload: {
        eventType: request.event.type,
        eventId,
        clinicianId: request.clinicianId ?? null,
      },
    });

    // -------------------------------------------------------------------------
    // STEP 2 — INGEST THE EVENT INTO THE CLINICAL STATE
    // -------------------------------------------------------------------------
    //
    // There are two fundamentally different input classes:
    //
    // A. Clinical observations / results
    //    → FactIngestionEngine
    //
    // B. Explicit clinician decisions
    //    → DecisionEngine
    //
    // A clinician decision must not silently become a patient observation.
    //
    // For example:
    //
    //   "Patient has SpO2 84%"
    //
    // is an observed fact.
    //
    // Whereas:
    //
    //   "Clinician decides to admit patient"
    //
    // is a human decision.
    //
    // Keeping these separate is essential for provenance, explainability and
    // medico-legal traceability.
    //
    let state: PatientClinicalState | undefined;

    try {
      if (isClinicianDecision(request.event)) {
        await this.decisions.handleDecision(request);
      } else {
        await this.ingestion.ingest(request);
      }

      // -------------------------------------------------------------------------
      // STEP 3 — RECONSTRUCT THE CURRENT PATIENT CLINICAL STATE
      // -------------------------------------------------------------------------
      //
      // The CPU does NOT reason from the latest event alone.
      //
      // It asks ContextResolver for the current state of the patient/encounter.
      //
      // This is what makes the runtime persistent and closed-loop:
      //
      //       historical events
      //              +
      //       latest event
      //              ↓
      //       current clinical state
      //
      // ContextResolver is therefore the boundary between persisted clinical
      // history and the computational engines.
      //
      state = await this.contextResolver.resolve(
        request.patientId,
        request.encounterId ?? null,
      );
    } catch (error) {
      return this.failPass(request, eventId, run, startedAt, error);
    }

    // STEP 3 resolves the current clinical state (may be undefined only if a
    // failure was handled above, in which case this line is unreachable).
    if (!state) {
      return this.failPass(
        request,
        eventId,
        run,
        startedAt,
        new Error('State resolution did not return a clinical state'),
      );
    }

    // -------------------------------------------------------------------------
    // STEP 4 — RUN THE COMPLETE CLINICAL CPU
    // -------------------------------------------------------------------------
    //
    // CPUOrchestrator coordinates the reusable clinical engines.
    //
    // It is deliberately separated from ClinicalCPU:
    //
    // ClinicalCPU
    //   = persistence + ingestion + state reconstruction + governance
    //
    // CPUOrchestrator
    //   = clinical reasoning/computation
    //
    // This keeps the public runtime boundary clean while allowing the internal
    // clinical intelligence to evolve independently.
    //
    const projection = await this.orchestrator.run(state).catch(async (error) => {
      return this.failPass(request, eventId, run, startedAt, error);
    });

    // The projection belongs to THIS event/pass.
    projection.eventId = eventId;

    // -------------------------------------------------------------------------
    // EVENT CORE — CPU PASS COMPLETED
    // -------------------------------------------------------------------------
    // Record the engine lifecycle for this pass: per-stage timings, engine
    // outputs and governance outcome, so the observatory can render the
    // encounter journey and detect engine degradation over time.
    // -------------------------------------------------------------------------
    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.CPU_PASS_COMPLETED,
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
      sourceType: 'system',
      sourceId: 'clinical-cpu',
      parentEventId: eventId,
      payload: {
        eventId,
        cycle: projection.runtime?.cycle ?? null,
        timings: projection.runtime?.timings ?? [],
        counts: {
          phenotypes: projection.phenotypes.length,
          mechanisms: projection.mechanisms.length,
          differentials: projection.differentials.length,
          nextQuestions: projection.nextQuestions.length,
          investigations: projection.investigations.length,
          treatment: projection.treatment.length,
          alerts: projection.alerts.length,
          documentationSections: projection.documentation.length,
        },
        phase: projection.currentPhase,
        governanceRunId: projection.governance?.runId ?? null,
      },
    });

    // Per-engine lifecycle events: the observatory groups engine health by
    // these (source_id = stage name). Each completed stage of the orchestrated
    // CPU pass becomes one CPU_ENGINE_COMPLETED event so we can see exactly
    // which engine ran, for how long, and detect degradation over time.
    const timings = projection.runtime?.timings ?? [];
    for (const t of timings) {
      await recordJourneyEvent(this.db, {
        eventType: JourneyEventType.CPU_ENGINE_COMPLETED,
        patientId: request.patientId,
        encounterId: request.encounterId ?? null,
        sourceType: 'system',
        sourceId: `engine:${t.stage}`,
        parentEventId: eventId,
        payload: {
          engine: t.stage,
          milliseconds: t.milliseconds,
          cycle: projection.runtime?.cycle ?? null,
        },
      });
    }

    // -------------------------------------------------------------------------
    // STEP 5 — GOVERNANCE + COMPUTATION TRACE
    // -------------------------------------------------------------------------
    //
    // Every CPU pass is recorded by GovernanceEngine.
    //
    // This should provide the traceability chain:
    //
    //     event
    //       ↓
    //     reasoning run
    //       ↓
    //     clinical snapshot
    //       ↓
    //     rendered projection
    //
    // The runtime therefore does not merely say WHAT it returned.
    //
    // It can establish:
    //
    // - which event caused the computation
    // - what clinical state existed
    // - which knowledge was considered
    // - what governance gate was applied
    // - what reasoning run produced the projection
    // - what snapshot represents that computation
    //
    const recorded = await this.governance.record(
      request,
      eventId,
      state,
      projection,
    );

    // -------------------------------------------------------------------------
    // EVENT CORE — RULE EXECUTION MIRROR
    // -------------------------------------------------------------------------
    // The governed rule executions are mirrored into `cpu.rule_execution` with
    // run/patient/encounter dimensions so Runtime analytics can aggregate rule
    // activity, matched rates and latency without coupling to governance.
    // -------------------------------------------------------------------------
    await mirrorRuleExecutions(this.db, {
      cpuRunId: run.id,
      governanceRunId: recorded.runId,
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
    });

    // -------------------------------------------------------------------------
    // EVENT CORE — CPU RUN FINALISED
    // -------------------------------------------------------------------------
    // Close the `cpu.run` row opened at the start of the pass with the stage
    // timings and engine outputs so Runtime analytics can aggregate health.
    // -------------------------------------------------------------------------
    await recordCpuRunFinalize(this.db, run.id, {
      status: 'completed',
      completedAt: new Date(),
      durationMs: new Date().getTime() - startedAt.getTime(),
      eventsConsumed: 1,
      rulesEvaluated: projection.governance?.gate?.checked ?? 0,
      rulesTriggered: projection.recommendations.length,
      questionsActivated: projection.nextQuestions.length,
      recommendations: projection.recommendations.length,
      knowledgeVersion: null,
      cpuVersion: null,
      metadata: {
        phase: projection.currentPhase,
        cycle: projection.runtime?.cycle ?? null,
        governanceRunId: recorded.runId,
        engineTimings: timings,
      },
    });

    // -------------------------------------------------------------------------
    // EVENT CORE — CHECKPOINT ADVANCE
    // -------------------------------------------------------------------------
    // The worker advances its position in the event stream so the Runtime view
    // can show how far each worker has consumed and its lease state.
    // -------------------------------------------------------------------------
    await recordEventCheckpoint(this.db, {
      workerCode: `clinical-cpu:${request.patientId}`,
      lastEventId: eventId,
      leaseOwner: 'clinical-cpu',
      leaseSeconds: 120,
    });

    // -------------------------------------------------------------------------
    // STEP 6 — EXPOSE THE GOVERNANCE TRACE TO THE PROJECTION
    // -------------------------------------------------------------------------
    //
    // The UI must be able to trace what it renders without independently
    // reconstructing the governance model.
    //
    // The UI can therefore follow:
    //
    //     projection.governance.runId
    //     projection.governance.clinicalSnapshotId
    //
    // back to the governed CPU computation.
    //
    if (projection.governance) {
      projection.governance.runId = recorded.runId;
      projection.governance.clinicalSnapshotId =
        recorded.clinicalSnapshotId;
    }

    // -------------------------------------------------------------------------
    // STEP 7 — PERSIST THE EXACT RUNTIME PROJECTION
    // -------------------------------------------------------------------------
    //
    // The projection returned to the caller is persisted as the CPU state
    // snapshot.
    //
    // This is important because the projection is not merely UI state.
    //
    // It is the materialized result of the clinical computation at event N.
    //
    // Therefore:
    //
    //     EVENT N
    //       ↓
    //     STATE N
    //       ↓
    //     CPU COMPUTATION N
    //       ↓
    //     PROJECTION N
    //
    // Previous snapshots are not overwritten.
    //
    await this.persistSnapshot(
      request,
      eventId,
      projection,
    );

    // -------------------------------------------------------------------------
    // STEP 8 — WORKFLOW ADVANCE + TASKS
    // -------------------------------------------------------------------------
    // The resolved clinical phase is projected onto the encounter's governed
    // workflow state machine (walking only valid transitions), and active
    // recommendations become durable workflow tasks for operational queues.
    // -------------------------------------------------------------------------
    if (request.encounterId) {
      const phase = projection.currentPhase;
      const recommendations = projection.recommendations.map((r) => ({
        code: r.code,
        title: r.text,
        urgency: r.urgency,
      }));
      await this.workflow.advance({
        patientId: request.patientId,
        encounterId: request.encounterId,
        phase,
        recommendations,
        eventBy: request.clinicianId ?? null,
      });
      await this.workflow.recordTasks(
        request.patientId,
        request.encounterId,
        recommendations,
      );
      if (phase === 'disposition' || request.event.type === 'ENCOUNTER_DISPOSITIONED') {
        await this.workflow.complete(
          request.patientId,
          request.encounterId,
          request.clinicianId ?? null,
        );
      }
    }

    // -------------------------------------------------------------------------
    // STEP 9 — RETURN THE COMPLETE CLINICAL RUNTIME PROJECTION
    // -------------------------------------------------------------------------
    //
    // The caller receives the whole current clinical workspace state.
    //
    // The UI does not decide what medicine to ask, what investigation is
    // relevant, what phenotype is active, what differential is leading or what
    // treatment is appropriate.
    //
    // It renders this projection.
    //
    return projection;
  }

  /**
   * Failure path shared by every stage of a CPU pass: records the journey
   * failure, closes the `cpu.run` row as `failed` and writes a durable dead
   * letter to `cpu.processing_error` before re-throwing.
   */
  private async failPass(
    request: ProcessRequest,
    eventId: number,
    run: RecordedRun,
    startedAt: Date,
    error: unknown,
  ): Promise<never> {
    const message = error instanceof Error ? error.message : String(error);
    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.CPU_PASS_FAILED,
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
      sourceType: 'system',
      sourceId: 'clinical-cpu',
      parentEventId: eventId,
      payload: {
        eventId,
        eventType: request.event.type,
        error: message,
        stack: error instanceof Error ? error.stack : undefined,
      },
    });
    await recordCpuRunFinalize(this.db, run.id, {
      status: 'failed',
      completedAt: new Date(),
      durationMs: new Date().getTime() - startedAt.getTime(),
      errorCode: error instanceof Error ? error.name : 'Error',
      errorMessage: message,
    });
    await recordProcessingError(this.db, {
      runId: run.id,
      eventId,
      patientId: request.patientId,
      errorCode: error instanceof Error ? error.name : 'Error',
      errorMessage: message,
      stackTrace: error instanceof Error ? error.stack : undefined,
      retryable: true,
    });
    throw error;
  }

  // ===========================================================================
  // PERSIST CLINICAL CPU SNAPSHOT
  // ===========================================================================
  //
  // A snapshot is an immutable representation of the projection produced by a
  // specific CPU event.
  //
  // It enables:
  //
  // - audit
  // - replay
  // - debugging
  // - clinical timeline reconstruction
  // - governance inspection
  // - deterministic comparison between CPU runs
  // - recovery after UI/session failure
  // - historical reconstruction
  //
  // ===========================================================================

  private async persistSnapshot(
    request: ProcessRequest,
    eventId: number,
    projection: ClinicalRuntimeProjection,
  ): Promise<void> {

    await this.db.query(
      `INSERT INTO cpu.state_snapshot (
         patient_id,
         encounter_id,
         event_id,
         state
       )
       VALUES ($1, $2, $3, $4::jsonb)`,
      [
        request.patientId,
        request.encounterId ?? null,
        eventId,
        JSON.stringify(projection),
      ],
    );
  }
}


// =============================================================================
// AMEXAN CLINICAL CPU PUBLIC ENGINE EXPORTS
// =============================================================================
//
// These exports expose the reusable clinical intelligence components without
// forcing external consumers to understand their internal filesystem structure.
//
// ClinicalCPU remains the preferred entry point.
//
// Direct engine imports are useful for:
//
// - testing
// - administrative tooling
// - knowledge validation
// - simulation
// - batch reasoning
// - clinical education
// - controlled internal workflows
//
// They should not be used by the ordinary clinical UI as a substitute for the
// complete ClinicalCPU.process() lifecycle.
//
// =============================================================================

export { ClinicalEventBus } from '../events/ClinicalEventBus.js';

export { ContextResolver } from '../context/ContextResolver.js';

export { FactIngestionEngine } from '../ingestion/FactIngestionEngine.js';

export { PhenotypeEngine } from '../phenotype/PhenotypeEngine.js';

export { MechanismEngine } from '../mechanism/MechanismEngine.js';

export { DifferentialEngine } from '../differential/DifferentialEngine.js';

export { ContradictionEngine } from '../differential/ContradictionEngine.js';

export { QuestionSelector } from '../questions/QuestionSelector.js';

export { ProtocolEngine } from '../protocol/ProtocolEngine.js';

export { MonitoringEngine } from '../monitoring/MonitoringEngine.js';

export { EducationEngine } from '../education/EducationEngine.js';

export { ExaminationSelector } from '../examination/ExaminationSelector.js';

export { ExaminationInterpreter } from '../examination/ExaminationInterpreter.js';

export { InvestigationSelector } from '../investigation/InvestigationSelector.js';

export { ResultInterpreter } from '../investigation/ResultInterpreter.js';

export { TreatmentEngine } from '../treatment/TreatmentEngine.js';

export {
  SafetyEngine,
  safetyProfileFromFacts,
} from '../treatment/SafetyEngine.js';

export { DocumentationEngine } from '../documentation/DocumentationEngine.js';

export { DecisionEngine } from '../decisions/DecisionEngine.js';

export { GovernanceEngine } from '../governance/GovernanceEngine.js';

export { ConfigurationResolver } from '../configuration/ConfigurationResolver.js';