// =============================================================================
// Clinical timeline — the cpu.event_log rendered as a longitudinal encounter
// story (4.26 / 4.44). The event log IS the provenance chain.
// =============================================================================

import type { Db, Row } from '../src/index.js';

export interface TimelineEntry {
  eventId: number;
  eventType: string;
  payload: Record<string, unknown>;
  occurredAt: string;
}

interface TimelineRow extends Row {
  id: number;
  event_type: string;
  payload: unknown;
  occurred_at: string;
}

export async function timelineForPatient(db: Db, patientId: string): Promise<TimelineEntry[]> {
  const rows = await db.query<TimelineRow>(
    `SELECT id, event_type, payload, occurred_at
       FROM cpu.event_log
      WHERE patient_id = $1
      ORDER BY occurred_at, id`,
    [patientId],
  );
  return rows.map((r) => ({
    eventId: Number(r.id),
    eventType: r.event_type,
    payload: (r.payload as Record<string, unknown>) ?? {},
    occurredAt: r.occurred_at,
  }));
}
