import { useMemo, useState } from 'react';
import type {
  ClinicalEvent,
  ClinicalRuntimeProjection,
  ClinicalUIState,
  InvestigationRecommendation,
} from '../../types';
import { factDisplayValue, sourceNice } from '../../types';
import { imagingResultReceived, labResultReceived } from '../../api';

/**
 * AMEXAN — Investigation Center
 *
 * Investigation workflow:
 *
 * 1. Laboratory investigations
 * 2. Imaging investigations
 * 3. Special / advanced investigations
 *
 * Every investigation has:
 * - stable investigation code
 * - clinical name
 * - category
 * - rationale
 * - clinician decision state
 * - result capture pathway
 *
 * Results re-enter the clinical reasoning substrate as structured facts.
 */

type InvestigationCategory = 'laboratory' | 'imaging' | 'special';

interface CategorizedInvestigation {
  investigation: InvestigationRecommendation;
  category: InvestigationCategory;
  number: number;
}

/**
 * Known structured result mappings.
 *
 * IMPORTANT:
 * Do not invent an interpretation mapping merely because an investigation
 * exists. If the knowledge layer has not defined a result mapping, the UI
 * deliberately reports that result entry is pending.
 */
const NUMERIC_RESULTS: Record<
  string,
  {
    factCode: string;
    hint: string;
    unit: string;
  }
> = {
  'INV-SPO2': {
    factCode: 'SPO2',
    hint: 'Oxygen saturation',
    unit: '%',
  },
};

const CODED_LAB_RESULTS: Record<
  string,
  {
    factCode: string;
    options: { code: string; label: string }[];
  }
> = {
  // Example structure for future knowledge mappings:
  //
  // 'INV-FBC': {
  //   factCode: 'HAEMOGRAM_PATTERN',
  //   options: [
  //     { code: 'LEUKOCYTOSIS', label: 'Leukocytosis' },
  //     { code: 'NEUTROPHILIA', label: 'Neutrophilia' },
  //   ],
  // },
};

const IMAGING_RESULTS: Record<
  string,
  {
    code: string;
    label: string;
  }[]
> = {
  'INV-CXR': [
    {
      code: 'RLL_CONSOLIDATION',
      label: 'Right lower lobe consolidation',
    },
    {
      code: 'AIRSPACE_OPACITY',
      label: 'Airspace opacity / infiltrate',
    },
    {
      code: 'NORMAL',
      label: 'No acute radiological abnormality',
    },
  ],
};

/**
 * Normalize the investigation category.
 *
 * The knowledge engine should ideally provide a stable `type`.
 * This fallback also supports common legacy values.
 */
function getInvestigationCategory(
  investigation: InvestigationRecommendation,
): InvestigationCategory {
  const type = String(investigation.type ?? '').trim().toLowerCase();

  if (
    type === 'imaging' ||
    type === 'radiology' ||
    type === 'radiological' ||
    type === 'scan'
  ) {
    return 'imaging';
  }

  if (
    type === 'special' ||
    type === 'special_test' ||
    type === 'special-test' ||
    type === 'advanced' ||
    type === 'procedure'
  ) {
    return 'special';
  }

  /**
   * Default investigation type is laboratory.
   *
   * This is preferable to silently placing an unknown investigation into
   * imaging or special testing.
   */
  return 'laboratory';
}

function categoryLabel(category: InvestigationCategory): string {
  switch (category) {
    case 'laboratory':
      return 'Laboratory investigations';
    case 'imaging':
      return 'Imaging';
    case 'special':
      return 'Special / advanced investigations';
  }
}

function categoryDescription(category: InvestigationCategory): string {
  switch (category) {
    case 'laboratory':
      return 'Blood, urine, microbiology and other specimen-based investigations.';
    case 'imaging':
      return 'Radiological and other imaging investigations.';
    case 'special':
      return 'Specialized investigations requiring additional diagnostic pathways.';
  }
}

function categoryClass(category: InvestigationCategory): string {
  return `investigation-group-${category}`;
}

export function InvestigationCenter({
  projection,
  uiState: _uiState,
  onDecision,
  onResult,
}: {
  projection: ClinicalRuntimeProjection;
  uiState?: ClinicalUIState | null;
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

  const investigations = projection.investigations ?? [];

  const categorized = useMemo<CategorizedInvestigation[]>(() => {
    return investigations.map((investigation, index) => ({
      investigation,
      category: getInvestigationCategory(investigation),
      number: index + 1,
    }));
  }, [investigations]);

  const pending = categorized.filter(
    ({ investigation }) =>
      !accepted.has(investigation.investigationCode) &&
      !dismissed.has(investigation.investigationCode),
  );

  const ordered = categorized.filter(({ investigation }) =>
    accepted.has(investigation.investigationCode),
  );

  // Compute result status map: which investigations have captured results
  // and their normal range, for display in the recommendation cards.
  const resultStatusMap = useMemo<Record<string, { hasResults: boolean; normalRange: string | null }>>(
    () => {
      const map: Record<string, { hasResults: boolean; normalRange: string | null }> = {};
      const capturedFactCodes = (projection.capturedFacts ?? []).map(
        (fact) => fact.factCode,
      );
      const hasResult = (code: string) =>
        capturedFactCodes.some((c) => c.includes(code) || code.includes(c));

      // Populate from NUMERIC_RESULTS knowledge mappings
      const numericNormals = Object.values(NUMERIC_RESULTS).reduce(
        (acc, curr) => ({ ...acc, [curr.factCode]: curr.hint }),
        {} as Record<string, string>,
      );

      // Check each investigation in categorized
      categorized.forEach((item) => {
        const code = item.investigation.investigationCode;
        map[code] = {
          hasResults: hasResult(code),
          normalRange: numericNormals[code] ?? null,
        };
      });

      return map;
    },
    [projection.capturedFacts, categorized, NUMERIC_RESULTS],
  );

  const results = (projection.capturedFacts ?? []).filter(
    (fact) =>
      fact.sourceType === 'lab' ||
      fact.sourceType === 'imaging' ||
      fact.sourceType === 'device',
  );

  const decide = (
    investigation: InvestigationRecommendation,
    status: 'accepted' | 'dismissed',
    decisionReason?: string,
  ) => {
    onDecision({
      type: 'investigation',
      code: investigation.investigationCode,
      recommendation: `Order ${investigation.name} (${investigation.investigationCode})`,
      status,
      decisionReason,
    });

    if (status === 'accepted') {
      setAccepted((current) => {
        const next = new Set(current);
        next.add(investigation.investigationCode);
        return next;
      });

      setDismissed((current) => {
        const next = new Set(current);
        next.delete(investigation.investigationCode);
        return next;
      });
    } else {
      setDismissed((current) => {
        const next = new Set(current);
        next.add(investigation.investigationCode);
        return next;
      });
    }

    setReasonFor(null);
  };

  return (
    <section className="stack investigation-center">
      {/* ================================================================
          RECOMMENDATIONS
         ================================================================ */}
      <div className="card">
        <header className="card-header">
          <div>
            <h2>Recommended investigations</h2>
            <p className="muted small">
              Investigation sequence is organized as laboratory → imaging →
              special testing. The CPU recommends; the clinician decides.
            </p>
          </div>

          <span className="muted small">
            {pending.length} pending
          </span>
        </header>

        {pending.length === 0 ? (
          <p className="muted">
            All investigation recommendations have been resolved.
          </p>
        ) : (
          <div className="investigation-groups">
            <InvestigationGroup
              category="laboratory"
              items={pending.filter(
                ({ category }) => category === 'laboratory',
              )}
              reasonFor={reasonFor}
              onDismiss={(code) => setReasonFor(code)}
              onAccept={(item) =>
                decide(item.investigation, 'accepted')
              }
              onDismissReason={(item, reason) =>
                decide(item.investigation, 'dismissed', reason)
              }
              resultStatusMap={resultStatusMap}
            />

            <InvestigationGroup
              category="imaging"
              items={pending.filter(
                ({ category }) => category === 'imaging',
              )}
              reasonFor={reasonFor}
              onDismiss={(code) => setReasonFor(code)}
              onAccept={(item) =>
                decide(item.investigation, 'accepted')
              }
              onDismissReason={(item, reason) =>
                decide(item.investigation, 'dismissed', reason)
              }
              resultStatusMap={resultStatusMap}
            />

            <InvestigationGroup
              category="special"
              items={pending.filter(
                ({ category }) => category === 'special',
              )}
              reasonFor={reasonFor}
              onDismiss={(code) => setReasonFor(code)}
              onAccept={(item) =>
                decide(item.investigation, 'accepted')
              }
              onDismissReason={(item, reason) =>
                decide(item.investigation, 'dismissed', reason)
              }
              resultStatusMap={resultStatusMap}
            />
          </div>
        )}
      </div>

      {/* ================================================================
          ORDERED INVESTIGATIONS
         ================================================================ */}
      {ordered.length > 0 && (
        <OrderedInvestigations
          ordered={ordered}
          onResult={onResult}
        />
      )}

      {/* ================================================================
          RECEIVED RESULTS
         ================================================================ */}
      <div className="card">
        <header className="card-header">
          <div>
            <h2>Investigation results</h2>
            <p className="muted small">
              Received results become structured clinical facts and are
              returned to the reasoning engine.
            </p>
          </div>

          <span className="muted small">
            {results.length} received
          </span>
        </header>

        {results.length === 0 ? (
          <p className="muted">No investigation results received yet.</p>
        ) : (
          <div className="results">
            {results.map((fact) => (
              <ResultRow
                key={fact.id}
                factCode={fact.factCode}
                value={factDisplayValue(fact)}
                source={sourceNice(fact.sourceType)}
              />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}

/* ========================================================================
   INVESTIGATION GROUP
   ======================================================================== */

function InvestigationGroup({
  category,
  items,
  reasonFor,
  onDismiss,
  onAccept,
  onDismissReason,
  resultStatusMap,
}: {
  category: InvestigationCategory;
  items: CategorizedInvestigation[];
  reasonFor: string | null;
  onDismiss: (code: string) => void;
  onAccept: (item: CategorizedInvestigation) => void;
  onDismissReason: (
    item: CategorizedInvestigation,
    reason: string,
  ) => void;
  resultStatusMap: Record<string, { hasResults: boolean; normalRange: string | null }>;
}) {
  if (items.length === 0) return null;

  return (
    <section className={`investigation-group ${categoryClass(category)}`}>
      <header className="investigation-group-header">
        <div>
          <h3>{categoryLabel(category)}</h3>
          <p className="muted small">
            {categoryDescription(category)}
          </p>
        </div>

        <span className="tag">{items.length}</span>
      </header>

      <div className="recommendations">
        {items.map((item) => {
          const status = resultStatusMap[item.investigation.investigationCode];
          return (
            <InvestigationRecommendationCard
              key={item.investigation.investigationCode}
              item={item}
              reasonFor={reasonFor}
              onAccept={onAccept}
              onDismiss={onDismiss}
              onDismissReason={onDismissReason}
              hasResults={status?.hasResults ?? false}
              normalRange={status?.normalRange ?? null}
            />
          );
        })}
      </div>
    </section>
  );
}

/* ========================================================================
   RECOMMENDATION CARD
   ======================================================================== */

function InvestigationRecommendationCard({
  item,
  reasonFor,
  onAccept,
  onDismiss,
  onDismissReason,
  hasResults,
  normalRange,
}: {
  item: CategorizedInvestigation;
  reasonFor: string | null;
  onAccept: (item: CategorizedInvestigation) => void;
  onDismiss: (code: string) => void;
  onDismissReason: (
    item: CategorizedInvestigation,
    reason: string,
  ) => void;
  hasResults: boolean;
  normalRange: string | null;
}) {
  const { investigation, category, number } = item;

  return (
    <article className={`rec investigation-rec ${categoryClass(category)}`}>
      <div className="rec-head">
        <span className="investigation-number">
          {String(number).padStart(2, '0')}
        </span>

        <div className="investigation-rec-main">
          <div className="rec-title-row">
            <span className="rec-name">{investigation.name}</span>

            <span className="rec-type">
              {category === 'laboratory'
                ? 'LAB'
                : category === 'imaging'
                  ? 'IMG'
                  : 'SPECIAL'}
            </span>
          </div>

          <span className="muted small mono">
            {investigation.investigationCode}
          </span>
        </div>
      </div>

      {investigation.rationale && (
        <div className="rec-purpose-block">
          <p className="rec-reason">{investigation.rationale}</p>
          <p className="rec-purpose">
            <strong>Purpose:</strong> {investigation.rationale}
          </p>
          {normalRange && (
            <p className="rec-normal-range">
              <strong>Normal range:</strong> {normalRange}
            </p>
          )}
          {hasResults && (
            <p className="rec-results-captured">
              <strong>Results captured:</strong> Yes
            </p>
          )}
          {!hasResults && (
            <p className="rec-results-pending">
              <strong>Results:</strong> Enter required
            </p>
          )}
        </div>
      )}

      <div className="rec-actions">
        <button
          type="button"
          className="btn btn-primary btn-small"
          onClick={() => onAccept(item)}
        >
          Order investigation
        </button>

        <button
          type="button"
          className="btn btn-small"
          onClick={() => onDismiss(investigation.investigationCode)}
        >
          Dismiss…
        </button>
      </div>

      {reasonFor === investigation.investigationCode && (
        <div className="rec-reason dismissal-reasons">
          <div className="muted small">
            Reason for dismissal:
          </div>

          {[
            'Not clinically necessary',
            'Already available',
            'Patient declined',
            'Resource limitation',
          ].map((reason) => (
            <button
              type="button"
              key={reason}
              className="step-action"
              onClick={() => onDismissReason(item, reason)}
            >
              {reason}
            </button>
          ))}
        </div>
      )}
    </article>
  );
}

/* ========================================================================
   ORDERED INVESTIGATIONS
   ======================================================================== */

function OrderedInvestigations({
  ordered,
  onResult,
}: {
  ordered: CategorizedInvestigation[];
  onResult: (r: { event: ClinicalEvent }) => void;
}) {
  return (
    <div className="card">
      <header className="card-header">
        <div>
          <h2>Ordered investigations</h2>
          <p className="muted small">
            Clinician-approved investigations awaiting results.
          </p>
        </div>

        <span className="muted small">
          {ordered.length} ordered
        </span>
      </header>

      <div className="ordered-investigation-groups">
        {(
          ['laboratory', 'imaging', 'special'] as InvestigationCategory[]
        ).map((category) => {
          const items = ordered.filter(
            (item) => item.category === category,
          );

          if (items.length === 0) return null;

          return (
            <section
              key={category}
              className={`ordered-group ${categoryClass(category)}`}
            >
              <h3>{categoryLabel(category)}</h3>

              <div className="results">
                {items.map((item) => (
                  <div
                    key={item.investigation.investigationCode}
                    className="result-row"
                  >
                    <span className="investigation-number">
                      {String(item.number).padStart(2, '0')}
                    </span>

                    <span className="result-fact mono">
                      {item.investigation.investigationCode}
                    </span>

                    <span className="result-value">
                      {item.investigation.name}
                    </span>

                    <span className="result-source">
                      ordered
                    </span>
                  </div>
                ))}
              </div>

              <div className="results-record">
                {items.map((item) => (
                  <ResultCapture
                    key={item.investigation.investigationCode}
                    investigation={item.investigation}
                    onResult={onResult}
                  />
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </div>
  );
}

/* ========================================================================
   RESULT ROW
   ======================================================================== */

function ResultRow({
  factCode,
  value,
  source,
}: {
  factCode: string;
  value: string;
  source: string;
}) {
  return (
    <div className="result-row">
      <span className="result-fact mono">{factCode}</span>
      <span className="result-value">{value}</span>
      <span className="result-source">{source}</span>
    </div>
  );
}

/* ========================================================================
   RESULT CAPTURE
   ======================================================================== */

function ResultCapture({
  investigation,
  onResult,
}: {
  investigation: InvestigationRecommendation;
  onResult: (r: { event: ClinicalEvent }) => void;
}) {
  const [coded, setCoded] = useState('');
  const [numeric, setNumeric] = useState('');

  const imaging = IMAGING_RESULTS[investigation.investigationCode];
  const numericDef = NUMERIC_RESULTS[investigation.investigationCode];
  const codedLab = CODED_LAB_RESULTS[investigation.investigationCode];

  const hasMapping = Boolean(imaging || numericDef || codedLab);

  if (!hasMapping) {
    return (
      <div className="rec-result result-mapping-pending">
        <div className="rec-result-head">
          <span className="rec-result-name">
            Result entry
          </span>

          <span className="muted small mono">
            {investigation.investigationCode}
          </span>
        </div>

        <p className="muted small">
          Structured result mapping is not yet available for this
          investigation. The result must not be guessed or converted into
          an unsupported clinical fact.
        </p>
      </div>
    );
  }

  const saveCodedResult = () => {
    if (!coded) return;

    if (imaging) {
      onResult({
        event: imagingResultReceived(
          investigation.investigationCode,
          [coded],
        ),
      });
    }

    if (codedLab) {
      const numericCode = Number(coded);

      onResult({
        event: labResultReceived(
          codedLab.factCode,
          numericCode,
          '',
        ),
      });
    }

    setCoded('');
  };

  const saveNumericResult = () => {
    if (!numeric || !numericDef) return;

    onResult({
      event: labResultReceived(
        numericDef.factCode,
        Number(numeric),
        numericDef.unit,
      ),
    });

    setNumeric('');
  };

  return (
    <div className="rec-result">
      <div className="rec-result-head">
        <span className="rec-result-name">
          Record result — {investigation.name}
        </span>

        <span className="muted small mono">
          {investigation.investigationCode}
        </span>
      </div>

      {/* ---------------------------------------------------------------
          CODED RESULT
         --------------------------------------------------------------- */}
      {(imaging || codedLab) && (
        <div className="answer-row">
          {(imaging ?? codedLab?.options ?? []).map((result) => (
            <button
              type="button"
              key={result.code}
              className={`answer ${
                coded === result.code ? 'selected' : ''
              }`}
              onClick={() => setCoded(result.code)}
            >
              {result.label}
            </button>
          ))}
        </div>
      )}

      {(imaging || codedLab) && coded && (
        <div className="result-capture-actions">
          <button
            type="button"
            className="btn btn-primary btn-small"
            onClick={saveCodedResult}
          >
            Save result
          </button>
        </div>
      )}

      {/* ---------------------------------------------------------------
          NUMERIC RESULT
         --------------------------------------------------------------- */}
      {numericDef && (
        <div className="finding-input">
          <input
            type="number"
            inputMode="decimal"
            step="any"
            value={numeric}
            placeholder={`${numericDef.hint} (${numericDef.unit})`}
            onChange={(event) =>
              setNumeric(event.target.value)
            }
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                saveNumericResult();
              }
            }}
          />

          <button
            type="button"
            className="btn btn-primary btn-small"
            disabled={!numeric}
            onClick={saveNumericResult}
          >
            Save
          </button>
        </div>
      )}
    </div>
  );
}