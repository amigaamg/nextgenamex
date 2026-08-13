// =============================================================================
// AMEXAN Clinical CPU — ExaminationInterpreter
// The examination engine keeps going through the same substrate (3.14): a
// captured examination finding resolves — through knowledge.examination_finding
// — to the clinical fact it establishes, so examination feeds the SAME reasoning
// as history. The UI may send a finding code (FIND-RLL-DULLNESS) or a fact code
// directly; the interpreter normalizes the former.
// =============================================================================

import type { Db, Row } from '../db.js';

interface FindingRow extends Row {
  finding_code: string;
  fact_definition_code: string | null;
}

export class ExaminationInterpreter {
  constructor(private readonly db: Db) {}

  async resolveFinding(findingCode: string): Promise<{ factDefinitionCode: string } | null> {
    const row = await this.db.queryOne<FindingRow>(
      `SELECT finding_code, fact_definition_code
         FROM knowledge.examination_finding
        WHERE finding_code = $1 AND status = 'active'`,
      [findingCode],
    );
    if (!row?.fact_definition_code) return null;
    return { factDefinitionCode: row.fact_definition_code };
  }
}
