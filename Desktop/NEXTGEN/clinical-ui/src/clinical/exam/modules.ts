// =============================================================================
// src/clinical/exam/modules.ts
// AMEXAN — EXAMINATION MODULE DEFINITIONS
//
// The full physical examination following a structured clinical approach:
//   1. Anthropometrics        (paediatric: weight, height/length, HC, MUAC, BMI)
//   2. General Examination    (appearance, nutrition, devices, catheters,
//                              skin signs with grading, lymph nodes, ENT)
//   3. Vital Signs            (BP, HR, RR, SpO₂, temp, RBS)
//   4. System Examinations    (CVS, respiratory, abdomen, CNS, MSK)
//      — each ordered Inspection → Palpation → Percussion → Auscultation
//   5. Local Examination      (mass, ulcer, wound, discharge, surgical sites)
//   6. Special Examinations   (breast, obstetric, etc.)
//
// Modules are declarative data; the UI renders capture controls grouped by
// technique section (see MODULE_TECHNIQUE_SECTIONS) and the knowledge base
// (norms.ts) produces deductions. The CPU stays the authority.
// =============================================================================

import type { ExaminationModule } from '../types';

export type FindingInputType =
  | 'presence'     // Present / Absent
  | 'measurement'  // numeric value + optional unit
  | 'select'       // single choice
  | 'text'         // free text
  | 'severity';    // + / ++ / +++ + site(s)

// -----------------------------------------------------------------------------
// Technique sections — the structured order doctors examine by.
// 'findingCodes' must reference codes that exist in the module's findings.
// Any finding not listed is still rendered, appended after the sections.
// -----------------------------------------------------------------------------

export type TechniqueCode =
  | 'INSPECTION'
  | 'PALPATION_SUPERFICIAL'
  | 'PALPATION_DEEP'
  | 'PERCUSSION'
  | 'AUSCULTATION'
  | 'PULSE'
  | 'MOVEMENT'
  | 'OTHER';

export interface TechniqueSection {
  technique: string;
  code: TechniqueCode;
  step: number; // 1..n order within the module
  findingCodes: string[];
}

// =============================================================================
// 1. ANTHROPOMETRICS (paediatric focus)
// =============================================================================

export const ANTHROPOMETRICS_MODULE: ExaminationModule = {
  moduleCode: 'ANTHROPO',
  name: 'Anthropometric Measurements',
  sequence: 1,
  required: true,
  visible: true,
  findings: [
    {
      findingCode: 'EXAM_ANTHRO_WEIGHT',
      name: 'Weight',
      findingType: 'measurement',
      unitCode: 'kg',
      normalValue: 'By age',
    },
    {
      findingCode: 'EXAM_ANTHRO_HEIGHT',
      name: 'Height / Length',
      findingType: 'measurement',
      unitCode: 'cm',
      normalValue: 'By age',
    },
    {
      findingCode: 'EXAM_ANTHRO_HEAD_CIRC',
      name: 'Head circumference',
      findingType: 'measurement',
      unitCode: 'cm',
      normalValue: 'Up to 2 years',
    },
    {
      findingCode: 'EXAM_ANTHRO_MUAC',
      name: 'MUAC',
      findingType: 'measurement',
      unitCode: 'cm',
      normalValue: '6–59 months',
    },
    {
      findingCode: 'EXAM_ANTHRO_BMI',
      name: 'BMI',
      findingType: 'measurement',
      unitCode: 'kg/m²',
      normalValue: '≥ 6 years',
    },
  ],
};

// =============================================================================
// 2. GENERAL EXAMINATION
// =============================================================================

export const GENERAL_MODULE: ExaminationModule = {
  moduleCode: 'GENERAL',
  name: 'General Examination',
  sequence: 2,
  required: true,
  visible: true,
  findings: [
    {
      findingCode: 'EXAM_GEN_APPEARANCE',
      name: 'Level of consciousness',
      findingType: 'select',
      options: [
        { answerCode: 'alert', label: 'Alert & orientated' },
        { answerCode: 'drowsy', label: 'Drowsy' },
        { answerCode: 'confused', label: 'Confused' },
        { answerCode: 'lethargic', label: 'Lethargic' },
        { answerCode: 'unresponsive', label: 'Unresponsive' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_POSITION',
      name: 'Position / posture',
      findingType: 'select',
      options: [
        { answerCode: 'ambulant', label: 'Ambulant / sitting' },
        { answerCode: 'recumbent', label: 'Recumbent' },
        { answerCode: 'orthopnoeic', label: 'Orthopnoeic' },
        { answerCode: 'dyspnoeic', label: 'Dyspnoeic / distressed' },
        { answerCode: 'fetal', label: 'Fetal position' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_DISTRESS',
      name: 'In visible distress',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_NUTRITION',
      name: 'Nutritional status',
      findingType: 'select',
      options: [
        { answerCode: 'well_nourished', label: 'Well nourished (kempt)' },
        { answerCode: 'moderate', label: 'Moderately nourished' },
        { answerCode: 'malnourished', label: 'Malnourished' },
        { answerCode: 'wasted', label: 'Wasted / emaciated' },
        { answerCode: 'obese', label: 'Obese' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_DEHYDRATION',
      name: 'Dehydration',
      findingType: 'select',
      options: [
        { answerCode: 'none', label: 'None' },
        { answerCode: 'mild', label: 'Mild (<5%)' },
        { answerCode: 'moderate', label: 'Moderate (5–10%)' },
        { answerCode: 'severe', label: 'Severe (>10%)' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_CANNULA',
      name: 'IV cannula in situ',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_CANNULA_SITE',
      name: 'Cannula site',
      findingType: 'select',
      options: [
        { answerCode: 'left_hand', label: 'Left hand' },
        { answerCode: 'right_hand', label: 'Right hand' },
        { answerCode: 'left_forearm', label: 'Left forearm' },
        { answerCode: 'right_forearm', label: 'Right forearm' },
        { answerCode: 'cubital_fossa', label: 'Cubital fossa' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_CANNULA_IMPORTANT',
      name: 'Cannula description / fluids',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_CATHETER',
      name: 'Urinary catheter in situ',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_URINE_COLOR',
      name: 'Urine colour',
      findingType: 'select',
      options: [
        { answerCode: 'clear', label: 'Clear / pale yellow' },
        { answerCode: 'yellow', label: 'Yellow' },
        { answerCode: 'dark_yellow', label: 'Dark yellow' },
        { answerCode: 'amber', label: 'Amber / concentrated' },
        { answerCode: 'blood', label: 'Blood-stained' },
        { answerCode: 'coca_cola', label: 'Coca-cola' },
        { answerCode: 'cloudy', label: 'Cloudy' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_URINE_VOLUME',
      name: 'Urine volume drained',
      findingType: 'measurement',
      unitCode: 'mL',
    },
    {
      findingCode: 'EXAM_GEN_URINE_DURATION',
      name: 'Drainage duration',
      findingType: 'measurement',
      unitCode: 'hours',
    },
    {
      findingCode: 'EXAM_GEN_URINE_OUTPUT_RATE',
      name: 'Urine output rate',
      findingType: 'measurement',
      unitCode: 'mL/hr',
    },
    {
      findingCode: 'EXAM_GEN_PALLOR',
      name: 'Pallor',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_PALLOR_SITE',
      name: 'Pallor site(s)',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_PALLOR_SEVERITY',
      name: 'Pallor severity',
      findingType: 'severity',
    },
    {
      findingCode: 'EXAM_GEN_JAUNDICE',
      name: 'Jaundice',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_JAUNDICE_SITE',
      name: 'Jaundice site(s)',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_JAUNDICE_SEVERITY',
      name: 'Jaundice severity',
      findingType: 'severity',
    },
    {
      findingCode: 'EXAM_GEN_CYANOSIS',
      name: 'Cyanosis',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_CYANOSIS_SITE',
      name: 'Cyanosis site(s)',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_CLUBBING',
      name: 'Finger clubbing',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_CLUBBING_SITE',
      name: 'Clubbing site(s)',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_EDEMA',
      name: 'Edema',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_EDEMA_SITE',
      name: 'Edema site(s)',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_EDEMA_SEVERITY',
      name: 'Edema severity',
      findingType: 'severity',
    },
    {
      findingCode: 'EXAM_GEN_LYMPHADENOPATHY',
      name: 'Lymphadenopathy',
      findingType: 'presence',
    },
    {
      findingCode: 'EXAM_GEN_LYMPH_NODE_SITE',
      name: 'Node group(s)',
      findingType: 'text',
    },
    {
      findingCode: 'EXAM_GEN_LYMPH_NODE_CHARACTER',
      name: 'Node character',
      findingType: 'select',
      options: [
        { answerCode: 'mobile', label: 'Mobile, non-tender' },
        { answerCode: 'tender', label: 'Tender / inflammatory' },
        { answerCode: 'matted', label: 'Matted' },
        { answerCode: 'fixed', label: 'Fixed (hard)' },
        { answerCode: 'rubbery', label: 'Rubbery' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_ENT_ORAL',
      name: 'Oral cavity / ENT',
      findingType: 'select',
      options: [
        { answerCode: 'normal', label: 'Normal' },
        { answerCode: 'thrush', label: 'Oral thrush (candidiasis)' },
        { answerCode: 'tonsillitis', label: 'Tonsillar inflammation' },
        { answerCode: 'pharyngitis', label: 'Pharyngitis' },
        { answerCode: 'stomatitis', label: 'Stomatitis' },
        { answerCode: 'dehydration', label: 'Dry mucosa (dehydrated)' },
        { answerCode: 'abnormal', label: 'Other abnormality' },
      ],
    },
    {
      findingCode: 'EXAM_GEN_ENT_NOTES',
      name: 'ENT / oral notes',
      findingType: 'text',
    },
  ],
};

// =============================================================================
// 3. VITAL SIGNS
// =============================================================================

export const VITALS_MODULE: ExaminationModule = {
  moduleCode: 'VITALS',
  name: 'Vital Signs',
  sequence: 3,
  required: true,
  visible: true,
  findings: [
    {
      findingCode: 'EXAM_VITALS_TEMP',
      name: 'Temperature',
      findingType: 'measurement',
      unitCode: '°C',
      normalValue: '36.1–37.7',
    },
    {
      findingCode: 'EXAM_VITALS_HR',
      name: 'Heart rate',
      findingType: 'measurement',
      unitCode: 'bpm',
      normalValue: 'By age',
    },
    {
      findingCode: 'EXAM_VITALS_RR',
      name: 'Respiratory rate',
      findingType: 'measurement',
      unitCode: '/min',
      normalValue: 'By age',
    },
    {
      findingCode: 'EXAM_VITALS_SBP',
      name: 'Blood pressure — systolic',
      findingType: 'measurement',
      unitCode: 'mmHg',
      normalValue: 'By age',
    },
    {
      findingCode: 'EXAM_VITALS_DBP',
      name: 'Blood pressure — diastolic',
      findingType: 'measurement',
      unitCode: 'mmHg',
      normalValue: 'By age',
    },
    {
      findingCode: 'EXAM_VITALS_SPO2',
      name: 'Oxygen saturation (SpO₂)',
      findingType: 'measurement',
      unitCode: '%',
      normalValue: '≥ 95',
    },
    {
      findingCode: 'EXAM_VITALS_RBS',
      name: 'Random blood sugar',
      findingType: 'measurement',
      unitCode: 'mmol/L',
      normalValue: '3.9–7.8',
    },
  ],
};

// =============================================================================
// 4. SYSTEM EXAMINATIONS — ordered Inspection → Palpation → Percussion →
//    Auscultation (abdomen: Inspection → Auscultation → Percussion → Palpation)
// =============================================================================

export const CVS_MODULE: ExaminationModule = {
  moduleCode: 'CVS',
  name: 'Cardiovascular System',
  sequence: 4,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_CVS_JVP', name: 'Jugular venous pressure', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal (≤ 4 cm)' }, { answerCode: 'raised', label: 'Raised' }, { answerCode: 'not_visible', label: 'Not visible' }] },
    { findingCode: 'EXAM_CVS_PRECORDIAL_BULGE', name: 'Precordial bulge / visible impulse', findingType: 'presence' },
    { findingCode: 'EXAM_CVS_APEX', name: 'Apex beat (location / character)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal 5th ICS, MCL' }, { answerCode: 'displaced', label: 'Displaced' }, { answerCode: 'diffuse', label: 'Diffuse / thrusting' }] },
    { findingCode: 'EXAM_CVS_HEAVES', name: 'Parasternal heave', findingType: 'presence' },
    { findingCode: 'EXAM_CVS_THRILLS', name: 'Palpable thrill', findingType: 'presence' },
    { findingCode: 'EXAM_CVS_HEART_SOUNDS', name: 'Heart sounds', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal S1 S2' }, { answerCode: 'soft', label: 'Soft / muffled' }, { answerCode: 'loud_s1', label: 'Loud S1' }, { answerCode: 's3', label: 'Third sound (S3)' }, { answerCode: 's4', label: 'Fourth sound (S4)' }] },
    { findingCode: 'EXAM_CVS_MURMUR', name: 'Murmur', findingType: 'select', options: [{ answerCode: 'none', label: 'None' }, { answerCode: 'systolic', label: 'Systolic' }, { answerCode: 'diastolic', label: 'Diastolic' }, { answerCode: 'continuous', label: 'Continuous' }] },
    { findingCode: 'EXAM_CVS_MURMUR_GRADE', name: 'Murmur grade', findingType: 'select', options: [{ answerCode: '1', label: '1/6' }, { answerCode: '2', label: '2/6' }, { answerCode: '3', label: '3/6' }, { answerCode: '4', label: '4/6' }, { answerCode: '5', label: '5/6' }, { answerCode: '6', label: '6/6' }] },
    { findingCode: 'EXAM_CVS_MURMUR_NOTES', name: 'Murmur description (site, radiation)', findingType: 'text' },
    { findingCode: 'EXAM_CVS_PERICARDIAL_RUB', name: 'Pericardial rub', findingType: 'presence' },
    { findingCode: 'EXAM_CVS_PULSE_RATE', name: 'Radial pulse rate', findingType: 'measurement', unitCode: 'bpm' },
    { findingCode: 'EXAM_CVS_PULSE_RHYTHM', name: 'Pulse rhythm', findingType: 'select', options: [{ answerCode: 'regular', label: 'Regular' }, { answerCode: 'irregularly_irregular', label: 'Irregularly irregular' }, { answerCode: 'regularly_irregular', label: 'Regularly irregular' }] },
    { findingCode: 'EXAM_CVS_PULSE_CHARACTER', name: 'Pulse character', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal volume' }, { answerCode: 'weak', label: 'Weak / thready' }, { answerCode: 'bounding', label: 'Bounding / collapsing' }, { answerCode: 'slow_rising', label: 'Slow-rising' }] },
    { findingCode: 'EXAM_CVS_PERIPHERAL_PULSES', name: 'Peripheral pulses (radial→femoral→pedal)', findingType: 'select', options: [{ answerCode: 'normal', label: 'All present & equal' }, { answerCode: 'weak', label: 'Weak / reduced' }, { answerCode: 'absent', label: 'Absent' }] },
    { findingCode: 'EXAM_CVS_EDEMA', name: 'Dependent edema', findingType: 'presence' },
  ],
};

export const RESPIRATORY_MODULE: ExaminationModule = {
  moduleCode: 'RESP',
  name: 'Respiratory System',
  sequence: 5,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_RESP_CHEST_SHAPE', name: 'Chest shape', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal / symmetrical' }, { answerCode: 'barrel', label: 'Barrel-shaped' }, { answerCode: 'pectus', label: 'Pectus excavatum / carinatum' }, { answerCode: 'kyphotic', label: 'Kyphoscoliotic' }] },
    { findingCode: 'EXAM_RESP_WORK_OF_BREATHING', name: 'Work of breathing', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'intercostal', label: 'Intercostal recession' }, { answerCode: 'subcostal', label: 'Subcostal recession' }, { answerCode: 'nasal_flaring', label: 'Nasal flaring' }, { answerCode: 'grunting', label: 'Grunting' }, { answerCode: 'accessory', label: 'Accessory muscle use' }] },
    { findingCode: 'EXAM_RESP_BREATHING_PATTERN', name: 'Breathing pattern', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'rapid', label: 'Rapid / shallow' }, { answerCode: 'kussmaul', label: 'Kussmaul' }, { answerCode: 'cheyne_stokes', label: 'Cheyne-Stokes' }] },
    { findingCode: 'EXAM_RESP_SCARS', name: 'Chest scars / sinuses', findingType: 'presence' },
    { findingCode: 'EXAM_RESP_TRACHEA', name: 'Trachea (palpation)', findingType: 'select', options: [{ answerCode: 'central', label: 'Central' }, { answerCode: 'deviated', label: 'Deviated' }] },
    { findingCode: 'EXAM_RESP_CHEST_EXPANSION', name: 'Chest expansion', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal & symmetrical' }, { answerCode: 'reduced', label: 'Reduced' }, { answerCode: 'asymmetric', label: 'Asymmetric' }] },
    { findingCode: 'EXAM_RESP_VOCAL_FREMITUS', name: 'Vocal fremitus', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'increased', label: 'Increased' }, { answerCode: 'reduced', label: 'Reduced' }] },
    { findingCode: 'EXAM_RESP_PERCCUSSION', name: 'Percussion note', findingType: 'select', options: [{ answerCode: 'resonant', label: 'Resonant' }, { answerCode: 'dull', label: 'Dull' }, { answerCode: 'hyperresonant', label: 'Hyper-resonant' }, { answerCode: 'stony_dull', label: 'Stony dull' }] },
    { findingCode: 'EXAM_RESP_AUSCULTATION', name: 'Breath sounds', findingType: 'select', options: [{ answerCode: 'clear', label: 'Clear / vesicular' }, { answerCode: 'wheeze', label: 'Wheezing' }, { answerCode: 'crackles', label: 'Crackles' }, { answerCode: 'reduced', label: 'Reduced / absent' }, { answerCode: 'bronchial', label: 'Bronchial breathing' }, { answerCode: 'pleural_rub', label: 'Pleural rub' }] },
    { findingCode: 'EXAM_RESP_VOCAL_RESONANCE', name: 'Vocal resonance', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'increased', label: 'Increased (bronchophony)' }, { answerCode: 'reduced', label: 'Reduced' }] },
    { findingCode: 'EXAM_RESP_AUSC_NOTES', name: 'Auscultation notes', findingType: 'text' },
  ],
};

export const ABDOMINAL_MODULE: ExaminationModule = {
  moduleCode: 'ABDOMEN',
  name: 'Abdominal Examination',
  sequence: 6,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_ABD_INSPECTION', name: 'Inspection (contour, scars, distension)', findingType: 'select', options: [{ answerCode: 'flat', label: 'Flat / scaphoid' }, { answerCode: 'distended', label: 'Distended' }, { answerCode: 'scars', label: 'Scars visible' }, { answerCode: 'hernia', label: 'Hernia / swellings' }, { answerCode: 'visible_pulsations', label: 'Visible pulsations' }] },
    { findingCode: 'EXAM_ABD_MOVES_RESPIRATION', name: 'Moves with respiration', findingType: 'select', options: [{ answerCode: 'yes', label: 'Yes' }, { answerCode: 'no', label: 'No (rigid abdomen)' }] },
    { findingCode: 'EXAM_ABD_AUSCULTATION', name: 'Bowel sounds (auscultate before palpation)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'hyperactive', label: 'Hyperactive' }, { answerCode: 'absent', label: 'Absent / reduced' }] },
    { findingCode: 'EXAM_ABD_PERCUSSION', name: 'Percussion', findingType: 'select', options: [{ answerCode: 'tympanic', label: 'Tympanic' }, { answerCode: 'dull', label: 'Dull' }, { answerCode: 'normal', label: 'Normal' }] },
    { findingCode: 'EXAM_ABD_SHIFTING_DULLNESS', name: 'Shifting dullness (ascites)', findingType: 'presence' },
    { findingCode: 'EXAM_ABD_PALPATION_SUPERFICIAL', name: 'Superficial palpation', findingType: 'select', options: [{ answerCode: 'soft', label: 'Soft, non-tender' }, { answerCode: 'tender', label: 'Tender' }, { answerCode: 'guarding', label: 'Guarding' }, { answerCode: 'rigid', label: 'Rigid' }] },
    { findingCode: 'EXAM_ABD_REBOUND', name: 'Rebound tenderness', findingType: 'presence' },
    { findingCode: 'EXAM_ABD_PALPATION_DEEP', name: 'Deep palpation (mass)', findingType: 'select', options: [{ answerCode: 'none', label: 'No mass' }, { answerCode: 'mass', label: 'Palpable mass' }] },
    { findingCode: 'EXAM_ABD_MASS_DETAIL', name: 'Mass details (site, size, mobility)', findingType: 'text' },
    { findingCode: 'EXAM_ABD_ORGANS', name: 'Liver / spleen / kidneys', findingType: 'select', options: [{ answerCode: 'not_palpable', label: 'Not palpable' }, { answerCode: 'hepatomegaly', label: 'Hepatomegaly' }, { answerCode: 'splenomegaly', label: 'Splenomegaly' }, { answerCode: 'both', label: 'Hepatosplenomegaly' }] },
  ],
};

export const CNS_MODULE: ExaminationModule = {
  moduleCode: 'CNS',
  name: 'Nervous System Examination',
  sequence: 7,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_CNS_CONSCIOUSNESS', name: 'Level of consciousness (AVPU)', findingType: 'select', options: [{ answerCode: 'alert', label: 'Alert' }, { answerCode: 'voice', label: 'Responds to voice' }, { answerCode: 'pain', label: 'Responds to pain' }, { answerCode: 'unresponsive', label: 'Unresponsive' }] },
    { findingCode: 'EXAM_CNS_ORIENTATION', name: 'Orientation (time / place / person)', findingType: 'select', options: [{ answerCode: 'intact', label: 'Fully orientated' }, { answerCode: 'partial', label: 'Partially disorientated' }, { answerCode: 'disorientated', label: 'Disorientated' }] },
    { findingCode: 'EXAM_CNS_MEMORY', name: 'Memory (short & long term)', findingType: 'select', options: [{ answerCode: 'intact', label: 'Intact' }, { answerCode: 'impaired_short', label: 'Short-term impaired' }, { answerCode: 'impaired', label: 'Impaired' }] },
    { findingCode: 'EXAM_CNS_SPEECH', name: 'Speech / language', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'dysarthria', label: 'Dysarthria' }, { answerCode: 'aphasia', label: 'Aphasia' }] },
    { findingCode: 'EXAM_CNS_CRANIAL_NERVES', name: 'Cranial nerves (overall)', findingType: 'select', options: [{ answerCode: 'normal', label: 'All intact' }, { answerCode: 'abnormal', label: 'Abnormal' }] },
    { findingCode: 'EXAM_CNS_CN3_4_6', name: 'CN III, IV, VI (pupils, EOM)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'pupil_abnormal', label: 'Pupil abnormality' }, { answerCode: 'nystagmus', label: 'Nystagmus' }, { answerCode: 'ophthalmoplegia', label: 'Ophthalmoplegia' }] },
    { findingCode: 'EXAM_CNS_CN7', name: 'CN VII (facial movements)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'upper_motor', label: 'Upper motor neuron' }, { answerCode: 'lower_motor', label: 'Lower motor neuron' }] },
    { findingCode: 'EXAM_CNS_CN9_10', name: 'CN IX, X (palate, swallow, gag)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'impaired', label: 'Impaired swallow / palate' }] },
    { findingCode: 'EXAM_CNS_CN11', name: 'CN XI (sternocleidomastoid, trapezius)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'weak', label: 'Weakness' }] },
    { findingCode: 'EXAM_CNS_CN12', name: 'CN XII (tongue)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'deviation', label: 'Deviation / wasting' }] },
    { findingCode: 'EXAM_CNS_CRANIAL_NOTES', name: 'Cranial nerve findings (detailed)', findingType: 'text' },
    { findingCode: 'EXAM_CNS_MUSCLE_BULK', name: 'Muscle bulk (wasting, fasciculations)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'wasting', label: 'Wasting' }, { answerCode: 'fasciculations', label: 'Fasciculations' }] },
    { findingCode: 'EXAM_CNS_TONE', name: 'Muscle tone', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'spastic', label: 'Spastic' }, { answerCode: 'rigid', label: 'Rigid' }, { answerCode: 'hypotonic', label: 'Hypotonic' }] },
    { findingCode: 'EXAM_CNS_MOTOR', name: 'Upper limb power (MRC)', findingType: 'select', options: [{ answerCode: '5', label: '5/5' }, { answerCode: '4', label: '4/5' }, { answerCode: '3', label: '3/5' }, { answerCode: '2', label: '2/5' }, { answerCode: '1', label: '1/5' }, { answerCode: '0', label: '0/5' }] },
    { findingCode: 'EXAM_CNS_MOTOR_LOWER', name: 'Lower limb power (MRC)', findingType: 'select', options: [{ answerCode: '5', label: '5/5' }, { answerCode: '4', label: '4/5' }, { answerCode: '3', label: '3/5' }, { answerCode: '2', label: '2/5' }, { answerCode: '1', label: '1/5' }, { answerCode: '0', label: '0/5' }] },
    { findingCode: 'EXAM_CNS_PRONATOR_DRIFT', name: 'Pronator drift', findingType: 'select', options: [{ answerCode: 'absent', label: 'Absent' }, { answerCode: 'present', label: 'Present' }] },
    { findingCode: 'EXAM_CNS_SENSATION', name: 'Light touch / pain', findingType: 'select', options: [{ answerCode: 'normal', label: 'Intact' }, { answerCode: 'reduced', label: 'Reduced' }, { answerCode: 'absent', label: 'Absent' }, { answerCode: 'hyperaesthesia', label: 'Hyperaesthesia' }] },
    { findingCode: 'EXAM_CNS_SENSATION_VIBRATION', name: 'Vibration / proprioception', findingType: 'select', options: [{ answerCode: 'normal', label: 'Intact' }, { answerCode: 'reduced', label: 'Reduced' }, { answerCode: 'absent', label: 'Absent' }] },
    { findingCode: 'EXAM_CNS_REFLEXES', name: 'Deep tendon reflexes', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'brisk', label: 'Brisk' }, { answerCode: 'reduced', label: 'Reduced / absent' }] },
    { findingCode: 'EXAM_CNS_PLANTAR', name: 'Plantar response', findingType: 'select', options: [{ answerCode: 'downgoing', label: 'Down-going (flexor)' }, { answerCode: 'upgoing', label: 'Up-going (extensor)' }] },
    { findingCode: 'EXAM_CNS_CLONUS', name: 'Ankle clonus', findingType: 'select', options: [{ answerCode: 'absent', label: 'Absent' }, { answerCode: 'sustained', label: 'Sustained' }, { answerCode: 'unsustained', label: 'Unsustained' }] },
    { findingCode: 'EXAM_CNS_CEREBELLAR', name: 'Cerebellar (finger–nose, heel–shin)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'intention_tremor', label: 'Intention tremor' }, { answerCode: 'dysmetria', label: 'Dysmetria' }, { answerCode: 'dysdiadochokinesis', label: 'Dysdiadochokinesis' }] },
    { findingCode: 'EXAM_CNS_GAIT', name: 'Gait', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'ataxic', label: 'Ataxic' }, { answerCode: 'hemiplegic', label: 'Hemiplegic' }, { answerCode: 'parkinsonian', label: 'Parkinsonian' }, { answerCode: 'unable', label: 'Unable to walk' }] },
    { findingCode: 'EXAM_CNS_ROMBERG', name: 'Romberg test', findingType: 'select', options: [{ answerCode: 'negative', label: 'Negative' }, { answerCode: 'positive', label: 'Positive' }] },
    { findingCode: 'EXAM_CNS_SIGNS', name: 'Meningism', findingType: 'select', options: [{ answerCode: 'absent', label: 'Absent' }, { answerCode: 'neck_stiffness', label: 'Neck stiffness' }, { answerCode: 'kernig', label: 'Kernig positive' }, { answerCode: 'brudzinski', label: 'Brudzinski positive' }] },
  ],
};

export const MSK_MODULE: ExaminationModule = {
  moduleCode: 'MSK',
  name: 'Musculoskeletal System',
  sequence: 8,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_MSK_JOINT', name: 'Joint(s) involved', findingType: 'text' },
    { findingCode: 'EXAM_MSK_SWELLING', name: 'Swelling / deformity (look)', findingType: 'presence' },
    { findingCode: 'EXAM_MSK_SWELLING_DETAIL', name: 'Swelling details (distribution, symmetry)', findingType: 'text' },
    { findingCode: 'EXAM_MSK_WARMTH', name: 'Warmth / erythema (feel)', findingType: 'presence' },
    { findingCode: 'EXAM_MSK_TENDERNESS', name: 'Tenderness (feel)', findingType: 'presence' },
    { findingCode: 'EXAM_MSK_ROM', name: 'Range of movement (move)', findingType: 'select', options: [{ answerCode: 'full', label: 'Full & pain-free' }, { answerCode: 'limited', label: 'Limited' }, { answerCode: 'painful', label: 'Painful' }] },
    { findingCode: 'EXAM_MSK_ROM_DETAIL', name: 'ROM details / crepitus', findingType: 'text' },
  ],
};

// =============================================================================
// 5. LOCAL EXAMINATION (surgical / focal findings)
// =============================================================================

export const LOCAL_MODULE: ExaminationModule = {
  moduleCode: 'LOCAL',
  name: 'Local Examination',
  sequence: 9,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_LOCAL_TYPE', name: 'Local finding type', findingType: 'select', options: [
      { answerCode: 'mass', label: 'Mass' },
      { answerCode: 'ulcer', label: 'Ulcer' },
      { answerCode: 'wound', label: 'Wound' },
      { answerCode: 'discharge', label: 'Discharge' },
      { answerCode: 'surgical_site', label: 'Surgical site' },
      { answerCode: 'skin_lesion', label: 'Skin lesion' },
      { answerCode: 'none', label: 'None required' },
    ] },
    { findingCode: 'EXAM_LOCAL_SITE', name: 'Site', findingType: 'text' },
    { findingCode: 'EXAM_LOCAL_SIZE', name: 'Size (cm)', findingType: 'measurement', unitCode: 'cm' },
    { findingCode: 'EXAM_LOCAL_SHAPE', name: 'Shape / surface', findingType: 'select', options: [{ answerCode: 'round', label: 'Round' }, { answerCode: 'oval', label: 'Oval' }, { answerCode: 'irregular', label: 'Irregular' }, { answerCode: 'lobulated', label: 'Lobulated' }] },
    { findingCode: 'EXAM_LOCAL_EDGE', name: 'Edge', findingType: 'select', options: [{ answerCode: 'well_defined', label: 'Well-defined' }, { answerCode: 'irregular', label: 'Irregular / rolled' }, { answerCode: 'sloping', label: 'Sloping' }, { answerCode: 'punched_out', label: 'Punched-out' }] },
    { findingCode: 'EXAM_LOCAL_CONSISTENCY', name: 'Consistency', findingType: 'select', options: [{ answerCode: 'soft', label: 'Soft' }, { answerCode: 'firm', label: 'Firm' }, { answerCode: 'hard', label: 'Hard / stony' }, { answerCode: 'cystic', label: 'Cystic / fluctuant' }] },
    { findingCode: 'EXAM_LOCAL_MOBILITY', name: 'Mobility / fixity', findingType: 'select', options: [{ answerCode: 'mobile', label: 'Mobile' }, { answerCode: 'fixed', label: 'Fixed to deep structures' }, { answerCode: 'tethered', label: 'Tethered' }] },
    { findingCode: 'EXAM_LOCAL_TENDERNESS', name: 'Tenderness', findingType: 'presence' },
    { findingCode: 'EXAM_LOCAL_TRANSMISSION', name: 'Transillumination', findingType: 'select', options: [{ answerCode: 'not_positive', label: 'Not positive' }, { answerCode: 'positive', label: 'Positive' }] },
    { findingCode: 'EXAM_LOCAL_REDUCIBLE', name: 'Reducibility', findingType: 'select', options: [{ answerCode: 'not_applicable', label: 'N/A' }, { answerCode: 'reducible', label: 'Reducible' }, { answerCode: 'irreducible', label: 'Irreducible' }] },
    { findingCode: 'EXAM_LOCAL_DISCHARGE', name: 'Discharge characteristics', findingType: 'select', options: [{ answerCode: 'none', label: 'None' }, { answerCode: 'serous', label: 'Serous' }, { answerCode: 'purulent', label: 'Purulent' }, { answerCode: 'blood', label: 'Blood-stained' }, { answerCode: 'foul', label: 'Foul-smelling' }] },
    { findingCode: 'EXAM_LOCAL_SURROUNDING_SKIN', name: 'Surrounding skin', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'erythema', label: 'Erythematous' }, { answerCode: 'inflamed', label: 'Inflamed / hot' }, { answerCode: 'indurated', label: 'Indurated' }] },
    { findingCode: 'EXAM_LOCAL_NOTES', name: 'Local findings notes', findingType: 'text' },
  ],
};

// =============================================================================
// 6. SPECIAL EXAMINATIONS
// =============================================================================

export const BREAST_MODULE: ExaminationModule = {
  moduleCode: 'BREAST',
  name: 'Breast Examination',
  sequence: 10,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_BREAST_INSPECTION', name: 'Inspection (symmetry, skin, nipple)', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'asymmetry', label: 'Asymmetry' }, { answerCode: 'dimpling', label: 'Skin dimpling' }, { answerCode: 'nipple_retraction', label: 'Nipple retraction' }, { answerCode: 'skin_changes', label: 'Skin changes (peau d’orange)' }, { answerCode: 'nipple_discharge', label: 'Nipple discharge' }] },
    { findingCode: 'EXAM_BREAST_MASS', name: 'Palpable mass', findingType: 'presence' },
    { findingCode: 'EXAM_BREAST_MASS_DETAIL', name: 'Mass details (quadrant, clock face, consistency, mobility)', findingType: 'text' },
    { findingCode: 'EXAM_BREAST_NODES', name: 'Axillary lymph nodes', findingType: 'select', options: [{ answerCode: 'not_palpable', label: 'Not palpable' }, { answerCode: 'palpable', label: 'Palpable' }] },
  ],
};

export const OBSTETRIC_MODULE: ExaminationModule = {
  moduleCode: 'OBSTETRIC',
  name: 'Obstetric / Gynaecological',
  sequence: 11,
  required: false,
  visible: true,
  findings: [
    { findingCode: 'EXAM_OB_FUNDAL_HEIGHT', name: 'Fundal height (cm)', findingType: 'measurement', unitCode: 'cm' },
    { findingCode: 'EXAM_OB_LEOPOLD_LIE', name: 'Leopold 1 — lie', findingType: 'select', options: [{ answerCode: 'longitudinal', label: 'Longitudinal' }, { answerCode: 'oblique', label: 'Oblique' }, { answerCode: 'transverse', label: 'Transverse' }] },
    { findingCode: 'EXAM_OB_PRESENTATION', name: 'Leopold 2–3 — presentation', findingType: 'select', options: [{ answerCode: 'cephalic', label: 'Cephalic' }, { answerCode: 'breech', label: 'Breech' }, { answerCode: 'transverse', label: 'Transverse' }] },
    { findingCode: 'EXAM_OB_FETAL_HEART', name: 'Fetal heart rate (auscultation)', findingType: 'measurement', unitCode: 'bpm' },
    { findingCode: 'EXAM_OB_CONTRACTIONS', name: 'Contractions (palpation)', findingType: 'select', options: [{ answerCode: 'absent', label: 'Absent' }, { answerCode: 'mild', label: 'Mild' }, { answerCode: 'moderate', label: 'Moderate' }, { answerCode: 'strong', label: 'Strong' }] },
    { findingCode: 'EXAM_OB_UTERINE_TONE', name: 'Uterine tone', findingType: 'select', options: [{ answerCode: 'normal', label: 'Normal' }, { answerCode: 'hypertonic', label: 'Hypertonic' }, { answerCode: 'relaxed', label: 'Relaxed / atonic' }] },
    { findingCode: 'EXAM_OB_VAGINAL_BLEEDING', name: 'Vaginal bleeding / liquor', findingType: 'select', options: [{ answerCode: 'none', label: 'None' }, { answerCode: 'bleeding', label: 'Bleeding' }, { answerCode: 'liquor', label: 'Liquor draining' }] },
  ],
};

// =============================================================================
// TECHNIQUE SECTION MAPS — ordered, speed-first grouping for each system.
// Abdomen uses Inspection → Auscultation → Percussion → Palpation (textbook).
// =============================================================================

export const MODULE_TECHNIQUE_SECTIONS: Record<string, TechniqueSection[]> = {
  CVS: [
    { technique: 'Inspection', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_CVS_JVP', 'EXAM_CVS_PRECORDIAL_BULGE'] },
    { technique: 'Palpation', code: 'PALPATION_SUPERFICIAL', step: 2, findingCodes: ['EXAM_CVS_APEX', 'EXAM_CVS_HEAVES', 'EXAM_CVS_THRILLS'] },
    { technique: 'Auscultation', code: 'AUSCULTATION', step: 3, findingCodes: ['EXAM_CVS_HEART_SOUNDS', 'EXAM_CVS_MURMUR', 'EXAM_CVS_MURMUR_GRADE', 'EXAM_CVS_MURMUR_NOTES', 'EXAM_CVS_PERICARDIAL_RUB'] },
    { technique: 'Pulse & Peripheral', code: 'PULSE', step: 4, findingCodes: ['EXAM_CVS_PULSE_RATE', 'EXAM_CVS_PULSE_RHYTHM', 'EXAM_CVS_PULSE_CHARACTER', 'EXAM_CVS_PERIPHERAL_PULSES', 'EXAM_CVS_EDEMA'] },
  ],
  RESP: [
    { technique: 'Inspection', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_RESP_CHEST_SHAPE', 'EXAM_RESP_WORK_OF_BREATHING', 'EXAM_RESP_BREATHING_PATTERN', 'EXAM_RESP_SCARS'] },
    { technique: 'Palpation', code: 'PALPATION_SUPERFICIAL', step: 2, findingCodes: ['EXAM_RESP_TRACHEA', 'EXAM_RESP_CHEST_EXPANSION', 'EXAM_RESP_VOCAL_FREMITUS'] },
    { technique: 'Percussion', code: 'PERCUSSION', step: 3, findingCodes: ['EXAM_RESP_PERCCUSSION'] },
    { technique: 'Auscultation', code: 'AUSCULTATION', step: 4, findingCodes: ['EXAM_RESP_AUSCULTATION', 'EXAM_RESP_VOCAL_RESONANCE', 'EXAM_RESP_AUSC_NOTES'] },
  ],
  ABDOMEN: [
    { technique: 'Inspection', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_ABD_INSPECTION', 'EXAM_ABD_MOVES_RESPIRATION'] },
    { technique: 'Auscultation', code: 'AUSCULTATION', step: 2, findingCodes: ['EXAM_ABD_AUSCULTATION'] },
    { technique: 'Percussion', code: 'PERCUSSION', step: 3, findingCodes: ['EXAM_ABD_PERCUSSION', 'EXAM_ABD_SHIFTING_DULLNESS'] },
    { technique: 'Palpation — superficial', code: 'PALPATION_SUPERFICIAL', step: 4, findingCodes: ['EXAM_ABD_PALPATION_SUPERFICIAL', 'EXAM_ABD_REBOUND'] },
    { technique: 'Palpation — deep', code: 'PALPATION_DEEP', step: 5, findingCodes: ['EXAM_ABD_PALPATION_DEEP', 'EXAM_ABD_MASS_DETAIL', 'EXAM_ABD_ORGANS'] },
  ],
  CNS: [
    { technique: 'Higher mental functions', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_CNS_CONSCIOUSNESS', 'EXAM_CNS_ORIENTATION', 'EXAM_CNS_MEMORY', 'EXAM_CNS_SPEECH'] },
    { technique: 'Cranial nerves', code: 'INSPECTION', step: 2, findingCodes: ['EXAM_CNS_CRANIAL_NERVES', 'EXAM_CNS_CN3_4_6', 'EXAM_CNS_CN7', 'EXAM_CNS_CN9_10', 'EXAM_CNS_CN11', 'EXAM_CNS_CN12', 'EXAM_CNS_CRANIAL_NOTES'] },
    { technique: 'Motor system', code: 'PALPATION_SUPERFICIAL', step: 3, findingCodes: ['EXAM_CNS_MUSCLE_BULK', 'EXAM_CNS_TONE', 'EXAM_CNS_MOTOR', 'EXAM_CNS_MOTOR_LOWER', 'EXAM_CNS_PRONATOR_DRIFT'] },
    { technique: 'Sensory system', code: 'PALPATION_DEEP', step: 4, findingCodes: ['EXAM_CNS_SENSATION', 'EXAM_CNS_SENSATION_VIBRATION'] },
    { technique: 'Reflexes', code: 'PERCUSSION', step: 5, findingCodes: ['EXAM_CNS_REFLEXES', 'EXAM_CNS_PLANTAR', 'EXAM_CNS_CLONUS'] },
    { technique: 'Cerebellar & gait', code: 'AUSCULTATION', step: 6, findingCodes: ['EXAM_CNS_CEREBELLAR', 'EXAM_CNS_GAIT', 'EXAM_CNS_ROMBERG'] },
    { technique: 'Meningism', code: 'OTHER', step: 7, findingCodes: ['EXAM_CNS_SIGNS'] },
  ],
  MSK: [
    { technique: 'Look (inspection)', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_MSK_JOINT', 'EXAM_MSK_SWELLING', 'EXAM_MSK_SWELLING_DETAIL'] },
    { technique: 'Feel (palpation)', code: 'PALPATION_SUPERFICIAL', step: 2, findingCodes: ['EXAM_MSK_WARMTH', 'EXAM_MSK_TENDERNESS'] },
    { technique: 'Move', code: 'MOVEMENT', step: 3, findingCodes: ['EXAM_MSK_ROM', 'EXAM_MSK_ROM_DETAIL'] },
  ],
  BREAST: [
    { technique: 'Inspection', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_BREAST_INSPECTION'] },
    { technique: 'Palpation', code: 'PALPATION_SUPERFICIAL', step: 2, findingCodes: ['EXAM_BREAST_MASS', 'EXAM_BREAST_MASS_DETAIL', 'EXAM_BREAST_NODES'] },
  ],
  OBSTETRIC: [
    { technique: 'Inspection & measurements', code: 'INSPECTION', step: 1, findingCodes: ['EXAM_OB_FUNDAL_HEIGHT', 'EXAM_OB_VAGINAL_BLEEDING'] },
    { technique: 'Palpation (Leopold)', code: 'PALPATION_SUPERFICIAL', step: 2, findingCodes: ['EXAM_OB_LEOPOLD_LIE', 'EXAM_OB_PRESENTATION', 'EXAM_OB_CONTRACTIONS', 'EXAM_OB_UTERINE_TONE'] },
    { technique: 'Auscultation', code: 'AUSCULTATION', step: 3, findingCodes: ['EXAM_OB_FETAL_HEART'] },
  ],
};

// =============================================================================
// EXPORT — full ordered module set
// =============================================================================

export const ALL_EXAMINATION_MODULES: ExaminationModule[] = [
  ANTHROPOMETRICS_MODULE,
  GENERAL_MODULE,
  VITALS_MODULE,
  CVS_MODULE,
  RESPIRATORY_MODULE,
  ABDOMINAL_MODULE,
  CNS_MODULE,
  MSK_MODULE,
  LOCAL_MODULE,
  BREAST_MODULE,
  OBSTETRIC_MODULE,
];

export const EXAMINATION_MODULES_BY_CODE: Record<string, ExaminationModule> =
  Object.fromEntries(
    ALL_EXAMINATION_MODULES.map((module) => [module.moduleCode, module]),
  );

// =============================================================================
// MODULE GROUPING FOR THE NAVIGATOR
// =============================================================================

export interface ExaminationPhase {
  phaseCode: string;
  label: string;
  moduleCodes: string[];
}

export const EXAMINATION_PHASES: ExaminationPhase[] = [
  {
    phaseCode: 'ANTHROPOMETRY',
    label: 'Anthropometry',
    moduleCodes: ['ANTHROPO'],
  },
  {
    phaseCode: 'GENERAL',
    label: 'General Examination',
    moduleCodes: ['GENERAL'],
  },
  {
    phaseCode: 'VITALS',
    label: 'Vital Signs',
    moduleCodes: ['VITALS'],
  },
  {
    phaseCode: 'SYSTEMS',
    label: 'System Examination',
    moduleCodes: ['CVS', 'RESP', 'ABDOMEN', 'CNS', 'MSK'],
  },
  {
    phaseCode: 'LOCAL',
    label: 'Local Examination',
    moduleCodes: ['LOCAL'],
  },
  {
    phaseCode: 'SPECIAL',
    label: 'Special Examinations',
    moduleCodes: ['BREAST', 'OBSTETRIC'],
  },
];