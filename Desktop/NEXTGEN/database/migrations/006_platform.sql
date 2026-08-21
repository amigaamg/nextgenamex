-- =============================================================================
-- AMEXAN Phase 1 — Migration 006: Platform Infrastructure
-- =============================================================================
-- Configuration, audit, interoperability, communication, and AMEXAN system
-- infrastructure.
--
-- Architectural principles:
--   1. Configuration is scoped, inheritable, versioned and auditable.
--   2. Audit records are append-oriented historical facts.
--   3. Interoperability is isolated from the clinical source of truth.
--   4. Communication is transport-oriented and does not own clinical facts.
--   5. System infrastructure describes AMEXAN itself.
--
-- Depends on:
--   Migration 001+:
--     public.set_updated_at()
--     identity.user_account
--     identity.person
--     organization.*
--     patient.patient
--     encounter.encounter
--     clinical.order
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- SCHEMAS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS configuration;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS interoperability;
CREATE SCHEMA IF NOT EXISTS communication;
CREATE SCHEMA IF NOT EXISTS system;

COMMENT ON SCHEMA configuration IS
'Scoped, inheritable and versioned AMEXAN configuration.';

COMMENT ON SCHEMA audit IS
'Append-oriented audit and accountability records.';

COMMENT ON SCHEMA interoperability IS
'External systems, endpoints, messages, mappings, imports, exports and FHIR projections.';

COMMENT ON SCHEMA communication IS
'Messages, recipients, notifications, templates, delivery and communication consent.';

COMMENT ON SCHEMA system IS
'AMEXAN platform topology: environments, instances, modules, services, engines, releases and jobs.';


-- =============================================================================
-- SYSTEM
-- =============================================================================

CREATE TABLE IF NOT EXISTS system.environment (
    code              text PRIMARY KEY,
    label             text NOT NULL,
    CHECK (btrim(code) <> ''),
    CHECK (btrim(label) <> '')
);

COMMENT ON TABLE system.environment IS
'Deployment environments such as development, staging and production.';


CREATE TABLE IF NOT EXISTS system.instance (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_name     text NOT NULL UNIQUE,
    environment_code  text NOT NULL REFERENCES system.environment(code),
    region            text,
    version           text,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(instance_name) <> '')
);

COMMENT ON TABLE system.instance IS
'An AMEXAN deployment instance.';


DROP TRIGGER IF EXISTS trg_system_instance_updated_at
ON system.instance;

CREATE TRIGGER trg_system_instance_updated_at
BEFORE UPDATE ON system.instance
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE IF NOT EXISTS system.module (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    version           text,
    description       text,
    is_active         boolean NOT NULL DEFAULT true,
    installed_at      timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE system.module IS
'Installed AMEXAN modules.';


CREATE TABLE IF NOT EXISTS system.service (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    service_type      text,
    status            text NOT NULL DEFAULT 'unknown'
                      CHECK (status IN ('unknown','healthy','degraded','down')),
    base_url          text,
    version           text,
    last_heartbeat    timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE system.service IS
'A backend service of the AMEXAN platform.';


DROP TRIGGER IF EXISTS trg_system_service_updated_at
ON system.service;

CREATE TRIGGER trg_system_service_updated_at
BEFORE UPDATE ON system.service
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_system_service_status
ON system.service(status);

CREATE INDEX IF NOT EXISTS idx_system_service_heartbeat
ON system.service(last_heartbeat);


CREATE TABLE IF NOT EXISTS system.engine (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    engine_type       text,
    description       text,
    status            text NOT NULL DEFAULT 'inactive'
                      CHECK (status IN (
                          'inactive',
                          'starting',
                          'active',
                          'degraded',
                          'failed',
                          'retired'
                      )),
    is_active         boolean NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE system.engine IS
'A registered AMEXAN engine such as Clinical CPU, Medication Engine or Safety Engine.';


DROP TRIGGER IF EXISTS trg_system_engine_updated_at
ON system.engine;

CREATE TRIGGER trg_system_engine_updated_at
BEFORE UPDATE ON system.engine
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_system_engine_active
ON system.engine(is_active);

CREATE INDEX IF NOT EXISTS idx_system_engine_status
ON system.engine(status);


CREATE TABLE IF NOT EXISTS system.engine_version (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    engine_id         uuid NOT NULL
                      REFERENCES system.engine(id)
                      ON DELETE CASCADE,
    version           text NOT NULL,
    changelog         text,
    is_active         boolean NOT NULL DEFAULT false,
    released_at       timestamptz NOT NULL DEFAULT now(),

    UNIQUE (engine_id, version),
    CHECK (btrim(version) <> '')
);

COMMENT ON TABLE system.engine_version IS
'Immutable released version metadata for an AMEXAN engine.';


CREATE UNIQUE INDEX IF NOT EXISTS uq_system_engine_one_active_version
ON system.engine_version(engine_id)
WHERE is_active = true;


CREATE TABLE IF NOT EXISTS system.feature_flag (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    description       text,
    enabled           boolean NOT NULL DEFAULT false,
    environment_code  text
                      REFERENCES system.environment(code),
    scope             jsonb,
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE system.feature_flag IS
'Controlled activation of platform features.';


DROP TRIGGER IF EXISTS trg_system_feature_flag_updated_at
ON system.feature_flag;

CREATE TRIGGER trg_system_feature_flag_updated_at
BEFORE UPDATE ON system.feature_flag
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_system_feature_flag_environment
ON system.feature_flag(environment_code);

CREATE INDEX IF NOT EXISTS idx_system_feature_flag_enabled
ON system.feature_flag(enabled);


CREATE TABLE IF NOT EXISTS system.release (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version           text NOT NULL UNIQUE,
    name              text,
    description       text,
    status            text NOT NULL DEFAULT 'planned'
                      CHECK (status IN (
                          'planned',
                          'testing',
                          'deployed',
                          'rolled_back'
                      )),
    released_at       timestamptz,

    CHECK (btrim(version) <> '')
);

COMMENT ON TABLE system.release IS
'AMEXAN platform release.';


CREATE TABLE IF NOT EXISTS system.release_change (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    release_id        uuid NOT NULL
                      REFERENCES system.release(id)
                      ON DELETE CASCADE,
    change_type       text NOT NULL
                      CHECK (change_type IN (
                          'feature',
                          'fix',
                          'migration',
                          'breaking',
                          'security',
                          'performance',
                          'documentation'
                      )),
    summary           text NOT NULL,
    change_ref        text,

    CHECK (btrim(summary) <> '')
);

COMMENT ON TABLE system.release_change IS
'Individual change included in an AMEXAN release.';


CREATE INDEX IF NOT EXISTS idx_system_release_change_release
ON system.release_change(release_id);


CREATE TABLE IF NOT EXISTS system.health_check (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_id        uuid REFERENCES system.service(id) ON DELETE SET NULL,
    status            text NOT NULL,
    latency_ms        integer,
    checked_at        timestamptz NOT NULL DEFAULT now(),
    detail            jsonb,

    CHECK (latency_ms IS NULL OR latency_ms >= 0)
);

COMMENT ON TABLE system.health_check IS
'Point-in-time service health snapshots.';


CREATE INDEX IF NOT EXISTS idx_system_health_service_time
ON system.health_check(service_id, checked_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_health_status
ON system.health_check(status);


CREATE TABLE IF NOT EXISTS system.job (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    schedule          text,
    handler           text,
    is_active         boolean NOT NULL DEFAULT true,
    last_run_at       timestamptz,

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE system.job IS
'Background job definition.';


CREATE TABLE IF NOT EXISTS system.job_execution (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id            uuid NOT NULL
                      REFERENCES system.job(id)
                      ON DELETE CASCADE,
    started_at        timestamptz NOT NULL DEFAULT now(),
    ended_at          timestamptz,
    status            text NOT NULL DEFAULT 'running'
                      CHECK (status IN (
                          'running',
                          'succeeded',
                          'failed',
                          'cancelled'
                      )),
    result            jsonb,
    error             text,

    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

COMMENT ON TABLE system.job_execution IS
'Execution history for a background job.';


CREATE INDEX IF NOT EXISTS idx_system_job_execution_job
ON system.job_execution(job_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_job_execution_status
ON system.job_execution(status);


CREATE TABLE IF NOT EXISTS system.event (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type        text NOT NULL,
    source            text,
    severity          text NOT NULL DEFAULT 'info'
                      CHECK (severity IN (
                          'debug',
                          'info',
                          'warning',
                          'error',
                          'critical'
                      )),
    event_at          timestamptz NOT NULL DEFAULT now(),
    payload           jsonb,

    CHECK (btrim(event_type) <> '')
);

COMMENT ON TABLE system.event IS
'Platform-level system event.';


CREATE INDEX IF NOT EXISTS idx_system_event_type_time
ON system.event(event_type, event_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_event_severity_time
ON system.event(severity, event_at DESC);


-- =============================================================================
-- CONFIGURATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS configuration.scope (
    code              text PRIMARY KEY,
    label             text NOT NULL,
    precedence        integer NOT NULL DEFAULT 0,

    CHECK (btrim(code) <> ''),
    CHECK (btrim(label) <> '')
);

COMMENT ON TABLE configuration.scope IS
'Configuration scopes such as global, country, organization, facility, department, clinic and clinician.';


CREATE TABLE IF NOT EXISTS configuration.configuration (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    key               text NOT NULL,
    name              text NOT NULL,
    description       text,
    data_type         text NOT NULL DEFAULT 'string'
                      CHECK (data_type IN (
                          'string',
                          'number',
                          'boolean',
                          'json',
                          'text'
                      )),
    default_value     jsonb,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(key) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE configuration.configuration IS
'A named configuration definition and its platform default value.';


DROP TRIGGER IF EXISTS trg_configuration_updated_at
ON configuration.configuration;

CREATE TRIGGER trg_configuration_updated_at
BEFORE UPDATE ON configuration.configuration
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_configuration_active
ON configuration.configuration(is_active);


CREATE TABLE IF NOT EXISTS configuration.configuration_version (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    configuration_id  uuid NOT NULL
                      REFERENCES configuration.configuration(id)
                      ON DELETE CASCADE,
    version           integer NOT NULL,
    value             jsonb NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    created_by        uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,

    UNIQUE (configuration_id, version),
    CHECK (version > 0)
);

COMMENT ON TABLE configuration.configuration_version IS
'Immutable versioned value of a configuration object.';


CREATE INDEX IF NOT EXISTS idx_configuration_version_configuration
ON configuration.configuration_version(configuration_id, version DESC);


CREATE TABLE IF NOT EXISTS configuration.override (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    configuration_id     uuid NOT NULL
                         REFERENCES configuration.configuration(id)
                         ON DELETE CASCADE,
    scope_code           text NOT NULL
                         REFERENCES configuration.scope(code),
    scope_entity_id      uuid,
    value                jsonb NOT NULL,
    override_version_id  uuid
                         REFERENCES configuration.configuration_version(id)
                         ON DELETE SET NULL,
    priority             integer NOT NULL DEFAULT 0,
    valid_from           timestamptz NOT NULL DEFAULT now(),
    valid_to             timestamptz,
    created_at           timestamptz NOT NULL DEFAULT now(),

    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

COMMENT ON TABLE configuration.override IS
'A scoped configuration override.';


CREATE INDEX IF NOT EXISTS idx_config_override_lookup
ON configuration.override(
    configuration_id,
    scope_code,
    scope_entity_id,
    priority DESC,
    valid_from DESC
);

CREATE INDEX IF NOT EXISTS idx_config_override_active_window
ON configuration.override(
    configuration_id,
    scope_code,
    scope_entity_id,
    valid_from,
    valid_to
);


CREATE TABLE IF NOT EXISTS configuration.inheritance (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_code        text NOT NULL
                      REFERENCES configuration.scope(code)
                      ON DELETE CASCADE,
    parent_scope_code text NOT NULL
                      REFERENCES configuration.scope(code)
                      ON DELETE CASCADE,
    precedence        integer NOT NULL DEFAULT 0,

    UNIQUE (scope_code, parent_scope_code),
    CHECK (scope_code <> parent_scope_code)
);

COMMENT ON TABLE configuration.inheritance IS
'Configuration hierarchy, for example clinician <- clinic <- department <- facility <- organization <- country <- global.';


CREATE INDEX IF NOT EXISTS idx_configuration_inheritance_parent
ON configuration.inheritance(parent_scope_code);


CREATE TABLE IF NOT EXISTS configuration.activation (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    configuration_id  uuid NOT NULL
                      REFERENCES configuration.configuration(id)
                      ON DELETE CASCADE,
    active_version_id uuid NOT NULL
                      REFERENCES configuration.configuration_version(id),
    scope_code        text
                      REFERENCES configuration.scope(code),
    scope_entity_id   uuid,
    activated_at      timestamptz NOT NULL DEFAULT now(),
    activated_by      uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL
);

COMMENT ON TABLE configuration.activation IS
'Currently active configuration version for a scope.';


-- NULL scope is the global activation.
CREATE UNIQUE INDEX IF NOT EXISTS uq_configuration_activation_global
ON configuration.activation(configuration_id)
WHERE scope_code IS NULL AND scope_entity_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_configuration_activation_scoped
ON configuration.activation(
    configuration_id,
    scope_code,
    scope_entity_id
)
WHERE scope_code IS NOT NULL;


CREATE INDEX IF NOT EXISTS idx_configuration_activation_scope
ON configuration.activation(scope_code, scope_entity_id);


CREATE TABLE IF NOT EXISTS configuration.test_case (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    configuration_id  uuid NOT NULL
                      REFERENCES configuration.configuration(id)
                      ON DELETE CASCADE,
    name              text NOT NULL,
    input             jsonb,
    expected          jsonb,
    created_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE configuration.test_case IS
'Test input and expected output for validating configuration behavior.';


CREATE INDEX IF NOT EXISTS idx_configuration_test_case_configuration
ON configuration.test_case(configuration_id);


CREATE TABLE IF NOT EXISTS configuration.test_result (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    test_case_id      uuid NOT NULL
                      REFERENCES configuration.test_case(id)
                      ON DELETE CASCADE,
    executed_at       timestamptz NOT NULL DEFAULT now(),
    passed            boolean NOT NULL,
    actual            jsonb,
    error             text
);

COMMENT ON TABLE configuration.test_result IS
'Result of executing a configuration test case.';


CREATE INDEX IF NOT EXISTS idx_configuration_test_result_case
ON configuration.test_result(test_case_id, executed_at DESC);


-- =============================================================================
-- AUDIT
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit.event (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type        text NOT NULL,
    actor_type        text NOT NULL,
    actor_id          uuid,
    action            text NOT NULL,
    target_type       text,
    target_id         uuid,
    occurred_at       timestamptz NOT NULL DEFAULT now(),
    ip_address        inet,
    source            text,
    detail            jsonb,

    CHECK (actor_type IN ('user','system','api_client','service')),
    CHECK (btrim(event_type) <> ''),
    CHECK (btrim(action) <> '')
);

COMMENT ON TABLE audit.event IS
'Universal accountability event: who did what, when, to which object and with what details.';


CREATE INDEX IF NOT EXISTS idx_audit_event_target
ON audit.event(target_type, target_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_event_type
ON audit.event(event_type, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_event_actor
ON audit.event(actor_type, actor_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_event_occurred
ON audit.event(occurred_at DESC);


CREATE TABLE IF NOT EXISTS audit.entity_change (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type       text NOT NULL,
    entity_id         uuid NOT NULL,
    change_type       text NOT NULL
                      CHECK (change_type IN (
                          'insert',
                          'update',
                          'delete',
                          'restore'
                      )),
    changed_at        timestamptz NOT NULL DEFAULT now(),
    changed_by        uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,
    before            jsonb,
    after             jsonb
);

COMMENT ON TABLE audit.entity_change IS
'State transition history for an entity.';


CREATE INDEX IF NOT EXISTS idx_audit_entity_change_entity
ON audit.entity_change(entity_type, entity_id, changed_at DESC);


CREATE TABLE IF NOT EXISTS audit.access (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    target_type       text NOT NULL,
    target_id         uuid NOT NULL,
    access_type       text NOT NULL
                      CHECK (access_type IN (
                          'view',
                          'export',
                          'print',
                          'copy',
                          'download',
                          'share'
                      )),
    accessed_at       timestamptz NOT NULL DEFAULT now(),
    accessed_by       uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,
    ip_address        inet,
    detail            jsonb
);

COMMENT ON TABLE audit.access IS
'Access history for protected AMEXAN resources.';


CREATE INDEX IF NOT EXISTS idx_audit_access_target
ON audit.access(target_type, target_id, accessed_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_access_actor
ON audit.access(accessed_by, accessed_at DESC);


CREATE TABLE IF NOT EXISTS audit.authentication (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id   uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,
    event_type        text NOT NULL
                      CHECK (event_type IN (
                          'login_success',
                          'login_failure',
                          'logout',
                          'password_change',
                          'password_reset',
                          'session_revoked',
                          'mfa_success',
                          'mfa_failure'
                      )),
    occurred_at       timestamptz NOT NULL DEFAULT now(),
    ip_address        inet,
    user_agent        text,
    detail            jsonb
);

COMMENT ON TABLE audit.authentication IS
'Authentication and session security events.';


CREATE INDEX IF NOT EXISTS idx_audit_auth_user_time
ON audit.authentication(user_account_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_auth_event_time
ON audit.authentication(event_type, occurred_at DESC);


CREATE TABLE IF NOT EXISTS audit.configuration_change (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    configuration_id  uuid NOT NULL
                      REFERENCES configuration.configuration(id),
    scope_code        text,
    scope_entity_id   uuid,
    changed_at        timestamptz NOT NULL DEFAULT now(),
    changed_by        uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,
    before            jsonb,
    after             jsonb
);

COMMENT ON TABLE audit.configuration_change IS
'Historical changes to configuration and scoped overrides.';


CREATE INDEX IF NOT EXISTS idx_audit_configuration_change_configuration
ON audit.configuration_change(
    configuration_id,
    changed_at DESC
);

CREATE INDEX IF NOT EXISTS idx_audit_configuration_change_scope
ON audit.configuration_change(scope_code, scope_entity_id, changed_at DESC);


CREATE TABLE IF NOT EXISTS audit.clinical_decision (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id        uuid
                      REFERENCES patient.patient(id)
                      ON DELETE SET NULL,
    encounter_id      uuid
                      REFERENCES encounter.encounter(id)
                      ON DELETE SET NULL,
    engine_id         uuid
                      REFERENCES system.engine(id)
                      ON DELETE SET NULL,
    decision_type     text NOT NULL,
    summary           text,
    payload           jsonb,
    decided_at        timestamptz NOT NULL DEFAULT now(),
    decided_by        uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,

    CHECK (btrim(decision_type) <> '')
);

COMMENT ON TABLE audit.clinical_decision IS
'Traceable record of a clinical decision produced by a human or AMEXAN engine.';


CREATE INDEX IF NOT EXISTS idx_audit_decision_patient
ON audit.clinical_decision(patient_id, decided_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_decision_encounter
ON audit.clinical_decision(encounter_id, decided_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_decision_engine
ON audit.clinical_decision(engine_id, decided_at DESC);


CREATE TABLE IF NOT EXISTS audit.order_decision (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id          uuid NOT NULL
                      REFERENCES clinical.order(id)
                      ON DELETE CASCADE,
    decision          text NOT NULL
                      CHECK (decision IN (
                          'accepted',
                          'modified',
                          'rejected',
                          'suspended',
                          'cancelled'
                      )),
    decided_at        timestamptz NOT NULL DEFAULT now(),
    decided_by        uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,
    reason            text,
    detail            jsonb
);

COMMENT ON TABLE audit.order_decision IS
'Acceptance, modification, rejection or suspension of a clinical order.';


CREATE INDEX IF NOT EXISTS idx_audit_order_decision_order
ON audit.order_decision(order_id, decided_at DESC);


CREATE TABLE IF NOT EXISTS audit.document_change (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         uuid NOT NULL
                        REFERENCES document.document(id)
                        ON DELETE CASCADE,
    document_version_id uuid
                        REFERENCES document.document_version(id)
                        ON DELETE SET NULL,
    change_type         text NOT NULL
                        CHECK (change_type IN (
                            'created',
                            'edited',
                            'signed',
                            'amended',
                            'voided',
                            'superseded',
                            'exported'
                        )),
    changed_at          timestamptz NOT NULL DEFAULT now(),
    changed_by          uuid
                        REFERENCES identity.user_account(id)
                        ON DELETE SET NULL
);

COMMENT ON TABLE audit.document_change IS
'Document lifecycle history.';


CREATE INDEX IF NOT EXISTS idx_audit_document_change_document
ON audit.document_change(document_id, changed_at DESC);


CREATE TABLE IF NOT EXISTS audit.data_export (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    exported_by       uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL,
    export_type       text NOT NULL,
    record_count      integer,
    started_at        timestamptz NOT NULL DEFAULT now(),
    completed_at      timestamptz,
    detail            jsonb,

    CHECK (record_count IS NULL OR record_count >= 0),
    CHECK (completed_at IS NULL OR completed_at >= started_at)
);

COMMENT ON TABLE audit.data_export IS
'Accountability record for data exports.';


CREATE INDEX IF NOT EXISTS idx_audit_data_export_time
ON audit.data_export(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_data_export_actor
ON audit.data_export(exported_by, started_at DESC);


CREATE TABLE IF NOT EXISTS audit.integration_event (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    direction         text NOT NULL
                      CHECK (direction IN ('inbound','outbound')),
    system_id         uuid,
    message_id        text,
    status            text NOT NULL DEFAULT 'received',
    occurred_at       timestamptz NOT NULL DEFAULT now(),
    detail            jsonb
);

COMMENT ON TABLE audit.integration_event IS
'Historical external-system exchange event.';


-- =============================================================================
-- INTEROPERABILITY
-- =============================================================================

CREATE TABLE IF NOT EXISTS interoperability.system (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    system_type       text,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> '')
);

COMMENT ON TABLE interoperability.system IS
'An external system AMEXAN communicates with.';


CREATE INDEX IF NOT EXISTS idx_interop_system_type
ON interoperability.system(system_type);

CREATE INDEX IF NOT EXISTS idx_interop_system_active
ON interoperability.system(is_active);


ALTER TABLE audit.integration_event
DROP CONSTRAINT IF EXISTS fk_audit_integration_system;

ALTER TABLE audit.integration_event
ADD CONSTRAINT fk_audit_integration_system
FOREIGN KEY (system_id)
REFERENCES interoperability.system(id)
ON DELETE SET NULL;


CREATE INDEX IF NOT EXISTS idx_audit_integration_system_time
ON audit.integration_event(system_id, occurred_at DESC);


CREATE TABLE IF NOT EXISTS interoperability.endpoint (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id         uuid NOT NULL
                      REFERENCES interoperability.system(id)
                      ON DELETE CASCADE,
    name              text NOT NULL,
    base_url          text,
    auth_type         text,
    credential_ref    text,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(name) <> ''),
    CHECK (
        auth_type IS NULL OR auth_type IN (
            'none',
            'bearer',
            'basic',
            'oauth2',
            'api_key',
            'm_tls'
        )
    )
);

COMMENT ON TABLE interoperability.endpoint IS
'A connectable endpoint belonging to an external system.';


DROP TRIGGER IF EXISTS trg_interop_endpoint_updated_at
ON interoperability.endpoint;

CREATE TRIGGER trg_interop_endpoint_updated_at
BEFORE UPDATE ON interoperability.endpoint
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_interop_endpoint_system
ON interoperability.endpoint(system_id);

CREATE INDEX IF NOT EXISTS idx_interop_endpoint_active
ON interoperability.endpoint(is_active);


CREATE TABLE IF NOT EXISTS interoperability.connection (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint_id       uuid NOT NULL
                      REFERENCES interoperability.endpoint(id)
                      ON DELETE CASCADE,
    status            text NOT NULL DEFAULT 'disconnected'
                      CHECK (status IN (
                          'disconnected',
                          'connecting',
                          'connected',
                          'degraded',
                          'failed'
                      )),
    connected_at      timestamptz,
    last_error        text,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE interoperability.connection IS
'Current connection state for an interoperability endpoint.';


DROP TRIGGER IF EXISTS trg_interop_connection_updated_at
ON interoperability.connection;

CREATE TRIGGER trg_interop_connection_updated_at
BEFORE UPDATE ON interoperability.connection
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_interop_connection_endpoint
ON interoperability.connection(endpoint_id);

CREATE INDEX IF NOT EXISTS idx_interop_connection_status
ON interoperability.connection(status);


CREATE TABLE IF NOT EXISTS interoperability.message (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    direction             text NOT NULL
                          CHECK (direction IN ('inbound','outbound')),
    system_id             uuid
                          REFERENCES interoperability.system(id)
                          ON DELETE SET NULL,
    endpoint_id           uuid
                          REFERENCES interoperability.endpoint(id)
                          ON DELETE SET NULL,
    message_type          text NOT NULL,
    external_message_id   text,
    payload               jsonb,
    status                text NOT NULL DEFAULT 'pending'
                          CHECK (status IN (
                              'pending',
                              'queued',
                              'sent',
                              'received',
                              'acknowledged',
                              'retrying',
                              'failed',
                              'error'
                          )),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE interoperability.message IS
'A message exchanged with an external system.';


DROP TRIGGER IF EXISTS trg_interop_message_updated_at
ON interoperability.message;

CREATE TRIGGER trg_interop_message_updated_at
BEFORE UPDATE ON interoperability.message
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_interop_message_status
ON interoperability.message(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_interop_message_system
ON interoperability.message(system_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_interop_message_external_id
ON interoperability.message(system_id, external_message_id);


CREATE TABLE IF NOT EXISTS interoperability.message_event (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id        uuid NOT NULL
                      REFERENCES interoperability.message(id)
                      ON DELETE CASCADE,
    event_type        text NOT NULL,
    event_at          timestamptz NOT NULL DEFAULT now(),
    detail            jsonb
);

COMMENT ON TABLE interoperability.message_event IS
'Lifecycle history for an interoperability message.';


CREATE INDEX IF NOT EXISTS idx_interop_message_event_message
ON interoperability.message_event(message_id, event_at DESC);


CREATE TABLE IF NOT EXISTS interoperability.mapping (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_system_id  uuid
                      REFERENCES interoperability.system(id)
                      ON DELETE CASCADE,
    target_system_id  uuid
                      REFERENCES interoperability.system(id)
                      ON DELETE CASCADE,
    source_resource   text NOT NULL,
    target_resource   text NOT NULL,
    field_mappings    jsonb NOT NULL,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(source_resource) <> ''),
    CHECK (btrim(target_resource) <> '')
);

COMMENT ON TABLE interoperability.mapping IS
'Field-level mapping between AMEXAN and external resources.';


DROP TRIGGER IF EXISTS trg_interop_mapping_updated_at
ON interoperability.mapping;

CREATE TRIGGER trg_interop_mapping_updated_at
BEFORE UPDATE ON interoperability.mapping
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_interop_mapping_source
ON interoperability.mapping(
    source_system_id,
    source_resource
);

CREATE INDEX IF NOT EXISTS idx_interop_mapping_target
ON interoperability.mapping(
    target_system_id,
    target_resource
);


CREATE TABLE IF NOT EXISTS interoperability.identifier_map (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id         uuid
                      REFERENCES interoperability.system(id)
                      ON DELETE CASCADE,
    source_type       text NOT NULL,
    source_id         text NOT NULL,
    target_type       text NOT NULL,
    target_id         text NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        system_id,
        source_type,
        source_id,
        target_type,
        target_id
    )
);

COMMENT ON TABLE interoperability.identifier_map IS
'Cross-system identifiers such as AMEXAN MRN to external patient identifiers.';


CREATE INDEX IF NOT EXISTS idx_interop_identifier_source
ON interoperability.identifier_map(
    system_id,
    source_type,
    source_id
);

CREATE INDEX IF NOT EXISTS idx_interop_identifier_target
ON interoperability.identifier_map(
    system_id,
    target_type,
    target_id
);


CREATE TABLE IF NOT EXISTS interoperability.fhir_resource (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_type     text NOT NULL,
    resource_id       uuid,
    fhir_json         jsonb NOT NULL,
    system_id         uuid
                      REFERENCES interoperability.system(id)
                      ON DELETE SET NULL,
    version           text,
    synced_at         timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(resource_type) <> '')
);

COMMENT ON TABLE interoperability.fhir_resource IS
'FHIR projection of an AMEXAN resource; not the primary clinical source of truth.';


CREATE INDEX IF NOT EXISTS idx_fhir_resource_type
ON interoperability.fhir_resource(resource_type);

CREATE INDEX IF NOT EXISTS idx_fhir_resource_resource
ON interoperability.fhir_resource(resource_type, resource_id);

CREATE INDEX IF NOT EXISTS idx_fhir_resource_system
ON interoperability.fhir_resource(system_id);


CREATE TABLE IF NOT EXISTS interoperability.import_job (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id         uuid
                      REFERENCES interoperability.system(id)
                      ON DELETE SET NULL,
    job_type          text NOT NULL,
    status            text NOT NULL DEFAULT 'pending'
                      CHECK (status IN (
                          'pending',
                          'running',
                          'completed',
                          'failed',
                          'cancelled'
                      )),
    started_at        timestamptz,
    completed_at      timestamptz,
    record_count      integer,
    error             text,
    detail            jsonb,

    CHECK (record_count IS NULL OR record_count >= 0),
    CHECK (
        completed_at IS NULL
        OR started_at IS NULL
        OR completed_at >= started_at
    )
);

COMMENT ON TABLE interoperability.import_job IS
'Import operation from an external system.';


CREATE INDEX IF NOT EXISTS idx_interop_import_job_system
ON interoperability.import_job(system_id);

CREATE INDEX IF NOT EXISTS idx_interop_import_job_status
ON interoperability.import_job(status);


CREATE TABLE IF NOT EXISTS interoperability.export_job (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id         uuid
                      REFERENCES interoperability.system(id)
                      ON DELETE SET NULL,
    job_type          text NOT NULL,
    status            text NOT NULL DEFAULT 'pending'
                      CHECK (status IN (
                          'pending',
                          'running',
                          'completed',
                          'failed',
                          'cancelled'
                      )),
    started_at        timestamptz,
    completed_at      timestamptz,
    record_count      integer,
    error             text,
    detail            jsonb,

    CHECK (record_count IS NULL OR record_count >= 0),
    CHECK (
        completed_at IS NULL
        OR started_at IS NULL
        OR completed_at >= started_at
    )
);

COMMENT ON TABLE interoperability.export_job IS
'Export operation to an external system.';


CREATE INDEX IF NOT EXISTS idx_interop_export_job_system
ON interoperability.export_job(system_id);

CREATE INDEX IF NOT EXISTS idx_interop_export_job_status
ON interoperability.export_job(status);


-- =============================================================================
-- COMMUNICATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS communication.thread (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject           text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    created_by        uuid
                      REFERENCES identity.user_account(id)
                      ON DELETE SET NULL
);

COMMENT ON TABLE communication.thread IS
'A communication conversation thread.';


CREATE INDEX IF NOT EXISTS idx_communication_thread_created
ON communication.thread(created_at DESC);


CREATE TABLE IF NOT EXISTS communication.message (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id         uuid
                      REFERENCES communication.thread(id)
                      ON DELETE SET NULL,
    sender_type       text NOT NULL,
    sender_id         uuid,
    message_type      text NOT NULL DEFAULT 'text'
                      CHECK (message_type IN (
                          'text',
                          'image',
                          'file',
                          'structured',
                          'system'
                      )),
    body              text,
    payload           jsonb,
    sent_at           timestamptz NOT NULL DEFAULT now(),
    status            text NOT NULL DEFAULT 'sent'
                      CHECK (status IN (
                          'sent',
                          'delivered',
                          'read',
                          'failed',
                          'deleted'
                      )),

    CHECK (
        body IS NOT NULL
        OR payload IS NOT NULL
    )
);

COMMENT ON TABLE communication.message IS
'A communication message; clinical facts remain owned by clinical domains.';


CREATE INDEX IF NOT EXISTS idx_communication_message_thread
ON communication.message(thread_id, sent_at);

CREATE INDEX IF NOT EXISTS idx_communication_message_sender
ON communication.message(sender_type, sender_id, sent_at DESC);


CREATE TABLE IF NOT EXISTS communication.recipient (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id        uuid NOT NULL
                      REFERENCES communication.message(id)
                      ON DELETE CASCADE,
    recipient_type    text NOT NULL,
    recipient_id      uuid NOT NULL,
    role              text,
    delivered_at      timestamptz,
    read_at           timestamptz,

    CHECK (read_at IS NULL OR delivered_at IS NULL OR read_at >= delivered_at)
);

COMMENT ON TABLE communication.recipient IS
'Recipient and delivery/read state for a communication message.';


CREATE INDEX IF NOT EXISTS idx_communication_recipient_message
ON communication.recipient(message_id);

CREATE INDEX IF NOT EXISTS idx_communication_recipient_target
ON communication.recipient(recipient_type, recipient_id);


CREATE TABLE IF NOT EXISTS communication.notification (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_type    text NOT NULL,
    recipient_id      uuid NOT NULL,
    notification_type text NOT NULL,
    title             text NOT NULL,
    body              text,
    data              jsonb,
    status            text NOT NULL DEFAULT 'queued'
                      CHECK (status IN (
                          'queued',
                          'sent',
                          'delivered',
                          'read',
                          'failed'
                      )),
    created_at        timestamptz NOT NULL DEFAULT now(),
    sent_at           timestamptz,
    read_at           timestamptz,

    CHECK (btrim(title) <> ''),
    CHECK (read_at IS NULL OR sent_at IS NULL OR read_at >= sent_at)
);

COMMENT ON TABLE communication.notification IS
'A notification addressed to a person or application identity.';


CREATE INDEX IF NOT EXISTS idx_notification_recipient
ON communication.notification(
    recipient_type,
    recipient_id,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_notification_status
ON communication.notification(status, created_at);


CREATE TABLE IF NOT EXISTS communication.template (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    template_type     text NOT NULL
                      CHECK (template_type IN (
                          'sms',
                          'email',
                          'push',
                          'in_app',
                          'whatsapp'
                      )),
    subject           text,
    body              text NOT NULL,
    language_code     text,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (btrim(code) <> ''),
    CHECK (btrim(name) <> ''),
    CHECK (btrim(body) <> '')
);

COMMENT ON TABLE communication.template IS
'Reusable communication template.';


DROP TRIGGER IF EXISTS trg_communication_template_updated_at
ON communication.template;

CREATE TRIGGER trg_communication_template_updated_at
BEFORE UPDATE ON communication.template
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


CREATE INDEX IF NOT EXISTS idx_communication_template_type_active
ON communication.template(template_type, is_active);


CREATE TABLE IF NOT EXISTS communication.delivery (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id        uuid
                      REFERENCES communication.message(id)
                      ON DELETE CASCADE,
    notification_id   uuid
                      REFERENCES communication.notification(id)
                      ON DELETE CASCADE,
    channel           text NOT NULL
                      CHECK (channel IN (
                          'sms',
                          'email',
                          'push',
                          'in_app',
                          'whatsapp'
                      )),
    provider          text,
    status            text NOT NULL DEFAULT 'queued'
                      CHECK (status IN (
                          'queued',
                          'sending',
                          'sent',
                          'delivered',
                          'failed'
                      )),
    attempted_at      timestamptz,
    sent_at           timestamptz,
    error             text,

    CHECK (
        message_id IS NOT NULL
        OR notification_id IS NOT NULL
    )
);

COMMENT ON TABLE communication.delivery IS
'Delivery attempt for a message or notification over a communication channel.';


CREATE INDEX IF NOT EXISTS idx_communication_delivery_message
ON communication.delivery(message_id);

CREATE INDEX IF NOT EXISTS idx_communication_delivery_notification
ON communication.delivery(notification_id);

CREATE INDEX IF NOT EXISTS idx_communication_delivery_status
ON communication.delivery(status, attempted_at);


CREATE TABLE IF NOT EXISTS communication.preference (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id         uuid NOT NULL
                      REFERENCES identity.person(id)
                      ON DELETE CASCADE,
    channel           text NOT NULL
                      CHECK (channel IN (
                          'sms',
                          'email',
                          'push',
                          'app',
                          'whatsapp'
                      )),
    category          text NOT NULL DEFAULT 'general',
    opt_in            boolean NOT NULL DEFAULT true,

    UNIQUE (person_id, channel, category)
);

COMMENT ON TABLE communication.preference IS
'Person-level communication channel and category preference.';


CREATE INDEX IF NOT EXISTS idx_communication_preference_person
ON communication.preference(person_id);


CREATE TABLE IF NOT EXISTS communication.consent (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id         uuid NOT NULL
                      REFERENCES identity.person(id)
                      ON DELETE CASCADE,
    consent_type      text NOT NULL,
    decision          text NOT NULL
                      CHECK (decision IN (
                          'granted',
                          'denied',
                          'withdrawn'
                      )),
    granted_at        timestamptz,
    revoked_at        timestamptz,

    UNIQUE (person_id, consent_type),

    CHECK (
        decision <> 'granted'
        OR granted_at IS NOT NULL
    ),

    CHECK (
        decision <> 'withdrawn'
        OR revoked_at IS NOT NULL
    ),

    CHECK (
        revoked_at IS NULL
        OR granted_at IS NULL
        OR revoked_at >= granted_at
    )
);

COMMENT ON TABLE communication.consent IS
'Person-level communication consent.';


CREATE INDEX IF NOT EXISTS idx_communication_consent_person
ON communication.consent(person_id);


-- =============================================================================
-- CROSS-DOMAIN INTEGRITY
-- =============================================================================

-- A delivery record must point to exactly one parent object.
CREATE OR REPLACE FUNCTION communication.enforce_delivery_parent()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.message_id IS NOT NULL
       AND NEW.notification_id IS NOT NULL THEN
        RAISE EXCEPTION
            'communication.delivery must reference either message_id or notification_id, not both';
    END IF;

    IF NEW.message_id IS NULL
       AND NEW.notification_id IS NULL THEN
        RAISE EXCEPTION
            'communication.delivery must reference message_id or notification_id';
    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_communication_delivery_parent
ON communication.delivery;

CREATE TRIGGER trg_communication_delivery_parent
BEFORE INSERT OR UPDATE ON communication.delivery
FOR EACH ROW
EXECUTE FUNCTION communication.enforce_delivery_parent();


-- =============================================================================
-- SEED CORE SYSTEM VALUES
-- =============================================================================

INSERT INTO system.environment (code, label)
VALUES
    ('development', 'Development'),
    ('staging',     'Staging'),
    ('production',  'Production')
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label;


INSERT INTO configuration.scope (code, label, precedence)
VALUES
    ('global',        'Global',        0),
    ('country',       'Country',      10),
    ('organization',  'Organization', 20),
    ('facility',      'Facility',     30),
    ('department',    'Department',   40),
    ('clinic',        'Clinic',       50),
    ('clinician',     'Clinician',    60)
ON CONFLICT (code) DO UPDATE
SET
    label = EXCLUDED.label,
    precedence = EXCLUDED.precedence;


INSERT INTO configuration.inheritance (
    scope_code,
    parent_scope_code,
    precedence
)
VALUES
    ('country',      'global',       10),
    ('organization', 'country',      20),
    ('facility',     'organization', 30),
    ('department',   'facility',     40),
    ('clinic',       'department',   50),
    ('clinician',    'clinic',       60)
ON CONFLICT (scope_code, parent_scope_code)
DO UPDATE SET precedence = EXCLUDED.precedence;


-- =============================================================================
-- PERFORMANCE / MAINTENANCE INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_system_event_payload_gin
ON system.event
USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_configuration_override_value_gin
ON configuration.override
USING gin (value);

CREATE INDEX IF NOT EXISTS idx_audit_event_detail_gin
ON audit.event
USING gin (detail);

CREATE INDEX IF NOT EXISTS idx_interop_message_payload_gin
ON interoperability.message
USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_interop_fhir_json_gin
ON interoperability.fhir_resource
USING gin (fhir_json);

CREATE INDEX IF NOT EXISTS idx_communication_message_payload_gin
ON communication.message
USING gin (payload);

CREATE INDEX IF NOT EXISTS idx_communication_notification_data_gin
ON communication.notification
USING gin (data);


-- =============================================================================
-- MIGRATION COMPLETION
-- =============================================================================

COMMIT;