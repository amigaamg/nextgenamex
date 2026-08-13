import { useState } from 'react';
import type { ClinicalEvent, ClinicalRuntimeProjection, InvestigationRecommendation } from '../../types';
import { factDisplayValue, sourceNice } from '../../types';
import { imagingResultReceived, labResultReceived } from '../../api';

// Knowledge-driven result entry (spec 4.20 / 4.21): each acknowledged
// investigation offers the result options the CPU can actually interpret.
const NUMERIC_RESULTS: Record<string, { factCode: string; hint: string; unit: string }> = {
  'INV-SPO2': { factCode: 'SPO2', hint: 'Oxygen saturation', unit: '%' },
  'INV-FBC': { factCode: 'SPO2', hint: 'Placeholder — interpretation pending knowledge mapping', unit: '%' },
};

const IMAGING_RESULTS: Record<string, { code: string; label: string }[]> = {
  'INV-CXR': [
    { code: 'RLL_CONSOLIDATION', label: 'Right lower lobe consolidation' },
    { code: 'AIRSPACE_OPACITY', label: 'Airspace opacity / infiltrate' },
    { code: 'NORMAL', label: 'No acute radiological abnormality' },
  ],
};

export function InvestigationCenter({
  projection,
  onDecision,
  onResult,
}: {
  projection: ClinicalRuntimeProjection;
  onDecision: (input: {
    type: string;
    code: string;
    recommendation: string;
    status: 'accepted' | 'modified' | 'dismissed';
    decisionReason?: string;
  }) => void;
  onResult: (r: { event: ClinicalEvent }) => void;
}) {
  const [accepted, setAccepted] = useState<Set<string>>(new Set());
  const [dismissed, setDismissed] = useState<Set<string>>(new Set());
  const [reasonFor, setReasonFor] = useState<string | null>(null);

  const pending = projection.investigations.filter((i) => !accepted.has(i.investigationCode) && !dismissed.has(i.investigationCode));
  const ordered = projection.investigations.filter((i) => accepted.has(i.investigationCode));
  const results = projection.capturedFacts.filter((f) => f.sourceType === 'lab' || f.sourceType === 'imaging' || f.sourceType === 'device');

  const decide = (inv: InvestigationRecommendation, status: 'accepted' | 'dismissed', decisionReason?: string) => {
    onDecision({
      type: 'investigation',
      code: inv.investigationCode,
      recommendation: `Order ${inv.name} (${inv.investigationCode})`,
      status,
      decisionReason,
    });
    if (status === 'accepted') {
      setAccepted((s) => new Set(s).add(inv.investigationCode));
      setDismissed((s) => {
        const next = new Set(s);
        next.delete(inv.investigationCode);
        return next;
      });
    } else {
      setDismissed((s) => new Set(s).add(inv.investigationCode));
    }
    setReasonFor(null);
  };

  return (
    <section className="stack">
      <div className="card">
        <header className="card-header">
          <h2>Recommended investigations</h2>
          <span className="muted small">the CPU recommends; the clinician decides</span>
        </header>
        {pending.length === 0 ? (
          <p className="muted">All recommendations resolved.</p>
        ) : (
          <div className="recommendations">
            {pending.map((inv) => (
              <div key={inv.investigationCode} className="rec">
                <div className="rec-head">
                  <span className="rec-name">{inv.name}</span>
                  <span className="rec-type">{inv.type}</span>
                  <span className="muted small mono">{inv.investigationCode}</span>
                </div>
                {inv.rationale && <p className="rec-reason">{inv.rationale}</p>}
                <div className="rec-actions">
                  <button className="btn btn-primary btn-small" onClick={() => decide(inv, 'accepted')}>
                    Accept
                  </button>
                  <button className="btn btn-small" onClick={() => setReasonFor(inv.investigationCode)}>
                    Dismiss…
                  </button>
                </div>
                {reasonFor === inv.investigationCode && (
                  <div className="rec-reason">
                    <div className="muted small">Reason for dismissal (recorded for the audit trail):</div>
                    {['Not clinically necessary', 'Already available', 'Patient declined', 'Resource limitation'].map((r) => (
                      <button key={r} className="step-action" onClick={() => decide(inv, 'dismissed', r)}>
                        {r}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {ordered.length > 0 && (
        <div className="card">
          <header className="card-header">
            <h2>Ordered</h2>
            <span className="muted small">{ordered.length}</span>
          </header>
          <div className="results">
            {ordered.map((inv) => (
              <div key={inv.investigationCode} className="result-row">
                <span className="result-fact">{inv.investigationCode}</span>
                <span className="result-value">{inv.name}</span>
                <span className="result-source">ordered</span>
              </div>
            ))}
          </div>
          <div className="results-record">
            {ordered.map((inv) => (
              <ResultCapture key={inv.investigationCode} investigation={inv} onResult={onResult} />
            ))}
          </div>
        </div>
      )}

      <div className="card">
        <header className="card-header">
          <h2>Results</h2>
          <span className="muted small">captured results re-enter the reasoning as facts</span>
        </header>
        {results.length === 0 ? (
          <p className="muted">No results received yet.</p>
        ) : (
          <div className="results">
            {results.map((f) => (
              <ResultRow key={f.id} factCode={f.factCode} value={factDisplayValue(f)} source={sourceNice(f.sourceType)} />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

// A compact label row (reused by both ordered and result lists).
function ResultRow({ factCode, value, source }: { factCode: string; value: string; source: string }) {
  return (
    <div className="result-row">
      <span className="result-fact">{factCode}</span>
      <span className="result-value">{value}</span>
      <span className="result-source">{source}</span>
    </div>
  );
}

// Result capture (spec 4.20): record a lab/imaging result back into the CPU.
// Only options the knowledge graph can interpret are offered — a normal CXR
// establishes nothing; a consolidation feeds the same reasoning substrate.
function ResultCapture({
  investigation,
  onResult,
}: {
  investigation: InvestigationRecommendation;
  onResult: (r: { event: ClinicalEvent }) => void;
}) {
  const [coded, setCoded] = useState<string>('');
  const [numeric, setNumeric] = useState('');
  const imaging = IMAGING_RESULTS[investigation.investigationCode];
  const numericDef = NUMERIC_RESULTS[investigation.investigationCode];

  if (!imaging && !numericDef) {
    return (
      <div className="rec-result muted small">
        Result entry pending knowledge mapping for {investigation.investigationCode}.
      </div>
    );
  }

  return (
    <div className="rec-result">
      <div className="rec-result-head">
        <span className="rec-result-name">Record result — {investigation.name}</span>
        <span className="muted small mono">{investigation.investigationCode}</span>
      </div>

      {imaging && (
        <div className="answer-row">
          {imaging.map((r) => (
            <button
              key={r.code}
              className={`answer ${coded === r.code ? 'selected' : ''}`}
              onClick={() => setCoded(r.code)}
            >
              {r.label}
            </button>
          ))}
        </div>
      )}
      {imaging && coded && (
        <div className="result-capture-actions">
          <button
            className="btn btn-primary btn-small"
            onClick={() => {
              onResult({ event: imagingResultReceived(investigation.investigationCode, [coded]) });
              setCoded('');
            }}
          >
            Save result
          </button>
        </div>
      )}

      {numericDef && (
        <div className="finding-input">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            value={numeric}
            placeholder={`${numericDef.hint} (${numericDef.unit})`}
            onChange={(e) => setNumeric(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && numeric !== '') {
                onResult({ event: labResultReceived(numericDef.factCode, Number(numeric), numericDef.unit) });
                setNumeric('');
              }
            }}
          />
          <button
            className="btn btn-primary btn-small"
            disabled={numeric === ''}
            onClick={() => {
              onResult({ event: labResultReceived(numericDef.factCode, Number(numeric), numericDef.unit) });
              setNumeric('');
            }}
          >
            Save
          </button>
        </div>
      )}
    </div>
  );
}