// =============================================================================
// AMEXAN Clinical CPU — DifferentialEngine
// Ranks candidate conditions by phenotype compatibility, then attaches the
// evidence ledger. The numbers are compatibility scores, not calibrated
// diagnostic probabilities — the UI must never present them as percentages.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, PhenotypeScore } from '../types.js';
import { EvidenceEngine } from './EvidenceEngine.js';

interface DifferentialRow extends Row {
  phenotype_code: string;
  condition_code: string;
  canonical_name: string;
  weight: number;
}

export class DifferentialEngine {
  private readonly evidence: EvidenceEngine;

  constructor(private readonly db: Db) {
    this.evidence = new EvidenceEngine(db);
  }

  async rank(phenotypes: PhenotypeScore[], facts: import('../types.js').Fact[]): Promise<DifferentialCandidate[]> {
    const rows = await this.db.query<DifferentialRow>(
      `SELECT ph.phenotype_code, c.condition_code, c.canonical_name, pd.weight
         FROM knowledge.phenotype_differential pd
         JOIN knowledge.phenotype ph ON ph.id = pd.phenotype_id
         JOIN knowledge.condition c ON c.id = pd.condition_id
        WHERE ph.status = 'active' AND c.status = 'active'`,
    );

    const scoreByPhenotype = new Map(phenotypes.map((p) => [p.phenotypeCode, p.score]));

    const byCondition = new Map<string, { conditionCode: string; name: string; viaPhenotypes: { phenotypeCode: string; weight: number }[]; total: number }>();
    for (const row of rows) {
      const score = scoreByPhenotype.get(row.phenotype_code) ?? 0;
      if (score <= 0) continue;
      const entry = byCondition.get(row.condition_code) ?? {
        conditionCode: row.condition_code,
        name: row.canonical_name,
        viaPhenotypes: [],
        total: 0,
      };
      entry.viaPhenotypes.push({ phenotypeCode: row.phenotype_code, weight: Number(row.weight) });
      entry.total += score * Number(row.weight);
      byCondition.set(row.condition_code, entry);
    }

    const candidates: DifferentialCandidate[] = [];
    for (const entry of byCondition.values()) {
      const phenotypeCodes = entry.viaPhenotypes.map((v) => v.phenotypeCode);
      const evidence = await this.evidence.evidenceFor(facts, phenotypeCodes);
      candidates.push({
        conditionCode: entry.conditionCode,
        name: entry.name,
        compatibility: round(entry.total),
        viaPhenotypes: entry.viaPhenotypes,
        evidence,
      });
    }
    return candidates.sort((a, b) => b.compatibility - a.compatibility);
  }
}

function round(n: number): number {
  return Math.round(n * 1000) / 1000;
}
