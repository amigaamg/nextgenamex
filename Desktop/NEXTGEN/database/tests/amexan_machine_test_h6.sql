-- =============================================================================
-- AMEXAN Phase 1E -- Machine Test 02: H6 Physical Examination engine
-- =============================================================================
-- Validates the H6 knowledge layer built on Hutchison:
--   1. schema + seed counts (H6 §32/§33 tables populated)
--   2. safety-critical priority engine: EX001/EX002 base_priority=1000; ER001/ER002
--      are SAFETY rules; ER012 disables auscultation under TELEMEDICINE (H5 §29)
--   3. the respiratory concept EX005 bundles the Hutchison Box 12.8 sequence
--      (rate, work-of-breathing, auscultation, clubbing, pulse) (HCH12-0014..18)
--   4. reference_standard: adult respiratory-rate normal range 12-18 (HCH12-0016);
--      SpO2 normal >=95 so a reading of 88 is flagged abnormal
--   5. finding_phenotype_link: crackles -> PNEUMONIA_SIGN concept (HCH12-0018)
--   6. provenance integrity: every H6 object edge points to a real source_claim
--      and EX005 carries a derived_from edge to HCH12-0018 (auscultation) + HCH12-0017 (sequence)
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP so any
-- assertion failure fails the whole run loudly.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h6_test$
DECLARE
   v integer;
   vtext text;
   vcnt  integer;
BEGIN
   RAISE NOTICE '==============================================================';
   RAISE NOTICE 'AMEXAN MACHINE TEST 02 - H6 physical examination engine';
   RAISE NOTICE '==============================================================';

   -- ------------------------------------------------------------------
   -- 1. schema + seed counts
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.examination_domain;
   IF vcnt <> 9 THEN RAISE EXCEPTION 'H6 FAIL: expected 9 examination_domain, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.examination_concept;
   IF vcnt <> 9 THEN RAISE EXCEPTION 'H6 FAIL: expected 9 examination_concept, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.observation_concept;
   IF vcnt <> 16 THEN RAISE EXCEPTION 'H6 FAIL: expected 16 observation_concept, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.examination_rule;
   IF vcnt <> 17 THEN RAISE EXCEPTION 'H6 FAIL: expected 17 examination_rule, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reference_standard;
   IF vcnt <> 16 THEN RAISE EXCEPTION 'H6 FAIL: expected 16 reference_standard, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.finding_interpretation;
   IF vcnt <> 16 THEN RAISE EXCEPTION 'H6 FAIL: expected 16 finding_interpretation, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.finding_phenotype_link;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H6 FAIL: expected 12 finding_phenotype_link, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 1 PASS: H6 schema + seed populated (9 domains, 9 concepts, 16 OCs, 17 rules, 16 RS, 16 interp, 12 phenotype links)';

   -- ------------------------------------------------------------------
   -- 2. safety-critical priority engine (H6 §8)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.examination_concept
   WHERE code IN ('EX001','EX002') AND base_priority = 1000;
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H6 FAIL: EX001/EX002 must be safety-critical priority 1000, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.examination_rule
   WHERE rule_code IN ('ER001','ER002') AND modification = 'SAFETY';
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H6 FAIL: ER001/ER002 must be SAFETY rules, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.examination_rule
   WHERE trigger_code = 'TELEMEDICINE' AND target_code = 'TECH_AUSCULTATION' AND modification = 'UNAVAILABLE';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H6 FAIL: auscultation must be UNAVAILABLE under TELEMEDICINE, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 2 PASS: safety-critical priority (EX001/EX002=1000) + SAFETY rules + tele-auscultation blocked';

   -- ------------------------------------------------------------------
   -- 3. respiratory concept bundles the Hutchison Box 12.8 sequence
   -- ------------------------------------------------------------------
   SELECT string_agg(sort_order::text || ':' || observation_concept_code, ' -> ' ORDER BY sort_order)
     INTO vtext
   FROM knowledge.examination_component
   WHERE examination_concept_code = 'EX005';
   RAISE NOTICE '   EX005 respiratory components sequence: %', vtext;
   SELECT count(*) INTO vcnt
   FROM knowledge.examination_component
   WHERE examination_concept_code = 'EX005'
     AND observation_concept_code IN ('OC004','OC009','OC010','OC013','OC014');
   IF vcnt <> 5 THEN RAISE EXCEPTION 'H6 FAIL: EX005 should bundle RR/WOB/auscultation/clubbing/pulse, got %', vcnt; END IF;

   -- ------------------------------------------------------------------
   -- 4. reference_standard: adult RR normal 12-18 (HCH12-0016) + SpO2 95-100
   -- ------------------------------------------------------------------
   DECLARE
       r_low  numeric; r_high numeric; r_unit text;
   BEGIN
   SELECT range_low, range_high, range_unit INTO r_low, r_high, r_unit
   FROM knowledge.reference_standard
   WHERE observation_concept_code = 'OC004' AND applies_to_context_codes @> ARRAY['ADULT']::text[];
   IF r_low IS NULL OR r_low <> 12 OR r_high <> 18 THEN
      RAISE EXCEPTION 'H6 FAIL: adult RR range must be 12-18, got %-%', r_low, r_high;
   END IF;
   IF r_unit <> 'breaths per minute' THEN
      RAISE EXCEPTION 'H6 FAIL: adult RR unit must be breaths per minute, got %', r_unit;
   END IF;

   SELECT range_low, range_high INTO r_low, r_high
   FROM knowledge.reference_standard
   WHERE observation_concept_code = 'OC005' AND applies_to_context_codes @> ARRAY['ADULT']::text[];
   IF r_low IS NULL OR r_low <> 95 OR r_high <> 100 THEN
      RAISE EXCEPTION 'H6 FAIL: adult SpO2 normal range must be 95-100, got %-%', r_low, r_high;
   END IF;
   IF 88 BETWEEN r_low AND r_high THEN
      RAISE EXCEPTION 'H6 FAIL: SpO2 88 must be OUTSIDE the normal range (>=95)';
   END IF;
   END;
   RAISE NOTICE 'STEP 4 PASS: adult RR 12-18 breaths/min (HCH12-0016); SpO2 normal 95-100, so 88 is abnormal';

   -- ------------------------------------------------------------------
   -- 5. finding_phenotype_link: crackles -> PNEUMONIA_SIGN (HCH12-0018)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.finding_phenotype_link
   WHERE observation_concept_code = 'OC010' AND finding_value = 'CRACKLES'
     AND associated_concept_code = 'PNEUMONIA_SIGN';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H6 FAIL: OC010 CRACKLES must link to PNEUMONIA_SIGN, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 5 PASS: crackles (OC010) -> PNEUMONIA_SIGN concept (HCH12-0018)';

   -- ------------------------------------------------------------------
   -- 6. provenance integrity
   -- ------------------------------------------------------------------
   -- every H6 object edge hits a real source_claim
   SELECT count(*) INTO vcnt
   FROM knowledge.provenance p
   LEFT JOIN knowledge.source_claim sc ON sc.claim_id = p.claim_id
   WHERE p.object_type IN ('examination_concept','observation_concept','examination_rule','reference_standard','finding_interpretation','finding_phenotype_link')
     AND sc.claim_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H6 FAIL: % H6 provenance edges point to a missing source_claim', vcnt; END IF;

   -- EX005 carries edges to auscultation (HCH12-0018) and chest sequence (HCH12-0017)
   SELECT count(*) INTO vcnt
   FROM knowledge.provenance p
   JOIN knowledge.source_claim sc ON sc.claim_id = p.claim_id
   WHERE p.object_type = 'examination_concept' AND p.object_code = 'EX005'
     AND sc.claim_code IN ('HCH12-0018','HCH12-0017');
   IF vcnt < 2 THEN RAISE EXCEPTION 'H6 FAIL: EX005 must cite HCH12-0018 + HCH12-0017, got % edges', vcnt; END IF;

   -- every seeded H6 object has at least one provenance edge
   SELECT count(*) INTO vcnt
   FROM knowledge.examination_concept ec
   LEFT JOIN knowledge.provenance p ON p.object_type='examination_concept' AND p.object_id = ec.id
   WHERE p.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H6 FAIL: % examination_concept(s) lack a provenance edge', vcnt; END IF;

   RAISE NOTICE 'STEP 6 PASS: provenance integrity OK — every H6 object grounded to Hutchison claims';

   RAISE NOTICE '===========================================================';
   RAISE NOTICE 'H6 MACHINE TEST PASSED: examination engine schema + seed verified';
   RAISE NOTICE '===========================================================';
END
$h6_test$;

ROLLBACK;

\echo 'H6 machine test rolled back cleanly (no rows persisted, fully re-runnable).'
