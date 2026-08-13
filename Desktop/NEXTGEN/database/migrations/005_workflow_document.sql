-- =============================================================================
-- AMEXAN Phase 1 — Migration 005: workflow + scheduling + document
-- =============================================================================
-- How work moves (registration → triage → doctor → lab → pharmacy → discharge),
-- appointments and schedules, and documents as projections of clinical state.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS scheduling;
CREATE SCHEMA IF NOT EXISTS document;

COMMENT ON SCHEMA workflow IS 'Workflow definitions, states, transitions, tasks and queues.';
COMMENT ON SCHEMA scheduling IS 'Schedules, slots, appointments, waitlists, check-in.';
COMMENT ON SCHEMA document IS 'Documents as outputs of clinical state, not the source of truth.';

-- =============================================================================
-- WORKFLOW
-- =============================================================================

CREATE TABLE workflow.definition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,      -- e.g. outpatient_visit / inpatient_admission
   name              text NOT NULL,
   description       text,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE workflow.definition IS 'A named workflow (a process AMEXAN can run).';

CREATE TRIGGER trg_workflow_definition_updated_at
   BEFORE UPDATE ON workflow.definition
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE workflow.version (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   definition_id     uuid NOT NULL REFERENCES workflow.definition(id) ON DELETE CASCADE,
   version           integer NOT NULL,
   state_machine     jsonb,                    -- machine-readable definition of states/transitions
   is_active         boolean NOT NULL DEFAULT false,
   created_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (definition_id, version)
);
COMMENT ON TABLE workflow.version IS 'A versioned definition of a workflow.';

CREATE TABLE workflow.state (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,      -- e.g. registration / triage / assessment / discharge
   label             text NOT NULL,
   state_kind        text NOT NULL DEFAULT 'middle' CHECK (state_kind IN ('start','middle','end'))
);
COMMENT ON TABLE workflow.state IS 'A state an instance can be in.';

CREATE TABLE workflow.transition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   workflow_version_id uuid NOT NULL REFERENCES workflow.version(id) ON DELETE CASCADE,
   from_state_id     uuid NOT NULL REFERENCES workflow.state(id),
   to_state_id       uuid NOT NULL REFERENCES workflow.state(id),
   name              text NOT NULL,
   guard             jsonb                     -- conditions that must hold to take this transition
);
COMMENT ON TABLE workflow.transition IS 'A permitted transition between states in a workflow version.';

CREATE TABLE workflow.instance (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   workflow_version_id uuid NOT NULL REFERENCES workflow.version(id),
   entity_type       text NOT NULL,             -- encounter / admission / request / ...
   entity_id         uuid NOT NULL,
   current_state_id  uuid REFERENCES workflow.state(id),
   status            text NOT NULL DEFAULT 'running'
                     CHECK (status IN ('running','completed','cancelled','error')),
   data              jsonb,
   started_at        timestamptz NOT NULL DEFAULT now(),
   ended_at          timestamptz,
   created_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE workflow.instance IS 'A running instance of a workflow.';

CREATE INDEX idx_workflow_instance_entity ON workflow.instance(entity_type, entity_id);

CREATE TABLE workflow.task (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   instance_id       uuid REFERENCES workflow.instance(id) ON DELETE CASCADE,
   task_type         text NOT NULL,             -- e.g. triage / document / review / approve
   name              text NOT NULL,
   description       text,
   data              jsonb,
   status            text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','assigned','in_progress','completed','cancelled')),
   due_at            timestamptz,
   created_at        timestamptz NOT NULL DEFAULT now(),
   completed_at      timestamptz
);
COMMENT ON TABLE workflow.task IS 'A unit of work produced by a workflow instance.';

CREATE INDEX idx_task_instance ON workflow.task(instance_id);
CREATE INDEX idx_task_status ON workflow.task(status);

CREATE TABLE workflow.task_assignment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   task_id           uuid NOT NULL REFERENCES workflow.task(id) ON DELETE CASCADE,
   assignee_type     text NOT NULL,             -- user / professional / role / team / queue
   assignee_id       uuid NOT NULL,
   assigned_at       timestamptz NOT NULL DEFAULT now(),
   assigned_by       uuid REFERENCES identity.user_account(id),
   status            text NOT NULL DEFAULT 'assigned'
);
COMMENT ON TABLE workflow.task_assignment IS 'Who a task is assigned to.';

CREATE INDEX idx_task_assignment_task ON workflow.task_assignment(task_id);

CREATE TABLE workflow.task_event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   task_id           uuid NOT NULL REFERENCES workflow.task(id) ON DELETE CASCADE,
   event_type        text NOT NULL,             -- assigned / started / progressed / completed / escalated
   event_at          timestamptz NOT NULL DEFAULT now(),
   event_by          uuid REFERENCES identity.user_account(id),
   detail            jsonb
);
COMMENT ON TABLE workflow.task_event IS 'History of a task.';

CREATE INDEX idx_task_event_task ON workflow.task_event(task_id);

CREATE TABLE workflow.queue (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   description       text,
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   is_active         boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE workflow.queue IS 'A work queue (e.g. triage queue, lab queue).';

CREATE TABLE workflow.queue_item (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   queue_id          uuid NOT NULL REFERENCES workflow.queue(id) ON DELETE CASCADE,
   workflow_instance_id uuid REFERENCES workflow.instance(id),
   entity_type       text NOT NULL,
   entity_id         uuid NOT NULL,
   priority          integer NOT NULL DEFAULT 0,
   status            text NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting','served','removed')),
   entered_at        timestamptz NOT NULL DEFAULT now(),
   exited_at         timestamptz
);
COMMENT ON TABLE workflow.queue_item IS 'An item waiting in a queue.';

CREATE INDEX idx_queue_item_queue ON workflow.queue_item(queue_id);

-- =============================================================================
-- SCHEDULING
-- =============================================================================

CREATE TABLE scheduling.schedule (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   name              text NOT NULL,
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   professional_id   uuid REFERENCES organization.professional(id),
   schedule_type     text NOT NULL,             -- consultation / clinic / theatre / radiology / laboratory
   valid_from        date,
   valid_to          date,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE scheduling.schedule IS 'A repeating availability schedule for a resource.';

CREATE INDEX idx_schedule_professional ON scheduling.schedule(professional_id);
CREATE TRIGGER trg_schedule_updated_at
   BEFORE UPDATE ON scheduling.schedule
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE scheduling.schedule_slot (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   schedule_id       uuid NOT NULL REFERENCES scheduling.schedule(id) ON DELETE CASCADE,
   start_time        timestamptz NOT NULL,
   end_time          timestamptz NOT NULL,
   duration_minutes  integer NOT NULL,
   status            text NOT NULL DEFAULT 'available'
                     CHECK (status IN ('available','blocked','booked','cancelled')),
   recurring         boolean NOT NULL DEFAULT false,
   recurring_rule    jsonb,
   CHECK (end_time > start_time)
);
COMMENT ON TABLE scheduling.schedule_slot IS 'An individual bookable slot.';

CREATE INDEX idx_schedule_slot_start ON scheduling.schedule_slot(start_time);
CREATE INDEX idx_schedule_slot_schedule ON scheduling.schedule_slot(schedule_id);

CREATE TABLE scheduling.appointment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   schedule_slot_id  uuid REFERENCES scheduling.schedule_slot(id),
   facility_id       uuid REFERENCES organization.facility(id),
   department_id     uuid REFERENCES organization.department(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   service_id        uuid REFERENCES organization.service(id),
   professional_id   uuid REFERENCES organization.professional(id),
   appointment_type  text,                     -- initial / follow_up / procedure / consultation
   status            text NOT NULL DEFAULT 'scheduled'
                     CHECK (status IN ('scheduled','confirmed','checked_in','in_progress',
                                       'completed','cancelled','no_show','rescheduled')),
   start_time        timestamptz NOT NULL,
   end_time          timestamptz,
   notes             text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE scheduling.appointment IS 'A booked appointment.';

CREATE INDEX idx_appointment_patient ON scheduling.appointment(patient_id);
CREATE INDEX idx_appointment_start ON scheduling.appointment(start_time);
CREATE INDEX idx_appointment_status ON scheduling.appointment(status);
CREATE TRIGGER trg_appointment_updated_at
   BEFORE UPDATE ON scheduling.appointment
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE scheduling.appointment_participant (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   appointment_id    uuid NOT NULL REFERENCES scheduling.appointment(id) ON DELETE CASCADE,
   participant_type  text NOT NULL,             -- patient / doctor / nurse / guardian / interpreter
   person_id         uuid REFERENCES identity.person(id),
   professional_id   uuid REFERENCES organization.professional(id)
);
COMMENT ON TABLE scheduling.appointment_participant IS 'People involved in an appointment.';

CREATE TABLE scheduling.appointment_reason (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   appointment_id    uuid NOT NULL REFERENCES scheduling.appointment(id) ON DELETE CASCADE,
   reason            text NOT NULL,
   concept_id        uuid REFERENCES terminology.concept(id)
);
COMMENT ON TABLE scheduling.appointment_reason IS 'Why an appointment was booked.';

CREATE TABLE scheduling.waitlist (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   facility_id       uuid REFERENCES organization.facility(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   service_id        uuid REFERENCES organization.service(id),
   professional_id   uuid REFERENCES organization.professional(id),
   priority          integer NOT NULL DEFAULT 0,
   added_at          timestamptz NOT NULL DEFAULT now(),
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','called','fulfilled','removed')),
   notes             text
);
COMMENT ON TABLE scheduling.waitlist IS 'Waiting list for a clinic/service.';

CREATE TABLE scheduling.check_in (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   appointment_id    uuid NOT NULL REFERENCES scheduling.appointment(id) ON DELETE CASCADE,
   checked_in_at     timestamptz NOT NULL DEFAULT now(),
   checked_in_by     uuid REFERENCES identity.user_account(id),
   method            text,                     -- counter / self_service / kiosk
   notes             text
);
COMMENT ON TABLE scheduling.check_in IS 'Patient arrival for an appointment.';

CREATE TABLE scheduling.no_show (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   appointment_id    uuid NOT NULL REFERENCES scheduling.appointment(id) ON DELETE CASCADE,
   recorded_at       timestamptz NOT NULL DEFAULT now(),
   recorded_by       uuid REFERENCES identity.user_account(id),
   reason            text
);
COMMENT ON TABLE scheduling.no_show IS 'Recorded missed appointment.';

CREATE TABLE scheduling.reschedule (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   appointment_id    uuid NOT NULL REFERENCES scheduling.appointment(id) ON DELETE CASCADE,
   from_start        timestamptz NOT NULL,
   from_end          timestamptz,
   to_start          timestamptz NOT NULL,
   to_end            timestamptz,
   rescheduled_at    timestamptz NOT NULL DEFAULT now(),
   rescheduled_by    uuid REFERENCES identity.user_account(id),
   reason            text
);
COMMENT ON TABLE scheduling.reschedule IS 'Every rescheduling of an appointment.';

-- =============================================================================
-- DOCUMENT
-- =============================================================================

CREATE TABLE document.document_type (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE document.document_type IS 'HPI / consultation_note / progress_note / discharge_summary / prescription / lab_request / referral_letter.';

CREATE TABLE document.document (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   document_type_code text NOT NULL REFERENCES document.document_type(code),
   title             text NOT NULL,
   status            text NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','final','amended','superseded','void')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   created_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE document.document IS 'Master document record. Content lives in document_version.';

CREATE INDEX idx_document_patient ON document.document(patient_id);
CREATE INDEX idx_document_encounter ON document.document(encounter_id);
CREATE TRIGGER trg_document_updated_at
   BEFORE UPDATE ON document.document
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE document.document_version (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id) ON DELETE CASCADE,
   version           integer NOT NULL,
   content           text,                     -- rendered human-language document
   content_json      jsonb,                    -- structured representation
   created_at        timestamptz NOT NULL DEFAULT now(),
   created_by        uuid REFERENCES identity.user_account(id),
   UNIQUE (document_id, version)
);
COMMENT ON TABLE document.document_version IS 'An immutable version of a document. Facts produce documents, never the reverse.';

CREATE INDEX idx_document_version_document ON document.document_version(document_id);

CREATE TABLE document.document_section (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_version_id uuid NOT NULL REFERENCES document.document_version(id) ON DELETE CASCADE,
   section_type      text NOT NULL,             -- history / examination / assessment / plan / medication
   title             text,
   content           text,
   sort_order        integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE document.document_section IS 'Sections within a document version.';

CREATE TABLE document.document_source (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id) ON DELETE CASCADE,
   source_type       text NOT NULL,             -- fact / observation / order / result / assessment / document
   source_entity_type text,
   source_entity_id  uuid,
   detail            jsonb
);
COMMENT ON TABLE document.document_source IS 'Which facts/observations/orders produced the document.';

CREATE INDEX idx_document_source_document ON document.document_source(document_id);

CREATE TABLE document.document_author (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id) ON DELETE CASCADE,
   professional_id   uuid NOT NULL REFERENCES organization.professional(id),
   author_type       text NOT NULL DEFAULT 'author',   -- author / co_author / editor / signer
   authored_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE document.document_author IS 'Who wrote the document.';

CREATE TABLE document.document_attachment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id) ON DELETE CASCADE,
   file_name         text NOT NULL,
   mime_type         text NOT NULL,
   file_path         text,
   size_bytes        bigint,
   checksum          text,
   uploaded_at       timestamptz NOT NULL DEFAULT now(),
   uploaded_by       uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE document.document_attachment IS 'Attachments bound to a document.';

CREATE TABLE document.document_signature (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id) ON DELETE CASCADE,
   person_id         uuid NOT NULL REFERENCES identity.person(id),
   professional_id   uuid REFERENCES organization.professional(id),
   signature_type    text NOT NULL,             -- electronic / ink / digitized_handwritten
   signed_at         timestamptz NOT NULL DEFAULT now(),
   signature_data    text,
   is_valid          boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE document.document_signature IS 'Signatures on a document.';

CREATE TABLE document.document_template (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   code              text NOT NULL UNIQUE,
   name              text NOT NULL,
   document_type_code text REFERENCES document.document_type(code),
   template_type     text NOT NULL,             -- static / liquid / html / markdown
   content           text NOT NULL,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE document.document_template IS 'Templates used to render documents from clinical state.';

CREATE TRIGGER trg_document_template_updated_at
   BEFORE UPDATE ON document.document_template
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE document.document_export (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   document_id       uuid NOT NULL REFERENCES document.document(id) ON DELETE CASCADE,
   export_type       text NOT NULL,             -- pdf / html / json / fhir
   format            text,
   file_path         text,
   status            text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','failed')),
   exported_at       timestamptz NOT NULL DEFAULT now(),
   exported_by       uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE document.document_export IS 'Exports of a document (PDF, FHIR, ...).';
