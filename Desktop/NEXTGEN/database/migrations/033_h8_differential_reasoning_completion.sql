-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H8 migration 033: universal differential-reasoning completion
-- =============================================================================
-- COMPLETES the H8 universal differential-reasoning interface to the full H8
-- specification. Migration 032 laid the skeleton (hypothesis/evidence/rule/
-- weight/source/version/status + runtime rank/reason). This migration adds the
-- reasoning ARCHITECTURE the H8 spec requires, still grounded ONLY in Hutchison
-- Clinical Methods 24e (via knowledge.source_claim in migration 032's seeds):
--
--   A. KNOWLEDGE LAYER (versioned, auditable, claim-grounded):
--         diagnosis_category        — grouping + Box 2.3 pathological process level
--         diagnosis_concept         — universal registry of diagnoses (H8 §34)
--         diagnosis_etiology        — bacterial/viral/mycobacterial/cardiac/... (§4)
--         diagnosis_complication    — separable complication concepts (§4)
--         diagnosis_phenotype       — diagnosis ↔ phenotype relationships (§35)
--         diagnosis_mechanism       — diagnosis ↔ mechanism relationships (§36)
--         diagnostic_expected_evidence — EXPECTED evidence tables (§37/§20)
--         diagnostic_criterion      — ALL/ANY/AT_LEAST_N/REQUIRED/... (§23/§24)
--         diagnostic_criterion_condition — value guards on criteria (§24)
--         diagnostic_exclusion      — critical exclusions (§25)
--         clinical_hypothesis_state — explicit states: CONSIDERED..REJECTED (§22)
--         clinical_fact_state       — PRESENT/ABSENT/UNKNOWN/NOT_ASSESSED (§10)
--         reasoning_rule            — IF (phenotype+investigation) THEN action (§25)
--         reasoning_rule_condition  — guards on reasoning rules
--         reasoning_rule_action     — consequences (STRONGLY_SUPPORT/DO_NOT_CONFIRM/REQUEST_INFO)
--         differential_evidence_rule — versioned candidate+proposition→effect (§38/§39)
--         reasoning_provenance      — claim → reasoning object edges (§45-style)
--         reasoning_version         — ruleset/knowledge/engine version registry (§39/§40)
--   B. RUNTIME LAYER (empty at seed time — the CPU fills them per reasoning run,
--      H6/H7 precedent): differential_candidate, differential_score,
--      differential_evidence_ledger, clinical_hypothesis, clinical_uncertainty,
--      clinical_information_gap, information_gap_question,
--      information_gap_investigation, reasoning_run, reasoning_event.
--
-- §9/§11 four-state fact model: every DISCRETE proposition the CPU reasons over
--   can be PRESENT / ABSENT / UNKNOWN / NOT_ASSESSED. UNKNOWN is NEVER treated as
--   ABSENT — that is a written safety rule (H8 §11) and is enforced here by
--   storing state as DATA, not by silently defaulting.
--
-- §42 constitutional rule: the UI never calculates the differential. The CPU
--   writes differential_score + differential_rank; the UI renders them.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A1. diagnosis_category — universal separation of types (H8 §4/§34/§45)
--     Merges the §45 reasoning levels (SYNDROME..COMPLICATION) with the Box 2.3
--     pathological-process framework (HCH2-0005).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnosis_category (
    category_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_code      text NOT NULL UNIQUE,
    label              text NOT NULL,
    reasoning_level    text NOT NULL CHECK (reasoning_level IN
        ('SYNDROME','ORGAN_SYSTEM','MECHANISM','DISEASE','AETIOLOGY','COMPLICATION','SEVERITY')),
    pathological_process text CHECK (pathological_process IN
        ('CONGENITAL','DEGENERATIVE','INFECTIVE_INFLAMMATORY','METABOLIC','NEOPLASTIC',
         'NUTRITIONAL','TOXIC','TRAUMATIC','VASCULAR','NONE')),
    description        text,
    sort_order         integer NOT NULL DEFAULT 1,
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.diagnosis_category
    IS 'Category + reasoning-level (H8 §4/§34/§45) plus Box 2.3 pathological process (HCH2-0005). Reason levels prevent premature disease labeling.';

-- ---------------------------------------------------------------------------
-- A2. diagnosis_concept — universal registry of diagnoses (H8 §34)
--     Reusable concepts; never one table per disease. References knowledge.concept.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnosis_concept (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code               text NOT NULL UNIQUE,             -- DA001..
    concept_id         uuid REFERENCES knowledge.concept(id),
    concept_code       text,
    canonical_name     text NOT NULL,
    short_label        text,
    description        text,
    category_code      text NOT NULL REFERENCES knowledge.diagnosis_category(category_code),
    diagnosis_type     text NOT NULL CHECK (diagnosis_type IN
        ('DIAGNOSIS','ETIOLOGY','COMPLICATION','MECHANISM','SYNDROME','SEVERITY')),
    base_weight        numeric(5,2) NOT NULL DEFAULT 0,   -- starting prior (§5 prior_probability)
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.diagnosis_concept
    IS 'Universal diagnosis registry (H8 §34). A diagnosis is a reusable concept, never a per-disease table.';
CREATE INDEX IF NOT EXISTS idx_diag_concept_cat  ON knowledge.diagnosis_concept(category_code);
CREATE INDEX IF NOT EXISTS idx_diag_concept_con  ON knowledge.diagnosis_concept(concept_id);
DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_concept_updated_at ON knowledge.diagnosis_concept;
CREATE TRIGGER trg_knowledge_diagnosis_concept_updated_at
    BEFORE UPDATE ON knowledge.diagnosis_concept FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A3. diagnosis_etiology — causes (H8 §4): bacterial/viral/mycobacterial/...
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnosis_etiology (
    etiology_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    etiology_code       text NOT NULL UNIQUE,             -- AET-..
    code                text NOT NULL,
    canonical_name      text NOT NULL,
    label               text,
    description         text,
    sort_order          integer NOT NULL DEFAULT 1,
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.diagnosis_etiology
    IS 'Etiology registry (H8 §4). Aetiology is a SEPARATE reasoning dimension from diagnosis; it is not interchangeable.';
DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_etiology_updated_at ON knowledge.diagnosis_etiology;
CREATE TRIGGER trg_knowledge_diagnosis_etiology_updated_at
    BEFORE UPDATE ON knowledge.diagnosis_etiology FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A4. diagnosis_complication — separable complications (H8 §4)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnosis_complication (
    complication_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    complication_code   text NOT NULL UNIQUE,             -- DC-..
    concept_id          uuid REFERENCES knowledge.concept(id),
    canonical_name      text NOT NULL,
    label               text,
    description         text,
    is_critical         boolean NOT NULL DEFAULT false,
    sort_order          integer NOT NULL DEFAULT 1,
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.diagnosis_complication
    IS 'Complication registry (H8 §4). Complications are reasoned SEPARATELY from the primary diagnosis.';
DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_complication_updated_at ON knowledge.diagnosis_complication;
CREATE TRIGGER trg_knowledge_diagnosis_complication_updated_at
    BEFORE UPDATE ON knowledge.diagnosis_complication FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A5. diagnosis_phenotype — diagnosis ↔ phenotype (H8 §35)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnosis_phenotype (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    diagnosis_code   text NOT NULL REFERENCES knowledge.diagnosis_concept(code) ON DELETE CASCADE,
    phenotype_code   text NOT NULL REFERENCES knowledge.phenotype(phenotype_code),
    relationship     text NOT NULL CHECK (relationship IN
        ('COMMONLY_ASSOCIATED','STRONGLY_ASSOCIATED','CHARACTERISTIC','OCCASIONALLY_ASSOCIATED','MIMICS')),
    weight           numeric(5,2) NOT NULL DEFAULT 1.00,
    description      text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (diagnosis_code, phenotype_code)
);
COMMENT ON TABLE knowledge.diagnosis_phenotype
    IS 'Diagnosis → phenotype relationships (H8 §35). The phenotype layer sits between facts and diagnosis (§16).';
CREATE INDEX IF NOT EXISTS idx_diag_pheno_dx ON knowledge.diagnosis_phenotype(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_phenotype_updated_at ON knowledge.diagnosis_phenotype;
CREATE TRIGGER trg_knowledge_diagnosis_phenotype_updated_at
    BEFORE UPDATE ON knowledge.diagnosis_phenotype FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A6. diagnosis_mechanism — diagnosis ↔ mechanism (H8 §36)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnosis_mechanism (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    diagnosis_code   text NOT NULL REFERENCES knowledge.diagnosis_concept(code) ON DELETE CASCADE,
    mechanism_code   text NOT NULL REFERENCES knowledge.mechanism(mechanism_code),
    weight           numeric(5,2) NOT NULL DEFAULT 1.00,
    description      text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (diagnosis_code, mechanism_code)
);
COMMENT ON TABLE knowledge.diagnosis_mechanism
    IS 'Diagnosis → mechanism relationships (H8 §36). CPU reasons FACT → PHENOTYPE → MECHANISM → DIAGNOSIS (§17).';
CREATE INDEX IF NOT EXISTS idx_diag_mech_dx ON knowledge.diagnosis_mechanism(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_diagnosis_mechanism_updated_at ON knowledge.diagnosis_mechanism;
CREATE TRIGGER trg_knowledge_diagnosis_mechanism_updated_at
    BEFORE UPDATE ON knowledge.diagnosis_mechanism FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A7. diagnostic_expected_evidence — EXPECTED vs OBSERVED (H8 §19/§20/§37)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnostic_expected_evidence (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    diagnosis_code          text NOT NULL REFERENCES knowledge.diagnosis_concept(code) ON DELETE CASCADE,
    evidence_type           text NOT NULL CHECK (evidence_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','EXAMINATION_FINDING','CONTEXT')),
    fact_definition_code    text REFERENCES clinical.fact_definition(code),
    phenotype_code          text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code          text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    context_code            text REFERENCES knowledge.clinical_context(code),
    expected_strength       text NOT NULL DEFAULT 'MODERATE' CHECK (expected_strength IN
        ('LOW','MODERATE','HIGH','VERY_HIGH')),
    what_it_means           text,                         -- if present: + ; if absent: -
    evidence_claim_code     text REFERENCES knowledge.source_claim(claim_code),
    is_must_not_miss        boolean NOT NULL DEFAULT false,
    is_active               boolean NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    -- NULLS NOT DISTINCT (PG15+): fact/result/context columns are NULL for most rows;
    -- without this the seeded INSERT ... ON CONFLICT can never dedupe and every
    -- seed re-run duplicates the expected-evidence catalogue (idempotency law).
    UNIQUE NULLS NOT DISTINCT (diagnosis_code, evidence_type, fact_definition_code, phenotype_code,
            mechanism_code, result_interpretation_code, context_code)
);
COMMENT ON TABLE knowledge.diagnostic_expected_evidence
    IS 'Expected evidence for a diagnosis (H8 §37). H8 compares EXPECTED vs OBSERVED vs MISSING (§20) instead of a bare compatibility number.';
CREATE INDEX IF NOT EXISTS idx_diag_exp_dx ON knowledge.diagnostic_expected_evidence(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_diag_expected_updated_at ON knowledge.diagnostic_expected_evidence;
CREATE TRIGGER trg_knowledge_diag_expected_updated_at
    BEFORE UPDATE ON knowledge.diagnostic_expected_evidence FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A8. diagnostic_criterion + condition — structured confirmation (H8 §23/§24)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnostic_criterion (
    criterion_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    criterion_code      text NOT NULL UNIQUE,            -- DCRIT..
    diagnosis_code      text NOT NULL REFERENCES knowledge.diagnosis_concept(code) ON DELETE CASCADE,
    criterion_name      text NOT NULL,
    logic               text NOT NULL CHECK (logic IN
        ('ALL','ANY','AT_LEAST_N','REQUIRED','EXCLUSION_REQUIRED','TIME_REQUIREMENT','TEST_REQUIRED')),
    min_count           integer,                          -- for AT_LEAST_N
    description         text,
    diagnostic_standard text,                             -- where criteria exist (§23)
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.diagnostic_criterion
    IS 'Structured diagnostic criteria (H8 §23/§24). CONFIRMED is never score>threshold — it must match a diagnostic standard.';
CREATE INDEX IF NOT EXISTS idx_diag_crit_dx ON knowledge.diagnostic_criterion(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_diagnostic_criterion_updated_at ON knowledge.diagnostic_criterion;
CREATE TRIGGER trg_knowledge_diagnostic_criterion_updated_at
    BEFORE UPDATE ON knowledge.diagnostic_criterion FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.diagnostic_criterion_condition (
    condition_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    criterion_code        text NOT NULL REFERENCES knowledge.diagnostic_criterion(criterion_code) ON DELETE CASCADE,
    condition_code        text NOT NULL,                 -- DCC..
    evidence_type         text NOT NULL CHECK (evidence_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','EXAMINATION_FINDING','CONTEXT')),
    fact_definition_code  text REFERENCES clinical.fact_definition(code),
    phenotype_code        text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code        text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    context_code          text REFERENCES knowledge.clinical_context(code),
    presence              text NOT NULL CHECK (presence IN ('PRESENT','ABSENT')),   -- WHAT must be present/absent
    operator              text CHECK (operator IN ('=', '!=', '>', '>=', '<', '<=', 'IN', 'BETWEEN', 'IS_TRUE', 'IS_FALSE')),
    value                 text,
    rationale             text,
    is_active             boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (criterion_code, condition_code)
);
COMMENT ON TABLE knowledge.diagnostic_criterion_condition
    IS 'Value-guards and membership requirements inside a diagnostic criterion (H8 §24).';
CREATE INDEX IF NOT EXISTS idx_diag_crit_cond_crit ON knowledge.diagnostic_criterion_condition(criterion_code);

-- ---------------------------------------------------------------------------
-- A9. diagnostic_exclusion — critical exclusions (H8 §25)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.diagnostic_exclusion (
    exclusion_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    exclusion_code       text NOT NULL UNIQUE,           -- DEX..
    diagnosis_code       text NOT NULL REFERENCES knowledge.diagnosis_concept(code) ON DELETE CASCADE,
    evidence_type        text NOT NULL CHECK (evidence_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','EXAMINATION_FINDING','CONTEXT')),
    fact_definition_code text REFERENCES clinical.fact_definition(code),
    phenotype_code       text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code       text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    context_code         text REFERENCES knowledge.clinical_context(code),
    does_what            text NOT NULL CHECK (does_what IN ('EXCLUDES','DO_NOT_CONFIRM','DEPRIORITIZE')),
    rationale            text,
    evidence_claim_code  text REFERENCES knowledge.source_claim(claim_code),
    is_active            boolean NOT NULL DEFAULT true,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (diagnosis_code, evidence_type, fact_definition_code, phenotype_code,
            mechanism_code, result_interpretation_code, context_code)
);
COMMENT ON TABLE knowledge.diagnostic_exclusion
    IS 'Critical exclusions (H8 §25): a finding that EXCLUDES / blocks confirmation / deprioritizes a candidate.';
CREATE INDEX IF NOT EXISTS idx_diag_excl_dx ON knowledge.diagnostic_exclusion(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_diagnostic_exclusion_updated_at ON knowledge.diagnostic_exclusion;
CREATE TRIGGER trg_knowledge_diagnostic_exclusion_updated_at
    BEFORE UPDATE ON knowledge.diagnostic_exclusion FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A10. clinical_hypothesis_state — explicit candidate lifecycle (H8 §22)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.clinical_hypothesis_state (
    state_code   text PRIMARY KEY,                       -- CONSIDERED..REJECTED
    label        text NOT NULL,
    description  text,
    sort_order   integer NOT NULL,
    is_terminal  boolean NOT NULL DEFAULT false,
    status       text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired'))
);
COMMENT ON TABLE knowledge.clinical_hypothesis_state
    IS 'Explicit differential candidate states (H8 §22): CONSIDERED, SUPPORTED, LEADING, POSSIBLE, UNLIKELY, DEPRIORITIZED, EXCLUDED, CONFIRMED, REJECTED. Transitions require explicit criteria (§23).';
CREATE INDEX IF NOT EXISTS idx_hyp_state_sort ON knowledge.clinical_hypothesis_state(sort_order);

-- ---------------------------------------------------------------------------
-- A11. clinical_fact_state — the four-state fact model (H8 §9/§10/§11)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.clinical_fact_state (
    state_code    text PRIMARY KEY,                      -- PRESENT/ABSENT/UNKNOWN/NOT_ASSESSED/NOT_APPLICABLE/CONFLICTING
    label         text NOT NULL,
    description   text,
    is_definitive boolean NOT NULL DEFAULT false,        -- only PRESENT/ABSENT drive STRONG evidence
    sort_order    integer NOT NULL,
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired'))
);
COMMENT ON TABLE knowledge.clinical_fact_state
    IS 'Four-state fact model (H8 §10). UNKNOWN must NEVER be treated as ABSENT (§11) — safety rule.';
INSERT INTO knowledge.clinical_fact_state (state_code, label, description, is_definitive, sort_order, status) VALUES
    ('PRESENT','Present','A discrete clinical proposition observed/measured to be true.',true,  1,'active'),
    ('ABSENT','Absent','A discrete clinical proposition observed/measured to be false.',true,  2,'active'),
    ('UNKNOWN','Unknown','The proposition has not been established either way.',            false, 3,'active'),
    ('NOT_ASSESSED','Not assessed','The proposition has not been asked/measured.',          false, 4,'active'),
    ('NOT_APPLICABLE','Not applicable','The proposition does not apply in this context.',   false, 5,'active'),
    ('CONFLICTING','Conflicting','Sources disagree about the proposition.',                 false, 6,'active')
ON CONFLICT (state_code) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    is_definitive = EXCLUDED.is_definitive, sort_order = EXCLUDED.sort_order, status = EXCLUDED.status;

-- ---------------------------------------------------------------------------
-- A12. reasoning_rule + condition + action (H8 §25/§26)
--     Rules are DATA and versioned; never if-chains in CPU code.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.reasoning_rule (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code                 text NOT NULL UNIQUE,        -- RR001..
    trigger_type              text NOT NULL CHECK (trigger_type IN
        ('ALWAYS','PHENOTYPE','MECHANISM','FACT','RESULT_INTERPRETATION','CONTEXT','DIAGNOSIS',
         'CANDIDATE_STATE','EVIDENCE_SUMMARY')),
    trigger_code              text,                         -- phenotype/mechanism/fact/interpretation/context/diagnosis code
    target_diagnosis_code     text REFERENCES knowledge.diagnosis_concept(code),
    action                    text NOT NULL CHECK (action IN
        ('ACTIVATE','SUPPORT','STRONGLY_SUPPORT','OPPOSE','DEPRIORITIZE','EXCLUDE',
         'DO_NOT_CONFIRM','MARK_CRITICAL','REQUEST_INFORMATION','CREATE_GAP')),
    weight_delta              numeric(5,2) NOT NULL DEFAULT 0,
    message                   text,
    evidence_claim_code       text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes  text[] NOT NULL DEFAULT '{}',
    is_active                 boolean NOT NULL DEFAULT true,
    status                    text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.reasoning_rule
    IS 'Data-driven reasoning rules (H8 §25): IF phenotype+investigation THEN strongly_support. Never hard-coded disease logic.';
CREATE INDEX IF NOT EXISTS idx_reas_rule_target ON knowledge.reasoning_rule(target_diagnosis_code);
CREATE INDEX IF NOT EXISTS idx_reas_rule_trigger ON knowledge.reasoning_rule(trigger_type, trigger_code);
DROP TRIGGER IF EXISTS trg_knowledge_reasoning_rule_updated_at ON knowledge.reasoning_rule;
CREATE TRIGGER trg_knowledge_reasoning_rule_updated_at
    BEFORE UPDATE ON knowledge.reasoning_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.reasoning_rule_condition (
    condition_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code           text NOT NULL REFERENCES knowledge.reasoning_rule(rule_code) ON DELETE CASCADE,
    condition_code      text NOT NULL,                    -- RRC..
    evidence_type       text NOT NULL CHECK (evidence_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','CONTEXT')),
    fact_definition_code text REFERENCES clinical.fact_definition(code),
    phenotype_code      text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code      text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    context_code        text REFERENCES knowledge.clinical_context(code),
    operator            text NOT NULL CHECK (operator IN ('=', '!=', '>', '>=', '<', '<=', 'IN', 'BETWEEN', 'IS_TRUE', 'IS_FALSE')),
    value               text,
    rationale           text,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_code, condition_code)
);
COMMENT ON TABLE knowledge.reasoning_rule_condition
    IS 'Value-guards on reasoning rules (H8 §25).';
CREATE INDEX IF NOT EXISTS idx_reas_rule_cond_rule ON knowledge.reasoning_rule_condition(rule_code);

CREATE TABLE IF NOT EXISTS knowledge.reasoning_rule_action (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code             text NOT NULL REFERENCES knowledge.reasoning_rule(rule_code) ON DELETE CASCADE,
    action_type           text NOT NULL CHECK (action_type IN
        ('CREATE_QUESTION_GAP','CREATE_INVESTIGATION_GAP','TRIGGER_QUESTION','TRIGGER_INVESTIGATION',
         'ESCALATE','REQUEST_REVIEW')),
    question_code         text NOT NULL DEFAULT '',          -- H3 question to ask (empty = none)
    investigation_code    text NOT NULL DEFAULT '',          -- H7 investigation concept code (empty = none)
    message               text,
    sort_order            integer NOT NULL DEFAULT 1,
    is_active             boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_code, action_type, question_code, investigation_code)
);
COMMENT ON TABLE knowledge.reasoning_rule_action
    IS 'Consequences of a fired reasoning rule (H8 §30/§31 closed loop H3⇄H8 and H8⇄H7).';
CREATE INDEX IF NOT EXISTS idx_reas_act_rule ON knowledge.reasoning_rule_action(rule_code);

-- ---------------------------------------------------------------------------
-- A13. differential_evidence_rule — versioned candidate+proposition→effect (§38/§39)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_evidence_rule (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_rule_code        text NOT NULL UNIQUE,        -- DEV..001
    diagnosis_code            text NOT NULL REFERENCES knowledge.diagnosis_concept(code) ON DELETE CASCADE,
    evidence_type             text NOT NULL CHECK (evidence_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','EXAMINATION_FINDING','CONTEXT','ABSENCE')),
    fact_definition_code      text REFERENCES clinical.fact_definition(code),
    phenotype_code            text REFERENCES knowledge.phenotype(phenotype_code),
    mechanism_code            text REFERENCES knowledge.mechanism(mechanism_code),
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code),
    context_code              text REFERENCES knowledge.clinical_context(code),
    relationship              text NOT NULL CHECK (relationship IN
        ('SUPPORTS','STRONGLY_SUPPORTS','WEAKLY_SUPPORTS','NEUTRAL',
         'WEAKLY_OPPOSES','OPPOSES','STRONGLY_OPPOSES','EXCLUDES','REQUIRES_CONFIRMATION')),
    base_strength             numeric(5,2) NOT NULL DEFAULT 1.00,   -- candidate+evidence strength (H8 §38)
    operator                  text CHECK (operator IN ('=', '!=', '>', '>=', '<', '<=', 'IN', 'BETWEEN', 'IS_TRUE', 'IS_FALSE')),
    value                     text,                                 -- value guard (e.g. COUGH_DURATION_DAYS < 21 SUPPORTS, > 56 OPPOSES)
    rationale                 text,
    evidence_claim_code       text REFERENCES knowledge.source_claim(claim_code),
    rule_version              integer NOT NULL DEFAULT 1,  -- §39: rule_version
    effective_from            date,
    status                    text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (diagnosis_code, evidence_type, fact_definition_code, phenotype_code,
            mechanism_code, result_interpretation_code, context_code, value)
);
COMMENT ON TABLE knowledge.differential_evidence_rule
    IS 'Versioned candidate+proposition → effect/strength rules (H8 §38/§39). Weights are never arbitrary; each links to a claim and a rule_version.';
CREATE INDEX IF NOT EXISTS idx_dif_evrule_dx ON knowledge.differential_evidence_rule(diagnosis_code);
DROP TRIGGER IF EXISTS trg_knowledge_diff_evrule_updated_at ON knowledge.differential_evidence_rule;
CREATE TRIGGER trg_knowledge_diff_evrule_updated_at
    BEFORE UPDATE ON knowledge.differential_evidence_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A14. reasoning_provenance — claim → reasoning knowledge edges
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.reasoning_provenance (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id         text NOT NULL REFERENCES knowledge.source_claim(claim_id),
    object_type      text NOT NULL,                       -- diagnosis_concept / expected_evidence / criterion / rule / ...
    object_id        uuid NOT NULL,
    object_code      text,
    relationship     text NOT NULL DEFAULT 'derived_from',
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (claim_id, object_type, object_id)
);
COMMENT ON TABLE knowledge.reasoning_provenance
    IS 'Provenance edges from Hutchison claims to H8 reasoning knowledge (H8 §45/§46).';
CREATE INDEX IF NOT EXISTS idx_reas_prov_claim ON knowledge.reasoning_provenance(claim_id);
CREATE INDEX IF NOT EXISTS idx_reas_prov_obj ON knowledge.reasoning_provenance(object_type, object_id);

-- ---------------------------------------------------------------------------
-- A15. reasoning_version — version registry (H8 §39/§40)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.reasoning_version (
    version_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    version_code      text NOT NULL UNIQUE,              -- RV2024.01.001
    ruleset_version   text NOT NULL,
    knowledge_version text NOT NULL,
    engine_version    text NOT NULL,
    effective_from    date,
    change_note       text,
    status            text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.reasoning_version
    IS 'Logical reasoning version (H8 §39/§40): what ruleset/knowledge/engine produced a given assessment.';
DROP TRIGGER IF EXISTS trg_knowledge_reasoning_version_updated_at ON knowledge.reasoning_version;
CREATE TRIGGER trg_knowledge_reasoning_version_updated_at
    BEFORE UPDATE ON knowledge.reasoning_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- B. RUNTIME LAYER (empty; the CPU fills these per reasoning run — H6/H7 precedent)
-- ---------------------------------------------------------------------------

-- B1. reasoning_run — one CPU evaluation pass (H8 §40)
CREATE TABLE IF NOT EXISTS knowledge.reasoning_run (
    run_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id        uuid,
    encounter_id      uuid,
    input_state_version text,
    ruleset_version   text,
    knowledge_version text,
    engine_version    text,
    started_at        timestamptz NOT NULL DEFAULT now(),
    completed_at      timestamptz,
    status            text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.reasoning_run
    IS 'A reasoning run (H8 §40) — what AMEXAN knew (versions) when it made an assessment.';
CREATE INDEX IF NOT EXISTS idx_reasoning_run_enc ON knowledge.reasoning_run(encounter_id);
CREATE INDEX IF NOT EXISTS idx_reasoning_run_pt  ON knowledge.reasoning_run(patient_id);

-- B2. differential_candidate — a diagnosis instance under consideration (§5)
CREATE TABLE IF NOT EXISTS knowledge.differential_candidate (
    candidate_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id            uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    diagnosis_code    text NOT NULL REFERENCES knowledge.diagnosis_concept(code),
    candidate_type    text NOT NULL CHECK (candidate_type IN
        ('PRIMARY_DIAGNOSIS','SECONDARY_DIAGNOSIS','COEXISTING_DIAGNOSIS','COMPLICATION',
         'COMORBIDITY','RISK_STATE','INCIDENTAL_FINDING','AETIOLOGY','SEVERITY_STATE')),
    prior_probability numeric(5,2) NOT NULL DEFAULT 0,    -- starting prior (§5)
    current_status    text NOT NULL DEFAULT 'CONSIDERED' REFERENCES knowledge.clinical_hypothesis_state(state_code),
    reasoning_level   text NOT NULL DEFAULT 'DISEASE' CHECK (reasoning_level IN
        ('SYNDROME','ORGAN_SYSTEM','MECHANISM','DISEASE','AETIOLOGY','COMPLICATION','SEVERITY')),
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_candidate
    IS 'A candidate explanation instance for one patient/run (H8 §5). Supports multiple simultaneous diagnoses at multiple levels (§44/§45).';
CREATE INDEX IF NOT EXISTS idx_diff_cand_run  ON knowledge.differential_candidate(run_id);
CREATE INDEX IF NOT EXISTS idx_diff_cand_dx   ON knowledge.differential_candidate(diagnosis_code);
CREATE INDEX IF NOT EXISTS idx_diff_cand_stat ON knowledge.differential_candidate(current_status);

-- B3. differential_score — computed support/against/uncertainty (§42)
CREATE TABLE IF NOT EXISTS knowledge.differential_score (
    score_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id      uuid NOT NULL REFERENCES knowledge.differential_candidate(candidate_id) ON DELETE CASCADE,
    run_id            uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    support           numeric(8,2) NOT NULL DEFAULT 0,
    against           numeric(8,2) NOT NULL DEFAULT 0,
    uncertainty       numeric(8,2) NOT NULL DEFAULT 0,
    rank_position     integer,
    scoring_version   text,
    computed_at       timestamptz NOT NULL DEFAULT now(),
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_score
    IS 'Computed support/against/uncertainty per candidate (H8 §42). The UI never calculates this; it renders it.';
CREATE INDEX IF NOT EXISTS idx_diff_score_cand ON knowledge.differential_score(candidate_id);
CREATE INDEX IF NOT EXISTS idx_diff_score_run  ON knowledge.differential_score(run_id);

-- B4. differential_evidence_ledger — the auditable evidence ledger (§7)
CREATE TABLE IF NOT EXISTS knowledge.differential_evidence_ledger (
    entry_id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id                uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    candidate_id          uuid NOT NULL REFERENCES knowledge.differential_candidate(candidate_id) ON DELETE CASCADE,
    diagnosis_code        text NOT NULL,
    proposal_type         text NOT NULL CHECK (proposal_type IN
        ('FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','EXAMINATION_FINDING','CONTEXT','ABSENCE')),
    proposal_code         text NOT NULL,                 -- fact/phenotype/mechanism/interpretation/context code
    fact_state            text REFERENCES knowledge.clinical_fact_state(state_code),   -- §10 four-state model
    relationship          text NOT NULL CHECK (relationship IN
        ('SUPPORTS','STRONGLY_SUPPORTS','WEAKLY_SUPPORTS','NEUTRAL',
         'WEAKLY_OPPOSES','OPPOSES','STRONGLY_OPPOSES','EXCLUDES','REQUIRES_CONFIRMATION')),
    direction_sign        text NOT NULL CHECK (direction_sign IN ('+','-','0')),
    strength              numeric(5,2) NOT NULL DEFAULT 1.00,
    evidence_rule_code    text,                           -- differential_evidence_rule that fired
    reasoning_rule_code   text,                           -- reasoning_rule that fired
    rule_version          text,
    quality_source        text,                           -- §12: patient_reported/measured/imaging_verified/...
    context_codes         text[] NOT NULL DEFAULT '{}',
    note                  text,
    created_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_evidence_ledger
    IS 'The patient-specific evidence ledger (H8 §7): every reasoning contribution as candidate+proposal+direction+strength+source+rule_version. The atomic unit of H8.';
CREATE INDEX IF NOT EXISTS idx_ledger_run  ON knowledge.differential_evidence_ledger(run_id);
CREATE INDEX IF NOT EXISTS idx_ledger_cand ON knowledge.differential_evidence_ledger(candidate_id);
CREATE INDEX IF NOT EXISTS idx_ledger_dx   ON knowledge.differential_evidence_ledger(diagnosis_code);

-- B5. clinical_hypothesis — working diagnosis/etiology/complications for a patient (§47)
CREATE TABLE IF NOT EXISTS knowledge.clinical_hypothesis (
    hypothesis_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id            uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    diagnosis_code    text NOT NULL REFERENCES knowledge.diagnosis_concept(code),
    role              text NOT NULL CHECK (role IN
        ('PRIMARY','SECONDARY','COEXISTING','COMPLICATION','COMORBIDITY','RISK_STATE','INCIDENTAL_FINDING')),
    status            text NOT NULL DEFAULT 'CONSIDERED' REFERENCES knowledge.clinical_hypothesis_state(state_code),
    certainty         text NOT NULL DEFAULT 'POSSIBLE' CHECK (certainty IN ('DEFINITE','PROBABLE','POSSIBLE','UNCERTAIN')),
    ranked_position   integer,
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.clinical_hypothesis
    IS 'The working clinical interpretation (H8 §47): leading hypothesis, alternatives, complications, severity. Supports multiple simultaneous problems (§44).';
CREATE INDEX IF NOT EXISTS idx_clin_hyp_run ON knowledge.clinical_hypothesis(run_id);
CREATE INDEX IF NOT EXISTS idx_clin_hyp_dx  ON knowledge.clinical_hypothesis(diagnosis_code);

-- B6. clinical_uncertainty (§28/§47)
CREATE TABLE IF NOT EXISTS knowledge.clinical_uncertainty (
    uncertainty_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id            uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    candidate_id      uuid NOT NULL REFERENCES knowledge.differential_candidate(candidate_id) ON DELETE CASCADE,
    dimension         text NOT NULL CHECK (dimension IN
        ('AETIOLOGY','SEVERITY','DIAGNOSIS','COMPLICATION','PROGNOSIS','CONFIRMATION')),
    level             text NOT NULL CHECK (level IN ('NONE','LOW','MODERATE','HIGH')),
    why_uncertain     text,
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.clinical_uncertainty
    IS 'Structured WHY (H8 §28): why considered/supported/opposed/not-confirmed, what is missing, what would change the ranking.';

-- B7. clinical_information_gap + question + investigation — H3⇄H8 and H7⇄H8 (§29/§30/§31)
CREATE TABLE IF NOT EXISTS knowledge.clinical_information_gap (
    gap_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id            uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    candidate_id      uuid NOT NULL REFERENCES knowledge.differential_candidate(candidate_id) ON DELETE CASCADE,
    gap_code          text NOT NULL,                     -- GAP..
    gap_type          text NOT NULL CHECK (gap_type IN
        ('QUESTION','INVESTIGATION','EXAMINATION','CONTEXT','TEMPORAL')),
    proposals         text[],                            -- fact/phenotype codes needed
    reason            text,
    priority          integer NOT NULL DEFAULT 0,
    status            text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','RESOLVED','CLOSED')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.clinical_information_gap
    IS 'WHAT IS MISSING (H8 §29/§30/§31). H8 emits gaps; H3/H7 resolve them; H8 re-ranks. That is the closed loop.';
CREATE INDEX IF NOT EXISTS idx_gap_run  ON knowledge.clinical_information_gap(run_id);
CREATE INDEX IF NOT EXISTS idx_gap_cand ON knowledge.clinical_information_gap(candidate_id);

CREATE TABLE IF NOT EXISTS knowledge.information_gap_question (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    gap_id          uuid NOT NULL REFERENCES knowledge.clinical_information_gap(gap_id) ON DELETE CASCADE,
    question_code   text NOT NULL,
    rationale       text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (gap_id, question_code)
);
COMMENT ON TABLE knowledge.information_gap_question
    IS 'Which H3 question resolves the gap (§29). The UI asks ONLY that question.';

CREATE TABLE IF NOT EXISTS knowledge.information_gap_investigation (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    gap_id                 uuid NOT NULL REFERENCES knowledge.clinical_information_gap(gap_id) ON DELETE CASCADE,
    investigation_code     text NOT NULL,                 -- H7 investigation concept code
    rationale              text,
    created_at             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (gap_id, investigation_code)
);
COMMENT ON TABLE knowledge.information_gap_investigation
    IS 'Which H7 investigation resolves the gap (§31).';

-- B8. reasoning_event — auditable CPU log (§41)
CREATE TABLE IF NOT EXISTS knowledge.reasoning_event (
    event_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id          uuid NOT NULL REFERENCES knowledge.reasoning_run(run_id) ON DELETE CASCADE,
    event_type      text NOT NULL CHECK (event_type IN
        ('FACT_ADDED','PHENOTYPE_ACTIVATED','MECHANISM_ACTIVATED','CANDIDATE_ADDED',
         'EVIDENCE_APPLIED','CANDIDATE_RERANKED','CANDIDATE_DEPRIORITIZED','CANDIDATE_EXCLUDED',
         'DIAGNOSIS_CONFIRMED','DIAGNOSIS_REJECTED','INFORMATION_GAP_CREATED',
         'QUESTION_TRIGGERED','INVESTIGATION_TRIGGERED')),
    object_type     text,
    object_code     text,
    detail          text,
    created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.reasoning_event
    IS 'Auditable reasoning event log (H8 §41). This is what makes AMEXAN a clinical operating system rather than a black box.';
CREATE INDEX IF NOT EXISTS idx_reas_event_run ON knowledge.reasoning_event(run_id);
CREATE INDEX IF NOT EXISTS idx_reas_event_type ON knowledge.reasoning_event(event_type);

-- ---------------------------------------------------------------------------
-- C. Provenance note — H8 reasoning objects join the same claim-grounded tree
-- ---------------------------------------------------------------------------
COMMENT ON TABLE knowledge.reasoning_provenance
    IS 'Claim → H8 reasoning knowledge edges. Every diagnosis concept, expected-evidence row, criterion, exclusion, rule and evidence-rule carries a derived_from edge to a Hutchison claim (migration 033 seed).';