-- =============================================================================
-- AMEXAN Phase 1 — Seed B: security (permissions, roles, scopes)
-- =============================================================================
-- Idempotent. Role ids are deterministic UUIDs so they can be re-seeded.
-- =============================================================================

INSERT INTO security.permission (code, resource, action, description) VALUES
   ('patient.view',         'patient',   'view',    'View a patient record'),
   ('patient.create',       'patient',   'create',  'Register a patient'),
   ('patient.update',       'patient',   'update',  'Update a patient record'),
   ('patient.restrict',     'patient',   'restrict','Set privacy restrictions'),
   ('encounter.view',       'encounter', 'view',    'View an encounter'),
   ('encounter.document',   'encounter', 'document','Document on an encounter'),
   ('encounter.update',     'encounter', 'update',  'Update an encounter'),
   ('encounter.cancel',     'encounter', 'cancel',  'Cancel an encounter'),
   ('order.view',           'order',     'view',    'View orders'),
   ('order.lab',            'order',     'lab',     'Order laboratory tests'),
   ('order.imaging',        'order',     'imaging', 'Order imaging'),
   ('order.prescribe',      'order',     'prescribe','Prescribe medication'),
   ('order.manage',         'order',     'manage',  'Manage any order'),
   ('result.view',          'result',    'view',    'View results'),
   ('document.view',        'document',  'view',    'View documents'),
   ('document.sign',        'document',  'sign',    'Sign documents'),
   ('document.export',      'document',  'export',  'Export documents'),
   ('appointment.view',     'appointment','view',   'View appointments'),
   ('appointment.book',     'appointment','book',   'Book appointments'),
   ('appointment.manage',   'appointment','manage', 'Manage appointments'),
   ('configuration.view',   'configuration','view', 'View configuration'),
   ('configuration.manage', 'configuration','manage','Change configuration'),
   ('audit.view',           'audit',     'view',    'View audit trail'),
   ('admin.all',            'system',    'admin',   'Full administrative access')
ON CONFLICT (code) DO NOTHING;

INSERT INTO security.role (id, code, name, description, is_system) VALUES
   ('00000000-0000-0000-0000-000000000201', 'administrator', 'Administrator', 'Full platform access', true),
   ('00000000-0000-0000-0000-000000000202', 'doctor',        'Doctor',        'Clinical clinician role', true),
   ('00000000-0000-0000-0000-000000000203', 'nurse',         'Nurse',         'Nursing role', true),
   ('00000000-0000-0000-0000-000000000204', 'receptionist',  'Receptionist',  'Front office role', true),
   ('00000000-0000-0000-0000-000000000205', 'pharmacist',    'Pharmacist',    'Pharmacy role', true),
   ('00000000-0000-0000-0000-000000000206', 'lab_technician','Lab Technician','Laboratory role', true)
ON CONFLICT (id) DO NOTHING;

-- administrator: everything
INSERT INTO security.role_permission (role_id, permission_code)
SELECT r.id, p.code
FROM security.role r, security.permission p
WHERE r.code = 'administrator'
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- doctor
INSERT INTO security.role_permission (role_id, permission_code) VALUES
   ('00000000-0000-0000-0000-000000000202', 'patient.view'),
   ('00000000-0000-0000-0000-000000000202', 'patient.update'),
   ('00000000-0000-0000-0000-000000000202', 'patient.restrict'),
   ('00000000-0000-0000-0000-000000000202', 'encounter.view'),
   ('00000000-0000-0000-0000-000000000202', 'encounter.document'),
   ('00000000-0000-0000-0000-000000000202', 'encounter.update'),
   ('00000000-0000-0000-0000-000000000202', 'order.view'),
   ('00000000-0000-0000-0000-000000000202', 'order.lab'),
   ('00000000-0000-0000-0000-000000000202', 'order.imaging'),
   ('00000000-0000-0000-0000-000000000202', 'order.prescribe'),
   ('00000000-0000-0000-0000-000000000202', 'result.view'),
   ('00000000-0000-0000-0000-000000000202', 'document.view'),
   ('00000000-0000-0000-0000-000000000202', 'document.sign'),
   ('00000000-0000-0000-0000-000000000202', 'appointment.view'),
   ('00000000-0000-0000-0000-000000000202', 'appointment.book')
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- nurse
INSERT INTO security.role_permission (role_id, permission_code) VALUES
   ('00000000-0000-0000-0000-000000000203', 'patient.view'),
   ('00000000-0000-0000-0000-000000000203', 'patient.update'),
   ('00000000-0000-0000-0000-000000000203', 'encounter.view'),
   ('00000000-0000-0000-0000-000000000203', 'encounter.document'),
   ('00000000-0000-0000-0000-000000000203', 'order.view'),
   ('00000000-0000-0000-0000-000000000203', 'result.view'),
   ('00000000-0000-0000-0000-000000000203', 'document.view'),
   ('00000000-0000-0000-0000-000000000203', 'appointment.book')
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- receptionist
INSERT INTO security.role_permission (role_id, permission_code) VALUES
   ('00000000-0000-0000-0000-000000000204', 'patient.view'),
   ('00000000-0000-0000-0000-000000000204', 'patient.create'),
   ('00000000-0000-0000-0000-000000000204', 'patient.update'),
   ('00000000-0000-0000-0000-000000000204', 'encounter.view'),
   ('00000000-0000-0000-0000-000000000204', 'appointment.view'),
   ('00000000-0000-0000-0000-000000000204', 'appointment.book'),
   ('00000000-0000-0000-0000-000000000204', 'appointment.manage')
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- pharmacist
INSERT INTO security.role_permission (role_id, permission_code) VALUES
   ('00000000-0000-0000-0000-000000000205', 'patient.view'),
   ('00000000-0000-0000-0000-000000000205', 'order.view'),
   ('00000000-0000-0000-0000-000000000205', 'order.prescribe'),
   ('00000000-0000-0000-0000-000000000205', 'result.view'),
   ('00000000-0000-0000-0000-000000000205', 'document.view')
ON CONFLICT (role_id, permission_code) DO NOTHING;

-- lab technician
INSERT INTO security.role_permission (role_id, permission_code) VALUES
   ('00000000-0000-0000-0000-000000000206', 'patient.view'),
   ('00000000-0000-0000-0000-000000000206', 'order.view'),
   ('00000000-0000-0000-0000-000000000206', 'result.view'),
   ('00000000-0000-0000-0000-000000000206', 'document.view')
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO security.api_scope (code, label, description) VALUES
   ('patient:read',   'Read patients',   'Read access to patient records'),
   ('patient:write',  'Write patients',  'Create/update patient records'),
   ('encounter:read', 'Read encounters', 'Read access to encounters'),
   ('encounter:write','Write encounters','Create/update encounters'),
   ('order:read',     'Read orders',     'Read access to orders'),
   ('order:write',    'Write orders',    'Create/update orders'),
   ('result:read',    'Read results',    'Read access to results')
ON CONFLICT (code) DO NOTHING;

INSERT INTO security.consent_policy (id, code, name, data_category, consent_required, retention_days, description) VALUES
   ('00000000-0000-0000-0000-000000000301', 'hiv_status',        'HIV status',        'hiv_status',        true,  NULL, 'HIV-related data is highly sensitive'),
   ('00000000-0000-0000-0000-000000000302', 'mental_health',     'Mental health',     'mental_health',     true,  NULL, 'Mental health data'),
   ('00000000-0000-0000-0000-000000000303', 'research_secondary','Research re-use',   'research',          true,  NULL, 'Secondary use of data for research')
ON CONFLICT (id) DO NOTHING;
