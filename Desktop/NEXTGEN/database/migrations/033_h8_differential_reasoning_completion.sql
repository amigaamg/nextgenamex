-- =============================================================================
-- AMEXAN MEDICAL KNOWLEDGE COMPILER
-- H8 MIGRATION 033R
--
-- UNIVERSAL CLINICAL DIFFERENTIAL-REASONING COMPLETION
--
-- PURPOSE
-- -------
-- H8 is the interpretation layer between the accumulated clinical database
-- and the clinician-facing working diagnosis.
--
-- H2/H3/H4/H5/H6/H7:
--
--     What happened?
--     What symptoms are present?
--     What history matters?
--     What context matters?
--     What was examined?
--     What investigations were performed?
--
-- H8:
--
--     What does the total clinical dataset mean?
--
-- CLINICAL REASONING MODEL
--
--     RAW CLINICAL OBSERVATIONS
--              â†“
--     NORMALIZED FACTS
--              â†“
--     PHENOTYPES / SYNDROMES
--              â†“
--     ANATOMICAL LOCALIZATION
--              â†“
--     MECHANISM
--              â†“
--     PATHOLOGICAL PROCESS
--              â†“
--     DIAGNOSTIC CANDIDATES
--              â†“
--     SUPPORTING / OPPOSING EVIDENCE
--              â†“
--     EXPECTED vs OBSERVED vs MISSING
--              â†“
--     EXCLUSIONS / RED FLAGS
--              â†“
--     SEVERITY / COMPLICATIONS
--              â†“
--     AETIOLOGY
--              â†“
--     DIAGNOSTIC CRITERIA
--              â†“
--     CONFIDENCE + UNCERTAINTY
--              â†“
--     NEXT INFORMATION THAT WOULD CHANGE THE DECISION
--
-- CONSTITUTIONAL RULES
-- --------------------
--
-- 1. H8 does not replace clinical examination.
-- 2. H8 does not invent facts.
-- 3. UNKNOWN is never ABSENT.
-- 4. NOT_ASSESSED is never ABSENT.
-- 5. A diagnosis is not confirmed merely because it has the highest score.
-- 6. Critical exclusions may override ranking.
-- 7. Severity and complications are independently reasoned.
-- 8. Aetiology is independently reasoned.
-- 9. Evidence must be traceable.
-- 10. Every computed conclusion must be reproducible from a reasoning_run.
-- 11. The UI never calculates diagnostic probability.
-- 12. The CPU never hardcodes disease-specific IF/ELSE chains.
-- 13. Knowledge is versioned.
-- 14. Clinical reasoning is versioned.
-- 15. Every medically meaningful rule should have provenance.
--
-- =============================================================================


-- =============================================================================
-- A. DIAGNOSTIC ONTOLOGY
-- =============================================================================


-- -----------------------------------------------------------------------------
-- A1. DIAGNOSIS CATEGORY
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_category (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_code TEXT NOT NULL UNIQUE,

    label TEXT NOT NULL,

    reasoning_level TEXT NOT NULL CHECK (
        reasoning_level IN (
            'PRESENTATION',
            'SYNDROME',
            'ANATOMICAL_LOCALIZATION',
            'ORGAN_SYSTEM',
            'MECHANISM',
            'PATHOLOGICAL_PROCESS',
            'DISEASE',
            'AETIOLOGY',
            'COMPLICATION',
            'SEVERITY',
            'PROGNOSIS'
        )
    ),

    pathological_process TEXT CHECK (
        pathological_process IN (
            'CONGENITAL',
            'DEGENERATIVE',
            'INFECTIVE_INFLAMMATORY',
            'METABOLIC',
            'NEOPLASTIC',
            'NUTRITIONAL',
            'TOXIC',
            'TRAUMATIC',
            'VASCULAR',
            'IATROGENIC',
            'IMMUNOLOGIC',
            'FUNCTIONAL',
            'NONE'
        )
    ),

    description TEXT,

    sort_order INTEGER NOT NULL DEFAULT 1,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.diagnosis_category IS
'Universal diagnostic hierarchy. Separates presentation, syndrome, localization, mechanism, disease, aetiology, complication, severity and prognosis.';


DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_category_updated_at
ON knowledge.diagnosis_category;

CREATE TRIGGER trg_knowledge_diagnosis_category_updated_at
BEFORE UPDATE ON knowledge.diagnosis_category
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- A2. UNIVERSAL DIAGNOSIS CONCEPT
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_concept (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code TEXT NOT NULL UNIQUE,

    concept_id UUID REFERENCES knowledge.concept(id),

    concept_code TEXT,

    canonical_name TEXT NOT NULL,

    short_label TEXT,

    description TEXT,

    category_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_category(category_code),

    diagnosis_type TEXT NOT NULL CHECK (
        diagnosis_type IN (
            'PRESENTATION',
            'SYNDROME',
            'ANATOMICAL_LOCALIZATION',
            'MECHANISM',
            'DIAGNOSIS',
            'AETIOLOGY',
            'COMPLICATION',
            'SEVERITY',
            'PROGNOSIS'
        )
    ),

    base_weight NUMERIC(8,4) NOT NULL DEFAULT 0,

    is_must_not_miss BOOLEAN NOT NULL DEFAULT false,

    is_time_critical BOOLEAN NOT NULL DEFAULT false,

    is_confirmable BOOLEAN NOT NULL DEFAULT true,

    requires_exclusion BOOLEAN NOT NULL DEFAULT false,

    applies_to_context_codes TEXT[] NOT NULL DEFAULT '{}',

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.diagnosis_concept IS
'Universal clinical diagnostic concept. Diagnosis, syndrome, mechanism, complication, severity and aetiology are represented as concepts rather than disease-specific tables.';


CREATE INDEX IF NOT EXISTS idx_diag_concept_category
ON knowledge.diagnosis_concept(category_code);

CREATE INDEX IF NOT EXISTS idx_diag_concept_type
ON knowledge.diagnosis_concept(diagnosis_type);

CREATE INDEX IF NOT EXISTS idx_diag_concept_critical
ON knowledge.diagnosis_concept(is_must_not_miss)
WHERE is_must_not_miss = true;


DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_concept_updated_at
ON knowledge.diagnosis_concept;

CREATE TRIGGER trg_knowledge_diagnosis_concept_updated_at
BEFORE UPDATE ON knowledge.diagnosis_concept
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- B. DIAGNOSTIC RELATIONSHIP GRAPH
-- =============================================================================

-- This is extremely important.
--
-- Medicine is relational.
--
-- Pneumonia may:
--   cause hypoxaemia
--   produce consolidation
--   cause pleural effusion
--   be bacterial/viral/fungal/mycobacterial
--   coexist with anaemia
--   mimic pulmonary embolism
--   be complicated by sepsis
--
-- The database must understand those relationships rather than storing isolated
-- disease rows.


CREATE TABLE IF NOT EXISTS knowledge.diagnosis_relationship (
    relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    target_diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    relationship_type TEXT NOT NULL CHECK (
        relationship_type IN (
            'CAUSES',
            'CAUSED_BY',
            'PREDISPOSES_TO',
            'COMPLICATED_BY',
            'MANIFESTS_AS',
            'PRESENTS_AS',
            'HAS_MECHANISM',
            'HAS_AETIOLOGY',
            'HAS_SEVERITY_STATE',
            'MIMICS',
            'MIMICKED_BY',
            'ASSOCIATED_WITH',
            'COEXISTS_WITH',
            'EXCLUDES',
            'ALTERNATIVE_TO',
            'SUBTYPE_OF',
            'PROGRESSES_TO',
            'PRECEDES',
            'RESULTS_FROM'
        )
    ),

    strength NUMERIC(5,2) NOT NULL DEFAULT 1.00,

    directionality TEXT NOT NULL DEFAULT 'DIRECTED'
        CHECK (directionality IN ('DIRECTED','BIDIRECTIONAL')),

    description TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (source_diagnosis_code <> target_diagnosis_code),

    UNIQUE (
        source_diagnosis_code,
        target_diagnosis_code,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.diagnosis_relationship IS
'Clinical relationship graph connecting diagnoses, syndromes, mechanisms, aetiologies, complications, mimics and progression states.';


CREATE INDEX IF NOT EXISTS idx_diag_rel_source
ON knowledge.diagnosis_relationship(source_diagnosis_code);

CREATE INDEX IF NOT EXISTS idx_diag_rel_target
ON knowledge.diagnosis_relationship(target_diagnosis_code);

CREATE INDEX IF NOT EXISTS idx_diag_rel_type
ON knowledge.diagnosis_relationship(relationship_type);


-- =============================================================================
-- C. AETIOLOGY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_etiology (
    etiology_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    etiology_code TEXT NOT NULL UNIQUE,

    code TEXT NOT NULL,

    canonical_name TEXT NOT NULL,

    label TEXT,

    description TEXT,

    etiology_class TEXT CHECK (
        etiology_class IN (
            'INFECTIVE',
            'BACTERIAL',
            'VIRAL',
            'FUNGAL',
            'MYCOBACTERIAL',
            'PARASITIC',
            'AUTOIMMUNE',
            'IMMUNOLOGIC',
            'GENETIC',
            'CONGENITAL',
            'METABOLIC',
            'ENDOCRINE',
            'VASCULAR',
            'NEOPLASTIC',
            'TRAUMATIC',
            'TOXIC',
            'DRUG_RELATED',
            'IATROGENIC',
            'NUTRITIONAL',
            'DEGENERATIVE',
            'FUNCTIONAL',
            'UNKNOWN'
        )
    ),

    sort_order INTEGER NOT NULL DEFAULT 1,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.diagnosis_etiology_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    etiology_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_etiology(etiology_code)
        ON DELETE CASCADE,

    relationship TEXT NOT NULL CHECK (
        relationship IN (
            'COMMON',
            'IMPORTANT',
            'CHARACTERISTIC',
            'POSSIBLE',
            'RARE',
            'EXCLUDED'
        )
    ),

    prior_weight NUMERIC(8,4) NOT NULL DEFAULT 0,

    context_codes TEXT[] NOT NULL DEFAULT '{}',

    rationale TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (diagnosis_code, etiology_code)
);

COMMENT ON TABLE knowledge.diagnosis_etiology_link IS
'Separates WHAT disease is present from WHY it is present. A diagnosis can have multiple possible aetiologies whose probability is independently reasoned.';


-- =============================================================================
-- D. COMPLICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_complication (
    complication_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    complication_code TEXT NOT NULL UNIQUE,

    concept_id UUID REFERENCES knowledge.concept(id),

    canonical_name TEXT NOT NULL,

    label TEXT,

    description TEXT,

    severity_weight NUMERIC(8,4) NOT NULL DEFAULT 0,

    is_critical BOOLEAN NOT NULL DEFAULT false,

    is_time_critical BOOLEAN NOT NULL DEFAULT false,

    sort_order INTEGER NOT NULL DEFAULT 1,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.diagnosis_complication_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    complication_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_complication(complication_code)
        ON DELETE CASCADE,

    relationship TEXT NOT NULL CHECK (
        relationship IN (
            'COMMON',
            'IMPORTANT',
            'POSSIBLE',
            'RARE',
            'EXPECTED_IN_SEVERE_DISEASE'
        )
    ),

    weight NUMERIC(8,4) NOT NULL DEFAULT 1,

    description TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (diagnosis_code, complication_code)
);


-- =============================================================================
-- E. PHENOTYPE RELATIONSHIPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_phenotype (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    phenotype_code TEXT NOT NULL
        REFERENCES knowledge.phenotype(phenotype_code),

    relationship TEXT NOT NULL CHECK (
        relationship IN (
            'CHARACTERISTIC',
            'HIGHLY_ASSOCIATED',
            'COMMONLY_ASSOCIATED',
            'COMPATIBLE',
            'OCCASIONAL',
            'UNUSUAL',
            'MIMIC'
        )
    ),

    weight NUMERIC(8,4) NOT NULL DEFAULT 1,

    discriminative_power NUMERIC(8,4) NOT NULL DEFAULT 0,

    expected_frequency NUMERIC(6,5),

    description TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (diagnosis_code, phenotype_code)
);

COMMENT ON TABLE knowledge.diagnosis_phenotype IS
'Clinical phenotype relationships. discriminative_power allows AMEXAN to distinguish common findings from findings that actually separate competing diagnoses.';


-- =============================================================================
-- F. MECHANISM
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_mechanism (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    mechanism_code TEXT NOT NULL
        REFERENCES knowledge.mechanism(mechanism_code),

    relationship TEXT NOT NULL DEFAULT 'EXPECTED'
        CHECK (
            relationship IN (
                'PRIMARY',
                'EXPECTED',
                'POSSIBLE',
                'SECONDARY',
                'ALTERNATIVE'
            )
        ),

    weight NUMERIC(8,4) NOT NULL DEFAULT 1,

    description TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (diagnosis_code, mechanism_code)
);

COMMENT ON TABLE knowledge.diagnosis_mechanism IS
'Mechanistic bridge between observed phenotype and diagnosis. Supports reasoning through disordered function rather than symptom matching.';


-- =============================================================================
-- G. EXPECTED / OBSERVED / MISSING EVIDENCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnostic_expected_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN (
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'EXAMINATION_FINDING',
            'CONTEXT'
        )
    ),

    fact_definition_code TEXT
        REFERENCES clinical.fact_definition(code),

    phenotype_code TEXT
        REFERENCES knowledge.phenotype(phenotype_code),

    mechanism_code TEXT
        REFERENCES knowledge.mechanism(mechanism_code),

    result_interpretation_code TEXT
        REFERENCES knowledge.result_interpretation(code),

    context_code TEXT
        REFERENCES knowledge.clinical_context(code),

    expected_strength TEXT NOT NULL DEFAULT 'MODERATE'
        CHECK (
            expected_strength IN (
                'LOW',
                'MODERATE',
                'HIGH',
                'VERY_HIGH'
            )
        ),

    expected_polarity TEXT NOT NULL DEFAULT 'PRESENT'
        CHECK (
            expected_polarity IN (
                'PRESENT',
                'ABSENT'
            )
        ),

    absence_interpretation TEXT CHECK (
        absence_interpretation IN (
            'NO_EFFECT',
            'WEAKENS',
            'STRONGLY_WEAKENS',
            'EXCLUDES'
        )
    ),

    discriminative_power NUMERIC(8,4) NOT NULL DEFAULT 0,

    what_it_means TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_must_not_miss BOOLEAN NOT NULL DEFAULT false,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE NULLS NOT DISTINCT (
        diagnosis_code,
        evidence_type,
        fact_definition_code,
        phenotype_code,
        mechanism_code,
        result_interpretation_code,
        context_code
    )
);

COMMENT ON TABLE knowledge.diagnostic_expected_evidence IS
'Expected evidence catalogue. Runtime reasoning explicitly compares expected evidence with PRESENT, ABSENT, UNKNOWN and NOT_ASSESSED patient evidence.';


-- =============================================================================
-- H. FOUR-STATE + SAFETY FACT MODEL
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_fact_state (
    state_code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT,

    is_definitive BOOLEAN NOT NULL DEFAULT false,

    permits_positive_evidence BOOLEAN NOT NULL DEFAULT false,

    permits_negative_evidence BOOLEAN NOT NULL DEFAULT false,

    contributes_uncertainty BOOLEAN NOT NULL DEFAULT true,

    sort_order INTEGER NOT NULL,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired'))
);


INSERT INTO knowledge.clinical_fact_state (
    state_code,
    label,
    description,
    is_definitive,
    permits_positive_evidence,
    permits_negative_evidence,
    contributes_uncertainty,
    sort_order,
    status
)
VALUES

(
    'PRESENT',
    'Present',
    'The proposition has been established as true.',
    true,
    true,
    false,
    false,
    1,
    'active'
),

(
    'ABSENT',
    'Absent',
    'The proposition has been deliberately assessed and established as false.',
    true,
    false,
    true,
    false,
    2,
    'active'
),

(
    'UNKNOWN',
    'Unknown',
    'The proposition has not been established either way.',
    false,
    false,
    false,
    true,
    3,
    'active'
),

(
    'NOT_ASSESSED',
    'Not assessed',
    'The proposition has not been sought or measured.',
    false,
    false,
    false,
    true,
    4,
    'active'
),

(
    'NOT_APPLICABLE',
    'Not applicable',
    'The proposition is not applicable to this clinical context.',
    false,
    false,
    false,
    false,
    5,
    'active'
),

(
    'CONFLICTING',
    'Conflicting',
    'Reliable clinical sources disagree.',
    false,
    false,
    false,
    true,
    6,
    'active'
)

ON CONFLICT (state_code)
DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    is_definitive = EXCLUDED.is_definitive,
    permits_positive_evidence = EXCLUDED.permits_positive_evidence,
    permits_negative_evidence = EXCLUDED.permits_negative_evidence,
    contributes_uncertainty = EXCLUDED.contributes_uncertainty,
    sort_order = EXCLUDED.sort_order,
    status = EXCLUDED.status;


-- =============================================================================
-- I. DIAGNOSTIC CRITERIA
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnostic_criterion (
    criterion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    criterion_code TEXT NOT NULL UNIQUE,

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    criterion_name TEXT NOT NULL,

    logic TEXT NOT NULL CHECK (
        logic IN (
            'ALL',
            'ANY',
            'AT_LEAST_N',
            'EXACTLY_N',
            'REQUIRED',
            'EXCLUSION_REQUIRED',
            'TIME_REQUIREMENT',
            'TEST_REQUIRED',
            'CLINICAL_JUDGEMENT'
        )
    ),

    min_count INTEGER,

    max_count INTEGER,

    diagnostic_standard TEXT,

    confirmation_level TEXT NOT NULL DEFAULT 'FORMAL'
        CHECK (
            confirmation_level IN (
                'SUPPORTIVE',
                'CLINICAL',
                'FORMAL'
            )
        ),

    description TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.diagnostic_criterion_condition (
    condition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    criterion_code TEXT NOT NULL
        REFERENCES knowledge.diagnostic_criterion(criterion_code)
        ON DELETE CASCADE,

    condition_code TEXT NOT NULL,

    group_no INTEGER NOT NULL DEFAULT 1,

    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN (
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'EXAMINATION_FINDING',
            'CONTEXT'
        )
    ),

    fact_definition_code TEXT
        REFERENCES clinical.fact_definition(code),

    phenotype_code TEXT
        REFERENCES knowledge.phenotype(phenotype_code),

    mechanism_code TEXT
        REFERENCES knowledge.mechanism(mechanism_code),

    result_interpretation_code TEXT
        REFERENCES knowledge.result_interpretation(code),

    context_code TEXT
        REFERENCES knowledge.clinical_context(code),

    presence TEXT NOT NULL
        CHECK (presence IN ('PRESENT','ABSENT')),

    operator TEXT CHECK (
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

    value TEXT,

    rationale TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (criterion_code, condition_code)
);

COMMENT ON TABLE knowledge.diagnostic_criterion_condition IS
'Atomic conditions within formal diagnostic criteria. group_no permits compound clinical criteria rather than flattening every criterion into a single boolean.';


-- =============================================================================
-- J. CRITICAL EXCLUSIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnostic_exclusion (
    exclusion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    exclusion_code TEXT NOT NULL UNIQUE,

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN (
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'EXAMINATION_FINDING',
            'CONTEXT'
        )
    ),

    fact_definition_code TEXT
        REFERENCES clinical.fact_definition(code),

    phenotype_code TEXT
        REFERENCES knowledge.phenotype(phenotype_code),

    mechanism_code TEXT
        REFERENCES knowledge.mechanism(mechanism_code),

    result_interpretation_code TEXT
        REFERENCES knowledge.result_interpretation(code),

    context_code TEXT
        REFERENCES knowledge.clinical_context(code),

    does_what TEXT NOT NULL CHECK (
        does_what IN (
            'EXCLUDES',
            'DO_NOT_CONFIRM',
            'DEPRIORITIZE',
            'REQUIRES_REASSESSMENT'
        )
    ),

    strength NUMERIC(8,4) NOT NULL DEFAULT 1,

    rationale TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE NULLS NOT DISTINCT (
        diagnosis_code,
        evidence_type,
        fact_definition_code,
        phenotype_code,
        mechanism_code,
        result_interpretation_code,
        context_code
    )
);


-- =============================================================================
-- K. DIFFERENTIAL EVIDENCE RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_evidence_rule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    evidence_rule_code TEXT NOT NULL UNIQUE,

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN (
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'EXAMINATION_FINDING',
            'CONTEXT',
            'ABSENCE'
        )
    ),

    fact_definition_code TEXT
        REFERENCES clinical.fact_definition(code),

    phenotype_code TEXT
        REFERENCES knowledge.phenotype(phenotype_code),

    mechanism_code TEXT
        REFERENCES knowledge.mechanism(mechanism_code),

    result_interpretation_code TEXT
        REFERENCES knowledge.result_interpretation(code),

    context_code TEXT
        REFERENCES knowledge.clinical_context(code),

    required_fact_state TEXT
        REFERENCES knowledge.clinical_fact_state(state_code),

    relationship TEXT NOT NULL CHECK (
        relationship IN (
            'SUPPORTS',
            'STRONGLY_SUPPORTS',
            'WEAKLY_SUPPORTS',
            'NEUTRAL',
            'WEAKLY_OPPOSES',
            'OPPOSES',
            'STRONGLY_OPPOSES',
            'EXCLUDES',
            'REQUIRES_CONFIRMATION'
        )
    ),

    base_strength NUMERIC(8,4) NOT NULL DEFAULT 1,

    discriminative_power NUMERIC(8,4) NOT NULL DEFAULT 0,

    likelihood_ratio_positive NUMERIC(12,6),

    likelihood_ratio_negative NUMERIC(12,6),

    operator TEXT CHECK (
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

    value TEXT,

    rationale TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    rule_version INTEGER NOT NULL DEFAULT 1,

    effective_from DATE,

    effective_to DATE,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.differential_evidence_rule IS
'Versioned candidate+clinical propositionâ†’diagnostic effect. Supports qualitative evidence and, where authoritative data exist, likelihood-ratio based reasoning.';


CREATE INDEX IF NOT EXISTS idx_diff_ev_rule_dx
ON knowledge.differential_evidence_rule(diagnosis_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_rule_fact
ON knowledge.differential_evidence_rule(fact_definition_code);

CREATE INDEX IF NOT EXISTS idx_diff_ev_rule_pheno
ON knowledge.differential_evidence_rule(phenotype_code);


-- =============================================================================
-- L. TEMPORAL REASONING
-- =============================================================================

-- Clinical diagnoses are strongly constrained by time.
--
-- Examples:
--   seconds â†’ minutes
--   hours
--   days
--   weeks
--   months
--   years
--
-- Acute, subacute and chronic presentations should therefore be explicit
-- reasoning dimensions rather than buried in free text.


CREATE TABLE IF NOT EXISTS knowledge.temporal_pattern (
    temporal_pattern_code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    minimum_duration_seconds BIGINT,

    maximum_duration_seconds BIGINT,

    onset_type TEXT CHECK (
        onset_type IN (
            'HYPERACUTE',
            'ACUTE',
            'SUBACUTE',
            'CHRONIC',
            'RECURRENT',
            'RELAPSING',
            'PROGRESSIVE',
            'INTERMITTENT',
            'CONTINUOUS'
        )
    ),

    description TEXT,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired'))
);


CREATE TABLE IF NOT EXISTS knowledge.diagnosis_temporal_pattern (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    temporal_pattern_code TEXT NOT NULL
        REFERENCES knowledge.temporal_pattern(temporal_pattern_code),

    relationship TEXT NOT NULL CHECK (
        relationship IN (
            'CHARACTERISTIC',
            'COMMON',
            'COMPATIBLE',
            'UNUSUAL',
            'STRONGLY_OPPOSES'
        )
    ),

    weight NUMERIC(8,4) NOT NULL DEFAULT 1,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (diagnosis_code, temporal_pattern_code)
);


-- =============================================================================
-- M. CONTEXT / EPIDEMIOLOGICAL PRIORS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.diagnosis_context_prior (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code)
        ON DELETE CASCADE,

    context_code TEXT NOT NULL
        REFERENCES knowledge.clinical_context(code),

    prior_weight NUMERIC(8,4) NOT NULL DEFAULT 0,

    prevalence_band TEXT CHECK (
        prevalence_band IN (
            'VERY_LOW',
            'LOW',
            'MODERATE',
            'HIGH',
            'VERY_HIGH',
            'UNKNOWN'
        )
    ),

    rationale TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    is_active BOOLEAN NOT NULL DEFAULT true,

    UNIQUE (diagnosis_code, context_code)
);

COMMENT ON TABLE knowledge.diagnosis_context_prior IS
'Context-dependent prior information. Base prevalence is never treated as diagnosis; it only modifies the starting probability before patient-specific evidence.';


-- =============================================================================
-- N. CLINICAL HYPOTHESIS STATES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_hypothesis_state (
    state_code TEXT PRIMARY KEY,

    label TEXT NOT NULL,

    description TEXT,

    sort_order INTEGER NOT NULL,

    is_terminal BOOLEAN NOT NULL DEFAULT false,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired'))
);


INSERT INTO knowledge.clinical_hypothesis_state
(state_code,label,description,sort_order,is_terminal)
VALUES

(
    'CONSIDERED',
    'Considered',
    'Candidate remains under active consideration.',
    1,
    false
),

(
    'POSSIBLE',
    'Possible',
    'Evidence is compatible but insufficient to make the diagnosis leading.',
    2,
    false
),

(
    'SUPPORTED',
    'Supported',
    'Evidence materially favours the hypothesis.',
    3,
    false
),

(
    'LEADING',
    'Leading',
    'Currently the best-supported explanation of the clinical dataset.',
    4,
    false
),

(
    'UNLIKELY',
    'Unlikely',
    'Evidence weighs against the diagnosis, but it is not excluded.',
    5,
    false
),

(
    'DEPRIORITIZED',
    'Deprioritized',
    'Another explanation has substantially greater explanatory power or urgency.',
    6,
    false
),

(
    'EXCLUDED',
    'Excluded',
    'Available evidence provides a valid exclusion.',
    7,
    true
),

(
    'CONFIRMED',
    'Confirmed',
    'The diagnosis satisfies the applicable confirmation standard.',
    8,
    true
),

(
    'REJECTED',
    'Rejected',
    'The diagnosis is no longer clinically defensible based on the available evidence.',
    9,
    true
)

ON CONFLICT (state_code) DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_terminal = EXCLUDED.is_terminal;


-- =============================================================================
-- O. REASONING RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.reasoning_rule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code TEXT NOT NULL UNIQUE,

    trigger_type TEXT NOT NULL CHECK (
        trigger_type IN (
            'ALWAYS',
            'PHENOTYPE',
            'MECHANISM',
            'FACT',
            'RESULT_INTERPRETATION',
            'CONTEXT',
            'DIAGNOSIS',
            'CANDIDATE_STATE',
            'EVIDENCE_SUMMARY',
            'SEVERITY',
            'COMPLICATION'
        )
    ),

    trigger_code TEXT,

    target_diagnosis_code TEXT
        REFERENCES knowledge.diagnosis_concept(code),

    action TEXT NOT NULL CHECK (
        action IN (
            'ACTIVATE',
            'SUPPORT',
            'STRONGLY_SUPPORT',
            'OPPOSE',
            'DEPRIORITIZE',
            'EXCLUDE',
            'DO_NOT_CONFIRM',
            'MARK_CRITICAL',
            'MARK_TIME_CRITICAL',
            'REQUEST_INFORMATION',
            'CREATE_GAP',
            'ESCALATE'
        )
    ),

    weight_delta NUMERIC(8,4) NOT NULL DEFAULT 0,

    message TEXT,

    evidence_claim_code TEXT
        REFERENCES knowledge.source_claim(claim_code),

    applies_to_context_codes TEXT[] NOT NULL DEFAULT '{}',

    is_active BOOLEAN NOT NULL DEFAULT true,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.reasoning_rule_condition (
    condition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code TEXT NOT NULL
        REFERENCES knowledge.reasoning_rule(rule_code)
        ON DELETE CASCADE,

    condition_code TEXT NOT NULL,

    evidence_type TEXT NOT NULL CHECK (
        evidence_type IN (
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'CONTEXT',
            'SEVERITY',
            'COMPLICATION'
        )
    ),

    fact_definition_code TEXT
        REFERENCES clinical.fact_definition(code),

    phenotype_code TEXT
        REFERENCES knowledge.phenotype(phenotype_code),

    mechanism_code TEXT
        REFERENCES knowledge.mechanism(mechanism_code),

    result_interpretation_code TEXT
        REFERENCES knowledge.result_interpretation(code),

    context_code TEXT
        REFERENCES knowledge.clinical_context(code),

    operator TEXT NOT NULL CHECK (
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

    value TEXT,

    required_fact_state TEXT
        REFERENCES knowledge.clinical_fact_state(state_code),

    rationale TEXT,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (rule_code, condition_code)
);


CREATE TABLE IF NOT EXISTS knowledge.reasoning_rule_action (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code TEXT NOT NULL
        REFERENCES knowledge.reasoning_rule(rule_code)
        ON DELETE CASCADE,

    action_type TEXT NOT NULL CHECK (
        action_type IN (
            'CREATE_QUESTION_GAP',
            'CREATE_INVESTIGATION_GAP',
            'CREATE_EXAMINATION_GAP',
            'TRIGGER_QUESTION',
            'TRIGGER_INVESTIGATION',
            'ESCALATE',
            'REQUEST_REVIEW',
            'CREATE_REASSESSMENT'
        )
    ),

    question_code TEXT,

    investigation_code TEXT,

    message TEXT,

    sort_order INTEGER NOT NULL DEFAULT 1,

    is_active BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        rule_code,
        action_type,
        question_code,
        investigation_code
    )
);


-- =============================================================================
-- P. REASONING VERSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.reasoning_version (
    version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    version_code TEXT NOT NULL UNIQUE,

    ruleset_version TEXT NOT NULL,

    knowledge_version TEXT NOT NULL,

    engine_version TEXT NOT NULL,

    evidence_model_version TEXT,

    diagnostic_ontology_version TEXT,

    effective_from DATE,

    change_note TEXT,

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'draft',
                'superseded',
                'retired'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- Q. REASONING RUN
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.reasoning_run (
    run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id UUID,

    encounter_id UUID,

    input_state_version TEXT,

    reasoning_version_id UUID
        REFERENCES knowledge.reasoning_version(version_id),

    ruleset_version TEXT,

    knowledge_version TEXT,

    engine_version TEXT,

    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    completed_at TIMESTAMPTZ,

    status TEXT NOT NULL DEFAULT 'RUNNING'
        CHECK (
            status IN (
                'RUNNING',
                'COMPLETED',
                'FAILED',
                'SUPERSEDED'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_reasoning_run_encounter
ON knowledge.reasoning_run(encounter_id);

CREATE INDEX IF NOT EXISTS idx_reasoning_run_patient
ON knowledge.reasoning_run(patient_id);


-- =============================================================================
-- R. PATIENT-SPECIFIC DIFFERENTIAL CANDIDATE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_candidate (
    candidate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code),

    candidate_type TEXT NOT NULL CHECK (
        candidate_type IN (
            'PRIMARY_DIAGNOSIS',
            'SECONDARY_DIAGNOSIS',
            'COEXISTING_DIAGNOSIS',
            'COMPLICATION',
            'COMORBIDITY',
            'RISK_STATE',
            'INCIDENTAL_FINDING',
            'AETIOLOGY',
            'SEVERITY_STATE'
        )
    ),

    prior_probability NUMERIC(10,8),

    current_status TEXT NOT NULL DEFAULT 'CONSIDERED'
        REFERENCES knowledge.clinical_hypothesis_state(state_code),

    reasoning_level TEXT NOT NULL DEFAULT 'DISEASE'
        CHECK (
            reasoning_level IN (
                'PRESENTATION',
                'SYNDROME',
                'ANATOMICAL_LOCALIZATION',
                'ORGAN_SYSTEM',
                'MECHANISM',
                'PATHOLOGICAL_PROCESS',
                'DISEASE',
                'AETIOLOGY',
                'COMPLICATION',
                'SEVERITY',
                'PROGNOSIS'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (run_id, diagnosis_code, candidate_type)
);


-- =============================================================================
-- S. EVIDENCE LEDGER
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_evidence_ledger (
    entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    candidate_id UUID NOT NULL
        REFERENCES knowledge.differential_candidate(candidate_id)
        ON DELETE CASCADE,

    diagnosis_code TEXT NOT NULL,

    proposal_type TEXT NOT NULL CHECK (
        proposal_type IN (
            'FACT',
            'PHENOTYPE',
            'MECHANISM',
            'RESULT_INTERPRETATION',
            'EXAMINATION_FINDING',
            'CONTEXT',
            'ABSENCE'
        )
    ),

    proposal_code TEXT NOT NULL,

    fact_state TEXT
        REFERENCES knowledge.clinical_fact_state(state_code),

    relationship TEXT NOT NULL CHECK (
        relationship IN (
            'SUPPORTS',
            'STRONGLY_SUPPORTS',
            'WEAKLY_SUPPORTS',
            'NEUTRAL',
            'WEAKLY_OPPOSES',
            'OPPOSES',
            'STRONGLY_OPPOSES',
            'EXCLUDES',
            'REQUIRES_CONFIRMATION'
        )
    ),

    direction_sign TEXT NOT NULL
        CHECK (direction_sign IN ('+','-','0')),

    strength NUMERIC(10,6) NOT NULL DEFAULT 1,

    likelihood_ratio NUMERIC(12,6),

    evidence_rule_code TEXT,

    reasoning_rule_code TEXT,

    rule_version TEXT,

    quality_source TEXT CHECK (
        quality_source IN (
            'PATIENT_REPORTED',
            'CAREGIVER_REPORTED',
            'CLINICIAN_OBSERVED',
            'CLINICIAN_MEASURED',
            'LABORATORY_VERIFIED',
            'IMAGING_VERIFIED',
            'PATHOLOGY_VERIFIED',
            'DEVICE_MEASURED',
            'EXTERNAL_RECORD',
            'INFERRED'
        )
    ),

    context_codes TEXT[] NOT NULL DEFAULT '{}',

    note TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.differential_evidence_ledger IS
'Patient-specific auditable evidence ledger. Every clinical proposition affecting a candidate is recorded here with state, direction, strength, provenance and rule version.';


-- =============================================================================
-- T. DIFFERENTIAL SCORE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.differential_score (
    score_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    candidate_id UUID NOT NULL
        REFERENCES knowledge.differential_candidate(candidate_id)
        ON DELETE CASCADE,

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    support NUMERIC(12,6) NOT NULL DEFAULT 0,

    against NUMERIC(12,6) NOT NULL DEFAULT 0,

    uncertainty NUMERIC(12,6) NOT NULL DEFAULT 0,

    net_support NUMERIC(12,6)
        GENERATED ALWAYS AS (support - against) STORED,

    posterior_probability NUMERIC(12,10),

    rank_position INTEGER,

    scoring_model TEXT,

    scoring_version TEXT,

    computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (run_id, candidate_id)
);


COMMENT ON TABLE knowledge.differential_score IS
'CPU-computed candidate support, opposition, uncertainty and optional probability. UI renders this; UI never computes it.';


-- =============================================================================
-- U. UNCERTAINTY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_uncertainty (
    uncertainty_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    candidate_id UUID NOT NULL
        REFERENCES knowledge.differential_candidate(candidate_id)
        ON DELETE CASCADE,

    dimension TEXT NOT NULL CHECK (
        dimension IN (
            'PRESENTATION',
            'LOCALIZATION',
            'MECHANISM',
            'AETIOLOGY',
            'SEVERITY',
            'DIAGNOSIS',
            'COMPLICATION',
            'PROGNOSIS',
            'CONFIRMATION'
        )
    ),

    level TEXT NOT NULL CHECK (
        level IN (
            'NONE',
            'LOW',
            'MODERATE',
            'HIGH',
            'CRITICAL'
        )
    ),

    why_uncertain TEXT,

    missing_evidence TEXT[],

    what_would_change_ranking TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- V. INFORMATION GAPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_information_gap (
    gap_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    candidate_id UUID
        REFERENCES knowledge.differential_candidate(candidate_id)
        ON DELETE CASCADE,

    gap_code TEXT NOT NULL,

    gap_type TEXT NOT NULL CHECK (
        gap_type IN (
            'QUESTION',
            'INVESTIGATION',
            'EXAMINATION',
            'CONTEXT',
            'TEMPORAL',
            'CONFIRMATION',
            'SEVERITY'
        )
    ),

    information_priority TEXT NOT NULL DEFAULT 'ROUTINE'
        CHECK (
            information_priority IN (
                'ROUTINE',
                'IMPORTANT',
                'URGENT',
                'EMERGENCY'
            )
        ),

    proposals TEXT[],

    reason TEXT,

    expected_information_gain NUMERIC(10,6),

    priority INTEGER NOT NULL DEFAULT 0,

    status TEXT NOT NULL DEFAULT 'OPEN'
        CHECK (
            status IN (
                'OPEN',
                'RESOLVED',
                'CLOSED',
                'SUPERSEDED'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TABLE IF NOT EXISTS knowledge.information_gap_question (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    gap_id UUID NOT NULL
        REFERENCES knowledge.clinical_information_gap(gap_id)
        ON DELETE CASCADE,

    question_code TEXT NOT NULL,

    rationale TEXT,

    expected_information_gain NUMERIC(10,6),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (gap_id, question_code)
);


CREATE TABLE IF NOT EXISTS knowledge.information_gap_investigation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    gap_id UUID NOT NULL
        REFERENCES knowledge.clinical_information_gap(gap_id)
        ON DELETE CASCADE,

    investigation_code TEXT NOT NULL,

    rationale TEXT,

    expected_information_gain NUMERIC(10,6),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (gap_id, investigation_code)
);


-- =============================================================================
-- W. CLINICAL WORKING HYPOTHESIS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_hypothesis (
    hypothesis_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    diagnosis_code TEXT NOT NULL
        REFERENCES knowledge.diagnosis_concept(code),

    role TEXT NOT NULL CHECK (
        role IN (
            'PRIMARY',
            'SECONDARY',
            'COEXISTING',
            'COMPLICATION',
            'COMORBIDITY',
            'RISK_STATE',
            'INCIDENTAL_FINDING',
            'AETIOLOGY',
            'SEVERITY_STATE'
        )
    ),

    status TEXT NOT NULL DEFAULT 'CONSIDERED'
        REFERENCES knowledge.clinical_hypothesis_state(state_code),

    certainty TEXT NOT NULL DEFAULT 'POSSIBLE'
        CHECK (
            certainty IN (
                'DEFINITE',
                'PROBABLE',
                'POSSIBLE',
                'UNCERTAIN'
            )
        ),

    ranked_position INTEGER,

    explanation TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- =============================================================================
-- X. REASON OBJECT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.differential_reason CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.differential_reason (
    reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    candidate_id UUID NOT NULL
        REFERENCES knowledge.differential_candidate(candidate_id)
        ON DELETE CASCADE,

    hypothesis_code TEXT,

    leading_support TEXT[],

    leading_opposition TEXT[],

    discriminating_features TEXT[],

    missing_expected_features TEXT[],

    critical_exclusions TEXT[],

    triggered_rules TEXT[],

    triggering_facts TEXT[],

    triggering_phenotypes TEXT[],

    relevant_mechanisms TEXT[],

    evidence_codes TEXT[],

    uncertainty_reasons TEXT[],

    information_gaps TEXT[],

    explanation TEXT NOT NULL,

    generated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


COMMENT ON TABLE knowledge.differential_reason IS
'Human-readable, auditable explanation of why a candidate is ranked where it is.';


-- =============================================================================
-- Y. REASONING EVENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.reasoning_event (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id UUID NOT NULL
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE CASCADE,

    event_type TEXT NOT NULL CHECK (
        event_type IN (
            'FACT_ADDED',
            'FACT_STATE_CHANGED',
            'PHENOTYPE_ACTIVATED',
            'MECHANISM_ACTIVATED',
            'CANDIDATE_ADDED',
            'EVIDENCE_APPLIED',
            'EVIDENCE_WITHDRAWN',
            'CANDIDATE_RERANKED',
            'CANDIDATE_DEPRIORITIZED',
            'CANDIDATE_EXCLUDED',
            'DIAGNOSIS_CONFIRMED',
            'DIAGNOSIS_REJECTED',
            'AETIOLOGY_REFINED',
            'COMPLICATION_IDENTIFIED',
            'SEVERITY_CHANGED',
            'INFORMATION_GAP_CREATED',
            'QUESTION_TRIGGERED',
            'INVESTIGATION_TRIGGERED',
            'REASSESSMENT_TRIGGERED'
        )
    ),

    object_type TEXT,

    object_code TEXT,

    detail TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_reasoning_event_run
ON knowledge.reasoning_event(run_id);

CREATE INDEX IF NOT EXISTS idx_reasoning_event_type
ON knowledge.reasoning_event(event_type);


-- =============================================================================
-- Z. PROVENANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.reasoning_provenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    claim_id TEXT NOT NULL
        REFERENCES knowledge.source_claim(claim_id),

    object_type TEXT NOT NULL,

    object_id UUID NOT NULL,

    object_code TEXT,

    relationship TEXT NOT NULL DEFAULT 'derived_from',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (
        claim_id,
        object_type,
        object_id
    )
);


CREATE INDEX IF NOT EXISTS idx_reasoning_provenance_claim
ON knowledge.reasoning_provenance(claim_id);

CREATE INDEX IF NOT EXISTS idx_reasoning_provenance_object
ON knowledge.reasoning_provenance(object_type, object_id);


-- =============================================================================
-- FINAL CONSTITUTIONAL COMMENTS
-- =============================================================================

COMMENT ON SCHEMA knowledge IS
'AMEXAN Medical Knowledge Layer. H8 interprets the accumulated clinical database using versioned, auditable clinical reasoning knowledge.';


COMMENT ON TABLE knowledge.differential_candidate IS
'Patient-specific candidate diagnoses. A candidate is an explanation, not a fact.';


COMMENT ON TABLE knowledge.differential_score IS
'Computed output. Never stored as immutable clinical truth. Scores are reproducible only in combination with the reasoning run, evidence ledger, knowledge version and engine version.';


COMMENT ON TABLE knowledge.clinical_uncertainty IS
'Explicit uncertainty model. AMEXAN must explain what is uncertain, why it is uncertain and what information would change the ranking.';


COMMENT ON TABLE knowledge.clinical_information_gap IS
'Closed-loop clinical reasoning. H8 identifies missing information; H3/H6/H7 can obtain it; H8 then re-evaluates the differential.';


COMMENT ON TABLE knowledge.reasoning_event IS
'Auditable chronological record of computational clinical reasoning events.';


-- =============================================================================
-- END H8 MIGRATION 033R
-- =============================================================================
