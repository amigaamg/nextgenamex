import type { CSSProperties, ReactNode } from 'react';
import type { ClinicalRuntimeProjection } from '../../types';

interface ConfigurationPanelProps {
  projection: ClinicalRuntimeProjection;
}

type Override = ClinicalRuntimeProjection['configuration']['overrides'][number];

const TARGET_LABELS: Record<string, string> = {
  FACILITY: 'Facility',
  DEPARTMENT: 'Department',
  CLINICIAN: 'Clinician',
  ORGANIZATION: 'Organization',
  SERVICE: 'Service',
  ROLE: 'Role',
};

export function ConfigurationPanel({
  projection,
}: ConfigurationPanelProps) {
  const overrides = projection.configuration?.overrides ?? [];

  return (
    <section
      className="configuration-panel stack"
      aria-label="Clinical configuration"
    >
      <section className="card">
        <header className="card-header configuration-header">
          <div>
            <span className="eyebrow">AMEXAN Clinical Runtime</span>
            <h2>Clinical Configuration</h2>
            <p className="muted small">
              Resolved clinical knowledge, facility configuration, and
              contextual overrides currently governing this encounter.
            </p>
          </div>

          <span className="status-pill status-active">
            {overrides.length} override{overrides.length === 1 ? '' : 's'}
          </span>
        </header>

        <ConfigurationHierarchy />

        <section className="configuration-overrides">
          <header className="subsection-header">
            <div>
              <h3>Resolved Overrides</h3>
              <p className="muted small">
                The local configuration layers resolved above the AMEXAN
                canonical knowledge baseline.
              </p>
            </div>
          </header>

          {overrides.length === 0 ? (
            <EmptyOverrides />
          ) : (
            <div className="override-list">
              {overrides.map((override) => (
                <ConfigurationOverride
                  key={override.overrideCode}
                  override={override}
                />
              ))}
            </div>
          )}
        </section>
      </section>
    </section>
  );
}

/**
 * Configuration resolution model:
 *
 * AMEXAN DEFAULT
 *      ↓
 * ORGANIZATION
 *      ↓
 * FACILITY
 *      ↓
 * DEPARTMENT
 *      ↓
 * SERVICE
 *      ↓
 * ROLE
 *      ↓
 * CLINICIAN
 *
 * The UI represents the hierarchy; the runtime remains the authority
 * for the actual resolved configuration.
 */
function ConfigurationHierarchy() {
  const nodes = [
    {
      level: 0,
      label: 'AMEXAN DEFAULT',
      description: 'Canonical clinical knowledge baseline',
      className: 'config-default',
    },
    {
      level: 1,
      label: 'Organization Configuration',
      description: 'Organization-wide governance and operational configuration',
    },
    {
      level: 2,
      label: 'Facility Configuration',
      description: 'Facility-specific clinical and operational configuration',
    },
    {
      level: 3,
      label: 'Department Configuration',
      description: 'Department-specific configuration and workflows',
    },
    {
      level: 4,
      label: 'Service Configuration',
      description: 'Service-level protocols, workflows, and availability',
    },
    {
      level: 5,
      label: 'Role Configuration',
      description: 'Role-specific permissions and clinical behavior',
    },
    {
      level: 6,
      label: 'Clinician Configuration',
      description: 'Clinician-specific preferences and permitted local rules',
    },
  ];

  return (
    <section className="configuration-hierarchy">
      <header className="subsection-header">
        <div>
          <h3>Configuration Hierarchy</h3>
          <p className="muted small">
            Canonical AMEXAN knowledge remains the baseline while authorized
            local layers provide contextual configuration.
          </p>
        </div>
      </header>

      <div
        className="config-tree"
        aria-label="AMEXAN clinical configuration hierarchy"
      >
        {nodes.map((node) => (
          <HierarchyNode
            key={node.label}
            level={node.level}
            label={node.label}
            description={node.description}
            className={node.className}
          />
        ))}
      </div>
    </section>
  );
}

function HierarchyNode({
  level,
  label,
  description,
  className = '',
}: {
  level: number;
  label: string;
  description: string;
  className?: string;
}) {
  const style = {
    '--config-level': level,
  } as CSSProperties;

  return (
    <div className={`config-node ${className}`.trim()} style={style}>
      <span className="config-node-marker" aria-hidden="true">
        {level === 0 ? '◆' : '↳'}
      </span>

      <div className="config-node-content">
        <strong>{label}</strong>
        <span className="muted small">{description}</span>
      </div>

      {level === 0 && (
        <span className="tag tag-primary">Canonical</span>
      )}
    </div>
  );
}

function EmptyOverrides() {
  return (
    <div className="config-empty card-soft">
      <span
        className="config-empty-icon"
        aria-hidden="true"
      >
        ✓
      </span>

      <div>
        <strong>AMEXAN DEFAULT is currently active</strong>
        <p className="muted small">
          No local configuration overrides currently resolve for this
          clinical runtime.
        </p>
      </div>
    </div>
  );
}

function ConfigurationOverride({
  override,
}: {
  override: Override;
}) {
  const targetType = String(override.targetType ?? '').toUpperCase();

  const targetLabel =
    TARGET_LABELS[targetType] ??
    formatLabel(targetType || 'Unknown');

  return (
    <article className="config-override card-soft">
      <header className="config-override-head">
        <div className="config-override-title">
          <span className="mono">
            {override.overrideCode}
          </span>

          <span className="tag">
            {targetLabel}
          </span>
        </div>

        <div className="config-version">
          <span className="muted small">
            Scope:{' '}
            <strong className="mono">
              {override.scopeCode}
            </strong>
          </span>

          <span className="muted small">
            Version{' '}
            <strong>
              v{override.version}
            </strong>
          </span>
        </div>
      </header>

      <div className="config-override-grid">
        <ConfigValue
          label="Target"
          value={override.targetCode}
        />

        <ConfigValue
          label="Target type"
          value={targetLabel}
        />

        <ConfigValue
          label="Scope"
          value={override.scopeCode}
        />

        <ConfigValue
          label="Version"
          value={`v${override.version}`}
        />
      </div>

      <div className="config-rationale">
        <span className="muted small">Rationale</span>

        <p>
          {override.reason?.trim() ||
            'No rationale recorded.'}
        </p>
      </div>

      <ConfigurationPayload config={override.config} />
    </article>
  );
}

function ConfigValue({
  label,
  value,
}: {
  label: string;
  value: ReactNode;
}) {
  return (
    <div className="config-value">
      <span className="muted small">{label}</span>

      <strong className="mono small">
        {value}
      </strong>
    </div>
  );
}

function ConfigurationPayload({
  config,
}: {
  config: unknown;
}) {
  const serialized = safeJson(config);

  return (
    <details className="config-payload">
      <summary>
        <span>Configuration payload</span>
        <span className="muted small mono">
          JSON
        </span>
      </summary>

      <pre className="config-json mono small">
        {serialized}
      </pre>
    </details>
  );
}

function safeJson(value: unknown): string {
  if (value === undefined) {
    return 'undefined';
  }

  if (value === null) {
    return 'null';
  }

  try {
    const serialized = JSON.stringify(
      value,
      null,
      2,
    );

    return serialized ?? String(value);
  } catch {
    return String(value);
  }
}

function formatLabel(value: string): string {
  return value
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase()
    .replace(/\b\w/g, (character) =>
      character.toUpperCase(),
    );
}