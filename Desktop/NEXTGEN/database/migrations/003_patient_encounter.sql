-- =============================================================================
-- AMEXAN PHASE 1 — MIGRATION 003
-- PATIENT + ENCOUNTER
-- VERSION 2
-- =============================================================================
--
-- PURPOSE
-- -------
-- Establish the AMEXAN longitudinal patient record and universal encounter
-- architecture.
--
-- CORE MODEL
--
-- PERSON
--   ↓
-- PATIENT
--   ↓
-- PATIENT REGISTRATION / IDENTIFIERS
--   ↓
-- ENCOUNTER
--   ↓
-- EPISODE / PARTICIPANTS / LOCATIONS / SERVICES / REASONS
--
-- IMPORTANT ARCHITECTURAL RULE
-- ----------------------------
-- The AMEXAN patient identity is longitudinal and must not be confused with
-- a facility's local Medical Record Number (MRN).
--
-- Therefore:
--
--   patient.patient.id
--       = AMEXAN longitudinal patient identity
--
--   patient.patient_identifier
--       = organization/facility-specific identifiers such as MRN
--
-- This permits:
--
--   Patient A
--       → Facility A MRN 001234
--       → Facility B MRN KTRH-92881
--       → External identifier XYZ
--
-- while retaining ONE longitudinal AMEXAN patient identity.
--
-- Encounter is the universal clinical contact:
--
-- OPD
-- ED
-- IPD
-- TELEMEDICINE
-- HOME VISIT
-- COMMUNITY
-- PROCEDURE
-- FOLLOW-UP
-- CONSULTATION
-- DAY CARE
-- ANC
-- PNC
-- etc.
--
-- Later clinical migrations must reference this foundation rather than
-- creating parallel patient/visit tables.
-- =============================================================================


CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS patient;
CREATE SCHEMA IF NOT EXISTS encounter;


COMMENT ON SCHEMA patient IS
'AMEXAN longitudinal patient identity, registration, demographics-linked preferences, consent and privacy.';

COMMENT ON SCHEMA encounter IS
'AMEXAN universal clinical encounter/contact architecture.';


-- =============================================================================
-- ============================================================================
-- PATIENT
-- ============================================================================


-- -----------------------------------------------------------------------------
-- PATIENT STATUS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_status (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT
);

COMMENT ON TABLE patient.patient_status IS
'Lifecycle state of an AMEXAN patient record.';


INSERT INTO patient.patient_status
    (code, label, description)
VALUES
    ('active', 'Active', 'Patient record is active.'),
    ('inactive', 'Inactive', 'Patient record is inactive but retained.'),
    ('deceased', 'Deceased', 'Patient is deceased.'),
    ('merged', 'Merged', 'Patient record has been merged into another patient.'),
    ('entered_in_error', 'Entered in Error', 'Patient record was created incorrectly.'),
    ('unknown', 'Unknown', 'Patient status is currently unknown.')
ON CONFLICT (code) DO NOTHING;


-- -----------------------------------------------------------------------------
-- PATIENT
-- -----------------------------------------------------------------------------
-- This is the longitudinal AMEXAN patient identity.
-- It intentionally does NOT contain a globally unique MRN.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE RESTRICT,

    status_code TEXT NOT NULL DEFAULT 'active'
        REFERENCES patient.patient_status(code),

    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    registered_by UUID
        REFERENCES identity.user_account(id),

    is_deceased BOOLEAN NOT NULL DEFAULT false,

    deceased_at TIMESTAMPTZ,

    deceased_recorded_by UUID
        REFERENCES identity.user_account(id),

    deceased_source TEXT,

    merged_into_patient_id UUID
        REFERENCES patient.patient(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        (
            is_deceased = false
            AND deceased_at IS NULL
        )
        OR
        (
            is_deceased = true
        )
    ),

    CHECK (
        merged_into_patient_id IS NULL
        OR merged_into_patient_id <> id
    )
);

COMMENT ON TABLE patient.patient IS
'Longitudinal AMEXAN patient identity linked to the canonical identity.person record.';

CREATE INDEX IF NOT EXISTS idx_patient_person
    ON patient.patient(person_id);

CREATE INDEX IF NOT EXISTS idx_patient_status
    ON patient.patient(status_code);

CREATE INDEX IF NOT EXISTS idx_patient_deceased
    ON patient.patient(is_deceased);

CREATE INDEX IF NOT EXISTS idx_patient_merged_into
    ON patient.patient(merged_into_patient_id);

CREATE TRIGGER trg_patient_updated_at
BEFORE UPDATE ON patient.patient
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- PATIENT REGISTRATION
-- -----------------------------------------------------------------------------
-- Represents a patient's relationship with an organization/facility.
--
-- This is where local registration context belongs.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_registration (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id)
        ON DELETE RESTRICT,

    facility_id UUID
        REFERENCES organization.facility(id)
        ON DELETE RESTRICT,

    registration_type TEXT NOT NULL DEFAULT 'general',

    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    registered_by UUID
        REFERENCES identity.user_account(id),

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'inactive',
                'transferred',
                'closed'
            )
        ),

    is_primary BOOLEAN NOT NULL DEFAULT false,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        organization_id IS NOT NULL
        OR facility_id IS NOT NULL
    )
);

COMMENT ON TABLE patient.patient_registration IS
'Organization/facility-specific registration of a longitudinal AMEXAN patient.';

CREATE INDEX IF NOT EXISTS idx_patient_registration_patient
    ON patient.patient_registration(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_registration_org
    ON patient.patient_registration(organization_id);

CREATE INDEX IF NOT EXISTS idx_patient_registration_facility
    ON patient.patient_registration(facility_id);

CREATE INDEX IF NOT EXISTS idx_patient_registration_status
    ON patient.patient_registration(status);

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_registration_primary
    ON patient.patient_registration(patient_id)
    WHERE is_primary = true
      AND status = 'active';

CREATE TRIGGER trg_patient_registration_updated_at
BEFORE UPDATE ON patient.patient_registration
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- PATIENT IDENTIFIERS
-- -----------------------------------------------------------------------------
-- MRNs and other identifiers belong here.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_identifier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id)
        ON DELETE RESTRICT,

    facility_id UUID
        REFERENCES organization.facility(id)
        ON DELETE RESTRICT,

    identifier_type TEXT NOT NULL,

    value TEXT NOT NULL,

    normalized_value TEXT NOT NULL,

    authority TEXT,

    assigning_jurisdiction TEXT,

    is_primary BOOLEAN NOT NULL DEFAULT false,

    verified BOOLEAN NOT NULL DEFAULT false,

    verified_at TIMESTAMPTZ,

    verified_by UUID
        REFERENCES identity.user_account(id),

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        organization_id IS NOT NULL
        OR facility_id IS NOT NULL
        OR authority IS NOT NULL
    )
);

COMMENT ON TABLE patient.patient_identifier IS
'Patient identifiers including facility-scoped MRNs, national identifiers and external identifiers.';

CREATE INDEX IF NOT EXISTS idx_patient_identifier_patient
    ON patient.patient_identifier(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_identifier_lookup
    ON patient.patient_identifier(identifier_type, normalized_value);

CREATE INDEX IF NOT EXISTS idx_patient_identifier_org
    ON patient.patient_identifier(organization_id);

CREATE INDEX IF NOT EXISTS idx_patient_identifier_facility
    ON patient.patient_identifier(facility_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_identifier_scoped
    ON patient.patient_identifier(
        identifier_type,
        normalized_value,
        COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
        COALESCE(facility_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );


-- -----------------------------------------------------------------------------
-- PATIENT MERGE / LINK HISTORY
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE RESTRICT,

    target_patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE RESTRICT,

    relationship_type TEXT NOT NULL
        CHECK (
            relationship_type IN (
                'duplicate',
                'merged',
                'linked',
                'possible_duplicate',
                'supersedes'
            )
        ),

    confidence NUMERIC(5,4),

    reason TEXT,

    detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    resolved_at TIMESTAMPTZ,

    resolved_by UUID
        REFERENCES identity.user_account(id),

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    CHECK (
        source_patient_id <> target_patient_id
    ),

    CHECK (
        confidence IS NULL
        OR confidence BETWEEN 0 AND 1
    )
);

COMMENT ON TABLE patient.patient_link IS
'Patient identity linkage, duplicate detection and merge history.';

CREATE INDEX IF NOT EXISTS idx_patient_link_source
    ON patient.patient_link(source_patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_link_target
    ON patient.patient_link(target_patient_id);


-- -----------------------------------------------------------------------------
-- PATIENT RELATIONSHIPS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_relationship (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    related_person_id UUID NOT NULL
        REFERENCES identity.person(id)
        ON DELETE RESTRICT,

    relationship_type TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'inactive',
                'ended',
                'unknown'
            )
        ),

    is_primary BOOLEAN NOT NULL DEFAULT false,

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ,

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        valid_to IS NULL
        OR valid_from IS NULL
        OR valid_to >= valid_from
    )
);

COMMENT ON TABLE patient.patient_relationship IS
'Guardian, parent, next-of-kin, caregiver and other relationships relevant to a patient.';

CREATE INDEX IF NOT EXISTS idx_patient_relationship_patient
    ON patient.patient_relationship(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_relationship_person
    ON patient.patient_relationship(related_person_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_relationship_primary
    ON patient.patient_relationship(patient_id, relationship_type)
    WHERE is_primary = true
      AND status = 'active';

CREATE TRIGGER trg_patient_relationship_updated_at
BEFORE UPDATE ON patient.patient_relationship
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- PATIENT PREFERENCE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_preference (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    preference_key TEXT NOT NULL,

    preference_value TEXT,

    source TEXT,

    effective_from TIMESTAMPTZ,

    effective_to TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (patient_id, preference_key)
);

COMMENT ON TABLE patient.patient_preference IS
'Patient communication and care preferences such as language, SMS preference and interpreter requirements.';

CREATE INDEX IF NOT EXISTS idx_patient_preference_patient
    ON patient.patient_preference(patient_id);

CREATE TRIGGER trg_patient_preference_updated_at
BEFORE UPDATE ON patient.patient_preference
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- PATIENT LANGUAGE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_language (
    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    language_code TEXT NOT NULL
        REFERENCES identity.language(code),

    proficiency TEXT,

    is_primary BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (patient_id, language_code)
);

COMMENT ON TABLE patient.patient_language IS
'Languages associated with a patient.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_primary_language
    ON patient.patient_language(patient_id)
    WHERE is_primary = true;


-- -----------------------------------------------------------------------------
-- PATIENT CONTACT
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_contact (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    contact_type TEXT NOT NULL,

    value TEXT NOT NULL,

    normalized_value TEXT,

    use_type TEXT DEFAULT 'home',

    is_primary BOOLEAN NOT NULL DEFAULT false,

    verified BOOLEAN NOT NULL DEFAULT false,

    verified_at TIMESTAMPTZ,

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE patient.patient_contact IS
'Patient-specific communication channels.';

CREATE INDEX IF NOT EXISTS idx_patient_contact_patient
    ON patient.patient_contact(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_contact_lookup
    ON patient.patient_contact(contact_type, normalized_value);

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_primary_contact
    ON patient.patient_contact(patient_id, contact_type)
    WHERE is_primary = true;

CREATE TRIGGER trg_patient_contact_updated_at
BEFORE UPDATE ON patient.patient_contact
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- PATIENT ADDRESS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_address (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    address_type TEXT NOT NULL DEFAULT 'home',

    line1 TEXT,

    line2 TEXT,

    city TEXT,

    district TEXT,

    county TEXT,

    province_state TEXT,

    postal_code TEXT,

    country TEXT,

    country_code TEXT,

    latitude NUMERIC(9,6),

    longitude NUMERIC(9,6),

    is_primary BOOLEAN NOT NULL DEFAULT false,

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ,

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

COMMENT ON TABLE patient.patient_address IS
'Patient addresses with temporal validity.';

CREATE INDEX IF NOT EXISTS idx_patient_address_patient
    ON patient.patient_address(patient_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_primary_address
    ON patient.patient_address(patient_id, address_type)
    WHERE is_primary = true;

CREATE TRIGGER trg_patient_address_updated_at
BEFORE UPDATE ON patient.patient_address
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- PATIENT EMERGENCY CONTACT
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_emergency_contact (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    related_person_id UUID
        REFERENCES identity.person(id)
        ON DELETE RESTRICT,

    name TEXT,

    relationship_type TEXT,

    phone TEXT,

    email TEXT,

    priority INTEGER NOT NULL DEFAULT 1,

    is_primary BOOLEAN NOT NULL DEFAULT false,

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ,

    notes TEXT
);

COMMENT ON TABLE patient.patient_emergency_contact IS
'Emergency contacts available to clinical and operational workflows.';

CREATE INDEX IF NOT EXISTS idx_emergency_contact_patient
    ON patient.patient_emergency_contact(patient_id);


-- -----------------------------------------------------------------------------
-- PATIENT CONSENT
-- -----------------------------------------------------------------------------
-- Consent is historical. Do not overwrite a previous decision.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS security.consent_policy (
    code TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO security.consent_policy (code, label, description)
VALUES
    ('default', 'Default consent policy', 'Standard institutional consent policy.'),
    ('research', 'Research consent policy', 'Consent governing use of data for research.'),
    ('sharing', 'Data sharing consent policy', 'Consent governing data sharing with third parties.'),
    ('restricted', 'Restricted access policy', 'Consent restricting access to minimum necessary data.')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS patient.patient_consent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    consent_policy_code TEXT
        REFERENCES security.consent_policy(code),

    consent_type TEXT NOT NULL,

    decision TEXT NOT NULL
        CHECK (
            decision IN (
                'granted',
                'denied',
                'withdrawn'
            )
        ),

    scope JSONB NOT NULL DEFAULT '{}'::jsonb,

    granted_at TIMESTAMPTZ,

    expires_at TIMESTAMPTZ,

    captured_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    captured_by UUID
        REFERENCES identity.user_account(id),

    method TEXT,

    source TEXT,

    version TEXT,

    evidence_reference TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        expires_at IS NULL
        OR granted_at IS NULL
        OR expires_at >= granted_at
    )
);

COMMENT ON TABLE patient.patient_consent IS
'Immutable-style historical record of patient consent decisions and their scope.';

CREATE INDEX IF NOT EXISTS idx_patient_consent_patient
    ON patient.patient_consent(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_consent_policy
    ON patient.patient_consent(consent_policy_code);

CREATE INDEX IF NOT EXISTS idx_patient_consent_active
    ON patient.patient_consent(patient_id, consent_type, captured_at DESC);


-- -----------------------------------------------------------------------------
-- PATIENT PRIVACY
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient.patient_privacy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    setting TEXT NOT NULL,

    is_restricted BOOLEAN NOT NULL DEFAULT true,

    reason TEXT,

    set_by UUID
        REFERENCES identity.user_account(id),

    set_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),

    effective_to TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_privacy_scoped
    ON patient.patient_privacy(
        patient_id,
        setting,
        COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
        COALESCE(facility_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );

COMMENT ON TABLE patient.patient_privacy IS
'Patient-specific privacy restrictions and sharing controls.';

CREATE INDEX IF NOT EXISTS idx_patient_privacy_patient
    ON patient.patient_privacy(patient_id);

CREATE INDEX IF NOT EXISTS idx_patient_privacy_org
    ON patient.patient_privacy(organization_id);


-- =============================================================================
-- ============================================================================
-- ENCOUNTER
-- ============================================================================


-- -----------------------------------------------------------------------------
-- ENCOUNTER TYPE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS encounter.encounter_type (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT
);

COMMENT ON TABLE encounter.encounter_type IS
'Universal AMEXAN clinical contact types.';

INSERT INTO encounter.encounter_type
    (code, label, description)
VALUES
    ('opd', 'Outpatient', 'Outpatient clinical encounter.'),
    ('ed', 'Emergency', 'Emergency department encounter.'),
    ('ipd', 'Inpatient', 'Inpatient encounter.'),
    ('telemedicine', 'Telemedicine', 'Remote clinical encounter.'),
    ('home_visit', 'Home Visit', 'Clinical encounter conducted at home.'),
    ('community', 'Community', 'Community-based clinical encounter.'),
    ('procedure', 'Procedure', 'Procedure-focused encounter.'),
    ('consultation', 'Consultation', 'Specialist or professional consultation.'),
    ('follow_up', 'Follow-up', 'Follow-up clinical encounter.'),
    ('day_care', 'Day Care', 'Day-care clinical encounter.'),
    ('anc', 'Antenatal Care', 'Antenatal clinical encounter.'),
    ('pnc', 'Postnatal Care', 'Postnatal clinical encounter.'),
    ('immunization', 'Immunization', 'Immunization encounter.'),
    ('screening', 'Screening', 'Screening encounter.'),
    ('occupational', 'Occupational', 'Occupational health encounter.'),
    ('public_health', 'Public Health', 'Public-health encounter.'),
    ('other', 'Other', 'Other clinical contact.')
ON CONFLICT (code) DO NOTHING;


-- -----------------------------------------------------------------------------
-- ENCOUNTER STATUS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS encounter.encounter_status (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT
);

INSERT INTO encounter.encounter_status
    (code, label, description)
VALUES
    ('planned', 'Planned', 'Encounter planned but not started.'),
    ('arrived', 'Arrived', 'Patient has arrived.'),
    ('triaged', 'Triaged', 'Initial triage completed.'),
    ('active', 'Active', 'Clinical encounter is active.'),
    ('on_hold', 'On Hold', 'Encounter temporarily paused.'),
    ('completed', 'Completed', 'Encounter completed.'),
    ('cancelled', 'Cancelled', 'Encounter cancelled.'),
    ('entered_in_error', 'Entered in Error', 'Encounter entered incorrectly.')
ON CONFLICT (code) DO NOTHING;


-- -----------------------------------------------------------------------------
-- ENCOUNTER PHASE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS encounter.encounter_phase (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT,

    sort_order INTEGER NOT NULL DEFAULT 0
);

INSERT INTO encounter.encounter_phase
    (code, label, description, sort_order)
VALUES
    ('registration', 'Registration', 'Patient registration.', 10),
    ('triage', 'Triage', 'Initial clinical prioritization.', 20),
    ('assessment', 'Assessment', 'Clinical assessment.', 30),
    ('diagnostic', 'Diagnostic', 'Diagnostic workup.', 40),
    ('treatment', 'Treatment', 'Treatment/care delivery.', 50),
    ('observation', 'Observation', 'Observation and monitoring.', 60),
    ('disposition', 'Disposition', 'Disposition decision.', 70),
    ('discharge', 'Discharge', 'Discharge process.', 80),
    ('follow_up', 'Follow-up', 'Follow-up planning.', 90)
ON CONFLICT (code) DO NOTHING;


-- -----------------------------------------------------------------------------
-- ENCOUNTER PRIORITY
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS encounter.encounter_priority (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0
);

INSERT INTO encounter.encounter_priority
    (code, label, sort_order)
VALUES
    ('routine', 'Routine', 10),
    ('urgent', 'Urgent', 20),
    ('emergency', 'Emergency', 30),
    ('stat', 'Stat', 40)
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- ENCOUNTER EPISODE
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_episode (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    episode_type TEXT,

    name TEXT,

    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    ended_at TIMESTAMPTZ,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'planned',
                'active',
                'completed',
                'cancelled'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        ended_at IS NULL
        OR ended_at >= started_at
    )
);

COMMENT ON TABLE encounter.encounter_episode IS
'Broader longitudinal clinical episode grouping related encounters.';

CREATE INDEX IF NOT EXISTS idx_episode_patient
    ON encounter.encounter_episode(patient_id);

CREATE INDEX IF NOT EXISTS idx_episode_facility
    ON encounter.encounter_episode(facility_id);

CREATE INDEX IF NOT EXISTS idx_episode_started
    ON encounter.encounter_episode(started_at);

CREATE TRIGGER trg_episode_updated_at
BEFORE UPDATE ON encounter.encounter_episode
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- ENCOUNTER
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID NOT NULL
        REFERENCES patient.patient(id)
        ON DELETE CASCADE,

    episode_id UUID
        REFERENCES encounter.encounter_episode(id)
        ON DELETE SET NULL,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    encounter_type_code TEXT NOT NULL
        REFERENCES encounter.encounter_type(code),

    status_code TEXT NOT NULL DEFAULT 'planned'
        REFERENCES encounter.encounter_status(code),

    phase_code TEXT
        REFERENCES encounter.encounter_phase(code),

    priority_code TEXT
        REFERENCES encounter.encounter_priority(code),

    department_id UUID
        REFERENCES organization.department(id),

    unit_id UUID
        REFERENCES organization.unit(id),

    clinic_id UUID
        REFERENCES organization.clinic(id),

    started_at TIMESTAMPTZ,

    ended_at TIMESTAMPTZ,

    duration_minutes INTEGER,

    service_mode TEXT,

    source_system TEXT,

    source_reference TEXT,

    referral_source TEXT,

    summary TEXT,

    created_by UUID
        REFERENCES identity.user_account(id),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        ended_at IS NULL
        OR started_at IS NULL
        OR ended_at >= started_at
    ),

    CHECK (
        duration_minutes IS NULL
        OR duration_minutes >= 0
    )
);

COMMENT ON TABLE encounter.encounter IS
'Universal AMEXAN encounter master record for every clinical contact.';

CREATE INDEX IF NOT EXISTS idx_encounter_patient
    ON encounter.encounter(patient_id);

CREATE INDEX IF NOT EXISTS idx_encounter_patient_started
    ON encounter.encounter(patient_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_encounter_status
    ON encounter.encounter(status_code);

CREATE INDEX IF NOT EXISTS idx_encounter_started
    ON encounter.encounter(started_at);

CREATE INDEX IF NOT EXISTS idx_encounter_facility
    ON encounter.encounter(facility_id);

CREATE INDEX IF NOT EXISTS idx_encounter_department
    ON encounter.encounter(department_id);

CREATE INDEX IF NOT EXISTS idx_encounter_episode
    ON encounter.encounter(episode_id);

CREATE INDEX IF NOT EXISTS idx_encounter_type
    ON encounter.encounter(encounter_type_code);

CREATE TRIGGER trg_encounter_updated_at
BEFORE UPDATE ON encounter.encounter
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- ENCOUNTER IDENTIFIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_identifier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    identifier_type TEXT NOT NULL,

    value TEXT NOT NULL,

    normalized_value TEXT NOT NULL,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    authority TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE encounter.encounter_identifier IS
'Local and external identifiers for encounters.';

CREATE INDEX IF NOT EXISTS idx_encounter_identifier_lookup
    ON encounter.encounter_identifier(identifier_type, normalized_value);

CREATE INDEX IF NOT EXISTS idx_encounter_identifier_encounter
    ON encounter.encounter_identifier(encounter_id);


-- =============================================================================
-- ENCOUNTER PHASE HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_phase_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    phase_code TEXT NOT NULL
        REFERENCES encounter.encounter_phase(code),

    entered_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    exited_at TIMESTAMPTZ,

    entered_by UUID
        REFERENCES identity.user_account(id),

    exited_by UUID
        REFERENCES identity.user_account(id),

    notes TEXT,

    CHECK (
        exited_at IS NULL
        OR exited_at >= entered_at
    )
);

COMMENT ON TABLE encounter.encounter_phase_history IS
'Historical clinical phase transitions for an encounter.';

CREATE INDEX IF NOT EXISTS idx_phase_history_encounter
    ON encounter.encounter_phase_history(encounter_id);

CREATE INDEX IF NOT EXISTS idx_phase_history_time
    ON encounter.encounter_phase_history(entered_at);


-- =============================================================================
-- ENCOUNTER PARTICIPANTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_participant (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    professional_id UUID
        REFERENCES organization.professional(id),

    person_id UUID
        REFERENCES identity.person(id),

    participant_role TEXT NOT NULL,

    participation_type TEXT,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ,

    is_primary BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (
        professional_id IS NOT NULL
        OR person_id IS NOT NULL
    ),

    CHECK (
        valid_to IS NULL
        OR valid_from IS NULL
        OR valid_to >= valid_from
    )
);

COMMENT ON TABLE encounter.encounter_participant IS
'Professionals and other people participating in an encounter.';

CREATE INDEX IF NOT EXISTS idx_encounter_participant_encounter
    ON encounter.encounter_participant(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_participant_professional
    ON encounter.encounter_participant(professional_id);

CREATE INDEX IF NOT EXISTS idx_encounter_participant_person
    ON encounter.encounter_participant(person_id);

CREATE INDEX IF NOT EXISTS idx_encounter_participant_role
    ON encounter.encounter_participant(participant_role);


-- =============================================================================
-- ENCOUNTER LOCATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_location (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    facility_id UUID
        REFERENCES organization.facility(id),

    department_id UUID
        REFERENCES organization.department(id),

    unit_id UUID
        REFERENCES organization.unit(id),

    clinic_id UUID
        REFERENCES organization.clinic(id),

    room_id UUID
        REFERENCES organization.room(id),

    bed_id UUID
        REFERENCES organization.bed(id),

    location_role TEXT NOT NULL DEFAULT 'treatment',

    from_time TIMESTAMPTZ,

    to_time TIMESTAMPTZ,

    is_current BOOLEAN NOT NULL DEFAULT false,

    CHECK (
        to_time IS NULL
        OR from_time IS NULL
        OR to_time >= from_time
    )
);

COMMENT ON TABLE encounter.encounter_location IS
'All physical locations occupied by or associated with an encounter over time.';

CREATE INDEX IF NOT EXISTS idx_encounter_location_encounter
    ON encounter.encounter_location(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_location_bed
    ON encounter.encounter_location(bed_id);

CREATE INDEX IF NOT EXISTS idx_encounter_location_current
    ON encounter.encounter_location(encounter_id)
    WHERE is_current = true;


-- =============================================================================
-- ENCOUNTER SERVICE
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_service (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    service_id UUID NOT NULL
        REFERENCES organization.service(id),

    is_primary BOOLEAN NOT NULL DEFAULT false,

    started_at TIMESTAMPTZ,

    ended_at TIMESTAMPTZ
);

COMMENT ON TABLE encounter.encounter_service IS
'Services requested or rendered during an encounter.';

CREATE INDEX IF NOT EXISTS idx_encounter_service_encounter
    ON encounter.encounter_service(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_service_service
    ON encounter.encounter_service(service_id);


-- =============================================================================
-- ENCOUNTER REASON
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_reason (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    reason_type TEXT NOT NULL DEFAULT 'chief_complaint',

    reason TEXT,

    concept_id UUID
        REFERENCES terminology.concept(id),

    is_primary BOOLEAN NOT NULL DEFAULT false,

    rank INTEGER NOT NULL DEFAULT 1,

    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    recorded_by UUID
        REFERENCES identity.user_account(id),

    CHECK (
        reason IS NOT NULL
        OR concept_id IS NOT NULL
    )
);

COMMENT ON TABLE encounter.encounter_reason IS
'Reason(s) for an encounter, supporting both free-text and AMEXAN terminology concepts.';

CREATE INDEX IF NOT EXISTS idx_encounter_reason_encounter
    ON encounter.encounter_reason(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_reason_concept
    ON encounter.encounter_reason(concept_id);


-- =============================================================================
-- ENCOUNTER REFERRAL
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_referral (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    direction TEXT NOT NULL
        CHECK (
            direction IN (
                'inbound',
                'outbound'
            )
        ),

    referral_type TEXT,

    referring_organization_id UUID
        REFERENCES organization.organization(id),

    referring_facility_id UUID
        REFERENCES organization.facility(id),

    receiving_organization_id UUID
        REFERENCES organization.organization(id),

    receiving_facility_id UUID
        REFERENCES organization.facility(id),

    referred_by UUID
        REFERENCES identity.user_account(id),

    referral_reason TEXT,

    referral_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            referral_status IN (
                'pending',
                'accepted',
                'declined',
                'completed',
                'cancelled'
            )
        ),

    referred_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    accepted_at TIMESTAMPTZ,

    completed_at TIMESTAMPTZ
);

COMMENT ON TABLE encounter.encounter_referral IS
'Inbound and outbound clinical referral context for an encounter.';

CREATE INDEX IF NOT EXISTS idx_encounter_referral_encounter
    ON encounter.encounter_referral(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_referral_status
    ON encounter.encounter_referral(referral_status);


-- =============================================================================
-- ENCOUNTER CARE TEAM
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_care_team (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    team_id UUID
        REFERENCES organization.team(id),

    team_role TEXT,

    is_primary BOOLEAN NOT NULL DEFAULT false,

    valid_from TIMESTAMPTZ,

    valid_to TIMESTAMPTZ
);

COMMENT ON TABLE encounter.encounter_care_team IS
'Care teams associated with an encounter.';


CREATE INDEX IF NOT EXISTS idx_encounter_care_team_encounter
    ON encounter.encounter_care_team(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_care_team_team
    ON encounter.encounter_care_team(team_id);


-- =============================================================================
-- ENCOUNTER PARENT / CHILD RELATIONSHIPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_parent (
    parent_encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    child_encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    relationship TEXT NOT NULL DEFAULT 'follow_up',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (
        parent_encounter_id,
        child_encounter_id,
        relationship
    ),

    CHECK (
        parent_encounter_id <> child_encounter_id
    )
);

COMMENT ON TABLE encounter.encounter_parent IS
'Relationships between encounters such as referral, admission, follow-up and continuation.';

CREATE INDEX IF NOT EXISTS idx_encounter_parent_child
    ON encounter.encounter_parent(child_encounter_id);


-- =============================================================================
-- ADMISSION / DISPOSITION FOUNDATION
-- =============================================================================
-- Detailed inpatient logic comes later. This preserves the universal
-- encounter's disposition without contaminating this migration with
-- full inpatient clinical logic.
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_disposition (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    disposition_code TEXT NOT NULL,

    destination_type TEXT,

    destination_facility_id UUID
        REFERENCES organization.facility(id),

    destination_unit_id UUID
        REFERENCES organization.unit(id),

    disposition_time TIMESTAMPTZ NOT NULL DEFAULT now(),

    recorded_by UUID
        REFERENCES identity.user_account(id),

    notes TEXT
);

COMMENT ON TABLE encounter.encounter_disposition IS
'Disposition resulting from an encounter. Detailed admission/discharge clinical data belongs to later migrations.';

CREATE INDEX IF NOT EXISTS idx_encounter_disposition_encounter
    ON encounter.encounter_disposition(encounter_id);


-- =============================================================================
-- ENCOUNTER AUDIT / PROVENANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS encounter.encounter_provenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id UUID NOT NULL
        REFERENCES encounter.encounter(id)
        ON DELETE CASCADE,

    source_system TEXT NOT NULL,

    source_type TEXT,

    source_reference TEXT,

    imported_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    imported_by UUID
        REFERENCES identity.user_account(id),

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE encounter.encounter_provenance IS
'Provenance of encounter records created, imported or synchronized from external systems.';

CREATE INDEX IF NOT EXISTS idx_encounter_provenance_encounter
    ON encounter.encounter_provenance(encounter_id);

CREATE INDEX IF NOT EXISTS idx_encounter_provenance_source
    ON encounter.encounter_provenance(source_system, source_reference);


-- =============================================================================
-- FINAL INTEGRITY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_patient_created
    ON patient.patient(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_patient_registration_patient_status
    ON patient.patient_registration(patient_id, status);

CREATE INDEX IF NOT EXISTS idx_encounter_patient_type
    ON encounter.encounter(patient_id, encounter_type_code);

CREATE INDEX IF NOT EXISTS idx_encounter_facility_started
    ON encounter.encounter(facility_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_encounter_active
    ON encounter.encounter(status_code, started_at DESC);


-- =============================================================================
-- END MIGRATION 003
-- =============================================================================