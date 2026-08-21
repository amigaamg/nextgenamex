-- =============================================================================
-- AMEXAN Phase 4 — Migration 021
-- UNIVERSAL QUESTION → FACT ACQUISITION LAYER
-- =============================================================================
-- Clinical Operating System principle:
--
--   QUESTION
--      ↓
--   RESPONSE
--      ↓
--   NORMALIZATION / VALIDATION
--      ↓
--   FACT
--      ↓
--   PHENOTYPE / MECHANISM / DIFFERENTIAL / SAFETY / PROTOCOL
--
-- Choice questions use:
--
--   question
--      → answer_option
--      → fact_mapping
--      → clinical.fact_definition
--
-- Typed questions use:
--
--   question
--      → question_fact
--      → clinical.fact_definition
--
-- The UI never becomes the reasoning engine.
-- The answer is converted into universal clinical truth.
--
-- This migration also hardens:
--   • numeric questions
--   • text questions
--   • date questions
--   • duration units
--   • coded raw values
--   • source/provenance
--   • multiplicity
--   • validation metadata
--   • normalization metadata
--   • question completeness
--   • existing CHEST_PAIN_RADIATION mappings
--
-- No disease owns a fact.
-- No specialty owns a fact.
-- No question owns a fact.
-- Questions acquire universal facts.
-- =============================================================================


-- =============================================================================
-- 1. UNIVERSAL DURATION UNITS
-- =============================================================================

INSERT INTO terminology.unit
    (code, label, dimension, symbol, si_unit_code)
VALUES
    ('second', 'second', 'duration', 's', NULL),
    ('seconds', 'seconds', 'duration', 's', NULL),
    ('minute', 'minute', 'duration', 'min', NULL),
    ('minutes', 'minutes', 'duration', 'min', NULL),
    ('hour', 'hour', 'duration', 'h', NULL),
    ('hours', 'hours', 'duration', 'h', NULL),
    ('day', 'day', 'duration', 'd', NULL),
    ('days', 'days', 'duration', 'd', NULL),
    ('week', 'week', 'duration', 'wk', NULL),
    ('weeks', 'weeks', 'duration', 'wk', NULL),
    ('month', 'month', 'duration', 'mo', NULL),
    ('months', 'months', 'duration', 'mo', NULL),
    ('year', 'year', 'duration', 'yr', NULL),
    ('years', 'years', 'duration', 'yr', NULL)
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 2. QUESTION → FACT BINDING
-- =============================================================================
-- A typed question directly acquires a fact.
--
-- Examples:
--   COUGH_DURATION      → COUGH_DURATION_DAYS
--   FEVER_ONSET_DATE    → FEVER_ONSET_DATE
--   WEIGHT              → WEIGHT
--   CHEST_PAIN_SCORE    → CHEST_PAIN_SEVERITY
--
-- The question remains an acquisition mechanism.
-- The fact remains the reusable clinical truth.
-- =============================================================================

CREATE TABLE knowledge.question_fact (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    fact_definition_code  text NOT NULL
                          REFERENCES clinical.fact_definition(code),

    unit_code             text
                          REFERENCES terminology.unit(code),

    -- Optional transformation performed by the ingestion layer.
    -- This is metadata for the fact-ingestion runtime, NOT clinical reasoning.
    normalization         jsonb NOT NULL DEFAULT '{}'::jsonb,

    -- Optional validation constraints consumed before fact creation.
    validation             jsonb NOT NULL DEFAULT '{}'::jsonb,

    -- Whether this binding is currently available to the acquisition engine.
    is_active              boolean NOT NULL DEFAULT true,

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),

    UNIQUE (question_id, fact_definition_code)
);

COMMENT ON TABLE knowledge.question_fact IS
'Universal typed-question → clinical-fact binding. Converts numeric, text, date and other raw responses into reusable clinical facts.';

COMMENT ON COLUMN knowledge.question_fact.normalization IS
'Machine-readable normalization metadata such as unit conversion, case normalization or coded-value normalization. Must not contain diagnostic reasoning.';

COMMENT ON COLUMN knowledge.question_fact.validation IS
'Machine-readable input validation constraints such as minimum, maximum, allowed precision or format. Validation prevents malformed observations from becoming clinical facts.';

CREATE INDEX idx_knowledge_question_fact_question
    ON knowledge.question_fact(question_id);

CREATE INDEX idx_knowledge_question_fact_fact
    ON knowledge.question_fact(fact_definition_code);

CREATE INDEX idx_knowledge_question_fact_active
    ON knowledge.question_fact(is_active);

CREATE TRIGGER trg_knowledge_question_fact_updated_at
    BEFORE UPDATE ON knowledge.question_fact
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. QUESTION → FACT VALIDATION
-- =============================================================================
-- Explicit validation rules make the acquisition layer safe for clinical data.
--
-- Examples:
--   COUGH_DURATION_DAYS >= 0
--   AGE_YEARS >= 0
--   WEIGHT_KG > 0
--
-- These constraints validate data.
-- They do NOT diagnose disease.
-- =============================================================================

CREATE TABLE knowledge.question_fact_validation (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_fact_id      uuid NOT NULL
                          REFERENCES knowledge.question_fact(id)
                          ON DELETE CASCADE,

    validation_type       text NOT NULL
                          CHECK (
                              validation_type IN (
                                  'min',
                                  'max',
                                  'exclusive_min',
                                  'exclusive_max',
                                  'regex',
                                  'allowed_values',
                                  'decimal_places',
                                  'length_min',
                                  'length_max'
                              )
                          ),

    validation_value      jsonb NOT NULL,

    error_message         text,

    priority              integer NOT NULL DEFAULT 0,

    is_active             boolean NOT NULL DEFAULT true,

    UNIQUE (
        question_fact_id,
        validation_type,
        priority
    )
);

COMMENT ON TABLE knowledge.question_fact_validation IS
'Input validation rules applied before a typed response becomes a clinical fact.';


CREATE INDEX idx_question_fact_validation_binding
    ON knowledge.question_fact_validation(question_fact_id);


-- =============================================================================
-- 4. QUESTION → FACT NORMALIZATION
-- =============================================================================
-- Normalization is deliberately separate from validation.
--
-- Example:
--
--   "3 days" → 3
--   "3 d"    → 3
--   "Three"  → normalized numeric 3
--
-- or:
--
--   "YES" → TRUE
--   "yes" → TRUE
--
-- The normalized value is still an observation.
-- =============================================================================

CREATE TABLE knowledge.question_fact_normalization (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_fact_id      uuid NOT NULL
                          REFERENCES knowledge.question_fact(id)
                          ON DELETE CASCADE,

    normalization_type    text NOT NULL
                          CHECK (
                              normalization_type IN (
                                  'unit_conversion',
                                  'case_normalization',
                                  'trim',
                                  'whitespace_normalization',
                                  'coded_alias',
                                  'date_normalization',
                                  'numeric_normalization',
                                  'text_normalization'
                              )
                          ),

    configuration         jsonb NOT NULL DEFAULT '{}'::jsonb,

    priority              integer NOT NULL DEFAULT 0,

    is_active             boolean NOT NULL DEFAULT true,

    UNIQUE (
        question_fact_id,
        normalization_type,
        priority
    )
);

COMMENT ON TABLE knowledge.question_fact_normalization IS
'Deterministic normalization metadata used to transform raw user input into canonical fact values.';


CREATE INDEX idx_question_fact_normalization_binding
    ON knowledge.question_fact_normalization(question_fact_id);


-- =============================================================================
-- 5. RAW RESPONSE TYPE HARDENING
-- =============================================================================
-- Every typed question must have a compatible fact data type.
--
-- This does not alter question.response_type.
-- It gives the CPU an explicit semantic contract.
-- =============================================================================

CREATE TABLE knowledge.question_fact_type (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_fact_id      uuid NOT NULL
                          REFERENCES knowledge.question_fact(id)
                          ON DELETE CASCADE,

    accepted_response_type text NOT NULL
                           CHECK (
                               accepted_response_type IN (
                                   'numeric',
                                   'text',
                                   'date',
                                   'boolean',
                                   'single_choice',
                                   'multiple_choice'
                               )
                           ),

    is_primary             boolean NOT NULL DEFAULT true,

    UNIQUE (
        question_fact_id,
        accepted_response_type
    )
);

COMMENT ON TABLE knowledge.question_fact_type IS
'Explicit response-type contract between the acquisition question and the fact it creates.';


-- =============================================================================
-- 6. FACT ACQUISITION SEMANTICS
-- =============================================================================
-- A question may acquire:
--
--   one fact
--   many facts
--   a fact with a scalar value
--   a fact with a coded value
--   a fact with a measurement unit
--
-- These semantics allow the runtime to remain generic.
-- =============================================================================

CREATE TABLE knowledge.question_fact_semantics (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_fact_id      uuid NOT NULL
                          REFERENCES knowledge.question_fact(id)
                          ON DELETE CASCADE,

    cardinality           text NOT NULL DEFAULT 'single'
                           CHECK (
                               cardinality IN (
                                   'single',
                                   'multiple'
                               )
                           ),

    value_semantics       text NOT NULL DEFAULT 'scalar'
                           CHECK (
                               value_semantics IN (
                                   'scalar',
                                   'coded',
                                   'text',
                                   'numeric',
                                   'boolean',
                                   'date',
                                   'datetime',
                                   'measurement'
                               )
                           ),

    required_for_answer   boolean NOT NULL DEFAULT false,

    UNIQUE (question_fact_id)
);

COMMENT ON TABLE knowledge.question_fact_semantics IS
'Defines how a typed response becomes a clinical fact without embedding clinical reasoning in the UI.';


-- =============================================================================
-- 7. UNIVERSAL FACT: COUGH DURATION
-- =============================================================================
-- Only create the fact if the universal vocabulary does not already contain it.
-- =============================================================================

INSERT INTO clinical.fact_definition
    (
        code,
        name,
        description,
        data_type,
        allow_multiple,
        is_active
    )
VALUES
    (
        'COUGH_DURATION_DAYS',
        'Cough duration',
        'Duration of cough expressed in days from onset to the documented observation.',
        'numeric',
        false,
        true
    )
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 8. COUGH DURATION → FACT
-- =============================================================================

INSERT INTO knowledge.question_fact
    (
        question_id,
        fact_definition_code,
        unit_code,
        normalization,
        validation,
        is_active
    )
SELECT
    q.id,
    'COUGH_DURATION_DAYS',
    'days',
    jsonb_build_object(
        'canonical_unit', 'days',
        'source_unit_dimension', 'duration'
    ),
    jsonb_build_object(
        'minimum', 0,
        'allow_negative', false
    ),
    true
FROM knowledge.question q
WHERE q.question_code = 'COUGH_DURATION'
ON CONFLICT (question_id, fact_definition_code)
DO UPDATE SET
    unit_code = EXCLUDED.unit_code,
    normalization = EXCLUDED.normalization,
    validation = EXCLUDED.validation,
    is_active = true;


-- =============================================================================
-- 9. COUGH DURATION RESPONSE CONTRACT
-- =============================================================================

INSERT INTO knowledge.question_fact_type
    (
        question_fact_id,
        accepted_response_type,
        is_primary
    )
SELECT
    qf.id,
    'numeric',
    true
FROM knowledge.question_fact qf
JOIN knowledge.question q
    ON q.id = qf.question_id
WHERE q.question_code = 'COUGH_DURATION'
  AND qf.fact_definition_code = 'COUGH_DURATION_DAYS'
ON CONFLICT (question_fact_id, accepted_response_type)
DO NOTHING;


INSERT INTO knowledge.question_fact_semantics
    (
        question_fact_id,
        cardinality,
        value_semantics,
        required_for_answer
    )
SELECT
    qf.id,
    'single',
    'measurement',
    true
FROM knowledge.question_fact qf
JOIN knowledge.question q
    ON q.id = qf.question_id
WHERE q.question_code = 'COUGH_DURATION'
  AND qf.fact_definition_code = 'COUGH_DURATION_DAYS'
ON CONFLICT (question_fact_id)
DO UPDATE SET
    cardinality = EXCLUDED.cardinality,
    value_semantics = EXCLUDED.value_semantics,
    required_for_answer = EXCLUDED.required_for_answer;


-- =============================================================================
-- 10. COUGH DURATION VALIDATION
-- =============================================================================

INSERT INTO knowledge.question_fact_validation
    (
        question_fact_id,
        validation_type,
        validation_value,
        error_message,
        priority
    )
SELECT
    qf.id,
    'min',
    '0'::jsonb,
    'Duration cannot be negative.',
    10
FROM knowledge.question_fact qf
JOIN knowledge.question q
    ON q.id = qf.question_id
WHERE q.question_code = 'COUGH_DURATION'
  AND qf.fact_definition_code = 'COUGH_DURATION_DAYS'
ON CONFLICT (
    question_fact_id,
    validation_type,
    priority
)
DO UPDATE SET
    validation_value = EXCLUDED.validation_value,
    error_message = EXCLUDED.error_message;


-- =============================================================================
-- 11. UNIVERSAL CHEST-PAIN-RADIATION FACT
-- =============================================================================

INSERT INTO clinical.fact_definition
    (
        code,
        name,
        data_type,
        description,
        allow_multiple,
        is_active
    )
VALUES
    (
        'CHEST_PAIN_RADIATION',
        'Chest pain radiation',
        'coded',
        'Anatomical location or locations to which chest pain radiates.',
        true,
        true
    )
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    data_type = EXCLUDED.data_type,
    description = EXCLUDED.description,
    allow_multiple = EXCLUDED.allow_multiple,
    is_active = true;


-- =============================================================================
-- 12. CHEST PAIN RADIATION → FACT
-- =============================================================================
-- Existing answer options become structured medical truth.
--
-- value_text is retained as the source value.
-- answer_code remains the stable UI-independent option identity.
-- =============================================================================

INSERT INTO knowledge.fact_mapping
    (
        answer_option_id,
        fact_definition_code,
        value,
        is_active
    )
SELECT
    ao.id,
    'CHEST_PAIN_RADIATION',
    COALESCE(NULLIF(ao.value_text, ''), ao.answer_code),
    true
FROM knowledge.answer_option ao
JOIN knowledge.question q
    ON q.id = ao.question_id
WHERE q.question_code = 'CHEST_PAIN_RADIATION'
ON CONFLICT (
    answer_option_id,
    fact_definition_code,
    value
)
DO UPDATE SET
    is_active = true;


-- =============================================================================
-- 13. CHEST PAIN RADIATION SEMANTICS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.answer_fact_semantics (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    answer_option_id      uuid NOT NULL
                          REFERENCES knowledge.answer_option(id)
                          ON DELETE CASCADE,

    fact_definition_code  text NOT NULL
                          REFERENCES clinical.fact_definition(code),

    semantic_role         text NOT NULL DEFAULT 'establishes'
                          CHECK (
                              semantic_role IN (
                                  'establishes',
                                  'contradicts',
                                  'qualifies',
                                  'modifies'
                              )
                          ),

    confidence             numeric(4,3)
                           CHECK (
                               confidence IS NULL
                               OR (
                                   confidence >= 0
                                   AND confidence <= 1
                               )
                           ),

    UNIQUE (
        answer_option_id,
        fact_definition_code,
        semantic_role
    )
);

COMMENT ON TABLE knowledge.answer_fact_semantics IS
'Defines how an answer-option mapping contributes to a clinical fact.';


INSERT INTO knowledge.answer_fact_semantics
    (
        answer_option_id,
        fact_definition_code,
        semantic_role,
        confidence
    )
SELECT
    ao.id,
    'CHEST_PAIN_RADIATION',
    'establishes',
    1.0
FROM knowledge.answer_option ao
JOIN knowledge.question q
    ON q.id = ao.question_id
JOIN knowledge.fact_mapping fm
    ON fm.answer_option_id = ao.id
   AND fm.fact_definition_code = 'CHEST_PAIN_RADIATION'
WHERE q.question_code = 'CHEST_PAIN_RADIATION'
ON CONFLICT (
    answer_option_id,
    fact_definition_code,
    semantic_role
)
DO NOTHING;


-- =============================================================================
-- 14. RAW QUESTION FACTS FOR COMMON CLINICAL DATA TYPES
-- =============================================================================
-- These are generic infrastructure bindings only.
-- Existing questions are bound if their corresponding fact definition exists.
--
-- No invented disease-specific facts are created here.
-- =============================================================================

INSERT INTO knowledge.question_fact
    (
        question_id,
        fact_definition_code,
        unit_code,
        is_active
    )
SELECT
    q.id,
    fd.code,
    NULL,
    true
FROM knowledge.question q
JOIN clinical.fact_definition fd
    ON fd.code = q.question_code
WHERE q.response_type IN ('numeric', 'text', 'date')
  AND NOT EXISTS (
      SELECT 1
      FROM knowledge.fact_mapping fm
      JOIN knowledge.answer_option ao
        ON ao.id = fm.answer_option_id
      WHERE ao.question_id = q.id
  )
  AND NOT EXISTS (
      SELECT 1
      FROM knowledge.question_fact qf
      WHERE qf.question_id = q.id
        AND qf.fact_definition_code = fd.code
  )
ON CONFLICT (question_id, fact_definition_code)
DO NOTHING;


-- =============================================================================
-- 15. RESPONSE TYPE CONTRACTS FOR EXISTING TYPED QUESTIONS
-- =============================================================================

INSERT INTO knowledge.question_fact_type
    (
        question_fact_id,
        accepted_response_type,
        is_primary
    )
SELECT
    qf.id,
    q.response_type,
    true
FROM knowledge.question_fact qf
JOIN knowledge.question q
    ON q.id = qf.question_id
WHERE q.response_type IN (
    'numeric',
    'text',
    'date',
    'boolean',
    'single_choice',
    'multiple_choice'
)
ON CONFLICT (question_fact_id, accepted_response_type)
DO NOTHING;


-- =============================================================================
-- 16. DEFAULT SEMANTICS FOR TYPED QUESTIONS
-- =============================================================================

INSERT INTO knowledge.question_fact_semantics
    (
        question_fact_id,
        cardinality,
        value_semantics,
        required_for_answer
    )
SELECT
    qf.id,
    CASE
        WHEN q.response_type = 'multiple_choice'
            THEN 'multiple'
        ELSE 'single'
    END,
    CASE
        WHEN q.response_type = 'numeric'
            THEN 'numeric'
        WHEN q.response_type = 'text'
            THEN 'text'
        WHEN q.response_type = 'date'
            THEN 'date'
        WHEN q.response_type = 'boolean'
            THEN 'boolean'
        WHEN q.response_type = 'single_choice'
            THEN 'coded'
        WHEN q.response_type = 'multiple_choice'
            THEN 'coded'
    END,
    true
FROM knowledge.question_fact qf
JOIN knowledge.question q
    ON q.id = qf.question_id
WHERE q.response_type IN (
    'numeric',
    'text',
    'date',
    'boolean',
    'single_choice',
    'multiple_choice'
)
ON CONFLICT (question_fact_id)
DO UPDATE SET
    cardinality = EXCLUDED.cardinality,
    value_semantics = EXCLUDED.value_semantics;


-- =============================================================================
-- 17. DURATION NORMALIZATION METADATA
-- =============================================================================
-- Canonical duration facts should preferably be stored in a canonical unit.
-- The acquisition layer records the source/canonical relationship.
-- =============================================================================

INSERT INTO knowledge.question_fact_normalization
    (
        question_fact_id,
        normalization_type,
        configuration,
        priority,
        is_active
    )
SELECT
    qf.id,
    'unit_conversion',
    jsonb_build_object(
        'dimension', 'duration',
        'canonical_unit', qf.unit_code,
        'supported_units', jsonb_build_array(
            'second',
            'seconds',
            'minute',
            'minutes',
            'hour',
            'hours',
            'day',
            'days',
            'week',
            'weeks',
            'month',
            'months',
            'year',
            'years'
        )
    ),
    10,
    true
FROM knowledge.question_fact qf
WHERE qf.unit_code IN (
    'second',
    'seconds',
    'minute',
    'minutes',
    'hour',
    'hours',
    'day',
    'days',
    'week',
    'weeks',
    'month',
    'months',
    'year',
    'years'
)
ON CONFLICT (
    question_fact_id,
    normalization_type,
    priority
)
DO UPDATE SET
    configuration = EXCLUDED.configuration,
    is_active = true;


-- =============================================================================
-- 18. FACT ACQUISITION AUDIT CONTRACT
-- =============================================================================
-- Every acquired fact should be traceable to the question/answer that produced
-- it. This table is knowledge-layer metadata; actual patient observations belong
-- in the clinical runtime/encounter data model.
-- =============================================================================

CREATE TABLE knowledge.fact_acquisition_source (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id           uuid NOT NULL
                          REFERENCES knowledge.question(id)
                          ON DELETE CASCADE,

    answer_option_id      uuid
                          REFERENCES knowledge.answer_option(id)
                          ON DELETE CASCADE,

    question_fact_id      uuid
                          REFERENCES knowledge.question_fact(id)
                          ON DELETE CASCADE,

    acquisition_mode      text NOT NULL
                          CHECK (
                              acquisition_mode IN (
                                  'answer_option',
                                  'raw_value'
                              )
                          ),

    provenance             jsonb NOT NULL DEFAULT '{}'::jsonb,

    is_active              boolean NOT NULL DEFAULT true,

    created_at             timestamptz NOT NULL DEFAULT now(),

    CHECK (
        (acquisition_mode = 'answer_option' AND answer_option_id IS NOT NULL)
        OR
        (acquisition_mode = 'raw_value' AND question_fact_id IS NOT NULL)
    )
);

COMMENT ON TABLE knowledge.fact_acquisition_source IS
'Metadata describing how a clinical fact is acquired from the universal question engine. Patient-specific observations are stored elsewhere.';


CREATE INDEX idx_fact_acquisition_source_question
    ON knowledge.fact_acquisition_source(question_id);

CREATE INDEX idx_fact_acquisition_source_option
    ON knowledge.fact_acquisition_source(answer_option_id);

CREATE INDEX idx_fact_acquisition_source_question_fact
    ON knowledge.fact_acquisition_source(question_fact_id);


-- =============================================================================
-- 19. REGISTER EXISTING CHOICE-QUESTION ACQUISITION PATH
-- =============================================================================

INSERT INTO knowledge.fact_acquisition_source
    (
        question_id,
        answer_option_id,
        acquisition_mode,
        provenance
    )
SELECT
    q.id,
    ao.id,
    'answer_option',
    jsonb_build_object(
        'mapping', 'knowledge.fact_mapping',
        'stable_answer_code', ao.answer_code
    )
FROM knowledge.question q
JOIN knowledge.answer_option ao
    ON ao.question_id = q.id
JOIN knowledge.fact_mapping fm
    ON fm.answer_option_id = ao.id
WHERE fm.is_active = true
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 20. REGISTER EXISTING RAW-VALUE ACQUISITION PATH
-- =============================================================================

INSERT INTO knowledge.fact_acquisition_source
    (
        question_id,
        question_fact_id,
        acquisition_mode,
        provenance
    )
SELECT
    qf.question_id,
    qf.id,
    'raw_value',
    jsonb_build_object(
        'mapping', 'knowledge.question_fact',
        'fact_definition', qf.fact_definition_code,
        'unit', qf.unit_code
    )
FROM knowledge.question_fact qf
WHERE qf.is_active = true
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 21. KNOWLEDGE INTEGRITY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_question_active_response
    ON knowledge.question(is_active, response_type);

CREATE INDEX IF NOT EXISTS idx_knowledge_answer_option_active
    ON knowledge.answer_option(question_id, is_active);

CREATE INDEX IF NOT EXISTS idx_knowledge_fact_mapping_fact
    ON knowledge.fact_mapping(fact_definition_code, is_active);


-- =============================================================================
-- 22. QUESTION ACQUISITION COVERAGE VIEW
-- =============================================================================
-- Used by the knowledge validator and administrative CPU tooling.
--
-- acquisition_mode:
--   option      → answer_option/fact_mapping
--   raw         → question_fact
--   both        → both mechanisms exist
--   none        → question acquires no clinical fact
--
-- "none" is not automatically an error because some questions may be:
--   • informational
--   • routing
--   • confirmation
--   • workflow-only
-- =============================================================================

CREATE VIEW knowledge.question_acquisition_coverage AS
SELECT
    q.id,
    q.question_code,
    q.response_type,
    q.is_active,

    EXISTS (
        SELECT 1
        FROM knowledge.answer_option ao
        JOIN knowledge.fact_mapping fm
            ON fm.answer_option_id = ao.id
           AND fm.is_active = true
        WHERE ao.question_id = q.id
          AND ao.is_active = true
    ) AS has_option_fact_mapping,

    EXISTS (
        SELECT 1
        FROM knowledge.question_fact qf
        WHERE qf.question_id = q.id
          AND qf.is_active = true
    ) AS has_raw_fact_mapping,

    CASE
        WHEN EXISTS (
            SELECT 1
            FROM knowledge.answer_option ao
            JOIN knowledge.fact_mapping fm
                ON fm.answer_option_id = ao.id
               AND fm.is_active = true
            WHERE ao.question_id = q.id
              AND ao.is_active = true
        )
        AND EXISTS (
            SELECT 1
            FROM knowledge.question_fact qf
            WHERE qf.question_id = q.id
              AND qf.is_active = true
        )
        THEN 'both'

        WHEN EXISTS (
            SELECT 1
            FROM knowledge.answer_option ao
            JOIN knowledge.fact_mapping fm
                ON fm.answer_option_id = ao.id
               AND fm.is_active = true
            WHERE ao.question_id = q.id
              AND ao.is_active = true
        )
        THEN 'option'

        WHEN EXISTS (
            SELECT 1
            FROM knowledge.question_fact qf
            WHERE qf.question_id = q.id
              AND qf.is_active = true
        )
        THEN 'raw'

        ELSE 'none'
    END AS acquisition_mode

FROM knowledge.question q;

COMMENT ON VIEW knowledge.question_acquisition_coverage IS
'Knowledge-quality view showing whether each question can acquire clinical truth.';


-- =============================================================================
-- 23. RAW QUESTION SAFETY VIEW
-- =============================================================================
-- Detects typed questions that have no fact acquisition path.
-- =============================================================================

CREATE VIEW knowledge.unmapped_typed_questions AS
SELECT
    q.id,
    q.question_code,
    q.text,
    q.response_type,
    q.is_active
FROM knowledge.question q
WHERE q.is_active = true
  AND q.response_type IN (
      'numeric',
      'text',
      'date',
      'boolean'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM knowledge.question_fact qf
      WHERE qf.question_id = q.id
        AND qf.is_active = true
  );

COMMENT ON VIEW knowledge.unmapped_typed_questions IS
'Typed clinical questions that cannot currently produce a clinical fact and therefore require knowledge curation.';


-- =============================================================================
-- 24. CHOICE QUESTION SAFETY VIEW
-- =============================================================================
-- Detects choice options that capture no clinical truth.
-- =============================================================================

CREATE VIEW knowledge.unmapped_answer_options AS
SELECT
    q.question_code,
    q.response_type,
    ao.id AS answer_option_id,
    ao.answer_code,
    ao.label
FROM knowledge.question q
JOIN knowledge.answer_option ao
    ON ao.question_id = q.id
WHERE q.is_active = true
  AND ao.is_active = true
  AND NOT EXISTS (
      SELECT 1
      FROM knowledge.fact_mapping fm
      WHERE fm.answer_option_id = ao.id
        AND fm.is_active = true
  );

COMMENT ON VIEW knowledge.unmapped_answer_options IS
'Active answer options that do not establish a clinical fact.';


-- =============================================================================
-- 25. UNIVERSAL ACQUISITION CONTRACT
-- =============================================================================
-- The CPU can use this view to obtain one normalized acquisition contract
-- regardless of whether the source is:
--
--   single choice
--   multiple choice
--   boolean
--   numeric
--   text
--   date
--
-- =============================================================================

CREATE VIEW knowledge.question_fact_contract AS
SELECT
    q.id                         AS question_id,
    q.question_code,
    q.question_type,
    q.response_type,
    qf.id                        AS question_fact_id,
    qf.fact_definition_code,
    qf.unit_code,
    qf.normalization,
    qf.validation,
    qfs.cardinality,
    qfs.value_semantics,
    qfs.required_for_answer,
    qft.accepted_response_type,
    qf.is_active
FROM knowledge.question q
JOIN knowledge.question_fact qf
    ON qf.question_id = q.id
LEFT JOIN knowledge.question_fact_semantics qfs
    ON qfs.question_fact_id = qf.id
LEFT JOIN knowledge.question_fact_type qft
    ON qft.question_fact_id = qf.id
   AND qft.is_primary = true
WHERE q.is_active = true
  AND qf.is_active = true;

COMMENT ON VIEW knowledge.question_fact_contract IS
'Canonical CPU acquisition contract: typed question → normalized clinical fact.';


-- =============================================================================
-- 26. EXPLICIT INTEGRITY CHECKS
-- =============================================================================

DO $$
DECLARE
    missing_cough integer;
    missing_radiation integer;
BEGIN

    SELECT COUNT(*)
      INTO missing_cough
      FROM knowledge.question q
     WHERE q.question_code = 'COUGH_DURATION'
       AND q.is_active = true
       AND NOT EXISTS (
           SELECT 1
           FROM knowledge.question_fact qf
           WHERE qf.question_id = q.id
             AND qf.fact_definition_code = 'COUGH_DURATION_DAYS'
             AND qf.is_active = true
       );

    IF missing_cough > 0 THEN
        RAISE EXCEPTION
            'AMEXAN knowledge integrity failure: COUGH_DURATION is not bound to COUGH_DURATION_DAYS';
    END IF;


    SELECT COUNT(*)
      INTO missing_radiation
      FROM knowledge.question q
     WHERE q.question_code = 'CHEST_PAIN_RADIATION'
       AND q.is_active = true
       AND EXISTS (
           SELECT 1
           FROM knowledge.answer_option ao
           WHERE ao.question_id = q.id
             AND ao.is_active = true
       )
       AND EXISTS (
           SELECT 1
           FROM knowledge.answer_option ao
           WHERE ao.question_id = q.id
             AND ao.is_active = true
             AND NOT EXISTS (
                 SELECT 1
                 FROM knowledge.fact_mapping fm
                 WHERE fm.answer_option_id = ao.id
                   AND fm.fact_definition_code = 'CHEST_PAIN_RADIATION'
                   AND fm.is_active = true
             )
       );

    IF missing_radiation > 0 THEN
        RAISE EXCEPTION
            'AMEXAN knowledge integrity failure: CHEST_PAIN_RADIATION contains unmapped answer options';
    END IF;

END
$$;


-- =============================================================================
-- 27. FINAL KNOWLEDGE CONTRACT
-- =============================================================================
--
-- AMEXAN acquisition is therefore:
--
--   HUMAN / DEVICE INPUT
--          │
--          ▼
--      QUESTION
--          │
--          ├──────── choice ────────► ANSWER_OPTION
--          │                              │
--          │                              ▼
--          │                         FACT_MAPPING
--          │                              │
--          │                              ▼
--          │                       CLINICAL FACT
--          │
--          └──────── typed ─────────► QUESTION_FACT
--                                         │
--                              validation │
--                              normalization
--                                         │
--                                         ▼
--                                  CLINICAL FACT
--                                         │
--                    ┌────────────────────┼────────────────────┐
--                    ▼                    ▼                    ▼
--                PHENOTYPE            MECHANISM             SAFETY
--                    │                    │                    │
--                    └────────────────────┼────────────────────┘
--                                         ▼
--                                  DIFFERENTIAL
--                                         │
--                                         ▼
--                                  INVESTIGATION
--                                         │
--                                         ▼
--                                  RESULT → FACT
--                                         │
--                                         ▼
--                                  PROTOCOL / CARE
--                                         │
--                                         ▼
--                                  MONITORING
--                                         │
--                                         ▼
--                                   NEW FACTS
--                                         │
--                                         └──────────► CPU LOOP
--
-- The question engine therefore remains an acquisition layer, while the
-- clinical CPU reasons exclusively over universal facts and the knowledge graph.
-- =============================================================================