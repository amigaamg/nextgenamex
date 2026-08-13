-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP0: Phase 1E fact definitions + concepts + specialties
-- =============================================================================
-- Extends the Phase 2 base seed with the fact definitions and concepts the MVP
-- knowledge population needs (chest pain, abdominal pain, examination facts,
-- the three new mechanisms, asthma/HF/GERD conditions, investigations,
-- examination modules, medications, monitoring, education, protocols).
-- Named seed_zp* so it runs after all existing seed_z* files.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Additional clinical fact definitions (history + examination)
-- ---------------------------------------------------------------------------

INSERT INTO clinical.fact_definition (code, name, data_type, description) VALUES
   ('COUGH_PRESENT',         'Cough present',           'coded',  'Presence of cough'),
   ('CHEST_PAIN_PRESENT',    'Chest pain present',      'coded',  'Presence of chest pain'),
   ('CHEST_PAIN_PLEURITIC',  'Pleuritic chest pain',    'coded',  'Chest pain worsened by breathing/coughing'),
   ('ABDO_PAIN_PRESENT',     'Abdominal pain present',  'coded',  'Presence of abdominal pain'),
   ('CHILLS',                'Chills',                  'coded',  'Chills with febrile illness'),
   ('WHEEZE_PRESENT',        'Wheeze present',          'coded',  'Wheezing / whistling on breathing'),
   ('RESP_RATE',             'Respiratory rate',        'numeric','Measured respiratory rate (breaths/min)'),
   ('SPO2',                  'Oxygen saturation',       'numeric','Peripheral oxygen saturation (%)'),
   ('TEMPERATURE',           'Body temperature',        'numeric','Measured temperature (degC)'),
   ('HEART_RATE',            'Heart rate',              'numeric','Measured heart rate (beats/min)'),
   ('RLL_DULLNESS',          'Right lower lobe dullness','boolean','Percussion dullness right lower lobe'),
   ('RLL_BRONCHIAL_BREATH_SOUNDS', 'RLL bronchial breath sounds','boolean','Bronchial breath sounds right lower lobe'),
   ('CRACKLES',              'Crackles',                'boolean','Crackles on auscultation'),
   ('CYANOSIS',              'Cyanosis',                'boolean','Cyanosis present'),
   ('CHEST_INDRAWING',       'Chest indrawing',         'boolean','Subcostal indrawing / increased work of breathing'),
   ('RESPIRATORY_DISTRESS',  'Respiratory distress',    'boolean','Clinical respiratory distress'),
   ('ORTHOPNOEA',            'Orthopnoea',              'coded',  'Breathlessness lying flat'),
   ('PND',                   'Paroxysmal nocturnal dyspnoea','coded','Sudden breathlessness at night'),
   ('PERIPHERAL_OEDEMA',     'Peripheral oedema',       'boolean','Bilateral peripheral oedema'),
   ('HEARTBURN',             'Heartburn / regurgitation','coded','Reflux symptoms'),
   ('CHEST_PAIN_ONSET',      'Chest pain onset',        'coded',  'Sudden / gradual onset')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- New universal concepts
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, description) VALUES
   ('f0a00000-0000-0000-0000-000000000017', 'CNS-CHEST-PAIN',       'symptom',       'Chest pain',        'Chest pain',        'Pain or discomfort perceived in the chest'),
   ('f0a00000-0000-0000-0000-000000000018', 'CNS-ABDO-PAIN',        'symptom',       'Abdominal pain',    'Abdominal pain',    'Pain perceived within the abdomen'),
   ('f0a00000-0000-0000-0000-000000000019', 'CNS-ASTHMA',           'condition',      'Asthma',            'Asthma',            'Chronic inflammatory airway disease with variable airflow limitation'),
   ('f0a00000-0000-0000-0000-00000000001a', 'CNS-HEART-FAILURE',    'condition',      'Heart failure',     'Heart failure',     'Impaired cardiac pump function with congestion'),
   ('f0a00000-0000-0000-0000-00000000001b', 'CNS-GERD',             'condition',      'Gastroesophageal reflux disease', 'GERD', 'Reflux of gastric contents causing symptoms'),
   ('f0a00000-0000-0000-0000-00000000001c', 'CNS-GRANULOMATOUS-INFECTION', 'mechanism', 'Chronic granulomatous pulmonary infection', 'Granulomatous infection', 'Persistent host-pathogen interaction producing chronic pulmonary disease'),
   ('f0a00000-0000-0000-0000-00000000001d', 'CNS-PULMONARY-CONGESTION', 'mechanism', 'Pulmonary vascular congestion', 'Pulmonary congestion', 'Raised pulmonary venous pressure with fluid accumulation'),
   ('f0a00000-0000-0000-0000-00000000001e', 'CNS-GASTROESOPHAGEAL-REFLUX', 'mechanism', 'Gastroesophageal reflux', 'GER', 'Retrograde movement of gastric contents'),
   ('f0a00000-0000-0000-0000-00000000001f', 'CNS-FBC',              'investigation',  'Full blood count',  'FBC',               'Haemoglobin, leukocyte and platelet assessment'),
   ('f0a00000-0000-0000-0000-000000000020', 'CNS-CRP',              'investigation',  'C-reactive protein','CRP',               'Systemic inflammatory marker'),
   ('f0a00000-0000-0000-0000-000000000021', 'CNS-UREA-CREAT',       'investigation',  'Urea and electrolytes', 'U+E',           'Renal function and electrolytes'),
   ('f0a00000-0000-0000-0000-000000000022', 'CNS-EXAM-GENERAL',     'examination_module', 'General examination', 'General exam', 'Initial general clinical assessment'),
   ('f0a00000-0000-0000-0000-000000000023', 'CNS-EXAM-RESP',        'examination_module', 'Respiratory examination', 'Resp exam',   'Structured respiratory examination'),
   ('f0a00000-0000-0000-0000-000000000024', 'CNS-EXAM-CVS',         'examination_module', 'Cardiovascular examination', 'CVS exam',    'Structured cardiovascular examination'),
   ('f0a00000-0000-0000-0000-000000000025', 'CNS-EXAM-ABDO',        'examination_module', 'Abdominal examination', 'Abdo exam',     'Structured abdominal examination'),
   ('f0a00000-0000-0000-0000-000000000026', 'CNS-EXAM-NEURO',       'examination_module', 'Neurological examination', 'Neuro exam',   'Structured neurological examination'),
   ('f0a00000-0000-0000-0000-000000000027', 'CNS-AMOXICILLIN',      'medication',     'Amoxicillin',       'Amoxicillin',       'Aminopenicillin antibiotic'),
   ('f0a00000-0000-0000-0000-000000000028', 'CNS-AMOXICILLIN-CLAV', 'medication',     'Amoxicillin/clavulanate', 'Co-amoxiclav', 'Beta-lactam/beta-lactamase inhibitor combination'),
   ('f0a00000-0000-0000-0000-000000000029', 'CNS-CEFTRIAXONE',      'medication',     'Ceftriaxone',       'Ceftriaxone',       'Third-generation cephalosporin'),
   ('f0a00000-0000-0000-0000-00000000002a', 'CNS-AZITHROMYCIN',     'medication',     'Azithromycin',      'Azithromycin',      'Macrolide antibiotic'),
   ('f0a00000-0000-0000-0000-00000000002b', 'CNS-PARACETAMOL',      'medication',     'Paracetamol',       'Paracetamol',       'Analgesic / antipyretic'),
   ('f0a00000-0000-0000-0000-00000000002c', 'CNS-MON-SPO2',         'monitoring',     'Oxygen saturation monitoring', 'SpO2 monitor', 'Oxygenation trajectory'),
   ('f0a00000-0000-0000-0000-00000000002d', 'CNS-MON-RR',           'monitoring',     'Respiratory rate monitoring', 'RR monitor',    'Respiratory workload trajectory'),
   ('f0a00000-0000-0000-0000-00000000002e', 'CNS-MON-TEMP',         'monitoring',     'Temperature monitoring', 'Temp monitor',      'Febrile trajectory'),
   ('f0a00000-0000-0000-0000-00000000002f', 'CNS-MON-HR',           'monitoring',     'Heart rate monitoring', 'HR monitor',        'Physiological response'),
   ('f0a00000-0000-0000-0000-000000000030', 'CNS-MON-WOB',          'monitoring',     'Work of breathing', 'WOB',                 'Respiratory effort'),
   ('f0a00000-0000-0000-0000-000000000031', 'CNS-EDU-CAP-BASICS',   'education',      'Understanding pneumonia', 'Pneumonia basics',  'Patient education on pneumonia'),
   ('f0a00000-0000-0000-0000-000000000032', 'CNS-EDU-CAP-DANGER',   'education',      'Pneumonia danger signs', 'Danger signs',      'When to seek urgent care'),
   ('f0a00000-0000-0000-0000-000000000033', 'CNS-EDU-CAP-MED',      'education',      'Taking pneumonia treatment', 'Medication guidance', 'How to take treatment'),
   ('f0a00000-0000-0000-0000-000000000034', 'CNS-EDU-CAP-TEACHBACK','education',      'Pneumonia teach-back', 'Teach-back',         'Confirm understanding'),
   ('f0a00000-0000-0000-0000-000000000035', 'CNS-EDU-CAP-CLINICIAN','education',      'Pneumonia reasoning summary', 'Clinician summary','Explanation of reasoning'),
   ('f0a00000-0000-0000-0000-000000000036', 'CNS-PROT-CAP',         'protocol',       'Adult community-acquired pneumonia pathway', 'CAP pathway', 'Adult CAP care pathway'),
   ('f0a00000-0000-0000-0000-000000000037', 'CNS-PROT-TB',          'protocol',       'Suspected pulmonary TB pathway', 'TB pathway',      'TB diagnostic pathway'),
   ('f0a00000-0000-0000-0000-000000000038', 'CNS-PROT-ASTHMA',      'protocol',       'Acute asthma pathway', 'Asthma pathway',      'Acute asthma care pathway'),
   ('f0a00000-0000-0000-0000-000000000039', 'CNS-PROT-HF',          'protocol',       'Decompensated heart failure pathway', 'HF pathway', 'Acute heart failure pathway'),
   ('f0a00000-0000-0000-0000-00000000003a', 'CNS-PROT-CHEST-PAIN',  'protocol',       'Acute chest pain pathway', 'Chest pain pathway','Undifferentiated chest pain pathway'),
   ('f0a00000-0000-0000-0000-00000000003b', 'CNS-WHEEZE',           'finding',        'Wheeze',            'Wheeze',            'Whistling sound on breathing'),
   ('f0a00000-0000-0000-0000-00000000003c', 'CNS-CRACKLES',         'finding',        'Crackles',          'Crackles',          'Fine or coarse crackles on auscultation'),
   ('f0a00000-0000-0000-0000-00000000003d', 'CNS-PLEURITIC-PAIN',   'sign',           'Pleuritic chest pain', 'Pleuritic pain',  'Pain worsened by breathing or cough')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Additional specialties used by the MVP graph
-- ---------------------------------------------------------------------------

INSERT INTO organization.specialty (code, label) VALUES
   ('respiratory_medicine',  'Respiratory Medicine'),
   ('cardiology',            'Cardiology'),
   ('gastroenterology',      'Gastroenterology'),
   ('infectious_disease',    'Infectious Disease'),
   ('emergency_department',  'Emergency Department')
ON CONFLICT (code) DO NOTHING;
