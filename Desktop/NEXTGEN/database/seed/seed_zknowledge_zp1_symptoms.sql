-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP1
-- UNIVERSAL SYMPTOM INTELLIGENCE LIBRARY
-- =============================================================================
--
-- PURPOSE
-- -------
-- ZP1 establishes the universal symptom-entry layer of the AMEXAN Clinical OS.
--
-- PRINCIPLE
-- ---------
--
--                  PATIENT
--                     ↓
--                  SYMPTOM
--                     ↓
--          CHARACTERIZATION
--                     ↓
--              RED FLAGS
--                     ↓
--          BODY SYSTEMS
--                     ↓
--             SPECIALTIES
--                     ↓
--           CLINICAL QUESTIONS
--                     ↓
--              PHENOTYPES
--                     ↓
--             CONDITIONS
--                     ↓
--       INVESTIGATION / MANAGEMENT
--
-- Disease must NOT be the starting point of the patient-facing reasoning
-- architecture.
--
-- ZP1 therefore models symptoms independently of disease.
--
-- This seed expands the MVP chest pain + abdominal pain foundation into a
-- broad universal symptom vocabulary while preserving the existing schema.
--
-- =============================================================================


-- =============================================================================
-- 0. CORRECTION OF EXISTING DATA
-- =============================================================================

UPDATE knowledge.symptom_red_flag
SET red_flag_code = 'RF-ABDO-PAIN-ECTOPIC',
    description =
        'Abdominal or pelvic pain in a patient who may be pregnant requires
         pregnancy assessment and exclusion of ectopic pregnancy when clinically
         applicable.'
WHERE red_flag_code = 'RF-ABDO-PAIN-ETOPIC';


-- =============================================================================
-- 1. CHEST PAIN — UNIVERSAL SYMPTOM PROFILE
-- =============================================================================

INSERT INTO knowledge.symptom_synonym
(symptom_id, synonym, language_code, is_preferred)
VALUES
('f0b00000-0000-0000-0000-000000000007', 'Chest discomfort', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'Chest pressure', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'Chest tightness', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'Chest heaviness', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'Pain in chest', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'Maumivu ya kifua', 'sw', true),
('f0b00000-0000-0000-0000-000000000007', 'Kifua kubana', 'sw', false),
('f0b00000-0000-0000-0000-000000000007', 'Kifua kuwa kizito', 'sw', false)
  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.symptom_system
(symptom_id, body_system_code, relevance)
VALUES
('f0b00000-0000-0000-0000-000000000007', 'CARDIOVASCULAR', 1.00),
('f0b00000-0000-0000-0000-000000000007', 'RESPIRATORY', 1.00),
('f0b00000-0000-0000-0000-000000000007', 'GASTROINTESTINAL', 0.70),
('f0b00000-0000-0000-0000-000000000007', 'MUSCULOSKELETAL', 0.80),
('f0b00000-0000-0000-0000-000000000007', 'NEUROLOGICAL', 0.30),
('f0b00000-0000-0000-0000-000000000007', 'PSYCHIATRIC', 0.30),
('f0b00000-0000-0000-0000-000000000007', 'DERMATOLOGICAL', 0.20)
  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.symptom_specialty
(symptom_id, specialty_code, relevance)
VALUES
('f0b00000-0000-0000-0000-000000000007', 'emergency_medicine', 1.00),
('f0b00000-0000-0000-0000-000000000007', 'cardiology', 1.00),
('f0b00000-0000-0000-0000-000000000007', 'pulmonology', 0.90),
('f0b00000-0000-0000-0000-000000000007', 'internal_medicine', 0.90),
('f0b00000-0000-0000-0000-000000000007', 'surgery', 0.70),
('f0b00000-0000-0000-0000-000000000007', 'gastroenterology', 0.60),
('f0b00000-0000-0000-0000-000000000007', 'surgery', 0.50),
('f0b00000-0000-0000-0000-000000000007', 'surgery', 0.60),
('f0b00000-0000-0000-0000-000000000007', 'family_medicine', 0.70),
('f0b00000-0000-0000-0000-000000000007', 'paediatrics', 0.50),
('f0b00000-0000-0000-0000-000000000007', 'obstetrics_gynaecology', 0.30)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- CHEST PAIN RED FLAGS
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag
(symptom_id, red_flag_code, description, urgency)
VALUES

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-ACS',
'Acute chest pain or pressure concerning for myocardial ischaemia, particularly with diaphoresis, nausea, dyspnoea, radiation or cardiovascular risk factors.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-AORTIC-DISSECTION',
'Sudden severe chest or back pain, especially abrupt or tearing in character, with pulse or neurological abnormalities.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-PULMONARY-EMBOLISM',
'Acute chest pain with dyspnoea, tachycardia, hypoxaemia, haemoptysis, syncope or thromboembolic risk.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-TENSION-PNEUMOTHORAX',
'Acute chest pain and respiratory distress with severe hypoxaemia, unilateral absent breath sounds or haemodynamic compromise.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-TAMPONADE',
'Chest discomfort with hypotension, elevated venous pressure, tachycardia or clinical evidence of obstructive shock.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-MYOCARDITIS',
'Chest pain with unexplained dyspnoea, arrhythmia, syncope or systemic/infectious features suggesting myocardial inflammation.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-PERICARDITIS',
'Chest pain with positional or pleuritic characteristics accompanied by systemic illness or haemodynamic compromise.',
'urgent'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-OESOPHAGEAL-RUPTURE',
'Severe acute chest pain following vomiting or instrumentation with systemic toxicity or subcutaneous emphysema.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-SEVERE-HYPOXAEMIA',
'Chest pain associated with clinically significant hypoxaemia or respiratory distress.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-SYNCOPE',
'Chest pain associated with syncope or near-syncope requires urgent assessment for potentially life-threatening cardiovascular or pulmonary causes.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-HAEMODYNAMIC-INSTABILITY',
'Chest pain associated with hypotension, shock, severe tachycardia or altered consciousness.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000007',
'RF-CHEST-TRAUMA',
'Chest pain after significant trauma may indicate pneumothorax, haemothorax, pulmonary contusion, cardiac injury or vascular injury.',
'emergency'
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.symptom_documentation
(symptom_id, documentation_phrase, language_code, is_preferred)
VALUES
('f0b00000-0000-0000-0000-000000000007', 'chest pain', 'en', true),
('f0b00000-0000-0000-0000-000000000007', 'chest discomfort', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'chest pressure', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'chest tightness', 'en', false),
('f0b00000-0000-0000-0000-000000000007', 'maumivu ya kifua', 'sw', true)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. ABDOMINAL PAIN — UNIVERSAL SYMPTOM PROFILE
-- =============================================================================

INSERT INTO knowledge.symptom_synonym
(symptom_id, synonym, language_code, is_preferred)
VALUES
('f0b00000-0000-0000-0000-000000000008', 'Stomach pain', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'Belly pain', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'Abdominal discomfort', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'Abdominal cramps', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'Tummy pain', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'Maumivu ya tumbo', 'sw', true),
('f0b00000-0000-0000-0000-000000000008', 'Tumbo kuuma', 'sw', false)
  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.symptom_system
(symptom_id, body_system_code, relevance)
VALUES
('f0b00000-0000-0000-0000-000000000008', 'GASTROINTESTINAL', 1.00),
('f0b00000-0000-0000-0000-000000000008', 'RENAL_URINARY', 0.80),
('f0b00000-0000-0000-0000-000000000008', 'REPRODUCTIVE', 0.80),
('f0b00000-0000-0000-0000-000000000008', 'MUSCULOSKELETAL', 0.40),
('f0b00000-0000-0000-0000-000000000008', 'CARDIOVASCULAR', 0.20),
('f0b00000-0000-0000-0000-000000000008', 'RESPIRATORY', 0.30),
('f0b00000-0000-0000-0000-000000000008', 'ENDOCRINE', 0.30),
('f0b00000-0000-0000-0000-000000000008', 'NEUROLOGICAL', 0.20)
  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.symptom_specialty
(symptom_id, specialty_code, relevance)
VALUES
('f0b00000-0000-0000-0000-000000000008', 'emergency_medicine', 1.00),
('f0b00000-0000-0000-0000-000000000008', 'surgery', 1.00),
('f0b00000-0000-0000-0000-000000000008', 'gastroenterology', 1.00),
('f0b00000-0000-0000-0000-000000000008', 'internal_medicine', 0.90),
('f0b00000-0000-0000-0000-000000000008', 'obstetrics_gynaecology', 0.90),
('f0b00000-0000-0000-0000-000000000008', 'urology', 0.80),
('f0b00000-0000-0000-0000-000000000008', 'paediatrics', 0.80),
('f0b00000-0000-0000-0000-000000000008', 'family_medicine', 0.80),
('f0b00000-0000-0000-0000-000000000008', 'infectious_diseases', 0.50),
('f0b00000-0000-0000-0000-000000000008', 'surgery', 0.60)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- ABDOMINAL PAIN RED FLAGS
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag
(symptom_id, red_flag_code, description, urgency)
VALUES

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-PERFORATION',
'Sudden severe abdominal pain with guarding, rigidity, rebound tenderness or systemic deterioration may indicate perforation or peritonitis.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-SHOCK',
'Abdominal pain associated with hypotension, tachycardia, altered consciousness or other evidence of shock.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-INTERNAL-HAEMORRHAGE',
'Abdominal pain with haemodynamic instability, pallor, syncope or evidence of bleeding.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-ECTOPIC',
'Abdominal or pelvic pain in a potentially pregnant patient requires assessment for ectopic pregnancy where clinically applicable.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-OBSTRUCTION',
'Severe abdominal pain with vomiting, distension, constipation or inability to pass flatus may indicate intestinal obstruction.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-MESENTERIC-ISCHAEMIA',
'Severe abdominal pain that may be disproportionate to examination findings, particularly in patients with vascular risk factors.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-AAA',
'Abdominal or back pain with hypotension, syncope or a pulsatile abdominal mass may indicate ruptured abdominal aortic aneurysm.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-APPENDICITIS-COMPLICATION',
'Severe localized or generalized abdominal pain with fever, peritoneal signs or systemic toxicity may indicate complicated appendicitis.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-ACUTE-PANCREATITIS',
'Severe upper abdominal pain with persistent vomiting or systemic deterioration requires urgent assessment for pancreatitis and complications.',
'urgent'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-ACUTE-CHOLECYSTITIS',
'Right upper quadrant pain with fever, systemic illness or jaundice requires urgent biliary assessment.',
'urgent'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-CHOLANGITIS',
'Abdominal pain associated with fever and jaundice may represent biliary infection requiring urgent treatment.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-GI-BLEED',
'Abdominal pain with haematemesis, melaena, haematochezia or haemodynamic compromise requires urgent assessment.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-STRANGULATION',
'Severe pain with intestinal obstruction and systemic toxicity may indicate bowel strangulation or ischaemia.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-TESTICULAR-REFERRAL',
'Lower abdominal or groin pain in a male may accompany testicular torsion and requires genital/testicular assessment when clinically indicated.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-OVARIAN-TORSION',
'Acute unilateral pelvic or lower abdominal pain with nausea or vomiting may indicate ovarian torsion.',
'emergency'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-SEVERE-DEHYDRATION',
'Abdominal pain with persistent vomiting, inability to maintain intake or signs of significant dehydration requires urgent assessment.',
'urgent'
),

(
'f0b00000-0000-0000-0000-000000000008',
'RF-ABDO-SEPSIS',
'Abdominal pain with fever or hypothermia, tachycardia, hypotension, altered mental status or other evidence of systemic infection requires urgent sepsis assessment.',
'emergency'
)

  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.symptom_documentation
(symptom_id, documentation_phrase, language_code, is_preferred)
VALUES
('f0b00000-0000-0000-0000-000000000008', 'abdominal pain', 'en', true),
('f0b00000-0000-0000-0000-000000000008', 'abdominal discomfort', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'stomach pain', 'en', false),
('f0b00000-0000-0000-0000-000000000008', 'maumivu ya tumbo', 'sw', true)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. Z9 SYMPTOM INTELLIGENCE OVERRIDE — CHEST PAIN
-- =============================================================================

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000020',
    'OVR-SYMPTOM-CHEST-PAIN-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000007',
    'global',
    NULL,

    jsonb_build_object(

        'priority', 100,

        'safety_priority', 100,

        'mandatory_dimensions',
        jsonb_build_array(
            'onset',
            'duration',
            'course',
            'site',
            'character',
            'severity',
            'radiation',
            'precipitating_factors',
            'relieving_factors',
            'exertional_relationship',
            'respiratory_relationship',
            'positional_relationship',
            'food_relationship',
            'associated_dyspnoea',
            'associated_palpitations',
            'associated_syncope',
            'associated_sweating',
            'associated_nausea',
            'associated_vomiting',
            'associated_fever',
            'associated_cough',
            'associated_haemoptysis',
            'trauma',
            'risk_factors',
            'previous_episodes',
            'treatment_taken',
            'red_flags'
        ),

        'mandatory_measurements',
        jsonb_build_array(
            'SPO2',
            'RESPIRATORY_RATE',
            'HEART_RATE',
            'BLOOD_PRESSURE',
            'TEMPERATURE'
        ),

        'context_dimensions',
        jsonb_build_array(
            'age',
            'sex',
            'pregnancy',
            'cardiovascular_risk',
            'smoking',
            'diabetes',
            'hypertension',
            'dyslipidaemia',
            'obesity',
            'previous_cardiovascular_disease',
            'thromboembolic_risk',
            'recent_surgery',
            'immobility',
            'malignancy',
            'trauma',
            'infection',
            'drug_exposure',
            'cocaine_or_stimulant_exposure'
        ),

        'red_flag_first', true,

        'emergency_screen_required', true,

        'note',
        'Chest pain must first undergo immediate severity and life-threatening-cause screening before disease-specific questioning.'
    ),

    'AMEXAN universal chest pain symptom intelligence baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. Z9 SYMPTOM INTELLIGENCE OVERRIDE — ABDOMINAL PAIN
-- =============================================================================

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000021',
    'OVR-SYMPTOM-ABDO-PAIN-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000008',
    'global',
    NULL,

    jsonb_build_object(

        'priority', 100,

        'safety_priority', 100,

        'mandatory_dimensions',
        jsonb_build_array(
            'onset',
            'duration',
            'course',
            'site',
            'character',
            'severity',
            'radiation',
            'migration',
            'precipitating_factors',
            'relieving_factors',
            'food_relationship',
            'movement_relationship',
            'vomiting',
            'nausea',
            'appetite',
            'bowel_frequency',
            'stool_character',
            'diarrhoea',
            'constipation',
            'obstipation',
            'flatus',
            'haematemesis',
            'melaena',
            'haematochezia',
            'dysuria',
            'frequency',
            'urgency',
            'haematuria',
            'vaginal_bleeding',
            'vaginal_discharge',
            'menstrual_history',
            'pregnancy_possibility',
            'previous_surgery',
            'trauma',
            'fever',
            'jaundice',
            'weight_loss',
            'red_flags'
        ),

        'mandatory_context',
        jsonb_build_array(
            'age',
            'sex',
            'pregnancy',
            'menstrual_status',
            'previous_abdominal_surgery',
            'previous_gastrointestinal_disease',
            'previous_urological_disease',
            'previous_gynaecological_disease',
            'medications',
            'NSAID_use',
            'anticoagulants',
            'alcohol',
            'travel',
            'food_exposure',
            'infectious_exposure'
        ),

        'mandatory_measurements',
        jsonb_build_array(
            'TEMPERATURE',
            'HEART_RATE',
            'BLOOD_PRESSURE',
            'RESPIRATORY_RATE',
            'SPO2'
        ),

        'red_flag_first', true,

        'emergency_screen_required', true,

        'special_context_activation',
        jsonb_build_object(
            'pregnancy_possible',
            jsonb_build_array(
                'pregnancy_test',
                'ectopic_pregnancy_screen',
                'vaginal_bleeding',
                'pelvic_pain'
            ),

            'child',
            jsonb_build_array(
                'feeding',
                'hydration',
                'stool',
                'vomiting',
                'abdominal_distension',
                'intussusception_screen',
                'appendicitis_screen'
            ),

            'elderly',
            jsonb_build_array(
                'vascular_risk',
                'medications',
                'atypical_presentation',
                'mesenteric_ischaemia_screen'
            )
        ),

        'note',
        'Abdominal pain must be anatomically localized and characterized before disease-level reasoning, with pregnancy, age, surgical history and systemic instability dynamically modifying the questioning pathway.'
    ),

    'AMEXAN universal abdominal pain symptom intelligence baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. CHEST PAIN — CLINICAL PHENOTYPE DIMENSIONS
-- =============================================================================
--
-- These are deliberately symptom-level descriptors.
-- They are NOT diagnoses.
-- =============================================================================

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000022',
    'OVR-CHEST-PAIN-PHENOTYPE-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000007',
    'global',
    NULL,

    jsonb_build_object(
        'phenotype_axes',
        jsonb_build_array(
            'pressure',
            'tightness',
            'heaviness',
            'burning',
            'sharp',
            'stabbing',
            'pleuritic',
            'positional',
            'exertional',
            'reproducible',
            'postprandial',
            'radiating',
            'sudden',
            'gradual',
            'constant',
            'intermittent'
        ),

        'radiation_sites',
        jsonb_build_array(
            'left_arm',
            'right_arm',
            'both_arms',
            'shoulder',
            'neck',
            'jaw',
            'back',
            'epigastrium'
        )
    ),

    'AMEXAN chest pain phenotype vocabulary.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. ABDOMINAL PAIN — ANATOMICAL LOCALIZATION
-- =============================================================================

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000023',
    'OVR-ABDO-PAIN-ANATOMY-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000008',
    'global',
    NULL,

    jsonb_build_object(
        'anatomical_regions',
        jsonb_build_array(
            'right_upper_quadrant',
            'epigastrium',
            'left_upper_quadrant',
            'periumbilical',
            'right_lower_quadrant',
            'suprapubic',
            'left_lower_quadrant',
            'right_flank',
            'left_flank',
            'generalized',
            'pelvic',
            'groin'
        ),

        'nine_region_model',
        jsonb_build_array(
            'right_hypochondrium',
            'epigastrium',
            'left_hypochondrium',
            'right_lumbar',
            'umbilical',
            'left_lumbar',
            'right_iliac',
            'hypogastric',
            'left_iliac'
        ),

        'pain_patterns',
        jsonb_build_array(
            'localized',
            'diffuse',
            'migratory',
            'radiating',
            'referred'
        )
    ),

    'AMEXAN abdominal pain anatomical intelligence vocabulary.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. UNIVERSAL SYMPTOM SAFETY CONTRACT
-- =============================================================================

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000024',
    'OVR-UNIVERSAL-SYMPTOM-SAFETY-CONTRACT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000007',
    'global',
    NULL,

    jsonb_build_object(

        'safety_contract',
        jsonb_build_object(
            'red_flags_before_differential', true,
            'severity_before_aetiology', true,
            'emergency_measurements_first', true,
            'patient_context_required', true,
            'age_sensitive', true,
            'sex_sensitive', true,
            'pregnancy_sensitive', true,
            'paediatric_sensitive', true,
            'elderly_sensitive', true,
            'immunocompromised_sensitive', true
        ),

        'prohibited_behaviour',
        jsonb_build_array(
            'disease_first_reasoning',
            'silent_inference',
            'silent_diagnosis',
            'suppression_of_red_flags',
            'suppression_of_contraindications',
            'automatic_emergency_downgrade'
        )
    ),

    'AMEXAN universal symptom safety contract.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. ZP1 VALIDATION
-- =============================================================================

SELECT
    s.symptom_code,
    s.canonical_name,
    s.is_emergency,
    COUNT(DISTINCT ss.body_system_code) AS systems,
    COUNT(DISTINCT sp.specialty_code) AS specialties,
    COUNT(DISTINCT sr.red_flag_code) AS red_flags,
    COUNT(DISTINCT sd.documentation_phrase) AS documentation_terms
FROM knowledge.symptom s
LEFT JOIN knowledge.symptom_system ss
    ON ss.symptom_id = s.id
LEFT JOIN knowledge.symptom_specialty sp
    ON sp.symptom_id = s.id
LEFT JOIN knowledge.symptom_red_flag sr
    ON sr.symptom_id = s.id
LEFT JOIN knowledge.symptom_documentation sd
    ON sd.symptom_id = s.id
WHERE s.id IN
(
    'f0b00000-0000-0000-0000-000000000007',
    'f0b00000-0000-0000-0000-000000000008'
)
GROUP BY
    s.symptom_code,
    s.canonical_name,
    s.is_emergency
ORDER BY
    s.symptom_code;


-- =============================================================================
-- 9. ZP1 EXPECTED ARCHITECTURAL RESULT
-- =============================================================================
--
-- CHEST PAIN
--     ↓
-- Characterize
--     ↓
-- Immediate severity
--     ↓
-- ACS / PE / dissection / pneumothorax / tamponade / other emergency screen
--     ↓
-- Cardiovascular
-- Respiratory
-- Gastrointestinal
-- Musculoskeletal
-- Neurological
-- Psychological
--     ↓
-- Context
--     ↓
-- Questions
--     ↓
-- Phenotype
--     ↓
-- Clinical concepts
--
--
-- ABDOMINAL PAIN
--     ↓
-- Characterize
--     ↓
-- Anatomical localization
--     ↓
-- Peritonitis / shock / bleeding / obstruction / ischaemia / pregnancy screen
--     ↓
-- GI
-- Renal
-- Reproductive
-- Vascular
-- Respiratory
-- Metabolic
--     ↓
-- Context
--     ↓
-- Questions
--     ↓
-- Phenotype
--     ↓
-- Clinical concepts
--
-- =============================================================================
-- END ZP1 CHEST + ABDOMINAL PAIN
-- =============================================================================