// =============================================================================
// AMEXAN Clinical CPU — ContradictionEngine
// Anti-anchoring (3.9): the CPU actively looks for evidence AGAINST its leading
// hypothesis. For the top differential it lists the EXPECTED findings that are
// not yet documented — "what we should see if this is correct, but have not
// confirmed". These probes steer the next question and keep the machine honest.
// =============================================================================

import type { Db, Row } from '../db.js';
import { evaluateFeature } from '../matching.js';
import { parseValue } from '../phenotype/PhenotypeEngine.js';
import type { ContradictionProbe, DifferentialCandidate, Fact } from '../types.js';

interface FeatureRow extends Row {
  phenotype_code: string;
  feature_code: string;
  operator: string;
  value: unknown;
  weight: number;
}

export class ContradictionEngine {
  constructor(private readonly db: Db) {}

  async probe(facts: Fact[], differentials: DifferentialCandidate[], limit = 5): Promise<ContradictionProbe[]> {
    const leading = differentials[0];
    if (!leading) return [];

    const phenotypeCodes = leading.viaPhenotypes.map((v) => v.phenotypeCode);
    if (phenotypeCodes.length === 0) return [];

    const features = await this.db.query<FeatureRow>(
      `SELECT ph.phenotype_code, pf.feature_code, pf.operator, pf.value, pf.weight
         FROM knowledge.phenotype_feature pf
         JOIN knowledge.phenotype ph ON ph.id = pf.phenotype_id
        WHERE ph.status = 'active' AND ph.phenotype_code = ANY($1::text[])
          AND pf.polarity = 'positive'`,
      [phenotypeCodes],
    );

    const probes: ContradictionProbe[] = [];
    for (const f of features) {
      const evalResult = evaluateFeature(facts, {
        featureCode: f.feature_code,
        operator: f.operator,
        value: parseValue(f.value),
        weight: Number(f.weight),
        polarity: 'positive',
      });
      if (evalResult.matched) continue;
      if (evalResult.found !== null) continue; // captured but wrong value → real against-evidence, not a probe
      probes.push({
        factCode: f.feature_code,
        expectation: expectationLabel(parseValue(f.value)),
        weight: Number(f.weight),
        reason: `Expected with ${leading.name} but not yet documented`,
      });
    }

    return probes.sort((a, b) => b.weight - a.weight).slice(0, limit);
  }
}

function expectationLabel(value: unknown): string {
  if (Array.isArray(value)) return `one of ${value.join(' / ')}`;
  if (typeof value === 'boolean') return value ? 'TRUE' : 'FALSE';
  if (value == null) return 'present';
  return String(value);
}
