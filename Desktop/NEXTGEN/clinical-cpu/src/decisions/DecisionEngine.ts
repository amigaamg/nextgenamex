// =============================================================================
// AMEXAN Clinical CPU — DecisionEngine
// The decision loop. The CPU produces recommendations; the clinician remains
// the decision authority. Every recommendation, decision and reason is
// persisted to cpu.decision with the patient state and knowledge version.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ClinicalEvent, ProcessRequest, Recommendation } from '../types.js';

interface DecisionRow extends Row {
  id: string;
}

const URGENCY_ORDER: Record<string, number> = { immediate: 0, urgent: 1, routine: 2, info: 3 };

export class DecisionEngine {
  constructor(private readonly db: Db) {}

  async handleDecision(request: ProcessRequest): Promise<{ id: string; status: string } | null> {
    const payload = request.event.payload as Record<string, string>;
    const status = String(payload.status ?? 'accepted');
    if (!['accepted', 'modified', 'dismissed'].includes(status)) return null;

    const row = await this.db.queryOne<DecisionRow>(
      `INSERT INTO cpu.decision
          (patient_id, encounter_id, recommendation_type, recommendation_code, recommendation_text,
           recommendation_reason, status, decision_reason, decision_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id`,
      [
        request.patientId,
        request.encounterId ?? null,
        payload.type ?? 'unknown',
        payload.code ?? null,
        payload.recommendation ?? 'Decision',
        payload.reason ?? null,
        status,
        payload.decisionReason ?? null,
        request.clinicianId ?? null,
      ],
    );
    return { id: row!.id, status };
  }

  // Build a ranked recommendation list from the engines' output.
  build(
    investigations: { investigationCode: string; name: string; weight: number; rationale: string | null }[],
    treatment: { medicationCode: string; genericName: string; role: string; verified: boolean }[],
    monitoring: { monitoringCode: string; name: string; alert: string | null }[],
    education: { educationCode: string; title: string }[],
    alerts: { level: string; message: string }[],
  ): Recommendation[] {
    const recommendations: Recommendation[] = [];
    for (const inv of investigations) {
      recommendations.push({
        type: 'investigation',
        code: inv.investigationCode,
        text: `Order ${inv.name} (${inv.investigationCode})`,
        reason: inv.rationale ?? 'Relevant to the working differential',
        urgency: 'routine',
      });
    }
    for (const med of treatment) {
      recommendations.push({
        type: 'treatment',
        code: med.medicationCode,
        text: `Consider ${med.genericName} (${med.role})${med.verified ? '' : ' — dose requires clinical verification'}`,
        reason: 'Eligible option for the working diagnosis; clinician must confirm regimen and contraindications.',
        urgency: 'routine',
      });
    }
    for (const mon of monitoring) {
      recommendations.push({
        type: 'monitoring',
        code: mon.monitoringCode,
        text: `Monitor ${mon.name} (${mon.monitoringCode})`,
        reason: mon.alert ?? 'Protocol-mandated monitoring target',
        urgency: mon.alert ? 'urgent' : 'routine',
      });
    }
    for (const edu of education) {
      recommendations.push({
        type: 'education',
        code: edu.educationCode,
        text: `Deliver education: ${edu.title}`,
        reason: 'Bound to the working diagnosis',
        urgency: 'routine',
      });
    }
    for (const alert of alerts) {
      recommendations.push({
        type: 'alert',
        code: alert.level,
        text: alert.message,
        reason: 'Deterioration detection',
        urgency: alert.level,
      });
    }
    return recommendations.sort((a, b) => (URGENCY_ORDER[a.urgency] ?? 3) - (URGENCY_ORDER[b.urgency] ?? 3));
  }
}

export function isClinicianDecision(event: ClinicalEvent): boolean {
  return event.type === 'CLINICIAN_DECISION';
}
