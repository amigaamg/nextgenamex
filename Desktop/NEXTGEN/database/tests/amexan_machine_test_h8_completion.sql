-- =============================================================================
-- AMEXAN Phase 1G -- Machine Test 05: H8 universal differential-reasoning COMPLETION
-- =============================================================================
-- Validates the H8 COMPLETION knowledge layer (migration 033 + seed zqA) built
-- on Hutchison claims ONLY. Migration 032 + seed zq9 proved the reasoning
-- SKELETON (hypotheses/evidence/rules/weights). This test proves the reasoning
-- CATALOGUE the CPU uses to structure a clinical interpretation:
--
--   1. schema + seed counts (diagnosis registry, expected evidence, criteria,
--      exclusions, rules, evidence rules, versions)
--   2. diagnosis_concept is a UNIVERSAL REGISTRY (H8 §34): every diagnosis is
--      tied to a real concept; DIAGNOSIS/MECHANISM/COMPLICATION are SEPARATE
--      types (§4); category reasoning_level prevents premature disease labeling
--      (§45); the Box 2.3 pathological-process framework is applied (HCH2-0005)
--   3. expected evidence (§19/§20/§37): EXPECTED vs OBSERVED tables exist —
--      consolidation VERY_HIGH + must-not-miss for pneumonia (HCH12-0018),
--      molecular MTB VERY_HIGH for TB (HCH12-0007)
--   4. diagnostic criteria (§23/§24): DCRIT001 AT_LEAST_N=3 (fever+cough+
--      dyspnoea); DCRIT003 TEST_REQUIRED on RINT_MTB_DETECTED — CONFIRMED is
--      never score>threshold, it must match a diagnostic standard; DCRIT007
--      TIME_REQUIREMENT; DCRIT004 ALL with a >56-day value guard
--   5. critical exclusions (§25): DEX001 EXCLUDES acute bronchitis on
--      COUGH_DURATION_DAYS>56; DEX004 DO_NOT_CONFIRM heart failure under pure
--      consolidation; DEX002 DEPRIORITIZE asthma on consolidation signs
--   6. four-state fact model (§9/§10/§11): PRESENT/ABSENT/UNKNOWN/NOT_ASSESSED/
--      NOT_APPLICABLE/CONFLICTING; ONLY PRESENT/ABSENT are DEFINITIVE —
--      UNKNOWN is NEVER treated as ABSENT (written safety rule, §11)
--   7. clinical_hypothesis_state (§22): CONSIDERED..REJECTED lifecycle with
--      explicit terminal states (EXCLUDED/CONFIRMED/REJECTED)
--   8. reasoning rules + CLOSED LOOP (§25/§30/§31): RR002 STRONGLY_SUPPORT
--      pneumonia (bronchial sounds, HCH12-0018); RR004 MARK_CRITICAL TB on
--      haemoptysis AND emits TRIGGER_INVESTIGATION I005/I011 +
--      CREATE_QUESTION_GAP TB_CONTACT (H8→H7 and H8→H3); RR010 gated by
--      COUGH_DURATION_DAYS>56; RR013 STRONGLY_SUPPORT hypoxaemia + ESCALATE
--   9. differential_evidence_rule (§38/§39): versioned candidate+proposition→
--      effect; DEV-003 STRONGLY_SUPPORTS pneumonia; DEV-005 ABSENCE
--      WEAKLY_OPPOSES (four-state absence, §9); DEV-006 <21 SUPPORTS vs
--      DEV-007 >56 OPPOSES are value-guarded opposites; rule_version=1
--  10. reasoning_version (§39/§40): a run must know WHICH ruleset/knowledge/
--      engine produced an assessment — RV2024.01.001 exists as data
--  11. runtime separation (§42): ALL 10 runtime tables (reasoning_run,
--      differential_candidate, differential_score, evidence ledger,
--      clinical_hypothesis, clinical_uncertainty, information gaps, events)
--      are EMPTY — the CPU computes them, the UI never does
--  12. governance: every seeded reasoning object carries a derived_from edge to
--      a real Hutchison claim; no dangling provenance; 0 orphan FKs
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP so any
-- assertion failure fails the whole run loudly.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h8c_test$
DECLARE
   v integer;
   vtext text;
   vcnt  integer;
   vweight numeric;
BEGIN
   RAISE NOTICE '==============================================================';
   RAISE NOTICE 'AMEXAN MACHINE TEST 05 - H8 differential-reasoning COMPLETION';
   RAISE NOTICE '==============================================================';

   -- ------------------------------------------------------------------
   -- 1. schema + seed counts (migration 033 + seed zqA)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_category;
   IF vcnt <> 9 THEN RAISE EXCEPTION 'H8C FAIL: expected 9 diagnosis_category, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_concept;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H8C FAIL: expected 12 diagnosis_concept, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_etiology;
   IF vcnt <> 7 THEN RAISE EXCEPTION 'H8C FAIL: expected 7 diagnosis_etiology, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_complication;
   IF vcnt <> 3 THEN RAISE EXCEPTION 'H8C FAIL: expected 3 diagnosis_complication, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_phenotype;
   IF vcnt <> 12 THEN RAISE EXCEPTION 'H8C FAIL: expected 12 diagnosis_phenotype, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_mechanism;
   IF vcnt <> 7 THEN RAISE EXCEPTION 'H8C FAIL: expected 7 diagnosis_mechanism, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnostic_expected_evidence;
   IF vcnt <> 31 THEN RAISE EXCEPTION 'H8C FAIL: expected 31 diagnostic_expected_evidence, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnostic_criterion;
   IF vcnt <> 8 THEN RAISE EXCEPTION 'H8C FAIL: expected 8 diagnostic_criterion, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnostic_criterion_condition;
   IF vcnt <> 17 THEN RAISE EXCEPTION 'H8C FAIL: expected 17 diagnostic_criterion_condition, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnostic_exclusion;
   IF vcnt <> 4 THEN RAISE EXCEPTION 'H8C FAIL: expected 4 diagnostic_exclusion, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_hypothesis_state;
   IF vcnt <> 9 THEN RAISE EXCEPTION 'H8C FAIL: expected 9 clinical_hypothesis_state, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_fact_state;
   IF vcnt <> 6 THEN RAISE EXCEPTION 'H8C FAIL: expected 6 clinical_fact_state, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reasoning_rule;
   IF vcnt <> 14 THEN RAISE EXCEPTION 'H8C FAIL: expected 14 reasoning_rule, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reasoning_rule_condition;
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: expected 1 reasoning_rule_condition, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reasoning_rule_action;
   IF vcnt <> 8 THEN RAISE EXCEPTION 'H8C FAIL: expected 8 reasoning_rule_action, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_evidence_rule;
   IF vcnt <> 25 THEN RAISE EXCEPTION 'H8C FAIL: expected 25 differential_evidence_rule, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reasoning_version;
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: expected 1 reasoning_version, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 1 PASS: H8 completion schema + seed populated (9 categories, 12 diagnoses, 7 etiologies, 3 complications, 12 phenotypes, 7 mechanisms, 31 expected-evidence, 8 criteria + 17 conditions, 4 exclusions, 9 hypothesis states, 6 fact states, 14 rules + 1 condition + 8 actions, 25 evidence rules, 1 reasoning version)';

   -- ------------------------------------------------------------------
   -- 2. diagnosis_concept = UNIVERSAL REGISTRY (H8 §34) — never 1 table per disease
   -- ------------------------------------------------------------------
   -- every diagnosis resolves to a real concept
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnosis_concept dc
   LEFT JOIN knowledge.concept c ON c.id = dc.concept_id
   WHERE c.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % diagnosis_concept(s) not tied to a concept', vcnt; END IF;

   -- diagnosis / mechanism / complication are SEPARATE reasoning types (§4)
   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_concept WHERE diagnosis_type='DIAGNOSIS';
   IF vcnt <> 8 THEN RAISE EXCEPTION 'H8C FAIL: expected 8 DIAGNOSIS concepts, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_concept WHERE diagnosis_type='MECHANISM';
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8C FAIL: expected 2 MECHANISM concepts, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_concept WHERE diagnosis_type='COMPLICATION';
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8C FAIL: expected 2 COMPLICATION concepts, got %', vcnt; END IF;

   -- reasoning levels (H8 §45): the category registry carries the full ladder
   SELECT count(DISTINCT reasoning_level) INTO vcnt FROM knowledge.diagnosis_category;
   IF vcnt <> 7 THEN RAISE EXCEPTION 'H8C FAIL: expected 7 distinct reasoning levels (SYNDROME..SEVERITY), got %', vcnt; END IF;

   -- Box 2.3 pathological-process framework (HCH2-0005) is applied to disease categories
   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_category
   WHERE pathological_process = 'INFECTIVE_INFLAMMATORY';
   IF vcnt < 1 THEN RAISE EXCEPTION 'H8C FAIL: infective/inflammatory Box 2.3 category missing'; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.diagnosis_category
   WHERE pathological_process = 'VASCULAR';
   IF vcnt < 1 THEN RAISE EXCEPTION 'H8C FAIL: vascular Box 2.3 category missing'; END IF;

   RAISE NOTICE 'STEP 2 PASS: diagnosis_concept is a universal registry — 8 DIAGNOSIS + 2 MECHANISM + 2 COMPLICATION concepts, all concept-bound, 7 reasoning levels, Box 2.3 framework';

   -- ------------------------------------------------------------------
   -- 3. expected evidence vs observed (H8 §19/§20/§37)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence
   WHERE diagnosis_code='DA001' AND evidence_type='EXAMINATION_FINDING'
     AND fact_definition_code='RLL_BRONCHIAL_BREATH_SOUNDS'
     AND expected_strength='VERY_HIGH' AND is_must_not_miss=true
     AND evidence_claim_code='HCH12-0018';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: pneumonia bronchial-sounds expected evidence (VERY_HIGH, must-not-miss, HCH12-0018) missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence
   WHERE diagnosis_code='DA001' AND evidence_type='RESULT_INTERPRETATION'
     AND result_interpretation_code='RINT_CONSOLIDATION'
     AND expected_strength='VERY_HIGH' AND is_must_not_miss=true
     AND evidence_claim_code='HCH12-0018';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: pneumonia consolidation expected evidence missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence
   WHERE diagnosis_code='DA004' AND evidence_type='RESULT_INTERPRETATION'
     AND result_interpretation_code='RINT_MTB_DETECTED'
     AND expected_strength='VERY_HIGH' AND is_must_not_miss=true
     AND evidence_claim_code='HCH12-0007';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: TB molecular expected evidence missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence
   WHERE diagnosis_code='DA003' AND evidence_type='FACT'
     AND fact_definition_code='ORTHOPNOEA' AND expected_strength='HIGH'
     AND evidence_claim_code='HCH12-0002';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: HF orthopnoea expected evidence missing'; END IF;

   -- every expected-evidence row is grounded in a Hutchison claim
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence
   WHERE evidence_claim_code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % expected-evidence row(s) lack a claim', vcnt; END IF;

   RAISE NOTICE 'STEP 3 PASS: EXPECTED vs OBSERVED catalogue present — pneumonia consolidation (VERY_HIGH, HCH12-0018), TB molecular (VERY_HIGH, HCH12-0007), HF orthopnoea (HIGH, HCH12-0002); 0 ungrounded rows';

   -- ------------------------------------------------------------------
   -- 4. diagnostic criteria — CONFIRMED requires a diagnostic standard (§23/§24)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion
   WHERE criterion_code='DCRIT001' AND diagnosis_code='DA001' AND logic='AT_LEAST_N' AND min_count=3
     AND diagnostic_standard=' Acute LRTI syndrome' AND evidence_claim_code='HCH12-0004';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DCRIT001 pneumonia AT_LEAST_N=3 missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion_condition
   WHERE criterion_code='DCRIT001' AND fact_definition_code IN ('FEVER_PRESENT','COUGH_PRESENT','DYSPNOEA_PRESENT') AND presence='PRESENT';
   IF vcnt <> 3 THEN RAISE EXCEPTION 'H8C FAIL: DCRIT001 must have fever+cough+dyspnoea conditions, got %', vcnt; END IF;

   -- TEST_REQUIRED: molecular MTB detection is the confirmation standard (not a score)
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion c
   JOIN knowledge.diagnostic_criterion_condition cc ON cc.criterion_code = c.criterion_code
   WHERE c.criterion_code='DCRIT003' AND c.logic='TEST_REQUIRED' AND c.diagnosis_code='DA004'
     AND cc.result_interpretation_code='RINT_MTB_DETECTED' AND cc.presence='PRESENT'
     AND c.evidence_claim_code='HCH12-0007';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DCRIT003 TB TEST_REQUIRED on RINT_MTB_DETECTED missing'; END IF;

   -- TIME_REQUIREMENT: acute cough < 21 days (§24)
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion c
   JOIN knowledge.diagnostic_criterion_condition cc ON cc.criterion_code = c.criterion_code
   WHERE c.criterion_code='DCRIT007' AND c.logic='TIME_REQUIREMENT' AND c.diagnosis_code='DA002'
     AND cc.fact_definition_code='COUGH_DURATION_DAYS' AND cc.operator='<' AND cc.value='21';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DCRIT007 bronchitis TIME_REQUIREMENT (duration<21) missing'; END IF;

   -- ALL logic with a >56-day value guard on the chronic constitutional TB syndrome
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion cc
   JOIN knowledge.diagnostic_criterion_condition ccc ON ccc.criterion_code = cc.criterion_code
   WHERE cc.criterion_code='DCRIT004' AND cc.logic='ALL'
     AND ccc.fact_definition_code='COUGH_DURATION_DAYS' AND ccc.operator='>' AND ccc.value='56';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DCRIT004 TB chronic syndrome must gate cough >56 days (got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 4 PASS: criteria structured — AT_LEAST_N=3 (LRTI), TEST_REQUIRED (TB molecular, NOT a score), TIME_REQUIREMENT (<21d), ALL (>56d guard) — CONFIRMED has an explicit standard (§23)';

   -- ------------------------------------------------------------------
   -- 5. critical exclusions (H8 §25)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_exclusion
   WHERE exclusion_code='DEX001' AND diagnosis_code='DA002' AND does_what='EXCLUDES'
     AND fact_definition_code='COUGH_DURATION_DAYS' AND evidence_claim_code='HCH12-0004';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DEX001 acute bronchitis EXCLUDES on chronic cough missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_exclusion
   WHERE exclusion_code='DEX004' AND diagnosis_code='DA003' AND does_what='DO_NOT_CONFIRM'
     AND fact_definition_code='RLL_BRONCHIAL_BREATH_SOUNDS' AND evidence_claim_code='HCH12-0018';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DEX004 HF DO_NOT_CONFIRM under pure consolidation missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_exclusion
   WHERE does_what='DEPRIORITIZE';
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8C FAIL: expected 2 DEPRIORITIZE exclusions, got %', vcnt; END IF;

   RAISE NOTICE 'STEP 5 PASS: exclusions data-driven — DEX001 EXCLUDES bronchitis on >56d, DEX004 DO_NOT_CONFIRM HF on consolidation, 2 DEPRIORITIZE';

   -- ------------------------------------------------------------------
   -- 6. four-state fact model (§9/§10/§11): UNKNOWN is NEVER ABSENT
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.clinical_fact_state
   WHERE state_code IN ('PRESENT','ABSENT','UNKNOWN','NOT_ASSESSED','NOT_APPLICABLE','CONFLICTING');
   IF vcnt <> 6 THEN RAISE EXCEPTION 'H8C FAIL: expected 6 clinical_fact_state rows, got %', vcnt; END IF;

   -- ONLY PRESENT/ABSENT are definitive; UNKNOWN and NOT_ASSESSED are not (§10/§11)
   SELECT count(*) INTO vcnt FROM knowledge.clinical_fact_state WHERE is_definitive = true;
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8C FAIL: exactly PRESENT/ABSENT must be definitive, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_fact_state
   WHERE state_code IN ('UNKNOWN','NOT_ASSESSED','NOT_APPLICABLE','CONFLICTING') AND is_definitive = true;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: UNKNOWN/NOT_ASSESSED/NOT_APPLICABLE/CONFLICTING must NOT be definitive (§11, got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 6 PASS: four-state model enforced — 6 states; only PRESENT/ABSENT definitive; UNKNOWN ≠ ABSENT written as data';

   -- ------------------------------------------------------------------
   -- 7. clinical_hypothesis_state lifecycle (§22)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.clinical_hypothesis_state WHERE is_terminal = true;
   IF vcnt <> 3 THEN RAISE EXCEPTION 'H8C FAIL: expected terminal EXCLUDED/CONFIRMED/REJECTED, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_hypothesis_state
   WHERE state_code NOT IN ('CONSIDERED','SUPPORTED','LEADING','POSSIBLE','UNLIKELY','DEPRIORITIZED','EXCLUDED','CONFIRMED','REJECTED');
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: hypothesis state vocabulary diverges from §22 (got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 7 PASS: hypothesis lifecycle CONSIDERED..REJECTED with exact §22 vocabulary and terminal states';

   -- ------------------------------------------------------------------
   -- 8. reasoning rules + the H3⇄H8 / H8⇄H7 CLOSED LOOP (§25/§30/§31)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule
   WHERE rule_code='RR002' AND trigger_type='FACT' AND trigger_code='RLL_BRONCHIAL_BREATH_SOUNDS'
     AND target_diagnosis_code='DA001' AND action='STRONGLY_SUPPORT' AND weight_delta=1.50
     AND evidence_claim_code='HCH12-0018';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: RR002 bronchial sounds STRONGLY_SUPPORT pneumonia missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule
   WHERE rule_code='RR004' AND trigger_type='FACT' AND trigger_code='BLOOD_IN_SPUTUM'
     AND target_diagnosis_code='DA004' AND action='MARK_CRITICAL'
     AND evidence_claim_code='HCH12-0007';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: RR004 haemoptysis MARK_CRITICAL TB missing'; END IF;

   -- closed loop: haemoptysis emits investigations (H8→H7, I005 CXR + I011 sputum molecular) AND an information gap (H8→H3, TB_CONTACT)
   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule_action
   WHERE rule_code='RR004' AND action_type='TRIGGER_INVESTIGATION' AND investigation_code IN ('I005','I011');
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8C FAIL: RR004 must trigger CXR + sputum-TB investigations, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule_action
   WHERE rule_code='RR004' AND action_type='CREATE_QUESTION_GAP' AND question_code='TB_CONTACT';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: RR004 must create the TB_CONTACT question gap (H8→H3, got %)', vcnt; END IF;

   -- guarded deprioritization: chronic cough >56 days deprioritizes acute bronchitis
   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule r
   LEFT JOIN knowledge.reasoning_rule_condition c ON c.rule_code = r.rule_code
   WHERE r.rule_code='RR010' AND r.action='DEPRIORITIZE' AND r.target_diagnosis_code='DA002'
     AND c.condition_code='RRC001' AND c.fact_definition_code='COUGH_DURATION_DAYS'
     AND c.operator='>' AND c.value='56' AND r.evidence_claim_code='HCH12-0004';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: RR010 must be guarded by COUGH_DURATION_DAYS>56 (got %)', vcnt; END IF;

   -- safety: hypoxaemia strongly supports respiratory failure and forces escalation
   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule
   WHERE rule_code='RR013' AND trigger_type='RESULT_INTERPRETATION' AND trigger_code='RINT_HYPOXAEMIA'
     AND target_diagnosis_code='DA011' AND action='STRONGLY_SUPPORT' AND weight_delta=2.00
     AND evidence_claim_code='HCH12-0016';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: RR013 hypoxaemia STRONGLY_SUPPORT respiratory failure missing'; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule_action
   WHERE rule_code='RR013' AND action_type='ESCALATE' AND question_code='' AND investigation_code='';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: RR013 must ESCALATE on hypoxaemia ('' = none, got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 8 PASS: rules data-driven — RR002 strong-support pneumonia, RR004 critical TB + closed loop (2 investigations + TB_CONTACT gap), RR010 guarded deprioritize, RR013 hypoxaemia escalate';

   -- ------------------------------------------------------------------
   -- 9. differential_evidence_rule — versioned candidate+proposition→effect (§38/§39)
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule
   WHERE evidence_rule_code='DEV-003' AND diagnosis_code='DA001'
     AND evidence_type='EXAMINATION_FINDING' AND fact_definition_code='RLL_BRONCHIAL_BREATH_SOUNDS'
     AND relationship='STRONGLY_SUPPORTS' AND base_strength=1.50
     AND rule_version=1 AND evidence_claim_code='HCH12-0018';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DEV-003 bronchial sounds STRONGLY_SUPPORTS pneumonia missing'; END IF;

   -- ABSENCE is a distinct evidence type: absence weakens but never eliminates (§9/§11)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule
   WHERE evidence_rule_code='DEV-005' AND evidence_type='ABSENCE'
     AND fact_definition_code='RLL_BRONCHIAL_BREATH_SOUNDS' AND relationship='WEAKLY_OPPOSES';
   IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: DEV-005 ABSENCE WEAKLY_OPPOSES (four-state absence) missing'; END IF;

   -- value-guarded opposites on the SAME proposition (§13 temporal; §9 absence)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule
   WHERE diagnosis_code='DA002' AND evidence_type='FACT' AND fact_definition_code='COUGH_DURATION_DAYS'
     AND ((operator='<' AND value='21' AND relationship='SUPPORTS')
      OR (operator='>' AND value='56' AND relationship='OPPOSES'));
   IF vcnt <> 2 THEN RAISE EXCEPTION 'H8C FAIL: DEV-006/DEV-007 must be value-guarded opposites (<21 SUPPORTS / >56 OPPOSES), got %', vcnt; END IF;

   -- every evidenced rule is versioned and claim-grounded (§39)
   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule
   WHERE evidence_claim_code IS NULL OR rule_version IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % evidence rule(s) lack claim/version', vcnt; END IF;

   RAISE NOTICE 'STEP 9 PASS: evidence rules versioned + claim-grounded — STRONGLY_SUPPORTS consolidation, ABSENCE WEAKLY_OPPOSES, value-guarded <21/>56 pair';

   -- ------------------------------------------------------------------
   -- 10. reasoning_version (§39/§40) — what AMEXAN knew when it assessed
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.reasoning_version
   WHERE version_code='RV2024.01.001' AND ruleset_version='H8-RULESET-1.0'
     AND knowledge_version='HUTCHISON_24_2018' AND engine_version='CLINICAL-CPU-1.0'
     AND status='active';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H8C FAIL: reasoning_version RV2024.01.001 missing/incorrect (got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 10 PASS: reasoning_version records ruleset/knowledge/engine — an assessment is reproducible';

   -- ------------------------------------------------------------------
   -- 11. runtime separation (§42): the CPU computes; the UI only renders
   -- ------------------------------------------------------------------
   SELECT count(*) INTO vcnt FROM knowledge.reasoning_run;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: reasoning_run must be empty at seed time, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_candidate;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: differential_candidate must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_score;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: differential_score must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.differential_evidence_ledger;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: differential_evidence_ledger must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_hypothesis;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: clinical_hypothesis must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_uncertainty;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: clinical_uncertainty must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.clinical_information_gap;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: clinical_information_gap must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.information_gap_question;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: information_gap_question must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.information_gap_investigation;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: information_gap_investigation must be empty, got %', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reasoning_event;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: reasoning_event must be empty, got %', vcnt; END IF;

   -- the RUNTIME SCHEMA itself supports the spec (multiple levels §45, types §44, quality §12)
   SELECT count(*) INTO vcnt FROM information_schema.columns
   WHERE table_schema='knowledge' AND table_name='differential_candidate'
     AND column_name IN ('candidate_type','current_status','reasoning_level');
    IF vcnt <> 3 THEN RAISE EXCEPTION 'H8C FAIL: differential_candidate must expose candidate_type/current_status/reasoning_level (got %)', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM information_schema.columns
   WHERE table_schema='knowledge' AND table_name='differential_evidence_ledger'
     AND column_name IN ('fact_state','quality_source','relationship','rule_version');
    IF vcnt <> 4 THEN RAISE EXCEPTION 'H8C FAIL: evidence ledger must expose fact_state/quality_source/relationship/rule_version (got %)', vcnt; END IF;

   RAISE NOTICE 'STEP 11 PASS: all 10 runtime tables EMPTY (CPU-only output); runtime schema supports §44/§45/§12 and the §7 evidence ledger';

   -- ------------------------------------------------------------------
   -- 12. governance: provenance integrity + 0 orphan FKs
   -- ------------------------------------------------------------------
   -- no dangling reasoning_provenance edges
   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_provenance rp
   LEFT JOIN knowledge.source_claim sc ON sc.claim_id = rp.claim_id
   WHERE sc.claim_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % reasoning_provenance edges point to a missing claim', vcnt; END IF;

   SELECT count(*) INTO vcnt FROM knowledge.reasoning_provenance;
   IF vcnt <> 130 THEN RAISE EXCEPTION 'H8C FAIL: expected 130 reasoning_provenance edges, got %', vcnt; END IF;

   -- every seeded diagnosis_concept carries a provenance edge
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnosis_concept dc
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnosis_concept' AND rp.object_id = dc.id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % diagnosis_concept(s) lack a provenance edge', vcnt; END IF;

   -- every diagnosis_phenotype / diagnosis_mechanism row carries an edge
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnosis_phenotype dp
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnosis_phenotype' AND rp.object_id = dp.id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % diagnosis_phenotype(s) lack a provenance edge', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnosis_mechanism dm
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnosis_mechanism' AND rp.object_id = dm.id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % diagnosis_mechanism(s) lack a provenance edge', vcnt; END IF;

   -- every expected-evidence / criterion / criterion-condition / exclusion / rule / evidence-rule row carries an edge
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence e
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnostic_expected_evidence' AND rp.object_id = e.id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % expected-evidence row(s) lack a provenance edge', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion c
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnostic_criterion' AND rp.object_id = c.criterion_id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % criterion row(s) lack a provenance edge', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion_condition cc
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnostic_criterion_condition' AND rp.object_id = cc.condition_id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % criterion-condition(s) lack a provenance edge', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_exclusion x
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='diagnostic_exclusion' AND rp.object_id = x.exclusion_id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % exclusion(s) lack a provenance edge', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule r
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='reasoning_rule' AND rp.object_id = r.id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % reasoning_rule(s) lack a provenance edge', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule dv
   LEFT JOIN knowledge.reasoning_provenance rp ON rp.object_type='differential_evidence_rule' AND rp.object_id = dv.id
   WHERE rp.object_id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % evidence-rule(s) lack a provenance edge', vcnt; END IF;

   -- 0 orphan FKs across the seeded completion tables
   SELECT count(*) INTO vcnt
   FROM knowledge.diagnosis_phenotype dp
   LEFT JOIN knowledge.phenotype p ON p.phenotype_code = dp.phenotype_code
   WHERE p.phenotype_code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % diagnosis_phenotype orphan phenotype FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnosis_mechanism dm
   LEFT JOIN knowledge.mechanism m ON m.mechanism_code = dm.mechanism_code
   WHERE m.mechanism_code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % diagnosis_mechanism orphan mechanism FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence e
   LEFT JOIN clinical.fact_definition f ON f.code = e.fact_definition_code
   WHERE e.fact_definition_code IS NOT NULL AND f.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % expected-evidence orphan fact FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_expected_evidence e
   LEFT JOIN knowledge.result_interpretation ri ON ri.code = e.result_interpretation_code
   WHERE e.result_interpretation_code IS NOT NULL AND ri.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % expected-evidence orphan interpretation FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion_condition cc
   LEFT JOIN clinical.fact_definition f ON f.code = cc.fact_definition_code
   WHERE cc.fact_definition_code IS NOT NULL AND f.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % criterion-condition orphan fact FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion_condition cc
   LEFT JOIN knowledge.result_interpretation ri ON ri.code = cc.result_interpretation_code
   WHERE cc.result_interpretation_code IS NOT NULL AND ri.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % criterion-condition orphan interpretation FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule dv
   LEFT JOIN clinical.fact_definition f ON f.code = dv.fact_definition_code
   WHERE dv.fact_definition_code IS NOT NULL AND f.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % evidence-rule orphan fact FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.differential_evidence_rule dv
   LEFT JOIN knowledge.result_interpretation ri ON ri.code = dv.result_interpretation_code
   WHERE dv.result_interpretation_code IS NOT NULL AND ri.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % evidence-rule orphan interpretation FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule r
   LEFT JOIN knowledge.diagnosis_concept dc ON dc.code = r.target_diagnosis_code
   WHERE r.target_diagnosis_code IS NOT NULL AND dc.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % reasoning_rule orphan diagnosis FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.reasoning_rule_action a
   LEFT JOIN knowledge.reasoning_rule r ON r.rule_code = a.rule_code
   WHERE r.id IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % reasoning_rule_action orphan rule FKs', vcnt; END IF;

   SELECT count(*) INTO vcnt
   FROM knowledge.diagnostic_criterion c
   LEFT JOIN knowledge.diagnosis_concept dc ON dc.code = c.diagnosis_code
   WHERE dc.code IS NULL;
   IF vcnt <> 0 THEN RAISE EXCEPTION 'H8C FAIL: % criterion orphan diagnosis FKs', vcnt; END IF;

   RAISE NOTICE 'STEP 12 PASS: governance OK — 130 provenance edges, 0 dangling, every reasoning object grounded to Hutchison claims, 0 orphan FKs';

   RAISE NOTICE '============================================================' ;
   RAISE NOTICE 'H8C MACHINE TEST PASSED: differential-reasoning COMPLETION verified';
   RAISE NOTICE '============================================================' ;
END
$h8c_test$;

ROLLBACK;

\echo 'H8 completion machine test rolled back cleanly (no rows persisted, fully re-runnable).'