// =============================================================================
// AMEXAN Clinical CPU — InvestigationSelector
// Question-driven investigation ordering. The CPU asks "given this patient's
// current state, what uncertainty should the next investigation resolve?" —
// candidates come from condition relevance and from the leading mechanism.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ConfigurationOverride, DifferentialCandidate, InvestigationRecommendation, MechanismScore } from '../types.js';

interface ConditionInvRow extends Row {
  condition_code: string;
  investigation_code: string;
  canonical_name: string;
  investigation_type: string;
  weight: number;
  rationale: string | null;
}

interface MechanismInvRow extends Row {
  mechanism_code: string;
  investigation_code: string;
  canonical_name: string;
  investigation_type: string;
  weight: number;
  rationale: string | null;
}

interface InvestigationRow extends Row {
  investigation_code: string;
  canonical_name: string;
  investigation_type: string;
}

// Investigation → the result facts that satisfy it. A lab/imaging result returns
// to the CPU as facts; once those facts exist, the CPU stops recommending the
// investigation (the closed loop). Only genuinely result-producing investigations
// are mapped (a CXR is a radiology study, not the RLL signs found on exam).
const INVESTIGATION_RESULT_FACTS: Record<string, string[]> = {
  'INV-SPO2': ['SPO2'],
  'INV-CXR': [],
  'INV-FBC': [],
  'INV-CRP': [],
  'INV-UREA-CREAT': [],
  'INV-SPUTUM-AFB': [],
};

function investigationAlreadySatisfied(capturedCodes: Set<string>, investigationCode: string): boolean {
  const resultFacts = INVESTIGATION_RESULT_FACTS[investigationCode];
  if (!resultFacts || resultFacts.length === 0) return false;
  return resultFacts.every((code) => capturedCodes.has(code));
}

export class InvestigationSelector {
  constructor(private readonly db: Db) {}

  async select(
    differentials: DifferentialCandidate[],
    mechanisms: MechanismScore[],
    capturedCodes: Set<string>,
    overrides: ConfigurationOverride[] = [],
  ): Promise<InvestigationRecommendation[]> {
    const topConditionCodes = differentials.slice(0, 2).map((d) => d.conditionCode);
    const topMechanismCodes = mechanisms.slice(0, 2).map((m) => m.mechanismCode);

    const [conditionRows, mechanismRows, protocolRows] = await Promise.all([
      topConditionCodes.length > 0
        ? this.db.query<ConditionInvRow>(
            `SELECT c.condition_code, i.investigation_code, i.canonical_name, i.investigation_type, ic.weight, ic.rationale
               FROM knowledge.investigation_condition ic
               JOIN knowledge.condition c ON c.id = ic.condition_id
               JOIN knowledge.investigation i ON i.id = ic.investigation_id
              WHERE c.condition_code = ANY($1::text[])`,
            [topConditionCodes],
          )
        : Promise.resolve([] as ConditionInvRow[]),
      topMechanismCodes.length > 0
        ? this.db.query<MechanismInvRow>(
            `SELECT m.mechanism_code, i.investigation_code, i.canonical_name, i.investigation_type, mi.weight, mi.rationale
               FROM knowledge.mechanism_investigation mi
               JOIN knowledge.mechanism m ON m.id = mi.mechanism_id
               JOIN knowledge.investigation i ON i.id = (SELECT id FROM knowledge.investigation WHERE investigation_code = mi.investigation_code)
              WHERE m.mechanism_code = ANY($1::text[])`,
            [topMechanismCodes],
          )
        : Promise.resolve([] as MechanismInvRow[]),
      this.db.query<InvestigationRow>(`SELECT investigation_code, canonical_name, investigation_type FROM knowledge.investigation`),
    ]);

    const protocolInvestigationCodes = protocolRows.map((i) => i.investigation_code);
    const aggregate = new Map<string, InvestigationRecommendation>();

    for (const row of conditionRows) {
      if (capturedCodes.has(row.investigation_code)) continue;
      if (investigationAlreadySatisfied(capturedCodes, row.investigation_code)) continue;
      const entry = aggregate.get(row.investigation_code) ?? {
        investigationCode: row.investigation_code,
        name: row.canonical_name,
        type: row.investigation_type,
        weight: 0,
        rationale: null,
        source: 'condition' as const,
      };
      entry.weight += Number(row.weight);
      entry.rationale = entry.rationale ?? row.rationale ?? `Relevant to suspected ${row.condition_code}`;
      aggregate.set(row.investigation_code, entry);
    }

    for (const row of mechanismRows) {
      if (capturedCodes.has(row.investigation_code)) continue;
      if (investigationAlreadySatisfied(capturedCodes, row.investigation_code)) continue;
      const entry = aggregate.get(row.investigation_code) ?? {
        investigationCode: row.investigation_code,
        name: row.canonical_name,
        type: row.investigation_type,
        weight: 0,
        rationale: null,
        source: 'mechanism' as const,
      };
      entry.weight += Number(row.weight);
      entry.rationale = entry.rationale ?? row.rationale ?? `Supported by mechanism ${row.mechanism_code}`;
      if (entry.source === 'condition') entry.source = 'condition';
      aggregate.set(row.investigation_code, entry);
    }

    // Protocol-mandated investigations are flagged even when already suggested.
    for (const code of protocolInvestigationCodes) {
      const entry = aggregate.get(code);
      if (entry && !capturedCodes.has(code) && !investigationAlreadySatisfied(capturedCodes, code)) {
        entry.rationale = entry.rationale ? `${entry.rationale} (also mandated by active protocol)` : 'Mandated by active protocol';
      }
    }

    // Configuration overrides (3.19) reshape the recommendation the clinician
    // actually sees, with full provenance (override code + reason available in
    // projection.configuration).
    const overrideByCode = new Map(overrides.map((o) => [o.targetCode, o]));
    for (const entry of aggregate.values()) {
      const override = overrideByCode.get(entry.investigationCode);
      if (!override) continue;
      const rationale = override.config?.rationale;
      if (typeof rationale === 'string' && rationale) entry.rationale = rationale;
    }

    return [...aggregate.values()]
      .sort((a, b) => b.weight - a.weight)
      .map((e) => ({ ...e, weight: round(e.weight) }));
  }
}

function round(n: number): number {
  return Math.round(n * 1000) / 1000;
}
