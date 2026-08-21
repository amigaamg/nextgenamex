// =============================================================================
// AMEXAN Clinical CPU — MonitoringEngine
//
// PURPOSE
// -----------------------------------------------------------------------------
// Converts protocol monitoring requirements into actionable clinical state.
//
// The engine implements:
//
//   protocol
//      ↓
//   monitoring targets
//      ↓
//   latest observations
//      ↓
//   baseline / previous / current
//      ↓
//   trend analysis
//      ↓
//   threshold evaluation
//      ↓
//   deterioration-rule evaluation
//      ↓
//   escalation / alert
//
// DESIGN PRINCIPLES
// -----------------------------------------------------------------------------
// 1. The CPU does not hard-code disease-specific monitoring protocols.
//    Protocols and targets live in PostgreSQL.
//
// 2. Missing data is NOT interpreted as normal.
//
// 3. A single abnormal value and a deteriorating trend are different signals.
//
// 4. Critical thresholds override ordinary target thresholds.
//
// 5. Monitoring rules may express:
//      - lower threshold
//      - upper threshold
//      - critical lower threshold
//      - critical upper threshold
//      - absolute change
//      - percentage change
//      - directional deterioration
//      - persistence
//
// 6. The engine is intentionally explainable.
//    Every alert carries enough information for the UI / audit layer to answer:
//      "Why was this patient flagged?"
//
// 7. The engine does not diagnose.
//    It evaluates measurements against monitoring requirements.
//
// 8. Clinical facts remain the universal substrate.
//    Vitals, laboratory results, device measurements and manually entered
//    observations can therefore participate in the same monitoring engine.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type { Fact, MonitoringTarget } from '../types.js';

// =============================================================================
// DATABASE TYPES
// =============================================================================

interface ProtocolMonitoringRow extends Row {
  protocol_code: string;

  monitoring_code: string;
  canonical_name: string;
  target_type: string;

  unit: string | null;

  // Ordinary target range.
  normal_low: number | null;
  normal_high: number | null;

  // Optional urgent / critical boundaries.
  critical_low: number | null;
  critical_high: number | null;

  // How frequently this target should be measured.
  frequency: string | null;

  // Optional machine-readable deterioration rule.
  //
  // Examples:
  //   "decrease"
  //   "increase"
  //   "change_gt:2"
  //   "change_lt:-2"
  //   "percent_change_gt:20"
  //   "percent_change_lt:-20"
  //   "decrease_gt:2"
  //   "increase_gt:20"
  //
  deterioration_rule: string | null;

  escalation_instruction: string | null;

  // Optional severity configured by protocol.
  escalation_level: string | null;

  // Optional persistence requirement.
  //
  // Example:
  //   2 = abnormal on two consecutive observations.
  //
  persistence_count: number | null;

  // Optional unit conversion / measurement metadata.
  measurement_code: string | null;
}

interface FactValueRow extends Row {
  fact_id: string;
  observed_at: string;
  recorded_at: string | null;

  fact_definition_code: string;

  value_text: string | null;
  value_numeric: number | null;
  value_boolean: boolean | null;

  unit_code: string | null;
}

interface MonitoringObservation {
  value: number;
  unit: string | null;
  observedAt: string;
  factId: string;
}

interface MonitoringAssessment {
  currentValue: number | null;
  previousValue: number | null;
  baselineValue: number | null;

  currentUnit: string | null;

  observedAt: string | null;

  change: number | null;
  percentChange: number | null;

  trend: MonitoringTrend;

  status: MonitoringStatus;

  severity: MonitoringSeverity | null;

  reason: string | null;

  thresholdBreached: boolean;

  critical: boolean;

  stale: boolean;

  missing: boolean;

  persistenceSatisfied: boolean;
}

type MonitoringTrend =
  | 'IMPROVING'
  | 'DETERIORATING'
  | 'STABLE'
  | 'UNKNOWN';

type MonitoringStatus =
  | 'NORMAL'
  | 'ABNORMAL'
  | 'CRITICAL'
  | 'MISSING'
  | 'STALE';

type MonitoringSeverity =
  | 'INFO'
  | 'WARNING'
  | 'URGENT'
  | 'CRITICAL';

// =============================================================================
// INTERNAL REPRESENTATION
// =============================================================================

interface TargetEvaluation {
  row: ProtocolMonitoringRow;

  observations: MonitoringObservation[];

  current: MonitoringObservation | null;
  previous: MonitoringObservation | null;
  baseline: MonitoringObservation | null;

  assessment: MonitoringAssessment;
}

// =============================================================================
// ENGINE
// =============================================================================

export class MonitoringEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================
  //
  // Resolve protocol monitoring requirements against the patient's facts.
  //
  // IMPORTANT:
  // `facts` should normally contain the patient's current clinical fact set.
  //
  // The engine does not assume that absence of a fact means normality.
  //
  async resolve(
    protocolCode: string | null,
    facts: Fact[],
  ): Promise<MonitoringTarget[]> {
    if (!protocolCode) return [];

    const rows = await this.db.query<ProtocolMonitoringRow>(
      `
      SELECT
          p.protocol_code,

          m.monitoring_code,
          m.canonical_name,
          m.target_type,
          m.unit,

          m.normal_low,
          m.normal_high,

          m.critical_low,
          m.critical_high,

          pm.frequency,
          pm.deterioration_rule,
          pm.escalation_instruction,

          pm.escalation_level,
          pm.persistence_count,

          m.measurement_code

      FROM knowledge.protocol_monitoring pm

      JOIN knowledge.protocol p
        ON p.id = pm.protocol_id

      JOIN knowledge.monitoring m
        ON m.id = pm.monitoring_id

      WHERE p.protocol_code = $1

      ORDER BY
          m.target_type,
          m.monitoring_code
      `,
      [protocolCode],
    );

    if (rows.length === 0) return [];

    const evaluations = rows.map((row) =>
      this.evaluateTarget(row, facts),
    );

    return evaluations.map((evaluation) =>
      this.toMonitoringTarget(evaluation),
    );
  }

  // ===========================================================================
  // TARGET EVALUATION
  // ===========================================================================

  private evaluateTarget(
    row: ProtocolMonitoringRow,
    facts: Fact[],
  ): TargetEvaluation {
    const observations = this.extractObservations(
      facts,
      row.monitoring_code,
      row.measurement_code,
    );

    const current = observations[0] ?? null;
    const previous = observations[1] ?? null;

    const baseline =
      observations.length > 0
        ? observations[observations.length - 1]
        : null;

    const assessment = this.assess(
      row,
      current,
      previous,
      baseline,
      observations,
    );

    return {
      row,
      observations,
      current,
      previous,
      baseline,
      assessment,
    };
  }

  // ===========================================================================
  // FACT EXTRACTION
  // ===========================================================================
  //
  // Fact arrays can contain:
  //
  //   HR
  //   RESPIRATORY_RATE
  //   SPO2
  //   TEMPERATURE
  //   BP_SYSTOLIC
  //   BP_DIASTOLIC
  //   URINE_OUTPUT_RATE
  //   GLUCOSE
  //   etc.
  //
  // We intentionally support both:
  //
  //   fact.factCode === monitoringCode
  //
  // and:
  //
  //   fact.factCode === measurementCode
  //
  // because knowledge terminology may distinguish a monitoring target from
  // the underlying universal measurement fact.
  //
  private extractObservations(
    facts: Fact[],
    monitoringCode: string,
    measurementCode: string | null,
  ): MonitoringObservation[] {
    const matchingFacts = facts.filter((fact) => {
      if (fact.factCode === monitoringCode) return true;

      if (
        measurementCode != null &&
        fact.factCode === measurementCode
      ) {
        return true;
      }

      return false;
    });

    const observations: MonitoringObservation[] = [];

    for (const fact of matchingFacts) {
      const observedAt =
        extractObservedAt(fact) ??
        extractRecordedAt(fact) ??
        new Date(0).toISOString();

      for (const value of fact.values ?? []) {
        if (value.numeric == null) continue;

        if (!Number.isFinite(Number(value.numeric))) continue;

        observations.push({
          value: Number(value.numeric),
          unit: value.unitCode ?? null,
          observedAt,
          factId: String(fact.id ?? ''),
        });
      }
    }

    return observations.sort(
      (a, b) =>
        new Date(b.observedAt).getTime() -
        new Date(a.observedAt).getTime(),
    );
  }

  // ===========================================================================
  // CLINICAL ASSESSMENT
  // ===========================================================================

  private assess(
    row: ProtocolMonitoringRow,
    current: MonitoringObservation | null,
    previous: MonitoringObservation | null,
    baseline: MonitoringObservation | null,
    observations: MonitoringObservation[],
  ): MonitoringAssessment {
    // -------------------------------------------------------------------------
    // NO DATA
    // -------------------------------------------------------------------------

    if (!current) {
      return {
        currentValue: null,
        previousValue: previous?.value ?? null,
        baselineValue: baseline?.value ?? null,

        currentUnit: row.unit,

        observedAt: null,

        change: null,
        percentChange: null,

        trend: 'UNKNOWN',

        status: 'MISSING',

        severity: null,

        reason: null,

        thresholdBreached: false,

        critical: false,

        stale: false,

        missing: true,

        persistenceSatisfied: false,
      };
    }

    // -------------------------------------------------------------------------
    // CHANGE
    // -------------------------------------------------------------------------

    const change =
      previous != null
        ? round(current.value - previous.value)
        : null;

    const percentChange =
      previous != null && previous.value !== 0
        ? round(
            ((current.value - previous.value) /
              Math.abs(previous.value)) *
              100,
          )
        : null;

    // -------------------------------------------------------------------------
    // TREND
    // -------------------------------------------------------------------------

    const trend = this.determineTrend(
      row,
      current,
      previous,
      change,
      percentChange,
    );

    // -------------------------------------------------------------------------
    // CRITICAL THRESHOLDS
    // -------------------------------------------------------------------------

    if (
      row.critical_low != null &&
      current.value < row.critical_low
    ) {
      return {
        currentValue: current.value,
        previousValue: previous?.value ?? null,
        baselineValue: baseline?.value ?? null,

        currentUnit: current.unit ?? row.unit,

        observedAt: current.observedAt,

        change,
        percentChange,

        trend,

        status: 'CRITICAL',

        severity: 'CRITICAL',

        reason:
          `${row.canonical_name} is critically low: ` +
          `${formatNumber(current.value)} ` +
          `${formatUnit(current.unit ?? row.unit)} ` +
          `(critical threshold < ${formatNumber(row.critical_low)})`,

        thresholdBreached: true,

        critical: true,

        stale: false,

        missing: false,

        persistenceSatisfied: this.persistenceSatisfied(
          row,
          observations,
        ),
      };
    }

    if (
      row.critical_high != null &&
      current.value > row.critical_high
    ) {
      return {
        currentValue: current.value,
        previousValue: previous?.value ?? null,
        baselineValue: baseline?.value ?? null,

        currentUnit: current.unit ?? row.unit,

        observedAt: current.observedAt,

        change,
        percentChange,

        trend,

        status: 'CRITICAL',

        severity: 'CRITICAL',

        reason:
          `${row.canonical_name} is critically high: ` +
          `${formatNumber(current.value)} ` +
          `${formatUnit(current.unit ?? row.unit)} ` +
          `(critical threshold > ${formatNumber(row.critical_high)})`,

        thresholdBreached: true,

        critical: true,

        stale: false,

        missing: false,

        persistenceSatisfied: this.persistenceSatisfied(
          row,
          observations,
        ),
      };
    }

    // -------------------------------------------------------------------------
    // ORDINARY TARGET RANGE
    // -------------------------------------------------------------------------

    const belowTarget =
      row.normal_low != null &&
      current.value < row.normal_low;

    const aboveTarget =
      row.normal_high != null &&
      current.value > row.normal_high;

    if (belowTarget || aboveTarget) {
      const reason = belowTarget
        ? `${row.canonical_name} is below target: ` +
          `${formatNumber(current.value)} ` +
          `${formatUnit(current.unit ?? row.unit)} ` +
          `(target ≥ ${formatNumber(row.normal_low!)})`
        : `${row.canonical_name} is above target: ` +
          `${formatNumber(current.value)} ` +
          `${formatUnit(current.unit ?? row.unit)} ` +
          `(target ≤ ${formatNumber(row.normal_high!)})`;

      return {
        currentValue: current.value,
        previousValue: previous?.value ?? null,
        baselineValue: baseline?.value ?? null,

        currentUnit: current.unit ?? row.unit,

        observedAt: current.observedAt,

        change,
        percentChange,

        trend,

        status: 'ABNORMAL',

        severity: this.resolveSeverity(
          row,
          'ABNORMAL',
        ),

        reason,

        thresholdBreached: true,

        critical: false,

        stale: false,

        missing: false,

        persistenceSatisfied: this.persistenceSatisfied(
          row,
          observations,
        ),
      };
    }

    // -------------------------------------------------------------------------
    // DETERIORATION RULE
    // -------------------------------------------------------------------------

    const deterioration = evaluateDeteriorationRule(
      row.deterioration_rule,
      current,
      previous,
      change,
      percentChange,
    );

    if (deterioration.triggered) {
      return {
        currentValue: current.value,
        previousValue: previous?.value ?? null,
        baselineValue: baseline?.value ?? null,

        currentUnit: current.unit ?? row.unit,

        observedAt: current.observedAt,

        change,
        percentChange,

        trend: 'DETERIORATING',

        status: 'ABNORMAL',

        severity: this.resolveSeverity(
          row,
          'DETERIORATING',
        ),

        reason:
          deterioration.reason ??
          `${row.canonical_name} demonstrates deterioration`,

        thresholdBreached: true,

        critical: false,

        stale: false,

        missing: false,

        persistenceSatisfied: this.persistenceSatisfied(
          row,
          observations,
        ),
      };
    }

    // -------------------------------------------------------------------------
    // NORMAL
    // -------------------------------------------------------------------------

    return {
      currentValue: current.value,
      previousValue: previous?.value ?? null,
      baselineValue: baseline?.value ?? null,

      currentUnit: current.unit ?? row.unit,

      observedAt: current.observedAt,

      change,
      percentChange,

      trend,

      status: 'NORMAL',

      severity: null,

      reason: null,

      thresholdBreached: false,

      critical: false,

      stale: false,

      missing: false,

      persistenceSatisfied: true,
    };
  }

  // ===========================================================================
  // TREND ENGINE
  // ===========================================================================

  private determineTrend(
    row: ProtocolMonitoringRow,
    current: MonitoringObservation,
    previous: MonitoringObservation | null,
    change: number | null,
    percentChange: number | null,
  ): MonitoringTrend {
    if (!previous || change == null) {
      return 'UNKNOWN';
    }

    const rule = row.deterioration_rule?.trim().toLowerCase();

    // -------------------------------------------------------------------------
    // Direction-sensitive clinical interpretation.
    //
    // Example:
    //
    // SpO2:
    //   decrease = deterioration
    //
    // Temperature:
    //   increase may be deterioration
    //
    // HR:
    //   direction depends on protocol and context.
    //
    // Therefore the database rule determines which direction matters.
    // -------------------------------------------------------------------------

    if (rule) {
      if (
        rule.includes('decrease') &&
        change < 0
      ) {
        return 'DETERIORATING';
      }

      if (
        rule.includes('increase') &&
        change > 0
      ) {
        return 'DETERIORATING';
      }

      if (
        rule.includes('percent_change_lt') &&
        percentChange != null &&
        percentChange < 0
      ) {
        return 'DETERIORATING';
      }

      if (
        rule.includes('percent_change_gt') &&
        percentChange != null &&
        percentChange > 0
      ) {
        return 'DETERIORATING';
      }
    }

    // If a protocol defines an explicit direction, respect it.
    if (
      rule?.startsWith('decrease') &&
      change < 0
    ) {
      return 'DETERIORATING';
    }

    if (
      rule?.startsWith('increase') &&
      change > 0
    ) {
      return 'DETERIORATING';
    }

    // Otherwise, a clinically small change is treated as stable.
    //
    // The threshold is intentionally conservative and is NOT itself an alert.
    // Actual alerting is controlled by the protocol.
    const magnitude = Math.abs(change);

    if (magnitude < 0.001) {
      return 'STABLE';
    }

    return 'STABLE';
  }

  // ===========================================================================
  // PERSISTENCE
  // ===========================================================================

  private persistenceSatisfied(
    row: ProtocolMonitoringRow,
    observations: MonitoringObservation[],
  ): boolean {
    const required = row.persistence_count ?? 1;

    if (required <= 1) return observations.length > 0;

    if (observations.length < required) return false;

    const relevant = observations.slice(0, required);

    return relevant.every((observation) =>
      this.observationAbnormal(row, observation),
    );
  }

  private observationAbnormal(
    row: ProtocolMonitoringRow,
    observation: MonitoringObservation,
  ): boolean {
    if (
      row.critical_low != null &&
      observation.value < row.critical_low
    ) {
      return true;
    }

    if (
      row.critical_high != null &&
      observation.value > row.critical_high
    ) {
      return true;
    }

    if (
      row.normal_low != null &&
      observation.value < row.normal_low
    ) {
      return true;
    }

    if (
      row.normal_high != null &&
      observation.value > row.normal_high
    ) {
      return true;
    }

    return false;
  }

  // ===========================================================================
  // ESCALATION
  // ===========================================================================

  private resolveSeverity(
    row: ProtocolMonitoringRow,
    situation: 'ABNORMAL' | 'DETERIORATING',
  ): MonitoringSeverity {
    const configured = normalizeSeverity(
      row.escalation_level,
    );

    if (configured) return configured;

    if (situation === 'DETERIORATING') {
      return 'URGENT';
    }

    return 'WARNING';
  }

  // ===========================================================================
  // OUTPUT PROJECTION
  // ===========================================================================

  private toMonitoringTarget(
    evaluation: TargetEvaluation,
  ): MonitoringTarget {
    const {
      row,
      current,
      previous,
      baseline,
      assessment,
    } = evaluation;

    /*
     * Keep the public MonitoringTarget compatible with the existing AMEXAN
     * contract while enriching it with optional metadata.
     *
     * TypeScript structural typing allows these additional properties when the
     * target interface has been expanded. If the existing interface is strict,
     * the extra projection can be moved into a dedicated MonitoringAssessment
     * type in ../types.ts.
     */

    return {
      monitoringCode: row.monitoring_code,

      name: row.canonical_name,

      targetType: row.target_type,

      unit: row.unit,

      frequency: row.frequency,

      deteriorationRule: row.deterioration_rule,

      escalationInstruction: row.escalation_instruction,

      currentValue:
        current != null
          ? String(current.value)
          : null,

      alert:
        assessment.reason,

      // -----------------------------------------------------------------------
      // Extended AMEXAN clinical intelligence projection.
      // -----------------------------------------------------------------------

      ...(assessment as unknown as Record<string, unknown>),

      previousValue:
        previous != null
          ? previous.value
          : null,

      baselineValue:
        baseline != null
          ? baseline.value
          : null,

      change:
        assessment.change,

      percentChange:
        assessment.percentChange,

      trend:
        assessment.trend,

      status:
        assessment.status,

      severity:
        assessment.severity,

      reason:
        assessment.reason,

      critical:
        assessment.critical,

      thresholdBreached:
        assessment.thresholdBreached,

      missing:
        assessment.missing,

      stale:
        assessment.stale,

      observedAt:
        assessment.observedAt,

      persistenceSatisfied:
        assessment.persistenceSatisfied,
    } as MonitoringTarget;
  }

  // ===========================================================================
  // OPTIONAL DATABASE-BACKED OBSERVATION LOADER
  // ===========================================================================
  //
  // Useful when the CPU has not loaded a complete Fact[] snapshot.
  //
  // This method intentionally does NOT replace resolve().
  //
  // It provides a second path for monitoring services, dashboards and
  // background surveillance workers.
  //
  async loadRecentObservations(
    patientId: string,
    monitoringCode: string,
    measurementCode: string | null = null,
    limit = 20,
  ): Promise<MonitoringObservation[]> {
    const codes = [
      monitoringCode,
      ...(measurementCode ? [measurementCode] : []),
    ];

    const rows = await this.db.query<FactValueRow>(
      `
      SELECT
          f.id AS fact_id,
          f.observed_at::text AS observed_at,
          f.recorded_at::text AS recorded_at,
          f.fact_definition_code,

          fv.value_text,
          fv.value_numeric,
          fv.value_boolean,

          fv.unit_code

      FROM clinical.fact f

      JOIN clinical.fact_value fv
        ON fv.fact_id = f.id

      WHERE f.patient_id = $1

        AND f.fact_definition_code = ANY($2::text[])

        AND f.status_code <> 'retracted'

        AND fv.value_numeric IS NOT NULL

      ORDER BY
          f.observed_at DESC,
          f.recorded_at DESC,
          fv.value_order ASC

      LIMIT $3
      `,
      [patientId, codes, limit],
    );

    return rows
      .filter(
        (row) =>
          row.value_numeric != null &&
          Number.isFinite(Number(row.value_numeric)),
      )
      .map((row) => ({
        value: Number(row.value_numeric),
        unit: row.unit_code,
        observedAt:
          row.observed_at ??
          row.recorded_at ??
          new Date(0).toISOString(),
        factId: row.fact_id,
      }));
  }
}

// =============================================================================
// DETERIORATION RULE ENGINE
// =============================================================================

interface DeteriorationResult {
  triggered: boolean;
  reason: string | null;
}

function evaluateDeteriorationRule(
  rule: string | null,
  current: MonitoringObservation,
  previous: MonitoringObservation | null,
  change: number | null,
  percentChange: number | null,
): DeteriorationResult {
  if (!rule || !previous || change == null) {
    return {
      triggered: false,
      reason: null,
    };
  }

  const expression = rule.trim().toLowerCase();

  // ---------------------------------------------------------------------------
  // Simple directional rules
  // ---------------------------------------------------------------------------

  if (expression === 'decrease') {
    if (change < 0) {
      return {
        triggered: true,
        reason:
          `Value decreased from ${previous.value} to ${current.value}`,
      };
    }

    return { triggered: false, reason: null };
  }

  if (expression === 'increase') {
    if (change > 0) {
      return {
        triggered: true,
        reason:
          `Value increased from ${previous.value} to ${current.value}`,
      };
    }

    return { triggered: false, reason: null };
  }

  // ---------------------------------------------------------------------------
  // Absolute decrease
  //
  // decrease_gt:2
  // ---------------------------------------------------------------------------

  const decreaseGt = expression.match(
    /^decrease_gt:([-+]?\d+(?:\.\d+)?)$/,
  );

  if (decreaseGt) {
    const threshold = Number(decreaseGt[1]);

    if (
      Number.isFinite(threshold) &&
      change < -threshold
    ) {
      return {
        triggered: true,
        reason:
          `Value decreased by ${formatNumber(Math.abs(change))}, ` +
          `exceeding deterioration threshold ${formatNumber(threshold)}`,
      };
    }

    return { triggered: false, reason: null };
  }

  // ---------------------------------------------------------------------------
  // Absolute increase
  //
  // increase_gt:20
  // ---------------------------------------------------------------------------

  const increaseGt = expression.match(
    /^increase_gt:([-+]?\d+(?:\.\d+)?)$/,
  );

  if (increaseGt) {
    const threshold = Number(increaseGt[1]);

    if (
      Number.isFinite(threshold) &&
      change > threshold
    ) {
      return {
        triggered: true,
        reason:
          `Value increased by ${formatNumber(change)}, ` +
          `exceeding deterioration threshold ${formatNumber(threshold)}`,
      };
    }

    return { triggered: false, reason: null };
  }

  // ---------------------------------------------------------------------------
  // Generic absolute change
  //
  // change_gt:10
  // ---------------------------------------------------------------------------

  const changeGt = expression.match(
    /^change_gt:([-+]?\d+(?:\.\d+)?)$/,
  );

  if (changeGt) {
    const threshold = Number(changeGt[1]);

    if (
      Number.isFinite(threshold) &&
      Math.abs(change) > threshold
    ) {
      return {
        triggered: true,
        reason:
          `Absolute change of ${formatNumber(Math.abs(change))} ` +
          `exceeds threshold ${formatNumber(threshold)}`,
      };
    }

    return { triggered: false, reason: null };
  }

  // ---------------------------------------------------------------------------
  // Percentage increase
  //
  // percent_change_gt:20
  // ---------------------------------------------------------------------------

  const percentGt = expression.match(
    /^percent_change_gt:([-+]?\d+(?:\.\d+)?)$/,
  );

  if (percentGt && percentChange != null) {
    const threshold = Number(percentGt[1]);

    if (
      Number.isFinite(threshold) &&
      percentChange > threshold
    ) {
      return {
        triggered: true,
        reason:
          `Value increased by ${formatNumber(Math.abs(percentChange))}% ` +
          `from baseline`,
      };
    }

    return { triggered: false, reason: null };
  }

  // ---------------------------------------------------------------------------
  // Percentage decrease
  //
  // percent_change_lt:-20
  // ---------------------------------------------------------------------------

  const percentLt = expression.match(
    /^percent_change_lt:([-+]?\d+(?:\.\d+)?)$/,
  );

  if (percentLt && percentChange != null) {
    const threshold = Number(percentLt[1]);

    if (
      Number.isFinite(threshold) &&
      percentChange < threshold
    ) {
      return {
        triggered: true,
        reason:
          `Value decreased by ${formatNumber(Math.abs(percentChange))}% ` +
          `from previous measurement`,
      };
    }

    return { triggered: false, reason: null };
  }

  // ---------------------------------------------------------------------------
  // Direct signed change comparison
  //
  // change_lt:-2
  // change_gt:2
  // ---------------------------------------------------------------------------

  const changeLt = expression.match(
    /^change_lt:([-+]?\d+(?:\.\d+)?)$/,
  );

  if (changeLt) {
    const threshold = Number(changeLt[1]);

    if (
      Number.isFinite(threshold) &&
      change < threshold
    ) {
      return {
        triggered: true,
        reason:
          `Change ${formatNumber(change)} is below configured threshold ` +
          `${formatNumber(threshold)}`,
      };
    }

    return { triggered: false, reason: null };
  }

  // Unknown rule:
  //
  // IMPORTANT:
  // Do not guess at clinical meaning.
  //
  // Fail closed rather than turning an unknown configuration into an alert.
  return {
    triggered: false,
    reason: null,
  };
}

// =============================================================================
// SEVERITY NORMALIZATION
// =============================================================================

function normalizeSeverity(
  value: string | null | undefined,
): MonitoringSeverity | null {
  if (!value) return null;

  switch (value.trim().toUpperCase()) {
    case 'INFO':
    case 'INFORMATION':
      return 'INFO';

    case 'WARNING':
    case 'WARN':
      return 'WARNING';

    case 'URGENT':
      return 'URGENT';

    case 'CRITICAL':
    case 'EMERGENCY':
      return 'CRITICAL';

    default:
      return null;
  }
}

// =============================================================================
// FORMATTING
// =============================================================================

function round(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function formatNumber(value: number): string {
  if (!Number.isFinite(value)) return 'unknown';

  return Number.isInteger(value)
    ? String(value)
    : value.toFixed(2).replace(/\.?0+$/, '');
}

function formatUnit(unit: string | null): string {
  return unit ? ` ${unit}` : '';
}

// =============================================================================
// FACT TIMESTAMP EXTRACTION
// =============================================================================
//
// Fact implementations may evolve. These helpers intentionally tolerate
// slightly different Fact shapes without making the monitoring engine depend
// on one UI representation.
//
// =============================================================================

function getRecord(
  value: unknown,
): Record<string, unknown> | null {
  if (
    value != null &&
    typeof value === 'object'
  ) {
    return value as Record<string, unknown>;
  }

  return null;
}

function extractTimestamp(
  fact: Fact,
  keys: string[],
): string | null {
  const record = getRecord(fact);

  if (!record) return null;

  for (const key of keys) {
    const value = record[key];

    if (typeof value !== 'string') continue;

    const timestamp = new Date(value);

    if (!Number.isNaN(timestamp.getTime())) {
      return timestamp.toISOString();
    }
  }

  return null;
}

function extractObservedAt(
  fact: Fact,
): string | null {
  return extractTimestamp(
    fact,
    [
      'observedAt',
      'observed_at',
      'observationTime',
      'observation_time',
    ],
  );
}

function extractRecordedAt(
  fact: Fact,
): string | null {
  return extractTimestamp(
    fact,
    [
      'recordedAt',
      'recorded_at',
      'createdAt',
      'created_at',
    ],
  );
}