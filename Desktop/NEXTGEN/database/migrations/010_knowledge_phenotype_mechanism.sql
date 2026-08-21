-- =============================================================================
-- AMEXAN Phase 2 â€” Migration 010: mechanisms + phenotype library
-- =============================================================================
-- Universal pathophysiology and clinical phenotype substrate.
--
-- DESIGN PRINCIPLES
-- -----------------------------------------------------------------------------
-- 1. Mechanisms are reusable across conditions.
-- 2. Phenotypes are reusable patterns of observed clinical reality.
-- 3. Diseases/conditions do not duplicate mechanisms or phenotypes.
-- 4. Positive and contradictory evidence are represented explicitly.
-- 5. Mechanisms may be hierarchical, causal, temporal and system-linked.
-- 6. Phenotypes may be composed, nested, context-dependent and longitudinal.
-- 7. Every feature may carry strength, timing, certainty and provenance.
-- 8. The clinical CPU reasons over observations, facts, mechanisms and phenotypes.
-- 9. Documentation is rendered from structured knowledge, never used as truth.
-- 10. No disease-specific engine is required.
-- =============================================================================


-- =============================================================================
-- 6. MECHANISMS â€” UNIVERSAL PATHOPHYSIOLOGY
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.mechanism CASCADE;
CREATE TABLE knowledge.mechanism (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   concept_id          uuid REFERENCES knowledge.concept(id),
   mechanism_code      text NOT NULL UNIQUE,
   canonical_name      text NOT NULL,
   display_name        text,
   description         text,

   mechanism_class     text NOT NULL DEFAULT 'pathophysiologic'
                       CHECK (
                          mechanism_class IN (
                             'pathophysiologic',
                             'physiologic',
                             'anatomic',
                             'immunologic',
                             'infectious',
                             'inflammatory',
                             'vascular',
                             'metabolic',
                             'endocrine',
                             'genetic',
                             'neoplastic',
                             'degenerative',
                             'toxic',
                             'traumatic',
                             'iatrogenic',
                             'pharmacologic',
                             'psychological',
                             'functional',
                             'obstructive',
                             'compressive',
                             'ischemic',
                             'hypoxic',
                             'hemorrhagic',
                             'infectious_inflammatory',
                             'mixed'
                          )
                       ),

   body_system_code    text REFERENCES knowledge.body_system(code),

   status              text NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','deprecated')),

   version             text,

   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.mechanism IS
'Universal reusable pathophysiological mechanism library.';

CREATE INDEX idx_knowledge_mechanism_concept
   ON knowledge.mechanism(concept_id);

CREATE INDEX idx_knowledge_mechanism_class
   ON knowledge.mechanism(mechanism_class);

CREATE INDEX idx_knowledge_mechanism_system
   ON knowledge.mechanism(body_system_code);

CREATE TRIGGER trg_knowledge_mechanism_updated_at
   BEFORE UPDATE ON knowledge.mechanism
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- Mechanism versions
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_version (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   version              integer NOT NULL,
   definition           jsonb NOT NULL,
   rationale            text,

   status               text NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','active','retired')),

   effective_from      date,
   effective_to        date,

   created_at          timestamptz NOT NULL DEFAULT now(),
   created_by          uuid REFERENCES identity.user_account(id),

   UNIQUE (mechanism_id, version)
);

COMMENT ON TABLE knowledge.mechanism_version IS
'Versioned machine-readable definitions of mechanisms.';


-- -----------------------------------------------------------------------------
-- Mechanism hierarchy
-- -----------------------------------------------------------------------------

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.mechanism_relationship CASCADE;
CREATE TABLE knowledge.mechanism_relationship (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   related_mechanism_id uuid NOT NULL
                        REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   relationship_type   text NOT NULL
                       CHECK (
                          relationship_type IN (
                             'causes',
                             'caused_by',
                             'contributes_to',
                             'results_from',
                             'precedes',
                             'follows',
                             'amplifies',
                             'attenuates',
                             'inhibits',
                             'mediates',
                             'part_of',
                             'subtype_of',
                             'overlaps',
                             'coexists_with',
                             'competes_with',
                             'requires',
                             'downstream_of',
                             'upstream_of',
                             'transforms_to'
                          )
                       ),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   description         text,

   CHECK (mechanism_id <> related_mechanism_id),

   UNIQUE (
      mechanism_id,
      related_mechanism_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.mechanism_relationship IS
'Causal, hierarchical and functional relationships between mechanisms.';

CREATE INDEX idx_knowledge_mechanism_relationship_source
   ON knowledge.mechanism_relationship(mechanism_id);

CREATE INDEX idx_knowledge_mechanism_relationship_target
   ON knowledge.mechanism_relationship(related_mechanism_id);


-- -----------------------------------------------------------------------------
-- Mechanism features
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_feature (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   feature_type        text NOT NULL
                       CHECK (
                          feature_type IN (
                             'fact',
                             'symptom',
                             'sign',
                             'finding',
                             'measurement',
                             'concept',
                             'phenotype',
                             'condition',
                             'investigation',
                             'medication',
                             'risk_factor',
                             'complication'
                          )
                       ),

   feature_code        text NOT NULL,

   operator             text NOT NULL DEFAULT 'eq'
                        CHECK (
                           operator IN (
                              'eq',
                              'neq',
                              'gt',
                              'gte',
                              'lt',
                              'lte',
                              'in',
                              'not_in',
                              'contains',
                              'exists',
                              'not_exists',
                              'between'
                           )
                        ),

   value               jsonb,

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   polarity            text NOT NULL DEFAULT 'positive'
                       CHECK (polarity IN ('positive','negative')),

   certainty            text NOT NULL DEFAULT 'established'
                       CHECK (
                          certainty IN (
                             'established',
                             'probable',
                             'possible',
                             'uncertain'
                          )
                       ),

   temporal_role       text
                       CHECK (
                          temporal_role IS NULL OR temporal_role IN (
                             'initiating',
                             'early',
                             'ongoing',
                             'progressive',
                             'late',
                             'terminal',
                             'reversible',
                             'persistent',
                             'intermittent'
                          )
                       ),

   description         text,

   UNIQUE (
      mechanism_id,
      feature_type,
      feature_code,
      operator,
      polarity,
      temporal_role
   )
);

COMMENT ON TABLE knowledge.mechanism_feature IS
'Clinical features supporting or contradicting a mechanism.';

CREATE INDEX idx_knowledge_mechanism_feature
   ON knowledge.mechanism_feature(mechanism_id);

CREATE INDEX idx_knowledge_mechanism_feature_code
   ON knowledge.mechanism_feature(feature_type, feature_code);


-- -----------------------------------------------------------------------------
-- Mechanism contexts
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_context (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   context_type_code   text NOT NULL
                       REFERENCES knowledge.context_type(code),

   context_value_id    uuid
                       REFERENCES knowledge.context_value(id),

   applicability       text NOT NULL DEFAULT 'applies'
                       CHECK (applicability IN ('applies','excludes')),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   description         text,

   UNIQUE (
      mechanism_id,
      context_type_code,
      context_value_id,
      applicability
   )
);

COMMENT ON TABLE knowledge.mechanism_context IS
'Context-dependent applicability of mechanisms.';


-- -----------------------------------------------------------------------------
-- Mechanism body-system relationships
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_system (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   body_system_code    text NOT NULL
                       REFERENCES knowledge.body_system(code),

   role                text NOT NULL DEFAULT 'involved'
                       CHECK (
                          role IN (
                             'primary',
                             'secondary',
                             'involved',
                             'upstream',
                             'downstream',
                             'target',
                             'source'
                          )
                       ),

   relevance           numeric(5,4) NOT NULL DEFAULT 1.0,

   UNIQUE (mechanism_id, body_system_code, role)
);

COMMENT ON TABLE knowledge.mechanism_system IS
'Many-to-many relationship between mechanisms and body systems.';


-- -----------------------------------------------------------------------------
-- Mechanism causal pathway
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_pathway (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   pathway_code        text NOT NULL UNIQUE,
   name                text NOT NULL,
   description         text,

   root_mechanism_id   uuid REFERENCES knowledge.mechanism(id),
   terminal_mechanism_id uuid REFERENCES knowledge.mechanism(id),

   status              text NOT NULL DEFAULT 'active'
                       CHECK (status IN ('draft','active','retired')),

   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.mechanism_pathway IS
'Named causal chains composed from reusable mechanisms.';

CREATE TABLE knowledge.mechanism_pathway_step (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   pathway_id          uuid NOT NULL
                       REFERENCES knowledge.mechanism_pathway(id)
                       ON DELETE CASCADE,

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id),

   step_order          integer NOT NULL,

   role                text
                       CHECK (
                          role IS NULL OR role IN (
                             'trigger',
                             'initiator',
                             'mediator',
                             'amplifier',
                             'downstream',
                             'endpoint'
                          )
                       ),

   description         text,

   UNIQUE (pathway_id, step_order)
);

COMMENT ON TABLE knowledge.mechanism_pathway_step IS
'Ordered mechanisms forming a causal path.';


-- -----------------------------------------------------------------------------
-- Mechanism evidence
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_source (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   source_type         text NOT NULL
                       CHECK (
                          source_type IN (
                             'textbook',
                             'guideline',
                             'systematic_review',
                             'meta_analysis',
                             'primary_literature',
                             'consensus',
                             'expert',
                             'local_protocol'
                          )
                       ),

   source_ref          text,
   citation            text,
   url                 text,
   evidence_level      text,

   notes               text,

   UNIQUE (mechanism_id, source_type, source_ref)
);

COMMENT ON TABLE knowledge.mechanism_source IS
'Provenance supporting a mechanism definition.';


-- -----------------------------------------------------------------------------
-- Mechanism documentation
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.mechanism_documentation (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   documentation_phrase text NOT NULL,
   language_code       text,
   context_code        text,

   is_preferred        boolean NOT NULL DEFAULT false,

   UNIQUE (
      mechanism_id,
      documentation_phrase,
      language_code,
      context_code
   )
);

COMMENT ON TABLE knowledge.mechanism_documentation IS
'Human-readable rendering of mechanisms for clinical documentation.';


-- =============================================================================
-- 7. PHENOTYPE LIBRARY
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.phenotype CASCADE;
CREATE TABLE knowledge.phenotype (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id          uuid REFERENCES knowledge.concept(id),

   phenotype_code      text NOT NULL UNIQUE,
   canonical_name      text NOT NULL,
   display_name        text,
   description         text,

   phenotype_class     text NOT NULL DEFAULT 'clinical'
                       CHECK (
                          phenotype_class IN (
                             'clinical',
                             'syndrome',
                             'symptom_cluster',
                             'sign_cluster',
                             'investigation_pattern',
                             'laboratory_pattern',
                             'imaging_pattern',
                             'physiologic',
                             'pathophysiologic',
                             'severity',
                             'risk',
                             'complication',
                             'response',
                             'treatment_response',
                             'adverse_effect',
                             'temporal',
                             'anatomic',
                             'functional',
                             'behavioral',
                             'developmental',
                             'mixed'
                          )
                       ),

   status              text NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','deprecated')),

   version             text,

   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.phenotype IS
'Universal reusable clinical phenotype library.';

CREATE INDEX idx_knowledge_phenotype_concept
   ON knowledge.phenotype(concept_id);

CREATE INDEX idx_knowledge_phenotype_class
   ON knowledge.phenotype(phenotype_class);

CREATE INDEX idx_knowledge_phenotype_name
   ON knowledge.phenotype(canonical_name);

CREATE TRIGGER trg_knowledge_phenotype_updated_at
   BEFORE UPDATE ON knowledge.phenotype
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- -----------------------------------------------------------------------------
-- Phenotype versions
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_version (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   version             integer NOT NULL,
   definition          jsonb NOT NULL,

   status              text NOT NULL DEFAULT 'draft'
                       CHECK (status IN ('draft','active','retired')),

   effective_from      date,
   effective_to        date,

   created_at          timestamptz NOT NULL DEFAULT now(),
   created_by          uuid REFERENCES identity.user_account(id),

   UNIQUE (phenotype_id, version)
);

COMMENT ON TABLE knowledge.phenotype_version IS
'Versioned phenotype definitions.';


-- -----------------------------------------------------------------------------
-- Phenotype feature model
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_feature (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   feature_type        text NOT NULL
                       CHECK (
                          feature_type IN (
                             'fact',
                             'symptom',
                             'sign',
                             'finding',
                             'measurement',
                             'concept',
                             'phenotype',
                             'mechanism',
                             'condition',
                             'investigation',
                             'medication',
                             'risk_factor',
                             'complication'
                          )
                       ),

   feature_code        text NOT NULL,

   operator             text NOT NULL DEFAULT 'eq'
                        CHECK (
                           operator IN (
                              'eq',
                              'neq',
                              'gt',
                              'gte',
                              'lt',
                              'lte',
                              'in',
                              'not_in',
                              'contains',
                              'exists',
                              'not_exists',
                              'between'
                           )
                        ),

   value               jsonb,

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   polarity            text NOT NULL DEFAULT 'positive'
                       CHECK (polarity IN ('positive','negative')),

   certainty            text NOT NULL DEFAULT 'established'
                       CHECK (
                          certainty IN (
                             'established',
                             'probable',
                             'possible',
                             'uncertain'
                          )
                       ),

   requiredness        text NOT NULL DEFAULT 'supporting'
                       CHECK (
                          requiredness IN (
                             'required',
                             'supporting',
                             'optional',
                             'exclusion'
                          )
                       ),

   temporal_role       text
                       CHECK (
                          temporal_role IS NULL OR temporal_role IN (
                             'triggering',
                             'acute',
                             'subacute',
                             'chronic',
                             'intermittent',
                             'progressive',
                             'static',
                             'resolving',
                             'recurrent',
                             'terminal'
                          )
                       ),

   minimum_duration    interval,
   maximum_duration    interval,

   description         text,

   UNIQUE (
      phenotype_id,
      feature_type,
      feature_code,
      operator,
      polarity,
      requiredness,
      temporal_role
   )
);

COMMENT ON TABLE knowledge.phenotype_feature IS
'Structured features defining support, contradiction, requirement and timing of a phenotype.';

CREATE INDEX idx_knowledge_phenotype_feature
   ON knowledge.phenotype_feature(phenotype_id);

CREATE INDEX idx_knowledge_phenotype_feature_code
   ON knowledge.phenotype_feature(feature_type, feature_code);


-- -----------------------------------------------------------------------------
-- Phenotype contexts
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_context (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   context_type_code   text NOT NULL
                       REFERENCES knowledge.context_type(code),

   context_value_id    uuid
                       REFERENCES knowledge.context_value(id),

   applicability       text NOT NULL DEFAULT 'applies'
                       CHECK (applicability IN ('applies','excludes')),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   description         text,

   UNIQUE (
      phenotype_id,
      context_type_code,
      context_value_id,
      applicability
   )
);

COMMENT ON TABLE knowledge.phenotype_context IS
'Contexts modifying phenotype applicability and clinical interpretation.';


-- -----------------------------------------------------------------------------
-- Phenotype relationships
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_relationship (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   related_phenotype_id uuid NOT NULL
                        REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   relationship_type   text NOT NULL
                       CHECK (
                          relationship_type IN (
                             'overlaps',
                             'extends',
                             'subset_of',
                             'superset_of',
                             'excludes',
                             'differentiates',
                             'precedes',
                             'follows',
                             'coexists_with',
                             'causes',
                             'caused_by',
                             'transforms_to',
                             'progresses_to',
                             'resolves_to',
                             'mimics',
                             'mimicked_by',
                             'associated_with'
                          )
                       ),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   description         text,

   CHECK (phenotype_id <> related_phenotype_id),

   UNIQUE (
      phenotype_id,
      related_phenotype_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.phenotype_relationship IS
'Typed relationships between clinical phenotypes.';

CREATE INDEX idx_knowledge_phenotype_relationship_source
   ON knowledge.phenotype_relationship(phenotype_id);

CREATE INDEX idx_knowledge_phenotype_relationship_target
   ON knowledge.phenotype_relationship(related_phenotype_id);


-- -----------------------------------------------------------------------------
-- Phenotype composition
-- -----------------------------------------------------------------------------

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.phenotype_component CASCADE;
CREATE TABLE knowledge.phenotype_component (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   component_type      text NOT NULL
                       CHECK (
                          component_type IN (
                             'phenotype',
                             'mechanism',
                             'symptom',
                             'sign',
                             'fact',
                             'finding'
                          )
                       ),

   component_code      text NOT NULL,

   relationship         text NOT NULL DEFAULT 'supports'
                        CHECK (
                           relationship IN (
                              'supports',
                              'requires',
                              'excludes',
                              'modifies',
                              'defines'
                           )
                        ),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   order_index         integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE knowledge.phenotype_component IS
'Composable components used to construct higher-order phenotypes.';


-- -----------------------------------------------------------------------------
-- Phenotype severity model
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_severity (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   severity_code       text NOT NULL,
   label               text NOT NULL,

   minimum_score       numeric,
   maximum_score       numeric,

   criteria            jsonb,

   urgency             text
                       CHECK (
                          urgency IS NULL OR urgency IN (
                             'routine',
                             'priority',
                             'urgent',
                             'emergency',
                             'critical'
                          )
                       ),

   description         text,

   UNIQUE (phenotype_id, severity_code)
);

COMMENT ON TABLE knowledge.phenotype_severity IS
'Severity strata for phenotypes and clinical syndromes.';


-- -----------------------------------------------------------------------------
-- Phenotype progression
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_transition (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_phenotype_id uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   target_phenotype_id uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   transition_type     text NOT NULL
                       CHECK (
                          transition_type IN (
                             'progression',
                             'resolution',
                             'relapse',
                             'recurrence',
                             'transformation',
                             'complication',
                             'decompensation',
                             'recovery'
                          )
                       ),

   expected_interval   interval,

   probability         numeric(5,4),

   conditions          jsonb,

   description         text,

   CHECK (source_phenotype_id <> target_phenotype_id),

   UNIQUE (
      source_phenotype_id,
      target_phenotype_id,
      transition_type
   )
);

COMMENT ON TABLE knowledge.phenotype_transition IS
'Longitudinal transitions between clinical phenotypes.';


-- -----------------------------------------------------------------------------
-- Phenotype mechanism relationships
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_mechanism (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   relationship_type   text NOT NULL
                       CHECK (
                          relationship_type IN (
                             'caused_by',
                             'mediated_by',
                             'associated_with',
                             'results_in',
                             'explained_by',
                             'exacerbated_by',
                             'protected_by'
                          )
                       ),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   certainty            text NOT NULL DEFAULT 'established'
                       CHECK (
                          certainty IN (
                             'established',
                             'probable',
                             'possible',
                             'uncertain'
                          )
                       ),

   UNIQUE (
      phenotype_id,
      mechanism_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.phenotype_mechanism IS
'Links observed phenotypes to underlying pathophysiological mechanisms.';


-- -----------------------------------------------------------------------------
-- Phenotype-condition relationships
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_condition (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   condition_concept_id uuid NOT NULL
                        REFERENCES knowledge.concept(id),

   relationship_type   text NOT NULL
                       CHECK (
                          relationship_type IN (
                             'supports',
                             'strongly_supports',
                             'characteristic_of',
                             'required_for',
                             'excludes',
                             'associated_with',
                             'complication_of',
                             'severity_marker',
                             'prognostic_marker',
                             'response_marker'
                          )
                       ),

   likelihood_weight   numeric(7,4),

   specificity         numeric(5,4),

   sensitivity         numeric(5,4),

   description         text,

   UNIQUE (
      phenotype_id,
      condition_concept_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.phenotype_condition IS
'Links reusable phenotypes to conditions without rebuilding phenotype definitions per disease.';


-- -----------------------------------------------------------------------------
-- Phenotype measurement model
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_measurement (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   measurement_code    text NOT NULL,

   unit_code           text,

   operator            text NOT NULL
                       CHECK (
                          operator IN (
                             'eq',
                             'neq',
                             'gt',
                             'gte',
                             'lt',
                             'lte',
                             'between'
                          )
                       ),

   threshold_value     numeric,

   threshold_max       numeric,

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   context_condition   jsonb,

   description         text
);

COMMENT ON TABLE knowledge.phenotype_measurement IS
'Quantitative thresholds contributing to phenotype recognition.';


-- -----------------------------------------------------------------------------
-- Phenotype evidence
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_source (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   source_type         text NOT NULL
                       CHECK (
                          source_type IN (
                             'textbook',
                             'guideline',
                             'systematic_review',
                             'meta_analysis',
                             'primary_literature',
                             'consensus',
                             'expert',
                             'local_protocol'
                          )
                       ),

   source_ref          text,
   citation            text,
   url                 text,
   evidence_level      text,

   notes               text,

   UNIQUE (
      phenotype_id,
      source_type,
      source_ref
   )
);

COMMENT ON TABLE knowledge.phenotype_source IS
'Evidence and provenance supporting phenotype definitions.';


-- -----------------------------------------------------------------------------
-- Phenotype documentation
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_documentation (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   documentation_phrase text NOT NULL,

   language_code       text,

   context_code        text,

   is_preferred        boolean NOT NULL DEFAULT false,

   UNIQUE (
      phenotype_id,
      documentation_phrase,
      language_code,
      context_code
   )
);

COMMENT ON TABLE knowledge.phenotype_documentation IS
'Human-readable phrases rendered from structured phenotype knowledge.';


-- =============================================================================
-- 8. UNIVERSAL PHENOTYPE OBSERVATION / MATCHING SUBSTRATE
-- =============================================================================

CREATE TABLE knowledge.phenotype_match_profile (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   minimum_support     numeric(7,4) NOT NULL DEFAULT 0,
   minimum_confidence  numeric(5,4) NOT NULL DEFAULT 0,

   contradiction_limit numeric(7,4) NOT NULL DEFAULT 0,

   require_all_required boolean NOT NULL DEFAULT false,

   scoring_method      text NOT NULL DEFAULT 'weighted'
                       CHECK (
                          scoring_method IN (
                             'weighted',
                             'bayesian',
                             'rule_based',
                             'threshold',
                             'hybrid'
                          )
                       ),

   parameters          jsonb,

   UNIQUE (phenotype_id)
);

COMMENT ON TABLE knowledge.phenotype_match_profile IS
'Defines how the clinical CPU evaluates evidence against a phenotype.';


-- -----------------------------------------------------------------------------
-- Phenotype feature groups
-- -----------------------------------------------------------------------------

CREATE TABLE knowledge.phenotype_feature_group (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   group_code          text NOT NULL,
   group_name          text NOT NULL,

   logical_operator    text NOT NULL DEFAULT 'AND'
                       CHECK (logical_operator IN ('AND','OR','NOT')),

   minimum_required    integer,

   priority            integer NOT NULL DEFAULT 0,

   description         text,

   UNIQUE (phenotype_id, group_code)
);

COMMENT ON TABLE knowledge.phenotype_feature_group IS
'Logical grouping of phenotype-defining evidence.';


CREATE TABLE knowledge.phenotype_feature_group_member (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   group_id             uuid NOT NULL
                        REFERENCES knowledge.phenotype_feature_group(id)
                        ON DELETE CASCADE,

   phenotype_feature_id uuid NOT NULL
                        REFERENCES knowledge.phenotype_feature(id)
                        ON DELETE CASCADE,

   member_order         integer NOT NULL DEFAULT 0,

   UNIQUE (group_id, phenotype_feature_id)
);

COMMENT ON TABLE knowledge.phenotype_feature_group_member IS
'Membership of phenotype features in logical evidence groups.';


-- =============================================================================
-- 9. MECHANISM â†” PHENOTYPE INTEGRATION
-- =============================================================================

CREATE TABLE knowledge.mechanism_phenotype (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   phenotype_id        uuid NOT NULL
                       REFERENCES knowledge.phenotype(id) ON DELETE CASCADE,

   relationship_type   text NOT NULL
                       CHECK (
                          relationship_type IN (
                             'produces',
                             'causes',
                             'supports',
                             'explains',
                             'manifests_as',
                             'amplifies',
                             'protects_against',
                             'contradicts'
                          )
                       ),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   temporal_order      integer,

   description         text,

   UNIQUE (
      mechanism_id,
      phenotype_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.mechanism_phenotype IS
'Universal bridge between pathophysiological mechanisms and observable phenotypes.';

CREATE INDEX idx_knowledge_mechanism_phenotype_mechanism
   ON knowledge.mechanism_phenotype(mechanism_id);

CREATE INDEX idx_knowledge_mechanism_phenotype_phenotype
   ON knowledge.mechanism_phenotype(phenotype_id);


-- =============================================================================
-- 10. UNIVERSAL KNOWLEDGE PROVENANCE
-- =============================================================================

CREATE TABLE knowledge.knowledge_assertion (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   subject_type        text NOT NULL
                       CHECK (
                          subject_type IN (
                             'concept',
                             'mechanism',
                             'phenotype',
                             'symptom',
                             'rule',
                             'condition',
                             'fact'
                          )
                       ),

   subject_code        text NOT NULL,

   predicate           text NOT NULL,

   object_type         text,

   object_code         text,

   value               jsonb,

   certainty            text NOT NULL DEFAULT 'established'
                       CHECK (
                          certainty IN (
                             'established',
                             'probable',
                             'possible',
                             'uncertain',
                             'controversial'
                          )
                       ),

   evidence_level      text,

   source_id           uuid,

   effective_from      date,
   effective_to        date,

   created_at          timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      subject_type,
      subject_code,
      predicate,
      object_type,
      object_code
   )
);

COMMENT ON TABLE knowledge.knowledge_assertion IS
'Universal extensible knowledge graph assertions supporting future clinical reasoning.';

CREATE INDEX idx_knowledge_assertion_subject
   ON knowledge.knowledge_assertion(subject_type, subject_code);

CREATE INDEX idx_knowledge_assertion_predicate
   ON knowledge.knowledge_assertion(predicate);

CREATE INDEX idx_knowledge_assertion_object
   ON knowledge.knowledge_assertion(object_type, object_code);


-- =============================================================================
-- 11. KNOWLEDGE VALIDATION
-- =============================================================================

CREATE TABLE knowledge.validation (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   subject_type        text NOT NULL,
   subject_id          uuid NOT NULL,

   validation_type     text NOT NULL
                       CHECK (
                          validation_type IN (
                             'structural',
                             'clinical',
                             'evidence',
                             'safety',
                             'regulatory',
                             'local'
                          )
                       ),

   status              text NOT NULL DEFAULT 'pending'
                       CHECK (
                          status IN (
                             'pending',
                             'passed',
                             'failed',
                             'waived'
                          )
                       ),

   validator           text,
   validated_at        timestamptz,

   findings            jsonb,
   notes               text
);

COMMENT ON TABLE knowledge.validation IS
'Validation lifecycle for clinical knowledge objects.';


-- =============================================================================
-- 12. UNIVERSAL KNOWLEDGE CHANGE HISTORY
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.change_log CASCADE;
CREATE TABLE knowledge.change_log (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   entity_type         text NOT NULL,
   entity_id           uuid NOT NULL,

   change_type         text NOT NULL
                       CHECK (
                          change_type IN (
                             'create',
                             'update',
                             'deprecate',
                             'restore',
                             'activate',
                             'retire'
                          )
                       ),

   changed_at          timestamptz NOT NULL DEFAULT now(),
   changed_by          uuid REFERENCES identity.user_account(id),

   before              jsonb,
   after               jsonb,

   reason              text
);

COMMENT ON TABLE knowledge.change_log IS
'Version and lifecycle history for the universal clinical knowledge substrate.';

CREATE INDEX idx_knowledge_change_log_entity
   ON knowledge.change_log(entity_type, entity_id);

CREATE INDEX idx_knowledge_change_log_time
   ON knowledge.change_log(changed_at);


-- =============================================================================
-- 13. UNIVERSAL KNOWLEDGE TAGS
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.tag CASCADE;
CREATE TABLE knowledge.tag (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   code                text NOT NULL UNIQUE,
   name                text NOT NULL,
   description         text,

   created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.tag IS
'Universal semantic tags for knowledge objects.';


CREATE TABLE knowledge.tag_assignment (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   tag_id              uuid NOT NULL
                       REFERENCES knowledge.tag(id) ON DELETE CASCADE,

   entity_type         text NOT NULL,
   entity_id           uuid NOT NULL,

   UNIQUE (tag_id, entity_type, entity_id)
);

COMMENT ON TABLE knowledge.tag_assignment IS
'Semantic tagging across the universal knowledge substrate.';

CREATE INDEX idx_knowledge_tag_assignment_entity
   ON knowledge.tag_assignment(entity_type, entity_id);


-- =============================================================================
-- 14. KNOWLEDGE SEARCH / RETRIEVAL INDEX
-- =============================================================================

CREATE TABLE knowledge.search_index (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   entity_type         text NOT NULL,
   entity_id           uuid NOT NULL,

   canonical_text      text,
   searchable_text     text,

   metadata            jsonb,

   updated_at          timestamptz NOT NULL DEFAULT now(),

   UNIQUE (entity_type, entity_id)
);

COMMENT ON TABLE knowledge.search_index IS
'Unified retrieval index for clinical knowledge discovery.';

CREATE INDEX idx_knowledge_search_entity
   ON knowledge.search_index(entity_type, entity_id);


-- =============================================================================
-- 15. UNIVERSAL CLINICAL KNOWLEDGE PACKAGE
-- =============================================================================

CREATE TABLE knowledge.package (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   package_code        text NOT NULL UNIQUE,
   name                text NOT NULL,

   package_type        text NOT NULL
                       CHECK (
                          package_type IN (
                             'textbook',
                             'guideline',
                             'specialty',
                             'subspecialty',
                             'clinical_domain',
                             'local_protocol',
                             'national_protocol',
                             'evidence_bundle',
                             'knowledge_release'
                          )
                       ),

   version             text NOT NULL,

   description         text,

   status              text NOT NULL DEFAULT 'draft'
                       CHECK (
                          status IN (
                             'draft',
                             'validated',
                             'active',
                             'retired'
                          )
                       ),

   effective_from      date,
   effective_to        date,

   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.package IS
'Versioned packages of medical knowledge such as textbooks, guidelines and specialty libraries.';

CREATE TRIGGER trg_knowledge_package_updated_at
   BEFORE UPDATE ON knowledge.package
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


CREATE TABLE knowledge.package_member (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   package_id          uuid NOT NULL
                       REFERENCES knowledge.package(id) ON DELETE CASCADE,

   entity_type         text NOT NULL,
   entity_id           uuid NOT NULL,

   role                text
                       CHECK (
                          role IS NULL OR role IN (
                             'definition',
                             'mechanism',
                             'phenotype',
                             'rule',
                             'symptom',
                             'question',
                             'condition',
                             'investigation',
                             'management',
                             'reference'
                          )
                       ),

   UNIQUE (package_id, entity_type, entity_id)
);

COMMENT ON TABLE knowledge.package_member IS
'Objects composing a versioned medical knowledge package.';

CREATE INDEX idx_knowledge_package_member
   ON knowledge.package_member(package_id, entity_type);


-- =============================================================================
-- 16. UNIVERSAL KNOWLEDGE DOMAIN
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.domain CASCADE;
CREATE TABLE knowledge.domain (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   domain_code         text NOT NULL UNIQUE,
   name                text NOT NULL,
   description         text,

   parent_domain_id    uuid
                       REFERENCES knowledge.domain(id),

   status              text NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','deprecated')),

   created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.domain IS
'Hierarchical medical knowledge domains spanning all clinical specialties.';


CREATE TABLE knowledge.domain_member (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   domain_id           uuid NOT NULL
                       REFERENCES knowledge.domain(id) ON DELETE CASCADE,

   entity_type         text NOT NULL,
   entity_id           uuid NOT NULL,

   role                text,

   UNIQUE (domain_id, entity_type, entity_id)
);

COMMENT ON TABLE knowledge.domain_member IS
'Universal membership of clinical knowledge objects within medical domains.';


-- =============================================================================
-- 17. KNOWLEDGE CROSS-REFERENCE
-- =============================================================================

CREATE TABLE knowledge.cross_reference (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_type         text NOT NULL,
   source_id           uuid NOT NULL,

   target_type         text NOT NULL,
   target_id           uuid NOT NULL,

   relationship_type   text NOT NULL,

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   description         text,

   UNIQUE (
      source_type,
      source_id,
      target_type,
      target_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.cross_reference IS
'Universal typed links between knowledge objects.';

CREATE INDEX idx_knowledge_cross_reference_source
   ON knowledge.cross_reference(source_type, source_id);

CREATE INDEX idx_knowledge_cross_reference_target
   ON knowledge.cross_reference(target_type, target_id);


-- =============================================================================
-- 18. KNOWLEDGE RELEASE
-- =============================================================================

CREATE TABLE knowledge.release (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   release_code        text NOT NULL UNIQUE,
   version             text NOT NULL UNIQUE,

   name                text NOT NULL,
   description         text,

   status              text NOT NULL DEFAULT 'draft'
                       CHECK (
                          status IN (
                             'draft',
                             'validated',
                             'active',
                             'superseded',
                             'rolled_back'
                          )
                       ),

   effective_from      date,
   released_at         timestamptz,

   created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.release IS
'Immutable versioned releases of the AMEXAN clinical knowledge substrate.';


CREATE TABLE knowledge.release_member (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   release_id          uuid NOT NULL
                       REFERENCES knowledge.release(id) ON DELETE CASCADE,

   entity_type         text NOT NULL,
   entity_id           uuid NOT NULL,

   entity_version      integer,

   UNIQUE (
      release_id,
      entity_type,
      entity_id,
      entity_version
   )
);

COMMENT ON TABLE knowledge.release_member IS
'Exact knowledge objects and versions contained in a knowledge release.';


-- =============================================================================
-- 19. INTEGRITY CONSTRAINTS
-- =============================================================================

ALTER TABLE knowledge.mechanism_feature
   ADD CONSTRAINT chk_mechanism_feature_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.phenotype_feature
   ADD CONSTRAINT chk_phenotype_feature_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.phenotype_context
   ADD CONSTRAINT chk_phenotype_context_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.mechanism_context
   ADD CONSTRAINT chk_mechanism_context_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.mechanism_phenotype
   ADD CONSTRAINT chk_mechanism_phenotype_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.phenotype_relationship
   ADD CONSTRAINT chk_phenotype_relationship_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.mechanism_relationship
   ADD CONSTRAINT chk_mechanism_relationship_weight
   CHECK (weight >= 0 AND weight <= 1);

ALTER TABLE knowledge.phenotype_condition
   ADD CONSTRAINT chk_phenotype_condition_probability
   CHECK (
      (likelihood_weight IS NULL OR likelihood_weight >= 0)
      AND
      (specificity IS NULL OR specificity BETWEEN 0 AND 1)
      AND
      (sensitivity IS NULL OR sensitivity BETWEEN 0 AND 1)
   );

ALTER TABLE knowledge.phenotype_transition
   ADD CONSTRAINT chk_phenotype_transition_probability
   CHECK (
      probability IS NULL OR probability BETWEEN 0 AND 1
   );


-- =============================================================================
-- 20. PERFORMANCE INDEXES
-- =============================================================================

CREATE INDEX idx_mechanism_feature_lookup
   ON knowledge.mechanism_feature(feature_type, feature_code, polarity);

CREATE INDEX idx_mechanism_context_lookup
   ON knowledge.mechanism_context(
      context_type_code,
      context_value_id
   );

CREATE INDEX idx_phenotype_context_lookup
   ON knowledge.phenotype_context(
      context_type_code,
      context_value_id
   );

CREATE INDEX idx_phenotype_condition_lookup
   ON knowledge.phenotype_condition(condition_concept_id);

CREATE INDEX idx_phenotype_mechanism_lookup
   ON knowledge.phenotype_mechanism(mechanism_id);

CREATE INDEX idx_phenotype_measurement_lookup
   ON knowledge.phenotype_measurement(measurement_code);

CREATE INDEX idx_phenotype_transition_source
   ON knowledge.phenotype_transition(source_phenotype_id);

CREATE INDEX idx_phenotype_transition_target
   ON knowledge.phenotype_transition(target_phenotype_id);

CREATE INDEX idx_mechanism_pathway_step_mechanism
   ON knowledge.mechanism_pathway_step(mechanism_id);

CREATE INDEX idx_knowledge_package_type
   ON knowledge.package(package_type, status);

CREATE INDEX idx_knowledge_domain_parent
   ON knowledge.domain(parent_domain_id);

CREATE INDEX idx_knowledge_validation_subject
   ON knowledge.validation(subject_type, subject_id);


-- =============================================================================
-- END MIGRATION 010
-- =============================================================================
