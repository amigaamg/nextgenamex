// =============================================================================
// AMEXAN Clinical CPU — PhenotypeEngine
// The bridge between raw facts and disease hypotheses. Scores every phenotype
// against the patient's captured facts using knowledge.phenotype_feature.
//
// The CPU computes COMPATIBILITY, not diagnosis. A phenotype is a reusable
// pattern of facts with weights and contradictions.
// =============================================================================

import type { Db, Row } from '../db.js';
import { contribution, evaluateFeature } from '../matching.js';
import type { Fact, PhenotypeScore } from '../types.js';

interface PhenotypeRow extends Row {
  phenotype_code: string;
  canonical_name: string;
}

interface FeatureRow extends Row {
  phenotype_code: string;
  feature_code: string;
  operator: string;
  value: unknown;
  weight: number;
  polarity: string;
}

export class PhenotypeEngine {
  constructor(private readonly db: Db) {}

  async score(facts: Fact[]): Promise<PhenotypeScore[]> {
    const [phenotypes, features] = await Promise.all([
      this.db.query<PhenotypeRow>(
        `SELECT phenotype_code, canonical_name FROM knowledge.phenotype WHERE status = 'active' ORDER BY phenotype_code`,
      ),
      this.db.query<FeatureRow>(
        `SELECT ph.phenotype_code, pf.feature_code, pf.operator, pf.value, pf.weight, pf.polarity
           FROM knowledge.phenotype_feature pf
           JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
          WHERE ph.status = 'active'`,
      ),
    ]);

    const byCode = new Map<string, FeatureRow[]>();
    for (const f of features) {
      const list = byCode.get(f.phenotype_code) ?? [];
      list.push(f);
      byCode.set(f.phenotype_code, list);
    }

    const scores: PhenotypeScore[] = [];
    for (const p of phenotypes) {
      const featuresFor = byCode.get(p.phenotype_code) ?? [];
      let score = 0;
      let maxScore = 0;
      for (const f of featuresFor) {
        const parsed = parseValue(f.value);
        const evalResult = evaluateFeature(facts, {
          featureCode: f.feature_code,
          operator: f.operator,
          value: parsed,
          weight: Number(f.weight),
          polarity: f.polarity,
        });
        if (f.polarity === 'positive') maxScore += Number(f.weight);
        score += contribution(
          { featureCode: f.feature_code, operator: f.operator, value: parsed, weight: Number(f.weight), polarity: f.polarity },
          evalResult,
        );
      }
      scores.push({
        phenotypeCode: p.phenotype_code,
        name: p.canonical_name,
        score: round(score),
        maxScore: round(maxScore),
        compatibility: maxScore > 0 ? clamp01(score / maxScore) : 0,
      });
    }
    return scores.sort((a, b) => b.score - a.score);
  }
}

export function parseValue(value: unknown): unknown {
  // PostgreSQL returns jsonb as a parsed object; strings come back as raw strings.
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch {
      return value;
    }
  }
  return value;
}

function round(n: number): number {
  return Math.round(n * 1000) / 1000;
}

function clamp01(n: number): number {
  return Math.max(0, Math.min(1, n));
}
