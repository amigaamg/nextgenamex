-- =============================================================================
-- AMEXAN Medical Knowledge Compiler
-- H8 Migration 032
--
-- UNIVERSAL CLINICAL DIFFERENTIAL + DIAGNOSTIC REASONING ENGINE
-- =============================================================================
--
-- H1  = vocabulary / claims
-- H2  = history concepts
-- H3  = history questions / acquisition
-- H4  = phenotype / red flag / clinical-state interpretation
-- H5  = context
-- H6  = physical examination
-- H7  = investigation selection + result interpretation
-- H8  = WHAT DOES THE COLLECTED CLINICAL DATABASE MEAN?
--
-- ============================================================================
-- CONSTITUTIONAL LAW
-- ============================================================================
--
-- H8 MUST NOT be:
--
--     DISEASE -> SYMPTOM LOOKUP
--
-- H8 IS:
--
--     PATIENT STATE
--          |
--          v
--     NORMALIZED FACTS
--          |
--          v
--     PHENOTYPES / SYNDROMES
--          |
--          v
--     MECHANISMS
--          |
--          v
--     PATHOLOGICAL PROCESSES
--          |
--          v
--     CANDIDATE HYPOTHESES
--          |
--          v
--     EVIDENCE GRAPH
--          |
--          +--> SUPPORT
--          +--> REFUTE
--          +--> DISCRIMINATE
--          +--> CONTRADICT
--          +--> NEUTRAL
--          |
--          v
--     CONTEXTUAL / TEMPORAL / CAUSAL WEIGHTING
--          |
--          v
--     DIFFERENTIAL RANK
--          |
--          v
--     EXPLANATION
--
-- ============================================================================
-- IMPORTANT MEDICAL LAW
-- ============================================================================
--
-- A disease does not become likely merely because one symptom is present.
--
-- A diagnosis is evaluated against:
--
--   1. epidemiological prior
--   2. syndrome fit
--   3. temporal fit
--   4. anatomical fit
--   5. pathophysiological/mechanistic fit
--   6. positive clinical evidence
--   7. negative clinical evidence
--   8. discriminating evidence
--   9. risk-factor/exposure fit
--  10. investigation evidence
--  11. contradiction evidence
--  12. severity/complication fit
--  13. context fit
--  14. treatment response where legitimately informative
--  15. must-not-miss/safety status
--
-- ============================================================================
-- H8 NEVER silently converts:
--
--   symptom -> diagnosis
--   abnormal test -> diagnosis
--   positive association -> causation
--   absence of evidence -> evidence of absence
--   prevalence -> diagnosis
--   score -> truth
--
-- The CPU produces a ranked differential, not an oracle.
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS knowledge;


-- =============================================================================
-- 0. ENUM-LIKE CONTROL TABLES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Pathological process
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.differential_pathological_process (
    process_code        text PRIMARY KEY,
    code                text NOT NULL UNIQUE,
    label               text NOT NULL,
    description         text,
    sort_order          integer NOT NULL,
    status              text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','draft','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.differential_pathological_process IS
'Universal pathological-process framework used to organize differentials: congenital, degenerative, infective/inflammatory, metabolic, neoplastic, nutritional, toxic, traumatic, vascular and related processes.';


-- ---------------------------------------------------------------------------
-- Evidence relationship
--
-- SUPPORTS:
--   increases consideration
--
-- REFUTES:
--   decreases consideration
--
-- DISCRIMINATES_FOR:
--   particularly favors one hypothesis over a competing hypothesis
--
-- DISCRIMINATES_AGAINST:
--   particularly favors a competing hypothesis
--
-- CONTRADICTS:
--   conflicts with what should be expected if hypothesis were true
--
-- COMPATIBLE:
--   does not materially change probability
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.differential_evidence_relation (
    relation_code       text PRIMARY KEY,
    code                text NOT NULL UNIQUE,
    label               text NOT NULL,
    description         text,
    default_direction   text NOT NULL
                        CHECK (default_direction IN (
                            'POSITIVE',
                            'NEGATIVE',
                            'NEUTRAL'
                        )),
    sort_order          integer NOT NULL,
    status              text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','draft','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.differential_evidence_relation IS
'Controlled semantic relationship between observed clinical evidence and a hypothesis.';


-- =============================================================================
-- 1. DIFFERENTIAL HYPOTHESIS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL UNIQUE,

    concept_id            uuid REFERENCES knowledge.concept(id),
    concept_code          text,

    hypothesis_type       text NOT NULL CHECK (
        hypothesis_type IN (
            'CONDITION',
            'MECHANISM',
            'SYNDROME',
            'FUNCTIONAL',
            'TOXIC',
            'TRAUMATIC',
            'COMPLICATION',
            'MIMIC'
        )
    ),

    canonical_name        text NOT NULL,
    short_label           text,
    description           text,

    body_system_code      text
                          REFERENCES knowledge.body_system(code),

    pathological_process_code
                          text
                          REFERENCES knowledge.differential_pathological_process(
                              process_code
                          ),

    -- Starting prior only.
    --
    -- THIS IS NOT THE FINAL DIAGNOSIS.
    base_weight           numeric(8,3) NOT NULL DEFAULT 0,

    -- Clinical safety.
    is_critical           boolean NOT NULL DEFAULT false,
    is_must_not_miss      boolean NOT NULL DEFAULT false,

    -- Whether this hypothesis can be considered from the universal engine.
    is_active_candidate   boolean NOT NULL DEFAULT true,

    -- Contexts in which the hypothesis is relevant.
    applies_to_context_codes
                          text[] NOT NULL DEFAULT '{}',

    -- Age / sex / physiological context metadata.
    age_min_days          integer,
    age_max_days          integer,

    sex_restriction       text
                          CHECK (
                              sex_restriction IS NULL OR
                              sex_restriction IN (
                                  'MALE',
                                  'FEMALE',
                                  'ANY'
                              )
                          ),

    -- Clinical category.
    acute_capable         boolean NOT NULL DEFAULT true,
    chronic_capable       boolean NOT NULL DEFAULT true,

    status                text NOT NULL DEFAULT 'active'
                          CHECK (
                              status IN (
                                  'active',
                                  'draft',
                                  'retired'
                              )
                          ),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_concept
    ON knowledge.differential_hypothesis(concept_id);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_concept_code
    ON knowledge.differential_hypothesis(concept_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_type
    ON knowledge.differential_hypothesis(hypothesis_type);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_system
    ON knowledge.differential_hypothesis(body_system_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_process
    ON knowledge.differential_hypothesis(pathological_process_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_critical
    ON knowledge.differential_hypothesis(is_critical, is_must_not_miss);


DROP TRIGGER IF EXISTS
trg_knowledge_differential_hypothesis_updated_at
ON knowledge.differential_hypothesis;

CREATE TRIGGER
trg_knowledge_differential_hypothesis_updated_at
BEFORE UPDATE ON knowledge.differential_hypothesis
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


COMMENT ON TABLE knowledge.differential_hypothesis IS
'Universal candidate explanations considered by H8. A hypothesis may be a disease, syndrome, mechanism, complication or important mimic. It is never equivalent to a diagnosis merely because it ranks first.';


-- =============================================================================
-- 2. HYPOTHESIS RELATIONSHIPS
--
-- Medicine is relational.
--
-- Examples:
--
-- pneumonia
--   -> complication -> respiratory failure
--   -> mimic       -> pulmonary embolism
--   -> mechanism   -> alveolar inflammation
--   -> consequence -> hypoxaemia
--
-- asthma
--   -> mechanism   -> variable airflow obstruction
--   -> mimic       -> COPD
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis_relationship (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_hypothesis_code
                          text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    target_hypothesis_code
                          text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'CAUSES',
            'RESULTS_IN',
            'COMPLICATION_OF',
            'MIMICS',
            'DIFFERENTIAL_OF',
            'EXCLUDES',
            'ASSOCIATED_WITH',
            'COEXISTS_WITH',
            'PRECEDES',
            'FOLLOWS',
            'MECHANISM_OF',
            'MANIFESTATION_OF'
        )
    ),

    strength              numeric(5,2) NOT NULL DEFAULT 1.00,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        source_hypothesis_code,
        target_hypothesis_code,
        relationship_type
    )
);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_rel_source
    ON knowledge.differential_hypothesis_relationship(
        source_hypothesis_code
    );

CREATE INDEX IF NOT EXISTS idx_diff_hyp_rel_target
    ON knowledge.differential_hypothesis_relationship(
        target_hypothesis_code
    );


COMMENT ON TABLE knowledge.differential_hypothesis_relationship IS
'Explicit clinical relationships between hypotheses: differential alternatives, mimics, complications, mechanisms, causal relationships and coexistence.';


-- =============================================================================
-- 3. HYPOTHESIS SYNDROME RELATIONSHIP
--
-- A disease is often reached through a syndrome.
--
-- Example:
--
-- ACUTE_FEBRILE_RESPIRATORY_SYNDROME
--       |
--       +--> pneumonia
--       +--> influenza
--       +--> pulmonary embolism
--       +--> acute bronchitis
--       +--> tuberculosis
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis_phenotype (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    phenotype_code        text NOT NULL
                          REFERENCES knowledge.phenotype(
                              phenotype_code
                          )
                          ON DELETE CASCADE,

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'EXPECTED',
            'COMMON',
            'CHARACTERISTIC',
            'UNCOMMON',
            'ATYPICAL',
            'ABSENCE_EXPECTED',
            'SEVERITY_MARKER',
            'COMPLICATION',
            'MECHANISTIC'
        )
    ),

    importance            numeric(6,3) NOT NULL DEFAULT 1.00,

    sensitivity_hint      numeric(6,4),
    specificity_hint      numeric(6,4),

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        phenotype_code,
        relationship_type
    )
);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_pheno_hyp
    ON knowledge.differential_hypothesis_phenotype(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_pheno_pheno
    ON knowledge.differential_hypothesis_phenotype(phenotype_code);


COMMENT ON TABLE knowledge.differential_hypothesis_phenotype IS
'Clinical phenotype relationships. Allows H8 to reason from syndromes and phenotype patterns rather than isolated symptoms.';


-- =============================================================================
-- 4. HYPOTHESIS MECHANISM RELATIONSHIP
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis_mechanism (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    mechanism_code        text NOT NULL
                          REFERENCES knowledge.mechanism(
                              mechanism_code
                          )
                          ON DELETE CASCADE,

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'PRIMARY_MECHANISM',
            'SECONDARY_MECHANISM',
            'PATHOGENIC_MECHANISM',
            'PHYSIOLOGICAL_CONSEQUENCE',
            'COMPLICATION_MECHANISM'
        )
    ),

    strength              numeric(6,3) NOT NULL DEFAULT 1.00,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        mechanism_code,
        relationship_type
    )
);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_mech_hyp
    ON knowledge.differential_hypothesis_mechanism(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_mech_mech
    ON knowledge.differential_hypothesis_mechanism(mechanism_code);


-- =============================================================================
-- 5. ETIOLOGICAL / RISK FACTOR RELATIONSHIPS
--
-- Risk factor ≠ diagnosis.
--
-- Smoking may support COPD.
-- It does NOT establish COPD.
--
-- Recent surgery may increase PE prior.
-- It does NOT establish PE.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis_risk_factor (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    risk_factor_code      text NOT NULL,

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'RISK_FACTOR',
            'STRONG_RISK_FACTOR',
            'CAUSE',
            'EXPOSURE',
            'PREDISPOSITION',
            'PROTECTIVE_FACTOR'
        )
    ),

    weight                numeric(6,3) NOT NULL DEFAULT 1.00,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        risk_factor_code,
        relationship_type
    )
);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_rf_hyp
    ON knowledge.differential_hypothesis_risk_factor(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_rf_factor
    ON knowledge.differential_hypothesis_risk_factor(risk_factor_code);


-- =============================================================================
-- 6. TEMPORAL PATTERN
--
-- Time is one of the strongest diagnostic discriminators.
--
-- Examples:
--   seconds       -> arrhythmia / seizure / embolic event
--   hours         -> ACS / PE / obstruction
--   days          -> infection / inflammation
--   weeks         -> TB / malignancy / autoimmune disease
--   months-years  -> degenerative / chronic inflammatory / neoplastic
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_temporal_pattern (
    temporal_pattern_code text PRIMARY KEY,

    code                  text NOT NULL UNIQUE,

    label                 text NOT NULL,

    onset_class           text NOT NULL CHECK (
        onset_class IN (
            'HYPERACUTE',
            'ACUTE',
            'SUBACUTE',
            'CHRONIC',
            'RELAPSING',
            'RECURRENT',
            'PROGRESSIVE',
            'INTERMITTENT',
            'FLUCTUATING'
        )
    ),

    minimum_duration_hours numeric(12,2),
    maximum_duration_hours numeric(12,2),

    description           text,

    sort_order            integer NOT NULL,

    status                text NOT NULL DEFAULT 'active'
                          CHECK (
                              status IN (
                                  'active',
                                  'draft',
                                  'retired'
                              )
                          ),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis_temporal_fit (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    temporal_pattern_code text NOT NULL
                          REFERENCES knowledge.differential_temporal_pattern(
                              temporal_pattern_code
                          ),

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'TYPICAL',
            'POSSIBLE',
            'ATYPICAL',
            'STRONGLY_SUPPORTIVE',
            'STRONGLY_AGAINST'
        )
    ),

    weight                numeric(6,3) NOT NULL DEFAULT 1.00,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        temporal_pattern_code
    )
);


-- =============================================================================
-- 7. ANATOMICAL / DISTRIBUTIONAL FIT
--
-- The same symptom has different meaning depending on location.
--
-- chest pain:
--   central / pleuritic / positional / dermatomal / reproducible
--
-- weakness:
--   proximal / distal / unilateral / symmetrical
--
-- abdominal pain:
--   epigastric / RUQ / RLQ / suprapubic etc.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis_anatomical_fit (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    anatomical_code       text NOT NULL,

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'TYPICAL_SITE',
            'POSSIBLE_SITE',
            'UNUSUAL_SITE',
            'EXCLUDES',
            'CHARACTERISTIC_DISTRIBUTION'
        )
    ),

    weight                numeric(6,3) NOT NULL DEFAULT 1.00,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        anatomical_code
    )
);


-- =============================================================================
-- 8. DIFFERENTIAL EVIDENCE
--
-- KNOWLEDGE:
--   what relationship does this clinical observation have with the hypothesis?
--
-- It is NOT the patient's actual result.
--
-- Patient evidence enters through the runtime evidence-instance layer below.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_evidence (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    evidence_code          text NOT NULL UNIQUE,

    hypothesis_code        text NOT NULL
                           REFERENCES knowledge.differential_hypothesis(
                               hypothesis_code
                           )
                           ON DELETE CASCADE,

    evidence_type          text NOT NULL CHECK (
        evidence_type IN (
            'FACT',
            'SYMPTOM',
            'EXAMINATION_FINDING',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'RESULT_VALUE',
            'CONTEXT',
            'RISK_FACTOR',
            'EXPOSURE',
            'TEMPORAL_PATTERN',
            'ANATOMICAL_PATTERN',
            'NEGATIVE_FINDING'
        )
    ),

    fact_definition_code   text
                           REFERENCES clinical.fact_definition(code),

    phenotype_code         text
                           REFERENCES knowledge.phenotype(phenotype_code),

    mechanism_code         text
                           REFERENCES knowledge.mechanism(mechanism_code),

    result_interpretation_code
                           text
                           REFERENCES knowledge.result_interpretation(
                               code
                           ),

    context_code           text
                           REFERENCES knowledge.clinical_context(code),

    temporal_pattern_code
                           text
                           REFERENCES knowledge.differential_temporal_pattern(
                               temporal_pattern_code
                           ),

    relation_code          text
                           REFERENCES knowledge.differential_evidence_relation(
                               relation_code
                           ),

    direction              text NOT NULL CHECK (
        direction IN (
            'SUPPORTS',
            'REFUTES',
            'DISCRIMINATES_FOR',
            'DISCRIMINATES_AGAINST',
            'CONTRADICTS',
            'COMPATIBLE'
        )
    ),

    -- Raw knowledge strength.
    weight                 numeric(8,3) NOT NULL DEFAULT 1.00,

    -- Where available, explicit diagnostic likelihood information.
    likelihood_ratio       numeric(12,6),

    likelihood_ratio_low   numeric(12,6),
    likelihood_ratio_high  numeric(12,6),

    certainty               text NOT NULL DEFAULT 'DEFINITE'
                           CHECK (
                               certainty IN (
                                   'DEFINITE',
                                   'PROBABLE',
                                   'POSSIBLE'
                               )
                           ),

    -- How characteristic is the evidence?
    evidentiary_role       text NOT NULL DEFAULT 'GENERAL'
                           CHECK (
                               evidentiary_role IN (
                                   'GENERAL',
                                   'KEY_FEATURE',
                                   'DISCRIMINATOR',
                                   'RED_FLAG',
                                   'MUST_NOT_MISS',
                                   'EXCLUSION_FEATURE',
                                   'SEVERITY_MARKER',
                                   'COMPLICATION_MARKER'
                               )
                           ),

    description             text,

    evidence_claim_code     text
                            REFERENCES knowledge.source_claim(claim_code),

    is_active               boolean NOT NULL DEFAULT true,

    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_ev_hyp
    ON knowledge.differential_evidence(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_fact
    ON knowledge.differential_evidence(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_ph
    ON knowledge.differential_evidence(phenotype_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_mech
    ON knowledge.differential_evidence(mechanism_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_result
    ON knowledge.differential_evidence(result_interpretation_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_direction
    ON knowledge.differential_evidence(direction);

CREATE INDEX IF NOT EXISTS idx_diff_ev_role
    ON knowledge.differential_evidence(evidentiary_role);


DROP TRIGGER IF EXISTS
trg_knowledge_differential_evidence_updated_at
ON knowledge.differential_evidence;

CREATE TRIGGER
trg_knowledge_differential_evidence_updated_at
BEFORE UPDATE ON knowledge.differential_evidence
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


COMMENT ON TABLE knowledge.differential_evidence IS
'Knowledge relationship between a clinical evidence type and a hypothesis. This is NOT the patients actual evidence; patient observations are linked through differential_evidence_instance.';


-- =============================================================================
-- 9. RUNTIME EVIDENCE INSTANCE
--
-- THIS IS A CRITICAL MEDICAL SEPARATION.
--
-- differential_evidence:
--     "Fever supports pneumonia."
--
-- differential_evidence_instance:
--     "This patient has documented fever of 39.2 C."
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_evidence_instance (
    evidence_instance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id         uuid NOT NULL,
    patient_id           uuid,

    hypothesis_code      text NOT NULL
                         REFERENCES knowledge.differential_hypothesis(
                             hypothesis_code
                         ),

    evidence_code        text NOT NULL
                         REFERENCES knowledge.differential_evidence(
                             evidence_code
                         ),

    -- Actual source of patient evidence.
    source_type          text NOT NULL CHECK (
        source_type IN (
            'HISTORY',
            'EXAMINATION',
            'INVESTIGATION',
            'CONTEXT',
            'OBSERVATION',
            'DOCUMENT',
            'PATIENT_REPORT',
            'CLINICIAN_OBSERVATION'
        )
    ),

    source_reference_id  uuid,

    observed_value       jsonb,

    certainty             text NOT NULL DEFAULT 'DEFINITE'
                          CHECK (
                              certainty IN (
                                  'DEFINITE',
                                  'PROBABLE',
                                  'POSSIBLE'
                              )
                          ),

    direction             text NOT NULL CHECK (
        direction IN (
            'SUPPORTS',
            'REFUTES',
            'DISCRIMINATES_FOR',
            'DISCRIMINATES_AGAINST',
            'CONTRADICTS',
            'COMPATIBLE'
        )
    ),

    raw_weight            numeric(8,3) NOT NULL DEFAULT 1.00,

    contextual_weight     numeric(8,3) NOT NULL DEFAULT 1.00,

    effective_weight      numeric(10,4)
                          GENERATED ALWAYS AS (
                              raw_weight * contextual_weight
                          ) STORED,

    explanation           text,

    observed_at           timestamptz,

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_ev_inst_encounter
    ON knowledge.differential_evidence_instance(encounter_id);

CREATE INDEX IF NOT EXISTS idx_diff_ev_inst_hyp
    ON knowledge.differential_evidence_instance(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_inst_source
    ON knowledge.differential_evidence_instance(source_type);


COMMENT ON TABLE knowledge.differential_evidence_instance IS
'Runtime patient-specific instantiation of differential evidence. Separates medical knowledge about evidence from what was actually observed in this patient.';


-- =============================================================================
-- 10. DIFFERENTIAL RULE
--
-- Rules activate candidates but MUST NOT themselves become diagnoses.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_rule (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code              text NOT NULL UNIQUE,

    trigger_type            text NOT NULL CHECK (
        trigger_type IN (
            'ALWAYS',
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'CONTEXT',
            'TEMPORAL_PATTERN',
            'RISK_FACTOR',
            'EXPOSURE'
        )
    ),

    trigger_code            text,

    target_hypothesis_code  text NOT NULL
                            REFERENCES knowledge.differential_hypothesis(
                                hypothesis_code
                            ),

    modification            text NOT NULL CHECK (
        modification IN (
            'ACTIVATE',
            'ELEVATE',
            'SUPPRESS',
            'EXCLUDE',
            'MARK_CRITICAL',
            'CONDITIONAL'
        )
    ),

    weight_delta             numeric(8,3) NOT NULL DEFAULT 0,

    rationale                text,

    evidence_claim_code      text
                             REFERENCES knowledge.source_claim(claim_code),

    applies_to_context_codes text[] NOT NULL DEFAULT '{}',

    is_active                boolean NOT NULL DEFAULT true,

    status                   text NOT NULL DEFAULT 'active'
                             CHECK (
                                 status IN (
                                     'active',
                                     'draft',
                                     'superseded',
                                     'retired'
                                 )
                             ),

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        trigger_type,
        trigger_code,
        target_hypothesis_code,
        modification
    )
);

CREATE INDEX IF NOT EXISTS idx_diff_rule_target
    ON knowledge.differential_rule(target_hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_rule_trigger
    ON knowledge.differential_rule(trigger_type, trigger_code);


DROP TRIGGER IF EXISTS
trg_knowledge_differential_rule_updated_at
ON knowledge.differential_rule;

CREATE TRIGGER
trg_knowledge_differential_rule_updated_at
BEFORE UPDATE ON knowledge.differential_rule
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 11. DIFFERENTIAL RULE CONDITION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_rule_condition (
    condition_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code             text NOT NULL
                          REFERENCES knowledge.differential_rule(rule_code)
                          ON DELETE CASCADE,

    condition_code        text NOT NULL,

    fact_definition_code  text NOT NULL
                          REFERENCES clinical.fact_definition(code),

    operator              text NOT NULL CHECK (
        operator IN (
            '=',
            '!=',
            '>',
            '>=',
            '<',
            '<=',
            'IN',
            'BETWEEN',
            'IS_TRUE',
            'IS_FALSE'
        )
    ),

    value                 text,

    -- Whether missing data means:
    --
    -- UNKNOWN:
    --   do not apply the rule.
    --
    -- NOT_PRESENT:
    --   explicit negative finding.
    --
    missing_data_behavior text NOT NULL DEFAULT 'UNKNOWN'
                          CHECK (
                              missing_data_behavior IN (
                                  'UNKNOWN',
                                  'NOT_PRESENT',
                                  'FAIL'
                              )
                          ),

    rationale              text,

    is_active              boolean NOT NULL DEFAULT true,

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),

    UNIQUE (rule_code, condition_code)
);

CREATE INDEX IF NOT EXISTS idx_diff_rule_cond_rule
    ON knowledge.differential_rule_condition(rule_code);


-- =============================================================================
-- 12. DIFFERENTIAL WEIGHT MODEL
--
-- The previous model was too simple because a single weight cannot adequately
-- represent clinical reasoning.
--
-- H8 must allow:
--
--   prior probability
--   evidence strength
--   temporal fit
--   syndrome fit
--   mechanism fit
--   anatomical fit
--   severity fit
--   context fit
--   contradiction
--   exclusion
--   red flag
--   diagnostic discriminator
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_weight (
    weight_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    weight_code          text NOT NULL UNIQUE,

    dimension            text NOT NULL CHECK (
        dimension IN (
            'PREVALENCE_PRIOR',
            'EVIDENCE_STRENGTH',
            'HARD_SYMPTOM',
            'SYNDROME_FIT',
            'PHENOTYPE_FIT',
            'MECHANISM_PLAUSIBILITY',
            'TEMPORAL_FIT',
            'ANATOMICAL_FIT',
            'RISK_FACTOR_FIT',
            'EXPOSURE_FIT',
            'SEVERITY_FIT',
            'COMPLICATION_FIT',
            'RED_FLAG',
            'CONTEXT_FIT',
            'EXCLUSION_POWER',
            'DISCRIMINATING_POWER',
            'CONTRADICTION_PENALTY',
            'REFUTATION_PENALTY',
            'REDUNDANCY_PENALTY',
            'MISSING_EXPECTED_FEATURE'
        )
    ),

    direction            text NOT NULL DEFAULT 'POSITIVE'
                         CHECK (
                             direction IN (
                                 'POSITIVE',
                                 'NEGATIVE'
                             )
                         ),

    weight               numeric(8,3) NOT NULL DEFAULT 1.00,

    description          text,

    version              integer NOT NULL DEFAULT 1,

    effective_from       date,
    effective_to         date,

    status               text NOT NULL DEFAULT 'active'
                         CHECK (
                             status IN (
                                 'active',
                                 'draft',
                                 'superseded',
                                 'retired'
                             )
                         ),

    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (dimension, version)
);


DROP TRIGGER IF EXISTS
trg_knowledge_differential_weight_updated_at
ON knowledge.differential_weight;

CREATE TRIGGER
trg_knowledge_differential_weight_updated_at
BEFORE UPDATE ON knowledge.differential_weight
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 13. BAYESIAN / LIKELIHOOD EVIDENCE
--
-- Do NOT force everything into an arbitrary score.
--
-- Where a reliable likelihood ratio exists:
--
--     prior odds × LR = posterior odds
--
-- Where one does not exist:
--
--     use qualitative evidence weighting.
--
-- H8 can therefore support both quantitative and qualitative reasoning.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_likelihood_evidence (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    evidence_code         text NOT NULL
                          REFERENCES knowledge.differential_evidence(
                              evidence_code
                          )
                          ON DELETE CASCADE,

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    likelihood_type       text NOT NULL CHECK (
        likelihood_type IN (
            'LR_POSITIVE',
            'LR_NEGATIVE',
            'LR_RANGE',
            'QUALITATIVE'
        )
    ),

    likelihood_ratio      numeric(14,8),

    lower_bound           numeric(14,8),
    upper_bound           numeric(14,8),

    qualitative_strength  text CHECK (
        qualitative_strength IS NULL OR
        qualitative_strength IN (
            'VERY_STRONG',
            'STRONG',
            'MODERATE',
            'WEAK',
            'MINIMAL'
        )
    ),

    population_context    text,

    method_context        text,

    source_claim_code     text
                          REFERENCES knowledge.source_claim(claim_code),

    description           text,

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        evidence_code,
        hypothesis_code
    )
);


-- =============================================================================
-- 14. EXPECTED-FEATURE MODEL
--
-- This is essential.
--
-- Absence of a finding must NOT automatically refute a diagnosis.
--
-- Instead:
--
--   EXPECTED + EXPLICITLY ASSESSED + ABSENT
--        may generate negative evidence.
--
--   EXPECTED + NOT ASSESSED
--        = UNKNOWN
--
-- This prevents a major clinical reasoning error.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_expected_feature (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    fact_definition_code  text
                          REFERENCES clinical.fact_definition(code),

    phenotype_code        text
                          REFERENCES knowledge.phenotype(phenotype_code),

    feature_role          text NOT NULL CHECK (
        feature_role IN (
            'EXPECTED',
            'COMMON',
            'CHARACTERISTIC',
            'ESSENTIAL',
            'SEVERITY_MARKER',
            'COMPLICATION_MARKER'
        )
    ),

    importance            numeric(8,3) NOT NULL DEFAULT 1.00,

    absence_penalty       numeric(8,3) NOT NULL DEFAULT 0,

    only_if_explicitly_assessed
                          boolean NOT NULL DEFAULT true,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active              boolean NOT NULL DEFAULT true,

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_expected_hyp
    ON knowledge.differential_expected_feature(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_expected_fact
    ON knowledge.differential_expected_feature(fact_definition_code);


-- =============================================================================
-- 15. DISCRIMINATING FEATURES
--
-- This is what makes a differential clinically useful.
--
-- Example:
--
-- pneumonia vs asthma:
--   focal bronchial breathing -> favors pneumonia
--   diffuse polyphonic wheeze -> favors asthma
--
-- PE vs pneumonia:
--   pleuritic pain + risk factors -> favors PE
--   focal consolidation + fever -> favors pneumonia
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_discriminator (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    discriminator_code    text NOT NULL UNIQUE,

    clinical_question     text NOT NULL,

    description           text,

    status                text NOT NULL DEFAULT 'active'
                          CHECK (
                              status IN (
                                  'active',
                                  'draft',
                                  'retired'
                              )
                          ),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.differential_discriminator_hypothesis (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    discriminator_code    text NOT NULL
                          REFERENCES knowledge.differential_discriminator(
                              discriminator_code
                          )
                          ON DELETE CASCADE,

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    direction             text NOT NULL CHECK (
        direction IN (
            'FAVORS',
            'ARGUES_AGAINST'
        )
    ),

    strength              numeric(8,3) NOT NULL DEFAULT 1.00,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    description           text,

    UNIQUE (
        discriminator_code,
        hypothesis_code
    )
);


-- =============================================================================
-- 16. MUST-NOT-MISS / SAFETY DIFFERENTIAL
--
-- A rare diagnosis can remain high in the differential because missing it
-- causes major harm.
--
-- This is NOT the same as probability.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_safety_profile (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL UNIQUE
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    mortality_if_missed   numeric(8,3),
    morbidity_if_missed   numeric(8,3),
    time_sensitivity      numeric(8,3),
    reversibility         numeric(8,3),

    must_not_miss         boolean NOT NULL DEFAULT false,

    immediate_action      boolean NOT NULL DEFAULT false,

    safety_rationale      text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 17. COMPLICATION MODEL
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_complication (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    complication_code     text NOT NULL,

    complication_type     text NOT NULL CHECK (
        complication_type IN (
            'LOCAL',
            'SYSTEMIC',
            'ORGAN_FAILURE',
            'TREATMENT_RELATED',
            'RECURRENCE',
            'LONG_TERM'
        )
    ),

    expected_feature_code text,

    severity              text CHECK (
        severity IS NULL OR
        severity IN (
            'MILD',
            'MODERATE',
            'SEVERE',
            'LIFE_THREATENING'
        )
    ),

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_comp_hyp
    ON knowledge.differential_complication(hypothesis_code);


-- =============================================================================
-- 18. COEXISTING / MULTIPLE DIAGNOSIS MODEL
--
-- A major clinical mistake is assuming:
--
--     "If A explains the patient, B cannot also exist."
--
-- Medicine frequently contains:
--
--     pneumonia + heart failure
--     diabetes + infection
--     pregnancy + PE
--     COPD + pneumonia
--     malignancy + infection
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_coexistence (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_a_code     text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    hypothesis_b_code     text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    relationship_type     text NOT NULL CHECK (
        relationship_type IN (
            'COMMONLY_COEXIST',
            'CAN_COEXIST',
            'RARELY_COEXIST',
            'MUTUALLY_EXCLUSIVE'
        )
    ),

    interaction_weight    numeric(8,3) NOT NULL DEFAULT 0,

    description           text,

    evidence_claim_code   text
                          REFERENCES knowledge.source_claim(claim_code),

    is_active             boolean NOT NULL DEFAULT true,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_a_code,
        hypothesis_b_code
    )
);


-- =============================================================================
-- 19. DIFFERENTIAL SOURCE / PROVENANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_source (
    source_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          )
                          ON DELETE CASCADE,

    source_version_id     text NOT NULL
                          REFERENCES knowledge.source_version(version_id),

    reference             text,
    organization          text,
    publication           text,
    edition               text,
    year                  integer,
    chapter_ref           text,
    section_ref           text,
    version               text,

    effective_from        date,
    effective_to          date,

    status                text NOT NULL DEFAULT 'active'
                          CHECK (
                              status IN (
                                  'active',
                                  'draft',
                                  'superseded',
                                  'retired'
                              )
                          ),

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        source_version_id
    )
);

CREATE INDEX IF NOT EXISTS idx_diff_source_hyp
    ON knowledge.differential_source(hypothesis_code);


DROP TRIGGER IF EXISTS
trg_knowledge_differential_source_updated_at
ON knowledge.differential_source;

CREATE TRIGGER
trg_knowledge_differential_source_updated_at
BEFORE UPDATE ON knowledge.differential_source
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 20. DIFFERENTIAL VERSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_version (
    version_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    hypothesis_code        text NOT NULL
                           REFERENCES knowledge.differential_hypothesis(
                               hypothesis_code
                           )
                           ON DELETE CASCADE,

    version_no             integer NOT NULL,

    effective_from         date,
    effective_to           date,

    supersedes             uuid
                           REFERENCES knowledge.differential_version(
                               version_id
                           ),

    change_note            text,

    status                 text NOT NULL DEFAULT 'active'
                           CHECK (
                               status IN (
                                   'active',
                                   'draft',
                                   'superseded',
                                   'retired'
                               )
                           ),

    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        hypothesis_code,
        version_no
    )
);


-- =============================================================================
-- 21. DIFFERENTIAL STATUS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_status (
    status_code       text PRIMARY KEY,

    label             text NOT NULL,

    description       text,

    sort_order        integer NOT NULL,

    is_terminal       boolean NOT NULL DEFAULT false,

    status            text NOT NULL DEFAULT 'active'
                      CHECK (
                          status IN (
                              'active',
                              'draft',
                              'retired'
                          )
                      )
);


-- =============================================================================
-- 22. REASONING PASS
--
-- A differential should be associated with a specific reasoning pass.
--
-- The same patient may have:
--
--   initial assessment
--   post-examination differential
--   post-investigation differential
--   post-treatment reassessment
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_reasoning_pass (
    reasoning_pass_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id           uuid NOT NULL,

    patient_id             uuid,

    context_stack          jsonb,

    reasoning_stage        text NOT NULL CHECK (
        reasoning_stage IN (
            'INITIAL',
            'POST_HISTORY',
            'POST_EXAMINATION',
            'POST_INVESTIGATION',
            'REASSESSMENT',
            'DISCHARGE',
            'FOLLOW_UP'
        )
    ),

    parent_pass_id         uuid
                           REFERENCES knowledge.differential_reasoning_pass(
                               reasoning_pass_id
                           ),

    knowledge_version      text,

    started_at             timestamptz NOT NULL DEFAULT now(),

    completed_at           timestamptz,

    status                 text NOT NULL DEFAULT 'ACTIVE'
                           CHECK (
                               status IN (
                                   'ACTIVE',
                                   'COMPLETED',
                                   'SUPERSEDED',
                                   'ENTERED_IN_ERROR'
                               )
                           )
);

CREATE INDEX IF NOT EXISTS idx_diff_pass_encounter
    ON knowledge.differential_reasoning_pass(encounter_id);

CREATE INDEX IF NOT EXISTS idx_diff_pass_parent
    ON knowledge.differential_reasoning_pass(parent_pass_id);


-- =============================================================================
-- 23. COMPUTED DIFFERENTIAL RANK
--
-- IMPORTANT:
--
-- score != diagnosis
-- rank != certainty
--
-- It is a computational ordering.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_rank (
    rank_id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    reasoning_pass_id      uuid NOT NULL
                           REFERENCES knowledge.differential_reasoning_pass(
                               reasoning_pass_id
                           )
                           ON DELETE CASCADE,

    encounter_id           uuid NOT NULL,

    patient_id             uuid,

    hypothesis_code        text NOT NULL
                           REFERENCES knowledge.differential_hypothesis(
                               hypothesis_code
                           ),

    score                  numeric(14,5) NOT NULL DEFAULT 0,

    rank                   integer NOT NULL,

    confidence_band        text NOT NULL DEFAULT 'UNDETERMINED'
                           CHECK (
                               confidence_band IN (
                                   'VERY_LOW',
                                   'LOW',
                                   'MODERATE',
                                   'HIGH',
                                   'VERY_HIGH',
                                   'UNDETERMINED'
                               )
                           ),

    probability_estimate   numeric(10,8),

    -- Explicitly distinguish probability from certainty.
    probability_basis      text CHECK (
        probability_basis IS NULL OR
        probability_basis IN (
            'BAYESIAN',
            'QUALITATIVE',
            'HYBRID'
        )
    ),

    is_leading_hypothesis  boolean NOT NULL DEFAULT false,

    is_must_not_miss       boolean NOT NULL DEFAULT false,

    is_excluded            boolean NOT NULL DEFAULT false,

    exclusion_reason       text,

    status_code             text NOT NULL DEFAULT 'ACTIVE'
                            REFERENCES knowledge.differential_status(
                                status_code
                            ),

    computed_at             timestamptz NOT NULL DEFAULT now(),

    created_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_rank_pass
    ON knowledge.differential_rank(reasoning_pass_id);

CREATE INDEX IF NOT EXISTS idx_diff_rank_encounter
    ON knowledge.differential_rank(encounter_id);

CREATE INDEX IF NOT EXISTS idx_diff_rank_hyp
    ON knowledge.differential_rank(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_rank_rank
    ON knowledge.differential_rank(
        reasoning_pass_id,
        rank
    );


-- =============================================================================
-- 24. RANK EVIDENCE CONTRIBUTION
--
-- Instead of only storing "score = 27", preserve HOW the score happened.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_rank_contribution (
    contribution_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rank_id                uuid NOT NULL
                           REFERENCES knowledge.differential_rank(rank_id)
                           ON DELETE CASCADE,

    evidence_instance_id   uuid
                           REFERENCES knowledge.differential_evidence_instance(
                               evidence_instance_id
                           ),

    rule_code              text
                           REFERENCES knowledge.differential_rule(rule_code),

    dimension              text,

    raw_contribution       numeric(14,5) NOT NULL DEFAULT 0,

    contextual_multiplier  numeric(14,5) NOT NULL DEFAULT 1,

    final_contribution     numeric(14,5) NOT NULL DEFAULT 0,

    direction              text NOT NULL CHECK (
        direction IN (
            'POSITIVE',
            'NEGATIVE',
            'NEUTRAL'
        )
    ),

    explanation            text,

    created_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_contrib_rank
    ON knowledge.differential_rank_contribution(rank_id);

CREATE INDEX IF NOT EXISTS idx_diff_contrib_evidence
    ON knowledge.differential_rank_contribution(evidence_instance_id);


-- =============================================================================
-- 25. AUDITABLE DIFFERENTIAL REASON
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_reason (
    reason_id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rank_id                uuid NOT NULL
                           REFERENCES knowledge.differential_rank(rank_id)
                           ON DELETE CASCADE,

    hypothesis_code        text NOT NULL
                           REFERENCES knowledge.differential_hypothesis(
                               hypothesis_code
                           ),

    rule_codes             text[],

    triggering_facts       text[],

    triggering_phenotypes  text[],

    relevant_mechanisms    text[],

    evidence_codes         text[],

    supporting_evidence    text[],

    refuting_evidence      text[],

    discriminating_evidence text[],

    contradictory_evidence text[],

    missing_expected_features text[],

    competing_hypotheses   text[],

    weight_contribution    numeric(14,5) NOT NULL DEFAULT 0,

    explanation            text,

    clinical_summary       text,

    uncertainty_statement  text,

    safety_statement       text,

    created_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_reason_rank
    ON knowledge.differential_reason(rank_id);

CREATE INDEX IF NOT EXISTS idx_diff_reason_hyp
    ON knowledge.differential_reason(hypothesis_code);


COMMENT ON TABLE knowledge.differential_reason IS
'Auditable clinical explanation of why a hypothesis was ranked where it was. Must expose supporting, refuting, discriminating and contradictory evidence, missing expected features, competing hypotheses, uncertainty and safety considerations.';


-- =============================================================================
-- 26. DIAGNOSTIC CERTAINTY
--
-- DO NOT collapse ranking into diagnosis.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_certainty (
    certainty_code       text PRIMARY KEY,

    code                 text NOT NULL UNIQUE,

    label                text NOT NULL,

    description          text,

    sort_order           integer NOT NULL,

    status               text NOT NULL DEFAULT 'active'
                         CHECK (
                             status IN (
                                 'active',
                                 'draft',
                                 'retired'
                             )
                         )
);


-- =============================================================================
-- 27. DIAGNOSTIC CONCLUSION
--
-- Runtime.
--
-- A conclusion is made AFTER reasoning, not merely because rank = 1.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_conclusion (
    conclusion_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    reasoning_pass_id     uuid NOT NULL
                          REFERENCES knowledge.differential_reasoning_pass(
                              reasoning_pass_id
                          ),

    hypothesis_code       text NOT NULL
                          REFERENCES knowledge.differential_hypothesis(
                              hypothesis_code
                          ),

    certainty_code        text
                          REFERENCES knowledge.differential_certainty(
                              certainty_code
                          ),

    conclusion_type       text NOT NULL CHECK (
        conclusion_type IN (
            'WORKING_DIAGNOSIS',
            'PROVISIONAL_DIAGNOSIS',
            'CONFIRMED_DIAGNOSIS',
            'EXCLUDED_DIAGNOSIS',
            'POSSIBLE_DIAGNOSIS',
            'UNRESOLVED'
        )
    ),

    clinical_basis        text,

    evidence_summary      text,

    remaining_uncertainty text,

    required_next_step    text,

    made_by               text,

    made_at               timestamptz NOT NULL DEFAULT now(),

    status                text NOT NULL DEFAULT 'ACTIVE'
                          CHECK (
                              status IN (
                                  'ACTIVE',
                                  'SUPERSEDED',
                                  'ENTERED_IN_ERROR'
                              )
                          )
);


-- =============================================================================
-- 28. DIFFERENTIAL QUESTION
--
-- The differential should be able to tell the clinical engine:
--
-- "What do I need to know next to separate these hypotheses?"
--
-- This connects H8 BACK to H2/H3/H6/H7.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_question (
    differential_question_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    discriminator_code       text
                             REFERENCES knowledge.differential_discriminator(
                                 discriminator_code
                             ),

    clinical_question        text NOT NULL,

    question_type            text NOT NULL CHECK (
        question_type IN (
            'HISTORY',
            'EXAMINATION',
            'INVESTIGATION',
            'CONTEXT',
            'EXPOSURE',
            'TEMPORAL',
            'SAFETY'
        )
    ),

    target_hypothesis_code   text
                             REFERENCES knowledge.differential_hypothesis(
                                 hypothesis_code
                             ),

    competing_hypothesis_code text
                             REFERENCES knowledge.differential_hypothesis(
                                 hypothesis_code
                             ),

    expected_information_gain numeric(10,4),

    rationale                text,

    evidence_claim_code      text
                             REFERENCES knowledge.source_claim(claim_code),

    status                   text NOT NULL DEFAULT 'active'
                             CHECK (
                                 status IN (
                                     'active',
                                     'draft',
                                     'retired'
                                 )
                             ),

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_question_target
    ON knowledge.differential_question(target_hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_question_competing
    ON knowledge.differential_question(competing_hypothesis_code);


COMMENT ON TABLE knowledge.differential_question IS
'Questions or assessments that would meaningfully distinguish competing hypotheses. H8 therefore does not only rank diagnoses; it can identify what information is still missing and route back to H2/H6/H7.';


-- =============================================================================
-- 29. DIFFERENTIAL NEXT ACTION
--
-- H8 should be able to state:
--
--   "The leading possibilities are A and B.
--    The most useful next discriminator is X."
--
-- This is NOT treatment.
-- It is diagnostic reasoning output.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_next_action (
    action_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    reasoning_pass_id         uuid NOT NULL
                              REFERENCES knowledge.differential_reasoning_pass(
                                  reasoning_pass_id
                              )
                              ON DELETE CASCADE,

    action_type               text NOT NULL CHECK (
        action_type IN (
            'ASK_HISTORY',
            'PERFORM_EXAMINATION',
            'ORDER_INVESTIGATION',
            'REVIEW_CONTEXT',
            'ASSESS_SAFETY',
            'REASSESS',
            'NO_ADDITIONAL_INFORMATION_REQUIRED'
        )
    ),

    target_code               text,

    clinical_question         text,

    expected_information_gain numeric(10,4),

    urgency                   text NOT NULL DEFAULT 'ROUTINE'
                              CHECK (
                                  urgency IN (
                                      'IMMEDIATE',
                                      'URGENT',
                                      'SOON',
                                      'ROUTINE'
                                  )
                              ),

    rationale                 text,

    related_hypotheses        text[],

    created_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_diff_next_action_pass
    ON knowledge.differential_next_action(reasoning_pass_id);


-- =============================================================================
-- 30. DIFFERENTIAL SOURCE CLAIM EDGE
--
-- Makes provenance explicit at the reasoning relationship level.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_claim_edge (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_claim_code     text NOT NULL
                          REFERENCES knowledge.source_claim(claim_code),

    object_type            text NOT NULL CHECK (
        object_type IN (
            'HYPOTHESIS',
            'EVIDENCE',
            'RULE',
            'WEIGHT',
            'DISCRIMINATOR',
            'TEMPORAL_PATTERN',
            'SAFETY_PROFILE',
            'COMPLICATION'
        )
    ),

    object_code            text NOT NULL,

    claim_role             text NOT NULL CHECK (
        claim_role IN (
            'DEFINITION',
            'ASSOCIATION',
            'CAUSATION',
            'DIAGNOSTIC_VALUE',
            'PROGNOSTIC_VALUE',
            'SAFETY',
            'EPIDEMIOLOGY',
            'MANAGEMENT_RELEVANCE'
        )
    ),

    evidence_strength      text NOT NULL DEFAULT 'moderate'
                           CHECK (
                               evidence_strength IN (
                                   'strong',
                                   'moderate',
                                   'weak'
                               )
                           ),

    notes                  text,

    created_at             timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        source_claim_code,
        object_type,
        object_code,
        claim_role
    )
);


-- =============================================================================
-- 31. UPDATED PROVENANCE COMMENT
-- =============================================================================

COMMENT ON TABLE knowledge.provenance IS
'Derivation edges from source claims to compiled AMEXAN objects across H1-H8. H8 provenance includes hypotheses, evidence relationships, mechanisms, temporal patterns, discriminators, safety profiles, rules, weights and diagnostic reasoning objects.';


-- =============================================================================
-- 32. INDEXES FOR CLINICAL QUERY PERFORMANCE
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_diff_evidence_claim
    ON knowledge.differential_evidence(evidence_claim_code);

CREATE INDEX IF NOT EXISTS idx_diff_rule_claim
    ON knowledge.differential_rule(evidence_claim_code);

CREATE INDEX IF NOT EXISTS idx_diff_hyp_source
    ON knowledge.differential_source(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_temporal_fit_hyp
    ON knowledge.differential_hypothesis_temporal_fit(hypothesis_code);

CREATE INDEX IF NOT EXISTS idx_diff_temporal_fit_pattern
    ON knowledge.differential_hypothesis_temporal_fit(
        temporal_pattern_code
    );

CREATE INDEX IF NOT EXISTS idx_diff_safety_mnm
    ON knowledge.differential_safety_profile(
        must_not_miss,
        immediate_action
    );

CREATE INDEX IF NOT EXISTS idx_diff_conclusion_pass
    ON knowledge.differential_conclusion(reasoning_pass_id);


-- =============================================================================
-- 33. UPDATED_AT TRIGGERS
-- =============================================================================

DROP TRIGGER IF EXISTS
trg_knowledge_differential_pathological_process_updated_at
ON knowledge.differential_pathological_process;

CREATE TRIGGER
trg_knowledge_differential_pathological_process_updated_at
BEFORE UPDATE ON knowledge.differential_pathological_process
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS
trg_knowledge_differential_evidence_relation_updated_at
ON knowledge.differential_evidence_relation;

CREATE TRIGGER
trg_knowledge_differential_evidence_relation_updated_at
BEFORE UPDATE ON knowledge.differential_evidence_relation
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS
trg_knowledge_differential_temporal_pattern_updated_at
ON knowledge.differential_temporal_pattern;

CREATE TRIGGER
trg_knowledge_differential_temporal_pattern_updated_at
BEFORE UPDATE ON knowledge.differential_temporal_pattern
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS
trg_knowledge_differential_weight_updated_at
ON knowledge.differential_weight;

CREATE TRIGGER
trg_knowledge_differential_weight_updated_at
BEFORE UPDATE ON knowledge.differential_weight
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 34. MEDICAL INTEGRITY CONSTRAINTS
-- =============================================================================

-- A result/evidence row cannot claim to be both quantitative and absent.
ALTER TABLE knowledge.differential_likelihood_evidence
    ADD CONSTRAINT chk_diff_lr_positive
    CHECK (
        likelihood_type NOT IN ('LR_POSITIVE','LR_NEGATIVE')
        OR likelihood_ratio IS NOT NULL
    );


-- A Bayesian probability must remain mathematically bounded.
ALTER TABLE knowledge.differential_rank
    ADD CONSTRAINT chk_diff_probability_range
    CHECK (
        probability_estimate IS NULL
        OR (
            probability_estimate >= 0
            AND probability_estimate <= 1
        )
    );


-- A temporal interval cannot have a negative duration.
ALTER TABLE knowledge.differential_temporal_pattern
    ADD CONSTRAINT chk_diff_temporal_bounds
    CHECK (
        maximum_duration_hours IS NULL
        OR minimum_duration_hours IS NULL
        OR maximum_duration_hours >= minimum_duration_hours
    );


-- Age boundaries must be coherent.
ALTER TABLE knowledge.differential_hypothesis
    ADD CONSTRAINT chk_diff_age_bounds
    CHECK (
        age_max_days IS NULL
        OR age_min_days IS NULL
        OR age_max_days >= age_min_days
    );


-- =============================================================================
-- 35. SEED UNIVERSAL PATHOLOGICAL PROCESSES
--
-- These are ORGANIZING CATEGORIES, not diagnoses.
-- =============================================================================

INSERT INTO knowledge.differential_pathological_process
(
    process_code,
    code,
    label,
    description,
    sort_order
)
VALUES
(
    'DPP01',
    'CONGENITAL',
    'Congenital',
    'Structural or functional abnormality present from birth or arising from developmental abnormality.',
    10
),
(
    'DPP02',
    'DEGENERATIVE',
    'Degenerative',
    'Progressive deterioration of structure or function over time.',
    20
),
(
    'DPP03',
    'INFECTIVE_INFLAMMATORY',
    'Infective / inflammatory',
    'Disease caused by infection or inflammatory processes.',
    30
),
(
    'DPP04',
    'METABOLIC',
    'Metabolic',
    'Disease arising from abnormal biochemical, endocrine or metabolic processes.',
    40
),
(
    'DPP05',
    'NEOPLASTIC',
    'Neoplastic',
    'Benign or malignant abnormal cellular proliferation.',
    50
),
(
    'DPP06',
    'NUTRITIONAL',
    'Nutritional',
    'Disease associated with deficiency, excess or imbalance of nutrients.',
    60
),
(
    'DPP07',
    'TOXIC',
    'Toxic',
    'Disease resulting from drugs, poisons, chemicals or environmental toxins.',
    70
),
(
    'DPP08',
    'TRAUMATIC',
    'Traumatic',
    'Disease or injury resulting from mechanical or physical trauma.',
    80
),
(
    'DPP09',
    'VASCULAR',
    'Vascular',
    'Disease resulting from arterial, venous, microvascular or lymphatic pathology.',
    90
)
ON CONFLICT (process_code) DO NOTHING;


-- =============================================================================
-- 36. SEED EVIDENCE RELATIONSHIPS
-- =============================================================================

INSERT INTO knowledge.differential_evidence_relation
(
    relation_code,
    code,
    label,
    description,
    default_direction,
    sort_order
)
VALUES
(
    'DER01',
    'SUPPORTS',
    'Supports',
    'Evidence increases consideration of the hypothesis.',
    'POSITIVE',
    10
),
(
    'DER02',
    'REFUTES',
    'Refutes',
    'Evidence decreases consideration of the hypothesis.',
    'NEGATIVE',
    20
),
(
    'DER03',
    'DISCRIMINATES_FOR',
    'Discriminates for',
    'Evidence is particularly useful in distinguishing this hypothesis from a competing hypothesis.',
    'POSITIVE',
    30
),
(
    'DER04',
    'DISCRIMINATES_AGAINST',
    'Discriminates against',
    'Evidence particularly favors a competing hypothesis.',
    'NEGATIVE',
    40
),
(
    'DER05',
    'CONTRADICTS',
    'Contradicts',
    'Evidence conflicts with an expected feature or mechanism.',
    'NEGATIVE',
    50
),
(
    'DER06',
    'COMPATIBLE',
    'Compatible',
    'Evidence is compatible but has little or no discriminatory value.',
    'NEUTRAL',
    60
)
ON CONFLICT (relation_code) DO NOTHING;


-- =============================================================================
-- 37. SEED TEMPORAL CLASSES
-- =============================================================================

INSERT INTO knowledge.differential_temporal_pattern
(
    temporal_pattern_code,
    code,
    label,
    onset_class,
    description,
    sort_order
)
VALUES
(
    'DTP01',
    'HYPERACUTE',
    'Hyperacute',
    'HYPERACUTE',
    'Developing within minutes to hours.',
    10
),
(
    'DTP02',
    'ACUTE',
    'Acute',
    'ACUTE',
    'Developing over hours to days.',
    20
),
(
    'DTP03',
    'SUBACUTE',
    'Subacute',
    'SUBACUTE',
    'Developing over days to weeks.',
    30
),
(
    'DTP04',
    'CHRONIC',
    'Chronic',
    'CHRONIC',
    'Persisting or evolving over months to years.',
    40
),
(
    'DTP05',
    'RECURRENT',
    'Recurrent',
    'RECURRENT',
    'Repeated discrete episodes separated by periods of improvement.',
    50
),
(
    'DTP06',
    'RELAPSING',
    'Relapsing',
    'RELAPSING',
    'Recurring disease activity following partial or complete remission.',
    60
),
(
    'DTP07',
    'PROGRESSIVE',
    'Progressive',
    'PROGRESSIVE',
    'Increasing severity or extent over time.',
    70
),
(
    'DTP08',
    'INTERMITTENT',
    'Intermittent',
    'INTERMITTENT',
    'Symptoms occur episodically rather than continuously.',
    80
),
(
    'DTP09',
    'FLUCTUATING',
    'Fluctuating',
    'FLUCTUATING',
    'Variable intensity over time.',
    90
)
ON CONFLICT (temporal_pattern_code) DO NOTHING;


-- =============================================================================
-- 38. SEED DIFFERENTIAL STATUS
-- =============================================================================

INSERT INTO knowledge.differential_status
(
    status_code,
    label,
    description,
    sort_order,
    is_terminal
)
VALUES
(
    'PENDING',
    'Pending',
    'Candidate has not yet been fully evaluated.',
    10,
    false
),
(
    'ACTIVE',
    'Active',
    'Currently under active differential consideration.',
    20,
    false
),
(
    'REFINED',
    'Refined',
    'Candidate has been reassessed using additional clinical information.',
    30,
    false
),
(
    'RESOLVED',
    'Resolved',
    'Reasoning regarding this candidate has been completed.',
    40,
    true
),
(
    'DROPPED',
    'Dropped',
    'Candidate is no longer being actively considered.',
    50,
    true
),
(
    'CONFIRMED',
    'Confirmed',
    'Candidate has sufficient evidence for a confirmed clinical conclusion.',
    60,
    true
),
(
    'ENTERED_IN_ERROR',
    'Entered in error',
    'Reasoning record was invalidated.',
    70,
    true
)
ON CONFLICT (status_code) DO NOTHING;


-- =============================================================================
-- 39. SEED CERTAINTY
-- =============================================================================

INSERT INTO knowledge.differential_certainty
(
    certainty_code,
    code,
    label,
    description,
    sort_order
)
VALUES
(
    'DC01',
    'UNDETERMINED',
    'Undetermined',
    'Insufficient information to assign meaningful diagnostic certainty.',
    10
),
(
    'DC02',
    'POSSIBLE',
    'Possible',
    'The hypothesis remains clinically plausible but is insufficiently established.',
    20
),
(
    'DC03',
    'PROBABLE',
    'Probable',
    'The available evidence favors the hypothesis over relevant alternatives.',
    30
),
(
    'DC04',
    'WORKING_DIAGNOSIS',
    'Working diagnosis',
    'The hypothesis is sufficiently supported to guide current clinical management while uncertainty remains.',
    40
),
(
    'DC05',
    'CONFIRMED',
    'Confirmed',
    'The available evidence establishes the diagnosis to the required clinical standard.',
    50
),
(
    'DC06',
    'EXCLUDED',
    'Excluded',
    'The available evidence makes the diagnosis sufficiently unlikely for the relevant clinical context.',
    60
)
ON CONFLICT (certainty_code) DO NOTHING;


-- =============================================================================
-- 40. SEED WEIGHT DIMENSIONS
-- =============================================================================

INSERT INTO knowledge.differential_weight
(
    weight_code,
    dimension,
    direction,
    weight,
    description,
    version,
    effective_from
)
VALUES
(
    'DWT01',
    'PREVALENCE_PRIOR',
    'POSITIVE',
    1.00,
    'Context-specific prior probability or prevalence contribution.',
    1,
    CURRENT_DATE
),
(
    'DWT02',
    'EVIDENCE_STRENGTH',
    'POSITIVE',
    1.00,
    'Strength of the observed evidence relationship.',
    1,
    CURRENT_DATE
),
(
    'DWT03',
    'HARD_SYMPTOM',
    'POSITIVE',
    1.00,
    'Contribution from strongly characteristic symptoms.',
    1,
    CURRENT_DATE
),
(
    'DWT04',
    'SYNDROME_FIT',
    'POSITIVE',
    1.00,
    'Degree to which the total phenotype forms a syndrome expected for the hypothesis.',
    1,
    CURRENT_DATE
),
(
    'DWT05',
    'PHENOTYPE_FIT',
    'POSITIVE',
    1.00,
    'Fit of normalized phenotypes to the hypothesis.',
    1,
    CURRENT_DATE
),
(
    'DWT06',
    'MECHANISM_PLAUSIBILITY',
    'POSITIVE',
    1.00,
    'Compatibility with the underlying pathophysiological mechanism.',
    1,
    CURRENT_DATE
),
(
    'DWT07',
    'TEMPORAL_FIT',
    'POSITIVE',
    1.00,
    'Compatibility between disease natural history and observed time course.',
    1,
    CURRENT_DATE
),
(
    'DWT08',
    'ANATOMICAL_FIT',
    'POSITIVE',
    1.00,
    'Compatibility with anatomical distribution and localization.',
    1,
    CURRENT_DATE
),
(
    'DWT09',
    'RISK_FACTOR_FIT',
    'POSITIVE',
    1.00,
    'Compatibility with established risk factors.',
    1,
    CURRENT_DATE
),
(
    'DWT10',
    'EXPOSURE_FIT',
    'POSITIVE',
    1.00,
    'Compatibility with relevant environmental, occupational, infectious or toxic exposure.',
    1,
    CURRENT_DATE
),
(
    'DWT11',
    'SEVERITY_FIT',
    'POSITIVE',
    1.00,
    'Compatibility between expected disease severity and observed severity.',
    1,
    CURRENT_DATE
),
(
    'DWT12',
    'COMPLICATION_FIT',
    'POSITIVE',
    1.00,
    'Compatibility with observed complications or downstream effects.',
    1,
    CURRENT_DATE
),
(
    'DWT13',
    'RED_FLAG',
    'POSITIVE',
    1.00,
    'Safety contribution associated with a clinically dangerous possibility.',
    1,
    CURRENT_DATE
),
(
    'DWT14',
    'CONTEXT_FIT',
    'POSITIVE',
    1.00,
    'Compatibility with age, sex, pregnancy, comorbidity, geography and clinical context.',
    1,
    CURRENT_DATE
),
(
    'DWT15',
    'EXCLUSION_POWER',
    'POSITIVE',
    1.00,
    'Strength with which a finding can exclude or substantially lower consideration of a hypothesis.',
    1,
    CURRENT_DATE
),
(
    'DWT16',
    'DISCRIMINATING_POWER',
    'POSITIVE',
    1.00,
    'Value of a feature in distinguishing competing hypotheses.',
    1,
    CURRENT_DATE
),
(
    'DWT17',
    'CONTRADICTION_PENALTY',
    'NEGATIVE',
    1.00,
    'Penalty where observed findings contradict the expected disease model.',
    1,
    CURRENT_DATE
),
(
    'DWT18',
    'REFUTATION_PENALTY',
    'NEGATIVE',
    1.00,
    'Penalty from evidence that actively argues against the hypothesis.',
    1,
    CURRENT_DATE
),
(
    'DWT19',
    'REDUNDANCY_PENALTY',
    'NEGATIVE',
    1.00,
    'Prevents multiple correlated observations from being incorrectly counted as independent evidence.',
    1,
    CURRENT_DATE
),
(
    'DWT20',
    'MISSING_EXPECTED_FEATURE',
    'NEGATIVE',
    1.00,
    'Penalty only where an expected feature was explicitly assessed and appropriately absent.',
    1,
    CURRENT_DATE
)
ON CONFLICT (weight_code) DO NOTHING;


-- =============================================================================
-- 41. FINAL ARCHITECTURAL COMMENT
-- =============================================================================

COMMENT ON SCHEMA knowledge IS
'AMEXAN Medical Knowledge Layer. H8 is the universal clinical reasoning layer consuming normalized history, examination and investigation information and producing an auditable differential, not an opaque disease prediction.';


-- =============================================================================
-- END H8 MIGRATION 032
-- =============================================================================