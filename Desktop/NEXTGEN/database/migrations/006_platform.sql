-- =============================================================================
-- AMEXAN Phase 1 — Migration 006: platform infrastructure
-- =============================================================================
-- Configuration (inheritable, scoped — the AMEXAN superpower), audit
-- (who did what, when, to what, and what changed), interoperability, messaging,
-- and the system schema describing AMEXAN itself.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS configuration;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS interoperability;
CREATE SCHEMA IF NOT EXISTS communication;
CREATE SCHEMA IF NOT EXISTS system;

COMMENT ON SCHEMA configuration IS 'Scoped, inheritable, versioned configuration.';
COMMENT ON SCHEMA audit IS 'Immutable audit trail.';
COMMENT ON SCHEMA interoperability IS 'External systems, endpoints, messages, mappings, FHIR.';
COMMENT ON SCHEMA communication IS 'Messages, notifications and their delivery.';
COMMENT ON SCHEMA system IS 'AMEXAN itself: instances, engines, modules, jobs, releases.';

-- =============================================================================
-- SYSTEM
-- =============================================================================

CREATE TABLE system.environment (
   code              text PRIMARY KEY,          -- development / staging / production
   label             text NOT NULL
);
COMMENT ON TABLE system.environment IS 'Deployment environments.';

CREATE TABLE system.instance (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   instance_name     text NOT NULL UNIQUE,
   environment_code  text NOT NULL REFERENCES system.environment(code),
   region            text,
   version           text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE system.instance IS 'An AMEXAN deployment instance.';

CREATE TRIGGER trg_system_instance_updated_at
   BEFORE UPDATE ON system.instance
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE system.module (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   version           text,
   description       text,
   is_active         boolean NOT NULL DEFAULT true,
   installed_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE system.module IS 'Installed AMEXAN modules.';

CREATE TABLE system.service (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   service_type      text,                      -- api / worker / scheduler / engine_host
   status            text NOT NULL DEFAULT 'unknown'
                     CHECK (status IN ('unknown','healthy','degraded','down')),
   base_url          text,
   version           text,
   last_heartbeat    timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE system.service IS 'A backend service of the platform.';

CREATE TRIGGER trg_system_service_updated_at
   BEFORE UPDATE ON system.service
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE system.engine (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,      -- e.g. clinical_cpu / medication_engine
   name              text NOT NULL,
   engine_type       text,                      -- reasoning / orchestration / documentation / safety
   description       text,
   status            text NOT NULL DEFAULT 'inactive',
   is_active         boolean NOT NULL DEFAULT false,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE system.engine IS 'A registered AMEXAN engine (the CPU and friends).';

CREATE TRIGGER trg_system_engine_updated_at
   BEFORE UPDATE ON system.engine
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE system.engine_version (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   engine_id         uuid NOT NULL REFERENCES system.engine(id) ON DELETE CASCADE,
   version           text NOT NULL,
   changelog         text,
   is_active         boolean NOT NULL DEFAULT false,
   released_at       timestamptz NOT NULL DEFAULT now(),
   UNIQUE (engine_id, version)
);
COMMENT ON TABLE system.engine_version IS 'Version of an engine.';

CREATE TABLE system.feature_flag (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   description       text,
   enabled           boolean NOT NULL DEFAULT false,
   environment_code  text REFERENCES system.environment(code),
   scope             jsonb,                     -- optional targeting rules
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE system.feature_flag IS 'Controlled feature activation.';

CREATE TABLE system.release (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   version           text NOT NULL UNIQUE,
   name              text,
   description       text,
   status            text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','deployed','rolled_back')),
   released_at       timestamptz
);
COMMENT ON TABLE system.release IS 'AMEXAN releases.';

CREATE TABLE system.release_change (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   release_id        uuid NOT NULL REFERENCES system.release(id) ON DELETE CASCADE,
   change_type       text NOT NULL,             -- feature / fix / migration / breaking
   summary           text NOT NULL,
   change_ref        text
);
COMMENT ON TABLE system.release_change IS 'What changed in a release.';

CREATE TABLE system.health_check (
   id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
   service_id        uuid REFERENCES system.service(id),
   status            text NOT NULL,
   latency_ms        integer,
   checked_at        timestamptz NOT NULL DEFAULT now(),
   detail            jsonb
);
COMMENT ON TABLE system.health_check IS 'Service health snapshots.';

CREATE TABLE system.job (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   schedule          text,                      -- cron expression
   handler           text,
   is_active         boolean NOT NULL DEFAULT true,
   last_run_at       timestamptz
);
COMMENT ON TABLE system.job IS 'Background job definition.';

CREATE TABLE system.job_execution (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   job_id            uuid NOT NULL REFERENCES system.job(id) ON DELETE CASCADE,
   started_at        timestamptz NOT NULL DEFAULT now(),
   ended_at          timestamptz,
   status            text NOT NULL DEFAULT 'running' CHECK (status IN ('running','succeeded','failed','cancelled')),
   result            jsonb,
   error             text
);
COMMENT ON TABLE system.job_execution IS 'Execution history of background jobs.';

CREATE INDEX idx_job_execution_job ON system.job_execution(job_id);

CREATE TABLE system.event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   event_type        text NOT NULL,
   source            text,
   severity          text NOT NULL DEFAULT 'info' CHECK (severity IN ('debug','info','warning','error','critical')),
   event_at          timestamptz NOT NULL DEFAULT now(),
   payload           jsonb
);
COMMENT ON TABLE system.event IS 'System events.';

CREATE INDEX idx_system_event_type ON system.event(event_type);

-- =============================================================================
-- CONFIGURATION
-- =============================================================================

CREATE TABLE configuration.scope (
   code              text PRIMARY KEY,          -- global / country / organization / facility / department / clinic / clinician
   label             text NOT NULL,
   precedence        integer NOT NULL DEFAULT 0  -- higher wins
);
COMMENT ON TABLE configuration.scope IS 'Scopes at which configuration can be defined.';

CREATE TABLE configuration.configuration (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   key               text NOT NULL,
   name              text NOT NULL,
   description       text,
   data_type         text NOT NULL DEFAULT 'string' CHECK (data_type IN ('string','number','boolean','json','text')),
   default_value     jsonb,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE configuration.configuration IS 'A named configuration object with a default value.';

CREATE TRIGGER trg_configuration_updated_at
   BEFORE UPDATE ON configuration.configuration
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE configuration.configuration_version (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   configuration_id  uuid NOT NULL REFERENCES configuration.configuration(id) ON DELETE CASCADE,
   version           integer NOT NULL,
   value             jsonb NOT NULL,
   created_at        timestamptz NOT NULL DEFAULT now(),
   created_by        uuid REFERENCES identity.user_account(id),
   UNIQUE (configuration_id, version)
);
COMMENT ON TABLE configuration.configuration_version IS 'Versioned values of a configuration object.';

CREATE TABLE configuration.override (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   configuration_id  uuid NOT NULL REFERENCES configuration.configuration(id) ON DELETE CASCADE,
   scope_code        text NOT NULL REFERENCES configuration.scope(code),
   scope_entity_id   uuid,                      -- the org/facility/clinician id the scope applies to
   value             jsonb NOT NULL,
   override_version_id uuid REFERENCES configuration.configuration_version(id),
   priority          integer NOT NULL DEFAULT 0,
   valid_from        timestamptz NOT NULL DEFAULT now(),
   valid_to          timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE configuration.override IS 'A scoped override of a configuration value.';

CREATE INDEX idx_config_override_scope ON configuration.override(scope_code, scope_entity_id);

CREATE TABLE configuration.inheritance (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   scope_code        text NOT NULL REFERENCES configuration.scope(code),
   parent_scope_code text NOT NULL REFERENCES configuration.scope(code),
   precedence        integer NOT NULL DEFAULT 0,
   UNIQUE (scope_code, parent_scope_code)
);
COMMENT ON TABLE configuration.inheritance IS 'Scope hierarchy: clinician <- clinic <- department <- facility <- organization <- country <- global.';

CREATE TABLE configuration.activation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   configuration_id  uuid NOT NULL REFERENCES configuration.configuration(id) ON DELETE CASCADE,
   active_version_id uuid NOT NULL REFERENCES configuration.configuration_version(id),
   scope_code        text,
   scope_entity_id   uuid,
   activated_at      timestamptz NOT NULL DEFAULT now(),
   activated_by      uuid REFERENCES identity.user_account(id),
   UNIQUE (configuration_id, scope_code, scope_entity_id)
);
COMMENT ON TABLE configuration.activation IS 'Which version is currently active for a scope.';

CREATE TABLE configuration.test_case (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   configuration_id  uuid NOT NULL REFERENCES configuration.configuration(id) ON DELETE CASCADE,
   name              text NOT NULL,
   input             jsonb,
   expected          jsonb,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE configuration.test_case IS 'Example/test inputs for validating configuration.';

CREATE TABLE configuration.test_result (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   test_case_id      uuid NOT NULL REFERENCES configuration.test_case(id) ON DELETE CASCADE,
   executed_at       timestamptz NOT NULL DEFAULT now(),
   passed            boolean NOT NULL,
   actual            jsonb,
   error             text
);
COMMENT ON TABLE configuration.test_result IS 'Outcome of running a configuration test case.';

-- =============================================================================
-- AUDIT
-- =============================================================================

CREATE TABLE audit.event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   event_type        text NOT NULL,
   actor_type        text NOT NULL,             -- user / system / api_client
   actor_id          uuid,
   action            text NOT NULL,
   target_type       text,
   target_id         uuid,
   occurred_at       timestamptz NOT NULL DEFAULT now(),
   ip_address        inet,
   source            text,
   detail            jsonb
);
COMMENT ON TABLE audit.event IS 'Universal audit event: who did what, when, to which object, and what changed.';

CREATE INDEX idx_audit_event_target ON audit.event(target_type, target_id);
CREATE INDEX idx_audit_event_type ON audit.event(event_type);
CREATE INDEX idx_audit_event_occurred ON audit.event(occurred_at);

CREATE TABLE audit.entity_change (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   entity_type       text NOT NULL,
   entity_id         uuid NOT NULL,
   change_type       text NOT NULL,             -- insert / update / delete / restore
   changed_at        timestamptz NOT NULL DEFAULT now(),
   changed_by        uuid REFERENCES identity.user_account(id),
   before            jsonb,
   after             jsonb
);
COMMENT ON TABLE audit.entity_change IS 'State changes to any entity.';

CREATE INDEX idx_audit_entity_change ON audit.entity_change(entity_type, entity_id);

CREATE TABLE audit.access (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   target_type       text NOT NULL,
   target_id         uuid NOT NULL,
   access_type       text NOT NULL,             -- view / export / print / copy
   accessed_at       timestamptz NOT NULL DEFAULT now(),
   accessed_by       uuid REFERENCES identity.user_account(id),
   ip_address        inet,
   detail            jsonb
);
COMMENT ON TABLE audit.access IS 'Who viewed what.';

CREATE INDEX idx_audit_access_target ON audit.access(target_type, target_id);

CREATE TABLE audit.authentication (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   user_account_id   uuid REFERENCES identity.user_account(id),
   event_type        text NOT NULL,             -- login_success / login_failure / logout / password_change
   occurred_at       timestamptz NOT NULL DEFAULT now(),
   ip_address        inet,
   user_agent        text,
   detail            jsonb
);
COMMENT ON TABLE audit.authentication IS 'Login/logout events.';

CREATE TABLE audit.configuration_change (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   configuration_id  uuid NOT NULL REFERENCES configuration.configuration(id),
   scope_code        text,
   changed_at        timestamptz NOT NULL DEFAULT now(),
   changed_by        uuid REFERENCES identity.user_account(id),
   before            jsonb,
   after             jsonb
);
COMMENT ON TABLE audit.configuration_change IS 'History of configuration changes.';

CREATE TABLE audit.clinical_decision (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid REFERENCES patient.patient(id),
   encounter_id      uuid REFERENCES encounter.encounter(id),
   engine_id         text,
   decision_type     text NOT NULL,             -- differential / investigation / prescription / referral
   summary           text,
   payload           jsonb,
   decided_at        timestamptz NOT NULL DEFAULT now(),
   decided_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE audit.clinical_decision IS 'Every clinical decision, human or engine-made.';

CREATE INDEX idx_audit_decision_patient ON audit.clinical_decision(patient_id);

CREATE TABLE audit.order_decision (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id          uuid NOT NULL REFERENCES clinical.order(id),
   decision          text NOT NULL,             -- accepted / modified / rejected / suspended
   decided_at        timestamptz NOT NULL DEFAULT now(),
   decided_by        uuid REFERENCES identity.user_account(id),
   reason            text,
   detail            jsonb
);
COMMENT ON TABLE audit.order_decision IS 'Acceptance/modification/rejection of orders.';

CREATE TABLE audit.document_change (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id),
   document_version_id uuid REFERENCES document.document_version(id),
   change_type       text NOT NULL,             -- created / edited / signed / voided
   changed_at        timestamptz NOT NULL DEFAULT now(),
   changed_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE audit.document_change IS 'Document history.';

CREATE TABLE audit.data_export (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   exported_by       uuid REFERENCES identity.user_account(id),
   export_type       text NOT NULL,
   record_count      integer,
   started_at        timestamptz NOT NULL DEFAULT now(),
   completed_at      timestamptz,
   detail            jsonb
);
COMMENT ON TABLE audit.data_export IS 'Records of data exports.';

CREATE TABLE audit.integration_event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   direction         text NOT NULL,             -- inbound / outbound
   system_id         uuid,                      -- FK to interoperability.system added later
   message_id        text,
   status            text NOT NULL DEFAULT 'received',
   occurred_at       timestamptz NOT NULL DEFAULT now(),
   detail            jsonb
);
COMMENT ON TABLE audit.integration_event IS 'External exchange events.';

-- =============================================================================
-- INTEROPERABILITY
-- =============================================================================

CREATE TABLE interoperability.system (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   system_type       text,                      -- emr / lis / pacs / pharmacy / national / insurance / nhif
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE interoperability.system IS 'An external system AMEXAN talks to.';

-- audit.integration_event depends on interoperability.system, added after creation
ALTER TABLE audit.integration_event
   ADD CONSTRAINT fk_audit_integration_system FOREIGN KEY (system_id)
   REFERENCES interoperability.system(id);

CREATE TABLE interoperability.endpoint (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   system_id         uuid NOT NULL REFERENCES interoperability.system(id),
   name              text NOT NULL,
   base_url          text,
   auth_type         text,                      -- none / bearer / basic / oauth2 / api_key
   credential_ref    text,                      -- pointer to stored credentials, never plaintext here
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE interoperability.endpoint IS 'A connectable endpoint of an external system.';

CREATE TRIGGER trg_interop_endpoint_updated_at
   BEFORE UPDATE ON interoperability.endpoint
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE interoperability.connection (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   endpoint_id       uuid NOT NULL REFERENCES interoperability.endpoint(id),
   status            text NOT NULL DEFAULT 'disconnected',
   connected_at      timestamptz,
   last_error        text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE interoperability.connection IS 'Live connection state to an endpoint.';

CREATE TABLE interoperability.message (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   direction         text NOT NULL,             -- inbound / outbound
   system_id         uuid REFERENCES interoperability.system(id),
   endpoint_id       uuid REFERENCES interoperability.endpoint(id),
   message_type      text NOT NULL,             -- fhir / hl7v2 / json / csv
   external_message_id text,
   payload           jsonb,
   status            text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','sent','received','acknowledged','failed','error')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE interoperability.message IS 'A message exchanged with an external system.';

CREATE INDEX idx_interop_message_status ON interoperability.message(status);
CREATE TRIGGER trg_interop_message_updated_at
   BEFORE UPDATE ON interoperability.message
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE interoperability.message_event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   message_id        uuid NOT NULL REFERENCES interoperability.message(id) ON DELETE CASCADE,
   event_type        text NOT NULL,             -- sent / received / ack / retry / failed
   event_at          timestamptz NOT NULL DEFAULT now(),
   detail            jsonb
);
COMMENT ON TABLE interoperability.message_event IS 'Lifecycle of an interoperability message.';

CREATE TABLE interoperability.mapping (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   source_system_id  uuid REFERENCES interoperability.system(id),
   target_system_id  uuid REFERENCES interoperability.system(id),
   source_resource   text NOT NULL,
   target_resource   text NOT NULL,
   field_mappings    jsonb NOT NULL,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE interoperability.mapping IS 'Field-level mapping between systems.';

CREATE TRIGGER trg_interop_mapping_updated_at
   BEFORE UPDATE ON interoperability.mapping
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE interoperability.identifier_map (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   system_id         uuid REFERENCES interoperability.system(id),
   source_type       text NOT NULL,
   source_id         text NOT NULL,
   target_type       text NOT NULL,
   target_id         text NOT NULL,
   created_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (system_id, source_type, source_id, target_type, target_id)
);
COMMENT ON TABLE interoperability.identifier_map IS 'Cross-system identifier mappings (AMEXAN MRN <-> external ID).';

CREATE TABLE interoperability.fhir_resource (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   resource_type     text NOT NULL,             -- Patient / Encounter / Observation / ...
   resource_id       uuid,
   fhir_json         jsonb NOT NULL,
   system_id         uuid REFERENCES interoperability.system(id),
   version           text,
   synced_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE interoperability.fhir_resource IS 'FHIR representation of AMEXAN resources.';

CREATE INDEX idx_fhir_resource_type ON interoperability.fhir_resource(resource_type);

CREATE TABLE interoperability.import_job (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   system_id         uuid REFERENCES interoperability.system(id),
   job_type          text NOT NULL,
   status            text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','running','completed','failed')),
   started_at        timestamptz,
   completed_at      timestamptz,
   record_count      integer,
   error             text,
   detail            jsonb
);
COMMENT ON TABLE interoperability.import_job IS 'Import jobs from external systems.';

CREATE TABLE interoperability.export_job (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   system_id         uuid REFERENCES interoperability.system(id),
   job_type          text NOT NULL,
   status            text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','running','completed','failed')),
   started_at        timestamptz,
   completed_at      timestamptz,
   record_count      integer,
   error             text,
   detail            jsonb
);
COMMENT ON TABLE interoperability.export_job IS 'Export jobs to external systems.';

-- =============================================================================
-- COMMUNICATION
-- =============================================================================

CREATE TABLE communication.thread (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   subject           text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   created_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE communication.thread IS 'A conversation thread.';

CREATE TABLE communication.message (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   thread_id         uuid REFERENCES communication.thread(id),
   sender_type       text NOT NULL,             -- user / system / api_client / patient
   sender_id         uuid,
   message_type      text NOT NULL DEFAULT 'text' CHECK (message_type IN ('text','image','file','structured')),
   body              text,
   payload           jsonb,
   sent_at           timestamptz NOT NULL DEFAULT now(),
   status            text NOT NULL DEFAULT 'sent'
                     CHECK (status IN ('sent','delivered','read','failed','deleted'))
);
COMMENT ON TABLE communication.message IS 'A message.';

CREATE INDEX idx_communication_thread ON communication.message(thread_id);

CREATE TABLE communication.recipient (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   message_id        uuid NOT NULL REFERENCES communication.message(id) ON DELETE CASCADE,
   recipient_type    text NOT NULL,             -- person / professional / user / group
   recipient_id      uuid NOT NULL,
   role              text,
   delivered_at      timestamptz,
   read_at           timestamptz
);
COMMENT ON TABLE communication.recipient IS 'Recipients of a message.';

CREATE TABLE communication.notification (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   recipient_type    text NOT NULL,
   recipient_id      uuid NOT NULL,
   notification_type text NOT NULL,             -- appointment_reminder / result_ready / message / alert
   title             text NOT NULL,
   body              text,
   data              jsonb,
   status            text NOT NULL DEFAULT 'queued'
                     CHECK (status IN ('queued','sent','delivered','read','failed')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   sent_at           timestamptz,
   read_at           timestamptz
);
COMMENT ON TABLE communication.notification IS 'A notification to a person/app.';

CREATE INDEX idx_notification_recipient ON communication.notification(recipient_type, recipient_id);

CREATE TABLE communication.template (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   template_type     text NOT NULL,             -- sms / email / push / in_app
   subject           text,
   body              text NOT NULL,
   language_code     text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE communication.template IS 'Message templates.';

CREATE TRIGGER trg_communication_template_updated_at
   BEFORE UPDATE ON communication.template
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE communication.delivery (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   message_id        uuid REFERENCES communication.message(id),
   notification_id   uuid REFERENCES communication.notification(id),
   channel           text NOT NULL,             -- sms / email / push / in_app / whatsapp
   provider          text,
   status            text NOT NULL DEFAULT 'queued'
                     CHECK (status IN ('queued','sent','delivered','failed')),
   attempted_at      timestamptz,
   sent_at           timestamptz,
   error             text
);
COMMENT ON TABLE communication.delivery IS 'Delivery attempt of a message/notification over a channel.';

CREATE TABLE communication.preference (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   channel           text NOT NULL,             -- sms / email / push / app
   category          text NOT NULL DEFAULT 'general',   -- reminders / results / alerts / marketing
   opt_in            boolean NOT NULL DEFAULT true,
   UNIQUE (person_id, channel, category)
);
COMMENT ON TABLE communication.preference IS 'Opt-in/opt-out per channel and category.';

CREATE TABLE communication.consent (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   person_id         uuid NOT NULL REFERENCES identity.person(id) ON DELETE CASCADE,
   consent_type      text NOT NULL,             -- sms / email / promotional / clinical_update / research
   decision          text NOT NULL CHECK (decision IN ('granted','denied','withdrawn')),
   granted_at        timestamptz,
   revoked_at        timestamptz,
   UNIQUE (person_id, consent_type)
);
COMMENT ON TABLE communication.consent IS 'Consent to be contacted in specific ways.';
