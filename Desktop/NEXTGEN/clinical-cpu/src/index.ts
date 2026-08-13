// =============================================================================
// AMEXAN Clinical CPU — public entry
// =============================================================================

export { ClinicalCPU } from './runtime/ClinicalCPU.js';
export { CPUOrchestrator } from './runtime/CPUOrchestrator.js';
export { GovernanceEngine } from './governance/GovernanceEngine.js';
export { KnowledgeResolver } from './governance/KnowledgeResolver.js';
export { ReplayEngine } from './governance/ReplayEngine.js';
export { SafetyEngine, safetyProfileFromFacts } from './treatment/SafetyEngine.js';
export { ExaminationInterpreter } from './examination/ExaminationInterpreter.js';
export { ResultInterpreter } from './investigation/ResultInterpreter.js';
export { ConfigurationResolver } from './configuration/ConfigurationResolver.js';
export { ContradictionEngine } from './differential/ContradictionEngine.js';
export { createPool, Db } from './db.js';
export type { Queryable, Row } from './db.js';
export type {
  AnswerOptionView,
  ClinicalEvent,
  ClinicalEventType,
  ClinicalRuntimeProjection,
  ConfigurationOverride,
  ContradictionProbe,
  DifferentialCandidate,
  DocumentationSection,
  EducationItem,
  EvidenceLine,
  ExaminationModuleView,
  Fact,
  FactValue,
  InvestigationRecommendation,
  KnowledgeGateEntry,
  KnowledgeGateResult,
  KnowledgeGateTarget,
  KnowledgeGateVerdict,
  MechanismScore,
  MonitoringTarget,
  NextQuestion,
  PatientClinicalState,
  PhenotypeScore,
  ProcessRequest,
  ProtocolActionView,
  ProtocolStepView,
  ProtocolView,
  Recommendation,
  TreatmentRecommendation,
} from './types.js';
