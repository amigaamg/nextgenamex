import type { ClinicalRuntimeProjection } from '../../types';
import { nicer } from '../../types';

export function PatientSnapshot({ projection }: { projection: ClinicalRuntimeProjection }) {
  const symptoms = projection.activeSymptoms.map((s) => nicer(s));
  const alerts = projection.alerts.map((a) => a.level);
  const top = projection.alerts[0];

  return (
    <section className="patient-snapshot" aria-label="Patient snapshot">
      <div className="snapshot-identity">
        <div className="avatar">PT</div>
        <div>
          <div className="snapshot-name">Demo patient</div>
          <div className="muted small">encounter {projection.encounterId?.slice(0, 13) ?? '—'}</div>
        </div>
      </div>

      <div className="snapshot-symptoms">
        {symptoms.length === 0 && <span className="chip">No symptoms yet</span>}
        {symptoms.map((s) => (
          <span key={s} className="chip chip-symptom">
            {s}
          </span>
        ))}
      </div>

      <div className="snapshot-dx">
        {projection.confidence.workingDiagnosis ? (
          <>
            <span className="muted small">Working diagnosis</span>
            <div className="dx-name">{projection.confidence.workingDiagnosis}</div>
          </>
        ) : (
          <>
            <span className="muted small">Differentials</span>
            <div className="dx-name">{projection.differentials.length}</div>
          </>
        )}
      </div>

      <div className="snapshot-safety">
        <span className="muted small">Facts {projection.capturedFacts.length}</span>
        <span className="muted small">Phenotype score {projection.confidence.leadingPhenotypeScore}</span>
      </div>

      <div className="snapshot-safety">
        {alerts.length === 0 ? (
          <span className="muted small">No active alerts</span>
        ) : (
          <span className={top && top.level === 'urgent' ? 'mon-alert' : 'muted small'}>
            {alerts.length} alert{alerts.length > 1 ? 's' : ''} active
          </span>
        )}
      </div>
    </section>
  );
}