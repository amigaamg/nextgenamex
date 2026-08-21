// =============================================================================
// AMEXAN Clinical CPU — EducationEngine
// =============================================================================
// Resolves reusable, knowledge-governed patient/clinician education from the
// active working differential.
//
// PRINCIPLES
// -----------------------------------------------------------------------------
// 1. Education is KNOWLEDGE, never generated clinical advice.
// 2. Education is linked to canonical condition codes in the knowledge graph.
// 3. Only the highest-ranked differentials are used as the working context.
// 4. Duplicate education items are removed deterministically.
// 5. Condition ranking is preserved so education follows clinical priority.
// 6. Patient/clinician audience and content type are retained from knowledge.
// 7. Inactive/retired knowledge must never be surfaced.
// 8. The engine does not diagnose, prescribe, or independently invent advice.
// 9. Missing education is a valid state — the engine returns [].
// 10. Database results are normalized before entering the CPU output.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, EducationItem } from '../types.js';

interface EducationRow extends Row {
  education_code: string;
  title: string;
  audience: string;
  content_type: string;
  body: string;
  status?: string;
}

interface EducationConditionRow extends Row {
  condition_code: string;
  education_code: string;
}

interface EducationLink {
  conditionCode: string;
  educationCode: string;
  conditionRank: number;
}

export class EducationEngine {
  constructor(private readonly db: Db) {}

  /**
   * Resolve education for the current working differential.
   *
   * The first two candidates are intentionally used as the working
   * educational context. This prevents the education panel from becoming a
   * dump of material for every low-ranked differential.
   *
   * Education remains diagnosis-contextual rather than diagnosis-confirming.
   */
  async resolve(
    differentials: DifferentialCandidate[],
  ): Promise<EducationItem[]> {
    if (!Array.isArray(differentials) || differentials.length === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // 1. Establish the working diagnostic context.
    // -------------------------------------------------------------------------
    const workingDifferentials = differentials
      .filter(
        (d) =>
          d != null &&
          typeof d.conditionCode === 'string' &&
          d.conditionCode.trim().length > 0,
      )
      .slice(0, 2);

    if (workingDifferentials.length === 0) {
      return [];
    }

    const topConditionCodes = [
      ...new Set(
        workingDifferentials.map((d) => d.conditionCode.trim()),
      ),
    ];

    if (topConditionCodes.length === 0) {
      return [];
    }

    const conditionRank = new Map<string, number>();

    for (let index = 0; index < workingDifferentials.length; index += 1) {
      const code = workingDifferentials[index].conditionCode.trim();

      // Preserve the first occurrence if duplicate condition codes somehow
      // reach the engine.
      if (!conditionRank.has(code)) {
        conditionRank.set(code, index);
      }
    }

    // -------------------------------------------------------------------------
    // 2. Resolve condition → education knowledge links.
    // -------------------------------------------------------------------------
    const links = await this.db.query<EducationConditionRow>(
      `
      SELECT DISTINCT
             c.condition_code,
             e.education_code
        FROM knowledge.education_condition ec
        JOIN knowledge.condition c
          ON c.id = ec.condition_id
        JOIN knowledge.education e
          ON e.id = ec.education_id
       WHERE c.status = 'active'
         AND e.status = 'active'
         AND c.condition_code = ANY($1::text[])
      `,
      [topConditionCodes],
    );

    if (links.length === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // 3. Normalize and deduplicate condition → education links.
    // -------------------------------------------------------------------------
    const normalizedLinks: EducationLink[] = [];

    const seenLinks = new Set<string>();

    for (const link of links) {
      const conditionCode = link.condition_code?.trim();
      const educationCode = link.education_code?.trim();

      if (!conditionCode || !educationCode) {
        continue;
      }

      const rank = conditionRank.get(conditionCode);

      if (rank == null) {
        continue;
      }

      const key = `${conditionCode}|${educationCode}`;

      if (seenLinks.has(key)) {
        continue;
      }

      seenLinks.add(key);

      normalizedLinks.push({
        conditionCode,
        educationCode,
        conditionRank: rank,
      });
    }

    if (normalizedLinks.length === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // 4. Resolve unique education records.
    // -------------------------------------------------------------------------
    const educationCodes = [
      ...new Set(normalizedLinks.map((link) => link.educationCode)),
    ];

    if (educationCodes.length === 0) {
      return [];
    }

    const rows = await this.db.query<EducationRow>(
      `
      SELECT
          education_code,
          title,
          audience,
          content_type,
          body,
          status
        FROM knowledge.education
       WHERE status = 'active'
         AND education_code = ANY($1::text[])
      `,
      [educationCodes],
    );

    if (rows.length === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // 5. Index education records.
    // -------------------------------------------------------------------------
    const educationByCode = new Map<string, EducationRow>();

    for (const row of rows) {
      const code = row.education_code?.trim();

      if (!code) {
        continue;
      }

      // Deterministic first-record behavior in case the database unexpectedly
      // returns duplicate education codes.
      if (!educationByCode.has(code)) {
        educationByCode.set(code, row);
      }
    }

    // -------------------------------------------------------------------------
    // 6. Rank education according to the differential from which it originated.
    //
    // If education belongs to both #1 and #2 diagnoses, it is surfaced once
    // and inherits the higher-priority (#1) position.
    // -------------------------------------------------------------------------
    const bestRankByEducation = new Map<string, number>();

    for (const link of normalizedLinks) {
      const current = bestRankByEducation.get(link.educationCode);

      if (current == null || link.conditionRank < current) {
        bestRankByEducation.set(
          link.educationCode,
          link.conditionRank,
        );
      }
    }

    // -------------------------------------------------------------------------
    // 7. Build the canonical EducationItem output.
    // -------------------------------------------------------------------------
    const resolved = educationCodes
      .map((educationCode) => {
        const row = educationByCode.get(educationCode);

        if (!row) {
          return null;
        }

        const rank = bestRankByEducation.get(educationCode);

        if (rank == null) {
          return null;
        }

        return {
          educationCode: row.education_code.trim(),
          title: normalizeText(row.title),
          audience: normalizeText(row.audience),
          contentType: normalizeText(row.content_type),
          body: normalizeText(row.body),
          _rank: rank,
        };
      })
      .filter(
        (
          item,
        ): item is {
          educationCode: string;
          title: string;
          audience: string;
          contentType: string;
          body: string;
          _rank: number;
        } => item !== null,
      );

    // -------------------------------------------------------------------------
    // 8. Deterministic ordering.
    //
    // First:
    //   education attached to the highest-ranked differential.
    //
    // Then:
    //   education_code provides stable ordering inside the same rank.
    // -------------------------------------------------------------------------
    resolved.sort((a, b) => {
      if (a._rank !== b._rank) {
        return a._rank - b._rank;
      }

      return a.educationCode.localeCompare(b.educationCode);
    });

    // -------------------------------------------------------------------------
    // 9. Final defensive deduplication.
    // -------------------------------------------------------------------------
    const seenEducation = new Set<string>();
    const result: EducationItem[] = [];

    for (const item of resolved) {
      if (seenEducation.has(item.educationCode)) {
        continue;
      }

      seenEducation.add(item.educationCode);

      result.push({
        educationCode: item.educationCode,
        title: item.title,
        audience: item.audience,
        contentType: item.contentType,
        body: item.body,
      });
    }

    return result;
  }
}

/**
 * Normalize knowledge text at the CPU boundary.
 *
 * Knowledge content is expected to be authored correctly, but trimming here
 * prevents accidental whitespace from leaking into the clinical UI and keeps
 * empty records from becoming apparently valid education items.
 */
function normalizeText(value: string | null | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}