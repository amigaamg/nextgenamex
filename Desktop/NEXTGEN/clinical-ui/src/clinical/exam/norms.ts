// =============================================================================
// src/clinical/exam/norms.ts
// AMEXAN — CLINICAL EXAMINATION KNOWLEDGE BASE
//
// Normal/reference ranges used to compare captured findings and produce
// deductions (normal / abnormal / tachypnea / tachycardia / malnutrition …).
//
// RULE:
//   This file only *describes* expected normal values and classification
//   rules. The clinician decides what is true for the patient; the CPU remains
//   the authority on overall reasoning. Ranges follow WHO and standard
//   paediatric/adult reference tables (Nelson, Hutchison).
// =============================================================================

export type AgeBand =
  | 'neonate'      // 0–28 days
  | 'infant'       // 1 month – 1 year
  | 'toddler'      // 1–3 years
  | 'preschool'    // 3–6 years
  | 'school'       // 6–12 years
  | 'adolescent'   // 12–18 years
  | 'adult'        // 18–65 years
  | 'older_adult'; // >65 years

export interface AgeInput {
  ageYears: number | null;
  ageMonths: number | null;
  ageDays: number | null;
}

/** Total age in months (fractional). Null when nothing is known. */
export function ageInMonths(age: AgeInput): number | null {
  if (age.ageDays != null && age.ageDays >= 0) {
    return age.ageDays / 30.44;
  }
  if (age.ageMonths != null && age.ageMonths >= 0) {
    return age.ageMonths;
  }
  if (age.ageYears != null && age.ageYears >= 0) {
    return age.ageYears * 12;
  }
  return null;
}

export function ageInYears(age: AgeInput): number | null {
  const months = ageInMonths(age);
  return months == null ? null : months / 12;
}

export function determineAgeBand(age: AgeInput): AgeBand {
  const months = ageInMonths(age);

  if (months == null) return 'adult';
  if (months < 1) return 'neonate';
  if (months < 12) return 'infant';
  if (months < 36) return 'toddler';
  if (months < 72) return 'preschool';
  if (months < 144) return 'school';
  if (months < 216) return 'adolescent';
  if (months < 780) return 'adult';
  return 'older_adult';
}

export const AGE_BAND_LABELS: Record<AgeBand, string> = {
  neonate: 'Neonate',
  infant: 'Infant',
  toddler: 'Toddler',
  preschool: 'Pre-school',
  school: 'School-age',
  adolescent: 'Adolescent',
  adult: 'Adult',
  older_adult: 'Older adult',
};

// =============================================================================
// VITAL SIGNS — NORMAL RANGES BY AGE
// =============================================================================

export interface VitalRange {
  hr: [number, number];   // bpm
  rr: [number, number];   // /min
  sbp: [number, number];  // mmHg
  dbp: [number, number];  // mmHg
  spo2Min: number;        // %
  tempC: [number, number];// °C
}

const NEONATE: VitalRange = {
  hr: [100, 160],
  rr: [30, 60],
  sbp: [60, 85],
  dbp: [35, 55],
  spo2Min: 95,
  tempC: [36.1, 37.7],
};

const INFANT: VitalRange = {
  hr: [100, 160],
  rr: [30, 50],
  sbp: [72, 104],
  dbp: [40, 60],
  spo2Min: 95,
  tempC: [36.1, 37.7],
};

const TODDLER: VitalRange = {
  hr: [80, 140],
  rr: [22, 34],
  sbp: [86, 106],
  dbp: [42, 63],
  spo2Min: 95,
  tempC: [36.1, 37.7],
};

const PRESCHOOL: VitalRange = {
  hr: [80, 130],
  rr: [20, 30],
  sbp: [89, 112],
  dbp: [46, 72],
  spo2Min: 95,
  tempC: [36.1, 37.7],
};

const SCHOOL: VitalRange = {
  hr: [70, 120],
  rr: [18, 26],
  sbp: [97, 120],
  dbp: [57, 80],
  spo2Min: 95,
  tempC: [36.1, 37.7],
};

const ADOLESCENT: VitalRange = {
  hr: [60, 100],
  rr: [14, 22],
  sbp: [100, 130],
  dbp: [60, 85],
  spo2Min: 95,
  tempC: [36.1, 37.7],
};

const ADULT: VitalRange = {
  hr: [60, 100],
  rr: [12, 20],
  sbp: [90, 130],
  dbp: [60, 85],
  spo2Min: 95,
  tempC: [36.1, 37.2],
};

const OLDER_ADULT: VitalRange = {
  hr: [60, 100],
  rr: [12, 20],
  sbp: [90, 140],
  dbp: [60, 90],
  spo2Min: 95,
  tempC: [36.1, 37.2],
};

const VITAL_RANGES: Record<AgeBand, VitalRange> = {
  neonate: NEONATE,
  infant: INFANT,
  toddler: TODDLER,
  preschool: PRESCHOOL,
  school: SCHOOL,
  adolescent: ADOLESCENT,
  adult: ADULT,
  older_adult: OLDER_ADULT,
};

export function vitalsForAge(age: AgeInput): VitalRange {
  return VITAL_RANGES[determineAgeBand(age)];
}

// =============================================================================
// DEDUCTIONS
// =============================================================================

export type VitalsStatus =
  | 'normal'
  | 'low'
  | 'high'
  | 'not_assessed';

export interface VitalsDeduction {
  status: VitalsStatus;
  label: string;
  note: string | null;
}

export function deduceHeartRate(
  value: number | null,
  age: AgeInput,
): VitalsDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: null };

  const [low, high] = VITAL_RANGES[determineAgeBand(age)].hr;

  if (value < low) {
    return {
      status: 'low',
      label: 'Bradycardia',
      note: `Below the expected range for age (${low}–${high} bpm).`,
    };
  }
  if (value > high) {
    return {
      status: 'high',
      label: 'Tachycardia',
      note: `Above the expected range for age (${low}–${high} bpm).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Within the expected range for age (${low}–${high} bpm).`,
  };
}

export function deduceRespiratoryRate(
  value: number | null,
  age: AgeInput,
): VitalsDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: null };

  const [low, high] = VITAL_RANGES[determineAgeBand(age)].rr;

  if (value < low) {
    return {
      status: 'low',
      label: 'Bradypnoea',
      note: `Below the expected range for age (${low}–${high}/min).`,
    };
  }
  if (value > high) {
    return {
      status: 'high',
      label: 'Tachypnoea',
      note: `Above the expected range for age (${low}–${high}/min).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Within the expected range for age (${low}–${high}/min).`,
  };
}

export function deduceTemperature(
  value: number | null,
): VitalsDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: null };

  if (value >= 41) return { status: 'high', label: 'Hyperpyrexia', note: 'Temperature ≥ 41 °C.' };
  if (value >= 39) return { status: 'high', label: 'High fever', note: 'Temperature 39.0–40.9 °C.' };
  if (value >= 38) return { status: 'high', label: 'Fever', note: 'Temperature 38.0–38.9 °C.' };
  if (value >= 37.5) return { status: 'high', label: 'Low-grade fever', note: 'Temperature 37.5–37.9 °C.' };
  if (value < 35) return { status: 'low', label: 'Hypothermia', note: 'Temperature < 35 °C.' };
  return { status: 'normal', label: 'Normal', note: 'Within expected range (36.1–37.7 °C).' };
}

export function deduceSpo2(
  value: number | null,
  age: AgeInput,
): VitalsDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: null };

  const min = VITAL_RANGES[determineAgeBand(age)].spo2Min;

  if (value < min) {
    return {
      status: 'low',
      label: value < 90 ? 'Severe hypoxaemia' : 'Hypoxaemia',
      note: `SpO₂ below expected minimum for age (≥ ${min}%).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Within expected range (≥ ${min}%).`,
  };
}

export function deduceBloodPressure(
  sbp: number | null,
  dbp: number | null,
  age: AgeInput,
): VitalsDeduction {
  const [sLow, sHigh] = VITAL_RANGES[determineAgeBand(age)].sbp;
  const [dLow, dHigh] = VITAL_RANGES[determineAgeBand(age)].dbp;

  if (sbp == null && dbp == null) {
    return { status: 'not_assessed', label: 'Not assessed', note: null };
  }

  const notes: string[] = [];

  if (sbp != null && sbp < sLow) notes.push(`SBP below expected for age (${sLow}–${sHigh} mmHg).`);
  if (sbp != null && sbp > sHigh) notes.push(`SBP above expected for age (${sLow}–${sHigh} mmHg).`);
  if (dbp != null && dbp < dLow) notes.push(`DBP below expected for age (${dLow}–${dHigh} mmHg).`);
  if (dbp != null && dbp > dHigh) notes.push(`DBP above expected for age (${dLow}–${dHigh} mmHg).`);

  if (notes.length === 0) {
    return {
      status: 'normal',
      label: 'Normal',
      note: `Within expected range (SBP ${sLow}–${sHigh}, DBP ${dLow}–${dHigh} mmHg).`,
    };
  }

  const isHypertensive =
    (sbp != null && sbp > sHigh) || (dbp != null && dbp > dHigh);
  const isHypotensive =
    (sbp != null && sbp < sLow) || (dbp != null && dbp < dLow);

  return {
    status: isHypertensive ? 'high' : isHypotensive ? 'low' : 'normal',
    label: isHypertensive
      ? 'Hypertension'
      : isHypotensive
        ? 'Hypotension'
        : 'Abnormal',
    note: notes.join(' '),
  };
}

// =============================================================================
// ANTHROPOMETRICS — PEDIATRIC REFERENCE VALUES
// =============================================================================

export interface AnthropometricRange {
  /** Roughly median – 2SD to median + 2SD by WHO. */
  weightKg: [number, number];
  heightCm: [number, number];
  /** Head circumference up to ~24 months. */
  headCircCm?: [number, number] | null;
  /** MUAC normal threshold by age (≥ threshold is normal). */
  muacNormalCm: number;
}

const ANTHRO_RANGES: Record<AgeBand, AnthropometricRange> = {
  neonate: {
    weightKg: [2.5, 4.2],
    heightCm: [46, 54],
    headCircCm: [32, 38],
    muacNormalCm: 12.5,
  },
  infant: {
    weightKg: [4.0, 10.5],
    heightCm: [54, 76],
    headCircCm: [38, 48],
    muacNormalCm: 12.5,
  },
  toddler: {
    weightKg: [10.0, 16.0],
    heightCm: [76, 96],
    headCircCm: [46, 50],
    muacNormalCm: 12.5,
  },
  preschool: {
    weightKg: [13.0, 22.0],
    heightCm: [92, 118],
    headCircCm: null,
    muacNormalCm: 13.5,
  },
  school: {
    weightKg: [20.0, 42.0],
    heightCm: [110, 150],
    headCircCm: null,
    muacNormalCm: 16.0,
  },
  adolescent: {
    weightKg: [36.0, 75.0],
    heightCm: [148, 175],
    headCircCm: null,
    muacNormalCm: 16.0,
  },
  adult: {
    weightKg: [50.0, 90.0],
    heightCm: [150, 185],
    headCircCm: null,
    muacNormalCm: 16.0,
  },
  older_adult: {
    weightKg: [50.0, 85.0],
    heightCm: [148, 180],
    headCircCm: null,
    muacNormalCm: 16.0,
  },
};

export interface AnthropometricDeduction {
  status: 'normal' | 'low' | 'high' | 'not_assessed';
  label: string;
  note: string;
}

export function deduceWeight(
  value: number | null,
  age: AgeInput,
): AnthropometricDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: '' };
  const [low, high] = ANTHRO_RANGES[determineAgeBand(age)].weightKg;

  if (value < low) {
    return {
      status: 'low',
      label: 'Underweight',
      note: `Below expected weight for age (${low}–${high} kg).`,
    };
  }
  if (value > high) {
    return {
      status: 'high',
      label: 'Overweight',
      note: `Above expected weight for age (${low}–${high} kg).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Within expected weight for age (${low}–${high} kg).`,
  };
}

export function deduceHeight(
  value: number | null,
  age: AgeInput,
): AnthropometricDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: '' };
  const [low, high] = ANTHRO_RANGES[determineAgeBand(age)].heightCm;

  if (value < low) {
    return {
      status: 'low',
      label: 'Short stature / stunting',
      note: `Below expected height for age (${low}–${high} cm).`,
    };
  }
  if (value > high) {
    return {
      status: 'high',
      label: 'Tall for age',
      note: `Above expected height for age (${low}–${high} cm).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Within expected height for age (${low}–${high} cm).`,
  };
}

export function deduceHeadCircumference(
  value: number | null,
  age: AgeInput,
): AnthropometricDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: '' };

  const band = determineAgeBand(age);
  const range = ANTHRO_RANGES[band].headCircCm;

  if (!range) {
    return {
      status: 'not_assessed',
      label: 'Not routinely measured',
      note: 'Head circumference is measured up to ~2 years of age.',
    };
  }

  const [low, high] = range;

  if (value < low) {
    return {
      status: 'low',
      label: 'Microcephaly',
      note: `Below expected head circumference for age (${low}–${high} cm).`,
    };
  }
  if (value > high) {
    return {
      status: 'high',
      label: 'Macrocephaly',
      note: `Above expected head circumference for age (${low}–${high} cm).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Within expected head circumference for age (${low}–${high} cm).`,
  };
}

export function deduceMuac(
  value: number | null,
  age: AgeInput,
): AnthropometricDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: '' };

  const months = ageInMonths(age);

  // MUAC is primarily validated for children 6–59 months.
  if (months != null && (months < 6 || months > 59)) {
    return {
      status: 'not_assessed',
      label: 'Not age-appropriate',
      note: 'MUAC is used for children aged 6–59 months (~5 years).',
    };
  }

  if (value < 11.5) {
    return {
      status: 'low',
      label: 'Severe acute malnutrition (SAM)',
      note: 'MUAC < 11.5 cm — severe acute malnutrition.',
    };
  }
  if (value < 12.5) {
    return {
      status: 'low',
      label: 'Moderate acute malnutrition (MAM)',
      note: 'MUAC 11.5–12.5 cm — moderate acute malnutrition.',
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: 'MUAC ≥ 12.5 cm — within expected range.',
  };
}

export function deduceBmi(
  value: number | null,
  age: AgeInput,
): AnthropometricDeduction {
  if (value == null) return { status: 'not_assessed', label: 'Not assessed', note: '' };

  const months = ageInMonths(age);

  if (months != null && months < 72) {
    return {
      status: 'not_assessed',
      label: 'Not for this age',
      note: 'BMI is assessed from ~6 years of age.',
    };
  }

  if (value < 18.5) {
    return {
      status: 'low',
      label: 'Underweight',
      note: 'BMI < 18.5 kg/m².',
    };
  }
  if (value >= 30) {
    return {
      status: 'high',
      label: 'Obesity',
      note: 'BMI ≥ 30 kg/m².',
    };
  }
  if (value >= 25) {
    return {
      status: 'high',
      label: 'Overweight',
      note: 'BMI 25–29.9 kg/m².',
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: 'BMI 18.5–24.9 kg/m².',
  };
}

// =============================================================================
// URINE OUTPUT — NORMAL RATES BY AGE
// =============================================================================

export interface UrineOutputRange {
  /** mL/kg/hr */
  min: number;
  max: number;
  label: string;
}

const URINE_OUTPUT_RANGES: Record<AgeBand, UrineOutputRange> = {
  neonate: { min: 1.0, max: 3.0, label: '1–3 mL/kg/hr' },
  infant: { min: 1.5, max: 2.0, label: '1.5–2 mL/kg/hr' },
  toddler: { min: 1.5, max: 2.0, label: '1.5–2 mL/kg/hr' },
  preschool: { min: 1.0, max: 2.0, label: '1–2 mL/kg/hr' },
  school: { min: 1.0, max: 2.0, label: '1–2 mL/kg/hr' },
  adolescent: { min: 0.5, max: 1.0, label: '0.5–1 mL/kg/hr' },
  adult: { min: 0.5, max: 1.0, label: '0.5–1 mL/kg/hr' },
  older_adult: { min: 0.5, max: 1.0, label: '0.5–1 mL/kg/hr' },
};

export function urineOutputRangeForAge(age: AgeInput): UrineOutputRange {
  return URINE_OUTPUT_RANGES[determineAgeBand(age)];
}

/** Calculates mL/hr from total volume (mL) and duration (hours). */
export function urineRatePerHour(
  volumeMl: number | null,
  durationHours: number | null,
): number | null {
  if (volumeMl == null || durationHours == null || durationHours <= 0) {
    return null;
  }
  return volumeMl / durationHours;
}

/** Calculates mL/kg/hr using weight in kg. */
export function urineRatePerKgPerHour(
  volumeMl: number | null,
  durationHours: number | null,
  weightKg: number | null,
): number | null {
  const perHour = urineRatePerHour(volumeMl, durationHours);
  if (perHour == null || weightKg == null || weightKg <= 0) {
    return null;
  }
  return perHour / weightKg;
}

export function deduceUrineOutput(
  volumeMl: number | null,
  durationHours: number | null,
  weightKg: number | null,
  age: AgeInput,
): VitalsDeduction {
  const perKgPerHr = urineRatePerKgPerHour(volumeMl, durationHours, weightKg);
  const expected = urineOutputRangeForAge(age);

  if (perKgPerHr == null) {
    return {
      status: 'not_assessed',
      label: 'Not assessable',
      note: 'Enter urine volume, drainage duration and weight to calculate the rate.',
    };
  }

  if (perKgPerHr < expected.min) {
    return {
      status: 'low',
      label: 'Oliguria',
      note: `Urine output ${perKgPerHr.toFixed(2)} mL/kg/hr — below expected for age (${expected.label}).`,
    };
  }
  if (perKgPerHr > expected.max) {
    return {
      status: 'high',
      label: 'Polyuria',
      note: `Urine output ${perKgPerHr.toFixed(2)} mL/kg/hr — above expected for age (${expected.label}).`,
    };
  }
  return {
    status: 'normal',
    label: 'Normal',
    note: `Urine output ${perKgPerHr.toFixed(2)} mL/kg/hr — within expected for age (${expected.label}).`,
  };
}

// =============================================================================
// PALLOR / SIGNS — GRADING HELPERS
// =============================================================================

export interface SignGradeOption {
  value: string;
  label: string;
}

export const PALLOR_SITES: string[] = [
  'Palmar creases',
  'Conjunctival',
  'Tongue',
  'Mucosa',
  'Skin',
  'Nail beds',
  'Generalised',
];

export const JAUNDICE_SITES: string[] = [
  'Sclera',
  'Skin',
  'Mucosa',
];

export const EDEMA_SITES: string[] = [
  'Lower limbs',
  'Dependent areas (sacrum)',
  'Facial/periorbital',
  'Generalised (anasarca)',
  'Ascites',
];

export const LYMPH_NODE_GROUPS: string[] = [
  'Cervical',
  'Axillary',
  'Epitrochlear',
  'Inguinal',
  'Submandibular',
  'Supraclavicular',
  'Generalised',
];

export function signGradeDescription(plus: string): string {
  switch (plus) {
    case '+':
      return 'Mild';
    case '++':
      return 'Moderate';
    case '+++':
      return 'Severe';
    default:
      return '';
  }
}

/** Grade (1–3) from a plus-string for severity sorting. */
export function plusGrade(plus: string): number {
  if (plus === '+++') return 3;
  if (plus === '++') return 2;
  if (plus === '+') return 1;
  return 0;
}

// =============================================================================
// ANTHROPOMETRY APPLICABILITY — what to measure and which norm to show
// =============================================================================

export interface AnthropometryGuide {
  useLength: boolean;       // < 2 years → recumbent length; otherwise standing height
  showHeadCirc: boolean;    // < 2 years
  showMuac: boolean;        // 6–59 months
  showBmi: boolean;         // ≥ 6 years
  weightExpected: string;
  heightExpected: string;
  headCircExpected: string;
  muacExpected: string;
  bmiExpected: string;
}

export function anthropometryGuide(age: AgeInput): AnthropometryGuide {
  const months = ageInMonths(age);
  const band = determineAgeBand(age);

  const weight = ANTHRO_RANGES[band].weightKg;
  const height = ANTHRO_RANGES[band].heightCm;
  const hc = ANTHRO_RANGES[band].headCircCm;
  const muacNormal = ANTHRO_RANGES[band].muacNormalCm;

  const showHeadCirc = months == null || months < 24;
  const showMuac = months != null && months >= 6 && months <= 59;
  const showBmi = months == null || months >= 72;
  const useLength = months != null && months < 24;

  return {
    useLength,
    showHeadCirc,
    showMuac,
    showBmi,
    weightExpected: `${weight[0]}–${weight[1]} kg`,
    heightExpected: `${height[0]}–${height[1]} cm`,
    headCircExpected: hc ? `${hc[0]}–${hc[1]} cm` : '—',
    muacExpected: `≥ ${muacNormal} cm`,
    bmiExpected: band === 'adult' || band === 'older_adult'
      ? '18.5–24.9'
      : 'By age (WHO)',
  };
}
