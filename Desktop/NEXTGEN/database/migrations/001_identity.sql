-- =============================================================================
-- AMEXAN Phase 1 — Migration 001: identity
-- =============================================================================
-- Universal persons, login accounts, identifiers, contacts, addresses and
-- relationships. A person is NOT a patient and NOT a login; roles sit above
-- this layer in later migrations / applications.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS identity;
COMMENT ON SCHEMA identity IS 'Universal human identity: persons, accounts, contacts, addresses.';

-- Shared trigger to maintain updated_at ---------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
   NEW.updated_at := now();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Reference: language + person status
-- ---------------------------------------------------------------------------

CREATE TABLE identity.language (
   code            text PRIMARY KEY,
   label           text NOT NULL,
   native_label    text,
   created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.language IS 'ISO-639 style language codes used across identity, patient and communication.';

CREATE TABLE identity.person_status (
   code            text PRIMARY KEY,
   label           text NOT NULL,
   description     text,
   created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.person_status IS 'Lifecycle state of a person: active/inactive/deceased/etc.';

-- ---------------------------------------------------------------------------
-- Person
-- ---------------------------------------------------------------------------

CREATE TABLE identity.person (
   id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   status_code             text NOT NULL DEFAULT 'active' REFERENCES identity.person_status(code),
   gender                  text CHECK (gender IN ('male','female','other','unknown')),
   birth_date              date,
   birth_date_estimated    boolean NOT NULL DEFAULT false,
   death_date              date,
   death_estimated         boolean NOT NULL DEFAULT false,
   marital_status          text,
   blood_type              text CHECK (blood_type IN ('A+','A-','B+','B-','AB+','AB-','O+','O-','unknown')),
   nationality             text,
   occupation              text,
   preferred_language_code text REFERENCES identity.language(code),
   preferred_name          text,
   notes                   text,
   created_at              timestamptz NOT NULL DEFAULT now(),
   updated_at              timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.person IS 'Universal human being. Every patient, clinician, staff member, guardian and relative is a person.';

CREATE INDEX idx_person_status ON identity.person(status_code);
CREATE INDEX idx_person_birth_date ON identity.person(birth_date);

CREATE TRIGGER trg_person_updated_at
   BEFORE UPDATE ON identity.person
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Person identifiers (national ID, passport, NHIF, etc.)
-- ---------------------------------------------------------------------------

CREATE TABLE identity.person_identifier (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   identifier_type   text NOT NULL,            -- national_id / passport / driving_license / nhif / ssn / ...
   value             text NOT NULL,
   authority         text,                     -- issuing authority / country
   issued_at         date,
   expires_at        date,
   verified          boolean NOT NULL DEFAULT false,
   verified_at       timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (person_id, identifier_type, value)
);
COMMENT ON TABLE identity.person_identifier IS 'Official identifiers attached to a person (not MRN — that lives in patient schema).';

CREATE INDEX idx_person_identifier_value ON identity.person_identifier(value);

CREATE TRIGGER trg_person_identifier_updated_at
   BEFORE UPDATE ON identity.person_identifier
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Contact points and addresses
-- ---------------------------------------------------------------------------

CREATE TABLE identity.contact_point (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   contact_type      text NOT NULL,            -- phone / email / fax / pager
   value             text NOT NULL,
   is_primary        boolean NOT NULL DEFAULT false,
   verified          boolean NOT NULL DEFAULT false,
   verified_at       timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.contact_point IS 'How to reach a person: phone, email, etc.';

CREATE INDEX idx_contact_point_person ON identity.contact_point(person_id);

CREATE TRIGGER trg_contact_point_updated_at
   BEFORE UPDATE ON identity.contact_point
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE identity.address (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   address_type      text NOT NULL DEFAULT 'home',  -- home / work / postal / temporary
   line1             text,
   line2             text,
   city              text,
   province_state    text,
   postal_code       text,
   country           text,
   latitude          numeric(9,6),
   longitude         numeric(9,6),
   is_primary        boolean NOT NULL DEFAULT false,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.address IS 'Physical addresses for a person.';

CREATE INDEX idx_address_person ON identity.address(person_id);

CREATE TRIGGER trg_address_updated_at
   BEFORE UPDATE ON identity.address
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Emergency contacts + person relationships
-- ---------------------------------------------------------------------------

CREATE TABLE identity.emergency_contact (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   contact_person_id uuid REFERENCES identity.person(id),  -- if the contact is known to the system
   name              text NOT NULL,
   relationship      text,                    -- spouse / parent / sibling / friend
   phone             text,
   email             text,
   notes             text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.emergency_contact IS 'Who to contact in an emergency for a person.';

CREATE TRIGGER trg_emergency_contact_updated_at
   BEFORE UPDATE ON identity.emergency_contact
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE identity.person_relationship (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   related_person_id uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   relationship_type text NOT NULL,           -- spouse / parent / guardian / child / sibling
   status            text NOT NULL DEFAULT 'active',
   valid_from        date,
   valid_to          date,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   CHECK (person_id <> related_person_id)
);
COMMENT ON TABLE identity.person_relationship IS 'Directed relationship between two people.';

CREATE INDEX idx_person_relationship_related ON identity.person_relationship(related_person_id);

CREATE TRIGGER trg_person_relationship_updated_at
   BEFORE UPDATE ON identity.person_relationship
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Communication preferences
-- ---------------------------------------------------------------------------

CREATE TABLE identity.communication_preference (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   language_code     text REFERENCES identity.language(code),
   channel           text NOT NULL,           -- sms / email / phone / app / post
   is_primary        boolean NOT NULL DEFAULT false,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.communication_preference IS 'How and in what language a person prefers to be reached.';

CREATE TRIGGER trg_communication_preference_updated_at
   BEFORE UPDATE ON identity.communication_preference
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- User accounts (login identities)
-- ---------------------------------------------------------------------------

CREATE TABLE identity.user_account (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id),
   username          text NOT NULL UNIQUE,
   email             text,
   phone             text,
   password_hash     text,                    -- argon2/bcrypt hash; may be null for OAuth-only accounts
   account_status    text NOT NULL DEFAULT 'active'
                     CHECK (account_status IN ('active','locked','disabled','pending_verification')),
   email_verified    boolean NOT NULL DEFAULT false,
   phone_verified    boolean NOT NULL DEFAULT false,
   must_change_password boolean NOT NULL DEFAULT false,
   last_login_at     timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.user_account IS 'Login account. A person may have many; a person need not have one.';

CREATE INDEX idx_user_account_person ON identity.user_account(person_id);

CREATE TRIGGER trg_user_account_updated_at
   BEFORE UPDATE ON identity.user_account
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE identity.user_credential (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   user_account_id   uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE CASCADE,
   credential_type   text NOT NULL,           -- password / totp / oauth / webauthn / api_key
   secret_hash       text,                    -- hash of the secret / token value
   expires_at        timestamptz,
   revoked_at        timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE identity.user_credential IS 'Authentication metadata for an account. Never store plaintext secrets.';

CREATE INDEX idx_user_credential_account ON identity.user_credential(user_account_id);

CREATE TABLE identity.user_session (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   user_account_id   uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE CASCADE,
   token_hash        text NOT NULL UNIQUE,
   ip_address        inet,
   user_agent        text,
   device            text,
   started_at        timestamptz NOT NULL DEFAULT now(),
   expires_at        timestamptz NOT NULL,
   last_active_at    timestamptz NOT NULL DEFAULT now(),
   ended_at          timestamptz,
   revoked           boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE identity.user_session IS 'Active/revoked sessions. Tokens are stored only as hashes.';

CREATE INDEX idx_user_session_account ON identity.user_session(user_account_id);
CREATE INDEX idx_user_session_expiry ON identity.user_session(expires_at);
