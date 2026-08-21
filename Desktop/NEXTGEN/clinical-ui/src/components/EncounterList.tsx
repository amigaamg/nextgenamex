import { useCallback, useEffect, useState } from 'react';
import type { FormEvent, KeyboardEvent } from 'react';
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
      label: status.replace(/_/g, ' '),
      className: '',
    }
  );
}

function formatEncounterDate(iso: string): string {
  const date = new Date(iso);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown date';
  }

  const now = new Date();

  if (date.toDateString() === now.toDateString()) {
    return `Today, ${date.toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    })}`;
  }

  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);

  if (date.toDateString() === yesterday.toDateString()) {
    return `Yesterday, ${date.toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    })}`;
  }

  return date.toLocaleDateString([], {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function getEncounterId(encounterId: string): string {
  return `ENC-${encounterId.slice(0, 6).toUpperCase()}`;
}

function getPatientFallback(patientId: string): string {
  return `Patient ${patientId.slice(0, 8)}`;
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

  const loadEncounters = useCallback(async (initial = false) => {
    try {
      if (initial) {
        setLoading(true);
      } else {
        setRefreshing(true);
      }

      setError(null);

      const data = await listEncounters();
      setEncounters(data);
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Failed to load clinical encounters.',
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    let mounted = true;

    const load = async () => {
      try {
        setLoading(true);
        setError(null);

        const data = await listEncounters();

        if (mounted) {
          setEncounters(data);
        }
      } catch (cause) {
        if (mounted) {
          setError(
            cause instanceof Error
              ? cause.message
              : 'Failed to load clinical encounters.',
          );
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };

    void load();

    return () => {
      mounted = false;
    };
  }, []);

  const handleNewEncounter = async (event: FormEvent<HTMLFormElement>) => {
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
      await loadEncounters();
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Failed to create clinical encounter.',
      );
    } finally {
      setCreating(false);
    }
  };

  const handleEncounterKeyDown = (
    event: KeyboardEvent<HTMLElement>,
    encounter: EncounterSummary,
  ) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      onOpenEncounter(encounter);
    }
  };

  return (
    <div className="encounter-list-page">
      <header className="list-header">
        <div className="list-title">
          <div className="header-brand">
            <span className="brand-mark" aria-hidden="true">
              <CrossIcon size={20} />
            </span>
            <div>
              <h1>AMEXAN</h1>
              <span className="subtitle">Clinical Encounters</span>
            </div>
          </div>
        </div>

        <form
          className="new-encounter-form"
          onSubmit={handleNewEncounter}
          noValidate
        >
          <label htmlFor="presenting-concern" className="sr-only">
            Presenting concern
          </label>

          <input
            id="presenting-concern"
            type="text"
            value={symptom}
            onChange={(event) => setSymptom(event.target.value)}
            placeholder="Presenting concern..."
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
            {creating ? 'Creating…' : 'New Encounter'}
          </button>
        </form>
      </header>

      {error && (
        <div className="banner banner-error" role="alert">
          <span>{error}</span>

          <button
            type="button"
            className="banner-dismiss"
            aria-label="Dismiss error"
            onClick={() => setError(null)}
          >
            ×
          </button>
        </div>
      )}

      <main className="encounters-main">
        <div className="encounters-toolbar">
          <div>
            <h2>Clinical encounters</h2>
            <span className="muted small">
              {encounters.length}{' '}
              {encounters.length === 1 ? 'encounter' : 'encounters'}
            </span>
          </div>

          <button
            type="button"
            className="btn btn-secondary btn-small"
            onClick={() => void loadEncounters()}
            disabled={loading || refreshing}
          >
            {refreshing ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>

        {loading ? (
          <div className="loading-state" aria-live="polite">
            <div className="loading-spinner" aria-hidden="true" />
            <span>Loading clinical encounters…</span>
          </div>
        ) : encounters.length === 0 ? (
          <section className="empty-state" aria-live="polite">
            <div className="empty-icon" aria-hidden="true">
              <StethoscopeIcon size={32} />
            </div>

            <h2>No encounters yet</h2>

            <p>
              Start a clinical encounter by entering the patient&apos;s
              presenting concern above.
            </p>

            <button
              type="button"
              className="btn-primary"
              onClick={() =>
                document.getElementById('presenting-concern')?.focus()
              }
            >
              Start first encounter
            </button>
          </section>
        ) : (
          <div className="encounters-grid">
            {encounters.map((encounter, index) => {
              const status = getStatusMeta(encounter.status);

              return (
                <article
                  key={encounter.encounterId}
                  className="encounter-card"
                  role="button"
                  tabIndex={0}
                  aria-label={`Open encounter for ${
                    encounter.patientName ||
                    getPatientFallback(encounter.patientId)
                  }`}
                  onClick={() => onOpenEncounter(encounter)}
                  onKeyDown={(event) =>
                    handleEncounterKeyDown(event, encounter)
                  }
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
                      {encounter.patientName ||
                        getPatientFallback(encounter.patientId)}
                    </h3>

                    <div className="patient-meta">
                      {encounter.age != null && (
                        <span>{encounter.age}y</span>
                      )}

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
                    <span className="muted small">
                      Presenting concern
                    </span>

                    <p>
                      {encounter.presentingComplaint ||
                        'No presenting concern recorded'}
                    </p>
                  </div>

                  <footer className="encounter-footer">
                    <time
                      className="encounter-date"
                      dateTime={encounter.startedAt}
                    >
                      {formatEncounterDate(encounter.startedAt)}
                    </time>

                    <span className="encounter-id mono">
                      {getEncounterId(encounter.encounterId)}
                    </span>
                  </footer>
                </article>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}