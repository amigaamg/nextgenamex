// =============================================================================
// AMEXAN Clinical CPU — DifferentialEngine
// =============================================================================
// PURPOSE
// -------
// Ranks candidate clinical conditions from phenotype compatibility and attaches
// a fully traceable evidence ledger.
//
// IMPORTANT CLINICAL SEMANTICS
// ----------------------------
// 1. `compatibility` is NOT a probability.
// 2. It MUST NEVER be rendered as "X% likely".
// 3. A high compatibility score does NOT establish a diagnosis.
// 4. A low score does NOT safely exclude a condition.
// 5. The clinician remains the diagnostic authority.
// 6. Evidence is generated only from captured patient facts.
// 7. Knowledge relationships are deduplicated so duplicate seed generations
//    cannot artificially inflate a condition.
// 8. Negative phenotype scores are never allowed to create a candidate.
// 9. Only active phenotypes and active conditions participate.
// 10. Every candidate carries the phenotype pathways and supporting/against
//     evidence required for explainability.
//
// ARCHITECTURE
// ------------
// Patient facts
//      ↓
// PhenotypeEngine
//      ↓
// PhenotypeScore[]
//      ↓
// DifferentialEngine
//      ↓
// phenotype → condition knowledge graph
//      ↓
// compatibility ranking
//      ↓
// EvidenceEngine
//      ↓
// "Supporting evidence / Against"
//      ↓
// Clinician-facing differential
//
// The engine deliberately does NOT:
// - diagnose the patient;
// - calculate diagnostic probability;
// - recommend treatment;
// - suppress clinically important alternatives merely because their score
//   is lower;
// - infer facts that were never captured.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  DifferentialCandidate,
  Fact,
  PhenotypeScore,
} from '../types.js';
import { EvidenceEngine } from './EvidenceEngine.js';

interface DifferentialRow extends Row {
  phenotype_code: string;
  condition_code: string;
  canonical_name: string;
  weight: number;
}

interface ConditionAccumulator {
  conditionCode: string;
  name: string;
  viaPhenotypes: Map<string, number>;
  total: number;
}

interface DifferentialLink {
  phenotypeCode: string;
  conditionCode: string;
  name: string;
  weight: number;
}

export class DifferentialEngine {
  private readonly evidence: EvidenceEngine;

  constructor(private readonly db: Db) {
    this.evidence = new EvidenceEngine(db);
  }

  /**
   * Rank candidate conditions for the current clinical state.
   *
   * @param phenotypes Phenotypes already evaluated from captured facts.
   * @param facts Canonical patient facts used to build the evidence ledger.
   *
   * @returns Differential candidates sorted from highest compatibility to
   *          lowest compatibility.
   */
  async rank(
    phenotypes: PhenotypeScore[],
    facts: Fact[],
  ): Promise<DifferentialCandidate[]> {
    if (phenotypes.length === 0) return [];

    // -----------------------------------------------------------------------
    // 1. Normalize phenotype scores.
    //
    // A phenotype may theoretically appear more than once in upstream output.
    // The differential graph should receive one deterministic score per
    // phenotype.
    //
    // We retain the highest positive score. This prevents duplicated phenotype
    // records from multiplying downstream condition compatibility.
    // -----------------------------------------------------------------------
    const scoreByPhenotype = this.buildPhenotypeScoreMap(phenotypes);

    if (scoreByPhenotype.size === 0) return [];

    const phenotypeCodes = [...scoreByPhenotype.keys()];

    // -----------------------------------------------------------------------
    // 2. Load active phenotype → condition relationships.
    //
    // No condition is hard-coded here. AMEXAN's knowledge layer owns the
    // clinical relationships.
    // -----------------------------------------------------------------------
    const rows = await this.db.query<DifferentialRow>(
      `
        SELECT
          ph.phenotype_code,
          c.condition_code,
          c.canonical_name,
          pd.weight
        FROM knowledge.phenotype_differential pd
        JOIN knowledge.phenotype ph
          ON ph.id = pd.phenotype_id
        JOIN knowledge.condition c
          ON c.id = pd.condition_id
        WHERE ph.status = 'active'
          AND c.status = 'active'
          AND ph.phenotype_code = ANY($1::text[])
      `,
      [phenotypeCodes],
    );

    if (rows.length === 0) return [];

    // -----------------------------------------------------------------------
    // 3. Deduplicate logical phenotype → condition relationships.
    //
    // AMEXAN may contain relationships originating from different seed
    // generations. For example:
    //
    //   phenotype A → condition X → associated
    //   phenotype A → condition X → suggestive_of
    //
    // If both rows represent the same logical phenotype/condition link,
    // summing both would artificially inflate the condition.
    //
    // Therefore:
    //   key = phenotype + condition
    //   contribution = MAX(weight)
    //
    // We also sanitize weights so invalid database values cannot poison the
    // ranking.
    // -----------------------------------------------------------------------
    const links = this.dedupeLinks(rows);

    // -----------------------------------------------------------------------
    // 4. Accumulate compatibility by condition.
    //
    // Conceptually:
    //
    // conditionScore =
    //   Σ(phenotypeScore × phenotypeConditionWeight)
    //
    // This remains a compatibility heuristic, NOT a Bayesian probability.
    // -----------------------------------------------------------------------
    const byCondition = new Map<string, ConditionAccumulator>();

    for (const link of links) {
      const phenotypeScore = scoreByPhenotype.get(link.phenotypeCode);

      // The link may exist in knowledge but not have an evaluated phenotype.
      if (phenotypeScore == null) continue;

      // Phenotypes with no positive compatibility do not contribute to the
      // differential.
      if (phenotypeScore <= 0) continue;

      // Invalid or non-positive knowledge weights cannot produce a meaningful
      // positive compatibility contribution.
      if (!Number.isFinite(link.weight) || link.weight <= 0) continue;

      let entry = byCondition.get(link.conditionCode);

      if (!entry) {
        entry = {
          conditionCode: link.conditionCode,
          name: link.name,
          viaPhenotypes: new Map<string, number>(),
          total: 0,
        };

        byCondition.set(link.conditionCode, entry);
      }

      // A phenotype should contribute once to a condition even if malformed
      // or duplicated upstream data attempts to reintroduce it.
      //
      // Because links have already been deduplicated, this is primarily a
      // second defensive boundary.
      if (!entry.viaPhenotypes.has(link.phenotypeCode)) {
        entry.viaPhenotypes.set(link.phenotypeCode, link.weight);
        entry.total += phenotypeScore * link.weight;
      }
    }

    if (byCondition.size === 0) return [];

    // -----------------------------------------------------------------------
    // 5. Build candidate objects and attach explainability evidence.
    //
    // EvidenceEngine is deliberately called with the phenotypes that actually
    // contributed to the condition.
    //
    // This makes the UI able to answer:
    //
    //   "Why is this condition in the differential?"
    //
    // through:
    //
    //   phenotype pathway
    //        +
    //   supporting facts
    //        +
    //   against facts
    // -----------------------------------------------------------------------
    const candidates: DifferentialCandidate[] = [];

    for (const entry of byCondition.values()) {
      const viaPhenotypes = [...entry.viaPhenotypes.entries()].map(
        ([phenotypeCode, weight]) => ({
          phenotypeCode,
          weight,
        }),
      );

      const contributingPhenotypes = viaPhenotypes.map(
        (item) => item.phenotypeCode,
      );

      const evidence = await this.evidence.evidenceFor(
        facts,
        contributingPhenotypes,
      );

      candidates.push({
        conditionCode: entry.conditionCode,
        name: entry.name,
        compatibility: round(entry.total),
        viaPhenotypes,
        evidence,
      });
    }

    // -----------------------------------------------------------------------
    // 6. Deterministic ordering.
    //
    // Primary:
    //   highest compatibility first.
    //
    // Secondary:
    //   condition code alphabetically.
    //
    // Deterministic ordering is important for:
    // - reproducible UI;
    // - audit trails;
    // - testing;
    // - event replay;
    // - clinical explainability.
    // -----------------------------------------------------------------------
    candidates.sort((a, b) => {
      const scoreDifference = b.compatibility - a.compatibility;

      if (scoreDifference !== 0) {
        return scoreDifference;
      }

      return a.conditionCode.localeCompare(b.conditionCode);
    });

    return candidates;
  }

  // ===========================================================================
  // PHENOTYPE SCORE NORMALIZATION
  // ===========================================================================

  /**
   * Build one positive compatibility score per phenotype.
   *
   * We deliberately do not sum duplicate phenotype scores because doing so
   * could make repeated evaluation look like additional clinical evidence.
   */
  private buildPhenotypeScoreMap(
    phenotypes: PhenotypeScore[],
  ): Map<string, number> {
    const scores = new Map<string, number>();

    for (const phenotype of phenotypes) {
      const code = phenotype.phenotypeCode?.trim();

      if (!code) continue;

      const score = Number(phenotype.score);

      if (!Number.isFinite(score)) continue;

      const existing = scores.get(code);

      if (existing == null || score > existing) {
        scores.set(code, score);
      }
    }

    return scores;
  }

  // ===========================================================================
  // KNOWLEDGE-LINK DEDUPLICATION
  // ===========================================================================

  /**
   * Deduplicate phenotype → condition relationships.
   *
   * The same logical relationship may exist more than once because AMEXAN
   * knowledge is versioned/seeded over time.
   *
   * We retain the strongest weight.
   */
  private dedupeLinks(rows: DifferentialRow[]): DifferentialLink[] {
    const links = new Map<string, DifferentialLink>();

    for (const row of rows) {
      const phenotypeCode = row.phenotype_code?.trim();
      const conditionCode = row.condition_code?.trim();

      if (!phenotypeCode || !conditionCode) continue;

      const weight = Number(row.weight);

      if (!Number.isFinite(weight)) continue;

      const key = `${phenotypeCode}|${conditionCode}`;

      const candidate: DifferentialLink = {
        phenotypeCode,
        conditionCode,
        name: row.canonical_name,
        weight,
      };

      const existing = links.get(key);

      if (!existing || weight > existing.weight) {
        links.set(key, candidate);
      }
    }

    return [...links.values()];
  }
}

// =============================================================================
// NUMERIC NORMALIZATION
// =============================================================================

/**
 * Round compatibility values for stable API output.
 *
 * This is presentation/storage normalization only. It does NOT convert the
 * value into a probability.
 */
function round(value: number): number {
  if (!Number.isFinite(value)) return 0;

  return Math.round(value * 1000) / 1000;
}