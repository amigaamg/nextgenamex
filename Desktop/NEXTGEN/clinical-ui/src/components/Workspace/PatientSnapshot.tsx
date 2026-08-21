import type { EnhancedClinicalRuntimeProjection, ClinicalUIState } from '../../types';
import { nicer } from '../../types';
import {
  StethoscopeIcon,
  ScissorsIcon,
  BabyIcon,
  VenusIcon,
  BrainIcon,
  BottleIcon,
  ClipboardIcon,
} from '../Icons';
import type { ReactNode } from 'react';

interface PatientSnapshotProps {
  projection: EnhancedClinicalRuntimeProjection;
  uiState: ClinicalUIState | null;
}

const FORMAT_ICONS: Record<string, ReactNode> = {
  ADULT_MEDICAL: <StethoscopeIcon size={18} />,
  ADULT_SURGICAL: <ScissorsIcon size={18} />,
  PEDIATRIC: <BabyIcon size={18} />,
  OBGYN: <VenusIcon size={18} />,
  PSYCHIATRY: <BrainIcon size={18} />,
  NEONATAL: <BottleIcon size={18} />,
};

const FORMAT_LABELS: Record<string, string> = {
  ADULT_MEDICAL: 'Adult Medical',
  ADULT_SURGICAL: 'Adult Surgical',
  PEDIATRIC: 'Paediatrics',
  OBGYN: 'Obstetrics & Gynaecology',
  PSYCHIATRY: 'Psychiatry',
  NEONATAL: 'Neonatology',
};

function formatLabel(baseFormat: string): string {
  return (
    FORMAT_LABELS[baseFormat] ??
    baseFormat
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase())
  );
}

export function PatientSnapshot({ projection, uiState }: PatientSnapshotProps) {
  const symptoms = projection.activeSymptoms.map(nicer);
  const alerts = projection.alerts ?? [];
  const topAlert = alerts[0];
  const formatPlan = projection.formatPlan;

  const alertCount = alerts.length;
  const factCount = projection.capturedFacts?.length ?? 0;
  const differentialCount = projection.differentials?.length ?? 0;
  const phenotypeScore = projection.confidence?.leadingPhenotypeScore;

  const connectionState = uiState?.task?.priority;

  const hasUrgentAlert = alerts.some(
    (alert) => alert.level === 'urgent' || alert.level === 'emergency',
  );

  const encounterLabel = projection.encounterId
    ? projection.encounterId.slice(0, 13)
    : '—';

  const patientName = projection.capturedFacts?.find(
    (fact) => fact.factCode === 'PATIENT_NAME',
  )?.values?.[0]?.text;

  const mrn = projection.capturedFacts?.find(
    (fact) => fact.factCode === 'MRN',
  )?.values?.[0]?.text;

  return (
    <section
      className="patient-snapshot"
      aria-label="Patient clinical snapshot"
    >
      <div className="snapshot-identity">
        <div className="avatar" aria-hidden="true">
          PT
        </div>

        <div>
          <div className="snapshot-name">
            {patientName || projection.patientId || 'Patient'}
          </div>

          <div className="muted small">
            {mrn ? `${mrn} • ` : ''}
            Encounter {encounterLabel}
          </div>
        </div>
      </div>

      <div className="snapshot-symptoms">
        {symptoms.length === 0 ? (
          <span className="chip">No active symptoms</span>
        ) : (
          symptoms.map((symptom) => (
            <span
              key={symptom}
              className="chip chip-symptom"
            >
              {symptom}
            </span>
          ))
        )}
      </div>

      <div className="snapshot-dx">
        {projection.confidence?.workingDiagnosis ? (
          <>
            <span className="muted small">
              Working diagnosis
            </span>

            <div className="dx-name">
              {projection.confidence.workingDiagnosis}
            </div>
          </>
        ) : (
          <>
            <span className="muted small">
              Active differentials
            </span>

            <div className="dx-name">
              {differentialCount}
            </div>
          </>
        )}
      </div>

      <div className="snapshot-safety">
        <span className="muted small">
          Facts {factCount}
        </span>

        {phenotypeScore !== undefined && (
          <span className="muted small">
            Phenotype score {phenotypeScore}
          </span>
        )}

        {connectionState && (
          <span className={`connection-badge connection-${connectionState}`}>
            {connectionState}
          </span>
        )}
      </div>

      <div className="snapshot-safety">
        {alertCount === 0 ? (
          <span className="muted small">
            No active alerts
          </span>
        ) : (
          <span
            className={
              hasUrgentAlert
                ? 'mon-alert'
                : 'muted small'
            }
            role="status"
            aria-label={`${alertCount} active clinical alert${
              alertCount === 1 ? '' : 's'
            }`}
          >
            {alertCount} active alert
            {alertCount === 1 ? '' : 's'}
            {topAlert?.level && (
              <span className="muted small">
                {' '}
                · {topAlert.level}
              </span>
            )}
          </span>
        )}
      </div>

      {formatPlan && (
        <div
          className="format-context-banner"
          aria-label="Clinical format context"
        >
          <span
            className="format-icon"
            aria-hidden="true"
          >
            {FORMAT_ICONS[formatPlan.baseFormat] ?? <ClipboardIcon size={18} />}
          </span>

          <span className="format-details">
            <strong>{formatLabel(formatPlan.baseFormat)}</strong>

            {formatPlan.ageBand && (
              <span> • {formatPlan.ageBand}</span>
            )}

            {formatPlan.sex && (
              <span> • {formatPlan.sex}</span>
            )}

            {formatPlan.pregnant && (
              <span> • Pregnant</span>
            )}

            {formatPlan.gestationalAge && (
              <span> • {formatPlan.gestationalAge}</span>
            )}

            {formatPlan.department && (
              <span> • {formatPlan.department}</span>
            )}
          </span>
        </div>
      )}
    </section>
  );
}