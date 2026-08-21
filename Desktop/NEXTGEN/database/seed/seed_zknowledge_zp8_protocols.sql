-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP8
-- UNIVERSAL CLINICAL PROTOCOL / CARE-PATHWAY INTELLIGENCE
-- =============================================================================
--
-- PURPOSE
-- -------
-- ZP8 is the orchestration layer of the AMEXAN Clinical Intelligence CPU.
--
-- It does NOT redefine:
--   • symptoms
--   • examination findings
--   • investigations
--   • medications
--   • dose references
--   • monitoring targets
--   • education
--
-- Those are reusable intelligence objects seeded elsewhere.
--
-- ZP8 defines:
--   • clinical pathways
--   • pathway eligibility
--   • pathway/condition relationships
--   • ordered clinical reasoning steps
--   • executable actions
--   • monitoring plans
--   • escalation logic
--   • investigation triggers
--   • treatment orchestration
--   • education orchestration
--   • disposition
--   • follow-up
--
-- IMPORTANT SAFETY MODEL
-- ----------------------
-- Protocols remain DRAFT until clinically reviewed and approved.
-- Medication actions reference medication intelligence by code.
-- Dose references remain independently verifiable.
-- No protocol here should be interpreted as a prescription without:
--   1. patient-specific context
--   2. contraindication/allergy review
--   3. renal/hepatic/pregnancy review where applicable
--   4. local formulary
--   5. current approved clinical guideline
--   6. clinician confirmation
--
-- =============================================================================


-- ============================================================================
-- 1. PROTOCOL ANCHORS
-- ============================================================================

INSERT INTO knowledge.protocol
(
    id,
    concept_id,
    protocol_code,
    canonical_name,
    version_label,
    description,
    specialty_code,
    purpose,
    status,
    is_guideline,
    source_reference
)
VALUES

(
    'f1900000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-000000000036',
    'PROT-CAP-ADULT',
    'Adult community-acquired pneumonia pathway',
    'MVP-1.0',
    'Universal pathway for assessment, severity recognition, investigation, treatment orchestration, monitoring, escalation, disposition, education and follow-up of suspected adult community-acquired pneumonia.',
    'pulmonology',
    'management',
    'draft',
    true,
    'Current approved local/international CAP guideline required'
),

(
    'f1900000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000037',
    'PROT-TB-DIAGNOSTIC',
    'Suspected pulmonary tuberculosis pathway',
    'MVP-1.0',
    'Universal diagnostic pathway for patients with a clinical presentation compatible with pulmonary tuberculosis, including specimen acquisition, investigation, infection-control consideration, referral, notification and follow-up.',
    'pulmonology',
    'diagnostic',
    'draft',
    true,
    'Current approved national TB guideline required'
),

(
    'f1900000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-000000000038',
    'PROT-ASTHMA-ACUTE',
    'Acute asthma pathway',
    'MVP-1.0',
    'Universal pathway for acute asthma/wheeze presentations including severity assessment, immediate supportive care, bronchodilator treatment orchestration, response monitoring, escalation and disposition.',
    'pulmonology',
    'management',
    'draft',
    true,
    'Current approved asthma guideline required'
),

(
    'f1900000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000039',
    'PROT-HF-DECOMP',
    'Acute decompensated heart failure pathway',
    'MVP-1.0',
    'Universal pathway for acute/subacute heart-failure presentations with congestion, dyspnoea, hypoxaemia or haemodynamic instability.',
    'cardiology',
    'management',
    'draft',
    true,
    'Current approved heart-failure guideline required'
),

(
    'f1900000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-00000000003b',
    'PROT-CHEST-PAIN',
    'Acute chest pain pathway',
    'MVP-1.0',
    'Universal undifferentiated chest-pain pathway prioritising immediate recognition of life-threatening causes, structured history, examination, targeted investigation, risk assessment, escalation and disposition.',
    'emergency_medicine',
    'diagnostic',
    'draft',
    true,
    'Current approved chest-pain/ACS guideline required'
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 2. PROTOCOL ? CONDITION RELATIONSHIPS
-- ============================================================================
--
-- Existing condition IDs:
--   001 = pneumonia
--   002 = tuberculosis
--   004 = asthma
--   005 = heart failure
--   006 = abdominal condition from earlier seed
--
-- Chest pain intentionally remains a pathway-level syndrome until a dedicated
-- ACS / PE / dissection condition ontology is seeded.
-- ============================================================================

INSERT INTO knowledge.protocol_condition
(
    protocol_id,
    condition_id,
    is_primary
)
VALUES

(
    'f1900000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    true
),

(
    'f1900000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000002',
    true
),

(
    'f1900000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000004',
    true
),

(
    'f1900000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000005',
    true
),

(
    'f1900000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    false
),

(
    'f1900000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000005',
    false
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 3. ADULT CAP — COMPLETE PATHWAY
-- ============================================================================

INSERT INTO knowledge.protocol_step
(
    id,
    protocol_id,
    step_code,
    step_label,
    step_type,
    sequence_no,
    instruction,
    rationale,
    required
)
VALUES

(
    'f1a00000-0000-0000-0000-000000000001',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-01',
    'Establish suspected CAP',
    'eligibility',
    10,
    'Integrate acute cough or other lower-respiratory symptoms with systemic features, examination findings and the clinical context.',
    'CAP is a clinical syndrome and should not be established from one isolated finding.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000001',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-02',
    'Identify immediate threats',
    'red_flag',
    20,
    'Assess for hypoxaemia, severe respiratory distress, haemodynamic instability, altered consciousness and other immediately dangerous features.',
    'Immediate threats take priority over routine diagnostic completion.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000002',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-03',
    'Complete focused examination',
    'assessment',
    30,
    'Perform general and respiratory examination including respiratory rate, oxygenation, work of breathing, percussion and auscultation.',
    'Examination establishes physiological severity and phenotype.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000003',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-04',
    'Assess severity and risk',
    'risk_stratification',
    40,
    'Integrate physiological findings, comorbidity, age, functional status, social circumstances and validated severity assessment where applicable.',
    'Severity determines urgency, treatment intensity and disposition.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000004',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-05',
    'Select investigations',
    'investigation',
    50,
    'Select investigations only when they answer a clinical question, establish severity, identify complications or change management.',
    'Investigation should be clinically purposeful rather than indiscriminate.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000005',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-06',
    'Initiate supportive care',
    'supportive',
    60,
    'Provide supportive management appropriate to physiological status, including oxygenation support when clinically indicated.',
    'Supportive care addresses physiological threats independently of antimicrobial selection.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000006',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-07',
    'Select antimicrobial treatment',
    'treatment',
    70,
    'Where bacterial pneumonia is sufficiently likely, select empiric antimicrobial therapy according to current approved guidance, severity, setting, allergy history, comorbidity, renal/hepatic status and local resistance patterns.',
    'Antimicrobial choice must be patient-specific and guideline-controlled.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000007',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-08',
    'Monitor response',
    'monitoring',
    80,
    'Trend oxygenation, respiratory rate, work of breathing, temperature, heart rate, clinical symptoms and relevant investigations according to severity.',
    'Response over time is part of clinical evidence.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000008',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-09',
    'Reassess non-response',
    'escalation',
    90,
    'If deterioration or failure to improve occurs, reassess the diagnosis, complications, resistance, adherence, alternative infection and non-infectious mimics.',
    'Unexpected trajectory represents new clinical evidence.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000009',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-10',
    'Determine disposition',
    'disposition',
    100,
    'Determine outpatient management, observation, admission, higher-level monitoring or escalation using severity, response, social support and ability to safely continue care.',
    'Disposition is dynamic and depends on both clinical and contextual factors.',
    true
),

(
    'f1a00000-0000-0000-0000-00000000000a',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-11',
    'Educate and teach back',
    'education',
    110,
    'Explain the illness, treatment plan, medication instructions, expected course, warning signs and follow-up using patient teach-back.',
    'Understanding is necessary for safe longitudinal care.',
    true
),

(
    'f1a00000-0000-0000-0000-00000000000b',
    'f1900000-0000-0000-0000-000000000001',
    'CAP-STEP-12',
    'Close the care loop',
    'follow_up',
    120,
    'Record follow-up timing, clinical targets, warning signs and information that should return to the longitudinal record.',
    'The episode must connect to continuing care.',
    true
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 4. CAP ACTIONS
-- ============================================================================

INSERT INTO knowledge.protocol_action
(
    id,
    protocol_id,
    step_id,
    action_type,
    action_code,
    action_name,
    detail,
    urgency,
    sort_order
)
VALUES

-- Red flags
(
    'f1b00000-0000-0000-0000-000000000001',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000001',
    'investigate',
    'INV-SPO2',
    'Pulse oximetry',
    'Immediate bedside oxygenation assessment.',
    'immediate',
    10
),

-- Examination
(
    'f1b00000-0000-0000-0000-000000000002',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000002',
    'examine',
    'EXAM-GENERAL',
    'General examination',
    'Assess general appearance, distress, cyanosis and core physiological observations.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000003',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000002',
    'examine',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assess respiratory rate, oxygenation, work of breathing, percussion and auscultation.',
    'immediate',
    20
),

-- Severity
(
    'f1b00000-0000-0000-0000-000000000004',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000003',
    'monitor',
    'MON-SPO2',
    'Oxygen saturation',
    'Establish baseline oxygenation and repeat according to severity.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000005',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000003',
    'monitor',
    'MON-RR',
    'Respiratory rate',
    'Establish respiratory workload and serial trajectory.',
    'immediate',
    20
),

(
    'f1b00000-0000-0000-0000-000000000006',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000003',
    'monitor',
    'MON-HR',
    'Heart rate',
    'Establish baseline physiological response and trend.',
    'routine',
    30
),

-- Investigations
(
    'f1b00000-0000-0000-0000-000000000007',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000004',
    'investigate',
    'INV-CXR',
    'Chest X-ray',
    'Use when clinically indicated to establish pulmonary pathology or complications.',
    'routine',
    10
),

(
    'f1b00000-0000-0000-0000-000000000008',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000004',
    'investigate',
    'INV-FBC',
    'Full blood count',
    'Use where severity, inflammatory assessment or alternative diagnosis makes the result clinically useful.',
    'routine',
    20
),

(
    'f1b00000-0000-0000-0000-000000000009',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000004',
    'investigate',
    'INV-CRP',
    'C-reactive protein',
    'Use when inflammatory assessment may assist clinical decision-making.',
    'routine',
    30
),

-- Supportive care
(
    'f1b00000-0000-0000-0000-00000000000a',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000005',
    'support',
    'INV-SPO2',
    'Oxygenation assessment',
    'Use oxygen-support decisions according to measured oxygenation and current clinical guidance.',
    'immediate',
    10
),

-- Treatment
(
    'f1b00000-0000-0000-0000-00000000000b',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000006',
    'medicate',
    'MED-AMOXICILLIN',
    'Amoxicillin',
    'Candidate empiric antimicrobial. Dose, route, duration and eligibility must be resolved from verified current guidance.',
    'routine',
    10
),

(
    'f1b00000-0000-0000-0000-00000000000c',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000006',
    'medicate',
    'MED-AMOXICILLIN-CLAVULANATE',
    'Amoxicillin/clavulanate',
    'Alternative antimicrobial option when clinically appropriate under current approved guidance.',
    'routine',
    20
),

(
    'f1b00000-0000-0000-0000-00000000000d',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000006',
    'medicate',
    'MED-CEFTRIAXONE',
    'Ceftriaxone',
    'Parenteral antimicrobial option for appropriately severe presentations under verified guidance.',
    'urgent',
    30
),

(
    'f1b00000-0000-0000-0000-00000000000e',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000006',
    'medicate',
    'MED-AZITHROMYCIN',
    'Azithromycin',
    'Use only when clinically indicated and supported by current guidance.',
    'routine',
    40
),

(
    'f1b00000-0000-0000-0000-00000000000f',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000006',
    'medicate',
    'MED-PARACETAMOL',
    'Paracetamol',
    'Symptomatic treatment for pain/fever when appropriate; dose must be verified.',
    'routine',
    50
),

-- Monitoring
(
    'f1b00000-0000-0000-0000-000000000010',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000007',
    'monitor',
    'MON-SPO2',
    'Oxygen saturation',
    'Serial oxygenation trajectory.',
    'routine',
    10
),

(
    'f1b00000-0000-0000-0000-000000000011',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000007',
    'monitor',
    'MON-RR',
    'Respiratory rate',
    'Serial respiratory workload.',
    'routine',
    20
),

(
    'f1b00000-0000-0000-0000-000000000012',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000007',
    'monitor',
    'MON-TEMP',
    'Temperature',
    'Trend febrile response.',
    'routine',
    30
),

(
    'f1b00000-0000-0000-0000-000000000013',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000007',
    'monitor',
    'MON-HR',
    'Heart rate',
    'Trend physiological response.',
    'routine',
    40
),

(
    'f1b00000-0000-0000-0000-000000000014',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000007',
    'monitor',
    'MON-WOB',
    'Work of breathing',
    'Serially assess respiratory effort.',
    'urgent',
    50
),

-- Escalation
(
    'f1b00000-0000-0000-0000-000000000015',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000008',
    'investigate',
    'INV-UREA-CREAT',
    'Urea and electrolytes',
    'Use when deterioration, organ dysfunction or treatment-safety considerations require renal assessment.',
    'urgent',
    10
),

(
    'f1b00000-0000-0000-0000-000000000016',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-000000000008',
    'reassess',
    'EXAM-RESPIRATORY',
    'Repeat respiratory examination',
    'Repeat examination when trajectory is worse than expected.',
    'urgent',
    20
),

-- Education
(
    'f1b00000-0000-0000-0000-000000000017',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-00000000000a',
    'educate',
    'EDU-CAP-BASICS',
    'Understanding pneumonia',
    'Explain illness and expected clinical course.',
    'routine',
    10
),

(
    'f1b00000-0000-0000-0000-000000000018',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-00000000000a',
    'educate',
    'EDU-CAP-DANGER-SIGNS',
    'Pneumonia danger signs',
    'Teach warning signs and urgent return instructions.',
    'routine',
    20
),

(
    'f1b00000-0000-0000-0000-000000000019',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-00000000000a',
    'educate',
    'EDU-CAP-MEDICATION',
    'Medication safety',
    'Explain medication purpose and safe use.',
    'routine',
    30
),

(
    'f1b00000-0000-0000-0000-00000000001a',
    'f1900000-0000-0000-0000-000000000001',
    'f1a00000-0000-0000-0000-00000000000a',
    'educate',
    'EDU-CAP-TEACHBACK',
    'Teach-back',
    'Confirm understanding using patient-generated explanation.',
    'routine',
    40
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 5. CAP MONITORING PLAN
-- ============================================================================

INSERT INTO knowledge.protocol_monitoring
(
    protocol_id,
    monitoring_id,
    frequency,
    deterioration_rule,
    escalation_instruction
)
VALUES

(
    'f1900000-0000-0000-0000-000000000001',
    'f1700000-0000-0000-0000-000000000001',
    'Baseline and according to severity',
    'Worsening oxygenation or new hypoxaemia',
    'Immediate clinical reassessment and escalation according to severity.'
),

(
    'f1900000-0000-0000-0000-000000000001',
    'f1700000-0000-0000-0000-000000000002',
    'Baseline and serially',
    'Increasing respiratory rate or respiratory distress',
    'Repeat respiratory assessment and escalate if clinically unstable.'
),

(
    'f1900000-0000-0000-0000-000000000001',
    'f1700000-0000-0000-0000-000000000003',
    'Serially as clinically indicated',
    'Persistent or worsening fever with poor response',
    'Reassess diagnosis, source, complications and treatment response.'
),

(
    'f1900000-0000-0000-0000-000000000001',
    'f1700000-0000-0000-0000-000000000004',
    'Baseline and serially',
    'Persistent/worsening tachycardia or instability',
    'Reassess haemodynamic state and differential diagnosis.'
),

(
    'f1900000-0000-0000-0000-000000000001',
    'f1700000-0000-0000-0000-000000000005',
    'With each clinical reassessment',
    'Increasing work of breathing',
    'Urgent reassessment and escalation according to severity.'
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 6. TB DIAGNOSTIC PATHWAY
-- ============================================================================

INSERT INTO knowledge.protocol_step
(
    id,
    protocol_id,
    step_code,
    step_label,
    step_type,
    sequence_no,
    instruction,
    rationale,
    required
)
VALUES

(
    'f1a00000-0000-0000-0000-000000000020',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-01',
    'Identify TB-compatible presentation',
    'eligibility',
    10,
    'Assess duration and pattern of cough together with constitutional symptoms, epidemiological exposure and relevant risk factors.',
    'Clinical context establishes pre-test suspicion.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000021',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-02',
    'Assess immediate clinical risk',
    'red_flag',
    20,
    'Assess respiratory compromise, haemodynamic instability, severe systemic illness and other urgent conditions.',
    'TB suspicion does not remove the need to address immediate threats.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000022',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-03',
    'Perform focused examination',
    'assessment',
    30,
    'Perform general and respiratory examination and document clinically relevant findings.',
    'Phenotype and severity influence diagnostic strategy.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000023',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-04',
    'Obtain diagnostic specimen',
    'investigation',
    40,
    'Obtain appropriate respiratory specimen and perform the currently recommended microbiological testing.',
    'Microbiological confirmation is central to TB diagnosis and management.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000024',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-05',
    'Perform imaging when indicated',
    'investigation',
    50,
    'Use chest imaging when clinically indicated to evaluate pulmonary disease and alternative diagnoses.',
    'Imaging complements rather than replaces microbiological diagnosis.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000025',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-06',
    'Review diagnostic result',
    'reassessment',
    60,
    'Integrate microbiology, imaging and clinical findings and document the resulting diagnostic state.',
    'The diagnostic state must be explicitly updated as evidence arrives.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000026',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-07',
    'Escalate or refer',
    'escalation',
    70,
    'Refer or escalate according to the confirmed or suspected TB state and applicable public-health pathway.',
    'TB management requires coordinated longitudinal and public-health care.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000027',
    'f1900000-0000-0000-0000-000000000002',
    'TB-STEP-08',
    'Close diagnostic loop',
    'follow_up',
    80,
    'Ensure results, referrals, notification requirements and follow-up are recorded in the longitudinal record.',
    'Diagnostic completion requires documented continuity.',
    true
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.protocol_action
(
    id,
    protocol_id,
    step_id,
    action_type,
    action_code,
    action_name,
    detail,
    urgency,
    sort_order
)
VALUES

(
    'f1b00000-0000-0000-0000-000000000020',
    'f1900000-0000-0000-0000-000000000002',
    'f1a00000-0000-0000-0000-000000000021',
    'examine',
    'EXAM-GENERAL',
    'General examination',
    'Assess systemic illness and immediate physiological compromise.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000021',
    'f1900000-0000-0000-0000-000000000002',
    'f1a00000-0000-0000-0000-000000000021',
    'examine',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assess respiratory status and pulmonary findings.',
    'immediate',
    20
),

(
    'f1b00000-0000-0000-0000-000000000022',
    'f1900000-0000-0000-0000-000000000002',
    'f1a00000-0000-0000-0000-000000000023',
    'investigate',
    'INV-SPUTUM-AFB',
    'Sputum AFB',
    'Collect appropriate respiratory specimen according to current TB diagnostic protocol.',
    'urgent',
    10
),

(
    'f1b00000-0000-0000-0000-000000000023',
    'f1900000-0000-0000-0000-000000000002',
    'f1a00000-0000-0000-0000-000000000024',
    'investigate',
    'INV-CXR',
    'Chest X-ray',
    'Evaluate pulmonary pathology when clinically indicated.',
    'routine',
    10
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 7. ACUTE ASTHMA — COMPLETE MVP PATHWAY
-- ============================================================================

INSERT INTO knowledge.protocol_step
(
    id,
    protocol_id,
    step_code,
    step_label,
    step_type,
    sequence_no,
    instruction,
    rationale,
    required
)
VALUES

(
    'f1a00000-0000-0000-0000-000000000030',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-01',
    'Recognize acute asthma presentation',
    'eligibility',
    10,
    'Assess acute or worsening wheeze, cough, breathlessness and compatible variable airflow symptoms while considering alternative diagnoses.',
    'Wheeze is not specific to asthma.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000031',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-02',
    'Identify life-threatening features',
    'red_flag',
    20,
    'Assess work of breathing, oxygenation, consciousness, ability to speak and other markers of severe respiratory compromise.',
    'Severe asthma can deteriorate rapidly.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000032',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-03',
    'Perform focused respiratory assessment',
    'assessment',
    30,
    'Perform respiratory examination and record physiological severity.',
    'Baseline severity determines treatment and monitoring intensity.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000033',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-04',
    'Initiate acute treatment',
    'treatment',
    40,
    'Deliver guideline-directed acute bronchodilator and other indicated therapy according to severity and patient context.',
    'Treatment intensity must correspond to severity.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000034',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-05',
    'Monitor treatment response',
    'monitoring',
    50,
    'Repeat clinical and physiological assessment after treatment.',
    'Response provides both therapeutic and diagnostic information.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000035',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-06',
    'Escalate non-response',
    'escalation',
    60,
    'Escalate urgently when response is inadequate or physiological deterioration occurs.',
    'Failure to respond indicates increased risk.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000036',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-07',
    'Determine disposition',
    'disposition',
    70,
    'Determine discharge, observation, admission or higher-level respiratory support according to response and severity.',
    'Disposition depends on trajectory rather than presentation alone.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000037',
    'f1900000-0000-0000-0000-000000000003',
    'ASTHMA-STEP-08',
    'Close asthma episode',
    'follow_up',
    80,
    'Provide education, treatment-plan review and follow-up according to the approved asthma pathway.',
    'Acute care should connect to chronic asthma control.',
    true
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.protocol_action
(
    id,
    protocol_id,
    step_id,
    action_type,
    action_code,
    action_name,
    detail,
    urgency,
    sort_order
)
VALUES

(
    'f1b00000-0000-0000-0000-000000000030',
    'f1900000-0000-0000-0000-000000000003',
    'f1a00000-0000-0000-0000-000000000031',
    'examine',
    'EXAM-GENERAL',
    'General examination',
    'Assess distress and systemic physiological state.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000031',
    'f1900000-0000-0000-0000-000000000003',
    'f1a00000-0000-0000-0000-000000000031',
    'examine',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assess wheeze, work of breathing and respiratory status.',
    'immediate',
    20
),

(
    'f1b00000-0000-0000-0000-000000000032',
    'f1900000-0000-0000-0000-000000000003',
    'f1a00000-0000-0000-0000-000000000031',
    'monitor',
    'MON-SPO2',
    'Oxygen saturation',
    'Assess oxygenation and trend during acute treatment.',
    'immediate',
    30
),

(
    'f1b00000-0000-0000-0000-000000000033',
    'f1900000-0000-0000-0000-000000000003',
    'f1a00000-0000-0000-0000-000000000031',
    'monitor',
    'MON-WOB',
    'Work of breathing',
    'Serial assessment of respiratory effort.',
    'urgent',
    40
),

(
    'f1b00000-0000-0000-0000-000000000034',
    'f1900000-0000-0000-0000-000000000003',
    'f1a00000-0000-0000-0000-000000000033',
    'monitor',
    'MON-SPO2',
    'Oxygen saturation',
    'Monitor treatment response.',
    'urgent',
    10
),

(
    'f1b00000-0000-0000-0000-000000000035',
    'f1900000-0000-0000-0000-000000000003',
    'f1a00000-0000-0000-0000-000000000033',
    'monitor',
    'MON-RR',
    'Respiratory rate',
    'Monitor respiratory workload.',
    'urgent',
    20
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 8. ACUTE ASTHMA MONITORING
-- ============================================================================

INSERT INTO knowledge.protocol_monitoring
(
    protocol_id,
    monitoring_id,
    frequency,
    deterioration_rule,
    escalation_instruction
)
VALUES

(
    'f1900000-0000-0000-0000-000000000003',
    'f1700000-0000-0000-0000-000000000001',
    'Continuous/serial according to severity',
    'Falling oxygenation or new hypoxaemia',
    'Urgent reassessment and escalation.'
),

(
    'f1900000-0000-0000-0000-000000000003',
    'f1700000-0000-0000-0000-000000000002',
    'Serially',
    'Persistent or increasing respiratory rate',
    'Repeat severity assessment and escalate if deterioration continues.'
),

(
    'f1900000-0000-0000-0000-000000000003',
    'f1700000-0000-0000-0000-000000000005',
    'Serially',
    'Increasing work of breathing',
    'Urgent escalation.'
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 9. ACUTE DECOMPENSATED HEART FAILURE
-- ============================================================================

INSERT INTO knowledge.protocol_step
(
    id,
    protocol_id,
    step_code,
    step_label,
    step_type,
    sequence_no,
    instruction,
    rationale,
    required
)
VALUES

(
    'f1a00000-0000-0000-0000-000000000040',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-01',
    'Recognize congestion syndrome',
    'eligibility',
    10,
    'Assess dyspnoea, orthopnoea, paroxysmal nocturnal dyspnoea, oedema, elevated JVP and compatible clinical findings.',
    'The congestion phenotype guides the pathway.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000041',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-02',
    'Identify immediate threats',
    'red_flag',
    20,
    'Assess hypoxaemia, severe respiratory distress, hypotension, shock and altered mental status.',
    'Acute heart failure may produce immediate cardiorespiratory instability.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000042',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-03',
    'Complete cardiovascular and respiratory examination',
    'assessment',
    30,
    'Perform cardiovascular and respiratory examination including JVP, oedema, heart sounds, respiratory findings and physiological observations.',
    'Congestion and perfusion phenotype influence management.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000043',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-04',
    'Investigate cause and severity',
    'investigation',
    40,
    'Select investigations according to suspected cause, severity, organ function and treatment consequences.',
    'Acute decompensation may have a reversible precipitant.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000044',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-05',
    'Initiate guideline-directed acute management',
    'treatment',
    50,
    'Initiate treatment according to current heart-failure guidance, haemodynamic state, congestion phenotype and renal/electrolyte status.',
    'Therapy depends on the physiological phenotype.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000045',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-06',
    'Monitor decongestion and perfusion',
    'monitoring',
    60,
    'Trend oxygenation, heart rate, symptoms, volume status and renal/electrolyte parameters as clinically indicated.',
    'Treatment safety requires active monitoring.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000046',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-07',
    'Reassess response',
    'reassessment',
    70,
    'Assess whether congestion and physiological compromise are improving and search for treatment complications or an alternative diagnosis.',
    'Trajectory determines further management.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000047',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-08',
    'Determine disposition',
    'disposition',
    80,
    'Determine discharge, admission, monitored care or higher-level escalation according to response and severity.',
    'Disposition depends on clinical stability and response.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000048',
    'f1900000-0000-0000-0000-000000000004',
    'HF-STEP-09',
    'Close the care loop',
    'follow_up',
    90,
    'Document precipitant evaluation, medication plan, monitoring requirements, education and follow-up.',
    'Acute decompensation requires longitudinal management.',
    true
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.protocol_action
(
    id,
    protocol_id,
    step_id,
    action_type,
    action_code,
    action_name,
    detail,
    urgency,
    sort_order
)
VALUES

(
    'f1b00000-0000-0000-0000-000000000040',
    'f1900000-0000-0000-0000-000000000004',
    'f1a00000-0000-0000-0000-000000000042',
    'examine',
    'EXAM-CARDIOVASCULAR',
    'Cardiovascular examination',
    'Assess heart rate, JVP, oedema and heart sounds.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000041',
    'f1900000-0000-0000-0000-000000000004',
    'f1a00000-0000-0000-0000-000000000042',
    'examine',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assess respiratory compromise and pulmonary congestion findings.',
    'immediate',
    20
),

(
    'f1b00000-0000-0000-0000-000000000042',
    'f1900000-0000-0000-0000-000000000004',
    'f1a00000-0000-0000-0000-000000000043',
    'investigate',
    'INV-CXR',
    'Chest X-ray',
    'Assess pulmonary congestion, effusion and alternative pulmonary disease when indicated.',
    'urgent',
    10
),

(
    'f1b00000-0000-0000-0000-000000000043',
    'f1900000-0000-0000-0000-000000000004',
    'f1a00000-0000-0000-0000-000000000043',
    'investigate',
    'INV-UREA-CREAT',
    'Urea and electrolytes',
    'Assess renal function and electrolytes relevant to treatment safety.',
    'urgent',
    20
),

(
    'f1b00000-0000-0000-0000-000000000044',
    'f1900000-0000-0000-0000-000000000004',
    'f1a00000-0000-0000-0000-000000000045',
    'monitor',
    'MON-SPO2',
    'Oxygen saturation',
    'Trend oxygenation.',
    'urgent',
    10
),

(
    'f1b00000-0000-0000-0000-000000000045',
    'f1900000-0000-0000-0000-000000000004',
    'f1a00000-0000-0000-0000-000000000045',
    'monitor',
    'MON-HR',
    'Heart rate',
    'Trend physiological response.',
    'urgent',
    20
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.protocol_monitoring
(
    protocol_id,
    monitoring_id,
    frequency,
    deterioration_rule,
    escalation_instruction
)
VALUES

(
    'f1900000-0000-0000-0000-000000000004',
    'f1700000-0000-0000-0000-000000000001',
    'Serial during acute decompensation',
    'Worsening oxygenation',
    'Immediate reassessment and escalation.'
),

(
    'f1900000-0000-0000-0000-000000000004',
    'f1700000-0000-0000-0000-000000000004',
    'Serial during acute decompensation',
    'Persistent/worsening tachycardia or instability',
    'Immediate haemodynamic reassessment.'
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 10. ACUTE CHEST PAIN
-- ============================================================================
--
-- This pathway intentionally remains syndrome-based.
-- Do NOT hard-code "chest pain = ACS".
-- A future ZP condition layer should add dedicated:
--   • ACS
--   • pulmonary embolism
--   • aortic dissection
--   • pneumothorax
--   • pericarditis
--   • oesophageal causes
-- etc.
-- ============================================================================

INSERT INTO knowledge.protocol_step
(
    id,
    protocol_id,
    step_code,
    step_label,
    step_type,
    sequence_no,
    instruction,
    rationale,
    required
)
VALUES

(
    'f1a00000-0000-0000-0000-000000000050',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-01',
    'Recognize acute chest pain syndrome',
    'eligibility',
    10,
    'Identify acute chest discomfort or pain and immediately begin structured assessment.',
    'Chest pain has multiple potentially life-threatening causes.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000051',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-02',
    'Screen for life-threatening causes',
    'red_flag',
    20,
    'Consider acute coronary syndrome, pulmonary embolism, aortic catastrophe, pneumothorax and other immediately dangerous conditions according to presentation.',
    'Life-threatening causes must be prioritised.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000052',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-03',
    'Characterize the pain',
    'assessment',
    30,
    'Document onset, timing, quality, location, radiation, provoking/relieving factors and associated symptoms without prematurely assigning a diagnosis.',
    'Structured characterization narrows the differential.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000053',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-04',
    'Complete focused examination',
    'assessment',
    40,
    'Perform general, cardiovascular and respiratory examination with physiological observations.',
    'Examination identifies physiological compromise and alternative diagnostic pathways.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000054',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-05',
    'Select targeted investigations',
    'investigation',
    50,
    'Select investigations according to the differential diagnosis, urgency and expected management consequence.',
    'Testing should answer specific clinical questions.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000055',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-06',
    'Reassess evolving evidence',
    'reassessment',
    60,
    'Integrate history, examination and investigation results and update the differential diagnosis.',
    'Chest pain diagnoses often evolve as evidence becomes available.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000056',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-07',
    'Escalate when unstable',
    'escalation',
    70,
    'Escalate immediately when physiological instability or a time-critical diagnosis is suspected.',
    'Delay in time-critical disease can cause major harm.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000057',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-08',
    'Determine disposition',
    'disposition',
    80,
    'Determine discharge, observation, admission, monitored care or specialty escalation based on risk and diagnostic certainty.',
    'Disposition must reflect both current risk and residual uncertainty.',
    true
),

(
    'f1a00000-0000-0000-0000-000000000058',
    'f1900000-0000-0000-0000-000000000005',
    'CP-STEP-09',
    'Close diagnostic loop',
    'follow_up',
    90,
    'Document unresolved uncertainty, follow-up requirements and results requiring return to the clinical record.',
    'Undifferentiated presentations require explicit continuity.',
    true
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.protocol_action
(
    id,
    protocol_id,
    step_id,
    action_type,
    action_code,
    action_name,
    detail,
    urgency,
    sort_order
)
VALUES

(
    'f1b00000-0000-0000-0000-000000000050',
    'f1900000-0000-0000-0000-000000000005',
    'f1a00000-0000-0000-0000-000000000051',
    'examine',
    'EXAM-GENERAL',
    'General examination',
    'Assess general state and physiological instability.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000051',
    'f1900000-0000-0000-0000-000000000005',
    'f1a00000-0000-0000-0000-000000000051',
    'examine',
    'EXAM-CARDIOVASCULAR',
    'Cardiovascular examination',
    'Assess cardiovascular findings relevant to the differential.',
    'immediate',
    20
),

(
    'f1b00000-0000-0000-0000-000000000052',
    'f1900000-0000-0000-0000-000000000005',
    'f1a00000-0000-0000-0000-000000000051',
    'examine',
    'EXAM-RESPIRATORY',
    'Respiratory examination',
    'Assess pulmonary causes and physiological compromise.',
    'immediate',
    30
),

(
    'f1b00000-0000-0000-0000-000000000053',
    'f1900000-0000-0000-0000-000000000005',
    'f1a00000-0000-0000-0000-000000000054',
    'investigate',
    'INV-SPO2',
    'Pulse oximetry',
    'Immediate oxygenation assessment.',
    'immediate',
    10
),

(
    'f1b00000-0000-0000-0000-000000000054',
    'f1900000-0000-0000-0000-000000000005',
    'f1a00000-0000-0000-0000-000000000054',
    'investigate',
    'INV-CXR',
    'Chest X-ray',
    'Use when pulmonary, pleural or cardiac causes are clinically suspected.',
    'routine',
    20
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.protocol_monitoring
(
    protocol_id,
    monitoring_id,
    frequency,
    deterioration_rule,
    escalation_instruction
)
VALUES

(
    'f1900000-0000-0000-0000-000000000005',
    'f1700000-0000-0000-0000-000000000001',
    'Immediate and serial according to clinical risk',
    'Worsening oxygenation',
    'Urgent reassessment and escalation.'
),

(
    'f1900000-0000-0000-0000-000000000005',
    'f1700000-0000-0000-0000-000000000004',
    'Baseline and serially',
    'Worsening tachycardia or haemodynamic instability',
    'Immediate reassessment and escalation.'
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 11. UNIVERSAL PROTOCOL INTEGRITY CHECKS
-- ============================================================================
--
-- These queries are intentionally included as comments/reference queries.
-- They can be executed after seeding to identify orphaned protocol actions.
-- ============================================================================

-- Find protocol actions referencing an unknown investigation:
--
-- SELECT pa.action_code
-- FROM knowledge.protocol_action pa
-- LEFT JOIN knowledge.investigation i
--   ON i.investigation_code = pa.action_code
-- WHERE pa.action_type = 'investigate'
--   AND i.investigation_code IS NULL;


-- Find protocol actions referencing an unknown medication:
--
-- SELECT pa.action_code
-- FROM knowledge.protocol_action pa
-- LEFT JOIN knowledge.medication m
--   ON m.medication_code = pa.action_code
-- WHERE pa.action_type = 'medicate'
--   AND m.medication_code IS NULL;


-- Find protocol actions referencing an unknown monitoring target:
--
-- SELECT pa.action_code
-- FROM knowledge.protocol_action pa
-- LEFT JOIN knowledge.monitoring m
--   ON m.monitoring_code = pa.action_code
-- WHERE pa.action_type = 'monitor'
--   AND m.monitoring_code IS NULL;


-- Find protocol actions referencing an unknown examination module:
--
-- SELECT pa.action_code
-- FROM knowledge.protocol_action pa
-- LEFT JOIN knowledge.examination_module em
--   ON em.module_code = pa.action_code
-- WHERE pa.action_type IN ('examine', 'reassess')
--   AND em.module_code IS NULL;


-- Find protocol actions referencing unknown education:
--
-- SELECT pa.action_code
-- FROM knowledge.protocol_action pa
-- LEFT JOIN knowledge.education e
--   ON e.education_code = pa.action_code
-- WHERE pa.action_type = 'educate'
--   AND e.education_code IS NULL;


-- ============================================================================
-- END ZP8
-- ============================================================================