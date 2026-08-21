// =============================================================================
// AMEXAN WorkflowEngine — durable workflow state machines
// =============================================================================
//
// The CPU is a clinical reasoning runtime; the WorkflowEngine is the care
// process runtime. Every encounter that enters the CPU gets a durable
// workflow instance drawn from the governed workflow definitions
// (workflow.definition → workflow.version → workflow.state/transition):
//
//   opd                  → outpatient_visit
//   ipd                  → inpatient_admission
//   emergency             → emergency_visit
//   day_case              → day_case
//   telemedicine          → telemedicine_visit
//
// Each CPU pass produces a phase (history, clinical_reasoning,
// investigation, management, safety_review, information_acquisition) that
// the engine maps onto the nearest valid workflow state and walks the
// governed transition graph to reach it, recording instance_events along
// the way. Tasks derived from recommendations are recorded as workflow.task
// rows so operational queues reflect the clinical state.
//
// This is durable and queryable: the admin Workflow view (§23) renders
// exactly these rows. The engine never decides medicine — it only tracks
// the process state the CPU's clinical phase implies.
// =============================================================================

import type { Db, Row } from '../db.js';
import { recordJourneyEvent, JourneyEventType } from '../observability/EventCore.js';

// =============================================================================
// TYPES
// =============================================================================

export interface WorkflowEnvelope {
  patientId: string;
  encounterId: string;
  encounterTypeCode?: string | null;
  createdBy?: string | null;
}

export interface WorkflowAdvanceInput {
  patientId: string;
  encounterId: string;
  phase: string;
  /** map from the current projection — used to derive tasks */
  recommendations?: Array<{ code?: string; title?: string; urgency?: string }>;
  eventBy?: string | null;
}

interface InstanceRow extends Row {
  id: string;
  workflow_version_id: string;
  entity_type: string;
  entity_id: string;
  current_state_id: string;
  status: string;
}

interface VersionRow extends Row {
  id: string;
  definition_code: string;
}

interface StateRow extends Row {
  id: string;
  code: string;
  state_kind: string;
}

interface TransitionRow extends Row {
  from_state_id: string;
  to_state_id: string;
}

// =============================================================================
// DEFINITION MAPPING
// =============================================================================

const ENCOUNTER_TO_DEFINITION: Record<string, string> = {
  opd: 'outpatient_visit',
  ipd: 'inpatient_admission',
  emergency: 'emergency_visit',
  er: 'emergency_visit',
  emergency_visit: 'emergency_visit',
  day_case: 'day_case',
  telemedicine: 'telemedicine_visit',
  telehealth: 'telemedicine_visit',
};

/** CPU phase → preferred workflow state code. */
const PHASE_TO_STATE: Record<string, string> = {
  information_acquisition: 'registration',
  history: 'registration',
  clinical_reasoning: 'assessment',
  investigation: 'investigation',
  management: 'treatment',
  safety_review: 'resuscitation',
  disposition: 'disposition',
};

// =============================================================================
// WORKFLOW ENGINE
// =============================================================================

export class WorkflowEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // INSTANTIATE
  // ===========================================================================

  /**
   * Ensure one workflow instance exists for the encounter. Returns the
   * instance id (existing or newly created).
   */
  async ensureInstance(input: WorkflowEnvelope): Promise<{ id: string; created: boolean }> {
    const existing = await this.db.queryOne<InstanceRow>(
      `SELECT id, workflow_version_id, entity_type, entity_id, current_state_id, status
         FROM workflow.instance
        WHERE entity_type = 'encounter' AND entity_id = $1`,
      [input.encounterId],
    );
    if (existing) {
      return { id: existing.id, created: false };
    }

    const definitionCode =
      ENCOUNTER_TO_DEFINITION[(input.encounterTypeCode ?? '').toLowerCase()] ??
      'outpatient_visit';

    const version = await this.db.queryOne<VersionRow>(
      `SELECT v.id, d.code AS definition_code
         FROM workflow.version v
         JOIN workflow.definition d ON d.id = v.definition_id
        WHERE d.code = $1 AND v.is_active = true
        ORDER BY v.version DESC
        LIMIT 1`,
      [definitionCode],
    );
    if (!version) {
      return { id: '', created: false };
    }

    const initial = await this.db.queryOne<StateRow>(
      `SELECT s.id, s.code, s.state_kind
         FROM workflow.state s
         JOIN workflow.version v ON v.id = $1
         JOIN workflow.transition t ON t.workflow_version_id = v.id
                                      AND t.from_state_id = s.id
         LEFT JOIN workflow.transition incoming
                ON incoming.workflow_version_id = v.id
               AND incoming.to_state_id = s.id
        WHERE incoming.id IS NULL
        ORDER BY s.code
        LIMIT 1`,
      [version.id],
    );
    if (!initial) {
      return { id: '', created: false };
    }

    const instance = await this.db.queryOne<InstanceRow>(
      `INSERT INTO workflow.instance
         (workflow_version_id, entity_type, entity_id, current_state_id,
          status, created_by)
       VALUES ($1, 'encounter', $2, $3, 'running', $4)
       RETURNING id, workflow_version_id, entity_type, entity_id,
                 current_state_id, status`,
      [version.id, input.encounterId, initial.id, input.createdBy ?? null],
    );

    await this.db.query(
      `INSERT INTO workflow.instance_event
         (instance_id, event_type, from_state_id, to_state_id, event_at, event_by, detail)
       VALUES ($1, 'INSTANCE_STARTED', NULL, $2, now(), $3, $4::jsonb)`,
      [
        instance!.id,
        initial.id,
        input.createdBy ?? null,
        JSON.stringify({ definitionCode, state: initial.code }),
      ],
    );

    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.SYSTEM_CHECKPOINT,
      patientId: input.patientId,
      encounterId: input.encounterId,
      sourceType: 'system',
      sourceId: 'workflow-engine',
      payload: {
        event: 'WORKFLOW_INSTANCE_CREATED',
        workflowInstanceId: instance!.id,
        definitionCode,
        state: initial.code,
      },
    });

    return { id: instance!.id, created: true };
  }

  // ===========================================================================
  // ADVANCE
  // ===========================================================================

  /**
   * Move the encounter's workflow instance along its governed transition
   * graph toward the state implied by the CPU phase. Records one
   * instance_event per transition taken.
   */
  async advance(input: WorkflowAdvanceInput): Promise<{ moved: boolean; state: string | null }> {
    const instance = await this.db.queryOne<InstanceRow>(
      `SELECT id, workflow_version_id, entity_type, entity_id, current_state_id, status
         FROM workflow.instance
        WHERE entity_type = 'encounter' AND entity_id = $1`,
      [input.encounterId],
    );
    if (!instance || instance.status !== 'running') {
      return { moved: false, state: null };
    }

    const targetCode = PHASE_TO_STATE[input.phase];
    if (!targetCode) {
      return { moved: false, state: null };
    }

    const current = await this.db.queryOne<StateRow>(
      `SELECT id, code, state_kind FROM workflow.state WHERE id = $1`,
      [instance.current_state_id],
    );
    if (!current || current.code === targetCode) {
      return { moved: false, state: current?.code ?? null };
    }

    const transitions = await this.db.query<TransitionRow>(
      `SELECT from_state_id, to_state_id
         FROM workflow.transition
        WHERE workflow_version_id = $1`,
      [instance.workflow_version_id],
    );

    const states = await this.db.query<StateRow>(
      `SELECT id, code, state_kind FROM workflow.state`,
    );
    const byId = new Map(states.map((s) => [s.id, s]));
    const codeToId = new Map(states.map((s) => [s.code, s.id]));

    const targetId = codeToId.get(targetCode);
    if (!targetId) {
      return { moved: false, state: current.code };
    }

    const path = this.shortestPath(
      instance.current_state_id,
      targetId,
      transitions,
      byId,
    );
    if (path.length === 0) {
      return { moved: false, state: current.code };
    }

    const events = await Promise.all(
      path.map(async (toId, index) => {
        const fromId = index === 0 ? instance.current_state_id : path[index - 1];
        const toState = byId.get(toId)!;
        await this.db.query(
          `INSERT INTO workflow.instance_event
             (instance_id, event_type, from_state_id, to_state_id,
              event_at, event_by, detail)
           VALUES ($1, 'STATE_CHANGED', $2, $3, now(), $4, $5::jsonb)`,
          [
            instance.id,
            fromId,
            toId,
            input.eventBy ?? null,
            JSON.stringify({ from: byId.get(fromId)?.code, to: toState.code, phase: input.phase }),
          ],
        );
        return toState;
      }),
    );

    const finalState = events[events.length - 1];
    await this.db.query(
      `UPDATE workflow.instance
          SET current_state_id = $2
        WHERE id = $1`,
      [instance.id, finalState.id],
    );

    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.SYSTEM_CHECKPOINT,
      patientId: input.patientId,
      encounterId: input.encounterId,
      sourceType: 'system',
      sourceId: 'workflow-engine',
      payload: {
        event: 'WORKFLOW_STATE_CHANGED',
        workflowInstanceId: instance.id,
        from: current.code,
        to: finalState.code,
        phase: input.phase,
      },
    });

    return { moved: true, state: finalState.code };
  }

  // ===========================================================================
  // TASKS
  // ===========================================================================

  /**
   * Record workflow tasks for active recommendations. Idempotent per
   * (instance, task_type, name) so repeated CPU passes do not duplicate rows.
   */
  async recordTasks(
    patientId: string,
    encounterId: string,
    recommendations: Array<{ code?: string; title?: string; urgency?: string }>,
  ): Promise<number> {
    const instance = await this.db.queryOne<InstanceRow>(
      `SELECT id, workflow_version_id, entity_type, entity_id, current_state_id, status
         FROM workflow.instance
        WHERE entity_type = 'encounter' AND entity_id = $1`,
      [encounterId],
    );
    if (!instance) return 0;

    let created = 0;
    for (const recommendation of recommendations) {
      if (!recommendation.code) continue;
      const exists = await this.db.queryOne<Row>(
        `SELECT id FROM workflow.task
          WHERE instance_id = $1 AND task_type = $2 AND name = $3`,
        [instance.id, recommendation.code, recommendation.title ?? recommendation.code],
      );
      if (exists) continue;

      await this.db.query(
        `INSERT INTO workflow.task
           (instance_id, task_type, name, description, data, status,
            priority, due_at)
         VALUES ($1, $2, $3, $4, $5::jsonb, 'pending', $6,
                 now() + interval '4 hours')`,
        [
          instance.id,
          recommendation.code,
          recommendation.title ?? recommendation.code,
          null,
          JSON.stringify({ patientId, encounterId }),
          recommendation.urgency === 'immediate'
            ? 10
            : recommendation.urgency === 'urgent'
              ? 6
              : 2,
        ],
      );
      created += 1;
    }

    return created;
  }

  // ===========================================================================
  // COMPLETE
  // ===========================================================================

  /** Move the instance to its terminal 'completed' state and mark ended. */
  async complete(patientId: string, encounterId: string, eventBy?: string | null): Promise<boolean> {
    const instance = await this.db.queryOne<InstanceRow>(
      `SELECT id, workflow_version_id, entity_type, entity_id, current_state_id, status
         FROM workflow.instance
        WHERE entity_type = 'encounter' AND entity_id = $1`,
      [encounterId],
    );
    if (!instance || instance.status !== 'running') return false;

    const transitions = await this.db.query<TransitionRow>(
      `SELECT from_state_id, to_state_id
         FROM workflow.transition
        WHERE workflow_version_id = $1`,
      [instance.workflow_version_id],
    );
    const states = await this.db.query<StateRow>(
      `SELECT id, code, state_kind FROM workflow.state`,
    );
    const byId = new Map(states.map((s) => [s.id, s]));
    const codeToId = new Map(states.map((s) => [s.code, s.id]));
    const completedId = codeToId.get('completed');
    if (!completedId || instance.current_state_id === completedId) {
      return false;
    }

    const path = this.shortestPath(instance.current_state_id, completedId, transitions, byId);
    if (path.length === 0) return false;

    let cursor = instance.current_state_id;
    for (const toId of path) {
      await this.db.query(
        `INSERT INTO workflow.instance_event
           (instance_id, event_type, from_state_id, to_state_id,
            event_at, event_by, detail)
         VALUES ($1, 'STATE_CHANGED', $2, $3, now(), $4, $5::jsonb)`,
        [
          instance.id,
          cursor,
          toId,
          eventBy ?? null,
          JSON.stringify({ from: byId.get(cursor)?.code, to: byId.get(toId)?.code }),
        ],
      );
      cursor = toId;
    }

    await this.db.query(
      `UPDATE workflow.instance
          SET current_state_id = $2, status = 'completed',
              ended_at = now()
        WHERE id = $1`,
      [instance.id, completedId],
    );

    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.SYSTEM_CHECKPOINT,
      patientId,
      encounterId,
      sourceType: 'system',
      sourceId: 'workflow-engine',
      payload: {
        event: 'WORKFLOW_COMPLETED',
        workflowInstanceId: instance.id,
      },
    });

    return true;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  private shortestPath(
    fromId: string,
    toId: string,
    transitions: TransitionRow[],
    byId: Map<string, StateRow>,
  ): string[] {
    const adjacency = new Map<string, string[]>();
    for (const t of transitions) {
      const list = adjacency.get(t.from_state_id) ?? [];
      list.push(t.to_state_id);
      adjacency.set(t.from_state_id, list);
    }

    const queue: Array<{ id: string; path: string[] }> = [{ id: fromId, path: [] }];
    const visited = new Set<string>([fromId]);

    while (queue.length > 0) {
      const { id, path } = queue.shift()!;
      for (const next of adjacency.get(id) ?? []) {
        if (next === toId) {
          return [...path, next];
        }
        if (visited.has(next)) continue;
        visited.add(next);
        queue.push({ id: next, path: [...path, next] });
      }
    }
    return [];
  }
}