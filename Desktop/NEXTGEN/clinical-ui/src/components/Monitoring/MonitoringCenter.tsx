import type {
  ClinicalRuntimeProjection,
  ClinicalUIState,
  MonitoringTarget,
} from '../../types';

interface MonitoringCenterProps {
  projection: ClinicalRuntimeProjection;
  uiState?: ClinicalUIState | null;
}

export function MonitoringCenter({
  projection,
  uiState: _uiState,
}: MonitoringCenterProps) {
  const targets = projection.monitoring ?? [];

  const measurements = (projection.capturedFacts ?? []).filter((fact) =>
    fact.values?.some((value) => value.numeric != null),
  );

  return (
    <section className="stack" aria-label="Clinical monitoring">
      <div className="card">
        <header className="card-header">
          <div>
            <h2>Monitoring Plan</h2>
            <p className="muted small">
              Targets are derived from the active clinical protocol.
            </p>
          </div>

          <span className="muted small">
            {targets.length} target{targets.length === 1 ? '' : 's'}
          </span>
        </header>

        {targets.length === 0 ? (
          <div className="empty-state compact">
            <p className="muted">No monitoring targets are currently resolved.</p>
          </div>
        ) : (
          <div className="monitoring-grid">
            {targets.map((target) => (
              <MonitoringTargetCard
                key={target.monitoringCode}
                target={target}
              />
            ))}
          </div>
        )}
      </div>

      {measurements.length > 0 && (
        <div className="card">
          <header className="card-header">
            <div>
              <h2>Latest Measurements</h2>
              <p className="muted small">
                Numeric observations captured during this encounter.
              </p>
            </div>

            <span className="muted small">
              {measurements.length} observation
              {measurements.length === 1 ? '' : 's'}
            </span>
          </header>

          <div className="results">
            {measurements.map((fact) => (
              <MeasurementRow key={fact.id} fact={fact} />
            ))}
          </div>
        </div>
      )}
    </section>
  );
}

function MonitoringTargetCard({
  target,
}: {
  target: MonitoringTarget;
}) {
  const hasCurrentValue = target.currentValue != null;
  const hasEscalation = Boolean(
    target.alert || target.escalationInstruction,
  );

  return (
    <article
      className={`mon-target ${target.alert ? 'mon-alert' : ''}`}
      aria-label={target.name}
    >
      <div className="mon-head">
        <div className="mon-title">
          <span className="mon-name">{target.name}</span>

          {target.unit && (
            <span className="muted small">{target.unit}</span>
          )}
        </div>

        {target.alert && (
          <span className="tag tag-danger" role="status">
            Alert
          </span>
        )}
      </div>

      {hasCurrentValue ? (
        <div className="mon-value">
          {target.currentValue}
          {target.unit ? (
            <span className="muted small mon-value-unit">
              {' '}
              {target.unit}
            </span>
          ) : null}
        </div>
      ) : (
        <div className="muted small">No current value recorded</div>
      )}

      <div className="mon-meta">
        {target.frequency && (
          <div className="mon-meta-row">
            <span className="muted small">Frequency</span>
            <span className="small">Every {target.frequency}</span>
          </div>
        )}

        {target.deteriorationRule && (
          <div className="mon-meta-row">
            <span className="muted small">Deterioration</span>
            <span className="small">{target.deteriorationRule}</span>
          </div>
        )}
      </div>

      {hasEscalation && (
        <div className="mon-escalation">
          {target.alert && (
            <div className="mon-escalation-title">
              {target.alert}
            </div>
          )}

          {target.escalationInstruction && (
            <div className="muted small">
              {target.escalationInstruction}
            </div>
          )}
        </div>
      )}

      <div className="muted small mono">
        {target.monitoringCode}
      </div>
    </article>
  );
}

function MeasurementRow({
  fact,
}: {
  fact: ClinicalRuntimeProjection['capturedFacts'][number];
}) {
  const values = (fact.values ?? [])
    .filter((value) => value.numeric != null)
    .map((value) => {
      const numeric = String(value.numeric);
      return value.unitCode ? `${numeric} ${value.unitCode}` : numeric;
    });

  return (
    <div className="result-row">
      <div className="result-fact">
        <span className="mono">{fact.factCode}</span>
      </div>

      <div className="result-value">
        {values.length > 0 ? values.join(' / ') : '—'}
      </div>

      <div className="result-source">
        Captured
      </div>
    </div>
  );
}