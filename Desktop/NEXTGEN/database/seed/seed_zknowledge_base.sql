-- =============================================================================
-- AMEXAN Phase 2 — Seed Z1: knowledge base (fact definitions + concepts)
-- =============================================================================
-- Named seed_z* so it runs AFTER seed_reference (specialties exist).
-- =============================================================================

INSERT INTO clinical.fact_definition (code, name, data_type, description) VALUES
   ('COUGH_PRODUCTIVITY',   'Cough productivity',    'coded',  'Is the cough productive?'),
   ('COUGH_DURATION_DAYS',  'Cough duration (days)', 'numeric','Duration of cough in days'),
   ('COUGH_ONSET',          'Cough onset',           'coded',  'Acute / subacute / chronic onset'),
   ('COUGH_SEVERITY',       'Cough severity',        'coded',  'Mild / moderate / severe'),
   ('SPUTUM_COLOUR',        'Sputum colour',         'coded',  'Colour of sputum'),
   ('SPUTUM_AMOUNT',        'Sputum amount',         'coded',  'Amount of sputum'),
   ('BLOOD_IN_SPUTUM',      'Blood in sputum',       'coded',  'Haemoptysis present'),
   ('FEVER_PRESENT',        'Fever present',         'coded',  'Is fever present?'),
   ('FEVER_ONSET',          'Fever onset',           'coded',  'When did fever start?'),
   ('TB_CONTACT',           'TB contact',            'coded',  'Known contact with TB'),
   ('WEIGHT_LOSS',          'Weight loss',           'coded',  'Unintentional weight loss'),
   ('NIGHT_SWEATS',         'Night sweats',          'coded',  'Night sweats present'),
   ('SMOKING_STATUS',       'Smoking status',        'coded',  'Current / former / never smoker'),
   ('DYSPNOEA_PRESENT',     'Dyspnoea present',      'coded',  'Shortness of breath present')
ON CONFLICT (code) DO NOTHING;

INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, description) VALUES
   ('f0a00000-0000-0000-0000-000000000001', 'CNS-COUGH',          'symptom',      'Cough',           'Cough',           'Expulsive expulsion of air from the airways'),
   ('f0a00000-0000-0000-0000-000000000002', 'CNS-FEVER',          'symptom',      'Fever',           'Fever',           'Elevated body temperature'),
   ('f0a00000-0000-0000-0000-000000000003', 'CNS-DYSPNOEA',       'symptom',      'Dyspnoea',        'Shortness of breath', 'Difficulty breathing'),
   ('f0a00000-0000-0000-0000-000000000004', 'CNS-HAEMOPTYSIS',    'sign',         'Haemoptysis',     'Coughing blood',  'Expectoration of blood'),
   ('f0a00000-0000-0000-0000-000000000005', 'CNS-PRODUCTIVE-COUGH','finding',     'Productive cough','Productive cough','Cough producing sputum'),
   ('f0a00000-0000-0000-0000-000000000006', 'CNS-TB-EXPOSURE',    'risk_factor',  'TB exposure',     'TB contact',      'Known contact with tuberculosis'),
   ('f0a00000-0000-0000-0000-000000000007', 'CNS-SMOKING',        'risk_factor',  'Smoking',         'Smoking',         'Tobacco smoking'),
   ('f0a00000-0000-0000-0000-000000000008', 'CNS-IMMUNOCOMPROMISED','risk_factor','Immunocompromised','Immunocompromised','Reduced immune competence'),
   ('f0a00000-0000-0000-0000-000000000009', 'CNS-WEIGHT-LOSS',    'finding',      'Weight loss',     'Weight loss',     'Unintentional weight loss'),
   ('f0a00000-0000-0000-0000-00000000000a', 'CNS-NIGHT-SWEATS',   'symptom',      'Night sweats',    'Night sweats',    'Profuse sweating at night'),
   ('f0a00000-0000-0000-0000-00000000000b', 'CNS-AIRWAY-INFLAMMATION','mechanism','Airway inflammation','Airway inflammation','Inflammation of the conducting airways'),
   ('f0a00000-0000-0000-0000-00000000000c', 'CNS-ALVEOLAR-INFLAMMATION','mechanism','Alveolar inflammation','Alveolar inflammation','Inflammation of lung parenchyma / alveoli'),
   ('f0a00000-0000-0000-0000-00000000000d', 'CNS-PLEURAL-INFLAMMATION','mechanism','Pleural inflammation','Pleural inflammation','Inflammation of the pleura'),
   ('f0a00000-0000-0000-0000-00000000000e', 'CNS-AIRWAY-OBSTRUCTION','mechanism','Airway obstruction','Airway obstruction','Obstruction of airflow in the airways'),
   ('f0a00000-0000-0000-0000-00000000000f', 'CNS-PNEUMONIA',      'condition',    'Pneumonia',       'Pneumonia',       'Acute infection of the lung parenchyma'),
   ('f0a00000-0000-0000-0000-000000000010', 'CNS-TUBERCULOSIS',   'condition',    'Tuberculosis',    'TB',              'Infectious disease caused by mycobacterium tuberculosis'),
   ('f0a00000-0000-0000-0000-000000000011', 'CNS-ACUTE-BRONCHITIS','condition',   'Acute bronchitis','Acute bronchitis','Inflammation of the large airways'),
   ('f0a00000-0000-0000-0000-000000000012', 'CNS-CHEST-XRAY',     'investigation','Chest X-ray',     'Chest X-ray',     'Radiograph of the chest'),
   ('f0a00000-0000-0000-0000-000000000013', 'CNS-SPUTUM-AFB',     'investigation','Sputum AFB',      'Sputum AFB',      'Acid-fast bacilli smear of sputum'),
   ('f0a00000-0000-0000-0000-000000000014', 'CNS-PULSE-OXIMETRY', 'investigation','Pulse oximetry',  'SpO2',            'Non-invasive oxygen saturation'),
   ('f0a00000-0000-0000-0000-000000000015', 'CNS-RESPIRATORY-FAILURE','complication','Respiratory failure','Respiratory failure','Inability to maintain adequate gas exchange'),
   ('f0a00000-0000-0000-0000-000000000016', 'CNS-HYPOXAEMIA',     'finding',      'Hypoxaemia',      'Low blood oxygen','Low arterial oxygen saturation')
ON CONFLICT (id) DO NOTHING;
