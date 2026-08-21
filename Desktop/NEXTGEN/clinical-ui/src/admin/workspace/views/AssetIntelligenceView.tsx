// =============================================================================
// AMEXAN Asset Intelligence — care continuity through asset intelligence
//
// OPERATE / IMPROVE. Read-only Control Plane projection.
//
// The Facility Administrator does not primarily need "what assets do we own?"
// They need:
//
//   "What clinical capability disappears if this asset becomes unavailable,
//    how much care is exposed, what alternatives exist, and what should we do
//    before failure?"
//
// Responsibilities
// -----------------------------------------------------------------------------
// • Facility asset health — the operational picture, not the register.
// • Clinical infrastructure resilience — redundancy, single points of failure,
//   external contingency, overdue maintenance.
// • Single points of failure — the strongest resilience indicators.
// • The operational register — every asset carries utilization, care
//   dependency and a CALCULATED risk, never a manual label.
// • "If this asset fails" — the hero feature: care impact, services affected,
//   dependency chain, alternatives, recovery estimate.
// • Utilization intelligence — workload vs configured capacity vs forecast.
// • Maintenance intelligence — review recommended when utilization diverges
//   from the baseline used for the existing maintenance interval.
// • Reliability — failures, MTBF, downtime, service history.
// • Patient safety separated from operational impact; patient details are
//   never exposed by default.
// • Recommended actions per high-risk asset.
//
// CONSTITUTIONAL RULE
// -----------------------------------------------------------------------------
// An asset is not important because AMEXAN owns it. An asset is important
// because of the clinical and operational capabilities that depend on it.
// The Service Catalogue tells AMEXAN what a service requires; Asset
// Intelligence tells AMEXAN whether those requirements are available.
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

import { getAssetIntelligence } from '../api';

import type {
  AssetEntry,
  AssetIntelligenceOverview,
  AssetRisk,
  AssetStatus,
  CareDependency,
  RedundancyLevel,
} from '../types';

// =============================================================================
// TYPES
// =============================================================================

type AssetFilter =
  | 'ALL'
  | 'CRITICAL'
  | 'HIGH'
  | 'MAINTENANCE'
  | 'HIGH_UTIL'
  | 'OFFLINE'
  | 'NO_REDUNDANCY'
  | 'CLINICAL_CRITICAL';

// =============================================================================
// CONSTANTS
// =============================================================================

const REFRESH_INTERVAL = 30_000;

const FILTERS: { value: AssetFilter; label: string }[] = [
  { value: 'ALL', label: 'All' },
  { value: 'CRITICAL', label: 'Critical' },
  { value: 'HIGH', label: 'High risk' },
  { value: 'MAINTENANCE', label: 'Maintenance due' },
  { value: 'HIGH_UTIL', label: 'High utilization' },
  { value: 'OFFLINE', label: 'Offline' },
  { value: 'NO_REDUNDANCY', label: 'No redundancy' },
  { value: 'CLINICAL_CRITICAL', label: 'Clinical critical' },
];

const STATUS_LABEL: Record<AssetStatus, string> = {
  operational: 'Operational',
  'in-service': 'In service',
  limited: 'Limited',
  offline: 'Offline',
  maintenance: 'Maintenance',
};

const STATUS_CLASS: Record<AssetStatus, string> = {
  operational: 'ok',
  'in-service': 'ok',
  limited: 'warn',
  offline: 'bad',
  maintenance: 'idle',
};

const STATUS_DOT: Record<AssetStatus, string> = {
  operational: '🟢',
  'in-service': '🟢',
  limited: '🟠',
  offline: '🔴',
  maintenance: '🟡',
};

const RISK_LABEL: Record<AssetRisk, string> = {
  low: 'Low',
  moderate: 'Moderate',
  high: 'High',
  critical: 'Critical',
};

const RISK_CLASS: Record<AssetRisk, string> = {
  low: 'ok',
  moderate: 'warn',
  high: 'bad',
  critical: 'bad',
};

const RISK_DOT: Record<AssetRisk, string> = {
  low: '🟢',
  moderate: '🟠',
  high: '🔴',
  critical: '🔴',
};

const DEPENDENCY_LABEL: Record<CareDependency, string> = {
  low: 'Low',
  medium: 'Medium',
  high: 'High',
  'very-high': 'Very high',
  critical: 'Critical',
};

const REDUNDANCY_LABEL: Record<RedundancyLevel, string> = {
  none: 'None',
  limited: 'Limited',
  full: 'Full',
};

const DETAIL_ACTIONS: string[] = [
  'Schedule maintenance',
  'Review contingency',
  'Open service',
  'View incidents',
  'View supplier',
  'View affected workflows',
];

// =============================================================================
// HELPERS
// =============================================================================

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

function formatDate(value: string | null): string {
  if (!value) return '—';

  const date = new Date(`${value}T00:00:00`);

  if (Number.isNaN(date.getTime())) return value;

  return date.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function formatKES(value: number): string {
  return `${value.toLocaleString('en-KE')} KES`;
}

function matchesFilter(asset: AssetEntry, filter: AssetFilter): boolean {
  switch (filter) {
    case 'ALL':
      return true;
    case 'CRITICAL':
      return asset.risk === 'critical' || asset.careDependency === 'critical';
    case 'HIGH':
      return asset.risk === 'high' || asset.risk === 'critical';
    case 'MAINTENANCE':
      return (
        asset.maintenance.status === 'due-soon' ||
        asset.maintenance.status === 'overdue' ||
        asset.approachingServiceThreshold
      );
    case 'HIGH_UTIL':
      return asset.utilizationPct >= 85;
    case 'OFFLINE':
      return (
        asset.status === 'offline' ||
        asset.status === 'maintenance' ||
        asset.status === 'limited'
      );
    case 'NO_REDUNDANCY':
      return asset.redundancy === 'none';
    case 'CLINICAL_CRITICAL':
      return (
        asset.careDependency === 'critical' ||
        asset.careDependency === 'very-high'
      );
  }
}

// =============================================================================
// SECTION TITLE
// =============================================================================

function SectionTitle({
  kicker,
  title,
  subtitle,
}: {
  kicker: string;
  title: string;
  subtitle?: string;
}) {
  return (
    <div style={{ margin: '0 0 12px' }}>
      <div
        className="sc-breadcrumb"
        style={{ marginBottom: 4 }}
      >
        {kicker}
      </div>

      <div
        className="admin-panel-title"
        style={{ display: 'block' }}
      >
        {title}
      </div>

      {subtitle && (
        <div
          className="admin-panel-sub"
          style={{ display: 'block', marginTop: 2 }}
        >
          {subtitle}
        </div>
      )}
    </div>
  );
}

// =============================================================================
// DEPENDENCY CHAIN
// =============================================================================

function DependencyChain({ asset }: { asset: AssetEntry }) {
  return (
    <div className="ai-dep-chain">
      <div className="ai-dep-root">
        <span className="ai-dep-root-name">{asset.name}</span>
        <span className="mono ai-dep-root-code">{asset.code}</span>
      </div>

      <div className="ai-dep-branch">
        {asset.clinicalServices.map((service) => (
          <div className="ai-dep-leaf" key={service}>
            {service}
          </div>
        ))}

        {asset.externalAlternatives.length > 0 && (
          <div className="ai-dep-subtree">
            <div className="ai-dep-leaf ai-dep-leaf-sub">Referral Network</div>

            <div className="ai-dep-branch ai-dep-branch-indent">
              {asset.externalAlternatives.map((alt) => (
                <div className="ai-dep-leaf" key={alt.name}>
                  {alt.name}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// =============================================================================
// IMPACT PANEL — "IF THIS ASSET FAILS"
// =============================================================================

function ImpactPanel({ asset }: { asset: AssetEntry }) {
  const impact = asset.scheduledImpact;

  return (
    <div className="admin-grid-3">
      <div className="admin-panel ai-impact-card">
        <div className="admin-panel-head">
          <span className="admin-panel-title">Care impact</span>
        </div>

        <div className="admin-kv ai-impact-kv">
          <span className="k">Investigations</span>
          <span className="v num">{impact?.investigations ?? 0}</span>

          <span className="k">Departments affected</span>
          <span className="v num">{impact?.departments ?? 0}</span>

          <span className="k">External facilities</span>
          <span className="v num">{asset.externalAlternatives.length}</span>

          <span className="k">Urgent investigations</span>
          <span className="v num">{impact?.urgent ?? 0}</span>
        </div>

        <div className="ai-safety-split">
          <div>
            <div className="ai-safety-label">Operational impact</div>
            <div className="num">{impact?.investigations ?? 0} scheduled studies</div>
          </div>

          <div>
            <div className="ai-safety-label">Clinical urgency</div>
            <div className="num">{impact?.urgent ?? 0} urgent</div>
          </div>

          {impact?.safetyImpact && (
            <div className="ai-safety-risk">
              {impact.safetyImpact}
            </div>
          )}
        </div>

        <div className="muted small ai-patient-note">
          Patient details are not exposed by default. Authorized staff enter
          the operational workflow for affected cases.
        </div>
      </div>

      <div className="admin-panel">
        <div className="admin-panel-head">
          <span className="admin-panel-title">Services affected</span>
        </div>

        <div className="sc-chip-list">
          {asset.clinicalServices.map((service) => (
            <span className="sc-chip" key={service}>
              {service}
            </span>
          ))}
        </div>

        <div className="admin-kv ai-impact-kv" style={{ marginTop: 14 }}>
          <span className="k">Current workload</span>
          <span className="v num">{asset.utilizationPct}% utilization</span>

          <span className="k">Recovery estimate</span>
          <span className="v">{asset.estimatedRecoveryHrs}</span>

          <span className="k">Internal redundancy</span>
          <span className="v">
            {asset.internalAlternatives.length > 0
              ? asset.internalAlternatives.join(', ')
              : REDUNDANCY_LABEL[asset.redundancy]}
          </span>
        </div>

        <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
          <span className="small muted">Operational risk</span>
          <span className={`admin-badge ${RISK_CLASS[asset.risk]}`}>
            {RISK_DOT[asset.risk]} {RISK_LABEL[asset.risk].toUpperCase()}
          </span>
        </div>
      </div>

      <div className="admin-panel">
        <div className="admin-panel-head">
          <span className="admin-panel-title">Alternatives</span>
        </div>

        <div className="ai-alt-list">
          {asset.externalAlternatives.length === 0 && (
            <div className="muted small">No external alternatives configured.</div>
          )}

          {asset.externalAlternatives.map((alt) => (
            <div className="ai-alt-card" key={alt.name}>
              <div className="ai-alt-head">
                <strong>{alt.name}</strong>
                <span
                  className={`admin-badge ${
                    alt.capacity === 'high' ? 'good' : 'warn'
                  }`}
                >
                  {alt.capacity === 'high'
                    ? 'High capacity'
                    : alt.capacity === 'moderate'
                      ? 'Moderate capacity'
                      : 'Low capacity'}
                </span>
              </div>

              <div className="small muted">{alt.capability}</div>

              <div className="ai-alt-meta">
                <span>Estimated transfer</span>
                <span className="num">{alt.transferMins} min</span>
              </div>
            </div>
          ))}

          {asset.internalAlternatives.length > 0 && (
            <div className="ai-internal-alts">
              <div className="small muted" style={{ marginBottom: 4 }}>
                Internal alternatives
              </div>

              {asset.internalAlternatives.map((name) => (
                <span className="sc-chip" key={name}>
                  {name}
                </span>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// =============================================================================
// RISK MODEL — factor breakdown (make the calculation visible)
// =============================================================================

type RiskFactorKey =
  | 'clinicalCriticality'
  | 'utilization'
  | 'dependency'
  | 'redundancyGap'
  | 'failureProbability'
  | 'recoveryTime';

const RISK_FACTOR_ROWS: {
  key: RiskFactorKey;
  label: string;
}[] = [
  { key: 'clinicalCriticality', label: 'Clinical criticality' },
  { key: 'utilization', label: 'Utilization' },
  { key: 'dependency', label: 'Dependency' },
  { key: 'redundancyGap', label: 'Redundancy gap' },
  { key: 'failureProbability', label: 'Failure probability' },
  { key: 'recoveryTime', label: 'Recovery time' },
];

function RiskModel({ asset }: { asset: AssetEntry }) {
  const factors = asset.riskFactors;

  return (
    <div>
      <div className="ai-risk-formula">
        Asset Risk = clinical criticality × utilization × dependency ×
        redundancy gap × failure probability × recovery time
      </div>

      <div className="ai-factor-list">
        {RISK_FACTOR_ROWS.map((row) => (
          <div className="ai-factor-row" key={row.key}>
            <span className="ai-factor-label">{row.label}</span>

            <span className="ai-factor-track">
              <span
                className="ai-factor-fill"
                style={{ width: `${Math.round(factors[row.key] * 100)}%` }}
              />
            </span>

            <span className="num ai-factor-value">
              {Math.round(factors[row.key] * 100)}%
            </span>
          </div>
        ))}
      </div>

      <div className="ai-risk-total">
        <span>Calculated score</span>
        <span className="mono">{factors.score.toFixed(2)}</span>
        <span className={`admin-badge ${RISK_CLASS[asset.risk]}`}>
          {RISK_DOT[asset.risk]} {RISK_LABEL[asset.risk].toUpperCase()}
        </span>
      </div>
    </div>
  );
}

// =============================================================================
// OUTAGE CHAIN
// =============================================================================

function OutageChain({ asset }: { asset: AssetEntry }) {
  if (asset.outageChain.length === 0) {
    return (
      <div className="admin-empty">
        No outage pathway recorded for this asset.
      </div>
    );
  }

  return (
    <div className="ai-outage-chain">
      {asset.outageChain.map((step, index) => (
        <div className="ai-outage-step" key={step.stage}>
          <span className="ai-outage-stage">
            <span className="ai-outage-index">{index + 1}</span>
            {step.stage}
          </span>
          <span className="ai-outage-detail">{step.detail}</span>
        </div>
      ))}
    </div>
  );
}

// =============================================================================
// ASSET DETAIL
// =============================================================================

function AssetDetail({
  asset,
  onBack,
  onAction,
}: {
  asset: AssetEntry;
  onBack: () => void;
  onAction: (label: string) => void;
}) {
  return (
    <div>
      <button
        type="button"
        className="sc-back"
        onClick={onBack}
      >
        ← All assets
      </button>

      <div className="admin-panel">
        <div className="admin-panel-head">
          <div>
            <span className="sc-breadcrumb">Asset Intelligence</span>

            <div className="sc-detail-title" style={{ marginTop: 4 }}>
              <h2>{asset.name}</h2>

              <span className="sc-card-code">{asset.code}</span>

              <span className={`admin-badge ${STATUS_CLASS[asset.status]}`}>
                {STATUS_DOT[asset.status]} {STATUS_LABEL[asset.status]}
              </span>

              {asset.singlePointOfFailure && (
                <span className="admin-badge bad">Single point of failure</span>
              )}
            </div>

            <div
              className="admin-panel-sub"
              style={{ display: 'block', marginTop: 2 }}
            >
              {asset.category} · {asset.location}
            </div>
          </div>

          <div className="admin-kv ai-detail-quick">
            <span className="k">Care dependency</span>
            <span className="v">{DEPENDENCY_LABEL[asset.careDependency]}</span>

            <span className="k">Failure risk</span>
            <span className={`v ${RISK_CLASS[asset.risk]}`}>
              {RISK_LABEL[asset.risk]}
            </span>
          </div>
        </div>
      </div>

      {asset.maintenance.reviewRecommended && (
        <div className="sc-status-note">
          Maintenance intelligence: review recommended —{' '}
          {asset.maintenance.reviewReason}
        </div>
      )}

      {/* Operational state + utilization */}
      <div className="admin-grid-3">
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Operational state</span>
          </div>

          <div className="admin-kv">
            <span className="k">Status</span>
            <span className="v">
              {STATUS_LABEL[asset.status]}
            </span>

            <span className="k">Utilization</span>
            <span className="v num">{asset.utilizationPct}%</span>

            <span className="k">Capacity</span>
            <span className="v num">{asset.configuredCapacityPerDay}/day</span>

            <span className="k">Current load</span>
            <span className="v num">{asset.currentLoadPerDay}</span>

            <span className="k">Remaining capacity</span>
            <span className="v num">{asset.remainingCapacityPerDay}/day</span>

            <span className="k">Redundancy</span>
            <span className="v">{REDUNDANCY_LABEL[asset.redundancy]}</span>
          </div>

          {asset.forecastNote && (
            <div className="ai-forecast-note">{asset.forecastNote}</div>
          )}

          {asset.redundancyNote && (
            <div className="muted small" style={{ marginTop: 10 }}>
              {asset.redundancyNote}
            </div>
          )}
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Clinical services dependent</span>
          </div>

          <div className="sc-chip-list">
            {asset.clinicalServices.map((service) => (
              <span className="sc-chip" key={service}>
                {service}
              </span>
            ))}
          </div>

          {asset.serviceCode && (
            <div style={{ marginTop: 12 }}>
              <div className="small muted" style={{ marginBottom: 4 }}>
                Service Catalogue reference
              </div>
              <span className="sc-chip">
                <span className="mono">{asset.serviceCode}</span>
                {asset.serviceName}
              </span>
            </div>
          )}

          <div className="admin-kv" style={{ marginTop: 14 }}>
            <span className="k">Scheduled impact</span>
            <span className="v num">
              {asset.scheduledImpact?.investigations ?? 0} studies
            </span>

            <span className="k">Urgent</span>
            <span className="v num">{asset.scheduledImpact?.urgent ?? 0}</span>
          </div>

          {asset.scheduledImpact?.safetyImpact && (
            <div className="ai-safety-risk" style={{ marginTop: 12 }}>
              {asset.scheduledImpact.safetyImpact}
            </div>
          )}
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Financial impact</span>
          </div>

          <div className="ai-financial-value">
            {formatKES(asset.financial.dailyGrossExposure)}
          </div>

          <div className="small muted">Estimated daily gross charge exposure</div>

          <div className="admin-kv" style={{ marginTop: 14 }}>
            <span className="k">Unit charge</span>
            <span className="v">{formatKES(asset.financial.configuredUnitCharge)}</span>

            <span className="k">Current daily load</span>
            <span className="v num">{asset.financial.currentDailyLoad}</span>
          </div>

          <div className="muted small" style={{ marginTop: 12 }}>
            Derived from configured service pricing and current utilization.
          </div>
        </div>
      </div>

      {/* Maintenance + reliability */}
      <div className="admin-grid-3">
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Maintenance</span>
          </div>

          <div className="admin-kv">
            <span className="k">Last service</span>
            <span className="v">{formatDate(asset.maintenance.lastService)}</span>

            <span className="k">Next scheduled</span>
            <span className="v">{formatDate(asset.maintenance.nextScheduled)}</span>

            <span className="k">Days remaining</span>
            <span className="v num">{asset.maintenance.daysRemaining}</span>
          </div>

          <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 10 }}>
            <span className={`admin-badge ${asset.maintenance.status === 'on-schedule' ? 'good' : 'warn'}`}>
              {asset.maintenance.status === 'on-schedule'
                ? '🟢 On schedule'
                : '🟠 Review recommended'}
            </span>

            {asset.maintenance.utilizationDeltaPct > 0 && (
              <span className="small muted">
                utilization +{asset.maintenance.utilizationDeltaPct}% since last
                service
              </span>
            )}
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Reliability</span>
          </div>

          <div className="admin-kv">
            <span className="k">Failures — 90 days</span>
            <span className="v num">{asset.reliability.failures90d}</span>

            <span className="k">Average downtime</span>
            <span className="v num">{asset.reliability.avgDowntimeHrs} hrs</span>

            <span className="k">MTBF</span>
            <span className="v num">{asset.reliability.mtbfDays} days</span>

            <span className="k">Last incident</span>
            <span className="v">{formatDate(asset.reliability.lastIncident)}</span>
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Support dependencies</span>
          </div>

          {asset.supplier ? (
            <div className="admin-kv">
              <span className="k">OEM / provider</span>
              <span className="v">{asset.supplier.name}</span>

              <span className="k">Contract</span>
              <span className="v">
                {asset.supplier.contract === 'active' ? '🟢 Active' : '🔴 Expired'}
              </span>

              <span className="k">Response SLA</span>
              <span className="v num">{asset.supplier.responseSlaHrs} hours</span>

              <span className="k">Last intervention</span>
              <span className="v">{formatDate(asset.supplier.lastIntervention)}</span>
            </div>
          ) : (
            <div className="muted small">No supplier contract configured.</div>
          )}

          {asset.integration && (
            <div style={{ marginTop: 12 }}>
              <span className={`admin-badge ${asset.integration.risPacs ? 'good' : 'warn'}`}>
                {asset.integration.risPacs ? '🟢' : '🟠'} {asset.integration.label}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Workforce + consumables */}
      <div className="admin-grid-3">
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Workforce coverage</span>
          </div>

          <div className="ai-workforce-list">
            {asset.workforce.map((role) => (
              <div className="ai-workforce-row" key={role.role}>
                <span>{role.role}</span>
                <span
                  className={`admin-badge ${role.covered ? 'good' : 'bad'}`}
                >
                  {role.covered ? '✓ Covered' : '✗ Insufficient'}
                </span>
              </div>
            ))}
          </div>

          <div className="muted small" style={{ marginTop: 12 }}>
            Asset available ≠ service available. A qualified operator is
            required to turn this asset into capability.
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Consumables</span>
          </div>

          {asset.consumables.length === 0 ? (
            <div className="muted small">No consumables tracked for this asset.</div>
          ) : (
            <div className="sc-version-list">
              {asset.consumables.map((item) => (
                <div className="sc-version" key={item.name}>
                  <span>{item.name}</span>

                  <span
                    className={`admin-badge ${
                      item.status === 'critical'
                        ? 'bad'
                        : item.status === 'low'
                          ? 'warn'
                          : 'good'
                    }`}
                  >
                    {item.daysRemaining} days remaining
                  </span>
                </div>
              ))}
            </div>
          )}

          <div className="muted small" style={{ marginTop: 12 }}>
            Failure risk is not only mechanical — an analyser may be operational
            but unable to perform tests if consumables are unavailable.
          </div>
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Recommended actions</span>
          </div>

          {asset.recommendedActions.length === 0 ? (
            <div className="muted small">
              No recommended actions — this asset is operating within its
              resilience envelope.
            </div>
          ) : (
            <div className="ai-recommended-list">
              {asset.recommendedActions.map((action, index) => (
                <div className="ai-recommended-item" key={action}>
                  <span className="num">{index + 1}.</span>
                  <span>{action}</span>
                  <span className="admin-badge warn">Recommended</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Risk model + outage chain */}
      <div className="admin-grid-3">
        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Risk model</span>
          </div>

          <RiskModel asset={asset} />
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Incident → care impact</span>
          </div>

          <OutageChain asset={asset} />
        </div>

        <div className="admin-panel">
          <div className="admin-panel-head">
            <span className="admin-panel-title">Dependency chain</span>
          </div>

          <DependencyChain asset={asset} />
        </div>
      </div>

      {/* Actions */}
      <div className="admin-panel">
        <div className="admin-panel-head">
          <span className="admin-panel-title">Actions</span>
        </div>

        <div className="sc-actions">
          {DETAIL_ACTIONS.map((label) => (
            <button
              type="button"
              key={label}
              className="sc-action-btn"
              onClick={() => onAction(label)}
            >
              <strong>{label}</strong>
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

export function AssetIntelligenceView() {
  const [data, setData] = useState<AssetIntelligenceOverview | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<AssetFilter>('ALL');
  const [focusCode, setFocusCode] = useState('RAD-CT-001');
  const [selectedCode, setSelectedCode] = useState<string | null>(null);
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
      const next = await getAssetIntelligence();

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
          : 'Failed to load asset intelligence',
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

  const assets = useMemo(() => data?.assets ?? [], [data]);
  const health = data?.health ?? null;
  const resilience = data?.resilience ?? null;

  const selected = useMemo(() => {
    if (!selectedCode) return null;
    return assets.find((asset) => asset.code === selectedCode) ?? null;
  }, [assets, selectedCode]);

  const focus = useMemo(() => {
    return assets.find((asset) => asset.code === focusCode) ?? null;
  }, [assets, focusCode]);

  const normalizedSearch = search.trim().toLowerCase();

  const filteredAssets = useMemo(() => {
    return assets.filter((asset) => {
      if (!matchesFilter(asset, filter)) return false;

      if (!normalizedSearch) return true;

      const haystack = [
        asset.code,
        asset.name,
        asset.category,
        asset.location,
        asset.serviceCode,
        asset.serviceName,
        ...asset.clinicalServices,
        ...asset.recommendedActions,
      ]
        .join(' ')
        .toLowerCase();

      return haystack.includes(normalizedSearch);
    });
  }, [assets, filter, normalizedSearch]);

  const handleAction = useCallback((label: string) => {
    setDemoNotice(
      `"${label}" opens the read-only operational surface. In the demo environment Asset Intelligence is a projection — actions route through the required operational workflow.`,
    );
  }, []);

  const openDetail = useCallback((asset: AssetEntry) => {
    setSelectedCode(asset.code);
    setDemoNotice(null);
  }, []);

  const backToOverview = useCallback(() => {
    setSelectedCode(null);
  }, []);

  // ===========================================================================
  // LOADING / FAILURE
  // ===========================================================================

  if (loading && !data) {
    return (
      <div className="admin-loading">
        <span className="admin-spinner" aria-hidden="true" />
        Loading asset intelligence…
      </div>
    );
  }

  if (error && !data) {
    return (
      <div>
        <div className="admin-error">
          <strong>Asset intelligence unavailable</strong>
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
  // RENDER — detail
  // ===========================================================================

  if (selected) {
    return (
      <div className="admin-assets">
        <div className="admin-panel">
          <div className="admin-panel-head">
            <div>
              <span className="sc-breadcrumb">← Command Center</span>

              <span
                className="admin-panel-title"
                style={{ display: 'block', marginTop: 4 }}
              >
                Asset Intelligence
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
            </div>
          </div>
        </div>

        {demoNotice && (
          <div className="sc-demo-notice" role="status">
            {demoNotice}
            <button type="button" onClick={() => setDemoNotice(null)}>
              Dismiss
            </button>
          </div>
        )}

        <AssetDetail
          asset={selected}
          onBack={backToOverview}
          onAction={handleAction}
        />
      </div>
    );
  }

  // ===========================================================================
  // RENDER — overview
  // ===========================================================================

  return (
    <div className="admin-assets">
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
              Asset Intelligence
            </span>

            <span className="admin-panel-sub" style={{ display: 'block', marginTop: 2 }}>
              Care continuity through asset intelligence · not asset CRUD —
              what happens to care if this asset fails?
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
            <strong>Asset Control Plane degraded:</strong> {error}
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

        <div className="ai-rule">
          {data?.constitutionalRule}
        </div>
      </div>

      {/* =====================================================================
          FACILITY ASSET HEALTH
          ===================================================================== */}

      {health && (
        <div>
          <SectionTitle
            kicker="1 · Asset health"
            title="Facility asset health"
            subtitle="The operational picture — not the register."
          />

          <div className="admin-tile-grid">
            <div className="admin-tile">
              <span className="tile-label">Assets monitored</span>
              <span className="tile-value">{health.assetsMonitored}</span>
              <span className="tile-note">critical / clinical assets</span>
            </div>

            <div className="admin-tile tile-good">
              <span className="tile-label">Operational availability</span>
              <span className="tile-value">{health.operationalAvailabilityPct}%</span>
              <span className="tile-note">overall availability</span>
            </div>

            <div className="admin-tile tile-danger">
              <span className="tile-label">High-risk assets</span>
              <span className="tile-value">{health.highRiskAssets}</span>
              <span className="tile-note">calculated risk, not manual labels</span>
            </div>

            <div className="admin-tile tile-warn">
              <span className="tile-label">Approaching threshold</span>
              <span className="tile-value">{health.approachingServiceThreshold}</span>
              <span className="tile-note">assets approaching service threshold</span>
            </div>

            <div className="admin-tile tile-brand">
              <span className="tile-label">CT exposure</span>
              <span className="tile-value">
                {health.ctExposedScheduledInvestigations}
              </span>
              <span className="tile-note">scheduled investigations exposed to a potential CT disruption</span>
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          FACILITY RESILIENCE
          ===================================================================== */}

      {resilience && (
        <div className="admin-panel ai-resilience">
          <div className="admin-panel-head">
            <div>
              <span className="admin-panel-title">Clinical infrastructure resilience</span>

              <span className="admin-panel-sub" style={{ display: 'block', marginTop: 2 }}>
                {resilience.note}
              </span>
            </div>

            <div className="ai-resilience-score">
              <span className="ai-resilience-pct">{resilience.pct}%</span>
              <span className={`admin-badge ${
                resilience.level === 'strong'
                  ? 'good'
                  : resilience.level === 'moderate'
                    ? 'warn'
                    : 'bad'
              }`}>
                {resilience.level === 'strong'
                  ? '🟢 Strong'
                  : resilience.level === 'moderate'
                    ? '🟠 Moderate'
                    : '🔴 Weak'}
              </span>
            </div>
          </div>

          <div className="ai-resilience-grid">
            <div className="ai-resilience-stat">
              <span className="num">
                {resilience.factors.criticalServicesWithRedundancy.n} /{' '}
                {resilience.factors.criticalServicesWithRedundancy.of}
              </span>
              <span className="small muted">critical services with redundancy</span>
            </div>

            <div className="ai-resilience-stat">
              <span className="num">{resilience.factors.singlePointsOfFailure}</span>
              <span className="small muted">single points of failure</span>
            </div>

            <div className="ai-resilience-stat">
              <span className="num">
                {resilience.factors.servicesWithExternalContingency}
              </span>
              <span className="small muted">services with external contingency</span>
            </div>

            <div className="ai-resilience-stat">
              <span className="num">
                {resilience.factors.assetsWithOverdueMaintenance}
              </span>
              <span className="small muted">assets with overdue maintenance</span>
            </div>
          </div>

          <div className="ai-opportunity">
            <strong>Resilience opportunity:</strong> {resilience.opportunity}
          </div>
        </div>
      )}

      {/* =====================================================================
          SINGLE POINTS OF FAILURE
          ===================================================================== */}

      <div>
        <SectionTitle
          kicker="2 · Resilience"
          title="Single points of failure"
          subtitle="What the administrator needs to know before failure."
        />

        <div className="admin-grid-3">
          {data?.singlePointsOfFailure.map((spof) => (
            <div className="admin-panel ai-spof-card" key={spof.code}>
              <div className="ai-spof-head">
                <span className={`admin-badge ${RISK_CLASS[spof.risk]}`}>
                  {RISK_DOT[spof.risk]} {RISK_LABEL[spof.risk]}
                </span>
                <span className="sc-card-code">{spof.code}</span>
              </div>

              <div className="ai-spof-name">{spof.name}</div>

              <div className="small muted">{spof.reason}</div>

              <button
                type="button"
                className="admin-page-btn"
                style={{ marginTop: 10 }}
                onClick={() => {
                  const entry = assets.find((asset) => asset.code === spof.code);
                  if (entry) openDetail(entry);
                }}
              >
                Review resilience →
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* =====================================================================
          IMPACT IF ASSET FAILS
          ===================================================================== */}

      {focus && (
        <div>
          <SectionTitle
            kicker="3 · The hero feature"
            title={`If ${focus.name} fails now`}
            subtitle="What happens to care if this asset becomes unavailable."
          />

          <div className="ai-focus-picker">
            {assets.map((asset) => (
              <button
                type="button"
                key={asset.code}
                className={`sc-chip-btn ${asset.code === focus.code ? 'active' : ''}`}
                onClick={() => setFocusCode(asset.code)}
              >
                {asset.name}
              </button>
            ))}
          </div>

          <ImpactPanel asset={focus} />

          <div className="admin-panel" style={{ marginTop: 16 }}>
            <div className="admin-panel-head">
              <div>
                <span className="admin-panel-title">Dependency chain</span>

                <span className="admin-panel-sub" style={{ display: 'block', marginTop: 2 }}>
                  If this asset fails, these services are affected.
                </span>
              </div>
            </div>

            <DependencyChain asset={focus} />
          </div>
        </div>
      )}

      {/* =====================================================================
          UTILIZATION INTELLIGENCE
          ===================================================================== */}

      <div>
        <SectionTitle
          kicker="4 · Utilization"
          title="Utilization intelligence"
          subtitle="Utilization ≠ risk. Demand vs configured capacity vs forecast."
        />

        <div className="ai-util-grid">
          {assets
            .filter((asset) => asset.utilizationPct >= 80)
            .map((asset) => (
              <div className="admin-panel" key={asset.code}>
                <div className="admin-panel-head">
                  <span className="admin-panel-title">{asset.name}</span>

                  <span
                    className={`admin-badge ${
                      asset.utilizationPct >= 88 ? 'bad' : 'warn'
                    }`}
                  >
                    {asset.utilizationPct >= 88 ? '🔴' : '🟠'}{' '}
                    {asset.utilizationPct}%
                  </span>
                </div>

                <div className="admin-kv">
                  <span className="k">Workload</span>
                  <span className="v num">
                    {asset.currentLoadPerDay} investigations/day
                  </span>

                  <span className="k">Configured capacity</span>
                  <span className="v num">
                    {asset.configuredCapacityPerDay} investigations/day
                  </span>

                  <span className="k">Remaining capacity</span>
                  <span className="v num">
                    {asset.remainingCapacityPerDay} investigations/day
                  </span>
                </div>

                <div className="ai-util-bar" style={{ marginTop: 12 }}>
                  <div
                    className="ai-util-fill"
                    style={{ width: `${Math.min(asset.utilizationPct, 100)}%` }}
                  />
                </div>

                <div className="small muted" style={{ marginTop: 8 }}>
                  Risk:{' '}
                  <span className={`${RISK_CLASS[asset.risk]}`}>
                    {RISK_LABEL[asset.risk]}
                  </span>
                  {asset.redundancy === 'none' ? ' · no backup' : ''}
                </div>

                {asset.forecastNote && (
                  <div className="ai-forecast-note" style={{ marginTop: 8 }}>
                    {asset.forecastNote}
                  </div>
                )}

                <button
                  type="button"
                  className="admin-page-btn"
                  style={{ marginTop: 10 }}
                  onClick={() => openDetail(asset)}
                >
                  View asset →
                </button>
              </div>
            ))}
        </div>
      </div>

      {/* =====================================================================
          MAINTENANCE
          ===================================================================== */}

      <div>
        <SectionTitle
          kicker="5 · Maintenance"
          title="Maintenance"
          subtitle="Actionable, not just scheduled."
        />

        <div className="admin-tile-grid">
          <div className="admin-tile tile-warn">
            <span className="tile-label">Due soon</span>
            <span className="tile-value">{data?.maintenance.dueSoon ?? 0}</span>
            <span className="tile-note">assets approaching service threshold</span>
          </div>

          <div className="admin-tile tile-good">
            <span className="tile-label">Overdue</span>
            <span className="tile-value">{data?.maintenance.overdue ?? 0}</span>
            <span className="tile-note">assets with overdue maintenance</span>
          </div>

          <div className="admin-tile tile-brand">
            <span className="tile-label">Review recommended</span>
            <span className="tile-value">{health?.reviewRecommended ?? 0}</span>
            <span className="tile-note">
              utilization diverges from maintenance baseline
            </span>
          </div>
        </div>

        <div className="admin-table-wrap" style={{ marginTop: 12 }}>
          <table className="admin-table">
            <thead>
              <tr>
                <th>Asset</th>
                <th>Last service</th>
                <th>Next scheduled</th>
                <th>Days remaining</th>
                <th>Status</th>
                <th>Utilization delta</th>
              </tr>
            </thead>

            <tbody>
              {assets.map((asset) => (
                <tr key={asset.code}>
                  <td>
                    <strong>{asset.name}</strong>
                    <span className="mono" style={{ marginLeft: 8 }}>
                      {asset.code}
                    </span>
                  </td>
                  <td>{formatDate(asset.maintenance.lastService)}</td>
                  <td>{formatDate(asset.maintenance.nextScheduled)}</td>
                  <td className="num">{asset.maintenance.daysRemaining}</td>
                  <td>
                    {asset.maintenance.reviewRecommended ? (
                      <span className="admin-badge warn">
                        🟠 Review recommended
                      </span>
                    ) : (
                      <span className="admin-badge good">🟢 On schedule</span>
                    )}
                  </td>
                  <td className="num">
                    +{asset.maintenance.utilizationDeltaPct}%
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* =====================================================================
          ASSET REGISTER
          ===================================================================== */}

      <div>
        <SectionTitle
          kicker="6 · Register"
          title="Asset register"
          subtitle="An operational intelligence table, not an inventory table."
        />

        <div className="admin-panel">
          <div className="admin-filters">
            <div className="sc-filter-chips">
              {FILTERS.map((item) => (
                <button
                  type="button"
                  key={item.value}
                  className={`sc-chip-btn ${filter === item.value ? 'active' : ''}`}
                  onClick={() => setFilter(item.value)}
                >
                  {item.label}
                </button>
              ))}
            </div>

            <input
              type="search"
              className="admin-filter-input"
              placeholder="Search assets…"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              aria-label="Search assets"
            />
          </div>

          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Asset</th>
                  <th>ID</th>
                  <th>Status</th>
                  <th>Location</th>
                  <th className="num">Utilization</th>
                  <th>Care dependency</th>
                  <th>Risk</th>
                </tr>
              </thead>

              <tbody>
                {filteredAssets.map((asset) => (
                  <tr key={asset.code} className="ai-register-row">
                    <td>
                      <button
                        type="button"
                        className="ai-register-asset"
                        onClick={() => openDetail(asset)}
                      >
                        {asset.name}
                      </button>
                    </td>
                    <td className="mono">{asset.code}</td>
                    <td>
                      <span className={`admin-badge ${STATUS_CLASS[asset.status]}`}>
                        {STATUS_DOT[asset.status]} {STATUS_LABEL[asset.status]}
                      </span>
                    </td>
                    <td>{asset.location}</td>
                    <td className="num">{asset.utilizationPct}%</td>
                    <td>
                      <span
                        className={
                          asset.careDependency === 'critical' ||
                          asset.careDependency === 'very-high'
                            ? 'ai-dep-high'
                            : asset.careDependency === 'high'
                              ? 'ai-dep-mid'
                              : ''
                        }
                      >
                        {DEPENDENCY_LABEL[asset.careDependency]}
                      </span>
                    </td>
                    <td>
                      <span className={`admin-badge ${RISK_CLASS[asset.risk]}`}>
                        {RISK_DOT[asset.risk]} {RISK_LABEL[asset.risk]}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {filteredAssets.length === 0 && (
              <div className="admin-empty">No assets match the current filter.</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}