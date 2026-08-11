-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H3: question & rule engine
-- =============================================================================
-- H3 answers: "Given the facts already known about this patient, which question
-- should AMEXAN ask NEXT, and why?"  It is the adaptive interview. No hard-coded
-- sequence lives in the CPU — the DATABASE holds every relevance rule, every
-- dependency, every rationale, every differential weight, every documentation
-- requirement and every completion criterion. The CPU only executes them.
--
-- Architectural law (unchanged):
--   PostgreSQL = KNOWLEDGE + CONFIGURATION   (everything below)
--   CPU        = DECISION / EXECUTION        (ranks and asks, never re-invents rules)
--   UI         = RENDERING                   (shows what the CPU chose)
--
-- Spec → implementation mapping:
--   question_rule                 NEW  — knowledge.question_rule  (QR001..) the H3 heart
--   question_module               NEW  — knowledge.question_module + _member (cough_core, sputum, ...)
--   question_dependency           NEW  — knowledge.question_dependency (blocking/ordering)
--   question_rationale            NEW  — knowledge.question_rationale (WHY we ask each question)
--   question_differential_weight  NEW  — knowledge.question_differential_weight (for/against conditions)
--   documentation_requirement     NEW  — knowledge.documentation_requirement (care standard)
--   history_completion_rule       NEW  — knowledge.history_completion_rule (clinical, not 100%)
--   requirement levels            UPGRADED — + 'safety' + 'high_priority' to question_requirement
--   fact → symptom cascade        EXISTS — knowledge.symptom_activation_fact (kept, reused)
--   candidates + scoring          CPU   — QuestionSelector consumes the tables above
--
-- Design law repeated from H2: the separation is enforced here — the question
-- engine is DATA. A rule that a clinician would argue with is a data error,
-- fixed in the database, not a code change.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. question_rule — the heart of H3
-- ---------------------------------------------------------------------------
-- A rule fires on a TRIGGER (a captured fact, or a patient context) and
-- ACTIVATEs / DEACTIVATEs a TARGET (a question, a symptom, or a question
-- module). priority_delta re-weights the target so dangerous/central questions
-- rise without ever hard-coding a fixed order.
CREATE TABLE IF NOT EXISTS knowledge.question_rule (
    rule_id             text PRIMARY KEY,             -- QR001 ..
    rule_name           text NOT NULL,
    trigger_type        text NOT NULL DEFAULT 'fact' CHECK (trigger_type IN ('fact','context')),
    trigger_code        text NOT NULL,                -- fact_definition.code OR context_type.code (AGE/PREGNANCY/...)
    trigger_operator    text NOT NULL DEFAULT 'eq' CHECK (trigger_operator IN ('eq','ne','gt','gte','lt','lte','in')),
    trigger_value       jsonb,                        -- scalar value or array (for 'in')
    action              text NOT NULL CHECK (action IN ('ACTIVATE','DEACTIVATE')),
    target_type         text NOT NULL CHECK (target_type IN ('question','symptom','module')),
    target_code         text NOT NULL,                -- question_code / symptom_code / module_code
    priority_delta      integer NOT NULL DEFAULT 0,
    rationale           text,
    context             jsonb,                        -- optional additional context binding (e.g. {"AGE": "5-17Y"})
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    version             integer NOT NULL DEFAULT 1,
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','superseded','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (trigger_type, trigger_code, trigger_operator, trigger_value, action, target_type, target_code)
);
COMMENT ON TABLE knowledge.question_rule
   IS 'The H3 question engine. A fired rule ACTIVATEs or DEACTIVATEs a target question/symptom/module and re-weights it. All rules live here, never in CPU code.';
COMMENT ON COLUMN knowledge.question_rule.trigger_type
   IS 'fact = fires on a captured clinical.fact_definition.code; context = fires on a patient context (knowledge.context_type.code, e.g. AGE/PREGNANCY).';
CREATE INDEX idx_question_rule_trigger ON knowledge.question_rule(trigger_type, trigger_code);
CREATE INDEX idx_question_rule_target ON knowledge.question_rule(target_type, target_code);
CREATE TRIGGER trg_knowledge_question_rule_updated_at
   BEFORE UPDATE ON knowledge.question_rule
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. question_module + member — named banks of questions
-- ---------------------------------------------------------------------------
-- Targets like cough_core / sputum / dyspnoea group questions so a rule can
-- activate several related questions at once (the spec''s "question banks").
CREATE TABLE IF NOT EXISTS knowledge.question_module (
    module_code         text PRIMARY KEY,             -- COUGH_CORE / SPUTUM / DYSPNOEA / ...
    module_name         text NOT NULL,
    description         text,
    sort_order          integer NOT NULL DEFAULT 0,
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired'))
);
COMMENT ON TABLE knowledge.question_module
   IS 'Named banks of questions (cough_core, sputum, dyspnoea ...). Rules and modules keep the engine composable.';

CREATE TABLE IF NOT EXISTS knowledge.question_module_member (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code         text NOT NULL REFERENCES knowledge.question_module(module_code) ON DELETE CASCADE,
    question_id         uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    sort_order          integer NOT NULL DEFAULT 0,
    UNIQUE (module_code, question_id)
);
CREATE INDEX idx_question_module_member ON knowledge.question_module_member(question_id);

-- ---------------------------------------------------------------------------
-- 3. question_dependency — the socratic ordering graph
-- ---------------------------------------------------------------------------
-- Dependency = "you may/should ask this question only after X is true".
--   blocking   : the question CANNOT be asked until the prerequisite is satisfied
--   non-blocking: the prerequisite raises priority but does not block (ordering hint)
CREATE TABLE IF NOT EXISTS knowledge.question_dependency (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id         uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    prerequisite_type   text NOT NULL CHECK (prerequisite_type IN ('fact','question','context')),
    prerequisite_code   text NOT NULL,                -- fact_definition.code / question_code / context_type.code
    operator            text NOT NULL DEFAULT 'eq' CHECK (operator IN ('eq','ne','gt','gte','lt','lte','in')),
    value               jsonb,                        -- expected value(s) of the prerequisite
    is_blocking         boolean NOT NULL DEFAULT false,
    priority            integer NOT NULL DEFAULT 0,
    description         text,
    UNIQUE (question_id, prerequisite_type, prerequisite_code, operator, value)
);
COMMENT ON TABLE knowledge.question_dependency
   IS 'Ordering/eligibility graph: when a prerequisite must hold before a question is asked (blocking) or when it merely raises its priority (ordering).';
CREATE INDEX idx_question_dependency_prereq ON knowledge.question_dependency(prerequisite_type, prerequisite_code);

-- ---------------------------------------------------------------------------
-- 4. question_rationale — WHY the question is being asked
-- ---------------------------------------------------------------------------
-- Every question asked by AMEXAN must be explainable to the clinician. The
-- rationale is stored next to the evidence claim that grounds it.
CREATE TABLE IF NOT EXISTS knowledge.question_rationale (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id         uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    rationale_type      text NOT NULL CHECK (rationale_type IN ('clinical','safety','differential','documentation','context','educational')),
    rationale           text NOT NULL,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    UNIQUE (question_id, rationale_type)
);
COMMENT ON TABLE knowledge.question_rationale
   IS 'Explainable question selection: each question carries a rationale grounded in an evidence claim, so the CPU can say WHY it asked.';
CREATE INDEX idx_question_rationale_q ON knowledge.question_rationale(question_id);

-- ---------------------------------------------------------------------------
-- 5. question_differential_weight — for/against the differentials
-- ---------------------------------------------------------------------------
-- An answer to a question moves the differential diagnosis. weight is added to
-- a condition (positive) or subtracted (negative) when the question is answered
-- with answer_value. NULL answer_value = any answer counts.
CREATE TABLE IF NOT EXISTS knowledge.question_differential_weight (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id         uuid NOT NULL REFERENCES knowledge.question(id) ON DELETE CASCADE,
    condition_id        uuid NOT NULL REFERENCES knowledge.condition(id) ON DELETE CASCADE,
    answer_value        text,                          -- the answer that carries the weight (NULL = any)
    weight              integer NOT NULL,              -- + supports, - opposes the condition
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    UNIQUE (question_id, condition_id, answer_value)
);
COMMENT ON TABLE knowledge.question_differential_weight
   IS 'How an answer moves the differential diagnosis. The CPU sums these into its differential ranking (deterministic, auditable — never a hidden ML model).';
CREATE INDEX idx_question_diff_weight_q ON knowledge.question_differential_weight(question_id);

-- ---------------------------------------------------------------------------
-- 6. documentation_requirement — the care standard
-- ---------------------------------------------------------------------------
-- Some facts must be documented for a presentation regardless of the live score
-- (e.g. haemoptysis status in every cough). section_code groups them (HPI / RED_FLAGS ...).
CREATE TABLE IF NOT EXISTS knowledge.documentation_requirement (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    section_code        text NOT NULL,                 -- HPI / RED_FLAGS / RISK_FACTORS / ...
    required_fact_code  text NOT NULL REFERENCES clinical.fact_definition(code),
    condition           jsonb,                         -- when it applies (jsonb fact-condition, null = always)
    priority            integer NOT NULL DEFAULT 0,
    is_required         boolean NOT NULL DEFAULT true,
    evidence_claim_code text REFERENCES knowledge.source_claim(claim_code),
    UNIQUE (section_code, required_fact_code)
);
COMMENT ON TABLE knowledge.documentation_requirement
   IS 'Care-standard documentation obligations per presentation section. Missing required facts are surfaced even if the live score would not ask the question again.';

-- ---------------------------------------------------------------------------
-- 7. history_completion_rule — clinical completion, never 100%
-- ---------------------------------------------------------------------------
-- Completion is a CLINICAL judgement: the history for a presentation is
-- complete when the discriminating facts are established — not when every
-- question in the bank has been asked. condition is an and/or tree over facts:
--   {"and": [ {"fact":"COUGH_ONSET"}, {"or":[{"fact":"COUGH_PRODUCTIVITY","value":"NON_PRODUCTIVE"},{"fact":"SPUTUM_COLOUR"}]} ]}
CREATE TABLE IF NOT EXISTS knowledge.history_completion_rule (
    rule_id             text PRIMARY KEY,             -- HCR-COUGH ..
    subject_type        text NOT NULL,                -- symptom / presentation / encounter
    subject_code        text NOT NULL,                -- symptom_code or presentation code
    condition           jsonb NOT NULL,               -- and/or tree of required facts
    description         text,
    UNIQUE (subject_type, subject_code)
);
COMMENT ON TABLE knowledge.history_completion_rule
   IS 'Clinical completion criteria. A history is complete when these discriminating facts are established — the engine must never chase 100%% of questions.';

-- ---------------------------------------------------------------------------
-- 8. question_requirement — add the H3 mandatory levels
-- ---------------------------------------------------------------------------
-- H3 levels (spec §9): MANDATORY / HIGH_PRIORITY / CONDITIONAL / OPTIONAL / SAFETY.
-- 'safety' outranks even 'mandatory' — a red-flag probe is never delayed by
-- completeness ordering. Existing rows keep their legacy levels.
ALTER TABLE knowledge.question_requirement
    DROP CONSTRAINT IF EXISTS question_requirement_requirement_level_check;
ALTER TABLE knowledge.question_requirement
    ADD CONSTRAINT question_requirement_requirement_level_check
    CHECK (requirement_level IN ('mandatory','conditionally_required','optional','informational','safety','high_priority'));

-- ---------------------------------------------------------------------------
-- 9. provenance note — H3 objects derive from H1 claims
-- ---------------------------------------------------------------------------
-- Seeds insert edges object_type='question_rule'|'question_rationale'|'question_differential_weight'
-- |'documentation_requirement'|'history_completion_rule', object_code=<code>, against H1 claim codes.
COMMENT ON TABLE knowledge.provenance
   IS 'Derivation edges from source claims to compiled AMEXAN objects (H1 claims → H2 history concepts, H3 questions/rules, ...).';
