-- =============================================================================
-- AMEXAN Phase 1 — Seed C: clinical, workflow, document, configuration, system
-- =============================================================================
-- Idempotent reference/lookup data.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- clinical lookups
-- ---------------------------------------------------------------------------

INSERT INTO clinical.fact_status (code, label, description) VALUES
   ('entered',    'Entered',    'Fact entered, not yet confirmed'),
   ('active',     'Active',     'Fact is currently valid'),
   ('corrected',  'Corrected',  'Fact has been corrected'),
   ('superseded', 'Superseded', 'Fact replaced by a newer fact'),
   ('retracted',  'Retracted',  'Fact withdrawn')
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.problem_status (code, label, description) VALUES
   ('active',          'Active',          'Problem is currently active'),
   ('resolved',        'Resolved',        'Problem has resolved'),
   ('inactive',        'Inactive',        'Problem is inactive'),
   ('recurred',        'Recurred',        'Problem has recurred'),
   ('entered_in_error','Entered in error','Problem was recorded in error')
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.diagnosis_status (code, label, description) VALUES
   ('suspected',       'Suspected',       'Diagnosis suspected'),
   ('working',         'Working',         'Working diagnosis'),
   ('confirmed',       'Confirmed',       'Diagnosis confirmed'),
   ('final',           'Final',           'Final diagnosis'),
   ('ruled_out',       'Ruled out',       'Diagnosis excluded'),
   ('entered_in_error','Entered in error','Diagnosis recorded in error')
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.order_type (code, label, description) VALUES
   ('laboratory', 'Laboratory', 'Laboratory test order'),
   ('imaging',    'Imaging',    'Radiology/imaging order'),
   ('medication', 'Medication', 'Medication order'),
   ('procedure',  'Procedure',  'Procedure order'),
   ('nursing',    'Nursing',    'Nursing care order'),
   ('consultation','Consultation','Consultation request'),
   ('diet',       'Diet',       'Dietary order'),
   ('other',      'Other',      'Other order type')
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.order_status (code, label, description) VALUES
   ('draft',     'Draft',     'Order being drafted'),
   ('pending',   'Pending',   'Order submitted, awaiting processing'),
   ('active',    'Active',    'Order is being worked'),
   ('on_hold',   'On hold',   'Order temporarily paused'),
   ('completed', 'Completed', 'Order completed'),
   ('cancelled', 'Cancelled', 'Order cancelled'),
   ('resulted',  'Resulted',  'Result available')
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.order_priority (code, label, sort_order) VALUES
   ('routine', 'Routine', 10),
   ('urgent',  'Urgent',  20),
   ('stat',    'STAT',    30),
   ('asap',    'ASAP',    25)
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.care_team_role (code, label, description) VALUES
   ('attending',       'Attending',       'Attending clinician'),
   ('registrar',       'Registrar',       'Registrar'),
   ('intern',          'Intern',          'Medical intern'),
   ('nurse_in_charge', 'Nurse in charge', 'Nurse in charge'),
   ('consultant',      'Consultant',      'Consultant'),
   ('pharmacist',      'Pharmacist',      'Clinical pharmacist')
ON CONFLICT (code) DO NOTHING;

INSERT INTO clinical.consent_type (code, label, description) VALUES
   ('procedure',      'Procedure',      'Consent for a procedure'),
   ('treatment',      'Treatment',      'Consent for treatment'),
   ('surgery',        'Surgery',        'Consent for surgery'),
   ('blood_transfusion','Blood transfusion','Consent for blood transfusion'),
   ('research',       'Research',       'Consent for research participation'),
   ('imaging',        'Imaging',        'Consent for imaging'),
   ('anesthesia',     'Anesthesia',     'Consent for anesthesia')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- workflow
-- ---------------------------------------------------------------------------

INSERT INTO workflow.definition (id, code, name, description) VALUES
   ('00000000-0000-0000-0000-000000000401', 'outpatient_visit',  'Outpatient Visit',  'Standard outpatient workflow'),
   ('00000000-0000-0000-0000-000000000402', 'inpatient_admission','Inpatient Admission','Inpatient admission workflow')
ON CONFLICT (id) DO NOTHING;

INSERT INTO workflow.version (id, definition_id, version, is_active) VALUES
   ('00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000401', 1, true),
   ('00000000-0000-0000-0000-000000000412', '00000000-0000-0000-0000-000000000402', 1, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO workflow.state (id, code, label, state_kind) VALUES
   ('00000000-0000-0000-0000-000000000421', 'registration', 'Registration', 'start'),
   ('00000000-0000-0000-0000-000000000422', 'triage',       'Triage',       'middle'),
   ('00000000-0000-0000-0000-000000000423', 'assessment',   'Assessment',   'middle'),
   ('00000000-0000-0000-0000-000000000424', 'investigation','Investigation','middle'),
   ('00000000-0000-0000-0000-000000000425', 'treatment',    'Treatment',    'middle'),
   ('00000000-0000-0000-0000-000000000426', 'disposition',  'Disposition',  'middle'),
   ('00000000-0000-0000-0000-000000000427', 'completed',    'Completed',    'end')
ON CONFLICT (id) DO NOTHING;

INSERT INTO workflow.transition (id, workflow_version_id, from_state_id, to_state_id, name) VALUES
   ('00000000-0000-0000-0000-000000000431', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000421', '00000000-0000-0000-0000-000000000422', 'Register'),
   ('00000000-0000-0000-0000-000000000432', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000422', '00000000-0000-0000-0000-000000000423', 'Assess'),
   ('00000000-0000-0000-0000-000000000433', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000423', '00000000-0000-0000-0000-000000000424', 'Investigate'),
   ('00000000-0000-0000-0000-000000000434', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000423', '00000000-0000-0000-0000-000000000425', 'Treat'),
   ('00000000-0000-0000-0000-000000000435', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000424', '00000000-0000-0000-0000-000000000425', 'Treat'),
   ('00000000-0000-0000-0000-000000000436', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000425', '00000000-0000-0000-0000-000000000426', 'Disposition'),
   ('00000000-0000-0000-0000-000000000437', '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000426', '00000000-0000-0000-0000-000000000427', 'Complete')
ON CONFLICT (id) DO NOTHING;

INSERT INTO workflow.queue (id, code, name, description) VALUES
   ('00000000-0000-0000-0000-000000000441', 'triage_queue',  'Triage Queue',  'Patients awaiting triage'),
   ('00000000-0000-0000-0000-000000000442', 'consult_queue', 'Consultation Queue', 'Patients awaiting consultation'),
   ('00000000-0000-0000-0000-000000000443', 'lab_queue',     'Laboratory Queue', 'Laboratory work queue')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- document
-- ---------------------------------------------------------------------------

INSERT INTO document.document_type (code, label, description) VALUES
   ('hpi',                'History of Presenting Illness', 'History of presenting illness'),
   ('consultation_note',  'Consultation Note',  'Clinician consultation note'),
   ('progress_note',      'Progress Note',      'Inpatient progress note'),
   ('triage_note',        'Triage Note',        'Triage assessment note'),
   ('discharge_summary',  'Discharge Summary',  'Discharge summary'),
   ('prescription',       'Prescription',       'Medication prescription'),
   ('lab_request',        'Laboratory Request', 'Laboratory test request'),
   ('referral_letter',    'Referral Letter',    'Referral letter')
ON CONFLICT (code) DO NOTHING;

INSERT INTO document.document_template (id, code, name, document_type_code, template_type, content) VALUES
   ('00000000-0000-0000-0000-000000000501', 'consultation_note_default', 'Consultation Note (Default)', 'consultation_note', 'liquid',
    '{{patient.name}}\n{{patient.mrn}}\n\nHistory:\n{{facts.history}}\n\nExamination:\n{{facts.examination}}\n\nAssessment:\n{{assessment}}\n\nPlan:\n{{plan}}'),
   ('00000000-0000-0000-0000-000000000502', 'discharge_summary_default', 'Discharge Summary (Default)',  'discharge_summary',  'liquid',
    '{{patient.name}}\n{{patient.mrn}}\n\nAdmission: {{admission.date}}\nDischarge: {{discharge.date}}\n\nDiagnosis: {{diagnosis}}\n\nSummary:\n{{summary}}\n\nFollow-up: {{follow_up}}')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- configuration
-- ---------------------------------------------------------------------------

INSERT INTO configuration.scope (code, label, precedence) VALUES
   ('global',       'Global',       1000),
   ('country',      'Country',      900),
   ('organization', 'Organization', 800),
   ('facility',     'Facility',     700),
   ('department',   'Department',   600),
   ('clinic',       'Clinic',       500),
   ('clinician',    'Clinician',    400)
ON CONFLICT (code) DO NOTHING;

INSERT INTO configuration.inheritance (id, scope_code, parent_scope_code, precedence) VALUES
   ('00000000-0000-0000-0000-000000000601', 'country',      'global',       10),
   ('00000000-0000-0000-0000-000000000602', 'organization', 'country',      20),
   ('00000000-0000-0000-0000-000000000603', 'facility',     'organization', 30),
   ('00000000-0000-0000-0000-000000000604', 'department',   'facility',     40),
   ('00000000-0000-0000-0000-000000000605', 'clinic',       'department',   50),
   ('00000000-0000-0000-0000-000000000606', 'clinician',    'clinic',       60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO configuration.configuration (id, code, key, name, data_type, default_value, description) VALUES
   ('00000000-0000-0000-0000-000000000611', 'language.default', 'language.default', 'Default language', 'string',
    '"en"', 'Default interface language'),
   ('00000000-0000-0000-0000-000000000612', 'appointment.slot_minutes', 'appointment.slot_minutes', 'Appointment slot length (minutes)', 'number',
    '15', 'Default appointment slot length'),
   ('00000000-0000-0000-0000-000000000613', 'facility.opd_open', 'facility.opd_open', 'OPD opens at (24h HH:MM)', 'string',
    '"08:00"', 'Facility opening time')
ON CONFLICT (id) DO NOTHING;

INSERT INTO configuration.configuration_version (id, configuration_id, version, value) VALUES
   ('00000000-0000-0000-0000-000000000621', '00000000-0000-0000-0000-000000000611', 1, '"en"'),
   ('00000000-0000-0000-0000-000000000622', '00000000-0000-0000-0000-000000000612', 1, '15'),
   ('00000000-0000-0000-0000-000000000623', '00000000-0000-0000-0000-000000000613', 1, '"08:00"')
ON CONFLICT (id) DO NOTHING;

INSERT INTO configuration.activation (id, configuration_id, active_version_id, scope_code) VALUES
   ('00000000-0000-0000-0000-000000000631', '00000000-0000-0000-0000-000000000611', '00000000-0000-0000-0000-000000000621', 'global'),
   ('00000000-0000-0000-0000-000000000632', '00000000-0000-0000-0000-000000000612', '00000000-0000-0000-0000-000000000622', 'global'),
   ('00000000-0000-0000-0000-000000000633', '00000000-0000-0000-0000-000000000613', '00000000-0000-0000-0000-000000000623', 'global')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- system
-- ---------------------------------------------------------------------------

INSERT INTO system.environment (code, label) VALUES
   ('development', 'Development'),
   ('staging',     'Staging'),
   ('production',  'Production')
ON CONFLICT (code) DO NOTHING;

INSERT INTO system.engine (id, code, name, engine_type, description) VALUES
   ('00000000-0000-0000-0000-000000000701', 'clinical_cpu', 'AMEXAN Clinical CPU', 'reasoning', 'Core reasoning engine (Phase 2+)'),
   ('00000000-0000-0000-0000-000000000702', 'documentation_engine', 'Documentation Engine', 'documentation', 'Generates documents from state (Phase 2+)')
ON CONFLICT (id) DO NOTHING;

INSERT INTO system.engine_version (id, engine_id, version, is_active) VALUES
   ('00000000-0000-0000-0000-000000000711', '00000000-0000-0000-0000-000000000701', '0.0.1', false),
   ('00000000-0000-0000-0000-000000000712', '00000000-0000-0000-0000-000000000702', '0.0.1', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO system.job (id, code, name, schedule, is_active) VALUES
   ('00000000-0000-0000-0000-000000000721', 'overdue_follow_ups',  'Overdue Follow-up Detection', '0 6 * * *', true),
   ('00000000-0000-0000-0000-000000000722', 'appointment_reminders','Appointment Reminders',       '0 8 * * *', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO system.feature_flag (id, code, name, description, enabled) VALUES
   ('00000000-0000-0000-0000-000000000731', 'cpu.differentials', 'CPU Differentials', 'Enable CPU differential generation (Phase 2)', false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- communication
-- ---------------------------------------------------------------------------

INSERT INTO communication.template (id, code, name, template_type, subject, body) VALUES
   ('00000000-0000-0000-0000-000000000801', 'appointment_reminder', 'Appointment Reminder', 'sms', NULL,
    'Dear {{patient_name}}, you have an appointment at {{facility_name}} on {{appointment_date}} at {{appointment_time}}.'),
   ('00000000-0000-0000-0000-000000000802', 'result_ready', 'Result Ready', 'sms', NULL,
    'Dear {{patient_name}}, your result is ready at {{facility_name}}.'),
   ('00000000-0000-0000-0000-000000000803', 'appointment_confirmation', 'Appointment Confirmation', 'email',
    'Your appointment is confirmed', 'Dear {{patient_name}}, your appointment is confirmed for {{appointment_date}} at {{appointment_time}}.')
ON CONFLICT (id) DO NOTHING;
