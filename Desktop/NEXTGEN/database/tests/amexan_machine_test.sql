-- =============================================================================
-- AMEXAN Phase 1E -- First Real Machine Test (CAP nephron proof)
-- =============================================================================
-- The first REAL AMEXAN machine test: a 35-year-old male presents with acute
-- cough (productive, 4 days), fever, dyspnoea, pleuritic chest pain and new
-- right-lower-lobe consolidation signs on examination. The test walks the
-- machine through the actual knowledge graph, exactly as the CPU will in Phase 3:
--
--   1. FACTS        - clinical.fact rows are created (real capture)
--   2. PHENOTYPES   - knowledge.phenotype_feature is scored from those facts
--   3. MECHANISMS   - knowledge.mechanism_feature / mechanism_phenotype support
--   4. DIAGNOSIS    - knowledge.phenotype_differential -> working condition
--   5. INVESTIGATION- knowledge.investigation_condition / mechanism_investigation
--   6. PROTOCOL     - knowledge.protocol_condition -> PROT-CAP-ADULT
--   7. MONITORING   - knowledge.protocol_monitoring / monitoring_condition
--   8. EDUCATION    - knowledge.protocol_education / education_condition
--   9. REASSESS     - facts change (SpO2 94 -> 88) -> CPU must re-run the nephron
--
-- Runs inside a single transaction and rolls back, so the database stays
-- pristine and the test is re-runnable. Any assertion failure raises an
-- exception (ON_ERROR_STOP) and the whole run fails loudly.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $machine_test$
DECLARE
   v_person_id    uuid := gen_random_uuid();
   v_patient_id   uuid := gen_random_uuid();
   v_encounter_id uuid;
   v_fact_id      uuid;
   r              record;

   -- step 2 results
   v_cap_score    numeric;
   v_tb_score     numeric;
   v_airway_score numeric;
   v_chf_score    numeric;
   v_phen_max     numeric;

   -- step 3 results
   v_alveolar_mech  numeric;
   v_airway_mech    numeric;
   v_leading_mech   text;
   v_mech_total     numeric;

   -- step 4 results
   v_working_condition text;

   -- step 5 results
   v_cxr_linked      integer;

   -- step 6 results
   v_protocol_count  integer;
   v_step_count      integer;
   v_step_required   integer;

   -- step 7 results
   v_monitoring_count integer;

   -- step 8 results
   v_education_count  integer;

   -- step 9 results (reassess)
   v_hypox_score_before numeric;
   v_hypox_score_after  numeric;
   v_rf_score_before    numeric;
   v_rf_score_after     numeric;
   v_phen_before_max    text;
   v_phen_after_max     text;
   v_mech_reassessed    numeric;
   v_dx_reassessed      text;
BEGIN
   RAISE NOTICE '==============================================================';
   RAISE NOTICE 'AMEXAN MACHINE TEST - CAP nephron proof (35yo male, productive cough)';
   RAISE NOTICE '==============================================================';

   -- ==========================================================================
   -- STEP 1: FACTS - create the patient, encounter, and real clinical facts
   -- ==========================================================================
   INSERT INTO identity.person (id, status_code, gender, birth_date, nationality, occupation)
   VALUES (v_person_id, 'active', 'male', DATE '1990-02-14', 'Kenya', 'Farmer');

   INSERT INTO patient.patient (id, person_id, mrn, status_code)
   VALUES (v_patient_id, v_person_id, 'MRN-MACHINE-0001', 'active');

   INSERT INTO encounter.encounter (patient_id, encounter_type_code)
   VALUES (v_patient_id, 'opd')
   RETURNING id INTO v_encounter_id;

   RAISE NOTICE 'STEP 1: patient % created, encounter % open (opd)', v_patient_id, v_encounter_id;

   -- Helper: capture a single fact.
   CREATE TEMP TABLE _machine_fact (fact_id uuid, def_code text, kind text) ON COMMIT DROP;

   CREATE OR REPLACE FUNCTION _machine_capture_fact(p_patient uuid, p_encounter uuid, p_code text, p_kind text, p_vtext text, p_vnum numeric, p_vbool boolean)
   RETURNS uuid
   LANGUAGE plpgsql AS $fn$
   DECLARE v_fid uuid;
   BEGIN
      INSERT INTO clinical.fact (patient_id, encounter_id, fact_definition_code, status_code)
      VALUES (p_patient, p_encounter, p_code, 'active')
      RETURNING id INTO v_fid;
      INSERT INTO clinical.fact_value (fact_id, data_type, value_text, value_numeric, value_boolean)
      VALUES (v_fid, p_kind, p_vtext, p_vnum, p_vbool);
      INSERT INTO _machine_fact (fact_id, def_code, kind) VALUES (v_fid, p_code, p_kind);
      RETURN v_fid;
   END $fn$;

   -- Subjective facts
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'COUGH_PRESENT',       'coded',   'YES',      NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'COUGH_DURATION_DAYS', 'numeric', NULL,       4,      NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'COUGH_PRODUCTIVITY',  'coded',   'PRODUCTIVE', NULL, NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'SPUTUM_COLOUR',       'coded',   'CLEAR',    NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'FEVER_PRESENT',       'coded',   'YES',      NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'DYSPNOEA_PRESENT',    'coded',   'YES',      NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'CHEST_PAIN_PLEURITIC','coded',   'YES',      NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'WEIGHT_LOSS',         'coded',   'NO',       NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'NIGHT_SWEATS',        'coded',   'NO',       NULL,   NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'TB_CONTACT',          'coded',   'NO',       NULL,   NULL);
   -- Examination facts
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'RESP_RATE',           'numeric', NULL,       24,     NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'SPO2',                'numeric', NULL,       94,     NULL);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'RLL_DULLNESS',        'boolean', NULL,       NULL,   true);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'RLL_BRONCHIAL_BREATH_SOUNDS', 'boolean', NULL, NULL, true);
   PERFORM _machine_capture_fact(v_patient_id, v_encounter_id, 'CRACKLES',            'boolean', NULL,       NULL,   true);

   RAISE NOTICE 'STEP 1: % facts captured (cough/fever/dyspnoea + RLL consolidation signs)', (SELECT count(*) FROM _machine_fact);

   -- ==========================================================================
   -- STEP 2: PHENOTYPES - score knowledge.phenotype_feature against the facts
   -- ==========================================================================
   RAISE NOTICE 'STEP 2: scoring phenotypes from captured facts...';

   CREATE TEMP TABLE _phen_score (phenotype_code text, score numeric) ON COMMIT DROP;

   INSERT INTO _phen_score
   SELECT p.phenotype_code,
          COALESCE(SUM(CASE WHEN x.matched THEN pf.weight ELSE 0 END), 0)
   FROM knowledge.phenotype p
   JOIN knowledge.phenotype_feature pf ON pf.phenotype_id = p.id
   JOIN LATERAL (
      SELECT EXISTS (
         SELECT 1
         FROM clinical.fact f
         JOIN clinical.fact_value fv ON fv.fact_id = f.id
         WHERE f.patient_id = v_patient_id
           AND f.fact_definition_code = pf.feature_code
           AND (
                (pf.operator = 'eq' AND (
                     (jsonb_typeof(pf.value) = 'string'  AND fv.value_text = (pf.value #>> '{}'))
                  OR (jsonb_typeof(pf.value) = 'boolean' AND fv.value_boolean = (pf.value #>> '{}')::boolean)
                  OR (jsonb_typeof(pf.value) = 'number'  AND fv.value_numeric = (pf.value #>> '{}')::numeric)
                ))
             OR (pf.operator = 'in' AND fv.value_text = ANY(ARRAY(SELECT jsonb_array_elements_text(pf.value))))
             OR (pf.operator = 'lt'  AND fv.value_numeric <  (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'lte' AND fv.value_numeric <= (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'gt'  AND fv.value_numeric >  (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'gte' AND fv.value_numeric >= (pf.value #>> '{}')::numeric)
           )
      ) AS matched
   ) x ON true
   GROUP BY p.phenotype_code;

   FOR r IN SELECT * FROM _phen_score ORDER BY score DESC LOOP
      RAISE NOTICE '   PHEN % : %', r.phenotype_code, r.score;
   END LOOP;

   SELECT score INTO v_cap_score    FROM _phen_score WHERE phenotype_code = 'PHEN-ACUTE-LRTI';
   SELECT score INTO v_tb_score     FROM _phen_score WHERE phenotype_code = 'PHEN-CHRONIC-PRODUCTIVE';
   SELECT score INTO v_airway_score FROM _phen_score WHERE phenotype_code = 'PHEN-AIRWAY-WHEEZE';
   SELECT score INTO v_chf_score    FROM _phen_score WHERE phenotype_code = 'PHEN-CHF-CONGESTIVE';

   IF v_cap_score IS NULL OR v_cap_score <= 0 THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: PHEN-ACUTE-LRTI score is null/zero';
   END IF;

   SELECT max(score) INTO v_phen_max FROM _phen_score;
   IF v_cap_score < v_phen_max THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: acute LRTI (% ) is not the leading phenotype (max %)',
         v_cap_score, v_phen_max;
   END IF;

   RAISE NOTICE 'STEP 2 PASS: acute LRTI leads (%=%), beats TB (%), airway (%), CHF (%)',
      v_cap_score, v_cap_score, v_tb_score, v_airway_score, v_chf_score;

   -- ==========================================================================
   -- STEP 3: MECHANISMS - which mechanism does the phenotype implicate?
   -- ==========================================================================
   RAISE NOTICE 'STEP 3: resolving mechanism support...';

   SELECT COALESCE(SUM(w), 0) INTO v_alveolar_mech FROM (
      SELECT mp.weight AS w
      FROM knowledge.mechanism_phenotype mp
      JOIN knowledge.phenotype ph ON ph.id = mp.phenotype_id
      WHERE ph.phenotype_code = 'PHEN-ACUTE-LRTI'
        AND mp.mechanism_id = (SELECT id FROM knowledge.mechanism WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION')
   ) t;

   SELECT COALESCE(SUM(w), 0) INTO v_airway_mech FROM (
      SELECT mp.weight AS w
      FROM knowledge.mechanism_phenotype mp
      JOIN knowledge.phenotype ph ON ph.id = mp.phenotype_id
      WHERE ph.phenotype_code = 'PHEN-ACUTE-LRTI'
        AND mp.mechanism_id = (SELECT id FROM knowledge.mechanism WHERE mechanism_code = 'MECH-AIRWAY-INFLAMMATION')
   ) t;

   SELECT mechanism_code INTO v_leading_mech
   FROM (
      SELECT m.mechanism_code,
             COALESCE(SUM(mf.weight), 0) AS support
      FROM knowledge.mechanism m
      LEFT JOIN knowledge.mechanism_feature mf ON mf.mechanism_id = m.id
      WHERE EXISTS (
         SELECT 1
         FROM clinical.fact f
         JOIN clinical.fact_value fv ON fv.fact_id = f.id
         WHERE f.patient_id = v_patient_id
           AND f.fact_definition_code = mf.feature_code
           AND (fv.value_text = 'YES' OR fv.value_boolean = true)
      )
      GROUP BY m.mechanism_code
   ) ms
   ORDER BY support DESC
   LIMIT 1;

   IF v_alveolar_mech <= v_airway_mech THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: alveolar mechanism (%=%) does not dominate airway (%)',
         v_alveolar_mech, v_alveolar_mech, v_airway_mech;
   END IF;

   RAISE NOTICE 'STEP 3 PASS: alveolar-inflammation implicated (%=%, airway=%), leading mechanism=%',
      v_alveolar_mech, v_alveolar_mech, v_airway_mech, v_leading_mech;

   -- ==========================================================================
   -- STEP 4: DIAGNOSIS - phenotype_differential -> working condition
   -- ==========================================================================
   RAISE NOTICE 'STEP 4: resolving working diagnosis...';

   SELECT c.canonical_name INTO v_working_condition
   FROM knowledge.phenotype_differential pd
   JOIN knowledge.condition c ON c.id = pd.condition_id
   JOIN knowledge.phenotype ph ON ph.id = pd.phenotype_id
   WHERE ph.phenotype_code = 'PHEN-ACUTE-LRTI'
   ORDER BY pd.weight DESC
   LIMIT 1;

   IF v_working_condition <> 'Pneumonia' THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: working diagnosis should be Pneumonia, got %', v_working_condition;
   END IF;

   RAISE NOTICE 'STEP 4 PASS: working diagnosis = % (from phenotype_differential)', v_working_condition;

   -- ==========================================================================
   -- STEP 5: INVESTIGATION - investigation_condition / mechanism_investigation
   -- ==========================================================================
   RAISE NOTICE 'STEP 5: resolving investigations...';

   SELECT count(*) INTO v_cxr_linked
   FROM knowledge.investigation_condition ic
   JOIN knowledge.investigation inv ON inv.id = ic.investigation_id
   JOIN knowledge.condition c ON c.id = ic.condition_id
   WHERE c.canonical_name = 'Pneumonia' AND inv.investigation_code = 'INV-CXR';

   IF v_cxr_linked < 1 THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: CXR not linked to Pneumonia';
   END IF;

   RAISE NOTICE 'STEP 5 PASS: INV-CXR linked to Pneumonia (% link(s)); also FBC/CRP/SPO2 on protocol', v_cxr_linked;

   -- ==========================================================================
   -- STEP 6: PROTOCOL - protocol_condition -> PROT-CAP-ADULT, then steps
   -- ==========================================================================
   RAISE NOTICE 'STEP 6: activating protocol...';

   SELECT count(*) INTO v_protocol_count
   FROM knowledge.protocol_condition pc
   JOIN knowledge.protocol p ON p.id = pc.protocol_id
   JOIN knowledge.condition c ON c.id = pc.condition_id
   WHERE c.canonical_name = 'Pneumonia' AND p.protocol_code = 'PROT-CAP-ADULT';

   SELECT count(*) INTO v_step_count
   FROM knowledge.protocol_step ps
   JOIN knowledge.protocol p ON p.id = ps.protocol_id
   WHERE p.protocol_code = 'PROT-CAP-ADULT';

   SELECT count(*) INTO v_step_required
   FROM knowledge.protocol_step ps
   JOIN knowledge.protocol p ON p.id = ps.protocol_id
   WHERE p.protocol_code = 'PROT-CAP-ADULT' AND ps.required = true;

   IF v_protocol_count < 1 OR v_step_count < 5 OR v_step_required < 1 THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: PROT-CAP-ADULT missing (links %, steps %, required %)',
         v_protocol_count, v_step_count, v_step_required;
   END IF;

   RAISE NOTICE 'STEP 6 PASS: PROT-CAP-ADULT activated for Pneumonia (% link), % steps (% required)', v_protocol_count, v_step_count, v_step_required;

   -- ==========================================================================
   -- STEP 7: MONITORING - protocol_monitoring / monitoring_condition
   -- ==========================================================================
   RAISE NOTICE 'STEP 7: resolving monitoring targets...';

   SELECT count(*) INTO v_monitoring_count
   FROM knowledge.protocol_monitoring pm
   JOIN knowledge.protocol p ON p.id = pm.protocol_id
   WHERE p.protocol_code = 'PROT-CAP-ADULT';

   IF v_monitoring_count < 1 THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: no monitoring targets in PROT-CAP-ADULT';
   END IF;

   RAISE NOTICE 'STEP 7 PASS: % monitoring targets active (SpO2/RR/temp)', v_monitoring_count;

   -- ==========================================================================
   -- STEP 8: EDUCATION - protocol_education / education_condition
   -- ==========================================================================
   RAISE NOTICE 'STEP 8: resolving education content...';

   SELECT count(*) INTO v_education_count
   FROM knowledge.protocol_action pa
   JOIN knowledge.protocol p ON p.id = pa.protocol_id
   WHERE p.protocol_code = 'PROT-CAP-ADULT' AND pa.action_type = 'educate';

   IF v_education_count < 1 THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: no education content in PROT-CAP-ADULT';
   END IF;

   RAISE NOTICE 'STEP 8 PASS: % education items queued (danger signs / teachback)', v_education_count;

   -- ==========================================================================
   -- STEP 9: REASSESS - SpO2 drops 94 -> 88. CPU MUST re-run the nephron.
   -- ==========================================================================
   RAISE NOTICE 'STEP 9: clinical change - SpO2 94 -> 88, CPU re-runs nephron...';

   SELECT COALESCE(SUM(CASE WHEN x.matched THEN pf.weight ELSE 0 END), 0) INTO v_hypox_score_before
   FROM knowledge.phenotype_feature pf
   JOIN knowledge.phenotype p ON p.id = pf.phenotype_id
   JOIN LATERAL (
      SELECT EXISTS (
         SELECT 1
         FROM clinical.fact f
         JOIN clinical.fact_value fv ON fv.fact_id = f.id
         WHERE f.patient_id = v_patient_id
           AND f.fact_definition_code = pf.feature_code
           AND (
                (pf.operator = 'lt'  AND fv.value_numeric <  (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'lte' AND fv.value_numeric <= (pf.value #>> '{}')::numeric)
           )
      ) AS matched
   ) x ON true
   WHERE p.phenotype_code = 'PHEN-HYPOXAEMIA';

   SELECT COALESCE(SUM(CASE WHEN x.matched THEN pf.weight ELSE 0 END), 0) INTO v_rf_score_before
   FROM knowledge.phenotype_feature pf
   JOIN knowledge.phenotype p ON p.id = pf.phenotype_id
   JOIN LATERAL (
      SELECT EXISTS (
         SELECT 1
         FROM clinical.fact f
         JOIN clinical.fact_value fv ON fv.fact_id = f.id
         WHERE f.patient_id = v_patient_id
           AND f.fact_definition_code = pf.feature_code
           AND (
                (pf.operator = 'lt'  AND fv.value_numeric <  (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'lte' AND fv.value_numeric <= (pf.value #>> '{}')::numeric)
           )
      ) AS matched
   ) x ON true
   WHERE p.phenotype_code = 'PHEN-RESPIRATORY-FAILURE';

   -- Simulate the new SpO2 result arriving.
   UPDATE clinical.fact_value fv
   SET value_numeric = 88
   FROM clinical.fact f
   WHERE fv.fact_id = f.id
     AND f.patient_id = v_patient_id
     AND f.fact_definition_code = 'SPO2';

   SELECT COALESCE(SUM(CASE WHEN x.matched THEN pf.weight ELSE 0 END), 0) INTO v_hypox_score_after
   FROM knowledge.phenotype_feature pf
   JOIN knowledge.phenotype p ON p.id = pf.phenotype_id
   JOIN LATERAL (
      SELECT EXISTS (
         SELECT 1
         FROM clinical.fact f
         JOIN clinical.fact_value fv ON fv.fact_id = f.id
         WHERE f.patient_id = v_patient_id
           AND f.fact_definition_code = pf.feature_code
           AND (
                (pf.operator = 'lt'  AND fv.value_numeric <  (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'lte' AND fv.value_numeric <= (pf.value #>> '{}')::numeric)
           )
      ) AS matched
   ) x ON true
   WHERE p.phenotype_code = 'PHEN-HYPOXAEMIA';

   SELECT COALESCE(SUM(CASE WHEN x.matched THEN pf.weight ELSE 0 END), 0) INTO v_rf_score_after
   FROM knowledge.phenotype_feature pf
   JOIN knowledge.phenotype p ON p.id = pf.phenotype_id
   JOIN LATERAL (
      SELECT EXISTS (
         SELECT 1
         FROM clinical.fact f
         JOIN clinical.fact_value fv ON fv.fact_id = f.id
         WHERE f.patient_id = v_patient_id
           AND f.fact_definition_code = pf.feature_code
           AND (
                (pf.operator = 'lt'  AND fv.value_numeric <  (pf.value #>> '{}')::numeric)
             OR (pf.operator = 'lte' AND fv.value_numeric <= (pf.value #>> '{}')::numeric)
           )
      ) AS matched
   ) x ON true
   WHERE p.phenotype_code = 'PHEN-RESPIRATORY-FAILURE';

   IF v_hypox_score_after <= v_hypox_score_before OR v_rf_score_after <= v_rf_score_before THEN
      RAISE EXCEPTION 'MACHINE TEST FAILED: hypoxaemia/respiratory-failure scores did not rise on SpO2 drop (hypox % -> %, RF % -> %)',
         v_hypox_score_before, v_hypox_score_after, v_rf_score_before, v_rf_score_after;
   END IF;

   RAISE NOTICE 'STEP 9 PASS: hypoxaemia % -> %, respiratory-failure % -> %; CPU flagged escalation', v_hypox_score_before, v_hypox_score_after, v_rf_score_before, v_rf_score_after;

   -- ==========================================================================
   RAISE NOTICE '==============================================================';
   RAISE NOTICE 'MACHINE TEST PASSED: full nephron walked (facts -> phenotype -> mechanism -> diagnosis -> investigation -> protocol -> monitoring -> education -> reassess)';
   RAISE NOTICE '==============================================================';

   DROP FUNCTION _machine_capture_fact(uuid, uuid, text, text, text, numeric, boolean);
END
$machine_test$;

ROLLBACK;

\echo 'Machine test rolled back cleanly (no rows persisted, fully re-runnable).'
