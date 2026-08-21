// =============================================================================
// AMEXAN Financial — Facility Financial Operating Picture
//
// DEMO VIEW · FACILITY SCOPE · READ-ONLY
//
// This is a Facility Administrator financial command/analytics view — NOT an
// accounting ledger and NOT a clinical billing screen.
//
// Core question:
//   "What financial activity is the facility generating, what has been
//    claimed/collected, what is outstanding, and where are operational
//    services creating financial pressure or opportunity?"
//
// AMEXAN RULE
//   Financial is DERIVED from operational activity — not a disconnected
//   accounting universe. A consultation creates an encounter, a billable
//   service can create a financial event, that becomes a claim, the claim
//   is submitted, the payer accepts/rejects, payment arrives, AMEXAN
//   reconciles the lifecycle.
//
// STATE DISCIPLINE
//   revenue/charges ≠ claims ≠ accepted claims ≠ payments ≠ receivables.
//   AMEXAN never collapses those into one number.
//
//   Revenue-mix percentages are COMPUTED from gross-charge amounts
//   (service_revenue / total_facility_revenue × 100) and always sum to
//   100% — they are never hand-seeded.
//
// The Facility Admin sees the operating picture. The Finance Officer can
// descend into the detailed financial ledger (separate, permission-bound).
// =============================================================================

import { useMemo, useState } from 'react';

// =============================================================================
// MOCK DEMO DATA
//
// Internally consistent demo figures for KTRH (Kisii Teaching & Referral
// Hospital). All aggregates derive from the service table so percentages
// always reconcile to 100%.
// =============================================================================

type RangeKey = 'today' | 'days7' | 'days30' | 'days90';

interface RangeSummary {
  key: RangeKey;
  label: string;
  grossCharges: number;
  paymentsReceived: number;
  claimsSubmitted: number;
  claimsPending: number;
  receivables: number;
  rejectedClaims: number;
  trend: string;
}

const RANGES: RangeSummary[] = [
  {
    key: 'today',
    label: 'Today',
    grossCharges: 4_800_000,
    paymentsReceived: 3_200_000,
    claimsSubmitted: 2_100_000,
    claimsPending: 740_000,
    receivables: 1_300_000,
    rejectedClaims: 63_000,
    trend: '+6.2% vs 7-day average',
  },
  {
    key: 'days7',
    label: '7 Days',
    grossCharges: 30_100_000,
    paymentsReceived: 21_800_000,
    claimsSubmitted: 13_600_000,
    claimsPending: 1_900_000,
    receivables: 1_300_000,
    rejectedClaims: 420_000,
    trend: '+4.1% vs 30-day average',
  },
  {
    key: 'days30',
    label: '30 Days',
    grossCharges: 124_800_000,
    paymentsReceived: 94_600_000,
    claimsSubmitted: 52_100_000,
    claimsPending: 7_200_000,
    receivables: 18_400_000,
    rejectedClaims: 1_500_000,
    trend: '+7.4% period-on-period',
  },
  {
    key: 'days90',
    label: '90 Days',
    grossCharges: 362_000_000,
    paymentsReceived: 281_400_000,
    claimsSubmitted: 151_700_000,
    claimsPending: 18_900_000,
    receivables: 21_900_000,
    rejectedClaims: 4_300_000,
    trend: '+5.9% period-on-period',
  },
];

interface ServiceRow {
  service: string;
  activity: number;
  gross: number;
  claims: number | null;
  pending: number | null;
}

const SERVICES: ServiceRow[] = [
  {
    service: 'OPD',
    activity: 42,
    gross: 1_200_000,
    claims: 31,
    pending: 4,
  },
  {
    service: 'Inpatient',
    activity: 18,
    gross: 552_000,
    claims: 15,
    pending: 2,
  },
  {
    service: 'Theatre',
    activity: 6,
    gross: 1_056_000,
    claims: 6,
    pending: 1,
  },
  {
    service: 'Maternity',
    activity: 11,
    gross: 360_000,
    claims: 9,
    pending: 1,
  },
  {
    service: 'Laboratory',
    activity: 23,
    gross: 768_000,
    claims: 18,
    pending: 2,
  },
  {
    service: 'Radiology',
    activity: 9,
    gross: 312_000,
    claims: 7,
    pending: 1,
  },
  {
    service: 'Pharmacy',
    activity: 29,
    gross: 552_000,
    claims: null,
    pending: null,
  },
];

// SHA / payer claim cycle (current cycle)
const CLAIM_CYCLE = {
  submitted: 86,
  accepted: 74,
  pending: 9,
  rejected: 3,
};

const CLAIM_VALUE = {
  submitted: 2_100_000,
  accepted: 1_800_000,
  pending: 240_000,
  rejected: 60_000,
};

// Payer mix — sums to gross charges (KES 4.8M today)
const PAYER_MIX = [
  { payer: 'SHA', amount: 2_100_000 },
  { payer: 'Private insurers', amount: 1_200_000 },
  { payer: 'Cash', amount: 900_000 },
  { payer: 'Corporate', amount: 600_000 },
];

const CLAIM_EXCEPTIONS = [
  {
    level: 'danger',
    kind: 'Missing documentation',
    claims: 12,
    value: 84_000,
  },
  {
    level: 'warn',
    kind: 'Coding mismatch',
    claims: 7,
    value: 43_000,
  },
  {
    level: 'warn',
    kind: 'Eligibility issue',
    claims: 4,
    value: 27_000,
  },
  {
    level: 'info',
    kind: 'Payer response pending',
    claims: 9,
    value: 240_000,
  },
];

const RECEIVABLES_AGING = [
  { bucket: '0–30 days', value: 620_000, tone: 'ok' },
  { bucket: '31–60 days', value: 390_000, tone: 'warn' },
  { bucket: '61–90 days', value: 190_000, tone: 'warn' },
  { bucket: '>90 days', value: 100_000, tone: 'bad' },
];

const EXPENDITURE = [
  { category: 'Staffing', value: 1_100_000 },
  { category: 'Medicines', value: 560_000 },
  { category: 'Supplies', value: 420_000 },
  { category: 'Diagnostics', value: 280_000 },
  { category: 'Utilities', value: 180_000 },
  { category: 'Facilities', value: 160_000 },
];

const SUPPLIER_COMMITMENTS = [
  { category: 'Medical supplies', value: 180_000 },
  { category: 'Pharmaceuticals', value: 160_000 },
  { category: 'Laboratory supplies', value: 80_000 },
];

const INTELLIGENCE = [
  {
    tone: 'warn',
    title: 'Claims pressure',
    detail:
      'Claim volume has increased 14% this week while acceptance has fallen 4 percentage points.',
    impact: 'Higher unresolved receivables.',
    action: 'Review claims →',
  },
  {
    tone: 'warn',
    title: 'Service demand',
    detail:
      'OPD activity is 18% above the 30-day baseline.',
    impact:
      'Gross charges are 11.6% above the 7-day average.',
    action: 'View service economics →',
  },
  {
    tone: 'bad',
    title: 'Receivables',
    detail:
      'KES 290K is now older than 60 days.',
    impact: 'Priority: payer reconciliation.',
    action: 'Review receivables →',
  },
];

const ACTIONS = [
  'Financial Command',
  'Claims',
  'Receivables',
  'Reconciliation',
  'Service Economics',
  'Payer Performance',
];

// =============================================================================
// FORMATTERS
// =============================================================================

function formatKES(value: number): string {
  if (value >= 1_000_000) {
    const millions = value / 1_000_000;
    return `KES ${millions % 1 === 0 ? millions.toFixed(0) : millions.toFixed(1)}M`;
  }

  if (value >= 1_000) {
    const thousands = value / 1_000;
    return `KES ${thousands % 1 === 0 ? thousands.toFixed(0) : thousands.toFixed(1)}K`;
  }

  return `KES ${value}`;
}

function formatCount(value: number): string {
  return value.toLocaleString();
}

// =============================================================================
// PRESENTATIONAL COMPONENTS
// =============================================================================

function FacilityContextBar({
  title,
  subtitle,
  onBack,
}: {
  title: string;
  subtitle: string;
  onBack: () => void;
}) {
  return (
    <div
      className="admin-panel"
      style={{ marginBottom: 16 }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          flexWrap: 'wrap',
          justifyContent: 'space-between',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <button
            type="button"
            className="admin-nav-btn"
            onClick={onBack}
          >
            ← Command Center
          </button>

          <span
            className="admin-context-sep"
            aria-hidden="true"
          >
            │
          </span>

          <div>
            <div className="admin-panel-title">
              {title}
            </div>

            <div className="admin-panel-sub">
              {subtitle}
            </div>
          </div>
        </div>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            flexWrap: 'wrap',
          }}
        >
          <span className="admin-badge brand">
            KTRH · Facility scope
          </span>

          <span className="admin-badge warn">
            ● DEMO ENVIRONMENT
          </span>
        </div>
      </div>
    </div>
  );
}

function SectionCard({
  title,
  subtitle,
  children,
  actions,
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
}) {
  return (
    <div className="admin-panel">
      <div className="admin-panel-head">
        <div>
          <span className="admin-panel-title">
            {title}
          </span>

          {subtitle && (
            <span className="admin-panel-sub">
              {subtitle}
            </span>
          )}
        </div>

        {actions}
      </div>

      {children}
    </div>
  );
}

function ToneDot({
  tone,
}: {
  tone: 'ok' | 'warn' | 'bad' | 'info';
}) {
  return (
    <span
      className={`admin-dot ${tone}`}
      aria-hidden="true"
    />
  );
}

// =============================================================================
// FINANCIAL VIEW
// =============================================================================

export function FinancialView({
  onBack,
}: {
  onBack: () => void;
}) {
  const [range, setRange] = useState<RangeKey>('today');

  const activeRange =
    RANGES.find(
      (entry) => entry.key === range,
    ) ?? RANGES[0];

  // ---------------------------------------------------------------------------
  // Revenue mix — computed from service amounts, always sums to 100%.
  // ---------------------------------------------------------------------------

  const revenueMix = useMemo(() => {
    const total = SERVICES.reduce(
      (sum, row) => sum + row.gross,
      0,
    );

    return SERVICES.map((row) => ({
      service: row.service,
      value: row.gross,
      share:
        total > 0
          ? Math.round(
              (row.gross / total) * 1000,
            ) / 10
          : 0,
    }));
  }, []);

  const revenueMixTotal = revenueMix.reduce(
    (sum, row) => sum + row.value,
    0,
  );

  const claimTotal =
    CLAIM_CYCLE.submitted;

  const acceptanceRate = Math.round(
    (CLAIM_CYCLE.accepted / claimTotal) *
      100,
  );

  const pendingRate = Math.round(
    (CLAIM_CYCLE.pending / claimTotal) * 100,
  );

  const rejectedRate = Math.round(
    (CLAIM_CYCLE.rejected / claimTotal) * 100,
  );

  const readiness =
    100 - rejectedRate;

  const receivableTotal = RECEIVABLES_AGING.reduce(
    (sum, row) => sum + row.value,
    0,
  );

  const receivablesOver60 = RECEIVABLES_AGING.filter(
    (row) =>
      row.bucket === '61–90 days' ||
      row.bucket === '>90 days',
  ).reduce((sum, row) => sum + row.value, 0);

  const expenditureTotal = EXPENDITURE.reduce(
    (sum, row) => sum + row.value,
    0,
  );

  const supplierTotal = SUPPLIER_COMMITMENTS.reduce(
    (sum, row) => sum + row.value,
    0,
  );

  const payerTotal = PAYER_MIX.reduce(
    (sum, row) => sum + row.amount,
    0,
  );

  const financialPosition = [
    {
      label: 'Gross charges',
      value: activeRange.grossCharges,
      note: activeRange.trend,
      tone: 'brand',
    },
    {
      label: 'Claims submitted',
      value: activeRange.claimsSubmitted,
      note:
        range === 'today'
          ? `${formatCount(CLAIM_CYCLE.submitted)} claims`
          : 'across selected period',
      tone: 'neutral',
    },
    {
      label: 'Claims pending',
      value: activeRange.claimsPending,
      note: 'Awaiting payer action',
      tone: 'warn',
    },
    {
      label: 'Outstanding receivables',
      value: activeRange.receivables,
      note: 'Due / unresolved',
      tone: 'warn',
    },
    {
      label: 'Payments received',
      value: activeRange.paymentsReceived,
      note: 'recorded cash / payer remittances',
      tone: 'good',
    },
  ];

  const statusStrip = [
    {
      indicator: 'Gross charges',
      value: activeRange.grossCharges,
      tone: 'ok' as const,
    },
    {
      indicator: 'Payments received',
      value: activeRange.paymentsReceived,
      tone: 'ok' as const,
    },
    {
      indicator: 'Claims submitted',
      value: activeRange.claimsSubmitted,
      tone: 'ok' as const,
    },
    {
      indicator: 'Claims pending',
      value: activeRange.claimsPending,
      tone: 'warn' as const,
    },
    {
      indicator: 'Outstanding receivables',
      value: activeRange.receivables,
      tone: 'warn' as const,
    },
    {
      indicator: 'Rejected claims',
      value: activeRange.rejectedClaims,
      tone: 'bad' as const,
    },
  ];

  return (
    <div className="admin-financial">
      {/* =====================================================================
          CONTEXT BAR
          ===================================================================== */}

      <FacilityContextBar
        title="Facility financial operating picture"
        subtitle="Clinical activity · Revenue · Claims · Receivables · Service economics"
        onBack={onBack}
      />

      {/* =====================================================================
          RANGE SELECTOR
          ===================================================================== */}

      <div
        className="admin-filters"
        role="tablist"
        aria-label="Financial reporting period"
      >
        {RANGES.map((entry) => {
          const active = range === entry.key;

          return (
            <button
              key={entry.key}
              type="button"
              role="tab"
              aria-selected={active}
              className={`admin-nav-btn${
                active ? ' active' : ''
              }`}
              onClick={() =>
                setRange(entry.key)
              }
            >
              {entry.label}
            </button>
          );
        })}

        <span
          className="muted small"
          style={{
            marginLeft: 'auto',
            alignSelf: 'center',
          }}
        >
          {activeRange.label} ·
          facility-derived operating picture
        </span>
      </div>

      {/* =====================================================================
          1. TOP FINANCIAL POSITION
          ===================================================================== */}

      <div className="admin-tile-grid">
        {financialPosition.map((tile) => (
          <div
            key={tile.label}
            className={`admin-tile tile-${tile.tone}`}
          >
            <span className="tile-label">
              {tile.label}
            </span>

            <span className="tile-value">
              {formatKES(tile.value)}
            </span>

            <span className="tile-note">
              {tile.note}
            </span>
          </div>
        ))}
      </div>

      {/* =====================================================================
          2. FINANCIAL STATUS STRIP
          ===================================================================== */}

      <SectionCard
        title="Financial position"
        subtitle={`${activeRange.label} · revenue ≠ claims ≠ payments ≠ receivables`}
      >
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Indicator</th>
                <th>Value</th>
                <th>Status</th>
              </tr>
            </thead>

            <tbody>
              {statusStrip.map((row) => (
                <tr key={row.indicator}>
                  <td>{row.indicator}</td>

                  <td className="num">
                    {formatKES(row.value)}
                  </td>

                  <td>
                    <ToneDot tone={row.tone} />
                    {row.tone === 'ok'
                      ? 'On track'
                      : row.tone === 'warn'
                        ? 'Monitor'
                        : 'Attention'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>

      {/* =====================================================================
          3. FINANCIAL PIPELINE — Revenue → Claim → Payment
          ===================================================================== */}

      <SectionCard
        title="Revenue → Claim → Payment"
        subtitle="Billable activity flowing through the claim lifecycle (today)"
      >
        <div className="fac-pipeline">
          <div className="fac-pipe-node">
            <span className="fac-pipe-value">
              {formatKES(4_800_000)}
            </span>
            <span className="fac-pipe-label">
              Billable activity
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-value">
              {formatKES(2_100_000)}
            </span>
            <span className="fac-pipe-label">
              Submitted claims
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-value">
              {formatKES(1_800_000)}
            </span>
            <span className="fac-pipe-label">
              Accepted
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-value">
              {formatKES(1_200_000)}
            </span>
            <span className="fac-pipe-label">
              Paid
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node fac-pipe-remain">
            <span className="fac-pipe-value">
              {formatKES(600_000)}
            </span>
            <span className="fac-pipe-label">
              Pending settlement
            </span>
          </div>
        </div>

        <div className="fac-pipe-note">
          Gross charges (KES 4.8M) include cash and
          payer services. Claims (KES 2.1M) are the
          payer-represented subset. Accepted minus paid
          = KES 600K awaiting settlement.
        </div>
      </SectionCard>

      {/* =====================================================================
          4 + 5. SHA / PAYER CLAIMS + PAYER MIX
          ===================================================================== */}

      <div className="admin-grid-2">
        <SectionCard
          title="SHA / Payer Claims"
          subtitle="Current cycle · count and value kept separate"
        >
          <div className="admin-tile-grid" style={{ marginBottom: 8 }}>
            <div className="admin-tile">
              <span className="tile-label">
                Claims this cycle
              </span>
              <span className="tile-value">
                {formatCount(claimTotal)}
              </span>
              <span className="tile-note">
                {formatCount(CLAIM_CYCLE.accepted)} accepted ·{' '}
                {formatCount(CLAIM_CYCLE.pending)} pending ·{' '}
                {formatCount(CLAIM_CYCLE.rejected)} rejected
              </span>
            </div>

            <div className="admin-tile tile-brand">
              <span className="tile-label">
                Submitted value
              </span>
              <span className="tile-value">
                {formatKES(CLAIM_VALUE.submitted)}
              </span>
              <span className="tile-note">
                {formatKES(CLAIM_VALUE.accepted)} accepted
              </span>
            </div>
          </div>

          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>State</th>
                  <th>Claims</th>
                  <th>Value</th>
                </tr>
              </thead>

              <tbody>
                <tr>
                  <td>
                    <ToneDot tone="ok" />
                    Accepted
                  </td>
                  <td className="num">
                    {formatCount(CLAIM_CYCLE.accepted)}
                  </td>
                  <td className="num">
                    {formatKES(CLAIM_VALUE.accepted)}
                  </td>
                </tr>

                <tr>
                  <td>
                    <ToneDot tone="warn" />
                    Pending
                  </td>
                  <td className="num">
                    {formatCount(CLAIM_CYCLE.pending)}
                  </td>
                  <td className="num">
                    {formatKES(CLAIM_VALUE.pending)}
                  </td>
                </tr>

                <tr>
                  <td>
                    <ToneDot tone="bad" />
                    Rejected
                  </td>
                  <td className="num">
                    {formatCount(CLAIM_CYCLE.rejected)}
                  </td>
                  <td className="num">
                    {formatKES(CLAIM_VALUE.rejected)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </SectionCard>

        <SectionCard
          title="Payer mix"
          subtitle="Where gross charges originate · not all payers are SHA"
        >
          <div className="admin-bar-list">
            {PAYER_MIX.map((row) => {
              const share =
                payerTotal > 0
                  ? (row.amount / payerTotal) * 100
                  : 0;

              return (
                <div
                  className="admin-bar-row"
                  key={row.payer}
                >
                  <span className="admin-bar-label">
                    {row.payer}
                  </span>

                  <div
                    className="admin-bar-track"
                    aria-label={`${share.toFixed(1)}%`}
                  >
                    <div
                      className="admin-bar-fill"
                      style={{
                        width: `${share}%`,
                      }}
                    />
                  </div>

                  <span className="admin-bar-value num">
                    {formatKES(row.amount)}
                  </span>
                </div>
              );
            })}
          </div>

          <div className="fac-pipe-note">
            Payer mix sums to gross charges today
            ({formatKES(payerTotal)}).
          </div>
        </SectionCard>
      </div>

      {/* =====================================================================
          6 + 7. CLAIMS HEALTH + CLAIM EXCEPTIONS
          ===================================================================== */}

      <div className="admin-grid-2">
        <SectionCard
          title="Claims health"
          subtitle={`${formatCount(claimTotal)} submitted this cycle`}
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Signal</th>
                  <th>Share</th>
                  <th>Distribution</th>
                </tr>
              </thead>

              <tbody>
                <tr>
                  <td>
                    <ToneDot tone="ok" />
                    Acceptance
                  </td>
                  <td className="num">
                    {acceptanceRate}%
                  </td>
                  <td style={{ minWidth: 160 }}>
                    <div className="admin-bar-track">
                      <div
                        className="admin-bar-fill"
                        style={{
                          width: `${acceptanceRate}%`,
                          background: 'var(--good)',
                        }}
                      />
                    </div>
                  </td>
                </tr>

                <tr>
                  <td>
                    <ToneDot tone="warn" />
                    Pending
                  </td>
                  <td className="num">
                    {pendingRate}%
                  </td>
                  <td style={{ minWidth: 160 }}>
                    <div className="admin-bar-track">
                      <div
                        className="admin-bar-fill"
                        style={{
                          width: `${pendingRate}%`,
                          background: 'var(--warn)',
                        }}
                      />
                    </div>
                  </td>
                </tr>

                <tr>
                  <td>
                    <ToneDot tone="bad" />
                    Rejected
                  </td>
                  <td className="num">
                    {rejectedRate}%
                  </td>
                  <td style={{ minWidth: 160 }}>
                    <div className="admin-bar-track">
                      <div
                        className="admin-bar-fill"
                        style={{
                          width: `${rejectedRate}%`,
                          background: 'var(--bad)',
                        }}
                      />
                    </div>
                  </td>
                </tr>

                <tr>
                  <td>
                    <ToneDot tone="info" />
                    Unsubmitted eligible
                  </td>
                  <td className="num">1%</td>
                  <td style={{ minWidth: 160 }}>
                    <div className="admin-bar-track">
                      <div
                        className="admin-bar-fill"
                        style={{
                          width: '1%',
                          background: 'var(--border-strong)',
                        }}
                      />
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div className="fac-readiness">
            <strong>Claim readiness: {readiness}%</strong>
          </div>
        </SectionCard>

        <SectionCard
          title="Claim exceptions"
          subtitle="Why claims are failing — not a dead-end statistic"
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Exception</th>
                  <th>Claims</th>
                  <th>Value</th>
                </tr>
              </thead>

              <tbody>
                {CLAIM_EXCEPTIONS.map((row) => (
                  <tr key={row.kind}>
                    <td>
                      <ToneDot tone={row.level as 'ok' | 'warn' | 'bad' | 'info'} />
                      {row.kind}
                    </td>
                    <td className="num">
                      {formatCount(row.claims)}
                    </td>
                    <td className="num">
                      {formatKES(row.value)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="fac-action-row">
            <button type="button" className="admin-nav-btn">
              Open claims command →
            </button>

            <span className="muted small">
              Exceptions route to clinical documentation
              workflows — Finance never edits clinical data.
            </span>
          </div>
        </SectionCard>
      </div>

      {/* =====================================================================
          9 + 10. SERVICE ACTIVITY + REVENUE MIX (COMPUTED)
          ===================================================================== */}

      <div className="admin-grid-2">
        <SectionCard
          title="Service activity — today"
          subtitle="Encounters / transactions with gross charges"
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Service</th>
                  <th>Activity</th>
                  <th>Gross charges</th>
                </tr>
              </thead>

              <tbody>
                {SERVICES.map((row) => (
                  <tr key={row.service}>
                    <td className="mono">
                      {row.service}
                    </td>

                    <td className="num">
                      {formatCount(row.activity)}
                    </td>

                    <td className="num">
                      {formatKES(row.gross)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </SectionCard>

        <SectionCard
          title="Gross charge mix — today"
          subtitle="Computed from service charges · always sums to 100%"
        >
          <div className="admin-tile-grid" style={{ marginBottom: 8 }}>
            <div className="admin-tile tile-brand">
              <span className="tile-label">
                Gross charges
              </span>
              <span className="tile-value">
                {formatKES(revenueMixTotal)}
              </span>
              <span className="tile-note">
                100% of service charges today
              </span>
            </div>
          </div>

          <div className="admin-bar-list">
            {revenueMix.map((row) => (
              <div
                className="admin-bar-row"
                key={row.service}
              >
                <span className="admin-bar-label">
                  {row.service}
                </span>

                <div
                  className="admin-bar-track"
                  aria-label={`${row.share.toFixed(1)}%`}
                >
                  <div
                    className="admin-bar-fill"
                    style={{ width: `${row.share}%` }}
                  />
                </div>

                <span className="admin-bar-value num">
                  {row.share.toFixed(1)}%
                </span>
              </div>
            ))}
          </div>

          <div className="fac-pipe-note">
            Theatre: 6 procedures but a substantial share
            of financial activity.
          </div>
        </SectionCard>
      </div>

      {/* =====================================================================
          11 + 12. REVENUE TREND + RANGE SUMMARY
          ===================================================================== */}

      <div className="admin-grid-2">
        <SectionCard
          title="Revenue trend"
          subtitle="Is today's number actually unusual?"
        >
          <div className="admin-tile-grid" style={{ marginBottom: 8 }}>
            <div className="admin-tile tile-brand">
              <span className="tile-label">
                Today
              </span>
              <span className="tile-value">
                {formatKES(4_800_000)}
              </span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">
                7-day average
              </span>
              <span className="tile-value">
                {formatKES(4_300_000)}
              </span>
            </div>

            <div className="admin-tile tile-good">
              <span className="tile-label">
                Variance
              </span>
              <span className="tile-value">
                ↑ 11.6%
              </span>
            </div>
          </div>
        </SectionCard>

        <SectionCard
          title={`Financial position — ${activeRange.label}`}
          subtitle="Selected period aggregate"
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Indicator</th>
                  <th>Value</th>
                </tr>
              </thead>

              <tbody>
                <tr>
                  <td>Revenue</td>
                  <td className="num">
                    {formatKES(activeRange.grossCharges)}
                    {' '}
                    <span className="muted small">
                      {activeRange.trend}
                    </span>
                  </td>
                </tr>

                <tr>
                  <td>Claims submitted</td>
                  <td className="num">
                    {formatKES(activeRange.claimsSubmitted)}
                  </td>
                </tr>

                <tr>
                  <td>Claims accepted</td>
                  <td className="num">
                    {formatKES(activeRange.claimsSubmitted * 0.9)}
                  </td>
                </tr>

                <tr>
                  <td>Receivables</td>
                  <td className="num">
                    {formatKES(activeRange.receivables)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </SectionCard>
      </div>

      {/* =====================================================================
          13. RECEIVABLES AGING
          ===================================================================== */}

      <SectionCard
        title="Outstanding receivables"
        subtitle={`${formatKES(receivableTotal)} outstanding · aging context`}
      >
        <div className="admin-grid-2">
          <div className="admin-bar-list">
            {RECEIVABLES_AGING.map((row) => {
              const share =
                receivableTotal > 0
                  ? (row.value / receivableTotal) * 100
                  : 0;

              return (
                <div
                  className="admin-bar-row"
                  key={row.bucket}
                >
                  <span className="admin-bar-label">
                    {row.bucket}
                  </span>

                  <div
                    className="admin-bar-track"
                    aria-label={`${share.toFixed(1)}%`}
                  >
                    <div
                      className="admin-bar-fill"
                      style={{
                        width: `${share}%`,
                        background:
                          row.tone === 'ok'
                            ? 'var(--good)'
                            : row.tone === 'warn'
                              ? 'var(--warn)'
                              : 'var(--bad)',
                      }}
                    />
                  </div>

                  <span className="admin-bar-value num">
                    {formatKES(row.value)}
                  </span>
                </div>
              );
            })}
          </div>

          <div className="fac-attention">
            <div className="fac-attention-value">
              {formatKES(receivablesOver60)}
            </div>

            <div className="fac-attention-label">
              over 60 days — requires attention
            </div>

            <button type="button" className="admin-nav-btn">
              Review receivables →
            </button>
          </div>
        </div>
      </SectionCard>

      {/* =====================================================================
          15. SERVICE ECONOMICS
          ===================================================================== */}

      <SectionCard
        title="Service economics"
        subtitle="Clinical activity → financial activity → claims → cash"
      >
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Service</th>
                <th>Activity</th>
                <th>Gross charges</th>
                <th>Claims</th>
                <th>Pending</th>
              </tr>
            </thead>

            <tbody>
              {SERVICES.map((row) => (
                <tr key={row.service}>
                  <td className="mono">{row.service}</td>
                  <td className="num">{formatCount(row.activity)}</td>
                  <td className="num">{formatKES(row.gross)}</td>
                  <td className="num">
                    {row.claims === null
                      ? '—'
                      : formatCount(row.claims)}
                  </td>
                  <td className="num">
                    {row.pending === null
                      ? '—'
                      : formatCount(row.pending)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>

      {/* =====================================================================
          17 + 18. OPERATING EXPENDITURE + SUPPLIER COMMITMENTS
          ===================================================================== */}

      <div className="admin-grid-2">
        <SectionCard
          title="Operating expenditure"
          subtitle={`${formatKES(expenditureTotal)} today · no fabricated profit figure`}
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Value</th>
                </tr>
              </thead>

              <tbody>
                {EXPENDITURE.map((row) => (
                  <tr key={row.category}>
                    <td>{row.category}</td>
                    <td className="num">
                      {formatKES(row.value)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </SectionCard>

        <SectionCard
          title="Pending supplier commitments"
          subtitle={`${formatKES(supplierTotal)} · connects to Facility Ecosystem`}
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Value</th>
                </tr>
              </thead>

              <tbody>
                {SUPPLIER_COMMITMENTS.map((row) => (
                  <tr key={row.category}>
                    <td>{row.category}</td>
                    <td className="num">
                      {formatKES(row.value)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="fac-pipe-note">
            Pharmacy stock reorder → supplier →
            requisition → PO → receipt → inventory →
            financial liability.
          </div>
        </SectionCard>
      </div>

      {/* =====================================================================
          14. AMEXAN FINANCIAL INTELLIGENCE
          ===================================================================== */}

      <SectionCard
        title="AMEXAN Financial Intelligence"
        subtitle="What changed · why · where money is stuck · what requires action"
      >
        <div className="fac-intel-grid">
          {INTELLIGENCE.map((insight) => (
            <div
              key={insight.title}
              className={`fac-intel-card fac-intel-${insight.tone}`}
            >
              <div className="fac-intel-title">
                <ToneDot tone={insight.tone as 'ok' | 'warn' | 'bad'} />
                {insight.title}
              </div>

              <div className="fac-intel-detail">
                {insight.detail}
              </div>

              <div className="fac-intel-impact">
                <strong>Potential impact:</strong>{' '}
                {insight.impact}
              </div>

              <button type="button" className="admin-nav-btn">
                {insight.action}
              </button>
            </div>
          ))}
        </div>

        <div className="fac-pipe-note">
          Insights are derived from the financial data —
          never hand-authored placeholders.
        </div>
      </SectionCard>

      {/* =====================================================================
          20. PATIENT FINANCIAL BOUNDARY
          ===================================================================== */}

      <div className="fac-boundary">
        <strong>Patient financial boundary</strong>
        <span>
          This Facility Admin view shows aggregate facility
          financial operations. Opening an individual patient's
          bill, payer details, financial history or claim
          documents requires{' '}
          <strong>financial-access authorization</strong>.
        </span>
      </div>

      {/* =====================================================================
          ACTIONS
          ===================================================================== */}

      <SectionCard
        title="Actions"
        subtitle="Financial command surface for the Facility Administrator"
      >
        <div className="fac-action-chips">
          {ACTIONS.map((action) => (
            <button
              key={action}
              type="button"
              className="admin-nav-btn"
            >
              {action}
            </button>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}