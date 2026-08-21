// components/Clinical/FactChips.tsx

import { useMemo, useState } from 'react';
import type {
  ClinicalRuntimeProjection,
  Fact,
} from '../../types';
import {
  factDisplayValue,
  sourceNice,
} from '../../types';
import {
  DnaIcon,
  SearchIcon,
  ArrowRightIcon,
} from '../Icons';

interface FactChipsProps {
  projection: ClinicalRuntimeProjection;
}

interface FactUsage {
  differentials: string[];
  phenotypes: string[];
  documentation: string[];
}

interface FactChipProps {
  fact: Fact;
  usage: FactUsage;
}

type FactFilter =
  | 'all'
  | 'positive'
  | 'negative'
  | 'recent';

const NEGATIVE_VALUES = new Set([
  'NO',
  'NONE',
  'FALSE',
  'NEVER',
  'ABSENT',
  'NEGATIVE',
  'NOT_PRESENT',
  'NO_KNOWN',
]);

const formatTime = (timestamp: string | number | Date): string => {
  const date = new Date(timestamp);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown';
  }

  return date.toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });
};

const formatDateTime = (timestamp: string | number | Date): string => {
  const date = new Date(timestamp);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown';
  }

  return date.toLocaleString([], {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
};

const normalize = (value: string | null | undefined): string =>
  String(value ?? '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '_');

const isNegativeFact = (fact: Fact): boolean => {
  return fact.values.some((value) => {
    if (value.boolean === false) {
      return true;
    }

    if (value.text != null) {
      return NEGATIVE_VALUES.has(normalize(value.text));
    }

    if (value.code != null) {
      return NEGATIVE_VALUES.has(normalize(value.code));
    }

    return false;
  });
};

const isPositiveFact = (fact: Fact): boolean => {
  if (isNegativeFact(fact)) {
    return false;
  }

  return fact.values.some((value) => {
    if (value.boolean === true) {
      return true;
    }

    if (value.text != null && value.text.trim() !== '') {
      return true;
    }

    if (value.code != null && value.code.trim() !== '') {
      return true;
    }

    return value.numeric != null;
  });
};

const factSectionLabel = (fact: Fact): string => {
  return fact.factCode
    .split('_')
    .map((part) => part.charAt(0) + part.slice(1).toLowerCase())
    .join(' ');
};

const buildFactUsage = (
  projection: ClinicalRuntimeProjection,
): Map<string, FactUsage> => {
  const usage = new Map<string, FactUsage>();

  const ensure = (factCode: string): FactUsage => {
    const existing = usage.get(factCode);

    if (existing) {
      return existing;
    }

    const created: FactUsage = {
      differentials: [],
      phenotypes: [],
      documentation: [],
    };

    usage.set(factCode, created);

    return created;
  };

  for (const differential of projection.differentials) {
    for (const evidence of differential.evidence ?? []) {
      const target = ensure(evidence.factCode);

      if (!target.differentials.includes(differential.name)) {
        target.differentials.push(differential.name);
      }
    }
  }

  for (const phenotype of projection.phenotypes) {
    if (!phenotype.name) {
      continue;
    }

    for (const fact of projection.capturedFacts) {
      const target = ensure(fact.factCode);

      if (!target.phenotypes.includes(phenotype.name)) {
        target.phenotypes.push(phenotype.name);
      }
    }
  }

  for (const documentation of projection.documentation) {
    for (const sentence of documentation.sentences ?? []) {
      if (!sentence.factCode) {
        continue;
      }

      const target = ensure(sentence.factCode);
      const label =
        documentation.section;

      if (!target.documentation.includes(label)) {
        target.documentation.push(label);
      }
    }
  }

  return usage;
};

const sortFacts = (facts: Fact[]): Fact[] => {
  return [...facts].sort((a, b) => {
    const aTime = new Date(a.recordedAt).getTime();
    const bTime = new Date(b.recordedAt).getTime();

    return bTime - aTime;
  });
};

export function FactChips({
  projection,
}: FactChipsProps) {
  const facts = projection.capturedFacts ?? [];

  const [filter, setFilter] = useState<FactFilter>('all');
  const [query, setQuery] = useState('');
  const [expandedFactId, setExpandedFactId] = useState<string | null>(null);

  const usageMap = useMemo(
    () => buildFactUsage(projection),
    [projection],
  );

  const filteredFacts = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    const now = Date.now();
    const twentyFourHours = 24 * 60 * 60 * 1000;

    return sortFacts(facts).filter((fact) => {
      const negative = isNegativeFact(fact);
      const positive = isPositiveFact(fact);

      if (filter === 'positive' && !positive) {
        return false;
      }

      if (filter === 'negative' && !negative) {
        return false;
      }

      if (filter === 'recent') {
        const recorded = new Date(fact.recordedAt).getTime();

        if (
          Number.isNaN(recorded) ||
          now - recorded > twentyFourHours
        ) {
          return false;
        }
      }

      if (!normalizedQuery) {
        return true;
      }

      const searchable = [
        fact.factCode,
        factDisplayValue(fact),
        sourceNice(fact.sourceType),
        fact.statusCode,
      ]
        .join(' ')
        .toLowerCase();

      return searchable.includes(normalizedQuery);
    });
  }, [facts, filter, query]);

  const counts = useMemo(() => {
    let positive = 0;
    let negative = 0;
    let recent = 0;

    const now = Date.now();
    const twentyFourHours = 24 * 60 * 60 * 1000;

    for (const fact of facts) {
      if (isPositiveFact(fact)) {
        positive += 1;
      }

      if (isNegativeFact(fact)) {
        negative += 1;
      }

      const recorded = new Date(fact.recordedAt).getTime();

      if (
        !Number.isNaN(recorded) &&
        now - recorded <= twentyFourHours
      ) {
        recent += 1;
      }
    }

    return {
      total: facts.length,
      positive,
      negative,
      recent,
    };
  }, [facts]);

  const toggleFact = (factId: string) => {
    setExpandedFactId((current) =>
      current === factId ? null : factId,
    );
  };

  return (
    <section className="card fact-chips-panel">
      <header className="card-header fact-chips-header">
        <div>
          <h2>
            <span className="section-icon">
              <DnaIcon size={16} />
            </span>
            Captured facts
          </h2>

          <span className="muted small">
            Realtime clinical state
          </span>
        </div>

        <span className="muted small">
          {counts.total} on record
        </span>
      </header>

      {facts.length === 0 ? (
        <EmptyFacts />
      ) : (
        <>
          <div className="fact-toolbar">
            <div className="fact-search">
              <input
                type="search"
                value={query}
                placeholder="Search captured facts..."
                aria-label="Search captured facts"
                onChange={(event) =>
                  setQuery(event.target.value)
                }
              />
            </div>

            <div
              className="fact-filters"
              role="tablist"
              aria-label="Fact filters"
            >
              <FilterButton
                active={filter === 'all'}
                label="All"
                count={counts.total}
                onClick={() => setFilter('all')}
              />

              <FilterButton
                active={filter === 'positive'}
                label="Positive"
                count={counts.positive}
                onClick={() => setFilter('positive')}
              />

              <FilterButton
                active={filter === 'negative'}
                label="Negative"
                count={counts.negative}
                onClick={() => setFilter('negative')}
              />

              <FilterButton
                active={filter === 'recent'}
                label="Recent"
                count={counts.recent}
                onClick={() => setFilter('recent')}
              />
            </div>
          </div>

          {filteredFacts.length === 0 ? (
            <div className="fact-filter-empty">
              <span className="search-icon">
                <SearchIcon size={15} />
              </span>
              <p>No facts match the current filter.</p>
              <button
                type="button"
                className="btn btn-secondary btn-small"
                onClick={() => {
                  setQuery('');
                  setFilter('all');
                }}
              >
                Clear filters
              </button>
            </div>
          ) : (
            <div className="fact-chips">
              {filteredFacts.map((fact) => (
                <FactChip
                  key={fact.id}
                  fact={fact}
                  usage={
                    usageMap.get(fact.factCode) ?? {
                      differentials: [],
                      phenotypes: [],
                      documentation: [],
                    }
                  }
                  open={expandedFactId === fact.id}
                  onToggle={() => toggleFact(fact.id)}
                />
              ))}
            </div>
          )}
        </>
      )}
    </section>
  );
}

function FilterButton({
  active,
  label,
  count,
  onClick,
}: {
  active: boolean;
  label: string;
  count: number;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      className={`fact-filter ${active ? 'active' : ''}`}
      onClick={onClick}
    >
      <span>{label}</span>
      <span className="filter-count">{count}</span>
    </button>
  );
}

interface ExpandedFactChipProps extends FactChipProps {
  open: boolean;
  onToggle: () => void;
}

function FactChip({
  fact,
  usage,
  open,
  onToggle,
}: ExpandedFactChipProps) {
  const negative = isNegativeFact(fact);
  const positive = isPositiveFact(fact);

  const statusClass = negative
    ? 'negative'
    : positive
      ? 'positive'
      : 'neutral';

  return (
    <article
      className={`fact ${statusClass} ${
        open ? 'fact-open' : ''
      }`}
    >
      <button
        type="button"
        className="fact-chip"
        onClick={onToggle}
        aria-expanded={open}
        aria-controls={`fact-detail-${fact.id}`}
      >
        <span className="fact-status-dot" />

        <span className="fact-chip-main">
          <span className="fact-code">
            {fact.factCode}
          </span>

          <span className="fact-value">
            {factDisplayValue(fact)}
          </span>
        </span>

        <span className="fact-chip-time">
          {formatTime(fact.recordedAt)}
        </span>

        <span
          className="fact-expand"
          aria-hidden="true"
        >
          {open ? '▴' : '▾'}
        </span>
      </button>

      {open && (
        <div
          id={`fact-detail-${fact.id}`}
          className="fact-detail"
        >
          <div className="fact-detail-header">
            <div>
              <span className="fact-detail-label">
                Clinical fact
              </span>

              <strong>{fact.factCode}</strong>

              <span className="muted small">
                {factSectionLabel(fact)}
              </span>
            </div>

            <span className={`fact-state ${statusClass}`}>
              {negative
                ? 'Negative'
                : positive
                  ? 'Positive'
                  : 'Recorded'}
            </span>
          </div>

          <dl className="fact-detail-grid">
            <div>
              <dt>Value</dt>
              <dd>{factDisplayValue(fact)}</dd>
            </div>

            <div>
              <dt>Source</dt>
              <dd>{sourceNice(fact.sourceType)}</dd>
            </div>

            <div>
              <dt>Captured</dt>
              <dd>{formatDateTime(fact.recordedAt)}</dd>
            </div>

            <div>
              <dt>Status</dt>
              <dd>{fact.statusCode}</dd>
            </div>
          </dl>

          <FactUsage usage={usage} />

          <div className="fact-detail-actions">
            <button
              type="button"
              className="btn btn-secondary btn-small"
              onClick={onToggle}
            >
              Close
            </button>
          </div>
        </div>
      )}
    </article>
  );
}

function FactUsage({
  usage,
}: {
  usage: FactUsage;
}) {
  const hasDifferentials =
    usage.differentials.length > 0;

  const hasPhenotypes =
    usage.phenotypes.length > 0;

  const hasDocumentation =
    usage.documentation.length > 0;

  if (
    !hasDifferentials &&
    !hasPhenotypes &&
    !hasDocumentation
  ) {
    return (
      <div className="fact-usage empty">
        <span className="muted small">
          This fact has not yet been linked to downstream
          clinical outputs.
        </span>
      </div>
    );
  }

  return (
    <div className="fact-usage">
      <h4>Realtime downstream use</h4>

      {hasDifferentials && (
        <UsageGroup
          label="Differentials"
          values={usage.differentials}
        />
      )}

      {hasPhenotypes && (
        <UsageGroup
          label="Phenotypes"
          values={usage.phenotypes}
        />
      )}

      {hasDocumentation && (
        <UsageGroup
          label="Documentation"
          values={usage.documentation}
        />
      )}
    </div>
  );
}

function UsageGroup({
  label,
  values,
}: {
  label: string;
  values: string[];
}) {
  return (
    <div className="fact-usage-group">
      <span className="fact-usage-label">
        {label}
      </span>

      <div className="fact-usage-values">
        {values.map((value) => (
          <span
            key={`${label}-${value}`}
            className="fact-usage-value"
          >
            {value}
          </span>
        ))}
      </div>
    </div>
  );
}

function EmptyFacts() {
  return (
    <div className="fact-empty-state">
      <div className="empty-icon">
        <DnaIcon size={30} />
      </div>

      <h3>No captured facts</h3>

      <p>
        Clinical answers will appear here immediately as
        structured facts.
      </p>

      <div className="fact-empty-flow">
        <span>Question</span>
        <span>
          <ArrowRightIcon size={14} />
        </span>
        <span>Fact</span>
        <span>
          <ArrowRightIcon size={14} />
        </span>
        <span>Reasoning</span>
        <span>
          <ArrowRightIcon size={14} />
        </span>
        <span>Documentation</span>
      </div>
    </div>
  );
}