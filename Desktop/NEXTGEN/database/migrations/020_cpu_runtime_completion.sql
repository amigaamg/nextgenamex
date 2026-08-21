-- =============================================================================
-- AMEXAN Phase 3 â€” Migration 020
-- UNIVERSAL SAFETY INTELLIGENCE + INVESTIGATION RESULT INTERPRETATION +
-- CONFIGURATION OVERRIDE HARDENING
--
-- Design principles
-- -----------------------------------------------------------------------------
-- 1. Safety factors are UNIVERSAL clinical facts.
-- 2. Investigation results return into the SAME fact substrate as history,
--    examination and monitoring.
-- 3. One investigation result may establish MANY facts.
-- 4. Result interpretation is DATA, not disease-specific application code.
-- 5. A result may be positive, negative, indeterminate, critical or normal.
-- 6. Result facts may carry an explicit value.
-- 7. Safety intelligence can block, modify, warn about or require review of
--    management.
-- 8. Facility/department/clinician configuration NEVER mutates AMEXAN DEFAULT.
-- 9. Overrides are versioned, time-bounded and explainable.
-- 10. Everything remains compatible with the universal concept / fact /
--     rule / protocol / knowledge-graph architecture.
--
-- Runtime loop:
--
--     INVESTIGATION ORDER
--          â†“
--     RESULT
--          â†“
--     RESULT INTERPRETER
--          â†“
--     FACTS
--          â†“
--     PHENOTYPE / MECHANISM / CONDITION UPDATE
--          â†“
--     SAFETY ENGINE
--          â†“
--     RULE ENGINE
--          â†“
--     PROTOCOL / RECOMMENDATION
--          â†“
--     CLINICIAN DECISION
--
-- No disease owns a result.
-- No investigation owns a disease-specific reasoning universe.
-- =============================================================================


BEGIN;


-- ============================================================================
-- 1. UNIVERSAL FACT DEFINITIONS â€” PATIENT SAFETY
-- ============================================================================

INSERT INTO clinical.fact_definition
    (code, name, description, data_type, allow_multiple, is_active)
VALUES

    (
        'DRUG_ALLERGY',
        'Drug allergy',
        'A documented allergy to a medication or medication class.',
        'text',
        true,
        true
    ),

    (
        'DRUG_ALLERGY_REACTION',
        'Drug allergy reaction',
        'Clinical description or coded phenotype of the documented drug allergy reaction.',
        'text',
        true,
        true
    ),

    (
        'DRUG_ALLERGY_SEVERITY',
        'Drug allergy severity',
        'Severity of a documented medication allergy.',
        'text',
        false,
        true
    ),

    (
        'PREGNANT',
        'Pregnant',
        'Whether the patient is currently pregnant.',
        'boolean',
        false,
        true
    ),

    (
        'GESTATIONAL_AGE',
        'Gestational age',
        'Gestational age at the time of observation.',
        'numeric',
        false,
        true
    ),

    (
        'LACTATING',
        'Lactating',
        'Whether the patient is currently breastfeeding/lactating.',
        'boolean',
        false,
        true
    ),

    (
        'CREATININE',
        'Serum creatinine',
        'Measured serum creatinine concentration.',
        'numeric',
        false,
        true
    ),

    (
        'EGFR',
        'Estimated glomerular filtration rate',
        'Estimated glomerular filtration rate used for renal function assessment.',
        'numeric',
        false,
        true
    ),

    (
        'RENAL_IMPAIRMENT',
        'Renal impairment',
        'Presence of clinically relevant renal impairment.',
        'boolean',
        false,
        true
    ),

    (
        'HEPATIC_IMPAIRMENT',
        'Hepatic impairment',
        'Presence of clinically relevant hepatic impairment.',
        'boolean',
        false,
        true
    ),

    (
        'HEPATIC_FUNCTION_SEVERITY',
        'Hepatic impairment severity',
        'Severity or clinical classification of hepatic dysfunction.',
        'text',
        false,
        true
    ),

    (
        'ANTICOAGULANT_USE',
        'Anticoagulant use',
        'Current use of an anticoagulant medication.',
        'text',
        true,
        true
    ),

    (
        'ANTIPLATELET_USE',
        'Antiplatelet use',
        'Current use of an antiplatelet medication.',
        'text',
        true,
        true
    ),

    (
        'IMMUNOSUPPRESSION',
        'Immunosuppression',
        'Current clinically relevant immunosuppression.',
        'boolean',
        false,
        true
    ),

    (
        'IMMUNOSUPPRESSIVE_AGENT',
        'Immunosuppressive agent',
        'Medication or treatment producing clinically relevant immunosuppression.',
        'text',
        true,
        true
    ),

    (
        'BLEEDING_RISK',
        'Bleeding risk',
        'Clinically relevant increased bleeding risk.',
        'boolean',
        false,
        true
    ),

    (
        'BLEEDING_DISORDER',
        'Bleeding disorder',
        'Known bleeding disorder or clinically significant coagulation disorder.',
        'text',
        true,
        true
    ),

    (
        'QT_PROLONGATION_RISK',
        'QT prolongation risk',
        'Known or clinically relevant risk of QT interval prolongation.',
        'boolean',
        false,
        true
    ),

    (
        'MEDICATION_RECONCILIATION_COMPLETE',
        'Medication reconciliation complete',
        'Whether medication reconciliation has been completed sufficiently for the current clinical decision.',
        'boolean',
        false,
        true
    )

ON CONFLICT (code) DO UPDATE
SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    data_type   = EXCLUDED.data_type,
    allow_multiple = EXCLUDED.allow_multiple,
    is_active   = EXCLUDED.is_active;


-- ============================================================================
-- 2. INVESTIGATION RESULT INTERPRETATION
--
-- One investigation may have many result codes.
-- One result code may establish MANY facts.
--
-- Example:
--
--     INV-CXR
--       RLL_CONSOLIDATION
--          -> RLL_DULLNESS
--          -> RLL_BRONCHIAL_BREATH_SOUNDS
--
-- The CPU therefore does NOT hard-code:
--
--     if CXR == consolidation -> ...
--
-- It asks the knowledge layer what facts the result establishes.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_result (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_id         uuid NOT NULL
        REFERENCES knowledge.investigation(id)
        ON DELETE CASCADE,

    result_code              text NOT NULL,

    result_label             text NOT NULL,

    result_category          text NOT NULL DEFAULT 'interpretation'
        CHECK (
            result_category IN (
                'normal',
                'abnormal',
                'positive',
                'negative',
                'indeterminate',
                'critical',
                'inconclusive',
                'other'
            )
        ),

    interpretation_type      text NOT NULL DEFAULT 'clinical'
        CHECK (
            interpretation_type IN (
                'clinical',
                'screening',
                'diagnostic',
                'severity',
                'safety',
                'monitoring',
                'incidental'
            )
        ),

    fact_definition_code     text
        REFERENCES clinical.fact_definition(code),

    fact_value               jsonb,

    unit                     text,

    severity                 text,

    interpretation           text,

    clinical_significance    text,

    follow_up_required       boolean NOT NULL DEFAULT false,

    urgent_review            boolean NOT NULL DEFAULT false,

    source_reference         text,

    evidence_level           text,

    status                   text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),

    created_at               timestamptz NOT NULL DEFAULT now(),

    updated_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_id,
        result_code,
        fact_definition_code
    )
);

COMMENT ON TABLE knowledge.investigation_result IS
'Universal investigation-result interpretation layer. A result establishes one or more structured clinical facts consumed by the same CPU substrate used by history, examination, monitoring and rules.';

COMMENT ON COLUMN knowledge.investigation_result.result_code IS
'Machine-stable result identifier supplied by the investigation/reporting system.';

COMMENT ON COLUMN knowledge.investigation_result.fact_value IS
'Structured value established by this result. JSON permits boolean, numeric, coded or structured values without changing the universal fact definition.';

COMMENT ON COLUMN knowledge.investigation_result.urgent_review IS
'If true, the result interpreter must emit an urgent clinical review signal rather than silently incorporating the result into routine reasoning.';

CREATE INDEX IF NOT EXISTS
    idx_knowledge_investigation_result_investigation
ON knowledge.investigation_result(investigation_id);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_investigation_result_code
ON knowledge.investigation_result(investigation_id, result_code);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_investigation_result_fact
ON knowledge.investigation_result(fact_definition_code);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_investigation_result_status
ON knowledge.investigation_result(status);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_investigation_result_urgent
ON knowledge.investigation_result(urgent_review)
WHERE urgent_review = true;


CREATE TRIGGER trg_knowledge_investigation_result_updated_at
BEFORE UPDATE ON knowledge.investigation_result
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 3. RESULT â†’ MULTIPLE FACTS
--
-- Kept as an explicit junction because one reported result can establish
-- several independent facts.
--
-- This is deliberately separated from investigation_result so the result
-- definition itself remains reusable and the CPU can traverse:
--
-- investigation
--      â†“
-- result
--      â†“
-- result_fact
--      â†“
-- fact_definition
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_result_fact (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_result_id  uuid NOT NULL
        REFERENCES knowledge.investigation_result(id)
        ON DELETE CASCADE,

    fact_definition_code     text NOT NULL
        REFERENCES clinical.fact_definition(code),

    value                    jsonb,

    polarity                 text NOT NULL DEFAULT 'positive'
        CHECK (polarity IN ('positive','negative')),

    weight                   numeric(4,3) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),

    certainty                numeric(4,3)
        CHECK (certainty >= 0 AND certainty <= 1),

    interpretation           text,

    is_primary               boolean NOT NULL DEFAULT false,

    created_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        investigation_result_id,
        fact_definition_code,
        polarity
    )
);

COMMENT ON TABLE knowledge.investigation_result_fact IS
'Universal mapping from an investigation result to every clinical fact established or contradicted by that result.';

CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_fact_result
ON knowledge.investigation_result_fact(investigation_result_id);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_fact_definition
ON knowledge.investigation_result_fact(fact_definition_code);


-- ============================================================================
-- 4. RESULT â†’ PHENOTYPE
--
-- Investigation results can directly support a phenotype without requiring
-- application code to know the medical meaning of the result.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_result_phenotype (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_result_id  uuid NOT NULL
        REFERENCES knowledge.investigation_result(id)
        ON DELETE CASCADE,

    phenotype_id             uuid NOT NULL
        REFERENCES knowledge.phenotype(id)
        ON DELETE CASCADE,

    relationship_type        text NOT NULL DEFAULT 'supports'
        CHECK (
            relationship_type IN (
                'supports',
                'contradicts',
                'defines',
                'suggests',
                'excludes'
            )
        ),

    weight                   numeric(4,3) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),

    rationale                text,

    UNIQUE (
        investigation_result_id,
        phenotype_id,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.investigation_result_phenotype IS
'Investigation results may support, contradict, define or exclude reusable phenotypes.';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_phenotype_result
ON knowledge.investigation_result_phenotype(investigation_result_id);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_phenotype_phenotype
ON knowledge.investigation_result_phenotype(phenotype_id);


-- ============================================================================
-- 5. RESULT â†’ CONDITION
--
-- This does NOT mean the result diagnoses a disease automatically.
-- It represents a knowledge-level relationship that the CPU combines with
-- the complete patient state.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_result_condition (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_result_id  uuid NOT NULL
        REFERENCES knowledge.investigation_result(id)
        ON DELETE CASCADE,

    condition_id             uuid NOT NULL
        REFERENCES knowledge.condition(id)
        ON DELETE CASCADE,

    relationship_type        text NOT NULL DEFAULT 'supports'
        CHECK (
            relationship_type IN (
                'supports',
                'contradicts',
                'suggests',
                'excludes',
                'severity_marker',
                'complication_marker'
            )
        ),

    weight                   numeric(4,3) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),

    rationale                text,

    evidence_level           text,

    UNIQUE (
        investigation_result_id,
        condition_id,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.investigation_result_condition IS
'Investigation-result relationships to conditions. These are probabilistic/clinical knowledge edges and never constitute an automatic diagnosis.';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_condition_result
ON knowledge.investigation_result_condition(investigation_result_id);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_condition_condition
ON knowledge.investigation_result_condition(condition_id);


-- ============================================================================
-- 6. INVESTIGATION RESULT SAFETY SIGNALS
--
-- Results can generate safety events independently of diagnosis.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.investigation_result_safety (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    investigation_result_id  uuid NOT NULL
        REFERENCES knowledge.investigation_result(id)
        ON DELETE CASCADE,

    safety_code              text NOT NULL,

    severity                 text NOT NULL DEFAULT 'warning'
        CHECK (
            severity IN (
                'information',
                'warning',
                'urgent',
                'emergency'
            )
        ),

    trigger_condition        jsonb,

    instruction              text NOT NULL,

    escalation_required      boolean NOT NULL DEFAULT false,

    UNIQUE (
        investigation_result_id,
        safety_code
    )
);

COMMENT ON TABLE knowledge.investigation_result_safety IS
'Result-triggered safety signals independent of disease diagnosis.';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_result_safety_result
ON knowledge.investigation_result_safety(investigation_result_id);


-- ============================================================================
-- 7. SAFETY KNOWLEDGE â€” MEDICATION CONTRAINDICATION / CAUTION LAYER
--
-- The medication table contains reusable drug identity.
-- This table contains patient-state-dependent safety logic.
--
-- Example:
--
--     DRUG_ALLERGY = penicillin
--              +
--     MED-AMOXICILLIN
--              â†“
--     BLOCK / REVIEW
--
-- The CPU does not hard-code the relationship.
-- ============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_safety_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_safety_rule (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_id            uuid NOT NULL
        REFERENCES knowledge.medication(id)
        ON DELETE CASCADE,

    safety_fact_code          text NOT NULL
        REFERENCES clinical.fact_definition(code),

    operator                  text NOT NULL DEFAULT 'eq'
        CHECK (
            operator IN (
                'eq',
                'neq',
                'gt',
                'gte',
                'lt',
                'lte',
                'in',
                'contains',
                'exists'
            )
        ),

    value                     jsonb,

    action_type               text NOT NULL
        CHECK (
            action_type IN (
                'block',
                'contraindication',
                'avoid',
                'caution',
                'dose_review',
                'monitor',
                'specialist_review',
                'alternative_required'
            )
        ),

    severity                  text NOT NULL DEFAULT 'warning'
        CHECK (
            severity IN (
                'information',
                'warning',
                'urgent',
                'critical'
            )
        ),

    rationale                 text,

    recommendation             text,

    evidence_source            text,

    evidence_level             text,

    is_verified                boolean NOT NULL DEFAULT false,

    status                    text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),

    created_at                timestamptz NOT NULL DEFAULT now(),

    updated_at                timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        medication_id,
        safety_fact_code,
        operator,
        value,
        action_type
    )
);

COMMENT ON TABLE knowledge.medication_safety_rule IS
'Patient-state-dependent medication safety rules. The SafetyEngine evaluates these against universal clinical facts before treatment recommendations are emitted.';

CREATE INDEX IF NOT EXISTS
    idx_knowledge_medication_safety_medication
ON knowledge.medication_safety_rule(medication_id);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_medication_safety_fact
ON knowledge.medication_safety_rule(safety_fact_code);


CREATE TRIGGER trg_knowledge_medication_safety_updated_at
BEFORE UPDATE ON knowledge.medication_safety_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 8. CONDITION â†’ SAFETY FACT
--
-- Some patient factors change the diagnostic/management pathway of a
-- condition. These are universal condition-context relationships rather than
-- duplicated condition-specific facts.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.condition_safety_factor (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    condition_id             uuid NOT NULL
        REFERENCES knowledge.condition(id)
        ON DELETE CASCADE,

    safety_fact_code         text NOT NULL
        REFERENCES clinical.fact_definition(code),

    relationship_type        text NOT NULL DEFAULT 'modifier'
        CHECK (
            relationship_type IN (
                'modifier',
                'risk',
                'contraindication',
                'severity',
                'diagnostic_modifier',
                'management_modifier'
            )
        ),

    weight                   numeric(4,3) NOT NULL DEFAULT 1.0
        CHECK (weight >= 0 AND weight <= 1),

    rationale                text,

    UNIQUE (
        condition_id,
        safety_fact_code,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.condition_safety_factor IS
'Universal safety/context factors that modify interpretation or management of a condition.';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_condition_safety_factor_condition
ON knowledge.condition_safety_factor(condition_id);

CREATE INDEX IF NOT EXISTS
    idx_knowledge_condition_safety_factor_fact
ON knowledge.condition_safety_factor(safety_fact_code);


-- ============================================================================
-- 9. HARDEN MEDICATION DOSE REFERENCES
--
-- A dose reference must never silently become actionable if it has not been
-- clinically verified.
-- ============================================================================

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        dose_unit text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        dose_basis text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        maximum_daily_expression text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        verification_status text NOT NULL DEFAULT 'unverified';

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        verified_by text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        verified_at timestamptz;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        jurisdiction text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS
        formulary_reference text;


DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_drug_dose_verification_status'
    ) THEN
        ALTER TABLE knowledge.drug_dose_reference
        ADD CONSTRAINT chk_drug_dose_verification_status
        CHECK (
            verification_status IN (
                'unverified',
                'under_review',
                'verified',
                'retired'
            )
        );
    END IF;
END
$$;


-- ============================================================================
-- 10. SAFETY OVERRIDE / GUARD
--
-- A local configuration must never be able to silently remove a universal
-- safety restriction.
--
-- This table identifies safety constraints that cannot be weakened by ordinary
-- facility configuration.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.safety_guard (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    guard_code               text NOT NULL UNIQUE,

    target_type              text NOT NULL,

    target_id                uuid,

    guard_type               text NOT NULL
        CHECK (
            guard_type IN (
                'hard_stop',
                'mandatory_review',
                'mandatory_confirmation',
                'mandatory_monitoring'
            )
        ),

    description              text NOT NULL,

    minimum_action            text,

    status                   text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','retired')),

    created_at               timestamptz NOT NULL DEFAULT now(),

    updated_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.safety_guard IS
'Non-bypassable clinical safety constraints. Local configuration may add stricter controls but must not silently remove a universal hard safety guard.';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_safety_guard_target
ON knowledge.safety_guard(target_type, target_id);


CREATE TRIGGER trg_knowledge_safety_guard_updated_at
BEFORE UPDATE ON knowledge.safety_guard
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 11. HARDEN KNOWLEDGE OVERRIDES
--
-- Facility/clinician overrides may modify recommendation behavior, but they
-- must remain explicit, versioned and reviewable.
-- ============================================================================

ALTER TABLE knowledge.knowledge_override
    ADD COLUMN IF NOT EXISTS
        override_type text NOT NULL DEFAULT 'configuration';

ALTER TABLE knowledge.knowledge_override
    ADD COLUMN IF NOT EXISTS
        approval_status text NOT NULL DEFAULT 'pending';

ALTER TABLE knowledge.knowledge_override
    ADD COLUMN IF NOT EXISTS
        approved_by text;

ALTER TABLE knowledge.knowledge_override
    ADD COLUMN IF NOT EXISTS
        approved_at timestamptz;

ALTER TABLE knowledge.knowledge_override
    ADD COLUMN IF NOT EXISTS
        review_required boolean NOT NULL DEFAULT true;

ALTER TABLE knowledge.knowledge_override
    ADD COLUMN IF NOT EXISTS
        change_summary text;


DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_knowledge_override_type'
    ) THEN
        ALTER TABLE knowledge.knowledge_override
        ADD CONSTRAINT chk_knowledge_override_type
        CHECK (
            override_type IN (
                'configuration',
                'priority',
                'threshold',
                'availability',
                'workflow',
                'recommendation',
                'documentation'
            )
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_knowledge_override_approval'
    ) THEN
        ALTER TABLE knowledge.knowledge_override
        ADD CONSTRAINT chk_knowledge_override_approval
        CHECK (
            approval_status IN (
                'pending',
                'approved',
                'rejected'
            )
        );
    END IF;
END
$$;


CREATE INDEX IF NOT EXISTS
    idx_knowledge_override_active_resolution
ON knowledge.knowledge_override(
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    status,
    effective_from,
    effective_to
);


-- ============================================================================
-- 12. REPLACE ACTIVE OVERRIDE RESOLUTION WITH ENTITY-AWARE RESOLUTION
--
-- The previous view ranked scopes globally. That can accidentally select a
-- clinician/facility override belonging to a DIFFERENT entity.
--
-- The CPU therefore needs runtime scope identity.
--
-- This view exposes all currently active overrides. The runtime resolver must
-- select the highest-precedence row applicable to the current organization,
-- department, facility and clinician.
-- ============================================================================

DROP VIEW IF EXISTS knowledge.active_override;

CREATE VIEW knowledge.active_override AS
SELECT
    o.id,
    o.override_code,
    o.target_type,
    o.target_id,
    o.scope_code,
    o.scope_entity_id,
    o.config,
    o.reason,
    o.version,
    o.supersedes_id,
    o.override_type,
    o.approval_status,
    o.approved_by,
    o.approved_at,
    o.review_required,
    o.change_summary,
    o.effective_from,
    o.effective_to
FROM knowledge.knowledge_override o
WHERE o.status = 'active'
  AND o.effective_from <= now()
  AND (
        o.effective_to IS NULL
        OR o.effective_to >= now()
      )
  AND (
        o.approval_status = 'approved'
        OR o.review_required = false
      );

COMMENT ON VIEW knowledge.active_override IS
'All currently applicable approved knowledge overrides. Runtime scope resolution must apply entity-aware precedence rather than globally selecting a facility or clinician override.';


-- ============================================================================
-- 13. UNIVERSAL INVESTIGATION RESULT VIEW
--
-- Fast read path for ResultInterpreter.
-- ============================================================================

CREATE OR REPLACE VIEW knowledge.investigation_result_interpretation AS
SELECT
    ir.id,
    ir.investigation_id,
    i.investigation_code,
    i.canonical_name AS investigation_name,

    ir.result_code,
    ir.result_label,
    ir.result_category,
    ir.interpretation_type,

    COALESCE(
        ir.fact_definition_code,
        irf.fact_definition_code
    ) AS fact_definition_code,

    COALESCE(
        ir.fact_value,
        irf.value
    ) AS fact_value,

    ir.unit,
    ir.severity,
    ir.interpretation,
    ir.clinical_significance,
    ir.follow_up_required,
    ir.urgent_review,

    irf.polarity,
    irf.weight,
    irf.certainty,
    irf.is_primary,

    ir.status

FROM knowledge.investigation_result ir

JOIN knowledge.investigation i
    ON i.id = ir.investigation_id

LEFT JOIN knowledge.investigation_result_fact irf
    ON irf.investigation_result_id = ir.id

WHERE ir.status = 'active';


COMMENT ON VIEW knowledge.investigation_result_interpretation IS
'Optimized ResultInterpreter read model: investigation result â†’ structured facts with interpretation and safety metadata.';


-- ============================================================================
-- 14. UNIVERSAL MEDICATION SAFETY READ MODEL
-- ============================================================================

CREATE OR REPLACE VIEW knowledge.medication_safety_intelligence AS
SELECT
    m.id AS medication_id,
    m.medication_code,
    m.generic_name,

    msr.id AS safety_rule_id,
    msr.safety_fact_code,
    msr.operator,
    msr.value,
    msr.action_type,
    msr.severity,
    msr.rationale,
    msr.recommendation,
    msr.evidence_source,
    msr.evidence_level,
    msr.is_verified,
    msr.status

FROM knowledge.medication m

JOIN knowledge.medication_safety_rule msr
    ON msr.medication_id = m.id

WHERE m.status = 'active'
  AND msr.status = 'active';


COMMENT ON VIEW knowledge.medication_safety_intelligence IS
'Fast SafetyEngine read model for medication-versus-patient-state evaluation.';


-- ============================================================================
-- 15. UNIVERSAL PATIENT SAFETY FACT INDEX
--
-- Provides a single semantic family for the CPU.
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge.safety_factor (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    fact_definition_code     text NOT NULL UNIQUE
        REFERENCES clinical.fact_definition(code),

    factor_category          text NOT NULL
        CHECK (
            factor_category IN (
                'allergy',
                'pregnancy',
                'lactation',
                'renal',
                'hepatic',
                'bleeding',
                'immunologic',
                'medication',
                'cardiac',
                'other'
            )
        ),

    canonical_name           text NOT NULL,

    description              text,

    affects_prescribing      boolean NOT NULL DEFAULT false,

    affects_investigation    boolean NOT NULL DEFAULT false,

    affects_diagnosis        boolean NOT NULL DEFAULT false,

    affects_monitoring       boolean NOT NULL DEFAULT false,

    status                   text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','deprecated')),

    created_at               timestamptz NOT NULL DEFAULT now(),

    updated_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.safety_factor IS
'Universal registry of patient-state factors that can modify diagnosis, investigation, prescribing, monitoring or disposition.';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_safety_factor_category
ON knowledge.safety_factor(factor_category);


CREATE TRIGGER trg_knowledge_safety_factor_updated_at
BEFORE UPDATE ON knowledge.safety_factor
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 16. REGISTER CORE SAFETY FACTORS
-- ============================================================================

INSERT INTO knowledge.safety_factor
    (
        fact_definition_code,
        factor_category,
        canonical_name,
        description,
        affects_prescribing,
        affects_investigation,
        affects_diagnosis,
        affects_monitoring
    )
VALUES

    (
        'DRUG_ALLERGY',
        'allergy',
        'Drug allergy',
        'Medication allergy affecting treatment selection.',
        true,
        false,
        false,
        true
    ),

    (
        'PREGNANT',
        'pregnancy',
        'Pregnancy',
        'Current pregnancy status affecting investigation, diagnosis and treatment.',
        true,
        true,
        true,
        true
    ),

    (
        'LACTATING',
        'lactation',
        'Lactation',
        'Current breastfeeding/lactation status affecting treatment selection.',
        true,
        false,
        false,
        false
    ),

    (
        'RENAL_IMPAIRMENT',
        'renal',
        'Renal impairment',
        'Renal dysfunction affecting drug selection, dosing, fluid management and monitoring.',
        true,
        false,
        false,
        true
    ),

    (
        'HEPATIC_IMPAIRMENT',
        'hepatic',
        'Hepatic impairment',
        'Hepatic dysfunction affecting drug selection, dosing and monitoring.',
        true,
        false,
        false,
        true
    ),

    (
        'ANTICOAGULANT_USE',
        'medication',
        'Anticoagulant use',
        'Current anticoagulant therapy affecting procedures, bleeding risk and medication selection.',
        true,
        true,
        false,
        true
    ),

    (
        'IMMUNOSUPPRESSION',
        'immunologic',
        'Immunosuppression',
        'Immunosuppressed state affecting differential diagnosis, investigation and treatment.',
        true,
        true,
        true,
        true
    ),

    (
        'BLEEDING_RISK',
        'bleeding',
        'Bleeding risk',
        'Increased bleeding risk affecting procedures, investigations and treatment.',
        true,
        true,
        false,
        true
    )

ON CONFLICT (fact_definition_code) DO UPDATE
SET
    factor_category       = EXCLUDED.factor_category,
    canonical_name        = EXCLUDED.canonical_name,
    description           = EXCLUDED.description,
    affects_prescribing   = EXCLUDED.affects_prescribing,
    affects_investigation = EXCLUDED.affects_investigation,
    affects_diagnosis     = EXCLUDED.affects_diagnosis,
    affects_monitoring    = EXCLUDED.affects_monitoring,
    status                = 'active';


-- ============================================================================
-- 17. SEED GENERIC CXR RESULT INTELLIGENCE
--
-- Only created when INV-CXR exists.
--
-- These are KNOWLEDGE mappings, not automatic diagnoses.
-- ============================================================================

INSERT INTO knowledge.investigation_result
(
    investigation_id,
    result_code,
    result_label,
    result_category,
    interpretation_type,
    fact_definition_code,
    fact_value,
    interpretation,
    clinical_significance
)
SELECT
    inv.id,
    r.result_code,
    r.result_label,
    r.result_category,
    r.interpretation_type,
    r.fact_definition_code,
    r.fact_value,
    r.interpretation,
    r.clinical_significance
FROM knowledge.investigation inv
CROSS JOIN (
    VALUES
    (
        'RLL_CONSOLIDATION',
        'Right lower lobe consolidation',
        'abnormal',
        'diagnostic',
        'RLL_DULLNESS',
        'true'::jsonb,
        'Right lower lobe airspace consolidation is reported.',
        'Supports a focal lower respiratory/alveolar process; must be integrated with clinical findings.'
    ),
    (
        'AIRSPACE_OPACITY',
        'Airspace opacity / infiltrate',
        'abnormal',
        'diagnostic',
        'RLL_DULLNESS',
        'true'::jsonb,
        'Airspace opacity is reported.',
        'Requires clinical correlation and does not independently establish etiology.'
    ),
    (
        'NORMAL',
        'No acute radiological abnormality',
        'normal',
        'diagnostic',
        NULL,
        NULL,
        'No acute radiological abnormality reported.',
        'Does not independently exclude clinically significant disease.'
    )
) AS r(
    result_code,
    result_label,
    result_category,
    interpretation_type,
    fact_definition_code,
    fact_value,
    interpretation,
    clinical_significance
)
WHERE inv.investigation_code = 'INV-CXR'

ON CONFLICT (
    investigation_id,
    result_code,
    fact_definition_code
)
DO UPDATE SET
    result_label          = EXCLUDED.result_label,
    result_category       = EXCLUDED.result_category,
    interpretation_type   = EXCLUDED.interpretation_type,
    fact_value            = EXCLUDED.fact_value,
    interpretation        = EXCLUDED.interpretation,
    clinical_significance = EXCLUDED.clinical_significance,
    updated_at            = now();


-- ============================================================================
-- 18. ADD MULTI-FACT CXR MAPPINGS
-- ============================================================================

INSERT INTO knowledge.investigation_result_fact
(
    investigation_result_id,
    fact_definition_code,
    value,
    polarity,
    weight,
    certainty,
    is_primary,
    interpretation
)
SELECT
    ir.id,
    x.fact_definition_code,
    x.value,
    x.polarity,
    x.weight,
    x.certainty,
    x.is_primary,
    x.interpretation
FROM knowledge.investigation_result ir
JOIN knowledge.investigation inv
    ON inv.id = ir.investigation_id
CROSS JOIN (
    VALUES
    (
        'RLL_DULLNESS',
        'true'::jsonb,
        'positive',
        1.0::numeric,
        1.0::numeric,
        true,
        'Result supports a right lower lobe focal abnormality.'
    ),
    (
        'RLL_BRONCHIAL_BREATH_SOUNDS',
        'true'::jsonb,
        'positive',
        0.85::numeric,
        1.0::numeric,
        false,
        'Radiological focal consolidation may correspond to focal bronchial breath sounds when clinically present; the imaging result does not replace physical examination.'
    )
) AS x(
    fact_definition_code,
    value,
    polarity,
    weight,
    certainty,
    is_primary,
    interpretation
)
WHERE inv.investigation_code = 'INV-CXR'
  AND ir.result_code = 'RLL_CONSOLIDATION'

ON CONFLICT (
    investigation_result_id,
    fact_definition_code,
    polarity
)
DO UPDATE SET
    value          = EXCLUDED.value,
    weight         = EXCLUDED.weight,
    certainty      = EXCLUDED.certainty,
    is_primary     = EXCLUDED.is_primary,
    interpretation = EXCLUDED.interpretation;


-- ============================================================================
-- 19. UNIVERSAL SAFETY GUARDS
--
-- These are architectural guardrails.
-- Actual drug-specific contraindications remain in medication_safety_rule.
-- ============================================================================

INSERT INTO knowledge.safety_guard
(
    guard_code,
    target_type,
    target_id,
    guard_type,
    description,
    minimum_action
)
VALUES

(
    'GUARD-UNVERIFIED-DOSE',
    'drug_dose_reference',
    NULL,
    'mandatory_confirmation',
    'An unverified dose reference must not silently become an executable prescribing instruction.',
    'Require verified jurisdiction-specific dose reference or clinician confirmation.'
),

(
    'GUARD-DRUG-ALLERGY',
    'medication',
    NULL,
    'mandatory_confirmation',
    'Documented medication allergy must be evaluated before a potentially implicated medication is recommended.',
    'Evaluate allergy relationship and require appropriate clinical review.'
),

(
    'GUARD-PREGNANCY',
    'medication',
    NULL,
    'mandatory_confirmation',
    'Pregnancy status must be considered before medication recommendations where pregnancy may alter safety.',
    'Evaluate pregnancy-specific medication safety before recommendation.'
),

(
    'GUARD-RENAL-FUNCTION',
    'medication',
    NULL,
    'mandatory_review',
    'Renal function must be considered where renal impairment may alter medication selection or dosing.',
    'Review renal dosing/safety before prescribing.'
),

(
    'GUARD-HEPATIC-FUNCTION',
    'medication',
    NULL,
    'mandatory_review',
    'Hepatic impairment must be considered where hepatic dysfunction may alter medication selection or dosing.',
    'Review hepatic dosing/safety before prescribing.'

)

ON CONFLICT (guard_code) DO UPDATE
SET
    guard_type      = EXCLUDED.guard_type,
    description     = EXCLUDED.description,
    minimum_action  = EXCLUDED.minimum_action,
    status          = 'active',
    updated_at      = now();


-- ============================================================================
-- 20. RESULT INTERPRETER CONTRACT VIEW
--
-- The CPU can use this as a single fast query surface.
-- ============================================================================

CREATE OR REPLACE VIEW knowledge.result_interpreter_contract AS
SELECT
    i.investigation_code,
    i.canonical_name AS investigation_name,

    ir.result_code,
    ir.result_label,
    ir.result_category,
    ir.interpretation_type,

    COALESCE(
        irf.fact_definition_code,
        ir.fact_definition_code
    ) AS fact_definition_code,

    COALESCE(
        irf.value,
        ir.fact_value
    ) AS fact_value,

    COALESCE(
        irf.polarity,
        'positive'
    ) AS polarity,

    COALESCE(
        irf.weight,
        1.0
    ) AS weight,

    irf.certainty,

    ir.interpretation,
    ir.clinical_significance,

    ir.follow_up_required,
    ir.urgent_review,

    ir.status

FROM knowledge.investigation_result ir

JOIN knowledge.investigation i
    ON i.id = ir.investigation_id

LEFT JOIN knowledge.investigation_result_fact irf
    ON irf.investigation_result_id = ir.id

WHERE ir.status = 'active';


COMMENT ON VIEW knowledge.result_interpreter_contract IS
'Canonical CPU read contract for investigation result â†’ clinical fact interpretation.';


-- ============================================================================
-- 21. SAFETY ENGINE CONTRACT VIEW
--
-- Fast path:
--
-- patient facts
--     Ã—
-- medication safety rules
--     â†“
-- safety action
-- ============================================================================

CREATE OR REPLACE VIEW knowledge.safety_engine_contract AS
SELECT
    m.medication_code,
    m.generic_name,

    msr.safety_fact_code,
    msr.operator,
    msr.value,

    msr.action_type,
    msr.severity,
    msr.rationale,
    msr.recommendation,

    msr.is_verified,
    msr.evidence_source,
    msr.evidence_level,

    sg.guard_code,
    sg.guard_type,
    sg.minimum_action

FROM knowledge.medication m

JOIN knowledge.medication_safety_rule msr
    ON msr.medication_id = m.id

LEFT JOIN knowledge.safety_guard sg
    ON sg.target_type = 'medication'
    AND (
        sg.target_id = m.id
        OR sg.target_id IS NULL
    )
    AND sg.status = 'active'

WHERE m.status = 'active'
  AND msr.status = 'active';


COMMENT ON VIEW knowledge.safety_engine_contract IS
'Canonical CPU read contract for medication safety evaluation against universal patient-state facts.';


-- ============================================================================
-- 22. PERFORMANCE INDEXES FOR CPU HOT PATH
-- ============================================================================

CREATE INDEX IF NOT EXISTS
    idx_knowledge_investigation_code
ON knowledge.investigation(investigation_code)
WHERE status = 'active';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_medication_code
ON knowledge.medication(medication_code)
WHERE status = 'active';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_fact_definition_code
ON clinical.fact_definition(code)
WHERE is_active = true;


CREATE INDEX IF NOT EXISTS
    idx_knowledge_condition_code
ON knowledge.condition(condition_code)
WHERE status = 'active';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_phenotype_code
ON knowledge.phenotype(phenotype_code)
WHERE status = 'active';


CREATE INDEX IF NOT EXISTS
    idx_knowledge_mechanism_code
ON knowledge.mechanism(mechanism_code)
WHERE status = 'active';


-- ============================================================================
-- 23. VALIDATION FUNCTIONS
--
-- Prevent clinically dangerous knowledge rows from being silently treated as
-- executable.
-- ============================================================================

CREATE OR REPLACE FUNCTION knowledge.is_dose_executable(
    p_dose_reference_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM knowledge.drug_dose_reference d
        WHERE d.id = p_dose_reference_id
          AND d.is_verified = true
          AND d.verification_status = 'verified'
    );
$$;


COMMENT ON FUNCTION knowledge.is_dose_executable(uuid) IS
'Returns true only for a clinically verified, non-retired dose reference.';


CREATE OR REPLACE FUNCTION knowledge.is_override_active(
    p_override_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM knowledge.knowledge_override o
        WHERE o.id = p_override_id
          AND o.status = 'active'
          AND o.approval_status = 'approved'
          AND o.effective_from <= now()
          AND (
              o.effective_to IS NULL
              OR o.effective_to >= now()
          )
    );
$$;


COMMENT ON FUNCTION knowledge.is_override_active(uuid) IS
'Determines whether an override is currently approved and temporally active.';


-- ============================================================================
-- 24. FINAL COMMENTS â€” ARCHITECTURAL CONTRACT
-- ============================================================================

COMMENT ON SCHEMA knowledge IS
'AMEXAN Universal Clinical Knowledge Layer. Shared concepts, facts, symptoms, signs, phenotypes, mechanisms, conditions, investigations, medications, protocols, monitoring, education, safety and configurable knowledge overrides form one composable clinical intelligence substrate.';

COMMIT;
