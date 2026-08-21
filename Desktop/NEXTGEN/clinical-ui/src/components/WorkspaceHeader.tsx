import { useState, type ReactNode } from 'react';
import type { ClinicalFormatPlan, ConnectionState } from '../types';
import {
  CrossIcon,
  StethoscopeIcon,
  ScissorsIcon,
  BabyIcon,
  BottleIcon,
  VenusIcon,
  BrainIcon,
  FileIcon,
} from './Icons';
import { DocumentPreview } from './Documentation/DocumentPreview';

const FORMAT_META: Record<
  string,
  {
    label: string;
    icon: ReactNode;
  }
> = {
  ADULT_MEDICAL: {
    label: 'Adult Medicine',
    icon: <StethoscopeIcon size={16} />,
  },
  ADULT_SURGICAL: {
    label: 'Adult Surgery',
    icon: <ScissorsIcon size={16} />,
  },
  PEDIATRIC: {
    label: 'Pediatrics',
    icon: <BabyIcon size={16} />,
  },
  NEONATAL: {
    label: 'Neonatal',
    icon: <BottleIcon size={16} />,
  },
  OBGYN: {
    label: 'Obstetrics & Gynaecology',
    icon: <VenusIcon size={16} />,
  },
  PSYCHIATRY: {
    label: 'Psychiatry',
    icon: <BrainIcon size={16} />,
  },
};

function formatIdentifier(value: string, prefix: string, length: number): string {
  return `${prefix}-${value.slice(0, length).toUpperCase()}`;
}

function buildContextChips(format: ClinicalFormatPlan): string[] {
  const chips: string[] = [];

  if (format.ageBand) chips.push(format.ageBand);
  if (format.sex) chips.push(format.sex);
  if (format.pregnant) chips.push('Pregnant');
  if (format.department) chips.push(format.department);

  return [...new Set(chips)];
}

function getConnectionLabel(connection: ConnectionState): string {
  switch (connection) {
    case 'online':
      return 'Live';
    case 'syncing':
      return 'Syncing';
    default:
      return 'Offline';
  }
}

function getConnectionClass(connection: ConnectionState): string {
  switch (connection) {
    case 'online':
      return 'dot-online';
    case 'syncing':
      return 'dot-syncing';
    default:
      return 'dot-offline';
  }
}

export function WorkspaceHeader({
  connection,
  patientId,
  encounterId,
  alertCount = 0,
  formatPlan = null,
}: {
  connection: ConnectionState;
  patientId: string | null;
  encounterId: string | null;
  alertCount?: number;
  formatPlan?: ClinicalFormatPlan | null;
}) {
  const formatMeta = formatPlan
    ? FORMAT_META[formatPlan.baseFormat]
    : null;

  const contextChips = formatPlan
    ? buildContextChips(formatPlan)
    : [];

  const hasEncounterContext = Boolean(patientId && encounterId);
  const connectionLabel = getConnectionLabel(connection);
  const connectionClass = getConnectionClass(connection);
  const [previewOpen, setPreviewOpen] = useState(false);

  return (
    <header className="workspace-header">
      <div className="header-left">
        <div className="header-brand" aria-label="AMEXAN Clinical Operating System">
          <span className="brand-mark" aria-hidden="true">
            <CrossIcon size={20} />
          </span>

          <div className="brand-copy">
            <span className="brand-text">AMEXAN</span>
            <span className="brand-subtitle">
              Clinical Operating System
            </span>
          </div>
        </div>
      </div>

      <div className="header-center">
        {hasEncounterContext && (
          <div className="header-patient" aria-label="Current encounter">
            <span
              className="muted mono"
              title={`Patient ID: ${patientId}`}
            >
              PT-{patientId!.slice(0, 8).toUpperCase()}
            </span>

            <span className="header-separator" aria-hidden="true">
              /
            </span>

            <span
              className="muted mono"
              title={`Encounter ID: ${encounterId}`}
            >
              {formatIdentifier(encounterId!, 'ENC', 6)}
            </span>
          </div>
        )}

        {formatPlan && formatMeta && (
          <div
            className="header-format-badge"
            aria-label={`Clinical format: ${formatMeta.label}`}
          >
            <span
              className="format-emoji"
              aria-hidden="true"
            >
              {formatMeta.icon}
            </span>
            <span className="format-label">
              {formatMeta.label}
            </span>

            {contextChips.length > 0 && (
              <div className="header-context-chips">
                {contextChips.map((chip) => (
                  <span
                    key={chip}
                    className="context-chip"
                  >
                    {chip}
                  </span>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      <div className="header-right">
        {alertCount > 0 && (
          <span
            className="header-alert-badge"
            role="status"
            aria-label={`${alertCount} active clinical alert${
              alertCount === 1 ? '' : 's'
            }`}
            title={`${alertCount} active clinical alert${
              alertCount === 1 ? '' : 's'
            }`}
          >
            {alertCount}
          </span>
        )}

        <span
          className={`sync-state ${connectionClass}`}
          role="status"
          aria-live="polite"
          title={`Realtime connection: ${connection}`}
        >
          <span
            className="sync-dot"
            aria-hidden="true"
          />
          {connectionLabel}
        </span>

        {hasEncounterContext && (
          <button
            type="button"
            className="btn btn-tertiary btn-small"
            title="Preview and export current encounter documentation as PDF"
            aria-label="Preview encounter documentation as PDF"
            onClick={() => setPreviewOpen(true)}
          >
            <span aria-hidden="true">
              <FileIcon size={15} />
            </span>
            PDF
          </button>
        )}
      </div>

      {previewOpen && patientId && encounterId && (
        <DocumentPreview
          patientId={patientId}
          encounterId={encounterId}
          onClose={() => setPreviewOpen(false)}
        />
      )}
    </header>
  );
}