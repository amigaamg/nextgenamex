// =============================================================================
// AMEXAN Clinical CPU — EducationEngine
// Resolves reusable patient/clinician education bound to the working diagnosis.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, EducationItem } from '../types.js';

interface EducationRow extends Row {
  education_code: string;
  title: string;
  audience: string;
  content_type: string;
  body: string;
}

interface EducationConditionRow extends Row {
  condition_code: string;
  education_code: string;
}

export class EducationEngine {
  constructor(private readonly db: Db) {}

  async resolve(differentials: DifferentialCandidate[]): Promise<EducationItem[]> {
    const topConditionCodes = differentials.slice(0, 2).map((d) => d.conditionCode);
    if (topConditionCodes.length === 0) return [];

    const links = await this.db.query<EducationConditionRow>(
      `SELECT c.condition_code, e.education_code
         FROM knowledge.education_condition ec
         JOIN knowledge.condition c ON c.id = ec.condition_id
         JOIN knowledge.education e ON e.id = ec.education_id
        WHERE c.condition_code = ANY($1::text[])`,
      [topConditionCodes],
    );

    const codes = [...new Set(links.map((l) => l.education_code))];
    if (codes.length === 0) return [];

    const rows = await this.db.query<EducationRow>(
      `SELECT education_code, title, audience, content_type, body FROM knowledge.education
        WHERE education_code = ANY($1::text[]) ORDER BY education_code`,
      [codes],
    );

    return rows.map((r) => ({
      educationCode: r.education_code,
      title: r.title,
      audience: r.audience,
      contentType: r.content_type,
      body: r.body,
    }));
  }
}
