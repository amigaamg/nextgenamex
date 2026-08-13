-- =============================================================================
-- AMEXAN Phase 1 — Seed A: identity, patient, encounter, organization, terminology
-- =============================================================================
-- Pure reference data. No patient data, no disease logic. Idempotent.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- identity
-- ---------------------------------------------------------------------------

INSERT INTO identity.language (code, label, native_label) VALUES
   ('en',  'English',   'English'),
   ('sw',  'Kiswahili', 'Kiswahili'),
   ('luo', 'Dholuo',    'Dholuo'),
   ('fr',  'French',    'French')
ON CONFLICT (code) DO NOTHING;

INSERT INTO identity.person_status (code, label, description) VALUES
   ('active',   'Active',   'Person is alive and active'),
   ('inactive', 'Inactive', 'Record exists but is not currently active'),
   ('deceased', 'Deceased', 'Person has died'),
   ('unknown',  'Unknown',  'Status unknown')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- patient
-- ---------------------------------------------------------------------------

INSERT INTO patient.patient_status (code, label, description) VALUES
   ('active',   'Active',   'Open patient record'),
   ('inactive', 'Inactive', 'Record closed'),
   ('deceased', 'Deceased', 'Patient is deceased'),
   ('archived', 'Archived', 'Record archived')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- encounter
-- ---------------------------------------------------------------------------

INSERT INTO encounter.encounter_type (code, label, description) VALUES
   ('opd',             'Outpatient',          'Outpatient department visit'),
   ('ipd',             'Inpatient',           'Inpatient admission/ward stay'),
   ('emergency',       'Emergency',           'Emergency department visit'),
   ('telemedicine',    'Telemedicine',        'Remote consultation'),
   ('home_visit',      'Home visit',          'Care delivered at home'),
   ('community_visit', 'Community visit',     'Community/outreach visit'),
   ('procedure',       'Procedure',           'A procedure encounter'),
   ('discharge',       'Discharge',           'Discharge from care'),
   ('follow_up',       'Follow-up',           'Scheduled follow-up visit'),
   ('special_clinic',  'Special clinic',      'Specialty clinic visit')
ON CONFLICT (code) DO NOTHING;

INSERT INTO encounter.encounter_status (code, label, description) VALUES
   ('planned',   'Planned',   'Encounter has been created'),
   ('active',    'Active',    'Encounter is ongoing'),
   ('completed', 'Completed', 'Encounter finished'),
   ('cancelled', 'Cancelled', 'Encounter cancelled'),
   ('on_hold',   'On hold',   'Encounter temporarily paused')
ON CONFLICT (code) DO NOTHING;

INSERT INTO encounter.encounter_phase (code, label, description, sort_order) VALUES
   ('registration', 'Registration', 'Patient registered', 10),
   ('triage',       'Triage',       'Triage assessment', 20),
   ('consultation', 'Consultation', 'Clinician consultation', 30),
   ('assessment',   'Assessment',   'Assessment in progress', 40),
   ('investigation','Investigation','Investigations ordered', 50),
   ('treatment',    'Treatment',    'Treatment being delivered', 60),
   ('disposition',  'Disposition',  'Disposition decided', 70),
   ('completed',    'Completed',    'Encounter complete', 80)
ON CONFLICT (code) DO NOTHING;

INSERT INTO encounter.encounter_priority (code, label, sort_order) VALUES
   ('routine',  'Routine',  10),
   ('urgent',   'Urgent',   20),
   ('emergency','Emergency',30),
   ('stat',     'STAT',     40)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- organization
-- ---------------------------------------------------------------------------

INSERT INTO organization.profession (code, label, description) VALUES
   ('doctor',           'Doctor',           'Medical doctor'),
   ('clinical_officer', 'Clinical Officer', 'Clinical officer'),
   ('nurse',            'Nurse',            'Nurse'),
   ('midwife',          'Midwife',          'Midwife'),
   ('pharmacist',       'Pharmacist',       'Pharmacist'),
   ('lab_technician',   'Lab Technician',   'Laboratory technician'),
   ('radiographer',     'Radiographer',     'Radiographer'),
   ('nutritionist',     'Nutritionist',     'Nutritionist'),
   ('physiotherapist',  'Physiotherapist',  'Physiotherapist'),
   ('receptionist',     'Receptionist',     'Receptionist / front office')
ON CONFLICT (code) DO NOTHING;

INSERT INTO organization.specialty (code, label) VALUES
   ('internal_medicine',     'Internal Medicine'),
   ('surgery',               'Surgery'),
   ('paediatrics',           'Paediatrics'),
   ('obstetrics_gynaecology','Obstetrics & Gynaecology'),
   ('family_medicine',       'Family Medicine'),
   ('emergency_medicine',    'Emergency Medicine'),
   ('radiology',             'Radiology'),
   ('laboratory_medicine',   'Laboratory Medicine')
ON CONFLICT (code) DO NOTHING;

INSERT INTO organization.subspecialty (code, specialty_code, label) VALUES
   ('cardiology',      'internal_medicine', 'Cardiology'),
   ('pulmonology',     'internal_medicine', 'Pulmonology'),
   ('nephrology',      'internal_medicine', 'Nephrology'),
   ('orthopaedics',    'surgery',           'Orthopaedics'),
   ('general_surgery', 'surgery',           'General Surgery'),
   ('neonatology',     'paediatrics',       'Neonatology')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- terminology
-- ---------------------------------------------------------------------------

INSERT INTO terminology.code_system (id, name, oid, uri, version) VALUES
   ('00000000-0000-0000-0000-000000000101', 'SNOMED CT', '2.16.840.1.113883.6.96', 'http://snomed.info/sct', '2025-01'),
   ('00000000-0000-0000-0000-000000000102', 'ICD-10',    '2.16.840.1.113883.6.3',  'http://hl7.org/fhir/sid/icd-10', '2019'),
   ('00000000-0000-0000-0000-000000000103', 'LOINC',     '2.16.840.1.113883.6.1',  'http://loinc.org', '2.77'),
   ('00000000-0000-0000-0000-000000000104', 'Local',     NULL, NULL, '1.0')
ON CONFLICT (id) DO NOTHING;

INSERT INTO terminology.unit (code, label, dimension, symbol, si_unit_code) VALUES
   ('%',           'percent',                'ratio',                 '%',    NULL),
   ('mmHg',        'millimetres of mercury', 'pressure',              'mmHg', NULL),
   ('bpm',         'beats per minute',       'rate',                  'bpm',  NULL),
   ('breaths/min', 'breaths per minute',     'rate',                  '/min', NULL),
   ('degC',        'degrees Celsius',        'temperature',           'degC', NULL),
   ('degF',        'degrees Fahrenheit',     'temperature',           'degF', 'degC'),
   ('kg',          'kilogram',               'mass',                  'kg',   NULL),
   ('cm',          'centimetre',             'length',                'cm',   NULL),
   ('m',           'metre',                  'length',                'm',    'cm'),
   ('mg/dL',       'milligrams per decilitre','mass concentration',   'mg/dL',NULL),
   ('mmol/L',      'millimoles per litre',   'amount concentration',  'mmol/L',NULL),
   ('g/dL',        'grams per decilitre',    'mass concentration',    'g/dL', NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO terminology.unit_conversion (from_unit_code, to_unit_code, factor, offset_value) VALUES
   ('degC', 'degF', 1.8, 32),
   ('degF', 'degC', 0.5555555556, -17.77777778),
   ('m',    'cm',   100, 0)
ON CONFLICT (from_unit_code, to_unit_code) DO NOTHING;

INSERT INTO terminology.concept (id, display_name, definition) VALUES
   ('00000000-0000-0000-0000-00000000a001', 'Cough',    'Expulsive expulsion of air from the airways'),
   ('00000000-0000-0000-0000-00000000a002', 'Fever',    'Elevated body temperature'),
   ('00000000-0000-0000-0000-00000000a003', 'Dyspnoea', 'Difficulty breathing / shortness of breath'),
   ('00000000-0000-0000-0000-00000000a004', 'Tuberculosis', 'Infectious disease caused by mycobacterium tuberculosis')
ON CONFLICT (id) DO NOTHING;

INSERT INTO terminology.concept_synonym (concept_id, synonym, language_code, is_preferred) VALUES
   ('00000000-0000-0000-0000-00000000a001', 'Cough',  'en', true),
   ('00000000-0000-0000-0000-00000000a001', 'Kikohozi', 'sw', true),
   ('00000000-0000-0000-0000-00000000a002', 'Fever',  'en', true),
   ('00000000-0000-0000-0000-00000000a002', 'Homa',   'sw', true),
   ('00000000-0000-0000-0000-00000000a004', 'TB',     'en', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO terminology.concept_translation (concept_id, language_code, translation, is_preferred) VALUES
   ('00000000-0000-0000-0000-00000000a001', 'sw', 'Kikohozi', true),
   ('00000000-0000-0000-0000-00000000a002', 'sw', 'Homa',     true),
   ('00000000-0000-0000-0000-00000000a003', 'sw', 'Upungufu wa pumzi', true)
ON CONFLICT (concept_id, language_code, translation) DO NOTHING;

INSERT INTO terminology.code (id, code_system_id, code, display) VALUES
   ('00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-000000000101', '49727002', 'Cough'),
   ('00000000-0000-0000-0000-00000000b002', '00000000-0000-0000-0000-000000000101', '386661006', 'Fever'),
   ('00000000-0000-0000-0000-00000000b003', '00000000-0000-0000-0000-000000000102', 'R05',      'Cough'),
   ('00000000-0000-0000-0000-00000000b004', '00000000-0000-0000-0000-000000000102', 'A15',      'Respiratory tuberculosis')
ON CONFLICT (id) DO NOTHING;

INSERT INTO terminology.concept_code (concept_id, code_id, relationship) VALUES
   ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b001', 'equivalent'),
   ('00000000-0000-0000-0000-00000000a001', '00000000-0000-0000-0000-00000000b003', 'equivalent'),
   ('00000000-0000-0000-0000-00000000a002', '00000000-0000-0000-0000-00000000b002', 'equivalent'),
   ('00000000-0000-0000-0000-00000000a004', '00000000-0000-0000-0000-00000000b004', 'equivalent')
ON CONFLICT (concept_id, code_id) DO NOTHING;

INSERT INTO terminology.value_set (id, name, description) VALUES
   ('00000000-0000-0000-0000-00000000c001', 'Vital Sign Parameters', 'Standard vital sign parameters (LOINC)')
ON CONFLICT (id) DO NOTHING;
