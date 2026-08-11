-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H2: universal history ontology
-- =============================================================================
-- H2 answers: "When AMEXAN is taking a history, what exactly is a piece of
-- history, how is it captured, structured, related, documented, and made
-- available to the CPU?"
--
-- Hutchison's foundation (H1): history and examination establish the clinical
-- database (history + examination), which is then interpreted as disturbances
-- of function and potential pathology. H2 builds the UNIVERSAL machinery for
-- that database — NOT disease-specific knowledge. No pneumonia engine, no TB
-- engine: only the universal history vocabulary and structures every disease
-- module will plug into.
--
-- Spec → implementation mapping (the repo already had part of the substrate):
--   history_concept             NEW  — universal history vocabulary (HC001..)
--   symptom_history_dimension   NEW  — which dimensions are meaningful for a symptom
--   history_context_rule        NEW  — context adaptations (adult/child/emergency/...)
--   clinical_question           →    knowledge.question (+ history_concept_id, question_mode)
--   clinical_question_variant   NEW  — knowledge.question_variant (context/language)
--   question_option             →    knowledge.answer_option (+ knowledge.fact_mapping)
--   clinical_fact               →    clinical.fact + clinical.fact_value
--   three-state facts           NEW  — clinical.fact_value.value_state (TRUE/FALSE/UNKNOWN)
--   clinical_fact_relationship  →    clinical.fact_relationship (relationship is free text)
--   clinical_event (timeline)   NEW  — clinical.clinical_event
--   functional impact           NEW  — knowledge.functional_impact (reusable domains)
--   patient_perspective         NEW  — clinical.patient_perspective (IDEA/CONCERN/EXPECTATION/GOAL)
--   fact_provenance             →    clinical.fact_source + clinical.fact_confidence
--   history_reliability         NEW  — clinical.history_reliability
--   fact_revision               →    clinical.fact_history (exists: created/corrected/superseded)
--   question_priority_rule      NEW  — knowledge.question_priority_rule (P001..)
--   H2 questioning engine       →    knowledge.question_trigger + question_requirement + rule (H3)
--
-- The separation enforced here is the H2 architectural law:
--   PostgreSQL = KNOWLEDGE + CONFIGURATION
--   CPU        = DECISION / EXECUTION
--   UI         = RENDERING (never medical intelligence)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. history_concept — the universal vocabulary of capturable things
-- ---------------------------------------------------------------------------
-- Deliberately small and reusable. The symptom object decides which dimensions
-- are meaningful (via symptom_history_dimension); it does NOT live in the UI.
CREATE TABLE IF NOT EXISTS knowledge.history_concept (
    history_concept_id text PRIMARY KEY,          -- HC001 .. HC028 (universal), HC029+ (dimension)
    concept_code       text NOT NULL UNIQUE,      -- ONSET / DURATION / SITE / PRODUCTIVITY / ...
    concept_name       text NOT NULL,
    concept_type       text NOT NULL              -- encounter / temporal / symptom / function / background / exposure / reproductive / screening / patient_perspective / source
                       CHECK (concept_type IN ('encounter','temporal','symptom','function','background','exposure','reproductive','screening','patient_perspective','source')),
    reusable           boolean NOT NULL DEFAULT true,   -- reusable across symptoms/systems?
    description        text,
    concept_id         uuid REFERENCES knowledge.concept(id),  -- optional link into the wider knowledge graph
    status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.history_concept
   IS 'Universal history vocabulary. Every capturable piece of a history is a concept; symptoms and systems reference it.';

CREATE INDEX idx_history_concept_type ON knowledge.history_concept(concept_type);
CREATE TRIGGER trg_knowledge_history_concept_updated_at
   BEFORE UPDATE ON knowledge.history_concept
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. symptom_history_dimension — the symptom tells AMEXAN what is meaningful
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_history_dimension (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id         uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    history_concept_id text NOT NULL REFERENCES knowledge.history_concept(history_concept_id) ON DELETE CASCADE,
    priority           integer NOT NULL DEFAULT 50,   -- ordering within the symptom
    mandatory          boolean NOT NULL DEFAULT false,-- must always be characterized
    applicable         boolean NOT NULL DEFAULT true, -- meaningful for this symptom?
    UNIQUE (symptom_id, history_concept_id)
);
COMMENT ON TABLE knowledge.symptom_history_dimension
   IS 'Maps a symptom to the history dimensions that make sense for it. This is what stops the UI asking nonsense (e.g. radiation for cough).';

CREATE INDEX idx_symptom_history_dimension ON knowledge.symptom_history_dimension(symptom_id);

-- ---------------------------------------------------------------------------
-- 3. history_context_rule — age/sex/context adaptations (Hutchison part II)
-- ---------------------------------------------------------------------------
-- The DATABASE stores the rule; the CPU executes it; the UI renders what the
-- CPU says is relevant. subject_code is polymorphic (history_concept code,
-- symptom code or fact_definition code) so rules read naturally.
CREATE TABLE IF NOT EXISTS knowledge.history_context_rule (
    rule_id            text PRIMARY KEY,             -- R001 ..
    subject_code       text NOT NULL,                -- COUGH_PRODUCTIVITY / DYSPNOEA / PRESENTING_CONCERN / HISTORY_SOURCE / REPRODUCTIVE_HISTORY ...
    context_label      text NOT NULL,                -- adult / young_child / emergency / unconscious / reproductive_context / child
    context_type_code  text REFERENCES knowledge.context_type(code),   -- optional formal context dimension
    context_value      text,                         -- optional formal context value (AGE: 1-4Y ...)
    action             text NOT NULL,                -- what changes in this context
    description        text,
    sort_order         integer NOT NULL DEFAULT 0,
    UNIQUE (subject_code, context_label)
);
COMMENT ON TABLE knowledge.history_context_rule
   IS 'How a history subject is adapted across contexts (women, children, older people, psychiatric, emergencies, fever, pain).';

-- ---------------------------------------------------------------------------
-- 4. question wiring — universal questions + modes + variants
-- ---------------------------------------------------------------------------
-- knowledge.question is the existing universal question registry (the spec's
-- clinical_question). H2 adds the universal history vocabulary link and the
-- Hutchison question-mode classification (OPEN/DIRECT/CLARIFYING/SCALE/...).
ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS history_concept_id text REFERENCES knowledge.history_concept(history_concept_id);

ALTER TABLE knowledge.question
    ADD COLUMN IF NOT EXISTS question_mode text
        CHECK (question_mode IN ('OPEN','DIRECT','CLARIFYING','SCALE','FUNCTIONAL','PROBING','NEGATIVE_EXCLUSION','CONTEXT'));

-- question_variant — the spec's clinical_question_variant: the fact stays the
-- same (ONSET), only the presentation changes (adult / child_proxy / caregiver / language).
CREATE TABLE IF NOT EXISTS knowledge.question_variant (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id        uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    context            text NOT NULL DEFAULT 'default',  -- adult / child_proxy / caregiver / interpreter ...
    language_code      text NOT NULL DEFAULT 'en',
    wording            text NOT NULL,
    is_active          boolean NOT NULL DEFAULT true,
    UNIQUE (question_id, context, language_code)
);
COMMENT ON TABLE knowledge.question_variant
   IS 'Context/language variants of the same question. The underlying fact is unchanged; only the wording differs.';

-- question_priority_rule — the spec''s H2 question-priority factors (P001..P010).
-- The CPU scores every candidate question, ranks them, and presents only the
-- next small group to the UI.
CREATE TABLE IF NOT EXISTS knowledge.question_priority_rule (
    rule_code          text PRIMARY KEY,             -- P001 ..
    factor             text NOT NULL UNIQUE,         -- mandatory_foundation / emergency_red_flag / ...
    effect             integer NOT NULL DEFAULT 0,   -- priority weight applied by the CPU
    description        text
);
COMMENT ON TABLE knowledge.question_priority_rule
   IS 'Data-driven question-prioritization factors. The CPU sums these to rank the next best question.';

-- ---------------------------------------------------------------------------
-- 5. THREE-STATE CLINICAL FACTS — TRUE / FALSE / UNKNOWN are first-class
-- ---------------------------------------------------------------------------
-- Hutchison: negative answers are diagnostically important, so HAEMOPTYSIS=FALSE
-- must be stored, and UNKNOWN must be distinguishable from NOT_ASKED. NOT_ASKED
-- remains the ABSENCE of a fact row; UNKNOWN is a fact row with value_state='unknown'.
ALTER TABLE clinical.fact_value
    ADD COLUMN IF NOT EXISTS value_state text NOT NULL DEFAULT 'known'
        CHECK (value_state IN ('known','unknown'));

-- enforce: an UNKNOWN fact carries no typed value
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fact_value_unknown_has_no_value'
    ) THEN
        ALTER TABLE clinical.fact_value
            ADD CONSTRAINT fact_value_unknown_has_no_value
            CHECK (value_state = 'known' OR (
                value_text IS NULL AND value_numeric IS NULL AND value_boolean IS NULL
                AND value_date IS NULL AND value_datetime IS NULL AND value_concept_id IS NULL
            ));
    END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 6. clinical_event — the history TIMELINE (Hutchison: chronology is central)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinical.clinical_event (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id         uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
    encounter_id       uuid REFERENCES encounter.encounter(id),
    event_type         text NOT NULL,                -- symptom_onset / cough_progression / dyspnoea_onset / presentation / ...
    event_time         timestamptz,                  -- WHEN (best-known anchor for the event)
    event_order        integer,                      -- relative order when time is approximate
    fact_id            uuid REFERENCES clinical.fact(id) ON DELETE SET NULL,
    description        text,
    recorded_at        timestamptz NOT NULL DEFAULT now(),
    recorded_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE clinical.clinical_event
   IS 'Anchors facts to a timeline so the CPU can reconstruct the story (Day1 cough → Day2 productive → Day4 dyspnoea) rather than a flat list.';

CREATE INDEX idx_clinical_event_encounter ON clinical.clinical_event(encounter_id);
CREATE INDEX idx_clinical_event_patient ON clinical.clinical_event(patient_id);

-- ---------------------------------------------------------------------------
-- 7. patient_perspective — the patient''s illness framework (NOT the diagnosis)
-- ---------------------------------------------------------------------------
-- Hutchison distinguishes the disease framework from the patient''s illness
-- framework: their ideas, concerns, expectations and feelings (Box 1.16).
CREATE TABLE IF NOT EXISTS clinical.patient_perspective (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id         uuid NOT NULL REFERENCES patient.patient(id) ON DELETE CASCADE,
    encounter_id       uuid REFERENCES encounter.encounter(id),
    perspective_type   text NOT NULL CHECK (perspective_type IN ('IDEA','CONCERN','EXPECTATION','GOAL')),
    value              text NOT NULL,
    patient_quote      text,                          -- raw words where available
    recorded_at        timestamptz NOT NULL DEFAULT now(),
    recorded_by        uuid REFERENCES identity.user_account(id)
);
COMMENT ON TABLE clinical.patient_perspective
   IS 'Facts about the patient''s perspective (ideas/concerns/expectations/goals) — captured, never diagnosed.';

CREATE INDEX idx_patient_perspective_encounter ON clinical.patient_perspective(encounter_id);

-- ---------------------------------------------------------------------------
-- 8. history_reliability — the CPU must never treat uncertain as verified
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinical.history_reliability (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id       uuid NOT NULL REFERENCES encounter.encounter(id) ON DELETE CASCADE,
    dimension          text NOT NULL,                -- overall / chronology / medication_history / collateral_available / ...
    value              text NOT NULL,                -- reliable / uncertain / unreliable / yes / no / partial
    assessed_at        timestamptz NOT NULL DEFAULT now(),
    assessed_by        uuid REFERENCES identity.user_account(id),
    note               text,
    UNIQUE (encounter_id, dimension)
);
COMMENT ON TABLE clinical.history_reliability
   IS 'Reliability assessment per encounter dimension. Uncertain history must not be treated as verified fact.';

-- ---------------------------------------------------------------------------
-- 9. functional_impact — its own reusable domain (mobility / work / sleep ...)
-- ---------------------------------------------------------------------------
-- Hutchison: assess how symptoms affect exercise, work, sport, eating and
-- social life (Box 1.5). These domains are reused by every disease and department.
CREATE TABLE IF NOT EXISTS knowledge.functional_impact (
    function_code      text PRIMARY KEY,             -- WALKING_LIMITATION / EXERCISE_TOLERANCE / ...
    domain             text NOT NULL,                -- mobility / physical_activity / occupation / education / nutrition / sleep / social / adl / sexual_health
    label              text NOT NULL,
    description        text
);
COMMENT ON TABLE knowledge.functional_impact
   IS 'Reusable functional-impact domains. Every symptom/disease module references these rather than inventing its own.';

-- ---------------------------------------------------------------------------
-- 10. provenance to H1 — the trace requirement continues
-- ---------------------------------------------------------------------------
-- H1 gives the clinical-method knowledge; H2 compiles universal history objects
-- FROM that knowledge. knowledge.provenance already carries the derivation
-- edges (claim → compiled object). H2 seeds will insert edges with
-- object_type='history_concept', object_code=<concept_code>.
COMMENT ON TABLE knowledge.provenance
   IS 'Derivation edges from source claims to compiled AMEXAN objects (H1 claims → H2 history concepts, H3 questions, ...).';
