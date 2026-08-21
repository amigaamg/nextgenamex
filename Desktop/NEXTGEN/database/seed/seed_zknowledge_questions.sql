-- =============================================================================
-- AMEXAN Phase 2 — Seed Z4: UNIVERSAL CLINICAL QUESTION ENGINE
-- =============================================================================
-- PURPOSE
-- -----------------------------------------------------------------------------
-- Questions are DATA.
--
-- The question engine does NOT diagnose.
-- It collects structured clinical facts which the AMEXAN Clinical Intelligence
-- Engine can subsequently use for:
--
--   symptom characterization
--   differential generation
--   red-flag detection
--   phenotype recognition
--   mechanism recognition
--   risk stratification
--   investigation selection
--   documentation assistance
--   longitudinal clinical reasoning
--   specialty routing
--   clinical summarisation
--
-- PRINCIPLES
-- -----------------------------------------------------------------------------
-- 1. Symptom first; disease second.
-- 2. Never encode a diagnosis merely because a symptom exists.
-- 3. Questions produce facts.
-- 4. Facts are reusable across diseases, specialties and encounters.
-- 5. The same fact may participate in multiple reasoning pathways.
-- 6. Questions are context-sensitive.
-- 7. Mandatory questions are limited to information necessary for safe
--    characterization of the presenting problem.
-- 8. Red-flag questions must be available before routine deep questioning.
-- 9. Pediatric, pregnancy, elderly and immunocompromised contexts alter
--    questioning.
-- 10. Questions must support longitudinal comparison.
-- 11. Unknown / not assessed must remain distinguishable from "No".
-- 12. Absence of documentation must never be interpreted automatically as
--     absence of a symptom.
-- 13. Clinical documentation must preserve provenance of every answer.
--
-- SEED ORDER
-- -----------------------------------------------------------------------------
-- Z1 -> reference / fact definitions
-- Z2 -> contexts / body systems
-- Z4 -> question engine
-- Z5 -> mechanisms / phenotypes
-- Z8 -> universal concept junctions
--
-- Idempotent.
-- =============================================================================


BEGIN;


-- =============================================================================
-- SECTION 0
-- ADDITIONAL UNIVERSAL MEDICAL FACT DEFINITIONS
-- =============================================================================
-- These extend the minimal respiratory facts and make Z4 useful across
-- Internal Medicine, Emergency Medicine, Family Medicine and longitudinal EMR.
--
-- If these codes already exist, they are preserved.
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, data_type, description)
VALUES

-- ---------------------------------------------------------------------------
-- GENERAL SYMPTOM CHARACTERIZATION
-- ---------------------------------------------------------------------------

('SYMPTOM_PRESENT',
 'Symptom present',
 'coded',
 'Whether the presenting symptom is present'),

('SYMPTOM_DURATION_DAYS',
 'Symptom duration',
 'numeric',
 'Duration of the symptom in days'),

('SYMPTOM_ONSET',
 'Symptom onset',
 'coded',
 'Sudden, gradual or other onset'),

('SYMPTOM_COURSE',
 'Symptom course',
 'coded',
 'Improving, worsening, stable, intermittent or recurrent'),

('SYMPTOM_SEVERITY',
 'Symptom severity',
 'coded',
 'Patient-reported symptom severity'),

('SYMPTOM_FREQUENCY',
 'Symptom frequency',
 'coded',
 'Frequency of symptom occurrence'),

('SYMPTOM_TRIGGER',
 'Symptom trigger',
 'coded',
 'Known precipitating or aggravating factor'),

('SYMPTOM_RELIEVING_FACTOR',
 'Symptom relieving factor',
 'coded',
 'Factor that improves symptoms'),

('SYMPTOM_NIGHT_PREDOMINANCE',
 'Night predominance',
 'coded',
 'Whether symptoms are worse at night'),

('SYMPTOM_FUNCTIONAL_IMPACT',
 'Functional impact',
 'coded',
 'Effect of symptom on normal activities'),

-- ---------------------------------------------------------------------------
-- RESPIRATORY
-- ---------------------------------------------------------------------------

('COUGH_PRESENT',
 'Cough present',
 'coded',
 'Whether cough is present'),

('COUGH_DURATION_DAYS',
 'Cough duration',
 'numeric',
 'Duration of cough in days'),

('COUGH_PRODUCTIVITY',
 'Cough productivity',
 'coded',
 'Whether cough produces sputum'),

('COUGH_ONSET',
 'Cough onset',
 'coded',
 'Acute, subacute or chronic onset'),

('COUGH_CIRCUMSTANCE',
 'Cough circumstance',
 'coded',
 'Circumstance in which cough occurs'),

('SPUTUM_PRESENT',
 'Sputum present',
 'coded',
 'Whether sputum is produced'),

('SPUTUM_COLOUR',
 'Sputum colour',
 'coded',
 'Colour of sputum'),

('SPUTUM_AMOUNT',
 'Sputum amount',
 'coded',
 'Amount of sputum'),

('BLOOD_IN_SPUTUM',
 'Blood in sputum',
 'coded',
 'Presence of blood in sputum'),

('DYSPNOEA_PRESENT',
 'Dyspnoea present',
 'coded',
 'Shortness of breath'),

('DYSPNOEA_ONSET',
 'Dyspnoea onset',
 'coded',
 'Onset of dyspnoea'),

('DYSPNOEA_AT_REST',
 'Dyspnoea at rest',
 'coded',
 'Breathlessness at rest'),

('ORTHOPNOEA',
 'Orthopnoea',
 'coded',
 'Breathlessness when lying flat'),

('PND',
 'Paroxysmal nocturnal dyspnoea',
 'coded',
 'Episodes of nocturnal breathlessness'),

('WHEEZE_PRESENT',
 'Wheeze',
 'coded',
 'Wheeze present'),

('STRIDOR_PRESENT',
 'Stridor',
 'coded',
 'Stridor present'),

('PLEURITIC_CHEST_PAIN',
 'Pleuritic chest pain',
 'coded',
 'Chest pain related to breathing'),

('CYANOSIS_PRESENT',
 'Cyanosis',
 'coded',
 'Blue discoloration of lips or extremities'),

-- ---------------------------------------------------------------------------
-- FEVER / INFECTION
-- ---------------------------------------------------------------------------

('FEVER_PRESENT',
 'Fever present',
 'coded',
 'Whether fever is present'),

('FEVER_DURATION_DAYS',
 'Fever duration',
 'numeric',
 'Duration of fever in days'),

('FEVER_PATTERN',
 'Fever pattern',
 'coded',
 'Intermittent, continuous or recurrent'),

('CHILLS',
 'Chills',
 'coded',
 'Chills associated with fever'),

('RIGORS',
 'Rigors',
 'coded',
 'Severe shaking chills'),

('NIGHT_SWEATS',
 'Night sweats',
 'coded',
 'Sweating during sleep'),

('INFECTIOUS_CONTACT',
 'Infectious contact',
 'coded',
 'Relevant infectious exposure'),

('TB_CONTACT',
 'TB contact',
 'coded',
 'Contact with tuberculosis'),

('RECENT_TRAVEL',
 'Recent travel',
 'coded',
 'Recent travel relevant to illness'),

-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR
-- ---------------------------------------------------------------------------

('CHEST_PAIN_PRESENT',
 'Chest pain',
 'coded',
 'Chest pain present'),

('CHEST_PAIN_ONSET',
 'Chest pain onset',
 'coded',
 'Onset of chest pain'),

('CHEST_PAIN_CHARACTER',
 'Chest pain character',
 'coded',
 'Character of chest pain'),

('CHEST_PAIN_EXERTIONAL',
 'Exertional chest pain',
 'coded',
 'Chest pain precipitated by exertion'),

('CHEST_PAIN_RADIATION',
 'Chest pain radiation',
 'coded',
 'Radiation of chest pain'),

('PALPITATIONS',
 'Palpitations',
 'coded',
 'Awareness of heartbeat'),

('SYNCOPE',
 'Syncope',
 'coded',
 'Transient loss of consciousness'),

('PRESYNCOPE',
 'Presyncope',
 'coded',
 'Near-fainting'),

('LEG_SWELLING',
 'Leg swelling',
 'coded',
 'Peripheral lower-limb swelling'),

('EXERTIONAL_DYSPNOEA',
 'Exertional dyspnoea',
 'coded',
 'Dyspnoea associated with exertion'),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL
-- ---------------------------------------------------------------------------

('HEADACHE_PRESENT',
 'Headache',
 'coded',
 'Headache present'),

('HEADACHE_ONSET',
 'Headache onset',
 'coded',
 'Sudden or gradual headache onset'),

('HEADACHE_SEVERITY',
 'Headache severity',
 'coded',
 'Severity of headache'),

('SEIZURE',
 'Seizure',
 'coded',
 'Seizure or seizure-like event'),

('FOCAL_WEAKNESS',
 'Focal weakness',
 'coded',
 'Focal motor weakness'),

('SENSORY_LOSS',
 'Sensory loss',
 'coded',
 'Loss or alteration of sensation'),

('SPEECH_DISTURBANCE',
 'Speech disturbance',
 'coded',
 'Difficulty speaking or understanding speech'),

('CONFUSION',
 'Confusion',
 'coded',
 'Acute confusion or altered mental status'),

('LOSS_OF_CONSCIOUSNESS',
 'Loss of consciousness',
 'coded',
 'Loss of consciousness'),

-- ---------------------------------------------------------------------------
-- GASTROINTESTINAL
-- ---------------------------------------------------------------------------

('ABDOMINAL_PAIN_PRESENT',
 'Abdominal pain',
 'coded',
 'Abdominal pain present'),

('ABDOMINAL_PAIN_LOCATION',
 'Abdominal pain location',
 'coded',
 'Location of abdominal pain'),

('ABDOMINAL_PAIN_CHARACTER',
 'Abdominal pain character',
 'coded',
 'Character of abdominal pain'),

('ABDOMINAL_PAIN_RADIATION',
 'Abdominal pain radiation',
 'coded',
 'Radiation of abdominal pain'),

('ABDOMINAL_PAIN_RELATION_TO_FOOD',
 'Pain relation to food',
 'coded',
 'Relationship of abdominal pain to meals'),

('VOMITING_PRESENT',
 'Vomiting',
 'coded',
 'Vomiting present'),

('VOMITING_BLOOD',
 'Haematemesis',
 'coded',
 'Blood in vomitus'),

('DIARRHOEA_PRESENT',
 'Diarrhoea',
 'coded',
 'Diarrhoea present'),

('BLOOD_IN_STOOL',
 'Blood in stool',
 'coded',
 'Rectal blood or bloody stool'),

('JAUNDICE',
 'Jaundice',
 'coded',
 'Yellow discoloration of skin or sclera'),

('DYSPHAGIA',
 'Dysphagia',
 'coded',
 'Difficulty swallowing'),

-- ---------------------------------------------------------------------------
-- RENAL / URINARY
-- ---------------------------------------------------------------------------

('DYSURIA',
 'Dysuria',
 'coded',
 'Painful urination'),

('URINARY_FREQUENCY',
 'Urinary frequency',
 'coded',
 'Increased urinary frequency'),

('URGENCY',
 'Urinary urgency',
 'coded',
 'Urgency of urination'),

('HAEMATURIA',
 'Haematuria',
 'coded',
 'Blood in urine'),

('FLANK_PAIN',
 'Flank pain',
 'coded',
 'Pain in flank'),

('URINE_OUTPUT_REDUCED',
 'Reduced urine output',
 'coded',
 'Reduced urine output'),

-- ---------------------------------------------------------------------------
-- ENDOCRINE / METABOLIC
-- ---------------------------------------------------------------------------

('POLYURIA',
 'Polyuria',
 'coded',
 'Excessive urination'),

('POLYDIPSIA',
 'Polydipsia',
 'coded',
 'Excessive thirst'),

('POLYPHAGIA',
 'Polyphagia',
 'coded',
 'Excessive hunger'),

('HEAT_INTOLERANCE',
 'Heat intolerance',
 'coded',
 'Heat intolerance'),

('COLD_INTOLERANCE',
 'Cold intolerance',
 'coded',
 'Cold intolerance'),

('WEIGHT_LOSS',
 'Weight loss',
 'coded',
 'Unintentional weight loss'),

('WEIGHT_GAIN',
 'Weight gain',
 'coded',
 'Unintentional weight gain'),

-- ---------------------------------------------------------------------------
-- HAEMATOLOGY
-- ---------------------------------------------------------------------------

('EASY_BLEEDING',
 'Easy bleeding',
 'coded',
 'Easy bleeding or bruising'),

('EASY_BRUISING',
 'Easy bruising',
 'coded',
 'Easy bruising'),

('PALLOR',
 'Pallor',
 'coded',
 'Patient-reported pallor'),

-- ---------------------------------------------------------------------------
-- MUSCULOSKELETAL
-- ---------------------------------------------------------------------------

('JOINT_PAIN',
 'Joint pain',
 'coded',
 'Joint pain'),

('JOINT_SWELLING',
 'Joint swelling',
 'coded',
 'Joint swelling'),

('MUSCLE_PAIN',
 'Muscle pain',
 'coded',
 'Muscle pain'),

('BACK_PAIN',
 'Back pain',
 'coded',
 'Back pain'),

-- ---------------------------------------------------------------------------
-- SKIN
-- ---------------------------------------------------------------------------

('RASH',
 'Rash',
 'coded',
 'Skin rash'),

('PRURITUS',
 'Pruritus',
 'coded',
 'Itching'),

('SKIN_ULCER',
 'Skin ulcer',
 'coded',
 'Skin ulceration'),

-- ---------------------------------------------------------------------------
-- GENERAL / CONSTITUTIONAL
-- ---------------------------------------------------------------------------

('FATIGUE',
 'Fatigue',
 'coded',
 'Fatigue'),

('WEAKNESS',
 'Weakness',
 'coded',
 'General weakness'),

('APPETITE_LOSS',
 'Loss of appetite',
 'coded',
 'Reduced appetite'),

('SLEEP_DISTURBANCE',
 'Sleep disturbance',
 'coded',
 'Sleep disturbance'),

('FUNCTIONAL_DECLINE',
 'Functional decline',
 'coded',
 'Decline in usual function'),

-- ---------------------------------------------------------------------------
-- RISK FACTORS
-- ---------------------------------------------------------------------------

('SMOKING_STATUS',
 'Smoking status',
 'coded',
 'Current, former or never smoker'),

('ALCOHOL_USE',
 'Alcohol use',
 'coded',
 'Alcohol consumption'),

('SUBSTANCE_USE',
 'Substance use',
 'coded',
 'Non-prescribed psychoactive substance use'),

('IMMUNOCOMPROMISED_STATUS',
 'Immune status',
 'coded',
 'Immunocompromised state'),

('RECENT_HOSPITALISATION',
 'Recent hospitalisation',
 'coded',
 'Recent hospital admission'),

('RECENT_ANTIBIOTIC_USE',
 'Recent antibiotic use',
 'coded',
 'Recent antibiotic exposure'),

('RECENT_SURGERY',
 'Recent surgery',
 'coded',
 'Recent surgical procedure'),

('IMMOBILISATION',
 'Immobilisation',
 'coded',
 'Recent immobilisation'),

('MALIGNANCY_HISTORY',
 'Malignancy history',
 'coded',
 'Previous or current malignancy'),

-- ---------------------------------------------------------------------------
-- MEDICATION / ALLERGY
-- ---------------------------------------------------------------------------

('CURRENT_MEDICATION_PRESENT',
 'Current medication',
 'coded',
 'Current medication use'),

('RECENT_MEDICATION_CHANGE',
 'Recent medication change',
 'coded',
 'Recent medication initiation, cessation or dose change'),

('MEDICATION_ADHERENCE',
 'Medication adherence',
 'coded',
 'Adherence to prescribed medication'),

('DRUG_ALLERGY',
 'Drug allergy',
 'coded',
 'Drug allergy'),

('ALLERGY_REACTION',
 'Allergic reaction type',
 'coded',
 'Type of reaction to allergen'),

-- ---------------------------------------------------------------------------
-- PAST HISTORY
-- ---------------------------------------------------------------------------

('PAST_MEDICAL_HISTORY_PRESENT',
 'Past medical history',
 'coded',
 'Previous medical condition'),

('PAST_SURGICAL_HISTORY_PRESENT',
 'Past surgical history',
 'coded',
 'Previous surgery'),

('PREVIOUS_SIMILAR_EPISODE',
 'Previous similar episode',
 'coded',
 'Previous episode of same/similar problem'),

('PREVIOUS_ADMISSION',
 'Previous hospital admission',
 'coded',
 'Previous hospital admission'),

-- ---------------------------------------------------------------------------
-- PREGNANCY / REPRODUCTIVE
-- ---------------------------------------------------------------------------

('PREGNANCY_STATUS',
 'Pregnancy status',
 'coded',
 'Pregnancy status'),

('LMP_KNOWN',
 'LMP known',
 'coded',
 'Whether last menstrual period is known'),

('LMP_DATE',
 'Last menstrual period',
 'date',
 'Date of last menstrual period'),

('VAGINAL_BLEEDING',
 'Vaginal bleeding',
 'coded',
 'Vaginal bleeding'),

('VAGINAL_DISCHARGE',
 'Vaginal discharge',
 'coded',
 'Vaginal discharge'),

('FETAL_MOVEMENT_REDUCED',
 'Reduced fetal movement',
 'coded',
 'Reduced fetal movement'),

-- ---------------------------------------------------------------------------
-- PAEDIATRICS
-- ---------------------------------------------------------------------------

('FEEDING_DIFFICULTY',
 'Feeding difficulty',
 'coded',
 'Difficulty feeding'),

('POOR_FEEDING',
 'Poor feeding',
 'coded',
 'Reduced feeding'),

('GRUNTING_PRESENT',
 'Grunting',
 'coded',
 'Grunting respiration'),

('CHEST_INDRAWING',
 'Chest indrawing',
 'coded',
 'Chest indrawing'),

('APNOEA',
 'Apnoea',
 'coded',
 'Apnoeic episode'),

('IMMUNIZATION_STATUS',
 'Immunization status',
 'coded',
 'Immunization status'),

-- ---------------------------------------------------------------------------
-- RED FLAGS
-- ---------------------------------------------------------------------------

('RED_FLAG_PRESENT',
 'Red flag present',
 'coded',
 'Clinically concerning feature'),

('SEVERE_RESPIRATORY_DISTRESS',
 'Severe respiratory distress',
 'coded',
 'Severe respiratory distress'),

('ALTERED_MENTAL_STATUS',
 'Altered mental status',
 'coded',
 'Altered consciousness or cognition'),

('SHOCK_FEATURE',
 'Shock feature',
 'coded',
 'Symptoms/signs suggestive of circulatory compromise'),

('SEVERE_BLEEDING',
 'Severe bleeding',
 'coded',
 'Significant active bleeding'),

('INABILITY_TO_TOLERATE_ORAL_INTAKE',
 'Unable to tolerate oral intake',
 'coded',
 'Unable to maintain oral intake'),

('SPO2',
 'Oxygen saturation',
 'numeric',
 'Peripheral oxygen saturation'),

('TEMPERATURE',
 'Temperature',
 'numeric',
 'Body temperature'),

('HEART_RATE',
 'Heart rate',
 'numeric',
 'Heart rate'),

('RESPIRATORY_RATE',
 'Respiratory rate',
 'numeric',
 'Respiratory rate'),

('SYSTOLIC_BP',
 'Systolic blood pressure',
 'numeric',
 'Systolic blood pressure'),

('DIASTOLIC_BP',
 'Diastolic blood pressure',
 'numeric',
 'Diastolic blood pressure')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 1
-- UNIVERSAL QUESTION REGISTRY
-- =============================================================================

INSERT INTO knowledge.question
(id, question_code, concept_id, question_type, text, response_type, priority)
VALUES

-- ===========================================================================
-- GENERAL SYMPTOM CHARACTERIZATION
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000001',
 'SYMPTOM_DURATION',
 NULL,
 'clinical',
 'When did the symptom first begin?',
 'numeric',
 10),

('f0c10000-0000-0000-0000-000000000002',
 'SYMPTOM_ONSET',
 NULL,
 'clinical',
 'Did the symptom begin suddenly or gradually?',
 'single_choice',
 15),

('f0c10000-0000-0000-0000-000000000003',
 'SYMPTOM_COURSE',
 NULL,
 'clinical',
 'Since it began, has the symptom been improving, worsening, staying the same, or coming and going?',
 'single_choice',
 20),

('f0c10000-0000-0000-0000-000000000004',
 'SYMPTOM_SEVERITY',
 NULL,
 'clinical',
 'How severe is the symptom?',
 'single_choice',
 25),

('f0c10000-0000-0000-0000-000000000005',
 'SYMPTOM_FUNCTIONAL_IMPACT',
 NULL,
 'clinical',
 'How has the symptom affected your usual activities?',
 'single_choice',
 30),

-- ===========================================================================
-- COUGH
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000010',
 'COUGH_PRESENT',
 'f0a00000-0000-0000-0000-000000000001',
 'clinical',
 'Do you have a cough?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000011',
 'COUGH_DURATION',
 'f0a00000-0000-0000-0000-000000000001',
 'clinical',
 'How long have you had the cough?',
 'numeric',
 45),

('f0c10000-0000-0000-0000-000000000012',
 'COUGH_ONSET',
 'f0a00000-0000-0000-0000-000000000001',
 'clinical',
 'How did the cough begin?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000013',
 'COUGH_PRODUCTIVITY',
 'f0a00000-0000-0000-0000-000000000001',
 'clinical',
 'Is the cough dry or does it produce sputum?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000014',
 'SPUTUM_AMOUNT',
 'f0a00000-0000-0000-0000-000000000005',
 'clinical',
 'If sputum is produced, approximately how much is produced?',
 'single_choice',
 60),

('f0c10000-0000-0000-0000-000000000015',
 'SPUTUM_COLOUR',
 'f0a00000-0000-0000-0000-000000000005',
 'clinical',
 'What colour is the sputum?',
 'single_choice',
 65),

('f0c10000-0000-0000-0000-000000000016',
 'BLOOD_IN_SPUTUM',
 'f0a00000-0000-0000-0000-000000000004',
 'clinical',
 'Have you noticed blood in the sputum?',
 'single_choice',
 70),

('f0c10000-0000-0000-0000-000000000017',
 'COUGH_NIGHT_PREDOMINANCE',
 NULL,
 'clinical',
 'Is the cough worse at night?',
 'single_choice',
 75),

('f0c10000-0000-0000-0000-000000000018',
 'COUGH_TRIGGER',
 NULL,
 'clinical',
 'Is there anything that reliably triggers or worsens the cough?',
 'single_choice',
 80),

-- ===========================================================================
-- FEVER
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000020',
 'FEVER_PRESENT',
 'f0a00000-0000-0000-0000-000000000002',
 'clinical',
 'Have you had fever or felt unusually hot?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000021',
 'FEVER_DURATION',
 NULL,
 'clinical',
 'How long have you had the fever?',
 'numeric',
 45),

('f0c10000-0000-0000-0000-000000000022',
 'FEVER_PATTERN',
 NULL,
 'clinical',
 'How does the fever behave?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000023',
 'CHILLS',
 NULL,
 'clinical',
 'Do you experience chills with the fever?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000024',
 'RIGORS',
 NULL,
 'clinical',
 'Have you had episodes of severe shaking chills?',
 'single_choice',
 60),

('f0c10000-0000-0000-0000-000000000025',
 'NIGHT_SWEATS',
 'f0a00000-0000-0000-0000-00000000000a',
 'clinical',
 'Do you have drenching night sweats?',
 'single_choice',
 65),

-- ===========================================================================
-- DYSPNOEA
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000030',
 'DYSPNOEA_PRESENT',
 'f0a00000-0000-0000-0000-000000000003',
 'clinical',
 'Do you feel short of breath?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000031',
 'DYSPNOEA_ONSET',
 NULL,
 'clinical',
 'When did the shortness of breath begin?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000032',
 'DYSPNOEA_AT_REST',
 NULL,
 'red_flag',
 'Do you become short of breath even while resting?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000033',
 'EXERTIONAL_DYSPNOEA',
 NULL,
 'clinical',
 'Does the shortness of breath occur with exertion?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000034',
 'ORTHOPNOEA',
 NULL,
 'clinical',
 'Do you become short of breath when lying flat?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000035',
 'PND',
 NULL,
 'clinical',
 'Do you wake from sleep because of sudden shortness of breath?',
 'single_choice',
 60),

('f0c10000-0000-0000-0000-000000000036',
 'WHEEZE_PRESENT',
 NULL,
 'clinical',
 'Have you noticed wheezing or a whistling sound when breathing?',
 'single_choice',
 65),

('f0c10000-0000-0000-0000-000000000037',
 'STRIDOR_PRESENT',
 NULL,
 'red_flag',
 'Have you noticed a harsh or noisy sound when breathing in?',
 'single_choice',
 10),

-- ===========================================================================
-- CHEST PAIN
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000040',
 'CHEST_PAIN_PRESENT',
 NULL,
 'clinical',
 'Do you have chest pain or discomfort?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000041',
 'CHEST_PAIN_ONSET',
 NULL,
 'clinical',
 'When did the chest pain begin?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000042',
 'CHEST_PAIN_CHARACTER',
 NULL,
 'clinical',
 'How would you describe the chest pain?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000043',
 'CHEST_PAIN_EXERTIONAL',
 NULL,
 'clinical',
 'Is the chest pain brought on or worsened by physical exertion?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000044',
 'CHEST_PAIN_RADIATION',
 NULL,
 'clinical',
 'Does the chest pain spread anywhere else?',
 'single_choice',
 60),

('f0c10000-0000-0000-0000-000000000045',
 'PLEURITIC_CHEST_PAIN',
 NULL,
 'clinical',
 'Does the chest pain become worse when you breathe deeply or cough?',
 'single_choice',
 65),

-- ===========================================================================
-- CARDIOVASCULAR
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000050',
 'PALPITATIONS',
 NULL,
 'clinical',
 'Have you felt your heart racing, pounding, fluttering, or beating irregularly?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000051',
 'SYNCOPE',
 NULL,
 'red_flag',
 'Have you ever completely lost consciousness with this illness?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000052',
 'PRESYNCOPE',
 NULL,
 'clinical',
 'Have you felt that you were about to faint?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000053',
 'LEG_SWELLING',
 NULL,
 'clinical',
 'Have you noticed swelling of either or both legs?',
 'single_choice',
 55),

-- ===========================================================================
-- NEUROLOGY
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000060',
 'HEADACHE_PRESENT',
 NULL,
 'clinical',
 'Do you have a headache?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000061',
 'HEADACHE_ONSET',
 NULL,
 'red_flag',
 'Did the headache reach maximum intensity suddenly?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000062',
 'SEIZURE',
 NULL,
 'red_flag',
 'Have you had a seizure or seizure-like episode?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000063',
 'FOCAL_WEAKNESS',
 NULL,
 'red_flag',
 'Have you developed weakness of one side or one particular limb?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000064',
 'SPEECH_DISTURBANCE',
 NULL,
 'red_flag',
 'Have you developed difficulty speaking or understanding speech?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000065',
 'CONFUSION',
 NULL,
 'red_flag',
 'Have you become unusually confused or less aware of your surroundings?',
 'single_choice',
 10),

-- ===========================================================================
-- ABDOMINAL / GI
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000070',
 'ABDOMINAL_PAIN_PRESENT',
 NULL,
 'clinical',
 'Do you have abdominal pain?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000071',
 'ABDOMINAL_PAIN_LOCATION',
 NULL,
 'clinical',
 'Where exactly is the abdominal pain?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000072',
 'ABDOMINAL_PAIN_CHARACTER',
 NULL,
 'clinical',
 'How would you describe the abdominal pain?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000073',
 'ABDOMINAL_PAIN_RADIATION',
 NULL,
 'clinical',
 'Does the abdominal pain spread anywhere else?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000074',
 'ABDOMINAL_PAIN_RELATION_TO_FOOD',
 NULL,
 'clinical',
 'Is the abdominal pain related to eating?',
 'single_choice',
 60),

('f0c10000-0000-0000-0000-000000000075',
 'VOMITING_PRESENT',
 NULL,
 'clinical',
 'Have you been vomiting?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000076',
 'VOMITING_BLOOD',
 NULL,
 'red_flag',
 'Have you vomited blood or material resembling coffee grounds?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000077',
 'DIARRHOEA_PRESENT',
 NULL,
 'clinical',
 'Have you had diarrhoea?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000078',
 'BLOOD_IN_STOOL',
 NULL,
 'red_flag',
 'Have you noticed blood in the stool?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000079',
 'JAUNDICE',
 NULL,
 'clinical',
 'Have you noticed yellowing of your eyes or skin?',
 'single_choice',
 50),

-- ===========================================================================
-- URINARY
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000080',
 'DYSURIA',
 NULL,
 'clinical',
 'Do you have pain or burning when passing urine?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000081',
 'URINARY_FREQUENCY',
 NULL,
 'clinical',
 'Are you passing urine more frequently than usual?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000082',
 'URGENCY',
 NULL,
 'clinical',
 'Do you have a sudden or difficult-to-control urge to pass urine?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000083',
 'HAEMATURIA',
 NULL,
 'clinical',
 'Have you noticed blood in your urine?',
 'single_choice',
 60),

('f0c10000-0000-0000-0000-000000000084',
 'FLANK_PAIN',
 NULL,
 'clinical',
 'Do you have pain in either side of your back or flank?',
 'single_choice',
 55),

('f0c10000-0000-0000-0000-000000000085',
 'URINE_OUTPUT_REDUCED',
 NULL,
 'red_flag',
 'Have you been passing much less urine than usual?',
 'single_choice',
 10),

-- ===========================================================================
-- METABOLIC
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000090',
 'POLYURIA',
 NULL,
 'clinical',
 'Have you been passing urine much more frequently or in larger amounts?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000091',
 'POLYDIPSIA',
 NULL,
 'clinical',
 'Have you been unusually thirsty?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000092',
 'WEIGHT_LOSS',
 'f0a00000-0000-0000-0000-000000000009',
 'clinical',
 'Have you lost weight unintentionally?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000093',
 'WEIGHT_GAIN',
 NULL,
 'clinical',
 'Have you gained weight unintentionally?',
 'single_choice',
 50),

-- ===========================================================================
-- GENERAL
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000100',
 'FATIGUE',
 NULL,
 'clinical',
 'Have you been unusually tired or lacking energy?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000101',
 'WEAKNESS',
 NULL,
 'clinical',
 'Have you felt unusually weak?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000102',
 'APPETITE_LOSS',
 NULL,
 'clinical',
 'Has your appetite decreased?',
 'single_choice',
 50),

-- ===========================================================================
-- TB / CHRONIC INFECTION
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000110',
 'TB_CONTACT',
 'f0a00000-0000-0000-0000-000000000006',
 'risk',
 'Have you had close contact with anyone diagnosed with tuberculosis?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000111',
 'INFECTIOUS_CONTACT',
 NULL,
 'risk',
 'Has anyone close to you recently had a similar infectious illness?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000112',
 'RECENT_TRAVEL',
 NULL,
 'risk',
 'Have you recently travelled outside your usual area of residence?',
 'single_choice',
 50),

-- ===========================================================================
-- SOCIAL / EXPOSURE
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000120',
 'SMOKING_STATUS',
 'f0a00000-0000-0000-0000-000000000007',
 'risk',
 'Do you currently smoke, have you smoked previously, or have you never smoked?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000121',
 'ALCOHOL_USE',
 NULL,
 'risk',
 'Do you drink alcohol?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000122',
 'SUBSTANCE_USE',
 NULL,
 'risk',
 'Do you use any non-prescribed recreational or psychoactive substances?',
 'single_choice',
 50),

-- ===========================================================================
-- MEDICATION
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000130',
 'CURRENT_MEDICATION_PRESENT',
 NULL,
 'medication',
 'Are you currently taking any medicines, including medicines bought without a prescription?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000131',
 'RECENT_MEDICATION_CHANGE',
 NULL,
 'medication',
 'Have you recently started, stopped, or changed the dose of any medicine?',
 'single_choice',
 50),

('f0c10000-0000-0000-0000-000000000132',
 'MEDICATION_ADHERENCE',
 NULL,
 'medication',
 'Have you been able to take your prescribed medicines as directed?',
 'single_choice',
 55),

-- ===========================================================================
-- ALLERGY
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000140',
 'DRUG_ALLERGY',
 NULL,
 'allergy',
 'Are you allergic to any medicine?',
 'single_choice',
 20),

('f0c10000-0000-0000-0000-000000000141',
 'ALLERGY_REACTION',
 NULL,
 'allergy',
 'What reaction did you experience when exposed to the medicine or allergen?',
 'single_choice',
 25),

-- ===========================================================================
-- PAST MEDICAL HISTORY
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000150',
 'PAST_MEDICAL_HISTORY_PRESENT',
 NULL,
 'history',
 'Do you have any known medical conditions or previous significant illnesses?',
 'single_choice',
 40),

('f0c10000-0000-0000-0000-000000000151',
 'PAST_SURGICAL_HISTORY_PRESENT',
 NULL,
 'history',
 'Have you ever had an operation or surgical procedure?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000152',
 'PREVIOUS_SIMILAR_EPISODE',
 NULL,
 'history',
 'Have you experienced a similar problem before?',
 'single_choice',
 45),

('f0c10000-0000-0000-0000-000000000153',
 'PREVIOUS_ADMISSION',
 NULL,
 'history',
 'Have you previously been admitted to hospital?',
 'single_choice',
 50),

-- ===========================================================================
-- PREGNANCY
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000160',
 'PREGNANCY_STATUS',
 NULL,
 'context',
 'Could you currently be pregnant?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000161',
 'LMP_KNOWN',
 NULL,
 'context',
 'Do you know the date of your last menstrual period?',
 'single_choice',
 15),

('f0c10000-0000-0000-0000-000000000162',
 'VAGINAL_BLEEDING',
 NULL,
 'clinical',
 'Have you had vaginal bleeding?',
 'single_choice',
 20),

('f0c10000-0000-0000-0000-000000000163',
 'VAGINAL_DISCHARGE',
 NULL,
 'clinical',
 'Have you noticed abnormal vaginal discharge?',
 'single_choice',
 25),

-- ===========================================================================
-- PAEDIATRICS
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000170',
 'POOR_FEEDING',
 NULL,
 'paediatric',
 'Has the child been feeding less than usual?',
 'single_choice',
 20),

('f0c10000-0000-0000-0000-000000000171',
 'FEEDING_DIFFICULTY',
 NULL,
 'paediatric',
 'Does the child have difficulty feeding or stopping frequently while feeding?',
 'single_choice',
 25),

('f0c10000-0000-0000-0000-000000000172',
 'GRUNTING_PRESENT',
 NULL,
 'red_flag',
 'Has the child been grunting while breathing?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000173',
 'CHEST_INDRAWING',
 NULL,
 'red_flag',
 'Does the child''s chest pull in when breathing?',
 'single_choice',
 10),

('f0c10000-0000-0000-0000-000000000174',
 'APNOEA',
 NULL,
 'red_flag',
 'Has the child stopped breathing or had episodes of apnoea?',
 'single_choice',
 10),

-- ===========================================================================
-- RED FLAGS
-- ===========================================================================

('f0c10000-0000-0000-0000-000000000180',
 'ALTERED_MENTAL_STATUS',
 NULL,
 'red_flag',
 'Have you become unusually drowsy, confused, difficult to wake, or less responsive?',
 'single_choice',
 1),

('f0c10000-0000-0000-0000-000000000181',
 'SEVERE_RESPIRATORY_DISTRESS',
 NULL,
 'red_flag',
 'Are you struggling severely to breathe or unable to speak normally because of breathlessness?',
 'single_choice',
 1),

('f0c10000-0000-0000-0000-000000000182',
 'SEVERE_BLEEDING',
 NULL,
 'red_flag',
 'Are you experiencing heavy or uncontrolled bleeding?',
 'single_choice',
 1),

('f0c10000-0000-0000-0000-000000000183',
 'INABILITY_TO_TOLERATE_ORAL_INTAKE',
 NULL,
 'red_flag',
 'Are you unable to keep fluids or food down?',
 'single_choice',
 5),

('f0c10000-0000-0000-0000-000000000184',
 'SHOCK_FEATURE',
 NULL,
 'red_flag',
 'Have you felt extremely faint, cold, clammy, or close to collapsing?',
 'single_choice',
 1)

ON CONFLICT (question_code) DO NOTHING;


-- =============================================================================
-- SECTION 2
-- ANSWER OPTIONS
-- =============================================================================

INSERT INTO knowledge.answer_option
(id, question_id, answer_code, label, value_text, sort_order)
VALUES

-- ---------------------------------------------------------------------------
-- GENERAL
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000001',
 'f0c10000-0000-0000-0000-000000000002',
 'SUDDEN',
 'Sudden',
 'SUDDEN',
 1),

('f0d10000-0000-0000-0000-000000000002',
 'f0c10000-0000-0000-0000-000000000002',
 'GRADUAL',
 'Gradual',
 'GRADUAL',
 2),

('f0d10000-0000-0000-0000-000000000003',
 'f0c10000-0000-0000-0000-000000000003',
 'IMPROVING',
 'Improving',
 'IMPROVING',
 1),

('f0d10000-0000-0000-0000-000000000004',
 'f0c10000-0000-0000-0000-000000000003',
 'WORSENING',
 'Worsening',
 'WORSENING',
 2),

('f0d10000-0000-0000-0000-000000000005',
 'f0c10000-0000-0000-0000-000000000003',
 'STABLE',
 'About the same',
 'STABLE',
 3),

('f0d10000-0000-0000-0000-000000000006',
 'f0c10000-0000-0000-0000-000000000003',
 'INTERMITTENT',
 'Comes and goes',
 'INTERMITTENT',
 4),

('f0d10000-0000-0000-0000-000000000007',
 'f0c10000-0000-0000-0000-000000000004',
 'MILD',
 'Mild',
 'MILD',
 1),

('f0d10000-0000-0000-0000-000000000008',
 'f0c10000-0000-0000-0000-000000000004',
 'MODERATE',
 'Moderate',
 'MODERATE',
 2),

('f0d10000-0000-0000-0000-000000000009',
 'f0c10000-0000-0000-0000-000000000004',
 'SEVERE',
 'Severe',
 'SEVERE',
 3),

('f0d10000-0000-0000-0000-00000000000a',
 'f0c10000-0000-0000-0000-000000000005',
 'NONE',
 'No effect',
 'NONE',
 1),

('f0d10000-0000-0000-0000-00000000000b',
 'f0c10000-0000-0000-0000-000000000005',
 'MILD',
 'Mild effect',
 'MILD',
 2),

('f0d10000-0000-0000-0000-00000000000c',
 'f0c10000-0000-0000-0000-000000000005',
 'MODERATE',
 'Moderate effect',
 'MODERATE',
 3),

('f0d10000-0000-0000-0000-00000000000d',
 'f0c10000-0000-0000-0000-000000000005',
 'SEVERE',
 'Severe limitation',
 'SEVERE',
 4),

-- ---------------------------------------------------------------------------
-- UNIVERSAL YES / NO / UNKNOWN
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000010',
 'f0c10000-0000-0000-0000-000000000010',
 'YES',
 'Yes',
 'YES',
 1),

('f0d10000-0000-0000-0000-000000000011',
 'f0c10000-0000-0000-0000-000000000010',
 'NO',
 'No',
 'NO',
 2),

('f0d10000-0000-0000-0000-000000000012',
 'f0c10000-0000-0000-0000-000000000010',
 'UNKNOWN',
 'Not sure',
 'UNKNOWN',
 3),

-- ---------------------------------------------------------------------------
-- COUGH PRODUCTIVITY
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000020',
 'f0c10000-0000-0000-0000-000000000013',
 'PRODUCTIVE',
 'Produces sputum',
 'PRODUCTIVE',
 1),

('f0d10000-0000-0000-0000-000000000021',
 'f0c10000-0000-0000-0000-000000000013',
 'NON_PRODUCTIVE',
 'Dry / no sputum',
 'NON_PRODUCTIVE',
 2),

-- ---------------------------------------------------------------------------
-- COUGH ONSET
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000022',
 'f0c10000-0000-0000-0000-000000000012',
 'ACUTE',
 'Acute',
 'ACUTE',
 1),

('f0d10000-0000-0000-0000-000000000023',
 'f0c10000-0000-0000-0000-000000000012',
 'SUBACUTE',
 'Subacute',
 'SUBACUTE',
 2),

('f0d10000-0000-0000-0000-000000000024',
 'f0c10000-0000-0000-0000-000000000012',
 'CHRONIC',
 'Chronic',
 'CHRONIC',
 3),

-- ---------------------------------------------------------------------------
-- SPUTUM
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000025',
 'f0c10000-0000-0000-0000-000000000015',
 'CLEAR',
 'Clear / white',
 'CLEAR',
 1),

('f0d10000-0000-0000-0000-000000000026',
 'f0c10000-0000-0000-0000-000000000015',
 'YELLOW_GREEN',
 'Yellow / green',
 'YELLOW_GREEN',
 2),

('f0d10000-0000-0000-0000-000000000027',
 'f0c10000-0000-0000-0000-000000000015',
 'RUSTY',
 'Rusty / brown',
 'RUSTY',
 3),

('f0d10000-0000-0000-0000-000000000028',
 'f0c10000-0000-0000-0000-000000000015',
 'PINK_FROTHY',
 'Pink / frothy',
 'PINK_FROTHY',
 4),

('f0d10000-0000-0000-0000-000000000029',
 'f0c10000-0000-0000-0000-000000000015',
 'BLOOD_STAINED',
 'Blood-stained',
 'BLOOD_STAINED',
 5),

-- ---------------------------------------------------------------------------
-- FEVER
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000030',
 'f0c10000-0000-0000-0000-000000000022',
 'CONTINUOUS',
 'Continuous',
 'CONTINUOUS',
 1),

('f0d10000-0000-0000-0000-000000000031',
 'f0c10000-0000-0000-0000-000000000022',
 'INTERMITTENT',
 'Intermittent',
 'INTERMITTENT',
 2),

('f0d10000-0000-0000-0000-000000000032',
 'f0c10000-0000-0000-0000-000000000022',
 'RECURRENT',
 'Recurrent episodes',
 'RECURRENT',
 3),

-- ---------------------------------------------------------------------------
-- CHEST PAIN
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000040',
 'f0c10000-0000-0000-0000-000000000042',
 'PRESSURE',
 'Pressure / heaviness',
 'PRESSURE',
 1),

('f0d10000-0000-0000-0000-000000000041',
 'f0c10000-0000-0000-0000-000000000042',
 'TIGHTNESS',
 'Tightness',
 'TIGHTNESS',
 2),

('f0d10000-0000-0000-0000-000000000042',
 'f0c10000-0000-0000-0000-000000000042',
 'SHARP',
 'Sharp',
 'SHARP',
 3),

('f0d10000-0000-0000-0000-000000000043',
 'f0c10000-0000-0000-0000-000000000042',
 'BURNING',
 'Burning',
 'BURNING',
 4),

('f0d10000-0000-0000-0000-000000000044',
 'f0c10000-0000-0000-0000-000000000042',
 'STABBING',
 'Stabbing',
 'STABBING',
 5),

-- ---------------------------------------------------------------------------
-- SMOKING
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000050',
 'f0c10000-0000-0000-0000-000000000120',
 'CURRENT',
 'Current smoker',
 'CURRENT',
 1),

('f0d10000-0000-0000-0000-000000000051',
 'f0c10000-0000-0000-0000-000000000120',
 'FORMER',
 'Former smoker',
 'FORMER',
 2),

('f0d10000-0000-0000-0000-000000000052',
 'f0c10000-0000-0000-0000-000000000120',
 'NEVER',
 'Never smoked',
 'NEVER',
 3),

-- ---------------------------------------------------------------------------
-- MEDICATION
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000060',
 'f0c10000-0000-0000-0000-000000000130',
 'YES',
 'Yes',
 'YES',
 1),

('f0d10000-0000-0000-0000-000000000061',
 'f0c10000-0000-0000-0000-000000000130',
 'NO',
 'No',
 'NO',
 2),

('f0d10000-0000-0000-0000-000000000062',
 'f0c10000-0000-0000-0000-000000000130',
 'UNKNOWN',
 'Not sure',
 'UNKNOWN',
 3),

-- ---------------------------------------------------------------------------
-- PREGNANCY
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000070',
 'f0c10000-0000-0000-0000-000000000160',
 'PREGNANT',
 'Pregnant',
 'PREGNANT',
 1),

('f0d10000-0000-0000-0000-000000000071',
 'f0c10000-0000-0000-0000-000000000160',
 'NOT_PREGNANT',
 'Not pregnant',
 'NOT_PREGNANT',
 2),

('f0d10000-0000-0000-0000-000000000072',
 'f0c10000-0000-0000-0000-000000000160',
 'UNKNOWN',
 'Unknown',
 'UNKNOWN',
 3),

-- ---------------------------------------------------------------------------
-- PAEDIATRIC FEEDING
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000080',
 'f0c10000-0000-0000-0000-000000000170',
 'YES',
 'Yes',
 'YES',
 1),

('f0d10000-0000-0000-0000-000000000081',
 'f0c10000-0000-0000-0000-000000000170',
 'NO',
 'No',
 'NO',
 2),

-- ---------------------------------------------------------------------------
-- RED FLAG QUESTIONS
-- ---------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000090',
 'f0c10000-0000-0000-0000-000000000181',
 'YES',
 'Yes',
 'YES',
 1),

('f0d10000-0000-0000-0000-000000000091',
 'f0c10000-0000-0000-0000-000000000181',
 'NO',
 'No',
 'NO',
 2)

ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- SECTION 3
-- ANSWER → FACT MAPPINGS
-- =============================================================================
-- The intelligence engine should reason from these facts, not from question
-- text.
-- =============================================================================

INSERT INTO knowledge.fact_mapping
(answer_option_id, fact_definition_code, value)
VALUES

-- General
('f0d10000-0000-0000-0000-000000000001', 'SYMPTOM_ONSET', 'SUDDEN'),
('f0d10000-0000-0000-0000-000000000002', 'SYMPTOM_ONSET', 'GRADUAL'),
('f0d10000-0000-0000-0000-000000000003', 'SYMPTOM_COURSE', 'IMPROVING'),
('f0d10000-0000-0000-0000-000000000004', 'SYMPTOM_COURSE', 'WORSENING'),
('f0d10000-0000-0000-0000-000000000005', 'SYMPTOM_COURSE', 'STABLE'),
('f0d10000-0000-0000-0000-000000000006', 'SYMPTOM_COURSE', 'INTERMITTENT'),
('f0d10000-0000-0000-0000-000000000007', 'SYMPTOM_SEVERITY', 'MILD'),
('f0d10000-0000-0000-0000-000000000008', 'SYMPTOM_SEVERITY', 'MODERATE'),
('f0d10000-0000-0000-0000-000000000009', 'SYMPTOM_SEVERITY', 'SEVERE'),

-- Cough
('f0d10000-0000-0000-0000-000000000010', 'COUGH_PRESENT', 'YES'),
('f0d10000-0000-0000-0000-000000000011', 'COUGH_PRESENT', 'NO'),
('f0d10000-0000-0000-0000-000000000020', 'COUGH_PRODUCTIVITY', 'PRODUCTIVE'),
('f0d10000-0000-0000-0000-000000000021', 'COUGH_PRODUCTIVITY', 'NON_PRODUCTIVE'),
('f0d10000-0000-0000-0000-000000000022', 'COUGH_ONSET', 'ACUTE'),
('f0d10000-0000-0000-0000-000000000023', 'COUGH_ONSET', 'SUBACUTE'),
('f0d10000-0000-0000-0000-000000000024', 'COUGH_ONSET', 'CHRONIC'),
('f0d10000-0000-0000-0000-000000000025', 'SPUTUM_COLOUR', 'CLEAR'),
('f0d10000-0000-0000-0000-000000000026', 'SPUTUM_COLOUR', 'YELLOW_GREEN'),
('f0d10000-0000-0000-0000-000000000027', 'SPUTUM_COLOUR', 'RUSTY'),
('f0d10000-0000-0000-0000-000000000028', 'SPUTUM_COLOUR', 'PINK_FROTHY'),
('f0d10000-0000-0000-0000-000000000029', 'SPUTUM_COLOUR', 'BLOOD_STAINED'),

-- Fever
('f0d10000-0000-0000-0000-000000000030', 'FEVER_PATTERN', 'CONTINUOUS'),
('f0d10000-0000-0000-0000-000000000031', 'FEVER_PATTERN', 'INTERMITTENT'),
('f0d10000-0000-0000-0000-000000000032', 'FEVER_PATTERN', 'RECURRENT'),

-- Smoking
('f0d10000-0000-0000-0000-000000000050', 'SMOKING_STATUS', 'CURRENT'),
('f0d10000-0000-0000-0000-000000000051', 'SMOKING_STATUS', 'FORMER'),
('f0d10000-0000-0000-0000-000000000052', 'SMOKING_STATUS', 'NEVER'),

-- Medication
('f0d10000-0000-0000-0000-000000000060', 'CURRENT_MEDICATION_PRESENT', 'YES'),
('f0d10000-0000-0000-0000-000000000061', 'CURRENT_MEDICATION_PRESENT', 'NO'),
('f0d10000-0000-0000-0000-000000000062', 'CURRENT_MEDICATION_PRESENT', 'UNKNOWN'),

-- Pregnancy
('f0d10000-0000-0000-0000-000000000070', 'PREGNANCY_STATUS', 'PREGNANT'),
('f0d10000-0000-0000-0000-000000000071', 'PREGNANCY_STATUS', 'NOT_PREGNANT'),
('f0d10000-0000-0000-0000-000000000072', 'PREGNANCY_STATUS', 'UNKNOWN'),

-- Paediatrics
('f0d10000-0000-0000-0000-000000000080', 'POOR_FEEDING', 'YES'),
('f0d10000-0000-0000-0000-000000000081', 'POOR_FEEDING', 'NO'),

-- Red flag
('f0d10000-0000-0000-0000-000000000090', 'SEVERE_RESPIRATORY_DISTRESS', 'YES'),
('f0d10000-0000-0000-0000-000000000091', 'SEVERE_RESPIRATORY_DISTRESS', 'NO')

ON CONFLICT (answer_option_id, fact_definition_code, value) DO NOTHING;


-- =============================================================================
-- SECTION 4
-- QUESTION TRIGGERS
-- =============================================================================
-- Questions become available because of:
--
--   presenting symptom
--   previously collected fact
--   clinical context
--   red flag
--
-- This is the key to avoiding a giant static questionnaire.
-- =============================================================================

INSERT INTO knowledge.question_trigger
(question_id, trigger_type, trigger_code, priority)
VALUES

-- Cough
('f0c10000-0000-0000-0000-000000000011',
 'symptom',
 'cough',
 10),

('f0c10000-0000-0000-0000-000000000012',
 'symptom',
 'cough',
 10),

('f0c10000-0000-0000-0000-000000000013',
 'symptom',
 'cough',
 10),

('f0c10000-0000-0000-0000-000000000014',
 'fact',
 'COUGH_PRODUCTIVITY',
 20),

('f0c10000-0000-0000-0000-000000000015',
 'fact',
 'COUGH_PRODUCTIVITY',
 20),

('f0c10000-0000-0000-0000-000000000016',
 'symptom',
 'cough',
 30),

-- Fever
('f0c10000-0000-0000-0000-000000000021',
 'symptom',
 'fever',
 10),

('f0c10000-0000-0000-0000-000000000022',
 'symptom',
 'fever',
 10),

('f0c10000-0000-0000-0000-000000000023',
 'symptom',
 'fever',
 20),

('f0c10000-0000-0000-0000-000000000024',
 'symptom',
 'fever',
 20),

('f0c10000-0000-0000-0000-000000000025',
 'symptom',
 'fever',
 30),

-- Dyspnoea
('f0c10000-0000-0000-0000-000000000031',
 'symptom',
 'dyspnoea',
 10),

('f0c10000-0000-0000-0000-000000000032',
 'symptom',
 'dyspnoea',
 1),

('f0c10000-0000-0000-0000-000000000033',
 'symptom',
 'dyspnoea',
 20),

('f0c10000-0000-0000-0000-000000000034',
 'symptom',
 'dyspnoea',
 30),

('f0c10000-0000-0000-0000-000000000035',
 'symptom',
 'dyspnoea',
 30),

-- Chest pain
('f0c10000-0000-0000-0000-000000000041',
 'symptom',
 'chest_pain',
 10),

('f0c10000-0000-0000-0000-000000000042',
 'symptom',
 'chest_pain',
 10),

('f0c10000-0000-0000-0000-000000000043',
 'symptom',
 'chest_pain',
 20),

('f0c10000-0000-0000-0000-000000000044',
 'symptom',
 'chest_pain',
 20),

('f0c10000-0000-0000-0000-000000000045',
 'symptom',
 'chest_pain',
 20),

-- Abdominal pain
('f0c10000-0000-0000-0000-000000000071',
 'symptom',
 'abdominal_pain',
 10),

('f0c10000-0000-0000-0000-000000000072',
 'symptom',
 'abdominal_pain',
 10),

('f0c10000-0000-0000-0000-000000000073',
 'symptom',
 'abdominal_pain',
 20),

('f0c10000-0000-0000-0000-000000000074',
 'symptom',
 'abdominal_pain',
 30),

-- Chronic respiratory / TB
('f0c10000-0000-0000-0000-000000000110',
 'symptom',
 'cough',
 40),

('f0c10000-0000-0000-0000-000000000112',
 'symptom',
 'cough',
 50),

-- General history
('f0c10000-0000-0000-0000-000000000120',
 'context',
 'adult',
 50),

('f0c10000-0000-0000-0000-000000000130',
 'context',
 'adult',
 50),

('f0c10000-0000-0000-0000-000000000140',
 'context',
 'all_patients',
 10),

('f0c10000-0000-0000-0000-000000000150',
 'context',
 'all_patients',
 40),

-- Pregnancy
('f0c10000-0000-0000-0000-000000000161',
 'fact',
 'PREGNANCY_STATUS',
 10),

('f0c10000-0000-0000-0000-000000000162',
 'fact',
 'PREGNANCY_STATUS',
 20),

('f0c10000-0000-0000-0000-000000000163',
 'fact',
 'PREGNANCY_STATUS',
 20),

-- Paediatrics
('f0c10000-0000-0000-0000-000000000170',
 'context',
 'paediatric',
 10),

('f0c10000-0000-0000-0000-000000000171',
 'context',
 'paediatric',
 10),

('f0c10000-0000-0000-0000-000000000172',
 'context',
 'paediatric',
 1),

('f0c10000-0000-0000-0000-000000000173',
 'context',
 'paediatric',
 1),

('f0c10000-0000-0000-0000-000000000174',
 'context',
 'paediatric',
 1),

-- Universal emergency questions
('f0c10000-0000-0000-0000-000000000180',
 'context',
 'emergency',
 1),

('f0c10000-0000-0000-0000-000000000181',
 'context',
 'emergency',
 1),

('f0c10000-0000-0000-0000-000000000182',
 'context',
 'emergency',
 1),

('f0c10000-0000-0000-0000-000000000183',
 'context',
 'emergency',
 5),

('f0c10000-0000-0000-0000-000000000184',
 'context',
 'emergency',
 1)

ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 5
-- QUESTION REQUIREMENTS
-- =============================================================================
-- Mandatory = required for the universal history pathway.
-- Conditional = required only when the relevant fact/context exists.
-- Optional = useful but not required for every presentation.
-- =============================================================================

INSERT INTO knowledge.question_requirement
(question_id, requirement_level, condition, priority)
VALUES

-- Core symptom characterization
('f0c10000-0000-0000-0000-000000000002',
 'mandatory',
 NULL,
 10),

('f0c10000-0000-0000-0000-000000000003',
 'mandatory',
 NULL,
 20),

('f0c10000-0000-0000-0000-000000000004',
 'mandatory',
 NULL,
 30),

-- Cough
('f0c10000-0000-0000-0000-000000000011',
 'mandatory',
 NULL,
 10),

('f0c10000-0000-0000-0000-000000000012',
 'mandatory',
 NULL,
 20),

('f0c10000-0000-0000-0000-000000000013',
 'mandatory',
 NULL,
 30),

('f0c10000-0000-0000-0000-000000000014',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','COUGH_PRODUCTIVITY',
      'value','PRODUCTIVE'
   )
 ),
 40),

('f0c10000-0000-0000-0000-000000000015',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','COUGH_PRODUCTIVITY',
      'value','PRODUCTIVE'
   )
 ),
 50),

('f0c10000-0000-0000-0000-000000000016',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','COUGH_PRODUCTIVITY',
      'value','PRODUCTIVE'
   )
 ),
 60),

-- Fever
('f0c10000-0000-0000-0000-000000000021',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','FEVER_PRESENT',
      'value','YES'
   )
 ),
 20),

('f0c10000-0000-0000-0000-000000000022',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','FEVER_PRESENT',
      'value','YES'
   )
 ),
 30),

('f0c10000-0000-0000-0000-000000000023',
 'optional',
 NULL,
 40),

('f0c10000-0000-0000-0000-000000000024',
 'optional',
 NULL,
 50),

-- Dyspnoea
('f0c10000-0000-0000-0000-000000000031',
 'mandatory',
 NULL,
 10),

('f0c10000-0000-0000-0000-000000000032',
 'mandatory',
 NULL,
 1),

('f0c10000-0000-0000-0000-000000000034',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','DYSPNOEA_PRESENT',
      'value','YES'
   )
 ),
 30),

('f0c10000-0000-0000-0000-000000000035',
 'conditionally_required',
 jsonb_build_object(
   'fact',
   jsonb_build_object(
      'code','DYSPNOEA_PRESENT',
      'value','YES'
   )
 ),
 40),

-- Chest pain
('f0c10000-0000-0000-0000-000000000041',
 'mandatory',
 NULL,
 10),

('f0c10000-0000-0000-0000-000000000042',
 'mandatory',
 NULL,
 20),

('f0c10000-0000-0000-0000-000000000043',
 'optional',
 NULL,
 30),

('f0c10000-0000-0000-0000-000000000044',
 'optional',
 NULL,
 40),

-- Red flags
('f0c10000-0000-0000-0000-000000000180',
 'mandatory',
 NULL,
 1),

('f0c10000-0000-0000-0000-000000000181',
 'mandatory',
 NULL,
 1),

('f0c10000-0000-0000-0000-000000000182',
 'mandatory',
 NULL,
 1),

-- Medication / allergy
('f0c10000-0000-0000-0000-000000000130',
 'mandatory',
 NULL,
 10),

('f0c10000-0000-0000-0000-000000000140',
 'mandatory',
 NULL,
 10),

-- Past history
('f0c10000-0000-0000-0000-000000000150',
 'mandatory',
 NULL,
 20),

('f0c10000-0000-0000-0000-000000000151',
 'optional',
 NULL,
 30),

('f0c10000-0000-0000-0000-000000000152',
 'optional',
 NULL,
 40)

ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 6
-- CONTEXT RULES
-- =============================================================================
-- Questions should not be asked indiscriminately.
-- =============================================================================

INSERT INTO knowledge.question_context
(question_id, context_type_code, context_value_id, applicability, priority)
VALUES

-- ---------------------------------------------------------------------------
-- Pregnancy
-- ---------------------------------------------------------------------------

(
 'f0c10000-0000-0000-0000-000000000160',
 'SEX',
 (SELECT id
    FROM knowledge.context_value
   WHERE context_type_code='SEX'
     AND value='female'),
 'applies',
 10
),

(
 'f0c10000-0000-0000-0000-000000000161',
 'SEX',
 (SELECT id
    FROM knowledge.context_value
   WHERE context_type_code='SEX'
     AND value='female'),
 'applies',
 10
),

(
 'f0c10000-0000-0000-0000-000000000162',
 'SEX',
 (SELECT id
    FROM knowledge.context_value
   WHERE context_type_code='SEX'
     AND value='female'),
 'applies',
 10
),

(
 'f0c10000-0000-0000-0000-000000000163',
 'SEX',
 (SELECT id
    FROM knowledge.context_value
   WHERE context_type_code='SEX'
     AND value='female'),
 'applies',
 10
),

-- ---------------------------------------------------------------------------
-- Paediatrics
-- ---------------------------------------------------------------------------

(
 'f0c10000-0000-0000-0000-000000000170',
 'AGE',
 (SELECT id
    FROM knowledge.context_value
   WHERE context_type_code='AGE'
     AND value IN ('0-28D','1-11M','1-4Y','5-17Y')
   ORDER BY sort_order
   LIMIT 1),
 'applies',
 10
)

ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 7
-- LONGITUDINAL QUESTION PRINCIPLES
-- =============================================================================
-- These facts are intentionally reusable.
--
-- The same question can be asked:
--
--   encounter 1
--   encounter 2
--   admission
--   discharge
--   follow-up
--   chronic disease review
--
-- The intelligence engine should therefore compare:
--
-- previous_value
-- current_value
-- change_direction
-- change_time
-- source_encounter
-- source_clinician
-- confidence
--
-- The seed does not overwrite historical clinical facts.
-- =============================================================================


-- =============================================================================
-- SECTION 8
-- SAFETY / RED-FLAG QUESTION REGISTRY
-- =============================================================================
-- These questions have very high priority because they can change the
-- immediate care pathway before ordinary diagnostic interrogation continues.
-- =============================================================================

INSERT INTO knowledge.question_trigger
(question_id, trigger_type, trigger_code, priority)
VALUES

-- Breathlessness
('f0c10000-0000-0000-0000-000000000032',
 'symptom',
 'dyspnoea',
 1),

-- Haemoptysis
('f0c10000-0000-0000-0000-000000000016',
 'symptom',
 'haemoptysis',
 1),

-- Chest pain
('f0c10000-0000-0000-0000-000000000051',
 'symptom',
 'chest_pain',
 1),

-- Abdominal bleeding
('f0c10000-0000-0000-0000-000000000076',
 'symptom',
 'vomiting',
 1),

('f0c10000-0000-0000-0000-000000000078',
 'symptom',
 'abdominal_pain',
 1),

-- Neurology
('f0c10000-0000-0000-0000-000000000061',
 'symptom',
 'headache',
 1),

('f0c10000-0000-0000-0000-000000000062',
 'symptom',
 'neurological',
 1),

('f0c10000-0000-0000-0000-000000000063',
 'symptom',
 'neurological',
 1),

('f0c10000-0000-0000-0000-000000000064',
 'symptom',
 'neurological',
 1),

('f0c10000-0000-0000-0000-000000000065',
 'symptom',
 'neurological',
 1),

-- Renal
('f0c10000-0000-0000-0000-000000000085',
 'symptom',
 'urinary',
 1),

-- Paediatric respiratory distress
('f0c10000-0000-0000-0000-000000000172',
 'context',
 'paediatric',
 1),

('f0c10000-0000-0000-0000-000000000173',
 'context',
 'paediatric',
 1),

('f0c10000-0000-0000-0000-000000000174',
 'context',
 'paediatric',
 1)

ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 9
-- FINAL TRANSACTION
-- =============================================================================

COMMIT;


-- =============================================================================
-- END OF Z4
-- =============================================================================