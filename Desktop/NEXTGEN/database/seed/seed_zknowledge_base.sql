-- =============================================================================
-- AMEXAN PHASE 2 — SEED Z1
-- UNIVERSAL CLINICAL KNOWLEDGE BASE
-- FACT DEFINITIONS + CLINICAL CONCEPT ONTOLOGY
-- =============================================================================
--
-- PURPOSE
-- -------
-- This seed establishes the semantic vocabulary used by the AMEXAN Clinical CPU.
--
-- The CPU should NOT reason directly from UI labels such as:
--     "Cough"
--     "Fever"
--     "Chest pain"
--
-- It should reason from structured concepts and facts:
--
--     SYMPTOM
--        ↓
--     CHARACTERISTICS
--        ↓
--     ASSOCIATED FEATURES
--        ↓
--     RISK FACTORS
--        ↓
--     PHENOTYPE
--        ↓
--     MECHANISM
--        ↓
--     DIFFERENTIAL / CONDITION
--        ↓
--     INVESTIGATION
--        ↓
--     COMPLICATION
--
-- This seed is intentionally FACT/CONCEPT oriented.
-- Disease reasoning rules should be seeded separately.
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. Patient facts are separate from knowledge concepts.
-- 2. A symptom is not a diagnosis.
-- 3. A risk factor is not a diagnosis.
-- 4. A mechanism is not a diagnosis.
-- 5. Investigations are not diagnoses.
-- 6. Complications are not diagnoses.
-- 7. The same concept can participate in multiple clinical pathways.
-- 8. The CPU should select questions from structured context + active concepts.
-- 9. Longitudinal patient data should reference stable semantic concepts.
-- 10. External terminology mappings should be added separately.
--
-- IDEMPOTENCY
-- -----------
-- Uses ON CONFLICT so the seed can safely be re-run.
--
-- =============================================================================


BEGIN;

-- =============================================================================
-- 0. FACT DEFINITIONS
-- =============================================================================
--
-- Facts are structured observations/questions that the Clinical CPU can acquire.
--
-- IMPORTANT:
-- A fact definition does NOT mean the patient has that finding.
-- It defines the variable that the CPU may collect.
--
-- =============================================================================


INSERT INTO clinical.fact_definition
(code, name, data_type, description)
VALUES

-- -----------------------------------------------------------------------------
-- CORE SYMPTOM PRESENCE
-- -----------------------------------------------------------------------------

('COUGH_PRESENT',
 'Cough present',
 'coded',
 'Whether cough is present'),

('FEVER_PRESENT',
 'Fever present',
 'coded',
 'Whether fever is present'),

('DYSPNOEA_PRESENT',
 'Dyspnoea present',
 'coded',
 'Whether shortness of breath or difficulty breathing is present'),

('CHEST_PAIN_PRESENT',
 'Chest pain present',
 'coded',
 'Whether chest pain is present'),

('WHEEZE_PRESENT',
 'Wheeze present',
 'coded',
 'Whether wheeze is present'),

('HAEMOPTYSIS_PRESENT',
 'Haemoptysis present',
 'coded',
 'Whether blood is coughed up'),

('FATIGUE_PRESENT',
 'Fatigue present',
 'coded',
 'Whether clinically significant fatigue is present'),

('ORTHOPNOEA_PRESENT',
 'Orthopnoea present',
 'coded',
 'Whether breathing difficulty occurs when lying flat'),

('PND_PRESENT',
 'Paroxysmal nocturnal dyspnoea',
 'coded',
 'Whether the patient experiences nocturnal episodes of breathlessness'),

('PLEURITIC_PAIN_PRESENT',
 'Pleuritic chest pain',
 'coded',
 'Whether chest pain is related to respiration or coughing'),

-- -----------------------------------------------------------------------------
-- COUGH CHARACTERISTICS
-- -----------------------------------------------------------------------------

('COUGH_PRODUCTIVITY',
 'Cough productivity',
 'coded',
 'Whether cough is dry or productive'),

('COUGH_DURATION_DAYS',
 'Cough duration',
 'numeric',
 'Duration of cough in days'),

('COUGH_ONSET',
 'Cough onset',
 'coded',
 'Sudden, gradual or other onset'),

('COUGH_PATTERN',
 'Cough pattern',
 'coded',
 'Intermittent, persistent, nocturnal, episodic or other pattern'),

('COUGH_TIMING',
 'Cough timing',
 'coded',
 'Temporal pattern of cough'),

('COUGH_SEVERITY',
 'Cough severity',
 'coded',
 'Clinical severity of cough'),

('COUGH_TRIGGER',
 'Cough trigger',
 'coded',
 'Factors precipitating or worsening cough'),

('COUGH_RELIEF',
 'Cough relieving factors',
 'text',
 'Factors that improve cough'),

('COUGH_NIGHT',
 'Nocturnal cough',
 'coded',
 'Whether cough is predominantly nocturnal'),

('COUGH_EXERTIONAL',
 'Exertional cough',
 'coded',
 'Whether cough occurs or worsens with exertion'),

-- -----------------------------------------------------------------------------
-- SPUTUM
-- -----------------------------------------------------------------------------

('SPUTUM_PRESENT',
 'Sputum present',
 'coded',
 'Whether sputum is produced'),

('SPUTUM_COLOUR',
 'Sputum colour',
 'coded',
 'Colour/appearance of sputum'),

('SPUTUM_AMOUNT',
 'Sputum amount',
 'coded',
 'Approximate sputum quantity'),

('SPUTUM_CHARACTER',
 'Sputum character',
 'coded',
 'Serous, mucoid, mucopurulent, purulent or other character'),

('SPUTUM_ODOR',
 'Sputum odour',
 'coded',
 'Presence of abnormal sputum odour'),

('BLOOD_IN_SPUTUM',
 'Blood in sputum',
 'coded',
 'Presence and character of blood in sputum'),

('HAEMOPTYSIS_AMOUNT',
 'Haemoptysis amount',
 'coded',
 'Approximate amount/severity of haemoptysis'),

-- -----------------------------------------------------------------------------
-- FEVER
-- -----------------------------------------------------------------------------

('FEVER_ONSET',
 'Fever onset',
 'coded',
 'When and how fever began'),

('FEVER_DURATION_DAYS',
 'Fever duration',
 'numeric',
 'Duration of fever in days'),

('FEVER_PATTERN',
 'Fever pattern',
 'coded',
 'Pattern of fever over time'),

('FEVER_MAX_TEMPERATURE',
 'Maximum recorded temperature',
 'numeric',
 'Highest measured temperature'),

('FEVER_RIGORS',
 'Rigors',
 'coded',
 'Presence of shaking chills/rigors'),

('FEVER_NIGHT_SWEATS',
 'Fever-associated night sweats',
 'coded',
 'Night sweats associated with febrile illness'),

('ANTIPYRETIC_RESPONSE',
 'Response to antipyretics',
 'coded',
 'Clinical response to antipyretic medication'),

-- -----------------------------------------------------------------------------
-- DYSPNOEA
-- -----------------------------------------------------------------------------

('DYSPNOEA_ONSET',
 'Dyspnoea onset',
 'coded',
 'Onset pattern of dyspnoea'),

('DYSPNOEA_DURATION_DAYS',
 'Dyspnoea duration',
 'numeric',
 'Duration of dyspnoea'),

('DYSPNOEA_SEVERITY',
 'Dyspnoea severity',
 'coded',
 'Severity of breathing difficulty'),

('DYSPNOEA_AT_REST',
 'Dyspnoea at rest',
 'coded',
 'Whether dyspnoea occurs at rest'),

('DYSPNOEA_EXERTIONAL',
 'Exertional dyspnoea',
 'coded',
 'Whether dyspnoea occurs with exertion'),

('DYSPNOEA_PROGRESSIVE',
 'Progressive dyspnoea',
 'coded',
 'Whether dyspnoea is progressively worsening'),

('FUNCTIONAL_EXERCISE_LIMITATION',
 'Functional exercise limitation',
 'coded',
 'Impact of respiratory symptoms on activity'),

-- -----------------------------------------------------------------------------
-- CHEST PAIN
-- -----------------------------------------------------------------------------

('CHEST_PAIN_ONSET',
 'Chest pain onset',
 'coded',
 'Onset of chest pain'),

('CHEST_PAIN_DURATION',
 'Chest pain duration',
 'numeric',
 'Duration of chest pain'),

('CHEST_PAIN_SITE',
 'Chest pain site',
 'coded',
 'Anatomical location of chest pain'),

('CHEST_PAIN_CHARACTER',
 'Chest pain character',
 'coded',
 'Character of chest pain'),

('CHEST_PAIN_RADIATION',
 'Chest pain radiation',
 'coded',
 'Radiation of chest pain'),

('CHEST_PAIN_SEVERITY',
 'Chest pain severity',
 'coded',
 'Severity of chest pain'),

('CHEST_PAIN_EXERTIONAL',
 'Exertional chest pain',
 'coded',
 'Whether chest pain occurs with exertion'),

('CHEST_PAIN_PLEURITIC',
 'Pleuritic chest pain',
 'coded',
 'Whether pain is affected by breathing/coughing'),

('CHEST_PAIN_POSITIONAL',
 'Positional chest pain',
 'coded',
 'Whether pain changes with position'),

-- -----------------------------------------------------------------------------
-- WHEEZE / AIRWAY OBSTRUCTION
-- -----------------------------------------------------------------------------

('WHEEZE_ONSET',
 'Wheeze onset',
 'coded',
 'Onset of wheeze'),

('WHEEZE_DURATION',
 'Wheeze duration',
 'numeric',
 'Duration of wheeze'),

('WHEEZE_PATTERN',
 'Wheeze pattern',
 'coded',
 'Episodic, persistent, nocturnal or other pattern'),

('WHEEZE_TRIGGER',
 'Wheeze trigger',
 'coded',
 'Factors precipitating wheeze'),

('WHEEZE_RESPONSE_TO_BRONCHODILATOR',
 'Response to bronchodilator',
 'coded',
 'Clinical response to bronchodilator therapy'),

-- -----------------------------------------------------------------------------
-- TB / CHRONIC RESPIRATORY FEATURES
-- -----------------------------------------------------------------------------

('TB_CONTACT',
 'TB contact',
 'coded',
 'Known exposure to tuberculosis'),

('TB_CONTACT_DURATION',
 'TB contact duration',
 'numeric',
 'Duration since or period of exposure to TB'),

('WEIGHT_LOSS',
 'Weight loss',
 'coded',
 'Unintentional weight loss'),

('WEIGHT_LOSS_AMOUNT',
 'Weight loss amount',
 'numeric',
 'Magnitude of unintentional weight loss'),

('NIGHT_SWEATS',
 'Night sweats',
 'coded',
 'Presence of significant night sweats'),

('CHRONIC_COUGH',
 'Chronic cough',
 'coded',
 'Cough meeting the relevant chronicity context'),

('TB_PREVIOUS_HISTORY',
 'Previous tuberculosis',
 'coded',
 'Previous history of tuberculosis'),

('TB_TREATMENT_HISTORY',
 'Previous TB treatment',
 'coded',
 'Previous tuberculosis treatment'),

('TB_TREATMENT_COMPLETION',
 'TB treatment completion',
 'coded',
 'Whether previous TB treatment was completed'),

-- -----------------------------------------------------------------------------
-- EXPOSURE / ENVIRONMENT
-- -----------------------------------------------------------------------------

('SMOKING_STATUS',
 'Smoking status',
 'coded',
 'Current, former or never smoker'),

('SMOKING_PACK_YEARS',
 'Smoking pack-years',
 'numeric',
 'Cumulative smoking exposure'),

('BIOMASS_FUEL_EXPOSURE',
 'Biomass fuel exposure',
 'coded',
 'Exposure to biomass/solid fuel smoke'),

('INDOOR_AIR_POLLUTION',
 'Indoor air pollution',
 'coded',
 'Relevant indoor air pollution exposure'),

('OCCUPATIONAL_RESPIRATORY_EXPOSURE',
 'Occupational respiratory exposure',
 'coded',
 'Occupational exposure to respiratory hazards'),

('DUST_EXPOSURE',
 'Dust exposure',
 'coded',
 'Exposure to dust'),

('CHEMICAL_INHALATION',
 'Chemical inhalation exposure',
 'coded',
 'Exposure to inhaled chemicals/irritants'),

('CROWDING_EXPOSURE',
 'Household crowding',
 'coded',
 'Relevant household crowding'),

('ANIMAL_EXPOSURE',
 'Animal exposure',
 'coded',
 'Relevant animal exposure'),

-- -----------------------------------------------------------------------------
-- IMMUNE / HOST FACTORS
-- -----------------------------------------------------------------------------

('IMMUNOCOMPROMISED_STATUS',
 'Immunocompromised status',
 'coded',
 'Presence of clinically relevant immune compromise'),

('HIV_STATUS_RELEVANT',
 'HIV status relevant',
 'coded',
 'Whether HIV status is clinically relevant to the current presentation'),

('IMMUNOSUPPRESSIVE_MEDICATION',
 'Immunosuppressive medication',
 'coded',
 'Current exposure to immunosuppressive medication'),

('MALNUTRITION_STATUS',
 'Malnutrition status',
 'coded',
 'Relevant nutritional compromise'),

('PREMATURE_BIRTH',
 'Prematurity',
 'coded',
 'History of preterm birth'),

-- -----------------------------------------------------------------------------
-- PAEDIATRIC RESPIRATORY FEATURES
-- -----------------------------------------------------------------------------

('AGE_IN_MONTHS',
 'Age in months',
 'numeric',
 'Age in months for paediatric assessment'),

('FEEDING_DIFFICULTY',
 'Feeding difficulty',
 'coded',
 'Difficulty feeding during illness'),

('POOR_FEEDING',
 'Poor feeding',
 'coded',
 'Reduced feeding compared with baseline'),

('APNOEA_PRESENT',
 'Apnoea present',
 'coded',
 'Observed or reported apnoeic episodes'),

('GRUNTING_PRESENT',
 'Grunting present',
 'coded',
 'Presence of expiratory grunting'),

('NASAL_FLARING',
 'Nasal flaring',
 'coded',
 'Presence of nasal flaring'),

('CHEST_INDRAWING',
 'Chest indrawing',
 'coded',
 'Presence of chest wall indrawing'),

('CYANOS_PRESENT',
 'Cyanosis present',
 'coded',
 'Presence of clinically apparent cyanosis'),

('IRRITABILITY',
 'Irritability',
 'coded',
 'Abnormal irritability during illness'),

('LETHARGY',
 'Lethargy',
 'coded',
 'Abnormal reduction in activity/responsiveness'),

-- -----------------------------------------------------------------------------
-- CARDIAC / CONGESTIVE FEATURES
-- -----------------------------------------------------------------------------

('LEG_SWELLING',
 'Leg swelling',
 'coded',
 'Peripheral lower limb swelling'),

('RAISED_JVP',
 'Raised JVP',
 'coded',
 'Elevated jugular venous pressure'),

('PND_FREQUENCY',
 'PND frequency',
 'numeric',
 'Frequency of paroxysmal nocturnal dyspnoea'),

('ORTHOPNOEA_PILLOWS',
 'Number of pillows for orthopnoea',
 'numeric',
 'Number of pillows used because of breathing difficulty'),

('PALPITATIONS',
 'Palpitations',
 'coded',
 'Awareness of heartbeat'),

-- -----------------------------------------------------------------------------
-- THROMBOEMBOLIC RISK
-- -----------------------------------------------------------------------------

('RECENT_SURGERY',
 'Recent surgery',
 'coded',
 'Recent surgical procedure'),

('RECENT_IMMOBILIZATION',
 'Recent immobilization',
 'coded',
 'Recent prolonged immobilization'),

('PREVIOUS_VTE',
 'Previous venous thromboembolism',
 'coded',
 'Previous DVT or pulmonary embolism'),

('ACTIVE_MALIGNANCY',
 'Active malignancy',
 'coded',
 'Known active malignancy'),

('OESTROGEN_EXPOSURE',
 'Oestrogen exposure',
 'coded',
 'Relevant oestrogen exposure'),

('LONG_DISTANCE_TRAVEL',
 'Recent long-distance travel',
 'coded',
 'Recent prolonged travel'),

-- -----------------------------------------------------------------------------
-- MEDICATION / RESPONSE
-- -----------------------------------------------------------------------------

('CURRENT_MEDICATIONS',
 'Current medications',
 'text',
 'Current medication exposure'),

('RECENT_ANTIBIOTIC_USE',
 'Recent antibiotic use',
 'coded',
 'Recent antimicrobial exposure'),

('RECENT_STEROID_USE',
 'Recent corticosteroid use',
 'coded',
 'Recent systemic or inhaled corticosteroid exposure'),

('BRONCHODILATOR_USE',
 'Bronchodilator use',
 'coded',
 'Current/recent bronchodilator use'),

('MEDICATION_RESPONSE',
 'Response to medication',
 'coded',
 'Clinical response to previous treatment'),

-- -----------------------------------------------------------------------------
-- OBJECTIVE RESPIRATORY FACTS
-- -----------------------------------------------------------------------------

('RESPIRATORY_RATE',
 'Respiratory rate',
 'numeric',
 'Respiratory rate per minute'),

('OXYGEN_SATURATION',
 'Oxygen saturation',
 'numeric',
 'Peripheral oxygen saturation'),

('OXYGEN_SUPPLEMENTATION',
 'Supplemental oxygen',
 'coded',
 'Whether supplemental oxygen is being administered'),

('OXYGEN_FLOW_RATE',
 'Oxygen flow rate',
 'numeric',
 'Supplemental oxygen flow rate'),

('BODY_TEMPERATURE',
 'Body temperature',
 'numeric',
 'Measured body temperature'),

('HEART_RATE',
 'Heart rate',
 'numeric',
 'Heart rate per minute'),

('BLOOD_PRESSURE_SYSTOLIC',
 'Systolic blood pressure',
 'numeric',
 'Systolic blood pressure'),

('BLOOD_PRESSURE_DIASTOLIC',
 'Diastolic blood pressure',
 'numeric',
 'Diastolic blood pressure'),

-- -----------------------------------------------------------------------------
-- EXAMINATION
-- -----------------------------------------------------------------------------

('WORK_OF_BREATHING',
 'Work of breathing',
 'coded',
 'Observed degree of respiratory effort'),

('AIR_ENTRY',
 'Air entry',
 'coded',
 'Quality and symmetry of air entry'),

('CRACKLES_PRESENT',
 'Crackles',
 'coded',
 'Presence of crackles on auscultation'),

('BRONCHIAL_BREATH_SOUNDS',
 'Bronchial breath sounds',
 'coded',
 'Presence of bronchial breath sounds'),

('PLEURAL_RUB',
 'Pleural rub',
 'coded',
 'Presence of pleural friction rub'),

('DULLNESS_TO_PERCUSSION',
 'Dullness to percussion',
 'coded',
 'Presence of percussion dullness'),

('HYPERRESONANCE',
 'Hyperresonance',
 'coded',
 'Presence of hyperresonance on percussion'),

('CLUBBING',
 'Clubbing',
 'coded',
 'Presence of digital clubbing'),

-- -----------------------------------------------------------------------------
-- INVESTIGATION FACTS
-- -----------------------------------------------------------------------------

('CHEST_XRAY_RESULT',
 'Chest X-ray result',
 'text',
 'Clinical interpretation of chest radiograph'),

('LUNG_ULTRASOUND_RESULT',
 'Lung ultrasound result',
 'text',
 'Clinical interpretation of lung ultrasound'),

('FULL_BLOOD_COUNT_RESULT',
 'Full blood count result',
 'text',
 'Relevant full blood count findings'),

('CRP_RESULT',
 'C-reactive protein result',
 'numeric',
 'C-reactive protein measurement'),

('BLOOD_CULTURE_RESULT',
 'Blood culture result',
 'text',
 'Blood culture result'),

('SPUTUM_AFB_RESULT',
 'Sputum AFB result',
 'text',
 'Acid-fast bacilli result'),

('TB_MOLECULAR_TEST_RESULT',
 'TB molecular test result',
 'text',
 'Molecular tuberculosis test result'),

('ARTERIAL_BLOOD_GAS',
 'Arterial blood gas',
 'text',
 'Arterial blood gas findings'),

('D_DIMER_RESULT',
 'D-dimer result',
 'numeric',
 'D-dimer measurement'),

('ECG_RESULT',
 'ECG result',
 'text',
 'Electrocardiographic interpretation'),

-- -----------------------------------------------------------------------------
-- CLINICAL SEVERITY / COMPLICATIONS
-- -----------------------------------------------------------------------------

('HYPOXAEMIA_PRESENT',
 'Hypoxaemia',
 'coded',
 'Evidence of low blood oxygenation'),

('RESPIRATORY_DISTRESS',
 'Respiratory distress',
 'coded',
 'Clinical respiratory distress'),

('RESPIRATORY_FAILURE',
 'Respiratory failure',
 'coded',
 'Clinical respiratory failure'),

('SEPSIS_FEATURES',
 'Sepsis features',
 'coded',
 'Features concerning for systemic infection/sepsis'),

('HAEMODYNAMIC_INSTABILITY',
 'Haemodynamic instability',
 'coded',
 'Evidence of circulatory instability'),

('ALTERED_MENTAL_STATUS',
 'Altered mental status',
 'coded',
 'Altered consciousness or cognition'),

('DEHYDRATION_STATUS',
 'Dehydration status',
 'coded',
 'Clinical degree of dehydration'),

('PLEURAL_EFFUSION_PRESENT',
 'Pleural effusion',
 'coded',
 'Evidence of pleural fluid'),

('PNEUMOTHORAX_PRESENT',
 'Pneumothorax',
 'coded',
 'Evidence of pneumothorax'),

('EMPYEMA_PRESENT',
 'Empyema',
 'coded',
 'Evidence of infected pleural collection'),

-- -----------------------------------------------------------------------------
-- RESPONSE / LONGITUDINAL CHANGE
-- -----------------------------------------------------------------------------

('SYMPTOM_IMPROVEMENT',
 'Symptom improvement',
 'coded',
 'Whether symptoms are improving'),

('SYMPTOM_WORSENING',
 'Symptom worsening',
 'coded',
 'Whether symptoms are worsening'),

('NEW_SYMPTOM',
 'New symptom',
 'text',
 'New symptom occurring during longitudinal follow-up'),

('TREATMENT_FAILURE',
 'Treatment failure',
 'coded',
 'Evidence that treatment has not achieved expected response'),

('RECURRENCE',
 'Recurrence',
 'coded',
 'Recurrence of previously documented clinical problem'),

('RELAPSE',
 'Relapse',
 'coded',
 'Relapse after apparent clinical improvement'),

('FOLLOW_UP_STATUS',
 'Follow-up status',
 'coded',
 'Clinical status at follow-up')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 1. CORE SYMPTOM CONCEPTS
-- =============================================================================


INSERT INTO knowledge.concept
(id, concept_code, concept_type, canonical_name, display_name, description)
VALUES

('f0a00000-0000-0000-0000-000000000001',
 'CNS-COUGH',
 'symptom',
 'Cough',
 'Cough',
 'Expulsive reflex producing forceful expiration'),

('f0a00000-0000-0000-0000-000000000002',
 'CNS-FEVER',
 'symptom',
 'Fever',
 'Fever',
 'Elevated body temperature associated with an altered thermoregulatory set point'),

('f0a00000-0000-0000-0000-000000000003',
 'CNS-DYSPNOEA',
 'symptom',
 'Dyspnoea',
 'Shortness of breath',
 'Subjective breathing discomfort or difficulty breathing'),

('f0a00000-0000-0000-0000-000000000004',
 'CNS-HAEMOPTYSIS',
 'symptom',
 'Haemoptysis',
 'Coughing blood',
 'Expectoration of blood originating from the lower respiratory tract'),

('f0a00000-0000-0000-0000-000000000005',
 'CNS-WHEEZE',
 'symptom',
 'Wheeze',
 'Wheeze',
 'Continuous musical respiratory sound associated with airflow limitation'),

('f0a00000-0000-0000-0000-000000000006',
 'CNS-CHEST-PAIN',
 'symptom',
 'Chest pain',
 'Chest pain',
 'Pain perceived in the thoracic region'),

('f0a00000-0000-0000-0000-000000000007',
 'CNS-FATIGUE',
 'symptom',
 'Fatigue',
 'Fatigue',
 'Subjective lack of energy or reduced capacity for activity'),

('f0a00000-0000-0000-0000-000000000008',
 'CNS-ORTHOPNOEA',
 'symptom',
 'Orthopnoea',
 'Orthopnoea',
 'Breathlessness occurring when lying flat and relieved by sitting or standing'),

('f0a00000-0000-0000-0000-000000000009',
 'CNS-PND',
 'symptom',
 'Paroxysmal nocturnal dyspnoea',
 'PND',
 'Episodes of nocturnal breathlessness causing awakening from sleep'),

('f0a00000-0000-0000-0000-00000000000a',
 'CNS-PLEURITIC-PAIN',
 'symptom',
 'Pleuritic chest pain',
 'Pleuritic pain',
 'Chest pain associated with respiration or coughing'),

-- =============================================================================
-- 2. SYMPTOM FINDINGS
-- =============================================================================

('f0a00000-0000-0000-0000-00000000000b',
 'CNS-PRODUCTIVE-COUGH',
 'finding',
 'Productive cough',
 'Productive cough',
 'Cough associated with sputum production'),

('f0a00000-0000-0000-0000-00000000000c',
 'CNS-PURULENT-SPUTUM',
 'finding',
 'Purulent sputum',
 'Purulent sputum',
 'Sputum with purulent character'),

('f0a00000-0000-0000-0000-00000000000d',
 'CNS-HAEMOPTYSIS-FINDING',
 'finding',
 'Blood in sputum',
 'Blood in sputum',
 'Blood occurring in expectorated respiratory secretions'),

('f0a00000-0000-0000-0000-00000000000e',
 'CNS-WEIGHT-LOSS',
 'finding',
 'Weight loss',
 'Weight loss',
 'Unintentional reduction in body weight'),

('f0a00000-0000-0000-0000-00000000000f',
 'CNS-NIGHT-SWEATS',
 'finding',
 'Night sweats',
 'Night sweats',
 'Clinically significant nocturnal sweating'),

('f0a00000-0000-0000-0000-000000000010',
 'CNS-CRACKLES',
 'finding',
 'Crackles',
 'Crackles',
 'Discontinuous adventitious respiratory sounds'),

('f0a00000-0000-0000-0000-000000000011',
 'CNS-BRONCHIAL-BREATH-SOUNDS',
 'finding',
 'Bronchial breath sounds',
 'Bronchial breath sounds',
 'Abnormally bronchial character of breath sounds over peripheral lung fields'),

('f0a00000-0000-0000-0000-000000000012',
 'CNS-CHEST-INDRAWING',
 'finding',
 'Chest indrawing',
 'Chest indrawing',
 'Visible inward movement of the chest wall during respiration'),

('f0a00000-0000-0000-0000-000000000013',
 'CNS-GRUNTING',
 'finding',
 'Grunting',
 'Grunting',
 'Expiratory grunting associated with increased respiratory effort'),

('f0a00000-0000-0000-0000-000000000014',
 'CNS-NASAL-FLARING',
 'finding',
 'Nasal flaring',
 'Nasal flaring',
 'Widening of the nostrils during inspiration'),

('f0a00000-0000-0000-0000-000000000015',
 'CNS-CLUBBING',
 'finding',
 'Digital clubbing',
 'Clubbing',
 'Abnormal enlargement of the distal digits with characteristic nail-bed changes'),

-- =============================================================================
-- 3. RISK FACTORS / EXPOSURES
-- =============================================================================

('f0a00000-0000-0000-0000-000000000016',
 'CNS-TB-EXPOSURE',
 'risk_factor',
 'Tuberculosis exposure',
 'TB contact',
 'Known or epidemiologically relevant exposure to tuberculosis'),

('f0a00000-0000-0000-0000-000000000017',
 'CNS-SMOKING',
 'risk_factor',
 'Tobacco smoking',
 'Smoking',
 'Current or previous tobacco exposure'),

('f0a00000-0000-0000-0000-000000000018',
 'CNS-BIOMASS-EXPOSURE',
 'risk_factor',
 'Biomass smoke exposure',
 'Biomass exposure',
 'Exposure to smoke from biomass or solid fuels'),

('f0a00000-0000-0000-0000-000000000019',
 'CNS-OCCUPATIONAL-EXPOSURE',
 'risk_factor',
 'Occupational respiratory exposure',
 'Occupational exposure',
 'Occupational exposure to respiratory hazards'),

('f0a00000-0000-0000-0000-00000000001a',
 'CNS-DUST-EXPOSURE',
 'risk_factor',
 'Dust exposure',
 'Dust exposure',
 'Relevant inhalational dust exposure'),

('f0a00000-0000-0000-0000-00000000001b',
 'CNS-CROWDING',
 'risk_factor',
 'Household crowding',
 'Crowding',
 'Close living conditions increasing exposure to transmissible respiratory illness'),

('f0a00000-0000-0000-0000-00000000001c',
 'CNS-IMMUNOCOMPROMISED',
 'risk_factor',
 'Immunocompromised state',
 'Immunocompromised',
 'Reduced host immune competence'),

('f0a00000-0000-0000-0000-00000000001d',
 'CNS-MALNUTRITION',
 'risk_factor',
 'Malnutrition',
 'Malnutrition',
 'Nutritional compromise affecting host health'),

('f0a00000-0000-0000-0000-00000000001e',
 'CNS-PREVIOUS-VTE',
 'risk_factor',
 'Previous venous thromboembolism',
 'Previous VTE',
 'Previous deep venous thrombosis or pulmonary embolism'),

('f0a00000-0000-0000-0000-00000000001f',
 'CNS-RECENT-IMMOBILIZATION',
 'risk_factor',
 'Recent immobilization',
 'Recent immobilization',
 'Recent prolonged reduction in mobility'),

('f0a00000-0000-0000-0000-000000000020',
 'CNS-RECENT-SURGERY',
 'risk_factor',
 'Recent surgery',
 'Recent surgery',
 'Recent surgical intervention relevant to current illness'),

-- =============================================================================
-- 4. PATHOPHYSIOLOGICAL MECHANISMS
-- =============================================================================

('f0a00000-0000-0000-0000-000000000021',
 'CNS-AIRWAY-INFLAMMATION',
 'mechanism',
 'Airway inflammation',
 'Airway inflammation',
 'Inflammation involving conducting airways'),

('f0a00000-0000-0000-0000-000000000022',
 'CNS-ALVEOLAR-INFLAMMATION',
 'mechanism',
 'Alveolar inflammation',
 'Alveolar inflammation',
 'Inflammatory involvement of alveolar/lung parenchymal tissue'),

('f0a00000-0000-0000-0000-000000000023',
 'CNS-AIRWAY-OBSTRUCTION',
 'mechanism',
 'Airway obstruction',
 'Airway obstruction',
 'Restriction of airflow through the conducting airways'),

('f0a00000-0000-0000-0000-000000000024',
 'CNS-BRONCHOSPASM',
 'mechanism',
 'Bronchospasm',
 'Bronchospasm',
 'Reversible or variable narrowing of airways due to bronchial smooth-muscle constriction'),

('f0a00000-0000-0000-0000-000000000025',
 'CNS-PLEURAL-INFLAMMATION',
 'mechanism',
 'Pleural inflammation',
 'Pleural inflammation',
 'Inflammatory involvement of the pleura'),

('f0a00000-0000-0000-0000-000000000026',
 'CNS-ALVEOLAR-FILLING',
 'mechanism',
 'Alveolar filling',
 'Alveolar filling',
 'Accumulation of inflammatory fluid, cells, blood or other material within alveoli'),

('f0a00000-0000-0000-0000-000000000027',
 'CNS-PULMONARY-VASCULAR-OCCLUSION',
 'mechanism',
 'Pulmonary vascular occlusion',
 'Pulmonary vascular occlusion',
 'Obstruction of pulmonary vascular blood flow'),

('f0a00000-0000-0000-0000-000000000028',
 'CNS-PULMONARY-CONGESTION',
 'mechanism',
 'Pulmonary congestion',
 'Pulmonary congestion',
 'Increased pulmonary vascular/interstitial fluid associated with congestion'),

('f0a00000-0000-0000-0000-000000000029',
 'CNS-GAS-EXCHANGE-IMPAIRMENT',
 'mechanism',
 'Impaired gas exchange',
 'Gas-exchange impairment',
 'Impaired transfer of oxygen and/or carbon dioxide across the respiratory system'),

('f0a00000-0000-0000-0000-00000000002a',
 'CNS-VENTILATION-PERFUSION-MISMATCH',
 'mechanism',
 'Ventilation-perfusion mismatch',
 'V/Q mismatch',
 'Mismatch between alveolar ventilation and pulmonary perfusion'),

('f0a00000-0000-0000-0000-00000000002b',
 'CNS-HYPOVENTILATION',
 'mechanism',
 'Alveolar hypoventilation',
 'Hypoventilation',
 'Inadequate alveolar ventilation relative to metabolic demand'),

-- =============================================================================
-- 5. CLINICAL PHENOTYPES
-- =============================================================================

('f0a00000-0000-0000-0000-00000000002c',
 'CNS-ACUTE-INFECTIVE-RESPIRATORY',
 'phenotype',
 'Acute infective respiratory phenotype',
 'Acute infective respiratory',
 'Acute respiratory presentation with features suggestive of infection'),

('f0a00000-0000-0000-0000-00000000002d',
 'CNS-OBSTRUCTIVE-AIRWAY',
 'phenotype',
 'Obstructive airway phenotype',
 'Obstructive airway',
 'Clinical pattern dominated by variable or persistent airflow obstruction'),

('f0a00000-0000-0000-0000-00000000002e',
 'CNS-CHRONIC-INFECTIVE-RESPIRATORY',
 'phenotype',
 'Chronic infective respiratory phenotype',
 'Chronic infective respiratory',
 'Chronic respiratory presentation with infectious features'),

('f0a00000-0000-0000-0000-00000000002f',
 'CNS-CARDIOPULMONARY-CONGESTIVE',
 'phenotype',
 'Cardiopulmonary congestive phenotype',
 'Congestive cardiopulmonary',
 'Respiratory presentation associated with features of circulatory congestion'),

('f0a00000-0000-0000-0000-000000000030',
 'CNS-ACUTE-HYPOXAEMIC',
 'phenotype',
 'Acute hypoxaemic respiratory phenotype',
 'Acute hypoxaemic respiratory',
 'Acute respiratory presentation associated with impaired oxygenation'),

('f0a00000-0000-0000-0000-000000000031',
 'CNS-PAEDIATRIC-LRT',
 'phenotype',
 'Paediatric lower respiratory phenotype',
 'Paediatric lower respiratory',
 'Lower respiratory presentation in a child'),

('f0a00000-0000-0000-0000-000000000032',
 'CNS-UPPER-AIRWAY-INFLAMMATORY',
 'phenotype',
 'Upper airway inflammatory phenotype',
 'Upper airway inflammatory',
 'Upper airway presentation dominated by inflammatory symptoms/signs'),

('f0a00000-0000-0000-0000-000000000033',
 'CNS-THROMBOEMBOLIC-RESPIRATORY',
 'phenotype',
 'Thromboembolic respiratory phenotype',
 'Thromboembolic respiratory',
 'Respiratory presentation compatible with pulmonary vascular thromboembolism'),

('f0a00000-0000-0000-0000-000000000034',
 'CNS-PLEURAL-PHENOTYPE',
 'phenotype',
 'Pleural phenotype',
 'Pleural disease phenotype',
 'Presentation dominated by pleural symptoms or findings'),

-- =============================================================================
-- 6. CONDITIONS / DIFFERENTIAL DIAGNOSES
-- =============================================================================

('f0a00000-0000-0000-0000-000000000035',
 'CNS-PNEUMONIA',
 'condition',
 'Pneumonia',
 'Pneumonia',
 'Infection/inflammation involving lung parenchyma'),

('f0a00000-0000-0000-0000-000000000036',
 'CNS-ACUTE-BRONCHITIS',
 'condition',
 'Acute bronchitis',
 'Acute bronchitis',
 'Acute inflammatory illness involving the bronchi'),

('f0a00000-0000-0000-0000-000000000037',
 'CNS-ASTHMA',
 'condition',
 'Asthma',
 'Asthma',
 'Chronic inflammatory airway disorder characterized by variable respiratory symptoms and airflow limitation'),

('f0a00000-0000-0000-0000-000000000038',
 'CNS-COPD',
 'condition',
 'Chronic obstructive pulmonary disease',
 'COPD',
 'Chronic respiratory disease characterized by persistent airflow limitation'),

('f0a00000-0000-0000-0000-000000000039',
 'CNS-TUBERCULOSIS',
 'condition',
 'Tuberculosis',
 'TB',
 'Infectious disease caused by organisms of the Mycobacterium tuberculosis complex'),

('f0a00000-0000-0000-0000-00000000003a',
 'CNS-PULMONARY-EMBOLISM',
 'condition',
 'Pulmonary embolism',
 'Pulmonary embolism',
 'Pulmonary arterial obstruction, commonly caused by thromboembolism'),

('f0a00000-0000-0000-0000-00000000003b',
 'CNS-HEART-FAILURE',
 'condition',
 'Heart failure',
 'Heart failure',
 'Clinical syndrome resulting from structural or functional cardiac abnormality'),

('f0a00000-0000-0000-0000-00000000003c',
 'CNS-BRONCHIOLITIS',
 'condition',
 'Bronchiolitis',
 'Bronchiolitis',
 'Acute lower-airway inflammatory illness occurring predominantly in infants'),

('f0a00000-0000-0000-0000-00000000003d',
 'CNS-CROUP',
 'condition',
 'Croup',
 'Croup',
 'Acute upper-airway illness characterized by barking cough and upper-airway obstruction'),

('f0a00000-0000-0000-0000-00000000003e',
 'CNS-FOREIGN-BODY-ASPIRATION',
 'condition',
 'Foreign body aspiration',
 'Foreign body aspiration',
 'Airway obstruction caused by an aspirated foreign body'),

('f0a00000-0000-0000-0000-00000000003f',
 'CNS-PLEURAL-EFFUSION',
 'condition',
 'Pleural effusion',
 'Pleural effusion',
 'Abnormal accumulation of fluid within the pleural space'),

('f0a00000-0000-0000-0000-000000000040',
 'CNS-PNEUMOTHORAX',
 'condition',
 'Pneumothorax',
 'Pneumothorax',
 'Presence of air within the pleural space'),

('f0a00000-0000-0000-0000-000000000041',
 'CNS-PULMONARY-OEDEMA',
 'condition',
 'Pulmonary oedema',
 'Pulmonary oedema',
 'Accumulation of fluid within pulmonary interstitial/alveolar compartments'),

-- =============================================================================
-- 7. INVESTIGATIONS
-- =============================================================================

('f0a00000-0000-0000-0000-000000000042',
 'CNS-CHEST-XRAY',
 'investigation',
 'Chest X-ray',
 'Chest X-ray',
 'Plain radiographic examination of the chest'),

('f0a00000-0000-0000-0000-000000000043',
 'CNS-PULSE-OXIMETRY',
 'investigation',
 'Pulse oximetry',
 'SpO2',
 'Non-invasive measurement of peripheral oxygen saturation'),

('f0a00000-0000-0000-0000-000000000044',
 'CNS-SPUTUM-AFB',
 'investigation',
 'Sputum acid-fast bacilli examination',
 'Sputum AFB',
 'Laboratory examination for acid-fast bacilli in respiratory specimens'),

('f0a00000-0000-0000-0000-000000000045',
 'CNS-TB-MOLECULAR-TEST',
 'investigation',
 'Tuberculosis molecular test',
 'TB molecular test',
 'Molecular diagnostic test for tuberculosis and relevant resistance markers'),

('f0a00000-0000-0000-0000-000000000046',
 'CNS-CULTURE',
 'investigation',
 'Microbiological culture',
 'Culture',
 'Microbiological culture of an appropriate clinical specimen'),

('f0a00000-0000-0000-0000-000000000047',
 'CNS-FULL-BLOOD-COUNT',
 'investigation',
 'Full blood count',
 'FBC',
 'Laboratory assessment of circulating blood cell populations'),

('f0a00000-0000-0000-0000-000000000048',
 'CNS-CRP',
 'investigation',
 'C-reactive protein',
 'CRP',
 'Measurement of C-reactive protein as an inflammatory biomarker'),

('f0a00000-0000-0000-0000-000000000049',
 'CNS-ARTERIAL-BLOOD-GAS',
 'investigation',
 'Arterial blood gas',
 'ABG',
 'Measurement of arterial blood gases and acid-base status'),

('f0a00000-0000-0000-0000-00000000004a',
 'CNS-ECG',
 'investigation',
 'Electrocardiogram',
 'ECG',
 'Electrocardiographic assessment'),

('f0a00000-0000-0000-0000-00000000004b',
 'CNS-D-DIMER',
 'investigation',
 'D-dimer',
 'D-dimer',
 'Measurement of circulating fibrin degradation products'),

('f0a00000-0000-0000-0000-00000000004c',
 'CNS-LUNG-ULTRASOUND',
 'investigation',
 'Lung ultrasound',
 'Lung ultrasound',
 'Ultrasonographic assessment of the lungs and pleural space'),

-- =============================================================================
-- 8. COMPLICATIONS / HIGH-RISK STATES
-- =============================================================================

('f0a00000-0000-0000-0000-00000000004d',
 'CNS-HYPOXAEMIA',
 'finding',
 'Hypoxaemia',
 'Hypoxaemia',
 'Reduced oxygenation of arterial blood'),

('f0a00000-0000-0000-0000-00000000004e',
 'CNS-RESPIRATORY-FAILURE',
 'complication',
 'Respiratory failure',
 'Respiratory failure',
 'Failure of the respiratory system to maintain adequate gas exchange'),

('f0a00000-0000-0000-0000-00000000004f',
 'CNS-RESPIRATORY-DISTRESS',
 'complication',
 'Respiratory distress',
 'Respiratory distress',
 'Clinically significant increased work of breathing'),

('f0a00000-0000-0000-0000-000000000050',
 'CNS-SEPSIS',
 'complication',
 'Sepsis',
 'Sepsis',
 'Life-threatening organ dysfunction associated with a dysregulated response to infection'),

('f0a00000-0000-0000-0000-000000000051',
 'CNS-EMPYEMA',
 'complication',
 'Empyema',
 'Empyema',
 'Infected collection of pus within the pleural space'),

('f0a00000-0000-0000-0000-000000000052',
 'CNS-PLEURAL-COMPLICATION',
 'complication',
 'Pleural complication',
 'Pleural complication',
 'Clinically important pleural complication of pulmonary disease'),

('f0a00000-0000-0000-0000-000000000053',
 'CNS-HAEMODYNAMIC-INSTABILITY',
 'complication',
 'Haemodynamic instability',
 'Haemodynamic instability',
 'Clinically significant circulatory instability'),

('f0a00000-0000-0000-0000-000000000054',
 'CNS-ALTERED-MENTAL-STATUS',
 'finding',
 'Altered mental status',
 'Altered mental status',
 'Change in level or quality of consciousness or cognition')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. CONCEPT ALIASES / ADDITIONAL SEMANTIC CONCEPTS
-- =============================================================================
--
-- These are intentionally separate concepts where AMEXAN may need to distinguish
-- clinically meaningful states rather than collapsing them into one generic term.
-- =============================================================================


INSERT INTO knowledge.concept
(id, concept_code, concept_type, canonical_name, display_name, description)
VALUES

('f0a00000-0000-0000-0000-000000000055',
 'CNS-ACUTE-COUGH',
 'phenotype',
 'Acute cough phenotype',
 'Acute cough',
 'Cough occurring in an acute temporal context'),

('f0a00000-0000-0000-0000-000000000056',
 'CNS-SUBACUTE-COUGH',
 'phenotype',
 'Subacute cough phenotype',
 'Subacute cough',
 'Cough occurring in a subacute temporal context'),

('f0a00000-0000-0000-0000-000000000057',
 'CNS-CHRONIC-COUGH',
 'phenotype',
 'Chronic cough phenotype',
 'Chronic cough',
 'Cough occurring in a chronic temporal context'),

('f0a00000-0000-0000-0000-000000000058',
 'CNS-HYPOXIC-RESPIRATORY-STATE',
 'phenotype',
 'Hypoxic respiratory state',
 'Hypoxic respiratory state',
 'Respiratory presentation characterized by clinically significant impaired oxygenation'),

('f0a00000-0000-0000-0000-000000000059',
 'CNS-SYSTEMIC-INFECTIVE-PHENOTYPE',
 'phenotype',
 'Systemic infective phenotype',
 'Systemic infective',
 'Clinical pattern suggesting systemic infectious illness'),

('f0a00000-0000-0000-0000-00000000005a',
 'CNS-CHILD-RESPIRATORY-DISTRESS',
 'phenotype',
 'Paediatric respiratory distress phenotype',
 'Paediatric respiratory distress',
 'Respiratory distress phenotype in a child'),

('f0a00000-0000-0000-0000-00000000005b',
 'CNS-CARDIAC-DYSPNOEA',
 'phenotype',
 'Cardiac dyspnoea phenotype',
 'Cardiac dyspnoea',
 'Dyspnoea pattern with features suggesting a cardiovascular contribution'),

('f0a00000-0000-0000-0000-00000000005c',
 'CNS-PLEURITIC-RESPIRATORY-PHENOTYPE',
 'phenotype',
 'Pleuritic respiratory phenotype',
 'Pleuritic respiratory',
 'Respiratory presentation dominated by pleuritic symptoms'),

('f0a00000-0000-0000-0000-00000000005d',
 'CNS-THROMBOEMBOLIC-PHENOTYPE',
 'phenotype',
 'Thromboembolic phenotype',
 'Thromboembolic',
 'Clinical pattern compatible with thromboembolic disease'),

('f0a00000-0000-0000-0000-00000000005e',
 'CNS-AIRWAY-REACTIVE-PHENOTYPE',
 'phenotype',
 'Reactive airway phenotype',
 'Reactive airway',
 'Clinical pattern characterized by variable airway narrowing and respiratory symptoms')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. VERIFICATION
-- =============================================================================


SELECT
    'FACT_DEFINITIONS' AS object_type,
    COUNT(*) AS seeded_count
FROM clinical.fact_definition
WHERE code IN (
    'COUGH_PRESENT',
    'COUGH_PRODUCTIVITY',
    'COUGH_DURATION_DAYS',
    'COUGH_ONSET',
    'COUGH_SEVERITY',
    'SPUTUM_COLOUR',
    'FEVER_PRESENT',
    'DYSPNOEA_PRESENT',
    'CHEST_PAIN_PRESENT',
    'WHEEZE_PRESENT',
    'HAEMOPTYSIS_PRESENT',
    'TB_CONTACT',
    'WEIGHT_LOSS',
    'NIGHT_SWEATS',
    'SMOKING_STATUS',
    'OXYGEN_SATURATION',
    'RESPIRATORY_RATE',
    'HYPOXAEMIA_PRESENT',
    'RESPIRATORY_FAILURE'
);


SELECT
    'KNOWLEDGE_CONCEPTS' AS object_type,
    COUNT(*) AS seeded_count
FROM knowledge.concept
WHERE concept_code LIKE 'CNS-%';


SELECT
    concept_type,
    COUNT(*) AS concept_count
FROM knowledge.concept
WHERE concept_code LIKE 'CNS-%'
GROUP BY concept_type
ORDER BY concept_type;


SELECT
    code,
    name,
    data_type,
    description
FROM clinical.fact_definition
WHERE code LIKE 'COUGH_%'
   OR code LIKE 'FEVER_%'
   OR code LIKE 'DYSPNOEA_%'
   OR code LIKE 'CHEST_%'
   OR code LIKE 'WHEEZE_%'
   OR code LIKE 'SPUTUM_%'
ORDER BY code;


SELECT
    concept_code,
    concept_type,
    canonical_name,
    display_name
FROM knowledge.concept
WHERE concept_code LIKE 'CNS-%'
ORDER BY concept_type, concept_code;


COMMIT;


-- =============================================================================
-- END OF SEED Z1
-- =============================================================================