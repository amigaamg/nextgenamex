-- =============================================================================
-- AMEXAN Phase 1 — Migration 003: patient + encounter
-- =============================================================================
-- The longitudinal patient record and every clinical contact (OPD/IPD/ED/
-- telemedicine/home visit...) as a single universal structure.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS patient;
CREATE SCHEMA IF NOT EXISTS encounter;

COMMENT ON SCHEMA patient IS 'The longitudinal patient record.';
COMMENT ON SCHEMA encounter IS 'Every clinical contact, universally.';

-- =============================================================================
-- PATIENT
-- =============================================================================

CREATE TABLE patient.patient_status (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE patient.patient_status IS 'Lifecycle of a patient record: active/inactive/deceased...';

CREATE TABLE patient.patient (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id),
   mrn               text NOT NULL UNIQUE,      -- medical record number
   status_code       text NOT NULL DEFAULT 'active' REFERENCES patient.patient_status(code),
   registered_at     timestamptz NOT NULL DEFAULT now(),
   registered_by     uuid REFERENCES identity.user_account(id),
   is_deceased       boolean NOT NULL DEFAULT false,
   deceased_at       timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE patient.patient IS 'A person as a patient. Person + patient profile + lifetime clinical record.';

CREATE INDEX idx_patient_person ON patient.patient(person_id);
CREATE INDEX idx_patient_status ON patient.patient(status_code);
CREATE TRIGGER trg_patient_updated_at
   BEFORE UPDATE ON patient.patient
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE patient.patient_identifier (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   identifier_type   text NOT NULL,           -- mrn / cr_number / external_id / ...
   value             text NOT NULL,
   authority         text,
   is_primary        boolean NOT NULL DEFAULT false,
   UNIQUE (patient_id, identifier_type, value)
);
COMMENT ON TABLE patient.patient_identifier IS 'Extra identifiers for a patient beyond the primary MRN.';

CREATE TABLE patient.patient_relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   related_person_id uuid NOT NULL REFERENCES identity.person(id),
   relationship_type text NOT NULL,           -- guardian / next_of_kin / caregiver
   status            text NOT NULL DEFAULT 'active',
   notes             text
);
COMMENT ON TABLE patient.patient_relationship IS 'Guardian/next-of-kin/caregiver for a patient.';

CREATE INDEX idx_patient_relationship_patient ON patient.patient_relationship(patient_id);

CREATE TABLE patient.patient_preference (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   preference_key    text NOT NULL,           -- e.g. sms_updates / language / interpreter_required
   preference_value  text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (patient_id, preference_key)
);
COMMENT ON TABLE patient.patient_preference IS 'Key/value care and communication preferences for a patient.';

CREATE TRIGGER trg_patient_preference_updated_at
   BEFORE UPDATE ON patient.patient_preference
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE patient.patient_language (
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   language_code     text NOT NULL REFERENCES identity.language(code),
   is_primary        boolean NOT NULL DEFAULT false,
   PRIMARY KEY (patient_id, language_code)
);
COMMENT ON TABLE patient.patient_language IS 'Languages a patient speaks.';

CREATE TABLE patient.patient_contact (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   contact_type      text NOT NULL,           -- phone / email / ...
   value             text NOT NULL,
   is_primary        boolean NOT NULL DEFAULT false,
   verified          boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE patient.patient_contact IS 'Contact channels specific to the patient record.';

CREATE INDEX idx_patient_contact_patient ON patient.patient_contact(patient_id);

CREATE TABLE patient.patient_address (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   address_type      text NOT NULL DEFAULT 'home',
   line1             text,
   line2             text,
   city              text,
   province_state    text,
   postal_code       text,
   country           text,
   is_primary        boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE patient.patient_address IS 'Addresses specific to the patient record.';

CREATE TABLE patient.patient_consent (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   consent_policy_code text REFERENCES security.consent_policy(code),
   consent_type      text NOT NULL,           -- e.g. treatment / research / data_sharing / communication
   decision          text NOT NULL CHECK (decision IN ('granted','denied','withdrawn')),
   granted_at        timestamptz,
   expires_at        timestamptz,
   captured_by       uuid REFERENCES identity.user_account(id),
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE patient.patient_consent IS 'Consent decisions made by/for a patient.';

CREATE INDEX idx_patient_consent_patient ON patient.patient_consent(patient_id);

CREATE TABLE patient.patient_privacy (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   setting           text NOT NULL,           -- e.g. restrict_hiv / restrict_mental_health / no_share
   is_restricted     boolean NOT NULL DEFAULT true,
   reason            text,
   set_by            uuid REFERENCES identity.user_account(id),
   set_at            timestamptz NOT NULL DEFAULT now(),
   UNIQUE (patient_id, setting)
);
COMMENT ON TABLE patient.patient_privacy IS 'Privacy restrictions on a patient record.';

-- =============================================================================
-- ENCOUNTER
-- =============================================================================

CREATE TABLE encounter.encounter_type (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE encounter.encounter_type IS 'OPD / IPD / emergency / telemedicine / home visit / community / procedure / discharge / follow-up...';

CREATE TABLE encounter.encounter_status (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE encounter.encounter_status IS 'planned / active / completed / cancelled / on_hold.';

CREATE TABLE encounter.encounter_phase (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text,
   sort_order        integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE encounter.encounter_phase IS 'Clinical phase of an encounter (registration, triage, assessment, disposition...).';

CREATE TABLE encounter.encounter_priority (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   sort_order        integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE encounter.encounter_priority IS 'routine / urgent / emergency / stat.';

CREATE TABLE encounter.encounter_episode (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   episode_type      text,                    -- e.g. admission_episode / care_episode
   name              text,
   started_at        timestamptz NOT NULL DEFAULT now(),
   ended_at          timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE encounter.encounter_episode IS 'A broader episode bundling multiple encounters (e.g. a hospitalization).';

CREATE INDEX idx_episode_patient ON encounter.encounter_episode(patient_id);

CREATE TABLE encounter.encounter (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id            uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   episode_id            uuid REFERENCES encounter.encounter_episode(id),
   encounter_type_code   text NOT NULL REFERENCES encounter.encounter_type(code),
   status_code           text NOT NULL DEFAULT 'planned' REFERENCES encounter.encounter_status(code),
   phase_code            text REFERENCES encounter.encounter_phase(code),
   priority_code         text REFERENCES encounter.encounter_priority(code),
   facility_id           uuid REFERENCES organization.facility(id),
   department_id         uuid REFERENCES organization.department(id),
   unit_id               uuid REFERENCES organization.unit(id),
   clinic_id             uuid REFERENCES organization.clinic(id),
   started_at            timestamptz,
   ended_at              timestamptz,
   duration_minutes      integer,
   summary               text,
   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE encounter.encounter IS 'The universal encounter master record.';

CREATE INDEX idx_encounter_patient ON encounter.encounter(patient_id);
CREATE INDEX idx_encounter_status ON encounter.encounter(status_code);
CREATE INDEX idx_encounter_started ON encounter.encounter(started_at);
CREATE TRIGGER trg_encounter_updated_at
   BEFORE UPDATE ON encounter.encounter
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE encounter.encounter_phase_history (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   encounter_id      uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   phase_code        text NOT NULL REFERENCES encounter.encounter_phase(code),
   entered_at        timestamptz NOT NULL DEFAULT now(),
   entered_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE encounter.encounter_phase_history IS 'Every phase transition an encounter has been through.';

CREATE INDEX idx_phase_history_encounter ON encounter.encounter_phase_history(encounter_id);

CREATE TABLE encounter.encounter_participant (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   encounter_id      uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   professional_id   uuid REFERENCES organization.professional(id),
   person_id         uuid REFERENCES identity.person(id),
   participant_role  text NOT NULL,           -- attending / admitting / consulted / nurse / clerk / ...
   valid_from        timestamptz,
   valid_to          timestamptz
);
COMMENT ON TABLE encounter.encounter_participant IS 'Clinicians and others involved in an encounter.';

CREATE INDEX idx_encounter_participant_encounter ON encounter.encounter_participant(encounter_id);

CREATE TABLE encounter.encounter_location (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   encounter_id      uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   unit_id           uuid REFERENCES organization.unit(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   room_id           uuid REFERENCES organization.room(id),
   bed_id            uuid REFERENCES organization.bed(id),
   from_time         timestamptz,
   to_time           timestamptz
);
COMMENT ON TABLE encounter.encounter_location IS 'Physical location(s) of an encounter over time.';

CREATE INDEX idx_encounter_location_encounter ON encounter.encounter_location(encounter_id);

CREATE TABLE encounter.encounter_service (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   encounter_id      uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   service_id        uuid NOT NULL REFERENCES organization.service(id),
   is_primary        boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE encounter.encounter_service IS 'Services rendered during an encounter.';

CREATE INDEX idx_encounter_service_encounter ON encounter.encounter_service(encounter_id);

CREATE TABLE encounter.encounter_reason (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   encounter_id      uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   reason            text NOT NULL,           -- free text reason for encounter
   is_primary        boolean NOT NULL DEFAULT false,
   concept_id        uuid REFERENCES terminology.concept(id)   -- coded reason when known
);
COMMENT ON TABLE encounter.encounter_reason IS 'Why the encounter happened.';

CREATE INDEX idx_encounter_reason_encounter ON encounter.encounter_reason(encounter_id);

CREATE TABLE encounter.encounter_parent (
   parent_encounter_id  uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   child_encounter_id   uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
   relationship         text NOT NULL DEFAULT 'follow_up',   -- follow_up / referral_origin / admission / ...
   PRIMARY KEY (parent_encounter_id, child_encounter_id)
);
COMMENT ON TABLE encounter.encounter_parent IS 'Links between encounters (e.g. OPD -> follow-up, ED -> admission).';
