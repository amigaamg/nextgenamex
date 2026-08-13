-- =============================================================================
-- AMEXAN Phase 1 — Acceptance Test
-- =============================================================================
-- Walks the full universal scenario with ZERO disease-specific code:
--
--   person -> user -> organization -> facility -> department -> professional
--   -> patient -> encounter -> clinical fact -> observation -> problem -> order
--   -> result -> assessment -> plan -> document -> audit
--
-- Runs inside a transaction and rolls back, so the database stays pristine and
-- the test is re-runnable. Fails loudly (RAISE EXCEPTION) if any step breaks.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $test$
DECLARE
   v_person_id        uuid;
   v_doctor_person_id uuid;
   v_user_id          uuid;
   v_org_id           uuid;
   v_facility_id      uuid;
   v_dept_id          uuid;
   v_prof_id          uuid;
   v_patient_id       uuid;
   v_encounter_id     uuid;
   v_fact_id          uuid;
   v_obs_id           uuid;
   v_problem_id       uuid;
   v_order_id         uuid;
   v_result_id        uuid;
   v_plan_id          uuid;
   v_document_id      uuid;
   v_count            integer;
   v_fact_def_code    text := 'COUGH_PRODUCTIVITY';
BEGIN

   -- ==========================================================================
   -- STEP 1: CREATE PERSON
   -- ==========================================================================
   INSERT INTO identity.person (id, status_code, gender, birth_date, nationality, occupation)
   VALUES (gen_random_uuid(), 'active', 'female', DATE '1990-01-15', 'Kenya', 'Teacher')
   RETURNING id INTO v_person_id;

   SELECT count(*) INTO v_count FROM identity.person WHERE id = v_person_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 1 FAILED: person not created'; END IF;
   RAISE NOTICE 'STEP 1 PASSED: person created (%)', v_person_id;

   -- ==========================================================================
   -- STEP 2: CREATE USER (a doctor's login account)
   -- ==========================================================================
   INSERT INTO identity.person (id, status_code, gender, birth_date, preferred_name)
   VALUES (gen_random_uuid(), 'active', 'male', DATE '1985-03-22', 'Dr. Kiprono')
   RETURNING id INTO v_doctor_person_id;

   INSERT INTO identity.user_account (id, person_id, username, email, account_status)
   VALUES (gen_random_uuid(), v_doctor_person_id, 'dr.kiprono', 'kiprono@amexan.example', 'active')
   RETURNING id INTO v_user_id;

   SELECT count(*) INTO v_count FROM identity.user_account WHERE id = v_user_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 2 FAILED: user account not created'; END IF;
   RAISE NOTICE 'STEP 2 PASSED: user account created (%)', v_user_id;

   -- ==========================================================================
   -- STEP 3: CREATE ORGANIZATION
   -- ==========================================================================
   INSERT INTO organization.organization (id, name, legal_name, organization_type, country)
   VALUES (gen_random_uuid(), 'Kisii County Health Services', 'Kisii County Health Services', 'hospital_network', 'Kenya')
   RETURNING id INTO v_org_id;

   SELECT count(*) INTO v_count FROM organization.organization WHERE id = v_org_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 3 FAILED: organization not created'; END IF;
   RAISE NOTICE 'STEP 3 PASSED: organization created (%)', v_org_id;

   -- ==========================================================================
   -- STEP 4: CREATE FACILITY
   -- ==========================================================================
   INSERT INTO organization.facility (id, organization_id, name, facility_type)
   VALUES (gen_random_uuid(), v_org_id, 'Kisii Teaching Hospital', 'hospital')
   RETURNING id INTO v_facility_id;

   SELECT count(*) INTO v_count FROM organization.facility WHERE id = v_facility_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 4 FAILED: facility not created'; END IF;
   RAISE NOTICE 'STEP 4 PASSED: facility created (%)', v_facility_id;

   -- ==========================================================================
   -- STEP 5: CREATE DEPARTMENT
   -- ==========================================================================
   INSERT INTO organization.department (id, facility_id, name, code)
   VALUES (gen_random_uuid(), v_facility_id, 'Medicine', 'MED')
   RETURNING id INTO v_dept_id;

   SELECT count(*) INTO v_count FROM organization.department WHERE id = v_dept_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 5 FAILED: department not created'; END IF;
   RAISE NOTICE 'STEP 5 PASSED: department created (%)', v_dept_id;

   -- ==========================================================================
   -- STEP 6: CREATE CLINICIAN (professional)
   -- ==========================================================================
   INSERT INTO organization.professional (id, person_id, profession_code, specialty_code, staff_number)
   VALUES (gen_random_uuid(), v_doctor_person_id, 'doctor', 'internal_medicine', 'KTH-0001')
   RETURNING id INTO v_prof_id;

   INSERT INTO organization.staff_assignment (id, professional_id, facility_id, department_id, role_text)
   VALUES (gen_random_uuid(), v_prof_id, v_facility_id, v_dept_id, 'Consultant Physician');

   SELECT count(*) INTO v_count FROM organization.professional WHERE id = v_prof_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 6 FAILED: professional not created'; END IF;
   RAISE NOTICE 'STEP 6 PASSED: professional (clinician) created (%)', v_prof_id;

   -- ==========================================================================
   -- STEP 7: CREATE PATIENT
   -- ==========================================================================
   INSERT INTO patient.patient (id, person_id, mrn, status_code)
   VALUES (gen_random_uuid(), v_person_id, 'MRN-000001', 'active')
   RETURNING id INTO v_patient_id;

   SELECT count(*) INTO v_count FROM patient.patient WHERE id = v_patient_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 7 FAILED: patient not created'; END IF;
   RAISE NOTICE 'STEP 7 PASSED: patient created (%)', v_patient_id;

   -- ==========================================================================
   -- STEP 8: CREATE ENCOUNTER
   -- ==========================================================================
   INSERT INTO encounter.encounter (id, patient_id, encounter_type_code, status_code,
                                    phase_code, priority_code, facility_id, department_id,
                                    started_at)
   VALUES (gen_random_uuid(), v_patient_id, 'opd', 'active', 'consultation', 'urgent',
           v_facility_id, v_dept_id, now())
   RETURNING id INTO v_encounter_id;

   INSERT INTO encounter.encounter_participant (id, encounter_id, professional_id, participant_role)
   VALUES (gen_random_uuid(), v_encounter_id, v_prof_id, 'attending');

   INSERT INTO encounter.encounter_phase_history (id, encounter_id, phase_code, entered_by)
   VALUES (gen_random_uuid(), v_encounter_id, 'registration', v_user_id),
          (gen_random_uuid(), v_encounter_id, 'consultation', v_user_id);

   SELECT count(*) INTO v_count FROM encounter.encounter WHERE id = v_encounter_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 8 FAILED: encounter not created'; END IF;
   RAISE NOTICE 'STEP 8 PASSED: encounter created (%)', v_encounter_id;

   -- ==========================================================================
   -- STEP 9: CAPTURE A CLINICAL FACT
   -- ==========================================================================
   INSERT INTO clinical.fact_definition (code, name, data_type, concept_id)
   VALUES (v_fact_def_code, 'Cough productivity', 'coded',
           '00000000-0000-0000-0000-00000000a001')
   ON CONFLICT (code) DO NOTHING;

   INSERT INTO clinical.fact (id, patient_id, encounter_id, fact_definition_code, status_code,
                              recorded_by, observed_at)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, v_fact_def_code, 'active',
           v_user_id, now())
   RETURNING id INTO v_fact_id;

   INSERT INTO clinical.fact_value (id, fact_id, data_type, value_text, value_concept_id)
   VALUES (gen_random_uuid(), v_fact_id, 'coded', 'PRODUCTIVE',
           '00000000-0000-0000-0000-00000000a001');

   INSERT INTO clinical.fact_context (fact_id, context_key, context_value)
   VALUES (v_fact_id, 'duration_days', '7');

   INSERT INTO clinical.fact_source (fact_id, source_type)
   VALUES (v_fact_id, 'patient_history');

   INSERT INTO clinical.fact_confidence (fact_id, confidence, method)
   VALUES (v_fact_id, 0.95, 'reported');

   SELECT count(*) INTO v_count FROM clinical.fact WHERE id = v_fact_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 9 FAILED: fact not captured'; END IF;
   RAISE NOTICE 'STEP 9 PASSED: clinical fact captured (%)', v_fact_id;

   -- ==========================================================================
   -- STEP 10: STORE OBSERVATION (vital sign)
   -- ==========================================================================
   INSERT INTO clinical.observation (id, patient_id, encounter_id, observation_type, status)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, 'vital_sign', 'final')
   RETURNING id INTO v_obs_id;

   INSERT INTO clinical.vital_sign (id, observation_id, parameter_code, value_numeric, unit_code)
   VALUES (gen_random_uuid(), v_obs_id, 'SPO2', 94, '%');

   SELECT count(*) INTO v_count FROM clinical.vital_sign WHERE observation_id = v_obs_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 10 FAILED: observation not stored'; END IF;
   RAISE NOTICE 'STEP 10 PASSED: observation (SpO2 94 percent) stored (%)', v_obs_id;

   -- ==========================================================================
   -- STEP 11: CREATE PROBLEM
   -- ==========================================================================
   INSERT INTO clinical.problem (id, patient_id, encounter_id, concept_id, label, status_code)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id,
           '00000000-0000-0000-0000-00000000a001', 'Acute cough', 'active')
   RETURNING id INTO v_problem_id;

   SELECT count(*) INTO v_count FROM clinical.problem WHERE id = v_problem_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 11 FAILED: problem not created'; END IF;
   RAISE NOTICE 'STEP 11 PASSED: problem created (%)', v_problem_id;

   -- ==========================================================================
   -- STEP 12: CREATE ORDER
   -- ==========================================================================
   INSERT INTO clinical.order (id, patient_id, encounter_id, order_type_code, status_code,
                               priority_code, requested_by, reason_text)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, 'laboratory', 'pending', 'routine',
           v_prof_id, 'Cough for 7 days - exclude tuberculosis')
   RETURNING id INTO v_order_id;

   INSERT INTO clinical.order_reason (order_id, reason_type, reason)
   VALUES (v_order_id, 'indication', 'Persistent productive cough');

   INSERT INTO clinical.order_event (order_id, event_type, event_by)
   VALUES (v_order_id, 'created', v_user_id);

   SELECT count(*) INTO v_count FROM clinical.order WHERE id = v_order_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 12 FAILED: order not created'; END IF;
   RAISE NOTICE 'STEP 12 PASSED: order created (%)', v_order_id;

   -- ==========================================================================
   -- STEP 13: RECEIVE RESULT
   -- ==========================================================================
   INSERT INTO clinical.result (id, patient_id, encounter_id, result_type, value_text, status,
                                collected_at, resulted_at, resulted_by)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, 'text', 'Negative', 'final',
           now() - interval '1 hour', now(), v_user_id)
   RETURNING id INTO v_result_id;

   INSERT INTO clinical.order_result_link (order_id, result_id)
   VALUES (v_order_id, v_result_id);

   SELECT count(*) INTO v_count FROM clinical.result WHERE id = v_result_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 13 FAILED: result not received'; END IF;
   RAISE NOTICE 'STEP 13 PASSED: result received (%)', v_result_id;

   -- ==========================================================================
   -- STEP 14: CREATE ASSESSMENT
   -- ==========================================================================
   INSERT INTO clinical.assessment (id, patient_id, encounter_id, assessment_type, content, recorded_by)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, 'assessment',
           'Productive cough, 7 days, afebrile on review, SpO2 94% on room air.', v_user_id);

   SELECT count(*) INTO v_count FROM clinical.assessment
   WHERE patient_id = v_patient_id AND encounter_id = v_encounter_id;
   IF v_count < 1 THEN RAISE EXCEPTION 'STEP 14 FAILED: assessment not created'; END IF;
   RAISE NOTICE 'STEP 14 PASSED: assessment created';

   -- ==========================================================================
   -- STEP 15: CREATE PLAN
   -- ==========================================================================
   INSERT INTO clinical.plan (id, patient_id, encounter_id, plan_type, title, created_by)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, 'management', 'Outpatient management', v_user_id)
   RETURNING id INTO v_plan_id;

   INSERT INTO clinical.plan_item (id, plan_id, item_order, action_type, description, related_order_id)
   VALUES (gen_random_uuid(), v_plan_id, 1, 'order', 'Repeat chest X-ray if symptoms persist', v_order_id),
          (gen_random_uuid(), v_plan_id, 2, 'follow_up', 'Review in 5 days', NULL);

   SELECT count(*) INTO v_count FROM clinical.plan WHERE id = v_plan_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 15 FAILED: plan not created'; END IF;
   RAISE NOTICE 'STEP 15 PASSED: plan created (%)', v_plan_id;

   -- ==========================================================================
   -- STEP 16: GENERATE DOCUMENT
   -- ==========================================================================
   INSERT INTO document.document (id, patient_id, encounter_id, document_type_code, title, status, created_by)
   VALUES (gen_random_uuid(), v_patient_id, v_encounter_id, 'consultation_note',
           'Consultation note', 'final', v_user_id)
   RETURNING id INTO v_document_id;

   INSERT INTO document.document_version (id, document_id, version, content, created_by)
   VALUES (gen_random_uuid(), v_document_id, 1,
           'History: productive cough for 7 days. Examination: SpO2 94%. Assessment: acute cough. Plan: review in 5 days.',
           v_user_id);

   INSERT INTO document.document_section (document_version_id, section_type, content, sort_order)
   SELECT id, 'history',  'Productive cough for 7 days', 10 FROM document.document_version WHERE document_id = v_document_id;

   INSERT INTO document.document_author (document_id, professional_id)
   VALUES (v_document_id, v_prof_id);

   INSERT INTO document.document_source (document_id, source_type, source_entity_type, source_entity_id)
   VALUES (v_document_id, 'fact',  'clinical.fact',  v_fact_id),
          (v_document_id, 'observation', 'clinical.observation', v_obs_id);

   SELECT count(*) INTO v_count FROM document.document WHERE id = v_document_id;
   IF v_count <> 1 THEN RAISE EXCEPTION 'STEP 16 FAILED: document not generated'; END IF;
   RAISE NOTICE 'STEP 16 PASSED: document generated (%)', v_document_id;

   -- ==========================================================================
   -- STEP 17: AUDIT EVERYTHING
   -- ==========================================================================
   INSERT INTO audit.event (event_type, actor_type, actor_id, action, target_type, target_id, detail) VALUES
      ('patient.created',    'user', v_user_id, 'create', 'patient.patient',    v_patient_id,   jsonb_build_object('mrn', 'MRN-000001')),
      ('encounter.created',  'user', v_user_id, 'create', 'encounter.encounter', v_encounter_id, NULL),
      ('fact.created',       'user', v_user_id, 'create', 'clinical.fact',      v_fact_id,       NULL),
      ('order.created',      'user', v_user_id, 'create', 'clinical.order',     v_order_id,      NULL),
      ('result.received',    'user', v_user_id, 'create', 'clinical.result',    v_result_id,     NULL),
      ('document.created',   'user', v_user_id, 'create', 'document.document',  v_document_id,   NULL);

   INSERT INTO audit.access (target_type, target_id, access_type, accessed_by)
   VALUES ('patient.patient', v_patient_id, 'view', v_user_id);

   INSERT INTO audit.clinical_decision (patient_id, encounter_id, engine_id, decision_type, summary, decided_by)
   VALUES (v_patient_id, v_encounter_id, NULL, 'investigation', 'Ordered sputum for AFB to rule out TB', v_user_id);

   INSERT INTO audit.order_decision (order_id, decision, decided_by, reason)
   VALUES (v_order_id, 'accepted', v_user_id, 'Indicated for persistent productive cough');

   INSERT INTO audit.entity_change (entity_type, entity_id, change_type, changed_by, after)
   VALUES ('encounter.encounter', v_encounter_id, 'insert', v_user_id,
           jsonb_build_object('status_code', 'active'));

   SELECT count(*) INTO v_count FROM audit.event WHERE target_id = v_patient_id;
   IF v_count < 1 THEN RAISE EXCEPTION 'STEP 17 FAILED: audit events not recorded'; END IF;
   RAISE NOTICE 'STEP 17 PASSED: audit trail recorded (% events)', v_count;

   -- ==========================================================================
   -- FINAL: cross-cutting integrity checks (zero disease code)
   -- ==========================================================================
   SELECT count(*) INTO v_count
   FROM patient.patient p
   JOIN encounter.encounter e    ON e.patient_id = p.id
   JOIN clinical.problem pr      ON pr.patient_id = p.id
   JOIN clinical.order o         ON o.patient_id = p.id
   JOIN clinical.result r        ON r.patient_id = p.id
   JOIN document.document d      ON d.patient_id = p.id
   WHERE p.id = v_patient_id;

   IF v_count <> 1 THEN RAISE EXCEPTION 'FINAL FAILED: longitudinal chain is broken'; END IF;
   RAISE NOTICE 'FINAL PASSED: patient -> encounter -> problem -> order -> result -> document chain intact';

   RAISE NOTICE 'ACCEPTANCE TEST PASSED — Phase 1 is universal.';

EXCEPTION WHEN others THEN
   RAISE EXCEPTION 'ACCEPTANCE TEST FAILED: %', SQLERRM;
END;
$test$;

ROLLBACK;
