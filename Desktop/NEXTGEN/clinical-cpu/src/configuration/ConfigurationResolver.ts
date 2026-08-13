// =============================================================================
// AMEXAN Clinical CPU — ConfigurationResolver
// The configuration engine (3.19): the AMEXAN DEFAULT knowledge is the baseline;
// facilities, departments and clinicians express LOCAL overrides that layer on
// top without mutating the original. This resolver reads the currently active
// override per target through knowledge.active_override (scope precedence:
// clinician > facility > department > organization > global) and exposes the
// full provenance chain: baseline + override + version + reason.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ConfigurationOverride } from '../types.js';

interface OverrideRow extends Row {
  override_code: string;
  target_type: string;
  target_id: string;
  scope_code: string;
  config: unknown;
  reason: string | null;
  version: number;
  target_code: string;
}

// Whitelisted target tables so the code column is never interpolated unsafely.
const TARGET_TABLES: Record<string, { table: string; codeColumn: string }> = {
  investigation: { table: 'knowledge.investigation', codeColumn: 'investigation_code' },
  condition: { table: 'knowledge.condition', codeColumn: 'condition_code' },
  protocol: { table: 'knowledge.protocol', codeColumn: 'protocol_code' },
  medication: { table: 'knowledge.medication', codeColumn: 'medication_code' },
  question: { table: 'knowledge.question', codeColumn: 'question_code' },
  phenotype: { table: 'knowledge.phenotype', codeColumn: 'phenotype_code' },
  mechanism: { table: 'knowledge.mechanism', codeColumn: 'mechanism_code' },
};

export class ConfigurationResolver {
  constructor(private readonly db: Db) {}

  async resolve(targets: { type: string; code: string }[]): Promise<ConfigurationOverride[]> {
    const overrides: ConfigurationOverride[] = [];
    for (const target of targets) {
      const table = TARGET_TABLES[target.type];
      if (!table) continue;
      const row = await this.db.queryOne<OverrideRow>(
        `SELECT o.override_code, o.target_type, o.target_id, o.scope_code, o.config, o.reason, o.version,
                c.${table.codeColumn} AS target_code
           FROM knowledge.active_override o
           JOIN ${table.table} c ON c.id = o.target_id
          WHERE o.target_type = $1 AND c.${table.codeColumn} = $2`,
        [target.type, target.code],
      );
      if (!row) continue;
      overrides.push({
        overrideCode: row.override_code,
        targetType: row.target_type,
        targetCode: row.target_code as string,
        scopeCode: row.scope_code,
        config: (row.config as Record<string, unknown>) ?? {},
        reason: row.reason,
        version: Number(row.version),
      });
    }
    return overrides;
  }
}
