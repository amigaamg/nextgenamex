// =============================================================================
// server/compose.ts
// AMEXAN — ENCOUNTER DOCUMENT COMPOSITION FOR THE PDF EXPORT
//
// This mirrors the clinical UI's live-documentation compiler
// (clinical-ui/src/clinical/documentation.ts) using the SAME stored clinical
// facts, so the exported PDF reads exactly like the "Live Documentation" note
// rendered in real time.
//
// RULES:
//   1. The PDF must look like the live documentation.
//   2. Both outputs render from the same single source of truth (facts).
//   3. Structured CHIEF_COMPLAINT_* facts are preferred; the legacy
//      PRESENTING_COMPLAINT summary is used only when no structured facts
//      exist.
//   4. Never emit boolean leakage ("Yes"/"No"), bare durations ("for days"),
//      or raw codes into the note.
// =============================================================================

import type {
  EncounterFactRow,
  EncounterSnapshot,
} from './encounters.js';

import type {
  ClinicalComplaint,
  ClinicalDuration,
  ClinicalDurationUnit,
} from './pdf.js';

// =============================================================================
// DURATION
// =============================================================================

const UNIT_TO_SECONDS: Record<
  ClinicalDurationUnit,
  number
> = {
  minutes: 60,
  hours: 3_600,
  days: 86_400,
  weeks: 604_800,
  months: 2_629_800,
  years: 31_557_600,
};

const OFFSET_UNIT_SECONDS: Record<
  ClinicalDurationUnit,
  number
> = {
  minutes: 60,
  hours: 3_600,
  days: 86_400,
  weeks: 604_800,
  months: 2_629_800,
  years: 31_557_600,
};

function normalizeUnit(
  unit: string | null | undefined,
): ClinicalDurationUnit {
  const value = String(unit ?? '')
    .trim()
    .toLowerCase();

  switch (value) {
    case 'minute':
    case 'minutes':
      return 'minutes';
    case 'hour':
    case 'hours':
      return 'hours';
    case 'week':
    case 'weeks':
      return 'weeks';
    case 'month':
    case 'months':
      return 'months';
    case 'year':
    case 'years':
      return 'years';
    case 'day':
    case 'days':
    default:
      return 'days';
  }
}

function formatDuration(
  value: number | null | undefined,
  unit: ClinicalDurationUnit | null | undefined,
): string | null {
  if (value == null || !unit) return null;

  if (value === 1) {
    return `1 ${unit.slice(0, -1)}`;
  }

  return `${value} ${unit}`;
}

function offsetDurationText(
  seconds: number,
  unit: ClinicalDurationUnit,
): string {
  const unitSeconds =
    OFFSET_UNIT_SECONDS[unit] ?? 86_400;

  if (seconds % unitSeconds === 0) {
    const text = formatDuration(
      seconds / unitSeconds,
      unit,
    );

    if (text) return text;
  }

  return (
    formatDuration(
      seconds / 86_400,
      'days',
    ) ?? 'a while'
  );
}

// =============================================================================
// FACT ACCESSORS
//
// Mirrors the UI's value() / lastValue() / formatFactValue() helpers.
// =============================================================================

function formatFactValue(
  fact: EncounterFactRow,
): string | null {
  if (fact.text != null) {
    const trimmed = fact.text.trim();

    return trimmed || null;
  }

  if (fact.numeric != null) {
    return [
      String(fact.numeric),
      fact.unitCode ?? null,
    ]
      .filter(Boolean)
      .join(' ');
  }

  if (fact.boolean != null) {
    return fact.boolean ? 'yes' : 'no';
  }

  return null;
}

function value(
  facts: EncounterFactRow[],
  code: string,
): string | null {
  const fact = facts.find(
    (item) => item.factCode === code,
  );

  return fact ? formatFactValue(fact) : null;
}

function lastValue(
  facts: EncounterFactRow[],
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

function isYes(
  facts: EncounterFactRow[],
  code: string,
): boolean {
  const next = value(facts, code);

  return (
    next === 'YES' ||
    next === 'yes' ||
    next === 'true'
  );
}

function isNo(
  facts: EncounterFactRow[],
  code: string,
): boolean {
  const next = value(facts, code);

  return (
    next === 'NO' ||
    next === 'no' ||
    next === 'false'
  );
}

function normalizeCode(
  value_: string | null,
): string {
  return value_
    ? value_
        .replace(/_/g, ' ')
        .toLowerCase()
    : '';
}

function sentenceCase(
  text: string,
): string {
  const trimmed = text.trim();

  if (!trimmed) return trimmed;

  return (
    trimmed.charAt(0).toUpperCase() +
    trimmed.slice(1)
  );
}

const JUNK_LABELS = new Set([
  'yes',
  'no',
  'true',
  'false',
  'none',
  'no complaint',
  'no complaints',
  'no chief complaint',
  'no_complaints',
  'no_chief_complaint',
  'changes not recorded',
  'changes not yet recorded',
  'changes_not_recorded',
  'required',
  'dirty',
  'draft',
  'presenting complaint',
]);

function isJunkLabel(label: string): boolean {
  const lower = label.trim().toLowerCase();

  if (lower === '') return true;

  return JUNK_LABELS.has(lower);
}

// =============================================================================
// PRESENTING COMPLAINT SUMMARY PARSER
//
// Identical to the UI's parsePresentingComplaints (plus junk filtering). Used
// only as a legacy fallback when structured CHIEF_COMPLAINT_* facts are
// absent.
// =============================================================================

interface ParsedSummaryEntry {
  label: string;
  durationValue: number | null;
  unit: ClinicalDurationUnit;
  duration: string | null;
  seconds: number;
}

const SINGULAR_TO_PLURAL: Record<
  string,
  ClinicalDurationUnit
> = {
  minute: 'minutes',
  minutes: 'minutes',
  hour: 'hours',
  hours: 'hours',
  day: 'days',
  days: 'days',
  week: 'weeks',
  weeks: 'weeks',
  month: 'months',
  months: 'months',
  year: 'years',
  years: 'years',
};

const PRESENTING_DURATION_PATTERN =
  /^(.+?)\s+for\s+(\d+(?:\.\d+)?)\s+(minutes?|hours?|days?|weeks?|months?|years?)$/i;

const PRESENTING_BARE_DURATION_PATTERN =
  /^(.+?)\s+for\s+(minutes?|hours?|days?|weeks?|months?|years?)$/i;

function humanizePresentingLabel(
  text: string,
): string {
  const trimmed = text.trim();

  if (/^[A-Z0-9][A-Z0-9_]*$/.test(trimmed)) {
    return trimmed
      .replace(/_/g, ' ')
      .toLowerCase()
      .replace(/\b\w/g, (letter) =>
        letter.toUpperCase(),
      );
  }

  return trimmed;
}

function parseSummary(
  text: string,
): ParsedSummaryEntry[] {
  return text
    .split(';')
    .map((part) => part.trim())
    .filter(Boolean)
    .map(
      (part): ParsedSummaryEntry => {
        const match =
          PRESENTING_DURATION_PATTERN.exec(
            part,
          );

      if (match) {
        const value = Number(match[2]);
        const unit =
          SINGULAR_TO_PLURAL[
            match[3].toLowerCase()
          ] ?? 'days';

        return {
          label: humanizePresentingLabel(
            match[1],
          ),
          durationValue: value,
          unit,
          duration: formatDuration(
            value,
            unit,
          ),
          seconds: Math.round(
            value * UNIT_TO_SECONDS[unit],
          ),
        };
      }

      const bare =
        PRESENTING_BARE_DURATION_PATTERN.exec(
          part,
        );

      if (bare) {
        return {
          label: humanizePresentingLabel(
            bare[1],
          ),
          durationValue: null,
          unit:
            SINGULAR_TO_PLURAL[
              bare[2].toLowerCase()
            ] ?? 'days',
          duration: null,
          seconds: 0,
        };
      }

      return {
        label: humanizePresentingLabel(part),
        durationValue: null,
        unit: 'days',
        duration: null,
        seconds: 0,
      };
    })
    .filter((entry) =>
      !isJunkLabel(entry.label),
    );
}

// =============================================================================
// STRUCTURED CHIEF COMPLAINT FACTS
//
// Mirrors the UI's getChiefComplaintsOldestFirst.
// =============================================================================

interface ChiefComplaintEntry {
  code: string;
  label: string;
  durationValue: number | null;
  unit: ClinicalDurationUnit;
  durationText: string | null;
  durationSeconds: number;
}

function hasStructuredComplaints(
  facts: EncounterFactRow[],
): boolean {
  return facts.some(
    (fact) =>
      fact.factCode === 'CHIEF_COMPLAINT_ORDER',
  );
}

function chiefComplaintEntries(
  facts: EncounterFactRow[],
): ChiefComplaintEntry[] {
  const order = facts.find(
    (fact) =>
      fact.factCode === 'CHIEF_COMPLAINT_ORDER',
  );

  if (!order?.text) return [];

  const codes = order.text
    .split(',')
    .map((code) => code.trim())
    .filter(Boolean);

  return codes.map((code) => {
    const labelFact = facts.find(
      (fact) =>
        fact.factCode ===
        `CHIEF_COMPLAINT_${code}_LABEL`,
    );

    const durationFact = facts.find(
      (fact) =>
        fact.factCode ===
        `CHIEF_COMPLAINT_${code}_DURATION`,
    );

    const unit = normalizeUnit(
      durationFact?.unitCode,
    );

    const numeric =
      durationFact?.numeric ?? null;

    const seconds =
      numeric != null &&
      Number.isFinite(numeric)
        ? Math.round(
            numeric * UNIT_TO_SECONDS[unit],
          )
        : 0;

    return {
      code,
      label:
        (labelFact?.text ?? '').trim() ||
        code,
      durationValue: numeric,
      unit,
      durationText:
        (durationFact?.text ?? '').trim() ||
        null,
      durationSeconds: seconds,
    };
  });
}

function chiefComplaintsOldestFirst(
  facts: EncounterFactRow[],
): ChiefComplaintEntry[] {
  return [
    ...chiefComplaintEntries(facts),
  ].sort(
    (a, b) =>
      b.durationSeconds -
      a.durationSeconds,
  );
}

// =============================================================================
// AGE / LIFE STAGE
// =============================================================================

function ageFromBirthDate(
  birthDate: string | null,
): number | null {
  if (!birthDate) return null;

  const parsed = new Date(
    `${birthDate}T00:00:00`,
  );

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  const today = new Date();

  let years =
    today.getFullYear() -
    parsed.getFullYear();

  const monthDiff =
    today.getMonth() - parsed.getMonth();

  if (
    monthDiff < 0 ||
    (monthDiff === 0 &&
      today.getDate() < parsed.getDate())
  ) {
    years -= 1;
  }

  return Math.max(0, years);
}

type LifeStage =
  | 'neonate'
  | 'infant'
  | 'child'
  | 'adolescent'
  | 'adult'
  | 'older_adult';

const NEONATAL_MAX_DAYS = 28;

function resolveLifeStageFromBirthDate(
  birthDate: string | null,
): LifeStage {
  if (!birthDate) return 'adult';

  const parsed = new Date(
    `${birthDate}T00:00:00`,
  );

  if (Number.isNaN(parsed.getTime())) {
    return 'adult';
  }

  const now = new Date();

  const birthUtc = Date.UTC(
    parsed.getFullYear(),
    parsed.getMonth(),
    parsed.getDate(),
  );

  const nowUtc = Date.UTC(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  );

  const days = Math.max(
    0,
    Math.floor((nowUtc - birthUtc) / 86_400_000),
  );

  const months =
    (now.getFullYear() - parsed.getFullYear()) *
      12 +
    (now.getMonth() - parsed.getMonth()) -
    (now.getDate() < parsed.getDate() ? 1 : 0);

  const years =
    ageFromBirthDate(birthDate) ?? 0;

  if (
    Number.isFinite(days) &&
    days >= 0 &&
    days <= NEONATAL_MAX_DAYS
  ) {
    return 'neonate';
  }

  if (months > 0 && months < 12) {
    return 'infant';
  }

  if (years >= 0 && years < 13) {
    return 'child';
  }

  if (years >= 13 && years < 18) {
    return 'adolescent';
  }

  if (years >= 65) {
    return 'older_adult';
  }

  return 'adult';
}

// =============================================================================
// HPI CHRONOLOGY
// =============================================================================

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
  facts: EncounterFactRow[],
): string[] {
  const out: string[] = [];

  for (const rule of CANONICAL_HPI_DETAILS[code] ?? []) {
    const raw = value(facts, rule.fact);

    if (!raw || NEGATIVE_VALUE_CODES.has(raw.toUpperCase())) {
      continue;
    }

    out.push(
      rule.template
        .replace(/\{label\}/g, label)
        .replace(/\{value\}/g, normalizeCode(raw)),
    );
  }

  return out;
}

function composeStructuredChronology(
  facts: EncounterFactRow[],
  entries: ChiefComplaintEntry[],
): string[] {
  const sentences: string[] = [];
  const details: string[] = [];

  if (entries.length === 0) {
    return sentences;
  }

  const firstEntry = entries[0];
  const firstSeconds =
    firstEntry.durationSeconds ?? 0;
  const firstLabel = (
    firstEntry.label ?? ''
  ).toLowerCase();

  entries.forEach((entry, index) => {
    const code = entry.code;
    const label = entry.label.toLowerCase();
    const duration =
      entry.durationText ??
      (entry.durationValue != null
        ? formatDuration(
            entry.durationValue,
            entry.unit,
          )
        : null);

    const canonicalOnsetFact = CANONICAL_ONSET_FACT[code];

    const onset =
      value(
        facts,
        `${code}_SYMPTOM_ONSET`,
      ) ??
      (canonicalOnsetFact
        ? value(facts, canonicalOnsetFact)
        : null);

    const course = value(
      facts,
      `${code}_SYMPTOM_COURSE`,
    );
    const severity = value(
      facts,
      `${code}_SYMPTOM_SEVERITY`,
    );
    const aggravating = value(
      facts,
      `${code}_SYMPTOM_AGGRAVATING`,
    );
    const relieving = value(
      facts,
      `${code}_SYMPTOM_RELIEVING`,
    );
    const associated = value(
      facts,
      `${code}_SYMPTOM_ASSOCIATED`,
    );

    if (index === 0) {
      const parts: string[] = [];

      if (duration) {
        parts.push(
          `The illness began with ${label} ${duration} ago`,
        );
      } else {
        parts.push(
          `The illness began with ${label}`,
        );
      }

      if (onset) {
        parts.push(
          `${normalizeCode(onset)} onset`,
        );
      }

      if (parts.length > 0) {
        sentences.push(
          `${parts.join(', ')}.`,
        );
      }
    } else {
      const parts: string[] = [];

      const entrySeconds =
        entry.durationSeconds ?? 0;

      if (
        entrySeconds > 0 &&
        firstSeconds > 0 &&
        entrySeconds < firstSeconds
      ) {
        parts.push(
          `${entry.label} developed ${offsetDurationText(
            firstSeconds - entrySeconds,
            entry.unit,
          )} after the ${firstLabel} began`,
        );
      } else if (
        entrySeconds > 0 &&
        firstSeconds > 0 &&
        entrySeconds === firstSeconds
      ) {
        parts.push(
          `${entry.label} began at the same time`,
        );
      } else {
        parts.push(
          `${entry.label} is also present`,
        );
      }

      if (onset) {
        parts.push(
          `${normalizeCode(onset)} onset`,
        );
      }

      sentences.push(
        `${parts.join(', ')}.`,
      );
    }

    if (course) {
      sentences.push(
        `The ${label} has been ${normalizeCode(
          course,
        )}.`,
      );
    }

    if (severity) {
      sentences.push(
        `At its worst the ${label} is ${normalizeCode(
          severity,
        )} in severity.`,
      );
    }

    if (aggravating) {
      sentences.push(
        `The ${label} is aggravated by ${normalizeCode(
          aggravating,
        )}.`,
      );
    }

    if (relieving) {
      sentences.push(
        `The ${label} is relieved by ${normalizeCode(
          relieving,
        )}.`,
      );
    }

    if (associated) {
      sentences.push(
        `Associated symptoms with the ${label}: ${associated}.`,
      );
    }

    details.push(
      ...canonicalDetailSentences(code, label, facts),
    );
  });

  sentences.push(...details);

  return sentences;
}

function composeSummaryChronology(
  parsed: ParsedSummaryEntry[],
): string[] {
  const sentences: string[] = [];

  if (parsed.length === 0) {
    return sentences;
  }

  const first = parsed[0];
  const firstLower = first.label.toLowerCase();

  if (first.duration) {
    sentences.push(
      `The illness began with ${firstLower} ${first.duration} ago.`,
    );
  } else {
    sentences.push(
      `The illness began with ${firstLower}.`,
    );
  }

  for (const entry of parsed.slice(1)) {
    if (
      entry.seconds > 0 &&
      first.seconds > 0 &&
      entry.seconds < first.seconds
    ) {
      sentences.push(
        `${sentenceCase(
          entry.label,
        )} developed ${offsetDurationText(
          first.seconds - entry.seconds,
          entry.unit,
        )} after the ${firstLower} began.`,
      );
    } else if (
      entry.seconds > 0 &&
      first.seconds > 0 &&
      entry.seconds === first.seconds
    ) {
      sentences.push(
        `${sentenceCase(
          entry.label,
        )} began at the same time.`,
      );
    } else {
      sentences.push(
        `${sentenceCase(
          entry.label,
        )} is also present.`,
      );
    }
  }

  return sentences;
}

// =============================================================================
// HPI OVERLAYS
//
// These run for both the structured and the legacy path, exactly as in the UI.
// =============================================================================

function composePaediatricOverlay(
  facts: EncounterFactRow[],
  birthDate: string | null,
): string[] {
  const sentences: string[] = [];

  const lifeStage =
    resolveLifeStageFromBirthDate(birthDate);

  if (
    !['neonate', 'infant', 'child'].includes(
      lifeStage,
    )
  ) {
    return sentences;
  }

  const feeding = value(
    facts,
    'FEEDING_STATUS',
  );

  if (feeding) {
    sentences.push(
      `Feeding is ${normalizeCode(
        feeding,
      )} compared with usual.`,
    );
  }

  const activity = value(
    facts,
    'ACTIVITY_STATUS',
  );

  if (activity) {
    sentences.push(
      `Activity is ${normalizeCode(
        activity,
      )} compared with baseline.`,
    );
  }

  if (isYes(facts, 'GRUNTING_PRESENT')) {
    sentences.push(
      'Grunting or unusual noisy breathing was reported.',
    );
  }

  if (isNo(facts, 'GRUNTING_PRESENT')) {
    sentences.push(
      'No grunting or unusual noisy breathing was reported.',
    );
  }

  return sentences;
}

function composePostOpOverlay(
  facts: EncounterFactRow[],
): string[] {
  const sentences: string[] = [];

  const postOpDay = value(
    facts,
    'POST_OPERATIVE_DAY',
  );

  const postOpProcedure = value(
    facts,
    'POST_OPERATIVE_PROCEDURE',
  );

  if (!postOpDay && !postOpProcedure) {
    return sentences;
  }

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
  const fever = value(facts, 'POSTOP_FEVER');
  const otherComplaints = value(
    facts,
    'POSTOP_OTHER_COMPLAINTS',
  );

  const overlay: Array<{
    value: string | null;
    text: string;
  }> = [
    {
      value: passedFlatus,
      text: `The patient has ${
        passedFlatus === 'YES' ? '' : 'not '
      }passed stool and flatus.`,
    },
    {
      value: dietTolerance,
      text: `The patient ${
        dietTolerance === 'YES'
          ? 'tolerates'
          : 'does not tolerate'
      } diet.`,
    },
    {
      value: mobility,
      text: `The patient ${
        mobility === 'YES' ? 'is' : 'is not'
      } able to walk around.`,
    },
    {
      value: bladderBowel,
      text: `Bladder and bowel habits are ${
        bladderBowel === 'YES'
          ? 'normal'
          : 'abnormal'
      }.`,
    },
    {
      value: woundPain,
      text: `There is ${
        woundPain === 'YES'
          ? 'pain at the surgical site'
          : 'no pain at the surgical site'
      }.`,
    },
    {
      value: woundDischarge,
      text: `There is ${
        woundDischarge === 'YES'
          ? 'discharge from the wound'
          : 'no discharge from the wound'
      }.`,
    },
    {
      value: fever,
      text: `The patient ${
        fever === 'YES' ? 'has' : 'has no'
      } hotness of body (fever).`,
    },
  ];

  for (const item of overlay) {
    if (item.value) {
      sentences.push(item.text);
    }
  }

  if (otherComplaints) {
    sentences.push(
      `Other post-operative complaints: ${otherComplaints}.`,
    );
  }

  return sentences;
}

// =============================================================================
// HPI COMPOSITION
// =============================================================================

function composeHpi(
  facts: EncounterFactRow[],
  structured: boolean,
  entries: ChiefComplaintEntry[],
  parsed: ParsedSummaryEntry[],
  birthDate: string | null,
): string | null {
  const sentences: string[] = [];

  if (structured) {
    sentences.push(
      ...composeStructuredChronology(
        facts,
        entries,
      ),
    );
  } else {
    sentences.push(
      ...composeSummaryChronology(parsed),
    );

    const followUpCourse = value(
      facts,
      'FOLLOW_UP_COURSE',
    );

    if (followUpCourse) {
      sentences.push(followUpCourse);
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
        `described as ${normalizeCode(
          severity,
        )} in severity`,
      );
    }

    if (openingParts.length > 0) {
      sentences.push(
        `${openingParts.join(', ')}.`,
      );
    }

    const details = facts
      .filter((fact) => fact.section === 'hpi')
      .map(formatFactValue)
      .filter(
        (next): next is string =>
          Boolean(next),
      );

    if (details.length > 0) {
      sentences.push(details.join('. '));
    }
  }

  sentences.push(
    ...composePaediatricOverlay(
      facts,
      birthDate,
    ),
  );

  sentences.push(...composePostOpOverlay(facts));

  if (sentences.length === 0) {
    return null;
  }

  return sentences.join(' ');
}

// =============================================================================
// COMPOSE
// =============================================================================

export interface ComposedPdfContent {
  patientName: string | null;
  mrn: string | null;
  age: number | null;
  occupation: string | null;
  residence: string | null;
  county: string | null;
  informantRelation: string | null;
  informantReliability: string | null;
  complaints: ClinicalComplaint[];
  hpi: string | null;
}

export function composePdfContent(
  snapshot: EncounterSnapshot,
): ComposedPdfContent {
  const facts = snapshot.facts;

  const structured =
    hasStructuredComplaints(facts);

  let complaints: ClinicalComplaint[] = [];
  let entries: ChiefComplaintEntry[] = [];
  let parsed: ParsedSummaryEntry[] = [];

  if (structured) {
    entries = chiefComplaintsOldestFirst(
      facts,
    );

    complaints = entries.map((entry, index) => {
      const duration: ClinicalDuration | null =
        entry.durationValue != null &&
        entry.durationValue > 0 &&
        entry.durationSeconds > 0
          ? {
              value: entry.durationValue,
              unit: entry.unit,
            }
          : null;

      return {
        id: `cc-${index}`,
        label: entry.label,
        patientWording: null,
        duration,
        sequence: index,
      };
    });
  } else {
    const summary =
      lastValue(
        facts,
        'PRESENTING_COMPLAINT',
      ) ??
      snapshot.context.presentingComplaint;

    parsed = summary
      ? parseSummary(summary)
      : [];

    complaints = parsed.map((entry, index) => {
      const duration: ClinicalDuration | null =
        entry.durationValue != null &&
        entry.durationValue > 0 &&
        entry.seconds > 0
          ? {
              value: entry.durationValue,
              unit: entry.unit,
            }
          : null;

      return {
        id: `presenting-${index}`,
        label: sentenceCase(entry.label),
        patientWording: null,
        duration,
        sequence: index,
      };
    });
  }

  const hpi = composeHpi(
    facts,
    structured,
    entries,
    parsed,
    snapshot.context.birthDate,
  );

  const reportedAge = Number(
    value(facts, 'REPORTED_AGE') ?? '',
  );

  const age =
    ageFromBirthDate(
      snapshot.context.birthDate,
    ) ??
    (Number.isFinite(reportedAge) &&
    reportedAge > 0
      ? reportedAge
      : null);

  return {
    patientName: value(facts, 'PATIENT_NAME'),
    mrn: value(facts, 'MRN'),
    age,
    occupation: value(facts, 'OCCUPATION'),
    residence: value(facts, 'RESIDENCE'),
    county: value(facts, 'COUNTY'),
    informantRelation: value(
      facts,
      'INFORMANT_RELATION',
    ),
    informantReliability: value(
      facts,
      'INFORMANT_RELIABILITY',
    ),
    complaints,
    hpi,
  };
}