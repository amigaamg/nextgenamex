-- =============================================================================
-- AMEXAN CLINICAL OPERATING SYSTEM
-- MIGRATION 042 — GOVERNANCE + CLINICAL OS VERSION BOOTSTRAP
-- =============================================================================
--
-- PURPOSE
-- -------
-- Establishes the executable AMEXAN Clinical OS baseline required by:
--
--   • Clinical CPU
--   • GovernanceEngine
--   • ReasoningEngine
--   • DocumentationEngine
--   • DifferentialEngine
--   • SnapshotEngine
--   • ProvenanceEngine
--   • SafetyEngine
--   • PublicationEngine
--   • ReplayEngine
--
-- This migration is deliberately idempotent.
--
-- ARCHITECTURAL LAW
-- -----------------
--
-- PostgreSQL:
--   knowledge + governed configuration + version catalogue
--
-- CPU:
--   execution + event processing + reasoning + documentation + snapshots
--
-- UI:
--   rendering only
--
-- No clinical truth is invented by the UI.
-- No clinical rule is silently invented by the CPU.
-- No historical version is overwritten.
--
-- VERSION CHAIN
-- -------------
--
--   AMEXAN-1.0.0
--        │
--        ├── reasoning      RV2024.01.001
--        │
--        ├── documentation RV2024.01.002
--        │
--        ├── differential  RV2024.01.001
--        │
--        └── engine        CLINICAL-CPU-1.0
--
-- SNAPSHOT LAW
-- ------------
-- Every executable clinical computation must be attributable to a system
-- version. Historical clinical states must never be reinterpreted silently
-- because a newer rule, documentation template, or knowledge version exists.
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- 1. REQUIRED SCHEMAS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;
CREATE SCHEMA IF NOT EXISTS governance;
CREATE SCHEMA IF NOT EXISTS clinical;


-- =============================================================================
-- 2. UNIVERSAL JURISDICTION BOOTSTRAP
-- =============================================================================
--
-- knowledge_object has:
--
--   jurisdiction_code DEFAULT 'JUR-GLOBAL'
--
-- Therefore JUR-GLOBAL MUST exist before governed objects are inserted.
--
-- =============================================================================

INSERT INTO governance.jurisdiction
(
    jurisdiction_code,
    name,
    description,
    country_code,
    is_default,
    is_active,
    status
)
VALUES
(
    'JUR-GLOBAL',
    'Global',
    'Universal AMEXAN clinical knowledge baseline applicable where no
     jurisdiction-specific rule supersedes it.',
    NULL,
    TRUE,
    TRUE,
    'active'
)
ON CONFLICT (jurisdiction_code)
DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    is_default  = TRUE,
    is_active   = TRUE,
    status      = 'active',
    updated_at  = now();


-- =============================================================================
-- 3. KENYA JURISDICTION
-- =============================================================================
--
-- AMEXAN is intended to support jurisdictional clinical overlays without
-- duplicating the universal clinical model.
--
-- =============================================================================

INSERT INTO governance.jurisdiction
(
    jurisdiction_code,
    name,
    description,
    country_code,
    is_default,
    is_active,
    status
)
VALUES
(
    'JUR-KENYA',
    'Kenya',
    'Kenyan jurisdictional clinical, regulatory, formulary and prescribing
     overlay applied on top of universal AMEXAN clinical knowledge.',
    'KE',
    FALSE,
    TRUE,
    'active'
)
ON CONFLICT (jurisdiction_code)
DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    country_code = EXCLUDED.country_code,
    is_active   = TRUE,
    status      = 'active',
    updated_at  = now();


-- =============================================================================
-- 4. UNIVERSAL POPULATION CONTEXTS
-- =============================================================================
--
-- These are configuration objects rather than separate clinical systems.
--
-- =============================================================================

INSERT INTO governance.population_context
(
    population_code,
    name,
    description,
    applies_to_context_codes,
    is_active
)
VALUES
(
    'POP-ALL',
    'All populations',
    'Universal population context.',
    '{}',
    TRUE
),
(
    'POP-NEONATE',
    'Neonate',
    'Patients from birth through 27 completed days.',
    ARRAY['AGE_NEONATE'],
    TRUE
),
(
    'POP-INFANT',
    'Infant',
    'Patients from 28 completed days to less than 1 year.',
    ARRAY['AGE_INFANT'],
    TRUE
),
(
    'POP-PAEDIATRIC',
    'Paediatric',
    'Children requiring paediatric clinical pathways.',
    ARRAY['AGE_INFANT','AGE_CHILD'],
    TRUE
),
(
    'POP-CHILD',
    'Child',
    'Patients aged 1 year to less than 12 years.',
    ARRAY['AGE_CHILD'],
    TRUE
),
(
    'POP-ADOLESCENT',
    'Adolescent',
    'Patients aged 12 years to less than 18 years.',
    ARRAY['AGE_ADOLESCENT'],
    TRUE
),
(
    'POP-ADULT',
    'Adult',
    'Patients aged 18 years and above.',
    ARRAY['AGE_ADULT'],
    TRUE
),
(
    'POP-GERIATRIC',
    'Geriatric',
    'Older adult population requiring geriatric considerations.',
    ARRAY['AGE_GERIATRIC'],
    TRUE
),
(
    'POP-PREGNANT',
    'Pregnant',
    'Pregnant patients requiring pregnancy-specific clinical logic.',
    ARRAY['PREGNANCY'],
    TRUE
)
ON CONFLICT (population_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    applies_to_context_codes = EXCLUDED.applies_to_context_codes,
    is_active = TRUE,
    updated_at = now();


-- =============================================================================
-- 5. EVIDENCE LEVEL CATALOGUE
-- =============================================================================
--
-- EV-A = highest evidentiary strength
-- EV-E = lowest / indirect evidence
--
-- The catalogue classifies evidence.
-- It does NOT independently authorize clinical action.
--
-- =============================================================================

INSERT INTO governance.evidence_metadata
(
    evidence_level_code,
    level_label,
    ranking,
    description,
    is_active
)
VALUES
(
    'EV-A',
    'Highest evidence',
    1,
    'Highest-supported evidence such as high-quality systematic reviews,
     authoritative evidence syntheses or equivalent validated evidence.',
    TRUE
),
(
    'EV-B',
    'Strong evidence',
    2,
    'Strong clinical evidence with substantial methodological support.',
    TRUE
),
(
    'EV-C',
    'Moderate evidence',
    3,
    'Moderate-quality evidence, accepted clinical references or established
     clinical consensus.',
    TRUE
),
(
    'EV-D',
    'Limited evidence',
    4,
    'Limited, indirect, observational or lower-certainty evidence.',
    TRUE
),
(
    'EV-E',
    'Very limited evidence',
    5,
    'Weak, preliminary or highly indirect evidence requiring additional
     governance before consequential use.',
    TRUE
)
ON CONFLICT (evidence_level_code)
DO UPDATE SET
    level_label = EXCLUDED.level_label,
    ranking = EXCLUDED.ranking,
    description = EXCLUDED.description,
    is_active = TRUE,
    updated_at = now();


-- =============================================================================
-- 6. REASONING VERSION
-- =============================================================================
--
-- This version is referenced by governance.system_version.
--
-- IMPORTANT:
-- Do not overwrite an existing version's historical identity.
-- If the version already exists, its semantic identity is retained.
--
-- =============================================================================

INSERT INTO knowledge.reasoning_version
(
    version_code,
    ruleset_version,
    knowledge_version,
    engine_version,
    effective_from,
    status
)
VALUES
(
    'RV2024.01.001',
    'AMEXAN-RULES-1.0',
    'AMEXAN-KNOWLEDGE-1.0',
    'CLINICAL-CPU-1.0',
    CURRENT_DATE,
    'active'
)
ON CONFLICT (version_code)
DO NOTHING;


-- =============================================================================
-- 7. DOCUMENTATION VERSION
-- =============================================================================

INSERT INTO knowledge.documentation_version
(
    version_code,
    ruleset_version,
    knowledge_version,
    engine_version,
    effective_from,
    status
)
VALUES
(
    'RV2024.01.002',
    'AMEXAN-RULES-1.0',
    'AMEXAN-KNOWLEDGE-1.0',
    'CLINICAL-CPU-1.0',
    CURRENT_DATE,
    'active'
)
ON CONFLICT (version_code)
DO NOTHING;


-- =============================================================================
-- 8. MASTER SYSTEM VERSION
-- =============================================================================
--
-- This is the version referenced by:
--
--   governance.clinical_snapshot.system_version_code
--
-- It is therefore a hard runtime dependency.
--
-- =============================================================================

INSERT INTO governance.system_version
(
    system_version_code,
    reasoning_version_code,
    documentation_version_code,
    differential_version_code,
    engine_version,
    released_at,
    is_active
)
VALUES
(
    'AMEXAN-1.0.0',
    'RV2024.01.001',
    'RV2024.01.002',
    'RV2024.01.001',
    'CLINICAL-CPU-1.0',
    CURRENT_DATE,
    TRUE
)
ON CONFLICT (system_version_code)
DO NOTHING;


-- =============================================================================
-- 9. VERSION INTEGRITY
-- =============================================================================
--
-- Prevent more than one active AMEXAN master system version from silently
-- becoming authoritative.
--
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_governance_active_system_version
ON governance.system_version (is_active)
WHERE is_active = TRUE;


-- =============================================================================
-- 10. CLINICAL CPU ENGINE REGISTRY
-- =============================================================================
--
-- A system version identifies the whole OS.
-- The engine registry identifies individual computational engines.
--
-- This table is intentionally created only if the deployment does not already
-- provide an equivalent engine registry.
--
-- =============================================================================

CREATE TABLE IF NOT EXISTS governance.engine_registry
(
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    engine_code         text NOT NULL UNIQUE,

    engine_name         text NOT NULL,

    engine_type         text NOT NULL
        CHECK (
            engine_type IN
            (
                'INGESTION',
                'QUESTION',
                'FORMAT',
                'SECTION',
                'PHENOTYPE',
                'MECHANISM',
                'DIFFERENTIAL',
                'INVESTIGATION',
                'SEVERITY',
                'PROTOCOL',
                'MEDICATION',
                'PRESCRIPTION',
                'DOCUMENTATION',
                'PROVENANCE',
                'GOVERNANCE',
                'SAFETY',
                'SNAPSHOT',
                'REPLAY',
                'AUDIT',
                'NOTIFICATION',
                'INTEGRATION'
            )
        ),

    engine_version      text NOT NULL,

    system_version_code text
        REFERENCES governance.system_version(system_version_code),

    status              text NOT NULL DEFAULT 'ACTIVE'
        CHECK (
            status IN
            (
                'DRAFT',
                'REVIEW',
                'APPROVED',
                'ACTIVE',
                'RETIRED'
            )
        ),

    deterministic       boolean NOT NULL DEFAULT TRUE,

    human_authorization_required
                        boolean NOT NULL DEFAULT FALSE,

    description         text,

    created_at          timestamptz NOT NULL DEFAULT now(),

    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gov_engine_registry_type
ON governance.engine_registry(engine_type);

CREATE INDEX IF NOT EXISTS idx_gov_engine_registry_status
ON governance.engine_registry(status);


-- =============================================================================
-- 11. ENGINE UPDATED_AT TRIGGER
-- =============================================================================

DROP TRIGGER IF EXISTS
trg_gov_engine_registry_updated_at
ON governance.engine_registry;

CREATE TRIGGER
trg_gov_engine_registry_updated_at
BEFORE UPDATE ON governance.engine_registry
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 12. REGISTER THE CORE CLINICAL OS ENGINES
-- =============================================================================

INSERT INTO governance.engine_registry
(
    engine_code,
    engine_name,
    engine_type,
    engine_version,
    system_version_code,
    status,
    deterministic,
    human_authorization_required,
    description
)
VALUES

(
    'ENGINE-FACT-INGESTION',
    'Fact Ingestion Engine',
    'INGESTION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Validates and persists structured clinical facts without altering
     clinician-entered clinical meaning.'
),

(
    'ENGINE-QUESTION',
    'Clinical Question Engine',
    'QUESTION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Selects the next applicable clinical question from governed question
     definitions and context rules.'
),

(
    'ENGINE-FORMAT',
    'Clinical Format Resolver',
    'FORMAT',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Determines the applicable clinical format from the patient context vector.'
),

(
    'ENGINE-SECTION',
    'Clinical Section Engine',
    'SECTION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Builds the clinical workspace section projection from governed format and
     section rules.'
),

(
    'ENGINE-PHENOTYPE',
    'Phenotype Engine',
    'PHENOTYPE',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Evaluates captured facts against governed phenotype evidence rules.'
),

(
    'ENGINE-MECHANISM',
    'Mechanism Engine',
    'MECHANISM',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Maps clinical facts and phenotypes to governed pathophysiological
     mechanisms.'
),

(
    'ENGINE-DIFFERENTIAL',
    'Differential Diagnosis Engine',
    'DIFFERENTIAL',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Generates and ranks differential diagnoses from governed clinical
     evidence without silently converting a differential into a diagnosis.'
),

(
    'ENGINE-INVESTIGATION',
    'Investigation Engine',
    'INVESTIGATION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Determines governed investigation candidates and their clinical rationale.'
),

(
    'ENGINE-SEVERITY',
    'Severity Score Engine',
    'SEVERITY',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Evaluates governed severity scoring instruments against captured facts.'
),

(
    'ENGINE-PROTOCOL',
    'Protocol Engine',
    'PROTOCOL',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    TRUE,
    'Selects and evaluates governed clinical protocols and protocol actions.'
),

(
    'ENGINE-MEDICATION',
    'Medication Knowledge Engine',
    'MEDICATION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Resolves medication identity, formulation, indication, population,
     contraindications and governed dose references.'
),

(
    'ENGINE-PRESCRIPTION',
    'Prescription Engine',
    'PRESCRIPTION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    TRUE,
    'Constructs prescription candidates from governed medication, dose,
     route, frequency, duration, contraindication and jurisdictional rules.
     Final prescribing authority remains with the authorized clinician.'
),

(
    'ENGINE-DOCUMENTATION',
    'Clinical Documentation Engine',
    'DOCUMENTATION',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Transforms structured clinical state into governed clinical documentation
     while preserving fact provenance and human editing provenance.'
),

(
    'ENGINE-PROVENANCE',
    'Clinical Provenance Engine',
    'PROVENANCE',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Maintains forward and backward traceability from source claims to
     clinical facts, reasoning, rules and documentation.'
),

(
    'ENGINE-GOVERNANCE',
    'Governance Engine',
    'GOVERNANCE',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    TRUE,
    'Evaluates lifecycle, provenance, evidence, publication and governance
     controls.'
),

(
    'ENGINE-SAFETY',
    'Clinical Safety Engine',
    'SAFETY',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    TRUE,
    'Applies governed risk classifications and human-in-the-loop controls.'
),

(
    'ENGINE-SNAPSHOT',
    'Clinical Snapshot Engine',
    'SNAPSHOT',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Captures patient facts, knowledge state, reasoning state and documentation
     state as an immutable reproducibility snapshot.'
),

(
    'ENGINE-REPLAY',
    'Clinical Replay Engine',
    'REPLAY',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Reconstructs historical computations using their original system and
     knowledge versions.'
),

(
    'ENGINE-AUDIT',
    'Clinical Audit Engine',
    'AUDIT',
    'CLINICAL-CPU-1.0',
    'AMEXAN-1.0.0',
    'ACTIVE',
    TRUE,
    FALSE,
    'Records the clinical computation event stream and actor provenance.'
)

ON CONFLICT (engine_code)
DO NOTHING;


-- =============================================================================
-- 13. SAFETY DEFAULTS FOR CORE ENGINES
-- =============================================================================
--
-- Prescription, protocol, safety and governance engines cannot be interpreted
-- as autonomous prescribers or autonomous clinical authorities.
--
-- =============================================================================

UPDATE governance.engine_registry
SET human_authorization_required = TRUE
WHERE engine_type IN
(
    'PRESCRIPTION',
    'PROTOCOL',
    'SAFETY',
    'GOVERNANCE'
);


-- =============================================================================
-- 14. SYSTEM VERSION COMMENTS
-- =============================================================================

COMMENT ON TABLE governance.system_version
IS
'AMEXAN master Clinical OS version registry. Every reproducible clinical
computation must identify the exact system version used. Historical versions
are never silently reinterpreted.';


COMMENT ON COLUMN governance.system_version.system_version_code
IS
'Immutable AMEXAN Clinical OS release identity, e.g. AMEXAN-1.0.0.';


COMMENT ON COLUMN governance.system_version.reasoning_version_code
IS
'Exact reasoning knowledge/rules version used by the Clinical CPU.';


COMMENT ON COLUMN governance.system_version.documentation_version_code
IS
'Exact documentation rules/template version used to render clinical
documentation.';


COMMENT ON COLUMN governance.system_version.differential_version_code
IS
'Exact differential reasoning ruleset identity used during clinical reasoning.';


COMMENT ON COLUMN governance.system_version.engine_version
IS
'Clinical CPU execution engine version.';


-- =============================================================================
-- 15. RUNTIME SNAPSHOT SAFETY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_clinical_snapshot_system_version
ON governance.clinical_snapshot(system_version_code);


CREATE INDEX IF NOT EXISTS idx_reasoning_snapshot_run
ON governance.reasoning_snapshot(run_id);


CREATE INDEX IF NOT EXISTS idx_documentation_snapshot_instance
ON governance.documentation_snapshot(instance_id);


-- =============================================================================
-- 16. RUNTIME AUDIT CORRELATION INDEX
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_governance_audit_correlation
ON governance.audit_event(correlation_id);


-- =============================================================================
-- 17. RULE EXECUTION VERSION INDEX
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_governance_rule_execution_version
ON governance.rule_execution(object_version_id);


CREATE INDEX IF NOT EXISTS idx_governance_rule_execution_object
ON governance.rule_execution(object_id);


-- =============================================================================
-- 18. PROVENANCE TRACE INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_governance_provenance_claim
ON governance.provenance_record(source_claim_code);


CREATE INDEX IF NOT EXISTS idx_governance_provenance_fact
ON governance.provenance_record(fact_code);


CREATE INDEX IF NOT EXISTS idx_governance_provenance_run
ON governance.provenance_record(reasoning_run_id);


CREATE INDEX IF NOT EXISTS idx_governance_provenance_document
ON governance.provenance_record(documentation_instance_id);


CREATE INDEX IF NOT EXISTS idx_governance_provenance_rule
ON governance.provenance_record(rule_execution_id);


-- =============================================================================
-- 19. SYSTEM VERSION INTEGRITY CHECK
-- =============================================================================

DO $verify_system_version$
DECLARE
    v_count integer;
BEGIN

    SELECT COUNT(*)
    INTO v_count
    FROM governance.system_version
    WHERE system_version_code = 'AMEXAN-1.0.0'
      AND reasoning_version_code = 'RV2024.01.001'
      AND documentation_version_code = 'RV2024.01.002'
      AND engine_version = 'CLINICAL-CPU-1.0'
      AND is_active = TRUE;

    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'AMEXAN Clinical OS bootstrap failure: AMEXAN-1.0.0 is not correctly registered';
    END IF;

END
$verify_system_version$;


-- =============================================================================
-- 20. REASONING VERSION INTEGRITY
-- =============================================================================

DO $verify_reasoning_version$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM knowledge.reasoning_version
        WHERE version_code = 'RV2024.01.001'
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN Clinical OS bootstrap failure: reasoning version RV2024.01.001 missing';
    END IF;

END
$verify_reasoning_version$;


-- =============================================================================
-- 21. DOCUMENTATION VERSION INTEGRITY
-- =============================================================================

DO $verify_documentation_version$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM knowledge.documentation_version
        WHERE version_code = 'RV2024.01.002'
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN Clinical OS bootstrap failure: documentation version RV2024.01.002 missing';
    END IF;

END
$verify_documentation_version$;


-- =============================================================================
-- 22. GOVERNANCE DEFAULT INTEGRITY
-- =============================================================================

DO $verify_governance_defaults$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM governance.jurisdiction
        WHERE jurisdiction_code = 'JUR-GLOBAL'
          AND is_active = TRUE
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN Governance bootstrap failure: JUR-GLOBAL missing';
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM governance.evidence_metadata
        WHERE evidence_level_code = 'EV-C'
          AND is_active = TRUE
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN Governance bootstrap failure: EV-C missing';
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM governance.population_context
        WHERE population_code = 'POP-ALL'
          AND is_active = TRUE
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN Governance bootstrap failure: POP-ALL missing';
    END IF;

END
$verify_governance_defaults$;


-- =============================================================================
-- 23. CLINICAL OS ENGINE INTEGRITY
-- =============================================================================

DO $verify_engines$
DECLARE
    v_required integer;
    v_registered integer;
BEGIN

    SELECT COUNT(*)
    INTO v_required
    FROM
    (
        VALUES
            ('ENGINE-FACT-INGESTION'),
            ('ENGINE-QUESTION'),
            ('ENGINE-FORMAT'),
            ('ENGINE-SECTION'),
            ('ENGINE-PHENOTYPE'),
            ('ENGINE-MECHANISM'),
            ('ENGINE-DIFFERENTIAL'),
            ('ENGINE-INVESTIGATION'),
            ('ENGINE-SEVERITY'),
            ('ENGINE-PROTOCOL'),
            ('ENGINE-MEDICATION'),
            ('ENGINE-PRESCRIPTION'),
            ('ENGINE-DOCUMENTATION'),
            ('ENGINE-PROVENANCE'),
            ('ENGINE-GOVERNANCE'),
            ('ENGINE-SAFETY'),
            ('ENGINE-SNAPSHOT'),
            ('ENGINE-REPLAY'),
            ('ENGINE-AUDIT')
    ) AS required_engines(engine_code);


    SELECT COUNT(*)
    INTO v_registered
    FROM governance.engine_registry
    WHERE engine_code IN
    (
        'ENGINE-FACT-INGESTION',
        'ENGINE-QUESTION',
        'ENGINE-FORMAT',
        'ENGINE-SECTION',
        'ENGINE-PHENOTYPE',
        'ENGINE-MECHANISM',
        'ENGINE-DIFFERENTIAL',
        'ENGINE-INVESTIGATION',
        'ENGINE-SEVERITY',
        'ENGINE-PROTOCOL',
        'ENGINE-MEDICATION',
        'ENGINE-PRESCRIPTION',
        'ENGINE-DOCUMENTATION',
        'ENGINE-PROVENANCE',
        'ENGINE-GOVERNANCE',
        'ENGINE-SAFETY',
        'ENGINE-SNAPSHOT',
        'ENGINE-REPLAY',
        'ENGINE-AUDIT'
    )
    AND status = 'ACTIVE';


    IF v_registered <> v_required THEN
        RAISE EXCEPTION
            'AMEXAN Clinical OS bootstrap failure: % of % required engines active',
            v_registered,
            v_required;
    END IF;

END
$verify_engines$;


-- =============================================================================
-- 24. PRESCRIPTION SAFETY INTEGRITY
-- =============================================================================
--
-- The prescription engine is a clinical decision-support engine.
-- It can calculate and present a governed prescription candidate.
-- It must not silently become an autonomous prescribing authority.
--
-- =============================================================================

DO $verify_prescription_safety$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM governance.engine_registry
        WHERE engine_code = 'ENGINE-PRESCRIPTION'
          AND status = 'ACTIVE'
          AND human_authorization_required = TRUE
    )
    THEN
        RAISE EXCEPTION
            'AMEXAN safety failure: prescription engine is not human-authorized';
    END IF;

END
$verify_prescription_safety$;


-- =============================================================================
-- 25. FINAL BOOTSTRAP NOTICE
-- =============================================================================

DO $amexan_042_complete$
BEGIN

    RAISE NOTICE
        '==============================================================';

    RAISE NOTICE
        'AMEXAN CLINICAL OS 1.0.0 BOOTSTRAP COMPLETE';

    RAISE NOTICE
        'System Version       : AMEXAN-1.0.0';

    RAISE NOTICE
        'Reasoning Version    : RV2024.01.001';

    RAISE NOTICE
        'Documentation Version: RV2024.01.002';

    RAISE NOTICE
        'Differential Version : RV2024.01.001';

    RAISE NOTICE
        'CPU Version          : CLINICAL-CPU-1.0';

    RAISE NOTICE
        'Global Jurisdiction  : JUR-GLOBAL';

    RAISE NOTICE
        'Kenya Jurisdiction   : JUR-KENYA';

    RAISE NOTICE
        'Evidence Catalogue   : EV-A through EV-E';

    RAISE NOTICE
        'Population Catalogue : POP-ALL + age/pregnancy overlays';

    RAISE NOTICE
        'Core Engines         : FACT → QUESTION → FORMAT → SECTION';

    RAISE NOTICE
        'Clinical Intelligence: PHENOTYPE → MECHANISM → DIFFERENTIAL';

    RAISE NOTICE
        'Decision Support     : INVESTIGATION → SEVERITY → PROTOCOL';

    RAISE NOTICE
        'Therapeutics         : MEDICATION → PRESCRIPTION';

    RAISE NOTICE
        'Clinical Record      : DOCUMENTATION → PROVENANCE';

    RAISE NOTICE
        'Trust Layer          : GOVERNANCE → SAFETY → AUDIT';

    RAISE NOTICE
        'Reproducibility      : SNAPSHOT → REPLAY';

    RAISE NOTICE
        '==============================================================';

END
$amexan_042_complete$;


COMMIT;