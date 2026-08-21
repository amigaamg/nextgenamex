// =============================================================================
// src/components/Examination/AnthropometryPanel.tsx
// Age-adaptive anthropometric capture:
//   - length (< 2 yrs) vs height (≥ 2 yrs),
//   - head circumference (< 2 yrs),
//   - MUAC (6–59 months),
//   - BMI (≥ 6 yrs),
//   - weight (always),
// with the expected normal range shown beside each input and a live
// normal/abnormal deduction once a value is entered.
// =============================================================================

import { useMemo } from 'react';
import type { ClinicalContext } from '../../clinical/types';
import {
  anthropometryGuide,
  deduceBmi,
  deduceHeadCircumference,
  deduceHeight,
  deduceMuac,
  deduceWeight,
} from '../../clinical/exam/norms';

interface AnthropometryPanelProps {
  context: ClinicalContext;
  capturedValues: Record<string, unknown>;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

interface FieldProps {
  label: string;
  expected: string;
  code: string;
  unit: string;
  value: unknown;
  deduction: { status: string; label: string } | null;
  onCapture: (
    findingCode: string,
    value: unknown,
    unit?: string | null,
  ) => void;
}

function pillClass(status: string): string {
  switch (status) {
    case 'normal':
      return 'anthro-pill good';
    case 'low':
      return 'anthro-pill warn';
    case 'high':
      return 'anthro-pill bad';
    default:
      return 'anthro-pill muted';
  }
}

function AnthroField({
  label,
  expected,
  code,
  unit,
  value,
  deduction,
  onCapture,
}: FieldProps) {
  const numericValue = typeof value === 'number' ? value : null;
  const textValue =
    typeof value === 'string'
      ? value
      : numericValue != null
        ? String(numericValue)
        : '';

  return (
    <div className="anthro-row">
      <div className="anthro-label">
        <span className="anthro-name">{label}</span>
        <span className="anthro-expected">Expected: {expected}</span>
      </div>

      <div className="anthro-control">
        <div className="anthro-input-group">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            className="anthro-input"
            placeholder="—"
            value={textValue}
            onChange={(event) => {
              const raw = event.target.value;
              onCapture(code, raw === '' ? null : Number(raw), unit);
            }}
          />
          <span className="anthro-unit">{unit}</span>
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

export function AnthropometryPanel({
  context,
  capturedValues,
  onCapture,
}: AnthropometryPanelProps) {
  const age = {
    ageYears: context.ageYears,
    ageMonths: context.ageMonths,
    ageDays: context.ageDays,
  };

  const guide = useMemo(() => anthropometryGuide(age), [age.ageYears, age.ageMonths, age.ageDays]);

  const numeric = (code: string): number | null => {
    const value = capturedValues[code];
    if (typeof value === 'number') return value;
    if (typeof value === 'string' && value !== '') {
      const parsed = Number(value);
      return Number.isNaN(parsed) ? null : parsed;
    }
    return null;
  };

  const weight = numeric('EXAM_ANTHRO_WEIGHT');
  const height = numeric('EXAM_ANTHRO_HEIGHT');
  const hc = numeric('EXAM_ANTHRO_HEAD_CIRC');
  const muac = numeric('EXAM_ANTHRO_MUAC');
  const bmi = numeric('EXAM_ANTHRO_BMI');

  const heightLabel = guide.useLength ? 'Length' : 'Height';

  return (
    <section className="exam-module-card">
      <header className="exam-module-head">
        <div>
          <h2 className="exam-module-title">Anthropometric Measurements</h2>
          <span className="exam-module-required">Required</span>
        </div>
        <span className="exam-module-code">ANTHROPO</span>
      </header>

      <div className="exam-module-body">
        <AnthroField
          label="Weight"
          expected={guide.weightExpected}
          code="EXAM_ANTHRO_WEIGHT"
          unit="kg"
          value={capturedValues['EXAM_ANTHRO_WEIGHT']}
          deduction={weight != null ? deduceWeight(weight, age) : null}
          onCapture={onCapture}
        />

        <AnthroField
          label={heightLabel}
          expected={guide.heightExpected}
          code="EXAM_ANTHRO_HEIGHT"
          unit="cm"
          value={capturedValues['EXAM_ANTHRO_HEIGHT']}
          deduction={height != null ? deduceHeight(height, age) : null}
          onCapture={onCapture}
        />

        {guide.showHeadCirc && (
          <AnthroField
            label="Head circumference"
            expected={guide.headCircExpected}
            code="EXAM_ANTHRO_HEAD_CIRC"
            unit="cm"
            value={capturedValues['EXAM_ANTHRO_HEAD_CIRC']}
            deduction={hc != null ? deduceHeadCircumference(hc, age) : null}
            onCapture={onCapture}
          />
        )}

        {guide.showMuac && (
          <AnthroField
            label="MUAC"
            expected={guide.muacExpected}
            code="EXAM_ANTHRO_MUAC"
            unit="cm"
            value={capturedValues['EXAM_ANTHRO_MUAC']}
            deduction={muac != null ? deduceMuac(muac, age) : null}
            onCapture={onCapture}
          />
        )}

        {guide.showBmi && (
          <AnthroField
            label="BMI"
            expected={guide.bmiExpected}
            code="EXAM_ANTHRO_BMI"
            unit="kg/m²"
            value={capturedValues['EXAM_ANTHRO_BMI']}
            deduction={bmi != null ? deduceBmi(bmi, age) : null}
            onCapture={onCapture}
          />
        )}

        <div className="anthro-note">
          <span className="anthro-note-badge">ℹ</span>
          <span>
            {guide.useLength
              ? 'Recumbent length is measured in children under 2 years.'
              : 'Standing height is measured in children 2 years and older.'}{' '}
            Measurements are compared against expected values for age using
            WHO reference ranges.
          </span>
        </div>
      </div>
    </section>
  );
}