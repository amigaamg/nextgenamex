// =============================================================================
// AMEXAN Clinical CPU — MonitoringEngine
// Baseline → measurement → trend → deviation → alert. Resolves the monitoring
// targets mandated by the active protocol, reads the patient's current value
// for each, and flags deterioration when the target is breached.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { Fact, MonitoringTarget } from '../types.js';

interface ProtocolMonitoringRow extends Row {
  protocol_code: string;
  monitoring_code: string;
  canonical_name: string;
  target_type: string;
  unit: string | null;
  normal_low: number | null;
  normal_high: number | null;
  frequency: string | null;
  deterioration_rule: string | null;
  escalation_instruction: string | null;
}

export class MonitoringEngine {
  constructor(private readonly db: Db) {}

  async resolve(protocolCode: string | null, facts: Fact[]): Promise<MonitoringTarget[]> {
    if (!protocolCode) return [];

    const rows = await this.db.query<ProtocolMonitoringRow>(
      `SELECT p.protocol_code, m.monitoring_code, m.canonical_name, m.target_type, m.unit,
              m.normal_low, m.normal_high, pm.frequency, pm.deterioration_rule, pm.escalation_instruction
         FROM knowledge.protocol_monitoring pm
         JOIN knowledge.protocol p ON p.id = pm.protocol_id
         JOIN knowledge.monitoring m ON m.id = pm.monitoring_id
        WHERE p.protocol_code = $1`,
      [protocolCode],
    );

    return rows.map((row) => {
      const latest = latestNumeric(facts, row.monitoring_code);
      const alert = assess(row, latest);
      return {
        monitoringCode: row.monitoring_code,
        name: row.canonical_name,
        targetType: row.target_type,
        unit: row.unit,
        frequency: row.frequency,
        deteriorationRule: row.deterioration_rule,
        escalationInstruction: row.escalation_instruction,
        currentValue: latest != null ? `${latest}` : null,
        alert,
      };
    });
  }
}

function latestNumeric(facts: Fact[], code: string): number | null {
  const fact = [...facts].reverse().find((f) => f.factCode === code);
  if (!fact) return null;
  const numeric = fact.values.find((v) => v.numeric != null);
  return numeric?.numeric ?? null;
}

function assess(row: ProtocolMonitoringRow, value: number | null): string | null {
  if (value == null) return null;
  if (row.normal_low != null && value < row.normal_low) {
    return `${row.canonical_name} ${value} is below target (${row.normal_low})`;
  }
  if (row.normal_high != null && value > row.normal_high) {
    return `${row.canonical_name} ${value} is above target (${row.normal_high})`;
  }
  return null;
}
