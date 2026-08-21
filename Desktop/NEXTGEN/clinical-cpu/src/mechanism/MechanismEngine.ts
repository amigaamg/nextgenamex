// =============================================================================
// AMEXAN Clinical CPU — MechanismEngine
// =============================================================================
//
// PURPOSE
// -------
// The MechanismEngine is the pathophysiology layer of the AMEXAN Clinical CPU.
//
// It answers:
//
//   "What physiological / pathological mechanisms are currently supported by
//    the patient's accumulated clinical evidence?"
//
// It does NOT diagnose the patient.
// It does NOT replace the differential engine.
// It does NOT invent clinical facts.
//
// Instead:
//
//   HISTORY ─────────────┐
//   EXAMINATION ─────────┤
//   VITALS ──────────────┤
//   LABS ────────────────┼──> FACTS ───────────────┐
//   IMAGING ─────────────┘                         │
//                                                   │
//   SYMPTOMS ──────────────────────────────────────┤
//                                                   ▼
//                                            MECHANISM ENGINE
//                                                   │
//                          ┌────────────────────────┼───────────────────────┐
//                          ▼                        ▼                       ▼
//                     features                phenotypes              contradictions
//                          │                        │                       │
//                          └────────────────────────┼───────────────────────┘
//                                                   ▼
//                                        MECHANISM SUPPORT SCORE
//                                                   │
//                          ┌────────────────────────┼───────────────────────┐
//                          ▼                        ▼                       ▼
//                   Investigation             Differential             Explanation
//                    selection                  engine                  / UI
//
// CORE PRINCIPLES
// ---------------
// 1. The engine reasons over canonical facts, never UI labels.
// 2. Positive evidence increases mechanism support.
// 3. Explicit negative evidence can reduce mechanism support.
// 4. Phenotypes provide higher-order pathophysiological support.
// 5. Symptoms can contribute when they are explicitly represented in the
//    mechanism knowledge graph.
// 6. Missing data is NOT treated as negative evidence.
// 7. Every contribution retains provenance.
// 8. Scores are deterministic and reproducible.
// 9. Knowledge remains in PostgreSQL; TypeScript evaluates the knowledge.
// 10. The mechanism engine does not manufacture a diagnosis.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import { evaluateFeature } from '../matching.js';
import type {
  Fact,
  MechanismScore,
  PhenotypeScore,
} from '../types.js';

// =============================================================================
// DATABASE ROWS
// =============================================================================

interface MechanismRow extends Row {
  mechanism_code: string;
  canonical_name: string;
  description?: string | null;
  body_system_code?: string | null;
  mechanism_class?: string | null;
  status?: string;
}

interface FeatureRow extends Row {
  mechanism_code: string;

  // Examples:
  // symptom
  // fact
  // measurement
  // finding
  // laboratory
  // imaging
  // examination
  feature_type: string;

  // Canonical feature/fact code.
  feature_code: string;

  // Positive contribution.
  weight: number;

  // Positive / negative.
  //
  // positive:
  //   presence supports mechanism.
  //
  // negative:
  //   presence argues against mechanism.
  polarity: string;

  // Optional comparator information if supported by the schema.
  operator?: string | null;
  value?: string | number | boolean | null;

  // Optional explanation.
  description?: string | null;
}

interface PhenotypeLinkRow extends Row {
  mechanism_code: string;
  phenotype_code: string;
  weight: number;
  polarity?: string | null;
  rationale?: string | null;
}

interface ContradictionRow extends Row {
  mechanism_code: string;
  feature_code: string;
  weight: number;
  rationale: string | null;
}

interface MechanismDependencyRow extends Row {
  mechanism_code: string;
  required_feature_code: string;
  dependency_type: string;
  weight: number;
}

interface FactDefinitionRow extends Row {
  code: string;
  canonical_name?: string | null;
}

// =============================================================================
// INTERNAL TYPES
// =============================================================================

export interface MechanismEvidence {
  source:
    | 'feature'
    | 'symptom'
    | 'phenotype'
    | 'contradiction'
    | 'dependency';

  code: string;
  weight: number;

  polarity: 'supporting' | 'against';

  matched: boolean;

  rationale: string | null;
}

export interface MechanismExplanation {
  mechanismCode: string;
  name: string;

  support: number;

  positiveSupport: number;
  negativeSupport: number;

  viaFeatures: number;
  viaSymptoms: number;
  viaPhenotypes: number;
  viaContradictions: number;

  evidence: MechanismEvidence[];

  viaPhenotypesDetailed: PhenotypeContributionDetail[];

  confidenceBand: 'none' | 'weak' | 'moderate' | 'strong' | 'very_strong';
}

interface PhenotypeContributionDetail {
  phenotypeCode: string;
  weight: number;
  score: number;
}

interface InternalMechanismResult {
  mechanismCode: string;
  name: string;

  positiveSupport: number;
  negativeSupport: number;

  viaFeatures: number;
  viaSymptoms: number;
  viaPhenotypes: number;
  viaContradictions: number;

  evidence: MechanismEvidence[];

  viaPhenotypesDetailed: PhenotypeContributionDetail[];
}

// =============================================================================
// ENGINE
// =============================================================================

export class MechanismEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // MAIN RESOLUTION
  // ===========================================================================
  //
  // Resolve all active mechanisms against:
  //
  //   facts
  //   phenotypes
  //   active symptoms
  //
  // The result remains sorted from strongest to weakest support.
  //
  async resolve(
    facts: Fact[],
    phenotypes: PhenotypeScore[],
    activeSymptoms: string[] = [],
  ): Promise<MechanismScore[]> {
    const detailed = await this.resolveDetailed(
      facts,
      phenotypes,
      activeSymptoms,
    );

    return detailed.map((result) => this.toMechanismScore(result));
  }

  // ===========================================================================
  // DETAILED RESOLUTION
  // ===========================================================================
  //
  // Used internally and can later become the CPU's explanation/provenance API.
  //
  async resolveDetailed(
    facts: Fact[],
    phenotypes: PhenotypeScore[],
    activeSymptoms: string[] = [],
  ): Promise<MechanismExplanation[]> {
    const [
      mechanisms,
      features,
      phenotypeLinks,
      contradictions,
      dependencies,
    ] = await Promise.all([
      this.loadMechanisms(),
      this.loadFeatures(),
      this.loadPhenotypeLinks(),
      this.loadContradictions(),
      this.loadDependencies(),
    ]);

    if (mechanisms.length === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // Normalize evidence once.
    // -------------------------------------------------------------------------

    const normalizedSymptoms = normalizeSymptoms(activeSymptoms);

    const phenotypeScoreMap = new Map<string, number>();

    for (const phenotype of phenotypes) {
      const score = Number(phenotype.score);

      if (!Number.isFinite(score)) {
        continue;
      }

      phenotypeScoreMap.set(
        phenotype.phenotypeCode,
        Math.max(0, score),
      );
    }

    // -------------------------------------------------------------------------
    // Index knowledge.
    // -------------------------------------------------------------------------

    const featuresByMechanism =
      groupByMechanism(features);

    const phenotypeLinksByMechanism =
      groupPhenotypeLinks(phenotypeLinks);

    const contradictionsByMechanism =
      groupContradictions(contradictions);

    const dependenciesByMechanism =
      groupDependencies(dependencies);

    // -------------------------------------------------------------------------
    // Resolve each mechanism independently.
    // -------------------------------------------------------------------------

    const results: InternalMechanismResult[] = [];

    for (const mechanism of mechanisms) {
      const result = this.evaluateMechanism(
        mechanism,
        facts,
        normalizedSymptoms,
        phenotypeScoreMap,
        featuresByMechanism.get(mechanism.mechanism_code) ?? [],
        phenotypeLinksByMechanism.get(mechanism.mechanism_code) ?? [],
        contradictionsByMechanism.get(mechanism.mechanism_code) ?? [],
        dependenciesByMechanism.get(mechanism.mechanism_code) ?? [],
      );

      results.push(result);
    }

    // -------------------------------------------------------------------------
    // Sort by net support.
    // -------------------------------------------------------------------------

    results.sort((a, b) => {
      const supportA = this.netSupport(a);
      const supportB = this.netSupport(b);

      if (supportA !== supportB) {
        return supportB - supportA;
      }

      // Stable deterministic fallback.
      return a.mechanismCode.localeCompare(b.mechanismCode);
    });

    return results.map((r) => ({
      mechanismCode: r.mechanismCode,
      name: r.name,

      support: round(this.netSupport(r)),

      positiveSupport: round(r.positiveSupport),
      negativeSupport: round(r.negativeSupport),

      viaFeatures: round(r.viaFeatures),
      viaSymptoms: round(r.viaSymptoms),
      viaPhenotypes: round(r.viaPhenotypes),
      viaContradictions: round(r.viaContradictions),

      evidence: r.evidence,

      viaPhenotypesDetailed: r.viaPhenotypesDetailed,

      confidenceBand: confidenceBand(
        this.netSupport(r),
      ),
    }));
  }

  // ===========================================================================
  // SINGLE MECHANISM EVALUATION
  // ===========================================================================

  private evaluateMechanism(
    mechanism: MechanismRow,
    facts: Fact[],
    symptoms: string[],
    phenotypeScores: Map<string, number>,
    features: FeatureRow[],
    phenotypeLinks: PhenotypeLinkRow[],
    contradictions: ContradictionRow[],
    dependencies: MechanismDependencyRow[],
  ): InternalMechanismResult {
    let viaFeatures = 0;
    let viaSymptoms = 0;
    let viaPhenotypes = 0;
    let viaContradictions = 0;

    const evidence: MechanismEvidence[] = [];

    // =========================================================================
    // 1. FEATURE EVIDENCE
    // =========================================================================

    for (const feature of features) {
      const polarity = normalizePolarity(feature.polarity);

      let matched = false;

      if (isSymptomFeature(feature.feature_type)) {
        matched = symptomMatches(
          feature.feature_code,
          symptoms,
        );
      } else {
        matched = this.evaluateFactFeature(
          facts,
          feature,
        );
      }

      if (!matched) {
        // CRITICAL:
        //
        // absence of captured evidence is NOT negative evidence.
        //
        // Example:
        // No documented haemoptysis
        //
        // does NOT mean:
        //
        // No haemoptysis.
        //
        continue;
      }

      const weight = safeWeight(
        feature.weight,
      );

      if (polarity === 'negative') {
        viaContradictions += weight;

        evidence.push({
          source: 'feature',
          code: feature.feature_code,
          weight,
          polarity: 'against',
          matched: true,
          rationale:
            feature.description ??
            `Feature ${feature.feature_code} argues against ${mechanism.canonical_name}`,
        });

        continue;
      }

      viaFeatures += weight;

      evidence.push({
        source: isSymptomFeature(feature.feature_type)
          ? 'symptom'
          : 'feature',
        code: feature.feature_code,
        weight,
        polarity: 'supporting',
        matched: true,
        rationale:
          feature.description ??
          `Feature ${feature.feature_code} supports ${mechanism.canonical_name}`,
      });
    }

    // =========================================================================
    // 2. EXPLICIT CONTRADICTIONS
    // =========================================================================

    for (const contradiction of contradictions) {
      const matched = this.factExists(
        facts,
        contradiction.feature_code,
      );

      if (!matched) continue;

      const weight = safeWeight(
        contradiction.weight,
      );

      viaContradictions += weight;

      evidence.push({
        source: 'contradiction',
        code: contradiction.feature_code,
        weight,
        polarity: 'against',
        matched: true,
        rationale:
          contradiction.rationale ??
          `Finding ${contradiction.feature_code} contradicts ${mechanism.canonical_name}`,
      });
    }

    // =========================================================================
    // 3. PHENOTYPE SUPPORT
    // =========================================================================
    //
    // Phenotypes are higher-level patterns.
    //
    // Example:
    //
    // fever + cough + tachypnea + hypoxaemia
    //          ↓
    // respiratory infection phenotype
    //          ↓
    // pulmonary infectious mechanism
    //
    // The phenotype score therefore modifies the mechanism weight rather than
    // simply behaving like another binary fact.
    // =========================================================================

    const viaPhenotypesDetailed: PhenotypeContributionDetail[] = [];

    for (const link of phenotypeLinks) {
      const phenotypeScore =
        phenotypeScores.get(link.phenotype_code) ?? 0;

      // Missing phenotype is not negative.
      if (phenotypeScore <= 0) {
        continue;
      }

      const weight = safeWeight(
        link.weight,
      );

      const polarity =
        normalizePolarity(
          link.polarity ?? 'positive',
        );

      const contribution =
        weight * normalizePhenotypeScore(
          phenotypeScore,
        );

      if (polarity === 'negative') {
        viaContradictions += contribution;

        evidence.push({
          source: 'phenotype',
          code: link.phenotype_code,
          weight: contribution,
          polarity: 'against',
          matched: true,
          rationale:
            link.rationale ??
            `Phenotype ${link.phenotype_code} argues against ${mechanism.canonical_name}`,
        });
      } else {
        viaPhenotypes += contribution;

        evidence.push({
          source: 'phenotype',
          code: link.phenotype_code,
          weight: contribution,
          polarity: 'supporting',
          matched: true,
          rationale:
            link.rationale ??
            `Phenotype ${link.phenotype_code} supports ${mechanism.canonical_name}`,
        });
      }

      viaPhenotypesDetailed.push({
        phenotypeCode: link.phenotype_code,
        weight,
        score: phenotypeScore,
      });
    }

    // =========================================================================
    // 4. DEPENDENCY CHECKS
    // =========================================================================
    //
    // A mechanism may have prerequisite evidence.
    //
    // Example:
    //
    // "obstructive airway mechanism"
    //
    // might require evidence such as:
    //
    // wheeze / prolonged expiration / airflow obstruction.
    //
    // A dependency does NOT automatically make the mechanism impossible unless
    // the knowledge rule explicitly defines it as required.
    //
    // This preserves the distinction:
    //
    //     unknown ≠ absent
    //
    // =========================================================================

    for (const dependency of dependencies) {
      const matched = this.factExists(
        facts,
        dependency.required_feature_code,
      );

      if (matched) {
        evidence.push({
          source: 'dependency',
          code: dependency.required_feature_code,
          weight: safeWeight(dependency.weight),
          polarity: 'supporting',
          matched: true,
          rationale:
            `Required/supporting dependency ${dependency.required_feature_code} is present`,
        });
      } else if (
        normalizeDependencyType(
          dependency.dependency_type,
        ) === 'required'
      ) {
        // IMPORTANT:
        //
        // We do not subtract arbitrary weight merely because information is
        // missing. The dependency is recorded as unresolved.
        //
        evidence.push({
          source: 'dependency',
          code: dependency.required_feature_code,
          weight: 0,
          polarity: 'supporting',
          matched: false,
          rationale:
            `Required dependency ${dependency.required_feature_code} has not been established`,
        });
      }
    }

    // =========================================================================
    // 5. FINAL OBJECT
    // =========================================================================

    const positiveSupport =
      viaFeatures +
      viaSymptoms +
      viaPhenotypes;

    const negativeSupport =
      viaContradictions;

    return {
      mechanismCode: mechanism.mechanism_code,
      name: mechanism.canonical_name,

      positiveSupport,
      negativeSupport,

      viaFeatures,
      viaSymptoms,
      viaPhenotypes,
      viaContradictions,

      evidence,

      viaPhenotypesDetailed,
    };
  }

  // ===========================================================================
  // FACT FEATURE EVALUATION
  // ===========================================================================

  private evaluateFactFeature(
    facts: Fact[],
    feature: FeatureRow,
  ): boolean {
    try {
      const result = evaluateFeature(
        facts,
        {
          featureCode: feature.feature_code,

          operator:
            feature.operator ?? 'exists',

          value:
            feature.value ?? null,

          weight:
            safeWeight(feature.weight),

          polarity:
            normalizePolarity(feature.polarity),
        },
      );

      return Boolean(result.matched);
    } catch {
      // Knowledge corruption must not crash the entire clinical CPU.
      //
      // The event/provenance layer should separately report malformed knowledge.
      // Here we safely fail the individual feature.
      return false;
    }
  }

  // ===========================================================================
  // FACT EXISTENCE
  // ===========================================================================

  private factExists(
    facts: Fact[],
    factCode: string,
  ): boolean {
    if (!factCode) return false;

    return facts.some(
      (fact) =>
        fact.factCode === factCode &&
        !isRetractedFact(fact),
    );
  }

  // ===========================================================================
  // DATABASE LOADERS
  // ===========================================================================

  private async loadMechanisms(): Promise<MechanismRow[]> {
    return this.db.query<MechanismRow>(
      `
      SELECT
        mechanism_code,
        canonical_name,
        description,
        body_system_code,
        mechanism_class,
        status
      FROM knowledge.mechanism
      WHERE status = 'active'
      ORDER BY mechanism_code
      `,
    );
  }

  private async loadFeatures(): Promise<FeatureRow[]> {
    return this.db.query<FeatureRow>(
      `
      SELECT
        m.mechanism_code,
        mf.feature_type,
        mf.feature_code,
        mf.weight,
        mf.polarity,
        mf.operator,
        mf.value,
        mf.description
      FROM knowledge.mechanism_feature mf
      JOIN knowledge.mechanism m
        ON m.id = mf.mechanism_id
      WHERE m.status = 'active'
      `,
    );
  }

  private async loadPhenotypeLinks(): Promise<PhenotypeLinkRow[]> {
    // knowledge.mechanism_phenotype has 'context' (jsonb) not 'rationale'
    return this.db.query<PhenotypeLinkRow>(
      `
      SELECT
        m.mechanism_code,
        ph.phenotype_code,
        mp.weight,
        mp.polarity,
        mp.context AS rationale
      FROM knowledge.mechanism_phenotype mp
      JOIN knowledge.mechanism m
        ON m.id = mp.mechanism_id
      JOIN knowledge.phenotype ph
        ON ph.id = mp.phenotype_id
      WHERE m.status = 'active'
      `,
    );
  }

  private async loadContradictions(): Promise<ContradictionRow[]> {
    // Optional knowledge table.
    //
    // If your current migration does not yet contain
    // knowledge.mechanism_contradiction, return an empty set rather than making
    // the whole CPU unusable.
    //
    // This can later be promoted to a required table.
    try {
      return await this.db.query<ContradictionRow>(
        `
        SELECT
          m.mechanism_code,
          mc.feature_code,
          mc.weight,
          mc.rationale
        FROM knowledge.mechanism_contradiction mc
        JOIN knowledge.mechanism m
          ON m.id = mc.mechanism_id
        WHERE m.status = 'active'
        `,
      );
    } catch {
      return [];
    }
  }

  private async loadDependencies(): Promise<MechanismDependencyRow[]> {
    // Same compatibility principle as contradictions.
    try {
      return await this.db.query<MechanismDependencyRow>(
        `
        SELECT
          m.mechanism_code,
          md.required_feature_code,
          md.dependency_type,
          md.weight
        FROM knowledge.mechanism_dependency md
        JOIN knowledge.mechanism m
          ON m.id = md.mechanism_id
        WHERE m.status = 'active'
        `,
      );
    } catch {
      return [];
    }
  }

  // ===========================================================================
  // NET SUPPORT
  // ===========================================================================

  private netSupport(
    result: InternalMechanismResult,
  ): number {
    return Math.max(
      0,
      result.positiveSupport - result.negativeSupport,
    );
  }

  // ===========================================================================
  // OUTPUT ADAPTER
  // ===========================================================================

  private toMechanismScore(
    result: InternalMechanismResult,
  ): MechanismScore {
    return {
      mechanismCode: result.mechanismCode,
      name: result.name,

      support: round(
        this.netSupport(result),
      ),

      viaFeatures: round(
        result.viaFeatures,
      ),

      viaPhenotypes:
        result.viaPhenotypesDetailed.map(
          (item) => ({
            phenotypeCode: item.phenotypeCode,
            weight: round(item.weight),
          }),
        ),
    };
  }
}

// =============================================================================
// GROUPING HELPERS
// =============================================================================

function groupByMechanism(
  rows: FeatureRow[],
): Map<string, FeatureRow[]> {
  const map = new Map<string, FeatureRow[]>();

  for (const row of rows) {
    const list =
      map.get(row.mechanism_code) ??
      [];

    list.push(row);
    map.set(row.mechanism_code, list);
  }

  return map;
}

function groupPhenotypeLinks(
  rows: PhenotypeLinkRow[],
): Map<string, PhenotypeLinkRow[]> {
  const map =
    new Map<string, PhenotypeLinkRow[]>();

  for (const row of rows) {
    const list =
      map.get(row.mechanism_code) ??
      [];

    list.push(row);
    map.set(row.mechanism_code, list);
  }

  return map;
}

function groupContradictions(
  rows: ContradictionRow[],
): Map<string, ContradictionRow[]> {
  const map =
    new Map<string, ContradictionRow[]>();

  for (const row of rows) {
    const list =
      map.get(row.mechanism_code) ??
      [];

    list.push(row);
    map.set(row.mechanism_code, list);
  }

  return map;
}

function groupDependencies(
  rows: MechanismDependencyRow[],
): Map<string, MechanismDependencyRow[]> {
  const map =
    new Map<string, MechanismDependencyRow[]>();

  for (const row of rows) {
    const list =
      map.get(row.mechanism_code) ??
      [];

    list.push(row);
    map.set(row.mechanism_code, list);
  }

  return map;
}

// =============================================================================
// SYMPTOM MATCHING
// =============================================================================

function symptomMatches(
  featureCode: string,
  activeSymptoms: string[],
): boolean {
  const normalizedFeature =
    normalizeSymptomCode(featureCode);

  if (!normalizedFeature) {
    return false;
  }

  return activeSymptoms.some(
    (symptom) =>
      symptom === normalizedFeature ||
      symptom.includes(normalizedFeature) ||
      normalizedFeature.includes(symptom),
  );
}

// =============================================================================
// SYMPTOM FEATURE DETECTION
// =============================================================================

function isSymptomFeature(
  featureType: string,
): boolean {
  const normalized =
    featureType.trim().toLowerCase();

  return (
    normalized === 'symptom' ||
    normalized === 'complaint' ||
    normalized === 'presentation'
  );
}

// =============================================================================
// NORMALIZATION
// =============================================================================

function normalizeSymptoms(
  symptoms: string[],
): string[] {
  const unique = new Set<string>();

  for (const symptom of symptoms) {
    const normalized =
      normalizeSymptomCode(symptom);

    if (normalized) {
      unique.add(normalized);
    }
  }

  return [...unique];
}

function normalizeSymptomCode(
  value: string,
): string {
  return value
    .replace(/^SYM[-_]/i, '')
    .replace(/^SYM[-_]/i, '')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

// =============================================================================
// POLARITY
// =============================================================================

function normalizePolarity(
  value: string | null | undefined,
): 'positive' | 'negative' {
  const normalized =
    String(value ?? 'positive')
      .trim()
      .toLowerCase();

  if (
    normalized === 'negative' ||
    normalized === 'against' ||
    normalized === 'exclude' ||
    normalized === 'contradictory'
  ) {
    return 'negative';
  }

  return 'positive';
}

// =============================================================================
// DEPENDENCY TYPE
// =============================================================================

function normalizeDependencyType(
  value: string | null | undefined,
): 'required' | 'supporting' | 'optional' {
  const normalized =
    String(value ?? 'supporting')
      .trim()
      .toLowerCase();

  if (
    normalized === 'required' ||
    normalized === 'mandatory'
  ) {
    return 'required';
  }

  if (
    normalized === 'optional'
  ) {
    return 'optional';
  }

  return 'supporting';
}

// =============================================================================
// PHENOTYPE NORMALIZATION
// =============================================================================
//
// Phenotype scores may come from different scoring layers.
//
// We deliberately cap them.
//
// A phenotype engine returning 100 should not automatically generate a
// mechanism contribution of weight × 100 unless the knowledge system
// explicitly intends that.
//
// Current normalization:
//   0       → 0
//   1       → 1
//   >1      → capped at 1
//
// If AMEXAN later adopts calibrated probabilities or another score scale,
// this should be replaced centrally rather than changing the mechanism logic.
// =============================================================================

function normalizePhenotypeScore(
  score: number,
): number {
  if (!Number.isFinite(score)) {
    return 0;
  }

  return Math.max(
    0,
    Math.min(1, score),
  );
}

// =============================================================================
// WEIGHT SAFETY
// =============================================================================

function safeWeight(
  value: unknown,
): number {
  const numeric =
    Number(value);

  if (!Number.isFinite(numeric)) {
    return 0;
  }

  return Math.max(
    0,
    numeric,
  );
}

// =============================================================================
// FACT STATUS
// =============================================================================

function isRetractedFact(
  fact: Fact,
): boolean {
  const candidate =
    fact as Fact & {
      statusCode?: string | null;
      status?: string | null;
    };

  return (
    candidate.statusCode === 'retracted' ||
    candidate.status === 'retracted'
  );
}

// =============================================================================
// CONFIDENCE BAND
// =============================================================================
//
// These are deliberately NOT probabilities.
//
// They are interpretive bands for UI/explanation and downstream prioritization.
// The thresholds belong here temporarily; a future knowledge configuration
// table should make them database-configurable.
//
// =============================================================================

function confidenceBand(
  score: number,
): 'none' | 'weak' | 'moderate' | 'strong' | 'very_strong' {
  if (score <= 0) {
    return 'none';
  }

  if (score < 1) {
    return 'weak';
  }

  if (score < 3) {
    return 'moderate';
  }

  if (score < 6) {
    return 'strong';
  }

  return 'very_strong';
}

// =============================================================================
// ROUNDING
// =============================================================================

function round(
  value: number,
): number {
  return Math.round(
    value * 1000,
  ) / 1000;
}