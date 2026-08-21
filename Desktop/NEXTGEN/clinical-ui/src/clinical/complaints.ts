// =============================================================================
// src/clinical/complaints.ts
// AMEXAN — CHIEF COMPLAINT CATALOGUE
//
// The chief complaint is captured from a searchable vocabulary.
// The clinician types any label OR synonym (e.g. "hotness of body" -> Fever)
// and the closest catalogue entries are offered.
//
// Each complaint:
//   - belongs to a body system (used to de-duplicate HPI vs Review of Systems),
//   - carries a duration (value + unit) so complaints can be laid out
//     chronologically, oldest first.
//
// RULE:
//   The UI offers vocabulary. The clinician decides what is true.
//   The clinical CPU remains the authority on reasoning.
// =============================================================================

import type { ClinicalFact } from './types';

// =============================================================================
// BODY SYSTEM
//
// Systems drive:
//   1. ROS question visibility (a system already explored in HPI is not
//      re-asked in the Review of Systems).
//   2. Documentation de-duplication (no contradictions).
// =============================================================================

export type ComplaintSystem =
  | 'general'
  | 'respiratory'
  | 'cardiovascular'
  | 'gastrointestinal'
  | 'neurological'
  | 'musculoskeletal'
  | 'genitourinary'
  | 'dermatological'
  | 'head_ent'
  | 'ophthalmological'
  | 'endocrine'
  | 'psychiatric'
  | 'haematological'
  | 'lymphatic'
  | 'other';

export const COMPLAINT_SYSTEM_LABELS: Record<ComplaintSystem, string> = {
  general: 'General',
  respiratory: 'Respiratory',
  cardiovascular: 'Cardiovascular',
  gastrointestinal: 'Gastrointestinal',
  neurological: 'Neurological',
  musculoskeletal: 'Musculoskeletal',
  genitourinary: 'Genitourinary',
  dermatological: 'Dermatological',
  head_ent: 'Head, Ears, Nose & Throat',
  ophthalmological: 'Ophthalmological',
  endocrine: 'Endocrine',
  psychiatric: 'Psychiatric',
  haematological: 'Haematological',
  lymphatic: 'Lymphatic',
  other: 'Other',
};

// =============================================================================
// COMPLAINT DEFINITION
// =============================================================================

export interface ComplaintDefinition {
  code: string;

  label: string;

  /** Everyday and colloquial terms the clinician may type. */
  synonyms: string[];

  system: ComplaintSystem;
}

// =============================================================================
// DURATION
// =============================================================================

export type DurationUnit =
  | 'minutes'
  | 'hours'
  | 'days'
  | 'weeks'
  | 'months'
  | 'years';

export const DURATION_UNITS: DurationUnit[] = [
  'minutes',
  'hours',
  'days',
  'weeks',
  'months',
  'years',
];

export const DURATION_UNIT_LABELS: Record<DurationUnit, string> = {
  minutes: 'minutes',
  hours: 'hours',
  days: 'days',
  weeks: 'weeks',
  months: 'months',
  years: 'years',
};

const UNIT_TO_SECONDS: Record<DurationUnit, number> = {
  minutes: 60,
  hours: 3_600,
  days: 86_400,
  weeks: 604_800,
  months: 2_629_800,
  years: 31_557_600,
};

export function durationToSeconds(
  value: number,
  unit: DurationUnit,
): number {
  return Math.round(value * UNIT_TO_SECONDS[unit]);
}

export function formatDuration(
  value: number | null | undefined,
  unit: DurationUnit | null | undefined,
): string | null {
  if (value == null || !unit) return null;

  if (value === 1) {
    return `1 ${unit.slice(0, -1)}`;
  }

  return `${value} ${DURATION_UNIT_LABELS[unit]}`;
}

export function formatDurationAgo(
  value: number | null | undefined,
  unit: DurationUnit | null | undefined,
): string | null {
  const text = formatDuration(value, unit);
  return text ? `${text} ago` : null;
}

// =============================================================================
// PRESENTING COMPLAINT SUMMARY PARSER
//
// The stored PRESENTING_COMPLAINT text is the single source of truth that BOTH
// the live note and the PDF export render from. Parsing that one string with
// identical rules in both places is what keeps the two outputs coinciding.
// =============================================================================

export interface ParsedPresentingComplaint {
  label: string;
  duration: string | null;
  seconds: number;
  unit: DurationUnit;
}

const SINGULAR_TO_PLURAL: Record<string, DurationUnit> = {
  minute: 'minutes', minutes: 'minutes',
  hour: 'hours', hours: 'hours',
  day: 'days', days: 'days',
  week: 'weeks', weeks: 'weeks',
  month: 'months', months: 'months',
  year: 'years', years: 'years',
};

const PRESENTING_DURATION_PATTERN =
  /^(.+?)\s+for\s+(\d+(?:\.\d+)?)\s+(minutes?|hours?|days?|weeks?|months?|years?)$/i;
const PRESENTING_BARE_DURATION_PATTERN =
  /^(.+?)\s+for\s+(minutes?|hours?|days?|weeks?|months?|years?)$/i;

function humanizePresentingLabel(text: string): string {
  const trimmed = text.trim();
  if (/^[A-Z0-9][A-Z0-9_]*$/.test(trimmed)) {
    return trimmed
      .replace(/_/g, ' ')
      .toLowerCase()
      .replace(/\b\w/g, (letter) => letter.toUpperCase());
  }
  return trimmed;
}

export function sentenceCase(text: string): string {
  const trimmed = text.trim();
  if (!trimmed) return trimmed;
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
}

export function parsePresentingComplaints(
  text: string,
): ParsedPresentingComplaint[] {
  return text
    .split(';')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => {
      const match = PRESENTING_DURATION_PATTERN.exec(part);
      if (match) {
        const value = Number(match[2]);
        const unit =
          SINGULAR_TO_PLURAL[match[3].toLowerCase()] ?? 'days';
        return {
          label: humanizePresentingLabel(match[1]),
          duration: formatDuration(value, unit),
          seconds: durationToSeconds(value, unit),
          unit,
        };
      }
      const bare = PRESENTING_BARE_DURATION_PATTERN.exec(part);
      if (bare) {
        return {
          label: humanizePresentingLabel(bare[1]),
          duration: null,
          seconds: 0,
          unit:
            SINGULAR_TO_PLURAL[bare[2].toLowerCase()] ?? 'days',
        };
      }
      return {
        label: humanizePresentingLabel(part),
        duration: null,
        seconds: 0,
        unit: 'days',
      };
    });
}

// =============================================================================
// CHIEF COMPLAINT INPUT (what the clinician builds in the panel)
// =============================================================================

export interface ChiefComplaintInput {
  code: string;

  label: string;

  durationValue: string;

  durationUnit: DurationUnit;

  canonicalLabel?: string | null;

  patientWording?: string | null;
}

export interface ChiefComplaintEntry extends ChiefComplaintInput {
  durationSeconds: number;

  durationText: string | null;
}

export const MAX_CHIEF_COMPLAINTS = 6;
export const MIN_CHIEF_COMPLAINTS = 1;

// =============================================================================
// FACT CODES
// =============================================================================

export const FACT_CHIEF_COMPLAINT_ORDER = 'CHIEF_COMPLAINT_ORDER';
export const FACT_PRESENTING_COMPLAINT = 'PRESENTING_COMPLAINT';

export function complaintDurationFactCode(
  code: string,
): string {
  return `CHIEF_COMPLAINT_${code}_DURATION`;
}

export function complaintLabelFactCode(
  code: string,
): string {
  return `CHIEF_COMPLAINT_${code}_LABEL`;
}

export function complaintSystemFactCode(
  code: string,
): string {
  return `CHIEF_COMPLAINT_${code}_SYSTEM`;
}

// =============================================================================
// FACT ACCESSORS
//
// These read the canonical complaint facts back out of the captured fact list
// so the question engine and documentation compiler can reason chronologically.
// =============================================================================

export function hasChiefComplaints(
  facts: ClinicalFact[],
): boolean {
  return facts.some(
    (fact) => fact.factCode === FACT_CHIEF_COMPLAINT_ORDER,
  );
}

export function getChiefComplaintOrder(
  facts: ClinicalFact[],
): string[] {
  const order = facts.find(
    (fact) => fact.factCode === FACT_CHIEF_COMPLAINT_ORDER,
  );

  if (!order?.value?.text) return [];

  return order.value.text
    .split(',')
    .map((code) => code.trim())
    .filter(Boolean);
}

export function getChiefComplaintEntries(
  facts: ClinicalFact[],
): ChiefComplaintEntry[] {
  const codes = getChiefComplaintOrder(facts);

  const labelFor = (code: string): string => {
    const fact = facts.find(
      (item) => item.factCode === complaintLabelFactCode(code),
    );

    return fact?.value?.text ?? code;
  };

  const durationFor = (
    code: string,
  ): { seconds: number; text: string | null } => {
    const fact = facts.find(
      (item) => item.factCode === complaintDurationFactCode(code),
    );

    const seconds =
      typeof fact?.value?.durationSeconds === 'number'
        ? fact.value.durationSeconds
        : 0;

    return {
      seconds,
      text: fact?.value?.text ?? null,
    };
  };

  const unitFor = (code: string): DurationUnit => {
    const fact = facts.find(
      (item) => item.factCode === complaintDurationFactCode(code),
    );

    const unit = fact?.value?.unitCode as DurationUnit | null | undefined;

    return unit && DURATION_UNITS.includes(unit) ? unit : 'days';
  };

  const numericFor = (code: string): number | null => {
    const fact = facts.find(
      (item) => item.factCode === complaintDurationFactCode(code),
    );

    return typeof fact?.value?.numeric === 'number'
      ? fact.value.numeric
      : null;
  };

  return codes.map((code) => {
    const duration = durationFor(code);

    return {
      code,
      label: labelFor(code),
      durationValue:
        numericFor(code) != null ? String(numericFor(code)) : '',
      durationUnit: unitFor(code),
      durationSeconds: duration.seconds,
      durationText: duration.text,
    };
  });
}

/**
 * Complaints ordered oldest first (longest duration first).
 */
export function getChiefComplaintsOldestFirst(
  facts: ClinicalFact[],
): ChiefComplaintEntry[] {
  return [...getChiefComplaintEntries(facts)].sort(
    (a, b) => b.durationSeconds - a.durationSeconds,
  );
}

export function complaintSystemCovered(
  facts: ClinicalFact[],
  system: ComplaintSystem,
): boolean {
  return getChiefComplaintEntries(facts).some(
    (entry) =>
      complaintSystemOf(entry.code) === system,
  );
}

function complaintSystemOf(code: string): ComplaintSystem {
  const definition = complaintByCode(code);

  return definition?.system ?? 'other';
}

export function coveredComplaintSystems(
  facts: ClinicalFact[],
): ComplaintSystem[] {
  const systems = new Set<ComplaintSystem>();

  for (const entry of getChiefComplaintEntries(facts)) {
    systems.add(complaintSystemOf(entry.code));
  }

  return [...systems];
}

/**
 * True when a fact code belongs to the chief-complaint vocabulary
 * (summary, order, per-complaint label/duration/system facts).
 *
 * Used to replace the previous complaint set when the clinician saves.
 */
export function isComplaintFactCode(
  factCode: string,
): boolean {
  if (factCode === FACT_PRESENTING_COMPLAINT) return true;
  if (factCode === FACT_CHIEF_COMPLAINT_ORDER) return true;

  return factCode.startsWith('CHIEF_COMPLAINT_');
}

// =============================================================================
// CATALOGUE LOOKUP
// =============================================================================

export function complaintByCode(
  code: string,
): ComplaintDefinition | null {
  return CHIEF_COMPLAINT_CATALOGUE.find(
    (item) => item.code === code,
  ) ?? null;
}

// =============================================================================
// SEARCH
//
// Matches on label and on every synonym, case-insensitively and
// punctuation-insensitively. The clinician can type:
//
//   "fever", "pyrexia", "hotness of body", "temperature"
//
// and the same FEVER entry is found.
// =============================================================================

function normalizeSearch(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function tokenize(text: string): string[] {
  return normalizeSearch(text).split(' ').filter(Boolean);
}

export function searchComplaints(
  query: string,
): ComplaintDefinition[] {
  const normalized = normalizeSearch(query);

  if (!normalized) return [];

  const tokens = tokenize(query);

  const scored = CHIEF_COMPLAINT_CATALOGUE.map((entry) => {
    const label = normalizeSearch(entry.label);
    const synonyms = entry.synonyms.map(normalizeSearch);

    const haystacks = [label, ...synonyms];

    // Whole-phrase matches rank highest, then synonym matches, then any token.
    let score = 0;

    if (haystacks.some((text) => text === normalized)) {
      score = 100;
    } else if (haystacks.some((text) => text.startsWith(normalized))) {
      score = 80;
    } else if (haystacks.some((text) => text.includes(normalized))) {
      score = 60;
    } else {
      const allTokensPresent = tokens.every((token) =>
        haystacks.some((text) => text.includes(token)),
      );

      if (allTokensPresent) {
        score = 40;
      } else {
        score = 20 * tokens.filter((token) =>
          haystacks.some((text) => text.includes(token)),
        ).length / Math.max(1, tokens.length);
      }
    }

    return { entry, score };
  });

  return scored
    .filter((item) => item.score > 0)
    .sort(
      (a, b) =>
        b.score - a.score ||
        a.entry.label.localeCompare(b.entry.label),
    )
    .map((item) => item.entry);
}

// =============================================================================
// CATALOGUE
// =============================================================================

export const CHIEF_COMPLAINT_CATALOGUE: ComplaintDefinition[] = [
  // ---------------------------------------------------------------------------
  // GENERAL
  // ---------------------------------------------------------------------------
  {
    code: 'FEVER',
    label: 'Fever',
    synonyms: [
      'hotness of body',
      'hot body',
      'high temperature',
      'pyrexia',
      'feverish',
      'temperature',
      'feeling hot',
      'rigors',
      'body hot',
    ],
    system: 'general',
  },
  {
    code: 'CHILLS',
    label: 'Chills / rigors',
    synonyms: ['shivering', 'feeling cold', 'shakes', 'cold shivers'],
    system: 'general',
  },
  {
    code: 'FATIGUE',
    label: 'Fatigue / tiredness',
    synonyms: ['tiredness', 'exhaustion', 'weakness', 'tired all the time', 'lethargy', 'tired', 'worn out'],
    system: 'general',
  },
  {
    code: 'WEIGHT_LOSS',
    label: 'Unintentional weight loss',
    synonyms: ['losing weight', 'weight reduction', 'slimming', 'wasting'],
    system: 'general',
  },
  {
    code: 'WEIGHT_GAIN',
    label: 'Weight gain',
    synonyms: ['gaining weight', 'putting on weight'],
    system: 'general',
  },
  {
    code: 'NIGHT_SWEATS',
    label: 'Night sweats',
    synonyms: ['sweating at night', 'drenching night sweats', 'sweaty at night'],
    system: 'general',
  },
  {
    code: 'MALAISE',
    label: 'Malaise',
    synonyms: ['general feeling unwell', 'not feeling well', 'unwell', 'feeling off', 'flu-like'],
    system: 'general',
  },
  {
    code: 'BODY_ACHES',
    label: 'General body aches',
    synonyms: ['body pain', 'aches all over', 'whole body pain', 'muscle aches all over', 'generalised aches'],
    system: 'general',
  },

  // ---------------------------------------------------------------------------
  // RESPIRATORY
  // ---------------------------------------------------------------------------
  {
    code: 'COUGH',
    label: 'Cough',
    synonyms: ['hacking cough', 'dry cough', 'productive cough', 'coughing'],
    system: 'respiratory',
  },
  {
    code: 'DYSPNOEA',
    label: 'Breathlessness / shortness of breath',
    synonyms: ['shortness of breath', 'difficulty breathing', 'hard to breathe', 'breathless', 'SOB', 'cannot breathe', 'struggling to breathe', 'air hunger'],
    system: 'respiratory',
  },
  {
    code: 'WHEEZE',
    label: 'Wheezing',
    synonyms: ['whistling breath', 'wheezy breathing', 'wheezing sound'],
    system: 'respiratory',
  },
  {
    code: 'SPUTUM',
    label: 'Sputum / phlegm',
    synonyms: ['phlegm', 'mucus', 'spitting phlegm', 'productive sputum'],
    system: 'respiratory',
  },
  {
    code: 'HAEMOPTYSIS',
    label: 'Coughing blood',
    synonyms: ['blood in sputum', 'coughing up blood', 'blood-stained sputum', 'bloody cough'],
    system: 'respiratory',
  },
  {
    code: 'NASAL_CONGESTION',
    label: 'Nasal congestion / blocked nose',
    synonyms: ['blocked nose', 'stuffy nose', 'runny nose', 'nasal discharge', 'flu'],
    system: 'respiratory',
  },
  {
    code: 'SNEEZING',
    label: 'Sneezing',
    synonyms: ['sneezes', 'fits of sneezing'],
    system: 'respiratory',
  },

  // ---------------------------------------------------------------------------
  // CARDIOVASCULAR
  // ---------------------------------------------------------------------------
  {
    code: 'CHEST_PAIN',
    label: 'Chest pain',
    synonyms: ['pain in the chest', 'chest tightness', 'chest discomfort', 'left chest pain', 'central chest pain', 'heavy chest'],
    system: 'cardiovascular',
  },
  {
    code: 'PALPITATIONS',
    label: 'Palpitations',
    synonyms: ['racing heart', 'heart beating fast', 'fluttering heart', 'skipped beats', 'fast heartbeat', 'heart pounding'],
    system: 'cardiovascular',
  },
  {
    code: 'LEG_SWELLING',
    label: 'Leg / ankle swelling',
    synonyms: ['swollen legs', 'swollen ankles', 'oedema', 'swollen feet', 'pitting oedema'],
    system: 'cardiovascular',
  },
  {
    code: 'SYNCOPE',
    label: 'Fainting / blackouts',
    synonyms: ['loss of consciousness', 'passed out', 'collapsed', 'syncope', 'blacked out'],
    system: 'cardiovascular',
  },
  {
    code: 'DIZZINESS_ON_STANDING',
    label: 'Dizziness on standing',
    synonyms: ['light-headed when standing', 'dizzy on standing', 'postural dizziness', 'feeling faint on standing'],
    system: 'cardiovascular',
  },

  // ---------------------------------------------------------------------------
  // GASTROINTESTINAL
  // ---------------------------------------------------------------------------
  {
    code: 'ABDOMINAL_PAIN',
    label: 'Abdominal pain',
    synonyms: ['stomach pain', 'belly pain', 'tummy ache', 'abdominal cramps', 'stomach ache', 'gastric pain', 'stomach cramps'],
    system: 'gastrointestinal',
  },
  {
    code: 'NAUSEA',
    label: 'Nausea',
    synonyms: ['feeling sick', 'queasy', 'feeling nauseated', 'wanting to vomit', 'sick feeling'],
    system: 'gastrointestinal',
  },
  {
    code: 'VOMITING',
    label: 'Vomiting',
    synonyms: ['throwing up', 'being sick', 'vomits', 'emesis', 'vomiting up', 'projectile vomiting'],
    system: 'gastrointestinal',
  },
  {
    code: 'DIARRHOEA',
    label: 'Diarrhoea',
    synonyms: ['loose stools', 'watery stools', 'frequent stools', 'running stomach', 'loose motions', 'diarrhea'],
    system: 'gastrointestinal',
  },
  {
    code: 'CONSTIPATION',
    label: 'Constipation',
    synonyms: ['hard stools', 'difficulty passing stool', 'infrequent stools', 'blocked bowels'],
    system: 'gastrointestinal',
  },
  {
    code: 'HEARTBURN',
    label: 'Heartburn / acid reflux',
    synonyms: ['acid reflux', 'burning chest', 'acid in throat', 'regurgitation', 'burning stomach'],
    system: 'gastrointestinal',
  },
  {
    code: 'BLOOD_IN_STOOL',
    label: 'Blood in stool',
    synonyms: ['rectal bleeding', 'bloody stool', 'blood in faeces', 'bleeding from back passage', 'fresh blood in stool'],
    system: 'gastrointestinal',
  },
  {
    code: 'JAUNDICE',
    label: 'Jaundice',
    synonyms: ['yellow skin', 'yellow eyes', 'yellowing of eyes', 'yellow body'],
    system: 'gastrointestinal',
  },
  {
    code: 'ABDOMINAL_DISTENSION',
    label: 'Abdominal distension / bloating',
    synonyms: ['bloating', 'swollen belly', 'swollen stomach', 'fullness of abdomen', 'gas in stomach'],
    system: 'gastrointestinal',
  },
  {
    code: 'REDUCED_APPETITE',
    label: 'Reduced appetite',
    synonyms: ['loss of appetite', 'poor appetite', 'not eating well', 'no appetite', 'anorexia'],
    system: 'gastrointestinal',
  },
  {
    code: 'DIFFICULTY_SWALLOWING',
    label: 'Difficulty swallowing',
    synonyms: ['dysphagia', 'trouble swallowing', 'food getting stuck', 'cannot swallow'],
    system: 'gastrointestinal',
  },

  // ---------------------------------------------------------------------------
  // NEUROLOGICAL
  // ---------------------------------------------------------------------------
  {
    code: 'HEADACHE',
    label: 'Headache',
    synonyms: ['head pain', 'pain in the head', 'throbbing head', 'head hurting', 'migraine', 'head ache'],
    system: 'neurological',
  },
  {
    code: 'SEIZURE',
    label: 'Seizure / convulsions',
    synonyms: ['fits', 'convulsions', 'epileptic attack', 'jerking movements', 'shaking fit', 'attacks'],
    system: 'neurological',
  },
  {
    code: 'LOSS_OF_CONSCIOUSNESS',
    label: 'Loss of consciousness',
    synonyms: ['unconscious', 'passed out', 'blacked out', 'comatose', 'faint'],
    system: 'neurological',
  },
  {
    code: 'LIMB_WEAKNESS',
    label: 'Limb weakness / paralysis',
    synonyms: ['weakness of arm', 'weakness of leg', 'paralysis', 'one-sided weakness', 'weak arm', 'weak leg', 'drooping face', 'facial weakness'],
    system: 'neurological',
  },
  {
    code: 'NUMBNESS',
    label: 'Numbness / tingling',
    synonyms: ['pins and needles', 'loss of sensation', 'tingling', 'numb limb'],
    system: 'neurological',
  },
  {
    code: 'TREMOR',
    label: 'Tremor / shaking',
    synonyms: ['shaking hands', 'trembling', 'tremors', 'hands shaking'],
    system: 'neurological',
  },
  {
    code: 'CONFUSION',
    label: 'Confusion / disorientation',
    synonyms: ['disoriented', 'confused', 'not oriented', 'mental confusion', 'muddled'],
    system: 'neurological',
  },
  {
    code: 'MEMORY_LOSS',
    label: 'Memory loss',
    synonyms: ['forgetfulness', 'poor memory', 'forgetting things', 'amnesia'],
    system: 'neurological',
  },
  {
    code: 'DIZZINESS',
    label: 'Dizziness / vertigo',
    synonyms: ['light-headed', 'vertigo', 'feeling dizzy', 'spinning sensation', 'room spinning'],
    system: 'neurological',
  },

  // ---------------------------------------------------------------------------
  // MUSCULOSKELETAL
  // ---------------------------------------------------------------------------
  {
    code: 'JOINT_PAIN',
    label: 'Joint pain / swelling',
    synonyms: ['painful joints', 'swollen joints', 'arthralgia', 'joint aches', 'arthritis', 'painful knees', 'painful joints'],
    system: 'musculoskeletal',
  },
  {
    code: 'BACK_PAIN',
    label: 'Back pain',
    synonyms: ['lower back pain', 'pain in the back', 'lumbar pain', 'spine pain', 'backache'],
    system: 'musculoskeletal',
  },
  {
    code: 'MUSCLE_PAIN',
    label: 'Muscle pain',
    synonyms: ['myalgia', 'muscle ache', 'aching muscles', 'painful muscles', 'body muscle pain'],
    system: 'musculoskeletal',
  },
  {
    code: 'NECK_PAIN',
    label: 'Neck pain / stiffness',
    synonyms: ['stiff neck', 'painful neck', 'neck stiffness'],
    system: 'musculoskeletal',
  },
  {
    code: 'TRAUMA',
    label: 'Injury / trauma',
    synonyms: ['accident', 'fall', 'fracture', 'broken bone', 'wound', 'hurt from fall', 'road accident'],
    system: 'musculoskeletal',
  },
  {
    code: 'SWELLING',
    label: 'Swelling / lump',
    synonyms: ['lump', 'swollen part', 'mass', 'growth', 'bump'],
    system: 'musculoskeletal',
  },

  // ---------------------------------------------------------------------------
  // GENITOURINARY
  // ---------------------------------------------------------------------------
  {
    code: 'DYSURIA',
    label: 'Painful urination',
    synonyms: ['burning urination', 'pain when passing urine', 'stinging urine', 'burning when urinating'],
    system: 'genitourinary',
  },
  {
    code: 'FREQUENT_URINATION',
    label: 'Frequent urination',
    synonyms: ['passing urine often', 'urinating a lot', 'urinary frequency', 'voiding often'],
    system: 'genitourinary',
  },
  {
    code: 'BLOOD_IN_URINE',
    label: 'Blood in urine',
    synonyms: ['haematuria', 'bloody urine', 'red urine', 'passing blood in urine'],
    system: 'genitourinary',
  },
  {
    code: 'URINARY_RETENTION',
    label: 'Difficulty passing urine',
    synonyms: ['unable to urinate', 'urinary retention', 'cannot pass urine', 'difficulty urinating'],
    system: 'genitourinary',
  },
  {
    code: 'VAGINAL_DISCHARGE',
    label: 'Vaginal discharge',
    synonyms: ['abnormal discharge', 'foul discharge', 'coloured discharge', 'leucorrhoea'],
    system: 'genitourinary',
  },
  {
    code: 'GENITAL_ULCER',
    label: 'Genital ulcer / sore',
    synonyms: ['genital sore', 'genital wound', 'ulcer on genital', 'genital rash'],
    system: 'genitourinary',
  },

  // ---------------------------------------------------------------------------
  // DERMATOLOGICAL
  // ---------------------------------------------------------------------------
  {
    code: 'RASH',
    label: 'Skin rash',
    synonyms: ['spots on skin', 'skin eruption', 'red spots', 'itching rash', 'body rash', 'skin bumps'],
    system: 'dermatological',
  },
  {
    code: 'ITCHING',
    label: 'Itching',
    synonyms: ['itchy skin', 'pruritus', 'itch all over', 'scratching'],
    system: 'dermatological',
  },
  {
    code: 'SKIN_LESION',
    label: 'Skin lesion / growth',
    synonyms: ['skin growth', 'mole', 'skin sore', 'non-healing wound', 'skin ulcer', 'boil'],
    system: 'dermatological',
  },
  {
    code: 'HAIR_LOSS',
    label: 'Hair loss',
    synonyms: ['falling hair', 'balding', 'thinning hair', 'hair falling out'],
    system: 'dermatological',
  },

  // ---------------------------------------------------------------------------
  // HEAD, EARS, NOSE & THROAT
  // ---------------------------------------------------------------------------
  {
    code: 'SORE_THROAT',
    label: 'Sore throat',
    synonyms: ['throat pain', 'painful throat', 'throat ache', 'pain when swallowing', 'pharyngitis'],
    system: 'head_ent',
  },
  {
    code: 'EAR_PAIN',
    label: 'Ear pain / discharge',
    synonyms: ['earache', 'pain in ear', 'ear discharge', 'running ear', 'pus from ear', 'ear infection'],
    system: 'head_ent',
  },
  {
    code: 'HEARING_LOSS',
    label: 'Hearing loss',
    synonyms: ['deafness', 'reduced hearing', 'cannot hear', 'hard of hearing'],
    system: 'head_ent',
  },
  {
    code: 'TOOTHACHE',
    label: 'Toothache',
    synonyms: ['dental pain', 'tooth pain', 'pain in teeth', 'aching tooth'],
    system: 'head_ent',
  },

  // ---------------------------------------------------------------------------
  // OPHTHALMOLOGICAL
  // ---------------------------------------------------------------------------
  {
    code: 'RED_EYE',
    label: 'Red eye',
    synonyms: ['bloodshot eye', 'eye redness', 'conjunctivitis', 'red eyes'],
    system: 'ophthalmological',
  },
  {
    code: 'EYE_PAIN',
    label: 'Eye pain',
    synonyms: ['pain in eye', 'aching eye', 'eye ache'],
    system: 'ophthalmological',
  },
  {
    code: 'BLURRED_VISION',
    label: 'Blurred vision',
    synonyms: ['poor vision', 'vision loss', 'cannot see clearly', 'blurring of vision', 'failing eyesight'],
    system: 'ophthalmological',
  },
  {
    code: 'EYE_DISCHARGE',
    label: 'Eye discharge',
    synonyms: ['sticky eye', 'mucus from eye', 'pussy eye', 'watering eye'],
    system: 'ophthalmological',
  },

  // ---------------------------------------------------------------------------
  // ENDOCRINE
  // ---------------------------------------------------------------------------
  {
    code: 'EXCESSIVE_THIRST',
    label: 'Excessive thirst',
    synonyms: ['polydipsia', 'drinking a lot', 'always thirsty', 'thirsty all the time'],
    system: 'endocrine',
  },
  {
    code: 'EXCESSIVE_URINATION',
    label: 'Excessive urination',
    synonyms: ['polyuria', 'urinating a lot at night', 'passing a lot of urine', 'nocturia'],
    system: 'endocrine',
  },
  {
    code: 'HEAT_INTOLERANCE',
    label: 'Heat intolerance / palpitations',
    synonyms: ['always hot', 'heat intolerance', 'sweating easily', 'intolerance to heat'],
    system: 'endocrine',
  },
  {
    code: 'COLD_INTOLERANCE',
    label: 'Cold intolerance',
    synonyms: ['always cold', 'intolerance to cold', 'feeling cold all the time'],
    system: 'endocrine',
  },

  // ---------------------------------------------------------------------------
  // PSYCHIATRIC
  // ---------------------------------------------------------------------------
  {
    code: 'LOW_MOOD',
    label: 'Low mood / depression',
    synonyms: ['depression', 'feeling sad', 'hopelessness', 'tearful', 'feeling down', 'crying a lot'],
    system: 'psychiatric',
  },
  {
    code: 'ANXIETY',
    label: 'Anxiety',
    synonyms: ['feeling anxious', 'worry', 'panic attacks', 'nervousness', 'restlessness'],
    system: 'psychiatric',
  },
  {
    code: 'SLEEP_DISTURBANCE',
    label: 'Sleep disturbance',
    synonyms: ['insomnia', 'poor sleep', 'trouble sleeping', 'not sleeping', 'sleeplessness', 'nightmares'],
    system: 'psychiatric',
  },
  {
    code: 'HALLUCINATIONS',
    label: 'Hallucinations',
    synonyms: ['seeing things', 'hearing voices', 'delusions', 'talking to self'],
    system: 'psychiatric',
  },
  {
    code: 'SUICIDAL_IDEATION',
    label: 'Suicidal thoughts',
    synonyms: ['thinking of suicide', 'wanting to die', 'self harm', 'suicidal ideas'],
    system: 'psychiatric',
  },

  // ---------------------------------------------------------------------------
  // HAEMATOLOGICAL / LYMPHATIC
  // ---------------------------------------------------------------------------
  {
    code: 'BLEEDING',
    label: 'Bleeding / easy bruising',
    synonyms: ['easy bruising', 'bleeding tendency', 'prolonged bleeding', 'bleeding gums', 'nose bleeds'],
    system: 'haematological',
  },
  {
    code: 'PALLOR',
    label: 'Pallor / paleness',
    synonyms: ['pale skin', 'pale', 'looks pale', 'anaemia', 'pale face'],
    system: 'haematological',
  },
  {
    code: 'SWOLLEN_GLANDS',
    label: 'Swollen glands',
    synonyms: ['lymph node swelling', 'swollen lymph nodes', 'neck glands', 'lumps in neck', 'glandular swelling'],
    system: 'lymphatic',
  },
];

// =============================================================================
// COMPLAINT FACTS BUILDER
//
// Converts a saved complaint set into the canonical fact stream used by the
// question engine and the documentation compiler.
// =============================================================================

export function complaintFactsFromSave(
  inputs: ChiefComplaintInput[],
  patientId: string,
  encounterId: string | null,
  section: string,
): ClinicalFact[] {
  const now = new Date().toISOString();

  // Chronological order, oldest first.
  const ordered = [...inputs].sort(
    (a, b) =>
      durationToSeconds(Number(b.durationValue) || 0, b.durationUnit) -
      durationToSeconds(Number(a.durationValue) || 0, a.durationUnit),
  );

  const facts: ClinicalFact[] = [];

  // Summary fact (keeps compatibility with PRESENTING_COMPLAINT).
  const summaryText = ordered
    .map((entry) => {
      const label =
        entry.patientWording ??
        entry.canonicalLabel ??
        entry.label;
      const duration = formatDuration(
        Number(entry.durationValue) || null,
        entry.durationUnit,
      );

      return duration
        ? `${label} for ${duration}`
        : label;
    })
    .join('; ');

  facts.push({
    id: crypto.randomUUID(),
    patientId,
    encounterId,
    factCode: FACT_PRESENTING_COMPLAINT,
    section: section as ClinicalFact['section'],
    value: {
      text: summaryText,
    },
    sourceType: 'clinician',
    recordedAt: now,
  });

  // Order fact: comma-separated codes, oldest first.
  facts.push({
    id: crypto.randomUUID(),
    patientId,
    encounterId,
    factCode: FACT_CHIEF_COMPLAINT_ORDER,
    section: section as ClinicalFact['section'],
    value: {
      text: ordered.map((entry) => entry.code).join(','),
    },
    sourceType: 'clinician',
    recordedAt: now,
  });

  for (const entry of ordered) {
    const numeric = Number(entry.durationValue) || 0;
    const definition = complaintByCode(entry.code);

    facts.push({
      id: crypto.randomUUID(),
      patientId,
      encounterId,
      factCode: complaintLabelFactCode(entry.code),
      section: section as ClinicalFact['section'],
      value: {
        text:
          entry.patientWording ??
          entry.canonicalLabel ??
          entry.label,
        code: entry.code,
      },
      sourceType: 'clinician',
      recordedAt: now,
    });

    facts.push({
      id: crypto.randomUUID(),
      patientId,
      encounterId,
      factCode: complaintDurationFactCode(entry.code),
      section: section as ClinicalFact['section'],
      value: {
        text: formatDuration(numeric, entry.durationUnit),
        numeric,
        unitCode: entry.durationUnit,
        durationSeconds: durationToSeconds(numeric, entry.durationUnit),
      },
      sourceType: 'clinician',
      recordedAt: now,
    });

    facts.push({
      id: crypto.randomUUID(),
      patientId,
      encounterId,
      factCode: complaintSystemFactCode(entry.code),
      section: section as ClinicalFact['section'],
      value: {
        text: definition?.system ?? 'other',
        code: definition?.system ?? 'other',
      },
      sourceType: 'clinician',
      recordedAt: now,
    });
  }

  return facts;
}
