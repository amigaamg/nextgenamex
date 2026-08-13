import type { ClinicalRuntimeProjection, MonitoringTarget } from '../../types';

export function MonitoringCenter({ projection }: { projection: ClinicalRuntimeProjection }) {
  const targets = projection.monitoring;
  const measurements = projection.capturedFacts.filter((f) => f.values.some((v) => v.numeric != null));

  return (
    <section className="stack">
      <div className="card">
        <header className="card-header">
          <h2>Monitoring plan</h2>
          <span className="muted small">targets derived from the active protocol, not invented by the UI</span>
        </header>
        {targets.length === 0 ? (
          <p className="muted">No monitoring targets yet.</p>
        ) : (
          <div className="monitoring-grid">
            {targets.map((t) => (
              <MonitoringTargetCard key={t.monitoringCode} target={t} />
            ))}
          </div>
        )}
      </div>

      {measurements.length > 0 && (
        <div className="card">
          <header className="card-header">
            <h2>Latest measurements</h2>
          </header>
          <div className="results">
            {measurements.map((f) => (
              <div key={f.id} className="result-row">
                <span className="result-fact">{f.factCode}</span>
                <span className="result-value">
                  {f.values
                    .map((v) => (v.numeric != null ? `${v.numeric}${v.unitCode ? ` ${v.unitCode}` : ''}` : ''))
                    .join(' / ')}
                </span>
                <span className="result-source">captured</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}

function MonitoringTargetCard({ target }: { target: MonitoringTarget }) {
  return (
    <div className={`mon-target ${target.alert ? 'mon-alert' : ''}`}>
      <div className="mon-head">
        <span>{target.name}</span>
        {target.unit && <span className="muted small">{target.unit}</span>}
      </div>
      {target.currentValue != null && <div className="mon-value">{target.currentValue}</div>}
      {target.frequency && <div className="muted small">Every {target.frequency}</div>}
      {target.deteriorationRule && <div className="muted small">Rule: {target.deteriorationRule}</div>}
      {target.alert && <div className="mon-escalation">{target.alert}</div>}
      {target.escalationInstruction && <div className="muted small">{target.escalationInstruction}</div>}
      <div className="muted small mono">{target.monitoringCode}</div>
    </div>
  );
}