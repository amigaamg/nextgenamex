-- =============================================================================
-- AMEXAN Phase 2 â€” Seed Z8: UNIVERSAL CONCEPT JUNCTIONS
-- =============================================================================
-- PURPOSE
-- =============================================================================
-- Connect canonical clinical concepts to:
--
--   1. BODY SYSTEMS
--   2. CLINICAL SPECIALTIES
--
-- The concept itself exists ONCE.
--
-- Example:
--
--   CNS-COUGH
--       |
--       +-- RESPIRATORY
--       +-- CARDIOVASCULAR
--       +-- GASTROINTESTINAL
--       +-- HEAD_NECK
--       |
--       +-- INTERNAL MEDICINE
--       +-- FAMILY MEDICINE
--       +-- PAEDIATRICS
--       +-- EMERGENCY MEDICINE
--       +-- SURGERY
--
-- This allows AMEXAN Clinical Intelligence to reason longitudinally
-- across specialties without copying the same clinical concept into
-- separate departmental knowledge bases.
--
-- DESIGN PRINCIPLES
-- =============================================================================
-- 1. One canonical concept.
-- 2. Many body systems.
-- 3. Many specialties.
-- 4. Weighted relevance.
-- 5. Specialty does not redefine the concept.
-- 6. Body system does not redefine the concept.
-- 7. Clinical reasoning can traverse concept -> system -> specialty.
-- 8. Longitudinal records can therefore retain the same semantic identity.
-- 9. Do not encode a diagnosis merely because a symptom belongs to a
--    specialty.
-- 10. These tables describe RELEVANCE, not diagnostic certainty.
--
-- relevance values:
--
--   primary
--   secondary
--   related
--   cross_system
--   possible
--
-- weight:
--   0.0 - 1.0
--
-- IMPORTANT:
-- Weight is a ranking signal, NOT a probability and NOT a diagnostic score.
-- =============================================================================


-- =============================================================================
-- Z8.1 BODY-SYSTEM RELATIONSHIPS
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

-- -----------------------------------------------------------------------------
-- CNS-COUGH
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000001',
    'RESPIRATORY',
    'primary',
    1.00,
    'Cough is primarily a respiratory symptom involving the airway and
     protective cough reflex.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'CARDIOVASCULAR',
    'secondary',
    0.40,
    'Cardiac disease, particularly pulmonary congestion and heart failure,
     may present with cough.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'GASTROINTESTINAL',
    'secondary',
    0.35,
    'Gastro-oesophageal reflux and aspiration may produce chronic cough.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'HEAD_NECK',
    'secondary',
    0.35,
    'Upper-airway disease and post-nasal drainage may produce cough.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'IMMUNE',
    'cross_system',
    0.40,
    'Infectious and inflammatory immune processes commonly generate cough.'
),

-- -----------------------------------------------------------------------------
-- CNS-FEVER
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000002',
    'CONSTITUTIONAL',
    'primary',
    1.00,
    'Fever is a systemic constitutional manifestation.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'IMMUNE',
    'primary',
    0.90,
    'Fever commonly reflects cytokine-mediated immune response.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'RESPIRATORY',
    'secondary',
    0.55,
    'Respiratory infections commonly produce fever.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'NEUROLOGICAL',
    'related',
    0.25,
    'Central nervous system disease can be associated with fever.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'GASTROINTESTINAL',
    'secondary',
    0.40,
    'Gastrointestinal and hepatobiliary infections may cause fever.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'RENAL_URINARY',
    'secondary',
    0.40,
    'Urinary tract and renal infections may cause fever.'
),

-- -----------------------------------------------------------------------------
-- CNS-DYSPNOEA
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000003',
    'RESPIRATORY',
    'primary',
    1.00,
    'Dyspnoea is a major respiratory symptom.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'CARDIOVASCULAR',
    'primary',
    0.90,
    'Cardiac failure, valvular disease and other cardiovascular disorders
     may produce dyspnoea.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'HAEMATOLOGICAL',
    'secondary',
    0.35,
    'Anaemia can produce exertional dyspnoea through reduced oxygen delivery.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'NEUROLOGICAL',
    'related',
    0.25,
    'Neuromuscular weakness and central disorders may impair ventilation.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'PSYCHIATRIC',
    'related',
    0.20,
    'Panic and anxiety may produce subjective breathlessness after organic
     causes have been considered.'
),

-- -----------------------------------------------------------------------------
-- CNS-HAEMOPTYSIS
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000004',
    'RESPIRATORY',
    'primary',
    1.00,
    'Haemoptysis usually originates from the respiratory tract.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'CARDIOVASCULAR',
    'secondary',
    0.35,
    'Pulmonary embolism, pulmonary hypertension and cardiac disease may
     produce haemoptysis.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'IMMUNE',
    'secondary',
    0.35,
    'Immune-mediated pulmonary and systemic vasculitic disorders may cause
     haemoptysis.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'HEAD_NECK',
    'related',
    0.20,
    'Upper-airway bleeding may be mistaken for true haemoptysis.'
),

-- -----------------------------------------------------------------------------
-- CNS-PRODUCTIVE-COUGH
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000000b',
    'RESPIRATORY',
    'primary',
    1.00,
    'Productive cough reflects mucus or other respiratory secretions.'
),
(
    'f0a00000-0000-0000-0000-00000000000b',
    'IMMUNE',
    'secondary',
    0.45,
    'Airway infection and inflammation may increase sputum production.'
),

-- -----------------------------------------------------------------------------
-- CNS-TB-EXPOSURE
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000016',
    'RESPIRATORY',
    'primary',
    1.00,
    'TB exposure is directly relevant to respiratory tuberculosis assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000016',
    'IMMUNE',
    'cross_system',
    0.80,
    'Risk and progression of tuberculosis are strongly influenced by host
     immune status.'
),

-- -----------------------------------------------------------------------------
-- CNS-SMOKING
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000017',
    'RESPIRATORY',
    'primary',
    1.00,
    'Smoking is a major respiratory exposure and risk factor.'
),
(
    'f0a00000-0000-0000-0000-000000000017',
    'CARDIOVASCULAR',
    'primary',
    0.85,
    'Smoking is a major cardiovascular risk factor.'
),
(
    'f0a00000-0000-0000-0000-000000000017',
    'INTEGUMENTARY',
    'related',
    0.15,
    'Smoking may adversely affect tissue perfusion and wound healing.'
),

-- -----------------------------------------------------------------------------
-- CNS-IMMUNOCOMPROMISED
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000001c',
    'IMMUNE',
    'primary',
    1.00,
    'Immunocompromise represents altered host immune competence.'
),
(
    'f0a00000-0000-0000-0000-00000000001c',
    'RESPIRATORY',
    'secondary',
    0.65,
    'Immunocompromised patients have altered susceptibility to respiratory
     infections.'
),
(
    'f0a00000-0000-0000-0000-00000000001c',
    'HAEMATOLOGICAL',
    'secondary',
    0.45,
    'Haematological disorders and therapies may cause immunocompromise.'
),

-- -----------------------------------------------------------------------------
-- CNS-WEIGHT-LOSS
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000000e',
    'CONSTITUTIONAL',
    'primary',
    1.00,
    'Weight loss is a constitutional clinical finding.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'GASTROINTESTINAL',
    'secondary',
    0.65,
    'Gastrointestinal disease and malabsorption may cause weight loss.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'ENDOCRINE',
    'secondary',
    0.60,
    'Endocrine disease may cause unintentional weight loss.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'IMMUNE',
    'secondary',
    0.50,
    'Chronic inflammatory and infectious disease may produce weight loss.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'MUSCULOSKELETAL',
    'related',
    0.20,
    'Chronic inflammatory musculoskeletal disease may contribute to weight
     loss.'
),

-- -----------------------------------------------------------------------------
-- CNS-NIGHT-SWEATS
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000000f',
    'CONSTITUTIONAL',
    'primary',
    1.00,
    'Night sweats are a constitutional symptom.'
),
(
    'f0a00000-0000-0000-0000-00000000000f',
    'IMMUNE',
    'secondary',
    0.75,
    'Chronic infection and inflammatory disease may cause night sweats.'
),
(
    'f0a00000-0000-0000-0000-00000000000f',
    'HAEMATOLOGICAL',
    'secondary',
    0.55,
    'Haematological malignancies may present with night sweats.'
),

-- -----------------------------------------------------------------------------
-- CNS-AIRWAY-INFLAMMATION
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000021',
    'RESPIRATORY',
    'primary',
    1.00,
    'Airway inflammation is a respiratory pathophysiological mechanism.'
),
(
    'f0a00000-0000-0000-0000-000000000021',
    'IMMUNE',
    'cross_system',
    0.75,
    'Airway inflammation may be mediated by infectious or immune mechanisms.'
),

-- -----------------------------------------------------------------------------
-- CNS-ALVEOLAR-INFLAMMATION
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000022',
    'RESPIRATORY',
    'primary',
    1.00,
    'Alveolar inflammation affects the pulmonary parenchyma and gas exchange.'
),
(
    'f0a00000-0000-0000-0000-000000000022',
    'IMMUNE',
    'cross_system',
    0.80,
    'Immune activation commonly contributes to alveolar inflammation.'
),

-- -----------------------------------------------------------------------------
-- CNS-PLEURAL-INFLAMMATION
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000025',
    'RESPIRATORY',
    'primary',
    1.00,
    'Pleural inflammation affects the pleural surfaces surrounding the lungs.'
),
(
    'f0a00000-0000-0000-0000-000000000025',
    'IMMUNE',
    'secondary',
    0.55,
    'Infectious and inflammatory processes may produce pleural inflammation.'
),

-- -----------------------------------------------------------------------------
-- CNS-AIRWAY-OBSTRUCTION
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000023',
    'RESPIRATORY',
    'primary',
    1.00,
    'Airway obstruction is a respiratory pathophysiological mechanism.'
),
(
    'f0a00000-0000-0000-0000-000000000023',
    'HEAD_NECK',
    'secondary',
    0.40,
    'Upper-airway obstruction may originate in the head and neck.'
),

-- -----------------------------------------------------------------------------
-- CNS-PNEUMONIA
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000035',
    'RESPIRATORY',
    'primary',
    1.00,
    'Pneumonia is an infection involving pulmonary parenchyma.'
),
(
    'f0a00000-0000-0000-0000-000000000035',
    'IMMUNE',
    'cross_system',
    0.80,
    'Pneumonia involves host immune response to infectious organisms.'
),
(
    'f0a00000-0000-0000-0000-000000000035',
    'CONSTITUTIONAL',
    'secondary',
    0.55,
    'Pneumonia commonly produces systemic constitutional manifestations.'
),

-- -----------------------------------------------------------------------------
-- CNS-TUBERCULOSIS
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000039',
    'RESPIRATORY',
    'primary',
    1.00,
    'Pulmonary tuberculosis primarily affects the respiratory system.'
),
(
    'f0a00000-0000-0000-0000-000000000039',
    'IMMUNE',
    'cross_system',
    0.95,
    'Tuberculosis is strongly determined by host immune response.'
),
(
    'f0a00000-0000-0000-0000-000000000039',
    'CONSTITUTIONAL',
    'secondary',
    0.70,
    'Tuberculosis may produce fever, weight loss and night sweats.'
),

-- -----------------------------------------------------------------------------
-- CNS-ACUTE-BRONCHITIS
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000036',
    'RESPIRATORY',
    'primary',
    1.00,
    'Acute bronchitis involves inflammation of the conducting airways.'
),
(
    'f0a00000-0000-0000-0000-000000000036',
    'IMMUNE',
    'secondary',
    0.65,
    'Acute bronchitis is commonly associated with infectious airway
     inflammation.'
),

-- -----------------------------------------------------------------------------
-- CNS-CHEST-XRAY
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000042',
    'RESPIRATORY',
    'primary',
    1.00,
    'Chest radiography evaluates lungs, pleura and other thoracic structures.'
),
(
    'f0a00000-0000-0000-0000-000000000042',
    'CARDIOVASCULAR',
    'secondary',
    0.65,
    'Chest radiography may assess cardiac size and pulmonary vascular patterns.'
),

-- -----------------------------------------------------------------------------
-- CNS-SPUTUM-AFB
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000044',
    'RESPIRATORY',
    'primary',
    1.00,
    'Sputum AFB testing evaluates respiratory specimens for acid-fast
     mycobacteria.'
),
(
    'f0a00000-0000-0000-0000-000000000044',
    'IMMUNE',
    'secondary',
    0.60,
    'Mycobacterial disease is closely related to host immune competence.'
),

-- -----------------------------------------------------------------------------
-- CNS-PULSE-OXIMETRY
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-000000000043',
    'RESPIRATORY',
    'primary',
    1.00,
    'Pulse oximetry provides a non-invasive assessment of oxygen saturation.'
),
(
    'f0a00000-0000-0000-0000-000000000043',
    'CARDIOVASCULAR',
    'secondary',
    0.55,
    'Oxygen saturation contributes to assessment of overall cardiorespiratory
     status.'
),

-- -----------------------------------------------------------------------------
-- CNS-RESPIRATORY-FAILURE
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000004e',
    'RESPIRATORY',
    'primary',
    1.00,
    'Respiratory failure represents failure of adequate pulmonary gas exchange
     and/or ventilation.'
),
(
    'f0a00000-0000-0000-0000-00000000004e',
    'CARDIOVASCULAR',
    'secondary',
    0.60,
    'Severe respiratory failure has major cardiovascular consequences and may
     coexist with cardiac failure.'
),

-- -----------------------------------------------------------------------------
-- CNS-HYPOXAEMIA
-- -----------------------------------------------------------------------------

(
    'f0a00000-0000-0000-0000-00000000004d',
    'RESPIRATORY',
    'primary',
    1.00,
    'Hypoxaemia represents inadequate arterial oxygenation and commonly reflects
     respiratory gas-exchange abnormality.'
),
(
    'f0a00000-0000-0000-0000-00000000004d',
    'CARDIOVASCULAR',
    'secondary',
    0.60,
    'Hypoxaemia affects cardiovascular physiology and may arise from cardiac
     disease.'
),
(
    'f0a00000-0000-0000-0000-00000000004d',
    'HAEMATOLOGICAL',
    'related',
    0.25,
    'Haematological abnormalities influence oxygen delivery although they do
     not necessarily represent arterial hypoxaemia.'
)

ON CONFLICT (concept_id, body_system_code) DO NOTHING;


-- =============================================================================
-- Z8.2 SPECIALTY RELATIONSHIPS
-- =============================================================================
-- These relationships tell the intelligence layer WHERE a concept is
-- clinically relevant.
--
-- They DO NOT mean:
--
--   specialty = diagnosis
--   relevance = probability
--   weight = diagnostic certainty
--
-- They are routing / retrieval / prioritisation signals.
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

-- =============================================================================
-- COUGH
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000001',
    'internal_medicine',
    'primary',
    1.00,
    'Common adult medical presentation requiring structured respiratory,
     cardiovascular and gastrointestinal differential assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'family_medicine',
    'primary',
    1.00,
    'Common primary-care presentation.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'paediatrics',
    'primary',
    1.00,
    'Common paediatric respiratory presentation.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'emergency_medicine',
    'primary',
    0.90,
    'Important emergency presentation when associated with respiratory distress,
     hypoxaemia, haemoptysis or altered consciousness.'
),
(
    'f0a00000-0000-0000-0000-000000000001',
    'surgery',
    'possible',
    0.20,
    'May occur in perioperative, postoperative, aspiration and selected
     thoracic surgical contexts.'
),

-- =============================================================================
-- FEVER
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000002',
    'internal_medicine',
    'primary',
    1.00,
    'Core adult medical symptom requiring infectious, inflammatory,
     malignant and other systemic assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'family_medicine',
    'primary',
    1.00,
    'Common primary-care presentation.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'paediatrics',
    'primary',
    1.00,
    'High-frequency paediatric presentation.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'emergency_medicine',
    'primary',
    0.95,
    'Fever may represent serious acute infection or sepsis.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'obstetrics_gynaecology',
    'secondary',
    0.65,
    'Fever may occur with obstetric, pelvic, urinary and puerperal infection.'
),
(
    'f0a00000-0000-0000-0000-000000000002',
    'surgery',
    'secondary',
    0.55,
    'Postoperative and intra-abdominal infection may present with fever.'
),

-- =============================================================================
-- DYSPNOEA
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000003',
    'internal_medicine',
    'primary',
    1.00,
    'Major medical presentation with respiratory, cardiac, haematological and
     systemic differentials.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'emergency_medicine',
    'primary',
    1.00,
    'Potentially life-threatening presentation requiring immediate
     cardiorespiratory assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'family_medicine',
    'primary',
    0.85,
    'Important primary-care symptom requiring structured differential diagnosis.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'paediatrics',
    'primary',
    0.90,
    'Paediatric respiratory distress requires age-specific assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'obstetrics_gynaecology',
    'secondary',
    0.50,
    'Pregnancy alters respiratory physiology and includes important cardiac,
     thromboembolic and obstetric differentials.'
),
(
    'f0a00000-0000-0000-0000-000000000003',
    'surgery',
    'secondary',
    0.45,
    'Relevant to postoperative respiratory complications and thoracic disease.'
),

-- =============================================================================
-- HAEMOPTYSIS
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000004',
    'internal_medicine',
    'primary',
    1.00,
    'Requires evaluation for infection, malignancy, bronchiectasis,
     cardiovascular and thromboembolic disease.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'emergency_medicine',
    'primary',
    1.00,
    'Potentially life-threatening when massive or associated with respiratory
     compromise.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'paediatrics',
    'secondary',
    0.65,
    'Important paediatric finding requiring age-specific respiratory assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'surgery',
    'secondary',
    0.60,
    'May require procedural or surgical management in selected structural
     pulmonary causes.'
),
(
    'f0a00000-0000-0000-0000-000000000004',
    'family_medicine',
    'secondary',
    0.70,
    'Primary-care recognition and referral symptom.'
),

-- =============================================================================
-- PRODUCTIVE COUGH
-- =============================================================================

(
    'f0a00000-0000-0000-0000-00000000000b',
    'internal_medicine',
    'primary',
    1.00,
    'Important respiratory history characteristic.'
),
(
    'f0a00000-0000-0000-0000-00000000000b',
    'family_medicine',
    'primary',
    0.95,
    'Common primary-care respiratory finding.'
),
(
    'f0a00000-0000-0000-0000-00000000000b',
    'paediatrics',
    'primary',
    0.90,
    'Respiratory secretion production requires age-specific interpretation.'
),
(
    'f0a00000-0000-0000-0000-00000000000b',
    'emergency_medicine',
    'secondary',
    0.70,
    'Important when associated with respiratory distress or systemic illness.'
),

-- =============================================================================
-- TB EXPOSURE
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000016',
    'internal_medicine',
    'primary',
    1.00,
    'Important exposure history in adult respiratory and infectious disease
     assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000016',
    'family_medicine',
    'primary',
    0.95,
    'Primary-care TB screening and contact assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000016',
    'paediatrics',
    'primary',
    0.95,
    'TB contact history is particularly important in children.'
),
(
    'f0a00000-0000-0000-0000-000000000016',
    'emergency_medicine',
    'secondary',
    0.55,
    'Relevant to emergency respiratory and infectious presentations.'
),

-- =============================================================================
-- SMOKING
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000017',
    'internal_medicine',
    'primary',
    1.00,
    'Major medical risk factor for respiratory and cardiovascular disease.'
),
(
    'f0a00000-0000-0000-0000-000000000017',
    'family_medicine',
    'primary',
    1.00,
    'Smoking assessment, prevention and cessation are central to primary care.'
),
(
    'f0a00000-0000-0000-0000-000000000017',
    'emergency_medicine',
    'secondary',
    0.60,
    'Relevant risk factor in acute cardiovascular and respiratory presentations.'
),
(
    'f0a00000-0000-0000-0000-000000000017',
    'surgery',
    'secondary',
    0.60,
    'Smoking affects perioperative risk, wound healing and postoperative
     respiratory outcomes.'
),

-- =============================================================================
-- IMMUNOCOMPROMISED
-- =============================================================================

(
    'f0a00000-0000-0000-0000-00000000001c',
    'internal_medicine',
    'primary',
    1.00,
    'Important determinant of infection, malignancy and treatment risk.'
),
(
    'f0a00000-0000-0000-0000-00000000001c',
    'paediatrics',
    'primary',
    0.90,
    'Important in children with congenital, acquired or treatment-associated
     immune dysfunction.'
),
(
    'f0a00000-0000-0000-0000-00000000001c',
    'emergency_medicine',
    'primary',
    0.85,
    'Immunocompromise changes the urgency and differential of acute illness.'
),
(
    'f0a00000-0000-0000-0000-00000000001c',
    'surgery',
    'secondary',
    0.65,
    'Immune status materially affects perioperative infection and wound risk.'
),

-- =============================================================================
-- WEIGHT LOSS
-- =============================================================================

(
    'f0a00000-0000-0000-0000-00000000000e',
    'internal_medicine',
    'primary',
    1.00,
    'Requires broad medical assessment including malignancy, infection,
     endocrine, gastrointestinal and systemic disease.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'family_medicine',
    'primary',
    1.00,
    'Important primary-care red-flag presentation.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'paediatrics',
    'primary',
    0.90,
    'Requires assessment of nutrition, growth, chronic infection and systemic
     disease in children.'
),
(
    'f0a00000-0000-0000-0000-00000000000e',
    'surgery',
    'secondary',
    0.50,
    'May occur with malignancy and chronic gastrointestinal or surgical disease.'
),

-- =============================================================================
-- NIGHT SWEATS
-- =============================================================================

(
    'f0a00000-0000-0000-0000-00000000000f',
    'internal_medicine',
    'primary',
    1.00,
    'Important constitutional symptom in infection, malignancy and systemic
     disease.'
),
(
    'f0a00000-0000-0000-0000-00000000000f',
    'family_medicine',
    'secondary',
    0.85,
    'Primary-care constitutional red flag.'
),
(
    'f0a00000-0000-0000-0000-00000000000f',
    'paediatrics',
    'secondary',
    0.65,
    'May accompany chronic infection and inflammatory disease in children.'
),

-- =============================================================================
-- AIRWAY INFLAMMATION
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000021',
    'internal_medicine',
    'primary',
    1.00,
    'Core mechanism in asthma, bronchitis and other airway inflammatory disease.'
),
(
    'f0a00000-0000-0000-0000-000000000021',
    'paediatrics',
    'primary',
    0.95,
    'Important mechanism in paediatric airway disease.'
),
(
    'f0a00000-0000-0000-0000-000000000021',
    'emergency_medicine',
    'primary',
    0.90,
    'Acute airway inflammation may produce clinically significant obstruction.'
),
(
    'f0a00000-0000-0000-0000-000000000021',
    'family_medicine',
    'primary',
    0.90,
    'Common primary-care respiratory mechanism.'
),

-- =============================================================================
-- ALVEOLAR INFLAMMATION
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000022',
    'internal_medicine',
    'primary',
    1.00,
    'Core mechanism in pneumonia and other parenchymal inflammatory disorders.'
),
(
    'f0a00000-0000-0000-0000-000000000022',
    'paediatrics',
    'primary',
    0.95,
    'Major mechanism in childhood lower respiratory tract disease.'
),
(
    'f0a00000-0000-0000-0000-000000000022',
    'emergency_medicine',
    'primary',
    0.90,
    'Acute alveolar disease may produce hypoxaemia and respiratory distress.'
),
(
    'f0a00000-0000-0000-0000-000000000022',
    'family_medicine',
    'secondary',
    0.80,
    'Relevant to community-acquired lower respiratory infection.'
),

-- =============================================================================
-- PLEURAL INFLAMMATION
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000025',
    'internal_medicine',
    'primary',
    0.95,
    'Relevant to pleuritic chest pain, pleural infection and inflammatory
     thoracic disease.'
),
(
    'f0a00000-0000-0000-0000-000000000025',
    'surgery',
    'primary',
    0.90,
    'Pleural disease may require drainage or operative management.'
),
(
    'f0a00000-0000-0000-0000-000000000025',
    'emergency_medicine',
    'primary',
    0.90,
    'Important mechanism in acute pleural emergencies.'
),
(
    'f0a00000-0000-0000-0000-000000000025',
    'paediatrics',
    'secondary',
    0.70,
    'Relevant to paediatric parapneumonic effusion and empyema.'
),

-- =============================================================================
-- AIRWAY OBSTRUCTION
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000023',
    'internal_medicine',
    'primary',
    0.95,
    'Important in asthma, COPD and other obstructive airway disorders.'
),
(
    'f0a00000-0000-0000-0000-000000000023',
    'paediatrics',
    'primary',
    1.00,
    'Critical mechanism in asthma, bronchiolitis and foreign-body airway
     obstruction.'
),
(
    'f0a00000-0000-0000-0000-000000000023',
    'emergency_medicine',
    'primary',
    1.00,
    'Acute airway obstruction may rapidly become life-threatening.'
),
(
    'f0a00000-0000-0000-0000-000000000023',
    'surgery',
    'secondary',
    0.75,
    'Mechanical airway obstruction may require procedural or surgical
     intervention.'
),

-- =============================================================================
-- PNEUMONIA
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000035',
    'internal_medicine',
    'primary',
    1.00,
    'Core adult medical diagnosis.'
),
(
    'f0a00000-0000-0000-0000-000000000035',
    'family_medicine',
    'primary',
    0.95,
    'Common community-acquired infection managed or initially assessed in
     primary care.'
),
(
    'f0a00000-0000-0000-0000-000000000035',
    'paediatrics',
    'primary',
    1.00,
    'Major paediatric lower respiratory infection.'
),
(
    'f0a00000-0000-0000-0000-000000000035',
    'emergency_medicine',
    'primary',
    1.00,
    'Important acute presentation, particularly when hypoxaemic or severe.'
),
(
    'f0a00000-0000-0000-0000-000000000035',
    'surgery',
    'secondary',
    0.40,
    'Relevant to aspiration, postoperative pneumonia and complications
     requiring procedural intervention.'
),

-- =============================================================================
-- TUBERCULOSIS
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000039',
    'internal_medicine',
    'primary',
    1.00,
    'Major medical and infectious disease condition.'
),
(
    'f0a00000-0000-0000-0000-000000000039',
    'family_medicine',
    'primary',
    0.90,
    'Community-level screening, contact tracing and initial recognition.'
),
(
    'f0a00000-0000-0000-0000-000000000039',
    'paediatrics',
    'primary',
    0.90,
    'Important childhood infectious disease.'
),
(
    'f0a00000-0000-0000-0000-000000000039',
    'emergency_medicine',
    'secondary',
    0.60,
    'Relevant to acute respiratory and systemic presentations.'
),

-- =============================================================================
-- ACUTE BRONCHITIS
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000036',
    'family_medicine',
    'primary',
    1.00,
    'Common primary-care respiratory condition.'
),
(
    'f0a00000-0000-0000-0000-000000000036',
    'internal_medicine',
    'secondary',
    0.80,
    'Respiratory medical diagnosis requiring differentiation from pneumonia
     and chronic airway disease.'
),
(
    'f0a00000-0000-0000-0000-000000000036',
    'paediatrics',
    'secondary',
    0.65,
    'Relevant to selected paediatric respiratory presentations.'
),
(
    'f0a00000-0000-0000-0000-000000000036',
    'emergency_medicine',
    'secondary',
    0.55,
    'May present acutely but severity must be assessed.'
),

-- =============================================================================
-- CHEST X-RAY
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000042',
    'radiology',
    'primary',
    1.00,
    'Core radiological investigation.'
),
(
    'f0a00000-0000-0000-0000-000000000042',
    'internal_medicine',
    'secondary',
    0.90,
    'Frequently used in adult respiratory and cardiovascular assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000042',
    'paediatrics',
    'secondary',
    0.80,
    'Used selectively according to paediatric clinical context.'
),
(
    'f0a00000-0000-0000-0000-000000000042',
    'emergency_medicine',
    'primary',
    0.90,
    'Important emergency thoracic investigation.'
),
(
    'f0a00000-0000-0000-0000-000000000042',
    'surgery',
    'secondary',
    0.65,
    'Relevant to thoracic, trauma and perioperative assessment.'
),

-- =============================================================================
-- SPUTUM AFB
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000044',
    'laboratory_medicine',
    'primary',
    1.00,
    'Laboratory investigation of respiratory specimens.'
),
(
    'f0a00000-0000-0000-0000-000000000044',
    'internal_medicine',
    'primary',
    0.95,
    'Important investigation in suspected pulmonary tuberculosis.'
),
(
    'f0a00000-0000-0000-0000-000000000044',
    'family_medicine',
    'secondary',
    0.80,
    'Relevant to community TB evaluation pathways.'
),
(
    'f0a00000-0000-0000-0000-000000000044',
    'paediatrics',
    'secondary',
    0.65,
    'May contribute to investigation of selected paediatric TB presentations.'
),

-- =============================================================================
-- PULSE OXIMETRY
-- =============================================================================

(
    'f0a00000-0000-0000-0000-000000000043',
    'emergency_medicine',
    'primary',
    1.00,
    'Immediate assessment of oxygenation in acute illness.'
),
(
    'f0a00000-0000-0000-0000-000000000043',
    'internal_medicine',
    'primary',
    0.90,
    'Routine cardiorespiratory assessment in medical patients.'
),
(
    'f0a00000-0000-0000-0000-000000000043',
    'paediatrics',
    'primary',
    1.00,
    'Important objective measure in paediatric respiratory illness.'
),
(
    'f0a00000-0000-0000-0000-000000000043',
    'family_medicine',
    'secondary',
    0.70,
    'Useful in primary-care assessment where available.'
),
(
    'f0a00000-0000-0000-0000-000000000043',
    'surgery',
    'secondary',
    0.65,
    'Important perioperative and postoperative monitoring parameter.'
),

-- =============================================================================
-- RESPIRATORY FAILURE
-- =============================================================================

(
    'f0a00000-0000-0000-0000-00000000004e',
    'emergency_medicine',
    'primary',
    1.00,
    'Life-threatening emergency requiring immediate stabilisation.'
),
(
    'f0a00000-0000-0000-0000-00000000004e',
    'internal_medicine',
    'primary',
    1.00,
    'Major medical critical illness.'
),
(
    'f0a00000-0000-0000-0000-00000000004e',
    'paediatrics',
    'primary',
    0.95,
    'Critical paediatric emergency.'
),
(
    'f0a00000-0000-0000-0000-00000000004e',
    'surgery',
    'secondary',
    0.75,
    'May result from postoperative, thoracic, trauma or anaesthetic causes.'
),
(
    'f0a00000-0000-0000-0000-00000000004e',
    'family_medicine',
    'secondary',
    0.45,
    'Recognition and urgent referral are important in primary care.'
),

-- =============================================================================
-- HYPOXAEMIA
-- =============================================================================

(
    'f0a00000-0000-0000-0000-00000000004d',
    'emergency_medicine',
    'primary',
    1.00,
    'Potentially life-threatening abnormality requiring immediate assessment.'
),
(
    'f0a00000-0000-0000-0000-00000000004d',
    'internal_medicine',
    'primary',
    1.00,
    'Major physiological finding in cardiopulmonary disease.'
),
(
    'f0a00000-0000-0000-0000-00000000004d',
    'paediatrics',
    'primary',
    1.00,
    'Critical finding in paediatric respiratory disease.'
),
(
    'f0a00000-0000-0000-0000-00000000004d',
    'surgery',
    'secondary',
    0.70,
    'Important in postoperative, trauma and thoracic surgical patients.'
),
(
    'f0a00000-0000-0000-0000-00000000004d',
    'family_medicine',
    'secondary',
    0.60,
    'Important trigger for escalation and referral.'
)

ON CONFLICT (concept_id, specialty_code) DO NOTHING;


-- =============================================================================
-- Z8.3 OPTIONAL INTEGRITY CHECKS
-- =============================================================================
-- These do not alter clinical data.
-- They allow the seed/deployment pipeline to detect orphan concepts.
-- =============================================================================

DO $$
BEGIN

    IF EXISTS (
        SELECT 1
        FROM knowledge.concept c
        WHERE NOT EXISTS (
            SELECT 1
            FROM knowledge.concept_system cs
            WHERE cs.concept_id = c.id
        )
    ) THEN
        RAISE NOTICE
            'AMEXAN Z8 WARNING: one or more concepts have no body-system mapping.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM knowledge.concept c
        WHERE NOT EXISTS (
            SELECT 1
            FROM knowledge.concept_specialty csp
            WHERE csp.concept_id = c.id
        )
    ) THEN
        RAISE NOTICE
            'AMEXAN Z8 WARNING: one or more concepts have no specialty mapping.';
    END IF;

END
$$;


-- =============================================================================
-- END Z8
-- =============================================================================