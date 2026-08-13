import type { TimelineEvent } from '../../types';

function eventSummary(e: TimelineEvent): string {
  const p = e.payload ?? {};
  if (e.eventType === 'QUESTION_ANSWERED') return `Answered ${p.questionCode ?? ''}`;
  if (e.eventType === 'SYMPTOM_PRESENTED') return `Presented with ${p.symptom ?? ''}`;
  if (e.eventType === 'EXAM_FINDING_CAPTURED') return `Exam finding ${p.findingCode ?? ''}`;
  if (e.eventType === 'CLINICIAN_DECISION') return `${p.status ?? 'decision'} on ${p.code ?? ''}`;
  if (e.eventType === 'FACT_CAPTURED') return `Fact ${p.factCode ?? ''}`;
  return e.eventType.replace(/_/g, ' ').toLowerCase();
}

export function ClinicalTimeline({ entries }: { entries: TimelineEvent[] }) {
  const sorted = [...entries].sort((a, b) => a.eventId - b.eventId);
  return (
    <section className="card">
      <header className="card-header">
        <h2>Encounter timeline</h2>
        <span className="muted small">the event log is the provenance chain</span>
      </header>
      {sorted.length === 0 ? (
        <p className="muted">No events recorded yet.</p>
      ) : (
        <ul className="timeline">
          {sorted.map((e) => (
            <li key={e.eventId} className="timeline-entry">
              <div className="tl-icon">{icon(e.eventType)}</div>
              <div>
                <div className="tl-head">
                  <span className="tl-type">{eventSummary(e)}</span>
                  <span className="tl-time">{new Date(e.occurredAt).toLocaleTimeString()}</span>
                  <span className="muted small mono">#{e.eventId}</span>
                </div>
                {e.eventType === 'CLINICIAN_DECISION' && (
                  <div className="tl-payload">
                    {e.payload.decisionReason ? `reason: ${e.payload.decisionReason}` : `reason: ${e.payload.reason ?? ''}`}
                  </div>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function icon(type: string): string {
  switch (type) {
    case 'SYMPTOM_PRESENTED':
      return '🩺';
    case 'QUESTION_ANSWERED':
      return '💬';
    case 'EXAM_FINDING_CAPTURED':
      return '👂';
    case 'CLINICIAN_DECISION':
      return '✍️';
    case 'FACT_CAPTURED':
    case 'LAB_RESULT_RECEIVED':
    case 'IMAGING_RESULT_RECEIVED':
      return '🧪';
    case 'ENCOUNTER_STARTED':
      return '🏥';
    default:
      return '•';
  }
}