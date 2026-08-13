-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP8: Phase 1E protocols (care pathways)
-- =============================================================================
-- Five protocol anchors with ordered steps. Actions reference reusable
-- investigation / medication / monitoring / education objects by code.
-- The CAP pathway is fully populated (10 steps) as the primary proof chain.
-- =============================================================================

INSERT INTO knowledge.protocol (id, concept_id, protocol_code, canonical_name, version_label, description,
                                 specialty_code, purpose, status, is_guideline, source_reference) VALUES
   ('f1900000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000036', 'PROT-CAP-ADULT',
    'Adult community-acquired pneumonia pathway', 'MVP-0.1',
    'Suspected adult CAP: eligibility, red flags, assessment, investigation, treatment, monitoring, escalation, disposition, education, follow-up.',
    'respiratory_medicine', 'management', 'draft', true, 'Production CPG reference required'),
   ('f1900000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000037', 'PROT-TB-DIAGNOSTIC',
    'Suspected pulmonary tuberculosis pathway', 'MVP-0.1',
    'Chronic cough with constitutional features or TB exposure: diagnostic evaluation.',
    'respiratory_medicine', 'diagnostic', 'draft', true, 'Production TB guideline reference required'),
   ('f1900000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000038', 'PROT-ASTHMA-ACUTE',
    'Acute asthma pathway', 'MVP-0.1',
    'Acute wheeze / airflow obstruction presentation.',
    'respiratory_medicine', 'management', 'draft', true, 'Production asthma guideline reference required'),
   ('f1900000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000039', 'PROT-HF-DECOMP',
    'Decompensated heart failure pathway', 'MVP-0.1',
    'Acute/subacute congestion and dyspnoea presentation.',
    'cardiology', 'management', 'draft', true, 'Production heart-failure guideline reference required'),
   ('f1900000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-00000000003a', 'PROT-CHEST-PAIN',
    'Acute chest pain pathway', 'MVP-0.1',
    'Undifferentiated acute chest pain evaluation.',
    'emergency_department', 'diagnostic', 'draft', true, 'Production chest-pain/ACS guideline reference required')
ON CONFLICT (protocol_code) DO NOTHING;

INSERT INTO knowledge.protocol_condition (protocol_id, condition_id, is_primary) VALUES
   ('f1900000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', true),
   ('f1900000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', true),
   ('f1900000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004', true),
   ('f1900000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000005', true),
   ('f1900000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000005', false),
   ('f1900000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', false)
ON CONFLICT (protocol_id, condition_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- PROT-CAP-ADULT steps (full MVP chain)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no,
                                     instruction, rationale, required) VALUES
   ('f1a00000-0000-0000-0000-000000000001', 'f1900000-0000-0000-0000-000000000001', 'STEP-01', 'Establish suspected CAP', 'eligibility', 10,
    'Integrate acute respiratory symptoms, systemic features and examination findings.',
    'The diagnosis is a clinical synthesis rather than a single symptom.', true),
   ('f1a00000-0000-0000-0000-000000000002', 'f1900000-0000-0000-0000-000000000001', 'STEP-02', 'Screen for deterioration', 'red_flag', 20,
    'Assess oxygenation, respiratory distress, haemodynamic instability and other severity indicators.',
    'Early recognition of physiological deterioration changes disposition and treatment urgency.', true),
   ('f1a00000-0000-0000-0000-000000000003', 'f1900000-0000-0000-0000-000000000001', 'STEP-03', 'Complete focused respiratory assessment', 'assessment', 30,
    'Perform general and respiratory examination with vital signs and oxygenation.',
    'Focal findings and physiological severity refine the working phenotype.', true),
   ('f1a00000-0000-0000-0000-000000000004', 'f1900000-0000-0000-0000-000000000001', 'STEP-04', 'Select investigations', 'investigation', 40,
    'Use clinically indicated investigations based on severity, diagnostic uncertainty and management consequences.',
    'Testing should answer a clinical question rather than be performed indiscriminately.', true),
   ('f1a00000-0000-0000-0000-000000000005', 'f1900000-0000-0000-0000-000000000001', 'STEP-05', 'Select treatment', 'treatment', 50,
    'Use the current approved local/international guideline and verified formulary for empiric therapy when bacterial pneumonia is sufficiently likely.',
    'Therapy must depend on severity, setting, allergies, comorbidities, local resistance and current guidance.', true),
   ('f1a00000-0000-0000-0000-000000000006', 'f1900000-0000-0000-0000-000000000001', 'STEP-06', 'Monitor response', 'monitoring', 60,
    'Trend symptoms, respiratory status, oxygenation, vital signs, intake/output and relevant investigations according to severity.',
    'A treatment decision is not complete until response is observed.', true),
   ('f1a00000-0000-0000-0000-000000000007', 'f1900000-0000-0000-0000-000000000001', 'STEP-07', 'Reassess deterioration or non-response', 'escalation', 70,
    'If the trajectory is worse than expected, reassess diagnosis, complications, adherence, resistance, alternative infection and non-infectious mimics.',
    'Failure of the expected trajectory is new evidence and should trigger reasoning again.', true),
   ('f1a00000-0000-0000-0000-000000000008', 'f1900000-0000-0000-0000-000000000001', 'STEP-08', 'Determine disposition', 'disposition', 80,
    'Use clinical severity, social context, response and ability to safely monitor at home to determine outpatient versus admission/escalation.',
    'Disposition is a dynamic clinical decision.', true),
   ('f1a00000-0000-0000-0000-000000000009', 'f1900000-0000-0000-0000-000000000001', 'STEP-09', 'Educate patient', 'education', 90,
    'Explain diagnosis, expected course, medication use, danger signs and follow-up using teach-back.',
    'Patient understanding is part of safe longitudinal care.', true),
   ('f1a00000-0000-0000-0000-00000000000a', 'f1900000-0000-0000-0000-000000000001', 'STEP-10', 'Close the care loop', 'follow_up', 100,
    'Record the follow-up plan and define what information should return to the clinical record.',
    'The episode should generate continuity rather than terminate at discharge.', true)
ON CONFLICT (protocol_id, step_code) DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name,
                                       detail, urgency, sort_order) VALUES
   ('f1b00000-0000-0000-0000-000000000001', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000002',
    'investigate', 'INV-SPO2', 'Pulse oximetry', 'Immediate bedside oxygenation assessment', 'immediate', 10),
   ('f1b00000-0000-0000-0000-000000000002', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000003',
    'monitor', 'MON-SPO2', 'Oxygen saturation monitoring', 'Baseline and per severity', 'routine', 10),
   ('f1b00000-0000-0000-0000-000000000003', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000003',
    'monitor', 'MON-RR', 'Respiratory rate monitoring', 'Baseline and serially', 'routine', 20),
   ('f1b00000-0000-0000-0000-000000000004', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000004',
    'investigate', 'INV-CXR', 'Chest X-ray', 'When bacterial pneumonia is suspected', 'routine', 10),
   ('f1b00000-0000-0000-0000-000000000005', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000004',
    'investigate', 'INV-FBC', 'Full blood count', 'Inflammatory/haematological assessment', 'routine', 20),
   ('f1b00000-0000-0000-0000-000000000006', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000004',
    'investigate', 'INV-CRP', 'C-reactive protein', 'Systemic inflammatory marker', 'routine', 30),
   ('f1b00000-0000-0000-0000-000000000007', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000005',
    'medicate', 'MED-AMOXICILLIN', 'Amoxicillin', 'Empiric regimen - VERIFY against current local guideline', 'routine', 10),
   ('f1b00000-0000-0000-0000-000000000008', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000005',
    'medicate', 'MED-PARACETAMOL', 'Paracetamol', 'Symptomatic fever/pain control - VERIFY dose', 'routine', 20),
   ('f1b00000-0000-0000-0000-000000000009', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000006',
    'monitor', 'MON-TEMP', 'Temperature monitoring', 'Serially as clinically indicated', 'routine', 10),
   ('f1b00000-0000-0000-0000-00000000000a', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000006',
    'monitor', 'MON-HR', 'Heart rate monitoring', 'Baseline and serially', 'routine', 20),
   ('f1b00000-0000-0000-0000-00000000000b', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000007',
    'investigate', 'INV-UREA-CREAT', 'Urea and electrolytes', 'Severity/treatment planning on deterioration', 'urgent', 10),
   ('f1b00000-0000-0000-0000-00000000000c', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000009',
    'educate', 'EDU-CAP-BASICS', 'Understanding pneumonia', 'Explain illness and expected course', 'routine', 10),
   ('f1b00000-0000-0000-0000-00000000000d', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000009',
    'educate', 'EDU-CAP-DANGER-SIGNS', 'Pneumonia danger signs', 'Teach danger signs and when to seek care', 'routine', 20),
   ('f1b00000-0000-0000-0000-00000000000e', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000009',
    'educate', 'EDU-CAP-MEDICATION', 'Taking pneumonia treatment safely', 'Medication instructions', 'routine', 30),
   ('f1b00000-0000-0000-0000-00000000000f', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-000000000009',
    'educate', 'EDU-CAP-TEACHBACK', 'Pneumonia teach-back', 'Confirm understanding', 'routine', 40),
   ('f1b00000-0000-0000-0000-000000000010', 'f1900000-0000-0000-0000-000000000001', 'f1a00000-0000-0000-0000-00000000000a',
    'educate', 'EDU-CAP-CLINICIAN', 'Pneumonia reasoning summary', 'Render evidence, phenotype comparison and rationale', 'routine', 10)
ON CONFLICT (step_id, action_type, action_code) DO NOTHING;

INSERT INTO knowledge.protocol_monitoring (protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES
   ('f1900000-0000-0000-0000-000000000001', 'f1700000-0000-0000-0000-000000000001', 'Baseline and per severity',
    'Worsening oxygenation or new hypoxaemia', 'Immediate clinical reassessment and escalation according to severity'),
   ('f1900000-0000-0000-0000-000000000001', 'f1700000-0000-0000-0000-000000000002', 'Baseline and serially',
    'Increasing respiratory rate or new distress', 'Reassess respiratory status and diagnosis; escalate if unstable'),
   ('f1900000-0000-0000-0000-000000000001', 'f1700000-0000-0000-0000-000000000003', 'Serially as indicated',
    'Persistent/worsening fever with poor clinical response', 'Reassess diagnosis, source, complications and treatment'),
   ('f1900000-0000-0000-0000-000000000001', 'f1700000-0000-0000-0000-000000000004', 'Baseline and serially',
    'Persistent/worsening tachycardia or new instability', 'Reassess haemodynamic state and differential diagnosis'),
   ('f1900000-0000-0000-0000-000000000001', 'f1700000-0000-0000-0000-000000000005', 'With every clinical change',
    'Increasing work of breathing', 'Urgent reassessment and escalation according to severity')
ON CONFLICT (protocol_id, monitoring_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- PROT-TB-DIAGNOSTIC steps (abridged MVP)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no,
                                     instruction, rationale, required) VALUES
   ('f1a00000-0000-0000-0000-00000000000b', 'f1900000-0000-0000-0000-000000000002', 'STEP-01', 'Identify TB-compatible presentation', 'eligibility', 10,
    'Chronic cough with weight loss, night sweats, fever or known TB contact.',
    'Constitutional symptoms and exposure drive suspicion.', true),
   ('f1a00000-0000-0000-0000-00000000000c', 'f1900000-0000-0000-0000-000000000002', 'STEP-02', 'Obtain diagnostic specimens', 'investigation', 20,
    'Arrange sputum AFB and any clinically indicated imaging.',
    'Microbiological confirmation changes treatment and public-health action.', true),
   ('f1a00000-0000-0000-0000-00000000000d', 'f1900000-0000-0000-0000-000000000002', 'STEP-03', 'Escalate / refer', 'escalation', 30,
    'Refer for specialty TB care and notification once suspected/confirmed.',
    'TB care requires structured public-health follow-up.', true)
ON CONFLICT (protocol_id, step_code) DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name,
                                       detail, urgency, sort_order) VALUES
   ('f1b00000-0000-0000-0000-000000000011', 'f1900000-0000-0000-0000-000000000002', 'f1a00000-0000-0000-0000-00000000000c',
    'investigate', 'INV-SPUTUM-AFB', 'Sputum acid-fast bacilli', 'Early-morning samples', 'routine', 10),
   ('f1b00000-0000-0000-0000-000000000012', 'f1900000-0000-0000-0000-000000000002', 'f1a00000-0000-0000-0000-00000000000c',
    'investigate', 'INV-CXR', 'Chest X-ray', 'Assess pulmonary disease', 'routine', 20)
ON CONFLICT (step_id, action_type, action_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- PROT-ASTHMA-ACUTE steps (abridged MVP)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no,
                                     instruction, rationale, required) VALUES
   ('f1a00000-0000-0000-0000-00000000000e', 'f1900000-0000-0000-0000-000000000003', 'STEP-01', 'Confirm acute asthma presentation', 'eligibility', 10,
    'Episodic wheeze, cough and breathlessness with variable airflow obstruction.',
    'Distinguish asthma from other causes of wheeze.', true),
   ('f1a00000-0000-0000-0000-00000000000f', 'f1900000-0000-0000-0000-000000000003', 'STEP-02', 'Assess severity', 'assessment', 20,
    'Assess work of breathing, oxygenation, speech and vital signs.',
    'Severity determines treatment intensity and disposition.', true),
   ('f1a00000-0000-0000-0000-000000000010', 'f1900000-0000-0000-0000-000000000003', 'STEP-03', 'Treat and monitor response', 'treatment', 30,
    'Deliver bronchodilator therapy and reassess response serially.',
    'Response to treatment is diagnostic and prognostic.', true)
ON CONFLICT (protocol_id, step_code) DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name,
                                       detail, urgency, sort_order) VALUES
   ('f1b00000-0000-0000-0000-000000000013', 'f1900000-0000-0000-0000-000000000003', 'f1a00000-0000-0000-0000-00000000000f',
    'monitor', 'MON-SPO2', 'Oxygen saturation monitoring', 'Continuous during acute episode', 'urgent', 10),
   ('f1b00000-0000-0000-0000-000000000014', 'f1900000-0000-0000-0000-000000000003', 'f1a00000-0000-0000-0000-00000000000f',
    'monitor', 'MON-WOB', 'Work of breathing', 'Serial assessment of respiratory effort', 'urgent', 20)
ON CONFLICT (step_id, action_type, action_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- PROT-HF-DECOMP steps (abridged MVP)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no,
                                     instruction, rationale, required) VALUES
   ('f1a00000-0000-0000-0000-000000000011', 'f1900000-0000-0000-0000-000000000004', 'STEP-01', 'Recognize congestion', 'eligibility', 10,
    'Dyspnoea, orthopnoea, PND, peripheral oedema and elevated JVP.',
    'Congestion pattern distinguishes decompensation.', true),
   ('f1a00000-0000-0000-0000-000000000012', 'f1900000-0000-0000-0000-000000000004', 'STEP-02', 'Assess and investigate', 'investigation', 20,
    'Assess oxygenation, vitals, renal function and imaging.',
    'Guides decongestion strategy and therapy safety.', true),
   ('f1a00000-0000-0000-0000-000000000013', 'f1900000-0000-0000-0000-000000000004', 'STEP-03', 'Treat and monitor', 'treatment', 30,
    'Deliver guideline-directed decongestive therapy and trend response.',
    'Response to decongestion guides ongoing care.', true)
ON CONFLICT (protocol_id, step_code) DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name,
                                       detail, urgency, sort_order) VALUES
   ('f1b00000-0000-0000-0000-000000000015', 'f1900000-0000-0000-0000-000000000004', 'f1a00000-0000-0000-0000-000000000012',
    'investigate', 'INV-CXR', 'Chest X-ray', 'Assess congestion/effusion', 'urgent', 10),
   ('f1b00000-0000-0000-0000-000000000016', 'f1900000-0000-0000-0000-000000000004', 'f1a00000-0000-0000-0000-000000000012',
    'investigate', 'INV-UREA-CREAT', 'Urea and electrolytes', 'Guides diuretic therapy', 'urgent', 20),
   ('f1b00000-0000-0000-0000-000000000017', 'f1900000-0000-0000-0000-000000000004', 'f1a00000-0000-0000-0000-000000000013',
    'monitor', 'MON-SPO2', 'Oxygen saturation monitoring', 'Serial oxygenation trend', 'urgent', 10)
ON CONFLICT (step_id, action_type, action_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- PROT-CHEST-PAIN steps (abridged MVP)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no,
                                     instruction, rationale, required) VALUES
   ('f1a00000-0000-0000-0000-000000000014', 'f1900000-0000-0000-0000-000000000005', 'STEP-01', 'Screen for life threats', 'red_flag', 10,
    'ACS, aortic dissection, pulmonary embolism, tension pneumothorax.',
    'Life threats must be excluded first.', true),
   ('f1a00000-0000-0000-0000-000000000015', 'f1900000-0000-0000-0000-000000000005', 'STEP-02', 'Characterize the pain', 'assessment', 20,
    'Onset, radiation, pleuritic quality, associated symptoms.',
    'Characterization directs the differential.', true),
   ('f1a00000-0000-0000-0000-000000000016', 'f1900000-0000-0000-0000-000000000005', 'STEP-03', 'Investigate according to suspicion', 'investigation', 30,
    'Oxygenation, ECG and other investigations guided by suspicion.',
    'Testing answers the specific clinical question.', true)
ON CONFLICT (protocol_id, step_code) DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name,
                                       detail, urgency, sort_order) VALUES
   ('f1b00000-0000-0000-0000-000000000018', 'f1900000-0000-0000-0000-000000000005', 'f1a00000-0000-0000-0000-000000000016',
    'investigate', 'INV-SPO2', 'Pulse oximetry', 'Immediate oxygenation assessment', 'immediate', 10),
   ('f1b00000-0000-0000-0000-000000000019', 'f1900000-0000-0000-0000-000000000005', 'f1a00000-0000-0000-0000-000000000016',
    'investigate', 'INV-CXR', 'Chest X-ray', 'When respiratory cause suspected', 'routine', 20)
ON CONFLICT (step_id, action_type, action_code) DO NOTHING;

INSERT INTO knowledge.protocol_monitoring (protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES
   ('f1900000-0000-0000-0000-000000000004', 'f1700000-0000-0000-0000-000000000001', 'Serial during decongestion',
    'Worsening oxygenation', 'Immediate reassessment and escalation'),
   ('f1900000-0000-0000-0000-000000000004', 'f1700000-0000-0000-0000-000000000004', 'Serial during decongestion',
    'Worsening tachycardia / instability', 'Immediate reassessment and escalation'),
   ('f1900000-0000-0000-0000-000000000003', 'f1700000-0000-0000-0000-000000000001', 'Continuous in acute episode',
    'Falling SpO2', 'Urgent escalation'),
   ('f1900000-0000-0000-0000-000000000005', 'f1700000-0000-0000-0000-000000000001', 'Immediate and serial',
    'Worsening oxygenation', 'Urgent escalation')
ON CONFLICT (protocol_id, monitoring_id) DO NOTHING;
