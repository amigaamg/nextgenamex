// =============================================================================
// AMEXAN Clinical CPU — ExaminationSelector
// Chooses which examination modules are worth performing based on the current
// differential, then lists their findings. Findings become facts through the
// ingestion engine (source = examination), so examination feeds the SAME
// reasoning substrate as history.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, ExaminationModuleView } from '../types.js';

interface ModuleRow extends Row {
  module_code: string;
  canonical_name: string;
  sort_order: number;
}

interface FindingRow extends Row {
  module_code: string;
  finding_code: string;
  canonical_name: string;
  fact_definition_code: string | null;
  finding_type: string;
  sort_order: number;
}

interface ExamConditionRow extends Row {
  condition_code: string;
  module_code: string;
}

export class ExaminationSelector {
  constructor(private readonly db: Db) {}

  async select(differentials: DifferentialCandidate[]): Promise<ExaminationModuleView[]> {
    const topConditionCodes = differentials.slice(0, 2).map((d) => d.conditionCode);
    if (topConditionCodes.length === 0) return [];

    const examLinks = await this.db.query<ExamConditionRow>(
      `SELECT c.condition_code, em.module_code
         FROM knowledge.examination_condition ec
         JOIN knowledge.condition c ON c.id = ec.condition_id
         JOIN knowledge.examination_module em ON em.id = ec.examination_module_id
        WHERE c.condition_code = ANY($1::text[])`,
      [topConditionCodes],
    );

    // Always offer the general examination.
    const moduleCodes = new Set(['EXAM-GENERAL', ...examLinks.map((l) => l.module_code)]);
    if (moduleCodes.size === 0) return [];

    const [modules, findings] = await Promise.all([
      this.db.query<ModuleRow>(
        `SELECT module_code, canonical_name, sort_order FROM knowledge.examination_module WHERE module_code = ANY($1::text[]) ORDER BY sort_order`,
        [[...moduleCodes]],
      ),
      this.db.query<FindingRow>(
        `SELECT em.module_code, f.finding_code, f.canonical_name, f.fact_definition_code, f.finding_type, f.sort_order
           FROM knowledge.examination_finding f
           JOIN knowledge.examination_module em ON em.id = f.module_id
          WHERE em.module_code = ANY($1::text[])
          ORDER BY em.module_code, f.sort_order`,
        [[...moduleCodes]],
      ),
    ]);

    const findingsByModule = new Map<string, FindingRow[]>();
    for (const f of findings) {
      const list = findingsByModule.get(f.module_code) ?? [];
      list.push(f);
      findingsByModule.set(f.module_code, list);
    }

    return modules.map((m) => ({
      moduleCode: m.module_code,
      name: m.canonical_name,
      findings: (findingsByModule.get(m.module_code) ?? []).map((f) => ({
        findingCode: f.finding_code,
        name: f.canonical_name,
        factDefinitionCode: f.fact_definition_code,
        findingType: f.finding_type,
      })),
    }));
  }
}
