-- =============================================================================
-- AMEXAN UNIVERSAL CLINICAL OPERATING SYSTEM
-- MIGRATION 047
-- =============================================================================
--
-- FILE:
--   047_clinical_rule_engine.sql
--
-- NAME:
--   AMEXAN Clinical Rule Engine â€” Universal Rule Graph & Execution Contract
--
-- PURPOSE:
--   Establish the persistent Clinical Rule Language (CRL) foundation used by
--   the CPU to determine:
--
--       WHEN  a rule applies
--       WHAT  clinical/workflow state it affects
--       WHY   the rule exists
--       HOW   the resulting action is represented
--
-- ARCHITECTURAL PRINCIPLE
-- -----------------------
--
--                 MEDICAL KNOWLEDGE
--                         â”‚
--                         â–¼
--                  KNOWLEDGE GRAPH
--                         â”‚
--                         â–¼
--                  CLINICAL RULES
--                         â”‚
--                         â–¼
--                         CPU / RULE ENGINE
--                         â”‚
--              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--              â–¼          â–¼          â–¼
--          QUESTIONS   EXAM PLAN   SAFETY
--              â”‚          â”‚          â”‚
--              â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                         â–¼
--                 CLINICAL CONTEXT
--                         â”‚
--                         â–¼
--                    REASONING
--                         â”‚
--                         â–¼
--                  DOCUMENTATION
--                         â”‚
--                         â–¼
--                         UI PROJECTION
--
-- IMPORTANT:
--   PostgreSQL stores rule definitions.
--   CPU executes rules.
--   UI does NOT determine clinical context.
--   UI does NOT infer diagnoses.
--   UI does NOT decide which clinical module applies.
--
-- RULE SAFETY PRINCIPLES
-- ----------------------
-- 1. Rules are deterministic configuration.
-- 2. Rules do not themselves become patient facts.
-- 3. Runtime execution creates rule-evaluation records.
-- 4. UNKNOWN is never silently converted to FALSE.
-- 5. NOT_ASSESSED is never silently converted to ABSENT.
-- 6. A rule may request information but may not fabricate it.
-- 7. A rule may expose a clinical possibility but may not silently create
--    a diagnosis.
-- 8. Medical knowledge and workflow behaviour remain separate.
-- 9. Every clinically consequential rule is versioned.
-- 10. Every executed rule is auditable.
-- 11. Rules may be disabled/retired without deleting historical execution.
-- 12. Rule conflicts are resolved explicitly and deterministically.
--
-- MEDICAL SCOPE OF THIS MIGRATION
-- -------------------------------
-- Universal:
--   identity / demographics
--   age
--   sex
--   encounter
--   disposition
--   history
--   examination
--   vital signs
--   paediatrics
--   pregnancy/OBGYN context
--   emergency/red-flag routing
--   surgery/local examination
--   respiratory
--   cardiovascular
--   neurological
--   gastrointestinal
--   genitourinary
--   musculoskeletal
--   dermatological
--   ENT/oral
--   geriatrics
--   documentation safety
--
-- This migration does NOT attempt to encode all disease knowledge.
-- Disease knowledge belongs in the Clinical Knowledge Graph.
--
-- PostgreSQL
-- Requires pgcrypto for UUID generation.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS knowledge;
CREATE SCHEMA IF NOT EXISTS clinical;

-- =============================================================================
-- 1. RULE CATEGORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.rule_category (
    code                    text PRIMARY KEY,
    label                   text NOT NULL,
    description             text NOT NULL,
    sort_order              integer NOT NULL DEFAULT 0,
    is_active               boolean NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE knowledge.rule_category IS
'AMEXAN Clinical Rule categories. Rules describe behaviour; medical facts remain in the knowledge graph.';

INSERT INTO knowledge.rule_category
(code, label, description, sort_order)
VALUES
('SYSTEM',
 'System Rule',
 'Global platform invariants that apply independently of a clinical specialty.',
 10),

('PATIENT_CONTEXT',
 'Patient Context',
 'Rules deriving age, sex, developmental and other structured patient contexts.',
 20),

('ENCOUNTER',
 'Encounter',
 'Rules governing encounter type, disposition, stage and workflow state.',
 30),

('HISTORY',
 'History',
 'Rules determining which history modules and questions apply.',
 40),

('EXAMINATION',
 'Examination',
 'Rules determining examination domains, concepts and focused examination.',
 50),

('VITAL',
 'Vital Sign',
 'Rules concerning vital-sign capture, validation and urgency classification.',
 60),

('PAEDIATRIC',
 'Paediatric',
 'Age-specific paediatric routing, measurements and examination behaviour.',
 70),

('OBSTETRIC',
 'Obstetric',
 'Pregnancy, antenatal, intrapartum and postpartum routing rules.',
 80),

('GYNAECOLOGICAL',
 'Gynaecological',
 'Menstrual and gynaecological history/examination routing.',
 90),

('SURGICAL',
 'Surgical',
 'Surgical/local examination routing and surgical safety behaviour.',
 100),

('RESPIRATORY',
 'Respiratory',
 'Respiratory-system examination and clinical workflow routing.',
 110),

('CARDIOVASCULAR',
 'Cardiovascular',
 'Cardiovascular examination and symptom-directed routing.',
 120),

('NEUROLOGICAL',
 'Neurological',
 'Neurological examination and neurological red-flag routing.',
 130),

('GASTROINTESTINAL',
 'Gastrointestinal',
 'GI examination and abdominal symptom routing.',
 140),

('GENITOURINARY',
 'Genitourinary',
 'GU examination and urinary/genital symptom routing.',
 150),

('MUSCULOSKELETAL',
 'Musculoskeletal',
 'Musculoskeletal examination and injury routing.',
 160),

('DERMATOLOGY',
 'Dermatology',
 'Skin and lesion examination routing.',
 170),

('ENT',
 'ENT / Oral',
 'ENT and oral examination routing.',
 180),

('GERIATRIC',
 'Geriatric',
 'Older-adult examination and safety routing.',
 190),

('SAFETY',
 'Clinical Safety',
 'Rules intended to identify urgent or unsafe states and require escalation.',
 200),

('VALIDATION',
 'Data Validation',
 'Rules validating clinical data completeness, units, ranges and consistency.',
 210),

('DOCUMENTATION',
 'Documentation',
 'Rules governing safe clinical documentation and provenance.',
 220),

('WORKFLOW',
 'Workflow',
 'Rules governing progression between clinical stages.',
 230)

ON CONFLICT (code) DO UPDATE
SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order;

-- =============================================================================
-- 2. RULE STATUS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.rule_status (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text NOT NULL
);

INSERT INTO knowledge.rule_status(code, label, description)
VALUES
('DRAFT',    'Draft',    'Rule is under development and must not execute clinically.'),
('TESTING',  'Testing',  'Rule is undergoing validation in non-production execution.'),
('ACTIVE',   'Active',   'Rule is authorised for CPU execution.'),
('SUSPENDED','Suspended','Rule temporarily disabled without retirement.'),
('RETIRED',  'Retired',  'Rule is no longer executable but remains historically preserved.')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- 3. RULE ACTION TYPES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.rule_action_type (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text NOT NULL,
    safety_class text NOT NULL
        CHECK (safety_class IN (
            'INFORMATIONAL',
            'WORKFLOW',
            'CLINICAL_SAFETY',
            'CLINICAL_REASONING',
            'MANAGEMENT'
        ))
);

INSERT INTO knowledge.rule_action_type
(code, label, description, safety_class)
VALUES
('SHOW_MODULE',
 'Show clinical module',
 'Make a clinical module available to the CPU/UI projection.',
 'WORKFLOW'),

('HIDE_MODULE',
 'Hide clinical module',
 'Remove a module from the active clinical projection when its context no longer applies.',
 'WORKFLOW'),

('REQUEST_QUESTION',
 'Request question',
 'Ask the CPU to request a structured clinical question.',
 'WORKFLOW'),

('REQUIRE_QUESTION',
 'Require question',
 'Require capture before the workflow can consider the module complete.',
 'WORKFLOW'),

('REQUEST_EXAM',
 'Request examination',
 'Add an examination concept/domain to the focused examination plan.',
 'CLINICAL_REASONING'),

('REQUIRE_EXAM',
 'Require examination',
 'Require a specified examination component when the rule conditions are met.',
 'CLINICAL_SAFETY'),

('REQUEST_MEASUREMENT',
 'Request measurement',
 'Request a structured measurement.',
 'WORKFLOW'),

('VALIDATE_VALUE',
 'Validate value',
 'Validate a captured clinical value.',
 'INFORMATIONAL'),

('CLASSIFY_FINDING',
 'Classify finding',
 'Attach an interpretation to an existing structured observation.',
 'CLINICAL_REASONING'),

('TRIGGER_ALERT',
 'Trigger alert',
 'Create an alert requiring review.',
 'CLINICAL_SAFETY'),

('TRIGGER_ESCALATION',
 'Trigger escalation',
 'Escalate the encounter to an appropriate clinical workflow.',
 'CLINICAL_SAFETY'),

('SET_CONTEXT',
 'Set context',
 'Derive a structured workflow context from captured facts.',
 'WORKFLOW'),

('REMOVE_CONTEXT',
 'Remove context',
 'Remove a previously applicable context when source facts no longer support it.',
 'WORKFLOW'),

('REQUEST_REASSESSMENT',
 'Request reassessment',
 'Ask for reassessment of an existing finding or physiological state.',
 'CLINICAL_SAFETY'),

('REQUEST_FOCUSED_HISTORY',
 'Request focused history',
 'Activate a symptom/system-specific history module.',
 'CLINICAL_REASONING'),

('REQUEST_FOCUSED_EXAM',
 'Request focused examination',
 'Activate a system-specific examination module.',
 'CLINICAL_REASONING'),

('DOCUMENT_FACT',
 'Document fact',
 'Make an existing structured fact eligible for documentation.',
 'INFORMATIONAL'),

('DOCUMENT_WARNING',
 'Document warning',
 'Expose a clinically relevant warning without inventing a diagnosis.',
 'INFORMATIONAL'),

('BLOCK_PROGRESSION',
 'Block progression',
 'Prevent workflow progression until a safety/completeness requirement is satisfied.',
 'CLINICAL_SAFETY'),

('ALLOW_PROGRESSION',
 'Allow progression',
 'Permit workflow progression after required conditions are satisfied.',
 'WORKFLOW')

ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- 4. RULE CONDITION OPERATORS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.rule_operator (
    code text PRIMARY KEY,
    label text NOT NULL,
    description text NOT NULL
);

INSERT INTO knowledge.rule_operator(code, label, description)
VALUES
('EQ',          'Equals',              'Exact equality.'),
('NEQ',         'Not equals',          'Exact inequality.'),
('GT',          'Greater than',        'Numeric/string comparison.'),
('GTE',         'Greater or equal',    'Numeric/string comparison.'),
('LT',          'Less than',           'Numeric/string comparison.'),
('LTE',         'Less or equal',       'Numeric/string comparison.'),
('IN',          'In set',              'Value exists in an allowed set.'),
('NOT_IN',      'Not in set',          'Value does not exist in a set.'),
('EXISTS',      'Exists',              'A structured fact is known to exist.'),
('NOT_EXISTS',  'Does not exist',      'No fact is currently known.'),
('TRUE',        'True',                'Boolean fact is true.'),
('FALSE',       'False',               'Boolean fact is false.'),
('UNKNOWN',     'Unknown',              'Fact is explicitly unknown.'),
('PRESENT',     'Present',              'Clinical finding is present.'),
('ABSENT',      'Absent',              'Clinical finding is explicitly absent.'),
('NOT_ASSESSED','Not assessed',        'Finding has not been assessed.'),
('BETWEEN',     'Between',             'Inclusive numeric interval.'),
('AGE_BETWEEN', 'Age between',         'Age in months is within interval.'),
('AGE_LT',      'Age less than',       'Age in months is below threshold.'),
('AGE_GTE',     'Age greater/equal',   'Age in months is at/above threshold.'),
('SEX_IS',      'Sex is',              'Structured sex value.'),
('HAS_CONTEXT', 'Has context',         'Context value is active.'),
('NO_CONTEXT',  'No context',          'Context value is not active.'),
('STAGE_IS',    'Workflow stage',      'Encounter stage equals requested stage.'),
('ANY',         'Any',                'At least one supplied condition is true.'),
('ALL',         'All',                'All supplied conditions are true.'),
('NOT',         'Not',                'Logical negation.')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- 5. CRL RULE REGISTRY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_rule (
    rule_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code               text NOT NULL UNIQUE,
    rule_name               text NOT NULL,
    canonical_description   text NOT NULL,

    category_code           text NOT NULL
        REFERENCES knowledge.rule_category(code),

    status_code             text NOT NULL DEFAULT 'DRAFT'
        REFERENCES knowledge.rule_status(code),

    version                 integer NOT NULL DEFAULT 1
        CHECK (version > 0),

    priority                integer NOT NULL DEFAULT 100,

    conflict_group          text,

    specificity             integer NOT NULL DEFAULT 0,

    stop_on_match           boolean NOT NULL DEFAULT FALSE,

    is_safety_critical      boolean NOT NULL DEFAULT FALSE,

    source_layer            text NOT NULL DEFAULT 'CRL'
        CHECK (source_layer IN (
            'SYSTEM',
            'CRL',
            'KNOWLEDGE',
            'GUIDELINE',
            'LOCAL_PROTOCOL'
        )),

    evidence_required       boolean NOT NULL DEFAULT FALSE,

    applies_to_context_codes text[] NOT NULL DEFAULT '{}',

    condition_json          jsonb NOT NULL DEFAULT '{}'::jsonb,

    action_json             jsonb NOT NULL DEFAULT '{}'::jsonb,

    exception_json          jsonb NOT NULL DEFAULT '{}'::jsonb,

    metadata_json           jsonb NOT NULL DEFAULT '{}'::jsonb,

    effective_from          timestamptz NOT NULL DEFAULT now(),
    effective_until         timestamptz,

    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT clinical_rule_effective_period_ck
        CHECK (
            effective_until IS NULL
            OR effective_until > effective_from
        )
);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_category
    ON knowledge.clinical_rule(category_code);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_status
    ON knowledge.clinical_rule(status_code);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_priority
    ON knowledge.clinical_rule(priority);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_context
    ON knowledge.clinical_rule
    USING GIN(applies_to_context_codes);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_condition
    ON knowledge.clinical_rule
    USING GIN(condition_json);

COMMENT ON TABLE knowledge.clinical_rule IS
'Canonical AMEXAN Clinical Rule Language registry. Rules contain workflow behaviour and conditions, not patient runtime facts.';

-- =============================================================================
-- 6. RULE DEPENDENCIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_rule_dependency (
    rule_id                 uuid NOT NULL
        REFERENCES knowledge.clinical_rule(rule_id)
        ON DELETE CASCADE,

    depends_on_rule_id      uuid NOT NULL
        REFERENCES knowledge.clinical_rule(rule_id)
        ON DELETE RESTRICT,

    dependency_type         text NOT NULL
        CHECK (dependency_type IN (
            'PREREQUISITE',
            'ORDERING',
            'CONFLICT',
            'ENHANCES',
            'SUPPRESSES'
        )),

    sort_order              integer NOT NULL DEFAULT 0,

    PRIMARY KEY (rule_id, depends_on_rule_id, dependency_type)
);

-- =============================================================================
-- 7. RULE EVIDENCE / PROVENANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_rule_evidence (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_id                 uuid NOT NULL
        REFERENCES knowledge.clinical_rule(rule_id)
        ON DELETE CASCADE,

    source_type             text NOT NULL
        CHECK (source_type IN (
            'TEXTBOOK',
            'GUIDELINE',
            'STANDARD',
            'LOCAL_PROTOCOL',
            'CONSENSUS',
            'SYSTEM_POLICY',
            'SYSTEM_STANDARD'
        )),

    source_name             text NOT NULL,
    source_reference       text,
    source_version         text,
    jurisdiction            text,

    evidence_level         text,

    verification_status    text NOT NULL DEFAULT 'UNVERIFIED'
        CHECK (verification_status IN (
            'UNVERIFIED',
            'REVIEWED',
            'APPROVED',
            'RETIRED'
        )),

    notes                   text,

    created_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rule_evidence_rule
    ON knowledge.clinical_rule_evidence(rule_id);

-- =============================================================================
-- 8. RULE TEST CASES
-- =============================================================================
--
-- This is essential.
--
-- A rule engine without executable regression tests becomes unsafe as the
-- knowledge base grows.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_rule_test (
    test_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_id                 uuid NOT NULL
        REFERENCES knowledge.clinical_rule(rule_id)
        ON DELETE CASCADE,

    test_code               text NOT NULL UNIQUE,
    test_name               text NOT NULL,

    input_context_json      jsonb NOT NULL,
    expected_match         boolean NOT NULL,

    expected_actions_json   jsonb NOT NULL DEFAULT '[]'::jsonb,

    expected_exceptions_json jsonb NOT NULL DEFAULT '[]'::jsonb,

    is_regression           boolean NOT NULL DEFAULT TRUE,
    is_active               boolean NOT NULL DEFAULT TRUE,

    created_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rule_test_rule
    ON knowledge.clinical_rule_test(rule_id);

-- =============================================================================
-- 9. RUNTIME RULE EXECUTION AUDIT
-- =============================================================================
--
-- CPU writes these records.
-- PostgreSQL does not execute the clinical rule itself.
--
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.rule_execution CASCADE;
CREATE TABLE IF NOT EXISTS clinical.rule_execution (
    execution_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_id                 uuid NOT NULL
        REFERENCES knowledge.clinical_rule(rule_id),

    patient_id              uuid,
    encounter_id            uuid,

    execution_run_id        uuid,

    execution_stage         text,

    input_context_hash      text,

    input_context_json      jsonb,

    matched                 boolean NOT NULL,

    action_result_json      jsonb,

    exception_result_json   jsonb,

    execution_status        text NOT NULL
        CHECK (execution_status IN (
            'EVALUATED',
            'MATCHED',
            'SKIPPED',
            'BLOCKED',
            'FAILED'
        )),

    failure_code            text,
    failure_message         text,

    executed_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_execution_rule
    ON clinical.rule_execution(rule_id);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_execution_patient
    ON clinical.rule_execution(patient_id);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_execution_encounter
    ON clinical.rule_execution(encounter_id);

CREATE INDEX IF NOT EXISTS idx_clinical_rule_execution_run
    ON clinical.rule_execution(execution_run_id);

-- =============================================================================
-- 10. CONTEXT DERIVATION REGISTRY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_context_definition (
    code                    text PRIMARY KEY,
    label                   text NOT NULL,
    description             text NOT NULL,
    context_level           text NOT NULL
        CHECK (context_level IN (
            'SYSTEM',
            'PATIENT',
            'ENCOUNTER',
            'CLINICAL',
            'WORKFLOW'
        )),
    source_fact_codes       text[] NOT NULL DEFAULT '{}',
    is_derived              boolean NOT NULL DEFAULT TRUE,
    is_active               boolean NOT NULL DEFAULT TRUE
);

INSERT INTO knowledge.clinical_context_definition
(code, label, description, context_level, source_fact_codes)
VALUES
('NEONATE',
 'Neonate',
 'Patient age 0 through 28 completed days.',
 'PATIENT',
 ARRAY[]::text[]),

('INFANT',
 'Infant',
 'Patient older than neonatal period through infancy.',
 'PATIENT',
 ARRAY[]::text[]),

('PAEDIATRIC',
 'Paediatric',
 'Child/adolescent clinical context requiring paediatric routing.',
 'PATIENT',
 ARRAY[]::text[]),

('ADOLESCENT',
 'Adolescent',
 'Adolescent developmental/clinical context.',
 'PATIENT',
 ARRAY[]::text[]),

('ADULT',
 'Adult',
 'Adult clinical context.',
 'PATIENT',
 ARRAY[]::text[]),

('OLDER_ADULT',
 'Older adult',
 'Older-adult/geriatric context.',
 'PATIENT',
 ARRAY[]::text[]),

('FEMALE_REPRODUCTIVE_AGE',
 'Female reproductive-age context',
 'Female patient in the configured reproductive-age range.',
 'PATIENT',
 ARRAY['SEX']),

('PREGNANCY_POSSIBLE',
 'Pregnancy possible',
 'Pregnancy has not been excluded where clinically relevant.',
 'CLINICAL',
 ARRAY[]::text[]),

('PREGNANT',
 'Pregnant',
 'Pregnancy is structurally established.',
 'CLINICAL',
 ARRAY[]::text[]),

('POSTPARTUM',
 'Postpartum',
 'Patient is within the postpartum context.',
 'CLINICAL',
 ARRAY[]::text[]),

('INPATIENT',
 'Inpatient',
 'Current encounter is an inpatient admission.',
 'ENCOUNTER',
 ARRAY['ENCOUNTER_TYPE']),

('OUTPATIENT',
 'Outpatient',
 'Current encounter is outpatient/review.',
 'ENCOUNTER',
 ARRAY['ENCOUNTER_TYPE']),

('EMERGENCY',
 'Emergency',
 'Emergency/urgent-care context.',
 'ENCOUNTER',
 ARRAY[]::text[]),

('SURGICAL_PRESENTATION',
 'Surgical presentation',
 'Clinical state requiring or potentially requiring focused surgical assessment.',
 'CLINICAL',
 ARRAY[]::text[]),

('RESPIRATORY_PRESENTATION',
 'Respiratory presentation',
 'Respiratory symptom/finding context.',
 'CLINICAL',
 ARRAY[]::text[]),

('CARDIOVASCULAR_PRESENTATION',
 'Cardiovascular presentation',
 'Cardiovascular symptom/finding context.',
 'CLINICAL',
 ARRAY[]::text[]),

('NEUROLOGICAL_PRESENTATION',
 'Neurological presentation',
 'Neurological symptom/finding context.',
 'CLINICAL',
 ARRAY[]::text[]),

('ABDOMINAL_PRESENTATION',
 'Abdominal presentation',
 'Abdominal/GI symptom or finding context.',
 'CLINICAL',
 ARRAY[]::text[]),

('MUSCULOSKELETAL_PRESENTATION',
 'Musculoskeletal presentation',
 'Musculoskeletal symptom/injury context.',
 'CLINICAL',
 ARRAY[]::text[]),

('DERMATOLOGICAL_PRESENTATION',
 'Dermatological presentation',
 'Skin/lesion presentation.',
 'CLINICAL',
 ARRAY[]::text[])

ON CONFLICT (code) DO UPDATE
SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    context_level = EXCLUDED.context_level,
    source_fact_codes = EXCLUDED.source_fact_codes;

-- =============================================================================
-- 11. UNIVERSAL RULE INSERT HELPER
-- =============================================================================
--
-- The following rules are deliberately expressed as JSON CRL.
--
-- JSON is used here because the CPU can interpret a stable rule contract while
-- the database remains extensible without schema migration for every new
-- condition/operator/action.
--
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SYSTEM RULES
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.clinical_rule
(
    rule_code,
    rule_name,
    canonical_description,
    category_code,
    status_code,
    version,
    priority,
    specificity,
    is_safety_critical,
    condition_json,
    action_json,
    applies_to_context_codes
)
VALUES

(
 'SYS-001',
 'Unknown is not absent',
 'The engine must never convert UNKNOWN or NOT_ASSESSED into ABSENT.',
 'SYSTEM',
 'ACTIVE',
 1,
 1,
 100,
 TRUE,
 '{"all":[
     {"operator":"EQ","fact":"semantic_state","value":"UNKNOWN"}
 ]}'::jsonb,
 '{"action":"BLOCK_INFERENCE","reason":"UNKNOWN_MUST_NOT_BE_ABSENT"}'::jsonb,
 ARRAY['all_ages']
),

(
 'SYS-002',
 'UI cannot determine clinical context',
 'Clinical context must be derived by CPU from structured data and rules.',
 'SYSTEM',
 'ACTIVE',
 1,
 2,
 100,
 TRUE,
 '{"operator":"EXISTS","fact":"patient"}'::jsonb,
 '{"action":"CONTEXT_SOURCE","source":"CPU_ONLY","ui_override":false}'::jsonb,
 ARRAY['all_ages']
),

(
 'SYS-003',
 'No diagnosis from absence of assessment',
 'A disease or diagnosis must never be inferred solely because a sign was not assessed.',
 'SYSTEM',
 'ACTIVE',
 1,
 3,
 100,
 TRUE,
 '{"operator":"EQ","fact":"finding_state","value":"NOT_ASSESSED"}'::jsonb,
 '{"action":"BLOCK_DIAGNOSTIC_NEGATION","reason":"NOT_ASSESSED_IS_NOT_ABSENT"}'::jsonb,
 ARRAY['all_ages']
),

(
 'SYS-004',
 'Preserve provenance',
 'Every material clinical assertion generated by the system must reference its source structured fact.',
 'SYSTEM',
 'ACTIVE',
 1,
 4,
 100,
 TRUE,
 '{"operator":"EXISTS","fact":"clinical_assertion"}'::jsonb,
 '{"action":"REQUIRE_PROVENANCE","source":"STRUCTURED_FACT"}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- PATIENT AGE CONTEXT
-- -----------------------------------------------------------------------------

(
 'PAT-AGE-001',
 'Neonatal context',
 'Activate neonatal context for patients from birth through 28 completed days.',
 'PATIENT_CONTEXT',
 'ACTIVE',
 1,
 10,
 90,
 TRUE,
 '{"operator":"AGE_LT","months":1}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"NEONATE"},
   {"action":"SHOW_MODULE","module":"NEONATAL"},
   {"action":"HIDE_MODULE","module":"ADULT_GENERAL_HISTORY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"BIRTH_HISTORY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"MATERNAL_HISTORY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"FEEDING_HISTORY"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"NEONATAL_EXAM"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'PAT-AGE-002',
 'Paediatric context',
 'Activate paediatric clinical routing for children.',
 'PATIENT_CONTEXT',
 'ACTIVE',
 1,
 20,
 80,
 FALSE,
 '{"all":[
   {"operator":"AGE_GTE","months":1},
   {"operator":"AGE_LT","months":156}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"PAEDIATRIC"},
   {"action":"SHOW_MODULE","module":"PAEDIATRIC"},
   {"action":"REQUEST_MEASUREMENT","concept":"WEIGHT"},
   {"action":"REQUEST_MEASUREMENT","concept":"HEIGHT_OR_LENGTH"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'PAT-AGE-003',
 'Adult context',
 'Activate adult clinical routing from 13 years where configured.',
 'PATIENT_CONTEXT',
 'ACTIVE',
 1,
 30,
 70,
 FALSE,
 '{"operator":"AGE_GTE","months":156}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"ADULT"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'PAT-AGE-004',
 'Older adult context',
 'Activate geriatric context for older adults.',
 'GERIATRIC',
 'ACTIVE',
 1,
 40,
 90,
 FALSE,
 '{"operator":"AGE_GTE","years":65}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"OLDER_ADULT"},
   {"action":"SHOW_MODULE","module":"GERIATRIC_ASSESSMENT"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"FALLS"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"FUNCTION"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"COGNITION"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"MEDICATION_REVIEW"}
 ]}'::jsonb,
 ARRAY['ADULT']
),

-- -----------------------------------------------------------------------------
-- SEX / REPRODUCTIVE CONTEXT
-- -----------------------------------------------------------------------------

(
 'PAT-SEX-001',
 'Female reproductive-age routing',
 'Activate reproductive history routing when sex and age make it clinically relevant.',
 'PATIENT_CONTEXT',
 'ACTIVE',
 1,
 50,
 70,
 FALSE,
 '{"all":[
   {"operator":"SEX_IS","value":"FEMALE"},
   {"operator":"AGE_BETWEEN","min_years":10,"max_years":55}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"FEMALE_REPRODUCTIVE_AGE"},
   {"action":"SHOW_MODULE","module":"MENSTRUAL_HISTORY"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'PAT-SEX-002',
 'Pregnancy-sensitive routing',
 'Where pregnancy status is clinically relevant but not established, route the CPU to pregnancy assessment rather than assume pregnancy or non-pregnancy.',
 'OBSTETRIC',
 'ACTIVE',
 1,
 60,
 80,
 TRUE,
 '{"all":[
   {"operator":"SEX_IS","value":"FEMALE"},
   {"operator":"AGE_BETWEEN","min_years":10,"max_years":55},
   {"operator":"EQ","fact":"pregnancy_status","value":"UNKNOWN"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"PREGNANCY_POSSIBLE"},
   {"action":"REQUEST_QUESTION","question":"PREGNANCY_STATUS"}
 ]}'::jsonb,
 ARRAY['FEMALE_REPRODUCTIVE_AGE']
),

(
 'PAT-SEX-003',
 'Pregnancy confirmed',
 'Pregnancy confirmation activates obstetric routing.',
 'OBSTETRIC',
 'ACTIVE',
 1,
 61,
 90,
 TRUE,
 '{"operator":"EQ","fact":"pregnancy_status","value":"CONFIRMED"}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"PREGNANT"},
   {"action":"SHOW_MODULE","module":"OBSTETRIC_HISTORY"},
   {"action":"SHOW_MODULE","module":"OBSTETRIC_EXAMINATION"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"CURRENT_PREGNANCY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"OBSTETRIC_HISTORY"}
 ]}'::jsonb,
 ARRAY['FEMALE_REPRODUCTIVE_AGE']
),

-- -----------------------------------------------------------------------------
-- ENCOUNTER
-- -----------------------------------------------------------------------------

(
 'ENC-001',
 'New encounter defaults to inpatient until disposition is recorded',
 'A new encounter defaults to inpatient in the Universal Entry workflow; the disposition remains editable and must be persisted.',
 'ENCOUNTER',
 'ACTIVE',
 1,
 100,
 100,
 FALSE,
 '{"operator":"EQ","fact":"encounter_type","value":"UNKNOWN"}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"INPATIENT"},
   {"action":"REQUEST_QUESTION","question":"BIODATA_ENCOUNTER_TYPE"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'ENC-002',
 'Outpatient disposition removes admission date requirement',
 'Admission date is relevant to inpatient encounters only.',
 'ENCOUNTER',
 'ACTIVE',
 1,
 101,
 100,
 FALSE,
 '{"operator":"EQ","fact":"ENCOUNTER_TYPE","value":"OUTPATIENT"}'::jsonb,
 '{"actions":[
   {"action":"REMOVE_CONTEXT","context":"INPATIENT"},
   {"action":"HIDE_MODULE","module":"ADMISSION_DATE"},
   {"action":"ALLOW_PROGRESSION","requirement":"ADMISSION_DATE","required":false}
 ]}'::jsonb,
 ARRAY['OUTPATIENT']
),

(
 'ENC-003',
 'Inpatient admission date',
 'Inpatient encounters require the admission date to be captured.',
 'ENCOUNTER',
 'ACTIVE',
 1,
 102,
 100,
 TRUE,
 '{"operator":"EQ","fact":"ENCOUNTER_TYPE","value":"INPATIENT"}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_QUESTION","question":"BIODATA_ADMISSION_DATE"},
   {"action":"REQUIRE_QUESTION","question":"BIODATA_ADMISSION_DATE"}
 ]}'::jsonb,
 ARRAY['INPATIENT']
),

-- -----------------------------------------------------------------------------
-- HISTORY
-- -----------------------------------------------------------------------------

(
 'HIST-001',
 'Chief complaint precedes symptom history',
 'A chief complaint must be established before the detailed HPI module progresses.',
 'HISTORY',
 'ACTIVE',
 1,
 200,
 100,
 FALSE,
 '{"operator":"NOT_EXISTS","fact":"CHIEF_COMPLAINT"}'::jsonb,
 '{"actions":[
   {"action":"REQUIRE_QUESTION","question":"CHIEF_COMPLAINT"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'HIST-002',
 'HPI symptom-first rule',
 'The HPI engine should operate from symptoms/complaints rather than diagnoses.',
 'HISTORY',
 'ACTIVE',
 1,
 201,
 100,
 TRUE,
 '{"operator":"EXISTS","fact":"CHIEF_COMPLAINT"}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_FOCUSED_HISTORY","module":"SYMPTOM_CHARACTERISATION"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"CHRONOLOGY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"ASSOCIATED_SYMPTOMS"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"RED_FLAGS"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"RISK_FACTORS"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"HEALTH_SEEKING"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'HIST-003',
 'Informant and reliability',
 'Clinical history documentation must identify the informant and, where relevant, reliability.',
 'HISTORY',
 'ACTIVE',
 1,
 202,
 100,
 FALSE,
 '{"operator":"NOT_EXISTS","fact":"INFORMANT"}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_QUESTION","question":"INFORMANT"},
   {"action":"REQUEST_QUESTION","question":"INFORMANT_RELIABILITY"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- GENERAL EXAMINATION
-- -----------------------------------------------------------------------------

(
 'EXAM-GEN-001',
 'Universal general examination',
 'General appearance and physiological state form the foundation of the examination.',
 'EXAMINATION',
 'ACTIVE',
 1,
 300,
 100,
 TRUE,
 '{"operator":"STAGE_IS","stage":"EXAMINATION"}'::jsonb,
 '{"actions":[
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-APPEARANCE"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-POSITION"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-DISTRESS"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-NUTRITION"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-PALLOR"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-ICTERIC"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-CYANOSIS"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-EDEMA"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-LYMPH"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- VITAL SIGNS
-- -----------------------------------------------------------------------------

(
 'VITAL-001',
 'Universal vital signs',
 'Vital signs should be captured as structured measurements rather than prose.',
 'VITAL',
 'ACTIVE',
 1,
 310,
 100,
 TRUE,
 '{"operator":"STAGE_IS","stage":"EXAMINATION"}'::jsonb,
 '{"actions":[
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-BP"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-HR"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-RR"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-TEMP"},
   {"action":"REQUEST_MEASUREMENT","concept":"SPO2"},
   {"action":"REQUEST_MEASUREMENT","concept":"CAPILLARY_REFILL"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'VITAL-002',
 'Respiratory rate abnormality',
 'Respiratory rate must be interpreted using age-appropriate reference ranges rather than a single adult threshold.',
 'VITAL',
 'ACTIVE',
 1,
 311,
 100,
 TRUE,
 '{"operator":"EXISTS","fact":"RESPIRATORY_RATE"}'::jsonb,
 '{"actions":[
   {"action":"CLASSIFY_FINDING","concept":"RESPIRATORY_RATE","method":"AGE_SEX_NORMAL_RANGE"},
   {"action":"REQUEST_REASSESSMENT","when":"ABNORMAL"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'VITAL-003',
 'Oxygen saturation safety',
 'Low oxygen saturation requires explicit physiological interpretation and clinical reassessment.',
 'SAFETY',
 'ACTIVE',
 1,
 312,
 100,
 TRUE,
 '{"all":[
   {"operator":"EXISTS","fact":"SPO2"},
   {"operator":"LT","fact":"SPO2","value":92}
 ]}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ALERT","severity":"HIGH","code":"LOW_SPO2"},
   {"action":"REQUEST_REASSESSMENT","domain":"RESPIRATORY"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-DISTRESS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- PAEDIATRIC MEASUREMENTS
-- -----------------------------------------------------------------------------

(
 'PED-001',
 'Paediatric weight',
 'Weight should be captured in paediatric encounters for nutritional and dosing-related clinical context.',
 'PAEDIATRIC',
 'ACTIVE',
 1,
 400,
 100,
 FALSE,
 '{"operator":"HAS_CONTEXT","context":"PAEDIATRIC"}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_MEASUREMENT","concept":"EXAM-CON-WEIGHT"}
 ]}'::jsonb,
 ARRAY['PAEDIATRIC']
),

(
 'PED-002',
 'MUAC age routing',
 'MUAC is relevant to children in the configured 6â€“59 month assessment range.',
 'PAEDIATRIC',
 'ACTIVE',
 1,
 401,
 100,
 FALSE,
 '{"all":[
   {"operator":"AGE_BETWEEN_MONTHS","min":6,"max":59},
   {"operator":"HAS_CONTEXT","context":"PAEDIATRIC"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_MEASUREMENT","concept":"EXAM-CON-MUAC"}
 ]}'::jsonb,
 ARRAY['PAEDIATRIC']
),

(
 'PED-003',
 'Head circumference routing',
 'Head circumference is relevant during infancy and early childhood.',
 'PAEDIATRIC',
 'ACTIVE',
 1,
 402,
 100,
 FALSE,
 '{"operator":"AGE_LT_MONTHS","months":24}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_MEASUREMENT","concept":"EXAM-CON-HC"}
 ]}'::jsonb,
 ARRAY['PAEDIATRIC']
),

(
 'PED-004',
 'Infant length',
 'Recumbent length is preferred for infants and young children according to the configured measurement context.',
 'PAEDIATRIC',
 'ACTIVE',
 1,
 403,
 100,
 FALSE,
 '{"operator":"AGE_LT_MONTHS","months":24}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_MEASUREMENT","concept":"EXAM-CON-LENGTH"}
 ]}'::jsonb,
 ARRAY['PAEDIATRIC']
),

(
 'PED-005',
 'Child standing height',
 'Standing height becomes the preferred stature measurement once the child is developmentally/age appropriate.',
 'PAEDIATRIC',
 'ACTIVE',
 1,
 404,
 100,
 FALSE,
 '{"operator":"AGE_GTE_MONTHS","months":24}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_MEASUREMENT","concept":"EXAM-CON-HEIGHT"}
 ]}'::jsonb,
 ARRAY['PAEDIATRIC']
),

(
 'PED-006',
 'Paediatric BMI',
 'BMI requires age-appropriate interpretation and should not use adult BMI thresholds in children.',
 'PAEDIATRIC',
 'ACTIVE',
 1,
 405,
 100,
 FALSE,
 '{"operator":"AGE_GTE_MONTHS","months":60}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_MEASUREMENT","concept":"EXAM-CON-BMI"},
   {"action":"CLASSIFY_FINDING","concept":"BMI","method":"AGE_SEX_REFERENCE"}
 ]}'::jsonb,
 ARRAY['PAEDIATRIC']
),

-- -----------------------------------------------------------------------------
-- RESPIRATORY
-- -----------------------------------------------------------------------------

(
 'RESP-001',
 'Respiratory symptom triggers respiratory examination',
 'Respiratory complaints activate a focused respiratory examination.',
 'RESPIRATORY',
 'ACTIVE',
 1,
 500,
 90,
 TRUE,
 '{"any":[
   {"operator":"PRESENT","fact":"COUGH"},
   {"operator":"PRESENT","fact":"DYSPNOEA"},
   {"operator":"PRESENT","fact":"WHEEZE"},
   {"operator":"PRESENT","fact":"CHEST_PAIN"},
   {"operator":"PRESENT","fact":"HAEMOPTYSIS"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"RESPIRATORY_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"RESPIRATORY"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-RR"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-SPO2"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-DISTRESS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'RESP-002',
 'Respiratory distress requires focused assessment',
 'Observed respiratory distress requires focused respiratory examination and physiological reassessment.',
 'RESPIRATORY',
 'ACTIVE',
 1,
 501,
 100,
 TRUE,
 '{"operator":"EQ","fact":"DISTRESS_OBSERVED","value":true}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ALERT","severity":"HIGH","code":"RESPIRATORY_DISTRESS"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"RESPIRATORY"},
   {"action":"REQUEST_MEASUREMENT","concept":"SPO2"},
   {"action":"REQUEST_REASSESSMENT","domain":"RESPIRATORY"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- CARDIOVASCULAR
-- -----------------------------------------------------------------------------

(
 'CARDIO-001',
 'Cardiovascular symptom routing',
 'Chest pain, palpitations, syncope or peripheral oedema activate cardiovascular assessment.',
 'CARDIOVASCULAR',
 'ACTIVE',
 1,
 600,
 90,
 TRUE,
 '{"any":[
   {"operator":"PRESENT","fact":"CHEST_PAIN"},
   {"operator":"PRESENT","fact":"PALPITATIONS"},
   {"operator":"PRESENT","fact":"SYNCOPE"},
   {"operator":"PRESENT","fact":"PERIPHERAL_OEDEMA"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"CARDIOVASCULAR_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"CARDIOVASCULAR"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-BP"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-HR"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-EDEMA"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- NEUROLOGY
-- -----------------------------------------------------------------------------

(
 'NEURO-001',
 'Neurological symptom routing',
 'Neurological symptoms activate neurological examination.',
 'NEUROLOGICAL',
 'ACTIVE',
 1,
 700,
 90,
 TRUE,
 '{"any":[
   {"operator":"PRESENT","fact":"HEADACHE"},
   {"operator":"PRESENT","fact":"SEIZURE"},
   {"operator":"PRESENT","fact":"WEAKNESS"},
   {"operator":"PRESENT","fact":"NUMBNESS"},
   {"operator":"PRESENT","fact":"ALTERED_CONSCIOUSNESS"},
   {"operator":"PRESENT","fact":"VERTIGO"},
   {"operator":"PRESENT","fact":"GAIT_DISTURBANCE"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"NEUROLOGICAL_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"NEUROLOGICAL"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-APPEARANCE"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'NEURO-002',
 'Altered consciousness safety',
 'Altered consciousness requires immediate structured neurological assessment.',
 'SAFETY',
 'ACTIVE',
 1,
 701,
 100,
 TRUE,
 '{"operator":"PRESENT","fact":"ALTERED_CONSCIOUSNESS"}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ESCALATION","code":"ALTERED_CONSCIOUSNESS"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"NEUROLOGICAL"},
   {"action":"REQUEST_MEASUREMENT","concept":"GCS"},
   {"action":"REQUEST_MEASUREMENT","concept":"RBS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'NEURO-003',
 'Seizure examination',
 'A seizure presentation requires neurological assessment and assessment of current consciousness and physiological stability.',
 'SAFETY',
 'ACTIVE',
 1,
 702,
 100,
 TRUE,
 '{"operator":"PRESENT","fact":"SEIZURE"}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ALERT","severity":"HIGH","code":"SEIZURE_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"NEUROLOGICAL"},
   {"action":"REQUEST_MEASUREMENT","concept":"RBS"},
   {"action":"REQUEST_REASSESSMENT","domain":"NEUROLOGICAL"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- GASTROINTESTINAL
-- -----------------------------------------------------------------------------

(
 'GI-001',
 'Abdominal presentation',
 'Abdominal pain, vomiting, diarrhoea, GI bleeding or abdominal distension activates abdominal examination.',
 'GASTROINTESTINAL',
 'ACTIVE',
 1,
 800,
 90,
 TRUE,
 '{"any":[
   {"operator":"PRESENT","fact":"ABDOMINAL_PAIN"},
   {"operator":"PRESENT","fact":"VOMITING"},
   {"operator":"PRESENT","fact":"DIARRHOEA"},
   {"operator":"PRESENT","fact":"HAEMATEMESIS"},
   {"operator":"PRESENT","fact":"MELAENA"},
   {"operator":"PRESENT","fact":"ABDOMINAL_DISTENSION"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"ABDOMINAL_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"ABDOMINAL"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-EDEMA"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'GI-002',
 'GI bleeding safety',
 'GI bleeding symptoms require explicit severity assessment.',
 'SAFETY',
 'ACTIVE',
 1,
 801,
 100,
 TRUE,
 '{"any":[
   {"operator":"PRESENT","fact":"HAEMATEMESIS"},
   {"operator":"PRESENT","fact":"MELAENA"},
   {"operator":"PRESENT","fact":"HAEMATOCHEZIA"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ALERT","severity":"HIGH","code":"GI_BLEEDING"},
   {"action":"REQUEST_MEASUREMENT","concept":"BP"},
   {"action":"REQUEST_MEASUREMENT","concept":"HR"},
   {"action":"REQUEST_REASSESSMENT","domain":"HAEMODYNAMIC_STATUS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- GENITOURINARY
-- -----------------------------------------------------------------------------

(
 'GU-001',
 'Urinary presentation',
 'Dysuria, frequency, retention, haematuria or flank pain activates GU assessment.',
 'GENITOURINARY',
 'ACTIVE',
 1,
 900,
 90,
 FALSE,
 '{"any":[
   {"operator":"PRESENT","fact":"DYSURIA"},
   {"operator":"PRESENT","fact":"URINARY_FREQUENCY"},
   {"operator":"PRESENT","fact":"URINARY_RETENTION"},
   {"operator":"PRESENT","fact":"HAEMATURIA"},
   {"operator":"PRESENT","fact":"FLANK_PAIN"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"GENITOURINARY_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"GENITOURINARY"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- MUSCULOSKELETAL
-- -----------------------------------------------------------------------------

(
 'MSK-001',
 'Musculoskeletal injury routing',
 'Trauma, joint pain, swelling or reduced function activates focused musculoskeletal examination.',
 'MUSCULOSKELETAL',
 'ACTIVE',
 1,
 1000,
 90,
 TRUE,
 '{"any":[
   {"operator":"PRESENT","fact":"LIMB_PAIN"},
   {"operator":"PRESENT","fact":"JOINT_PAIN"},
   {"operator":"PRESENT","fact":"JOINT_SWELLING"},
   {"operator":"PRESENT","fact":"TRAUMA"},
   {"operator":"PRESENT","fact":"REDUCED_RANGE_OF_MOTION"},
   {"operator":"PRESENT","fact":"LIMB_DEFORMITY"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"MUSCULOSKELETAL_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"MUSCULOSKELETAL"},
   {"action":"REQUEST_EXAM","concept":"NEUROVASCULAR_STATUS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'MSK-002',
 'Neurovascular examination after limb injury',
 'A limb injury requires documentation of distal neurovascular status.',
 'SAFETY',
 'ACTIVE',
 1,
 1001,
 100,
 TRUE,
 '{"operator":"PRESENT","fact":"TRAUMA"}'::jsonb,
 '{"actions":[
   {"action":"REQUIRE_EXAM","concept":"DISTAL_PULSES"},
   {"action":"REQUIRE_EXAM","concept":"CAPILLARY_REFILL"},
   {"action":"REQUIRE_EXAM","concept":"DISTAL_SENSATION"},
   {"action":"REQUIRE_EXAM","concept":"DISTAL_MOTOR_FUNCTION"}
 ]}'::jsonb,
 ARRAY['MUSCULOSKELETAL_PRESENTATION']
),

-- -----------------------------------------------------------------------------
-- DERMATOLOGY / SURGICAL
-- -----------------------------------------------------------------------------

(
 'SURG-001',
 'Mass requires local examination',
 'A documented mass requires focused local examination rather than generic systemic examination alone.',
 'SURGICAL',
 'ACTIVE',
 1,
 1100,
 100,
 FALSE,
 '{"operator":"PRESENT","fact":"MASS_FOUND"}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"SURGICAL_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"LOCAL_MASS"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-MASS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'SURG-002',
 'Ulcer requires local examination',
 'An ulcer requires structured local examination.',
 'SURGICAL',
 'ACTIVE',
 1,
 1101,
 100,
 FALSE,
 '{"operator":"PRESENT","fact":"ULCER_FOUND"}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"SURGICAL_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"LOCAL_ULCER"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-ULCER"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'SURG-003',
 'Wound requires local examination',
 'A wound requires structured wound examination.',
 'SURGICAL',
 'ACTIVE',
 1,
 1102,
 100,
 TRUE,
 '{"operator":"PRESENT","fact":"WOUND_FOUND"}'::jsonb,
 '{"actions":[
   {"action":"SET_CONTEXT","context":"SURGICAL_PRESENTATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"WOUND"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-WOUND"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'SURG-004',
 'Discharge requires source examination',
 'A discharge should trigger identification and examination of the anatomical source.',
 'SURGICAL',
 'ACTIVE',
 1,
 1103,
 90,
 FALSE,
 '{"operator":"PRESENT","fact":"DISCHARGE_FOUND"}'::jsonb,
 '{"actions":[
   {"action":"REQUEST_FOCUSED_EXAM","module":"LOCAL_DISCHARGE"},
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-DISCHARGE"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- ENT / ORAL
-- -----------------------------------------------------------------------------

(
 'ENT-001',
 'ENT symptom routing',
 'Sore throat, dysphagia, odynophagia, ear symptoms or oral symptoms activate ENT/oral examination.',
 'ENT',
 'ACTIVE',
 1,
 1200,
 90,
 FALSE,
 '{"any":[
   {"operator":"PRESENT","fact":"SORE_THROAT"},
   {"operator":"PRESENT","fact":"DYSPHAGIA"},
   {"operator":"PRESENT","fact":"ODYNOPHAGIA"},
   {"operator":"PRESENT","fact":"EAR_PAIN"},
   {"operator":"PRESENT","fact":"ORAL_PAIN"},
   {"operator":"PRESENT","fact":"ORAL_LESION"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SHOW_MODULE","module":"ENT_ORAL"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"ENT_ORAL"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-TONSILS"},
   {"action":"REQUEST_EXAM","concept":"EXAM-CON-ORALCAV"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- LYMPHATIC / SYSTEMIC
-- -----------------------------------------------------------------------------

(
 'SYS-EXAM-001',
 'Lymphadenopathy requires node assessment',
 'Lymphadenopathy requires structured lymph-node examination.',
 'EXAMINATION',
 'ACTIVE',
 1,
 1300,
 100,
 FALSE,
 '{"operator":"PRESENT","fact":"LYMPHADENOPATHY"}'::jsonb,
 '{"actions":[
   {"action":"REQUIRE_EXAM","concept":"EXAM-CON-LYMPH"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"LYMPH_NODE_EXAMINATION"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- OBGYN
-- -----------------------------------------------------------------------------

(
 'OBG-001',
 'Menstrual history for reproductive-age female',
 'Menstrual history is activated for clinically relevant reproductive-age females.',
 'GYNAECOLOGICAL',
 'ACTIVE',
 1,
 1400,
 80,
 FALSE,
 '{"all":[
   {"operator":"HAS_CONTEXT","context":"FEMALE_REPRODUCTIVE_AGE"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"SHOW_MODULE","module":"MENSTRUAL_HISTORY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"MENSTRUAL_HISTORY"}
 ]}'::jsonb,
 ARRAY['FEMALE_REPRODUCTIVE_AGE']
),

(
 'OBG-002',
 'Pregnancy activates obstetric history',
 'Confirmed pregnancy activates obstetric history and current pregnancy history.',
 'OBSTETRIC',
 'ACTIVE',
 1,
 1401,
 100,
 TRUE,
 '{"operator":"HAS_CONTEXT","context":"PREGNANT"}'::jsonb,
 '{"actions":[
   {"action":"SHOW_MODULE","module":"OBSTETRIC_HISTORY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"GRAVIDITY_PARITY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"LMP_EDD"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"CURRENT_PREGNANCY"},
   {"action":"REQUEST_FOCUSED_HISTORY","module":"PAST_OBSTETRIC_HISTORY"}
 ]}'::jsonb,
 ARRAY['PREGNANT']
),

(
 'OBG-003',
 'Pregnant patient requires obstetric examination',
 'Pregnancy activates appropriate obstetric examination according to gestation and presentation.',
 'OBSTETRIC',
 'ACTIVE',
 1,
 1402,
 100,
 TRUE,
 '{"operator":"HAS_CONTEXT","context":"PREGNANT"}'::jsonb,
 '{"actions":[
   {"action":"SHOW_MODULE","module":"OBSTETRIC_EXAMINATION"},
   {"action":"REQUEST_FOCUSED_EXAM","module":"OBSTETRIC"}
 ]}'::jsonb,
 ARRAY['PREGNANT']
),

-- -----------------------------------------------------------------------------
-- EMERGENCY / SAFETY
-- -----------------------------------------------------------------------------

(
 'SAFE-001',
 'Severe respiratory compromise',
 'Severe respiratory compromise requires immediate escalation.',
 'SAFETY',
 'ACTIVE',
 1,
 1500,
 100,
 TRUE,
 '{"any":[
   {"operator":"EQ","fact":"SPO2_SEVERITY","value":"CRITICAL"},
   {"operator":"EQ","fact":"DISTRESS_SEVERITY","value":"SEVERE"},
   {"operator":"EQ","fact":"RESPIRATORY_RATE_SEVERITY","value":"CRITICAL"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ESCALATION","code":"RESPIRATORY_COMPROMISE"},
   {"action":"TRIGGER_ALERT","severity":"CRITICAL","code":"RESPIRATORY_COMPROMISE"},
   {"action":"BLOCK_PROGRESSION","reason":"IMMEDIATE_REASSESSMENT_REQUIRED"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'SAFE-002',
 'Shock physiology',
 'Possible shock physiology requires immediate physiological reassessment and escalation.',
 'SAFETY',
 'ACTIVE',
 1,
 1501,
 100,
 TRUE,
 '{"any":[
   {"operator":"EQ","fact":"HAEMODYNAMIC_STATE","value":"SHOCK"},
   {"operator":"EQ","fact":"CAPILLARY_REFILL_SEVERITY","value":"PROLONGED"},
   {"operator":"EQ","fact":"BP_SYSTOLIC_INTERPRETATION","value":"CRITICAL_LOW"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ALERT","severity":"CRITICAL","code":"POSSIBLE_SHOCK"},
   {"action":"TRIGGER_ESCALATION","code":"HAEMODYNAMIC_INSTABILITY"},
   {"action":"REQUEST_REASSESSMENT","domain":"HAEMODYNAMIC_STATUS"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'SAFE-003',
 'Severe altered mental status',
 'Severe impairment of consciousness requires urgent escalation.',
 'SAFETY',
 'ACTIVE',
 1,
 1502,
 100,
 TRUE,
 '{"any":[
   {"operator":"EQ","fact":"GCS_CATEGORY","value":"SEVERE"},
   {"operator":"EQ","fact":"CONSCIOUSNESS","value":"UNRESPONSIVE"}
 ]}'::jsonb,
 '{"actions":[
   {"action":"TRIGGER_ALERT","severity":"CRITICAL","code":"SEVERE_ALTERED_CONSCIOUSNESS"},
   {"action":"TRIGGER_ESCALATION","code":"NEUROLOGICAL_EMERGENCY"},
   {"action":"BLOCK_PROGRESSION","reason":"URGENT_ASSESSMENT_REQUIRED"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- DOCUMENTATION
-- -----------------------------------------------------------------------------

(
 'DOC-001',
 'Do not generate absent findings from omitted findings',
 'Documentation may state absence only when the structured examination explicitly records absence.',
 'DOCUMENTATION',
 'ACTIVE',
 1,
 1600,
 100,
 TRUE,
 '{"operator":"EQ","fact":"finding_state","value":"NOT_ASSESSED"}'::jsonb,
 '{"actions":[
   {"action":"BLOCK_DOCUMENTATION_ASSERTION","assertion":"ABSENT"},
   {"action":"DOCUMENT_WARNING","code":"NOT_ASSESSED"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'DOC-002',
 'Documentation follows structured facts',
 'The documentation engine may only realize assertions supported by structured facts.',
 'DOCUMENTATION',
 'ACTIVE',
 1,
 1601,
 100,
 TRUE,
 '{"operator":"EXISTS","fact":"documentation_assertion"}'::jsonb,
 '{"actions":[
   {"action":"REQUIRE_PROVENANCE","source":"STRUCTURED_FACT"},
   {"action":"PRESERVE_CERTAINTY","value":true}
 ]}'::jsonb,
 ARRAY['all_ages']
),

-- -----------------------------------------------------------------------------
-- WORKFLOW
-- -----------------------------------------------------------------------------

(
 'FLOW-001',
 'History must precede examination completion',
 'The workflow should not silently mark history complete when required history remains incomplete.',
 'WORKFLOW',
 'ACTIVE',
 1,
 1700,
 100,
 TRUE,
 '{"all":[
   {"operator":"STAGE_IS","stage":"EXAMINATION"},
   {"operator":"EQ","fact":"REQUIRED_HISTORY_COMPLETE","value":false}
 ]}'::jsonb,
 '{"actions":[
   {"action":"BLOCK_PROGRESSION","reason":"REQUIRED_HISTORY_INCOMPLETE"}
 ]}'::jsonb,
 ARRAY['all_ages']
),

(
 'FLOW-002',
 'Required examination completion',
 'A mandatory examination component must be captured before examination completion.',
 'WORKFLOW',
 'ACTIVE',
 1,
 1701,
 100,
 TRUE,
 '{"all":[
   {"operator":"STAGE_IS","stage":"POST_EXAMINATION"},
   {"operator":"EQ","fact":"MANDATORY_EXAM_COMPLETE","value":false}
 ]}'::jsonb,
 '{"actions":[
   {"action":"BLOCK_PROGRESSION","reason":"MANDATORY_EXAMINATION_INCOMPLETE"}
 ]}'::jsonb,
 ARRAY['all_ages']
)

ON CONFLICT (rule_code) DO UPDATE
SET
    rule_name = EXCLUDED.rule_name,
    canonical_description = EXCLUDED.canonical_description,
    category_code = EXCLUDED.category_code,
    version = EXCLUDED.version,
    priority = EXCLUDED.priority,
    specificity = EXCLUDED.specificity,
    is_safety_critical = EXCLUDED.is_safety_critical,
    condition_json = EXCLUDED.condition_json,
    action_json = EXCLUDED.action_json,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes;

-- =============================================================================
-- 12. RULE EVIDENCE / PROVENANCE SEEDS
-- =============================================================================
--
-- These are intentionally architectural references rather than claims that a
-- particular numeric threshold has been clinically approved for production.
--
-- Production deployment should attach verified, jurisdiction-specific sources.
-- =============================================================================

INSERT INTO knowledge.clinical_rule_evidence
(
    rule_id,
    source_type,
    source_name,
    source_reference,
    verification_status,
    notes
)
SELECT
    r.rule_id,
    'SYSTEM_STANDARD',
    'AMEXAN Clinical Rule Language Constitution',
    'CRL-001',
    'APPROVED',
    'Architectural rule: workflow behaviour must be separated from medical knowledge.'
FROM knowledge.clinical_rule r
WHERE r.rule_code IN (
    'SYS-001',
    'SYS-002',
    'SYS-003',
    'SYS-004'
)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- 13. REGRESSION TESTS
-- =============================================================================

INSERT INTO knowledge.clinical_rule_test
(
    rule_id,
    test_code,
    test_name,
    input_context_json,
    expected_match,
    expected_actions_json
)
SELECT
    r.rule_id,
    x.test_code,
    x.test_name,
    x.input_context,
    x.expected_match,
    x.expected_actions
FROM knowledge.clinical_rule r
JOIN (
    VALUES

    (
      'SYS-001',
      'TEST-SYS-001-UNKNOWN',
      'Unknown must not become absent',
      '{"semantic_state":"UNKNOWN"}'::jsonb,
      TRUE,
      '[{"action":"BLOCK_INFERENCE"}]'::jsonb
    ),

    (
      'PAT-AGE-001',
      'TEST-PAT-AGE-001-NEONATE',
      'Neonate activates neonatal routing',
      '{"age_days":10}'::jsonb,
      TRUE,
      '[{"action":"SET_CONTEXT","context":"NEONATE"}]'::jsonb
    ),

    (
      'PAT-AGE-002',
      'TEST-PAT-AGE-002-CHILD',
      'Child activates paediatric routing',
      '{"age_months":30}'::jsonb,
      TRUE,
      '[{"action":"SET_CONTEXT","context":"PAEDIATRIC"}]'::jsonb
    ),

    (
      'PAT-AGE-003',
      'TEST-PAT-AGE-003-ADULT',
      'Adult activates adult routing',
      '{"age_months":300}'::jsonb,
      TRUE,
      '[{"action":"SET_CONTEXT","context":"ADULT"}]'::jsonb
    ),

    (
      'PAT-SEX-002',
      'TEST-PAT-SEX-002-PREGNANCY-UNKNOWN',
      'Pregnancy status unknown must trigger pregnancy assessment',
      '{"sex":"FEMALE","age_years":25,"pregnancy_status":"UNKNOWN"}'::jsonb,
      TRUE,
      '[{"action":"REQUEST_QUESTION","question":"PREGNANCY_STATUS"}]'::jsonb
    ),

    (
      'PAT-SEX-003',
      'TEST-PAT-SEX-003-PREGNANT',
      'Confirmed pregnancy activates obstetric history',
      '{"sex":"FEMALE","age_years":25,"pregnancy_status":"CONFIRMED"}'::jsonb,
      TRUE,
      '[{"action":"SET_CONTEXT","context":"PREGNANT"}]'::jsonb
    ),

    (
      'ENC-003',
      'TEST-ENC-003-INPATIENT',
      'Inpatient requires admission date',
      '{"ENCOUNTER_TYPE":"INPATIENT"}'::jsonb,
      TRUE,
      '[{"action":"REQUIRE_QUESTION","question":"BIODATA_ADMISSION_DATE"}]'::jsonb
    ),

    (
      'ENC-002',
      'TEST-ENC-002-OUTPATIENT',
      'Outpatient removes admission date requirement',
      '{"ENCOUNTER_TYPE":"OUTPATIENT"}'::jsonb,
      TRUE,
      '[{"action":"HIDE_MODULE","module":"ADMISSION_DATE"}]'::jsonb
    ),

    (
      'RESP-002',
      'TEST-RESP-002-DISTRESS',
      'Respiratory distress triggers respiratory reassessment',
      '{"DISTRESS_OBSERVED":true}'::jsonb,
      TRUE,
      '[{"action":"TRIGGER_ALERT","severity":"HIGH"}]'::jsonb
    ),

    (
      'NEURO-002',
      'TEST-NEURO-002-ALTERED',
      'Altered consciousness triggers neurological safety pathway',
      '{"ALTERED_CONSCIOUSNESS":true}'::jsonb,
      TRUE,
      '[{"action":"TRIGGER_ESCALATION","code":"ALTERED_CONSCIOUSNESS"}]'::jsonb
    ),

    (
      'MSK-002',
      'TEST-MSK-002-TRAUMA',
      'Limb trauma requires distal neurovascular examination',
      '{"TRAUMA":true}'::jsonb,
      TRUE,
      '[{"action":"REQUIRE_EXAM","concept":"DISTAL_PULSES"}]'::jsonb
    ),

    (
      'SURG-001',
      'TEST-SURG-001-MASS',
      'Mass triggers local examination',
      '{"MASS_FOUND":true}'::jsonb,
      TRUE,
      '[{"action":"REQUEST_FOCUSED_EXAM","module":"LOCAL_MASS"}]'::jsonb
    ),

    (
      'OBG-002',
      'TEST-OBG-002-PREGNANCY',
      'Pregnancy activates obstetric history',
      '{"PREGNANT":true}'::jsonb,
      TRUE,
      '[{"action":"SHOW_MODULE","module":"OBSTETRIC_HISTORY"}]'::jsonb
    ),

    (
      'SAFE-003',
      'TEST-SAFE-003-COMATOSE',
      'Severe altered consciousness triggers critical escalation',
      '{"GCS_CATEGORY":"SEVERE"}'::jsonb,
      TRUE,
      '[{"action":"TRIGGER_ALERT","severity":"CRITICAL"}]'::jsonb
    ),

    (
      'DOC-001',
      'TEST-DOC-001-NOT-ASSESSED',
      'Not assessed cannot be documented as absent',
      '{"finding_state":"NOT_ASSESSED"}'::jsonb,
      TRUE,
      '[{"action":"BLOCK_DOCUMENTATION_ASSERTION","assertion":"ABSENT"}]'::jsonb
    )

) AS x(
    rule_code,
    test_code,
    test_name,
    input_context,
    expected_match,
    expected_actions
)
ON r.rule_code = x.rule_code
ON CONFLICT (test_code) DO UPDATE
SET
    test_name = EXCLUDED.test_name,
    input_context_json = EXCLUDED.input_context_json,
    expected_match = EXCLUDED.expected_match,
    expected_actions_json = EXCLUDED.expected_actions_json;

-- =============================================================================
-- 14. RULE CONFLICT SAFETY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rule_conflict_group
    ON knowledge.clinical_rule(conflict_group);

CREATE INDEX IF NOT EXISTS idx_rule_safety_priority
    ON knowledge.clinical_rule(is_safety_critical, priority);

-- =============================================================================
-- 15. UPDATED-AT TRIGGER
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'set_updated_at'
    )
    AND EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'knowledge'
          AND table_name = 'clinical_rule'
    )
    THEN
        DROP TRIGGER IF EXISTS
            trg_knowledge_clinical_rule_updated_at
        ON knowledge.clinical_rule;

        CREATE TRIGGER
            trg_knowledge_clinical_rule_updated_at
        BEFORE UPDATE ON knowledge.clinical_rule
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;
END
$$;

-- =============================================================================
-- 16. RULE ENGINE CONTRACT
-- =============================================================================
--
-- The CPU MUST interpret the following execution contract:
--
-- 1. LOAD ACTIVE RULES
-- 2. FILTER BY EFFECTIVE DATE
-- 3. FILTER BY CONTEXT
-- 4. NORMALISE INPUT FACTS
-- 5. EVALUATE CONDITIONS
-- 6. APPLY EXCEPTIONS
-- 7. RESOLVE CONFLICTS
-- 8. SORT BY:
--       a. safety criticality
--       b. specificity
--       c. priority
--       d. rule_code
-- 9. EXECUTE ACTIONS
-- 10. WRITE EXECUTION AUDIT
-- 11. UPDATE CLINICAL CONTEXT
-- 12. RE-RUN DEPENDENT RULES
-- 13. STOP WHEN FIXPOINT IS REACHED
--
-- IMPORTANT:
-- The CPU should NOT continuously mutate state without convergence.
-- A rule execution cycle must terminate when no new context/action is created.
--
-- =============================================================================

COMMENT ON COLUMN knowledge.clinical_rule.condition_json IS
'CRL condition tree. The CPU evaluates this against structured clinical context.';

COMMENT ON COLUMN knowledge.clinical_rule.action_json IS
'CRL action tree. Actions describe workflow/context behaviour and must not fabricate patient facts.';

COMMENT ON COLUMN knowledge.clinical_rule.exception_json IS
'Explicit rule exceptions. Exceptions must be evaluated before action execution.';

COMMENT ON COLUMN knowledge.clinical_rule.conflict_group IS
'Rules with the same conflict group require deterministic conflict resolution.';

COMMENT ON COLUMN knowledge.clinical_rule.specificity IS
'Higher specificity wins when otherwise competing rules have equal safety class and priority.';

-- =============================================================================
-- 17. COMPLETION VERIFICATION
-- =============================================================================

DO $completion$
DECLARE
    v_rule_count integer;
    v_test_count integer;
    v_category_count integer;
BEGIN

    SELECT COUNT(*)
    INTO v_rule_count
    FROM knowledge.clinical_rule;

    SELECT COUNT(*)
    INTO v_test_count
    FROM knowledge.clinical_rule_test;

    SELECT COUNT(*)
    INTO v_category_count
    FROM knowledge.rule_category;

    IF v_category_count < 20 THEN
        RAISE EXCEPTION
            'AMEXAN migration 047 verification failed: rule categories incomplete';
    END IF;

    IF v_rule_count < 40 THEN
        RAISE EXCEPTION
            'AMEXAN migration 047 verification failed: expected universal rule seed';
    END IF;

    IF v_test_count < 10 THEN
        RAISE EXCEPTION
            'AMEXAN migration 047 verification failed: regression tests incomplete';
    END IF;

    RAISE NOTICE
        'AMEXAN migration 047 COMPLETE: Clinical Rule Engine installed. Rules=% Tests=% Categories=%',
        v_rule_count,
        v_test_count,
        v_category_count;
END
$completion$;

COMMIT;

-- =============================================================================
-- END MIGRATION 047
-- =============================================================================
