import { useCallback, useEffect, useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import type { EncounterSummary } from '../api';
import { listEncounters } from '../api';
import { CrossIcon, StethoscopeIcon } from './Icons';

interface EncounterListProps {
  onNewEncounter: (symptom: string) => Promise<void>;
  onOpenEncounter: (encounter: EncounterSummary) => void;
}

const STATUS_META: Record<
  string,
  {
    label: string;
    className: string;
  }
> = {
  in_progress: {
    label: 'In Progress',
    className: 'status-in-progress',
  },
  completed: {
    label: 'Completed',
    className: 'status-completed',
  },
  reviewed: {
    label: 'Reviewed',
    className: 'status-reviewed',
  },
};

function getStatusMeta(status: string) {
  return (
    STATUS_META[status] ?? {
      label: formatStatus(status),
      className: 'status-default',
    }
  );
}

function formatStatus(status: string): string {
  return status
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function formatDate(iso: string): string {
  const date = new Date(iso);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown date';
  }

  const now = new Date();

  const startOfToday = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  );

  const startOfDate = new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
  );

  const diffDays = Math.round(
    (startOfToday.getTime() - startOfDate.getTime()) /
      (1000 * 60 * 60 * 24),
  );

  const time = date.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });

  if (diffDays === 0) {
    return `Today, ${time}`;
  }

  if (diffDays === 1) {
    return `Yesterday, ${time}`;
  }

  if (diffDays > 1 && diffDays < 7) {
    return date.toLocaleDateString([], {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
    });
  }

  return date.toLocaleDateString([], {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function formatPatientId(patientId: string): string {
  return patientId
    ? `PT-${patientId.slice(0, 8).toUpperCase()}`
    : 'Patient';
}

function formatEncounterId(encounterId: string): string {
  return `ENC-${encounterId.slice(0, 6).toUpperCase()}`;
}

function formatAge(age: unknown): string {
  if (age === null || age === undefined || age === '') {
    return 'Age not recorded';
  }

  const numericAge = Number(age);

  if (!Number.isFinite(numericAge)) {
    return String(age);
  }

  return `${numericAge} ${numericAge === 1 ? 'year' : 'years'}`;
}

export function EncounterList({
  onNewEncounter,
  onOpenEncounter,
}: EncounterListProps) {
  const [encounters, setEncounters] = useState<EncounterSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [symptom, setSymptom] = useState('');
  const [creating, setCreating] = useState(false);

  const loadEncounters = useCallback(async (isRefresh = false) => {
    try {
      if (isRefresh) {
        setRefreshing(true);
      } else {
        setLoading(true);
      }

      setError(null);

      const data = await listEncounters();

      setEncounters(Array.isArray(data) ? data : []);
    } catch (error) {
      setError(
        error instanceof Error
          ? error.message
          : 'Unable to load clinical encounters.',
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void loadEncounters();
  }, [loadEncounters]);

  const sortedEncounters = useMemo(() => {
    return [...encounters].sort((a, b) => {
      const aTime = new Date(a.startedAt).getTime();
      const bTime = new Date(b.startedAt).getTime();

      return (
        (Number.isFinite(bTime) ? bTime : 0) -
        (Number.isFinite(aTime) ? aTime : 0)
      );
    });
  }, [encounters]);

  async function handleNewEncounter(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const presentingConcern = symptom.trim();

    if (!presentingConcern || creating) {
      return;
    }

    try {
      setCreating(true);
      setError(null);

      await onNewEncounter(presentingConcern);

      setSymptom('');

      await loadEncounters(true);
    } catch (error) {
      setError(
        error instanceof Error
          ? error.message
          : 'Unable to create the clinical encounter.',
      );
    } finally {
      setCreating(false);
    }
  }

  return (
    <div className="encounter-list-page">
      <header className="list-header">
        <div className="list-title">
          <div className="brand-mark" aria-hidden="true">
            <CrossIcon size={22} />
          </div>

          <div>
            <h1>AMEXAN</h1>
            <span className="subtitle">
              Clinical Encounter Workspace
            </span>
          </div>
        </div>

        <form
          className="new-encounter-form"
          onSubmit={handleNewEncounter}
          noValidate
        >
          <label
            htmlFor="presenting-concern"
            className="sr-only"
          >
            Presenting concern
          </label>

          <input
            id="presenting-concern"
            type="text"
            value={symptom}
            onChange={(event) => setSymptom(event.target.value)}
            placeholder="Presenting concern — cough, chest pain, fever..."
            className="symptom-input"
            disabled={creating}
            autoComplete="off"
            maxLength={500}
          />

          <button
            type="submit"
            className="btn-primary"
            disabled={creating || !symptom.trim()}
          >
            {creating ? (
              <>
                <span
                  className="button-spinner"
                  aria-hidden="true"
                />
                Creating...
              </>
            ) : (
              <>
                <span aria-hidden="true">+</span>
                New Encounter
              </>
            )}
          </button>
        </form>
      </header>

      {error && (
        <div
          className="banner banner-error"
          role="alert"
        >
          <div className="banner-content">
            <strong>Encounter workspace error</strong>
            <span>{error}</span>
          </div>

          <div className="banner-actions">
            <button
              type="button"
              className="btn btn-secondary btn-small"
              onClick={() => void loadEncounters(true)}
              disabled={refreshing}
            >
              {refreshing ? 'Retrying...' : 'Retry'}
            </button>

            <button
              type="button"
              className="banner-close"
              aria-label="Dismiss error"
              onClick={() => setError(null)}
            >
              ×
            </button>
          </div>
        </div>
      )}

      <main className="encounters-main">
        <div className="encounters-toolbar">
          <div>
            <h2>Clinical Encounters</h2>
            <span className="muted small">
              {encounters.length}{' '}
              {encounters.length === 1
                ? 'encounter'
                : 'encounters'}{' '}
              available
            </span>
          </div>

          <button
            type="button"
            className="btn btn-secondary btn-small"
            onClick={() => void loadEncounters(true)}
            disabled={loading || refreshing}
            aria-label="Refresh encounters"
          >
            {refreshing ? 'Refreshing...' : 'Refresh'}
          </button>
        </div>

        {loading ? (
          <EncounterLoadingState />
        ) : sortedEncounters.length === 0 ? (
          <EmptyEncounterState />
        ) : (
          <div
            className="encounters-grid"
            aria-label="Clinical encounters"
          >
            {sortedEncounters.map((encounter, index) => (
              <EncounterCard
                key={encounter.encounterId}
                encounter={encounter}
                index={index}
                onOpen={onOpenEncounter}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

function EncounterCard({
  encounter,
  index,
  onOpen,
}: {
  encounter: EncounterSummary;
  index: number;
  onOpen: (encounter: EncounterSummary) => void;
}) {
  const status = getStatusMeta(encounter.status);

  const patientName =
    encounter.patientName?.trim() ||
    formatPatientId(encounter.patientId);

  const complaint =
    encounter.presentingComplaint?.trim() ||
    'Presenting concern not recorded';

  return (
    <article
      className="encounter-card"
      role="button"
      tabIndex={0}
      onClick={() => onOpen(encounter)}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          onOpen(encounter);
        }
      }}
      aria-label={`Open encounter for ${patientName}`}
    >
      <header className="encounter-header">
        <span className="encounter-number">
          #{index + 1}
        </span>

        <span
          className={`encounter-status ${status.className}`}
        >
          <span
            className="status-dot"
            aria-hidden="true"
          />
          {status.label}
        </span>
      </header>

      <div className="encounter-patient">
        <h3 className="patient-name">
          {patientName}
        </h3>

        <div className="patient-meta">
          <span>{formatAge(encounter.age)}</span>

          {encounter.sex && (
            <>
              <span aria-hidden="true">•</span>
              <span>{encounter.sex}</span>
            </>
          )}

          {encounter.department && (
            <>
              <span aria-hidden="true">•</span>
              <span>{encounter.department}</span>
            </>
          )}
        </div>
      </div>

      <div className="encounter-complaint">
        <span className="complaint-label">
          Presenting concern
        </span>

        <p>{complaint}</p>
      </div>

      <footer className="encounter-footer">
        <time
          className="encounter-date"
          dateTime={encounter.startedAt}
          title={new Date(encounter.startedAt).toLocaleString()}
        >
          {formatDate(encounter.startedAt)}
        </time>

        <span className="encounter-id mono">
          {formatEncounterId(encounter.encounterId)}
        </span>
      </footer>
    </article>
  );
}

function EncounterLoadingState() {
  return (
    <div
      className="loading-state"
      role="status"
      aria-live="polite"
    >
      <div className="loading-spinner" aria-hidden="true" />

      <div>
        <strong>Loading clinical encounters</strong>
        <p className="muted small">
          Retrieving the current encounter workspace...
        </p>
      </div>
    </div>
);
}

export type EncounterPhase = 'biodata' | 'chief_complaint' | 'hpi' | 'past_medical_history' | 'past_surgical_history' | 'drug_history' | 'allergy_history' | 'family_history' | 'social_history' | 'occupational_history' | 'sexual_history' | 'review_of_systems' | 'obstetric_history' | 'gynaecological_history' | 'anc_profile' | 'birth_history' | 'growth_development' | 'immunization' | 'nutrition' | 'psychiatric_history' | 'substance_history' | 'collateral_history' | 'monitoring' | 'investigation' | 'management' | 'summary';

export const PHASES: EncounterPhase[] = [
  'biodata',
  'chief_complaint',
  'hpi',
  'past_medical_history',
  'past_surgical_history',
  'drug_history',
  'allergy_history',
  'family_history',
  'social_history',
  'occupational_history',
  'sexual_history',
  'review_of_systems',
  'obstetric_history',
  'gynaecological_history',
  'anc_profile',
  'birth_history',
  'growth_development',
  'immunization',
  'nutrition',
  'psychiatric_history',
  'substance_history',
  'collateral_history',
  'monitoring',
  'investigation',
  'management',
  'summary',
];

export function EncounterPhaseBar({
  onPhaseChange,
  initialPhase,
  phases,
  activePhase,
  onPhase,
  completion,
  urgency,
}: {
  onPhaseChange?: (phase: EncounterPhase) => void;
  initialPhase?: EncounterPhase;
  phases: EncounterPhase[];
  activePhase: EncounterPhase;
  onPhase: (phaseId: EncounterPhase) => void;
  completion: Record<string, number>;
  urgency: Record<string, "emergency" | "urgent" | "routine" | "important">;
}) {
  const [currentPhase, setCurrentPhase] = useState<EncounterPhase>(
    initialPhase ?? activePhase ?? 'biodata',
  );

  useEffect(() => {
    const next = initialPhase ?? activePhase ?? 'biodata';
    void setCurrentPhase(next);
    onPhaseChange?.(next);
  }, [initialPhase, activePhase, onPhaseChange]);

  const handlePhaseClick = (phase: EncounterPhase) => {
    setCurrentPhase(phase);
    onPhase(phase);
  };

  return (
    <div className="encounter-phase-bar">
      {phases.map((phase) => {
        const isActive = phase === currentPhase;

        const phaseCompletion =
          completion[phase] ?? 0;

        const phaseUrgency = urgency[phase];

        const isActiveUrgent =
          phaseUrgency === 'emergency' ||
          phaseUrgency === 'urgent';

        return (
          <button
            key={phase}
            type="button"
            className={`phase-step ${
              isActive ? 'active' : ''
            } ${
              isActiveUrgent ? 'urgent' : ''
            }`}
            onClick={() => handlePhaseClick(phase)}
            aria-current={isActive}
            aria-label={`${phase} — ${phaseCompletion}% complete`}
          >
            <span className="phase-step-label">
              {phase}
            </span>

            <span className="phase-completion">
              {phaseCompletion}/{100}
            </span>
          </button>
        );
      })}
    </div>
  );
}

function EmptyEncounterState() {
  return (
    <div className="empty-state">
      <div
        className="empty-icon"
        aria-hidden="true"
      >
        <StethoscopeIcon size={32} />
      </div>

      <h2>No clinical encounters yet</h2>

      <p className="muted">
        Start a new encounter using the presenting concern
        field above. AMEXAN will create the clinical workspace
        from the presenting problem.
      </p>
    </div>
  );
}