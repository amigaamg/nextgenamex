import { useState } from 'react';
import type { ClinicalRuntimeProjection, NextQuestion } from '../../types';

export function QuestionCard({
  projection,
  onAnswer,
  onSkip,
}: {
  projection: ClinicalRuntimeProjection;
  onAnswer: (questionCode: string, answerCode: string) => void;
  onSkip: (questionCode: string) => void;
}) {
  const questions = projection.nextQuestions;
  if (questions.length === 0) {
    return (
      <section className="card">
        <header className="card-header">
          <h2>Adaptive history</h2>
          <span className="muted small">active questions</span>
        </header>
        <p className="muted">No further questions needed for the current reasoning.</p>
      </section>
    );
  }

  return (
    <section className="card">
      <header className="card-header">
        <h2>Adaptive history</h2>
        <span className="muted small">{questions.length} active</span>
      </header>
      <div className="question-list">
        {questions.slice(0, 6).map((q) => (
          <QuestionRow
            key={q.questionCode}
            question={q}
            onAnswer={(code) => onAnswer(q.questionCode, code)}
            onSkip={() => onSkip(q.questionCode)}
          />
        ))}
      </div>
    </section>
  );
}

function QuestionRow({
  question,
  onAnswer,
  onSkip,
}: {
  question: NextQuestion;
  onAnswer: (answerCode: string) => void;
  onSkip: () => void;
}) {
  const [value, setValue] = useState('');
  const hasOptions = question.options.length > 0;
  const mandatory = question.requirementLevel === 'mandatory';

  return (
    <div className="question">
      <div className="question-head">
        <span className={`tag ${mandatory ? 'tag-required' : ''}`}>{mandatory ? 'required' : question.requirementLevel}</span>
        <span className="question-text">{question.text}</span>
      </div>

      {question.responseType === 'numeric' || (question.factCode && !hasOptions) ? (
        <div className="answer-row">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            value={value}
            placeholder={question.unitCode ? `value in ${question.unitCode}` : 'value'}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && value !== '') onAnswer(value);
            }}
          />
          <button className="btn btn-primary" disabled={value === ''} onClick={() => onAnswer(value)}>
            Record
          </button>
        </div>
      ) : (
        <div className="answer-row">
          {question.options.map((o) => (
            <button key={o.answerCode} className="answer" onClick={() => onAnswer(o.answerCode)}>
              {o.label}
            </button>
          ))}
        </div>
      )}

      {!mandatory && (
        <div className="answer-row question-actions">
          {['Skip', 'Not applicable', 'Ask later'].map((action) => (
            <button key={action} className="link question-skip" onClick={onSkip}>
              {action}
            </button>
          ))}
        </div>
      )}
      {mandatory && (
        <div className="muted small question-actions">
          A required question — it determines whether an urgent pathway is active. Please answer or escalate instead of skipping.
        </div>
      )}

      {question.reason && (
        <div className="question-why">
          <details>
            <summary className="link">Why is this asked?</summary>
            <p className="why-body">{question.reason}</p>
          </details>
        </div>
      )}
    </div>
  );
}