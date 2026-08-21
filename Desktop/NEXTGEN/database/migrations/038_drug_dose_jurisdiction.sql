-- =============================================================================
-- AMEXAN MEDICAL KNOWLEDGE COMPILER
-- R8 / MIGRATION 038
-- JURISDICTIONAL PHARMACOLOGY, PRESCRIBING, PROTOCOL & REAL-TIME MEDICATION
-- INTELLIGENCE LAYER
-- =============================================================================
--
-- PURPOSE
-- -------
-- Establishes the governed pharmacology and prescribing operating layer for
-- AMEXAN Clinical OS.
--
-- This migration does NOT hard-code clinical decisions into application code.
-- PostgreSQL stores the governed pharmacology/configuration catalogue.
-- The CPU evaluates the catalogue against the patient's structured clinical
-- state in real time.
--
-- CORE MODEL
-- ----------
--
-- CLINICAL STATE
--      â†“
-- patient / encounter / facts / phenotype / diagnosis / investigation
--      â†“
-- MEDICATION INTELLIGENCE
--      â†“
-- indication
-- contraindication
-- allergy
-- interaction
-- age
-- weight
-- renal function
-- hepatic function
-- pregnancy / lactation
-- route
-- formulation
-- dose
-- frequency
-- duration
-- maximum dose
-- monitoring
-- antimicrobial / stewardship rules
-- jurisdiction
-- formulary
--      â†“
-- PRESCRIPTION ENGINE
--      â†“
-- prescription proposal
--      â†“
-- safety gates
--      â†“
-- clinician authorization
--      â†“
-- prescription order
--      â†“
-- administration / dispensing / monitoring
--      â†“
-- AUDIT + PROVENANCE + REPLAY
--
-- MEDICAL LAW
-- ----------
-- 1. A medication is never prescribed from drug name alone.
-- 2. Dose is contextual: patient + indication + population + route +
--    formulation + jurisdiction + clinical state.
-- 3. A dose reference is knowledge, not an instruction to prescribe.
-- 4. Contraindications and safety exclusions are evaluated before action.
-- 5. Human authorization remains mandatory for medication orders unless an
--    explicitly governed workflow grants otherwise.
-- 6. Every clinically consequential medication decision is auditable.
-- 7. Every medication knowledge object is source-grounded and versioned.
-- 8. Jurisdictional rows override global rows only when an active governed
--    jurisdictional rule explicitly applies.
-- 9. Historical prescriptions are immutable clinical records.
-- 10. Amendments create lineage; they do not silently rewrite history.
-- 11. UI renders governed results. It does not invent doses or protocols.
-- 12. LLM / language models may assist language realization but are not the
--     source of pharmacological truth.
--
-- DEPENDENCIES
-- ------------
-- H1-H10 knowledge / governance architecture
-- knowledge.medication
-- knowledge.drug_dose_reference
-- knowledge.protocol_action
-- governance.jurisdiction
-- governance.population_context
-- governance.knowledge_object
-- governance.knowledge_object_version
-- governance.system_version
-- knowledge.source_claim
-- knowledge.fact_capture_method
--
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS knowledge;

COMMENT ON SCHEMA knowledge IS
'AMEXAN governed clinical knowledge catalogue including pharmacology, protocols,
prescribing, dosing, monitoring and medication safety.';


-- =============================================================================
-- 1. JURISDICTIONAL DOSE REFERENCE
-- =============================================================================

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS jurisdiction_code text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS indication_code text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS route text;

ALTER TABLE knowledge.drug_dose_reference
    DROP CONSTRAINT IF EXISTS
    drug_dose_reference_medication_id_population_indication_cod_key;

ALTER TABLE knowledge.drug_dose_reference
    ADD CONSTRAINT drug_dose_reference_jurisdiction_uk
    UNIQUE (
        medication_id,
        population,
        indication_code,
        route,
        jurisdiction_code
    );

UPDATE knowledge.drug_dose_reference
SET jurisdiction_code = 'JUR-GLOBAL'
WHERE jurisdiction_code IS NULL;

CREATE INDEX IF NOT EXISTS
idx_drug_dose_reference_jurisdiction
ON knowledge.drug_dose_reference(jurisdiction_code);


-- =============================================================================
-- 2. MEDICATION KNOWLEDGE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_knowledge (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_id       uuid,
    medication_code     text NOT NULL UNIQUE,

    generic_name        text NOT NULL,
    canonical_name      text NOT NULL,

    brand_names         text[] NOT NULL DEFAULT '{}',

    pharmacologic_class text,
    therapeutic_class   text,
    drug_family         text,

    active_ingredient   text,
    salt_form           text,

    mechanism_of_action text,
    therapeutic_effect  text,

    controlled_status   text NOT NULL DEFAULT 'NON_CONTROLLED'
        CHECK (
            controlled_status IN (
                'NON_CONTROLLED',
                'CONTROLLED',
                'RESTRICTED',
                'SPECIAL_AUTHORIZATION'
            )
        ),

    prescription_status text NOT NULL DEFAULT 'PRESCRIPTION'
        CHECK (
            prescription_status IN (
                'OTC',
                'PRESCRIPTION',
                'RESTRICTED_PRESCRIPTION',
                'HOSPITAL_ONLY',
                'SPECIALIST_ONLY'
            )
        ),

    antimicrobial       boolean NOT NULL DEFAULT false,

    high_alert          boolean NOT NULL DEFAULT false,

    look_alike_sound_alike boolean NOT NULL DEFAULT false,

    requires_weight     boolean NOT NULL DEFAULT false,
    requires_bsa        boolean NOT NULL DEFAULT false,
    requires_renal_assessment boolean NOT NULL DEFAULT false,
    requires_hepatic_assessment boolean NOT NULL DEFAULT false,

    therapeutic_index  text
        CHECK (
            therapeutic_index IS NULL OR
            therapeutic_index IN ('WIDE','MODERATE','NARROW')
        ),

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    lifecycle_status    text NOT NULL DEFAULT 'DRAFT'
        CHECK (
            lifecycle_status IN (
                'DRAFT',
                'CLINICALLY_REVIEWED',
                'VALIDATED',
                'APPROVED',
                'ACTIVE',
                'DEPRECATED',
                'RETIRED'
            )
        ),

    effective_from     date,
    effective_to       date,

    created_by         text,
    reviewed_by        text,
    approved_by        text,

    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.medication_knowledge IS
'Governed medication master record. Describes pharmacology and prescribing
characteristics without embedding patient-specific prescribing decisions.';

CREATE INDEX IF NOT EXISTS idx_med_knowledge_generic
ON knowledge.medication_knowledge(generic_name);

CREATE INDEX IF NOT EXISTS idx_med_knowledge_class
ON knowledge.medication_knowledge(therapeutic_class);

CREATE INDEX IF NOT EXISTS idx_med_knowledge_antimicrobial
ON knowledge.medication_knowledge(antimicrobial);

CREATE INDEX IF NOT EXISTS idx_med_knowledge_status
ON knowledge.medication_knowledge(lifecycle_status);

DROP TRIGGER IF EXISTS trg_medication_knowledge_updated_at
ON knowledge.medication_knowledge;

CREATE TRIGGER trg_medication_knowledge_updated_at
BEFORE UPDATE ON knowledge.medication_knowledge
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. MEDICATION INGREDIENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_ingredient (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    ingredient_name     text NOT NULL,

    strength_value      numeric(14,4),
    strength_unit       text,

    role                text NOT NULL DEFAULT 'ACTIVE'
        CHECK (
            role IN (
                'ACTIVE',
                'EXCIPIENT',
                'PRESERVATIVE',
                'DILUENT'
            )
        ),

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        medication_code,
        ingredient_name,
        role
    )
);


-- =============================================================================
-- 4. PHARMACEUTICAL FORM
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_formulation CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_formulation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    formulation_code    text NOT NULL UNIQUE,

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    dosage_form         text NOT NULL,

    route               text NOT NULL,

    concentration_value numeric(14,4),
    concentration_unit  text,

    strength_value      numeric(14,4),
    strength_unit       text,

    volume_value        numeric(14,4),
    volume_unit         text,

    release_type        text
        CHECK (
            release_type IS NULL OR
            release_type IN (
                'IMMEDIATE',
                'EXTENDED',
                'MODIFIED',
                'CONTROLLED',
                'ENTERIC',
                'DEPOT'
            )
        ),

    is_pediatric       boolean NOT NULL DEFAULT false,
    is_active          boolean NOT NULL DEFAULT true,

    source_claim_code  text
        REFERENCES knowledge.source_claim(claim_code),

    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_form_med
ON knowledge.medication_formulation(medication_code);

CREATE INDEX IF NOT EXISTS idx_med_form_route
ON knowledge.medication_formulation(route);

DROP TRIGGER IF EXISTS trg_medication_formulation_updated_at
ON knowledge.medication_formulation;

CREATE TRIGGER trg_medication_formulation_updated_at
BEFORE UPDATE ON knowledge.medication_formulation
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 5. ROUTES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_route CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_route (
    route_code          text PRIMARY KEY,
    canonical_name      text NOT NULL,
    parent_route_code   text REFERENCES knowledge.medication_route(route_code),
    enteral             boolean NOT NULL DEFAULT false,
    parenteral          boolean NOT NULL DEFAULT false,
    invasive            boolean NOT NULL DEFAULT false,
    requires_authorized_clinician boolean NOT NULL DEFAULT false,
    is_active            boolean NOT NULL DEFAULT true
);

INSERT INTO knowledge.medication_route
    (route_code, canonical_name, enteral, parenteral)
VALUES
    ('PO','Oral',true,false),
    ('SL','Sublingual',true,false),
    ('BUCCAL','Buccal',true,false),
    ('NG','Nasogastric',true,false),
    ('PEG','Gastrostomy',true,false),
    ('PR','Rectal',true,false),
    ('IV','Intravenous',false,true),
    ('IM','Intramuscular',false,true),
    ('SC','Subcutaneous',false,true),
    ('ID','Intradermal',false,true),
    ('IO','Intraosseous',false,true),
    ('TOPICAL','Topical',false,false),
    ('TRANSDERMAL','Transdermal',false,false),
    ('INHALATION','Inhaled',true,false),
    ('NEBULIZED','Nebulized',true,false),
    ('INTRANASAL','Intranasal',true,false),
    ('OPHTHALMIC','Ophthalmic',false,false),
    ('OTIC','Otic',false,false),
    ('VAGINAL','Vaginal',false,false)
ON CONFLICT (route_code) DO NOTHING;


-- =============================================================================
-- 6. INDICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_indication (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    indication_code     text NOT NULL,

    indication_type     text NOT NULL DEFAULT 'THERAPEUTIC'
        CHECK (
            indication_type IN (
                'THERAPEUTIC',
                'PROPHYLAXIS',
                'DISEASE_MODIFYING',
                'SYMPTOMATIC',
                'RESCUE',
                'DIAGNOSTIC'
            )
        ),

    first_line          boolean NOT NULL DEFAULT false,
    second_line         boolean NOT NULL DEFAULT false,
    alternative         boolean NOT NULL DEFAULT false,

    severity_min        text,
    severity_max        text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        medication_code,
        indication_code,
        jurisdiction_code
    )
);

CREATE INDEX IF NOT EXISTS idx_med_indication_code
ON knowledge.medication_indication(indication_code);


-- =============================================================================
-- 7. DOSE REFERENCE â€” EXTENDED GOVERNED MODEL
-- =============================================================================

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS dose_basis text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS dose_min numeric(14,4);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS dose_max numeric(14,4);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS dose_unit text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS frequency_code text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS duration_min_days numeric(8,2);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS duration_max_days numeric(8,2);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS maximum_single_dose numeric(14,4);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS maximum_daily_dose numeric(14,4);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS maximum_course_dose numeric(14,4);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS dose_frequency_unit text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS bsa_based boolean NOT NULL DEFAULT false;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS weight_based boolean NOT NULL DEFAULT false;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS age_min_days integer;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS age_max_days integer;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS weight_min_kg numeric(8,3);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS weight_max_kg numeric(8,3);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS dose_expression jsonb;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS administration_notes text;

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS source_claim_code text
        REFERENCES knowledge.source_claim(claim_code);

ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

CREATE INDEX IF NOT EXISTS idx_dose_ref_jurisdiction
ON knowledge.drug_dose_reference(jurisdiction_code);

CREATE INDEX IF NOT EXISTS idx_dose_ref_indication
ON knowledge.drug_dose_reference(indication_code);


-- =============================================================================
-- 8. FREQUENCY CATALOGUE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_frequency (
    frequency_code      text PRIMARY KEY,

    canonical_label     text NOT NULL,

    doses_per_day       numeric(8,3),

    interval_hours      numeric(8,3),

    timing_pattern      jsonb,

    prn_allowed        boolean NOT NULL DEFAULT false,

    maximum_daily_administrations integer,

    clinical_description text,

    is_active           boolean NOT NULL DEFAULT true
);

INSERT INTO knowledge.medication_frequency
    (frequency_code, canonical_label, doses_per_day, interval_hours)
VALUES
    ('ONCE','once daily',1,24),
    ('BD','twice daily',2,12),
    ('TDS','three times daily',3,8),
    ('QDS','four times daily',4,6),
    ('Q4H','every 4 hours',6,4),
    ('Q6H','every 6 hours',4,6),
    ('Q8H','every 8 hours',3,8),
    ('Q12H','every 12 hours',2,12),
    ('STAT','single immediate dose',1,NULL),
    ('PRN','as required',NULL,NULL),
    ('CONTINUOUS','continuous infusion',NULL,NULL)
ON CONFLICT (frequency_code) DO NOTHING;


-- =============================================================================
-- 9. DOSE ADJUSTMENT â€” RENAL
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_renal_adjustment (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    indication_code     text,

    renal_measure       text NOT NULL
        CHECK (
            renal_measure IN (
                'EGFR',
                'CRCL',
                'SERUM_CREATININE',
                'DIALYSIS',
                'HEMODIALYSIS',
                'PERITONEAL_DIALYSIS'
            )
        ),

    lower_threshold     numeric(14,4),
    upper_threshold     numeric(14,4),

    threshold_unit      text,

    adjustment_type     text NOT NULL
        CHECK (
            adjustment_type IN (
                'NO_CHANGE',
                'DOSE_REDUCTION',
                'INTERVAL_EXTENSION',
                'DOSE_AND_INTERVAL',
                'AVOID',
                'CONTRAINDICATED',
                'POST_DIALYSIS_DOSE'
            )
        ),

    adjusted_dose_expression jsonb,

    dialysis_type       text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_renal_adjustment_med
ON knowledge.medication_renal_adjustment(medication_code);


-- =============================================================================
-- 10. HEPATIC ADJUSTMENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_hepatic_adjustment (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    severity_class      text NOT NULL,

    assessment_system   text,

    adjustment_type     text NOT NULL
        CHECK (
            adjustment_type IN (
                'NO_CHANGE',
                'DOSE_REDUCTION',
                'INTERVAL_EXTENSION',
                'DOSE_AND_INTERVAL',
                'AVOID',
                'CONTRAINDICATED'
            )
        ),

    adjusted_dose_expression jsonb,

    monitoring_required boolean NOT NULL DEFAULT false,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_hepatic_adjustment_med
ON knowledge.medication_hepatic_adjustment(medication_code);


-- =============================================================================
-- 11. AGE / POPULATION RESTRICTIONS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_population_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_population_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    population_code     text,

    age_min_days        integer,
    age_max_days        integer,

    weight_min_kg       numeric(8,3),
    weight_max_kg       numeric(8,3),

    pregnancy_status    text,
    lactation_status    text,

    rule_type           text NOT NULL
        CHECK (
            rule_type IN (
                'ALLOWED',
                'CAUTION',
                'DO_NOT_USE',
                'SPECIALIST_ONLY',
                'SPECIAL_DOSE'
            )
        ),

    rationale           text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 12. CONTRAINDICATIONS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_contraindication CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_contraindication (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    contraindication_code text NOT NULL,

    trigger_type        text NOT NULL
        CHECK (
            trigger_type IN (
                'DIAGNOSIS',
                'FACT',
                'ALLERGY',
                'LAB',
                'AGE',
                'PREGNANCY',
                'RENAL',
                'HEPATIC',
                'INTERACTION',
                'PHYSIOLOGIC_STATE'
            )
        ),

    trigger_expression  jsonb NOT NULL,

    severity            text NOT NULL
        CHECK (
            severity IN (
                'ABSOLUTE',
                'MAJOR',
                'MODERATE',
                'PRECAUTION'
            )
        ),

    action              text NOT NULL
        CHECK (
            action IN (
                'BLOCK',
                'WARN',
                'REQUIRE_OVERRIDE',
                'REQUIRE_SPECIALIST'
            )
        ),

    rationale           text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_contra_med
ON knowledge.medication_contraindication(medication_code);


-- =============================================================================
-- 13. ALLERGY / CROSS-REACTIVITY
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_allergy_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_allergy_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    allergen_code       text NOT NULL,

    relationship_type   text NOT NULL
        CHECK (
            relationship_type IN (
                'DIRECT',
                'CLASS',
                'CROSS_REACTIVITY',
                'EXCIPIENT'
            )
        ),

    reaction_severity   text
        CHECK (
            reaction_severity IS NULL OR
            reaction_severity IN (
                'MILD',
                'MODERATE',
                'SEVERE',
                'ANAPHYLAXIS'
            )
        ),

    action              text NOT NULL
        CHECK (
            action IN (
                'BLOCK',
                'WARN',
                'REQUIRE_ASSESSMENT'
            )
        ),

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 14. DRUG-DRUG INTERACTION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_interaction CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_interaction (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_a_code   text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    medication_b_code   text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    interaction_type    text NOT NULL
        CHECK (
            interaction_type IN (
                'PHARMACOKINETIC',
                'PHARMACODYNAMIC',
                'DUPLICATION',
                'ADDITIVE_TOXICITY',
                'ANTAGONISM',
                'ABSORPTION'
            )
        ),

    severity            text NOT NULL
        CHECK (
            severity IN (
                'MAJOR',
                'MODERATE',
                'MINOR',
                'INFORMATIONAL'
            )
        ),

    clinical_effect     text NOT NULL,

    mechanism           text,

    management          text,

    action              text NOT NULL
        CHECK (
            action IN (
                'BLOCK',
                'WARN',
                'MONITOR',
                'ADJUST_DOSE',
                'SEPARATE_ADMINISTRATION',
                'NO_ACTION'
            )
        ),

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        medication_a_code,
        medication_b_code
    )
);

CREATE INDEX IF NOT EXISTS idx_med_interaction_a
ON knowledge.medication_interaction(medication_a_code);

CREATE INDEX IF NOT EXISTS idx_med_interaction_b
ON knowledge.medication_interaction(medication_b_code);


-- =============================================================================
-- 15. DRUG-DISEASE INTERACTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_disease_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    condition_code      text NOT NULL,

    effect              text NOT NULL,

    severity            text NOT NULL
        CHECK (
            severity IN (
                'MAJOR',
                'MODERATE',
                'MINOR',
                'PRECAUTION'
            )
        ),

    action              text NOT NULL
        CHECK (
            action IN (
                'BLOCK',
                'WARN',
                'MONITOR',
                'ADJUST',
                'REQUIRE_SPECIALIST'
            )
        ),

    rationale           text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 16. ADVERSE DRUG REACTIONS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_adverse_effect CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_adverse_effect (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    adverse_effect_code text NOT NULL,
    canonical_name      text NOT NULL,

    frequency_class     text,

    severity             text
        CHECK (
            severity IN (
                'MILD',
                'MODERATE',
                'SEVERE',
                'LIFE_THREATENING'
            )
        ),

    dose_related        boolean,
    time_to_onset       text,

    action_if_detected text,

    source_claim_code  text
        REFERENCES knowledge.source_claim(claim_code),

    status             text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    UNIQUE (
        medication_code,
        adverse_effect_code
    )
);


-- =============================================================================
-- 17. MONITORING RULES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_monitoring_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_monitoring_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    monitoring_code     text NOT NULL,

    parameter_type      text NOT NULL
        CHECK (
            parameter_type IN (
                'VITAL_SIGN',
                'LABORATORY',
                'ECG',
                'CLINICAL_SYMPTOM',
                'THERAPEUTIC_LEVEL',
                'ORGAN_FUNCTION',
                'OTHER'
            )
        ),

    parameter_code      text NOT NULL,

    baseline_required   boolean NOT NULL DEFAULT false,

    monitoring_interval jsonb,

    threshold_expression jsonb,

    action_on_abnormal  text,

    urgency             text
        CHECK (
            urgency IS NULL OR
            urgency IN (
                'ROUTINE',
                'URGENT',
                'IMMEDIATE'
            )
        ),

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_monitoring_med
ON knowledge.medication_monitoring_rule(medication_code);


-- =============================================================================
-- 18. THERAPEUTIC DRUG MONITORING
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.therapeutic_drug_monitoring (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    analyte_code        text NOT NULL,

    target_range_low    numeric(14,4),
    target_range_high   numeric(14,4),

    unit                text,

    sampling_time_rule  jsonb,

    toxicity_threshold  numeric(14,4),

    subtherapeutic_threshold numeric(14,4),

    action_expression   jsonb,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 19. ADMINISTRATION RULES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_administration_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_administration_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    formulation_code   text
        REFERENCES knowledge.medication_formulation(formulation_code),

    route_code          text NOT NULL
        REFERENCES knowledge.medication_route(route_code),

    preparation         text,

    dilution            jsonb,

    infusion_rate       jsonb,

    administration_time text,

    food_relationship   text,

    handling_instruction text,

    compatibility       jsonb,

    incompatibility     jsonb,

    stability           jsonb,

    administration_warning text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 20. DUPLICATION / THERAPEUTIC CLASS RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.therapeutic_duplication_rule (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    class_code          text NOT NULL,

    medication_code_a   text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    medication_code_b   text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    duplication_type    text NOT NULL
        CHECK (
            duplication_type IN (
                'THERAPEUTIC_DUPLICATION',
                'INGREDIENT_DUPLICATION',
                'CLASS_DUPLICATION'
            )
        ),

    action              text NOT NULL
        CHECK (
            action IN (
                'BLOCK',
                'WARN',
                'ALLOW_WITH_REASON'
            )
        ),

    rationale           text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (
        medication_code_a,
        medication_code_b,
        duplication_type
    )
);


-- =============================================================================
-- 21. PROTOCOLS
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_protocol (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    protocol_code       text NOT NULL UNIQUE,

    canonical_name      text NOT NULL,

    clinical_domain     text NOT NULL,

    condition_code      text,

    population          text,

    purpose             text,

    entry_criteria      jsonb NOT NULL DEFAULT '{}',

    exclusion_criteria  jsonb NOT NULL DEFAULT '{}',

    escalation_criteria jsonb NOT NULL DEFAULT '{}',

    discharge_criteria  jsonb NOT NULL DEFAULT '{}',

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    evidence_level_code text
        REFERENCES governance.evidence_metadata(evidence_level_code),

    status              text NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'clinical_review',
                'approved',
                'active',
                'superseded',
                'retired'
            )
        ),

    version_no          integer NOT NULL DEFAULT 1,

    effective_from      date,
    effective_to        date,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_protocol_condition
ON knowledge.clinical_protocol(condition_code);

CREATE INDEX IF NOT EXISTS idx_clinical_protocol_jurisdiction
ON knowledge.clinical_protocol(jurisdiction_code);


DROP TRIGGER IF EXISTS trg_clinical_protocol_updated_at
ON knowledge.clinical_protocol;

CREATE TRIGGER trg_clinical_protocol_updated_at
BEFORE UPDATE ON knowledge.clinical_protocol
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 22. PROTOCOL STEPS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.protocol_step CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.protocol_step (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    protocol_code       text NOT NULL
        REFERENCES knowledge.clinical_protocol(protocol_code)
        ON DELETE CASCADE,

    step_code           text NOT NULL,

    sequence_no         integer NOT NULL,

    phase               text
        CHECK (
            phase IS NULL OR
            phase IN (
                'ASSESS',
                'DIAGNOSE',
                'INVESTIGATE',
                'TREAT',
                'MONITOR',
                'REASSESS',
                'ESCALATE',
                'DISCHARGE',
                'FOLLOW_UP'
            )
        ),

    title               text NOT NULL,

    entry_condition     jsonb,

    exit_condition      jsonb,

    action_type         text NOT NULL
        CHECK (
            action_type IN (
                'investigate',
                'medicate',
                'monitor',
                'educate',
                'refer',
                'admit',
                'advice',
                'order_set',
                'score',
                'reassess',
                'discharge',
                'follow_up',
                'alert'
            )
        ),

    mandatory           boolean NOT NULL DEFAULT false,

    human_authorization_required boolean NOT NULL DEFAULT false,

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        protocol_code,
        step_code
    ),

    UNIQUE (
        protocol_code,
        sequence_no
    )
);

CREATE INDEX IF NOT EXISTS idx_protocol_step_protocol
ON knowledge.protocol_step(protocol_code, sequence_no);


-- =============================================================================
-- 23. PROTOCOL MEDICATION ACTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.protocol_medication_action (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    protocol_step_id    uuid NOT NULL
        REFERENCES knowledge.protocol_step(id)
        ON DELETE CASCADE,

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    indication_code     text,

    dose_reference_id   uuid
        REFERENCES knowledge.drug_dose_reference(id),

    route_code          text
        REFERENCES knowledge.medication_route(route_code),

    frequency_code      text
        REFERENCES knowledge.medication_frequency(frequency_code),

    duration_expression jsonb,

    condition_expression jsonb,

    preferred           boolean NOT NULL DEFAULT false,

    alternative         boolean NOT NULL DEFAULT false,

    contraindication_gate boolean NOT NULL DEFAULT true,

    interaction_gate    boolean NOT NULL DEFAULT true,

    renal_gate          boolean NOT NULL DEFAULT true,

    hepatic_gate        boolean NOT NULL DEFAULT true,

    allergy_gate        boolean NOT NULL DEFAULT true,

    authorization_required boolean NOT NULL DEFAULT true,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 24. GUIDELINE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_guideline (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    guideline_code      text NOT NULL UNIQUE,

    canonical_name      text NOT NULL,

    issuing_body        text,

    specialty           text,

    publication_date    date,

    revision_date       date,

    version_label       text,

    scope               text,

    recommendations    jsonb,

    source_claim_code  text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code  text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    evidence_level_code text
        REFERENCES governance.evidence_metadata(evidence_level_code),

    status              text NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'review',
                'approved',
                'active',
                'superseded',
                'retired'
            )
        ),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_clinical_guideline_updated_at
ON knowledge.clinical_guideline;

CREATE TRIGGER trg_clinical_guideline_updated_at
BEFORE UPDATE ON knowledge.clinical_guideline
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 25. GUIDELINE RECOMMENDATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.guideline_recommendation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    guideline_code      text NOT NULL
        REFERENCES knowledge.clinical_guideline(guideline_code)
        ON DELETE CASCADE,

    recommendation_code text NOT NULL,

    clinical_condition_code text,

    population_code     text,

    recommendation_text text NOT NULL,

    recommendation_type text NOT NULL
        CHECK (
            recommendation_type IN (
                'ASSESSMENT',
                'DIAGNOSIS',
                'INVESTIGATION',
                'TREATMENT',
                'MONITORING',
                'REFERRAL',
                'PREVENTION',
                'FOLLOW_UP'
            )
        ),

    strength           text,

    evidence_level     text,

    trigger_expression jsonb,

    source_claim_code  text
        REFERENCES knowledge.source_claim(claim_code),

    status             text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    UNIQUE (
        guideline_code,
        recommendation_code
    )
);


-- =============================================================================
-- 26. PRESCRIPTION TEMPLATE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_template (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    template_code       text NOT NULL UNIQUE,

    template_name       text NOT NULL,

    setting             text
        CHECK (
            setting IS NULL OR
            setting IN (
                'OUTPATIENT',
                'INPATIENT',
                'EMERGENCY',
                'OPERATING_THEATRE',
                'ICU',
                'MATERNITY',
                'PAEDIATRIC',
                'DISCHARGE'
            )
        ),

    required_fields     jsonb NOT NULL DEFAULT '[]',

    optional_fields     jsonb NOT NULL DEFAULT '[]',

    validation_rules    jsonb NOT NULL DEFAULT '[]',

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 27. PRESCRIPTION DECISION / PROPOSAL
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_proposal (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id        uuid,

    patient_id          uuid
        REFERENCES patient.patient(id),

    run_id              uuid
        REFERENCES knowledge.reasoning_run(run_id),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    indication_code     text,

    proposed_formulation_code text
        REFERENCES knowledge.medication_formulation(formulation_code),

    proposed_route_code text
        REFERENCES knowledge.medication_route(route_code),

    proposed_dose       numeric(14,4),
    proposed_dose_unit  text,

    proposed_frequency_code text
        REFERENCES knowledge.medication_frequency(frequency_code),

    proposed_duration   numeric(10,3),
    proposed_duration_unit text,

    proposed_quantity   numeric(14,4),

    proposed_maximum    numeric(14,4),

    dose_basis          text,

    calculation_trace   jsonb,

    clinical_context    jsonb,

    safety_evaluation   jsonb,

    indication_evaluation jsonb,

    interaction_evaluation jsonb,

    allergy_evaluation jsonb,

    renal_evaluation    jsonb,

    hepatic_evaluation  jsonb,

    pregnancy_evaluation jsonb,

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    knowledge_version   text,

    protocol_code       text,

    guideline_code      text,

    status              text NOT NULL DEFAULT 'PROPOSED'
        CHECK (
            status IN (
                'PROPOSED',
                'SAFE_TO_REVIEW',
                'WARNING',
                'BLOCKED',
                'AUTHORIZED',
                'REJECTED',
                'EXPIRED'
            )
        ),

    block_reason        text,

    generated_at        timestamptz NOT NULL DEFAULT now(),

    expires_at          timestamptz
);

CREATE INDEX IF NOT EXISTS idx_rx_proposal_patient
ON knowledge.prescription_proposal(patient_id);

CREATE INDEX IF NOT EXISTS idx_rx_proposal_encounter
ON knowledge.prescription_proposal(encounter_id);

CREATE INDEX IF NOT EXISTS idx_rx_proposal_status
ON knowledge.prescription_proposal(status);


-- =============================================================================
-- 28. PRESCRIPTION ORDER
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_order (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_code   text NOT NULL UNIQUE,

    proposal_id         uuid
        REFERENCES knowledge.prescription_proposal(id),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id),

    encounter_id        uuid,

    prescriber_id       uuid
        REFERENCES organization.professional(id),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    formulation_code    text
        REFERENCES knowledge.medication_formulation(formulation_code),

    route_code          text
        REFERENCES knowledge.medication_route(route_code),

    dose_value          numeric(14,4),
    dose_unit           text,

    frequency_code      text
        REFERENCES knowledge.medication_frequency(frequency_code),

    dose_expression     jsonb,

    duration_value      numeric(10,3),
    duration_unit       text,

    quantity            numeric(14,4),

    indication_code     text,

    instructions        text,

    prn                 boolean NOT NULL DEFAULT false,

    prn_indication      text,

    prn_min_interval_hours numeric(8,3),

    maximum_daily_dose  numeric(14,4),

    start_at            timestamptz,

    stop_at             timestamptz,

    status              text NOT NULL DEFAULT 'DRAFT'
        CHECK (
            status IN (
                'DRAFT',
                'PENDING_AUTHORIZATION',
                'AUTHORIZED',
                'DISPENSED',
                'PARTIALLY_DISPENSED',
                'ACTIVE',
                'HELD',
                'DISCONTINUED',
                'COMPLETED',
                'CANCELLED',
                'REJECTED'
            )
        ),

    authorization_required boolean NOT NULL DEFAULT true,

    authorized_at       timestamptz,

    authorized_by       uuid
        REFERENCES organization.professional(id),

    cancellation_reason text,

    system_version_code text
        REFERENCES governance.system_version(system_version_code),

    knowledge_version   text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rx_order_patient
ON knowledge.prescription_order(patient_id);

CREATE INDEX IF NOT EXISTS idx_rx_order_encounter
ON knowledge.prescription_order(encounter_id);

CREATE INDEX IF NOT EXISTS idx_rx_order_medication
ON knowledge.prescription_order(medication_code);

CREATE INDEX IF NOT EXISTS idx_rx_order_status
ON knowledge.prescription_order(status);

DROP TRIGGER IF EXISTS trg_rx_order_updated_at
ON knowledge.prescription_order;

CREATE TRIGGER trg_rx_order_updated_at
BEFORE UPDATE ON knowledge.prescription_order
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 29. PRESCRIPTION AMENDMENT / VERSION HISTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_order_version (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid NOT NULL
        REFERENCES knowledge.prescription_order(id)
        ON DELETE CASCADE,

    version_no          integer NOT NULL,

    previous_version_id uuid
        REFERENCES knowledge.prescription_order_version(id),

    changed_by          uuid
        REFERENCES organization.professional(id),

    change_reason       text NOT NULL,

    order_snapshot      jsonb NOT NULL,

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        prescription_order_id,
        version_no
    )
);


-- =============================================================================
-- 30. PRESCRIPTION AUTHORIZATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_authorization (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid NOT NULL
        REFERENCES knowledge.prescription_order(id)
        ON DELETE CASCADE,

    authorization_type text NOT NULL
        CHECK (
            authorization_type IN (
                'STANDARD',
                'HIGH_RISK',
                'CONTROLLED',
                'SPECIALIST',
                'EMERGENCY_OVERRIDE'
            )
        ),

    decision            text NOT NULL
        CHECK (
            decision IN (
                'APPROVED',
                'REJECTED',
                'DEFERRED'
            )
        ),

    authorized_by       uuid
        REFERENCES organization.professional(id),

    reason              text,

    authorized_at       timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        prescription_order_id,
        authorized_at
    )
);


-- =============================================================================
-- 31. MEDICATION ADMINISTRATION RECORD
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_administration (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid NOT NULL
        REFERENCES knowledge.prescription_order(id),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id),

    encounter_id        uuid,

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    scheduled_at        timestamptz,

    administered_at     timestamptz,

    administered_dose   numeric(14,4),

    administered_unit   text,

    route_code          text
        REFERENCES knowledge.medication_route(route_code),

    administrator_id    uuid
        REFERENCES organization.professional(id),

    status              text NOT NULL
        CHECK (
            status IN (
                'SCHEDULED',
                'GIVEN',
                'HELD',
                'REFUSED',
                'OMITTED',
                'CANCELLED',
                'NOT_AVAILABLE'
            )
        ),

    hold_reason         text,

    refusal_reason      text,

    administration_note text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mar_patient
ON knowledge.medication_administration(patient_id);

CREATE INDEX IF NOT EXISTS idx_mar_prescription
ON knowledge.medication_administration(prescription_order_id);

CREATE INDEX IF NOT EXISTS idx_mar_time
ON knowledge.medication_administration(scheduled_at);


-- =============================================================================
-- 32. MEDICATION RECONCILIATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_reconciliation (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id),

    encounter_id        uuid,

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    source              text
        CHECK (
            source IN (
                'PATIENT',
                'CAREGIVER',
                'CLINICIAN',
                'PHARMACY',
                'PREVIOUS_RECORD',
                'EXTERNAL_RECORD',
                'SYSTEM'
            )
        ),

    reported_dose      text,
    reported_frequency text,
    reported_route     text,

    currently_taking   boolean,

    adherence_status   text,

    last_taken_at      timestamptz,

    discrepancy_type   text,

    reconciliation_action text,

    reconciled_by      uuid
        REFERENCES organization.professional(id),

    reconciled_at      timestamptz,

    created_at         timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 33. FORMULARY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.formulary_item (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id     uuid,

    facility_id         uuid,

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    formulation_code    text
        REFERENCES knowledge.medication_formulation(formulation_code),

    availability_status text NOT NULL DEFAULT 'AVAILABLE'
        CHECK (
            availability_status IN (
                'AVAILABLE',
                'LIMITED',
                'OUT_OF_STOCK',
                'DISCONTINUED',
                'NOT_FORMULARY',
                'RESTRICTED'
            )
        ),

    restriction_type    text,

    restriction_rule    jsonb,

    stock_quantity      numeric(14,4),

    reorder_level       numeric(14,4),

    updated_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        organization_id,
        facility_id,
        medication_code,
        formulation_code
    )
);


-- =============================================================================
-- 34. MEDICATION SUPPLY / DISPENSING
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_dispensing (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid NOT NULL
        REFERENCES knowledge.prescription_order(id),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    formulation_code    text
        REFERENCES knowledge.medication_formulation(formulation_code),

    quantity_prescribed numeric(14,4),

    quantity_dispensed  numeric(14,4),

    unit                text,

    dispenser_id        uuid
        REFERENCES organization.professional(id),

    dispensed_at        timestamptz,

    batch_number        text,

    expiry_date         date,

    status              text NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'DISPENSED',
                'PARTIAL',
                'REJECTED',
                'CANCELLED'
            )
        ),

    note                text,

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 35. ANTIMICROBIAL STEWARDSHIP
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.antimicrobial_rule CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.antimicrobial_rule (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    indication_code     text,

    syndrome_code       text,

    pathogen_code       text,

    treatment_intent    text
        CHECK (
            treatment_intent IN (
                'EMPIRIC',
                'TARGETED',
                'PROPHYLAXIS',
                'DE_ESCALATION',
                'ESCALATION',
                'STEP_DOWN'
            )
        ),

    culture_required    boolean NOT NULL DEFAULT false,

    culture_before_antibiotic boolean NOT NULL DEFAULT false,

    review_interval_hours numeric(8,2),

    deescalation_rule   jsonb,

    stop_rule           jsonb,

    duration_rule       jsonb,

    resistance_context  jsonb,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 36. PROPHYLAXIS RULE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_prophylaxis_rule (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    prophylaxis_code    text NOT NULL,

    indication_context  jsonb NOT NULL,

    timing_rule         jsonb,

    dose_rule           jsonb,

    duration_rule       jsonb,

    stop_rule           jsonb,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 37. TAPERING RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_taper_rule (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    indication_code     text,

    minimum_exposure    jsonb,

    taper_required      boolean NOT NULL DEFAULT false,

    taper_expression    jsonb,

    withdrawal_risk     text,

    emergency_stop_rule jsonb,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 38. DOSE CALCULATION RULE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.dose_calculation_rule (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code           text NOT NULL UNIQUE,

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    calculation_type    text NOT NULL
        CHECK (
            calculation_type IN (
                'FIXED',
                'MG_KG_DOSE',
                'MG_KG_DAY',
                'MCG_KG_MIN',
                'MG_M2',
                'MCG_M2',
                'BSA',
                'WEIGHT_CAPPED',
                'WEIGHT_BANDED',
                'AGE_BANDED',
                'RENAL_ADJUSTED',
                'HEPATIC_ADJUSTED',
                'INFUSION_RATE',
                'CONCENTRATION_VOLUME'
            )
        ),

    expression          jsonb NOT NULL,

    rounding_rule       jsonb,

    minimum_dose        numeric(14,4),

    maximum_dose        numeric(14,4),

    maximum_daily_dose  numeric(14,4),

    weight_required     boolean NOT NULL DEFAULT false,

    bsa_required        boolean NOT NULL DEFAULT false,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 39. REAL-TIME MEDICATION EVALUATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_evaluation (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid
        REFERENCES patient.patient(id),

    encounter_id        uuid,

    run_id              uuid
        REFERENCES knowledge.reasoning_run(run_id),

    medication_code     text
        REFERENCES knowledge.medication_knowledge(medication_code),

    indication_code     text,

    evaluated_at        timestamptz NOT NULL DEFAULT now(),

    clinical_state      jsonb NOT NULL,

    dose_state          jsonb,

    contraindication_state jsonb,

    allergy_state       jsonb,

    interaction_state   jsonb,

    renal_state         jsonb,

    hepatic_state       jsonb,

    population_state    jsonb,

    pregnancy_state     jsonb,

    formulary_state     jsonb,

    protocol_state      jsonb,

    guideline_state     jsonb,

    governance_state    jsonb,

    final_disposition   text NOT NULL
        CHECK (
            final_disposition IN (
                'ALLOW_FOR_REVIEW',
                'ALLOW_WITH_WARNING',
                'BLOCK',
                'REQUIRES_HUMAN_REVIEW',
                'REQUIRES_SPECIALIST',
                'INSUFFICIENT_INFORMATION'
            )
        ),

    blocking_reasons    jsonb,

    warnings            jsonb,

    calculation_trace   jsonb,

    source_claims       jsonb,

    system_version_code text
        REFERENCES governance.system_version(system_version_code),

    knowledge_fingerprint text
);

CREATE INDEX IF NOT EXISTS idx_med_eval_patient
ON knowledge.medication_evaluation(patient_id);

CREATE INDEX IF NOT EXISTS idx_med_eval_encounter
ON knowledge.medication_evaluation(encounter_id);

CREATE INDEX IF NOT EXISTS idx_med_eval_time
ON knowledge.medication_evaluation(evaluated_at);


-- =============================================================================
-- 40. MEDICATION ALERT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_alert (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid
        REFERENCES patient.patient(id),

    encounter_id        uuid,

    prescription_order_id uuid
        REFERENCES knowledge.prescription_order(id),

    medication_code     text
        REFERENCES knowledge.medication_knowledge(medication_code),

    alert_type          text NOT NULL
        CHECK (
            alert_type IN (
                'ALLERGY',
                'CONTRAINDICATION',
                'INTERACTION',
                'DUPLICATION',
                'DOSE_TOO_HIGH',
                'DOSE_TOO_LOW',
                'AGE_RESTRICTION',
                'WEIGHT_MISSING',
                'RENAL_ADJUSTMENT',
                'HEPATIC_ADJUSTMENT',
                'PREGNANCY',
                'LACTATION',
                'MONITORING_REQUIRED',
                'FORMULARY',
                'ANTIMICROBIAL_STEWARDSHIP',
                'GUIDELINE',
                'MISSING_INFORMATION',
                'HIGH_RISK'
            )
        ),

    severity            text NOT NULL
        CHECK (
            severity IN (
                'INFO',
                'LOW',
                'MODERATE',
                'HIGH',
                'CRITICAL'
            )
        ),

    message             text NOT NULL,

    blocking            boolean NOT NULL DEFAULT false,

    acknowledged       boolean NOT NULL DEFAULT false,

    acknowledged_by    uuid
        REFERENCES organization.professional(id),

    acknowledged_at    timestamptz,

    override_reason    text,

    created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_alert_patient
ON knowledge.medication_alert(patient_id);

CREATE INDEX IF NOT EXISTS idx_med_alert_order
ON knowledge.medication_alert(prescription_order_id);

CREATE INDEX IF NOT EXISTS idx_med_alert_blocking
ON knowledge.medication_alert(blocking);


-- =============================================================================
-- 41. PRESCRIPTION ENGINE EVENT LOG
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_event_log (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid
        REFERENCES knowledge.prescription_order(id),

    proposal_id         uuid
        REFERENCES knowledge.prescription_proposal(id),

    evaluation_id       uuid
        REFERENCES knowledge.medication_evaluation(id),

    event_type          text NOT NULL
        CHECK (
            event_type IN (
                'PATIENT_STATE_RECEIVED',
                'MEDICATION_SELECTED',
                'INDICATION_MATCHED',
                'DOSE_RULE_MATCHED',
                'DOSE_CALCULATED',
                'CONTRAINDICATION_CHECKED',
                'ALLERGY_CHECKED',
                'INTERACTION_CHECKED',
                'RENAL_CHECKED',
                'HEPATIC_CHECKED',
                'POPULATION_CHECKED',
                'PREGNANCY_CHECKED',
                'FORMULARY_CHECKED',
                'PROTOCOL_CHECKED',
                'GUIDELINE_CHECKED',
                'ALERT_CREATED',
                'PRESCRIPTION_BLOCKED',
                'PRESCRIPTION_PROPOSED',
                'PRESCRIPTION_AUTHORIZED',
                'PRESCRIPTION_REJECTED',
                'PRESCRIPTION_AMENDED',
                'PRESCRIPTION_DISCONTINUED',
                'ADMINISTRATION_RECORDED',
                'DISPENSING_RECORDED'
            )
        ),

    actor_type          text NOT NULL
        CHECK (
            actor_type IN (
                'SYSTEM',
                'CLINICIAN',
                'PHARMACIST',
                'NURSE',
                'API_CLIENT'
            )
        ),

    actor_id            uuid,

    payload             jsonb,

    correlation_id      uuid,

    occurred_at         timestamptz NOT NULL DEFAULT now(),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rx_event_order
ON knowledge.prescription_event_log(prescription_order_id);

CREATE INDEX IF NOT EXISTS idx_rx_event_time
ON knowledge.prescription_event_log(occurred_at);


-- =============================================================================
-- 42. PRESCRIPTION PROVENANCE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_provenance (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid
        REFERENCES knowledge.prescription_order(id)
        ON DELETE CASCADE,

    medication_evaluation_id uuid
        REFERENCES knowledge.medication_evaluation(id),

    dose_reference_id   uuid
        REFERENCES knowledge.drug_dose_reference(id),

    protocol_code       text,

    guideline_code      text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    governance_object_id uuid
        REFERENCES governance.knowledge_object(id),

    governance_version_id uuid
        REFERENCES governance.knowledge_object_version(id),

    relationship_type   text NOT NULL
        CHECK (
            relationship_type IN (
                'SUPPORTED_BY',
                'DERIVED_FROM',
                'SELECTED_BY',
                'BLOCKED_BY',
                'MODIFIED_BY',
                'VALIDATED_BY',
                'GOVERNED_BY'
            )
        ),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 43. MEDICATION KNOWLEDGE VERSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_knowledge_version (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    version_no          integer NOT NULL,

    version_code        text NOT NULL UNIQUE,

    change_note         text,

    knowledge_snapshot  jsonb NOT NULL,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    effective_from      date,

    effective_to        date,

    status              text NOT NULL DEFAULT 'DRAFT'
        CHECK (
            status IN (
                'DRAFT',
                'REVIEW',
                'APPROVED',
                'ACTIVE',
                'SUPERSEDED',
                'RETIRED'
            )
        ),

    created_by          text,

    created_at          timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        medication_code,
        version_no
    )
);


-- =============================================================================
-- 44. MEDICATION SAFETY POLICY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_safety_policy (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    policy_code         text NOT NULL UNIQUE,

    policy_name         text NOT NULL,

    clinical_scope      text,

    trigger_expression  jsonb NOT NULL,

    action              text NOT NULL
        CHECK (
            action IN (
                'ALLOW',
                'WARN',
                'BLOCK',
                'REQUIRE_HUMAN_AUTHORIZATION',
                'REQUIRE_SPECIALIST',
                'REQUIRE_MONITORING',
                'REQUIRE_INFORMATION'
            )
        ),

    priority            integer NOT NULL DEFAULT 100,

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_safety_policy_priority
ON knowledge.medication_safety_policy(priority);


-- =============================================================================
-- 45. PRESCRIBER SCOPE / AUTHORIZATION POLICY
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescribing_authorization_rule (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    rule_code           text NOT NULL UNIQUE,

    medication_code     text
        REFERENCES knowledge.medication_knowledge(medication_code),

    medication_class    text,

    professional_role   text NOT NULL,

    required_authority  text,

    setting             text,

    action              text NOT NULL
        CHECK (
            action IN (
                'ALLOW',
                'WARN',
                'BLOCK',
                'REQUIRE_SUPERVISION',
                'REQUIRE_SPECIALIST'
            )
        ),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 46. MEDICATION REASON FOR USE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_indication_link (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid NOT NULL
        REFERENCES knowledge.prescription_order(id)
        ON DELETE CASCADE,

    indication_code     text NOT NULL,

    indication_status   text NOT NULL
        CHECK (
            indication_status IN (
                'CONFIRMED',
                'PROBABLE',
                'POSSIBLE',
                'PROPHYLAXIS',
                'SYMPTOMATIC'
            )
        ),

    supporting_facts   jsonb,

    supporting_diagnoses jsonb,

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 47. MEDICATION STOP / REVIEW RULE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_review_rule (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    medication_code     text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code),

    indication_code     text,

    review_at_expression jsonb,

    stop_at_expression   jsonb,

    response_criteria    jsonb,

    escalation_criteria jsonb,

    continuation_criteria jsonb,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'active'
        CHECK (status IN ('draft','active','superseded','retired')),

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 48. REAL-TIME CLINICAL MEDICATION CONTEXT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.medication_context_snapshot (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id          uuid NOT NULL
        REFERENCES patient.patient(id),

    encounter_id        uuid,

    captured_at         timestamptz NOT NULL DEFAULT now(),

    age_days            integer,

    weight_kg           numeric(8,3),

    height_cm           numeric(8,3),

    bsa_m2              numeric(8,4),

    pregnancy_status    text,

    lactation_status    text,

    renal_state         jsonb,

    hepatic_state       jsonb,

    allergies           jsonb,

    active_medications  jsonb,

    active_diagnoses    jsonb,

    active_conditions   jsonb,

    recent_laboratory   jsonb,

    recent_vitals       jsonb,

    recent_investigations jsonb,

    relevant_events     jsonb,

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    input_fingerprint   text,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_med_context_patient
ON knowledge.medication_context_snapshot(patient_id);

CREATE INDEX IF NOT EXISTS idx_med_context_encounter
ON knowledge.medication_context_snapshot(encounter_id);


-- =============================================================================
-- 49. REAL-TIME PRESCRIPTION ENGINE RESULT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_engine_result (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    context_snapshot_id uuid NOT NULL
        REFERENCES knowledge.medication_context_snapshot(id),

    medication_evaluation_id uuid
        REFERENCES knowledge.medication_evaluation(id),

    proposed_medication_code text,

    recommended_action text NOT NULL
        CHECK (
            recommended_action IN (
                'NO_ACTION',
                'CONSIDER',
                'SAFE_TO_REVIEW',
                'WARNING',
                'BLOCKED',
                'URGENT_REVIEW'
            )
        ),

    calculated_dose      jsonb,

    calculated_frequency jsonb,

    calculated_duration  jsonb,

    route_selection      jsonb,

    safety_gates         jsonb,

    warnings             jsonb,

    blocking_conditions  jsonb,

    monitoring_plan      jsonb,

    follow_up_plan       jsonb,

    provenance           jsonb,

    knowledge_version    text,

    system_version_code  text
        REFERENCES governance.system_version(system_version_code),

    generated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rx_engine_result_context
ON knowledge.prescription_engine_result(context_snapshot_id);


-- =============================================================================
-- 50. PRESCRIPTION DECISION GATE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.prescription_decision_gate (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    prescription_order_id uuid NOT NULL
        REFERENCES knowledge.prescription_order(id)
        ON DELETE CASCADE,

    gate_code           text NOT NULL,

    gate_type           text NOT NULL
        CHECK (
            gate_type IN (
                'IDENTITY',
                'INDICATION',
                'DOSE',
                'ROUTE',
                'FREQUENCY',
                'DURATION',
                'ALLERGY',
                'CONTRAINDICATION',
                'INTERACTION',
                'RENAL',
                'HEPATIC',
                'POPULATION',
                'PREGNANCY',
                'FORMULARY',
                'MONITORING',
                'GOVERNANCE',
                'AUTHORIZATION'
            )
        ),

    result              text NOT NULL
        CHECK (
            result IN (
                'PASS',
                'WARN',
                'FAIL',
                'NOT_APPLICABLE',
                'INSUFFICIENT_INFORMATION'
            )
        ),

    blocking            boolean NOT NULL DEFAULT false,

    detail              text,

    evidence            jsonb,

    evaluated_at        timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        prescription_order_id,
        gate_code
    )
);


-- =============================================================================
-- 51. EXISTING PROTOCOL ACTION â€” ADD SCORE
-- =============================================================================

ALTER TABLE knowledge.protocol_action
    DROP CONSTRAINT IF EXISTS protocol_action_action_type_check;

ALTER TABLE knowledge.protocol_action
    ADD CONSTRAINT protocol_action_action_type_check
    CHECK (
        action_type IN (
            'investigate',
            'medicate',
            'monitor',
            'educate',
            'refer',
            'admit',
            'advice',
            'order_set',
            'score',
            'reassess',
            'discharge',
            'follow_up',
            'alert'
        )
    );


-- =============================================================================
-- 52. SEVERITY SCORE â€” RETAINED AS FIRST-CLASS KNOWLEDGE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.severity_score CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.severity_score (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_code          text NOT NULL UNIQUE,

    canonical_name      text NOT NULL,

    description         text,

    condition_id        uuid
        REFERENCES knowledge.condition(id),

    population          text NOT NULL DEFAULT 'both',

    max_score           integer NOT NULL DEFAULT 0,

    source_reference    text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    jurisdiction_code   text
        REFERENCES governance.jurisdiction(jurisdiction_code),

    status              text NOT NULL DEFAULT 'draft'
        CHECK (
            status IN (
                'draft',
                'active',
                'superseded',
                'retired'
            )
        ),

    created_at          timestamptz NOT NULL DEFAULT now(),

    updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_severity_score_condition
ON knowledge.severity_score(condition_id);


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.severity_score_component CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.severity_score_component (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id            uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    component_code      text NOT NULL,

    component_name      text NOT NULL,

    condition           jsonb NOT NULL,

    points              integer NOT NULL DEFAULT 1,

    rationale           text,

    sort_order          integer NOT NULL DEFAULT 0,

    UNIQUE (
        score_id,
        component_code
    )
);

CREATE INDEX IF NOT EXISTS idx_severity_component_score
ON knowledge.severity_score_component(score_id, sort_order);


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.severity_score_interpretation CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.severity_score_interpretation (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_id            uuid NOT NULL
        REFERENCES knowledge.severity_score(id)
        ON DELETE CASCADE,

    min_score           integer NOT NULL,

    max_score           integer NOT NULL,

    severity_label      text NOT NULL,

    disposition         text,

    recommendation      text,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    UNIQUE (
        score_id,
        min_score,
        max_score
    )
);

CREATE INDEX IF NOT EXISTS idx_severity_interpretation_score
ON knowledge.severity_score_interpretation(score_id);


-- =============================================================================
-- 53. PHARMACOLOGY KNOWLEDGE GRAPH EDGES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_relationship CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.medication_relationship (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    relationship_code   text NOT NULL UNIQUE,

    medication_a_code   text NOT NULL
        REFERENCES knowledge.medication_knowledge(medication_code)
        ON DELETE CASCADE,

    medication_b_code   text,

    target_object_code  text,

    relationship_type   text NOT NULL
        CHECK (
            relationship_type IN (
                'SAME_INGREDIENT',
                'SAME_CLASS',
                'ALTERNATIVE',
                'SYNERGY',
                'ANTAGONISM',
                'INTERACTS_WITH',
                'CONTRAINDICATED_WITH',
                'REQUIRES_MONITORING',
                'REPLACES',
                'STEP_UP',
                'STEP_DOWN'
            )
        ),

    weight              numeric(8,3) NOT NULL DEFAULT 1,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    is_active           boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 54. KNOWLEDGE CHANGE EVENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.pharmacology_change_event (

    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    object_type         text NOT NULL,

    object_code         text NOT NULL,

    change_type         text NOT NULL
        CHECK (
            change_type IN (
                'CREATED',
                'UPDATED',
                'REVIEWED',
                'APPROVED',
                'ACTIVATED',
                'SUPERSEDED',
                'RETIRED',
                'JURISDICTION_CHANGED',
                'DOSE_CHANGED',
                'SAFETY_RULE_CHANGED',
                'GUIDELINE_CHANGED'
            )
        ),

    previous_state      jsonb,

    new_state           jsonb,

    source_claim_code   text
        REFERENCES knowledge.source_claim(claim_code),

    actor                text,

    occurred_at          timestamptz NOT NULL DEFAULT now()
);


-- =============================================================================
-- 55. SAFETY: DO NOT ALLOW A NULL JURISDICTION ON DOSE REFERENCES
-- =============================================================================

UPDATE knowledge.drug_dose_reference
SET jurisdiction_code = 'JUR-GLOBAL'
WHERE jurisdiction_code IS NULL;


-- =============================================================================
-- 56. SAFETY: DOSE REFERENCE VALIDATION CONSTRAINTS
-- =============================================================================

ALTER TABLE knowledge.drug_dose_reference
    DROP CONSTRAINT IF EXISTS chk_drug_dose_reference_range;

ALTER TABLE knowledge.drug_dose_reference
    ADD CONSTRAINT chk_drug_dose_reference_range
    CHECK (
        (
            dose_min IS NULL
            AND dose_max IS NULL
        )
        OR
        (
            dose_min IS NOT NULL
            AND dose_max IS NOT NULL
            AND dose_min >= 0
            AND dose_max >= dose_min
        )
    );


ALTER TABLE knowledge.drug_dose_reference
    DROP CONSTRAINT IF EXISTS chk_drug_dose_reference_age;

ALTER TABLE knowledge.drug_dose_reference
    ADD CONSTRAINT chk_drug_dose_reference_age
    CHECK (
        age_min_days IS NULL
        OR age_max_days IS NULL
        OR age_max_days >= age_min_days
    );


ALTER TABLE knowledge.drug_dose_reference
    DROP CONSTRAINT IF EXISTS chk_drug_dose_reference_weight;

ALTER TABLE knowledge.drug_dose_reference
    ADD CONSTRAINT chk_drug_dose_reference_weight
    CHECK (
        weight_min_kg IS NULL
        OR weight_max_kg IS NULL
        OR weight_max_kg >= weight_min_kg
    );


-- =============================================================================
-- 57. SAFETY: PRESCRIPTION STATUS TRANSITIONS ARE EXPLICIT
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_prescription_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.status = 'CANCELLED'
       AND NEW.status <> 'CANCELLED'
    THEN
        RAISE EXCEPTION
            'Cancelled prescription orders are immutable and cannot be reactivated';
    END IF;

    IF OLD.status = 'COMPLETED'
       AND NEW.status NOT IN ('COMPLETED')
    THEN
        RAISE EXCEPTION
            'Completed prescription orders cannot be silently reopened';
    END IF;

    IF NEW.status = 'AUTHORIZED'
       AND NEW.authorized_by IS NULL
    THEN
        RAISE EXCEPTION
            'Authorized medication orders require authorized_by';
    END IF;

    IF NEW.status = 'AUTHORIZED'
       AND NEW.authorized_at IS NULL
    THEN
        RAISE EXCEPTION
            'Authorized medication orders require authorized_at';
    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_validate_prescription_transition
ON knowledge.prescription_order;

CREATE TRIGGER trg_validate_prescription_transition
BEFORE UPDATE ON knowledge.prescription_order
FOR EACH ROW
EXECUTE FUNCTION knowledge.validate_prescription_transition();


-- =============================================================================
-- 58. AUTOMATIC PRESCRIPTION VERSION SNAPSHOT
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.capture_prescription_version()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    next_version integer;
BEGIN

    IF TG_OP = 'UPDATE'
       AND (
            OLD.dose_value IS DISTINCT FROM NEW.dose_value
         OR OLD.dose_unit IS DISTINCT FROM NEW.dose_unit
         OR OLD.frequency_code IS DISTINCT FROM NEW.frequency_code
         OR OLD.route_code IS DISTINCT FROM NEW.route_code
         OR OLD.duration_value IS DISTINCT FROM NEW.duration_value
         OR OLD.quantity IS DISTINCT FROM NEW.quantity
         OR OLD.instructions IS DISTINCT FROM NEW.instructions
         OR OLD.status IS DISTINCT FROM NEW.status
       )
    THEN

        SELECT COALESCE(MAX(version_no),0) + 1
        INTO next_version
        FROM knowledge.prescription_order_version
        WHERE prescription_order_id = NEW.id;

        INSERT INTO knowledge.prescription_order_version (
            prescription_order_id,
            version_no,
            changed_by,
            change_reason,
            order_snapshot
        )
        VALUES (
            NEW.id,
            next_version,
            NEW.authorized_by,
            COALESCE(
                NEW.cancellation_reason,
                'Prescription order amended'
            ),
            jsonb_build_object(
                'medication_code', NEW.medication_code,
                'formulation_code', NEW.formulation_code,
                'route_code', NEW.route_code,
                'dose_value', NEW.dose_value,
                'dose_unit', NEW.dose_unit,
                'frequency_code', NEW.frequency_code,
                'duration_value', NEW.duration_value,
                'duration_unit', NEW.duration_unit,
                'quantity', NEW.quantity,
                'indication_code', NEW.indication_code,
                'instructions', NEW.instructions,
                'status', NEW.status,
                'start_at', NEW.start_at,
                'stop_at', NEW.stop_at
            )
        );

    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_capture_prescription_version
ON knowledge.prescription_order;

CREATE TRIGGER trg_capture_prescription_version
AFTER UPDATE ON knowledge.prescription_order
FOR EACH ROW
EXECUTE FUNCTION knowledge.capture_prescription_version();


-- =============================================================================
-- 59. PHARMACOLOGY GOVERNANCE VIEWS
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_active_medication_knowledge AS
SELECT
    m.*
FROM knowledge.medication_knowledge m
WHERE m.lifecycle_status = 'ACTIVE'
  AND (m.effective_from IS NULL OR m.effective_from <= CURRENT_DATE)
  AND (m.effective_to IS NULL OR m.effective_to >= CURRENT_DATE);


CREATE OR REPLACE VIEW knowledge.v_active_drug_dose_reference AS
SELECT
    d.*
FROM knowledge.drug_dose_reference d
WHERE COALESCE(d.status,'active') = 'active';


CREATE OR REPLACE VIEW knowledge.v_active_medication_interactions AS
SELECT
    i.*
FROM knowledge.medication_interaction i
WHERE i.status = 'active';


CREATE OR REPLACE VIEW knowledge.v_active_medication_contraindications AS
SELECT
    c.*
FROM knowledge.medication_contraindication c
WHERE c.status = 'active';


CREATE OR REPLACE VIEW knowledge.v_active_medication_monitoring AS
SELECT
    m.*
FROM knowledge.medication_monitoring_rule m
WHERE m.status = 'active';


-- =============================================================================
-- 60. REAL-TIME DOSE RESOLUTION FUNCTION
-- =============================================================================
--
-- This function DOES NOT prescribe.
--
-- It resolves candidate dose references for a structured patient context.
-- The calling CPU must subsequently evaluate contraindications, interactions,
-- allergy, renal/hepatic status, governance and authorization.
--
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_dose_reference(
    p_medication_id uuid,
    p_population text,
    p_indication_code text,
    p_route text,
    p_jurisdiction_code text DEFAULT 'JUR-GLOBAL'
)
RETURNS TABLE (
    dose_reference_id uuid,
    jurisdiction_code text,
    dose_min numeric,
    dose_max numeric,
    dose_unit text,
    frequency_code text,
    duration_min_days numeric,
    duration_max_days numeric,
    maximum_single_dose numeric,
    maximum_daily_dose numeric,
    dose_expression text
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        d.id,
        d.jurisdiction_code,
        d.dose_min,
        d.dose_max,
        d.dose_unit,
        d.frequency_code,
        d.duration_min_days,
        d.duration_max_days,
        d.maximum_single_dose,
        d.maximum_daily_dose,
        d.dose_expression
    FROM knowledge.drug_dose_reference d
    WHERE d.medication_id = p_medication_id
      AND d.population = p_population
      AND d.indication_code = p_indication_code
      AND d.route = p_route
      AND d.jurisdiction_code IN (
          p_jurisdiction_code,
          'JUR-GLOBAL'
      )
    ORDER BY
        CASE
            WHEN d.jurisdiction_code = p_jurisdiction_code
                THEN 0
            ELSE 1
        END,
        d.id;
$$;


-- =============================================================================
-- 61. COMPLETION SELF-CHECK
-- =============================================================================

DO $amexan_r8$
BEGIN

    IF to_regclass('knowledge.medication_knowledge') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: medication_knowledge was not created';
    END IF;

    IF to_regclass('knowledge.medication_contraindication') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: medication_contraindication was not created';
    END IF;

    IF to_regclass('knowledge.medication_interaction') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: medication_interaction was not created';
    END IF;

    IF to_regclass('knowledge.prescription_proposal') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: prescription_proposal was not created';
    END IF;

    IF to_regclass('knowledge.prescription_order') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: prescription_order was not created';
    END IF;

    IF to_regclass('knowledge.medication_administration') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: medication_administration was not created';
    END IF;

    IF to_regclass('knowledge.medication_evaluation') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: medication_evaluation was not created';
    END IF;

    IF to_regclass('knowledge.antimicrobial_rule') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: antimicrobial_rule was not created';
    END IF;

    IF to_regclass('knowledge.clinical_protocol') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: clinical_protocol was not created';
    END IF;

    IF to_regclass('knowledge.clinical_guideline') IS NULL THEN
        RAISE EXCEPTION
            'R8 FAILURE: clinical_guideline was not created';
    END IF;

    RAISE NOTICE
        'AMEXAN R8 pharmacology/prescribing layer OK: medication intelligence,
         dosing, safety, interactions, protocols, guidelines, prescription
         lifecycle, authorization, dispensing, administration, monitoring,
         stewardship, provenance and real-time evaluation are available.';

END
$amexan_r8$;


-- =============================================================================
-- END AMEXAN R8 MIGRATION 038
-- =============================================================================
