-- =============================================================================
-- AMEXAN Universal Symptom Engine — Migration 024
-- FULL CLINICAL DOCUMENTATION NARRATIVE ORDER
-- =============================================================================
-- Purpose
-- -------
-- Makes symptom documentation a first-class, machine-assembled clinical
-- narrative rather than a collection of disconnected phrases.
--
-- The DocumentationEngine uses:
--
--   captured clinical facts
--        ↓
--   symptom_hpi_template
--        ↓
--   documentation_group
--        ↓
--   clinical narrative ordering
--        ↓
--   HPI / examination / assessment documentation
--
-- The engine MUST document what is known without inventing facts, diagnoses,
-- causality, chronology, severity or clinical conclusions that were not
-- captured.
--
-- UNIVERSAL NARRATIVE ORDER
-- -------------------------
--
--   01 presenting
--   02 chronology
--   03 character
--   04 sputum
--   05 associated
--   06 systemic
--   07 ent_gi
--   08 risk
--   09 previous
--   10 health_seeking
--   11 severity
--   12 functional
--   13 examination
--
-- This ordering is reusable across symptoms and specialties.
-- It is NOT a disease-specific template.
--
-- Example:
--
--   "The patient reports a cough which started 4 days prior to presentation.
--    The cough was initially dry and subsequently became productive of
--    yellowish sputum. It is associated with fever and shortness of breath.
--    There is no history of haemoptysis. The patient reports reduced exercise
--    tolerance. He has not previously experienced similar symptoms. He sought
--    treatment at a local facility and received medication with partial
--    improvement."
--
-- The actual wording is generated ONLY from captured facts.
-- =============================================================================


-- =============================================================================
-- 1. ENSURE DOCUMENTATION GROUP EXISTS
-- =============================================================================
-- Earlier symptom-engine versions may already contain this column. This keeps
-- the migration safe when upgrading an existing AMEXAN installation.

ALTER TABLE knowledge.symptom_hpi_template
    ADD COLUMN IF NOT EXISTS documentation_group text;


-- =============================================================================
-- 2. DEFAULT LEGACY ROWS TO A SAFE DOCUMENTATION GROUP
-- =============================================================================
-- Existing templates created before migration 024 may have NULL groups.
-- They remain usable and are placed in the general history/presenting bucket
-- until explicitly classified.

UPDATE knowledge.symptom_hpi_template
SET documentation_group = 'presenting'
WHERE documentation_group IS NULL;


ALTER TABLE knowledge.symptom_hpi_template
    ALTER COLUMN documentation_group SET DEFAULT 'presenting';


ALTER TABLE knowledge.symptom_hpi_template
    ALTER COLUMN documentation_group SET NOT NULL;


-- =============================================================================
-- 3. REMOVE OLD / INCOMPLETE GROUP CONSTRAINT
-- =============================================================================

ALTER TABLE knowledge.symptom_hpi_template
    DROP CONSTRAINT IF EXISTS symptom_hpi_template_documentation_group_check;


-- =============================================================================
-- 4. UNIVERSAL CLINICAL DOCUMENTATION VOCABULARY
-- =============================================================================
-- The ordering is deliberately encoded here so every client, API and
-- DocumentationEngine can obtain exactly the same canonical narrative order.

ALTER TABLE knowledge.symptom_hpi_template
    ADD CONSTRAINT symptom_hpi_template_documentation_group_check
    CHECK (
        documentation_group IN (
            'presenting',
            'chronology',
            'character',
            'sputum',
            'associated',
            'systemic',
            'ent_gi',
            'risk',
            'previous',
            'health_seeking',
            'severity',
            'functional',
            'examination'
        )
    );


-- =============================================================================
-- 5. CANONICAL DOCUMENTATION ORDER
-- =============================================================================
-- Database-level helper function.
--
-- Lower number = earlier in the final clinical narrative.
--
-- This prevents different UI/API implementations from inventing their own
-- ordering.

CREATE OR REPLACE FUNCTION knowledge.documentation_group_order(
    p_group text
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
STRICT
AS $$
    SELECT CASE p_group
        WHEN 'presenting'     THEN 10
        WHEN 'chronology'     THEN 20
        WHEN 'character'      THEN 30
        WHEN 'sputum'         THEN 40
        WHEN 'associated'     THEN 50
        WHEN 'systemic'       THEN 60
        WHEN 'ent_gi'         THEN 70
        WHEN 'risk'           THEN 80
        WHEN 'previous'       THEN 90
        WHEN 'health_seeking' THEN 100
        WHEN 'severity'       THEN 110
        WHEN 'functional'     THEN 120
        WHEN 'examination'    THEN 130
        ELSE 999
    END;
$$;

COMMENT ON FUNCTION knowledge.documentation_group_order(text) IS
'Canonical AMEXAN clinical narrative ordering for symptom documentation.';


-- =============================================================================
-- 6. DOCUMENTATION GROUP METADATA
-- =============================================================================
-- A machine-readable vocabulary makes the documentation architecture itself
-- discoverable by the UI, API, documentation engine and future AI services.

CREATE TABLE IF NOT EXISTS knowledge.documentation_group (
    code                text PRIMARY KEY,
    canonical_name      text NOT NULL,
    description         text NOT NULL,
    narrative_order     integer NOT NULL UNIQUE,
    clinical_purpose    text NOT NULL,
    typical_questioning text,
    documentation_rule  text,
    is_hpi              boolean NOT NULL DEFAULT true,
    is_examination      boolean NOT NULL DEFAULT false,
    is_active           boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.documentation_group IS
'Universal AMEXAN clinical documentation groups controlling narrative assembly.';


INSERT INTO knowledge.documentation_group (
    code,
    canonical_name,
    description,
    narrative_order,
    clinical_purpose,
    typical_questioning,
    documentation_rule,
    is_hpi,
    is_examination
)
VALUES

(
    'presenting',
    'Presenting Complaint',
    'The symptom or clinical problem bringing the patient for care.',
    10,
    'Establish exactly what the patient is presenting with.',
    'What is the main symptom/problem? When did it begin?',
    'State the presenting symptom using the captured clinical terminology without adding interpretation.',
    true,
    false
),

(
    'chronology',
    'Chronology',
    'Temporal development of the complaint from baseline through presentation.',
    20,
    'Establish onset, sequence, duration, progression and temporal relationships.',
    'When did it start? What happened first? What developed subsequently? Has it changed over time?',
    'Preserve the captured sequence and temporal relationships. Never infer an onset or sequence that was not documented.',
    true,
    false
),

(
    'character',
    'Character',
    'Qualitative characteristics of the presenting symptom.',
    30,
    'Characterize the symptom using symptom-specific clinical descriptors.',
    'What is it like? What is its quality, nature, site, distribution, radiation or pattern?',
    'Use only characteristics actually obtained for the symptom.',
    true,
    false
),

(
    'sputum',
    'Sputum / Respiratory Secretions',
    'Characteristics of sputum or respiratory secretions when relevant.',
    40,
    'Describe production, quantity, colour, consistency, odour and associated features.',
    'Is there sputum? What colour? How much? What consistency? Any blood?',
    'Include only when sputum or respiratory secretion information has been captured.',
    true,
    false
),

(
    'associated',
    'Associated Symptoms',
    'Symptoms occurring together with the presenting complaint.',
    50,
    'Expand the symptom into relevant positive and negative associated features.',
    'What other symptoms occur with it? Which relevant symptoms are absent?',
    'Document captured positives and clinically relevant documented negatives without inventing exclusions.',
    true,
    false
),

(
    'systemic',
    'Systemic Symptoms',
    'Constitutional or multisystem manifestations relevant to the complaint.',
    60,
    'Capture fever, chills, rigors, weight change, appetite change, malaise, fatigue and other systemic manifestations where relevant.',
    'Any fever, chills, night sweats, weight change, appetite change, fatigue or malaise?',
    'Do not convert a reported systemic symptom into an etiological conclusion.',
    true,
    false
),

(
    'ent_gi',
    'ENT / Gastrointestinal / Cross-System Review',
    'Relevant ENT, gastrointestinal and other cross-system symptoms that may clarify the presenting complaint.',
    70,
    'Explore anatomical and physiological systems that may mimic, contribute to or accompany the presenting complaint.',
    'Any nasal, throat, ear, swallowing, reflux, nausea, vomiting, abdominal or bowel symptoms?',
    'Include only systems relevant to the active symptom and captured in the encounter.',
    true,
    false
),

(
    'risk',
    'Risk Factors and Relevant Exposures',
    'Patient factors, exposures and contexts that alter the clinical relevance of the symptom.',
    80,
    'Identify epidemiological, environmental, behavioural, occupational, medication, travel, contact and host risk factors.',
    'Any relevant exposures, contacts, smoking, occupation, travel, medications, immunosuppression or environmental risks?',
    'Document the risk factor as a fact. Do not infer the disease it might imply.',
    true,
    false
),

(
    'previous',
    'Previous Episodes / Previous Evaluation',
    'Whether the complaint has occurred before and what happened previously.',
    90,
    'Distinguish first presentations from recurrent or previously evaluated complaints.',
    'Has this happened before? Was there a previous diagnosis? Previous treatment? Previous investigations? What was the response?',
    'Document prior events and responses as historical facts. Do not assume the current episode is the same condition.',
    true,
    false
),

(
    'health_seeking',
    'Health-Seeking and Treatment History',
    'Care sought before the current encounter and actions taken by the patient or others.',
    100,
    'Establish previous consultation, self-medication, prescribed treatment, adherence, response and reason for current presentation.',
    'Have you sought care? Where? What treatment was given or taken? Did it help? Why are you presenting now?',
    'Document actual treatment and response. Never fabricate medication, adherence or response.',
    true,
    false
),

(
    'severity',
    'Severity, Progression and Red Flags',
    'Features describing severity, deterioration, complications and urgent warning features.',
    110,
    'Determine clinical severity and identify features requiring urgent escalation.',
    'Is it worsening? How severe is it? Any severe pain, inability to function, altered consciousness, bleeding, respiratory distress or other relevant danger signs?',
    'Severity must be supported by captured symptoms, measurements, signs or clinician assessment.',
    true,
    false
),

(
    'functional',
    'Functional Impact',
    'Effect of the complaint on activities, mobility, feeding, sleep, work, school, exercise and other patient functions.',
    120,
    'Quantify the real-world effect of the illness on the patient.',
    'What can the patient no longer do? Has sleep, feeding, work, school, mobility or exercise been affected?',
    'Describe functional consequences without converting them into severity diagnoses unless explicitly established.',
    true,
    false
),

(
    'examination',
    'Examination Findings',
    'Objective findings obtained during physical examination and bedside assessment.',
    130,
    'Integrate examination findings with the same clinical fact substrate used by history.',
    'What objective signs and measurements were found?',
    'Document observed or measured findings only. Examination documentation must not be fabricated from the history.',
    false,
    true
)

ON CONFLICT (code) DO UPDATE
SET
    canonical_name      = EXCLUDED.canonical_name,
    description         = EXCLUDED.description,
    narrative_order     = EXCLUDED.narrative_order,
    clinical_purpose    = EXCLUDED.clinical_purpose,
    typical_questioning = EXCLUDED.typical_questioning,
    documentation_rule  = EXCLUDED.documentation_rule,
    is_hpi              = EXCLUDED.is_hpi,
    is_examination      = EXCLUDED.is_examination,
    is_active           = EXCLUDED.is_active;


-- =============================================================================
-- 7. LINK SYMPTOM HPI TEMPLATES TO THE CANONICAL GROUP VOCABULARY
-- =============================================================================
-- Foreign-key enforcement prevents misspelled documentation groups from
-- silently entering the clinical documentation layer.

ALTER TABLE knowledge.symptom_hpi_template
    DROP CONSTRAINT IF EXISTS fk_symptom_hpi_template_documentation_group;

ALTER TABLE knowledge.symptom_hpi_template
    ADD CONSTRAINT fk_symptom_hpi_template_documentation_group
    FOREIGN KEY (documentation_group)
    REFERENCES knowledge.documentation_group(code);


-- =============================================================================
-- 8. INDEXES FOR HIGH-SPEED DOCUMENTATION RESOLUTION
-- =============================================================================
-- The DocumentationEngine will frequently query:
--
--   symptom + section + group + fact + value
--
-- These indexes keep the clinical narrative assembly path small and selective.

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_symptom_group
ON knowledge.symptom_hpi_template (
    symptom_id,
    documentation_group,
    sort_order
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_fact
ON knowledge.symptom_hpi_template (
    fact_definition_code,
    documentation_group
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_active
ON knowledge.symptom_hpi_template (
    symptom_id,
    is_active,
    documentation_group
);

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_language
ON knowledge.symptom_hpi_template (
    symptom_id,
    language_code,
    documentation_group
);


-- =============================================================================
-- 9. FAST DOCUMENTATION RESOLUTION VIEW
-- =============================================================================
-- Provides the DocumentationEngine with the canonical ordering already
-- resolved by the database.
--
-- The engine can therefore:
--
--   SELECT ...
--   FROM knowledge.symptom_hpi_documentation
--   WHERE symptom_id = ?
--   ORDER BY narrative_order, sort_order;
--
-- No frontend should independently reconstruct the clinical order.

CREATE OR REPLACE VIEW knowledge.symptom_hpi_documentation AS
SELECT
    t.id,
    t.symptom_id,
    t.section,
    t.documentation_group,
    g.canonical_name AS documentation_group_name,
    g.narrative_order,
    t.fact_definition_code,
    t.fact_value,
    t.phrase_template,
    t.sort_order,
    t.language_code,
    t.is_active,
    t.supersedes_fact_code
FROM knowledge.symptom_hpi_template t
JOIN knowledge.documentation_group g
  ON g.code = t.documentation_group
WHERE t.is_active = true
  AND g.is_active = true;


COMMENT ON VIEW knowledge.symptom_hpi_documentation IS
'Canonical AMEXAN symptom documentation source ordered by universal clinical narrative group.';


-- =============================================================================
-- 10. DOCUMENTATION GROUP ORDERING FUNCTION FOR RUNTIME USE
-- =============================================================================
-- Returns the complete canonical order as a JSON object.
-- Useful for UI/API initialization without hardcoding medical narrative order
-- in multiple clients.

CREATE OR REPLACE FUNCTION knowledge.documentation_group_catalog()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'code', code,
                'name', canonical_name,
                'order', narrative_order,
                'description', description,
                'clinicalPurpose', clinical_purpose,
                'isHPI', is_hpi,
                'isExamination', is_examination
            )
            ORDER BY narrative_order
        ),
        '[]'::jsonb
    )
    FROM knowledge.documentation_group
    WHERE is_active = true;
$$;


-- =============================================================================
-- 11. DOCUMENTATION SAFETY: DO NOT DOCUMENT ABSENT UNKNOWN FACTS
-- =============================================================================
-- This metadata explicitly tells the documentation layer that templates are
-- rendering rules, NOT generators of clinical facts.
--
-- A phrase template is eligible only when its corresponding fact is actually
-- present in the encounter's clinical fact substrate.
--
-- This is intentionally metadata rather than executable clinical reasoning.

COMMENT ON COLUMN knowledge.symptom_hpi_template.phrase_template IS
'Documentation-only phrase template. May contain {value}; must render only when its bound clinical fact/value is actually captured. Must never create or infer a clinical fact.';


COMMENT ON COLUMN knowledge.symptom_hpi_template.fact_definition_code IS
'Clinical fact required for this documentation phrase. Documentation is generated from captured facts, never from the template alone.';


COMMENT ON COLUMN knowledge.symptom_hpi_template.fact_value IS
'Optional exact/coded value for conditional rendering. NULL means the template applies to any captured value of the bound fact.';


COMMENT ON COLUMN knowledge.symptom_hpi_template.sort_order IS
'Local ordering within the canonical documentation group. Lower values render first.';


-- =============================================================================
-- 12. SYMPTOM-SPECIFIC DOCUMENTATION GROUP INDEX
-- =============================================================================
-- Allows the runtime to quickly determine whether a symptom has documentation
-- coverage across the complete narrative.

CREATE INDEX IF NOT EXISTS idx_symptom_hpi_template_coverage
ON knowledge.symptom_hpi_template (
    symptom_id,
    section,
    documentation_group,
    is_active
);


-- =============================================================================
-- 13. COVERAGE VIEW
-- =============================================================================
-- Lets AMEXAN identify incomplete symptom documentation libraries.
--
-- A symptom does not need every group for every complaint; the view simply
-- exposes coverage so the Knowledge QA system can detect missing areas.

CREATE OR REPLACE VIEW knowledge.symptom_documentation_coverage AS
SELECT
    s.id AS symptom_id,
    s.symptom_code,
    g.code AS documentation_group,
    g.canonical_name AS documentation_group_name,
    g.narrative_order,
    EXISTS (
        SELECT 1
        FROM knowledge.symptom_hpi_template t
        WHERE t.symptom_id = s.id
          AND t.documentation_group = g.code
          AND t.is_active = true
    ) AS has_template
FROM knowledge.symptom s
CROSS JOIN knowledge.documentation_group g
WHERE g.is_active = true;


COMMENT ON VIEW knowledge.symptom_documentation_coverage IS
'Knowledge QA view showing whether each universal documentation group has active symptom templates.';


-- =============================================================================
-- 14. CLINICAL DOCUMENTATION ORDER GUARANTEE
-- =============================================================================
-- Defensive validation function. The documentation vocabulary must retain one
-- unique, contiguous narrative order. This prevents accidental insertion of
-- conflicting order values.

CREATE OR REPLACE FUNCTION knowledge.validate_documentation_group_order()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer;
    v_distinct_count integer;
    v_min integer;
    v_max integer;
BEGIN
    SELECT
        COUNT(*),
        COUNT(DISTINCT narrative_order),
        MIN(narrative_order),
        MAX(narrative_order)
    INTO
        v_count,
        v_distinct_count,
        v_min,
        v_max
    FROM knowledge.documentation_group
    WHERE is_active = true;

    IF v_count <> v_distinct_count THEN
        RAISE EXCEPTION
            'AMEXAN documentation group order violation: duplicate narrative_order detected';
    END IF;

    IF v_count <> 13 OR v_min <> 10 OR v_max <> 130 THEN
        RAISE EXCEPTION
            'AMEXAN documentation group vocabulary is incomplete or incorrectly ordered';
    END IF;
END;
$$;


-- =============================================================================
-- 15. FINAL VALIDATION
-- =============================================================================

SELECT knowledge.validate_documentation_group_order();


-- =============================================================================
-- 16. FINAL CANONICAL ORDER
-- =============================================================================
--
-- 10   PRESENTING
-- 20   CHRONOLOGY
-- 30   CHARACTER
-- 40   SPUTUM
-- 50   ASSOCIATED
-- 60   SYSTEMIC
-- 70   ENT / GI / CROSS-SYSTEM
-- 80   RISK
-- 90   PREVIOUS
-- 100  HEALTH-SEEKING
-- 110  SEVERITY
-- 120  FUNCTIONAL
-- 130  EXAMINATION
--
-- This becomes the universal AMEXAN documentation contract.
-- =============================================================================