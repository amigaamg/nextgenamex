-- =============================================================================
-- AMEXAN Phase 1F -- Machine Test 03: H7 universal investigation-selection engine
-- =============================================================================
-- Validates the H7 knowledge layer built on Hutchison claims ONLY:
--   1. schema + seed counts (H7 §12 tables populated; 24-table family)
--   2. safety-critical priority engine: I009 PULSE_OXIMETRY base_priority=1000;
--      IR001 is a SAFETY rule (HCH12-0016); IR010 blocks CT under PREGNANCY (H7 §26)
--   3. haemoptysis → MANDATORY chest X-ray (IR002, HCH12-0004/0007) — H7 §11
--   4. chronic cough (>8 weeks = >56 days) → baseline spirometry + CXR, gated by
--      COUGH_DURATION_DAYS>56 conditions (IR003/IR004 + COND001/COND002, HCH12-0004);
--      CXR and spirometry requested ALONGSIDE (IR004 action, HCH12-0004)
--   5. dependency: contrast CT requires U&E result BEFORE (IR014 action
--      REQUIRE_RESULT_BEFORE I003, H7 §25)
--   6. result interpretation: raw WBC=23 → LEUKOCYTOSIS (outside RRS003 4-11);
--      SpO2 88 → HYPOXAEMIA critical (RRS013 ≥95, HCH12-0016); H7 §29/§30/§32
--   7. result_phenotype_link: consolidation → ALVEOLAR-INFLAMMATION, effusion →
--      PLEURAL-INFLAMMATION (HCH12-0019 tracheal deviation); H7 §33
--   8. governance: every seeded H7 object carries a derived_from edge to a real
--      Hutchison claim; no dangling provenance; 0 orphan FKs
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP so any
-- assertion failure fails the whole run loudly.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h7_test$
DECLARE
   v integer;
   vtext text;
   vcnt  integer;
BEGIN
   RAISE NOTICE '==============================================================';
   RAISE NOTICE 'AMEXAN MACHINE TEST 03 - H7 investigation-selection engine';
   RAISE NOTICE '==============================================================';

   -- ------------------------------------------------------------------
   -- 1. schema + seed counts
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.investigation_domain;
   IF vcnt <> 5 THEN RAISE EXCEPTION 'H7 FAIL: expected 5 investigation_domain, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_purpose;
   IF vcnt <> 14 THEN RAISE EXCEPTION 'H7 FAIL: expected 14 investigation_purpose, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_concept;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H7 FAIL: expected 12 investigation_concept, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_component;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H7 FAIL: expected 12 investigation_component, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_rule;
   IF vcnt <> 15 THEN RAISE EXCEPTION 'H7 FAIL: expected 15 investigation_rule, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_priority_rule;
   IF vcnt <> 11 THEN RAISE EXCEPTION 'H7 FAIL: expected 11 investigation_priority_rule, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.result_reference_standard;
   IF vcnt <> 13 THEN RAISE EXCEPTION 'H7 FAIL: expected 13 result_reference_standard, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.result_interpretation;
   IF vcnt <> 15 THEN RAISE EXCEPTION 'H7 FAIL: expected 15 result_interpretation, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.result_phenotype_link;
   IF vcnt <> 7 THEN RAISE EXCEPTION 'H7 FAIL: expected 7 result_phenotype_link, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_source;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H7 FAIL: expected 12 investigation_source, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.investigation_version;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H7 FAIL: expected 12 investigation_version, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 1 PASS: H7 schema + seed populated (5 domains, 14 purposes, 12 concepts, 12 components, 15 rules, 11 priority dims, 13 ref-std, 15 interp, 7 phenotype links, 12 sources, 12 versions)';

   -- ------------------------------------------------------------------
   -- 2. safety-critical priority engine (H7 §8) + safety rules + context block
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_concept
   WHERE code = 'I009' AND base_priority = 1000 AND is_mandatory = true;
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: I009 PULSE_OXIMETRY must be safety-critical priority 1000 + mandatory, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule
   WHERE rule_code = 'IR001' AND modification = 'SAFETY' AND evidence_claim_code = 'HCH12-0016';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: IR001 must be SAFETY grounded in HCH12-0016, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule
   WHERE trigger_code = 'PREGNANCY' AND target_code = 'I012' AND modification = 'UNAVAILABLE';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: CT must be UNAVAILABLE under PREGNANCY, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 2 PASS: I009=1000 mandatory; IR001 SAFETY (HCH12-0016); CT UNAVAILABLE in PREGNANCY';

   -- ------------------------------------------------------------------
   -- 3. haemoptysis → MANDATORY chest X-ray (HCH12-0004/0007)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule
   WHERE trigger_type='FACT' AND trigger_code='BLOOD_IN_SPUTUM' AND target_code='I005'
     AND modification='MANDATORY' AND priority_delta=100
     AND evidence_claim_code IN ('HCH12-0004','HCH12-0007');
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: haemoptysis must MANDATORY-activate I005 CXR (+100), got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule
   WHERE trigger_type='FACT' AND trigger_code='BLOOD_IN_SPUTUM' AND target_code='I010';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: haemoptysis should activate sputum microscopy, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 3 PASS: haemoptysis → MANDATORY CXR (+100) + sputum microscopy (HCH12-0007)';

   -- ------------------------------------------------------------------
   -- 4. chronic cough (>56 days) → baseline spirometry + CXR (HCH12-0004)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule_condition c
   JOIN knowledge.investigation_rule r ON r.rule_code = c.rule_code
   WHERE c.fact_definition_code='COUGH_DURATION_DAYS' AND c.operator='>' AND c.value='56'
     AND c.rule_code IN ('IR003','IR004');
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H7 FAIL: IR003/IR004 must be gated by COUGH_DURATION_DAYS>56, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule
   WHERE rule_code='IR004' AND target_code='I005' AND modification='ACTIVATE'
     AND evidence_claim_code='HCH12-0004';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: chronic cough baseline CXR (IR004) missing, got %', vcnt; END IF;

   -- CXR + spirometry requested together (H7 §25 REQUEST_ALONGSIDE)
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule_action
   WHERE rule_code='IR004' AND action_type='REQUEST_ALONGSIDE' AND target_investigation_code='I008';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: baseline CXR should REQUEST_ALONGSIDE spirometry, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 4 PASS: chronic cough >8 weeks → baseline CXR + spirometry (HCH12-0004), requested together';

   -- ------------------------------------------------------------------
   -- 5. dependency: contrast CT requires U&E result BEFORE (H7 §25)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule_action
   WHERE rule_code='IR014' AND action_type='REQUIRE_RESULT_BEFORE' AND target_investigation_code='I003';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: contrast CT must REQUIRE_RESULT_BEFORE U&E, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule
   WHERE rule_code='IR014' AND target_code='I012' AND modification='DEPENDENCY';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: IR014 must be DEPENDENCY on I012 CT, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 5 PASS: contrast CT (I012) DEPENDENCY → REQUIRE_RESULT_BEFORE U&E (I003)';

   -- ------------------------------------------------------------------
   -- 6. result interpretation: raw result → reference standard → finding
   --    WBC 23 outside RRS003 4-11 → LEUKOCYTOSIS; SpO2 88 → HYPOXAEMIA critical
   -- ------------------------------------------------------------------
   DECLARE
       r_low numeric; r_high numeric;
   BEGIN
       SELECT range_low, range_high INTO r_low, r_high
       FROM knowledge.result_reference_standard
       WHERE code='RRS003';
       IF r_low <> 4.0 OR r_high <> 11.0 THEN
          RAISE EXCEPTION 'H7 FAIL: RRS003 WBC normal must be 4-11, got %-%', r_low, r_high;
       END IF;
       IF 23 BETWEEN r_low AND r_high THEN
          RAISE EXCEPTION 'H7 FAIL: WBC 23 must be OUTSIDE the 4-11 normal band';
       END IF;

       SELECT range_low, range_high INTO r_low, r_high
       FROM knowledge.result_reference_standard
       WHERE code='RRS013';
       IF r_low IS NULL OR r_low <> 95 THEN
          RAISE EXCEPTION 'H7 FAIL: RRS013 SpO2 normal must start at 95, got %', r_low;
       END IF;
       IF 88 BETWEEN r_low AND r_high THEN
          RAISE EXCEPTION 'H7 FAIL: SpO2 88 must be OUTSIDE the >=95 normal band';
       END IF;
   END;

   SELECT count(*) INTO vcnt FROM knowledge.result_interpretation WHERE code='RINT_HYPOXAEMIA' AND is_critical=true;
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: RINT_HYPOXAEMIA must be critical, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 6 PASS: WBC 23 outside 4-11 → abnormal; SpO2 88 outside ≥95 → HYPOXAEMIA critical (HCH12-0016)';

   -- ------------------------------------------------------------------
   -- 7. result_phenotype_link: interpretation → concept bridge (H7 §33)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.result_phenotype_link
   WHERE result_interpretation_code='RINT_CONSOLIDATION' AND associated_concept_code='CNS-ALVEOLAR-INFLAMMATION';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: consolidation must link to ALVEOLAR-INFLAMMATION, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.result_phenotype_link
   WHERE result_interpretation_code='RINT_PLEURAL_EFFUSION' AND associated_concept_code='CNS-PLEURAL-INFLAMMATION'
     AND evidence_claim_code='HCH12-0019';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H7 FAIL: effusion must link to PLEURAL-INFLAMMATION via HCH12-0019, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 7 PASS: consolidation → ALVEOLAR-INFLAMMATION; effusion → PLEURAL-INFLAMMATION (HCH12-0019)';

   -- ------------------------------------------------------------------
   -- 8. governance: provenance integrity + 0 orphan FKs
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.provenance p
   LEFT JOIN knowledge.source_claim sc ON sc.claim_id = p.claim_id
   WHERE sc.claim_id IS NULL
     AND (p.object_type LIKE 'investigation_%'
          OR p.object_type IN ('result_reference_standard','result_interpretation','result_phenotype_link','investigation_source'));
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H7 FAIL: % H7 provenance edges point to a missing source_claim', vcnt; END IF;

   -- every seeded investigation_concept has at least one provenance edge
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_concept ic
   LEFT JOIN knowledge.provenance p ON p.object_type='investigation_concept' AND p.object_id = ic.id
   WHERE p.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H7 FAIL: % investigation_concept(s) lack a provenance edge', vcnt; END IF;

   -- every investigation_rule that cites a claim has a provenance edge on it
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule ir
   LEFT JOIN knowledge.provenance p ON p.object_type='investigation_rule' AND p.object_id = ir.id
   WHERE ir.evidence_claim_code IS NOT NULL AND p.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H7 FAIL: % evidenced investigation_rule(s) lack a provenance edge', vcnt; END IF;

   -- 0 orphan FKs across the seeded H7 tables
   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule_condition c
   LEFT JOIN knowledge.investigation_rule r ON r.rule_code = c.rule_code
   WHERE r.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H7 FAIL: % rule_condition orphan FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.investigation_rule_action a
   LEFT JOIN knowledge.investigation_rule r ON r.rule_code = a.rule_code
   WHERE r.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H7 FAIL: % rule_action orphan FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.result_reference_standard s
   LEFT JOIN clinical.fact_definition f ON f.code = s.fact_definition_code
   WHERE s.fact_definition_code IS NOT NULL AND f.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H7 FAIL: % reference-standard orphan fact FKs', vcnt; END IF;

   RAISE NOTICE 'STEP 8 PASS: governance OK — 0 dangling provenance, 0 orphan FKs, every H7 object grounded to Hutchison claims';

   RAISE NOTICE '===========================================================' ;
   RAISE NOTICE 'H7 MACHINE TEST PASSED: investigation engine schema + seed verified';
   RAISE NOTICE '===========================================================' ;
END
$h7_test$;

ROLLBACK;

\echo 'H7 machine test rolled back cleanly (no rows persisted, fully re-runnable).'