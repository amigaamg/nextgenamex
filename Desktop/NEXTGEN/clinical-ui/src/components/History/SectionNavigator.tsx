import type {
  HistorySectionDefinition,
  CaptureQuestion,
  ClinicalFact,
} from '../../clinical/types';

interface SectionNavigatorProps {
  sections: HistorySectionDefinition[];
  activeSection: string;
  onSectionChange: (section: string) => void;
  sectionFacts: Map<string, ClinicalFact[]>;
  sectionQuestions: Map<string, CaptureQuestion[]>;
  horizontal?: boolean;
  onNavigateToExam?: () => void;
}

const SECTION_ICONS: Record<string, string> = {
  biodata: 'BD',
  chief_complaint: 'CC',
  hpi: 'HPI',
  past_medical_history: 'PMH',
  past_surgical_history: 'PSH',
  drug_history: 'DH',
  allergy_history: 'ALL',
  family_history: 'FH',
  social_history: 'SH',
  occupational_history: 'OH',
  sexual_history: 'SX',
  review_of_systems: 'ROS',
  obstetric_history: 'OB',
  gynaecological_history: 'GYN',
  anc_profile: 'ANC',
  birth_history: 'BH',
  growth_development: 'GD',
  immunization: 'IMM',
  nutrition: 'NUT',
  psychiatric_history: 'PSY',
  substance_history: 'SUB',
  collateral_history: 'COL',
  summary: 'SUM',
};

export function SectionNavigator({
  sections,
  activeSection,
  onSectionChange,
  sectionFacts,
  sectionQuestions,
  horizontal = false,
  onNavigateToExam,
}: SectionNavigatorProps) {
  const visibleSections = sections.filter((section) => section.visible);

  const totalRequired = visibleSections.filter(
    (section) => section.required,
  ).length;

  const getSectionProgress = (
    section: HistorySectionDefinition,
  ) => {
    const facts = sectionFacts.get(section.code) ?? [];
    const questions = sectionQuestions.get(section.code) ?? [];

    const mandatoryQuestions = questions.filter(
      (question) => question.requirementLevel === 'mandatory',
    );

    const answeredMandatory = mandatoryQuestions.filter(
      (question) =>
        question.factCode != null &&
        facts.some(
          (fact) => fact.factCode === question.factCode,
        ),
    ).length;

    const unresolvedMandatory = Math.max(
      mandatoryQuestions.length - answeredMandatory,
      0,
    );

    const complete =
      mandatoryQuestions.length === 0
        ? facts.length > 0
        : answeredMandatory === mandatoryQuestions.length;

    return {
      facts,
      questions,
      mandatoryQuestions,
      answeredMandatory,
      unresolvedMandatory,
      complete,
    };
  };

  return (
    <nav
      className={[
        'section-navigator',
        horizontal ? 'horizontal' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      aria-label="Clinical history sections"
    >
      <div className="nav-header">
        <div>
          <h3>Clinical History</h3>
          <span className="nav-subtitle">
            {visibleSections.length} sections
          </span>
        </div>

        <span className="nav-required-count">
          {totalRequired} required
        </span>
      </div>

      <div
        className="nav-tabs"
        role="tablist"
        aria-orientation={horizontal ? 'horizontal' : 'vertical'}
      >
        {visibleSections.map((section, index) => {
          const progress = getSectionProgress(section);
          const isActive = activeSection === section.code;
          const icon =
            SECTION_ICONS[section.code] ?? '•';

          return (
            <button
              key={section.code}
              id={`tab-${section.code}`}
              type="button"
              role="tab"
              aria-selected={isActive}
              aria-controls={`panel-${section.code}`}
              tabIndex={isActive ? 0 : -1}
              className={[
                'nav-tab',
                isActive ? 'active' : '',
                progress.complete ? 'complete' : '',
                progress.facts.length > 0
                  ? 'has-content'
                  : '',
                section.required ? 'required' : '',
                progress.unresolvedMandatory > 0
                  ? 'has-unresolved'
                  : '',
              ]
                .filter(Boolean)
                .join(' ')}
              onClick={() =>
                onSectionChange(section.code)
              }
              onKeyDown={(event) => {
                if (
                  event.key === 'ArrowDown' ||
                  event.key === 'ArrowRight'
                ) {
                  event.preventDefault();

                  const nextIndex =
                    (index + 1) %
                    visibleSections.length;

                  onSectionChange(
                    visibleSections[nextIndex].code,
                  );
                }

                if (
                  event.key === 'ArrowUp' ||
                  event.key === 'ArrowLeft'
                ) {
                  event.preventDefault();

                  const previousIndex =
                    (index - 1 + visibleSections.length) %
                    visibleSections.length;

                  onSectionChange(
                    visibleSections[previousIndex].code,
                  );
                }

                if (event.key === 'Home') {
                  event.preventDefault();
                  onSectionChange(
                    visibleSections[0]?.code ?? 'biodata',
                  );
                }

                if (event.key === 'End') {
                  event.preventDefault();
                  onSectionChange(
                    visibleSections[
                      visibleSections.length - 1
                    ]?.code ?? 'biodata',
                  );
                }
              }}
              title={[
                section.label,
                section.required ? 'Required' : null,
                progress.complete ? 'Complete' : null,
              ]
                .filter(Boolean)
                .join(' · ')}
            >
              <span
                className="tab-index"
                aria-hidden="true"
              >
                {index + 1}
              </span>

              <span
                className="tab-icon"
                aria-hidden="true"
              >
                {icon}
              </span>

              <span className="tab-content">
                <span className="tab-label">
                  {section.label}
                </span>

                <span className="tab-status">
                  {progress.complete
                    ? 'Complete'
                    : progress.facts.length > 0
                      ? `${progress.facts.length} captured`
                      : 'Not started'}
                </span>
              </span>

              <span className="tab-indicators">
                {section.required && (
                  <span
                    className="required-badge"
                    aria-label="Required section"
                  >
                    *
                  </span>
                )}

                {progress.mandatoryQuestions.length > 0 && (
                  <span
                    className="progress-badge"
                    aria-label={`${progress.answeredMandatory} of ${progress.mandatoryQuestions.length} mandatory questions answered`}
                  >
                    {progress.answeredMandatory}/
                    {progress.mandatoryQuestions.length}
                  </span>
                )}

                {progress.complete && (
                  <span
                    className="complete-indicator"
                    aria-label="Complete"
                  >
                    ✓
                  </span>
                )}
              </span>
            </button>
          );
        })}

        {onNavigateToExam && (
          <>
            <div className="nav-tab-divider" aria-hidden="true" />

            <button
              key="examination"
              id="tab-examination"
              type="button"
              role="tab"
              aria-selected={activeSection === 'examination'}
              tabIndex={activeSection === 'examination' ? 0 : -1}
              className={[
                'nav-tab',
                'nav-tab-exam',
                activeSection === 'examination' ? 'active' : '',
              ]
                .filter(Boolean)
                .join(' ')}
              onClick={onNavigateToExam}
            >
              <span className="tab-index" aria-hidden="true">
                ▶
              </span>

              <span className="tab-icon" aria-hidden="true">
                🩺
              </span>

              <span className="tab-content">
                <span className="tab-label">Examination</span>

                <span className="tab-status">
                  Physical examination
                </span>
              </span>

              <span className="tab-indicators" aria-hidden="true" />
            </button>
          </>
        )}
      </div>
    </nav>
  );
}