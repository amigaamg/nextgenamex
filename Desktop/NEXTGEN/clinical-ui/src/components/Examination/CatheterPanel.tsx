// =============================================================================
// src/components/Examination/CatheterPanel.tsx
// Catheter / urine output capture with automatic rate calculation:
//   - catheter present (Yes/No),
//   - urine colour,
//   - volume drained (mL) and drainage duration (hours),
//   - auto-calculated rate in mL/hr and mL/kg/hr (uses captured weight),
//   - live deduction (normal / oliguria / polyuria) compared against the
//     expected range for age.
// =============================================================================

import { useMemo } from 'react';
import type { ClinicalContext } from '../../clinical/types';
import {
  deduceUrineOutput,
  urineOutputRangeForAge,
  urineRatePerHour,
  urineRatePerKgPerHour,
} from '../../clinical/exam/norms';

interface CatheterPanelProps {
  context: ClinicalContext;
  capturedValues: Record<string, unknown>;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

const URINE_COLORS: { code: string; label: string }[] = [
  { code: 'clear', label: 'Clear' },
  { code: 'pale_yellow', label: 'Pale yellow' },
  { code: 'yellow', label: 'Yellow' },
  { code: 'dark_yellow', label: 'Dark yellow' },
  { code: 'amber', label: 'Amber' },
  { code: 'blood_stained', label: 'Blood-stained' },
  { code: 'coca_cola', label: 'Coca-cola' },
  { code: 'cloudy', label: 'Cloudy' },
];

function numericValue(capturedValues: Record<string, unknown>, code: string): number | null {
  const value = capturedValues[code];
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
      return 'catheter-pill good';
    case 'low':
      return 'catheter-pill warn';
    case 'high':
      return 'catheter-pill bad';
    default:
      return 'catheter-pill muted';
  }
}

export function CatheterPanel({
  context,
  capturedValues,
  onCapture,
}: CatheterPanelProps) {
  const age = {
    ageYears: context.ageYears,
    ageMonths: context.ageMonths,
    ageDays: context.ageDays,
  };

  const catheterPresent = capturedValues['EXAM_GEN_CATHETER'] as boolean | undefined;
  const volume = numericValue(capturedValues, 'EXAM_GEN_URINE_VOLUME');
  const duration = numericValue(capturedValues, 'EXAM_GEN_URINE_DURATION');
  const weight = numericValue(capturedValues, 'EXAM_ANTHRO_WEIGHT');
  const color = capturedValues['EXAM_GEN_URINE_COLOR'] as string | undefined;

  const expected = useMemo(() => urineOutputRangeForAge(age), [age.ageYears, age.ageMonths, age.ageDays]);

  const perHour = urineRatePerHour(volume, duration);
  const perKgPerHour = urineRatePerKgPerHour(volume, duration, weight);

  const deduction = useMemo(
    () => deduceUrineOutput(volume, duration, weight, age),
    [volume, duration, weight, age.ageYears, age.ageMonths, age.ageDays],
  );

  const numberInput = (
    code: string,
    label: string,
    unit: string,
    value: number | null,
  ) => (
    <div className="catheter-field">
      <span className="catheter-field-label">{label}</span>
      <div className="catheter-input-group">
        <input
          type="number"
          inputMode="decimal"
          step="any"
          className="catheter-input"
          placeholder="—"
          value={value != null ? String(value) : ''}
          onChange={(event) => {
            const raw = event.target.value;
            onCapture(code, raw === '' ? null : Number(raw), unit);
          }}
        />
        <span className="catheter-unit">{unit}</span>
      </div>
    </div>
  );

  return (
    <section className="exam-module-card">
      <header className="exam-module-head">
        <div>
          <h2 className="exam-module-title">Catheter & Urine Output</h2>
          <span className="exam-module-required">If catheterised</span>
        </div>
        <span className="exam-module-code">URINE</span>
      </header>

      <div className="exam-module-body">
        <div className="catheter-row">
          <span className="finding-name">Urinary catheter in situ</span>
          <div className="presence-row">
            <button
              type="button"
              className={`presence-option positive ${catheterPresent === true ? 'active' : ''}`}
              onClick={() => onCapture('EXAM_GEN_CATHETER', true)}
            >
              Yes
            </button>
            <button
              type="button"
              className={`presence-option negative ${catheterPresent === false ? 'active' : ''}`}
              onClick={() => onCapture('EXAM_GEN_CATHETER', false)}
            >
              No
            </button>
          </div>
        </div>

        {catheterPresent === true && (
          <>
            <div className="catheter-row">
              <span className="finding-name">Urine colour</span>
              <div className="select-row catheter-colors">
                {URINE_COLORS.map((option) => (
                  <button
                    key={option.code}
                    type="button"
                    className={`select-option ${color === option.code ? 'active' : ''}`}
                    onClick={() => onCapture('EXAM_GEN_URINE_COLOR', option.code)}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>

            <div className="catheter-grid">
              {numberInput('EXAM_GEN_URINE_VOLUME', 'Volume drained', 'mL', volume)}
              {numberInput('EXAM_GEN_URINE_DURATION', 'Drainage duration', 'hr', duration)}
            </div>

            <div className="catheter-output">
              <div className="catheter-output-head">
                <span className="catheter-output-title">Calculated urine output rate</span>
                <span className="catheter-expected">
                  Expected for age: {expected.min}–{expected.max} mL/kg/hr
                </span>
              </div>

              <div className="catheter-rate-row">
                <div className="catheter-rate-cell">
                  <span className="catheter-rate-value">
                    {perHour != null ? perHour.toFixed(1) : '—'}
                  </span>
                  <span className="catheter-rate-label">mL/hr</span>
                </div>

                <div className="catheter-rate-cell">
                  <span className="catheter-rate-value">
                    {perKgPerHour != null ? perKgPerHour.toFixed(2) : '—'}
                  </span>
                  <span className="catheter-rate-label">mL/kg/hr</span>
                </div>

                <span className={pillClass(deduction.status)}>
                  {deduction.label}
                </span>
              </div>

              {deduction.note && (
                <p className="catheter-note">{deduction.note}</p>
              )}
            </div>
          </>
        )}

        {catheterPresent === false && (
          <p className="catheter-note">
            No urinary catheter — urine output assessment not applicable.
          </p>
        )}
      </div>
    </section>
  );
}