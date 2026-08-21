-- =============================================================================
-- AMEXAN — PHASE 1 / MIGRATION 001
-- IDENTITY FOUNDATION v2
-- =============================================================================
-- Purpose:
--   Universal identity layer for the entire AMEXAN ecosystem.
--
-- Constitutional rule:
--   PERSON != PATIENT != USER ACCOUNT != ACTOR != MEMBERSHIP
--
-- A person may:
--   - be a patient
--   - be a clinician
--   - be staff
--   - be a guardian
--   - be a researcher
--   - be an educator
--   - hold multiple organizational memberships
--   - have zero or multiple login accounts
--
-- Design goals:
--   - durable identifiers
--   - temporal data
--   - provenance
--   - auditability
--   - internationalization
--   - healthcare interoperability
--   - high-performance indexing
--   - future federation
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS identity;

COMMENT ON SCHEMA identity IS
'AMEXAN Universal Identity Layer. Persons, identifiers, accounts, contacts,
relationships, addresses and identity lifecycle.';

-- =============================================================================
-- COMMON UPDATED_AT TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- =============================================================================
-- ENUM-LIKE REFERENCE TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.language (
    code            text PRIMARY KEY,
    label           text NOT NULL,
    native_label    text,
    locale_code     text,
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS identity.person_status (
    code            text PRIMARY KEY,
    label           text NOT NULL,
    description     text,
    terminal        boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS identity.contact_type (
    code            text PRIMARY KEY,
    label           text NOT NULL,
    description     text
);

CREATE TABLE IF NOT EXISTS identity.address_type (
    code            text PRIMARY KEY,
    label           text NOT NULL,
    description     text
);

CREATE TABLE IF NOT EXISTS identity.relationship_type (
    code            text PRIMARY KEY,
    label           text NOT NULL,
    inverse_code    text,
    description     text
);

CREATE TABLE IF NOT EXISTS identity.identifier_type (
    code            text PRIMARY KEY,
    label           text NOT NULL,
    description     text,
    sensitive       boolean NOT NULL DEFAULT false,
    country_code    text,
    active          boolean NOT NULL DEFAULT true
);

-- =============================================================================
-- UNIVERSAL PERSON
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.person (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    status_code TEXT NOT NULL DEFAULT 'active'
        REFERENCES identity.person_status(code),

    -- Human-readable identity
    title TEXT,
    given_name TEXT,
    middle_name TEXT,
    family_name TEXT,
    family_name_prefix TEXT,
    preferred_name TEXT,
    suffix TEXT,

    -- Sex/gender are deliberately separated.
    sex_at_birth TEXT
        CHECK (
            sex_at_birth IS NULL OR
            sex_at_birth IN (
                'male',
                'female',
                'intersex',
                'unknown',
                'not_stated'
            )
        ),

    gender_identity TEXT,

    birth_date DATE,
    birth_date_estimated BOOLEAN NOT NULL DEFAULT false,

    death_date DATE,
    death_date_estimated BOOLEAN NOT NULL DEFAULT false,

    marital_status TEXT,

    blood_type TEXT
        CHECK (
            blood_type IS NULL OR
            blood_type IN (
                'A+','A-',
                'B+','B-',
                'AB+','AB-',
                'O+','O-',
                'unknown'
            )
        ),

    nationality_code TEXT,
    citizenship_code TEXT,

    occupation TEXT,

    preferred_language_code TEXT
        REFERENCES identity.language(code),

    notes TEXT,

    -- Temporal lifecycle
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (death_date IS NULL OR birth_date IS NULL OR death_date >= birth_date),
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

COMMENT ON TABLE identity.person IS
'Universal AMEXAN person. A person is neither a patient nor a login account.';

CREATE INDEX IF NOT EXISTS idx_person_status
    ON identity.person(status_code);

CREATE INDEX IF NOT EXISTS idx_person_birth_date
    ON identity.person(birth_date);

CREATE INDEX IF NOT EXISTS idx_person_family_name
    ON identity.person(lower(family_name));

CREATE INDEX IF NOT EXISTS idx_person_given_name
    ON identity.person(lower(given_name));

CREATE INDEX IF NOT EXISTS idx_person_preferred_name
    ON identity.person(lower(preferred_name));

CREATE INDEX IF NOT EXISTS idx_person_active
    ON identity.person(id)
    WHERE valid_to IS NULL;

DROP TRIGGER IF EXISTS trg_person_updated_at ON identity.person;

CREATE TRIGGER trg_person_updated_at
BEFORE UPDATE ON identity.person
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- PERSON NAMES
-- =============================================================================
-- Names can change over time.
-- Never destroy historical identity simply because a legal/preferred name changed.

CREATE TABLE IF NOT EXISTS identity.person_name (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    name_use TEXT NOT NULL
        CHECK (
            name_use IN (
                'official',
                'legal',
                'usual',
                'preferred',
                'maiden',
                'former',
                'alias'
            )
        ),

    title TEXT,
    given_name TEXT,
    middle_name TEXT,
    family_name TEXT,
    suffix TEXT,

    valid_from DATE,
    valid_to DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        valid_to IS NULL
        OR valid_from IS NULL
        OR valid_to >= valid_from
    )
);

CREATE INDEX IF NOT EXISTS idx_person_name_person
    ON identity.person_name(person_id);

CREATE INDEX IF NOT EXISTS idx_person_name_lookup
    ON identity.person_name(
        lower(family_name),
        lower(given_name)
    );

-- =============================================================================
-- OFFICIAL / EXTERNAL IDENTIFIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.person_identifier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    identifier_type TEXT NOT NULL
        REFERENCES identity.identifier_type(code),

    value TEXT NOT NULL,

    -- Normalized representation for lookup/deduplication.
    normalized_value TEXT NOT NULL,

    authority TEXT,
    country_code TEXT,

    issued_at DATE,
    expires_at DATE,

    verified BOOLEAN NOT NULL DEFAULT false,
    verified_at TIMESTAMPTZ,
    verified_by UUID,

    active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        identifier_type,
        normalized_value,
        authority
    )
);

CREATE INDEX IF NOT EXISTS idx_person_identifier_person
    ON identity.person_identifier(person_id);

CREATE INDEX IF NOT EXISTS idx_person_identifier_lookup
    ON identity.person_identifier(identifier_type, normalized_value);

CREATE INDEX IF NOT EXISTS idx_person_identifier_value
    ON identity.person_identifier(value);

DROP TRIGGER IF EXISTS trg_person_identifier_updated_at
ON identity.person_identifier;

CREATE TRIGGER trg_person_identifier_updated_at
BEFORE UPDATE ON identity.person_identifier
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- CONTACT POINTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.contact_point (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    contact_type TEXT NOT NULL
        REFERENCES identity.contact_type(code),

    value TEXT NOT NULL,
    normalized_value TEXT,

    is_primary BOOLEAN NOT NULL DEFAULT false,
    verified BOOLEAN NOT NULL DEFAULT false,
    verified_at TIMESTAMPTZ,

    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contact_person
    ON identity.contact_point(person_id);

CREATE INDEX IF NOT EXISTS idx_contact_lookup
    ON identity.contact_point(contact_type, normalized_value);

CREATE UNIQUE INDEX IF NOT EXISTS uq_primary_contact
    ON identity.contact_point(person_id, contact_type)
    WHERE is_primary = true AND valid_to IS NULL;

DROP TRIGGER IF EXISTS trg_contact_point_updated_at
ON identity.contact_point;

CREATE TRIGGER trg_contact_point_updated_at
BEFORE UPDATE ON identity.contact_point
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- ADDRESSES
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.address (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    address_type TEXT NOT NULL
        REFERENCES identity.address_type(code),

    line1 TEXT,
    line2 TEXT,
    line3 TEXT,

    city TEXT,
    district TEXT,
    county TEXT,
    province_state TEXT,
    postal_code TEXT,
    country_code TEXT,

    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),

    is_primary BOOLEAN NOT NULL DEFAULT false,

    valid_from DATE,
    valid_to DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        latitude IS NULL
        OR latitude BETWEEN -90 AND 90
    ),

    CHECK (
        longitude IS NULL
        OR longitude BETWEEN -180 AND 180
    )
);

CREATE INDEX IF NOT EXISTS idx_address_person
    ON identity.address(person_id);

CREATE INDEX IF NOT EXISTS idx_address_country
    ON identity.address(country_code);

CREATE UNIQUE INDEX IF NOT EXISTS uq_primary_address
    ON identity.address(person_id, address_type)
    WHERE is_primary = true AND valid_to IS NULL;

DROP TRIGGER IF EXISTS trg_address_updated_at
ON identity.address;

CREATE TRIGGER trg_address_updated_at
BEFORE UPDATE ON identity.address
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- PERSON RELATIONSHIPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.person_relationship (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    related_person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    relationship_type TEXT NOT NULL
        REFERENCES identity.relationship_type(code),

    status TEXT NOT NULL DEFAULT 'active',

    valid_from DATE,
    valid_to DATE,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (person_id <> related_person_id),

    CHECK (
        valid_to IS NULL
        OR valid_from IS NULL
        OR valid_to >= valid_from
    )
);

CREATE INDEX IF NOT EXISTS idx_relationship_person
    ON identity.person_relationship(person_id);

CREATE INDEX IF NOT EXISTS idx_relationship_related
    ON identity.person_relationship(related_person_id);

CREATE INDEX IF NOT EXISTS idx_relationship_type
    ON identity.person_relationship(relationship_type);

DROP TRIGGER IF EXISTS trg_person_relationship_updated_at
ON identity.person_relationship;

CREATE TRIGGER trg_person_relationship_updated_at
BEFORE UPDATE ON identity.person_relationship
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- EMERGENCY CONTACT
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.emergency_contact (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    contact_person_id UUID
        REFERENCES identity.person(id),

    name TEXT NOT NULL,
    relationship_type TEXT,
    phone TEXT,
    email TEXT,

    priority SMALLINT NOT NULL DEFAULT 1,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emergency_contact_person
    ON identity.emergency_contact(person_id);

CREATE INDEX IF NOT EXISTS idx_emergency_contact_priority
    ON identity.emergency_contact(person_id, priority);

DROP TRIGGER IF EXISTS trg_emergency_contact_updated_at
ON identity.emergency_contact;

CREATE TRIGGER trg_emergency_contact_updated_at
BEFORE UPDATE ON identity.emergency_contact
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- COMMUNICATION PREFERENCES
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.communication_preference (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE CASCADE,

    language_code TEXT
        REFERENCES identity.language(code),

    channel TEXT NOT NULL,

    is_primary BOOLEAN NOT NULL DEFAULT false,

    quiet_hours_start TIME,
    quiet_hours_end TIME,

    consent_status TEXT NOT NULL DEFAULT 'allowed',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comm_preference_person
    ON identity.communication_preference(person_id);

DROP TRIGGER IF EXISTS trg_communication_preference_updated_at
ON identity.communication_preference;

CREATE TRIGGER trg_communication_preference_updated_at
BEFORE UPDATE ON identity.communication_preference
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- LOGIN ACCOUNTS
-- =============================================================================
-- Authentication identity is deliberately separate from person identity.

CREATE TABLE IF NOT EXISTS identity.user_account (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id),

    username TEXT,
    email TEXT,
    phone TEXT,

    account_status TEXT NOT NULL DEFAULT 'pending_verification'
        CHECK (
            account_status IN (
                'active',
                'locked',
                'disabled',
                'pending_verification',
                'suspended'
            )
        ),

    email_verified BOOLEAN NOT NULL DEFAULT false,
    phone_verified BOOLEAN NOT NULL DEFAULT false,

    must_change_password BOOLEAN NOT NULL DEFAULT false,

    mfa_required BOOLEAN NOT NULL DEFAULT false,

    last_login_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_username
    ON identity.user_account(lower(username))
    WHERE username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_email
    ON identity.user_account(lower(email))
    WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_account_person
    ON identity.user_account(person_id);

CREATE INDEX IF NOT EXISTS idx_user_account_status
    ON identity.user_account(account_status);

DROP TRIGGER IF EXISTS trg_user_account_updated_at
ON identity.user_account;

CREATE TRIGGER trg_user_account_updated_at
BEFORE UPDATE ON identity.user_account
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- AUTHENTICATION CREDENTIALS
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.user_credential (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_account_id UUID NOT NULL
        REFERENCES identity.user_account(id)
        ON DELETE CASCADE,

    credential_type TEXT NOT NULL,

    secret_hash TEXT,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_credential_account
    ON identity.user_credential(user_account_id);

CREATE INDEX IF NOT EXISTS idx_user_credential_active
    ON identity.user_credential(user_account_id)
    WHERE revoked_at IS NULL;

-- =============================================================================
-- USER SESSIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS identity.user_session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_account_id UUID NOT NULL
        REFERENCES identity.user_account(id)
        ON DELETE CASCADE,

    token_hash TEXT NOT NULL UNIQUE,

    ip_address INET,
    user_agent TEXT,
    device TEXT,

    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    ended_at TIMESTAMPTZ,

    revoked BOOLEAN NOT NULL DEFAULT false,

    CHECK (expires_at > started_at)
);

CREATE INDEX IF NOT EXISTS idx_session_account
    ON identity.user_session(user_account_id);

CREATE INDEX IF NOT EXISTS idx_session_expiry
    ON identity.user_session(expires_at);

CREATE INDEX IF NOT EXISTS idx_session_active
    ON identity.user_session(user_account_id, expires_at)
    WHERE revoked = false;

-- =============================================================================
-- IDENTITY AUDIT EVENTS
-- =============================================================================
-- Identity changes are security-sensitive and must be reconstructable.

CREATE TABLE IF NOT EXISTS identity.audit_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID
        REFERENCES identity.person(id),

    user_account_id UUID
        REFERENCES identity.user_account(id),

    event_type TEXT NOT NULL,

    entity_type TEXT NOT NULL,
    entity_id UUID,

    actor_user_account_id UUID
        REFERENCES identity.user_account(id),

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    ip_address INET,
    user_agent TEXT,

    old_values JSONB,
    new_values JSONB,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_identity_audit_person
    ON identity.audit_event(person_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_identity_audit_account
    ON identity.audit_event(user_account_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_identity_audit_entity
    ON identity.audit_event(entity_type, entity_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_identity_audit_event_type
    ON identity.audit_event(event_type, occurred_at DESC);

-- =============================================================================
-- SEED — CORE LANGUAGE DATA
-- =============================================================================

INSERT INTO identity.language
    (code, label, native_label, locale_code)
VALUES
    ('en', 'English', 'English', 'en'),
    ('sw', 'Swahili', 'Kiswahili', 'sw'),
    ('fr', 'French', 'Français', 'fr'),
    ('ar', 'Arabic', 'العربية', 'ar'),
    ('es', 'Spanish', 'Español', 'es'),
    ('pt', 'Portuguese', 'Português', 'pt'),
    ('de', 'German', 'Deutsch', 'de'),
    ('zh', 'Chinese', '中文', 'zh'),
    ('hi', 'Hindi', 'हिन्दी', 'hi')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- SEED — PERSON STATUS
-- =============================================================================

INSERT INTO identity.person_status
    (code, label, description, terminal)
VALUES
    ('active', 'Active', 'Person is currently active in the identity system.', false),
    ('inactive', 'Inactive', 'Person is no longer actively participating.', false),
    ('deceased', 'Deceased', 'Person is deceased.', true),
    ('unknown', 'Unknown', 'Identity status has not been established.', false),
    ('merged', 'Merged', 'Identity was merged into another canonical person.', true),
    ('entered_in_error', 'Entered in Error', 'Identity record was created incorrectly.', true)
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- SEED — CONTACT TYPES
-- =============================================================================

INSERT INTO identity.contact_type
    (code, label, description)
VALUES
    ('phone', 'Telephone', 'Telephone number.'),
    ('mobile', 'Mobile', 'Mobile telephone number.'),
    ('email', 'Email', 'Electronic mail address.'),
    ('fax', 'Fax', 'Fax number.'),
    ('pager', 'Pager', 'Pager contact.')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- SEED — ADDRESS TYPES
-- =============================================================================

INSERT INTO identity.address_type
    (code, label, description)
VALUES
    ('home', 'Home', 'Residential address.'),
    ('work', 'Work', 'Workplace address.'),
    ('postal', 'Postal', 'Postal/mailing address.'),
    ('temporary', 'Temporary', 'Temporary residence.'),
    ('previous', 'Previous', 'Historical address.')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- SEED — RELATIONSHIPS
-- =============================================================================

INSERT INTO identity.relationship_type
    (code, label, inverse_code, description)
VALUES
    ('parent', 'Parent', 'child', 'Parent of the related person.'),
    ('child', 'Child', 'parent', 'Child of the related person.'),
    ('guardian', 'Guardian', 'ward', 'Legal/care guardian.'),
    ('ward', 'Ward', 'guardian', 'Person under guardianship.'),
    ('spouse', 'Spouse', 'spouse', 'Spousal relationship.'),
    ('partner', 'Partner', 'partner', 'Partner relationship.'),
    ('sibling', 'Sibling', 'sibling', 'Sibling relationship.'),
    ('grandparent', 'Grandparent', 'grandchild', 'Grandparent relationship.'),
    ('grandchild', 'Grandchild', 'grandparent', 'Grandchild relationship.'),
    ('caregiver', 'Caregiver', 'care_recipient', 'Caregiver relationship.'),
    ('care_recipient', 'Care Recipient', 'caregiver', 'Person receiving care.'),
    ('emergency_contact', 'Emergency Contact', NULL, 'Designated emergency contact.')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- SEED — GLOBAL IDENTIFIER TYPES
-- =============================================================================

INSERT INTO identity.identifier_type
    (code, label, description, sensitive)
VALUES
    ('national_id', 'National Identification Number',
        'Government-issued national identity number.', true),

    ('passport', 'Passport Number',
        'Passport identifier.', true),

    ('driving_license', 'Driving Licence',
        'Driving licence identifier.', true),

    ('birth_certificate', 'Birth Certificate',
        'Birth registration/certificate identifier.', true),

    ('tax_id', 'Tax Identification Number',
        'Tax authority identifier.', true),

    ('social_security', 'Social Security Number',
        'Social security identifier.', true),

    ('health_insurance', 'Health Insurance Identifier',
        'Health insurance membership identifier.', true),

    ('employee_id', 'Employee Identifier',
        'Employer-issued employee identifier.', false),

    ('professional_license', 'Professional Licence',
        'Professional regulatory licence identifier.', true),

    ('external_id', 'External Identifier',
        'Identifier assigned by an external system.', false)
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- COMMENTS — ARCHITECTURAL CONTRACT
-- =============================================================================

COMMENT ON TABLE identity.user_account IS
'Authentication account only. Authorization, organizational membership and
clinical roles belong to higher AMEXAN layers.';

COMMENT ON TABLE identity.user_credential IS
'Credential metadata only. Plaintext passwords, tokens and secrets are forbidden.';

COMMENT ON TABLE identity.audit_event IS
'Immutable security and identity audit trail. Application code must append events
rather than rewriting historical audit records.';

-- =============================================================================
-- END MIGRATION
-- =============================================================================