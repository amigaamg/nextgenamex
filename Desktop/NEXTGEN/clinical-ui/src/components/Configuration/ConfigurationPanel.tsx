import type { ClinicalRuntimeProjection } from '../../types';

export function ConfigurationPanel({ projection }: { projection: ClinicalRuntimeProjection }) {
  const overrides = projection.configuration.overrides;
  return (
    <div className="stack">
      <section className="card">
        <header className="card-header">
          <h2>Clinical configuration</h2>
          <span className="muted small">baseline + override + version + reason (3.19 / 4.32)</span>
        </header>
        <p className="muted small">
          The AMEXAN DEFAULT is the knowledge baseline. Facilities, departments and clinicians express local overrides that layer on top without mutating the original knowledge.
        </p>
        <div className="config-tree">
          <div className="config-node config-default">AMEXAN DEFAULT</div>
          <div className="config-node">↳ Facility configuration</div>
          <div className="config-node">↳ Department</div>
          <div className="config-node">↳ Clinician</div>
        </div>
        {overrides.length === 0 && <p className="muted">No local overrides currently resolve — AMEXAN default applies.</p>}
        {overrides.map((o) => (
          <div key={o.overrideCode} className="config-override card-soft">
            <div className="config-override-head">
              <span className="mono">{o.overrideCode}</span>
              <span className="tag">{o.targetType}</span>
              <span className="muted small">
                {o.scopeCode} · v{o.version}
              </span>
            </div>
            <div className="muted small">target: {o.targetCode}</div>
            <div>{o.reason ?? 'no rationale recorded'}</div>
            <pre className="config-json mono small">{JSON.stringify(o.config, null, 2)}</pre>
          </div>
        ))}
      </section>
    </div>
  );
}
