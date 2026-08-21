// =============================================================================
// src/clinical/documentation.ts
// UNIVERSAL CLINICAL DOCUMENTATION COMPILER
//
// Rules:
// 1. Documentation is generated ONLY from captured facts/context.
// 2. Never invent symptoms, diagnoses, examination findings, investigations,
//    treatment, or clinical reasoning.
// 3. Never write "normal"/"negative" unless an explicit fact supports it.
// 4. Empty sections are omitted.
// 5. Context controls which conditional sections can appear.
// 6. Every generated sentence retains its originating factCode.
// 7. Burdens are unloaded: a single captured negative documents whole groups
//    of questions at once (e.g. "no relevant past medical history").
// 8. Developmental deductions are made only from explicitly captured
//    milestone answers, never from missing data.
// =============================================================================

import type {
  ClinicalContext,
  ClinicalFact,
  HistorySection,
} from './types';

import {
  type ComplaintSystem,
  type DurationUnit,
  COMPLAINT_SYSTEM_LABELS,
  complaintLabelFactCode,
  complaintDurationFactCode,
  formatDuration,
  getChiefComplaintsOldestFirst,
  hasChiefComplaints,
  coveredComplaintSystems,
  parsePresentingComplaints,
  sentenceCase,
} from './complaints';

import {
  ageInMonths,
  evaluateMilestones,
  hasMilestoneEvidence,
  MILESTONE_DOMAIN_LABELS,
} from './milestones';

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

function findFact(
  facts: ClinicalFact[],
  code: string,
): ClinicalFact | undefined {
  return facts.find((item) => item.factCode === code);
}

function formatFactValue(
  clinicalFact: ClinicalFact | undefined,
): string | null {
  if (!clinicalFact) return null;

  const value = clinicalFact.value;

  if (value.text != null) {
    return value.text.trim() || null;
  }

  if (value.code != null) {
    return value.code;
  }

  if (value.numeric != null) {
    return [
      String(value.numeric),
      value.unitCode ?? null,
    ]
      .filter(Boolean)
      .join(' ');
  }

  if (value.boolean != null) {
    return value.boolean ? 'yes' : 'no';
  }

  if (value.date != null) {
    return value.date;
  }

  if (value.datetime != null) {
    return value.datetime;
  }

  return null;
}

function value(
  facts: ClinicalFact[],
  code: string,
): string | null {
  return formatFactValue(findFact(facts, code));
}

function lastValue(
  facts: ClinicalFact[],
  code: string,
): string | null {
  let last: string | null = null;
  for (const fact of facts) {
    if (fact.factCode === code) {
      const next = formatFactValue(fact);
      if (next) last = next;
    }
  }
  return last;
}

function hasFact(
  facts: ClinicalFact[],
  code: string,
): boolean {
  return findFact(facts, code) !== undefined;
}

/** True when the fact's text/code equals a "yes" marker. */
function isYes(facts: ClinicalFact[], code: string): boolean {
  const v = value(facts, code);
  return v === 'YES' || v === 'yes' || v === 'true';
}

/** True when the fact's text/code equals a "no" marker. */
function isNo(facts: ClinicalFact[], code: string): boolean {
  const v = value(facts, code);
  return v === 'NO' || v === 'no' || v === 'false';
}

function sentence(
  text: string,
  factCode: string | null = null,
): DocumentationSentence {
  return {
    text: text.trim(),
    factCode,
  };
}

function section(
  sectionCode: HistorySection,
  title: string,
  sentences: DocumentationSentence[],
): DocumentationSection | null {
  const validSentences = sentences.filter(
    (item) => item.text.trim().length > 0,
  );

  if (validSentences.length === 0) {
    return null;
  }

  return {
    section: sectionCode,
    title,
    sentences: validSentences,
  };
}

function normalizeCode(value: string | null): string {
  return value
    ? value
        .replace(/_/g, ' ')
        .toLowerCase()
    : '';
}

function formatSex(value_: string | null): string | null {
  if (!value_) return null;

  const map: Record<string, string> = {
    MALE: 'male',
    FEMALE: 'female',
    INTERSEX: 'intersex',
    UNKNOWN: 'sex unknown',
    male: 'male',
    female: 'female',
    intersex: 'intersex',
    unknown: 'sex unknown',
  };

  return map[value_] ?? normalizeCode(value_);
}

/** Format a multi-select value ("TB, HTN") into a sentence fragment. */
function formatList(value: string | null): string | null {
  if (!value) return null;
  return value.replace(/,/g, ', ').replace(/\s+/g, ' ').trim();
}

/** True for paediatric life stages (neonate through adolescent). */
function isPaediatricLifeStage(
  context: ClinicalContext,
): boolean {
  return [
    'neonate',
    'infant',
    'child',
    'adolescent',
  ].includes(context.lifeStage);
}

/** Convert a numeric ordinal ("1") into text ("first"). */
function ordinalText(value: string): string {
  const map: Record<string, string> = {
    '1': 'first',
    '2': 'second',
    '3': 'third',
    '4': 'fourth',
    '5': 'fifth',
    '6': 'sixth',
    '7': 'seventh',
    '8': 'eighth',
    '9': 'ninth',
    '10': 'tenth',
  };

  return map[value.trim()] ?? value;
}

// -----------------------------------------------------------------------------
// Public contract
// -----------------------------------------------------------------------------

export interface DocumentationSentence {
  text: string;
  factCode: string | null;
}

export interface DocumentationSection {
  section: HistorySection;
  title: string;
  sentences: DocumentationSentence[];
}

// -----------------------------------------------------------------------------
// Main compiler
// -----------------------------------------------------------------------------

export function compileDocumentation(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection[] {
  const sections: Array<DocumentationSection | null> = [
    compileBiodata(context, facts),
    compileChiefComplaint(context, facts),
    compileHPI(context, facts),

    compilePastMedicalHistory(facts),
    compilePastSurgicalHistory(facts),
    compileDrugHistory(facts),
    compileAllergyHistory(facts),
    compileFamilyHistory(context, facts),
    compileSocialHistory(context, facts),
    compileOccupationalHistory(facts),
    compileSexualHistory(facts),

    compileObstetricHistory(context, facts),
    compileGynaecologicalHistory(context, facts),
    compileANCProfile(context, facts),

    compileBirthHistory(context, facts),
    compileGrowthDevelopment(context, facts),
    compileImmunization(context, facts),
    compileNutrition(context, facts),

    compilePsychiatricHistory(context, facts),
    compileSubstanceHistory(context, facts),
    compileCollateralHistory(context, facts),

    compileReviewOfSystems(facts),
    compileSummary(context, facts),
  ];

  return sections.filter(
    (item): item is DocumentationSection => item !== null,
  );
}

// =============================================================================
// SHORTHAND NOTE
//
// A fast, abbreviation-dense view of the same note for quick scanning:
//   C/C  Cough ×4d
//   Pt   Kimani Munyua · M · farmer · Kituso, Kitui Cnty
// Every shorthand line keeps its originating factCode.
// =============================================================================

const SHORTHAND_HEADERS: Record<string, string> = {
  biodata: 'Pt',
  chief_complaint: 'C/C',
  hpi: 'HPI',
  past_medical_history: 'PMHx',
  past_surgical_history: 'PSHx',
  drug_history: 'Rx',
  allergy_history: 'Allergies',
  family_history: 'FamHx',
  social_history: 'SocHx',
  occupational_history: 'OccHx',
  sexual_history: 'SexHx',
  review_of_systems: 'ROS',
  obstetric_history: 'ObsHx',
  gynaecological_history: 'GynHx',
  anc_profile: 'ANC',
  birth_history: 'BirthHx',
  growth_development: 'Growth',
  immunization: 'Immun',
  nutrition: 'Nutrition',
  psychiatric_history: 'PsychHx',
  substance_history: 'SubstHx',
  collateral_history: 'Collat',
  maternal_history: 'MatHx',
  summary: 'Summary',
};

const SHORT_DURATION_UNITS: Record<string, string> = {
  minutes: 'min',
  hours: 'h',
  days: 'd',
  weeks: 'w',
  months: 'm',
  years: 'y',
};

const SHORT_SEX: Record<string, string> = {
  male: 'M',
  female: 'F',
  intersex: 'I',
  'sex unknown': '?',
};

/** "Cough for 4 days." → "Cough ×4d" */
function condenseDuration(text: string): string {
  return text.replace(
    / for (\d+) (minutes|hours|days|weeks|months|years)\b/g,
    (_, value: string, unit: string) =>
      ` \u00d7${value}${SHORT_DURATION_UNITS[unit]}`,
  );
}

function reliabilityTag(tail: string): string | null {
  if (tail.includes('and is reliable')) return 'reliable';
  if (tail.includes('fairly reliable')) return 'fair';
  if (tail.includes('poor reliability')) return 'poor';
  if (tail.includes('unreliable')) return 'unreliable';
  return null;
}

/** "He is the informant and is reliable." → "informant: self (reliable)" */
function condenseInformant(text: string): string | null {
  const trimmed = text.trim();

  let match = /^(He|She) is the informant(.*)$/.exec(trimmed);
  if (match) {
    const tag = reliabilityTag(match[2]);
    return tag
      ? `informant: self (${tag})`
      : 'informant: self';
  }

  match = /^(His|Her) (.+) is the informant(.*)$/.exec(trimmed);
  if (match) {
    const who = match[2];
    const tag = reliabilityTag(match[3]);
    return tag
      ? `informant: ${who} (${tag})`
      : `informant: ${who}`;
  }

  return null;
}

function condenseBiodataLine(text: string): string {
  const trimmed = text.trim();

  let match = /^This is (.+?), ([a-z ]+)\.$/.exec(trimmed);
  if (match) {
    return `${match[1]} \u00b7 ${SHORT_SEX[match[2]] ?? match[2]}`;
  }

  match = /^(He|She) is a (.+?) from (.+?), (.+) county\.$/.exec(trimmed);
  if (match) {
    return `${match[2]} \u00b7 ${match[3]}, ${match[4]} Cnty`;
  }

  match = /^(He|She) is a (.+?)\.$/.exec(trimmed);
  if (match) {
    return match[2];
  }

  match = /^(He|She) resides in (.+?), (.+) county\.$/.exec(trimmed);
  if (match) {
    return `lives \u00b7 ${match[2]}, ${match[3]} Cnty`;
  }

  match = /^(He|She) resides in (.+?) county\.$/.exec(trimmed);
  if (match) {
    return `lives \u00b7 ${match[1]} Cnty`;
  }

  match = /^MRN: (.+)\.$/.exec(trimmed);
  if (match) {
    return `MRN ${match[1]}`;
  }

  match = /^Admitted on (.+)\.$/.exec(trimmed);
  if (match) {
    return `Admitted ${match[1]}`;
  }

  match = /^Seen as an outpatient \(review\)\.$/.exec(trimmed);
  if (match) {
    return 'OPD review';
  }

  match = /^Currently admitted — date of admission pending\.$/.exec(trimmed);
  if (match) {
    return 'Admitted (date pending)';
  }

  match = /^(He|She) is of the (.+) faith\.$/.exec(trimmed);
  if (match) {
    return `religion: ${match[2]}`;
  }

  match = /^She is doing day (\d+) post admission\.$/.exec(trimmed);
  if (match) {
    return `Day ${match[1]} post-admission`;
  }

  match = /^She is doing day (\d+) of (.+)\.$/.exec(trimmed);
  if (match) {
    return `Day ${match[1]} post-op (${match[2]})`;
  }

  match = /^She is doing day (\d+) post-operative\.$/.exec(trimmed);
  if (match) {
    return `Day ${match[1]} post-op`;
  }

  match = /^She is doing day (\d+) post MVA or D&C\.$/.exec(trimmed);
  if (match) {
    return `Day ${match[1]} post-MVA/D&C`;
  }

  match = /^(He|She) attends (.+)\.$/.exec(trimmed);
  if (match) {
    return `school: ${match[2]}`;
  }

  return condenseDuration(trimmed);
}

function condenseGeneric(text: string): string {
  return condenseDuration(text).replace(/\s+/g, ' ').trim();
}

interface ShorthandSectionInput {
  section: string;
  title?: string;
  sentences: DocumentationSentence[];
}

export interface ShorthandSection {
  section: string;
  title: string;
  sentences: DocumentationSentence[];
}

/**
 * Transform a compiled narrative note into the compact shorthand view.
 * Sections keep their order and every line keeps its originating factCode.
 */
export function toShorthand(
  sections: ShorthandSectionInput[],
): ShorthandSection[] {
  const shorthand: Array<ShorthandSection | null> = sections.map(
    (section) => {
      const lines = section.sentences
        .map((item) => {
          const text = item.text.trim();
          if (!text) return null;

          const condensed =
            section.section === 'biodata'
              ? condenseInformant(text) ?? condenseBiodataLine(text)
              : condenseGeneric(text);

          if (!condensed.trim()) return null;

          return {
            text: condensed.trim(),
            factCode: item.factCode,
          };
        })
        .filter(
          (item): item is DocumentationSentence =>
            item !== null && item.text.length > 0,
        );

      if (lines.length === 0) {
        return null;
      }

      return {
        section: section.section,
        title:
          SHORTHAND_HEADERS[section.section] ?? section.title,
        sentences: lines,
      };
    },
  );

  return shorthand.filter(
    (item): item is ShorthandSection => item !== null,
  );
}

// =============================================================================
// BIODATA
// =============================================================================

function resolveAgeYears(
  context: ClinicalContext,
  facts: ClinicalFact[],
): string | null {
  const contextAge =
    context.ageYears != null &&
    Number.isFinite(context.ageYears) &&
    context.ageYears > 0
      ? context.ageYears
      : null;

  const factAge = Number(
    value(facts, 'AGE_YEARS') ??
      value(facts, 'REPORTED_AGE') ??
      '',
  );

  let years =
    contextAge ??
    (Number.isFinite(factAge) && factAge > 0
      ? factAge
      : null);

  if (years == null) {
    const dob = value(facts, 'DATE_OF_BIRTH');
    if (dob) {
      const parsed = new Date(`${dob}T00:00:00`);
      if (!Number.isNaN(parsed.getTime())) {
        const today = new Date();
        let y =
          today.getFullYear() - parsed.getFullYear();
        const m =
          today.getMonth() - parsed.getMonth();
        if (
          m < 0 ||
          (m === 0 &&
            today.getDate() < parsed.getDate())
        ) {
          y -= 1;
        }
        years = Math.max(0, y);
      }
    }
  }

  if (years == null) return null;

  return `${years} ${years === 1 ? 'year' : 'years'}`;
}

function compileBiodata(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const name = value(facts, 'PATIENT_NAME');
  const sex = formatSex(value(facts, 'SEX'));
  const mrn = value(facts, 'MRN');
  const occupation = value(facts, 'OCCUPATION');
  const residence = value(facts, 'RESIDENCE');
  const county = value(facts, 'COUNTY');
  const informantRelation = value(facts, 'INFORMANT_RELATION');
  const informantReliability = value(facts, 'INFORMANT_RELIABILITY');
  const encounterType = (value(facts, 'ENCOUNTER_TYPE') ?? '').toUpperCase();
  const admissionDate = value(facts, 'ADMISSION_DATE');

  const ageYears = resolveAgeYears(context, facts);

  const pronounSubject =
    name
      ? sex === 'female'
        ? 'She'
        : sex === 'male'
          ? 'He'
          : name
      : 'The patient';

  const sentences: DocumentationSentence[] = [];

  // Identity — concise: "Kimunya njogu, male, 28 years."
  const identity: string[] = [];
  if (name) {
    identity.push(name);
  } else {
    identity.push('Patient');
  }
  if (sex) {
    identity.push(sex);
  }
  if (ageYears) {
    identity.push(ageYears);
  }

  if (identity.length > 0) {
    sentences.push(
      sentence(
        `${identity.join(', ')}.`,
        hasFact(facts, 'PATIENT_NAME')
          ? 'PATIENT_NAME'
          : hasFact(facts, 'AGE_YEARS')
            ? 'AGE_YEARS'
            : 'SEX',
      ),
    );
  }

  if (mrn) {
    sentences.push(
      sentence(`MRN: ${mrn}.`, 'MRN'),
    );
  }

  // Origin — concise: "Teacher, Kimunye, Kirinyaga county."
  const origin: string[] = [];
  if (occupation) {
    origin.push(occupation);
  }
  if (residence) {
    origin.push(residence);
  }
  if (county) {
    origin.push(`${county} county`);
  }

  if (origin.length > 0) {
    sentences.push(
      sentence(
        `${origin.join(', ')}.`,
        hasFact(facts, 'OCCUPATION')
          ? 'OCCUPATION'
          : hasFact(facts, 'RESIDENCE')
            ? 'RESIDENCE'
            : 'COUNTY',
      ),
    );
  }

  // Informant — concise: "Informant: self, reliable."
  if (informantRelation) {
    const relation =
      informantRelation.toLowerCase();
    const reliability = informantReliability
      ? informantReliability.toLowerCase()
      : null;

    sentences.push(
      sentence(
        `Informant: ${relation}${
          reliability
            ? `, ${reliability}`
            : ''
        }.`,
        'INFORMANT_RELATION',
      ),
    );
  }

  // Encounter disposition: date of admission is recorded for inpatients.
  if (encounterType === 'INPATIENT') {
    if (admissionDate) {
      sentences.push(
        sentence(
          `Admitted on ${admissionDate}.`,
          'ADMISSION_DATE',
        ),
      );
    } else {
      sentences.push(
        sentence(
          'Currently admitted — date of admission pending.',
          'ENCOUNTER_TYPE',
        ),
      );
    }
  } else if (encounterType === 'OUTPATIENT') {
    sentences.push(
      sentence(
        'Seen as an outpatient (review).',
        'ENCOUNTER_TYPE',
      ),
    );
  }

  const religion = value(facts, 'RELIGION');
  if (religion) {
    sentences.push(
      sentence(
        `${pronounSubject} is of the ${normalizeCode(religion)} faith.`,
        'RELIGION',
      ),
    );
  }

  const school = value(facts, 'SCHOOL_NAME');
  if (school) {
    sentences.push(
      sentence(
        `${pronounSubject} attends ${school}.`,
        'SCHOOL_NAME',
      ),
    );
  }

  const postAdmissionDay = value(facts, 'POST_ADMISSION_DAY');
  const postOpDay = value(facts, 'POST_OPERATIVE_DAY');
  const postOpProcedure = value(facts, 'POST_OPERATIVE_PROCEDURE');
  const postMvaDcDays = value(facts, 'POST_MVA_DC_DAYS');

  if (postAdmissionDay) {
    sentences.push(
      sentence(
        `She is doing day ${postAdmissionDay} post admission.`,
        'POST_ADMISSION_DAY',
      ),
    );
  }

  if (postOpDay) {
    const procedurePart = postOpProcedure
      ? ` of ${postOpProcedure}`
      : ' post-operative';
    sentences.push(
      sentence(
        `She is doing day ${postOpDay}${procedurePart}.`,
        hasFact(facts, 'POST_OPERATIVE_PROCEDURE')
          ? 'POST_OPERATIVE_PROCEDURE'
          : 'POST_OPERATIVE_DAY',
      ),
    );
  }

  if (postMvaDcDays) {
    sentences.push(
      sentence(
        `She is doing day ${postMvaDcDays} post MVA or D&C.`,
        'POST_MVA_DC_DAYS',
      ),
    );
  }

  return section('biodata', 'Patient', sentences);
}

// =============================================================================
// CHIEF COMPLAINT
// =============================================================================

function compileChiefComplaint(
  _context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const complaint = lastValue(
    facts,
    'PRESENTING_COMPLAINT',
  );
  const encounterType = (value(facts, 'ENCOUNTER_TYPE') ?? '').toUpperCase();
  const admissionDate = value(facts, 'ADMISSION_DATE');
  const name = value(facts, 'PATIENT_NAME');
  const sex = formatSex(value(facts, 'SEX'));

  const structured = hasChiefComplaints(facts);
  const followUpNoComplaints = isYes(facts, 'FOLLOW_UP_NO_COMPLAINTS');

  if (
    !complaint &&
    !structured &&
    !followUpNoComplaints &&
    !encounterType &&
    !admissionDate
  ) {
    return null;
  }

  const pronoun =
    name
      ? sex === 'female'
        ? 'She'
        : sex === 'male'
          ? 'He'
          : name
      : 'The patient';

  const sentences: DocumentationSentence[] = [];

  if (structured) {
    const oldestFirst = getChiefComplaintsOldestFirst(facts);

    for (const entry of oldestFirst) {
      const duration =
        formatDuration(
          Number(entry.durationValue) || null,
          entry.durationUnit,
        ) ?? entry.durationText;

      if (duration) {
        sentences.push(
          sentence(
            `${entry.label} for ${duration}.`,
            complaintDurationFactCode(entry.code),
          ),
        );
      } else {
        sentences.push(
          sentence(
            `${entry.label}.`,
            complaintLabelFactCode(entry.code),
          ),
        );
      }
    }
  } else if (followUpNoComplaints) {
    sentences.push(
      sentence(
        `${pronoun} is on routine review / follow-up and reports no current complaints.`,
        'FOLLOW_UP_NO_COMPLAINTS',
      ),
    );
  } else if (complaint) {
    const parsed = parsePresentingComplaints(complaint);
    if (parsed.length > 0) {
      for (const entry of parsed) {
        sentences.push(
          sentence(
            `${sentenceCase(entry.label)}${entry.duration ? ` for ${entry.duration}` : ''}.`,
            'PRESENTING_COMPLAINT',
          ),
        );
      }
    } else {
      sentences.push(
        sentence(
          complaint,
          'PRESENTING_COMPLAINT',
        ),
      );
    }
  }

  // Presentation timing, derived from the recorded admission date for
  // inpatients: "She presented today." / "She presented 2 days ago."
  if (encounterType === 'INPATIENT') {
    if (admissionDate) {
      const days = daysSince(admissionDate);
      if (days === 0) {
        sentences.push(
          sentence(
            `${pronoun} presented today.`,
            'ADMISSION_DATE',
          ),
        );
      } else if (days === 1) {
        sentences.push(
          sentence(
            `${pronoun} presented yesterday.`,
            'ADMISSION_DATE',
          ),
        );
      } else {
        sentences.push(
          sentence(
            `${pronoun} presented ${days} days ago.`,
            'ADMISSION_DATE',
          ),
        );
      }
    } else {
      sentences.push(
        sentence(
          `${pronoun} presented as an inpatient — date of admission pending.`,
          'ENCOUNTER_TYPE',
        ),
      );
    }
  } else if (encounterType === 'OUTPATIENT') {
    sentences.push(
      sentence(
        `${pronoun} presented as an outpatient (review).`,
        'ENCOUNTER_TYPE',
      ),
    );
  }

  return section(
    'chief_complaint',
    'Chief Complaint',
    sentences,
  );
}

function daysSince(dateText: string): number {
  const parsed = new Date(`${dateText}T00:00:00`);
  if (Number.isNaN(parsed.getTime())) return 0;
  const today = new Date();
  const midnight = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate(),
  );
  return Math.max(
    0,
    Math.floor(
      (midnight.getTime() - parsed.getTime()) / 86_400_000,
    ),
  );
}

// =============================================================================
// HPI
// =============================================================================

const OFFSET_UNIT_SECONDS: Record<DurationUnit, number> = {
  minutes: 60,
  hours: 3_600,
  days: 86_400,
  weeks: 604_800,
  months: 2_629_800,
  years: 31_557_600,
};

function offsetDurationText(
  seconds: number,
  unit: DurationUnit,
): string {
  const unitSeconds = OFFSET_UNIT_SECONDS[unit] ?? 86_400;

  if (seconds % unitSeconds === 0) {
    const text = formatDuration(seconds / unitSeconds, unit);
    if (text) return text;
  }

  return formatDuration(seconds / 86_400, 'days') ?? 'a while';
}

// -----------------------------------------------------------------------------
// Canonical DB symptom facts (cough / fever reference)
//
// The CPU owns the per-symptom HPI battery in PostgreSQL (COUGH_PRODUCTIVITY,
// SPUTUM_COLOUR, ...). The HPI narrative renders those facts so the live note
// stays coincident with the PDF export. Only well-known facts with stable
// wording are mapped here; the rest flow through the CPU documentation
// template.
// -----------------------------------------------------------------------------

const NEGATIVE_VALUE_CODES = new Set([
  'NO',
  'NONE',
  'FALSE',
  'UNKNOWN',
  'ABSENT',
  'NOT_APPLICABLE',
]);

interface CanonicalDetailRule {
  fact: string;
  template: string;
}

const CANONICAL_HPI_DETAILS: Record<string, CanonicalDetailRule[]> = {
  COUGH: [
    {
      fact: 'COUGH_PRODUCTIVITY',
      template: 'The {label} is {value}.',
    },
    {
      fact: 'COUGH_CHARACTER',
      template: 'The {label} is described as {value}.',
    },
    {
      fact: 'COUGH_SEVERITY',
      template: 'At its worst the {label} is {value} in severity.',
    },
    {
      fact: 'COUGH_TRIGGERS',
      template: 'The {label} is aggravated by {value}.',
    },
    {
      fact: 'COUGH_RELIEVING',
      template: 'The {label} is relieved by {value}.',
    },
    {
      fact: 'COUGH_NIGHT_PREDOMINANCE',
      template: 'The {label} is worse at night.',
    },
    {
      fact: 'COUGH_POSITIONAL',
      template: 'The {label} is worse when lying flat.',
    },
    {
      fact: 'SPUTUM_COLOUR',
      template: 'The sputum is {value} in colour.',
    },
    {
      fact: 'SPUTUM_CONSISTENCY',
      template: 'The sputum is {value}.',
    },
    {
      fact: 'SPUTUM_ODOUR',
      template: 'The sputum is foul-smelling.',
    },
    {
      fact: 'BLOOD_IN_SPUTUM',
      template: 'There is blood in the sputum (haemoptysis).',
    },
  ],
  FEVER: [
    {
      fact: 'FEVER_PATTERN',
      template: 'The fever is {value} in pattern.',
    },
  ],
  DYSPNOEA: [
    {
      fact: 'DYSPNOEA_SEVERITY',
      template: 'There is breathlessness {value}.',
    },
    {
      fact: 'ORTHOPNOEA',
      template: 'There is orthopnoea.',
    },
    {
      fact: 'PND',
      template: 'There is paroxysmal nocturnal dyspnoea.',
    },
    {
      fact: 'WHEEZE_PRESENT',
      template: 'There is wheeze.',
    },
  ],
};

const CANONICAL_ONSET_FACT: Record<string, string> = {
  COUGH: 'COUGH_ONSET',
  FEVER: 'FEVER_ONSET',
  DYSPNOEA: 'DYSPNOEA_ONSET',
};

function canonicalDetailSentences(
  code: string,
  label: string,
  facts: ClinicalFact[],
): DocumentationSentence[] {
  const out: DocumentationSentence[] = [];

  for (const rule of CANONICAL_HPI_DETAILS[code] ?? []) {
    const raw = value(facts, rule.fact);

    if (!raw || NEGATIVE_VALUE_CODES.has(raw.toUpperCase())) {
      continue;
    }

    out.push(
      sentence(
        rule.template
          .replace(/\{label\}/g, label)
          .replace(/\{value\}/g, normalizeCode(raw)),
        rule.fact,
      ),
    );
  }

  return out;
}

function compileHPI(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const structured = hasChiefComplaints(facts);
  const summary = lastValue(
    facts,
    'PRESENTING_COMPLAINT',
  );

  const sentences: DocumentationSentence[] = [];
  const details: DocumentationSentence[] = [];

  if (structured) {
    // Chronological narrative: each complaint is described once, in the order
    // it appeared (oldest first), without repetition and without allowing the
    // Review of Systems to re-ask about covered systems.
    const oldestFirst = getChiefComplaintsOldestFirst(facts);
    const firstEntry = oldestFirst[0];
    const firstSeconds = firstEntry?.durationSeconds ?? 0;
    const firstLabel = (firstEntry?.label ?? '').toLowerCase();

    oldestFirst.forEach((entry, index) => {
      const code = entry.code;
      const label = entry.label.toLowerCase();
      const duration =
        formatDuration(
          Number(entry.durationValue) || null,
          entry.durationUnit,
        ) ?? entry.durationText;

      const canonicalOnsetFact = CANONICAL_ONSET_FACT[code];

      const onset =
        value(facts, `${code}_SYMPTOM_ONSET`) ??
        (canonicalOnsetFact
          ? value(facts, canonicalOnsetFact)
          : null);

      const course = value(facts, `${code}_SYMPTOM_COURSE`);
      const severity = value(facts, `${code}_SYMPTOM_SEVERITY`);
      const aggravating = value(facts, `${code}_SYMPTOM_AGGRAVATING`);
      const relieving = value(facts, `${code}_SYMPTOM_RELIEVING`);
      const associated = value(facts, `${code}_SYMPTOM_ASSOCIATED`);

      if (index === 0) {
        // Oldest complaint: "The illness began with fever 3 days ago,
        // with sudden onset."
        const parts: string[] = [];

        if (duration) {
          parts.push(`The illness began with ${label} ${duration} ago`);
        } else {
          parts.push(`The illness began with ${label}`);
        }

        if (onset) {
          parts.push(`${normalizeCode(onset)} onset`);
        }

        if (parts.length > 0) {
          sentences.push(
            sentence(
              `${parts.join(', ')}.`,
              onset
                ? (canonicalOnsetFact ??
                  `${code}_SYMPTOM_ONSET`)
                : complaintDurationFactCode(code),
            ),
          );
        }
      } else {
        const parts: string[] = [];

        const entrySeconds = entry.durationSeconds ?? 0;

        if (
          entrySeconds > 0 &&
          firstSeconds > 0 &&
          entrySeconds < firstSeconds
        ) {
          parts.push(
            `${entry.label} developed ${offsetDurationText(
              firstSeconds - entrySeconds,
              entry.durationUnit,
            )} after the ${firstLabel} began`,
          );
        } else if (
          entrySeconds > 0 &&
          firstSeconds > 0 &&
          entrySeconds === firstSeconds
        ) {
          parts.push(`${entry.label} began at the same time`);
        } else {
          parts.push(`${entry.label} is also present`);
        }

        if (onset) {
          parts.push(`${normalizeCode(onset)} onset`);
        }

        sentences.push(
          sentence(
            `${parts.join(', ')}.`,
            onset
              ? (canonicalOnsetFact ??
                `${code}_SYMPTOM_ONSET`)
              : complaintDurationFactCode(code),
          ),
        );
      }

      if (course) {
        sentences.push(
          sentence(
            `The ${label} has been ${normalizeCode(course)}.`,
            `${code}_SYMPTOM_COURSE`,
          ),
        );
      }

      if (severity) {
        sentences.push(
          sentence(
            `At its worst the ${label} is ${normalizeCode(severity)} in severity.`,
            `${code}_SYMPTOM_SEVERITY`,
          ),
        );
      }

      if (aggravating) {
        sentences.push(
          sentence(
            `The ${label} is aggravated by ${normalizeCode(aggravating)}.`,
            `${code}_SYMPTOM_AGGRAVATING`,
          ),
        );
      }

      if (relieving) {
        sentences.push(
          sentence(
            `The ${label} is relieved by ${normalizeCode(relieving)}.`,
            `${code}_SYMPTOM_RELIEVING`,
          ),
        );
      }

      if (associated) {
        sentences.push(
          sentence(
            `Associated symptoms with the ${label}: ${associated}.`,
            `${code}_SYMPTOM_ASSOCIATED`,
          ),
        );
      }

      details.push(
        ...canonicalDetailSentences(code, label, facts),
      );
    });

    sentences.push(...details);
  } else {
    // Non-structured case (live server snapshot): the HPI chronology is rebuilt
    // from the single PRESENTING_COMPLAINT summary so it matches the PDF export
    // exactly — onset offsets are the differences between the complaints'
    // durations. Any extra HPI detail facts are appended afterwards.
    if (summary) {
      const parsed = parsePresentingComplaints(summary);
      if (parsed.length > 0) {
        const first = parsed[0];
        const firstLower = first.label.toLowerCase();

        if (first.duration) {
          sentences.push(
            sentence(
              `The illness began with ${firstLower} ${first.duration} ago.`,
              'PRESENTING_COMPLAINT',
            ),
          );
        } else {
          sentences.push(
            sentence(`The illness began with ${firstLower}.`, 'PRESENTING_COMPLAINT'),
          );
        }

        for (const entry of parsed.slice(1)) {
          if (entry.seconds > 0 && first.seconds > 0 && entry.seconds < first.seconds) {
            sentences.push(
              sentence(
                `${sentenceCase(entry.label)} developed ${offsetDurationText(first.seconds - entry.seconds, entry.unit)} after the ${firstLower} began.`,
                'PRESENTING_COMPLAINT',
              ),
            );
          } else if (entry.seconds > 0 && first.seconds > 0 && entry.seconds === first.seconds) {
            sentences.push(
              sentence(
                `${sentenceCase(entry.label)} began at the same time.`,
                'PRESENTING_COMPLAINT',
              ),
            );
          } else {
            sentences.push(
              sentence(`${sentenceCase(entry.label)} is also present.`, 'PRESENTING_COMPLAINT'),
            );
          }
        }
      }
    }

    const followUpCourse = value(
      facts,
      'FOLLOW_UP_COURSE',
    );

    if (followUpCourse) {
      sentences.push(
        sentence(
          followUpCourse,
          'FOLLOW_UP_COURSE',
        ),
      );
    }

    const duration = value(
      facts,
      'SYMPTOM_DURATION',
    );

    const onset = value(
      facts,
      'SYMPTOM_ONSET',
    );

    const severity = value(
      facts,
      'SYMPTOM_SEVERITY',
    );

    const openingParts: string[] = [];

    if (duration) {
      openingParts.push(
        `The presenting problem has been present for ${duration}`,
      );
    }

    if (onset) {
      openingParts.push(
        `${normalizeCode(onset)} onset`,
      );
    }

    if (severity) {
      openingParts.push(
        `described as ${normalizeCode(severity)} in severity`,
      );
    }

       if (openingParts.length > 0) {
      sentences.push(
        sentence(
          `${openingParts.join(', ')}.`,
          duration
            ? 'SYMPTOM_DURATION'
            : onset
              ? 'SYMPTOM_ONSET'
              : 'SYMPTOM_SEVERITY',
        ),
      );
    }

    // Mirror the PDF: append captured HPI detail facts as prose so the live
    // note and the export read identically.
    const details = facts
      .filter((fact) => fact.section === 'hpi')
      .map((fact) => formatFactValue(fact))
      .filter((value_): value_ is string => Boolean(value_));
    if (details.length > 0) {
      sentences.push(sentence(details.join('. '), 'hpi'));
    }
  }

  // ---------------------------------------------------------------------------
  // Paediatric HPI overlays
  // ---------------------------------------------------------------------------

  if (
    ['neonate', 'infant', 'child'].includes(
      context.lifeStage,
    )
  ) {
    const feeding = value(
      facts,
      'FEEDING_STATUS',
    );

    const activity = value(
      facts,
      'ACTIVITY_STATUS',
    );

    if (feeding) {
      sentences.push(
        sentence(
          `Feeding is ${normalizeCode(feeding)} compared with usual.`,
          'FEEDING_STATUS',
        ),
      );
    }

    if (activity) {
      sentences.push(
        sentence(
          `Activity is ${normalizeCode(activity)} compared with baseline.`,
          'ACTIVITY_STATUS',
        ),
      );
    }

    if (isYes(facts, 'GRUNTING_PRESENT')) {
      sentences.push(
        sentence(
          'Grunting or unusual noisy breathing was reported.',
          'GRUNTING_PRESENT',
        ),
      );
    }

    if (isNo(facts, 'GRUNTING_PRESENT')) {
      sentences.push(
        sentence(
          'No grunting or unusual noisy breathing was reported.',
          'GRUNTING_PRESENT',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Surgical post-operative overlay
  // ---------------------------------------------------------------------------
  const postOpDay = value(facts, 'POST_OPERATIVE_DAY');
  const postOpProcedure = value(facts, 'POST_OPERATIVE_PROCEDURE');
  const postOpReported = postOpDay || postOpProcedure;

  if (postOpReported) {
    const passedFlatus = value(
      facts,
      'POSTOP_PASSED_FLATUS',
    );
    const dietTolerance = value(
      facts,
      'POSTOP_DIET_TOLERANCE',
    );
    const mobility = value(
      facts,
      'POSTOP_MOBILITY',
    );
    const bladderBowel = value(
      facts,
      'POSTOP_BLADDER_BOWEL_NORMAL',
    );
    const woundPain = value(
      facts,
      'POSTOP_WOUND_PAIN',
    );
    const woundDischarge = value(
      facts,
      'POSTOP_WOUND_DISCHARGE',
    );
    const fever = value(
      facts,
      'POSTOP_FEVER',
    );
    const otherComplaints = value(
      facts,
      'POSTOP_OTHER_COMPLAINTS',
    );

    const overlay: Array<{ value: string | null; fact: string; text: string }> = [
      {
        value: passedFlatus,
        fact: 'POSTOP_PASSED_FLATUS',
        text: `The patient has ${passedFlatus === 'YES' ? '' : 'not '}passed stool and flatus.`,
      },
      {
        value: dietTolerance,
        fact: 'POSTOP_DIET_TOLERANCE',
        text: `The patient ${dietTolerance === 'YES' ? 'tolerates' : 'does not tolerate'} diet.`,
      },
      {
        value: mobility,
        fact: 'POSTOP_MOBILITY',
        text: `The patient ${mobility === 'YES' ? 'is' : 'is not'} able to walk around.`,
      },
      {
        value: bladderBowel,
        fact: 'POSTOP_BLADDER_BOWEL_NORMAL',
        text: `Bladder and bowel habits are ${bladderBowel === 'YES' ? 'normal' : 'abnormal'}.`,
      },
      {
        value: woundPain,
        fact: 'POSTOP_WOUND_PAIN',
        text: `There is ${woundPain === 'YES' ? 'pain at the surgical site' : 'no pain at the surgical site'}.`,
      },
      {
        value: woundDischarge,
        fact: 'POSTOP_WOUND_DISCHARGE',
        text: `There is ${woundDischarge === 'YES' ? 'discharge from the wound' : 'no discharge from the wound'}.`,
      },
      {
        value: fever,
        fact: 'POSTOP_FEVER',
        text: `The patient ${fever === 'YES' ? 'has' : 'has no'} hotness of body (fever).`,
      },
    ];

    for (const item of overlay) {
      if (!item.value) {
        continue;
      }

      sentences.push(
        sentence(item.text, item.fact),
      );
    }

    if (otherComplaints) {
      sentences.push(
        sentence(
          `Other post-operative complaints: ${otherComplaints}.`,
          'POSTOP_OTHER_COMPLAINTS',
        ),
      );
    }
  }

  if (sentences.length === 0) {
    return null;
  }

  return section(
    'hpi',
    'History of Present Illness',
    sentences,
  );
}

// =============================================================================
// PAST MEDICAL HISTORY
//
// Burden unloading: a single "no relevant history" captures admissions,
// transfusions, chronic conditions and serostatus in one documented sentence.
// =============================================================================

function compilePastMedicalHistory(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const present = value(
    facts,
    'PAST_MEDICAL_HISTORY_PRESENT',
  );

  const details = value(
    facts,
    'PAST_MEDICAL_HISTORY_DETAILS',
  );

  const conditions = formatList(
    value(facts, 'CHRONIC_CONDITIONS'),
  );

  const hospitalization = value(
    facts,
    'PREVIOUS_HOSPITALIZATION',
  );

  const hospitalizationDetails = value(
    facts,
    'PREVIOUS_HOSPITALIZATION_DETAILS',
  );

  const transfusion = value(
    facts,
    'BLOOD_TRANSFUSION',
  );

  const transfusionDetails = value(
    facts,
    'BLOOD_TRANSFUSION_DETAILS',
  );

  const hivStatus = value(
    facts,
    'HIV_SEROSTATUS',
  );

  const onART = value(
    facts,
    'ON_ART',
  );

  const sentences: DocumentationSentence[] = [];

  // Fast combined negative when the gate is "no".
  if (present === 'no' || present === 'NO') {
    sentences.push(
      sentence(
        'The patient reports no relevant previous medical conditions.',
        'PAST_MEDICAL_HISTORY_PRESENT',
      ),
    );

    if (hospitalization === 'no' || hospitalization === 'NO') {
      sentences.push(
        sentence(
          'There is no history of previous hospital admissions.',
          'PREVIOUS_HOSPITALIZATION',
        ),
      );
    }

    if (transfusion === 'no' || transfusion === 'NO') {
      sentences.push(
        sentence(
          'There is no history of blood transfusion.',
          'BLOOD_TRANSFUSION',
        ),
      );
    }

    if (hivStatus === 'NEGATIVE' || hivStatus === 'negative') {
      sentences.push(
        sentence(
          'The patient is HIV seronegative.',
          'HIV_SEROSTATUS',
        ),
      );
    }
  } else if (present === 'yes' || present === 'YES') {
    if (conditions) {
      sentences.push(
        sentence(
          `The patient has a history of ${normalizeCode(conditions)}.`,
          'CHRONIC_CONDITIONS',
        ),
      );
    } else {
      sentences.push(
        sentence(
          'The patient reports previous medical conditions.',
          'PAST_MEDICAL_HISTORY_PRESENT',
        ),
      );
    }

    if (details) {
      sentences.push(
        sentence(
          details,
          'PAST_MEDICAL_HISTORY_DETAILS',
        ),
      );
    }

    if (hivStatus) {
      const hivSentence =
        hivStatus === 'POSITIVE' || hivStatus === 'positive'
          ? 'The patient is HIV positive.'
          : hivStatus === 'NEGATIVE' || hivStatus === 'negative'
            ? 'The patient is HIV seronegative.'
            : `HIV serostatus: ${normalizeCode(hivStatus)}.`;
      sentences.push(
        sentence(hivSentence, 'HIV_SEROSTATUS'),
      );

      if (onART === 'yes' || onART === 'YES') {
        sentences.push(
          sentence(
            'The patient is on antiretroviral therapy (ART).',
            'ON_ART',
          ),
        );
      } else if (onART === 'no' || onART === 'NO') {
        sentences.push(
          sentence(
            'The patient is not currently on ART.',
            'ON_ART',
          ),
        );
      }
    }
  }

  // Hospitalization / transfusion detail captured independently.
  if (hospitalization === 'yes' || hospitalization === 'YES') {
    sentences.push(
      sentence(
        hospitalizationDetails
          ? `Previous hospital admissions: ${hospitalizationDetails}.`
          : 'The patient has a history of previous hospital admission.',
        hospitalizationDetails
          ? 'PREVIOUS_HOSPITALIZATION_DETAILS'
          : 'PREVIOUS_HOSPITALIZATION',
      ),
    );
  }

  if (transfusion === 'yes' || transfusion === 'YES') {
    sentences.push(
      sentence(
        transfusionDetails
          ? `History of blood transfusion: ${transfusionDetails}.`
          : 'The patient has a history of blood transfusion.',
        transfusionDetails
          ? 'BLOOD_TRANSFUSION_DETAILS'
          : 'BLOOD_TRANSFUSION',
      ),
    );
  }

  if (hivStatus && (present === 'no' || present === 'NO') && (hivStatus === 'POSITIVE' || hivStatus === 'positive')) {
    sentences.push(
      sentence(
        'The patient is HIV positive.',
        'HIV_SEROSTATUS',
      ),
    );
  }

  return section(
    'past_medical_history',
    'Past Medical History',
    sentences,
  );
}

// =============================================================================
// PAST SURGICAL HISTORY
// =============================================================================

function compilePastSurgicalHistory(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const present = value(
    facts,
    'PAST_SURGERY_PRESENT',
  );

  const history = value(
    facts,
    'PAST_SURGICAL_HISTORY',
  );

  const sentences: DocumentationSentence[] = [];

  if (present === 'yes' || present === 'YES') {
    sentences.push(
      sentence(
        history
          ? `Previous surgical history: ${history}.`
          : 'The patient reports previous surgical procedures.',
        history
          ? 'PAST_SURGICAL_HISTORY'
          : 'PAST_SURGERY_PRESENT',
      ),
    );
  } else if (present === 'no' || present === 'NO') {
    sentences.push(
      sentence(
        'There is no history of previous surgery or procedures.',
        'PAST_SURGERY_PRESENT',
      ),
    );
  } else if (history) {
    sentences.push(
      sentence(
        history,
        'PAST_SURGICAL_HISTORY',
      ),
    );
  }

  return section(
    'past_surgical_history',
    'Past Surgical History',
    sentences,
  );
}

// =============================================================================
// DRUG HISTORY
// =============================================================================

function compileDrugHistory(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const present = value(
    facts,
    'CURRENT_MEDICATION_PRESENT',
  );

  const medications = value(
    facts,
    'CURRENT_MEDICATIONS',
  );

  const recentTreatment = value(
    facts,
    'RECENT_TREATMENT',
  );

  const adherence = value(
    facts,
    'DRUG_ADHERENCE',
  );

  const sentences: DocumentationSentence[] = [];

  if (present === 'yes' || present === 'YES') {
    sentences.push(
      sentence(
        medications
          ? `Current medications: ${medications}.`
          : 'The patient is currently taking medication.',
        medications
          ? 'CURRENT_MEDICATIONS'
          : 'CURRENT_MEDICATION_PRESENT',
      ),
    );
  } else if (present === 'no' || present === 'NO') {
    sentences.push(
      sentence(
        'The patient is not on any current medication.',
        'CURRENT_MEDICATION_PRESENT',
      ),
    );
  }

  if (adherence) {
    sentences.push(
      sentence(
        `Medication adherence is reported as ${normalizeCode(adherence)}.`,
        'DRUG_ADHERENCE',
      ),
    );
  }

  if (recentTreatment) {
    sentences.push(
      sentence(
        `Recent treatment: ${recentTreatment}.`,
        'RECENT_TREATMENT',
      ),
    );
  }

  return section(
    'drug_history',
    'Drug History',
    sentences,
  );
}

// =============================================================================
// ALLERGY HISTORY
// =============================================================================

function compileAllergyHistory(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const present = value(
    facts,
    'ALLERGY_PRESENT',
  );

  const type = formatList(
    value(facts, 'ALLERGY_TYPE'),
  );

  const allergyDetails = value(
    facts,
    'ALLERGY_DETAILS',
  );

  const sentences: DocumentationSentence[] = [];

  if (present === 'yes' || present === 'YES') {
    const typeFragment = type
      ? ` (${normalizeCode(type)})`
      : '';
    sentences.push(
      sentence(
        `A clinically relevant allergy was reported${typeFragment}.`,
        hasFact(facts, 'ALLERGY_TYPE')
          ? 'ALLERGY_TYPE'
          : 'ALLERGY_PRESENT',
      ),
    );

    if (allergyDetails) {
      sentences.push(
        sentence(
          `Allergy details: ${allergyDetails}.`,
          'ALLERGY_DETAILS',
        ),
      );
    }
  } else if (present === 'no' || present === 'NO') {
    sentences.push(
      sentence(
        'No known food or drug allergies.',
        'ALLERGY_PRESENT',
      ),
    );
  }

  return section(
    'allergy_history',
    'Allergy History',
    sentences,
  );
}

// =============================================================================
// FAMILY HISTORY
// =============================================================================

function compileFamilyHistory(
  _context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const present = value(
    facts,
    'FAMILY_HISTORY_PRESENT',
  );

  const details = value(
    facts,
    'FAMILY_HISTORY_DETAILS',
  );

  const cardiovascular = value(
    facts,
    'FAMILY_HISTORY_CARDIOVASCULAR',
  );

  const cancer = value(
    facts,
    'FAMILY_HISTORY_CANCER',
  );

  const sibling = value(
    facts,
    'FAMILY_SIBLING_DEATH',
  );

  const sentences: DocumentationSentence[] = [];

  if (present === 'yes' || present === 'YES') {
    sentences.push(
      sentence(
        'A relevant family history was reported.',
        'FAMILY_HISTORY_PRESENT',
      ),
    );

    if (details) {
      sentences.push(
        sentence(
          details,
          'FAMILY_HISTORY_DETAILS',
        ),
      );
    }
  } else if (present === 'no' || present === 'NO') {
    sentences.push(
      sentence(
        'No relevant family history was reported.',
        'FAMILY_HISTORY_PRESENT',
      ),
    );
  }

  if (cardiovascular === 'yes' || cardiovascular === 'YES') {
    sentences.push(
      sentence(
        'There is a family history of hypertension, diabetes, heart disease or stroke.',
        'FAMILY_HISTORY_CARDIOVASCULAR',
      ),
    );
  }

  if (cancer === 'yes' || cancer === 'YES') {
    sentences.push(
      sentence(
        'There is a family history of cancer.',
        'FAMILY_HISTORY_CANCER',
      ),
    );
  }

  if (isYes(facts, 'FAMILY_TB_CONTACT')) {
    sentences.push(
      sentence(
        'The child has had close contact with a person with chronic cough or tuberculosis.',
        'FAMILY_TB_CONTACT',
      ),
    );
  } else if (isNo(facts, 'FAMILY_TB_CONTACT')) {
    sentences.push(
      sentence(
        'No close contact with a person with chronic cough or tuberculosis was reported.',
        'FAMILY_TB_CONTACT',
      ),
    );
  }

  if (isYes(facts, 'FAMILY_CONSANGUINITY')) {
    sentences.push(
      sentence(
        'The parents are related (consanguineous).',
        'FAMILY_CONSANGUINITY',
      ),
    );
  } else if (isNo(facts, 'FAMILY_CONSANGUINITY')) {
    sentences.push(
      sentence(
        'There is no history of parental consanguinity.',
        'FAMILY_CONSANGUINITY',
      ),
    );
  }

  if (isYes(facts, 'FAMILY_SICKLE_CELL')) {
    sentences.push(
      sentence(
        'There is a family history of sickle cell disease or trait.',
        'FAMILY_SICKLE_CELL',
      ),
    );
  }

  if (sibling) {
    sentences.push(
      sentence(
        sibling,
        'FAMILY_SIBLING_DEATH',
      ),
    );
  }

  return section(
    'family_history',
    'Family History',
    sentences,
  );
}

// =============================================================================
// SOCIAL HISTORY
//
// Age-appropriate: adult items (marital, alcohol, smoking) are never rendered
// for children; paediatric items (caregiver, school, home safety) are.
// =============================================================================

function compileSocialHistory(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const social = value(
    facts,
    'LIVING_SITUATION',
  );

  const support = value(
    facts,
    'SOCIAL_SUPPORT',
  );

  const maritalStatus = value(
    facts,
    'MARITAL_STATUS',
  );

  const alcohol = value(
    facts,
    'ALCOHOL_USE',
  );

  const alcoholDetails = value(
    facts,
    'ALCOHOL_DETAILS',
  );

  const smoking = value(
    facts,
    'SMOKING_STATUS',
  );

  const smokingDetails = value(
    facts,
    'SMOKING_DETAILS',
  );

  const caregiver = value(
    facts,
    'PRIMARY_CAREGIVER',
  );

  const school = value(
    facts,
    'SCHOOL_ATTENDANCE',
  );

  const homeConcerns = value(
    facts,
    'HOME_ENVIRONMENT_CONCERNS',
  );

  const sentences: DocumentationSentence[] = [];

  if (social) {
    sentences.push(
      sentence(
        social,
        'LIVING_SITUATION',
      ),
    );
  }

  if (maritalStatus) {
    sentences.push(
      sentence(
        `Marital status: ${normalizeCode(maritalStatus)}.`,
        'MARITAL_STATUS',
      ),
    );
  }

  if (caregiver) {
    sentences.push(
      sentence(
        `Primary caregiver: ${caregiver}.`,
        'PRIMARY_CAREGIVER',
      ),
    );
  }

  if (school) {
    sentences.push(
      sentence(
        school,
        'SCHOOL_ATTENDANCE',
      ),
    );
  }

  if (alcohol && alcohol !== 'NONE' && alcohol !== 'none' && alcohol !== 'UNKNOWN' && alcohol !== 'unknown') {
    sentences.push(
      sentence(
        alcoholDetails
          ? `Alcohol use: ${normalizeCode(alcohol)} — ${alcoholDetails}.`
          : `The patient reports ${normalizeCode(alcohol)} alcohol use.`,
        alcoholDetails
          ? 'ALCOHOL_DETAILS'
          : 'ALCOHOL_USE',
      ),
    );
  } else if (alcohol === 'NONE' || alcohol === 'none') {
    sentences.push(
      sentence(
        'The patient does not drink alcohol.',
        'ALCOHOL_USE',
      ),
    );
  }

  if (smoking && smoking !== 'NEVER' && smoking !== 'never' && smoking !== 'UNKNOWN' && smoking !== 'unknown') {
    sentences.push(
      sentence(
        smokingDetails
          ? `Smoking: ${normalizeCode(smoking)} — ${smokingDetails}.`
          : `The patient is a ${normalizeCode(smoking)} smoker.`,
        smokingDetails
          ? 'SMOKING_DETAILS'
          : 'SMOKING_STATUS',
      ),
    );
  } else if (smoking === 'NEVER' || smoking === 'never') {
    sentences.push(
      sentence(
        'The patient has never smoked tobacco.',
        'SMOKING_STATUS',
      ),
    );
  }

  if (homeConcerns) {
    sentences.push(
      sentence(
        homeConcerns,
        'HOME_ENVIRONMENT_CONCERNS',
      ),
    );
  }

  if (support) {
    sentences.push(
      sentence(
        `Social/caregiver support is ${normalizeCode(support)}.`,
        'SOCIAL_SUPPORT',
      ),
    );
  }

  if (isPaediatricLifeStage(context)) {
    const birthOrder = value(facts, 'BIRTH_ORDER');
    const siblings = value(facts, 'SIBLING_DETAILS');
    const parentsMarital = value(facts, 'PARENTS_MARITAL_STATUS');
    const parentsOccupations = value(facts, 'PARENTS_OCCUPATIONS');
    const familyIncome = value(facts, 'FAMILY_INCOME_INSURANCE');
    const housing = value(facts, 'HOUSING_DETAILS');
    const cookingWater = value(facts, 'COOKING_WATER_SANITATION');
    const latrines = value(facts, 'LATRINE_DETAILS');
    const householdSmoking = value(facts, 'HOUSEHOLD_SMOKING_ALCOHOL');
    const similarSymptoms = value(facts, 'HOUSEHOLD_SIMILAR_SYMPTOMS');

    if (birthOrder) {
      sentences.push(
        sentence(
          `The child is the ${ordinalText(birthOrder)} born in the family.`,
          'BIRTH_ORDER',
        ),
      );
    }

    if (siblings) {
      sentences.push(
        sentence(
          `Siblings: ${siblings}.`,
          'SIBLING_DETAILS',
        ),
      );
    }

    if (parentsMarital) {
      sentences.push(
        sentence(
          `Parents are ${parentsMarital === 'MARRIED' ? 'married' : parentsMarital === 'SEPARATED' ? 'separated' : parentsMarital === 'DIVORCED' ? 'divorced' : parentsMarital === 'DECEASED' ? 'deceased' : parentsMarital === 'UNMARRIED' ? 'unmarried' : normalizeCode(parentsMarital)}.`,
          'PARENTS_MARITAL_STATUS',
        ),
      );
    }

    if (parentsOccupations) {
      sentences.push(
        sentence(
          `Parents’ occupations: ${parentsOccupations}.`,
          'PARENTS_OCCUPATIONS',
        ),
      );
    }

    if (familyIncome) {
      sentences.push(
        sentence(
          `Family income/insurance status: ${familyIncome}.`,
          'FAMILY_INCOME_INSURANCE',
        ),
      );
    }

    if (housing) {
      sentences.push(
        sentence(
          `Housing: ${housing}.`,
          'HOUSING_DETAILS',
        ),
      );
    }

    if (cookingWater) {
      sentences.push(
        sentence(
          `Cooking, water and sanitation: ${cookingWater}.`,
          'COOKING_WATER_SANITATION',
        ),
      );
    }

    if (latrines) {
      sentences.push(
        sentence(
          `Latrine details: ${latrines}.`,
          'LATRINE_DETAILS',
        ),
      );
    }

    if (householdSmoking === 'yes' || householdSmoking === 'YES') {
      sentences.push(
        sentence(
          'There is smoking and/or alcohol use within the household.',
          'HOUSEHOLD_SMOKING_ALCOHOL',
        ),
      );
    } else if (householdSmoking === 'no' || householdSmoking === 'NO') {
      sentences.push(
        sentence(
          'There is no smoking or alcohol use within the household.',
          'HOUSEHOLD_SMOKING_ALCOHOL',
        ),
      );
    }

    if (similarSymptoms === 'yes' || similarSymptoms === 'YES') {
      sentences.push(
        sentence(
          'Similar symptoms are reported among other household members.',
          'HOUSEHOLD_SIMILAR_SYMPTOMS',
        ),
      );
    } else if (similarSymptoms === 'no' || similarSymptoms === 'NO') {
      sentences.push(
        sentence(
          'No similar symptoms are reported among other household members.',
          'HOUSEHOLD_SIMILAR_SYMPTOMS',
        ),
      );
    }
  }

  return section(
    'social_history',
    'Social History',
    sentences,
  );
}

// =============================================================================
// OCCUPATIONAL HISTORY
// =============================================================================

function compileOccupationalHistory(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const occupation = value(
    facts,
    'OCCUPATION',
  );

  const exposures = value(
    facts,
    'OCCUPATIONAL_EXPOSURES',
  );

  const sentences: DocumentationSentence[] = [];

  if (occupation) {
    sentences.push(
      sentence(
        `Occupation: ${occupation}.`,
        'OCCUPATION',
      ),
    );
  }

  if (exposures) {
    sentences.push(
      sentence(
        `Occupational/environmental exposures: ${exposures}.`,
        'OCCUPATIONAL_EXPOSURES',
      ),
    );
  }

  return section(
    'occupational_history',
    'Occupational History',
    sentences,
  );
}

// =============================================================================
// SEXUAL HISTORY
// =============================================================================

function compileSexualHistory(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const relevant = value(
    facts,
    'SEXUAL_HISTORY_RELEVANT',
  );

  const details = value(
    facts,
    'SEXUAL_HISTORY_DETAILS',
  );

  const sentences: DocumentationSentence[] = [];

  if (relevant === 'yes' || relevant === 'YES') {
    sentences.push(
      sentence(
        details
          ? details
          : 'Relevant sexual or reproductive history was reported.',
        details
          ? 'SEXUAL_HISTORY_DETAILS'
          : 'SEXUAL_HISTORY_RELEVANT',
      ),
    );
  } else if (relevant === 'no' || relevant === 'NO') {
    sentences.push(
      sentence(
        'No relevant sexual or reproductive history was reported.',
        'SEXUAL_HISTORY_RELEVANT',
      ),
    );
  }

  return section(
    'sexual_history',
    'Sexual History',
    sentences,
  );
}

// =============================================================================
// GYNAECOLOGICAL HISTORY
// =============================================================================

function compileGynaecologicalHistory(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (context.sex !== 'female') {
    return null;
  }

  if (
    context.ageYears == null ||
    context.ageYears < 12 ||
    context.ageYears > 55
  ) {
    return null;
  }

  const sentences: DocumentationSentence[] = [];

  const menarche = value(
    facts,
    'MENARCHE_AGE',
  );

  const lmp = value(
    facts,
    'LMP_DATE',
  );

  const cycle = value(
    facts,
    'MENSTRUAL_PATTERN',
  );

  const menstrualProblem = value(
    facts,
    'MENSTRUAL_PROBLEM_PRESENT',
  );

  const menstrualProblemDetails = value(
    facts,
    'MENSTRUAL_PROBLEM_DETAILS',
  );

  const menopausal = value(
    facts,
    'MENOPAUSAL_STATUS',
  );

  const postmenopausalYears = value(
    facts,
    'POSTMENOPAUSAL_YEARS',
  );

  const contraception = value(
    facts,
    'CONTRACEPTION_USE',
  );

  const contraceptionDetails = value(
    facts,
    'CONTRACEPTION_DETAILS',
  );

  const contraceptionSideEffects = value(
    facts,
    'CONTRACEPTION_SIDE_EFFECTS',
  );

  const flowDetails = value(
    facts,
    'MENSTRUAL_FLOW_DETAILS',
  );

  const sexualDebut = value(
    facts,
    'SEXUAL_DEBUT_AGE',
  );

  const cancerScreening = value(
    facts,
    'CANCER_SCREENING_HISTORY',
  );

  const stdHistory = value(
    facts,
    'STD_HISTORY',
  );

  const gynTreatments = value(
    facts,
    'GYNAECOLOGICAL_TREATMENTS',
  );

  if (menarche) {
    sentences.push(
      sentence(
        `Her menarche was at ${menarche} years.`,
        'MENARCHE_AGE',
      ),
    );
  }

  if (lmp) {
    sentences.push(
      sentence(
        `Her LNMP was recorded as ${lmp}.`,
        'LMP_DATE',
      ),
    );
  }

  if (cycle) {
    sentences.push(
      sentence(
        `Menstrual cycle: ${cycle}.`,
        'MENSTRUAL_PATTERN',
      ),
    );
  }

  if (flowDetails) {
    sentences.push(
      sentence(
        `Menstrual flow: ${flowDetails}.`,
        'MENSTRUAL_FLOW_DETAILS',
      ),
    );
  }

  if (menstrualProblem === 'yes' || menstrualProblem === 'YES') {
    sentences.push(
      sentence(
        menstrualProblemDetails
          ? `Menstrual problems: ${menstrualProblemDetails}.`
          : 'Significant menstrual problems were reported.',
        menstrualProblemDetails
          ? 'MENSTRUAL_PROBLEM_DETAILS'
          : 'MENSTRUAL_PROBLEM_PRESENT',
      ),
    );
  } else if (menstrualProblem === 'no' || menstrualProblem === 'NO') {
    sentences.push(
      sentence(
        'No significant menstrual problems such as heavy menstrual bleeding or dysmenorrhea were reported.',
        'MENSTRUAL_PROBLEM_PRESENT',
      ),
    );
  }

  if (menopauseStatusParagraph(facts)) {
    const paragraph = menopauseStatusParagraph(facts)!;
    sentences.push(
      sentence(
        paragraph,
        'MENOPAUSAL_STATUS',
      ),
    );
  } else if (menopausal) {
    sentences.push(
      sentence(
        menopausal === 'YES' || menopausal === 'yes'
          ? postmenopausalYears
            ? `She is a postmenopausal woman since the last ${postmenopausalYears} years.`
            : 'She has reached menopause.'
          : menopausal === 'NO' || menopausal === 'no'
            ? 'She has not yet reached menopause.'
            : normalizeCode(menopausal),
        'MENOPAUSAL_STATUS',
      ),
    );
  }

  if (isYes(facts, 'POSTMENOPAUSAL_BLEEDING')) {
    sentences.push(
      sentence(
        'There is postmenopausal bleeding.',
        'POSTMENOPAUSAL_BLEEDING',
      ),
    );
  } else if (isNo(facts, 'POSTMENOPAUSAL_BLEEDING')) {
    sentences.push(
      sentence(
        'There is no postmenopausal bleeding.',
        'POSTMENOPAUSAL_BLEEDING',
      ),
    );
  }

  if (contraception === 'yes' || contraception === 'YES') {
    sentences.push(
      sentence(
        contraceptionDetails
          ? `Contraception: ${contraceptionDetails}.`
          : 'The patient uses contraception.',
        contraceptionDetails
          ? 'CONTRACEPTION_DETAILS'
          : 'CONTRACEPTION_USE',
      ),
    );
  } else if (contraception === 'no' || contraception === 'NO') {
    sentences.push(
      sentence(
        'The patient does not currently use contraception.',
        'CONTRACEPTION_USE',
      ),
    );
  }

  if (contraceptionSideEffects) {
    sentences.push(
      sentence(
        `Contraceptive side effects reported: ${contraceptionSideEffects}.`,
        'CONTRACEPTION_SIDE_EFFECTS',
      ),
    );
  }

  if (isYes(facts, 'DYSPAREUNIA')) {
    sentences.push(
      sentence(
        'There is dyspareunia.',
        'DYSPAREUNIA',
      ),
    );
  } else if (isNo(facts, 'DYSPAREUNIA')) {
    sentences.push(
      sentence(
        'There is no dyspareunia.',
        'DYSPAREUNIA',
      ),
    );
  }

  if (isYes(facts, 'POSTCOITAL_BLEEDING')) {
    sentences.push(
      sentence(
        'There is post-coital bleeding.',
        'POSTCOITAL_BLEEDING',
      ),
    );
  } else if (isNo(facts, 'POSTCOITAL_BLEEDING')) {
    sentences.push(
      sentence(
        'There is no post-coital bleeding.',
        'POSTCOITAL_BLEEDING',
      ),
    );
  }

  if (sexualDebut) {
    sentences.push(
      sentence(
        `Sexual debut was at ${sexualDebut} years of age.`,
        'SEXUAL_DEBUT_AGE',
      ),
    );
  }

  if (cancerScreening) {
    sentences.push(
      sentence(
        `Cancer screening: ${cancerScreening}.`,
        'CANCER_SCREENING_HISTORY',
      ),
    );
  }

  if (stdHistory) {
    sentences.push(
      sentence(
        `History of sexually transmitted infections: ${stdHistory}.`,
        'STD_HISTORY',
      ),
    );
  }

  if (gynTreatments) {
    sentences.push(
      sentence(
        `Gynaecological treatments/operations: ${gynTreatments}.`,
        'GYNAECOLOGICAL_TREATMENTS',
      ),
    );
  }

  return section(
    'gynaecological_history',
    'Gynaecological History',
    sentences,
  );
}

/** Renders the postmenopausal status as a single structured sentence. */
function menopauseStatusParagraph(
  facts: ClinicalFact[],
): string | null {
  if (!isYes(facts, 'MENOPAUSAL_STATUS')) {
    return null;
  }

  const years = value(facts, 'POSTMENOPAUSAL_YEARS');

  if (years) {
    return `She is a postmenopausal woman since the last ${years} years.`;
  }

  return 'She is a postmenopausal woman.';
}

// =============================================================================
// OBSTETRIC HISTORY
// =============================================================================

function compileObstetricHistory(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (context.sex !== 'female') {
    return null;
  }

  if (
    context.ageYears == null ||
    context.ageYears < 12 ||
    context.ageYears > 55
  ) {
    return null;
  }

  const pregnancyStatus = value(
    facts,
    'PREGNANCY_STATUS',
  );

  const gravida = value(
    facts,
    'GRAVIDA',
  );

  const para = value(
    facts,
    'PARA',
  );

  const abortions = value(
    facts,
    'ABORTIONS',
  );

  const living = value(
    facts,
    'LIVING_CHILDREN',
  );

  const previousCS = value(
    facts,
    'PREVIOUS_CAESAREAN',
  );

  const outcomes = value(
    facts,
    'PREVIOUS_PREGNANCY_OUTCOMES',
  );

  const sentences: DocumentationSentence[] = [];

  if (pregnancyStatus) {
    const label =
      pregnancyStatus === 'YES' || pregnancyStatus === 'yes'
        ? 'currently pregnant'
        : pregnancyStatus === 'NO' || pregnancyStatus === 'no'
          ? 'not currently pregnant'
          : normalizeCode(pregnancyStatus);
    sentences.push(
      sentence(
        `Current pregnancy status: ${label}.`,
        'PREGNANCY_STATUS',
      ),
    );
  }

  if (gravida != null && gravida !== '') {
    sentences.push(
      sentence(
        `Gravidity: ${gravida}.`,
        'GRAVIDA',
      ),
    );
  }

  if (para != null && para !== '') {
    sentences.push(
      sentence(
        `Parity: ${para}.`,
        'PARA',
      ),
    );
  }

  if (abortions != null && abortions !== '' && Number(abortions) > 0) {
    sentences.push(
      sentence(
        `Previous abortions: ${abortions}.`,
        'ABORTIONS',
      ),
    );
  }

  if (living != null && living !== '') {
    sentences.push(
      sentence(
        `Living children: ${living}.`,
        'LIVING_CHILDREN',
      ),
    );
  }

  if (previousCS === 'yes' || previousCS === 'YES') {
    sentences.push(
      sentence(
        'There is a history of previous caesarean section.',
        'PREVIOUS_CAESAREAN',
      ),
    );
  }

  if (outcomes) {
    sentences.push(
      sentence(
        `Previous pregnancy outcomes: ${outcomes}.`,
        'PREVIOUS_PREGNANCY_OUTCOMES',
      ),
    );
  }

  const pregnancyRows = collectPregnancyRows(facts);

  for (const row of pregnancyRows) {
    sentences.push(
      sentence(
        buildPregnancyRowSentence(row),
        row.yearFactCode,
      ),
    );
  }

  return section(
    'obstetric_history',
    'Obstetric History',
    sentences,
  );
}

interface PregnancyRow {
  index: number;
  yearFactCode: string;
  year: string;
  gestationalAge: string | null;
  mode: string | null;
  location: string | null;
  birthWeight: string | null;
  sex: string | null;
  fate: string | null;
  complications: string | null;
}

function collectPregnancyRows(
  facts: ClinicalFact[],
): PregnancyRow[] {
  const rows: PregnancyRow[] = [];

  for (let i = 1; i <= 5; i += 1) {
    const year = value(facts, `OB_PREGNANCY_${i}_YEAR`);

    if (!year) {
      continue;
    }

    rows.push({
      index: i,
      yearFactCode: `OB_PREGNANCY_${i}_YEAR`,
      year,
      gestationalAge: value(
        facts,
        `OB_PREGNANCY_${i}_GA`,
      ),
      mode: value(
        facts,
        `OB_PREGNANCY_${i}_MODE`,
      ),
      location: value(
        facts,
        `OB_PREGNANCY_${i}_LOCATION`,
      ),
      birthWeight: value(
        facts,
        `OB_PREGNANCY_${i}_BIRTH_WEIGHT`,
      ),
      sex: value(
        facts,
        `OB_PREGNANCY_${i}_SEX`,
      ),
      fate: value(
        facts,
        `OB_PREGNANCY_${i}_FATE`,
      ),
      complications: value(
        facts,
        `OB_PREGNANCY_${i}_COMPLICATIONS`,
      ),
    });
  }

  return rows;
}

function buildPregnancyRowSentence(
  row: PregnancyRow,
): string {
  const parts: string[] = [];

  parts.push(`Pregnancy ${row.index}: ${row.year}`);
  parts.push(
    `GA at delivery ${row.gestationalAge || 'not recorded'}`,
  );
  parts.push(
    `mode of delivery ${row.mode || 'not recorded'}`,
  );

  if (row.location) {
    parts.push(`delivered at ${row.location}`);
  }

  if (row.birthWeight) {
    parts.push(`birth weight ${row.birthWeight}`);
  }

  if (row.sex) {
    parts.push(`sex ${row.sex}`);
  }

  if (row.fate) {
    parts.push(`fate ${row.fate}`);
  }

  if (row.complications) {
    parts.push(`complications: ${row.complications}`);
  }

  return `${parts.join('; ')}.`;
}

// =============================================================================
// ANC PROFILE
// =============================================================================

function compileANCProfile(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (
    context.sex !== 'female' ||
    context.pregnancyState !== 'pregnant'
  ) {
    return null;
  }

  const sentences: DocumentationSentence[] = [];

  const gestationalAge = value(
    facts,
    'GESTATIONAL_AGE',
  );

  const edd = value(
    facts,
    'EDD',
  );

  const ancReceived = value(
    facts,
    'ANC_RECEIVED',
  );

  const ancVisits = value(
    facts,
    'ANC_VISITS',
  );

  const complications = value(
    facts,
    'CURRENT_PREGNANCY_COMPLICATIONS',
  );

  const tetanus = value(
    facts,
    'ANC_TETANUS_STATUS',
  );

  const supplements = value(
    facts,
    'ANC_SUPPLEMENT_USE',
  );

  const firstVisit = value(
    facts,
    'ANC_FIRST_VISIT_DETAILS',
  );

  const bloodGroup = value(
    facts,
    'ANC_BLOOD_GROUP',
  );

  const hbStatus = value(
    facts,
    'ANC_HB_STATUS',
  );

  const urineNormal = value(
    facts,
    'ANC_URINE_TEST_NORMAL',
  );

  const hivResult = value(
    facts,
    'ANC_HIV_RESULT',
  );

  const vdrlResult = value(
    facts,
    'ANC_VDRL_RESULT',
  );

  const hepBResult = value(
    facts,
    'ANC_HEPATITIS_B_RESULT',
  );

  const tbScreen = value(
    facts,
    'ANC_TB_SCREENING',
  );

  const deworming = value(
    facts,
    'ANC_DEWORMING',
  );

  const bpNormal = value(
    facts,
    'ANC_BP_NORMAL',
  );

  const ultrasound = value(
    facts,
    'ANC_ULTRASOUND_DETAILS',
  );

  const acuteIllnesses = value(
    facts,
    'ANC_ACUTE_ILLNESSES',
  );

  const medicationUse = value(
    facts,
    'ANC_MEDICATION_USE',
  );

  const malariaProphylaxis = value(
    facts,
    'ANC_MALARIA_PROPHYLAXIS',
  );

  if (gestationalAge) {
    sentences.push(
      sentence(
        `Her gestational age by dates is ${gestationalAge} weeks.`,
        'GESTATIONAL_AGE',
      ),
    );
  }

  if (edd) {
    sentences.push(
      sentence(
        `The expected date of delivery is/was ${edd}.`,
        'EDD',
      ),
    );
  }

  if (ancReceived === 'yes' || ancReceived === 'YES') {
    sentences.push(
      sentence(
        ancVisits != null && ancVisits !== ''
          ? `During this pregnancy she has attended ${ancVisits} antenatal clinics.`
          : 'The patient has received antenatal care during this pregnancy.',
        ancVisits != null && ancVisits !== ''
          ? 'ANC_VISITS'
          : 'ANC_RECEIVED',
      ),
    );
  } else if (ancReceived === 'no' || ancReceived === 'NO') {
    sentences.push(
      sentence(
        'The patient has not attended antenatal care during this pregnancy.',
        'ANC_RECEIVED',
      ),
    );
  }

  if (firstVisit) {
    sentences.push(
      sentence(
        `Her first ANC visit was ${normalizeCode(firstVisit)}.`,
        'ANC_FIRST_VISIT_DETAILS',
      ),
    );
  }

  if (bloodGroup) {
    sentences.push(
      sentence(
        `Her blood group is ${normalizeCode(bloodGroup)}.`,
        'ANC_BLOOD_GROUP',
      ),
    );
  }

  if (hbStatus) {
    const hbLabel =
      hbStatus === 'ADEQUATE'
        ? 'Her level of blood (Hb) was reported as adequate.'
        : hbStatus === 'INADEQUATE'
          ? 'Her level of blood (Hb) was reported as inadequate.'
          : hbStatus === 'NOT_DONE'
            ? 'No haemoglobin result was reported.'
            : `Hb status: ${normalizeCode(hbStatus)}.`;
    sentences.push(
      sentence(hbLabel, 'ANC_HB_STATUS'),
    );
  }

  if (urineNormal === 'yes' || urineNormal === 'YES') {
    sentences.push(
      sentence(
        'The urinary test was reported as normal.',
        'ANC_URINE_TEST_NORMAL',
      ),
    );
  } else if (urineNormal === 'no' || urineNormal === 'NO') {
    sentences.push(
      sentence(
        'The urinary test was reported as abnormal.',
        'ANC_URINE_TEST_NORMAL',
      ),
    );
  }

  if (hivResult) {
    const label =
      hivResult === 'NEGATIVE'
        ? 'The P24 markers for HIV were negative.'
        : hivResult === 'POSITIVE'
          ? 'The P24 markers for HIV were positive.'
          : hivResult === 'NOT_DONE'
            ? 'HIV testing was not done.'
            : `HIV status: ${normalizeCode(hivResult)}.`;
    sentences.push(
      sentence(label, 'ANC_HIV_RESULT'),
    );
  }

  if (vdrlResult) {
    const label =
      vdrlResult === 'NEGATIVE'
        ? 'The VDRL test for syphilis was negative.'
        : vdrlResult === 'POSITIVE'
          ? 'The VDRL test for syphilis was positive.'
          : vdrlResult === 'NOT_DONE'
            ? 'VDRL testing was not done.'
            : `VDRL status: ${normalizeCode(vdrlResult)}.`;
    sentences.push(
      sentence(label, 'ANC_VDRL_RESULT'),
    );
  }

  if (hepBResult) {
    const label =
      hepBResult === 'NEGATIVE'
        ? 'Hepatitis B screening was negative.'
        : hepBResult === 'POSITIVE'
          ? 'Hepatitis B screening was positive.'
          : hepBResult === 'NOT_DONE'
            ? 'Hepatitis B screening was not done.'
            : `Hepatitis B status: ${normalizeCode(hepBResult)}.`;
    sentences.push(
      sentence(label, 'ANC_HEPATITIS_B_RESULT'),
    );
  }

  if (tbScreen) {
    const label =
      tbScreen === 'DONE_NORMAL'
        ? 'TB screening was done and reported normal.'
        : tbScreen === 'DONE_ABNORMAL'
          ? 'TB screening was done and flagged for further review.'
          : tbScreen === 'NOT_DONE'
            ? 'TB screening was not done.'
            : `TB screening: ${normalizeCode(tbScreen)}.`;
    sentences.push(
      sentence(label, 'ANC_TB_SCREENING'),
    );
  }

  if (tetanus === 'yes' || tetanus === 'YES') {
    sentences.push(
      sentence(
        'Tetanus toxoid vaccination was given.',
        'ANC_TETANUS_STATUS',
      ),
    );
  } else if (tetanus === 'no' || tetanus === 'NO') {
    sentences.push(
      sentence(
        'Tetanus toxoid vaccination was not given.',
        'ANC_TETANUS_STATUS',
      ),
    );
  }

  if (deworming === 'yes' || deworming === 'YES') {
    sentences.push(
      sentence(
        'She was dewormed during the second trimester.',
        'ANC_DEWORMING',
      ),
    );
  } else if (deworming === 'no' || deworming === 'NO') {
    sentences.push(
      sentence(
        'She was not dewormed during the second trimester.',
        'ANC_DEWORMING',
      ),
    );
  }

  if (bpNormal === 'yes' || bpNormal === 'YES') {
    sentences.push(
      sentence(
        'Blood pressure taken at antenatal visits was normal.',
        'ANC_BP_NORMAL',
      ),
    );
  } else if (bpNormal === 'no' || bpNormal === 'NO') {
    sentences.push(
      sentence(
        'Blood pressure taken at antenatal visits was abnormal.',
        'ANC_BP_NORMAL',
      ),
    );
  }

  if (ultrasound) {
    sentences.push(
      sentence(
        `Ultrasound scans: ${ultrasound}.`,
        'ANC_ULTRASOUND_DETAILS',
      ),
    );
  }

  if (supplements === 'yes' || supplements === 'YES') {
    sentences.push(
      sentence(
        'Iron and folate supplements were taken.',
        'ANC_SUPPLEMENT_USE',
      ),
    );
  } else if (supplements === 'no' || supplements === 'NO') {
    sentences.push(
      sentence(
        'Iron and folate supplements were not taken.',
        'ANC_SUPPLEMENT_USE',
      ),
    );
  }

  if (complications) {
    sentences.push(
      sentence(
        `Complications in the current pregnancy: ${complications}.`,
        'CURRENT_PREGNANCY_COMPLICATIONS',
      ),
    );
  }

  if (acuteIllnesses) {
    sentences.push(
      sentence(
        `Acute illnesses during pregnancy: ${acuteIllnesses}.`,
        'ANC_ACUTE_ILLNESSES',
      ),
    );
  }

  if (medicationUse) {
    sentences.push(
      sentence(
        `Medication use during pregnancy: ${medicationUse}.`,
        'ANC_MEDICATION_USE',
      ),
    );
  }

  if (malariaProphylaxis) {
    const label =
      malariaProphylaxis === 'IPT_AND_LLIN'
        ? 'She used IPT (malarial prophylaxis) and a long-lasting insecticide-treated net.'
        : malariaProphylaxis === 'IPT_ONLY'
          ? 'She used IPT (malarial prophylaxis).'
          : malariaProphylaxis === 'LLIN_ONLY'
            ? 'She used a long-lasting insecticide-treated net.'
            : malariaProphylaxis === 'NONE'
              ? 'She did not use malarial prophylaxis or a treated net.'
              : `Malaria prophylaxis: ${normalizeCode(malariaProphylaxis)}.`;
    sentences.push(
      sentence(label, 'ANC_MALARIA_PROPHYLAXIS'),
    );
  }

  // "8 things you must ask a pregnant woman"
  const ancRedFlags: Array<{
    factCode: string;
    yesText: string;
    noText: string;
  }> = [
    {
      factCode: 'ANC_LOWER_ABDOMINAL_PAIN',
      yesText: 'She has lower abdominal pain.',
      noText: 'She has no lower abdominal pain.',
    },
    {
      factCode: 'ANC_LOWER_BACK_PAIN',
      yesText: 'She has lower back pain.',
      noText: 'She has no lower back pain.',
    },
    {
      factCode: 'ANC_PV_BLEEDING',
      yesText: 'She reports leakage of blood per vagina.',
      noText: 'She reports no leakage of blood per vagina.',
    },
    {
      factCode: 'ANC_SUDDEN_GUSH_LIQUID',
      yesText: 'She reports a sudden gush of liquid from the vagina, suggesting possible membrane rupture.',
      noText: 'She reports no sudden gush of liquid from the vagina.',
    },
    {
      factCode: 'ANC_VAGINAL_DISCHARGE',
      yesText: 'She reports abnormal vaginal discharge.',
      noText: 'She reports no abnormal vaginal discharge.',
    },
    {
      factCode: 'ANC_FETAL_MOVEMENT',
      yesText: 'She perceives fetal movement.',
      noText: 'She does not perceive fetal movement.',
    },
    {
      factCode: 'ANC_HEADACHE',
      yesText: 'She has headaches.',
      noText: 'She has no headaches.',
    },
    {
      factCode: 'ANC_BLURRED_VISION',
      yesText: 'She reports blurring of vision.',
      noText: 'She reports no blurring of vision.',
    },
  ];

  for (const flag of ancRedFlags) {
    if (isYes(facts, flag.factCode)) {
      sentences.push(
        sentence(flag.yesText, flag.factCode),
      );
    } else if (isNo(facts, flag.factCode)) {
      sentences.push(
        sentence(flag.noText, flag.factCode),
      );
    }
  }

  return section(
    'anc_profile',
    'ANC Profile',
    sentences,
  );
}

// =============================================================================
// BIRTH HISTORY
// =============================================================================

function compileBirthHistory(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (
    ![
      'neonate',
      'infant',
      'child',
      'adolescent',
    ].includes(context.lifeStage)
  ) {
    return null;
  }

  const sentences: DocumentationSentence[] = [];

  const place = value(
    facts,
    'BIRTH_PLACE',
  );

  const birthMode = value(
    facts,
    'BIRTH_MODE',
  );

  const birthWeight = value(
    facts,
    'BIRTH_WEIGHT',
  );

  const gestationalAge = value(
    facts,
    'BIRTH_GESTATIONAL_AGE',
  );

  const complications = value(
    facts,
    'BIRTH_COMPLICATIONS',
  );

  if (birthMode) {
    sentences.push(
      sentence(
        `Delivery was by ${normalizeCode(birthMode)}.`,
        'BIRTH_MODE',
      ),
    );
  }

  if (place) {
    sentences.push(
      sentence(
        `The child was delivered at ${normalizeCode(place)}.`,
        'BIRTH_PLACE',
      ),
    );
  }

  if (birthWeight) {
    sentences.push(
      sentence(
        `Birth weight was ${birthWeight}.`,
        'BIRTH_WEIGHT',
      ),
    );
  }

  if (gestationalAge) {
    sentences.push(
      sentence(
        `Gestational age at birth was ${gestationalAge}.`,
        'BIRTH_GESTATIONAL_AGE',
      ),
    );
  }

  if (isYes(facts, 'BIRTH_RESUSCITATION')) {
    sentences.push(
      sentence(
        'The child required resuscitation or significant support at birth.',
        'BIRTH_RESUSCITATION',
      ),
    );
  } else if (isNo(facts, 'BIRTH_RESUSCITATION')) {
    sentences.push(
      sentence(
        'No resuscitation was required at birth.',
        'BIRTH_RESUSCITATION',
      ),
    );
  }

  if (isYes(facts, 'BIRTH_CRIED_IMMEDIATELY')) {
    sentences.push(
      sentence(
        'The child cried immediately after birth.',
        'BIRTH_CRIED_IMMEDIATELY',
      ),
    );
  } else if (isNo(facts, 'BIRTH_CRIED_IMMEDIATELY')) {
    sentences.push(
      sentence(
        'The child did not cry immediately after birth.',
        'BIRTH_CRIED_IMMEDIATELY',
      ),
    );
  }

  if (isYes(facts, 'BIRTH_BREASTFED_EARLY')) {
    sentences.push(
      sentence(
        'The child was breastfed early (within the first hour).',
        'BIRTH_BREASTFED_EARLY',
      ),
    );
  } else if (isNo(facts, 'BIRTH_BREASTFED_EARLY')) {
    sentences.push(
      sentence(
        'The child was not breastfed early (within the first hour).',
        'BIRTH_BREASTFED_EARLY',
      ),
    );
  }

  if (isYes(facts, 'BIRTH_NICU_ADMISSION')) {
    sentences.push(
      sentence(
        'The child was admitted to the neonatal unit after birth.',
        'BIRTH_NICU_ADMISSION',
      ),
    );
  } else if (isNo(facts, 'BIRTH_NICU_ADMISSION')) {
    sentences.push(
      sentence(
        'The child was not admitted to the neonatal unit after birth.',
        'BIRTH_NICU_ADMISSION',
      ),
    );
  }

  if (isYes(facts, 'BIRTH_POSTNATAL_ILLNESS')) {
    sentences.push(
      sentence(
        'There was significant illness in the postnatal period.',
        'BIRTH_POSTNATAL_ILLNESS',
      ),
    );
  } else if (isNo(facts, 'BIRTH_POSTNATAL_ILLNESS')) {
    sentences.push(
      sentence(
        'There was no significant illness in the postnatal period.',
        'BIRTH_POSTNATAL_ILLNESS',
      ),
    );
  }

  if (complications) {
    sentences.push(
      sentence(
        `Birth complications: ${complications}.`,
        'BIRTH_COMPLICATIONS',
      ),
    );
  }

  const maternalAnc = value(
    facts,
    'MATERNAL_ANC_ATTENDANCE',
  );

  const maternalProfile = value(
    facts,
    'MATERNAL_ANC_PROFILE',
  );

  const maternalIllnesses = value(
    facts,
    'MATERNAL_ILLNESSES',
  );

  const maternalHiv = value(
    facts,
    'MATERNAL_HIV_STATUS',
  );

  const maternalDrugs = value(
    facts,
    'MATERNAL_DRUGS',
  );

  if (maternalAnc === 'yes' || maternalAnc === 'YES') {
    sentences.push(
      sentence(
        maternalProfile
          ? `The mother attended antenatal care. Antenatal profile: ${maternalProfile}.`
          : 'The mother attended antenatal care during this pregnancy.',
        maternalProfile
          ? 'MATERNAL_ANC_PROFILE'
          : 'MATERNAL_ANC_ATTENDANCE',
      ),
    );
  } else if (maternalAnc === 'no' || maternalAnc === 'NO') {
    sentences.push(
      sentence(
        'The mother did not attend antenatal care during this pregnancy.',
        'MATERNAL_ANC_ATTENDANCE',
      ),
    );
  }

  if (maternalIllnesses) {
    sentences.push(
      sentence(
        `Maternal illnesses during pregnancy: ${maternalIllnesses}.`,
        'MATERNAL_ILLNESSES',
      ),
    );
  }

  if (maternalHiv) {
    const label =
      maternalHiv === 'NEGATIVE'
        ? 'The mother’s HIV status was reported as negative.'
        : maternalHiv === 'POSITIVE'
          ? 'The mother’s HIV status was reported as positive.'
          : 'The mother’s HIV status was unknown.';
    sentences.push(
      sentence(label, 'MATERNAL_HIV_STATUS'),
    );
  }

  if (maternalDrugs) {
    sentences.push(
      sentence(
        `Maternal medication, substance or radiation exposure during pregnancy: ${maternalDrugs}.`,
        'MATERNAL_DRUGS',
      ),
    );
  }

  return section(
    'birth_history',
    'Birth History',
    sentences,
  );
}

// =============================================================================
// GROWTH & DEVELOPMENT
// =============================================================================

function compileGrowthDevelopment(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (
    ![
      'neonate',
      'infant',
      'child',
      'adolescent',
    ].includes(context.lifeStage) ||
    context.lifeStage === 'neonate'
  ) {
    return null;
  }

  const globalStatus = value(
    facts,
    'DEVELOPMENTAL_STATUS',
  );

  const concerns = value(
    facts,
    'DEVELOPMENTAL_CONCERNS',
  );

  const deductions = evaluateMilestones(facts);
  const hasEvidence = hasMilestoneEvidence(deductions);

  const sentences: DocumentationSentence[] = [];

  if (globalStatus) {
    const label =
      globalStatus === 'APPROPRIATE'
        ? 'Development is reported as appropriate for age.'
        : globalStatus === 'DELAYED'
          ? 'Development is reported as possibly delayed.'
          : globalStatus === 'REGRESSION'
            ? 'Loss of previously acquired developmental skills was reported.'
            : `Developmental status: ${normalizeCode(globalStatus)}.`;
    sentences.push(
      sentence(label, 'DEVELOPMENTAL_STATUS'),
    );
  }

  if (concerns) {
    sentences.push(
      sentence(
        `Developmental concerns: ${concerns}.`,
        'DEVELOPMENTAL_CONCERNS',
      ),
    );
  }

  if (hasEvidence) {
    const achieved = deductions.filter(
      (item) => item.status === 'achieved',
    );

    if (achieved.length > 0) {
      const labels = achieved.map((item) => item.label);
      const prefix = labels.length === 1
        ? 'The child has achieved'
        : 'The child has achieved';
      sentences.push(
        sentence(
          `${prefix} ${labels.join('; ')}.`,
          achieved[0].code,
        ),
      );
    }

    // Deductions: only for milestones clearly past their latest window that
    // were explicitly answered "not yet".
    const currentMonths = ageInMonths(context);
    const delayed = deductions.filter(
      (item) =>
        item.status === 'not_achieved' &&
        currentMonths != null &&
        item.latestAgeMonths <= currentMonths,
    );

    if (delayed.length > 0) {
      const byDomain = new Map<string, string[]>();

      for (const item of delayed) {
        const domainLabel =
          MILESTONE_DOMAIN_LABELS[item.domain];
        const list = byDomain.get(domainLabel) ?? [];
        list.push(item.label);
        byDomain.set(domainLabel, list);
      }

      const fragments = Array.from(byDomain.entries()).map(
        ([domain, list]) => `${domain}: ${list.join('; ')}`,
      );

      sentences.push(
        sentence(
          `Not yet achieved (expected by ${delayed[0].latestAgeMonths} months): ${fragments.join('; ')}. This may indicate a developmental delay and warrants assessment.`,
          delayed[0].code,
        ),
      );
    }
  }

  if (sentences.length === 0) {
    return null;
  }

  return section(
    'growth_development',
    'Growth & Development',
    sentences,
  );
}

// =============================================================================
// IMMUNIZATION
// =============================================================================

function compileImmunization(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (
    ![
      'neonate',
      'infant',
      'child',
      'adolescent',
    ].includes(context.lifeStage)
  ) {
    return null;
  }

  const status = value(
    facts,
    'IMMUNIZATION_STATUS',
  );

  const details = value(
    facts,
    'IMMUNIZATION_DETAILS',
  );

  const nextVaccine = value(
    facts,
    'IMMUNIZATION_NEXT_VACCINE',
  );

  const sentences: DocumentationSentence[] = [];

  if (status) {
    const label =
      status === 'UP_TO_DATE'
        ? 'Immunizations are up to date according to the schedule.'
        : status === 'INCOMPLETE'
          ? 'Immunizations are incomplete.'
          : `Immunization status: ${normalizeCode(status)}.`;
    sentences.push(
      sentence(label, 'IMMUNIZATION_STATUS'),
    );
  }

  if (details) {
    sentences.push(
      sentence(
        `Vaccines missing or overdue: ${details}.`,
        'IMMUNIZATION_DETAILS',
      ),
    );
  }

  if (nextVaccine) {
    sentences.push(
      sentence(
        `The next vaccine due is ${nextVaccine}.`,
        'IMMUNIZATION_NEXT_VACCINE',
      ),
    );
  }

  return section(
    'immunization',
    'Immunization',
    sentences,
  );
}

// =============================================================================
// NUTRITION
// =============================================================================

function compileNutrition(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (
    ![
      'neonate',
      'infant',
      'child',
      'adolescent',
    ].includes(context.lifeStage)
  ) {
    return null;
  }

  const sentences: DocumentationSentence[] = [];

  const feeding = value(
    facts,
    'FEEDING_STATUS',
  );

  const method = value(
    facts,
    'FEEDING_METHOD',
  );

  const change = value(
    facts,
    'RECENT_NUTRITION_CHANGE',
  );

  const ebfMonths = value(
    facts,
    'EXCLUSIVE_BREASTFEEDING_MONTHS',
  );

  const complementaryAge = value(
    facts,
    'COMPLEMENTARY_FEEDING_MONTHS',
  );

  const feedContent = value(
    facts,
    'FEED_CONTENT_DETAILS',
  );

  const recall24 = value(
    facts,
    'FEEDING_24HR_RECALL',
  );

  const mealsPerDay = value(
    facts,
    'MEALS_PER_DAY',
  );

  if (feeding) {
    sentences.push(
      sentence(
        `Feeding is ${normalizeCode(feeding)} compared with usual.`,
        'FEEDING_STATUS',
      ),
    );
  }

  if (method) {
    sentences.push(
      sentence(
        `The child is fed by ${normalizeCode(method)}.`,
        'FEEDING_METHOD',
      ),
    );
  }

  if (ebfMonths) {
    sentences.push(
      sentence(
        `The child was exclusively breastfed for ${ebfMonths} months.`,
        'EXCLUSIVE_BREASTFEEDING_MONTHS',
      ),
    );
  }

  if (complementaryAge) {
    sentences.push(
      sentence(
        `Complementary foods were started at ${complementaryAge} months of age.`,
        'COMPLEMENTARY_FEEDING_MONTHS',
      ),
    );
  }

  if (feedContent) {
    sentences.push(
      sentence(
        `Feed content and quantity/frequency: ${feedContent}.`,
        'FEED_CONTENT_DETAILS',
      ),
    );
  }

  if (mealsPerDay) {
    sentences.push(
      sentence(
        `The child eats ${mealsPerDay} meals per day.`,
        'MEALS_PER_DAY',
      ),
    );
  }

  if (recall24) {
    sentences.push(
      sentence(
        `24-hour dietary recall: ${recall24}.`,
        'FEEDING_24HR_RECALL',
      ),
    );
  }

  if (isYes(facts, 'RETAINS_FEED')) {
    sentences.push(
      sentence(
        'The child retains feeds without vomiting.',
        'RETAINS_FEED',
      ),
    );
  } else if (isNo(facts, 'RETAINS_FEED')) {
    sentences.push(
      sentence(
        'The child vomits or fails to retain feeds.',
        'RETAINS_FEED',
      ),
    );
  }

  if (isYes(facts, 'PED_BOWEL_BLADDER_NORMAL')) {
    sentences.push(
      sentence(
        'Bowel and bladder habits are reported as normal.',
        'PED_BOWEL_BLADDER_NORMAL',
      ),
    );
  } else if (isNo(facts, 'PED_BOWEL_BLADDER_NORMAL')) {
    sentences.push(
      sentence(
        'Bowel or bladder habits are reported as abnormal.',
        'PED_BOWEL_BLADDER_NORMAL',
      ),
    );
  }

  if (change) {
    sentences.push(
      sentence(
        change,
        'RECENT_NUTRITION_CHANGE',
      ),
    );
  }

  return section(
    'nutrition',
    'Nutrition',
    sentences,
  );
}

// =============================================================================
// PSYCHIATRIC HISTORY
// =============================================================================

function compilePsychiatricHistory(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (context.department !== 'psychiatry') {
    return null;
  }

  const presentation = value(
    facts,
    'PSYCHIATRIC_PRESENTATION',
  );

  const history = value(
    facts,
    'PSYCHIATRIC_HISTORY',
  );

  const impact = value(
    facts,
    'PSYCHIATRIC_FUNCTIONAL_IMPACT',
  );

  const suicidal = value(
    facts,
    'SUICIDAL_IDEATION',
  );

  const sentences: DocumentationSentence[] = [];

  if (presentation) {
    sentences.push(
      sentence(
        presentation,
        'PSYCHIATRIC_PRESENTATION',
      ),
    );
  }

  if (history) {
    sentences.push(
      sentence(
        history,
        'PSYCHIATRIC_HISTORY',
      ),
    );
  }

  if (impact) {
    sentences.push(
      sentence(
        impact,
        'PSYCHIATRIC_FUNCTIONAL_IMPACT',
      ),
    );
  }

  if (suicidal === 'yes' || suicidal === 'YES') {
    sentences.push(
      sentence(
        'Current suicidal ideation was reported and requires immediate review.',
        'SUICIDAL_IDEATION',
      ),
    );
  } else if (suicidal === 'no' || suicidal === 'NO') {
    sentences.push(
      sentence(
        'No current suicidal or self-harm ideation was reported.',
        'SUICIDAL_IDEATION',
      ),
    );
  }

  return section(
    'psychiatric_history',
    'Psychiatric History',
    sentences,
  );
}

// =============================================================================
// SUBSTANCE HISTORY
// =============================================================================

function compileSubstanceHistory(
  _context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const present = value(
    facts,
    'SUBSTANCE_USE_PRESENT',
  );

  const substance = value(
    facts,
    'SUBSTANCE_HISTORY',
  );

  const sentences: DocumentationSentence[] = [];

  if (present === 'yes' || present === 'YES') {
    sentences.push(
      sentence(
        substance
          ? `Substance use: ${substance}.`
          : 'Substance use relevant to the presentation was reported.',
        substance
          ? 'SUBSTANCE_HISTORY'
          : 'SUBSTANCE_USE_PRESENT',
      ),
    );
  } else if (present === 'no' || present === 'NO') {
    sentences.push(
      sentence(
        'No current or recent substance use was reported.',
        'SUBSTANCE_USE_PRESENT',
      ),
    );
  }

  return section(
    'substance_history',
    'Substance History',
    sentences,
  );
}

// =============================================================================
// COLLATERAL HISTORY
// =============================================================================

function compileCollateralHistory(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  if (context.department !== 'psychiatry') {
    return null;
  }

  const available = value(
    facts,
    'COLLATERAL_AVAILABLE',
  );

  const collateral = value(
    facts,
    'COLLATERAL_HISTORY',
  );

  const sentences: DocumentationSentence[] = [];

  if (available === 'yes' || available === 'YES') {
    sentences.push(
      sentence(
        collateral
          ? collateral
          : 'Collateral information was available and reviewed.',
        collateral
          ? 'COLLATERAL_HISTORY'
          : 'COLLATERAL_AVAILABLE',
      ),
    );
  } else if (available === 'no' || available === 'NO') {
    sentences.push(
      sentence(
        'No collateral history was available.',
        'COLLATERAL_AVAILABLE',
      ),
    );
  }

  return section(
    'collateral_history',
    'Collateral / Informant History',
    sentences,
  );
}

// =============================================================================
// REVIEW OF SYSTEMS
//
// RULE:
// Systems already explored through the chief complaints / HPI are NOT
// re-asked here, so the documented ROS can never contradict the HPI.
// (e.g. if vomiting was captured in the HPI, "no vomiting" cannot appear in
// the ROS.)
// =============================================================================

const ROS_SYSTEMS: {
  system: ComplaintSystem;
  factCode: string;
  detailsFactCode: string;
  label: string;
}[] = [
  {
    system: 'general',
    factCode: 'ADDITIONAL_SYSTEM_SYMPTOMS',
    detailsFactCode: 'ADDITIONAL_SYSTEM_SYMPTOM_DETAILS',
    label: 'General',
  },
  {
    system: 'respiratory',
    factCode: 'ROS_RESPIRATORY',
    detailsFactCode: 'ROS_RESPIRATORY_DETAILS',
    label: 'Respiratory',
  },
  {
    system: 'cardiovascular',
    factCode: 'ROS_CARDIOVASCULAR',
    detailsFactCode: 'ROS_CARDIOVASCULAR_DETAILS',
    label: 'Cardiovascular',
  },
  {
    system: 'gastrointestinal',
    factCode: 'ROS_GASTROINTESTINAL',
    detailsFactCode: 'ROS_GASTROINTESTINAL_DETAILS',
    label: 'Gastrointestinal',
  },
  {
    system: 'neurological',
    factCode: 'ROS_NEUROLOGICAL',
    detailsFactCode: 'ROS_NEUROLOGICAL_DETAILS',
    label: 'Neurological',
  },
  {
    system: 'musculoskeletal',
    factCode: 'ROS_MUSCULOSKELETAL',
    detailsFactCode: 'ROS_MUSCULOSKELETAL_DETAILS',
    label: 'Musculoskeletal',
  },
  {
    system: 'genitourinary',
    factCode: 'ROS_GENITOURINARY',
    detailsFactCode: 'ROS_GENITOURINARY_DETAILS',
    label: 'Genitourinary',
  },
  {
    system: 'dermatological',
    factCode: 'ROS_DERMATOLOGICAL',
    detailsFactCode: 'ROS_DERMATOLOGICAL_DETAILS',
    label: 'Dermatological',
  },
  {
    system: 'head_ent',
    factCode: 'ROS_HEAD_ENT',
    detailsFactCode: 'ROS_HEAD_ENT_DETAILS',
    label: 'Head, ears, nose & throat',
  },
  {
    system: 'ophthalmological',
    factCode: 'ROS_OPHTHALMOLOGICAL',
    detailsFactCode: 'ROS_OPHTHALMOLOGICAL_DETAILS',
    label: 'Ophthalmological',
  },
  {
    system: 'endocrine',
    factCode: 'ROS_ENDOCRINE',
    detailsFactCode: 'ROS_ENDOCRINE_DETAILS',
    label: 'Endocrine',
  },
  {
    system: 'psychiatric',
    factCode: 'ROS_PSYCHIATRIC',
    detailsFactCode: 'ROS_PSYCHIATRIC_DETAILS',
    label: 'Psychiatric',
  },
  {
    system: 'haematological',
    factCode: 'ROS_HAEMATOLOGICAL',
    detailsFactCode: 'ROS_HAEMATOLOGICAL_DETAILS',
    label: 'Haematological',
  },
  {
    system: 'lymphatic',
    factCode: 'ROS_LYMPHATIC',
    detailsFactCode: 'ROS_LYMPHATIC_DETAILS',
    label: 'Lymphatic',
  },
];

function compileReviewOfSystems(
  facts: ClinicalFact[],
): DocumentationSection | null {
  const sentences: DocumentationSentence[] = [];

  if (hasChiefComplaints(facts)) {
    const covered = coveredComplaintSystems(facts);

    // Systems reviewed in HPI are recorded once and never repeated here.
    if (covered.length > 0) {
      const labels = covered.map(
        (system) =>
          COMPLAINT_SYSTEM_LABELS[system] ?? system,
      );

      sentences.push(
        sentence(
          `${labels.join(', ')} system(s) reviewed as part of the chief complaint and history of present illness and not repeated here.`,
          'CHIEF_COMPLAINT_ORDER',
        ),
      );
    }

    // Uncovered systems are probed here.
    for (const entry of ROS_SYSTEMS) {
      if (
        covered.includes(entry.system)
      ) {
        continue;
      }

      const details = value(
        facts,
        entry.detailsFactCode,
      );

      if (isYes(facts, entry.factCode)) {
        sentences.push(
          sentence(
            details
              ? `${entry.label} system: ${details}.`
              : `${entry.label} system symptoms were reported.`,
            entry.detailsFactCode,
          ),
        );
      } else if (isNo(facts, entry.factCode)) {
        sentences.push(
          sentence(
            `No ${entry.label.toLowerCase()} symptoms were reported.`,
            entry.factCode,
          ),
        );
      }
    }
  } else {
    const ros = value(
      facts,
      'REVIEW_OF_SYSTEMS',
    );

    if (isYes(facts, 'ADDITIONAL_SYSTEM_SYMPTOMS')) {
      sentences.push(
        sentence(
          'Additional relevant system symptoms were reported.',
          'ADDITIONAL_SYSTEM_SYMPTOMS',
        ),
      );
    }

    if (isNo(facts, 'ADDITIONAL_SYSTEM_SYMPTOMS')) {
      sentences.push(
        sentence(
          'No additional relevant system symptoms were reported.',
          'ADDITIONAL_SYSTEM_SYMPTOMS',
        ),
      );
    }

    if (ros) {
      sentences.push(
        sentence(
          ros,
          'REVIEW_OF_SYSTEMS',
        ),
      );
    }
  }

  return section(
    'review_of_systems',
    'Review of Systems',
    sentences,
  );
}

// =============================================================================
// CLINICAL SUMMARY
//
// IMPORTANT:
// This is deliberately descriptive rather than diagnostic.
// The documentation compiler must not independently infer a diagnosis.
// =============================================================================

function compileSummary(
  context: ClinicalContext,
  facts: ClinicalFact[],
): DocumentationSection | null {
  const complaint = value(
    facts,
    'PRESENTING_COMPLAINT',
  );

  const duration = value(
    facts,
    'SYMPTOM_DURATION',
  );

  const sentences: DocumentationSentence[] = [];

  const name = value(
    facts,
    'PATIENT_NAME',
  );
  const age = value(
    facts,
    'AGE_YEARS',
  );
  const sex = formatSex(value(facts, 'SEX'));

  const demographic = [age ? `${age}-year-old` : null, sex]
    .filter(Boolean)
    .join(' ');

  const postAdmissionDay = value(
    facts,
    'POST_ADMISSION_DAY',
  );

  const summaryParts: string[] = [];

  if (name || demographic) {
    const subject = name
      ? name
      : 'The patient';
    const demographicPart = demographic
      ? `, ${demographic}`
      : '';
    summaryParts.push(
      `Our patient is ${subject}${demographicPart}`,
    );
  }

  if (context.emergency || context.encounterType === 'INPATIENT') {
    if (postAdmissionDay) {
      const subject = name ? name : 'The patient';
      sentences.push(
        sentence(
          `${subject} was admitted ${postAdmissionDay} days ago.`,
          'POST_ADMISSION_DAY',
        ),
      );
    }
  } else if (context.encounterType === 'OUTPATIENT') {
    const subject = name ? name : 'The patient';
    sentences.push(
      sentence(
        `${subject} was seen as an outpatient.`,
        'ENCOUNTER_TYPE',
      ),
    );
  }

  if (complaint) {
    summaryParts.push(
      `presenting with a history of ${complaint}`,
    );
  }

  if (duration) {
    summaryParts.push(
      `for ${duration}`,
    );
  }

  if (summaryParts.length > 0) {
    sentences.push(
      sentence(
        `${summaryParts.join(', ')}.`,
        complaint
          ? 'PRESENTING_COMPLAINT'
          : duration
            ? 'SYMPTOM_DURATION'
            : 'AGE_YEARS',
      ),
    );
  }

  if (context.emergency) {
    const emergencyFact = value(
      facts,
      'EMERGENCY_STATUS',
    );

    if (emergencyFact) {
      sentences.push(
        sentence(
          `Emergency status: ${emergencyFact}.`,
          'EMERGENCY_STATUS',
        ),
      );
    }
  }

  if (sentences.length === 0) {
    return null;
  }

  return section(
    'summary',
    'Clinical Summary',
    sentences,
  );
}
