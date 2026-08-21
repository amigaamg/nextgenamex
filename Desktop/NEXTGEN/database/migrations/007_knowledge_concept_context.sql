-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 007: knowledge substrate (concept + context)
-- =============================================================================
-- Phase 1 gave the database memory. Phase 2 gives it medical meaning.
-- Architecture rule: universal primitives and relationships built ONCE, then
-- composed into diseases, departments, ages, services and protocols.
-- There is NO pneumonia engine, NO diabetes engine â€” only knowledge loaded into
-- a universal machine.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;

COMMENT ON SCHEMA knowledge IS
'Universal clinical knowledge: concepts, contexts, symptoms, questions, rules, phenotypes, mechanisms, conditions.';


-- =============================================================================
-- 1. UNIVERSAL CONCEPT
-- =============================================================================

CREATE TABLE knowledge.concept (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_code      text NOT NULL UNIQUE,
    concept_type      text NOT NULL,
    canonical_name    text NOT NULL,
    display_name      text,
    description       text,
    status            text NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','deprecated')),
    version           text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),

    CHECK (length(trim(concept_code)) > 0),
    CHECK (length(trim(canonical_name)) > 0)
);

COMMENT ON TABLE knowledge.concept IS
'Universal atomic medical vocabulary. Every other knowledge object references it.';

CREATE INDEX idx_knowledge_concept_type
    ON knowledge.concept(concept_type);

CREATE INDEX idx_knowledge_concept_name
    ON knowledge.concept(canonical_name);

CREATE TRIGGER trg_knowledge_concept_updated_at
    BEFORE UPDATE ON knowledge.concept
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 2. UNIVERSAL CONTEXT
-- =============================================================================

CREATE TABLE knowledge.context_type (
    code              text PRIMARY KEY,
    label             text NOT NULL,
    description       text
);

COMMENT ON TABLE knowledge.context_type IS
'A dimension of clinical context.';


CREATE TABLE knowledge.context_value (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    context_type_code text NOT NULL
                      REFERENCES knowledge.context_type(code)
                      ON DELETE CASCADE,
    value             text NOT NULL,
    label             text,
    sort_order        integer NOT NULL DEFAULT 0,
    UNIQUE (context_type_code, value)
);

COMMENT ON TABLE knowledge.context_value IS
'Allowed values within a context type.';

CREATE INDEX idx_context_value_type
    ON knowledge.context_value(context_type_code);


CREATE TABLE knowledge.body_system (
    code              text PRIMARY KEY,
    label             text NOT NULL,
    description       text
);

COMMENT ON TABLE knowledge.body_system IS
'Body systems used to attach symptoms, findings and conditions to systems.';


CREATE TABLE knowledge.context_relationship (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    context_type_code text NOT NULL
                      REFERENCES knowledge.context_type(code)
                      ON DELETE CASCADE,
    source_value_id   uuid NOT NULL
                      REFERENCES knowledge.context_value(id)
                      ON DELETE CASCADE,
    target_value_id   uuid NOT NULL
                      REFERENCES knowledge.context_value(id)
                      ON DELETE CASCADE,
    relationship      text NOT NULL,
    description       text,
    UNIQUE (
        context_type_code,
        source_value_id,
        target_value_id,
        relationship
    )
);

COMMENT ON TABLE knowledge.context_relationship IS
'Relationships between context values.';


CREATE INDEX idx_context_relationship_source
    ON knowledge.context_relationship(source_value_id);

CREATE INDEX idx_context_relationship_target
    ON knowledge.context_relationship(target_value_id);


-- =============================================================================
-- 3. CONCEPT RELATIONSHIPS
-- =============================================================================

CREATE TABLE knowledge.concept_relationship_type (
    code              text PRIMARY KEY,
    label             text NOT NULL,
    description       text,
    is_directional    boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.concept_relationship_type IS
'Controlled vocabulary for relationships between clinical concepts.';


CREATE TABLE knowledge.concept_relationship (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_concept_id     uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    relationship_type_code text NOT NULL
                          REFERENCES knowledge.concept_relationship_type(code),
    target_concept_id     uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    strength              numeric,
    certainty             text,
    context               jsonb,
    description           text,
    status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','deprecated')),
    created_at            timestamptz NOT NULL DEFAULT now(),

    CHECK (source_concept_id <> target_concept_id),
    CHECK (
        strength IS NULL
        OR strength >= 0
    ),
    UNIQUE (
        source_concept_id,
        relationship_type_code,
        target_concept_id
    )
);

COMMENT ON TABLE knowledge.concept_relationship IS
'Universal semantic relationships between concepts.';

CREATE INDEX idx_concept_relationship_source
    ON knowledge.concept_relationship(source_concept_id);

CREATE INDEX idx_concept_relationship_target
    ON knowledge.concept_relationship(target_concept_id);

CREATE INDEX idx_concept_relationship_type
    ON knowledge.concept_relationship(relationship_type_code);


-- =============================================================================
-- 4. CONCEPT CONTEXT
-- =============================================================================

CREATE TABLE knowledge.concept_context (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id        uuid NOT NULL
                      REFERENCES knowledge.concept(id)
                      ON DELETE CASCADE,
    context_type_code text NOT NULL
                      REFERENCES knowledge.context_type(code)
                      ON DELETE CASCADE,
    context_value_id  uuid NOT NULL
                      REFERENCES knowledge.context_value(id)
                      ON DELETE CASCADE,
    relationship      text NOT NULL DEFAULT 'applicable',
    weight            numeric,
    notes             text,
    UNIQUE (
        concept_id,
        context_type_code,
        context_value_id,
        relationship
    )
);

COMMENT ON TABLE knowledge.concept_context IS
'Associates concepts with the contexts in which they apply, change meaning, or change probability.';

CREATE INDEX idx_concept_context_concept
    ON knowledge.concept_context(concept_id);

CREATE INDEX idx_concept_context_value
    ON knowledge.concept_context(context_value_id);


-- =============================================================================
-- 5. SYMPTOM
-- =============================================================================

CREATE TABLE knowledge.symptom (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL UNIQUE
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    symptom_class         text,
    onset_model           text,
    laterality_supported  boolean NOT NULL DEFAULT false,
    severity_supported    boolean NOT NULL DEFAULT true,
    duration_supported    boolean NOT NULL DEFAULT true,
    frequency_supported   boolean NOT NULL DEFAULT true,
    timing_supported      boolean NOT NULL DEFAULT true,
    trigger_supported     boolean NOT NULL DEFAULT true,
    relieving_supported   boolean NOT NULL DEFAULT true,
    associated_supported  boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.symptom IS
'Clinical symptom metadata attached to the universal concept vocabulary.';


CREATE TABLE knowledge.symptom_attribute (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id        uuid NOT NULL
                      REFERENCES knowledge.symptom(id)
                      ON DELETE CASCADE,
    attribute_code    text NOT NULL,
    label             text NOT NULL,
    data_type         text NOT NULL DEFAULT 'text'
                      CHECK (
                          data_type IN (
                              'text',
                              'number',
                              'boolean',
                              'choice',
                              'date',
                              'datetime',
                              'duration',
                              'quantity'
                          )
                      ),
    required          boolean NOT NULL DEFAULT false,
    options           jsonb,
    validation        jsonb,
    sort_order        integer NOT NULL DEFAULT 0,
    UNIQUE (symptom_id, attribute_code)
);

COMMENT ON TABLE knowledge.symptom_attribute IS
'Structured dimensions through which a symptom may be characterized.';


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_relationship CASCADE;
CREATE TABLE knowledge.symptom_relationship (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,
    related_concept_id    uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    relationship_type     text NOT NULL,
    relevance             numeric,
    context               jsonb,
    UNIQUE (
        symptom_id,
        related_concept_id,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.symptom_relationship IS
'Clinical relationships between symptoms and other concepts.';


-- =============================================================================
-- 6. CLINICAL QUESTIONS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question CASCADE;
CREATE TABLE knowledge.question (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_code         text NOT NULL UNIQUE,
    question_text         text NOT NULL,
    short_text            text,
    question_type         text NOT NULL
                          CHECK (
                              question_type IN (
                                  'yes_no',
                                  'single_choice',
                                  'multiple_choice',
                                  'free_text',
                                  'numeric',
                                  'date',
                                  'datetime',
                                  'duration',
                                  'quantity'
                              )
                          ),
    target_concept_id     uuid REFERENCES knowledge.concept(id),
    purpose               text,
    clinical_domain       text,
    is_active             boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.question IS
'Universal clinical questions used to collect facts without embedding disease-specific UI logic.';


CREATE TRIGGER trg_knowledge_question_updated_at
    BEFORE UPDATE ON knowledge.question
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE knowledge.question_option (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,
    option_code           text NOT NULL,
    label                 text NOT NULL,
    concept_id            uuid REFERENCES knowledge.concept(id),
    value                 jsonb,
    sort_order            integer NOT NULL DEFAULT 0,
    UNIQUE (question_id, option_code)
);

COMMENT ON TABLE knowledge.question_option IS
'Selectable responses for structured clinical questions.';


CREATE TABLE knowledge.question_relationship (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,
    related_question_id   uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,
    relationship          text NOT NULL,
    condition             jsonb,
    UNIQUE (
        question_id,
        related_question_id,
        relationship
    ),
    CHECK (question_id <> related_question_id)
);

COMMENT ON TABLE knowledge.question_relationship IS
'Dependencies between clinical questions, including conditional follow-up logic.';


-- =============================================================================
-- 7. QUESTION CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_context CASCADE;
CREATE TABLE knowledge.question_context (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,
    context_type_code     text NOT NULL
                          REFERENCES knowledge.context_type(code)
                          ON DELETE CASCADE,
    context_value_id      uuid NOT NULL
                          REFERENCES knowledge.context_value(id)
                          ON DELETE CASCADE,
    applicability         text NOT NULL DEFAULT 'preferred'
                          CHECK (
                              applicability IN (
                                  'required',
                                  'preferred',
                                  'optional',
                                  'excluded'
                              )
                          ),
    UNIQUE (
        question_id,
        context_type_code,
        context_value_id
    )
);

COMMENT ON TABLE knowledge.question_context IS
'Controls when a clinical question is required, preferred, optional, or excluded.';


-- =============================================================================
-- 8. PHENOTYPE
-- =============================================================================

CREATE TABLE knowledge.phenotype (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL UNIQUE
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    phenotype_type        text NOT NULL,
    description           text,
    created_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.phenotype IS
'A clinically meaningful phenotype composed from observable concepts and relationships.';


CREATE TABLE knowledge.phenotype_component (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    phenotype_id          uuid NOT NULL
                          REFERENCES knowledge.phenotype(id)
                          ON DELETE CASCADE,
    concept_id            uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    component_role        text NOT NULL,
    required              boolean NOT NULL DEFAULT false,
    weight                numeric,
    min_occurrences       integer,
    max_occurrences       integer,
    condition             jsonb,
    UNIQUE (
        phenotype_id,
        concept_id,
        component_role
    )
);

COMMENT ON TABLE knowledge.phenotype_component IS
'Concepts that compose a phenotype.';


-- =============================================================================
-- 9. MECHANISM
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.mechanism CASCADE;
CREATE TABLE knowledge.mechanism (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL UNIQUE
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    mechanism_type        text NOT NULL,
    description           text
);

COMMENT ON TABLE knowledge.mechanism IS
'Pathophysiological mechanisms represented independently of diseases.';


CREATE TABLE knowledge.mechanism_step (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    mechanism_id          uuid NOT NULL
                          REFERENCES knowledge.mechanism(id)
                          ON DELETE CASCADE,
    sequence_no           integer NOT NULL,
    source_concept_id     uuid NOT NULL
                          REFERENCES knowledge.concept(id),
    relationship_type     text NOT NULL,
    target_concept_id     uuid NOT NULL
                          REFERENCES knowledge.concept(id),
    explanation           text,
    UNIQUE (
        mechanism_id,
        sequence_no
    )
);

COMMENT ON TABLE knowledge.mechanism_step IS
'Ordered causal or mechanistic relationships composing a mechanism.';


-- =============================================================================
-- 10. CONDITION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition CASCADE;
CREATE TABLE knowledge.condition (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL UNIQUE
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    condition_class       text,
    definition            text,
    typical_course        text,
    severity_model        jsonb,
    diagnostic_model      jsonb,
    management_model      jsonb,
    status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','deprecated')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.condition IS
'Universal representation of a clinical condition. Disease-specific behavior is data attached to this object.';


CREATE TRIGGER trg_knowledge_condition_updated_at
    BEFORE UPDATE ON knowledge.condition
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE knowledge.condition_component (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    concept_id            uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    component_type        text NOT NULL,
    relationship          text NOT NULL,
    frequency             numeric,
    likelihood_ratio      numeric,
    importance            numeric,
    context               jsonb,
    notes                 text,
    UNIQUE (
        condition_id,
        concept_id,
        component_type,
        relationship
    )
);

COMMENT ON TABLE knowledge.condition_component IS
'Symptoms, signs, findings, mechanisms, risks, investigations and complications associated with a condition.';


CREATE INDEX idx_condition_component_condition
    ON knowledge.condition_component(condition_id);

CREATE INDEX idx_condition_component_concept
    ON knowledge.condition_component(concept_id);


-- =============================================================================
-- 11. CONDITION CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_context CASCADE;
CREATE TABLE knowledge.condition_context (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    context_type_code     text NOT NULL
                          REFERENCES knowledge.context_type(code)
                          ON DELETE CASCADE,
    context_value_id      uuid NOT NULL
                          REFERENCES knowledge.context_value(id)
                          ON DELETE CASCADE,
    relevance              text NOT NULL DEFAULT 'applicable'
                          CHECK (
                              relevance IN (
                                  'required',
                                  'typical',
                                  'possible',
                                  'uncommon',
                                  'excluded'
                              )
                          ),
    probability_modifier   numeric,
    notes                  text,
    UNIQUE (
        condition_id,
        context_type_code,
        context_value_id
    )
);

COMMENT ON TABLE knowledge.condition_context IS
'Clinical context that modifies applicability or probability of a condition.';


-- =============================================================================
-- 12. CONDITION PHENOTYPE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_phenotype CASCADE;
CREATE TABLE knowledge.condition_phenotype (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    phenotype_id          uuid NOT NULL
                          REFERENCES knowledge.phenotype(id)
                          ON DELETE CASCADE,
    relationship          text NOT NULL,
    weight                numeric,
    context               jsonb,
    UNIQUE (
        condition_id,
        phenotype_id,
        relationship
    )
);

COMMENT ON TABLE knowledge.condition_phenotype IS
'Phenotypic patterns associated with conditions.';


-- =============================================================================
-- 13. CONDITION MECHANISM
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_mechanism CASCADE;
CREATE TABLE knowledge.condition_mechanism (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    mechanism_id          uuid NOT NULL
                          REFERENCES knowledge.mechanism(id)
                          ON DELETE CASCADE,
    relationship          text NOT NULL,
    contribution          numeric,
    context               jsonb,
    UNIQUE (
        condition_id,
        mechanism_id,
        relationship
    )
);

COMMENT ON TABLE knowledge.condition_mechanism IS
'Mechanisms through which a condition produces its phenotype.';


-- =============================================================================
-- 14. CONDITION DIFFERENTIAL
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_differential CASCADE;
CREATE TABLE knowledge.condition_differential (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    differential_condition_id uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    discriminator_concept_id uuid
                          REFERENCES knowledge.concept(id),
    discriminator_type    text,
    importance            numeric,
    context               jsonb,
    notes                 text,
    UNIQUE (
        condition_id,
        differential_condition_id,
        discriminator_concept_id
    ),
    CHECK (condition_id <> differential_condition_id)
);

COMMENT ON TABLE knowledge.condition_differential IS
'Structured differential-diagnosis relationships between conditions.';


-- =============================================================================
-- 15. INVESTIGATION KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.investigation CASCADE;
CREATE TABLE knowledge.investigation (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL UNIQUE
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    investigation_type    text NOT NULL,
    specimen_type         text,
    methodology           text,
    purpose               text,
    description           text
);

COMMENT ON TABLE knowledge.investigation IS
'Universal investigation knowledge independent of any one disease.';


CREATE TABLE knowledge.investigation_parameter (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investigation_id      uuid NOT NULL
                          REFERENCES knowledge.investigation(id)
                          ON DELETE CASCADE,
    code                  text NOT NULL,
    name                  text NOT NULL,
    unit                  text,
    value_type            text NOT NULL,
    reference_range       jsonb,
    critical_range        jsonb,
    interpretation        jsonb,
    UNIQUE (
        investigation_id,
        code
    )
);

COMMENT ON TABLE knowledge.investigation_parameter IS
'Parameters and interpretable outputs of an investigation.';


CREATE TABLE knowledge.condition_investigation (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    investigation_id      uuid NOT NULL
                          REFERENCES knowledge.investigation(id)
                          ON DELETE CASCADE,
    purpose               text NOT NULL,
    priority              integer NOT NULL DEFAULT 0,
    indication            jsonb,
    expected_findings     jsonb,
    exclusion_findings    jsonb,
    context               jsonb,
    UNIQUE (
        condition_id,
        investigation_id,
        purpose
    )
);

COMMENT ON TABLE knowledge.condition_investigation IS
'Investigations associated with a condition and the clinical purpose for ordering them.';


-- =============================================================================
-- 16. MEDICATION KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication CASCADE;
CREATE TABLE knowledge.medication (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL UNIQUE
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    generic_name          text NOT NULL,
    medication_class      text,
    route_options         jsonb,
    formulation_options  jsonb,
    description           text
);

COMMENT ON TABLE knowledge.medication IS
'Universal medication vocabulary and metadata.';


CREATE TABLE knowledge.medication_dose_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_id         uuid NOT NULL
                          REFERENCES knowledge.medication(id)
                          ON DELETE CASCADE,
    indication_concept_id uuid REFERENCES knowledge.concept(id),
    route                 text,
    dose_basis             text,
    dose_value             numeric,
    dose_unit              text,
    frequency              text,
    duration              text,
    minimum_dose           numeric,
    maximum_dose           numeric,
    maximum_daily_dose     numeric,
    context               jsonb,
    conditions            jsonb,
    notes                 text
);

COMMENT ON TABLE knowledge.medication_dose_rule IS
'Context-dependent medication dosing knowledge.';


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_safety_rule CASCADE;
CREATE TABLE knowledge.medication_safety_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    medication_id         uuid NOT NULL
                          REFERENCES knowledge.medication(id)
                          ON DELETE CASCADE,
    rule_type             text NOT NULL,
    severity              text NOT NULL
                          CHECK (
                              severity IN (
                                  'info',
                                  'warning',
                                  'major',
                                  'contraindicated'
                              )
                          ),
    condition             jsonb NOT NULL,
    message               text NOT NULL,
    recommendation        text
);

COMMENT ON TABLE knowledge.medication_safety_rule IS
'Universal medication safety rules.';


-- =============================================================================
-- 17. COMPLICATION KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_complication CASCADE;
CREATE TABLE knowledge.condition_complication (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    complication_concept_id uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    probability            numeric,
    severity               text,
    timing                 jsonb,
    risk_context           jsonb,
    warning_signs          jsonb,
    UNIQUE (
        condition_id,
        complication_concept_id
    )
);

COMMENT ON TABLE knowledge.condition_complication IS
'Potential complications and their contextual characteristics.';


-- =============================================================================
-- 18. RISK FACTOR KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_risk_factor CASCADE;
CREATE TABLE knowledge.condition_risk_factor (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,
    risk_factor_concept_id uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    effect                 text NOT NULL DEFAULT 'increases_risk',
    strength               numeric,
    context                jsonb,
    mechanism_id           uuid
                          REFERENCES knowledge.mechanism(id),
    notes                  text,
    UNIQUE (
        condition_id,
        risk_factor_concept_id
    )
);

COMMENT ON TABLE knowledge.condition_risk_factor IS
'Risk factors associated with conditions.';


-- =============================================================================
-- 19. BODY SYSTEM MEMBERSHIP
-- =============================================================================

CREATE TABLE knowledge.concept_body_system (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    body_system_code      text NOT NULL
                          REFERENCES knowledge.body_system(code),
    relationship           text NOT NULL DEFAULT 'primary',
    importance              numeric,
    UNIQUE (
        concept_id,
        body_system_code,
        relationship
    )
);

COMMENT ON TABLE knowledge.concept_body_system IS
'Associates any clinical concept with one or more body systems.';


-- =============================================================================
-- 20. CLINICAL DOMAIN
-- =============================================================================

CREATE TABLE knowledge.domain (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                  text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description           text,
    parent_domain_id      uuid REFERENCES knowledge.domain(id),
    is_active             boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.domain IS
'Hierarchical clinical knowledge domains.';


CREATE TABLE knowledge.concept_domain (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id            uuid NOT NULL
                          REFERENCES knowledge.concept(id)
                          ON DELETE CASCADE,
    domain_id             uuid NOT NULL
                          REFERENCES knowledge.domain(id)
                          ON DELETE CASCADE,
    relevance              numeric,
    UNIQUE (
        concept_id,
        domain_id
    )
);

COMMENT ON TABLE knowledge.concept_domain IS
'Maps concepts into one or more clinical knowledge domains.';


-- =============================================================================
-- 21. KNOWLEDGE SOURCE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.source CASCADE;
CREATE TABLE knowledge.source (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type            text NOT NULL,
    title                  text NOT NULL,
    citation               text,
    publisher              text,
    edition                text,
    publication_date       date,
    url                    text,
    identifier             text,
    license                text,
    metadata               jsonb,
    created_at             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.source IS
'Provenance sources supporting knowledge objects.';


CREATE TABLE knowledge.source_reference (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id             uuid NOT NULL
                          REFERENCES knowledge.source(id)
                          ON DELETE CASCADE,
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    locator                text,
    quoted_text            text,
    interpretation         text,
    created_at             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.source_reference IS
'Provenance links from knowledge objects to supporting sources.';

CREATE INDEX idx_knowledge_source_reference_entity
    ON knowledge.source_reference(entity_type, entity_id);


-- =============================================================================
-- 22. KNOWLEDGE VERSION
-- =============================================================================

CREATE TABLE knowledge.version (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_code          text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description           text,
    status                text NOT NULL DEFAULT 'draft'
                          CHECK (
                              status IN (
                                  'draft',
                                  'validated',
                                  'published',
                                  'retired'
                              )
                          ),
    created_at            timestamptz NOT NULL DEFAULT now(),
    published_at          timestamptz,
    created_by             uuid REFERENCES identity.user_account(id),
    published_by           uuid REFERENCES identity.user_account(id)
);

COMMENT ON TABLE knowledge.version IS
'A publishable version of the AMEXAN knowledge substrate.';


CREATE TABLE knowledge.version_member (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id             uuid NOT NULL
                          REFERENCES knowledge.version(id)
                          ON DELETE CASCADE,
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    UNIQUE (
        version_id,
        entity_type,
        entity_id
    )
);

COMMENT ON TABLE knowledge.version_member IS
'Objects included in a specific knowledge release.';


-- =============================================================================
-- 23. KNOWLEDGE VALIDATION
-- =============================================================================

CREATE TABLE knowledge.validation_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                  text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description           text,
    entity_type            text NOT NULL,
    severity              text NOT NULL DEFAULT 'error'
                          CHECK (
                              severity IN (
                                  'info',
                                  'warning',
                                  'error',
                                  'critical'
                              )
                          ),
    expression             jsonb NOT NULL,
    is_active              boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.validation_rule IS
'Machine-readable rules used to validate knowledge integrity.';


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.validation_run CASCADE;
CREATE TABLE knowledge.validation_run (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id             uuid REFERENCES knowledge.version(id),
    started_at             timestamptz NOT NULL DEFAULT now(),
    completed_at           timestamptz,
    status                 text NOT NULL DEFAULT 'running'
                          CHECK (
                              status IN (
                                  'running',
                                  'passed',
                                  'failed'
                              )
                          ),
    error_count             integer NOT NULL DEFAULT 0,
    warning_count           integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE knowledge.validation_run IS
'Execution of knowledge validation.';


CREATE TABLE knowledge.validation_result (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    validation_run_id      uuid NOT NULL
                          REFERENCES knowledge.validation_run(id)
                          ON DELETE CASCADE,
    validation_rule_id     uuid NOT NULL
                          REFERENCES knowledge.validation_rule(id),
    entity_type            text,
    entity_id              uuid,
    passed                 boolean NOT NULL,
    severity               text NOT NULL,
    message                text,
    detail                 jsonb
);

COMMENT ON TABLE knowledge.validation_result IS
'Individual knowledge validation results.';


-- =============================================================================
-- 24. KNOWLEDGE CHANGE HISTORY
-- =============================================================================

CREATE TABLE knowledge.change (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    change_type            text NOT NULL
                          CHECK (
                              change_type IN (
                                  'create',
                                  'update',
                                  'deprecate',
                                  'restore',
                                  'delete'
                              )
                          ),
    before_data            jsonb,
    after_data             jsonb,
    changed_by             uuid REFERENCES identity.user_account(id),
    changed_at             timestamptz NOT NULL DEFAULT now(),
    reason                 text
);

COMMENT ON TABLE knowledge.change IS
'Immutable change history for knowledge objects.';

CREATE INDEX idx_knowledge_change_entity
    ON knowledge.change(entity_type, entity_id);

CREATE INDEX idx_knowledge_change_time
    ON knowledge.change(changed_at);


-- =============================================================================
-- 25. CONTEXT SET
-- =============================================================================

CREATE TABLE knowledge.context_set (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                  text NOT NULL UNIQUE,
    name                  text NOT NULL,
    description           text,
    is_active              boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.context_set IS
'A reusable named bundle of clinical context constraints.';


CREATE TABLE knowledge.context_set_member (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    context_set_id         uuid NOT NULL
                          REFERENCES knowledge.context_set(id)
                          ON DELETE CASCADE,
    context_type_code      text NOT NULL
                          REFERENCES knowledge.context_type(code),
    context_value_id       uuid NOT NULL
                          REFERENCES knowledge.context_value(id),
    required               boolean NOT NULL DEFAULT true,
    negated                boolean NOT NULL DEFAULT false,
    UNIQUE (
        context_set_id,
        context_type_code,
        context_value_id
    )
);

COMMENT ON TABLE knowledge.context_set_member IS
'Context values composing a reusable context set.';


-- =============================================================================
-- 26. KNOWLEDGE APPLICABILITY
-- =============================================================================

CREATE TABLE knowledge.applicability (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    context_set_id         uuid NOT NULL
                          REFERENCES knowledge.context_set(id)
                          ON DELETE CASCADE,
    applicability           text NOT NULL
                          CHECK (
                              applicability IN (
                                  'required',
                                  'preferred',
                                  'optional',
                                  'excluded'
                              )
                          ),
    priority                integer NOT NULL DEFAULT 0,
    condition               jsonb,
    UNIQUE (
        entity_type,
        entity_id,
        context_set_id
    )
);

COMMENT ON TABLE knowledge.applicability IS
'Universal context-dependent applicability for any knowledge object.';

CREATE INDEX idx_knowledge_applicability_entity
    ON knowledge.applicability(entity_type, entity_id);


-- =============================================================================
-- 27. KNOWLEDGE TAG
-- =============================================================================

CREATE TABLE knowledge.tag (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code                  text NOT NULL UNIQUE,
    label                 text NOT NULL,
    description           text
);

COMMENT ON TABLE knowledge.tag IS
'Reusable semantic tags for knowledge organization.';


CREATE TABLE knowledge.entity_tag (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_id                uuid NOT NULL
                          REFERENCES knowledge.tag(id)
                          ON DELETE CASCADE,
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    UNIQUE (
        tag_id,
        entity_type,
        entity_id
    )
);

COMMENT ON TABLE knowledge.entity_tag IS
'Associates reusable tags with knowledge objects.';

CREATE INDEX idx_knowledge_entity_tag_entity
    ON knowledge.entity_tag(entity_type, entity_id);


-- =============================================================================
-- 28. SEED UNIVERSAL CONTEXT TYPES
-- =============================================================================

INSERT INTO knowledge.context_type (code, label, description)
VALUES
    ('AGE', 'Age', 'Chronological age or age band.'),
    ('SEX', 'Sex', 'Biological sex context.'),
    ('PREGNANCY', 'Pregnancy', 'Pregnancy status.'),
    ('GESTATIONAL_AGE', 'Gestational Age', 'Gestational age context.'),
    ('BODY_SYSTEM', 'Body System', 'Relevant physiological body system.'),
    ('SPECIALTY', 'Specialty', 'Clinical specialty context.'),
    ('DEPARTMENT', 'Department', 'Clinical department context.'),
    ('CARE_SETTING', 'Care Setting', 'Location or mode of care.'),
    ('ACUITY', 'Acuity', 'Clinical acuity.'),
    ('COMORBIDITY', 'Comorbidity', 'Relevant coexisting condition.'),
    ('IMMUNOCOMPROMISED_STATUS', 'Immunocompromised Status', 'Immune status.'),
    ('GEOGRAPHY', 'Geography', 'Geographic or epidemiological context.'),
    ('SEASON', 'Season', 'Seasonal context.'),
    ('LIFE_STAGE', 'Life Stage', 'Developmental or reproductive life stage.'),
    ('CARE_PHASE', 'Care Phase', 'Phase of clinical care.')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 29. SEED UNIVERSAL CONTEXT VALUES
-- =============================================================================

INSERT INTO knowledge.context_value
    (context_type_code, value, label, sort_order)
VALUES
    ('AGE', '0-28D', 'Neonate: 0â€“28 days', 10),
    ('AGE', '1-11M', 'Infant: 1â€“11 months', 20),
    ('AGE', '1-4Y', 'Early childhood: 1â€“4 years', 30),
    ('AGE', '5-11Y', 'Child: 5â€“11 years', 40),
    ('AGE', '12-17Y', 'Adolescent: 12â€“17 years', 50),
    ('AGE', '18-64Y', 'Adult: 18â€“64 years', 60),
    ('AGE', '65+Y', 'Older adult: 65+ years', 70),

    ('SEX', 'male', 'Male', 10),
    ('SEX', 'female', 'Female', 20),
    ('SEX', 'intersex', 'Intersex', 30),
    ('SEX', 'unknown', 'Unknown / not recorded', 40),

    ('PREGNANCY', 'not_pregnant', 'Not pregnant', 10),
    ('PREGNANCY', 'pregnant', 'Pregnant', 20),
    ('PREGNANCY', 'postpartum', 'Postpartum', 30),
    ('PREGNANCY', 'unknown', 'Unknown', 40),

    ('ACUITY', 'routine', 'Routine', 10),
    ('ACUITY', 'urgent', 'Urgent', 20),
    ('ACUITY', 'emergency', 'Emergency', 30),
    ('ACUITY', 'critical', 'Critical', 40),

    ('CARE_SETTING', 'community', 'Community', 10),
    ('CARE_SETTING', 'outpatient', 'Outpatient', 20),
    ('CARE_SETTING', 'emergency', 'Emergency department', 30),
    ('CARE_SETTING', 'inpatient', 'Inpatient', 40),
    ('CARE_SETTING', 'icu', 'Intensive care', 50),
    ('CARE_SETTING', 'theatre', 'Operating theatre', 60),
    ('CARE_SETTING', 'telemedicine', 'Telemedicine', 70),

    ('LIFE_STAGE', 'neonatal', 'Neonatal', 10),
    ('LIFE_STAGE', 'infancy', 'Infancy', 20),
    ('LIFE_STAGE', 'childhood', 'Childhood', 30),
    ('LIFE_STAGE', 'adolescence', 'Adolescence', 40),
    ('LIFE_STAGE', 'adulthood', 'Adulthood', 50),
    ('LIFE_STAGE', 'older_adult', 'Older adulthood', 60)
ON CONFLICT (context_type_code, value) DO NOTHING;


-- =============================================================================
-- 30. SEED BODY SYSTEMS
-- =============================================================================

INSERT INTO knowledge.body_system (code, label, description)
VALUES
    ('CARDIOVASCULAR', 'Cardiovascular', 'Heart and vascular system.'),
    ('RESPIRATORY', 'Respiratory', 'Airways and lungs.'),
    ('GASTROINTESTINAL', 'Gastrointestinal', 'Digestive tract and associated organs.'),
    ('HEPATOBILIARY', 'Hepatobiliary', 'Liver, gallbladder and biliary system.'),
    ('RENAL', 'Renal', 'Kidneys and renal physiology.'),
    ('UROLOGICAL', 'Urological', 'Urinary tract.'),
    ('REPRODUCTIVE', 'Reproductive', 'Male and female reproductive systems.'),
    ('ENDOCRINE', 'Endocrine', 'Endocrine organs and hormonal systems.'),
    ('NERVOUS', 'Nervous', 'Central and peripheral nervous systems.'),
    ('MUSCULOSKELETAL', 'Musculoskeletal', 'Bones, joints, muscles and connective tissues.'),
    ('INTEGUMENTARY', 'Integumentary', 'Skin, hair, nails and associated structures.'),
    ('HEMATOLOGICAL', 'Hematological', 'Blood and hematopoietic system.'),
    ('IMMUNOLOGICAL', 'Immunological', 'Immune system.'),
    ('LYMPHATIC', 'Lymphatic', 'Lymphatic system.'),
    ('OPHTHALMIC', 'Ophthalmic', 'Eye and visual system.'),
    ('ENT', 'Ear Nose and Throat', 'Ear, nose, throat and related structures.'),
    ('DENTAL', 'Dental', 'Teeth, gums and oral structures.'),
    ('PSYCHIATRIC', 'Psychiatric', 'Mental and behavioral health.'),
    ('SYSTEMIC', 'Systemic', 'Multisystem or systemic processes.')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 31. SEED RELATIONSHIP TYPES
-- =============================================================================

INSERT INTO knowledge.concept_relationship_type
    (code, label, description, is_directional)
VALUES
    ('CAUSES', 'Causes', 'Source concept causes or contributes to target.', true),
    ('CAUSED_BY', 'Caused By', 'Source concept is caused by target.', true),
    ('ASSOCIATED_WITH', 'Associated With', 'General clinical association.', false),
    ('PRESENTS_WITH', 'Presents With', 'Condition or phenotype presents with concept.', true),
    ('SUPPORTS', 'Supports', 'Concept supports another concept or interpretation.', true),
    ('ARGUES_AGAINST', 'Argues Against', 'Concept decreases support for another concept.', true),
    ('PRECEDES', 'Precedes', 'Temporal relationship.', true),
    ('FOLLOWS', 'Follows', 'Temporal relationship.', true),
    ('PART_OF', 'Part Of', 'Source is a component of target.', true),
    ('HAS_COMPONENT', 'Has Component', 'Target contains source component.', true),
    ('SUBTYPE_OF', 'Subtype Of', 'Source is a subtype of target.', true),
    ('SUPERSEDES', 'Supersedes', 'Source supersedes target.', true),
    ('MIMICS', 'Mimics', 'Source may clinically resemble target.', true),
    ('DIFFERENTIAL_OF', 'Differential Of', 'Source is a differential diagnosis of target.', true),
    ('RISK_FOR', 'Risk For', 'Source increases risk for target.', true),
    ('COMPLICATION_OF', 'Complication Of', 'Source is a complication of target.', true),
    ('MANIFESTATION_OF', 'Manifestation Of', 'Source is a manifestation of target.', true),
    ('MECHANISM_OF', 'Mechanism Of', 'Source is a mechanism of target.', true),
    ('LOCATED_IN', 'Located In', 'Source is anatomically located in target.', true),
    ('MEASURED_BY', 'Measured By', 'Source is measured using target.', true)
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 32. KNOWLEDGE INTEGRITY INDEXES
-- =============================================================================

CREATE INDEX idx_knowledge_condition_context_condition
    ON knowledge.condition_context(condition_id);

CREATE INDEX idx_knowledge_condition_context_value
    ON knowledge.condition_context(context_value_id);

CREATE INDEX idx_knowledge_condition_phenotype_condition
    ON knowledge.condition_phenotype(condition_id);

CREATE INDEX idx_knowledge_condition_mechanism_condition
    ON knowledge.condition_mechanism(condition_id);

CREATE INDEX idx_knowledge_condition_differential_condition
    ON knowledge.condition_differential(condition_id);

CREATE INDEX idx_knowledge_condition_risk_condition
    ON knowledge.condition_risk_factor(condition_id);

CREATE INDEX idx_knowledge_condition_complication_condition
    ON knowledge.condition_complication(condition_id);

CREATE INDEX idx_knowledge_condition_investigation_condition
    ON knowledge.condition_investigation(condition_id);

CREATE INDEX idx_knowledge_medication_dose_medication
    ON knowledge.medication_dose_rule(medication_id);

CREATE INDEX idx_knowledge_medication_safety_medication
    ON knowledge.medication_safety_rule(medication_id);

CREATE INDEX idx_knowledge_phenotype_component
    ON knowledge.phenotype_component(phenotype_id);

CREATE INDEX idx_knowledge_mechanism_step
    ON knowledge.mechanism_step(mechanism_id);

CREATE INDEX idx_knowledge_question_context
    ON knowledge.question_context(question_id);

CREATE INDEX idx_knowledge_question_option
    ON knowledge.question_option(question_id);

CREATE INDEX idx_knowledge_concept_body_system
    ON knowledge.concept_body_system(concept_id);

CREATE INDEX idx_knowledge_version_member
    ON knowledge.version_member(version_id);

CREATE INDEX idx_knowledge_validation_result_run
    ON knowledge.validation_result(validation_run_id);


-- =============================================================================
-- 33. UNIVERSAL KNOWLEDGE RESOLUTION VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_concept_context AS
SELECT
    c.id AS concept_id,
    c.concept_code,
    c.concept_type,
    c.canonical_name,
    c.display_name,
    c.status,
    ct.code AS context_type_code,
    cv.id AS context_value_id,
    cv.value AS context_value,
    cv.label AS context_label,
    cc.relationship,
    cc.weight,
    cc.notes
FROM knowledge.concept c
JOIN knowledge.concept_context cc
    ON cc.concept_id = c.id
JOIN knowledge.context_type ct
    ON ct.code = cc.context_type_code
JOIN knowledge.context_value cv
    ON cv.id = cc.context_value_id;


-- =============================================================================
-- 34. UNIVERSAL CONDITION PROFILE VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_condition_profile AS
SELECT
    c.id AS condition_id,
    c.concept_id,
    cpt.concept_code,
    cpt.canonical_name,
    cpt.display_name,
    c.definition,
    c.condition_class,
    c.status
FROM knowledge.condition c
JOIN knowledge.concept cpt
    ON cpt.id = c.concept_id;


-- =============================================================================
-- 35. UNIVERSAL CONCEPT GRAPH VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_concept_graph AS
SELECT
    cr.id AS relationship_id,
    cr.source_concept_id,
    source.concept_code AS source_code,
    source.canonical_name AS source_name,
    cr.relationship_type_code,
    crt.label AS relationship_label,
    cr.target_concept_id,
    target.concept_code AS target_code,
    target.canonical_name AS target_name,
    cr.strength,
    cr.certainty,
    cr.context,
    cr.status
FROM knowledge.concept_relationship cr
JOIN knowledge.concept source
    ON source.id = cr.source_concept_id
JOIN knowledge.concept_relationship_type crt
    ON crt.code = cr.relationship_type_code
JOIN knowledge.concept target
    ON target.id = cr.target_concept_id;


-- =============================================================================
-- 36. UNIVERSAL KNOWLEDGE OBJECT REGISTRY
-- =============================================================================

CREATE TABLE knowledge.object_registry (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type            text NOT NULL,
    entity_id              uuid NOT NULL,
    canonical_code         text,
    display_name           text,
    status                 text NOT NULL DEFAULT 'active'
                          CHECK (
                              status IN (
                                  'active',
                                  'deprecated',
                                  'draft'
                              )
                          ),
    registered_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (
        entity_type,
        entity_id
    )
);

COMMENT ON TABLE knowledge.object_registry IS
'Universal registry of knowledge objects for indexing, versioning and graph traversal.';

CREATE INDEX idx_knowledge_object_registry_code
    ON knowledge.object_registry(canonical_code);

CREATE INDEX idx_knowledge_object_registry_type
    ON knowledge.object_registry(entity_type);


-- =============================================================================
-- 37. KNOWLEDGE PUBLICATION LOCK
-- =============================================================================

CREATE TABLE knowledge.publication (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id             uuid NOT NULL UNIQUE
                          REFERENCES knowledge.version(id),
    publication_code       text NOT NULL UNIQUE,
    published_at           timestamptz NOT NULL DEFAULT now(),
    published_by           uuid REFERENCES identity.user_account(id),
    checksum               text,
    metadata               jsonb
);

COMMENT ON TABLE knowledge.publication IS
'Immutable publication record for a validated knowledge version.';


-- =============================================================================
-- 38. FINAL COMMENTS
-- =============================================================================

COMMENT ON TABLE knowledge.concept_relationship IS
'Universal concept graph. Disease-specific intelligence is composed from these reusable relationships.';

COMMENT ON TABLE knowledge.condition IS
'Universal condition representation. No disease-specific engine is required.';

COMMENT ON TABLE knowledge.question IS
'Universal clinical question substrate used by history, examination and decision workflows.';

COMMENT ON TABLE knowledge.context_set IS
'Reusable context composition for age, sex, pregnancy, acuity, setting, specialty and other dimensions.';

COMMENT ON TABLE knowledge.version IS
'Versioned publication boundary for the AMEXAN knowledge substrate.';
