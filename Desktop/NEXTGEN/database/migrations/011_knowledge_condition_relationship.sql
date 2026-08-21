-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 011: condition layer + universal clinical graph
-- =============================================================================
-- PRINCIPLES
--   1. Conditions are compositions of universal concepts, symptoms, signs,
--      phenotypes, mechanisms, risks, investigations and interventions.
--   2. No disease-specific engine is created here.
--   3. The same substrate supports medicine, surgery, paediatrics, OBGYN,
--      psychiatry, emergency medicine, radiology, pathology, pharmacology,
--      public health and subspecialties.
--   4. Clinical knowledge is contextual, weighted, versionable and traceable.
--   5. The generalized graph permits arbitrary future knowledge without schema
--      redesign.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS knowledge;

-- =============================================================================
-- 8. CONDITION / DISEASE LAYER
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition CASCADE;
CREATE TABLE knowledge.condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id            uuid REFERENCES knowledge.concept(id),
   condition_code        text NOT NULL UNIQUE,
   canonical_name        text NOT NULL,
   display_name          text,
   description           text,

   condition_type        text NOT NULL DEFAULT 'disease'
                         CHECK (
                            condition_type IN (
                               'disease',
                               'syndrome',
                               'disorder',
                               'injury',
                               'infection',
                               'neoplasm',
                               'congenital',
                               'genetic',
                               'metabolic',
                               'autoimmune',
                               'inflammatory',
                               'degenerative',
                               'vascular',
                               'toxic',
                               'iatrogenic',
                               'physiologic',
                               'pregnancy_related',
                               'postoperative',
                               'traumatic',
                               'functional',
                               'symptom_complex'
                            )
                         ),

   clinical_course       text
                         CHECK (
                            clinical_course IS NULL OR clinical_course IN (
                               'acute',
                               'subacute',
                               'chronic',
                               'recurrent',
                               'episodic',
                               'progressive',
                               'relapsing',
                               'self_limited',
                               'lifelong'
                            )
                         ),

   etiologic_class       text
                         CHECK (
                            etiologic_class IS NULL OR etiologic_class IN (
                               'infectious',
                               'inflammatory',
                               'autoimmune',
                               'neoplastic',
                               'vascular',
                               'metabolic',
                               'endocrine',
                               'genetic',
                               'congenital',
                               'degenerative',
                               'traumatic',
                               'toxic',
                               'iatrogenic',
                               'nutritional',
                               'environmental',
                               'functional',
                               'idiopathic',
                               'multifactorial'
                            )
                         ),

   severity_model        text,
   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   version               text,
   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.condition IS
'Universal disease/condition node composed from shared clinical knowledge primitives.';

CREATE INDEX idx_knowledge_condition_concept
   ON knowledge.condition(concept_id);

CREATE INDEX idx_knowledge_condition_type
   ON knowledge.condition(condition_type);

CREATE INDEX idx_knowledge_condition_course
   ON knowledge.condition(clinical_course);

CREATE INDEX idx_knowledge_condition_etiology
   ON knowledge.condition(etiologic_class);

CREATE INDEX idx_knowledge_condition_name
   ON knowledge.condition(canonical_name);

CREATE TRIGGER trg_knowledge_condition_updated_at
   BEFORE UPDATE ON knowledge.condition
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 8.1 CONDITION IDENTIFIERS / TERMINOLOGY
-- =============================================================================

CREATE TABLE knowledge.condition_synonym (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   synonym               text NOT NULL,
   language_code         text,
   terminology           text,
   is_preferred          boolean NOT NULL DEFAULT false,
   UNIQUE (condition_id, synonym, language_code)
);

COMMENT ON TABLE knowledge.condition_synonym IS
'Alternative names, historical names, abbreviations and terminology mappings.';

CREATE INDEX idx_condition_synonym_condition
   ON knowledge.condition_synonym(condition_id);

CREATE INDEX idx_condition_synonym_text
   ON knowledge.condition_synonym(synonym);


CREATE TABLE knowledge.condition_code (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   coding_system         text NOT NULL,
   code                  text NOT NULL,
   display_name          text,
   version               text,
   is_primary             boolean NOT NULL DEFAULT false,
   UNIQUE (coding_system, code)
);

COMMENT ON TABLE knowledge.condition_code IS
'External and internal classification codes such as ICD, SNOMED CT and local AMEXAN codes.';

CREATE INDEX idx_condition_code_condition
   ON knowledge.condition_code(condition_id);

CREATE INDEX idx_condition_code_system
   ON knowledge.condition_code(coding_system, code);


-- =============================================================================
-- 8.2 CONDITION CONTEXT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_context CASCADE;
CREATE TABLE knowledge.condition_context (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   context_type_code     text NOT NULL REFERENCES knowledge.context_type(code),
   context_value_id      uuid REFERENCES knowledge.context_value(id),
   applicability          text NOT NULL DEFAULT 'applies'
                         CHECK (applicability IN ('applies','excludes')),
   likelihood_modifier   numeric(5,3),
   severity_modifier     numeric(5,3),
   priority              integer NOT NULL DEFAULT 0,
   description           text,

   UNIQUE (
      condition_id,
      context_type_code,
      context_value_id,
      applicability
   )
);

COMMENT ON TABLE knowledge.condition_context IS
'Clinical context modifiers for age, sex, pregnancy, geography, acuity, care setting and other dimensions.';

CREATE INDEX idx_condition_context_lookup
   ON knowledge.condition_context(
      context_type_code,
      context_value_id
   );

CREATE INDEX idx_condition_context_condition
   ON knowledge.condition_context(condition_id);


-- =============================================================================
-- 8.3 CONDITION BODY SYSTEM / SPECIALTY
-- =============================================================================

CREATE TABLE knowledge.condition_system (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   body_system_code      text NOT NULL REFERENCES knowledge.body_system(code),
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   is_primary            boolean NOT NULL DEFAULT false,
   UNIQUE (condition_id, body_system_code)
);

COMMENT ON TABLE knowledge.condition_system IS
'Body systems involved in a condition. A condition may involve multiple systems.';


CREATE TABLE knowledge.condition_specialty (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   specialty_code        text NOT NULL REFERENCES organization.specialty(code),
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   is_primary            boolean NOT NULL DEFAULT false,
   UNIQUE (condition_id, specialty_code)
);

COMMENT ON TABLE knowledge.condition_specialty IS
'Specialties relevant to diagnosis, management or referral of a condition.';


-- =============================================================================
-- 8.4 CONDITION ETIOLOGY
-- =============================================================================

CREATE TABLE knowledge.condition_etiology (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   etiology_type         text NOT NULL
                         CHECK (
                            etiology_type IN (
                               'infectious_agent',
                               'genetic',
                               'environmental',
                               'nutritional',
                               'metabolic',
                               'immune',
                               'vascular',
                               'traumatic',
                               'toxic',
                               'iatrogenic',
                               'behavioral',
                               'occupational',
                               'congenital',
                               'idiopathic',
                               'other'
                            )
                         ),
   concept_id            uuid REFERENCES knowledge.concept(id),
   etiology_code         text NOT NULL,
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),
   description           text,
   UNIQUE (condition_id, etiology_type, etiology_code)
);

COMMENT ON TABLE knowledge.condition_etiology IS
'Causes and etiologic contributors to a condition.';


CREATE INDEX idx_condition_etiology_code
   ON knowledge.condition_etiology(etiology_code);


-- =============================================================================
-- 8.5 RISK FACTORS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_risk_factor CASCADE;
CREATE TABLE knowledge.condition_risk_factor (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   risk_factor_concept_id uuid REFERENCES knowledge.concept(id),
   risk_factor_code      text NOT NULL,
   risk_factor_type      text,
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   attributable          boolean,
   modifiable            boolean,
   description           text,
   UNIQUE (condition_id, risk_factor_code)
);

COMMENT ON TABLE knowledge.condition_risk_factor IS
'Risk factors and predispositions for a condition.';


CREATE INDEX idx_condition_risk_factor_condition
   ON knowledge.condition_risk_factor(condition_id);

CREATE INDEX idx_condition_risk_factor_code
   ON knowledge.condition_risk_factor(risk_factor_code);


-- =============================================================================
-- 8.6 PROTECTIVE FACTORS
-- =============================================================================

CREATE TABLE knowledge.condition_protective_factor (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   concept_id            uuid REFERENCES knowledge.concept(id),
   factor_code           text NOT NULL,
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   description           text,
   UNIQUE (condition_id, factor_code)
);

COMMENT ON TABLE knowledge.condition_protective_factor IS
'Protective factors that reduce disease probability, severity or complications.';


-- =============================================================================
-- 8.7 MANIFESTATIONS
-- =============================================================================

CREATE TABLE knowledge.condition_manifestation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   manifestation_type    text NOT NULL
                         CHECK (
                            manifestation_type IN (
                               'symptom',
                               'sign',
                               'finding',
                               'laboratory',
                               'imaging',
                               'pathology',
                               'functional',
                               'behavioral'
                            )
                         ),
   concept_id            uuid REFERENCES knowledge.concept(id),
   manifestation_code    text NOT NULL,
   typicality            numeric(5,3) NOT NULL DEFAULT 1.0,
   diagnostic_weight     numeric(5,3) NOT NULL DEFAULT 1.0,
   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),
   timing                text,
   description           text,
   UNIQUE (
      condition_id,
      manifestation_type,
      manifestation_code,
      polarity
   )
);

COMMENT ON TABLE knowledge.condition_manifestation IS
'Universal clinical manifestations of a condition.';


CREATE INDEX idx_condition_manifestation_condition
   ON knowledge.condition_manifestation(condition_id);

CREATE INDEX idx_condition_manifestation_code
   ON knowledge.condition_manifestation(manifestation_code);


-- =============================================================================
-- 8.8 SYMPTOM ASSOCIATIONS
-- =============================================================================

CREATE TABLE knowledge.condition_symptom (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   symptom_id            uuid NOT NULL REFERENCES knowledge.symptom(id)
                         ON DELETE CASCADE,
   relationship_type     text NOT NULL DEFAULT 'associated_with'
                         CHECK (
                            relationship_type IN (
                               'typical',
                               'common',
                               'uncommon',
                               'rare',
                               'hallmark',
                               'associated_with',
                               'prodromal',
                               'late',
                               'complication',
                               'exclusionary'
                            )
                         ),
   likelihood_weight     numeric(5,3) NOT NULL DEFAULT 1.0,
   diagnostic_weight     numeric(5,3) NOT NULL DEFAULT 1.0,
   context               jsonb,
   UNIQUE (condition_id, symptom_id, relationship_type)
);

COMMENT ON TABLE knowledge.condition_symptom IS
'Condition-to-symptom relationships with diagnostic and contextual weighting.';

CREATE INDEX idx_condition_symptom_condition
   ON knowledge.condition_symptom(condition_id);

CREATE INDEX idx_condition_symptom_symptom
   ON knowledge.condition_symptom(symptom_id);


-- =============================================================================
-- 8.9 PHENOTYPES
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_phenotype CASCADE;
CREATE TABLE knowledge.condition_phenotype (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   phenotype_id          uuid NOT NULL REFERENCES knowledge.phenotype(id)
                         ON DELETE CASCADE,
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   likelihood_weight     numeric(5,3) NOT NULL DEFAULT 1.0,
   is_suggestive         boolean NOT NULL DEFAULT true,
   is_required           boolean NOT NULL DEFAULT false,
   context               jsonb,
   UNIQUE (condition_id, phenotype_id)
);

COMMENT ON TABLE knowledge.condition_phenotype IS
'Recurrent clinical phenotypes expressed by a condition.';


CREATE INDEX idx_condition_phenotype_condition
   ON knowledge.condition_phenotype(condition_id);

CREATE INDEX idx_condition_phenotype_phenotype
   ON knowledge.condition_phenotype(phenotype_id);


-- =============================================================================
-- 8.10 MECHANISMS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_mechanism CASCADE;
CREATE TABLE knowledge.condition_mechanism (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   role                  text
                         CHECK (
                            role IS NULL OR role IN (
                               'primary',
                               'secondary',
                               'contributing',
                               'protective',
                               'compensatory',
                               'downstream'
                            )
                         ),
   context               jsonb,
   UNIQUE (condition_id, mechanism_id)
);

COMMENT ON TABLE knowledge.condition_mechanism IS
'Pathophysiological mechanisms through which a condition manifests.';


CREATE INDEX idx_condition_mechanism_condition
   ON knowledge.condition_mechanism(condition_id);

CREATE INDEX idx_condition_mechanism_mechanism
   ON knowledge.condition_mechanism(mechanism_id);


-- =============================================================================
-- 8.11 COMPLICATIONS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_complication CASCADE;
CREATE TABLE knowledge.condition_complication (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   complication_concept_id uuid REFERENCES knowledge.concept(id),
   complication_code     text NOT NULL,
   complication_type     text,
   probability_weight    numeric(5,3) NOT NULL DEFAULT 1.0,
   severity_weight       numeric(5,3) NOT NULL DEFAULT 1.0,
   timing                text,
   preventable           boolean,
   description           text,
   UNIQUE (condition_id, complication_code)
);

COMMENT ON TABLE knowledge.condition_complication IS
'Acute, chronic, treatment-related and disease-related complications.';

CREATE INDEX idx_condition_complication_condition
   ON knowledge.condition_complication(condition_id);

CREATE INDEX idx_condition_complication_code
   ON knowledge.condition_complication(complication_code);


-- =============================================================================
-- 8.12 DIFFERENTIAL DIAGNOSIS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_differential CASCADE;
CREATE TABLE knowledge.condition_differential (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   differential_condition_id uuid NOT NULL REFERENCES knowledge.condition(id)
                             ON DELETE CASCADE,
   relationship_type     text NOT NULL DEFAULT 'mimics'
                         CHECK (
                            relationship_type IN (
                               'mimics',
                               'overlaps',
                               'must_rule_out',
                               'dangerous_alternative',
                               'common_alternative',
                               'rare_alternative',
                               'coexists',
                               'competes'
                            )
                         ),
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   urgency               text
                         CHECK (
                            urgency IS NULL OR urgency IN (
                               'routine',
                               'urgent',
                               'emergency'
                            )
                         ),
   distinguishing_features jsonb,
   UNIQUE (
      condition_id,
      differential_condition_id,
      relationship_type
   ),
   CHECK (condition_id <> differential_condition_id)
);

COMMENT ON TABLE knowledge.condition_differential IS
'Structured differential diagnosis graph between conditions.';

CREATE INDEX idx_condition_differential_source
   ON knowledge.condition_differential(condition_id);

CREATE INDEX idx_condition_differential_target
   ON knowledge.condition_differential(differential_condition_id);


-- =============================================================================
-- 8.13 SUBTYPES / VARIANTS
-- =============================================================================

CREATE TABLE knowledge.condition_variant (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   parent_condition_id   uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   child_condition_id    uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   variant_type          text NOT NULL
                         CHECK (
                            variant_type IN (
                               'subtype',
                               'phenotype',
                               'stage',
                               'severity',
                               'etiologic_variant',
                               'anatomic_variant',
                               'clinical_variant',
                               'histologic_variant',
                               'molecular_variant'
                            )
                         ),
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   distinguishing_features jsonb,
   UNIQUE (
      parent_condition_id,
      child_condition_id,
      variant_type
   ),
   CHECK (parent_condition_id <> child_condition_id)
);

COMMENT ON TABLE knowledge.condition_variant IS
'Hierarchical condition variants without duplicating universal knowledge.';


-- =============================================================================
-- 8.14 ANATOMICAL DISTRIBUTION
-- =============================================================================

CREATE TABLE knowledge.condition_anatomy (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   anatomy_concept_id    uuid REFERENCES knowledge.concept(id),
   anatomy_code          text NOT NULL,
   relationship_type     text NOT NULL DEFAULT 'affects'
                         CHECK (
                            relationship_type IN (
                               'affects',
                               'originates_in',
                               'spreads_to',
                               'involves',
                               'drains_to',
                               'obstructs',
                               'invades',
                               'metastasizes_to'
                            )
                         ),
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   laterality            text,
   description           text,
   UNIQUE (
      condition_id,
      anatomy_code,
      relationship_type,
      laterality
   )
);

COMMENT ON TABLE knowledge.condition_anatomy IS
'Anatomical distribution and disease relationships.';


CREATE INDEX idx_condition_anatomy_condition
   ON knowledge.condition_anatomy(condition_id);

CREATE INDEX idx_condition_anatomy_code
   ON knowledge.condition_anatomy(anatomy_code);


-- =============================================================================
-- 8.15 TEMPORAL PATTERNS
-- =============================================================================

CREATE TABLE knowledge.condition_temporal_pattern (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   phase_code             text NOT NULL,
   phase_order            integer NOT NULL DEFAULT 0,
   duration_min_value     numeric,
   duration_max_value     numeric,
   duration_unit          text,
   onset_pattern          text,
   recurrence_pattern     text,
   description            text,
   UNIQUE (condition_id, phase_code)
);

COMMENT ON TABLE knowledge.condition_temporal_pattern IS
'Natural history, onset, phases, recurrence and temporal progression of conditions.';


-- =============================================================================
-- 8.16 SEVERITY / STAGING
-- =============================================================================

CREATE TABLE knowledge.condition_severity_model (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   model_code             text NOT NULL,
   model_name             text NOT NULL,
   description            text,
   version                text,
   is_active              boolean NOT NULL DEFAULT true,
   UNIQUE (condition_id, model_code)
);

COMMENT ON TABLE knowledge.condition_severity_model IS
'Severity, staging, grading and classification systems attached to conditions.';


CREATE TABLE knowledge.condition_severity_level (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   severity_model_id     uuid NOT NULL REFERENCES knowledge.condition_severity_model(id)
                         ON DELETE CASCADE,
   level_code             text NOT NULL,
   level_name             text NOT NULL,
   ordinal                integer NOT NULL,
   criteria               jsonb NOT NULL,
   clinical_meaning      text,
   urgency               text,
   UNIQUE (severity_model_id, level_code),
   UNIQUE (severity_model_id, ordinal)
);

COMMENT ON TABLE knowledge.condition_severity_level IS
'Machine-readable severity/stage definitions.';

CREATE INDEX idx_condition_severity_level_model
   ON knowledge.condition_severity_level(severity_model_id);


-- =============================================================================
-- 8.17 PROGNOSIS / OUTCOMES
-- =============================================================================

CREATE TABLE knowledge.condition_outcome (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   outcome_code           text NOT NULL,
   outcome_type           text NOT NULL
                         CHECK (
                            outcome_type IN (
                               'recovery',
                               'remission',
                               'recurrence',
                               'relapse',
                               'chronicity',
                               'disability',
                               'complication',
                               'death',
                               'cure',
                               'progression'
                            )
                         ),
   probability_weight    numeric(5,3),
   time_horizon          text,
   prognostic_modifier   jsonb,
   description           text,
   UNIQUE (condition_id, outcome_code)
);

COMMENT ON TABLE knowledge.condition_outcome IS
'Natural history and prognostic outcomes.';


CREATE TABLE knowledge.condition_prognostic_factor (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   concept_id            uuid REFERENCES knowledge.concept(id),
   factor_code            text NOT NULL,
   direction              text NOT NULL
                         CHECK (direction IN ('favorable','unfavorable')),
   weight                 numeric(5,3) NOT NULL DEFAULT 1.0,
   description             text,
   UNIQUE (condition_id, factor_code)
);

COMMENT ON TABLE knowledge.condition_prognostic_factor IS
'Factors modifying prognosis.';


-- =============================================================================
-- 8.18 TRANSMISSION / EPIDEMIOLOGY
-- =============================================================================

CREATE TABLE knowledge.condition_transmission (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   transmission_code     text NOT NULL,
   route                  text,
   infectious_period      text,
   incubation_period     text,
   contagiousness        numeric(5,3),
   prevention             jsonb,
   description           text,
   UNIQUE (condition_id, transmission_code)
);

COMMENT ON TABLE knowledge.condition_transmission IS
'Transmission and epidemiological behaviour where applicable.';


CREATE TABLE knowledge.condition_epidemiology (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   context_type_code     text REFERENCES knowledge.context_type(code),
   context_value_id      uuid REFERENCES knowledge.context_value(id),
   measure_type          text NOT NULL,
   value                 numeric,
   unit                   text,
   denominator            text,
   period_start          date,
   period_end            date,
   source                 text,
   metadata               jsonb
);

COMMENT ON TABLE knowledge.condition_epidemiology IS
'Epidemiological measurements contextualized by population and geography.';


-- =============================================================================
-- 8.19 INVESTIGATION RELATIONSHIPS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.condition_investigation CASCADE;
CREATE TABLE knowledge.condition_investigation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   investigation_concept_id uuid REFERENCES knowledge.concept(id),
   investigation_code    text NOT NULL,
   investigation_role    text NOT NULL
                         CHECK (
                            investigation_role IN (
                               'screening',
                               'diagnostic',
                               'confirmatory',
                               'rule_out',
                               'severity',
                               'staging',
                               'monitoring',
                               'prognostic',
                               'preoperative',
                               'follow_up'
                            )
                         ),
   priority              integer NOT NULL DEFAULT 50,
   expected_finding      jsonb,
   sensitivity           numeric(6,5),
   specificity           numeric(6,5),
   rationale              text,
   context                jsonb,
   UNIQUE (
      condition_id,
      investigation_code,
      investigation_role
   )
);

COMMENT ON TABLE knowledge.condition_investigation IS
'Investigations linked to a condition with role, expected findings and diagnostic characteristics.';

CREATE INDEX idx_condition_investigation_condition
   ON knowledge.condition_investigation(condition_id);

CREATE INDEX idx_condition_investigation_code
   ON knowledge.condition_investigation(investigation_code);


-- =============================================================================
-- 8.20 INVESTIGATION FINDINGS
-- =============================================================================

CREATE TABLE knowledge.condition_investigation_finding (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_investigation_id uuid NOT NULL
                             REFERENCES knowledge.condition_investigation(id)
                             ON DELETE CASCADE,
   finding_type           text NOT NULL,
   finding_code           text NOT NULL,
   operator               text NOT NULL DEFAULT 'eq',
   expected_value         jsonb,
   likelihood_weight      numeric(5,3) NOT NULL DEFAULT 1.0,
   polarity               text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),
   description            text
);

COMMENT ON TABLE knowledge.condition_investigation_finding IS
'Expected investigation findings and their diagnostic contribution.';


-- =============================================================================
-- 8.21 MANAGEMENT PRINCIPLES
-- =============================================================================

CREATE TABLE knowledge.condition_management (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   management_code       text NOT NULL,
   management_type       text NOT NULL
                         CHECK (
                            management_type IN (
                               'supportive',
                               'pharmacologic',
                               'procedural',
                               'surgical',
                               'behavioral',
                               'nutritional',
                               'rehabilitation',
                               'preventive',
                               'monitoring',
                               'referral',
                               'emergency',
                               'definitive',
                               'palliative',
                               'follow_up'
                            )
                         ),
   priority              integer NOT NULL DEFAULT 50,
   indication             jsonb,
   contraindication       jsonb,
   context                jsonb,
   rationale              text,
   UNIQUE (condition_id, management_code, management_type)
);

COMMENT ON TABLE knowledge.condition_management IS
'Condition-level management options and their contextual indications.';


CREATE INDEX idx_condition_management_condition
   ON knowledge.condition_management(condition_id);


-- =============================================================================
-- 8.22 MANAGEMENT ACTIONS
-- =============================================================================

CREATE TABLE knowledge.management_action (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   management_code       text NOT NULL UNIQUE,
   concept_id            uuid REFERENCES knowledge.concept(id),
   action_name            text NOT NULL,
   action_type            text NOT NULL,
   description            text,
   status                 text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated'))
);

COMMENT ON TABLE knowledge.management_action IS
'Universal management vocabulary shared across conditions.';


CREATE TABLE knowledge.condition_management_action (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   management_action_id  uuid NOT NULL REFERENCES knowledge.management_action(id),
   indication             jsonb,
   contraindication       jsonb,
   priority               integer NOT NULL DEFAULT 50,
   context                jsonb,
   rationale              text,
   UNIQUE (condition_id, management_action_id)
);

COMMENT ON TABLE knowledge.condition_management_action IS
'Connects universal management actions to conditions without disease-specific engines.';


-- =============================================================================
-- 8.23 TREATMENT GOALS
-- =============================================================================

CREATE TABLE knowledge.condition_treatment_goal (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   goal_code             text NOT NULL,
   goal_type              text NOT NULL
                         CHECK (
                            goal_type IN (
                               'curative',
                               'disease_modifying',
                               'symptom_control',
                               'preventive',
                               'supportive',
                               'rehabilitative',
                               'palliative',
                               'life_saving'
                            )
                         ),
   priority              integer NOT NULL DEFAULT 50,
   criteria               jsonb,
   description            text,
   UNIQUE (condition_id, goal_code)
);

COMMENT ON TABLE knowledge.condition_treatment_goal IS
'Therapeutic intent and measurable goals for a condition.';


-- =============================================================================
-- 8.24 CONTRAINDICATIONS / HARM
-- =============================================================================

CREATE TABLE knowledge.condition_contraindication (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   action_code            text NOT NULL,
   contraindication_type  text NOT NULL
                         CHECK (
                            contraindication_type IN (
                               'absolute',
                               'relative',
                               'avoid',
                               'caution'
                            )
                         ),
   context                jsonb,
   rationale              text,
   evidence_level         text,
   UNIQUE (condition_id, action_code, contraindication_type)
);

COMMENT ON TABLE knowledge.condition_contraindication IS
'Condition-specific safety restrictions for interventions.';


-- =============================================================================
-- 8.25 RED FLAGS / EMERGENCY FEATURES
-- =============================================================================

CREATE TABLE knowledge.condition_red_flag (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   red_flag_code         text NOT NULL,
   trigger_type           text NOT NULL,
   trigger_code           text NOT NULL,
   severity               text NOT NULL
                         CHECK (
                            severity IN (
                               'warning',
                               'urgent',
                               'emergency',
                               'life_threatening'
                            )
                         ),
   action_code            text,
   action_params          jsonb,
   description            text,
   UNIQUE (condition_id, red_flag_code)
);

COMMENT ON TABLE knowledge.condition_red_flag IS
'Immediate danger signals and actions associated with a condition.';

CREATE INDEX idx_condition_red_flag_condition
   ON knowledge.condition_red_flag(condition_id);

CREATE INDEX idx_condition_red_flag_trigger
   ON knowledge.condition_red_flag(trigger_type, trigger_code);


-- =============================================================================
-- 8.26 PREVENTION
-- =============================================================================

CREATE TABLE knowledge.condition_prevention (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   prevention_code       text NOT NULL,
   prevention_type       text NOT NULL
                         CHECK (
                            prevention_type IN (
                               'primary',
                               'secondary',
                               'tertiary',
                               'vaccination',
                               'screening',
                               'exposure_reduction',
                               'lifestyle',
                               'chemoprevention',
                               'prophylaxis'
                            )
                         ),
   action_code            text,
   target_population      jsonb,
   priority               integer NOT NULL DEFAULT 50,
   description            text,
   UNIQUE (condition_id, prevention_code)
);

COMMENT ON TABLE knowledge.condition_prevention IS
'Primary, secondary and tertiary prevention knowledge.';


-- =============================================================================
-- 8.27 FOLLOW-UP / MONITORING
-- =============================================================================

CREATE TABLE knowledge.condition_follow_up (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   follow_up_code        text NOT NULL,
   trigger_code           text,
   interval_value        numeric,
   interval_unit         text,
   monitoring_targets    jsonb,
   escalation_criteria   jsonb,
   discharge_criteria    jsonb,
   description           text,
   UNIQUE (condition_id, follow_up_code)
);

COMMENT ON TABLE knowledge.condition_follow_up IS
'Monitoring, reassessment, escalation and discharge knowledge.';


-- =============================================================================
-- 8.28 REFERRAL / ESCALATION
-- =============================================================================

CREATE TABLE knowledge.condition_referral (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   referral_type         text NOT NULL,
   specialty_code        text REFERENCES organization.specialty(code),
   urgency               text NOT NULL DEFAULT 'routine'
                         CHECK (
                            urgency IN (
                               'routine',
                               'soon',
                               'urgent',
                               'emergency'
                            )
                         ),
   trigger               jsonb,
   destination_type      text,
   rationale             text,
   UNIQUE (
      condition_id,
      referral_type,
      specialty_code,
      urgency
   )
);

COMMENT ON TABLE knowledge.condition_referral IS
'Referral and escalation pathways.';


-- =============================================================================
-- 8.29 PATIENT EDUCATION
-- =============================================================================

CREATE TABLE knowledge.condition_education (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   education_code        text NOT NULL,
   audience              text NOT NULL DEFAULT 'patient',
   language_code         text,
   topic                 text NOT NULL,
   content               text NOT NULL,
   literacy_level        text,
   format                text DEFAULT 'text',
   UNIQUE (
      condition_id,
      education_code,
      audience,
      language_code
   )
);

COMMENT ON TABLE knowledge.condition_education IS
'Patient, caregiver and professional education associated with a condition.';


-- =============================================================================
-- 8.30 DOCUMENTATION
-- =============================================================================

CREATE TABLE knowledge.condition_documentation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   documentation_type    text NOT NULL,
   phrase                 text NOT NULL,
   language_code          text,
   context_code           text,
   is_preferred           boolean NOT NULL DEFAULT false,
   UNIQUE (
      condition_id,
      documentation_type,
      phrase,
      language_code
   )
);

COMMENT ON TABLE knowledge.condition_documentation IS
'Canonical documentation language for clinical notes and summaries.';


-- =============================================================================
-- 8.31 KNOWLEDGE EVIDENCE
-- =============================================================================

CREATE TABLE knowledge.condition_source (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   source_type           text NOT NULL,
   source_ref            text,
   citation              text,
   url                   text,
   evidence_level       text,
   guideline_version     text,
   publication_date      date,
   accessed_at           timestamptz,
   notes                 text,
   UNIQUE (condition_id, source_type, source_ref)
);

COMMENT ON TABLE knowledge.condition_source IS
'Provenance and evidence sources for condition knowledge.';


-- =============================================================================
-- 9. CROSS-LAYER MECHANISM RELATIONSHIPS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.mechanism_phenotype CASCADE;
CREATE TABLE knowledge.mechanism_phenotype (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,
   phenotype_id          uuid NOT NULL REFERENCES knowledge.phenotype(id)
                         ON DELETE CASCADE,
   relationship_type     text NOT NULL DEFAULT 'produces',
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),
   context               jsonb,
   UNIQUE (
      mechanism_id,
      phenotype_id,
      relationship_type,
      polarity
   )
);

COMMENT ON TABLE knowledge.mechanism_phenotype IS
'Mechanism-to-phenotype causal relationships.';


CREATE TABLE knowledge.mechanism_condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   relationship_type     text NOT NULL DEFAULT 'underlies',
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   context               jsonb,
   UNIQUE (
      mechanism_id,
      condition_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.mechanism_condition IS
'Mechanism-to-condition relationships.';


CREATE TABLE knowledge.mechanism_investigation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,
   investigation_concept_id uuid REFERENCES knowledge.concept(id),
   investigation_code    text NOT NULL,
   relationship_type     text NOT NULL DEFAULT 'evaluates',
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   rationale             text,
   UNIQUE (
      mechanism_id,
      investigation_code,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.mechanism_investigation IS
'Investigations that evaluate a pathophysiological mechanism.';


CREATE TABLE knowledge.mechanism_management (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,
   management_concept_id uuid REFERENCES knowledge.concept(id),
   management_code       text NOT NULL,
   relationship_type     text NOT NULL DEFAULT 'targets',
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   rationale             text,
   UNIQUE (
      mechanism_id,
      management_code,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.mechanism_management IS
'Management actions targeting mechanisms.';


-- =============================================================================
-- 10. PHENOTYPE CROSS-LAYER RELATIONSHIPS
-- =============================================================================

CREATE TABLE knowledge.phenotype_differential (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id          uuid NOT NULL REFERENCES knowledge.phenotype(id)
                         ON DELETE CASCADE,
   condition_id          uuid NOT NULL REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,
   relationship_type     text NOT NULL DEFAULT 'suggestive_of',
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),
   context               jsonb,
   UNIQUE (
      phenotype_id,
      condition_id,
      relationship_type,
      polarity
   )
);

COMMENT ON TABLE knowledge.phenotype_differential IS
'Phenotype-to-condition diagnostic relationships.';


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.phenotype_mechanism CASCADE;
CREATE TABLE knowledge.phenotype_mechanism (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   phenotype_id          uuid NOT NULL REFERENCES knowledge.phenotype(id)
                         ON DELETE CASCADE,
   mechanism_id          uuid NOT NULL REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,
   relationship_type     text NOT NULL DEFAULT 'reflects',
   weight                numeric(5,3) NOT NULL DEFAULT 1.0,
   context               jsonb,
   UNIQUE (
      phenotype_id,
      mechanism_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.phenotype_mechanism IS
'Phenotype-to-mechanism relationships.';


-- =============================================================================
-- 11. KNOWLEDGE GRAPH â€” UNIVERSAL RELATIONAL SKELETON
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.relationship CASCADE;
CREATE TABLE knowledge.relationship (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_type           text NOT NULL,
   source_id             uuid NOT NULL,

   relationship_type     text NOT NULL,

   target_type           text NOT NULL,
   target_id             uuid NOT NULL,

   weight                numeric(6,3) NOT NULL DEFAULT 1.0,

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),

   confidence            numeric(5,4)
                         CHECK (confidence >= 0 AND confidence <= 1),

   context               jsonb,

   evidence              text,
   source_ref            text,
   guideline             text,
   guideline_version     text,

   valid_from            timestamptz,
   valid_to              timestamptz,

   version               text,
   is_active             boolean NOT NULL DEFAULT true,

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now(),

   CHECK (source_type <> ''),
   CHECK (target_type <> ''),
   CHECK (relationship_type <> '')
);

COMMENT ON TABLE knowledge.relationship IS
'Universal typed clinical knowledge graph connecting every knowledge primitive without disease-specific schemas.';


CREATE INDEX idx_knowledge_relationship_source
   ON knowledge.relationship(source_type, source_id);

CREATE INDEX idx_knowledge_relationship_target
   ON knowledge.relationship(target_type, target_id);

CREATE INDEX idx_knowledge_relationship_type
   ON knowledge.relationship(relationship_type);

CREATE INDEX idx_knowledge_relationship_source_type
   ON knowledge.relationship(source_type, relationship_type);

CREATE INDEX idx_knowledge_relationship_target_type
   ON knowledge.relationship(target_type, relationship_type);

CREATE INDEX idx_knowledge_relationship_active
   ON knowledge.relationship(is_active);

CREATE INDEX idx_knowledge_relationship_context
   ON knowledge.relationship
   USING gin(context);

CREATE TRIGGER trg_knowledge_relationship_updated_at
   BEFORE UPDATE ON knowledge.relationship
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 11.1 GRAPH EDGE EVIDENCE
-- =============================================================================

CREATE TABLE knowledge.relationship_source (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   relationship_id       uuid NOT NULL REFERENCES knowledge.relationship(id)
                         ON DELETE CASCADE,
   source_type           text NOT NULL,
   source_ref            text,
   citation              text,
   url                   text,
   evidence_level        text,
   guideline             text,
   guideline_version     text,
   publication_date      date,
   notes                 text
);

COMMENT ON TABLE knowledge.relationship_source IS
'Evidence and provenance attached to individual knowledge-graph edges.';


CREATE INDEX idx_relationship_source_relationship
   ON knowledge.relationship_source(relationship_id);


-- =============================================================================
-- 11.2 GRAPH EDGE CONDITIONS
-- =============================================================================

CREATE TABLE knowledge.relationship_condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   relationship_id       uuid NOT NULL REFERENCES knowledge.relationship(id)
                         ON DELETE CASCADE,
   condition_type_code   text NOT NULL,
   condition_value       jsonb NOT NULL,
   operator              text NOT NULL DEFAULT 'eq',
   priority              integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE knowledge.relationship_condition IS
'Contextual activation criteria for graph edges.';


CREATE INDEX idx_relationship_condition_relationship
   ON knowledge.relationship_condition(relationship_id);


-- =============================================================================
-- 11.3 GRAPH PATH / INFERENCE DEFINITIONS
-- =============================================================================

CREATE TABLE knowledge.inference_pattern (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   inference_code        text NOT NULL UNIQUE,
   name                  text NOT NULL,
   description           text,
   pattern_type          text NOT NULL
                         CHECK (
                            pattern_type IN (
                               'causal',
                               'diagnostic',
                               'differential',
                               'temporal',
                               'risk',
                               'safety',
                               'management',
                               'prognostic',
                               'screening',
                               'referral'
                            )
                         ),
   expression            jsonb NOT NULL,
   priority              integer NOT NULL DEFAULT 50,
   confidence_threshold  numeric(5,4)
                         CHECK (
                            confidence_threshold IS NULL OR
                            confidence_threshold BETWEEN 0 AND 1
                         ),
   is_active             boolean NOT NULL DEFAULT true,
   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.inference_pattern IS
'Reusable graph traversal and inference patterns used by the AMEXAN clinical CPU.';

CREATE TRIGGER trg_knowledge_inference_pattern_updated_at
   BEFORE UPDATE ON knowledge.inference_pattern
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 11.4 KNOWLEDGE ASSERTION
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.assertion CASCADE;
CREATE TABLE knowledge.assertion (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   subject_type          text NOT NULL,
   subject_id            uuid NOT NULL,

   predicate             text NOT NULL,

   object_type           text,
   object_id             uuid,

   value                 jsonb,

   certainty              text NOT NULL DEFAULT 'known'
                         CHECK (
                            certainty IN (
                               'known',
                               'probable',
                               'possible',
                               'uncertain',
                               'unknown',
                               'excluded'
                            )
                         ),

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),

   source                 text,
   recorded_at            timestamptz NOT NULL DEFAULT now(),

   valid_from             timestamptz,
   valid_to               timestamptz,

   context                jsonb,

   CHECK (
      object_id IS NOT NULL
      OR value IS NOT NULL
   )
);

COMMENT ON TABLE knowledge.assertion IS
'Universal clinical assertion substrate representing facts about any knowledge node.';

CREATE INDEX IF NOT EXISTS idx_knowledge_assertion_subject2
   ON knowledge.assertion(subject_type, subject_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_assertion_predicate2
   ON knowledge.assertion(predicate);

CREATE INDEX IF NOT EXISTS idx_knowledge_assertion_object2
   ON knowledge.assertion(object_type, object_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_assertion_context
   ON knowledge.assertion USING gin(context);


-- =============================================================================
-- 11.5 KNOWLEDGE VERSION / RELEASE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.knowledge_release CASCADE;
CREATE TABLE knowledge.knowledge_release (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   release_code          text NOT NULL UNIQUE,
   version               text NOT NULL UNIQUE,
   name                  text NOT NULL,
   description           text,
   status                text NOT NULL DEFAULT 'draft'
                         CHECK (
                            status IN (
                               'draft',
                               'validated',
                               'approved',
                               'released',
                               'retired'
                            )
                         ),
   effective_from        timestamptz,
   effective_to          timestamptz,
   created_at            timestamptz NOT NULL DEFAULT now(),
   released_at           timestamptz
);

COMMENT ON TABLE knowledge.knowledge_release IS
'Versioned release boundary for clinical knowledge.';


CREATE TABLE knowledge.knowledge_release_item (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   release_id            uuid NOT NULL REFERENCES knowledge.knowledge_release(id)
                         ON DELETE CASCADE,
   entity_type           text NOT NULL,
   entity_id             uuid NOT NULL,
   entity_version        text,
   change_type            text NOT NULL
                         CHECK (
                            change_type IN (
                               'add',
                               'update',
                               'deprecate',
                               'restore'
                            )
                         ),
   UNIQUE (
      release_id,
      entity_type,
      entity_id,
      change_type
   )
);

COMMENT ON TABLE knowledge.knowledge_release_item IS
'Knowledge entities included in a controlled clinical knowledge release.';

CREATE INDEX idx_knowledge_release_item_entity
   ON knowledge.knowledge_release_item(entity_type, entity_id);


-- =============================================================================
-- 12. HIGH-SPEED CLINICAL LOOKUP INDEXES
-- =============================================================================

CREATE INDEX idx_condition_context_fast
   ON knowledge.condition_context(
      context_type_code,
      context_value_id,
      condition_id
   );

CREATE INDEX idx_condition_system_fast
   ON knowledge.condition_system(
      body_system_code,
      condition_id
   );

CREATE INDEX idx_condition_specialty_fast
   ON knowledge.condition_specialty(
      specialty_code,
      condition_id
   );

CREATE INDEX idx_condition_symptom_fast
   ON knowledge.condition_symptom(
      symptom_id,
      condition_id
   );

CREATE INDEX idx_condition_phenotype_fast
   ON knowledge.condition_phenotype(
      phenotype_id,
      condition_id
   );

CREATE INDEX idx_condition_mechanism_fast
   ON knowledge.condition_mechanism(
      mechanism_id,
      condition_id
   );

CREATE INDEX idx_condition_risk_fast
   ON knowledge.condition_risk_factor(
      risk_factor_code,
      condition_id
   );

CREATE INDEX idx_condition_red_flag_fast
   ON knowledge.condition_red_flag(
      trigger_type,
      trigger_code,
      condition_id
   );

CREATE INDEX idx_condition_investigation_fast
   ON knowledge.condition_investigation(
      investigation_code,
      condition_id
   );

CREATE INDEX idx_condition_management_fast
   ON knowledge.condition_management(
      management_code,
      condition_id
   );


-- =============================================================================
-- 13. UNIVERSAL KNOWLEDGE INTEGRITY
-- =============================================================================

ALTER TABLE knowledge.condition_context
   ADD CONSTRAINT chk_condition_context_modifier
   CHECK (
      likelihood_modifier IS NULL
      OR likelihood_modifier >= 0
   );

ALTER TABLE knowledge.condition_system
   ADD CONSTRAINT chk_condition_system_weight
   CHECK (weight >= 0);

ALTER TABLE knowledge.condition_specialty
   ADD CONSTRAINT chk_condition_specialty_weight
   CHECK (weight >= 0);

ALTER TABLE knowledge.condition_etiology
   ADD CONSTRAINT chk_condition_etiology_weight
   CHECK (weight >= 0);

ALTER TABLE knowledge.condition_risk_factor
   ADD CONSTRAINT chk_condition_risk_weight
   CHECK (weight >= 0);

ALTER TABLE knowledge.condition_phenotype
   ADD CONSTRAINT chk_condition_phenotype_weight
   CHECK (weight >= 0);

ALTER TABLE knowledge.condition_mechanism
   ADD CONSTRAINT chk_condition_mechanism_weight
   CHECK (weight >= 0);

ALTER TABLE knowledge.condition_symptom
   ADD CONSTRAINT chk_condition_symptom_weight
   CHECK (
      likelihood_weight >= 0
      AND diagnostic_weight >= 0
   );


-- =============================================================================
-- 14. UNIVERSAL KNOWLEDGE SEARCH
-- =============================================================================

CREATE INDEX idx_knowledge_condition_name_fts
   ON knowledge.condition
   USING gin (
      to_tsvector(
         'simple',
         coalesce(canonical_name,'') || ' ' ||
         coalesce(display_name,'') || ' ' ||
         coalesce(description,'')
      )
   );

CREATE INDEX idx_knowledge_symptom_name_fts
   ON knowledge.symptom
   USING gin (
      to_tsvector(
         'simple',
         coalesce(canonical_name,'') || ' ' ||
         coalesce(definition,'')
      )
   );

CREATE INDEX idx_knowledge_concept_name_fts
   ON knowledge.concept
   USING gin (
      to_tsvector(
         'simple',
         coalesce(canonical_name,'') || ' ' ||
         coalesce(display_name,'') || ' ' ||
         coalesce(description,'')
      )
   );


-- =============================================================================
-- 15. UNIVERSAL KNOWLEDGE GRAPH RELATIONSHIP VOCABULARY
-- =============================================================================

CREATE TABLE knowledge.relationship_type (
   code                  text PRIMARY KEY,
   label                 text NOT NULL,
   description           text,
   inverse_code          text,
   category              text NOT NULL
                         CHECK (
                            category IN (
                               'causal',
                               'diagnostic',
                               'clinical',
                               'temporal',
                               'contextual',
                               'management',
                               'safety',
                               'semantic',
                               'structural',
                               'epidemiologic',
                               'prognostic'
                            )
                         ),
   is_symmetric           boolean NOT NULL DEFAULT false,
   is_active              boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE knowledge.relationship_type IS
'Controlled vocabulary for universal clinical knowledge graph edges.';


-- =============================================================================
-- 16. GRAPH QUERY SUPPORT
-- =============================================================================

CREATE INDEX idx_knowledge_relationship_active_source
   ON knowledge.relationship(
      is_active,
      source_type,
      source_id,
      relationship_type
   );

CREATE INDEX idx_knowledge_relationship_active_target
   ON knowledge.relationship(
      is_active,
      target_type,
      target_id,
      relationship_type
   );

CREATE INDEX idx_knowledge_assertion_active_context
   ON knowledge.assertion(
      subject_type,
      subject_id,
      certainty,
      polarity
   );


-- =============================================================================
-- 17. KNOWLEDGE AUDIT / VALIDATION STATE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.validation CASCADE;
CREATE TABLE knowledge.validation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   entity_type            text NOT NULL,
   entity_id              uuid NOT NULL,
   validation_type        text NOT NULL,
   status                 text NOT NULL DEFAULT 'pending'
                         CHECK (
                            status IN (
                               'pending',
                               'passed',
                               'failed',
                               'waived'
                            )
                         ),
   validator              text,
   validated_at            timestamptz,
   findings               jsonb,
   notes                  text
);

COMMENT ON TABLE knowledge.validation IS
'Validation state for clinical knowledge entities before controlled release.';

CREATE INDEX idx_knowledge_validation_entity
   ON knowledge.validation(entity_type, entity_id);

CREATE INDEX idx_knowledge_validation_status
   ON knowledge.validation(status);


-- =============================================================================
-- 18. CLINICAL KNOWLEDGE IMPORT BATCH
-- =============================================================================

CREATE TABLE knowledge.import_batch (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   batch_code             text NOT NULL UNIQUE,
   source_name            text NOT NULL,
   source_version         text,
   source_type             text,
   imported_at             timestamptz NOT NULL DEFAULT now(),
   imported_by             uuid REFERENCES identity.user_account(id),
   status                  text NOT NULL DEFAULT 'pending'
                         CHECK (
                            status IN (
                               'pending',
                               'processing',
                               'validated',
                               'committed',
                               'failed',
                               'rolled_back'
                            )
                         ),
   record_count            integer,
   error_count             integer NOT NULL DEFAULT 0,
   metadata                jsonb
);

COMMENT ON TABLE knowledge.import_batch IS
'Controlled ingestion boundary for medical textbooks, guidelines, terminologies and validated clinical knowledge.';


CREATE TABLE knowledge.import_record (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   batch_id               uuid NOT NULL REFERENCES knowledge.import_batch(id)
                         ON DELETE CASCADE,
   entity_type            text NOT NULL,
   source_key              text,
   target_id               uuid,
   action                  text NOT NULL,
   status                  text NOT NULL DEFAULT 'pending'
                         CHECK (
                            status IN (
                               'pending',
                               'accepted',
                               'rejected',
                               'conflict'
                            )
                         ),
   source_payload          jsonb,
   validation_errors        jsonb
);

COMMENT ON TABLE knowledge.import_record IS
'Individual knowledge records processed through an import batch.';

CREATE INDEX idx_knowledge_import_record_batch
   ON knowledge.import_record(batch_id);

CREATE INDEX idx_knowledge_import_record_target
   ON knowledge.import_record(target_id);


-- =============================================================================
-- 19. CLINICAL KNOWLEDGE CONFLICTS
-- =============================================================================

CREATE TABLE knowledge.conflict (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   entity_type            text NOT NULL,
   entity_id              uuid NOT NULL,
   conflict_type          text NOT NULL,
   source_a               text,
   source_b               text,
   statement_a            jsonb,
   statement_b            jsonb,
   severity               text NOT NULL DEFAULT 'warning'
                         CHECK (
                            severity IN (
                               'info',
                               'warning',
                               'high',
                               'critical'
                            )
                         ),
   resolution_status      text NOT NULL DEFAULT 'open'
                         CHECK (
                            resolution_status IN (
                               'open',
                               'under_review',
                               'resolved',
                               'accepted'
                            )
                         ),
   resolution             jsonb,
   resolved_by            text,
   resolved_at            timestamptz,
   created_at             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.conflict IS
'Conflicting clinical knowledge statements requiring explicit resolution rather than silent overwriting.';

CREATE INDEX idx_knowledge_conflict_entity
   ON knowledge.conflict(entity_type, entity_id);

CREATE INDEX idx_knowledge_conflict_status
   ON knowledge.conflict(resolution_status);


-- =============================================================================
-- 20. CLINICAL KNOWLEDGE PROVENANCE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.provenance CASCADE;
CREATE TABLE knowledge.provenance (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   entity_type            text NOT NULL,
   entity_id              uuid NOT NULL,
   source_type            text NOT NULL,
   source_identifier      text,
   citation               text,
   url                    text,
   evidence_level         text,
   author                  text,
   reviewer                text,
   publication_date       date,
   effective_from         date,
   effective_to           date,
   extracted_at           timestamptz,
   notes                  text,
   metadata               jsonb
);

COMMENT ON TABLE knowledge.provenance IS
'Universal provenance layer for every clinical knowledge object.';

CREATE INDEX idx_knowledge_provenance_entity
   ON knowledge.provenance(entity_type, entity_id);

CREATE INDEX idx_knowledge_provenance_source
   ON knowledge.provenance(source_type, source_identifier);


-- =============================================================================
-- 21. CLINICAL KNOWLEDGE STATUS
-- =============================================================================

CREATE TABLE knowledge.entity_status (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   entity_type            text NOT NULL,
   entity_id              uuid NOT NULL,
   status                 text NOT NULL
                         CHECK (
                            status IN (
                               'draft',
                               'review',
                               'validated',
                               'approved',
                               'active',
                               'deprecated',
                               'retired'
                            )
                         ),
   effective_from         timestamptz,
   effective_to           timestamptz,
   changed_at             timestamptz NOT NULL DEFAULT now(),
   changed_by             uuid REFERENCES identity.user_account(id),
   reason                 text
);

COMMENT ON TABLE knowledge.entity_status IS
'Lifecycle state of universal clinical knowledge entities.';

CREATE INDEX idx_knowledge_entity_status
   ON knowledge.entity_status(entity_type, entity_id, status);


-- =============================================================================
-- 22. KNOWLEDGE GRAPH MATERIALIZATION SUPPORT
-- =============================================================================

CREATE TABLE knowledge.graph_node (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   node_type              text NOT NULL,
   entity_id              uuid NOT NULL,
   canonical_key          text NOT NULL,
   label                  text,
   search_text            text,
   status                 text NOT NULL DEFAULT 'active',
   metadata               jsonb,
   created_at             timestamptz NOT NULL DEFAULT now(),
   updated_at             timestamptz NOT NULL DEFAULT now(),
   UNIQUE (node_type, entity_id),
   UNIQUE (canonical_key)
);

COMMENT ON TABLE knowledge.graph_node IS
'Optional materialized node index for high-speed graph traversal and search.';

CREATE INDEX idx_knowledge_graph_node_type
   ON knowledge.graph_node(node_type);

CREATE INDEX idx_knowledge_graph_node_search
   ON knowledge.graph_node
   USING gin (
      to_tsvector('simple', coalesce(search_text,''))
   );

CREATE TRIGGER trg_knowledge_graph_node_updated_at
   BEFORE UPDATE ON knowledge.graph_node
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE knowledge.graph_edge (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   source_node_id        uuid NOT NULL REFERENCES knowledge.graph_node(id)
                         ON DELETE CASCADE,
   target_node_id        uuid NOT NULL REFERENCES knowledge.graph_node(id)
                         ON DELETE CASCADE,
   relationship_id       uuid REFERENCES knowledge.relationship(id)
                         ON DELETE CASCADE,
   relationship_type     text NOT NULL,
   weight                numeric(6,3) NOT NULL DEFAULT 1.0,
   confidence             numeric(5,4),
   polarity               text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),
   is_active              boolean NOT NULL DEFAULT true,
   metadata               jsonb,
   UNIQUE (
      source_node_id,
      target_node_id,
      relationship_type,
      polarity
   )
);

COMMENT ON TABLE knowledge.graph_edge IS
'Materialized high-speed representation of universal clinical graph relationships.';

CREATE INDEX idx_knowledge_graph_edge_source
   ON knowledge.graph_edge(source_node_id, relationship_type);

CREATE INDEX idx_knowledge_graph_edge_target
   ON knowledge.graph_edge(target_node_id, relationship_type);

CREATE INDEX idx_knowledge_graph_edge_relationship
   ON knowledge.graph_edge(relationship_id);


-- =============================================================================
-- 23. UNIVERSAL CLINICAL KNOWLEDGE VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.condition_knowledge_index AS
SELECT
   c.id,
   c.condition_code,
   c.canonical_name,
   c.display_name,
   c.condition_type,
   c.clinical_course,
   c.etiologic_class,
   c.status,
   COALESCE(s.symptom_count, 0)       AS symptom_count,
   COALESCE(p.phenotype_count, 0)     AS phenotype_count,
   COALESCE(m.mechanism_count, 0)     AS mechanism_count,
   COALESCE(r.risk_count, 0)          AS risk_factor_count,
   COALESCE(cf.complication_count, 0) AS complication_count,
   COALESCE(df.differential_count, 0) AS differential_count,
   COALESCE(iv.investigation_count,0) AS investigation_count,
   COALESCE(ma.management_count, 0)   AS management_count
FROM knowledge.condition c

LEFT JOIN (
   SELECT condition_id, count(*) AS symptom_count
   FROM knowledge.condition_symptom
   GROUP BY condition_id
) s ON s.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS phenotype_count
   FROM knowledge.condition_phenotype
   GROUP BY condition_id
) p ON p.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS mechanism_count
   FROM knowledge.condition_mechanism
   GROUP BY condition_id
) m ON m.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS risk_count
   FROM knowledge.condition_risk_factor
   GROUP BY condition_id
) r ON r.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS complication_count
   FROM knowledge.condition_complication
   GROUP BY condition_id
) cf ON cf.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS differential_count
   FROM knowledge.condition_differential
   GROUP BY condition_id
) df ON df.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS investigation_count
   FROM knowledge.condition_investigation
   GROUP BY condition_id
) iv ON iv.condition_id = c.id

LEFT JOIN (
   SELECT condition_id, count(*) AS management_count
   FROM knowledge.condition_management
   GROUP BY condition_id
) ma ON ma.condition_id = c.id;


-- =============================================================================
-- 24. UNIVERSAL CLINICAL SEARCH VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.clinical_knowledge_search AS

SELECT
   'condition'::text AS entity_type,
   c.id AS entity_id,
   c.condition_code AS code,
   c.canonical_name AS name,
   c.description,
   c.status
FROM knowledge.condition c

UNION ALL

SELECT
   'symptom'::text,
   s.id,
   s.symptom_code,
   s.canonical_name,
   s.definition,
   s.status
FROM knowledge.symptom s

UNION ALL

SELECT
   'phenotype'::text,
   p.id,
   p.phenotype_code,
   p.canonical_name,
   p.description,
   p.status
FROM knowledge.phenotype p

UNION ALL

SELECT
   'mechanism'::text,
   m.id,
   m.mechanism_code,
   m.canonical_name,
   m.description,
   m.status
FROM knowledge.mechanism m

UNION ALL

SELECT
   'concept'::text,
   c.id,
   c.concept_code,
   c.canonical_name,
   c.description,
   c.status
FROM knowledge.concept c;


-- =============================================================================
-- 25. UNIVERSAL CLINICAL KNOWLEDGE COUNTS
-- =============================================================================
-- Note: the investigation registry is owned by migration 012/014, so the
-- inventory view is defined below without the investigation count. Recreate
-- the inventory view after the investigation substrate exists if desired.

-- =============================================================================
-- 26. SAFE OPTIONAL PLACEHOLDER REGISTRATION
-- =============================================================================

DROP VIEW IF EXISTS knowledge.knowledge_inventory;

CREATE OR REPLACE VIEW knowledge.knowledge_inventory AS
SELECT
   (SELECT count(*) FROM knowledge.concept)             AS concepts,
   (SELECT count(*) FROM knowledge.symptom)             AS symptoms,
   (SELECT count(*) FROM knowledge.phenotype)           AS phenotypes,
   (SELECT count(*) FROM knowledge.mechanism)           AS mechanisms,
   (SELECT count(*) FROM knowledge.condition)           AS conditions,
   (SELECT count(*) FROM knowledge.relationship)        AS relationships,
   (SELECT count(*) FROM knowledge.rule)                AS rules,
   (SELECT count(*) FROM knowledge.question)            AS questions,
   (SELECT count(*) FROM knowledge.management_action)   AS management_actions;


-- =============================================================================
-- 27. END OF MIGRATION 011
-- =============================================================================
