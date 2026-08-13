// =============================================================================
// AMEXAN Clinical CPU — ClinicalEventBus
// Every clinically meaningful change becomes an event, is recorded in
// cpu.event_log, and re-triggers the nephron. The event log is the provenance
// chain: the system can always answer "what happened, when, and why did the
// machine change its mind?"
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ClinicalEvent, ProcessRequest } from '../types.js';

interface EventLogRow extends Row {
  id: number;
}

export class ClinicalEventBus {
  constructor(private readonly db: Db) {}

  async record(request: ProcessRequest): Promise<number> {
    const payload = {
      ...request.event.payload,
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
      clinicianId: request.clinicianId ?? null,
    };
    const row = await this.db.queryOne<EventLogRow>(
      `INSERT INTO cpu.event_log (event_type, payload, patient_id, encounter_id)
       VALUES ($1, $2::jsonb, $3, $4)
       RETURNING id`,
      [request.event.type, JSON.stringify(payload), request.patientId, request.encounterId ?? null],
    );
    return row!.id;
  }
}

export function eventLabel(event: ClinicalEvent): string {
  return event.type.replaceAll('_', ' ').toLowerCase();
}
