import { useMemo, useState } from 'react';
import type {
  CaptureQuestion,
  ClinicalFact,
  HistorySectionDefinition,
  UniversalClinicalProjection,
} from '../../clinical/types';

import { SectionNavigator } from './SectionNavigator';
import { HistorySection } from './HistorySection';
import { QuestionCapture } from './QuestionCapture';
import { FactSummary } from './FactSummary';

interface HistoryWorkspaceProps {
  projection: UniversalClinicalProjection;
  onEvent: (event: any) => void;
}

export function HistoryWorkspace({
  projection,
  onEvent,
}: HistoryWorkspaceProps) {
  const sections = projection.sections ?? [];
  const facts = projection.capturedFacts ?? [];
  const questions = projection.questions ?? [];
  const context = projection.context;

  const [activeSection, setActiveSection] = useState<string>(
    projection.activeSection ||
      sections[0]?.code ||
      'biodata',
  );

  const sectionQuestions = useMemo(() => {
    const map = new Map<string, CaptureQuestion[]>();

    for (const question of questions) {
      const list = map.get(question.section) ?? [];
      list.push(question);
      map.set(question.section, list);
    }

    return map;
  }, [questions]);

  const sectionFacts = useMemo(() => {
    const map = new Map<string, ClinicalFact[]>();

    for (const fact of facts) {
      const list = map.get(fact.section) ?? [];
      list.push(fact);
      map.set(fact.section, list);
    }

    return map;
  }, [facts]);

  const activeIndex = Math.max(
    0,
    sections.findIndex(
      (section) => section.code === activeSection,
    ),
  );

  const activeSectionDef: HistorySectionDefinition | undefined =
    sections[activeIndex] ??
    sections.find(
      (section) => section.code === activeSection,
    ) ??
    sections[0];

  const activeCode = activeSectionDef?.code ?? 'biodata';

  const activeQuestions =
    sectionQuestions.get(activeCode) ?? [];

  const activeFacts =
    sectionFacts.get(activeCode) ?? [];

  const unresolvedMandatoryQuestions = activeQuestions.filter(
    (question) =>
      question.requirementLevel === 'mandatory',
  );

  const completedSection = activeFacts.length > 0;

  const firstIncompleteIndex = sections.findIndex(
    (section) => {
      const sectionFactsForSection = sectionFacts.get(section.code) ?? [];

      if (section.required) {
        return sectionFactsForSection.length === 0;
      }

      return false;
    },
  );

  const nextIndex = activeIndex + 1;
  const previousIndex = activeIndex - 1;

  const hasNext = nextIndex < sections.length;
  const hasPrevious = previousIndex >= 0;

  const goToSection = (index: number) => {
    if (index < 0 || index >= sections.length) return;

    const target = sections[index];

    setActiveSection(target.code);

    onEvent({
      type: 'HISTORY_SECTION_CHANGED',
      payload: {
        section: target.code,
        sequence: index + 1,
      },
    });
  };

  const goNext = () => {
    if (!hasNext) return;

    goToSection(nextIndex);
  };

  const goPrevious = () => {
    if (!hasPrevious) return;

    goToSection(previousIndex);
  };

  const goToFirstIncomplete = () => {
    if (firstIncompleteIndex >= 0) {
      goToSection(firstIncompleteIndex);
    }
  };

  if (sections.length === 0) {
    return (
      <div className="history-workspace history-workspace-empty">
        <div className="history-empty-state">
          <h2>Clinical History</h2>
          <p>No history sections are available for this encounter.</p>
        </div>
      </div>
    );
  }

  return (
    <div
      className="history-workspace"
      data-patient-id={context.patientId}
      data-encounter-id={context.encounterId ?? undefined}
    >
      <SectionNavigator
        sections={sections}
        activeSection={activeCode}
        onSectionChange={(section) => {
          const index = sections.findIndex(
            (item) => item.code === section,
          );

          if (index >= 0) {
            goToSection(index);
          }
        }}
        sectionFacts={sectionFacts}
        sectionQuestions={sectionQuestions}
      />

      <div className="history-content">
        <main className="history-main">
          <div className="history-progress-header">
            <div className="history-progress-position">
              <span>
                Section {activeIndex + 1} of {sections.length}
              </span>

              <strong>
                {activeSectionDef?.label ?? 'Clinical History'}
              </strong>
            </div>

            <div className="history-progress-actions">
              {firstIncompleteIndex >= 0 &&
                firstIncompleteIndex !== activeIndex && (
                  <button
                    type="button"
                    className="history-action-btn"
                    onClick={goToFirstIncomplete}
                  >
                    Go to first required section
                  </button>
                )}
            </div>
          </div>

          <div className="history-section-progress">
            <div
              className="history-section-progress-bar"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={sections.length}
              aria-valuenow={activeIndex + 1}
            >
              <span
                style={{
                  width: `${
                    ((activeIndex + 1) / sections.length) * 100
                  }%`,
                }}
              />
            </div>
          </div>

          {activeSectionDef && (
            <HistorySection
              section={activeSectionDef}
              questions={activeQuestions}
              facts={activeFacts}
              mandatoryRemaining={
                unresolvedMandatoryQuestions.length
              }
              onEvent={onEvent}
            />
          )}

          <QuestionCapture
            questions={activeQuestions}
            facts={activeFacts}
            section={activeCode}
            patientId={context.patientId}
            encounterId={context.encounterId}
            onEvent={onEvent}
          />

          <div className="history-section-footer">
            <button
              type="button"
              className="history-navigation-btn previous"
              disabled={!hasPrevious}
              onClick={goPrevious}
            >
              Previous
            </button>

            <div className="history-section-status">
              {completedSection ? (
                <span className="section-complete">
                  Section captured
                </span>
              ) : (
                <span className="section-incomplete">
                  Section awaiting capture
                </span>
              )}

              {unresolvedMandatoryQuestions.length > 0 && (
                <span className="section-mandatory-count">
                  {
                    unresolvedMandatoryQuestions.length
                  } mandatory question
                  {unresolvedMandatoryQuestions.length !== 1
                    ? 's'
                    : ''}{' '}
                  remaining
                </span>
              )}
            </div>

            <button
              type="button"
              className="history-navigation-btn next"
              disabled={!hasNext}
              onClick={goNext}
            >
              {nextIndex < sections.length
                ? `Next: ${
                    sections[nextIndex]?.label ?? 'Section'
                  }`
                : 'Finish'}
            </button>
          </div>
        </main>

        <aside className="history-sidebar">
          <FactSummary facts={activeFacts} />

          <div className="history-sidebar-sections">
            <h3>History Progress</h3>

            <div className="history-section-list">
              {sections.map((section, index) => {
                const captured =
                  (sectionFacts.get(section.code) ?? []).length >
                  0;

                const sectionQuestionsForItem =
                  sectionQuestions.get(section.code) ?? [];

                const mandatory =
                  sectionQuestionsForItem.filter(
                    (question) =>
                      question.requirementLevel ===
                      'mandatory',
                  ).length;

                return (
                  <button
                    key={section.code}
                    type="button"
                    className={[
                      'history-section-list-item',
                      section.code === activeCode
                        ? 'active'
                        : '',
                      captured ? 'captured' : '',
                      section.required ? 'required' : '',
                    ]
                      .filter(Boolean)
                      .join(' ')}
                    onClick={() => goToSection(index)}
                  >
                    <span className="section-sequence">
                      {index + 1}
                    </span>

                    <span className="section-list-content">
                      <span className="section-list-label">
                        {section.label}
                      </span>

                      <span className="section-list-status">
                        {captured
                          ? 'Captured'
                          : section.required
                            ? 'Required'
                            : mandatory > 0
                              ? 'Questions available'
                              : 'Pending'}
                      </span>
                    </span>

                    <span
                      className="section-list-indicator"
                      aria-hidden="true"
                    >
                      {captured ? '✓' : section.required ? '!' : '○'}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}

