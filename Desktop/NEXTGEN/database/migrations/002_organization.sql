-- =============================================================================
-- AMEXAN
-- PHASE 1 — MIGRATION 002
-- ORGANIZATION + SECURITY + TERMINOLOGY
-- VERSION 2
-- =============================================================================
--
-- AMEXAN CONSTITUTIONAL LAYER
--
-- PERSON
--   ↓
-- USER ACCOUNT
--   ↓
-- ORGANIZATION MEMBERSHIP / PROFESSIONAL IDENTITY
--   ↓
-- ROLE
--   ↓
-- PERMISSION
--   ↓
-- RESOURCE / ACTION
--
-- ORGANIZATION
--   ↓
-- FACILITY
--   ↓
-- CAMPUS
--   ↓
-- BUILDING
--   ↓
-- FLOOR
--   ↓
-- ROOM
--   ↓
-- BED
--
-- TERMINOLOGY
--   CODE SYSTEM
--      ↓
--   CODE
--      ↓
--   UNIVERSAL CONCEPT
--      ↓
--   RELATIONSHIPS / MAPPINGS / VALUE SETS
--
-- SECURITY
--   HUMAN USER + SERVICE CLIENT
--      ↓
--   AUTHENTICATION
--      ↓
--   SCOPED AUTHORIZATION
--      ↓
--   POLICY
--      ↓
--   AUDIT
--
-- Design goals:
--   - multi-organization
--   - multi-facility
--   - multi-country
--   - temporal
--   - interoperable
--   - terminology-neutral
--   - API-first
--   - high-performance
--   - auditable
--   - future CPU / engine compatible
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS organization;
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS terminology;

COMMENT ON SCHEMA organization IS
'AMEXAN organizational, facility, physical-space, service and workforce foundation.';

COMMENT ON SCHEMA security IS
'AMEXAN authentication-adjacent authorization, roles, permissions, policies,
API clients, scopes and security controls.';

COMMENT ON SCHEMA terminology IS
'AMEXAN universal clinical and operational terminology, code systems,
concepts, mappings, value sets and units.';

-- =============================================================================
-- ============================================================================
-- TERMINOLOGY
-- ============================================================================
-- Terminology is deliberately independent of clinical schemas.
--
-- Clinical modules should reference terminology.concept.id rather than
-- hard-coding SNOMED/ICD/LOINC/local codes into clinical tables.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CODE SYSTEM
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.code_system (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name TEXT NOT NULL UNIQUE,

    canonical_uri TEXT,
    oid TEXT,

    publisher TEXT,
    description TEXT,

    version TEXT,

    release_date DATE,

    country_code TEXT,

    is_external BOOLEAN NOT NULL DEFAULT true,
    is_local BOOLEAN NOT NULL DEFAULT false,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_code_system_active
    ON terminology.code_system(is_active);

DROP TRIGGER IF EXISTS trg_code_system_updated_at
ON terminology.code_system;

CREATE TRIGGER trg_code_system_updated_at
BEFORE UPDATE ON terminology.code_system
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE terminology.code_system IS
'Terminology/code source such as SNOMED CT, ICD-10, ICD-11, LOINC,
RxNorm, UCUM, local AMEXAN terminology or national terminology.';

-- -----------------------------------------------------------------------------
-- CODE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.code (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code_system_id UUID NOT NULL
        REFERENCES terminology.code_system(id)
        ON DELETE RESTRICT,

    code TEXT NOT NULL,

    display TEXT NOT NULL,

    definition TEXT,

    designation JSONB NOT NULL DEFAULT '[]'::jsonb,

    version TEXT,

    effective_from DATE,
    effective_to DATE,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_code_system_code_version
    ON terminology.code(code_system_id, code, COALESCE(version, ''));

CREATE INDEX IF NOT EXISTS idx_code_system_code
    ON terminology.code(code_system_id, code);

CREATE INDEX IF NOT EXISTS idx_code_display
    ON terminology.code(lower(display));

CREATE INDEX IF NOT EXISTS idx_code_active
    ON terminology.code(code_system_id, is_active);

DROP TRIGGER IF EXISTS trg_code_updated_at
ON terminology.code;

CREATE TRIGGER trg_code_updated_at
BEFORE UPDATE ON terminology.code
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE terminology.code IS
'An individual code issued by a terminology/code system.';

-- -----------------------------------------------------------------------------
-- UNIVERSAL CONCEPT
-- -----------------------------------------------------------------------------
-- This is AMEXAN's semantic layer.
--
-- A concept is NOT synonymous with a code.
--
-- Example:
--   AMEXAN concept: Pneumonia
--
-- may have relationships to:
--   SNOMED CT
--   ICD-10
--   ICD-11
--   local Kenyan code
--   local AMEXAN code
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.concept (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_id UUID
        REFERENCES terminology.concept(id)
        ON DELETE RESTRICT,

    concept_key TEXT UNIQUE,

    display_name TEXT NOT NULL,

    definition TEXT,

    semantic_type TEXT,

    concept_status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            concept_status IN (
                'active',
                'inactive',
                'retired',
                'deprecated',
                'draft'
            )
        ),

    version INTEGER NOT NULL DEFAULT 1,

    effective_from DATE,
    effective_to DATE,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_concept_parent
    ON terminology.concept(parent_id);

CREATE INDEX IF NOT EXISTS idx_concept_name
    ON terminology.concept(lower(display_name));

CREATE INDEX IF NOT EXISTS idx_concept_status
    ON terminology.concept(concept_status);

CREATE INDEX IF NOT EXISTS idx_concept_semantic_type
    ON terminology.concept(semantic_type);

DROP TRIGGER IF EXISTS trg_concept_updated_at
ON terminology.concept;

CREATE TRIGGER trg_concept_updated_at
BEFORE UPDATE ON terminology.concept
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE terminology.concept IS
'AMEXAN universal semantic concept. Multiple external codes may represent,
refine or map to one concept.';

-- -----------------------------------------------------------------------------
-- CONCEPT CODE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.concept_code (
    concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    code_id UUID NOT NULL
        REFERENCES terminology.code(id)
        ON DELETE CASCADE,

    relationship TEXT NOT NULL DEFAULT 'equivalent'
        CHECK (
            relationship IN (
                'equivalent',
                'broader',
                'narrower',
                'related',
                'approximate',
                'contextual'
            )
        ),

    is_preferred BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (concept_id, code_id)
);

CREATE INDEX IF NOT EXISTS idx_concept_code_code
    ON terminology.concept_code(code_id);

CREATE INDEX IF NOT EXISTS idx_concept_code_preferred
    ON terminology.concept_code(concept_id)
    WHERE is_preferred = true;

-- -----------------------------------------------------------------------------
-- SYNONYMS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.concept_synonym (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    synonym TEXT NOT NULL,

    normalized_synonym TEXT,

    language_code TEXT,

    synonym_type TEXT NOT NULL DEFAULT 'clinical'
        CHECK (
            synonym_type IN (
                'preferred',
                'clinical',
                'lay',
                'abbreviation',
                'acronym',
                'historical',
                'local'
            )
        ),

    is_preferred BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_synonym_lookup
    ON terminology.concept_synonym(lower(synonym));

CREATE INDEX IF NOT EXISTS idx_synonym_concept
    ON terminology.concept_synonym(concept_id);

-- -----------------------------------------------------------------------------
-- TRANSLATIONS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.concept_translation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    language_code TEXT NOT NULL,

    translation TEXT NOT NULL,

    is_preferred BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (concept_id, language_code, translation)
);

CREATE INDEX IF NOT EXISTS idx_translation_language
    ON terminology.concept_translation(language_code);

-- -----------------------------------------------------------------------------
-- CONCEPT RELATIONSHIPS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.concept_relationship (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    target_concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    relationship_type TEXT NOT NULL,

    relationship_group INTEGER,

    is_transitive BOOLEAN NOT NULL DEFAULT false,

    is_symmetric BOOLEAN NOT NULL DEFAULT false,

    effective_from DATE,
    effective_to DATE,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (source_concept_id <> target_concept_id)
);

CREATE INDEX IF NOT EXISTS idx_concept_rel_source
    ON terminology.concept_relationship(source_concept_id);

CREATE INDEX IF NOT EXISTS idx_concept_rel_target
    ON terminology.concept_relationship(target_concept_id);

CREATE INDEX IF NOT EXISTS idx_concept_rel_type
    ON terminology.concept_relationship(relationship_type);

-- -----------------------------------------------------------------------------
-- CROSS-TERMINOLOGY MAPPINGS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    target_concept_id UUID NOT NULL
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    mapping_relationship TEXT NOT NULL
        CHECK (
            mapping_relationship IN (
                'equivalent',
                'source_broader',
                'source_narrower',
                'target_broader',
                'target_narrower',
                'related',
                'inexact',
                'unmapped'
            )
        ),

    authority TEXT,

    confidence NUMERIC(5,4)
        CHECK (confidence >= 0 AND confidence <= 1),

    mapping_method TEXT,

    effective_from DATE,
    effective_to DATE,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (source_concept_id <> target_concept_id)
);

CREATE INDEX IF NOT EXISTS idx_mapping_source
    ON terminology.mapping(source_concept_id);

CREATE INDEX IF NOT EXISTS idx_mapping_target
    ON terminology.mapping(target_concept_id);

-- -----------------------------------------------------------------------------
-- VALUE SETS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.value_set (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key TEXT NOT NULL UNIQUE,

    name TEXT NOT NULL,

    description TEXT,

    oid TEXT,

    version TEXT,

    publisher TEXT,

    effective_from DATE,
    effective_to DATE,

    is_expandable BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_value_set_active
    ON terminology.value_set(is_active);

DROP TRIGGER IF EXISTS trg_value_set_updated_at
ON terminology.value_set;

CREATE TRIGGER trg_value_set_updated_at
BEFORE UPDATE ON terminology.value_set
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS terminology.value_set_member (
    value_set_id UUID NOT NULL
        REFERENCES terminology.value_set(id)
        ON DELETE CASCADE,

    concept_id UUID
        REFERENCES terminology.concept(id)
        ON DELETE CASCADE,

    code_id UUID
        REFERENCES terminology.code(id)
        ON DELETE CASCADE,

    is_active BOOLEAN NOT NULL DEFAULT true,

    sort_order INTEGER NOT NULL DEFAULT 0,

    PRIMARY KEY (value_set_id, concept_id, code_id),

    CHECK (
        concept_id IS NOT NULL
        OR code_id IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_value_set_member_concept
    ON terminology.value_set_member(concept_id);

CREATE INDEX IF NOT EXISTS idx_value_set_member_code
    ON terminology.value_set_member(code_id);

-- -----------------------------------------------------------------------------
-- UNITS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS terminology.unit (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    symbol TEXT,

    dimension TEXT,

    ucum_code TEXT,

    si_unit_code TEXT
        REFERENCES terminology.unit(code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_unit_dimension
    ON terminology.unit(dimension);

CREATE TABLE IF NOT EXISTS terminology.unit_conversion (
    from_unit_code TEXT NOT NULL
        REFERENCES terminology.unit(code),

    to_unit_code TEXT NOT NULL
        REFERENCES terminology.unit(code),

    factor NUMERIC NOT NULL,

    offset_value NUMERIC NOT NULL DEFAULT 0,

    PRIMARY KEY (from_unit_code, to_unit_code),

    CHECK (from_unit_code <> to_unit_code)
);

-- =============================================================================
-- ============================================================================
-- ORGANIZATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS organization.organization (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_id UUID
        REFERENCES organization.organization(id),

    organization_key TEXT UNIQUE,

    name TEXT NOT NULL,

    legal_name TEXT,

    organization_type TEXT NOT NULL,

    description TEXT,

    country_code TEXT,

    registration_number TEXT,

    tax_identifier TEXT,

    timezone TEXT NOT NULL DEFAULT 'Africa/Nairobi',

    default_language_code TEXT,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'inactive',
                'suspended',
                'closed',
                'pending'
            )
        ),

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_org_parent
    ON organization.organization(parent_id);

CREATE INDEX IF NOT EXISTS idx_org_status
    ON organization.organization(status);

CREATE INDEX IF NOT EXISTS idx_org_country
    ON organization.organization(country_code);

DROP TRIGGER IF EXISTS trg_organization_updated_at
ON organization.organization;

CREATE TRIGGER trg_organization_updated_at
BEFORE UPDATE ON organization.organization
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- ORGANIZATION IDENTIFIERS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS organization.organization_identifier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL
        REFERENCES organization.organization(id)
        ON DELETE CASCADE,

    identifier_type TEXT NOT NULL,

    value TEXT NOT NULL,

    normalized_value TEXT NOT NULL,

    authority TEXT,

    issued_at DATE,
    expires_at DATE,

    verified BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        identifier_type,
        normalized_value,
        authority
    )
);

CREATE INDEX IF NOT EXISTS idx_org_identifier_org
    ON organization.organization_identifier(organization_id);

-- -----------------------------------------------------------------------------
-- FACILITY
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS organization.facility (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL
        REFERENCES organization.organization(id),

    facility_key TEXT,

    name TEXT NOT NULL,

    legal_name TEXT,

    facility_type TEXT NOT NULL,

    ownership_type TEXT,

    status TEXT NOT NULL DEFAULT 'active',

    country_code TEXT,

    county TEXT,

    district TEXT,

    city TEXT,

    timezone TEXT NOT NULL DEFAULT 'Africa/Nairobi',

    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),

    phone TEXT,
    email TEXT,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

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

CREATE UNIQUE INDEX IF NOT EXISTS uq_facility_org_key
    ON organization.facility(organization_id, facility_key)
    WHERE facility_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_facility_org
    ON organization.facility(organization_id);

CREATE INDEX IF NOT EXISTS idx_facility_status
    ON organization.facility(status);

DROP TRIGGER IF EXISTS trg_facility_updated_at
ON organization.facility;

CREATE TRIGGER trg_facility_updated_at
BEFORE UPDATE ON organization.facility
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- FACILITY IDENTIFIERS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS organization.facility_identifier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    identifier_type TEXT NOT NULL,

    value TEXT NOT NULL,

    normalized_value TEXT NOT NULL,

    authority TEXT,

    issued_at DATE,
    expires_at DATE,

    verified BOOLEAN NOT NULL DEFAULT false,

    UNIQUE (
        identifier_type,
        normalized_value,
        authority
    )
);

CREATE INDEX IF NOT EXISTS idx_facility_identifier_facility
    ON organization.facility_identifier(facility_id);

-- =============================================================================
-- PHYSICAL FACILITY HIERARCHY
-- =============================================================================

CREATE TABLE IF NOT EXISTS organization.campus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    code TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (facility_id, name)
);

CREATE INDEX IF NOT EXISTS idx_campus_facility
    ON organization.campus(facility_id);

CREATE TABLE IF NOT EXISTS organization.building (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    campus_id UUID
        REFERENCES organization.campus(id)
        ON DELETE CASCADE,

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    code TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (facility_id, name)
);

CREATE INDEX IF NOT EXISTS idx_building_facility
    ON organization.building(facility_id);

CREATE TABLE IF NOT EXISTS organization.floor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    building_id UUID NOT NULL
        REFERENCES organization.building(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    level INTEGER,

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (building_id, name)
);

CREATE TABLE IF NOT EXISTS organization.room (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    floor_id UUID
        REFERENCES organization.floor(id)
        ON DELETE CASCADE,

    building_id UUID
        REFERENCES organization.building(id)
        ON DELETE CASCADE,

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    code TEXT,

    room_type TEXT,

    status TEXT NOT NULL DEFAULT 'active',

    capacity INTEGER,

    is_active BOOLEAN NOT NULL DEFAULT true,

    CHECK (capacity IS NULL OR capacity >= 0)
);

CREATE INDEX IF NOT EXISTS idx_room_facility
    ON organization.room(facility_id);

CREATE INDEX IF NOT EXISTS idx_room_type
    ON organization.room(room_type);

CREATE TABLE IF NOT EXISTS organization.bed (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    room_id UUID NOT NULL
        REFERENCES organization.room(id)
        ON DELETE CASCADE,

    name TEXT NOT NULL,

    code TEXT,

    bed_type TEXT,

    status TEXT NOT NULL DEFAULT 'available'
        CHECK (
            status IN (
                'available',
                'occupied',
                'reserved',
                'blocked',
                'maintenance',
                'cleaning',
                'out_of_service'
            )
        ),

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (room_id, name)
);

CREATE INDEX IF NOT EXISTS idx_bed_room
    ON organization.bed(room_id);

CREATE INDEX IF NOT EXISTS idx_bed_status
    ON organization.bed(status);

-- =============================================================================
-- CARE ORGANIZATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS organization.department (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    parent_id UUID
        REFERENCES organization.department(id),

    code TEXT,

    name TEXT NOT NULL,

    department_type TEXT,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (facility_id, code)
);

CREATE INDEX IF NOT EXISTS idx_department_facility
    ON organization.department(facility_id);

CREATE INDEX IF NOT EXISTS idx_department_parent
    ON organization.department(parent_id);

CREATE TABLE IF NOT EXISTS organization.unit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    department_id UUID
        REFERENCES organization.department(id),

    code TEXT,

    name TEXT NOT NULL,

    unit_type TEXT,

    capacity INTEGER,

    is_active BOOLEAN NOT NULL DEFAULT true,

    CHECK (capacity IS NULL OR capacity >= 0),

    UNIQUE (facility_id, code)
);

CREATE INDEX IF NOT EXISTS idx_unit_facility
    ON organization.unit(facility_id);

CREATE INDEX IF NOT EXISTS idx_unit_department
    ON organization.unit(department_id);

CREATE TABLE IF NOT EXISTS organization.clinic (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    department_id UUID
        REFERENCES organization.department(id),

    unit_id UUID
        REFERENCES organization.unit(id),

    code TEXT,

    name TEXT NOT NULL,

    clinic_type TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (facility_id, code)
);

CREATE INDEX IF NOT EXISTS idx_clinic_facility
    ON organization.clinic(facility_id);

-- =============================================================================
-- SERVICE CATALOGUE
-- =============================================================================

CREATE TABLE IF NOT EXISTS organization.service (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code TEXT NOT NULL UNIQUE,

    name TEXT NOT NULL,

    description TEXT,

    service_category TEXT,

    service_type TEXT,

    terminology_concept_id UUID
        REFERENCES terminology.concept(id),

    is_billable BOOLEAN NOT NULL DEFAULT false,

    is_clinical BOOLEAN NOT NULL DEFAULT true,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_category
    ON organization.service(service_category);

CREATE INDEX IF NOT EXISTS idx_service_active
    ON organization.service(is_active);

DROP TRIGGER IF EXISTS trg_service_updated_at
ON organization.service;

CREATE TRIGGER trg_service_updated_at
BEFORE UPDATE ON organization.service
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS organization.facility_service (
    facility_id UUID NOT NULL
        REFERENCES organization.facility(id)
        ON DELETE CASCADE,

    service_id UUID NOT NULL
        REFERENCES organization.service(id)
        ON DELETE CASCADE,

    is_active BOOLEAN NOT NULL DEFAULT true,

    available_from DATE,
    available_to DATE,

    PRIMARY KEY (facility_id, service_id)
);

CREATE TABLE IF NOT EXISTS organization.department_service (
    department_id UUID NOT NULL
        REFERENCES organization.department(id)
        ON DELETE CASCADE,

    service_id UUID NOT NULL
        REFERENCES organization.service(id)
        ON DELETE CASCADE,

    is_active BOOLEAN NOT NULL DEFAULT true,

    PRIMARY KEY (department_id, service_id)
);

CREATE TABLE IF NOT EXISTS organization.service_location (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    service_id UUID NOT NULL
        REFERENCES organization.service(id)
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

    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_service_location_service
    ON organization.service_location(service_id);

CREATE INDEX IF NOT EXISTS idx_service_location_facility
    ON organization.service_location(facility_id);

-- =============================================================================
-- WORKFORCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS organization.profession (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT,

    regulatory_body TEXT,

    is_clinical BOOLEAN NOT NULL DEFAULT false,

    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS organization.specialty (
    code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS organization.subspecialty (
    code TEXT PRIMARY KEY,

    specialty_code TEXT
        REFERENCES organization.specialty(code),

    label TEXT NOT NULL,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS organization.professional (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES identity.person(id),

    profession_code TEXT
        REFERENCES organization.profession(code),

    specialty_code TEXT
        REFERENCES organization.specialty(code),

    subspecialty_code TEXT
        REFERENCES organization.subspecialty(code),

    professional_identifier TEXT,

    staff_number TEXT,

    status TEXT NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_professional_person
    ON organization.professional(person_id);

CREATE INDEX IF NOT EXISTS idx_professional_profession
    ON organization.professional(profession_code);

CREATE INDEX IF NOT EXISTS idx_professional_specialty
    ON organization.professional(specialty_code);

DROP TRIGGER IF EXISTS trg_professional_updated_at
ON organization.professional;

CREATE TRIGGER trg_professional_updated_at
BEFORE UPDATE ON organization.professional
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- -----------------------------------------------------------------------------
-- LICENSES
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS organization.license (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    professional_id UUID NOT NULL
        REFERENCES organization.professional(id)
        ON DELETE CASCADE,

    license_type TEXT NOT NULL,

    license_number TEXT NOT NULL,

    issuing_body TEXT,

    country_code TEXT,

    issued_at DATE,

    expires_at DATE,

    status TEXT NOT NULL DEFAULT 'active',

    verified BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (license_type, license_number, issuing_body)
);

CREATE INDEX IF NOT EXISTS idx_license_professional
    ON organization.license(professional_id);

CREATE INDEX IF NOT EXISTS idx_license_expiry
    ON organization.license(expires_at);

-- -----------------------------------------------------------------------------
-- EMPLOYMENT
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS organization.employment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    professional_id UUID NOT NULL
        REFERENCES organization.professional(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    position TEXT,

    employment_type TEXT,

    started_on DATE,

    ended_on DATE,

    status TEXT NOT NULL DEFAULT 'active',

    is_primary BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_employment_professional
    ON organization.employment(professional_id);

CREATE INDEX IF NOT EXISTS idx_employment_org
    ON organization.employment(organization_id);

CREATE INDEX IF NOT EXISTS idx_employment_facility
    ON organization.employment(facility_id);

-- -----------------------------------------------------------------------------
-- STAFF ASSIGNMENT
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS organization.staff_assignment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    professional_id UUID NOT NULL
        REFERENCES organization.professional(id)
        ON DELETE CASCADE,

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    department_id UUID
        REFERENCES organization.department(id),

    unit_id UUID
        REFERENCES organization.unit(id),

    clinic_id UUID
        REFERENCES organization.clinic(id),

    assignment_role TEXT,

    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),

    valid_to TIMESTAMPTZ,

    is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_assignment_professional
    ON organization.staff_assignment(professional_id);

CREATE INDEX IF NOT EXISTS idx_assignment_facility
    ON organization.staff_assignment(facility_id);

CREATE INDEX IF NOT EXISTS idx_assignment_unit
    ON organization.staff_assignment(unit_id);

-- =============================================================================
-- TEAMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS organization.team (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID
        REFERENCES organization.organization(id),

    facility_id UUID
        REFERENCES organization.facility(id),

    department_id UUID
        REFERENCES organization.department(id),

    code TEXT,

    name TEXT NOT NULL,

    description TEXT,

    team_type TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_facility
    ON organization.team(facility_id);

DROP TRIGGER IF EXISTS trg_team_updated_at
ON organization.team;