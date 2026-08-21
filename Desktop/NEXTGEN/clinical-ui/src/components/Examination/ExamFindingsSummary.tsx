// =============================================================================
// src/components/Examination/ExamFindingsSummary.tsx
// Generates an organised, narrative-style summary of all captured findings so
// the clinician immediately sees the structured documentation being built.
// =============================================================================

import { useMemo } from 'react';
import type { ClinicalContext, ExaminationFinding } from '../../clinical/types';
import {
  ALL_EXAMINATION_MODULES,
} from '../../clinical/exam/modules';
import {
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

interface ExamFindingsSummaryProps {
  capturedValues: Record<string, unknown>;
  context: ClinicalContext;
}

function readText(value: unknown): string {
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string' && value !== '') return value;
  return '';
}

export function ExamFindingsSummary({
  capturedValues,
  context,
}: ExamFindingsSummaryProps) {
  const age = {
    ageYears: context.ageYears,
    ageMonths: context.ageMonths,
    ageDays: context.ageDays,
  };

  const numeric = (code: string): number | null => {
    const value = capturedValues[code];
    if (typeof value === 'number') return value;
    if (typeof value === 'string' && value !== '') {
      const parsed = Number(value);
      return Number.isNaN(parsed) ? null : parsed;
    }
    return null;
  };

  const text = (code: string): string => readText(capturedValues[code]);

  const lines = useMemo(() => {
    const output: { module: string; text: string }[] = [];

    const anthropo: string[] = [];
    const weight = numeric('EXAM_ANTHRO_WEIGHT');
    const height = numeric('EXAM_ANTHRO_HEIGHT');
    const hc = numeric('EXAM_ANTHRO_HEAD_CIRC');
    const muac = numeric('EXAM_ANTHRO_MUAC');
    const bmi = numeric('EXAM_ANTHRO_BMI');

    if (weight != null) anthropo.push(`Weight ${weight} kg (${deduceWeight(weight, age).label.toLowerCase()}).`);
    if (height != null) anthropo.push(`Height/Length ${height} cm (${deduceHeight(height, age).label.toLowerCase()}).`);
    if (hc != null) anthropo.push(`Head circumference ${hc} cm (${deduceHeadCircumference(hc, age).label.toLowerCase()}).`);
    if (muac != null) anthropo.push(`MUAC ${muac} cm (${deduceMuac(muac, age).label.toLowerCase()}).`);
    if (bmi != null) anthropo.push(`BMI ${bmi} (${deduceBmi(bmi, age).label.toLowerCase()}).`);

    if (anthropo.length > 0) {
      output.push({ module: 'Anthropometry', text: anthropo.join(' ') });
    }

    const vitals: string[] = [];
    const temp = numeric('EXAM_VITALS_TEMP');
    const hr = numeric('EXAM_VITALS_HR');
    const rr = numeric('EXAM_VITALS_RR');
    const sbp = numeric('EXAM_VITALS_SBP');
    const dbp = numeric('EXAM_VITALS_DBP');
    const spo2 = numeric('EXAM_VITALS_SPO2');
    const rbs = numeric('EXAM_VITALS_RBS');

    if (temp != null) vitals.push(`Temperature ${temp} °C — ${deduceTemperature(temp).label.toLowerCase()}.`);
    if (hr != null) vitals.push(`Heart rate ${hr} bpm — ${deduceHeartRate(hr, age).label.toLowerCase()}.`);
    if (rr != null) vitals.push(`Respiratory rate ${rr}/min — ${deduceRespiratoryRate(rr, age).label.toLowerCase()}.`);
    if (sbp != null && dbp != null) vitals.push(`Blood pressure ${sbp}/${dbp} mmHg.`);
    else if (sbp != null) vitals.push(`BP systolic ${sbp} mmHg.`);
    if (spo2 != null) vitals.push(`SpO₂ ${spo2}% — ${deduceSpo2(spo2, age).label.toLowerCase()}.`);
    if (rbs != null) vitals.push(`Random blood sugar ${rbs} mmol/L.`);

    if (vitals.length > 0) {
      output.push({ module: 'Vital Signs', text: vitals.join(' ') });
    }

    const urineVolume = numeric('EXAM_GEN_URINE_VOLUME');
    const urineDuration = numeric('EXAM_GEN_URINE_DURATION');
    const urineColor = text('EXAM_GEN_URINE_COLOR');
    const catheter = capturedValues['EXAM_GEN_CATHETER'];

    const urineLines: string[] = [];
    if (catheter === true || urineVolume != null || urineDuration != null) {
      if (urineColor) urineLines.push(`Urine colour ${urineColor}.`);
      if (urineVolume != null && urineDuration != null) {
        const deduction = deduceUrineOutput(urineVolume, urineDuration, weight, age);
        urineLines.push(
          `${urineVolume} mL drained over ${urineDuration} hr — ${deduction.label.toLowerCase()}.`,
        );
      }
    }
    if (urineLines.length > 0) {
      output.push({ module: 'Catheter & Urine Output', text: urineLines.join(' ') });
    }

    // Presence signs with severity + site.
    const signMap: { presenceCode: string; siteCode: string; severityCode: string; name: string }[] = [
      { presenceCode: 'EXAM_GEN_PALLOR', siteCode: 'EXAM_GEN_PALLOR_SITE', severityCode: 'EXAM_GEN_PALLOR_SEVERITY', name: 'Pallor' },
      { presenceCode: 'EXAM_GEN_JAUNDICE', siteCode: 'EXAM_GEN_JAUNDICE_SITE', severityCode: 'EXAM_GEN_JAUNDICE_SEVERITY', name: 'Jaundice' },
      { presenceCode: 'EXAM_GEN_CYANOSIS', siteCode: 'EXAM_GEN_CYANOSIS_SITE', severityCode: '', name: 'Cyanosis' },
      { presenceCode: 'EXAM_GEN_CLUBBING', siteCode: 'EXAM_GEN_CLUBBING_SITE', severityCode: '', name: 'Clubbing' },
      { presenceCode: 'EXAM_GEN_EDEMA', siteCode: 'EXAM_GEN_EDEMA_SITE', severityCode: 'EXAM_GEN_EDEMA_SEVERITY', name: 'Edema' },
      { presenceCode: 'EXAM_GEN_LYMPHADENOPATHY', siteCode: 'EXAM_GEN_LYMPH_NODE_SITE', severityCode: '', name: 'Lymphadenopathy' },
    ];

    for (const sign of signMap) {
      const present = capturedValues[sign.presenceCode];
      if (present === undefined) continue;

      if (present === true) {
        let severityLabel = '';
        const severityValue = capturedValues[sign.severityCode];
        if (typeof severityValue === 'string' && severityValue) {
          severityLabel = ` (${severityValue})`;
        } else if (severityValue && typeof severityValue === 'object') {
          const severity = (severityValue as { severity?: string }).severity;
          if (severity) severityLabel = ` (${severity})`;
        }

        const rawSite = capturedValues[sign.siteCode];
        const siteValue = Array.isArray(rawSite)
          ? (rawSite as string[]).join(', ')
          : text(sign.siteCode);

        output.push({
          module: 'General Examination',
          text: `${sign.name} present${severityLabel}${siteValue ? ` — ${siteValue}` : ''}.`,
        });
      } else if (present === false) {
        output.push({
          module: 'General Examination',
          text: `${sign.name} absent.`,
        });
      }
    }

    const ent = text('EXAM_GEN_ENT_ORAL');
    if (ent && ent !== 'normal') {
      output.push({ module: 'General Examination', text: `ENT/oral: ${ent}.` });
    }

    // Local examination summary.
    const localType = text('EXAM_LOCAL_TYPE');
    if (localType && localType !== 'none') {
      const parts: string[] = [];
      const site = text('EXAM_LOCAL_SITE');
      const size = numeric('EXAM_LOCAL_SIZE');
      const consistency = text('EXAM_LOCAL_CONSISTENCY');
      const edge = text('EXAM_LOCAL_EDGE');
      const discharge = text('EXAM_LOCAL_DISCHARGE');
      const notes = text('EXAM_LOCAL_NOTES');

      parts.push(`${localType} at ${site || '—'}`);
      if (size != null) parts.push(`${size} cm`);
      if (consistency) parts.push(consistency);
      if (edge) parts.push(edge);
      if (discharge && discharge !== 'none') parts.push(`discharge ${discharge}`);
      if (notes) parts.push(notes);

      output.push({ module: 'Local Examination', text: parts.join(', ') + '.' });
    }

    // System examinations — built from the module definitions so every
    // captured finding (CVS, RESP, ABDOMEN, CNS, MSK, BREAST, OBSTETRIC)
    // flows into the narrative in the correct technique order.
    const reportedByCode = [
      'EXAM_CVS_',
      'EXAM_RESP_',
      'EXAM_ABD_',
      'EXAM_CNS_',
      'EXAM_MSK_',
      'EXAM_BREAST_',
      'EXAM_OB_',
    ];

    for (const module of ALL_EXAMINATION_MODULES) {
      if (!module.moduleCode) continue;
      if (module.moduleCode === 'ANTHROPO') continue;
      if (module.moduleCode === 'VITALS') continue;
      if (module.moduleCode === 'LOCAL') continue;

      const systemLines: string[] = [];

      for (const finding of module.findings) {
        if (!finding.findingCode) continue;

        const isGeneralOnly = finding.findingCode.startsWith('EXAM_GEN_');
        if (isGeneralOnly) continue;
        if (!reportedByCode.some((prefix) => finding.findingCode.startsWith(prefix))) {
          continue;
        }

        const raw = capturedValues[finding.findingCode];
        if (raw === undefined || raw === null) continue;

        const sentence = describeFinding(finding, raw);
        if (sentence) systemLines.push(sentence);
      }

      if (systemLines.length > 0) {
        output.push({ module: module.name, text: systemLines.join(' ') });
      }
    }

    return output;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [capturedValues, context]);

  if (lines.length === 0) {
    return (
      <section className="exam-summary-card">
        <h3 className="exam-summary-title">Documentation</h3>
        <p className="text-sm text-muted">
          Captured findings will appear here as an organised narrative.
        </p>
      </section>
    );
  }

  return (
    <section className="exam-summary-card">
      <h3 className="exam-summary-title">Documentation</h3>
      <div className="exam-summary-lines">
        {lines.map((line, index) => (
          <p key={index} className="exam-summary-line">
            <strong>{line.module}:</strong> {line.text}
          </p>
        ))}
      </div>
    </section>
  );
}

function describeFinding(
  finding: ExaminationFinding,
  raw: unknown,
): string | null {
  const name = finding.name;

  switch (finding.findingType) {
    case 'presence':
      return `${name}: ${raw === true ? 'present' : raw === false ? 'absent' : ''}.`;

    case 'measurement': {
      if (typeof raw === 'number') {
        return `${name} ${raw}${finding.unitCode ? ` ${finding.unitCode}` : ''}.`;
      }
      if (typeof raw === 'string' && raw !== '') {
        return `${name} ${raw}${finding.unitCode ? ` ${finding.unitCode}` : ''}.`;
      }
      return null;
    }

    case 'severity': {
      if (typeof raw === 'string' && raw) {
        return `${name}: ${raw}.`;
      }
      if (raw && typeof raw === 'object') {
        const severity = (raw as { severity?: string }).severity;
        const site = (raw as { site?: string }).site;
        const parts = [name];
        if (severity) parts.push(severity);
        if (site) parts.push(`(${site})`);
        return `${parts.join(' ')}.`;
      }
      return null;
    }

    case 'select':
    case 'text': {
      if (typeof raw === 'string' && raw !== '') {
        const option = finding.options?.find(
          (candidate) => candidate.answerCode === raw,
        );
        const label = option?.label ?? raw;
        return `${name}: ${label}.`;
      }
      if (typeof raw === 'boolean') {
        return `${name}: ${raw ? 'Yes' : 'No'}.`;
      }
      return null;
    }

    default: {
      if (typeof raw === 'string' && raw !== '') {
        return `${name}: ${raw}.`;
      }
      return null;
    }
  }
}
