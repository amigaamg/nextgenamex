-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H9 migration 034: documentation compiler
-- =============================================================================
-- H9 consumes an H8 reasoning_run (differential_candidate / differential_score /
-- differential_evidence_ledger / clinical_hypothesis / clinical_uncertainty /
-- information_gap) together with H7 investigation_result and the shared clinical
-- event timeline, and COMPILES a structured, versioned clinical document.
--
-- Architectural law (inherited from H6/H7/H8):
--   PostgreSQL = KNOWLEDGE + CONFIGURATION   (the catalogue of WHAT CAN be documented)
--   CPU        = COMPILATION / EXECUTION     (compiles one document per run)
--   UI         = RENDERING                   (renders documentation_sentence only)
--
-- §42 constitutional rule (carried from H8): the UI never compiles. It renders
-- documentation_sentence / documentation_section_rendered, never touching the
-- documentation_template_rule engine.
--
-- SHARED-ENUM / SHARED-TIME REUSE (H9 MUST NOT redefine these — it references
-- them by foreign key, exactly as H8 reuses fact_capture_method/clinical_event):
--   • certainty            — the H8 inline CHECK set
--       ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN') , reused verbatim on every
--       compiled document row so H9 preserves H8's certainty state (H9 §20/§21).
--   • source-hierarchy     — knowledge.fact_capture_method(method_code) (H5 §12):
--       PATIENT_REPORTED / CAREGIVER_REPORTED / CLINICIAN_OBSERVED / DEVICE_MEASURED
--       / LAB_MEASURED / IMAGING_DERIVED / SYSTEM_DERIVED.
--   • clinical_event_time  — clinical.clinical_event(event_time) (H2 §3/H3 §15):
--       the shared patient-event timeline anchor for chronology (H9 §11/§12).
--
-- §46 provenance law (carried from H8 §45/§46): H8 stored ALL claim→object edges
--   in the single shared table knowledge.provenance. H9 follows that convention
--   — H9 provenance rows live there too (object_type = 'documentation_…').
--   No per-layer provenance table, so governance stays unified and auditable.
--
-- Runtime tables (documentation_instance / _sentence / _sentence_fact) are created
-- EMPTY here — the CPU populates them per compiled document, exactly as H7/H8 leave
-- investigation_result / differential_rank / differential_reason empty at seed time.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A. KNOWLEDGE LAYER (the documentation catalogue — seeded, claim-grounded)
-- ---------------------------------------------------------------------------

-- A1. documentation_section — canonical clinical-note sections (H9 §6).
--     Reused across templates; never free-form headings.
CREATE TABLE IF NOT EXISTS knowledge.documentation_section (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    section_code       text NOT NULL UNIQUE,            -- DOC-HPI / DOC-ROS / …
    label              text NOT NULL,
    heading_template   text NOT NULL,                   -- e.g. 'History of Present Illness'
    section_type       text NOT NULL CHECK (section_type IN ('NARRATIVE','TABLE','LIST','SCALAR')),
    is_required        boolean NOT NULL DEFAULT true,
    is_repeatable      boolean NOT NULL DEFAULT false,
    default_certainty  text NOT NULL DEFAULT 'POSSIBLE'
                        CHECK (default_certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),  -- SHARED certainty enum
    sort_order         integer NOT NULL,
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',  -- clinical_context.code
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_section
    IS 'Canonical clinical-note sections (H9 §6). default_certainty reuses the H8 certainty enum so H9 never inflates H8 certainty (H9 §20/§21).';
CREATE INDEX IF NOT EXISTS idx_doc_section_sort ON knowledge.documentation_section(sort_order);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_section_updated_at ON knowledge.documentation_section;
CREATE TRIGGER trg_knowledge_documentation_section_updated_at
    BEFORE UPDATE ON knowledge.documentation_section FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A2. documentation_template — a named, versioned document template (H9 §8/§25).
CREATE TABLE IF NOT EXISTS knowledge.documentation_template (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code      text NOT NULL UNIQUE,            -- TPL-ADULT-MEDICAL / TPL-EMERGENCY / …
    canonical_name     text NOT NULL,
    short_label        text,
    description        text,
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active          boolean NOT NULL DEFAULT true,
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_template
    IS 'Document templates that assemble sections for a presentation (H9 §8). A template is a documentation frame, never a clinical conclusion.';
CREATE INDEX IF NOT EXISTS idx_doc_template_active ON knowledge.documentation_template(is_active);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_template_updated_at ON knowledge.documentation_template;
CREATE TRIGGER trg_knowledge_documentation_template_updated_at
    BEFORE UPDATE ON knowledge.documentation_template FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A3. documentation_template_section — section membership + order within a template.
CREATE TABLE IF NOT EXISTS knowledge.documentation_template_section (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code     text NOT NULL REFERENCES knowledge.documentation_template(template_code) ON DELETE CASCADE,
    section_code      text NOT NULL REFERENCES knowledge.documentation_section(section_code) ON DELETE CASCADE,
    sort_order        integer NOT NULL,
    is_required       boolean NOT NULL DEFAULT false,
    is_repeatable     boolean NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (template_code, section_code)
);
COMMENT ON TABLE knowledge.documentation_template_section
    IS 'Section membership + ordering within a template (H9 §6). NOT every encounter gets every section; the template activates them.';

-- A4. documentation_template_element — WHAT content maps into a template section (H9 §7).
--     One element = one structured proposition (fact / phenotype / mechanism /
--     result_interpretation / diagnosis / evidence_rule) that the language
--     realizer may surface. FKs reuse the H7/H8 concept registries.
CREATE TABLE IF NOT EXISTS knowledge.documentation_template_element (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    element_code            text NOT NULL UNIQUE,        -- DTE-PNEUMONIA-CONSOLIDATION …
    template_code           text NOT NULL REFERENCES knowledge.documentation_template(template_code) ON DELETE CASCADE,
    section_code            text NOT NULL REFERENCES knowledge.documentation_section(section_code) ON DELETE CASCADE,
    evidence_type           text NOT NULL CHECK (evidence_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','EVIDENCE_RULE','CLINICAL_HYPOTHESIS')),
    fact_definition_code    text REFERENCES clinical.fact_definition(code),
    phenotype_code          text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code          text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    diagnosis_code          text REFERENCES knowledge.diagnosis_concept(code),
    evidence_rule_code      text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),  -- H8 linkage
    wording_template        text NOT NULL,
    source_method_code      text NOT NULL REFERENCES knowledge.fact_capture_method(method_code),  -- SHARED source-hierarchy
    certainty               text NOT NULL DEFAULT 'POSSIBLE'
                             CHECK (certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),         -- SHARED certainty enum
    min_strength            numeric(5,2),               -- evidence strength floor to render
    is_must_document        boolean NOT NULL DEFAULT false,  -- §46 never-silence: must appear if its proposition is met
    is_active               boolean NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_template_element
    IS 'What content maps into a template section (H9 §7/§8). Reuses certainty + fact_capture_method source-hierarchy + H7/H8 concept FKs.';
CREATE INDEX IF NOT EXISTS idx_doc_elem_tmpl ON knowledge.documentation_template_element(template_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_sec  ON knowledge.documentation_template_element(section_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_ert  ON knowledge.documentation_template_element(evidence_rule_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_template_element_updated_at ON knowledge.documentation_template_element;
CREATE TRIGGER trg_knowledge_documentation_template_element_updated_at
    BEFORE UPDATE ON knowledge.documentation_template_element FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A5. documentation_template_rule — data-driven IF proposition THEN render/suppress
--     (H9 §9). Rules are DATA, never if-chains. evidence_rule_code is the H8
--     linkage so H9 compiles only what H8's differential_evidence_rule established.
CREATE TABLE IF NOT EXISTS knowledge.documentation_template_rule (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code                text NOT NULL UNIQUE,      -- DRule-001 …
    template_code            text NOT NULL REFERENCES knowledge.documentation_template(template_code) ON DELETE CASCADE,
    trigger_type             text NOT NULL CHECK (trigger_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','EVIDENCE_RULE',
         'CANDIDATE_STATE','CLINICAL_HYPOTHESIS','CONTEXT','CLINICAL_EVENT','ALWAYS')),
    trigger_code             text,                       -- proposition code for FACT/PHENOTYPE/… triggers
    evidence_rule_code       text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),  -- H8 linkage
    target_element_code      text NOT NULL REFERENCES knowledge.documentation_template_element(element_code),
    action                   text NOT NULL CHECK (action IN
        ('RENDER','SUPPRESS','ESCALATE','MARK_CRITICAL','REQUEST_INFORMATION','CREATE_QUESTION_GAP',
         'TRIGGER_INVESTIGATION','STRONGLY_INCLUDE','WEAKLY_INCLUDE')),
    weight_delta             numeric(5,2) NOT NULL DEFAULT 0,
    wording_template         text,
    message                  text,
    evidence_claim_code      text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    applies_to_clinical_event boolean NOT NULL DEFAULT false,  -- fires on clinical_event timeline (event_time)
    is_active                boolean NOT NULL DEFAULT true,
    status                   text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_template_rule
    IS 'Data-driven documentation rules (H9 §9/§30/§31): IF proposition THEN render/suppress/escalate. evidence_rule_code closes the H8→H9 loop.';
CREATE INDEX IF NOT EXISTS idx_doc_rule_tmpl  ON knowledge.documentation_template_rule(template_code);
CREATE INDEX IF NOT EXISTS idx_doc_rule_elem  ON knowledge.documentation_template_rule(target_element_code);
CREATE INDEX IF NOT EXISTS idx_doc_rule_ert   ON knowledge.documentation_template_rule(evidence_rule_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_template_rule_updated_at ON knowledge.documentation_template_rule;
CREATE TRIGGER trg_knowledge_documentation_template_rule_updated_at
    BEFORE UPDATE ON knowledge.documentation_template_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A6. documentation_order_rule — clinical ordering of facts into narrative (H9 §9/§11).
CREATE TABLE IF NOT EXISTS knowledge.documentation_order_rule (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code         text NOT NULL UNIQUE,            -- DOR-001 …
    section_code      text NOT NULL REFERENCES knowledge.documentation_section(section_code) ON DELETE CASCADE,
    proposition_code  text NOT NULL,                   -- the fact/phenotype/diagnosis code this ordering governs
    proposition_type  text NOT NULL CHECK (proposition_type IN ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS')),
    clinical_narrative_position text NOT NULL,          -- ONSET / CHARACTER / SITE / …
    sort_order        integer NOT NULL,
    wording_template  text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_order_rule
    IS 'Clinical semantic ordering of facts into narrative (H9 §9/§11).';
CREATE INDEX IF NOT EXISTS idx_doc_order_sec ON knowledge.documentation_order_rule(section_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_order_rule_updated_at ON knowledge.documentation_order_rule;
CREATE TRIGGER trg_knowledge_documentation_order_rule_updated_at
    BEFORE UPDATE ON knowledge.documentation_order_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A7. documentation_relevance_rule — document_priority per proposition (H9 §17).
CREATE TABLE IF NOT EXISTS knowledge.documentation_relevance_rule (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code         text NOT NULL UNIQUE,            -- DRL-001 …
    proposition_code  text NOT NULL,                   -- the fact/phenotype/diagnosis/result code
    proposition_type  text NOT NULL CHECK (proposition_type IN ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS')),
    priority_level    text NOT NULL CHECK (priority_level IN ('HIGH','MEDIUM','LOW','EXCLUDE')),  -- §17 document_priority
    rationale         text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_relevance_rule
    IS 'Document priority / relevance of a proposition (H9 §17). Not every captured fact is documented.';
CREATE INDEX IF NOT EXISTS idx_doc_rel_prio ON knowledge.documentation_relevance_rule(priority_level);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_relevance_rule_updated_at ON knowledge.documentation_relevance_rule;
CREATE TRIGGER trg_knowledge_documentation_relevance_rule_updated_at
    BEFORE UPDATE ON knowledge.documentation_relevance_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A8. documentation_lexicon — canonical term per canonical concept (H9 §23).
CREATE TABLE IF NOT EXISTS knowledge.documentation_lexicon (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_code    text NOT NULL,                     -- canonical fact/phenotype/diagnosis/result code
    concept_type    text NOT NULL CHECK (concept_type IN ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','CONTEXT')),
    canonical_term  text NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (concept_code, concept_type)
);
COMMENT ON TABLE knowledge.documentation_lexicon
    IS 'Canonical documentation term per canonical concept (H9 §23). Drives the language realizer.';
CREATE INDEX IF NOT EXISTS idx_doc_lex_concept ON knowledge.documentation_lexicon(concept_code);

-- A9. documentation_term — per-context realisation of a lexicon concept (H9 §23/§24).
CREATE TABLE IF NOT EXISTS knowledge.documentation_term (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lexicon_id            uuid NOT NULL REFERENCES knowledge.documentation_lexicon(id) ON DELETE CASCADE,
    applies_to_context_code text NOT NULL REFERENCES knowledge.clinical_context(code),  -- ADULT / CHILD / …
    preferred_label       text NOT NULL,
    wording_template      text,
    is_preferred          boolean NOT NULL DEFAULT true,
    is_active             boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (lexicon_id, applies_to_context_code)
);
COMMENT ON TABLE knowledge.documentation_term
    IS 'Per-context wording of a lexicon concept (H9 §23/§24, §5 pediatric).';
CREATE INDEX IF NOT EXISTS idx_doc_term_lex ON knowledge.documentation_term(lexicon_id);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_term_updated_at ON knowledge.documentation_term;
CREATE TRIGGER trg_knowledge_documentation_term_updated_at
    BEFORE UPDATE ON knowledge.documentation_term FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- A10. documentation_term_variant — synonyms / age-specific variants (H9 §23/§24).
CREATE TABLE IF NOT EXISTS knowledge.documentation_term_variant (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    term_id               uuid NOT NULL REFERENCES knowledge.documentation_term(id) ON DELETE CASCADE,
    variant_label         text NOT NULL,
    language_code         text NOT NULL DEFAULT 'en',
    applies_to_context_code text REFERENCES knowledge.clinical_context(code),  -- e.g. CHILD
    is_preferred          boolean NOT NULL DEFAULT false,
    created_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (term_id, variant_label, language_code)
);
COMMENT ON TABLE knowledge.documentation_term_variant
    IS 'Acceptable synonym / context variant of a documentation term (H9 §23).';

-- A11. documentation_version — version registry (H9 §40/§41), mirrors H8 reasoning_version.
CREATE TABLE IF NOT EXISTS knowledge.documentation_version (
    version_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_code      text NOT NULL UNIQUE,            -- RV2024.01.002
    ruleset_version   text NOT NULL,
    knowledge_version text NOT NULL,                   -- = H8 reasoning_version.knowledge_version
    engine_version    text NOT NULL,
    effective_from    date,
    change_note       text,
    status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_version
    IS 'Documentation knowledge version (H9 §40): which ruleset/knowledge/engine produced a compiled document. Mirrors H8 reasoning_version.';
DROP TRIGGER IF EXISTS trg_knowledge_documentation_version_updated_at ON knowledge.documentation_version;
CREATE TRIGGER trg_knowledge_documentation_version_updated_at
    BEFORE UPDATE ON knowledge.documentation_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- B. RUNTIME LAYER (empty at seed time — the CPU compiles a document per run,
--    exactly as H7/H8 leave investigation_result / differential_rank empty)
-- ---------------------------------------------------------------------------

-- B1. documentation_instance — one compiled clinical document per H8 reasoning_run.
--     Anchored to the shared clinical_event timeline (clinical_event_time).
CREATE TABLE IF NOT EXISTS knowledge.documentation_instance (
    instance_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id              uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,   -- H8 reasoning run
    template_code       text NOT NULL REFERENCES knowledge.documentation_template(template_code),
    clinical_event_id   uuid REFERENCES clinical.clinical_event(id) ON DELETE SET NULL,  -- anchor: reuses event_time
    started_at          timestamptz NOT NULL DEFAULT now(),
    completed_at        timestamptz,
    status              text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPILED','FAILED')),
    ruleset_version     text,
    knowledge_version   text,
    engine_version      text,
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_instance
    IS 'A compiled clinical document (H9). One per H8 reasoning_run per encounter; anchored to the shared clinical_event timeline (event_time).';
CREATE INDEX IF NOT EXISTS idx_doc_inst_run ON knowledge.documentation_instance(run_id);
CREATE INDEX IF NOT EXISTS idx_doc_inst_tmpl ON knowledge.documentation_instance(template_code);
CREATE INDEX IF NOT EXISTS idx_doc_inst_evt  ON knowledge.documentation_instance(clinical_event_id);

-- B2. documentation_block — a structured block within a compiled document (H9 §18).
CREATE TABLE IF NOT EXISTS knowledge.documentation_block (
    block_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id     uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    section_code    text NOT NULL REFERENCES knowledge.documentation_section(section_code),
    block_order     integer NOT NULL,
    block_label     text,
    created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_block
    IS 'Structured blocks of a compiled document (H9 §18 graph node).';
CREATE INDEX IF NOT EXISTS idx_doc_block_inst ON knowledge.documentation_block(instance_id);

-- B3. documentation_sentence — a rendered clinical sentence (H9 §15/§31).
CREATE TABLE IF NOT EXISTS knowledge.documentation_sentence (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id         uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    block_id            uuid REFERENCES knowledge.documentation_block(block_id) ON DELETE SET NULL,
    section_code        text NOT NULL REFERENCES knowledge.documentation_section(section_code),
    sentence_order      integer NOT NULL,
    content             text NOT NULL,                 -- the controlled-language sentence
    certainty           text NOT NULL DEFAULT 'POSSIBLE'
                         CHECK (certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),  -- SHARED certainty enum (H9 §20/§21)
    source_method_code  text NOT NULL REFERENCES knowledge.fact_capture_method(method_code),  -- SHARED source-hierarchy
    event_time          timestamptz,                  -- the shared clinical_event_time this sentence's facts anchor to
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_sentence
    IS 'Rendered clinical sentences (H9 §15). Every fact has provenance via documentation_sentence_fact (H9 §32).';
CREATE INDEX IF NOT EXISTS idx_doc_sent_inst ON knowledge.documentation_sentence(instance_id);
CREATE INDEX IF NOT EXISTS idx_doc_sent_sec  ON knowledge.documentation_sentence(section_code);

-- B4. documentation_sentence_fact — sentence → source-fact provenance bridge (H9 §32).
CREATE TABLE IF NOT EXISTS knowledge.documentation_sentence_fact (
    sentence_id            uuid NOT NULL REFERENCES knowledge.documentation_sentence(id) ON DELETE CASCADE,
    element_code           text REFERENCES knowledge.documentation_template_element(element_code),
    fact_code              text NOT NULL,             -- canonical fact code
    evidence_rule_code     text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),  -- H8 linkage
    fact_value             text,                       -- the captured value
    source_method_code     text REFERENCES knowledge.fact_capture_method(method_code),
    PRIMARY KEY (sentence_id, fact_code)
);
COMMENT ON TABLE knowledge.documentation_sentence_fact
    IS 'Sentence -> source-fact provenance bridge (H9 §32). Makes every assertion auditable back to a fact and H8 evidence rule.';

-- B5. documentation_event_log — auditable CPU compile log (H9 §41, mirrors H8 reasoning_event).
CREATE TABLE IF NOT EXISTS knowledge.documentation_event_log (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id     uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    event_type      text NOT NULL CHECK (event_type IN
        ('FACT_RECEIVED','ELEMENT_MATCHED','RULE_FIRED','SECTION_RENDERED','SENTENCE_GENERATED',
         'OMISSION_SUPPRESSED','EVIDENCE_SILENCED','CERTAINTY_ADJUSTED','RULE_ACTION_EMITTED','DOCUMENT_COMPILED')),
    rule_code       text REFERENCES knowledge.documentation_template_rule(rule_code),
    element_code    text REFERENCES knowledge.documentation_template_element(element_code),
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    payload         jsonb,
    event_time      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_event_log
    IS 'Auditable CPU compile log (H9 §41).';
CREATE INDEX IF NOT EXISTS idx_doc_evt_inst ON knowledge.documentation_event_log(instance_id);

-- B6. documentation_validation — a compiled document's validation report (H9 §35).
CREATE TABLE IF NOT EXISTS knowledge.documentation_validation (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id     uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    check_name      text NOT NULL,                 -- COMPLETENESS / CHRONOLOGY / CONTRADICTION / …
    status          text NOT NULL CHECK (status IN ('PASS','WARN','FAIL')),
    detail          text,
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (instance_id, check_name, evidence_rule_code)
);
COMMENT ON TABLE knowledge.documentation_validation
    IS 'Per-document validation report (H9 §35/§36/§37).';
