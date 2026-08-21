-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP4: Comprehensive condition graph
-- =============================================================================
--
-- PURPOSE
-- -------
-- This seed completes and substantially expands the condition layer for the
-- Phase 2 MVP clinical knowledge graph.
--
-- PRINCIPLE
-- ---------
-- AMEXAN does NOT reason:
--
--      symptom -> disease
--
-- Instead:
--
--      symptom
--        -> clinical fact
--        -> phenotype
--        -> mechanism
--        -> candidate condition
--        -> differential discrimination
--        -> investigation
--        -> interpretation
--        -> diagnostic state
--        -> management
--        -> monitoring
--
-- This seed therefore:
--
-- 1. Creates Asthma, Heart Failure and GERD.
-- 2. Connects each condition to its systems and specialties.
-- 3. Adds clinically meaningful risk factors.
-- 4. Adds complications.
-- 5. Adds differential relationships.
-- 6. Connects mechanisms <-> phenotypes <-> conditions.
-- 7. Connects mechanisms to investigations.
-- 8. Connects conditions to core symptoms.
-- 9. Adds high-value clinical relationships.
-- 10. Expands the universal concept graph for chest pain, abdominal pain,
--     asthma, heart failure, GERD and relevant clinical findings.
--
-- IMPORTANT
-- ---------
-- Disease ownership is deliberately avoided for reusable mechanisms and
-- phenotypes. A mechanism or phenotype can participate in many conditions.
--
-- Existing CAP/TB conditions and their relationships are preserved.
--
-- =============================================================================


-- =============================================================================
-- 1. CONDITIONS
-- =============================================================================

INSERT INTO knowledge.condition
(
    id,
    concept_id,
    condition_code,
    canonical_name,
    description,
    condition_type
)
VALUES

(
    'f1000000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000019',
    'ASTHMA',
    'Asthma',
    'A chronic inflammatory airway disease characterized by variable respiratory symptoms and variable expiratory airflow limitation.',
    'chronic'
),

(
    'f1000000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-00000000001a',
    'HEART_FAILURE',
    'Heart failure',
    'A clinical syndrome caused by structural and/or functional cardiac abnormality resulting in elevated intracardiac pressures, inadequate cardiac output, or both.',
    'chronic'
),

(
    'f1000000-0000-0000-0000-000000000006',
    'f0a00000-0000-0000-0000-00000000001b',
    'GERD',
    'Gastroesophageal reflux disease',
    'A disorder in which reflux of gastric contents causes troublesome symptoms and/or complications.',
    'chronic'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. CONDITION -> BODY SYSTEM
-- =============================================================================
--
-- A condition may legitimately belong to multiple systems.
-- The weight describes relevance, not probability.
--
-- =============================================================================

INSERT INTO knowledge.condition_system
(
    condition_id,
    body_system_code,
    weight
)
VALUES

-- ASTHMA
(
    'f1000000-0000-0000-0000-000000000004',
    'RESPIRATORY',
    1.0
),

-- HEART FAILURE
(
    'f1000000-0000-0000-0000-000000000005',
    'CARDIOVASCULAR',
    1.0
),
(
    'f1000000-0000-0000-0000-000000000005',
    'RESPIRATORY',
    0.7
),

-- GERD
(
    'f1000000-0000-0000-0000-000000000006',
    'GASTROINTESTINAL',
    1.0
),
(
    'f1000000-0000-0000-0000-000000000006',
    'RESPIRATORY',
    0.3
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. CONDITION -> SPECIALTY
-- =============================================================================

INSERT INTO knowledge.condition_specialty
(
    condition_id,
    specialty_code,
    weight
)
VALUES

-- ASTHMA
(
    'f1000000-0000-0000-0000-000000000004',
    'pulmonology',
    1.0
),
(
    'f1000000-0000-0000-0000-000000000004',
    'family_medicine',
    0.9
),
(
    'f1000000-0000-0000-0000-000000000004',
    'paediatrics',
    0.8
),
(
    'f1000000-0000-0000-0000-000000000004',
    'emergency_medicine',
    0.9
),
(
    'f1000000-0000-0000-0000-000000000004',
    'internal_medicine',
    0.8
),

-- HEART FAILURE
(
    'f1000000-0000-0000-0000-000000000005',
    'cardiology',
    1.0
),
(
    'f1000000-0000-0000-0000-000000000005',
    'internal_medicine',
    0.9
),
(
    'f1000000-0000-0000-0000-000000000005',
    'emergency_medicine',
    0.9
),
(
    'f1000000-0000-0000-0000-000000000005',
    'family_medicine',
    0.7
),

-- GERD
(
    'f1000000-0000-0000-0000-000000000006',
    'gastroenterology',
    1.0
),
(
    'f1000000-0000-0000-0000-000000000006',
    'family_medicine',
    0.9
),
(
    'f1000000-0000-0000-0000-000000000006',
    'internal_medicine',
    0.7
),
(
    'f1000000-0000-0000-0000-000000000006',
    'pulmonology',
    0.4
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. ASTHMA RISK FACTORS
-- =============================================================================
--
-- Only risk-factor concepts already established by the existing Phase 2
-- vocabulary are used here.
--
-- =============================================================================

INSERT INTO knowledge.condition_risk_factor
(
    condition_id,
    risk_factor_concept_id,
    risk_factor_code,
    weight,
    description
)
VALUES

(
    'f1000000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000007',
    'SMOKING',
    0.6,
    'Active or passive tobacco smoke exposure may worsen asthma control and airway inflammation.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. HEART FAILURE RISK FACTORS
-- =============================================================================

INSERT INTO knowledge.condition_risk_factor
(
    condition_id,
    risk_factor_concept_id,
    risk_factor_code,
    weight,
    description
)
VALUES

(
    'f1000000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000007',
    'SMOKING',
    0.6,
    'Tobacco exposure increases cardiovascular disease risk and may contribute to heart failure.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. ASTHMA COMPLICATIONS
-- =============================================================================

INSERT INTO knowledge.condition_complication
(
    condition_id,
    complication_concept_id,
    complication_code,
    probability_weight,
    description
)
VALUES

(
    'f1000000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000015',
    'RESPIRATORY_FAILURE',
    0.7,
    'Severe or life-threatening asthma may progress to respiratory failure.'
),

(
    'f1000000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-000000000016',
    'HYPOXAEMIA',
    0.6,
    'Severe airflow obstruction and ventilation-perfusion mismatch may cause hypoxaemia.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. HEART FAILURE COMPLICATIONS
-- =============================================================================

INSERT INTO knowledge.condition_complication
(
    condition_id,
    complication_concept_id,
    complication_code,
    probability_weight,
    description
)
VALUES

(
    'f1000000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000016',
    'HYPOXAEMIA',
    0.8,
    'Pulmonary congestion or oedema may impair gas exchange and cause hypoxaemia.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. HEART FAILURE DIFFERENTIALS
-- =============================================================================
--
-- The differential layer represents clinical discrimination.
-- It does NOT mean that every listed condition is equally likely.
--
-- =============================================================================

INSERT INTO knowledge.condition_differential
(
    condition_id,
    differential_condition_id,
    relationship_type,
    weight
)
VALUES

-- Heart failure versus CAP
(
    'f1000000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    'mimics',
    0.5
),

-- Heart failure versus TB/chronic pulmonary disease
(
    'f1000000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000002',
    'differentiates',
    0.4
),

-- Asthma versus CAP
(
    'f1000000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000001',
    'overlaps',
    0.5
),

-- Asthma versus TB/chronic respiratory disease
(
    'f1000000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000002',
    'differentiates',
    0.6
),

-- GERD versus TB/chronic cough
(
    'f1000000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000002',
    'differentiates',
    0.4
),

-- GERD versus CAP
(
    'f1000000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000001',
    'differentiates',
    0.3
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. MECHANISM -> PHENOTYPE
-- =============================================================================

INSERT INTO knowledge.mechanism_phenotype
(
    mechanism_id,
    phenotype_id,
    weight
)
VALUES

-- Granulomatous pulmonary infection -> existing chronic pulmonary phenotype
(
    'f0e00000-0000-0000-0000-000000000005',
    'f0f00000-0000-0000-0000-000000000002',
    0.9
),

-- Pulmonary congestion -> CHF congestive phenotype
(
    'f0e00000-0000-0000-0000-000000000006',
    'f0f00000-0000-0000-0000-000000000101',
    1.0
),

-- Gastroesophageal reflux -> reflux cough phenotype
(
    'f0e00000-0000-0000-0000-000000000007',
    'f0f00000-0000-0000-0000-000000000102',
    1.0
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. MECHANISM -> CONDITION
-- =============================================================================

INSERT INTO knowledge.mechanism_condition
(
    mechanism_id,
    condition_id,
    weight
)
VALUES

-- Granulomatous infection -> TB/chronic pulmonary condition
(
    'f0e00000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000002',
    1.0
),

-- Pulmonary congestion -> Heart failure
(
    'f0e00000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000005',
    1.0
),

-- GER -> GERD
(
    'f0e00000-0000-0000-0000-000000000007',
    'f1000000-0000-0000-0000-000000000006',
    1.0
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. MECHANISM -> INVESTIGATION
-- =============================================================================

INSERT INTO knowledge.mechanism_investigation
(
    mechanism_id,
    investigation_concept_id,
    investigation_code,
    weight,
    rationale
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000006',
    'f0a00000-0000-0000-0000-000000000012',
    'INV-CXR',
    0.9,
    'Chest radiography may demonstrate pulmonary vascular congestion, interstitial oedema, alveolar oedema, cardiomegaly or alternative pulmonary pathology.'
),

(
    'f0e00000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000013',
    'INV-SPUTUM-AFB',
    1.0,
    'Sputum testing is appropriate when chronic granulomatous pulmonary infection such as tuberculosis is clinically suspected.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 12. PHENOTYPE -> CONDITION
-- =============================================================================

INSERT INTO knowledge.phenotype_differential
(
    phenotype_id,
    condition_id,
    relationship_type,
    weight
)
VALUES

-- Airway-wheeze phenotype
(
    'f0f00000-0000-0000-0000-000000000100',
    'f1000000-0000-0000-0000-000000000004',
    'suggestive_of',
    0.9
),

-- Congestive phenotype
(
    'f0f00000-0000-0000-0000-000000000101',
    'f1000000-0000-0000-0000-000000000005',
    'associated',
    0.9
),

-- Congestive phenotype may overlap pneumonia
(
    'f0f00000-0000-0000-0000-000000000101',
    'f1000000-0000-0000-0000-000000000001',
    'suggestive_of',
    0.3
),

-- Reflux cough phenotype
(
    'f0f00000-0000-0000-0000-000000000102',
    'f1000000-0000-0000-0000-000000000006',
    'suggestive_of',
    0.9
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. CONDITION -> PHENOTYPE
-- =============================================================================

INSERT INTO knowledge.condition_phenotype
(
    condition_id,
    phenotype_id,
    weight,
    is_suggestive
)
VALUES

(
    'f1000000-0000-0000-0000-000000000004',
    'f0f00000-0000-0000-0000-000000000100',
    0.9,
    true
),

(
    'f1000000-0000-0000-0000-000000000005',
    'f0f00000-0000-0000-0000-000000000101',
    0.9,
    true
),

(
    'f1000000-0000-0000-0000-000000000006',
    'f0f00000-0000-0000-0000-000000000102',
    0.9,
    true
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 14. CONDITION -> MECHANISM
-- =============================================================================

-- Gastroesophageal reflux mechanism (referenced by the GERD junction below)
INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES
(
    'f0e00000-0000-0000-0000-00000000006f',
    NULL,
    'MECH-GASTROESOPHAGEAL-REFLUX',
    'Gastroesophageal reflux',
    'Retrograde flow of gastric contents into the oesophagus causing mucosal injury and symptoms.',
    'GASTROINTESTINAL'
)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES
(
    'f0e00000-0000-0000-0000-00000000007a',
    NULL,
    'MECH-GRANULOMATOUS-INFECTION',
    'Granulomatous infection',
    'Chronic infection characterised by granuloma formation (e.g. pulmonary tuberculosis).',
    'RESPIRATORY'
)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_mechanism
(
    condition_id,
    mechanism_id,
    weight
)
VALUES

-- Asthma: variable airway obstruction/inflammation mechanisms already present
(
    'f1000000-0000-0000-0000-000000000004',
    'f0e00000-0000-0000-0000-000000000003',
    0.9
),

(
    'f1000000-0000-0000-0000-000000000004',
    'f0e00000-0000-0000-0000-000000000001',
    0.8
),

-- Heart failure -> pulmonary congestion
(
    'f1000000-0000-0000-0000-000000000005',
    'f0e00000-0000-0000-0000-000000000009',
    1.0
),

-- GERD -> gastroesophageal reflux
(
    'f1000000-0000-0000-0000-000000000006',
    'f0e00000-0000-0000-0000-00000000006f',
    1.0
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 15. ASTHMA — CORE CLINICAL RELATIONSHIPS
-- =============================================================================
--
-- These are associations, NOT deterministic diagnostic rules.
--
-- =============================================================================

INSERT INTO knowledge.relationship
(
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
)
VALUES

-- Asthma -> cough
(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'associated_with',
    'symptom',
    'f0b00000-0000-0000-0000-000000000001',
    0.8,
    'positive',
    0.9,
    'Asthma commonly causes cough, particularly nocturnal or episodic cough.'
),

-- Asthma -> dyspnoea
(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'associated_with',
    'symptom',
    'f0b00000-0000-0000-0000-000000000003',
    0.9,
    'positive',
    0.9,
    'Asthma commonly causes episodic breathlessness.'
),

-- Asthma -> wheeze
(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'associated_with',
    'concept',
    'f0a00000-0000-0000-0000-00000000003b',
    1.0,
    'positive',
    0.9,
    'Wheeze is a characteristic manifestation of variable airflow obstruction, although its absence does not exclude asthma.'
),

-- Asthma -> chest tightness
(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'associated_with',
    'concept',
    'f0a00000-0000-0000-0000-00000000003d',
    0.4,
    'positive',
    0.6,
    'Chest discomfort or tightness may occur during asthma symptoms.'
),

-- Heart failure -> dyspnoea
(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'associated_with',
    'symptom',
    'f0b00000-0000-0000-0000-000000000003',
    1.0,
    'positive',
    0.95,
    'Dyspnoea is a cardinal manifestation of heart failure, particularly with pulmonary congestion.'
),

-- Heart failure -> cough
(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'associated_with',
    'symptom',
    'f0b00000-0000-0000-0000-000000000001',
    0.5,
    'positive',
    0.7,
    'Heart failure may cause cough through pulmonary congestion.'
),

-- GERD -> cough
(
    'condition',
    'f1000000-0000-0000-0000-000000000006',
    'associated_with',
    'symptom',
    'f0b00000-0000-0000-0000-000000000001',
    0.6,
    'positive',
    0.7,
    'GERD can be associated with chronic cough, although other causes should be assessed.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 16. UNIVERSAL CONCEPT -> BODY SYSTEM GRAPH
-- =============================================================================
--
-- ONE CONCEPT
-- MANY SYSTEMS
-- NO DUPLICATE CONCEPTS
--
-- =============================================================================

INSERT INTO knowledge.concept_system
(
    concept_id,
    body_system_code,
    relevance,
    weight,
    description
)
VALUES

-- ---------------------------------------------------------------------------
-- CHEST PAIN
-- ---------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000017',
    'CARDIOVASCULAR',
    'primary',
    1.0,
    'Chest pain is a major cardiovascular presentation including potentially life-threatening acute coronary and aortic disease.'
),

(
    'f0a00000-0000-0000-0000-000000000017',
    'RESPIRATORY',
    'primary',
    1.0,
    'Pulmonary and pleural disease may produce chest pain, particularly pleuritic pain.'
),

(
    'f0a00000-0000-0000-0000-000000000017',
    'GASTROINTESTINAL',
    'secondary',
    0.5,
    'Oesophageal and gastroesophageal disease may produce retrosternal chest discomfort.'
),

(
    'f0a00000-0000-0000-0000-000000000017',
    'MUSCULOSKELETAL',
    'secondary',
    0.6,
    'Chest wall, muscle, rib and costochondral disorders may cause chest pain.'
),

-- ---------------------------------------------------------------------------
-- ABDOMINAL PAIN
-- ---------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000018',
    'GASTROINTESTINAL',
    'primary',
    1.0,
    'Abdominal pain is a major gastrointestinal presentation.'
),

(
    'f0a00000-0000-0000-0000-000000000018',
    'RENAL_URINARY',
    'secondary',
    0.7,
    'Renal and urinary tract disease may present with abdominal or flank pain.'
),

(
    'f0a00000-0000-0000-0000-000000000018',
    'REPRODUCTIVE',
    'secondary',
    0.6,
    'Gynaecological and reproductive disorders may present with abdominal or pelvic pain.'
),

-- ---------------------------------------------------------------------------
-- ASTHMA
-- ---------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000019',
    'RESPIRATORY',
    'primary',
    1.0,
    'Asthma is fundamentally a respiratory disease.'
),

-- ---------------------------------------------------------------------------
-- HEART FAILURE
-- ---------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000001a',
    'CARDIOVASCULAR',
    'primary',
    1.0,
    'Heart failure is a cardiovascular clinical syndrome.'
),

(
    'f0a00000-0000-0000-0000-00000000001a',
    'RESPIRATORY',
    'secondary',
    0.7,
    'Pulmonary congestion and oedema are major respiratory consequences of left-sided heart failure.'
),

-- ---------------------------------------------------------------------------
-- GERD
-- ---------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000001b',
    'GASTROINTESTINAL',
    'primary',
    1.0,
    'GERD is primarily an oesophageal/gastrointestinal disorder.'
),

(
    'f0a00000-0000-0000-0000-00000000001b',
    'RESPIRATORY',
    'related',
    0.3,
    'Reflux may be associated with respiratory symptoms such as chronic cough.'
),

-- ---------------------------------------------------------------------------
-- RESPIRATORY FINDINGS
-- ---------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000003b',
    'RESPIRATORY',
    'primary',
    1.0,
    'Wheeze is an auscultatory respiratory finding associated with airflow limitation.'
),

(
    'f0a00000-0000-0000-0000-00000000003c',
    'RESPIRATORY',
    'primary',
    1.0,
    'Crackles are an auscultatory respiratory finding occurring in multiple pulmonary and cardiac conditions.'
),

(
    'f0a00000-0000-0000-0000-00000000003d',
    'RESPIRATORY',
    'primary',
    1.0,
    'Pleuritic pain is a clinical characteristic of pain arising from pleural or adjacent inflammatory processes.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 17. UNIVERSAL CONCEPT -> SPECIALTY
-- =============================================================================

INSERT INTO knowledge.concept_specialty
(
    concept_id,
    specialty_code,
    relevance,
    weight,
    description
)
VALUES

-- CHEST PAIN
(
    'f0a00000-0000-0000-0000-000000000017',
    'emergency_medicine',
    'primary',
    1.0,
    'Potentially life-threatening causes of chest pain require emergency assessment.'
),

(
    'f0a00000-0000-0000-0000-000000000017',
    'cardiology',
    'primary',
    1.0,
    'Cardiovascular causes of chest pain require cardiac assessment.'
),

(
    'f0a00000-0000-0000-0000-000000000017',
    'pulmonology',
    'secondary',
    0.8,
    'Pulmonary causes include pulmonary embolism, pneumothorax, pneumonia and pleural disease.'
),

(
    'f0a00000-0000-0000-0000-000000000017',
    'gastroenterology',
    'secondary',
    0.4,
    'Oesophageal and reflux disease may produce retrosternal symptoms.'
),

-- ABDOMINAL PAIN
(
    'f0a00000-0000-0000-0000-000000000018',
    'emergency_medicine',
    'primary',
    1.0,
    'Acute abdominal pain may represent a surgical or other time-critical emergency.'
),

(
    'f0a00000-0000-0000-0000-000000000018',
    'gastroenterology',
    'primary',
    1.0,
    'Gastrointestinal disorders are major causes of abdominal pain.'
),

(
    'f0a00000-0000-0000-0000-000000000018',
    'surgery',
    'secondary',
    0.8,
    'Surgical causes include obstruction, perforation, appendicitis, ischemia and other acute abdominal emergencies.'
),

(
    'f0a00000-0000-0000-0000-000000000018',
    'obstetrics_gynaecology',
    'secondary',
    0.8,
    'Pelvic and reproductive causes must be considered in appropriate patients.'
),

-- ASTHMA
(
    'f0a00000-0000-0000-0000-000000000019',
    'pulmonology',
    'primary',
    1.0,
    'Asthma is routinely managed within respiratory medicine.'
),

(
    'f0a00000-0000-0000-0000-000000000019',
    'family_medicine',
    'primary',
    0.9,
    'Asthma is commonly diagnosed, treated and monitored in primary care.'
),

(
    'f0a00000-0000-0000-0000-000000000019',
    'paediatrics',
    'secondary',
    0.8,
    'Asthma is common in children and requires age-appropriate assessment.'
),

(
    'f0a00000-0000-0000-0000-000000000019',
    'emergency_medicine',
    'secondary',
    0.9,
    'Acute severe asthma may require emergency treatment.'
),

-- HEART FAILURE
(
    'f0a00000-0000-0000-0000-00000000001a',
    'cardiology',
    'primary',
    1.0,
    'Heart failure is a major cardiology condition.'
),

(
    'f0a00000-0000-0000-0000-00000000001a',
    'internal_medicine',
    'secondary',
    0.9,
    'Heart failure commonly presents to and is managed within general medicine.'
),

(
    'f0a00000-0000-0000-0000-00000000001a',
    'emergency_medicine',
    'secondary',
    0.9,
    'Acute pulmonary oedema, decompensation and cardiogenic shock require emergency management.'
),

-- GERD
(
    'f0a00000-0000-0000-0000-00000000001b',
    'gastroenterology',
    'primary',
    1.0,
    'GERD is a major gastroenterological condition.'
),

(
    'f0a00000-0000-0000-0000-00000000001b',
    'family_medicine',
    'secondary',
    0.9,
    'Most uncomplicated GERD can initially be assessed and managed in primary care.'
),

(
    'f0a00000-0000-0000-0000-00000000001b',
    'internal_medicine',
    'secondary',
    0.7,
    'Persistent, atypical or complicated reflux may require general medical assessment.'
),

(
    'f0a00000-0000-0000-0000-00000000001b',
    'pulmonology',
    'related',
    0.4,
    'Respiratory specialists may assess chronic cough or other respiratory presentations associated with reflux.'
),

-- FINDINGS
(
    'f0a00000-0000-0000-0000-00000000003b',
    'pulmonology',
    'primary',
    1.0,
    'Wheeze requires respiratory assessment in the appropriate clinical context.'
),

(
    'f0a00000-0000-0000-0000-00000000003c',
    'pulmonology',
    'primary',
    1.0,
    'Crackles require clinical interpretation within pulmonary and cardiac contexts.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 18. HIGH-VALUE CHEST PAIN KNOWLEDGE RELATIONSHIPS
-- =============================================================================
--
-- Chest pain is an emergency presentation until dangerous causes have been
-- considered. These are associations, not diagnostic shortcuts.
--
-- =============================================================================

INSERT INTO knowledge.relationship
(
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
)
VALUES

(
    'symptom',
    'f0b00000-0000-0000-0000-000000000007',
    'may_indicate',
    'concept',
    'f0a00000-0000-0000-0000-000000000017',
    1.0,
    'positive',
    1.0,
    'Chest pain is the presenting symptom represented by the chest-pain concept.'
),

(
    'concept',
    'f0a00000-0000-0000-0000-000000000017',
    'requires_consideration_of',
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    0.5,
    'positive',
    0.8,
    'Heart failure may produce chest discomfort through cardiac disease, although chest pain requires a broad differential.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 19. HIGH-VALUE ABDOMINAL PAIN KNOWLEDGE RELATIONSHIPS
-- =============================================================================

INSERT INTO knowledge.relationship
(
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
)
VALUES

(
    'symptom',
    'f0b00000-0000-0000-0000-000000000008',
    'may_indicate',
    'concept',
    'f0a00000-0000-0000-0000-000000000018',
    1.0,
    'positive',
    1.0,
    'Abdominal pain is the presenting symptom represented by the abdominal-pain concept.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 20. UNIVERSAL DIAGNOSTIC PRINCIPLE RELATIONSHIPS
-- =============================================================================
--
-- These relationships deliberately encode that findings have multiple possible
-- interpretations.
--
-- =============================================================================

INSERT INTO knowledge.relationship
(
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
)
VALUES

-- Wheeze does not belong exclusively to asthma.
(
    'concept',
    'f0a00000-0000-0000-0000-00000000003b',
    'associated_with',
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    0.8,
    'positive',
    0.9,
    'Wheeze is common in asthma but is not pathognomonic for asthma.'
),

-- Crackles occur in multiple conditions.
(
    'concept',
    'f0a00000-0000-0000-0000-00000000003c',
    'associated_with',
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    0.7,
    'positive',
    0.8,
    'Crackles may occur with pulmonary congestion in heart failure but are not specific to it.'
),

-- Pleuritic pain has respiratory relevance.
(
    'concept',
    'f0a00000-0000-0000-0000-00000000003d',
    'associated_with',
    'symptom',
    'f0b00000-0000-0000-0000-000000000007',
    0.7,
    'positive',
    0.8,
    'Pleuritic pain may accompany pulmonary or pleural pathology and requires contextual interpretation.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 21. CONDITION DOCUMENTATION RELATIONSHIPS
-- =============================================================================
--
-- The relationship graph remains separate from clinical documentation.
-- Documentation must never be interpreted as diagnosis by itself.
--
-- =============================================================================

INSERT INTO knowledge.relationship
(
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
)
VALUES

(
    'condition',
    'f1000000-0000-0000-0000-000000000004',
    'has_documentation_pattern',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000100',
    0.8,
    'positive',
    0.9,
    'Asthma may present with a variable obstructive airway phenotype.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    'has_documentation_pattern',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000101',
    0.8,
    'positive',
    0.9,
    'Heart failure may present with a cardiopulmonary congestion phenotype.'
),

(
    'condition',
    'f1000000-0000-0000-0000-000000000006',
    'has_documentation_pattern',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000102',
    0.8,
    'positive',
    0.9,
    'GERD may present with a reflux-associated cough phenotype.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 22. CLINICAL GRAPH INTEGRITY CHECKS
-- =============================================================================
--
-- These checks do not modify data.
-- They allow the seed/deployment process to verify that critical graph
-- junctions exist.
--
-- =============================================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN

    -- -------------------------------------------------------------------------
    -- Asthma
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition
    WHERE condition_code = 'ASTHMA';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: ASTHMA condition missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- Heart failure
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition
    WHERE condition_code = 'HEART_FAILURE';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: HEART-FAILURE condition missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- GERD
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition
    WHERE condition_code = 'GERD';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: GERD condition missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- Asthma phenotype
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition_phenotype cp
    JOIN knowledge.condition c
      ON c.id = cp.condition_id
    JOIN knowledge.phenotype p
      ON p.id = cp.phenotype_id
    WHERE c.condition_code = 'ASTHMA'
      AND p.phenotype_code = 'PHEN-AIRWAY-WHEEZE';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: ASTHMA -> AIRWAY-WHEEZE junction missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- Heart failure phenotype
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition_phenotype cp
    JOIN knowledge.condition c
      ON c.id = cp.condition_id
    JOIN knowledge.phenotype p
      ON p.id = cp.phenotype_id
    WHERE c.condition_code = 'HEART_FAILURE'
      AND p.phenotype_code = 'PHEN-CHF-CONGESTIVE';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: HEART-FAILURE -> CHF-CONGESTIVE junction missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- GERD phenotype
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition_phenotype cp
    JOIN knowledge.condition c
      ON c.id = cp.condition_id
    JOIN knowledge.phenotype p
      ON p.id = cp.phenotype_id
    WHERE c.condition_code = 'GERD'
      AND p.phenotype_code = 'PHEN-REFLUX-COUGH';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: GERD -> REFLUX-COUGH junction missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- Heart failure -> pulmonary congestion
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition_mechanism cm
    JOIN knowledge.condition c
      ON c.id = cm.condition_id
    JOIN knowledge.mechanism m
      ON m.id = cm.mechanism_id
    WHERE c.condition_code = 'HEART_FAILURE'
      AND m.mechanism_code = 'MECH-PULMONARY-CONGESTION';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: HEART-FAILURE -> PULMONARY-CONGESTION junction missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- GERD -> reflux mechanism
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.condition_mechanism cm
    JOIN knowledge.condition c
      ON c.id = cm.condition_id
    JOIN knowledge.mechanism m
      ON m.id = cm.mechanism_id
    WHERE c.condition_code = 'GERD'
      AND m.mechanism_code = 'MECH-GASTROESOPHAGEAL-REFLUX';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: GERD -> REFLUX mechanism junction missing';
    END IF;


    -- -------------------------------------------------------------------------
    -- Asthma -> airway phenotype
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.phenotype_differential pd
    JOIN knowledge.phenotype p
      ON p.id = pd.phenotype_id
    JOIN knowledge.condition c
      ON c.id = pd.condition_id
    WHERE p.phenotype_code = 'PHEN-AIRWAY-WHEEZE'
      AND c.condition_code = 'ASTHMA';

    IF v_count = 0 THEN
        RAISE EXCEPTION
            'AMEXAN ZP4 integrity failure: AIRWAY-WHEEZE -> ASTHMA differential missing';
    END IF;


    RAISE NOTICE
        'AMEXAN ZP4 clinical knowledge graph integrity checks passed.';

END $$;


-- =============================================================================
-- END OF AMEXAN PHASE 2 — SEED ZP4
-- =============================================================================