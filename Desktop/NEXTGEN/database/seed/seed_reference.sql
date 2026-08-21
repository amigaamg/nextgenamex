-- =============================================================================
-- AMEXAN CLINICAL OPERATING SYSTEM
-- PHASE 1 — SEED A
-- IDENTITY, PATIENT, ENCOUNTER, ORGANIZATION, TERMINOLOGY
-- =============================================================================
--
-- PURPOSE
-- -----------------------------------------------------------------------------
-- This seed establishes UNIVERSAL REFERENCE DATA.
--
-- It does NOT contain:
--   - disease rules
--   - diagnostic reasoning
--   - differential diagnosis logic
--   - treatment protocols
--   - medication dosing
--   - HPI intelligence
--   - examination reasoning
--   - CPU inference
--
-- Those belong to later knowledge / CPU seeds.
--
-- DESIGN PRINCIPLES
-- -----------------------------------------------------------------------------
-- 1. Idempotent
-- 2. No patient-specific data
-- 3. No organization-specific data
-- 4. No disease-specific reasoning
-- 5. Stable canonical codes
-- 6. Human-readable labels
-- 7. Terminology-ready
-- 8. Internationally extensible
-- 9. Kenya-first language support without Kenya-only architecture
-- 10. Suitable for CPU consumption
--
-- DEPENDENCIES
-- -----------------------------------------------------------------------------
-- Expected schemas:
--
-- identity
-- patient
-- encounter
-- organization
-- terminology
--
-- Run AFTER schema creation and BEFORE CPU/rule seeds.
--
-- =============================================================================


BEGIN;

-- ============================================================================
-- SECTION 1
-- IDENTITY — LANGUAGES
-- ============================================================================

INSERT INTO identity.language
    (code, label, native_label)
VALUES
    ('en',   'English',    'English'),
    ('sw',   'Kiswahili',  'Kiswahili'),
    ('luo',  'Dholuo',     'Dholuo'),
    ('luy',  'Luhya',      'Luhya'),
    ('kik',  'Kikuyu',     'Gĩkũyũ'),
    ('kam',  'Kamba',      'Kikamba'),
    ('som',  'Somali',     'Somali'),
    ('fr',   'French',     'Français'),
    ('es',   'Spanish',    'Español'),
    ('pt',   'Portuguese', 'Português'),
    ('ar',   'Arabic',     'العربية'),
    ('zh',   'Chinese',    '中文'),
    ('hi',   'Hindi',      'हिन्दी')
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 2
-- IDENTITY — PERSON STATUS
-- ============================================================================

INSERT INTO identity.person_status
    (code, label, description)
VALUES
    (
        'active',
        'Active',
        'Person record is active and may participate in care.'
    ),
    (
        'inactive',
        'Inactive',
        'Person record exists but is not currently active.'
    ),
    (
        'deceased',
        'Deceased',
        'Person is recorded as deceased.'
    ),
    (
        'unknown',
        'Unknown',
        'Current person status is unknown.'
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 3
-- PATIENT — MASTER RECORD STATUS
-- ============================================================================

INSERT INTO patient.patient_status
    (code, label, description)
VALUES
    (
        'active',
        'Active',
        'Patient has an active clinical record.'
    ),
    (
        'inactive',
        'Inactive',
        'Patient record is inactive but retained.'
    ),
    (
        'deceased',
        'Deceased',
        'Patient is recorded as deceased.'
    ),
    (
        'archived',
        'Archived',
        'Patient record has been archived according to retention policy.'
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 4
-- ENCOUNTER TYPES
-- ============================================================================

INSERT INTO encounter.encounter_type
    (code, label, description)
VALUES
    (
        'opd',
        'Outpatient',
        'Routine outpatient clinical encounter.'
    ),
    (
        'ipd',
        'Inpatient',
        'Encounter occurring during an inpatient admission.'
    ),
    (
        'emergency',
        'Emergency',
        'Emergency or acute unscheduled clinical encounter.'
    ),
    (
        'telemedicine',
        'Telemedicine',
        'Clinical encounter conducted remotely using telecommunications.'
    ),
    (
        'home_visit',
        'Home Visit',
        'Clinical care delivered at the patient home.'
    ),
    (
        'community_visit',
        'Community Visit',
        'Clinical care delivered in a community or outreach setting.'
    ),
    (
        'procedure',
        'Procedure',
        'Encounter primarily associated with a procedure.'
    ),
    (
        'discharge',
        'Discharge',
        'Encounter associated with discharge from a care episode.'
    ),
    (
        'follow_up',
        'Follow-up',
        'Planned follow-up clinical encounter.'
    ),
    (
        'special_clinic',
        'Special Clinic',
        'Encounter occurring within a specialized clinical service.'
    ),
    (
        'antenatal',
        'Antenatal',
        'Pregnancy-related antenatal clinical encounter.'
    ),
    (
        'postnatal',
        'Postnatal',
        'Postpartum/postnatal clinical encounter.'
    ),
    (
        'immunization',
        'Immunization',
        'Encounter primarily for immunization or vaccination.'
    ),
    (
        'screening',
        'Screening',
        'Encounter primarily for preventive screening.'
    ),
    (
        'well_child',
        'Well Child',
        'Routine preventive child-health encounter.'
    ),
    (
        'wellness',
        'Wellness',
        'General preventive health and wellness encounter.'
    ),
    (
        'occupational_health',
        'Occupational Health',
        'Encounter related to occupational health assessment or care.'
    ),
    (
        'mental_health',
        'Mental Health',
        'Encounter primarily addressing mental or behavioural health.'
    ),
    (
        'rehabilitation',
        'Rehabilitation',
        'Encounter primarily for rehabilitation services.'
    ),
    (
        'pharmacy',
        'Pharmacy',
        'Medication/pharmacy-focused encounter.'
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 5
-- ENCOUNTER STATUS
-- ============================================================================

INSERT INTO encounter.encounter_status
    (code, label, description)
VALUES
    (
        'planned',
        'Planned',
        'Encounter has been scheduled or created but has not started.'
    ),
    (
        'arrived',
        'Arrived',
        'Patient has arrived for the encounter.'
    ),
    (
        'triaged',
        'Triaged',
        'Initial triage has been completed.'
    ),
    (
        'active',
        'Active',
        'Encounter is currently in progress.'
    ),
    (
        'completed',
        'Completed',
        'Encounter has been completed.'
    ),
    (
        'cancelled',
        'Cancelled',
        'Encounter was cancelled before completion.'
    ),
    (
        'on_hold',
        'On Hold',
        'Encounter has temporarily been placed on hold.'
    ),
    (
        'no_show',
        'No Show',
        'Patient did not attend the scheduled encounter.'
    ),
    (
        'entered_in_error',
        'Entered in Error',
        'Encounter was created incorrectly and should not be treated as valid clinical activity.'
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 6
-- ENCOUNTER PHASES
-- ============================================================================

INSERT INTO encounter.encounter_phase
    (code, label, description, sort_order)
VALUES
    (
        'registration',
        'Registration',
        'Patient registration and encounter creation.',
        10
    ),
    (
        'triage',
        'Triage',
        'Initial prioritization and immediate clinical assessment.',
        20
    ),
    (
        'history',
        'History',
        'Collection of the relevant clinical history.',
        25
    ),
    (
        'consultation',
        'Consultation',
        'Clinical consultation with the responsible clinician.',
        30
    ),
    (
        'assessment',
        'Assessment',
        'Clinical assessment and examination.',
        40
    ),
    (
        'investigation',
        'Investigation',
        'Investigation ordering, performance and interpretation workflow.',
        50
    ),
    (
        'diagnosis',
        'Diagnosis',
        'Clinical diagnostic assessment.',
        55
    ),
    (
        'treatment',
        'Treatment',
        'Treatment and therapeutic intervention.',
        60
    ),
    (
        'monitoring',
        'Monitoring',
        'Monitoring of clinical status and response.',
        65
    ),
    (
        'disposition',
        'Disposition',
        'Decision regarding admission, discharge, referral, transfer or follow-up.',
        70
    ),
    (
        'completed',
        'Completed',
        'Encounter is clinically complete.',
        80
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 7
-- ENCOUNTER PRIORITY
-- ============================================================================

INSERT INTO encounter.encounter_priority
    (code, label, sort_order)
VALUES
    ('routine',    'Routine',    10),
    ('urgent',     'Urgent',     20),
    ('asap',       'ASAP',       30),
    ('emergency',  'Emergency',  40),
    ('stat',       'STAT',       50)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 8
-- ORGANIZATION — PROFESSIONS
-- ============================================================================

INSERT INTO organization.profession
    (code, label, description)
VALUES
    (
        'doctor',
        'Doctor',
        'Medical doctor / physician.'
    ),
    (
        'clinical_officer',
        'Clinical Officer',
        'Licensed clinical officer providing clinical care.'
    ),
    (
        'nurse',
        'Nurse',
        'Registered or licensed nursing professional.'
    ),
    (
        'midwife',
        'Midwife',
        'Qualified midwifery professional.'
    ),
    (
        'pharmacist',
        'Pharmacist',
        'Qualified pharmacy professional.'
    ),
    (
        'pharmacy_technician',
        'Pharmacy Technician',
        'Pharmacy technical professional.'
    ),
    (
        'lab_technician',
        'Laboratory Technician',
        'Laboratory technical professional.'
    ),
    (
        'laboratory_scientist',
        'Laboratory Scientist',
        'Medical laboratory scientist.'
    ),
    (
        'radiographer',
        'Radiographer',
        'Medical imaging/radiography professional.'
    ),
    (
        'radiologist',
        'Radiologist',
        'Medical doctor specializing in diagnostic imaging.'
    ),
    (
        'nutritionist',
        'Nutritionist',
        'Nutrition professional.'
    ),
    (
        'dietitian',
        'Dietitian',
        'Qualified dietetics professional.'
    ),
    (
        'physiotherapist',
        'Physiotherapist',
        'Physical rehabilitation professional.'
    ),
    (
        'occupational_therapist',
        'Occupational Therapist',
        'Occupational therapy professional.'
    ),
    (
        'psychologist',
        'Psychologist',
        'Psychology professional.'
    ),
    (
        'psychiatrist',
        'Psychiatrist',
        'Medical doctor specializing in psychiatry.'
    ),
    (
        'dentist',
        'Dentist',
        'Dental practitioner.'
    ),
    (
        'dental_officer',
        'Dental Officer',
        'Dental clinical practitioner.'
    ),
    (
        'optometrist',
        'Optometrist',
        'Eye-care professional specializing in optometry.'
    ),
    (
        'ophthalmologist',
        'Ophthalmologist',
        'Medical doctor specializing in ophthalmology.'
    ),
    (
        'health_records_officer',
        'Health Records Officer',
        'Health information and medical records professional.'
    ),
    (
        'receptionist',
        'Receptionist',
        'Front-office and patient reception professional.'
    ),
    (
        'community_health_worker',
        'Community Health Worker',
        'Community-based health worker.'
    ),
    (
        'social_worker',
        'Social Worker',
        'Social care and support professional.'
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 9
-- ORGANIZATION — SPECIALTIES
-- ============================================================================

INSERT INTO organization.specialty
    (code, label)
VALUES
    ('internal_medicine',       'Internal Medicine'),
    ('surgery',                  'Surgery'),
    ('paediatrics',              'Paediatrics'),
    ('obstetrics_gynaecology',   'Obstetrics & Gynaecology'),
    ('family_medicine',          'Family Medicine'),
    ('emergency_medicine',       'Emergency Medicine'),
    ('anaesthesiology',          'Anaesthesiology'),
    ('radiology',                'Radiology'),
    ('laboratory_medicine',      'Laboratory Medicine'),
    ('psychiatry',               'Psychiatry'),
    ('dermatology',              'Dermatology'),
    ('neurology',                'Neurology'),
    ('neurosurgery',             'Neurosurgery'),
    ('cardiology',               'Cardiology'),
    ('pulmonology',              'Pulmonology'),
    ('nephrology',               'Nephrology'),
    ('gastroenterology',         'Gastroenterology'),
    ('endocrinology',            'Endocrinology'),
    ('rheumatology',              'Rheumatology'),
    ('infectious_diseases',      'Infectious Diseases'),
    ('haematology',              'Haematology'),
    ('oncology',                 'Oncology'),
    ('critical_care',            'Critical Care'),
    ('orthopaedics',             'Orthopaedics'),
    ('urology',                  'Urology'),
    ('ent',                      'Ear, Nose & Throat'),
    ('ophthalmology',            'Ophthalmology'),
    ('dentistry',                'Dentistry'),
    ('pathology',                'Pathology'),
    ('public_health',            'Public Health'),
    ('rehabilitation_medicine',  'Rehabilitation Medicine')
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 10
-- ORGANIZATION — SUBSPECIALTIES
-- ============================================================================

INSERT INTO organization.subspecialty
    (code, specialty_code, label)
VALUES

    -- Internal Medicine
    ('cardiology',          'internal_medicine', 'Cardiology'),
    ('pulmonology',         'internal_medicine', 'Pulmonology'),
    ('nephrology',          'internal_medicine', 'Nephrology'),
    ('gastroenterology',    'internal_medicine', 'Gastroenterology'),
    ('endocrinology',       'internal_medicine', 'Endocrinology'),
    ('rheumatology',        'internal_medicine', 'Rheumatology'),
    ('infectious_diseases', 'internal_medicine', 'Infectious Diseases'),
    ('haematology',         'internal_medicine', 'Haematology'),
    ('medical_oncology',    'internal_medicine', 'Medical Oncology'),
    ('geriatric_medicine',  'internal_medicine', 'Geriatric Medicine'),

    -- Surgery
    ('general_surgery',     'surgery', 'General Surgery'),
    ('orthopaedics',        'surgery', 'Orthopaedics'),
    ('urology',             'surgery', 'Urology'),
    ('neurosurgery',        'surgery', 'Neurosurgery'),
    ('paediatric_surgery',  'surgery', 'Paediatric Surgery'),
    ('plastic_surgery',     'surgery', 'Plastic Surgery'),
    ('vascular_surgery',    'surgery', 'Vascular Surgery'),
    ('cardiothoracic',      'surgery', 'Cardiothoracic Surgery'),

    -- Paediatrics
    ('neonatology',         'paediatrics', 'Neonatology'),
    ('paediatric_cardiology','paediatrics', 'Paediatric Cardiology'),
    ('paediatric_neurology','paediatrics', 'Paediatric Neurology'),
    ('paediatric_nephrology','paediatrics', 'Paediatric Nephrology'),
    ('paediatric_infectious_diseases','paediatrics','Paediatric Infectious Diseases'),

    -- OBGYN
    ('maternal_fetal_medicine','obstetrics_gynaecology','Maternal-Fetal Medicine'),
    ('reproductive_medicine','obstetrics_gynaecology','Reproductive Medicine'),
    ('gynaecologic_oncology','obstetrics_gynaecology','Gynaecologic Oncology'),
    ('urogynaecology','obstetrics_gynaecology','Urogynaecology'),

    -- Emergency
    ('emergency_critical_care','emergency_medicine','Emergency Critical Care'),

    -- Psychiatry
    ('child_adolescent_psychiatry','psychiatry','Child & Adolescent Psychiatry'),
    ('addiction_psychiatry','psychiatry','Addiction Psychiatry'),

    -- Radiology
    ('interventional_radiology','radiology','Interventional Radiology'),

    -- Pathology
    ('histopathology','pathology','Histopathology'),
    ('haematopathology','pathology','Haematopathology'),
    ('chemical_pathology','pathology','Chemical Pathology'),
    ('microbiology','pathology','Medical Microbiology')
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 11
-- TERMINOLOGY — CODE SYSTEMS
-- ============================================================================

INSERT INTO terminology.code_system
    (id, name, oid, canonical_uri, version)
VALUES
    (
        '00000000-0000-0000-0000-000000000101',
        'SNOMED CT',
        '2.16.840.1.113883.6.96',
        'http://snomed.info/sct',
        '2025-01'
    ),
    (
        '00000000-0000-0000-0000-000000000102',
        'ICD-10',
        '2.16.840.1.113883.6.3',
        'http://hl7.org/fhir/sid/icd-10',
        '2019'
    ),
    (
        '00000000-0000-0000-0000-000000000103',
        'LOINC',
        '2.16.840.1.113883.6.1',
        'http://loinc.org',
        '2.77'
    ),
    (
        '00000000-0000-0000-0000-000000000104',
        'ICD-11',
        NULL,
        'http://id.who.int/icd/entity',
        '2026'
    ),
    (
        '00000000-0000-0000-0000-000000000105',
        'RxNorm',
        '2.16.840.1.113883.6.88',
        'http://www.nlm.nih.gov/research/umls/rxnorm',
        'current'
    ),
    (
        '00000000-0000-0000-0000-000000000106',
        'Local',
        NULL,
        NULL,
        '1.0'
    )
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 12
-- TERMINOLOGY — UNIVERSAL UNITS
-- ============================================================================

INSERT INTO terminology.unit
    (code, label, dimension, symbol, si_unit_code)
VALUES

    -- Ratio / percentage
    ('%',            'Percent',                     'ratio',                   '%',       NULL),
    ('ratio',        'Ratio',                       'ratio',                   'ratio',   NULL),

    -- Pressure
    ('mmHg',         'Millimetres of mercury',      'pressure',               'mmHg',    NULL),
    ('cmH2O',        'Centimetres of water',        'pressure',               'cmH2O',   NULL),
    ('kPa',           'Kilopascal',                 'pressure',               'kPa',     NULL),

    -- Rate
    ('bpm',          'Beats per minute',            'rate',                   'bpm',     NULL),
    ('breaths/min',  'Breaths per minute',          'rate',                   '/min',    NULL),
    ('per_min',      'Per minute',                  'rate',                   '/min',    NULL),

    -- Temperature
    ('degC',         'Degrees Celsius',             'temperature',             '°C',      NULL),
    ('degF',         'Degrees Fahrenheit',          'temperature',             '°F',      'degC'),
    ('K',            'Kelvin',                     'temperature',             'K',       NULL),

    -- Mass
    ('kg',           'Kilogram',                    'mass',                   'kg',      NULL),
    ('g',            'Gram',                        'mass',                   'g',       NULL),
    ('mg',           'Milligram',                  'mass',                   'mg',      NULL),
    ('mcg',          'Microgram',                  'mass',                   'mcg',     NULL),

    -- Length
    ('m',            'Metre',                      'length',                 'm',       NULL),
    ('cm',           'Centimetre',                 'length',                 'cm',      NULL),
    ('mm',           'Millimetre',                 'length',                 'mm',      NULL),

    -- Volume
    ('L',            'Litre',                      'volume',                 'L',       NULL),
    ('mL',            'Millilitre',                'volume',                 'mL',      NULL),
    ('dL',            'Decilitre',                 'volume',                 'dL',      NULL),

    -- Concentration
    ('mg/dL',        'Milligrams per decilitre',   'mass concentration',     'mg/dL',   NULL),
    ('mmol/L',       'Millimoles per litre',       'amount concentration',   'mmol/L',   NULL),
    ('g/dL',         'Grams per decilitre',        'mass concentration',     'g/dL',    NULL),
    ('g/L',          'Grams per litre',            'mass concentration',     'g/L',     NULL),
    ('mg/L',         'Milligrams per litre',       'mass concentration',     'mg/L',    NULL),
    ('IU/L',         'International units per litre','activity concentration','IU/L',    NULL),
    ('U/L',          'Units per litre',            'activity concentration', 'U/L',     NULL),

    -- Flow
    ('mL/min',       'Millilitres per minute',     'flow',                  'mL/min',  NULL),
    ('mL/hr',        'Millilitres per hour',       'flow',                  'mL/hr',   NULL),

    -- Time
    ('s',            'Second',                     'time',                   's',       NULL),
    ('min',          'Minute',                     'time',                   'min',     NULL),
    ('hr',           'Hour',                       'time',                   'hr',      NULL),
    ('day',          'Day',                       'time',                   'day',     NULL),
    ('week',         'Week',                      'time',                   'week',    NULL),
    ('month',        'Month',                     'time',                   'month',   NULL),
    ('year',         'Year',                      'time',                   'year',    NULL)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 13
-- TERMINOLOGY — UNIT CONVERSIONS
-- ============================================================================

INSERT INTO terminology.unit_conversion
    (from_unit_code, to_unit_code, factor, offset_value)
VALUES
    ('degC', 'degF', 1.8, 32),
    ('degF', 'degC', 0.5555555556, -17.77777778),

    ('m',    'cm',   100, 0),
    ('cm',   'm',    0.01, 0),

    ('kg',   'g',    1000, 0),
    ('g',    'kg',   0.001, 0),

    ('g',    'mg',   1000, 0),
    ('mg',   'g',    0.001, 0),

    ('mg',   'mcg',  1000, 0),
    ('mcg',  'mg',   0.001, 0),

    ('L',    'mL',   1000, 0),
    ('mL',   'L',    0.001, 0),

    ('day',  'hr',   24, 0),
    ('hr',   'min',  60, 0),
    ('min',  's',    60, 0)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 14
-- TERMINOLOGY — CORE UNIVERSAL CONCEPTS
-- ============================================================================
--
-- These are deliberately broad concepts.
--
-- They are NOT diagnostic rules.
-- They allow the AMEXAN CPU to reason from observations, complaints,
-- findings and clinical facts without hard-coding every term into application
-- code.
-- ============================================================================

INSERT INTO terminology.concept
    (id, display_name, definition)
VALUES

    -- ------------------------------------------------------------------------
    -- Symptoms
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a001',
        'Cough',
        'A forceful expiratory respiratory event that may be voluntary or reflex.'
    ),

    (
        '00000000-0000-0000-0000-00000000a002',
        'Fever',
        'An elevated body temperature associated with a regulated increase in temperature set point.'
    ),

    (
        '00000000-0000-0000-0000-00000000a003',
        'Dyspnoea',
        'Subjective difficulty or discomfort associated with breathing.'
    ),

    (
        '00000000-0000-0000-0000-00000000a004',
        'Tuberculosis',
        'Infectious disease caused by organisms of the Mycobacterium tuberculosis complex.'
    ),

    (
        '00000000-0000-0000-0000-00000000a005',
        'Chest Pain',
        'Pain or discomfort perceived in the chest region.'
    ),

    (
        '00000000-0000-0000-0000-00000000a006',
        'Abdominal Pain',
        'Pain or discomfort perceived in the abdominal region.'
    ),

    (
        '00000000-0000-0000-0000-00000000a007',
        'Headache',
        'Pain or discomfort perceived in the head.'
    ),

    (
        '00000000-0000-0000-0000-00000000a008',
        'Vomiting',
        'Forceful expulsion of gastric contents through the mouth.'
    ),

    (
        '00000000-0000-0000-0000-00000000a009',
        'Diarrhoea',
        'Passage of unusually loose or watery stools, generally with increased frequency or volume.'
    ),

    (
        '00000000-0000-0000-0000-00000000a010',
        'Fatigue',
        'Subjective feeling of tiredness or reduced energy.'
    ),

    (
        '00000000-0000-0000-0000-00000000a011',
        'Weakness',
        'Subjective or objective reduction in strength.'
    ),

    (
        '00000000-0000-0000-0000-00000000a012',
        'Dizziness',
        'Subjective sensation that may include lightheadedness, disequilibrium or a sense of motion.'
    ),

    (
        '00000000-0000-0000-0000-00000000a013',
        'Palpitations',
        'Awareness of the heartbeat or an abnormal sensation of cardiac activity.'
    ),

    (
        '00000000-0000-0000-0000-00000000a014',
        'Syncope',
        'Transient loss of consciousness due to transient global cerebral hypoperfusion with spontaneous recovery.'
    ),

    (
        '00000000-0000-0000-0000-00000000a015',
        'Convulsion',
        'An episode of involuntary abnormal motor activity that may occur with or without impaired consciousness.'
    ),

    (
        '00000000-0000-0000-0000-00000000a016',
        'Loss of Appetite',
        'Reduced desire to eat.'
    ),

    (
        '00000000-0000-0000-0000-00000000a017',
        'Weight Loss',
        'Reduction in body weight over time.'
    ),

    (
        '00000000-0000-0000-0000-00000000a018',
        'Weight Gain',
        'Increase in body weight over time.'
    ),

    -- ------------------------------------------------------------------------
    -- Respiratory
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a020',
        'Wheeze',
        'A continuous musical respiratory sound, usually more prominent during expiration.'
    ),

    (
        '00000000-0000-0000-0000-00000000a021',
        'Haemoptysis',
        'Expectoration of blood originating from the lower respiratory tract.'
    ),

    (
        '00000000-0000-0000-0000-00000000a022',
        'Sputum Production',
        'Production and expectoration of mucus or other material from the lower respiratory tract.'
    ),

    (
        '00000000-0000-0000-0000-00000000a023',
        'Stridor',
        'A harsh, predominantly inspiratory respiratory sound caused by upper airway narrowing.'
    ),

    (
        '00000000-0000-0000-0000-00000000a024',
        'Cyanosis',
        'Bluish discoloration associated with increased concentration of deoxygenated haemoglobin or abnormal haemoglobin.'
    ),

    -- ------------------------------------------------------------------------
    -- General clinical findings
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a030',
        'Oedema',
        'Abnormal accumulation of fluid within interstitial tissues.'
    ),

    (
        '00000000-0000-0000-0000-00000000a031',
        'Jaundice',
        'Yellow discoloration of the skin, sclerae or mucous membranes associated with increased bilirubin.'
    ),

    (
        '00000000-0000-0000-0000-00000000a032',
        'Pallor',
        'Paleness of skin or mucous membranes relative to the expected appearance.'
    ),

    (
        '00000000-0000-0000-0000-00000000a033',
        'Lymphadenopathy',
        'Abnormal enlargement or abnormality of lymph nodes.'
    ),

    -- ------------------------------------------------------------------------
    -- Core diseases / conditions
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a040',
        'Pneumonia',
        'Infection or inflammation involving the pulmonary parenchyma.'
    ),

    (
        '00000000-0000-0000-0000-00000000a041',
        'Asthma',
        'A chronic inflammatory airway disorder characterized by variable respiratory symptoms and variable expiratory airflow limitation.'
    ),

    (
        '00000000-0000-0000-0000-00000000a042',
        'Hypertension',
        'Persistently elevated arterial blood pressure diagnosed according to the applicable clinical definition and measurement context.'
    ),

    (
        '00000000-0000-0000-0000-00000000a043',
        'Diabetes Mellitus',
        'A group of metabolic disorders characterized by chronic hyperglycaemia resulting from impaired insulin secretion, insulin action, or both.'
    ),

    (
        '00000000-0000-0000-0000-00000000a044',
        'Anaemia',
        'A reduction in haemoglobin concentration below the appropriate reference threshold for the individual clinical context.'
    ),

    (
        '00000000-0000-0000-0000-00000000a045',
        'Heart Failure',
        'Clinical syndrome caused by structural and/or functional cardiac abnormality resulting in symptoms and signs with evidence of elevated filling pressures and/or inadequate cardiac output.'
    ),

    (
        '00000000-0000-0000-0000-00000000a046',
        'Chronic Kidney Disease',
        'Abnormality of kidney structure or function that persists for the clinically defined chronic period.'
    ),

    (
        '00000000-0000-0000-0000-00000000a047',
        'Malaria',
        'Parasitic infection caused by Plasmodium species and transmitted primarily by infected Anopheles mosquitoes.'
    ),

    (
        '00000000-0000-0000-0000-00000000a048',
        'HIV Infection',
        'Infection with human immunodeficiency virus.'
    ),

    -- ------------------------------------------------------------------------
    -- Reproductive / obstetric
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a050',
        'Pregnancy',
        'The state of carrying a developing embryo or fetus within the uterus.'
    ),

    (
        '00000000-0000-0000-0000-00000000a051',
        'Labour',
        'The physiological process involving uterine contractions and cervical change leading to birth.'
    ),

    (
        '00000000-0000-0000-0000-00000000a052',
        'Postpartum State',
        'The period following childbirth during which the mother undergoes physiological recovery and adaptation.'
    ),

    (
        '00000000-0000-0000-0000-00000000a053',
        'Vaginal Bleeding',
        'Bleeding originating from the female genital tract.'
    ),

    (
        '00000000-0000-0000-0000-00000000a054',
        'Vaginal Discharge',
        'Fluid discharged from the vagina.'
    ),

    -- ------------------------------------------------------------------------
    -- Paediatrics
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a060',
        'Poor Feeding',
        'Reduced or inadequate intake of feeds relative to expected requirements.'
    ),

    (
        '00000000-0000-0000-0000-00000000a061',
        'Failure to Thrive',
        'Growth pattern that is inadequate for the expected trajectory and requires clinical assessment.'
    ),

    (
        '00000000-0000-0000-0000-00000000a062',
        'Developmental Delay',
        'Failure to attain one or more developmental milestones within the expected range.'
    ),

    -- ------------------------------------------------------------------------
    -- Mental health
    -- ------------------------------------------------------------------------

    (
        '00000000-0000-0000-0000-00000000a070',
        'Depressed Mood',
        'Persistent or clinically significant low mood or sadness.'
    ),

    (
        '00000000-0000-0000-0000-00000000a071',
        'Anxiety',
        'Excessive or clinically significant fear, worry or apprehension.'
    ),

    (
        '00000000-0000-0000-0000-00000000a072',
        'Suicidal Ideation',
        'Thoughts or consideration of ending one''s own life.'
    )

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 15
-- TERMINOLOGY — SYNONYMS
-- ============================================================================

INSERT INTO terminology.concept_synonym
    (concept_id, synonym, language_code, is_preferred)
VALUES

    -- Cough
    ('00000000-0000-0000-0000-00000000a001', 'Cough',    'en', true),
    ('00000000-0000-0000-0000-00000000a001', 'Kikohozi', 'sw', true),

    -- Fever
    ('00000000-0000-0000-0000-00000000a002', 'Fever',    'en', true),
    ('00000000-0000-0000-0000-00000000a002', 'Homa',     'sw', true),

    -- Dyspnoea
    ('00000000-0000-0000-0000-00000000a003', 'Dyspnoea', 'en', true),
    ('00000000-0000-0000-0000-00000000a003', 'Dyspnea',  'en', false),
    ('00000000-0000-0000-0000-00000000a003', 'Shortness of breath', 'en', false),
    ('00000000-0000-0000-0000-00000000a003', 'Upungufu wa pumzi', 'sw', true),

    -- Tuberculosis
    ('00000000-0000-0000-0000-00000000a004', 'Tuberculosis', 'en', true),
    ('00000000-0000-0000-0000-00000000a004', 'TB',          'en', false),
    ('00000000-0000-0000-0000-00000000a004', 'Kifua Kikuu', 'sw', true),

    -- Chest pain
    ('00000000-0000-0000-0000-00000000a005', 'Chest pain', 'en', true),
    ('00000000-0000-0000-0000-00000000a005', 'Maumivu ya kifua', 'sw', true),

    -- Abdominal pain
    ('00000000-0000-0000-0000-00000000a006', 'Abdominal pain', 'en', true),
    ('00000000-0000-0000-0000-00000000a006', 'Stomach pain', 'en', false),
    ('00000000-0000-0000-0000-00000000a006', 'Maumivu ya tumbo', 'sw', true),

    -- Vomiting
    ('00000000-0000-0000-0000-00000000a008', 'Vomiting', 'en', true),
    ('00000000-0000-0000-0000-00000000a008', 'Emesis',   'en', false),
    ('00000000-0000-0000-0000-00000000a008', 'Kutapika', 'sw', true),

    -- Diarrhoea
    ('00000000-0000-0000-0000-00000000a009', 'Diarrhoea', 'en', true),
    ('00000000-0000-0000-0000-00000000a009', 'Diarrhea', 'en', false),
    ('00000000-0000-0000-0000-00000000a009', 'Kuhara',   'sw', true),

    -- Wheeze
    ('00000000-0000-0000-0000-00000000a020', 'Wheeze', 'en', true),
    ('00000000-0000-0000-0000-00000000a020', 'Wheezing', 'en', false),

    -- Haemoptysis
    ('00000000-0000-0000-0000-00000000a021', 'Haemoptysis', 'en', true),
    ('00000000-0000-0000-0000-00000000a021', 'Hemoptysis',  'en', false),

    -- Pneumonia
    ('00000000-0000-0000-0000-00000000a040', 'Pneumonia', 'en', true),
    ('00000000-0000-0000-0000-00000000a040', 'Nimonia',   'sw', true),

    -- Asthma
    ('00000000-0000-0000-0000-00000000a041', 'Asthma', 'en', true),
    ('00000000-0000-0000-0000-00000000a041', 'Pumu',   'sw', true),

    -- Hypertension
    ('00000000-0000-0000-0000-00000000a042', 'Hypertension', 'en', true),
    ('00000000-0000-0000-0000-00000000a042', 'High blood pressure', 'en', false),
    ('00000000-0000-0000-0000-00000000a042', 'Shinikizo la damu', 'sw', true),

    -- Diabetes
    ('00000000-0000-0000-0000-00000000a043', 'Diabetes mellitus', 'en', true),
    ('00000000-0000-0000-0000-00000000a043', 'Diabetes', 'en', false),
    ('00000000-0000-0000-0000-00000000a043', 'Kisukari', 'sw', true),

    -- Anaemia
    ('00000000-0000-0000-0000-00000000a044', 'Anaemia', 'en', true),
    ('00000000-0000-0000-0000-00000000a044', 'Anemia', 'en', false),
    ('00000000-0000-0000-0000-00000000a044', 'Upungufu wa damu', 'sw', true),

    -- Malaria
    ('00000000-0000-0000-0000-00000000a047', 'Malaria', 'en', true),
    ('00000000-0000-0000-0000-00000000a047', 'Malaria', 'sw', true),

    -- Pregnancy
    ('00000000-0000-0000-0000-00000000a050', 'Pregnancy', 'en', true),
    ('00000000-0000-0000-0000-00000000a050', 'Ujauzito',  'sw', true)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 16
-- TERMINOLOGY — TRANSLATIONS
-- ============================================================================

INSERT INTO terminology.concept_translation
    (concept_id, language_code, translation, is_preferred)
VALUES

    ('00000000-0000-0000-0000-00000000a001', 'sw', 'Kikohozi', true),
    ('00000000-0000-0000-0000-00000000a002', 'sw', 'Homa', true),
    ('00000000-0000-0000-0000-00000000a003', 'sw', 'Upungufu wa pumzi', true),
    ('00000000-0000-0000-0000-00000000a004', 'sw', 'Kifua Kikuu', true),
    ('00000000-0000-0000-0000-00000000a005', 'sw', 'Maumivu ya kifua', true),
    ('00000000-0000-0000-0000-00000000a006', 'sw', 'Maumivu ya tumbo', true),
    ('00000000-0000-0000-0000-00000000a008', 'sw', 'Kutapika', true),
    ('00000000-0000-0000-0000-00000000a009', 'sw', 'Kuhara', true),
    ('00000000-0000-0000-0000-00000000a040', 'sw', 'Nimonia', true),
    ('00000000-0000-0000-0000-00000000a042', 'sw', 'Shinikizo la damu', true),
    ('00000000-0000-0000-0000-00000000a043', 'sw', 'Kisukari', true),
    ('00000000-0000-0000-0000-00000000a044', 'sw', 'Upungufu wa damu', true),
    ('00000000-0000-0000-0000-00000000a050', 'sw', 'Ujauzito', true)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 17
-- TERMINOLOGY — EXTERNAL CODES
-- ============================================================================
--
-- These provide interoperability anchors.
--
-- IMPORTANT:
-- Do not interpret these codes as CPU reasoning.
-- The CPU may use terminology mappings, but diagnostic reasoning belongs
-- to the knowledge/rule layer.
-- ============================================================================

INSERT INTO terminology.code
    (id, code_system_id, code, display)
VALUES

    -- SNOMED CT
    (
        '00000000-0000-0000-0000-00000000b001',
        '00000000-0000-0000-0000-000000000101',
        '49727002',
        'Cough'
    ),

    (
        '00000000-0000-0000-0000-00000000b002',
        '00000000-0000-0000-0000-000000000101',
        '386661006',
        'Fever'
    ),

    (
        '00000000-0000-0000-0000-00000000b003',
        '00000000-0000-0000-0000-000000000101',
        '267036007',
        'Dyspnoea'
    ),

    (
        '00000000-0000-0000-0000-00000000b004',
        '00000000-0000-0000-0000-000000000101',
        '233604007',
        'Pneumonia'
    ),

    (
        '00000000-0000-0000-0000-00000000b005',
        '00000000-0000-0000-0000-000000000101',
        '195967001',
        'Asthma'
    ),

    -- ICD-10
    (
        '00000000-0000-0000-0000-00000000b010',
        '00000000-0000-0000-0000-000000000102',
        'R05',
        'Cough'
    ),

    (
        '00000000-0000-0000-0000-00000000b011',
        '00000000-0000-0000-0000-000000000102',
        'R50.9',
        'Fever, unspecified'
    ),

    (
        '00000000-0000-0000-0000-00000000b012',
        '00000000-0000-0000-0000-000000000102',
        'R06.0',
        'Dyspnoea'
    ),

    (
        '00000000-0000-0000-0000-00000000b013',
        '00000000-0000-0000-0000-000000000102',
        'J18.9',
        'Pneumonia, unspecified organism'
    ),

    (
        '00000000-0000-0000-0000-00000000b014',
        '00000000-0000-0000-0000-000000000102',
        'J45.9',
        'Asthma, unspecified'
    ),

    (
        '00000000-0000-0000-0000-00000000b015',
        '00000000-0000-0000-0000-000000000102',
        'A15',
        'Respiratory tuberculosis'
    ),

    -- LOINC examples
    (
        '00000000-0000-0000-0000-00000000b020',
        '00000000-0000-0000-0000-000000000103',
        '8310-5',
        'Body temperature'
    ),

    (
        '00000000-0000-0000-0000-00000000b021',
        '00000000-0000-0000-0000-000000000103',
        '8867-4',
        'Heart rate'
    ),

    (
        '00000000-0000-0000-0000-00000000b022',
        '00000000-0000-0000-0000-000000000103',
        '9279-1',
        'Respiratory rate'
    ),

    (
        '00000000-0000-0000-0000-00000000b023',
        '00000000-0000-0000-0000-000000000103',
        '8480-6',
        'Systolic blood pressure'
    ),

    (
        '00000000-0000-0000-0000-00000000b024',
        '00000000-0000-0000-0000-000000000103',
        '8462-4',
        'Diastolic blood pressure'
    ),

    (
        '00000000-0000-0000-0000-00000000b025',
        '00000000-0000-0000-0000-000000000103',
        '2708-6',
        'Oxygen saturation'
    )

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 18
-- TERMINOLOGY — CONCEPT ↔ CODE MAPPINGS
-- ============================================================================

INSERT INTO terminology.concept_code
    (concept_id, code_id, relationship)
VALUES

    -- Cough
    (
        '00000000-0000-0000-0000-00000000a001',
        '00000000-0000-0000-0000-00000000b001',
        'equivalent'
    ),
    (
        '00000000-0000-0000-0000-00000000a001',
        '00000000-0000-0000-0000-00000000b010',
        'equivalent'
    ),

    -- Fever
    (
        '00000000-0000-0000-0000-00000000a002',
        '00000000-0000-0000-0000-00000000b002',
        'equivalent'
    ),
    (
        '00000000-0000-0000-0000-00000000a002',
        '00000000-0000-0000-0000-00000000b011',
        'equivalent'
    ),

    -- Dyspnoea
    (
        '00000000-0000-0000-0000-00000000a003',
        '00000000-0000-0000-0000-00000000b003',
        'equivalent'
    ),
    (
        '00000000-0000-0000-0000-00000000a003',
        '00000000-0000-0000-0000-00000000b012',
        'equivalent'
    ),

    -- Pneumonia
    (
        '00000000-0000-0000-0000-00000000a040',
        '00000000-0000-0000-0000-00000000b004',
        'equivalent'
    ),
    (
        '00000000-0000-0000-0000-00000000a040',
        '00000000-0000-0000-0000-00000000b013',
        'equivalent'
    ),

    -- Asthma
    (
        '00000000-0000-0000-0000-00000000a041',
        '00000000-0000-0000-0000-00000000b005',
        'terminology_anchor'
    )

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 19
-- TERMINOLOGY — CORE VALUE SETS
-- ============================================================================

INSERT INTO terminology.value_set
    (id, key, name, description)
VALUES

    (
        '00000000-0000-0000-0000-00000000c001',
        'vital_sign_parameters',
        'Vital Sign Parameters',
        'Core physiological measurements used for routine clinical assessment.'
    ),

    (
        '00000000-0000-0000-0000-00000000c002',
        'common_clinical_symptoms',
        'Common Clinical Symptoms',
        'Universal symptom concepts used across clinical presentations.'
    ),

    (
        '00000000-0000-0000-0000-00000000c003',
        'respiratory_symptoms',
        'Respiratory Symptoms',
        'Symptoms and findings associated with respiratory presentations.'
    ),

    (
        '00000000-0000-0000-0000-00000000c004',
        'cardiovascular_symptoms',
        'Cardiovascular Symptoms',
        'Symptoms and findings associated with cardiovascular presentations.'
    ),

    (
        '00000000-0000-0000-0000-00000000c005',
        'gastrointestinal_symptoms',
        'Gastrointestinal Symptoms',
        'Symptoms and findings associated with gastrointestinal presentations.'
    ),

    (
        '00000000-0000-0000-0000-00000000c006',
        'neurological_symptoms',
        'Neurological Symptoms',
        'Symptoms and findings associated with neurological presentations.'
    ),

    (
        '00000000-0000-0000-0000-00000000c007',
        'obstetric_symptoms',
        'Obstetric Symptoms',
        'Symptoms and presentations relevant to pregnancy and obstetric care.'
    ),

    (
        '00000000-0000-0000-0000-00000000c008',
        'paediatric_presentations',
        'Paediatric Presentations',
        'Common clinical presentations relevant to paediatric care.'
    ),

    (
        '00000000-0000-0000-0000-00000000c009',
        'mental_health_presentations',
        'Mental Health Presentations',
        'Core mental and behavioural health presentations.'
    ),

    (
        '00000000-0000-0000-0000-00000000c010',
        'clinical_units',
        'Clinical Units',
        'Units commonly used for clinical observations, measurements and laboratory data.'
    )

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- SECTION 20
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM identity.language
        WHERE code = 'en'
    ) THEN
        RAISE EXCEPTION 'AMEXAN Seed A verification failed: English language missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM encounter.encounter_type
        WHERE code = 'opd'
    ) THEN
        RAISE EXCEPTION 'AMEXAN Seed A verification failed: OPD encounter type missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM organization.profession
        WHERE code = 'doctor'
    ) THEN
        RAISE EXCEPTION 'AMEXAN Seed A verification failed: doctor profession missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM terminology.code_system
        WHERE name = 'SNOMED CT'
    ) THEN
        RAISE EXCEPTION 'AMEXAN Seed A verification failed: SNOMED CT missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM terminology.unit
        WHERE code = 'mmHg'
    ) THEN
        RAISE EXCEPTION 'AMEXAN Seed A verification failed: mmHg unit missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM terminology.concept
        WHERE display_name = 'Cough'
    ) THEN
        RAISE EXCEPTION 'AMEXAN Seed A verification failed: Cough concept missing';
    END IF;

END $$;


-- ============================================================================
-- SEED SUMMARY
-- ============================================================================

SELECT
    'AMEXAN PHASE 1 — SEED A COMPLETE' AS status,
    now() AS seeded_at;


SELECT
    'identity.language' AS table_name,
    COUNT(*) AS row_count
FROM identity.language

UNION ALL

SELECT
    'identity.person_status',
    COUNT(*)
FROM identity.person_status

UNION ALL

SELECT
    'patient.patient_status',
    COUNT(*)
FROM patient.patient_status

UNION ALL

SELECT
    'encounter.encounter_type',
    COUNT(*)
FROM encounter.encounter_type

UNION ALL

SELECT
    'encounter.encounter_status',
    COUNT(*)
FROM encounter.encounter_status

UNION ALL

SELECT
    'encounter.encounter_phase',
    COUNT(*)
FROM encounter.encounter_phase

UNION ALL

SELECT
    'encounter.encounter_priority',
    COUNT(*)
FROM encounter.encounter_priority

UNION ALL

SELECT
    'organization.profession',
    COUNT(*)
FROM organization.profession

UNION ALL

SELECT
    'organization.specialty',
    COUNT(*)
FROM organization.specialty

UNION ALL

SELECT
    'organization.subspecialty',
    COUNT(*)
FROM organization.subspecialty

UNION ALL

SELECT
    'terminology.code_system',
    COUNT(*)
FROM terminology.code_system

UNION ALL

SELECT
    'terminology.unit',
    COUNT(*)
FROM terminology.unit

UNION ALL

SELECT
    'terminology.concept',
    COUNT(*)
FROM terminology.concept

UNION ALL

SELECT
    'terminology.code',
    COUNT(*)
FROM terminology.code

UNION ALL

SELECT
    'terminology.value_set',
    COUNT(*)
FROM terminology.value_set;


-- ============================================================================
-- IMPORTANT
-- ============================================================================
--
-- Seed A establishes:
--
-- IDENTITY
--   languages
--   person states
--
-- PATIENT
--   patient lifecycle states
--
-- ENCOUNTER
--   encounter types
--   encounter states
--   encounter phases
--   encounter priorities
--
-- ORGANIZATION
--   professions
--   specialties
--   subspecialties
--
-- TERMINOLOGY
--   code systems
--   units
--   conversions
--   universal concepts
--   synonyms
--   translations
--   external terminology mappings
--   value sets
--
-- NOTHING HERE SHOULD DECIDE:
--
--   "What is the diagnosis?"
--   "What question should be asked next?"
--   "What examination should be performed?"
--   "What disease is most likely?"
--   "What treatment should be prescribed?"
--
-- Those belong to AMEXAN KNOWLEDGE + CPU.
--
-- ============================================================================

COMMIT;