// =============================================================================
// src/components/Examination/ExamSummaryStrip.tsx
// A compact "already recorded" strip showing the key vitals & anthropometrics
// with their age-normal deductions, so the clinician never scrolls to confirm
// what has been captured.
// =============================================================================

import type { ClinicalContext } from '../../clinical/types';
import {
  deduceBloodPressure,
  deduceBmi,
  deduceHeadCircumference,
  deduceHeight,
  deduceHeartRate,
  deduceMuac,
  deduceRespiratoryRate,
  deduceSpo2,
  deduceTemperature,
  deduceUrineOutput,
  deduceWeight,
} from '../../clinical/exam/norms';

interface ExamSummaryStripProps {
  context: ClinicalContext;
  capturedValues: Record<string, unknown>;
}

function numeric(value: unknown): number | null {
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value !== '') {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function pillClass(status: string): string {
  switch (status) {
    case 'normal':
      return 'sum-pill good';
    case 'low':
      return 'sum-pill warn';
    case 'high':
      return 'sum-pill bad';
    default:
      return 'sum-pill muted';
  }
}

export function ExamSummaryStrip({
  context,
  capturedValues,
}: ExamSummaryStripProps) {
  const age = {
    ageYears: context.ageYears,
    ageMonths: context.ageMonths,
    ageDays: context.ageDays,
  };

  const sbp = numeric(capturedValues['EXAM_VITALS_SBP']);
  const dbp = numeric(capturedValues['EXAM_VITALS_DBP']);
  const hr = numeric(capturedValues['EXAM_VITALS_HR']);
  const rr = numeric(capturedValues['EXAM_VITALS_RR']);
  const spo2 = numeric(capturedValues['EXAM_VITALS_SPO2']);
  const temp = numeric(capturedValues['EXAM_VITALS_TEMP']);
  const weight = numeric(capturedValues['EXAM_ANTHRO_WEIGHT']);
  const height = numeric(capturedValues['EXAM_ANTHRO_HEIGHT']);
  const hc = numeric(capturedValues['EXAM_ANTHRO_HEAD_CIRC']);
  const muac = numeric(capturedValues['EXAM_ANTHRO_MUAC']);
  const bmi = numeric(capturedValues['EXAM_ANTHRO_BMI']);

  const urineVolume = numeric(capturedValues['EXAM_GEN_URINE_VOLUME']);
  const urineDuration = numeric(capturedValues['EXAM_GEN_URINE_DURATION']);

  const items: { label: string; value: string; className: string; deduction: string }[] = [];

  const add = (
    label: string,
    value: string,
    status: string,
    deduction: string,
  ) => {
    items.push({ label, value, className: pillClass(status), deduction });
  };

  if (temp != null) {
    const d = deduceTemperature(temp);
    add('Temp', `${temp} °C`, d.status, d.label);
  }
  if (hr != null) {
    const d = deduceHeartRate(hr, age);
    add('HR', `${hr} bpm`, d.status, d.label);
  }
  if (rr != null) {
    const d = deduceRespiratoryRate(rr, age);
    add('RR', `${rr}/min`, d.status, d.label);
  }
  if (sbp != null || dbp != null) {
    const d = deduceBloodPressure(sbp, dbp, age);
    const display = `${sbp ?? '–'}/${dbp ?? '–'}`;
    add('BP', `${display} mmHg`, d.status, d.label);
  }
  if (spo2 != null) {
    const d = deduceSpo2(spo2, age);
    add('SpO₂', `${spo2}%`, d.status, d.label);
  }
  if (weight != null) {
    const d = deduceWeight(weight, age);
    add('Wt', `${weight} kg`, d.status, d.label);
  }
  if (height != null) {
    const d = deduceHeight(height, age);
    add('Ht', `${height} cm`, d.status, d.label);
  }
  if (hc != null) {
    const d = deduceHeadCircumference(hc, age);
    add('HC', `${hc} cm`, d.status, d.label);
  }
  if (muac != null) {
    const d = deduceMuac(muac, age);
    add('MUAC', `${muac} cm`, d.status, d.label);
  }
  if (bmi != null) {
    const d = deduceBmi(bmi, age);
    add('BMI', `${bmi}`, d.status, d.label);
  }

  if (urineVolume != null && urineDuration != null) {
    const d = deduceUrineOutput(urineVolume, urineDuration, weight, age);
    const rate = (urineVolume / urineDuration).toFixed(1);
    add('Urine', `${rate} mL/hr`, d.status, d.label);
  }

  if (items.length === 0) {
    return (
      <div className="exam-summary-strip empty">
        <span className="text-xs text-muted">
          Record anthropometry and vital signs — deductions appear here live.
        </span>
      </div>
    );
  }

  return (
    <div className="exam-summary-strip">
      {items.map((item) => (
        <div key={item.label} className={item.className}>
          <span className="sum-value">
            {item.value}
          </span>
          <span className="sum-label">{item.label}</span>
          <span className="sum-deduction">{item.deduction}</span>
        </div>
      ))}
    </div>
  );
}
