import { useMemo, useState } from 'react';
import type { ClinicalFact } from '../../clinical/types';

interface FactSummaryProps {
  facts: ClinicalFact[];
  onExport?: () => void;
  onGenerateNote?: () => void;
  defaultExpanded?: boolean;
  showActions?: boolean;
}

interface FactGroup {
  section: string;
  facts: ClinicalFact[];
}

const SECTION_LABELS: Record<string, string> = {
  biodata: 'Biodata',
  chief_complaint: 'Chief Complaint',
  hpi: 'History of Present Illness',
  past_medical_history: 'Past Medical History',
  past_surgical_history: 'Past Surgical History',
  drug_history: 'Drug History',
  allergy_history: 'Allergy History',
  family_history: 'Family History',
  social_history: 'Social History',
  occupational_history: 'Occupational History',
  sexual_history: 'Sexual History',
  review_of_systems: 'Review of Systems',
  obstetric_history: 'Obstetric History',
  gynaecological_history: 'Gynaecological History',
  anc_profile: 'Antenatal Profile',
  birth_history: 'Birth History',
  growth_development: 'Growth & Development',
  immunization: 'Immunization',
  nutrition: 'Nutrition',
  psychiatric_history: 'Psychiatric History',
  substance_history: 'Substance History',
  collateral_history: 'Collateral History',
  summary: 'Clinical Summary',
};

const SOURCE_LABELS: Record<string, string> = {
  patient: 'Patient',
  caregiver: 'Caregiver',
  clinician: 'Clinician',
  observation: 'Observation',
  imported: 'Imported',
  derived: 'Derived',
  system: 'System',
};

export function FactSummary({
  facts,
  onExport,
  onGenerateNote,
  defaultExpanded = false,
  showActions = true,
}: FactSummaryProps) {
  const [expandedSections, setExpandedSections] = useState<Set<string>>(
    () =>
      defaultExpanded
        ? new Set(facts.map((fact) => fact.section || 'other'))
        : new Set(),
  );

  const groups = useMemo<FactGroup[]>(() => {
    const grouped = new Map<string, ClinicalFact[]>();

    for (const clinicalFact of facts) {
      const section = clinicalFact.section || 'other';
      const existing = grouped.get(section);

      if (existing) {
        existing.push(clinicalFact);
      } else {
        grouped.set(section, [clinicalFact]);
      }
    }

    return Array.from(grouped.entries()).map(([section, sectionFacts]) => ({
      section,
      facts: sectionFacts,
    }));
  }, [facts]);

  const toggleSection = (section: string) => {
    setExpandedSections((previous) => {
      const next = new Set(previous);

      if (next.has(section)) {
        next.delete(section);
      } else {
        next.add(section);
      }

      return next;
    });
  };

  const expandAll = () => {
    setExpandedSections(new Set(groups.map((group) => group.section)));
  };

  const collapseAll = () => {
    setExpandedSections(new Set());
  };

  if (facts.length === 0) {
    return (
      <aside className="fact-summary empty" aria-label="Captured clinical facts">
        <div className="empty-state">
          <span className="empty-icon" aria-hidden="true">
            ◌
          </span>
          <h3>No captured facts</h3>
          <p>
            Clinical answers will appear here as soon as they are recorded.
          </p>
        </div>
      </aside>
    );
  }

  return (
    <aside className="fact-summary" aria-label="Captured clinical facts">
      <header className="summary-header">
        <div>
          <h3>Captured Facts</h3>
          <span className="fact-count">
            {facts.length} {facts.length === 1 ? 'fact' : 'facts'}
          </span>
        </div>

        <div className="summary-controls">
          <button
            type="button"
            className="summary-control"
            onClick={expandAll}
            aria-label="Expand all fact sections"
          >
            Expand all
          </button>

          <button
            type="button"
            className="summary-control"
            onClick={collapseAll}
            aria-label="Collapse all fact sections"
          >
            Collapse all
          </button>
        </div>
      </header>

      <div className="facts-list">
        {groups.map(({ section, facts: sectionFacts }) => {
          const expanded = expandedSections.has(section);

          return (
            <section
              key={section}
              className={`facts-group ${expanded ? 'expanded' : ''}`}
            >
              <button
                type="button"
                className="facts-group-header"
                onClick={() => toggleSection(section)}
                aria-expanded={expanded}
                aria-controls={`facts-${section}`}
              >
                <span className="facts-group-title">
                  {SECTION_LABELS[section] ?? formatSectionLabel(section)}
                </span>

                <span className="facts-group-meta">
                  <span className="facts-group-count">
                    {sectionFacts.length}
                  </span>

                  <span
                    className="facts-group-chevron"
                    aria-hidden="true"
                  >
                    {expanded ? '⌃' : '⌄'}
                  </span>
                </span>
              </button>

              {expanded && (
                <div
                  id={`facts-${section}`}
                  className="facts-group-content"
                >
                  <ul className="facts-items">
                    {sectionFacts.map((clinicalFact) => (
                      <FactItem
                        key={clinicalFact.id}
                        fact={clinicalFact}
                      />
                    ))}
                  </ul>
                </div>
              )}
            </section>
          );
        })}
      </div>

      <footer className="summary-footer">
        {showActions && (
          <>
            <button
              type="button"
              className="btn-secondary"
              onClick={onExport}
              disabled={!onExport}
            >
              Export
            </button>

            <button
              type="button"
              className="btn-primary"
              onClick={onGenerateNote}
              disabled={!onGenerateNote}
            >
              Generate Note
            </button>
          </>
        )}
      </footer>
    </aside>
  );
}

interface FactItemProps {
  fact: ClinicalFact;
}

function FactItem({ fact }: FactItemProps) {
  const source = normalizeSource(fact.sourceType);

  return (
    <li className="fact-item">
      <div className="fact-item-main">
        <span className="fact-code">
          {formatFactCode(fact.factCode)}
        </span>

        <span className="fact-value">
          {formatFactValue(fact)}
        </span>
      </div>

      <div className="fact-item-meta">
        <span className="fact-source">
          {SOURCE_LABELS[source] ?? formatLabel(source)}
        </span>

        {fact.value.unitCode && fact.value.numeric != null && (
          <span className="fact-unit">
            {fact.value.unitCode}
          </span>
        )}
      </div>
    </li>
  );
}

function formatFactValue(fact: ClinicalFact): string {
  const value = fact.value;

  if (value.text != null) {
    return value.text.trim() || '—';
  }

  if (value.code != null) {
    return formatLabel(value.code);
  }

  if (value.boolean != null) {
    return value.boolean ? 'Yes' : 'No';
  }

  if (value.numeric != null) {
    return formatNumericValue(value.numeric);
  }

  if (value.date != null) {
    return formatDateValue(value.date);
  }

  if (value.datetime != null) {
    return formatDateTimeValue(value.datetime);
  }

  return '—';
}

function formatFactCode(code: string): string {
  return formatLabel(code);
}

function formatSectionLabel(section: string): string {
  return formatLabel(section);
}

function formatLabel(value: string): string {
  return value
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .trim()
    .toLowerCase()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function normalizeSource(source: string): string {
  return source.trim().toLowerCase().replace(/[\s-]+/g, '_');
}

function formatNumericValue(value: number): string {
  if (!Number.isFinite(value)) return '—';

  return new Intl.NumberFormat(undefined, {
    maximumFractionDigits: 4,
  }).format(value);
}

function formatDateValue(value: string): string {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}

function formatDateTimeValue(value: string): string {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}