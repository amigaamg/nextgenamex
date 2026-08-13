// =============================================================================
// AMEXAN Clinical CPU — ResultInterpreter
// The closed loop (3.16): a lab/imaging result returns to the CPU as FACTS.
// The interpreter resolves an investigation result code (e.g. RLL_CONSOLIDATION)
// to the fact definitions it establishes via knowledge.investigation_result,
// so a CXR finding strengthens the SAME phenotypes and differential as if it had
// been reported by history or examination. A NORMAL result establishes nothing.
// =============================================================================

import type { Db, Row } from '../db.js';

export interface InterpreResult {
  facts: { factCode: string; value: unknown }[];
}

interface ResultRow extends Row {
  result_code: string;
  result_label: string;
  fact_definition_code: string | null;
}

export class ResultInterpreter {
  constructor(private readonly db: Db) {}

  async interpret(investigationCode: string, resultCodes: string[]): Promise<InterpreResult> {
    if (resultCodes.length === 0) return { facts: [] };
    const rows = await this.db.query<ResultRow>(
      `SELECT r.result_code, r.result_label, r.fact_definition_code
         FROM knowledge.investigation_result r
         JOIN knowledge.investigation inv ON inv.id = r.investigation_id
        WHERE inv.investigation_code = $1
          AND r.status = 'active'
          AND r.result_code = ANY($2::text[])
          AND r.fact_definition_code IS NOT NULL`,
      [investigationCode, resultCodes],
    );

    const seen = new Set<string>();
    const facts: { factCode: string; value: unknown }[] = [];
    for (const row of rows) {
      if (seen.has(row.fact_definition_code!)) continue;
      seen.add(row.fact_definition_code!);
      facts.push({ factCode: row.fact_definition_code!, value: true });
    }
    return { facts };
  }
}
