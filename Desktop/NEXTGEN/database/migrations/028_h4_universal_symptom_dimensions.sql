-- =============================================================================
-- AMEXAN Medical Knowledge Compiler
-- H4 â€” UNIVERSAL SYMPTOM EXPLORATION GRAMMAR
-- =============================================================================
--
-- PURPOSE
-- -------
-- H4 defines the universal clinical grammar beneath every symptom:
--
--   PRESENTATION
--        â†“
--   SYMPTOM
--        â†“
--   DIMENSIONS
--        â†“
--   QUESTIONS
--        â†“
--   ANSWERS
--        â†“
--   CANONICAL FACTS
--        â†“
--   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--   â”‚ TIMELINE     â”‚ ASSOCIATIONS â”‚ RED FLAGS    â”‚ DIFFERENTIAL   â”‚
--   â”‚              â”‚              â”‚              â”‚                â”‚
--   â”‚ onset        â”‚ symptoms     â”‚ danger       â”‚ diagnostic     â”‚
--   â”‚ duration     â”‚ exposures    â”‚ severity     â”‚ weighting     â”‚
--   â”‚ progression  â”‚ risks        â”‚ context      â”‚                â”‚
--   â”‚ sequence     â”‚ function     â”‚ urgency      â”‚                â”‚
--   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--        â†“
--   CLINICAL DOCUMENTATION
--        â†“
--   CPU / CLINICAL INTELLIGENCE
--
-- ARCHITECTURAL LAW
-- -----------------
-- PostgreSQL = knowledge + configuration + provenance
-- CPU        = execution / ranking / reasoning over stored rules
-- UI         = rendering only
--
-- H4 MUST NOT contain disease-specific questionnaires.
-- Disease modules consume this grammar.
--
-- UNIVERSALITY
-- ------------
-- A symptom is not a disease.
-- A dimension is not a question.
-- A question is not a fact.
-- A fact is not a diagnosis.
--
-- The pipeline is:
--
--   SYMPTOM
--      â†’ DIMENSION
--      â†’ QUESTION
--      â†’ ANSWER
--      â†’ FACT
--      â†’ RULES / RELATIONSHIPS / DOCUMENTATION
--
-- This permits one respiratory symptom engine to work for:
--   pneumonia, TB, asthma, COPD, PE, heart failure, malignancy, etc.
--
-- And the same grammar can subsequently work for:
--   abdominal pain
--   headache
--   fever
--   vomiting
--   diarrhoea
--   dysuria
--   vaginal bleeding
--   weakness
--   jaundice
--   syncope
--   seizures
--   joint pain
--   rash
--   psychiatric symptoms
--   surgical complaints
--   emergency presentations
-- etc.
--
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS knowledge;


-- =============================================================================
-- 1. SYMPTOM DIMENSION REGISTRY
-- =============================================================================
--
-- The canonical exploration dimensions.
--
-- These are UNIVERSAL clinical concepts, not UI fields.
--
-- A symptom may use:
--   * all dimensions
--   * a subset
--   * dimensions conditionally activated by another fact
--
-- Example:
--
-- COUGH
--   presence
--   onset
--   duration
--   progression
--   character
--   productivity
--   sputum
--   severity
--   associated symptoms
--   systemic symptoms
--   exposure
--   risk factors
--   previous episodes
--   treatment / health seeking
--   functional impact
--
-- CHEST PAIN
--   presence
--   onset
--   duration
--   site
--   character
--   radiation
--   severity
--   timing
--   precipitating factors
--   relieving factors
--   associated symptoms
--   functional impact
--   risk factors
--   previous episodes
--   health seeking
--
-- The dimension registry prevents every disease module from reinventing
-- history structure.
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_dimension CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.symptom_dimension (
    dimension_id       text PRIMARY KEY,
    dimension_code     text NOT NULL UNIQUE,
    dimension_name     text NOT NULL,

    -- true = this dimension belongs to the universal symptom grammar.
    universal          boolean NOT NULL DEFAULT true,

    applicability      text NOT NULL DEFAULT 'always'
        CHECK (applicability IN ('always', 'conditional')),

    history_concept_id text
        REFERENCES knowledge.history_concept(history_concept_id)
        ON DELETE SET NULL,

    sort_order         integer NOT NULL DEFAULT 0,

    description        text,

    status             text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_symptom_dimension_history_concept
    ON knowledge.symptom_dimension(history_concept_id);

CREATE INDEX IF NOT EXISTS idx_symptom_dimension_status
    ON knowledge.symptom_dimension(status);

CREATE INDEX IF NOT EXISTS idx_symptom_dimension_sort
    ON knowledge.symptom_dimension(sort_order);


DROP TRIGGER IF EXISTS trg_knowledge_symptom_dimension_updated_at
ON knowledge.symptom_dimension;

CREATE TRIGGER trg_knowledge_symptom_dimension_updated_at
    BEFORE UPDATE ON knowledge.symptom_dimension
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


COMMENT ON TABLE knowledge.symptom_dimension IS
'AMEXAN H4 canonical symptom-exploration dimension registry. Dimensions are reusable clinical concepts, not UI fields.';


COMMENT ON COLUMN knowledge.symptom_dimension.universal IS
'Universal dimension available to the symptom grammar. Symptom-specific applicability is determined by symptom_history_dimension and rules.';


COMMENT ON COLUMN knowledge.symptom_dimension.applicability IS
'Always means intrinsically relevant to symptom exploration; conditional means activated only when clinically relevant.';


-- =============================================================================
-- 2. CANONICAL 25-DIMENSION SEED
-- =============================================================================
--
-- The exact set can evolve through governed knowledge releases, but the initial
-- AMEXAN grammar must be explicit and deterministic.
--
-- IMPORTANT:
-- The registry is not saying every dimension must be asked for every symptom.
-- It defines what CAN be explored.
-- symptom_history_dimension decides what IS meaningful for a particular symptom.
-- =============================================================================


INSERT INTO knowledge.symptom_dimension
(
    dimension_id,
    dimension_code,
    dimension_name,
    universal,
    applicability,
    sort_order,
    description
)
VALUES

(
    'SD001',
    'PRESENCE',
    'Presence / absence',
    true,
    'always',
    10,
    'Whether the presenting symptom or manifestation is present.'
),

(
    'SD002',
    'ONSET',
    'Onset',
    true,
    'always',
    20,
    'When and how the symptom began, including sudden, gradual or insidious onset.'
),

(
    'SD003',
    'DURATION',
    'Duration',
    true,
    'always',
    30,
    'How long the symptom has been present.'
),

(
    'SD004',
    'COURSE',
    'Course / progression',
    true,
    'always',
    40,
    'Whether the symptom is improving, worsening, stable, intermittent, recurrent or progressive.'
),

(
    'SD005',
    'SITE',
    'Site / location',
    true,
    'conditional',
    50,
    'Anatomical location of the symptom.'
),

(
    'SD006',
    'CHARACTER',
    'Character / quality',
    true,
    'conditional',
    60,
    'Qualitative nature of the symptom, such as sharp, dull, burning, pressure, barking or tearing.'
),

(
    'SD007',
    'SEVERITY',
    'Severity',
    true,
    'always',
    70,
    'Intensity or clinical severity of the symptom.'
),

(
    'SD008',
    'RADIATION',
    'Radiation / spread',
    true,
    'conditional',
    80,
    'Spread or radiation from the primary site to another anatomical region.'
),

(
    'SD009',
    'TIMING',
    'Timing / temporal pattern',
    true,
    'conditional',
    90,
    'Temporal pattern including episodic, continuous, nocturnal, morning, post-exertional or cyclical occurrence.'
),

(
    'SD010',
    'PRECIPITANTS',
    'Precipitating / aggravating factors',
    true,
    'conditional',
    100,
    'Activities, exposures or circumstances that provoke or worsen the symptom.'
),

(
    'SD011',
    'RELIEVING_FACTORS',
    'Relieving factors',
    true,
    'conditional',
    110,
    'Activities, positions, treatments or circumstances that reduce the symptom.'
),

(
    'SD012',
    'ASSOCIATED_SYMPTOMS',
    'Associated symptoms',
    true,
    'always',
    120,
    'Other symptoms occurring with or around the presenting symptom.'
),

(
    'SD013',
    'SYSTEMIC_FEATURES',
    'Systemic features',
    true,
    'conditional',
    130,
    'Constitutional or systemic manifestations such as fever, weight loss, fatigue or night sweats.'
),

(
    'SD014',
    'FUNCTIONAL_IMPACT',
    'Functional impact',
    true,
    'always',
    140,
    'Effect of the symptom on activities of daily living, exercise, work, school, sleep, eating or social function.'
),

(
    'SD015',
    'EXPOSURES',
    'Relevant exposures',
    true,
    'conditional',
    150,
    'Environmental, occupational, infectious, travel, animal, food, water, smoke, chemical or healthcare exposures.'
),

(
    'SD016',
    'RISK_FACTORS',
    'Risk factors',
    true,
    'conditional',
    160,
    'Patient characteristics, behaviours, conditions or circumstances modifying symptom risk or interpretation.'
),

(
    'SD017',
    'PREVIOUS_EPISODES',
    'Previous episodes',
    true,
    'conditional',
    170,
    'Whether the symptom has occurred before and the characteristics of previous episodes.'
),

(
    'SD018',
    'PREVIOUS_DIAGNOSIS',
    'Previous diagnosis',
    true,
    'conditional',
    180,
    'Previous clinical diagnoses relevant to the symptom.'
),

(
    'SD019',
    'PREVIOUS_TREATMENT',
    'Previous treatment',
    true,
    'conditional',
    190,
    'Previous treatment, self-treatment, prescribed treatment or other interventions.'
),

(
    'SD020',
    'TREATMENT_RESPONSE',
    'Treatment response',
    true,
    'conditional',
    200,
    'Response, non-response, partial response or recurrence following treatment.'
),

(
    'SD021',
    'HEALTH_SEEKING',
    'Health-seeking behaviour',
    true,
    'conditional',
    210,
    'Previous consultation, healthcare contact, treatment obtained and reason for current presentation.'
),

(
    'SD022',
    'PATIENT_PERSPECTIVE',
    'Patient perspective',
    true,
    'conditional',
    220,
    'Patient ideas, concerns, expectations and goals relating to the symptom.'
),

(
    'SD023',
    'RED_FLAGS',
    'Red flags / danger features',
    true,
    'conditional',
    230,
    'Features indicating potentially serious disease, deterioration or need for urgent escalation.'
),

(
    'SD024',
    'SEQUENCE',
    'Symptom sequence / chronology',
    true,
    'conditional',
    240,
    'Relationship between onset and evolution of multiple symptoms over time.'
),

(
    'SD025',
    'SOURCE_AND_RELIABILITY',
    'History source and reliability',
    true,
    'conditional',
    250,
    'Who provided the history, availability of collateral information and reliability of the account.'
)

ON CONFLICT (dimension_code) DO UPDATE SET
    dimension_name = EXCLUDED.dimension_name,
    universal = EXCLUDED.universal,
    applicability = EXCLUDED.applicability,
    sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description,
    updated_at = now();


-- =============================================================================
-- 3. SYMPTOM-SPECIFIC DIMENSION VOCABULARY
-- =============================================================================
--
-- A dimension is universal.
--
-- Its possible values are NOT necessarily universal.
--
-- Example:
--
-- CHARACTER is universal.
--
-- COUGH character:
--   dry
--   productive
--   barking
--   paroxysmal
--   brassy
--
-- CHEST PAIN character:
--   pressure
--   tightness
--   burning
--   sharp
--   stabbing
--   tearing
--
-- ABDOMINAL PAIN character:
--   colicky
--   cramping
--   burning
--   dull
--   sharp
--
-- This table is therefore a controlled vocabulary layer.
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.symptom_dimension_option CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.symptom_dimension_option (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id    uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    dimension_id  text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    option_code   text NOT NULL,
    option_name   text NOT NULL,

    description   text,

    sort_order    integer NOT NULL DEFAULT 0,

    is_active    boolean NOT NULL DEFAULT true,

    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    UNIQUE (symptom_id, dimension_id, option_code)
);


CREATE INDEX IF NOT EXISTS idx_symptom_dimension_option_dimension
    ON knowledge.symptom_dimension_option(dimension_id);

CREATE INDEX IF NOT EXISTS idx_symptom_dimension_option_symptom
    ON knowledge.symptom_dimension_option(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_dimension_option_active
    ON knowledge.symptom_dimension_option(symptom_id, dimension_id, is_active);


DROP TRIGGER IF EXISTS trg_symptom_dimension_option_updated_at
ON knowledge.symptom_dimension_option;

CREATE TRIGGER trg_symptom_dimension_option_updated_at
    BEFORE UPDATE ON knowledge.symptom_dimension_option
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


COMMENT ON TABLE knowledge.symptom_dimension_option IS
'Symptom-specific controlled vocabulary for a universal symptom dimension.';


-- =============================================================================
-- 4. RED-FLAG RULE ENGINE
-- =============================================================================
--
-- A red flag is NOT merely:
--
--   RED_FLAG = TRUE
--
-- It is:
--
--   FACT
--      +
--   CONTEXT
--      +
--   CLINICAL SIGNIFICANCE
--      +
--   URGENCY
--      +
--   PRIORITY
--
-- Example:
--
-- haemoptysis in cough
-- severe hypoxaemia
-- sudden dyspnoea
-- syncope with chest pain
-- altered consciousness
--
-- can all mean different things depending on age, amount, timing, associated
-- findings and context.
--
-- Therefore the CPU evaluates rules rather than looking for a boolean.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.red_flag_rule (
    rule_id                text PRIMARY KEY,

    rule_code              text NOT NULL UNIQUE,

    symptom_id             uuid
        REFERENCES knowledge.symptom(id)
        ON DELETE SET NULL,

    fact_definition_code   text
        REFERENCES clinical.fact_definition(code)
        ON DELETE SET NULL,

    context_condition      jsonb,

    clinical_significance  text NOT NULL,

    urgency                text NOT NULL DEFAULT 'urgent'
        CHECK (urgency IN ('emergency', 'urgent', 'routine')),

    priority               integer NOT NULL DEFAULT 50,

    escalation_action      text,

    evidence_claim_code    text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    status                 text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),

    CHECK (
        symptom_id IS NOT NULL
        OR fact_definition_code IS NOT NULL
    )
);


CREATE INDEX IF NOT EXISTS idx_red_flag_rule_symptom
    ON knowledge.red_flag_rule(symptom_id);

CREATE INDEX IF NOT EXISTS idx_red_flag_rule_fact
    ON knowledge.red_flag_rule(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_red_flag_rule_urgency
    ON knowledge.red_flag_rule(urgency, priority);

CREATE INDEX IF NOT EXISTS idx_red_flag_rule_status
    ON knowledge.red_flag_rule(status);


DROP TRIGGER IF EXISTS trg_knowledge_red_flag_rule_updated_at
ON knowledge.red_flag_rule;

CREATE TRIGGER trg_knowledge_red_flag_rule_updated_at
    BEFORE UPDATE ON knowledge.red_flag_rule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


COMMENT ON TABLE knowledge.red_flag_rule IS
'AMEXAN H4 red-flag intelligence: fact + context + clinical significance + urgency, rather than a disease-specific boolean.';


COMMENT ON COLUMN knowledge.red_flag_rule.context_condition IS
'Machine-evaluable contextual condition such as age, severity, amount, frequency, pregnancy or associated findings.';


COMMENT ON COLUMN knowledge.red_flag_rule.clinical_significance IS
'Clinically meaningful explanation of why the triggering fact matters.';


-- =============================================================================
-- 5. EXPOSURE CONCEPT REGISTRY
-- =============================================================================
--
-- Exposures are reusable across symptoms and diseases.
--
-- The same exposure may matter to:
--
--   cough
--   fever
--   diarrhoea
--   jaundice
--   rash
--   hepatitis
--   respiratory disease
--   occupational disease
--   poisoning
--   infectious disease
--
-- The exposure itself is therefore universal intelligence.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.exposure_concept (
    exposure_code  text PRIMARY KEY,

    exposure_class text NOT NULL,

    label          text NOT NULL,

    description    text,

    status         text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_exposure_concept_class
    ON knowledge.exposure_concept(exposure_class);

CREATE INDEX IF NOT EXISTS idx_exposure_concept_status
    ON knowledge.exposure_concept(status);


DROP TRIGGER IF EXISTS trg_knowledge_exposure_concept_updated_at
ON knowledge.exposure_concept;

CREATE TRIGGER trg_knowledge_exposure_concept_updated_at
    BEFORE UPDATE ON knowledge.exposure_concept
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 6. UNIVERSAL EXPOSURE SEED
-- =============================================================================


INSERT INTO knowledge.exposure_concept
(
    exposure_code,
    exposure_class,
    label,
    description
)
VALUES

(
    'CONTACT',
    'infectious',
    'Contact exposure',
    'Relevant contact with people, patients, household members or persons with similar illness.'
),

(
    'TRAVEL',
    'geographic',
    'Travel exposure',
    'Recent or relevant travel, including destination-specific infectious and environmental exposures.'
),

(
    'OCCUPATION',
    'occupational',
    'Occupational exposure',
    'Exposure associated with occupation, workplace or occupational activities.'
),

(
    'ANIMAL',
    'zoonotic',
    'Animal exposure',
    'Contact with domestic, farm, wild or other animals.'
),

(
    'INSECT',
    'vector',
    'Insect / vector exposure',
    'Exposure to mosquitoes, ticks, fleas or other vectors.'
),

(
    'FOOD',
    'ingestion',
    'Food exposure',
    'Relevant food ingestion, preparation, storage or contaminated food exposure.'
),

(
    'WATER',
    'ingestion',
    'Water exposure',
    'Potentially contaminated drinking, recreational or occupational water exposure.'
),

(
    'SEXUAL',
    'sexual',
    'Sexual exposure',
    'Relevant sexual exposure when clinically appropriate to the presentation.'
),

(
    'HEALTHCARE',
    'healthcare',
    'Healthcare exposure',
    'Recent admission, procedures, healthcare contact, devices or healthcare-associated exposure.'
),

(
    'ENVIRONMENTAL',
    'environmental',
    'Environmental exposure',
    'Relevant environmental conditions including housing, climate and environmental hazards.'
),

(
    'SMOKE',
    'inhalational',
    'Smoke exposure',
    'Tobacco smoke, second-hand smoke or other smoke exposure.'
),

(
    'BIOMASS',
    'inhalational',
    'Biomass fuel exposure',
    'Indoor or occupational exposure to biomass fuel combustion products.'
),

(
    'DUST',
    'inhalational',
    'Dust exposure',
    'Occupational or environmental exposure to dust or particulate matter.'
),

(
    'CHEMICAL',
    'toxicological',
    'Chemical exposure',
    'Exposure to industrial, household, agricultural or other chemicals.'
),

(
    'DRUG',
    'medication',
    'Drug / medication exposure',
    'Medication, substance, supplement or other pharmacological exposure relevant to the presentation.'
)

ON CONFLICT (exposure_code) DO UPDATE SET
    exposure_class = EXCLUDED.exposure_class,
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    updated_at = now();


-- =============================================================================
-- 7. SYMPTOM â†’ EXPOSURE
-- =============================================================================
--
-- This determines which exposure domains are relevant to a symptom.
--
-- It does NOT mean that every exposure is automatically asked.
-- The H3 question engine can use these as candidates and rank them using:
--
--   symptom
--   context
--   known facts
--   risk
--   differential
--   urgency
--   previous answers
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.symptom_exposure (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id    uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    exposure_code text NOT NULL
        REFERENCES knowledge.exposure_concept(exposure_code)
        ON DELETE CASCADE,

    priority      integer NOT NULL DEFAULT 50,

    rationale     text,

    evidence_claim_code text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    UNIQUE (symptom_id, exposure_code)
);


CREATE INDEX IF NOT EXISTS idx_symptom_exposure_symptom
    ON knowledge.symptom_exposure(symptom_id);

CREATE INDEX IF NOT EXISTS idx_symptom_exposure_code
    ON knowledge.symptom_exposure(exposure_code);

CREATE INDEX IF NOT EXISTS idx_symptom_exposure_priority
    ON knowledge.symptom_exposure(symptom_id, priority);


-- =============================================================================
-- 8. DIAGNOSTIC WEIGHT ON SYMPTOM RELATIONSHIPS
-- =============================================================================
--
-- Not all associated symptoms carry equal diagnostic information.
--
-- Example:
--
-- cough + fever
-- cough + haemoptysis
--
-- should not necessarily contribute identical diagnostic weight.
--
-- diagnostic_weight is an intelligence parameter used by the reasoning layer.
--
-- It does NOT itself diagnose disease.
--
-- It tells the CPU that the relationship has greater or lesser discriminating
-- value when combining evidence.
-- =============================================================================


ALTER TABLE knowledge.symptom_relationship
    ADD COLUMN IF NOT EXISTS diagnostic_weight integer NOT NULL DEFAULT 1;


ALTER TABLE knowledge.symptom_relationship
    ADD COLUMN IF NOT EXISTS evidence_claim_code text;


-- Add FK only if the column exists and the constraint has not already been added.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'symptom_relationship_evidence_claim_fk'
    ) THEN
        ALTER TABLE knowledge.symptom_relationship
            ADD CONSTRAINT symptom_relationship_evidence_claim_fk
            FOREIGN KEY (evidence_claim_code)
            REFERENCES knowledge.source_claim(claim_code)
            ON DELETE SET NULL;
    END IF;
END
$$;


COMMENT ON COLUMN knowledge.symptom_relationship.diagnostic_weight IS
'Relative diagnostic value of a symptom relationship. Higher values indicate greater discriminating value to the reasoning layer.';


CREATE INDEX IF NOT EXISTS idx_symptom_relationship_diagnostic_weight
    ON knowledge.symptom_relationship(diagnostic_weight);


-- =============================================================================
-- 9. SYMPTOM â†’ DIMENSION OVERRIDE / APPLICABILITY
-- =============================================================================
--
-- H2 already provides:
--
--   knowledge.symptom_history_dimension
--
-- H4 should explicitly allow the symptom to override the generic dimension
-- defaults.
--
-- Example:
--
-- cough:
--   productivity = applicable
--   radiation   = not applicable
--
-- chest pain:
--   radiation   = applicable
--   sputum      = not applicable
--
-- This keeps the UI and CPU from asking clinically meaningless questions.
-- =============================================================================


ALTER TABLE knowledge.symptom_history_dimension
    ADD COLUMN IF NOT EXISTS dimension_id text
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE SET NULL;


ALTER TABLE knowledge.symptom_history_dimension
    ADD COLUMN IF NOT EXISTS rationale text;


ALTER TABLE knowledge.symptom_history_dimension
    ADD COLUMN IF NOT EXISTS evidence_claim_code text;


DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'symptom_history_dimension_evidence_claim_fk'
    ) THEN
        ALTER TABLE knowledge.symptom_history_dimension
            ADD CONSTRAINT symptom_history_dimension_evidence_claim_fk
            FOREIGN KEY (evidence_claim_code)
            REFERENCES knowledge.source_claim(claim_code)
            ON DELETE SET NULL;
    END IF;
END
$$;


CREATE INDEX IF NOT EXISTS idx_symptom_history_dimension_dimension
    ON knowledge.symptom_history_dimension(dimension_id);


-- =============================================================================
-- 10. DIMENSION â†’ HISTORY CONCEPT SYNCHRONISATION
-- =============================================================================
--
-- Where H2 already has history concepts such as ONSET, DURATION, SITE etc.,
-- H4 links the dimension registry to them.
--
-- This is deliberately code-based rather than inventing duplicate concepts.
-- =============================================================================


UPDATE knowledge.symptom_dimension sd
SET history_concept_id = hc.history_concept_id
FROM knowledge.history_concept hc
WHERE sd.history_concept_id IS NULL
  AND upper(hc.concept_code) = sd.dimension_code;


-- =============================================================================
-- 11. UNIVERSAL DIMENSION SEMANTIC METADATA
-- =============================================================================
--
-- The CPU needs to know what a dimension fundamentally represents.
--
-- This is useful for question generation, documentation and validation.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.symptom_dimension_semantics (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    dimension_id    text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    semantic_role   text NOT NULL
        CHECK (
            semantic_role IN (
                'identity',
                'temporal',
                'anatomical',
                'qualitative',
                'quantitative',
                'causal',
                'associated',
                'severity',
                'risk',
                'exposure',
                'functional',
                'safety',
                'historical',
                'perspective',
                'reliability',
                'escalation'
            )
        ),

    description     text,

    UNIQUE (dimension_id, semantic_role)
);


CREATE INDEX IF NOT EXISTS idx_dimension_semantics_dimension
    ON knowledge.symptom_dimension_semantics(dimension_id);


-- =============================================================================
-- 12. SEED SEMANTIC ROLES
-- =============================================================================


INSERT INTO knowledge.symptom_dimension_semantics
(
    dimension_id,
    semantic_role,
    description
)
VALUES
('SD001', 'identity',      'Establishes whether the presenting symptom exists.'),
('SD002', 'temporal',      'Establishes when and how the symptom begins.'),
('SD003', 'temporal',      'Establishes symptom duration.'),
('SD004', 'temporal',      'Establishes evolution and progression.'),
('SD005', 'anatomical',    'Establishes anatomical location.'),
('SD006', 'qualitative',   'Establishes symptom quality or character.'),
('SD007', 'severity',      'Establishes intensity or severity.'),
('SD008', 'anatomical',    'Establishes anatomical spread or radiation.'),
('SD009', 'temporal',      'Establishes temporal pattern.'),
('SD010', 'causal',        'Identifies provoking/aggravating factors.'),
('SD011', 'causal',        'Identifies relieving factors.'),
('SD012', 'associated',    'Identifies associated clinical manifestations.'),
('SD013', 'severity',      'Identifies systemic illness features.'),
('SD014', 'functional',    'Establishes effect on function and daily life.'),
('SD015', 'exposure',      'Identifies relevant environmental or epidemiological exposure.'),
('SD016', 'risk',          'Identifies predisposition and risk modification.'),
('SD017', 'historical',    'Establishes recurrence and previous episodes.'),
('SD018', 'historical',    'Establishes previous diagnostic history.'),
('SD019', 'historical',    'Establishes prior treatment.'),
('SD020', 'historical',    'Establishes response to previous treatment.'),
('SD021', 'historical',    'Establishes previous healthcare interaction.'),
('SD022', 'perspective',  'Captures patient ideas, concerns, expectations and goals.'),
('SD023', 'escalation',   'Identifies danger features requiring escalation.'),
('SD024', 'temporal',     'Links the sequence of multiple clinical events.'),
('SD025', 'reliability',  'Establishes source and reliability of the history.')

ON CONFLICT (dimension_id, semantic_role) DO NOTHING;


-- =============================================================================
-- 13. DIMENSION VALIDATION RULES
-- =============================================================================
--
-- This gives the compiler a place to encode structural expectations without
-- putting medical logic into the UI.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.symptom_dimension_rule (
    rule_id             text PRIMARY KEY,

    dimension_id        text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    rule_type            text NOT NULL
        CHECK (
            rule_type IN (
                'requires_fact',
                'requires_question',
                'suppresses_question',
                'activates_dimension',
                'deactivates_dimension',
                'documentation',
                'validation'
            )
        ),

    condition            jsonb,

    action               jsonb NOT NULL,

    rationale            text,

    evidence_claim_code  text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    priority             integer NOT NULL DEFAULT 50,

    status               text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_symptom_dimension_rule_dimension
    ON knowledge.symptom_dimension_rule(dimension_id);

CREATE INDEX IF NOT EXISTS idx_symptom_dimension_rule_type
    ON knowledge.symptom_dimension_rule(rule_type);


DROP TRIGGER IF EXISTS trg_symptom_dimension_rule_updated_at
ON knowledge.symptom_dimension_rule;

CREATE TRIGGER trg_symptom_dimension_rule_updated_at
    BEFORE UPDATE ON knowledge.symptom_dimension_rule
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 14. SYMPTOM EXPLORATION PROFILE
-- =============================================================================
--
-- This is the compiled runtime-facing summary of how a symptom is explored.
--
-- It does NOT duplicate questions.
--
-- It provides a governed configuration boundary between the universal symptom
-- ontology and the H3 question selector.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.symptom_exploration_profile (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id           uuid NOT NULL UNIQUE
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    minimum_completion    jsonb,

    default_priority      integer NOT NULL DEFAULT 50,

    safety_first          boolean NOT NULL DEFAULT true,

    chronology_required   boolean NOT NULL DEFAULT true,

    character_required    boolean NOT NULL DEFAULT false,

    associated_required   boolean NOT NULL DEFAULT true,

    functional_required   boolean NOT NULL DEFAULT true,

    risk_review_required  boolean NOT NULL DEFAULT true,

    exposure_review_required boolean NOT NULL DEFAULT false,

    previous_episode_review boolean NOT NULL DEFAULT true,

    health_seeking_review boolean NOT NULL DEFAULT true,

    patient_perspective_review boolean NOT NULL DEFAULT true,

    documentation_order   jsonb,

    evidence_claim_code   text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    status                text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);


DROP TRIGGER IF EXISTS trg_symptom_exploration_profile_updated_at
ON knowledge.symptom_exploration_profile;

CREATE TRIGGER trg_symptom_exploration_profile_updated_at
    BEFORE UPDATE ON knowledge.symptom_exploration_profile
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 15. SYMPTOM DIMENSION â†’ QUESTION BRIDGE
-- =============================================================================
--
-- H4 should explicitly know which questions explore which dimension.
--
-- One question may explore one or several dimensions.
--
-- Example:
--
-- "When did the cough begin?"
--      â†’ ONSET
--
-- "Has it been getting worse?"
--      â†’ COURSE
--
-- "Is there any blood in the sputum?"
--      â†’ SPUTUM + RED_FLAGS
--
-- This lets AMEXAN:
--   * rank questions
--   * avoid duplicate questioning
--   * know which dimensions are complete
--   * generate documentation
--   * audit why a question was asked
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.question_dimension CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.question_dimension (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    question_id    uuid NOT NULL
        REFERENCES knowledge.question(id)
        ON DELETE CASCADE,

    dimension_id   text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    priority       integer NOT NULL DEFAULT 50,

    acquisition_role text NOT NULL DEFAULT 'primary'
        CHECK (
            acquisition_role IN (
                'primary',
                'secondary',
                'safety',
                'supporting'
            )
        ),

    UNIQUE (question_id, dimension_id)
);


CREATE INDEX IF NOT EXISTS idx_question_dimension_question
    ON knowledge.question_dimension(question_id);

CREATE INDEX IF NOT EXISTS idx_question_dimension_dimension
    ON knowledge.question_dimension(dimension_id);


-- =============================================================================
-- 16. DIMENSION â†’ FACT BRIDGE
-- =============================================================================
--
-- This explicitly declares which canonical facts constitute completion/evidence
-- for a dimension.
--
-- Example:
--
-- ONSET
--   â†’ COUGH_ONSET
--
-- DURATION
--   â†’ COUGH_DURATION_DAYS
--
-- SEVERITY
--   â†’ DYSPNOEA_SEVERITY
--
-- RED_FLAGS
--   â†’ HAEMOPTYSIS
--   â†’ CYANOS
--   â†’ ALTERED_CONSCIOUSNESS
--
-- This is critical for CPU reasoning and documentation.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.dimension_fact (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    dimension_id          text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    fact_definition_code  text NOT NULL
        REFERENCES clinical.fact_definition(code)
        ON DELETE CASCADE,

    role                  text NOT NULL DEFAULT 'evidence'
        CHECK (
            role IN (
                'evidence',
                'completion',
                'red_flag',
                'severity',
                'temporal',
                'documentation'
            )
        ),

    priority              integer NOT NULL DEFAULT 50,

    UNIQUE (dimension_id, fact_definition_code, role)
);


CREATE INDEX IF NOT EXISTS idx_dimension_fact_dimension
    ON knowledge.dimension_fact(dimension_id);

CREATE INDEX IF NOT EXISTS idx_dimension_fact_fact
    ON knowledge.dimension_fact(fact_definition_code);


-- =============================================================================
-- 17. SYMPTOM DIMENSION COMPLETION
-- =============================================================================
--
-- Completion is not simply "question answered".
--
-- The CPU should know whether the underlying clinical dimension is sufficiently
-- established.
--
-- Examples:
--
-- ONSET:
--   known OR explicitly unknown
--
-- RED_FLAGS:
--   required safety probes answered
--
-- FUNCTION:
--   functional impact established
--
-- SOURCE:
--   source/reliability established
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.symptom_dimension_completion (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id           uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    dimension_id         text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    completion_condition  jsonb NOT NULL,

    mandatory             boolean NOT NULL DEFAULT false,

    priority              integer NOT NULL DEFAULT 50,

    evidence_claim_code   text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    UNIQUE (symptom_id, dimension_id)
);


CREATE INDEX IF NOT EXISTS idx_symptom_dimension_completion
    ON knowledge.symptom_dimension_completion(symptom_id, dimension_id);


-- =============================================================================
-- 18. DOCUMENTATION ORDER
-- =============================================================================
--
-- AMEXAN documentation must not simply reproduce database insertion order.
--
-- Clinical narrative has an order.
--
-- Typical internal-medicine symptom narrative:
--
--   presenting complaint
--   chronology
--   character
--   site/radiation
--   progression
--   associated symptoms
--   systemic features
--   exposures/risk factors
--   previous episodes
--   previous treatment
--   health seeking
--   severity
--   functional impact
--   examination
--
-- The DocumentationEngine uses this configuration.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.symptom_documentation_order (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id         uuid NOT NULL
        REFERENCES knowledge.symptom(id)
        ON DELETE CASCADE,

    dimension_id       text NOT NULL
        REFERENCES knowledge.symptom_dimension(dimension_id)
        ON DELETE CASCADE,

    documentation_group text NOT NULL,

    sort_order          integer NOT NULL DEFAULT 0,

    prose_role          text NOT NULL DEFAULT 'fact'
        CHECK (
            prose_role IN (
                'opening',
                'chronology',
                'characterization',
                'associated',
                'systemic',
                'risk',
                'previous',
                'health_seeking',
                'severity',
                'functional',
                'examination',
                'closing'
            )
        ),

    UNIQUE (symptom_id, dimension_id)
);


CREATE INDEX IF NOT EXISTS idx_symptom_documentation_order
    ON knowledge.symptom_documentation_order(symptom_id, sort_order);


-- =============================================================================
-- 19. PROVENANCE
-- =============================================================================
--
-- Every H4 rule can be tied back to the compiler's source layer.
--
-- No unsupported clinical rule should silently become runtime truth.
-- =============================================================================


COMMENT ON TABLE knowledge.symptom_dimension IS
'AMEXAN H4 universal symptom grammar. Dimensions are reusable clinical concepts and are separated from questions, answers and diseases.';

COMMENT ON TABLE knowledge.symptom_dimension_option IS
'Controlled symptom-specific vocabularies attached to universal exploration dimensions.';

COMMENT ON TABLE knowledge.red_flag_rule IS
'Clinical safety rules represented as fact + context + significance + urgency.';

COMMENT ON TABLE knowledge.exposure_concept IS
'Reusable exposure ontology shared across symptoms, systems and disease modules.';

COMMENT ON TABLE knowledge.symptom_exposure IS
'Maps symptoms to clinically relevant exposure domains.';

COMMENT ON TABLE knowledge.symptom_exploration_profile IS
'Runtime configuration describing how a symptom is comprehensively explored without embedding questions in the symptom object.';

COMMENT ON TABLE knowledge.question_dimension IS
'Maps questions to the universal symptom dimensions they acquire or establish.';

COMMENT ON TABLE knowledge.dimension_fact IS
'Maps canonical facts to symptom dimensions for evidence, completion, safety and documentation.';

COMMENT ON TABLE knowledge.symptom_dimension_completion IS
'Clinical completion rules for symptom dimensions. Completion is based on established clinical information, not number of questions asked.';

COMMENT ON TABLE knowledge.symptom_documentation_order IS
'Clinical narrative ordering used by the AMEXAN DocumentationEngine.';


-- =============================================================================
-- 20. INTEGRITY CHECKS
-- =============================================================================
--
-- These constraints protect the architecture from invalid knowledge.
-- =============================================================================


DO $$
BEGIN

    -- Ensure diagnostic weight cannot become meaningless.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'symptom_relationship_diagnostic_weight_positive'
    ) THEN
        ALTER TABLE knowledge.symptom_relationship
            ADD CONSTRAINT symptom_relationship_diagnostic_weight_positive
            CHECK (diagnostic_weight >= 0);
    END IF;


    -- Ensure symptom dimension priorities remain deterministic.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'symptom_dimension_sort_nonnegative'
    ) THEN
        ALTER TABLE knowledge.symptom_dimension
            ADD CONSTRAINT symptom_dimension_sort_nonnegative
            CHECK (sort_order >= 0);
    END IF;


    -- Ensure red flag priorities are valid.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'red_flag_rule_priority_nonnegative'
    ) THEN
        ALTER TABLE knowledge.red_flag_rule
            ADD CONSTRAINT red_flag_rule_priority_nonnegative
            CHECK (priority >= 0);
    END IF;

END
$$;


-- =============================================================================
-- 21. H4 ARCHITECTURAL CONTRACT
-- =============================================================================
--
-- The following comments are deliberately part of the database schema.
-- They document the invariant that the application must preserve.
-- =============================================================================


COMMENT ON SCHEMA knowledge IS
'AMEXAN clinical knowledge layer: universal clinical vocabulary, questions, facts, symptoms, rules, protocols, provenance and configuration. CPU executes this knowledge; UI renders it.';


-- =============================================================================
-- END H4
-- =============================================================================
