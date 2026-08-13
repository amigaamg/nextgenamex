-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H5 migration 029: universal context engine
-- =============================================================================
-- H4 answered: "What CAN be explored about any symptom?"
-- H5 answers:    "Which VERSION of that exploration is appropriate for THIS
--               patient, at THIS encounter, in THIS context?"
--
-- Architectural law (unchanged):
--   PostgreSQL = KNOWLEDGE + CONFIGURATION   (everything below)
--   CPU        = DECISION / EXECUTION        (builds the context stack, applies
--                                            context rules, picks the wording
--                                            variant, emits an execution plan)
--   UI         = RENDERING                   (shows the plan the CPU chose)
--
-- Constitutional AMEXAN rule (H5 §44):
--   "Context may change how a fact is elicited, but NOT the identity of the
--    underlying canonical fact."
--   The same canonical fact (e.g. DYSPNOEA_FUNCTIONAL_IMPACT) may be captured
--   via four wordings + capture methods — but it is NEVER four different facts.
--
-- Spec → implementation mapping (H5 §45 core):
--   clinical_context            NEW  — knowledge.clinical_context (C001..C016)
--   developmental_stage         NEW  — knowledge.developmental_stage (9 stages)
--   historian_type              NEW  — knowledge.historian_type (7)
--   historian_reliability       NEW  — knowledge.historian_reliability (5)
--   communication_context       NEW  — knowledge.communication_context (factors)
--   encounter_mode              NEW  — knowledge.encounter_mode (5)
--   response_mode               NEW  — knowledge.response_mode (capture strategy)
--   response_variant            NEW  — knowledge.response_variant (age-appropriate scales/pickers)
--   context_rule                → knowledge.context_adaptation_rule
--                                  (SPEC §32 engine: context → target → modification.
--                                   Named differently because `knowledge.context_rule`
--                                   already exists as a rule↔context BINDING table
--                                   from migration 009 — a different concept: it
--                                   records which contexts a knowledge.rule applies
--                                   in, not what to DO in a context.)
--   context_fact_mapping        NEW  — knowledge.context_fact_mapping (raw→canonical, §23)
--   functional_domain           NEW  — knowledge.functional_domain (FD001..)
--   fact_capture_method         NEW  — knowledge.fact_capture_method (§10 provenance)
--   fact_provenance             NEW  — knowledge.fact_provenance (fact → capture method)
--   question_variant            UPGRADED — + response_mode + historian_type (§33)
--   question_context            EXISTS — patient context exclusions (reused, H5 §38)
--
-- Design law repeated from H2/H3: the adaptation rules are DATA. A clinician who
-- would argue "an infant should not be asked 'how many pack-years'" files a data
-- bug in knowledge.context_adaptation_rule, not a code change.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. clinical_context — the canonical registry of patient contexts (H5 §31)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.clinical_context (
    context_id        text PRIMARY KEY,              -- C001..
    code              text NOT NULL UNIQUE,          -- NEONATE / CHILD / ADULT ...
    category          text NOT NULL CHECK (category IN ('AGE','REPRODUCTIVE','SETTING','MODE','HISTORIAN','COMMUNICATION','COGNITION','ENCOUNTER_PURPOSE')),
    label             text NOT NULL,
    description       text,
    applies_to_questions boolean NOT NULL DEFAULT true,  -- does this context alter question wording/activation?
    applies_to_exam   boolean NOT NULL DEFAULT true,      -- does this context constrain H6 examination modalities?
    priority_weight   numeric(5,3) NOT NULL DEFAULT 1.0,  -- ContextApplicability factor (§34)
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.clinical_context
    IS 'Canonical patient contexts. A single patient may carry many simultaneously (§35); the CPU evaluates the whole context stack, not an IF-chain (§36).';
CREATE TRIGGER trg_knowledge_clinical_context_updated_at
    BEFORE UPDATE ON knowledge.clinical_context
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. developmental_stage — the 9 universal age bands (H5 §5)
-- ---------------------------------------------------------------------------
-- Age IS NOT just a number: 3 months ≠ 3 years ≠ 13 years. Boundaries live in
-- the database so protocols can override them (spec §5: "don't use these as
-- immutable medical truth"); the CPU resolves age_years/days → stage.
CREATE TABLE IF NOT EXISTS knowledge.developmental_stage (
    stage_code        text PRIMARY KEY,             -- NEONATE .. OLDER_ADULT
    label             text NOT NULL,
    min_age_days      numeric NOT NULL,             -- inclusive lower bound
    max_age_days      numeric,                     -- null = unbounded (OLDER_ADULT)
    sort_order        integer NOT NULL,
    description       text,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.developmental_stage
    IS 'The 9 universal developmental stages; the CPU derives the stage from the patient age, then uses it to pick question wording / capture method / relevance (H5 §4-5).';
CREATE TRIGGER trg_knowledge_developmental_stage_updated_at
    BEFORE UPDATE ON knowledge.developmental_stage
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. historian_type — who provides the history (H5 §8)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.historian_type (
    type_code         text PRIMARY KEY,             -- PATIENT / PARENT / CAREGIVER ...
    label             text NOT NULL,
    is_patient        boolean NOT NULL DEFAULT false,
    description       text,
    sort_order        integer NOT NULL,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_historian_type_updated_at
    BEFORE UPDATE ON knowledge.historian_type FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. historian_reliability — how much to trust the source (H5 §8)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.historian_reliability (
    reliability_code  text PRIMARY KEY,             -- GOOD / FAIR / POOR ...
    label             text NOT NULL,
    sort_order        integer NOT NULL,             -- lower = more reliable
    description       text,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_historian_reliability_updated_at
    BEFORE UPDATE ON knowledge.historian_reliability FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5. communication_context — interface-level communication constraints (H5 §13)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.communication_context (
    factor_code       text PRIMARY KEY,             -- LANGUAGE_BARRIER / HEARING_IMPAIRMENT ...
    context_type_code text REFERENCES knowledge.context_type(code),
    label             text NOT NULL,
    description       text,
    sort_order        integer NOT NULL,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_communication_context_updated_at
    BEFORE UPDATE ON knowledge.communication_context FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 6. encounter_mode — how care is delivered (H5 §29/30)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.encounter_mode (
    mode_code         text PRIMARY KEY,             -- IN_PERSON / VIDEO / AUDIO / CHAT / REMOTE_MONITORING
    label             text NOT NULL,
    supports_auscultation boolean NOT NULL DEFAULT true,
    supports_inspection  boolean NOT NULL DEFAULT true,
    supports_device_readings boolean NOT NULL DEFAULT true,
    description       text,
    sort_order        integer NOT NULL,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_encounter_mode_updated_at
    BEFORE UPDATE ON knowledge.encounter_mode FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 7. response_mode — the CAPTURE STRATEGY layer (H5 §7 Layer B)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.response_mode (
    mode_code         text PRIMARY KEY,             -- SELF_REPORT / CAREGIVER_REPORT / OBSERVATION ...
    label             text NOT NULL,
    is_patient_facing boolean NOT NULL DEFAULT true,
    description       text,
    sort_order        integer NOT NULL,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_response_mode_updated_at
    BEFORE UPDATE ON knowledge.response_mode FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 8. response_variant — age/appropriate picker for an answer interface (H5 §40/§45)
-- ---------------------------------------------------------------------------
-- Same canonical fact, different answer surface: a 0-10 numeric scale for adults,
-- a faces scale for young children, an observable checklist for infants.
CREATE TABLE IF NOT EXISTS knowledge.response_variant (
    variant_id        text PRIMARY KEY,             -- RV001..
    response_type     text NOT NULL,                -- e.g. numeric / single_choice / scale
    variant_name      text NOT NULL,                -- e.g. numeric_scale / faces_scale
    applicable_context_codes text[] NOT NULL,        -- which clinical_context codes this variant suits
    is_active         boolean NOT NULL DEFAULT true,
    description       text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.response_variant
    IS 'Contextual response surfaces (H5 §40). The canonical response_type is unchanged; only the picker the CPU hands to the UI varies by context.';

-- ---------------------------------------------------------------------------
-- 9. functional_domain — developmental + adult functional domains (H5 §24)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.functional_domain (
    domain_code       text PRIMARY KEY,             -- FD001..
    code              text NOT NULL UNIQUE,         -- FEEDING / SPEECH / MOBILITY ...
    label             text NOT NULL,
    category          text NOT NULL CHECK (category IN ('developmental','adult','geriatric')),
    age_relevance     text,                         -- which life stage this matters most
    description       text,
    sort_order        integer NOT NULL,
    status            text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','draft','retired')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_functional_domain_updated_at
    BEFORE UPDATE ON knowledge.functional_domain FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 10. context_adaptation_rule — THE H5 RULE ENGINE (H5 §32)
-- ---------------------------------------------------------------------------
-- Spec §32 calls this table `context_rule`, but `knowledge.context_rule` already
-- exists (migration 009) as a rule↔context BINDING table. They are different
-- concepts, so this engine table is named `context_adaptation_rule` and is the
-- thing the CPU executes: "given CONTEXT, do MODIFICATION to TARGET."
--   context_code      → a clinical_context.code (NEONATE, UNCONSCIOUS, ...)
--   target_type       → what the rule adapts: question / question_module /
--                       symptom / fact_definition / functional_domain / examination_modality
--   modification      → ACTIVATE (priority boost) / UNAVAILABLE (cannot capture)
--                       / DISABLE (suppress entirely / wrong capture method)
--   priority_delta    → H5 priority modifier (§34): BasePriority × ContextApplicability
--                       The CPU subtracts this (lower score = asked sooner), mirroring
--                       H3 question_rule.priority_delta semantics.
CREATE TABLE IF NOT EXISTS knowledge.context_adaptation_rule (
    rule_code          text PRIMARY KEY,             -- CR001..
    context_code       text NOT NULL REFERENCES knowledge.clinical_context(code),
    target_type        text NOT NULL CHECK (target_type IN ('question','question_module','symptom','fact_definition','functional_domain','examination_modality')),
    target_code        text NOT NULL,
    modification       text NOT NULL CHECK (modification IN ('ACTIVATE','UNAVAILABLE','DISABLE')),
    priority_delta     integer NOT NULL DEFAULT 0,
    required_historian text REFERENCES knowledge.historian_type(type_code),  -- capture-method override
    rationale          text,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    condition          jsonb,                       -- optional extra guard (§37 conflict resolution)
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    version            integer NOT NULL DEFAULT 1,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (context_code, target_type, target_code, modification)
);
COMMENT ON TABLE knowledge.context_adaptation_rule
    IS 'The H5 context engine (spec §32, named to avoid collision with the existing knowledge.context_rule binding table). Fires on a context stack and ACTIVATEs/UNAVAILABLEs/DISABLEs a target to adapt the H3 question list and H6 examination to THIS patient.';
CREATE INDEX idx_context_adaptation_rule_context ON knowledge.context_adaptation_rule(context_code);
CREATE INDEX idx_context_adaptation_rule_target  ON knowledge.context_adaptation_rule(target_type, target_code);
CREATE TRIGGER trg_knowledge_context_adaptation_rule_updated_at
    BEFORE UPDATE ON knowledge.context_adaptation_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 11. context_fact_mapping — raw expression → canonical fact (H5 §23/22)
-- ---------------------------------------------------------------------------
-- The paediatric translation layer: a caregiver says "he stops playing after
-- running" → canonical fact EXERCISE_TOLERANCE = reduced. Maps lay/observed
-- expressions into the universal fact vocabulary.
CREATE TABLE IF NOT EXISTS knowledge.context_fact_mapping (
    mapping_code       text PRIMARY KEY,             -- CFM001..
    context_code       text NOT NULL REFERENCES knowledge.clinical_context(code),
    raw_expression     text NOT NULL,                -- what is actually reported ("stops playing")
    target_type        text NOT NULL CHECK (target_type IN ('fact_definition','functional_domain')),
    target_code        text NOT NULL,                -- the canonical fact / functional domain
    canonical_value    text,                         -- the value it maps to ("reduced")
    strength           text NOT NULL DEFAULT 'strong' CHECK (strength IN ('strong','moderate','weak')),
    description        text,
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (context_code, raw_expression, target_code)
);
COMMENT ON TABLE knowledge.context_fact_mapping
    IS 'Semantic normalization (H5 §22-23). A lay/observed expression in a context maps onto the universal fact, never creating a parallel fact.';
CREATE INDEX idx_context_fact_mapping_target ON knowledge.context_fact_mapping(target_type, target_code);

-- ---------------------------------------------------------------------------
-- 12. fact_capture_method — provenance of how a fact entered the record (H5 §10)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.fact_capture_method (
    method_code        text PRIMARY KEY,             -- PATIENT_REPORTED / CAREGIVER_REPORTED ...
    label              text NOT NULL,
    is_patient_source  boolean NOT NULL DEFAULT true,
    description        text,
    sort_order         integer NOT NULL,
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_knowledge_fact_capture_method_updated_at
    BEFORE UPDATE ON knowledge.fact_capture_method FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 13. fact_provenance — which capture methods are lawful for a fact (H5 §10/13)
-- ---------------------------------------------------------------------------
-- E.g. SMOKING_PACK_YEARS may be PATIENT_REPORTED / CAREGIVER_REPORTED / RECORD_DERIVED;
-- never DEVICE_MEASURED. Lets the CPU validate that a fact can actually be
-- obtained in the current encounter mode.
CREATE TABLE IF NOT EXISTS knowledge.fact_provenance (
    fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code) ON DELETE CASCADE,
    capture_method_code  text NOT NULL REFERENCES knowledge.fact_capture_method(method_code),
    historian_type_code  text REFERENCES knowledge.historian_type(type_code),  -- NULL = any
    min_reliability_code text REFERENCES knowledge.historian_reliability(reliability_code),
    is_valid             boolean NOT NULL DEFAULT true,
    evidence_claim_code  text REFERENCES knowledge.source_claim(claim_code),
    PRIMARY KEY (fact_definition_code, capture_method_code, historian_type_code, min_reliability_code)
);
COMMENT ON TABLE knowledge.fact_provenance
    IS 'Governance of fact provenance (H5 §10). Declares which capture methods/historians/reliabilities may lawfully yield each canonical fact, so the CPU knows a fact is obtainable in the current context (§37).';

-- ---------------------------------------------------------------------------
-- 14. Link questions to a functional domain they can assess (H5 §24/42)
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS functional_domain_code text REFERENCES knowledge.functional_domain(code);
DROP INDEX IF EXISTS idx_question_functional_domain;
CREATE INDEX IF NOT EXISTS idx_question_func_domain ON knowledge.question(functional_domain_code) WHERE functional_domain_code IS NOT NULL;
COMMENT ON COLUMN knowledge.question.functional_domain_code
    IS 'FK knowledge.functional_domain — which functional domain this question assesses (H5 §24). NULL = not a functional question.';

-- ---------------------------------------------------------------------------
-- 15. Extend question_variant with response_mode + historian (H5 §33)
-- ---------------------------------------------------------------------------
-- The universal H3 question keeps ONE identity; H5 adds a capture-strategy and
-- historian to each wording variant so the CPU can pick both the wording AND
-- the capture method together.
ALTER TABLE knowledge.question_variant
    ADD COLUMN IF NOT EXISTS response_mode  text REFERENCES knowledge.response_mode(mode_code),
    ADD COLUMN IF NOT EXISTS historian_type text REFERENCES knowledge.historian_type(type_code),
    ADD COLUMN IF NOT EXISTS priority_delta integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_disabled    boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN knowledge.question_variant.response_mode
    IS 'H5 capture-strategy layer (§7 Layer B): SELF_REPORT / CAREGIVER_REPORT / OBSERVATION / ...';
COMMENT ON COLUMN knowledge.question_variant.historian_type
    IS 'H5 historian who supplies this variant (§8): PATIENT / PARENT / CAREGIVER / ...';
COMMENT ON COLUMN knowledge.question_variant.is_disabled
    IS 'H5 DISABLE gate (§32/37): this wording is inappropriate for its context (e.g. a self-report wording for an unconscious patient).';

-- ---------------------------------------------------------------------------
-- 16. provenance note — H5 objects derive from H1/H4 claims
-- ---------------------------------------------------------------------------
COMMENT ON TABLE knowledge.provenance
    IS 'Derivation edges from source claims to compiled AMEXAN objects (H1 claims → H2 history concepts, H3 questions/rules, H4 dimensions/red-flags, H5 contexts/variants/adaptation rules).';

