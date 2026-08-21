-- =============================================================================
-- AMEXAN H5 — PHASE 1 / SEED C
-- =============================================================================
-- NAME:
--   048_amexan_phase1_seed_c_clinical_workflow_document_configuration_system.sql
--
-- PURPOSE:
--   Universal reference/lookup seed for the AMEXAN Clinical Operating System.
--
-- LAYERS:
--   1. Clinical vocabulary
--   2. Clinical state/status vocabulary
--   3. Orders and care-team vocabulary
--   4. Consent vocabulary
--   5. Clinical workflow definitions
--   6. Workflow states/transitions/queues
--   7. Clinical document types/templates
--   8. Configuration hierarchy/inheritance
--   9. System environments
--  10. Engine registry/versioning
--  11. Background jobs
--  12. Feature flags
--  13. Communication templates
--
-- DESIGN PRINCIPLES:
--   - Idempotent
--   - Deterministic
--   - No patient-specific data
--   - No clinical diagnosis engine logic
--   - No probabilistic reasoning
--   - No hard-coded UI assumptions
--   - Vocabulary is data, not application code
--   - CPU/engines consume this layer
--
-- DEPENDENCIES:
--   This seed assumes the Phase 1 schema migration has already created the
--   referenced schemas/tables.
--
-- IMPORTANT:
--   This seed intentionally does NOT activate the Clinical CPU.
--   CPU reasoning/rules belong to subsequent rule/knowledge seeds.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';

-- =============================================================================
-- 0. SAFETY / EXTENSIONS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- 1. CLINICAL FACT STATUS
-- =============================================================================
-- A fact is an observation/assertion in the longitudinal clinical record.
--
-- entered:
--   captured but not necessarily verified.
--
-- active:
--   currently valid.
--
-- corrected:
--   explicitly corrected but retained for provenance.
--
-- superseded:
--   replaced by a later fact.
--
-- retracted:
--   withdrawn from clinical use.
-- =============================================================================

INSERT INTO clinical.fact_status
    (code, label, description)
VALUES
    ('entered',
     'Entered',
     'Fact has been entered but may not yet have completed verification.'),
    ('active',
     'Active',
     'Fact is currently considered valid and clinically usable.'),
    ('corrected',
     'Corrected',
     'The original fact was corrected while preserving its provenance.'),
    ('superseded',
     'Superseded',
     'Fact has been replaced by a newer or more authoritative fact.'),
    ('retracted',
     'Retracted',
     'Fact has been withdrawn and must not be treated as currently valid.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 2. PROBLEM STATUS
-- =============================================================================

INSERT INTO clinical.problem_status
    (code, label, description)
VALUES
    ('active',
     'Active',
     'Problem is currently active.'),
    ('resolved',
     'Resolved',
     'Problem has clinically resolved.'),
    ('inactive',
     'Inactive',
     'Problem is no longer active but remains clinically relevant historically.'),
    ('recurred',
     'Recurred',
     'Previously resolved/inactive problem has recurred.'),
    ('entered_in_error',
     'Entered in error',
     'Problem was documented incorrectly and must not be treated as valid.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 3. DIAGNOSIS STATUS
-- =============================================================================
-- AMEXAN deliberately separates suspected/working/confirmed/final.
-- This is essential for clinical reasoning and documentation integrity.
-- =============================================================================

INSERT INTO clinical.diagnosis_status
    (code, label, description)
VALUES
    ('suspected',
     'Suspected',
     'Diagnosis is clinically suspected but not yet adopted as the working diagnosis.'),
    ('working',
     'Working',
     'Diagnosis currently guides clinical management while evaluation continues.'),
    ('confirmed',
     'Confirmed',
     'Diagnosis has sufficient supporting evidence to be considered confirmed.'),
    ('final',
     'Final',
     'Diagnosis is the finalized diagnosis for the encounter or episode.'),
    ('ruled_out',
     'Ruled out',
     'Diagnosis has been adequately excluded for the current clinical episode.'),
    ('entered_in_error',
     'Entered in error',
     'Diagnosis was entered incorrectly and must not be treated as valid.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 4. ORDER TYPES
-- =============================================================================

INSERT INTO clinical.order_type
    (code, label, description)
VALUES
    ('laboratory',
     'Laboratory',
     'Order for laboratory investigation or specimen-based diagnostic testing.'),
    ('imaging',
     'Imaging',
     'Order for diagnostic imaging or radiological investigation.'),
    ('medication',
     'Medication',
     'Medication prescribing, administration, dispensing, or related order.'),
    ('procedure',
     'Procedure',
     'Order for a diagnostic, therapeutic, surgical, or bedside procedure.'),
    ('nursing',
     'Nursing',
     'Order for nursing assessment, monitoring, intervention, or care.'),
    ('consultation',
     'Consultation',
     'Request for review or co-management by another clinical service.'),
    ('diet',
     'Diet',
     'Dietary or nutritional management order.'),
    ('referral',
     'Referral',
     'Referral to another clinician, facility, specialty, or service.'),
    ('monitoring',
     'Monitoring',
     'Order for physiological, clinical, or observation monitoring.'),
    ('therapy',
     'Therapy',
     'Order for physiotherapy, occupational therapy, speech therapy, or similar service.'),
    ('other',
     'Other',
     'Other clinically relevant order not represented above.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 5. ORDER STATUS
-- =============================================================================

INSERT INTO clinical.order_status
    (code, label, description)
VALUES
    ('draft',
     'Draft',
     'Order is being prepared and has not been submitted.'),
    ('pending',
     'Pending',
     'Order has been submitted and awaits processing.'),
    ('active',
     'Active',
     'Order is currently active and actionable.'),
    ('on_hold',
     'On hold',
     'Order is temporarily suspended without being cancelled.'),
    ('completed',
     'Completed',
     'Order has been completed.'),
    ('cancelled',
     'Cancelled',
     'Order has been cancelled before completion.'),
    ('resulted',
     'Resulted',
     'Order has produced a result or clinical outcome.'),
    ('discontinued',
     'Discontinued',
     'Order has been intentionally discontinued.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 6. ORDER PRIORITY
-- =============================================================================
-- Lower numeric sort order means lower urgency in the display vocabulary.
-- Clinical CPU may separately reason about urgency.
-- =============================================================================

INSERT INTO clinical.order_priority
    (code, label, sort_order)
VALUES
    ('routine', 'Routine', 10),
    ('urgent',  'Urgent', 20),
    ('asap',    'ASAP', 25),
    ('stat',    'STAT', 30)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 7. CARE TEAM ROLES
-- =============================================================================

INSERT INTO clinical.care_team_role
    (code, label, description)
VALUES
    ('attending',
     'Attending',
     'Clinician with primary responsibility for the patient episode.'),
    ('consultant',
     'Consultant',
     'Senior specialist clinician responsible for specialist oversight.'),
    ('registrar',
     'Registrar',
     'Senior resident/registrar participating in clinical care.'),
    ('resident',
     'Resident',
     'Resident physician participating in clinical care.'),
    ('intern',
     'Intern',
     'Intern physician participating under appropriate supervision.'),
    ('medical_officer',
     'Medical Officer',
     'Medical officer providing clinical care.'),
    ('clinical_officer',
     'Clinical Officer',
     'Clinical officer participating in patient care within scope of practice.'),
    ('nurse_in_charge',
     'Nurse in charge',
     'Nurse responsible for coordination of nursing care in the clinical area.'),
    ('nurse',
     'Nurse',
     'Nursing professional participating in patient care.'),
    ('midwife',
     'Midwife',
     'Midwifery professional participating in maternity care.'),
    ('pharmacist',
     'Pharmacist',
     'Clinical or dispensing pharmacist participating in medication care.'),
    ('laboratory',
     'Laboratory professional',
     'Laboratory professional involved in specimen processing or interpretation.'),
    ('radiologist',
     'Radiologist',
     'Medical imaging specialist involved in interpretation.'),
    ('radiographer',
     'Radiographer',
     'Radiography/imaging professional performing imaging studies.'),
    ('therapist',
     'Therapist',
     'Allied health professional providing therapy.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 8. CONSENT TYPES
-- =============================================================================

INSERT INTO clinical.consent_type
    (code, label, description)
VALUES
    ('general_care',
     'General care',
     'Consent relating to routine clinical assessment and care where required.'),
    ('procedure',
     'Procedure',
     'Consent for a diagnostic or therapeutic procedure.'),
    ('surgery',
     'Surgery',
     'Consent for operative intervention.'),
    ('treatment',
     'Treatment',
     'Consent for a specific treatment intervention.'),
    ('medication',
     'Medication',
     'Consent or authorization relevant to medication treatment where applicable.'),
    ('blood_transfusion',
     'Blood transfusion',
     'Consent relating to blood or blood-component transfusion.'),
    ('anesthesia',
     'Anesthesia',
     'Consent for anesthesia or anesthetic-related intervention.'),
    ('imaging',
     'Imaging',
     'Consent relevant to imaging where required.'),
    ('research',
     'Research',
     'Consent for participation in research.'),
    ('photography',
     'Clinical photography',
     'Consent relating to clinical photography or image capture.'),
    ('telemedicine',
     'Telemedicine',
     'Consent relating to remote clinical consultation where required.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 9. WORKFLOW DEFINITIONS
-- =============================================================================
-- Universal clinical workflows.
--
-- OUTPATIENT:
--   registration -> triage -> assessment -> investigation/treatment
--                -> disposition -> completed
--
-- INPATIENT:
--   admission -> assessment -> investigation/treatment
--             -> disposition/discharge -> completed
--
-- EMERGENCY:
--   registration -> immediate triage/resuscitation -> assessment
--                -> investigation/treatment -> disposition
--
-- The CPU does not diagnose here.
-- Workflow merely determines what operational state the encounter occupies.
-- =============================================================================

INSERT INTO workflow.definition
    (id, code, name, description)
VALUES
    (
        '00000000-0000-0000-0000-000000000401',
        'outpatient_visit',
        'Outpatient Visit',
        'Universal outpatient clinical encounter workflow.'
    ),
    (
        '00000000-0000-0000-0000-000000000402',
        'inpatient_admission',
        'Inpatient Admission',
        'Universal inpatient admission and episode-of-care workflow.'
    ),
    (
        '00000000-0000-0000-0000-000000000403',
        'emergency_visit',
        'Emergency Visit',
        'Emergency clinical workflow emphasizing rapid triage, stabilization, assessment and disposition.'
    ),
    (
        '00000000-0000-0000-0000-000000000404',
        'day_case',
        'Day Case',
        'Short-stay/day-case workflow for planned investigation or intervention without routine overnight admission.'
    ),
    (
        '00000000-0000-0000-0000-000000000405',
        'telemedicine_visit',
        'Telemedicine Visit',
        'Remote clinical encounter workflow with explicit remote-assessment constraints.'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 10. WORKFLOW VERSIONS
-- =============================================================================

INSERT INTO workflow.version
    (id, definition_id, version, is_active)
VALUES
    (
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000401',
        1,
        TRUE
    ),
    (
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000402',
        1,
        TRUE
    ),
    (
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000403',
        1,
        TRUE
    ),
    (
        '00000000-0000-0000-0000-000000000414',
        '00000000-0000-0000-0000-000000000404',
        1,
        TRUE
    ),
    (
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000405',
        1,
        TRUE
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 11. UNIVERSAL WORKFLOW STATES
-- =============================================================================

INSERT INTO workflow.state
    (id, code, label, state_kind)
VALUES
    (
        '00000000-0000-0000-0000-000000000421',
        'registration',
        'Registration',
        'start'
    ),
    (
        '00000000-0000-0000-0000-000000000422',
        'triage',
        'Triage',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000423',
        'assessment',
        'Clinical Assessment',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000424',
        'investigation',
        'Investigation',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000425',
        'treatment',
        'Treatment',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000426',
        'disposition',
        'Disposition',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000427',
        'completed',
        'Completed',
        'end'
    ),
    (
        '00000000-0000-0000-0000-000000000428',
        'resuscitation',
        'Resuscitation / Stabilization',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000429',
        'admission',
        'Admission',
        'start'
    ),
    (
        '00000000-0000-0000-0000-000000000430',
        'discharge',
        'Discharge',
        'middle'
    ),
    (
        '00000000-0000-0000-0000-000000000431',
        'remote_assessment',
        'Remote Assessment',
        'middle'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 12. OUTPATIENT WORKFLOW TRANSITIONS
-- =============================================================================

INSERT INTO workflow.transition
    (id, workflow_version_id, from_state_id, to_state_id, name)
VALUES
    (
        '00000000-0000-0000-0000-000000000501',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000421',
        '00000000-0000-0000-0000-000000000422',
        'Register'
    ),
    (
        '00000000-0000-0000-0000-000000000502',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000422',
        '00000000-0000-0000-0000-000000000423',
        'Complete triage'
    ),
    (
        '00000000-0000-0000-0000-000000000503',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000424',
        'Investigate'
    ),
    (
        '00000000-0000-0000-0000-000000000504',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000425',
        'Treat'
    ),
    (
        '00000000-0000-0000-0000-000000000505',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000424',
        '00000000-0000-0000-0000-000000000425',
        'Treat after investigation'
    ),
    (
        '00000000-0000-0000-0000-000000000506',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000424',
        '00000000-0000-0000-0000-000000000426',
        'Disposition after investigation'
    ),
    (
        '00000000-0000-0000-0000-000000000507',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000425',
        '00000000-0000-0000-0000-000000000426',
        'Disposition after treatment'
    ),
    (
        '00000000-0000-0000-0000-000000000508',
        '00000000-0000-0000-0000-000000000411',
        '00000000-0000-0000-0000-000000000426',
        '00000000-0000-0000-0000-000000000427',
        'Complete encounter'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 13. INPATIENT WORKFLOW TRANSITIONS
-- =============================================================================

INSERT INTO workflow.transition
    (id, workflow_version_id, from_state_id, to_state_id, name)
VALUES
    (
        '00000000-0000-0000-0000-000000000511',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000429',
        '00000000-0000-0000-0000-000000000423',
        'Admit and assess'
    ),
    (
        '00000000-0000-0000-0000-000000000512',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000424',
        'Investigate'
    ),
    (
        '00000000-0000-0000-0000-000000000513',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000425',
        'Treat'
    ),
    (
        '00000000-0000-0000-0000-000000000514',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000424',
        '00000000-0000-0000-0000-000000000425',
        'Treat after investigation'
    ),
    (
        '00000000-0000-0000-0000-000000000515',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000425',
        '00000000-0000-0000-0000-000000000423',
        'Reassess'
    ),
    (
        '00000000-0000-0000-0000-000000000516',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000425',
        '00000000-0000-0000-0000-000000000430',
        'Prepare discharge'
    ),
    (
        '00000000-0000-0000-0000-000000000517',
        '00000000-0000-0000-0000-000000000412',
        '00000000-0000-0000-0000-000000000430',
        '00000000-0000-0000-0000-000000000427',
        'Complete discharge'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 14. EMERGENCY WORKFLOW
-- =============================================================================

INSERT INTO workflow.transition
    (id, workflow_version_id, from_state_id, to_state_id, name)
VALUES
    (
        '00000000-0000-0000-0000-000000000521',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000421',
        '00000000-0000-0000-0000-000000000422',
        'Emergency registration'
    ),
    (
        '00000000-0000-0000-0000-000000000522',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000422',
        '00000000-0000-0000-0000-000000000428',
        'Immediate stabilization'
    ),
    (
        '00000000-0000-0000-0000-000000000523',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000422',
        '00000000-0000-0000-0000-000000000423',
        'Emergency assessment'
    ),
    (
        '00000000-0000-0000-0000-000000000524',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000428',
        '00000000-0000-0000-0000-000000000423',
        'Stabilized and assess'
    ),
    (
        '00000000-0000-0000-0000-000000000525',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000424',
        'Emergency investigation'
    ),
    (
        '00000000-0000-0000-0000-000000000526',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000425',
        'Emergency treatment'
    ),
    (
        '00000000-0000-0000-0000-000000000527',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000425',
        '00000000-0000-0000-0000-000000000426',
        'Emergency disposition'
    ),
    (
        '00000000-0000-0000-0000-000000000528',
        '00000000-0000-0000-0000-000000000413',
        '00000000-0000-0000-0000-000000000426',
        '00000000-0000-0000-0000-000000000427',
        'Complete emergency encounter'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 15. DAY CASE WORKFLOW
-- =============================================================================

INSERT INTO workflow.transition
    (id, workflow_version_id, from_state_id, to_state_id, name)
VALUES
    (
        '00000000-0000-0000-0000-000000000531',
        '00000000-0000-0000-0000-000000000414',
        '00000000-0000-0000-0000-000000000421',
        '00000000-0000-0000-0000-000000000423',
        'Register and assess'
    ),
    (
        '00000000-0000-0000-0000-000000000532',
        '00000000-0000-0000-0000-000000000414',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000424',
        'Investigate'
    ),
    (
        '00000000-0000-0000-0000-000000000533',
        '00000000-0000-0000-0000-000000000414',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000425',
        'Treat / procedure'
    ),
    (
        '00000000-0000-0000-0000-000000000534',
        '00000000-0000-0000-0000-000000000414',
        '00000000-0000-0000-0000-000000000425',
        '00000000-0000-0000-0000-000000000426',
        'Disposition'
    ),
    (
        '00000000-0000-0000-0000-000000000535',
        '00000000-0000-0000-0000-000000000414',
        '00000000-0000-0000-0000-000000000426',
        '00000000-0000-0000-0000-000000000427',
        'Complete day case'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 16. TELEMEDICINE WORKFLOW
-- =============================================================================

INSERT INTO workflow.transition
    (id, workflow_version_id, from_state_id, to_state_id, name)
VALUES
    (
        '00000000-0000-0000-0000-000000000541',
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000421',
        '00000000-0000-0000-0000-000000000431',
        'Start remote assessment'
    ),
    (
        '00000000-0000-0000-0000-000000000542',
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000431',
        '00000000-0000-0000-0000-000000000423',
        'Proceed to clinical assessment'
    ),
    (
        '00000000-0000-0000-0000-000000000543',
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000424',
        'Remote investigation'
    ),
    (
        '00000000-0000-0000-0000-000000000544',
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000423',
        '00000000-0000-0000-0000-000000000425',
        'Remote treatment'
    ),
    (
        '00000000-0000-0000-0000-000000000545',
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000425',
        '00000000-0000-0000-0000-000000000426',
        'Remote disposition'
    ),
    (
        '00000000-0000-0000-0000-000000000546',
        '00000000-0000-0000-0000-000000000415',
        '00000000-0000-0000-0000-000000000426',
        '00000000-0000-0000-0000-000000000427',
        'Complete telemedicine encounter'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 17. WORKFLOW QUEUES
-- =============================================================================

INSERT INTO workflow.queue
    (id, code, name, description)
VALUES
    (
        '00000000-0000-0000-0000-000000000601',
        'registration_queue',
        'Registration Queue',
        'Patients awaiting registration or administrative intake.'
    ),
    (
        '00000000-0000-0000-0000-000000000602',
        'triage_queue',
        'Triage Queue',
        'Patients awaiting clinical triage.'
    ),
    (
        '00000000-0000-0000-0000-000000000603',
        'consult_queue',
        'Consultation Queue',
        'Patients awaiting clinician assessment or consultation.'
    ),
    (
        '00000000-0000-0000-0000-000000000604',
        'procedure_queue',
        'Procedure Queue',
        'Patients awaiting planned procedures.'
    ),
    (
        '00000000-0000-0000-0000-000000000605',
        'laboratory_queue',
        'Laboratory Queue',
        'Specimens/orders awaiting laboratory processing.'
    ),
    (
        '00000000-0000-0000-0000-000000000606',
        'imaging_queue',
        'Imaging Queue',
        'Patients/orders awaiting diagnostic imaging.'
    ),
    (
        '00000000-0000-0000-0000-000000000607',
        'pharmacy_queue',
        'Pharmacy Queue',
        'Medication orders awaiting pharmacy processing.'
    ),
    (
        '00000000-0000-0000-0000-000000000608',
        'discharge_queue',
        'Discharge Queue',
        'Patients awaiting discharge processing.'
    ),
    (
        '00000000-0000-0000-0000-000000000609',
        'referral_queue',
        'Referral Queue',
        'Referrals awaiting processing or acceptance.'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 18. DOCUMENT TYPES
-- =============================================================================

INSERT INTO document.document_type
    (code, label, description)
VALUES
    (
        'hpi',
        'History of Presenting Illness',
        'Structured history of the current presenting complaint.'
    ),
    (
        'history_full',
        'Full Clinical History',
        'Comprehensive clinical history document.'
    ),
    (
        'examination',
        'Clinical Examination',
        'Structured physical examination document.'
    ),
    (
        'triage_note',
        'Triage Note',
        'Initial triage and acuity assessment.'
    ),
    (
        'consultation_note',
        'Consultation Note',
        'Clinician assessment, examination, impression and plan.'
    ),
    (
        'progress_note',
        'Progress Note',
        'Longitudinal inpatient or ongoing-care progress documentation.'
    ),
    (
        'admission_note',
        'Admission Note',
        'Initial inpatient admission documentation.'
    ),
    (
        'procedure_note',
        'Procedure Note',
        'Documentation of a performed clinical procedure.'
    ),
    (
        'operative_note',
        'Operative Note',
        'Documentation of a surgical operation.'
    ),
    (
        'anesthesia_note',
        'Anesthesia Note',
        'Documentation relating to anesthesia care.'
    ),
    (
        'discharge_summary',
        'Discharge Summary',
        'Summary of an inpatient episode and discharge plan.'
    ),
    (
        'prescription',
        'Prescription',
        'Medication prescription document.'
    ),
    (
        'laboratory_request',
        'Laboratory Request',
        'Laboratory investigation request.'
    ),
    (
        'imaging_request',
        'Imaging Request',
        'Diagnostic imaging request.'
    ),
    (
        'referral_letter',
        'Referral Letter',
        'Formal referral communication.'
    ),
    (
        'medical_certificate',
        'Medical Certificate',
        'Clinically generated certificate where authorized.'
    ),
    (
        'consent_form',
        'Consent Form',
        'Documentation of informed consent.'
    ),
    (
        'telemedicine_note',
        'Telemedicine Note',
        'Clinical documentation of a remote encounter.'
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 19. DOCUMENT TEMPLATES
-- =============================================================================
-- Templates are intentionally sparse.
-- The Documentation Engine later fills them from structured state.
-- =============================================================================

INSERT INTO document.document_template
    (id, code, name, document_type_code, template_type, content)
VALUES
(
    '00000000-0000-0000-0000-000000000701',
    'consultation_note_default',
    'Consultation Note — Default',
    'consultation_note',
    'liquid',
    '{{patient.name}}
MRN: {{patient.mrn}}

CHIEF COMPLAINT
{{facts.chief_complaint}}

HISTORY OF PRESENTING ILLNESS
{{facts.hpi}}

RELEVANT HISTORY
{{facts.relevant_history}}

EXAMINATION
{{facts.examination}}

INVESTIGATIONS
{{facts.investigations}}

ASSESSMENT
{{assessment}}

PLAN
{{plan}}

SAFETY / FOLLOW-UP
{{follow_up}}'
),
(
    '00000000-0000-0000-0000-000000000702',
    'admission_note_default',
    'Admission Note — Default',
    'admission_note',
    'liquid',
    '{{patient.name}}
MRN: {{patient.mrn}}

REASON FOR ADMISSION
{{reason_for_admission}}

HISTORY
{{facts.history}}

EXAMINATION
{{facts.examination}}

INITIAL INVESTIGATIONS
{{facts.investigations}}

PROBLEM LIST
{{problems}}

INITIAL ASSESSMENT
{{assessment}}

INITIAL PLAN
{{plan}}'
),
(
    '00000000-0000-0000-0000-000000000703',
    'progress_note_default',
    'Progress Note — Default',
    'progress_note',
    'liquid',
    '{{date_time}}

CLINICAL STATUS
{{clinical_status}}

INTERVAL HISTORY
{{interval_history}}

EXAMINATION
{{facts.examination}}

NEW INVESTIGATIONS / RESULTS
{{new_results}}

ACTIVE PROBLEMS
{{problems}}

ASSESSMENT
{{assessment}}

PLAN
{{plan}}'
),
(
    '00000000-0000-0000-0000-000000000704',
    'discharge_summary_default',
    'Discharge Summary — Default',
    'discharge_summary',
    'liquid',
    '{{patient.name}}
MRN: {{patient.mrn}}

ADMISSION DATE: {{admission.date}}
DISCHARGE DATE: {{discharge.date}}

REASON FOR ADMISSION
{{reason_for_admission}}

FINAL DIAGNOSES
{{diagnosis}}

HOSPITAL COURSE
{{summary}}

PROCEDURES
{{procedures}}

INVESTIGATIONS
{{investigations}}

TREATMENT
{{treatment}}

CONDITION AT DISCHARGE
{{condition_at_discharge}}

DISCHARGE MEDICATIONS
{{medications}}

FOLLOW-UP
{{follow_up}}

SAFETY-NET / RETURN PRECAUTIONS
{{return_precautions}}'
),
(
    '00000000-0000-0000-0000-000000000705',
    'referral_letter_default',
    'Referral Letter — Default',
    'referral_letter',
    'liquid',
    '{{patient.name}}
MRN: {{patient.mrn}}

DATE
{{date}}

REFERRING FACILITY
{{facility.name}}

REASON FOR REFERRAL
{{reason}}

CLINICAL HISTORY
{{history}}

EXAMINATION
{{examination}}

INVESTIGATIONS
{{investigations}}

CURRENT ASSESSMENT
{{assessment}}

TREATMENT ALREADY PROVIDED
{{treatment}}

SPECIFIC REQUEST / QUESTION
{{referral_question}}

URGENCY
{{urgency}}'
),
(
    '00000000-0000-0000-0000-000000000706',
    'telemedicine_note_default',
    'Telemedicine Note — Default',
    'telemedicine_note',
    'liquid',
    '{{patient.name}}
MRN: {{patient.mrn}}

REMOTE ENCOUNTER
{{date_time}}

REMOTE MODALITY
{{modality}}

PATIENT LOCATION
{{patient_location}}

CLINICIAN LOCATION
{{clinician_location}}

IDENTITY / CONSENT
{{consent}}

HISTORY
{{facts.history}}

REMOTE-AVAILABLE EXAMINATION
{{facts.examination}}

LIMITATIONS OF REMOTE ASSESSMENT
{{limitations}}

INVESTIGATIONS
{{investigations}}

ASSESSMENT
{{assessment}}

PLAN
{{plan}}

ESCALATION / SAFETY-NET
{{safety_net}}'
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 20. CONFIGURATION SCOPES
-- =============================================================================
-- Higher precedence number = broader authority in this hierarchy.
--
-- Runtime resolution should normally traverse:
--
-- global
--   -> country
--      -> organization
--         -> facility
--            -> department
--               -> clinic
--                  -> clinician
--
-- More specific scope overrides inherited values.
-- =============================================================================

INSERT INTO configuration.scope
    (code, label, precedence)
VALUES
    ('global',       'Global',       1000),
    ('country',      'Country',       900),
    ('organization', 'Organization',  800),
    ('facility',     'Facility',      700),
    ('department',   'Department',    600),
    ('clinic',       'Clinic',        500),
    ('clinician',    'Clinician',     400)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 21. CONFIGURATION INHERITANCE
-- =============================================================================

INSERT INTO configuration.inheritance
    (id, scope_code, parent_scope_code, precedence)
VALUES
    (
        '00000000-0000-0000-0000-000000000801',
        'country',
        'global',
        10
    ),
    (
        '00000000-0000-0000-0000-000000000802',
        'organization',
        'country',
        20
    ),
    (
        '00000000-0000-0000-0000-000000000803',
        'facility',
        'organization',
        30
    ),
    (
        '00000000-0000-0000-0000-000000000804',
        'department',
        'facility',
        40
    ),
    (
        '00000000-0000-0000-0000-000000000805',
        'clinic',
        'department',
        50
    ),
    (
        '00000000-0000-0000-0000-000000000806',
        'clinician',
        'clinic',
        60
    )
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 22. UNIVERSAL CONFIGURATION
-- =============================================================================

INSERT INTO configuration.configuration
    (id, code, key, name, data_type, default_value, description)
VALUES
(
    '00000000-0000-0000-0000-000000000811',
    'language.default',
    'language.default',
    'Default language',
    'string',
    '"en"',
    'Default AMEXAN interface and documentation language.'
),
(
    '00000000-0000-0000-0000-000000000812',
    'timezone.default',
    'timezone.default',
    'Default timezone',
    'string',
    '"Africa/Nairobi"',
    'Default timezone for facilities where no more specific timezone is configured.'
),
(
    '00000000-0000-0000-0000-000000000813',
    'appointment.slot_minutes',
    'appointment.slot_minutes',
    'Appointment slot length',
    'number',
    '15',
    'Default appointment duration in minutes.'
),
(
    '00000000-0000-0000-0000-000000000814',
    'facility.opd_open',
    'facility.opd_open',
    'OPD opening time',
    'string',
    '"08:00"',
    'Default outpatient opening time.'
),
(
    '00000000-0000-0000-0000-000000000815',
    'facility.opd_close',
    'facility.opd_close',
    'OPD closing time',
    'string',
    '"17:00"',
    'Default outpatient closing time.'
),
(
    '00000000-0000-0000-0000-000000000816',
    'clinical.measurement.unit_system',
    'clinical.measurement.unit_system',
    'Clinical measurement unit system',
    'string',
    '"metric"',
    'Default clinical measurement system.'
),
(
    '00000000-0000-0000-0000-000000000817',
    'clinical.documentation.auto_draft',
    'clinical.documentation.auto_draft',
    'Automatic documentation drafting',
    'boolean',
    'true',
    'Allows the documentation engine to construct draft documentation from structured clinical state.'
),
(
    '00000000-0000-0000-0000-000000000818',
    'clinical.cpu.enabled',
    'clinical.cpu.enabled',
    'Clinical CPU enabled',
    'boolean',
    'false',
    'Master switch for activation of the clinical reasoning CPU.'
),
(
    '00000000-0000-0000-0000-000000000819',
    'clinical.cpu.safety_mode',
    'clinical.cpu.safety_mode',
    'Clinical CPU safety mode',
    'string',
    '"conservative"',
    'Controls the operational safety posture of the Clinical CPU.'
),
(
    '00000000-0000-0000-0000-000000000820',
    'telemedicine.remote_exam_disclaimer',
    'telemedicine.remote_exam_disclaimer',
    'Remote examination limitation handling',
    'boolean',
    'true',
    'Requires explicit representation of examination limitations during remote encounters.')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 23. CONFIGURATION VERSIONS
-- =============================================================================

INSERT INTO configuration.configuration_version
    (id, configuration_id, version, value)
VALUES
(
    '00000000-0000-0000-0000-000000000831',
    '00000000-0000-0000-0000-000000000811',
    1,
    '"en"'
),
(
    '00000000-0000-0000-0000-000000000832',
    '00000000-0000-0000-0000-000000000812',
    1,
    '"Africa/Nairobi"'
),
(
    '00000000-0000-0000-0000-000000000833',
    '00000000-0000-0000-0000-000000000813',
    1,
    '15'
),
(
    '00000000-0000-0000-0000-000000000834',
    '00000000-0000-0000-0000-000000000814',
    1,
    '"08:00"'
),
(
    '00000000-0000-0000-0000-000000000835',
    '00000000-0000-0000-0000-000000000815',
    1,
    '"17:00"'
),
(
    '00000000-0000-0000-0000-000000000836',
    '00000000-0000-0000-0000-000000000816',
    1,
    '"metric"'
),
(
    '00000000-0000-0000-0000-000000000837',
    '00000000-0000-0000-0000-000000000817',
    1,
    'true'
),
(
    '00000000-0000-0000-0000-000000000838',
    '00000000-0000-0000-0000-000000000818',
    1,
    'false'
),
(
    '00000000-0000-0000-0000-000000000839',
    '00000000-0000-0000-0000-000000000819',
    1,
    '"conservative"'
),
(
    '00000000-0000-0000-0000-000000000840',
    '00000000-0000-0000-0000-000000000820',
    1,
    'true'
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 24. CONFIGURATION ACTIVATION
-- =============================================================================

INSERT INTO configuration.activation
    (id, configuration_id, active_version_id, scope_code)
VALUES
(
    '00000000-0000-0000-0000-000000000851',
    '00000000-0000-0000-0000-000000000811',
    '00000000-0000-0000-0000-000000000831',
    'global'
),
(
    '00000000-0000-0000-0000-000000000852',
    '00000000-0000-0000-0000-000000000812',
    '00000000-0000-0000-0000-000000000832',
    'global'
),
(
    '00000000-0000-0000-0000-000000000853',
    '00000000-0000-0000-0000-000000000813',
    '00000000-0000-0000-0000-000000000833',
    'global'
),
(
    '00000000-0000-0000-0000-000000000854',
    '00000000-0000-0000-0000-000000000814',
    '00000000-0000-0000-0000-000000000834',
    'global'
),
(
    '00000000-0000-0000-0000-000000000855',
    '00000000-0000-0000-0000-000000000815',
    '00000000-0000-0000-0000-000000000835',
    'global'
),
(
    '00000000-0000-0000-0000-000000000856',
    '00000000-0000-0000-0000-000000000816',
    '00000000-0000-0000-0000-000000000836',
    'global'
),
(
    '00000000-0000-0000-0000-000000000857',
    '00000000-0000-0000-0000-000000000817',
    '00000000-0000-0000-0000-000000000837',
    'global'
),
(
    '00000000-0000-0000-0000-000000000858',
    '00000000-0000-0000-0000-000000000818',
    '00000000-0000-0000-0000-000000000838',
    'global'
),
(
    '00000000-0000-0000-0000-000000000859',
    '00000000-0000-0000-0000-000000000819',
    '00000000-0000-0000-0000-000000000839',
    'global'
),
(
    '00000000-0000-0000-0000-000000000860',
    '00000000-0000-0000-0000-000000000820',
    '00000000-0000-0000-0000-000000000840',
    'global'
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 25. SYSTEM ENVIRONMENTS
-- =============================================================================

INSERT INTO system.environment
    (code, label)
VALUES
    ('development', 'Development'),
    ('staging',     'Staging'),
    ('production',  'Production')
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 26. AMEXAN ENGINE REGISTRY
-- =============================================================================
-- This is a registry, NOT the actual implementation.
--
-- Clinical CPU:
--   reasoning / clinical decision support
--
-- Documentation Engine:
--   converts structured clinical state into documents
--
-- Context Engine:
--   resolves patient/encounter context
--
-- Workflow Engine:
--   manages encounter state
--
-- Terminology Engine:
--   canonicalizes clinical vocabulary
--
-- Safety Engine:
--   detects safety-critical states and execution constraints
--
-- Rules Engine:
--   deterministic clinical rules
--
-- These engines will later be connected through the AMEXAN CPU architecture.
-- =============================================================================

INSERT INTO system.engine
    (id, code, name, engine_type, description)
VALUES
(
    '00000000-0000-0000-0000-000000000901',
    'clinical_cpu',
    'AMEXAN Clinical CPU',
    'reasoning',
    'Core clinical reasoning and decision-support orchestration engine.'
),
(
    '00000000-0000-0000-0000-000000000902',
    'documentation_engine',
    'AMEXAN Documentation Engine',
    'documentation',
    'Generates structured clinical documentation from authoritative clinical state.'
),
(
    '00000000-0000-0000-0000-000000000903',
    'context_engine',
    'AMEXAN Context Engine',
    'context',
    'Resolves patient, encounter, demographic, temporal, clinical and operational context.'
),
(
    '00000000-0000-0000-0000-000000000904',
    'workflow_engine',
    'AMEXAN Workflow Engine',
    'workflow',
    'Controls clinical encounter workflow state and permissible transitions.'
),
(
    '00000000-0000-0000-0000-000000000905',
    'terminology_engine',
    'AMEXAN Terminology Engine',
    'terminology',
    'Resolves canonical clinical concepts, synonyms, codes and semantic relationships.'
),
(
    '00000000-0000-0000-0000-000000000906',
    'rules_engine',
    'AMEXAN Clinical Rules Engine',
    'rules',
    'Executes deterministic clinical, safety, eligibility and workflow rules.'
),
(
    '00000000-0000-0000-0000-000000000907',
    'safety_engine',
    'AMEXAN Safety Engine',
    'safety',
    'Detects safety-critical findings, contraindications, escalation states and execution constraints.'
),
(
    '00000000-0000-0000-0000-000000000908',
    'knowledge_engine',
    'AMEXAN Clinical Knowledge Engine',
    'knowledge',
    'Provides normalized clinical knowledge to the CPU and deterministic rules layer.'
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 27. ENGINE VERSIONS
-- =============================================================================

INSERT INTO system.engine_version
    (id, engine_id, version, is_active)
VALUES
(
    '00000000-0000-0000-0000-000000000921',
    '00000000-0000-0000-0000-000000000901',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000922',
    '00000000-0000-0000-0000-000000000902',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000923',
    '00000000-0000-0000-0000-000000000903',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000924',
    '00000000-0000-0000-0000-000000000904',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000925',
    '00000000-0000-0000-0000-000000000905',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000926',
    '00000000-0000-0000-0000-000000000906',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000927',
    '00000000-0000-0000-0000-000000000907',
    '0.1.0',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000928',
    '00000000-0000-0000-0000-000000000908',
    '0.1.0',
    FALSE
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 28. SYSTEM JOBS
-- =============================================================================

INSERT INTO system.job
    (id, code, name, schedule, is_active)
VALUES
(
    '00000000-0000-0000-0000-000000000941',
    'overdue_follow_ups',
    'Overdue Follow-up Detection',
    '0 6 * * *',
    TRUE
),
(
    '00000000-0000-0000-0000-000000000942',
    'appointment_reminders',
    'Appointment Reminders',
    '0 8 * * *',
    TRUE
),
(
    '00000000-0000-0000-0000-000000000943',
    'clinical_task_expiry',
    'Clinical Task Expiry Detection',
    '*/15 * * * *',
    TRUE
),
(
    '00000000-0000-0000-0000-000000000944',
    'pending_order_monitor',
    'Pending Order Monitor',
    '*/10 * * * *',
    TRUE
),
(
    '00000000-0000-0000-0000-000000000945',
    'safety_event_monitor',
    'Safety Event Monitor',
    '*/5 * * * *',
    TRUE
),
(
    '00000000-0000-0000-0000-000000000946',
    'documentation_draft_refresh',
    'Documentation Draft Refresh',
    '*/15 * * * *',
    TRUE
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 29. FEATURE FLAGS
-- =============================================================================

INSERT INTO system.feature_flag
    (id, code, name, description, enabled)
VALUES
(
    '00000000-0000-0000-0000-000000000961',
    'cpu.differentials',
    'CPU Differentials',
    'Enable structured differential diagnosis generation.',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000962',
    'cpu.context_resolution',
    'CPU Context Resolution',
    'Enable structured patient and encounter context resolution.',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000963',
    'cpu.rule_execution',
    'CPU Rule Execution',
    'Enable deterministic clinical rule execution.',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000964',
    'cpu.safety_alerts',
    'CPU Safety Alerts',
    'Enable clinical safety-state detection and alert generation.',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000965',
    'documentation.auto_draft',
    'Automatic Documentation Drafting',
    'Enable generation of documentation drafts from structured clinical facts.',
    FALSE
),
(
    '00000000-0000-0000-0000-000000000966',
    'telemedicine.enabled',
    'Telemedicine',
    'Enable telemedicine workflow support.',
    TRUE
),
(
    '00000000-0000-0000-0000-000000000967',
    'clinical_audit.enabled',
    'Clinical Audit',
    'Enable expanded clinical audit/event tracking.',
    TRUE
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 30. COMMUNICATION TEMPLATES
-- =============================================================================

INSERT INTO communication.template
    (id, code, name, template_type, subject, body)
VALUES
(
    '00000000-0000-0000-0000-000000001001',
    'appointment_reminder_sms',
    'Appointment Reminder — SMS',
    'sms',
    NULL,
    'Dear {{patient_name}}, you have an appointment at {{facility_name}} on {{appointment_date}} at {{appointment_time}}.'
),
(
    '00000000-0000-0000-0000-000000001002',
    'appointment_confirmation_sms',
    'Appointment Confirmation — SMS',
    'sms',
    NULL,
    'Dear {{patient_name}}, your appointment at {{facility_name}} is confirmed for {{appointment_date}} at {{appointment_time}}.'
),
(
    '00000000-0000-0000-0000-000000001003',
    'result_ready_sms',
    'Result Ready — SMS',
    'sms',
    NULL,
    'Dear {{patient_name}}, a clinical result is ready at {{facility_name}}. Please follow the instructions provided by your care team.'
),
(
    '00000000-0000-0000-0000-000000001004',
    'follow_up_reminder_sms',
    'Follow-up Reminder — SMS',
    'sms',
    NULL,
    'Dear {{patient_name}}, this is a reminder regarding your scheduled clinical follow-up at {{facility_name}} on {{appointment_date}}.'
),
(
    '00000000-0000-0000-0000-000000001005',
    'appointment_confirmation_email',
    'Appointment Confirmation — Email',
    'email',
    'Your AMEXAN appointment is confirmed',
    'Dear {{patient_name}}, your appointment at {{facility_name}} is confirmed for {{appointment_date}} at {{appointment_time}}.'
),
(
    '00000000-0000-0000-0000-000000001006',
    'telemedicine_invitation',
    'Telemedicine Invitation',
    'email',
    'Your AMEXAN telemedicine consultation',
    'Dear {{patient_name}}, your remote clinical consultation with {{clinician_name}} is scheduled for {{appointment_date}} at {{appointment_time}}. Please use the provided secure access method.'
)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 31. VERIFICATION
-- =============================================================================

DO $$
DECLARE
    v_missing integer;
BEGIN

    -- Clinical status vocabulary
    SELECT COUNT(*)
    INTO v_missing
    FROM (
        VALUES
            ('entered'),
            ('active'),
            ('corrected'),
            ('superseded'),
            ('retracted')
    ) AS required(code)
    WHERE NOT EXISTS (
        SELECT 1
        FROM clinical.fact_status fs
        WHERE fs.code = required.code
    );

    IF v_missing > 0 THEN
        RAISE EXCEPTION
            'AMEXAN Seed C verification failed: % fact status values missing',
            v_missing;
    END IF;

    -- Workflow definitions
    SELECT COUNT(*)
    INTO v_missing
    FROM (
        VALUES
            ('outpatient_visit'),
            ('inpatient_admission'),
            ('emergency_visit'),
            ('day_case'),
            ('telemedicine_visit')
    ) AS required(code)
    WHERE NOT EXISTS (
        SELECT 1
        FROM workflow.definition wd
        WHERE wd.code = required.code
    );

    IF v_missing > 0 THEN
        RAISE EXCEPTION
            'AMEXAN Seed C verification failed: % workflow definitions missing',
            v_missing;
    END IF;

    -- Engine registry
    SELECT COUNT(*)
    INTO v_missing
    FROM (
        VALUES
            ('clinical_cpu'),
            ('documentation_engine'),
            ('context_engine'),
            ('workflow_engine'),
            ('terminology_engine'),
            ('rules_engine'),
            ('safety_engine'),
            ('knowledge_engine')
    ) AS required(code)
    WHERE NOT EXISTS (
        SELECT 1
        FROM system.engine se
        WHERE se.code = required.code
    );

    IF v_missing > 0 THEN
        RAISE EXCEPTION
            'AMEXAN Seed C verification failed: % engine definitions missing',
            v_missing;
    END IF;

END
$$;

-- =============================================================================
-- 32. HUMAN-READABLE VERIFICATION OUTPUT
-- =============================================================================

SELECT
    'AMEXAN PHASE 1 SEED C' AS seed,
    'clinical + workflow + document + configuration + system' AS layer,
    'SUCCESS' AS status;

SELECT
    'clinical.fact_status' AS table_name,
    COUNT(*) AS seeded_rows
FROM clinical.fact_status;

SELECT
    'clinical.problem_status' AS table_name,
    COUNT(*) AS seeded_rows
FROM clinical.problem_status;

SELECT
    'clinical.diagnosis_status' AS table_name,
    COUNT(*) AS seeded_rows
FROM clinical.diagnosis_status;

SELECT
    'clinical.order_type' AS table_name,
    COUNT(*) AS seeded_rows
FROM clinical.order_type;

SELECT
    'workflow.definition' AS table_name,
    COUNT(*) AS seeded_rows
FROM workflow.definition;

SELECT
    'workflow.version' AS table_name,
    COUNT(*) AS seeded_rows
FROM workflow.version;

SELECT
    'workflow.state' AS table_name,
    COUNT(*) AS seeded_rows
FROM workflow.state;

SELECT
    'workflow.transition' AS table_name,
    COUNT(*) AS seeded_rows
FROM workflow.transition;

SELECT
    'workflow.queue' AS table_name,
    COUNT(*) AS seeded_rows
FROM workflow.queue;

SELECT
    'document.document_type' AS table_name,
    COUNT(*) AS seeded_rows
FROM document.document_type;

SELECT
    'document.document_template' AS table_name,
    COUNT(*) AS seeded_rows
FROM document.document_template;

SELECT
    'configuration.configuration' AS table_name,
    COUNT(*) AS seeded_rows
FROM configuration.configuration;

SELECT
    'system.engine' AS table_name,
    COUNT(*) AS seeded_rows
FROM system.engine;

SELECT
    'system.engine_version' AS table_name,
    COUNT(*) AS seeded_rows
FROM system.engine_version;

SELECT
    'system.feature_flag' AS table_name,
    COUNT(*) AS seeded_rows
FROM system.feature_flag;

SELECT
    'communication.template' AS table_name,
    COUNT(*) AS seeded_rows
FROM communication.template;

COMMIT;

-- =============================================================================
-- END — AMEXAN PHASE 1 / SEED C
-- =============================================================================