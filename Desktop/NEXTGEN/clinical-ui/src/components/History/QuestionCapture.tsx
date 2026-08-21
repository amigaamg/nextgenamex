import { useMemo, useState } from 'react';
import type { CaptureQuestion, ClinicalFact } from '../../clinical/types';

interface QuestionCaptureProps {
  questions: CaptureQuestion[];
  archivedQuestions?: CaptureQuestion[];
  facts: ClinicalFact[];
  section: string;
  patientId: string;
  encounterId: string | null;
  onEvent: (event: any) => void;
}

interface QuestionCardProps {
  question: CaptureQuestion;
  patientId: string;
  encounterId: string | null;
  section: string;
  onEvent: (event: any) => void;
  initialFact?: ClinicalFact;
  onCancelEdit?: () => void;
}

type PrimitiveValue = string | number | boolean | null;

// Short option lists stay as tap buttons (one-touch, fastest for a doctor);
// longer lists collapse to a compact dropdown so many questions fit on screen.
const SINGLE_SELECT_DROPDOWN_LIMIT = 3;

// Doctors think in a narrative order, not a utility score. Within a section we
// surface the identity/registration questions in this logical sequence so the
// clinician never sees "date of admission" before "patient name". The CPU's
// priority still wins across sections; this only orders same-priority siblings.
const LOGICAL_ORDER: Record<string, number> = {
  BIODATA_PATIENT_NAME: 10,
  BIODATA_AGE: 20,
  BIODATA_SEX: 30,
  BIODATA_DATE_OF_BIRTH: 35,
  BIODATA_OCCUPATION: 40,
  BIODATA_RESIDENCE: 50,
  BIODATA_COUNTY: 60,
  BIODATA_ENCOUNTER_TYPE: 70,
  BIODATA_ADMISSION_DATE: 80,
  BIODATA_NEXT_OF_KIN: 90,
  BIODATA_NEXT_OF_KIN_PHONE: 95,
};

function logicalRank(question: CaptureQuestion): number {
  return LOGICAL_ORDER[question.questionCode] ?? 999;
}

const REQUIREMENT_WEIGHT: Record<string, number> = {
  mandatory: 100000,
  conditional: 50000,
  recommended: 25000,
  optional: 0,
};

function sortByLogical<T extends CaptureQuestion>(items: T[]): T[] {
  return [...items].sort((a, b) => {
    const weightA = REQUIREMENT_WEIGHT[a.requirementLevel] ?? 0;
    const weightB = REQUIREMENT_WEIGHT[b.requirementLevel] ?? 0;
    if (weightB !== weightA) return weightB - weightA;
    if (b.priority !== a.priority) return b.priority - a.priority;
    return logicalRank(a) - logicalRank(b);
  });
}

export function QuestionCapture({
  questions,
  archivedQuestions = [],
  facts,
  section,
  patientId,
  encounterId,
  onEvent,
}: QuestionCaptureProps) {
  const sectionQuestions = useMemo(
    () => questions.filter((question) => question.section === section),
    [questions, section],
  );

  // Keep answered questions reviewable even after the CPU drops them from the
  // live question stack: the archive preserves every previously-seen question.
  const reviewableQuestions = useMemo(() => {
    const merged = new Map<string, CaptureQuestion>();

    for (const question of archivedQuestions) {
      if (question.section !== section) continue;
      merged.set(question.questionCode, question);
    }

    for (const question of sectionQuestions) {
      merged.set(question.questionCode, question);
    }

    return [...merged.values()];
  }, [archivedQuestions, sectionQuestions, section]);

  const factsByCode = useMemo(() => {
    const map = new Map<string, ClinicalFact>();
    for (const fact of facts) {
      if (fact.factCode && !map.has(fact.factCode)) {
        map.set(fact.factCode, fact);
      }
    }
    return map;
  }, [facts]);

  const pendingQuestions = useMemo(
    () =>
      sectionQuestions.filter(
        (question) =>
          !question.factCode ||
          !factsByCode.has(question.factCode),
      ),
    [sectionQuestions, factsByCode],
  );

  const answeredQuestions = useMemo(
    () =>
      reviewableQuestions.filter(
        (question) =>
          question.factCode != null &&
          factsByCode.has(question.factCode),
      ),
    [reviewableQuestions, factsByCode],
  );

  const pendingMandatory = useMemo(
    () =>
      pendingQuestions.filter(
        (question) => question.requirementLevel === 'mandatory',
      ),
    [pendingQuestions],
  );

  const [editingCodes, setEditingCodes] = useState<Set<string>>(
    () => new Set(),
  );

  const toggleEditing = (questionCode: string) => {
    setEditingCodes((previous) => {
      const next = new Set(previous);
      if (next.has(questionCode)) {
        next.delete(questionCode);
      } else {
        next.add(questionCode);
      }
      return next;
    });
  };

  const orphanFacts = useMemo(
    () =>
      facts.filter(
        (fact) =>
          fact.factCode &&
          !sectionQuestions.some(
            (question) => question.factCode === fact.factCode,
          ),
      ),
    [facts, sectionQuestions],
  );

  if (sectionQuestions.length === 0 && facts.length === 0) {
    return (
      <div className="question-capture empty">
        <div className="empty-state">
          <span className="empty-icon" aria-hidden="true">
            ?
          </span>
          <h3>No questions for this section</h3>
          <p>
            Questions will appear here as the clinical context and captured
            facts determine what remains necessary.
          </p>
        </div>
      </div>
    );
  }

  const allCaptured =
    pendingQuestions.length === 0 && answeredQuestions.length > 0;

  return (
    <div className="question-capture">
      <header className="capture-header">
        <div>
          <h3>Adaptive Clinical Questions</h3>
          <p className="capture-description">
            Capture the information required to complete this section.
          </p>
        </div>

        <div className="capture-meta">
          <span
            className={`badge ${
              pendingMandatory.length > 0 ? 'warning' : 'success'
            }`}
          >
            {pendingMandatory.length} mandatory pending
          </span>

          <span className="badge info">
            {pendingQuestions.length} pending
          </span>

          <span className="badge success">
            {answeredQuestions.length} captured
          </span>
        </div>
      </header>

      {pendingQuestions.length > 0 && (
        <div className="questions-grid">
          {sortByLogical(pendingQuestions).map((question) => (
            <QuestionCard
              key={question.questionCode}
              question={question}
              patientId={patientId}
              encounterId={encounterId}
              section={section}
              onEvent={onEvent}
            />
          ))}
        </div>
      )}

      {allCaptured && (
        <div className="capture-complete">
          <span className="complete-icon" aria-hidden="true">
            ✓
          </span>
          <div>
            <strong>All current questions captured</strong>
            <p>
              Captured answers stay reviewable below. Continue to the next
              section or review them here.
            </p>
          </div>
        </div>
      )}

      {answeredQuestions.length > 0 && (
        <>
          <div className="capture-subsection">
            <span className="capture-subsection-label">
              Captured & reviewable
            </span>
            <span className="capture-subsection-count">
              {answeredQuestions.length}
            </span>
          </div>

          <div className="questions-grid">
            {sortByLogical(answeredQuestions).map((question) => {
              const fact = factsByCode.get(question.factCode!);

              if (editingCodes.has(question.questionCode)) {
                return (
                  <QuestionCard
                    key={question.questionCode}
                    question={question}
                    patientId={patientId}
                    encounterId={encounterId}
                    section={section}
                    onEvent={onEvent}
                    initialFact={fact}
                    onCancelEdit={() =>
                      toggleEditing(question.questionCode)
                    }
                  />
                );
              }

              return (
                <AnsweredCard
                  key={question.questionCode}
                  question={question}
                  fact={fact!}
                  onEdit={() =>
                    toggleEditing(question.questionCode)
                  }
                />
              );
            })}
          </div>
        </>
      )}

      {orphanFacts.length > 0 && (
        <div className="captured-extra">
          <span className="capture-subsection-label">
            Additional captured facts
          </span>

          <div className="captured-fact-chips">
            {orphanFacts.map((fact) => (
              <span key={fact.id} className="captured-fact-chip">
                <span className="captured-fact-chip-code">
                  {fact.factCode}
                </span>
                <span className="captured-fact-chip-value">
                  {formatCapturedValue(fact)}
                </span>
              </span>
            ))}
          </div>
        </div>
      )}

      {pendingQuestions.length === 0 &&
        answeredQuestions.length === 0 && (
          <div className="capture-complete">
            <span className="complete-icon" aria-hidden="true">
              ✓
            </span>
            <div>
              <strong>Section captured</strong>
              <p>
                All currently resolved questions in this section have been
                documented.
              </p>
            </div>
          </div>
        )}
    </div>
  );
}

function AnsweredCard({
  question,
  fact,
  onEdit,
}: {
  question: CaptureQuestion;
  fact: ClinicalFact;
  onEdit?: () => void;
}) {
  return (
    <article
      className="question-card answered"
      data-question-code={question.questionCode}
    >
      <header className="question-header">
        <div className="question-meta">
          <span className="answered-badge">Captured</span>

          {question.factCode && (
            <span className="fact-code">
              {question.factCode}
            </span>
          )}
        </div>

        <span className="answered-check" aria-hidden="true">
          ✓
        </span>
      </header>

      <h3 className="question-text">
        {question.text}
      </h3>

      <div className="answered-value">
        {formatCapturedValue(fact)}
      </div>

      {fact.value.unitCode && fact.value.numeric != null && (
        <span className="answered-unit">
          {fact.value.unitCode}
        </span>
      )}

      {onEdit && (
        <footer className="question-actions">
          <button
            type="button"
            className="disposition-btn edit"
            onClick={onEdit}
          >
            Change answer
          </button>
        </footer>
      )}
    </article>
  );
}

function QuestionCard({
  question,
  patientId,
  encounterId,
  section,
  onEvent,
  initialFact,
  onCancelEdit,
}: QuestionCardProps) {
  const initialValue = initialFact
    ? prefillValue(question, initialFact)
    : '';

  const [value, setValue] = useState(
    () =>
      (initialValue !== ''
        ? initialValue
        : question.defaultAnswer &&
          question.options.some(
            (option) =>
              option.answerCode === question.defaultAnswer,
          )
          ? question.defaultAnswer
          : '') as string,
  );
  const [multiSelect, setMultiSelect] = useState<Set<string>>(
    () => new Set(),
  );
  const [submitting, setSubmitting] = useState(false);
  const [showReason, setShowReason] = useState(false);

  const emitAnswer = (
    answerCode: string | string[],
    rawValue: PrimitiveValue | string[] = null,
  ) => {
    if (submitting) return;

    const codes = Array.isArray(answerCode)
      ? answerCode
      : answerCode
        ? [answerCode]
        : [];

    setSubmitting(true);

    onEvent({
      type: 'QUESTION_ANSWERED',
      payload: {
        patientId,
        encounterId,
        questionCode: question.questionCode,
        answerCodes: codes,
        rawValue,
        section,
        factCode: question.factCode ?? null,
        unitCode: question.unitCode ?? null,
      },
    });

    setValue('');
    setMultiSelect(new Set());

    if (onCancelEdit) {
      window.setTimeout(onCancelEdit, 50);
    }

    window.setTimeout(() => setSubmitting(false), 150);
  };

  const emitDisposition = (
    disposition: 'not_applicable' | 'deferred' | 'skipped',
  ) => {
    if (submitting) return;

    setSubmitting(true);

    onEvent({
      type: 'QUESTION_DISPOSITIONED',
      payload: {
        patientId,
        encounterId,
        questionCode: question.questionCode,
        disposition,
        section,
        factCode: question.factCode ?? null,
      },
    });

    setValue('');
    setMultiSelect(new Set());

    if (onCancelEdit) {
      window.setTimeout(onCancelEdit, 50);
    }

    window.setTimeout(() => setSubmitting(false), 150);
  };

  const toggleMultiSelect = (answerCode: string) => {
    setMultiSelect((previous) => {
      const next = new Set(previous);

      if (next.has(answerCode)) {
        next.delete(answerCode);
      } else {
        next.add(answerCode);
      }

      return next;
    });
  };

  const renderInput = () => {
    switch (question.responseType) {
      case 'single_select':
      case 'coded':
        if (question.options.length > SINGLE_SELECT_DROPDOWN_LIMIT) {
          return (
            <div className="answer-input">
              <select
                className="answer-select"
                value={value}
                disabled={submitting}
                aria-label={question.text}
                onChange={(event) => {
                  const next = event.target.value;
                  if (next) {
                    emitAnswer(next);
                  }
                }}
              >
                <option value="" disabled>
                  Select one option…
                </option>
                {question.options.map((option) => (
                  <option
                    key={option.answerCode}
                    value={option.answerCode}
                  >
                    {option.label}
                    {question.defaultAnswer === option.answerCode
                      ? ' (default)'
                      : ''}
                  </option>
                ))}
              </select>
            </div>
          );
        }

        return (
          <div className="answer-options" role="group">
            {question.options.map((option) => (
              <button
                key={option.answerCode}
                type="button"
                className={`answer-option ${
                  value === option.answerCode ? 'preselected' : ''
                }`}
                disabled={submitting}
                onClick={() => emitAnswer(option.answerCode)}
              >
                <span>{option.label}</span>

                {value === option.answerCode && (
                  <span className="preselected-tag">
                    default
                  </span>
                )}

                {option.factValue != null && (
                  <span className="option-detail">
                    {formatOptionDetail(option.factValue)}
                  </span>
                )}
              </button>
            ))}
          </div>
        );

      case 'boolean':
        return (
          <div className="answer-options boolean" role="group">
            {getBooleanOptions(question).map((option) => (
              <button
                key={option.answerCode}
                type="button"
                disabled={submitting}
                className={`answer-option ${option.className}`}
                onClick={() => emitAnswer(option.answerCode)}
              >
                {option.label}
              </button>
            ))}
          </div>
        );

      case 'multi_select':
        return (
          <div className="multi-select">
            <div className="answer-options" role="group">
              {question.options.map((option) => {
                const selected = multiSelect.has(option.answerCode);

                return (
                  <button
                    key={option.answerCode}
                    type="button"
                    disabled={submitting}
                    className={`answer-option ${
                      selected ? 'selected' : ''
                    }`}
                    aria-pressed={selected}
                    onClick={() =>
                      toggleMultiSelect(option.answerCode)
                    }
                  >
                    <span
                      className="selection-indicator"
                      aria-hidden="true"
                    >
                      {selected ? '✓' : ''}
                    </span>
                    {option.label}
                  </button>
                );
              })}
            </div>

            <div className="multi-select-actions">
              <button
                type="button"
                className="btn-primary"
                disabled={multiSelect.size === 0 || submitting}
                onClick={() =>
                  emitAnswer([...multiSelect], [...multiSelect])
                }
              >
                Apply{multiSelect.size === 0 ? '' : ` (${multiSelect.size})`}
              </button>
            </div>
          </div>
        );
      case 'numeric':
      case 'measurement':
        return (
          <div className="answer-input">
            <div className="input-with-unit">
              <input
                type="number"
                inputMode="decimal"
                step={question.validation?.step ?? 'any'}
                min={question.validation?.min ?? undefined}
                max={question.validation?.max ?? undefined}
                placeholder={
                  question.placeholder ||
                  question.unitCode ||
                  'Enter value'
                }
                value={value}
                disabled={submitting}
                onChange={(event) =>
                  setValue(event.target.value)
                }
                onBlur={(event) => {
                  const v = event.target.value.trim();
                  if (v !== '') emitAnswer('', Number(v));
                }}
                onKeyDown={(event) => {
                  if (
                    event.key === 'Enter' &&
                    value.trim() !== ''
                  ) {
                    emitAnswer('', Number(value));
                  }
                }}
              />

              {question.unitCode && (
                <span className="input-unit">
                  {question.unitCode}
                </span>
              )}
            </div>
          </div>
        );

      case 'date':
        return (
          <div className="answer-input">
            <input
              type="date"
              value={value}
              disabled={submitting}
              onChange={(event) =>
                setValue(event.target.value)
              }
              onBlur={(event) => {
                if (event.target.value.trim() !== '')
                  emitAnswer('', event.target.value);
              }}
              onKeyDown={(event) => {
                if (
                  event.key === 'Enter' &&
                  value.trim() !== ''
                ) {
                  emitAnswer('', value);
                }
              }}
            />
          </div>
        );

      case 'datetime':
        return (
          <div className="answer-input">
            <input
              type="datetime-local"
              value={value}
              disabled={submitting}
              onChange={(event) =>
                setValue(event.target.value)
              }
              onBlur={(event) => {
                if (event.target.value.trim() !== '')
                  emitAnswer('', event.target.value);
              }}
            />
          </div>
        );

      case 'text':
      case 'free_text':
        return (
          <div className="answer-input">
            <input
              type="text"
              autoComplete="off"
              placeholder={
                question.placeholder || 'Enter response'
              }
              value={value}
              disabled={submitting}
              onChange={(event) =>
                setValue(event.target.value)
              }
              onBlur={(event) => {
                const v = event.target.value.trim();
                if (v !== '') emitAnswer('', v);
              }}
              onKeyDown={(event) => {
                if (
                  event.key === 'Enter' &&
                  value.trim() !== ''
                ) {
                  emitAnswer('', value.trim());
                }
              }}
            />
          </div>
        );

      case 'long_text':
        return (
          <div className="answer-input long">
            <textarea
              placeholder={
                question.placeholder ||
                'Enter clinical response'
              }
              value={value}
              disabled={submitting}
              rows={3}
              onChange={(event) =>
                setValue(event.target.value)
              }
            />

            <div className="long-input-footer">
              <span className="character-count">
                {value.length} characters
              </span>

              <button
                type="button"
                className="btn-primary"
                disabled={
                  value.trim() === '' || submitting
                }
                onClick={() =>
                  emitAnswer('', value.trim())
                }
              >
                Record
              </button>
            </div>
          </div>
        );

      default:
        return (
          <div className="unsupported">
            Unsupported response type:{' '}
            {String(question.responseType)}
          </div>
        );
    }
  };

  return (
    <article
      className={`question-card ${
        question.requirementLevel === 'mandatory'
          ? 'mandatory'
          : ''
      }`}
      data-question-code={question.questionCode}
    >
      <header className="question-header">
        <div className="question-meta">
          <span
            className={`requirement-badge ${question.requirementLevel}`}
          >
            {formatRequirement(question.requirementLevel)}
          </span>

          {question.factCode && (
            <span className="fact-code">
              {question.factCode}
            </span>
          )}
        </div>
      </header>

      <h3 className="question-text">
        {question.text}
      </h3>

      {question.reason && (
        <div className="question-why">
          <button
            type="button"
            className="question-why-toggle"
            onClick={() =>
              setShowReason(
                (show) => !show,
              )
            }
            aria-expanded={showReason}
          >
            {showReason ? 'Why this question? —' : 'Why this question?'}
            <span
              className={`question-why-chevron ${
                showReason ? 'open' : ''
              }`}
            >
              ▸
            </span>
          </button>

          {showReason && (
            <p className="question-reason">
              {question.reason}
            </p>
          )}
        </div>
      )}

      <div className="question-control">
        {renderInput()}
      </div>

      {question.defaultAnswer &&
        question.options.some(
          (option) => option.answerCode === question.defaultAnswer,
        ) && (
          <p className="question-default">
            Default:{' '}
            {
              question.options.find(
                (option) =>
                  option.answerCode === question.defaultAnswer,
              )?.label
            }
          </p>
        )}

      <footer className="question-actions">
        {question.allowNotApplicable && (
          <button
            type="button"
            className="disposition-btn"
            disabled={submitting}
            onClick={() =>
              emitDisposition('not_applicable')
            }
          >
            Not Applicable
          </button>
        )}

        {question.allowDefer && (
          <button
            type="button"
            className="disposition-btn"
            disabled={submitting}
            onClick={() =>
              emitDisposition('deferred')
            }
          >
            Ask Later
          </button>
        )}

        <button
          type="button"
          className="disposition-btn skip"
          disabled={submitting}
          onClick={() => emitDisposition('skipped')}
        >
          Skip
        </button>

        {onCancelEdit && (
          <button
            type="button"
            className="disposition-btn cancel"
            disabled={submitting}
            onClick={onCancelEdit}
          >
            Cancel edit
          </button>
        )}
      </footer>
    </article>
  );
}

function formatCapturedValue(fact: ClinicalFact): string {
  const value = fact.value;

  if (value.text != null && value.text.trim() !== '') {
    return value.text.trim();
  }

  if (value.code != null) {
    return value.code;
  }

  if (value.boolean != null) {
    return value.boolean ? 'Yes' : 'No';
  }

  if (value.numeric != null) {
    return String(value.numeric);
  }

  if (value.date != null) {
    return value.date;
  }

  if (value.datetime != null) {
    return value.datetime;
  }

  return '—';
}

function getBooleanOptions(
  question: CaptureQuestion,
) {
  const hasUnknown = question.options.some(
    (option) => option.answerCode === 'UNKNOWN',
  );

  return [
    {
      answerCode: 'YES',
      label: 'Yes',
      className: 'positive',
    },
    {
      answerCode: 'NO',
      label: 'No',
      className: 'negative',
    },
    ...(hasUnknown
      ? [
          {
            answerCode: 'UNKNOWN',
            label: 'Unknown',
            className: 'neutral',
          },
        ]
      : []),
  ];
}

function formatRequirement(
  requirement: CaptureQuestion['requirementLevel'],
): string {
  switch (requirement) {
    case 'mandatory':
      return 'Required';
    case 'recommended':
      return 'Recommended';
    case 'conditional':
      return 'Conditional';
    default:
      return String(requirement);
  }
}

function formatOptionDetail(value: unknown): string {
  if (value == null) return '';

  if (
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return String(value);
  }

  try {
    return JSON.stringify(value);
  } catch {
    return '';
  }
}

function prefillValue(
  question: CaptureQuestion,
  fact: ClinicalFact,
): string {
  const value = fact.value;

  if (question.responseType === 'boolean') {
    if (value.boolean === true) return 'YES';
    if (value.boolean === false) return 'NO';
  }

  if (
    question.responseType === 'numeric' ||
    question.responseType === 'measurement'
  ) {
    if (value.numeric != null) return String(value.numeric);
  }

  if (
    question.responseType === 'date' ||
    question.responseType === 'datetime'
  ) {
    if (value.datetime) return value.datetime;
    if (value.date) return value.date;
  }

  if (
    question.responseType === 'single_select' ||
    question.responseType === 'coded' ||
    question.responseType === 'multi_select'
  ) {
    if (value.code) return value.code;
    if (value.text) {
      const matched = question.options.find(
        (option) => option.label === value.text,
      );
      if (matched) return matched.answerCode;
    }
  }

  if (
    question.responseType === 'text' ||
    question.responseType === 'free_text'
  ) {
    if (value.text) return value.text;
  }

  return '';
}
