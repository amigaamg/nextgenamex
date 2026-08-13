// =============================================================================
// AMEXAN Clinical CPU — ClinicalCPU
// The single entry point the rest of the world calls:
//
//   const result = await clinicalCPU.process({ patientId, encounterId, event });
//
// One event in → a full nephron pass out. The CPU persists the event, ingests
// the new input, rebuilds the PatientClinicalState, runs every engine, persists
// a state snapshot, and returns the ClinicalRuntimeProjection the UI renders.
// =============================================================================

import type { Db } from '../db.js';
import { ContextResolver } from '../context/ContextResolver.js';
import { FactIngestionEngine } from '../ingestion/FactIngestionEngine.js';
import { DecisionEngine, isClinicianDecision } from '../decisions/DecisionEngine.js';
import { GovernanceEngine } from '../governance/GovernanceEngine.js';
import { ClinicalEventBus } from '../events/ClinicalEventBus.js';
import type { ClinicalRuntimeProjection, ProcessRequest } from '../types.js';
import { CPUOrchestrator } from './CPUOrchestrator.js';

export class ClinicalCPU {
  private readonly eventBus: ClinicalEventBus;
  private readonly contextResolver: ContextResolver;
  private readonly ingestion: FactIngestionEngine;
  private readonly decisions: DecisionEngine;
  private readonly orchestrator: CPUOrchestrator;
  private readonly governance: GovernanceEngine;

  constructor(private readonly db: Db) {
    this.eventBus = new ClinicalEventBus(db);
    this.contextResolver = new ContextResolver(db);
    this.ingestion = new FactIngestionEngine(db);
    this.decisions = new DecisionEngine(db);
    this.orchestrator = new CPUOrchestrator(db);
    this.governance = new GovernanceEngine(db);
  }

  async process(request: ProcessRequest): Promise<ClinicalRuntimeProjection> {
    const eventId = await this.eventBus.record(request);

    if (isClinicianDecision(request.event)) {
      await this.decisions.handleDecision(request);
    } else {
      await this.ingestion.ingest(request);
    }

    const state = await this.contextResolver.resolve(request.patientId, request.encounterId ?? null);
    const projection = await this.orchestrator.run(state);
    projection.eventId = eventId;

    const recorded = await this.governance.record(request, eventId, state, projection);
    // Expose the H10 trace on the projection itself (§34-36): the UI can follow
    // a rendered computation to its reasoning run + clinical snapshot.
    if (projection.governance) {
      projection.governance.runId = recorded.runId;
      projection.governance.clinicalSnapshotId = recorded.clinicalSnapshotId;
    }
    await this.persistSnapshot(request, eventId, projection);
    return projection;
  }

  private async persistSnapshot(request: ProcessRequest, eventId: number, projection: ClinicalRuntimeProjection): Promise<void> {
    await this.db.query(
      `INSERT INTO cpu.state_snapshot (patient_id, encounter_id, event_id, state)
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
export { SafetyEngine, safetyProfileFromFacts } from '../treatment/SafetyEngine.js';
export { DocumentationEngine } from '../documentation/DocumentationEngine.js';
export { DecisionEngine } from '../decisions/DecisionEngine.js';
export { GovernanceEngine } from '../governance/GovernanceEngine.js';
export { ConfigurationResolver } from '../configuration/ConfigurationResolver.js';
