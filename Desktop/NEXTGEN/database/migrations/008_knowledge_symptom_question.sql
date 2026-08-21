-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 008: symptom library + question engine
-- UNIVERSAL CLINICAL KNOWLEDGE SUBSTRATE
-- =============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS knowledge;

-- =============================================================================
-- 3. SYMPTOM LIBRARY
-- =============================================================================
-- knowledge.symptom is created in migration 007. This migration extends it
-- with the symptom-library columns used by the question engine.

ALTER TABLE knowledge.symptom
    ADD COLUMN IF NOT EXISTS symptom_code text,
    ADD COLUMN IF NOT EXISTS canonical_name text,
    ADD COLUMN IF NOT EXISTS definition text,
    ADD COLUMN IF NOT EXISTS is_emergency boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS uq_knowledge_symptom_code
    ON knowledge.symptom(symptom_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_symptom_concept
    ON knowledge.symptom(concept_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_symptom_name
    ON knowledge.symptom(canonical_name);

CREATE INDEX IF NOT EXISTS idx_knowledge_symptom_status
    ON knowledge.symptom(status);

DROP TRIGGER IF EXISTS trg_knowledge_symptom_updated_at
    ON knowledge.symptom;

CREATE TRIGGER trg_knowledge_symptom_updated_at
    BEFORE UPDATE ON knowledge.symptom
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- SYMPTOM SYNONYMS
-- =============================================================================

CREATE TABLE knowledge.symptom_synonym (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    synonym text NOT NULL,
    language_code text NOT NULL DEFAULT 'en',
    is_preferred boolean NOT NULL DEFAULT false,
    UNIQUE (symptom_id, synonym, language_code)
);

CREATE INDEX idx_symptom_synonym_lookup
    ON knowledge.symptom_synonym(lower(synonym));


-- =============================================================================
-- SYMPTOM TRANSLATIONS
-- =============================================================================

CREATE TABLE knowledge.symptom_translation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    language_code text NOT NULL,
    translation text NOT NULL,
    is_preferred boolean NOT NULL DEFAULT false,
    UNIQUE (symptom_id, language_code, translation)
);

CREATE INDEX idx_symptom_translation_language
    ON knowledge.symptom_translation(language_code);


-- =============================================================================
-- SYMPTOM CONTEXT
-- =============================================================================

CREATE TABLE knowledge.symptom_context (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
    context_value_id uuid REFERENCES knowledge.context_value(id),
    relevance numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (relevance >= 0 AND relevance <= 1),
    description text,
    UNIQUE (symptom_id, context_type_code, context_value_id)
);

CREATE INDEX idx_symptom_context_lookup
    ON knowledge.symptom_context(
        symptom_id,
        context_type_code,
        context_value_id
    );


-- =============================================================================
-- SYMPTOM BODY SYSTEMS
-- =============================================================================

CREATE TABLE knowledge.symptom_system (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    body_system_code text NOT NULL REFERENCES knowledge.body_system(code),
    relevance numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (relevance >= 0 AND relevance <= 1),
    UNIQUE (symptom_id, body_system_code)
);

CREATE INDEX idx_symptom_system_system
    ON knowledge.symptom_system(body_system_code);


-- =============================================================================
-- SYMPTOM SPECIALTIES
-- =============================================================================

CREATE TABLE knowledge.symptom_specialty (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    specialty_code text NOT NULL REFERENCES organization.specialty(code),
    relevance numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (relevance >= 0 AND relevance <= 1),
    UNIQUE (symptom_id, specialty_code)
);

CREATE INDEX idx_symptom_specialty_specialty
    ON knowledge.symptom_specialty(specialty_code);


-- =============================================================================
-- SYMPTOM RELATIONSHIPS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_relationship CASCADE;
CREATE TABLE knowledge.symptom_relationship (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    related_symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    relationship_type text NOT NULL,
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    polarity text NOT NULL DEFAULT 'positive'
        CHECK (polarity IN ('positive','negative')),
    description text,
    CHECK (symptom_id <> related_symptom_id),
    UNIQUE (symptom_id, related_symptom_id, relationship_type)
);

CREATE INDEX idx_symptom_relationship_source
    ON knowledge.symptom_relationship(symptom_id);

CREATE INDEX idx_symptom_relationship_target
    ON knowledge.symptom_relationship(related_symptom_id);


-- =============================================================================
-- SYMPTOM RED FLAGS
-- =============================================================================

CREATE TABLE knowledge.symptom_red_flag (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    red_flag_code text NOT NULL,
    description text NOT NULL,
    urgency text NOT NULL DEFAULT 'urgent'
        CHECK (urgency IN ('emergency','urgent','routine')),
    evidence text,
    action_code text,
    UNIQUE (symptom_id, red_flag_code)
);

CREATE INDEX idx_symptom_red_flag_urgency
    ON knowledge.symptom_red_flag(urgency);


-- =============================================================================
-- SYMPTOM DOCUMENTATION
-- =============================================================================

CREATE TABLE knowledge.symptom_documentation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    documentation_phrase text NOT NULL,
    language_code text NOT NULL DEFAULT 'en',
    context_code text,
    is_preferred boolean NOT NULL DEFAULT false,
    UNIQUE (symptom_id, documentation_phrase, language_code)
);


-- =============================================================================
-- SYMPTOM CHARACTERISTICS
-- Universal SOCRATES / OPQRST / symptom-specific dimensions
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_dimension CASCADE;
CREATE TABLE knowledge.symptom_dimension (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    dimension_code text NOT NULL,
    label text NOT NULL,
    description text,
    response_type text NOT NULL
        CHECK (
            response_type IN (
                'single_choice',
                'multiple_choice',
                'boolean',
                'numeric',
                'numeric_range',
                'text',
                'date',
                'datetime'
            )
        ),
    is_core boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    UNIQUE (symptom_id, dimension_code)
);

CREATE TABLE knowledge.symptom_dimension_option (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dimension_id uuid NOT NULL REFERENCES knowledge.symptom_dimension(id) ON DELETE CASCADE,
    option_code text NOT NULL,
    label text NOT NULL,
    value_text text,
    sort_order integer NOT NULL DEFAULT 0,
    UNIQUE (dimension_id, option_code)
);

CREATE INDEX idx_symptom_dimension_symptom
    ON knowledge.symptom_dimension(symptom_id);


-- =============================================================================
-- 4. QUESTION ENGINE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question CASCADE;
CREATE TABLE knowledge.question (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_code text NOT NULL UNIQUE,
    concept_id uuid REFERENCES knowledge.concept(id),
    question_type text NOT NULL DEFAULT 'clinical'
        CHECK (
            question_type IN (
                'clinical',
                'risk',
                'screening',
                'follow_up',
                'safety',
                'severity',
                'differential',
                'context',
                'documentation'
            )
        ),
    text text NOT NULL,
    response_type text NOT NULL DEFAULT 'single_choice'
        CHECK (
            response_type IN (
                'single_choice',
                'multiple_choice',
                'boolean',
                'numeric',
                'numeric_range',
                'text',
                'date',
                'datetime'
            )
        ),
    priority integer NOT NULL DEFAULT 50,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_question_concept
    ON knowledge.question(concept_id);

CREATE INDEX idx_question_type
    ON knowledge.question(question_type);

CREATE TRIGGER trg_knowledge_question_updated_at
    BEFORE UPDATE ON knowledge.question
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- QUESTION DIMENSION MAPPING
-- =============================================================================

CREATE TABLE knowledge.question_dimension (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    symptom_id uuid REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    dimension_code text NOT NULL,
    is_core boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    UNIQUE (question_id, symptom_id, dimension_code)
);


-- =============================================================================
-- ANSWER OPTIONS
-- =============================================================================

CREATE TABLE knowledge.answer_option (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    answer_code text NOT NULL,
    label text NOT NULL,
    value_text text,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    UNIQUE (question_id, answer_code)
);

CREATE INDEX idx_answer_option_question
    ON knowledge.answer_option(question_id);


-- =============================================================================
-- ANSWER â†’ CLINICAL FACT
-- =============================================================================

CREATE TABLE knowledge.fact_mapping (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    answer_option_id uuid NOT NULL REFERENCES knowledge.answer_option(id) ON DELETE CASCADE,
    fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
    value text NOT NULL,
    polarity text NOT NULL DEFAULT 'positive'
        CHECK (polarity IN ('positive','negative','unknown')),
    confidence numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (confidence >= 0 AND confidence <= 1),
    is_active boolean NOT NULL DEFAULT true,
    UNIQUE (
        answer_option_id,
        fact_definition_code,
        value
    )
);

CREATE INDEX idx_fact_mapping_fact
    ON knowledge.fact_mapping(fact_definition_code);


-- =============================================================================
-- QUESTION CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_context CASCADE;
CREATE TABLE knowledge.question_context (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
    context_value_id uuid REFERENCES knowledge.context_value(id),
    applicability text NOT NULL DEFAULT 'applies'
        CHECK (applicability IN ('applies','excludes')),
    priority integer NOT NULL DEFAULT 0,
    UNIQUE (
        question_id,
        context_type_code,
        context_value_id
    )
);

CREATE INDEX idx_question_context_lookup
    ON knowledge.question_context(
        context_type_code,
        context_value_id
    );


-- =============================================================================
-- QUESTION TRIGGERS
-- =============================================================================

CREATE TABLE knowledge.question_trigger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    trigger_type text NOT NULL
        CHECK (
            trigger_type IN (
                'symptom',
                'phenotype',
                'risk_factor',
                'mechanism',
                'condition',
                'complication',
                'context',
                'fact',
                'investigation',
                'medication'
            )
        ),
    trigger_concept_id uuid REFERENCES knowledge.concept(id),
    trigger_code text NOT NULL,
    condition jsonb,
    priority integer NOT NULL DEFAULT 0,
    UNIQUE (
        question_id,
        trigger_type,
        trigger_code
    )
);

CREATE INDEX idx_question_trigger_lookup
    ON knowledge.question_trigger(trigger_type, trigger_code);


-- =============================================================================
-- QUESTION REQUIREMENTS
-- =============================================================================

CREATE TABLE knowledge.question_requirement (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    requirement_level text NOT NULL
        CHECK (
            requirement_level IN (
                'mandatory',
                'conditionally_required',
                'optional',
                'informational'
            )
        ),
    condition jsonb,
    priority integer NOT NULL DEFAULT 0
);

CREATE INDEX idx_question_requirement_question
    ON knowledge.question_requirement(question_id);


-- =============================================================================
-- QUESTION DEPENDENCIES
-- =============================================================================

CREATE TABLE knowledge.question_dependency (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    depends_on_question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    operator text NOT NULL
        CHECK (
            operator IN (
                'answered',
                'not_answered',
                'equals',
                'not_equals',
                'contains',
                'greater_than',
                'less_than'
            )
        ),
    expected_value text,
    priority integer NOT NULL DEFAULT 0,
    CHECK (question_id <> depends_on_question_id)
);

CREATE INDEX idx_question_dependency_question
    ON knowledge.question_dependency(question_id);


-- =============================================================================
-- QUESTION EXCLUSION / DE-DUPLICATION
-- =============================================================================

CREATE TABLE knowledge.question_exclusion (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    excludes_question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    reason text,
    UNIQUE (question_id, excludes_question_id),
    CHECK (question_id <> excludes_question_id)
);

CREATE INDEX idx_question_exclusion_question
    ON knowledge.question_exclusion(question_id);


-- =============================================================================
-- QUESTION GROUPS
-- =============================================================================

CREATE TABLE knowledge.question_group (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    group_type text NOT NULL
        CHECK (
            group_type IN (
                'general',
                'symptom_characterisation',
                'red_flag',
                'risk_factor',
                'differential',
                'severity',
                'complication',
                'past_history',
                'medication',
                'social',
                'family',
                'obstetric',
                'paediatric',
                'review_of_systems',
                'safety'
            )
        ),
    priority integer NOT NULL DEFAULT 50,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE knowledge.question_group_member (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL REFERENCES knowledge.question_group(id) ON DELETE CASCADE,
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    sort_order integer NOT NULL DEFAULT 0,
    required boolean NOT NULL DEFAULT false,
    UNIQUE (group_id, question_id)
);

CREATE INDEX idx_question_group_member_group
    ON knowledge.question_group_member(group_id);


-- =============================================================================
-- HPI OBJECTIVES
-- =============================================================================

CREATE TABLE knowledge.hpi_objective (
    code text PRIMARY KEY,
    name text NOT NULL,
    description text NOT NULL,
    sort_order integer NOT NULL DEFAULT 0
);

CREATE TABLE knowledge.question_hpi_objective (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    objective_code text NOT NULL REFERENCES knowledge.hpi_objective(code),
    weight numeric(8,4) NOT NULL DEFAULT 1.0,
    UNIQUE (question_id, objective_code)
);


-- =============================================================================
-- CLINICAL COMPLETENESS RULES
-- =============================================================================

CREATE TABLE knowledge.completeness_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    context jsonb,
    required_questions jsonb,
    scoring_method text NOT NULL DEFAULT 'weighted'
        CHECK (
            scoring_method IN (
                'binary',
                'weighted',
                'percentage',
                'threshold'
            )
        ),
    threshold numeric(8,4),
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE knowledge.completeness_result_definition (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id uuid NOT NULL REFERENCES knowledge.completeness_rule(id) ON DELETE CASCADE,
    result_code text NOT NULL,
    label text NOT NULL,
    min_score numeric(8,4),
    max_score numeric(8,4),
    action_code text,
    UNIQUE (rule_id, result_code)
);


-- =============================================================================
-- KNOWLEDGE SOURCES / BOOKS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.source CASCADE;
CREATE TABLE knowledge.source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_code text NOT NULL UNIQUE,
    title text NOT NULL,
    source_type text NOT NULL
        CHECK (
            source_type IN (
                'textbook',
                'guideline',
                'protocol',
                'standard',
                'paper',
                'monograph',
                'institutional',
                'regulatory',
                'local_protocol'
            )
        ),
    edition text,
    publisher text,
    authors text,
    publication_year integer,
    isbn text,
    url text,
    version text,
    jurisdiction text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','superseded','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_knowledge_source_type
    ON knowledge.source(source_type);

CREATE TRIGGER trg_knowledge_source_updated_at
    BEFORE UPDATE ON knowledge.source
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- SOURCE SECTIONS / CHAPTERS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.source_section CASCADE;
CREATE TABLE knowledge.source_section (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id uuid NOT NULL REFERENCES knowledge.source(id) ON DELETE CASCADE,
    parent_section_id uuid REFERENCES knowledge.source_section(id) ON DELETE CASCADE,
    section_code text,
    chapter_number text,
    title text NOT NULL,
    sort_order integer NOT NULL DEFAULT 0,
    page_start integer,
    page_end integer,
    content_hash text,
    UNIQUE (source_id, section_code)
);

CREATE INDEX idx_source_section_source
    ON knowledge.source_section(source_id);


-- =============================================================================
-- KNOWLEDGE ASSERTIONS
-- Facts extracted from authoritative sources
-- =============================================================================

CREATE TABLE knowledge.assertion (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assertion_code text NOT NULL UNIQUE,
    subject_concept_id uuid REFERENCES knowledge.concept(id),
    predicate text NOT NULL,
    object_concept_id uuid REFERENCES knowledge.concept(id),
    object_value jsonb,
    assertion_type text NOT NULL DEFAULT 'clinical'
        CHECK (
            assertion_type IN (
                'clinical',
                'epidemiological',
                'diagnostic',
                'therapeutic',
                'prognostic',
                'preventive',
                'safety',
                'documentation',
                'workflow'
            )
        ),
    certainty text NOT NULL DEFAULT 'established'
        CHECK (
            certainty IN (
                'established',
                'probable',
                'conditional',
                'uncertain'
            )
        ),
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','superseded','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_assertion_subject
    ON knowledge.assertion(subject_concept_id);

CREATE INDEX idx_assertion_object
    ON knowledge.assertion(object_concept_id);

CREATE INDEX idx_assertion_predicate
    ON knowledge.assertion(predicate);

CREATE TRIGGER trg_knowledge_assertion_updated_at
    BEFORE UPDATE ON knowledge.assertion
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- ASSERTION SOURCES
-- =============================================================================

CREATE TABLE knowledge.assertion_source (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assertion_id uuid NOT NULL REFERENCES knowledge.assertion(id) ON DELETE CASCADE,
    source_id uuid NOT NULL REFERENCES knowledge.source(id),
    source_section_id uuid REFERENCES knowledge.source_section(id),
    citation text,
    evidence_level text,
    evidence_grade text,
    notes text,
    UNIQUE (assertion_id, source_id, source_section_id)
);

CREATE INDEX idx_assertion_source_assertion
    ON knowledge.assertion_source(assertion_id);


-- =============================================================================
-- KNOWLEDGE VERSION
-- =============================================================================

CREATE TABLE knowledge.knowledge_version (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    status text NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft','validated','active','superseded','retired')),
    effective_from timestamptz,
    effective_to timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid REFERENCES identity.user_account(id)
);

CREATE TABLE knowledge.knowledge_version_item (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_version_id uuid NOT NULL REFERENCES knowledge.knowledge_version(id) ON DELETE CASCADE,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    operation text NOT NULL
        CHECK (operation IN ('added','modified','deprecated','removed')),
    UNIQUE (knowledge_version_id, entity_type, entity_id)
);

CREATE INDEX idx_knowledge_version_item_version
    ON knowledge.knowledge_version_item(knowledge_version_id);


-- =============================================================================
-- UNIVERSAL KNOWLEDGE RELATIONSHIP
-- =============================================================================

CREATE TABLE knowledge.relationship (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type text NOT NULL,
    source_id uuid NOT NULL,
    relationship_type text NOT NULL,
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    polarity text NOT NULL DEFAULT 'positive'
        CHECK (polarity IN ('positive','negative','neutral')),
    context jsonb,
    evidence_level text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (
        source_type,
        source_id,
        relationship_type,
        target_type,
        target_id
    )
);

CREATE INDEX idx_knowledge_relationship_source
    ON knowledge.relationship(source_type, source_id);

CREATE INDEX idx_knowledge_relationship_target
    ON knowledge.relationship(target_type, target_id);

CREATE INDEX idx_knowledge_relationship_type
    ON knowledge.relationship(relationship_type);


-- =============================================================================
-- KNOWLEDGE RULES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.rule CASCADE;
CREATE TABLE knowledge.rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code text NOT NULL UNIQUE,
    name text NOT NULL,
    rule_type text NOT NULL
        CHECK (
            rule_type IN (
                'diagnostic',
                'differential',
                'red_flag',
                'investigation',
                'treatment',
                'medication',
                'referral',
                'screening',
                'prevention',
                'severity',
                'documentation',
                'workflow',
                'safety',
                'question_selection'
            )
        ),
    description text,
    condition jsonb NOT NULL,
    action jsonb NOT NULL,
    priority integer NOT NULL DEFAULT 50,
    confidence numeric(5,4)
        CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
    source_id uuid REFERENCES knowledge.source(id),
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated','draft')),
    version text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_knowledge_rule_type
    ON knowledge.rule(rule_type);

CREATE INDEX idx_knowledge_rule_status
    ON knowledge.rule(status);

CREATE TRIGGER trg_knowledge_rule_updated_at
    BEFORE UPDATE ON knowledge.rule
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- RULE CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.rule_context CASCADE;
CREATE TABLE knowledge.rule_context (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id uuid NOT NULL REFERENCES knowledge.rule(id) ON DELETE CASCADE,
    context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
    context_value_id uuid REFERENCES knowledge.context_value(id),
    applicability text NOT NULL DEFAULT 'applies'
        CHECK (applicability IN ('applies','excludes')),
    priority integer NOT NULL DEFAULT 0,
    UNIQUE (rule_id, context_type_code, context_value_id)
);


-- =============================================================================
-- PHENOTYPE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.phenotype CASCADE;
CREATE TABLE knowledge.phenotype (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    phenotype_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_phenotype_concept
    ON knowledge.phenotype(concept_id);

CREATE TRIGGER trg_knowledge_phenotype_updated_at
    BEFORE UPDATE ON knowledge.phenotype
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- PHENOTYPE COMPONENTS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.phenotype_component CASCADE;
CREATE TABLE knowledge.phenotype_component (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    phenotype_id uuid NOT NULL REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    relationship text NOT NULL
        CHECK (
            relationship IN (
                'required',
                'supporting',
                'excluding',
                'optional'
            )
        ),
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    condition jsonb
);

CREATE INDEX idx_phenotype_component_phenotype
    ON knowledge.phenotype_component(phenotype_id);


-- =============================================================================
-- MECHANISM
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.mechanism CASCADE;
CREATE TABLE knowledge.mechanism (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    mechanism_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.mechanism_relationship CASCADE;
CREATE TABLE knowledge.mechanism_relationship (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    mechanism_id uuid NOT NULL REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,
    related_concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    relationship_type text NOT NULL,
    direction text NOT NULL DEFAULT 'forward'
        CHECK (direction IN ('forward','reverse','bidirectional')),
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    UNIQUE (
        mechanism_id,
        related_concept_id,
        relationship_type
    )
);


-- =============================================================================
-- CONDITION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition CASCADE;
CREATE TABLE knowledge.condition (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    condition_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    condition_class text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_condition_concept
    ON knowledge.condition(concept_id);

CREATE TRIGGER trg_knowledge_condition_updated_at
    BEFORE UPDATE ON knowledge.condition
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- CONDITION PHENOTYPES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_phenotype CASCADE;
CREATE TABLE knowledge.condition_phenotype (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    phenotype_id uuid NOT NULL REFERENCES knowledge.phenotype(id),
    relationship text NOT NULL DEFAULT 'associated'
        CHECK (
            relationship IN (
                'required',
                'typical',
                'associated',
                'atypical',
                'excluding'
            )
        ),
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    UNIQUE (condition_id, phenotype_id)
);


-- =============================================================================
-- CONDITION CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_context CASCADE;
CREATE TABLE knowledge.condition_context (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    context_type_code text NOT NULL REFERENCES knowledge.context_type(code),
    context_value_id uuid REFERENCES knowledge.context_value(id),
    relevance numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (relevance >= 0 AND relevance <= 1),
    notes text,
    UNIQUE (
        condition_id,
        context_type_code,
        context_value_id
    )
);


-- =============================================================================
-- CONDITION DIFFERENTIAL RELATIONSHIPS
-- =============================================================================

CREATE TABLE knowledge.condition_relationship (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    related_condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    relationship_type text NOT NULL
        CHECK (
            relationship_type IN (
                'differential',
                'comorbidity',
                'cause',
                'complication',
                'precursor',
                'mimic',
                'associated',
                'alternative'
            )
        ),
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    context jsonb,
    CHECK (condition_id <> related_condition_id),
    UNIQUE (
        condition_id,
        related_condition_id,
        relationship_type
    )
);


-- =============================================================================
-- INVESTIGATION KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.investigation CASCADE;
CREATE TABLE knowledge.investigation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    investigation_code text NOT NULL UNIQUE,
    name text NOT NULL,
    investigation_type text,
    description text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.investigation_rule CASCADE;
CREATE TABLE knowledge.investigation_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_id uuid NOT NULL REFERENCES knowledge.investigation(id) ON DELETE CASCADE,
    condition_id uuid REFERENCES knowledge.condition(id),
    indication jsonb,
    contraindication jsonb,
    expected_finding jsonb,
    interpretation jsonb,
    urgency text,
    source_id uuid REFERENCES knowledge.source(id),
    UNIQUE (
        investigation_id,
        condition_id,
        source_id
    )
);


-- =============================================================================
-- MEDICATION KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication CASCADE;
CREATE TABLE knowledge.medication (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    medication_code text NOT NULL UNIQUE,
    generic_name text NOT NULL,
    route_options jsonb,
    formulation_options jsonb,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

CREATE TABLE knowledge.medication_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_id uuid NOT NULL REFERENCES knowledge.medication(id) ON DELETE CASCADE,
    condition_id uuid REFERENCES knowledge.condition(id),
    indication jsonb,
    dose_rule jsonb,
    contraindication jsonb,
    interaction_rule jsonb,
    monitoring_rule jsonb,
    adjustment_rule jsonb,
    source_id uuid REFERENCES knowledge.source(id)
);


-- =============================================================================
-- COMPLICATION KNOWLEDGE
-- =============================================================================

CREATE TABLE knowledge.complication (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    complication_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    severity text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_complication CASCADE;
CREATE TABLE knowledge.condition_complication (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    complication_id uuid NOT NULL REFERENCES knowledge.complication(id),
    probability numeric(5,4),
    timing jsonb,
    risk_factors jsonb,
    detection_rule jsonb,
    prevention_rule jsonb,
    management_rule jsonb,
    source_id uuid REFERENCES knowledge.source(id),
    UNIQUE (condition_id, complication_id)
);


-- =============================================================================
-- RISK FACTOR KNOWLEDGE
-- =============================================================================

CREATE TABLE knowledge.risk_factor (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id uuid NOT NULL REFERENCES knowledge.concept(id),
    risk_factor_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    modifiable boolean,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated'))
);

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_risk_factor CASCADE;
CREATE TABLE knowledge.condition_risk_factor (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    risk_factor_id uuid NOT NULL REFERENCES knowledge.risk_factor(id),
    effect text NOT NULL DEFAULT 'increases_risk'
        CHECK (
            effect IN (
                'increases_risk',
                'decreases_risk',
                'protective',
                'severity_modifier'
            )
        ),
    weight numeric(5,4) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),
    context jsonb,
    source_id uuid REFERENCES knowledge.source(id),
    UNIQUE (condition_id, risk_factor_id, effect)
);


-- =============================================================================
-- SAFETY KNOWLEDGE
-- =============================================================================

CREATE TABLE knowledge.safety_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    safety_code text NOT NULL UNIQUE,
    name text NOT NULL,
    severity text NOT NULL
        CHECK (severity IN ('information','caution','urgent','emergency','contraindicated')),
    trigger jsonb NOT NULL,
    action jsonb NOT NULL,
    explanation text,
    source_id uuid REFERENCES knowledge.source(id),
    is_active boolean NOT NULL DEFAULT true
);


-- =============================================================================
-- KNOWLEDGE VALIDATION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.validation_rule CASCADE;
CREATE TABLE knowledge.validation_rule (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    validation_code text NOT NULL UNIQUE,
    entity_type text NOT NULL,
    name text NOT NULL,
    description text,
    condition jsonb NOT NULL,
    severity text NOT NULL DEFAULT 'error'
        CHECK (severity IN ('warning','error','critical')),
    is_active boolean NOT NULL DEFAULT true
);

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.validation_run CASCADE;
CREATE TABLE knowledge.validation_run (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    knowledge_version_id uuid REFERENCES knowledge.knowledge_version(id),
    started_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz,
    status text NOT NULL DEFAULT 'running'
        CHECK (status IN ('running','passed','failed')),
    summary jsonb
);

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.validation_result CASCADE;
CREATE TABLE knowledge.validation_result (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    validation_run_id uuid NOT NULL REFERENCES knowledge.validation_run(id) ON DELETE CASCADE,
    validation_rule_id uuid NOT NULL REFERENCES knowledge.validation_rule(id),
    entity_type text,
    entity_id uuid,
    status text NOT NULL
        CHECK (status IN ('passed','warning','failed')),
    message text,
    detail jsonb
);

CREATE INDEX idx_validation_result_run
    ON knowledge.validation_result(validation_run_id);


-- =============================================================================
-- KNOWLEDGE CHANGE LOG
-- =============================================================================

CREATE TABLE knowledge.change_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    change_type text NOT NULL
        CHECK (
            change_type IN (
                'create',
                'update',
                'deprecate',
                'restore',
                'supersede',
                'delete'
            )
        ),
    changed_by uuid REFERENCES identity.user_account(id),
    changed_at timestamptz NOT NULL DEFAULT now(),
    before jsonb,
    after jsonb,
    reason text
);

CREATE INDEX idx_knowledge_change_log_entity
    ON knowledge.change_log(entity_type, entity_id);

CREATE INDEX idx_knowledge_change_log_time
    ON knowledge.change_log(changed_at);


-- =============================================================================
-- KNOWLEDGE REGISTRY
-- =============================================================================

CREATE TABLE knowledge.registry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    registry_code text NOT NULL UNIQUE,
    name text NOT NULL,
    entity_type text NOT NULL,
    description text,
    source_of_truth text,
    version text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- INITIAL UNIVERSAL CONTEXT TYPES
-- =============================================================================

INSERT INTO knowledge.context_type (code, label, description)
VALUES
    ('AGE', 'Age', 'Patient age/life-stage context'),
    ('SEX', 'Sex', 'Sex context'),
    ('PREGNANCY', 'Pregnancy', 'Pregnancy state'),
    ('GESTATIONAL_AGE', 'Gestational age', 'Gestational age context'),
    ('BODY_SYSTEM', 'Body system', 'Relevant physiological system'),
    ('SPECIALTY', 'Specialty', 'Clinical specialty'),
    ('DEPARTMENT', 'Department', 'Clinical department'),
    ('CARE_SETTING', 'Care setting', 'Location/setting of care'),
    ('ACUITY', 'Acuity', 'Clinical acuity'),
    ('COMORBIDITY', 'Comorbidity', 'Relevant coexisting condition'),
    ('IMMUNOCOMPROMISED_STATUS', 'Immunocompromised status', 'Immune status'),
    ('GEOGRAPHY', 'Geography', 'Geographic context'),
    ('SEASON', 'Season', 'Seasonal context'),
    ('PRESENTATION', 'Presentation', 'Mode of clinical presentation'),
    ('PREVIOUS_HEALTH_STATE', 'Previous health state', 'Baseline health context')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- INITIAL BODY SYSTEM VOCABULARY
-- =============================================================================

INSERT INTO knowledge.body_system (code, label)
VALUES
    ('CARDIOVASCULAR', 'Cardiovascular'),
    ('RESPIRATORY', 'Respiratory'),
    ('GASTROINTESTINAL', 'Gastrointestinal'),
    ('HEPATOBILIARY', 'Hepatobiliary'),
    ('RENAL', 'Renal'),
    ('UROLOGICAL', 'Urological'),
    ('REPRODUCTIVE', 'Reproductive'),
    ('OBSTETRIC', 'Obstetric'),
    ('ENDOCRINE', 'Endocrine'),
    ('METABOLIC', 'Metabolic'),
    ('NEUROLOGICAL', 'Neurological'),
    ('MUSCULOSKELETAL', 'Musculoskeletal'),
    ('DERMATOLOGICAL', 'Dermatological'),
    ('HAEMATOLOGICAL', 'Haematological'),
    ('IMMUNOLOGICAL', 'Immunological'),
    ('INFECTIOUS', 'Infectious disease'),
    ('OPHTHALMOLOGICAL', 'Ophthalmological'),
    ('ENT', 'Ear, nose and throat'),
    ('PSYCHIATRIC', 'Psychiatric'),
    ('ONCOLOGICAL', 'Oncological'),
    ('GENETIC', 'Genetic'),
    ('PAEDIATRIC', 'Paediatric'),
    ('GERIATRIC', 'Geriatric'),
    ('SYSTEMIC', 'Systemic')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- INITIAL HPI OBJECTIVES
-- =============================================================================

INSERT INTO knowledge.hpi_objective
    (code, name, description, sort_order)
VALUES
    (
        'CHARACTERISE_PRESENTING_PROBLEM',
        'Characterise the presenting problem',
        'Explore the chief complaint chronologically and systematically, including appropriate symptom characteristics.',
        10
    ),
    (
        'ESTABLISH_CLINICAL_DIFFERENTIAL',
        'Establish the clinical differential',
        'Acquire positive and negative clinical facts relevant to possible diagnoses and important differentials.',
        20
    ),
    (
        'IDENTIFY_AETIOLOGY_RISK',
        'Identify aetiology and risk factors',
        'Identify relevant exposures, precipitating factors, predispositions and risk factors.',
        30
    ),
    (
        'IDENTIFY_COMPLICATIONS',
        'Identify complications',
        'Search for clinically important complications and deterioration.',
        40
    ),
    (
        'ASSESS_HEALTH_SEEKING',
        'Assess previous health seeking and management',
        'Determine what has happened previously, care already sought, investigations performed and treatments attempted.',
        50
    ),
    (
        'ASSESS_PATIENT_IMPACT',
        'Assess impact on the patient',
        'Establish effects on function, activities, work, school, feeding, sleep and other relevant affairs.',
        60
    )
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- UNIVERSAL SYMPTOM DIMENSIONS
-- =============================================================================

CREATE TABLE knowledge.dimension (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dimension_code text NOT NULL UNIQUE,
    name text NOT NULL,
    description text,
    response_type text NOT NULL
        CHECK (
            response_type IN (
                'single_choice',
                'multiple_choice',
                'boolean',
                'numeric',
                'numeric_range',
                'text',
                'date',
                'datetime'
            )
        ),
    universal boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0
);

INSERT INTO knowledge.dimension
    (dimension_code, name, response_type, sort_order)
VALUES
    ('ONSET', 'Onset', 'single_choice', 10),
    ('TIME_COURSE', 'Time course', 'single_choice', 20),
    ('DURATION', 'Duration', 'numeric', 30),
    ('FREQUENCY', 'Frequency', 'numeric', 40),
    ('SITE', 'Site', 'text', 50),
    ('RADIATION', 'Radiation', 'text', 60),
    ('CHARACTER', 'Character', 'single_choice', 70),
    ('SEVERITY', 'Severity', 'numeric', 80),
    ('TIMING', 'Timing', 'single_choice', 90),
    ('AGGRAVATING_FACTORS', 'Aggravating factors', 'multiple_choice', 100),
    ('RELIEVING_FACTORS', 'Relieving factors', 'multiple_choice', 110),
    ('ASSOCIATED_SYMPTOMS', 'Associated symptoms', 'multiple_choice', 120),
    ('PROGRESSION', 'Progression', 'single_choice', 130),
    ('PREVIOUS_EPISODES', 'Previous episodes', 'boolean', 140),
    ('TREATMENT_TRIED', 'Treatment tried', 'text', 150),
    ('FUNCTIONAL_IMPACT', 'Functional impact', 'multiple_choice', 160),
    ('PATIENT_INTERPRETATION', 'Patient interpretation', 'text', 170)
ON CONFLICT (dimension_code) DO NOTHING;


COMMIT;
