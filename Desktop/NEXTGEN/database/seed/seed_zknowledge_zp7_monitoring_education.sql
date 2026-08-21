-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP7
-- UNIVERSAL MONITORING + EDUCATION INTELLIGENCE
-- =============================================================================
--
-- PURPOSE
-- -------
-- Monitoring and education are not disease-owned.
--
-- The architecture is:
--
--   UNIVERSAL CONCEPT
--          ?
--      MONITORING
--          ?
--   CONDITION JUNCTION
--          ?
--   CLINICAL PLAN / CPU
--
-- and:
--
--   UNIVERSAL CONCEPT
--          ?
--      EDUCATION
--          ?
--   CONDITION JUNCTION
--          ?
--   TEACH-BACK / DISCHARGE / FOLLOW-UP
--
-- Current Phase-1E conditions:
--
--   PNEUMONIA
--   TUBERCULOSIS
--   ASTHMA
--   HEART FAILURE
--   GERD
--
-- IMPORTANT
-- ---------
-- Numeric normal ranges below are reference ranges for adult/general
-- monitoring only. They are NOT diagnostic thresholds and must not replace
-- age-, pregnancy-, disease-, altitude-, or jurisdiction-specific clinical
-- thresholds.
--
-- Paediatric, neonatal, pregnancy and disease-specific thresholds should
-- eventually be represented through a separate threshold/rule layer rather
-- than duplicating monitoring concepts.
--
-- Education content is intentionally reusable and written as content data.
-- The clinical CPU decides when it should surface it.
-- =============================================================================


-- =============================================================================
-- 1. MONITORING DEFINITIONS
-- =============================================================================
-- A monitoring row represents WHAT is monitored.
-- It does not represent a disease.
--
-- One monitoring concept may belong to many conditions.
-- =============================================================================


INSERT INTO knowledge.monitoring
(
    id,
    concept_id,
    monitoring_code,
    canonical_name,
    description,
    target_type,
    unit,
    body_system_code,
    normal_low,
    normal_high
)
VALUES

-- ---------------------------------------------------------------------------
-- UNIVERSAL / CONSTITUTIONAL
-- ---------------------------------------------------------------------------

(
    'f1700000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-00000000002c',
    'MON-SPO2',
    'Oxygen saturation',
    'Tracks peripheral oxygenation and change in oxygenation over time.',
    'numeric',
    '%',
    'RESPIRATORY',
    94,
    100
),

(
    'f1700000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-00000000002d',
    'MON-RR',
    'Respiratory rate',
    'Tracks respiratory workload and trajectory.',
    'numeric',
    'breaths/min',
    'RESPIRATORY',
    12,
    20
),

(
    'f1700000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-00000000002e',
    'MON-TEMP',
    'Body temperature',
    'Tracks febrile or hypothermic trajectory.',
    'numeric',
    'degC',
    'CONSTITUTIONAL',
    36.5,
    37.5
),

(
    'f1700000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-00000000002f',
    'MON-HR',
    'Heart rate',
    'Tracks cardiovascular and physiological response.',
    'numeric',
    'beats/min',
    'CARDIOVASCULAR',
    60,
    100
),

(
    'f1700000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000030',
    'MON-WOB',
    'Work of breathing',
    'Tracks respiratory effort and clinical deterioration.',
    'coded',
    NULL,
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000006',
    NULL,
    'MON-MENTAL-STATUS',
    'Mental status',
    'Tracks alertness, orientation and change in level of consciousness.',
    'coded',
    NULL,
    'NEUROLOGICAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000007',
    NULL,
    'MON-BP-SYSTOLIC',
    'Systolic blood pressure',
    'Tracks systemic perfusion and haemodynamic trajectory.',
    'numeric',
    'mmHg',
    'CARDIOVASCULAR',
    90,
    129
),

(
    'f1700000-0000-0000-0000-000000000008',
    NULL,
    'MON-BP-DIASTOLIC',
    'Diastolic blood pressure',
    'Tracks systemic vascular and haemodynamic state.',
    'numeric',
    'mmHg',
    'CARDIOVASCULAR',
    60,
    79
),

(
    'f1700000-0000-0000-0000-000000000009',
    NULL,
    'MON-PAIN',
    'Pain severity',
    'Tracks patient-reported pain intensity and response to treatment.',
    'numeric',
    '0-10',
    'CONSTITUTIONAL',
    0,
    0
),

(
    'f1700000-0000-0000-0000-00000000000a',
    NULL,
    'MON-ORAL-INTAKE',
    'Oral intake',
    'Tracks ability to maintain oral hydration and nutrition.',
    'coded',
    NULL,
    'CONSTITUTIONAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000000b',
    NULL,
    'MON-FLUID-BALANCE',
    'Fluid balance',
    'Tracks intake and output where clinically indicated.',
    'numeric',
    'mL',
    'RENAL_URINARY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000000c',
    NULL,
    'MON-URINE-OUTPUT',
    'Urine output',
    'Tracks renal perfusion and fluid status.',
    'numeric',
    'mL/hour',
    'RENAL_URINARY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000000d',
    NULL,
    'MON-WEIGHT',
    'Body weight',
    'Tracks nutritional state and fluid-related weight change.',
    'numeric',
    'kg',
    'CONSTITUTIONAL',
    NULL,
    NULL
),


-- ---------------------------------------------------------------------------
-- RESPIRATORY
-- ---------------------------------------------------------------------------

(
    'f1700000-0000-0000-0000-00000000000e',
    NULL,
    'MON-COUGH',
    'Cough trajectory',
    'Tracks frequency, severity and trajectory of cough.',
    'coded',
    NULL,
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000000f',
    NULL,
    'MON-SPUTUM',
    'Sputum trajectory',
    'Tracks sputum amount and relevant change in sputum characteristics.',
    'coded',
    NULL,
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000010',
    NULL,
    'MON-DYSPNOEA',
    'Dyspnoea trajectory',
    'Tracks subjective breathlessness over time.',
    'coded',
    NULL,
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000011',
    NULL,
    'MON-WHEEZE',
    'Wheeze trajectory',
    'Tracks presence and change in wheeze.',
    'coded',
    NULL,
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000012',
    NULL,
    'MON-PEF',
    'Peak expiratory flow',
    'Tracks expiratory airflow where peak-flow monitoring is clinically appropriate.',
    'numeric',
    'L/min',
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000013',
    NULL,
    'MON-AIRWAY-RESCUE-USE',
    'Reliever medication use',
    'Tracks frequency of rescue/reliever medication use as a marker of symptom control.',
    'numeric',
    'uses',
    'RESPIRATORY',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000014',
    NULL,
    'MON-NIGHT-WAKING',
    'Night-time respiratory symptoms',
    'Tracks night waking attributable to respiratory symptoms.',
    'numeric',
    'episodes',
    'RESPIRATORY',
    NULL,
    NULL
),


-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR / HEART FAILURE
-- ---------------------------------------------------------------------------

(
    'f1700000-0000-0000-0000-000000000015',
    NULL,
    'MON-JVP',
    'Jugular venous pressure',
    'Tracks systemic venous congestion.',
    'coded',
    NULL,
    'CARDIOVASCULAR',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000016',
    NULL,
    'MON-PERIPHERAL-OEDEMA',
    'Peripheral oedema',
    'Tracks peripheral fluid accumulation.',
    'coded',
    NULL,
    'CARDIOVASCULAR',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000017',
    NULL,
    'MON-ORTHOPNOEA',
    'Orthopnoea',
    'Tracks breathlessness related to recumbency.',
    'coded',
    NULL,
    'CARDIOVASCULAR',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000018',
    NULL,
    'MON-PND',
    'Paroxysmal nocturnal dyspnoea',
    'Tracks nocturnal episodes of breathlessness.',
    'coded',
    NULL,
    'CARDIOVASCULAR',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000019',
    NULL,
    'MON-EXERCISE-TOLERANCE',
    'Exercise tolerance',
    'Tracks functional capacity and change in activity tolerance.',
    'coded',
    NULL,
    'CARDIOVASCULAR',
    NULL,
    NULL
),


-- ---------------------------------------------------------------------------
-- GASTROINTESTINAL / GERD
-- ---------------------------------------------------------------------------

(
    'f1700000-0000-0000-0000-00000000001a',
    NULL,
    'MON-HEARTBURN',
    'Heartburn',
    'Tracks frequency and severity of reflux-associated burning discomfort.',
    'coded',
    NULL,
    'GASTROINTESTINAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000001b',
    NULL,
    'MON-REGURGITATION',
    'Regurgitation',
    'Tracks frequency of reflux-associated regurgitation.',
    'coded',
    NULL,
    'GASTROINTESTINAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000001c',
    NULL,
    'MON-DYSPHAGIA',
    'Dysphagia',
    'Tracks swallowing difficulty and its trajectory.',
    'coded',
    NULL,
    'GASTROINTESTINAL',
    NULL,
    NULL
),


-- ---------------------------------------------------------------------------
-- INFECTION / TB
-- ---------------------------------------------------------------------------

(
    'f1700000-0000-0000-0000-00000000001d',
    NULL,
    'MON-NIGHT-SWEATS',
    'Night sweats',
    'Tracks constitutional symptom trajectory relevant to chronic infection.',
    'coded',
    NULL,
    'CONSTITUTIONAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000001e',
    NULL,
    'MON-WEIGHT-LOSS',
    'Weight-loss trajectory',
    'Tracks clinically significant unintentional weight loss.',
    'numeric',
    'kg',
    'CONSTITUTIONAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-00000000001f',
    NULL,
    'MON-HAEMOPTYSIS',
    'Haemoptysis',
    'Tracks presence and severity of coughing blood.',
    'coded',
    NULL,
    'RESPIRATORY',
    NULL,
    NULL
),


-- ---------------------------------------------------------------------------
-- TREATMENT SAFETY
-- ---------------------------------------------------------------------------

(
    'f1700000-0000-0000-0000-000000000020',
    NULL,
    'MON-ADVERSE-EFFECTS',
    'Medication adverse effects',
    'Tracks suspected treatment-related adverse effects.',
    'coded',
    NULL,
    'CONSTITUTIONAL',
    NULL,
    NULL
),

(
    'f1700000-0000-0000-0000-000000000021',
    NULL,
    'MON-ADHERENCE',
    'Treatment adherence',
    'Tracks whether the prescribed treatment is being taken as intended.',
    'coded',
    NULL,
    'CONSTITUTIONAL',
    NULL,
    NULL
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. MONITORING ? CONDITION JUNCTIONS
-- =============================================================================
-- These relationships tell the CPU:
--
-- "For this condition, this is something worth following."
--
-- They do NOT mean that every target must be measured in every patient.
-- =============================================================================


INSERT INTO knowledge.monitoring_condition
(
    monitoring_id,
    condition_id,
    weight,
    rationale
)
VALUES

-- =============================================================================
-- PNEUMONIA
-- =============================================================================

(
    'f1700000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Oxygenation is central to severity assessment and trajectory monitoring.'
),

(
    'f1700000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Respiratory rate tracks respiratory workload and deterioration.'
),

(
    'f1700000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000001',
    0.9,
    'Temperature helps track the febrile trajectory.'
),

(
    'f1700000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000001',
    0.8,
    'Heart rate contributes to physiological trajectory assessment.'
),

(
    'f1700000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Increasing work of breathing may indicate deterioration.'
),

(
    'f1700000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000001',
    0.8,
    'Altered mental status may indicate severe systemic or respiratory compromise.'
),

(
    'f1700000-0000-0000-0000-000000000007',
    'f1000000-0000-0000-0000-000000000001',
    0.7,
    'Blood pressure contributes to severity and haemodynamic assessment.'
),

(
    'f1700000-0000-0000-0000-000000000009',
    'f1000000-0000-0000-0000-000000000001',
    0.5,
    'Pain trajectory may be relevant in pleuritic or chest-wall-associated disease.'
),

(
    'f1700000-0000-0000-0000-00000000000a',
    'f1000000-0000-0000-0000-000000000001',
    0.7,
    'Ability to maintain oral intake influences hydration and treatment planning.'
),

(
    'f1700000-0000-0000-0000-00000000000e',
    'f1000000-0000-0000-0000-000000000001',
    0.6,
    'Cough trajectory helps assess clinical response.'
),

(
    'f1700000-0000-0000-0000-00000000000f',
    'f1000000-0000-0000-0000-000000000001',
    0.7,
    'Sputum trajectory may contribute to respiratory response assessment.'
),

(
    'f1700000-0000-0000-0000-000000000010',
    'f1000000-0000-0000-0000-000000000001',
    0.8,
    'Dyspnoea trajectory is important in pneumonia response assessment.'
),


-- =============================================================================
-- TUBERCULOSIS
-- =============================================================================

(
    'f1700000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000002',
    0.7,
    'Temperature trajectory may reflect ongoing inflammatory/infectious activity.'
),

(
    'f1700000-0000-0000-0000-00000000000e',
    'f1000000-0000-0000-0000-000000000002',
    0.8,
    'Cough trajectory is central to respiratory symptom monitoring.'
),

(
    'f1700000-0000-0000-0000-00000000000f',
    'f1000000-0000-0000-0000-000000000002',
    0.7,
    'Sputum trajectory may be clinically relevant in pulmonary TB.'
),

(
    'f1700000-0000-0000-0000-00000000001d',
    'f1000000-0000-0000-0000-000000000002',
    0.8,
    'Night sweats may track constitutional disease activity.'
),

(
    'f1700000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000002',
    0.9,
    'Weight trajectory is important in chronic infection and nutritional assessment.'
),

(
    'f1700000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000002',
    0.8,
    'Haemoptysis requires active monitoring when present.'
),

(
    'f1700000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000002',
    1.0,
    'Treatment adherence is essential for successful tuberculosis treatment.'
),

(
    'f1700000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000002',
    1.0,
    'Medication adverse effects must be actively assessed during treatment.'
),


-- =============================================================================
-- ASTHMA
-- =============================================================================

(
    'f1700000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000004',
    1.0,
    'Oxygenation is important during acute respiratory deterioration.'
),

(
    'f1700000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000004',
    1.0,
    'Respiratory rate tracks respiratory workload.'
),

(
    'f1700000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000004',
    0.7,
    'Heart rate may reflect physiological stress and treatment response.'
),

(
    'f1700000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000004',
    1.0,
    'Work of breathing is an important marker of acute severity.'
),

(
    'f1700000-0000-0000-0000-000000000010',
    'f1000000-0000-0000-0000-000000000004',
    0.9,
    'Dyspnoea trajectory reflects symptom control.'
),

(
    'f1700000-0000-0000-0000-000000000011',
    'f1000000-0000-0000-0000-000000000004',
    0.9,
    'Wheeze trajectory contributes to assessment of airflow obstruction.'
),

(
    'f1700000-0000-0000-0000-000000000012',
    'f1000000-0000-0000-0000-000000000004',
    1.0,
    'Peak flow can provide objective airflow monitoring when appropriate.'
),

(
    'f1700000-0000-0000-0000-000000000013',
    'f1000000-0000-0000-0000-000000000004',
    0.9,
    'Increasing reliever use can indicate inadequate symptom control.'
),

(
    'f1700000-0000-0000-0000-000000000014',
    'f1000000-0000-0000-0000-000000000004',
    0.8,
    'Night-time symptoms are an important marker of asthma control.'),


-- =============================================================================
-- HEART FAILURE
-- =============================================================================

(
    'f1700000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000005',
    1.0,
    'Oxygenation may deteriorate with pulmonary congestion.'
),

(
    'f1700000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000005',
    0.8,
    'Respiratory rate reflects pulmonary workload.'
),

(
    'f1700000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000005',
    0.8,
    'Heart rate contributes to haemodynamic assessment.'
),

(
    'f1700000-0000-0000-0000-000000000007',
    'f1000000-0000-0000-0000-000000000005',
    1.0,
    'Blood pressure is central to haemodynamic assessment and treatment safety.'
),

(
    'f1700000-0000-0000-0000-00000000000b',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Fluid balance is important when congestion or diuretic therapy is present.'
),

(
    'f1700000-0000-0000-0000-00000000000c',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Urine output contributes to renal perfusion and treatment monitoring.'
),

(
    'f1700000-0000-0000-0000-00000000000d',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Weight trajectory can identify clinically important fluid change.'
),

(
    'f1700000-0000-0000-0000-000000000015',
    'f1000000-0000-0000-0000-000000000005',
    1.0,
    'JVP provides evidence of systemic venous congestion.'
),

(
    'f1700000-0000-0000-0000-000000000016',
    'f1000000-0000-0000-0000-000000000005',
    1.0,
    'Peripheral oedema tracks systemic fluid accumulation.'
),

(
    'f1700000-0000-0000-0000-000000000017',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Orthopnoea reflects pulmonary congestion.'
),

(
    'f1700000-0000-0000-0000-000000000018',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'PND reflects episodic pulmonary congestion.'
),

(
    'f1700000-0000-0000-0000-000000000019',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Functional capacity tracks disease burden and response.'
),


-- =============================================================================
-- GERD
-- =============================================================================

(
    'f1700000-0000-0000-0000-00000000000e',
    'f1000000-0000-0000-0000-000000000006',
    0.7,
    'Cough trajectory is relevant where reflux-associated cough is present.'
),

(
    'f1700000-0000-0000-0000-000000000010',
    'f1000000-0000-0000-0000-000000000006',
    0.5,
    'Respiratory symptoms may accompany reflux-associated disease.'
),

(
    'f1700000-0000-0000-0000-00000000001a',
    'f1000000-0000-0000-0000-000000000006',
    1.0,
    'Heartburn is a principal symptom used to assess treatment response.'
),

(
    'f1700000-0000-0000-0000-00000000001b',
    'f1000000-0000-0000-0000-000000000006',
    1.0,
    'Regurgitation is a principal reflux symptom.'
),

(
    'f1700000-0000-0000-0000-00000000001c',
    'f1000000-0000-0000-0000-000000000006',
    0.9,
    'Dysphagia requires active assessment because it may represent a clinically important complication or alternate process.'
),


-- =============================================================================
-- UNIVERSAL TREATMENT SAFETY
-- =============================================================================

(
    'f1700000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000001',
    0.8,
    'Treatment adverse effects should be reviewed.'
),

(
    'f1700000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000001',
    0.8,
    'Treatment adherence influences treatment response.'
),

(
    'f1700000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000004',
    0.8,
    'Medication adverse effects should be reviewed.'
),

(
    'f1700000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000004',
    0.9,
    'Controller-treatment adherence is relevant to asthma control.'
),

(
    'f1700000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000005',
    1.0,
    'Heart-failure therapies require active safety monitoring.'
),

(
    'f1700000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Treatment adherence affects heart-failure control.'
),

(
    'f1700000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000006',
    0.7,
    'Treatment adverse effects should be reviewed.'
),

(
    'f1700000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000006',
    0.8,
    'Adherence influences reflux symptom control.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. EDUCATION DEFINITIONS
-- =============================================================================
--
-- Education is reusable clinical content.
--
-- The CPU should select education according to:
--
--   condition
--   patient context
--   treatment
--   active risks
--   literacy
--   language
--   care setting
--   discharge state
--   teach-back status
--
-- These rows are deliberately not hard-coded into the UI.
-- =============================================================================


INSERT INTO knowledge.education
(
    id,
    concept_id,
    education_code,
    title,
    audience,
    content_type,
    language_code,
    literacy_level,
    body
)
VALUES


-- =============================================================================
-- PNEUMONIA
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-000000000031',
    'EDU-CAP-BASICS',
    'Understanding pneumonia',
    'patient',
    'explanation',
    'en',
    'plain',
    'Explain that pneumonia is an infection or inflammatory process affecting the lungs. Explain the main symptoms, expected recovery trajectory, why treatment may be required and why reassessment is important if the patient does not improve.'
),

(
    'f1800000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000032',
    'EDU-CAP-DANGER-SIGNS',
    'Pneumonia danger signs',
    'patient',
    'warning',
    'en',
    'plain',
    'Explain that urgent clinical review is needed for worsening difficulty breathing, new or worsening cyanosis, severe weakness, confusion, inability to maintain fluids, persistent deterioration or any other deterioration identified by the treating clinician.'
),

(
    'f1800000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-000000000033',
    'EDU-CAP-MEDICATION',
    'Taking pneumonia treatment safely',
    'patient',
    'instruction',
    'en',
    'plain',
    'Take prescribed medicines exactly as directed. Do not independently change doses or stop treatment early. Report suspected adverse effects and seek review if symptoms worsen or fail to improve as expected.'
),

(
    'f1800000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000034',
    'EDU-CAP-HYDRATION',
    'Hydration and recovery',
    'patient',
    'instruction',
    'en',
    'plain',
    'Maintain appropriate fluid intake unless the clinician has given a fluid restriction. Follow nutritional advice and monitor the ability to eat and drink during recovery.'
),

(
    'f1800000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000035',
    'EDU-CAP-TEACHBACK',
    'Pneumonia teach-back',
    'patient',
    'teach_back',
    'en',
    'plain',
    'Ask the patient or caregiver to explain in their own words what the illness is, what each prescribed treatment is for, how it should be taken and which warning signs should trigger urgent reassessment.'
),

(
    'f1800000-0000-0000-0000-000000000006',
    NULL,
    'EDU-CAP-CLINICIAN',
    'Pneumonia clinical reasoning summary',
    'clinician',
    'explanation',
    'en',
    'professional',
    'Display the active evidence, severity indicators, competing phenotypes, uncertainty, investigations selected and their rationale, management decisions, monitoring targets and response over time.'
),


-- =============================================================================
-- TUBERCULOSIS
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000007',
    NULL,
    'EDU-TB-BASICS',
    'Understanding tuberculosis',
    'patient',
    'explanation',
    'en',
    'plain',
    'Explain what tuberculosis is, how it can affect the lungs and other organs, why treatment requires a structured regimen and why completing the prescribed treatment is important.'
),

(
    'f1800000-0000-0000-0000-000000000008',
    NULL,
    'EDU-TB-ADHERENCE',
    'Tuberculosis treatment adherence',
    'patient',
    'instruction',
    'en',
    'plain',
    'Take tuberculosis treatment exactly as prescribed and attend scheduled clinical reviews. Do not stop treatment independently even when symptoms improve.'
),

(
    'f1800000-0000-0000-0000-000000000009',
    NULL,
    'EDU-TB-ADVERSE-EFFECTS',
    'Tuberculosis treatment safety',
    'patient',
    'warning',
    'en',
    'plain',
    'Explain important treatment-related symptoms that should be reported promptly to the clinical team. The exact counselling should be individualized to the medicines prescribed.'
),

(
    'f1800000-0000-0000-0000-00000000000a',
    NULL,
    'EDU-TB-INFECTION-CONTROL',
    'Tuberculosis infection-control education',
    'patient',
    'instruction',
    'en',
    'plain',
    'Explain the infection-control measures recommended by the treating service, including appropriate respiratory hygiene and adherence to public-health instructions where applicable.'
),

(
    'f1800000-0000-0000-0000-00000000000b',
    NULL,
    'EDU-TB-NUTRITION',
    'Nutrition during tuberculosis treatment',
    'patient',
    'instruction',
    'en',
    'plain',
    'Discuss adequate nutrition and weight monitoring during treatment, with additional nutritional assessment where weight loss or nutritional vulnerability is present.'
),

(
    'f1800000-0000-0000-0000-00000000000c',
    NULL,
    'EDU-TB-TEACHBACK',
    'Tuberculosis teach-back',
    'patient',
    'teach_back',
    'en',
    'plain',
    'Ask the patient or caregiver to explain what tuberculosis is, how treatment will be taken, why adherence matters, what adverse effects should be reported and when follow-up is required.'
),


-- =============================================================================
-- ASTHMA
-- =============================================================================

(
    'f1800000-0000-0000-0000-00000000000d',
    NULL,
    'EDU-ASTHMA-BASICS',
    'Understanding asthma',
    'patient',
    'explanation',
    'en',
    'plain',
    'Explain asthma as a condition characterized by variable respiratory symptoms and variable airflow limitation. Explain common symptoms and the importance of an individualized treatment plan.'
),

(
    'f1800000-0000-0000-0000-00000000000e',
    NULL,
    'EDU-ASTHMA-TRIGGERS',
    'Asthma triggers and exposure reduction',
    'patient',
    'instruction',
    'en',
    'plain',
    'Help the patient identify relevant personal triggers and exposures. Avoid unnecessary blanket trigger lists and focus counselling on exposures demonstrated or strongly suspected to worsen symptoms.'
),

(
    'f1800000-0000-0000-0000-00000000000f',
    NULL,
    'EDU-ASTHMA-INHALER',
    'Inhaler technique',
    'patient',
    'instruction',
    'en',
    'plain',
    'Demonstrate the prescribed inhaler technique, ask the patient to demonstrate it back and correct errors. Technique should be reassessed periodically.'
),

(
    'f1800000-0000-0000-0000-000000000010',
    NULL,
    'EDU-ASTHMA-ACTION-PLAN',
    'Asthma action plan',
    'patient',
    'instruction',
    'en',
    'plain',
    'Provide an individualized written or digital asthma action plan describing the patient’s usual treatment, how to recognize worsening symptoms and what action to take according to the clinician’s plan.'
),

(
    'f1800000-0000-0000-0000-000000000011',
    NULL,
    'EDU-ASTHMA-DANGER-SIGNS',
    'Asthma deterioration warning signs',
    'patient',
    'warning',
    'en',
    'plain',
    'Explain the warning signs identified by the treating clinician that require urgent assessment, especially rapidly worsening breathlessness, inability to speak or function normally, severe respiratory distress, altered consciousness or poor response to prescribed reliever treatment.'
),

(
    'f1800000-0000-0000-0000-000000000012',
    NULL,
    'EDU-ASTHMA-TEACHBACK',
    'Asthma teach-back',
    'patient',
    'teach_back',
    'en',
    'plain',
    'Ask the patient to demonstrate inhaler technique and explain their regular treatment, reliever plan, warning signs and action plan in their own words.'
),


-- =============================================================================
-- HEART FAILURE
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000013',
    NULL,
    'EDU-HF-BASICS',
    'Understanding heart failure',
    'patient',
    'explanation',
    'en',
    'plain',
    'Explain heart failure as a clinical syndrome in which the heart cannot adequately meet the body’s needs without elevated filling pressures or related abnormalities. Explain that symptoms and fluid congestion can change over time.'
),

(
    'f1800000-0000-0000-0000-000000000014',
    NULL,
    'EDU-HF-MEDICATION',
    'Heart failure medicines',
    'patient',
    'instruction',
    'en',
    'plain',
    'Explain the purpose of each prescribed medicine, how it should be taken and which adverse effects or warning symptoms should be reported. Do not change treatment independently.'
),

(
    'f1800000-0000-0000-0000-000000000015',
    NULL,
    'EDU-HF-FLUID',
    'Heart failure fluid and weight monitoring',
    'patient',
    'instruction',
    'en',
    'plain',
    'Explain the individualized fluid and weight-monitoring plan. Follow the clinician’s advice regarding fluid and dietary restrictions rather than applying a universal restriction.'
),

(
    'f1800000-0000-0000-0000-000000000016',
    NULL,
    'EDU-HF-DANGER-SIGNS',
    'Heart failure deterioration warning signs',
    'patient',
    'warning',
    'en',
    'plain',
    'Explain the individualized warning signs that require urgent review, including worsening breathlessness, increasing difficulty lying flat, rapidly increasing swelling, marked weakness, confusion or other deterioration identified by the treating clinician.'
),

(
    'f1800000-0000-0000-0000-000000000017',
    NULL,
    'EDU-HF-ADHERENCE',
    'Heart failure treatment adherence',
    'patient',
    'instruction',
    'en',
    'plain',
    'Take prescribed treatment consistently and attend scheduled monitoring. Do not stop or alter heart-failure medicines without clinical advice.'
),

(
    'f1800000-0000-0000-0000-000000000018',
    NULL,
    'EDU-HF-TEACHBACK',
    'Heart failure teach-back',
    'patient',
    'teach_back',
    'en',
    'plain',
    'Ask the patient or caregiver to explain the condition, prescribed medicines, monitoring plan, individualized warning signs and when to seek review.'
),


-- =============================================================================
-- GERD
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000019',
    NULL,
    'EDU-GERD-BASICS',
    'Understanding reflux disease',
    'patient',
    'explanation',
    'en',
    'plain',
    'Explain gastroesophageal reflux disease, common symptoms such as heartburn and regurgitation, and the purpose of the prescribed treatment.'
),

(
    'f1800000-0000-0000-0000-00000000001a',
    NULL,
    'EDU-GERD-MEDICATION',
    'GERD treatment',
    'patient',
    'instruction',
    'en',
    'plain',
    'Take reflux treatment according to the prescribed regimen and discuss persistent or recurrent symptoms with the clinical team rather than repeatedly changing treatment independently.'
),

(
    'f1800000-0000-0000-0000-00000000001b',
    NULL,
    'EDU-GERD-LIFESTYLE',
    'Reflux symptom management',
    'patient',
    'instruction',
    'en',
    'plain',
    'Identify individualized factors that worsen symptoms and discuss practical measures with the clinician. Avoid unnecessary restrictions that are not relevant to the individual patient.'
),

(
    'f1800000-0000-0000-0000-00000000001c',
    NULL,
    'EDU-GERD-ALARM',
    'Reflux alarm symptoms',
    'patient',
    'warning',
    'en',
    'plain',
    'Seek clinical review for clinically significant swallowing difficulty, gastrointestinal bleeding symptoms, persistent vomiting, unexplained weight loss or other alarm features identified by the treating clinician.'
),

(
    'f1800000-0000-0000-0000-00000000001d',
    NULL,
    'EDU-GERD-TEACHBACK',
    'GERD teach-back',
    'patient',
    'teach_back',
    'en',
    'plain',
    'Ask the patient to explain what reflux disease means, how prescribed treatment should be taken, which individualized measures may reduce symptoms and which warning symptoms require review.'
),


-- =============================================================================
-- UNIVERSAL CLINICIAN EDUCATION
-- =============================================================================

(
    'f1800000-0000-0000-0000-00000000001e',
    NULL,
    'EDU-CLINICAL-REASONING',
    'Clinical reasoning summary',
    'clinician',
    'explanation',
    'en',
    'professional',
    'Display the active clinical evidence, supporting and opposing findings, phenotype pattern, mechanism, candidate conditions, uncertainty, differential diagnoses, investigations and rationale, treatment decisions, monitoring plan and response over time.'
),

(
    'f1800000-0000-0000-0000-00000000001f',
    NULL,
    'EDU-MEDICATION-COUNSELLING',
    'Medication counselling',
    'clinician',
    'instruction',
    'en',
    'professional',
    'Display the purpose of each prescribed medication, administration instructions, relevant contraindications, monitoring requirements, important adverse effects, adherence considerations and patient-specific counselling requirements.'
),

(
    'f1800000-0000-0000-0000-000000000020',
    NULL,
    'EDU-DISCHARGE-READINESS',
    'Discharge readiness education',
    'clinician',
    'checklist',
    'en',
    'professional',
    'Confirm that the patient or caregiver understands the working diagnosis, treatment plan, medication instructions, monitoring plan, follow-up plan, warning signs and route for urgent reassessment.'
),

(
    'f1800000-0000-0000-0000-000000000021',
    NULL,
    'EDU-TEACHBACK-UNIVERSAL',
    'Universal teach-back',
    'clinician',
    'teach_back',
    'en',
    'professional',
    'Use teach-back to verify understanding. Ask the patient or caregiver to explain the plan in their own words rather than asking only whether they understand.'
),

(
    'f1800000-0000-0000-0000-000000000022',
    NULL,
    'EDU-ADHERENCE-ASSESSMENT',
    'Treatment adherence assessment',
    'clinician',
    'assessment',
    'en',
    'professional',
    'Assess actual medication use, barriers to adherence, access problems, adverse effects, misunderstanding of instructions and other reasons for treatment non-adherence.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. EDUCATION ? CONDITION JUNCTIONS
-- =============================================================================


INSERT INTO knowledge.education_condition
(
    education_id,
    condition_id,
    weight
)
VALUES

-- =============================================================================
-- PNEUMONIA
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000001',
    0.8
),

(
    'f1800000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),


-- =============================================================================
-- TUBERCULOSIS
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000007',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000008',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000009',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000000a',
    'f1000000-0000-0000-0000-000000000002',
    0.9
),

(
    'f1800000-0000-0000-0000-00000000000b',
    'f1000000-0000-0000-0000-000000000002',
    0.8
),

(
    'f1800000-0000-0000-0000-00000000000c',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),


-- =============================================================================
-- ASTHMA
-- =============================================================================

(
    'f1800000-0000-0000-0000-00000000000d',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000000e',
    'f1000000-0000-0000-0000-000000000004',
    0.8
),

(
    'f1800000-0000-0000-0000-00000000000f',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000010',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000011',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000012',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),


-- =============================================================================
-- HEART FAILURE
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000013',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000014',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000015',
    'f1000000-0000-0000-0000-000000000005',
    0.9
),

(
    'f1800000-0000-0000-0000-000000000016',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000017',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000018',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),


-- =============================================================================
-- GERD
-- =============================================================================

(
    'f1800000-0000-0000-0000-000000000019',
    'f1000000-0000-0000-0000-000000000006',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001a',
    'f1000000-0000-0000-0000-000000000006',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001b',
    'f1000000-0000-0000-0000-000000000006',
    0.8
),

(
    'f1800000-0000-0000-0000-00000000001c',
    'f1000000-0000-0000-0000-000000000006',
    1.0
),


-- =============================================================================
-- UNIVERSAL CLINICIAN CONTENT
-- =============================================================================

(
    'f1800000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000006',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000006',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000006',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

(
    'f1800000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000006',
    1.0
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. UNIVERSAL CONCEPT ? MONITORING SYSTEM JUNCTIONS
-- =============================================================================
-- This makes monitoring objects discoverable by body system without creating
-- disease-specific copies.
-- =============================================================================


INSERT INTO knowledge.concept_system
(
    concept_id,
    body_system_code,
    relevance,
    weight,
    description
)
VALUES

-- Oxygen saturation
(
    'f0a00000-0000-0000-0000-00000000002c',
    'RESPIRATORY',
    'primary',
    1.0,
    'Oxygen saturation is a universal respiratory monitoring concept.'
),

-- Respiratory rate
(
    'f0a00000-0000-0000-0000-00000000002d',
    'RESPIRATORY',
    'primary',
    1.0,
    'Respiratory rate is a universal respiratory monitoring concept.'
),

-- Temperature
(
    'f0a00000-0000-0000-0000-00000000002e',
    'CONSTITUTIONAL',
    'primary',
    1.0,
    'Temperature is a universal physiological monitoring concept.'
),

-- Heart rate
(
    'f0a00000-0000-0000-0000-00000000002f',
    'CARDIOVASCULAR',
    'primary',
    1.0,
    'Heart rate is a universal cardiovascular monitoring concept.'
),

-- Work of breathing
(
    'f0a00000-0000-0000-0000-000000000030',
    'RESPIRATORY',
    'primary',
    1.0,
    'Work of breathing is a universal respiratory severity concept.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. UNIVERSAL EDUCATION ? SPECIALTY JUNCTIONS
-- =============================================================================
-- Education is not owned by one disease.
-- This makes clinician-facing education discoverable by specialty.
-- =============================================================================


INSERT INTO knowledge.concept_specialty
(
    concept_id,
    specialty_code,
    relevance,
    weight,
    description
)
VALUES

(
    'f0a00000-0000-0000-0000-00000000002c',
    'pulmonology',
    'primary',
    1.0,
    'Oxygenation monitoring in respiratory medicine.'
),

(
    'f0a00000-0000-0000-0000-00000000002d',
    'pulmonology',
    'primary',
    1.0,
    'Respiratory rate monitoring.'
),

(
    'f0a00000-0000-0000-0000-00000000002f',
    'cardiology',
    'primary',
    1.0,
    'Heart-rate monitoring in cardiovascular disease.'
),

(
    'f0a00000-0000-0000-0000-000000000030',
    'pulmonology',
    'primary',
    1.0,
    'Work-of-breathing monitoring.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. GENERALIZED KNOWLEDGE-GRAPH RELATIONSHIPS
-- =============================================================================
--
-- These edges allow the universal relationship engine to navigate:
--
-- condition ? monitoring
-- condition ? education
-- monitoring ? body system
-- education ? clinical plan
--
-- They complement the typed junction tables above.
-- =============================================================================


INSERT INTO knowledge.relationship
(
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
)
VALUES

-- Pneumonia
(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000001',
    1.0,
    'positive',
    0.98,
    'Oxygenation is an important marker of respiratory severity and trajectory.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000005',
    1.0,
    'positive',
    0.98,
    'Increasing work of breathing can indicate respiratory deterioration.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'educated_by',
    'education',
    'f1800000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.99,
    'Patients require clear deterioration and urgent-review instructions.'
),


-- Tuberculosis
(
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-00000000001e',
    0.9,
    'positive',
    0.95,
    'Weight trajectory is clinically relevant in chronic tuberculosis.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000021',
    1.0,
    'positive',
    0.99,
    'Treatment adherence is essential in tuberculosis management.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    'educated_by',
    'education',
    'f1800000-0000-0000-0000-000000000008',
    1.0,
    'positive',
    0.99,
    'Patients require treatment-adherence counselling.'
),


-- Asthma
(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000012',
    1.0,
    'positive',
    0.95,
    'Peak flow can provide objective airflow monitoring where appropriate.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000013',
    0.9,
    'positive',
    0.95,
    'Reliever-use frequency can indicate inadequate control.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'educated_by',
    'education',
    'f1800000-0000-0000-0000-000000000010',
    1.0,
    'positive',
    0.99,
    'Patients benefit from an individualized asthma action plan.'
),


-- Heart failure
(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000015',
    1.0,
    'positive',
    0.98,
    'JVP provides evidence of systemic venous congestion.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-000000000016',
    1.0,
    'positive',
    0.98,
    'Peripheral oedema tracks fluid accumulation.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-00000000000d',
    0.9,
    'positive',
    0.95,
    'Weight change can help identify fluid trajectory.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'educated_by',
    'education',
    'f1800000-0000-0000-0000-000000000016',
    1.0,
    'positive',
    0.99,
    'Patients require education on deterioration warning signs.'
),


-- GERD
(
    'condition',
    'f1000000-0000-0000-0000-000000000006',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-00000000001a',
    1.0,
    'positive',
    0.98,
    'Heartburn trajectory is directly relevant to reflux symptom control.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000006',
    'monitored_by',
    'monitoring',
    'f1700000-0000-0000-0000-00000000001b',
    1.0,
    'positive',
    0.98,
    'Regurgitation trajectory is directly relevant to reflux disease.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000006',
    'educated_by',
    'education',
    'f1800000-0000-0000-0000-00000000001c',
    1.0,
    'positive',
    0.99,
    'Alarm-feature education is important when reflux symptoms are assessed.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. DATA-INTEGRITY CHECKS
-- =============================================================================
-- These checks intentionally do not mutate clinical data.
-- They make the seed fail loudly if the universal graph becomes disconnected.
-- =============================================================================


DO $$
BEGIN

    -- -------------------------------------------------------------------------
    -- Monitoring objects must exist.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring
        WHERE monitoring_code = 'MON-SPO2'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: MON-SPO2 missing';
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring
        WHERE monitoring_code = 'MON-WOB'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: MON-WOB missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- Pneumonia must have monitoring.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring_condition mc
        JOIN knowledge.monitoring m
          ON m.id = mc.monitoring_id
        WHERE mc.condition_id =
              'f1000000-0000-0000-0000-000000000001'
          AND m.monitoring_code = 'MON-SPO2'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: pneumonia has no SpO2 monitoring';
    END IF;


    -- -------------------------------------------------------------------------
    -- TB must have adherence monitoring.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring_condition mc
        JOIN knowledge.monitoring m
          ON m.id = mc.monitoring_id
        WHERE mc.condition_id =
              'f1000000-0000-0000-0000-000000000002'
          AND m.monitoring_code = 'MON-ADHERENCE'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: TB has no adherence monitoring';
    END IF;


    -- -------------------------------------------------------------------------
    -- Asthma must have peak-flow monitoring.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring_condition mc
        JOIN knowledge.monitoring m
          ON m.id = mc.monitoring_id
        WHERE mc.condition_id =
              'f1000000-0000-0000-0000-000000000004'
          AND m.monitoring_code = 'MON-PEF'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: asthma has no PEF monitoring';
    END IF;


    -- -------------------------------------------------------------------------
    -- Heart failure must have congestion monitoring.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring_condition mc
        JOIN knowledge.monitoring m
          ON m.id = mc.monitoring_id
        WHERE mc.condition_id =
              'f1000000-0000-0000-0000-000000000005'
          AND m.monitoring_code = 'MON-PERIPHERAL-OEDEMA'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: heart failure has no oedema monitoring';
    END IF;


    -- -------------------------------------------------------------------------
    -- GERD must have symptom monitoring.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.monitoring_condition mc
        JOIN knowledge.monitoring m
          ON m.id = mc.monitoring_id
        WHERE mc.condition_id =
              'f1000000-0000-0000-0000-000000000006'
          AND m.monitoring_code = 'MON-HEARTBURN'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: GERD has no heartburn monitoring';
    END IF;


    -- -------------------------------------------------------------------------
    -- Every MVP condition must have at least one education object.
    -- -------------------------------------------------------------------------

    IF (
        SELECT COUNT(DISTINCT ec.condition_id)
        FROM knowledge.education_condition ec
        WHERE ec.condition_id IN
        (
            'f1000000-0000-0000-0000-000000000001',
            'f1000000-0000-0000-0000-000000000002',
            'f1000000-0000-0000-0000-000000000004',
            'f1000000-0000-0000-0000-000000000005',
            'f1000000-0000-0000-0000-000000000006'
        )
    ) <> 5 THEN

        RAISE EXCEPTION
            'AMEXAN ZP7 integrity failure: one or more MVP conditions lack education content';

    END IF;

END $$;


-- =============================================================================
-- END OF ZP7
-- =============================================================================
--
-- RESULTING UNIVERSAL MEDICINE GRAPH
--
--   SYMPTOM
--      ?
--   FACT
--      ?
--   PHENOTYPE
--      ?
--   MECHANISM
--      ?
--   CONDITION
--      +--------------? INVESTIGATION
--      ¦
--      +--------------? MEDICATION
--      ¦
--      +--------------? PROTOCOL
--      ¦
--      +--------------? MONITORING
--      ¦                    ?
--      ¦                 trajectory
--      ¦                    ?
--      ¦                 response
--      ¦                    ?
--      ¦              deterioration
--      ¦
--      +--------------? EDUCATION
--                           ?
--                       teach-back
--                           ?
--                       adherence
--                           ?
--                       discharge
--
-- The important architectural property is that monitoring and education
-- remain reusable knowledge objects rather than copies embedded inside
-- individual diseases.
-- =============================================================================