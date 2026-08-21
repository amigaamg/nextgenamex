// =============================================================================
// AMEXAN Clinical CPU — Public Entry Point
//
// This file defines the public API of the AMEXAN Clinical CPU package.
//
// Internal implementation modules remain encapsulated behind this boundary.
// Consumers of the CPU should import clinical runtime services, engines,
// database primitives, and public domain types from this entry point rather
// than reaching into internal implementation paths.
//
// Public architecture:
//
//     Application / API / Clinical Workspace
//                    │
//                    ▼
//             ClinicalCPU
//                    │
//                    ▼
//             CPUOrchestrator
//                    │
//        ┌───────────┴───────────┐
//        │       CPU Engines     │
//        └───────────┬───────────┘
//                    │
//                    ▼
//               PostgreSQL
//
// The public API intentionally exposes both:
//   • the complete ClinicalCPU runtime entry point;
//   • selected engines required by integrations, testing, administration,
//     replay, governance, and clinical interpretation;
//   • the database adapter;
//   • the complete public clinical type surface.
//
// No UI implementation belongs here.
// No clinical rules belong here.
// No database schema logic belongs here.
//
// =============================================================================

// -----------------------------------------------------------------------------
// Clinical runtime
// -----------------------------------------------------------------------------

export { ClinicalCPU } from './runtime/ClinicalCPU.js';
export { CPUOrchestrator } from './runtime/CPUOrchestrator.js';

// -----------------------------------------------------------------------------
// Universal clinical workspace
// -----------------------------------------------------------------------------

export { FormatResolver } from './format/FormatResolver.js';
export { SectionEngine } from './section/SectionEngine.js';

// -----------------------------------------------------------------------------
// Knowledge governance
// -----------------------------------------------------------------------------

export { GovernanceEngine } from './governance/GovernanceEngine.js';
export { KnowledgeResolver } from './governance/KnowledgeResolver.js';
export { ReplayEngine } from './governance/ReplayEngine.js';

// -----------------------------------------------------------------------------
// Treatment safety
// -----------------------------------------------------------------------------

export {
  SafetyEngine,
  safetyProfileFromFacts,
} from './treatment/SafetyEngine.js';

// -----------------------------------------------------------------------------
// Clinical interpretation
// -----------------------------------------------------------------------------

export { ExaminationInterpreter } from './examination/ExaminationInterpreter.js';
export { ResultInterpreter } from './investigation/ResultInterpreter.js';

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------

export { ConfigurationResolver } from './configuration/ConfigurationResolver.js';

// -----------------------------------------------------------------------------
// Differential reasoning
// -----------------------------------------------------------------------------

export { ContradictionEngine } from './differential/ContradictionEngine.js';

// -----------------------------------------------------------------------------
// Database
// -----------------------------------------------------------------------------

export {
  createPool,
  Db,
} from './db.js';

export type {
  Queryable,
  Row,
} from './db.js';

// =============================================================================
// Public Clinical Domain Types
// =============================================================================
//
// These types form the contract between the Clinical CPU and its consumers.
//
// Runtime code should return these structures.
// API layers may serialize them.
// UI layers may render them.
// Test suites may assert against them.
//
// The types remain implementation-independent: consumers do not need to know
// which internal engine produced a particular field.
//
// =============================================================================

export type {
  // ---------------------------------------------------------------------------
  // Questioning / history
  // ---------------------------------------------------------------------------

  AnswerOptionView,
  NextQuestion,

  // ---------------------------------------------------------------------------
  // Clinical events
  // ---------------------------------------------------------------------------

  ClinicalEvent,
  ClinicalEventType,
  ProcessRequest,

  // ---------------------------------------------------------------------------
  // Patient state / facts
  // ---------------------------------------------------------------------------

  PatientClinicalState,
  Fact,
  FactValue,

  // ---------------------------------------------------------------------------
  // Clinical format / workspace
  // ---------------------------------------------------------------------------

  ClinicalFormatPlan,
  WorkspaceNavigationProjection,
  WorkspaceSectionProjection,
  WorkspaceSectionState,
  WorkspaceSubsectionProjection,

  // ---------------------------------------------------------------------------
  // Phenotype / mechanism / differential reasoning
  // ---------------------------------------------------------------------------

  PhenotypeScore,
  MechanismScore,
  DifferentialCandidate,
  ContradictionProbe,

  // ---------------------------------------------------------------------------
  // Evidence
  // ---------------------------------------------------------------------------

  EvidenceLine,

  // ---------------------------------------------------------------------------
  // Examination
  // ---------------------------------------------------------------------------

  ExaminationModuleView,

  // ---------------------------------------------------------------------------
  // Investigations
  // ---------------------------------------------------------------------------

  InvestigationRecommendation,

  // ---------------------------------------------------------------------------
  // Protocols
  // ---------------------------------------------------------------------------

  ProtocolActionView,
  ProtocolStepView,
  ProtocolView,

  // ---------------------------------------------------------------------------
  // Monitoring
  // ---------------------------------------------------------------------------

  MonitoringTarget,

  // ---------------------------------------------------------------------------
  // Treatment
  // ---------------------------------------------------------------------------

  TreatmentRecommendation,

  // ---------------------------------------------------------------------------
  // Education
  // ---------------------------------------------------------------------------

  EducationItem,

  // ---------------------------------------------------------------------------
  // Documentation
  // ---------------------------------------------------------------------------

  DocumentationSection,

  // ---------------------------------------------------------------------------
  // Recommendations
  // ---------------------------------------------------------------------------

  Recommendation,

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  ConfigurationOverride,

  // ---------------------------------------------------------------------------
  // Governance / knowledge gate
  // ---------------------------------------------------------------------------

  KnowledgeGateEntry,
  KnowledgeGateResult,
  KnowledgeGateTarget,
  KnowledgeGateVerdict,

  // ---------------------------------------------------------------------------
  // Complete CPU projection
  // ---------------------------------------------------------------------------

  ClinicalRuntimeProjection,
} from './types.js';