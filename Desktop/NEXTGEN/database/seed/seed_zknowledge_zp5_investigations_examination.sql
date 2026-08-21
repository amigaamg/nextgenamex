-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP5
-- COMPREHENSIVE INVESTIGATIONS + STRUCTURED CLINICAL EXAMINATION
-- =============================================================================
--
-- PURPOSE
-- -------
-- ZP5 establishes reusable investigation definitions and structured examination
-- modules for the AMEXAN Clinical Intelligence / Clinical Reasoning CPU.
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. Investigations are reusable clinical actions, NOT disease-owned objects.
-- 2. Examination modules are reusable clinical assessment domains.
-- 3. Examination findings become FACTS that the reasoning CPU can consume.
-- 4. Measurements retain numeric meaning rather than being reduced to labels.
-- 5. A test is never equivalent to a diagnosis.
-- 6. Investigation relevance is probabilistic/contextual, not absolute.
-- 7. Negative findings are clinically meaningful and must remain representable.
-- 8. The same investigation may support many conditions.
-- 9. The same examination finding may support many conditions.
-- 10. Emergency investigations are represented independently of specialty.
--
-- CLINICAL GRAPH
--
-- symptom
--    ↓
-- fact
--    ↓
-- phenotype
--    ↓
-- mechanism
--    ↓
-- condition
--    ↓
-- investigation / examination
--    ↓
-- result / finding
--    ↓
-- fact
--    ↓
-- updated phenotype / differential / severity
--    ↓
-- management
--
-- IMPORTANT
-- ---------
-- Existing concept IDs from the AMEXAN base knowledge seed are reused wherever
-- they are already established:
--
-- 001 cough
-- 002 fever
-- 003 dyspnoea
-- 005 sputum / cough productivity family
-- 012 CXR
-- 013 sputum AFB
-- 014 SpO2
-- 015/016 severe respiratory complications
-- 017 chest pain
-- 018 abdominal pain
-- 019 asthma
-- 01a heart failure
-- 01b GERD
-- 01f FBC
-- 020 CRP
-- 021 urea/electrolytes
-- 03b wheeze
-- 03c crackles
-- 03d pleuritic pain
--
-- =============================================================================


-- =============================================================================
-- SECTION 1 — INVESTIGATION DEFINITIONS
-- =============================================================================

INSERT INTO knowledge.investigation
(
    id,
    concept_id,
    investigation_code,
    canonical_name,
    description,
    investigation_type,
    body_system_code,
    specimen,
    preparation
)
VALUES

-- ---------------------------------------------------------------------------
-- HAEMATOLOGY
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-00000000001f',
    'INV-FBC',
    'Full blood count',
    'Assessment of haemoglobin, white cell count, differential and platelets.',
    'laboratory',
    'HAEMATOLOGICAL',
    'blood',
    NULL
),

(
    'f1300000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000020',
    'INV-CRP',
    'C-reactive protein',
    'Inflammatory biomarker used as contextual evidence of inflammation.',
    'laboratory',
    'IMMUNE',
    'blood',
    NULL
),

-- ---------------------------------------------------------------------------
-- RESPIRATORY / IMAGING
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-000000000012',
    'INV-CXR',
    'Chest X-ray',
    'Chest radiography for assessment of pulmonary, pleural and cardiac
     abnormalities.',
    'imaging',
    'RESPIRATORY',
    'radiographic image',
    NULL
),

(
    'f1300000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000014',
    'INV-SPO2',
    'Pulse oximetry',
    'Non-invasive measurement of peripheral oxygen saturation.',
    'physiological',
    'RESPIRATORY',
    'bedside',
    NULL
),

(
    'f1300000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000021',
    'INV-UREA-CREAT',
    'Urea, creatinine and electrolytes',
    'Assessment of renal function and major serum electrolytes.',
    'laboratory',
    'RENAL_URINARY',
    'blood',
    NULL
),

(
    'f1300000-0000-0000-0000-000000000006',
    'f0a00000-0000-0000-0000-000000000013',
    'INV-SPUTUM-AFB',
    'Sputum acid-fast bacilli smear',
    'Microscopic examination for acid-fast bacilli. Used as an adjunct in
     tuberculosis assessment and not as a standalone exclusion test.',
    'microbiology',
    'RESPIRATORY',
    'sputum',
    'Follow local TB diagnostic protocol'
),

-- =============================================================================
-- SECTION 2 — INVESTIGATION → CONDITION RELATIONSHIPS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- COMMUNITY-ACQUIRED PNEUMONIA
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000007',
    'f0a00000-0000-0000-0000-00000000001f',
    'INV-FBC-REPEAT',
    'Full blood count — repeat',
    'Repeat haematological assessment when clinically indicated.',
    'laboratory',
    'HAEMATOLOGICAL',
    'blood',
    NULL
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- INVESTIGATION → CONDITION
-- =============================================================================
--
-- IMPORTANT:
-- These weights represent clinical usefulness/relevance.
-- They DO NOT mean:
--     investigation positive = diagnosis
--     investigation negative = diagnosis excluded
--
-- The reasoning engine must interpret results in context.
-- =============================================================================

INSERT INTO knowledge.investigation_condition
(
    investigation_id,
    condition_id,
    weight,
    rationale
)
VALUES

-- ---------------------------------------------------------------------------
-- PNEUMONIA
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Chest radiography can identify pulmonary infiltrates, consolidation,
     pleural complications and alternative diagnoses when imaging is indicated.'
),

(
    'f1300000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Oxygen saturation assesses hypoxaemia and severity.'
),

(
    'f1300000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    0.7,
    'FBC may provide supportive evidence of infection and identify anaemia or
     other clinically relevant abnormalities.'
),

(
    'f1300000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    0.6,
    'CRP provides contextual evidence of systemic inflammation.'
),

(
    'f1300000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    0.6,
    'Renal function and electrolytes support severity assessment and treatment
     planning in clinically significant infection.'
),

-- ---------------------------------------------------------------------------
-- TUBERCULOSIS
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000002',
    0.8,
    'Sputum smear can provide microbiological evidence of pulmonary TB but does
     not independently exclude TB when negative.'
),

(
    'f1300000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000002',
    0.7,
    'Chest imaging may support pulmonary TB assessment and identify alternative
     or associated pathology.'
),

-- ---------------------------------------------------------------------------
-- HEART FAILURE
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Chest radiography may demonstrate pulmonary congestion, oedema, pleural
     effusion or alternative pulmonary pathology.'
),

(
    'f1300000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000005',
    0.8,
    'Oxygen saturation assesses gas-exchange impairment in decompensated heart
     failure and pulmonary oedema.'
),

(
    'f1300000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Renal function and electrolytes are important for assessment and safe
     heart-failure treatment.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 3 — EXAMINATION MODULES
-- =============================================================================

INSERT INTO knowledge.examination_module
(
    id,
    concept_id,
    module_code,
    canonical_name,
    description,
    body_system_code,
    sort_order
)
VALUES

(
    'f1400000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-000000000022',
    'EXAM-GENERAL',
    'General examination',
    'General clinical assessment including appearance, consciousness,
     distress, perfusion, temperature and visible systemic signs.',
    'CONSTITUTIONAL',
    10
),

(
    'f1400000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000023',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assessment of respiratory rate, oxygenation, work of breathing,
     chest expansion, percussion and auscultation.',
    'RESPIRATORY',
    20
),

(
    'f1400000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-000000000024',
    'EXAM-CARDIOVASCULAR',
    'Cardiovascular examination',
    'Assessment of pulse, blood pressure, JVP, precordium, heart sounds,
     peripheral perfusion and oedema.',
    'CARDIOVASCULAR',
    30
),

(
    'f1400000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000025',
    'EXAM-ABDOMINAL',
    'Abdominal examination',
    'Inspection, auscultation, percussion and palpation of the abdomen,
     including peritoneal and organ-specific findings.',
    'GASTROINTESTINAL',
    40
),

(
    'f1400000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000026',
    'EXAM-NEUROLOGICAL',
    'Neurological examination',
    'Assessment of consciousness, orientation, cranial nerves, motor function,
     sensation, coordination and focal neurological deficit.',
    'NEUROLOGICAL',
    50
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 4 — GENERAL EXAMINATION FINDINGS
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

-- ---------------------------------------------------------------------------
-- GENERAL APPEARANCE / SEVERITY
-- ---------------------------------------------------------------------------

(
    'f1500000-0000-0000-0000-000000000001',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-ILL-APPEARING',
    'Ill appearance',
    'Patient appears systemically unwell.',
    'ILL_APPEARANCE',
    'sign',
    10
),

(
    'f1500000-0000-0000-0000-000000000002',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-RESP-DISTRESS',
    'Respiratory distress',
    'Visible increased work of breathing.',
    'RESPIRATORY_DISTRESS',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-000000000003',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-CYANOSIS',
    'Central cyanosis',
    'Bluish discoloration of central mucous membranes.',
    'CYANOSIS',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-000000000004',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-CHEST-INDRAWING',
    'Chest indrawing',
    'Visible inward movement of the chest wall during inspiration.',
    'CHEST_INDRAWING',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-000000000005',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-GRUNTING',
    'Grunting',
    'Expiratory grunting indicating increased respiratory effort.',
    'GRUNTING',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-000000000006',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-NASAL-FLARING',
    'Nasal flaring',
    'Visible widening of the nostrils during inspiration.',
    'NASAL_FLARING',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-000000000007',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-TEMP',
    'Temperature',
    'Measured body temperature in degrees Celsius.',
    'TEMPERATURE',
    'measurement',
    70
),

(
    'f1500000-0000-0000-0000-000000000008',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-BP',
    'Blood pressure',
    'Systolic and diastolic arterial blood pressure.',
    'BLOOD_PRESSURE',
    'measurement',
    80
),

(
    'f1500000-0000-0000-0000-000000000009',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-PERFUSION',
    'Peripheral perfusion',
    'Assessment of peripheral circulation including capillary refill.',
    'PERIPHERAL_PERFUSION',
    'sign',
    90
),

(
    'f1500000-0000-0000-0000-00000000000a',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-ALTERED-CONSCIOUSNESS',
    'Altered consciousness',
    'Reduced or abnormal level of consciousness.',
    'ALTERED_CONSCIOUSNESS',
    'sign',
    100
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 5 — RESPIRATORY EXAMINATION FINDINGS
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-00000000000b',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-RR',
    'Respiratory rate',
    'Respiratory rate in breaths per minute.',
    'RESP_RATE',
    'measurement',
    10
),

(
    'f1500000-0000-0000-0000-00000000000c',
    'f1400000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000014',
    'FIND-SPO2',
    'Oxygen saturation',
    'Peripheral oxygen saturation measured by pulse oximetry.',
    'SPO2',
    'measurement',
    20
),

(
    'f1500000-0000-0000-0000-00000000000d',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-ACCESSORY-MUSCLES',
    'Accessory muscle use',
    'Use of accessory respiratory muscles.',
    'ACCESSORY_MUSCLE_USE',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-00000000000e',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-CHEST-EXPANSION',
    'Reduced chest expansion',
    'Reduced or asymmetrical chest expansion.',
    'REDUCED_CHEST_EXPANSION',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-00000000000f',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-TRACHEAL-DEVIATION',
    'Tracheal deviation',
    'Deviation of the trachea from the midline.',
    'TRACHEAL_DEVIATION',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-000000000010',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-PERCUSSION-DULL',
    'Percussion dullness',
    'Dull percussion note over a specified region.',
    'PERCUSSION_DULLNESS',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-000000000011',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-PERCUSSION-HYPER',
    'Hyperresonant percussion',
    'Hyperresonant percussion note over a specified region.',
    'PERCUSSION_HYPERRESONANCE',
    'sign',
    70
),

(
    'f1500000-0000-0000-0000-000000000012',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-BRONCHIAL-BREATH',
    'Bronchial breath sounds',
    'Bronchial breathing over an area where vesicular breathing is expected.',
    'BRONCHIAL_BREATH_SOUNDS',
    'sign',
    80
),

(
    'f1500000-0000-0000-0000-000000000013',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-CRACKLES',
    'Crackles',
    'Discontinuous added breath sounds on auscultation.',
    'CRACKLES',
    'sign',
    90
),

(
    'f1500000-0000-0000-0000-000000000014',
    'f1400000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-00000000003b',
    'FIND-WHEEZE',
    'Wheeze',
    'Musical expiratory or inspiratory added breath sound.',
    'WHEEZE_PRESENT',
    'sign',
    100
),

(
    'f1500000-0000-0000-0000-000000000015',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-ABSENT-BREATH',
    'Reduced or absent breath sounds',
    'Reduced or absent breath sounds over a specified region.',
    'REDUCED_BREATH_SOUNDS',
    'sign',
    110
),

(
    'f1500000-0000-0000-0000-000000000016',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-PLEURAL-RUB',
    'Pleural friction rub',
    'Grating sound produced by inflamed pleural surfaces.',
    'PLEURAL_RUB',
    'sign',
    120
),

(
    'f1500000-0000-0000-0000-000000000017',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-TACTILE-VOCAL',
    'Abnormal tactile vocal fremitus',
    'Altered transmission of vocal vibrations through the chest wall.',
    'TACTILE_VOCAL_FREMITUS',
    'sign',
    130
),

(
    'f1500000-0000-0000-0000-000000000018',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-RLL-DULLNESS',
    'Right lower lobe dullness',
    'Percussion dullness localized to the right lower chest.',
    'RLL_DULLNESS',
    'sign',
    140
),

(
    'f1500000-0000-0000-0000-000000000019',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-RLL-BRONCHIAL',
    'Right lower lobe bronchial breath sounds',
    'Bronchial breath sounds localized to the right lower lobe.',
    'RLL_BRONCHIAL_BREATH_SOUNDS',
    'sign',
    150
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 6 — CARDIOVASCULAR EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-00000000001a',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-HR',
    'Heart rate',
    'Heart rate in beats per minute.',
    'HEART_RATE',
    'measurement',
    10
),

(
    'f1500000-0000-0000-0000-00000000001b',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-PULSE-RHYTHM',
    'Pulse rhythm',
    'Regularity and rhythm of the peripheral pulse.',
    'PULSE_RHYTHM',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-00000000001c',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-PULSE-VOLUME',
    'Pulse volume',
    'Assessment of peripheral pulse volume.',
    'PULSE_VOLUME',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-00000000001d',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-JVP-ELEVATED',
    'Elevated JVP',
    'Raised jugular venous pressure.',
    'ELEVATED_JVP',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-00000000001e',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-PERIPHERAL-OEDEMA',
    'Peripheral oedema',
    'Dependent peripheral pitting oedema.',
    'PERIPHERAL_OEDEMA',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-00000000001f',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-HEART-SOUND-S3',
    'Third heart sound',
    'Audible S3 gallop.',
    'S3_PRESENT',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-000000000020',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-HEART-SOUND-S4',
    'Fourth heart sound',
    'Audible S4 gallop.',
    'S4_PRESENT',
    'sign',
    70
),

(
    'f1500000-0000-0000-0000-000000000021',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-MURMUR',
    'Cardiac murmur',
    'Audible cardiac murmur requiring characterization.',
    'CARDIAC_MURMUR',
    'sign',
    80
),

(
    'f1500000-0000-0000-0000-000000000022',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-COLD-EXTREMITIES',
    'Cold extremities',
    'Cool peripheral extremities suggesting impaired peripheral perfusion.',
    'COLD_EXTREMITIES',
    'sign',
    90
),

(
    'f1500000-0000-0000-0000-000000000023',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-CAP-REFILL',
    'Prolonged capillary refill',
    'Delayed capillary refill.',
    'PROLONGED_CAPILLARY_REFILL',
    'sign',
    100
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 7 — ABDOMINAL EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-000000000024',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-DISTENSION',
    'Abdominal distension',
    'Visible abdominal distension.',
    'ABDOMINAL_DISTENSION',
    'sign',
    10
),

(
    'f1500000-0000-0000-0000-000000000025',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-TENDERNESS',
    'Abdominal tenderness',
    'Pain elicited by abdominal palpation.',
    'ABDOMINAL_TENDERNESS',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-000000000026',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-GUARDING',
    'Abdominal guarding',
    'Involuntary or voluntary muscular guarding on palpation.',
    'ABDOMINAL_GUARDING',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-000000000027',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-RIGIDITY',
    'Abdominal rigidity',
    'Board-like or involuntary abdominal rigidity.',
    'ABDOMINAL_RIGIDITY',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-000000000028',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-REBOUND',
    'Rebound tenderness',
    'Pain elicited or increased on release of palpation.',
    'REBOUND_TENDERNESS',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-000000000029',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-MASS',
    'Abdominal mass',
    'Palpable abdominal mass requiring localization and characterization.',
    'ABDOMINAL_MASS',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-00000000002a',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-HEPATOMEGALY',
    'Hepatomegaly',
    'Enlarged liver on examination.',
    'HEPATOMEGALY',
    'sign',
    70
),

(
    'f1500000-0000-0000-0000-00000000002b',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-SPLENOMEGALY',
    'Splenomegaly',
    'Enlarged spleen on examination.',
    'SPLENOMEGALY',
    'sign',
    80
),

(
    'f1500000-0000-0000-0000-00000000002c',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-BOWEL-SOUNDS-ABSENT',
    'Absent bowel sounds',
    'No bowel sounds detected during appropriate auscultation.',
    'ABSENT_BOWEL_SOUNDS',
    'sign',
    90
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 8 — NEUROLOGICAL EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-00000000002d',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-GCS',
    'Glasgow Coma Scale',
    'Assessment of eye, verbal and motor responses.',
    'GCS',
    'measurement',
    10
),

(
    'f1500000-0000-0000-0000-00000000002e',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-CONFUSION',
    'Confusion',
    'Abnormal cognition or disorientation.',
    'CONFUSION',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-00000000002f',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-FOCAL-NEURO',
    'Focal neurological deficit',
    'Focal neurological abnormality detected on examination.',
    'FOCAL_NEUROLOGICAL_DEFICIT',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-000000000030',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-HEMIPARESIS',
    'Hemiparesis',
    'Weakness affecting one side of the body.',
    'HEMIPARESIS',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-000000000031',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-SEIZURE',
    'Seizure activity',
    'Observed seizure activity or clinically relevant postictal state.',
    'SEIZURE',
    'sign',
    50
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 9 — EXAMINATION → CONDITION RELATIONSHIPS
-- =============================================================================

INSERT INTO knowledge.examination_condition
(
    examination_module_id,
    condition_id,
    weight
)
VALUES

-- Pneumonia
(
    'f1400000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    0.8
),

(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

-- TB
(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000002',
    0.8
),

-- Asthma
(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

-- Heart failure
(
    'f1400000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000005',
    0.7
),

(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000005',
    0.9
),

(
    'f1400000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

-- GERD
(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000006',
    0.4
),

(
    'f1400000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000006',
    0.4
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 10 — EXAMINATION FINDING → GENERALIZED RELATIONSHIPS
-- =============================================================================
--
-- These edges allow the CPU to use findings independently of one particular
-- disease.
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

-- ---------------------------------------------------------------------------
-- RESPIRATORY DISTRESS
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000002',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.95,
    'Observed increased work of breathing is a clinically meaningful severity
     finding.'
),

-- ---------------------------------------------------------------------------
-- HYPOXAEMIA
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-00000000000c',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000000c',
    1.0,
    'positive',
    0.99,
    'Pulse oximetry provides objective oxygenation data.'
),

-- ---------------------------------------------------------------------------
-- WHEEZE
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000014',
    'supports',
    'symptom',
    'f0a00000-0000-0000-0000-00000000003b',
    1.0,
    'positive',
    0.95,
    'Wheeze is an auscultatory respiratory finding associated with airflow
     obstruction but is not specific to asthma.'
),

-- ---------------------------------------------------------------------------
-- CRACKLES
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000013',
    'supports',
    'symptom',
    'f0a00000-0000-0000-0000-00000000003c',
    1.0,
    'positive',
    0.95,
    'Crackles are a respiratory auscultatory finding with multiple possible
     mechanisms.'
),

-- ---------------------------------------------------------------------------
-- CARDIAC CONGESTION
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-00000000001d',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000001d',
    1.0,
    'positive',
    0.95,
    'Elevated JVP supports systemic venous congestion.'
),

(
    'finding',
    'f1500000-0000-0000-0000-00000000001e',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000001e',
    0.9,
    'positive',
    0.95,
    'Peripheral oedema supports fluid retention/congestion but is not specific
     to heart failure.'
),

-- ---------------------------------------------------------------------------
-- PERITONEAL IRRITATION
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000027',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-000000000027',
    1.0,
    'positive',
    0.95,
    'Abdominal rigidity is an important sign of peritoneal irritation.'
),

(
    'finding',
    'f1500000-0000-0000-0000-000000000028',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-000000000028',
    1.0,
    'positive',
    0.95,
    'Rebound tenderness may indicate peritoneal irritation but must be
     interpreted with the complete abdominal examination.'
),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL EMERGENCY
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-00000000002f',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000002f',
    1.0,
    'positive',
    0.98,
    'Focal neurological deficit requires urgent clinical localization and
     differential diagnosis.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 11 — CONDITION → EXAMINATION FINDING ASSOCIATIONS
-- =============================================================================
--
-- These are not diagnostic rules.
-- They represent expected/clinically useful associations.
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

-- ---------------------------------------------------------------------------
-- PNEUMONIA
-- ---------------------------------------------------------------------------

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000002',
    0.8,
    'positive',
    0.9,
    'Pneumonia may produce increased work of breathing.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000013',
    0.8,
    'positive',
    0.85,
    'Crackles may occur with pulmonary infection and consolidation.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000012',
    0.6,
    'positive',
    0.8,
    'Bronchial breath sounds may occur over consolidation.'
),

-- ---------------------------------------------------------------------------
-- ASTHMA
-- ---------------------------------------------------------------------------

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000014',
    1.0,
    'positive',
    0.95,
    'Wheeze commonly accompanies variable airflow obstruction.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000002',
    0.8,
    'positive',
    0.9,
    'Acute severe asthma may produce marked respiratory distress.'
),

-- ---------------------------------------------------------------------------
-- HEART FAILURE
-- ---------------------------------------------------------------------------

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-00000000001d',
    1.0,
    'positive',
    0.95,
    'Elevated JVP is an important sign of systemic venous congestion.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-00000000001e',
    0.9,
    'positive',
    0.95,
    'Peripheral oedema may accompany systemic congestion.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000013',
    0.7,
    'positive',
    0.85,
    'Pulmonary congestion may produce crackles.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-00000000001f',
    0.7,
    'positive',
    0.8,
    'An S3 may occur in volume-overloaded ventricular dysfunction.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 12 — INVESTIGATION / EXAMINATION SPECIALTY RELEVANCE
-- =============================================================================
--
-- Reusable routing metadata.
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

-- Chest imaging
(
    'f0a00000-0000-0000-0000-000000000012',
    'pulmonology',
    'primary',
    1.0,
    'Chest imaging is central to evaluation of many respiratory presentations.'
),

(
    'f0a00000-0000-0000-0000-000000000012',
    'internal_medicine',
    'primary',
    0.9,
    'Chest imaging is widely used in general medical assessment.'
),

(
    'f0a00000-0000-0000-0000-000000000012',
    'emergency_medicine',
    'primary',
    0.9,
    'Chest imaging supports evaluation of acute cardiopulmonary presentations.'
),

-- Pulse oximetry
(
    'f0a00000-0000-0000-0000-000000000014',
    'emergency_medicine',
    'primary',
    1.0,
    'Rapid oxygenation assessment in acute illness.'
),

(
    'f0a00000-0000-0000-0000-000000000014',
    'pulmonology',
    'primary',
    1.0,
    'Oxygenation is central to respiratory assessment.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 13 — UNIVERSAL CONCEPT → BODY SYSTEM MAPPINGS
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

(
    'f0a00000-0000-0000-0000-000000000012',
    'RESPIRATORY',
    'primary',
    1.0,
    'Chest radiography evaluates pulmonary and pleural pathology.'
),

(
    'f0a00000-0000-0000-0000-000000000014',
    'RESPIRATORY',
    'primary',
    1.0,
    'Pulse oximetry assesses oxygenation.'
),

(
    'f0a00000-0000-0000-0000-00000000001f',
    'HAEMATOLOGICAL',
    'primary',
    1.0,
    'Full blood count evaluates haematological parameters.'
),

(
    'f0a00000-0000-0000-0000-000000000020',
    'IMMUNE',
    'primary',
    1.0,
    'CRP is an inflammatory biomarker.'
),

(
    'f0a00000-0000-0000-0000-000000000021',
    'RENAL_URINARY',
    'primary',
    1.0,
    'Urea, creatinine and electrolytes assess renal and electrolyte status.'
),

(
    'f0a00000-0000-0000-0000-000000000013',
    'RESPIRATORY',
    'primary',
    1.0,
    'Sputum microbiology contributes to respiratory infection assessment.'
)

  ON CONFLICT DO NOTHING;





-- =============================================================================
-- SECTION 15 — CLINICAL SAFETY / RED-FLAG EXAMINATION EDGES
-- =============================================================================
--
-- These are emergency-routing signals.
-- They must NOT automatically produce a diagnosis.
-- They should raise urgency and activate appropriate clinical pathways.
-- =============================================================================




-- =============================================================================
-- SECTION 16 — FINAL DATA INTEGRITY NOTES
-- =============================================================================
--
-- The AMEXAN CPU should interpret the above as:
--
-- FINDING
--    ↓
-- FACT
--    ↓
-- CLINICAL SIGNIFICANCE
--    ↓
-- PHENOTYPE / MECHANISM
--    ↓
-- DIFFERENTIAL
--    ↓
-- INVESTIGATION SELECTION
--    ↓
-- RESULT
--    ↓
-- UPDATED FACTS
--    ↓
-- UPDATED DIFFERENTIAL
--    ↓
-- SEVERITY
--    ↓
-- MANAGEMENT / MONITORING / EDUCATION
--
-- NEVER implement:
--
--     "finding X = disease Y"
--
-- Instead:
--
--     "finding X increases/decreases support for hypothesis Y"
--
-- This preserves uncertainty and allows competing diagnoses to remain alive.
--
-- ============================================================================


-- =============================================================================
-- INVESTIGATION → CONDITION
-- =============================================================================
--
-- IMPORTANT:
-- These weights represent clinical usefulness/relevance.
-- They DO NOT mean:
--     investigation positive = diagnosis
--     investigation negative = diagnosis excluded
--
-- The reasoning engine must interpret results in context.
-- =============================================================================

INSERT INTO knowledge.investigation_condition
(
    investigation_id,
    condition_id,
    weight,
    rationale
)
VALUES

-- ---------------------------------------------------------------------------
-- PNEUMONIA
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Chest radiography can identify pulmonary infiltrates, consolidation,
     pleural complications and alternative diagnoses when imaging is indicated.'
),

(
    'f1300000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000001',
    1.0,
    'Oxygen saturation assesses hypoxaemia and severity.'
),

(
    'f1300000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    0.7,
    'FBC may provide supportive evidence of infection and identify anaemia or
     other clinically relevant abnormalities.'
),

(
    'f1300000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    0.6,
    'CRP provides contextual evidence of systemic inflammation.'
),

(
    'f1300000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    0.6,
    'Renal function and electrolytes support severity assessment and treatment
     planning in clinically significant infection.'
),

-- ---------------------------------------------------------------------------
-- TUBERCULOSIS
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000002',
    0.8,
    'Sputum smear can provide microbiological evidence of pulmonary TB but does
     not independently exclude TB when negative.'
),

(
    'f1300000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000002',
    0.7,
    'Chest imaging may support pulmonary TB assessment and identify alternative
     or associated pathology.'
),

-- ---------------------------------------------------------------------------
-- HEART FAILURE
-- ---------------------------------------------------------------------------

(
    'f1300000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Chest radiography may demonstrate pulmonary congestion, oedema, pleural
     effusion or alternative pulmonary pathology.'
),

(
    'f1300000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000005',
    0.8,
    'Oxygen saturation assesses gas-exchange impairment in decompensated heart
     failure and pulmonary oedema.'
),

(
    'f1300000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'Renal function and electrolytes are important for assessment and safe
     heart-failure treatment.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 3 — EXAMINATION MODULES
-- =============================================================================

INSERT INTO knowledge.examination_module
(
    id,
    concept_id,
    module_code,
    canonical_name,
    description,
    body_system_code,
    sort_order
)
VALUES

(
    'f1400000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-000000000022',
    'EXAM-GENERAL',
    'General examination',
    'General clinical assessment including appearance, consciousness,
     distress, perfusion, temperature and visible systemic signs.',
    'CONSTITUTIONAL',
    10
),

(
    'f1400000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000023',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assessment of respiratory rate, oxygenation, work of breathing,
     chest expansion, percussion and auscultation.',
    'RESPIRATORY',
    20
),

(
    'f1400000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-000000000024',
    'EXAM-CARDIOVASCULAR',
    'Cardiovascular examination',
    'Assessment of pulse, blood pressure, JVP, precordium, heart sounds,
     peripheral perfusion and oedema.',
    'CARDIOVASCULAR',
    30
),

(
    'f1400000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000025',
    'EXAM-ABDOMINAL',
    'Abdominal examination',
    'Inspection, auscultation, percussion and palpation of the abdomen,
     including peritoneal and organ-specific findings.',
    'GASTROINTESTINAL',
    40
),

(
    'f1400000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000026',
    'EXAM-NEUROLOGICAL',
    'Neurological examination',
    'Assessment of consciousness, orientation, cranial nerves, motor function,
     sensation, coordination and focal neurological deficit.',
    'NEUROLOGICAL',
    50
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 4 — GENERAL EXAMINATION FINDINGS
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

-- ---------------------------------------------------------------------------
-- GENERAL APPEARANCE / SEVERITY
-- ---------------------------------------------------------------------------

(
    'f1500000-0000-0000-0000-000000000001',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-ILL-APPEARING',
    'Ill appearance',
    'Patient appears systemically unwell.',
    'ILL_APPEARANCE',
    'sign',
    10
),

(
    'f1500000-0000-0000-0000-000000000002',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-RESP-DISTRESS',
    'Respiratory distress',
    'Visible increased work of breathing.',
    'RESPIRATORY_DISTRESS',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-000000000003',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-CYANOSIS',
    'Central cyanosis',
    'Bluish discoloration of central mucous membranes.',
    'CYANOSIS',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-000000000004',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-CHEST-INDRAWING',
    'Chest indrawing',
    'Visible inward movement of the chest wall during inspiration.',
    'CHEST_INDRAWING',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-000000000005',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-GRUNTING',
    'Grunting',
    'Expiratory grunting indicating increased respiratory effort.',
    'GRUNTING',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-000000000006',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-NASAL-FLARING',
    'Nasal flaring',
    'Visible widening of the nostrils during inspiration.',
    'NASAL_FLARING',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-000000000007',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-TEMP',
    'Temperature',
    'Measured body temperature in degrees Celsius.',
    'TEMPERATURE',
    'measurement',
    70
),

(
    'f1500000-0000-0000-0000-000000000008',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-BP',
    'Blood pressure',
    'Systolic and diastolic arterial blood pressure.',
    'BLOOD_PRESSURE',
    'measurement',
    80
),

(
    'f1500000-0000-0000-0000-000000000009',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-PERFUSION',
    'Peripheral perfusion',
    'Assessment of peripheral circulation including capillary refill.',
    'PERIPHERAL_PERFUSION',
    'sign',
    90
),

(
    'f1500000-0000-0000-0000-00000000000a',
    'f1400000-0000-0000-0000-000000000001',
    NULL,
    'FIND-ALTERED-CONSCIOUSNESS',
    'Altered consciousness',
    'Reduced or abnormal level of consciousness.',
    'ALTERED_CONSCIOUSNESS',
    'sign',
    100
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 5 — RESPIRATORY EXAMINATION FINDINGS
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-00000000000b',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-RR',
    'Respiratory rate',
    'Respiratory rate in breaths per minute.',
    'RESP_RATE',
    'measurement',
    10
),

(
    'f1500000-0000-0000-0000-00000000000c',
    'f1400000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000014',
    'FIND-SPO2',
    'Oxygen saturation',
    'Peripheral oxygen saturation measured by pulse oximetry.',
    'SPO2',
    'measurement',
    20
),

(
    'f1500000-0000-0000-0000-00000000000d',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-ACCESSORY-MUSCLES',
    'Accessory muscle use',
    'Use of accessory respiratory muscles.',
    'ACCESSORY_MUSCLE_USE',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-00000000000e',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-CHEST-EXPANSION',
    'Reduced chest expansion',
    'Reduced or asymmetrical chest expansion.',
    'REDUCED_CHEST_EXPANSION',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-00000000000f',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-TRACHEAL-DEVIATION',
    'Tracheal deviation',
    'Deviation of the trachea from the midline.',
    'TRACHEAL_DEVIATION',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-000000000010',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-PERCUSSION-DULL',
    'Percussion dullness',
    'Dull percussion note over a specified region.',
    'PERCUSSION_DULLNESS',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-000000000011',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-PERCUSSION-HYPER',
    'Hyperresonant percussion',
    'Hyperresonant percussion note over a specified region.',
    'PERCUSSION_HYPERRESONANCE',
    'sign',
    70
),

(
    'f1500000-0000-0000-0000-000000000012',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-BRONCHIAL-BREATH',
    'Bronchial breath sounds',
    'Bronchial breathing over an area where vesicular breathing is expected.',
    'BRONCHIAL_BREATH_SOUNDS',
    'sign',
    80
),

(
    'f1500000-0000-0000-0000-000000000013',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-CRACKLES',
    'Crackles',
    'Discontinuous added breath sounds on auscultation.',
    'CRACKLES',
    'sign',
    90
),

(
    'f1500000-0000-0000-0000-000000000014',
    'f1400000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-00000000003b',
    'FIND-WHEEZE',
    'Wheeze',
    'Musical expiratory or inspiratory added breath sound.',
    'WHEEZE_PRESENT',
    'sign',
    100
),

(
    'f1500000-0000-0000-0000-000000000015',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-ABSENT-BREATH',
    'Reduced or absent breath sounds',
    'Reduced or absent breath sounds over a specified region.',
    'REDUCED_BREATH_SOUNDS',
    'sign',
    110
),

(
    'f1500000-0000-0000-0000-000000000016',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-PLEURAL-RUB',
    'Pleural friction rub',
    'Grating sound produced by inflamed pleural surfaces.',
    'PLEURAL_RUB',
    'sign',
    120
),

(
    'f1500000-0000-0000-0000-000000000017',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-TACTILE-VOCAL',
    'Abnormal tactile vocal fremitus',
    'Altered transmission of vocal vibrations through the chest wall.',
    'TACTILE_VOCAL_FREMITUS',
    'sign',
    130
),

(
    'f1500000-0000-0000-0000-000000000018',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-RLL-DULLNESS',
    'Right lower lobe dullness',
    'Percussion dullness localized to the right lower chest.',
    'RLL_DULLNESS',
    'sign',
    140
),

(
    'f1500000-0000-0000-0000-000000000019',
    'f1400000-0000-0000-0000-000000000002',
    NULL,
    'FIND-RLL-BRONCHIAL',
    'Right lower lobe bronchial breath sounds',
    'Bronchial breath sounds localized to the right lower lobe.',
    'RLL_BRONCHIAL_BREATH_SOUNDS',
    'sign',
    150
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 6 — CARDIOVASCULAR EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-00000000001a',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-HR',
    'Heart rate',
    'Heart rate in beats per minute.',
    'HEART_RATE',
    'measurement',
    10
),

(
    'f1500000-0000-0000-0000-00000000001b',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-PULSE-RHYTHM',
    'Pulse rhythm',
    'Regularity and rhythm of the peripheral pulse.',
    'PULSE_RHYTHM',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-00000000001c',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-PULSE-VOLUME',
    'Pulse volume',
    'Assessment of peripheral pulse volume.',
    'PULSE_VOLUME',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-00000000001d',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-JVP-ELEVATED',
    'Elevated JVP',
    'Raised jugular venous pressure.',
    'ELEVATED_JVP',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-00000000001e',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-PERIPHERAL-OEDEMA',
    'Peripheral oedema',
    'Dependent peripheral pitting oedema.',
    'PERIPHERAL_OEDEMA',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-00000000001f',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-HEART-SOUND-S3',
    'Third heart sound',
    'Audible S3 gallop.',
    'S3_PRESENT',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-000000000020',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-HEART-SOUND-S4',
    'Fourth heart sound',
    'Audible S4 gallop.',
    'S4_PRESENT',
    'sign',
    70
),

(
    'f1500000-0000-0000-0000-000000000021',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-MURMUR',
    'Cardiac murmur',
    'Audible cardiac murmur requiring characterization.',
    'CARDIAC_MURMUR',
    'sign',
    80
),

(
    'f1500000-0000-0000-0000-000000000022',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-COLD-EXTREMITIES',
    'Cold extremities',
    'Cool peripheral extremities suggesting impaired peripheral perfusion.',
    'COLD_EXTREMITIES',
    'sign',
    90
),

(
    'f1500000-0000-0000-0000-000000000023',
    'f1400000-0000-0000-0000-000000000003',
    NULL,
    'FIND-CAP-REFILL',
    'Prolonged capillary refill',
    'Delayed capillary refill.',
    'PROLONGED_CAPILLARY_REFILL',
    'sign',
    100
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 7 — ABDOMINAL EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-000000000024',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-DISTENSION',
    'Abdominal distension',
    'Visible abdominal distension.',
    'ABDOMINAL_DISTENSION',
    'sign',
    10
),

(
    'f1500000-0000-0000-0000-000000000025',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-TENDERNESS',
    'Abdominal tenderness',
    'Pain elicited by abdominal palpation.',
    'ABDOMINAL_TENDERNESS',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-000000000026',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-GUARDING',
    'Abdominal guarding',
    'Involuntary or voluntary muscular guarding on palpation.',
    'ABDOMINAL_GUARDING',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-000000000027',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-RIGIDITY',
    'Abdominal rigidity',
    'Board-like or involuntary abdominal rigidity.',
    'ABDOMINAL_RIGIDITY',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-000000000028',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-REBOUND',
    'Rebound tenderness',
    'Pain elicited or increased on release of palpation.',
    'REBOUND_TENDERNESS',
    'sign',
    50
),

(
    'f1500000-0000-0000-0000-000000000029',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-ABDO-MASS',
    'Abdominal mass',
    'Palpable abdominal mass requiring localization and characterization.',
    'ABDOMINAL_MASS',
    'sign',
    60
),

(
    'f1500000-0000-0000-0000-00000000002a',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-HEPATOMEGALY',
    'Hepatomegaly',
    'Enlarged liver on examination.',
    'HEPATOMEGALY',
    'sign',
    70
),

(
    'f1500000-0000-0000-0000-00000000002b',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-SPLENOMEGALY',
    'Splenomegaly',
    'Enlarged spleen on examination.',
    'SPLENOMEGALY',
    'sign',
    80
),

(
    'f1500000-0000-0000-0000-00000000002c',
    'f1400000-0000-0000-0000-000000000004',
    NULL,
    'FIND-BOWEL-SOUNDS-ABSENT',
    'Absent bowel sounds',
    'No bowel sounds detected during appropriate auscultation.',
    'ABSENT_BOWEL_SOUNDS',
    'sign',
    90
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 8 — NEUROLOGICAL EXAMINATION
-- =============================================================================

INSERT INTO knowledge.examination_finding
(
    id,
    module_id,
    concept_id,
    finding_code,
    canonical_name,
    description,
    fact_definition_code,
    finding_type,
    sort_order
)
VALUES

(
    'f1500000-0000-0000-0000-00000000002d',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-GCS',
    'Glasgow Coma Scale',
    'Assessment of eye, verbal and motor responses.',
    'GCS',
    'measurement',
    10
),

(
    'f1500000-0000-0000-0000-00000000002e',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-CONFUSION',
    'Confusion',
    'Abnormal cognition or disorientation.',
    'CONFUSION',
    'sign',
    20
),

(
    'f1500000-0000-0000-0000-00000000002f',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-FOCAL-NEURO',
    'Focal neurological deficit',
    'Focal neurological abnormality detected on examination.',
    'FOCAL_NEUROLOGICAL_DEFICIT',
    'sign',
    30
),

(
    'f1500000-0000-0000-0000-000000000030',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-HEMIPARESIS',
    'Hemiparesis',
    'Weakness affecting one side of the body.',
    'HEMIPARESIS',
    'sign',
    40
),

(
    'f1500000-0000-0000-0000-000000000031',
    'f1400000-0000-0000-0000-000000000005',
    NULL,
    'FIND-SEIZURE',
    'Seizure activity',
    'Observed seizure activity or clinically relevant postictal state.',
    'SEIZURE',
    'sign',
    50
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 9 — EXAMINATION → CONDITION RELATIONSHIPS
-- =============================================================================

INSERT INTO knowledge.examination_condition
(
    examination_module_id,
    condition_id,
    weight
)
VALUES

-- Pneumonia
(
    'f1400000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    0.8
),

(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    1.0
),

-- TB
(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000002',
    0.8
),

-- Asthma
(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000004',
    1.0
),

-- Heart failure
(
    'f1400000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000005',
    0.7
),

(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000005',
    0.9
),

(
    'f1400000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

-- GERD
(
    'f1400000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000006',
    0.4
),

(
    'f1400000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000006',
    0.4
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 10 — EXAMINATION FINDING → GENERALIZED RELATIONSHIPS
-- =============================================================================
--
-- These edges allow the CPU to use findings independently of one particular
-- disease.
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

-- ---------------------------------------------------------------------------
-- RESPIRATORY DISTRESS
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000002',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.95,
    'Observed increased work of breathing is a clinically meaningful severity
     finding.'
),

-- ---------------------------------------------------------------------------
-- HYPOXAEMIA
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-00000000000c',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000000c',
    1.0,
    'positive',
    0.99,
    'Pulse oximetry provides objective oxygenation data.'
),

-- ---------------------------------------------------------------------------
-- WHEEZE
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000014',
    'supports',
    'symptom',
    'f0a00000-0000-0000-0000-00000000003b',
    1.0,
    'positive',
    0.95,
    'Wheeze is an auscultatory respiratory finding associated with airflow
     obstruction but is not specific to asthma.'
),

-- ---------------------------------------------------------------------------
-- CRACKLES
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000013',
    'supports',
    'symptom',
    'f0a00000-0000-0000-0000-00000000003c',
    1.0,
    'positive',
    0.95,
    'Crackles are a respiratory auscultatory finding with multiple possible
     mechanisms.'
),

-- ---------------------------------------------------------------------------
-- CARDIAC CONGESTION
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-00000000001d',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000001d',
    1.0,
    'positive',
    0.95,
    'Elevated JVP supports systemic venous congestion.'
),

(
    'finding',
    'f1500000-0000-0000-0000-00000000001e',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000001e',
    0.9,
    'positive',
    0.95,
    'Peripheral oedema supports fluid retention/congestion but is not specific
     to heart failure.'
),

-- ---------------------------------------------------------------------------
-- PERITONEAL IRRITATION
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-000000000027',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-000000000027',
    1.0,
    'positive',
    0.95,
    'Abdominal rigidity is an important sign of peritoneal irritation.'
),

(
    'finding',
    'f1500000-0000-0000-0000-000000000028',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-000000000028',
    1.0,
    'positive',
    0.95,
    'Rebound tenderness may indicate peritoneal irritation but must be
     interpreted with the complete abdominal examination.'
),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL EMERGENCY
-- ---------------------------------------------------------------------------

(
    'finding',
    'f1500000-0000-0000-0000-00000000002f',
    'supports',
    'fact',
    'f1500000-0000-0000-0000-00000000002f',
    1.0,
    'positive',
    0.98,
    'Focal neurological deficit requires urgent clinical localization and
     differential diagnosis.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 11 — CONDITION → EXAMINATION FINDING ASSOCIATIONS
-- =============================================================================
--
-- These are not diagnostic rules.
-- They represent expected/clinically useful associations.
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

-- ---------------------------------------------------------------------------
-- PNEUMONIA
-- ---------------------------------------------------------------------------

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000002',
    0.8,
    'positive',
    0.9,
    'Pneumonia may produce increased work of breathing.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000013',
    0.8,
    'positive',
    0.85,
    'Crackles may occur with pulmonary infection and consolidation.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000012',
    0.6,
    'positive',
    0.8,
    'Bronchial breath sounds may occur over consolidation.'
),

-- ---------------------------------------------------------------------------
-- ASTHMA
-- ---------------------------------------------------------------------------

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000014',
    1.0,
    'positive',
    0.95,
    'Wheeze commonly accompanies variable airflow obstruction.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000002',
    0.8,
    'positive',
    0.9,
    'Acute severe asthma may produce marked respiratory distress.'
),

-- ---------------------------------------------------------------------------
-- HEART FAILURE
-- ---------------------------------------------------------------------------

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-00000000001d',
    1.0,
    'positive',
    0.95,
    'Elevated JVP is an important sign of systemic venous congestion.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-00000000001e',
    0.9,
    'positive',
    0.95,
    'Peripheral oedema may accompany systemic congestion.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-000000000013',
    0.7,
    'positive',
    0.85,
    'Pulmonary congestion may produce crackles.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'may_present_with',
    'finding',
    'f1500000-0000-0000-0000-00000000001f',
    0.7,
    'positive',
    0.8,
    'An S3 may occur in volume-overloaded ventricular dysfunction.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 12 — INVESTIGATION / EXAMINATION SPECIALTY RELEVANCE
-- =============================================================================
--
-- Reusable routing metadata.
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

-- Chest imaging
(
    'f0a00000-0000-0000-0000-000000000012',
    'pulmonology',
    'primary',
    1.0,
    'Chest imaging is central to evaluation of many respiratory presentations.'
),

(
    'f0a00000-0000-0000-0000-000000000012',
    'internal_medicine',
    'primary',
    0.9,
    'Chest imaging is widely used in general medical assessment.'
),

(
    'f0a00000-0000-0000-0000-000000000012',
    'emergency_medicine',
    'primary',
    0.9,
    'Chest imaging supports evaluation of acute cardiopulmonary presentations.'
),

-- Pulse oximetry
(
    'f0a00000-0000-0000-0000-000000000014',
    'emergency_medicine',
    'primary',
    1.0,
    'Rapid oxygenation assessment in acute illness.'
),

(
    'f0a00000-0000-0000-0000-000000000014',
    'pulmonology',
    'primary',
    1.0,
    'Oxygenation is central to respiratory assessment.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 13 — UNIVERSAL CONCEPT → BODY SYSTEM MAPPINGS
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

(
    'f0a00000-0000-0000-0000-000000000012',
    'RESPIRATORY',
    'primary',
    1.0,
    'Chest radiography evaluates pulmonary and pleural pathology.'
),

(
    'f0a00000-0000-0000-0000-000000000014',
    'RESPIRATORY',
    'primary',
    1.0,
    'Pulse oximetry assesses oxygenation.'
),

(
    'f0a00000-0000-0000-0000-00000000001f',
    'HAEMATOLOGICAL',
    'primary',
    1.0,
    'Full blood count evaluates haematological parameters.'
),

(
    'f0a00000-0000-0000-0000-000000000020',
    'IMMUNE',
    'primary',
    1.0,
    'CRP is an inflammatory biomarker.'
),

(
    'f0a00000-0000-0000-0000-000000000021',
    'RENAL_URINARY',
    'primary',
    1.0,
    'Urea, creatinine and electrolytes assess renal and electrolyte status.'
),

(
    'f0a00000-0000-0000-0000-000000000013',
    'RESPIRATORY',
    'primary',
    1.0,
    'Sputum microbiology contributes to respiratory infection assessment.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 14 — CORE SEVERITY FACTS
-- =============================================================================
--
-- These facts are intentionally generic.
-- They can be used by multiple diseases.
-- =============================================================================




-- =============================================================================
-- SECTION 15 — CLINICAL SAFETY / RED-FLAG EXAMINATION EDGES
-- =============================================================================
--
-- These are emergency-routing signals.
-- They must NOT automatically produce a diagnosis.
-- They should raise urgency and activate appropriate clinical pathways.
-- =============================================================================




-- =============================================================================
-- SECTION 16 — FINAL DATA INTEGRITY NOTES
-- =============================================================================
--
-- The AMEXAN CPU should interpret the above as:
--
-- FINDING
--    ↓
-- FACT
--    ↓
-- CLINICAL SIGNIFICANCE
--    ↓
-- PHENOTYPE / MECHANISM
--    ↓
-- DIFFERENTIAL
--    ↓
-- INVESTIGATION SELECTION
--    ↓
-- RESULT
--    ↓
-- UPDATED FACTS
--    ↓
-- UPDATED DIFFERENTIAL
--    ↓
-- SEVERITY
--    ↓
-- MANAGEMENT / MONITORING / EDUCATION
--
-- NEVER implement:
--
--     "finding X = disease Y"
--
-- Instead:
--
--     "finding X increases/decreases support for hypothesis Y"
--
-- This preserves uncertainty and allows competing diagnoses to remain alive.
--
-- =============================================================================