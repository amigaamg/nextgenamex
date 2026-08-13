import { useState } from 'react';
import type {
  ClinicalRuntimeProjection,
  ContradictionProbe,
  DifferentialCandidate,
  EvidenceLine,
  Explanation,
  MechanismScore,
  PhenotypeScore,
} from '../../types';

type Panel = 'differential' | 'phenotypes' | 'mechanisms' | 'contradictions' | 'explanations';

export function ReasoningDrawer({
  projection,
  onClose,
}: {
  projection: ClinicalRuntimeProjection;
  onClose: () => void;
}) {
  const [panel, setPanel] = useState<Panel>('differential');

  return (
    <div className="reasoning-drawer">
      <header className="drawer-header">
        <h2>Clinical reasoning</h2>
        <span className="muted small">event #{projection.eventId ?? '—'}</span>
      </header>

      <div className="drawer-tabs">
        {([
          'differential',
          'phenotypes',
          'mechanisms',
          'contradictions',
          'explanations',
        ] as Panel[]).map((p) => (
          <button key={p} className={`drawer-tab ${panel === p ? 'active' : ''}`} onClick={() => setPanel(p)}>
            {p}
          </button>
        ))}
      </div>

      <div className="drawer-body">
        {panel === 'differential' && <DifferentialPanel differentials={projection.differentials} />}
        {panel === 'phenotypes' && <PhenotypePanel phenotypes={projection.phenotypes} />}
        {panel === 'mechanisms' && <MechanismPanel mechanisms={projection.mechanisms} />}
        {panel === 'contradictions' && <ContradictionPanel probes={projection.contradictions} />}
        {panel === 'explanations' && <ExplanationPanel explanations={projection.explanations} />}
      </div>

      <footer className="drawer-footer">
        <button className="btn" onClick={onClose}>
          Close
        </button>
      </footer>
    </div>
  );
}

function DifferentialPanel({ differentials }: { differentials: DifferentialCandidate[] }) {
  if (differentials.length === 0) return <p className="muted">No differential yet — answer the adaptive questions first.</p>;
  return (
    <div className="differential-list">
      {differentials.map((d, i) => (
        <div key={d.conditionCode} className="diff-row">
          <div className="diff-head">
            <span className="diff-rank">{rankingEmoji(i)}</span>
            <span className="diff-name">{d.name}</span>
            <span className="diff-score">{Math.round(d.compatibility * 100)}%</span>
          </div>
          <div className="diff-bar">
            <div className="diff-bar-fill" style={{ width: `${Math.min(100, d.compatibility * 100)}%` }} />
          </div>
          {d.viaPhenotypes.length > 0 && (
            <div className="muted small">via {d.viaPhenotypes.map((p) => p.phenotypeCode).join(', ')}</div>
          )}
          <EvidenceRows evidence={d.evidence} />
        </div>
      ))}
    </div>
  );
}

function rankingEmoji(i: number): string {
  return ['🟢', '🟡', '🟡', '🔵', '⚪'][i] ?? '⚪';
}

function EvidenceRows({ evidence }: { evidence: EvidenceLine[] }) {
  if (evidence.length === 0) return null;
  return (
    <div className="evidence-inline">
      {evidence.map((e, i) => (
        <span key={i} className={`evl evl-${e.support}`}>
          {e.support === 'support' ? '+' : '−'} {e.factCode} ({Math.round(e.weight * 100)})
        </span>
      ))}
    </div>
  );
}

function PhenotypePanel({ phenotypes }: { phenotypes: PhenotypeScore[] }) {
  if (phenotypes.length === 0) return <p className="muted">No phenotypes scored yet.</p>;
  return (
    <div className="panel-list">
      {phenotypes.map((p) => (
        <div key={p.phenotypeCode} className="panel-row">
          <div className="row-head">
            <span>{p.name}</span>
            <span className="mono">
              {p.score.toFixed(1)}/{p.maxScore.toFixed(1)} · {Math.round(p.compatibility * 100)}%
            </span>
          </div>
          <div className="diff-bar">
            <div className="diff-bar-fill" style={{ width: `${Math.min(100, (p.score / (p.maxScore || 1)) * 100)}%` }} />
          </div>
          <div className="muted small mono">{p.phenotypeCode}</div>
        </div>
      ))}
    </div>
  );
}

function MechanismPanel({ mechanisms }: { mechanisms: MechanismScore[] }) {
  if (mechanisms.length === 0) return <p className="muted">No mechanisms resolved yet.</p>;
  return (
    <div className="panel-list">
      {mechanisms.map((m) => (
        <div key={m.mechanismCode} className="panel-row">
          <div className="row-head">
            <span>{m.name}</span>
            <span className="mono diff-score">{m.support.toFixed(1)}</span>
          </div>
          {m.viaPhenotypes.length > 0 && (
            <div className="muted small">
              via {m.viaPhenotypes.map((p) => `${p.phenotypeCode} (${p.weight})`).join(', ')}
            </div>
          )}
          <div className="muted small mono">{m.mechanismCode}</div>
        </div>
      ))}
    </div>
  );
}

function ContradictionPanel({ probes }: { probes: ContradictionProbe[] }) {
  if (probes.length === 0) return <p className="muted">No contradiction probes raised.</p>;
  return (
    <div className="panel-list">
      {probes.map((p) => (
        <div key={p.factCode} className="panel-row">
          <div className="row-head">
            <span className="mono">{p.factCode}</span>
            <span className="tag tag-danger">probe</span>
          </div>
          <div className="small">{p.expectation}</div>
          <div className="muted small">{p.reason}</div>
        </div>
      ))}
    </div>
  );
}

function ExplanationPanel({ explanations }: { explanations: Explanation[] }) {
  if (explanations.length === 0) {
    return <p className="muted">No explanations generated yet.</p>;
  }
  return (
    <div className="stack">
      {explanations.map((e) => (
        <div key={e.label} className="panel-row">
          <div className="row-head">
            <span>{e.label}</span>
          </div>
          <div className="muted small">{e.body}</div>
        </div>
      ))}
    </div>
  );
}