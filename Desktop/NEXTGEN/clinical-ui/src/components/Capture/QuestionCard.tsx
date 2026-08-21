// components/Capture/QuestionCard.tsx

import { useCallback, useMemo, useState } from 'react';
import type {
  EnhancedClinicalRuntimeProjection,
  NextQuestion,
  QuestionDisposition,
  QuestionRequirementLevel,
} from '../../types';
import { ChatIcon } from '../Icons';

interface QuestionCardProps {
  projection: EnhancedClinicalRuntimeProjection;
  onAnswer: (
    questionCode: string,
    answerCodes: string[],
    rawValue?: string | number | null
  ) => void;
  onDisposition: (
    questionCode: string,
    disposition: QuestionDisposition
  ) => void;
}

type RawValue = string | number | null;

export function QuestionCard({
  projection,
  onAnswer,
  onDisposition,
}: QuestionCardProps) {
  const questions = projection.nextQuestions ?? [];

  const orderedQuestions = useMemo(
    () =>
      [...questions].sort(
        (a, b) =>
          Number(b.requirementLevel === 'mandatory') -
            Number(a.requirementLevel === 'mandatory') ||
          b.priority - a.priority
      ),
    [questions]
  );

  if (orderedQuestions.length === 0) {
    return <CompletedHistory />;
  }

  const primary = orderedQuestions[0];
  const queued = orderedQuestions.slice(1);

  return (
    <section className="card adaptive-history" aria-label="Adaptive clinical history">
      <header className="card-header">
        <div>
          <h2>
            <span className="section-icon" aria-hidden="true">
              <ChatIcon size={16} />
            </span>
            Adaptive history
          </h2>

          <span className="muted small">
            {orderedQuestions.length} clinically relevant question
            {orderedQuestions.length === 1 ? '' : 's'} available
          </span>
        </div>

        <span className="status-pill status-active">Live</span>
      </header>

      <PrimaryQuestion
        question={primary}
        onAnswer={onAnswer}
        onDisposition={onDisposition}
      />

      {queued.length > 0 && <QuestionQueue questions={queued} />}
    </section>
  );
}

function CompletedHistory() {
  return (
    <section className="card adaptive-history">
      <header className="card-header">
        <div>
          <h2>
            <span className="section-icon" aria-hidden="true">
              <ChatIcon size={16} />
            </span>
            Adaptive history
          </h2>

          <span className="muted small">
            Clinical information capture
          </span>
        </div>

        <span className="status-pill status-complete">Complete</span>
      </header>

      <div className="question-empty">
        <div className="question-empty-icon" aria-hidden="true">
          ✓
        </div>

        <div>
          <strong>No further questions required</strong>

          <p className="muted">
            The clinical CPU currently has sufficient information for the
            active reasoning state.
          </p>
        </div>
      </div>
    </section>
  );
}

function PrimaryQuestion({
  question,
  onAnswer,
  onDisposition,
}: {
  question: NextQuestion;
  onAnswer: QuestionCardProps['onAnswer'];
  onDisposition: QuestionCardProps['onDisposition'];
}) {
  const answer = useCallback(
    (answerCodes: string[], rawValue?: RawValue) => {
      onAnswer(question.questionCode, answerCodes, rawValue);
    },
    [onAnswer, question.questionCode]
  );

  const dispose = useCallback(
    (disposition: QuestionDisposition) => {
      onDisposition(question.questionCode, disposition);
    },
    [onDisposition, question.questionCode]
  );

  return (
    <article
      className={`primary-question ${
        question.requirementLevel === 'mandatory'
          ? 'primary-question-required'
          : ''
      }`}
    >
      <QuestionMeta question={question} />

      <div className="primary-question-body">
        <h3 className="question-title">{question.text}</h3>

        <QuestionInput
          question={question}
          onAnswer={answer}
        />

        <QuestionDispositionActions
          question={question}
          onDisposition={dispose}
        />

        <QuestionReason question={question} />
      </div>
    </article>
  );
}

function QuestionMeta({ question }: { question: NextQuestion }) {
  const requirementClass =
    question.requirementLevel === 'mandatory'
      ? 'tag-required'
      : question.requirementLevel === 'conditionally_required'
        ? 'tag-conditional'
        : question.requirementLevel === 'recommended'
          ? 'tag-recommended'
          : 'tag-optional';

  return (
    <div className="question-meta">
      <span className={`tag ${requirementClass}`}>
        {formatRequirement(question.requirementLevel)}
      </span>

      {question.priority >= 90 && (
        <span className="tag tag-high-priority">
          High priority
        </span>
      )}

      {question.priority >= 70 && question.priority < 90 && (
        <span className="tag tag-priority">
          Priority
        </span>
      )}

      {question.source?.knowledgeCode && (
        <span className="muted small mono">
          {question.source.knowledgeCode}
        </span>
      )}

      {question.factCode && (
        <span className="muted small mono">
          {question.factCode}
        </span>
      )}
    </div>
  );
}

function formatRequirement(
  value: QuestionRequirementLevel
): string {
  switch (value) {
    case 'mandatory':
      return 'Required';

    case 'conditionally_required':
      return 'Required if applicable';

    case 'recommended':
      return 'Recommended';

    case 'optional':
      return 'Optional';

    default:
      return value;
  }
}

function QuestionInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue?: RawValue
  ) => void;
}) {
  switch (question.responseType) {
    case 'single_choice':
    case 'coded':
      return (
        <SingleChoiceInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'boolean':
      return (
        <BooleanInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'multi_choice':
      return (
        <MultiChoiceInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'numeric':
      return (
        <NumericInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'measurement':
      return (
        <MeasurementInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'range':
      return (
        <RangeInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'date':
      return (
        <DateInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'datetime':
      return (
        <DateTimeInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'duration':
      return (
        <DurationInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'text':
      return (
        <TextInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    case 'long_text':
      return (
        <LongTextInput
          question={question}
          onAnswer={onAnswer}
        />
      );

    default:
      return (
        <div className="question-error" role="alert">
          Unsupported response type.
        </div>
      );
  }
}

function SingleChoiceInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (answerCodes: string[]) => void;
}) {
  return (
    <div
      className="answer-options"
      role="radiogroup"
      aria-label={question.text}
    >
      {question.options.map((option) => (
        <button
          key={option.answerCode}
          type="button"
          className="answer-option"
          onClick={() => onAnswer([option.answerCode])}
        >
          <span className="answer-option-label">
            {option.label}
          </span>

          {option.description && (
            <small className="answer-option-description">
              {option.description}
            </small>
          )}
        </button>
      ))}
    </div>
  );
}

function BooleanInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (answerCodes: string[]) => void;
}) {
  const yes =
    question.options.find(
      (o) =>
        o.answerCode === 'YES' ||
        o.answerCode === 'TRUE'
    )?.answerCode ?? 'YES';

  const no =
    question.options.find(
      (o) =>
        o.answerCode === 'NO' ||
        o.answerCode === 'FALSE'
    )?.answerCode ?? 'NO';

  const unknown =
    question.options.find(
      (o) =>
        o.answerCode === 'UNKNOWN' ||
        o.answerCode === 'UNCERTAIN'
    )?.answerCode;

  return (
    <div
      className="answer-options answer-options-boolean"
      role="radiogroup"
      aria-label={question.text}
    >
      <button
        type="button"
        className="answer-option answer-positive"
        onClick={() => onAnswer([yes])}
      >
        <span>Yes</span>
      </button>

      <button
        type="button"
        className="answer-option answer-negative"
        onClick={() => onAnswer([no])}
      >
        <span>No</span>
      </button>

      {unknown && (
        <button
          type="button"
          className="answer-option answer-unknown"
          onClick={() => onAnswer([unknown])}
        >
          <span>Unknown</span>
        </button>
      )}
    </div>
  );
}

function MultiChoiceInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (answerCodes: string[]) => void;
}) {
  const [selected, setSelected] = useState<string[]>([]);

  const toggle = (code: string) => {
    setSelected((current) =>
      current.includes(code)
        ? current.filter((item) => item !== code)
        : [...current, code]
    );
  };

  const submit = () => {
    if (selected.length === 0) return;

    onAnswer(selected);
    setSelected([]);
  };

  return (
    <div className="multi-choice">
      <div
        className="answer-options"
        role="group"
        aria-label={question.text}
      >
        {question.options.map((option) => {
          const active = selected.includes(
            option.answerCode
          );

          return (
            <button
              key={option.answerCode}
              type="button"
              className={`answer-option ${
                active ? 'selected' : ''
              }`}
              aria-pressed={active}
              onClick={() =>
                toggle(option.answerCode)
              }
            >
              <span
                className="answer-check"
                aria-hidden="true"
              >
                {active ? '✓' : ''}
              </span>

              {option.label}
            </button>
          );
        })}
      </div>

      <button
        type="button"
        className="btn btn-primary"
        disabled={selected.length === 0}
        onClick={submit}
      >
        Record {selected.length} selection
        {selected.length === 1 ? '' : 's'}
      </button>
    </div>
  );
}

function NumericInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: number
  ) => void;
}) {
  const [value, setValue] = useState('');

  const validation = question.validation;

  const submit = () => {
    const trimmed = value.trim();

    if (!trimmed) return;

    const numeric = Number(trimmed);

    if (!Number.isFinite(numeric)) return;

    if (
      validation?.min != null &&
      numeric < validation.min
    ) {
      return;
    }

    if (
      validation?.max != null &&
      numeric > validation.max
    ) {
      return;
    }

    onAnswer([], numeric);
    setValue('');
  };

  return (
    <div className="answer-input-group">
      <div className="input-with-unit">
        <input
          type="number"
          inputMode="decimal"
          step={validation?.step ?? 'any'}
          min={validation?.min ?? undefined}
          max={validation?.max ?? undefined}
          value={value}
          placeholder={
            question.placeholder ??
            question.unitCode ??
            'Enter value'
          }
          onChange={(event) =>
            setValue(event.target.value)
          }
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              submit();
            }
          }}
        />

        {question.unitCode && (
          <span className="input-unit">
            {question.unitCode}
          </span>
        )}
      </div>

      <button
        type="button"
        className="btn btn-primary"
        disabled={!value.trim()}
        onClick={submit}
      >
        Record
      </button>
    </div>
  );
}

function MeasurementInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: number
  ) => void;
}) {
  const [value, setValue] = useState('');

  const validation = question.validation;

  const submit = () => {
    const trimmed = value.trim();

    if (!trimmed) return;

    const numeric = Number(trimmed);

    if (!Number.isFinite(numeric)) return;

    if (
      validation?.min != null &&
      numeric < validation.min
    ) {
      return;
    }

    if (
      validation?.max != null &&
      numeric > validation.max
    ) {
      return;
    }

    onAnswer([], numeric);
    setValue('');
  };

  return (
    <div className="measurement-input">
      <div className="measurement-field">
        <input
          type="number"
          inputMode="decimal"
          step={validation?.step ?? 'any'}
          min={validation?.min ?? undefined}
          max={validation?.max ?? undefined}
          value={value}
          placeholder={
            question.placeholder ??
            'Enter measurement'
          }
          onChange={(event) =>
            setValue(event.target.value)
          }
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              submit();
            }
          }}
        />

        {question.unitCode && (
          <span className="measurement-unit">
            {question.unitCode}
          </span>
        )}
      </div>

      <button
        type="button"
        className="btn btn-primary"
        disabled={!value.trim()}
        onClick={submit}
      >
        Record
      </button>
    </div>
  );
}

function RangeInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: number
  ) => void;
}) {
  const min = question.validation?.min ?? 0;
  const max = question.validation?.max ?? 10;
  const step = question.validation?.step ?? 1;

  const [value, setValue] = useState(
    String(min)
  );

  const numericValue = Number(value);

  return (
    <div className="range-input">
      <div className="range-value" aria-live="polite">
        {value}
        {question.unitCode
          ? ` ${question.unitCode}`
          : ''}
      </div>

      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        aria-label={question.text}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <div className="range-scale">
        <span>{min}</span>
        <span>{max}</span>
      </div>

      <button
        type="button"
        className="btn btn-primary"
        onClick={() =>
          onAnswer([], numericValue)
        }
      >
        Record
      </button>
    </div>
  );
}

function DateInput({
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: string
  ) => void;
}) {
  const [value, setValue] = useState('');

  return (
    <div className="answer-input-group">
      <input
        type="date"
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <button
        type="button"
        className="btn btn-primary"
        disabled={!value}
        onClick={() => {
          onAnswer([], value);
          setValue('');
        }}
      >
        Record
      </button>
    </div>
  );
}

function DateTimeInput({
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: string
  ) => void;
}) {
  const [value, setValue] = useState('');

  return (
    <div className="answer-input-group">
      <input
        type="datetime-local"
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <button
        type="button"
        className="btn btn-primary"
        disabled={!value}
        onClick={() => {
          onAnswer([], value);
          setValue('');
        }}
      >
        Record
      </button>
    </div>
  );
}

function DurationInput({
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: string
  ) => void;
}) {
  const [value, setValue] = useState('');
  const [unit, setUnit] = useState('days');

  const submit = () => {
    const trimmed = value.trim();

    if (!trimmed) return;

    const numeric = Number(trimmed);

    if (
      !Number.isFinite(numeric) ||
      numeric < 0
    ) {
      return;
    }

    onAnswer([], `${numeric}|${unit}`);
    setValue('');
  };

  return (
    <div className="duration-input">
      <input
        type="number"
        min="0"
        step="any"
        inputMode="decimal"
        value={value}
        placeholder="Duration"
        onChange={(event) =>
          setValue(event.target.value)
        }
        onKeyDown={(event) => {
          if (event.key === 'Enter') {
            event.preventDefault();
            submit();
          }
        }}
      />

      <select
        value={unit}
        onChange={(event) =>
          setUnit(event.target.value)
        }
        aria-label="Duration unit"
      >
        <option value="minutes">minutes</option>
        <option value="hours">hours</option>
        <option value="days">days</option>
        <option value="weeks">weeks</option>
        <option value="months">months</option>
        <option value="years">years</option>
      </select>

      <button
        type="button"
        className="btn btn-primary"
        disabled={!value.trim()}
        onClick={submit}
      >
        Record
      </button>
    </div>
  );
}

function TextInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: string
  ) => void;
}) {
  const [value, setValue] = useState('');

  const submit = () => {
    const trimmed = value.trim();

    if (!trimmed) return;

    onAnswer([], trimmed);
    setValue('');
  };

  return (
    <div className="answer-input-group">
      <input
        type="text"
        value={value}
        placeholder={
          question.placeholder ??
          'Enter response'
        }
        onChange={(event) =>
          setValue(event.target.value)
        }
        onKeyDown={(event) => {
          if (event.key === 'Enter') {
            event.preventDefault();
            submit();
          }
        }}
      />

      <button
        type="button"
        className="btn btn-primary"
        disabled={!value.trim()}
        onClick={submit}
      >
        Record
      </button>
    </div>
  );
}

function LongTextInput({
  question,
  onAnswer,
}: {
  question: NextQuestion;
  onAnswer: (
    answerCodes: string[],
    rawValue: string
  ) => void;
}) {
  const [value, setValue] = useState('');

  const submit = () => {
    const trimmed = value.trim();

    if (!trimmed) return;

    onAnswer([], trimmed);
    setValue('');
  };

  return (
    <div className="answer-long-text">
      <textarea
        value={value}
        placeholder={
          question.placeholder ??
          'Enter clinical response'
        }
        rows={5}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <div className="long-text-actions">
        <span className="muted small">
          {value.length} characters
        </span>

        <button
          type="button"
          className="btn btn-primary"
          disabled={!value.trim()}
          onClick={submit}
        >
          Record
        </button>
      </div>
    </div>
  );
}

function QuestionDispositionActions({
  question,
  onDisposition,
}: {
  question: NextQuestion;
  onDisposition: (
    disposition: QuestionDisposition
  ) => void;
}) {
  const mandatory =
    question.requirementLevel === 'mandatory';

  if (mandatory) {
    return (
      <div className="question-required-message">
        <span
          className="required-indicator"
          aria-hidden="true"
        >
          !
        </span>

        <div>
          <strong>Required</strong>

          <span>
            This question must be answered before
            the current clinical pathway can be
            considered complete.
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="question-actions">
      {question.allowNotApplicable && (
        <button
          type="button"
          className="link question-action"
          onClick={() =>
            onDisposition('not_applicable')
          }
        >
          Not applicable
        </button>
      )}

      {question.allowDefer && (
        <button
          type="button"
          className="link question-action"
          onClick={() =>
            onDisposition('deferred')
          }
        >
          Ask later
        </button>
      )}

      <button
        type="button"
        className="link question-action"
        onClick={() =>
          onDisposition('skipped')
        }
      >
        Skip
      </button>
    </div>
  );
}

function QuestionReason({
  question,
}: {
  question: NextQuestion;
}) {
  if (
    !question.reason &&
    !question.reasoning
  ) {
    return null;
  }

  return (
    <details className="question-why">
      <summary>
        <span>Why is this asked?</span>
      </summary>

      <div className="why-body">
        {question.reason && (
          <p>{question.reason}</p>
        )}

        {question.reasoning?.phenotypeCodes
          ?.length ? (
          <div className="why-section">
            <span className="muted small">
              Phenotypes considered
            </span>

            <div className="reason-codes">
              {question.reasoning.phenotypeCodes.map(
                (code) => (
                  <span
                    className="reason-code"
                    key={code}
                  >
                    {code}
                  </span>
                )
              )}
            </div>
          </div>
        ) : null}

        {question.reasoning?.conditionCodes
          ?.length ? (
          <div className="why-section">
            <span className="muted small">
              Differential relevance
            </span>

            <div className="reason-codes">
              {question.reasoning.conditionCodes.map(
                (code) => (
                  <span
                    className="reason-code"
                    key={code}
                  >
                    {code}
                  </span>
                )
              )}
            </div>
          </div>
        ) : null}

        {question.reasoning?.priorityBasis && (
          <div className="why-section">
            <span className="muted small">
              Priority basis
            </span>

            <p>
              {question.reasoning.priorityBasis}
            </p>
          </div>
        )}
      </div>
    </details>
  );
}

function QuestionQueue({
  questions,
}: {
  questions: NextQuestion[];
}) {
  return (
    <details className="question-queue">
      <summary>
        <span>
          Additional clinically relevant questions
        </span>

        <span className="queue-count">
          {questions.length}
        </span>
      </summary>

      <div className="question-queue-list">
        {questions.map((question) => (
          <div
            key={question.questionCode}
            className={`queued-question ${
              question.requirementLevel ===
              'mandatory'
                ? 'queued-required'
                : ''
            }`}
          >
            <div className="queued-question-content">
              <strong>
                {question.text}
              </strong>

              <div className="queued-question-meta">
                <span className="muted small">
                  {formatRequirement(
                    question.requirementLevel
                  )}
                </span>

                {question.factCode && (
                  <span className="muted small mono">
                    {question.factCode}
                  </span>
                )}
              </div>
            </div>

            <span
              className={`priority-indicator ${
                question.priority >= 90
                  ? 'priority-critical'
                  : question.priority >= 70
                    ? 'priority-high'
                    : ''
              }`}
            >
              {question.priority}
            </span>
          </div>
        ))}
      </div>
    </details>
  );
}