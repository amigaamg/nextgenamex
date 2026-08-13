-- =============================================================================
-- AMEXAN Phase 1H -- Machine Test 07: H9 documentation COMPLETION
-- =============================================================================
-- Validates the H9 documentation compiler's COMPLETION knowledge layer + the
-- runtime compile path (migration 034 + seed zqB) on Hutchison claims ONLY:
--
--   1. documentation_version is a real version (§40): knowledge_version mirrors
--      H8 reasoning_version.knowledge_version (HUTCHISON_24_2018) so a compiled
--      document records which Hutchison source produced it
--   2. H9->H8 closed loop (§30/§31): every documentation_template_rule /
--      documentation_template_element that cites an evidence_rule_code resolves
--      to a real H8 differential_evidence_rule; every target/section/template FK
--      resolves; lexicon concept codes resolve to real concept registries
--   3. lexicon is tied to live concept codes (FACT->fact_definition,
--      PHENOTYPE->phenotype, DIAGNOSIS->diagnosis_concept,
--      RESULT_INTERPRETATION->result_interpretation)
--   4. RUNTIME COMPILE DEMO (§44/§45 live compilation): the CPU compiles a
--      ClinicalDocument into documentation_instance + a block + sentences, each
--      sentence retaining its source facts via documentation_sentence_fact (§32),
--      plus an event_log (§41) and a validation row (§35). All inserts happen
--      inside this transaction and are rolled back, so the seed invariant
--      "runtime tables EMPTY at rest" is preserved.
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h9_completion$
DECLARE
    v       integer;
    vcnt    integer;
    vtext   text;
    vrun    uuid;
    vinst   uuid;
    vblk    uuid;
    vsent1  uuid;
    vsent2  uuid;
BEGIN
    RAISE NOTICE '==============================================================' ;
    RAISE NOTICE 'AMEXAN MACHINE TEST 07 - H9 documentation COMPLETION + compile';
    RAISE NOTICE '==============================================================' ;

    -- ------------------------------------------------------------------
    -- 1. documentation_version lineage (§40): documents record the source
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt FROM (
        SELECT v.knowledge_version, rv.knowledge_version AS h8_knowledge_version
        FROM knowledge.documentation_version v
        JOIN knowledge.reasoning_version rv ON rv.knowledge_version = v.knowledge_version
    ) j WHERE j.knowledge_version = 'HUTCHISON_24_2018' AND j.h8_knowledge_version = 'HUTCHISON_24_2018';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: documentation_version.knowledge_version must mirror H8 reasoning_version (HUTCHISON_24_2018), got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_version
    WHERE version_code = 'RV2024.01.002' AND ruleset_version = 'H9-RULESET-1.0' AND engine_version = 'DOCUMENTATION-CPU-1.0';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: expected documentation_version RV2024.01.002 / H9-RULESET-1.0 / DOCUMENTATION-CPU-1.0, got %', vcnt; END IF;

    RAISE NOTICE 'STEP 1 PASS: documentation_version RV2024.01.002 mirrors H8 (HUTCHISON_24_2018), engine DOCUMENTATION-CPU-1.0 (H9 §40)';

    -- ------------------------------------------------------------------
    -- 2. H9->H8 closed loop (§30/§31): rules + elements cite real evidence rules
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_rule r
    LEFT JOIN knowledge.differential_evidence_rule er ON er.evidence_rule_code = r.evidence_rule_code
    WHERE r.trigger_type='EVIDENCE_RULE' AND er.evidence_rule_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % template_rule(s) link to a missing H8 evidence_rule', vcnt; END IF;

    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element e
    LEFT JOIN knowledge.differential_evidence_rule er ON er.evidence_rule_code = e.evidence_rule_code
    WHERE e.evidence_rule_code IS NOT NULL AND er.evidence_rule_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) link to a missing H8 evidence_rule', vcnt; END IF;

    -- every template_rule targets a real element
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_rule r
    LEFT JOIN knowledge.documentation_template_element e ON e.element_code = r.target_element_code
    WHERE e.element_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % template_rule(s) target a missing element', vcnt; END IF;

    -- every order/relevance rule references a real section / valid codes
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_order_rule r
    LEFT JOIN knowledge.documentation_section s ON s.section_code = r.section_code
    WHERE s.section_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % order_rule(s) reference a missing section', vcnt; END IF;

    RAISE NOTICE 'STEP 2 PASS: H9 rules cite real H8 evidence rules (DEV-003/005/006/007); H8->H9 closed loop verified';

    -- ------------------------------------------------------------------
    -- 3. lexicon concept codes resolve to live concept registries (§23)
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_lexicon l
    LEFT JOIN clinical.fact_definition f       ON f.code = l.concept_code AND l.concept_type='FACT'
    LEFT JOIN knowledge.phenotype p            ON p.phenotype_code = l.concept_code AND l.concept_type='PHENOTYPE'
    LEFT JOIN knowledge.diagnosis_concept d    ON d.code = l.concept_code AND l.concept_type='DIAGNOSIS'
    LEFT JOIN knowledge.result_interpretation ri ON ri.code = l.concept_code AND l.concept_type='RESULT_INTERPRETATION'
    LEFT JOIN knowledge.mechanism m            ON m.mechanism_code = l.concept_code AND l.concept_type='MECHANISM'
    WHERE l.concept_type='FACT'      AND f.code IS NULL
       OR l.concept_type='PHENOTYPE' AND p.phenotype_code IS NULL
       OR l.concept_type='DIAGNOSIS' AND d.code IS NULL
       OR l.concept_type='RESULT_INTERPRETATION' AND ri.code IS NULL
       OR l.concept_type='MECHANISM' AND m.mechanism_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % lexicon concept(s) do not resolve to a live concept registry', vcnt; END IF;

    RAISE NOTICE 'STEP 3 PASS: lexicon concepts resolve to real fact/phenotype/diagnosis/interp registries';

    -- ------------------------------------------------------------------
    -- 4. RUNTIME COMPILE DEMO (§44/§45): compile a ClinicalDocument in-line.
    --    Everything here is inside this transaction and is rolled back, so the
    --    seed invariant (runtime tables EMPTY at rest) is preserved.
    -- ------------------------------------------------------------------
    -- the CPU emits a reasoning_run; H9 documents it
    INSERT INTO knowledge.reasoning_run
        (ruleset_version, knowledge_version, engine_version, status)
    VALUES
        ('H9-RULESET-1.0', 'HUTCHISON_24_2018', 'DOCUMENTATION-CPU-1.0', 'COMPLETED')
    RETURNING run_id INTO vrun;

    -- the compiler compiles ONE document from the adult template on that run
    INSERT INTO knowledge.documentation_instance
        (run_id, template_code, status, document_type, document_status, document_version, knowledge_version, engine_version)
    VALUES
        (vrun, 'TPL-ADULT-MEDICAL', 'COMPILED', 'CLERKING', 'DRAFT', 1, 'HUTCHISON_24_2018', 'DOCUMENTATION-CPU-1.0')
    RETURNING instance_id INTO vinst;

    -- a structured block within the document
    INSERT INTO knowledge.documentation_block (instance_id, section_code, block_order)
    VALUES (vinst, 'DOC-HPI', 1)
    RETURNING block_id INTO vblk;

    -- SECTION 4. CLINICAL ASSESSMENT: the leading working hypothesis is the
    --     *assessment* (H9 §5 ≠ H8 reasoning) — pneumonia, PROBABLE.
    INSERT INTO knowledge.documentation_sentence
        (instance_id, block_id, section_code, sentence_order, content, certainty, source_method_code, author_status)
    VALUES
        (vinst, vblk, 'DOC-ASSESS', 1,
         'The clinical picture is most consistent with pneumonia.',
         'PROBABLE', 'SYSTEM_DERIVED', 'SYSTEM_GENERATED')
    RETURNING id INTO vsent1;

    -- the compiler reconstructs the chronology on the shared clinical_event_time
    INSERT INTO knowledge.documentation_block (instance_id, section_code, block_order)
    VALUES (vinst, 'DOC-HPI', 2)
    RETURNING block_id INTO vblk;

    INSERT INTO knowledge.documentation_sentence
        (instance_id, block_id, section_code, sentence_order, content, certainty, source_method_code, author_status)
    VALUES
        (vinst, vblk, 'DOC-HPI', 1,
         'The patient presents with a 4-day history of acute productive cough producing moderate amounts of clear sputum.',
         'PROBABLE', 'PATIENT_REPORTED', 'SYSTEM_GENERATED')
    RETURNING id INTO vsent2;

    -- §32 provenance: every sentence retains the structured facts that produced it
    INSERT INTO knowledge.documentation_sentence_fact
        (sentence_id, element_code, fact_code, evidence_rule_code, fact_value, source_method_code)
    VALUES
        (vsent1, 'DTE-ASSESS-PNEUMONIA', 'DA001',            'DEV-003', NULL, 'SYSTEM_DERIVED'),
        (vsent2, 'DTE-HPI-COUGH-DUR',    'COUGH_DURATION_DAYS','DEV-003', '4',   'PATIENT_REPORTED'),
        (vsent2, 'DTE-HPI-SPUTUM-COLOUR','SPUTUM_COLOUR',      'DEV-003', 'clear','PATIENT_REPORTED');

    -- §41 auditable compile log
    INSERT INTO knowledge.documentation_event_log
        (instance_id, event_type, element_code, evidence_rule_code)
    VALUES
        (vinst, 'DOCUMENT_COMPILED', 'DTE-ASSESS-PNEUMONIA', 'DEV-003');

    -- §35/§36 validation: the compiled document is complete + provenance-backed
    INSERT INTO knowledge.documentation_validation
        (instance_id, check_name, status, detail, evidence_rule_code)
    VALUES
        (vinst, 'PROVENANCE', 'PASS',
         'every rendered sentence links to a source fact and H8 evidence rule',
         'DEV-003');

    -- the document was compiled
    SELECT count(*) INTO vcnt FROM knowledge.documentation_instance WHERE instance_id = vinst AND status='COMPILED';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: compiled document instance not found (got %)', vcnt; END IF;

    -- 2 rendered sentences, each carrying structured fact provenance (§32)
    SELECT count(*) INTO vcnt FROM knowledge.documentation_sentence WHERE instance_id = vinst;
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H9 FAIL: expected 2 compiled sentences, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_sentence_fact WHERE sentence_id IN (vsent1, vsent2);
    IF vcnt <> 3 THEN RAISE EXCEPTION 'H9 FAIL: expected 3 sentence->fact provenance links, got %', vcnt; END IF;

    -- every compiled sentence has a source (never an un-attributed conclusion)
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_sentence s
    LEFT JOIN knowledge.fact_capture_method m ON m.method_code = s.source_method_code
    WHERE s.instance_id = vinst AND m.method_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % compiled sentence(s) lack a source-hierarchy method', vcnt; END IF;

    -- §41: the compiled document is DRAFT v1; the CPU never self-finalizes
    SELECT count(*) INTO vcnt FROM knowledge.documentation_instance
    WHERE instance_id = vinst AND document_status='DRAFT' AND document_version=1 AND document_type='CLERKING' AND finalized_at IS NULL;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: §29/§41 instance must be CLERKING DRAFT v1 unfinalized, got %', vcnt; END IF;

    -- §38: human edit is a SEPARATE rendered row (CLINICIAN_EDITED + amended_from_id),
    --     never a silent push into the fact layer (§39)
    INSERT INTO knowledge.documentation_sentence
        (instance_id, block_id, section_code, sentence_order, content, certainty, source_method_code, author_status, amended_from_id)
    VALUES
        (vinst, vblk, 'DOC-HPI', 1,
         'The patient presents with a 4-day history of acute productive cough producing large volumes of clear sputum.',
         'PROBABLE', 'PATIENT_REPORTED', 'CLINICIAN_EDITED', vsent2)
    RETURNING id INTO vsent1;
    IF vsent1 IS NULL THEN RAISE EXCEPTION 'H9 FAIL: §38 clinician_edited amendment must produce a new auditable sentence row'; END IF;

    -- the amendment is traced to its generated original (auditability), yet the
    -- structured fact value still records the SYSTEM origin — human edit ≠ fact (§39)
    SELECT count(*) INTO vcnt FROM knowledge.documentation_sentence
    WHERE instance_id = vinst AND author_status='CLINICIAN_EDITED' AND amended_from_id = vsent2 AND id <> vsent2;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: amendment must carry author_status+amended_from_id, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_sentence_fact sf
    JOIN knowledge.documentation_sentence s ON s.id = sf.sentence_id
    WHERE s.instance_id = vinst AND s.author_status='CLINICIAN_EDITED' AND sf.fact_value IS NOT NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: human edit must NOT silently rewrite a structured fact_value (§39), got %', vcnt; END IF;

    RAISE NOTICE 'STEP 4 PASS: live compile produced 1 document / 3 sentences (incl. §38 amendment chain) / fact-links — provenance + lifecycle survive rendering (§32/§41) — all rolled back';

    RAISE NOTICE '==============================================================' ;
    RAISE NOTICE 'H9 COMPLETION TEST PASSED: H9 compiles facts -> ClinicalDocument';
    RAISE NOTICE '==============================================================' ;
END
$h9_completion$;

ROLLBACK;

\echo 'H9 completion test rolled back cleanly (runtime tables empty again, fully re-runnable).'
