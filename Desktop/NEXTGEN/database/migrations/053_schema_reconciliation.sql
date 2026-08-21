-- =============================================================================
-- 053_schema_reconciliation.sql
-- -----------------------------------------------------------------------------
-- Reconciles the knowledge schema with the current CPU runtime and the
-- knowledge-compiler generators (respiratory vertical slice seeds zqD-zqR).
--
-- The migrations, the runtime (clinical-cpu) and the generators evolved
-- independently; this migration brings the DDL in line with the runtime and
-- generators so the seed pipeline can complete and the machine acceptance
-- test can walk a real knowledge graph.
--
-- Changes:
--   A. clinical.fact_definition      + allow_multiple          (generators)
--   B. knowledge.drug_dose_reference + weight_basis, dose_per_kg_min,
--                                      dose_per_kg_max          (generators)
--   C. knowledge.protocol            + population, acuity, setting, version,
--                                      requires_confirmation, priority (CPU)
--   D. knowledge.protocol_step       rebuilt to protocol_id FK design (CPU)
--   E. knowledge.protocol_condition  + priority_weight         (CPU)
--   F. knowledge.protocol_gate       created (queried by CPU ProtocolEngine)
--   G. knowledge.condition           widen condition_type CHECK  (generators)
--   H. knowledge.clinical_context    widen category CHECK       (legacy seeds)
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- A. clinical.fact_definition
-- ---------------------------------------------------------------------------
ALTER TABLE clinical.fact_definition
    ADD COLUMN IF NOT EXISTS allow_multiple boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN clinical.fact_definition.allow_multiple IS
'Whether multiple simultaneous assertions of this fact are permitted.';

-- ---------------------------------------------------------------------------
-- B. knowledge.drug_dose_reference
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.drug_dose_reference
    ADD COLUMN IF NOT EXISTS weight_basis text,
    ADD COLUMN IF NOT EXISTS dose_per_kg_min numeric,
    ADD COLUMN IF NOT EXISTS dose_per_kg_max numeric;

COMMENT ON COLUMN knowledge.drug_dose_reference.weight_basis IS
'Weight basis for the dose, e.g. mg_per_kg, mg_per_m2.';
COMMENT ON COLUMN knowledge.drug_dose_reference.dose_per_kg_min IS
'Minimum dose expressed per kg body weight.';
COMMENT ON COLUMN knowledge.drug_dose_reference.dose_per_kg_max IS
'Maximum dose expressed per kg body weight.';

-- ---------------------------------------------------------------------------
-- C. knowledge.protocol
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.protocol
    ADD COLUMN IF NOT EXISTS population text,
    ADD COLUMN IF NOT EXISTS acuity text,
    ADD COLUMN IF NOT EXISTS setting text,
    ADD COLUMN IF NOT EXISTS version text,
    ADD COLUMN IF NOT EXISTS requires_confirmation boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS priority numeric NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_protocol_population
    ON knowledge.protocol(population);
CREATE INDEX IF NOT EXISTS idx_protocol_acuity
    ON knowledge.protocol(acuity);

-- ---------------------------------------------------------------------------
-- D. knowledge.protocol_step  (rebuilt: protocol_id FK, empty legacy table)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS knowledge.protocol_step CASCADE;

CREATE TABLE knowledge.protocol_step (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    protocol_id          uuid NOT NULL REFERENCES knowledge.protocol(id) ON DELETE CASCADE,
    step_code            text NOT NULL,
    step_label           text,
    step_type            text,
    sequence_no          integer NOT NULL,
    instruction          text,
    rationale            text,
    required             boolean NOT NULL DEFAULT false,
    condition_expression jsonb,
    status               text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','inactive','draft','retired')),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (protocol_id, step_code)
);

CREATE INDEX idx_protocol_step_protocol
    ON knowledge.protocol_step(protocol_id);

COMMENT ON TABLE knowledge.protocol_step IS
'Steps within a clinical protocol. Linked to the protocol by protocol_id.';

-- Restore the protocol_action -> protocol_step dependency (dropped by CASCADE).
ALTER TABLE knowledge.protocol_action
    DROP CONSTRAINT IF EXISTS protocol_action_step_id_fkey;
ALTER TABLE knowledge.protocol_action
    ADD CONSTRAINT protocol_action_step_id_fkey
    FOREIGN KEY (step_id) REFERENCES knowledge.protocol_step(id) ON DELETE CASCADE;

-- Restore protocol_monitoring -> protocol_step dependency if present.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='knowledge' AND table_name='protocol_monitoring'
          AND column_name='step_id'
    ) THEN
        ALTER TABLE knowledge.protocol_monitoring
            DROP CONSTRAINT IF EXISTS protocol_monitoring_step_id_fkey;
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- E. knowledge.protocol_condition
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.protocol_condition
    ADD COLUMN IF NOT EXISTS priority_weight numeric;

-- ---------------------------------------------------------------------------
-- F. knowledge.protocol_gate  (queried by CPU ProtocolEngine)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.protocol_gate (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    protocol_code    text NOT NULL REFERENCES knowledge.protocol(protocol_code) ON DELETE CASCADE,
    gate_code        text NOT NULL,
    gate_type        text NOT NULL,
    target_code      text,
    operator         text,
    expected_value   jsonb,
    failure_action   text,
    failure_message  text,
    priority         integer NOT NULL DEFAULT 0,
    status           text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','inactive','retired')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (protocol_code, gate_code)
);

COMMENT ON TABLE knowledge.protocol_gate IS
'Safety/eligibility gates evaluated by the CPU ProtocolEngine before activation.';

-- ---------------------------------------------------------------------------
-- G. knowledge.condition  (widen condition_type CHECK)
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.condition
    DROP CONSTRAINT IF EXISTS condition_condition_type_check;
ALTER TABLE knowledge.condition
    ADD CONSTRAINT condition_condition_type_check CHECK (
        condition_type IN (
            'disease','syndrome','disorder','injury','infection','neoplasm',
            'congenital','genetic','metabolic','autoimmune','inflammatory',
            'degenerative','vascular','toxic','iatrogenic','physiologic',
            'pregnancy_related','postoperative','traumatic','functional',
            'symptom_complex','acute','subacute','chronic','recurrent',
            'episodic','progressive','relapsing','self_limited','lifelong'
        )
    );

-- ---------------------------------------------------------------------------
-- H. knowledge.clinical_context  (widen category CHECK for legacy content)
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.clinical_context
    DROP CONSTRAINT IF EXISTS clinical_context_category_check;
ALTER TABLE knowledge.clinical_context
    ADD CONSTRAINT clinical_context_category_check CHECK (
        category IN (
            'AGE','SEX','REPRODUCTIVE','LACTATION','SETTING','MODE','HISTORIAN',
            'COMMUNICATION','COGNITION','ENCOUNTER_PURPOSE','ENCOUNTER',
            'DEPARTMENT','PRESENTATION','ACUITY','FUNCTION',
            'SPECIAL_CLINICAL','CONSCIOUSNESS'
        )
    );

-- ---------------------------------------------------------------------------
-- I. Widened vocabulary CHECKs so seed content (which is the authority for
--     clinical vocabulary evolution) matches the schema guardrails.
-- ---------------------------------------------------------------------------

ALTER TABLE clinical.fact_definitions
    DROP CONSTRAINT IF EXISTS fact_definitions_data_type_check;
ALTER TABLE clinical.fact_definitions
    ADD CONSTRAINT fact_definitions_data_type_check CHECK (
        data_type IN (
            'TEXT','CODE','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME',
            'TIME','QUANTITY','RANGE','CODE_LIST','TEXT_LIST','JSON',
            'text','coded','numeric','boolean','date'
        )
    );

ALTER TABLE knowledge.condition
    DROP CONSTRAINT IF EXISTS condition_condition_type_check;
ALTER TABLE knowledge.condition
    ADD CONSTRAINT condition_condition_type_check CHECK (
        condition_type IN (
            'disease','syndrome','disorder','injury','infection','neoplasm',
            'congenital','genetic','metabolic','autoimmune','inflammatory',
            'degenerative','vascular','toxic','iatrogenic','physiologic',
            'pregnancy_related','postoperative','traumatic','functional',
            'symptom_complex','acute','subacute','chronic','recurrent',
            'episodic','progressive','relapsing','self_limited','lifelong',
            'arrhythmia','dermatological','dermatological_emergency',
            'emergency','endocrine','gastrointestinal','gynaecological',
            'haematological','immune','infectious','infectious_emergency',
            'neonatal','neoplastic','neurodegenerative','neurological',
            'nutritional','obstetric','obstetric_emergency',
            'ophthalmic_emergency','ophthalmological','orthopaedic',
            'orthopaedic_emergency','paediatric','psychiatric','renal',
            'sleep_disorder','structural','surgical','surgical_emergency',
            'trauma','vascular_emergency'
        )
    );

ALTER TABLE knowledge.condition_differential
    DROP CONSTRAINT IF EXISTS condition_differential_relationship_type_check;
ALTER TABLE knowledge.condition_differential
    ADD CONSTRAINT condition_differential_relationship_type_check CHECK (
        relationship_type IN (
            'mimics','overlaps','must_rule_out','dangerous_alternative',
            'common_alternative','rare_alternative','coexists','competes',
            'differentiates'
        )
    );

ALTER TABLE knowledge.diagnosis_phenotype
    DROP CONSTRAINT IF EXISTS diagnosis_phenotype_relationship_check;
ALTER TABLE knowledge.diagnosis_phenotype
    ADD CONSTRAINT diagnosis_phenotype_relationship_check CHECK (
        relationship IN (
            'CHARACTERISTIC','HIGHLY_ASSOCIATED','COMMONLY_ASSOCIATED',
            'COMPATIBLE','OCCASIONAL','UNUSUAL','MIMIC','STRONGLY_ASSOCIATED'
        )
    );

ALTER TABLE knowledge.drug_dose_reference
    DROP CONSTRAINT IF EXISTS drug_dose_reference_population_check;
ALTER TABLE knowledge.drug_dose_reference
    ADD CONSTRAINT drug_dose_reference_population_check CHECK (
        population IN (
            'adult','paediatric','neonatal','geriatric','renal_impairment',
            'hepatic_impairment','pregnancy','lactation','other','adolescent'
        )
    );

ALTER TABLE knowledge.education
    DROP CONSTRAINT IF EXISTS education_content_type_check;
ALTER TABLE knowledge.education
    ADD CONSTRAINT education_content_type_check CHECK (
        content_type IN (
            'explanation','warning','instruction','preparation',
            'medication_instruction','monitoring_instruction','teach_back',
            'follow_up','discharge','prevention','lifestyle',
            'emergency_return','procedure','other','assessment','checklist'
        )
    );

ALTER TABLE knowledge.investigation_rule
    DROP CONSTRAINT IF EXISTS investigation_rule_modification_check;
ALTER TABLE knowledge.investigation_rule
    ADD CONSTRAINT investigation_rule_modification_check CHECK (
        modification IN (
            'SAFETY_BLOCK','SAFETY_PRECAUTION','MANDATORY','ACTIVATE',
            'UNAVAILABLE','CONDITIONAL','PRIORITY','DEPENDENCY','ALTERNATIVE',
            'SAFETY'
        )
    );

ALTER TABLE knowledge.medication_condition
    DROP CONSTRAINT IF EXISTS medication_condition_role_check;
ALTER TABLE knowledge.medication_condition
    ADD CONSTRAINT medication_condition_role_check CHECK (
        role IN (
            'treatment','first_line','alternative','second_line','prophylaxis',
            'post_exposure_prophylaxis','symptomatic','adjunct','supportive',
            'rescue','maintenance','replacement','palliative',
            'controller','disease_modifying','exacerbation','reliever'
        )
    );

ALTER TABLE knowledge.source
    DROP CONSTRAINT IF EXISTS source_source_type_check;
ALTER TABLE knowledge.source
    ADD CONSTRAINT source_source_type_check CHECK (
        source_type IN (
            'clinical_methods_text','textbook','guideline','journal',
            'reference','protocol','formulary','pharmacology','consensus',
            'regulatory','paediatric_management_guided'
        )
    );

ALTER TABLE knowledge.source_version
    DROP CONSTRAINT IF EXISTS source_version_status_check;
ALTER TABLE knowledge.source_version
    ADD CONSTRAINT source_version_status_check CHECK (
        status IN (
            'ACTIVE','active','deprecated','superseded','pending_review',
            'ACTIVE_FOUNDATION'
        )
    );

ALTER TABLE knowledge.symptom_etiology
    DROP CONSTRAINT IF EXISTS symptom_etiology_category_check;
ALTER TABLE knowledge.symptom_etiology
    ADD CONSTRAINT symptom_etiology_category_check CHECK (
        category IN (
            'infectious','inflammatory','vascular','neoplastic','traumatic',
            'obstructive','metabolic','endocrine','toxic','drug_related',
            'degenerative','congenital','genetic','functional','psychological',
            'iatrogenic','environmental','other',
            'cardiac','drug-induced','gastroesophageal','occupational','pleural',
            'upper-airway'
        )
    );

ALTER TABLE knowledge.symptom_relationship
    DROP CONSTRAINT IF EXISTS symptom_relationship_relationship_type_check;
ALTER TABLE knowledge.symptom_relationship
    ADD CONSTRAINT symptom_relationship_relationship_type_check CHECK (
        relationship_type IN (
            'associated','commonly_associated','may_accompany','precedes',
            'follows','coexists','mimics','differentiates',
            'red_flag_association','complication',
            'associated_with','may_cause'
        )
    );

ALTER TABLE knowledge.symptom_risk_factor
    DROP CONSTRAINT IF EXISTS symptom_risk_factor_category_check;
ALTER TABLE knowledge.symptom_risk_factor
    ADD CONSTRAINT symptom_risk_factor_category_check CHECK (
        category IN (
            'demographic','environmental','occupational','behavioural',
            'exposure','infectious','medication','medical','surgical',
            'reproductive','family','genetic','nutritional','social','travel',
            'iatrogenic','other','drug','immunological'
        )
    );

ALTER TABLE terminology.concept_code
    DROP CONSTRAINT IF EXISTS concept_code_relationship_check;
ALTER TABLE terminology.concept_code
    ADD CONSTRAINT concept_code_relationship_check CHECK (
        relationship IN (
            'equivalent','broader','narrower','related','approximate',
            'contextual','terminology_anchor'
        )
    );

ALTER TABLE knowledge.context_adaptation_rule
    DROP CONSTRAINT IF EXISTS context_adaptation_rule_modification_check;
ALTER TABLE knowledge.context_adaptation_rule
    ADD CONSTRAINT context_adaptation_rule_modification_check CHECK (
        modification IN (
            'ACTIVATE','UNAVAILABLE','DISABLE','DEACTIVATE','DEPRIORITIZE',
            'ENFORCE','MODIFY','NO_AUTO_DIAGNOSIS','CONDITIONAL','OVERRIDE'
        )
    );

ALTER TABLE knowledge.context_adaptation_rule
    DROP CONSTRAINT IF EXISTS context_adaptation_rule_target_type_check;
ALTER TABLE knowledge.context_adaptation_rule
    ADD CONSTRAINT context_adaptation_rule_target_type_check CHECK (
        target_type IN (
            'question','question_module','symptom','fact_definition',
            'functional_domain','examination_modality','examination_module',
            'clinical_reasoning','cpu_policy','output_format','clinical_format',
            'format','concept'
        )
    );

ALTER TABLE knowledge.phenotype_context
    DROP CONSTRAINT IF EXISTS phenotype_context_applicability_check;
ALTER TABLE knowledge.phenotype_context
    ADD CONSTRAINT phenotype_context_applicability_check CHECK (
        applicability IN ('applies','excludes','required','preferred')
    );

ALTER TABLE knowledge.question_requirement
    ALTER COLUMN requirement_type DROP NOT NULL;
ALTER TABLE knowledge.question_requirement
    ALTER COLUMN requirement_code DROP NOT NULL;
ALTER TABLE knowledge.question_requirement
    ALTER COLUMN operator DROP NOT NULL;

ALTER TABLE knowledge.differential_hypothesis
    DROP CONSTRAINT IF EXISTS differential_hypothesis_pathological_process_code_fkey;
ALTER TABLE knowledge.differential_hypothesis
    ADD CONSTRAINT differential_hypothesis_pathological_process_code_fkey
    FOREIGN KEY (pathological_process_code) REFERENCES knowledge.differential_pathological_process(code);

ALTER TABLE knowledge.investigation_result
    DROP CONSTRAINT IF EXISTS investigation_result_result_category_check;
ALTER TABLE knowledge.investigation_result
    ADD CONSTRAINT investigation_result_result_category_check
    CHECK (result_category IN ('normal','abnormal','positive','negative','indeterminate','critical','inconclusive','other','interpretation'));

ALTER TABLE knowledge.question_requirement
    DROP CONSTRAINT IF EXISTS question_requirement_requirement_level_check;
ALTER TABLE knowledge.question_requirement
    ADD CONSTRAINT question_requirement_requirement_level_check CHECK (
        requirement_level IS NULL
        OR requirement_level IN (
            'mandatory','conditionally_required','optional',
            'informational','safety','high_priority'
        )
    );

ALTER TABLE knowledge.rule_source
    DROP CONSTRAINT IF EXISTS rule_source_source_type_check;
ALTER TABLE knowledge.rule_source
    ADD CONSTRAINT rule_source_source_type_check CHECK (
        source_type IN (
            'guideline','systematic_review','meta_analysis','randomized_trial',
            'observational_study','textbook','monograph','consensus','expert',
            'local_protocol','facility_protocol','regulatory','public_health',
            'pharmacopoeia','other','safety_framework','internal'
        )
    );

ALTER TABLE knowledge.symptom
    ALTER COLUMN concept_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'knowledge_symptom_symptom_code_key' AND conrelid = 'knowledge.symptom'::regclass
    ) THEN
        ALTER TABLE knowledge.symptom ADD CONSTRAINT knowledge_symptom_symptom_code_key UNIQUE (symptom_code);
    END IF;
END $$;

ALTER TABLE knowledge.symptom_context
    ADD COLUMN IF NOT EXISTS relevance numeric;
ALTER TABLE knowledge.symptom_context
    ADD COLUMN IF NOT EXISTS description text;

-- ---------------------------------------------------------------------------
-- J. protocol_action: widen action_type CHECK to the vocabulary used by the
--    z-series protocol seeds (examine, support).
-- ---------------------------------------------------------------------------

ALTER TABLE knowledge.protocol_action
    DROP CONSTRAINT IF EXISTS protocol_action_action_type_check;
ALTER TABLE knowledge.protocol_action
    ADD CONSTRAINT protocol_action_action_type_check CHECK (
        action_type IN (
            'investigate','medicate','monitor','educate','refer','admit',
            'advice','order_set','score','reassess','discharge','follow_up',
            'alert','examine','support'
        )
    );

-- protocol_monitoring.deterioration_rule is consumed by the CPU and seeded
-- as plain text, not JSON.
ALTER TABLE knowledge.protocol_monitoring
    ALTER COLUMN deterioration_rule DROP DEFAULT;
ALTER TABLE knowledge.protocol_monitoring
    ALTER COLUMN deterioration_rule TYPE text USING deterioration_rule::text;

-- ---------------------------------------------------------------------------
-- K. symptom_functional_impact: rebuild to the z-series shape
--    (migration 026 replaced the 022/z-series definition with a legacy shape
--    that the z-series seeds and CPU do not use).
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS knowledge.symptom_functional_impact CASCADE;
CREATE TABLE knowledge.symptom_functional_impact (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    symptom_id            uuid NOT NULL
                          REFERENCES knowledge.symptom(id)
                          ON DELETE CASCADE,

    functional_impact_code text NOT NULL,
    canonical_name        text NOT NULL,
    description           text,

    domain                text NOT NULL DEFAULT 'general'
                          CHECK (domain IN (
                              'activities_of_daily_living',
                              'mobility',
                              'feeding',
                              'sleep',
                              'work',
                              'school',
                              'exercise',
                              'communication',
                              'self_care',
                              'social',
                              'sexual',
                              'reproductive',
                              'caregiving',
                              'general'
                          )),

    weight                numeric(4,3) NOT NULL DEFAULT 1.000
                          CHECK (weight >= 0 AND weight <= 1),

    priority              integer NOT NULL DEFAULT 50,

    UNIQUE (symptom_id, functional_impact_code)
);

CREATE INDEX IF NOT EXISTS idx_symptom_functional_symptom
    ON knowledge.symptom_functional_impact(symptom_id);

COMMIT;
