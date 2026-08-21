-- =============================================================================
-- AMEXAN Phase 3 â€” Migration 019
-- UNIVERSAL CLINICAL KNOWLEDGE SEED + CPU ACTIVATION HARDENING
-- =============================================================================
--
-- PURPOSE
-- -------
-- This migration strengthens the universal clinical intelligence substrate.
--
-- PRINCIPLES
-- ----------
-- 1. Disease does not drive the interview directly.
--    PRESENTING CONCEPT/SYMPTOM -> QUESTIONS -> FACTS -> PHENOTYPES ->
--    MECHANISMS -> DIFFERENTIALS -> INVESTIGATIONS -> MANAGEMENT.
--
-- 2. One clinical concept is reused everywhere.
--    No duplicate "cough" concepts for respiratory, paediatrics, emergency,
--    medicine, ENT, etc.
--
-- 3. Questions are activated by universal triggers.
--
-- 4. Every clinically meaningful answer should become a structured fact.
--
-- 5. The CPU reasons from facts and context, never from UI labels.
--
-- 6. Positive findings, negative findings, unknowns and contradictions must
--    remain distinguishable.
--
-- 7. The knowledge layer is universal; local configuration belongs in
--    knowledge.knowledge_override.
--
-- 8. No disease-specific CPU is created here.
--
-- 9. No invented drug dose or guideline recommendation is introduced.
--
-- 10. All inserts are idempotent and safe to rerun.
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- 1. KNOWLEDGE GRAPH INTEGRITY
-- =============================================================================

COMMENT ON SCHEMA knowledge IS
'Universal AMEXAN clinical intelligence substrate. Concepts, symptoms, questions,
facts, phenotypes, mechanisms, conditions, investigations, medications,
protocols, monitoring, education and typed relationships compose one reusable
clinical knowledge graph.';


-- -----------------------------------------------------------------------------
-- Universal indexes used heavily by the CPU.
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_knowledge_concept_code
    ON knowledge.concept(concept_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_concept_type_status
    ON knowledge.concept(concept_type, status);

CREATE INDEX IF NOT EXISTS idx_knowledge_symptom_code
    ON knowledge.symptom(symptom_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_question_code
    ON knowledge.question(question_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_question_active_priority
    ON knowledge.question(is_active, priority DESC);

CREATE INDEX IF NOT EXISTS idx_knowledge_question_trigger_lookup
    ON knowledge.question_trigger(trigger_type, trigger_code, priority DESC);

CREATE INDEX IF NOT EXISTS idx_knowledge_question_context_lookup
    ON knowledge.question_context(context_type_code, context_value_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_relationship_lookup
    ON knowledge.relationship(
        source_type,
        source_id,
        relationship_type,
        target_type,
        target_id
    );

CREATE INDEX IF NOT EXISTS idx_knowledge_relationship_reverse
    ON knowledge.relationship(
        target_type,
        target_id,
        relationship_type,
        source_type,
        source_id
    );

CREATE INDEX IF NOT EXISTS idx_knowledge_condition_code
    ON knowledge.condition(condition_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_phenotype_code
    ON knowledge.phenotype(phenotype_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_mechanism_code
    ON knowledge.mechanism(mechanism_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_investigation_code
    ON knowledge.investigation(investigation_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_medication_code
    ON knowledge.medication(medication_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_protocol_code
    ON knowledge.protocol(protocol_code);


-- =============================================================================
-- 2. UNIVERSAL CONCEPTS
-- =============================================================================
-- Only create concepts that are required by the activation substrate.
-- Existing richer concepts are never duplicated.
-- =============================================================================

INSERT INTO knowledge.concept (
    id,
    concept_code,
    concept_type,
    canonical_name,
    display_name,
    description,
    status
)
VALUES
(
    'f0a00000-0000-0000-0000-000000000001',
    'CNS-COUGH',
    'symptom',
    'cough',
    'Cough',
    'A forceful expiratory respiratory symptom requiring characterization by onset, duration, quality, severity, associated features and context.',
    'active'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'CNS-FEVER',
    'symptom',
    'fever',
    'Fever',
    'Elevated body temperature or history of fever requiring characterization by onset, duration, severity, pattern and associated symptoms.',
    'active'
),
(
    'f0a00000-0000-0000-0000-000000000006',
    'CNS-CHEST-PAIN',
    'symptom',
    'chest pain',
    'Chest pain',
    'Pain or discomfort perceived in the chest requiring characterization by site, onset, character, radiation, severity, timing, provoking/relieving factors and associated features.',
    'active'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'CNS-DYSPNOEA',
    'symptom',
    'dyspnoea',
    'Shortness of breath',
    'Subjective breathing difficulty requiring characterization by onset, severity, exertional relationship, positional relationship and associated features.',
    'active'
)
ON CONFLICT (concept_code) DO NOTHING;


-- =============================================================================
-- 3. UNIVERSAL SYMPTOM REGISTRY
-- =============================================================================

INSERT INTO knowledge.symptom (
    id,
    concept_id,
    symptom_code,
    canonical_name,
    definition,
    is_emergency,
    status
)
SELECT
    v.id::uuid,
    c.id,
    v.symptom_code,
    v.canonical_name,
    v.definition,
    v.is_emergency,
    'active'
FROM (
    VALUES
    (
        'f0b00000-0000-0000-0000-000000000001',
        'CNS-COUGH',
        'SYM-COUGH',
        'cough',
        'Forceful expiration involving the respiratory tract; characterize onset, duration, quality, severity, sputum and associated symptoms.',
        false
    ),
    (
        'f0b00000-0000-0000-0000-000000000002',
        'CNS-FEVER',
        'SYM-FEVER',
        'fever',
        'History or measurement of elevated body temperature; characterize onset, duration, pattern, severity and associated symptoms.',
        false
    ),
    (
        'f0b00000-0000-0000-0000-00000000000a',
        'CNS-CHEST-PAIN',
        'SYM-CHEST-PAIN',
        'chest pain',
        'Pain or discomfort perceived in the chest requiring systematic characterization and safety screening.',
        true
    ),
    (
        'f0b00000-0000-0000-0000-000000000003',
        'CNS-DYSPNOEA',
        'SYM-DYSPNOEA',
        'dyspnoea',
        'Subjective breathing difficulty requiring assessment of severity and physiological compromise.',
        true
    )
) AS v(
    id,
    concept_code,
    symptom_code,
    canonical_name,
    definition,
    is_emergency
)
JOIN knowledge.concept c
    ON c.concept_code = v.concept_code
ON CONFLICT (symptom_code) DO NOTHING;


-- =============================================================================
-- 4. UNIVERSAL SYMPTOM SYNONYMS
-- =============================================================================

INSERT INTO knowledge.symptom_synonym (
    symptom_id,
    synonym,
    language_code,
    is_preferred
)
SELECT
    s.id,
    v.synonym,
    'en',
    v.is_preferred
FROM (
    VALUES
    ('SYM-COUGH', 'cough', true),
    ('SYM-COUGH', 'coughing', false),
    ('SYM-FEVER', 'fever', true),
    ('SYM-FEVER', 'high temperature', false),
    ('SYM-CHEST-PAIN', 'chest pain', true),
    ('SYM-CHEST-PAIN', 'chest discomfort', false),
    ('SYM-DYSPNOEA', 'shortness of breath', true),
    ('SYM-DYSPNOEA', 'breathlessness', false),
    ('SYM-DYSPNOEA', 'difficulty breathing', false)
) AS v(symptom_code, synonym, is_preferred)
JOIN knowledge.symptom s
    ON s.symptom_code = v.symptom_code
ON CONFLICT (symptom_id, synonym, language_code) DO NOTHING;


-- =============================================================================
-- 5. UNIVERSAL BODY-SYSTEM RELATIONSHIPS
-- =============================================================================
-- A symptom may belong to multiple systems.
-- This does NOT create multiple symptoms.
-- =============================================================================

INSERT INTO knowledge.body_system (code, label, description)
VALUES
    ('GENITOURINARY', 'Genitourinary', 'Urinary and reproductive systems.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO knowledge.symptom_system (
    symptom_id,
    body_system_code,
    relevance
)
SELECT
    s.id,
    v.body_system_code,
    v.relevance
FROM (
    VALUES
    ('SYM-COUGH',      'RESPIRATORY', '1.00'::numeric),
    ('SYM-COUGH',      'CARDIOVASCULAR', '0.60'::numeric),
    ('SYM-COUGH',      'GASTROINTESTINAL', '0.40'::numeric),
    ('SYM-COUGH',      'ENT', '0.80'::numeric),
    ('SYM-FEVER',      'SYSTEMIC', '1.00'::numeric),
    ('SYM-FEVER',      'RESPIRATORY', '0.80'::numeric),
    ('SYM-FEVER',      'GENITOURINARY', '0.60'::numeric),
    ('SYM-FEVER',      'GASTROINTESTINAL', '0.60'::numeric),
    ('SYM-FEVER',      'NEUROLOGICAL', '0.50'::numeric),
    ('SYM-CHEST-PAIN', 'CARDIOVASCULAR', '1.00'::numeric),
    ('SYM-CHEST-PAIN', 'RESPIRATORY', '1.00'::numeric),
    ('SYM-CHEST-PAIN', 'GASTROINTESTINAL', '0.60'::numeric),
    ('SYM-CHEST-PAIN', 'MUSCULOSKELETAL', '0.80'::numeric),
    ('SYM-CHEST-PAIN', 'ENT', '0.30'::numeric),
    ('SYM-DYSPNOEA',   'RESPIRATORY', '1.00'::numeric),
    ('SYM-DYSPNOEA',   'CARDIOVASCULAR', '1.00'::numeric),
    ('SYM-DYSPNOEA',   'NEUROLOGICAL', '0.40'::numeric),
    ('SYM-DYSPNOEA',   'SYSTEMIC', '0.50'::numeric)
) AS v(symptom_code, body_system_code, relevance)
JOIN knowledge.symptom s
    ON s.symptom_code = v.symptom_code
ON CONFLICT (symptom_id, body_system_code) DO UPDATE
SET relevance = EXCLUDED.relevance;


-- =============================================================================
-- 6. SYMPTOM RELATIONSHIPS
-- =============================================================================

INSERT INTO knowledge.symptom_relationship (
    symptom_id,
    related_symptom_id,
    relationship_type,
    weight
)
SELECT
    a.id,
    b.id,
    v.relationship_type,
    v.weight
FROM (
    VALUES
    ('SYM-COUGH', 'SYM-FEVER', 'associated_with', 0.80::numeric),
    ('SYM-COUGH', 'SYM-DYSPNOEA', 'associated_with', 0.80::numeric),
    ('SYM-COUGH', 'SYM-CHEST-PAIN', 'associated_with', 0.60::numeric),
    ('SYM-FEVER', 'SYM-COUGH', 'associated_with', 0.80::numeric),
    ('SYM-FEVER', 'SYM-DYSPNOEA', 'associated_with', 0.50::numeric),
    ('SYM-CHEST-PAIN', 'SYM-DYSPNOEA', 'associated_with', 0.70::numeric),
    ('SYM-DYSPNOEA', 'SYM-CHEST-PAIN', 'associated_with', 0.70::numeric)
) AS v(
    symptom_code,
    related_symptom_code,
    relationship_type,
    weight
)
JOIN knowledge.symptom a
    ON a.symptom_code = v.symptom_code
JOIN knowledge.symptom b
    ON b.symptom_code = v.related_symptom_code
ON CONFLICT (
    symptom_id,
    related_symptom_id,
    relationship_type
) DO UPDATE
SET
    weight = EXCLUDED.weight;


-- =============================================================================
-- 7. GATE QUESTION ACTIVATION
-- =============================================================================
-- The adaptive interview MUST be able to open secondary symptom branches
-- from the presenting complaint.
--
-- These are universal gates, not pneumonia-specific questions.
-- =============================================================================

INSERT INTO knowledge.question_trigger (
    question_id,
    trigger_type,
    trigger_code,
    priority
)
SELECT
    q.id,
    v.trigger_type,
    v.trigger_code,
    v.priority
FROM (
    VALUES
    ('CHEST_PAIN_PRESENT', 'symptom', 'SYM-CHEST-PAIN', 10),
    ('CHEST_PAIN_PRESENT', 'symptom', 'chest pain', 10),

    ('FEVER_PRESENT', 'symptom', 'SYM-FEVER', 10),
    ('FEVER_PRESENT', 'symptom', 'fever', 10),

    ('FEVER_ONSET', 'symptom', 'SYM-FEVER', 20),
    ('FEVER_ONSET', 'symptom', 'fever', 20),

    ('COUGH_SEVERITY', 'symptom', 'SYM-COUGH', 20),
    ('COUGH_SEVERITY', 'symptom', 'cough', 20),

    ('DYSPNOEA_PRESENT', 'symptom', 'SYM-DYSPNOEA', 10),
    ('DYSPNOEA_PRESENT', 'symptom', 'dyspnoea', 10),
    ('DYSPNOEA_PRESENT', 'symptom', 'shortness of breath', 10)
) AS v(
    question_code,
    trigger_type,
    trigger_code,
    priority
)
JOIN knowledge.question q
    ON q.question_code = v.question_code
WHERE q.is_active = true
ON CONFLICT (question_id, trigger_type, trigger_code, activation_mode) DO NOTHING;


-- =============================================================================
-- 8. UNIVERSAL QUESTION GATES
-- =============================================================================
-- Add the questions only if they do not already exist.
-- They are intentionally generic.
-- =============================================================================

INSERT INTO knowledge.question (
    question_code,
    question_type,
    text,
    response_type,
    priority,
    is_active
)
VALUES
(
    'CHEST_PAIN_PRESENT',
    'clinical',
    'Is chest pain or chest discomfort present?',
    'boolean',
    10,
    true
),
(
    'FEVER_PRESENT',
    'clinical',
    'Has the patient had fever or felt feverish?',
    'boolean',
    10,
    true
),
(
    'FEVER_ONSET',
    'clinical',
    'When did the fever begin?',
    'date',
    20,
    true
),
(
    'COUGH_SEVERITY',
    'clinical',
    'How severe is the cough?',
    'single_choice',
    20,
    true
),
(
    'DYSPNOEA_PRESENT',
    'clinical',
    'Is there shortness of breath or difficulty breathing?',
    'boolean',
    10,
    true
)
ON CONFLICT (question_code) DO NOTHING;


-- Re-run trigger creation after ensuring questions exist.
INSERT INTO knowledge.question_trigger (
    question_id,
    trigger_type,
    trigger_code,
    priority
)
SELECT
    q.id,
    v.trigger_type,
    v.trigger_code,
    v.priority
FROM (
    VALUES
    ('CHEST_PAIN_PRESENT', 'symptom', 'SYM-CHEST-PAIN', 10),
    ('FEVER_PRESENT', 'symptom', 'SYM-FEVER', 10),
    ('FEVER_ONSET', 'symptom', 'SYM-FEVER', 20),
    ('COUGH_SEVERITY', 'symptom', 'SYM-COUGH', 20),
    ('DYSPNOEA_PRESENT', 'symptom', 'SYM-DYSPNOEA', 10)
) AS v(question_code, trigger_type, trigger_code, priority)
JOIN knowledge.question q
    ON q.question_code = v.question_code
ON CONFLICT (question_id, trigger_type, trigger_code, activation_mode) DO NOTHING;


-- =============================================================================
-- 9. ANSWER OPTIONS
-- =============================================================================

INSERT INTO knowledge.answer_option (
    question_id,
    answer_code,
    label,
    value_text,
    sort_order,
    is_active
)
SELECT
    q.id,
    v.answer_code,
    v.label,
    v.value_text,
    v.sort_order,
    true
FROM (
    VALUES
    ('CHEST_PAIN_PRESENT', 'YES', 'Yes', 'true', 1),
    ('CHEST_PAIN_PRESENT', 'NO', 'No', 'false', 2),
    ('CHEST_PAIN_PRESENT', 'UNKNOWN', 'Unable to determine', 'unknown', 3),

    ('FEVER_PRESENT', 'YES', 'Yes', 'true', 1),
    ('FEVER_PRESENT', 'NO', 'No', 'false', 2),
    ('FEVER_PRESENT', 'UNKNOWN', 'Unable to determine', 'unknown', 3),

    ('COUGH_SEVERITY', 'MILD', 'Mild', 'mild', 1),
    ('COUGH_SEVERITY', 'MODERATE', 'Moderate', 'moderate', 2),
    ('COUGH_SEVERITY', 'SEVERE', 'Severe', 'severe', 3),
    ('COUGH_SEVERITY', 'UNKNOWN', 'Unable to determine', 'unknown', 4),

    ('DYSPNOEA_PRESENT', 'YES', 'Yes', 'true', 1),
    ('DYSPNOEA_PRESENT', 'NO', 'No', 'false', 2),
    ('DYSPNOEA_PRESENT', 'UNKNOWN', 'Unable to determine', 'unknown', 3)
) AS v(
    question_code,
    answer_code,
    label,
    value_text,
    sort_order
)
JOIN knowledge.question q
    ON q.question_code = v.question_code
ON CONFLICT (question_id, answer_code) DO NOTHING;


-- =============================================================================
-- 10. UNIVERSAL FACTS REQUIRED BY THE QUESTIONS
-- =============================================================================
-- clinical.fact_definition is Phase 1 infrastructure.
-- Only create facts when they do not already exist.
-- =============================================================================

INSERT INTO clinical.fact_definition (
    code,
    name,
    description,
    data_type
)
VALUES
(
    'CHEST_PAIN_PRESENT',
    'Chest pain present',
    'Whether chest pain or chest discomfort is present.',
    'boolean'
),
(
    'FEVER_PRESENT',
    'Fever present',
    'Whether fever or a history of fever is present.',
    'boolean'
),
(
    'COUGH_SEVERITY',
    'Cough severity',
    'Structured severity of cough.',
    'coded'
),
(
    'DYSPNOEA_PRESENT',
    'Dyspnoea present',
    'Whether shortness of breath or difficulty breathing is present.',
    'boolean'
)
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 11. ANSWER -> FACT MAPPINGS
-- =============================================================================
-- The CPU receives facts, not UI answers.
-- =============================================================================

INSERT INTO knowledge.fact_mapping (
    answer_option_id,
    fact_definition_code,
    value,
    is_active
)
SELECT
    ao.id,
    v.fact_definition_code,
    v.value,
    true
FROM (
    VALUES
    ('CHEST_PAIN_PRESENT', 'YES', 'CHEST_PAIN_PRESENT', 'true'),
    ('CHEST_PAIN_PRESENT', 'NO', 'CHEST_PAIN_PRESENT', 'false'),
    ('CHEST_PAIN_PRESENT', 'UNKNOWN', 'CHEST_PAIN_PRESENT', 'unknown'),

    ('FEVER_PRESENT', 'YES', 'FEVER_PRESENT', 'true'),
    ('FEVER_PRESENT', 'NO', 'FEVER_PRESENT', 'false'),
    ('FEVER_PRESENT', 'UNKNOWN', 'FEVER_PRESENT', 'unknown'),

    ('COUGH_SEVERITY', 'MILD', 'COUGH_SEVERITY', 'mild'),
    ('COUGH_SEVERITY', 'MODERATE', 'COUGH_SEVERITY', 'moderate'),
    ('COUGH_SEVERITY', 'SEVERE', 'COUGH_SEVERITY', 'severe'),
    ('COUGH_SEVERITY', 'UNKNOWN', 'COUGH_SEVERITY', 'unknown'),

    ('DYSPNOEA_PRESENT', 'YES', 'DYSPNOEA_PRESENT', 'true'),
    ('DYSPNOEA_PRESENT', 'NO', 'DYSPNOEA_PRESENT', 'false'),
    ('DYSPNOEA_PRESENT', 'UNKNOWN', 'DYSPNOEA_PRESENT', 'unknown')
) AS v(
    question_code,
    answer_code,
    fact_definition_code,
    value
)
JOIN knowledge.question q
    ON q.question_code = v.question_code
JOIN knowledge.answer_option ao
    ON ao.question_id = q.id
   AND ao.answer_code = v.answer_code
ON CONFLICT (answer_option_id, fact_definition_code, value) DO UPDATE
SET
    is_active = true;


-- =============================================================================
-- 12. UNIVERSAL RELATIONSHIPS FOR THE GATES
-- =============================================================================

INSERT INTO knowledge.relationship (
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    version,
    is_active
)
SELECT
    'question',
    q.id,
    'asks',
    'concept',
    c.id,
    1.0,
    'positive',
    1.0,
    '019',
    true
FROM (
    VALUES
    ('CHEST_PAIN_PRESENT', 'CNS-CHEST-PAIN'),
    ('FEVER_PRESENT', 'CNS-FEVER'),
    ('FEVER_ONSET', 'CNS-FEVER'),
    ('COUGH_SEVERITY', 'CNS-COUGH'),
    ('DYSPNOEA_PRESENT', 'CNS-DYSPNOEA')
) AS v(question_code, concept_code)
JOIN knowledge.question q
    ON q.question_code = v.question_code
JOIN knowledge.concept c
    ON c.concept_code = v.concept_code
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. UNIVERSAL SYMPTOM RED FLAGS
-- =============================================================================
-- These are activation primitives, not diagnoses.
-- They allow the CPU to elevate safety before disease classification.
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag (
    symptom_id,
    red_flag_code,
    description,
    urgency
)
SELECT
    s.id,
    v.red_flag_code,
    v.description,
    v.urgency
FROM (
    VALUES
    (
        'SYM-DYSPNOEA',
        'RF-SEVERE-BREATHING-DIFFICULTY',
        'Severe or rapidly worsening difficulty breathing requires immediate clinical assessment.',
        'emergency'
    ),
    (
        'SYM-CHEST-PAIN',
        'RF-SEVERE-CHEST-PAIN',
        'Severe, acute or concerning chest pain requires immediate clinical assessment.',
        'emergency'
    )
) AS v(
    symptom_code,
    red_flag_code,
    description,
    urgency
)
JOIN knowledge.symptom s
    ON s.symptom_code = v.symptom_code
ON CONFLICT (symptom_id, red_flag_code) DO NOTHING;


-- =============================================================================
-- 14. UNIVERSAL CONCEPT -> SYSTEM ATTACHMENTS
-- =============================================================================
-- Uses the universal concept junction introduced in Migration 012.
-- =============================================================================

INSERT INTO knowledge.concept_system (
    concept_id,
    body_system_code,
    relevance,
    weight
)
SELECT
    c.id,
    v.body_system_code,
    v.relevance,
    v.weight
FROM (
    VALUES
    ('CNS-COUGH', 'RESPIRATORY', 'primary', 1.00::numeric),
    ('CNS-COUGH', 'CARDIOVASCULAR', 'secondary', 0.60::numeric),
    ('CNS-COUGH', 'GASTROINTESTINAL', 'secondary', 0.40::numeric),
    ('CNS-COUGH', 'ENT', 'related', 0.80::numeric),

    ('CNS-FEVER', 'SYSTEMIC', 'primary', 1.00::numeric),
    ('CNS-FEVER', 'RESPIRATORY', 'secondary', 0.80::numeric),
    ('CNS-FEVER', 'GENITOURINARY', 'secondary', 0.60::numeric),
    ('CNS-FEVER', 'GASTROINTESTINAL', 'secondary', 0.60::numeric),
    ('CNS-FEVER', 'NEUROLOGICAL', 'related', 0.50::numeric),

    ('CNS-CHEST-PAIN', 'CARDIOVASCULAR', 'primary', 1.00::numeric),
    ('CNS-CHEST-PAIN', 'RESPIRATORY', 'primary', 1.00::numeric),
    ('CNS-CHEST-PAIN', 'MUSCULOSKELETAL', 'secondary', 0.80::numeric),
    ('CNS-CHEST-PAIN', 'GASTROINTESTINAL', 'secondary', 0.60::numeric),

    ('CNS-DYSPNOEA', 'RESPIRATORY', 'primary', 1.00::numeric),
    ('CNS-DYSPNOEA', 'CARDIOVASCULAR', 'primary', 1.00::numeric),
    ('CNS-DYSPNOEA', 'SYSTEMIC', 'secondary', 0.50::numeric),
    ('CNS-DYSPNOEA', 'NEUROLOGICAL', 'related', 0.40::numeric)
) AS v(
    concept_code,
    body_system_code,
    relevance,
    weight
)
JOIN knowledge.concept c
    ON c.concept_code = v.concept_code
ON CONFLICT (concept_id, body_system_code) DO UPDATE
SET
    relevance = EXCLUDED.relevance,
    weight = EXCLUDED.weight;


-- =============================================================================
-- 15. NORMALIZED TRIGGER RESOLUTION
-- =============================================================================
-- Existing applications may have stored:
--
--     cough
--     SYM-COUGH
--     CNS-COUGH
--
-- The CPU should resolve all three to the same universal symptom/concept.
--
-- This view gives the runtime one normalized lookup surface.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.question_trigger_resolved AS
SELECT
    qt.id,
    qt.question_id,
    q.question_code,
    qt.trigger_type,
    qt.trigger_code,
    qt.priority,

    CASE
        WHEN qt.trigger_type = 'symptom'
             AND s.id IS NOT NULL
            THEN s.id
        WHEN qt.trigger_type = 'symptom'
             AND c.id IS NOT NULL
            THEN s2.id
        ELSE NULL
    END AS symptom_id,

    CASE
        WHEN qt.trigger_type = 'symptom'
             AND s.id IS NOT NULL
            THEN s.concept_id
        WHEN qt.trigger_type = 'symptom'
             AND c.id IS NOT NULL
            THEN c.id
        ELSE NULL
    END AS concept_id

FROM knowledge.question_trigger qt
JOIN knowledge.question q
    ON q.id = qt.question_id

LEFT JOIN knowledge.symptom s
    ON qt.trigger_type = 'symptom'
   AND (
       upper(qt.trigger_code) = upper(s.symptom_code)
       OR lower(qt.trigger_code) = lower(s.canonical_name)
   )

LEFT JOIN knowledge.concept c
    ON qt.trigger_type = 'symptom'
   AND (
       upper(qt.trigger_code) = upper(c.concept_code)
       OR lower(qt.trigger_code) = lower(c.canonical_name)
   )

LEFT JOIN knowledge.symptom s2
    ON s2.concept_id = c.id
   AND qt.trigger_type = 'symptom';


COMMENT ON VIEW knowledge.question_trigger_resolved IS
'CPU-facing normalized question trigger surface. Different representations of
the same clinical symptom resolve toward one universal concept/symptom node.';


-- =============================================================================
-- 16. CPU QUESTION ACTIVATION VIEW
-- =============================================================================
-- High-speed read surface.
--
-- The CPU can retrieve candidate questions using:
--
--   trigger_type + normalized trigger
--
-- without traversing the complete graph for every question.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.cpu_question_activation AS
SELECT DISTINCT
    q.id AS question_id,
    q.question_code,
    q.question_type,
    q.text,
    q.response_type,
    q.priority AS question_priority,

    qt.trigger_type,
    qt.trigger_code,
    qt.priority AS trigger_priority,

    COALESCE(qt.priority, 0)
        + COALESCE(q.priority, 0) AS activation_priority

FROM knowledge.question q
JOIN knowledge.question_trigger qt
    ON qt.question_id = q.id

WHERE q.is_active = true;


COMMENT ON VIEW knowledge.cpu_question_activation IS
'Fast CPU activation surface for adaptive clinical interviewing.';


-- =============================================================================
-- 17. UNIVERSAL KNOWLEDGE VERSION
-- =============================================================================
-- Gives the runtime a deterministic knowledge release identifier.
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.knowledge_release CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.knowledge_release (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    release_code      text NOT NULL UNIQUE,
    version_label     text NOT NULL,
    description       text,
    status            text NOT NULL DEFAULT 'active'
                      CHECK (status IN ('draft','active','superseded','retired')),
    released_at       timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.knowledge_release IS
'Immutable-ish release identity for the universal AMEXAN knowledge substrate.
CPU decisions record the release used so reasoning is reproducible.';


INSERT INTO knowledge.knowledge_release (
    release_code,
    version_label,
    description,
    status,
    released_at
)
VALUES (
    'AMEXAN-KNOWLEDGE-019',
    'Phase-3-019',
    'Universal clinical knowledge activation hardening and adaptive interview seed release.',
    'active',
    now()
)
ON CONFLICT (release_code) DO NOTHING;


-- =============================================================================
-- 18. KNOWLEDGE HEALTH CHECK
-- =============================================================================
-- Materialized runtime diagnostic information is intentionally NOT created.
-- The following view is cheap and lets the CPU/administration layer identify
-- incomplete knowledge without modifying the source knowledge.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.knowledge_health AS
SELECT
    q.question_code,

    CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM knowledge.question_trigger qt
            WHERE qt.question_id = q.id
        )
        THEN 'MISSING_TRIGGER'

        WHEN NOT EXISTS (
            SELECT 1
            FROM knowledge.answer_option ao
            WHERE ao.question_id = q.id
              AND ao.is_active = true
        )
        THEN 'MISSING_ANSWERS'

        WHEN q.response_type IN ('boolean','single_choice','multiple_choice')
             AND NOT EXISTS (
                 SELECT 1
                 FROM knowledge.answer_option ao
                 WHERE ao.question_id = q.id
                   AND ao.is_active = true
             )
        THEN 'MISSING_FACT_PATH'

        ELSE 'READY'
    END AS readiness

FROM knowledge.question q
WHERE q.is_active = true;


COMMENT ON VIEW knowledge.knowledge_health IS
'Runtime knowledge completeness surface. READY means the question has an
activation path and active structured answer path; clinical correctness still
requires knowledge governance and evidence review.';


-- =============================================================================
-- 19. CPU-SAFE QUESTION CANDIDATE INDEX
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_question_trigger_fast
ON knowledge.question_trigger (
    trigger_type,
    lower(trigger_code),
    priority DESC,
    question_id
);


-- =============================================================================
-- 20. UNIVERSAL RELATIONSHIP INTEGRITY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_relationship_source_active
ON knowledge.relationship (
    source_type,
    source_id,
    is_active,
    relationship_type
);

CREATE INDEX IF NOT EXISTS idx_knowledge_relationship_target_active
ON knowledge.relationship (
    target_type,
    target_id,
    is_active,
    relationship_type
);


-- =============================================================================
-- 21. OVERRIDE RUNTIME INDEX
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_override_runtime
ON knowledge.knowledge_override (
    target_type,
    target_id,
    status,
    effective_from,
    effective_to,
    scope_code,
    version DESC
);


-- =============================================================================
-- 22. CPU EVENT/DECISION RUNTIME INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_cpu_event_runtime
ON cpu.event_log (
    patient_id,
    encounter_id,
    occurred_at DESC
);

CREATE INDEX IF NOT EXISTS idx_cpu_decision_runtime
ON cpu.decision (
    patient_id,
    encounter_id,
    status,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_cpu_snapshot_runtime
ON cpu.state_snapshot (
    patient_id,
    encounter_id,
    created_at DESC
);


-- =============================================================================
-- 23. KNOWLEDGE GRAPH CPU ENTRY POINT
-- =============================================================================
-- This function deliberately performs NO diagnosis.
--
-- It returns candidate questions from a presenting trigger.
--
-- The actual CPU can subsequently:
--
--   1. acquire facts
--   2. update PatientClinicalState
--   3. activate further questions
--   4. calculate phenotype support
--   5. evaluate mechanisms
--   6. rank differentials
--   7. activate investigations
--   8. evaluate safety rules
--   9. activate protocols
--  10. generate recommendations
--
-- PostgreSQL therefore serves as a high-speed indexed knowledge substrate;
-- the clinical CPU remains the reasoning executor.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.get_question_candidates(
    p_trigger_type text,
    p_trigger_code text
)
RETURNS TABLE (
    question_id uuid,
    question_code text,
    question_type text,
    question_text text,
    response_type text,
    question_priority integer,
    trigger_priority integer,
    activation_priority integer
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        q.id,
        q.question_code,
        q.question_type,
        q.text,
        q.response_type,
        q.priority,
        qt.priority,
        q.priority + qt.priority
    FROM knowledge.question q
    JOIN knowledge.question_trigger qt
        ON qt.question_id = q.id
    WHERE q.is_active = true
      AND qt.trigger_type = p_trigger_type
      AND (
          lower(qt.trigger_code) = lower(p_trigger_code)
          OR EXISTS (
              SELECT 1
              FROM knowledge.symptom s
              WHERE qt.trigger_type = 'symptom'
                AND (
                    lower(s.symptom_code) = lower(qt.trigger_code)
                    OR lower(s.canonical_name) = lower(qt.trigger_code)
                )
                AND (
                    lower(s.symptom_code) = lower(p_trigger_code)
                    OR lower(s.canonical_name) = lower(p_trigger_code)
                )
          )
      )
    ORDER BY
        q.priority DESC,
        qt.priority DESC,
        q.id;
$$;


COMMENT ON FUNCTION knowledge.get_question_candidates(text, text) IS
'Fast universal adaptive-interview entry point. Resolves equivalent symptom
representations and returns candidate questions without performing diagnosis.';


-- =============================================================================
-- 24. RELEASE METADATA
-- =============================================================================

COMMENT ON TABLE knowledge.question_trigger IS
'Universal activation edges. Every adaptive clinical question must have an
activation pathway from a symptom, phenotype, risk factor, mechanism, condition,
complication, context or fact.';

COMMENT ON TABLE knowledge.fact_mapping IS
'Universal answer-to-fact translation layer. Clinical reasoning consumes facts,
not presentation labels.';

COMMENT ON TABLE knowledge.relationship IS
'Universal clinical knowledge graph edge table. Typed relationships connect
concepts, symptoms, questions, answers, facts, phenotypes, mechanisms,
conditions and other reusable medical primitives.';


-- =============================================================================
-- 25. FINAL VALIDATION
-- =============================================================================

DO $$
DECLARE
    missing_trigger_count integer;
BEGIN

    SELECT count(*)
    INTO missing_trigger_count
    FROM knowledge.question q
    WHERE q.is_active = true
      AND q.question_code IN (
          'CHEST_PAIN_PRESENT',
          'FEVER_PRESENT',
          'FEVER_ONSET',
          'COUGH_SEVERITY',
          'DYSPNOEA_PRESENT'
      )
      AND NOT EXISTS (
          SELECT 1
          FROM knowledge.question_trigger qt
          WHERE qt.question_id = q.id
      );

    IF missing_trigger_count > 0 THEN
        RAISE EXCEPTION
            'AMEXAN knowledge validation failed: % gate questions have no trigger.',
            missing_trigger_count;
    END IF;

END
$$;


COMMIT;


-- =============================================================================
-- AMEXAN PHASE 3 / MIGRATION 019 COMPLETE
-- =============================================================================
--
-- Runtime architecture after this migration:
--
-- PRESENTING SYMPTOM
--        |
--        v
-- UNIVERSAL CONCEPT
--        |
--        +----> BODY SYSTEMS
--        |
--        +----> SPECIALTIES
--        |
--        +----> RED FLAGS
--        |
--        +----> QUESTION TRIGGERS
--                    |
--                    v
--               QUESTIONS
--                    |
--                    v
--             ANSWER OPTIONS
--                    |
--                    v
--                  FACTS
--                    |
--          +---------+---------+
--          |                   |
--          v                   v
--      PHENOTYPES          CONTEXT
--          |                   |
--          v                   v
--      MECHANISMS <------> RULES
--          |
--          v
--     DIFFERENTIALS
--          |
--          v
--   INVESTIGATIONS
--          |
--          v
--     RESULT FACTS
--          |
--          v
--     RE-EVALUATION
--          |
--          v
--      PROTOCOLS
--          |
--     +----+----+----------------+
--     |         |                |
--     v         v                v
-- TREATMENT  MONITORING      EDUCATION
--     |
--     v
-- ESCALATION / DISPOSITION / FOLLOW-UP
--
-- The same universal substrate is therefore usable across medicine,
-- surgery, paediatrics, OBGYN, emergency medicine, psychiatry, ENT,
-- ophthalmology, dermatology, oncology, anaesthesia, critical care,
-- radiology, pathology, primary care and other specialties without creating
-- separate disease engines.
-- =============================================================================
