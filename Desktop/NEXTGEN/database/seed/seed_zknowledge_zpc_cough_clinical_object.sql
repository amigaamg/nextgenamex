-- =============================================================================
-- AMEXAN Universal Symptom Engine — Seed C: cough as a complete clinical object
-- =============================================================================
-- Populates every symptom-knowledge dimension for cough (SYM-COUGH,
-- f0b00000-0000-0000-0000-000000000001) so the CPU treats the symptom as a
-- first-class clinical object, not a narrow "one question -> one differential"
-- probe:
--   • symptom_etiology          — all cause categories that can produce cough
--   • symptom_risk_factor       — risk factors worth capturing for cough
--   • symptom_functional_impact — how cough affects daily function
--   • symptom_complication      — complications to watch for (with urgency)
--   • symptom_examination_target — structured exam findings tied to cough
--   • symptom_investigation_target — investigations a cough workup may need
--   • symptom_hpi_template      — natural-language documentation phrase for
--                                 EVERY captured cough fact (the reason HPI
--                                 prose was "not well documented": the docs
--                                 engine hardcoded ~15 slots and ignored the
--                                 remaining facts). After this seed the HPI is
--                                 data-driven and complete.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. New investigations a thorough cough workup may order (with concepts)
--    Existing INV-* used by targets: INV-CXR, INV-SPO2, INV-FBC, INV-CRP,
--    INV-UREA-CREAT, INV-SPUTUM-AFB. Added here: sputum culture, GeneXpert
--    MTB/RIF, blood culture.
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, description) VALUES
   ('f0a00000-0000-0000-0000-000000000046', 'CNS-SPUTUM-CULTURE', 'investigation',
    'Sputum culture and sensitivity', 'Culture and susceptibility testing of expectorated sputum'),
   ('f0a00000-0000-0000-0000-000000000047', 'CNS-GENEXPERT', 'investigation',
    'GeneXpert MTB/RIF', 'Molecular assay for tuberculosis and rifampicin resistance'),
   ('f0a00000-0000-0000-0000-000000000048', 'CNS-BLOOD-CULTURE', 'investigation',
    'Blood culture', 'Aerobic and anaerobic blood culture for bacteraemia')
ON CONFLICT (concept_code) DO NOTHING;

INSERT INTO knowledge.investigation (id, concept_id, investigation_code, canonical_name, description,
                                     investigation_type, body_system_code, specimen, preparation) VALUES
   ('f1300000-0000-0000-0000-000000000007', 'f0a00000-0000-0000-0000-000000000046', 'INV-SPUTUM-CULTURE',
    'Sputum culture and sensitivity', 'Culture and sensitivity of sputum for bacterial pathogens',
    'microbiology', 'RESPIRATORY', 'sputum', 'Early morning sample'),
   ('f1300000-0000-0000-0000-000000000008', 'f0a00000-0000-0000-0000-000000000047', 'INV-GENEXPERT',
    'GeneXpert MTB/RIF', 'Molecular detection of M. tuberculosis complex and rifampicin resistance',
    'microbiology', 'RESPIRATORY', 'sputum', 'Early morning sample'),
   ('f1300000-0000-0000-0000-000000000009', 'f0a00000-0000-0000-0000-000000000048', 'INV-BLOOD-CULTURE',
    'Blood culture', 'Aerobic and anaerobic blood culture', 'microbiology', 'HAEMATOLOGICAL', 'blood', 'Before antimicrobials')
ON CONFLICT (investigation_code) DO NOTHING;

INSERT INTO knowledge.investigation_condition (investigation_id, condition_id, weight, rationale) VALUES
   ('f1300000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000001', 0.6, 'Confirms bacterial pathogen and guides antibiotics'),
   ('f1300000-0000-0000-0000-000000000008', 'f1000000-0000-0000-0000-000000000002', 1.0, 'Molecular TB confirmation and RIF resistance'),
   ('f1300000-0000-0000-0000-000000000009', 'f1000000-0000-0000-0000-000000000001', 0.6, 'Detects bacteraemia in severe pneumonia')
ON CONFLICT (investigation_id, condition_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 1. Etiology — every category of disease that can present as cough
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_etiology (symptom_id, etiology_code, canonical_name, description, category, weight) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-URTI', 'Upper respiratory tract infection',
    'Viral rhinopharyngitis, laryngitis, influenza and other self-limiting URTIs', 'infectious', 1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-ACUTE-BRONCHITIS', 'Acute bronchitis',
    'Acute tracheobronchitis, usually viral, with productive cough', 'infectious', 0.9),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-PNEUMONIA', 'Pneumonia',
    'Parenchymal lung infection (bacterial, viral, aspiration) with consolidation', 'infectious', 0.9),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-TUBERCULOSIS', 'Pulmonary tuberculosis',
    'Chronic granulomatous infection of the lungs', 'infectious', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-PERTUSSIS', 'Pertussis',
    'Whooping cough from Bordetella pertussis infection', 'infectious', 0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-COVID', 'COVID-19',
    'SARS-CoV-2 respiratory infection with cough and fever', 'infectious', 0.6),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-ASTHMA', 'Asthma',
    'Variable airflow obstruction with cough, wheeze and nocturnal symptoms', 'obstructive', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-COPD', 'Chronic obstructive pulmonary disease',
    'Fixed airflow obstruction from chronic smoking / biomass exposure', 'obstructive', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-BRONCHIECTASIS', 'Bronchiectasis',
    'Chronic airway dilation with purulent sputum and recurrent infection', 'obstructive', 0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-LUNG-CANCER', 'Lung cancer',
    'Bronchogenic carcinoma with persistent cough, weight loss, haemoptysis', 'neoplastic', 0.7),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-METASTATIC-LUNG', 'Metastatic lung disease',
    'Secondary lung deposits causing cough', 'neoplastic', 0.3),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-HEART-FAILURE', 'Heart failure',
    'Pulmonary congestion causing cough, orthopnoea, PND and leg swelling', 'cardiac', 0.7),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-GERD', 'Gastroesophageal reflux disease',
    'Reflux triggering cough, worse with eating or lying flat', 'gastroesophageal', 0.6),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-ASPIRATION', 'Aspiration',
    'Chronic aspiration from dysphagia or poor swallowing', 'gastroesophageal', 0.5),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-POSTNASAL', 'Upper airway cough syndrome',
    'Post-nasal drip / rhinosinusitis causing reflex cough', 'upper-airway', 0.6),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-ACE-INHIBITOR', 'ACE inhibitor cough',
    'Drug-induced cough from ACE inhibitor therapy', 'drug-induced', 0.5),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-OCCUPATIONAL', 'Occupational lung disease',
    'Pneumoconiosis or irritant-induced cough from dust / fumes', 'occupational', 0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'ETH-COUGH-PLEURAL', 'Pleural disease',
    'Pleurisy, pleural effusion or pneumothorax presenting with cough', 'pleural', 0.5)
ON CONFLICT (symptom_id, etiology_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Risk factors — exposures and host factors relevant to cough
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_risk_factor (symptom_id, risk_factor_code, canonical_name, description, category, relevance) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-SMOKING', 'Tobacco smoking',
    'Current or former smoking increases risk of bronchitis, COPD, TB and lung cancer', 'behavioural', 1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-PACK-YEARS', 'Smoking pack-years',
    'Cumulative smoking exposure; higher exposure raises malignancy / COPD risk', 'behavioural', 0.9),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-TB-CONTACT', 'Tuberculosis contact',
    'Known exposure to active TB is the dominant risk for infection', 'environmental', 1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-HIV', 'HIV infection',
    'Immunosuppression predisposes to TB, bacterial pneumonia and PCP', 'immunological', 0.9),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-IMMUNOSUPPRESSION', 'Immunosuppression',
    'Steroids, chemotherapy or transplant increase infection risk', 'immunological', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-BIOMASS', 'Biomass fuel exposure',
    'Indoor cooking with wood / charcoal / dung causes chronic lung disease', 'environmental', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-OCCUPATIONAL', 'Occupational dust / fumes',
    'Mining, quarrying and industrial dust exposure', 'occupational', 0.7),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-ASPIRATION', 'Aspiration risk',
    'Dysphagia, choking or impaired swallow predispose to aspiration pneumonia', 'behavioural', 0.7),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-ACE', 'ACE inhibitor use',
    'Class effect cough in a subset of patients', 'drug', 0.6),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-ADVANCED-AGE', 'Advanced age',
    'Older adults have more severe disease and atypical presentation', 'demographic', 0.6),
   ('f0b00000-0000-0000-0000-000000000001', 'RISK-COUGH-PREGNANT', 'Pregnancy',
    'Pregnancy affects chest X-ray interpretation and antibiotic choices', 'demographic', 0.5)
ON CONFLICT (symptom_id, risk_factor_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Functional impact — how cough disrupts the patient's life
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_functional_impact (symptom_id, functional_impact_code, canonical_name, description, weight) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-SLEEP', 'Sleep disturbance',
    'Cough interrupts or prevents sleep', 0.9),
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-WORK', 'Work / school absence',
    'Missed work or school days attributable to cough', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-EXERCISE', 'Exercise intolerance',
    'Cough limits walking distance or exercise capacity', 0.7),
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-FEEDING', 'Feeding difficulty',
    'Cough interferes with feeding or drinking (paediatric)', 0.7),
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-VOICE', 'Voice impact',
    'Hoarseness or voice loss from cough', 0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-INCONTINENCE', 'Stress incontinence',
    'Cough-induced urinary leakage', 0.3),
   ('f0b00000-0000-0000-0000-000000000001', 'FUNC-COUGH-SOCIAL', 'Social distress',
    'Cough causes embarrassment, anxiety or avoidance of public places', 0.4)
ON CONFLICT (symptom_id, functional_impact_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Complications — adverse outcomes to watch for, with urgency
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_complication (symptom_id, complication_code, canonical_name, description, urgency, weight) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-RESP-FAILURE', 'Respiratory failure',
    'Type I or II respiratory failure from severe pneumonia / obstruction', 'emergency', 1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-HYPOXAEMIA', 'Hypoxaemia',
    'Low oxygen saturation requiring oxygen supplementation', 'emergency', 1.0),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-PNEUMOTHORAX', 'Pneumothorax',
    'Air leak causing lung collapse, sudden breathlessness and chest pain', 'emergency', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-MASSIVE-HAEMOPTYSIS', 'Massive haemoptysis',
    'Life-threatening airway bleeding', 'emergency', 0.8),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-SEPSIS', 'Sepsis',
    'Systemic infection with organ dysfunction from pneumonia', 'emergency', 0.9),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-EMPYEMA', 'Empyema',
    'Pus in the pleural space complicating pneumonia', 'urgent', 0.5),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-LUNG-ABSCESS', 'Lung abscess',
    'Localised pus collection from necrotising infection / aspiration', 'urgent', 0.5),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-SYNCOPE', 'Cough syncope',
    'Transient loss of consciousness during coughing paroxysm', 'urgent', 0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-RIB-FRACTURE', 'Rib fracture',
    'Stress fracture from prolonged severe coughing', 'urgent', 0.4),
   ('f0b00000-0000-0000-0000-000000000001', 'COMP-COUGH-CACHEXIA', 'Weight loss / cachexia',
    'Wasting associated with TB or malignancy', 'urgent', 0.5)
ON CONFLICT (symptom_id, complication_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Examination targets — structured findings to look for when cough present
--    (finding codes reference knowledge.examination_finding)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_examination_target (symptom_id, finding_code, priority, rationale) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-RR', 10, 'Tachypnoea marks respiratory distress'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-SPO2', 10, 'Hypoxaemia is the key severity signal'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-TEMP', 10, 'Fever confirms infection'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-RESP-DISTRESS', 20, 'Work of breathing assessment'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-CHEST-INDRAWING', 20, 'Indrawing in children / severe obstruction'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-CYANOSIS', 20, 'Late sign of severe hypoxaemia'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-RLL-DULLNESS', 20, 'Percussion dullness suggests consolidation or effusion'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-RLL-BRONCHIAL', 20, 'Bronchial breathing over consolidation'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-CRACKLES', 20, 'Crackles in pneumonia / pulmonary oedema'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-WHEEZE', 20, 'Wheeze indicates airflow obstruction'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-HR', 30, 'Tachycardia in sepsis or hypoxia'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-PERIPHERAL-OEDEMA', 30, 'Oedema points to heart failure'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-JVP-ELEVATED', 30, 'Raised JVP supports cardiac cause'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-ABDO-TENDERNESS', 40, 'Basal pneumonia may present with abdominal pain'),
   ('f0b00000-0000-0000-0000-000000000001', 'FIND-FOCAL-NEURO', 40, 'Focal deficit raises aspiration risk')
ON CONFLICT (symptom_id, finding_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. Investigation targets — investigations a cough workup may need
--    (codes reference knowledge.investigation)
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.symptom_investigation_target (symptom_id, investigation_code, priority, rationale) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'INV-SPO2', 10, 'Objective oxygenation assessment'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-CXR', 10, 'First-line imaging: consolidation, effusion, mass, TB'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-FBC', 20, 'White cell count and anaemia assessment'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-CRP', 20, 'Systemic inflammatory marker'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-UREA-CREAT', 20, 'Severity assessment and treatment planning'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-SPUTUM-AFB', 20, 'TB screening in endemic / chronic cough'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-SPUTUM-CULTURE', 20, 'Pathogen identification and sensitivity'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-GENEXPERT', 30, 'Molecular TB confirmation and RIF resistance'),
   ('f0b00000-0000-0000-0000-000000000001', 'INV-BLOOD-CULTURE', 30, 'Bacteraemia detection in severe disease')
ON CONFLICT (symptom_id, investigation_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. HPI documentation templates
-- ---------------------------------------------------------------------------
-- One template row per (fact, captured value). A NULL fact_value means the
-- phrase is value-agnostic and uses the {value} placeholder (numeric facts).
-- The DocumentationEngine renders only templates whose fact is captured and
-- whose fact_value matches. This makes the History of Present Illness fully
-- data-driven and complete for every cough fact.
--
-- Idempotency: rows with fact_value IS NULL can never collide with ON CONFLICT
-- (Postgres treats NULLs as distinct in a unique index), so the symptom's
-- templates are wiped and re-inserted wholesale. This is safe reference data.
-- ---------------------------------------------------------------------------

DELETE FROM knowledge.symptom_hpi_template
 WHERE symptom_id = 'f0b00000-0000-0000-0000-000000000001';

-- 7a. History — presenting complaint (opening sentence: onset / duration / productivity)
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_PRESENT',      'YES',   'cough', 10),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_PRESENT',      'NO',    'no cough', 10),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_ONSET',        'ACUTE',    'acute', 20),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_ONSET',        'SUBACUTE', 'subacute', 20),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_ONSET',        'CHRONIC',  'chronic', 20),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_DURATION_DAYS', NULL,       '{value}-day history', 30),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_PRODUCTIVITY', 'PRODUCTIVE',     'productive', 40),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'presenting', 'COUGH_PRODUCTIVITY', 'NON_PRODUCTIVE', 'dry', 40)
;

-- 7b. History — cough character (severity, character, timing, triggers, relieving, positional)
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_SEVERITY',   'MILD',    'mild in severity', 45),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_SEVERITY',   'MODERATE','moderate in severity', 45),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_SEVERITY',   'SEVERE',  'severe in severity', 45),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_CHARACTER',  'DRY_HACK', 'dry and hacking', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_CHARACTER',  'BARKING',  'barking', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_CHARACTER',  'PAROXYSMAL','paroxysmal', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_CHARACTER',  'WHOOPING', 'whooping', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TIMING',     'MORNING',    'worse in the morning', 60),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TIMING',     'NIGHT',      'worse at night', 60),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TIMING',     'THROUGHOUT', 'present throughout the day', 60),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TRIGGERS',   'COLD_AIR',   'worsened by cold air', 70),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TRIGGERS',   'EXERCISE',   'worsened by exertion', 70),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TRIGGERS',   'LYING_FLAT', 'worsened on lying flat', 70),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TRIGGERS',   'EATING',     'worsened by eating', 70),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_TRIGGERS',   'TALKING',    'worsened by talking', 70),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_RELIEVING',  'NOTHING', 'nothing relieves the cough', 75),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_RELIEVING',  'REST',    'relieved by rest', 75),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_RELIEVING',  'POSITION','relieved by sitting up', 75),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_POSITIONAL', 'YES', 'worse on lying flat', 80),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'character', 'COUGH_POSITIONAL', 'NO',  'not positional', 80)
;

-- 7c. History — sputum detail
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_COLOUR',      'CLEAR',       'clear', 90),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_COLOUR',      'YELLOW_GREEN','yellow-green', 90),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_COLOUR',      'RUSTY',       'rusty-coloured', 90),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_AMOUNT',      'SCANT',   'scant in amount', 95),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_AMOUNT',      'MODERATE','moderate in amount', 95),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_AMOUNT',      'COPIOUS', 'copious', 95),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_CONSISTENCY', 'WATERY',   'watery', 100),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_CONSISTENCY', 'MUCOID',   'mucoid', 100),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_CONSISTENCY', 'PURULENT', 'purulent', 100),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_CONSISTENCY', 'FROTHY',   'frothy', 100),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_ODOUR',       'NONE', 'no offensive odour', 105),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'SPUTUM_ODOUR',       'FOUL', 'foul-smelling', 105),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'BLOOD_IN_SPUTUM',    'YES', 'haemoptysis', 110),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'sputum', 'BLOOD_IN_SPUTUM',    'NO',  'no haemoptysis', 110)
;

-- 7d. History — associated respiratory & cardiac symptoms
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_PRESENT',   'YES', 'progressive dyspnoea', 150),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_PRESENT',   'NO',  'no dyspnoea', 150),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_ONSET',     'SUDDEN', 'of sudden onset', 155),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_ONSET',     'GRADUAL','of gradual onset', 155),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_SEVERITY',  'ON_EXERTION','breathless on exertion', 160),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_SEVERITY',  'ON_WALKING', 'breathless on walking', 160),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'DYSPNOEA_SEVERITY',  'AT_REST',    'breathless at rest', 160),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'ORTHOPNOEA',         'YES', 'orthopnoea', 165),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'ORTHOPNOEA',         'NO',  'no orthopnoea', 165),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'PND',                'YES', 'paroxysmal nocturnal dyspnoea', 170),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'PND',                'NO',  'no paroxysmal nocturnal dyspnoea', 170),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'LEG_SWELLING',       'YES', 'leg swelling', 175),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'LEG_SWELLING',       'NO',  'no leg swelling', 175),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'WHEEZE_PRESENT',     'YES', 'wheeze', 180),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'WHEEZE_PRESENT',     'NO',  'no wheeze', 180),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_PRESENT',   'YES', 'chest pain', 190),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_PRESENT',   'NO',  'no chest pain', 190),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_PLEURITIC', 'YES', 'pleuritic in nature', 195),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_PLEURITIC', 'NO',  'non-pleuritic in nature', 195),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_ONSET',     'SUDDEN', 'sudden onset', 200),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_ONSET',     'GRADUAL','gradual onset', 200),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_RADIATION', 'NONE',     'with no radiation', 205),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_RADIATION', 'LEFT_ARM', 'radiating to the left arm', 205),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_RADIATION', 'JAW',      'radiating to the jaw', 205),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'associated', 'CHEST_PAIN_RADIATION', 'BACK',     'radiating to the back', 205)
;

-- 7e. History — ENT, reflux and upper airway symptoms
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'RHINORRHOEA',   'YES', 'rhinorrhoea', 210),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'RHINORRHOEA',   'NO',  'no rhinorrhoea', 210),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'SORE_THROAT',   'YES', 'sore throat', 215),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'SORE_THROAT',   'NO',  'no sore throat', 215),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'HOARSENESS',    'YES', 'hoarseness', 220),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'HOARSENESS',    'NO',  'no hoarseness', 220),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'POSTNASAL_DRIP','YES', 'post-nasal drip', 225),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'POSTNASAL_DRIP','NO',  'no post-nasal drip', 225),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'HEARTBURN',     'YES', 'heartburn', 230),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'HEARTBURN',     'NO',  'no heartburn', 230),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'VOICE_CHANGE',  'YES', 'voice change', 235),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'ent_gi', 'VOICE_CHANGE',  'NO',  'no voice change', 235)
;

-- 7f. History — systemic symptoms
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'FEVER_PRESENT', 'YES', 'fever', 240),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'FEVER_PRESENT', 'NO',  'no fever', 240),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'FEVER_ONSET',   'LESS_3_DAYS', 'fever for under 3 days', 245),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'FEVER_ONSET',   '3_7_DAYS',    'fever for 3 to 7 days', 245),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'FEVER_ONSET',   'OVER_7_DAYS', 'fever for over a week', 245),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'CHILLS',         'YES', 'chills', 255),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'CHILLS',         'NO',  'no chills', 255),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'WEIGHT_LOSS',    'YES',     'unintentional weight loss', 260),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'WEIGHT_LOSS',    'NO',      'no weight loss', 260),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'WEIGHT_LOSS',    'UNKNOWN', 'weight loss status unclear', 260),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'NIGHT_SWEATS',   'YES', 'night sweats', 265),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'systemic', 'NIGHT_SWEATS',   'NO',  'no night sweats', 265)
;

-- 7g. History — risk factors and exposures
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'TB_CONTACT',        'YES',     'reported TB exposure', 270),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'TB_CONTACT',        'NO',      'no known TB contact', 270),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'TB_CONTACT',        'UNKNOWN', 'TB contact status unknown', 270),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'SMOKING_STATUS',    'CURRENT', 'current smoker', 275),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'SMOKING_STATUS',    'FORMER',  'ex-smoker', 275),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'SMOKING_STATUS',    'NEVER',   'non-smoker', 275),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'SMOKING_PACK_YEARS', NULL,      '{value} pack-year smoking history', 280),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'HIV_STATUS',        'POSITIVE', 'known HIV positive', 285),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'HIV_STATUS',        'NEGATIVE', 'HIV negative', 285),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'HIV_STATUS',        'UNKNOWN',  'HIV status unknown', 285),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'IMMUNOSUPPRESSED',  'YES', 'immunosuppressed', 290),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'IMMUNOSUPPRESSED',  'NO',  'no immunosuppression', 290),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'OCCUPATIONAL_DUST', 'YES', 'occupational dust exposure', 295),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'OCCUPATIONAL_DUST', 'NO',  'no occupational dust exposure', 295),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'BIOMASS_EXPOSURE',  'YES', 'indoor biomass smoke exposure', 300),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'BIOMASS_EXPOSURE',  'NO',  'no biomass smoke exposure', 300),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'ASPIRATION_RISK',   'YES', 'aspiration risk', 305),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'ASPIRATION_RISK',   'NO',  'no aspiration risk', 305),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'DYSPHAGIA',         'YES', 'dysphagia', 310),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'DYSPHAGIA',         'NO',  'no dysphagia', 310),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'ACE_INHIBITOR',     'YES', 'on an ACE inhibitor', 315),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'risk', 'ACE_INHIBITOR',     'NO',  'not on an ACE inhibitor', 315)
;

-- 7h. History — functional impact
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'SLEEP_DISTURBANCE',    'YES', 'cough disturbs sleep', 320),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'SLEEP_DISTURBANCE',    'NO',  'sleep undisturbed', 320),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'WORK_ABSENCE',         'YES', 'missed work or school', 325),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'WORK_ABSENCE',         'NO',  'no work or school absence', 325),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'EXERCISE_INTOLERANCE', 'YES', 'exercise intolerance', 330),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'EXERCISE_INTOLERANCE', 'NO',  'no exercise limitation', 330),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'FEEDING_DIFFICULTY',   'YES', 'cough interferes with feeding', 335),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'functional', 'FEEDING_DIFFICULTY',   'NO',  'no feeding difficulty', 335)
;

-- 7i. Examination section — findings as facts become sentences
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'RESP_RATE',                  NULL,  'respiratory rate {value}/min', 10),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'SPO2',                       NULL,  'SpO2 {value}%', 20),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'HEART_RATE',                 NULL,  'heart rate {value}/min', 30),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'TEMPERATURE',                NULL,  'temperature {value}°C', 40),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'RESPIRATORY_DISTRESS',       'true', 'respiratory distress', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'CHEST_INDRAWING',            'true', 'chest indrawing', 60),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'CYANOSIS',                   'true', 'cyanosis', 70),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'RLL_DULLNESS',               'true', 'right lower lobe dullness', 80),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'RLL_BRONCHIAL_BREATH_SOUNDS','true', 'right lower lobe bronchial breath sounds', 90),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'CRACKLES',                   'true', 'crackles', 100),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'WHEEZE_PRESENT',             'YES',  'wheeze on auscultation', 110),
   ('f0b00000-0000-0000-0000-000000000001', 'examination', 'examination', 'PERIPHERAL_OEDEMA',          'true', 'peripheral oedema', 120)
;

-- ---------------------------------------------------------------------------
-- 8. Socratic activation corrections (value-aware questioning)
-- ---------------------------------------------------------------------------
-- The QuestionSelector now enforces question_requirement.condition as a
-- "rule out when contradicted" gate. These corrections keep the interview
-- medically correct:
--   • DYSPNOEA_PRESENT must be asked for ANY cough (severity red flag), not
--     only chronic cough — clear its gt:14 condition.
--   • FEVER_PRESENT is a mandatory discriminator for every respiratory
--     presentation — give it a symptom:cough trigger alongside symptom:fever.
-- ---------------------------------------------------------------------------

UPDATE knowledge.question_requirement
   SET condition = NULL
 WHERE question_id = 'f0c00000-0000-0000-0000-00000000000c'
   AND requirement_level = 'conditionally_required';

INSERT INTO knowledge.question_trigger (question_id, trigger_type, trigger_concept_id, trigger_code, priority)
VALUES ('f0c00000-0000-0000-0000-000000000006', 'symptom', 'f0a00000-0000-0000-0000-000000000001', 'cough', 20)
ON CONFLICT DO NOTHING;
