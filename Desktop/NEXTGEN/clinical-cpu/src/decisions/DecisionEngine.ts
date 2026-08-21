// =============================================================================
// AMEXAN Clinical CPU — DecisionEngine
//
// PURPOSE
// -------
// The DecisionEngine is the ACTION/DECISION layer of the AMEXAN Clinical CPU.
//
// ContextResolver builds the canonical PatientClinicalState.
// Clinical engines evaluate that state and produce candidate actions.
// DecisionEngine:
//
//   1. normalizes candidate actions
//   2. removes invalid/duplicate recommendations
//   3. applies clinical safety gates
//   4. assigns urgency and priority
//   5. preserves rationale/provenance
//   6. separates CPU recommendation from clinician decision
//   7. persists clinician decisions
//   8. provides deterministic ranking
//
// IMPORTANT CLINICAL PRINCIPLE
// ----------------------------
// AMEXAN does NOT autonomously diagnose, prescribe, or execute treatment.
//
// The CPU may:
//   - identify clinically relevant actions
//   - identify danger signals
//   - suggest investigations
//   - suggest treatment options
//   - suggest monitoring
//   - suggest education
//   - identify missing information
//
// The clinician remains responsible for the final clinical decision.
//
// Every recommendation should therefore be interpreted as:
//
//     "AMEXAN recommends consideration of X because Y,
//      subject to the patient's complete clinical context,
//      contraindications, local protocol and clinician judgement."
//
// Every clinician response is separately recorded.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  ClinicalEvent,
  ProcessRequest,
  Recommendation,
} from '../types.js';
import {
  JourneyEventType,
  recordJourneyEvent,
} from '../observability/EventCore.js';


// =============================================================================
// DATABASE TYPES
// =============================================================================

interface DecisionRow extends Row {
  id: string;
}


// =============================================================================
// CLINICAL TYPES
// =============================================================================

export type DecisionStatus =
  | 'accepted'
  | 'modified'
  | 'dismissed';

export type RecommendationType =
  | 'alert'
  | 'investigation'
  | 'treatment'
  | 'monitoring'
  | 'education'
  | 'referral'
  | 'procedure'
  | 'prevention'
  | 'follow_up'
  | 'missing_information';

export type RecommendationUrgency =
  | 'immediate'
  | 'urgent'
  | 'routine'
  | 'info';

export type RecommendationConfidence =
  | 'high'
  | 'moderate'
  | 'low'
  | 'unknown';


// =============================================================================
// URGENCY
// =============================================================================
//
// Lower number = higher clinical priority.
//
// IMMEDIATE:
//   Action required now because delay may result in significant harm.
//
// URGENT:
//   Action should occur promptly but is not necessarily a resuscitation issue.
//
// ROUTINE:
//   Appropriate during normal clinical workflow.
//
// INFO:
//   Educational/contextual information without immediate action.
//
// =============================================================================

const URGENCY_ORDER: Record<RecommendationUrgency, number> = {
  immediate: 0,
  urgent: 1,
  routine: 2,
  info: 3,
};


// =============================================================================
// RECOMMENDATION PRIORITY
// =============================================================================
//
// This allows AMEXAN to rank recommendations beyond urgency.
//
// Example:
//
//   immediate + safety alert
//       >
//   urgent + investigation
//       >
//   routine + treatment
//       >
//   routine + education
//
// =============================================================================

const TYPE_PRIORITY: Record<RecommendationType, number> = {
  alert: 100,
  treatment: 80,
  procedure: 78,
  investigation: 70,
  referral: 68,
  monitoring: 60,
  prevention: 50,
  follow_up: 45,
  missing_information: 40,
  education: 20,
};


// =============================================================================
// SAFE WEIGHT LOOKUPS
// =============================================================================
//
// Recommendation.urgency / Recommendation.type are typed as plain strings
// because they may originate from arbitrary database input. These helpers
// narrow them to the known unions before indexing the weighted records,
// so an unknown value falls back to the least-prioritized weight instead of
// silently weakening the Record typing.
// =============================================================================

function isRecommendationUrgency(
  value: string,
): value is RecommendationUrgency {
  return value in URGENCY_ORDER;
}

function isRecommendationType(
  value: string,
): value is RecommendationType {
  return value in TYPE_PRIORITY;
}

function getUrgencyOrder(value: string): number {
  return isRecommendationUrgency(value)
    ? URGENCY_ORDER[value]
    : 3;
}

function getTypePriority(value: string): number {
  return isRecommendationType(value)
    ? TYPE_PRIORITY[value]
    : 0;
}


// =============================================================================
// INPUT CONTRACTS
// =============================================================================

export interface InvestigationCandidate {
  investigationCode: string;
  name: string;

  /**
   * Clinical relevance score supplied by the investigation engine.
   * Expected range: 0–100.
   */
  weight: number;

  rationale: string | null;

  /**
   * Optional knowledge/rule provenance.
   */
  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;

  /**
   * Whether this investigation is essential for immediate decision-making.
   */
  urgent?: boolean;

  /**
   * Optional indication supporting the investigation.
   */
  indication?: string | null;

  /**
   * Whether the investigation has already been performed.
   */
  alreadyPerformed?: boolean;

  /**
   * Whether this candidate requires clinician confirmation before ordering.
   */
  requiresConfirmation?: boolean;
}


export interface TreatmentCandidate {
  medicationCode: string;
  genericName: string;
  role: string;

  /**
   * True only when AMEXAN's medication/rule layer has verified the
   * required information for this patient context.
   */
  verified: boolean;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;

  /**
   * Optional clinical rationale.
   */
  rationale?: string | null;

  /**
   * Optional safety information supplied by the treatment engine.
   */
  contraindications?: string[];
  cautions?: string[];
  interactions?: string[];

  /**
   * True when the treatment engine requires clinician confirmation.
   */
  requiresConfirmation?: boolean;

  /**
   * True when the candidate has failed a safety gate.
   */
  blocked?: boolean;

  /**
   * Reason for blocking.
   */
  blockedReason?: string | null;
}


export interface MonitoringCandidate {
  monitoringCode: string;
  name: string;

  alert: string | null;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;

  /**
   * Optional reason why this monitoring target is required.
   */
  rationale?: string | null;

  /**
   * Immediate monitoring should be promoted to urgent.
   */
  immediate?: boolean;
}


export interface EducationCandidate {
  educationCode: string;
  title: string;

  rationale?: string | null;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;
}


export interface AlertCandidate {
  level: RecommendationUrgency;
  message: string;

  /**
   * Stable clinical code is strongly preferred over using the
   * severity level itself as the recommendation code.
   */
  code?: string;

  rationale?: string | null;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;
}


export interface ReferralCandidate {
  referralCode: string;
  serviceName: string;

  rationale: string;

  urgency?: RecommendationUrgency;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;
}


export interface ProcedureCandidate {
  procedureCode: string;
  name: string;

  rationale: string;

  urgency?: RecommendationUrgency;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;
}


export interface FollowUpCandidate {
  followUpCode: string;
  description: string;

  rationale: string;

  urgency?: RecommendationUrgency;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;
}


export interface MissingInformationCandidate {
  informationCode: string;
  description: string;

  rationale: string;

  urgency?: RecommendationUrgency;
}


// =============================================================================
// EXTENDED INTERNAL RECOMMENDATION
// =============================================================================
//
// We deliberately keep the public Recommendation compatible with the existing
// AMEXAN type while allowing richer internal metadata.
//
// If the Recommendation type is later expanded, these fields can become part
// of the canonical type instead of being intersected here.
// =============================================================================

type EngineRecommendation = Recommendation & {
  priority?: number;
  confidence?: RecommendationConfidence;

  knowledgeCode?: string | null;
  knowledgeVersion?: string | null;

  provenance?: string[];

  requiresConfirmation?: boolean;

  safetyBlocked?: boolean;
  safetyReason?: string | null;

  indication?: string | null;
};


// =============================================================================
// DECISION ENGINE
// =============================================================================

export class DecisionEngine {
  constructor(private readonly db: Db) {}


  // ===========================================================================
  // CLINICIAN DECISION
  // ===========================================================================
  //
  // This method records what the clinician did with an AMEXAN recommendation.
  //
  // IMPORTANT:
  //   ACCEPTED does NOT mean AMEXAN executed the treatment.
  //
  //   It means the clinician accepted the recommendation.
  //
  // MODIFIED means the clinician used the recommendation as a basis but
  // changed it.
  //
  // DISMISSED means the clinician intentionally rejected it.
  //
  // ===========================================================================

  async handleDecision(
    request: ProcessRequest,
  ): Promise<{ id: string; status: DecisionStatus } | null> {

    const payload = asRecord(request.event.payload);

    const status = normalizeDecisionStatus(payload.status);

    if (!status) {
      return null;
    }

    const recommendationType =
      normalizeString(payload.type) ?? 'unknown';

    const recommendationCode =
      normalizeString(payload.code);

    const recommendationText =
      normalizeString(payload.recommendation) ?? 'Clinical decision';

    const recommendationReason =
      normalizeString(payload.reason);

    const decisionReason =
      normalizeString(payload.decisionReason);

    const clinicianId =
      request.clinicianId ?? null;


    // -------------------------------------------------------------------------
    // Safety invariant:
    //
    // A clinician decision should be attributable whenever possible.
    // We do not reject historical/system events solely because clinicianId
    // is unavailable, because automated migration/replay/audit processes may
    // legitimately lack it.
    // -------------------------------------------------------------------------

    const row = await this.db.queryOne<DecisionRow>(
      `
      INSERT INTO cpu.decision
      (
        patient_id,
        encounter_id,

        recommendation_type,
        recommendation_code,
        recommendation_text,
        recommendation_reason,

        status,
        decision_reason,
        decision_by
      )
      VALUES
      (
        $1, $2,
        $3, $4, $5, $6,
        $7, $8, $9
      )
      RETURNING id
      `,
      [
        request.patientId,
        request.encounterId ?? null,

        recommendationType,
        recommendationCode,
        recommendationText,
        recommendationReason,

        status,
        decisionReason,
        clinicianId,
      ],
    );


    if (!row) {
      throw new Error(
        'AMEXAN DecisionEngine: decision insert returned no row',
      );
    }

    // Event Core — record the clinician's response to the recommendation so the
    // journey shows exactly how suggestions are received (accept/modify/reject).
    await recordJourneyEvent(this.db, {
      eventType:
        status === 'accepted'
          ? JourneyEventType.SUGGESTION_ACCEPTED
          : status === 'modified'
            ? JourneyEventType.SUGGESTION_MODIFIED
            : JourneyEventType.SUGGESTION_REJECTED,
      patientId: request.patientId,
      encounterId: request.encounterId ?? null,
      sourceType: 'clinician',
      sourceId: clinicianId ?? null,
      payload: {
        recommendationType,
        recommendationCode,
        recommendationText,
        recommendationReason,
        decisionReason,
        decisionId: row.id,
      },
    });

    return {
      id: row.id,
      status,
    };
  }


  // ===========================================================================
  // BUILD RECOMMENDATIONS
  // ===========================================================================
  //
  // This method converts outputs from the clinical engines into a single
  // deterministic recommendation queue.
  //
  // It does NOT diagnose.
  // It does NOT prescribe.
  // It does NOT execute orders.
  //
  // ===========================================================================

  build(
    investigations: InvestigationCandidate[],
    treatment: TreatmentCandidate[],
    monitoring: MonitoringCandidate[],
    education: EducationCandidate[],
    alerts: AlertCandidate[],
    referrals: ReferralCandidate[] = [],
    procedures: ProcedureCandidate[] = [],
    followUps: FollowUpCandidate[] = [],
    missingInformation: MissingInformationCandidate[] = [],
  ): Recommendation[] {

    const recommendations: EngineRecommendation[] = [];


    // =========================================================================
    // ALERTS
    // =========================================================================

    for (const alert of alerts) {

      const message = cleanText(alert.message);

      if (!message) {
        continue;
      }

      const urgency = normalizeUrgency(alert.level);

      recommendations.push(
        this.createRecommendation({
          type: 'alert',
          code: cleanText(alert.code ?? '') || alert.level,
          text: message,
          reason:
            cleanText(alert.rationale ?? '') ||
            'Potential clinical deterioration or safety concern detected.',
          urgency,
          confidence: 'high',
          knowledgeCode: alert.knowledgeCode,
          knowledgeVersion: alert.knowledgeVersion,
          requiresConfirmation: true,
          provenance: ['clinical_alert_engine'],
        }),
      );
    }


    // =========================================================================
    // INVESTIGATIONS
    // =========================================================================

    for (const investigation of investigations) {

      const code = cleanText(investigation.investigationCode);
      const name = cleanText(investigation.name);

      if (!code || !name) {
        continue;
      }

      // Do not recommend an investigation that the engine explicitly reports
      // as already completed unless the investigation engine deliberately
      // sends it back for repeat testing.
      if (investigation.alreadyPerformed) {
        continue;
      }

      const urgency: RecommendationUrgency =
        investigation.urgent
          ? 'urgent'
          : 'routine';

      const confidence = confidenceFromWeight(investigation.weight);

      const reason =
        cleanText(investigation.rationale ?? '') ||
        cleanText(investigation.indication ?? '') ||
        'Relevant to the current clinical assessment.';

      recommendations.push(
        this.createRecommendation({
          type: 'investigation',
          code,
          text: `Consider ${name} (${code})`,
          reason,
          urgency,
          confidence,
          knowledgeCode: investigation.knowledgeCode,
          knowledgeVersion: investigation.knowledgeVersion,
          requiresConfirmation:
            investigation.requiresConfirmation ?? true,
          indication: investigation.indication,
          provenance: ['investigation_engine'],
        }),
      );
    }


    // =========================================================================
    // TREATMENT
    // =========================================================================

    for (const medication of treatment) {

      const code = cleanText(medication.medicationCode);
      const genericName = cleanText(medication.genericName);
      const role = cleanText(medication.role);

      if (!code || !genericName) {
        continue;
      }


      // -----------------------------------------------------------------------
      // HARD SAFETY GATE
      // -----------------------------------------------------------------------
      //
      // A blocked medication must never appear as an ordinary treatment
      // recommendation.
      //
      // Instead, AMEXAN surfaces the safety issue as an alert-like
      // recommendation requiring clinician review.
      // -----------------------------------------------------------------------

      if (medication.blocked) {

        const reason =
          cleanText(medication.blockedReason ?? '') ||
          'Treatment candidate failed a clinical safety gate.';

        recommendations.push(
          this.createRecommendation({
            type: 'alert',
            code: `TREATMENT_BLOCKED:${code}`,
            text:
              `Do not proceed with ${genericName} without resolving the safety issue.`,
            reason,
            urgency: 'urgent',
            confidence: 'high',
            knowledgeCode: medication.knowledgeCode,
            knowledgeVersion: medication.knowledgeVersion,
            requiresConfirmation: true,
            safetyBlocked: true,
            safetyReason: reason,
            provenance: ['treatment_safety_engine'],
          }),
        );

        continue;
      }


      const safetyWarnings = [
        ...(medication.contraindications ?? []),
        ...(medication.cautions ?? []),
        ...(medication.interactions ?? []),
      ]
        .map(cleanText)
        .filter(Boolean);


      let text =
        `Consider ${genericName}` +
        (role ? ` (${role})` : '');


      if (!medication.verified) {
        text += ' — regimen requires clinical verification';
      }


      if (safetyWarnings.length > 0) {
        text += ' — review safety considerations';
      }


      const reason =
        cleanText(medication.rationale ?? '') ||
        'Potential treatment option for the current clinical problem; confirm indication, contraindications, interactions, allergies, organ function, age/weight requirements, and local protocol before use.';


      recommendations.push(
        this.createRecommendation({
          type: 'treatment',
          code,
          text,
          reason,
          urgency: 'routine',
          confidence:
            medication.verified
              ? 'moderate'
              : 'low',
          knowledgeCode: medication.knowledgeCode,
          knowledgeVersion: medication.knowledgeVersion,
          requiresConfirmation: true,
          provenance: ['treatment_engine'],
        }),
      );


      // -----------------------------------------------------------------------
      // SAFETY WARNINGS ARE PRESERVED AS SEPARATE INFORMATION
      // -----------------------------------------------------------------------
      //
      // We intentionally do not silently discard contraindications/cautions.
      // They are important clinical provenance.
      //
      // If the Recommendation schema later supports structured safety metadata,
      // attach them there rather than encoding them in free text.
      // -----------------------------------------------------------------------
    }


    // =========================================================================
    // MONITORING
    // =========================================================================

    for (const monitor of monitoring) {

      const code = cleanText(monitor.monitoringCode);
      const name = cleanText(monitor.name);

      if (!code || !name) {
        continue;
      }

      const alert =
        cleanText(monitor.alert ?? '');

      const reason =
        alert ||
        cleanText(monitor.rationale ?? '') ||
        'Monitoring target relevant to the current clinical state.';

      const urgency: RecommendationUrgency =
        monitor.immediate || alert
          ? 'urgent'
          : 'routine';

      recommendations.push(
        this.createRecommendation({
          type: 'monitoring',
          code,
          text: `Monitor ${name} (${code})`,
          reason,
          urgency,
          confidence: 'moderate',
          knowledgeCode: monitor.knowledgeCode,
          knowledgeVersion: monitor.knowledgeVersion,
          requiresConfirmation: false,
          provenance: ['monitoring_engine'],
        }),
      );
    }


    // =========================================================================
    // REFERRALS
    // =========================================================================

    for (const referral of referrals) {

      const code = cleanText(referral.referralCode);
      const service = cleanText(referral.serviceName);

      if (!code || !service) {
        continue;
      }

      recommendations.push(
        this.createRecommendation({
          type: 'referral',
          code,
          text: `Consider referral to ${service}`,
          reason:
            cleanText(referral.rationale) ||
            'Referral may be appropriate based on the current clinical state.',
          urgency:
            referral.urgency ?? 'routine',
          confidence: 'moderate',
          knowledgeCode: referral.knowledgeCode,
          knowledgeVersion: referral.knowledgeVersion,
          requiresConfirmation: true,
          provenance: ['referral_engine'],
        }),
      );
    }


    // =========================================================================
    // PROCEDURES
    // =========================================================================

    for (const procedure of procedures) {

      const code = cleanText(procedure.procedureCode);
      const name = cleanText(procedure.name);

      if (!code || !name) {
        continue;
      }

      recommendations.push(
        this.createRecommendation({
          type: 'procedure',
          code,
          text: `Consider ${name}`,
          reason:
            cleanText(procedure.rationale) ||
            'Procedure may be appropriate for the current clinical problem.',
          urgency:
            procedure.urgency ?? 'routine',
          confidence: 'moderate',
          knowledgeCode: procedure.knowledgeCode,
          knowledgeVersion: procedure.knowledgeVersion,
          requiresConfirmation: true,
          provenance: ['procedure_engine'],
        }),
      );
    }


    // =========================================================================
    // FOLLOW-UP
    // =========================================================================

    for (const followUp of followUps) {

      const code = cleanText(followUp.followUpCode);
      const description = cleanText(followUp.description);

      if (!code || !description) {
        continue;
      }

      recommendations.push(
        this.createRecommendation({
          type: 'follow_up',
          code,
          text: description,
          reason:
            cleanText(followUp.rationale) ||
            'Follow-up is relevant to ongoing clinical management.',
          urgency:
            followUp.urgency ?? 'routine',
          confidence: 'moderate',
          knowledgeCode: followUp.knowledgeCode,
          knowledgeVersion: followUp.knowledgeVersion,
          requiresConfirmation: true,
          provenance: ['follow_up_engine'],
        }),
      );
    }


    // =========================================================================
    // MISSING INFORMATION
    // =========================================================================
    //
    // This is extremely important for AMEXAN.
    //
    // The CPU should not manufacture certainty when critical information is
    // absent. Instead, it should tell the clinician what information is
    // required to safely continue reasoning.
    //
    // ==========================================================================

    for (const missing of missingInformation) {

      const code = cleanText(missing.informationCode);
      const description = cleanText(missing.description);

      if (!code || !description) {
        continue;
      }

      recommendations.push(
        this.createRecommendation({
          type: 'missing_information',
          code,
          text: `Obtain ${description}`,
          reason:
            cleanText(missing.rationale) ||
            'Required information is currently unavailable for complete clinical assessment.',
          urgency:
            missing.urgency ?? 'urgent',
          confidence: 'high',
          requiresConfirmation: false,
          provenance: ['clinical_completeness_engine'],
        }),
      );
    }


    // =========================================================================
    // EDUCATION
    // =========================================================================

    for (const educationItem of education) {

      const code = cleanText(educationItem.educationCode);
      const title = cleanText(educationItem.title);

      if (!code || !title) {
        continue;
      }

      recommendations.push(
        this.createRecommendation({
          type: 'education',
          code,
          text: `Provide education: ${title}`,
          reason:
            cleanText(educationItem.rationale ?? '') ||
            'Patient education is relevant to the current clinical management plan.',
          urgency: 'routine',
          confidence: 'moderate',
          knowledgeCode: educationItem.knowledgeCode,
          knowledgeVersion: educationItem.knowledgeVersion,
          requiresConfirmation: false,
          provenance: ['education_engine'],
        }),
      );
    }


    // =========================================================================
    // DEDUPLICATION
    // =========================================================================

    const deduplicated =
      this.deduplicate(recommendations);


    // =========================================================================
    // FINAL DETERMINISTIC SORT
    // =========================================================================

    deduplicated.sort(compareRecommendations);


    return deduplicated;
  }


  // ===========================================================================
  // RECOMMENDATION FACTORY
  // ===========================================================================

  private createRecommendation(input: {
    type: RecommendationType;
    code: string;
    text: string;
    reason: string;
    urgency: RecommendationUrgency;
    confidence?: RecommendationConfidence;

    knowledgeCode?: string | null;
    knowledgeVersion?: string | null;

    provenance?: string[];

    requiresConfirmation?: boolean;

    safetyBlocked?: boolean;
    safetyReason?: string | null;

    indication?: string | null;
  }): EngineRecommendation {

    const priority =
      (URGENCY_ORDER[input.urgency] ?? 3) * -1000 +
      (TYPE_PRIORITY[input.type] ?? 0);


    return {
      type: input.type,
      code: input.code,
      text: input.text,
      reason: input.reason,
      urgency: input.urgency,

      priority,

      confidence:
        input.confidence ?? 'unknown',

      knowledgeCode:
        input.knowledgeCode ?? null,

      knowledgeVersion:
        input.knowledgeVersion ?? null,

      provenance:
        input.provenance ?? [],

      requiresConfirmation:
        input.requiresConfirmation ?? true,

      safetyBlocked:
        input.safetyBlocked ?? false,

      safetyReason:
        input.safetyReason ?? null,

      indication:
        input.indication ?? null,
    };
  }


  // ===========================================================================
  // DEDUPLICATION
  // ===========================================================================

  private deduplicate(
    recommendations: EngineRecommendation[],
  ): EngineRecommendation[] {

    const map =
      new Map<string, EngineRecommendation>();


    for (const recommendation of recommendations) {

      const key = [
        recommendation.type,
        recommendation.code,
      ]
        .map((part) => String(part).trim().toUpperCase())
        .join(':');


      const existing = map.get(key);

      if (!existing) {
        map.set(key, recommendation);
        continue;
      }


      // Preserve the stronger urgency.
      const existingUrgency =
        getUrgencyOrder(existing.urgency);

      const incomingUrgency =
        getUrgencyOrder(recommendation.urgency);


      if (incomingUrgency < existingUrgency) {
        map.set(key, {
          ...recommendation,
          provenance: mergeUnique(
            existing.provenance,
            recommendation.provenance,
          ),
        });

        continue;
      }


      // Preserve the richer provenance/reasoning from both engines.
      map.set(key, {
        ...existing,

        provenance: mergeUnique(
          existing.provenance,
          recommendation.provenance,
        ),

        knowledgeCode:
          existing.knowledgeCode ??
          recommendation.knowledgeCode,

        knowledgeVersion:
          existing.knowledgeVersion ??
          recommendation.knowledgeVersion,

        indication:
          existing.indication ??
          recommendation.indication,

        safetyBlocked:
          existing.safetyBlocked ||
          recommendation.safetyBlocked,

        safetyReason:
          existing.safetyReason ??
          recommendation.safetyReason,

        requiresConfirmation:
          existing.requiresConfirmation ||
          recommendation.requiresConfirmation,
      });
    }


    return [...map.values()];
  }
}


// =============================================================================
// SORTING
// =============================================================================
//
// The ordering is deliberately deterministic.
//
// 1. Urgency
// 2. Clinical action class
// 3. Priority
// 4. Stable code
//
// This means the UI will not randomly reorder recommendations between renders.
//
// =============================================================================

function compareRecommendations(
  a: EngineRecommendation,
  b: EngineRecommendation,
): number {

  const urgencyA =
    getUrgencyOrder(a.urgency);

  const urgencyB =
    getUrgencyOrder(b.urgency);

  if (urgencyA !== urgencyB) {
    return urgencyA - urgencyB;
  }


  const typeA =
    getTypePriority(a.type);

  const typeB =
    getTypePriority(b.type);

  if (typeA !== typeB) {
    return typeB - typeA;
  }


  const priorityA =
    a.priority ?? 0;

  const priorityB =
    b.priority ?? 0;

  if (priorityA !== priorityB) {
    return priorityB - priorityA;
  }


  return String(a.code)
    .localeCompare(String(b.code));
}


// =============================================================================
// DECISION STATUS NORMALIZATION
// =============================================================================

function normalizeDecisionStatus(
  value: unknown,
): DecisionStatus | null {

  const status =
    normalizeString(value)?.toLowerCase();

  if (
    status === 'accepted' ||
    status === 'modified' ||
    status === 'dismissed'
  ) {
    return status;
  }

  return null;
}


// =============================================================================
// URGENCY NORMALIZATION
// =============================================================================

function normalizeUrgency(
  value: unknown,
): RecommendationUrgency {

  const urgency =
    normalizeString(value)?.toLowerCase();

  if (
    urgency === 'immediate' ||
    urgency === 'urgent' ||
    urgency === 'routine' ||
    urgency === 'info'
  ) {
    return urgency;
  }

  // Unknown severity must never silently become "immediate".
  return 'routine';
}


// =============================================================================
// CONFIDENCE FROM INVESTIGATION WEIGHT
// =============================================================================
//
// This is NOT diagnostic probability.
//
// It merely expresses how strongly the originating engine prioritized the
// candidate.
//
// A future Bayesian/clinical-evidence layer should remain separate from this.
// =============================================================================

function confidenceFromWeight(
  weight: number,
): RecommendationConfidence {

  if (!Number.isFinite(weight)) {
    return 'unknown';
  }

  if (weight >= 80) {
    return 'high';
  }

  if (weight >= 50) {
    return 'moderate';
  }

  if (weight > 0) {
    return 'low';
  }

  return 'unknown';
}


// =============================================================================
// STRING NORMALIZATION
// =============================================================================

function normalizeString(
  value: unknown,
): string | null {

  if (typeof value !== 'string') {
    return null;
  }

  const normalized =
    value.trim();

  return normalized.length > 0
    ? normalized
    : null;
}


function cleanText(
  value: string,
): string {

  return value
    .replace(/\s+/g, ' ')
    .trim();
}


// =============================================================================
// EVENT PAYLOAD NORMALIZATION
// =============================================================================

function asRecord(
  value: unknown,
): Record<string, unknown> {

  if (
    value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value)
  ) {
    return value as Record<string, unknown>;
  }

  return {};
}


// =============================================================================
// ARRAY HELPERS
// =============================================================================

function mergeUnique(
  a: string[] = [],
  b: string[] = [],
): string[] {

  return [
    ...new Set(
      [...a, ...b]
        .map(cleanText)
        .filter(Boolean),
    ),
  ];
}


// =============================================================================
// CLINICIAN DECISION EVENT IDENTIFICATION
// =============================================================================

export function isClinicianDecision(
  event: ClinicalEvent,
): boolean {

  return event.type === 'CLINICIAN_DECISION';
}