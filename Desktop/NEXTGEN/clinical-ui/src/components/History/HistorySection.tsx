// =============================================================================
// src/clinical/components/HistorySection.tsx
// UNIVERSAL AMEXAN CLINICAL CAPTURE UI
// HUTCHISON-ALIGNED CLINICAL HISTORY STRUCTURE
// =============================================================================

'use client';

import { useState } from 'react';

import type {
  CaptureQuestion,
  ClinicalFact,
  ClinicalFactValue,
  HistorySectionDefinition,
} from '../../clinical/types';

interface HistorySectionProps {
  section: HistorySectionDefinition;
  questions: CaptureQuestion[];
  facts: ClinicalFact[];
  mandatoryRemaining: number;
  onEvent: (event: ClinicalUIEvent) => void;
}

interface ClinicalUIEvent {
  type:
    | 'QUESTION_ANSWERED'
    | 'QUESTION_DISPOSITIONED';

  payload: Record<string, unknown>;
}

const SECTION_DESCRIPTIONS: Record<string, string> = {
  biodata:
    'Patient identification, demographic information, age, sex and relevant background.',
  chief_complaint:
    'The principal reason for the patient seeking medical attention, recorded in the patient’s own terms where possible.',
  hpi:
    'Chronological history of the presenting problem, including onset, evolution, associated features, severity, modifying factors and relevant context.',
  past_medical_history:
    'Previous illnesses, chronic conditions, admissions and clinically important medical events.',
  past_surgical_history:
    'Previous operations, procedures, complications and relevant perioperative history.',
  drug_history:
    'Current, recent and relevant previous medications, including prescribed, over-the-counter and other treatments.',
  allergy_history:
    'Drug, food and other clinically relevant allergies and the nature of previous reactions.',
  family_history:
    'Relevant illnesses and conditions occurring among family members, including hereditary and familial disorders.',
  social_history:
    'Living circumstances, lifestyle, tobacco, alcohol, relevant exposures, support and other social determinants.',
  occupational_history:
    'Occupation, workplace exposures, hazards and occupational factors relevant to the presentation.',
  sexual_history:
    'Sexual and reproductive health information relevant to the clinical problem.',
  review_of_systems:
    'Systematic screening for additional symptoms not already adequately covered in the history of the presenting problem.',
  obstetric_history:
    'Previous pregnancies, deliveries, pregnancy outcomes and relevant obstetric complications.',
  gynaecological_history:
    'Menstrual, reproductive, contraceptive and other relevant gynaecological history.',
  anc_profile:
    'Current pregnancy and antenatal history, including relevant antenatal events, investigations and care.',
  birth_history:
    'Pregnancy, delivery, immediate neonatal period and relevant perinatal events.',
  growth_development:
    'Growth, developmental milestones and developmental concerns appropriate to age.',
  immunization:
    'Routine and additional immunizations, including relevant missed or incomplete vaccinations.',
  nutrition:
    'Feeding pattern, nutritional intake, appetite and relevant nutritional concerns.',
  psychiatric_history:
    'Psychiatric symptoms, previous mental-health disorders, treatment, functioning and relevant psychosocial context.',
  substance_history:
    'Alcohol, tobacco, recreational drugs and other substances, including pattern and consequences of use.',
  collateral_history:
    'Clinically relevant information obtained from relatives, caregivers or other reliable informants.',
  summary:
    'Concise synthesis of the history and the important positive and negative findings established so far.',
};

export function HistorySection({
  section,
  questions,
  facts,
  mandatoryRemaining,
  onEvent,
}: HistorySectionProps) {
  const description =
    SECTION_DESCRIPTIONS[section.code] ?? '';

  if (!section.visible) {
    return null;
  }

  const sectionFacts = facts.filter(
    (fact) => fact.section === section.code,
  );

  const sectionQuestions = questions.filter(
    (question) => question.section === section.code,
  );

  const hasContent =
    sectionFacts.length > 0 ||
    sectionQuestions.length > 0;

  return (
    <section
      className={[
        'history-section',
        section.code,
        sectionFacts.length > 0 ? 'has-content' : '',
        section.required ? 'required' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      id={`panel-${section.code}`}
      role="tabpanel"
      aria-labelledby={`tab-${section.code}`}
    >
      <header className="section-header">
        <div className="section-title-group">
          <div>
            <span className="section-sequence">
              {section.sequence}
            </span>

            <h2 className="section-title">
              {section.label}
            </h2>
          </div>

          {section.required && (
            <span className="required-pill">
              Required
            </span>
          )}
        </div>

        <div className="section-meta">
          <span className="fact-count">
            {sectionFacts.length}{' '}
            {sectionFacts.length === 1 ? 'fact' : 'facts'}
          </span>

          {mandatoryRemaining > 0 && (
            <span className="mandatory-remaining">
              {mandatoryRemaining} mandatory remaining
            </span>
          )}
        </div>
      </header>

      {description && (
        <p className="section-description">
          {description}
        </p>
      )}

      {sectionFacts.length > 0 && (
        <div
          className="section-facts"
          aria-label={`${section.label} recorded information`}
        >
          {sectionFacts.map((fact) => (
            <FactItem
              key={fact.id}
              fact={fact}
            />
          ))}
        </div>
      )}

      {sectionQuestions.length > 0 && (
        <div className="section-questions">
          {sectionQuestions.map((question) => (
            <QuestionRenderer
              key={question.questionCode}
              question={question}
              section={section.code}
              facts={facts}
              onEvent={onEvent}
            />
          ))}
        </div>
      )}

      {!hasContent && (
        <div className="section-empty">
          <span
            className="empty-icon"
            aria-hidden="true"
          >
            +
          </span>

          <p>
            No clinical information has been recorded
            for this section yet.
          </p>

          <p className="empty-hint">
            Relevant questions will appear here as the
            clinical context develops.
          </p>
        </div>
      )}
    </section>
  );
}

function FactItem({
  fact,
}: {
  fact: ClinicalFact;
}) {
  return (
    <article className="fact-item">
      <div className="fact-main">
        <span className="fact-label">
          {formatFactCode(fact.factCode)}
        </span>

        <span className="fact-value">
          {formatFactValue(fact)}
        </span>
      </div>

      <div className="fact-meta">
        <span className="fact-source">
          {formatSource(fact.sourceType)}
        </span>

        {fact.recordedAt && (
          <time
            className="fact-time"
            dateTime={fact.recordedAt}
          >
            {formatDateTime(fact.recordedAt)}
          </time>
        )}
      </div>
    </article>
  );
}

interface QuestionRendererProps {
  question: CaptureQuestion;
  section: string;
  facts: ClinicalFact[];
  onEvent: (event: ClinicalUIEvent) => void;
}

function QuestionRenderer({
  question,
  section,
  facts,
  onEvent,
}: QuestionRendererProps) {
  const alreadyAnswered =
    question.factCode != null &&
    facts.some(
      (fact) =>
        fact.factCode === question.factCode,
    );

  const [value, setValue] = useState('');
  const [error, setError] = useState<string | null>(
    null,
  );

  if (!question.visible) {
    return null;
  }

  if (!question.enabled) {
    return null;
  }

  if (alreadyAnswered) {
    return null;
  }

  const recordAnswer = (
    answerCode: string | string[],
    rawValue?: string | number | null,
  ) => {
    setError(null);

    const codes = Array.isArray(answerCode)
      ? answerCode
      : answerCode
        ? [answerCode]
        : [];

    if (
      codes.length === 0 &&
      (rawValue == null ||
        String(rawValue).trim() === '')
    ) {
      setError('A response is required.');
      return;
    }

    onEvent({
      type: 'QUESTION_ANSWERED',
      payload: {
        questionCode:
          question.questionCode,

        answerCodes: codes,

        rawValue:
          rawValue ?? null,

        section,

        factCode:
          question.factCode ?? null,

        unitCode:
          question.unitCode ?? null,
      },
    });

    setValue('');
  };

  const disposition = (
    dispositionCode:
      | 'not_applicable'
      | 'deferred'
      | 'skipped',
  ) => {
    onEvent({
      type: 'QUESTION_DISPOSITIONED',
      payload: {
        questionCode:
          question.questionCode,
        section,
        factCode:
          question.factCode ?? null,
        disposition:
          dispositionCode,
      },
    });

    setValue('');
    setError(null);
  };

  return (
    <article
      className={[
        'question-card',
        question.requirementLevel ===
        'mandatory'
          ? 'mandatory'
          : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      <header className="question-header">
        <div className="question-meta">
          <span
            className={[
              'requirement-badge',
              question.requirementLevel,
            ].join(' ')}
          >
            {formatRequirement(
              question.requirementLevel,
            )}
          </span>

          {question.factCode && (
            <span className="question-fact-code">
              {question.factCode}
            </span>
          )}
        </div>
      </header>

      <h3 className="question-text">
        {question.text}
      </h3>

      {question.reason && (
        <p className="question-reason">
          {question.reason}
        </p>
      )}

      <div className="question-control">
        {renderQuestionInput(
          question,
          value,
          setValue,
          recordAnswer,
          setError,
        )}
      </div>

      {error && (
        <p
          className="question-error"
          role="alert"
        >
          {error}
        </p>
      )}

      <div className="question-actions">
        {question.allowNotApplicable && (
          <button
            type="button"
            className="disposition-btn"
            onClick={() =>
              disposition('not_applicable')
            }
          >
            Not applicable
          </button>
        )}

        {question.allowDefer && (
          <button
            type="button"
            className="disposition-btn"
            onClick={() =>
              disposition('deferred')
            }
          >
            Ask later
          </button>
        )}

        {question.requirementLevel !==
          'mandatory' && (
          <button
            type="button"
            className="disposition-btn skip"
            onClick={() =>
              disposition('skipped')
            }
          >
            Skip
          </button>
        )}
      </div>
    </article>
  );
}

function renderQuestionInput(
  question: CaptureQuestion,
  value: string,
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >,
  recordAnswer: (
    answerCode: string | string[],
    rawValue?: string | number | null,
  ) => void,
  setError: React.Dispatch<
    React.SetStateAction<string | null>
  >,
) {
  switch (question.responseType) {
    case 'single_select':
    case 'coded':
      return (
        <SingleSelect
          question={question}
          onAnswer={(code) =>
            recordAnswer(code)
          }
        />
      );

    case 'multi_select':
      return (
        <MultiSelect
          question={question}
          onAnswer={(codes) =>
            recordAnswer(codes)
          }
        />
      );

    case 'boolean':
      return (
        <BooleanInput
          question={question}
          onAnswer={(code) =>
            recordAnswer(code)
          }
        />
      );

    case 'numeric':
    case 'measurement':
    case 'range':
      return (
        <NumericInput
          question={question}
          value={value}
          setValue={setValue}
          onError={setError}
          onRecord={(number) =>
            recordAnswer('', number)
          }
        />
      );

    case 'date':
      return (
        <DateInput
          question={question}
          value={value}
          setValue={setValue}
          onRecord={(date) =>
            recordAnswer('', date)
          }
        />
      );

    case 'datetime':
      return (
        <DateTimeInput
          question={question}
          value={value}
          setValue={setValue}
          onRecord={(dateTime) =>
            recordAnswer('', dateTime)
          }
        />
      );

    case 'duration':
      return (
        <DurationInput
          question={question}
          value={value}
          setValue={setValue}
          onRecord={(duration) =>
            recordAnswer('', duration)
          }
        />
      );

    case 'text':
    case 'free_text':
      return (
        <TextInput
          question={question}
          value={value}
          setValue={setValue}
          onRecord={(text) =>
            recordAnswer('', text)
          }
        />
      );

    case 'long_text':
      return (
        <LongTextInput
          question={question}
          value={value}
          setValue={setValue}
          onRecord={(text) =>
            recordAnswer('', text)
          }
        />
      );

    default:
      return (
        <div className="unsupported">
          Unsupported response type.
        </div>
      );
  }
}

function SingleSelect({
  question,
  onAnswer,
}: {
  question: CaptureQuestion;
  onAnswer: (code: string) => void;
}) {
  return (
    <div className="answer-options">
      {question.options.map((option) => (
        <button
          key={option.answerCode}
          type="button"
          className="answer-option"
          onClick={() =>
            onAnswer(option.answerCode)
          }
        >
          {option.label}
        </button>
      ))}

      {question.allowUnknown && (
        <button
          type="button"
          className="answer-option neutral"
          onClick={() =>
            onAnswer('UNKNOWN')
          }
        >
          Unknown
        </button>
      )}

      {question.allowNotApplicable && (
        <button
          type="button"
          className="answer-option neutral"
          onClick={() =>
            onAnswer('NOT_APPLICABLE')
          }
        >
          Not applicable
        </button>
      )}
    </div>
  );
}

function BooleanInput({
  question,
  onAnswer,
}: {
  question: CaptureQuestion;
  onAnswer: (code: string) => void;
}) {
  return (
    <div className="answer-options boolean">
      <button
        type="button"
        className="answer-option positive"
        onClick={() => onAnswer('YES')}
      >
        Yes
      </button>

      <button
        type="button"
        className="answer-option negative"
        onClick={() => onAnswer('NO')}
      >
        No
      </button>

      {question.allowUnknown && (
        <button
          type="button"
          className="answer-option neutral"
          onClick={() =>
            onAnswer('UNKNOWN')
          }
        >
          Unknown
        </button>
      )}

      {question.allowNotApplicable && (
        <button
          type="button"
          className="answer-option neutral"
          onClick={() =>
            onAnswer('NOT_APPLICABLE')
          }
        >
          Not applicable
        </button>
      )}
    </div>
  );
}

function MultiSelect({
  question,
  onAnswer,
}: {
  question: CaptureQuestion;
  onAnswer: (codes: string[]) => void;
}) {
  const [selected, setSelected] =
    useState<Set<string>>(
      () => new Set(),
    );

  const toggle = (code: string) => {
    setSelected((previous) => {
      const next = new Set(previous);

      if (next.has(code)) {
        next.delete(code);
      } else {
        next.add(code);
      }

      return next;
    });
  };

  const submit = () => {
    if (selected.size === 0) {
      return;
    }

    onAnswer([...selected]);
    setSelected(new Set());
  };

  return (
    <div className="multi-select">
      <div className="answer-options">
        {question.options.map((option) => {
          const selectedNow =
            selected.has(
              option.answerCode,
            );

          return (
            <button
              key={option.answerCode}
              type="button"
              className={[
                'answer-option',
                selectedNow
                  ? 'selected'
                  : '',
              ]
                .filter(Boolean)
                .join(' ')}
              aria-pressed={selectedNow}
              onClick={() =>
                toggle(
                  option.answerCode,
                )
              }
            >
              {selectedNow ? '✓ ' : ''}
              {option.label}
            </button>
          );
        })}
      </div>

      <button
        type="button"
        className="btn-primary"
        disabled={selected.size === 0}
        onClick={submit}
      >
        Record{' '}
        {selected.size}{' '}
        {selected.size === 1
          ? 'selection'
          : 'selections'}
      </button>
    </div>
  );
}

function NumericInput({
  question,
  value,
  setValue,
  onError,
  onRecord,
}: {
  question: CaptureQuestion;
  value: string;
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >;
  onError: (
    value: string | null,
  ) => void;
  onRecord: (value: number) => void;
}) {
  const validate = (): number | null => {
    if (value.trim() === '') {
      onError('Enter a value.');
      return null;
    }

    const number = Number(value);

    if (!Number.isFinite(number)) {
      onError(
        'Enter a valid numeric value.',
      );
      return null;
    }

    const validation =
      question.validation;

    if (
      validation?.min != null &&
      number < validation.min
    ) {
      onError(
        `Value must be at least ${validation.min}.`,
      );
      return null;
    }

    if (
      validation?.max != null &&
      number > validation.max
    ) {
      onError(
        `Value must not exceed ${validation.max}.`,
      );
      return null;
    }

    if (
      validation?.step != null &&
      validation.step > 0
    ) {
      const min =
        validation.min ?? 0;

      const quotient =
        (number - min) /
        validation.step;

      if (
        Math.abs(
          quotient -
            Math.round(quotient),
        ) > 1e-9
      ) {
        onError(
          `Value must use increments of ${validation.step}.`,
        );
        return null;
      }
    }

    return number;
  };

  const submit = () => {
    const number = validate();

    if (number == null) {
      return;
    }

    onRecord(number);
    setValue('');
    onError(null);
  };

  return (
    <div className="answer-input">
      <div className="input-wrapper">
        <input
          type="number"
          inputMode="decimal"
          step={
            question.validation?.step ??
            'any'
          }
          min={
            question.validation?.min ??
            undefined
          }
          max={
            question.validation?.max ??
            undefined
          }
          placeholder={
            question.placeholder ??
            'Enter value'
          }
          value={value}
          onChange={(event) => {
            setValue(event.target.value);
            onError(null);
          }}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
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
        className="btn-primary"
        disabled={!value.trim()}
        onClick={submit}
      >
        Record
      </button>
    </div>
  );
}

function DateInput({
  question,
  value,
  setValue,
  onRecord,
}: {
  question: CaptureQuestion;
  value: string;
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >;
  onRecord: (value: string) => void;
}) {
  return (
    <div className="answer-input">
      <input
        type="date"
        aria-label={question.text}
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <button
        type="button"
        className="btn-primary"
        disabled={!value}
        onClick={() => {
          onRecord(value);
          setValue('');
        }}
      >
        Record
      </button>
    </div>
  );
}

function DateTimeInput({
  question,
  value,
  setValue,
  onRecord,
}: {
  question: CaptureQuestion;
  value: string;
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >;
  onRecord: (value: string) => void;
}) {
  return (
    <div className="answer-input">
      <input
        type="datetime-local"
        aria-label={question.text}
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <button
        type="button"
        className="btn-primary"
        disabled={!value}
        onClick={() => {
          onRecord(value);
          setValue('');
        }}
      >
        Record
      </button>
    </div>
  );
}

function DurationInput({
  question,
  value,
  setValue,
  onRecord,
}: {
  question: CaptureQuestion;
  value: string;
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >;
  onRecord: (value: string) => void;
}) {
  const [unit, setUnit] =
    useState(
      question.unitCode ??
        'days',
    );

  return (
    <div className="answer-input duration-input">
      <input
        type="number"
        min={0}
        step="any"
        placeholder={
          question.placeholder ??
          'Duration'
        }
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <select
        value={unit}
        onChange={(event) =>
          setUnit(event.target.value)
        }
      >
        <option value="minutes">
          Minutes
        </option>
        <option value="hours">
          Hours
        </option>
        <option value="days">
          Days
        </option>
        <option value="weeks">
          Weeks
        </option>
        <option value="months">
          Months
        </option>
        <option value="years">
          Years
        </option>
      </select>

      <button
        type="button"
        className="btn-primary"
        disabled={!value.trim()}
        onClick={() => {
          const number = Number(value);

          if (
            !Number.isFinite(number) ||
            number < 0
          ) {
            return;
          }

          onRecord(
            `${number} ${unit}`,
          );

          setValue('');
        }}
      >
        Record
      </button>
    </div>
  );
}

function TextInput({
  question,
  value,
  setValue,
  onRecord,
}: {
  question: CaptureQuestion;
  value: string;
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >;
  onRecord: (value: string) => void;
}) {
  const submit = () => {
    const text = value.trim();

    if (!text) {
      return;
    }

    onRecord(text);
    setValue('');
  };

  return (
    <div className="answer-input">
      <input
        type="text"
        placeholder={
          question.placeholder ??
          'Enter clinical response'
        }
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
        onKeyDown={(event) => {
          if (
            event.key === 'Enter'
          ) {
            submit();
          }
        }}
      />

      <button
        type="button"
        className="btn-primary"
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
  value,
  setValue,
  onRecord,
}: {
  question: CaptureQuestion;
  value: string;
  setValue: React.Dispatch<
    React.SetStateAction<string>
  >;
  onRecord: (value: string) => void;
}) {
  const submit = () => {
    const text = value.trim();

    if (!text) {
      return;
    }

    onRecord(text);
    setValue('');
  };

  return (
    <div className="answer-input long">
      <textarea
        rows={5}
        placeholder={
          question.placeholder ??
          'Enter clinical response'
        }
        value={value}
        onChange={(event) =>
          setValue(event.target.value)
        }
      />

      <button
        type="button"
        className="btn-primary"
        disabled={!value.trim()}
        onClick={submit}
      >
        Record
      </button>
    </div>
  );
}

function formatFactValue(
  fact: ClinicalFact,
): string {
  const value: ClinicalFactValue =
    fact.value;

  if (value.text != null) {
    return value.text;
  }

  if (value.code != null) {
    return formatCode(value.code);
  }

  if (value.boolean != null) {
    return value.boolean
      ? 'Yes'
      : 'No';
  }

  if (value.numeric != null) {
    return [
      value.numeric,
      value.unitCode ??
        fact.value.unitCode,
    ]
      .filter(
        (part) =>
          part != null &&
          part !== '',
      )
      .join(' ');
  }

  if (value.date != null) {
    return formatDate(value.date);
  }

  if (value.datetime != null) {
    return formatDateTime(
      value.datetime,
    );
  }

  return '—';
}

function formatFactCode(
  code: string,
): string {
  return formatCode(code);
}

function formatCode(
  value: string,
): string {
  return value
    .replace(/[_-]+/g, ' ')
    .toLowerCase()
    .replace(
      /\b\w/g,
      (character) =>
        character.toUpperCase(),
    );
}

function formatRequirement(
  requirement:
    | 'mandatory'
    | 'recommended'
    | 'conditional'
    | 'optional',
): string {
  switch (requirement) {
    case 'mandatory':
      return 'Required';

    case 'recommended':
      return 'Recommended';

    case 'conditional':
      return 'Conditional';

    case 'optional':
      return 'Optional';

    default:
      return requirement;
  }
}

function formatSource(
  source: string,
): string {
  return formatCode(source);
}

function formatDate(
  value: string,
): string {
  const date = new Date(
    `${value}T00:00:00`,
  );

  if (
    Number.isNaN(date.getTime())
  ) {
    return value;
  }

  return new Intl.DateTimeFormat(
    undefined,
    {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    },
  ).format(date);
}

function formatDateTime(
  value: string,
): string {
  const date = new Date(value);

  if (
    Number.isNaN(date.getTime())
  ) {
    return value;
  }

  return new Intl.DateTimeFormat(
    undefined,
    {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    },
  ).format(date);
}