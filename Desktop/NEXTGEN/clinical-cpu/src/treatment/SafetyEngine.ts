// =============================================================================
// AMEXAN Clinical CPU — SafetyEngine
//
// Safety is a gating layer between candidate treatment generation and the
// clinical runtime projection.
//
// The engine does NOT prescribe, substitute, remove, or silently suppress a
// treatment. It evaluates each candidate against the patient's captured safety
// profile and annotates the candidate with explicit safety state.
//
// Safety information is derived from ordinary clinical facts:
//   • DRUG_ALLERGY
//   • PREGNANT
//   • RENAL_IMPAIRMENT
//   • HEPATIC_IMPAIRMENT
//   • CREATININE
//
// Medication-specific contraindication intelligence is supplied by the
// TreatmentEngine through `safetyNotes`. The SafetyEngine interprets that
// reusable knowledge against the patient's current profile.
//
// Design principles:
//   1. Never silently hide a treatment candidate.
//   2. Never convert uncertainty into a false safety claim.
//   3. Hard contraindications are explicitly surfaced.
//   4. Pregnancy/renal/hepatic issues are surfaced for clinical review.
//   5. Latest captured fact wins for mutable patient-state facts.
//   6. Unknown safety state remains unknown.
//   7. Allergy matching is normalized and class-aware.
//   8. The engine does not perform prescribing or therapeutic substitution.
// =============================================================================

import type { Fact, TreatmentRecommendation } from '../types.js';

export interface SafetyProfile {
  allergies: string[];
  pregnant: boolean | null;
  renalImpairment: boolean | null;
  hepaticImpairment: boolean | null;
  creatinineMgDl: number | null;
}

interface ContraindicationMatch {
  phrase: string;
  evidence: string;
  category: 'allergy' | 'renal' | 'hepatic' | 'pregnancy' | 'other';
}

interface SafetyEvaluation {
  contraindicated: boolean;
  notes: string[];
}

// -----------------------------------------------------------------------------
// Allergy normalization
// -----------------------------------------------------------------------------
//
// The database may contain either:
//   "penicillin"
//   "penicillin allergy"
//   "immediate penicillin allergy"
//   "beta-lactam"
//   "macrolide"
// etc.
//
// Matching is deliberately conservative. A generic allergy must not be turned
// into a drug contraindication unless the medication's contraindication
// knowledge explicitly intersects with the normalized allergy class.
// -----------------------------------------------------------------------------

const ALLERGY_CLASS_ALIASES: ReadonlyArray<readonly [string, string]> = [
  ['beta-lactam', 'beta-lactam'],
  ['beta lactam', 'beta-lactam'],
  ['penicillin', 'beta-lactam'],
  ['ampicillin', 'beta-lactam'],
  ['amoxicillin', 'beta-lactam'],
  ['amoxicillin-clavulanate', 'beta-lactam'],
  ['amoxicillin clavulanate', 'beta-lactam'],
  ['benzylpenicillin', 'beta-lactam'],
  ['phenoxymethylpenicillin', 'beta-lactam'],
  ['piperacillin', 'beta-lactam'],
  ['piperacillin-tazobactam', 'beta-lactam'],
  ['cephalosporin', 'cephalosporin'],
  ['ceftriaxone', 'cephalosporin'],
  ['cefotaxime', 'cephalosporin'],
  ['cefuroxime', 'cephalosporin'],
  ['cephalexin', 'cephalosporin'],
  ['carbapenem', 'carbapenem'],
  ['meropenem', 'carbapenem'],
  ['imipenem', 'carbapenem'],
  ['ertapenem', 'carbapenem'],
  ['macrolide', 'macrolide'],
  ['erythromycin', 'macrolide'],
  ['azithromycin', 'macrolide'],
  ['clarithromycin', 'macrolide'],
  ['sulfonamide', 'sulfonamide'],
  ['sulphonamide', 'sulfonamide'],
  ['sulfa', 'sulfonamide'],
  ['sulpha', 'sulfonamide'],
  ['cotrimoxazole', 'sulfonamide'],
  ['trimethoprim-sulfamethoxazole', 'sulfonamide'],
  ['trimethoprim sulfamethoxazole', 'sulfonamide'],
  ['paracetamol', 'paracetamol'],
  ['acetaminophen', 'paracetamol'],
];

const SAFETY_NOTE_PREFIXES = {
  contraindications: 'contraindications:',
  interactions: 'interactions:',
} as const;

// -----------------------------------------------------------------------------
// Patient safety profile
// -----------------------------------------------------------------------------

export function safetyProfileFromFacts(facts: Fact[]): SafetyProfile {
  const allergies = new Set<string>();

  let pregnant: boolean | null = null;
  let renalImpairment: boolean | null = null;
  let hepaticImpairment: boolean | null = null;
  let creatinineMgDl: number | null = null;

  // Facts are append-only clinical history. For mutable safety state, the
  // latest observation is authoritative.
  //
  // Allergy is different: allergies accumulate rather than overwrite each
  // other.
  for (const fact of facts) {
    switch (fact.factCode) {
      case 'DRUG_ALLERGY': {
        for (const value of fact.values) {
          const text = value.text?.trim();
          if (text) allergies.add(text);
        }
        break;
      }

      case 'PREGNANT': {
        const value = latestBooleanValue(fact);
        if (value != null) pregnant = value;
        break;
      }

      case 'RENAL_IMPAIRMENT': {
        const value = latestBooleanValue(fact);
        if (value != null) renalImpairment = value;
        break;
      }

      case 'HEPATIC_IMPAIRMENT': {
        const value = latestBooleanValue(fact);
        if (value != null) hepaticImpairment = value;
        break;
      }

      case 'CREATININE': {
        const value = latestNumericValue(fact);
        if (value != null) creatinineMgDl = value;
        break;
      }

      default:
        break;
    }
  }

  return {
    allergies: [...allergies],
    pregnant,
    renalImpairment,
    hepaticImpairment,
    creatinineMgDl,
  };
}

// -----------------------------------------------------------------------------
// Safety engine
// -----------------------------------------------------------------------------

export class SafetyEngine {
  apply(
    facts: Fact[],
    recommendations: TreatmentRecommendation[],
  ): TreatmentRecommendation[] {
    if (recommendations.length === 0) return [];

    const profile = safetyProfileFromFacts(facts);

    return recommendations.map((recommendation) => {
      // Preserve an already-established hard contraindication.
      //
      // The SafetyEngine must never downgrade an upstream safety decision.
      const alreadyContraindicated = recommendation.contraindicated === true;

      const evaluation = this.evaluateRecommendation(
        recommendation,
        profile,
      );

      return {
        ...recommendation,

        contraindicated:
          alreadyContraindicated || evaluation.contraindicated,

        safetyNotes: mergeSafetyNotes(
          evaluation.notes,
          recommendation.safetyNotes,
        ),
      };
    });
  }

  private evaluateRecommendation(
    recommendation: TreatmentRecommendation,
    profile: SafetyProfile,
  ): SafetyEvaluation {
    const notes: string[] = [];

    const contraindicationMatch = this.findContraindication(
      recommendation,
      profile,
    );

    if (contraindicationMatch) {
      notes.push(
        buildContraindicationMessage(contraindicationMatch),
      );
    }

    this.appendRenalSafetyNote(
      notes,
      recommendation,
      profile,
    );

    this.appendHepaticSafetyNote(
      notes,
      recommendation,
      profile,
    );

    this.appendPregnancySafetyNote(
      notes,
      recommendation,
      profile,
    );

    return {
      contraindicated: contraindicationMatch != null,
      notes,
    };
  }

  // ---------------------------------------------------------------------------
  // Contraindication evaluation
  // ---------------------------------------------------------------------------

  private findContraindication(
    recommendation: TreatmentRecommendation,
    profile: SafetyProfile,
  ): ContraindicationMatch | null {
    const contraindications = extractContraindications(
      recommendation.safetyNotes,
    );

    if (contraindications.length === 0) return null;

    for (const phrase of contraindications) {
      const normalizedPhrase = normalizeText(phrase);

      // Allergy-related contraindications.
      for (const allergy of profile.allergies) {
        const allergyMatch = matchAllergyAgainstContraindication(
          allergy,
          normalizedPhrase,
        );

        if (allergyMatch) {
          return {
            phrase,
            evidence: `drug allergy: ${allergy}`,
            category: 'allergy',
          };
        }
      }

      // Organ-specific hard contraindications.
      if (
        profile.renalImpairment === true &&
        containsAny(normalizedPhrase, [
          'renal contraindication',
          'contraindicated in renal impairment',
          'contraindicated in severe renal impairment',
          'contraindicated in renal failure',
        ])
      ) {
        return {
          phrase,
          evidence: 'renal impairment',
          category: 'renal',
        };
      }

      if (
        profile.hepaticImpairment === true &&
        containsAny(normalizedPhrase, [
          'hepatic contraindication',
          'contraindicated in hepatic impairment',
          'contraindicated in severe hepatic impairment',
          'contraindicated in liver failure',
        ])
      ) {
        return {
          phrase,
          evidence: 'hepatic impairment',
          category: 'hepatic',
        };
      }

      if (
        profile.pregnant === true &&
        containsAny(normalizedPhrase, [
          'contraindicated in pregnancy',
          'contraindicated during pregnancy',
          'pregnancy contraindication',
        ])
      ) {
        return {
          phrase,
          evidence: 'pregnancy',
          category: 'pregnancy',
        };
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Renal handling
  // ---------------------------------------------------------------------------

  private appendRenalSafetyNote(
    notes: string[],
    recommendation: TreatmentRecommendation,
    profile: SafetyProfile,
  ): void {
    if (profile.renalImpairment !== true) return;

    if (!containsSafetyTopic(recommendation.safetyNotes, 'renal')) {
      return;
    }

    const creatinineText =
      profile.creatinineMgDl != null
        ? ` (creatinine ${profile.creatinineMgDl} mg/dL)`
        : '';

    notes.push(
      `RENAL SAFETY REVIEW — renal impairment is present${creatinineText}. ` +
      'Review renal dosing, contraindications, and monitoring requirements before prescribing.',
    );
  }

  // ---------------------------------------------------------------------------
  // Hepatic handling
  // ---------------------------------------------------------------------------

  private appendHepaticSafetyNote(
    notes: string[],
    recommendation: TreatmentRecommendation,
    profile: SafetyProfile,
  ): void {
    if (profile.hepaticImpairment !== true) return;

    if (!containsSafetyTopic(recommendation.safetyNotes, 'hepatic')) {
      return;
    }

    notes.push(
      'HEPATIC SAFETY REVIEW — hepatic impairment is present. ' +
      'Review hepatic dosing, contraindications, and monitoring requirements before prescribing.',
    );
  }

  // ---------------------------------------------------------------------------
  // Pregnancy handling
  // ---------------------------------------------------------------------------

  private appendPregnancySafetyNote(
    notes: string[],
    recommendation: TreatmentRecommendation,
    profile: SafetyProfile,
  ): void {
    if (profile.pregnant !== true) return;

    if (!containsSafetyTopic(recommendation.safetyNotes, 'pregnan')) {
      return;
    }

    notes.push(
      'PREGNANCY SAFETY REVIEW — pregnancy is present. ' +
      'Review current pregnancy-specific safety guidance before prescribing.',
    );
  }
}

// =============================================================================
// Contraindication parsing
// =============================================================================

function extractContraindications(
  safetyNotes: string[],
): string[] {
  const result: string[] = [];

  for (const note of safetyNotes) {
    const normalized = normalizeText(note);

    if (
      !normalized.startsWith(
        SAFETY_NOTE_PREFIXES.contraindications,
      )
    ) {
      continue;
    }

    const separatorIndex = note.indexOf(':');

    if (separatorIndex === -1) continue;

    const payload = note
      .slice(separatorIndex + 1)
      .trim();

    if (!payload) continue;

    for (const phrase of splitSafetyValues(payload)) {
      if (phrase) result.push(phrase);
    }
  }

  return uniqueStrings(result);
}

function splitSafetyValues(value: string): string[] {
  return value
    .split(/[;,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

// =============================================================================
// Allergy matching
// =============================================================================

function matchAllergyAgainstContraindication(
  allergy: string,
  normalizedContraindication: string,
): boolean {
  const normalizedAllergy = normalizeText(allergy);

  if (!normalizedAllergy) return false;

  // Direct phrase match.
  if (
    normalizedContraindication.includes(normalizedAllergy)
  ) {
    return true;
  }

  // Determine clinically meaningful allergy classes.
  const allergyClasses = resolveAllergyClasses(
    normalizedAllergy,
  );

  if (allergyClasses.length === 0) return false;

  // The contraindication must explicitly mention the relevant class or
  // specific allergen. This avoids treating every medication allergy as
  // equivalent to every other medication.
  return allergyClasses.some((allergyClass) =>
    normalizedContraindication.includes(allergyClass),
  );
}

function resolveAllergyClasses(
  allergy: string,
): string[] {
  const classes = new Set<string>();

  for (const [alias, allergyClass] of ALLERGY_CLASS_ALIASES) {
    if (allergy.includes(alias)) {
      classes.add(allergyClass);
    }
  }

  return [...classes];
}

// =============================================================================
// Safety-topic detection
// =============================================================================

function containsSafetyTopic(
  safetyNotes: string[],
  topic: string,
): boolean {
  const normalizedTopic = normalizeText(topic);

  return safetyNotes.some((note) =>
    normalizeText(note).includes(normalizedTopic),
  );
}

// =============================================================================
// Fact helpers
// =============================================================================

function latestBooleanValue(
  fact: Fact,
): boolean | null {
  for (let i = fact.values.length - 1; i >= 0; i--) {
    const value = fact.values[i];

    if (value.boolean != null) {
      return value.boolean;
    }
  }

  return null;
}

function latestNumericValue(
  fact: Fact,
): number | null {
  for (let i = fact.values.length - 1; i >= 0; i--) {
    const value = fact.values[i];

    if (value.numeric != null) {
      return value.numeric;
    }
  }

  return null;
}

// =============================================================================
// Text normalization
// =============================================================================

function normalizeText(value: string): string {
  return value
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function containsAny(
  value: string,
  candidates: string[],
): boolean {
  return candidates.some((candidate) =>
    value.includes(normalizeText(candidate)),
  );
}

function uniqueStrings(
  values: string[],
): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const value of values) {
    const key = normalizeText(value);

    if (!key || seen.has(key)) continue;

    seen.add(key);
    result.push(value);
  }

  return result;
}

// =============================================================================
// Runtime safety message construction
// =============================================================================

function buildContraindicationMessage(
  match: ContraindicationMatch,
): string {
  switch (match.category) {
    case 'allergy':
      return (
        `CONTRAINDICATED — patient safety profile matches ` +
        `"${match.phrase}" (${match.evidence}). ` +
        'Do not prescribe unless the contraindication is clinically reconciled.'
      );

    case 'renal':
      return (
        `CONTRAINDICATED — patient safety profile matches ` +
        `"${match.phrase}" (${match.evidence}). ` +
        'Do not prescribe unless the contraindication is clinically reconciled.'
      );

    case 'hepatic':
      return (
        `CONTRAINDICATED — patient safety profile matches ` +
        `"${match.phrase}" (${match.evidence}). ` +
        'Do not prescribe unless the contraindication is clinically reconciled.'
      );

    case 'pregnancy':
      return (
        `CONTRAINDICATED — patient safety profile matches ` +
        `"${match.phrase}" (${match.evidence}). ` +
        'Do not prescribe unless the contraindication is clinically reconciled.'
      );

    default:
      return (
        `CONTRAINDICATED — patient safety profile matches ` +
        `"${match.phrase}" (${match.evidence}). ` +
        'Do not prescribe unless the contraindication is clinically reconciled.'
      );
  }
}

// =============================================================================
// Safety-note merge
// =============================================================================
//
// SafetyEngine-generated warnings are placed first so that the runtime/UI sees
// the highest-priority safety information immediately. Existing treatment
// knowledge is preserved verbatim.
// =============================================================================

function mergeSafetyNotes(
  generated: string[],
  existing: string[],
): string[] {
  return uniqueStrings([
    ...generated,
    ...existing,
  ]);
}