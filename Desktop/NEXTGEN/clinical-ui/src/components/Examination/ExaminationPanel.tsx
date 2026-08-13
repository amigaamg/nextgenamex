import { useState } from 'react';
import type { ExaminationModuleView } from '../../types';

type FindingValue = boolean | number | string;

export function ExaminationPanel({
  modules,
  onFinding,
}: {
  modules: ExaminationModuleView[];
  onFinding: (findingCode: string, value: unknown, unit?: string) => void;
}) {
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