// =============================================================================
// AMEXAN Clinical CPU — CPUOrchestrator
// Runs the full nephron over the current PatientClinicalState and assembles the
// ClinicalRuntimeProjection the UI renders. The UI is not the intelligence; it
// simply renders whatever this object contains.
//
//   facts → phenotypes → mechanisms → differential → evidence → next questions
//         → examination → investigations → protocol → monitoring → education
//         → treatment → documentation → recommendations → alerts
// =============================================================================

import type { Db } from '../db.js';
import type {
  Alert,
  ClinicalRuntimeProjection,
  KnowledgeGateResult,
  PatientClinicalState,
} from '../types.js';
import { ConfigurationResolver } from '../configuration/ConfigurationResolver.js';
import { DecisionEngine } from '../decisions/DecisionEngine.js';
import { ContradictionEngine } from '../differential/ContradictionEngine.js';
import { DocumentationEngine } from '../documentation/DocumentationEngine.js';
import { EducationEngine } from '../education/EducationEngine.js';
import { ExaminationSelector } from '../examination/ExaminationSelector.js';
import { InvestigationSelector } from '../investigation/InvestigationSelector.js';
import { MechanismEngine } from '../mechanism/MechanismEngine.js';
import { MonitoringEngine } from '../monitoring/MonitoringEngine.js';
import { PhenotypeEngine } from '../phenotype/PhenotypeEngine.js';
import { ProtocolEngine } from '../protocol/ProtocolEngine.js';
import { QuestionSelector } from '../questions/QuestionSelector.js';
import { DifferentialEngine } from '../differential/DifferentialEngine.js';
import { KnowledgeResolver } from '../governance/KnowledgeResolver.js';
import { SafetyEngine } from '../treatment/SafetyEngine.js';
import { TreatmentEngine } from '../treatment/TreatmentEngine.js';

const DETERIORATION_PHENOTYPES = new Set(['PHEN-HYPOXAEMIA', 'PHEN-RESPIRATORY-FAILURE']);

export class CPUOrchestrator {
  private readonly phenotype: PhenotypeEngine;
  private readonly mechanism: MechanismEngine;
  private readonly differential: DifferentialEngine;
  private readonly contradiction: ContradictionEngine;
  private readonly questions: QuestionSelector;
  private readonly examination: ExaminationSelector;
  private readonly investigation: InvestigationSelector;
  private readonly protocol: ProtocolEngine;
  private readonly monitoring: MonitoringEngine;
  private readonly education: EducationEngine;
  private readonly treatment: TreatmentEngine;
  private readonly safety: SafetyEngine;
  private readonly documentation: DocumentationEngine;
  private readonly decisions: DecisionEngine;
  private readonly configuration: ConfigurationResolver;
  private readonly governance: KnowledgeResolver;

  constructor(private readonly db: Db) {
    this.phenotype = new PhenotypeEngine(db);
    this.mechanism = new MechanismEngine(db);
    this.differential = new DifferentialEngine(db);
    this.contradiction = new ContradictionEngine(db);
    this.questions = new QuestionSelector(db);
    this.examination = new ExaminationSelector(db);
    this.investigation = new InvestigationSelector(db);
    this.protocol = new ProtocolEngine(db);
    this.monitoring = new MonitoringEngine(db);
    this.education = new EducationEngine(db);
    this.treatment = new TreatmentEngine(db);
    this.safety = new SafetyEngine();
    this.documentation = new DocumentationEngine(db);
    this.decisions = new DecisionEngine(db);
    this.configuration = new ConfigurationResolver(db);
    this.governance = new KnowledgeResolver(db);
  }

  async run(state: PatientClinicalState): Promise<ClinicalRuntimeProjection> {
    const scoredPhenotypes = await this.phenotype.score(state.facts);
    const rankedDifferentials = await this.differential.rank(scoredPhenotypes, state.facts);

    // H10 §37 — the runtime knowledge gate. Nothing governed-but-not-live
    // (DRAFT/SUPERSEDED/DEPRECATED/RETIRED) may participate in the computation;
    // ungoverned knowledge is flagged, never silently trusted (§27/§49).
    const gate = await this.governance.gate([
      ...scoredPhenotypes.map((p) => ({ kind: 'phenotype', code: p.phenotypeCode })),
      ...rankedDifferentials.map((d) => ({ kind: 'condition', code: d.conditionCode })),
    ]);
    const phenotypes = keepLive(gate, scoredPhenotypes);
    const differentials = keepLiveConditions(gate, rankedDifferentials);

    const mechanisms = await this.mechanism.resolve(state.facts, phenotypes, state.activeSymptoms);
    const nextQuestions = await this.questions.select(state, phenotypes, mechanisms, differentials);
    const examination = await this.examination.select(differentials);

    const capturedCodes = new Set(state.facts.map((f) => f.factCode));
    const investigationOverrides = await this.configuration.resolve(
      await this.investigationTargets(differentials, mechanisms),
    );
    const investigations = await this.investigation.select(differentials, mechanisms, capturedCodes, investigationOverrides);

    let protocol = await this.protocol.activate(differentials);
    if (protocol) {
      const protocolGate = await this.governance.gate([{ kind: 'protocol', code: protocol.protocolCode }]);
      if (!protocolGate.passes) {
        gate.blocked.push(...protocolGate.blocked);
        gate.checked += protocolGate.checked;
        protocol = null;
      }
    }
    const monitoring = await this.monitoring.resolve(protocol?.protocolCode ?? null, state.facts);
    const education = await this.education.resolve(differentials);
    const treatment = this.safety.apply(state.facts, await this.treatment.resolve(differentials, state.ageYears));
    const contradictions = await this.contradiction.probe(state.facts, differentials);

    const alerts = buildAlerts(monitoring, phenotypes);
    const recommendations = this.decisions.build(investigations, treatment, monitoring, education, alerts);
    const documentation = await this.documentation.build(state.facts, differentials, protocol, recommendations);

    const workingDiagnosis = differentials.length > 0 ? differentials[0].name : null;
    const leadingPhenotype = phenotypes.length > 0 ? phenotypes[0] : null;
    const configurationOverrides = await this.configuration.resolve(configTargets(differentials, investigations, protocol));

    return {
      currentPhase: 'clinical_reasoning',
      patientId: state.patientId,
      encounterId: state.encounterId,
      eventId: null,
      alerts,
      activeSymptoms: state.activeSymptoms,
      capturedFacts: state.facts,
      nextQuestions,
      phenotypes,
      mechanisms,
      differentials,
      examination,
      investigations,
      treatment,
      protocol,
      monitoring,
      education,
      documentation,
      recommendations,
      explanations: buildExplanations(workingDiagnosis, phenotypes, mechanisms),
      contradictions,
      configuration: { overrides: configurationOverrides },
      confidence: {
        workingDiagnosis,
        leadingPhenotypeScore: leadingPhenotype?.score ?? 0,
      },
      governance: { gate },
    };
  }

  // Candidate investigation codes for the top conditions/mechanisms — the
  // targets whose local overrides (if any) reshape the recommendation.
  private async investigationTargets(
    differentials: { conditionCode: string }[],
    mechanisms: { mechanismCode: string }[],
  ): Promise<{ type: string; code: string }[]> {
    const rows = await this.db.query<{ investigation_code: string }>(
      `SELECT DISTINCT i.investigation_code
         FROM knowledge.investigation_condition ic
         JOIN knowledge.condition c ON c.id = ic.condition_id
         JOIN knowledge.investigation i ON i.id = ic.investigation_id
        WHERE c.condition_code = ANY($1::text[])
        UNION
       SELECT DISTINCT i.investigation_code
         FROM knowledge.mechanism_investigation mi
         JOIN knowledge.mechanism m ON m.id = mi.mechanism_id
         JOIN knowledge.investigation i ON i.id = (SELECT id FROM knowledge.investigation WHERE investigation_code = mi.investigation_code)
        WHERE m.mechanism_code = ANY($2::text[])`,
      [differentials.slice(0, 2).map((d) => d.conditionCode), mechanisms.slice(0, 2).map((m) => m.mechanismCode)],
    );
    return rows.map((r) => ({ type: 'investigation', code: r.investigation_code }));
  }
}

function configTargets(
  differentials: { conditionCode: string }[],
  investigations: { investigationCode: string }[],
  protocol: { protocolCode: string } | null,
): { type: string; code: string }[] {
  const targets: { type: string; code: string }[] = [];
  for (const d of differentials.slice(0, 3)) targets.push({ type: 'condition', code: d.conditionCode });
  for (const i of investigations) targets.push({ type: 'investigation', code: i.investigationCode });
  if (protocol) targets.push({ type: 'protocol', code: protocol.protocolCode });
  return targets;
}

// H10 §37 fails-closed: drop any phenotype whose governed object is not live.
function keepLive<T extends { phenotypeCode: string }>(
  gate: KnowledgeGateResult,
  phenotypes: T[],
): T[] {
  const blocked = new Set(gate.blocked.filter((e) => e.kind === 'phenotype').map((e) => e.code));
  return phenotypes.filter((p) => !blocked.has(p.phenotypeCode));
}

// H10 §37 fails-closed: drop any differential condition whose governed object
// is not live (a RETIRED/SUPERSEDED diagnosis must never be presented).
function keepLiveConditions<T extends { conditionCode: string }>(
  gate: KnowledgeGateResult,
  differentials: T[],
): T[] {
  const blocked = new Set(gate.blocked.filter((e) => e.kind === 'condition').map((e) => e.code));
  return differentials.filter((d) => !blocked.has(d.conditionCode));
}

function buildAlerts(monitoring: { monitoringCode: string; alert: string | null }[], phenotypes: { phenotypeCode: string; score: number }[]): Alert[] {
  const alerts: Alert[] = [];
  for (const mon of monitoring) {
    if (mon.alert) {
      alerts.push({
        level: 'warning',
        code: mon.monitoringCode,
        message: mon.alert,
      });
    }
  }
  for (const phenotype of phenotypes) {
    if (phenotype.score > 0 && DETERIORATION_PHENOTYPES.has(phenotype.phenotypeCode)) {
      alerts.push({
        level: 'urgent',
        code: phenotype.phenotypeCode,
        message: `${phenotype.phenotypeCode} is active (score ${phenotype.score}) — reassess oxygenation and respiratory status`,
      });
    }
  }
  return alerts;
}

function buildExplanations(
  workingDiagnosis: string | null,
  phenotypes: { phenotypeCode: string; name: string; score: number }[],
  mechanisms: { mechanismCode: string; name: string; support: number }[],
): { label: string; body: string }[] {
  const explanations: { label: string; body: string }[] = [];
  if (workingDiagnosis) {
    explanations.push({ label: 'Working diagnosis', body: workingDiagnosis });
  }
  if (phenotypes.length > 0) {
    explanations.push({
      label: 'Leading phenotype',
      body: phenotypes
        .slice(0, 3)
        .map((p) => `${p.name} (${p.score})`)
        .join(' > '),
    });
  }
  if (mechanisms.length > 0) {
    explanations.push({
      label: 'Mechanism interpretation',
      body: mechanisms
        .slice(0, 2)
        .map((m) => `${m.name} (${m.support})`)
        .join(' > '),
    });
  }
  return explanations;
}
