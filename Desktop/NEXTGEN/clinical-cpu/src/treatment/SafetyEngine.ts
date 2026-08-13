// =============================================================================
// AMEXAN Clinical CPU — SafetyEngine
// The CPU never prescribes blindly (3.17). It consumes the patient's safety
// profile — drug allergies, pregnancy, renal and hepatic impairment — captured
// as ordinary clinical facts, and cross-checks every treatment candidate
// against the medication's reusable contraindication intelligence. Hard
// contraindications are flagged (never silently hidden); renal/pregnancy/hepatic
// handling is surfaced as notes the clinician must weigh.
// =============================================================================

import type { Fact, TreatmentRecommendation } from '../types.js';

export interface SafetyProfile {
  allergies: string[];
  pregnant: boolean;
  renalImpairment: boolean;
  hepaticImpairment: boolean;
  creatinineMgDl: number | null;
}

// Allergy → drug-class aliases used to interpret the medication's
// contraindication phrases. "Penicillin" implies "serious immediate
// beta-lactam allergy"; "azithromycin" implies a macrolide allergy.
const ALLERGY_CLASS: [string, string][] = [
  ['beta-lactam', 'beta-lactam'],
  ['penicillin', 'beta-lactam'],
  ['ampicillin', 'beta-lactam'],
  ['amoxicillin', 'beta-lactam'],
  ['cephalosporin', 'beta-lactam'],
  ['ceftriaxone', 'beta-lactam'],
  ['macrolide', 'macrolide'],
  ['erythromycin', 'macrolide'],
  ['azithromycin', 'macrolide'],
  ['clarithromycin', 'macrolide'],
  ['sulfonamide', 'sulfonamide'],
  ['sulpha', 'sulfonamide'],
  ['cotrimoxazole', 'sulfonamide'],
  ['paracetamol', 'paracetamol'],
  ['acetaminophen', 'paracetamol'],
];

const RENAL_IMPAIRMENT_CREATININE_MG_DL = 1.3;

export function safetyProfileFromFacts(facts: Fact[]): SafetyProfile {
  const allergies = new Set<string>();
  let pregnant = false;
  let hepaticImpairment = false;
  let creatinine: number | null = null;

  for (const fact of facts) {
    for (const value of fact.values) {
      switch (fact.factCode) {
        case 'DRUG_ALLERGY':
          if (value.text) allergies.add(value.text);
          break;
        case 'PREGNANT':
          if (value.boolean === true) pregnant = true;
          break;
        case 'HEPATIC_IMPAIRMENT':
          if (value.boolean === true) hepaticImpairment = true;
          break;
        case 'CREATININE':
          if (value.numeric != null) creatinine = value.numeric;
          break;
        default:
          break;
      }
    }
  }
  return {
    allergies: [...allergies],
    pregnant,
    renalImpairment: creatinine != null && creatinine > RENAL_IMPAIRMENT_CREATININE_MG_DL,
    hepaticImpairment,
    creatinineMgDl: creatinine,
  };
}

export class SafetyEngine {
  apply(facts: Fact[], recommendations: TreatmentRecommendation[]): TreatmentRecommendation[] {
    const profile = safetyProfileFromFacts(facts);
    return recommendations.map((rec) => {
      if (rec.contraindicated) return rec;
      const safetyNotes: string[] = [];
      const contraindication = this.findContraindication(rec, profile);
      if (contraindication) {
        safetyNotes.push(
          `CONTRANDICATED — patient profile matches "${contraindication.phrase}" (recorded: ${contraindication.evidence}). ` +
            'Do not prescribe without specialist reconciliation.',
        );
      }
      if (profile.renalImpairment && rec.safetyNotes.some((n) => n.toLowerCase().includes('renal'))) {
        safetyNotes.push(`Renal impairment present (creatinine ${profile.creatinineMgDl} mg/dL) — renal dose adjustment required.`);
      }
      if (profile.hepaticImpairment && rec.safetyNotes.some((n) => n.toLowerCase().includes('hepatic'))) {
        safetyNotes.push('Hepatic impairment present — hepatic handling review required.');
      }
      if (profile.pregnant && rec.safetyNotes.some((n) => n.toLowerCase().includes('pregnan'))) {
        safetyNotes.push('Pregnancy present — review current pregnancy guidance for this drug.');
      }
      return {
        ...rec,
        contraindicated: contraindication != null,
        safetyNotes: [...safetyNotes, ...rec.safetyNotes],
      };
    });
  }

  private findContraindication(
    rec: TreatmentRecommendation,
    profile: SafetyProfile,
  ): { phrase: string; evidence: string } | null {
    const contraindications = rec.safetyNotes
      .filter((n) => n.startsWith('Contraindications:'))
      .map((n) => n.slice(n.indexOf(':') + 1).split(';').map((s) => s.trim()))
      .flat();

    for (const phrase of contraindications) {
      const normalized = phrase.toLowerCase();
      for (const allergy of profile.allergies) {
        const allergyLower = allergy.toLowerCase();
        const classes = ALLERGY_CLASS.filter(([source]) => allergyLower.includes(source)).map(([, cls]) => cls);
        if (normalized.includes(allergyLower) || classes.some((cls) => normalized.includes(cls))) {
          return { phrase, evidence: `allergy: ${allergy}` };
        }
      }
      if (profile.hepaticImpairment && normalized.includes('hepatic')) {
        return { phrase, evidence: 'hepatic impairment' };
      }
    }
    return null;
  }
}
