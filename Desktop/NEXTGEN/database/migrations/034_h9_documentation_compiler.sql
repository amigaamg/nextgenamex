-- AMEXAN Medical Knowledge Compiler â€” H9 Migration 034
-- Clinical Documentation Compiler
--
-- Constitutional rules:
-- 1. PostgreSQL stores documentation knowledge/configuration.
-- 2. CPU compiles patient-specific documentation.
-- 3. UI renders documentation_sentence; it never reasons or rewrites clinically.
-- 4. H9 never invents facts, diagnoses, chronology, examination findings,
--    causal explanations, treatment responses, or complications.
-- 5. UNKNOWN / NOT_ASSESSED are never silently converted to ABSENT.
-- 6. Certainty is preserved from H8 and never upgraded by language realization.
-- 7. Output is natural professional clinical English, not database-like prose.
-- 8. Every material assertion remains traceable to its source fact/event.

BEGIN;

CREATE SCHEMA IF NOT EXISTS knowledge;

-- Existing shared registries are intentionally reused:
-- knowledge.fact_capture_method, clinical.fact_definition,
-- knowledge.phenotype, knowledge.mechanism,
-- knowledge.result_interpretation, knowledge.clinical_context,
-- knowledge.diagnosis_concept, knowledge.differential_evidence_rule,
-- knowledge.reasoning_run, knowledge.clinical_fact_state,
-- knowledge.source_claim, clinical.clinical_event, public.set_updated_at().
-- H9 must fail rather than create incompatible duplicate registries.

-- ============================================================================
-- A. KNOWLEDGE / CONFIGURATION
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.documentation_section CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.documentation_section (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    section_code text NOT NULL UNIQUE,
    label text NOT NULL,
    heading_template text NOT NULL,
    section_type text NOT NULL CHECK (section_type IN ('NARRATIVE','TABLE','LIST','SCALAR')),
    is_required boolean NOT NULL DEFAULT true,
    is_repeatable boolean NOT NULL DEFAULT false,
    default_certainty text NOT NULL DEFAULT 'POSSIBLE'
        CHECK (default_certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),
    sort_order integer NOT NULL DEFAULT 1,
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_section IS
'Canonical clinical-document sections. Sections are configuration, not free-form UI headings.';
CREATE INDEX IF NOT EXISTS idx_doc_section_sort ON knowledge.documentation_section(sort_order);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_section_updated_at ON knowledge.documentation_section;
CREATE TRIGGER trg_knowledge_documentation_section_updated_at
BEFORE UPDATE ON knowledge.documentation_section
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_template (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code text NOT NULL UNIQUE,
    canonical_name text NOT NULL,
    short_label text,
    description text,
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_template IS
'Clinical-document frame. It determines document structure, never the patient-specific clinical conclusion.';
CREATE INDEX IF NOT EXISTS idx_doc_template_active ON knowledge.documentation_template(is_active);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_template_updated_at ON knowledge.documentation_template;
CREATE TRIGGER trg_knowledge_documentation_template_updated_at
BEFORE UPDATE ON knowledge.documentation_template
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_template_section (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code text NOT NULL REFERENCES knowledge.documentation_template(template_code) ON DELETE CASCADE,
    section_code text NOT NULL REFERENCES knowledge.documentation_section(section_code) ON DELETE CASCADE,
    sort_order integer NOT NULL DEFAULT 1,
    is_required boolean NOT NULL DEFAULT false,
    is_repeatable boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (template_code, section_code)
);
COMMENT ON TABLE knowledge.documentation_template_section IS
'Defines canonical sections belonging to a document template and their clinical order.';

CREATE TABLE IF NOT EXISTS knowledge.documentation_template_element (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    element_code text NOT NULL UNIQUE,
    template_code text NOT NULL REFERENCES knowledge.documentation_template(template_code) ON DELETE CASCADE,
    section_code text NOT NULL REFERENCES knowledge.documentation_section(section_code) ON DELETE CASCADE,
    evidence_type text NOT NULL CHECK (evidence_type IN (
        'FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','EVIDENCE_RULE','CLINICAL_HYPOTHESIS'
    )),
    fact_definition_code text REFERENCES clinical.fact_definition(code),
    phenotype_code text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    diagnosis_code text REFERENCES knowledge.diagnosis_concept(code),
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    wording_template text NOT NULL,
    source_method_code text NOT NULL REFERENCES knowledge.fact_capture_method(method_code),
    certainty text NOT NULL DEFAULT 'POSSIBLE'
        CHECK (certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),
    min_strength numeric(5,2),
    is_must_document boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (evidence_type = 'FACT' AND fact_definition_code IS NOT NULL) OR
        (evidence_type = 'PHENOTYPE' AND phenotype_code IS NOT NULL) OR
        (evidence_type = 'MECHANISM' AND mechanism_code IS NOT NULL) OR
        (evidence_type = 'RESULT_INTERPRETATION' AND result_interpretation_code IS NOT NULL) OR
        (evidence_type IN ('DIAGNOSIS','CLINICAL_HYPOTHESIS') AND diagnosis_code IS NOT NULL) OR
        (evidence_type = 'EVIDENCE_RULE' AND evidence_rule_code IS NOT NULL)
    )
);
COMMENT ON TABLE knowledge.documentation_template_element IS
'Structured documentation proposition. It may be rendered only when supported by patient-specific evidence; the element itself never creates a fact.';
CREATE INDEX IF NOT EXISTS idx_doc_elem_tmpl ON knowledge.documentation_template_element(template_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_sec ON knowledge.documentation_template_element(section_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_rule ON knowledge.documentation_template_element(evidence_rule_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_fact ON knowledge.documentation_template_element(fact_definition_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_pheno ON knowledge.documentation_template_element(phenotype_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_mech ON knowledge.documentation_template_element(mechanism_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_result ON knowledge.documentation_template_element(result_interpretation_code);
CREATE INDEX IF NOT EXISTS idx_doc_elem_dx ON knowledge.documentation_template_element(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_template_element_updated_at ON knowledge.documentation_template_element;
CREATE TRIGGER trg_knowledge_documentation_template_element_updated_at
BEFORE UPDATE ON knowledge.documentation_template_element
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_template_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL UNIQUE,
    template_code text NOT NULL REFERENCES knowledge.documentation_template(template_code) ON DELETE CASCADE,
    trigger_type text NOT NULL CHECK (trigger_type IN (
        'FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','EVIDENCE_RULE',
        'CANDIDATE_STATE','CLINICAL_HYPOTHESIS','CONTEXT','CLINICAL_EVENT','ALWAYS'
    )),
    trigger_code text,
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    target_element_code text NOT NULL REFERENCES knowledge.documentation_template_element(element_code),
    action text NOT NULL CHECK (action IN (
        'RENDER','SUPPRESS','ESCALATE','MARK_CRITICAL','REQUEST_INFORMATION',
        'CREATE_QUESTION_GAP','TRIGGER_INVESTIGATION','STRONGLY_INCLUDE','WEAKLY_INCLUDE'
    )),
    weight_delta numeric(5,2) NOT NULL DEFAULT 0,
    wording_template text,
    message text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    applies_to_clinical_event boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_template_rule IS
'Data-driven documentation rule. Rules select and phrase supported propositions; they never create unsupported clinical meaning.';
CREATE INDEX IF NOT EXISTS idx_doc_rule_tmpl ON knowledge.documentation_template_rule(template_code);
CREATE INDEX IF NOT EXISTS idx_doc_rule_elem ON knowledge.documentation_template_rule(target_element_code);
CREATE INDEX IF NOT EXISTS idx_doc_rule_trigger ON knowledge.documentation_template_rule(trigger_type, trigger_code);
CREATE INDEX IF NOT EXISTS idx_doc_rule_evidence ON knowledge.documentation_template_rule(evidence_rule_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_template_rule_updated_at ON knowledge.documentation_template_rule;
CREATE TRIGGER trg_knowledge_documentation_template_rule_updated_at
BEFORE UPDATE ON knowledge.documentation_template_rule
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_order_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL UNIQUE,
    section_code text NOT NULL REFERENCES knowledge.documentation_section(section_code) ON DELETE CASCADE,
    proposition_code text NOT NULL,
    proposition_type text NOT NULL CHECK (proposition_type IN (
        'FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS'
    )),
    clinical_narrative_position text NOT NULL,
    sort_order integer NOT NULL DEFAULT 1,
    wording_template text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_order_rule IS
'Clinical semantic ordering for readable narrative. It prevents arbitrary database-order prose.';
CREATE INDEX IF NOT EXISTS idx_doc_order_sec ON knowledge.documentation_order_rule(section_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_order_rule_updated_at ON knowledge.documentation_order_rule;
CREATE TRIGGER trg_knowledge_documentation_order_rule_updated_at
BEFORE UPDATE ON knowledge.documentation_order_rule
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_relevance_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL UNIQUE,
    proposition_code text NOT NULL,
    proposition_type text NOT NULL CHECK (proposition_type IN (
        'FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS'
    )),
    priority_level text NOT NULL CHECK (priority_level IN ('HIGH','MEDIUM','LOW','EXCLUDE')),
    rationale text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_relevance_rule IS
'Controls clinical documentation priority. Capture does not imply that a fact belongs in the final note.';
CREATE INDEX IF NOT EXISTS idx_doc_rel_prio ON knowledge.documentation_relevance_rule(priority_level);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_relevance_rule_updated_at ON knowledge.documentation_relevance_rule;
CREATE TRIGGER trg_knowledge_documentation_relevance_rule_updated_at
BEFORE UPDATE ON knowledge.documentation_relevance_rule
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_lexicon (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_code text NOT NULL,
    concept_type text NOT NULL CHECK (concept_type IN (
        'FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','DIAGNOSIS','CONTEXT'
    )),
    canonical_term text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (concept_code, concept_type)
);
COMMENT ON TABLE knowledge.documentation_lexicon IS
'Canonical clinical terminology used by the language realizer.';
CREATE INDEX IF NOT EXISTS idx_doc_lex_concept ON knowledge.documentation_lexicon(concept_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_lexicon_updated_at ON knowledge.documentation_lexicon;
CREATE TRIGGER trg_knowledge_documentation_lexicon_updated_at
BEFORE UPDATE ON knowledge.documentation_lexicon
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_term (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lexicon_id uuid NOT NULL REFERENCES knowledge.documentation_lexicon(id) ON DELETE CASCADE,
    applies_to_context_code text NOT NULL REFERENCES knowledge.clinical_context(code),
    preferred_label text NOT NULL,
    wording_template text,
    is_preferred boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (lexicon_id, applies_to_context_code)
);
COMMENT ON TABLE knowledge.documentation_term IS
'Context-aware clinical wording, including age/context-appropriate terminology.';
CREATE INDEX IF NOT EXISTS idx_doc_term_lex ON knowledge.documentation_term(lexicon_id);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_term_updated_at ON knowledge.documentation_term;
CREATE TRIGGER trg_knowledge_documentation_term_updated_at
BEFORE UPDATE ON knowledge.documentation_term
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_term_variant (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    term_id uuid NOT NULL REFERENCES knowledge.documentation_term(id) ON DELETE CASCADE,
    variant_label text NOT NULL,
    language_code text NOT NULL DEFAULT 'en',
    applies_to_context_code text REFERENCES knowledge.clinical_context(code),
    is_preferred boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (term_id, variant_label, language_code)
);
COMMENT ON TABLE knowledge.documentation_term_variant IS
'Controlled synonyms and context-specific variants. Variants must remain clinically equivalent to the canonical concept.';

CREATE TABLE IF NOT EXISTS knowledge.documentation_version (
    version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_code text NOT NULL UNIQUE,
    ruleset_version text NOT NULL,
    knowledge_version text NOT NULL,
    engine_version text NOT NULL,
    effective_from date,
    change_note text,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_version IS
'Documentation compiler version registry. Each compiled document records the exact ruleset, knowledge and engine versions used.';
DROP TRIGGER IF EXISTS trg_knowledge_documentation_version_updated_at ON knowledge.documentation_version;
CREATE TRIGGER trg_knowledge_documentation_version_updated_at
BEFORE UPDATE ON knowledge.documentation_version
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- B. RUNTIME
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.documentation_instance (
    instance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    template_code text NOT NULL REFERENCES knowledge.documentation_template(template_code),
    clinical_event_id uuid REFERENCES clinical.clinical_event(id) ON DELETE SET NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    status text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPILED','FAILED')),
    ruleset_version text,
    knowledge_version text,
    engine_version text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (completed_at IS NULL OR completed_at >= started_at)
);
COMMENT ON TABLE knowledge.documentation_instance IS
'One CPU-compiled clinical document for an H8 reasoning run, optionally anchored to a shared clinical event.';
CREATE INDEX IF NOT EXISTS idx_doc_inst_run ON knowledge.documentation_instance(run_id);
CREATE INDEX IF NOT EXISTS idx_doc_inst_tmpl ON knowledge.documentation_instance(template_code);
CREATE INDEX IF NOT EXISTS idx_doc_inst_evt ON knowledge.documentation_instance(clinical_event_id);

CREATE TABLE IF NOT EXISTS knowledge.documentation_block (
    block_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    section_code text NOT NULL REFERENCES knowledge.documentation_section(section_code),
    block_order integer NOT NULL,
    block_label text,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (instance_id, section_code, block_order)
);
COMMENT ON TABLE knowledge.documentation_block IS
'Structured clinical-document blocks preserving section and narrative organization before sentence rendering.';
CREATE INDEX IF NOT EXISTS idx_doc_block_inst ON knowledge.documentation_block(instance_id);

CREATE TABLE IF NOT EXISTS knowledge.documentation_sentence (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    block_id uuid REFERENCES knowledge.documentation_block(block_id) ON DELETE SET NULL,
    section_code text NOT NULL REFERENCES knowledge.documentation_section(section_code),
    sentence_order integer NOT NULL,
    content text NOT NULL CHECK (length(btrim(content)) > 0),
    certainty text NOT NULL DEFAULT 'POSSIBLE'
        CHECK (certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),
    source_method_code text NOT NULL REFERENCES knowledge.fact_capture_method(method_code),
    event_time timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (instance_id, section_code, sentence_order)
);
COMMENT ON TABLE knowledge.documentation_sentence IS
'Final controlled clinical-language sentence. The UI renders this value and must not perform clinical reasoning or certainty upgrading.';
CREATE INDEX IF NOT EXISTS idx_doc_sent_inst ON knowledge.documentation_sentence(instance_id);
CREATE INDEX IF NOT EXISTS idx_doc_sent_sec ON knowledge.documentation_sentence(section_code);
CREATE INDEX IF NOT EXISTS idx_doc_sent_event_time ON knowledge.documentation_sentence(event_time);

CREATE TABLE IF NOT EXISTS knowledge.documentation_sentence_fact (
    sentence_id uuid NOT NULL REFERENCES knowledge.documentation_sentence(id) ON DELETE CASCADE,
    element_code text REFERENCES knowledge.documentation_template_element(element_code),
    fact_code text NOT NULL,
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    fact_value text,
    fact_state text REFERENCES knowledge.clinical_fact_state(state_code),
    source_method_code text REFERENCES knowledge.fact_capture_method(method_code),
    event_id uuid REFERENCES clinical.clinical_event(id) ON DELETE SET NULL,
    PRIMARY KEY (sentence_id, fact_code)
);
COMMENT ON TABLE knowledge.documentation_sentence_fact IS
'Sentence-level provenance. Each material assertion can be traced to the underlying patient fact/event and, where applicable, H8 evidence logic.';
CREATE INDEX IF NOT EXISTS idx_doc_sent_fact_rule ON knowledge.documentation_sentence_fact(evidence_rule_code);
CREATE INDEX IF NOT EXISTS idx_doc_sent_fact_event ON knowledge.documentation_sentence_fact(event_id);

CREATE TABLE IF NOT EXISTS knowledge.documentation_event_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    event_type text NOT NULL CHECK (event_type IN (
        'FACT_RECEIVED','ELEMENT_MATCHED','RULE_FIRED','SECTION_RENDERED','SENTENCE_GENERATED',
        'OMISSION_SUPPRESSED','EVIDENCE_SILENCED','CERTAINTY_ADJUSTED','RULE_ACTION_EMITTED',
        'DOCUMENT_COMPILED','VALIDATION_PASSED','VALIDATION_WARNED','VALIDATION_FAILED'
    )),
    rule_code text REFERENCES knowledge.documentation_template_rule(rule_code),
    element_code text REFERENCES knowledge.documentation_template_element(element_code),
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    payload jsonb,
    event_time timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_event_log IS
'Auditable CPU documentation-compilation event stream.';
CREATE INDEX IF NOT EXISTS idx_doc_evt_inst ON knowledge.documentation_event_log(instance_id);
CREATE INDEX IF NOT EXISTS idx_doc_evt_type ON knowledge.documentation_event_log(event_type);

CREATE TABLE IF NOT EXISTS knowledge.documentation_validation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id uuid NOT NULL REFERENCES knowledge.documentation_instance(instance_id) ON DELETE CASCADE,
    check_name text NOT NULL,
    status text NOT NULL CHECK (status IN ('PASS','WARN','FAIL')),
    detail text,
    evidence_rule_code text REFERENCES knowledge.differential_evidence_rule(evidence_rule_code),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (instance_id, check_name, evidence_rule_code)
);
COMMENT ON TABLE knowledge.documentation_validation IS
'Machine-readable validation report for completeness, chronology, contradiction, provenance and certainty safety.';
CREATE INDEX IF NOT EXISTS idx_doc_validation_inst ON knowledge.documentation_validation(instance_id);
CREATE INDEX IF NOT EXISTS idx_doc_validation_status ON knowledge.documentation_validation(status);

-- ============================================================================
-- C. CLINICAL LANGUAGE / SAFETY CONFIGURATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.documentation_language_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL UNIQUE,
    context_code text REFERENCES knowledge.clinical_context(code),
    section_code text REFERENCES knowledge.documentation_section(section_code),
    rule_type text NOT NULL CHECK (rule_type IN (
        'PERSON_REFERENCE','PRONOUN','TENSE','NEGATION','ATTRIBUTION','CHRONOLOGY','CONCISION','CLINICAL_STYLE'
    )),
    instruction text NOT NULL,
    priority integer NOT NULL DEFAULT 1,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.documentation_language_rule IS
'Controlled clinical-language policy. It governs readable professional English without allowing the language layer to add clinical meaning.';
CREATE INDEX IF NOT EXISTS idx_doc_lang_context ON knowledge.documentation_language_rule(context_code);
CREATE INDEX IF NOT EXISTS idx_doc_lang_section ON knowledge.documentation_language_rule(section_code);
DROP TRIGGER IF EXISTS trg_knowledge_documentation_language_rule_updated_at ON knowledge.documentation_language_rule;
CREATE TRIGGER trg_knowledge_documentation_language_rule_updated_at
BEFORE UPDATE ON knowledge.documentation_language_rule
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.documentation_attribution_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_method_code text NOT NULL REFERENCES knowledge.fact_capture_method(method_code),
    attribution_phrase text NOT NULL,
    example_pattern text,
    preserves_uncertainty boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_method_code, attribution_phrase)
);
COMMENT ON TABLE knowledge.documentation_attribution_rule IS
'Clinical attribution policy. Source hierarchy must not disappear during sentence realization.';

CREATE TABLE IF NOT EXISTS knowledge.documentation_fact_state_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    state_code text NOT NULL REFERENCES knowledge.clinical_fact_state(state_code),
    render_mode text NOT NULL CHECK (render_mode IN (
        'ASSERT','NEGATE','ATTRIBUTE_UNKNOWN','ATTRIBUTE_NOT_ASSESSED','ATTRIBUTE_NOT_APPLICABLE','FLAG_CONFLICT'
    )),
    wording_template text NOT NULL,
    allow_default_omission boolean NOT NULL DEFAULT true,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (state_code, render_mode)
);
COMMENT ON TABLE knowledge.documentation_fact_state_rule IS
'Explicit rendering policy for all H8 fact states. UNKNOWN is never rendered as a negative finding.';

-- ============================================================================
-- D. SAFE SEEDS FOR LANGUAGE BEHAVIOUR
-- ============================================================================

INSERT INTO knowledge.documentation_fact_state_rule
    (state_code, render_mode, wording_template, allow_default_omission)
VALUES
    ('PRESENT', 'ASSERT', '{{TERM}} {{VALUE}}', true),
    ('ABSENT', 'NEGATE', 'The patient denies {{TERM}}.', true),
    ('UNKNOWN', 'ATTRIBUTE_UNKNOWN', '{{TERM}} is unknown.', false),
    ('NOT_ASSESSED', 'ATTRIBUTE_NOT_ASSESSED', '{{TERM}} was not assessed.', false),
    ('NOT_APPLICABLE', 'ATTRIBUTE_NOT_APPLICABLE', '{{TERM}} is not applicable.', true),
    ('CONFLICTING', 'FLAG_CONFLICT', 'The available information regarding {{TERM}} is conflicting.', false)
ON CONFLICT (state_code, render_mode)
DO UPDATE SET
    wording_template = EXCLUDED.wording_template,
    allow_default_omission = EXCLUDED.allow_default_omission;

INSERT INTO knowledge.documentation_language_rule
    (rule_code, rule_type, instruction, priority)
VALUES
    ('DLR-CHRONOLOGY-001','CHRONOLOGY',
     'Present clinical events in meaningful temporal order. Prefer explicit onset and sequence over database insertion order.',100),
    ('DLR-ATTRIBUTION-001','ATTRIBUTION',
     'Preserve whether information was patient-reported, caregiver-reported, clinician-observed, device-measured, laboratory-measured, imaging-derived or system-derived.',100),
    ('DLR-NEGATION-001','NEGATION',
     'Document an absence only when the clinical fact state is explicitly ABSENT. Never convert UNKNOWN or NOT_ASSESSED into a negative finding.',100),
    ('DLR-CERTAINTY-001','CLINICAL_STYLE',
     'Never strengthen certainty during wording. Preserve DEFINITE, PROBABLE, POSSIBLE and UNCERTAIN exactly.',100),
    ('DLR-NO-INFERENCE-001','CLINICAL_STYLE',
     'Do not add causal explanations, diagnostic deductions, severity judgments, treatment responses or complications unless represented by supported structured propositions.',100),
    ('DLR-NATURAL-ENGLISH-001','CONCISION',
     'Use concise professional clinical English. Prefer natural complete sentences and familiar clinical terminology over repetitive database labels or telegraphic fragments.',90),
    ('DLR-NO-ROBOTIC-REPETITION-001','CONCISION',
     'Avoid unnecessary repetition of the same subject, diagnosis, date or symptom in consecutive sentences while preserving clarity, attribution and provenance.',80)
ON CONFLICT (rule_code)
DO UPDATE SET
    rule_type = EXCLUDED.rule_type,
    instruction = EXCLUDED.instruction,
    priority = EXCLUDED.priority,
    updated_at = now();

COMMENT ON COLUMN knowledge.documentation_sentence.content IS
'CPU-generated controlled clinical English. UI renders it; UI must not reason, infer, recalculate or upgrade certainty.';
COMMENT ON COLUMN knowledge.documentation_sentence.certainty IS
'Preserved H8 certainty: DEFINITE / PROBABLE / POSSIBLE / UNCERTAIN.';
COMMENT ON COLUMN knowledge.documentation_sentence.event_time IS
'Clinical event time used for chronology; never substitute database insertion order for clinical chronology.';
COMMENT ON COLUMN knowledge.documentation_sentence_fact.fact_state IS
'Explicit H8 fact state. UNKNOWN and NOT_ASSESSED are never equivalent to ABSENT.';
COMMENT ON COLUMN knowledge.documentation_template_element.wording_template IS
'Controlled wording scaffold. It may realize supported data but must never introduce unsupported clinical meaning.';

COMMIT;
