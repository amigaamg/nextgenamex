-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H8 migration 032: universal differential-reasoning interface
-- =============================================================================
-- H7 answered: "WHAT investigation do we need, WHY, in WHAT order?"
-- H8 answers:  "WHAT does ALL the collected information collectively MEAN?"
--              "WHICH hypotheses are supported, by WHICH evidence, and WHY?"
--
-- Architectural law (H8): differential reasoning is NOT a giant
-- disease→symptom lookup table. It is a UNIVERSAL REASONING INTERFACE:
--
--   CLINICAL DATABASE (history H2/H3/H4 + exam H6 + results H7)
--        ↓
--   NORMALIZED FACTS / PHENOTYPES / MECHANISMS
--        ↓
--   HYPOTHESES (candidate explanations, each tied to a concept)
--        ↓
--   EVIDENCE (each fact/phenotype/mechanism/result SUPPORTS or REFUTES)
--        ↓
--   WEIGHTED RANKING (evidence strength × hypothesis weight × context)
--        ↓
--   EXPLANATION (WHY this hypothesis ranks here)
--
-- H8 §1/§2 constitutional boundary (mirrors H7 §47):
--   H7 = WHAT INFORMATION DO WE NEED?
--   H8 = WHAT DOES ALL THE INFORMATION COLLECTIVELY MEAN?
--
-- The MOST IMPORTANT separation (H8): HYPOTHESIS ≠ EVIDENCE ≠ WEIGHT ≠ RANK.
--   HYPOTHESIS = a candidate explanation (a concept: condition/mechanism)
--   EVIDENCE   = a fact, phenotype, mechanism or result interpretation that
--                bears on a hypothesis (SUPPORTS / REFUTES)
--   WEIGHT     = versioned numeric model of how strongly evidence counts
--   RANK       = computed output (hypothesis ordering), never stored as truth
--   EXPLANATION= auditable reason object (H8 §45/§46)
--
-- Two-step diagnosis is the Hutchison core (HCH1-0002):
--   step 1: establish the clinical features (the clinical database);
--   step 2: interpret that database in terms of disordered function and
--           potential causative pathologies. H8 IS step 2.
--
-- Box 2.3 pathological-process framework (HCH2-0005) is the skeleton of the
-- differential: Congenital, Degenerative, Infective/inflammatory, Metabolic,
-- Neoplastic, Nutritional, Toxic, Traumatic, Vascular.
--
-- Spec → implementation mapping:
--   differential_hypothesis          NEW  — knowledge.differential_hypothesis (a candidate explanation)
--   differential_evidence            NEW  — knowledge.differential_evidence (SUPPORTS/REFUTES, weighted)
--   differential_rule                NEW  — knowledge.differential_rule (data-driven evidence→hypothesis activation)
--   differential_rule_condition      NEW  — knowledge.differential_rule_condition (value guards)
--   differential_weight              NEW  — knowledge.differential_weight (versioned multi-dimension model)
--   differential_reason              NEW  — knowledge.differential_reason (RUNTIME explanation object, not seeded)
--   differential_rank                NEW  — knowledge.differential_rank (RUNTIME computed ordering, not seeded)
--   differential_source              NEW  — knowledge.differential_source (provenance → Hutchison)
--   differential_version             NEW  — knowledge.differential_version (temporal versioning)
--   differential_status              NEW  — knowledge.differential_status (reasoning lifecycle)
--
-- H8 consumes the objects built by earlier layers:
--   clinical.fact_definition         (normalized facts)
--   knowledge.phenotype              (H1/H4 phenotype objects)
--   knowledge.mechanism              (H1/H4 mechanism objects)
--   knowledge.result_interpretation  (H7 result findings)
--   knowledge.result_phenotype_link  (H7 interpretation → concept bridge)
--   knowledge.phenotype_differential (existing static knowledge link)
--   knowledge.condition_differential (existing static knowledge link)
--   knowledge.question_differential_weight (existing static knowledge link)
--
-- Runtime tables (differential_reason, differential_rank) are created-but-EMPTY
-- per the established H6/H7 precedent: the CPU populates them at reasoning time
-- from the knowledge tables above. Rows below are engine output.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. differential_hypothesis — a candidate explanation under consideration (H8)
--    A hypothesis is a CONCEPT (condition or mechanism), never a raw symptom.
--    base_weight is H8 §21-style urgency/priori signal (higher = more plausible
--    starting prior); the actual score is computed from evidence, not stored.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_hypothesis (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hypothesis_code       text NOT NULL UNIQUE,             -- DH001..
    concept_id            uuid REFERENCES knowledge.concept(id),   -- the explanation (condition/mechanism)
    concept_code          text,                             -- denormalized concept_code for joinability
    hypothesis_type       text NOT NULL CHECK (hypothesis_type IN ('CONDITION','MECHANISM','FUNCTIONAL','TOXIC','TRAUMATIC')),
    canonical_name        text NOT NULL,
    short_label           text,
    description           text,
    body_system_code      text REFERENCES knowledge.body_system(code),
    pathological_process  text,                             -- HCH2-0005 Box 2.3 (CONGENITAL/DEGENERATIVE/INFECTIVE_INFLAMMATORY/METABOLIC/NEOPLASTIC/NUTRITIONAL/TOXIC/TRAUMATIC/VASCULAR)
    base_weight           numeric(5,2) NOT NULL DEFAULT 0,  -- starting prior (H8 §21), evidence drives the final score
    is_critical           boolean NOT NULL DEFAULT false,   -- must-not-miss hypothesis (safety)
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_hypothesis
    IS 'A candidate explanation (hypothesis) under differential consideration (H8). Always tied to a concept (condition/mechanism); never a raw symptom. base_weight is the starting prior; the final rank is evidence-derived.';
CREATE INDEX IF NOT EXISTS idx_diff_hyp_concept ON knowledge.differential_hypothesis(concept_id);
CREATE INDEX IF NOT EXISTS idx_diff_hyp_type   ON knowledge.differential_hypothesis(hypothesis_type);
CREATE INDEX IF NOT EXISTS idx_diff_hyp_system ON knowledge.differential_hypothesis(body_system_code);
DROP TRIGGER IF EXISTS trg_knowledge_differential_hypothesis_updated_at ON knowledge.differential_hypothesis;
CREATE TRIGGER trg_knowledge_differential_hypothesis_updated_at
    BEFORE UPDATE ON knowledge.differential_hypothesis FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. differential_evidence — a fact/phenotype/mechanism/result bearing on a hypothesis
--    SUPPORTS or REFUTES; carries a weight and an evidence claim (H8 §5/§6/§7/§20).
--    The evidence is the OBJECT; the weight is DATA; the rank is COMPUTED.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_evidence (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_code          text NOT NULL,                   -- DEV001..
    hypothesis_code        text NOT NULL REFERENCES knowledge.differential_hypothesis(hypothesis_code) ON DELETE CASCADE,
    evidence_type          text NOT NULL CHECK (evidence_type IN
        ('FACT','SYMPTOM','EXAMINATION_FINDING','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','CONTEXT','RISK_FACTOR','EXPOSURE')),
    fact_definition_code   text REFERENCES clinical.fact_definition(code),      -- when FACT/SYMPTOM/EXAMINATION_FINDING
    phenotype_code         text REFERENCES knowledge.phenotype(phenotype_code), -- when PHENOTYPE
    mechanism_code         text REFERENCES knowledge.mechanism(mechanism_code), -- when MECHANISM
    result_interpretation_code text REFERENCES knowledge.result_interpretation(code), -- when RESULT_INTERPRETATION
    context_code           text REFERENCES knowledge.clinical_context(code),    -- when CONTEXT
    direction              text NOT NULL CHECK (direction IN ('SUPPORTS','REFUTES')),
    weight                 numeric(5,2) NOT NULL DEFAULT 1.00,   -- strength of this piece of evidence
    certainty              text NOT NULL DEFAULT 'DEFINITE' CHECK (certainty IN ('DEFINITE','PROBABLE','POSSIBLE')),
    description            text,
    evidence_claim_code    text REFERENCES knowledge.source_claim(claim_code),
    is_active              boolean NOT NULL DEFAULT true,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hypothesis_code, evidence_code)
);
COMMENT ON TABLE knowledge.differential_evidence
    IS 'One piece of evidence and its direction (SUPPORTS/REFUTES) and weight on a differential hypothesis (H8). The weight is data; the final rank is computed from these rows.';
CREATE INDEX IF NOT EXISTS idx_diff_ev_hyp   ON knowledge.differential_evidence(hypothesis_code);
CREATE INDEX IF NOT EXISTS idx_diff_ev_fact  ON knowledge.differential_evidence(fact_definition_code);
CREATE INDEX IF NOT EXISTS idx_diff_ev_ph    ON knowledge.differential_evidence(phenotype_code);
CREATE INDEX IF NOT EXISTS idx_diff_ev_mech  ON knowledge.differential_evidence(mechanism_code);
DROP TRIGGER IF EXISTS trg_knowledge_differential_evidence_updated_at ON knowledge.differential_evidence;
CREATE TRIGGER trg_knowledge_differential_evidence_updated_at
    BEFORE UPDATE ON knowledge.differential_evidence FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. differential_rule — data-driven evidence→hypothesis activation (H8 §11)
--    Given a TRIGGER (fact/phenotype/mechanism/result/context or ALWAYS),
--    do a MODIFICATION to a TARGET hypothesis. Mirrors H6 examination_rule and
--    H7 investigation_rule — rules are DATA, never if-chains in CPU code.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_rule (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code              text NOT NULL UNIQUE,            -- DR001..
    trigger_type           text NOT NULL CHECK (trigger_type IN ('ALWAYS','FACT','PHENOTYPE','MECHANISM','RESULT_INTERPRETATION','CONTEXT')),
    trigger_code           text,                             -- fact_definition / phenotype / mechanism / result_interpretation / context code (NULL for ALWAYS)
    target_hypothesis_code text NOT NULL REFERENCES knowledge.differential_hypothesis(hypothesis_code),
    modification           text NOT NULL CHECK (modification IN ('ACTIVATE','ELEVATE','SUPPRESS','EXCLUDE','MARK_CRITICAL','CONDITIONAL')),
    weight_delta           numeric(5,2) NOT NULL DEFAULT 0, -- change to the hypothesis score when the trigger is present
    rationale              text,
    evidence_claim_code    text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active              boolean NOT NULL DEFAULT true,
    status                 text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),
    UNIQUE (trigger_type, trigger_code, target_hypothesis_code, modification)
);
COMMENT ON TABLE knowledge.differential_rule
    IS 'Data-driven activation/weighting of differential hypotheses (H8). Urgency, contraindications, dependencies and conditional activation are rules, not code.';
CREATE INDEX IF NOT EXISTS idx_diff_rule_target  ON knowledge.differential_rule(target_hypothesis_code);
CREATE INDEX IF NOT EXISTS idx_diff_rule_trigger ON knowledge.differential_rule(trigger_type, trigger_code);
DROP TRIGGER IF EXISTS trg_knowledge_differential_rule_updated_at ON knowledge.differential_rule;
CREATE TRIGGER trg_knowledge_differential_rule_updated_at
    BEFORE UPDATE ON knowledge.differential_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. differential_rule_condition — extra value-guards on a differential rule
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_rule_condition (
    condition_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code             text NOT NULL REFERENCES knowledge.differential_rule(rule_code) ON DELETE CASCADE,
    condition_code        text NOT NULL,                    -- DRC001..
    fact_definition_code  text NOT NULL REFERENCES clinical.fact_definition(code),
    operator              text NOT NULL CHECK (operator IN ('=', '!=', '>', '>=', '<', '<=', 'IN', 'BETWEEN', 'IS_TRUE', 'IS_FALSE')),
    value                 text,
    rationale             text,
    is_active             boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rule_code, condition_code)
);
COMMENT ON TABLE knowledge.differential_rule_condition
    IS 'Optional value-guards on a differential rule (H8). The CPU evaluates these against the captured clinical facts before applying the rule.';
CREATE INDEX IF NOT EXISTS idx_diff_rule_cond_rule ON knowledge.differential_rule_condition(rule_code);

-- ---------------------------------------------------------------------------
-- 5. differential_weight — the H8 §21 multi-dimension evidence-weighting model
--    Versioned DATA. The CPU computes:
--      score(h) = base_weight + Σ(dimension_weight × factor)
--                 + Σ(rule weight_delta) + Σ(evidence weight)
--    The dimension registry is the tunable, auditable recipe.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_weight (
    weight_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    weight_code          text NOT NULL UNIQUE,              -- DWT001..
    dimension            text NOT NULL UNIQUE CHECK (dimension IN
        ('EVIDENCE_STRENGTH','HARD_SYMPTOM','MECHANISM_PLAUSIBILITY','TEMPORAL_FIT',
         'SEVERITY_FIT','RED_FLAG','CONTEXT_FIT','EXCLUSION_POWER','REFUTATION_PENALTY',
         'PREVALENCE_PRIOR')),
    direction            text NOT NULL DEFAULT 'POSITIVE' CHECK (direction IN ('POSITIVE','NEGATIVE')),
    weight               numeric(4,2) NOT NULL DEFAULT 1.00,
    description          text,
    version              integer NOT NULL DEFAULT 1,
    effective_from       date,
    status               text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_weight
    IS 'Versioned multi-dimension evidence-weighting model (H8 §21). Dimensions are data so the scoring recipe is tunable and auditable.';
DROP TRIGGER IF EXISTS trg_knowledge_differential_weight_updated_at ON knowledge.differential_weight;
CREATE TRIGGER trg_knowledge_differential_weight_updated_at
    BEFORE UPDATE ON knowledge.differential_weight FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 6. differential_source — provenance of differential knowledge (H8 §31/§45)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_source (
    source_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hypothesis_code       text NOT NULL REFERENCES knowledge.differential_hypothesis(hypothesis_code) ON DELETE CASCADE,
    source_version_id     text NOT NULL REFERENCES knowledge.source_version(version_id),
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
    status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hypothesis_code, source_version_id)
);
COMMENT ON TABLE knowledge.differential_source
    IS 'Source provenance for differential-reasoning knowledge (H8). Every hypothesis records the authoritative source (Hutchison) that grounds it.';
CREATE INDEX IF NOT EXISTS idx_diff_source_hyp ON knowledge.differential_source(hypothesis_code);
DROP TRIGGER IF EXISTS trg_knowledge_differential_source_updated_at ON knowledge.differential_source;
CREATE TRIGGER trg_knowledge_differential_source_updated_at
    BEFORE UPDATE ON knowledge.differential_source FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 7. differential_version — temporal versioning of differential knowledge (H8)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_version (
    version_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hypothesis_code       text NOT NULL REFERENCES knowledge.differential_hypothesis(hypothesis_code) ON DELETE CASCADE,
    version_no            integer NOT NULL,
    effective_from        date,
    effective_to          date,
    supersedes            uuid REFERENCES knowledge.differential_version(version_id),
    change_note           text,
    status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (hypothesis_code, version_no)
);
COMMENT ON TABLE knowledge.differential_version
    IS 'Version history of a differential hypothesis (H8). Supports temporal validity of differential reasoning as guidelines change.';
CREATE INDEX IF NOT EXISTS idx_diff_version_hyp ON knowledge.differential_version(hypothesis_code);
DROP TRIGGER IF EXISTS trg_knowledge_differential_version_updated_at ON knowledge.differential_version;
CREATE TRIGGER trg_knowledge_differential_version_updated_at
    BEFORE UPDATE ON knowledge.differential_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 8. differential_status — reasoning lifecycle (H8)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.differential_status (
    status_code   text PRIMARY KEY,                         -- PENDING / ACTIVE / REFINED / RESOLVED / DROPPED / CONFIRMED / ENTERED_IN_ERROR
    label         text NOT NULL,
    description   text,
    sort_order    integer NOT NULL,
    is_terminal   boolean NOT NULL DEFAULT false,
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired'))
);
COMMENT ON TABLE knowledge.differential_status
    IS 'Operational lifecycle states of a differential hypothesis during reasoning (H8).';
CREATE INDEX IF NOT EXISTS idx_diff_status_sort ON knowledge.differential_status(sort_order);

-- ---------------------------------------------------------------------------
-- 9–10. Runtime tables (H8) — created, NOT seeded (per H6/H7 precedent)
-- The CPU writes differential_rank (computed ordering) and differential_reason
-- (the auditable explanation object, H8 §45/§46) at reasoning time.
-- ---------------------------------------------------------------------------

-- 9. differential_rank — computed hypothesis ordering for one encounter (H8 §21/§22)
CREATE TABLE IF NOT EXISTS knowledge.differential_rank (
    rank_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id      uuid NOT NULL,                        -- clinical.encounter
    patient_id        uuid,
    context_stack     jsonb,                                -- H5 context codes active for this reasoning pass
    hypothesis_code   text NOT NULL REFERENCES knowledge.differential_hypothesis(hypothesis_code),
    score             numeric(8,2) NOT NULL DEFAULT 0,      -- computed score (H8 §21 formula)
    rank              integer NOT NULL,                     -- 1 = most supported
    status_code       text NOT NULL DEFAULT 'ACTIVE' REFERENCES knowledge.differential_status(status_code),
    computed_at       timestamptz NOT NULL DEFAULT now(),
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_rank
    IS 'Computed differential ordering for one encounter (H8 §21/§22). Runtime output: score = base_weight + Σ(weights) + Σ(rule deltas); rank = ordering. NEVER treated as ground truth.';
CREATE INDEX IF NOT EXISTS idx_diff_rank_encounter ON knowledge.differential_rank(encounter_id);
CREATE INDEX IF NOT EXISTS idx_diff_rank_hyp      ON knowledge.differential_rank(hypothesis_code);
CREATE INDEX IF NOT EXISTS idx_diff_rank_status   ON knowledge.differential_rank(status_code);

-- 10. differential_reason — the auditable explanation object (H8 §45/§46)
CREATE TABLE IF NOT EXISTS knowledge.differential_reason (
    reason_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rank_id           uuid NOT NULL REFERENCES knowledge.differential_rank(rank_id) ON DELETE CASCADE,
    hypothesis_code   text NOT NULL REFERENCES knowledge.differential_hypothesis(hypothesis_code),
    rule_codes        text[],                               -- differential rules that fired
    triggering_facts  text[],                               -- fact_definition codes that contributed
    triggering_phenotypes text[],                           -- phenotype codes that contributed
    relevant_mechanisms   text[],                           -- mechanism codes that contributed
    evidence_codes    text[],                               -- differential_evidence codes applied
    weight_contribution numeric(8,2) NOT NULL DEFAULT 0,    -- how much evidence added
    explanation       text,                                 -- human-readable "because..." (H8 §46)
    created_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.differential_reason
    IS 'Auditable explanation for a hypothesis rank (H8 §45/§46): which evidence, which rules, which phenotypes/mechanisms, and how much weight each contributed. This is what makes AMEXAN a clinical operating system rather than a black box.';
CREATE INDEX IF NOT EXISTS idx_diff_reason_rank ON knowledge.differential_reason(rank_id);
CREATE INDEX IF NOT EXISTS idx_diff_reason_hyp  ON knowledge.differential_reason(hypothesis_code);

-- ---------------------------------------------------------------------------
-- 11. Provenance note — H8 objects derive from source claims
-- ---------------------------------------------------------------------------
COMMENT ON TABLE knowledge.provenance
    IS 'Derivation edges from source claims to compiled AMEXAN objects (H1..H6 as before, H7 investigation concepts/components/rules/reference-standards/interpretations/phenotype-links, H8 differential hypotheses/evidence/rules/weights).';