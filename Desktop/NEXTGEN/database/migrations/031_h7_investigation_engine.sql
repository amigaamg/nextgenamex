-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H7 migration 031: universal investigation-selection engine
-- =============================================================================
-- H6 answered: "WHAT do we EXAMINE on this patient, in WHAT ORDER, with WHAT
--               methods, and HOW do we record each finding as a canonical fact?"
-- H7 answers:    "Once history + examination facts are captured, WHAT investigation
--               should be CONSIDERED, WHY, in WHAT ORDER, under WHICH context, and
--               HOW does its RESULT return to the same clinical CPU?"
--
-- Architectural law (H7 §11/§50): an investigation is NOT a disease→test lookup.
-- There is no "pneumonia panel" or "cardiology bundle" engine — only
-- investigation_concepts, their clinical purposes, their indications, their
-- priority/safety rules, their reference standards, and the interpretation table
-- loaded into the universal machine. Selection rules are DATA in
-- investigation_rule, not if-chains in CPU code.
--
-- The MOST IMPORTANT separation (H7 §2/§11): the following are DIFFERENT objects:
--   INVESTIGATION  = knowledge (reusable concept: what a chest radiograph IS)
--   RULE           = knowledge (when it is useful, H7 §11)
--   PURPOSE        = knowledge (which clinical question it answers, H7 §6)
--   REQUEST        = operational (was it actually ordered, H7 §20)
--   SPECIMEN       = operational (the sample/study, H7 §18)
--   RESULT         = operational (what it showed, H7 §15/§16/§17)
--   INTERPRETATION = knowledge + operational (what the result means, H7 §32)
-- Concepts are never disease-owned: CBC is NEVER "the pneumonia test" (H7 §7).
--
-- H7 §21 prioritization is multi-dimensional, not one arbitrary disease weight:
--   priority = clinical_urgency + expected_information + diagnostic_relevance
--            + severity_relevance + management_impact + safety_value + context_fit
--            - harm - cost - redundancy - availability_penalty
-- The dimension weights are DATA (investigation_priority_rule), versioned, so the
-- exact scoring recipe can be tuned without a code change (§21/§30).
--
-- Spec → implementation mapping (H7 §12 core, spec §12/§21/§30/§50):
--   investigation_domain            NEW  — knowledge.investigation_domain (IDOM01..)
--   investigation_concept           NEW  — knowledge.investigation_concept (I001.. = universal investigations)
--   investigation_component         NEW  — knowledge.investigation_component (I001 → {Hb, WBC, PLT, MCV...})
--   investigation_specimen          NEW  — knowledge.investigation_specimen (blood/sputum/urine/image)
--   investigation_method            NEW  — knowledge.investigation_method (analyser/culture/imaging/...)
--   investigation_purpose           NEW  — knowledge.investigation_purpose (14 clinical purposes, H7 §6)
--   investigation_indication        NEW  — knowledge.investigation_indication (WHY it may be useful)
--   investigation_rule              NEW  — knowledge.investigation_rule (selection/priority/safety, H7 §11/§25/§26)
--   investigation_rule_condition    NEW  — knowledge.investigation_rule_condition (extra guards)
--   investigation_rule_action       NEW  — knowledge.investigation_rule_action (dependencies, H7 §25)
--   investigation_priority_rule     NEW  — knowledge.investigation_priority_rule (H7 §21 dimension weights)
--   investigation_request           NEW  — knowledge.investigation_request (RUNTIME, H7 §20, not seeded)
--   investigation_request_item      NEW  — knowledge.investigation_request_item (RUNTIME, not seeded)
--   investigation_status            NEW  — knowledge.investigation_status (operational lifecycle)
--   specimen_collection             NEW  — knowledge.specimen_collection (RUNTIME, H7 §18, not seeded)
--   specimen_processing             NEW  — knowledge.specimen_processing (RUNTIME, not seeded)
--   result                          NEW  — knowledge.result (RUNTIME, H7 §15/§16/§17, not seeded)
--   result_component                NEW  — knowledge.result_component (RUNTIME, structured findings, not seeded)
--   result_value                    NEW  — knowledge.result_value (RUNTIME, numeric + reference compare, not seeded)
--   result_reference_range          NEW  — knowledge.result_reference_standard (age/sex/pregnancy/method contexts, H7 §30)
--   result_interpretation           NEW  — knowledge.result_interpretation (LEUKOCYTOSIS / CONSOLIDATION / ..., H7 §32)
--   result_phenotype_link           NEW  — knowledge.result_phenotype_link (result → phenotype concept, H7 §33)
--   investigation_source            NEW  — knowledge.investigation_source (provenance: source/edition/chapter, H7 §31)
--   investigation_version           NEW  — knowledge.investigation_version (temporal versioning, H7 §24/§30)
--
-- Context coupling (H7 §26/§27/§28): every investigation_concept/investigation_rule/
-- result_reference_standard carries `applies_to_context_codes` so the H5 context
-- engine gates investigation selection the SAME way it gates questions and exams.
-- Pregnancy/renal-function/contrast-safety/radiation constraints are contextual
-- RULES (H7 §26); the concept carries the safety metadata, the CPU decides whether
-- that metadata applies to THIS patient.
--
-- Source note: H7 §44 says the investigation knowledge layer is where Kumar/
-- Davidson and later specialty sources enter. The H7 schema below is source-
-- agnostic (investigation_source/provenance reference any loaded source_version).
-- The seed currently grounds H7 in the AVAILABLE Hutchison claims (respiratory
-- investigation triggers: CXR, spirometry, sputum, pulse oximetry — HCH12-0004,
-- HCH12-0007, HCH12-0019, HCH12-0016) pending later specialty sources.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. investigation_domain — the universal investigation domains (H7 §12)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_domain (
    domain_code       text PRIMARY KEY,              -- IDOM01..
    code              text NOT NULL UNIQUE,          -- HAEMATOLOGY / BIOCHEMISTRY / MICROBIOLOGY / IMAGING / PHYSIOLOGY / PATHOLOGY
    body_system_code  text REFERENCES knowledge.body_system(code),
    label             text NOT NULL,
    description       text,
    sort_order        integer NOT NULL,
    status            text NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_domain
    IS 'Universal investigation domains. A domain spans one discipline (haematology, microbiology, imaging...), NOT one department and NOT one disease.';
CREATE INDEX IF NOT EXISTS idx_inv_domain_system ON knowledge.investigation_domain(body_system_code);
CREATE INDEX IF NOT EXISTS idx_inv_domain_sort   ON knowledge.investigation_domain(sort_order);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_domain_updated_at ON knowledge.investigation_domain;
CREATE TRIGGER trg_knowledge_investigation_domain_updated_at
    BEFORE UPDATE ON knowledge.investigation_domain
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. investigation_concept — universal investigation concepts (H7 §13, I001..)
-- Each concept is a REUSABLE definition of WHAT an investigation is and what it
-- produces. It is NOT a request, NOT a result, and never owned by a disease.
-- base_priority uses H7 §8 absolute urgency (higher = sooner; safety-critical = 1000).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_concept (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                 text NOT NULL UNIQUE,           -- I001..
    domain_code          text NOT NULL REFERENCES knowledge.investigation_domain(domain_code),
    concept_id           uuid REFERENCES knowledge.concept(id),            -- optional canonical concept
    fact_definition_code text REFERENCES clinical.fact_definition(code),   -- single-result investigations (CRP → CRP, pulse oximetry → SPO2)
    canonical_code       text NOT NULL UNIQUE,           -- CBC / CRP / U_E / BLOOD_CULTURE / CHEST_XRAY / ECG / ECHO / SPIROMETRY ...
    canonical_name       text NOT NULL,
    short_label          text,
    description          text,
    modality             text NOT NULL CHECK (modality IN ('LAB','MICROBIOLOGY','IMAGING','PHYSIOLOGY','PATHOLOGY')),
    specimen_type_code   text,                           -- FK wired via ALTER below (specimen table is created after concept)
    preparation_requirements text,                       -- fasting / timing / special instructions (H7 §3)
    patient_constraints  text[],                          -- safety metadata the CPU tests against THIS patient (H7 §26)
    safety_requirements  text,                            -- e.g. renal function before contrast
    result_structure     text NOT NULL DEFAULT 'NUMERIC' CHECK (result_structure IN ('NUMERIC','COMPONENT_PANEL','STRUCTURED_FINDINGS','MICROBIOLOGY','MIXED')),
    clinical_purposes    text[],                          -- purpose codes this concept can serve (H7 §6/§7)
    base_priority        integer NOT NULL DEFAULT 100,    -- H7 §8 absolute urgency (higher = sooner; safety-critical=1000)
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    capture_method_codes text[] NOT NULL DEFAULT '{}',    -- lawful capture (LAB_MEASURED / IMAGING_DERIVED / DEVICE_MEASURED)
    is_mandatory         boolean NOT NULL DEFAULT false,
    status               text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_concept
    IS 'Universal investigation definitions (spec §13). Reusable, never disease-owned, never a request. The CPU selects from these via investigation_rule and materialises a request when ordered.';
CREATE INDEX IF NOT EXISTS idx_inv_concept_domain  ON knowledge.investigation_concept(domain_code);
CREATE INDEX IF NOT EXISTS idx_inv_concept_fact    ON knowledge.investigation_concept(fact_definition_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_concept_updated_at ON knowledge.investigation_concept;
CREATE TRIGGER trg_knowledge_investigation_concept_updated_at
    BEFORE UPDATE ON knowledge.investigation_concept FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. investigation_component — the measurable parts of a composite investigation (H7 §14)
-- CBC is ONE concept whose components (Hb, WBC, neutrophils, platelets, MCV) the
-- CPU reasons over individually (H7 §15). One component = one canonical fact.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_component (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_concept_code text NOT NULL REFERENCES knowledge.investigation_concept(code) ON DELETE CASCADE,
    component_code        text NOT NULL,               -- HAEMOGLOBIN / WBC / NEUTROPHILS / PLATELETS / MCV ...
    fact_definition_code  text NOT NULL REFERENCES clinical.fact_definition(code),
    name                  text NOT NULL,
    short_label           text,
    value_type            text NOT NULL CHECK (value_type IN ('NUMERIC','CATEGORICAL','TEXT','BOOLEAN')),
    unit                  text,                        -- g/dL / x10^9/L / fL ...
    normal_range          jsonb,                       -- {"min":..,"max":..,"unit":..,"inclusive":true} adult default
    sort_order            integer NOT NULL DEFAULT 0,
    is_mandatory          boolean NOT NULL DEFAULT true,
    status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (investigation_concept_code, component_code)
);
COMMENT ON TABLE knowledge.investigation_component
    IS 'A composite investigation''s measurable components (spec §14). Each component maps to ONE canonical fact so results are stored and reasoned over per component, never as "CBC = abnormal" (spec §15).';
CREATE INDEX IF NOT EXISTS idx_inv_component_fact ON knowledge.investigation_component(fact_definition_code);
CREATE INDEX IF NOT EXISTS idx_inv_component_inv  ON knowledge.investigation_component(investigation_concept_code);

-- ---------------------------------------------------------------------------
-- 4. investigation_specimen — the specimen/study required (H7 §18)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_specimen (
    specimen_code      text PRIMARY KEY,                -- SPEC_BLOOD / SPEC_SPUTUM / SPEC_URINE / SPEC_IMAGE / SPEC_NONE
    name               text NOT NULL,
    description        text,
    collection_site    text,                            -- venepuncture / coughed sputum / mid-stream urine / ...
    collection_method  text,
    container_type     text,                            -- EDTA / plain / sterile / imaging series ...
    sort_order         integer NOT NULL,
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_specimen
    IS 'Specimens/studies an investigation requires (spec §18). Enables the request → specimen → processing → result chain to be audited.';
DROP TRIGGER IF EXISTS trg_knowledge_investigation_specimen_updated_at ON knowledge.investigation_specimen;
CREATE TRIGGER trg_knowledge_investigation_specimen_updated_at
    BEFORE UPDATE ON knowledge.investigation_specimen FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- FK wired after investigation_specimen exists.
ALTER TABLE knowledge.investigation_concept
    ADD CONSTRAINT fk_inv_concept_specimen
    FOREIGN KEY (specimen_type_code) REFERENCES knowledge.investigation_specimen(specimen_code);

-- ---------------------------------------------------------------------------
-- 5. investigation_method — the technique/assay behind an investigation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_method (
    method_code      text PRIMARY KEY,                  -- METHOD_LAB_ANALYSER / METHOD_CULTURE / METHOD_MICROSCOPY / METHOD_PCR / METHOD_RADIOGRAPH / METHOD_ULTRASOUND / METHOD_ECG / METHOD_SPIROMETRY / METHOD_PULSE_OXIMETRY
    name             text NOT NULL,
    description      text,
    sort_order       integer NOT NULL,
    status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_method
    IS 'Assay/technique behind an investigation (spec §12). A method may be shared by several investigation_concepts and may gate a result_reference_standard (spec §30).';
DROP TRIGGER IF EXISTS trg_knowledge_investigation_method_updated_at ON knowledge.investigation_method;
CREATE TRIGGER trg_knowledge_investigation_method_updated_at
    BEFORE UPDATE ON knowledge.investigation_method FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 6. investigation_purpose — clinical purpose is a FIRST-CLASS object (H7 §6/§7)
-- The SAME investigation can serve many purposes (CBC: DIAGNOSTIC_SUPPORT +
-- SEVERITY_ASSESSMENT + BASELINE + MONITORING). We never encode "CBC = pneumonia test".
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_purpose (
    purpose_code   text PRIMARY KEY,                    -- PUR001..
    code           text NOT NULL UNIQUE,                -- DIAGNOSIS / CONFIRMATION / EXCLUSION / DIFFERENTIATION / ...
    label          text NOT NULL,
    description    text,
    sort_order     integer NOT NULL,
    status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_purpose
    IS 'Clinical purpose of an investigation (spec §6): DIAGNOSIS, CONFIRMATION, EXCLUSION, DIFFERENTIATION, SEVERITY_ASSESSMENT, BASELINE_ASSESSMENT, COMPLICATION_DETECTION, PROGNOSTICATION, TREATMENT_SELECTION, SAFETY_BEFORE_TREATMENT, MONITORING, RESPONSE_ASSESSMENT, SCREENING, SURVEILLANCE.';
DROP TRIGGER IF EXISTS trg_knowledge_investigation_purpose_updated_at ON knowledge.investigation_purpose;
CREATE TRIGGER trg_knowledge_investigation_purpose_updated_at
    BEFORE UPDATE ON knowledge.investigation_purpose FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 7. investigation_indication — WHY an investigation may be useful (H7 §44)
-- "phenotype X → investigation Y → useful for clinical question Z → under context C
--  → according to source S". This is the knowledge library's contribution to H7.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_indication (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_concept_code text NOT NULL REFERENCES knowledge.investigation_concept(code) ON DELETE CASCADE,
    purpose_code             text NOT NULL REFERENCES knowledge.investigation_purpose(purpose_code),
    clinical_question        text NOT NULL,             -- the H7 §5 question it answers ("Is there consolidation?")
    trigger_fact_codes       text[],                     -- facts that activate this indication
    trigger_phenotype_codes  text[],                     -- phenotypes that activate this indication
    context_codes            text[] NOT NULL DEFAULT '{}',
    evidence_claim_code      text REFERENCES knowledge.source_claim(claim_code),
    strength                 text NOT NULL DEFAULT 'moderate' CHECK (strength IN ('strong','moderate','weak')),
    is_active                boolean NOT NULL DEFAULT true,
    status                   text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (investigation_concept_code, purpose_code, clinical_question)
);
COMMENT ON TABLE knowledge.investigation_indication
    IS 'Declares the clinical question each investigation can answer, grounded in a source claim (spec §44). The CPU generates clinical questions from the clinical state, then matches indications to produce investigation candidates.';
CREATE INDEX IF NOT EXISTS idx_inv_indication_inv ON knowledge.investigation_indication(investigation_concept_code);
CREATE INDEX IF NOT EXISTS idx_inv_indication_purpose ON knowledge.investigation_indication(purpose_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_indication_updated_at ON knowledge.investigation_indication;
CREATE TRIGGER trg_knowledge_investigation_indication_updated_at
    BEFORE UPDATE ON knowledge.investigation_indication FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 8. investigation_rule — the H7 selection engine (H7 §11/§25/§26)
-- "Given TRIGGER (a context, a fact, a symptom/sign, a phenotype, or ALWAYS),
--  do MODIFICATION to TARGET." Mirrors examination_rule (H6) and
-- context_adaptation_rule (H5) but for investigation selection.
--   trigger_type   → ALWAYS / CONTEXT / FACT / SYMPTOM_SIGN / PHENOTYPE
--   target_type    → investigation_concept
--   modification   → SAFETY / MANDATORY / ACTIVATE / UNAVAILABLE / CONDITIONAL /
--                     PRIORITY / DEPENDENCY
--   priority_delta → added to investigation_concept.base_priority (higher score = sooner)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code           text NOT NULL UNIQUE,            -- IR001..
    trigger_type        text NOT NULL CHECK (trigger_type IN ('ALWAYS','CONTEXT','FACT','SYMPTOM_SIGN','PHENOTYPE')),
    trigger_code        text,                       -- clinical_context.code / fact_definition.code / symptom code / phenotype code (NULL for ALWAYS)
    target_type         text NOT NULL CHECK (target_type IN ('investigation_concept')),
    target_code         text NOT NULL,
    modification        text NOT NULL CHECK (modification IN ('SAFETY','MANDATORY','ACTIVATE','UNAVAILABLE','CONDITIONAL','PRIORITY','DEPENDENCY')),
    priority_delta      integer NOT NULL DEFAULT 0,
    rationale           text,
    evidence_claim_code  text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active            boolean NOT NULL DEFAULT true,
    status               text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (target_type, target_code, trigger_type, trigger_code, modification)
);
COMMENT ON TABLE knowledge.investigation_rule
    IS 'H7 selection/priority/safety engine (spec §11/§25/§26). Data-driven: urgency, contraindications, dependencies and conditional activation are rules, not code.';
CREATE INDEX IF NOT EXISTS idx_inv_rule_target ON knowledge.investigation_rule(target_type, target_code);
CREATE INDEX IF NOT EXISTS idx_inv_rule_trigger ON knowledge.investigation_rule(trigger_type, trigger_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_rule_updated_at ON knowledge.investigation_rule;
CREATE TRIGGER trg_knowledge_investigation_rule_updated_at
    BEFORE UPDATE ON knowledge.investigation_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 9. investigation_rule_condition — extra guards on a rule (H7 §10 filter stage)
-- e.g. chronic-cough rule only fires when COUGH_DURATION_DAYS > 56 (HCH12-0004).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_rule_condition (
    condition_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code          text NOT NULL REFERENCES knowledge.investigation_rule(rule_code) ON DELETE CASCADE,
    condition_code     text NOT NULL,                    -- COND001..
    fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
    operator           text NOT NULL CHECK (operator IN ('=', '!=', '>', '>=', '<', '<=', 'IN', 'BETWEEN', 'IS_TRUE', 'IS_FALSE')),
    value              text,                             -- literal value or comma-separated IN list; NULL for IS_TRUE/IS_FALSE
    rationale          text,
    is_active          boolean NOT NULL DEFAULT true,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_code, condition_code)
);
COMMENT ON TABLE knowledge.investigation_rule_condition
    IS 'Optional value-guards on an investigation rule (spec §10 filter stage). The CPU evaluates these against the captured clinical facts before applying the rule.';
CREATE INDEX IF NOT EXISTS idx_inv_rule_condition_rule ON knowledge.investigation_rule_condition(rule_code);

-- ---------------------------------------------------------------------------
-- 10. investigation_rule_action — dependencies and secondary effects (H7 §25)
-- Some investigations depend on others (contrast imaging ← renal function;
-- advanced investigation ← basic assessment). Dependencies are RULES here, never
-- hard-coded in the UI.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_rule_action (
    action_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code            text NOT NULL REFERENCES knowledge.investigation_rule(rule_code) ON DELETE CASCADE,
    action_type          text NOT NULL CHECK (action_type IN ('REQUIRE_RESULT_BEFORE','REQUEST_ALONGSIDE','DEFER','BLOCK')),
    target_investigation_code text NOT NULL REFERENCES knowledge.investigation_concept(code),
    rationale            text,
    sort_order           integer NOT NULL DEFAULT 0,
    is_active            boolean NOT NULL DEFAULT true,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_code, action_type, target_investigation_code)
);
COMMENT ON TABLE knowledge.investigation_rule_action
    IS 'Dependency/sequencing actions attached to a rule (spec §25): REQUIRE_RESULT_BEFORE (e.g. renal function before contrast CT), REQUEST_ALONGSIDE, DEFER, BLOCK. Represented as data, never as UI if-chains.';
CREATE INDEX IF NOT EXISTS idx_inv_rule_action_rule ON knowledge.investigation_rule_action(rule_code);

-- ---------------------------------------------------------------------------
-- 11. investigation_priority_rule — the H7 §21 multi-dimensional priority model
-- ---------------------------------------------------------------------------
-- The exact scoring recipe is versioned DATA. Each dimension carries a direction
-- (positive adds, negative subtracts) and a weight. The CPU computes
--   score = base_priority + Σ(dimension_weight × factor) + Σ(rule priority_delta)
-- The formula itself is defined by the CPU and versioned; the dimension registry
-- below is the tunable knowledge that drives it.
CREATE TABLE IF NOT EXISTS knowledge.investigation_priority_rule (
    priority_rule_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    priority_code     text NOT NULL UNIQUE,              -- IPR001..
    dimension         text NOT NULL UNIQUE CHECK (dimension IN
        ('CLINICAL_URGENCY','EXPECTED_INFORMATION','DIAGNOSTIC_RELEVANCE','SEVERITY_RELEVANCE',
         'MANAGEMENT_IMPACT','SAFETY_VALUE','CONTEXT_FIT','HARM_PENALTY','COST_PENALTY',
         'REDUNDANCY_PENALTY','AVAILABILITY_PENALTY')),
    direction         text NOT NULL DEFAULT 'POSITIVE' CHECK (direction IN ('POSITIVE','NEGATIVE')),
    weight            numeric(4,2) NOT NULL DEFAULT 1.00,
    description       text,
    version           integer NOT NULL DEFAULT 1,
    effective_from    date,
    status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_priority_rule
    IS 'Versioned multi-dimensional priority model (spec §21). Dimensions are data so the scoring recipe is tunable and auditable; no arbitrary disease weight.';
DROP TRIGGER IF EXISTS trg_knowledge_investigation_priority_rule_updated_at ON knowledge.investigation_priority_rule;
CREATE TRIGGER trg_knowledge_investigation_priority_rule_updated_at
    BEFORE UPDATE ON knowledge.investigation_priority_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 12. investigation_source — provenance of the investigation knowledge (H7 §31)
-- ---------------------------------------------------------------------------
-- Every important standard/selection should trace back to a source, publication,
-- organization, edition, year, chapter, section, version, effective window. This is
-- where AMEXAN's medical knowledge governance becomes real.
CREATE TABLE IF NOT EXISTS knowledge.investigation_source (
    source_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_concept_code text NOT NULL REFERENCES knowledge.investigation_concept(code) ON DELETE CASCADE,
    source_version_id         text NOT NULL REFERENCES knowledge.source_version(version_id),
    reference                 text,                      -- free-text reference (chapter/page)
    organization              text,
    publication               text,
    edition                   text,
    year                      integer,
    chapter_ref               text,
    section_ref               text,
    version                   text,
    effective_from            date,
    effective_to              date,
    status                    text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now(),
    UNIQUE (investigation_concept_code, source_version_id)
);
COMMENT ON TABLE knowledge.investigation_source
    IS 'Source provenance for investigation knowledge (spec §31). Every investigation concept records the authoritative source that defines/grounds it; complements knowledge.provenance for per-object claim edges.';
CREATE INDEX IF NOT EXISTS idx_inv_source_concept ON knowledge.investigation_source(investigation_concept_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_source_updated_at ON knowledge.investigation_source;
CREATE TRIGGER trg_knowledge_investigation_source_updated_at
    BEFORE UPDATE ON knowledge.investigation_source FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 13. investigation_version — temporal versioning of investigation knowledge (H7 §24/§30)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_version (
    version_id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_concept_code text NOT NULL REFERENCES knowledge.investigation_concept(code) ON DELETE CASCADE,
    version_no               integer NOT NULL,
    effective_from           date,
    effective_to             date,
    supersedes               uuid REFERENCES knowledge.investigation_version(version_id),
    change_note              text,
    status                   text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (investigation_concept_code, version_no)
);
COMMENT ON TABLE knowledge.investigation_version
    IS 'Version history of an investigation concept (spec §24/§30). Supports temporal validity: a result/reference may be valid for one version window, obsolete after a clinical change or a guideline update.';
CREATE INDEX IF NOT EXISTS idx_inv_version_concept ON knowledge.investigation_version(investigation_concept_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_version_updated_at ON knowledge.investigation_version;
CREATE TRIGGER trg_knowledge_investigation_version_updated_at
    BEFORE UPDATE ON knowledge.investigation_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 14. result_reference_standard — age/sex/pregnancy/method-adjusted ranges (H7 §30)
-- ---------------------------------------------------------------------------
-- A result (e.g. Hb = 9.8 g/dL) does NOT itself say "anaemia" (H7 §29). The CPU
-- compares it against the CORRECT contextual standard: age, sex, pregnancy,
-- altitude, laboratory, method, unit, population. Standards are versioned (via
-- investigation_version) and sourced (evidence_claim_code).
CREATE TABLE IF NOT EXISTS knowledge.result_reference_standard (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                     text NOT NULL UNIQUE,       -- RRS001.. (stable provenance joins)
    investigation_concept_code text REFERENCES knowledge.investigation_concept(code) ON DELETE CASCADE,  -- NULL = component-level
    component_code           text,                       -- investigation_component.component_code when component-level
    fact_definition_code     text REFERENCES clinical.fact_definition(code),
    method_code              text REFERENCES knowledge.investigation_method(method_code),   -- method-specific range (H7 §30)
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',   -- NEONATE / CHILD / ADULT / OLDER_ADULT / PREGNANCY ...
    sex                      text CHECK (sex IN ('MALE','FEMALE','ANY')) DEFAULT 'ANY',
    range_low                numeric,
    range_high               numeric,
    range_unit               text,
    is_inclusive             boolean NOT NULL DEFAULT true,
    classification           text NOT NULL DEFAULT 'NORMAL', -- NORMAL / ABNORMAL / CRITICAL (what this band MEANS)
    source                   text,                       -- guideline/hierarchy name
    source_claim_code        text REFERENCES knowledge.source_claim(claim_code),
    evidence_strength        text NOT NULL DEFAULT 'strong' CHECK (evidence_strength IN ('strong','moderate','weak')),
    status                   text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (investigation_concept_code, component_code, fact_definition_code, applies_to_context_codes, sex)
);
COMMENT ON TABLE knowledge.result_reference_standard
    IS 'Contextual reference standards for results (spec §30): RAW RESULT → REFERENCE STANDARD → CLASSIFICATION → CLINICAL PHENOTYPE (spec §29). Bands may be age/sex/pregnancy/method specific; every band is sourced and versioned.';
CREATE INDEX IF NOT EXISTS idx_result_refstd_concept ON knowledge.result_reference_standard(investigation_concept_code);
CREATE INDEX IF NOT EXISTS idx_result_refstd_fact    ON knowledge.result_reference_standard(fact_definition_code);

-- ---------------------------------------------------------------------------
-- 15. result_interpretation — controlled interpretation of a result (H7 §32)
-- ---------------------------------------------------------------------------
-- Interpretation is separate from the raw result: WBC = 23 → LEUKOCYTOSIS PRESENT
-- → NEUTROPHILIC_INFLAMMATORY_PATTERN PRESENT → phenotype (H7 §32/§33).
CREATE TABLE IF NOT EXISTS knowledge.result_interpretation (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                   text NOT NULL UNIQUE,          -- RINT_LEUKOCYTOSIS / RINT_CONSOLIDATION / RINT_MTB_DETECTED ...
    canonical_name         text NOT NULL,
    label                  text NOT NULL,
    result_type_constraint text CHECK (result_type_constraint IN ('LAB','IMAGING','MICROBIOLOGY','PHYSIOLOGY')),
    is_abnormal            boolean NOT NULL DEFAULT false,
    is_critical            boolean NOT NULL DEFAULT false,
    description            text,
    sort_order             integer NOT NULL,
    status                 text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.result_interpretation
    IS 'Controlled vocabulary of result interpretations (spec §32): from NORMAL/ABNORMAL to findings (CONSOLIDATION, PLEURAL_EFFUSION, LEUKOCYTOSIS, MTB_DETECTED...). Separate from the raw result.';
CREATE INDEX IF NOT EXISTS idx_result_interp_abnormal ON knowledge.result_interpretation(is_abnormal);

-- ---------------------------------------------------------------------------
-- 16. result_phenotype_link — result interpretation → downstream concept (H7 §33)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.result_phenotype_link (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    result_interpretation_code text NOT NULL REFERENCES knowledge.result_interpretation(code) ON DELETE CASCADE,
    associated_concept_code text,                      -- a knowledge.concept code (phenotype/condition/sign) for H8 consumption
    strength                text NOT NULL DEFAULT 'moderate' CHECK (strength IN ('strong','moderate','weak')),
    description             text,
    evidence_claim_code     text REFERENCES knowledge.source_claim(claim_code),
    is_active               boolean NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    UNIQUE (result_interpretation_code, associated_concept_code)
);
COMMENT ON TABLE knowledge.result_phenotype_link
    IS 'Bridge from a result interpretation to the phenotype/concept it supports (spec §33): CXR consolidation → AIRSPACE_CONSOLIDATION_PHENOTYPE; microcytosis → MICROCYTIC_PATTERN; ECG AF → ATRIAL_ARRHYTHMIA_PHENOTYPE. H8 consumes these.';
CREATE INDEX IF NOT EXISTS idx_result_pl_ri ON knowledge.result_phenotype_link(result_interpretation_code);

-- ---------------------------------------------------------------------------
-- 17. investigation_status — operational lifecycle of a request (H7 §20/§12)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.investigation_status (
    status_code   text PRIMARY KEY,                      -- RECOMMENDED / ORDERED / SPECIMEN_COLLECTED / IN_PROGRESS / RESULT_AVAILABLE / REPORTED / CANCELLED / ENTERED_IN_ERROR
    label         text NOT NULL,
    description   text,
    sort_order    integer NOT NULL,
    is_terminal   boolean NOT NULL DEFAULT false,
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired'))
);
COMMENT ON TABLE knowledge.investigation_status
    IS 'Operational lifecycle states of an investigation request and its result chain (spec §20/§12).';
CREATE INDEX IF NOT EXISTS idx_inv_status_sort ON knowledge.investigation_status(sort_order);

-- ---------------------------------------------------------------------------
-- 18–24. Runtime tables (H7 §15/§16/§17/§20) — created, NOT seeded
-- The CPU populates investigation_request/request_item/specimen_collection/
-- specimen_processing/result/result_component/result_value at runtime from the
-- knowledge tables above. Rows below are engine output.
-- ---------------------------------------------------------------------------

-- 18. investigation_request — an actual order for one patient/encounter (H7 §20)
CREATE TABLE IF NOT EXISTS knowledge.investigation_request (
    request_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id      uuid NOT NULL,                     -- clinical.encounter
    patient_id        uuid,
    context_stack     jsonb,                             -- H5 context codes active for this plan
    purpose_code      text REFERENCES knowledge.investigation_purpose(purpose_code),
    priority          text,                              -- e.g. CRITICAL / HIGH / MEDIUM / ROUTINE (display)
    total_priority    integer,                           -- computed score (H7 §21)
    status_code       text NOT NULL DEFAULT 'RECOMMENDED' REFERENCES knowledge.investigation_status(status_code),
    requested_by      text,
    requested_at      timestamptz NOT NULL DEFAULT now(),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.investigation_request
    IS 'An actual investigation request for one patient/encounter (spec §20). Operational data: WHO ordered WHAT for WHICH purpose at WHAT priority with WHAT status.';
CREATE INDEX IF NOT EXISTS idx_inv_request_encounter ON knowledge.investigation_request(encounter_id);
CREATE INDEX IF NOT EXISTS idx_inv_request_status ON knowledge.investigation_request(status_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_request_updated_at ON knowledge.investigation_request;
CREATE TRIGGER trg_knowledge_investigation_request_updated_at
    BEFORE UPDATE ON knowledge.investigation_request FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 19. investigation_request_item — one investigation line on a request (H7 §20)
CREATE TABLE IF NOT EXISTS knowledge.investigation_request_item (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id           uuid NOT NULL REFERENCES knowledge.investigation_request(request_id) ON DELETE CASCADE,
    investigation_concept_code text NOT NULL REFERENCES knowledge.investigation_concept(code),
    purpose_code         text REFERENCES knowledge.investigation_purpose(purpose_code),
    priority             integer NOT NULL,               -- base_priority + rule deltas + priority-model score
    reason               text,                           -- the H7 §46 explanation ("triggering facts...")
    evidence_rule_code   text REFERENCES knowledge.investigation_rule(rule_code),  -- which rule matched
    status_code          text NOT NULL DEFAULT 'RECOMMENDED' REFERENCES knowledge.investigation_status(status_code),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (request_id, investigation_concept_code)
);
COMMENT ON TABLE knowledge.investigation_request_item
    IS 'One investigation on a request (spec §20). Each line records purpose, priority, reason and the evidence rule that generated it (spec §45/§46).';
CREATE INDEX IF NOT EXISTS idx_inv_request_item_request ON knowledge.investigation_request_item(request_id);
CREATE INDEX IF NOT EXISTS idx_inv_request_item_concept ON knowledge.investigation_request_item(investigation_concept_code);
DROP TRIGGER IF EXISTS trg_knowledge_investigation_request_item_updated_at ON knowledge.investigation_request_item;
CREATE TRIGGER trg_knowledge_investigation_request_item_updated_at
    BEFORE UPDATE ON knowledge.investigation_request_item FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 20. specimen_collection — the specimen taken (H7 §18)
CREATE TABLE IF NOT EXISTS knowledge.specimen_collection (
    collection_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_item_id   uuid NOT NULL REFERENCES knowledge.investigation_request_item(id) ON DELETE CASCADE,
    specimen_code     text NOT NULL REFERENCES knowledge.investigation_specimen(specimen_code),
    collection_site   text,
    collection_method text,
    condition         text,                               -- e.g. early-morning sputum, fasting blood
    laboratory        text,
    collected_at      timestamptz,
    collected_by      text,
    status_code       text NOT NULL DEFAULT 'SPECIMEN_COLLECTED' REFERENCES knowledge.investigation_status(status_code),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.specimen_collection
    IS 'The actual specimen/study taken for a requested investigation (spec §18). Enables the whole request → specimen → processing → result chain to be audited.';
CREATE INDEX IF NOT EXISTS idx_specimen_collection_item ON knowledge.specimen_collection(request_item_id);

-- 21. specimen_processing — lab handling of the specimen
CREATE TABLE IF NOT EXISTS knowledge.specimen_processing (
    processing_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id     uuid NOT NULL REFERENCES knowledge.specimen_collection(collection_id) ON DELETE CASCADE,
    method_code       text REFERENCES knowledge.investigation_method(method_code),
    laboratory        text,
    received_at       timestamptz,
    processor         text,
    status_code       text NOT NULL DEFAULT 'IN_PROGRESS' REFERENCES knowledge.investigation_status(status_code),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.specimen_processing
    IS 'Laboratory processing of a collected specimen (spec §12/§19).';
CREATE INDEX IF NOT EXISTS idx_specimen_processing_collection ON knowledge.specimen_processing(collection_id);

-- 22. result — a completed investigation result (H7 §15/§16/§17)
CREATE TABLE IF NOT EXISTS knowledge.result (
    result_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_item_id       uuid NOT NULL REFERENCES knowledge.investigation_request_item(id) ON DELETE CASCADE,
    investigation_concept_code text NOT NULL REFERENCES knowledge.investigation_concept(code),
    collection_id         uuid REFERENCES knowledge.specimen_collection(collection_id),
    result_structure      text CHECK (result_structure IN ('NUMERIC','COMPONENT_PANEL','STRUCTURED_FINDINGS','MICROBIOLOGY')),
    status_code           text NOT NULL DEFAULT 'RESULT_AVAILABLE' REFERENCES knowledge.investigation_status(status_code),
    resulted_at           timestamptz,
    resulted_by           text,
    notes                 text,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.result
    IS 'A completed investigation result (spec §15-§17). Generic enough to hold numeric labs, component panels, structured imaging findings and microbiology, whose parts live in result_component/result_value.';
CREATE INDEX IF NOT EXISTS idx_result_request_item ON knowledge.result(request_item_id);
CREATE INDEX IF NOT EXISTS idx_result_concept ON knowledge.result(investigation_concept_code);
DROP TRIGGER IF EXISTS trg_knowledge_result_updated_at ON knowledge.result;
CREATE TRIGGER trg_knowledge_result_updated_at
    BEFORE UPDATE ON knowledge.result FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 23. result_component — structured parts/findings of a result (H7 §16/§17)
CREATE TABLE IF NOT EXISTS knowledge.result_component (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    result_id            uuid NOT NULL REFERENCES knowledge.result(result_id) ON DELETE CASCADE,
    component_code       text NOT NULL,                   -- e.g. HAEMOGLOBIN or a finding (CONSOLIDATION)
    fact_definition_code text REFERENCES clinical.fact_definition(code),
    finding              text,                            -- imaging finding / organism / structured finding (H7 §16/§17)
    anatomical_site      text,                            -- e.g. RIGHT_LOWER_LOBE
    laterality           text CHECK (laterality IN ('LEFT','RIGHT','BILATERAL','MIDLINE','NONE')) ,
    severity             text,                            -- MILD / MODERATE / SEVERE for findings
    certainty            text,                            -- DEFINITE / PROBABLE / POSSIBLE for findings
    interpretation_code  text REFERENCES knowledge.result_interpretation(code),
    is_abnormal          boolean,
    status               text NOT NULL DEFAULT 'recorded' CHECK (status IN ('recorded','entered','final','entered_in_error')),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.result_component
    IS 'Structured components/findings of a result (spec §16/§17): numeric components of a panel, imaging findings with anatomical site/laterality/severity/certainty, and microbiology organism/finding records.';
CREATE INDEX IF NOT EXISTS idx_result_component_result ON knowledge.result_component(result_id);
CREATE INDEX IF NOT EXISTS idx_result_component_finding ON knowledge.result_component(finding);

-- 24. result_value — the measured value compared against its reference standard (H7 §15/§29)
CREATE TABLE IF NOT EXISTS knowledge.result_value (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    result_id             uuid NOT NULL REFERENCES knowledge.result(result_id) ON DELETE CASCADE,
    result_component_id   uuid REFERENCES knowledge.result_component(id),
    fact_definition_code  text NOT NULL REFERENCES clinical.fact_definition(code),
    value_numeric         numeric,
    value_text            text,
    unit                  text,
    reference_standard_code text REFERENCES knowledge.result_reference_standard(code),
    classification        text NOT NULL DEFAULT 'UNMEASURED' CHECK (classification IN ('NORMAL','ABNORMAL','CRITICAL','UNMEASURED')),
    interpretation_code   text REFERENCES knowledge.result_interpretation(code),
    is_abnormal           boolean,
    recorded_at           timestamptz NOT NULL DEFAULT now(),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.result_value
    IS 'The measured value compared against its contextual reference standard (spec §15/§29): RAW RESULT → REFERENCE STANDARD → CLASSIFICATION → PHENOTYPE. One row per numeric measurement.';
CREATE INDEX IF NOT EXISTS idx_result_value_result ON knowledge.result_value(result_id);
CREATE INDEX IF NOT EXISTS idx_result_value_standard ON knowledge.result_value(reference_standard_code);
CREATE INDEX IF NOT EXISTS idx_result_value_fact ON knowledge.result_value(fact_definition_code);

-- ---------------------------------------------------------------------------
-- 25. Provenance note — H7 objects derive from source claims
-- ---------------------------------------------------------------------------
COMMENT ON TABLE knowledge.provenance
    IS 'Derivation edges from source claims to compiled AMEXAN objects (H1 claims → H2 history concepts, H3 questions/rules, H4 dimensions/red-flags, H5 contexts/variants/adaptation rules, H6 examination concepts/observations/interpretations/reference-standards/examination-rules, H7 investigation concepts/components/rules/reference-standards/interpretations/phenotype-links).';
