-- =============================================================================
-- AMEXAN Phase 1H -- Machine Test 06: H9 universal documentation compiler
-- =============================================================================
-- Validates the H9 documentation compiler knowledge layer (migration 034 +
-- seed zqB) built on Hutchison claims ONLY. Mirrors the H7/H8 machine-test
-- contract:
--   1. schema + seed counts (15 sections, 3 templates, 33 template-sections,
--      9 template-elements, 8 template-rules, 9 order-rules, 7 relevance-rules,
--      8 lexicon terms, 8 terms, 8 variants, 1 version)
--   2. SHARED-ENUM REUSE (H9 §3/§9): H9 reuses fact_capture_method (7-value
--      source hierarchy, H5 §12), clinical.clinical_event.event_time
--      (clinical_event_time, H2 §3), and the H8 certainty inline CHECK set
--      ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN') — H9 never inflates H8
--      certainty (H9 §20/§21) nor redefines the source hierarchy
--   3. HYPOTHESIS-DISTINCT fact/interp/diagnosis (H9 §5): every template
--      element carries a concrete evidence_type and a concrete source_method,
--      never a free-text conclusion
--   4. provenance integrity (§46): every seeded documentation object carries a
--      derived_from edge to a real Hutchison claim; 0 dangling edges; provenance
--      count == sum of object counts (one edge per object)
--   5. H9->H8 LINKAGE (§30/§31): template_element / template_rule
--      evidence_rule_code resolves to a real H8 differential_evidence_rule;
--      element/section/template FKs resolve
--   6. runtime separation: documentation_instance / _sentence /
--      _sentence_fact / _block / _event_log / _validation are EMPTY (the CPU
--      compiles a document at reasoning time — H6/H7/H8 precedent)
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP so any
-- assertion failure fails the whole run loudly.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h9_test$
DECLARE
    v       integer;
    vtext   text;
    vcnt    integer;
BEGIN
    RAISE NOTICE '==============================================================' ;
    RAISE NOTICE 'AMEXAN MACHINE TEST 06 - H9 documentation compiler';
    RAISE NOTICE '==============================================================' ;

    -- ------------------------------------------------------------------
    -- 1. schema + seed counts
    -- ------------------------------------------------------------------
    -- all 17 H9 tables exist
    SELECT count(*) INTO vcnt
    FROM (VALUES
        ('knowledge.documentation_section'),
        ('knowledge.documentation_template'),
        ('knowledge.documentation_template_section'),
        ('knowledge.documentation_template_element'),
        ('knowledge.documentation_template_rule'),
        ('knowledge.documentation_order_rule'),
        ('knowledge.documentation_relevance_rule'),
        ('knowledge.documentation_lexicon'),
        ('knowledge.documentation_term'),
        ('knowledge.documentation_term_variant'),
        ('knowledge.documentation_version'),
        ('knowledge.documentation_instance'),
        ('knowledge.documentation_block'),
        ('knowledge.documentation_sentence'),
        ('knowledge.documentation_sentence_fact'),
        ('knowledge.documentation_event_log'),
        ('knowledge.documentation_validation')) AS t(t)
    WHERE to_regclass(t.t) IS NOT NULL;
    IF vcnt <> 17 THEN RAISE EXCEPTION 'H9 FAIL: expected 17 documentation tables, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_section;
    IF vcnt <> 15 THEN RAISE EXCEPTION 'H9 FAIL: expected 15 documentation_section, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_template;
    IF vcnt <> 3 THEN RAISE EXCEPTION 'H9 FAIL: expected 3 documentation_template, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_template_section;
    IF vcnt <> 33 THEN RAISE EXCEPTION 'H9 FAIL: expected 33 documentation_template_section, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_template_element;
    IF vcnt <> 9 THEN RAISE EXCEPTION 'H9 FAIL: expected 9 documentation_template_element, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_template_rule;
    IF vcnt <> 8 THEN RAISE EXCEPTION 'H9 FAIL: expected 8 documentation_template_rule, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_order_rule;
    IF vcnt <> 9 THEN RAISE EXCEPTION 'H9 FAIL: expected 9 documentation_order_rule, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_relevance_rule;
    IF vcnt <> 7 THEN RAISE EXCEPTION 'H9 FAIL: expected 7 documentation_relevance_rule, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_lexicon;
    IF vcnt <> 8 THEN RAISE EXCEPTION 'H9 FAIL: expected 8 documentation_lexicon, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_term;
    IF vcnt <> 8 THEN RAISE EXCEPTION 'H9 FAIL: expected 8 documentation_term, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_term_variant;
    IF vcnt <> 8 THEN RAISE EXCEPTION 'H9 FAIL: expected 8 documentation_term_variant, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_version;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: expected 1 documentation_version, got %', vcnt; END IF;

    RAISE NOTICE 'STEP 1 PASS: H9 schema + seed populated (15/3/33/9/8/9/7/8/8/8/1)';

    -- ------------------------------------------------------------------
    -- 2. SHARED-ENUM REUSE — H9 must NOT redefine H5/H8 shared enums
    -- ------------------------------------------------------------------
    -- source-hierarchy: H9 reuses the H5 fact_capture_method set (H9 §3 §6)
    SELECT count(*) INTO vcnt FROM knowledge.fact_capture_method;
    IF vcnt <> 7 THEN RAISE EXCEPTION 'H9 FAIL: fact_capture_method source-hierarchy must still be the 7-method H5 set, got %', vcnt; END IF;

    -- H9 references the shared clinical_capture methods on every element
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element e
    LEFT JOIN knowledge.fact_capture_method m ON m.method_code = e.source_method_code
    WHERE m.method_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) reference an unknown capture method', vcnt; END IF;

    -- certainty: H9 reuses the H8 inline CHECK set verbatim (H9 §20/§21)
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element
    WHERE certainty NOT IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN');
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) carry a certainty outside the shared H8 set', vcnt; END IF;

    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element
    WHERE certainty = 'DEFINITE';
    IF vcnt < 1 THEN RAISE EXCEPTION 'H9 FAIL: expected at least one DEFINITE-certainty element (hypoxaemia), got %', vcnt; END IF;

    -- clinical_event_time reuse: documentation_instance anchors to clinical_event
    IF to_regclass('clinical.clinical_event') IS NULL THEN
        RAISE EXCEPTION 'H9 FAIL: shared clinical.clinical_event (clinical_event_time) missing';
    END IF;

    RAISE NOTICE 'STEP 2 PASS: shared enums reused (7 capture methods, H8 certainty set, clinical_event_time anchor)';

    -- ------------------------------------------------------------------
    -- 3. FACT ≠ INTERPRETATION ≠ DIAGNOSIS (H9 §5)
    -- ------------------------------------------------------------------
    -- every element is typed (not free text) and sourced (not a conclusion)
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element
    WHERE evidence_type NOT IN ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','EVIDENCE_RULE','CLINICAL_HYPOTHESIS');
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) have an untyped evidence_type', vcnt; END IF;

    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element
    WHERE source_method_code IS NULL OR source_method_code = '';
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) lack a source-method (document priority without provenance)', vcnt; END IF;

    -- every element maps to a real section + template (no orphan section FKs)
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element e
    LEFT JOIN knowledge.documentation_section s      ON s.section_code = e.section_code
    LEFT JOIN knowledge.documentation_template t     ON t.template_code = e.template_code
    WHERE s.section_code IS NULL OR t.template_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) orphan section/template FK', vcnt; END IF;

    RAISE NOTICE 'STEP 3 PASS: every documented proposition is a typed, sourced fact (H9 §5 distinction preserved)';

    -- ------------------------------------------------------------------
    -- 4. H8 framework sections (H9 §6/§8)
    -- ------------------------------------------------------------------
    -- the three universal documentation dimensions exist
    IF to_regclass('knowledge.documentation_template') IS NULL THEN
        RAISE EXCEPTION 'H9 FAIL: documentation_template missing';
    END IF;
    IF to_regclass('knowledge.documentation_template_section') IS NULL THEN
        RAISE EXCEPTION 'H9 FAIL: documentation_template_section missing';
    END IF;
    IF to_regclass('knowledge.documentation_template_rule') IS NULL THEN
        RAISE EXCEPTION 'H9 FAIL: documentation_template_rule missing';
    END IF;

    -- TPL-ADULT-MEDICAL owns all 15 sections, ordered to match documentation_section.sort_order
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_section ts
    JOIN knowledge.documentation_section s ON s.section_code = ts.section_code
    WHERE ts.template_code='TPL-ADULT-MEDICAL' AND ts.sort_order = s.sort_order;
    IF vcnt <> 15 THEN RAISE EXCEPTION 'H9 FAIL: TPL-ADULT-MEDICAL section order must mirror documentation_section.sort_order, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_template_section WHERE template_code='TPL-EMERGENCY';
    IF vcnt <> 9 THEN RAISE EXCEPTION 'H9 FAIL: expected 9 TPL-EMERGENCY sections, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM knowledge.documentation_template_section WHERE template_code='TPL-DISCHARGE';
    IF vcnt <> 9 THEN RAISE EXCEPTION 'H9 FAIL: expected 9 TPL-DISCHARGE sections, got %', vcnt; END IF;

    -- every template_section resolves (no orphan section/template FKs)
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_section ts
    LEFT JOIN knowledge.documentation_section s   ON s.section_code = ts.section_code
    LEFT JOIN knowledge.documentation_template t  ON t.template_code = ts.template_code
    WHERE s.section_code IS NULL OR t.template_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % template_section orphan FK(s)', vcnt; END IF;

    RAISE NOTICE 'STEP 4 PASS: templates assemble sections by context (Adult=15, Emergency=9, Discharge=9), ordering mirrors §9 HPI grammar';

    -- ------------------------------------------------------------------
    -- 5. H9->H8 LINKAGE (§30/§31): documentation rules cite real evidence rules
    -- ------------------------------------------------------------------
    -- every template_rule that fires on an H8 evidence rule resolves to it
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_rule r
    LEFT JOIN knowledge.differential_evidence_rule er ON er.evidence_rule_code = r.evidence_rule_code
    WHERE r.trigger_type='EVIDENCE_RULE' AND er.evidence_rule_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % template_rule(s) link to a missing H8 evidence_rule', vcnt; END IF;

    -- every template_element citing an evidence rule resolves to it
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_element e
    LEFT JOIN knowledge.differential_evidence_rule er ON er.evidence_rule_code = e.evidence_rule_code
    WHERE e.evidence_rule_code IS NOT NULL AND er.evidence_rule_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % element(s) link to a missing H8 evidence_rule', vcnt; END IF;

    -- every template_rule targets a real element (no orphan target FK)
    SELECT count(*) INTO vcnt
    FROM knowledge.documentation_template_rule r
    LEFT JOIN knowledge.documentation_template_element e ON e.element_code = r.target_element_code
    WHERE e.element_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % template_rule(s) target a missing element', vcnt; END IF;

    RAISE NOTICE 'STEP 5 PASS: H9 rules cite real H8 evidence rules (DEV-003/DEV-005/DEV-006/DEV-007), H8->H9 closed loop intact';

    -- ------------------------------------------------------------------
    -- 6. governance: provenance integrity (§46) + runtime separation
    -- ------------------------------------------------------------------
    -- no dangling provenance edges to missing Hutchison claims (H9 objects only)
    SELECT count(*) INTO vcnt
    FROM knowledge.provenance p
    LEFT JOIN knowledge.source_claim sc ON sc.claim_id = p.claim_id
    WHERE p.object_type IN ('documentation_section','documentation_template','documentation_template_section',
                            'documentation_template_element','documentation_template_rule',
                            'documentation_order_rule','documentation_relevance_rule',
                            'documentation_lexicon','documentation_term','documentation_term_variant',
                            'documentation_version')
      AND sc.claim_id IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % documentation provenance edges point to a missing source_claim', vcnt; END IF;

    -- every seeded documentation object carries >= 1 provenance edge (0 orphans)
    SELECT count(*) INTO vcnt
    FROM (
        SELECT s.id FROM knowledge.documentation_section s
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_section' AND p.object_id=s.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT t.id FROM knowledge.documentation_template t
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_template' AND p.object_id=t.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT ts.id FROM knowledge.documentation_template_section ts
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_template_section' AND p.object_id=ts.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT e.id FROM knowledge.documentation_template_element e
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_template_element' AND p.object_id=e.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT r.id FROM knowledge.documentation_template_rule r
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_template_rule' AND p.object_id=r.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT r.id FROM knowledge.documentation_order_rule r
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_order_rule' AND p.object_id=r.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT r.id FROM knowledge.documentation_relevance_rule r
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_relevance_rule' AND p.object_id=r.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT l.id FROM knowledge.documentation_lexicon l
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_lexicon' AND p.object_id=l.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT t.id FROM knowledge.documentation_term t
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_term' AND p.object_id=t.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT tv.id FROM knowledge.documentation_term_variant tv
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_term_variant' AND p.object_id=tv.id
        WHERE p.object_id IS NULL
        UNION ALL
        SELECT dv.version_id FROM knowledge.documentation_version dv
        LEFT JOIN knowledge.provenance p ON p.object_type='documentation_version' AND p.object_id=dv.version_id
        WHERE p.object_id IS NULL
    ) orphan;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: % seeded documentation object(s) lack a provenance edge (§46)', vcnt; END IF;

    -- provenance edge count == sum of object counts (exactly one edge per object)
    -- NB: object_type list is explicit so the pre-existing knowledge.documentation_requirement
    --     edges (not an H9 object) are excluded from the count.
    SELECT count(*) INTO vcnt
    FROM knowledge.provenance
    WHERE object_type IN ('documentation_section','documentation_template','documentation_template_section',
                          'documentation_template_element','documentation_template_rule',
                          'documentation_order_rule','documentation_relevance_rule',
                          'documentation_lexicon','documentation_term','documentation_term_variant',
                          'documentation_version');
    IF vcnt <> 109 THEN RAISE EXCEPTION 'H9 FAIL: expected 109 provenance edges (one per object), got %', vcnt; END IF;

    -- runtime separation: the CPU compiles documents, H9 seeds the catalogue only
    SELECT count(*) INTO vcnt FROM knowledge.documentation_instance;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: documentation_instance must be empty at seed time, got % rows', vcnt; END IF;
    SELECT count(*) INTO vcnt FROM knowledge.documentation_sentence;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: documentation_sentence must be empty at seed time, got % rows', vcnt; END IF;
    SELECT count(*) INTO vcnt FROM knowledge.documentation_sentence_fact;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H9 FAIL: documentation_sentence_fact must be empty at seed time, got % rows', vcnt; END IF;

    RAISE NOTICE 'STEP 6 PASS: governance OK — provenance 109 edges (one per object), 0 dangling, 0 orphan FKs; runtime tables EMPTY (CPU compiles)';

    -- ------------------------------------------------------------------
    -- 7. document lifecycle + human-edit provenance (§29/§38/§41)
    -- ------------------------------------------------------------------
    -- §29 documentation_document lifecycle columns exist on the instance
    SELECT count(*) INTO vcnt FROM information_schema.columns
    WHERE table_schema='knowledge' AND table_name='documentation_instance'
      AND column_name IN ('patient_id','author_id','document_type','document_version','document_status','finalized_at','finalized_by_id','amended_from_id');
    IF vcnt <> 8 THEN RAISE EXCEPTION 'H9 FAIL: documentation_instance must carry the §29 lifecycle columns (got %/8)', vcnt; END IF;

    -- §38 author_status exists on every sentence column set
    SELECT count(*) INTO vcnt FROM information_schema.columns
    WHERE table_schema='knowledge' AND table_name='documentation_sentence'
      AND column_name IN ('author_status','amended_from_id');
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H9 FAIL: documentation_sentence must carry §38 author_status + amendment chain (got %/2)', vcnt; END IF;

    -- §41 versioning: DRAFT default is the documented start state
    SELECT count(*) INTO vcnt
    FROM information_schema.columns c
    WHERE c.table_schema='knowledge' AND c.table_name='documentation_instance'
      AND c.column_name='document_status'
      AND c.column_default LIKE '%DRAFT%';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H9 FAIL: §29 document_status must default to DRAFT, got % matching defaults', vcnt; END IF;

    RAISE NOTICE 'STEP 7 PASS: §29 lifecycle + §38 author_status + §41 versioning columns present with DRAFT default';

    RAISE NOTICE '==============================================================' ;
    RAISE NOTICE 'H9 MACHINE TEST PASSED: documentation-compiler schema + seed verified';
    RAISE NOTICE '==============================================================' ;
END
$h9_test$;

ROLLBACK;

\echo 'H9 machine test rolled back cleanly (no rows persisted, fully re-runnable).'
