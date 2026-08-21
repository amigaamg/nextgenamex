// =============================================================================
// src/components/Examination/FindingControl.tsx
// Renders the capture control for a single examination finding and, where the
// knowledge base supports it, a live deduction next to the entered value.
// =============================================================================

import type { ClinicalContext, ExaminationFinding } from '../../clinical/types';
import {
  deduceBmi,
  deduceHeadCircumference,
  deduceHeight,
  deduceHeartRate,
  deduceMuac,
  deduceRespiratoryRate,
  deduceSpo2,
  deduceTemperature,
  deduceWeight,
  signGradeDescription,
} from '../../clinical/exam/norms';
import type { VitalsDeduction } from '../../clinical/exam/norms';

interface FindingControlProps {
  finding: ExaminationFinding;
  context: ClinicalContext;
  value: unknown;
  onCapture: (value: unknown, unit?: string | null) => void;
}

const SEVERITY_OPTIONS = ['+', '++', '+++'];

function statusPillClass(deduction: VitalsDeduction | null): string {
  if (!deduction) return '';
  switch (deduction.status) {
    case 'normal':
      return 'text-good';
    case 'low':
      return 'text-warn';
    case 'high':
      return 'text-bad';
    default:
      return 'text-muted';
  }
}

function deductionFor(
  finding: ExaminationFinding,
  value: unknown,
  context: ClinicalContext,
): VitalsDeduction | null {
  const numeric =
    typeof value === 'number' ? value : Number(value);
  const hasValue = typeof value === 'number' || (typeof value === 'string' && value !== '');
  const age = {
    ageYears: context.ageYears,
    ageMonths: context.ageMonths,
    ageDays: context.ageDays,
  };

  if (!hasValue || Number.isNaN(numeric)) return null;

  switch (finding.findingCode) {
    case 'EXAM_VITALS_HR':
      return deduceHeartRate(numeric, age);
    case 'EXAM_VITALS_RR':
      return deduceRespiratoryRate(numeric, age);
    case 'EXAM_VITALS_TEMP':
      return deduceTemperature(numeric);
    case 'EXAM_VITALS_SPO2':
      return deduceSpo2(numeric, age);
    case 'EXAM_VITALS_SBP':
      return deductionForBloodPressure(finding.findingCode, numeric);
    case 'EXAM_VITALS_DBP':
      return deductionForBloodPressure(finding.findingCode, numeric);
    case 'EXAM_ANTHRO_WEIGHT':
      return deduceWeight(numeric, age);
    case 'EXAM_ANTHRO_HEIGHT':
      return deduceHeight(numeric, age);
    case 'EXAM_ANTHRO_HEAD_CIRC':
      return deduceHeadCircumference(numeric, age);
    case 'EXAM_ANTHRO_MUAC':
      return deduceMuac(numeric, age);
    case 'EXAM_ANTHRO_BMI':
      return deduceBmi(numeric, age);
    default:
      return null;
  }
}

/** BP needs both SBP and DBP — we evaluate the entered half against its own range. */
function deductionForBloodPressure(
  findingCode: string,
  numeric: number,
): VitalsDeduction | null {
  // The full BP deduction is computed in the summary strip (both values are
  // known there). For the individual field we show a simple +/- hint.
  const low = findingCode === 'EXAM_VITALS_SBP' ? 90 : 60;
  const high = findingCode === 'EXAM_VITALS_SBP' ? 130 : 85;

  if (numeric < low) {
    return { status: 'low', label: 'Low', note: `Below usual ${low}–${high} mmHg.` };
  }
  if (numeric > high) {
    return { status: 'high', label: 'High', note: `Above usual ${low}–${high} mmHg.` };
  }
  return { status: 'normal', label: 'Normal', note: `Within ${low}–${high} mmHg.` };
}

function SeverityControl({
  value,
  onSelect,
}: {
  value: string | undefined;
  onSelect: (plus: string) => void;
}) {
  return (
    <div className="severity-row">
      {SEVERITY_OPTIONS.map((plus) => (
        <button
          key={plus}
          type="button"
          className={`severity-option ${value === plus ? 'active' : ''}`}
          onClick={() => onSelect(plus)}
          title={`${plus} — ${signGradeDescription(plus)}`}
        >
          <span className="severity-plus">{plus}</span>
          <span className="severity-word">{signGradeDescription(plus)}</span>
        </button>
      ))}
    </div>
  );
}

export function FindingControl({
  finding,
  context,
  value,
  onCapture,
}: FindingControlProps) {
  const type = (finding.findingType ?? 'select') as string;

  const deduction = deductionFor(finding, value, context);

  // Presence control — Present / Absent.
  if (type === 'presence') {
    const current = value as boolean | undefined;

    return (
      <div className="finding-row">
        <span className="finding-name">{finding.name}</span>

        <div className="presence-row">
          <button
            type="button"
            className={`presence-option positive ${current === true ? 'active' : ''}`}
            onClick={() => onCapture(true)}
          >
            Present
          </button>
          <button
            type="button"
            className={`presence-option negative ${current === false ? 'active' : ''}`}
            onClick={() => onCapture(false)}
          >
            Absent
          </button>
        </div>
      </div>
    );
  }

  // Measurement — numeric input with live deduction.
  if (type === 'measurement') {
    const numericValue = typeof value === 'number' ? value : null;
    const textValue =
      typeof value === 'string' ? value : numericValue != null ? String(numericValue) : '';

    return (
      <div className="finding-row">
        <span className="finding-name">{finding.name}</span>

        <div className="measurement-row">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            className="finding-input"
            placeholder="—"
            value={textValue}
            onChange={(event) => {
              const raw = event.target.value;
              onCapture(raw === '' ? null : Number(raw), finding.unitCode ?? null);
            }}
          />
          <span className="finding-unit">{finding.unitCode ?? ''}</span>
        </div>

        {deduction && (
          <span className={`finding-deduction ${statusPillClass(deduction)}`}>
            {deduction.label}
          </span>
        )}
      </div>
    );
  }

  // Severity — +/++/+++ with site free-text (used with presence sign findings).
  if (type === 'severity') {
    const site = (value as { site?: string } | undefined)?.site ?? '';
    const severity = (value as { severity?: string } | undefined)?.severity;

    return (
      <div className="finding-row">
        <span className="finding-name">{finding.name}</span>

        <div className="severity-block">
          <SeverityControl
            value={severity}
            onSelect={(plus) =>
              onCapture({ severity: plus, site })
            }
          />

          <input
            type="text"
            className="finding-input site"
            placeholder="Site(s) — e.g. palmar creases"
            value={site}
            onChange={(event) =>
              onCapture({ severity, site: event.target.value })
            }
          />
        </div>
      </div>
    );
  }

  // Select — single choice from options.
  if (type === 'select') {
    const current = value as string | undefined;

    return (
      <div className="finding-row">
        <span className="finding-name">{finding.name}</span>

        <div className="select-row">
          {finding.options?.map((option) => (
            <button
              key={option.answerCode}
              type="button"
              className={`select-option ${current === option.answerCode ? 'active' : ''}`}
              onClick={() => onCapture(option.answerCode)}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>
    );
  }

  // Text — free text.
  const textValue = typeof value === 'string' ? value : '';

  return (
    <div className="finding-row">
      <span className="finding-name">{finding.name}</span>

      <input
        type="text"
        className="finding-input text"
        placeholder="Type…"
        value={textValue}
        onChange={(event) => onCapture(event.target.value)}
      />
    </div>
  );
}
