import type {
  EnhancedClinicalRuntimeProjection,
  WorkspaceSectionProjection,
  WorkspaceSubsectionProjection,
  WorkspaceSectionState,
  ClinicalFormatPlan,
  ClinicalUIState,
} from '../../types';
import { ChartIcon } from '../Icons';

interface ClinicalStatePanelProps {
  projection: EnhancedClinicalRuntimeProjection;
  uiState?: ClinicalUIState | null;
}

const UNIVERSAL_SECTIONS = new Set([
  'BIODATA',
  'CC',
  'HPI',
  'PMHX',
  'PSHX',
  'FAMHX',
  'ROS',
  'SUMMARY',
]);

const FORMAT_SECTIONS: Record<string, Set<string>> = {
  ADULT_MEDICAL: new Set([
    'GENERAL_EXAMINATION',
    'SYSTEMIC_EXAMINATION',
    'INVESTIGATIONS',
    'ASSESSMENT',
    'DIFFERENTIAL_DIAGNOSIS',
    'MANAGEMENT',
    'MONITORING',
    'DOCUMENTATION',
  ]),

  ADULT_SURGICAL: new Set([
    'GENERAL_EXAMINATION',
    'SYSTEMIC_EXAMINATION',
    'INVESTIGATIONS',
    'ASSESSMENT',
    'DIFFERENTIAL_DIAGNOSIS',
    'MANAGEMENT',
    'MONITORING',
    'DOCUMENTATION',
  ]),

  PEDIATRIC: new Set([
    'GENERAL_EXAMINATION',
    'SYSTEMIC_EXAMINATION',
    'GROWTH_PARAMETERS',
    'VITALS',
    'INVESTIGATIONS',
    'ASSESSMENT',
    'DDX',
    'MANAGEMENT',
    'MONITORING',
    'DOCUMENTATION',
  ]),

  OBGYN: new Set([
    'MATERNAL_VITALS',
    'OBSTETRIC_EXAMINATION',
    'SYSTEMIC_EXAMINATION',
    'FETAL_ASSESSMENT',
    'INVESTIGATIONS',
    'ASSESSMENT',
    'DDX',
    'MANAGEMENT',
    'MONITORING',
    'DOCUMENTATION',
  ]),

  PSYCHIATRY: new Set([
    'PSYCHIATRIC_HISTORY',
    'MENTAL_STATE_EXAMINATION',
    'RISK_ASSESSMENT',
    'INSIGHT_JUDGEMENT',
    'FORMULATION',
    'DIFFERENTIAL_DIAGNOSIS',
    'INVESTIGATIONS',
    'MANAGEMENT',
    'SAFETY_PLAN',
    'FOLLOW_UP_MONITORING',
    'DOCUMENTATION',
  ]),

  NEONATAL: new Set([
    'MATERNAL_HISTORY',
    'ANTENATAL_HISTORY',
    'BIRTH_HISTORY',
    'IMMEDIATE_NEONATAL_HISTORY',
    'POSTNATAL_HISTORY',
    'FEEDING_HISTORY',
    'IMMUNIZATION_PROPHYLAXIS',
    'GROWTH',
    'DEVELOPMENT_NEUROBEHAVIOUR',
    'FAMILY_HISTORY',
    'ROS_NEONATAL',
    'SUMMARY',
    'DOCUMENTATION',
  ]),
};

export function ClinicalStatePanel({
  projection,
  uiState: _uiState,
}: ClinicalStatePanelProps) {
  if (!projection) {
    return null;
  }

  const formatPlan = projection.formatPlan;
  const sections = projection.navigation?.sections ?? [];

  const relevantSections = sections.filter((section) =>
    isSectionRelevantToFormat(section.sectionCode, formatPlan),
  );

  if (relevantSections.length === 0) {
    return null;
  }

  return (
    <section className="clinical-state-panel" aria-label="Clinical state">
      <header className="state-header">
        <div className="state-title">
          <span className="section-icon" aria-hidden="true">
            <ChartIcon size={16} />
          </span>

          <div>
            <h3>Clinical State</h3>
            <span className="muted small">
              Live clinical workspace state
            </span>
          </div>
        </div>

        <FormatBadge formatPlan={formatPlan} />
      </header>

      <div className="state-summary">
        <StateSummary sections={relevantSections} />
      </div>

      <div className="state-sections">
        {relevantSections.map((section) => (
          <StateSection
            key={section.sectionCode}
            section={section}
          />
        ))}
      </div>
    </section>
  );
}

function FormatBadge({
  formatPlan,
}: {
  formatPlan?: ClinicalFormatPlan | null;
}) {
  if (!formatPlan) {
    return (
      <span className="state-format-badge">
        Clinical format
      </span>
    );
  }

  const context: string[] = [];

  if (formatPlan.ageBand) {
    context.push(formatPlan.ageBand);
  }

  if (formatPlan.sex) {
    context.push(formatPlan.sex);
  }

  if (formatPlan.gestationalAge) {
    context.push(formatPlan.gestationalAge);
  }

  if (formatPlan.pregnant) {
    context.push('Pregnant');
  }

  return (
    <div className="state-format-badge">
      <span className="format-base">
        {formatPlan.baseFormat}
      </span>

      {context.length > 0 && (
        <div className="format-context">
          {context.map((item) => (
            <span key={item} className="context-chip">
              {item}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

function StateSummary({
  sections,
}: {
  sections: WorkspaceSectionProjection[];
}) {
  const totalRequired = sections.reduce(
    (total, section) => total + getNumber(section.requiredTotal),
    0,
  );

  const remainingRequired = sections.reduce(
    (total, section) => total + getNumber(section.requiredRemaining),
    0,
  );

  const completed = sections.filter(
    (section) => section.state === 'complete',
  ).length;

  const attention = sections.filter(
    (section) => section.state === 'attention',
  ).length;

  const completion =
    totalRequired > 0
      ? Math.round(
          ((totalRequired - remainingRequired) / totalRequired) * 100,
        )
      : 0;

  return (
    <div className="state-summary-grid">
      <div className="state-metric">
        <span className="state-metric-value">
          {Math.max(0, completion)}%
        </span>
        <span className="state-metric-label">Progress</span>
      </div>

      <div className="state-metric">
        <span className="state-metric-value">
          {completed}
        </span>
        <span className="state-metric-label">Complete</span>
      </div>

      <div className="state-metric">
        <span className="state-metric-value">
          {remainingRequired}
        </span>
        <span className="state-metric-label">Required remaining</span>
      </div>

      <div className={`state-metric ${attention > 0 ? 'attention' : ''}`}>
        <span className="state-metric-value">
          {attention}
        </span>
        <span className="state-metric-label">Attention</span>
      </div>
    </div>
  );
}

function StateSection({
  section,
}: {
  section: WorkspaceSectionProjection;
}) {
  const children = (section.children ?? []).filter((child) =>
    childIsRelevant(child),
  );

  const remaining = getNumber(section.requiredRemaining);
  const total = getNumber(section.requiredTotal);

  return (
    <article
      className={`state-section state-${section.state}`}
      data-section-code={section.sectionCode}
    >
      <header className="state-section-header">
        <div className="state-section-main">
          <span
            className={`state-indicator state-indicator-${section.state}`}
            aria-hidden="true"
          />

          <div>
            <h4 className="section-label">
              {section.label}
            </h4>

            <span className="muted small mono">
              {section.sectionCode}
            </span>
          </div>
        </div>

        <div className="state-section-meta">
          <span className="section-count">
            {remaining}/{total}
          </span>

          {section.badge && (
            <span className="section-badge">
              {section.badge}
            </span>
          )}

          <span className="section-state-label">
            {getStateLabel(section.state)}
          </span>
        </div>
      </header>

      {children.length > 0 && (
        <div className="subsections">
          {children.map((child) => (
            <SubsectionItem
              key={child.subsectionCode}
              subsection={child}
            />
          ))}
        </div>
      )}

      {section.state === 'attention' && (
        <div className="state-section-notice">
          <span aria-hidden="true">!</span>
          <span>Clinical information requires attention.</span>
        </div>
      )}
    </article>
  );
}

function SubsectionItem({
  subsection,
}: {
  subsection: WorkspaceSubsectionProjection;
}) {
  const total = getNumber(subsection.requiredTotal);
  const remaining = getNumber(subsection.requiredRemaining);

  const completion =
    total > 0
      ? Math.round(((total - remaining) / total) * 100)
      : 100;

  return (
    <div
      className={`subsection-item subsection-${subsection.state}`}
      data-subsection-code={subsection.subsectionCode}
    >
      <div className="subsection-main">
        <span
          className={`subsection-indicator subsection-indicator-${subsection.state}`}
          aria-hidden="true"
        />

        <div className="subsection-content">
          <span className="subsection-label">
            {subsection.label}
          </span>

          <span className="muted small mono">
            {subsection.subsectionCode}
          </span>
        </div>
      </div>

      <div className="subsection-meta">
        <span className="subsection-progress">
          {completion}%
        </span>

        <span className="subsection-count">
          {remaining}/{total}
        </span>

        <span className="subsection-state">
          {getStateLabel(subsection.state)}
        </span>
      </div>
    </div>
  );
}

function childIsRelevant(
  subsection: WorkspaceSubsectionProjection,
): boolean {
  return subsection.state !== 'hidden';
}

function isSectionRelevantToFormat(
  sectionCode: string,
  formatPlan?: ClinicalFormatPlan,
): boolean {
  if (!formatPlan) {
    return true;
  }

  const excluded = formatPlan.excludedSections ?? [];
  const additional = formatPlan.additionalSections ?? [];

  if (excluded.includes(sectionCode)) {
    return false;
  }

  if (additional.includes(sectionCode)) {
    return true;
  }

  if (UNIVERSAL_SECTIONS.has(sectionCode)) {
    return true;
  }

  const formatSections =
    FORMAT_SECTIONS[formatPlan.baseFormat];

  if (!formatSections) {
    return true;
  }

  return formatSections.has(sectionCode);
}

function getStateLabel(
  state: WorkspaceSectionState,
): string {
  const labels: Record<WorkspaceSectionState, string> = {
    hidden: 'Hidden',
    locked: 'Locked',
    available: 'Available',
    active: 'Active',
    attention: 'Attention',
    complete: 'Complete',
  };

  return labels[state] ?? state;
}

function getNumber(value: number | null | undefined): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.max(0, value)
    : 0;
}