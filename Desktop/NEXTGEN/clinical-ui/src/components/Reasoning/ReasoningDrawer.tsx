import { useMemo, useState } from 'react';
import type {
  ClinicalRuntimeProjection,
  ClinicalUIState,
  ContradictionProbe,
  DifferentialCandidate,
  EvidenceLine,
  Explanation,
  MechanismScore,
  PhenotypeScore,
} from '../../types';

type Panel =
  | 'differential'
  | 'phenotypes'
  | 'mechanisms'
  | 'contradictions'
  | 'explanations';

interface ReasoningDrawerProps {
  projection: ClinicalRuntimeProjection;
  uiState: ClinicalUIState | null;
  onClose: () => void;
}

export function ReasoningDrawer({
  projection,
  uiState: _uiState,
  onClose,
}: ReasoningDrawerProps) {
  const [panel, setPanel] = useState<Panel>('differential');

  const tabs: Array<{ key: Panel; label: string; count: number }> = [
    {
      key: 'differential',
      label: 'Differential',
      count: projection.differentials?.length ?? 0,
    },
    {
      key: 'phenotypes',
      label: 'Phenotypes',
      count: projection.phenotypes?.length ?? 0,
    },
    {
      key: 'mechanisms',
      label: 'Mechanisms',
      count: projection.mechanisms?.length ?? 0,
    },
    {
      key: 'contradictions',
      label: 'Contradictions',
      count: projection.contradictions?.length ?? 0,
    },
    {
      key: 'explanations',
      label: 'Explanations',
      count: projection.explanations?.length ?? 0,
    },
  ];

  const panelTitle = useMemo(
    () => tabs.find((tab) => tab.key === panel)?.label ?? 'Clinical reasoning',
    [panel],
  );

  return (
    <aside
      className="reasoning-drawer"
      aria-label="AMEXAN clinical reasoning"
      role="dialog"
      aria-modal="true"
    >
      <header className="drawer-header">
        <div>
          <div className="drawer-kicker">AMEXAN · Clinical Intelligence</div>
          <h2>Clinical reasoning</h2>
          <p className="muted small">
            Evidence-linked reasoning derived from the current encounter state.
          </p>
        </div>

        <div className="drawer-header-meta">
          <span className="tag">Explainable</span>
          <span className="muted small mono">
            event #{projection.eventId ?? '—'}
          </span>
        </div>
      </header>

      <nav className="drawer-tabs" aria-label="Reasoning views">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            className={`drawer-tab ${panel === tab.key ? 'active' : ''}`}
            onClick={() => setPanel(tab.key)}
            aria-selected={panel === tab.key}
            role="tab"
          >
            <span>{tab.label}</span>
            <span className="drawer-tab-count">{tab.count}</span>
          </button>
        ))}
      </nav>

      <div className="drawer-section-title">
        <span>{panelTitle}</span>
        <span className="muted small">live projection</span>
      </div>

      <div className="drawer-body">
        {panel === 'differential' && (
          <DifferentialPanel differentials={projection.differentials ?? []} />
        )}

        {panel === 'phenotypes' && (
          <PhenotypePanel phenotypes={projection.phenotypes ?? []} />
        )}

        {panel === 'mechanisms' && (
          <MechanismPanel mechanisms={projection.mechanisms ?? []} />
        )}

        {panel === 'contradictions' && (
          <ContradictionPanel probes={projection.contradictions ?? []} />
        )}

        {panel === 'explanations' && (
          <ExplanationPanel explanations={projection.explanations ?? []} />
        )}
      </div>

      <footer className="drawer-footer">
        <div className="muted small">
          Reasoning is traceable to captured evidence and encounter events.
        </div>

        <button type="button" className="btn" onClick={onClose}>
          Close
        </button>
      </footer>
    </aside>
  );
}

function DifferentialPanel({
  differentials,
}: {
  differentials: DifferentialCandidate[];
}) {
  if (differentials.length === 0) {
    return (
      <EmptyState>
        No differential has been resolved yet. Continue structured history,
        examination, and investigation capture.
      </EmptyState>
    );
  }

  // Rank by relevance/significance (not as a diagnostic probability).
  const ranked = [...differentials].sort(
    (a, b) =>
      (b.compatibility ?? 0) - (a.compatibility ?? 0),
  );

  const relevant = ranked.slice(0, 6);
  const others = ranked.slice(6);

  return (
    <div className="differential-list">
      <div className="muted small">
        Ranked by relevance. Start with the most likely / most significant
        working diagnoses; review the constellation of supporting and
        against factors.
      </div>

      {relevant.map((differential, index) => (
        <article
          key={differential.conditionCode}
          className="diff-row"
        >
          <div className="diff-head">
            <div className="diff-title-group">
              <span className="diff-rank">
                {rankingIndicator(index)}
              </span>

              <div>
                <div className="diff-name">
                  {differential.name}
                </div>
                <div className="muted small mono">
                  {differential.conditionCode}
                </div>
                {index === 0 && (
                  <span className="tag tag-primary">
                    Most likely
                  </span>
                )}
              </div>
            </div>

            {differential.reasoning ? (
              <div className="muted small">
                {differential.reasoning}
              </div>
            ) : null}
          </div>

          <EvidenceGroups
            evidence={differential.evidence}
          />
        </article>
      ))}

      {others.length > 0 && (
        <div className="diff-others muted small">
          <strong>Others to consider:</strong>{' '}
          {others.map((other) => other.name).join(', ')}.
        </div>
      )}
    </div>
  );
}

function EvidenceGroups({
  evidence,
}: {
  evidence: EvidenceLine[];
}) {
  if (evidence.length === 0) {
    return (
      <div className="muted small evidence-empty">
        No explicit evidence lines recorded.
      </div>
    );
  }

  const supporting = evidence.filter(
    (item) => item.support === 'support',
  );
  const against = evidence.filter(
    (item) => item.support === 'against',
  );

  return (
    <div className="evidence-groups">
      {supporting.length > 0 && (
        <div className="evidence-group">
          <div className="evidence-group-label">
            Supports (history / examination)
          </div>
          <EvidenceList
            evidence={supporting}
            polarity="support"
          />
        </div>
      )}

      {against.length > 0 && (
        <div className="evidence-group">
          <div className="evidence-group-label">
            Against
          </div>
          <EvidenceList
            evidence={against}
            polarity="against"
          />
        </div>
      )}
    </div>
  );
}

function EvidenceList({
  evidence,
  polarity,
}: {
  evidence: EvidenceLine[];
  polarity: 'support' | 'against';
}) {
  return (
    <div
      className="evidence-inline"
      aria-label={
        polarity === 'support'
          ? 'Supporting factors'
          : 'Factors against'
      }
    >
      {evidence.map((item, index) => (
        <span
          key={`${item.factCode}-${index}`}
          className={`evl evl-${polarity}`}
          title={
            polarity === 'support'
              ? `Supports: ${item.factCode}`
              : `Against: ${item.factCode}`
          }
        >
          <span aria-hidden="true">
            {polarity === 'support' ? '+' : '−'}
          </span>{' '}
          <span className="mono">{item.factCode}</span>{' '}
          <span className="muted small">
            expected: {item.expectation ?? '—'}; found:
            {item.found ? ` ${item.found}` : ' —'}
          </span>
        </span>
      ))}
    </div>
  );
}

function PhenotypePanel({
  phenotypes,
}: {
  phenotypes: PhenotypeScore[];
}) {
  if (phenotypes.length === 0) {
    return (
      <EmptyState>
        No phenotypes have been scored from the current structured state.
      </EmptyState>
    );
  }

  const ranked = [...phenotypes].sort(
    (a, b) => b.compatibility - a.compatibility,
  );

  return (
    <div className="panel-list">
      {ranked.map((phenotype) => {
        const maxScore = phenotype.maxScore || 1;
        const scoreRatio = clampPercentage(
          phenotype.score / maxScore,
        );
        const compatibility = clampPercentage(phenotype.compatibility);

        return (
          <article
            key={phenotype.phenotypeCode}
            className="panel-row"
          >
            <div className="row-head">
              <div>
                <div>{phenotype.name}</div>
                <div className="muted small mono">
                  {phenotype.phenotypeCode}
                </div>
              </div>

              <div className="mono">
                {phenotype.score.toFixed(1)} /{' '}
                {phenotype.maxScore.toFixed(1)}
              </div>
            </div>

            <div className="diff-bar">
              <div
                className="diff-bar-fill"
                style={{ width: `${scoreRatio * 100}%` }}
              />
            </div>

            <div className="panel-metrics">
              <span className="muted small">
                Score: {Math.round(scoreRatio * 100)}%
              </span>
              <span className="muted small">
                Compatibility: {Math.round(compatibility * 100)}%
              </span>
            </div>
          </article>
        );
      })}
    </div>
  );
}

function MechanismPanel({
  mechanisms,
}: {
  mechanisms: MechanismScore[];
}) {
  if (mechanisms.length === 0) {
    return (
      <EmptyState>
        No underlying mechanisms have been resolved from the current evidence.
      </EmptyState>
    );
  }

  const ranked = [...mechanisms].sort(
    (a, b) => b.support - a.support,
  );

  return (
    <div className="panel-list">
      {ranked.map((mechanism) => (
        <article
          key={mechanism.mechanismCode}
          className="panel-row"
        >
          <div className="row-head">
            <div>
              <div>{mechanism.name}</div>
              <div className="muted small mono">
                {mechanism.mechanismCode}
              </div>
            </div>

            <span className="mono diff-score">
              {mechanism.support.toFixed(1)}
            </span>
          </div>

          {mechanism.viaPhenotypes.length > 0 && (
            <div className="mechanism-links">
              <span className="muted small">Derived via</span>

              <div className="chip-row">
                {mechanism.viaPhenotypes.map((phenotype) => (
                  <span
                    key={`${mechanism.mechanismCode}-${phenotype.phenotypeCode}`}
                    className="chip"
                  >
                    {phenotype.phenotypeCode}
                    <span className="muted small">
                      {' '}
                      ({phenotype.weight})
                    </span>
                  </span>
                ))}
              </div>
            </div>
          )}
        </article>
      ))}
    </div>
  );
}

function ContradictionPanel({
  probes,
}: {
  probes: ContradictionProbe[];
}) {
  if (probes.length === 0) {
    return (
      <EmptyState>
        No contradiction probes are currently raised by the reasoning engine.
      </EmptyState>
    );
  }

  return (
    <div className="panel-list">
      {probes.map((probe) => (
        <article
          key={`${probe.factCode}-${probe.reason}`}
          className="panel-row panel-row-danger"
        >
          <div className="row-head">
            <span className="mono">{probe.factCode}</span>
            <span className="tag tag-danger">Probe</span>
          </div>

          <div className="small">
            <strong>Expected:</strong> {probe.expectation}
          </div>

          <div className="muted small">
            <strong>Reason:</strong> {probe.reason}
          </div>
        </article>
      ))}
    </div>
  );
}

function ExplanationPanel({
  explanations,
}: {
  explanations: Explanation[];
}) {
  if (explanations.length === 0) {
    return (
      <EmptyState>
        No explanations have been generated from the current structured state.
      </EmptyState>
    );
  }

  return (
    <div className="stack">
      {explanations.map((explanation, index) => (
        <article
          key={`${explanation.label}-${index}`}
          className="panel-row"
        >
          <div className="row-head">
            <span>{explanation.label}</span>
          </div>

          <div className="muted small">{explanation.body}</div>
        </article>
      ))}
    </div>
  );
}

function EmptyState({ children }: { children: React.ReactNode }) {
  return (
    <div className="reasoning-empty">
      <div className="reasoning-empty-icon" aria-hidden="true">
        ◌
      </div>
      <p className="muted">{children}</p>
    </div>
  );
}

function rankingIndicator(index: number): string {
  switch (index) {
    case 0:
      return '1';
    case 1:
      return '2';
    case 2:
      return '3';
    case 3:
      return '4';
    default:
      return String(index + 1);
  }
}

function clampPercentage(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(1, value));
}