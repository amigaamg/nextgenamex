import { useMemo } from 'react';
import type { ClinicalFact } from '../../clinical/types';
import { FactSummary } from '../History/FactSummary';

interface FactsPanelProps {
  facts: ClinicalFact[];
}

function factValue(fact: ClinicalFact | undefined): string | null {
  if (!fact) return null;

  const value = fact.value;

  if (value.text != null && value.text.trim() !== '') {
    return value.text.trim();
  }

  if (value.code != null) {
    return value.code;
  }

  if (value.boolean != null) {
    return value.boolean ? 'Yes' : 'No';
  }

  if (value.numeric != null) {
    return [
      String(value.numeric),
      value.unitCode ?? null,
    ]
      .filter(Boolean)
      .join(' ');
  }

  if (value.date != null) {
    return value.date;
  }

  if (value.datetime != null) {
    return value.datetime;
  }

  return null;
}

function formatSex(value: string | null): string | null {
  if (!value) return null;

  const map: Record<string, string> = {
    MALE: 'Male',
    FEMALE: 'Female',
    INTERSEX: 'Intersex',
    UNKNOWN: 'Unknown',
    male: 'Male',
    female: 'Female',
    intersex: 'Intersex',
  };

  return map[value] ?? value;
}

export function FactsPanel({ facts }: FactsPanelProps) {
  const bio = useMemo(() => {
    const name = factValue(
      facts.find((fact) => fact.factCode === 'PATIENT_NAME'),
    );
    const age = factValue(
      facts.find((fact) => fact.factCode === 'AGE_YEARS'),
    );
    const sex = formatSex(
      factValue(facts.find((fact) => fact.factCode === 'SEX')),
    );
    const mrn = factValue(
      facts.find((fact) => fact.factCode === 'MRN'),
    );

    return { name, age, sex, mrn };
  }, [facts]);

  const hasIdentity = Boolean(
    bio.name || bio.age || bio.sex || bio.mrn,
  );

  return (
    <div className="facts-panel">
      {hasIdentity && (
        <div className="facts-bio">
          <span className="facts-bio-label">Patient</span>

          <span className="facts-bio-identity">
            {[
              bio.name,
              bio.age ? `${bio.age} yr` : null,
              bio.sex,
            ]
              .filter(Boolean)
              .join(' · ')}
          </span>

          {bio.mrn && (
            <span className="facts-bio-mrn">
              MRN {bio.mrn}
            </span>
          )}
        </div>
      )}

      <FactSummary facts={facts} defaultExpanded showActions={false} />
    </div>
  );
}
