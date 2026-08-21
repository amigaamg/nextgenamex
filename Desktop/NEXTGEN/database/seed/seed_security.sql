-- =============================================================================
-- AMEXAN PHASE 1 — SEED B
-- SECURITY / IDENTITY AUTHORIZATION / CONSENT / INTEROPERABILITY ACCESS
-- =============================================================================
-- Purpose:
--   Establish the canonical AMEXAN security vocabulary for:
--     • RBAC
--     • least-privilege authorization
--     • patient privacy
--     • longitudinal record access
--     • consent-aware access
--     • clinical break-glass access
--     • audit access
--     • API / interoperability scopes
--     • research / secondary-use controls
--     • health-information exchange
--     • future distributed-ledger / blockchain anchoring
--
-- SECURITY PRINCIPLES:
--   1. Authentication != authorization.
--   2. Role != permission.
--   3. Permission != API scope.
--   4. Clinical access must remain patient/context scoped.
--   5. Longitudinal records must preserve provenance and history.
--   6. Corrections must never silently destroy historical clinical facts.
--   7. Sensitive information must require additional authorization.
--   8. Break-glass access must be exceptional and auditable.
--   9. Interoperability must expose minimum necessary information.
--  10. Blockchain / distributed ledger must never become the PHI store.
--      Only cryptographic proofs, identifiers, timestamps or integrity
--      commitments may be anchored externally.
--
-- IDEMPOTENCY:
--   All reference data uses ON CONFLICT DO NOTHING.
--
-- IMPORTANT:
--   This seed contains NO patient data.
--   This seed contains NO clinical diagnosis logic.
--   This seed contains NO passwords, secrets, API keys or private keys.
-- =============================================================================


BEGIN;


-- ============================================================================
-- 1. CANONICAL SECURITY PERMISSIONS
-- ============================================================================

INSERT INTO security.permission
    (code, resource, action, description)
VALUES

-- --------------------------------------------------------------------------
-- PATIENT / MASTER PATIENT RECORD
-- --------------------------------------------------------------------------
('patient.view',
 'patient',
 'view',
 'View permitted patient demographic and clinical identity information'),

('patient.create',
 'patient',
 'create',
 'Create/register a patient record'),

('patient.update',
 'patient',
 'update',
 'Update permitted patient demographic or administrative information'),

('patient.merge',
 'patient',
 'merge',
 'Perform controlled duplicate-patient merge'),

('patient.restrict',
 'patient',
 'restrict',
 'Apply or manage patient privacy restrictions'),

('patient.unrestrict',
 'patient',
 'unrestrict',
 'Remove a patient privacy restriction when authorized'),

('patient.export',
 'patient',
 'export',
 'Export permitted patient information'),

('patient.deidentify',
 'patient',
 'deidentify',
 'Create an authorized de-identified representation'),

('patient.link',
 'patient',
 'link',
 'Link a patient to an external longitudinal identity or health record'),

('patient.identity_verify',
 'patient',
 'identity_verify',
 'Verify patient identity or identity attributes'),

-- --------------------------------------------------------------------------
-- LONGITUDINAL RECORD
-- --------------------------------------------------------------------------
('record.view',
 'record',
 'view',
 'View the authorized longitudinal health record'),

('record.create',
 'record',
 'create',
 'Create a longitudinal record event'),

('record.append',
 'record',
 'append',
 'Append a new immutable clinical record event'),

('record.correct',
 'record',
 'correct',
 'Correct an erroneous clinical record through controlled provenance'),

('record.supersede',
 'record',
 'supersede',
 'Supersede a previous record version without destroying history'),

('record.retract',
 'record',
 'retract',
 'Retract a record when legally and clinically authorized'),

('record.export',
 'record',
 'export',
 'Export an authorized longitudinal record'),

('record.exchange',
 'record',
 'exchange',
 'Exchange authorized longitudinal information with another system'),

-- --------------------------------------------------------------------------
-- ENCOUNTER
-- --------------------------------------------------------------------------
('encounter.view',
 'encounter',
 'view',
 'View an authorized encounter'),

('encounter.create',
 'encounter',
 'create',
 'Create an encounter'),

('encounter.document',
 'encounter',
 'document',
 'Document clinical information within an encounter'),

('encounter.update',
 'encounter',
 'update',
 'Update permitted encounter information'),

('encounter.cancel',
 'encounter',
 'cancel',
 'Cancel an encounter'),

('encounter.complete',
 'encounter',
 'complete',
 'Complete an encounter'),

('encounter.reopen',
 'encounter',
 'reopen',
 'Reopen a completed encounter under controlled authorization'),

-- --------------------------------------------------------------------------
-- CLINICAL FACTS / PROBLEMS / DIAGNOSES
-- --------------------------------------------------------------------------
('fact.view',
 'fact',
 'view',
 'View clinical facts'),

('fact.create',
 'fact',
 'create',
 'Create a clinical fact'),

('fact.correct',
 'fact',
 'correct',
 'Correct a clinical fact with provenance'),

('fact.retract',
 'fact',
 'retract',
 'Retract a clinical fact'),

('problem.view',
 'problem',
 'view',
 'View patient problems'),

('problem.create',
 'problem',
 'create',
 'Create a patient problem'),

('problem.update',
 'problem',
 'update',
 'Update a patient problem'),

('diagnosis.view',
 'diagnosis',
 'view',
 'View diagnoses'),

('diagnosis.create',
 'diagnosis',
 'create',
 'Create a diagnosis'),

('diagnosis.update',
 'diagnosis',
 'update',
 'Update diagnosis status'),

-- --------------------------------------------------------------------------
-- ORDERS
-- --------------------------------------------------------------------------
('order.view',
 'order',
 'view',
 'View orders'),

('order.create',
 'order',
 'create',
 'Create an order'),

('order.lab',
 'order',
 'lab',
 'Order laboratory investigations'),

('order.imaging',
 'order',
 'imaging',
 'Order imaging investigations'),

('order.prescribe',
 'order',
 'prescribe',
 'Prescribe medication'),

('order.procedure',
 'order',
 'procedure',
 'Order a procedure'),

('order.consultation',
 'order',
 'consultation',
 'Request a clinical consultation'),

('order.nursing',
 'order',
 'nursing',
 'Create nursing orders'),

('order.manage',
 'order',
 'manage',
 'Manage orders within authorized scope'),

('order.cancel',
 'order',
 'cancel',
 'Cancel an order'),

-- --------------------------------------------------------------------------
-- RESULTS
-- --------------------------------------------------------------------------
('result.view',
 'result',
 'view',
 'View investigation results'),

('result.create',
 'result',
 'create',
 'Create or enter an authorized result'),

('result.verify',
 'result',
 'verify',
 'Verify a result'),

('result.correct',
 'result',
 'correct',
 'Correct a result using controlled provenance'),

('result.release',
 'result',
 'release',
 'Release a result to an authorized recipient'),

-- --------------------------------------------------------------------------
-- DOCUMENTATION
-- --------------------------------------------------------------------------
('document.view',
 'document',
 'view',
 'View authorized clinical documents'),

('document.create',
 'document',
 'create',
 'Create a clinical document'),

('document.update',
 'document',
 'update',
 'Update an unsigned document'),

('document.sign',
 'document',
 'sign',
 'Electronically sign a clinical document'),

('document.amend',
 'document',
 'amend',
 'Create a controlled amendment to a signed document'),

('document.export',
 'document',
 'export',
 'Export an authorized document'),

('document.verify',
 'document',
 'verify',
 'Verify document integrity or signature'),

-- --------------------------------------------------------------------------
-- MEDICATION / PHARMACY
-- --------------------------------------------------------------------------
('medication.view',
 'medication',
 'view',
 'View medication information'),

('medication.prescribe',
 'medication',
 'prescribe',
 'Prescribe medication'),

('medication.dispense',
 'medication',
 'dispense',
 'Dispense medication'),

('medication.administer',
 'medication',
 'administer',
 'Record medication administration'),

('medication.reconcile',
 'medication',
 'reconcile',
 'Perform medication reconciliation'),

-- --------------------------------------------------------------------------
-- APPOINTMENTS
-- --------------------------------------------------------------------------
('appointment.view',
 'appointment',
 'view',
 'View authorized appointments'),

('appointment.book',
 'appointment',
 'book',
 'Book an appointment'),

('appointment.manage',
 'appointment',
 'manage',
 'Manage appointments'),

('appointment.cancel',
 'appointment',
 'cancel',
 'Cancel an appointment'),

-- --------------------------------------------------------------------------
-- CARE TEAM
-- --------------------------------------------------------------------------
('care_team.view',
 'care_team',
 'view',
 'View authorized care-team membership'),

('care_team.manage',
 'care_team',
 'manage',
 'Manage care-team membership'),

-- --------------------------------------------------------------------------
-- CONSENT / PRIVACY
-- --------------------------------------------------------------------------
('consent.view',
 'consent',
 'view',
 'View consent status'),

('consent.capture',
 'consent',
 'capture',
 'Capture patient consent'),

('consent.withdraw',
 'consent',
 'withdraw',
 'Record withdrawal of consent'),

('consent.manage',
 'consent',
 'manage',
 'Manage authorized consent policies'),

('privacy.view',
 'privacy',
 'view',
 'View privacy restrictions'),

('privacy.manage',
 'privacy',
 'manage',
 'Manage patient privacy restrictions'),

-- --------------------------------------------------------------------------
-- AUDIT / SECURITY
-- --------------------------------------------------------------------------
('audit.view',
 'audit',
 'view',
 'View audit records'),

('audit.export',
 'audit',
 'export',
 'Export audit records'),

('audit.security',
 'audit',
 'security',
 'View security-relevant audit events'),

('security.manage',
 'security',
 'manage',
 'Manage security configuration'),

('security.roles',
 'security',
 'roles',
 'Manage roles and permissions'),

('security.sessions',
 'security',
 'sessions',
 'Manage authorized sessions'),

('security.break_glass',
 'security',
 'break_glass',
 'Authorize or review emergency break-glass access'),

-- --------------------------------------------------------------------------
-- ORGANIZATION / CONFIGURATION
-- --------------------------------------------------------------------------
('organization.view',
 'organization',
 'view',
 'View organization information'),

('organization.manage',
 'organization',
 'manage',
 'Manage organization configuration'),

('configuration.view',
 'configuration',
 'view',
 'View configuration'),

('configuration.manage',
 'configuration',
 'manage',
 'Manage configuration'),

-- --------------------------------------------------------------------------
-- INTEROPERABILITY
-- --------------------------------------------------------------------------
('interop.read',
 'interop',
 'read',
 'Read authorized information through interoperability services'),

('interop.write',
 'interop',
 'write',
 'Write authorized information through interoperability services'),

('interop.exchange',
 'interop',
 'exchange',
 'Exchange authorized health information'),

('interop.fhir',
 'interop',
 'fhir',
 'Use authorized FHIR interoperability operations'),

('interop.import',
 'interop',
 'import',
 'Import authorized external health information'),

('interop.export',
 'interop',
 'export',
 'Export authorized health information'),

('interop.identity',
 'interop',
 'identity',
 'Perform authorized cross-system patient identity operations'),

-- --------------------------------------------------------------------------
-- RESEARCH / SECONDARY USE
-- --------------------------------------------------------------------------
('research.view',
 'research',
 'view',
 'View authorized research datasets'),

('research.export',
 'research',
 'export',
 'Export authorized research datasets'),

('research.deidentify',
 'research',
 'deidentify',
 'Generate authorized de-identified research data'),

('research.consent',
 'research',
 'consent',
 'Manage research-use consent'),

-- --------------------------------------------------------------------------
-- SYSTEM
-- --------------------------------------------------------------------------
('system.monitor',
 'system',
 'monitor',
 'Monitor platform health'),

('system.admin',
 'system',
 'admin',
 'Perform platform administration'),

('admin.all',
 'system',
 'admin',
 'Full administrative access')

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 2. SYSTEM ROLES
-- ============================================================================

INSERT INTO security.role
    (id, code, name, description, is_system)
VALUES

('00000000-0000-0000-0000-000000000201',
 'administrator',
 'Administrator',
 'Full AMEXAN platform administration',
 true),

('00000000-0000-0000-0000-000000000202',
 'doctor',
 'Doctor',
 'Medical doctor / clinician',
 true),

('00000000-0000-0000-0000-000000000203',
 'nurse',
 'Nurse',
 'Nursing clinician',
 true),

('00000000-0000-0000-0000-000000000204',
 'receptionist',
 'Receptionist',
 'Registration and front-office role',
 true),

('00000000-0000-0000-0000-000000000205',
 'pharmacist',
 'Pharmacist',
 'Pharmacy professional',
 true),

('00000000-0000-0000-0000-000000000206',
 'lab_technician',
 'Laboratory Technician',
 'Laboratory professional',
 true),

('00000000-0000-0000-0000-000000000207',
 'clinical_officer',
 'Clinical Officer',
 'Clinical officer',
 true),

('00000000-0000-0000-0000-000000000208',
 'midwife',
 'Midwife',
 'Midwifery professional',
 true),

('00000000-0000-0000-0000-000000000209',
 'radiographer',
 'Radiographer',
 'Radiography professional',
 true),

('00000000-0000-0000-0000-000000000210',
 'records_officer',
 'Health Records Officer',
 'Health information and records professional',
 true),

('00000000-0000-0000-0000-000000000211',
 'auditor',
 'Clinical / Security Auditor',
 'Read-only audit and compliance role',
 true),

('00000000-0000-0000-0000-000000000212',
 'researcher',
 'Researcher',
 'Authorized research and secondary-use role',
 true),

('00000000-0000-0000-0000-000000000213',
 'system_operator',
 'System Operator',
 'Technical operations without unrestricted clinical access',
 true),

('00000000-0000-0000-0000-000000000214',
 'specialist',
 'Specialist Clinician',
 'Specialist clinical role',
 true)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 3. ADMINISTRATOR
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    r.id,
    p.code
FROM security.role r
CROSS JOIN security.permission p
WHERE r.code = 'administrator'
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 4. DOCTOR
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000202',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.update',
 'patient.restrict',
 'patient.identity_verify',

 'record.view',
 'record.create',
 'record.append',
 'record.correct',
 'record.supersede',
 'record.exchange',

 'encounter.view',
 'encounter.create',
 'encounter.document',
 'encounter.update',
 'encounter.complete',
 'encounter.reopen',

 'fact.view',
 'fact.create',
 'fact.correct',

 'problem.view',
 'problem.create',
 'problem.update',

 'diagnosis.view',
 'diagnosis.create',
 'diagnosis.update',

 'order.view',
 'order.create',
 'order.lab',
 'order.imaging',
 'order.prescribe',
 'order.procedure',
 'order.consultation',
 'order.cancel',

 'result.view',
 'result.verify',

 'document.view',
 'document.create',
 'document.update',
 'document.sign',
 'document.amend',
 'document.export',

 'medication.view',
 'medication.prescribe',
 'medication.reconcile',

 'appointment.view',
 'appointment.book',

 'care_team.view',
 'care_team.manage',

 'consent.view',
 'consent.capture',
 'consent.withdraw',

 'privacy.view',

 'interop.read',
 'interop.exchange',
 'interop.fhir',

 'security.break_glass'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 5. SPECIALIST
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000214',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.update',
 'patient.restrict',
 'patient.identity_verify',

 'record.view',
 'record.create',
 'record.append',
 'record.correct',
 'record.supersede',
 'record.exchange',

 'encounter.view',
 'encounter.create',
 'encounter.document',
 'encounter.update',
 'encounter.complete',
 'encounter.reopen',

 'fact.view',
 'fact.create',
 'fact.correct',

 'problem.view',
 'problem.create',
 'problem.update',

 'diagnosis.view',
 'diagnosis.create',
 'diagnosis.update',

 'order.view',
 'order.create',
 'order.lab',
 'order.imaging',
 'order.prescribe',
 'order.procedure',
 'order.consultation',
 'order.cancel',

 'result.view',
 'result.verify',

 'document.view',
 'document.create',
 'document.update',
 'document.sign',
 'document.amend',
 'document.export',

 'medication.view',
 'medication.prescribe',
 'medication.reconcile',

 'care_team.view',
 'care_team.manage',

 'consent.view',
 'consent.capture',
 'consent.withdraw',

 'privacy.view',

 'interop.read',
 'interop.exchange',
 'interop.fhir',

 'security.break_glass'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 6. CLINICAL OFFICER
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000207',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.update',
 'patient.identity_verify',

 'record.view',
 'record.create',
 'record.append',
 'record.correct',

 'encounter.view',
 'encounter.create',
 'encounter.document',
 'encounter.update',
 'encounter.complete',

 'fact.view',
 'fact.create',
 'fact.correct',

 'problem.view',
 'problem.create',
 'problem.update',

 'diagnosis.view',
 'diagnosis.create',
 'diagnosis.update',

 'order.view',
 'order.create',
 'order.lab',
 'order.imaging',
 'order.prescribe',
 'order.procedure',
 'order.consultation',

 'result.view',

 'document.view',
 'document.create',
 'document.sign',

 'medication.view',
 'medication.prescribe',
 'medication.reconcile',

 'appointment.view',
 'appointment.book',

 'care_team.view',

 'consent.view',
 'consent.capture',
 'consent.withdraw',

 'privacy.view',

 'interop.read',
 'interop.fhir',

 'security.break_glass'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 7. NURSE
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000203',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.update',
 'patient.identity_verify',

 'record.view',
 'record.create',
 'record.append',

 'encounter.view',
 'encounter.document',
 'encounter.update',

 'fact.view',
 'fact.create',

 'problem.view',

 'order.view',
 'order.nursing',

 'result.view',

 'document.view',
 'document.create',
 'document.sign',

 'medication.view',
 'medication.administer',
 'medication.reconcile',

 'appointment.view',
 'appointment.book',

 'care_team.view',

 'consent.view',
 'consent.capture',

 'privacy.view',

 'interop.read'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 8. MIDWIFE
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000208',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.update',
 'patient.identity_verify',

 'record.view',
 'record.create',
 'record.append',
 'record.correct',

 'encounter.view',
 'encounter.create',
 'encounter.document',
 'encounter.update',
 'encounter.complete',

 'fact.view',
 'fact.create',
 'fact.correct',

 'problem.view',
 'problem.create',
 'problem.update',

 'diagnosis.view',
 'diagnosis.create',
 'diagnosis.update',

 'order.view',
 'order.create',
 'order.lab',
 'order.imaging',
 'order.consultation',

 'result.view',

 'document.view',
 'document.create',
 'document.sign',

 'medication.view',
 'medication.administer',
 'medication.reconcile',

 'care_team.view',

 'consent.view',
 'consent.capture',
 'consent.withdraw',

 'privacy.view',

 'interop.read',
 'interop.fhir',

 'security.break_glass'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 9. PHARMACIST
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000205',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',

 'record.view',

 'encounter.view',

 'order.view',
 'order.prescribe',
 'order.manage',
 'order.cancel',

 'result.view',

 'document.view',

 'medication.view',
 'medication.prescribe',
 'medication.dispense',
 'medication.reconcile',

 'care_team.view',

 'consent.view',

 'privacy.view',

 'interop.read'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 10. LABORATORY TECHNICIAN
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000206',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',

 'record.view',

 'encounter.view',

 'order.view',
 'order.lab',

 'result.view',
 'result.create',
 'result.verify',
 'result.correct',

 'document.view',

 'consent.view',

 'privacy.view',

 'interop.read'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 11. RADIOGRAPHER
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000209',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'record.view',
 'encounter.view',

 'order.view',
 'order.imaging',

 'result.view',
 'result.create',
 'result.verify',

 'document.view',

 'consent.view',
 'privacy.view',

 'interop.read'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 12. RECEPTIONIST
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000204',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.create',
 'patient.update',
 'patient.identity_verify',

 'encounter.view',
 'encounter.create',

 'appointment.view',
 'appointment.book',
 'appointment.manage',
 'appointment.cancel',

 'organization.view'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 13. HEALTH RECORDS OFFICER
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000210',
    code
FROM security.permission
WHERE code IN
(
 'patient.view',
 'patient.create',
 'patient.update',
 'patient.merge',
 'patient.identity_verify',

 'record.view',
 'record.create',
 'record.append',
 'record.correct',
 'record.supersede',
 'record.export',
 'record.exchange',

 'encounter.view',

 'document.view',
 'document.export',
 'document.verify',

 'consent.view',
 'consent.capture',
 'consent.withdraw',

 'privacy.view',
 'privacy.manage',

 'interop.read',
 'interop.write',
 'interop.exchange',
 'interop.fhir',
 'interop.import',
 'interop.export',
 'interop.identity'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 14. AUDITOR
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000211',
    code
FROM security.permission
WHERE code IN
(
 'audit.view',
 'audit.export',
 'audit.security',

 'security.sessions',

 'organization.view'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 15. RESEARCHER
-- ============================================================================

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000212',
    code
FROM security.permission
WHERE code IN
(
 'research.view',
 'research.export',
 'research.deidentify',
 'research.consent',

 'consent.view'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 16. SYSTEM OPERATOR
-- ============================================================================
-- Technical operations should NOT automatically grant clinical record access.

INSERT INTO security.role_permission (role_id, permission_code)
SELECT
    '00000000-0000-0000-0000-000000000213',
    code
FROM security.permission
WHERE code IN
(
 'system.monitor',
 'configuration.view',
 'audit.security'
)
  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 17. API / INTEROPERABILITY SCOPES
-- ============================================================================
-- OAuth/API scopes are deliberately separate from clinical RBAC permissions.
-- Possession of an API token must never imply unrestricted clinical access.

INSERT INTO security.api_scope
    (code, label, description)
VALUES

('patient:read',
 'Read patients',
 'Read patient information permitted by authorization and policy'),

('patient:write',
 'Write patients',
 'Create/update patient information permitted by authorization'),

('patient:identity',
 'Patient identity',
 'Perform authorized patient identity matching/linking'),

('record:read',
 'Read longitudinal records',
 'Read authorized longitudinal health information'),

('record:write',
 'Write longitudinal records',
 'Append authorized longitudinal health information'),

('record:correct',
 'Correct records',
 'Perform controlled record correction/supersession'),

('encounter:read',
 'Read encounters',
 'Read authorized encounters'),

('encounter:write',
 'Write encounters',
 'Create/update authorized encounters'),

('order:read',
 'Read orders',
 'Read authorized orders'),

('order:write',
 'Write orders',
 'Create/update authorized orders'),

('result:read',
 'Read results',
 'Read authorized clinical results'),

('result:write',
 'Write results',
 'Submit authorized results'),

('document:read',
 'Read documents',
 'Read authorized clinical documents'),

('document:write',
 'Write documents',
 'Create authorized clinical documents'),

('document:sign',
 'Sign documents',
 'Sign authorized clinical documents'),

('consent:read',
 'Read consent',
 'Read authorization/consent state'),

('consent:write',
 'Write consent',
 'Create/update consent records'),

('audit:read',
 'Read audit',
 'Read permitted audit information'),

('fhir:read',
 'FHIR read',
 'Read authorized FHIR resources'),

('fhir:write',
 'FHIR write',
 'Write authorized FHIR resources'),

('interop:exchange',
 'Health information exchange',
 'Exchange authorized health information'),

('research:read',
 'Research read',
 'Read authorized research datasets'),

('research:export',
 'Research export',
 'Export approved research datasets'),

('deidentified:read',
 'De-identified read',
 'Read approved de-identified datasets')

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 18. HIGH-SENSITIVITY CONSENT / PRIVACY POLICIES
-- ============================================================================
-- These are policy categories, not permission bypasses.
-- Authorization must still be evaluated at runtime.

INSERT INTO security.consent_policy
    (id, code, name, data_category, consent_required, retention_days, description)
VALUES

(
 '00000000-0000-0000-0000-000000000301',
 'hiv_status',
 'HIV status',
 'hiv_status',
 true,
 NULL,
 'Highly sensitive health information requiring enhanced confidentiality controls'
),

(
 '00000000-0000-0000-0000-000000000302',
 'mental_health',
 'Mental health',
 'mental_health',
 true,
 NULL,
 'Mental health information requiring enhanced privacy controls'
),

(
 '00000000-0000-0000-0000-000000000303',
 'sexual_reproductive_health',
 'Sexual and reproductive health',
 'sexual_reproductive_health',
 true,
 NULL,
 'Sensitive sexual and reproductive health information'
),

(
 '00000000-0000-0000-0000-000000000304',
 'genetic',
 'Genetic information',
 'genetic',
 true,
 NULL,
 'Genomic or genetic information requiring enhanced controls'
),

(
 '00000000-0000-0000-0000-000000000305',
 'substance_use',
 'Substance use',
 'substance_use',
 true,
 NULL,
 'Substance-use-related health information'
),

(
 '00000000-0000-0000-0000-000000000306',
 'child_protection',
 'Child protection',
 'child_protection',
 true,
 NULL,
 'Safeguarding and child-protection information'
),

(
 '00000000-0000-0000-0000-000000000307',
 'research_secondary',
 'Research secondary use',
 'research',
 true,
 NULL,
 'Secondary use of health information for research'
),

(
 '00000000-0000-0000-0000-000000000308',
 'cross_organization_exchange',
 'Cross-organization exchange',
 'health_information_exchange',
 true,
 NULL,
 'Controlled exchange of patient information between organizations'
),

(
 '00000000-0000-0000-0000-000000000309',
 'longitudinal_record_exchange',
 'Longitudinal record exchange',
 'longitudinal_record',
 true,
 NULL,
 'Controlled exchange of longitudinal health information'
)

  ON CONFLICT DO NOTHING;


-- ============================================================================
-- 19. VERIFICATION — PERMISSION COUNTS
-- ============================================================================

SELECT
    'SECURITY PERMISSIONS' AS section,
    COUNT(*) AS count
FROM security.permission;


SELECT
    'SECURITY ROLES' AS section,
    COUNT(*) AS count
FROM security.role;


SELECT
    'ROLE-PERMISSION LINKS' AS section,
    COUNT(*) AS count
FROM security.role_permission;


SELECT
    'API SCOPES' AS section,
    COUNT(*) AS count
FROM security.api_scope;


SELECT
    'CONSENT POLICIES' AS section,
    COUNT(*) AS count
FROM security.consent_policy;


-- ============================================================================
-- 20. ROLE COVERAGE AUDIT
-- ============================================================================

SELECT
    r.code AS role_code,
    r.name AS role_name,
    COUNT(rp.permission_code) AS permission_count
FROM security.role r
LEFT JOIN security.role_permission rp
       ON rp.role_id = r.id
GROUP BY r.id, r.code, r.name
ORDER BY r.code;


-- ============================================================================
-- 21. CRITICAL SECURITY CHECKS
-- ============================================================================

-- Administrator must have every defined permission.
SELECT
    'ADMIN_PERMISSION_GAP' AS check_name,
    COUNT(*) AS missing_permissions
FROM security.permission p
WHERE NOT EXISTS
(
    SELECT 1
    FROM security.role r
    JOIN security.role_permission rp
      ON rp.role_id = r.id
     AND rp.permission_code = p.code
    WHERE r.code = 'administrator'
);


-- System operator must NOT automatically receive patient access.
SELECT
    'SYSTEM_OPERATOR_PATIENT_ACCESS' AS check_name,
    COUNT(*) AS dangerous_permissions
FROM security.role_permission rp
JOIN security.role r
  ON r.id = rp.role_id
WHERE r.code = 'system_operator'
  AND rp.permission_code IN
  (
      'patient.view',
      'patient.create',
      'patient.update',
      'record.view',
      'record.export'
  );


-- Researcher must not receive unrestricted clinical access.
SELECT
    'RESEARCHER_CLINICAL_ACCESS' AS check_name,
    COUNT(*) AS dangerous_permissions
FROM security.role_permission rp
JOIN security.role r
  ON r.id = rp.role_id
WHERE r.code = 'researcher'
  AND rp.permission_code IN
  (
      'patient.view',
      'patient.update',
      'record.view',
      'record.create',
      'record.export',
      'diagnosis.create',
      'order.create'
  );


-- ============================================================================
-- 22. SECURITY MODEL CONTRACT
-- ============================================================================
-- These comments are intentional architectural documentation.
--
-- AMEXAN authorization evaluation should conceptually be:
--
--   AUTHORIZATION =
--       authenticated_identity
--     + active_role
--     + permission
--     + organization_scope
--     + facility_scope
--     + department_scope
--     + care_relationship
--     + patient_relationship
--     + purpose_of_use
--     + consent_state
--     + sensitivity_policy
--     + encounter_context
--     + emergency_state
--     + time_validity
--     + audit_requirement
--
-- NOT:
--
--   role == doctor -> allow everything
--
-- ============================================================================
-- LONGITUDINAL PRINCIPLE
-- ============================================================================
--
-- A patient's record is a longitudinal chain of clinical events.
--
-- Existing information MUST NOT be silently overwritten merely because
-- a newer value exists.
--
-- Preferred lifecycle:
--
--   ENTERED
--       |
--       v
--     ACTIVE
--       |
--       +----> CORRECTED
--       |
--       +----> SUPERSEDED
--       |
--       +----> RETRACTED
--
-- The original event remains part of provenance.
--
-- ============================================================================
-- INTEROPERABILITY PRINCIPLE
-- ============================================================================
--
-- AMEXAN may exchange information with:
--
--   • HMIS
--   • EMR
--   • EHR
--   • laboratory systems
--   • radiology systems
--   • pharmacy systems
--   • national health information exchanges
--   • FHIR servers
--   • approved research systems
--   • future distributed health networks
--
-- External systems must never receive unrestricted access merely because
-- an integration exists.
--
-- Every exchange should be:
--
--   authenticated
--   authorized
--   purpose-bound
--   minimum-necessary
--   consent-aware
--   auditable
--   traceable
--   revocable where applicable
--
-- ============================================================================
-- DISTRIBUTED LEDGER / BLOCKCHAIN PRINCIPLE
-- ============================================================================
--
-- DO NOT PUT:
--
--   patient names
--   diagnoses
--   laboratory results
--   medications
--   clinical notes
--   photographs
--   identifiers
--   genomic information
--   or other PHI
--
-- directly onto a public or immutable blockchain.
--
-- A future AMEXAN integrity-anchor layer may instead anchor:
--
--   • record hash
--   • document hash
--   • event hash
--   • Merkle root
--   • timestamp
--   • organization identifier
--   • cryptographic proof
--   • version identifier
--
-- The actual clinical record remains under governed health-information
-- storage and access control.
--
-- This allows later verification that:
--
--       local_record_hash
--              ==
--       previously_anchored_hash
--
-- without exposing the clinical payload.
--
-- ============================================================================
-- END SECURITY SEED B
-- ============================================================================


COMMIT;