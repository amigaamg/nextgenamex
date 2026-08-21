-- =============================================================================
-- AMEXAN Phase 2 — Migration 014: investigation + examination primitives
-- =============================================================================
-- Clinical Operating System principle:
--
-- HISTORY + EXAMINATION + INVESTIGATIONS
--              ↓
--       UNIVERSAL FACTS
--              ↓
--       PHENOTYPES / MECHANISMS
--              ↓
--     DIFFERENTIAL / RISK / SEVERITY
--              ↓
--      INVESTIGATION / ACTION
--
-- Investigations and examination findings are UNIVERSAL primitives.
-- They are never duplicated inside diseases.
--
-- A CBC is one investigation.
-- A respiratory examination is one examination module.
-- "Tachypnoea" is one clinical concept/fact regardless of whether it occurs
-- in pneumonia, asthma, heart failure, sepsis, anaemia or metabolic disease.
--
-- Disease knowledge attaches to these primitives through relationships/rules.
-- =============================================================================


-- =============================================================================
-- 1. UNIVERSAL VOCABULARY
-- =============================================================================

ALTER TABLE knowledge.concept
   DROP CONSTRAINT IF EXISTS chk_knowledge_concept_type;

ALTER TABLE knowledge.concept
   ADD CONSTRAINT chk_knowledge_concept_type
   CHECK (
      concept_type IN (
         'symptom',
         'sign',
         'finding',
         'fact',
         'risk_factor',
         'mechanism',
         'phenotype',
         'condition',
         'investigation',
         'medication',
         'complication',
         'body_system',
         'examination_module',
         'examination_finding',
         'protocol',
         'monitoring',
         'education'
      )
   );

COMMENT ON CONSTRAINT chk_knowledge_concept_type ON knowledge.concept IS
'Universal AMEXAN clinical vocabulary. Clinical objects are represented once and reused across history, examination, investigation, diagnosis, management, monitoring, education and protocols.';


-- =============================================================================
-- 2. INVESTIGATION LIBRARY
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.investigation CASCADE;
CREATE TABLE knowledge.investigation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid REFERENCES knowledge.concept(id),

   investigation_code    text NOT NULL UNIQUE,
   canonical_name        text NOT NULL,
   display_name          text,

   description           text,

   investigation_type   text NOT NULL DEFAULT 'laboratory'
                         CHECK (
                            investigation_type IN (
                               'laboratory',
                               'imaging',
                               'physiological',
                               'pathology',
                               'microbiology',
                               'genetic',
                               'point_of_care',
                               'endoscopic',
                               'functional',
                               'other'
                            )
                         ),

   modality              text,

   body_system_code      text REFERENCES knowledge.body_system(code),

   specimen              text,
   specimen_container    text,
   collection_method     text,

   turn_around_minutes   integer
                         CHECK (turn_around_minutes IS NULL OR turn_around_minutes >= 0),

   preparation           text,
   timing_requirements   text,

   fasting_required      boolean NOT NULL DEFAULT false,

   is_screening          boolean NOT NULL DEFAULT false,
   is_diagnostic         boolean NOT NULL DEFAULT true,
   is_monitoring        boolean NOT NULL DEFAULT false,

   invasiveness          text NOT NULL DEFAULT 'non_invasive'
                         CHECK (
                            invasiveness IN (
                               'non_invasive',
                               'minimally_invasive',
                               'invasive'
                            )
                         ),

   radiation_exposure    boolean NOT NULL DEFAULT false,

   availability_level    text NOT NULL DEFAULT 'facility'
                         CHECK (
                            availability_level IN (
                               'bedside',
                               'point_of_care',
                               'facility',
                               'reference_lab',
                               'specialist_center'
                            )
                         ),

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation IS
'Universal investigation registry. Each investigation exists once and is reused by conditions, symptoms, mechanisms, phenotypes, protocols, screening pathways and monitoring pathways.';

CREATE INDEX idx_knowledge_investigation_concept
   ON knowledge.investigation(concept_id);

CREATE INDEX idx_knowledge_investigation_system
   ON knowledge.investigation(body_system_code);

CREATE INDEX idx_knowledge_investigation_type
   ON knowledge.investigation(investigation_type);

CREATE INDEX idx_knowledge_investigation_status
   ON knowledge.investigation(status);

CREATE TRIGGER trg_knowledge_investigation_updated_at
   BEFORE UPDATE ON knowledge.investigation
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 3. INVESTIGATION COMPONENTS
-- =============================================================================
-- Allows CBC, U&E, LFT etc. to be represented as panels containing reusable
-- measurable components.
--
-- Example:
-- CBC
--   ├── haemoglobin
--   ├── WBC
--   ├── neutrophils
--   ├── lymphocytes
--   └── platelets
--
-- The component is the clinical fact carrier; the panel is the investigation.


CREATE TABLE knowledge.investigation_component (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   concept_id            uuid REFERENCES knowledge.concept(id),

   component_code        text NOT NULL,
   canonical_name        text NOT NULL,
   display_name          text,

   component_type        text NOT NULL DEFAULT 'measurement'
                         CHECK (
                            component_type IN (
                               'measurement',
                               'observation',
                               'qualitative',
                               'calculated',
                               'interpretive'
                            )
                         ),

   fact_definition_code  text REFERENCES clinical.fact_definition(code),

   value_type            text NOT NULL DEFAULT 'numeric'
                         CHECK (
                            value_type IN (
                               'numeric',
                               'integer',
                               'boolean',
                               'text',
                               'coded',
                               'date',
                               'datetime'
                            )
                         ),

   unit                  text,

   reference_range_type  text
                         CHECK (
                            reference_range_type IS NULL OR
                            reference_range_type IN (
                               'numeric',
                               'categorical',
                               'age_specific',
                               'sex_specific',
                               'pregnancy_specific',
                               'gestational_age_specific',
                               'context_specific',
                               'none'
                            )
                         ),

   sort_order            integer NOT NULL DEFAULT 0,

   required              boolean NOT NULL DEFAULT false,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (investigation_id, component_code)
);

COMMENT ON TABLE knowledge.investigation_component IS
'Reusable measurable or interpretable component of an investigation. Components map results into universal clinical facts.';

CREATE INDEX idx_investigation_component_investigation
   ON knowledge.investigation_component(investigation_id);

CREATE INDEX idx_investigation_component_fact
   ON knowledge.investigation_component(fact_definition_code);

CREATE INDEX idx_investigation_component_concept
   ON knowledge.investigation_component(concept_id);


-- =============================================================================
-- 4. INVESTIGATION REFERENCE RANGES
-- =============================================================================
-- Reference ranges must be contextual rather than globally hard-coded.
--
-- A haemoglobin value has different interpretation according to age, sex,
-- pregnancy, altitude and other applicable contexts.
-- =============================================================================

CREATE TABLE knowledge.investigation_reference_range (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   component_id          uuid NOT NULL
                         REFERENCES knowledge.investigation_component(id)
                         ON DELETE CASCADE,

   context_type_code     text REFERENCES knowledge.context_type(code),
   context_value_id      uuid REFERENCES knowledge.context_value(id),

   lower_value           numeric,
   upper_value           numeric,

   lower_inclusive       boolean NOT NULL DEFAULT true,
   upper_inclusive       boolean NOT NULL DEFAULT true,

   unit                  text,

   interpretation_code   text,

   source                 text,
   source_version        text,

   effective_from        date,
   effective_to          date,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   CHECK (
      lower_value IS NULL
      OR upper_value IS NULL
      OR lower_value <= upper_value
   )
);

COMMENT ON TABLE knowledge.investigation_reference_range IS
'Context-aware reference ranges. Interpretation is never assumed to be universally identical across age, sex, pregnancy, gestational age or other contexts.';

CREATE INDEX idx_investigation_reference_component
   ON knowledge.investigation_reference_range(component_id);

CREATE INDEX idx_investigation_reference_context
   ON knowledge.investigation_reference_range(context_type_code, context_value_id);


-- =============================================================================
-- 5. INVESTIGATION RESULT INTERPRETATIONS
-- =============================================================================
-- Converts raw values into universal clinical facts.
--
-- Example:
-- SpO2 84%
--     ↓
-- FACT-HYPOXAEMIA
--
-- WBC 23 ×10^9/L
--     ↓
-- FACT-LEUKOCYTOSIS
--
-- CXR consolidation
--     ↓
-- FINDING-FOCAL-AIRSPACE-CONSOLIDATION
-- =============================================================================

CREATE TABLE knowledge.investigation_interpretation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   component_id          uuid NOT NULL
                         REFERENCES knowledge.investigation_component(id)
                         ON DELETE CASCADE,

   interpretation_code   text NOT NULL,

   operator              text NOT NULL
                         CHECK (
                            operator IN (
                               'eq',
                               'neq',
                               'gt',
                               'gte',
                               'lt',
                               'lte',
                               'between',
                               'in',
                               'contains',
                               'exists'
                            )
                         ),

   value                 jsonb,

   result_fact_code      text REFERENCES clinical.fact_definition(code),

   result_concept_id     uuid REFERENCES knowledge.concept(id),

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),

   severity              text,

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   interpretation_text   text,

   priority              integer NOT NULL DEFAULT 0,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (component_id, interpretation_code)
);

COMMENT ON TABLE knowledge.investigation_interpretation IS
'Machine-readable interpretation of investigation results into universal clinical facts, findings, phenotypes or severity signals.';


-- =============================================================================
-- 6. INVESTIGATION → CONDITION
-- =============================================================================

CREATE TABLE knowledge.investigation_condition (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   condition_id          uuid NOT NULL
                         REFERENCES knowledge.condition(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL DEFAULT 'relevant'
                         CHECK (
                            relationship_type IN (
                               'screening',
                               'diagnostic',
                               'confirmatory',
                               'supportive',
                               'severity',
                               'staging',
                               'monitoring',
                               'prognostic',
                               'exclude',
                               'relevant'
                            )
                         ),

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale             text,

   priority              integer NOT NULL DEFAULT 0,

   UNIQUE (
      investigation_id,
      condition_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.investigation_condition IS
'Associates universal investigations with conditions without making the investigation disease-owned. Rules determine actual activation.';


-- =============================================================================
-- 7. INVESTIGATION → SYMPTOM
-- =============================================================================

CREATE TABLE knowledge.investigation_symptom (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   symptom_id            uuid NOT NULL
                         REFERENCES knowledge.symptom(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL DEFAULT 'may_help_evaluate'
                         CHECK (
                            relationship_type IN (
                               'evaluates',
                               'supports',
                               'excludes',
                               'severity',
                               'complication',
                               'prognostic',
                               'may_help_evaluate'
                            )
                         ),

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale             text,

   UNIQUE (
      investigation_id,
      symptom_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.investigation_symptom IS
'Associates investigations with symptoms and their diagnostic purposes without hard-coding symptom-specific investigation engines.';


-- =============================================================================
-- 8. INVESTIGATION → PHENOTYPE
-- =============================================================================

CREATE TABLE knowledge.investigation_phenotype (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   phenotype_id          uuid NOT NULL
                         REFERENCES knowledge.phenotype(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL DEFAULT 'characterizes'
                         CHECK (
                            relationship_type IN (
                               'characterizes',
                               'supports',
                               'contradicts',
                               'quantifies',
                               'severifies',
                               'monitors'
                            )
                         ),

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale             text,

   UNIQUE (
      investigation_id,
      phenotype_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.investigation_phenotype IS
'Links investigation results and investigations to reusable clinical phenotypes.';


-- =============================================================================
-- 9. INVESTIGATION → MECHANISM
-- =============================================================================

CREATE TABLE knowledge.investigation_mechanism (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   mechanism_id          uuid NOT NULL
                         REFERENCES knowledge.mechanism(id)
                         ON DELETE CASCADE,

   relationship_type     text NOT NULL DEFAULT 'evaluates'
                         CHECK (
                            relationship_type IN (
                               'evaluates',
                               'supports',
                               'contradicts',
                               'quantifies',
                               'monitors'
                            )
                         ),

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale             text,

   UNIQUE (
      investigation_id,
      mechanism_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.investigation_mechanism IS
'Links investigations to reusable pathophysiological mechanisms.';


-- =============================================================================
-- 10. INVESTIGATION SAFETY
-- =============================================================================

CREATE TABLE knowledge.investigation_safety (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id      uuid NOT NULL
                         REFERENCES knowledge.investigation(id)
                         ON DELETE CASCADE,

   safety_type           text NOT NULL
                         CHECK (
                            safety_type IN (
                               'contraindication',
                               'precaution',
                               'interaction',
                               'adverse_effect',
                               'radiation',
                               'specimen_risk',
                               'patient_risk'
                            )
                         ),

   concept_id            uuid REFERENCES knowledge.concept(id),

   code                  text NOT NULL,

   description           text NOT NULL,

   severity              text,

   action                text,

   UNIQUE (investigation_id, safety_type, code)
);

COMMENT ON TABLE knowledge.investigation_safety IS
'Universal safety knowledge for investigations. Safety is part of the clinical operating system, not an external note.';


-- =============================================================================
-- 11. INVESTIGATION ALTERNATIVES / DEPENDENCIES
-- =============================================================================

CREATE TABLE knowledge.investigation_relationship (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_investigation_id uuid NOT NULL
                            REFERENCES knowledge.investigation(id)
                            ON DELETE CASCADE,

   target_investigation_id uuid NOT NULL
                            REFERENCES knowledge.investigation(id)
                            ON DELETE CASCADE,

   relationship_type     text NOT NULL
                         CHECK (
                            relationship_type IN (
                               'alternative_to',
                               'prerequisite_for',
                               'reflex_to',
                               'followed_by',
                               'supersedes',
                               'complements',
                               'confirms',
                               'requires'
                            )
                         ),

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale             text,

   CHECK (
      source_investigation_id <> target_investigation_id
   ),

   UNIQUE (
      source_investigation_id,
      target_investigation_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.investigation_relationship IS
'Typed relationships between investigations, allowing reflex testing, alternatives, prerequisites and complementary investigations.';


-- =============================================================================
-- 12. EXAMINATION MODULE
-- =============================================================================
-- Examination is structured data, not free-text documentation.
--
-- Respiratory:
--   inspection
--   respiratory rate
--   oxygen saturation
--   palpation
--   percussion
--   auscultation
--
-- Cardiac:
--   pulse
--   JVP
--   precordium
--   heart sounds
--   murmurs
--   peripheral perfusion
--
-- The findings all enter the SAME fact substrate as history and investigations.
-- =============================================================================

CREATE TABLE knowledge.examination_module (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   concept_id            uuid REFERENCES knowledge.concept(id),

   module_code           text NOT NULL UNIQUE,
   canonical_name        text NOT NULL,
   display_name          text,

   description           text,

   body_system_code      text REFERENCES knowledge.body_system(code),

   examination_domain    text
                         CHECK (
                            examination_domain IS NULL OR
                            examination_domain IN (
                               'general',
                               'vital_signs',
                               'respiratory',
                               'cardiovascular',
                               'gastrointestinal',
                               'neurological',
                               'musculoskeletal',
                               'genitourinary',
                               'obstetric',
                               'gynaecological',
                               'paediatric',
                               'neonatal',
                               'dermatological',
                               'ENT',
                               'ophthalmological',
                               'psychiatric',
                               'vascular',
                               'breast',
                               'endocrine',
                               'other'
                            )
                         ),

   sort_order            integer NOT NULL DEFAULT 0,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.examination_module IS
'Universal structured examination module. Examination modules are reusable across diseases and specialties.';

CREATE INDEX idx_knowledge_exam_module_concept
   ON knowledge.examination_module(concept_id);

CREATE INDEX idx_knowledge_exam_module_system
   ON knowledge.examination_module(body_system_code);

CREATE INDEX idx_knowledge_exam_module_domain
   ON knowledge.examination_module(examination_domain);

CREATE TRIGGER trg_knowledge_examination_module_updated_at
   BEFORE UPDATE ON knowledge.examination_module
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 13. EXAMINATION SECTIONS
-- =============================================================================
-- Allows a module to have clinically meaningful ordered sections.
--
-- Respiratory:
--   General inspection
--   Vitals
--   Hands
--   Face
--   Neck
--   Chest inspection
--   Palpation
--   Percussion
--   Auscultation
-- =============================================================================

CREATE TABLE knowledge.examination_section (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   module_id             uuid NOT NULL
                         REFERENCES knowledge.examination_module(id)
                         ON DELETE CASCADE,

   section_code          text NOT NULL,
   canonical_name        text NOT NULL,
   description           text,

   sort_order            integer NOT NULL DEFAULT 0,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (module_id, section_code)
);

COMMENT ON TABLE knowledge.examination_section IS
'Ordered clinical sections within an examination module.';


-- =============================================================================
-- 14. EXAMINATION FINDINGS
-- =============================================================================

CREATE TABLE knowledge.examination_finding (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   module_id             uuid NOT NULL
                         REFERENCES knowledge.examination_module(id)
                         ON DELETE CASCADE,

   section_id            uuid
                         REFERENCES knowledge.examination_section(id)
                         ON DELETE SET NULL,

   concept_id            uuid REFERENCES knowledge.concept(id),

   finding_code          text NOT NULL,
   canonical_name        text NOT NULL,
   display_name          text,

   description           text,

   fact_definition_code  text
                         REFERENCES clinical.fact_definition(code),

   parent_finding_id     uuid
                         REFERENCES knowledge.examination_finding(id),

   finding_type          text NOT NULL DEFAULT 'observation'
                         CHECK (
                            finding_type IN (
                               'observation',
                               'measurement',
                               'sign',
                               'maneuver',
                               'inspection',
                               'palpation',
                               'percussion',
                               'auscultation',
                               'neurological',
                               'functional'
                            )
                         ),

   value_type            text NOT NULL DEFAULT 'boolean'
                         CHECK (
                            value_type IN (
                               'boolean',
                               'numeric',
                               'integer',
                               'single_choice',
                               'multiple_choice',
                               'text',
                               'coded'
                            )
                         ),

   unit                  text,

   required              boolean NOT NULL DEFAULT false,

   sort_order            integer NOT NULL DEFAULT 0,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (module_id, finding_code)
);

COMMENT ON TABLE knowledge.examination_finding IS
'Structured examination finding. Every clinically meaningful finding can map into the universal fact substrate used by reasoning.';

CREATE INDEX idx_knowledge_exam_finding_module
   ON knowledge.examination_finding(module_id);

CREATE INDEX idx_knowledge_exam_finding_section
   ON knowledge.examination_finding(section_id);

CREATE INDEX idx_knowledge_exam_finding_fact
   ON knowledge.examination_finding(fact_definition_code);

CREATE INDEX idx_knowledge_exam_finding_concept
   ON knowledge.examination_finding(concept_id);

CREATE INDEX idx_knowledge_exam_finding_parent
   ON knowledge.examination_finding(parent_finding_id);


-- =============================================================================
-- 15. EXAMINATION FINDING OPTIONS
-- =============================================================================
-- Structured alternatives prevent examination data from becoming arbitrary
-- strings.
--
-- Example:
-- FIND-CHEST-PERCUSSION
--   RESONANT
--   DULL
--   STONY_DULL
--   HYPERRESONANT
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.examination_finding_option CASCADE;
CREATE TABLE knowledge.examination_finding_option (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   finding_id            uuid NOT NULL
                         REFERENCES knowledge.examination_finding(id)
                         ON DELETE CASCADE,

   option_code           text NOT NULL,
   label                 text NOT NULL,

   fact_definition_code  text
                         REFERENCES clinical.fact_definition(code),

   value                 jsonb,

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative','neutral')),

   severity              text,

   sort_order            integer NOT NULL DEFAULT 0,

   is_active             boolean NOT NULL DEFAULT true,

   UNIQUE (finding_id, option_code)
);

COMMENT ON TABLE knowledge.examination_finding_option IS
'Structured examination responses mapped directly to universal clinical facts.';


-- =============================================================================
-- 16. EXAMINATION MEASUREMENT DEFINITIONS
-- =============================================================================
-- Measurements require explicit units and physiological meaning.
-- =============================================================================

CREATE TABLE knowledge.examination_measurement (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   finding_id            uuid NOT NULL
                         REFERENCES knowledge.examination_finding(id)
                         ON DELETE CASCADE,

   measurement_code      text NOT NULL UNIQUE,

   unit                  text NOT NULL,

   minimum_plausible     numeric,
   maximum_plausible     numeric,

   normality_mode        text
                         CHECK (
                            normality_mode IS NULL OR
                            normality_mode IN (
                               'reference_range',
                               'threshold',
                               'contextual',
                               'none'
                            )
                         ),

   fact_definition_code  text
                         REFERENCES clinical.fact_definition(code),

   description           text
);

COMMENT ON TABLE knowledge.examination_measurement IS
'Measurement metadata for examination findings such as temperature, respiratory rate, pulse, blood pressure, SpO2, MUAC and GCS.';


-- =============================================================================
-- 17. EXAMINATION REFERENCE RANGES
-- =============================================================================
-- Like laboratory values, examination measurements are context dependent.
-- =============================================================================

CREATE TABLE knowledge.examination_reference_range (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   measurement_id        uuid NOT NULL
                         REFERENCES knowledge.examination_measurement(id)
                         ON DELETE CASCADE,

   context_type_code     text REFERENCES knowledge.context_type(code),
   context_value_id      uuid REFERENCES knowledge.context_value(id),

   lower_value           numeric,
   upper_value           numeric,

   lower_inclusive       boolean NOT NULL DEFAULT true,
   upper_inclusive       boolean NOT NULL DEFAULT true,

   unit                  text,

   interpretation_code   text,

   source                 text,
   source_version        text,

   effective_from        date,
   effective_to          date,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   CHECK (
      lower_value IS NULL
      OR upper_value IS NULL
      OR lower_value <= upper_value
   )
);

COMMENT ON TABLE knowledge.examination_reference_range IS
'Context-sensitive reference ranges for physical examination measurements.';


-- =============================================================================
-- 18. EXAMINATION FINDING INTERPRETATION
-- =============================================================================
-- Allows a raw examination observation to generate a standardized fact.
--
-- Example:
-- RR = 68/min in a child
--       ↓
-- FACT-TACHYPNOEA
--
-- SpO2 = 84%
--       ↓
-- FACT-HYPOXAEMIA
-- =============================================================================

CREATE TABLE knowledge.examination_interpretation (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   finding_id            uuid NOT NULL
                         REFERENCES knowledge.examination_finding(id)
                         ON DELETE CASCADE,

   interpretation_code   text NOT NULL,

   operator              text NOT NULL
                         CHECK (
                            operator IN (
                               'eq',
                               'neq',
                               'gt',
                               'gte',
                               'lt',
                               'lte',
                               'between',
                               'in',
                               'contains',
                               'exists'
                            )
                         ),

   value                 jsonb,

   result_fact_code      text
                         REFERENCES clinical.fact_definition(code),

   result_concept_id     uuid
                         REFERENCES knowledge.concept(id),

   polarity              text NOT NULL DEFAULT 'positive'
                         CHECK (polarity IN ('positive','negative')),

   severity              text,

   weight                numeric(5,2) NOT NULL DEFAULT 1.0,

   interpretation_text   text,

   priority              integer NOT NULL DEFAULT 0,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   UNIQUE (finding_id, interpretation_code)
);

COMMENT ON TABLE knowledge.examination_interpretation IS
'Machine-readable interpretation of examination observations into universal facts, findings, severity markers and phenotypes.';


-- =============================================================================
-- 19. EXAMINATION MANEUVERS
-- =============================================================================
-- Some findings arise from an explicit clinical maneuver rather than passive
-- observation: JVP assessment, shifting dullness, rebound tenderness,
-- Romberg, reflexes, respiratory expansion, etc.
-- =============================================================================

CREATE TABLE knowledge.examination_maneuver (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   finding_id            uuid NOT NULL
                         REFERENCES knowledge.examination_finding(id)
                         ON DELETE CASCADE,

   maneuver_code         text NOT NULL UNIQUE,
   canonical_name        text NOT NULL,

   technique             text,
   patient_position      text,
   instruction           text,

   positive_finding      text,
   negative_finding      text,

   interpretation        text,

   safety_notes          text,

   sort_order            integer NOT NULL DEFAULT 0
);

COMMENT ON TABLE knowledge.examination_maneuver IS
'Structured clinical maneuvers with technique, position, expected observations and interpretation.';


-- =============================================================================
-- 20. EXAMINATION MODULE → CONDITION
-- =============================================================================

CREATE TABLE knowledge.examination_condition (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   examination_module_id    uuid NOT NULL
                            REFERENCES knowledge.examination_module(id)
                            ON DELETE CASCADE,

   condition_id             uuid NOT NULL
                            REFERENCES knowledge.condition(id)
                            ON DELETE CASCADE,

   relationship_type        text NOT NULL DEFAULT 'relevant'
                            CHECK (
                               relationship_type IN (
                                  'routine',
                                  'relevant',
                                  'supportive',
                                  'severity',
                                  'staging',
                                  'complication',
                                  'monitoring'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale                text,

   priority                 integer NOT NULL DEFAULT 0,

   UNIQUE (
      examination_module_id,
      condition_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.examination_condition IS
'Associates examination modules with conditions while keeping the examination universal and reusable.';


-- =============================================================================
-- 21. EXAMINATION MODULE → SYMPTOM
-- =============================================================================

CREATE TABLE knowledge.examination_symptom (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   examination_module_id    uuid NOT NULL
                            REFERENCES knowledge.examination_module(id)
                            ON DELETE CASCADE,

   symptom_id               uuid NOT NULL
                            REFERENCES knowledge.symptom(id)
                            ON DELETE CASCADE,

   relationship_type        text NOT NULL DEFAULT 'evaluates'
                            CHECK (
                               relationship_type IN (
                                  'evaluates',
                                  'supports',
                                  'excludes',
                                  'severity',
                                  'complication',
                                  'monitoring'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale                text,

   UNIQUE (
      examination_module_id,
      symptom_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.examination_symptom IS
'Associates examination modules with presenting symptoms without creating symptom-specific examination engines.';


-- =============================================================================
-- 22. EXAMINATION MODULE → PHENOTYPE
-- =============================================================================

CREATE TABLE knowledge.examination_phenotype (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   examination_module_id    uuid NOT NULL
                            REFERENCES knowledge.examination_module(id)
                            ON DELETE CASCADE,

   phenotype_id             uuid NOT NULL
                            REFERENCES knowledge.phenotype(id)
                            ON DELETE CASCADE,

   relationship_type        text NOT NULL DEFAULT 'characterizes'
                            CHECK (
                               relationship_type IN (
                                  'characterizes',
                                  'supports',
                                  'contradicts',
                                  'severity',
                                  'staging',
                                  'monitoring'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale                text,

   UNIQUE (
      examination_module_id,
      phenotype_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.examination_phenotype IS
'Connects structured examination modules to reusable phenotypes.';


-- =============================================================================
-- 23. EXAMINATION FINDING RELATIONSHIPS
-- =============================================================================
-- Allows findings to represent combinations without duplicating disease logic.
--
-- Examples:
-- bronchial breathing + crackles
-- raised JVP + peripheral oedema
-- meningism + altered consciousness
-- =============================================================================

CREATE TABLE knowledge.examination_finding_relationship (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_finding_id        uuid NOT NULL
                            REFERENCES knowledge.examination_finding(id)
                            ON DELETE CASCADE,

   target_finding_id        uuid NOT NULL
                            REFERENCES knowledge.examination_finding(id)
                            ON DELETE CASCADE,

   relationship_type        text NOT NULL
                            CHECK (
                               relationship_type IN (
                                  'associated_with',
                                  'supports',
                                  'contradicts',
                                  'precedes',
                                  'follows',
                                  'commonly_coexists',
                                  'differentiates'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale                text,

   CHECK (
      source_finding_id <> target_finding_id
   ),

   UNIQUE (
      source_finding_id,
      target_finding_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.examination_finding_relationship IS
'Typed relationships between examination findings. These relationships are reusable across conditions.';


-- =============================================================================
-- 24. UNIVERSAL EXAMINATION SAFETY
-- =============================================================================

CREATE TABLE knowledge.examination_safety (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   module_id                uuid
                            REFERENCES knowledge.examination_module(id)
                            ON DELETE CASCADE,

   finding_id               uuid
                            REFERENCES knowledge.examination_finding(id)
                            ON DELETE CASCADE,

   safety_type              text NOT NULL
                            CHECK (
                               safety_type IN (
                                  'contraindication',
                                  'precaution',
                                  'infection_control',
                                  'patient_risk',
                                  'positioning_risk',
                                  'procedure_risk'
                               )
                            ),

   code                     text NOT NULL,

   description              text NOT NULL,

   action                   text,

   severity                 text
);

COMMENT ON TABLE knowledge.examination_safety IS
'Universal safety constraints for examination modules and maneuvers.';


-- =============================================================================
-- 25. EXAMINATION DOCUMENTATION
-- =============================================================================
-- Structured findings can render into clinical documentation without making
-- documentation itself the source of truth.
-- =============================================================================

CREATE TABLE knowledge.examination_documentation (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   finding_id               uuid NOT NULL
                            REFERENCES knowledge.examination_finding(id)
                            ON DELETE CASCADE,

   phrase                   text NOT NULL,

   language_code            text,

   context_code             text,

   is_preferred             boolean NOT NULL DEFAULT false,

   UNIQUE (
      finding_id,
      phrase,
      language_code
   )
);

COMMENT ON TABLE knowledge.examination_documentation IS
'Canonical clinical documentation phrases generated from structured examination findings.';


-- =============================================================================
-- 26. UNIVERSAL INVESTIGATION ↔ EXAMINATION RELATIONSHIPS
-- =============================================================================
-- Allows the operating system to connect bedside findings to appropriate
-- investigations without embedding the logic in a disease-specific engine.
-- =============================================================================

CREATE TABLE knowledge.examination_investigation (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   finding_id               uuid NOT NULL
                            REFERENCES knowledge.examination_finding(id)
                            ON DELETE CASCADE,

   investigation_id         uuid NOT NULL
                            REFERENCES knowledge.investigation(id)
                            ON DELETE CASCADE,

   relationship_type        text NOT NULL
                            CHECK (
                               relationship_type IN (
                                  'supports',
                                  'confirms',
                                  'evaluates',
                                  'quantifies',
                                  'excludes',
                                  'severity',
                                  'monitoring'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   rationale                text,

   UNIQUE (
      finding_id,
      investigation_id,
      relationship_type
   )
);

COMMENT ON TABLE knowledge.examination_investigation IS
'Connects examination findings to investigations through reusable clinical relationships.';


-- =============================================================================
-- 27. UNIVERSAL PRIMITIVE → BODY SYSTEM
-- =============================================================================
-- Ensures new investigation/examination primitives can participate in the
-- universal concept graph without creating duplicate system-specific entities.
-- =============================================================================

CREATE TABLE knowledge.investigation_system (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_id         uuid NOT NULL
                            REFERENCES knowledge.investigation(id)
                            ON DELETE CASCADE,

   body_system_code         text NOT NULL
                            REFERENCES knowledge.body_system(code),

   relevance                text NOT NULL DEFAULT 'related'
                            CHECK (
                               relevance IN (
                                  'primary',
                                  'secondary',
                                  'cross_system',
                                  'related'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   UNIQUE (
      investigation_id,
      body_system_code
   )
);

COMMENT ON TABLE knowledge.investigation_system IS
'Universal multi-system attachment for investigations.';


CREATE TABLE knowledge.examination_module_system (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   examination_module_id    uuid NOT NULL
                            REFERENCES knowledge.examination_module(id)
                            ON DELETE CASCADE,

   body_system_code         text NOT NULL
                            REFERENCES knowledge.body_system(code),

   relevance                text NOT NULL DEFAULT 'primary'
                            CHECK (
                               relevance IN (
                                  'primary',
                                  'secondary',
                                  'cross_system',
                                  'related'
                               )
                            ),

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   UNIQUE (
      examination_module_id,
      body_system_code
   )
);

COMMENT ON TABLE knowledge.examination_module_system IS
'Universal multi-system attachment for examination modules.';


-- =============================================================================
-- 28. KNOWLEDGE GRAPH EDGES
-- =============================================================================
-- Investigation and examination nodes participate in the same universal graph.
-- =============================================================================

CREATE TABLE knowledge.investigation_relationship_edge (
   id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   source_type              text NOT NULL
                            CHECK (
                               source_type IN (
                                  'investigation',
                                  'investigation_component',
                                  'examination_module',
                                  'examination_finding'
                               )
                            ),

   source_id                uuid NOT NULL,

   relationship_type        text NOT NULL,

   target_type              text NOT NULL
                            CHECK (
                               target_type IN (
                                  'concept',
                                  'fact',
                                  'symptom',
                                  'finding',
                                  'phenotype',
                                  'mechanism',
                                  'condition',
                                  'investigation',
                                  'examination_module',
                                  'examination_finding'
                               )
                            ),

   target_id                uuid NOT NULL,

   weight                   numeric(5,2) NOT NULL DEFAULT 1.0,

   polarity                 text NOT NULL DEFAULT 'positive'
                            CHECK (
                               polarity IN ('positive','negative')
                            ),

   context                  jsonb,

   confidence               numeric(4,3)
                            CHECK (
                               confidence IS NULL
                               OR confidence BETWEEN 0 AND 1
                            ),

   evidence                 text,

   is_active                boolean NOT NULL DEFAULT true,

   created_at               timestamptz NOT NULL DEFAULT now(),

   UNIQUE (
      source_type,
      source_id,
      relationship_type,
      target_type,
      target_id,
      context,
      polarity
   )
);

COMMENT ON TABLE knowledge.investigation_relationship_edge IS
'Investigation and examination edges participating in the AMEXAN clinical knowledge graph.';


CREATE INDEX idx_investigation_edge_source
   ON knowledge.investigation_relationship_edge(source_type, source_id);

CREATE INDEX idx_investigation_edge_target
   ON knowledge.investigation_relationship_edge(target_type, target_id);

CREATE INDEX idx_investigation_edge_type
   ON knowledge.investigation_relationship_edge(relationship_type);


-- =============================================================================
-- 29. PERFORMANCE INDEXES FOR THE CLINICAL CPU
-- =============================================================================

CREATE INDEX idx_investigation_condition_condition
   ON knowledge.investigation_condition(condition_id);

CREATE INDEX idx_investigation_symptom_symptom
   ON knowledge.investigation_symptom(symptom_id);

CREATE INDEX idx_investigation_phenotype_phenotype
   ON knowledge.investigation_phenotype(phenotype_id);

CREATE INDEX idx_investigation_mechanism_mechanism
   ON knowledge.investigation_mechanism(mechanism_id);

CREATE INDEX idx_examination_condition_condition
   ON knowledge.examination_condition(condition_id);

CREATE INDEX idx_examination_symptom_symptom
   ON knowledge.examination_symptom(symptom_id);

CREATE INDEX idx_examination_phenotype_phenotype
   ON knowledge.examination_phenotype(phenotype_id);

CREATE INDEX idx_examination_finding_option_fact
   ON knowledge.examination_finding_option(fact_definition_code);

CREATE INDEX idx_examination_interpretation_fact
   ON knowledge.examination_interpretation(result_fact_code);


-- =============================================================================
-- 30. UPDATED-AT TRIGGERS
-- =============================================================================

CREATE TRIGGER trg_knowledge_examination_section_updated_at
   BEFORE UPDATE ON knowledge.examination_module
   FOR EACH ROW
   EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 31. UNIVERSAL CLINICAL FLOW VIEW
-- =============================================================================
-- This does not make diagnoses.
-- It exposes the primitive chain available to the clinical CPU:
--
-- symptom/fact
--      → examination
--      → finding
--      → fact
--      → phenotype/mechanism
--      → investigation
--      → condition
--
-- Rules remain responsible for deciding when a node is activated.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.clinical_primitive_catalog AS
SELECT
   'investigation'::text AS primitive_type,
   i.id,
   i.investigation_code AS code,
   i.canonical_name AS name,
   i.status
FROM knowledge.investigation i

UNION ALL

SELECT
   'examination_module'::text AS primitive_type,
   e.id,
   e.module_code AS code,
   e.canonical_name AS name,
   e.status
FROM knowledge.examination_module e

UNION ALL

SELECT
   'examination_finding'::text AS primitive_type,
   f.id,
   f.finding_code AS code,
   f.canonical_name AS name,
   f.status
FROM knowledge.examination_finding f;

COMMENT ON VIEW knowledge.clinical_primitive_catalog IS
'Fast catalog of universal clinical examination and investigation primitives available to the AMEXAN Clinical CPU.';


-- =============================================================================
-- 32. DESIGN INVARIANTS
-- =============================================================================
-- 1. An investigation is never recreated because a disease uses it.
-- 2. An examination finding is never recreated because another specialty uses it.
-- 3. Raw observations are converted into universal facts.
-- 4. Context determines interpretation.
-- 5. Rules determine activation.
-- 6. Phenotypes and mechanisms provide reusable intermediate reasoning layers.
-- 7. Conditions consume the same substrate rather than owning private logic.
-- 8. Investigation safety is represented as knowledge.
-- 9. Examination safety is represented as knowledge.
-- 10. Structured data remains the source of truth; documentation is rendering.
-- 11. History, examination and investigation all converge on the same fact layer.
-- 12. The same primitive can serve paediatrics, adult medicine, surgery,
--     OBGYN, emergency medicine, ICU, primary care and subspecialties.
-- =============================================================================
