-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H6 migration 030: universal physical examination engine
-- =============================================================================
-- H5 answered: "Which VERSION of that exploration is appropriate for THIS patient?"
-- H6 answers:    "WHAT do we EXAMINE on this patient, in WHAT ORDER, with WHAT
--               methods, and HOW do we record each finding as a canonical fact?"
--
-- Architectural law (H6 §46): the examination is DATA. There is no "respiratory
-- protocol" or "cardiac protocol" engine — only examination_concepts, their
-- priority/safety rules, their reference standards, and the interpretation table
-- loaded into the universal machine. Priorities are data in examination_rule,
-- not if-chains in CPU code.
--
-- Constitutional AMEXAN rule (H6 §44):
--   "Examination NEVER invents a new fact. EVERY physical finding maps to ONE
--    canonical fact (fact_definition). A murmur is not a 'murmur fact';
--    it is the finding of the CANONICAL fact CARDIAC_FREMITUS expressed via
--    the observation_concept murmur, captured by auscultation."
--   ONE observation_concept = ONE canonical fact. ONE observation = ONE canonical
--   fact-value pair. New signs are new fact_definitions, never parallel vocabularies.
--
-- Spec → implementation mapping (H6 §32 core, spec §32/33/38):
--   examination_domain            NEW  — knowledge.examination_domain (DOM01..)
--   examination_concept           NEW  — knowledge.examination_concept (EX001.. = universal exam bundles)
--   observation_concept           NEW  — knowledge.observation_concept (OC001.. = one per canonical fact)
--   examination_component         NEW  — knowledge.examination_component (EX001 → {OCxxx})
--   examination_technique         NEW  — knowledge.examination_technique (INSPECTION/PALPATION/PERCussion/AUSCULTATION)
--   examination_site              NEW  — knowledge.examination_site (anatomical surface)
--   examination_position          NEW  — knowledge.examination_position (SUPINE/SITTING/LEFT_LATERAL...)
--   examination_rule              NEW  — knowledge.examination_rule (priority/safety, H6 §8/§32)
--   reference_standard            NEW  — knowledge.reference_standard (normal ranges by context, H6 §9)
--   finding_interpretation        NEW  — knowledge.finding_interpretation (NORMAL/ABNORMAL/PRESENT/ABSENT/...)
--   finding_phenotype_link        NEW  — knowledge.finding_phenotype_link (sign+interpretation → concept, H6 §44)
--   observation                   NEW  — knowledge.observation (the fact table, RUNTIME output — H6 §45)
--   observation_component         NEW  — knowledge.observation_component (composite findings, RUNTIME)
--   examination_plan              NEW  — knowledge.examination_plan (CPU runtime plan — H6 §45, not seeded)
--   examination_plan_item         NEW  — knowledge.examination_plan_item (CPU runtime plan lines — H6 §45)
--   examination_execution         NEW  — knowledge.examination_execution (CPU runtime execution log)
--   examination_technique        NEW  — knowledge.examination_technique (the Four Techniques; note: migration
--                                   014 models coarse methods as examination_module concept rows, NOT a
--                                   separate examination_modality table — that table was never created,
--                                   so H6 technique stands alone as the fine-grained technique layer.)
--
-- Context coupling (H6 §31): every examination_concept/examination_rule/reference_standard
-- carries `applies_to_context_codes` so the H5 context engine can gate the exam the
-- SAME way it gates questions (a neonate, an unconscious patient, or a televisit
-- all restrict which exams/modality/value-sets are lawful).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. examination_domain — the 9 universal examination domains (H6 §33)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_domain (
    domain_code  text PRIMARY KEY,              -- DOM01..
    code         text NOT NULL UNIQUE,         -- GENERAL / VITAL_SIGNS / HEAD_NECK ...
    body_system_code text NOT NULL REFERENCES knowledge.body_system(code),
    label        text NOT NULL,
    description  text,
    sort_order   integer NOT NULL,
    is_mandatory boolean NOT NULL DEFAULT false,  -- must appear in every complete exam (e.g. general, vitals)
    status       text NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active','draft','retired')),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_domain
    IS 'Universal examination domains. A domain spans one body_system (or GENERAL/CONSTITUTIONAL for the whole-person exam).';
CREATE INDEX IF NOT EXISTS idx_exam_domain_system ON knowledge.examination_domain(body_system_code);
CREATE INDEX IF NOT EXISTS idx_exam_domain_sort   ON knowledge.examination_domain(sort_order);
DROP TRIGGER IF EXISTS trg_knowledge_examination_domain_updated_at ON knowledge.examination_domain;
CREATE TRIGGER trg_knowledge_examination_domain_updated_at
    BEFORE UPDATE ON knowledge.examination_domain
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. examination_concept — universal exam bundles (H6 §33, EX001..EX009)
-- Each concept is a structured physical examination of one domain, grounded in
-- Hutchison. It bundles the observation_concepts (canonical facts) it yields and
-- carries the base priority (H6 §8) the CPU schedules from before context deltas.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_concept (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code               text NOT NULL UNIQUE,           -- EX001..
    domain_code        text NOT NULL REFERENCES knowledge.examination_domain(domain_code),
    concept_id         uuid REFERENCES knowledge.concept(id),            -- optional canonical concept
    fact_definition_code text REFERENCES clinical.fact_definition(code), -- the single canonical fact IF one-per-concept (vitals)
    name               text NOT NULL,
    short_label        text,                           -- e.g. "Look, feel, listen"
    description        text,
    body_system_code   text NOT NULL REFERENCES knowledge.body_system(code),
    is_mandatory       boolean NOT NULL DEFAULT false, -- captured every encounter
    base_priority      integer NOT NULL DEFAULT 100,   -- H6 §8 absolute urgency (higher = sooner; safety-critical=1000)
    technique_codes    text[] NOT NULL DEFAULT '{}',   -- which modalities the concept uses (INSPECTION/PALPATION/PERCussion/AUSCULTATION)
    capture_method_codes text[] NOT NULL DEFAULT '{}', -- lawful capture methods (DEVICE_MEASURED/CLINICIAN_OBSERVED/OBSERVATION)
    applies_to_context_codes text[] NOT NULL DEFAULT '{}', -- age/setting contexts that make this concept lawful (H5 context coupling)
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_concept
    IS 'Universal physical-examination concepts (spec §33). Each bundles canonical observations and carries the base priority the H6 scheduler starts from.';
CREATE INDEX IF NOT EXISTS idx_exam_concept_domain  ON knowledge.examination_concept(domain_code);
CREATE INDEX IF NOT EXISTS idx_exam_concept_system  ON knowledge.examination_concept(body_system_code);
DROP TRIGGER IF EXISTS trg_knowledge_examination_concept_updated_at ON knowledge.examination_concept;
CREATE TRIGGER trg_knowledge_examination_concept_updated_at
    BEFORE UPDATE ON knowledge.examination_concept FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. observation_concept — ONE per canonical fact (H6 §33/§38)
-- ONE observation_concept = ONE fact_definition. value_type is the data shape the
-- CPU hands to the UI; normal_range holds the adult default; reference_standard
-- (table 9) holds the age/stage-adjusted ranges.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.observation_concept (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code               text NOT NULL UNIQUE,           -- OC001..
    fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
    name               text NOT NULL,
    short_label        text,
    value_type         text NOT NULL CHECK (value_type IN ('BOOLEAN','CATEGORICAL','NUMERIC','TEXT','ORDINAL')),
    unit               text,                            -- e.g. 'Celsius','bpm','%','mmHg'
    value_set_code     text,                            -- controlled vocab for CATEGORICAL observations
    normal_range       jsonb,                           -- {"min":..,"max":..,"unit":..,"inclusive":true} adult default
    applies_to_context_codes text[] NOT NULL DEFAULT '{}', -- which contexts this observation admits values for
    capture_method_code text REFERENCES knowledge.fact_capture_method(method_code), -- how it is obtained
    interpretation_default text,                        -- default interpretation code for this OC
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.observation_concept
    IS 'A measurable clinical finding = ONE canonical fact (spec §38/§44). The CPU records exactly one observation row per canonical fact per encounter.';
CREATE INDEX IF NOT EXISTS idx_obs_concept_fact    ON knowledge.observation_concept(fact_definition_code);
CREATE INDEX IF NOT EXISTS idx_obs_concept_method  ON knowledge.observation_concept(capture_method_code);
DROP TRIGGER IF EXISTS trg_knowledge_observation_concept_updated_at ON knowledge.observation_concept;
CREATE TRIGGER trg_knowledge_observation_concept_updated_at
    BEFORE UPDATE ON knowledge.observation_concept FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. examination_component — which observation_concepts each exam concept yields (H6 §34)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_component (
    examination_concept_code text NOT NULL REFERENCES knowledge.examination_concept(code) ON DELETE CASCADE,
    observation_concept_code text NOT NULL REFERENCES knowledge.observation_concept(code) ON DELETE CASCADE,
    is_mandatory   boolean NOT NULL DEFAULT false, -- this finding must be sought/obtained
    sort_order     integer NOT NULL DEFAULT 0,     -- capture ordering within the concept
    status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (examination_concept_code, observation_concept_code)
);
COMMENT ON TABLE knowledge.examination_component
    IS 'A concept''s constituent canonical findings (spec §34): EX001 general assessment yields OC001 general appearance, OC002 temperature, etc.';
CREATE INDEX IF NOT EXISTS idx_exam_component_obs ON knowledge.examination_component(observation_concept_code);

-- ---------------------------------------------------------------------------
-- 5. examination_technique — the Four Fundamental Techniques (H6 §12)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_technique (
    code        text PRIMARY KEY,                     -- TECH_INSPECTION etc.
    name        text NOT NULL,                        -- Inspection / Palpation / Percussion / Auscultation
    description text,
    sort_order  integer NOT NULL,
    status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_technique
    IS 'The four fundamental physical-examination techniques (H6 §12): Inspection, Palpation, Percussion, Auscultation.';
DROP TRIGGER IF EXISTS trg_knowledge_examination_technique_updated_at ON knowledge.examination_technique;
CREATE TRIGGER trg_knowledge_examination_technique_updated_at
    BEFORE UPDATE ON knowledge.examination_technique FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 6. examination_site — anatomical surface to examine (H6 §13)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_site (
    code            text PRIMARY KEY,                 -- SITE_CHEST etc.
    body_system_code text REFERENCES knowledge.body_system(code),
    name            text NOT NULL,
    description     text,
    default_position_code text,                       -- FK deferred to ALTER (position table created below)
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_site IS 'Anatomical surfaces/portions of the physical exam (H6 §13).';
CREATE INDEX IF NOT EXISTS idx_exam_site_system ON knowledge.examination_site(body_system_code);

-- ---------------------------------------------------------------------------
-- 7. examination_position — patient position for a manoeuvre (H6 §14)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_position (
    position_code   text PRIMARY KEY,                 -- POS_SUPINE etc.
    name            text NOT NULL,                    -- Supine / Sitting / Left lateral ...
    description     text,
    requires        text[],                           -- prerequisite positions if any
    sort_order      integer NOT NULL,
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_position IS 'Standardised patient positions for physical manoeuvres (H6 §14).';
DROP TRIGGER IF EXISTS trg_knowledge_examination_position_updated_at ON knowledge.examination_position;
CREATE TRIGGER trg_knowledge_examination_position_updated_at
    BEFORE UPDATE ON knowledge.examination_position FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- FK wired after examination_position exists (avoids forward reference at CREATE time).
ALTER TABLE knowledge.examination_site
    ADD CONSTRAINT fk_exam_site_default_position
    FOREIGN KEY (default_position_code) REFERENCES knowledge.examination_position(position_code);

-- ---------------------------------------------------------------------------
-- 8. examination_rule — the H6 priority/safety engine (H6 §8/§32)
-- "Given TRIGGER (a symptom, a context, or ALWAYS), do MODIFICATION to TARGET."
-- Mirrors knowledge.context_adaptation_rule (H5 §32) but for the examination.
--   trigger_type   → ALWAYS / CONTEXT / SYMPTOM_SIGN
--   target_type    → examination_concept / technique
--   modification   → SAFETY / MANDATORY / ACTIVATE / UNAVAILABLE / PRIORITY
--   priority_delta → added to examination_concept.base_priority (higher score = earlier)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code             text NOT NULL UNIQUE,            -- ER001..
    trigger_type          text NOT NULL CHECK (trigger_type IN ('ALWAYS','CONTEXT','SYMPTOM_SIGN')),
    trigger_code          text,                       -- clinical_context.code / symptom concept_code (NULL for ALWAYS)
    target_type           text NOT NULL CHECK (target_type IN ('examination_concept','technique')),
    target_code           text NOT NULL,
    modification          text NOT NULL CHECK (modification IN ('SAFETY','MANDATORY','ACTIVATE','UNAVAILABLE','PRIORITY')),
    priority_delta        integer NOT NULL DEFAULT 0,
    rationale             text,
    evidence_claim_code   text REFERENCES knowledge.source_claim(claim_code),
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',
    is_active             boolean NOT NULL DEFAULT true,
    status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (target_type, target_code, trigger_type, trigger_code, modification)
);
COMMENT ON TABLE knowledge.examination_rule
    IS 'H6 priority/safety engine (spec §8/§32). Data-driven examination gating: urgency, mandatory findings, and unavailable modalities are rules, not code.';
CREATE INDEX IF NOT EXISTS idx_exam_rule_target ON knowledge.examination_rule(target_type, target_code);
CREATE INDEX IF NOT EXISTS idx_exam_rule_trigger ON knowledge.examination_rule(trigger_type, trigger_code);
CREATE TRIGGER trg_knowledge_examination_rule_updated_at
    BEFORE UPDATE ON knowledge.examination_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 9. reference_standard — normal ranges by context (H6 §9)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.reference_standard (
    code                   text NOT NULL UNIQUE,        -- RS001.. (for stable provenance joins)
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    observation_concept_code text NOT NULL REFERENCES knowledge.observation_concept(code) ON DELETE CASCADE,
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',  -- NEONATE / CHILD / ADULT / OLDER_ADULT ...
    range_low           numeric,
    range_high          numeric,
    range_unit          text,
    is_inclusive        boolean NOT NULL DEFAULT true,
    interpretation      text NOT NULL DEFAULT 'NORMAL',      -- NORMAL / ABNORMAL / CRITICAL
    source              text,                              -- guideline/hierarchy name
    source_claim_code   text REFERENCES knowledge.source_claim(claim_code),
    evidence_strength   text NOT NULL DEFAULT 'strong' CHECK (evidence_strength IN ('strong','moderate','weak')),
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (observation_concept_code, applies_to_context_codes)
);
COMMENT ON TABLE knowledge.reference_standard
    IS 'Age-/context-adjusted reference ranges for physiological observations (H6 §9). Adult default lives on observation_concept.normal_range; this table holds the paediatric/older-adult/etc. overrides.';
CREATE INDEX IF NOT EXISTS idx_refstd_obs ON knowledge.reference_standard(observation_concept_code);

-- ---------------------------------------------------------------------------
-- 10. finding_interpretation — controlled interpretations of a finding (H6 §10)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.finding_interpretation (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code           text NOT NULL UNIQUE,                        -- FIN_NORMAL etc.
    canonical_name text NOT NULL,
    label       text NOT NULL,
    value_type_constraint text,                          -- restricts which OC value_type this interpretation fits
    is_abnormal boolean NOT NULL DEFAULT false,
    is_critical boolean NOT NULL DEFAULT false,
    description text,
    sort_order  integer NOT NULL,
    status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.finding_interpretation
    IS 'Controlled vocabulary of finding interpretations (H6 §10): from NORMAL/ABNORMAL to sign-specific categorical labels (e.g. VESICULAR, WHEEZE, CRACKLES).';
CREATE INDEX IF NOT EXISTS idx_finding_interp_abnormal ON knowledge.finding_interpretation(is_abnormal);

-- ---------------------------------------------------------------------------
-- 11. finding_phenotype_link — sign + interpretation → associated concept (H6 §44)
-- A captured finding (observation_concept + its categorical value/interpretation)
-- points at an associated sign/symptom/condition concept, which the H4/H5 engines
-- then reason over. associated_concept_code is a free concept_code string so H6 can
-- link findings to the H4 phenotype/condition graph even before those rows exist.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.finding_phenotype_link (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    observation_concept_code text NOT NULL REFERENCES knowledge.observation_concept(code) ON DELETE CASCADE,
    finding_value           text NOT NULL,             -- the categorical value that was found (e.g. 'CRACKLES')
    associated_concept_code text,                      -- a knowledge.concept can_code (sign/symptom/condition/phenotype)
    strength                text NOT NULL DEFAULT 'moderate' CHECK (strength IN ('strong','moderate','weak')),
    description             text,
    evidence_claim_code     text REFERENCES knowledge.source_claim(claim_code),
    is_active               boolean NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    UNIQUE (observation_concept_code, finding_value, associated_concept_code)
);
COMMENT ON TABLE knowledge.finding_phenotype_link
    IS 'Bridge from a physical finding interpretation to the downstream concept it suggests (H6 §44), e.g. crackles+infection → pneumonia-relevant concept.';
CREATE INDEX IF NOT EXISTS idx_fpl_obs ON knowledge.finding_phenotype_link(observation_concept_code);

-- ---------------------------------------------------------------------------
-- 12–13. Runtime fact + component tables (H6 §45) — created, NOT seeded
-- The CPU populates observation/observation_component/examination_plan* at runtime
-- from the knowledge tables above. Rows below are engine output.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.observation (
    observation_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id         uuid NOT NULL,               -- clinical.encounter
    examination_concept_code text REFERENCES knowledge.examination_concept(code),
    observation_concept_code text NOT NULL REFERENCES knowledge.observation_concept(code),
    value_numeric      numeric,
    unit               text,
    value_text         text,
    value_boolean      boolean,
    interpretation_code text REFERENCES knowledge.finding_interpretation(code),
    is_abnormal        boolean,
    performed_by       text,                          -- performer identity
    observed_at        timestamptz NOT NULL DEFAULT now(),
    status             text NOT NULL DEFAULT 'recorded' CHECK (status IN ('recorded','entered','final','entered_in_error')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.observation IS 'A captured physical finding: ONE row = ONE canonical fact at ONE encounter (H6 §45).';
CREATE INDEX IF NOT EXISTS idx_observation_encounter ON knowledge.observation(encounter_id);
CREATE INDEX IF NOT EXISTS idx_observation_concept   ON knowledge.observation(observation_concept_code);
DROP TRIGGER IF EXISTS trg_knowledge_observation_updated_at ON knowledge.observation;
CREATE TRIGGER trg_knowledge_observation_updated_at
    BEFORE UPDATE ON knowledge.observation FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE IF NOT EXISTS knowledge.observation_component (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    observation_id    uuid NOT NULL REFERENCES knowledge.observation(observation_id) ON DELETE CASCADE,
    observation_concept_code text NOT NULL REFERENCES knowledge.observation_concept(code),
    value_numeric     numeric,
    value_text        text,
    unit              text,
    interpretation_code text REFERENCES knowledge.finding_interpretation(code),
    is_abnormal       boolean,
    status            text NOT NULL DEFAULT 'recorded' CHECK (status IN ('recorded','entered','final','entered_in_error')),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.observation_component IS 'Parts of a composite observation (e.g. systolic/diastolic of one BP) (H6 §45).';
CREATE INDEX IF NOT EXISTS idx_obs_component_parent ON knowledge.observation_component(observation_id);

-- ---------------------------------------------------------------------------
-- 14–16. Runtime plan tables (H6 §45) — CPU output, NOT seeded
-- examination_plan         : the prioritised sequence of examination concepts for an encounter
-- examination_plan_item     : one concept on the plan (ordering + status)
-- examination_execution     : log of modality/site/position used per item
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.examination_plan (
    plan_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id   uuid NOT NULL,
    context_stack  jsonb,                          -- snapshot of the H5 context codes active for this plan
    status         text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','in_progress','completed','cancelled')),
    total_priority integer,                       -- summed/overall acuity score driving the plan
    created_by     text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_exam_plan_encounter ON knowledge.examination_plan(encounter_id);

CREATE TABLE IF NOT EXISTS knowledge.examination_plan_item (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id             uuid NOT NULL REFERENCES knowledge.examination_plan(plan_id) ON DELETE CASCADE,
    examination_concept_code text NOT NULL REFERENCES knowledge.examination_concept(code),
    priority_score       integer NOT NULL,         -- base_priority + sum(rule deltas) for this encounter
    is_mandatory        boolean NOT NULL DEFAULT false,
    is_unavailable      boolean NOT NULL DEFAULT false, -- e.g. auscultation blocked by televisit
    status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','skipped','performed','deferred')),
    performed_at        timestamptz,
    performed_by        text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (plan_id, examination_concept_code)
);
CREATE INDEX IF NOT EXISTS idx_exam_plan_item_plan ON knowledge.examination_plan_item(plan_id);

CREATE TABLE IF NOT EXISTS knowledge.examination_execution (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_item_id        uuid NOT NULL REFERENCES knowledge.examination_plan_item(id) ON DELETE CASCADE,
    technique_code      text REFERENCES knowledge.examination_technique(code),
    site_code           text REFERENCES knowledge.examination_site(code),
    position_code       text REFERENCES knowledge.examination_position(position_code),
    notes               text,
    executed_at         timestamptz NOT NULL DEFAULT now(),
    executed_by         text,
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.examination_execution
    IS 'How each plan item was actually performed (technique/site/position) (H6 §45).';
CREATE INDEX IF NOT EXISTS idx_exam_exec_plan_item ON knowledge.examination_execution(plan_item_id);

-- ---------------------------------------------------------------------------
-- 17. Provenance note — H6 objects derive from Hutchison examination claims
-- ---------------------------------------------------------------------------
COMMENT ON TABLE knowledge.provenance
    IS 'Derivation edges from source claims to compiled AMEXAN objects (H1 claims → H2 history concepts, H3 questions/rules, H4 dimensions/red-flags, H5 contexts/variants/adaptation rules, H6 examination concepts/observations/interpretations/reference-standards/examination-rules).';
