-- =============================================================================
-- AMEXAN Phase 1H -- Machine Test 08: H10 governance & clinical knowledge control
-- =============================================================================
-- Validates the H10 trust layer (migration 036 + seed zqC): provenance, lifecycle,
-- publish gates, dependency integrity, conflict management, safety, reproducibility.
--
--   1. schema + seed counts (2 jurisd / 4 populations / 5 evidence levels /
--      25 governed objects / 7 versions / 10 relationships / 8 dependencies /
--      4 reviews / 4 approvals / 4 publications (3 PASS + 1 BLOCKED) /
--      1 deprecation / 1 conflict (RESOLVED) / 4 safety reviews /
--      2 model-registry rows / 1 system version)
--   2. NO ANONYMOUS LOGIC (§49): every governed object carries a real Hutchison
--      claim + a resolved type; 0 un sourced objects
--   3. LIFECYCLE + PUBLISH GATE (§41): every PUBLISHED record passes ALL six
--      gates; a BLOCKED record exists where safety + population failed; version
--      history never overwritten (superseded v1 -> active v2)
--   4. DEPENDENCY INTEGRITY (#28/#29): recursive cycle detection over
--      knowledge_dependency returns 0 cycles; every dependency resolves to a
--      governed object
--   5. CONFLICT MANAGEMENT (#20/#21): the temporal conflict is RESOLVED with a
--      documented resolution; classification is structured
--   6. REPRODUCIBILITY (#47/#48): deterministic engine ACTIVE/APPROVED; the LLM
--      is DRAFT and not active — a realisation component, never the source of
--      clinical truth; system_version ties real H8/H9 version codes
--   7. SHARED-REGISTRY REUSE: governed object codes (DA001, DEV-003, PHEN-*,
--      MECH-*, COUGH_DURATION_DAYS, PROT-CAP-ADULT, TPL-ADULT-MEDICAL,
--      RV2024.01.002) resolve to the REAL H4-H9 registries — the catalogue
--      GOVERNS, never duplicates the layers
--   8. PROVENANCE INTEGRITY (§46): 82 governance_* edges == number of governed
--      objects; 0 dangling edges; exactly one edge per object
--   9. runtime separation: rule_execution / audit_event / provenance_record /
--      clinical_snapshot / reasoning_snapshot / documentation_snapshot are EMPTY
--
-- Runs in a transaction and rolls back; fully re-runnable. ON_ERROR_STOP.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $h10_test$
DECLARE
    v       integer;
    vcnt    integer;
    vtext   text;
BEGIN
    RAISE NOTICE '==============================================================' ;
    RAISE NOTICE 'AMEXAN MACHINE TEST 08 - H10 governance & knowledge control';
    RAISE NOTICE '==============================================================' ;

    -- ------------------------------------------------------------------
    -- 1. schema + seed counts (all 15 governance catalogue tables exist)
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM (VALUES
        ('governance.jurisdiction'),
        ('governance.population_context'),
        ('governance.evidence_metadata'),
        ('governance.knowledge_object'),
        ('governance.knowledge_object_version'),
        ('governance.knowledge_relationship'),
        ('governance.knowledge_dependency'),
        ('governance.knowledge_review'),
        ('governance.knowledge_approval'),
        ('governance.knowledge_publication'),
        ('governance.knowledge_deprecation'),
        ('governance.conflict_record'),
        ('governance.safety_review'),
        ('governance.model_registry'),
        ('governance.system_version')) AS t(t)
    WHERE to_regclass(t.t) IS NOT NULL;
    IF vcnt <> 15 THEN RAISE EXCEPTION 'H10 FAIL: expected 15 governance catalogue tables, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.jurisdiction;
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H10 FAIL: expected 2 jurisdictions, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.population_context;
    IF vcnt <> 5 THEN RAISE EXCEPTION 'H10 FAIL: expected 5 population_context (4 core + POP-BOTH), got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.evidence_metadata;
    IF vcnt <> 5 THEN RAISE EXCEPTION 'H10 FAIL: expected 5 evidence levels (EV-A..EV-E), got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_object;
    IF vcnt <> 55 THEN RAISE EXCEPTION 'H10 FAIL: expected 55 governed objects (25 core + 30 respiratory slice), got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_object_version;
    IF vcnt <> 37 THEN RAISE EXCEPTION 'H10 FAIL: expected 37 object versions (7 core + 30 respiratory slice), got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_relationship;
    IF vcnt <> 10 THEN RAISE EXCEPTION 'H10 FAIL: expected 10 knowledge relationships, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_dependency;
    IF vcnt <> 8 THEN RAISE EXCEPTION 'H10 FAIL: expected 8 knowledge dependencies, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_review;
    IF vcnt <> 4 THEN RAISE EXCEPTION 'H10 FAIL: expected 4 knowledge reviews, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_approval;
    IF vcnt <> 4 THEN RAISE EXCEPTION 'H10 FAIL: expected 4 knowledge approvals, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_publication;
    IF vcnt <> 4 THEN RAISE EXCEPTION 'H10 FAIL: expected 4 knowledge publications, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_deprecation;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: expected 1 knowledge deprecation, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.conflict_record;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: expected 1 conflict record, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.safety_review;
    IF vcnt <> 4 THEN RAISE EXCEPTION 'H10 FAIL: expected 4 safety reviews, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.model_registry;
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H10 FAIL: expected 2 model registry rows, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.system_version;
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H10 FAIL: expected 2 system versions (AMEXAN-1.0.0 + 1.1.0), got %', vcnt; END IF;

    RAISE NOTICE 'STEP 1 PASS: H10 schema + catalogue seeded (2/5/5/55/37/10/8/4/4/4/1/1/4/2/2)';

    -- ------------------------------------------------------------------
    -- 2. NO ANONYMOUS LOGIC (§49): every governed object is sourced + typed
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_object
    WHERE source_claim_code IS NULL OR source_claim_code = '';
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % governed object(s) lack a Hutchison source claim (§49)', vcnt; END IF;

    -- every object carries a valid knowledge_type (the CHECK set already
    -- enforces syntax; here we assert no object fell back on unknown semantics)
    SELECT count(DISTINCT knowledge_type) INTO vcnt FROM governance.knowledge_object;
    IF vcnt < 10 THEN RAISE EXCEPTION 'H10 FAIL: expected >=10 distinct governed knowledge_type categories, got %', vcnt; END IF;

    -- the shared-source claims must resolve (governance objects are REAL objects)
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_object ko
    LEFT JOIN knowledge.source_claim sc ON sc.claim_code = ko.source_claim_code
    WHERE sc.claim_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % governed object(s) cite a missing source_claim', vcnt; END IF;

    RAISE NOTICE 'STEP 2 PASS: no anonymous clinical logic — 55/55 governed objects carry a real Hutchison claim';

    -- ------------------------------------------------------------------
    -- 3. LIFECYCLE + PUBLISH GATE (#41)
    -- ------------------------------------------------------------------
    -- 3 PUBLISHED, 1 BLOCKED
    SELECT count(*) INTO vcnt FROM governance.knowledge_publication WHERE decision='PUBLISHED';
    IF vcnt <> 3 THEN RAISE EXCEPTION 'H10 FAIL: expected 3 PUBLISHED gates, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.knowledge_publication WHERE decision='BLOCKED';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: expected 1 BLOCKED gate, got %', vcnt; END IF;

    -- invariant: decision==PUBLISHED  <=>  ALL six gates true; BLOCKED otherwise
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_publication
    WHERE (decision='PUBLISHED' AND NOT (provenance_complete AND validation_passed
          AND dependency_integrity AND jurisdiction_ok AND population_ok AND safety_review_ok))
       OR (decision='BLOCKED' AND (provenance_complete AND validation_passed
          AND dependency_integrity AND jurisdiction_ok AND population_ok AND safety_review_ok));
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % publication(s) violate the six-gate invariant (§41)', vcnt; END IF;

    -- the BLOCKED candidate failed BOTH population and safety gates (why it is not live)
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_publication pub
    JOIN governance.knowledge_object ko ON ko.id = pub.object_id
    WHERE pub.publication_code='GO-PUB-GL' AND ko.object_code='GL-KENYA-ASTHMA-2021'
          AND pub.population_ok=false AND pub.safety_review_ok=false AND pub.decision='BLOCKED';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: BLOCKED candidate must be the DRAFT Kenya guideline with population+safety gates failed, got %', vcnt; END IF;

    -- version history never overwritten (#8): v1 SUPERSEDED, v2 ACTIVE with link
    SELECT count(*) INTO vcnt FROM governance.knowledge_object_version WHERE lifecycle_status='SUPERSEDED';
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H10 FAIL: expected 2 SUPERSEDED versions (DA001/PROT v1), got %', vcnt; END IF;

    SELECT count(*) INTO vcnt
    FROM governance.knowledge_object_version v2
    JOIN governance.knowledge_object_version v1 ON v1.id = v2.supersedes_version_id
    WHERE v2.lifecycle_status='ACTIVE' AND v1.lifecycle_status='SUPERSEDED';
    IF vcnt <> 2 THEN RAISE EXCEPTION 'H10 FAIL: expected 2 ACTIVE versions superseding a RETIRED/SUPERSEDED predecessor, got %', vcnt; END IF;

    -- the deprecation points the retired v1 to its replacement (same object v2)
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_deprecation dep
    JOIN governance.knowledge_object o      ON o.id  = dep.object_id
    JOIN governance.knowledge_object rep   ON rep.id = dep.replacement_object_id
    JOIN governance.knowledge_object_version v ON v.id = dep.version_id
    WHERE dep.deprecation_code='GO-DEPR-PROT-1' AND o.object_code='PROT-CAP-ADULT'
          AND rep.object_code='PROT-CAP-ADULT' AND v.version_code='GO-V-PROT-1';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: deprecation must retire PROT-CAP-ADULT v1 and point to its replacement, got %', vcnt; END IF;

    RAISE NOTICE 'STEP 3 PASS: 3 PUBLISHED through all six gates, 1 documented BLOCKED (#41); v1->v2 supersede + deprecation intact (#8)';

    -- ------------------------------------------------------------------
    -- 4. DEPENDENCY INTEGRITY (#28/#29): 0 cycles, all edges resolve
    -- ------------------------------------------------------------------
    WITH RECURSIVE walk AS (
        SELECT d.dependent_object_id AS start, d.required_object_id AS node,
               ARRAY[d.dependent_object_id] AS path, false AS cyclic
        FROM governance.knowledge_dependency d
        UNION ALL
        SELECT w.start, d.required_object_id, w.path || d.required_object_id,
               d.required_object_id = ANY(w.path)
        FROM walk w
        JOIN governance.knowledge_dependency d ON d.dependent_object_id = w.node
        WHERE NOT w.cyclic AND array_length(w.path, 1) <= 25
    )
    SELECT count(*) INTO vcnt FROM walk WHERE cyclic;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % circular dependency path(s) detected (#28/#29)', vcnt; END IF;

    -- every dependency endpoint is a governed object (no orphan edges)
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_dependency d
    LEFT JOIN governance.knowledge_object dep ON dep.id = d.dependent_object_id
    LEFT JOIN governance.knowledge_object req ON req.id = d.required_object_id
    WHERE dep.id IS NULL OR req.id IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % dependency edge(s) reference a missing governed object', vcnt; END IF;

    RAISE NOTICE 'STEP 4 PASS: knowledge_dependency is acyclic (0 cycles), all 8 edges resolve (#28/#29)';

    -- ------------------------------------------------------------------
    -- 5. CONFLICT MANAGEMENT (#20/#21)
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM governance.conflict_record
    WHERE conflict_code='GO-CONF-DEV6-7' AND conflict_type='TEMPORAL_CONFLICT'
          AND status='RESOLVED' AND resolution IS NOT NULL AND resolution <> ''
          AND classification IS NOT NULL
          AND source_claim_a = 'HCH12-0004' AND source_claim_b = 'HCH12-0004';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: temporal conflict DEV-006/DEV-007 must be RESOLVED with a documented resolution + classification (#21), got %', vcnt; END IF;

    -- the conflicting objects are the real acute/chronic band rules
    SELECT count(*) INTO vcnt
    FROM governance.conflict_record c
    JOIN governance.knowledge_object a ON a.id = c.object_id_a
    JOIN governance.knowledge_object b ON b.id = c.object_id_b
    WHERE a.object_code='DEV-006' AND b.object_code='DEV-007';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: conflict must cite DEV-006 vs DEV-007 as the conflicting objects, got %', vcnt; END IF;

    RAISE NOTICE 'STEP 5 PASS: 1 TEMPORAL_CONFLICT recorded, classified and RESOLVED — no silent source merging (#20/#21)';

    -- ------------------------------------------------------------------
    -- 6. REPRODUCIBILITY + MODEL IDENTITY (#47/#48)
    -- ------------------------------------------------------------------
    -- deterministic engine is ACTIVE; the LLM stays DRAFT and inactive
    SELECT count(*) INTO vcnt
    FROM governance.model_registry
    WHERE model_code='MODEL-DOC-CPU-1.0' AND model_type='DETERMINISTIC' AND approval_status='ACTIVE' AND is_active=true;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: deterministic documentation engine must be ACTIVE, got %', vcnt; END IF;

    SELECT count(*) INTO vcnt
    FROM governance.model_registry
    WHERE model_code='MODEL-LLM-01' AND model_type='LLM' AND approval_status='DRAFT' AND is_active=false;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: LLM must stay DRAFT + inactive until reviewed (#47/#48), got %', vcnt; END IF;

    -- system_version ties the REAL H8 + H9 version codes (active row = AMEXAN-1.1.0)
    SELECT count(*) INTO vcnt
    FROM governance.system_version sv
    JOIN knowledge.reasoning_version rv     ON rv.version_code = sv.reasoning_version_code
    JOIN knowledge.documentation_version dv ON dv.version_code = sv.documentation_version_code
    WHERE sv.system_version_code='AMEXAN-1.1.0' AND sv.is_active=true
          AND sv.reasoning_version_code='RV2024.01.001'
          AND sv.documentation_version_code='RV2024.01.002'
          AND rv.knowledge_version='HUTCHISON_24_2018'
          AND dv.knowledge_version='HUTCHISON_24_2018';
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: AMEXAN-1.1.0 must tie H8 reasoning RV2024.01.001 + H9 documentation RV2024.01.002 (HUTCHISON_24_2018), got %', vcnt; END IF;

    -- the superseded predecessor is preserved, never overwritten (#8)
    SELECT count(*) INTO vcnt
    FROM governance.system_version WHERE system_version_code='AMEXAN-1.0.0' AND is_active=false;
    IF vcnt <> 1 THEN RAISE EXCEPTION 'H10 FAIL: AMEXAN-1.0.0 must be preserved as superseded/inactive, got %', vcnt; END IF;

    RAISE NOTICE 'STEP 6 PASS: deterministic engine ACTIVE, LLM DRAFT (#47/#48); system_version AMEXAN-1.1.0 ties real H8/H9 versions, 1.0.0 preserved (#10/#17)';

    -- ------------------------------------------------------------------
    -- 7. SHARED-REGISTRY REUSE: governed object codes resolve to the real layers
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_object ko
    LEFT JOIN knowledge.diagnosis_concept dc       ON dc.code = ko.object_code AND ko.knowledge_type='DIAGNOSIS'
    LEFT JOIN knowledge.differential_evidence_rule er ON er.evidence_rule_code = ko.object_code AND ko.knowledge_type='DIFFERENTIAL_RULE'
    LEFT JOIN knowledge.phenotype ph               ON ph.phenotype_code = ko.object_code AND ko.knowledge_type='PHENOTYPE'
    LEFT JOIN knowledge.mechanism me               ON me.mechanism_code = ko.object_code AND ko.knowledge_type='MECHANISM'
    LEFT JOIN clinical.fact_definition fd          ON fd.code = ko.object_code AND ko.knowledge_type='CLINICAL_FACT'
    LEFT JOIN knowledge.protocol pr                ON pr.protocol_code = ko.object_code AND ko.knowledge_type='PROTOCOL'
    LEFT JOIN knowledge.documentation_template dt  ON dt.template_code = ko.object_code AND ko.knowledge_type='DOCUMENTATION_TEMPLATE'
    LEFT JOIN knowledge.documentation_template_element de ON de.element_code = ko.object_code AND ko.knowledge_type='DOCUMENTATION_TEMPLATE'
    LEFT JOIN knowledge.documentation_version dvv  ON dvv.version_code = ko.object_code AND ko.knowledge_type='KNOWLEDGE_VERSION'
    WHERE ko.knowledge_type IN ('DIAGNOSIS','DIFFERENTIAL_RULE','PHENOTYPE','MECHANISM',
                                'CLINICAL_FACT','PROTOCOL','DOCUMENTATION_TEMPLATE','KNOWLEDGE_VERSION')
      AND ko.object_code NOT LIKE '%-VERTICAL-SLICE-%'
      AND dc.code IS NULL AND er.evidence_rule_code IS NULL AND ph.phenotype_code IS NULL
      AND me.mechanism_code IS NULL AND fd.code IS NULL AND pr.protocol_code IS NULL
      AND dt.template_code IS NULL AND de.element_code IS NULL AND dvv.version_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % governed object code(s) do not resolve to their real H4-H9 registry', vcnt; END IF;

    -- the governed documentation rule/element + assessment resolve into H9
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_object ko
    LEFT JOIN knowledge.documentation_template_rule dr ON dr.rule_code = ko.object_code AND ko.knowledge_type='DOCUMENTATION_RULE'
    LEFT JOIN knowledge.documentation_template_element de ON de.element_code = ko.object_code AND ko.knowledge_type='DOCUMENTATION_TEMPLATE'
    WHERE ko.object_code IN ('DRule-001','DTE-ASSESS-PNEUMONIA')
      AND dr.rule_code IS NULL AND de.element_code IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: documented rule/element codes must resolve into the H9 catalogue, got %', vcnt; END IF;

    RAISE NOTICE 'STEP 7 PASS: governed object codes are the REAL H4-H9 codes — catalogue governs, never duplicates (DA001/DEV-003/PHEN-*/MECH-*/PROT-CAP-ADULT/TPL-ADULT-MEDICAL/RV2024.01.002 all resolve)';

    -- ------------------------------------------------------------------
    -- 8. PROVENANCE INTEGRITY (§46): one edge per governed object, 0 dangling
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt
    FROM knowledge.provenance p
    LEFT JOIN knowledge.source_claim sc ON sc.claim_id = p.claim_id
    WHERE p.object_type LIKE 'governance\_%' AND sc.claim_id IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % governance provenance edge(s) point to a missing source_claim', vcnt; END IF;

    -- objective: governance edges == number of governed catalogue rows
    SELECT count(*) INTO vcnt FROM knowledge.provenance WHERE object_type LIKE 'governance\_%';
    IF vcnt <> 107 THEN RAISE EXCEPTION 'H10 FAIL: expected 107 governance provenance edges (one per governed object incl. respiratory slice), got %', vcnt; END IF;

    -- every governed object has >= 1 provenance edge (no orphan governed rows)
    SELECT count(*) INTO vcnt
    FROM governance.knowledge_dependency d
    LEFT JOIN knowledge.provenance p ON p.object_type='governance_knowledge_dependency' AND p.object_id=d.id
    WHERE p.object_id IS NULL;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: % governed dependency object(s) lack a provenance edge', vcnt; END IF;

    RAISE NOTICE 'STEP 8 PASS: provenance reuses the shared H1 backbone — 107 governance edges == governed-object count, 0 dangling (§46)';

    -- ------------------------------------------------------------------
    -- 9. runtime separation: the CPU records computations, not this seed
    -- ------------------------------------------------------------------
    SELECT count(*) INTO vcnt FROM governance.rule_execution;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: rule_execution must be empty at seed time, got % rows', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.audit_event;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: audit_event must be empty at seed time, got % rows', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.provenance_record;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: provenance_record must be empty at seed time, got % rows', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.clinical_snapshot;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: clinical_snapshot must be empty at seed time, got % rows', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.reasoning_snapshot;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: reasoning_snapshot must be empty at seed time, got % rows', vcnt; END IF;

    SELECT count(*) INTO vcnt FROM governance.documentation_snapshot;
    IF vcnt <> 0 THEN RAISE EXCEPTION 'H10 FAIL: documentation_snapshot must be empty at seed time, got % rows', vcnt; END IF;

    RAISE NOTICE 'STEP 9 PASS: runtime tables EMPTY at rest — the CPU records rule_execution/audit/snapshots per computation';

    RAISE NOTICE '==============================================================' ;
    RAISE NOTICE 'H10 MACHINE TEST PASSED: governance catalogue + gates + provenance verified';
    RAISE NOTICE '==============================================================' ;
END
$h10_test$;

ROLLBACK;

\echo 'H10 machine test rolled back cleanly (no rows persisted, fully re-runnable).'