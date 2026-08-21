-- =============================================================================
-- AMEXAN Medical Knowledge Compiler
-- H7 MIGRATION 031
-- UNIVERSAL INVESTIGATION INTELLIGENCE ENGINE
-- =============================================================================
--
-- H7 answers:
--
--   "Once history + examination facts are captured, WHAT investigation should
--    be considered, WHY, in WHAT ORDER, under WHICH CONTEXT, subject to WHICH
--    SAFETY CONDITIONS, and HOW does its result return to the clinical CPU?"
--
-- =============================================================================
--
-- CONSTITUTIONAL PRINCIPLE
--
-- H7 is NOT:
--
--      disease -> test lookup
--
-- H7 IS:
--
--      PATIENT STATE
--          â†“
--      CLINICAL QUESTION
--          â†“
--      INVESTIGATION INDICATION
--          â†“
--      INVESTIGATION CANDIDATE
--          â†“
--      CONTEXT GATING
--          â†“
--      SAFETY GATING
--          â†“
--      REDUNDANCY / DEPENDENCY
--          â†“
--      CLINICAL PRIORITY
--          â†“
--      OPERATIONAL FEASIBILITY
--          â†“
--      RECOMMENDATION
--          â†“
--      REQUEST
--          â†“
--      SPECIMEN / STUDY
--          â†“
--      PROCESSING / ACQUISITION
--          â†“
--      RAW RESULT
--          â†“
--      CONTEXTUAL REFERENCE STANDARD
--          â†“
--      CLASSIFICATION
--          â†“
--      INTERPRETATION
--          â†“
--      PHENOTYPE / CANONICAL FACT
--          â†“
--      H8 CLINICAL SYNTHESIS
--
-- =============================================================================
--
-- H7 CONSTITUTIONAL LAWS
--
-- H7-01  Investigation knowledge is not an investigation request.
-- H7-02  Investigation knowledge is never owned by a disease.
-- H7-03  A request is an operational event.
-- H7-04  A specimen/study is an operational object.
-- H7-05  A result is not an interpretation.
-- H7-06  An interpretation is not a diagnosis.
-- H7-07  Raw results are immutable clinical evidence once finalized.
-- H7-08  Composite investigations produce independently addressable components.
-- H7-09  Context can change eligibility, safety, priority and interpretation.
-- H7-10  Reference standards are contextual and versioned.
-- H7-11  Units are explicit and raw units are never destroyed.
-- H7-12  Imaging findings retain anatomical localization.
-- H7-13  Microbiology retains organism and susceptibility information.
-- H7-14  Selection rules are DATA, not disease-specific CPU if-chains.
-- H7-15  Clinical appropriateness is separate from operational availability.
-- H7-16  Safety semantics distinguish block, precaution, prerequisite and
--        alternative.
-- H7-17  Every recommendation must be explainable and traceable.
-- H7-18  Every interpretation must be traceable to a rule and source.
-- H7-19  H7 produces investigation-derived facts and phenotypes.
-- H7-20  H8 performs clinical synthesis and diagnosis.
--
-- =============================================================================


-- ============================================================================
-- 0. SCHEMAS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;
CREATE SCHEMA IF NOT EXISTS clinical;


-- ============================================================================
-- 1. INVESTIGATION DOMAIN
-- ============================================================================
--
-- A DOMAIN describes the discipline/type of investigation.
--
-- It is deliberately NOT a body system.
--
-- Example:
--
--   HAEMATOLOGY
--   BIOCHEMISTRY
--   MICROBIOLOGY
--   IMMUNOLOGY
--   IMAGING
--   PHYSIOLOGY
--   PATHOLOGY
--   MOLECULAR
--   GENETICS
--   TOXICOLOGY
--
-- A single investigation may apply to many body systems.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_domain (
    domain_code          TEXT PRIMARY KEY,
    code                 TEXT NOT NULL UNIQUE,
    label                TEXT NOT NULL,
    description          TEXT,
    sort_order           INTEGER NOT NULL DEFAULT 0,

    status               TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation_domain IS
'Universal investigation domains. Domains describe investigation discipline, never disease ownership or body-system ownership.';


-- ============================================================================
-- 2. INVESTIGATION CONCEPT
-- ============================================================================
--
-- KNOWLEDGE OBJECT.
--
-- Defines WHAT an investigation is.
--
-- Examples:
--
--   I001 CBC
--   I002 CRP
--   I003 UREA_ELECTROLYTES
--   I004 BLOOD_CULTURE
--   I005 CHEST_XRAY
--   I006 ECG
--   I007 SPIROMETRY
--
-- This is NOT an order and NOT a result.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_concept (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                     TEXT NOT NULL UNIQUE,

    domain_code              TEXT NOT NULL
        REFERENCES knowledge.investigation_domain(domain_code),

    concept_id               UUID
        REFERENCES knowledge.concept(id),

    fact_definition_code     TEXT
        REFERENCES clinical.fact_definition(code),

    canonical_code           TEXT NOT NULL UNIQUE,
    canonical_name           TEXT NOT NULL,
    short_label              TEXT,
    description              TEXT,

    modality                 TEXT NOT NULL
        CHECK (
            modality IN (
                'LAB',
                'MICROBIOLOGY',
                'IMAGING',
                'PHYSIOLOGY',
                'PATHOLOGY',
                'MOLECULAR',
                'GENETIC',
                'TOXICOLOGY'
            )
        ),

    result_structure         TEXT NOT NULL DEFAULT 'NUMERIC'
        CHECK (
            result_structure IN (
                'NUMERIC',
                'COMPONENT_PANEL',
                'STRUCTURED_FINDINGS',
                'MICROBIOLOGY',
                'PATHOLOGY',
                'MIXED'
            )
        ),

    specimen_type_code       TEXT,

    preparation_requirements TEXT,

    patient_constraints      TEXT[] NOT NULL DEFAULT '{}',

    safety_requirements      TEXT,

    clinical_purposes        TEXT[] NOT NULL DEFAULT '{}',

    base_priority            INTEGER NOT NULL DEFAULT 100,

    applies_to_context_codes TEXT[] NOT NULL DEFAULT '{}',

    capture_method_codes     TEXT[] NOT NULL DEFAULT '{}',

    is_mandatory             BOOLEAN NOT NULL DEFAULT false,

    status                   TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation_concept IS
'Universal reusable investigation definition. Never a disease-owned test, never a request, never a result.';


CREATE INDEX IF NOT EXISTS idx_inv_concept_domain
    ON knowledge.investigation_concept(domain_code);

CREATE INDEX IF NOT EXISTS idx_inv_concept_fact
    ON knowledge.investigation_concept(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_inv_concept_modality
    ON knowledge.investigation_concept(modality);


-- ============================================================================
-- 3. INVESTIGATION METHOD
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_method (
    method_code          TEXT PRIMARY KEY,

    name                 TEXT NOT NULL,
    description          TEXT,

    method_family        TEXT,

    acquisition_type     TEXT
        CHECK (
            acquisition_type IN (
                'LAB_ANALYSER',
                'MICROSCOPY',
                'CULTURE',
                'PCR',
                'IMMUNOASSAY',
                'RADIOGRAPH',
                'ULTRASOUND',
                'CT',
                'MRI',
                'NUCLEAR_MEDICINE',
                'ECG',
                'SPIROMETRY',
                'PULSE_OXIMETRY',
                'ENDOSCOPY',
                'BIOPSY',
                'OTHER'
            )
        ),

    sort_order           INTEGER NOT NULL DEFAULT 0,

    status               TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation_method IS
'Technique or assay used to obtain an investigation result.';


-- ============================================================================
-- 4. INVESTIGATION CONCEPT â†” METHOD
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_concept_method (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    method_code                TEXT NOT NULL
        REFERENCES knowledge.investigation_method(method_code),

    is_preferred               BOOLEAN NOT NULL DEFAULT false,

    availability_context_codes TEXT[] NOT NULL DEFAULT '{}',

    turnaround_time_minutes   INTEGER,

    requires_specimen          BOOLEAN NOT NULL DEFAULT true,

    preparation_requirements   TEXT,

    method_notes               TEXT,

    is_active                  BOOLEAN NOT NULL DEFAULT true,

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        method_code
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_concept_method_concept
    ON knowledge.investigation_concept_method(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_inv_concept_method_method
    ON knowledge.investigation_concept_method(method_code);


-- ============================================================================
-- 5. INVESTIGATION SPECIMEN
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_specimen (
    specimen_code       TEXT PRIMARY KEY,

    name                TEXT NOT NULL,
    description         TEXT,

    specimen_category   TEXT
        CHECK (
            specimen_category IN (
                'BLOOD',
                'URINE',
                'RESPIRATORY',
                'CSF',
                'STOOL',
                'TISSUE',
                'BODY_FLUID',
                'SWAB',
                'BONE_MARROW',
                'SALIVA',
                'SEMEN',
                'IMAGE',
                'DEVICE_SIGNAL',
                'NONE',
                'OTHER'
            )
        ),

    collection_site     TEXT,
    collection_method   TEXT,
    container_type      TEXT,

    sort_order          INTEGER NOT NULL DEFAULT 0,

    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation_specimen IS
'Knowledge definition of the specimen or study required by an investigation.';


-- ============================================================================
-- 6. INVESTIGATION CONCEPT â†” SPECIMEN
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_concept_specimen (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    specimen_code              TEXT NOT NULL
        REFERENCES knowledge.investigation_specimen(specimen_code),

    is_preferred               BOOLEAN NOT NULL DEFAULT false,

    collection_requirements    TEXT,

    timing_requirements        TEXT,

    minimum_volume             NUMERIC,

    minimum_volume_unit        TEXT,

    rejection_criteria         TEXT,

    transport_requirements     TEXT,

    storage_requirements       TEXT,

    is_active                  BOOLEAN NOT NULL DEFAULT true,

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        specimen_code
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_concept_specimen_concept
    ON knowledge.investigation_concept_specimen(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_inv_concept_specimen_specimen
    ON knowledge.investigation_concept_specimen(specimen_code);


-- ============================================================================
-- 7. INVESTIGATION COMPONENT
-- ============================================================================
--
-- Composite investigations expose individual canonical components.
--
-- CBC:
--   Hb
--   WBC
--   neutrophils
--   lymphocytes
--   platelets
--   MCV
--   etc.
--
-- Each component can become a canonical fact.
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.investigation_component CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.investigation_component (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    component_code             TEXT NOT NULL,

    fact_definition_code       TEXT NOT NULL
        REFERENCES clinical.fact_definition(code),

    name                       TEXT NOT NULL,
    short_label                TEXT,

    value_type                 TEXT NOT NULL
        CHECK (
            value_type IN (
                'NUMERIC',
                'CATEGORICAL',
                'TEXT',
                'BOOLEAN',
                'DATE',
                'DATETIME'
            )
        ),

    canonical_unit_code        TEXT,

    sort_order                 INTEGER NOT NULL DEFAULT 0,

    is_mandatory               BOOLEAN NOT NULL DEFAULT true,

    status                     TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        component_code
    )
);

COMMENT ON TABLE knowledge.investigation_component IS
'Canonical measurable or observable component of a composite investigation.';


CREATE INDEX IF NOT EXISTS idx_inv_component_fact
    ON knowledge.investigation_component(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_inv_component_inv
    ON knowledge.investigation_component(investigation_concept_code);


-- ============================================================================
-- 8. INVESTIGATION PURPOSE
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_purpose (
    purpose_code    TEXT PRIMARY KEY,

    code            TEXT NOT NULL UNIQUE,

    label           TEXT NOT NULL,
    description     TEXT,

    sort_order      INTEGER NOT NULL DEFAULT 0,

    status          TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation_purpose IS
'First-class clinical purpose of an investigation.';


-- ============================================================================
-- 9. INVESTIGATION INDICATION
-- ============================================================================
--
-- Defines:
--
--   phenotype/fact/context
--          â†“
--   clinical question
--          â†“
--   investigation
--          â†“
--   purpose
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_indication (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    purpose_code               TEXT NOT NULL
        REFERENCES knowledge.investigation_purpose(purpose_code),

    clinical_question          TEXT NOT NULL,

    trigger_fact_codes         TEXT[] NOT NULL DEFAULT '{}',

    trigger_phenotype_codes    TEXT[] NOT NULL DEFAULT '{}',

    trigger_symptom_codes      TEXT[] NOT NULL DEFAULT '{}',

    context_codes              TEXT[] NOT NULL DEFAULT '{}',

    exclusion_fact_codes       TEXT[] NOT NULL DEFAULT '{}',

    evidence_claim_code        TEXT
        REFERENCES knowledge.source_claim(claim_code),

    strength                   TEXT NOT NULL DEFAULT 'moderate'
        CHECK (strength IN ('strong', 'moderate', 'weak')),

    is_active                  BOOLEAN NOT NULL DEFAULT true,

    status                     TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        purpose_code,
        clinical_question
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_indication_inv
    ON knowledge.investigation_indication(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_inv_indication_purpose
    ON knowledge.investigation_indication(purpose_code);


-- ============================================================================
-- 10. INVESTIGATION RULE
-- ============================================================================
--
-- DATA-DRIVEN SELECTION / SAFETY / ACTIVATION ENGINE.
--
-- The CPU never hard-codes:
--
--   if pneumonia -> CXR
--
-- Instead rules activate concepts based on clinical state.
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.investigation_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.investigation_rule (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code                   TEXT NOT NULL UNIQUE,

    trigger_type                TEXT NOT NULL
        CHECK (
            trigger_type IN (
                'ALWAYS',
                'CONTEXT',
                'FACT',
                'SYMPTOM_SIGN',
                'PHENOTYPE',
                'INVESTIGATION_RESULT'
            )
        ),

    trigger_code                TEXT,

    investigation_concept_code  TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    modification                TEXT NOT NULL
        CHECK (
            modification IN (
                'SAFETY_BLOCK',
                'SAFETY_PRECAUTION',
                'MANDATORY',
                'ACTIVATE',
                'UNAVAILABLE',
                'CONDITIONAL',
                'PRIORITY',
                'DEPENDENCY',
                'ALTERNATIVE'
            )
        ),

    priority_delta              INTEGER NOT NULL DEFAULT 0,

    rationale                   TEXT,

    evidence_claim_code         TEXT
        REFERENCES knowledge.source_claim(claim_code),

    applies_to_context_codes    TEXT[] NOT NULL DEFAULT '{}',

    is_active                   BOOLEAN NOT NULL DEFAULT true,

    status                      TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        trigger_type,
        trigger_code,
        modification
    )
);

COMMENT ON TABLE knowledge.investigation_rule IS
'Universal investigation selection, safety, dependency and prioritisation rule layer.';


CREATE INDEX IF NOT EXISTS idx_inv_rule_target
    ON knowledge.investigation_rule(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_inv_rule_trigger
    ON knowledge.investigation_rule(trigger_type, trigger_code);


-- ============================================================================
-- 11. INVESTIGATION RULE CONDITION
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_rule_condition (
    condition_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code             TEXT NOT NULL
        REFERENCES knowledge.investigation_rule(rule_code)
        ON DELETE CASCADE,

    condition_code        TEXT NOT NULL,

    fact_definition_code  TEXT NOT NULL
        REFERENCES clinical.fact_definition(code),

    operator              TEXT NOT NULL
        CHECK (
            operator IN (
                '=',
                '!=',
                '>',
                '>=',
                '<',
                '<=',
                'IN',
                'NOT_IN',
                'BETWEEN',
                'IS_TRUE',
                'IS_FALSE',
                'IS_PRESENT',
                'IS_ABSENT'
            )
        ),

    value                 TEXT,

    rationale             TEXT,

    is_active             BOOLEAN NOT NULL DEFAULT true,

    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        rule_code,
        condition_code
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_rule_condition_rule
    ON knowledge.investigation_rule_condition(rule_code);


-- ============================================================================
-- 12. INVESTIGATION RULE ACTION
-- ============================================================================
--
-- Dependencies and secondary effects.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_rule_action (
    action_id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code                    TEXT NOT NULL
        REFERENCES knowledge.investigation_rule(rule_code)
        ON DELETE CASCADE,

    action_type                  TEXT NOT NULL
        CHECK (
            action_type IN (
                'REQUIRE_RESULT_BEFORE',
                'REQUEST_ALONGSIDE',
                'DEFER',
                'BLOCK',
                'PREFER_ALTERNATIVE',
                'REPEAT_AFTER_INTERVAL'
            )
        ),

    target_investigation_code    TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code),

    interval_minutes             INTEGER,

    rationale                    TEXT,

    sort_order                   INTEGER NOT NULL DEFAULT 0,

    is_active                    BOOLEAN NOT NULL DEFAULT true,

    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        rule_code,
        action_type,
        target_investigation_code
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_rule_action_rule
    ON knowledge.investigation_rule_action(rule_code);


-- ============================================================================
-- 13. INVESTIGATION SAFETY RULE
-- ============================================================================
--
-- Explicit safety semantics rather than one generic "safety" flag.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_safety_rule (
    safety_rule_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    safety_rule_code           TEXT NOT NULL UNIQUE,

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    trigger_type               TEXT NOT NULL
        CHECK (
            trigger_type IN (
                'FACT',
                'CONTEXT',
                'SYMPTOM_SIGN',
                'PHENOTYPE',
                'ALWAYS'
            )
        ),

    trigger_code               TEXT,

    safety_effect              TEXT NOT NULL
        CHECK (
            safety_effect IN (
                'SAFE',
                'PRECAUTION',
                'PREREQUISITE',
                'BLOCK',
                'DEFER',
                'ALTERNATIVE_REQUIRED'
            )
        ),

    rationale                  TEXT,

    alternative_investigation_code TEXT
        REFERENCES knowledge.investigation_concept(code),

    evidence_claim_code        TEXT
        REFERENCES knowledge.source_claim(claim_code),

    applies_to_context_codes   TEXT[] NOT NULL DEFAULT '{}',

    is_active                  BOOLEAN NOT NULL DEFAULT true,

    status                     TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'superseded', 'retired')),

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_safety_concept
    ON knowledge.investigation_safety_rule(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_inv_safety_trigger
    ON knowledge.investigation_safety_rule(trigger_type, trigger_code);


-- ============================================================================
-- 14. INVESTIGATION PRIORITY DIMENSION
-- ============================================================================
--
-- Clinical priority and operational feasibility are deliberately separated.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_priority_dimension (
    priority_dimension_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    dimension_code        TEXT NOT NULL UNIQUE,

    dimension_group       TEXT NOT NULL
        CHECK (
            dimension_group IN (
                'CLINICAL',
                'OPERATIONAL'
            )
        ),

    dimension              TEXT NOT NULL,

    direction              TEXT NOT NULL DEFAULT 'POSITIVE'
        CHECK (
            direction IN (
                'POSITIVE',
                'NEGATIVE'
            )
        ),

    weight                NUMERIC(6,3) NOT NULL DEFAULT 1.000,

    description           TEXT,

    version               INTEGER NOT NULL DEFAULT 1,

    effective_from        DATE,
    effective_to          DATE,

    status                TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        dimension_group,
        dimension,
        version
    )
);

COMMENT ON TABLE knowledge.investigation_priority_dimension IS
'Versioned investigation priority dimensions. Clinical appropriateness is separated from operational feasibility.';


-- ============================================================================
-- 15. UNIT SYSTEM
-- ============================================================================
--
-- Raw units are preserved.
-- Canonical units enable comparison.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.measurement_unit (
    unit_code             TEXT PRIMARY KEY,

    symbol                TEXT NOT NULL UNIQUE,

    name                  TEXT NOT NULL,

    quantity_type         TEXT NOT NULL,

    is_si                  BOOLEAN NOT NULL DEFAULT false,

    canonical_unit_code   TEXT,

    conversion_factor     NUMERIC,

    conversion_offset     NUMERIC DEFAULT 0,

    status                TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.measurement_unit IS
'Universal measurement unit vocabulary and canonical conversion metadata.';


-- Self-reference added after table creation.
ALTER TABLE knowledge.measurement_unit
    DROP CONSTRAINT IF EXISTS fk_measurement_unit_canonical;

ALTER TABLE knowledge.measurement_unit
    ADD CONSTRAINT fk_measurement_unit_canonical
    FOREIGN KEY (canonical_unit_code)
    REFERENCES knowledge.measurement_unit(unit_code);


-- ============================================================================
-- 16. RESULT REFERENCE STANDARD
-- ============================================================================
--
-- RAW RESULT DOES NOT MEAN NORMAL / ABNORMAL BY ITSELF.
--
-- The CPU selects the correct standard using:
--
--   age
--   sex
--   pregnancy
--   gestational age
--   context
--   method
--   laboratory
--   population
--   geography
--   altitude
--   unit
--   version
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.result_reference_standard (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                       TEXT NOT NULL UNIQUE,

    investigation_concept_code TEXT
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    component_code             TEXT,

    fact_definition_code       TEXT
        REFERENCES clinical.fact_definition(code),

    method_code                TEXT
        REFERENCES knowledge.investigation_method(method_code),

    standard_type              TEXT NOT NULL DEFAULT 'REFERENCE_INTERVAL'
        CHECK (
            standard_type IN (
                'REFERENCE_INTERVAL',
                'CLINICAL_DECISION_THRESHOLD',
                'DIAGNOSTIC_THRESHOLD',
                'SCREENING_THRESHOLD',
                'CRITICAL_VALUE',
                'THERAPEUTIC_RANGE',
                'TARGET_RANGE'
            )
        ),

    applies_to_context_codes   TEXT[] NOT NULL DEFAULT '{}',

    sex                        TEXT NOT NULL DEFAULT 'ANY'
        CHECK (
            sex IN (
                'MALE',
                'FEMALE',
                'INTERSEX',
                'ANY'
            )
        ),

    age_min_days               INTEGER,
    age_max_days               INTEGER,

    gestational_age_min_days  INTEGER,
    gestational_age_max_days  INTEGER,

    postpartum_min_days       INTEGER,
    postpartum_max_days       INTEGER,

    geographic_region_code    TEXT,

    altitude_min_m            INTEGER,
    altitude_max_m            INTEGER,

    population_description    TEXT,

    laboratory_identifier     TEXT,

    range_low                 NUMERIC,
    range_high                NUMERIC,

    threshold_operator        TEXT
        CHECK (
            threshold_operator IS NULL
            OR threshold_operator IN (
                '<',
                '<=',
                '=',
                '>=',
                '>'
            )
        ),

    threshold_value           NUMERIC,

    range_unit_code           TEXT
        REFERENCES knowledge.measurement_unit(unit_code),

    lower_inclusive           BOOLEAN NOT NULL DEFAULT true,
    upper_inclusive           BOOLEAN NOT NULL DEFAULT true,

    classification            TEXT NOT NULL DEFAULT 'NORMAL'
        CHECK (
            classification IN (
                'NORMAL',
                'ABNORMAL',
                'CRITICAL',
                'TARGET',
                'THERAPEUTIC',
                'DECISION_POSITIVE',
                'DECISION_NEGATIVE'
            )
        ),

    source_version_id         TEXT
        REFERENCES knowledge.source_version(version_id),

    source_claim_code         TEXT
        REFERENCES knowledge.source_claim(claim_code),

    evidence_strength         TEXT NOT NULL DEFAULT 'strong'
        CHECK (
            evidence_strength IN (
                'strong',
                'moderate',
                'weak'
            )
        ),

    effective_from            DATE,
    effective_to              DATE,

    status                    TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'retired'
            )
        ),

    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.result_reference_standard IS
'Contextual and versioned reference/decision standards. The raw value is interpreted only after selecting the appropriate standard.';


CREATE INDEX IF NOT EXISTS idx_result_refstd_concept
    ON knowledge.result_reference_standard(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_result_refstd_fact
    ON knowledge.result_reference_standard(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_result_refstd_method
    ON knowledge.result_reference_standard(method_code);

CREATE INDEX IF NOT EXISTS idx_result_refstd_context
    ON knowledge.result_reference_standard
    USING GIN(applies_to_context_codes);


-- ============================================================================
-- 17. INVESTIGATION VERSION
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_version (
    version_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    version_no               INTEGER NOT NULL,

    effective_from           DATE,
    effective_to             DATE,

    supersedes               UUID
        REFERENCES knowledge.investigation_version(version_id),

    change_note              TEXT,

    source_version_id        TEXT
        REFERENCES knowledge.source_version(version_id),

    status                   TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        version_no
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_version_concept
    ON knowledge.investigation_version(investigation_concept_code);


-- ============================================================================
-- 18. INVESTIGATION SOURCE
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_source (
    source_id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    source_version_id         TEXT NOT NULL
        REFERENCES knowledge.source_version(version_id),

    reference                 TEXT,

    organization              TEXT,
    publication               TEXT,
    edition                   TEXT,
    year                      INTEGER,

    chapter_ref               TEXT,
    section_ref               TEXT,

    effective_from            DATE,
    effective_to              DATE,

    status                    TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_concept_code,
        source_version_id
    )
);


-- ============================================================================
-- 19. RESULT INTERPRETATION
-- ============================================================================
--
-- Controlled interpretation vocabulary.
--
-- Examples:
--
--   LEUKOCYTOSIS
--   ANAEMIA
--   MICROCYTOSIS
--   AIRSPACE_CONSOLIDATION
--   PLEURAL_EFFUSION
--   PNEUMOTHORAX
--   ATRIAL_FIBRILLATION
--   MTB_DETECTED
--
-- These are NOT diagnoses.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.result_interpretation (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code                     TEXT NOT NULL UNIQUE,

    canonical_name           TEXT NOT NULL,
    label                    TEXT NOT NULL,

    result_type_constraint   TEXT
        CHECK (
            result_type_constraint IS NULL
            OR result_type_constraint IN (
                'LAB',
                'IMAGING',
                'MICROBIOLOGY',
                'PHYSIOLOGY',
                'PATHOLOGY',
                'MOLECULAR'
            )
        ),

    is_abnormal              BOOLEAN NOT NULL DEFAULT false,
    is_critical              BOOLEAN NOT NULL DEFAULT false,

    description              TEXT,

    sort_order               INTEGER NOT NULL DEFAULT 0,

    status                   TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_result_interp_abnormal
    ON knowledge.result_interpretation(is_abnormal);


-- ============================================================================
-- 20. RESULT INTERPRETATION RULE
-- ============================================================================
--
-- THIS IS CRITICAL.
--
-- result_interpretation is vocabulary.
-- result_interpretation_rule tells the CPU WHEN that interpretation applies.
--
-- Example:
--
--   WBC > age-adjusted upper reference
--        â†“
--   LEUKOCYTOSIS
--
-- Example:
--
--   CXR finding = consolidation
--        â†“
--   AIRSPACE_CONSOLIDATION
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.result_interpretation_rule (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code                  TEXT NOT NULL UNIQUE,

    investigation_concept_code TEXT
        REFERENCES knowledge.investigation_concept(code)
        ON DELETE CASCADE,

    component_code             TEXT,

    fact_definition_code       TEXT
        REFERENCES clinical.fact_definition(code),

    interpretation_code        TEXT NOT NULL
        REFERENCES knowledge.result_interpretation(code)
        ON DELETE CASCADE,

    condition_type             TEXT NOT NULL
        CHECK (
            condition_type IN (
                'NUMERIC_THRESHOLD',
                'CATEGORICAL_VALUE',
                'TEXT_MATCH',
                'BOOLEAN_STATE',
                'FINDING_PRESENT',
                'FINDING_ABSENT',
                'ORGANISM_PRESENT',
                'SUSCEPTIBILITY_PATTERN'
            )
        ),

    operator                   TEXT
        CHECK (
            operator IS NULL
            OR operator IN (
                '=',
                '!=',
                '>',
                '>=',
                '<',
                '<=',
                'IN',
                'NOT_IN',
                'BETWEEN'
            )
        ),

    threshold_low              NUMERIC,
    threshold_high             NUMERIC,
    threshold_value            NUMERIC,

    categorical_value          TEXT,

    finding_concept_code       TEXT,

    organism_concept_code      TEXT,

    applies_to_context_codes   TEXT[] NOT NULL DEFAULT '{}',

    priority                   INTEGER NOT NULL DEFAULT 0,

    rationale                  TEXT,

    evidence_claim_code        TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active                  BOOLEAN NOT NULL DEFAULT true,

    status                     TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_result_interp_rule_concept
    ON knowledge.result_interpretation_rule(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_result_interp_rule_fact
    ON knowledge.result_interpretation_rule(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_result_interp_rule_interpretation
    ON knowledge.result_interpretation_rule(interpretation_code);


-- ============================================================================
-- 21. RESULT PHENOTYPE LINK
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.result_phenotype_link (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    result_interpretation_code  TEXT NOT NULL
        REFERENCES knowledge.result_interpretation(code)
        ON DELETE CASCADE,

    associated_concept_code     TEXT NOT NULL,

    relationship_type           TEXT NOT NULL DEFAULT 'SUPPORTS'
        CHECK (
            relationship_type IN (
                'SUPPORTS',
                'NEGATES',
                'INDICATES',
                'ASSOCIATED_WITH'
            )
        ),

    strength                    TEXT NOT NULL DEFAULT 'moderate'
        CHECK (
            strength IN (
                'strong',
                'moderate',
                'weak'
            )
        ),

    description                 TEXT,

    evidence_claim_code         TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active                   BOOLEAN NOT NULL DEFAULT true,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        result_interpretation_code,
        associated_concept_code,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.result_phenotype_link IS
'Links interpreted investigation findings to canonical phenotypes/concepts consumed downstream by H8.';


-- ============================================================================
-- 22. IMAGING FINDING VOCABULARY
-- ============================================================================
--
-- Imaging requires structured controlled findings and anatomical localization.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.imaging_finding (
    finding_code        TEXT PRIMARY KEY,

    canonical_name      TEXT NOT NULL,
    label               TEXT NOT NULL,

    finding_category    TEXT,

    description         TEXT,

    sort_order          INTEGER NOT NULL DEFAULT 0,

    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 23. ANATOMICAL INVESTIGATION SITE
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_anatomical_site (
    site_code           TEXT PRIMARY KEY,

    canonical_name      TEXT NOT NULL,
    label               TEXT NOT NULL,

    parent_site_code    TEXT
        REFERENCES knowledge.investigation_anatomical_site(site_code),

    laterality_allowed  BOOLEAN NOT NULL DEFAULT false,

    sort_order          INTEGER NOT NULL DEFAULT 0,

    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 24. MICROBIOLOGY ORGANISM
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.microbiology_organism (
    organism_code       TEXT PRIMARY KEY,

    canonical_name      TEXT NOT NULL,
    scientific_name     TEXT,

    organism_group      TEXT,

    gram_class          TEXT,

    description         TEXT,

    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 25. ANTIMICROBIAL
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.antimicrobial (
    antimicrobial_code  TEXT PRIMARY KEY,

    canonical_name      TEXT NOT NULL,

    drug_class          TEXT,

    description         TEXT,

    status              TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 26. INVESTIGATION STATUS
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_status (
    status_code     TEXT PRIMARY KEY,

    label           TEXT NOT NULL,
    description     TEXT,

    sort_order      INTEGER NOT NULL DEFAULT 0,

    is_terminal     BOOLEAN NOT NULL DEFAULT false,

    status          TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'draft', 'retired')),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 27. CLINICAL INVESTIGATION REQUEST
-- ============================================================================
--
-- IMPORTANT:
--
-- This is OPERATIONAL data.
-- It belongs in clinical, NOT knowledge.
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_request (
    request_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id           UUID NOT NULL,

    patient_id             UUID,

    context_stack          JSONB NOT NULL DEFAULT '{}'::jsonb,

    overarching_purpose_code TEXT
        REFERENCES knowledge.investigation_purpose(purpose_code),

    clinical_priority      INTEGER,

    operational_priority   INTEGER,

    final_priority         INTEGER,

    priority_class         TEXT
        CHECK (
            priority_class IN (
                'CRITICAL',
                'URGENT',
                'HIGH',
                'MEDIUM',
                'ROUTINE'
            )
        ),

    status_code            TEXT NOT NULL DEFAULT 'RECOMMENDED'
        REFERENCES knowledge.investigation_status(status_code),

    recommendation_reason  TEXT,

    requested_by            TEXT,

    requested_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clin_inv_request_encounter
    ON clinical.investigation_request(encounter_id);

CREATE INDEX IF NOT EXISTS idx_clin_inv_request_patient
    ON clinical.investigation_request(patient_id);

CREATE INDEX IF NOT EXISTS idx_clin_inv_request_status
    ON clinical.investigation_request(status_code);


-- ============================================================================
-- 28. CLINICAL INVESTIGATION REQUEST ITEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_request_item (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    request_id                  UUID NOT NULL
        REFERENCES clinical.investigation_request(request_id)
        ON DELETE CASCADE,

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code),

    purpose_code                TEXT
        REFERENCES knowledge.investigation_purpose(purpose_code),

    clinical_question           TEXT,

    clinical_priority           INTEGER NOT NULL DEFAULT 0,

    operational_feasibility    INTEGER NOT NULL DEFAULT 0,

    final_priority              INTEGER NOT NULL DEFAULT 0,

    priority_class              TEXT
        CHECK (
            priority_class IN (
                'CRITICAL',
                'URGENT',
                'HIGH',
                'MEDIUM',
                'ROUTINE'
            )
        ),

    safety_state                TEXT
        CHECK (
            safety_state IN (
                'SAFE',
                'PRECAUTION',
                'PREREQUISITE_REQUIRED',
                'BLOCKED',
                'DEFERRED',
                'ALTERNATIVE_REQUIRED'
            )
        ),

    reason                      TEXT,

    triggering_fact_codes       TEXT[] NOT NULL DEFAULT '{}',
    triggering_phenotype_codes  TEXT[] NOT NULL DEFAULT '{}',

    evidence_rule_code          TEXT
        REFERENCES knowledge.investigation_rule(rule_code),

    status_code                 TEXT NOT NULL DEFAULT 'RECOMMENDED'
        REFERENCES knowledge.investigation_status(status_code),

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        request_id,
        investigation_concept_code
    )
);

CREATE INDEX IF NOT EXISTS idx_clin_inv_item_request
    ON clinical.investigation_request_item(request_id);

CREATE INDEX IF NOT EXISTS idx_clin_inv_item_concept
    ON clinical.investigation_request_item(investigation_concept_code);


-- ============================================================================
-- 29. CLINICAL SPECIMEN COLLECTION
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.specimen_collection (
    collection_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    request_item_id        UUID NOT NULL
        REFERENCES clinical.investigation_request_item(id)
        ON DELETE CASCADE,

    specimen_code          TEXT NOT NULL
        REFERENCES knowledge.investigation_specimen(specimen_code),

    collection_site        TEXT,

    collection_method      TEXT,

    condition_description  TEXT,

    laboratory             TEXT,

    collected_at           TIMESTAMPTZ,

    collected_by           TEXT,

    adequacy               TEXT
        CHECK (
            adequacy IN (
                'ADEQUATE',
                'INADEQUATE',
                'CONTAMINATED',
                'INSUFFICIENT',
                'UNKNOWN'
            )
        ),

    rejection_reason       TEXT,

    status_code            TEXT NOT NULL DEFAULT 'SPECIMEN_COLLECTED'
        REFERENCES knowledge.investigation_status(status_code),

    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clin_specimen_request_item
    ON clinical.specimen_collection(request_item_id);


-- ============================================================================
-- 30. CLINICAL SPECIMEN PROCESSING
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.specimen_processing (
    processing_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    collection_id       UUID NOT NULL
        REFERENCES clinical.specimen_collection(collection_id)
        ON DELETE CASCADE,

    method_code         TEXT
        REFERENCES knowledge.investigation_method(method_code),

    laboratory          TEXT,

    received_at         TIMESTAMPTZ,

    processor           TEXT,

    processing_notes    TEXT,

    quality_status      TEXT
        CHECK (
            quality_status IN (
                'ACCEPTED',
                'REJECTED',
                'QUESTIONABLE',
                'NOT_ASSESSED'
            )
        ),

    status_code         TEXT NOT NULL DEFAULT 'IN_PROGRESS'
        REFERENCES knowledge.investigation_status(status_code),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 31. CLINICAL RESULT
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.result CASCADE;
CREATE TABLE IF NOT EXISTS clinical.result (
    result_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    request_item_id         UUID NOT NULL
        REFERENCES clinical.investigation_request_item(id)
        ON DELETE CASCADE,

    investigation_concept_code TEXT NOT NULL
        REFERENCES knowledge.investigation_concept(code),

    investigation_version_id UUID
        REFERENCES knowledge.investigation_version(version_id),

    collection_id           UUID
        REFERENCES clinical.specimen_collection(collection_id),

    method_code             TEXT
        REFERENCES knowledge.investigation_method(method_code),

    result_structure        TEXT NOT NULL
        CHECK (
            result_structure IN (
                'NUMERIC',
                'COMPONENT_PANEL',
                'STRUCTURED_FINDINGS',
                'MICROBIOLOGY',
                'PATHOLOGY',
                'MIXED'
            )
        ),

    status_code             TEXT NOT NULL DEFAULT 'RESULT_AVAILABLE'
        REFERENCES knowledge.investigation_status(status_code),

    resulted_at             TIMESTAMPTZ,

    resulted_by             TEXT,

    laboratory_identifier   TEXT,

    source_system           TEXT,

    report_text             TEXT,

    notes                   TEXT,

    is_final                BOOLEAN NOT NULL DEFAULT false,

    entered_in_error        BOOLEAN NOT NULL DEFAULT false,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clin_result_request_item
    ON clinical.result(request_item_id);

CREATE INDEX IF NOT EXISTS idx_clin_result_concept
    ON clinical.result(investigation_concept_code);

CREATE INDEX IF NOT EXISTS idx_clin_result_collection
    ON clinical.result(collection_id);


-- ============================================================================
-- 32. CLINICAL RESULT COMPONENT
-- ============================================================================
--
-- Structured result findings.
--
-- Supports:
--   laboratory components
--   imaging findings
--   pathology observations
--   microbiology observations
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.result_component (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    result_id               UUID NOT NULL
        REFERENCES clinical.result(result_id)
        ON DELETE CASCADE,

    component_code          TEXT,

    fact_definition_code    TEXT
        REFERENCES clinical.fact_definition(code),

    finding_code            TEXT
        REFERENCES knowledge.imaging_finding(finding_code),

    finding                 TEXT,

    anatomical_site_code    TEXT
        REFERENCES knowledge.investigation_anatomical_site(site_code),

    laterality              TEXT
        CHECK (
            laterality IN (
                'LEFT',
                'RIGHT',
                'BILATERAL',
                'MIDLINE',
                'NONE'
            )
        ),

    severity                TEXT,

    certainty               TEXT,

    interpretation_code     TEXT
        REFERENCES knowledge.result_interpretation(code),

    is_abnormal             BOOLEAN,

    status                  TEXT NOT NULL DEFAULT 'recorded'
        CHECK (
            status IN (
                'recorded',
                'entered',
                'final',
                'entered_in_error'
            )
        ),

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clin_result_component_result
    ON clinical.result_component(result_id);

CREATE INDEX IF NOT EXISTS idx_clin_result_component_finding
    ON clinical.result_component(finding_code);

CREATE INDEX IF NOT EXISTS idx_clin_result_component_site
    ON clinical.result_component(anatomical_site_code);


-- ============================================================================
-- 33. CLINICAL RESULT VALUE
-- ============================================================================
--
-- RAW MEASUREMENT IS PRESERVED.
--
-- value_numeric + original_unit_code
--       â†“
-- canonical_value_numeric + canonical_unit_code
--       â†“
-- reference standard
--       â†“
-- classification
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.result_value (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    result_id                UUID NOT NULL
        REFERENCES clinical.result(result_id)
        ON DELETE CASCADE,

    result_component_id      UUID
        REFERENCES clinical.result_component(id),

    fact_definition_code     TEXT NOT NULL
        REFERENCES clinical.fact_definition(code),

    value_numeric            NUMERIC,
    value_text               TEXT,
    value_boolean            BOOLEAN,

    original_unit_code       TEXT
        REFERENCES knowledge.measurement_unit(unit_code),

    canonical_value_numeric  NUMERIC,

    canonical_unit_code      TEXT
        REFERENCES knowledge.measurement_unit(unit_code),

    conversion_applied       BOOLEAN NOT NULL DEFAULT false,

    conversion_rule          TEXT,

    reference_standard_code  TEXT
        REFERENCES knowledge.result_reference_standard(code),

    classification            TEXT NOT NULL DEFAULT 'UNMEASURED'
        CHECK (
            classification IN (
                'NORMAL',
                'ABNORMAL',
                'CRITICAL',
                'TARGET',
                'THERAPEUTIC',
                'DECISION_POSITIVE',
                'DECISION_NEGATIVE',
                'UNMEASURED'
            )
        ),

    interpretation_code      TEXT
        REFERENCES knowledge.result_interpretation(code),

    is_abnormal              BOOLEAN,

    reference_selection_reason TEXT,

    recorded_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clin_result_value_result
    ON clinical.result_value(result_id);

CREATE INDEX IF NOT EXISTS idx_clin_result_value_fact
    ON clinical.result_value(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_clin_result_value_reference
    ON clinical.result_value(reference_standard_code);


-- ============================================================================
-- 34. MICROBIOLOGY RESULT
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.microbiology_result (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    result_id               UUID NOT NULL
        REFERENCES clinical.result(result_id)
        ON DELETE CASCADE,

    organism_code           TEXT
        REFERENCES knowledge.microbiology_organism(organism_code),

    detection_status        TEXT
        CHECK (
            detection_status IN (
                'DETECTED',
                'NOT_DETECTED',
                'INDETERMINATE',
                'CONTAMINANT',
                'COLONISATION',
                'UNKNOWN'
            )
        ),

    quantity_text           TEXT,

    colony_count            NUMERIC,

    colony_count_unit       TEXT,

    identification_method_code TEXT
        REFERENCES knowledge.investigation_method(method_code),

    comment                 TEXT,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_micro_result_result
    ON clinical.microbiology_result(result_id);

CREATE INDEX IF NOT EXISTS idx_micro_result_organism
    ON clinical.microbiology_result(organism_code);


-- ============================================================================
-- 35. MICROBIOLOGY SUSCEPTIBILITY
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.microbiology_susceptibility (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    microbiology_result_id  UUID NOT NULL
        REFERENCES clinical.microbiology_result(id)
        ON DELETE CASCADE,

    antimicrobial_code      TEXT NOT NULL
        REFERENCES knowledge.antimicrobial(antimicrobial_code),

    interpretation          TEXT
        CHECK (
            interpretation IN (
                'S',
                'I',
                'R',
                'SDD',
                'UNKNOWN'
            )
        ),

    mic_value               NUMERIC,

    mic_unit                TEXT,

    breakpoint_source       TEXT,

    breakpoint_version      TEXT,

    method_code             TEXT
        REFERENCES knowledge.investigation_method(method_code),

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        microbiology_result_id,
        antimicrobial_code
    )
);


-- ============================================================================
-- 36. CLINICAL RESULT INTERPRETATION
-- ============================================================================
--
-- Operational application of knowledge interpretation.
--
-- Knowledge:
--   result_interpretation
--   result_interpretation_rule
--
-- Runtime:
--   clinical.result_interpretation
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.result_interpretation (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    result_id                UUID NOT NULL
        REFERENCES clinical.result(result_id)
        ON DELETE CASCADE,

    result_component_id      UUID
        REFERENCES clinical.result_component(id),

    result_value_id          UUID
        REFERENCES clinical.result_value(id),

    interpretation_code      TEXT NOT NULL
        REFERENCES knowledge.result_interpretation(code),

    rule_code                TEXT
        REFERENCES knowledge.result_interpretation_rule(rule_code),

    confidence               NUMERIC(5,4),

    rationale                TEXT,

    context_snapshot         JSONB NOT NULL DEFAULT '{}'::jsonb,

    is_final                 BOOLEAN NOT NULL DEFAULT false,

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clin_result_interp_result
    ON clinical.result_interpretation(result_id);

CREATE INDEX IF NOT EXISTS idx_clin_result_interp_code
    ON clinical.result_interpretation(interpretation_code);


-- ============================================================================
-- 37. CLINICAL RESULT PHENOTYPE LINK
-- ============================================================================
--
-- Runtime manifestation of result â†’ phenotype.
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.result_phenotype_link (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    result_id                   UUID NOT NULL
        REFERENCES clinical.result(result_id)
        ON DELETE CASCADE,

    result_interpretation_id    UUID
        REFERENCES clinical.result_interpretation(id)
        ON DELETE CASCADE,

    associated_concept_code     TEXT NOT NULL,

    relationship_type           TEXT NOT NULL DEFAULT 'SUPPORTS'
        CHECK (
            relationship_type IN (
                'SUPPORTS',
                'NEGATES',
                'INDICATES',
                'ASSOCIATED_WITH'
            )
        ),

    strength                    TEXT NOT NULL DEFAULT 'moderate'
        CHECK (
            strength IN (
                'strong',
                'moderate',
                'weak'
            )
        ),

    evidence_claim_code         TEXT
        REFERENCES knowledge.source_claim(claim_code),

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        result_id,
        associated_concept_code,
        relationship_type
    )
);


-- ============================================================================
-- 38. INVESTIGATION PROVENANCE
-- ============================================================================
--
-- Explicit source â†’ object provenance.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_provenance (
    provenance_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    object_type                TEXT NOT NULL
        CHECK (
            object_type IN (
                'INVESTIGATION_CONCEPT',
                'INVESTIGATION_COMPONENT',
                'INVESTIGATION_METHOD',
                'INVESTIGATION_SPECIMEN',
                'INVESTIGATION_PURPOSE',
                'INVESTIGATION_INDICATION',
                'INVESTIGATION_RULE',
                'SAFETY_RULE',
                'REFERENCE_STANDARD',
                'INTERPRETATION',
                'INTERPRETATION_RULE',
                'PHENOTYPE_LINK'
            )
        ),

    object_code                TEXT NOT NULL,

    source_claim_code          TEXT NOT NULL
        REFERENCES knowledge.source_claim(claim_code),

    derivation_type            TEXT NOT NULL DEFAULT 'SUPPORTED_BY'
        CHECK (
            derivation_type IN (
                'SUPPORTED_BY',
                'DERIVED_FROM',
                'ADAPTED_FROM',
                'SUPERSEDES',
                'CONTRADICTED_BY'
            )
        ),

    confidence                 TEXT
        CHECK (
            confidence IN (
                'HIGH',
                'MODERATE',
                'LOW'
            )
        ),

    notes                      TEXT,

    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        object_type,
        object_code,
        source_claim_code,
        derivation_type
    )
);


-- ============================================================================
-- 39. INVESTIGATION EXPLANATION
-- ============================================================================
--
-- Operational explanation for WHY the CPU recommended an investigation.
--
-- This is essential for auditability and clinician trust.
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_recommendation_explanation (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    request_item_id             UUID NOT NULL
        REFERENCES clinical.investigation_request_item(id)
        ON DELETE CASCADE,

    clinical_question            TEXT,

    triggering_fact_codes        TEXT[] NOT NULL DEFAULT '{}',

    triggering_phenotype_codes   TEXT[] NOT NULL DEFAULT '{}',

    matched_indication_id        UUID
        REFERENCES knowledge.investigation_indication(id),

    matched_rule_code            TEXT
        REFERENCES knowledge.investigation_rule(rule_code),

    safety_evaluation_summary    TEXT,

    priority_summary             TEXT,

    alternative_considered       TEXT,

    explanation_text             TEXT NOT NULL,

    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 40. PRIORITY SCORE AUDIT
-- ============================================================================
--
-- Never store only the final score.
--
-- The CPU should preserve the dimensions that produced it.
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical.investigation_priority_score (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    request_item_id             UUID NOT NULL
        REFERENCES clinical.investigation_request_item(id)
        ON DELETE CASCADE,

    dimension_code              TEXT NOT NULL,

    raw_factor                  NUMERIC NOT NULL DEFAULT 0,

    weight                      NUMERIC NOT NULL DEFAULT 1,

    contribution                NUMERIC NOT NULL DEFAULT 0,

    score_group                 TEXT NOT NULL
        CHECK (
            score_group IN (
                'CLINICAL',
                'OPERATIONAL'
            )
        ),

    version                     INTEGER NOT NULL DEFAULT 1,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        request_item_id,
        dimension_code,
        version
    )
);


-- ============================================================================
-- 41. TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS trg_inv_domain_updated_at
    ON knowledge.investigation_domain;

CREATE TRIGGER trg_inv_domain_updated_at
BEFORE UPDATE ON knowledge.investigation_domain
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_concept_updated_at
    ON knowledge.investigation_concept;

CREATE TRIGGER trg_inv_concept_updated_at
BEFORE UPDATE ON knowledge.investigation_concept
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_method_updated_at
    ON knowledge.investigation_method;

CREATE TRIGGER trg_inv_method_updated_at
BEFORE UPDATE ON knowledge.investigation_method
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_concept_method_updated_at
    ON knowledge.investigation_concept_method;

CREATE TRIGGER trg_inv_concept_method_updated_at
BEFORE UPDATE ON knowledge.investigation_concept_method
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_specimen_updated_at
    ON knowledge.investigation_specimen;

CREATE TRIGGER trg_inv_specimen_updated_at
BEFORE UPDATE ON knowledge.investigation_specimen
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_concept_specimen_updated_at
    ON knowledge.investigation_concept_specimen;

CREATE TRIGGER trg_inv_concept_specimen_updated_at
BEFORE UPDATE ON knowledge.investigation_concept_specimen
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_component_updated_at
    ON knowledge.investigation_component;

CREATE TRIGGER trg_inv_component_updated_at
BEFORE UPDATE ON knowledge.investigation_component
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_purpose_updated_at
    ON knowledge.investigation_purpose;

CREATE TRIGGER trg_inv_purpose_updated_at
BEFORE UPDATE ON knowledge.investigation_purpose
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_indication_updated_at
    ON knowledge.investigation_indication;

CREATE TRIGGER trg_inv_indication_updated_at
BEFORE UPDATE ON knowledge.investigation_indication
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_rule_updated_at
    ON knowledge.investigation_rule;

CREATE TRIGGER trg_inv_rule_updated_at
BEFORE UPDATE ON knowledge.investigation_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_rule_condition_updated_at
    ON knowledge.investigation_rule_condition;

CREATE TRIGGER trg_inv_rule_condition_updated_at
BEFORE UPDATE ON knowledge.investigation_rule_condition
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_rule_action_updated_at
    ON knowledge.investigation_rule_action;

CREATE TRIGGER trg_inv_rule_action_updated_at
BEFORE UPDATE ON knowledge.investigation_rule_action
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_safety_rule_updated_at
    ON knowledge.investigation_safety_rule;

CREATE TRIGGER trg_inv_safety_rule_updated_at
BEFORE UPDATE ON knowledge.investigation_safety_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_priority_dimension_updated_at
    ON knowledge.investigation_priority_dimension;

CREATE TRIGGER trg_inv_priority_dimension_updated_at
BEFORE UPDATE ON knowledge.investigation_priority_dimension
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_measurement_unit_updated_at
    ON knowledge.measurement_unit;

CREATE TRIGGER trg_measurement_unit_updated_at
BEFORE UPDATE ON knowledge.measurement_unit
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_result_refstd_updated_at
    ON knowledge.result_reference_standard;

CREATE TRIGGER trg_result_refstd_updated_at
BEFORE UPDATE ON knowledge.result_reference_standard
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_version_updated_at
    ON knowledge.investigation_version;

CREATE TRIGGER trg_inv_version_updated_at
BEFORE UPDATE ON knowledge.investigation_version
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_source_updated_at
    ON knowledge.investigation_source;

CREATE TRIGGER trg_inv_source_updated_at
BEFORE UPDATE ON knowledge.investigation_source
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_result_interp_updated_at
    ON knowledge.result_interpretation;

CREATE TRIGGER trg_result_interp_updated_at
BEFORE UPDATE ON knowledge.result_interpretation
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_result_interp_rule_updated_at
    ON knowledge.result_interpretation_rule;

CREATE TRIGGER trg_result_interp_rule_updated_at
BEFORE UPDATE ON knowledge.result_interpretation_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_result_phenotype_link_updated_at
    ON knowledge.result_phenotype_link;

CREATE TRIGGER trg_result_phenotype_link_updated_at
BEFORE UPDATE ON knowledge.result_phenotype_link
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_imaging_finding_updated_at
    ON knowledge.imaging_finding;

CREATE TRIGGER trg_imaging_finding_updated_at
BEFORE UPDATE ON knowledge.imaging_finding
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_site_updated_at
    ON knowledge.investigation_anatomical_site;

CREATE TRIGGER trg_inv_site_updated_at
BEFORE UPDATE ON knowledge.investigation_anatomical_site
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_micro_organism_updated_at
    ON knowledge.microbiology_organism;

CREATE TRIGGER trg_micro_organism_updated_at
BEFORE UPDATE ON knowledge.microbiology_organism
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_antimicrobial_updated_at
    ON knowledge.antimicrobial;

CREATE TRIGGER trg_antimicrobial_updated_at
BEFORE UPDATE ON knowledge.antimicrobial
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_inv_status_updated_at
    ON knowledge.investigation_status;

CREATE TRIGGER trg_inv_status_updated_at
BEFORE UPDATE ON knowledge.investigation_status
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_inv_request_updated_at
    ON clinical.investigation_request;

CREATE TRIGGER trg_clin_inv_request_updated_at
BEFORE UPDATE ON clinical.investigation_request
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_inv_item_updated_at
    ON clinical.investigation_request_item;

CREATE TRIGGER trg_clin_inv_item_updated_at
BEFORE UPDATE ON clinical.investigation_request_item
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_specimen_collection_updated_at
    ON clinical.specimen_collection;

CREATE TRIGGER trg_clin_specimen_collection_updated_at
BEFORE UPDATE ON clinical.specimen_collection
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_specimen_processing_updated_at
    ON clinical.specimen_processing;

CREATE TRIGGER trg_clin_specimen_processing_updated_at
BEFORE UPDATE ON clinical.specimen_processing
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_result_updated_at
    ON clinical.result;

CREATE TRIGGER trg_clin_result_updated_at
BEFORE UPDATE ON clinical.result
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_result_component_updated_at
    ON clinical.result_component;

CREATE TRIGGER trg_clin_result_component_updated_at
BEFORE UPDATE ON clinical.result_component
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_result_value_updated_at
    ON clinical.result_value;

CREATE TRIGGER trg_clin_result_value_updated_at
BEFORE UPDATE ON clinical.result_value
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_micro_result_updated_at
    ON clinical.microbiology_result;

CREATE TRIGGER trg_micro_result_updated_at
BEFORE UPDATE ON clinical.microbiology_result
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_micro_susc_updated_at
    ON clinical.microbiology_susceptibility;

CREATE TRIGGER trg_micro_susc_updated_at
BEFORE UPDATE ON clinical.microbiology_susceptibility
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_result_interp_updated_at
    ON clinical.result_interpretation;

CREATE TRIGGER trg_clin_result_interp_updated_at
BEFORE UPDATE ON clinical.result_interpretation
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clin_result_pheno_updated_at
    ON clinical.result_phenotype_link;

CREATE TRIGGER trg_clin_result_pheno_updated_at
BEFORE UPDATE ON clinical.result_phenotype_link
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 42. SEED UNIVERSAL INVESTIGATION DOMAINS
-- ============================================================================

INSERT INTO knowledge.investigation_domain
    (domain_code, code, label, description, sort_order)
VALUES
    ('IDOM01', 'HAEMATOLOGY',
        'Haematology',
        'Investigation of blood cells, haemoglobin, coagulation and related haematological processes.',
        10),

    ('IDOM02', 'BIOCHEMISTRY',
        'Clinical Biochemistry',
        'Measurement of biochemical substances and metabolic function.',
        20),

    ('IDOM03', 'MICROBIOLOGY',
        'Microbiology',
        'Detection, identification and susceptibility assessment of microorganisms.',
        30),

    ('IDOM04', 'IMMUNOLOGY',
        'Immunology',
        'Investigation of immune responses, antibodies, autoantibodies and immune-mediated disease.',
        40),

    ('IDOM05', 'IMAGING',
        'Medical Imaging',
        'Structural and functional imaging investigations.',
        50),

    ('IDOM06', 'PHYSIOLOGY',
        'Physiology',
        'Functional physiological measurements and physiological response testing.',
        60),

    ('IDOM07', 'PATHOLOGY',
        'Pathology',
        'Cytology, histopathology and tissue-based diagnostic investigation.',
        70),

    ('IDOM08', 'MOLECULAR',
        'Molecular Diagnostics',
        'Molecular detection and characterisation of disease-related targets.',
        80),

    ('IDOM09', 'GENETICS',
        'Genetics',
        'Genetic and genomic investigations.',
        90),

    ('IDOM10', 'TOXICOLOGY',
        'Toxicology',
        'Detection and measurement of drugs, poisons and toxic substances.',
        100)

ON CONFLICT (domain_code)
DO UPDATE SET
    code = EXCLUDED.code,
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 43. SEED INVESTIGATION PURPOSES
-- ============================================================================

INSERT INTO knowledge.investigation_purpose
    (purpose_code, code, label, description, sort_order)
VALUES
    ('PUR001', 'DIAGNOSIS',
        'Diagnosis',
        'Support establishment of the nature of a clinical problem.',
        10),

    ('PUR002', 'CONFIRMATION',
        'Confirmation',
        'Confirm a suspected clinical finding or condition.',
        20),

    ('PUR003', 'EXCLUSION',
        'Exclusion',
        'Provide evidence against a clinically relevant possibility.',
        30),

    ('PUR004', 'DIFFERENTIATION',
        'Differentiation',
        'Distinguish between clinically relevant alternatives.',
        40),

    ('PUR005', 'SEVERITY_ASSESSMENT',
        'Severity assessment',
        'Assess physiological, anatomical or biochemical severity.',
        50),

    ('PUR006', 'BASELINE_ASSESSMENT',
        'Baseline assessment',
        'Establish baseline status before treatment or longitudinal follow-up.',
        60),

    ('PUR007', 'COMPLICATION_DETECTION',
        'Complication detection',
        'Detect a complication of a disease, treatment or procedure.',
        70),

    ('PUR008', 'PROGNOSTICATION',
        'Prognostication',
        'Provide information relevant to prognosis.',
        80),

    ('PUR009', 'TREATMENT_SELECTION',
        'Treatment selection',
        'Provide information that determines or modifies treatment choice.',
        90),

    ('PUR010', 'SAFETY_BEFORE_TREATMENT',
        'Safety before treatment',
        'Assess safety before medication, procedure, contrast or other intervention.',
        100),

    ('PUR011', 'MONITORING',
        'Monitoring',
        'Monitor an ongoing disease, physiological state or treatment.',
        110),

    ('PUR012', 'RESPONSE_ASSESSMENT',
        'Response assessment',
        'Assess response to an intervention or treatment.',
        120),

    ('PUR013', 'SCREENING',
        'Screening',
        'Investigate an asymptomatic or at-risk population according to a screening strategy.',
        130),

    ('PUR014', 'SURVEILLANCE',
        'Surveillance',
        'Monitor populations or individuals for emergence or recurrence of clinically relevant findings.',
        140)

ON CONFLICT (purpose_code)
DO UPDATE SET
    code = EXCLUDED.code,
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 44. SEED INVESTIGATION METHODS
-- ============================================================================

INSERT INTO knowledge.investigation_method
    (
        method_code,
        name,
        description,
        method_family,
        acquisition_type,
        sort_order
    )
VALUES
    (
        'METHOD_LAB_ANALYSER',
        'Automated laboratory analyser',
        'Automated laboratory analytical platform.',
        'LABORATORY_ANALYSIS',
        'LAB_ANALYSER',
        10
    ),

    (
        'METHOD_POINT_OF_CARE',
        'Point-of-care analyser',
        'Near-patient analytical method.',
        'LABORATORY_ANALYSIS',
        'LAB_ANALYSER',
        20
    ),

    (
        'METHOD_MICROSCOPY',
        'Microscopy',
        'Microscopic examination of a specimen.',
        'MICROBIOLOGY',
        'MICROSCOPY',
        30
    ),

    (
        'METHOD_CULTURE',
        'Culture',
        'Growth-based microbiological investigation.',
        'MICROBIOLOGY',
        'CULTURE',
        40
    ),

    (
        'METHOD_PCR',
        'PCR / molecular amplification',
        'Molecular amplification-based detection.',
        'MOLECULAR',
        'PCR',
        50
    ),

    (
        'METHOD_RADIOGRAPH',
        'Plain radiography',
        'Projection radiographic imaging.',
        'IMAGING',
        'RADIOGRAPH',
        60
    ),

    (
        'METHOD_ULTRASOUND',
        'Ultrasound',
        'Ultrasonographic imaging.',
        'IMAGING',
        'ULTRASOUND',
        70
    ),

    (
        'METHOD_CT',
        'Computed tomography',
        'Cross-sectional X-ray imaging.',
        'IMAGING',
        'CT',
        80
    ),

    (
        'METHOD_MRI',
        'Magnetic resonance imaging',
        'Magnetic resonance imaging.',
        'IMAGING',
        'MRI',
        90
    ),

    (
        'METHOD_ECG',
        'Electrocardiography',
        'Electrical recording of cardiac activity.',
        'PHYSIOLOGY',
        'ECG',
        100
    ),

    (
        'METHOD_SPIROMETRY',
        'Spirometry',
        'Measurement of dynamic pulmonary function.',
        'PHYSIOLOGY',
        'SPIROMETRY',
        110
    ),

    (
        'METHOD_PULSE_OXIMETRY',
        'Pulse oximetry',
        'Non-invasive measurement of peripheral oxygen saturation.',
        'PHYSIOLOGY',
        'PULSE_OXIMETRY',
        120
    ),

    (
        'METHOD_HISTOLOGY',
        'Histopathology',
        'Microscopic examination of tissue sections.',
        'PATHOLOGY',
        'BIOPSY',
        130
    )

ON CONFLICT (method_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    method_family = EXCLUDED.method_family,
    acquisition_type = EXCLUDED.acquisition_type,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 45. SEED SPECIMENS / STUDIES
-- ============================================================================

INSERT INTO knowledge.investigation_specimen
    (
        specimen_code,
        name,
        description,
        specimen_category,
        collection_site,
        collection_method,
        container_type,
        sort_order
    )
VALUES
    (
        'SPEC_BLOOD',
        'Blood',
        'Venous or arterial blood depending on investigation.',
        'BLOOD',
        'Venous / arterial',
        'Venepuncture / arterial sampling',
        'Investigation-specific tube',
        10
    ),

    (
        'SPEC_URINE',
        'Urine',
        'Urine specimen.',
        'URINE',
        'Urinary tract',
        'Midstream / catheter / timed collection',
        'Sterile urine container',
        20
    ),

    (
        'SPEC_SPUTUM',
        'Sputum',
        'Lower respiratory tract sputum.',
        'RESPIRATORY',
        'Lower respiratory tract',
        'Expectorated sputum',
        'Sterile specimen container',
        30
    ),

    (
        'SPEC_SWAB',
        'Swab',
        'Swab specimen from a defined anatomical site.',
        'SWAB',
        'Defined anatomical site',
        'Swabbing',
        'Transport medium as appropriate',
        40
    ),

    (
        'SPEC_CSF',
        'Cerebrospinal fluid',
        'CSF obtained by lumbar puncture or other appropriate procedure.',
        'CSF',
        'Subarachnoid space',
        'Lumbar puncture',
        'Sterile CSF tubes',
        50
    ),

    (
        'SPEC_STOOL',
        'Stool',
        'Faecal specimen.',
        'STOOL',
        'Gastrointestinal tract',
        'Collection',
        'Sterile specimen container',
        60
    ),

    (
        'SPEC_TISSUE',
        'Tissue',
        'Tissue specimen obtained for pathology.',
        'TISSUE',
        'Defined anatomical site',
        'Biopsy / excision',
        'Formalin / fresh specimen as required',
        70
    ),

    (
        'SPEC_IMAGE',
        'Imaging study',
        'Acquired imaging study rather than a biological specimen.',
        'IMAGE',
        NULL,
        'Imaging acquisition',
        NULL,
        80
    ),

    (
        'SPEC_NONE',
        'No specimen',
        'Investigation requiring no physical specimen.',
        'NONE',
        NULL,
        NULL,
        NULL,
        90
    )

ON CONFLICT (specimen_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    specimen_category = EXCLUDED.specimen_category,
    collection_site = EXCLUDED.collection_site,
    collection_method = EXCLUDED.collection_method,
    container_type = EXCLUDED.container_type,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 46. SEED INVESTIGATION STATUS
-- ============================================================================

INSERT INTO knowledge.investigation_status
    (
        status_code,
        label,
        description,
        sort_order,
        is_terminal
    )
VALUES
    ('RECOMMENDED',
        'Recommended',
        'Suggested by the investigation engine but not yet ordered.',
        10,
        false),

    ('ORDERED',
        'Ordered',
        'Investigation has been operationally ordered.',
        20,
        false),

    ('SPECIMEN_COLLECTED',
        'Specimen collected',
        'Required specimen or study acquisition has occurred.',
        30,
        false),

    ('IN_PROGRESS',
        'In progress',
        'Investigation or laboratory processing is underway.',
        40,
        false),

    ('RESULT_AVAILABLE',
        'Result available',
        'A result has been produced.',
        50,
        false),

    ('REPORTED',
        'Reported',
        'Result has been formally reported.',
        60,
        true),

    ('CANCELLED',
        'Cancelled',
        'Investigation was cancelled.',
        70,
        true),

    ('ENTERED_IN_ERROR',
        'Entered in error',
        'Result or operational record was entered incorrectly.',
        80,
        true)

ON CONFLICT (status_code)
DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_terminal = EXCLUDED.is_terminal,
    status = 'active';


-- ============================================================================
-- 47. SEED PRIORITY DIMENSIONS
-- ============================================================================

INSERT INTO knowledge.investigation_priority_dimension
    (
        dimension_code,
        dimension_group,
        dimension,
        direction,
        weight,
        description,
        version
    )
VALUES
    (
        'IPD_CLINICAL_URGENCY',
        'CLINICAL',
        'CLINICAL_URGENCY',
        'POSITIVE',
        1.00,
        'How urgently the clinical question requires resolution.',
        1
    ),

    (
        'IPD_EXPECTED_INFORMATION',
        'CLINICAL',
        'EXPECTED_INFORMATION',
        'POSITIVE',
        1.00,
        'Expected information yield of the investigation.',
        1
    ),

    (
        'IPD_DIAGNOSTIC_RELEVANCE',
        'CLINICAL',
        'DIAGNOSTIC_RELEVANCE',
        'POSITIVE',
        1.00,
        'Relevance to the current clinical question.',
        1
    ),

    (
        'IPD_SEVERITY_RELEVANCE',
        'CLINICAL',
        'SEVERITY_RELEVANCE',
        'POSITIVE',
        1.00,
        'Expected ability to establish or refine severity.',
        1
    ),

    (
        'IPD_MANAGEMENT_IMPACT',
        'CLINICAL',
        'MANAGEMENT_IMPACT',
        'POSITIVE',
        1.00,
        'Expected ability to change management.',
        1
    ),

    (
        'IPD_SAFETY_VALUE',
        'CLINICAL',
        'SAFETY_VALUE',
        'POSITIVE',
        1.00,
        'Value in preventing treatment or procedural harm.',
        1
    ),

    (
        'IPD_CONTEXT_FIT',
        'CLINICAL',
        'CONTEXT_FIT',
        'POSITIVE',
        1.00,
        'Fit with patient-specific clinical context.',
        1
    ),

    (
        'IPD_HARM',
        'CLINICAL',
        'HARM',
        'NEGATIVE',
        1.00,
        'Potential patient harm associated with the investigation.',
        1
    ),

    (
        'IPD_REDUNDANCY',
        'CLINICAL',
        'REDUNDANCY',
        'NEGATIVE',
        1.00,
        'Degree to which existing information makes repetition unnecessary.',
        1
    ),

    (
        'IPD_AVAILABILITY',
        'OPERATIONAL',
        'AVAILABILITY',
        'POSITIVE',
        1.00,
        'Availability at the current facility or care setting.',
        1
    ),

    (
        'IPD_TURNAROUND',
        'OPERATIONAL',
        'TURNAROUND_TIME',
        'NEGATIVE',
        1.00,
        'Operational delay before clinically useful information is available.',
        1
    ),

    (
        'IPD_COST',
        'OPERATIONAL',
        'COST',
        'NEGATIVE',
        1.00,
        'Operational/resource cost.',
        1
    ),

    (
        'IPD_CAPABILITY',
        'OPERATIONAL',
        'FACILITY_CAPABILITY',
        'POSITIVE',
        1.00,
        'Ability of the current facility to safely perform the investigation.',
        1
    )

ON CONFLICT (priority_dimension_id)
DO NOTHING;


-- ============================================================================
-- 48. SEED COMMON UNITS
-- ============================================================================
--
-- These are foundational examples only.
-- The knowledge compiler can add specialty-specific units later.
-- ============================================================================

INSERT INTO knowledge.measurement_unit
    (
        unit_code,
        symbol,
        name,
        quantity_type,
        is_si
    )
VALUES
    (
        'UNIT_G_PER_DL',
        'g/dL',
        'grams per decilitre',
        'MASS_CONCENTRATION',
        false
    ),

    (
        'UNIT_G_PER_L',
        'g/L',
        'grams per litre',
        'MASS_CONCENTRATION',
        true
    ),

    (
        'UNIT_MG_PER_DL',
        'mg/dL',
        'milligrams per decilitre',
        'MASS_CONCENTRATION',
        false
    ),

    (
        'UNIT_MMOL_PER_L',
        'mmol/L',
        'millimoles per litre',
        'SUBSTANCE_CONCENTRATION',
        true
    ),

    (
        'UNIT_UMOL_PER_L',
        'Âµmol/L',
        'micromoles per litre',
        'SUBSTANCE_CONCENTRATION',
        true
    ),

    (
        'UNIT_X10E9_PER_L',
        'Ã—10â¹/L',
        'times ten to the ninth per litre',
        'CELL_CONCENTRATION',
        true
    ),

    (
        'UNIT_FEMTOLITRE',
        'fL',
        'femtolitre',
        'VOLUME',
        true
    ),

    (
        'UNIT_PERCENT',
        '%',
        'percent',
        'PERCENTAGE',
        false
    ),

    (
        'UNIT_MM_HG',
        'mmHg',
        'millimetres of mercury',
        'PRESSURE',
        false
    ),

    (
        'UNIT_BPM',
        'bpm',
        'beats per minute',
        'RATE',
        false
    ),

    (
        'UNIT_BREATHS_MIN',
        'breaths/min',
        'breaths per minute',
        'RATE',
        false
    ),

    (
        'UNIT_CELSIUS',
        'Â°C',
        'degrees Celsius',
        'TEMPERATURE',
        false
    )

ON CONFLICT (unit_code)
DO UPDATE SET
    symbol = EXCLUDED.symbol,
    name = EXCLUDED.name,
    quantity_type = EXCLUDED.quantity_type,
    is_si = EXCLUDED.is_si,
    status = 'active';


-- ============================================================================
-- 49. SEED COMMON UNIT CONVERSIONS
-- ============================================================================

INSERT INTO knowledge.measurement_unit
    (
        unit_code,
        symbol,
        name,
        quantity_type,
        is_si,
        canonical_unit_code,
        conversion_factor,
        conversion_offset
    )
VALUES
    (
        'UNIT_G_PER_DL',
        'g/dL',
        'grams per decilitre',
        'MASS_CONCENTRATION',
        false,
        'UNIT_G_PER_L',
        10,
        0
    )

ON CONFLICT (unit_code)
DO UPDATE SET
    canonical_unit_code = EXCLUDED.canonical_unit_code,
    conversion_factor = EXCLUDED.conversion_factor,
    conversion_offset = EXCLUDED.conversion_offset;


-- ============================================================================
-- 50. SEED COMMON INVESTIGATION CONCEPTS
-- ============================================================================
--
-- These are UNIVERSAL investigations.
--
-- They are deliberately NOT attached to pneumonia, asthma, anaemia,
-- heart failure or any other disease.
--
-- Clinical indications/rules establish when they become useful.
-- ============================================================================

INSERT INTO knowledge.investigation_concept
(
    code,
    domain_code,
    canonical_code,
    canonical_name,
    short_label,
    description,
    modality,
    result_structure,
    specimen_type_code,
    clinical_purposes,
    base_priority
)
SELECT
    v.code,
    v.domain_code,
    v.canonical_code,
    v.canonical_name,
    v.short_label,
    v.description,
    v.modality,
    v.result_structure,
    v.specimen_type_code,
    v.clinical_purposes,
    v.base_priority
FROM (
    VALUES
    (
        'I001',
        'IDOM01',
        'CBC',
        'Complete blood count',
        'CBC',
        'Quantitative and morphological assessment of major circulating blood cell lines.',
        'LAB',
        'COMPONENT_PANEL',
        'SPEC_BLOOD',
        ARRAY['DIAGNOSTIC_SUPPORT','SEVERITY_ASSESSMENT','BASELINE_ASSESSMENT','MONITORING']::TEXT[],
        100
    ),

    (
        'I002',
        'IDOM02',
        'CRP',
        'C-reactive protein',
        'CRP',
        'Measurement of circulating C-reactive protein concentration.',
        'LAB',
        'NUMERIC',
        'SPEC_BLOOD',
        ARRAY['DIAGNOSTIC_SUPPORT','SEVERITY_ASSESSMENT','MONITORING','RESPONSE_ASSESSMENT']::TEXT[],
        90
    ),

    (
        'I003',
        'IDOM02',
        'UREA_ELECTROLYTES',
        'Urea and electrolytes',
        'U&E',
        'Assessment of renal-related biochemical parameters and major serum electrolytes.',
        'LAB',
        'COMPONENT_PANEL',
        'SPEC_BLOOD',
        ARRAY['DIAGNOSIS','SEVERITY_ASSESSMENT','BASELINE_ASSESSMENT','SAFETY_BEFORE_TREATMENT','MONITORING']::TEXT[],
        100
    ),

    (
        'I004',
        'IDOM03',
        'BLOOD_CULTURE',
        'Blood culture',
        'Blood culture',
        'Microbiological investigation of blood for bloodstream infection.',
        'MICROBIOLOGY',
        'MICROBIOLOGY',
        'SPEC_BLOOD',
        ARRAY['DIAGNOSIS','CONFIRMATION','TREATMENT_SELECTION']::TEXT[],
        120
    ),

    (
        'I005',
        'IDOM05',
        'CHEST_XRAY',
        'Chest radiograph',
        'CXR',
        'Plain radiographic examination of the chest.',
        'IMAGING',
        'STRUCTURED_FINDINGS',
        'SPEC_IMAGE',
        ARRAY['DIAGNOSIS','DIFFERENTIATION','COMPLICATION_DETECTION','SEVERITY_ASSESSMENT','RESPONSE_ASSESSMENT']::TEXT[],
        120
    ),

    (
        'I006',
        'IDOM06',
        'ECG',
        'Electrocardiogram',
        'ECG',
        'Recording of cardiac electrical activity.',
        'PHYSIOLOGY',
        'STRUCTURED_FINDINGS',
        'SPEC_NONE',
        ARRAY['DIAGNOSIS','DIFFERENTIATION','SEVERITY_ASSESSMENT','MONITORING']::TEXT[],
        150
    ),

    (
        'I007',
        'IDOM06',
        'PULSE_OXIMETRY',
        'Pulse oximetry',
        'SpO2',
        'Non-invasive measurement of peripheral oxygen saturation.',
        'PHYSIOLOGY',
        'NUMERIC',
        'SPEC_NONE',
        ARRAY['SEVERITY_ASSESSMENT','MONITORING','RESPONSE_ASSESSMENT']::TEXT[],
        1000
    ),

    (
        'I008',
        'IDOM06',
        'SPIROMETRY',
        'Spirometry',
        'Spirometry',
        'Dynamic pulmonary function testing.',
        'PHYSIOLOGY',
        'STRUCTURED_FINDINGS',
        'SPEC_NONE',
        ARRAY['DIAGNOSIS','DIFFERENTIATION','SEVERITY_ASSESSMENT','MONITORING']::TEXT[],
        100
    )

) AS v(
    code,
    domain_code,
    canonical_code,
    canonical_name,
    short_label,
    description,
    modality,
    result_structure,
    specimen_type_code,
    clinical_purposes,
    base_priority
)
ON CONFLICT (code)
DO UPDATE SET
    domain_code = EXCLUDED.domain_code,
    canonical_code = EXCLUDED.canonical_code,
    canonical_name = EXCLUDED.canonical_name,
    short_label = EXCLUDED.short_label,
    description = EXCLUDED.description,
    modality = EXCLUDED.modality,
    result_structure = EXCLUDED.result_structure,
    clinical_purposes = EXCLUDED.clinical_purposes,
    base_priority = EXCLUDED.base_priority,
    status = 'active';


-- ============================================================================
-- 51. SEED INVESTIGATION â†” METHOD
-- ============================================================================

INSERT INTO knowledge.investigation_concept_method
(
    investigation_concept_code,
    method_code,
    is_preferred,
    requires_specimen
)
VALUES
    ('I001', 'METHOD_LAB_ANALYSER', true, true),
    ('I002', 'METHOD_LAB_ANALYSER', true, true),
    ('I003', 'METHOD_LAB_ANALYSER', true, true),
    ('I004', 'METHOD_CULTURE', true, true),
    ('I005', 'METHOD_RADIOGRAPH', true, false),
    ('I006', 'METHOD_ECG', true, false),
    ('I007', 'METHOD_PULSE_OXIMETRY', true, false),
    ('I008', 'METHOD_SPIROMETRY', true, false)

ON CONFLICT (
    investigation_concept_code,
    method_code
)
DO UPDATE SET
    is_preferred = EXCLUDED.is_preferred,
    requires_specimen = EXCLUDED.requires_specimen;


-- ============================================================================
-- 52. SEED INVESTIGATION â†” SPECIMEN
-- ============================================================================

INSERT INTO knowledge.investigation_concept_specimen
(
    investigation_concept_code,
    specimen_code,
    is_preferred
)
VALUES
    ('I001', 'SPEC_BLOOD', true),
    ('I002', 'SPEC_BLOOD', true),
    ('I003', 'SPEC_BLOOD', true),
    ('I004', 'SPEC_BLOOD', true),
    ('I005', 'SPEC_IMAGE', true),
    ('I006', 'SPEC_NONE', true),
    ('I007', 'SPEC_NONE', true),
    ('I008', 'SPEC_NONE', true)

ON CONFLICT (
    investigation_concept_code,
    specimen_code
)
DO UPDATE SET
    is_preferred = EXCLUDED.is_preferred;


-- ============================================================================
-- 53. CBC COMPONENTS
-- ============================================================================
--
-- NOTE:
-- fact_definition_code values must correspond to the existing AMEXAN
-- canonical fact dictionary.
--
-- These INSERTS deliberately do not invent missing fact definitions.
-- ============================================================================

-- [RECONCILED] The canonical fact dictionary above did not previously contain
-- the investigation RESULT facts consumed by the component seeds. Seed them here
-- (sourced from seed_zknowledge_zq8_h7_investigation.sql) so the component FK
-- resolves. Uses 004-era clinical.fact_definition column set.
INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES
    ('HAEMOGLOBIN',              'Haemoglobin',                'Haemoglobin concentration (g/dL) on a full blood count.',                         'numeric', false, true),
    ('WHITE_CELL_COUNT',         'White blood cell count',     'White blood cell count (x10^9/L); raised in infection/inflammation.',             'numeric', false, true),
    ('NEUTROPHIL_COUNT',         'Neutrophil count',           'Neutrophil count (x10^9/L); dominant response to bacterial infection.',          'numeric', false, true),
    ('LYMPHOCYTE_COUNT',         'Lymphocyte count',           'Lymphocyte count (x10^9/L).',                                                    'numeric', false, true),
    ('PLATELET_COUNT',           'Platelet count',             'Platelet count (x10^9/L).',                                                       'numeric', false, true),
    ('MEAN_CELL_VOLUME',         'Mean cell volume',           'Mean cell volume (fL); micro/macrocytosis.',                                      'numeric', false, true),
    ('C_REACTIVE_PROTEIN',       'C-reactive protein',         'C-reactive protein (mg/L); acute-phase inflammation marker.',                    'numeric', false, true),
    ('UREA',                     'Urea',                       'Plasma urea (mmol/L).',                                                          'numeric', false, true),
    ('SODIUM',                   'Sodium',                     'Plasma sodium (mmol/L).',                                                        'numeric', false, true),
    ('POTASSIUM',                'Potassium',                  'Plasma potassium (mmol/L).',                                                     'numeric', false, true),
    ('FORCED_EXPIRATORY_VOLUME_1','FEV1',                      'Forced expiratory volume in 1 second (L).',                                       'numeric', false, true),
    ('FORCED_VITAL_CAPACITY',    'FVC',                        'Forced vital capacity (L).',                                                     'numeric', false, true),
    ('FEV1_FVC_RATIO',           'FEV1/FVC ratio',             'FEV1/FVC ratio; <0.70 suggests obstructive airflow limitation.',                 'numeric', false, true),
    ('WBC',                      'White blood cell count',     'White blood cell count (x10^9/L); raised in infection/inflammation.',             'numeric', false, true),
    ('PLATELETS',                'Platelet count',             'Platelet count (x10^9/L).',                                                       'numeric', false, true),
    ('MCV',                      'Mean cell volume',           'Mean cell volume (fL); micro/macrocytosis.',                                      'numeric', false, true)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description,
    data_type = EXCLUDED.data_type, is_active = EXCLUDED.is_active;

INSERT INTO knowledge.investigation_component
(
    investigation_concept_code,
    component_code,
    fact_definition_code,
    name,
    short_label,
    value_type,
    canonical_unit_code,
    sort_order
)
VALUES
    (
        'I001',
        'HAEMOGLOBIN',
        'HAEMOGLOBIN',
        'Haemoglobin',
        'Hb',
        'NUMERIC',
        'UNIT_G_PER_DL',
        10
    ),

    (
        'I001',
        'WBC',
        'WBC',
        'White blood cell count',
        'WBC',
        'NUMERIC',
        'UNIT_X10E9_PER_L',
        20
    ),

    (
        'I001',
        'PLATELETS',
        'PLATELETS',
        'Platelet count',
        'PLT',
        'NUMERIC',
        'UNIT_X10E9_PER_L',
        30
    ),

    (
        'I001',
        'MCV',
        'MCV',
        'Mean corpuscular volume',
        'MCV',
        'NUMERIC',
        'UNIT_FEMTOLITRE',
        40
    )

ON CONFLICT (
    investigation_concept_code,
    component_code
)
DO UPDATE SET
    name = EXCLUDED.name,
    short_label = EXCLUDED.short_label,
    value_type = EXCLUDED.value_type,
    canonical_unit_code = EXCLUDED.canonical_unit_code,
    sort_order = EXCLUDED.sort_order;


-- ============================================================================
-- 54. COMMON IMAGING FINDINGS
-- ============================================================================

INSERT INTO knowledge.imaging_finding
(
    finding_code,
    canonical_name,
    label,
    finding_category,
    description,
    sort_order
)
VALUES
    (
        'IMG_AIRSPACE_CONSOLIDATION',
        'Airspace consolidation',
        'Consolidation',
        'LUNG_PARENCHYMA',
        'Airspace opacity compatible with consolidation when supported by the imaging appearance.',
        10
    ),

    (
        'IMG_PLEURAL_EFFUSION',
        'Pleural effusion',
        'Pleural effusion',
        'PLEURA',
        'Fluid within the pleural space.',
        20
    ),

    (
        'IMG_PNEUMOTHORAX',
        'Pneumothorax',
        'Pneumothorax',
        'PLEURA',
        'Pleural air producing a pneumothorax.',
        30
    ),

    (
        'IMG_CARDIOMEGALY',
        'Cardiac enlargement',
        'Cardiomegaly',
        'CARDIAC',
        'Enlarged cardiac silhouette where applicable to the imaging method and projection.',
        40
    ),

    (
        'IMG_CAVITATION',
        'Cavitation',
        'Cavitation',
        'LUNG_PARENCHYMA',
        'Cavitary pulmonary lesion.',
        50
    )

ON CONFLICT (finding_code)
DO UPDATE SET
    canonical_name = EXCLUDED.canonical_name,
    label = EXCLUDED.label,
    finding_category = EXCLUDED.finding_category,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 55. COMMON ANATOMICAL SITES
-- ============================================================================

INSERT INTO knowledge.investigation_anatomical_site
(
    site_code,
    canonical_name,
    label,
    laterality_allowed,
    sort_order
)
VALUES
    (
        'SITE_LUNG_RIGHT',
        'Right lung',
        'Right lung',
        true,
        10
    ),

    (
        'SITE_LUNG_LEFT',
        'Left lung',
        'Left lung',
        true,
        20
    ),

    (
        'SITE_RIGHT_LOWER_LOBE',
        'Right lower lobe',
        'Right lower lobe',
        false,
        30
    ),

    (
        'SITE_LEFT_LOWER_LOBE',
        'Left lower lobe',
        'Left lower lobe',
        false,
        40
    ),

    (
        'SITE_PLEURAL_SPACE',
        'Pleural space',
        'Pleural space',
        true,
        50
    ),

    (
        'SITE_HEART',
        'Heart',
        'Heart',
        false,
        60
    )

ON CONFLICT (site_code)
DO UPDATE SET
    canonical_name = EXCLUDED.canonical_name,
    label = EXCLUDED.label,
    laterality_allowed = EXCLUDED.laterality_allowed,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 56. COMMON RESULT INTERPRETATIONS
-- ============================================================================

INSERT INTO knowledge.result_interpretation
(
    code,
    canonical_name,
    label,
    result_type_constraint,
    is_abnormal,
    is_critical,
    description,
    sort_order
)
VALUES
    (
        'RINT_LEUKOCYTOSIS',
        'Leukocytosis',
        'Leukocytosis',
        'LAB',
        true,
        false,
        'White blood cell count above the applicable contextual reference threshold.',
        10
    ),

    (
        'RINT_ANAEMIA',
        'Anaemia',
        'Anaemia',
        'LAB',
        true,
        false,
        'Haemoglobin below the applicable contextual threshold for the patient.',
        20
    ),

    (
        'RINT_MICROCYTOSIS',
        'Microcytosis',
        'Microcytosis',
        'LAB',
        true,
        false,
        'Mean corpuscular volume below the applicable contextual reference interval.',
        30
    ),

    (
        'RINT_AIRSPACE_CONSOLIDATION',
        'Airspace consolidation',
        'Airspace consolidation',
        'IMAGING',
        true,
        false,
        'Structured imaging interpretation indicating airspace consolidation.',
        40
    ),

    (
        'RINT_PLEURAL_EFFUSION',
        'Pleural effusion',
        'Pleural effusion',
        'IMAGING',
        true,
        false,
        'Structured imaging interpretation indicating pleural fluid.',
        50
    ),

    (
        'RINT_PNEUMOTHORAX',
        'Pneumothorax',
        'Pneumothorax',
        'IMAGING',
        true,
        true,
        'Structured imaging interpretation indicating pneumothorax.',
        60
    ),

    (
        'RINT_HYPOXAEMIA',
        'Hypoxaemia',
        'Hypoxaemia',
        'PHYSIOLOGY',
        true,
        false,
        'Oxygen saturation or blood gas result interpreted as below the applicable contextual threshold.',
        70
    )

ON CONFLICT (code)
DO UPDATE SET
    canonical_name = EXCLUDED.canonical_name,
    label = EXCLUDED.label,
    result_type_constraint = EXCLUDED.result_type_constraint,
    is_abnormal = EXCLUDED.is_abnormal,
    is_critical = EXCLUDED.is_critical,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    status = 'active';


-- ============================================================================
-- 57. COMMON SAFETY EXAMPLE:
--     PULSE OXIMETRY IS HIGH-URGENCY WHEN HYPOXAEMIA IS SUSPECTED
-- ============================================================================
--
-- The rule is based on a clinical state, NOT a disease.
--
-- The exact trigger code must correspond to the canonical AMEXAN phenotype
-- vocabulary.
--
-- ============================================================================

INSERT INTO knowledge.investigation_rule
(
    rule_code,
    trigger_type,
    trigger_code,
    investigation_concept_code,
    modification,
    priority_delta,
    rationale
)
VALUES
(
    'IR_H7_PULSE_OX_SEVERITY',
    'PHENOTYPE',
    'HYPOXAEMIA_SUSPECTED',
    'I007',
    'MANDATORY',
    900,
    'Assessment of oxygenation is clinically urgent when hypoxaemia is suspected.'
)

ON CONFLICT (
    investigation_concept_code,
    trigger_type,
    trigger_code,
    modification
)
DO UPDATE SET
    priority_delta = EXCLUDED.priority_delta,
    rationale = EXCLUDED.rationale,
    status = 'active';


-- ============================================================================
-- 58. COMMON INTERPRETATION RULE:
--     CXR CONSOLIDATION
-- ============================================================================
--
-- Structured imaging finding is converted into an interpretation.
-- ============================================================================

INSERT INTO knowledge.result_interpretation_rule
(
    rule_code,
    investigation_concept_code,
    interpretation_code,
    condition_type,
    finding_concept_code,
    rationale
)
VALUES
(
    'RIR_CXR_CONSOLIDATION',
    'I005',
    'RINT_AIRSPACE_CONSOLIDATION',
    'FINDING_PRESENT',
    'IMG_AIRSPACE_CONSOLIDATION',
    'A structured chest imaging finding of airspace consolidation produces the corresponding investigation interpretation.'
)

ON CONFLICT (rule_code)
DO UPDATE SET
    interpretation_code = EXCLUDED.interpretation_code,
    condition_type = EXCLUDED.condition_type,
    finding_concept_code = EXCLUDED.finding_concept_code,
    rationale = EXCLUDED.rationale,
    status = 'active';


-- ============================================================================
-- 59. COMMON INTERPRETATION RULE:
--     MICROCYTOSIS
-- ============================================================================

INSERT INTO knowledge.result_interpretation_rule
(
    rule_code,
    investigation_concept_code,
    component_code,
    fact_definition_code,
    interpretation_code,
    condition_type,
    operator,
    threshold_value,
    rationale
)
VALUES
(
    'RIR_MCV_LOW',
    'I001',
    'MCV',
    'MCV',
    'RINT_MICROCYTOSIS',
    'NUMERIC_THRESHOLD',
    '<',
    80,
    'MCV below the adult threshold supports a microcytic red-cell pattern; final interpretation must use the applicable contextual reference standard.'
)

ON CONFLICT (rule_code)
DO UPDATE SET
    interpretation_code = EXCLUDED.interpretation_code,
    condition_type = EXCLUDED.condition_type,
    operator = EXCLUDED.operator,
    threshold_value = EXCLUDED.threshold_value,
    rationale = EXCLUDED.rationale,
    status = 'active';


-- ============================================================================
-- 60. COMMON PHENOTYPE LINKS
-- ============================================================================
--
-- associated_concept_code deliberately remains a generic canonical concept
-- reference because the exact phenotype/concept vocabulary belongs to the
-- existing AMEXAN concept layer.
-- ============================================================================

INSERT INTO knowledge.result_phenotype_link
(
    result_interpretation_code,
    associated_concept_code,
    relationship_type,
    strength,
    description
)
VALUES
(
    'RINT_LEUKOCYTOSIS',
    'LEUKOCYTOSIS',
    'INDICATES',
    'strong',
    'Leukocytosis is an interpreted haematological phenotype.'
),

(
    'RINT_ANAEMIA',
    'ANAEMIA',
    'INDICATES',
    'strong',
    'Anaemia is an interpreted haemoglobin-related phenotype.'
),

(
    'RINT_MICROCYTOSIS',
    'MICROCYTIC_PATTERN',
    'INDICATES',
    'strong',
    'Microcytosis indicates a microcytic red-cell phenotype.'
),

(
    'RINT_AIRSPACE_CONSOLIDATION',
    'AIRSPACE_CONSOLIDATION',
    'INDICATES',
    'strong',
    'Imaging-confirmed consolidation becomes a canonical structural phenotype.'
),

(
    'RINT_PLEURAL_EFFUSION',
    'PLEURAL_EFFUSION',
    'INDICATES',
    'strong',
    'Imaging-confirmed pleural fluid becomes a canonical phenotype.'
),

(
    'RINT_PNEUMOTHORAX',
    'PNEUMOTHORAX',
    'INDICATES',
    'strong',
    'Imaging-confirmed pneumothorax becomes a canonical phenotype.'
)

ON CONFLICT (
    result_interpretation_code,
    associated_concept_code,
    relationship_type
)
DO UPDATE SET
    strength = EXCLUDED.strength,
    description = EXCLUDED.description,
    is_active = true;


-- ============================================================================
-- 61. FINAL PROVENANCE COMMENT
-- ============================================================================

COMMENT ON TABLE knowledge.provenance IS
'AMEXAN evidence derivation graph. H7 investigation concepts, components, methods, specimens, purposes, indications, rules, safety rules, reference standards, interpretation rules and phenotype links must remain traceable to source claims where evidence is available.';


-- ============================================================================
-- 62. H7 ARCHITECTURAL COMMENTARY
-- ============================================================================

COMMENT ON TABLE clinical.investigation_request IS
'Runtime operational investigation request. Never treated as knowledge. Generated only after H7 candidate selection, contextual gating, safety evaluation and prioritisation.';


COMMENT ON TABLE clinical.result IS
'Runtime investigation result. Raw evidence returned from an investigation. A result is not itself a diagnosis or interpretation.';


COMMENT ON TABLE clinical.result_value IS
'Runtime raw measurement. Original value and original unit are preserved. Canonical conversion may be added without destroying the raw measurement.';


COMMENT ON TABLE clinical.result_interpretation IS
'Runtime application of a knowledge-layer interpretation rule to a result. Interpretation is distinct from the raw result and from diagnosis.';


COMMENT ON TABLE clinical.result_phenotype_link IS
'Runtime bridge from interpreted investigation findings into the universal clinical state consumed by downstream clinical reasoning.';


-- ============================================================================
-- 63. H7 FINAL ARCHITECTURAL CONTRACT
-- ============================================================================
--
-- The H7 CPU MUST implement the following sequence:
--
--   01. Read clinical state.
--   02. Read active context stack.
--   03. Generate unresolved clinical questions.
--   04. Match investigation indications.
--   05. Generate investigation candidates.
--   06. Evaluate contextual eligibility.
--   07. Evaluate safety rules.
--   08. Evaluate prerequisites/dependencies.
--   09. Evaluate redundancy.
--   10. Calculate clinical priority.
--   11. Calculate operational feasibility separately.
--   12. Produce final recommendation.
--   13. Explain why the recommendation exists.
--   14. Materialise a clinical.investigation_request only when ordered.
--   15. Track specimen/study acquisition.
--   16. Track processing/acquisition.
--   17. Store raw result.
--   18. Preserve original units.
--   19. Convert to canonical units without destroying raw values.
--   20. Select contextual reference standard.
--   21. Classify result.
--   22. Apply interpretation rules.
--   23. Produce controlled interpretation.
--   24. Link interpretation to phenotype/canonical concept.
--   25. Return the resulting fact to the universal clinical CPU.
--   26. H8 then performs clinical synthesis.
--
-- ============================================================================
--
-- END H7 MIGRATION 031
-- =============================================================================
