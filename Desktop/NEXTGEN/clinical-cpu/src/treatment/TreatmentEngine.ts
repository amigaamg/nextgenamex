// =============================================================================
// AMEXAN Clinical CPU — TreatmentEngine
// Produces ELIGIBLE actions, not automatic blind prescribing. Candidates come
// from medication_condition for the working diagnosis; dose references are
// population/indication-aware and force verification when not clinically
// approved (is_verified = false).
// =============================================================================

import type { Db, Row } from '../db.js';
import type { DifferentialCandidate, TreatmentRecommendation } from '../types.js';

interface MedicationConditionRow extends Row {
  condition_code: string;
  medication_code: string;
  generic_name: string;
  role: string;
  weight: number;
}

interface MedicationRow extends Row {
  medication_code: string;
  generic_name: string;
  contraindications: unknown;
  interaction_notes: unknown;
}

interface DoseRow extends Row {
  medication_code: string;
  route: string | null;
  dose_expression: string;
  frequency_expression: string | null;
  duration_expression: string | null;
  is_verified: boolean;
}

export class TreatmentEngine {
  constructor(private readonly db: Db) {}

  async resolve(differentials: DifferentialCandidate[], ageYears: number | null): Promise<TreatmentRecommendation[]> {
    const top = differentials[0];
    if (!top) return [];

    const rows = await this.db.query<MedicationConditionRow>(
      `SELECT c.condition_code, m.medication_code, m.generic_name, mc.role, mc.weight
         FROM knowledge.medication_condition mc
         JOIN knowledge.condition c ON c.id = mc.condition_id
         JOIN knowledge.medication m ON m.id = mc.medication_id
        WHERE c.condition_code = $1
        ORDER BY mc.weight DESC`,
      [top.conditionCode],
    );
    if (rows.length === 0) return [];

    const codes = rows.map((r) => r.medication_code);
    const [medications, doses] = await Promise.all([
      this.db.query<MedicationRow>(
        `SELECT medication_code, generic_name, contraindications, interaction_notes
           FROM knowledge.medication WHERE medication_code = ANY($1::text[])`,
        [codes],
      ),
      this.db.query<DoseRow>(
        `SELECT m.medication_code, ddr.route, ddr.dose_expression, ddr.frequency_expression,
                ddr.duration_expression, ddr.is_verified
           FROM knowledge.drug_dose_reference ddr
           JOIN knowledge.medication m ON m.id = ddr.medication_id
          WHERE m.medication_code = ANY($1::text[])
            AND ddr.population = $2
            AND ddr.indication_code = $3`,
        [codes, ageYears !== null && ageYears < 18 ? 'paediatric' : 'adult', top.conditionCode],
      ),
    ]);

    const doseByMedication = new Map<string, DoseRow>();
    for (const dose of doses) doseByMedication.set(dose.medication_code, dose);
    const medicationByCode = new Map(medications.map((m) => [m.medication_code, m]));

    return rows.map((row) => {
      const med = medicationByCode.get(row.medication_code);
      const dose = doseByMedication.get(row.medication_code);
      const safetyNotes: string[] = [];
      if (med) {
        const contra = med.contraindications as unknown[] | null;
        if (Array.isArray(contra) && contra.length > 0) {
          safetyNotes.push(`Contraindications: ${contra.join('; ')}`);
        }
        const interactions = med.interaction_notes as unknown[] | null;
        if (Array.isArray(interactions) && interactions.length > 0) {
          safetyNotes.push(`Interactions: ${interactions.join('; ')}`);
        }
      }
      if (dose && !dose.is_verified) {
        safetyNotes.push('Dose expression requires independent clinical verification before prescribing.');
      }
      return {
        medicationCode: row.medication_code,
        genericName: row.generic_name,
        role: row.role,
        route: dose?.route ?? null,
        doseExpression: dose?.dose_expression ?? 'REVIEW REQUIRED',
        frequency: dose?.frequency_expression ?? null,
        duration: dose?.duration_expression ?? null,
        verified: dose?.is_verified ?? false,
        contraindicated: false,
        safetyNotes,
      };
    });
  }
}
