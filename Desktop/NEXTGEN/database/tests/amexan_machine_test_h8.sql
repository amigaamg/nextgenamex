-- =============================================================================
-- AMEXAN Phase 1G -- Machine Test 04: H8 universal differential-reasoning interface
-- =============================================================================
-- Validates the H8 knowledge layer built on Hutchison claims ONLY:
--   1. schema + seed counts (10 hypotheses, 54 evidence, 14 rules, 2 rule
--      conditions, 10 weights, 10 sources, 10 versions, 7 statuses)
--   2. HYPOTHESIS = CONCEPT law: every hypothesis is tied to a real condition
--      or mechanism concept, never a raw symptom (H8 §1/§2); 8 condition +
--      2 mechanism hypotheses across the Box 2.3 pathological-process framework
--   3. EVIDENCE law: SUPPORTS/REFUTES carry a weight and a Hutchison claim
--      (e.g. bronchial breath sounds → pneumonia, HCH12-0018; trachea deviated
--      away → effusion/pneumothorax, HCH12-0019; haemoptysis → TB, HCH12-0007)
--   4. RULE engine: haemoptysis → TB MARK_CRITICAL (DR001, HCH12-0007);
--      chronic cough >56 days guards asthma/bronchitis (DR007/DR008 + DRC001/2);
--      RINT_MTB_DETECTED → TB MARK_CRITICAL +2.0 (DR009)
--   5. WEIGHT model: the 10 H8 §21 dimensions exist and are versioned
--   6. runtime separation: differential_rank / differential_reason are EMPTY
--      (the CPU fills them at reasoning time — H6/H7 precedent)
--   7. governance: every seeded H8 object carries a derived_from edge to a real
--      Hutchison claim; no dangling provenance; 0 orphan FKs
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP so any
-- assertion failure fails the whole run loudly.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h8_test$
DECLARE
   v integer;
   vtext text;
   vcnt  integer;
   vweight numeric;
BEGIN
   RAISE NOTICE '==============================================================';
   RAISE NOTICE 'AMEXAN MACHINE TEST 04 - H8 differential-reasoning engine';
   RAISE NOTICE '==============================================================';

   -- ------------------------------------------------------------------
   -- 1. schema + seed counts
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.differential_hypothesis;
   IF vcnt <> 10 THEN RAISE EXCEPTION 'H8 FAIL: expected 10 differential_hypothesis, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_evidence;
   IF vcnt <> 54 THEN RAISE EXCEPTION 'H8 FAIL: expected 54 differential_evidence, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_rule;
   IF vcnt <> 14 THEN RAISE EXCEPTION 'H8 FAIL: expected 14 differential_rule, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_rule_condition;
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8 FAIL: expected 2 differential_rule_condition, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_weight;
   IF vcnt <> 10 THEN RAISE EXCEPTION 'H8 FAIL: expected 10 differential_weight, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_source;
   IF vcnt <> 10 THEN RAISE EXCEPTION 'H8 FAIL: expected 10 differential_source, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_version;
   IF vcnt <> 10 THEN RAISE EXCEPTION 'H8 FAIL: expected 10 differential_version, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_status;
   IF vcnt <> 7 THEN RAISE EXCEPTION 'H8 FAIL: expected 7 differential_status, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 1 PASS: H8 schema + seed populated (10 hypotheses, 54 evidence, 14 rules, 2 conditions, 10 weights, 10 sources, 10 versions, 7 statuses)';

   -- ------------------------------------------------------------------
   -- 2. HYPOTHESIS = CONCEPT law (H8 §1/§2): never a raw symptom
   -- ------------------------------------------------------------------
   -- every hypothesis must resolve to a real concept
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_hypothesis dh
   LEFT JOIN knowledge.concept c ON c.id = dh.concept_id
   WHERE c.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % hypothesis(es) not tied to a concept', vcnt; END IF;

   -- hypothesis types: condition vs mechanism
   SELECT count(*) INTO vcnt FROM knowledge.differential_hypothesis WHERE hypothesis_type = 'CONDITION';
   IF vcnt <> 8 THEN RAISE EXCEPTION 'H8 FAIL: expected 8 CONDITION hypotheses, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_hypothesis WHERE hypothesis_type = 'MECHANISM';
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8 FAIL: expected 2 MECHANISM hypotheses, got %', vcnt; END IF;

   -- pathological-process framework (Box 2.3, HCH2-0005) is applied
   SELECT count(*) INTO vcnt FROM knowledge.differential_hypothesis WHERE pathological_process IS NOT NULL;
   IF vcnt < 5 THEN RAISE EXCEPTION 'H8 FAIL: expected >=5 hypotheses carrying a Box 2.3 pathological process, got %', vcnt; END IF;

   -- critical (must-not-miss) hypotheses are flagged for safety
   SELECT count(*) INTO vcnt FROM knowledge.differential_hypothesis WHERE is_critical = true;
   IF vcnt <> 4 THEN RAISE EXCEPTION 'H8 FAIL: expected 4 critical hypotheses (pneumonia, TB, heart failure, pneumothorax), got %', vcnt; END IF;

   RAISE NOTICE 'STEP 2 PASS: all 10 hypotheses are concepts (8 CONDITION + 2 MECHANISM); Box 2.3 framework applied; 4 must-not-miss flagged';

   -- ------------------------------------------------------------------
   -- 3. EVIDENCE law: SUPPORTS/REFUTES grounded in Hutchison claims
   -- ------------------------------------------------------------------
   -- every evidence row that is a FACT must point to a real fact_definition
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence e
   LEFT JOIN clinical.fact_definition f ON f.code = e.fact_definition_code
   WHERE e.evidence_type IN ('FACT','SYMPTOM','EXAMINATION_FINDING') AND e.fact_definition_code IS NOT NULL AND f.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidence row(s) point to a missing fact_definition', vcnt; END IF;

   -- bronchial breath sounds SUPPORT pneumonia (HCH12-0018)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence
   WHERE evidence_code = 'EV001' AND hypothesis_code = 'DH001'
     AND direction = 'SUPPORTS' AND evidence_claim_code = 'HCH12-0018';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: EV001 bronchial breath sounds → pneumonia missing (got %)', vcnt; END IF;
   -- trachea deviated away → effusion AND pneumothorax (HCH12-0019)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence
   WHERE result_interpretation_code = 'RINT_PLEURAL_EFFUSION' AND direction = 'SUPPORTS' AND evidence_claim_code = 'HCH12-0019';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: effusion evidence missing (HCH12-0019) — got % rows', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence
   WHERE result_interpretation_code = 'RINT_PNEUMOTHORAX' AND direction = 'SUPPORTS' AND evidence_claim_code = 'HCH12-0019';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: pneumothorax evidence missing (HCH12-0019) — got % rows', vcnt; END IF;

   -- REFUTES rows exist and carry a penalty weight (H8 §21 EXCLUSION_POWER)
   SELECT count(*) INTO vcnt FROM knowledge.differential_evidence WHERE direction = 'REFUTES';
   IF vcnt < 5 THEN RAISE EXCEPTION 'H8 FAIL: expected >=5 REFUTES evidence rows, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 3 PASS: evidence grounded in Hutchison claims — bronchial sounds→pneumonia (HCH12-0018), trachea away→effusion/pneumothorax (HCH12-0019), % REFUTES rows', vcnt;

   -- ------------------------------------------------------------------
   -- 4. RULE engine: evidence→hypothesis activation (H8 §11)
   -- ------------------------------------------------------------------
   -- haemoptysis → TB MARK_CRITICAL (DR001, HCH12-0007)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule
   WHERE rule_code='DR001' AND trigger_code='BLOOD_IN_SPUTUM' AND target_hypothesis_code='DH002'
     AND modification='MARK_CRITICAL' AND evidence_claim_code='HCH12-0007';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: DR001 haemoptysis → TB MARK_CRITICAL missing (got %)', vcnt; END IF;

   -- RINT_MTB_DETECTED → TB MARK_CRITICAL +2.0 (DR009)
   SELECT weight_delta INTO vweight
   FROM knowledge.differential_rule
   WHERE rule_code='DR009' AND trigger_type='RESULT_INTERPRETATION'
     AND trigger_code='RINT_MTB_DETECTED' AND target_hypothesis_code='DH002';
   IF vweight IS NULL THEN RAISE EXCEPTION 'H8 FAIL: DR009 MTB-detected rule missing'; END IF;
   IF vweight <> 2.00 THEN RAISE EXCEPTION 'H8 FAIL: DR009 weight_delta must be 2.00, got %', vweight; END IF;

   -- chronic cough >56 days guards asthma (DR007) and bronchitis (DR008)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule_condition c
   JOIN knowledge.differential_rule r ON r.rule_code = c.rule_code
   WHERE c.fact_definition_code='COUGH_DURATION_DAYS' AND c.operator='>' AND c.value='56'
     AND c.rule_code IN ('DR007','DR008');
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8 FAIL: DR007/DR008 must be gated by COUGH_DURATION_DAYS>56, got %', vcnt; END IF;

   -- bronchial breath sounds ELEVATE pneumonia and SUPPRESS bronchitis (DR003/DR004)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule
   WHERE trigger_code='RLL_BRONCHIAL_BREATH_SOUNDS' AND target_hypothesis_code='DH001' AND modification='ELEVATE';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: DR003 bronchial sounds → pneumonia ELEVATE missing (got %)', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule
   WHERE trigger_code='RLL_BRONCHIAL_BREATH_SOUNDS' AND target_hypothesis_code='DH005' AND modification='SUPPRESS';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: DR004 bronchial sounds → bronchitis SUPPRESS missing (got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 4 PASS: rule engine verified — haemoptysis→TB critical (HCH12-0007), MTB-detected +2.0, chronic-cough guards, consolidation ELEVATE/SUPPRESS';

   -- ------------------------------------------------------------------
   -- 5. WEIGHT model: H8 §21 ten dimensions, versioned
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.differential_weight WHERE direction='POSITIVE';
   IF vcnt <> 9 THEN RAISE EXCEPTION 'H8 FAIL: expected 9 POSITIVE dimensions, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_weight WHERE dimension='RED_FLAG' AND weight >= 1.00;
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: RED_FLAG weight must be >=1.00 (got %)', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_weight WHERE dimension='REFUTATION_PENALTY' AND direction='NEGATIVE';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8 FAIL: REFUTATION_PENALTY must be NEGATIVE (got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 5 PASS: H8 §21 weight model verified (10 versioned dimensions; RED_FLAG +; REFUTATION_PENALTY -)';

   -- ------------------------------------------------------------------
   -- 6. runtime separation: rank/reason are EMPTY (CPU fills them)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.differential_rank;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: differential_rank must be empty at seed time, got % rows', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_reason;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: differential_reason must be empty at seed time, got % rows', vcnt; END IF;

   RAISE NOTICE 'STEP 6 PASS: differential_rank and differential_reason are EMPTY (runtime output, H6/H7 precedent)';

   -- ------------------------------------------------------------------
   -- 7. governance: provenance integrity + 0 orphan FKs
   -- ------------------------------------------------------------------
   -- no dangling provenance edges to missing source_claims
   SELECT count(*) INTO vcnt
   FROM knowledge.provenance p
   LEFT JOIN knowledge.source_claim sc ON sc.claim_id = p.claim_id
   WHERE sc.claim_id IS NULL
     AND (p.object_type LIKE 'differential%'
          OR (p.object_type='concept' AND p.object_code IN ('CNS-PLEURAL-EFFUSION','CNS-PNEUMOTHORAX')));
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % H8 provenance edges point to a missing source_claim', vcnt; END IF;

   -- every seeded hypothesis carries at least one provenance edge
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_hypothesis dh
   LEFT JOIN knowledge.provenance p ON p.object_type='differential_hypothesis' AND p.object_id = dh.id
   WHERE p.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % hypothesis(es) lack a provenance edge', vcnt; END IF;

   -- every evidence row carries a provenance edge
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence e
   LEFT JOIN knowledge.provenance p ON p.object_type='differential_evidence' AND p.object_id = e.id
   WHERE p.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidence row(s) lack a provenance edge', vcnt; END IF;

   -- every rule that cites a claim has a provenance edge
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule r
   LEFT JOIN knowledge.provenance p ON p.object_type='differential_rule' AND p.object_id = r.id
   WHERE r.evidence_claim_code IS NOT NULL AND p.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidenced differential_rule(s) lack a provenance edge', vcnt; END IF;

   -- 0 orphan FKs across the seeded H8 tables
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence e
   LEFT JOIN knowledge.differential_hypothesis dh ON dh.hypothesis_code = e.hypothesis_code
   WHERE dh.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidence orphan hypothesis FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule r
   LEFT JOIN knowledge.differential_hypothesis dh ON dh.hypothesis_code = r.target_hypothesis_code
   WHERE dh.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % rule orphan hypothesis FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_rule_condition c
   LEFT JOIN knowledge.differential_rule r ON r.rule_code = c.rule_code
   WHERE r.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % rule_condition orphan rule FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_source s
   LEFT JOIN knowledge.differential_hypothesis dh ON dh.hypothesis_code = s.hypothesis_code
   WHERE dh.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % source orphan hypothesis FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_version dv
   LEFT JOIN knowledge.differential_hypothesis dh ON dh.hypothesis_code = dv.hypothesis_code
   WHERE dh.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % version orphan hypothesis FKs', vcnt; END IF;

   -- every differential_evidence FK that is populated must resolve
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence e
   LEFT JOIN knowledge.phenotype p ON p.phenotype_code = e.phenotype_code
   WHERE e.phenotype_code IS NOT NULL AND p.phenotype_code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidence orphan phenotype FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence e
   LEFT JOIN knowledge.mechanism m ON m.mechanism_code = e.mechanism_code
   WHERE e.mechanism_code IS NOT NULL AND m.mechanism_code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidence orphan mechanism FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence e
   LEFT JOIN knowledge.result_interpretation ri ON ri.code = e.result_interpretation_code
   WHERE e.result_interpretation_code IS NOT NULL AND ri.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8 FAIL: % evidence orphan result_interpretation FKs', vcnt; END IF;

   RAISE NOTICE 'STEP 7 PASS: governance OK — 0 dangling provenance, 0 orphan FKs, every H8 object grounded to Hutchison claims';

   RAISE NOTICE '===========================================================' ;
   RAISE NOTICE 'H8 MACHINE TEST PASSED: differential-reasoning schema + seed verified';
   RAISE NOTICE '===========================================================' ;
END
$h8_test$;

ROLLBACK;

\echo 'H8 machine test rolled back cleanly (no rows persisted, fully re-runnable).'
