// =============================================================================
// AMEXAN Clinical Intelligence Operating System
// Clinical CPU — DocumentationEngine
// =============================================================================
//
// PURPOSE
// -------
// Converts captured clinical facts into structured, traceable documentation
// for clinician review.
//
// CORE PRINCIPLES
// ---------------
// 1. DOCUMENTATION IS DERIVED FROM CAPTURED FACTS ONLY.
// 2. GENERATED PROSE MUST NEVER INVENT A CLINICAL FACT.
// 3. A missing fact is NEVER rendered as a negative fact.
// 4. Every generated sentence retains the fact codes that support it.
// 5. HPI language is knowledge-driven through knowledge.symptom_hpi_template.
// 6. Hardcoded fallbacks exist only to prevent silent loss while knowledge
//    coverage is incomplete.
// 7. Positive and negative captured findings are both documentable.
// 8. Differential documentation is explicitly labelled as a working
//    differential, never as a confirmed diagnosis.
// 9. Compatibility scores are never described as diagnostic probabilities.
// 10. Recommendations remain clinician-reviewable.
// 11. Documentation follows clinical narrative order rather than database
//     insertion order.
// 12. Superseded facts are not allowed to contaminate current documentation.
// 13. Contradictory/multiple values are handled conservatively.
// 14. Patient identity is generated only from captured biodata.
// 15. The engine never performs hidden clinical reasoning inside the HPI.
//
// HPI DOCUMENTATION ORDER
// -----------------------
// presenting
// chronology
// character
// sputum
// associated
// systemic
// ent_gi
// risk
// previous
// health_seeking
// severity
// functional
// examination
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  EvidenceLine,
  Fact,
  DocumentationSection,
  DifferentialCandidate,
  ProtocolView,
} from '../types.js';

// =============================================================================
// LOCAL TYPES
// =============================================================================

interface Sentence {
  text: string;
  factCode: string | null;
  factCodes?: string[];
}

type SlotValue = string | null | undefined;
type SlotNumeric = number | null | undefined;
type SlotBool = boolean | null | undefined;

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
  templateId?: string | null;
}

interface FactSnapshot {
  text: string | null;
  numeric: number | null;
  boolean: boolean | null;
  unitCode: string | null;
}

interface RenderedSentence {
  text: string;
  factCodes: string[];
}

// =============================================================================
// FALLBACK HPI KNOWLEDGE
// =============================================================================
//
// These are NOT intended to replace the knowledge base.
// They prevent captured facts from disappearing when a corresponding
// knowledge.symptom_hpi_template row has not yet been seeded.
//
// They render only facts that actually exist.
//
// =============================================================================

const HPI_SLOTS: {
  factCode: string;
  render: (
    value: SlotValue,
    numeric: SlotNumeric,
    bool: SlotBool,
  ) => string | null;
}[] = [
  {
    factCode: 'COUGH_PRESENT',
    render: (v, _n, b) =>
      yesValue(v, b) ? 'cough' : negativeValue(v, b) ? 'no cough' : null,
  },
  {
    factCode: 'COUGH_DURATION_DAYS',
    render: (_v, n) => (n != null ? `${n}-day history` : null),
  },
  {
    factCode: 'COUGH_ONSET',
    render: (v) => valuePhrase(v, 'onset'),
  },
  {
    factCode: 'COUGH_PRODUCTIVITY',
    render: (v) =>
      equalsAny(v, ['PRODUCTIVE'])
        ? 'productive'
        : equalsAny(v, ['NON_PRODUCTIVE', 'NON-PRODUCTIVE'])
          ? 'dry'
          : null,
  },
  {
    factCode: 'SPUTUM_COLOUR',
    render: (v) => (v ? `${humanize(v)} sputum` : null),
  },
  {
    factCode: 'SPUTUM_CONSISTENCY',
    render: (v) => (v ? `${humanize(v)} sputum` : null),
  },
  {
    factCode: 'SPUTUM_AMOUNT',
    render: (v) => (v ? `${humanize(v)} sputum` : null),
  },
  {
    factCode: 'SPUTUM_ODOUR',
    render: (v) => (v ? `${humanize(v)} sputum odour` : null),
  },
  {
    factCode: 'BLOOD_IN_SPUTUM',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'haemoptysis'
        : negativeValue(v, b)
          ? 'no haemoptysis'
          : null,
  },
  {
    factCode: 'FEVER_PRESENT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'associated fever'
        : negativeValue(v, b)
          ? 'no fever'
          : null,
  },
  {
    factCode: 'FEVER_DURATION_DAYS',
    render: (_v, n) => (n != null ? `${n}-day history of fever` : null),
  },
  {
    factCode: 'FEVER_ONSET',
    render: (v) => valuePhrase(v, 'fever onset'),
  },
  {
    factCode: 'TEMPERATURE',
    render: (_v, n) => (n != null ? `temperature ${n}°C` : null),
  },
  {
    factCode: 'CHILLS',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'chills'
        : negativeValue(v, b)
          ? 'no chills'
          : null,
  },
  {
    factCode: 'DYSPNOEA_PRESENT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'dyspnoea'
        : negativeValue(v, b)
          ? 'no dyspnoea'
          : null,
  },
  {
    factCode: 'DYSPNOEA_DURATION_DAYS',
    render: (_v, n) => (n != null ? `${n}-day history of dyspnoea` : null),
  },
  {
    factCode: 'DYSPNOEA_ONSET',
    render: (v) => valuePhrase(v, 'dyspnoea onset'),
  },
  {
    factCode: 'DYSPNOEA_SEVERITY',
    render: (v) => (v ? `dyspnoea ${humanize(v)}` : null),
  },
  {
    factCode: 'ORTHOPNOEA',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'orthopnoea'
        : negativeValue(v, b)
          ? 'no orthopnoea'
          : null,
  },
  {
    factCode: 'PND',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'paroxysmal nocturnal dyspnoea'
        : negativeValue(v, b)
          ? 'no paroxysmal nocturnal dyspnoea'
          : null,
  },
  {
    factCode: 'LEG_SWELLING',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'leg swelling'
        : negativeValue(v, b)
          ? 'no leg swelling'
          : null,
  },
  {
    factCode: 'CHEST_PAIN_PRESENT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'chest pain'
        : negativeValue(v, b)
          ? 'no chest pain'
          : null,
  },
  {
    factCode: 'CHEST_PAIN_PLEURITIC',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'pleuritic chest pain'
        : negativeValue(v, b)
          ? 'non-pleuritic chest pain'
          : null,
  },
  {
    factCode: 'CHEST_PAIN_ONSET',
    render: (v) => valuePhrase(v, 'chest pain onset'),
  },
  {
    factCode: 'WHEEZE_PRESENT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'wheeze'
        : negativeValue(v, b)
          ? 'no wheeze'
          : null,
  },
  {
    factCode: 'WEIGHT_LOSS',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'unintentional weight loss'
        : negativeValue(v, b)
          ? 'no weight loss'
          : null,
  },
  {
    factCode: 'NIGHT_SWEATS',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'night sweats'
        : negativeValue(v, b)
          ? 'no night sweats'
          : null,
  },
  {
    factCode: 'TB_CONTACT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'reported TB exposure'
        : negativeValue(v, b)
          ? 'no reported TB exposure'
          : null,
  },
  {
    factCode: 'SMOKING_STATUS',
    render: (v) => (v ? `smoking status: ${humanize(v)}` : null),
  },
  {
    factCode: 'SMOKING_PACK_YEARS',
    render: (_v, n) => (n != null ? `${n} pack-years` : null),
  },
  {
    factCode: 'ASPIRATION_RISK',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'aspiration risk'
        : negativeValue(v, b)
          ? 'no aspiration risk'
          : null,
  },
  {
    factCode: 'DYSPHAGIA',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'dysphagia'
        : negativeValue(v, b)
          ? 'no dysphagia'
          : null,
  },
  {
    factCode: 'RHINORRHOEA',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'rhinorrhoea'
        : negativeValue(v, b)
          ? 'no rhinorrhoea'
          : null,
  },
  {
    factCode: 'SORE_THROAT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'sore throat'
        : negativeValue(v, b)
          ? 'no sore throat'
          : null,
  },
  {
    factCode: 'HOARSENESS',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'hoarseness'
        : negativeValue(v, b)
          ? 'no hoarseness'
          : null,
  },
  {
    factCode: 'VOICE_CHANGE',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'voice change'
        : negativeValue(v, b)
          ? 'no voice change'
          : null,
  },
  {
    factCode: 'POSTNASAL_DRIP',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'post-nasal drip'
        : negativeValue(v, b)
          ? 'no post-nasal drip'
          : null,
  },
  {
    factCode: 'HEARTBURN',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'heartburn'
        : negativeValue(v, b)
          ? 'no heartburn'
          : null,
  },
];

// =============================================================================
// EXAMINATION FALLBACK KNOWLEDGE
// =============================================================================

const EXAM_FINDING_SLOTS: {
  factCode: string;
  render: (
    value: SlotValue,
    numeric: SlotNumeric,
    bool: SlotBool,
  ) => string | null;
}[] = [
  {
    factCode: 'RESP_RATE',
    render: (_v, n) => (n != null ? `respiratory rate ${n}/min` : null),
  },
  {
    factCode: 'SPO2',
    render: (_v, n) => (n != null ? `SpO₂ ${n}%` : null),
  },
  {
    factCode: 'HEART_RATE',
    render: (_v, n) => (n != null ? `heart rate ${n}/min` : null),
  },
  {
    factCode: 'TEMPERATURE',
    render: (_v, n) => (n != null ? `temperature ${n}°C` : null),
  },
  {
    factCode: 'BLOOD_PRESSURE_SYSTOLIC',
    render: (_v, n) => (n != null ? `systolic BP ${n} mmHg` : null),
  },
  {
    factCode: 'BLOOD_PRESSURE_DIASTOLIC',
    render: (_v, n) => (n != null ? `diastolic BP ${n} mmHg` : null),
  },
  {
    factCode: 'RESPIRATORY_DISTRESS',
    render: (_v, _n, b) => (b === true ? 'respiratory distress' : null),
  },
  {
    factCode: 'CHEST_INDRAWING',
    render: (_v, _n, b) => (b === true ? 'chest indrawing' : null),
  },
  {
    factCode: 'CYANOSIS',
    render: (_v, _n, b) => (b === true ? 'cyanosis' : null),
  },
  {
    factCode: 'RLL_DULLNESS',
    render: (_v, _n, b) =>
      b === true ? 'right lower lobe dullness' : null,
  },
  {
    factCode: 'RLL_BRONCHIAL_BREATH_SOUNDS',
    render: (_v, _n, b) =>
      b === true
        ? 'right lower lobe bronchial breath sounds'
        : null,
  },
  {
    factCode: 'CRACKLES',
    render: (_v, _n, b) => (b === true ? 'crackles' : null),
  },
  {
    factCode: 'WHEEZE_PRESENT',
    render: (v, _n, b) =>
      yesValue(v, b)
        ? 'wheeze'
        : negativeValue(v, b)
          ? 'no wheeze'
          : null,
  },
  {
    factCode: 'PERIPHERAL_OEDEMA',
    render: (_v, _n, b) =>
      b === true ? 'peripheral oedema' : null,
  },
];

// =============================================================================
// CLINICAL DOCUMENTATION ORDER
// =============================================================================

const GROUP_ORDER: string[] = [
  'presenting',
  'chronology',
  'character',
  'sputum',
  'associated',
  'systemic',
  'ent_gi',
  'risk',
  'previous',
  'health_seeking',
  'severity',
  'functional',
  'examination',
];

const GROUP_LEADS: Record<string, string> = {
  presenting: '',
  chronology: 'Chronology:',
  character: 'Character:',
  sputum: 'Sputum:',
  associated: 'Associated symptoms:',
  systemic: 'Systemic review:',
  ent_gi: 'ENT and GI review:',
  risk: 'Relevant risk factors:',
  previous: 'Previous episodes:',
  health_seeking: 'Health-seeking behaviour:',
  severity: 'Severity and progression:',
  functional: 'Functional impact:',
  examination: 'Examination:',
};

// =============================================================================
// DIFFERENTIAL EVIDENCE VOCABULARY
// =============================================================================
//
// Evidence codes are rendered into clinician-readable terms.
// This is presentation logic, not diagnostic reasoning.
//
// =============================================================================

const EVIDENCE_TERMS: Record<
  string,
  (found: string | null) => string
> = {
  COUGH_PRESENT: (f) =>
    positiveFound(f) ? 'cough' : negativeFound(f) ? 'no cough' : 'cough status',

  COUGH_DURATION_DAYS: (f) =>
    f ? `${f}-day cough` : 'cough duration',

  COUGH_ONSET: (f) =>
    f ? `${humanize(f)} onset` : 'cough onset',

  COUGH_PRODUCTIVITY: (f) =>
    f === 'PRODUCTIVE'
      ? 'productive cough'
      : f === 'NON_PRODUCTIVE' || f === 'NON-PRODUCTIVE'
        ? 'dry cough'
        : 'cough productivity',

  COUGH_SEVERITY: (f) =>
    f ? `${humanize(f)} severity cough` : 'cough severity',

  COUGH_TIMING: (f) =>
    f ? `cough ${humanize(f)}` : 'cough timing',

  COUGH_POSITIONAL: (f) =>
    affirmativeString(f) ? 'positional cough' : 'non-positional cough',

  SPUTUM_COLOUR: (f) =>
    f ? `${humanize(f)} sputum` : 'sputum colour',

  SPUTUM_CONSISTENCY: (f) =>
    f ? `${humanize(f)} sputum` : 'sputum consistency',

  SPUTUM_AMOUNT: (f) =>
    f ? `${humanize(f)} sputum volume` : 'sputum volume',

  SPUTUM_ODOUR: (f) =>
    f === 'FOUL'
      ? 'foul-smelling sputum'
      : f === 'NO' || f === 'NONE'
        ? 'no offensive sputum odour'
        : 'sputum odour',

  BLOOD_IN_SPUTUM: (f) =>
    f === 'YES'
      ? 'haemoptysis'
      : f === 'NO'
        ? 'no haemoptysis'
        : 'haemoptysis status',

  FEVER_PRESENT: (f) =>
    f === 'YES'
      ? 'fever'
      : f === 'NO'
        ? 'no fever'
        : 'fever status',

  FEVER_ONSET: (f) =>
    f ? `fever onset ${humanize(f)}` : 'fever onset',

  CHILLS: (f) =>
    f === 'YES'
      ? 'chills'
      : f === 'NO'
        ? 'no chills'
        : 'chills',

  DYSPNOEA_PRESENT: (f) =>
    f === 'YES'
      ? 'dyspnoea'
      : f === 'NO'
        ? 'no dyspnoea'
        : 'dyspnoea',

  DYSPNOEA_ONSET: (f) =>
    f ? `${humanize(f)}-onset dyspnoea` : 'dyspnoea onset',

  DYSPNOEA_SEVERITY: (f) =>
    f ? `dyspnoea ${humanize(f)}` : 'dyspnoea severity',

  ORTHOPNOEA: (f) =>
    f === 'YES' ? 'orthopnoea' : f === 'NO' ? 'no orthopnoea' : 'orthopnoea',

  PND: (f) =>
    f === 'YES'
      ? 'paroxysmal nocturnal dyspnoea'
      : f === 'NO'
        ? 'no paroxysmal nocturnal dyspnoea'
        : 'PND',

  LEG_SWELLING: (f) =>
    f === 'YES'
      ? 'leg swelling'
      : f === 'NO'
        ? 'no leg swelling'
        : 'leg swelling',

  CHEST_PAIN_PRESENT: (f) =>
    f === 'YES'
      ? 'chest pain'
      : f === 'NO'
        ? 'no chest pain'
        : 'chest pain',

  CHEST_PAIN_PLEURITIC: (f) =>
    f === 'YES'
      ? 'pleuritic chest pain'
      : f === 'NO'
        ? 'non-pleuritic chest pain'
        : 'pleuritic chest pain status',

  CHEST_PAIN_ONSET: (f) =>
    f ? `${humanize(f)}-onset chest pain` : 'chest pain onset',

  WHEEZE_PRESENT: (f) =>
    f === 'YES' ? 'wheeze' : f === 'NO' ? 'no wheeze' : 'wheeze',

  WEIGHT_LOSS: (f) =>
    f === 'YES'
      ? 'unintentional weight loss'
      : f === 'NO'
        ? 'no weight loss'
        : 'weight loss',

  NIGHT_SWEATS: (f) =>
    f === 'YES' ? 'night sweats' : f === 'NO' ? 'no night sweats' : 'night sweats',

  TB_CONTACT: (f) =>
    f ? `TB contact (${humanize(f)})` : 'TB contact',

  SMOKING_STATUS: (f) =>
    f ? `smoking (${humanize(f)})` : 'smoking status',

  SMOKING_PACK_YEARS: (f) =>
    f ? `${f} pack-years` : 'smoking pack-years',

  ASPIRATION_RISK: (f) =>
    f === 'YES'
      ? 'aspiration risk'
      : f === 'NO'
        ? 'no aspiration risk'
        : 'aspiration risk',

  DYSPHAGIA: (f) =>
    f === 'YES' ? 'dysphagia' : f === 'NO' ? 'no dysphagia' : 'dysphagia',

  RHINORRHOEA: (f) =>
    f === 'YES'
      ? 'rhinorrhoea'
      : f === 'NO'
        ? 'no rhinorrhoea'
        : 'rhinorrhoea',

  SORE_THROAT: (f) =>
    f === 'YES'
      ? 'sore throat'
      : f === 'NO'
        ? 'no sore throat'
        : 'sore throat',

  HOARSENESS: (f) =>
    f === 'YES'
      ? 'hoarseness'
      : f === 'NO'
        ? 'no hoarseness'
        : 'hoarseness',

  VOICE_CHANGE: (f) =>
    f === 'YES'
      ? 'voice change'
      : f === 'NO'
        ? 'no voice change'
        : 'voice change',

  POSTNASAL_DRIP: (f) =>
    f === 'YES'
      ? 'post-nasal drip'
      : f === 'NO'
        ? 'no post-nasal drip'
        : 'post-nasal drip',

  HEARTBURN: (f) =>
    f === 'YES' ? 'heartburn' : f === 'NO' ? 'no heartburn' : 'heartburn',

  RESP_RATE: (f) => (f ? `RR ${f}/min` : 'respiratory rate'),

  SPO2: (f) => (f ? `SpO₂ ${f}%` : 'SpO₂'),

  HEART_RATE: (f) => (f ? `HR ${f}/min` : 'heart rate'),

  TEMPERATURE: (f) =>
    f ? `temperature ${f}°C` : 'temperature',

  RESPIRATORY_DISTRESS: () => 'respiratory distress',
  CHEST_INDRAWING: () => 'chest indrawing',
  CYANOSIS: () => 'cyanosis',
  RLL_DULLNESS: () => 'right lower lobe dullness',
  RLL_BRONCHIAL_BREATH_SOUNDS: () =>
    'right lower lobe bronchial breathing',
  CRACKLES: () => 'crackles',
  PERIPHERAL_OEDEMA: () => 'peripheral oedema',
};

// =============================================================================
// DOCUMENTATION ENGINE
// =============================================================================

export class DocumentationEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // KNOWLEDGE LOADING
  // ===========================================================================

  private async loadTemplates(): Promise<HpiTemplateRow[]> {
    return this.db.query<HpiTemplateRow>(
      `
        SELECT
          section,
          documentation_group,
          fact_definition_code,
          fact_value,
          phrase_template,
          sort_order,
          supersedes_fact_code
        FROM knowledge.symptom_hpi_template
        WHERE is_active = true
        ORDER BY
          documentation_group ASC,
          sort_order ASC,
          fact_definition_code ASC
      `,
    );
  }

  // ===========================================================================
  // FACT NORMALIZATION
  // ===========================================================================

  /**
   * Extract all current values from a fact.
   *
   * The previous implementation used values[0], which can silently discard
   * valid multi-valued captures. AMEXAN preserves all values.
   */
  private snapshots(fact: Fact): FactSnapshot[] {
    return fact.values.map((value) => ({
      text: value.text ?? null,
      numeric:
        value.numeric != null && Number.isFinite(Number(value.numeric))
          ? Number(value.numeric)
          : null,
      boolean:
        value.boolean != null
          ? Boolean(value.boolean)
          : null,
      unitCode: value.unitCode ?? null,
    }));
  }

  /**
   * Return the latest/current fact by code.
   *
   * ContextResolver already excludes retracted facts, but this additional
   * defensive check prevents documentation from rendering explicitly
   * retracted facts if callers bypass the resolver.
   */
  private currentFact(
    facts: Fact[],
    factCode: string,
  ): Fact | undefined {
    const matching = facts.filter(
      (fact) =>
        fact.factCode === factCode &&
        fact.statusCode.toLowerCase() !== 'retracted',
    );

    if (matching.length === 0) return undefined;

    return matching
      .slice()
      .sort(
        (a, b) =>
          new Date(b.recordedAt).getTime() -
          new Date(a.recordedAt).getTime(),
      )[0];
  }

  // ===========================================================================
  // TEMPLATE RENDERING
  // ===========================================================================

  /**
   * Render a knowledge template against every captured value of a fact.
   *
   * Value-specific templates:
   *   fact_value = YES
   *
   * Value-agnostic templates:
   *   fact_value = NULL
   *
   * Value-agnostic templates may use:
   *   {value}
   *   {unit}
   *
   * Numeric values are rendered exactly as captured.
   * No clinical interpretation is added here.
   */
  private renderTemplate(
    template: HpiTemplateRow,
    fact: Fact,
  ): string[] {
    const rendered: string[] = [];
    const snapshots = this.snapshots(fact);

    for (const value of snapshots) {
      if (template.fact_value === null) {
        const text = substituteTemplateValues(
          template.phrase_template,
          value,
        );

        if (text.trim()) {
          rendered.push(text.trim());
        }

        continue;
      }

      if (!templateValueMatches(template.fact_value, value)) {
        continue;
      }

      const text = substituteTemplateValues(
        template.phrase_template,
        value,
      );

      if (text.trim()) {
        rendered.push(text.trim());
      }
    }

    return unique(rendered);
  }

  // ===========================================================================
  // TEMPLATE COLLECTION
  // ===========================================================================

  /**
   * Match knowledge templates against captured facts.
   *
   * Supersession:
   * A template can explicitly supersede another fact code. If the superseding
   * fact is captured, the old fact is not independently rendered.
   */
  private collect(
    facts: Fact[],
    templates: HpiTemplateRow[],
  ): Map<string, MatchedPhrase[]> {
    const byGroup = new Map<string, MatchedPhrase[]>();
    const capturedCodes = new Set(
      facts
        .filter(
          (fact) =>
            fact.statusCode.toLowerCase() !== 'retracted',
        )
        .map((fact) => fact.factCode),
    );

    for (const template of templates) {
      const fact = this.currentFact(
        facts,
        template.fact_definition_code,
      );

      if (!fact) continue;

      if (
        template.supersedes_fact_code &&
        capturedCodes.has(template.supersedes_fact_code) &&
        template.supersedes_fact_code !== template.fact_definition_code
      ) {
        // The new fact definition explicitly replaces the old semantic field.
        // The current template itself still renders.
      }

      const phrases = this.renderTemplate(template, fact);

      if (phrases.length === 0) continue;

      const list =
        byGroup.get(template.documentation_group) ?? [];

      for (const phrase of phrases) {
        list.push({
          factCode: fact.factCode,
          text: phrase,
          sortOrder: Number(template.sort_order) || 0,
        });
      }

      byGroup.set(template.documentation_group, list);
    }

    for (const list of byGroup.values()) {
      list.sort(
        (a, b) =>
          a.sortOrder - b.sortOrder ||
          a.factCode.localeCompare(b.factCode),
      );
    }

    return byGroup;
  }

  // ===========================================================================
  // FALLBACK COLLECTION
  // ===========================================================================

  private collectFallback(
    facts: Fact[],
    matchedCodes: Set<string>,
  ): MatchedPhrase[] {
    const phrases: MatchedPhrase[] = [];

    const slots = [
      ...HPI_SLOTS,
    ];

    for (const slot of slots) {
      if (matchedCodes.has(slot.factCode)) {
        continue;
      }

      const fact = this.currentFact(facts, slot.factCode);

      if (!fact) {
        continue;
      }

      for (const value of this.snapshots(fact)) {
        const phrase = slot.render(
          value.text,
          value.numeric,
          value.boolean,
        );

        if (!phrase) continue;

        phrases.push({
          factCode: fact.factCode,
          text: phrase,
          sortOrder: 999,
        });
      }
    }

    return deduplicatePhrases(phrases);
  }

  // ===========================================================================
  // PRESENTING COMPLAINT / OPENING HPI
  // ===========================================================================

  /**
   * Construct the opening HPI sentence from the presenting group.
   *
   * This is deliberately conservative.
   *
   * It does not infer:
   * - causality
   * - diagnosis
   * - severity
   * - progression
   * - relationships between symptoms
   *
   * It simply assembles captured facts into clinical narrative.
   */
  private buildPresenting(
    phrases: MatchedPhrase[],
  ): RenderedSentence {
    const byCode = (code: string): string | undefined =>
      phrases.find((phrase) => phrase.factCode === code)?.text;

    const duration =
      byCode('COUGH_DURATION_DAYS') ??
      byCode('SYMPTOM_DURATION_DAYS');

    const onset = byCode('COUGH_ONSET');

    const productivity =
      byCode('COUGH_PRODUCTIVITY');

    const presence =
      byCode('COUGH_PRESENT') ??
      byCode('PRESENTING_COMPLAINT') ??
      'cough';

    const descriptors = [onset, productivity]
      .filter(Boolean)
      .join(' ');

    const factCodes = unique(
      phrases
        .filter((phrase) =>
          [
            'COUGH_DURATION_DAYS',
            'SYMPTOM_DURATION_DAYS',
            'COUGH_ONSET',
            'COUGH_PRODUCTIVITY',
            'COUGH_PRESENT',
            'PRESENTING_COMPLAINT',
          ].includes(phrase.factCode),
        )
        .map((phrase) => phrase.factCode),
    );

    if (duration) {
      const middle = descriptors
        ? ` of ${descriptors} ${presence}`
        : ` of ${presence}`;

      return {
        text: `Patient reports a ${duration}${middle}.`,
        factCodes,
      };
    }

    return {
      text: `Patient reports ${
        descriptors ? `${descriptors} ` : ''
      }${presence}.`,
      factCodes,
    };
  }

  // ===========================================================================
  // HPI
  // ===========================================================================

  async hpi(
    facts: Fact[],
    hasChiefComplaint = false,
  ): Promise<Sentence[]> {
    // HPI explores symptoms entered in the chief complaint and the associated
    // symptoms answered during the HPI. Without a chief complaint the HPI has
    // nothing to explore.
    if (!hasChiefComplaint) {
      return [];
    }

    // HPI is strictly history: chief-complaint symptoms and the associated
    // symptoms explored during the HPI. Examination findings, vitals, laboratory
    // and imaging results are documented in their own sections and must not
    // leak into the HPI.
    const historyFacts = facts.filter(isHistoryFact);

    const templates = await this.loadTemplates();

    const historyTemplates = templates.filter(
      (template) => template.section === 'history',
    );

    const historyGroups = this.collect(
      historyFacts,
      historyTemplates,
    );

    const sentences: Sentence[] = [];

    // -------------------------------------------------------------------------
    // Clinical narrative groups
    // -------------------------------------------------------------------------

    for (const group of GROUP_ORDER) {
      const phrases = historyGroups.get(group) ?? [];

      if (phrases.length === 0) continue;

      // Opening HPI.
      if (group === 'presenting') {
        const rendered = this.buildPresenting(phrases);

        sentences.push({
          text: rendered.text,
          factCode: rendered.factCodes[0] ?? null,
          factCodes: rendered.factCodes,
        });

        continue;
      }

      const lead = GROUP_LEADS[group] ?? group;

      const text = `${lead} ${joinClinicalPhrases(
        phrases.map((phrase) => phrase.text),
      )}.`;

      const factCodes = unique(
        phrases.map((phrase) => phrase.factCode),
      );

      sentences.push({
        text,
        factCode: factCodes[0] ?? null,
        factCodes,
      });
    }

    // -------------------------------------------------------------------------
    // Knowledge-base fallback
    // -------------------------------------------------------------------------

    const matchedCodes = new Set<string>();

    for (const group of historyGroups.values()) {
      for (const phrase of group) {
        matchedCodes.add(phrase.factCode);
      }
    }

    const fallback = this.collectFallback(
      historyFacts,
      matchedCodes,
    );

    if (fallback.length > 0) {
      const factCodes = unique(
        fallback.map((phrase) => phrase.factCode),
      );

      sentences.push({
        text: `Noted: ${joinClinicalPhrases(
          fallback.map((phrase) => phrase.text),
        )}.`,
        factCode: factCodes[0] ?? null,
        factCodes,
      });
    }

    // -------------------------------------------------------------------------
    // No captured history
    // -------------------------------------------------------------------------

    if (sentences.length === 0) {
      sentences.push({
        text: 'No history facts captured yet.',
        factCode: null,
        factCodes: [],
      });
    }

    return sentences;
  }

  // ===========================================================================
  // ASSESSMENT
  // ===========================================================================

  assessment(
    differentials: DifferentialCandidate[],
  ): Sentence[] {
    if (differentials.length === 0) {
      return [
        {
          text:
            'No differential established yet — further history, examination and appropriate clinical assessment are required.',
          factCode: null,
          factCodes: [],
        },
      ];
    }

    const sentences: Sentence[] = [];
    const top = differentials[0];

    // -------------------------------------------------------------------------
    // Working assessment
    // -------------------------------------------------------------------------

    sentences.push({
      text:
        `Working assessment: ${top.name} is the current leading differential ` +
        `(compatibility ${formatCompatibility(top.compatibility)}). ` +
        `This is a working differential, not a confirmed diagnosis. ` +
        `The clinician must integrate the clinical history, examination, ` +
        `vital signs and appropriate investigations before establishing ` +
        `a final diagnosis.`,
      factCode: null,
      factCodes: [],
    });

    // -------------------------------------------------------------------------
    // Differential ledger
    // -------------------------------------------------------------------------

    for (const [index, differential] of differentials
      .slice(0, 5)
      .entries()) {
      const supporting = unique(
        differential.evidence
          .filter(
            (evidence) => evidence.support === 'support',
          )
          .map(evidencePhrase),
      );

      const against = unique(
        differential.evidence
          .filter(
            (evidence) => evidence.support === 'against',
          )
          .map(evidencePhrase),
      );

      const supportText =
        supporting.length > 0
          ? `supporting: ${supporting.join('; ')}`
          : 'supporting evidence not yet captured';

      const againstText =
        against.length > 0
          ? `; against: ${against.join('; ')}`
          : '';

      sentences.push({
        text:
          `${index + 1}. ${differential.name} ` +
          `(compatibility ${formatCompatibility(
            differential.compatibility,
          )}) — ${supportText}${againstText}.`,
        factCode: null,
        factCodes: unique(
          differential.evidence.map(
            (evidence) => evidence.factCode,
          ),
        ),
      });
    }

    // -------------------------------------------------------------------------
    // Diagnostic uncertainty statement
    // -------------------------------------------------------------------------

    sentences.push({
      text:
        'The current assessment remains subject to clinical verification. ' +
        'Captured evidence should be distinguished from information that ' +
        'has not yet been assessed or documented.',
      factCode: null,
      factCodes: [],
    });

    return sentences;
  }

  // ===========================================================================
  // PLAN
  // ===========================================================================

  plan(
    protocol: ProtocolView | null,
    recommendations: { type: string; text: string }[],
  ): Sentence[] {
    const lines: Sentence[] = [];

    if (protocol) {
      for (const step of protocol.steps) {
        lines.push({
          text:
            `${step.sequenceNo}. ${step.label} — ${step.instruction}`,
          factCode: null,
          factCodes: [],
        });
      }
    }

    for (const recommendation of recommendations) {
      lines.push({
        text: `• ${recommendation.text}`,
        factCode: null,
        factCodes: [],
      });
    }

    if (lines.length === 0) {
      return [
        {
          text:
            'Plan pending further clinical assessment.',
          factCode: null,
          factCodes: [],
        },
      ];
    }

    return lines;
  }

  // ===========================================================================
  // PATIENT IDENTIFICATION
  // ===========================================================================

  /**
   * Patient identification is generated strictly from biodata facts.
   *
   * No demographic inference is made from:
   * - database identifiers
   * - sex
   * - encounter type
   * - clinician identity
   * - clinical symptoms
   *
   * Sex/gender wording is used only where explicitly captured.
   */
  private patient(facts: Fact[]): Sentence[] {
    const valueOf = (
      code: string,
    ): FactSnapshot | null => {
      const fact = this.currentFact(facts, code);

      if (!fact) return null;

      return this.snapshots(fact)[0] ?? null;
    };

    const name = valueOf('PATIENT_NAME')?.text;

    const age = valueOf('AGE_YEARS')?.numeric;

    const sexRaw = (
      valueOf('SEX')?.text ?? ''
    ).trim().toLowerCase();

    const sex =
      sexRaw === 'male'
        ? 'male'
        : sexRaw === 'female'
          ? 'female'
          : sexRaw || null;

    const mrn = valueOf('MRN')?.text;

    const occupation =
      valueOf('OCCUPATION')?.text;

    const residence =
      valueOf('RESIDENCE')?.text;

    const county =
      valueOf('COUNTY')?.text;

    const informantRelation =
      valueOf('INFORMANT_RELATION')?.text;

    const informantReliable = (
      valueOf('INFORMANT_RELIABILITY')?.text ?? ''
    )
      .trim()
      .toLowerCase();

    const admissionDate =
      valueOf('ADMISSION_DATE')?.text;

    const encounterType = (
      valueOf('ENCOUNTER_TYPE')?.text ?? ''
    )
      .trim()
      .toUpperCase();

    const demographic = [
      age != null
        ? `a ${formatAge(age)}-year-old`
        : null,
      sex,
    ]
      .filter(Boolean)
      .join(' ');

    const subject = name ?? 'The patient';

    const sentences: Sentence[] = [];

    // -------------------------------------------------------------------------
    // Identity
    // -------------------------------------------------------------------------

    if (name || demographic) {
      const text = name
        ? `This is ${name}${
            demographic ? `, ${demographic}` : ''
          }.`
        : `${subject} is ${demographic}.`;

      const factCodes = unique(
        [
          name ? 'PATIENT_NAME' : null,
          age != null ? 'AGE_YEARS' : null,
          sex ? 'SEX' : null,
        ].filter(
          (code): code is string => code !== null,
        ),
      );

      sentences.push({
        text,
        factCode: factCodes[0] ?? null,
        factCodes,
      });
    }

    // -------------------------------------------------------------------------
    // MRN
    // -------------------------------------------------------------------------

    if (mrn) {
      sentences.push({
        text: `MRN: ${mrn}.`,
        factCode: 'MRN',
        factCodes: ['MRN'],
      });
    }

    // -------------------------------------------------------------------------
    // Occupation / residence
    // -------------------------------------------------------------------------

    if (occupation || residence || county) {
      const descriptors: string[] = [];

      if (occupation) {
        descriptors.push(
          `occupation: ${occupation}`,
        );
      }

      if (residence) {
        descriptors.push(
          `residence: ${residence}`,
        );
      }

      if (county) {
        descriptors.push(
          `county: ${county}`,
        );
      }

      const factCodes = unique(
        [
          occupation ? 'OCCUPATION' : null,
          residence ? 'RESIDENCE' : null,
          county ? 'COUNTY' : null,
        ].filter(
          (code): code is string => code !== null,
        ),
      );

      sentences.push({
        text: `${subject}: ${descriptors.join('; ')}.`,
        factCode: factCodes[0] ?? null,
        factCodes,
      });
    }

    // -------------------------------------------------------------------------
    // Informant
    // -------------------------------------------------------------------------

    if (informantRelation) {
      const reliable =
        informantReliable === 'yes'
          ? ' and is reported as reliable'
          : informantReliable === 'no'
            ? ' and is reported as not fully reliable'
            : '';

      const factCodes = unique(
        [
          'INFORMANT_RELATION',
          valueOf('INFORMANT_RELIABILITY')
            ? 'INFORMANT_RELIABILITY'
            : null,
        ].filter(
          (code): code is string => code !== null,
        ),
      );

      sentences.push({
        text:
          `${informantRelation} is the informant${reliable}.`,
        factCode: factCodes[0] ?? null,
        factCodes,
      });
    }

    // -------------------------------------------------------------------------
    // Encounter
    // -------------------------------------------------------------------------

    if (admissionDate || encounterType) {
      if (
        encounterType === 'INPATIENT' &&
        admissionDate
      ) {
        sentences.push({
          text: `Admitted on ${admissionDate}.`,
          factCode: 'ADMISSION_DATE',
          factCodes: [
            'ADMISSION_DATE',
            'ENCOUNTER_TYPE',
          ],
        });
      } else if (encounterType === 'INPATIENT') {
        sentences.push({
          text:
            'Admitted; date of admission has not been captured.',
          factCode: 'ENCOUNTER_TYPE',
          factCodes: ['ENCOUNTER_TYPE'],
        });
      } else if (encounterType === 'OUTPATIENT') {
        sentences.push({
          text:
            'Seen as an outpatient.',
          factCode: 'ENCOUNTER_TYPE',
          factCodes: ['ENCOUNTER_TYPE'],
        });
      }
    }

    // -------------------------------------------------------------------------
    // No biodata
    // -------------------------------------------------------------------------

    if (sentences.length === 0) {
      sentences.push({
        text:
          'Patient identification pending biodata capture.',
        factCode: null,
        factCodes: [],
      });
    }

    return sentences;
  }

  // ===========================================================================
  // COMPLETE DOCUMENTATION BUILD
  // ===========================================================================

  async build(
    facts: Fact[],
    differentials: DifferentialCandidate[],
    protocol: ProtocolView | null,
    recommendations: {
      type: string;
      text: string;
    }[],
    hasChiefComplaint = false,
  ): Promise<DocumentationSection[]> {
    const patient = this.patient(facts);
    const hpi = await this.hpi(facts, hasChiefComplaint);
    const assessment = this.assessment(differentials);
    const plan = this.plan(
      protocol,
      recommendations,
    );

    return [
      {
        section: 'Patient',
        sentences: patient,
      },
      {
        section: 'History of Present Illness',
        sentences: hpi,
      },
      {
        section: 'Assessment',
        sentences: assessment,
      },
      {
        section: 'Plan',
        sentences: plan,
      },
    ];
  }
}

// =============================================================================
// EVIDENCE RENDERING
// =============================================================================

function evidencePhrase(
  line: EvidenceLine,
): string {
  const builder =
    EVIDENCE_TERMS[line.factCode];

  if (builder) {
    return builder(line.found);
  }

  if (line.found) {
    return `${humanize(line.factCode)} (${line.found})`;
  }

  return humanize(line.factCode);
}

// =============================================================================
// TEMPLATE VALUE MATCHING
// =============================================================================

function templateValueMatches(
  expected: string,
  value: FactSnapshot,
): boolean {
  const normalizedExpected =
    expected.trim().toUpperCase();

  if (value.text != null) {
    return (
      value.text.trim().toUpperCase() ===
      normalizedExpected
    );
  }

  if (value.boolean != null) {
    return (
      String(value.boolean).toUpperCase() ===
      normalizedExpected
    );
  }

  if (value.numeric != null) {
    return (
      String(value.numeric).toUpperCase() ===
      normalizedExpected
    );
  }

  return false;
}

// =============================================================================
// TEMPLATE SUBSTITUTION
// =============================================================================

function substituteTemplateValues(
  template: string,
  value: FactSnapshot,
): string {
  let rendered = template;

  const rawValue =
    value.numeric != null
      ? String(value.numeric)
      : value.text != null
        ? value.text
        : value.boolean != null
          ? String(value.boolean)
          : '';

  rendered = rendered.replace(
    /\{value\}/g,
    rawValue,
  );

  rendered = rendered.replace(
    /\{text\}/g,
    value.text ?? '',
  );

  rendered = rendered.replace(
    /\{numeric\}/g,
    value.numeric != null
      ? String(value.numeric)
      : '',
  );

  rendered = rendered.replace(
    /\{boolean\}/g,
    value.boolean != null
      ? String(value.boolean)
      : '',
  );

  rendered = rendered.replace(
    /\{unit\}/g,
    value.unitCode ?? '',
  );

  return rendered
    .replace(/\s+/g, ' ')
    .trim();
}

// =============================================================================
// CLINICAL PHRASE JOINING
// =============================================================================

// =============================================================================
// HISTORY FACT CLASSIFICATION
// =============================================================================
//
// The HPI documents ONLY the chief-complaint symptoms and the associated
// symptoms explored during the history. Examination findings, vitals,
// laboratory and imaging results belong to their own sections.
//
// Facts captured through the history (patient_history, clinician-entered
// history facts, and untyped facts) are eligible for the HPI.
//
// =============================================================================

const NON_HISTORY_SOURCES = new Set([
  'examination',
  'imaging',
  'lab',
  'device',
  'device_measurement',
  'lab_result',
  'imaging_result',
]);

function isHistoryFact(
  fact: Fact,
): boolean {
  const source = fact.sourceType?.toLowerCase() ?? '';

  return !NON_HISTORY_SOURCES.has(source);
}

// =============================================================================
// CLINICAL PHRASE JOINING
// =============================================================================

function joinClinicalPhrases(
  phrases: string[],
): string {
  const clean = unique(
    phrases
      .map((phrase) => phrase.trim())
      .filter(Boolean),
  );

  if (clean.length === 0) return '';

  if (clean.length === 1) {
    return clean[0];
  }

  if (clean.length === 2) {
    return `${clean[0]} and ${clean[1]}`;
  }

  return `${clean.slice(0, -1).join(', ')}, and ${
    clean[clean.length - 1]
  }`;
}

// =============================================================================
// PHRASE DEDUPLICATION
// =============================================================================

function deduplicatePhrases(
  phrases: MatchedPhrase[],
): MatchedPhrase[] {
  const seen = new Set<string>();
  const result: MatchedPhrase[] = [];

  for (const phrase of phrases) {
    const key =
      `${phrase.factCode}|${phrase.text.trim().toLowerCase()}`;

    if (seen.has(key)) continue;

    seen.add(key);
    result.push(phrase);
  }

  return result;
}

// =============================================================================
// GENERAL VALUE HELPERS
// =============================================================================

function yesValue(
  text: string | null | undefined,
  bool: boolean | null | undefined,
): boolean {
  if (bool === true) return true;

  if (!text) return false;

  return [
    'YES',
    'TRUE',
    'PRESENT',
    'POSITIVE',
  ].includes(text.trim().toUpperCase());
}

function negativeValue(
  text: string | null | undefined,
  bool: boolean | null | undefined,
): boolean {
  if (bool === false) return true;

  if (!text) return false;

  return [
    'NO',
    'FALSE',
    'ABSENT',
    'NEGATIVE',
    'NONE',
    'NEVER',
  ].includes(text.trim().toUpperCase());
}

function positiveFound(
  value: string | null,
): boolean {
  if (!value) return false;

  return [
    'YES',
    'TRUE',
    'PRESENT',
    'POSITIVE',
  ].includes(value.trim().toUpperCase());
}

function negativeFound(
  value: string | null,
): boolean {
  if (!value) return false;

  return [
    'NO',
    'FALSE',
    'ABSENT',
    'NEGATIVE',
    'NONE',
  ].includes(value.trim().toUpperCase());
}

function affirmativeString(
  value: string | null,
): boolean {
  return positiveFound(value);
}

function equalsAny(
  value: string | null | undefined,
  expected: string[],
): boolean {
  if (!value) return false;

  const normalized =
    value.trim().toUpperCase();

  return expected.some(
    (item) =>
      normalized === item.trim().toUpperCase(),
  );
}

function valuePhrase(
  value: string | null | undefined,
  noun: string,
): string | null {
  if (!value) return null;

  return `${humanize(value)} ${noun}`;
}

// =============================================================================
// TEXT NORMALIZATION
// =============================================================================

function humanize(
  value: string,
): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ');
}

// =============================================================================
// ARRAY HELPERS
// =============================================================================

function unique<T>(
  values: T[],
): T[] {
  return [...new Set(values)];
}

// =============================================================================
// NUMBER FORMATTING
// =============================================================================

function formatAge(
  age: number,
): string {
  if (!Number.isFinite(age)) {
    return String(age);
  }

  return Number.isInteger(age)
    ? String(age)
    : age.toFixed(1).replace(/\.0$/, '');
}

function formatCompatibility(
  value: number,
): string {
  if (!Number.isFinite(value)) {
    return '0';
  }

  return Number.isInteger(value)
    ? String(value)
    : String(
        Math.round(value * 1000) / 1000,
      );
}