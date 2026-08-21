// =============================================================================
// AMEXAN Research Intelligence — Governed Clinical Research Environment
//
// DEMO VIEW · FACILITY SCOPE · READ-ONLY
//
// This is a research governance and data-access CONTROL PLANE — NOT a page
// showing researchers everything the hospital knows.
//
// Central principle:
//   Clinical data belongs to patient care first. Research access is
//   purpose-bound, approved, minimized, auditable, and preferably
//   de-identified.
//
// NON-NEGOTIABLE RULES
//   1. Research Intelligence is not a second clinical database. It sits on
//      top of the clinical operating model and creates controlled research
//      representations from it.
//   2. Researchers never get direct database access
//      (researcher ❌ SELECT * FROM patients).
//   3. Approval creates a CONTROLLED DATASET ENTITLEMENT, not unrestricted
//      access to the underlying clinical database.
//   4. Eligibility ≠ enrollment. AMEXAN identifies potentially eligible
//      records; an authorized research workflow handles screening → consent
//      → enrollment.
//   5. Research data does not automatically become national reporting data.
//   6. A Facility Admin does NOT automatically browse participant identities.
// =============================================================================

import { useMemo, useState } from 'react';

// =============================================================================
// MOCK DEMO DATA
// =============================================================================

interface StudyRow {
  id: string;
  title: string;
  pi: string;
  participants: number;
  status: 'Active' | 'Recruiting';
  statusTone: 'ok' | 'warn';
  dataClass: string;
  governance: 'Approved' | 'Review';
  governanceTone: 'ok' | 'warn';
  expiry: string;
}

const STUDIES: StudyRow[] = [
  {
    id: 'RES-2026-004',
    title:
      'Determinants of neonatal sepsis outcomes in Kisii County',
    pi: 'Dr. R. Monari',
    participants: 214,
    status: 'Active',
    statusTone: 'ok',
    dataClass: 'Restricted clinical',
    governance: 'Approved',
    governanceTone: 'ok',
    expiry: '30 Nov 2026',
  },
  {
    id: 'RES-2026-011',
    title: 'AMR surveillance — Kisii Referral Laboratory',
    pi: 'Dr. B. Ogoti',
    participants: 388,
    status: 'Active',
    statusTone: 'ok',
    dataClass: 'Laboratory',
    governance: 'Approved',
    governanceTone: 'ok',
    expiry: '15 Jan 2027',
  },
  {
    id: 'RES-2026-018',
    title: 'Hypertension control in community clinics',
    pi: 'Dr. I. Bosibori',
    participants: 512,
    status: 'Active',
    statusTone: 'ok',
    dataClass: 'De-identified',
    governance: 'Approved',
    governanceTone: 'ok',
    expiry: '28 Feb 2027',
  },
  {
    id: 'RES-2026-023',
    title: 'Telemedicine follow-up for diabetes in OPD',
    pi: 'Dr. B. Kamau',
    participants: 146,
    status: 'Recruiting',
    statusTone: 'warn',
    dataClass: 'Restricted clinical',
    governance: 'Review',
    governanceTone: 'warn',
    expiry: '20 Mar 2027',
  },
];

interface DataRequest {
  id: string;
  requester: string;
  purpose: string;
  dataset: string;
  records: number;
  scope: string;
  identifiers: string;
}

const DATA_REQUESTS: DataRequest[] = [
  {
    id: 'REQ-2041',
    requester: 'Kisii Research Institute',
    purpose: '2024 hypertension cohort analysis',
    dataset: 'De-identified encounter dataset',
    records: 1_284,
    scope: 'Patients with hypertension',
    identifiers: 'None requested',
  },
  {
    id: 'REQ-2042',
    requester: 'Egerton University',
    purpose: 'AMR isolate characterisation',
    dataset: 'Laboratory AMR isolates',
    records: 388,
    scope: 'Microbiology results',
    identifiers: 'None',
  },
  {
    id: 'REQ-2043',
    requester: 'MOH Research Unit',
    purpose: 'Community clinic workload planning',
    dataset: 'Community clinic workload data',
    records: 0,
    scope: 'Aggregate counts only',
    identifiers: 'None',
  },
];

const DATA_PROTECTION = {
  datasetsGoverned: 10,
  deIdentificationConfigs: 10,
  unauthorizedExports: 0,
  configsRequiringReview: 2,
};

const CONTROLS = [
  'Direct identifiers',
  'Quasi-identifiers',
  'Dates',
  'Small-cell suppression',
  'Export controls',
  'Audit logging',
];

const PARTICIPANT_GOVERNANCE = {
  enrolled: 1_482,
  activeFollowUp: 1_421,
  completed: 61,
  consentValid: 1_472,
  consentReview: 10,
  withdrawals: 2,
  retentionExceptions: 1,
};

const DATA_ACTIVITY = {
  accessEvents: 14,
  exports: 3,
  unauthorizedAttempts: 0,
  accessReviews: 2,
};

const EXPORTS = [
  {
    label: 'Hypertension cohort',
    records: 1_284,
    deidentified: true,
    exported: '20 Aug · 16:42',
    requester: 'Kisii Research Institute',
    status: 'Approved',
    tone: 'ok' as const,
  },
  {
    label: 'AMR dataset',
    records: 388,
    deidentified: true,
    exported: 'Pending',
    requester: 'Egerton University',
    status: 'Governance review',
    tone: 'warn' as const,
  },
];

const RESEARCH_INTELLIGENCE = [
  {
    tone: 'warn' as const,
    title: 'Governance',
    detail:
      '10 participants in one study have consent records requiring review.',
    action: 'Review →',
  },
  {
    tone: 'warn' as const,
    title: 'Data request',
    detail:
      'One requested dataset contains more granular dates than the current minimization policy allows.',
    action: 'Review request →',
  },
  {
    tone: 'ok' as const,
    title: 'Research capacity',
    detail:
      '4 active studies are currently recruiting through OPD and maternity workflows.',
    action: undefined,
  },
  {
    tone: 'info' as const,
    title: 'Operational impact',
    detail:
      'Three studies currently request data from laboratory workflows with high operational demand.',
    action: 'Assess impact →',
  },
];

interface StudyDetail {
  title: string;
  id: string;
  status: 'Active' | 'Recruiting';
  pi: string;
  institution: string;
  participants: number;
  recruitment: string;
  protocolApproval: string;
  dataUseApproval: string;
  dataClass: string;
  deIdentification: string;
  expiry: string;
  nextReview: string;
  approvedDatasets: string[];
}

const STUDY_DETAIL: StudyDetail = {
  title: 'Determinants of neonatal sepsis outcomes',
  id: 'RES-2026-004',
  status: 'Active',
  pi: 'Dr. R. Monari',
  institution: 'Kisii Teaching & Referral Hospital',
  participants: 214,
  recruitment: 'Active',
  protocolApproval: 'Valid',
  dataUseApproval: 'Valid',
  dataClass: 'Restricted clinical',
  deIdentification: 'Configured',
  expiry: '30 Nov 2026',
  nextReview: '15 Nov 2026',
  approvedDatasets: [
    'Neonatal admission dataset',
    'Laboratory dataset',
    'Outcome dataset',
  ],
};

const RESTRICTED_FIELDS = [
  'Patient identifiers',
  'Phone numbers',
  'National identifiers',
  'Full addresses',
  'Direct contact information',
];

const APPROVAL_LIFECYCLE = [
  'PROTOCOL SUBMITTED',
  'GOVERNANCE REVIEW',
  'ETHICS / REGULATORY STATUS',
  'FACILITY APPROVAL',
  'DATA ACCESS APPROVAL',
  'DATASET CREATED',
  'RESEARCH ACTIVE',
  'MONITORING',
  'CLOSE-OUT',
  'RETENTION / DESTRUCTION',
];

const DATA_CLASSES = [
  {
    name: 'Aggregate',
    sensitivity: 'Lowest sensitivity',
    example: '128 pneumonia admissions in July.',
  },
  {
    name: 'De-identified',
    sensitivity: 'Patient-level analysis without direct identifiers',
    example: undefined,
  },
  {
    name: 'Pseudonymized',
    sensitivity: 'Linkable under controlled conditions',
    example: undefined,
  },
  {
    name: 'Restricted clinical',
    sensitivity: 'Potentially identifiable or highly sensitive',
    example: undefined,
  },
  {
    name: 'Directly identifiable',
    sensitivity: 'Strongest access controls',
    example: undefined,
  },
];

const ECOSYSTEM = [
  {
    org: 'KTRH',
    relationship: 'Host facility',
    agreement: 'Institutional policy',
    status: 'Current',
    tone: 'ok' as const,
    datasets: 'Facility clinical representations',
  },
  {
    org: 'Kisii Medical Laboratory',
    relationship: 'Data-sharing partner',
    agreement: 'Data-use agreement',
    status: 'Current',
    tone: 'ok' as const,
    datasets: 'AMR isolate dataset',
  },
  {
    org: 'Egerton University',
    relationship: 'Research collaborator',
    agreement: 'Data-use agreement',
    status: 'Review',
    tone: 'warn' as const,
    datasets: 'Laboratory AMR isolates',
  },
  {
    org: 'Kisii Research Institute',
    relationship: 'External requester',
    agreement: 'Data-sharing agreement',
    status: 'Current',
    tone: 'ok' as const,
    datasets: 'De-identified encounter dataset',
  },
];

// =============================================================================
// FORMATTERS
// =============================================================================

function formatCount(value: number): string {
  return value.toLocaleString();
}

// =============================================================================
// PRESENTATIONAL COMPONENTS
// =============================================================================

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

// =============================================================================
// RESEARCH VIEW
// =============================================================================

export function ResearchView({
  onBack,
}: {
  onBack: () => void;
}) {
  const [selectedStudy, setSelectedStudy] =
    useState<StudyRow | null>(null);

  const [selectedRequest, setSelectedRequest] =
    useState<DataRequest | null>(null);

  const consentRate = useMemo(() => {
    const total =
      PARTICIPANT_GOVERNANCE.consentValid +
      PARTICIPANT_GOVERNANCE.consentReview;

    return total > 0
      ? Math.round(
          (PARTICIPANT_GOVERNANCE.consentValid /
            total) *
            100,
        )
      : 0;
  }, []);

  const governanceItems =
    STUDIES.filter(
      (study) =>
        study.governanceTone === 'warn',
    ).length +
    PARTICIPANT_GOVERNANCE.consentReview;

  const tiles = [
    {
      label: 'Active studies',
      value: formatCount(12),
      note: 'Approved / active research protocols',
      tone: 'brand',
    },
    {
      label: 'Participants enrolled',
      value: formatCount(
        PARTICIPANT_GOVERNANCE.enrolled,
      ),
      note: 'Across active facility studies',
      tone: 'neutral',
    },
    {
      label: 'Governance reviews',
      value: formatCount(governanceItems),
      note: 'Requiring administrative / governance action',
      tone: 'warn',
    },
    {
      label: 'Data requests',
      value: formatCount(DATA_REQUESTS.length + 4),
      note: 'Open research data-access requests',
      tone: 'warn',
    },
    {
      label: 'Governance compliance',
      value: '98%',
      note: '2 items require attention',
      tone: 'good',
    },
  ];

  const governanceStrip = [
    {
      label: 'Protocol approvals',
      value: '12/12',
      tone: 'ok' as const,
    },
    {
      label: 'Data-use agreements current',
      value: '11/12',
      tone: 'warn' as const,
    },
    {
      label: 'De-identification validated',
      value: '10/12',
      tone: 'warn' as const,
    },
    {
      label: 'Unauthorized exports',
      value: '0',
      tone: 'ok' as const,
    },
    {
      label: 'Access requests',
      value: formatCount(
        DATA_REQUESTS.length + 4,
      ),
      tone: 'warn' as const,
    },
  ];

  return (
    <div className="admin-research">
      {/* =====================================================================
          CONTEXT BAR
          ===================================================================== */}

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
                Governed clinical research environment
              </div>

              <div className="admin-panel-sub">
                Studies · Participants · Data requests ·
                Approvals · De-identification · Governance
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

      {/* =====================================================================
          1. RESEARCH GOVERNANCE HEALTH
          ===================================================================== */}

      <div className="admin-tile-grid">
        {tiles.map((tile) => (
          <div
            key={tile.label}
            className={`admin-tile tile-${tile.tone}`}
          >
            <span className="tile-label">
              {tile.label}
            </span>

            <span className="tile-value">
              {tile.value}
            </span>

            <span className="tile-note">
              {tile.note}
            </span>
          </div>
        ))}
      </div>

      {/* =====================================================================
          2. GOVERNANCE STATUS STRIP
          ===================================================================== */}

      <SectionCard
        title="Research governance"
        subtitle="12 active studies · is research inside this hospital under control?"
      >
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Signal</th>
                <th>Value</th>
                <th>Status</th>
              </tr>
            </thead>

            <tbody>
              {governanceStrip.map((row) => (
                <tr key={row.label}>
                  <td>{row.label}</td>
                  <td className="num">
                    {row.value}
                  </td>
                  <td>
                    <ToneDot tone={row.tone} />
                    {row.tone === 'ok'
                      ? 'On track'
                      : 'Attention'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>

      {/* =====================================================================
          3. ACTIVE STUDIES
          ===================================================================== */}

      <SectionCard
        title="Active studies"
        subtitle="Approved / recruiting research protocols"
      >
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Study</th>
                <th>PI</th>
                <th>Participants</th>
                <th>Status</th>
                <th>Data class</th>
                <th>Governance</th>
              </tr>
            </thead>

            <tbody>
              {STUDIES.map((study) => (
                <tr
                  key={study.id}
                  className="admin-row-click"
                  onClick={() =>
                    setSelectedStudy(study)
                  }
                >
                  <td>
                    <span className="mono">
                      {study.title}
                    </span>
                    <span
                      className="muted small"
                      style={{ display: 'block' }}
                    >
                      {study.id}
                    </span>
                  </td>

                  <td>{study.pi}</td>

                  <td className="num">
                    {formatCount(
                      study.participants,
                    )}
                  </td>

                  <td>
                    <ToneDot tone={study.statusTone} />
                    {study.status}
                  </td>

                  <td className="mono">
                    {study.dataClass}
                  </td>

                  <td>
                    <ToneDot tone={study.governanceTone} />
                    {study.governance}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="fac-action-row">
          <button type="button" className="admin-nav-btn">
            Open study →
          </button>

          <span className="muted small">
            Click a study to open its governed workspace.
          </span>
        </div>
      </SectionCard>

      {/* =====================================================================
          4 + 5. STUDY DETAIL + DATA ACCESS (governed workspace)
          ===================================================================== */}

      {selectedStudy ? (
        <SectionCard
          title={STUDY_DETAIL.title}
          subtitle={`Study ID: ${STUDY_DETAIL.id} · ${STUDY_DETAIL.status}`}
          actions={
            <button
              type="button"
              className="admin-nav-btn"
              onClick={() =>
                setSelectedStudy(null)
              }
            >
              Close study →
            </button>
          }
        >
          <div className="admin-grid-2">
            <div className="admin-kv">
              <span className="k">
                Principal Investigator
              </span>
              <span className="v">
                {STUDY_DETAIL.pi}
              </span>

              <span className="k">Institution</span>
              <span className="v">
                {STUDY_DETAIL.institution}
              </span>

              <span className="k">Participants</span>
              <span className="v">
                {formatCount(
                  STUDY_DETAIL.participants,
                )}
              </span>

              <span className="k">Recruitment</span>
              <span className="v">
                {STUDY_DETAIL.recruitment}
              </span>

              <span className="k">
                Protocol approval
              </span>
              <span className="v">
                <ToneDot tone="ok" />
                {STUDY_DETAIL.protocolApproval}
              </span>

              <span className="k">
                Data-use approval
              </span>
              <span className="v">
                <ToneDot tone="ok" />
                {STUDY_DETAIL.dataUseApproval}
              </span>

              <span className="k">
                Data classification
              </span>
              <span className="v">
                {STUDY_DETAIL.dataClass}
              </span>

              <span className="k">
                De-identification
              </span>
              <span className="v">
                <ToneDot tone="ok" />
                {STUDY_DETAIL.deIdentification}
              </span>

              <span className="k">
                Expiry / review
              </span>
              <span className="v">
                {STUDY_DETAIL.expiry}
              </span>

              <span className="k">Next review</span>
              <span className="v">
                {STUDY_DETAIL.nextReview}
              </span>
            </div>

            <div>
              <div className="admin-panel-sub" style={{ marginBottom: 8 }}>
                Approved datasets
              </div>

              <div className="fac-approve-list">
                {STUDY_DETAIL.approvedDatasets.map(
                  (dataset) => (
                    <div
                      className="fac-approve-item"
                      key={dataset}
                    >
                      <span>
                        {dataset}
                      </span>

                      <span className="admin-badge brand">
                        De-identified
                      </span>
                    </div>
                  ),
                )}
              </div>

              <div className="fac-pipe-note">
                Restricted fields —{' '}
                <strong>Access: Not granted</strong>
              </div>

              <div className="fac-restricted">
                {RESTRICTED_FIELDS.map((field) => (
                  <span
                    className="admin-badge bad"
                    key={field}
                  >
                    {field}
                  </span>
                ))}
              </div>

              <div className="fac-boundary" style={{ marginTop: 10 }}>
                <strong>Approval validity</strong>
                <span>
                  Valid until {STUDY_DETAIL.expiry}.
                  Study {STUDY_DETAIL.id} requires
                  governance review before{' '}
                  {STUDY_DETAIL.nextReview}.
                </span>
              </div>
            </div>
          </div>
        </SectionCard>
      ) : null}

      {/* =====================================================================
          6 + 7. DATA REQUESTS + REVIEW REQUEST
          ===================================================================== */}

      {selectedRequest ? (
        <SectionCard
          title="Data Access Request"
          subtitle={`${selectedRequest.id} · governance review`}
          actions={
            <button
              type="button"
              className="admin-nav-btn"
              onClick={() =>
                setSelectedRequest(null)
              }
            >
              Back to requests →
            </button>
          }
        >
          <div className="admin-grid-2">
            <div className="admin-kv">
              <span className="k">Requester</span>
              <span className="v">
                {selectedRequest.requester}
              </span>

              <span className="k">Purpose</span>
              <span className="v">
                {selectedRequest.purpose}
              </span>

              <span className="k">
                Requested dataset
              </span>
              <span className="v">
                {selectedRequest.dataset}
              </span>

              <span className="k">
                Requested population
              </span>
              <span className="v">
                {selectedRequest.scope}
              </span>

              <span className="k">
                Identifiers requested
              </span>
              <span className="v">
                {selectedRequest.identifiers}
              </span>

              <span className="k">
                Population size
              </span>
              <span className="v">
                {selectedRequest.records > 0
                  ? `${formatCount(selectedRequest.records)} records`
                  : 'Aggregate only'}
              </span>
            </div>

            <div>
              <div className="admin-kv">
                <span className="k">
                  Data minimization
                </span>
                <span className="v">
                  <ToneDot tone="ok" />
                  Satisfied
                </span>

                <span className="k">
                  De-identification
                </span>
                <span className="v">
                  <ToneDot tone="ok" />
                  Required and configured
                </span>

                <span className="k">
                  Geographic granularity
                </span>
                <span className="v">
                  County / facility
                </span>

                <span className="k">Retention</span>
                <span className="v">
                  12 months
                </span>

                <span className="k">Export</span>
                <span className="v">
                  Restricted
                </span>
              </div>

              <div className="fac-pipe-note">
                Approval does not grant unrestricted
                access to the underlying clinical
                database. It creates a{' '}
                <strong>controlled dataset entitlement</strong>.
              </div>
            </div>
          </div>

          <div className="fac-decision">
            <button type="button" className="admin-nav-btn">
              Approve
            </button>

            <button type="button" className="admin-nav-btn">
              Reject
            </button>

            <button type="button" className="admin-nav-btn">
              Request modification
            </button>
          </div>
        </SectionCard>
      ) : (
        <SectionCard
          title="Data requests awaiting governance"
          subtitle="Review is a governed workflow — not a casual button"
        >
          <div className="fac-request-grid">
            {DATA_REQUESTS.map((request) => (
              <div
                className="fac-request-card"
                key={request.id}
              >
                <div className="fac-request-title">
                  {request.dataset}
                </div>

                <div className="admin-kv">
                  <span className="k">Requester</span>
                  <span className="v">
                    {request.requester}
                  </span>

                  <span className="k">Purpose</span>
                  <span className="v">
                    {request.purpose}
                  </span>

                  <span className="k">
                    Identifiers
                  </span>
                  <span className="v">
                    {request.identifiers}
                  </span>
                </div>

                <div className="fac-request-status">
                  <ToneDot tone="warn" />
                  Pending governance review
                </div>

                <button
                  type="button"
                  className="admin-nav-btn"
                  onClick={() =>
                    setSelectedRequest(request)
                  }
                >
                  Review request →
                </button>
              </div>
            ))}
          </div>
        </SectionCard>
      )}

      {/* =====================================================================
          9. DE-IDENTIFICATION CENTER
          ===================================================================== */}

      <SectionCard
        title="Data protection"
        subtitle="De-identification is governed and configurable — not a single 'anonymised' label"
      >
        <div className="admin-tile-grid">
          <div className="admin-tile">
            <span className="tile-label">
              Datasets governed
            </span>
            <span className="tile-value">
              {formatCount(
                DATA_PROTECTION.datasetsGoverned,
              )}
            </span>
          </div>

          <div className="admin-tile">
            <span className="tile-label">
              De-identification configs
            </span>
            <span className="tile-value">
              {formatCount(
                DATA_PROTECTION.deIdentificationConfigs,
              )}
            </span>
          </div>

          <div className="admin-tile tile-good">
            <span className="tile-label">
              Unauthorized exports
            </span>
            <span className="tile-value">
              {formatCount(
                DATA_PROTECTION.unauthorizedExports,
              )}
            </span>
          </div>

          <div className="admin-tile tile-warn">
            <span className="tile-label">
              Configs requiring review
            </span>
            <span className="tile-value">
              {formatCount(
                DATA_PROTECTION.configsRequiringReview,
              )}
            </span>
          </div>
        </div>

        <div className="admin-grid-2">
          <div className="admin-panel-sub" style={{ marginBottom: 8 }}>
            Current controls
          </div>

          <div />
        </div>

        <div className="fac-controls">
          {CONTROLS.map((control) => (
            <span
              className="admin-badge good"
              key={control}
            >
              <ToneDot tone="ok" />
              {control}
            </span>
          ))}
        </div>
      </SectionCard>

      {/* =====================================================================
          10. DATA CLASSIFICATION
          ===================================================================== */}

      <SectionCard
        title="Data classification"
        subtitle="Not all research data is equivalent"
      >
        <div className="fac-class-grid">
          {DATA_CLASSES.map((item, index) => (
            <div
              className="fac-class-card"
              key={item.name}
            >
              <div className="fac-class-rank">
                {index + 1}
              </div>

              <div className="fac-class-name">
                {item.name}
              </div>

              <div className="fac-class-sens">
                {item.sensitivity}
              </div>

              {item.example && (
                <div className="fac-class-example">
                  {item.example}
                </div>
              )}
            </div>
          ))}
        </div>
      </SectionCard>

      {/* =====================================================================
          12. PARTICIPANT GOVERNANCE
          ===================================================================== */}

      <SectionCard
        title="Participant governance"
        subtitle="Are participant rights and study obligations being respected?"
      >
        <div className="admin-grid-2">
          <div className="admin-tile-grid">
            <div className="admin-tile tile-brand">
              <span className="tile-label">
                Enrolled
              </span>
              <span className="tile-value">
                {formatCount(
                  PARTICIPANT_GOVERNANCE.enrolled,
                )}
              </span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">
                Active follow-up
              </span>
              <span className="tile-value">
                {formatCount(
                  PARTICIPANT_GOVERNANCE.activeFollowUp,
                )}
              </span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">
                Completed
              </span>
              <span className="tile-value">
                {formatCount(
                  PARTICIPANT_GOVERNANCE.completed,
                )}
              </span>
            </div>

            <div className="admin-tile tile-warn">
              <span className="tile-label">
                Consent requires review
              </span>
              <span className="tile-value">
                {formatCount(
                  PARTICIPANT_GOVERNANCE.consentReview,
                )}
              </span>
            </div>

            <div className="admin-tile tile-warn">
              <span className="tile-label">
                Withdrawal requests
              </span>
              <span className="tile-value">
                {formatCount(
                  PARTICIPANT_GOVERNANCE.withdrawals,
                )}
              </span>
            </div>
          </div>

          <div>
            <div className="admin-panel-sub" style={{ marginBottom: 8 }}>
              Consent status
            </div>

            <div className="admin-bar-list">
              <div className="admin-bar-row">
                <span className="admin-bar-label">
                  Valid consent
                </span>

                <div
                  className="admin-bar-track"
                  aria-label={`${consentRate}%`}
                >
                  <div
                    className="admin-bar-fill"
                    style={{
                      width: `${consentRate}%`,
                      background: 'var(--good)',
                    }}
                  />
                </div>

                <span className="admin-bar-value num">
                  {formatCount(
                    PARTICIPANT_GOVERNANCE.consentValid,
                  )}
                </span>
              </div>

              <div className="admin-bar-row">
                <span className="admin-bar-label">
                  Require review
                </span>

                <div
                  className="admin-bar-track"
                  aria-label={`${
                    100 - consentRate
                  }%`}
                >
                  <div
                    className="admin-bar-fill"
                    style={{
                      width: `${100 - consentRate}%`,
                      background: 'var(--warn)',
                    }}
                  />
                </div>

                <span className="admin-bar-value num">
                  {formatCount(
                    PARTICIPANT_GOVERNANCE.consentReview,
                  )}
                </span>
              </div>
            </div>

            <div className="fac-pipe-note">
              Data retention exceptions:{' '}
              {formatCount(
                PARTICIPANT_GOVERNANCE.retentionExceptions,
              )}{' '}
              — review required.
            </div>
          </div>
        </div>
      </SectionCard>

      {/* =====================================================================
          13. APPROVAL LIFECYCLE
          ===================================================================== */}

      <SectionCard
        title="Study approval lifecycle"
        subtitle="'Active' is not a single boolean"
      >
        <div className="fac-lifecycle">
          {APPROVAL_LIFECYCLE.map((step, index) => (
            <div className="fac-life-step" key={step}>
              <span className="fac-life-index">
                {index + 1}
              </span>
              <span className="fac-life-label">
                {step}
              </span>
            </div>
          ))}
        </div>
      </SectionCard>

      {/* =====================================================================
          15 + 16. RESEARCH DATA ACTIVITY + EXPORTS
          ===================================================================== */}

      <div className="admin-grid-2">
        <SectionCard
          title="Research data activity"
          subtitle="Who accessed which approved dataset, for which study, and when?"
        >
          <div className="admin-tile-grid">
            <div className="admin-tile tile-brand">
              <span className="tile-label">
                Dataset access events
              </span>
              <span className="tile-value">
                {formatCount(DATA_ACTIVITY.accessEvents)}
              </span>
              <span className="tile-note">
                today
              </span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">
                Dataset exports
              </span>
              <span className="tile-value">
                {formatCount(DATA_ACTIVITY.exports)}
              </span>
              <span className="tile-note">
                today
              </span>
            </div>

            <div className="admin-tile tile-good">
              <span className="tile-label">
                Unauthorized attempts
              </span>
              <span className="tile-value">
                {formatCount(
                  DATA_ACTIVITY.unauthorizedAttempts,
                )}
              </span>
            </div>

            <div className="admin-tile">
              <span className="tile-label">
                Access reviews
              </span>
              <span className="tile-value">
                {formatCount(DATA_ACTIVITY.accessReviews)}
              </span>
            </div>
          </div>

          <button type="button" className="admin-nav-btn">
            Open research audit →
          </button>
        </SectionCard>

        <SectionCard
          title="Recent exports"
          subtitle="Every export is an auditable event"
        >
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Dataset</th>
                  <th>Records</th>
                  <th>Status</th>
                </tr>
              </thead>

              <tbody>
                {EXPORTS.map((row) => (
                  <tr key={row.label}>
                    <td>
                      <span className="mono">
                        {row.label}
                      </span>
                      <span
                        className="muted small"
                        style={{ display: 'block' }}
                      >
                        {row.requester}
                      </span>
                    </td>

                    <td className="num">
                      {formatCount(row.records)}
                    </td>

                    <td>
                      <ToneDot tone={row.tone} />
                      {row.status}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="fac-pipe-note">
            Exports are logged, de-identified where
            configured, and traceable to their study and
            requester.
          </div>
        </SectionCard>
      </div>

      {/* =====================================================================
          17. AMEXAN RESEARCH INTELLIGENCE
          ===================================================================== */}

      <SectionCard
        title="AMEXAN Research Intelligence"
        subtitle="What studies are active · what data is requested · who is allowed · what needs attention"
      >
        <div className="fac-intel-grid">
          {RESEARCH_INTELLIGENCE.map((insight) => (
            <div
              key={insight.title}
              className={`fac-intel-card fac-intel-${insight.tone}`}
            >
              <div className="fac-intel-title">
                <ToneDot tone={insight.tone} />
                {insight.title}
              </div>

              <div className="fac-intel-detail">
                {insight.detail}
              </div>

              {insight.action && (
                <button
                  type="button"
                  className="admin-nav-btn"
                >
                  {insight.action}
                </button>
              )}
            </div>
          ))}
        </div>
      </SectionCard>

      {/* =====================================================================
          20. RESEARCH ↔ FACILITY ECOSYSTEM
          ===================================================================== */}

      <SectionCard
        title="Research ↔ Facility Ecosystem"
        subtitle="Organizations have defined data-sharing relationships, not just names"
      >
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Organization</th>
                <th>Relationship</th>
                <th>Agreement</th>
                <th>Governance</th>
                <th>Approved datasets</th>
              </tr>
            </thead>

            <tbody>
              {ECOSYSTEM.map((row) => (
                <tr key={row.org}>
                  <td className="mono">
                    {row.org}
                  </td>

                  <td>{row.relationship}</td>

                  <td>{row.agreement}</td>

                  <td>
                    <ToneDot tone={row.tone} />
                    {row.status}
                  </td>

                  <td className="mono">
                    {row.datasets}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </SectionCard>

      {/* =====================================================================
          11 + 18. PATIENT-LEVEL BOUNDARY + CLINICAL SEPARATION
          ===================================================================== */}

      <div className="fac-boundary">
        <strong>
          Patient-level research access boundary
        </strong>
        <span>
          This Facility Admin view shows enrollment and
          governance aggregates. It does{' '}
          <strong>not</strong> grant automatic access to
          research participant identities, bills, or
          clinical records. Patient-level access is
          routed through an explicitly authorized
          research workspace with purpose-bound
          entitlement.
        </span>
      </div>

      <div className="fac-boundary">
        <strong>Research cannot change clinical care</strong>
        <span>
          Research cannot alter diagnoses, treatment,
          patient queues, encounter documentation,
          laboratory results, or medication orders —
          unless the study itself has an appropriately
          authorized clinical intervention workflow.
          Research data never automatically becomes
          national reporting data.
        </span>
      </div>

      {/* =====================================================================
          RESEARCH DATA PIPELINE
          ===================================================================== */}

      <SectionCard
        title="Research representation pipeline"
        subtitle="Clinical source of truth → controlled research workspace"
      >
        <div className="fac-pipeline">
          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Clinical source of truth
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Eligibility engine
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Research dataset definition
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Minimization
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              De-identification / pseudonymization
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Governance approval
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Controlled dataset
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Research workspace
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Audited access / export
            </span>
          </div>

          <div className="fac-pipe-arrow">↓</div>

          <div className="fac-pipe-node">
            <span className="fac-pipe-label">
              Study close-out
            </span>
          </div>
        </div>

        <div className="fac-pipe-note">
          The researcher gets the{' '}
          <strong>approved representation</strong>, never
          the source-of-truth clinical database.
        </div>
      </SectionCard>
    </div>
  );
}