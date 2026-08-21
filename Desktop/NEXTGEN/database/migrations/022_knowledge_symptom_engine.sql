-- =============================================================================
-- AMEXAN UNIVERSAL CLINICAL OPERATING SYSTEM
-- Migration: Universal Symptom Intelligence + HPI + Clinical Exploration Layer
-- =============================================================================
--
-- PURPOSE
-- -------
-- The symptom is the primary clinical entry point.
--
-- The system must be able to start from:
--
--      CHIEF COMPLAINT
--            â†“
--      SYMPTOM
--            â†“
--      HPI OBJECTIVES
--            â†“
--      CHARACTERISTICS / SOCRATES
--            â†“
--      ASSOCIATED SYMPTOMS
--            â†“
--      ETIOLOGY / RISK FACTORS
--            â†“
--      RED FLAGS
--            â†“
--      FUNCTIONAL IMPACT
--            â†“
--      PREVIOUS EPISODES / HEALTH-SEEKING / TREATMENT
--            â†“
--      EXAMINATION TARGETS
--            â†“
--      INVESTIGATION TARGETS
--            â†“
--      PHENOTYPES
--            â†“
--      DIFFERENTIALS
--            â†“
--      MECHANISMS
--            â†“
--      CONDITIONS
--            â†“
--      MANAGEMENT / MONITORING / EDUCATION / FOLLOW-UP
--
-- IMPORTANT ARCHITECTURAL RULES
-- -----------------------------
-- 1. Symptoms are universal knowledge objects.
-- 2. Diseases consume symptoms; diseases do not recreate them.
-- 3. One concept may participate in many specialties/body systems.
-- 4. History, examination and investigation results enter the SAME fact
--    substrate used by the CPU.
-- 5. The HPI engine asks questions to acquire clinically useful facts.
-- 6. Questions are adaptive; the entire questionnaire is NEVER hardcoded.
-- 7. The HPI engine must not make diagnostic deductions while documenting
--    the patient's history.
-- 8. Diagnostic reasoning occurs downstream in the CPU.
-- 9. Documentation is generated from captured facts, not invented prose.
-- 10. Missing information remains missing; the engine must never fabricate it.
-- 11. Safety/red-flag questions have priority over routine characterization.
-- 12. Pediatric, neonatal, adult, geriatric, pregnancy and other contexts
--     modify applicability without duplicating symptoms.
-- 13. A single symptom can be simultaneously relevant to medicine, surgery,
--     paediatrics, emergency medicine, ENT, respiratory, cardiovascular,
--     gastrointestinal, neurological and other domains.
-- 14. The schema is designed for very fast CPU retrieval:
--       indexed IDs/codes
--       compact junctions
--       deterministic priorities
--       no disease-specific symptom duplication.
--
-- =============================================================================


BEGIN;


-- ============================================================================
-- 1. SYMPTOM â†’ RISK FACTOR
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_risk_factor (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
                        REFERENCES knowledge.symptom(id)
                        ON DELETE CASCADE,

    risk_factor_code    text NOT NULL,
    canonical_name      text NOT NULL,
    description         text,

    category            text NOT NULL DEFAULT 'other'
                        CHECK (category IN (
                            'demographic',
                            'environmental',
                            'occupational',
                            'behavioural',
                            'exposure',
                            'infectious',
                            'medication',
                            'medical',
                            'surgical',
                            'reproductive',
                            'family',
                            'genetic',
                            'nutritional',
                            'social',
                            'travel',
                            'iatrogenic',
                            'other'
                        )),

    relevance           numeric(4,3) NOT NULL DEFAULT 1.000
                        CHECK (relevance >= 0 AND relevance <= 1),

    is_red_flag         boolean NOT NULL DEFAULT false,
    priority            integer NOT NULL DEFAULT 50,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (symptom_id, risk_factor_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_rf_symptom
    ON knowledge.symptom_risk_factor(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_rf_code
    ON knowledge.symptom_risk_factor(risk_factor_code);

CREATE INDEX IF NOT EXISTS idx_symptom_rf_priority
    ON knowledge.symptom_risk_factor(symptom_id, priority DESC);


-- ============================================================================
-- 2. SYMPTOM â†’ ETIOLOGY
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_etiology (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
                        REFERENCES knowledge.symptom(id)
                        ON DELETE CASCADE,

    etiology_code       text NOT NULL,
    canonical_name      text NOT NULL,
    description         text,

    category            text NOT NULL DEFAULT 'other'
                        CHECK (category IN (
                            'infectious',
                            'inflammatory',
                            'vascular',
                            'neoplastic',
                            'traumatic',
                            'obstructive',
                            'metabolic',
                            'endocrine',
                            'toxic',
                            'drug_related',
                            'degenerative',
                            'congenital',
                            'genetic',
                            'functional',
                            'psychological',
                            'iatrogenic',
                            'environmental',
                            'other'
                        )),

    weight              numeric(4,3) NOT NULL DEFAULT 1.000
                        CHECK (weight >= 0 AND weight <= 1),

    priority            integer NOT NULL DEFAULT 50,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (symptom_id, etiology_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_etiology_symptom
    ON knowledge.symptom_etiology(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_etiology_category
    ON knowledge.symptom_etiology(category);

CREATE INDEX IF NOT EXISTS idx_symptom_etiology_priority
    ON knowledge.symptom_etiology(symptom_id, priority DESC);


-- ============================================================================
-- 3. SYMPTOM â†’ FUNCTIONAL IMPACT
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_functional_impact (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    functional_impact_code text NOT NULL,
    canonical_name        text NOT NULL,
    description           text,

    domain                text NOT NULL DEFAULT 'general'
                          CHECK (domain IN (
                              'activities_of_daily_living',
                              'mobility',
                              'feeding',
                              'sleep',
                              'work',
                              'school',
                              'exercise',
                              'communication',
                              'self_care',
                              'social',
                              'sexual',
                              'reproductive',
                              'caregiving',
                              'general'
                          )),

    weight                numeric(4,3) NOT NULL DEFAULT 1.000
                          CHECK (weight >= 0 AND weight <= 1),

    priority              integer NOT NULL DEFAULT 50,

    UNIQUE (symptom_id, functional_impact_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_functional_symptom
    ON knowledge.symptom_functional_impact(symptom_id);


-- ============================================================================
-- 4. SYMPTOM â†’ POTENTIAL COMPLICATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_complication (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
                        REFERENCES knowledge.symptom(id)
                        ON DELETE CASCADE,

    complication_code   text NOT NULL,
    canonical_name      text NOT NULL,
    description         text,

    urgency             text NOT NULL DEFAULT 'urgent'
                        CHECK (urgency IN (
                            'emergency',
                            'urgent',
                            'routine'
                        )),

    weight              numeric(4,3) NOT NULL DEFAULT 1.000
                        CHECK (weight >= 0 AND weight <= 1),

    priority            integer NOT NULL DEFAULT 50,

    UNIQUE (symptom_id, complication_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_complication_symptom
    ON knowledge.symptom_complication(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_complication_urgency
    ON knowledge.symptom_complication(symptom_id, urgency);


-- ============================================================================
-- 5. SYMPTOM â†’ EXAMINATION TARGET
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_examination_target (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id          uuid NOT NULL
                        REFERENCES knowledge.symptom(id)
                        ON DELETE CASCADE,

    finding_code        text NOT NULL,

    priority            integer NOT NULL DEFAULT 50,

    urgency             text NOT NULL DEFAULT 'routine'
                        CHECK (urgency IN (
                            'immediate',
                            'urgent',
                            'routine'
                        )),

    rationale            text,

    required_if          jsonb,

    UNIQUE (symptom_id, finding_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_exam_symptom
    ON knowledge.symptom_examination_target(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_exam_priority
    ON knowledge.symptom_examination_target(symptom_id, priority DESC);


-- ============================================================================
-- 6. SYMPTOM â†’ INVESTIGATION TARGET
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_investigation_target (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    investigation_code    text NOT NULL,

    priority              integer NOT NULL DEFAULT 50,

    urgency               text NOT NULL DEFAULT 'routine'
                          CHECK (urgency IN (
                              'immediate',
                              'urgent',
                              'routine'
                          )),

    rationale             text,

    activation_rule       jsonb,

    UNIQUE (symptom_id, investigation_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_investigation_symptom
    ON knowledge.symptom_investigation_target(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_investigation_priority
    ON knowledge.symptom_investigation_target(symptom_id, priority DESC);


-- ============================================================================
-- 7. UNIVERSAL HPI FACT â†’ DOCUMENTATION TEMPLATE
-- ============================================================================
--
-- Documentation is generated from facts.
--
-- Example:
--
-- fact: COUGH_DURATION_DAYS = 4
-- template: "The patient reports a cough of {value} days' duration."
--
-- The engine MUST NOT write:
-- "likely infectious"
--
-- unless that is an explicit assessment generated downstream.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_hpi_template (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    section               text NOT NULL DEFAULT 'history'
                          CHECK (section IN (
                              'history',
                              'examination',
                              'assessment',
                              'summary'
                          )),

    subsection            text,

    fact_definition_code  text NOT NULL
                          REFERENCES clinical.fact_definition(code),

    fact_value            text,

    phrase_template       text NOT NULL,

    negative_phrase       text,

    missing_phrase        text,

    sort_order            integer NOT NULL DEFAULT 0,

    language_code         text NOT NULL DEFAULT 'en',

    context_rule          jsonb,

    is_preferred          boolean NOT NULL DEFAULT false,

    is_active             boolean NOT NULL DEFAULT true,

    supersedes_fact_code  text
                          REFERENCES clinical.fact_definition(code),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        symptom_id,
        section,
        fact_definition_code,
        fact_value,
        language_code
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_lookup
    ON knowledge.symptom_hpi_template(
        symptom_id,
        section,
        fact_definition_code,
        is_active
    );

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_fact
    ON knowledge.symptom_hpi_template(fact_definition_code);


-- ============================================================================
-- 8. SYMPTOM ACTIVATION FACT
-- ============================================================================
--
-- Determines when a symptom becomes an active clinical thread.
--
-- Example:
--
-- COUGH_PRESENT = true
--      â†’
-- activate COUGH symptom
--      â†’
-- open cough HPI pathway
--      â†’
-- activate cough characterization
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_activation_fact (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    fact_definition_code  text NOT NULL
                          REFERENCES clinical.fact_definition(code),

    active_operator       text NOT NULL DEFAULT 'eq'
                          CHECK (active_operator IN (
                              'eq',
                              'neq',
                              'gt',
                              'gte',
                              'lt',
                              'lte',
                              'exists',
                              'not_exists',
                              'in',
                              'contains'
                          )),

    active_value          text,

    priority              integer NOT NULL DEFAULT 50,

    UNIQUE (
        symptom_id,
        fact_definition_code
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_activation_fact
    ON knowledge.symptom_activation_fact(
        fact_definition_code,
        active_value
    );


-- ============================================================================
-- 9. RED FLAG â†’ FACT BINDING
-- ============================================================================

ALTER TABLE knowledge.symptom_red_flag
    ADD COLUMN IF NOT EXISTS fact_definition_code
    text REFERENCES clinical.fact_definition(code);

ALTER TABLE knowledge.symptom_red_flag
    ADD COLUMN IF NOT EXISTS trigger_operator
    text DEFAULT 'eq';

ALTER TABLE knowledge.symptom_red_flag
    ADD COLUMN IF NOT EXISTS trigger_value
    text;

ALTER TABLE knowledge.symptom_red_flag
    ADD COLUMN IF NOT EXISTS priority
    integer NOT NULL DEFAULT 100;

CREATE INDEX IF NOT EXISTS idx_symptom_red_flag_fact
    ON knowledge.symptom_red_flag(
        fact_definition_code,
        trigger_value
    );

CREATE INDEX IF NOT EXISTS idx_symptom_red_flag_symptom_priority
    ON knowledge.symptom_red_flag(
        symptom_id,
        priority DESC
    );


-- ============================================================================
-- 10. SYMPTOM â†’ QUESTION TARGET
-- ============================================================================
--
-- A symptom does not own questions.
--
-- Questions remain universal knowledge objects.
--
-- This junction determines which questions are relevant to the active symptom.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_question (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    question_role         text NOT NULL DEFAULT 'characterization'
                          CHECK (question_role IN (
                              'activation',
                              'characterization',
                              'chronology',
                              'severity',
                              'red_flag',
                              'associated_symptom',
                              'etiology',
                              'risk_factor',
                              'functional_impact',
                              'previous_episode',
                              'treatment',
                              'health_seeking',
                              'complication',
                              'safety',
                              'context',
                              'closing'
                          )),

    priority              integer NOT NULL DEFAULT 50,

    sequence_group        integer NOT NULL DEFAULT 1,

    is_core               boolean NOT NULL DEFAULT false,

    is_safety_critical    boolean NOT NULL DEFAULT false,

    activation_rule       jsonb,

    context_rule          jsonb,

    rationale             text,

    UNIQUE (symptom_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_symptom_question_symptom
    ON knowledge.symptom_question(
        symptom_id,
        priority DESC
    );

CREATE INDEX IF NOT EXISTS idx_symptom_question_question
    ON knowledge.symptom_question(question_id);

CREATE INDEX IF NOT EXISTS idx_symptom_question_role
    ON knowledge.symptom_question(symptom_id, question_role);


-- ============================================================================
-- 11. SYMPTOM â†’ ASSOCIATED SYMPTOM
-- ============================================================================
--
-- Universal symptom relationships.
--
-- Example:
-- cough â†’ fever
-- cough â†’ dyspnoea
-- chest pain â†’ palpitations
-- headache â†’ vomiting
--
-- No duplicate symptom records are created.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_relationship CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.symptom_relationship (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    related_symptom_id    uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    relationship_type     text NOT NULL
                          CHECK (relationship_type IN (
                              'associated',
                              'commonly_associated',
                              'may_accompany',
                              'precedes',
                              'follows',
                              'coexists',
                              'mimics',
                              'differentiates',
                              'red_flag_association',
                              'complication'
                          )),

    weight                numeric(4,3) NOT NULL DEFAULT 1.000
                          CHECK (weight >= 0 AND weight <= 1),

    priority              integer NOT NULL DEFAULT 50,

    context_rule          jsonb,

    rationale             text,

    CHECK (symptom_id <> related_symptom_id),

    UNIQUE (
        symptom_id,
        related_symptom_id,
        relationship_type
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_relationship_source
    ON knowledge.symptom_relationship(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_relationship_target
    ON knowledge.symptom_relationship(related_symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_relationship_type
    ON knowledge.symptom_relationship(
        symptom_id,
        relationship_type
    );


-- ============================================================================
-- 12. UNIVERSAL HPI DIMENSION LIBRARY
-- ============================================================================
--
-- These are reusable dimensions of symptom characterization.
--
-- The UI should NOT hardcode:
-- "every symptom gets SOCRATES".
--
-- Instead the engine activates dimensions appropriate to the symptom.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.hpi_dimension (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    dimension_code        text NOT NULL UNIQUE,

    canonical_name        text NOT NULL,

    description           text,

    sequence_no           integer NOT NULL DEFAULT 0,

    clinical_objective    text,

    status                text NOT NULL DEFAULT 'active'
                          CHECK (status IN (
                              'active',
                              'deprecated'
                          ))
);

INSERT INTO knowledge.hpi_dimension
    (
        dimension_code,
        canonical_name,
        description,
        sequence_no,
        clinical_objective
    )
VALUES
    (
        'ONSET',
        'Onset',
        'When the symptom began and whether onset was sudden, gradual or otherwise characterized.',
        10,
        'Establish temporal beginning of the presenting problem.'
    ),
    (
        'CHRONOLOGY',
        'Chronology',
        'Sequence and evolution of the symptom over time.',
        20,
        'Establish the clinical timeline.'
    ),
    (
        'SITE',
        'Site',
        'Anatomical location of the symptom.',
        30,
        'Localize the symptom.'
    ),
    (
        'RADIATION',
        'Radiation',
        'Spread or radiation from the primary site.',
        40,
        'Characterize anatomical distribution.'
    ),
    (
        'CHARACTER',
        'Character',
        'Quality or nature of the symptom.',
        50,
        'Characterize the symptom phenomenologically.'
    ),
    (
        'SEVERITY',
        'Severity',
        'Intensity or severity of the symptom.',
        60,
        'Determine severity and establish a baseline.'
    ),
    (
        'TIMING',
        'Timing',
        'Timing, frequency, periodicity and duration of episodes.',
        70,
        'Characterize temporal pattern.'
    ),
    (
        'AGGRAVATING',
        'Aggravating factors',
        'Factors that provoke or worsen the symptom.',
        80,
        'Identify symptom modifiers.'
    ),
    (
        'RELIEVING',
        'Relieving factors',
        'Factors that reduce or relieve the symptom.',
        90,
        'Identify symptom modifiers.'
    ),
    (
        'ASSOCIATED',
        'Associated symptoms',
        'Other symptoms occurring with the presenting symptom.',
        100,
        'Identify clinically relevant associated symptoms.'
    ),
    (
        'RED_FLAGS',
        'Red flags',
        'Features suggesting immediate danger or serious disease.',
        110,
        'Identify time-critical pathology.'
    ),
    (
        'ETIOLOGY',
        'Etiological context',
        'Exposure, precipitating and causal-context information.',
        120,
        'Explore potential causes without prematurely diagnosing.'
    ),
    (
        'RISK_FACTORS',
        'Risk factors',
        'Relevant predispositions and exposures.',
        130,
        'Identify factors modifying the clinical context.'
    ),
    (
        'PREVIOUS_EPISODES',
        'Previous episodes',
        'Previous occurrences and their clinical context.',
        140,
        'Determine recurrence and prior history.'
    ),
    (
        'HEALTH_SEEKING',
        'Health-seeking',
        'Prior medical evaluation, treatment and actions taken.',
        150,
        'Establish prior care and treatment exposure.'
    ),
    (
        'TREATMENT_RESPONSE',
        'Treatment response',
        'Response, non-response or adverse effects following treatment.',
        160,
        'Characterize treatment response.'
    ),
    (
        'FUNCTIONAL_IMPACT',
        'Functional impact',
        'Effect on activities, work, school, sleep, feeding and daily life.',
        170,
        'Determine effect on patient affairs and function.'
    ),
    (
        'PATIENT_CONCERN',
        'Patient perspective',
        'Patient concerns, expectations and explanatory perspective.',
        180,
        'Capture the patient perspective.'
    )
ON CONFLICT (dimension_code) DO NOTHING;


-- ============================================================================
-- 13. SYMPTOM â†’ HPI DIMENSION
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_hpi_dimension (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    dimension_code        text NOT NULL
                          REFERENCES knowledge.hpi_dimension(dimension_code),

    priority              integer NOT NULL DEFAULT 50,

    required_mode         text NOT NULL DEFAULT 'conditional'
                          CHECK (required_mode IN (
                              'always',
                              'core',
                              'conditional',
                              'optional',
                              'never'
                          )),

    activation_rule       jsonb,

    context_rule          jsonb,

    rationale             text,

    UNIQUE (symptom_id, dimension_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_dimension_symptom
    ON knowledge.symptom_hpi_dimension(
        symptom_id,
        priority DESC
    );


-- ============================================================================
-- 14. HPI QUESTION OBJECTIVE
-- ============================================================================
--
-- Makes the purpose of each question machine-readable.
--
-- A question can acquire facts while also satisfying an HPI objective.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_objective (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    objective_code        text NOT NULL
                          CHECK (objective_code IN (
                              'characterize',
                              'chronology',
                              'rule_in',
                              'rule_out',
                              'red_flag',
                              'etiology',
                              'risk_factor',
                              'complication',
                              'functional_impact',
                              'previous_episode',
                              'treatment',
                              'health_seeking',
                              'safety',
                              'context',
                              'documentation'
                          )),

    priority              integer NOT NULL DEFAULT 50,

    rationale             text,

    UNIQUE (question_id, objective_code)
);

CREATE INDEX IF NOT EXISTS idx_question_objective_question
    ON knowledge.question_objective(question_id);

CREATE INDEX IF NOT EXISTS idx_question_objective_code
    ON knowledge.question_objective(objective_code);


-- ============================================================================
-- 15. HPI QUESTION SEQUENCING
-- ============================================================================
--
-- Prevents the UI from displaying an arbitrary flat list of questions.
--
-- The CPU can construct:
--
--   safety
--      â†“
--   activation
--      â†“
--   chronology
--      â†“
--   characterization
--      â†“
--   associated symptoms
--      â†“
--   etiological context
--      â†“
--   risk factors
--      â†“
--   previous episodes
--      â†“
--   health-seeking/treatment
--      â†“
--   functional impact
--      â†“
--   closure
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.hpi_question_sequence (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    sequence_no           integer NOT NULL,

    stage_code             text NOT NULL
                           CHECK (stage_code IN (
                               'safety',
                               'activation',
                               'chronology',
                               'characterization',
                               'associated',
                               'red_flag',
                               'etiology',
                               'risk_factor',
                               'previous_episode',
                               'health_seeking',
                               'treatment',
                               'functional',
                               'closure'
                           )),

    stop_if_satisfied      boolean NOT NULL DEFAULT false,

    skip_if_known          boolean NOT NULL DEFAULT true,

    priority               integer NOT NULL DEFAULT 50,

    UNIQUE (symptom_id, question_id),

    UNIQUE (symptom_id, sequence_no)
);

CREATE INDEX IF NOT EXISTS idx_hpi_sequence_runtime
    ON knowledge.hpi_question_sequence(
        symptom_id,
        sequence_no
    );


-- ============================================================================
-- 16. QUESTION DEPENDENCY GRAPH
-- ============================================================================
--
-- Example:
--
-- "Is the chest pain exertional?"
--       â†“ YES
-- "Does it improve with rest?"
--
-- This allows adaptive questioning without hardcoded frontend logic.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_dependency CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_dependency (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_question_id    uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    child_question_id     uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    operator              text NOT NULL DEFAULT 'eq'
                          CHECK (operator IN (
                              'eq',
                              'neq',
                              'gt',
                              'gte',
                              'lt',
                              'lte',
                              'exists',
                              'not_exists',
                              'in',
                              'contains'
                          )),

    trigger_value         jsonb,

    priority              integer NOT NULL DEFAULT 50,

    rationale             text,

    UNIQUE (
        parent_question_id,
        child_question_id,
        operator,
        trigger_value
    ),

    CHECK (parent_question_id <> child_question_id)
);

CREATE INDEX IF NOT EXISTS idx_question_dependency_parent
    ON knowledge.question_dependency(parent_question_id);

CREATE INDEX IF NOT EXISTS idx_question_dependency_child
    ON knowledge.question_dependency(child_question_id);


-- ============================================================================
-- 17. QUESTION "DO NOT REPEAT" / FACT COVERAGE
-- ============================================================================
--
-- If another question has already acquired the same fact, the engine can avoid
-- asking the patient again unless clarification is required.
--
-- This is critical for a fast clinical interview.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.question_fact_coverage (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    fact_definition_code  text NOT NULL
                          REFERENCES clinical.fact_definition(code),

    coverage_type         text NOT NULL DEFAULT 'acquires'
                          CHECK (coverage_type IN (
                              'acquires',
                              'confirms',
                              'clarifies',
                              'updates',
                              'negates'
                          )),

    UNIQUE (
        question_id,
        fact_definition_code,
        coverage_type
    )
);

CREATE INDEX IF NOT EXISTS idx_question_fact_coverage_question
    ON knowledge.question_fact_coverage(question_id);

CREATE INDEX IF NOT EXISTS idx_question_fact_coverage_fact
    ON knowledge.question_fact_coverage(fact_definition_code);


-- ============================================================================
-- 18. SYMPTOM CONTEXT APPLICABILITY
-- ============================================================================
--
-- A cough is universal.
--
-- Its HPI differs according to:
--
-- neonatal
-- paediatric
-- adult
-- geriatric
-- pregnancy
-- emergency
-- outpatient
-- inpatient
--
-- We modify applicability rather than create duplicate symptoms.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_context CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.symptom_context (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    context_type_code     text NOT NULL
                          REFERENCES knowledge.context_type(code),

    context_value_id      uuid
                          REFERENCES knowledge.context_value(id),

    applicability         text NOT NULL DEFAULT 'applies'
                          CHECK (applicability IN (
                              'applies',
                              'preferred',
                              'conditional',
                              'excluded'
                          )),

    priority              integer NOT NULL DEFAULT 50,

    activation_rule       jsonb,

    documentation_rule    jsonb,

    UNIQUE (
        symptom_id,
        context_type_code,
        context_value_id
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_context_runtime
    ON knowledge.symptom_context(
        symptom_id,
        context_type_code,
        context_value_id
    );


-- ============================================================================
-- 19. SYMPTOM â†’ PHENOTYPE
-- ============================================================================
--
-- Symptoms can directly contribute to phenotype recognition.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_phenotype (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    phenotype_id          uuid NOT NULL
                          REFERENCES knowledge.phenotype(id)
                          ON DELETE CASCADE,

    weight                numeric(4,3) NOT NULL DEFAULT 1.000
                          CHECK (weight >= 0 AND weight <= 1),

    polarity              text NOT NULL DEFAULT 'positive'
                          CHECK (polarity IN (
                              'positive',
                              'negative'
                          )),

    rationale             text,

    UNIQUE (symptom_id, phenotype_id, polarity)
);

CREATE INDEX IF NOT EXISTS idx_symptom_phenotype_symptom
    ON knowledge.symptom_phenotype(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_phenotype_phenotype
    ON knowledge.symptom_phenotype(phenotype_id);


-- ============================================================================
-- 20. SYMPTOM â†’ MECHANISM
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_mechanism (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    mechanism_id          uuid NOT NULL
                          REFERENCES knowledge.mechanism(id)
                          ON DELETE CASCADE,

    weight                numeric(4,3) NOT NULL DEFAULT 1.000
                          CHECK (weight >= 0 AND weight <= 1),

    polarity              text NOT NULL DEFAULT 'positive'
                          CHECK (polarity IN (
                              'positive',
                              'negative'
                          )),

    rationale             text,

    UNIQUE (symptom_id, mechanism_id, polarity)
);

CREATE INDEX IF NOT EXISTS idx_symptom_mechanism_symptom
    ON knowledge.symptom_mechanism(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_mechanism_mechanism
    ON knowledge.symptom_mechanism(mechanism_id);


-- ============================================================================
-- 21. SYMPTOM â†’ CONDITION DIRECT ASSOCIATION
-- ============================================================================
--
-- This is not the final diagnostic engine.
--
-- It provides a knowledge-graph association which the CPU combines with:
--
-- symptoms
-- + negatives
-- + phenotype
-- + risk factors
-- + examination
-- + investigations
-- + context
-- + prevalence
-- + mechanisms
-- + contradictions
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_condition (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    condition_id          uuid NOT NULL
                          REFERENCES knowledge.condition(id)
                          ON DELETE CASCADE,

    relationship_type     text NOT NULL DEFAULT 'associated'
                          CHECK (relationship_type IN (
                              'associated',
                              'common',
                              'possible',
                              'important',
                              'must_consider',
                              'red_flag',
                              'rare'
                          )),

    weight                numeric(4,3) NOT NULL DEFAULT 1.000
                          CHECK (weight >= 0 AND weight <= 1),

    polarity              text NOT NULL DEFAULT 'positive'
                          CHECK (polarity IN (
                              'positive',
                              'negative'
                          )),

    rationale             text,

    UNIQUE (
        symptom_id,
        condition_id,
        relationship_type,
        polarity
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_condition_symptom
    ON knowledge.symptom_condition(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_condition_condition
    ON knowledge.symptom_condition(condition_id);


-- ============================================================================
-- 22. SYMPTOM DOCUMENTATION RULES
-- ============================================================================
--
-- Gives the documentation engine control over ordering and presentation.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_documentation_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    section_code          text NOT NULL
                          CHECK (section_code IN (
                              'chief_complaint',
                              'hpi',
                              'associated_symptoms',
                              'red_flags',
                              'risk_factors',
                              'functional_impact',
                              'past_history',
                              'medication_history',
                              'examination',
                              'investigation',
                              'assessment',
                              'plan'
                          )),

    rule_code             text NOT NULL,

    sequence_no           integer NOT NULL DEFAULT 0,

    condition_rule        jsonb,

    rendering_rule        jsonb,

    is_active             boolean NOT NULL DEFAULT true,

    UNIQUE (
        symptom_id,
        section_code,
        rule_code
    )
);

CREATE INDEX IF NOT EXISTS idx_symptom_documentation_runtime
    ON knowledge.symptom_documentation_rule(
        symptom_id,
        section_code,
        sequence_no
    );


-- ============================================================================
-- 23. UNIVERSAL SYMPTOM HPI OBJECTIVES
-- ============================================================================
--
-- Explicitly encode the HPI purpose so the engine knows why it is collecting
-- information.
--
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.hpi_objective CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.hpi_objective (
    objective_code       text PRIMARY KEY,
    canonical_name       text NOT NULL,
    description          text NOT NULL,
    sequence_no          integer NOT NULL,
    is_core              boolean NOT NULL DEFAULT true
);

INSERT INTO knowledge.hpi_objective
    (
        objective_code,
        canonical_name,
        description,
        sequence_no,
        is_core
    )
VALUES
    (
        'CHARACTERIZE',
        'Characterize the presenting symptom',
        'Establish the nature, site, character, severity, timing, aggravating and relieving factors of the presenting symptom.',
        10,
        true
    ),
    (
        'CHRONOLOGY',
        'Establish chronology',
        'Establish onset, progression, evolution, recurrence and temporal relationships.',
        20,
        true
    ),
    (
        'ASSOCIATED',
        'Explore associated symptoms',
        'Identify clinically relevant positive and negative associated symptoms.',
        30,
        true
    ),
    (
        'RULE_IN_OUT',
        'Explore diagnostic discriminators',
        'Collect relevant clinical information that supports or argues against important diagnostic possibilities without documenting a diagnosis as fact.',
        40,
        true
    ),
    (
        'ETIOLOGY',
        'Explore etiological context',
        'Identify exposures, precipitants and contextual factors relevant to possible causes.',
        50,
        true
    ),
    (
        'RISK',
        'Identify risk factors',
        'Identify demographic, environmental, medical, medication, exposure, family and other risk factors.',
        60,
        true
    ),
    (
        'COMPLICATION',
        'Identify complications',
        'Identify symptoms or circumstances suggesting complications or deterioration.',
        70,
        true
    ),
    (
        'SAFETY',
        'Establish treatment safety context',
        'Capture allergies, pregnancy, organ function, medications and other information that affects safe clinical action.',
        80,
        true
    ),
    (
        'PREVIOUS',
        'Explore previous episodes',
        'Establish whether the problem has occurred previously and what happened during previous episodes.',
        90,
        true
    ),
    (
        'HEALTH_SEEKING',
        'Establish health-seeking history',
        'Establish previous consultations, investigations, treatment and response.',
        100,
        true
    ),
    (
        'FUNCTION',
        'Assess functional impact',
        'Determine effect on activities of daily living, work, school, sleep, feeding and other patient affairs.',
        110,
        true
    ),
    (
        'PATIENT_PERSPECTIVE',
        'Capture patient perspective',
        'Capture concerns, ideas, expectations and priorities when appropriate.',
        120,
        true
    )
ON CONFLICT (objective_code) DO NOTHING;


-- ============================================================================
-- 24. SYMPTOM â†’ HPI OBJECTIVE
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_hpi_objective (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    objective_code        text NOT NULL
                          REFERENCES knowledge.hpi_objective(objective_code),

    priority              integer NOT NULL DEFAULT 50,

    required_mode         text NOT NULL DEFAULT 'conditional'
                          CHECK (required_mode IN (
                              'always',
                              'core',
                              'conditional',
                              'optional'
                          )),

    activation_rule       jsonb,

    context_rule          jsonb,

    UNIQUE (symptom_id, objective_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_objective_runtime
    ON knowledge.symptom_hpi_objective(
        symptom_id,
        priority DESC
    );


-- ============================================================================
-- 25. HPI COMPLETENESS RULE
-- ============================================================================
--
-- Allows the CPU/UI to determine whether an HPI thread has enough information
-- to close, while distinguishing:
--
--   answered
--   explicitly negative
--   not applicable
--   unknown
--   refused
--   missing
--
-- It must NEVER interpret missing as negative.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_hpi_completion_rule (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    objective_code        text
                          REFERENCES knowledge.hpi_objective(objective_code),

    minimum_facts         jsonb NOT NULL DEFAULT '[]'::jsonb,

    blocking_red_flags    jsonb NOT NULL DEFAULT '[]'::jsonb,

    completion_expression jsonb,

    priority              integer NOT NULL DEFAULT 50,

    UNIQUE (symptom_id, objective_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_completion
    ON knowledge.symptom_hpi_completion_rule(symptom_id);


-- ============================================================================
-- 26. HPI THREAD CONFIGURATION
-- ============================================================================
--
-- Controls how aggressively the adaptive engine asks questions.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.symptom_hpi_config (
    symptom_id                 uuid PRIMARY KEY
                               REFERENCES knowledge.symptom(id)
                               ON DELETE CASCADE,

    max_questions               integer NOT NULL DEFAULT 100
                                CHECK (max_questions > 0),

    stop_when_core_complete     boolean NOT NULL DEFAULT true,

    prioritize_safety           boolean NOT NULL DEFAULT true,

    prioritize_red_flags        boolean NOT NULL DEFAULT true,

    avoid_repeated_facts        boolean NOT NULL DEFAULT true,

    ask_negatives_when_relevant boolean NOT NULL DEFAULT true,

    allow_patient_skip          boolean NOT NULL DEFAULT true,

    allow_unknown               boolean NOT NULL DEFAULT true,

    generate_documentation      boolean NOT NULL DEFAULT true,

    adaptive_mode               text NOT NULL DEFAULT 'adaptive'
                                CHECK (adaptive_mode IN (
                                    'fixed',
                                    'adaptive',
                                    'minimal',
                                    'comprehensive'
                                )),

    updated_at                  timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
-- 27. UPDATE TIMESTAMP TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS trg_symptom_risk_factor_updated_at
    ON knowledge.symptom_risk_factor;

CREATE TRIGGER trg_symptom_risk_factor_updated_at
    BEFORE UPDATE ON knowledge.symptom_risk_factor
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_symptom_etiology_updated_at
    ON knowledge.symptom_etiology;

CREATE TRIGGER trg_symptom_etiology_updated_at
    BEFORE UPDATE ON knowledge.symptom_etiology
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_symptom_hpi_template_updated_at
    ON knowledge.symptom_hpi_template;

CREATE TRIGGER trg_symptom_hpi_template_updated_at
    BEFORE UPDATE ON knowledge.symptom_hpi_template
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_symptom_hpi_config_updated_at
    ON knowledge.symptom_hpi_config;

CREATE TRIGGER trg_symptom_hpi_config_updated_at
    BEFORE UPDATE ON knowledge.symptom_hpi_config
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 28. FAST RUNTIME VIEWS
-- ============================================================================
--
-- These views provide deterministic lookup surfaces for the CPU.
--
-- ============================================================================

CREATE OR REPLACE VIEW knowledge.symptom_hpi_runtime AS
SELECT
    s.id AS symptom_id,
    s.symptom_code,
    s.canonical_name,

    hdim.dimension_code,
    hdim.canonical_name AS dimension_name,

    shd.priority,
    shd.required_mode,
    shd.activation_rule,
    shd.context_rule,

    q.id AS question_id,
    q.question_code,

    sq.question_role,
    sq.is_core,
    sq.is_safety_critical

FROM knowledge.symptom s

JOIN knowledge.symptom_hpi_dimension shd
    ON shd.symptom_id = s.id

JOIN knowledge.hpi_dimension hdim
    ON hdim.dimension_code = shd.dimension_code

LEFT JOIN knowledge.symptom_question sq
    ON sq.symptom_id = s.id

LEFT JOIN knowledge.question q
    ON q.id = sq.question_id

WHERE s.status = 'active'
  AND hdim.status = 'active';


COMMENT ON VIEW knowledge.symptom_hpi_runtime IS
'Runtime HPI graph: active symptom â†’ HPI dimensions â†’ applicable questions.';


CREATE OR REPLACE VIEW knowledge.symptom_clinical_runtime AS
SELECT
    s.id AS symptom_id,
    s.symptom_code,
    s.canonical_name,

    sr.risk_factor_code,
    se.etiology_code,
    sc.complication_code,
    sex.finding_code,
    sit.investigation_code

FROM knowledge.symptom s

LEFT JOIN knowledge.symptom_risk_factor sr
    ON sr.symptom_id = s.id

LEFT JOIN knowledge.symptom_etiology se
    ON se.symptom_id = s.id

LEFT JOIN knowledge.symptom_complication sc
    ON sc.symptom_id = s.id

LEFT JOIN knowledge.symptom_examination_target sex
    ON sex.symptom_id = s.id

LEFT JOIN knowledge.symptom_investigation_target sit
    ON sit.symptom_id = s.id

WHERE s.status = 'active';


COMMENT ON VIEW knowledge.symptom_clinical_runtime IS
'Universal symptom runtime graph used by the clinical CPU for rapid downstream expansion.';


-- ============================================================================
-- 29. UNIVERSAL SYMPTOM SEARCH INDEXES
-- ============================================================================
--
-- These indexes optimize the hot path:
--
-- presenting symptom â†’ knowledge expansion
--
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_symptom_active_code
    ON knowledge.symptom(symptom_code)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_symptom_active_id
    ON knowledge.symptom(id)
    WHERE status = 'active';


CREATE INDEX IF NOT EXISTS idx_symptom_question_core
    ON knowledge.symptom_question(
        symptom_id,
        is_core,
        priority DESC
    );

CREATE INDEX IF NOT EXISTS idx_symptom_redflag_runtime
    ON knowledge.symptom_red_flag(
        symptom_id,
        priority DESC,
        fact_definition_code
    );

CREATE INDEX IF NOT EXISTS idx_symptom_exam_runtime
    ON knowledge.symptom_examination_target(
        symptom_id,
        priority DESC
    );

CREATE INDEX IF NOT EXISTS idx_symptom_investigation_runtime
    ON knowledge.symptom_investigation_target(
        symptom_id,
        priority DESC
    );

CREATE INDEX IF NOT EXISTS idx_symptom_relationship_runtime
    ON knowledge.symptom_relationship(
        symptom_id,
        relationship_type,
        priority DESC
    );


-- ============================================================================
-- 30. UNIVERSAL CLINICAL SAFETY QUESTION PRIORITY
-- ============================================================================
--
-- Safety information is not merely another HPI category.
-- The CPU must be able to elevate safety questions globally.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.hpi_safety_priority (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    safety_domain         text NOT NULL
                          CHECK (safety_domain IN (
                              'allergy',
                              'pregnancy',
                              'renal',
                              'hepatic',
                              'medication',
                              'anticoagulation',
                              'immunosuppression',
                              'infection_control',
                              'paediatric',
                              'geriatric',
                              'other'
                          )),

    priority              integer NOT NULL DEFAULT 100,

    blocking              boolean NOT NULL DEFAULT false,

    rationale             text,

    UNIQUE (question_id, safety_domain)
);

CREATE INDEX IF NOT EXISTS idx_hpi_safety_priority_runtime
    ON knowledge.hpi_safety_priority(
        safety_domain,
        priority DESC
    );


-- ============================================================================
-- 31. UNIVERSAL CLINICAL NEGATIVE / POSITIVE SEMANTICS
-- ============================================================================
--
-- A clinically intelligent system must distinguish:
--
-- YES
-- NO
-- UNKNOWN
-- NOT ASKED
-- NOT APPLICABLE
-- REFUSED
-- UNABLE TO OBTAIN
--
-- This is intentionally a knowledge-layer contract for the UI/CPU.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_answer_semantics (
    semantic_code       text PRIMARY KEY,
    canonical_name      text NOT NULL,
    clinical_meaning    text NOT NULL,
    contributes_fact    boolean NOT NULL DEFAULT true,
    is_negative         boolean NOT NULL DEFAULT false,
    is_missing          boolean NOT NULL DEFAULT false
);

INSERT INTO knowledge.clinical_answer_semantics
    (
        semantic_code,
        canonical_name,
        clinical_meaning,
        contributes_fact,
        is_negative,
        is_missing
    )
VALUES
    (
        'YES',
        'Yes',
        'The patient affirms the feature.',
        true,
        false,
        false
    ),
    (
        'NO',
        'No',
        'The patient explicitly denies the feature.',
        true,
        true,
        false
    ),
    (
        'UNKNOWN',
        'Unknown',
        'The patient does not know or cannot establish the answer.',
        false,
        false,
        true
    ),
    (
        'NOT_ASKED',
        'Not asked',
        'The system has not collected the information.',
        false,
        false,
        true
    ),
    (
        'NOT_APPLICABLE',
        'Not applicable',
        'The question does not apply in this clinical context.',
        false,
        false,
        true
    ),
    (
        'REFUSED',
        'Refused',
        'The patient declined to provide the information.',
        false,
        false,
        true
    ),
    (
        'UNABLE_TO_OBTAIN',
        'Unable to obtain',
        'The information could not be obtained.',
        false,
        false,
        true
    )
ON CONFLICT (semantic_code) DO NOTHING;


-- ============================================================================
-- 32. UNIVERSAL CLINICAL INTERVIEW PRINCIPLES
-- ============================================================================
--
-- Machine-readable rules governing the HPI engine.
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.hpi_engine_rule (
    rule_code           text PRIMARY KEY,

    canonical_name      text NOT NULL,

    description         text NOT NULL,

    priority             integer NOT NULL DEFAULT 50,

    config               jsonb NOT NULL DEFAULT '{}'::jsonb,

    is_active            boolean NOT NULL DEFAULT true
);

INSERT INTO knowledge.hpi_engine_rule
    (
        rule_code,
        canonical_name,
        description,
        priority,
        config
    )
VALUES
    (
        'NO_DIAGNOSTIC_DEDUCTION_IN_HPI',
        'No diagnostic deduction during HPI',
        'The HPI documentation layer records patient-reported and observed facts without converting them into diagnostic conclusions.',
        1000,
        '{"allow_diagnosis_language":false,"allow_inference":false}'::jsonb
    ),
    (
        'DO_NOT_REPEAT_ACQUIRED_FACT',
        'Do not repeat acquired facts',
        'Do not ask a question when its required fact has already been adequately acquired unless clarification or confirmation is explicitly required.',
        900,
        '{"repeat_if":"clarification_required"}'::jsonb
    ),
    (
        'RED_FLAGS_BEFORE_ROUTINE_EXPANSION',
        'Prioritize red flags',
        'Safety-critical and red-flag questions take precedence over routine characterization when triggered.',
        1000,
        '{"red_flag_priority_boost":1000}'::jsonb
    ),
    (
        'MISSING_IS_NOT_NEGATIVE',
        'Missing is not negative',
        'Absence of a captured fact must never be interpreted as absence of the clinical feature.',
        1000,
        '{"missing_equals_negative":false}'::jsonb
    ),
    (
        'CONTEXT_MODIFIES_NOT_DUPLICATES',
        'Context modifies universal knowledge',
        'Age, sex, pregnancy, specialty and encounter context modify applicability of universal knowledge rather than creating duplicate symptom objects.',
        950,
        '{"duplicate_symptoms":false}'::jsonb
    ),
    (
        'FACTS_FEED_SINGLE_REASONING_SUBSTRATE',
        'History and examination share one fact substrate',
        'Facts acquired through history, examination, monitoring and investigation results must enter the same clinical reasoning substrate.',
        950,
        '{"shared_fact_substrate":true}'::jsonb
    ),
    (
        'SAFETY_BEFORE_TREATMENT',
        'Safety precedes treatment',
        'Treatment recommendations must be checked against allergy, pregnancy, renal, hepatic, medication and other applicable safety factors.',
        1000,
        '{"require_safety_evaluation":true}'::jsonb
    )
ON CONFLICT (rule_code) DO NOTHING;


-- ============================================================================
-- 33. COMMENTS â€” ARCHITECTURAL CONTRACT
-- ============================================================================

COMMENT ON TABLE knowledge.symptom_relationship IS
'Universal symptom-to-symptom graph. One symptom may relate to many symptoms without duplication.';

COMMENT ON TABLE knowledge.symptom_question IS
'Maps universal questions to an active symptom thread. Questions remain reusable across symptoms and specialties.';

COMMENT ON TABLE knowledge.symptom_hpi_dimension IS
'Controls which dimensions of HPI characterization are applicable to a symptom.';

COMMENT ON TABLE knowledge.question_dependency IS
'Adaptive interview dependency graph. A child question is activated by an answer to its parent question.';

COMMENT ON TABLE knowledge.question_fact_coverage IS
'Prevents unnecessary repetition by declaring which clinical facts a question can acquire, confirm, clarify or update.';

COMMENT ON TABLE knowledge.symptom_context IS
'Context-specific applicability for universal symptoms. Context modifies the pathway without duplicating the symptom.';

COMMENT ON TABLE knowledge.hpi_objective IS
'Universal objectives of clinical history taking.';

COMMENT ON TABLE knowledge.symptom_hpi_objective IS
'Maps each symptom to the HPI objectives that must be satisfied.';

COMMENT ON TABLE knowledge.symptom_hpi_completion_rule IS
'Determines whether an active symptom history has sufficient captured information to close the HPI thread.';

COMMENT ON TABLE knowledge.hpi_engine_rule IS
'Global machine-readable rules governing safe, factual and non-redundant HPI operation.';


COMMIT;


-- =============================================================================
-- RESULTING AMEXAN CLINICAL FLOW
-- =============================================================================
--
--                     PATIENT / CLINICIAN
--                             â”‚
--                             â–¼
--                     CHIEF COMPLAINT
--                             â”‚
--                             â–¼
--                    UNIVERSAL SYMPTOM
--                             â”‚
--              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--              â”‚              â”‚              â”‚
--              â–¼              â–¼              â–¼
--          CONTEXT         SAFETY        RED FLAGS
--              â”‚              â”‚              â”‚
--              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                             â–¼
--                     HPI OBJECTIVES
--                             â”‚
--                             â–¼
--                  HPI DIMENSION ENGINE
--                             â”‚
--        â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--        â”‚                    â”‚                    â”‚
--        â–¼                    â–¼                    â–¼
--     ONSET              CHARACTER             SEVERITY
--     SITE               RADIATION             TIMING
--     AGGRAVATING        RELIEVING             ASSOCIATED
--        â”‚                    â”‚                    â”‚
--        â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                             â–¼
--                     FACT ACQUISITION
--                             â”‚
--              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--              â–¼              â–¼              â–¼
--          POSITIVE        NEGATIVE       UNKNOWN
--              â”‚              â”‚              â”‚
--              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                             â–¼
--                    SAME FACT SUBSTRATE
--                             â”‚
--          â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--          â–¼                  â–¼                  â–¼
--       HISTORY           EXAMINATION       INVESTIGATION
--          â”‚                  â”‚                  â”‚
--          â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                             â–¼
--                         PHENOTYPE
--                             â”‚
--                         MECHANISM
--                             â”‚
--                       DIFFERENTIAL
--                             â”‚
--                         CONDITION
--                             â”‚
--               â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--               â–¼             â–¼             â–¼
--           INVESTIGATE    MANAGEMENT     MONITOR
--               â”‚             â”‚             â”‚
--               â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                             â–¼
--                         EDUCATION
--                             â”‚
--                         FOLLOW-UP
--                             â”‚
--                             â–¼
--                     CLINICIAN DECISION
--                             â”‚
--                             â–¼
--                       CPU AUDIT LEDGER
--
-- =============================================================================
-- CRITICAL DESIGN PROPERTY
-- =============================================================================
--
-- Cough is ONE object.
--
-- It can simultaneously participate in:
--
--   respiratory medicine
--   cardiology
--   gastroenterology
--   ENT
--   paediatrics
--   emergency medicine
--   infectious disease
--   oncology
--   surgery
--   critical care
--
-- without creating:
--
--   RESPIRATORY_COUGH
--   CARDIAC_COUGH
--   PAEDIATRIC_COUGH
--   ENT_COUGH
--
-- Instead:
--
--                    CNS-COUGH
--                       â”‚
--        â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--        â–¼              â–¼                 â–¼
--     CONTEXT         SYSTEM           SPECIALTY
--        â”‚              â”‚                 â”‚
--     child          respiratory       paediatrics
--     adult          cardiac           medicine
--     pregnancy      GI                emergency
--     elderly        ENT               surgery
--
-- The same universal clinical truth is reused everywhere.
--
-- This is the substrate that allows AMEXAN to behave as a
-- UNIVERSAL CLINICAL OPERATING SYSTEM rather than a collection of
-- disease-specific forms.
-- =============================================================================
