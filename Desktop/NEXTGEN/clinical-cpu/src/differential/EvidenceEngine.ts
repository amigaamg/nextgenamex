// =============================================================================
// AMEXAN Clinical CPU — EvidenceEngine
// Produces the traceable "Supporting evidence / Against" ledger for any set of
// phenotypes, so the clinician can always click "Why does AMEXAN think this?"
// Every line is traceable to a captured fact and the knowledge feature it hit.
// =============================================================================

import type { Db, Row } from '../db.js';
import { evaluateFeature } from '../matching.js';
import { parseValue } from '../phenotype/PhenotypeEngine.js';
import type { EvidenceLine, Fact } from '../types.js';

interface FeatureRow extends Row {
  phenotype_code: string;
  feature_code: string;
  operator: string;
  value: unknown;
  weight: number;
  polarity: string;
}

export class EvidenceEngine {
  constructor(private readonly db: Db) {}

  async evidenceFor(facts: Fact[], phenotypeCodes: string[]): Promise<EvidenceLine[]> {
    if (phenotypeCodes.length === 0) return [];

    const features = await this.db.query<FeatureRow>(
      `SELECT ph.phenotype_code, pf.feature_code, pf.operator, pf.value, pf.weight, pf.polarity
         FROM knowledge.phenotype_feature pf
         JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
        WHERE ph.status = 'active' AND ph.phenotype_code = ANY($1::text[])`,
      [phenotypeCodes],
    );

    const lines: EvidenceLine[] = [];
    for (const f of features) {
      const expected = stringify(parseValue(f.value));
      const evalResult = evaluateFeature(facts, {
        featureCode: f.feature_code,
        operator: f.operator,
        value: parseValue(f.value),
        weight: Number(f.weight),
        polarity: f.polarity,
      });

      if (evalResult.matched) {
        lines.push({
          factCode: f.feature_code,
          expectation: expected,
          found: evalResult.found,
          weight: Number(f.weight),
          polarity: f.polarity === 'negative' ? 'negative' : 'positive',
          support: f.polarity === 'negative' ? 'against' : 'support',
        });
      } else if (evalResult.found !== null) {
        // The fact WAS captured, but not with the expected value → against.
        lines.push({
          factCode: f.feature_code,
          expectation: expected,
          found: evalResult.found,
          weight: Number(f.weight),
          polarity: f.polarity === 'negative' ? 'negative' : 'positive',
          support: 'against',
        });
      }
    }
    return lines;
  }
}

function stringify(value: unknown): string {
  if (Array.isArray(value)) return value.join(' / ');
  if (typeof value === 'boolean') return value ? 'TRUE' : 'FALSE';
  if (value == null) return '?';
  return String(value);
}
