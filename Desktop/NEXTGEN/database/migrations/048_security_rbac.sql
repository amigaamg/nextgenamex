-- =============================================================================
-- AMEXAN
-- PHASE 1 -- MIGRATION 048
-- SECURITY RBAC FOUNDATION
-- =============================================================================
--
-- Restores the AMEXAN authorization vocabulary that `seed_security.sql`
-- (SEED B) requires but which is not created by the current migrations:
--
--   security.permission          atomic permission (patient.view, order.lab)
--   security.role                named bundle of permissions
--   security.role_permission     permission granted to a role
--   security.organization_role   role instantiated within an organization
--   security.user_role           scoped role assignment to a user account
--   security.access_policy       declarative access rules
--   security.resource_policy     resource-level rules under a policy
--   security.api_client          external credentialed client
--   security.api_scope           API permission scopes
--   security.api_client_scope    scopes granted to an API client
--
-- It also reconciles `security.consent_policy` (created in migration 003 with
-- a minimal shape) to the richer shape `seed_security.sql` expects
-- (id, name, data_category, consent_required, retention_days), keeping the
-- original `code` primary key and `label`/`description`/`active` columns that
-- `patient.patient_consent` already references.
--
-- IDEMPOTENT: all statements are guarded.
-- =============================================================================


BEGIN;


-- =============================================================================
-- 1. ATOMIC PERMISSIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.permission (
    code              text PRIMARY KEY,
    resource          text NOT NULL,
    action            text NOT NULL,
    description       text,
    created_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(resource) <> ''),
    CHECK (btrim(action) <> '')
);

COMMENT ON TABLE security.permission IS
'Atomic permission. Example: patient.view, encounter.document, order.lab.';

CREATE INDEX IF NOT EXISTS idx_permission_resource
    ON security.permission(resource);

CREATE INDEX IF NOT EXISTS idx_permission_action
    ON security.permission(action);


-- =============================================================================
-- 2. ROLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.role (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    description       text,
    is_system         boolean NOT NULL DEFAULT false,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE security.role IS
'A named bundle of permissions (doctor, receptionist, nurse...).';

DROP TRIGGER IF EXISTS trg_role_updated_at ON security.role;
CREATE TRIGGER trg_role_updated_at
    BEFORE UPDATE ON security.role
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. ROLE <-> PERMISSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.role_permission (
    role_id           uuid NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
    permission_code   text NOT NULL REFERENCES security.permission(code) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_code)
);

COMMENT ON TABLE security.role_permission IS
'Permission granted to a role.';

CREATE INDEX IF NOT EXISTS idx_role_permission_permission
    ON security.role_permission(permission_code);


-- =============================================================================
-- 4. ORGANIZATION-SCOPED ROLE INSTANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.organization_role (
    organization_id   uuid NOT NULL REFERENCES organization.organization(id) ON DELETE CASCADE,
    role_id           uuid NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
    label             text,
    description       text,
    PRIMARY KEY (organization_id, role_id)
);

COMMENT ON TABLE security.organization_role IS
'A role as instantiated/scoped within an organization.';


-- =============================================================================
-- 5. USER ROLE ASSIGNMENT (WHO / WHERE / SCOPE)
-- =============================================================================
-- The admin side assigns roles to user accounts, optionally constrained to an
-- organization, facility and/or department.

CREATE TABLE IF NOT EXISTS security.user_role (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id   uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE CASCADE,
    role_id           uuid NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
    organization_id   uuid REFERENCES organization.organization(id),
    facility_id       uuid REFERENCES organization.facility(id),
    department_id     uuid REFERENCES organization.department(id),
    assigned_by       uuid REFERENCES identity.user_account(id),
    valid_from        timestamptz NOT NULL DEFAULT now(),
    valid_to          timestamptz,

    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

COMMENT ON TABLE security.user_role IS
'Role assignment to a user, optionally scoped to org/facility/department.';

CREATE INDEX IF NOT EXISTS idx_user_role_user ON security.user_role(user_account_id);
CREATE INDEX IF NOT EXISTS idx_user_role_role ON security.user_role(role_id);
CREATE INDEX IF NOT EXISTS idx_user_role_scope
    ON security.user_role(organization_id, facility_id, department_id);


-- =============================================================================
-- 6. DECLARATIVE ACCESS POLICIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.access_policy (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name              text NOT NULL UNIQUE,
    policy_type       text NOT NULL,
    rule              jsonb,
    description       text,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (policy_type IN ('role_based','attribute_based','organization_scoped','facility_scoped'))
);

COMMENT ON TABLE security.access_policy IS
'Declarative access rules evaluated by the engine.';

DROP TRIGGER IF EXISTS trg_access_policy_updated_at ON security.access_policy;
CREATE TRIGGER trg_access_policy_updated_at
    BEFORE UPDATE ON security.access_policy
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE IF NOT EXISTS security.resource_policy (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    access_policy_id  uuid NOT NULL REFERENCES security.access_policy(id) ON DELETE CASCADE,
    resource          text NOT NULL,
    resource_id       uuid,
    permission_code   text REFERENCES security.permission(code) ON DELETE SET NULL,
    effect            text NOT NULL DEFAULT 'allow' CHECK (effect IN ('allow','deny')),
    priority          integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE security.resource_policy IS
'Resource-level access rules under an access policy.';

CREATE INDEX IF NOT EXISTS idx_resource_policy_policy
    ON security.resource_policy(access_policy_id);


-- =============================================================================
-- 7. API CLIENTS AND SCOPES
-- =============================================================================

CREATE TABLE IF NOT EXISTS security.api_client (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id         text NOT NULL UNIQUE,
    client_name       text NOT NULL,
    client_secret_hash text,
    organization_id   uuid REFERENCES organization.organization(id),
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(client_id) <> ''),
    CHECK (btrim(client_name) <> '')
);

COMMENT ON TABLE security.api_client IS
'External application/credentialed client.';

DROP TRIGGER IF EXISTS trg_api_client_updated_at ON security.api_client;
CREATE TRIGGER trg_api_client_updated_at
    BEFORE UPDATE ON security.api_client
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE IF NOT EXISTS security.api_scope (
    code              text PRIMARY KEY,
    label             text NOT NULL,
    description       text,

    CHECK (btrim(code) <> ''),
    CHECK (btrim(label) <> '')
);

COMMENT ON TABLE security.api_scope IS
'API permission scopes (e.g. patient:read, orders:write).';


CREATE TABLE IF NOT EXISTS security.api_client_scope (
    client_id         uuid NOT NULL REFERENCES security.api_client(id) ON DELETE CASCADE,
    scope_code        text NOT NULL REFERENCES security.api_scope(code) ON DELETE CASCADE,
    PRIMARY KEY (client_id, scope_code)
);

COMMENT ON TABLE security.api_client_scope IS
'Scopes granted to an API client.';


-- =============================================================================
-- 8. CONSENT POLICY RECONCILIATION
-- =============================================================================
-- Migration 003 created security.consent_policy as (code, label, description,
-- active) with code as primary key. seed_security.sql inserts the richer shape
-- (id, code, name, data_category, consent_required, retention_days,
-- description) with ON CONFLICT (id). Extend the existing table in place and
-- keep code as the primary key so patient.patient_consent keeps working.

ALTER TABLE security.consent_policy
    ALTER COLUMN label DROP NOT NULL;

ALTER TABLE security.consent_policy
    ADD COLUMN IF NOT EXISTS id uuid;

UPDATE security.consent_policy
   SET id = gen_random_uuid()
 WHERE id IS NULL;

ALTER TABLE security.consent_policy
    ALTER COLUMN id SET NOT NULL;

ALTER TABLE security.consent_policy
    ALTER COLUMN id SET DEFAULT gen_random_uuid();

ALTER TABLE security.consent_policy
    ADD COLUMN IF NOT EXISTS name text;

ALTER TABLE security.consent_policy
    ADD COLUMN IF NOT EXISTS data_category text;

ALTER TABLE security.consent_policy
    ADD COLUMN IF NOT EXISTS consent_required boolean NOT NULL DEFAULT true;

ALTER TABLE security.consent_policy
    ADD COLUMN IF NOT EXISTS retention_days integer;

UPDATE security.consent_policy
   SET name = label
 WHERE name IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_security_consent_policy_id
    ON security.consent_policy(id);

COMMENT ON TABLE security.consent_policy IS
'Categories of data that require consent, and their rules.';


-- =============================================================================
-- 9. VERIFICATION
-- =============================================================================

SELECT
    '048_security_rbac' AS migration,
    COUNT(*)            AS permission_count
FROM security.permission;

SELECT
    '048_security_rbac' AS migration,
    COUNT(*)            AS role_count
FROM security.role;


COMMIT;