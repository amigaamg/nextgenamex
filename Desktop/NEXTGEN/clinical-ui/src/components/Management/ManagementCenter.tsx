import type { ClinicalRuntimeProjection, Fact, ProtocolView, TreatmentRecommendation } from '../../types';

export function ManagementCenter({ projection }: { projection: ClinicalRuntimeProjection }) {
  return (
    <section className="stack">
      <div className="card">
        <header className="card-header">
          <h2>Assessment</h2>
        </header>
        <div className="assessment-block">
          <div>
            <span className="muted small">Working diagnosis</span>
            <div className="assessment-dx">{projection.confidence.workingDiagnosis ?? 'Not yet established'}</div>
          </div>
          <div>
            <span className="muted small">Leading phenotype score</span>
            <div className="assessment-score">{projection.confidence.leadingPhenotypeScore.toFixed(1)}</div>
          </div>
          <div>
            <span className="muted small">Differentials</span>
            <div className="assessment-score">{projection.differentials.length}</div>
          </div>
        </div>
      </div>

      {projection.protocol && <ProtocolCard protocol={projection.protocol} />}

      <SafetyPanel facts={projection.capturedFacts} />

      <div className="card">
        <header className="card-header">
          <h2>Treatment options</h2>
          <span className="muted small">verification status from the safety engine</span>
        </header>
        {projection.treatment.length === 0 ? (
          <p className="muted">No treatment options yet — the working diagnosis drives these.</p>
        ) : (
          <div className="meds">
            {projection.treatment.map((med) => (
              <MedCard key={med.medicationCode} med={med} />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

function SafetyPanel({ facts }: { facts: Fact[] }) {
  const allergies = new Set<string>();
  let pregnant = false;
  let hepaticImpairment = false;
  let creatinine: number | null = null;

  for (const fact of facts) {
    for (const value of fact.values) {
      switch (fact.factCode) {
        case 'DRUG_ALLERGY':
          if (value.text) allergies.add(value.text);
          break;
        case 'PREGNANT':
          if (value.boolean === true) pregnant = true;
          break;
        case 'HEPATIC_IMPAIRMENT':
          if (value.boolean === true) hepaticImpairment = true;
          break;
        case 'CREATININE':
          if (value.numeric != null) creatinine = value.numeric;
          break;
        default:
          break;
      }
    }
  }
  const renalImpairment = creatinine != null && creatinine > 1.3;

  const rows: { label: string; status: string; danger?: boolean }[] = [];
  rows.push({ label: 'Drug allergies', status: allergies.size === 0 ? 'None documented' : [...allergies].join(', ') });
  rows.push({ label: 'Pregnancy', status: pregnant ? 'Present' : 'Not indicated', danger: pregnant });
  rows.push({ label: 'Renal function', status: renalImpairment ? `Impaired (creatinine ${creatinine})` : 'No impairment indicated', danger: renalImpairment });
  rows.push({ label: 'Hepatic function', status: hepaticImpairment ? 'Impaired' : 'No impairment indicated', danger: hepaticImpairment });

  return (
    <div className="card">
      <header className="card-header">
        <h2>Safety profile</h2>
        <span className="muted small">derived from captured allergy / renal / pregnancy facts</span>
      </header>
      <div className="safety-grid">
        {rows.map((r) => (
          <div key={r.label} className={`safety-cell ${r.danger ? 'safety-danger' : ''}`}>
            <div className="muted small">{r.label}</div>
            <div className="safety-value">{r.status}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ProtocolCard({ protocol }: { protocol: ProtocolView }) {
  return (
    <div className="card">
      <header className="card-header">
        <h2>{protocol.name}</h2>
        <span className="muted small mono">{protocol.protocolCode}</span>
      </header>
      {protocol.purpose && <p className="muted">{protocol.purpose}</p>}
      <ol className="protocol-steps">
        {[...protocol.steps]
          .sort((a, b) => a.sequenceNo - b.sequenceNo)
          .map((step) => (
            <li key={step.stepCode}>
              <div className="step-head">
                <span className="step-no">{step.sequenceNo}</span>
                <span className="step-label">{step.label}</span>
                {step.required && <span className="tag tag-required">required</span>}
              </div>
              {step.instruction && <p className="step-instr">{step.instruction}</p>}
              {step.actions.length > 0 && (
                <div className="step-actions">
                  {step.actions.map((a) => (
                    <span key={`${a.actionCode}-${a.actionType}`} className="step-action">
                      {a.actionName} ({a.urgency})
                    </span>
                  ))}
                </div>
              )}
            </li>
          ))}
      </ol>
    </div>
  );
}

function MedCard({ med }: { med: TreatmentRecommendation }) {
  return (
    <div className={`med ${med.contraindicated ? 'med-contraindicated' : ''}`}>
      <div className="med-head">
        <span className="med-name">{med.genericName}</span>
        <span className="tag">{med.role}</span>
        {!med.verified && <span className="tag tag-required">dose needs verification</span>}
        {med.contraindicated && <span className="tag tag-danger">contraindicated</span>}
      </div>
      <div className="med-dose">
        {med.doseExpression}
        {med.route ? ` · ${med.route}` : ''}
        {med.frequency ? ` · ${med.frequency}` : ''}
        {med.duration ? ` · ${med.duration}` : ''}
      </div>
      {med.safetyNotes.length > 0 && (
        <div className="med-notes">
          {med.safetyNotes.map((n) => (
            <span key={n} className={n.toLowerCase().includes('contra') || n.toLowerCase().includes('caution') ? 'note-danger' : ''}>
              • {n}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}