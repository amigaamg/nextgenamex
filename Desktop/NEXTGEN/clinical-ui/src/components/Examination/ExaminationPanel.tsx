import { useState } from 'react';
import type { ExaminationModuleView } from '../../types';

type FindingValue = boolean | number | string;

function FindingRow({
  findingCode,
  name,
  type,
  onFinding,
}: {
  findingCode: string;
  name: string;
  type: string;
  onFinding: (findingCode: string, value: unknown, unit?: string) => void;
}) {
  const [value, setValue] = useState<FindingValue>('');
  const measurement = type === 'measurement';

  return (
    <div className="finding">
      <span className="finding-name">{name}</span>
      <span className="muted small mono">{findingCode}</span>
      {measurement ? (
        <div className="finding-input">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            value={value as number}
            placeholder="value"
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && value !== '') {
                onFinding(findingCode, Number(value));
                setValue('');
              }
            }}
          />
          <button className="btn btn-finding" disabled={value === ''} onClick={() => { onFinding(findingCode, Number(value)); setValue(''); }}>
            OK
          </button>
        </div>
      ) : (
        <div className="answer-row">
          {[true, false].map((present) => (
            <button key={String(present)} className="answer" onClick={() => onFinding(findingCode, present)}>
              {present ? 'Present' : 'Absent'}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

const DEFAULT_HUTCHINSON_MODULES: ExaminationModuleView[] = [
  {
    moduleCode: 'ANTHROPO',
    name: 'Pediatric Anthropometrics',
    findings: [
      { findingCode: 'HEIGHT', name: 'Height', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'WEIGHT', name: 'Weight', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'HEAD_CIRCUMFERENCE', name: 'Head circumference', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'MUAC', name: 'MUAC', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'BMI', name: 'BMI', factDefinitionCode: null, findingType: 'measurement' },
    ],
  },
  {
    moduleCode: 'GENERAL',
    name: 'General Examination',
    findings: [
      { findingCode: 'GEN_APPEARANCE', name: 'General appearance', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_NUTRITION', name: 'Nutritional status', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_TOXIC', name: 'Toxic appearance', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_DISTRESSED', name: 'Distressed', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'VITALS_TEMP', name: 'Temperature (°C)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'VITALS_BP', name: 'Blood pressure (mmHg)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'VITALS_HR', name: 'Heart rate (bpm)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'VITALS_RR', name: 'Respiratory rate (/min)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'VITALS_SPO2', name: 'SpO₂ (%)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'VITALS_RBS', name: 'Random blood sugar (mg/dL)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'GEN_PALLOR', name: 'Pallor', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_JAUNDICE', name: 'Jaundice', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_CYANOSIS', name: 'Cyanosis', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_CLUBBING', name: 'Finger clubbing', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_EDEMA', name: 'Edema', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_PALLOR_SITE', name: 'Pallor site', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_PALLOR_SEVERITY', name: 'Pallor severity', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_CATHETER', name: 'Urinary catheter', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_CATHETER_URINE_COLOR', name: 'Urine color', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_CATHETER_URINE_AMOUNT', name: 'Urine amount (mL)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'GEN_CATHETER_DURATION', name: 'Catheter duration (hours)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'GEN_CATHETER_OUTPUT_RATE', name: 'Urine output rate (mL/hr)', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'GEN_ENT_ORAL_THRUSH', name: 'Oral thrush', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'GEN_ENT_TONSILLAR_INFLAMMATION', name: 'Tonsillar inflammation', factDefinitionCode: null, findingType: 'select' },
    ],
  },
  {
    moduleCode: 'CVS',
    name: 'CVS (Cardiovascular System)',
    findings: [
      { findingCode: 'CVS_JVP', name: 'JVP', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'CVS_AP', name: 'Apical pulse', factDefinitionCode: null, findingType: 'measurement' },
      { findingCode: 'CVS_EDMA', name: 'Edema', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'CVS_CRACKLES', name: 'Basal crackles', factDefinitionCode: null, findingType: 'select' },
    ],
  },
  {
    moduleCode: 'ABDOMINAL',
    name: 'Abdominal Examination',
    findings: [
      { findingCode: 'ABDOMINAL_SCARS', name: 'Scars', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'ABDOMINAL_MASS', name: 'Mass', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'ABDOMINAL_TENDERNESS', name: 'Tenderness', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'ABDOMINAL_REBOUND', name: 'Rebound tenderness', factDefinitionCode: null, findingType: 'select' },
    ],
  },
  {
    moduleCode: 'CNS',
    name: 'CNS (Central Nervous System)',
    findings: [
      { findingCode: 'CNS_ALERTNESS', name: 'Alertness', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'CNS_REFLEXES', name: 'Reflexes', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'CNS_COORDINATION', name: 'Coordination', factDefinitionCode: null, findingType: 'select' },
    ],
  },
  {
    moduleCode: 'MSK',
    name: 'Musculoskeletal Examination',
    findings: [
      { findingCode: 'MSK_RANGE', name: 'Range of motion', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'MSK_SWELLING', name: 'Swelling', factDefinitionCode: null, findingType: 'select' },
      { findingCode: 'MSK_REALIGNMENT', name: 'Realignment', factDefinitionCode: null, findingType: 'select' },
    ],
  },
];

export function ExaminationPanel({
  examination,
  onFinding,
}: {
  examination: ExaminationModuleView[];
  onFinding: (findingCode: string, value: unknown, unit?: string) => void;
}) {
  const modules = examination ?? DEFAULT_HUTCHINSON_MODULES;

  if (modules.length === 0) {
    return (
      <section className="card">
        <header className="card-header">
          <h2>Examination</h2>
        </header>
        <p className="muted">No examination modules recommended for the current reasoning.</p>
      </section>
    );
  }

  return (
    <section className="stack">
      {modules.map((m) => (
        <div key={m.moduleCode} className="card exam-module">
          <header className="card-header">
            <h2>{m.name}</h2>
            <span className="muted small mono">{m.moduleCode}</span>
          </header>
          <div className="exam-grid">
            {m.findings.map((f) => (
              <FindingRow key={f.findingCode} findingCode={f.findingCode} name={f.name} type={f.findingType} onFinding={onFinding} />
            ))}
          </div>
        </div>
      ))}
    </section>
  );
}