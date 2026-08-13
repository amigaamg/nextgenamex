-- =============================================================================
-- AMEXAN Phase 1 — Migration 002: organization + security + terminology
-- =============================================================================
-- Where care happens (organizations, facilities, workforce) + who can do what
-- (roles, permissions, API clients) + the universal language (concepts, codes,
-- mappings, value sets, units).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS organization;
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS terminology;

COMMENT ON SCHEMA organization IS 'Organizations, facilities, physical space and workforce.';
COMMENT ON SCHEMA security IS 'Roles, permissions, access policies, API clients.';
COMMENT ON SCHEMA terminology IS 'Universal concepts, code systems, mappings, value sets and units.';

-- =============================================================================
-- TERMINOLOGY (built first so every other schema can reference concepts)
-- =============================================================================

CREATE TABLE terminology.code_system (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   name              text NOT NULL UNIQUE,     -- SNOMED CT / ICD-10 / LOINC / ...
   oid               text,
   uri               text,
   version           text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE terminology.code_system IS 'A source of codes (SNOMED, ICD, LOINC, local codes...).';

CREATE TRIGGER trg_code_system_updated_at
   BEFORE UPDATE ON terminology.code_system
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE terminology.code (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code_system_id    uuid NOT NULL REFERENCES terminology.code_system(id),
   code              text NOT NULL,
   display           text NOT NULL,
   definition        text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (code_system_id, code)
);
COMMENT ON TABLE terminology.code IS 'A raw code as issued by a code system.';

CREATE INDEX idx_code_display ON terminology.code(display);
CREATE TRIGGER trg_code_updated_at
   BEFORE UPDATE ON terminology.code
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE terminology.concept (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   parent_id         uuid REFERENCES terminology.concept(id),
   display_name      text NOT NULL,
   definition        text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE terminology.concept IS 'Universal concept that can map to many codes across code systems.';

CREATE INDEX idx_concept_display ON terminology.concept(display_name);
CREATE TRIGGER trg_concept_updated_at
   BEFORE UPDATE ON terminology.concept
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE terminology.concept_code (
   concept_id        uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   code_id           uuid NOT NULL REFERENCES terminology.code(id) ON DELETE CASCADE,
   relationship      text NOT NULL DEFAULT 'equivalent',  -- equivalent / narrower / broader
   PRIMARY KEY (concept_id, code_id)
);
COMMENT ON TABLE terminology.concept_code IS 'Links a universal concept to codes in various code systems.';

CREATE TABLE terminology.concept_synonym (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   synonym           text NOT NULL,
   language_code     text,
   is_preferred      boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE terminology.concept_synonym IS 'Alternate terms for a concept (clinician term, patient-friendly term...).';

CREATE INDEX idx_concept_synonym_text ON terminology.concept_synonym(synonym);

CREATE TABLE terminology.concept_translation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id        uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   language_code     text NOT NULL,
   translation       text NOT NULL,
   is_preferred      boolean NOT NULL DEFAULT false,
   UNIQUE (concept_id, language_code, translation)
);
COMMENT ON TABLE terminology.concept_translation IS 'Translations of a concept (Kiswahili, Luo, English...).';

CREATE TABLE terminology.concept_relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   source_concept_id uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   target_concept_id uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   relationship_type text NOT NULL,           -- is_a / associated_with / caused_by / ...
   is_bi_directional boolean NOT NULL DEFAULT false,
   created_at        timestamptz NOT NULL DEFAULT now(),
   CHECK (source_concept_id <> target_concept_id)
);
COMMENT ON TABLE terminology.concept_relationship IS 'Typed relationships between universal concepts.';

CREATE INDEX idx_concept_relationship_target ON terminology.concept_relationship(target_concept_id);

CREATE TABLE terminology.mapping (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   source_concept_id     uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   target_concept_id     uuid NOT NULL REFERENCES terminology.concept(id) ON DELETE CASCADE,
   mapping_relationship  text NOT NULL,       -- equivalent / source_narrower / source_broader / ...
   authority             text,
   confidence            numeric(4,3) CHECK (confidence >= 0 AND confidence <= 1),
   created_at            timestamptz NOT NULL DEFAULT now(),
   CHECK (source_concept_id <> target_concept_id)
);
COMMENT ON TABLE terminology.mapping IS 'Authoritative cross-terminology mappings between concepts.';

CREATE TABLE terminology.value_set (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   name              text NOT NULL UNIQUE,
   description       text,
   oid               text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE terminology.value_set IS 'A named, permitted set of codes (e.g. "vital sign parameters").';

CREATE TRIGGER trg_value_set_updated_at
   BEFORE UPDATE ON terminology.value_set
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE terminology.value_set_member (
   value_set_id      uuid NOT NULL REFERENCES terminology.value_set(id) ON DELETE CASCADE,
   code_id           uuid NOT NULL REFERENCES terminology.code(id) ON DELETE CASCADE,
   is_active         boolean NOT NULL DEFAULT true,
   sort_order        integer NOT NULL DEFAULT 0,
   PRIMARY KEY (value_set_id, code_id)
);
COMMENT ON TABLE terminology.value_set_member IS 'Membership of a code in a value set.';

CREATE TABLE terminology.unit (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   dimension         text,                    -- mass / length / time / temperature / ...
   symbol            text,
   si_unit_code      text REFERENCES terminology.unit(code),
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE terminology.unit IS 'Measurement units used by clinical values.';

CREATE TABLE terminology.unit_conversion (
   from_unit_code    text NOT NULL REFERENCES terminology.unit(code),
   to_unit_code      text NOT NULL REFERENCES terminology.unit(code),
   factor            numeric NOT NULL,        -- to = from * factor + offset_value
   offset_value      numeric NOT NULL DEFAULT 0,
   PRIMARY KEY (from_unit_code, to_unit_code)
);
COMMENT ON TABLE terminology.unit_conversion IS 'Linear conversions between units.';

-- =============================================================================
-- ORGANIZATION — legal/administrative structure
-- =============================================================================

CREATE TABLE organization.organization (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   parent_id         uuid REFERENCES organization.organization(id),
   name              text NOT NULL,
   legal_name        text,
   organization_type text NOT NULL,           -- hospital_network / hospital / clinic / ministry / insurance / ...
   tax_id            text,
   country           text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE organization.organization IS 'Legal/administrative organization (group, network, hospital authority...).';

CREATE INDEX idx_organization_parent ON organization.organization(parent_id);
CREATE TRIGGER trg_organization_updated_at
   BEFORE UPDATE ON organization.organization
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE organization.organization_identifier (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   organization_id   uuid NOT NULL REFERENCES organization.organization(id) ON DELETE CASCADE,
   identifier_type   text NOT NULL,           -- registration / license / ministry_code / ...
   value             text NOT NULL,
   authority         text,
   issued_at         date,
   expires_at        date,
   UNIQUE (organization_id, identifier_type, value)
);
COMMENT ON TABLE organization.organization_identifier IS 'Registration/license IDs for an organization.';

-- Facilities -----------------------------------------------------------------

CREATE TABLE organization.facility (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   organization_id   uuid REFERENCES organization.organization(id),
   name              text NOT NULL,
   facility_type     text NOT NULL,           -- hospital / clinic / health_center / dispensary / ...
   status            text NOT NULL DEFAULT 'active',
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE organization.facility IS 'A site where care is delivered (hospital, clinic, health centre).';

CREATE INDEX idx_facility_org ON organization.facility(organization_id);
CREATE TRIGGER trg_facility_updated_at
   BEFORE UPDATE ON organization.facility
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE organization.facility_identifier (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   facility_id       uuid NOT NULL REFERENCES organization.facility(id) ON DELETE CASCADE,
   identifier_type   text NOT NULL,           -- facility_code / mfl_code / license / ...
   value             text NOT NULL,
   authority         text,
   UNIQUE (facility_id, identifier_type, value)
);
COMMENT ON TABLE organization.facility_identifier IS 'External identifiers for a facility.';

CREATE TABLE organization.campus (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   facility_id       uuid NOT NULL REFERENCES organization.facility(id) ON DELETE CASCADE,
   name              text NOT NULL
);
COMMENT ON TABLE organization.campus IS 'A campus within a facility.';

CREATE TABLE organization.building (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   campus_id         uuid REFERENCES organization.campus(id),
   facility_id       uuid REFERENCES organization.facility(id),
   name              text NOT NULL
);
COMMENT ON TABLE organization.building IS 'A building within a facility/campus.';

CREATE TABLE organization.floor (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   building_id       uuid NOT NULL REFERENCES organization.building(id) ON DELETE CASCADE,
   name              text NOT NULL,
   level             integer
);
COMMENT ON TABLE organization.floor IS 'A floor within a building.';

CREATE TABLE organization.room (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   floor_id          uuid REFERENCES organization.floor(id),
   building_id       uuid REFERENCES organization.building(id),
   name              text NOT NULL,
   room_type         text                     -- ward / consultation / theatre / lab / pharmacy / ...
);
COMMENT ON TABLE organization.room IS 'A physical room where care or services happen.';

CREATE TABLE organization.bed (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   room_id           uuid NOT NULL REFERENCES organization.room(id) ON DELETE CASCADE,
   name              text NOT NULL,
   status            text NOT NULL DEFAULT 'available'
                     CHECK (status IN ('available','occupied','reserved','maintenance')),
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.bed IS 'A physical bed. Occupancy is tracked in encounters, not here.';

-- Care structure --------------------------------------------------------------

CREATE TABLE organization.department (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   facility_id       uuid NOT NULL REFERENCES organization.facility(id) ON DELETE CASCADE,
   parent_id         uuid REFERENCES organization.department(id),
   name              text NOT NULL,           -- "Medicine", "Surgery" — free of hardcoding but stored per-facility
   code              text
);
COMMENT ON TABLE organization.department IS 'A department within a facility (no special-casing of specialties).';

CREATE INDEX idx_department_facility ON organization.department(facility_id);

CREATE TABLE organization.unit (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   facility_id       uuid NOT NULL REFERENCES organization.facility(id) ON DELETE CASCADE,
   department_id     uuid REFERENCES organization.department(id),
   name              text NOT NULL,           -- ward / service unit / ICU / labour ward
   code              text
);
COMMENT ON TABLE organization.unit IS 'A ward or service unit where care is delivered.';

CREATE INDEX idx_unit_department ON organization.unit(department_id);

CREATE TABLE organization.clinic (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   facility_id       uuid NOT NULL REFERENCES organization.facility(id) ON DELETE CASCADE,
   department_id     uuid REFERENCES organization.department(id),
   unit_id           uuid REFERENCES organization.unit(id),
   name              text NOT NULL,           -- MOPC / ANC / diabetes clinic / ...
   code              text
);
COMMENT ON TABLE organization.clinic IS 'An outpatient/specialty clinic.';

-- Service catalogue ------------------------------------------------------------

CREATE TABLE organization.service (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   description       text,
   service_category  text,                    -- clinical / laboratory / radiology / pharmacy / administrative
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE organization.service IS 'Catalogue of services AMEXAN can deliver/order.';

CREATE TRIGGER trg_service_updated_at
   BEFORE UPDATE ON organization.service
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE organization.service_location (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   service_id        uuid NOT NULL REFERENCES organization.service(id) ON DELETE CASCADE,
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   unit_id           uuid REFERENCES organization.unit(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   room_id           uuid REFERENCES organization.room(id),
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.service_location IS 'Where a service is physically delivered.';

CREATE TABLE organization.facility_service (
   facility_id       uuid NOT NULL REFERENCES organization.facility(id) ON DELETE CASCADE,
   service_id        uuid NOT NULL REFERENCES organization.service(id) ON DELETE CASCADE,
   is_active         boolean NOT NULL DEFAULT true,
   PRIMARY KEY (facility_id, service_id)
);
COMMENT ON TABLE organization.facility_service IS 'Services available at a facility.';

CREATE TABLE organization.department_service (
   department_id     uuid NOT NULL REFERENCES organization.department(id) ON DELETE CASCADE,
   service_id        uuid NOT NULL REFERENCES organization.service(id) ON DELETE CASCADE,
   is_active         boolean NOT NULL DEFAULT true,
   PRIMARY KEY (department_id, service_id)
);
COMMENT ON TABLE organization.department_service IS 'Services offered by a department.';

-- Workforce --------------------------------------------------------------------

CREATE TABLE organization.profession (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text,
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.profession IS 'Clinical/non-clinical professions: doctor, nurse, pharmacist...';

CREATE TABLE organization.specialty (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.specialty IS 'Specialties: internal medicine, paediatrics, surgery...';

CREATE TABLE organization.subspecialty (
   code              text PRIMARY KEY,
   specialty_code    text REFERENCES organization.specialty(code),
   label             text NOT NULL,
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.subspecialty IS 'Subspecialties within a specialty.';

CREATE TABLE organization.professional (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id),
   profession_code   text REFERENCES organization.profession(code),
   specialty_code    text REFERENCES organization.specialty(code),
   subspecialty_code text REFERENCES organization.subspecialty(code),
   staff_number      text,
   status            text NOT NULL DEFAULT 'active',
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE organization.professional IS 'A person acting in a professional/clinical capacity.';

CREATE INDEX idx_professional_person ON organization.professional(person_id);
CREATE TRIGGER trg_professional_updated_at
   BEFORE UPDATE ON organization.professional
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE organization.license (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   professional_id   uuid NOT NULL REFERENCES organization.professional(id) ON DELETE CASCADE,
   license_type      text NOT NULL,           -- medical_practitioners / nursing_council / ...
   license_number    text NOT NULL,
   issuing_body      text,
   issued_at         date,
   expires_at        date,
   verified          boolean NOT NULL DEFAULT false,
   UNIQUE (license_type, license_number)
);
COMMENT ON TABLE organization.license IS 'Professional licenses held by a professional.';

CREATE TABLE organization.employment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   professional_id   uuid NOT NULL REFERENCES organization.professional(id) ON DELETE CASCADE,
   organization_id   uuid REFERENCES organization.organization(id),
   facility_id       uuid REFERENCES organization.facility(id),
   position          text,
   employment_type   text,                    -- full_time / part_time / locum / volunteer
   started_on        date,
   ended_on          date,
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.employment IS 'Employment relationship between a professional and an organization/facility.';

CREATE INDEX idx_employment_professional ON organization.employment(professional_id);

CREATE TABLE organization.staff_assignment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   professional_id   uuid NOT NULL REFERENCES organization.professional(id) ON DELETE CASCADE,
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   unit_id           uuid REFERENCES organization.unit(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   role_text         text,
   valid_from        timestamptz,
   valid_to          timestamptz,
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE organization.staff_assignment IS 'Where a professional is assigned to work.';

CREATE TABLE organization.team (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   name              text NOT NULL,
   description       text,
   facility_id       uuid REFERENCES organization.facility(id),
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE organization.team IS 'A care team (e.g. ward team, trauma team).';

CREATE TRIGGER trg_team_updated_at
   BEFORE UPDATE ON organization.team
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE organization.team_member (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   team_id           uuid NOT NULL REFERENCES organization.team(id) ON DELETE CASCADE,
   professional_id   uuid NOT NULL REFERENCES organization.professional(id) ON DELETE CASCADE,
   member_role       text,                    -- lead / member / consultant
   valid_from        timestamptz,
   valid_to          timestamptz,
   UNIQUE (team_id, professional_id, member_role, valid_from)
);
COMMENT ON TABLE organization.team_member IS 'Membership of a professional in a care team.';

-- =============================================================================
-- SECURITY
-- =============================================================================

CREATE TABLE security.permission (
   code              text PRIMARY KEY,
   resource          text NOT NULL,           -- patient / encounter / order / ...
   action            text NOT NULL,           -- view / create / update / delete / prescribe
   description       text,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE security.permission IS 'Atomic permission. Example: patient.view, encounter.document, order.lab.';

CREATE INDEX idx_permission_resource ON security.permission(resource);

CREATE TABLE security.role (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   description       text,
   is_system         boolean NOT NULL DEFAULT false,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE security.role IS 'A named bundle of permissions (doctor, receptionist, nurse...).';

CREATE TRIGGER trg_role_updated_at
   BEFORE UPDATE ON security.role
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE security.role_permission (
   role_id           uuid NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
   permission_code   text NOT NULL REFERENCES security.permission(code) ON DELETE CASCADE,
   PRIMARY KEY (role_id, permission_code)
);
COMMENT ON TABLE security.role_permission IS 'Permission granted to a role.';

CREATE TABLE security.organization_role (
   organization_id   uuid NOT NULL REFERENCES organization.organization(id) ON DELETE CASCADE,
   role_id           uuid NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
   label             text,
   description       text,
   PRIMARY KEY (organization_id, role_id)
);
COMMENT ON TABLE security.organization_role IS 'A role as instantiated/scoped within an organization.';

CREATE TABLE security.user_role (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   user_account_id   uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE CASCADE,
   role_id           uuid NOT NULL REFERENCES security.role(id) ON DELETE CASCADE,
   organization_id   uuid REFERENCES organization.organization(id),
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   assigned_by       uuid REFERENCES identity.user_account(id),
   valid_from        timestamptz NOT NULL DEFAULT now(),
   valid_to          timestamptz
);
COMMENT ON TABLE security.user_role IS 'Role assignment to a user, optionally scoped to org/facility/department.';

CREATE INDEX idx_user_role_user ON security.user_role(user_account_id);
CREATE INDEX idx_user_role_role ON security.user_role(role_id);

CREATE TABLE security.access_policy (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   name              text NOT NULL UNIQUE,
   policy_type       text NOT NULL,           -- role_based / attribute_based / organization_scoped
   rule              jsonb,                   -- machine-evaluable policy expression
   description       text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE security.access_policy IS 'Declarative access rules evaluated by the engine.';

CREATE TRIGGER trg_access_policy_updated_at
   BEFORE UPDATE ON security.access_policy
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE security.resource_policy (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   access_policy_id  uuid NOT NULL REFERENCES security.access_policy(id) ON DELETE CASCADE,
   resource          text NOT NULL,           -- patient / encounter / document / ...
   resource_id       uuid,                    -- null = applies to all resources of the type
   permission_code   text REFERENCES security.permission(code),
   effect            text NOT NULL DEFAULT 'allow' CHECK (effect IN ('allow','deny')),
   priority          integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE security.resource_policy IS 'Resource-level access rules under an access policy.';

CREATE TABLE security.consent_policy (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   data_category     text,                    -- e.g. hiv_status / mental_health / research
   consent_required  boolean NOT NULL DEFAULT true,
   retention_days    integer,
   description       text,
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE security.consent_policy IS 'Categories of data that require consent, and their rules.';

CREATE TABLE security.api_client (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   client_id         text NOT NULL UNIQUE,
   client_name       text NOT NULL,
   client_secret_hash text,                   -- never plaintext
   organization_id   uuid REFERENCES organization.organization(id),
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE security.api_client IS 'External application/credentialed client.';

CREATE TRIGGER trg_api_client_updated_at
   BEFORE UPDATE ON security.api_client
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE security.api_scope (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE security.api_scope IS 'API permission scopes (e.g. patient:read, orders:write).';

CREATE TABLE security.api_client_scope (
   client_id         uuid NOT NULL REFERENCES security.api_client(id) ON DELETE CASCADE,
   scope_code        text NOT NULL REFERENCES security.api_scope(code) ON DELETE CASCADE,
   PRIMARY KEY (client_id, scope_code)
);
COMMENT ON TABLE security.api_client_scope IS 'Scopes granted to an API client.';
