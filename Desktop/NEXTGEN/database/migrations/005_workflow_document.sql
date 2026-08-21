-- =============================================================================
-- AMEXAN Phase 1 — Migration 005: workflow + scheduling + document
-- =============================================================================
-- Universal operational infrastructure.
--
-- WORKFLOW:
--   definitions → versions → states → transitions → instances → tasks/queues
--
-- SCHEDULING:
--   schedules → slots → appointments → participants/reasons/check-in
--
-- DOCUMENT:
--   documents → immutable versions → sections/sources/authors/attachments/
--   signatures/templates/exports
--
-- PRINCIPLE:
--   Clinical facts and observations remain the source of truth.
--   Workflow, scheduling and documents are operational/projection layers.
-- =============================================================================


-- =============================================================================
-- SCHEMAS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS scheduling;
CREATE SCHEMA IF NOT EXISTS document;

COMMENT ON SCHEMA workflow IS
'Workflow definitions, states, transitions, instances, tasks and queues.';

COMMENT ON SCHEMA scheduling IS
'Schedules, slots, appointments, waitlists and patient check-in.';

COMMENT ON SCHEMA document IS
'Clinical documents and immutable document projections generated from source state.';


-- =============================================================================
-- WORKFLOW
-- =============================================================================

CREATE TABLE workflow.definition (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                text NOT NULL UNIQUE,
    name                text NOT NULL,
    description         text,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE workflow.definition IS
'A named AMEXAN workflow process.';


CREATE TRIGGER trg_workflow_definition_updated_at
    BEFORE UPDATE ON workflow.definition
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE workflow.version (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    definition_id       uuid NOT NULL
                        REFERENCES workflow.definition(id)
                        ON DELETE CASCADE,
    version             integer NOT NULL CHECK (version > 0),
    state_machine       jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_active           boolean NOT NULL DEFAULT false,
    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (definition_id, version)
);

COMMENT ON TABLE workflow.version IS
'Versioned machine-readable definition of a workflow.';


CREATE UNIQUE INDEX uq_workflow_active_version
    ON workflow.version(definition_id)
    WHERE is_active = true;


CREATE TABLE workflow.state (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                text NOT NULL UNIQUE,
    label               text NOT NULL,
    state_kind          text NOT NULL DEFAULT 'middle'
                        CHECK (state_kind IN ('start', 'middle', 'end')),
    description         text
);

COMMENT ON TABLE workflow.state IS
'A reusable state within a workflow state machine.';


CREATE TABLE workflow.transition (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_version_id uuid NOT NULL
                        REFERENCES workflow.version(id)
                        ON DELETE CASCADE,
    from_state_id       uuid NOT NULL
                        REFERENCES workflow.state(id),
    to_state_id         uuid NOT NULL
                        REFERENCES workflow.state(id),
    name                text NOT NULL,
    guard               jsonb NOT NULL DEFAULT '{}'::jsonb,

    CHECK (from_state_id <> to_state_id)
);

COMMENT ON TABLE workflow.transition IS
'A permitted transition between workflow states.';


CREATE INDEX idx_workflow_transition_version
    ON workflow.transition(workflow_version_id);

CREATE INDEX idx_workflow_transition_from
    ON workflow.transition(from_state_id);

CREATE INDEX idx_workflow_transition_to
    ON workflow.transition(to_state_id);


CREATE TABLE workflow.instance (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_version_id  uuid NOT NULL
                         REFERENCES workflow.version(id),
    entity_type          text NOT NULL,
    entity_id            uuid NOT NULL,
    current_state_id     uuid REFERENCES workflow.state(id),
    status               text NOT NULL DEFAULT 'running'
                         CHECK (status IN (
                             'running',
                             'completed',
                             'cancelled',
                             'error'
                         )),
    data                 jsonb NOT NULL DEFAULT '{}'::jsonb,
    started_at           timestamptz NOT NULL DEFAULT now(),
    ended_at             timestamptz,
    created_by           uuid REFERENCES identity.user_account(id),

    CHECK (
        (status = 'running' AND ended_at IS NULL)
        OR
        (status <> 'running')
    )
);

COMMENT ON TABLE workflow.instance IS
'A running or completed instance of a workflow against a domain entity.';


CREATE INDEX idx_workflow_instance_entity
    ON workflow.instance(entity_type, entity_id);

CREATE INDEX idx_workflow_instance_status
    ON workflow.instance(status);

CREATE INDEX idx_workflow_instance_state
    ON workflow.instance(current_state_id);


CREATE TABLE workflow.instance_event (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id          uuid NOT NULL
                         REFERENCES workflow.instance(id)
                         ON DELETE CASCADE,
    event_type            text NOT NULL,
    from_state_id         uuid REFERENCES workflow.state(id),
    to_state_id           uuid REFERENCES workflow.state(id),
    event_at              timestamptz NOT NULL DEFAULT now(),
    event_by              uuid REFERENCES identity.user_account(id),
    detail                jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE workflow.instance_event IS
'Immutable lifecycle history of a workflow instance.';


CREATE INDEX idx_workflow_instance_event_instance
    ON workflow.instance_event(instance_id);

CREATE INDEX idx_workflow_instance_event_time
    ON workflow.instance_event(event_at);


CREATE TABLE workflow.task (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id          uuid
                         REFERENCES workflow.instance(id)
                         ON DELETE CASCADE,
    task_type             text NOT NULL,
    name                  text NOT NULL,
    description           text,
    data                  jsonb NOT NULL DEFAULT '{}'::jsonb,
    status                text NOT NULL DEFAULT 'pending'
                          CHECK (status IN (
                              'pending',
                              'assigned',
                              'in_progress',
                              'completed',
                              'cancelled'
                          )),
    priority              integer NOT NULL DEFAULT 0,
    due_at                timestamptz,
    created_at            timestamptz NOT NULL DEFAULT now(),
    completed_at          timestamptz,

    CHECK (
        (status = 'completed' AND completed_at IS NOT NULL)
        OR
        (status <> 'completed')
    )
);

COMMENT ON TABLE workflow.task IS
'A unit of operational work produced by a workflow.';


CREATE INDEX idx_workflow_task_instance
    ON workflow.task(instance_id);

CREATE INDEX idx_workflow_task_status
    ON workflow.task(status);

CREATE INDEX idx_workflow_task_due
    ON workflow.task(due_at)
    WHERE status NOT IN ('completed', 'cancelled');


CREATE TABLE workflow.task_assignment (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id              uuid NOT NULL
                         REFERENCES workflow.task(id)
                         ON DELETE CASCADE,
    assignee_type        text NOT NULL
                         CHECK (assignee_type IN (
                             'user',
                             'professional',
                             'role',
                             'team',
                             'queue'
                         )),
    assignee_id          uuid NOT NULL,
    assigned_at          timestamptz NOT NULL DEFAULT now(),
    assigned_by          uuid REFERENCES identity.user_account(id),
    status               text NOT NULL DEFAULT 'assigned'
                         CHECK (status IN (
                             'assigned',
                             'accepted',
                             'declined',
                             'completed',
                             'cancelled'
                         ))
);

COMMENT ON TABLE workflow.task_assignment IS
'Assignment of a workflow task to a user, professional, role, team or queue.';


CREATE INDEX idx_workflow_task_assignment_task
    ON workflow.task_assignment(task_id);

CREATE INDEX idx_workflow_task_assignment_assignee
    ON workflow.task_assignment(assignee_type, assignee_id);


CREATE TABLE workflow.task_event (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id              uuid NOT NULL
                         REFERENCES workflow.task(id)
                         ON DELETE CASCADE,
    event_type            text NOT NULL,
    event_at              timestamptz NOT NULL DEFAULT now(),
    event_by              uuid REFERENCES identity.user_account(id),
    detail                jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE workflow.task_event IS
'Immutable lifecycle history for a workflow task.';


CREATE INDEX idx_workflow_task_event_task
    ON workflow.task_event(task_id);

CREATE INDEX idx_workflow_task_event_time
    ON workflow.task_event(event_at);


CREATE TABLE workflow.queue (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                 text NOT NULL UNIQUE,
    name                 text NOT NULL,
    description          text,
    facility_id          uuid REFERENCES organization.facility(id),
    department_id        uuid REFERENCES organization.department(id),
    is_active            boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE workflow.queue IS
'A facility or department work queue.';


CREATE INDEX idx_workflow_queue_facility
    ON workflow.queue(facility_id);

CREATE INDEX idx_workflow_queue_department
    ON workflow.queue(department_id);


CREATE TABLE workflow.queue_item (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    queue_id              uuid NOT NULL
                          REFERENCES workflow.queue(id)
                          ON DELETE CASCADE,
    workflow_instance_id  uuid
                          REFERENCES workflow.instance(id)
                          ON DELETE SET NULL,
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    priority               integer NOT NULL DEFAULT 0,
    status                 text NOT NULL DEFAULT 'waiting'
                           CHECK (status IN (
                               'waiting',
                               'served',
                               'removed'
                           )),
    entered_at             timestamptz NOT NULL DEFAULT now(),
    exited_at              timestamptz,

    CHECK (
        (status = 'waiting' AND exited_at IS NULL)
        OR
        (status <> 'waiting')
    )
);

COMMENT ON TABLE workflow.queue_item IS
'An entity waiting for service in an operational queue.';


CREATE INDEX idx_workflow_queue_item_queue
    ON workflow.queue_item(queue_id);

CREATE INDEX idx_workflow_queue_item_entity
    ON workflow.queue_item(entity_type, entity_id);

CREATE INDEX idx_workflow_queue_item_waiting
    ON workflow.queue_item(queue_id, priority DESC, entered_at)
    WHERE status = 'waiting';


-- =============================================================================
-- SCHEDULING
-- =============================================================================

CREATE TABLE scheduling.schedule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name                text NOT NULL,
    facility_id         uuid REFERENCES organization.facility(id),
    department_id       uuid REFERENCES organization.department(id),
    clinic_id           uuid REFERENCES organization.clinic(id),
    professional_id     uuid REFERENCES organization.professional(id),
    schedule_type       text NOT NULL,
    valid_from          date,
    valid_to            date,
    timezone             text NOT NULL DEFAULT 'Africa/Nairobi',
    is_active            boolean NOT NULL DEFAULT true,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),

    CHECK (
        valid_to IS NULL
        OR valid_from IS NULL
        OR valid_to >= valid_from
    )
);

COMMENT ON TABLE scheduling.schedule IS
'A recurring availability definition for a clinical or operational resource.';


CREATE INDEX idx_scheduling_schedule_professional
    ON scheduling.schedule(professional_id);

CREATE INDEX idx_scheduling_schedule_facility
    ON scheduling.schedule(facility_id);

CREATE INDEX idx_scheduling_schedule_clinic
    ON scheduling.schedule(clinic_id);


CREATE TRIGGER trg_scheduling_schedule_updated_at
    BEFORE UPDATE ON scheduling.schedule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE scheduling.schedule_slot (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id         uuid NOT NULL
                        REFERENCES scheduling.schedule(id)
                        ON DELETE CASCADE,
    start_time          timestamptz NOT NULL,
    end_time            timestamptz NOT NULL,
    duration_minutes    integer NOT NULL CHECK (duration_minutes > 0),
    status              text NOT NULL DEFAULT 'available'
                        CHECK (status IN (
                            'available',
                            'blocked',
                            'booked',
                            'cancelled'
                        )),
    recurring            boolean NOT NULL DEFAULT false,
    recurring_rule       jsonb,

    CHECK (end_time > start_time)
);

COMMENT ON TABLE scheduling.schedule_slot IS
'An individual schedulable time slot.';


CREATE INDEX idx_scheduling_slot_start
    ON scheduling.schedule_slot(start_time);

CREATE INDEX idx_scheduling_slot_schedule
    ON scheduling.schedule_slot(schedule_id);

CREATE INDEX idx_scheduling_slot_available
    ON scheduling.schedule_slot(schedule_id, start_time)
    WHERE status = 'available';


CREATE TABLE scheduling.appointment (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,
    schedule_slot_id    uuid REFERENCES scheduling.schedule_slot(id),
    facility_id         uuid REFERENCES organization.facility(id),
    department_id       uuid REFERENCES organization.department(id),
    clinic_id           uuid REFERENCES organization.clinic(id),
    service_id          uuid REFERENCES organization.service(id),
    professional_id     uuid REFERENCES organization.professional(id),
    appointment_type    text,
    status              text NOT NULL DEFAULT 'scheduled'
                        CHECK (status IN (
                            'scheduled',
                            'confirmed',
                            'checked_in',
                            'in_progress',
                            'completed',
                            'cancelled',
                            'no_show',
                            'rescheduled'
                        )),
    start_time          timestamptz NOT NULL,
    end_time            timestamptz,
    notes               text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CHECK (
        end_time IS NULL
        OR end_time > start_time
    )
);

COMMENT ON TABLE scheduling.appointment IS
'A booked patient appointment.';


CREATE INDEX idx_scheduling_appointment_patient
    ON scheduling.appointment(patient_id);

CREATE INDEX idx_scheduling_appointment_start
    ON scheduling.appointment(start_time);

CREATE INDEX idx_scheduling_appointment_status
    ON scheduling.appointment(status);

CREATE INDEX idx_scheduling_appointment_professional
    ON scheduling.appointment(professional_id);

CREATE INDEX idx_scheduling_appointment_clinic
    ON scheduling.appointment(clinic_id);


CREATE TRIGGER trg_scheduling_appointment_updated_at
    BEFORE UPDATE ON scheduling.appointment
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE scheduling.appointment_participant (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      uuid NOT NULL
                        REFERENCES scheduling.appointment(id)
                        ON DELETE CASCADE,
    participant_type    text NOT NULL
                        CHECK (participant_type IN (
                            'patient',
                            'doctor',
                            'nurse',
                            'guardian',
                            'interpreter',
                            'other'
                        )),
    person_id           uuid REFERENCES identity.person(id),
    professional_id     uuid REFERENCES organization.professional(id),

    CHECK (
        person_id IS NOT NULL
        OR professional_id IS NOT NULL
    )
);

COMMENT ON TABLE scheduling.appointment_participant IS
'People participating in an appointment.';


CREATE INDEX idx_scheduling_appointment_participant
    ON scheduling.appointment_participant(appointment_id);


CREATE TABLE scheduling.appointment_reason (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      uuid NOT NULL
                        REFERENCES scheduling.appointment(id)
                        ON DELETE CASCADE,
    reason              text NOT NULL,
    concept_id          uuid REFERENCES terminology.concept(id)
);

COMMENT ON TABLE scheduling.appointment_reason IS
'Clinical or operational reason for an appointment.';


CREATE INDEX idx_scheduling_appointment_reason
    ON scheduling.appointment_reason(appointment_id);


CREATE TABLE scheduling.waitlist (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          uuid NOT NULL
                        REFERENCES patient.patient(id)
                        ON DELETE CASCADE,
    facility_id         uuid REFERENCES organization.facility(id),
    clinic_id           uuid REFERENCES organization.clinic(id),
    service_id          uuid REFERENCES organization.service(id),
    professional_id     uuid REFERENCES organization.professional(id),
    priority             integer NOT NULL DEFAULT 0,
    preferred_from      timestamptz,
    preferred_to        timestamptz,
    added_at             timestamptz NOT NULL DEFAULT now(),
    status               text NOT NULL DEFAULT 'active'
                        CHECK (status IN (
                            'active',
                            'called',
                            'fulfilled',
                            'removed'
                        )),
    notes                text,

    CHECK (
        preferred_to IS NULL
        OR preferred_from IS NULL
        OR preferred_to >= preferred_from
    )
);

COMMENT ON TABLE scheduling.waitlist IS
'Patients awaiting an appointment or service opening.';


CREATE INDEX idx_scheduling_waitlist_patient
    ON scheduling.waitlist(patient_id);

CREATE INDEX idx_scheduling_waitlist_active
    ON scheduling.waitlist(priority DESC, added_at)
    WHERE status = 'active';


CREATE TABLE scheduling.check_in (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      uuid NOT NULL
                        REFERENCES scheduling.appointment(id)
                        ON DELETE CASCADE,
    checked_in_at       timestamptz NOT NULL DEFAULT now(),
    checked_in_by       uuid REFERENCES identity.user_account(id),
    method              text
                        CHECK (method IN (
                            'counter',
                            'self_service',
                            'kiosk',
                            'mobile',
                            'other'
                        )),
    notes               text
);

COMMENT ON TABLE scheduling.check_in IS
'Patient arrival/check-in event for an appointment.';


CREATE INDEX idx_scheduling_check_in_appointment
    ON scheduling.check_in(appointment_id);

CREATE INDEX idx_scheduling_check_in_time
    ON scheduling.check_in(checked_in_at);


CREATE TABLE scheduling.no_show (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      uuid NOT NULL
                        REFERENCES scheduling.appointment(id)
                        ON DELETE CASCADE,
    recorded_at         timestamptz NOT NULL DEFAULT now(),
    recorded_by         uuid REFERENCES identity.user_account(id),
    reason              text
);

COMMENT ON TABLE scheduling.no_show IS
'Recorded missed appointment event.';


CREATE INDEX idx_scheduling_no_show_appointment
    ON scheduling.no_show(appointment_id);


CREATE TABLE scheduling.reschedule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      uuid NOT NULL
                        REFERENCES scheduling.appointment(id)
                        ON DELETE CASCADE,
    from_start          timestamptz NOT NULL,
    from_end            timestamptz,
    to_start            timestamptz NOT NULL,
    to_end              timestamptz,
    rescheduled_at      timestamptz NOT NULL DEFAULT now(),
    rescheduled_by      uuid REFERENCES identity.user_account(id),
    reason              text,

    CHECK (
        from_end IS NULL
        OR from_end > from_start
    ),

    CHECK (
        to_end IS NULL
        OR to_end > to_start
    )
);

COMMENT ON TABLE scheduling.reschedule IS
'Immutable history of appointment rescheduling.';


CREATE INDEX idx_scheduling_reschedule_appointment
    ON scheduling.reschedule(appointment_id);


-- =============================================================================
-- SCHEDULING EVENT HISTORY
-- =============================================================================

CREATE TABLE scheduling.appointment_event (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id      uuid NOT NULL
                        REFERENCES scheduling.appointment(id)
                        ON DELETE CASCADE,
    event_type          text NOT NULL,
    event_at            timestamptz NOT NULL DEFAULT now(),
    event_by            uuid REFERENCES identity.user_account(id),
    detail              jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE scheduling.appointment_event IS
'Immutable lifecycle history for an appointment.';


CREATE INDEX idx_scheduling_appointment_event_appointment
    ON scheduling.appointment_event(appointment_id);

CREATE INDEX idx_scheduling_appointment_event_time
    ON scheduling.appointment_event(event_at);


-- =============================================================================
-- DOCUMENT
-- =============================================================================

CREATE TABLE document.document_type (
    code                text PRIMARY KEY,
    label               text NOT NULL,
    description         text
);

COMMENT ON TABLE document.document_type IS
'HPI, consultation note, progress note, discharge summary, prescription, lab request, referral letter and other clinical document types.';


CREATE TABLE document.document (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          uuid REFERENCES patient.patient(id) ON DELETE CASCADE,
    encounter_id        uuid REFERENCES encounter.encounter(id),
    document_type_code  text NOT NULL
                        REFERENCES document.document_type(code),
    title               text NOT NULL,
    status               text NOT NULL DEFAULT 'draft'
                        CHECK (status IN (
                            'draft',
                            'final',
                            'amended',
                            'superseded',
                            'void'
                        )),
    current_version     integer NOT NULL DEFAULT 1
                        CHECK (current_version > 0),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    created_by           uuid REFERENCES identity.user_account(id)
);

COMMENT ON TABLE document.document IS
'Master document identity and lifecycle. Document content is stored in immutable versions.';


CREATE INDEX idx_document_patient
    ON document.document(patient_id);

CREATE INDEX idx_document_encounter
    ON document.document(encounter_id);

CREATE INDEX idx_document_type
    ON document.document(document_type_code);

CREATE INDEX idx_document_status
    ON document.document(status);


CREATE TRIGGER trg_document_updated_at
    BEFORE UPDATE ON document.document
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE document.document_version (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         uuid NOT NULL
                        REFERENCES document.document(id)
                        ON DELETE CASCADE,
    version             integer NOT NULL CHECK (version > 0),
    content             text,
    content_json        jsonb,
    created_at           timestamptz NOT NULL DEFAULT now(),
    created_by           uuid REFERENCES identity.user_account(id),

    CHECK (
        content IS NOT NULL
        OR content_json IS NOT NULL
    ),

    UNIQUE (document_id, version)
);

COMMENT ON TABLE document.document_version IS
'Immutable version of a document. Clinical source data remains authoritative.';


CREATE INDEX idx_document_version_document
    ON document.document_version(document_id);


CREATE TABLE document.document_section (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_version_id   uuid NOT NULL
                          REFERENCES document.document_version(id)
                          ON DELETE CASCADE,
    section_type          text NOT NULL,
    title                 text,
    content               text,
    sort_order            integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE document.document_section IS
'Structured sections within a document version.';


CREATE INDEX idx_document_section_version
    ON document.document_section(document_version_id);

CREATE INDEX idx_document_section_order
    ON document.document_section(document_version_id, sort_order);


CREATE TABLE document.document_source (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id           uuid NOT NULL
                          REFERENCES document.document(id)
                          ON DELETE CASCADE,
    source_type           text NOT NULL
                          CHECK (source_type IN (
                              'fact',
                              'observation',
                              'order',
                              'result',
                              'assessment',
                              'document',
                              'diagnosis',
                              'problem',
                              'plan',
                              'other'
                          )),
    source_entity_type    text,
    source_entity_id      uuid,
    detail                jsonb NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE document.document_source IS
'Provenance linking a document to the clinical state from which it was produced.';


CREATE INDEX idx_document_source_document
    ON document.document_source(document_id);

CREATE INDEX idx_document_source_entity
    ON document.document_source(source_entity_type, source_entity_id);


CREATE TABLE document.document_author (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         uuid NOT NULL
                        REFERENCES document.document(id)
                        ON DELETE CASCADE,
    professional_id     uuid NOT NULL
                        REFERENCES organization.professional(id),
    author_type         text NOT NULL DEFAULT 'author'
                        CHECK (author_type IN (
                            'author',
                            'co_author',
                            'editor',
                            'signer'
                        )),
    authored_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE document.document_author IS
'Professionals responsible for authoring, editing or signing a document.';


CREATE INDEX idx_document_author_document
    ON document.document_author(document_id);

CREATE INDEX idx_document_author_professional
    ON document.document_author(professional_id);


CREATE TABLE document.document_attachment (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         uuid NOT NULL
                        REFERENCES document.document(id)
                        ON DELETE CASCADE,
    file_name           text NOT NULL,
    mime_type            text NOT NULL,
    file_path            text,
    size_bytes           bigint CHECK (size_bytes IS NULL OR size_bytes >= 0),
    checksum             text,
    uploaded_at          timestamptz NOT NULL DEFAULT now(),
    uploaded_by          uuid REFERENCES identity.user_account(id)
);

COMMENT ON TABLE document.document_attachment IS
'External files attached to a document.';


CREATE INDEX idx_document_attachment_document
    ON document.document_attachment(document_id);


CREATE TABLE document.document_signature (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         uuid NOT NULL
                        REFERENCES document.document(id)
                        ON DELETE CASCADE,
    person_id           uuid NOT NULL
                        REFERENCES identity.person(id),
    professional_id     uuid REFERENCES organization.professional(id),
    signature_type      text NOT NULL
                        CHECK (signature_type IN (
                            'electronic',
                            'ink',
                            'digitized_handwritten'
                        )),
    signed_at            timestamptz NOT NULL DEFAULT now(),
    signature_data      text,
    is_valid             boolean NOT NULL DEFAULT true,
    invalidated_at       timestamptz,
    invalidated_by       uuid REFERENCES identity.user_account(id),

    CHECK (
        is_valid = true
        OR invalidated_at IS NOT NULL
    )
);

COMMENT ON TABLE document.document_signature IS
'Electronic or recorded signatures attached to documents.';


CREATE INDEX idx_document_signature_document
    ON document.document_signature(document_id);


CREATE TABLE document.document_template (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                text NOT NULL UNIQUE,
    name                text NOT NULL,
    document_type_code  text
                        REFERENCES document.document_type(code),
    template_type       text NOT NULL
                        CHECK (template_type IN (
                            'static',
                            'liquid',
                            'html',
                            'markdown'
                        )),
    content             text NOT NULL,
    is_active            boolean NOT NULL DEFAULT true,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE document.document_template IS
'Version-independent rendering template definitions.';


CREATE TRIGGER trg_document_template_updated_at
    BEFORE UPDATE ON document.document_template
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE document.document_export (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id         uuid NOT NULL
                        REFERENCES document.document(id)
                        ON DELETE CASCADE,
    export_type         text NOT NULL
                        CHECK (export_type IN (
                            'pdf',
                            'html',
                            'json',
                            'fhir',
                            'xml',
                            'other'
                        )),
    format              text,
    file_path           text,
    status               text NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                            'pending',
                            'processing',
                            'completed',
                            'failed'
                        )),
    exported_at         timestamptz NOT NULL DEFAULT now(),
    exported_by         uuid REFERENCES identity.user_account(id),
    error_detail        text
);

COMMENT ON TABLE document.document_export IS
'Generated document representations such as PDF, HTML, JSON or FHIR.';


CREATE INDEX idx_document_export_document
    ON document.document_export(document_id);

CREATE INDEX idx_document_export_status
    ON document.document_export(status);


-- =============================================================================
-- DOCUMENT VERSION IMMUTABILITY
-- =============================================================================

CREATE OR REPLACE FUNCTION document.prevent_document_version_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'document.document_version is immutable; create a new version instead';
END;
$$;


CREATE TRIGGER trg_document_version_immutable
    BEFORE UPDATE OR DELETE
    ON document.document_version
    FOR EACH ROW
    EXECUTE FUNCTION document.prevent_document_version_mutation();


CREATE OR REPLACE FUNCTION document.prevent_document_section_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'document.document_section is immutable; create a new document version instead';
END;
$$;


CREATE TRIGGER trg_document_section_immutable
    BEFORE UPDATE OR DELETE
    ON document.document_section
    FOR EACH ROW
    EXECUTE FUNCTION document.prevent_document_section_mutation();


-- =============================================================================
-- DOCUMENT VERSION / MASTER CONSISTENCY
-- =============================================================================

CREATE OR REPLACE FUNCTION document.sync_current_version()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE document.document
       SET current_version = GREATEST(current_version, NEW.version),
           updated_at = now()
     WHERE id = NEW.document_id;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_document_version_sync_current
    AFTER INSERT ON document.document_version
    FOR EACH ROW
    EXECUTE FUNCTION document.sync_current_version();


-- =============================================================================
-- APPOINTMENT / SLOT INTEGRITY
-- =============================================================================

CREATE OR REPLACE FUNCTION scheduling.validate_appointment_slot()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_slot_start timestamptz;
    v_slot_end   timestamptz;
    v_slot_status text;
BEGIN
    IF NEW.schedule_slot_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT
        start_time,
        end_time,
        status
    INTO
        v_slot_start,
        v_slot_end,
        v_slot_status
    FROM scheduling.schedule_slot
    WHERE id = NEW.schedule_slot_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Schedule slot % does not exist',
            NEW.schedule_slot_id;
    END IF;

    IF v_slot_status IN ('blocked', 'cancelled') THEN
        RAISE EXCEPTION
            'Schedule slot % is not bookable',
            NEW.schedule_slot_id;
    END IF;

    IF NEW.start_time <> v_slot_start THEN
        RAISE EXCEPTION
            'Appointment start time must match schedule slot start time';
    END IF;

    IF NEW.end_time IS NOT NULL
       AND NEW.end_time > v_slot_end THEN
        RAISE EXCEPTION
            'Appointment exceeds schedule slot';
    END IF;

    IF TG_OP = 'INSERT' THEN
        UPDATE scheduling.schedule_slot
           SET status = 'booked'
         WHERE id = NEW.schedule_slot_id
           AND status = 'available';

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Schedule slot % is no longer available',
                NEW.schedule_slot_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_appointment_slot
    BEFORE INSERT ON scheduling.appointment
    FOR EACH ROW
    EXECUTE FUNCTION scheduling.validate_appointment_slot();


-- =============================================================================
-- WORKFLOW STATE INTEGRITY
-- =============================================================================

CREATE OR REPLACE FUNCTION workflow.validate_instance_state()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists boolean;
BEGIN
    IF NEW.current_state_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM workflow.transition t
        WHERE t.workflow_version_id = NEW.workflow_version_id
          AND (
              t.from_state_id = NEW.current_state_id
              OR t.to_state_id = NEW.current_state_id
          )
    )
    INTO v_exists;

    IF NOT v_exists THEN
        SELECT EXISTS (
            SELECT 1
            FROM workflow.state s
            WHERE s.id = NEW.current_state_id
        )
        INTO v_exists;
    END IF;

    IF NOT v_exists THEN
        RAISE EXCEPTION
            'Workflow state % does not exist',
            NEW.current_state_id;
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validate_workflow_instance_state
    BEFORE INSERT OR UPDATE OF workflow_version_id, current_state_id
    ON workflow.instance
    FOR EACH ROW
    EXECUTE FUNCTION workflow.validate_instance_state();


-- =============================================================================
-- PERFORMANCE INDEXES
-- =============================================================================

CREATE INDEX idx_workflow_definition_active
    ON workflow.definition(is_active);

CREATE INDEX idx_workflow_version_active
    ON workflow.version(definition_id, is_active);

CREATE INDEX idx_workflow_instance_running
    ON workflow.instance(started_at)
    WHERE status = 'running';

CREATE INDEX idx_workflow_task_pending
    ON workflow.task(priority DESC, created_at)
    WHERE status IN ('pending', 'assigned', 'in_progress');


CREATE INDEX idx_scheduling_schedule_active
    ON scheduling.schedule(is_active);

CREATE INDEX idx_scheduling_slot_end
    ON scheduling.schedule_slot(end_time);

CREATE INDEX idx_scheduling_appointment_active
    ON scheduling.appointment(start_time)
    WHERE status IN (
        'scheduled',
        'confirmed',
        'checked_in',
        'in_progress'
    );


-- =============================================================================
-- COMMENTS — ARCHITECTURAL CONTRACT
-- =============================================================================

COMMENT ON TABLE workflow.instance IS
'Operational workflow projection over AMEXAN domain entities. Clinical truth remains in domain clinical tables.';

COMMENT ON TABLE scheduling.appointment IS
'Operational appointment record. It does not replace an encounter or clinical record.';

COMMENT ON TABLE document.document IS
'Human-readable clinical projection. It is not the authoritative source of clinical facts.';

COMMENT ON TABLE document.document_version IS
'Immutable rendering of clinical state at a point in time. Corrections create a new version.';


-- =============================================================================
-- END MIGRATION 005
-- =============================================================================