// =============================================================================
// AMEXAN Clinical CPU — DocumentationEngine
// Turns captured facts into structured documentation the clinician reviews
// (Accept / Modify / Reject). Every sentence is tagged with the fact code it
// came from — generated prose never invents facts.
//
// HPI phrases are DATA-DRIVEN: the engine reads knowledge.symptom_hpi_template
// (one row per fact × value) and renders only templates whose fact is captured
// and whose fact_value matches the captured value. Templates with a NULL
// fact_value are value-agnostic and substitute the {value} placeholder with the
// numeric capture.
//
// Sentences are assembled in CLINICAL ORDER by documentation_group:
//   presenting → chronology → character → sputum → associated → systemic →
//   ent_gi → risk → previous → health_seeking → severity → functional →
//   examination
// so the History of Present Illness reads as a full internal-medicine narrative
// (all positives AND negatives), not a flat "with"-joined chain.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { EvidenceLine, Fact, DocumentationSection, DifferentialCandidate, ProtocolView } from '../types.js';

interface Sentence {
  text: string;
  factCode: string | null;
}

// Ordered HPI slots retained purely as a fallback for fact codes that have no
// template row yet (nothing silently drops while the knowledge base catches up).
type SlotValue = string | null | undefined;
type SlotNumeric = number | null | undefined;
type SlotBool = boolean | null | undefined;

const HPI_SLOTS: { factCode: string; render: (value: SlotValue, numeric: SlotNumeric, bool: SlotBool) => string | null }[] = [
  { factCode: 'COUGH_PRESENT', render: () => 'acute cough' },
  { factCode: 'COUGH_DURATION_DAYS', render: (_v, n) => (n != null ? `${n}-day history` : null) },
  { factCode: 'COUGH_PRODUCTIVITY', render: (v) => (v === 'PRODUCTIVE' ? 'productive' : v === 'NON_PRODUCTIVE' ? 'dry' : null) },
  { factCode: 'SPUTUM_COLOUR', render: (v) => (v ? `${v.toLowerCase()} sputum` : null) },
  { factCode: 'FEVER_PRESENT', render: (v) => (v === 'YES' ? 'associated fever' : null) },
  { factCode: 'TEMPERATURE', render: (_v, n) => (n != null ? `fever to ${n}°C` : null) },
  { factCode: 'CHILLS', render: (v) => (v === 'YES' ? 'chills' : null) },
  { factCode: 'DYSPNOEA_PRESENT', render: (v) => (v === 'YES' ? 'progressive dyspnoea' : null) },
  { factCode: 'CHEST_PAIN_PLEURITIC', render: (v) => (v === 'YES' ? 'pleuritic chest pain' : null) },
  { factCode: 'CHEST_PAIN_PRESENT', render: (v) => (v === 'YES' ? 'chest pain' : null) },
  { factCode: 'CHEST_PAIN_ONSET', render: (v) => (v ? `${v.toLowerCase()}-onset chest pain` : null) },
  { factCode: 'WHEEZE_PRESENT', render: (v) => (v === 'YES' ? 'wheeze' : null) },
  { factCode: 'WEIGHT_LOSS', render: (v) => (v === 'YES' ? 'unintentional weight loss' : null) },
  { factCode: 'NIGHT_SWEATS', render: (v) => (v === 'YES' ? 'night sweats' : null) },
  { factCode: 'TB_CONTACT', render: (v) => (v === 'YES' ? 'reported TB exposure' : null) },
];

const EXAM_FINDING_SLOTS: { factCode: string; render: (value: SlotValue, numeric: SlotNumeric, bool: SlotBool) => string | null }[] = [
  { factCode: 'RESP_RATE', render: (_v, n) => (n != null ? `respiratory rate ${n}/min` : null) },
  { factCode: 'SPO2', render: (_v, n) => (n != null ? `SpO2 ${n}%` : null) },
  { factCode: 'RESPIRATORY_DISTRESS', render: (_v, _n, b) => (b ? 'respiratory distress' : null) },
  { factCode: 'CHEST_INDRAWING', render: (_v, _n, b) => (b ? 'chest indrawing' : null) },
  { factCode: 'CYANOSIS', render: (_v, _n, b) => (b ? 'cyanosis' : null) },
  { factCode: 'RLL_DULLNESS', render: (_v, _n, b) => (b ? 'right lower lobe dullness' : null) },
  { factCode: 'RLL_BRONCHIAL_BREATH_SOUNDS', render: (_v, _n, b) => (b ? 'right lower lobe bronchial breath sounds' : null) },
  { factCode: 'CRACKLES', render: (_v, _n, b) => (b ? 'crackles' : null) },
  { factCode: 'WHEEZE_PRESENT', render: (v) => (v === 'YES' ? 'wheeze' : null) },
];

interface HpiTemplateRow extends Row {
  section: string;
  documentation_group: string;
  fact_definition_code: string;
  fact_value: string | null;
  phrase_template: string;
  sort_order: number;
  supersedes_fact_code: string | null;
}

interface MatchedPhrase {
  factCode: string;
  text: string;
  sortOrder: number;
}

// Clinical ordering of documentation groups, and the lead-in used to open the
// sentence for each group (the presenting group is assembled as the opening
// sentence of the HPI).
const GROUP_ORDER: string[] = [
  'presenting', 'chronology', 'character', 'sputum', 'associated', 'systemic',
  'ent_gi', 'risk', 'previous', 'health_seeking', 'severity', 'functional', 'examination',
];

const GROUP_LEADS: Record<string, string> = {
  presenting: '',
  chronology: 'Chronology:',
  character: 'The cough is',
  sputum: 'Sputum:',
  associated: 'Associated symptoms:',
  systemic: 'Systemic review:',
  ent_gi: 'ENT and GI review:',
  risk: 'Risk factors:',
  previous: 'Previous episodes:',
  health_seeking: 'Health-seeking behaviour:',
  severity: 'Severity and progression:',
  functional: 'Functional impact:',
  examination: 'Examination:',
};

// Curated clinical vocabulary for rendering differential evidence as readable
// prose rather than raw codes. Maps factCode → phrase builder(found value).
const EVIDENCE_TERMS: Record<string, (found: string | null) => string> = {
  COUGH_DURATION_DAYS: (f) => (f ? `${f}-day cough` : 'cough duration'),
  COUGH_ONSET: (f) => (f ? `${f.toLowerCase()} onset` : 'onset'),
  COUGH_PRODUCTIVITY: (f) => (f === 'PRODUCTIVE' ? 'productive cough' : f === 'NON_PRODUCTIVE' ? 'dry cough' : 'cough productivity'),
  COUGH_SEVERITY: (f) => (f ? `${f.toLowerCase()} severity cough` : 'cough severity'),
  COUGH_TIMING: (f) => (f ? `cough ${f.toLowerCase().replace(/_/g, ' ')}` : 'cough timing'),
  COUGH_POSITIONAL: (f) => (f === 'true' || f === 'YES' ? 'positional cough' : 'non-positional cough'),
  SPUTUM_COLOUR: (f) => (f ? `${f.toLowerCase().replace(/_/g, ' ')} sputum` : 'sputum colour'),
  SPUTUM_CONSISTENCY: (f) => (f ? `${f.toLowerCase()} sputum` : 'sputum consistency'),
  SPUTUM_AMOUNT: (f) => (f ? `${f.toLowerCase()} sputum volume` : 'sputum volume'),
  SPUTUM_ODOUR: (f) => (f === 'FOUL' ? 'foul-smelling sputum' : 'no offensive sputum odour'),
  BLOOD_IN_SPUTUM: (f) => (f === 'YES' ? 'haemoptysis' : f === 'NO' ? 'no haemoptysis' : 'haemoptysis status'),
  FEVER_PRESENT: (f) => (f === 'YES' ? 'fever' : f === 'NO' ? 'no fever' : 'fever status'),
  FEVER_ONSET: (f) => (f ? `fever onset ${f.toLowerCase().replace(/_/g, ' ')}` : 'fever onset'),
  CHILLS: (f) => (f === 'YES' ? 'chills' : f === 'NO' ? 'no chills' : 'chills'),
  DYSPNOEA_PRESENT: (f) => (f === 'YES' ? 'dyspnoea' : f === 'NO' ? 'no dyspnoea' : 'dyspnoea'),
  DYSPNOEA_ONSET: (f) => (f ? `${f.toLowerCase()}-onset dyspnoea` : 'dyspnoea onset'),
  DYSPNOEA_SEVERITY: (f) => (f ? `dyspnoea ${f.toLowerCase().replace(/_/g, ' ')}` : 'dyspnoea severity'),
  ORTHOPNOEA: (f) => (f === 'YES' ? 'orthopnoea' : 'no orthopnoea'),
  PND: (f) => (f === 'YES' ? 'paroxysmal nocturnal dyspnoea' : 'no PND'),
  LEG_SWELLING: (f) => (f === 'YES' ? 'leg swelling' : 'no leg swelling'),
  CHEST_PAIN_PRESENT: (f) => (f === 'YES' ? 'chest pain' : 'no chest pain'),
  CHEST_PAIN_PLEURITIC: (f) => (f === 'YES' ? 'pleuritic chest pain' : 'non-pleuritic chest pain'),
  CHEST_PAIN_ONSET: (f) => (f ? `${f.toLowerCase()}-onset chest pain` : 'chest pain onset'),
  WHEEZE_PRESENT: (f) => (f === 'YES' ? 'wheeze' : 'no wheeze'),
  WEIGHT_LOSS: (f) => (f === 'YES' ? 'unintentional weight loss' : 'no weight loss'),
  NIGHT_SWEATS: (f) => (f === 'YES' ? 'night sweats' : 'no night sweats'),
  TB_CONTACT: (f) => (f ? `TB contact (${f.toLowerCase()})` : 'TB contact'),
  SMOKING_STATUS: (f) => (f ? `smoking (${f.toLowerCase()})` : 'smoking status'),
  SMOKING_PACK_YEARS: (f) => (f ? `${f} pack-years` : 'smoking pack-years'),
  ASPIRATION_RISK: (f) => (f === 'YES' ? 'aspiration risk' : 'no aspiration risk'),
  DYSPHAGIA: (f) => (f === 'YES' ? 'dysphagia' : 'no dysphagia'),
  RHINORRHOEA: (f) => (f === 'YES' ? 'rhinorrhoea' : 'no rhinorrhoea'),
  SORE_THROAT: (f) => (f === 'YES' ? 'sore throat' : 'no sore throat'),
  HOARSENESS: (f) => (f === 'YES' ? 'hoarseness' : 'no hoarseness'),
  VOICE_CHANGE: (f) => (f === 'YES' ? 'voice change' : 'no voice change'),
  POSTNASAL_DRIP: (f) => (f === 'YES' ? 'post-nasal drip' : 'no post-nasal drip'),
  HEARTBURN: (f) => (f === 'YES' ? 'heartburn' : 'no heartburn'),
  RESP_RATE: (f) => (f ? `RR ${f}` : 'respiratory rate'),
  SPO2: (f) => (f ? `SpO2 ${f}%` : 'SpO2'),
  HEART_RATE: (f) => (f ? `HR ${f}` : 'heart rate'),
  TEMPERATURE: (f) => (f ? `temperature ${f}°C` : 'temperature'),
  RESPIRATORY_DISTRESS: () => 'respiratory distress',
  CHEST_INDRAWING: () => 'chest indrawing',
  CYANOSIS: () => 'cyanosis',
  RLL_DULLNESS: () => 'right lower lobe dullness',
  RLL_BRONCHIAL_BREATH_SOUNDS: () => 'right lower lobe bronchial breathing',
  CRACKLES: () => 'crackles',
  PERIPHERAL_OEDEMA: () => 'peripheral oedema',
};

function evidencePhrase(line: EvidenceLine): string {
  const builder = EVIDENCE_TERMS[line.factCode];
  if (builder) return builder(line.found);
  return line.found ? `${line.factCode} (${line.found})` : line.factCode;
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}

export class DocumentationEngine {
  constructor(private readonly db: Db) {}

  private async loadTemplates(): Promise<HpiTemplateRow[]> {
    return this.db.query<HpiTemplateRow>(
      `SELECT section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order, supersedes_fact_code
         FROM knowledge.symptom_hpi_template
        WHERE is_active = true
        ORDER BY documentation_group, sort_order`,
    );
  }

  // Render one template against one captured fact, or null when the template
  // does not apply. For value-agnostic templates ({value}) the numeric capture
  // is substituted in.
  private renderTemplate(template: HpiTemplateRow, fact: Fact): string | null {
    const value = fact.values[0];
    if (template.fact_value === null) {
      if (value.numeric != null) {
        return template.phrase_template.replace(/\{value\}/g, String(value.numeric));
      }
      if (value.text != null) {
        return template.phrase_template.replace(/\{value\}/g, value.text);
      }
      return null;
    }
    if (value.text != null && value.text === template.fact_value) {
      return template.phrase_template;
    }
    if (value.boolean != null && String(value.boolean) === template.fact_value) {
      return template.phrase_template;
    }
    return null;
  }

  // Opening sentence built from the presenting group: duration, onset,
  // productivity and the noun itself. e.g. "Patient reports a 4-day history
  // of acute productive cough."
  private buildPresenting(phrases: MatchedPhrase[]): string {
    const byCode = (code: string) => phrases.find((p) => p.factCode === code)?.text;
    const duration = byCode('COUGH_DURATION_DAYS');
    const onset = byCode('COUGH_ONSET');
    const productivity = byCode('COUGH_PRODUCTIVITY');
    const presence = byCode('COUGH_PRESENT') ?? 'cough';
    const descriptors = [onset, productivity].filter(Boolean).join(' ');
    if (duration) {
      const middle = descriptors ? ` of ${descriptors} ${presence}` : ` of ${presence}`;
      return `Patient reports a ${duration}${middle}.`;
    }
    return `Patient reports ${descriptors ? `${descriptors} ` : ''}${presence}.`;
  }

  // Match every template against captured facts, grouped by documentation_group.
  private collect(facts: Fact[], templates: HpiTemplateRow[]): Map<string, MatchedPhrase[]> {
    const byGroup = new Map<string, MatchedPhrase[]>();
    for (const template of templates) {
      const fact = facts.find((f) => f.factCode === template.fact_definition_code);
      if (!fact) continue;
      const phrase = this.renderTemplate(template, fact);
      if (!phrase) continue;
      const list = byGroup.get(template.documentation_group) ?? [];
      list.push({ factCode: fact.factCode, text: phrase, sortOrder: template.sort_order });
      byGroup.set(template.documentation_group, list);
    }
    for (const list of byGroup.values()) {
      list.sort((a, b) => a.sortOrder - b.sortOrder);
    }
    return byGroup;
  }

  private collectFallback(facts: Fact[], matchedCodes: Set<string>): MatchedPhrase[] {
    const phrases: MatchedPhrase[] = [];
    for (const slot of [...HPI_SLOTS, ...EXAM_FINDING_SLOTS]) {
      if (matchedCodes.has(slot.factCode)) continue;
      const fact = facts.find((f) => f.factCode === slot.factCode);
      if (!fact) continue;
      const value = fact.values[0];
      const phrase = slot.render(value.text, value.numeric, value.boolean);
      if (phrase) phrases.push({ factCode: fact.factCode, text: phrase, sortOrder: 999 });
    }
    return phrases;
  }

  async hpi(facts: Fact[]): Promise<Sentence[]> {
    const templates = await this.loadTemplates();
    const byGroup = this.collect(facts, templates.filter((t) => t.section === 'history'));
    const examGroup = this.collect(facts, templates.filter((t) => t.section === 'examination'));

    const sentences: Sentence[] = [];
    for (const group of GROUP_ORDER) {
      const phrases = group === 'examination' ? examGroup.get('examination') ?? [] : byGroup.get(group) ?? [];
      if (phrases.length === 0) continue;
      if (group === 'presenting') {
        sentences.push({ text: this.buildPresenting(phrases), factCode: null });
        continue;
      }
      const lead = GROUP_LEADS[group] ?? group;
      sentences.push({ text: `${lead} ${phrases.map((p) => p.text).join(', ')}.`, factCode: null });
    }

    // Fallback: any captured fact with a hardcoded slot but no template row.
    const matchedCodes = new Set<string>();
    for (const list of [...byGroup.values(), ...examGroup.values()]) {
      for (const p of list) matchedCodes.add(p.factCode);
    }
    const fallback = this.collectFallback(facts, matchedCodes);
    if (fallback.length > 0) {
      sentences.push({ text: `Noted: ${fallback.map((p) => p.text).join(', ')}.`, factCode: null });
    }

    if (sentences.length === 0) {
      sentences.push({ text: 'No history facts captured yet.', factCode: null });
    }
    return sentences;
  }

  assessment(differentials: DifferentialCandidate[]): Sentence[] {
    if (differentials.length === 0) return [{ text: 'No differential yet — further history required.', factCode: null }];

    const sentences: Sentence[] = [];
    const top = differentials[0];

    // Lead sentence: honest about what is and is not established.
    sentences.push({
      text: `Working assessment: ${top.name} is the current working differential (compatibility ${top.compatibility}). This remains a working differential — not a confirmed diagnosis — until examination, vital signs and appropriate investigations support it.`,
      factCode: null,
    });

    // One line per candidate with the traceable supporting / against ledger.
    for (const [index, d] of differentials.slice(0, 3).entries()) {
      const supporting = unique(d.evidence.filter((e) => e.support === 'support').map(evidencePhrase));
      const against = unique(d.evidence.filter((e) => e.support === 'against').map(evidencePhrase));
      const supportText = supporting.length > 0 ? `supporting: ${supporting.join('; ')}` : 'no capturing evidence yet';
      const againstText = against.length > 0 ? `against: ${against.join('; ')}` : null;
      sentences.push({
        text: `${index + 1}. ${d.name} (compatibility ${d.compatibility}) — ${supportText}${againstText ? `; ${againstText}` : ''}.`,
        factCode: null,
      });
    }

    // What the system knows it does NOT know yet.
    sentences.push({
      text: 'Assessment is currently history-led. Objective severity assessment — vital signs, respiratory examination, and indicated investigations — is still required to establish severity and confirm the diagnosis.',
      factCode: null,
    });

    return sentences;
  }

  plan(protocol: ProtocolView | null, recommendations: { type: string; text: string }[]): Sentence[] {
    const lines: Sentence[] = [];
    if (protocol) {
      for (const step of protocol.steps) {
        lines.push({ text: `${step.sequenceNo}. ${step.label} — ${step.instruction}`, factCode: null });
      }
    }
    for (const rec of recommendations) {
      lines.push({ text: `• ${rec.text}`, factCode: null });
    }
    return lines.length > 0 ? lines : [{ text: 'Plan pending further assessment.', factCode: null }];
  }

  async build(facts: Fact[], differentials: DifferentialCandidate[], protocol: ProtocolView | null, recommendations: { type: string; text: string }[]): Promise<DocumentationSection[]> {
    return [
      { section: 'History of Present Illness', sentences: await this.hpi(facts) },
      { section: 'Assessment', sentences: this.assessment(differentials) },
      { section: 'Plan', sentences: this.plan(protocol, recommendations) },
    ];
  }
}
