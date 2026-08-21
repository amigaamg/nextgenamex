import type { EnhancedClinicalRuntimeProjection } from '../../types';

interface EncounterCommandStripProps {
  projection: EnhancedClinicalRuntimeProjection;
}

const FORMAT_LABELS: Record<string, string> = {
  ADULT_MEDICAL: 'Adult Medicine',
  ADULT_SURGICAL: 'Adult Surgery',
  PEDIATRIC: 'Pediatrics',
  OBGYN: 'OBGYN',
  PSYCHIATRY: 'Psychiatry',
  NEONATAL: 'Neonatal',
};

type EncounterStatus = {
  label: string;
  className: string;
};

export function EncounterCommandStrip({
  projection,
}: EncounterCommandStripProps) {
  if (!projection) {
    return null;
  }

  const formatPlan = projection.formatPlan;
  const alerts = projection.alerts ?? [];
  const facts = projection.capturedFacts ?? [];
  const phenotypes = projection.phenotypes ?? [];
  const differentials = projection.differentials ?? [];
  const activeSymptoms = projection.activeSymptoms ?? [];
  const activeDomains = formatPlan?.activeDomains ?? [];

  const status = getEncounterStatus(projection);

  return (
    <section
      className="encounter-command-strip"
      aria-label="Encounter command status"
    >
      <div className="command-primary">
        <div className="command-patient">
          <div className="command-patient-main">
            <span className="patient-name">
              Active Encounter
            </span>

            {activeSymptoms.length > 0 && (
              <span className="patient-complaint">
                {activeSymptoms.join(' · ')}
              </span>
            )}
          </div>

          <span
            className={`patient-status ${status.className}`}
            role="status"
          >
            <span aria-hidden="true">●</span>
            {status.label}
          </span>
        </div>

        <div className="command-stats" aria-label="Encounter state">
          <CommandStat label="Facts" value={facts.length} />
          <CommandStat
            label="Phenotypes"
            value={phenotypes.length}
          />
          <CommandStat
            label="Differentials"
            value={differentials.length}
          />
          <CommandStat
            label="Alerts"
            value={alerts.length}
            active={alerts.length > 0}
          />
        </div>
      </div>

      {(formatPlan || activeDomains.length > 0) && (
        <div className="command-context">
          {formatPlan && (
            <div className="command-context-group">
              <span className="action-label">Clinical format</span>

              <span
                className={`format-badge ${getFormatClass(
                  formatPlan.baseFormat,
                )}`}
              >
                {getFormatLabel(formatPlan.baseFormat)}
              </span>

              {formatPlan.ageBand && (
                <ContextValue value={formatPlan.ageBand} />
              )}

              {formatPlan.sex && (
                <ContextValue value={formatPlan.sex} />
              )}

              {formatPlan.gestationalAge && (
                <ContextValue
                  value={formatPlan.gestationalAge}
                />
              )}

              {formatPlan.department && (
                <ContextValue
                  value={formatPlan.department}
                />
              )}

              {formatPlan.pregnant === true && (
                <ContextValue value="Pregnant" />
              )}
            </div>
          )}

          {activeDomains.length > 0 && (
            <div className="command-context-group command-domains">
              <span className="action-label">Active domains</span>

              <div className="command-domain-list">
                {activeDomains.map((domain) => (
                  <span
                    key={domain}
                    className="badge badge-soft"
                  >
                    {formatDomainLabel(domain)}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </section>
  );
}

function CommandStat({
  label,
  value,
  active = false,
}: {
  label: string;
  value: number;
  active?: boolean;
}) {
  return (
    <div className={`stat-item ${active ? 'stat-alerts' : ''}`}>
      <span className="stat-label">{label}</span>

      <span
        className={`stat-value ${
          active ? 'stat-alert-active' : ''
        }`}
      >
        {value}
      </span>
    </div>
  );
}

function ContextValue({
  value,
}: {
  value: string;
}) {
  return (
    <span className="context-value">
      <span aria-hidden="true">•</span>
      {value}
    </span>
  );
}

function getEncounterStatus(
  projection: EnhancedClinicalRuntimeProjection,
): EncounterStatus {
  const alerts = projection.alerts ?? [];

  if (alerts.some((alert) => alert.level === 'emergency')) {
    return {
      label: 'Critical',
      className: 'status-critical',
    };
  }

  if (alerts.some((alert) => alert.level === 'urgent')) {
    return {
      label: 'Unstable',
      className: 'status-unstable',
    };
  }

  if (projection.protocol) {
    return {
      label: 'Protocol Active',
      className: 'status-protocol',
    };
  }

  return {
    label: 'Stable',
    className: 'status-stable',
  };
}

function getFormatLabel(format?: string | null): string {
  if (!format) {
    return 'Clinical';
  }

  return FORMAT_LABELS[format] ?? format
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function getFormatClass(format?: string | null): string {
  return (format ?? 'clinical')
    .toLowerCase()
    .replace(/_/g, '-');
}

function formatDomainLabel(domain: string): string {
  return domain
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}