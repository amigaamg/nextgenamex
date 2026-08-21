// =============================================================================
// src/components/Examination/VitalsPanel.tsx
// Vital signs capture with an explicit "recorded vs normal for age" table:
//   each row shows the entered value, the expected normal range for this age,
//   and a live deduction (e.g. tachycardia, tachypnoea, fever, hypoxaemia).
// =============================================================================

import { useMemo } from 'react';
import type { ClinicalContext } from '../../clinical/types';
import {
  determineAgeBand,
  deduceBloodPressure,
  deduceHeartRate,
  deduceRespiratoryRate,
  deduceSpo2,
  deduceTemperature,
  vitalsForAge,
} from '../../clinical/exam/norms';
import type { VitalsDeduction } from '../../clinical/exam/norms';

interface VitalsPanelProps {
  context: ClinicalContext;
  capturedValues: Record<string, unknown>;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

interface RowProps {
  label: string;
  code: string;
  unit: string;
  normal: string;
  value: number | null;
  deduction: VitalsDeduction | null;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

function pillClass(status: string): string {
  switch (status) {
    case 'normal':
      return 'vital-pill good';
    case 'low':
      return 'vital-pill warn';
    case 'high':
      return 'vital-pill bad';
    default:
      return 'vital-pill muted';
  }
}

function VitalRow({
  label,
  code,
  unit,
  normal,
  value,
  deduction,
  onCapture,
}: RowProps) {
  const textValue = value != null ? String(value) : '';

  return (
    <div className="vital-row">
      <div className="vital-label">
        <span className="vital-name">{label}</span>
        <span className="vital-normal">Normal: {normal}</span>
      </div>

      <div className="vital-control">
        <div className="vital-input-group">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            className="vital-input"
            placeholder="—"
            value={textValue}
            onChange={(event) => {
              const raw = event.target.value;
              onCapture(code, raw === '' ? null : Number(raw), unit);
            }}
          />
          <span className="vital-unit">{unit}</span>
        </div>

        {deduction && (
          <span className={pillClass(deduction.status)}>
            {deduction.label}
          </span>
        )}
      </div>
    </div>
  );
}

function numericValue(capturedValues: Record<string, unknown>, code: string): number | null {
  const value = capturedValues[code];
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value !== '') {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

export function VitalsPanel({
  context,
  capturedValues,
  onCapture,
}: VitalsPanelProps) {
  const age = {
    ageYears: context.ageYears,
    ageMonths: context.ageMonths,
    ageDays: context.ageDays,
  };

  const range = useMemo(() => vitalsForAge(age), [age.ageYears, age.ageMonths, age.ageDays]);
  const band = determineAgeBand(age);

  const temp = numericValue(capturedValues, 'EXAM_VITALS_TEMP');
  const hr = numericValue(capturedValues, 'EXAM_VITALS_HR');
  const rr = numericValue(capturedValues, 'EXAM_VITALS_RR');
  const sbp = numericValue(capturedValues, 'EXAM_VITALS_SBP');
  const dbp = numericValue(capturedValues, 'EXAM_VITALS_DBP');
  const spo2 = numericValue(capturedValues, 'EXAM_VITALS_SPO2');
  const rbs = numericValue(capturedValues, 'EXAM_VITALS_RBS');

  const bpDeduction = sbp != null || dbp != null
    ? deduceBloodPressure(sbp, dbp, age)
    : null;

  return (
    <section className="exam-module-card">
      <header className="exam-module-head">
        <div>
          <h2 className="exam-module-title">Vital Signs</h2>
          <span className="exam-module-required">Required</span>
        </div>
        <span className="exam-module-code">VITALS</span>
      </header>

      <div className="exam-module-body">
        <div className="vital-age-banner">
          Expected ranges shown are for a <strong>{band}</strong> patient.
        </div>

        <VitalRow
          label="Temperature"
          code="EXAM_VITALS_TEMP"
          unit="°C"
          normal={`${range.tempC[0]}–${range.tempC[1]}`}
          value={temp}
          deduction={temp != null ? deduceTemperature(temp) : null}
          onCapture={onCapture}
        />

        <VitalRow
          label="Heart rate"
          code="EXAM_VITALS_HR"
          unit="bpm"
          normal={`${range.hr[0]}–${range.hr[1]}`}
          value={hr}
          deduction={hr != null ? deduceHeartRate(hr, age) : null}
          onCapture={onCapture}
        />

        <VitalRow
          label="Respiratory rate"
          code="EXAM_VITALS_RR"
          unit="/min"
          normal={`${range.rr[0]}–${range.rr[1]}`}
          value={rr}
          deduction={rr != null ? deduceRespiratoryRate(rr, age) : null}
          onCapture={onCapture}
        />

        <VitalRow
          label="Blood pressure (systolic)"
          code="EXAM_VITALS_SBP"
          unit="mmHg"
          normal={`${range.sbp[0]}–${range.sbp[1]}`}
          value={sbp}
          deduction={sbp != null || dbp != null ? bpDeduction : null}
          onCapture={onCapture}
        />

        <VitalRow
          label="Blood pressure (diastolic)"
          code="EXAM_VITALS_DBP"
          unit="mmHg"
          normal={`${range.dbp[0]}–${range.dbp[1]}`}
          value={dbp}
          deduction={sbp != null || dbp != null ? bpDeduction : null}
          onCapture={onCapture}
        />

        <VitalRow
          label="Oxygen saturation (SpO₂)"
          code="EXAM_VITALS_SPO2"
          unit="%"
          normal={`≥ ${range.spo2Min}`}
          value={spo2}
          deduction={spo2 != null ? deduceSpo2(spo2, age) : null}
          onCapture={onCapture}
        />

        <VitalRow
          label="Random blood sugar"
          code="EXAM_VITALS_RBS"
          unit="mmol/L"
          normal="3.9–7.8"
          value={rbs}
          deduction={null}
          onCapture={onCapture}
        />
      </div>
    </section>
  );
}