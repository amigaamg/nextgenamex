import { useMemo, useState } from 'react';
import type { ClinicalFact } from '../../clinical/types';

interface SocialHistoryProps {
  facts: ClinicalFact[];
  onEvent: (event: any) => void;
}

type SocialFieldType =
  | 'text'
  | 'number'
  | 'boolean'
  | 'select'
  | 'multiselect'
  | 'long_text';

interface SocialField {
  code: string;
  label: string;
  type: SocialFieldType;
  options?: string[];
  showIf?: (
    value: unknown,
    values: Record<string, unknown>,
  ) => boolean;
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  placeholder?: string;
  required?: boolean;
}

interface SocialSectionDefinition {
  label: string;
  icon: string;
  description: string;
  fields: SocialField[];
}

const SOCIAL_SECTIONS: Record<string, SocialSectionDefinition> = {
  demographics: {
    label: 'Demographics & Residence',
    icon: '⌂',
    description:
      'Living circumstances, household composition, water, sanitation, utilities and housing conditions.',
    fields: [
      {
        code: 'RESIDENCE_TYPE',
        label: 'Residence Type',
        type: 'select',
        options: [
          'Urban',
          'Peri-urban',
          'Rural',
          'Informal settlement',
          'Refugee camp',
          'Other',
        ],
      },
      {
        code: 'HOUSEHOLD_SIZE',
        label: 'Household Size',
        type: 'number',
        min: 1,
        max: 100,
        step: 1,
      },
      {
        code: 'ROOM_COUNT',
        label: 'Number of Rooms Used by Household',
        type: 'number',
        min: 1,
        max: 100,
        step: 1,
      },
      {
        code: 'OVERCROWDING',
        label: 'Overcrowding',
        type: 'boolean',
      },
      {
        code: 'HOUSING_CONDITION',
        label: 'Housing Condition',
        type: 'select',
        options: [
          'Good',
          'Adequate',
          'Poor',
          'Unsafe',
          'Unknown',
        ],
      },
      {
        code: 'WATER_SOURCE',
        label: 'Main Water Source',
        type: 'select',
        options: [
          'Piped',
          'Borehole',
          'Protected well',
          'Unprotected well',
          'Surface water',
          'Rainwater',
          'Vendor',
          'Other',
        ],
      },
      {
        code: 'SANITATION',
        label: 'Sanitation',
        type: 'select',
        options: [
          'Flush toilet',
          'VIP latrine',
          'Pit latrine',
          'Shared facility',
          'No facility',
          'Other',
        ],
      },
      {
        code: 'ELECTRICITY',
        label: 'Electricity Access',
        type: 'boolean',
      },
      {
        code: 'HOUSEHOLD_COOKING_FUEL',
        label: 'Main Household Cooking Fuel',
        type: 'select',
        options: [
          'Electricity',
          'LPG',
          'Natural gas',
          'Kerosene',
          'Charcoal',
          'Wood',
          'Crop residue',
          'Animal dung',
          'Coal',
          'Other',
        ],
      },
    ],
  },

  occupation: {
    label: 'Occupation & Workplace',
    icon: '▣',
    description:
      'Current employment, occupational exposures and previous high-risk work.',
    fields: [
      {
        code: 'OCCUPATION',
        label: 'Current Occupation',
        type: 'text',
        placeholder: 'Enter occupation',
      },
      {
        code: 'EMPLOYMENT_STATUS',
        label: 'Employment Status',
        type: 'select',
        options: [
          'Employed',
          'Self-employed',
          'Unemployed',
          'Student',
          'Retired',
          'Homemaker',
          'Unable to work',
          'Other',
        ],
      },
      {
        code: 'WORKPLACE_EXPOSURE',
        label: 'Workplace Exposures',
        type: 'multiselect',
        options: [
          'Dust/silica',
          'Coal dust',
          'Asbestos',
          'Chemicals/fumes',
          'Pesticides',
          'Radiation',
          'Biological agents',
          'Noise',
          'Heat/cold',
          'Heavy lifting',
          'Prolonged standing',
          'Shift work',
          'Vibration',
          'None',
        ],
      },
      {
        code: 'WORK_DURATION_YEARS',
        label: 'Years in Current Work',
        type: 'number',
        min: 0,
        max: 80,
        step: 0.5,
      },
      {
        code: 'PREVIOUS_OCCUPATIONS',
        label: 'Previous Occupations / Relevant Exposures',
        type: 'long_text',
        placeholder:
          'Previous occupations, duration and important exposures',
      },
    ],
  },

  lifestyle: {
    label: 'Lifestyle & Substances',
    icon: '◉',
    description:
      'Tobacco, alcohol, recreational substances, diet and physical activity.',
    fields: [
      {
        code: 'SMOKING_STATUS',
        label: 'Smoking Status',
        type: 'select',
        options: [
          'Never',
          'Former',
          'Current',
          'Passive only',
          'Unknown',
        ],
      },
      {
        code: 'CIGARETTES_PER_DAY',
        label: 'Cigarettes / Day',
        type: 'number',
        min: 0,
        max: 100,
        step: 1,
        showIf: (_, values) =>
          values.SMOKING_STATUS === 'Current' ||
          values.SMOKING_STATUS === 'Former',
      },
      {
        code: 'SMOKING_YEARS',
        label: 'Years Smoked',
        type: 'number',
        min: 0,
        max: 100,
        step: 0.5,
        showIf: (_, values) =>
          values.SMOKING_STATUS === 'Current' ||
          values.SMOKING_STATUS === 'Former',
      },
      {
        code: 'PACK_YEARS',
        label: 'Pack-Years',
        type: 'number',
        min: 0,
        max: 200,
        step: 0.1,
        showIf: (_, values) =>
          values.SMOKING_STATUS === 'Current' ||
          values.SMOKING_STATUS === 'Former',
      },
      {
        code: 'SMOKING_CESSATION_YEARS',
        label: 'Years Since Quitting',
        type: 'number',
        min: 0,
        max: 100,
        step: 0.5,
        showIf: (_, values) =>
          values.SMOKING_STATUS === 'Former',
      },
      {
        code: 'ALCOHOL_USE',
        label: 'Alcohol Use',
        type: 'select',
        options: [
          'Never',
          'Occasional',
          'Regular',
          'Heavy',
          'Former',
          'Unknown',
        ],
      },
      {
        code: 'ALCOHOL_UNITS_WEEK',
        label: 'Alcohol Units / Week',
        type: 'number',
        min: 0,
        max: 300,
        step: 1,
        showIf: (_, values) =>
          values.ALCOHOL_USE !== 'Never' &&
          values.ALCOHOL_USE !== 'Former' &&
          values.ALCOHOL_USE !== 'Unknown' &&
          values.ALCOHOL_USE != null,
      },
      {
        code: 'RECREATIONAL_DRUGS',
        label: 'Recreational / Non-prescribed Drug Use',
        type: 'multiselect',
        options: [
          'Cannabis',
          'Cocaine',
          'Heroin/opioids',
          'Methamphetamine',
          'Inhalants',
          'Khat/miraa',
          'Sedatives',
          'Other',
          'None',
          'Unknown',
        ],
      },
      {
        code: 'DIET_TYPE',
        label: 'Dietary Pattern',
        type: 'select',
        options: [
          'Mixed',
          'Vegetarian',
          'Vegan',
          'High carbohydrate',
          'High fat',
          'Traditional',
          'Other',
        ],
      },
      {
        code: 'PHYSICAL_ACTIVITY',
        label: 'Physical Activity Level',
        type: 'select',
        options: [
          'Sedentary',
          'Light',
          'Moderate',
          'Vigorous',
          'Unknown',
        ],
      },
    ],
  },

  exposures: {
    label: 'Environmental & Infectious Exposures',
    icon: '⌁',
    description:
      'Environmental, household, animal, travel and infectious-disease exposures.',
    fields: [
      {
        code: 'BIOMASS_EXPOSURE',
        label: 'Biomass Fuel Exposure',
        type: 'boolean',
      },
      {
        code: 'BIOMASS_TYPE',
        label: 'Biomass Type',
        type: 'select',
        options: [
          'Wood',
          'Charcoal',
          'Crop residue',
          'Animal dung',
          'Coal',
          'Other',
        ],
        showIf: (value) => value === true,
      },
      {
        code: 'BIOMASS_EXPOSURE_YEARS',
        label: 'Years of Biomass Exposure',
        type: 'number',
        min: 0,
        max: 100,
        step: 0.5,
        showIf: (_, values) => values.BIOMASS_EXPOSURE === true,
      },
      {
        code: 'INDOOR_POLLUTION',
        label: 'Indoor Cooking Without Adequate Ventilation',
        type: 'boolean',
      },
      {
        code: 'TB_CONTACT',
        label: 'Known TB Contact',
        type: 'boolean',
      },
      {
        code: 'TB_CONTACT_RELATION',
        label: 'TB Contact Relationship',
        type: 'select',
        options: [
          'Household',
          'Workplace',
          'Community',
          'Healthcare',
          'Other',
        ],
        showIf: (value) => value === true,
      },
      {
        code: 'TB_CONTACT_DURATION',
        label: 'Duration of TB Contact',
        type: 'text',
        placeholder: 'e.g. 3 months',
        showIf: (_, values) => values.TB_CONTACT === true,
      },
      {
        code: 'PET_ANIMAL_EXPOSURE',
        label: 'Animal Exposure',
        type: 'multiselect',
        options: [
          'Dog',
          'Cat',
          'Bird',
          'Livestock',
          'Poultry',
          'Rodents',
          'Wildlife',
          'None',
          'Unknown',
        ],
      },
      {
        code: 'RECENT_TRAVEL',
        label: 'Recent Travel',
        type: 'boolean',
      },
      {
        code: 'TRAVEL_HISTORY',
        label: 'Travel History',
        type: 'long_text',
        placeholder:
          'Destinations, dates/duration and relevant exposures',
        showIf: (_, values) => values.RECENT_TRAVEL === true,
      },
      {
        code: 'COMMUNITY_OUTBREAK_EXPOSURE',
        label: 'Known Community Outbreak Exposure',
        type: 'boolean',
      },
    ],
  },

  social: {
    label: 'Social Support & Barriers',
    icon: '◎',
    description:
      'Family structure, support, socioeconomic barriers, health literacy and safeguarding.',
    fields: [
      {
        code: 'MARITAL_STATUS',
        label: 'Marital Status',
        type: 'select',
        options: [
          'Single',
          'Married',
          'Cohabiting',
          'Divorced',
          'Widowed',
          'Separated',
          'Unknown',
        ],
      },
      {
        code: 'EDUCATION_LEVEL',
        label: 'Education Level',
        type: 'select',
        options: [
          'None',
          'Primary',
          'Secondary',
          'Tertiary',
          'Postgraduate',
          'Unknown',
        ],
      },
      {
        code: 'INCOME_LEVEL',
        label: 'Income / Economic Circumstances',
        type: 'select',
        options: [
          'Below poverty line',
          'Low',
          'Middle',
          'High',
          'Prefer not to say',
          'Unknown',
        ],
      },
      {
        code: 'SOCIAL_SUPPORT',
        label: 'Social Support Network',
        type: 'select',
        options: [
          'Strong',
          'Moderate',
          'Limited',
          'None',
          'Unknown',
        ],
      },
      {
        code: 'CAREGIVER_AVAILABLE',
        label: 'Caregiver Available',
        type: 'boolean',
      },
      {
        code: 'FINANCIAL_BARRIERS',
        label: 'Financial Barriers to Care',
        type: 'boolean',
      },
      {
        code: 'TRANSPORT_BARRIERS',
        label: 'Transport Barriers',
        type: 'boolean',
      },
      {
        code: 'ACCESS_BARRIERS',
        label: 'Healthcare Access Barriers',
        type: 'multiselect',
        options: [
          'Distance',
          'Cost',
          'Transport',
          'Availability',
          'Opening hours',
          'Documentation',
          'Language',
          'Stigma',
          'Other',
          'None',
        ],
      },
      {
        code: 'HEALTH_LITERACY',
        label: 'Health Literacy',
        type: 'select',
        options: [
          'High',
          'Adequate',
          'Limited',
          'Low',
          'Unknown',
        ],
      },
      {
        code: 'ADHERENCE_BARRIERS',
        label: 'Anticipated Adherence Barriers',
        type: 'multiselect',
        options: [
          'Cost',
          'Side effects',
          'Complexity',
          'Forgetfulness',
          'Beliefs',
          'Stigma',
          'Access',
          'Language',
          'Other',
          'None',
        ],
      },
      {
        code: 'SAFEGUARDING_CONCERN',
        label: 'Safeguarding Concern Identified',
        type: 'boolean',
      },
      {
        code: 'SAFEGUARDING_DETAILS',
        label: 'Safeguarding Details',
        type: 'long_text',
        placeholder: 'Document relevant concern and source of information',
        showIf: (_value, values) =>
          values.SAFEGUARDING_CONCERN === true,
      },
    ],
  },
};

export function SocialHistory({
  facts,
  onEvent,
}: SocialHistoryProps) {
  const [formData, setFormData] = useState<Record<string, unknown>>({});
  const [expandedSection, setExpandedSection] = useState<string>(
    Object.keys(SOCIAL_SECTIONS)[0],
  );

  const factValues = useMemo(() => {
    const values: Record<string, unknown> = {};

    for (const clinicalFact of facts) {
      const value = clinicalFact.value;

      if (value.text != null) {
        values[clinicalFact.factCode] = value.text;
      } else if (value.code != null) {
        values[clinicalFact.factCode] = value.code;
      } else if (value.boolean != null) {
        values[clinicalFact.factCode] = value.boolean;
      } else if (value.numeric != null) {
        values[clinicalFact.factCode] = value.numeric;
      } else if (Array.isArray(value.code)) {
        values[clinicalFact.factCode] = value.code;
      } else if (value.date != null) {
        values[clinicalFact.factCode] = value.date;
      } else if (value.datetime != null) {
        values[clinicalFact.factCode] = value.datetime;
      }
    }

    return values;
  }, [facts]);

  const values = useMemo(
    () => ({
      ...factValues,
      ...formData,
    }),
    [factValues, formData],
  );

  const handleChange = (
    field: SocialField,
    nextValue: unknown,
  ) => {
    setFormData((previous) => ({
      ...previous,
      [field.code]: nextValue,
    }));

    const answerCodes = Array.isArray(nextValue)
      ? nextValue.map(String)
      : nextValue == null
        ? []
        : typeof nextValue === 'boolean'
          ? [nextValue ? 'YES' : 'NO']
          : [String(nextValue)];

    onEvent({
      type: 'QUESTION_ANSWERED',
      payload: {
        questionCode: field.code,
        answerCodes,
        rawValue: nextValue,
        factCode: field.code,
        section: 'social_history',
      },
    });

    clearDependentValues(field.code, nextValue);
  };

  const clearDependentValues = (
    changedCode: string,
    nextValue: unknown,
  ) => {
    const dependentCodes: string[] = [];

    for (const section of Object.values(SOCIAL_SECTIONS)) {
      for (const field of section.fields) {
        if (!field.showIf) continue;

        const visible = field.showIf(
          nextValue,
          {
            ...values,
            [changedCode]: nextValue,
          },
        );

        if (!visible && values[field.code] != null) {
          dependentCodes.push(field.code);
        }
      }
    }

    if (dependentCodes.length === 0) return;

    setFormData((previous) => {
      const next = { ...previous };

      for (const code of dependentCodes) {
        delete next[code];
      }

      return next;
    });
  };

  const getFieldValue = (code: string): unknown => {
    return values[code] ?? null;
  };

  const isFieldDocumented = (code: string): boolean => {
    return facts.some((fact) => fact.factCode === code);
  };

  return (
    <section className="social-history" aria-label="Social history">
      <header className="section-header">
        <div>
          <h2>Social History</h2>
          <p className="section-description">
            Lifestyle, environment, occupation and social determinants of health
          </p>
        </div>

        <div className="section-progress">
          {facts.length} documented
        </div>
      </header>

      <nav className="social-nav" aria-label="Social history subsections">
        {Object.entries(SOCIAL_SECTIONS).map(([key, section]) => {
          const active = expandedSection === key;

          const documentedCount = section.fields.filter((field) =>
            isFieldDocumented(field.code),
          ).length;

          return (
            <button
              key={key}
              type="button"
              className={`social-tab ${active ? 'active' : ''}`}
              onClick={() => setExpandedSection(key)}
              aria-current={active ? 'page' : undefined}
            >
              <span className="tab-icon" aria-hidden="true">
                {section.icon}
              </span>

              <span className="tab-content">
                <span className="tab-label">{section.label}</span>
                <span className="tab-count">
                  {documentedCount}/{section.fields.length}
                </span>
              </span>
            </button>
          );
        })}
      </nav>

      <div className="social-content">
        {Object.entries(SOCIAL_SECTIONS).map(([key, section]) => {
          if (expandedSection !== key) return null;

          return (
            <div key={key} className="social-section">
              <header className="social-section-header">
                <div>
                  <h3>
                    <span aria-hidden="true">{section.icon}</span>{' '}
                    {section.label}
                  </h3>
                  <p>{section.description}</p>
                </div>
              </header>

              <div className="fields-grid">
                {section.fields.map((field) => {
                  const currentValue = getFieldValue(field.code);

                  const visible =
                    !field.showIf ||
                    field.showIf(currentValue, values);

                  if (!visible) return null;

                  return (
                    <SocialFieldRenderer
                      key={field.code}
                      field={field}
                      value={currentValue}
                      onChange={(nextValue) =>
                        handleChange(field, nextValue)
                      }
                    />
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

interface SocialFieldRendererProps {
  field: SocialField;
  value: unknown;
  onChange: (value: unknown) => void;
}

function SocialFieldRenderer({
  field,
  value,
  onChange,
}: SocialFieldRendererProps) {
  const [draftText, setDraftText] = useState(
    typeof value === 'string' ? value : '',
  );

  if (field.type === 'text') {
    return (
      <div className="field-wrapper">
        <label className="field-label" htmlFor={field.code}>
          {field.label}
          {field.required && <span aria-hidden="true"> *</span>}
        </label>

        <input
          id={field.code}
          type="text"
          value={draftText}
          placeholder={field.placeholder}
          onChange={(event) => {
            const next = event.target.value;
            setDraftText(next);
            onChange(next);
          }}
        />
      </div>
    );
  }

  if (field.type === 'long_text') {
    return (
      <div className="field-wrapper field-wrapper-wide">
        <label className="field-label" htmlFor={field.code}>
          {field.label}
        </label>

        <textarea
          id={field.code}
          value={draftText}
          placeholder={field.placeholder}
          rows={4}
          onChange={(event) => {
            const next = event.target.value;
            setDraftText(next);
            onChange(next);
          }}
        />
      </div>
    );
  }

  if (field.type === 'number') {
    return (
      <div className="field-wrapper">
        <label className="field-label" htmlFor={field.code}>
          {field.label}
        </label>

        <div className="input-with-unit">
          <input
            id={field.code}
            type="number"
            min={field.min}
            max={field.max}
            step={field.step ?? 'any'}
            value={
              typeof value === 'number' && Number.isFinite(value)
                ? value
                : ''
            }
            placeholder={field.placeholder}
            onChange={(event) => {
              const raw = event.target.value;

              if (raw === '') {
                onChange(null);
                return;
              }

              const numeric = Number(raw);

              if (!Number.isFinite(numeric)) return;

              onChange(numeric);
            }}
          />

          {field.unit && (
            <span className="input-unit">{field.unit}</span>
          )}
        </div>
      </div>
    );
  }

  if (field.type === 'boolean') {
    return (
      <div className="field-wrapper">
        <span className="field-label">{field.label}</span>

        <div className="boolean-toggle" role="radiogroup">
          <label
            className={`boolean-option ${
              value === true ? 'selected' : ''
            }`}
          >
            <input
              type="radio"
              name={field.code}
              checked={value === true}
              onChange={() => onChange(true)}
            />
            <span>Yes</span>
          </label>

          <label
            className={`boolean-option ${
              value === false ? 'selected' : ''
            }`}
          >
            <input
              type="radio"
              name={field.code}
              checked={value === false}
              onChange={() => onChange(false)}
            />
            <span>No</span>
          </label>

          <label
            className={`boolean-option ${
              value == null ? 'selected' : ''
            }`}
          >
            <input
              type="radio"
              name={field.code}
              checked={value == null}
              onChange={() => onChange(null)}
            />
            <span>Unknown</span>
          </label>
        </div>
      </div>
    );
  }

  if (field.type === 'select') {
    return (
      <div className="field-wrapper">
        <label className="field-label" htmlFor={field.code}>
          {field.label}
        </label>

        <select
          id={field.code}
          value={typeof value === 'string' ? value : ''}
          onChange={(event) =>
            onChange(event.target.value || null)
          }
        >
          <option value="">Select...</option>

          {field.options?.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      </div>
    );
  }

  if (field.type === 'multiselect') {
    const selected = Array.isArray(value)
      ? value.map(String)
      : [];

    return (
      <fieldset className="field-wrapper field-wrapper-wide">
        <legend className="field-label">{field.label}</legend>

        <div className="multiselect">
          {field.options?.map((option) => {
            const checked = selected.includes(option);

            return (
              <label
                key={option}
                className={`multiselect-option ${
                  checked ? 'selected' : ''
                }`}
              >
                <input
                  type="checkbox"
                  checked={checked}
                   onChange={(_event) => {
                    const next = checked
                      ? selected.filter(
                          (item) => item !== option,
                        )
                      : [...selected, option];

                    const normalized =
                      normalizeExclusiveOptions(next);

                    onChange(normalized);
                  }}
                />

                <span>{option}</span>
              </label>
            );
          })}
        </div>
      </fieldset>
    );
  }

  return null;
}

function normalizeExclusiveOptions(
  values: string[],
): string[] {
  const exclusive = new Set([
    'None',
    'Unknown',
  ]);

  const selectedExclusive = values.filter((value) =>
    exclusive.has(value),
  );

  if (selectedExclusive.length > 0) {
    return [selectedExclusive[selectedExclusive.length - 1]];
  }

  return values.filter(
    (value) => !exclusive.has(value),
  );
}