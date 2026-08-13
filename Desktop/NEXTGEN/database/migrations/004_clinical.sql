-- =============================================================================
-- AMEXAN Phase 1 — Migration 004: clinical primitives
-- =============================================================================
-- The atomic fact system, observations, encounter-state, orders, care teams,
-- and clinical consent. NO disease-specific code. The knowledge layer (Phase 2)
-- teaches these primitives medicine.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS clinical;
COMMENT ON SCHEMA clinical IS 'Universal clinical primitives: facts, observations, problems, orders, care teams.';

-- =============================================================================
-- FACT SYSTEM — atomic, structured clinical facts (never text blobs)
-- =============================================================================

CREATE TABLE clinical.fact_status (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.fact_status IS 'entered / active / corrected / superseded / retracted.';

CREATE TABLE clinical.fact_definition (
   code              text PRIMARY KEY,
   name              text NOT NULL,
   description       text,
   data_type         text NOT NULL CHECK (data_type IN ('text','boolean','numeric','date','datetime','coded')),
   value_set_id      uuid REFERENCES terminology.value_set(id),
   concept_id        uuid REFERENCES terminology.concept(id),
   allow_multiple    boolean NOT NULL DEFAULT false,
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.fact_definition IS 'Defines a clinical fact (e.g. COUGH_PRODUCTIVITY, SMOKING_STATUS).';

CREATE TRIGGER trg_fact_definition_updated_at
   BEFORE UPDATE ON clinical.fact_definition
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.fact_unit (
   fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code) ON DELETE CASCADE,
   unit_code            text NOT NULL REFERENCES terminology.unit(code) ON DELETE CASCADE,
   is_default           boolean NOT NULL DEFAULT false,
   PRIMARY KEY (fact_definition_code, unit_code)
);
COMMENT ON TABLE clinical.fact_unit IS 'Units permitted for a fact definition.';

CREATE TABLE clinical.fact (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id          uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id        uuid REFERENCES encounter.encounter(id),
   fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
   status_code         text NOT NULL DEFAULT 'entered' REFERENCES clinical.fact_status(code),
   recorded_at         timestamptz NOT NULL DEFAULT now(),
   recorded_by         uuid REFERENCES identity.user_account(id),
   observed_at         timestamptz,
   notes               text,
   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.fact IS 'A patient-specific instance of a fact definition.';

CREATE INDEX idx_fact_patient ON clinical.fact(patient_id);
CREATE INDEX idx_fact_encounter ON clinical.fact(encounter_id);
CREATE INDEX idx_fact_definition ON clinical.fact(fact_definition_code);
CREATE TRIGGER trg_fact_updated_at
   BEFORE UPDATE ON clinical.fact
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.fact_value (
   id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   fact_id            uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   value_order        integer NOT NULL DEFAULT 0,
   data_type          text NOT NULL,
   value_text         text,
   value_numeric      numeric,
   value_boolean      boolean,
   value_date         date,
   value_datetime     timestamptz,
   value_concept_id   uuid REFERENCES terminology.concept(id),
   unit_code          text REFERENCES terminology.unit(code)
);
COMMENT ON TABLE clinical.fact_value IS 'Typed values for a fact. A fact may carry multiple ordered values.';

CREATE INDEX idx_fact_value_fact ON clinical.fact_value(fact_id);

CREATE TABLE clinical.fact_context (
   fact_id           uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   context_key       text NOT NULL,           -- age / sex / pregnancy / smoking / ...
   context_value     text NOT NULL,
   PRIMARY KEY (fact_id, context_key)
);
COMMENT ON TABLE clinical.fact_context IS 'Context in which a fact is true (age, sex, pregnancy, comorbidity...).';

CREATE TABLE clinical.fact_source (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   fact_id           uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   source_type       text NOT NULL,           -- patient_history / examination / device / document / external / engine
   source_ref        text,
   detail            jsonb,
   recorded_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.fact_source IS 'Provenance: where a fact came from.';

CREATE TABLE clinical.fact_confidence (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   fact_id           uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   confidence        numeric(4,3) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
   method            text,                    -- reported / measured / inferred / machine_estimate
   assessed_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.fact_confidence IS 'Confidence attached to a fact.';

CREATE TABLE clinical.fact_history (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   fact_id           uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   changed_at        timestamptz NOT NULL DEFAULT now(),
   changed_by        uuid REFERENCES identity.user_account(id),
   change_type       text NOT NULL,           -- created / corrected / superseded / retracted
   previous_snapshot jsonb,
   reason            text
);
COMMENT ON TABLE clinical.fact_history IS 'Full change history for every fact.';

CREATE INDEX idx_fact_history_fact ON clinical.fact_history(fact_id);

CREATE TABLE clinical.fact_relationship (
   source_fact_id    uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   target_fact_id    uuid NOT NULL REFERENCES clinical.fact(id) ON DELETE CASCADE,
   relationship      text NOT NULL,           -- supports / contradicts / implies / related_to
   PRIMARY KEY (source_fact_id, target_fact_id)
);
COMMENT ON TABLE clinical.fact_relationship IS 'Typed relationships between facts.';

CREATE TABLE clinical.fact_observation (
   fact_id           uuid PRIMARY KEY REFERENCES clinical.fact(id) ON DELETE CASCADE,
   effective_time    timestamptz,
   method            text,                    -- measured / self_reported / observed / reviewed
   observer_id       uuid REFERENCES organization.professional(id),
   is_abnormal       boolean,
   interpretation    text,
   device            text
);
COMMENT ON TABLE clinical.fact_observation IS 'Observation-specific metadata for a fact.';

-- =============================================================================
-- OBSERVATIONS
-- =============================================================================

CREATE TABLE clinical.observation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   observation_type  text NOT NULL,           -- measurement / vital_sign / physical_finding / symptom / functional / behavioral
   concept_id        uuid REFERENCES terminology.concept(id),
   status            text NOT NULL DEFAULT 'final'
                     CHECK (status IN ('preliminary','final','corrected','cancelled')),
   effective_time    timestamptz,
   recorded_at       timestamptz NOT NULL DEFAULT now(),
   recorded_by       uuid REFERENCES identity.user_account(id),
   note              text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.observation IS 'Generic observation container. Everything below specializes it.';

CREATE INDEX idx_observation_patient ON clinical.observation(patient_id);
CREATE INDEX idx_observation_encounter ON clinical.observation(encounter_id);
CREATE TRIGGER trg_observation_updated_at
   BEFORE UPDATE ON clinical.observation
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.measurement (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   observation_id    uuid NOT NULL REFERENCES clinical.observation(id) ON DELETE CASCADE,
   parameter_code    text NOT NULL,           -- e.g. SPO2 / TEMPERATURE / WEIGHT / HBA1C
   value_numeric     numeric,
   value_text        text,
   unit_code         text REFERENCES terminology.unit(code),
   low_threshold     numeric,
   high_threshold    numeric
);
COMMENT ON TABLE clinical.measurement IS 'A numeric/text measurement tied to an observation (SpO2 94 %).';

CREATE INDEX idx_measurement_observation ON clinical.measurement(observation_id);
CREATE INDEX idx_measurement_parameter ON clinical.measurement(parameter_code);

CREATE TABLE clinical.vital_sign (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   observation_id    uuid NOT NULL REFERENCES clinical.observation(id) ON DELETE CASCADE,
   parameter_code    text NOT NULL,           -- SBP / DBP / HR / RR / TEMP / SPO2 / WEIGHT / BMI
   value_numeric     numeric NOT NULL,
   unit_code         text REFERENCES terminology.unit(code),
   patient_position  text,                    -- sitting / lying / standing
   device            text
);
COMMENT ON TABLE clinical.vital_sign IS 'A vital sign measurement.';

CREATE INDEX idx_vital_sign_observation ON clinical.vital_sign(observation_id);
CREATE INDEX idx_vital_sign_parameter ON clinical.vital_sign(parameter_code);

CREATE TABLE clinical.physical_finding (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   observation_id    uuid NOT NULL REFERENCES clinical.observation(id) ON DELETE CASCADE,
   finding_code      text NOT NULL,           -- e.g. CREPITATIONS / JAUNDICE / RASH
   present           boolean NOT NULL DEFAULT true,
   laterality        text,                    -- left / right / bilateral / midline
   severity          text,
   description       text
);
COMMENT ON TABLE clinical.physical_finding IS 'An examination finding.';

CREATE TABLE clinical.symptom_report (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   observation_id    uuid NOT NULL REFERENCES clinical.observation(id) ON DELETE CASCADE,
   symptom_code      text NOT NULL,           -- e.g. COUGH / FEVER / DYSPNEA
   severity          text,                    -- mild / moderate / severe
   onset_date        date,
   duration_days     numeric,
   chronicity        text,                    -- acute / subacute / chronic
   description       text
);
COMMENT ON TABLE clinical.symptom_report IS 'A patient-reported symptom.';

CREATE TABLE clinical.functional_status (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   observation_id    uuid NOT NULL REFERENCES clinical.observation(id) ON DELETE CASCADE,
   domain            text NOT NULL,           -- mobility / self_care / cognition / communication
   score             numeric,
   scale_code        text,                    -- e.g. MRS / KATZ / ECOG
   description       text
);
COMMENT ON TABLE clinical.functional_status IS 'A functional assessment result.';

CREATE TABLE clinical.behavioral_observation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   observation_id    uuid NOT NULL REFERENCES clinical.observation(id) ON DELETE CASCADE,
   behavior_code     text NOT NULL,           -- e.g. aggression / confusion / alcohol_use
   description       text
);
COMMENT ON TABLE clinical.behavioral_observation IS 'A behavioral finding.';

-- =============================================================================
-- ENCOUNTER-STATE: assessment, problems, diagnoses, plans, disposition
-- =============================================================================

CREATE TABLE clinical.assessment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   assessment_type   text NOT NULL,           -- subjective / objective / assessment / plan / general
   concept_id        uuid REFERENCES terminology.concept(id),
   content           text NOT NULL,
   recorded_at       timestamptz NOT NULL DEFAULT now(),
   recorded_by       uuid REFERENCES identity.user_account(id),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.assessment IS 'A structured assessment entry within an encounter.';

CREATE INDEX idx_assessment_encounter ON clinical.assessment(encounter_id);
CREATE TRIGGER trg_assessment_updated_at
   BEFORE UPDATE ON clinical.assessment
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.problem_status (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.problem_status IS 'active / resolved / inactive / recurred / entered_in_error.';

CREATE TABLE clinical.problem (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   concept_id        uuid REFERENCES terminology.concept(id),
   label             text NOT NULL,
   status_code       text NOT NULL DEFAULT 'active' REFERENCES clinical.problem_status(code),
   is_chronic        boolean NOT NULL DEFAULT false,
   onset_date        date,
   resolved_date     date,
   added_by          uuid REFERENCES identity.user_account(id),
   added_at          timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.problem IS 'A clinical problem on the patient problem list.';

CREATE INDEX idx_problem_patient ON clinical.problem(patient_id);
CREATE INDEX idx_problem_status ON clinical.problem(status_code);
CREATE TRIGGER trg_problem_updated_at
   BEFORE UPDATE ON clinical.problem
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.diagnosis_status (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.diagnosis_status IS 'suspected / working / confirmed / final / ruled_out / entered_in_error.';

CREATE TABLE clinical.diagnosis (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   problem_id        uuid REFERENCES clinical.problem(id),
   concept_id        uuid REFERENCES terminology.concept(id),
   label             text NOT NULL,
   status_code       text NOT NULL DEFAULT 'working' REFERENCES clinical.diagnosis_status(code),
   diagnosis_type    text NOT NULL DEFAULT 'primary' CHECK (diagnosis_type IN ('primary','secondary','complication')),
   certainty         text,                    -- excluded / unlikely / possible / probable / confirmed
   diagnosed_on      date,
   diagnosed_by      uuid REFERENCES identity.user_account(id),
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.diagnosis IS 'A diagnosis with its certainty and status.';

CREATE INDEX idx_diagnosis_patient ON clinical.diagnosis(patient_id);
CREATE INDEX idx_diagnosis_encounter ON clinical.diagnosis(encounter_id);
CREATE TRIGGER trg_diagnosis_updated_at
   BEFORE UPDATE ON clinical.diagnosis
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.clinical_summary (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   summary_type      text NOT NULL,           -- discharge_summary / referral_summary / episode_summary / clinic_letter
   content           text,
   generated_at      timestamptz NOT NULL DEFAULT now(),
   generated_by      uuid REFERENCES identity.user_account(id),
   supersedes_id     uuid REFERENCES clinical.clinical_summary(id)
);
COMMENT ON TABLE clinical.clinical_summary IS 'A structured summary of clinical state at a point in time.';

CREATE TABLE clinical.plan (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   plan_type         text NOT NULL DEFAULT 'management',   -- management / discharge / admission / referral
   title             text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   created_by        uuid REFERENCES identity.user_account(id),
   is_active         boolean NOT NULL DEFAULT true,
   superseded_by     uuid REFERENCES clinical.plan(id)
);
COMMENT ON TABLE clinical.plan IS 'A clinical plan. The CPU will assemble plans in Phase 2; the structure is universal.';

CREATE INDEX idx_plan_patient ON clinical.plan(patient_id);

CREATE TABLE clinical.plan_item (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   plan_id           uuid NOT NULL REFERENCES clinical.plan(id) ON DELETE CASCADE,
   item_order        integer NOT NULL DEFAULT 0,
   action_type       text NOT NULL,           -- order / medication / procedure / referral / follow_up / education / observation
   description       text NOT NULL,
   related_order_id  uuid,                    -- FK added after clinical.order exists
   status            text NOT NULL DEFAULT 'planned'
                     CHECK (status IN ('planned','in_progress','completed','cancelled','deferred')),
   due_at            timestamptz,
   completed_at      timestamptz,
   completed_by      uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE clinical.plan_item IS 'An individual action within a plan.';

CREATE INDEX idx_plan_item_plan ON clinical.plan_item(plan_id);

CREATE TABLE clinical.follow_up_plan (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   follow_up_type    text,                    -- outpatient / telephone / home / special_clinic
   instructions      text,
   due_date          date NOT NULL,
   facility_id       uuid REFERENCES organization.facility(id),
   clinic_id         uuid REFERENCES organization.clinic(id),
   clinician_id      uuid REFERENCES organization.professional(id),
   status            text NOT NULL DEFAULT 'open' CHECK (status IN ('open','completed','cancelled','overdue')),
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.follow_up_plan IS 'Planned follow-up after an encounter.';

CREATE INDEX idx_follow_up_patient ON clinical.follow_up_plan(patient_id);

CREATE TABLE clinical.disposition (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid NOT NULL REFERENCES encounter.encounter(id),
   disposition_type  text NOT NULL CHECK (disposition_type IN
                     ('discharge','admit','referral','transfer','observe','follow_up','expired','other')),
   destination       text,                    -- home / ward / other_facility / ...
   decided_at        timestamptz NOT NULL DEFAULT now(),
   decided_by        uuid REFERENCES identity.user_account(id),
   notes             text,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.disposition IS 'How an encounter ended for the patient.';

CREATE TABLE clinical.referral (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   from_professional uuid REFERENCES organization.professional(id),
   to_professional   uuid REFERENCES organization.professional(id),
   to_facility_id    uuid REFERENCES organization.facility(id),
   to_department_id  uuid REFERENCES organization.department(id),
   reason            text,
   priority          text NOT NULL DEFAULT 'routine',
   status            text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','accepted','declined','completed','cancelled')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   closed_at         timestamptz
);
COMMENT ON TABLE clinical.referral IS 'A referral between clinicians/facilities.';

CREATE INDEX idx_referral_patient ON clinical.referral(patient_id);

-- =============================================================================
-- ORDERS — universal order infrastructure
-- =============================================================================

CREATE TABLE clinical.order_type (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.order_type IS 'laboratory / imaging / medication / procedure / nursing / consultation / diet / other.';

CREATE TABLE clinical.order_status (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.order_status IS 'draft / pending / active / on_hold / completed / cancelled / resulted.';

CREATE TABLE clinical.order_priority (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   sort_order        integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE clinical.order_priority IS 'routine / urgent / stat / asap.';

CREATE TABLE clinical.order (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   order_type_code   text NOT NULL REFERENCES clinical.order_type(code),
   status_code       text NOT NULL DEFAULT 'pending' REFERENCES clinical.order_status(code),
   priority_code     text NOT NULL DEFAULT 'routine' REFERENCES clinical.order_priority(code),
   concept_id        uuid REFERENCES terminology.concept(id),
   service_id        uuid REFERENCES organization.service(id),
   requested_by      uuid REFERENCES organization.professional(id),
   requested_at      timestamptz NOT NULL DEFAULT now(),
   requested_start   timestamptz,
   requested_end     timestamptz,
   instructions      text,
   reason_text       text,
   is_stat           boolean NOT NULL DEFAULT false,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.order IS 'The universal order. Specialized order engines (lab, imaging, meds) attach in Phase 2.';

CREATE INDEX idx_order_patient ON clinical.order(patient_id);
CREATE INDEX idx_order_encounter ON clinical.order(encounter_id);
CREATE INDEX idx_order_status ON clinical.order(status_code);
CREATE TRIGGER trg_order_updated_at
   BEFORE UPDATE ON clinical.order
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- plan_item.related_order_id depends on clinical.order, added after creation
ALTER TABLE clinical.plan_item
   ADD CONSTRAINT fk_plan_item_order FOREIGN KEY (related_order_id)
   REFERENCES clinical.order(id);

CREATE TABLE clinical.order_reason (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id          uuid NOT NULL REFERENCES clinical.order(id) ON DELETE CASCADE,
   reason_type       text NOT NULL,           -- symptom / indication / follow_up / monitoring / differential
   reason            text NOT NULL,
   concept_id        uuid REFERENCES terminology.concept(id)
);
COMMENT ON TABLE clinical.order_reason IS 'Rationale for an order.';

CREATE TABLE clinical.order_source (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id          uuid NOT NULL REFERENCES clinical.order(id) ON DELETE CASCADE,
   source_type       text NOT NULL,           -- manual / protocol / differential / engine / clinical_decision_support
   source_ref        text,
   engine_id         text
);
COMMENT ON TABLE clinical.order_source IS 'Where/why an order was generated.';

CREATE TABLE clinical.order_event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id          uuid NOT NULL REFERENCES clinical.order(id) ON DELETE CASCADE,
   event_type        text NOT NULL,           -- created / submitted / accepted / collected / resulted / completed / cancelled
   event_at          timestamptz NOT NULL DEFAULT now(),
   event_by          uuid REFERENCES identity.user_account(id),
   detail            jsonb
);
COMMENT ON TABLE clinical.order_event IS 'Full lifecycle events for an order.';

CREATE INDEX idx_order_event_order ON clinical.order_event(order_id);

CREATE TABLE clinical.order_cancellation (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   order_id          uuid NOT NULL REFERENCES clinical.order(id) ON DELETE CASCADE,
   cancelled_by      uuid NOT NULL REFERENCES identity.user_account(id),
   cancelled_at      timestamptz NOT NULL DEFAULT now(),
   reason            text,
   previous_status   text
);
COMMENT ON TABLE clinical.order_cancellation IS 'Record of order cancellation.';

CREATE TABLE clinical.result (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   result_type       text NOT NULL CHECK (result_type IN ('numeric','coded','text','document')),
   concept_id        uuid REFERENCES terminology.concept(id),
   value_numeric     numeric,
   value_text        text,
   unit_code         text REFERENCES terminology.unit(code),
   status            text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','partial','final','corrected','cancelled')),
   collected_at      timestamptz,
   resulted_at       timestamptz,
   resulted_by       uuid REFERENCES identity.user_account(id),
   notes             text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.result IS 'A result produced for a patient (lab, imaging, pathology...).';

CREATE INDEX idx_result_patient ON clinical.result(patient_id);
CREATE TRIGGER trg_result_updated_at
   BEFORE UPDATE ON clinical.result
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE clinical.order_result_link (
   order_id          uuid NOT NULL REFERENCES clinical.order(id) ON DELETE CASCADE,
   result_id         uuid NOT NULL REFERENCES clinical.result(id) ON DELETE CASCADE,
   link_type         text NOT NULL DEFAULT 'produced',
   PRIMARY KEY (order_id, result_id)
);
COMMENT ON TABLE clinical.order_result_link IS 'Links an order to the result(s) it produced.';

-- =============================================================================
-- CARE TEAM
-- =============================================================================

CREATE TABLE clinical.care_team (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   name              text NOT NULL,
   team_type         text,                    -- inpatient_team / ward_team / specialist_team
   is_active         boolean NOT NULL DEFAULT true,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.care_team IS 'A team caring for a patient.';

CREATE INDEX idx_care_team_patient ON clinical.care_team(patient_id);

CREATE TABLE clinical.care_team_role (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.care_team_role IS 'attending / registrar / intern / nurse_in_charge / consultant / pharmacist.';

CREATE TABLE clinical.care_team_member (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   care_team_id      uuid NOT NULL REFERENCES clinical.care_team(id) ON DELETE CASCADE,
   professional_id   uuid NOT NULL REFERENCES organization.professional(id),
   role_code         text REFERENCES clinical.care_team_role(code),
   is_lead           boolean NOT NULL DEFAULT false,
   valid_from        timestamptz NOT NULL DEFAULT now(),
   valid_to          timestamptz
);
COMMENT ON TABLE clinical.care_team_member IS 'A professional''s membership in a care team.';

CREATE TABLE clinical.care_team_assignment (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   care_team_id      uuid REFERENCES clinical.care_team(id),
   professional_id   uuid NOT NULL REFERENCES organization.professional(id),
   assignment_type   text NOT NULL,           -- responsible_clinician / consultant / nurse_in_charge
   valid_from        timestamptz NOT NULL DEFAULT now(),
   valid_to          timestamptz
);
COMMENT ON TABLE clinical.care_team_assignment IS 'Assignment of responsibility for a patient.';

CREATE INDEX idx_care_team_assignment_patient ON clinical.care_team_assignment(patient_id);

CREATE TABLE clinical.handover (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   from_professional uuid REFERENCES organization.professional(id),
   to_professional   uuid REFERENCES organization.professional(id),
   summary           text,
   status            text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','completed','cancelled')),
   created_at        timestamptz NOT NULL DEFAULT now(),
   accepted_at       timestamptz
);
COMMENT ON TABLE clinical.handover IS 'A clinical handover between providers.';

CREATE TABLE clinical.handover_item (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   handover_id       uuid NOT NULL REFERENCES clinical.handover(id) ON DELETE CASCADE,
   item_order        integer NOT NULL DEFAULT 0,
   item_type         text,                    -- issue / task / medication / follow_up / alert
   concept_id        uuid REFERENCES terminology.concept(id),
   description       text NOT NULL,
   action_required   text,
   status            text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','cancelled'))
);
COMMENT ON TABLE clinical.handover_item IS 'An individual item within a handover.';

-- =============================================================================
-- CLINICAL CONSENT & PREFERENCES
-- =============================================================================

CREATE TABLE clinical.consent_type (
   code              text PRIMARY KEY,
   label             text NOT NULL,
   description       text
);
COMMENT ON TABLE clinical.consent_type IS 'procedure / treatment / surgery / blood_transfusion / research / imaging / anesthesia.';

CREATE TABLE clinical.consent_version (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   consent_type_code text NOT NULL REFERENCES clinical.consent_type(code),
   version           integer NOT NULL,
   content           text NOT NULL,           -- the consent document text
   effective_from    date NOT NULL DEFAULT current_date,
   effective_to      date,
   UNIQUE (consent_type_code, version)
);
COMMENT ON TABLE clinical.consent_version IS 'Versioned consent documents per consent type.';

CREATE TABLE clinical.consent (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   encounter_id      uuid REFERENCES encounter.encounter(id),
   consent_type_code text NOT NULL REFERENCES clinical.consent_type(code),
   consent_version_id uuid REFERENCES clinical.consent_version(id),
   decision          text NOT NULL CHECK (decision IN ('granted','denied','withdrawn')),
   signed_by         uuid REFERENCES identity.person(id),
   signed_at         timestamptz,
   witnessed_by      uuid REFERENCES identity.person(id),
   valid_from        timestamptz NOT NULL DEFAULT now(),
   valid_to          timestamptz,
   notes             text,
   created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE clinical.consent IS 'A clinical consent decision.';

CREATE INDEX idx_consent_patient ON clinical.consent(patient_id);

CREATE TABLE clinical.consent_event (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   consent_id        uuid NOT NULL REFERENCES clinical.consent(id) ON DELETE CASCADE,
   event_type        text NOT NULL,           -- created / viewed / amended / withdrawn
   event_at          timestamptz NOT NULL DEFAULT now(),
   event_by          uuid REFERENCES identity.user_account(id),
   detail            jsonb
);
COMMENT ON TABLE clinical.consent_event IS 'Lifecycle events for a consent.';

CREATE TABLE clinical.patient_preference (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   preference_type   text NOT NULL,           -- pain_management / care_communication / spiritual / dietary
   preference_key    text NOT NULL,
   preference_value  text,
   recorded_at       timestamptz NOT NULL DEFAULT now(),
   recorded_by       uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE clinical.patient_preference IS 'Care preferences beyond administrative contact preferences.';

CREATE TABLE clinical.advance_directive (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   patient_id        uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
   directive_type    text NOT NULL,           -- living_will / dnr / organ_donation / power_of_attorney
   content           text,
   surrogate_person_id uuid REFERENCES identity.person(id),
   status            text NOT NULL DEFAULT 'active',
   recorded_at       timestamptz NOT NULL DEFAULT now(),
   recorded_by       uuid REFERENCES identity.user_account(id),
   expires_at        timestamptz
);
COMMENT ON TABLE clinical.advance_directive IS 'Advance directives where applicable.';
