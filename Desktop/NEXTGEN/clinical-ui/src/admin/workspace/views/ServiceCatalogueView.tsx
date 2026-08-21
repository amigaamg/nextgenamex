// =============================================================================
// AMEXAN Service Catalogues — Facility operational service registry
//
// OPERATE / IMPROVE. Read-only Control Plane projection.
//
// Responsibilities
// -----------------------------------------------------------------------------
// • Catalogue health — is the catalogue actually usable?
// • Catalogue integrity — which services are fully configured?
// • Facility service registry — every service carries its operational
//   definition (department · location · workforce · workflow · capacity ·
//   pricing · reporting · integrations).
// • Service ≠ department — a department is an organizational unit; a service
//   is an operational capability (many-to-many). The responsible department
//   is a reference, never the service's identity.
// • Service status — operational / limited / suspended / planned / archived
//   flows into Clinical Operations, Referrals, Radiology, Workforce,
//   Financial and Intelligence.
// • Workflow definitions — each node carries its required role, inputs and
//   outputs, so the catalogue is the configuration source for workflow
//   execution rather than a static description.
// • Reporting mappings — AMEXAN service → national reporting / payer / FHIR
//   representations. Mappings change without mutating the service definition.
// • Configuration attention + governed changes (approval requirements).
//
// PRINCIPLES
// -----------------------------------------------------------------------------
// • Read-only administration projection (browser never touches PostgreSQL).
// • All data comes from the AMEXAN Control Plane API.
// • Polling is the realtime transport fallback.
// =============================================================================

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { getServiceCatalogue } from '../api';

import type {
  CatalogueAttentionItem,
  CatalogueCategory,
  CatalogueServiceEntry,
  CatalogueServiceState,
  ServiceCatalogueOverview,
} from '../types';

// =============================================================================
// TYPES
// =============================================================================

type CategoryFilter = 'ALL' | CatalogueCategory;

interface QuickAction {
  id: string;
  label: string;
  description: string;
}

// =============================================================================
// CONSTANTS
// =============================================================================

const REFRESH_INTERVAL = 30_000;

const CATEGORY_ORDER: CatalogueCategory[] = [
  'CLINICAL',
  'DIAGNOSTICS',
  'SUPPORT',
];

const CATEGORY_FILTERS: {
  value: CategoryFilter;
  label: string;
}[] = [
  { value: 'ALL', label: 'All' },
  { value: 'CLINICAL', label: 'Clinical' },
  { value: 'DIAGNOSTICS', label: 'Diagnostics' },
  { value: 'SUPPORT', label: 'Support / Allied' },
];

const QUICK_ACTIONS: QuickAction[] = [
  {
    id: 'add-service',
    label: '+ Add service',
    description: 'Create a new operational service definition',
  },
  {
    id: 'workflows',
    label: 'Manage workflows',
    description: 'Configure workflow nodes, roles, inputs and outputs',
  },
  {
    id: 'pricing',
    label: 'Manage pricing',
    description: 'Maintain tariff versions and payer rules',
  },
  {
    id: 'mappings',
    label: 'Manage mappings',
    description: 'Reporting and interoperability representations',
  },
  {
    id: 'capacity',
    label: 'Manage capacity',
    description: 'Configured daily capacity and pressure thresholds',
  },
  {
    id: 'locations',
    label: 'Manage locations',
    description: 'Buildings, floors, zones, rooms and queues',
  },
];

const STATUS_CLASS: Record<CatalogueServiceState, string> = {
  operational: 'ok',
  limited: 'warn',
  suspended: 'bad',
  planned: 'idle',
  archived: 'idle',
};

const STATUS_LABEL: Record<CatalogueServiceState, string> = {
  operational: 'Operational',
  limited: 'Limited',
  suspended: 'Suspended',
  planned: 'Planned',
  archived: 'Archived',
};

const PRESSURE_CLASS: Record<string, string> = {
  LOW: 'ok',
  MEDIUM: 'warn',
  HIGH: 'bad',
};

// =============================================================================
// HELPERS
// =============================================================================

function formatDate(value: string | null | undefined): string {
  if (!value) return '—';

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return '—';

  return date.toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function formatRelative(value: string | null | undefined): string {
  if (!value) return '';

  const timestamp = new Date(value).getTime();

  if (Number.isNaN(timestamp)) return '';

  const diff = Date.now() - timestamp;

  if (diff < 60_000) return 'just now';

  const minutes = Math.floor(diff / 60_000);

  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);

  if (hours < 24) return `${hours}h ago`;

  return `${Math.floor(hours / 24)}d ago`;
}

// =============================================================================
// SMALL BUILDING BLOCKS
// =============================================================================

function SectionTitle({
  kicker,
  title,
  subtitle,
}: {
  kicker?: string;
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="admin-panel-head">
      <div>
        {kicker && (
          <span className="admin-panel-sub" style={{ display: 'block' }}>
            {kicker}
          </span>
        )}

        <span className="admin-panel-title" style={{ marginTop: 2 }}>
          {title}
        </span>

        {subtitle && (
          <span className="admin-panel-sub" style={{ display: 'block', marginTop: 2 }}>
            {subtitle}
          </span>
        )}
      </div>
    </div>
  );
}

function ProgressBar({
  value,
  tone,
}: {
  value: number;
  tone?: 'warn' | 'bad';
}) {
  const clamped = Math.max(0, Math.min(100, value));

  return (
    <div className="sc-progress" aria-hidden="true">
      <div
        className={`sc-progress-fill${tone ? ` ${tone}` : ''}`}
        style={{ width: `${clamped}%` }}
      />
    </div>
  );
}

function StatusBadge({
  state,
  reason,
}: {
  state: CatalogueServiceState;
  reason?: string | null;
}) {
  return (
    <span
      className={`admin-badge ${STATUS_CLASS[state]}`}
      title={reason ?? STATUS_LABEL[state]}
    >
      {STATUS_LABEL[state]}
    </span>
  );
}

function PressureBadge({ pressure }: { pressure: string }) {
  return (
    <span className={`admin-badge ${PRESSURE_CLASS[pressure] ?? ''}`}>
      {pressure === 'HIGH' ? '🔴' : pressure === 'MEDIUM' ? '🟠' : '🟢'} {pressure} pressure
    </span>
  );
}

// =============================================================================
// SERVICE CARD
// =============================================================================

function ServiceCard({
  entry,
  onOpen,
}: {
  entry: CatalogueServiceEntry;
  onOpen: (entry: CatalogueServiceEntry) => void;
}) {
  return (
    <button
      type="button"
      className="sc-card"
      onClick={() => onOpen(entry)}
      title={`Open ${entry.name}`}
    >
      <div className="sc-card-head">
        <div>
          <span className="sc-card-code">{entry.code}</span>

          <span className="sc-card-name">{entry.name}</span>
        </div>

        <StatusBadge state={entry.status.state} reason={entry.status.reason} />
      </div>

      <div className="sc-card-meta">
        <span>📍 {entry.location.label}</span>

        <span>Unit · {entry.units.offering}</span>

        <span className="mono">
          {entry.workflow.summary}
        </span>
      </div>

      <div className="sc-card-kv">
        <span className="k">Workforce</span>

        <span className="v">
          {entry.workforce.requiredCapacity} required capacity
          {' · '}
          {entry.workforce.coveragePercent}% coverage
        </span>

        <span className="k">Pricing</span>

        <span className="v">
          {entry.pricing.status === 'configured' ? 'Configured' : 'Missing'}
        </span>

        <span className="k">Reporting</span>

        <span className="v mono">
          {entry.reporting.classification}
        </span>

        <span className="k">Pressure</span>

        <span className="v">
          {entry.capacity.current} / {entry.capacity.demand}
        </span>
      </div>

      <div className="sc-card-foot">
        {entry.attention && (
          <span className="sc-card-flag warn">
            ⚠ {entry.attention}
          </span>
        )}

        {!entry.attention && (
          <span className="sc-card-flag ok">Fully configured</span>
        )}

        <span className="sc-card-open">Open service →</span>
      </div>
    </button>
  );
}

// =============================================================================
// DETAIL VIEW
// =============================================================================

function CoverageBar({ percent }: { percent: number }) {
  return (
    <div className="sc-coverage">
      <ProgressBar value={percent} />
      <span className="mono">{percent}%</span>
    </div>
  );
}

function WorkflowRail({ nodes }: { nodes: CatalogueServiceEntry['workflow']['nodes'] }) {
  return (
    <div className="sc-workflow-rail">
      {nodes.map((node, index) => (
        <div key={node.name} className="sc-node">
          <div className="sc-node-main">
            <span className="sc-node-name">
              {index + 1}. {node.name}
            </span>

            <span className="admin-badge brand">{node.requiredRole}</span>
          </div>

          <div className="sc-node-io">
            <span className="io-label">Inputs</span>

            <span className="io-value">{node.inputs.join(' · ') || '—'}</span>
          </div>

          <div className="sc-node-io">
            <span className="io-label">Outputs</span>

            <span className="io-value">{node.outputs.join(' · ') || '—'}</span>
          </div>
        </div>
      ))}
    </div>
  );
}

function ServiceDetail({
  entry,
  onBack,
  onAction,
}: {
  entry: CatalogueServiceEntry;
  onBack: () => void;
  onAction: (label: string) => void;
}) {
  const isLimited =
    entry.status.state === 'limited' ||
    entry.status.state === 'suspended';

  const actionButtons: { id: string; label: string }[] = [
    { id: 'edit', label: 'Edit configuration' },
    { id: 'workflow', label: 'View workflow' },
    { id: 'staffing', label: 'View staffing' },
    { id: 'equipment', label: 'View equipment' },
    { id: 'pricing', label: 'View pricing' },
    { id: 'reporting', label: 'View reporting mapping' },
  ];

  return (
    <div className="admin-panel sc-detail">
      <div className="admin-panel-head">
        <div>
          <button
            type="button"
            className="sc-back"
            onClick={onBack}
          >
            ← Back to catalogue
          </button>

          <div className="sc-detail-title">
            <h2>{entry.name}</h2>

            <span className="sc-card-code">{entry.code}</span>

            <StatusBadge state={entry.status.state} reason={entry.status.reason} />
          </div>

          {isLimited && (
            <div className="sc-status-note">
              <strong>{entry.status.reason}</strong>

              {entry.status.expectedRecovery && (
                <span>
                  · Expected recovery: {entry.status.expectedRecovery}
                </span>
              )}
            </div>
          )}
        </div>

        <span className="admin-panel-sub">
          Current activity: {entry.activity.today} {entry.activity.unit} today
        </span>
      </div>

      <div className="sc-detail-grid">
        {/* Identity */}
        <div className="sc-section">
          <div className="sc-section-title">Identity</div>

          <div className="admin-kv">
            <span className="k">Service type</span>
            <span className="v">{entry.serviceType}</span>

            <span className="k">Department</span>
            <span className="v">{entry.department.name}</span>

            <span className="k">Location</span>
            <span className="v">{entry.location.label}</span>

            <span className="k">Offering</span>
            <span className="v">{entry.units.offering}</span>

            <span className="k">Billing unit</span>
            <span className="v">{entry.units.billingUnit}</span>

            <span className="k">Reporting unit</span>
            <span className="v">{entry.units.reportingUnit}</span>
          </div>
        </div>

        {/* Facility location */}
        <div className="sc-section">
          <div className="sc-section-title">Facility location</div>

          <div className="admin-kv">
            <span className="k">Building</span>
            <span className="v">{entry.location.building}</span>

            <span className="k">Floor</span>
            <span className="v">{entry.location.floor}</span>

            <span className="k">Zone</span>
            <span className="v">{entry.location.zone}</span>

            <span className="k">Rooms</span>
            <span className="v">{entry.location.rooms}</span>

            <span className="k">Queue</span>
            <span className="v mono">{entry.location.queue}</span>
          </div>
        </div>

        {/* Capacity */}
        <div className="sc-section">
          <div className="sc-section-title">Capacity</div>

          <div className="admin-kv">
            <span className="k">Rooms</span>
            <span className="v num">{entry.capacity.rooms}</span>

            <span className="k">Configured daily</span>
            <span className="v num">{entry.capacity.configuredDaily}</span>

            <span className="k">Current</span>
            <span className="v num">{entry.capacity.current}</span>

            <span className="k">Demand</span>
            <span className="v num">{entry.capacity.demand}</span>

            <span className="k">Pressure</span>
            <span className="v">
              <PressureBadge pressure={entry.capacity.pressure} />
            </span>
          </div>
        </div>

        {/* Workforce */}
        <div className="sc-section">
          <div className="sc-section-title">Workforce configuration</div>

          <div className="admin-kv">
            <span className="k">Required capacity</span>
            <span className="v num">{entry.workforce.requiredCapacity}</span>

            <span className="k">Currently assigned</span>
            <span className="v num">{entry.workforce.currentlyAssigned}</span>

            <span className="k">On duty</span>
            <span className="v num">{entry.workforce.onDuty}</span>

            <span className="k">Coverage</span>
            <span className="v">
              <CoverageBar percent={entry.workforce.coveragePercent} />
            </span>
          </div>

          {entry.workforce.roles.length > 0 && (
            <div className="sc-role-list">
              {entry.workforce.roles.map((role) => (
                <div key={role.role} className="sc-role">
                  <span>{role.role}</span>
                  <span className="num">{role.required}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Workflow */}
      <div className="sc-section">
        <div className="sc-section-title">
          Workflow
          {entry.workflow.configured ? (
            <span className="admin-badge ok">Configured</span>
          ) : (
            <span className="admin-badge warn">Not configured</span>
          )}
        </div>

        <div className="sc-workflow-summary mono">
          {entry.workflow.summary}
        </div>

        <WorkflowRail nodes={entry.workflow.nodes} />
      </div>

      {/* Equipment */}
      {entry.equipment.length > 0 && (
        <div className="sc-section">
          <div className="sc-section-title">Equipment</div>

          <div className="sc-equipment">
            {entry.equipment.map((asset) => (
              <div key={asset.name} className="sc-equipment-item">
                <div className="sc-equipment-head">
                  <strong>{asset.name}</strong>

                  <span className="admin-badge ok">{asset.status}</span>
                </div>

                <div className="admin-kv">
                  <span className="k">Utilization</span>
                  <span className="v num">{asset.utilization}%</span>

                  <span className="k">Maintenance</span>
                  <span className="v">Next due {formatDate(asset.maintenanceNextDue)}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Items / test catalogue / modalities */}
      {entry.items.length > 0 && (
        <div className="sc-section">
          <div className="sc-section-title">Service items / modalities</div>

          <div className="sc-chip-list">
            {entry.items.map((item) => (
              <span key={item.code} className="sc-chip" title={item.name}>
                <span className="mono">{item.code}</span>
                {item.name}
              </span>
            ))}
          </div>
        </div>
      )}

      <div className="sc-detail-grid">
        {/* Pricing */}
        <div className="sc-section">
          <div className="sc-section-title">
            Pricing
            {entry.pricing.status === 'configured' ? (
              <span className="admin-badge ok">Active</span>
            ) : (
              <span className="admin-badge warn">Missing</span>
            )}
          </div>

          <div className="admin-kv">
            <span className="k">Billing model</span>
            <span className="v">{entry.pricing.unit}</span>

            <span className="k">Payer rules</span>
            <span className="v">{entry.pricing.payerRules.join(' / ')}</span>

            <span className="k">Base tariff</span>
            <span className="v">{entry.pricing.baseTariff}</span>

            <span className="k">Effective</span>
            <span className="v">{formatDate(entry.pricing.effective)}</span>
          </div>

          {entry.pricing.versions.length > 0 && (
            <div className="sc-version-list">
              {entry.pricing.versions.map((version) => (
                <div key={version.label} className="sc-version">
                  <span>{version.label}</span>

                  {version.active ? (
                    <span className="admin-badge good">Active</span>
                  ) : (
                    <span className="admin-badge idle">Historical</span>
                  )}

                  {version.effective && (
                    <span className="muted small">
                      {formatDate(version.effective)}
                    </span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Reporting */}
        <div className="sc-section">
          <div className="sc-section-title">
            Reporting mapping
            {entry.reporting.status === 'valid' ? (
              <span className="admin-badge ok">Valid</span>
            ) : (
              <span className="admin-badge warn">Review</span>
            )}
          </div>

          <div className="admin-kv">
            <span className="k">AMEXAN code</span>
            <span className="v mono">{entry.code}</span>

            <span className="k">Classification</span>
            <span className="v mono">{entry.reporting.classification}</span>

            <span className="k">Dataset</span>
            <span className="v">{entry.reporting.dataset}</span>

            <span className="k">Mapping status</span>
            <span className="v">{entry.reporting.mappingStatus}</span>

            <span className="k">Last validated</span>
            <span className="v">{formatDate(entry.reporting.lastValidated)}</span>
          </div>

          <div className="sc-map-list">
            {entry.mappings.map((mapping) => (
              <div key={`${mapping.kind}-${mapping.standard}`} className="sc-map-row">
                <span className="sc-map-kind">{mapping.kind}</span>

                <span className="mono">{mapping.standard}</span>

                <span className="mono muted">→ {mapping.representation}</span>

                {mapping.status === 'valid' ? (
                  <span className="admin-badge good">valid</span>
                ) : (
                  <span className="admin-badge warn">{mapping.status}</span>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="sc-detail-grid">
        {/* Dependencies */}
        <div className="sc-section">
          <div className="sc-section-title">Dependencies</div>

          {entry.dependencies.length === 0 ? (
            <div className="admin-empty" style={{ padding: 12 }}>
              No operational dependencies.
            </div>
          ) : (
            <div className="sc-chip-list">
              {entry.dependencies.map((dependency) => (
                <span key={dependency} className="sc-chip">
                  {dependency}
                </span>
              ))}
            </div>
          )}

          {entry.dependencies.length > 0 && (
            <div className="muted small" style={{ marginTop: 8 }}>
              A dependency that becomes unavailable raises this service's
              operational risk and flows into Clinical Operations and AMEXAN
              Intelligence.
            </div>
          )}
        </div>

        {/* Integrations */}
        <div className="sc-section">
          <div className="sc-section-title">Integrations</div>

          {entry.integrations.length === 0 ? (
            <div className="admin-empty" style={{ padding: 12 }}>
              No external integrations configured.
            </div>
          ) : (
            <div className="sc-chip-list">
              {entry.integrations.map((integration) => (
                <span key={integration} className="sc-chip">
                  {integration}
                </span>
              ))}
            </div>
          )}

          <div className="muted small" style={{ marginTop: 8 }}>
            External integration mapping:{' '}
            {entry.integrationMapping ? (
              <span className="admin-badge ok">Configured</span>
            ) : (
              <span className="admin-badge warn">Missing</span>
            )}
          </div>
        </div>
      </div>

      {/* Governance */}
      <div className="sc-section">
        <div className="sc-section-title">Governed configuration</div>

        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Change</th>
                <th>Approval required</th>
              </tr>
            </thead>

            <tbody>
              {entry.governance.map((rule) => (
                <tr key={rule.change}>
                  <td>{rule.change}</td>
                  <td className="muted">{rule.approval}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Actions */}
      <div className="sc-section">
        <div className="sc-section-title">Actions</div>

        <div className="sc-actions">
          {actionButtons.map((button) => (
            <button
              key={button.id}
              type="button"
              className="admin-page-btn"
              onClick={() => onAction(button.label)}
            >
              {button.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// =============================================================================
// MAIN VIEW
// =============================================================================

export function ServiceCatalogueView() {
  const [data, setData] = useState<ServiceCatalogueOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<CategoryFilter>('ALL');
  const [selected, setSelected] = useState<CatalogueServiceEntry | null>(null);
  const [demoNotice, setDemoNotice] = useState<string | null>(null);

  const mountedRef = useRef(true);
  const requestRef = useRef(0);

  // ===========================================================================
  // LOAD
  // ===========================================================================

  const load = useCallback(async (background = false) => {
    const requestId = ++requestRef.current;

    if (background) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }

    try {
      const next = await getServiceCatalogue();

      if (!mountedRef.current) return;
      if (requestId !== requestRef.current) return;

      setData(next);
      setError(null);
      setLastUpdated(new Date());
    } catch (cause) {
      if (!mountedRef.current) return;
      if (requestId !== requestRef.current) return;

      setError(
        cause instanceof Error
          ? cause.message
          : 'Failed to load service catalogue',
      );
    } finally {
      if (!mountedRef.current) return;

      if (background) {
        setRefreshing(false);
      } else {
        setLoading(false);
      }
    }
  }, []);

  // ===========================================================================
  // INITIAL + POLLING
  // ===========================================================================

  useEffect(() => {
    mountedRef.current = true;

    void load(false);

    const timer = window.setInterval(() => {
      void load(true);
    }, REFRESH_INTERVAL);

    return () => {
      mountedRef.current = false;
      window.clearInterval(timer);
    };
  }, [load]);

  // ===========================================================================
  // DERIVED DATA
  // ===========================================================================

  const services = useMemo(() => data?.services ?? [], [data]);
  const health = data?.health ?? null;
  const attention = data?.attention ?? [];
  const categories = data?.categories ?? [];

  const normalizedSearch = search.trim().toLowerCase();

  const filteredServices = useMemo(() => {
    return services.filter((entry) => {
      if (filter !== 'ALL' && entry.category !== filter) return false;

      if (!normalizedSearch) return true;

      const haystack = [
        entry.code,
        entry.name,
        entry.description,
        entry.serviceType,
        entry.location.label,
        entry.department.name,
        entry.units.offering,
        entry.reporting.classification,
        entry.workflow.summary,
        ...entry.dependencies,
        ...entry.integrations,
        ...entry.items.map((item) => `${item.code} ${item.name}`),
      ]
        .join(' ')
        .toLowerCase();

      return haystack.includes(normalizedSearch);
    });
  }, [services, filter, normalizedSearch]);

  const grouped = useMemo(() => {
    const result = new Map<CatalogueCategory, CatalogueServiceEntry[]>();

    for (const code of CATEGORY_ORDER) {
      result.set(code, filteredServices.filter((entry) => entry.category === code));
    }

    return result;
  }, [filteredServices]);

  const handleAction = useCallback((label: string) => {
    setDemoNotice(
      `"${label}" opens the read-only configuration surface. In the demo environment the Service Catalogue is a governed projection — changes route through their required approvals.`,
    );
  }, []);

  const openDetail = useCallback((entry: CatalogueServiceEntry) => {
    setSelected(entry);
    setDemoNotice(null);
  }, []);

  const attentionTarget = useCallback(
    (item: CatalogueAttentionItem) => {
      const entry = services.find((candidate) => candidate.code === item.code);

      if (entry) openDetail(entry);
    },
    [services, openDetail],
  );

  // ===========================================================================
  // LOADING / FAILURE
  // ===========================================================================

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span className="admin-spinner" aria-hidden="true" />
        Loading service catalogue…
      </div>
    );
  }

  if (error && !data) {
    return (
      <div>
        <div className="admin-error">
          <strong>Service catalogue unavailable</strong>
          {error}
        </div>

        <button
          type="button"
          className="admin-page-btn"
          style={{ marginTop: 12 }}
          onClick={() => void load(false)}
        >
          Retry
        </button>
      </div>
    );
  }

  // ===========================================================================
  // RENDER
  // ===========================================================================

  return (
    <div className="admin-catalogues">
      {/* =====================================================================
          HEADER / SCOPE
          ===================================================================== */}

      <div className="admin-panel">
        <div className="admin-panel-head">
          <div>
            <span className="sc-breadcrumb">← Command Center</span>

            <span
              className="admin-panel-title"
              style={{ display: 'block', marginTop: 4 }}
            >
              Service Catalogues
            </span>

            <span className="admin-panel-sub" style={{ display: 'block', marginTop: 2 }}>
              Facility service registry · every service carries department ·
              location · workforce · workflow · capacity · pricing · reporting ·
              integrations
            </span>
          </div>

          <div
            style={{
              display: 'flex',
              gap: 8,
              alignItems: 'center',
              flexWrap: 'wrap',
            }}
          >
            <span className="admin-badge brand">
              {data?.facility.code} · Facility scope
            </span>

            <span className="admin-badge">● DEMO ENVIRONMENT</span>

            {refreshing && (
              <span className="admin-badge warn">synchronizing</span>
            )}

            <span className="muted small">
              {lastUpdated ? `updated ${formatRelative(lastUpdated.toISOString())}` : 'not synchronized'}
            </span>

            <button
              type="button"
              className="admin-page-btn"
              onClick={() => void load(true)}
              disabled={refreshing}
            >
              {refreshing ? 'Refreshing…' : 'Refresh'}
            </button>
          </div>
        </div>

        {error && (
          <div className="admin-error" style={{ margin: 12 }}>
            <strong>Catalogue Control Plane degraded:</strong> {error}
          </div>
        )}

        {demoNotice && (
          <div className="sc-demo-notice" role="status">
            {demoNotice}
            <button type="button" onClick={() => setDemoNotice(null)}>
              Dismiss
            </button>
          </div>
        )}
      </div>

      {/* =====================================================================
          CATALOGUE HEALTH
          ===================================================================== */}

      {health && (
        <div>
          <div className="admin-tile-grid">
            <div className="admin-tile">
              <span className="tile-label">Active services</span>

              <span className="tile-value">{health.activeServices}</span>

              <span className="tile-note">
                {health.clinical} Clinical · {health.diagnostics} Diagnostics ·{' '}
                {health.support} Support
              </span>
            </div>

            <div className="admin-tile tile-good">
              <span className="tile-label">Configured workflows</span>

              <span className="tile-value">{health.configuredWorkflows}</span>

              <span className="tile-note">workflow definitions active</span>
            </div>

            <div className="admin-tile tile-brand">
              <span className="tile-label">Reporting mappings</span>

              <span className="tile-value">{health.reportingMappings}</span>

              <span className="tile-note">HMIS / payer / FHIR representations</span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">Pricing configurations</span>

              <span className="tile-value">{health.pricingConfigurations}</span>

              <span className="tile-note">tariff versions active</span>
            </div>

            <div
              className={`admin-tile${
                health.requiresReview > 0 ? ' tile-danger' : ''
              }`}
            >
              <span className="tile-label">Requires review</span>

              <span className="tile-value">{health.requiresReview}</span>

              <span className="tile-note">services needing configuration review</span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">Catalogue status</span>

              <span className="tile-value">{health.catalogueStatusPercent}%</span>

              <span className="tile-note">
                complete — weighted across all five configuration surfaces
              </span>

              <ProgressBar value={health.catalogueStatusPercent} />
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          CATALOGUE INTEGRITY
          ===================================================================== */}

      {health && (
        <div className="admin-panel">
          <SectionTitle
            kicker="Is the catalogue actually usable?"
            title="Catalogue integrity"
            subtitle="configuration completeness per service, computed from the registry"
          />

          <div className="sc-integrity">
            {[
              { label: 'Service definitions complete', value: health.integrity.serviceDefinitions },
              { label: 'Workflow configured', value: health.integrity.workflowConfigured },
              { label: 'Pricing configured', value: health.integrity.pricingConfigured },
              { label: 'Reporting mapping', value: health.integrity.reportingMapping },
              { label: 'Integration mappings', value: health.integrity.integrationMappings },
            ].map((row) => {
              const complete =
                row.value.total === 0
                  ? 0
                  : Math.round((row.value.complete / row.value.total) * 100);

              const tone =
                complete === 100
                  ? undefined
                  : complete >= 80
                    ? 'warn'
                    : 'bad';

              return (
                <div key={row.label} className="sc-integrity-row">
                  <span className="sc-integrity-label">{row.label}</span>

                  <span className="sc-integrity-track">
                    <ProgressBar value={complete} tone={tone} />
                  </span>

                  <span className="sc-integrity-value mono">
                    {row.value.complete} / {row.value.total}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* =====================================================================
          SEARCH + FILTER
          ===================================================================== */}

      <div className="admin-panel">
        <SectionTitle
          title="Service registry"
          subtitle={`${services.length} operational services · search or filter by category`}
        />

        <div className="admin-filters">
          <input
            type="search"
            className="admin-filter-input"
            placeholder="Search services, codes, locations, departments, workflows…"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            aria-label="Search services"
          />

          <div className="sc-filter-chips" role="tablist" aria-label="Filter by category">
            {CATEGORY_FILTERS.map((item) => (
              <button
                key={item.value}
                type="button"
                role="tab"
                aria-selected={filter === item.value}
                className={`sc-chip-btn${filter === item.value ? ' active' : ''}`}
                onClick={() => setFilter(item.value)}
              >
                {item.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* =====================================================================
          CATEGORY SECTIONS + CARDS
          ===================================================================== */}

      {categories.map((category) => {
        const entries = grouped.get(category.code) ?? [];

        return (
          <div key={category.code} className="admin-panel">
            <div className="admin-panel-head">
              <div>
                <span className="admin-panel-title">{category.label}</span>

                <span className="admin-panel-sub" style={{ display: 'block', marginTop: 2 }}>
                  {entries.length === 0
                    ? 'no matching services'
                    : `${entries.length} service${entries.length === 1 ? '' : 's'}`}
                </span>
              </div>

              {category.code === 'SUPPORT' && (
                <span className="admin-panel-sub">
                  Categories are for navigation — the underlying service model
                  remains flexible.
                </span>
              )}
            </div>

            {entries.length === 0 ? (
              <div className="admin-empty">
                No services match the current search and filter.
              </div>
            ) : (
              <div className="admin-grid-3">
                {entries.map((entry) => (
                  <ServiceCard
                    key={entry.id}
                    entry={entry}
                    onOpen={openDetail}
                  />
                ))}
              </div>
            )}
          </div>
        );
      })}

      {/* =====================================================================
          CONFIGURATION ATTENTION
          ===================================================================== */}

      <div className="admin-panel">
        <SectionTitle
          kicker="Not everything is fully configured"
          title="Configuration attention"
          subtitle="gaps and operational dependencies that require a review"
        />

        {attention.length === 0 ? (
          <div className="admin-empty">
            Every service is fully configured.
          </div>
        ) : (
          <div className="sc-attention">
            {attention.map((item) => (
              <div
                key={item.code}
                className={`sc-attention-item ${item.severity}`}
              >
                <span className="sc-attention-code mono">{item.code}</span>

                <div className="sc-attention-body">
                  <strong>{item.name}</strong>

                  <span className="muted small">
                    ⚠ {item.issue}
                  </span>
                </div>

                <button
                  type="button"
                  className="admin-page-btn"
                  onClick={() => attentionTarget(item)}
                >
                  Review →
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* =====================================================================
          QUICK ACTIONS
          ===================================================================== */}

      <div className="admin-panel">
        <SectionTitle
          title="Quick actions"
          subtitle="configuration surfaces for the facility service registry"
        />

        <div className="sc-actions">
          {QUICK_ACTIONS.map((action) => (
            <button
              key={action.id}
              type="button"
              className="sc-action-btn"
              title={action.description}
              onClick={() => handleAction(action.label)}
            >
              <strong>{action.label}</strong>
              <span className="muted small">{action.description}</span>
            </button>
          ))}
        </div>
      </div>

      {/* =====================================================================
          SERVICE DETAIL
          ===================================================================== */}

      {selected && (
        <ServiceDetail
          entry={selected}
          onBack={() => setSelected(null)}
          onAction={handleAction}
        />
      )}
    </div>
  );
}