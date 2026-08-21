// =============================================================================
// src/components/clinical/FamilyHistory.tsx
// AMEXAN — UNIVERSAL FAMILY HISTORY CAPTURE
// =============================================================================

'use client';

import { useMemo, useState } from 'react';
import type { ClinicalFact } from '../../clinical/types';

interface FamilyHistoryProps {
  facts: ClinicalFact[];
  onEvent: (event: any) => void;
}

type FamilyMemberCode =
  | 'FATHER'
  | 'MOTHER'
  | 'SIBLING'
  | 'CHILD'
  | 'PATERNAL_GRANDFATHER'
  | 'PATERNAL_GRANDMOTHER'
  | 'MATERNAL_GRANDFATHER'
  | 'MATERNAL_GRANDMOTHER';

interface FamilyMemberDefinition {
  code: FamilyMemberCode;
  label: string;
}

const FAMILY_MEMBERS: FamilyMemberDefinition[] = [
  { code: 'FATHER', label: 'Father' },
  { code: 'MOTHER', label: 'Mother' },
  { code: 'SIBLING', label: 'Sibling(s)' },
  { code: 'CHILD', label: 'Child(ren)' },
  {
    code: 'PATERNAL_GRANDFATHER',
    label: 'Paternal Grandfather',
  },
  {
    code: 'PATERNAL_GRANDMOTHER',
    label: 'Paternal Grandmother',
  },
  {
    code: 'MATERNAL_GRANDFATHER',
    label: 'Maternal Grandfather',
  },
  {
    code: 'MATERNAL_GRANDMOTHER',
    label: 'Maternal Grandmother',
  },
];

const FAMILY_CONDITIONS = [
  'HYPERTENSION',
  'DIABETES_TYPE_2',
  'DIABETES_TYPE_1',
  'CORONARY_ARTERY_DISEASE',
  'STROKE',
  'HEART_FAILURE',
  'ASTHMA',
  'COPD',
  'TUBERCULOSIS',
  'CANCER_BREAST',
  'CANCER_COLORECTAL',
  'CANCER_PROSTATE',
  'CANCER_LUNG',
  'CANCER_OTHER',
  'CHRONIC_KIDNEY_DISEASE',
  'LIVER_DISEASE',
  'EPILEPSY',
  'MENTAL_ILLNESS',
  'SUBSTANCE_USE',
  'SUICIDE',
  'SUDDEN_CARDIAC_DEATH',
  'BLEEDING_DISORDER',
  'THROMBOPHILIA',
  'AUTOIMMUNE_DISEASE',
  'GENETIC_DISORDER',
  'OTHER_SIGNIFICANT',
] as const;

type FamilyCondition = (typeof FAMILY_CONDITIONS)[number];

type MemberDraft = {
  status: 'alive' | 'deceased' | 'unknown' | null;
  age: string;
  ageAtDeath: string;
  conditions: FamilyCondition[];
  notes: string;
};

type SummaryState = {
  consanguinity: boolean;
  clustering: boolean;
  householdIllness: boolean;
  householdTBContact: boolean;
};

const EMPTY_DRAFT: MemberDraft = {
  status: null,
  age: '',
  ageAtDeath: '',
  conditions: [],
  notes: '',
};

const INITIAL_SUMMARY: SummaryState = {
  consanguinity: false,
  clustering: false,
  householdIllness: false,
  householdTBContact: false,
};

function formatLabel(value: string): string {
  return value
    .replace(/_/g, ' ')
    .toLowerCase()
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function getFact(
  facts: ClinicalFact[],
  factCode: string,
): ClinicalFact | undefined {
  return facts.find((fact) => fact.factCode === factCode);
}

function getNumericFact(
  facts: ClinicalFact[],
  factCode: string,
): number | null {
  const fact = getFact(facts, factCode);
  return fact?.value.numeric ?? null;
}

//

function getTextFact(
  facts: ClinicalFact[],
  factCode: string,
): string | null {
  const fact = getFact(facts, factCode);
  return fact?.value.text ?? null;
}

function emitAnswer(
  onEvent: (event: any) => void,
  questionCode: string,
  factCode: string,
  rawValue: unknown,
  answerCodes: string[] = [],
) {
  onEvent({
    type: 'QUESTION_ANSWERED',
    payload: {
      questionCode,
      answerCodes,
      rawValue,
      factCode,
    },
  });
}

function memberFactPrefix(memberCode: FamilyMemberCode): string {
  return `FAMILY_${memberCode}_`;
}

function getMemberFacts(
  facts: ClinicalFact[],
  memberCode: FamilyMemberCode,
): ClinicalFact[] {
  const prefix = memberFactPrefix(memberCode);

  return facts.filter((fact) =>
    fact.factCode.startsWith(prefix),
  );
}

function memberHasHistory(
  facts: ClinicalFact[],
  memberCode: FamilyMemberCode,
): boolean {
  return getMemberFacts(facts, memberCode).length > 0;
}

function getMemberConditions(
  facts: ClinicalFact[],
  memberCode: FamilyMemberCode,
): FamilyCondition[] {
  const prefix = memberFactPrefix(memberCode);

  return facts
    .filter((fact) => fact.factCode.startsWith(prefix))
    .map((fact) => fact.value.code)
    .filter(
      (code): code is FamilyCondition =>
        !!code &&
        FAMILY_CONDITIONS.includes(code as FamilyCondition),
    );
}

function createDraftFromFacts(
  facts: ClinicalFact[],
  memberCode: FamilyMemberCode,
): MemberDraft {
  const aliveFact = getFact(
    facts,
    `FAMILY_${memberCode}_ALIVE`,
  );

  const age = getNumericFact(
    facts,
    `FAMILY_${memberCode}_AGE`,
  );

  const ageAtDeath = getNumericFact(
    facts,
    `FAMILY_${memberCode}_AGE_DEATH`,
  );

  const notes = getTextFact(
    facts,
    `FAMILY_${memberCode}_NOTES`,
  );

  const aliveValue = aliveFact?.value.boolean;

  const status =
    aliveValue === true
      ? 'alive'
      : aliveValue === false
        ? 'deceased'
        : aliveFact
          ? 'unknown'
          : null;

  return {
    status,
    age: age != null ? String(age) : '',
    ageAtDeath: ageAtDeath != null ? String(ageAtDeath) : '',
    conditions: getMemberConditions(facts, memberCode),
    notes: notes ?? '',
  };
}

function hasMeaningfulDraft(draft: MemberDraft): boolean {
  return (
    draft.status !== null ||
    draft.age.trim() !== '' ||
    draft.ageAtDeath.trim() !== '' ||
    draft.conditions.length > 0 ||
    draft.notes.trim() !== ''
  );
}

export function FamilyHistory({
  facts,
  onEvent,
}: FamilyHistoryProps) {
  const [expandedMember, setExpandedMember] =
    useState<FamilyMemberCode | null>(null);

  const [drafts, setDrafts] = useState<
    Record<string, MemberDraft>
  >({});

  const [summary, setSummary] =
    useState<SummaryState>(INITIAL_SUMMARY);

  const documentedCount = useMemo(
    () =>
      FAMILY_MEMBERS.filter((member) =>
        memberHasHistory(facts, member.code),
      ).length,
    [facts],
  );

  const updateDraft = (
    memberCode: FamilyMemberCode,
    patch: Partial<MemberDraft>,
  ) => {
    setDrafts((previous) => ({
      ...previous,
      [memberCode]: {
        ...(previous[memberCode] ?? EMPTY_DRAFT),
        ...patch,
      },
    }));
  };

  const getDraft = (
    memberCode: FamilyMemberCode,
  ): MemberDraft => {
    return (
      drafts[memberCode] ??
      createDraftFromFacts(facts, memberCode)
    );
  };

  const openMember = (memberCode: FamilyMemberCode) => {
    setDrafts((previous) => {
      if (previous[memberCode]) return previous;

      return {
        ...previous,
        [memberCode]: createDraftFromFacts(
          facts,
          memberCode,
        ),
      };
    });

    setExpandedMember((current) =>
      current === memberCode ? null : memberCode,
    );
  };

  const toggleCondition = (
    memberCode: FamilyMemberCode,
    condition: FamilyCondition,
  ) => {
    const draft = getDraft(memberCode);

    const conditions = draft.conditions.includes(condition)
      ? draft.conditions.filter(
          (item) => item !== condition,
        )
      : [...draft.conditions, condition];

    updateDraft(memberCode, { conditions });
  };

  const saveMember = (
    memberCode: FamilyMemberCode,
  ) => {
    const draft = getDraft(memberCode);

    if (!hasMeaningfulDraft(draft)) {
      return;
    }

    const prefix = memberFactPrefix(memberCode);

    if (draft.status !== null) {
      emitAnswer(
        onEvent,
        `${prefix}ALIVE`,
        `${prefix}ALIVE`,
        draft.status === 'alive'
          ? true
          : draft.status === 'deceased'
            ? false
            : null,
        [draft.status.toUpperCase()],
      );
    }

    if (draft.age.trim() !== '') {
      emitAnswer(
        onEvent,
        `${prefix}AGE`,
        `${prefix}AGE`,
        Number(draft.age),
      );
    }

    if (
      draft.status === 'deceased' &&
      draft.ageAtDeath.trim() !== ''
    ) {
      emitAnswer(
        onEvent,
        `${prefix}AGE_DEATH`,
        `${prefix}AGE_DEATH`,
        Number(draft.ageAtDeath),
      );
    }

    for (const condition of draft.conditions) {
      emitAnswer(
        onEvent,
        `${prefix}CONDITION_${condition}`,
        `${prefix}CONDITION_${condition}`,
        condition,
        [condition],
      );
    }

    if (draft.notes.trim() !== '') {
      emitAnswer(
        onEvent,
        `${prefix}NOTES`,
        `${prefix}NOTES`,
        draft.notes.trim(),
      );
    }

    emitAnswer(
      onEvent,
      `${prefix}HISTORY`,
      `${prefix}HISTORY`,
      {
        memberCode,
        memberLabel:
          FAMILY_MEMBERS.find(
            (member) => member.code === memberCode,
          )?.label ?? memberCode,
        status: draft.status,
        age:
          draft.age.trim() !== ''
            ? Number(draft.age)
            : null,
        ageAtDeath:
          draft.ageAtDeath.trim() !== ''
            ? Number(draft.ageAtDeath)
            : null,
        conditions: draft.conditions,
        notes: draft.notes.trim() || null,
      },
      ['DOCUMENTED'],
    );

    setExpandedMember(null);
  };

  const cancelMember = (
    memberCode: FamilyMemberCode,
  ) => {
    setDrafts((previous) => {
      const next = { ...previous };
      delete next[memberCode];
      return next;
    });

    setExpandedMember(null);
  };

  const saveSummaryFact = (
    factCode: string,
    value: boolean,
  ) => {
    emitAnswer(
      onEvent,
      factCode,
      factCode,
      value,
      [value ? 'YES' : 'NO'],
    );
  };

  const updateSummary = (
    key: keyof SummaryState,
    factCode: string,
  ) => {
    const nextValue = !summary[key];

    setSummary((previous) => ({
      ...previous,
      [key]: nextValue,
    }));

    saveSummaryFact(factCode, nextValue);
  };

  return (
    <section className="family-history">
      <header className="section-header">
        <div>
          <h2>Family History</h2>
          <p className="section-description">
            Hereditary, familial, genetic, clustering,
            consanguinity and household disease history.
          </p>
        </div>

        <div className="section-meta">
          <span className="fact-count">
            {documentedCount}/{FAMILY_MEMBERS.length} documented
          </span>
        </div>
      </header>

      <div className="family-members">
        {FAMILY_MEMBERS.map((member) => {
          const hasData = memberHasHistory(
            facts,
            member.code,
          );

          const memberFacts = getMemberFacts(
            facts,
            member.code,
          );

          const conditions = getMemberConditions(
            facts,
            member.code,
          );

          const isExpanded =
            expandedMember === member.code;

          const draft = getDraft(member.code);

          return (
            <article
              key={member.code}
              className={[
                'family-member',
                hasData ? 'has-data' : '',
                isExpanded ? 'expanded' : '',
              ]
                .filter(Boolean)
                .join(' ')}
            >
              <button
                type="button"
                className="member-header"
                onClick={() =>
                  openMember(member.code)
                }
                aria-expanded={isExpanded}
              >
                <span className="member-label">
                  {member.label}
                </span>

                <span className="member-status">
                  {hasData ? (
                    <>
                      <span className="status-badge complete">
                        Documented
                      </span>

                      {conditions.length > 0 && (
                        <span className="condition-count">
                          {conditions.length}{' '}
                          {conditions.length === 1
                            ? 'condition'
                            : 'conditions'}
                        </span>
                      )}

                      {memberFacts.length > 0 && (
                        <span className="fact-count">
                          {memberFacts.length} facts
                        </span>
                      )}
                    </>
                  ) : (
                    <span className="status-badge pending">
                      Not documented
                    </span>
                  )}
                </span>

                <span
                  className="expand-icon"
                  aria-hidden="true"
                >
                  {isExpanded ? '−' : '+'}
                </span>
              </button>

              {isExpanded && (
                <div className="member-detail">
                  <div className="detail-row">
                    <fieldset>
                      <legend>Status</legend>

                      <div className="radio-group">
                        <label>
                          <input
                            type="radio"
                            name={`family-status-${member.code}`}
                            checked={
                              draft.status === 'alive'
                            }
                            onChange={() =>
                              updateDraft(
                                member.code,
                                {
                                  status: 'alive',
                                },
                              )
                            }
                          />
                          Alive
                        </label>

                        <label>
                          <input
                            type="radio"
                            name={`family-status-${member.code}`}
                            checked={
                              draft.status === 'deceased'
                            }
                            onChange={() =>
                              updateDraft(
                                member.code,
                                {
                                  status: 'deceased',
                                },
                              )
                            }
                          />
                          Deceased
                        </label>

                        <label>
                          <input
                            type="radio"
                            name={`family-status-${member.code}`}
                            checked={
                              draft.status === 'unknown'
                            }
                            onChange={() =>
                              updateDraft(
                                member.code,
                                {
                                  status: 'unknown',
                                },
                              )
                            }
                          />
                          Unknown
                        </label>
                      </div>
                    </fieldset>

                    <label>
                      <span>Current age</span>

                      <input
                        type="number"
                        min={0}
                        max={120}
                        value={draft.age}
                        placeholder="Age"
                        onChange={(event) =>
                          updateDraft(
                            member.code,
                            {
                              age: event.target.value,
                            },
                          )
                        }
                      />
                    </label>

                    {draft.status === 'deceased' && (
                      <label>
                        <span>Age at death</span>

                        <input
                          type="number"
                          min={0}
                          max={120}
                          value={draft.ageAtDeath}
                          placeholder="Age at death"
                          onChange={(event) =>
                            updateDraft(
                              member.code,
                              {
                                ageAtDeath:
                                  event.target.value,
                              },
                            )
                          }
                        />
                      </label>
                    )}
                  </div>

                  <fieldset className="conditions-grid">
                    <legend>Known or relevant conditions</legend>

                    <div className="conditions-list">
                      {FAMILY_CONDITIONS.map(
                        (condition) => {
                          const selected =
                            draft.conditions.includes(
                              condition,
                            );

                          return (
                            <label
                              key={condition}
                              className={[
                                'condition-item',
                                selected
                                  ? 'selected'
                                  : '',
                              ]
                                .filter(Boolean)
                                .join(' ')}
                            >
                              <input
                                type="checkbox"
                                checked={selected}
                                onChange={() =>
                                  toggleCondition(
                                    member.code,
                                    condition,
                                  )
                                }
                              />

                              <span>
                                {formatLabel(condition)}
                              </span>
                            </label>
                          );
                        },
                      )}
                    </div>
                  </fieldset>

                  <label className="family-notes">
                    <span>
                      Additional relevant family details
                    </span>

                    <textarea
                      value={draft.notes}
                      rows={4}
                      placeholder="Relationship, age at diagnosis, cause of death, hereditary pattern, relevant details..."
                      onChange={(event) =>
                        updateDraft(
                          member.code,
                          {
                            notes:
                              event.target.value,
                          },
                        )
                      }
                    />
                  </label>

                  <div className="member-actions">
                    <button
                      type="button"
                      className="btn-primary"
                      onClick={() =>
                        saveMember(member.code)
                      }
                      disabled={
                        !hasMeaningfulDraft(draft)
                      }
                    >
                      Save {member.label}
                    </button>

                    <button
                      type="button"
                      className="btn-secondary"
                      onClick={() =>
                        cancelMember(member.code)
                      }
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}
            </article>
          );
        })}
      </div>

      <section className="family-summary">
        <header>
          <h3>Family Pattern & Household Context</h3>
          <p>
            Capture clinically important familial patterns
            that are not limited to a single relative.
          </p>
        </header>

        <div className="summary-items">
          <label>
            <input
              type="checkbox"
              checked={summary.consanguinity}
              onChange={() =>
                updateSummary(
                  'consanguinity',
                  'FAMILY_CONSANGUINITY',
                )
              }
            />
            <span>
              Parents are consanguineous
            </span>
          </label>

          <label>
            <input
              type="checkbox"
              checked={summary.clustering}
              onChange={() =>
                updateSummary(
                  'clustering',
                  'FAMILY_DISEASE_CLUSTERING',
                )
              }
            />
            <span>
              Multiple affected family members
              (familial clustering)
            </span>
          </label>

          <label>
            <input
              type="checkbox"
              checked={summary.householdIllness}
              onChange={() =>
                updateSummary(
                  'householdIllness',
                  'FAMILY_HOUSEHOLD_SIMILAR_ILLNESS',
                )
              }
            />
            <span>
              Similar illness in the household
            </span>
          </label>

          <label>
            <input
              type="checkbox"
              checked={summary.householdTBContact}
              onChange={() =>
                updateSummary(
                  'householdTBContact',
                  'FAMILY_HOUSEHOLD_TB_CONTACT',
                )
              }
            />
            <span>
              Tuberculosis contact in household
            </span>
          </label>
        </div>
      </section>
    </section>
  );
}