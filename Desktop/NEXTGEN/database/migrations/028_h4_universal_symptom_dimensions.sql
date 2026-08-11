-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H4 migration 028: universal symptom
-- exploration dimensions
-- =============================================================================
-- H4 defines the reusable clinical grammar underneath every symptom:
--
--   SYMPTOM → DIMENSIONS → QUESTIONS → ANSWERS → CANONICAL FACTS
--                                                    │        │
--                                              ASSOCIATED   TEMPORAL
--                                              SYMPTOMS     STRUCTURE
--
-- H2 already delivered part of this grammar (history_concept dimensions,
-- symptom_history_dimension map, symptom_relationship, functional_impact,
-- symptom_red_flag). H4 completes it with the pieces that make the grammar
-- reusable across departments without per-disease questionnaires:
--
--   1. symptom_dimension          — canonical 25-dimension registry (SD001-SD025)
--                                    with universal vs conditional applicability,
--                                    each backed by a history_concept.
--   2. symptom_dimension_option   — symptom-specific controlled vocabularies per
--                                    dimension (cough character: dry/productive/
--                                    barking/paroxysmal; chest-pain character:
--                                    pressure/burning/sharp/tearing; ...). This is
--                                    the "universal dimension + symptom-specific
--                                    vocabulary" balance from the H4 spec §26.
--   3. red_flag_rule              — red flags are FACT + CONTEXT +
--                                    CLINICAL_SIGNIFICANCE (not a bare boolean).
--                                    Each rule names the triggering fact, an
--                                    optional context condition (age, amount,
--                                    frequency), the clinical significance and
--                                    an urgency tier. H4 spec §19.
--   4. exposure_concept            — reusable exposure classes (contact, travel,
--                                    occupation, animal, insect, food, water,
--                                    sexual, healthcare, environmental, smoke,
--                                    biomass, dust, chemical, drug). H4 spec §20.
--   5. symptom_exposure            — which exposure concepts a symptom explores.
--   6. symptom_relationship.diagnostic_weight — hard-vs-soft symptom weighting
--                                    (H4 spec §16): haemoptysis carries more
--                                    diagnostic value than fever when both
--                                    accompany cough.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. symptom_dimension — canonical registry of the 25 exploration dimensions
-- ---------------------------------------------------------------------------
CREATE TABLE knowledge.symptom_dimension (
    dimension_id       text        PRIMARY KEY,                 -- SD001..SD025
    dimension_code     text        NOT NULL UNIQUE,             -- PRESENCE, ONSET, ...
    dimension_name     text        NOT NULL,
    universal          boolean     NOT NULL DEFAULT true,       -- asked for every symptom?
    applicability      text        NOT NULL DEFAULT 'always'
                                 CHECK (applicability IN ('always', 'conditional')),
    history_concept_id text        REFERENCES knowledge.history_concept(history_concept_id) ON DELETE SET NULL,
    sort_order         integer     NOT NULL DEFAULT 0,
    description        text,
    status             text        NOT NULL DEFAULT 'active'
                                 CHECK (status IN ('active', 'draft', 'retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_symptom_dimension_history_concept ON knowledge.symptom_dimension (history_concept_id);
CREATE TRIGGER trg_knowledge_symptom_dimension_updated_at
    BEFORE UPDATE ON knowledge.symptom_dimension
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. symptom_dimension_option — symptom-specific vocabulary per dimension
-- ---------------------------------------------------------------------------
CREATE TABLE knowledge.symptom_dimension_option (
    id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id   uuid    NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    dimension_id text    NOT NULL REFERENCES knowledge.symptom_dimension(dimension_id) ON DELETE CASCADE,
    option_code  text    NOT NULL,
    option_name  text    NOT NULL,
    sort_order   integer NOT NULL DEFAULT 0,
    is_active    boolean NOT NULL DEFAULT true,
    UNIQUE (symptom_id, dimension_id, option_code)
);

CREATE INDEX idx_symptom_dimension_option_dimension ON knowledge.symptom_dimension_option (dimension_id);

-- ---------------------------------------------------------------------------
-- 3. red_flag_rule — FACT + CONTEXT + CLINICAL_SIGNIFICANCE
-- ---------------------------------------------------------------------------
CREATE TABLE knowledge.red_flag_rule (
    rule_id                text        PRIMARY KEY,             -- RFR001..RFRnnn
    rule_code              text        NOT NULL UNIQUE,
    symptom_id             uuid        REFERENCES knowledge.symptom(id) ON DELETE SET NULL,
    fact_definition_code   text        REFERENCES clinical.fact_definition(code) ON DELETE SET NULL,
    context_condition      jsonb,                               -- e.g. {"fact":{"code":"AGE_BUCKET","in":["65P"]}}
    clinical_significance  text        NOT NULL,
    urgency                text        NOT NULL DEFAULT 'urgent'
                                    CHECK (urgency IN ('emergency', 'urgent', 'routine')),
    priority               integer     NOT NULL DEFAULT 50,
    evidence_claim_code    text        REFERENCES knowledge.source_claim(claim_code) ON DELETE SET NULL,
    status                 text        NOT NULL DEFAULT 'active'
                                    CHECK (status IN ('active', 'draft', 'retired')),
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),
    CHECK (symptom_id IS NOT NULL OR fact_definition_code IS NOT NULL)
);

CREATE INDEX idx_red_flag_rule_symptom     ON knowledge.red_flag_rule (symptom_id);
CREATE INDEX idx_red_flag_rule_fact        ON knowledge.red_flag_rule (fact_definition_code);
CREATE INDEX idx_red_flag_rule_urgency     ON knowledge.red_flag_rule (urgency, priority);
CREATE TRIGGER trg_knowledge_red_flag_rule_updated_at
    BEFORE UPDATE ON knowledge.red_flag_rule
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. exposure_concept — reusable exposure classes (H4 spec §20)
-- ---------------------------------------------------------------------------
CREATE TABLE knowledge.exposure_concept (
    exposure_code text        PRIMARY KEY,                      -- CONTACT, TRAVEL, OCCUPATION, ...
    exposure_class text       NOT NULL,
    label         text        NOT NULL,
    description   text,
    status        text        NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active', 'draft', 'retired')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_exposure_concept_class ON knowledge.exposure_concept (exposure_class);
CREATE TRIGGER trg_knowledge_exposure_concept_updated_at
    BEFORE UPDATE ON knowledge.exposure_concept
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- 5. symptom_exposure — which exposures a symptom explores
-- ---------------------------------------------------------------------------
CREATE TABLE knowledge.symptom_exposure (
    id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id    uuid    NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    exposure_code text    NOT NULL REFERENCES knowledge.exposure_concept(exposure_code) ON DELETE CASCADE,
    priority      integer NOT NULL DEFAULT 50,
    UNIQUE (symptom_id, exposure_code)
);

-- ---------------------------------------------------------------------------
-- 6. symptom_relationship.diagnostic_weight — hard vs soft symptoms (H4 §16)
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.symptom_relationship
    ADD COLUMN diagnostic_weight integer NOT NULL DEFAULT 1;

COMMENT ON TABLE  knowledge.symptom_dimension          IS 'Canonical registry of the 25 universal symptom-exploration dimensions (H4).';
COMMENT ON TABLE  knowledge.symptom_dimension_option   IS 'Symptom-specific controlled vocabulary for a dimension (e.g. cough CHARACTER = dry/productive/barking/paroxysmal).';
COMMENT ON TABLE  knowledge.red_flag_rule              IS 'Red flags as FACT + CONTEXT + CLINICAL_SIGNIFICANCE rules (H4 §19), never a bare boolean.';
COMMENT ON TABLE  knowledge.exposure_concept           IS 'Reusable exposure classes (contact, travel, occupation, animal, insect, food, water, ...).';
COMMENT ON TABLE  knowledge.symptom_exposure           IS 'Exposure concepts a given symptom explores.';
COMMENT ON COLUMN knowledge.symptom_relationship.diagnostic_weight IS 'Hard-vs-soft symptom diagnostic weight (H4 §16); higher = more diagnostically valuable association.';
