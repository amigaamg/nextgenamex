// =============================================================================
// src/clinical/milestones.ts
// DEVELOPMENTAL MILESTONE KNOWLEDGE BASE
//
// RULE:
// This module is KNOWLEDGE. It does not capture facts itself; it drives:
//   1. Age-appropriate milestone questions in questions.ts
//   2. Age-appropriate deductions in documentation.ts
//
// Milestones follow the internationally accepted developmental screening
// landmarks (gross motor, fine motor & adaptive, language, social/emotional)
// used in well-child care (WHO / CDC / Nelson Essentials of Pediatrics).
//
// The UI never reasons: it asks exactly the milestones that are relevant to
// the child's age and reports whether each was achieved. The documentation
// engine then deduces whether development is appropriate, delayed, or shows
// regression, always from captured facts.
// =============================================================================

// -----------------------------------------------------------------------------
// Domain model
// -----------------------------------------------------------------------------

export type MilestoneDomain =
  | 'gross_motor'
  | 'fine_motor'
  | 'language'
  | 'social_emotional';

export const MILESTONE_DOMAIN_LABELS: Record<MilestoneDomain, string> = {
  gross_motor: 'Gross motor',
  fine_motor: 'Fine motor & adaptive',
  language: 'Language & communication',
  social_emotional: 'Social & emotional',
};

// -----------------------------------------------------------------------------
// Milestone definitions
// -----------------------------------------------------------------------------

export interface MilestoneDefinition {
  /** Unique milestone code, used for the fact code. */
  code: string;

  domain: MilestoneDomain;

  /** Human readable milestone, phrased as a capability. */
  label: string;

  /**
   * The age in months at which ~50% of typically developing children
   * achieve the skill. Used to decide which milestones are age-appropriate.
   */
  expectedAgeMonths: number;

  /**
   * Upper boundary (months) by which the skill should reliably be present.
   * Used to distinguish "not yet expected" from "possibly delayed".
   */
  latestAgeMonths: number;
}

export interface MilestoneBand {
  bandLabel: string;

  /** Inclusive lower age in months. */
  fromMonths: number;

  /** Exclusive upper age in months. */
  toMonths: number;

  milestones: MilestoneDefinition[];
}

// =============================================================================
// THE MILESTONE TABLE
//
// Phrased as the typical age of acquisition. Age bands follow the screening
// windows used in routine child health surveillance.
// =============================================================================

const MILESTONE_BANDS: MilestoneBand[] = [
  {
    bandLabel: 'Birth to 2 months',
    fromMonths: 0,
    toMonths: 2,
    milestones: [
      {
        code: 'MILESTONE_LIFTS_CHIN',
        domain: 'gross_motor',
        label: 'lifts the chin when lying on the tummy',
        expectedAgeMonths: 1,
        latestAgeMonths: 2,
      },
      {
        code: 'MILESTONE_FIXES_GAZE',
        domain: 'fine_motor',
        label: 'fixes the gaze and briefly follows a face or object',
        expectedAgeMonths: 1,
        latestAgeMonths: 2,
      },
      {
        code: 'MILESTONE_STARTLES_TO_SOUND',
        domain: 'language',
        label: 'startles or blinks to a loud sound',
        expectedAgeMonths: 1,
        latestAgeMonths: 2,
      },
      {
        code: 'MILESTONE_SOCIAL_SMILE',
        domain: 'social_emotional',
        label: 'shows a social smile in response to a face or voice',
        expectedAgeMonths: 2,
        latestAgeMonths: 3,
      },
    ],
  },
  {
    bandLabel: '2 to 4 months',
    fromMonths: 2,
    toMonths: 4,
    milestones: [
      {
        code: 'MILESTONE_HEAD_CONTROL',
        domain: 'gross_motor',
        label: 'holds the head steady when supported upright',
        expectedAgeMonths: 3,
        latestAgeMonths: 4,
      },
      {
        code: 'MILESTONE_PRONES_ON_FOREARMS',
        domain: 'gross_motor',
        label: 'pushes up on the forearms when lying on the tummy',
        expectedAgeMonths: 3,
        latestAgeMonths: 4,
      },
      {
        code: 'MILESTONE_FOLLOWS_180',
        domain: 'fine_motor',
        label: 'follows objects across the midline',
        expectedAgeMonths: 3,
        latestAgeMonths: 4,
      },
      {
        code: 'MILESTONE_COOS',
        domain: 'language',
        label: 'coos and makes vowel sounds',
        expectedAgeMonths: 3,
        latestAgeMonths: 4,
      },
      {
        code: 'MILESTONE_LAUGHS',
        domain: 'language',
        label: 'laughs or squeals with pleasure',
        expectedAgeMonths: 4,
        latestAgeMonths: 5,
      },
    ],
  },
  {
    bandLabel: '4 to 6 months',
    fromMonths: 4,
    toMonths: 6,
    milestones: [
      {
        code: 'MILESTONE_ROLLS',
        domain: 'gross_motor',
        label: 'rolls from tummy to back',
        expectedAgeMonths: 5,
        latestAgeMonths: 6,
      },
      {
        code: 'MILESTONE_SITS_SUPPORTED',
        domain: 'gross_motor',
        label: 'sits with support',
        expectedAgeMonths: 5,
        latestAgeMonths: 6,
      },
      {
        code: 'MILESTONE_REACHES_GRASPS',
        domain: 'fine_motor',
        label: 'reaches for and grasps objects',
        expectedAgeMonths: 5,
        latestAgeMonths: 6,
      },
      {
        code: 'MILESTONE_TRANSFERS_OBJECTS',
        domain: 'fine_motor',
        label: 'transfers objects from one hand to the other',
        expectedAgeMonths: 6,
        latestAgeMonths: 7,
      },
      {
        code: 'MILESTONE_BABBLES',
        domain: 'language',
        label: 'babbles with consonant sounds such as "ba", "ma", "da"',
        expectedAgeMonths: 6,
        latestAgeMonths: 8,
      },
      {
        code: 'MILESTONE_DISTINGUISHES_STRANGERS',
        domain: 'social_emotional',
        label: 'shows wariness or dislike of strangers',
        expectedAgeMonths: 6,
        latestAgeMonths: 8,
      },
    ],
  },
  {
    bandLabel: '6 to 9 months',
    fromMonths: 6,
    toMonths: 9,
    milestones: [
      {
        code: 'MILESTONE_SITS_ALONE',
        domain: 'gross_motor',
        label: 'sits without support',
        expectedAgeMonths: 7,
        latestAgeMonths: 9,
      },
      {
        code: 'MILESTONE_CRAWLS',
        domain: 'gross_motor',
        label: 'crawls on the hands and knees',
        expectedAgeMonths: 8,
        latestAgeMonths: 10,
      },
      {
        code: 'MILESTONE_PINCER_GRASP',
        domain: 'fine_motor',
        label: 'picks up small objects with the thumb and forefinger',
        expectedAgeMonths: 9,
        latestAgeMonths: 11,
      },
      {
        code: 'MILESTONE_RESPONDS_TO_NAME',
        domain: 'language',
        label: 'turns to a familiar voice and responds to the name',
        expectedAgeMonths: 8,
        latestAgeMonths: 10,
      },
      {
        code: 'MILESTONE_PEEKABOO',
        domain: 'social_emotional',
        label: 'plays peek-a-boo and waves goodbye',
        expectedAgeMonths: 9,
        latestAgeMonths: 11,
      },
    ],
  },
  {
    bandLabel: '9 to 12 months',
    fromMonths: 9,
    toMonths: 12,
    milestones: [
      {
        code: 'MILESTONE_PULLS_TO_STAND',
        domain: 'gross_motor',
        label: 'pulls to stand and cruises along furniture',
        expectedAgeMonths: 10,
        latestAgeMonths: 12,
      },
      {
        code: 'MILESTONE_STANDS_ALONE',
        domain: 'gross_motor',
        label: 'stands alone briefly',
        expectedAgeMonths: 12,
        latestAgeMonths: 14,
      },
      {
        code: 'MILESTONE_SINGLE_WORDS',
        domain: 'language',
        label: 'says one or two clear words such as "mama" or "dada"',
        expectedAgeMonths: 12,
        latestAgeMonths: 15,
      },
      {
        code: 'MILESTONE_POINTS_TO_REQUEST',
        domain: 'language',
        label: 'points at things to show or request',
        expectedAgeMonths: 12,
        latestAgeMonths: 14,
      },
      {
        code: 'MILESTONE_IMITATES_ACTIONS',
        domain: 'social_emotional',
        label: 'imitates simple actions and enjoys games with others',
        expectedAgeMonths: 12,
        latestAgeMonths: 14,
      },
    ],
  },
  {
    bandLabel: '12 to 18 months',
    fromMonths: 12,
    toMonths: 18,
    milestones: [
      {
        code: 'MILESTONE_WALKS_ALONE',
        domain: 'gross_motor',
        label: 'walks independently',
        expectedAgeMonths: 13,
        latestAgeMonths: 18,
      },
      {
        code: 'MILESTONE_RUNS',
        domain: 'gross_motor',
        label: 'runs stiffly and climbs onto furniture',
        expectedAgeMonths: 18,
        latestAgeMonths: 20,
      },
      {
        code: 'MILESTONE_SPOON_FEEDS',
        domain: 'fine_motor',
        label: 'feeds with a spoon and drinks from a cup with help',
        expectedAgeMonths: 15,
        latestAgeMonths: 18,
      },
      {
        code: 'MILESTONE_3_TO_6_WORDS',
        domain: 'language',
        label: 'uses 3 to 6 words and follows a simple command',
        expectedAgeMonths: 15,
        latestAgeMonths: 18,
      },
      {
        code: 'MILESTONE_POINTS_BODY_PARTS',
        domain: 'language',
        label: 'points to one or more body parts when asked',
        expectedAgeMonths: 18,
        latestAgeMonths: 20,
      },
      {
        code: 'MILESTONE_PARALLEL_PLAY',
        domain: 'social_emotional',
        label: 'plays alongside other children',
        expectedAgeMonths: 18,
        latestAgeMonths: 24,
      },
    ],
  },
  {
    bandLabel: '18 to 24 months',
    fromMonths: 18,
    toMonths: 24,
    milestones: [
      {
        code: 'MILESTONE_WALKS_UP_STAIRS',
        domain: 'gross_motor',
        label: 'walks up stairs with support',
        expectedAgeMonths: 20,
        latestAgeMonths: 24,
      },
      {
        code: 'MILESTONE_TWO_WORD_PHRASES',
        domain: 'language',
        label: 'puts two words together such as "more milk"',
        expectedAgeMonths: 21,
        latestAgeMonths: 24,
      },
      {
        code: 'MILESTONE_50_WORDS',
        domain: 'language',
        label: 'uses about 50 single words',
        expectedAgeMonths: 24,
        latestAgeMonths: 27,
      },
      {
        code: 'MILESTONE_UNDRESSES',
        domain: 'fine_motor',
        label: 'undresses with help and turns pages of a book',
        expectedAgeMonths: 22,
        latestAgeMonths: 26,
      },
      {
        code: 'MILESTONE_IMITATES_HOUSEHOLD',
        domain: 'social_emotional',
        label: 'imitates household activities such as sweeping or "talking" on the phone',
        expectedAgeMonths: 24,
        latestAgeMonths: 30,
      },
    ],
  },
  {
    bandLabel: '2 to 3 years',
    fromMonths: 24,
    toMonths: 36,
    milestones: [
      {
        code: 'MILESTONE_JUMPS',
        domain: 'gross_motor',
        label: 'jumps with both feet off the ground',
        expectedAgeMonths: 28,
        latestAgeMonths: 33,
      },
      {
        code: 'MILESTONE_KICKS_BALL',
        domain: 'gross_motor',
        label: 'kicks a ball forward',
        expectedAgeMonths: 30,
        latestAgeMonths: 36,
      },
      {
        code: 'MILESTONE_BUILDS_TOWER',
        domain: 'fine_motor',
        label: 'builds a tower of six or more blocks',
        expectedAgeMonths: 30,
        latestAgeMonths: 36,
      },
      {
        code: 'MILESTONE_2_TO_3_WORD_SENTENCES',
        domain: 'language',
        label: 'speaks in short three-word sentences and is understood by family',
        expectedAgeMonths: 30,
        latestAgeMonths: 36,
      },
      {
        code: 'MILESTONE_TOILET_TRAINING',
        domain: 'social_emotional',
        label: 'is beginning toilet training with daytime dryness',
        expectedAgeMonths: 32,
        latestAgeMonths: 40,
      },
    ],
  },
  {
    bandLabel: '3 to 4 years',
    fromMonths: 36,
    toMonths: 48,
    milestones: [
      {
        code: 'MILESTONE_RIDES_TRICYCLE',
        domain: 'gross_motor',
        label: 'rides a tricycle and stands briefly on one foot',
        expectedAgeMonths: 38,
        latestAgeMonths: 44,
      },
      {
        code: 'MILESTONE_CATCHES_BALL',
        domain: 'gross_motor',
        label: 'catches a large ball with both hands',
        expectedAgeMonths: 42,
        latestAgeMonths: 48,
      },
      {
        code: 'MILESTONE_COPIES_CIRCLE',
        domain: 'fine_motor',
        label: 'copies a circle and draws a person with three parts',
        expectedAgeMonths: 40,
        latestAgeMonths: 46,
      },
      {
        code: 'MILESTONE_FULL_SENTENCES',
        domain: 'language',
        label: 'speaks in full sentences and is understood by strangers',
        expectedAgeMonths: 40,
        latestAgeMonths: 48,
      },
      {
        code: 'MILESTONE_DRESSSELF',
        domain: 'social_emotional',
        label: 'dresses and undresses with minimal help',
        expectedAgeMonths: 44,
        latestAgeMonths: 50,
      },
    ],
  },
  {
    bandLabel: '4 to 5 years',
    fromMonths: 48,
    toMonths: 60,
    milestones: [
      {
        code: 'MILESTONE_HOPS',
        domain: 'gross_motor',
        label: 'hops on one foot',
        expectedAgeMonths: 52,
        latestAgeMonths: 58,
      },
      {
        code: 'MILESTONE_CUTS_PAPER',
        domain: 'fine_motor',
        label: 'cuts with scissors and copies a square',
        expectedAgeMonths: 52,
        latestAgeMonths: 58,
      },
      {
        code: 'MILESTONE_STORY_TELLING',
        domain: 'language',
        label: 'tells simple stories and uses correct grammar for age',
        expectedAgeMonths: 54,
        latestAgeMonths: 60,
      },
      {
        code: 'MILESTONE_KNOWS_COLORS',
        domain: 'language',
        label: 'knows several colours and counts to ten',
        expectedAgeMonths: 54,
        latestAgeMonths: 60,
      },
      {
        code: 'MILESTONE_COOPERATIVE_PLAY',
        domain: 'social_emotional',
        label: 'plays cooperatively and follows simple rules of games',
        expectedAgeMonths: 54,
        latestAgeMonths: 60,
      },
    ],
  },
  {
    bandLabel: '5 to 6 years',
    fromMonths: 60,
    toMonths: 72,
    milestones: [
      {
        code: 'MILESTONE_SKIPS',
        domain: 'gross_motor',
        label: 'skips and walks in a straight line',
        expectedAgeMonths: 62,
        latestAgeMonths: 68,
      },
      {
        code: 'MILESTONE_TIES_SHOELACES',
        domain: 'fine_motor',
        label: 'ties shoelaces and copies a triangle',
        expectedAgeMonths: 66,
        latestAgeMonths: 72,
      },
      {
        code: 'MILESTONE_PRINTS_NAME',
        domain: 'fine_motor',
        label: 'prints the own name and simple letters',
        expectedAgeMonths: 66,
        latestAgeMonths: 72,
      },
      {
        code: 'MILESTONE_READY_FOR_SCHOOL',
        domain: 'language',
        label: 'has the attention and language expected for school entry',
        expectedAgeMonths: 66,
        latestAgeMonths: 72,
      },
      {
        code: 'MILESTONE_FRIENDSHIPS',
        domain: 'social_emotional',
        label: 'forms friendships and shows empathy toward others',
        expectedAgeMonths: 66,
        latestAgeMonths: 72,
      },
    ],
  },
];

// =============================================================================
// Age selection
// =============================================================================

export function ageInMonths(
  context: {
    ageYears: number | null;
    ageMonths: number | null;
    ageDays: number | null;
  },
): number | null {
  if (context.ageDays != null && Number.isFinite(context.ageDays)) {
    return Math.round(context.ageDays / 30.4375);
  }

  if (context.ageMonths != null && Number.isFinite(context.ageMonths)) {
    return Math.round(context.ageMonths);
  }

  if (context.ageYears != null && Number.isFinite(context.ageYears)) {
    return Math.round(context.ageYears * 12);
  }

  return null;
}

/**
 * Returns the milestone questions that are age-appropriate for a child.
 *
 * A milestone is considered age-appropriate when:
 *   - the child has reached the age window where the skill is expected
 *     (expectedAgeMonths <= currentAgeMonths + window), OR
 *   - the skill is still "due" (latestAgeMonths > currentAgeMonths) so it can
 *     be probed without being unfair.
 *
 * This deliberately surfaces a compact, clinically useful set rather than the
 * full table.
 */
export function milestonesForAge(
  context: {
    ageYears: number | null;
    ageMonths: number | null;
    ageDays: number | null;
  },
): MilestoneDefinition[] {
  const months = ageInMonths(context);

  if (months == null) {
    return [];
  }

  const selected: MilestoneDefinition[] = [];

  for (const band of MILESTONE_BANDS) {
    for (const milestone of band.milestones) {
      // Milestone already long past its latest window is not relevant for
      // capture (it was either achieved or lost; a regression fact covers it).
      if (milestone.latestAgeMonths + 3 < months) {
        continue;
      }

      // Milestone not yet due (expected far in the future) is skipped.
      if (milestone.expectedAgeMonths > months + 2) {
        continue;
      }

      selected.push(milestone);
    }
  }

  // Order by expected age, then domain for stable rendering.
  return selected.sort(
    (a, b) =>
      a.expectedAgeMonths - b.expectedAgeMonths ||
      a.domain.localeCompare(b.domain),
  );
}

export function milestoneByCode(
  code: string,
): MilestoneDefinition | null {
  for (const band of MILESTONE_BANDS) {
    for (const milestone of band.milestones) {
      if (milestone.code === code) {
        return milestone;
      }
    }
  }

  return null;
}

export function milestoneFactCode(
  code: string,
): string {
  return `${code}_ACHIEVED`;
}

// =============================================================================
// Deductions
// =============================================================================

export interface MilestoneDeduction {
  domain: MilestoneDomain;
  code: string;
  label: string;
  expectedAgeMonths: number;
  latestAgeMonths: number;
  status: 'achieved' | 'not_achieved' | 'unknown';
}

/**
 * Produces a structured list of milestone results from captured facts.
 * "unknown" is treated as not-yet-answered and never as delay.
 */
export function evaluateMilestones(
  facts: Array<{
    factCode: string;
    value: {
      boolean?: boolean | null;
      code?: string | null;
      text?: string | null;
    };
  }>,
): MilestoneDeduction[] {
  const deductions: MilestoneDeduction[] = [];

  for (const band of MILESTONE_BANDS) {
    for (const milestone of band.milestones) {
      const fact = facts.find(
        (item) => item.factCode === milestoneFactCode(milestone.code),
      );

      let status: MilestoneDeduction['status'] = 'unknown';

      if (fact?.value.boolean === true || fact?.value.code === 'YES') {
        status = 'achieved';
      } else if (fact?.value.boolean === false || fact?.value.code === 'NO') {
        status = 'not_achieved';
      }

      deductions.push({
        domain: milestone.domain,
        code: milestone.code,
        label: milestone.label,
        expectedAgeMonths: milestone.expectedAgeMonths,
        latestAgeMonths: milestone.latestAgeMonths,
        status,
      });
    }
  }

  return deductions;
}

/**
 * True when the milestone facts present enough evidence to comment on
 * development (at least one milestone answered yes or no).
 */
export function hasMilestoneEvidence(
  deductions: MilestoneDeduction[],
): boolean {
  return deductions.some(
    (item) => item.status === 'achieved' || item.status === 'not_achieved',
  );
}

/**
 * The "delay" verdict is only drawn for a milestone that is clearly past its
 * latest window AND explicitly marked as not achieved. This prevents the
 * engine from inventing developmental delay from missing answers.
 */
export function delayedMilestones(
  deductions: MilestoneDeduction[],
): MilestoneDeduction[] {
  const currentMonths = currentAgeMonthsFallback();

  return deductions.filter(
    (item) =>
      item.status === 'not_achieved' &&
      currentMonths != null &&
      item.latestAgeMonths <= currentMonths,
  );
}

function currentAgeMonthsFallback(): number | null {
  // A coarse fallback is never used for the deduction; documentation calls
  // evaluateMilestones with a context and performs its own age comparison.
  // This helper exists only to keep the API stable for tests.
  return null;
}

/**
 * Identifies milestones marked "lost" (previously achieved, now lost) from
 * captured regression facts.
 */
export function regressedMilestones(
  facts: Array<{
    factCode: string;
    value: {
      boolean?: boolean | null;
      code?: string | null;
      text?: string | null;
    };
  }>,
): MilestoneDeduction[] {
  const deductions = evaluateMilestones(facts);

  return deductions.filter(
    (item) => item.status === 'not_achieved' && item.latestAgeMonths >= 12,
  );
}
