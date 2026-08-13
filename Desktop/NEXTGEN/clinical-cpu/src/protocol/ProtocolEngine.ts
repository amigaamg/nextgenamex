// =============================================================================
// AMEXAN Clinical CPU — ProtocolEngine
// Activates the protocol for the leading working diagnosis, then returns its
// ordered steps with the concrete actions (investigate / medicate / monitor /
// educate) each step fires. The protocol coordinates; it never re-defines
// medicine — actions reference the reusable knowledge objects by code.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, ProtocolActionView, ProtocolStepView, ProtocolView } from '../types.js';

interface ProtocolRow extends Row {
  protocol_code: string;
  canonical_name: string;
  purpose: string | null;
  status: string;
}

interface ConditionLinkRow extends Row {
  condition_code: string;
  protocol_code: string;
}

interface StepRow extends Row {
  protocol_code: string;
  step_code: string;
  step_label: string;
  step_type: string;
  sequence_no: number;
  instruction: string;
  rationale: string | null;
  required: boolean;
}

interface ActionRow extends Row {
  protocol_code: string;
  step_code: string;
  action_type: string;
  action_code: string;
  action_name: string;
  detail: string | null;
  urgency: string;
  sort_order: number;
}

export class ProtocolEngine {
  constructor(private readonly db: Db) {}

  async activate(differentials: DifferentialCandidate[]): Promise<ProtocolView | null> {
    const top = differentials[0];
    if (!top) return null;

    const link = await this.db.queryOne<ConditionLinkRow>(
      `SELECT c.condition_code, p.protocol_code
         FROM knowledge.protocol_condition pc
         JOIN knowledge.condition c ON c.id = pc.condition_id
         JOIN knowledge.protocol p ON p.id = pc.protocol_id
        WHERE c.condition_code = $1
        ORDER BY p.status DESC, pc.is_primary DESC
        LIMIT 1`,
      [top.conditionCode],
    );
    if (!link) return null;

    const protocol = await this.db.queryOne<ProtocolRow>(
      `SELECT protocol_code, canonical_name, purpose, status FROM knowledge.protocol WHERE protocol_code = $1`,
      [link.protocol_code],
    );
    if (!protocol) return null;

    const [steps, actions] = await Promise.all([
      this.db.query<StepRow>(
        `SELECT p.protocol_code, ps.step_code, ps.step_label, ps.step_type, ps.sequence_no,
                ps.instruction, ps.rationale, ps.required
           FROM knowledge.protocol_step ps
           JOIN knowledge.protocol p ON p.id = ps.protocol_id
          WHERE p.protocol_code = $1
          ORDER BY ps.sequence_no`,
        [protocol.protocol_code],
      ),
      this.db.query<ActionRow>(
        `SELECT p.protocol_code, ps.step_code, pa.action_type, pa.action_code, pa.action_name,
                pa.detail, pa.urgency, pa.sort_order
           FROM knowledge.protocol_action pa
           JOIN knowledge.protocol_step ps ON ps.id = pa.step_id
           JOIN knowledge.protocol p ON p.id = pa.protocol_id
          WHERE p.protocol_code = $1
          ORDER BY pa.sort_order`,
        [protocol.protocol_code],
      ),
    ]);

    const actionsByStep = new Map<string, ProtocolActionView[]>();
    for (const a of actions) {
      const list = actionsByStep.get(a.step_code) ?? [];
      list.push({ actionType: a.action_type, actionCode: a.action_code, actionName: a.action_name, detail: a.detail, urgency: a.urgency });
      actionsByStep.set(a.step_code, list);
    }

    const stepViews: ProtocolStepView[] = steps.map((s) => ({
      stepCode: s.step_code,
      label: s.step_label,
      stepType: s.step_type,
      sequenceNo: s.sequence_no,
      instruction: s.instruction,
      rationale: s.rationale,
      required: s.required,
      actions: actionsByStep.get(s.step_code) ?? [],
    }));

    return {
      protocolCode: protocol.protocol_code,
      name: protocol.canonical_name,
      purpose: protocol.purpose,
      status: protocol.status,
      steps: stepViews,
    };
  }
}
