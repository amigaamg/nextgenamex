-- =============================================================================
-- AMEXAN Phase 2 — Migration 016: medication / drug intelligence primitives
-- =============================================================================
-- UNIVERSAL MEDICATION INTELLIGENCE LAYER
--
-- Design principles:
--   1. A medication exists ONCE in the universal knowledge substrate.
--   2. Indications, contraindications, interactions, adverse effects, monitoring,
--      formulations and population constraints are reusable relationships.
--   3. Drugs do NOT own disease-specific treatment engines.
--   4. Prescribing logic is composed from:
--        medication + indication + patient context + facts + rules + formulary
--   5. Dose references are NEVER silently treated as verified prescribing data.
--   6. Population-specific information is explicit.
--   7. Drug-drug, drug-condition and drug-context safety relationships are
--      first-class knowledge.
--   8. Every clinically meaningful statement can carry provenance/evidence.
--   9. Facility/local formulary configuration is layered through the existing
--      knowledge.override mechanism.
--  10. The medication layer feeds the same universal reasoning CPU used by
--      history, examination, investigation, phenotype, condition and monitoring.
-- =============================================================================


-- =============================================================================
-- 1. MEDICATION
-- =============================================================================
-- Universal drug identity. This represents the reusable medication entity,
-- not a prescription and not a disease-specific treatment.

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication CASCADE;
CREATE TABLE knowledge.medication (
   id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id                 uuid REFERENCES knowledge.concept(id),

   medication_code            text NOT NULL UNIQUE,
   generic_name               text NOT NULL,
   normalized_name            text,
   display_name               text,

   drug_class                 text,
   pharmacologic_class        text,
   therapeutic_class          text,

   description                text,

   -- High-level route/formulation metadata retained for fast resolution.
   route_options              jsonb NOT NULL DEFAULT '[]'::jsonb,
   formulations               jsonb NOT NULL DEFAULT '[]'::jsonb,

   -- Safety summaries. Detailed relationships are represented below.
   contraindications          jsonb NOT NULL DEFAULT '[]'::jsonb,
   warnings                   jsonb NOT NULL DEFAULT '[]'::jsonb,
   precautions                jsonb NOT NULL DEFAULT '[]'::jsonb,
   interaction_notes          jsonb NOT NULL DEFAULT '[]'::jsonb,
   adverse_effect_notes      jsonb NOT NULL DEFAULT '[]'::jsonb,
   monitoring_notes           jsonb NOT NULL DEFAULT '[]'::jsonb,

   renal_adjustment_notes     text,
   hepatic_adjustment_notes   text,

   pregnancy_notes            text,
   lactation_notes            text,
   paediatric_notes           text,
   geriatric_notes            text,
   neonatal_notes             text,

   antimicrobial              boolean NOT NULL DEFAULT false,
   high_alert                 boolean NOT NULL DEFAULT false,
   narrow_therapeutic_index   boolean NOT NULL DEFAULT false,

   formulary_status           text NOT NULL DEFAULT 'reference'
                              CHECK (
                                 formulary_status IN (
                                    'reference',
                                    'facility',
                                    'restricted',
                                    'non_formulary',
                                    'retired'
                                 )
                              ),

   evidence_source             text,

   status                     text NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active','deprecated')),

   created_at                 timestamptz NOT NULL DEFAULT now(),
   updated_at                 timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.medication IS
'Universal medication identity and high-level drug intelligence. Medication entities are created once and reused across conditions, protocols, prescriptions, monitoring and education.';

COMMENT ON COLUMN knowledge.medication.concept_id IS
'Universal concept node representing this medication.';

COMMENT ON COLUMN knowledge.medication.formulary_status IS
'Reference describes AMEXAN knowledge; facility/restricted/non_formulary/retired describe formulary state resolved through local configuration.';

CREATE INDEX idx_knowledge_medication_concept
   ON knowledge.medication(concept_id);

CREATE INDEX idx_knowledge_medication_generic_name
   ON knowledge.medication(generic_name);

CREATE INDEX idx_knowledge_medication_class
   ON knowledge.medication(drug_class);

CREATE INDEX idx_knowledge_medication_antimicrobial
   ON knowledge.medication(antimicrobial)
   WHERE antimicrobial = true;

CREATE INDEX idx_knowledge_medication_high_alert
   ON knowledge.medication(high_alert)
   WHERE high_alert = true;

CREATE TRIGGER trg_knowledge_medication_updated_at
   BEFORE UPDATE ON knowledge.medication
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 2. MEDICATION ROUTE
-- =============================================================================
-- Routes are structured primitives rather than arbitrary strings.

CREATE TABLE knowledge.medication_route (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   route_code            text NOT NULL,
   route_label           text NOT NULL,

   formulation_supported boolean NOT NULL DEFAULT true,

   restrictions           jsonb NOT NULL DEFAULT '{}'::jsonb,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, route_code)
);

COMMENT ON TABLE knowledge.medication_route IS
'Routes by which a medication may be administered. Route availability is medication-specific and may be further constrained by formulation, population, protocol or facility configuration.';

CREATE INDEX idx_knowledge_medication_route_med
   ON knowledge.medication_route(medication_id);

CREATE INDEX idx_knowledge_medication_route_code
   ON knowledge.medication_route(route_code);


-- =============================================================================
-- 3. MEDICATION FORMULATION
-- =============================================================================
-- Separates drug identity from actual pharmaceutical presentation.

CREATE TABLE knowledge.medication_formulation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   formulation_code      text NOT NULL,
   dosage_form           text NOT NULL,

   strength_expression   text,
   concentration_expression text,

   unit_of_measure       text,
   route_code            text,

   release_type          text
                         CHECK (
                            release_type IS NULL OR
                            release_type IN (
                               'immediate',
                               'modified',
                               'extended',
                               'delayed',
                               'controlled',
                               'other'
                            )
                         ),

   device_required       boolean NOT NULL DEFAULT false,

   excipients             jsonb NOT NULL DEFAULT '[]'::jsonb,
   administration_notes  text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, formulation_code)
);

COMMENT ON TABLE knowledge.medication_formulation IS
'Specific pharmaceutical presentations of a medication.';

CREATE INDEX idx_knowledge_medication_formulation_med
   ON knowledge.medication_formulation(medication_id);

CREATE INDEX idx_knowledge_medication_formulation_route
   ON knowledge.medication_formulation(route_code);


-- =============================================================================
-- 4. MEDICATION INDICATION / CONDITION RELATIONSHIP
-- =============================================================================
-- The same medication can have multiple clinical roles for the same condition.

CREATE TABLE knowledge.medication_condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   role                  text NOT NULL DEFAULT 'treatment'
                         CHECK (
                            role IN (
                               'treatment',
                               'first_line',
                               'alternative',
                               'second_line',
                               'prophylaxis',
                               'post_exposure_prophylaxis',
                               'symptomatic',
                               'adjunct',
                               'supportive',
                               'rescue',
                               'maintenance',
                               'replacement',
                               'palliative'
                            )
                         ),

   indication_expression jsonb,
   population_context    jsonb,

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   evidence_level        text,
   evidence_source       text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, condition_id, role)
);

COMMENT ON TABLE knowledge.medication_condition IS
'Universal medication-to-condition relationship. Treatment selection remains context- and rule-dependent rather than being hard-coded into the condition.';

CREATE INDEX idx_knowledge_medication_condition_med
   ON knowledge.medication_condition(medication_id);

CREATE INDEX idx_knowledge_medication_condition_condition
   ON knowledge.medication_condition(condition_id);


-- =============================================================================
-- 5. DOSE REFERENCE
-- =============================================================================
-- Dose knowledge is explicitly separated from medication identity.
--
-- IMPORTANT:
--   dose_expression is deliberately textual/structured rather than converted
--   into executable prescribing mathematics here.
--
--   Production dose execution requires verified jurisdiction-specific,
--   indication-specific and population-specific clinical data.

CREATE TABLE knowledge.drug_dose_reference (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id            uuid NOT NULL REFERENCES knowledge.medication(id)
                            ON DELETE CASCADE,

   condition_id             uuid REFERENCES knowledge.condition(id),

   population               text NOT NULL
                            CHECK (
                               population IN (
                                  'adult',
                                  'paediatric',
                                  'neonatal',
                                  'geriatric',
                                  'renal_impairment',
                                  'hepatic_impairment',
                                  'pregnancy',
                                  'lactation',
                                  'other'
                               )
                            ),

   age_min_days             integer CHECK (age_min_days IS NULL OR age_min_days >= 0),
   age_max_days             integer CHECK (age_max_days IS NULL OR age_max_days >= 0),

   weight_min_kg            numeric(8,3)
                            CHECK (weight_min_kg IS NULL OR weight_min_kg >= 0),

   weight_max_kg            numeric(8,3)
                            CHECK (weight_max_kg IS NULL OR weight_max_kg >= 0),

   route_code               text,

   dose_basis               text
                            CHECK (
                               dose_basis IS NULL OR
                               dose_basis IN (
                                  'fixed',
                                  'weight',
                                  'body_surface_area',
                                  'renal_function',
                                  'hepatic_function',
                                  'age',
                                  'other'
                               )
                            ),

   dose_expression          text NOT NULL,
   frequency_expression     text,
   duration_expression      text,
   maximum_expression       text,

   adjustment_expression    text,

   clinical_conditions      jsonb NOT NULL DEFAULT '{}'::jsonb,

   evidence_source          text,
   guideline_reference      text,
   guideline_version        text,

   is_verified              boolean NOT NULL DEFAULT false,

   verification_status      text NOT NULL DEFAULT 'unverified'
                            CHECK (
                               verification_status IN (
                                  'unverified',
                                  'under_review',
                                  'verified',
                                  'superseded',
                                  'rejected'
                               )
                            ),

   verified_by              text,
   verified_at              timestamptz,

   status                   text NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active','deprecated')),

   created_at               timestamptz NOT NULL DEFAULT now(),
   updated_at               timestamptz NOT NULL DEFAULT now(),

   CHECK (
      age_max_days IS NULL
      OR age_min_days IS NULL
      OR age_max_days >= age_min_days
   ),

   CHECK (
      weight_max_kg IS NULL
      OR weight_min_kg IS NULL
      OR weight_max_kg >= weight_min_kg
   )
);

COMMENT ON TABLE knowledge.drug_dose_reference IS
'Population-, indication- and context-aware dose reference. Unverified dose references must never be silently converted into executable prescribing instructions.';

COMMENT ON COLUMN knowledge.drug_dose_reference.is_verified IS
'Explicit clinical verification gate. False means the reference is knowledge awaiting verification, not executable prescribing authority.';

CREATE INDEX idx_knowledge_dose_reference_med
   ON knowledge.drug_dose_reference(medication_id);

CREATE INDEX idx_knowledge_dose_reference_condition
   ON knowledge.drug_dose_reference(condition_id);

CREATE INDEX idx_knowledge_dose_reference_population
   ON knowledge.drug_dose_reference(population);

CREATE INDEX idx_knowledge_dose_reference_verified
   ON knowledge.drug_dose_reference(is_verified, verification_status);


CREATE TRIGGER trg_knowledge_drug_dose_reference_updated_at
   BEFORE UPDATE ON knowledge.drug_dose_reference
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 6. CONTRAINDICATIONS
-- =============================================================================
-- Drug-condition contraindications are explicit graph relationships.

CREATE TABLE knowledge.medication_contraindication (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   condition_id          uuid REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   concept_id            uuid REFERENCES knowledge.concept(id),

   contraindication_code text NOT NULL,

   severity              text NOT NULL DEFAULT 'major'
                         CHECK (
                            severity IN (
                               'absolute',
                               'major',
                               'relative',
                               'precaution'
                            )
                         ),

   context_condition     jsonb,
   description           text NOT NULL,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, contraindication_code)
);

COMMENT ON TABLE knowledge.medication_contraindication IS
'Explicit medication safety constraints. Conditions and universal concepts can independently trigger contraindication or precaution logic.';

CREATE INDEX idx_knowledge_medication_contraindication_med
   ON knowledge.medication_contraindication(medication_id);

CREATE INDEX idx_knowledge_medication_contraindication_condition
   ON knowledge.medication_contraindication(condition_id);

CREATE INDEX idx_knowledge_medication_contraindication_concept
   ON knowledge.medication_contraindication(concept_id);


-- =============================================================================
-- 7. DRUG-DRUG INTERACTIONS
-- =============================================================================

CREATE TABLE knowledge.medication_interaction (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   interacting_medication_id
                         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   interaction_code      text NOT NULL UNIQUE,

   interaction_type      text NOT NULL
                         CHECK (
                            interaction_type IN (
                               'contraindicated',
                               'avoid',
                               'major',
                               'moderate',
                               'minor',
                               'monitor',
                               'dose_adjustment'
                            )
                         ),

   mechanism             text,
   clinical_effect       text,
   management            text,

   context_condition     jsonb NOT NULL DEFAULT '{}'::jsonb,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   CHECK (medication_id <> interacting_medication_id),

   UNIQUE (
      medication_id,
      interacting_medication_id,
      interaction_code
   )
);

COMMENT ON TABLE knowledge.medication_interaction IS
'Drug-drug interaction knowledge. Interaction severity, mechanism, expected effect and management are explicit and context-aware.';

CREATE INDEX idx_knowledge_medication_interaction_source
   ON knowledge.medication_interaction(medication_id);

CREATE INDEX idx_knowledge_medication_interaction_target
   ON knowledge.medication_interaction(interacting_medication_id);

CREATE INDEX idx_knowledge_medication_interaction_type
   ON knowledge.medication_interaction(interaction_type);


-- =============================================================================
-- 8. MEDICATION ↔ CONCEPT SAFETY RELATIONSHIPS
-- =============================================================================
-- Supports universal facts such as allergy, pregnancy state, renal function,
-- QT prolongation, bleeding risk, etc., without forcing everything into
-- condition rows.

CREATE TABLE knowledge.medication_concept_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   concept_id            uuid NOT NULL REFERENCES knowledge.concept(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL
                         CHECK (
                            relationship_type IN (
                               'contraindicated_in',
                               'caution_in',
                               'requires_monitoring',
                               'dose_adjustment',
                               'adverse_effect',
                               'therapeutic_target',
                               'mechanism',
                               'allergy_trigger',
                               'safety_signal'
                            )
                         ),

   severity              text
                         CHECK (
                            severity IS NULL OR
                            severity IN (
                               'critical',
                               'major',
                               'moderate',
                               'minor',
                               'informational'
                            )
                         ),

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   condition_expression  jsonb,
   description           text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      concept_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.medication_concept_rule IS
'Universal medication-to-concept safety and clinical relationships. Allows medication intelligence to react directly to facts without requiring a disease node.';

CREATE INDEX idx_knowledge_medication_concept_rule_med
   ON knowledge.medication_concept_rule(medication_id);

CREATE INDEX idx_knowledge_medication_concept_rule_concept
   ON knowledge.medication_concept_rule(concept_id);

CREATE INDEX idx_knowledge_medication_concept_rule_type
   ON knowledge.medication_concept_rule(relationship_type);


-- =============================================================================
-- 9. ADVERSE EFFECT LIBRARY
-- =============================================================================
-- Adverse effects are concepts, not free-text drug-owned strings.

CREATE TABLE knowledge.medication_adverse_effect (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   concept_id            uuid REFERENCES knowledge.concept(id),

   adverse_effect_code   text NOT NULL,

   severity              text NOT NULL DEFAULT 'moderate'
                         CHECK (
                            severity IN (
                               'mild',
                               'moderate',
                               'severe',
                               'life_threatening',
                               'fatal'
                            )
                         ),

   frequency_category    text
                         CHECK (
                            frequency_category IS NULL OR
                            frequency_category IN (
                               'very_common',
                               'common',
                               'uncommon',
                               'rare',
                               'very_rare',
                               'unknown'
                            )
                         ),

   onset_expression      text,
   risk_context          jsonb NOT NULL DEFAULT '{}'::jsonb,

   action_if_occurs      text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, adverse_effect_code)
);

COMMENT ON TABLE knowledge.medication_adverse_effect IS
'Structured adverse-effect relationships between medications and universal clinical concepts.';

CREATE INDEX idx_knowledge_medication_adverse_effect_med
   ON knowledge.medication_adverse_effect(medication_id);

CREATE INDEX idx_knowledge_medication_adverse_effect_concept
   ON knowledge.medication_adverse_effect(concept_id);


-- =============================================================================
-- 10. MEDICATION MONITORING REQUIREMENTS
-- =============================================================================
-- Medication monitoring feeds the universal monitoring engine from Migration
-- 015 rather than inventing a separate drug-monitoring system.

CREATE TABLE knowledge.medication_monitoring (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   monitoring_id         uuid NOT NULL REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   indication_id         uuid REFERENCES knowledge.condition(id),

   reason                 text,

   timing_expression      text,

   baseline_required      boolean NOT NULL DEFAULT false,
   ongoing_required      boolean NOT NULL DEFAULT false,
   post_dose_required    boolean NOT NULL DEFAULT false,

   threshold_expression   jsonb,

   escalation_expression  jsonb,

   evidence_source        text,
   evidence_level         text,

   status                 text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      monitoring_id,
      indication_id
   )
);

COMMENT ON TABLE knowledge.medication_monitoring IS
'Connects medications to the universal monitoring substrate. Baseline, ongoing, threshold and escalation logic remain reusable and context-aware.';

CREATE INDEX idx_knowledge_medication_monitoring_med
   ON knowledge.medication_monitoring(medication_id);

CREATE INDEX idx_knowledge_medication_monitoring_target
   ON knowledge.medication_monitoring(monitoring_id);

CREATE INDEX idx_knowledge_medication_monitoring_condition
   ON knowledge.medication_monitoring(indication_id);


-- =============================================================================
-- 11. SPECIAL-POPULATION MEDICATION INTELLIGENCE
-- =============================================================================
-- Explicit population-specific constraints prevent unsafe assumptions.

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_population_rule CASCADE;
CREATE TABLE knowledge.medication_population_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   context_type_code     text NOT NULL REFERENCES knowledge.context_type(code),

   context_value_id      uuid REFERENCES knowledge.context_value(id),

   rule_type              text NOT NULL
                          CHECK (
                             rule_type IN (
                                'allowed',
                                'avoid',
                                'contraindicated',
                                'dose_adjustment',
                                'route_restriction',
                                'monitoring_required',
                                'special_precaution'
                             )
                          ),

   severity               text
                          CHECK (
                             severity IS NULL OR
                             severity IN (
                                'critical',
                                'major',
                                'moderate',
                                'minor',
                                'informational'
                             )
                          ),

   expression             jsonb NOT NULL DEFAULT '{}'::jsonb,
   rationale              text,

   evidence_source        text,
   evidence_level         text,

   status                 text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      context_type_code,
      context_value_id,
      rule_type
   )
);

COMMENT ON TABLE knowledge.medication_population_rule IS
'Population/context-specific medication constraints. Supports age, pregnancy, renal/hepatic status, lactation, geography and other universal contexts.';

CREATE INDEX idx_knowledge_medication_population_med
   ON knowledge.medication_population_rule(medication_id);

CREATE INDEX idx_knowledge_medication_population_context
   ON knowledge.medication_population_rule(
      context_type_code,
      context_value_id
   );


-- =============================================================================
-- 12. MEDICATION-ALLERGY / IMMUNOLOGIC SAFETY
-- =============================================================================
-- Allergy is sufficiently safety-critical to have an explicit high-speed path.

CREATE TABLE knowledge.medication_allergy_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   allergen_concept_id   uuid REFERENCES knowledge.concept(id),

   allergen_code         text NOT NULL,

   reaction_type         text,

   severity              text NOT NULL DEFAULT 'major'
                         CHECK (
                            severity IN (
                               'critical',
                               'major',
                               'moderate',
                               'minor',
                               'unknown'
                            )
                         ),

   cross_reactivity      jsonb NOT NULL DEFAULT '{}'::jsonb,

   action                 text NOT NULL,

   evidence_source        text,
   evidence_level         text,

   status                 text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, allergen_code)
);

COMMENT ON TABLE knowledge.medication_allergy_rule IS
'Fast-path medication allergy and cross-reactivity intelligence for prescribing safety.';

CREATE INDEX idx_knowledge_medication_allergy_med
   ON knowledge.medication_allergy_rule(medication_id);

CREATE INDEX idx_knowledge_medication_allergy_concept
   ON knowledge.medication_allergy_rule(allergen_concept_id);


-- =============================================================================
-- 13. MEDICATION ADMINISTRATION REQUIREMENTS
-- =============================================================================
-- Separates "what drug" from "how safely it is administered".

CREATE TABLE knowledge.medication_administration_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   route_code             text,

   formulation_id         uuid REFERENCES knowledge.medication_formulation(id),

   administration_code    text NOT NULL,

   instruction             text NOT NULL,

   timing_expression       text,
   dilution_expression     text,
   infusion_expression     text,

   food_relationship       text
                          CHECK (
                             food_relationship IS NULL OR
                             food_relationship IN (
                                'with_food',
                                'without_food',
                                'either',
                                'food_dependent'
                             )
                          ),

   special_equipment       text,

   safety_requirements     jsonb NOT NULL DEFAULT '{}'::jsonb,

   evidence_source         text,
   evidence_level          text,

   status                  text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      administration_code
   )
);

COMMENT ON TABLE knowledge.medication_administration_rule IS
'Structured medication administration instructions reusable by prescribing and protocol engines.';


CREATE INDEX idx_knowledge_medication_admin_med
   ON knowledge.medication_administration_rule(medication_id);

CREATE INDEX idx_knowledge_medication_admin_formulation
   ON knowledge.medication_administration_rule(formulation_id);


-- =============================================================================
-- 14. MEDICATION DUPLICATION / THERAPEUTIC CLASS RELATIONSHIPS
-- =============================================================================
-- Prevents unsafe duplication and allows class-level reasoning.

CREATE TABLE knowledge.medication_relationship (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_medication_id  uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   target_medication_id  uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL
                         CHECK (
                            relationship_type IN (
                               'same_active_ingredient',
                               'same_therapeutic_class',
                               'same_pharmacologic_class',
                               'therapeutic_duplicate',
                               'alternative_to',
                               'synergistic_with',
                               'antagonistic_to',
                               'substitute_for',
                               'combination_product',
                               'cross_reactive_with'
                            )
                         ),

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   context_expression    jsonb NOT NULL DEFAULT '{}'::jsonb,

   description           text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   CHECK (source_medication_id <> target_medication_id),

   UNIQUE (
      source_medication_id,
      target_medication_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.medication_relationship IS
'Graph relationships between medications supporting duplication detection, substitution, therapeutic class reasoning and combination logic.';

CREATE INDEX idx_knowledge_medication_relationship_source
   ON knowledge.medication_relationship(source_medication_id);

CREATE INDEX idx_knowledge_medication_relationship_target
   ON knowledge.medication_relationship(target_medication_id);

CREATE INDEX idx_knowledge_medication_relationship_type
   ON knowledge.medication_relationship(relationship_type);


-- =============================================================================
-- 15. MEDICATION → MECHANISM
-- =============================================================================
-- Connects pharmacology to the universal pathophysiology substrate.

CREATE TABLE knowledge.medication_mechanism (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL DEFAULT 'acts_through'
                         CHECK (
                            relationship_type IN (
                               'acts_through',
                               'inhibits',
                               'activates',
                               'blocks',
                               'replaces',
                               'modulates',
                               'targets'
                            )
                         ),

   weight                numeric(5,3) NOT NULL DEFAULT 1.0,

   description           text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      mechanism_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.medication_mechanism IS
'Connects medication pharmacology to reusable pathophysiological mechanisms.';


CREATE INDEX idx_knowledge_medication_mechanism_med
   ON knowledge.medication_mechanism(medication_id);

CREATE INDEX idx_knowledge_medication_mechanism_mech
   ON knowledge.medication_mechanism(mechanism_id);


-- =============================================================================
-- 16. MEDICATION → INVESTIGATION
-- =============================================================================
-- Some medicines require investigation before, during or after use.

CREATE TABLE knowledge.medication_investigation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   investigation_id      uuid NOT NULL REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   requirement_type      text NOT NULL
                         CHECK (
                            requirement_type IN (
                               'baseline',
                               'monitoring',
                               'diagnostic',
                               'toxicity',
                               'efficacy',
                               'safety'
                            )
                         ),

   indication_id         uuid REFERENCES knowledge.condition(id),

   timing_expression     text,

   threshold_expression  jsonb,

   rationale             text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      investigation_id,
      requirement_type,
      indication_id
   )
);

COMMENT ON TABLE knowledge.medication_investigation IS
'Medication-linked investigations. Uses the universal investigation layer rather than disease-specific test definitions.';

CREATE INDEX idx_knowledge_medication_investigation_med
   ON knowledge.medication_investigation(medication_id);

CREATE INDEX idx_knowledge_medication_investigation_inv
   ON knowledge.medication_investigation(investigation_id);

CREATE INDEX idx_knowledge_medication_investigation_condition
   ON knowledge.medication_investigation(indication_id);


-- =============================================================================
-- 17. MEDICATION → EDUCATION
-- =============================================================================
-- Medication counselling becomes part of the universal education engine.

CREATE TABLE knowledge.medication_education (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   education_id          uuid NOT NULL REFERENCES knowledge.education(id)
                         ON DELETE CASCADE,

   context_expression    jsonb NOT NULL DEFAULT '{}'::jsonb,

   priority              integer NOT NULL DEFAULT 50,

   required_for          text
                         CHECK (
                            required_for IS NULL OR
                            required_for IN (
                               'initiation',
                               'discharge',
                               'high_risk',
                               'all',
                               'follow_up'
                            )
                         ),

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (medication_id, education_id)
);

COMMENT ON TABLE knowledge.medication_education IS
'Links reusable education content to medications so counselling and teach-back can be automatically composed into clinical workflows.';


CREATE INDEX idx_knowledge_medication_education_med
   ON knowledge.medication_education(medication_id);

CREATE INDEX idx_knowledge_medication_education_edu
   ON knowledge.medication_education(education_id);


-- =============================================================================
-- 18. MEDICATION → MONITORING / ESCALATION
-- =============================================================================
-- Extends monitoring with medication-specific response and safety thresholds.

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.medication_monitoring_rule CASCADE;
CREATE TABLE knowledge.medication_monitoring_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   monitoring_id         uuid NOT NULL REFERENCES knowledge.monitoring(id)
                         ON DELETE CASCADE,

   condition_id          uuid REFERENCES knowledge.condition(id),

   trigger_type          text NOT NULL
                         CHECK (
                            trigger_type IN (
                               'baseline',
                               'trend',
                               'threshold',
                               'new_symptom',
                               'adverse_effect',
                               'treatment_response',
                               'treatment_failure'
                            )
                         ),

   trigger_expression    jsonb NOT NULL,

   action_type           text NOT NULL
                         CHECK (
                            action_type IN (
                               'continue',
                               'repeat_measurement',
                               'reassess',
                               'hold',
                               'stop',
                               'adjust',
                               'escalate',
                               'urgent_review',
                               'emergency_review'
                            )
                         ),

   action_expression     jsonb,

   rationale             text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      monitoring_id,
      condition_id,
      trigger_type
   )
);

COMMENT ON TABLE knowledge.medication_monitoring_rule IS
'Medication safety and response rules operating on the universal monitoring substrate. These rules may trigger reassessment or escalation rather than directly prescribing an unverified action.';

CREATE INDEX idx_knowledge_medication_monitoring_rule_med
   ON knowledge.medication_monitoring_rule(medication_id);

CREATE INDEX idx_knowledge_medication_monitoring_rule_monitoring
   ON knowledge.medication_monitoring_rule(monitoring_id);

CREATE INDEX idx_knowledge_medication_monitoring_rule_condition
   ON knowledge.medication_monitoring_rule(condition_id);


-- =============================================================================
-- 19. ANTIMICROBIAL STEWARDSHIP INTELLIGENCE
-- =============================================================================
-- Universal antimicrobial metadata. No disease-specific antimicrobial engine.

CREATE TABLE knowledge.antimicrobial_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   condition_id          uuid REFERENCES knowledge.condition(id),

   rule_type             text NOT NULL
                         CHECK (
                            rule_type IN (
                               'empiric',
                               'targeted',
                               'de_escalation',
                               'escalation',
                               'prophylaxis',
                               'culture_directed',
                               'resistance_consideration',
                               'stewardship'
                            )
                         ),

   microbiology_context  jsonb NOT NULL DEFAULT '{}'::jsonb,

   recommendation_expression jsonb NOT NULL DEFAULT '{}'::jsonb,

   duration_expression   text,

   review_time_expression text,

   stop_condition        jsonb,

   rationale             text,

   evidence_source       text,
   evidence_level        text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (
      medication_id,
      condition_id,
      rule_type
   )
);

COMMENT ON TABLE knowledge.antimicrobial_rule IS
'Universal antimicrobial stewardship substrate. Specific recommendations remain guideline-, organism-, resistance-, population- and facility-context dependent.';

CREATE INDEX idx_knowledge_antimicrobial_rule_med
   ON knowledge.antimicrobial_rule(medication_id);

CREATE INDEX idx_knowledge_antimicrobial_rule_condition
   ON knowledge.antimicrobial_rule(condition_id);


-- =============================================================================
-- 20. MEDICATION EVIDENCE / PROVENANCE
-- =============================================================================
-- Independent provenance layer for medication knowledge.

CREATE TABLE knowledge.medication_source (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   source_type            text NOT NULL
                         CHECK (
                            source_type IN (
                               'guideline',
                               'formulary',
                               'drug_label',
                               'pharmacopoeia',
                               'literature',
                               'systematic_review',
                               'expert',
                               'facility',
                               'regulatory'
                            )
                         ),

   source_ref             text,
   citation               text,
   url                    text,

   evidence_level         text,

   jurisdiction           text,
   publication_date       date,
   accessed_at            timestamptz,

   notes                  text,

   UNIQUE (
      medication_id,
      source_type,
      source_ref
   )
);

COMMENT ON TABLE knowledge.medication_source IS
'Medication-specific evidence and provenance. Supports jurisdiction-aware clinical knowledge and explainability.';

CREATE INDEX idx_knowledge_medication_source_med
   ON knowledge.medication_source(medication_id);

CREATE INDEX idx_knowledge_medication_source_type
   ON knowledge.medication_source(source_type);


-- =============================================================================
-- 21. MEDICATION VERSION
-- =============================================================================
-- Drug knowledge can evolve without destroying historical clinical meaning.

CREATE TABLE knowledge.medication_version (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   version                integer NOT NULL,

   snapshot               jsonb NOT NULL,

   change_type            text
                          CHECK (
                             change_type IS NULL OR
                             change_type IN (
                                'created',
                                'corrected',
                                'safety_update',
                                'guideline_update',
                                'formulary_update',
                                'retired',
                                'reinstated'
                             )
                          ),

   change_reason          text,

   changed_by             text,
   changed_at             timestamptz NOT NULL DEFAULT now(),

   UNIQUE (medication_id, version)
);

COMMENT ON TABLE knowledge.medication_version IS
'Immutable medication knowledge snapshots for temporal reasoning, auditability and provenance.';

CREATE INDEX idx_knowledge_medication_version_med
   ON knowledge.medication_version(medication_id, version);


-- =============================================================================
-- 22. MEDICATION KNOWLEDGE STATUS
-- =============================================================================
-- Fast resolution flags for the clinical operating system.

CREATE TABLE knowledge.medication_safety_status (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   medication_id         uuid NOT NULL REFERENCES knowledge.medication(id)
                         ON DELETE CASCADE,

   status_code            text NOT NULL
                         CHECK (
                            status_code IN (
                               'verified',
                               'unverified',
                               'restricted',
                               'high_alert',
                               'interaction_risk',
                               'dose_review_required',
                               'formulary_review_required',
                               'regulatory_review_required',
                               'retired'
                            )
                         ),

   severity               text NOT NULL DEFAULT 'informational'
                         CHECK (
                            severity IN (
                               'informational',
                               'minor',
                               'moderate',
                               'major',
                               'critical'
                            )
                         ),

   reason                 text,

   source_ref             text,

   effective_from         timestamptz NOT NULL DEFAULT now(),
   effective_to           timestamptz,

   status                 text NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','retired')),

   UNIQUE (
      medication_id,
      status_code,
      effective_from
   )
);

COMMENT ON TABLE knowledge.medication_safety_status IS
'Fast-path medication safety state consumed by the clinical operating system before medication recommendations are rendered.';

CREATE INDEX idx_knowledge_medication_safety_status_med
   ON knowledge.medication_safety_status(medication_id);

CREATE INDEX idx_knowledge_medication_safety_status_active
   ON knowledge.medication_safety_status(status_code, status)
   WHERE status = 'active';


-- =============================================================================
-- 23. UNIVERSAL KNOWLEDGE-GRAPH RELATIONSHIPS
-- =============================================================================
-- Migration 011 already provides knowledge.relationship. These explicit
-- medication edges make the most important medication traversals fast and
-- machine-readable without creating a second knowledge graph.

INSERT INTO knowledge.relationship (
   source_type,
   source_id,
   relationship_type,
   target_type,
   target_id,
   weight,
   polarity,
   context,
   confidence,
   evidence,
   version,
   is_active
)
SELECT
   'medication',
   mc.medication_id,
   'treats',
   'condition',
   mc.condition_id,
   mc.weight,
   'positive',
   jsonb_build_object('role', mc.role),
   NULL,
   mc.evidence_source,
   NULL,
   true
FROM knowledge.medication_condition mc
WHERE NOT EXISTS (
   SELECT 1
   FROM knowledge.relationship r
   WHERE r.source_type = 'medication'
     AND r.source_id = mc.medication_id
     AND r.relationship_type = 'treats'
     AND r.target_type = 'condition'
     AND r.target_id = mc.condition_id
     AND r.is_active = true
);


-- =============================================================================
-- 24. FAST RESOLUTION INDEXES
-- =============================================================================
-- These indexes support the clinical CPU's high-frequency traversals:
--
--   patient facts
--       ↓
--   medication candidates
--       ↓
--   indication
--       ↓
--   contraindication / interaction / context
--       ↓
--   dose reference
--       ↓
--   monitoring
--       ↓
--   education
--
-- Partial indexes keep active knowledge fast.

CREATE INDEX idx_knowledge_medication_active
   ON knowledge.medication(id)
   WHERE status = 'active';

CREATE INDEX idx_knowledge_medication_condition_active
   ON knowledge.medication_condition(condition_id, medication_id)
   WHERE status = 'active';

CREATE INDEX idx_knowledge_dose_reference_active_verified
   ON knowledge.drug_dose_reference(
      medication_id,
      condition_id,
      population
   )
   WHERE status = 'active'
     AND is_verified = true
     AND verification_status = 'verified';

CREATE INDEX idx_knowledge_contraindication_active
   ON knowledge.medication_contraindication(
      medication_id,
      condition_id
   )
   WHERE status = 'active';

CREATE INDEX idx_knowledge_interaction_active_source
   ON knowledge.medication_interaction(
      medication_id,
      interaction_type
   )
   WHERE status = 'active';

CREATE INDEX idx_knowledge_interaction_active_target
   ON knowledge.medication_interaction(
      interacting_medication_id,
      interaction_type
   )
   WHERE status = 'active';

CREATE INDEX idx_knowledge_population_rule_active
   ON knowledge.medication_population_rule(
      medication_id,
      context_type_code,
      context_value_id
   )
   WHERE status = 'active';

CREATE INDEX idx_knowledge_medication_condition_role
   ON knowledge.medication_condition(
      condition_id,
      role,
      weight DESC
   )
   WHERE status = 'active';


-- =============================================================================
-- 25. CLINICAL SAFETY RESOLUTION VIEW
-- =============================================================================
-- A medication recommendation must pass through safety state before it can
-- become an executable clinical action.

CREATE VIEW knowledge.medication_safety_resolution AS
SELECT
   m.id AS medication_id,
   m.medication_code,
   m.generic_name,
   m.formulary_status,
   m.high_alert,
   m.narrow_therapeutic_index,
   COALESCE(
      jsonb_agg(
         DISTINCT jsonb_build_object(
            'status_code', ss.status_code,
            'severity', ss.severity,
            'reason', ss.reason,
            'source_ref', ss.source_ref
         )
      ) FILTER (WHERE ss.id IS NOT NULL),
      '[]'::jsonb
   ) AS safety_statuses
FROM knowledge.medication m
LEFT JOIN knowledge.medication_safety_status ss
   ON ss.medication_id = m.id
  AND ss.status = 'active'
  AND ss.effective_from <= now()
  AND (
      ss.effective_to IS NULL
      OR ss.effective_to >= now()
  )
WHERE m.status = 'active'
GROUP BY
   m.id,
   m.medication_code,
   m.generic_name,
   m.formulary_status,
   m.high_alert,
   m.narrow_therapeutic_index;

COMMENT ON VIEW knowledge.medication_safety_resolution IS
'Fast medication safety resolution surface consumed before a medication recommendation is exposed to the clinical workflow.';


-- =============================================================================
-- 26. PRESCRIBING READINESS VIEW
-- =============================================================================
-- This does NOT prescribe. It tells the operating system whether the
-- knowledge substrate contains the minimum information necessary for a
-- medication candidate to proceed to clinical decision logic.

CREATE VIEW knowledge.medication_prescribing_readiness AS
SELECT
   m.id AS medication_id,
   m.medication_code,
   m.generic_name,

   EXISTS (
      SELECT 1
      FROM knowledge.medication_condition mc
      WHERE mc.medication_id = m.id
        AND mc.status = 'active'
   ) AS has_indication,

   EXISTS (
      SELECT 1
      FROM knowledge.medication_formulation mf
      WHERE mf.medication_id = m.id
        AND mf.status = 'active'
   ) AS has_formulation,

   EXISTS (
      SELECT 1
      FROM knowledge.drug_dose_reference dd
      WHERE dd.medication_id = m.id
        AND dd.status = 'active'
        AND dd.is_verified = true
        AND dd.verification_status = 'verified'
   ) AS has_verified_dose_reference,

   EXISTS (
      SELECT 1
      FROM knowledge.medication_source ms
      WHERE ms.medication_id = m.id
   ) AS has_provenance,

   EXISTS (
      SELECT 1
      FROM knowledge.medication_contraindication ci
      WHERE ci.medication_id = m.id
        AND ci.status = 'active'
   ) AS has_safety_constraints,

   EXISTS (
      SELECT 1
      FROM knowledge.medication_monitoring mm
      WHERE mm.medication_id = m.id
        AND mm.status = 'active'
   ) AS has_monitoring,

   CASE
      WHEN m.status <> 'active'
         THEN 'unavailable'

      WHEN m.formulary_status IN ('retired','non_formulary')
         THEN 'formulary_review'

      WHEN EXISTS (
         SELECT 1
         FROM knowledge.medication_safety_status ss
         WHERE ss.medication_id = m.id
           AND ss.status = 'active'
           AND ss.status_code = 'retired'
      )
         THEN 'unavailable'

      WHEN NOT EXISTS (
         SELECT 1
         FROM knowledge.medication_source ms
         WHERE ms.medication_id = m.id
      )
         THEN 'provenance_review'

      WHEN NOT EXISTS (
         SELECT 1
         FROM knowledge.drug_dose_reference dd
         WHERE dd.medication_id = m.id
           AND dd.status = 'active'
           AND dd.is_verified = true
           AND dd.verification_status = 'verified'
      )
         THEN 'dose_verification_required'

      ELSE 'knowledge_ready'
   END AS readiness_state

FROM knowledge.medication m;


COMMENT ON VIEW knowledge.medication_prescribing_readiness IS
'Determines whether medication knowledge is sufficiently verified for downstream clinical decision logic. Knowledge readiness is not equivalent to prescribing authority.';


-- =============================================================================
-- 27. UPDATED-AT TRIGGERS
-- =============================================================================

CREATE TRIGGER trg_knowledge_medication_formulation_updated_at
   BEFORE UPDATE ON knowledge.medication_formulation
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_knowledge_medication_adverse_effect_updated_at
   BEFORE UPDATE ON knowledge.medication_adverse_effect
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 28. SAFETY INVARIANTS
-- =============================================================================
-- Prevent obviously unsafe data states at the substrate level.

CREATE OR REPLACE FUNCTION knowledge.validate_medication_dose_reference()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

   IF NEW.is_verified = true
      AND NEW.verification_status <> 'verified'
   THEN
      RAISE EXCEPTION
         'Verified medication dose reference must have verification_status=verified';
   END IF;

   IF NEW.verification_status = 'verified'
      AND NEW.is_verified = false
   THEN
      RAISE EXCEPTION
         'verification_status=verified requires is_verified=true';
   END IF;

   IF NEW.verified_at IS NOT NULL
      AND NEW.is_verified = false
   THEN
      RAISE EXCEPTION
         'verified_at cannot be populated for an unverified dose reference';
   END IF;

   RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_medication_dose_reference
   BEFORE INSERT OR UPDATE
   ON knowledge.drug_dose_reference
   FOR EACH ROW
   EXECUTE FUNCTION knowledge.validate_medication_dose_reference();


-- =============================================================================
-- 29. UNIVERSAL MEDICATION GRAPH CONTRACT
-- =============================================================================
-- Medication intelligence is now traversable through the existing universal
-- substrate:
--
-- CONCEPT
--   ├── MEDICATION
--   │     ├── FORMULATION
--   │     ├── ROUTE
--   │     ├── DOSE REFERENCE
--   │     ├── CONDITION / INDICATION
--   │     ├── CONTRAINDICATION
--   │     ├── DRUG-DRUG INTERACTION
--   │     ├── ADVERSE EFFECT
--   │     ├── POPULATION RULE
--   │     ├── ALLERGY RULE
--   │     ├── ADMINISTRATION RULE
--   │     ├── MONITORING
--   │     ├── INVESTIGATION
--   │     ├── EDUCATION
--   │     ├── MECHANISM
--   │     └── STEWARDSHIP
--   │
--   └── UNIVERSAL KNOWLEDGE GRAPH
--
-- Clinical CPU traversal:
--
-- PATIENT CONTEXT
--      ↓
-- OBSERVED FACTS
--      ↓
-- PHENOTYPE / CONDITION
--      ↓
-- MEDICATION CANDIDATES
--      ↓
-- INDICATION RESOLUTION
--      ↓
-- AGE / WEIGHT / RENAL / HEPATIC / PREGNANCY / OTHER CONTEXT
--      ↓
-- CONTRAINDICATION + ALLERGY CHECK
--      ↓
-- DRUG-DRUG INTERACTION CHECK
--      ↓
-- FORMULARY / FACILITY OVERRIDE
--      ↓
-- VERIFIED DOSE REFERENCE
--      ↓
-- ADMINISTRATION REQUIREMENTS
--      ↓
-- BASELINE INVESTIGATION / MONITORING
--      ↓
-- RESPONSE / TOXICITY MONITORING
--      ↓
-- EDUCATION + TEACH-BACK
--      ↓
-- PROVENANCE / EXPLANATION
--
-- No disease-specific medication engine is required.
-- =============================================================================
