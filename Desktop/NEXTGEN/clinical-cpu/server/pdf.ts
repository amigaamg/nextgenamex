// =============================================================================
// AMEXAN CLINICAL RECORD — PRODUCTION PDF GENERATOR
// =============================================================================
//
// PURPOSE
// -------
// Generates a concise, clinically readable AMEXAN encounter record.
//
// CORE DOCUMENTATION RULES
// ------------------------
// 1. Chief complaints are structured data, not generic fact dumps.
// 2. Maximum 4 presenting complaints.
// 3. Complaints are ordered oldest onset -> most recent onset.
// 4. Duration MUST contain a numeric value.
// 5. Duration unit defaults to DAYS.
// 6. Never print "for days", "for weeks", "for minutes", etc.
// 7. Never print raw Yes/No facts in the C/C section.
// 8. HPI is documented as prose from explicitly recorded HPI content.
// 9. The PDF does NOT infer diagnosis, causation, chronology, or reasoning.
// 10. Biodata is compact and clinically recognizable.
// 11. Two-column paper-saving layout is used throughout the clinical body.
// 12. Empty, duplicate, technical, and UI-only facts are suppressed.
// 13. The PDF represents the CURRENT committed clinical state only.
// 14. No historical UI snapshots are rendered.
// =============================================================================

const PAGE_WIDTH = 612;   // US Letter
const PAGE_HEIGHT = 792;

const MARGIN_LEFT = 44;
const MARGIN_RIGHT = 44;
const MARGIN_TOP = 48;
const MARGIN_BOTTOM = 46;

const CONTENT_WIDTH =
  PAGE_WIDTH - MARGIN_LEFT - MARGIN_RIGHT;

const COLUMN_GAP = 18;

const COLUMN_WIDTH =
  (CONTENT_WIDTH - COLUMN_GAP) / 2;

const FOOTER_Y = 28;

const TITLE_SIZE = 16;
const META_SIZE = 7.8;
const HEADING_SIZE = 9.5;
const BODY_SIZE = 9.6;

const BODY_LINE_FACTOR = 1.35;

const ACCENT_COLOR = '0.086 0.13 0.22';
const GRAY_COLOR = '0.42 0.44 0.50';
const LIGHT_RULE = '0.78';

const FONT_HELVETICA = 'F1';
const FONT_HELVETICA_BOLD = 'F2';
const FONT_TIMES = 'F3';
const FONT_TIMES_BOLD = 'F4';

// =============================================================================
// FONT WIDTHS
// =============================================================================

const HELVETICA_WIDTHS: Record<number, number> = {
  0x20: 278, 0x21: 278, 0x22: 355, 0x23: 556, 0x24: 556,
  0x25: 889, 0x26: 667, 0x27: 191, 0x28: 333, 0x29: 333,
  0x2a: 389, 0x2b: 584, 0x2c: 278, 0x2d: 333, 0x2e: 278,
  0x2f: 278,

  0x30: 556, 0x31: 556, 0x32: 556, 0x33: 556, 0x34: 556,
  0x35: 556, 0x36: 556, 0x37: 556, 0x38: 556, 0x39: 556,

  0x3a: 278, 0x3b: 278, 0x3c: 584, 0x3d: 584, 0x3e: 584,
  0x3f: 556, 0x40: 1015,

  0x41: 667, 0x42: 667, 0x43: 722, 0x44: 722, 0x45: 667,
  0x46: 611, 0x47: 778, 0x48: 722, 0x49: 278, 0x4a: 500,
  0x4b: 667, 0x4c: 556, 0x4d: 833, 0x4e: 722, 0x4f: 778,
  0x50: 667, 0x51: 778, 0x52: 722, 0x53: 667, 0x54: 611,
  0x55: 722, 0x56: 667, 0x57: 944, 0x58: 667, 0x59: 667,
  0x5a: 611,

  0x61: 556, 0x62: 556, 0x63: 500, 0x64: 556, 0x65: 556,
  0x66: 278, 0x67: 556, 0x68: 556, 0x69: 222, 0x6a: 222,
  0x6b: 500, 0x6c: 222, 0x6d: 833, 0x6e: 556, 0x6f: 556,
  0x70: 556, 0x71: 556, 0x72: 333, 0x73: 500, 0x74: 278,
  0x75: 556, 0x76: 500, 0x77: 722, 0x78: 500, 0x79: 500,
  0x7a: 500,
};

const TIMES_WIDTHS: Record<number, number> = {
  0x20: 250, 0x21: 333, 0x22: 408, 0x23: 500, 0x24: 500,
  0x25: 833, 0x26: 778, 0x27: 180, 0x28: 333, 0x29: 333,
  0x2a: 500, 0x2b: 564, 0x2c: 250, 0x2d: 333, 0x2e: 250,
  0x2f: 278,

  0x30: 500, 0x31: 500, 0x32: 500, 0x33: 500, 0x34: 500,
  0x35: 500, 0x36: 500, 0x37: 500, 0x38: 500, 0x39: 500,

  0x3a: 278, 0x3b: 278, 0x3c: 564, 0x3d: 564, 0x3e: 564,
  0x3f: 444, 0x40: 921,

  0x41: 722, 0x42: 667, 0x43: 667, 0x44: 722, 0x45: 611,
  0x46: 556, 0x47: 722, 0x48: 722, 0x49: 333, 0x4a: 389,
  0x4b: 722, 0x4c: 611, 0x4d: 889, 0x4e: 722, 0x4f: 722,
  0x50: 556, 0x51: 722, 0x52: 667, 0x53: 556, 0x54: 611,
  0x55: 722, 0x56: 722, 0x57: 944, 0x58: 722, 0x59: 722,
  0x5a: 611,

  0x61: 444, 0x62: 500, 0x63: 444, 0x64: 500, 0x65: 444,
  0x66: 333, 0x67: 500, 0x68: 500, 0x69: 278, 0x6a: 278,
  0x6b: 500, 0x6c: 278, 0x6d: 778, 0x6e: 500, 0x6f: 500,
  0x70: 500, 0x71: 500, 0x72: 333, 0x73: 389, 0x74: 278,
  0x75: 500, 0x76: 500, 0x77: 722, 0x78: 500, 0x79: 500,
  0x7a: 444,
};

// =============================================================================
// PDF TEXT HELPERS
// =============================================================================

function lineHeight(size: number): number {
  return Math.round(size * BODY_LINE_FACTOR);
}

interface PdfRun {
  text: string;
  bold?: boolean;
  serif?: boolean;
}

interface WordToken {
  text: string;
  bold: boolean;
  serif: boolean;
}

function fontIdForRun(
  bold: boolean,
  serif: boolean,
): string {
  if (serif) {
    return bold
      ? FONT_TIMES_BOLD
      : FONT_TIMES;
  }

  return bold
    ? FONT_HELVETICA_BOLD
    : FONT_HELVETICA;
}

function charWidth(
  fontId: string,
  code: number,
  size: number,
): number {
  let width: number;

  if (
    fontId === FONT_TIMES ||
    fontId === FONT_TIMES_BOLD
  ) {
    width = TIMES_WIDTHS[code] ?? 500;
  } else {
    width = HELVETICA_WIDTHS[code] ?? 556;

    if (fontId === FONT_HELVETICA_BOLD) {
      width = Math.round(width * 1.04);
    }
  }

  return (width / 1000) * size;
}

function tokenWidth(
  token: WordToken,
  size: number,
): number {
  const font = fontIdForRun(
    token.bold,
    token.serif,
  );

  let width = 0;

  for (const character of token.text) {
    width += charWidth(
      font,
      character.codePointAt(0) ?? 32,
      size,
    );
  }

  return width;
}

function escapePdfText(text: string): string {
  let output = '';

  for (const character of text) {
    const code = character.codePointAt(0) ?? 32;

    // WinAnsi-safe fallback.
    if (code > 255) {
      output += '?';
      continue;
    }

    if (
      character === '\\' ||
      character === '(' ||
      character === ')'
    ) {
      output += `\\${character}`;
    } else {
      output += character;
    }
  }

  return output;
}

function wrapRuns(
  runs: PdfRun[],
  maxWidth: number,
  size: number,
): PdfRun[][] {
  const tokens: WordToken[] = [];

  for (const run of runs) {
    const parts = run.text.split(/(\s+)/);

    for (const part of parts) {
      if (!part) continue;

      tokens.push({
        text: /^\s+$/.test(part)
          ? ' '
          : part,
        bold: Boolean(run.bold),
        serif: Boolean(run.serif),
      });
    }
  }

  const lines: WordToken[][] = [];

  let current: WordToken[] = [];
  let currentWidth = 0;

  for (const token of tokens) {
    const width = tokenWidth(token, size);

    if (
      current.length > 0 &&
      currentWidth + width > maxWidth
    ) {
      while (
        current.length > 0 &&
        current[current.length - 1].text === ' '
      ) {
        current.pop();
      }

      if (current.length > 0) {
        lines.push(current);
      }

      current = [];
      currentWidth = 0;
    }

    if (
      token.text === ' ' &&
      current.length === 0
    ) {
      continue;
    }

    if (width > maxWidth) {
      let remaining = token.text;

      while (remaining.length > 0) {
        let cut = remaining.length;

        while (
          cut > 1 &&
          tokenWidth(
            {
              text: remaining.slice(0, cut),
              bold: token.bold,
              serif: token.serif,
            },
            size,
          ) > maxWidth
        ) {
          cut -= 1;
        }

        lines.push([
          {
            text: remaining.slice(0, cut),
            bold: token.bold,
            serif: token.serif,
          },
        ]);

        remaining = remaining.slice(cut);
      }

      continue;
    }

    current.push(token);
    currentWidth += width;
  }

  while (
    current.length > 0 &&
    current[current.length - 1].text === ' '
  ) {
    current.pop();
  }

  if (current.length > 0) {
    lines.push(current);
  }

  return lines.map((tokensOnLine) => {
    const result: PdfRun[] = [];

    for (const token of tokensOnLine) {
      const last = result[result.length - 1];

      if (
        last &&
        Boolean(last.bold) === token.bold &&
        Boolean(last.serif) === token.serif
      ) {
        last.text += token.text;
      } else {
        result.push({
          text: token.text,
          bold: token.bold,
          serif: token.serif,
        });
      }
    }

    return result;
  });
}

// =============================================================================
// CLINICAL DATA CONTRACT
// =============================================================================
//
// IMPORTANT:
// The renderer understands these structures directly.
//
// Do NOT pass a serialized UI state such as:
// "FEVER for days; COUGH for minutes..."
//
// Instead the application should supply structured complaints.
//
// =============================================================================

export type ClinicalDurationUnit =
  | 'minutes'
  | 'hours'
  | 'days'
  | 'weeks'
  | 'months'
  | 'years';

export interface ClinicalDuration {
  value: number;
  unit: ClinicalDurationUnit;
}

export interface ClinicalComplaint {
  id: string;

  /**
   * Human-readable complaint.
   * Example: "Cough"
   */
  label: string;

  /**
   * Optional patient's own wording.
   */
  patientWording?: string | null;

  /**
   * Structured duration.
   * Unit should normally be "days".
   */
  duration?: ClinicalDuration | null;

  /**
   * Optional category.
   * Example: respiratory, general, gastrointestinal.
   */
  category?: string | null;

  /**
   * Stable insertion sequence.
   * Used only to resolve equal-duration ties.
   */
  sequence?: number;
}

export interface PdfFact {
  factCode: string;
  section: string;

  text: string | null;
  numeric: number | null;
  boolean: boolean | null;
  unitCode: string | null;
}

export interface EncounterPdfInput {
  encounterId: string;

  department?: string | null;

  patientName?: string | null;
  mrn?: string | null;

  sex?: string | null;
  age?: number | null;

  birthDate?: string | null;

  occupation?: string | null;
  residence?: string | null;
  county?: string | null;

  informantRelation?: string | null;
  informantReliability?: string | null;

  /**
   * CURRENT structured C/C state.
   *
   * This is the preferred source.
   */
  complaints?: ClinicalComplaint[];

  /**
   * Current HPI prose.
   *
   * This must contain only explicitly documented history.
   */
  hpi?: string | null;

  /**
   * Remaining structured clinical facts.
   *
   * Used for non-C/C sections.
   */
  facts?: PdfFact[];

  /**
   * Legacy field retained only for compatibility.
   *
   * It should NOT be used if complaints[] exists.
   */
  presentingComplaint?: string | null;
}

// =============================================================================
// DURATION
// =============================================================================

const UNIT_SECONDS: Record<
  ClinicalDurationUnit,
  number
> = {
  minutes: 60,
  hours: 3600,
  days: 86400,
  weeks: 604800,
  months: 2629800,
  years: 31557600,
};

function normalizeDurationUnit(
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

function normalizeDuration(
  duration?: ClinicalDuration | null,
): ClinicalDuration | null {
  if (!duration) return null;

  const value = Number(duration.value);

  if (!Number.isFinite(value) || value <= 0) {
    return null;
  }

  return {
    value,
    unit: normalizeDurationUnit(duration.unit),
  };
}

function formatDuration(
  duration?: ClinicalDuration | null,
): string | null {
  const normalized = normalizeDuration(duration);

  if (!normalized) {
    return null;
  }

  const rounded =
    Number.isInteger(normalized.value)
      ? String(normalized.value)
      : String(normalized.value);

  const singular =
    normalized.value === 1;

  const labels: Record<
    ClinicalDurationUnit,
    [string, string]
  > = {
    minutes: ['minute', 'minutes'],
    hours: ['hour', 'hours'],
    days: ['day', 'days'],
    weeks: ['week', 'weeks'],
    months: ['month', 'months'],
    years: ['year', 'years'],
  };

  return `${rounded} ${
    labels[normalized.unit][singular ? 0 : 1]
  }`;
}

function durationSeconds(
  duration?: ClinicalDuration | null,
): number {
  const normalized = normalizeDuration(duration);

  if (!normalized) {
    return 0;
  }

  return (
    normalized.value *
    UNIT_SECONDS[normalized.unit]
  );
}

// =============================================================================
// COMPLAINT NORMALIZATION
// =============================================================================

function cleanText(
  value: string | null | undefined,
): string | null {
  if (value == null) return null;

  const result = value
    .replace(/\s+/g, ' ')
    .trim();

  return result || null;
}

function sentenceCase(
  value: string,
): string {
  const text = cleanText(value);

  if (!text) return '';

  return (
    text.charAt(0).toUpperCase() +
    text.slice(1)
  );
}

function humanizeCode(
  code: string,
): string {
  return code
    .replace(/_/g, ' ')
    .toLowerCase()
    .replace(/\b\w/g, (letter) =>
      letter.toUpperCase(),
    );
}

function humanizeComplaintLabel(
  label: string,
): string {
  const cleaned = cleanText(label);

  if (!cleaned) return '';

  if (/^[A-Z0-9_]+$/.test(cleaned)) {
    return humanizeCode(cleaned);
  }

  return sentenceCase(cleaned);
}

function complaintKey(
  complaint: ClinicalComplaint,
): string {
  return [
    humanizeComplaintLabel(complaint.label)
      .toLowerCase(),
    formatDuration(complaint.duration) ?? '',
  ].join('|');
}

/**
 * Strict C/C normalization.
 *
 * Important:
 * - removes duplicates
 * - removes blank complaints
 * - limits to 4
 * - keeps current structured records
 * - sorts longest duration first = oldest onset first
 */
function normalizeComplaints(
  complaints: ClinicalComplaint[] | undefined,
): ClinicalComplaint[] {
  if (!complaints?.length) {
    return [];
  }

  const unique = new Map<
    string,
    ClinicalComplaint
  >();

  for (const complaint of complaints) {
    const label =
      humanizeComplaintLabel(complaint.label);

    if (!label) continue;

    const normalized: ClinicalComplaint = {
      ...complaint,
      label,
      duration: normalizeDuration(
        complaint.duration,
      ),
    };

    const key = complaintKey(normalized);

    if (!unique.has(key)) {
      unique.set(key, normalized);
    }
  }

  return Array.from(unique.values())
    .sort((a, b) => {
      const durationDifference =
        durationSeconds(b.duration) -
        durationSeconds(a.duration);

      if (durationDifference !== 0) {
        return durationDifference;
      }

      return (
        (a.sequence ?? 0) -
        (b.sequence ?? 0)
      );
    })
    .slice(0, 4);
}

// =============================================================================
// LEGACY PRESENTING-COMPLAINT COMPATIBILITY
// =============================================================================
//
// This is intentionally isolated.
//
// The application should migrate to complaints[].
//
// If the old database contains:
// "Cough for 4 days; Fever for 3 days; Dyspnoea for 1 day"
// this function can temporarily read it.
//
// It must NEVER interpret:
//
// "Yes"
// "No"
// "PRESENTING_COMPLAINT"
// "Changes not yet recorded"
//
// as clinical complaints.
// =============================================================================

const LEGACY_DURATION_REGEX =
  /^(.+?)\s+for\s+(\d+(?:\.\d+)?)\s+(minutes?|hours?|days?|weeks?|months?|years?)$/i;

function parseLegacyComplaints(
  value: string | null | undefined,
): ClinicalComplaint[] {
  const text = cleanText(value);

  if (!text) return [];

  return text
    .split(';')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part, index) => {
      const match =
        LEGACY_DURATION_REGEX.exec(part);

      if (!match) {
        return {
          id: `legacy-${index}`,
          label: humanizeComplaintLabel(part),
          duration: null,
          sequence: index,
        };
      }

      return {
        id: `legacy-${index}`,
        label: humanizeComplaintLabel(
          match[1],
        ),
        duration: {
          value: Number(match[2]),
          unit: normalizeDurationUnit(
            match[3],
          ),
        },
        sequence: index,
      };
    })
    .filter((item) => {
      const lower = item.label.toLowerCase();

      // UI/boolean leakage must never enter C/C.
      return (
        lower !== 'yes' &&
        lower !== 'no' &&
        lower !== 'true' &&
        lower !== 'false'
      );
    });
}

// =============================================================================
// SEX / BIODATA
// =============================================================================

function formatSex(
  value: string | null | undefined,
): string | null {
  const normalized = cleanText(value);

  if (!normalized) return null;

  const map: Record<string, string> = {
    male: 'Male',
    m: 'Male',
    female: 'Female',
    f: 'Female',
    intersex: 'Intersex',
    unknown: 'Unknown',
    other: 'Other',
  };

  return (
    map[normalized.toLowerCase()] ??
    sentenceCase(normalized)
  );
}

function formatAge(
  age: number | null | undefined,
): string | null {
  if (
    age == null ||
    !Number.isFinite(age) ||
    age < 0
  ) {
    return null;
  }

  return `${age} ${
    age === 1 ? 'year' : 'years'
  }`;
}

// =============================================================================
// SECTION CONFIGURATION
// =============================================================================

const SECTION_TITLES: Record<
  string,
  string
> = {
  pmh: 'Past Medical History',
  psh: 'Past Surgical History',
  dh: 'Drug History',
  allergies: 'Allergies',
  fh: 'Family History',
  sh: 'Social History',
  occupational: 'Occupational History',
  sexual: 'Sexual History',
  obstetric_history: 'Obstetric History',
  gynae: 'Gynaecological History',
  gynaecological: 'Gynaecological History',
  birth: 'Birth History',
  growth: 'Growth and Development',
  immunization: 'Immunization',
  nutrition: 'Nutrition',
  psychiatric: 'Psychiatric History',
  substance: 'Substance Use History',
  examination: 'Examination',
  vitals: 'Vital Signs',
  investigations: 'Investigations',
  assessment: 'Assessment',
  plan: 'Plan',
};

const SECTION_ORDER = [
  'pmh',
  'psh',
  'dh',
  'allergies',
  'fh',
  'sh',
  'occupational',
  'sexual',
  'obstetric_history',
  'gynae',
  'gynaecological',
  'birth',
  'growth',
  'immunization',
  'nutrition',
  'psychiatric',
  'substance',
  'examination',
  'vitals',
  'investigations',
  'assessment',
  'plan',
];

// =============================================================================
// PDF BUILDER
// =============================================================================

class PdfBuilder {
  private pages: string[][] = [[]];

  private column = 0;

  private columnY =
    PAGE_HEIGHT - MARGIN_TOP;

  private get currentPage(): string[] {
    return this.pages[
      this.pages.length - 1
    ];
  }

  private columnX(): number {
    return (
      MARGIN_LEFT +
      this.column *
        (COLUMN_WIDTH + COLUMN_GAP)
    );
  }

  private ensureColumnSpace(
    size: number,
  ): void {
    if (
      this.columnY -
        lineHeight(size) <
      MARGIN_BOTTOM
    ) {
      if (this.column === 0) {
        this.column = 1;
        this.columnY =
          PAGE_HEIGHT - MARGIN_TOP;
      } else {
        this.pages.push([]);
        this.column = 0;
        this.columnY =
          PAGE_HEIGHT - MARGIN_TOP;
      }
    }
  }

  addColumnGap(
    amount: number,
  ): void {
    this.ensureColumnSpace(1);
    this.columnY -= amount;
  }

  addColumnLine(options: {
    runs: PdfRun[];
    size?: number;
    indent?: number;
    gap?: number;
    gray?: boolean;
  }): void {
    const {
      runs,
      size = BODY_SIZE,
      indent = 0,
      gap = 0,
      gray = false,
    } = options;

    const wrapped = wrapRuns(
      runs,
      COLUMN_WIDTH - indent,
      size,
    );

    for (const lineRuns of wrapped) {
      this.ensureColumnSpace(size);

      let x =
        this.columnX() + indent;

      for (const run of lineRuns) {
        const font =
          fontIdForRun(
            Boolean(run.bold),
            Boolean(run.serif),
          );

        const color = gray
          ? `${GRAY_COLOR} rg`
          : '0 0 0 rg';

        this.currentPage.push(
          [
            'BT',
            color,
            `${font} ${size} Tf`,
            '0 Tc',
            `1 0 0 1 ${x} ${this.columnY} Tm`,
            `(${escapePdfText(run.text)}) Tj`,
            'ET',
          ].join(' '),
        );

        x += tokenWidth(
          {
            text: run.text,
            bold: Boolean(run.bold),
            serif: Boolean(run.serif),
          },
          size,
        );
      }

      this.columnY -= lineHeight(size);
    }

    if (gap > 0) {
      this.addColumnGap(gap);
    }
  }

  addHeading(
    text: string,
  ): void {
    this.ensureColumnSpace(
      HEADING_SIZE + 8,
    );

    this.columnY -= 3;

    const x = this.columnX();

    this.currentPage.push(
      [
        `${ACCENT_COLOR} rg`,
        `${x} ${this.columnY - 2}`,
        `3 ${HEADING_SIZE + 3}`,
        're f',
      ].join(' '),
    );

    this.addColumnLine({
      runs: [
        {
          text: text.toUpperCase(),
          bold: true,
          serif: false,
        },
      ],
      size: HEADING_SIZE,
      indent: 9,
      gap: 3,
    });
  }

  addRule(): void {
    this.ensureColumnSpace(3);

    const x = this.columnX();

    this.currentPage.push(
      [
        `${LIGHT_RULE} G`,
        '0.5 w',
        `${x} ${this.columnY - 2}`,
        `${COLUMN_WIDTH} 0.5 re S`,
      ].join(' '),
    );

    this.columnY -= 5;
  }

  addClinicalParagraph(
    text: string,
  ): void {
    const cleaned = cleanText(text);

    if (!cleaned) return;

    this.addColumnLine({
      runs: [
        {
          text: cleaned,
          serif: true,
        },
      ],
      size: BODY_SIZE,
      gap: 2,
    });
  }

  build(
    footerText: string,
  ): Buffer {
    const pageCount =
      this.pages.length;

    for (
      let index = 0;
      index < pageCount;
      index++
    ) {
      const page =
        this.pages[index];

      // Footer rule.
      page.push(
        [
          `${LIGHT_RULE} G`,
          '0.5 w',
          `${MARGIN_LEFT} ${FOOTER_Y + 10}`,
          `${CONTENT_WIDTH} 0.5 re S`,
        ].join(' '),
      );

      // Footer left.
      page.push(
        [
          'BT',
          `${GRAY_COLOR} rg`,
          '/F1 7 Tf',
          `1 0 0 1 ${MARGIN_LEFT} ${FOOTER_Y} Tm`,
          `(${escapePdfText(footerText)}) Tj`,
          'ET',
        ].join(' '),
      );

      const pageText =
        `Page ${index + 1} of ${pageCount}`;

      const width = tokenWidth(
        {
          text: pageText,
          bold: false,
          serif: false,
        },
        7,
      );

      page.push(
        [
          'BT',
          `${GRAY_COLOR} rg`,
          '/F1 7 Tf',
          `1 0 0 1 ${
            PAGE_WIDTH -
            MARGIN_RIGHT -
            width
          } ${FOOTER_Y} Tm`,
          `(${escapePdfText(pageText)}) Tj`,
          'ET',
        ].join(' '),
      );
    }

    return this.assemble();
  }

  private assemble(): Buffer {
    const chunks: Buffer[] = [];

    const offsets: number[] = [0];

    const push = (
      text: string,
    ): void => {
      const buffer =
        Buffer.from(text, 'latin1');

      chunks.push(buffer);

      offsets.push(
        offsets[offsets.length - 1] +
          buffer.length,
      );
    };

    const CATALOG = 1;
    const PAGES = 2;

    let nextObject = 3;

    const pageObjects: number[] = [];
    const contentObjects: number[] = [];

    for (
      let i = 0;
      i < this.pages.length;
      i++
    ) {
      pageObjects.push(nextObject++);
      contentObjects.push(nextObject++);
    }

    const fontObjects: Record<
      string,
      number
    > = {};

    for (const font of [
      FONT_HELVETICA,
      FONT_HELVETICA_BOLD,
      FONT_TIMES,
      FONT_TIMES_BOLD,
    ]) {
      fontObjects[font] =
        nextObject++;
    }

    const totalObjects =
      nextObject - 1;

    push('%PDF-1.4\n');

    push(
      `${CATALOG} 0 obj\n` +
        `<< /Type /Catalog /Pages ${PAGES} 0 R >>\n` +
        `endobj\n`,
    );

    push(
      `${PAGES} 0 obj\n` +
        `<< /Type /Pages /Kids [` +
        pageObjects
          .map((object) => `${object} 0 R`)
          .join(' ') +
        `] /Count ${this.pages.length} >>\n` +
        `endobj\n`,
    );

    for (
      let i = 0;
      i < this.pages.length;
      i++
    ) {
      const fontDictionary = [
        FONT_HELVETICA,
        FONT_HELVETICA_BOLD,
        FONT_TIMES,
        FONT_TIMES_BOLD,
      ]
        .map(
          (font) =>
            `/${font} ${fontObjects[font]} 0 R`,
        )
        .join(' ');

      push(
        `${pageObjects[i]} 0 obj\n` +
          `<< /Type /Page ` +
          `/Parent ${PAGES} 0 R ` +
          `/MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] ` +
          `/Resources << /Font << ${fontDictionary} >> >> ` +
          `/Contents ${contentObjects[i]} 0 R >>\n` +
          `endobj\n`,
      );

      const content =
        Buffer.from(
          this.pages[i].join('\n'),
          'latin1',
        );

      push(
        `${contentObjects[i]} 0 obj\n` +
          `<< /Length ${content.length} >>\n` +
          `stream\n`,
      );

      chunks.push(content);

      offsets.push(
        offsets[offsets.length - 1] +
          content.length,
      );

      push(
        '\nendstream\nendobj\n',
      );
    }

    const fontBases: Record<
      string,
      string
    > = {
      F1: '/Helvetica',
      F2: '/Helvetica-Bold',
      F3: '/Times-Roman',
      F4: '/Times-Bold',
    };

    for (const font of [
      FONT_HELVETICA,
      FONT_HELVETICA_BOLD,
      FONT_TIMES,
      FONT_TIMES_BOLD,
    ]) {
      push(
        `${fontObjects[font]} 0 obj\n` +
          `<< /Type /Font ` +
          `/Subtype /Type1 ` +
          `/BaseFont ${fontBases[font]} ` +
          `/Encoding /WinAnsiEncoding >>\n` +
          `endobj\n`,
      );
    }

    const xrefStart =
      offsets[offsets.length - 1];

    push(
      `xref\n0 ${totalObjects + 1}\n`,
    );

    push(
      '0000000000 65535 f \n',
    );

    for (
      let i = 1;
      i <= totalObjects;
      i++
    ) {
      push(
        `${String(offsets[i]).padStart(
          10,
          '0',
        )} 00000 n \n`,
      );
    }

    push(
      `trailer\n` +
        `<< /Size ${totalObjects + 1} /Root ${CATALOG} 0 R >>\n` +
        `startxref\n` +
        `${xrefStart}\n` +
        `%%EOF\n`,
    );

    return Buffer.concat(chunks);
  }
}

// =============================================================================
// CLINICAL FACT HELPERS
// =============================================================================

function factValue(
  fact: PdfFact,
): string | null {
  const text = cleanText(fact.text);

  if (text) {
    return text;
  }

  if (
    fact.numeric != null &&
    Number.isFinite(fact.numeric)
  ) {
    return `${fact.numeric}${
      fact.unitCode
        ? ` ${fact.unitCode}`
        : ''
    }`;
  }

  // IMPORTANT:
  //
  // Generic boolean facts are deliberately not
  // converted to "Yes"/"No" automatically.
  //
  // They must be interpreted by their owning
  // clinical section.
  //
  return null;
}

function isTechnicalFact(
  fact: PdfFact,
): boolean {
  const code =
    fact.factCode
      .trim()
      .toUpperCase();

  return [
    'PRESENTING_COMPLAINT',
    'CHIEF_COMPLAINT',
    'CHANGES_NOT_RECORDED',
    'REQUIRED',
    'DIRTY',
    'DRAFT',
    'SYNC_STATE',
    'LAST_UPDATED',
    'UI_STATE',
  ].includes(code);
}

// =============================================================================
// SECTION FACT CLEANING
// =============================================================================

function cleanSectionFacts(
  facts: PdfFact[],
): PdfFact[] {
  const result: PdfFact[] = [];

  for (const fact of facts) {
    if (isTechnicalFact(fact)) {
      continue;
    }

    const value = factValue(fact);

    if (!value) {
      continue;
    }

    // Generic Yes/No values are not clinically
    // useful without their semantic field.
    //
    // Do not allow raw boolean leakage.
    if (
      /^(yes|no|true|false)$/i.test(
        value,
      )
    ) {
      continue;
    }

    result.push(fact);
  }

  return result;
}

// =============================================================================
// HPI
// =============================================================================
//
// CRITICAL RULE:
//
// The PDF does NOT construct:
// "The illness began with cough 4 days ago..."
//
// merely because cough has a 4-day duration.
//
// That is an inference.
//
// AMEXAN stores C/C and HPI separately.
// C/C documents the complaints.
// HPI documents the history actually captured.
//
// =============================================================================

function normalizeHpi(
  value: string | null | undefined,
): string | null {
  const text = cleanText(value);

  if (!text) {
    return null;
  }

  return text;
}

// =============================================================================
// MAIN RENDERER
// =============================================================================

export function renderEncounterPdf(
  input: EncounterPdfInput,
): Buffer {
  const builder =
    new PdfBuilder();

  const encounterId =
    cleanText(input.encounterId) ??
    'UNKNOWN';

  const encounterLabel =
    `ENC-${encounterId
      .replace(/[^a-zA-Z0-9]/g, '')
      .slice(0, 6)
      .toUpperCase()}`;

  const generatedAt =
    new Date().toLocaleDateString(
      'en-GB',
      {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      },
    );

  // ===========================================================================
  // LETTERHEAD
  // ===========================================================================

  builder.addColumnLine({
    runs: [
      {
        text: 'AMEXAN CLINICAL RECORD',
        bold: true,
        serif: false,
      },
    ],
    size: TITLE_SIZE,
    gap: 2,
  });

  builder.addColumnLine({
    runs: [
      {
        text: `${encounterLabel} · ${generatedAt}`,
        serif: false,
      },
    ],
    size: META_SIZE,
    gray: true,
    gap: 5,
  });

  // Full-width visual rule is intentionally omitted
  // from the two-column clinical body.
  //
  // This prevents wasted vertical space.

  // ===========================================================================
  // BIODATA
  // ===========================================================================

  const patientName =
    cleanText(input.patientName) ??
    'Patient';

  const biodataParts: string[] = [];

  const age = formatAge(input.age);

  if (age) {
    biodataParts.push(age);
  }

  const sex = formatSex(input.sex);

  if (sex) {
    biodataParts.push(sex);
  }

  if (cleanText(input.mrn)) {
    biodataParts.push(
      `MRN ${cleanText(input.mrn)}`,
    );
  }

  builder.addHeading('Patient');

  // Deliberately:
  //
  // Kevin Kiruja
  //
  // NOT:
  //
  // Patient Name: Kevin Kiruja
  //
  builder.addColumnLine({
    runs: [
      {
        text: patientName,
        bold: true,
        serif: true,
      },
    ],
    size: 11,
    gap: 1,
  });

  if (biodataParts.length > 0) {
    builder.addColumnLine({
      runs: [
        {
          text: biodataParts.join(' · '),
          serif: false,
        },
      ],
      size: META_SIZE,
      gray: true,
      gap: 2,
    });
  }

  // Concise origin line — only what was actually recorded.
  const origin = [
    cleanText(input.occupation),
    cleanText(input.residence),
    cleanText(input.county),
  ]
    .filter((part): part is string => Boolean(part))
    .join(' · ');

  if (origin) {
    builder.addColumnLine({
      runs: [
        {
          text: origin,
          serif: false,
        },
      ],
      size: META_SIZE,
      gray: true,
      gap: 2,
    });
  }

  const informantRelation =
    cleanText(input.informantRelation);

  const informantReliability =
    cleanText(input.informantReliability);

  const informant = [
    informantRelation
      ? `Informant: ${informantRelation.toLowerCase()}`
      : null,
    informantReliability
      ? informantReliability.toLowerCase()
      : null,
  ]
    .filter((part): part is string => Boolean(part))
    .join(', ');

  if (informant) {
    builder.addColumnLine({
      runs: [
        {
          text: informant,
          serif: false,
        },
      ],
      size: META_SIZE,
      gray: true,
      gap: 4,
    });
  }

  // ===========================================================================
  // CHIEF COMPLAINT
  // ===========================================================================

  let complaints =
    normalizeComplaints(
      input.complaints,
    );

  // Temporary legacy compatibility.
  if (complaints.length === 0) {
    complaints =
      normalizeComplaints(
        parseLegacyComplaints(
          input.presentingComplaint,
        ),
      );
  }

  if (complaints.length > 0) {
    builder.addHeading(
      'Chief Complaint',
    );

    complaints.forEach(
      (complaint, index) => {
        const duration =
          formatDuration(
            complaint.duration,
          );

        const label =
          humanizeComplaintLabel(
            complaint.label,
          );

        const wording =
          cleanText(
            complaint.patientWording,
          );

        const runs: PdfRun[] = [
          {
            text: `${index + 1}. `,
            bold: true,
            serif: false,
          },
          {
            text: label,
            bold: true,
            serif: true,
          },
        ];

        if (duration) {
          runs.push({
            text: ` for ${duration}.`,
            serif: true,
          });
        } else {
          runs.push({
            text: '.',
            serif: true,
          });
        }

        builder.addColumnLine({
          runs,
          size: BODY_SIZE,
          gap: wording ? 0 : 1,
        });

        // Patient's own wording is optional and subordinate.
        //
        // It is shown only when explicitly recorded.
        if (wording) {
          builder.addColumnLine({
            runs: [
              {
                text: `"${wording}"`,
                serif: true,
              },
            ],
            size: 8.5,
            gray: true,
            indent: 13,
            gap: 1,
          });
        }
      },
    );

    builder.addColumnGap(4);
  }

  // ===========================================================================
  // HPI
  // ===========================================================================

  const hpi =
    normalizeHpi(input.hpi);

  if (hpi) {
    builder.addHeading('HPI');

    builder.addClinicalParagraph(hpi);

    builder.addColumnGap(4);
  }

  // ===========================================================================
  // REMAINING FACTS
  // ===========================================================================

  const facts =
    (input.facts ?? [])
      .filter(
        (fact) =>
          fact.section !==
            'biodata' &&
          fact.section !==
            'chief_complaint' &&
          fact.section !== 'hpi',
      );

  const factsBySection =
    new Map<string, PdfFact[]>();

  for (const fact of facts) {
    const cleaned =
      cleanSectionFacts([fact]);

    if (cleaned.length === 0) {
      continue;
    }

    const current =
      factsBySection.get(
        fact.section,
      ) ?? [];

    current.push(...cleaned);

    factsBySection.set(
      fact.section,
      current,
    );
  }

  // ===========================================================================
  // CANONICAL SECTION ORDER
  // ===========================================================================

  for (const section of SECTION_ORDER) {
    const sectionFacts =
      factsBySection.get(section);

    if (
      !sectionFacts ||
      sectionFacts.length === 0
    ) {
      continue;
    }

    const title =
      SECTION_TITLES[section];

    if (!title) {
      continue;
    }

    builder.addHeading(title);

    // -------------------------------------------------------------------------
    // Clinical prose sections.
    // -------------------------------------------------------------------------

    const proseSections =
      new Set([
        'pmh',
        'psh',
        'dh',
        'allergies',
        'fh',
        'sh',
        'occupational',
        'sexual',
        'obstetric_history',
        'gynae',
        'gynaecological',
        'birth',
        'growth',
        'immunization',
        'nutrition',
        'psychiatric',
        'substance',
        'assessment',
        'plan',
      ]);

    if (
      proseSections.has(section)
    ) {
      const values =
        sectionFacts
          .map(factValue)
          .filter(
            (
              value,
            ): value is string =>
              Boolean(value),
          );

      if (values.length > 0) {
        builder.addClinicalParagraph(
          values
            .map((value) =>
              value.replace(
                /[.\s]+$/,
                '',
              ),
            )
            .join('. ') + '.',
        );
      }
    }

    // -------------------------------------------------------------------------
    // Examination / vitals / investigations
    // remain compact and list-like.
    // -------------------------------------------------------------------------

    else {
      for (
        const fact of sectionFacts
      ) {
        const value =
          factValue(fact);

        if (!value) {
          continue;
        }

        const label =
          humanizeCode(
            fact.factCode,
          );

        builder.addColumnLine({
          runs: [
            {
              text: `${label}: `,
              bold: true,
              serif: false,
            },
            {
              text: value,
              serif: true,
            },
          ],
          size: BODY_SIZE,
          gap: 1,
        });
      }
    }

    builder.addColumnGap(4);
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  return builder.build(
    `AMEXAN Clinical Record · ${encounterLabel}`,
  );
}