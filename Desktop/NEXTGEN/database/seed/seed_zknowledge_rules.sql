-- =============================================================================
-- AMEXAN Phase 2 — Seed Z7: UNIVERSAL CLINICAL RULE ENGINE
-- =============================================================================
-- AMEXAN INTELLIGENCE
--
-- Purpose
-- -------
-- Universal, reusable, composable, versioned and provenance-aware clinical
-- rules shared across specialties and care settings.
--
-- ARCHITECTURAL PRINCIPLES
-- ------------------------
-- 1. Facts are the atomic clinical truth.
-- 2. Rules consume facts; they do not duplicate symptom definitions.
-- 3. Rules are reusable across diseases and specialties.
-- 4. Rules generate actions, not final diagnoses unless explicitly configured.
-- 5. Safety rules outrank diagnostic/convenience rules.
-- 6. Every clinically consequential rule has provenance.
-- 7. Rule versions are immutable once used clinically.
-- 8. Context modifies applicability; it does not duplicate the rule.
-- 9. A rule may activate:
--      - investigation
--      - management recommendation
--      - red flag
--      - phenotype
--      - priority
--      - question
--      - escalation
--      - referral
--      - monitoring
-- 10. The engine must be able to explain:
--       "WHY did AMEXAN produce this recommendation?"
--
-- NOTE
-- ----
-- Numeric thresholds below are intentionally represented as rule facts and
-- should be interpreted together with age, pregnancy, altitude, chronic disease,
-- care setting and local protocol context.
--
-- =============================================================================


-- =============================================================================
-- 1. UNIVERSAL SAFETY / RED-FLAG RULES
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000001',
 'RULE-UNIVERSAL-AIRWAY-COMPROMISE',
 'Airway compromise escalation',
 'Clinical evidence of threatened or compromised airway requires immediate airway assessment and emergency escalation.',
 'safety', 'active', 100,
 'A1', 'Emergency airway management principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000002',
 'RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',
 'Severe hypoxaemia escalation',
 'Markedly reduced oxygen saturation or clinical evidence of severe hypoxaemia requires immediate assessment and appropriate oxygenation support.',
 'safety', 'active', 100,
 'A1', 'Oxygen therapy and emergency care guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000003',
 'RULE-UNIVERSAL-RESPIRATORY-FAILURE',
 'Respiratory failure escalation',
 'Evidence of severe respiratory compromise requires urgent escalation and respiratory support assessment.',
 'safety', 'active', 100,
 'A1', 'Acute respiratory failure guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000004',
 'RULE-UNIVERSAL-SHOCK',
 'Shock recognition',
 'Clinical evidence of circulatory shock requires immediate resuscitation assessment and escalation.',
 'safety', 'active', 100,
 'A1', 'Emergency and critical care principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000005',
 'RULE-UNIVERSAL-ALTERED-CONSCIOUSNESS',
 'Altered consciousness escalation',
 'Acute reduction or alteration in consciousness requires urgent assessment for reversible and life-threatening causes.',
 'safety', 'active', 100,
 'A1', 'Emergency neurological assessment', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000006',
 'RULE-UNIVERSAL-SEIZURE',
 'Active seizure escalation',
 'A prolonged or ongoing convulsive seizure requires immediate emergency management.',
 'safety', 'active', 100,
 'A1', 'Status epilepticus guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000007',
 'RULE-UNIVERSAL-HYPOGLYCAEMIA',
 'Hypoglycaemia emergency',
 'Low blood glucose with compatible clinical findings requires immediate recognition and treatment according to patient context.',
 'safety', 'active', 100,
 'A1', 'Hypoglycaemia management guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000008',
 'RULE-UNIVERSAL-SEVERE-HYPERGLYCAEMIA',
 'Severe hyperglycaemia assessment',
 'Marked hyperglycaemia with compatible clinical or metabolic features requires urgent assessment for acute metabolic decompensation.',
 'safety', 'active', 95,
 'A1', 'Diabetes emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000009',
 'RULE-UNIVERSAL-ANAPHYLAXIS',
 'Anaphylaxis emergency',
 'Rapid multisystem allergic features with airway, breathing or circulation compromise require immediate emergency management.',
 'safety', 'active', 100,
 'A1', 'Anaphylaxis emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000000a',
 'RULE-UNIVERSAL-ACS',
 'Acute coronary syndrome pathway',
 'Compatible acute chest pain or equivalent ischaemic presentation requires urgent assessment for acute coronary syndrome.',
 'safety', 'active', 100,
 'A1', 'Acute coronary syndrome guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000000b',
 'RULE-UNIVERSAL-STROKE',
 'Acute stroke pathway',
 'Sudden focal neurological deficit requires immediate stroke assessment.',
 'safety', 'active', 100,
 'A1', 'Acute stroke guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000000c',
 'RULE-UNIVERSAL-MENINGITIS',
 'Suspected meningitis escalation',
 'Compatible acute neurological and systemic features require urgent assessment for meningitis or other CNS infection.',
 'safety', 'active', 100,
 'A1', 'Meningitis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000000d',
 'RULE-UNIVERSAL-GI-BLEED',
 'Gastrointestinal bleeding escalation',
 'Evidence of significant gastrointestinal bleeding requires urgent assessment and haemodynamic evaluation.',
 'safety', 'active', 95,
 'A1', 'Gastrointestinal bleeding guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000000e',
 'RULE-UNIVERSAL-SEPSIS',
 'Suspected sepsis escalation',
 'Suspected infection with physiological evidence of organ dysfunction or severe systemic illness requires urgent sepsis assessment.',
 'safety', 'active', 100,
 'A1', 'Sepsis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000000f',
 'RULE-UNIVERSAL-AKI',
 'Acute kidney injury recognition',
 'A significant acute deterioration in renal function requires assessment for reversible causes, complications and medication-related harm.',
 'clinical', 'active', 90,
 'A1', 'Acute kidney injury guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000010',
 'RULE-UNIVERSAL-HYPERKALAEMIA',
 'Hyperkalaemia escalation',
 'Significant hyperkalaemia requires urgent confirmation, ECG assessment and treatment according to severity.',
 'safety', 'active', 100,
 'A1', 'Hyperkalaemia emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000011',
 'RULE-UNIVERSAL-SEVERE-ANAEMIA',
 'Severe anaemia assessment',
 'Marked anaemia requires assessment for symptoms, haemodynamic impact, bleeding and underlying cause.',
 'clinical', 'active', 90,
 'A1', 'Anaemia management guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000012',
 'RULE-UNIVERSAL-FEVER',
 'Fever clinical assessment',
 'Fever requires evaluation according to age, duration, associated symptoms, epidemiological exposure and physiological severity.',
 'clinical', 'active', 70,
 'A1', 'Fever evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000013',
 'RULE-UNIVERSAL-PERSISTENT-FEVER',
 'Persistent fever evaluation',
 'Persistent or recurrent fever requires evaluation for infectious, inflammatory, malignant and other systemic causes.',
 'clinical', 'active', 80,
 'A1', 'Fever of unknown origin principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000014',
 'RULE-UNIVERSAL-WEIGHT-LOSS',
 'Unintentional weight loss evaluation',
 'Unintentional clinically significant weight loss requires evaluation for malignant, infectious, gastrointestinal, endocrine, psychiatric and systemic causes.',
 'clinical', 'active', 75,
 'B1', 'Internal medicine diagnostic principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000015',
 'RULE-UNIVERSAL-ELECTROLYTE-DERANGEMENT',
 'Significant electrolyte disturbance',
 'Clinically significant electrolyte abnormalities require assessment for symptoms, ECG risk, underlying cause and treatment urgency.',
 'safety', 'active', 90,
 'A1', 'Electrolyte management guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000016',
 'RULE-UNIVERSAL-CHEST-PAIN',
 'Chest pain assessment',
 'Acute chest pain requires structured assessment for immediately life-threatening cardiovascular, respiratory and gastrointestinal causes.',
 'safety', 'active', 95,
 'A1', 'Acute chest pain assessment principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000017',
 'RULE-UNIVERSAL-SYNCOPE',
 'Syncope evaluation',
 'Transient loss of consciousness requires assessment for cardiac, neurological, orthostatic and other causes, with identification of high-risk features.',
 'clinical', 'active', 85,
 'A1', 'Syncope evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000018',
 'RULE-UNIVERSAL-ACUTE-DYSPNOEA',
 'Acute dyspnoea pathway',
 'Acute dyspnoea requires immediate assessment for respiratory, cardiovascular, thromboembolic, metabolic and other life-threatening causes.',
 'safety', 'active', 95,
 'A1', 'Acute dyspnoea assessment principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000019',
 'RULE-UNIVERSAL-HAEMOPTYSIS',
 'Haemoptysis assessment',
 'Haemoptysis requires assessment of severity, airway stability and potential infectious, vascular, malignant and structural causes.',
 'clinical', 'active', 90,
 'A1', 'Haemoptysis evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-00000000001a',
 'RULE-UNIVERSAL-OLIGURIA',
 'Oliguria assessment',
 'Marked reduction in urine output requires assessment for hypovolaemia, obstruction, renal injury and systemic illness.',
 'clinical', 'active', 90,
 'A1', 'Acute kidney injury guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. RESPIRATORY MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000101',
 'RULE-PNEUMONIA-ASSESS',
 'Suspected pneumonia assessment',
 'An acute respiratory syndrome with cough, fever and compatible lower respiratory features should trigger assessment for pneumonia.',
 'clinical', 'active', 80,
 'A1', 'Community acquired pneumonia guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000102',
 'RULE-TB-SCREEN',
 'TB screening in prolonged cough',
 'Prolonged cough with compatible constitutional or epidemiological features should trigger assessment for tuberculosis.',
 'clinical', 'active', 90,
 'A1', 'WHO tuberculosis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000103',
 'RULE-TB-CONTACT',
 'TB contact with symptoms',
 'Respiratory symptoms in a person with known TB exposure require TB assessment.',
 'clinical', 'active', 90,
 'A1', 'WHO tuberculosis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000104',
 'RULE-ASTHMA-EXACERBATION',
 'Asthma exacerbation assessment',
 'Acute worsening of wheeze, cough or breathlessness in a patient with asthma requires assessment of exacerbation severity.',
 'clinical', 'active', 90,
 'A1', 'Asthma management guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000105',
 'RULE-COPD-EXACERBATION',
 'COPD exacerbation assessment',
 'Acute worsening of respiratory symptoms in a patient with COPD requires assessment for exacerbation and alternative causes.',
 'clinical', 'active', 85,
 'A1', 'COPD management guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000106',
 'RULE-PULMONARY-EMBOLISM',
 'Pulmonary embolism assessment',
 'Acute unexplained dyspnoea, pleuritic chest pain, haemoptysis or compatible thromboembolic risk should trigger PE risk assessment.',
 'safety', 'active', 95,
 'A1', 'Venous thromboembolism guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000107',
 'RULE-PNEUMOTHORAX',
 'Pneumothorax assessment',
 'Sudden unilateral pleuritic chest pain and dyspnoea should trigger assessment for pneumothorax.',
 'safety', 'active', 95,
 'A1', 'Acute respiratory guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000108',
 'RULE-PLEURAL-EFFUSION',
 'Pleural effusion assessment',
 'Clinical or imaging evidence suggesting pleural fluid requires evaluation of the underlying cause.',
 'clinical', 'active', 70,
 'B1', 'Pleural disease guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. CARDIOVASCULAR MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000201',
 'RULE-HEART-FAILURE',
 'Possible heart failure assessment',
 'Compatible dyspnoea, orthopnoea, oedema or other congestion features require assessment for heart failure and alternative causes.',
 'clinical', 'active', 85,
 'A1', 'Heart failure guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000202',
 'RULE-ACS',
 'Acute coronary syndrome assessment',
 'Compatible acute ischaemic symptoms require urgent ECG and cardiac assessment.',
 'safety', 'active', 100,
 'A1', 'Acute coronary syndrome guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000203',
 'RULE-ARRHYTHMIA',
 'Symptomatic arrhythmia assessment',
 'Palpitations, syncope or haemodynamic instability with suspected arrhythmia requires ECG assessment.',
 'clinical', 'active', 90,
 'A1', 'Arrhythmia assessment guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000204',
 'RULE-HYPERTENSIVE-EMERGENCY',
 'Severe hypertension with acute organ injury',
 'Marked hypertension accompanied by evidence of acute target-organ injury requires emergency assessment.',
 'safety', 'active', 100,
 'A1', 'Hypertensive emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000205',
 'RULE-SYNCOPE-CARDIAC',
 'High-risk syncope assessment',
 'Syncope associated with exertion, chest pain, abnormal ECG or suspected structural heart disease requires urgent cardiac assessment.',
 'safety', 'active', 95,
 'A1', 'Syncope guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. NEUROLOGICAL MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000301',
 'RULE-STROKE',
 'Acute focal neurological deficit',
 'Sudden focal neurological deficit requires immediate stroke pathway activation.',
 'safety', 'active', 100,
 'A1', 'Acute stroke guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000302',
 'RULE-TIA',
 'Transient focal neurological deficit',
 'Transient focal neurological symptoms require urgent assessment for TIA and stroke risk.',
 'safety', 'active', 95,
 'A1', 'TIA guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000303',
 'RULE-MENINGITIS',
 'Suspected meningitis',
 'Fever with compatible neurological or meningeal features requires urgent assessment for meningitis.',
 'safety', 'active', 100,
 'A1', 'Meningitis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000304',
 'RULE-ENCEPHALITIS',
 'Suspected encephalitis',
 'Altered mental state with fever and neurological features requires urgent assessment for encephalitis.',
 'safety', 'active', 100,
 'A1', 'Encephalitis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000305',
 'RULE-SEIZURE',
 'First or unexplained seizure',
 'A first seizure or unexplained seizure-like event requires neurological assessment and identification of reversible causes.',
 'clinical', 'active', 90,
 'A1', 'Seizure evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000306',
 'RULE-DELIRIUM',
 'Acute delirium assessment',
 'Acute fluctuating disturbance in attention or cognition requires assessment for underlying systemic, neurological and medication-related causes.',
 'clinical', 'active', 90,
 'A1', 'Delirium guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. ENDOCRINE / METABOLIC MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000401',
 'RULE-HYPOGLYCAEMIA',
 'Hypoglycaemia emergency',
 'Low blood glucose requires immediate assessment and correction according to consciousness, oral intake and clinical context.',
 'safety', 'active', 100,
 'A1', 'Diabetes emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000402',
 'RULE-DKA',
 'Diabetic ketoacidosis assessment',
 'Diabetes or hyperglycaemia with compatible metabolic features requires assessment for diabetic ketoacidosis.',
 'safety', 'active', 100,
 'A1', 'Diabetes emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000403',
 'RULE-HHS',
 'Hyperosmolar hyperglycaemic state assessment',
 'Severe hyperglycaemia with dehydration or altered mental status requires assessment for hyperosmolar hyperglycaemic state.',
 'safety', 'active', 100,
 'A1', 'Diabetes emergency guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000404',
 'RULE-THYROTOXICOSIS',
 'Thyrotoxicosis assessment',
 'Clinical features compatible with thyroid hormone excess require assessment for thyrotoxicosis and severity.',
 'clinical', 'active', 75,
 'A1', 'Thyroid disease guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000405',
 'RULE-ADRENAL-CRISIS',
 'Adrenal crisis assessment',
 'Compatible hypotension, electrolyte disturbance, hypoglycaemia or systemic illness in a susceptible patient requires urgent assessment for adrenal crisis.',
 'safety', 'active', 100,
 'A1', 'Adrenal insufficiency guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. RENAL / ELECTROLYTE MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000501',
 'RULE-AKI',
 'Acute kidney injury',
 'Acute deterioration in kidney function requires assessment of volume status, obstruction, nephrotoxins and intrinsic renal disease.',
 'clinical', 'active', 90,
 'A1', 'Acute kidney injury guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000502',
 'RULE-HYPERKALAEMIA',
 'Hyperkalaemia emergency',
 'Significant hyperkalaemia requires urgent ECG assessment and treatment according to severity and clinical context.',
 'safety', 'active', 100,
 'A1', 'Hyperkalaemia guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000503',
 'RULE-HYPONATRAEMIA',
 'Hyponatraemia assessment',
 'Significant hyponatraemia requires assessment of symptoms, chronicity, volume status and underlying cause.',
 'clinical', 'active', 90,
 'A1', 'Hyponatraemia guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000504',
 'RULE-HYPERNAATRAEMIA',
 'Hypernatraemia assessment',
 'Significant hypernatraemia requires assessment of water deficit, neurological status and underlying cause.',
 'clinical', 'active', 90,
 'A1', 'Hypernatraemia guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000505',
 'RULE-OLIGURIA',
 'Oliguria assessment',
 'Reduced urine output requires assessment for hypovolaemia, obstruction, renal injury and systemic illness.',
 'clinical', 'active', 90,
 'A1', 'Acute kidney injury guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. HAEMATOLOGY
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000601',
 'RULE-ANAEMIA',
 'Anaemia evaluation',
 'Anaemia requires classification and investigation according to severity, indices, bleeding history, nutritional status and systemic disease.',
 'clinical', 'active', 75,
 'A1', 'Anaemia evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000602',
 'RULE-ACUTE-BLEEDING',
 'Acute bleeding assessment',
 'Evidence of acute blood loss requires assessment of haemodynamic stability and bleeding source.',
 'safety', 'active', 100,
 'A1', 'Major haemorrhage principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000603',
 'RULE-THROMBOCYTOPENIA',
 'Significant thrombocytopenia',
 'Marked thrombocytopenia requires assessment for bleeding risk, medications, infection, immune disease and marrow pathology.',
 'clinical', 'active', 85,
 'A1', 'Haematology guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000604',
 'RULE-VTE',
 'Venous thromboembolism assessment',
 'Symptoms compatible with DVT or PE require structured thromboembolic risk assessment.',
 'safety', 'active', 95,
 'A1', 'Venous thromboembolism guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. GASTROINTESTINAL / HEPATOBILIARY MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000701',
 'RULE-GI-BLEED',
 'Gastrointestinal bleeding',
 'Haematemesis, melaena or significant rectal bleeding requires urgent bleeding assessment.',
 'safety', 'active', 100,
 'A1', 'GI bleeding guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000702',
 'RULE-ACUTE-ABDOMEN',
 'Acute abdomen assessment',
 'Acute severe abdominal pain or peritoneal features require urgent assessment for surgical and medical causes.',
 'safety', 'active', 95,
 'A1', 'Acute abdomen principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000703',
 'RULE-JAUNDICE',
 'Jaundice evaluation',
 'Jaundice requires differentiation of prehepatic, hepatocellular and cholestatic causes.',
 'clinical', 'active', 80,
 'A1', 'Liver disease evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000704',
 'RULE-ACUTE-LIVER-INJURY',
 'Acute liver injury assessment',
 'Acute biochemical or clinical evidence of liver injury requires assessment for toxic, viral, autoimmune, vascular and obstructive causes.',
 'clinical', 'active', 90,
 'A1', 'Liver disease guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000705',
 'RULE-HEPATIC-ENCEPHALOPATHY',
 'Hepatic encephalopathy assessment',
 'Altered mental status in advanced liver disease requires assessment for hepatic encephalopathy and alternative precipitants.',
 'safety', 'active', 95,
 'A1', 'Cirrhosis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000706',
 'RULE-ASCITES',
 'Ascites assessment',
 'New or clinically significant ascites requires assessment for portal hypertension, malignancy, infection and other causes.',
 'clinical', 'active', 80,
 'A1', 'Cirrhosis and ascites guidance', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. INFECTIOUS DISEASE MEDICINE
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000801',
 'RULE-SEPSIS',
 'Suspected sepsis',
 'Suspected infection with evidence of acute organ dysfunction requires urgent sepsis assessment and treatment according to local protocol.',
 'safety', 'active', 100,
 'A1', 'Sepsis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000802',
 'RULE-FEVER-UNEXPLAINED',
 'Unexplained fever',
 'Fever without an established source requires structured infectious and non-infectious evaluation.',
 'clinical', 'active', 75,
 'A1', 'Fever evaluation guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000803',
 'RULE-TB',
 'Tuberculosis evaluation',
 'Prolonged respiratory or constitutional symptoms with compatible epidemiological risk require TB evaluation.',
 'clinical', 'active', 90,
 'A1', 'WHO tuberculosis guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000804',
 'RULE-MALARIA',
 'Malaria assessment in compatible exposure',
 'Fever in a patient with relevant malaria exposure requires malaria assessment according to local epidemiology and clinical severity.',
 'clinical', 'active', 90,
 'A1', 'WHO malaria guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000805',
 'RULE-IMMUNOCOMPROMISED-INFECTION',
 'Infection in immunocompromised patient',
 'Infection symptoms in an immunocompromised patient require consideration of atypical organisms, rapid progression and lower thresholds for investigation.',
 'safety', 'active', 90,
 'A1', 'Immunocompromised host infection principles', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. UNIVERSAL DIAGNOSTIC PATTERN RULES
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000901',
 'RULE-PERSISTENT-COUGH',
 'Persistent cough evaluation',
 'Persistent cough requires assessment according to duration, phenotype, exposures, medications, age and associated symptoms.',
 'clinical', 'active', 80,
 'A1', 'Chronic cough guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000902',
 'RULE-UNEXPLAINED-WEIGHT-LOSS',
 'Unexplained weight loss',
 'Clinically significant unexplained weight loss requires systematic assessment for malignancy, infection, endocrine, gastrointestinal and other systemic disease.',
 'clinical', 'active', 80,
 'B1', 'Internal medicine diagnostic principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000903',
 'RULE-PERIPHERAL-OEDEMA',
 'Peripheral oedema evaluation',
 'Peripheral oedema requires assessment for cardiac, renal, hepatic, venous, lymphatic and medication-related causes.',
 'clinical', 'active', 75,
 'A1', 'Internal medicine diagnostic principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000904',
 'RULE-PALPITATIONS',
 'Palpitations assessment',
 'Palpitations require assessment for arrhythmia, structural cardiac disease, endocrine causes, stimulants, medications and systemic illness.',
 'clinical', 'active', 80,
 'A1', 'Arrhythmia guidance', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000905',
 'RULE-FATIGUE',
 'Persistent fatigue evaluation',
 'Persistent unexplained fatigue requires assessment for anaemia, endocrine disease, infection, inflammatory disease, sleep disorders, medication effects and systemic illness.',
 'clinical', 'active', 70,
 'B1', 'Internal medicine diagnostic principles', 'approved'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. RULE VERSIONS
-- =============================================================================

INSERT INTO knowledge.rule_version
(id, rule_id, version, body, is_active, changed_by)

SELECT
    gen_random_uuid(),
    r.id,
    1,
    jsonb_build_object(
        'type', 'clinical_rule',
        'rule_code', r.rule_code,
        'version', 1,
        'architecture', 'AMEXAN-Universal-Clinical-Intelligence',
        'engine', 'AMEXAN-Clinical-Reasoning-Engine',
        'versioning_policy', 'immutable'
    ),
    true,
    NULL
FROM knowledge.rule r
WHERE r.rule_code IN (

    'RULE-UNIVERSAL-AIRWAY-COMPROMISE',
    'RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',
    'RULE-UNIVERSAL-RESPIRATORY-FAILURE',
    'RULE-UNIVERSAL-SHOCK',
    'RULE-UNIVERSAL-ALTERED-CONSCIOUSNESS',
    'RULE-UNIVERSAL-SEIZURE',
    'RULE-UNIVERSAL-HYPOGLYCAEMIA',
    'RULE-UNIVERSAL-SEVERE-HYPERGLYCAEMIA',
    'RULE-UNIVERSAL-ANAPHYLAXIS',
    'RULE-UNIVERSAL-ACS',
    'RULE-UNIVERSAL-STROKE',
    'RULE-UNIVERSAL-MENINGITIS',
    'RULE-UNIVERSAL-GI-BLEED',
    'RULE-UNIVERSAL-SEPSIS',
    'RULE-UNIVERSAL-AKI',
    'RULE-UNIVERSAL-HYPERKALAEMIA',
    'RULE-UNIVERSAL-SEVERE-ANAEMIA',
    'RULE-UNIVERSAL-FEVER',
    'RULE-UNIVERSAL-PERSISTENT-FEVER',
    'RULE-UNIVERSAL-WEIGHT-LOSS',
    'RULE-UNIVERSAL-ELECTROLYTE-DERANGEMENT',
    'RULE-UNIVERSAL-CHEST-PAIN',
    'RULE-UNIVERSAL-SYNCOPE',
    'RULE-UNIVERSAL-ACUTE-DYSPNOEA',
    'RULE-UNIVERSAL-HAEMOPTYSIS',
    'RULE-UNIVERSAL-OLIGURIA',

    'RULE-PNEUMONIA-ASSESS',
    'RULE-TB-SCREEN',
    'RULE-TB-CONTACT',
    'RULE-ASTHMA-EXACERBATION',
    'RULE-COPD-EXACERBATION',
    'RULE-PULMONARY-EMBOLISM',
    'RULE-PNEUMOTHORAX',
    'RULE-PLEURAL-EFFUSION',

    'RULE-HEART-FAILURE',
    'RULE-ACS',
    'RULE-ARRHYTHMIA',
    'RULE-HYPERTENSIVE-EMERGENCY',
    'RULE-SYNCOPE-CARDIAC',

    'RULE-STROKE',
    'RULE-TIA',
    'RULE-MENINGITIS',
    'RULE-ENCEPHALITIS',
    'RULE-SEIZURE',
    'RULE-DELIRIUM',

    'RULE-HYPOGLYCAEMIA',
    'RULE-DKA',
    'RULE-HHS',
    'RULE-THYROTOXICOSIS',
    'RULE-ADRENAL-CRISIS',

    'RULE-AKI',
    'RULE-HYPERKALAEMIA',
    'RULE-HYPONATRAEMIA',
    'RULE-HYPERNAATRAEMIA',
    'RULE-OLIGURIA',

    'RULE-ANAEMIA',
    'RULE-ACUTE-BLEEDING',
    'RULE-THROMBOCYTOPENIA',
    'RULE-VTE',

    'RULE-GI-BLEED',
    'RULE-ACUTE-ABDOMEN',
    'RULE-JAUNDICE',
    'RULE-ACUTE-LIVER-INJURY',
    'RULE-HEPATIC-ENCEPHALOPATHY',
    'RULE-ASCITES',

    'RULE-SEPSIS',
    'RULE-FEVER-UNEXPLAINED',
    'RULE-TB',
    'RULE-MALARIA',
    'RULE-IMMUNOCOMPROMISED-INFECTION',

    'RULE-PERSISTENT-COUGH',
    'RULE-UNEXPLAINED-WEIGHT-LOSS',
    'RULE-PERIPHERAL-OEDEMA',
    'RULE-PALPITATIONS',
    'RULE-FATIGUE'
)
AND NOT EXISTS (
    SELECT 1
    FROM knowledge.rule_version rv
    WHERE rv.rule_id = r.id
      AND rv.version = 1
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 12. UNIVERSAL SAFETY CONDITIONS
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    -- AIRWAY
    ('RULE-UNIVERSAL-AIRWAY-COMPROMISE',1,1,'fact','AIRWAY_COMPROMISE','eq','"YES"'),

    -- HYPOXAEMIA
    ('RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',1,1,'measurement','SPO2','lt','90'),

    -- RESPIRATORY FAILURE
    ('RULE-UNIVERSAL-RESPIRATORY-FAILURE',1,1,'fact','RESPIRATORY_FAILURE','eq','"YES"'),

    -- SHOCK
    ('RULE-UNIVERSAL-SHOCK',1,1,'fact','SHOCK_PRESENT','eq','"YES"'),

    -- ALTERED CONSCIOUSNESS
    ('RULE-UNIVERSAL-ALTERED-CONSCIOUSNESS',1,1,'fact','ALTERED_CONSCIOUSNESS','eq','"YES"'),

    -- ACTIVE SEIZURE
    ('RULE-UNIVERSAL-SEIZURE',1,1,'fact','ACTIVE_SEIZURE','eq','"YES"'),

    -- HYPOGLYCAEMIA
    ('RULE-UNIVERSAL-HYPOGLYCAEMIA',1,1,'measurement','BLOOD_GLUCOSE','lt','70'),

    -- ANAPHYLAXIS
    ('RULE-UNIVERSAL-ANAPHYLAXIS',1,1,'fact','ANAPHYLAXIS_FEATURES','eq','"YES"'),

    -- ACS
    ('RULE-UNIVERSAL-ACS',1,1,'fact','ACUTE_ISCHAEMIC_CHEST_PAIN','eq','"YES"'),

    -- STROKE
    ('RULE-UNIVERSAL-STROKE',1,1,'fact','SUDDEN_FOCAL_NEUROLOGICAL_DEFICIT','eq','"YES"'),

    -- MENINGITIS
    ('RULE-UNIVERSAL-MENINGITIS',1,1,'fact','MENINGEAL_FEATURES','eq','"YES"'),
    ('RULE-UNIVERSAL-MENINGITIS',1,2,'fact','FEVER_PRESENT','eq','"YES"'),

    -- GI BLEED
    ('RULE-UNIVERSAL-GI-BLEED',1,1,'fact','GI_BLEEDING','eq','"YES"'),

    -- SEPSIS
    ('RULE-UNIVERSAL-SEPSIS',1,1,'fact','SUSPECTED_INFECTION','eq','"YES"'),
    ('RULE-UNIVERSAL-SEPSIS',1,2,'fact','ORGAN_DYSFUNCTION','eq','"YES"'),

    -- AKI
    ('RULE-UNIVERSAL-AKI',1,1,'fact','AKI_PRESENT','eq','"YES"'),

    -- HYPERKALAEMIA
    ('RULE-UNIVERSAL-HYPERKALAEMIA',1,1,'measurement','POTASSIUM','gte','6.0'),

    -- ANAEMIA
    ('RULE-UNIVERSAL-SEVERE-ANAEMIA',1,1,'fact','SEVERE_ANAEMIA','eq','"YES"'),

    -- CHEST PAIN
    ('RULE-UNIVERSAL-CHEST-PAIN',1,1,'fact','CHEST_PAIN_PRESENT','eq','"YES"'),

    -- SYNCOPE
    ('RULE-UNIVERSAL-SYNCOPE',1,1,'fact','SYNCOPE_PRESENT','eq','"YES"'),

    -- ACUTE DYSPNOEA
    ('RULE-UNIVERSAL-ACUTE-DYSPNOEA',1,1,'fact','DYSPNOEA_PRESENT','eq','"YES"'),
    ('RULE-UNIVERSAL-ACUTE-DYSPNOEA',1,2,'fact','ACUTE_ONSET','eq','"YES"'),

    -- HAEMOPTYSIS
    ('RULE-UNIVERSAL-HAEMOPTYSIS',1,1,'fact','BLOOD_IN_SPUTUM','eq','"YES"'),

    -- OLIGURIA
    ('RULE-UNIVERSAL-OLIGURIA',1,1,'fact','OLIGURIA_PRESENT','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. RESPIRATORY CONDITIONS
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    -- PNEUMONIA
    ('RULE-PNEUMONIA-ASSESS',1,1,'fact','COUGH_PRESENT','eq','"YES"'),
    ('RULE-PNEUMONIA-ASSESS',1,2,'fact','FEVER_PRESENT','eq','"YES"'),

    -- TB
    ('RULE-TB-SCREEN',1,1,'fact','COUGH_DURATION_DAYS','gt','14'),
    ('RULE-TB-SCREEN',1,2,'fact','WEIGHT_LOSS','eq','"YES"'),
    ('RULE-TB-SCREEN',2,1,'fact','COUGH_DURATION_DAYS','gt','14'),
    ('RULE-TB-SCREEN',2,2,'fact','NIGHT_SWEATS','eq','"YES"'),
    ('RULE-TB-SCREEN',3,1,'fact','COUGH_DURATION_DAYS','gt','14'),
    ('RULE-TB-SCREEN',3,2,'fact','TB_CONTACT','eq','"YES"'),

    -- TB CONTACT
    ('RULE-TB-CONTACT',1,1,'fact','TB_CONTACT','eq','"YES"'),
    ('RULE-TB-CONTACT',1,2,'fact','COUGH_PRESENT','eq','"YES"'),

    -- ASTHMA
    ('RULE-ASTHMA-EXACERBATION',1,1,'fact','ASTHMA_HISTORY','eq','"YES"'),
    ('RULE-ASTHMA-EXACERBATION',1,2,'fact','WHEEZE_PRESENT','eq','"YES"'),

    -- COPD
    ('RULE-COPD-EXACERBATION',1,1,'fact','COPD_HISTORY','eq','"YES"'),
    ('RULE-COPD-EXACERBATION',1,2,'fact','DYSPNOEA_WORSE_THAN_BASELINE','eq','"YES"'),

    -- PE
    ('RULE-PULMONARY-EMBOLISM',1,1,'fact','ACUTE_DYSPNOEA','eq','"YES"'),
    ('RULE-PULMONARY-EMBOLISM',1,2,'fact','VTE_RISK_PRESENT','eq','"YES"'),

    -- PNEUMOTHORAX
    ('RULE-PNEUMOTHORAX',1,1,'fact','SUDDEN_DYSPNOEA','eq','"YES"'),
    ('RULE-PNEUMOTHORAX',1,2,'fact','PLEURITIC_CHEST_PAIN','eq','"YES"'),

    -- PLEURAL EFFUSION
    ('RULE-PLEURAL-EFFUSION',1,1,'fact','PLEURAL_EFFUSION_SUSPECTED','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 14. CARDIOVASCULAR CONDITIONS
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-HEART-FAILURE',1,1,'fact','DYSPNOEA_PRESENT','eq','"YES"'),
    ('RULE-HEART-FAILURE',1,2,'fact','ORTHOPNOEA','eq','"YES"'),
    ('RULE-HEART-FAILURE',2,1,'fact','PERIPHERAL_OEDEMA','eq','"YES"'),

    ('RULE-ACS',1,1,'fact','CHEST_PAIN_PRESENT','eq','"YES"'),
    ('RULE-ACS',1,2,'fact','ISCHAEMIC_FEATURES','eq','"YES"'),

    ('RULE-ARRHYTHMIA',1,1,'fact','PALPITATIONS','eq','"YES"'),

    ('RULE-HYPERTENSIVE-EMERGENCY',1,1,'measurement','SBP','gte','180'),
    ('RULE-HYPERTENSIVE-EMERGENCY',1,2,'fact','ACUTE_TARGET_ORGAN_INJURY','eq','"YES"'),

    ('RULE-SYNCOPE-CARDIAC',1,1,'fact','SYNCOPE_PRESENT','eq','"YES"'),
    ('RULE-SYNCOPE-CARDIAC',1,2,'fact','ABNORMAL_ECG','eq','"YES"'),

    ('RULE-SYNCOPE-CARDIAC',2,1,'fact','SYNCOPE_PRESENT','eq','"YES"'),
    ('RULE-SYNCOPE-CARDIAC',2,2,'fact','EXERTIONAL_SYNCOPE','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 15. NEUROLOGICAL CONDITIONS
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-STROKE',1,1,'fact','SUDDEN_FOCAL_NEUROLOGICAL_DEFICIT','eq','"YES"'),

    ('RULE-TIA',1,1,'fact','TRANSIENT_FOCAL_NEUROLOGICAL_DEFICIT','eq','"YES"'),

    ('RULE-MENINGITIS',1,1,'fact','FEVER_PRESENT','eq','"YES"'),
    ('RULE-MENINGITIS',1,2,'fact','MENINGEAL_FEATURES','eq','"YES"'),

    ('RULE-ENCEPHALITIS',1,1,'fact','FEVER_PRESENT','eq','"YES"'),
    ('RULE-ENCEPHALITIS',1,2,'fact','ALTERED_CONSCIOUSNESS','eq','"YES"'),

    ('RULE-SEIZURE',1,1,'fact','SEIZURE_PRESENT','eq','"YES"'),

    ('RULE-DELIRIUM',1,1,'fact','ACUTE_CONFUSIONAL_STATE','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 16. ENDOCRINE / METABOLIC CONDITIONS
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-HYPOGLYCAEMIA',1,1,'measurement','BLOOD_GLUCOSE','lt','70'),

    ('RULE-DKA',1,1,'fact','DIABETES_PRESENT','eq','"YES"'),
    ('RULE-DKA',1,2,'fact','KETONES_PRESENT','eq','"YES"'),
    ('RULE-DKA',1,3,'fact','METABOLIC_ACIDOSIS','eq','"YES"'),

    ('RULE-HHS',1,1,'fact','DIABETES_PRESENT','eq','"YES"'),
    ('RULE-HHS',1,2,'fact','SEVERE_HYPERGLYCAEMIA','eq','"YES"'),
    ('RULE-HHS',1,3,'fact','DEHYDRATION','eq','"YES"'),

    ('RULE-THYROTOXICOSIS',1,1,'fact','THYROTOXICOSIS_FEATURES','eq','"YES"'),

    ('RULE-ADRENAL-CRISIS',1,1,'fact','ADRENAL_INSUFFICIENCY_RISK','eq','"YES"'),
    ('RULE-ADRENAL-CRISIS',1,2,'fact','SHOCK_PRESENT','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 17. RENAL / ELECTROLYTES
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-AKI',1,1,'fact','AKI_PRESENT','eq','"YES"'),

    ('RULE-HYPERKALAEMIA',1,1,'measurement','POTASSIUM','gte','6.0'),

    ('RULE-HYPONATRAEMIA',1,1,'measurement','SODIUM','lt','130'),

    ('RULE-HYPERNAATRAEMIA',1,1,'measurement','SODIUM','gt','150'),

    ('RULE-OLIGURIA',1,1,'fact','OLIGURIA_PRESENT','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 18. HAEMATOLOGY
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-ANAEMIA',1,1,'fact','ANAEMIA_PRESENT','eq','"YES"'),

    ('RULE-ACUTE-BLEEDING',1,1,'fact','ACTIVE_BLEEDING','eq','"YES"'),

    ('RULE-THROMBOCYTOPENIA',1,1,'measurement','PLATELETS','lt','50000'),

    ('RULE-VTE',1,1,'fact','VTE_FEATURES','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 19. GI / HEPATOBILIARY
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-GI-BLEED',1,1,'fact','GI_BLEEDING','eq','"YES"'),

    ('RULE-ACUTE-ABDOMEN',1,1,'fact','SEVERE_ABDOMINAL_PAIN','eq','"YES"'),
    ('RULE-ACUTE-ABDOMEN',1,2,'fact','PERITONEAL_FEATURES','eq','"YES"'),

    ('RULE-JAUNDICE',1,1,'fact','JAUNDICE_PRESENT','eq','"YES"'),

    ('RULE-ACUTE-LIVER-INJURY',1,1,'fact','ACUTE_LIVER_INJURY','eq','"YES"'),

    ('RULE-HEPATIC-ENCEPHALOPATHY',1,1,'fact','CIRRHOSIS_PRESENT','eq','"YES"'),
    ('RULE-HEPATIC-ENCEPHALOPATHY',1,2,'fact','ALTERED_CONSCIOUSNESS','eq','"YES"'),

    ('RULE-ASCITES',1,1,'fact','ASCITES_PRESENT','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 20. INFECTIOUS DISEASE
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-SEPSIS',1,1,'fact','SUSPECTED_INFECTION','eq','"YES"'),
    ('RULE-SEPSIS',1,2,'fact','ORGAN_DYSFUNCTION','eq','"YES"'),

    ('RULE-FEVER-UNEXPLAINED',1,1,'fact','FEVER_PRESENT','eq','"YES"'),
    ('RULE-FEVER-UNEXPLAINED',1,2,'fact','NO_SOURCE_IDENTIFIED','eq','"YES"'),

    ('RULE-TB',1,1,'fact','COUGH_DURATION_DAYS','gt','14'),

    ('RULE-MALARIA',1,1,'fact','FEVER_PRESENT','eq','"YES"'),
    ('RULE-MALARIA',1,2,'fact','MALARIA_EXPOSURE','eq','"YES"'),

    ('RULE-IMMUNOCOMPROMISED-INFECTION',1,1,'fact','IMMUNOCOMPROMISED','eq','"YES"'),
    ('RULE-IMMUNOCOMPROMISED-INFECTION',1,2,'fact','INFECTION_SUSPECTED','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 21. UNIVERSAL SYMPTOM RULES
-- =============================================================================

INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-PERSISTENT-COUGH',1,1,'fact','COUGH_PRESENT','eq','"YES"'),
    ('RULE-PERSISTENT-COUGH',1,2,'fact','COUGH_DURATION_DAYS','gt','21'),

    ('RULE-UNEXPLAINED-WEIGHT-LOSS',1,1,'fact','WEIGHT_LOSS','eq','"YES"'),

    ('RULE-PERIPHERAL-OEDEMA',1,1,'fact','PERIPHERAL_OEDEMA','eq','"YES"'),

    ('RULE-PALPITATIONS',1,1,'fact','PALPITATIONS','eq','"YES"'),

    ('RULE-FATIGUE',1,1,'fact','PERSISTENT_FATIGUE','eq','"YES"')

) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 22. UNIVERSAL RULE ACTIONS — SAFETY
-- =============================================================================

INSERT INTO knowledge.rule_action
(rule_id, action_order, action_type, action_entity_type, action_code, params)

SELECT
    r.id,
    x.action_order,
    x.action_type,
    x.action_entity_type,
    x.action_code,
    x.params
FROM knowledge.rule r
JOIN (
    VALUES

    (
      'RULE-UNIVERSAL-AIRWAY-COMPROMISE',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-AIRWAY-COMPROMISE',
      jsonb_build_object(
          'severity','critical',
          'rationale','Evidence of threatened or compromised airway'
      )
    ),

    (
      'RULE-UNIVERSAL-AIRWAY-COMPROMISE',
      2,
      'set_priority',
      'context',
      'emergency',
      jsonb_build_object(
          'reason','airway'
      )
    ),

    (
      'RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-SEVERE-HYPOXAEMIA',
      jsonb_build_object(
          'severity','critical',
          'rationale','Severe reduction in oxygen saturation'
      )
    ),

    (
      'RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',
      2,
      'recommend_management',
      'management',
      'OXYGEN_ASSESSMENT',
      jsonb_build_object(
          'rationale','Hypoxaemia requires immediate oxygenation assessment',
          'context_sensitive',true
      )
    ),

    (
      'RULE-UNIVERSAL-RESPIRATORY-FAILURE',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-RESPIRATORY-FAILURE',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-SHOCK',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-SHOCK',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-SHOCK',
      2,
      'set_priority',
      'context',
      'emergency',
      jsonb_build_object(
          'reason','circulatory_instability'
      )
    ),

    (
      'RULE-UNIVERSAL-ALTERED-CONSCIOUSNESS',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-ALTERED-CONSCIOUSNESS',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-SEIZURE',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-ACTIVE-SEIZURE',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-HYPOGLYCAEMIA',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-HYPOGLYCAEMIA',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-ANAPHYLAXIS',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-ANAPHYLAXIS',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-ACS',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-ACS',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-STROKE',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-ACUTE-STROKE',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-MENINGITIS',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-MENINGITIS',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-GI-BLEED',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-GI-BLEED',
      jsonb_build_object(
          'severity','high'
      )
    ),

    (
      'RULE-UNIVERSAL-SEPSIS',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-SEPSIS',
      jsonb_build_object(
          'severity','critical'
      )
    ),

    (
      'RULE-UNIVERSAL-HYPERKALAEMIA',
      1,
      'raise_red_flag',
      'red_flag',
      'RF-HYPERKALAEMIA',
      jsonb_build_object(
          'severity','critical'
      )
    )

) AS x(rule_code,action_order,action_type,action_entity_type,action_code,params)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 23. INVESTIGATION ACTIONS
-- =============================================================================

INSERT INTO knowledge.rule_action
(rule_id, action_order, action_type, action_entity_type, action_code, params)

SELECT
    r.id,
    x.action_order,
    x.action_type,
    x.action_entity_type,
    x.action_code,
    x.params
FROM knowledge.rule r
JOIN (
    VALUES

    (
      'RULE-PNEUMONIA-ASSESS',
      1,
      'recommend_investigation',
      'investigation',
      'ASSESS-PNEUMONIA',
      jsonb_build_object(
          'rationale','Acute respiratory syndrome compatible with lower respiratory infection'
      )
    ),

    (
      'RULE-TB-SCREEN',
      1,
      'recommend_investigation',
      'investigation',
      'TB-DIAGNOSTIC-ASSESSMENT',
      jsonb_build_object(
          'rationale','Prolonged cough with compatible TB features',
          'context_sensitive',true
      )
    ),

    (
      'RULE-TB-CONTACT',
      1,
      'recommend_investigation',
      'investigation',
      'TB-DIAGNOSTIC-ASSESSMENT',
      jsonb_build_object(
          'rationale','TB exposure with respiratory symptoms'
      )
    ),

    (
      'RULE-ACS',
      1,
      'recommend_investigation',
      'investigation',
      'ECG',
      jsonb_build_object(
          'rationale','Possible acute coronary syndrome'
      )
    ),

    (
      'RULE-ARRHYTHMIA',
      1,
      'recommend_investigation',
      'investigation',
      'ECG',
      jsonb_build_object(
          'rationale','Palpitations require rhythm assessment'
      )
    ),

    (
      'RULE-STROKE',
      1,
      'recommend_investigation',
      'investigation',
      'ACUTE-STROKE-ASSESSMENT',
      jsonb_build_object(
          'rationale','Sudden focal neurological deficit'
      )
    ),

    (
      'RULE-AKI',
      1,
      'recommend_investigation',
      'investigation',
      'AKI-ASSESSMENT',
      jsonb_build_object(
          'rationale','Acute deterioration in renal function'
      )
    ),

    (
      'RULE-HYPERKALAEMIA',
      1,
      'recommend_investigation',
      'investigation',
      'ECG',
      jsonb_build_object(
          'rationale','Significant hyperkalaemia may cause life-threatening arrhythmia'
      )
    ),

    (
      'RULE-GI-BLEED',
      1,
      'recommend_investigation',
      'investigation',
      'GI-BLEED-ASSESSMENT',
      jsonb_build_object(
          'rationale','Evidence of gastrointestinal bleeding'
      )
    )

) AS x(rule_code,action_order,action_type,action_entity_type,action_code,params)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 24. PHENOTYPE ACTIVATION
-- =============================================================================

INSERT INTO knowledge.rule_action
(rule_id, action_order, action_type, action_entity_type, action_code, params)

SELECT
    r.id,
    x.action_order,
    'activate_phenotype',
    'phenotype',
    x.action_code,
    x.params
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-PNEUMONIA-ASSESS',1,'PHEN-ACUTE-LRTI',
     jsonb_build_object('reason','acute_lower_respiratory_syndrome')),

    ('RULE-TB-SCREEN',1,'PHEN-CHRONIC-PRODUCTIVE',
     jsonb_build_object('reason','prolonged_productive_cough')),

    ('RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',1,'PHEN-HYPOXAEMIA',
     jsonb_build_object('reason','low_oxygen_saturation')),

    ('RULE-UNIVERSAL-RESPIRATORY-FAILURE',1,'PHEN-RESPIRATORY-FAILURE',
     jsonb_build_object('reason','respiratory_failure')),

    ('RULE-SEPSIS',1,'PHEN-SYSTEMIC-INFECTION',
     jsonb_build_object('reason','infection_with_organ_dysfunction')),

    ('RULE-HEART-FAILURE',1,'PHEN-CONGESTIVE-SYNDROME',
     jsonb_build_object('reason','congestion_features')),

    ('RULE-AKI',1,'PHEN-ACUTE-KIDNEY-INJURY',
     jsonb_build_object('reason','acute_renal_dysfunction'))

) AS x(rule_code,action_order,action_code,params)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 25. RULE CONTEXT
-- =============================================================================
-- Neonates require different thresholds/pathways.
-- Rules are therefore not duplicated; context controls applicability.
-- =============================================================================

INSERT INTO knowledge.rule_context
(rule_id, context_type_code, context_value_id, applicability)

SELECT
    r.id,
    x.context_type_code,
    cv.id,
    x.applicability
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-TB-SCREEN','AGE','0-28D','excludes'),
    ('RULE-TB-CONTACT','AGE','0-28D','excludes'),

    ('RULE-MALARIA','AGE','0-28D','excludes'),

    ('RULE-DKA','AGE','0-28D','excludes'),

    ('RULE-HYPERTENSIVE-EMERGENCY','AGE','0-28D','excludes'),

    ('RULE-COPD-EXACERBATION','AGE','0-28D','excludes'),
    ('RULE-COPD-EXACERBATION','AGE','1-11M','excludes'),
    ('RULE-COPD-EXACERBATION','AGE','1-4Y','excludes'),
    ('RULE-COPD-EXACERBATION','AGE','5-17Y','excludes'),

    ('RULE-IMMUNOCOMPROMISED-INFECTION',
     'IMMUNOCOMPROMISED_STATUS','immunocompromised','applies'),

    ('RULE-TB','IMMUNOCOMPROMISED_STATUS','immunocompromised','applies')

) AS x(rule_code,context_type_code,context_value,applicability)
ON r.rule_code = x.rule_code
JOIN knowledge.context_value cv
  ON cv.context_type_code = x.context_type_code
 AND cv.value = x.context_value

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 26. RULE SOURCES / PROVENANCE
-- =============================================================================

INSERT INTO knowledge.rule_source
(rule_id, source_type, source_ref, citation, evidence_level)

SELECT
    r.id,
    x.source_type,
    x.source_ref,
    x.citation,
    x.evidence_level
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-SEPSIS',
     'guideline',
     'Sepsis guidance',
     'International evidence-based sepsis guidance; exact implementation should follow current local protocol.',
     'A1'),

    ('RULE-TB-SCREEN',
     'guideline',
     'WHO TB guidance',
     'WHO tuberculosis screening and diagnostic guidance.',
     'A1'),

    ('RULE-TB-CONTACT',
     'guideline',
     'WHO TB guidance',
     'WHO tuberculosis contact and diagnostic guidance.',
     'A1'),

    ('RULE-PNEUMONIA-ASSESS',
     'guideline',
     'Community acquired pneumonia guidance',
     'Evidence-based assessment of community acquired pneumonia.',
     'A1'),

    ('RULE-ACS',
     'guideline',
     'Acute coronary syndrome guidance',
     'Evidence-based acute coronary syndrome assessment guidance.',
     'A1'),

    ('RULE-STROKE',
     'guideline',
     'Acute stroke guidance',
     'Evidence-based acute stroke pathway guidance.',
     'A1'),

    ('RULE-MENINGITIS',
     'guideline',
     'Meningitis guidance',
     'Evidence-based meningitis diagnostic and emergency management guidance.',
     'A1'),

    ('RULE-AKI',
     'guideline',
     'Acute kidney injury guidance',
     'Evidence-based acute kidney injury guidance.',
     'A1'),

    ('RULE-HYPERKALAEMIA',
     'guideline',
     'Hyperkalaemia guidance',
     'Evidence-based emergency electrolyte management guidance.',
     'A1'),

    ('RULE-DKA',
     'guideline',
     'Diabetes emergency guidance',
     'Evidence-based diabetic ketoacidosis guidance.',
     'A1'),

    ('RULE-GI-BLEED',
     'guideline',
     'GI bleeding guidance',
     'Evidence-based gastrointestinal bleeding assessment guidance.',
     'A1'),

    ('RULE-HEART-FAILURE',
     'guideline',
     'Heart failure guidance',
     'Evidence-based heart failure diagnostic guidance.',
     'A1'),

    ('RULE-PULMONARY-EMBOLISM',
     'guideline',
     'Venous thromboembolism guidance',
     'Evidence-based venous thromboembolism diagnostic pathway.',
     'A1'),

    ('RULE-MALARIA',
     'guideline',
     'WHO malaria guidance',
     'WHO malaria diagnosis and management guidance.',
     'A1'),

    ('RULE-ANAEMIA',
     'guideline',
     'Anaemia evaluation guidance',
     'Evidence-based evaluation of anaemia.',
     'A1'),

    ('RULE-UNEXPLAINED-WEIGHT-LOSS',
     'expert',
     'Internal medicine diagnostic principles',
     'Systematic diagnostic approach to unexplained weight loss.',
     'B1')

) AS x(rule_code,source_type,source_ref,citation,evidence_level)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 27. RULE PRIORITY
-- =============================================================================
-- Priority is deliberately separated from rule priority in the rule table.
-- This lets AMEXAN change execution precedence without rewriting the rule.
-- =============================================================================

INSERT INTO knowledge.rule_priority
(rule_id, priority_score, basis, description)

SELECT
    r.id,
    x.priority_score,
    x.basis,
    x.description
FROM knowledge.rule r
JOIN (
    VALUES

    ('RULE-UNIVERSAL-AIRWAY-COMPROMISE',100,'safety',
     'Immediate threat to airway'),

    ('RULE-UNIVERSAL-SEVERE-HYPOXAEMIA',100,'safety',
     'Immediate threat from severe hypoxaemia'),

    ('RULE-UNIVERSAL-RESPIRATORY-FAILURE',100,'safety',
     'Potential respiratory failure'),

    ('RULE-UNIVERSAL-SHOCK',100,'safety',
     'Circulatory instability'),

    ('RULE-UNIVERSAL-ALTERED-CONSCIOUSNESS',100,'safety',
     'Acute neurological or systemic emergency'),

    ('RULE-UNIVERSAL-SEIZURE',100,'safety',
     'Active seizure emergency'),

    ('RULE-UNIVERSAL-HYPOGLYCAEMIA',100,'safety',
     'Potential immediate neurological injury'),

    ('RULE-UNIVERSAL-ANAPHYLAXIS',100,'safety',
     'Potential rapid airway/circulatory collapse'),

    ('RULE-UNIVERSAL-ACS',100,'safety',
     'Potential acute coronary syndrome'),

    ('RULE-UNIVERSAL-STROKE',100,'safety',
     'Time-critical neurological emergency'),

    ('RULE-UNIVERSAL-MENINGITIS',100,'safety',
     'Potential CNS infection'),

    ('RULE-UNIVERSAL-SEPSIS',100,'safety',
     'Potential infection-associated organ dysfunction'),

    ('RULE-UNIVERSAL-HYPERKALAEMIA',100,'safety',
     'Potential fatal cardiac arrhythmia'),

    ('RULE-UNIVERSAL-GI-BLEED',95,'safety',
     'Potential major haemorrhage'),

    ('RULE-UNIVERSAL-CHEST-PAIN',95,'safety',
     'Potential life-threatening thoracic disease'),

    ('RULE-UNIVERSAL-ACUTE-DYSPNOEA',95,'safety',
     'Potential life-threatening respiratory/cardiovascular disease'),

    ('RULE-TB-SCREEN',90,'diagnostic',
     'Potential transmissible chronic infection'),

    ('RULE-PULMONARY-EMBOLISM',95,'safety',
     'Potential life-threatening thromboembolic disease'),

    ('RULE-PNEUMOTHORAX',95,'safety',
     'Potential acute pleural emergency'),

    ('RULE-AKI',90,'clinical',
     'Potential progressive renal injury'),

    ('RULE-HEART-FAILURE',85,'clinical',
     'Potential decompensated cardiovascular disease'),

    ('RULE-ANAEMIA',75,'clinical',
     'Requires classification and cause assessment'),

    ('RULE-PERSISTENT-COUGH',80,'diagnostic',
     'Persistent symptom requiring structured evaluation'),

    ('RULE-UNEXPLAINED-WEIGHT-LOSS',80,'diagnostic',
     'Potential malignancy, infection or systemic disease'),

    ('RULE-FATIGUE',70,'diagnostic',
     'Broad systemic differential')

) AS x(rule_code,priority_score,basis,description)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 28. UNIVERSAL RULE — MEDICATION SAFETY
-- =============================================================================
-- Medication decisions should NEVER be hard-coded blindly into a universal
-- rule. Instead the rule engine detects a safety state and hands the case to
-- the medication intelligence layer.
-- =============================================================================

INSERT INTO knowledge.rule
(id, rule_code, name, description, rule_type, status, priority,
 evidence_level, guideline, approval_status)
VALUES

(
 'f1100000-0000-0000-0000-000000000a01',
 'RULE-MED-ALLERGY',
 'Medication allergy safety check',
 'A documented medication allergy must be considered before medication recommendation.',
 'safety', 'active', 100,
 'A1', 'Medication safety principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000a02',
 'RULE-MED-RENAL-DOSE',
 'Renal medication safety',
 'Reduced renal function should trigger medication renal-dose and nephrotoxicity assessment where relevant.',
 'safety', 'active', 95,
 'A1', 'Medication safety principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000a03',
 'RULE-MED-PREGNANCY',
 'Pregnancy medication safety',
 'Pregnancy status must be considered before medication recommendations where fetal or maternal safety may be affected.',
 'safety', 'active', 100,
 'A1', 'Medication safety principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000a04',
 'RULE-MED-INTERACTION',
 'Medication interaction check',
 'Existing medication exposure must be checked for clinically important interactions before medication recommendation.',
 'safety', 'active', 95,
 'A1', 'Medication safety principles', 'approved'
),

(
 'f1100000-0000-0000-0000-000000000a05',
 'RULE-MED-CONTRAINDICATION',
 'Medication contraindication check',
 'Known contraindications must be checked before medication recommendation.',
 'safety', 'active', 100,
 'A1', 'Medication safety principles', 'approved'
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.rule_condition
(rule_id, condition_group, condition_order, entity_type, entity_code, operator, value)

SELECT r.id, x.grp, x.ord, x.entity_type, x.entity_code, x.operator, x.value::jsonb
FROM knowledge.rule r
JOIN (
    VALUES
    ('RULE-MED-ALLERGY',1,1,'fact','MEDICATION_ALLERGY_PRESENT','eq','"YES"'),
    ('RULE-MED-RENAL-DOSE',1,1,'fact','RENAL_IMPAIRMENT','eq','"YES"'),
    ('RULE-MED-PREGNANCY',1,1,'context','PREGNANCY','eq','"pregnant"'),
    ('RULE-MED-INTERACTION',1,1,'fact','CURRENT_MEDICATIONS_PRESENT','eq','"YES"'),
    ('RULE-MED-CONTRAINDICATION',1,1,'fact','MEDICATION_CONTRAINDICATION_PRESENT','eq','"YES"')
) AS x(rule_code,grp,ord,entity_type,entity_code,operator,value)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.rule_action
(rule_id, action_order, action_type, action_entity_type, action_code, params)

SELECT r.id, x.action_order, x.action_type, x.action_entity_type,
       x.action_code, x.params
FROM knowledge.rule r
JOIN (
    VALUES

    (
      'RULE-MED-ALLERGY',1,
      'recommend_investigation','medication_safety',
      'CHECK-DRUG-ALLERGY',
      jsonb_build_object(
          'blocking',true,
          'reason','Documented medication allergy'
      )
    ),

    (
      'RULE-MED-RENAL-DOSE',1,
      'recommend_investigation','medication_safety',
      'CHECK-RENAL-DOSING',
      jsonb_build_object(
          'blocking',true,
          'reason','Renal impairment'
      )
    ),

    (
      'RULE-MED-PREGNANCY',1,
      'recommend_investigation','medication_safety',
      'CHECK-PREGNANCY-SAFETY',
      jsonb_build_object(
          'blocking',true,
          'reason','Pregnancy'
      )
    ),

    (
      'RULE-MED-INTERACTION',1,
      'recommend_investigation','medication_safety',
      'CHECK-DRUG-INTERACTIONS',
      jsonb_build_object(
          'blocking',true,
          'reason','Existing medication exposure'
      )
    ),

    (
      'RULE-MED-CONTRAINDICATION',1,
      'recommend_investigation','medication_safety',
      'CHECK-CONTRAINDICATIONS',
      jsonb_build_object(
          'blocking',true,
          'reason','Potential medication contraindication'
      )
    )

) AS x(rule_code,action_order,action_type,action_entity_type,action_code,params)
ON r.rule_code = x.rule_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 29. VERSION THE MEDICATION SAFETY RULES
-- =============================================================================

INSERT INTO knowledge.rule_version
(id, rule_id, version, body, is_active, changed_by)

SELECT
    gen_random_uuid(),
    r.id,
    1,
    jsonb_build_object(
        'type','clinical_safety_rule',
        'rule_code',r.rule_code,
        'version',1,
        'architecture','AMEXAN-Medication-Safety-Intelligence',
        'blocking_check',true
    ),
    true,
    NULL
FROM knowledge.rule r
WHERE r.rule_code IN (
    'RULE-MED-ALLERGY',
    'RULE-MED-RENAL-DOSE',
    'RULE-MED-PREGNANCY',
    'RULE-MED-INTERACTION',
    'RULE-MED-CONTRAINDICATION'
)
AND NOT EXISTS (
    SELECT 1
    FROM knowledge.rule_version rv
    WHERE rv.rule_id = r.id
      AND rv.version = 1
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 30. MEDICATION SAFETY PROVENANCE
-- =============================================================================

INSERT INTO knowledge.rule_source
(rule_id, source_type, source_ref, citation, evidence_level)

SELECT
    r.id,
    'safety_framework',
    'AMEXAN Medication Safety Layer',
    'Medication recommendations require allergy, contraindication, interaction,
     pregnancy and renal-function safety checks before execution.',
    'A1'
FROM knowledge.rule r
WHERE r.rule_code IN (
    'RULE-MED-ALLERGY',
    'RULE-MED-RENAL-DOSE',
    'RULE-MED-PREGNANCY',
    'RULE-MED-INTERACTION',
    'RULE-MED-CONTRAINDICATION'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 31. FINAL UNIVERSAL SAFETY PRIORITIES
-- =============================================================================

INSERT INTO knowledge.rule_priority
(rule_id, priority_score, basis, description)

SELECT
    r.id,
    100,
    'medication_safety',
    'Medication safety gate must execute before medication recommendation'
FROM knowledge.rule r
WHERE r.rule_code IN (
    'RULE-MED-ALLERGY',
    'RULE-MED-PREGNANCY',
    'RULE-MED-CONTRAINDICATION'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- END Z7
-- =============================================================================