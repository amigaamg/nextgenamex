import type { TimelineEvent } from '../../types';
import { ClockIcon } from '../Icons';

interface ClinicalTimelineProps {
  entries: TimelineEvent[];
  projection?: unknown;
}

type TimelineCategory =
  | 'encounter'
  | 'history'
  | 'examination'
  | 'investigation'
  | 'reasoning'
  | 'decision'
  | 'documentation'
  | 'system';

interface TimelineMeta {
  label: string;
  category: TimelineCategory;
  icon: string;
}

const EVENT_META: Record<string, TimelineMeta> = {
  ENCOUNTER_STARTED: {
    label: 'Encounter started',
    category: 'encounter',
    icon: 'EC',
  },
  ENCOUNTER_UPDATED: {
    label: 'Encounter updated',
    category: 'encounter',
    icon: 'EC',
  },
  ENCOUNTER_COMPLETED: {
    label: 'Encounter completed',
    category: 'encounter',
    icon: 'EC',
  },

  SYMPTOM_PRESENTED: {
    label: 'Symptom presented',
    category: 'history',
    icon: 'HS',
  },
  QUESTION_ASKED: {
    label: 'Question asked',
    category: 'history',
    icon: 'HS',
  },
  QUESTION_ANSWERED: {
    label: 'Question answered',
    category: 'history',
    icon: 'HS',
  },
  QUESTION_SKIPPED: {
    label: 'Question skipped',
    category: 'history',
    icon: 'HS',
  },
  QUESTION_DEFERRED: {
    label: 'Question deferred',
    category: 'history',
    icon: 'HS',
  },
  QUESTION_NOT_APPLICABLE: {
    label: 'Question marked not applicable',
    category: 'history',
    icon: 'HS',
  },

  EXAMINATION_STARTED: {
    label: 'Examination started',
    category: 'examination',
    icon: 'EX',
  },
  EXAM_FINDING_CAPTURED: {
    label: 'Examination finding captured',
    category: 'examination',
    icon: 'EX',
  },
  VITAL_CAPTURED: {
    label: 'Vital sign captured',
    category: 'examination',
    icon: 'EX',
  },
  MEASUREMENT_CAPTURED: {
    label: 'Measurement captured',
    category: 'examination',
    icon: 'EX',
  },

  FACT_CAPTURED: {
    label: 'Clinical fact captured',
    category: 'reasoning',
    icon: 'RS',
  },
  FACT_UPDATED: {
    label: 'Clinical fact updated',
    category: 'reasoning',
    icon: 'RS',
  },
  PHENOTYPE_UPDATED: {
    label: 'Phenotype updated',
    category: 'reasoning',
    icon: 'RS',
  },
  DIFFERENTIAL_UPDATED: {
    label: 'Differential updated',
    category: 'reasoning',
    icon: 'RS',
  },
  DIAGNOSIS_UPDATED: {
    label: 'Working diagnosis updated',
    category: 'reasoning',
    icon: 'RS',
  },
  CLINICAL_REASONING_UPDATED: {
    label: 'Clinical reasoning updated',
    category: 'reasoning',
    icon: 'RS',
  },

  LAB_RESULT_RECEIVED: {
    label: 'Laboratory result received',
    category: 'investigation',
    icon: 'IN',
  },
  LAB_RESULT_UPDATED: {
    label: 'Laboratory result updated',
    category: 'investigation',
    icon: 'IN',
  },
  IMAGING_RESULT_RECEIVED: {
    label: 'Imaging result received',
    category: 'investigation',
    icon: 'IN',
  },
  IMAGING_RESULT_UPDATED: {
    label: 'Imaging result updated',
    category: 'investigation',
    icon: 'IN',
  },
  INVESTIGATION_ORDERED: {
    label: 'Investigation ordered',
    category: 'investigation',
    icon: 'IN',
  },

  CLINICIAN_DECISION: {
    label: 'Clinician decision',
    category: 'decision',
    icon: 'DC',
  },
  MANAGEMENT_DECISION: {
    label: 'Management decision',
    category: 'decision',
    icon: 'DC',
  },
  PROTOCOL_ACTIVATED: {
    label: 'Protocol activated',
    category: 'decision',
    icon: 'DC',
  },
  PROTOCOL_UPDATED: {
    label: 'Protocol updated',
    category: 'decision',
    icon: 'DC',
  },

  DOCUMENTATION_GENERATED: {
    label: 'Documentation generated',
    category: 'documentation',
    icon: 'DO',
  },
  DOCUMENTATION_UPDATED: {
    label: 'Documentation updated',
    category: 'documentation',
    icon: 'DO',
  },

  ALERT_RAISED: {
    label: 'Clinical alert raised',
    category: 'system',
    icon: 'SY',
  },
  ALERT_RESOLVED: {
    label: 'Clinical alert resolved',
    category: 'system',
    icon: 'SY',
  },
  CONFIGURATION_CHANGED: {
    label: 'Configuration changed',
    category: 'system',
    icon: 'SY',
  },
};

const CATEGORY_LABELS: Record<TimelineCategory, string> = {
  encounter: 'Encounter',
  history: 'History',
  examination: 'Examination',
  investigation: 'Investigation',
  reasoning: 'Clinical reasoning',
  decision: 'Decision',
  documentation: 'Documentation',
  system: 'System',
};

function getEventMeta(type: string): TimelineMeta {
  return (
    EVENT_META[type] ?? {
      label: formatEventType(type),
      category: 'system',
      icon: '•',
    }
  );
}

function formatEventType(type: string): string {
  return type
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/_/g, ' ')
    .toLowerCase()
    .replace(/^\w/, (c) => c.toUpperCase());
}

function value(
  payload: Record<string, unknown>,
  key: string,
): string | null {
  const raw = payload[key];

  if (raw === undefined || raw === null || raw === '') {
    return null;
  }

  if (Array.isArray(raw)) {
    return raw.join(', ');
  }

  if (typeof raw === 'object') {
    return JSON.stringify(raw);
  }

  return String(raw);
}

function eventSummary(event: TimelineEvent): string {
  const payload = (event.payload ?? {}) as Record<string, unknown>;

  switch (event.eventType) {
    case 'ENCOUNTER_STARTED':
      return 'Clinical encounter initiated';

    case 'ENCOUNTER_COMPLETED':
      return 'Clinical encounter completed';

    case 'SYMPTOM_PRESENTED': {
      const symptom =
        value(payload, 'symptom') ??
        value(payload, 'symptomCode') ??
        value(payload, 'code');

      return symptom
        ? `Presenting symptom: ${symptom}`
        : 'Presenting symptom recorded';
    }

    case 'QUESTION_ANSWERED': {
      const question =
        value(payload, 'questionText') ??
        value(payload, 'questionCode');

      const answer =
        value(payload, 'answerLabel') ??
        value(payload, 'answerCode') ??
        value(payload, 'rawValue');

      if (question && answer) {
        return `${question}: ${answer}`;
      }

      return question
        ? `Answered ${question}`
        : 'Clinical question answered';
    }

    case 'QUESTION_SKIPPED':
      return `Skipped ${value(payload, 'questionCode') ?? 'clinical question'}`;

    case 'QUESTION_DEFERRED':
      return `Deferred ${value(payload, 'questionCode') ?? 'clinical question'}`;

    case 'QUESTION_NOT_APPLICABLE':
      return `${value(payload, 'questionCode') ?? 'Clinical question'} marked not applicable`;

    case 'EXAM_FINDING_CAPTURED': {
      const finding =
        value(payload, 'findingCode') ??
        value(payload, 'finding');

      const findingValue =
        value(payload, 'value') ??
        value(payload, 'result');

      return finding && findingValue
        ? `${finding}: ${findingValue}`
        : finding
          ? `Exam finding: ${finding}`
          : 'Examination finding captured';
    }

    case 'VITAL_CAPTURED': {
      const vital = value(payload, 'vitalCode') ?? value(payload, 'name');
      const result = value(payload, 'value');

      return vital && result
        ? `${vital}: ${result}${value(payload, 'unit') ? ` ${value(payload, 'unit')}` : ''}`
        : 'Vital sign captured';
    }

    case 'MEASUREMENT_CAPTURED': {
      const measurement =
        value(payload, 'measurementCode') ??
        value(payload, 'name');

      const result = value(payload, 'value');

      return measurement && result
        ? `${measurement}: ${result}${value(payload, 'unit') ? ` ${value(payload, 'unit')}` : ''}`
        : 'Clinical measurement captured';
    }

    case 'FACT_CAPTURED':
    case 'FACT_UPDATED': {
      const factCode = value(payload, 'factCode');
      const factValue =
        value(payload, 'value') ??
        value(payload, 'text');

      return factCode && factValue
        ? `${factCode}: ${factValue}`
        : factCode
          ? `Clinical fact: ${factCode}`
          : getEventMeta(event.eventType).label;
    }

    case 'LAB_RESULT_RECEIVED':
    case 'LAB_RESULT_UPDATED': {
      const test =
        value(payload, 'testName') ??
        value(payload, 'testCode');

      const result =
        value(payload, 'result') ??
        value(payload, 'value');

      return test && result
        ? `${test}: ${result}${value(payload, 'unit') ? ` ${value(payload, 'unit')}` : ''}`
        : test
          ? `Laboratory result: ${test}`
          : getEventMeta(event.eventType).label;
    }

    case 'IMAGING_RESULT_RECEIVED':
    case 'IMAGING_RESULT_UPDATED': {
      const study =
        value(payload, 'studyName') ??
        value(payload, 'studyCode');

      const impression = value(payload, 'impression');

      return study && impression
        ? `${study}: ${impression}`
        : study
          ? `Imaging result: ${study}`
          : 'Imaging result received';
    }

    case 'CLINICIAN_DECISION': {
      const status =
        value(payload, 'status') ??
        value(payload, 'decision');

      const code =
        value(payload, 'code') ??
        value(payload, 'decisionCode');

      return status && code
        ? `${status} · ${code}`
        : status
          ? status
          : 'Clinical decision recorded';
    }

    case 'MANAGEMENT_DECISION':
      return (
        value(payload, 'decision') ??
        value(payload, 'plan') ??
        'Management decision recorded'
      );

    case 'PROTOCOL_ACTIVATED':
    case 'PROTOCOL_UPDATED': {
      const protocol =
        value(payload, 'protocolName') ??
        value(payload, 'protocolCode');

      return protocol
        ? `${getEventMeta(event.eventType).label}: ${protocol}`
        : getEventMeta(event.eventType).label;
    }

    case 'DIAGNOSIS_UPDATED':
      return `Working diagnosis: ${
        value(payload, 'diagnosis') ??
        value(payload, 'diagnosisCode') ??
        'updated'
      }`;

    case 'ALERT_RAISED':
      return `Alert: ${
        value(payload, 'message') ??
        value(payload, 'code') ??
        'clinical risk identified'
      }`;

    case 'ALERT_RESOLVED':
      return `Alert resolved: ${
        value(payload, 'code') ??
        value(payload, 'message') ??
        'clinical alert'
      }`;

    default:
      return getEventMeta(event.eventType).label;
  }
}

function eventDetail(event: TimelineEvent): string | null {
  const payload = (event.payload ?? {}) as Record<string, unknown>;

  const reason =
    value(payload, 'decisionReason') ??
    value(payload, 'reason');

  if (reason) {
    return `Reason: ${reason}`;
  }

  const source =
    value(payload, 'source') ??
    value(payload, 'sourceType');

  if (source) {
    return `Source: ${source}`;
  }

  return null;
}

function formatTime(iso: string): string {
  const date = new Date(iso);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown time';
  }

  return date.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

function formatDate(iso: string): string {
  const date = new Date(iso);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown date';
  }

  return date.toLocaleDateString([], {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function sameDay(a: string, b: string): boolean {
  const first = new Date(a);
  const second = new Date(b);

  return (
    first.getFullYear() === second.getFullYear() &&
    first.getMonth() === second.getMonth() &&
    first.getDate() === second.getDate()
  );
}

export function ClinicalTimeline({
  entries,
}: ClinicalTimelineProps) {
  const sorted = [...entries].sort((a, b) => {
    const timeA = new Date(a.occurredAt).getTime();
    const timeB = new Date(b.occurredAt).getTime();

    if (Number.isFinite(timeA) && Number.isFinite(timeB)) {
      return timeA - timeB;
    }

    return a.eventId - b.eventId;
  });

  return (
    <section
      className="card clinical-timeline"
      aria-label="Clinical event timeline"
    >
      <header className="card-header timeline-header">
        <div>
          <h2>
            <span className="section-icon">
              <ClockIcon size={16} />
            </span>
            Encounter timeline
          </h2>
          <span className="muted small">
            Live clinical event provenance
          </span>
        </div>

        <div className="timeline-header-meta">
          <span className="status-pill status-active">
            Live
          </span>

          <span className="muted small">
            {sorted.length} event{sorted.length === 1 ? '' : 's'}
          </span>
        </div>
      </header>

      {sorted.length === 0 ? (
        <div className="timeline-empty">
          <div className="timeline-empty-icon">
            <ClockIcon size={22} />
          </div>
          <strong>No clinical events recorded</strong>
          <p className="muted small">
            Clinical actions, captured facts, examination findings,
            investigations, decisions and system transitions will appear here
            in real time.
          </p>
        </div>
      ) : (
        <div className="timeline-container">
          {sorted.map((event, index) => {
            const meta = getEventMeta(event.eventType);
            const previous = sorted[index - 1];

            const showDate =
              index === 0 ||
              !previous ||
              !sameDay(previous.occurredAt, event.occurredAt);

            const detail = eventDetail(event);

            return (
              <div
                key={`${event.eventId}-${event.eventType}`}
                className={`timeline-group timeline-${meta.category}`}
              >
                {showDate && (
                  <div className="timeline-date">
                    {formatDate(event.occurredAt)}
                  </div>
                )}

                <article className="timeline-entry">
                  <div className="tl-rail" aria-hidden="true">
                    <div className="tl-icon">
                      {meta.icon}
                    </div>
                  </div>

                  <div className="tl-content">
                    <div className="tl-head">
                      <div className="tl-title">
                        <span className="tl-type">
                          {eventSummary(event)}
                        </span>

                        <span className="tl-category">
                          {CATEGORY_LABELS[meta.category]}
                        </span>
                      </div>

                      <div className="tl-meta">
                        <time
                          className="tl-time"
                          dateTime={event.occurredAt}
                        >
                          {formatTime(event.occurredAt)}
                        </time>

                        <span className="muted small mono">
                          #{event.eventId}
                        </span>
                      </div>
                    </div>

                    {detail && (
                      <div className="tl-detail">
                        {detail}
                      </div>
                    )}

                    <div className="tl-event-type muted small mono">
                      {event.eventType}
                    </div>
                  </div>
                </article>
              </div>
            );
          })}
        </div>
      )}
    </section>
  );
}