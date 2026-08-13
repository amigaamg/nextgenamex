import { useState } from 'react';
import type { ClinicalRuntimeProjection, Fact } from '../../types';
import { factDisplayValue, sourceNice } from '../../types';

export function FactChips({ projection }: { projection: ClinicalRuntimeProjection }) {
  const facts = projection.capturedFacts;
  const usedBy = (factCode: string): string[] => {
    const uses = new Set<string>();
    for (const d of projection.differentials) {
      if (d.evidence.some((e) => e.factCode === factCode)) uses.add(`differential: ${d.name}`);
    }
    for (const p of projection.phenotypes) {
      if (p.name) uses.add(`phenotype: ${p.name}`);
    }
    for (const doc of projection.documentation) {
      if (doc.sentences.some((s) => s.factCode === factCode)) uses.add(`documentation: ${doc.section}`);
    }
    return [...uses];
  };

  return (
    <section className="card">
      <header className="card-header">
        <h2>Captured facts</h2>
        <span className="muted small">{facts.length} on record</span>
      </header>
      {facts.length === 0 ? (
        <p className="muted">Nothing captured yet. Answers become clinical facts immediately.</p>
      ) : (
        <div className="fact-chips">
          {facts.map((f) => (
            <FactChip key={f.id} fact={f} usedBy={usedBy(f.factCode)} />
          ))}
        </div>
      )}
    </section>
  );
}

function FactChip({ fact, usedBy }: { fact: Fact; usedBy: string[] }) {
  const [open, setOpen] = useState(false);
  const negative = fact.values.some((v) => v.boolean === false || ['NO', 'NONE', 'FALSE', 'NEVER'].includes(v.text ?? ''));

  return (
    <div className={`fact ${negative ? 'fact-negative' : ''}`}>
      <button className="fact-chip" onClick={() => setOpen((o) => !o)}>
        <span className="fact-code">{fact.factCode}</span>
        <span className="fact-value">{factDisplayValue(fact)}</span>
      </button>
      {open && (
        <div className="fact-detail">
          <dl>
            <dt>Value</dt>
            <dd>{factDisplayValue(fact)}</dd>
            <dt>Source</dt>
            <dd>{sourceNice(fact.sourceType)}</dd>
            <dt>Captured</dt>
            <dd>{new Date(fact.recordedAt).toLocaleTimeString()}</dd>
            <dt>Status</dt>
            <dd>{fact.statusCode}</dd>
            {usedBy.length > 0 && (
              <>
                <dt>Used by</dt>
                <dd>
                  {usedBy.map((u) => (
                    <div key={u} className="small">
                      • {u}
                    </div>
                  ))}
                </dd>
              </>
            )}
          </dl>
          <div className="fact-detail-actions">
            <button className="btn btn-secondary btn-small" onClick={() => setOpen(false)}>
              Close
            </button>
          </div>
        </div>
      )}
    </div>
  );
}