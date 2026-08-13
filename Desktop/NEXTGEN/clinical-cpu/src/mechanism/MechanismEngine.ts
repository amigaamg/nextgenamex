// =============================================================================
// AMEXAN Clinical CPU — MechanismEngine
// Resolves pathophysiological support from two reusable sources:
//   1. mechanism_feature     — facts/symptoms that support a mechanism
//   2. mechanism_phenotype   — scored phenotypes that imply a mechanism
// =============================================================================

import type { Db, Row } from '../db.js';
import { evaluateFeature } from '../matching.js';
import type { Fact, MechanismScore, PhenotypeScore } from '../types.js';

interface MechanismRow extends Row {
  mechanism_code: string;
  canonical_name: string;
}

interface FeatureRow extends Row {
  mechanism_code: string;
  feature_type: string;
  feature_code: string;
  weight: number;
  polarity: string;
}

interface PhenotypeLinkRow extends Row {
  mechanism_code: string;
  phenotype_code: string;
  weight: number;
}

export class MechanismEngine {
  constructor(private readonly db: Db) {}

  async resolve(facts: Fact[], phenotypes: PhenotypeScore[], activeSymptoms: string[] = []): Promise<MechanismScore[]> {
    const [mechanisms, features, phenotypeLinks] = await Promise.all([
      this.db.query<MechanismRow>(
        `SELECT mechanism_code, canonical_name FROM knowledge.mechanism WHERE status = 'active' ORDER BY mechanism_code`,
      ),
      this.db.query<FeatureRow>(
        `SELECT m.mechanism_code, mf.feature_type, mf.feature_code, mf.weight, mf.polarity
           FROM knowledge.mechanism_feature mf
           JOIN knowledge.mechanism m ON m.id = mf.mechanism_id
          WHERE m.status = 'active'`,
      ),
      this.db.query<PhenotypeLinkRow>(
        `SELECT m.mechanism_code, ph.phenotype_code, mp.weight
           FROM knowledge.mechanism_phenotype mp
           JOIN knowledge.mechanism m ON m.id = mp.mechanism_id
           JOIN knowledge.phenotype ph ON ph.id = mp.phenotype_id
          WHERE m.status = 'active'`,
      ),
    ]);

    const activeSymptomSet = activeSymptoms.map((s) => s.toLowerCase());
    const scoreByPhenotype = new Map(phenotypes.map((p) => [p.phenotypeCode, p.score]));
    const featuresByMechanism = new Map<string, FeatureRow[]>();
    for (const f of features) {
      const list = featuresByMechanism.get(f.mechanism_code) ?? [];
      list.push(f);
      featuresByMechanism.set(f.mechanism_code, list);
    }

    const linksByMechanism = new Map<string, { phenotypeCode: string; weight: number }[]>();
    for (const link of phenotypeLinks) {
      const list = linksByMechanism.get(link.mechanism_code) ?? [];
      list.push({ phenotypeCode: link.phenotype_code, weight: Number(link.weight) });
      linksByMechanism.set(link.mechanism_code, list);
    }

    const results: MechanismScore[] = [];
    for (const m of mechanisms) {
      let viaFeatures = 0;
      for (const f of featuresByMechanism.get(m.mechanism_code) ?? []) {
        const matched = f.feature_type === 'symptom'
          ? symptomMatches(f.feature_code, activeSymptomSet)
          : evaluateFeature(facts, {
              featureCode: f.feature_code,
              operator: 'exists',
              value: null,
              weight: Number(f.weight),
              polarity: f.polarity,
            }).matched;
        if (matched) viaFeatures += Number(f.weight);
      }

      const viaPhenotypes: { phenotypeCode: string; weight: number }[] = [];
      for (const link of linksByMechanism.get(m.mechanism_code) ?? []) {
        const phenotypeScore = scoreByPhenotype.get(link.phenotypeCode) ?? 0;
        if (phenotypeScore > 0) viaPhenotypes.push({ phenotypeCode: link.phenotypeCode, weight: link.weight });
      }
      const viaPhenotypeSum = viaPhenotypes.reduce((acc, l) => acc + l.weight * (scoreByPhenotype.get(l.phenotypeCode) ?? 0), 0);

      results.push({
        mechanismCode: m.mechanism_code,
        name: m.canonical_name,
        support: round(viaFeatures + viaPhenotypeSum),
        viaFeatures: round(viaFeatures),
        viaPhenotypes,
      });
    }
    return results.sort((a, b) => b.support - a.support);
  }
}

function round(n: number): number {
  return Math.round(n * 1000) / 1000;
}

function symptomMatches(symptomFeatureCode: string, activeSymptomSet: string[]): boolean {
  // SYM-COUGH → "cough", SYM-CHEST-PAIN → "chest pain"
  const normalized = symptomFeatureCode.replace(/^SYM-/, '').toLowerCase().replace(/_/g, ' ').replace(/-/g, ' ').trim();
  if (!normalized) return false;
  return activeSymptomSet.some((s) => s === normalized || s.includes(normalized) || normalized.includes(s));
}
