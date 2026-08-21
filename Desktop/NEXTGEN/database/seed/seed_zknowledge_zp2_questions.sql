-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP2.1
-- UNIVERSAL CLINICAL QUESTION INTELLIGENCE
-- CHEST PAIN + ABDOMINAL PAIN + COMPLETE COUGH EXPANSION
-- =============================================================================
--
-- PRINCIPLE
-- ----------
-- Questions are DATA.
--
-- Question
--    ↓
-- Answer
--    ↓
-- Fact
--    ↓
-- Clinical phenotype / mechanism / condition
--    ↓
-- Rule / investigation / management
--
-- IMPORTANT:
-- Questions do NOT diagnose.
-- Questions acquire clinically meaningful facts.
--
-- The engine must therefore:
--   1. Start from the patient's presenting symptom.
--   2. Characterize the symptom completely.
--   3. Identify immediate danger.
--   4. Acquire discriminating associated symptoms.
--   5. Acquire relevant exposures/risk factors.
--   6. Acquire patient context.
--   7. Stop asking questions that no longer add meaningful information.
--   8. Never make a diagnosis merely because a question was answered.
--
-- ZP2.1 covers:
--   A. Chest pain
--   B. Abdominal pain
--   C. Cough completion
--   D. Cross-system danger screening
--
-- =============================================================================


-- =============================================================================
-- 1. ADDITIONAL QUESTIONS
-- =============================================================================

INSERT INTO knowledge.question
(
    id,
    question_code,
    concept_id,
    question_type,
    text,
    response_type,
    priority
)
VALUES

-- -----------------------------------------------------------------------------
-- CHEST PAIN — CORE CHARACTERIZATION
-- -----------------------------------------------------------------------------

(
    'f0c10000-0000-0000-0000-000000000042',
    'CHEST_PAIN_CHARACTER',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'What does the chest pain feel like?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-000000000016',
    'CHEST_PAIN_DURATION',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'How long does each episode of chest pain last?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-000000000017',
    'CHEST_PAIN_SEVERITY',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'How severe is the chest pain?',
    'single_choice',
    55
),
(
    'f0c10000-0000-0000-0000-000000000043',
    'CHEST_PAIN_EXERTIONAL',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Does the chest pain occur or become worse with physical activity?',
    'single_choice',
    70
),
(
    'f0c00000-0000-0000-0000-000000000019',
    'CHEST_PAIN_REST_RELIEF',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Does the chest pain improve with rest?',
    'single_choice',
    65
),
(
    'f0c00000-0000-0000-0000-00000000001a',
    'CHEST_PAIN_POSITIONAL',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Does changing your position affect the chest pain?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-00000000001b',
    'CHEST_PAIN_REPRODUCIBLE',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Does pressing on the chest or moving the chest/upper body reproduce the pain?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-00000000001c',
    'CHEST_PAIN_FOOD_RELATION',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Is the chest pain related to eating or swallowing?',
    'single_choice',
    45
),

-- -----------------------------------------------------------------------------
-- CHEST PAIN — ASSOCIATED CARDIOVASCULAR FEATURES
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-00000000001d',
    'CHEST_PAIN_DYSPNOEA',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you become short of breath with the chest pain?',
    'single_choice',
    90
),
(
    'f0c00000-0000-0000-0000-00000000001e',
    'CHEST_PAIN_DIAPHORESIS',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you become unusually sweaty when the chest pain occurs?',
    'single_choice',
    85
),
(
    'f0c00000-0000-0000-0000-00000000001f',
    'CHEST_PAIN_NAUSEA',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you feel nauseated or vomit when the chest pain occurs?',
    'single_choice',
    75
),
(
    'f0c00000-0000-0000-0000-000000000020',
    'CHEST_PAIN_SYNCOPE',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Have you fainted, nearly fainted, or become severely light-headed with the chest pain?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000021',
    'CHEST_PAIN_PALPITATIONS',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you feel your heart racing, pounding, fluttering, or beating irregularly?',
    'single_choice',
    75
),

-- -----------------------------------------------------------------------------
-- CHEST PAIN — RESPIRATORY FEATURES
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000022',
    'CHEST_PAIN_COUGH',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you have a cough with the chest pain?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000023',
    'CHEST_PAIN_HAEMOPTYSIS',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Have you coughed up blood with the chest pain?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000024',
    'CHEST_PAIN_WHEEZE',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you wheeze or make a whistling sound when breathing?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000025',
    'CHEST_PAIN_FEVER',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Have you had fever or chills with the chest pain?',
    'single_choice',
    65
),

-- -----------------------------------------------------------------------------
-- CHEST PAIN — AORTIC / THROMBOEMBOLIC / INFECTIVE DANGER
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000026',
    'CHEST_PAIN_BACK_RADIATION',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Does the chest pain spread to the back?',
    'single_choice',
    95
),
(
    'f0c00000-0000-0000-0000-000000000027',
    'CHEST_PAIN_UNILATERAL_LEG_SWELLING',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you currently have one-sided leg swelling or pain?',
    'single_choice',
    90
),
(
    'f0c00000-0000-0000-0000-000000000028',
    'CHEST_PAIN_RECENT_IMMOBILIZATION',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Have you recently had prolonged immobility, major surgery, or a long journey?',
    'single_choice',
    85
),

-- -----------------------------------------------------------------------------
-- CHEST PAIN — CARDIOVASCULAR RISK CONTEXT
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000029',
    'CHEST_PAIN_CARDIOVASCULAR_HISTORY',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Have you previously been diagnosed with heart disease, angina, a heart attack, stroke, or peripheral vascular disease?',
    'single_choice',
    80
),
(
    'f0c00000-0000-0000-0000-00000000002a',
    'CHEST_PAIN_DIABETES',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you have diabetes?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-00000000002b',
    'CHEST_PAIN_HYPERTENSION',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you have high blood pressure?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-00000000002c',
    'CHEST_PAIN_SMOKING',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Do you currently smoke or have you smoked tobacco in the past?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-00000000002d',
    'CHEST_PAIN_FAMILY_PREMATURE_CVD',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Has a close family member had heart disease or sudden cardiac death at a young age?',
    'single_choice',
    55
),

-- -----------------------------------------------------------------------------
-- CHEST PAIN — THROMBOEMBOLIC / PREGNANCY CONTEXT
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-00000000002e',
    'CHEST_PAIN_PREGNANCY_POSTPARTUM',
    'f0a00000-0000-0000-0000-000000000017',
    'clinical',
    'Are you pregnant or have you recently given birth?',
    'single_choice',
    90
),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN — LOCATION / TIME / CHARACTER
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-00000000002f',
    'ABDO_PAIN_ONSET',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Did the abdominal pain start suddenly or gradually?',
    'single_choice',
    65
),
(
    'f0c00000-0000-0000-0000-000000000030',
    'ABDO_PAIN_SITE',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Where exactly is the abdominal pain?',
    'single_choice',
    80
),
(
    'f0c00000-0000-0000-0000-000000000031',
    'ABDO_PAIN_MIGRATION',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Has the abdominal pain moved from where it first started?',
    'single_choice',
    65
),
(
    'f0c00000-0000-0000-0000-000000000032',
    'ABDO_PAIN_CHARACTER',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'What does the abdominal pain feel like?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000033',
    'ABDO_PAIN_SEVERITY',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'How severe is the abdominal pain?',
    'single_choice',
    65
),
(
    'f0c00000-0000-0000-0000-000000000034',
    'ABDO_PAIN_DURATION',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'How long has the abdominal pain been present?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000035',
    'ABDO_PAIN_RADIATION',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Does the abdominal pain spread anywhere else?',
    'single_choice',
    65
),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN — FOOD / MOVEMENT / BOWEL
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000036',
    'ABDO_PAIN_FOOD_RELATION',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Is the abdominal pain related to eating?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000037',
    'ABDO_PAIN_MOVEMENT',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Does movement, walking, coughing, or changing position make the abdominal pain worse?',
    'single_choice',
    70
),
(
    'f0c00000-0000-0000-0000-000000000038',
    'ABDO_PAIN_BOWEL_CHANGE',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you had a change in your bowel movements since the abdominal pain started?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000039',
    'ABDO_PAIN_DIARRHOEA',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you had diarrhoea?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-00000000003a',
    'ABDO_PAIN_CONSTIPATION',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you been unable to pass stool or had significant constipation?',
    'single_choice',
    70
),
(
    'f0c00000-0000-0000-0000-00000000003b',
    'ABDO_PAIN_FLATUS',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Are you still passing gas?',
    'single_choice',
    80
),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN — VOMITING / GI BLEED / JAUNDICE
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-00000000003c',
    'ABDO_PAIN_VOMITING',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you been vomiting?',
    'single_choice',
    70
),
(
    'f0c00000-0000-0000-0000-00000000003d',
    'ABDO_PAIN_BLOOD_VOMIT',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you vomited blood or material that looks like coffee grounds?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-00000000003e',
    'ABDO_PAIN_BLOOD_STOOL',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you noticed blood in your stool or black, tarry stool?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-00000000003f',
    'ABDO_PAIN_JAUNDICE',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have your eyes or skin become yellow?',
    'single_choice',
    80
),
(
    'f0c00000-0000-0000-0000-000000000040',
    'ABDO_PAIN_FEVER',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you had fever or chills with the abdominal pain?',
    'single_choice',
    70
),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN — URINARY
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000041',
    'ABDO_PAIN_DYSURIA',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Do you have pain or burning when passing urine?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-000000000042',
    'ABDO_PAIN_URINARY_FREQUENCY',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Are you passing urine more frequently than usual?',
    'single_choice',
    50
),
(
    'f0c00000-0000-0000-0000-000000000043',
    'ABDO_PAIN_HAEMATURIA',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you noticed blood in your urine?',
    'single_choice',
    70
),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN — REPRODUCTIVE / GYNAECOLOGICAL
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000044',
    'ABDO_PAIN_PREGNANCY_POSSIBLE',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Could you be pregnant?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000045',
    'ABDO_PAIN_VAGINAL_BLEEDING',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you had vaginal bleeding?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000046',
    'ABDO_PAIN_VAGINAL_DISCHARGE',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you had unusual vaginal discharge?',
    'single_choice',
    65
),
(
    'f0c00000-0000-0000-0000-000000000047',
    'ABDO_PAIN_LMP',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'When was the first day of your last menstrual period?',
    'single_choice',
    100
),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN — SURGICAL DANGER
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-000000000048',
    'ABDO_PAIN_ABDOMINAL_RIGIDITY',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Has your abdomen become unusually hard or rigid?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000049',
    'ABDO_PAIN_COLLAPSE',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Have you fainted, collapsed, or become severely weak with the abdominal pain?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-00000000004a',
    'ABDO_PAIN_ABDOMINAL_DISTENSION',
    'f0a00000-0000-0000-0000-000000000018',
    'clinical',
    'Has your abdomen become markedly swollen or distended?',
    'single_choice',
    85
),

-- -----------------------------------------------------------------------------
-- COUGH — COMPLETE UNIVERSAL CHARACTERIZATION
-- -----------------------------------------------------------------------------

(
    'f0c00000-0000-0000-0000-00000000004b',
    'COUGH_SPUTUM_COLOUR',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'What colour is the sputum?',
    'single_choice',
    60
),
(
    'f0c00000-0000-0000-0000-00000000004c',
    'COUGH_HAEMOPTYSIS',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Have you coughed up blood?',
    'single_choice',
    95
),
(
    'f0c00000-0000-0000-0000-00000000004d',
    'COUGH_NIGHT',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Is the cough worse at night or does it wake you from sleep?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-00000000004e',
    'COUGH_EXERTIONAL',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Does physical activity make the cough worse?',
    'single_choice',
    45
),
(
    'f0c00000-0000-0000-0000-00000000004f',
    'COUGH_POSTURAL',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Does changing position make the cough worse?',
    'single_choice',
    45
),
(
    'f0c00000-0000-0000-0000-000000000050',
    'COUGH_NIGHT_SWEATS',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Have you been having drenching night sweats?',
    'single_choice',
    80
),
(
    'f0c00000-0000-0000-0000-000000000051',
    'COUGH_WEIGHT_LOSS',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Have you had unexplained weight loss?',
    'single_choice',
    80
),
(
    'f0c00000-0000-0000-0000-000000000052',
    'COUGH_TB_CONTACT',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Have you been in close contact with someone who has tuberculosis or a prolonged cough?',
    'single_choice',
    90
),
(
    'f0c00000-0000-0000-0000-000000000053',
    'COUGH_SMOKE_EXPOSURE',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Are you exposed to tobacco smoke, biomass smoke, dust, fumes, or other respiratory irritants?',
    'single_choice',
    65
),
(
    'f0c00000-0000-0000-0000-000000000054',
    'COUGH_ACE_INHIBITOR',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Are you taking an ACE inhibitor blood-pressure medicine such as enalapril, lisinopril, or captopril?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-000000000055',
    'COUGH_ASPIRATION',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Did the cough begin suddenly while eating, drinking, or after something may have entered the airway?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000056',
    'COUGH_STRIDOR',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Do you make a harsh or high-pitched sound when breathing in?',
    'single_choice',
    100
),
(
    'f0c00000-0000-0000-0000-000000000057',
    'COUGH_WHOOP',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'After coughing repeatedly, do you make a high-pitched "whoop" when breathing in?',
    'single_choice',
    75
),
(
    'f0c00000-0000-0000-0000-000000000058',
    'COUGH_BARKING',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Does the cough sound harsh or barking like a seal?',
    'single_choice',
    75
),
(
    'f0c00000-0000-0000-0000-000000000059',
    'COUGH_REFLUX',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Do you have heartburn, acid coming into your mouth, or a sour taste associated with the cough?',
    'single_choice',
    55
),
(
    'f0c00000-0000-0000-0000-00000000005a',
    'COUGH_POSTNASAL',
    'f0a00000-0000-0000-0000-000000000001',
    'clinical',
    'Do you have a blocked or runny nose or a sensation of mucus dripping into the throat?',
    'single_choice',
    50
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. ANSWER OPTIONS — CHEST PAIN
-- =============================================================================

INSERT INTO knowledge.answer_option
(
    id,
    question_id,
    answer_code,
    label,
    value_text,
    sort_order
)
VALUES

-- CHARACTER
('f0d10000-0000-0000-0000-000000000040','f0c10000-0000-0000-0000-000000000042','PRESSURE','Pressure/heaviness','PRESSURE',1),
('f0d10000-0000-0000-0000-000000000041','f0c10000-0000-0000-0000-000000000042','TIGHTNESS','Tightness','TIGHTNESS',2),
('f0d10000-0000-0000-0000-000000000043','f0c10000-0000-0000-0000-000000000042','BURNING','Burning','BURNING',3),
('f0d10000-0000-0000-0000-000000000044','f0c10000-0000-0000-0000-000000000042','STABBING','Stabbing','STABBING',4),
('f0d10000-0000-0000-0000-000000000042','f0c10000-0000-0000-0000-000000000042','SHARP','Sharp','SHARP',5),
('f0d00000-0000-0000-0000-000000000036','f0c10000-0000-0000-0000-000000000042','TEARING','Tearing/ripping','TEARING',6),
('f0d00000-0000-0000-0000-000000000037','f0c10000-0000-0000-0000-000000000042','OTHER','Other','OTHER',7),

-- DURATION
('f0d00000-0000-0000-0000-000000000038','f0c00000-0000-0000-0000-000000000016','SECONDS','Seconds','SECONDS',1),
('f0d00000-0000-0000-0000-000000000039','f0c00000-0000-0000-0000-000000000016','MINUTES','Minutes','MINUTES',2),
('f0d00000-0000-0000-0000-00000000003a','f0c00000-0000-0000-0000-000000000016','HOURS','Hours','HOURS',3),
('f0d00000-0000-0000-0000-00000000003b','f0c00000-0000-0000-0000-000000000016','CONSTANT','Constant','CONSTANT',4),

-- SEVERITY
('f0d00000-0000-0000-0000-00000000003c','f0c00000-0000-0000-0000-000000000017','MILD','Mild','MILD',1),
('f0d00000-0000-0000-0000-00000000003d','f0c00000-0000-0000-0000-000000000017','MODERATE','Moderate','MODERATE',2),
('f0d00000-0000-0000-0000-00000000003e','f0c00000-0000-0000-0000-000000000017','SEVERE','Severe','SEVERE',3),

-- YES/NO
('f0d00000-0000-0000-0000-00000000003f','f0c10000-0000-0000-0000-000000000043','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000040','f0c10000-0000-0000-0000-000000000043','NO','No','NO',2),

-- RADIATION
('f0d00000-0000-0000-0000-000000000023','f0c10000-0000-0000-0000-000000000044','NONE','No radiation','NONE',1),
('f0d00000-0000-0000-0000-000000000024','f0c10000-0000-0000-0000-000000000044','LEFT_ARM','Left arm','LEFT_ARM',2),
('f0d00000-0000-0000-0000-000000000025','f0c10000-0000-0000-0000-000000000044','JAW','Jaw','JAW',3),
('f0d00000-0000-0000-0000-000000000026','f0c10000-0000-0000-0000-000000000044','BACK','Back','BACK',4),

('f0d00000-0000-0000-0000-000000000041','f0c00000-0000-0000-0000-000000000019','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000042','f0c00000-0000-0000-0000-000000000019','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000043','f0c00000-0000-0000-0000-00000000001a','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000044','f0c00000-0000-0000-0000-00000000001a','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000045','f0c00000-0000-0000-0000-00000000001b','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000046','f0c00000-0000-0000-0000-00000000001b','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000047','f0c00000-0000-0000-0000-00000000001c','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000048','f0c00000-0000-0000-0000-00000000001c','NO','No','NO',2),

-- CHEST ASSOCIATED
('f0d00000-0000-0000-0000-000000000049','f0c00000-0000-0000-0000-00000000001d','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000004a','f0c00000-0000-0000-0000-00000000001d','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000004b','f0c00000-0000-0000-0000-00000000001e','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000004c','f0c00000-0000-0000-0000-00000000001e','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000004d','f0c00000-0000-0000-0000-00000000001f','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000004e','f0c00000-0000-0000-0000-00000000001f','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000004f','f0c00000-0000-0000-0000-000000000020','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000050','f0c00000-0000-0000-0000-000000000020','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000051','f0c00000-0000-0000-0000-000000000021','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000052','f0c00000-0000-0000-0000-000000000021','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000053','f0c00000-0000-0000-0000-000000000022','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000054','f0c00000-0000-0000-0000-000000000022','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000055','f0c00000-0000-0000-0000-000000000023','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000056','f0c00000-0000-0000-0000-000000000023','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000057','f0c00000-0000-0000-0000-000000000024','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000058','f0c00000-0000-0000-0000-000000000024','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000059','f0c00000-0000-0000-0000-000000000025','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000005a','f0c00000-0000-0000-0000-000000000025','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000005b','f0c00000-0000-0000-0000-000000000026','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000005c','f0c00000-0000-0000-0000-000000000026','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000005d','f0c00000-0000-0000-0000-000000000027','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000005e','f0c00000-0000-0000-0000-000000000027','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000005f','f0c00000-0000-0000-0000-000000000028','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000060','f0c00000-0000-0000-0000-000000000028','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000061','f0c00000-0000-0000-0000-000000000029','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000062','f0c00000-0000-0000-0000-000000000029','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000063','f0c00000-0000-0000-0000-00000000002a','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000064','f0c00000-0000-0000-0000-00000000002a','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000065','f0c00000-0000-0000-0000-00000000002b','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000066','f0c00000-0000-0000-0000-00000000002b','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000067','f0c00000-0000-0000-0000-00000000002c','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000068','f0c00000-0000-0000-0000-00000000002c','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000069','f0c00000-0000-0000-0000-00000000002d','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000006a','f0c00000-0000-0000-0000-00000000002d','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000006b','f0c00000-0000-0000-0000-00000000002e','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000006c','f0c00000-0000-0000-0000-00000000002e','NO','No','NO',2)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. ANSWER OPTIONS — ABDOMINAL PAIN
-- =============================================================================

INSERT INTO knowledge.answer_option
(
    id,
    question_id,
    answer_code,
    label,
    value_text,
    sort_order
)
VALUES

-- ONSET
('f0d00000-0000-0000-0000-00000000006d','f0c00000-0000-0000-0000-00000000002f','SUDDEN','Sudden','SUDDEN',1),
('f0d00000-0000-0000-0000-00000000006e','f0c00000-0000-0000-0000-00000000002f','GRADUAL','Gradual','GRADUAL',2),

-- SITE
('f0d00000-0000-0000-0000-00000000006f','f0c00000-0000-0000-0000-000000000030','EPIGASTRIC','Upper central abdomen / epigastrium','EPIGASTRIC',1),
('f0d00000-0000-0000-0000-000000000070','f0c00000-0000-0000-0000-000000000030','RUQ','Right upper abdomen','RUQ',2),
('f0d00000-0000-0000-0000-000000000071','f0c00000-0000-0000-0000-000000000030','LUQ','Left upper abdomen','LUQ',3),
('f0d00000-0000-0000-0000-000000000072','f0c00000-0000-0000-0000-000000000030','PERIUMBILICAL','Around the umbilicus','PERIUMBILICAL',4),
('f0d00000-0000-0000-0000-000000000073','f0c00000-0000-0000-0000-000000000030','RLQ','Right lower abdomen','RLQ',5),
('f0d00000-0000-0000-0000-000000000074','f0c00000-0000-0000-0000-000000000030','LLQ','Left lower abdomen','LLQ',6),
('f0d00000-0000-0000-0000-000000000075','f0c00000-0000-0000-0000-000000000030','SUPRAPUBIC','Lower central abdomen / suprapubic','SUPRAPUBIC',7),
('f0d00000-0000-0000-0000-000000000076','f0c00000-0000-0000-0000-000000000030','DIFFUSE','Diffuse / generalized','DIFFUSE',8),

-- MIGRATION
('f0d00000-0000-0000-0000-000000000077','f0c00000-0000-0000-0000-000000000031','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000078','f0c00000-0000-0000-0000-000000000031','NO','No','NO',2),

-- CHARACTER
('f0d00000-0000-0000-0000-000000000079','f0c00000-0000-0000-0000-000000000032','COLICKY','Colicky/cramping','COLICKY',1),
('f0d00000-0000-0000-0000-00000000007a','f0c00000-0000-0000-0000-000000000032','BURNING','Burning','BURNING',2),
('f0d00000-0000-0000-0000-00000000007b','f0c00000-0000-0000-0000-000000000032','SHARP','Sharp/stabbing','SHARP',3),
('f0d00000-0000-0000-0000-00000000007c','f0c00000-0000-0000-0000-000000000032','CONSTANT','Constant','CONSTANT',4),
('f0d00000-0000-0000-0000-00000000007d','f0c00000-0000-0000-0000-000000000032','DULL','Dull/aching','DULL',5),

-- SEVERITY
('f0d00000-0000-0000-0000-00000000007e','f0c00000-0000-0000-0000-000000000033','MILD','Mild','MILD',1),
('f0d00000-0000-0000-0000-00000000007f','f0c00000-0000-0000-0000-000000000033','MODERATE','Moderate','MODERATE',2),
('f0d00000-0000-0000-0000-000000000080','f0c00000-0000-0000-0000-000000000033','SEVERE','Severe','SEVERE',3),

-- DURATION
('f0d00000-0000-0000-0000-000000000081','f0c00000-0000-0000-0000-000000000034','HOURS','Hours','HOURS',1),
('f0d00000-0000-0000-0000-000000000082','f0c00000-0000-0000-0000-000000000034','DAYS','Days','DAYS',2),
('f0d00000-0000-0000-0000-000000000083','f0c00000-0000-0000-0000-000000000034','WEEKS','Weeks','WEEKS',3),
('f0d00000-0000-0000-0000-000000000084','f0c00000-0000-0000-0000-000000000034','MONTHS','Months','MONTHS',4),

-- RADIATION
('f0d00000-0000-0000-0000-000000000085','f0c00000-0000-0000-0000-000000000035','BACK','Back','BACK',1),
('f0d00000-0000-0000-0000-000000000086','f0c00000-0000-0000-0000-000000000035','SHOULDER','Shoulder','SHOULDER',2),
('f0d00000-0000-0000-0000-000000000087','f0c00000-0000-0000-0000-000000000035','GROIN','Groin','GROIN',3),
('f0d00000-0000-0000-0000-000000000088','f0c00000-0000-0000-0000-000000000035','NONE','No radiation','NONE',4),

-- UNIVERSAL YES/NO
('f0d00000-0000-0000-0000-000000000089','f0c00000-0000-0000-0000-000000000036','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000008a','f0c00000-0000-0000-0000-000000000036','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000008b','f0c00000-0000-0000-0000-000000000037','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000008c','f0c00000-0000-0000-0000-000000000037','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000008d','f0c00000-0000-0000-0000-000000000038','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000008e','f0c00000-0000-0000-0000-000000000038','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000008f','f0c00000-0000-0000-0000-000000000039','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000090','f0c00000-0000-0000-0000-000000000039','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000091','f0c00000-0000-0000-0000-00000000003a','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000092','f0c00000-0000-0000-0000-00000000003a','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000093','f0c00000-0000-0000-0000-00000000003b','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000094','f0c00000-0000-0000-0000-00000000003b','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000095','f0c00000-0000-0000-0000-00000000003c','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000096','f0c00000-0000-0000-0000-00000000003c','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000097','f0c00000-0000-0000-0000-00000000003d','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-000000000098','f0c00000-0000-0000-0000-00000000003d','NO','No','NO',2),

('f0d00000-0000-0000-0000-000000000099','f0c00000-0000-0000-0000-00000000003e','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000009a','f0c00000-0000-0000-0000-00000000003e','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000009b','f0c00000-0000-0000-0000-00000000003f','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000009c','f0c00000-0000-0000-0000-00000000003f','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000009d','f0c00000-0000-0000-0000-000000000040','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-00000000009e','f0c00000-0000-0000-0000-000000000040','NO','No','NO',2),

('f0d00000-0000-0000-0000-00000000009f','f0c00000-0000-0000-0000-000000000041','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000a0','f0c00000-0000-0000-0000-000000000041','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000a1','f0c00000-0000-0000-0000-000000000042','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000a2','f0c00000-0000-0000-0000-000000000042','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000a3','f0c00000-0000-0000-0000-000000000043','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000a4','f0c00000-0000-0000-0000-000000000043','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000a5','f0c00000-0000-0000-0000-000000000044','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000a6','f0c00000-0000-0000-0000-000000000044','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000a7','f0c00000-0000-0000-0000-000000000045','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000a8','f0c00000-0000-0000-0000-000000000045','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000a9','f0c00000-0000-0000-0000-000000000046','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000aa','f0c00000-0000-0000-0000-000000000046','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000ab','f0c00000-0000-0000-0000-000000000048','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000ac','f0c00000-0000-0000-0000-000000000048','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000ad','f0c00000-0000-0000-0000-000000000049','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000ae','f0c00000-0000-0000-0000-000000000049','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000af','f0c00000-0000-0000-0000-00000000004a','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000b0','f0c00000-0000-0000-0000-00000000004a','NO','No','NO',2)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. ANSWER OPTIONS — COUGH COMPLETION
-- =============================================================================

INSERT INTO knowledge.answer_option
(
    id,
    question_id,
    answer_code,
    label,
    value_text,
    sort_order
)
VALUES

('f0d00000-0000-0000-0000-0000000000b1','f0c00000-0000-0000-0000-00000000004b','CLEAR','Clear/white','CLEAR',1),
('f0d00000-0000-0000-0000-0000000000b2','f0c00000-0000-0000-0000-00000000004b','YELLOW','Yellow','YELLOW',2),
('f0d00000-0000-0000-0000-0000000000b3','f0c00000-0000-0000-0000-00000000004b','GREEN','Green','GREEN',3),
('f0d00000-0000-0000-0000-0000000000b4','f0c00000-0000-0000-0000-00000000004b','BLOOD_STAINED','Blood-stained','BLOOD_STAINED',4),

('f0d00000-0000-0000-0000-0000000000b5','f0c00000-0000-0000-0000-00000000004c','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000b6','f0c00000-0000-0000-0000-00000000004c','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000b7','f0c00000-0000-0000-0000-00000000004d','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000b8','f0c00000-0000-0000-0000-00000000004d','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000b9','f0c00000-0000-0000-0000-00000000004e','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000ba','f0c00000-0000-0000-0000-00000000004e','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000bb','f0c00000-0000-0000-0000-00000000004f','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000bc','f0c00000-0000-0000-0000-00000000004f','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000bd','f0c00000-0000-0000-0000-000000000050','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000be','f0c00000-0000-0000-0000-000000000050','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000bf','f0c00000-0000-0000-0000-000000000051','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000c0','f0c00000-0000-0000-0000-000000000051','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000c1','f0c00000-0000-0000-0000-000000000052','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000c2','f0c00000-0000-0000-0000-000000000052','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000c3','f0c00000-0000-0000-0000-000000000053','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000c4','f0c00000-0000-0000-0000-000000000053','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000c5','f0c00000-0000-0000-0000-000000000054','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000c6','f0c00000-0000-0000-0000-000000000054','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000c7','f0c00000-0000-0000-0000-000000000055','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000c8','f0c00000-0000-0000-0000-000000000055','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000c9','f0c00000-0000-0000-0000-000000000056','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000ca','f0c00000-0000-0000-0000-000000000056','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000cb','f0c00000-0000-0000-0000-000000000057','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000cc','f0c00000-0000-0000-0000-000000000057','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000cd','f0c00000-0000-0000-0000-000000000058','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000ce','f0c00000-0000-0000-0000-000000000058','NO','No','NO',2),

('f0d00000-0000-0000-0000-0000000000cf','f0c00000-0000-0000-0000-000000000059','YES','Yes','YES',1),
('f0d00000-0000-0000-0000-0000000000d0','f0c00000-0000-0000-0000-000000000059','NO','No','NO',2)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. FACT MAPPINGS
-- =============================================================================
-- Existing facts from earlier seeds are deliberately reused.
-- New answers map directly to clinically meaningful atomic facts.
-- =============================================================================

INSERT INTO knowledge.fact_mapping
(answer_option_id, fact_definition_code, value)
VALUES

-- -----------------------------------------------------------------------------
-- FIX / COMPLETE EXISTING CHEST PAIN RADIATION MAPPINGS
-- -----------------------------------------------------------------------------

('f0d00000-0000-0000-0000-000000000023','CHEST_PAIN_RADIATION','NONE'),
('f0d00000-0000-0000-0000-000000000024','CHEST_PAIN_RADIATION','LEFT_ARM'),
('f0d00000-0000-0000-0000-000000000025','CHEST_PAIN_RADIATION','JAW'),
('f0d00000-0000-0000-0000-000000000026','CHEST_PAIN_RADIATION','BACK'),

-- -----------------------------------------------------------------------------
-- CHEST PAIN
-- -----------------------------------------------------------------------------

('f0d10000-0000-0000-0000-000000000040','CHEST_PAIN_CHARACTER','PRESSURE'),
('f0d10000-0000-0000-0000-000000000041','CHEST_PAIN_CHARACTER','TIGHTNESS'),
('f0d10000-0000-0000-0000-000000000043','CHEST_PAIN_CHARACTER','BURNING'),
('f0d10000-0000-0000-0000-000000000044','CHEST_PAIN_CHARACTER','STABBING'),
('f0d10000-0000-0000-0000-000000000042','CHEST_PAIN_CHARACTER','SHARP'),
('f0d00000-0000-0000-0000-000000000036','CHEST_PAIN_CHARACTER','TEARING'),
('f0d00000-0000-0000-0000-000000000037','CHEST_PAIN_CHARACTER','OTHER'),

('f0d00000-0000-0000-0000-000000000038','CHEST_PAIN_DURATION','SECONDS'),
('f0d00000-0000-0000-0000-000000000039','CHEST_PAIN_DURATION','MINUTES'),
('f0d00000-0000-0000-0000-00000000003a','CHEST_PAIN_DURATION','HOURS'),
('f0d00000-0000-0000-0000-00000000003b','CHEST_PAIN_DURATION','CONSTANT'),

('f0d00000-0000-0000-0000-00000000003c','CHEST_PAIN_SEVERITY','MILD'),
('f0d00000-0000-0000-0000-00000000003d','CHEST_PAIN_SEVERITY','MODERATE'),
('f0d00000-0000-0000-0000-00000000003e','CHEST_PAIN_SEVERITY','SEVERE'),

('f0d00000-0000-0000-0000-00000000003f','CHEST_PAIN_EXERTIONAL','YES'),
('f0d00000-0000-0000-0000-000000000040','CHEST_PAIN_EXERTIONAL','NO'),

('f0d00000-0000-0000-0000-000000000041','CHEST_PAIN_REST_RELIEF','YES'),
('f0d00000-0000-0000-0000-000000000042','CHEST_PAIN_REST_RELIEF','NO'),

('f0d00000-0000-0000-0000-000000000043','CHEST_PAIN_POSITIONAL','YES'),
('f0d00000-0000-0000-0000-000000000044','CHEST_PAIN_POSITIONAL','NO'),

('f0d00000-0000-0000-0000-000000000045','CHEST_PAIN_REPRODUCIBLE','YES'),
('f0d00000-0000-0000-0000-000000000046','CHEST_PAIN_REPRODUCIBLE','NO'),

('f0d00000-0000-0000-0000-000000000047','CHEST_PAIN_FOOD_RELATION','YES'),
('f0d00000-0000-0000-0000-000000000048','CHEST_PAIN_FOOD_RELATION','NO'),

('f0d00000-0000-0000-0000-000000000049','CHEST_PAIN_DYSPNOEA','YES'),
('f0d00000-0000-0000-0000-00000000004a','CHEST_PAIN_DYSPNOEA','NO'),

('f0d00000-0000-0000-0000-00000000004b','CHEST_PAIN_DIAPHORESIS','YES'),
('f0d00000-0000-0000-0000-00000000004c','CHEST_PAIN_DIAPHORESIS','NO'),

('f0d00000-0000-0000-0000-00000000004d','CHEST_PAIN_NAUSEA','YES'),
('f0d00000-0000-0000-0000-00000000004e','CHEST_PAIN_NAUSEA','NO'),

('f0d00000-0000-0000-0000-00000000004f','CHEST_PAIN_SYNCOPE','YES'),
('f0d00000-0000-0000-0000-000000000050','CHEST_PAIN_SYNCOPE','NO'),

('f0d00000-0000-0000-0000-000000000051','CHEST_PAIN_PALPITATIONS','YES'),
('f0d00000-0000-0000-0000-000000000052','CHEST_PAIN_PALPITATIONS','NO'),

('f0d00000-0000-0000-0000-000000000053','CHEST_PAIN_COUGH','YES'),
('f0d00000-0000-0000-0000-000000000054','CHEST_PAIN_COUGH','NO'),

('f0d00000-0000-0000-0000-000000000055','CHEST_PAIN_HAEMOPTYSIS','YES'),
('f0d00000-0000-0000-0000-000000000056','CHEST_PAIN_HAEMOPTYSIS','NO'),

('f0d00000-0000-0000-0000-000000000057','CHEST_PAIN_WHEEZE','YES'),
('f0d00000-0000-0000-0000-000000000058','CHEST_PAIN_WHEEZE','NO'),

('f0d00000-0000-0000-0000-000000000059','CHEST_PAIN_FEVER','YES'),
('f0d00000-0000-0000-0000-00000000005a','CHEST_PAIN_FEVER','NO'),

('f0d00000-0000-0000-0000-00000000005b','CHEST_PAIN_BACK_RADIATION','YES'),
('f0d00000-0000-0000-0000-00000000005c','CHEST_PAIN_BACK_RADIATION','NO'),

('f0d00000-0000-0000-0000-00000000005d','CHEST_PAIN_UNILATERAL_LEG_SWELLING','YES'),
('f0d00000-0000-0000-0000-00000000005e','CHEST_PAIN_UNILATERAL_LEG_SWELLING','NO'),

('f0d00000-0000-0000-0000-00000000005f','CHEST_PAIN_RECENT_IMMOBILIZATION','YES'),
('f0d00000-0000-0000-0000-000000000060','CHEST_PAIN_RECENT_IMMOBILIZATION','NO'),

('f0d00000-0000-0000-0000-000000000061','CHEST_PAIN_CARDIOVASCULAR_HISTORY','YES'),
('f0d00000-0000-0000-0000-000000000062','CHEST_PAIN_CARDIOVASCULAR_HISTORY','NO'),

('f0d00000-0000-0000-0000-000000000063','CHEST_PAIN_DIABETES','YES'),
('f0d00000-0000-0000-0000-000000000064','CHEST_PAIN_DIABETES','NO'),

('f0d00000-0000-0000-0000-000000000065','CHEST_PAIN_HYPERTENSION','YES'),
('f0d00000-0000-0000-0000-000000000066','CHEST_PAIN_HYPERTENSION','NO'),

('f0d00000-0000-0000-0000-000000000067','CHEST_PAIN_SMOKING','YES'),
('f0d00000-0000-0000-0000-000000000068','CHEST_PAIN_SMOKING','NO'),

('f0d00000-0000-0000-0000-000000000069','CHEST_PAIN_FAMILY_PREMATURE_CVD','YES'),
('f0d00000-0000-0000-0000-00000000006a','CHEST_PAIN_FAMILY_PREMATURE_CVD','NO'),

('f0d00000-0000-0000-0000-00000000006b','CHEST_PAIN_PREGNANCY_POSTPARTUM','YES'),
('f0d00000-0000-0000-0000-00000000006c','CHEST_PAIN_PREGNANCY_POSTPARTUM','NO'),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN
-- -----------------------------------------------------------------------------

('f0d00000-0000-0000-0000-00000000006d','ABDO_PAIN_ONSET','SUDDEN'),
('f0d00000-0000-0000-0000-00000000006e','ABDO_PAIN_ONSET','GRADUAL'),

('f0d00000-0000-0000-0000-00000000006f','ABDO_PAIN_SITE','EPIGASTRIC'),
('f0d00000-0000-0000-0000-000000000070','ABDO_PAIN_SITE','RUQ'),
('f0d00000-0000-0000-0000-000000000071','ABDO_PAIN_SITE','LUQ'),
('f0d00000-0000-0000-0000-000000000072','ABDO_PAIN_SITE','PERIUMBILICAL'),
('f0d00000-0000-0000-0000-000000000073','ABDO_PAIN_SITE','RLQ'),
('f0d00000-0000-0000-0000-000000000074','ABDO_PAIN_SITE','LLQ'),
('f0d00000-0000-0000-0000-000000000075','ABDO_PAIN_SITE','SUPRAPUBIC'),
('f0d00000-0000-0000-0000-000000000076','ABDO_PAIN_SITE','DIFFUSE'),

('f0d00000-0000-0000-0000-000000000077','ABDO_PAIN_MIGRATION','YES'),
('f0d00000-0000-0000-0000-000000000078','ABDO_PAIN_MIGRATION','NO'),

('f0d00000-0000-0000-0000-000000000079','ABDO_PAIN_CHARACTER','COLICKY'),
('f0d00000-0000-0000-0000-00000000007a','ABDO_PAIN_CHARACTER','BURNING'),
('f0d00000-0000-0000-0000-00000000007b','ABDO_PAIN_CHARACTER','SHARP'),
('f0d00000-0000-0000-0000-00000000007c','ABDO_PAIN_CHARACTER','CONSTANT'),
('f0d00000-0000-0000-0000-00000000007d','ABDO_PAIN_CHARACTER','DULL'),

('f0d00000-0000-0000-0000-00000000007e','ABDO_PAIN_SEVERITY','MILD'),
('f0d00000-0000-0000-0000-00000000007f','ABDO_PAIN_SEVERITY','MODERATE'),
('f0d00000-0000-0000-0000-000000000080','ABDO_PAIN_SEVERITY','SEVERE'),

('f0d00000-0000-0000-0000-000000000081','ABDO_PAIN_DURATION','HOURS'),
('f0d00000-0000-0000-0000-000000000082','ABDO_PAIN_DURATION','DAYS'),
('f0d00000-0000-0000-0000-000000000083','ABDO_PAIN_DURATION','WEEKS'),
('f0d00000-0000-0000-0000-000000000084','ABDO_PAIN_DURATION','MONTHS'),

('f0d00000-0000-0000-0000-000000000085','ABDO_PAIN_RADIATION','BACK'),
('f0d00000-0000-0000-0000-000000000086','ABDO_PAIN_RADIATION','SHOULDER'),
('f0d00000-0000-0000-0000-000000000087','ABDO_PAIN_RADIATION','GROIN'),
('f0d00000-0000-0000-0000-000000000088','ABDO_PAIN_RADIATION','NONE'),

('f0d00000-0000-0000-0000-000000000089','ABDO_PAIN_FOOD_RELATION','YES'),
('f0d00000-0000-0000-0000-00000000008a','ABDO_PAIN_FOOD_RELATION','NO'),

('f0d00000-0000-0000-0000-00000000008b','ABDO_PAIN_MOVEMENT','YES'),
('f0d00000-0000-0000-0000-00000000008c','ABDO_PAIN_MOVEMENT','NO'),

('f0d00000-0000-0000-0000-00000000008d','ABDO_PAIN_BOWEL_CHANGE','YES'),
('f0d00000-0000-0000-0000-00000000008e','ABDO_PAIN_BOWEL_CHANGE','NO'),

('f0d00000-0000-0000-0000-00000000008f','ABDO_PAIN_DIARRHOEA','YES'),
('f0d00000-0000-0000-0000-000000000090','ABDO_PAIN_DIARRHOEA','NO'),

('f0d00000-0000-0000-0000-000000000091','ABDO_PAIN_CONSTIPATION','YES'),
('f0d00000-0000-0000-0000-000000000092','ABDO_PAIN_CONSTIPATION','NO'),

('f0d00000-0000-0000-0000-000000000093','ABDO_PAIN_FLATUS','YES'),
('f0d00000-0000-0000-0000-000000000094','ABDO_PAIN_FLATUS','NO'),

('f0d00000-0000-0000-0000-000000000095','ABDO_PAIN_VOMITING','YES'),
('f0d00000-0000-0000-0000-000000000096','ABDO_PAIN_VOMITING','NO'),

('f0d00000-0000-0000-0000-000000000097','ABDO_PAIN_BLOOD_VOMIT','YES'),
('f0d00000-0000-0000-0000-000000000098','ABDO_PAIN_BLOOD_VOMIT','NO'),

('f0d00000-0000-0000-0000-000000000099','ABDO_PAIN_BLOOD_STOOL','YES'),
('f0d00000-0000-0000-0000-00000000009a','ABDO_PAIN_BLOOD_STOOL','NO'),

('f0d00000-0000-0000-0000-00000000009b','ABDO_PAIN_JAUNDICE','YES'),
('f0d00000-0000-0000-0000-00000000009c','ABDO_PAIN_JAUNDICE','NO'),

('f0d00000-0000-0000-0000-00000000009d','ABDO_PAIN_FEVER','YES'),
('f0d00000-0000-0000-0000-00000000009e','ABDO_PAIN_FEVER','NO'),

('f0d00000-0000-0000-0000-00000000009f','ABDO_PAIN_DYSURIA','YES'),
('f0d00000-0000-0000-0000-0000000000a0','ABDO_PAIN_DYSURIA','NO'),

('f0d00000-0000-0000-0000-0000000000a1','ABDO_PAIN_URINARY_FREQUENCY','YES'),
('f0d00000-0000-0000-0000-0000000000a2','ABDO_PAIN_URINARY_FREQUENCY','NO'),

('f0d00000-0000-0000-0000-0000000000a3','ABDO_PAIN_HAEMATURIA','YES'),
('f0d00000-0000-0000-0000-0000000000a4','ABDO_PAIN_HAEMATURIA','NO'),

('f0d00000-0000-0000-0000-0000000000a5','ABDO_PAIN_PREGNANCY_POSSIBLE','YES'),
('f0d00000-0000-0000-0000-0000000000a6','ABDO_PAIN_PREGNANCY_POSSIBLE','NO'),

('f0d00000-0000-0000-0000-0000000000a7','ABDO_PAIN_VAGINAL_BLEEDING','YES'),
('f0d00000-0000-0000-0000-0000000000a8','ABDO_PAIN_VAGINAL_BLEEDING','NO'),

('f0d00000-0000-0000-0000-0000000000a9','ABDO_PAIN_VAGINAL_DISCHARGE','YES'),
('f0d00000-0000-0000-0000-0000000000aa','ABDO_PAIN_VAGINAL_DISCHARGE','NO'),

('f0d00000-0000-0000-0000-0000000000ab','ABDO_PAIN_ABDOMINAL_RIGIDITY','YES'),
('f0d00000-0000-0000-0000-0000000000ac','ABDO_PAIN_ABDOMINAL_RIGIDITY','NO'),

('f0d00000-0000-0000-0000-0000000000ad','ABDO_PAIN_COLLAPSE','YES'),
('f0d00000-0000-0000-0000-0000000000ae','ABDO_PAIN_COLLAPSE','NO'),

('f0d00000-0000-0000-0000-0000000000af','ABDO_PAIN_ABDOMINAL_DISTENSION','YES'),
('f0d00000-0000-0000-0000-0000000000b0','ABDO_PAIN_ABDOMINAL_DISTENSION','NO'),

-- -----------------------------------------------------------------------------
-- COUGH
-- -----------------------------------------------------------------------------

('f0d00000-0000-0000-0000-0000000000b1','SPUTUM_COLOUR','CLEAR'),
('f0d00000-0000-0000-0000-0000000000b2','SPUTUM_COLOUR','YELLOW'),
('f0d00000-0000-0000-0000-0000000000b3','SPUTUM_COLOUR','GREEN'),
('f0d00000-0000-0000-0000-0000000000b4','SPUTUM_COLOUR','BLOOD_STAINED'),

('f0d00000-0000-0000-0000-0000000000b5','HAEMOPTYSIS','YES'),
('f0d00000-0000-0000-0000-0000000000b6','HAEMOPTYSIS','NO'),

('f0d00000-0000-0000-0000-0000000000b7','COUGH_NIGHT','YES'),
('f0d00000-0000-0000-0000-0000000000b8','COUGH_NIGHT','NO'),

('f0d00000-0000-0000-0000-0000000000b9','COUGH_EXERTIONAL','YES'),
('f0d00000-0000-0000-0000-0000000000ba','COUGH_EXERTIONAL','NO'),

('f0d00000-0000-0000-0000-0000000000bb','COUGH_POSTURAL','YES'),
('f0d00000-0000-0000-0000-0000000000bc','COUGH_POSTURAL','NO'),

('f0d00000-0000-0000-0000-0000000000bd','COUGH_NIGHT_SWEATS','YES'),
('f0d00000-0000-0000-0000-0000000000be','COUGH_NIGHT_SWEATS','NO'),

('f0d00000-0000-0000-0000-0000000000bf','COUGH_WEIGHT_LOSS','YES'),
('f0d00000-0000-0000-0000-0000000000c0','COUGH_WEIGHT_LOSS','NO'),

('f0d00000-0000-0000-0000-0000000000c1','TB_CONTACT','YES'),
('f0d00000-0000-0000-0000-0000000000c2','TB_CONTACT','NO'),

('f0d00000-0000-0000-0000-0000000000c3','RESPIRATORY_IRRITANT_EXPOSURE','YES'),
('f0d00000-0000-0000-0000-0000000000c4','RESPIRATORY_IRRITANT_EXPOSURE','NO'),

('f0d00000-0000-0000-0000-0000000000c5','ACE_INHIBITOR_USE','YES'),
('f0d00000-0000-0000-0000-0000000000c6','ACE_INHIBITOR_USE','NO'),

('f0d00000-0000-0000-0000-0000000000c7','ASPIRATION_EVENT','YES'),
('f0d00000-0000-0000-0000-0000000000c8','ASPIRATION_EVENT','NO'),

('f0d00000-0000-0000-0000-0000000000c9','STRIDOR_PRESENT','YES'),
('f0d00000-0000-0000-0000-0000000000ca','STRIDOR_PRESENT','NO'),

('f0d00000-0000-0000-0000-0000000000cb','WHOOP_PRESENT','YES'),
('f0d00000-0000-0000-0000-0000000000cc','WHOOP_PRESENT','NO'),

('f0d00000-0000-0000-0000-0000000000cd','BARKING_COUGH','YES'),
('f0d00000-0000-0000-0000-0000000000ce','BARKING_COUGH','NO'),

('f0d00000-0000-0000-0000-0000000000cf','REFLUX_SYMPTOMS','YES'),
('f0d00000-0000-0000-0000-0000000000d0','REFLUX_SYMPTOMS','NO')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. QUESTION TRIGGERS
-- =============================================================================
--
-- Trigger architecture:
--
-- symptom trigger = symptom initiated questioning
-- fact trigger    = newly acquired fact initiated questioning
-- context trigger = patient/context initiated questioning
--
-- =============================================================================

INSERT INTO knowledge.question_trigger
(
    question_id,
    trigger_type,    trigger_code,
    priority
)
VALUES

-- -----------------------------------------------------------------------------
-- CHEST PAIN
-- -----------------------------------------------------------------------------

('f0c10000-0000-0000-0000-000000000042','symptom','chest pain',40),
('f0c00000-0000-0000-0000-000000000016','symptom','chest pain',40),
('f0c00000-0000-0000-0000-000000000017','symptom','chest pain',40),
('f0c10000-0000-0000-0000-000000000043','symptom','chest pain',50),
('f0c00000-0000-0000-0000-000000000019','symptom','chest pain',45),
('f0c00000-0000-0000-0000-00000000001a','symptom','chest pain',40),
('f0c00000-0000-0000-0000-00000000001b','symptom','chest pain',40),
('f0c00000-0000-0000-0000-00000000001c','symptom','chest pain',35),

('f0c00000-0000-0000-0000-00000000001d','fact','CHEST_PAIN_PRESENT',90),
('f0c00000-0000-0000-0000-00000000001e','fact','CHEST_PAIN_PRESENT',90),
('f0c00000-0000-0000-0000-00000000001f','fact','CHEST_PAIN_PRESENT',70),
('f0c00000-0000-0000-0000-000000000020','fact','CHEST_PAIN_PRESENT',100),
('f0c00000-0000-0000-0000-000000000021','fact','CHEST_PAIN_PRESENT',70),
('f0c00000-0000-0000-0000-000000000022','fact','CHEST_PAIN_PRESENT',55),
('f0c00000-0000-0000-0000-000000000023','fact','CHEST_PAIN_PRESENT',55),
('f0c00000-0000-0000-0000-000000000024','fact','CHEST_PAIN_PRESENT',70),
('f0c00000-0000-0000-0000-000000000025','fact','CHEST_PAIN_PRESENT',60),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN
-- -----------------------------------------------------------------------------

('f0c00000-0000-0000-0000-00000000002f','symptom','abdominal pain',50),
('f0c00000-0000-0000-0000-000000000030','symptom','abdominal pain',70),
('f0c00000-0000-0000-0000-000000000031','symptom','abdominal pain',60),
('f0c00000-0000-0000-0000-000000000032','symptom','abdominal pain',50),
('f0c00000-0000-0000-0000-000000000033','symptom','abdominal pain',60),
('f0c00000-0000-0000-0000-000000000034','symptom','abdominal pain',50),
('f0c00000-0000-0000-0000-000000000035','symptom','abdominal pain',60),

('f0c00000-0000-0000-0000-000000000036','fact','ABDO_PAIN_PRESENT',55),
('f0c00000-0000-0000-0000-000000000037','fact','ABDO_PAIN_PRESENT',60),
('f0c00000-0000-0000-0000-000000000038','fact','ABDO_PAIN_PRESENT',55),
('f0c00000-0000-0000-0000-000000000039','fact','ABDO_PAIN_PRESENT',55),
('f0c00000-0000-0000-0000-00000000003a','fact','ABDO_PAIN_PRESENT',65),
('f0c00000-0000-0000-0000-00000000003b','fact','ABDO_PAIN_PRESENT',75),
('f0c00000-0000-0000-0000-00000000003c','fact','ABDO_PAIN_PRESENT',65),
('f0c00000-0000-0000-0000-00000000003d','fact','ABDO_PAIN_PRESENT',100),
('f0c00000-0000-0000-0000-00000000003e','fact','ABDO_PAIN_PRESENT',100),
('f0c00000-0000-0000-0000-00000000003f','fact','ABDO_PAIN_PRESENT',75),
('f0c00000-0000-0000-0000-000000000040','fact','ABDO_PAIN_PRESENT',65),

-- -----------------------------------------------------------------------------
-- COUGH
-- -----------------------------------------------------------------------------

('f0c00000-0000-0000-0000-00000000004b','symptom','cough',45),
('f0c00000-0000-0000-0000-00000000004c','fact','COUGH_PRESENT',90),
('f0c00000-0000-0000-0000-00000000004d','symptom','cough',40),
('f0c00000-0000-0000-0000-00000000004e','symptom','cough',35),
('f0c00000-0000-0000-0000-00000000004f','symptom','cough',35),
('f0c00000-0000-0000-0000-000000000050','symptom','cough',50),
('f0c00000-0000-0000-0000-000000000051','symptom','cough',50),
('f0c00000-0000-0000-0000-000000000052','symptom','cough',80),
('f0c00000-0000-0000-0000-000000000053','symptom','cough',55),
('f0c00000-0000-0000-0000-000000000054','symptom','cough',50),
('f0c00000-0000-0000-0000-000000000055','symptom','cough',100),
('f0c00000-0000-0000-0000-000000000056','symptom','cough',100),
('f0c00000-0000-0000-0000-000000000057','symptom','cough',75),
('f0c00000-0000-0000-0000-000000000058','symptom','cough',75),
('f0c00000-0000-0000-0000-000000000059','symptom','cough',45)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. QUESTION REQUIREMENTS
-- =============================================================================

INSERT INTO knowledge.question_requirement
(
    question_id,
    requirement_level,
    condition,
    priority
)
VALUES

-- -----------------------------------------------------------------------------
-- CHEST PAIN
-- -----------------------------------------------------------------------------

('f0c10000-0000-0000-0000-000000000042','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),60),

('f0c00000-0000-0000-0000-000000000016','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),55),

('f0c00000-0000-0000-0000-000000000017','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),55),

('f0c10000-0000-0000-0000-000000000043','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),70),

('f0c00000-0000-0000-0000-000000000019','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_EXERTIONAL','value','YES')),65),

('f0c00000-0000-0000-0000-00000000001d','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-00000000001e','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-00000000001f','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),90),

('f0c00000-0000-0000-0000-000000000020','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-000000000021','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),75),

('f0c00000-0000-0000-0000-000000000023','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),85),

('f0c00000-0000-0000-0000-000000000024','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),65),

('f0c00000-0000-0000-0000-000000000026','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),95),

('f0c00000-0000-0000-0000-000000000027','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),90),

('f0c00000-0000-0000-0000-000000000028','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),85),

('f0c00000-0000-0000-0000-000000000029','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','CHEST_PAIN_PRESENT','value','YES')),60),

('f0c00000-0000-0000-0000-00000000002e','conditionally_required',
 jsonb_build_object('context',jsonb_build_object('sex','female','reproductive_age',true)),90),

-- -----------------------------------------------------------------------------
-- ABDOMINAL PAIN
-- -----------------------------------------------------------------------------

('f0c00000-0000-0000-0000-00000000002f','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),70),

('f0c00000-0000-0000-0000-000000000030','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),90),

('f0c00000-0000-0000-0000-000000000031','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),70),

('f0c00000-0000-0000-0000-000000000032','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),65),

('f0c00000-0000-0000-0000-000000000033','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),75),

('f0c00000-0000-0000-0000-000000000035','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),70),

('f0c00000-0000-0000-0000-00000000003b','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),90),

('f0c00000-0000-0000-0000-00000000003d','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-00000000003e','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-00000000003f','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),80),

('f0c00000-0000-0000-0000-000000000040','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),70),

('f0c00000-0000-0000-0000-000000000041','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),65),

('f0c00000-0000-0000-0000-000000000043','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),75),

('f0c00000-0000-0000-0000-000000000044','conditionally_required',
 jsonb_build_object('context',jsonb_build_object('sex','female','reproductive_age',true)),100),

('f0c00000-0000-0000-0000-000000000045','conditionally_required',
 jsonb_build_object('context',jsonb_build_object('sex','female','reproductive_age',true)),100),

('f0c00000-0000-0000-0000-000000000046','conditionally_required',
 jsonb_build_object('context',jsonb_build_object('sex','female','reproductive_age',true)),65),

('f0c00000-0000-0000-0000-000000000047','conditionally_required',
 jsonb_build_object('context',jsonb_build_object('sex','female','reproductive_age',true)),100),

('f0c00000-0000-0000-0000-000000000048','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-000000000049','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-00000000004a','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','ABDO_PAIN_PRESENT','value','YES')),90),

-- -----------------------------------------------------------------------------
-- COUGH
-- -----------------------------------------------------------------------------

('f0c00000-0000-0000-0000-00000000004c','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-000000000050','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),55),

('f0c00000-0000-0000-0000-000000000051','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),80),

('f0c00000-0000-0000-0000-000000000052','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),90),

('f0c00000-0000-0000-0000-000000000053','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),65),

('f0c00000-0000-0000-0000-000000000055','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-000000000056','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),100),

('f0c00000-0000-0000-0000-000000000057','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),80),

('f0c00000-0000-0000-0000-000000000058','conditionally_required',
 jsonb_build_object('fact',jsonb_build_object('code','COUGH_PRESENT','value','YES')),80)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. HIGH-PRIORITY CROSS-SYSTEM SAFETY QUESTION POLICY
-- =============================================================================
--
-- These rules ensure the question engine does not behave like a simple
-- questionnaire.
--
-- The CPU should promote danger questions when relevant.
-- =============================================================================

INSERT INTO knowledge.question_requirement
(
    question_id,
    requirement_level,
    condition,
    priority
)
SELECT
    q.id,
    'conditionally_required',
    jsonb_build_object(
        'fact',
        jsonb_build_object(
            'code',
            'CHEST_PAIN_PRESENT',
            'value',
            'YES'
        )
    ),
    100
FROM knowledge.question q
WHERE q.question_code IN
(
    'CHEST_PAIN_DYSPNOEA',
    'CHEST_PAIN_SYNCOPE',
    'CHEST_PAIN_HAEMOPTYSIS'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. QUESTION-LEVEL INTELLIGENCE OVERRIDES
-- =============================================================================
--
-- Z9 adapts questioning without modifying Z4.
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
    'f1200000-0000-0000-0000-000000000014',
    'OVR-CHEST-PAIN-QUESTION-SAFETY-V1',
    'question',
    'f0c00000-0000-0000-0000-000000000020',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 120,
        'safety', true,
        'mandatory_when',
            jsonb_build_object(
                'fact',
                jsonb_build_object(
                    'code',
                    'CHEST_PAIN_PRESENT',
                    'value',
                    'YES'
                )
            ),
        'note',
            'Syncope or near-syncope associated with chest pain is a high-priority safety feature.'
    ),
    'AMEXAN universal chest-pain safety questioning.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


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
    'f1200000-0000-0000-0000-000000000015',
    'OVR-ABDO-PAIN-PREGNANCY-SAFETY-V1',
    'question',
    'f0c00000-0000-0000-0000-000000000044',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 120,
        'safety', true,
        'context_required',
            jsonb_build_array(
                'reproductive_age',
                'sex_female'
            ),
        'note',
            'Pregnancy possibility must be actively assessed in abdominal/pelvic pain where applicable.'
    ),
    'AMEXAN universal reproductive-age abdominal pain safety pathway.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. DOCUMENTATION INTELLIGENCE
-- =============================================================================

INSERT INTO knowledge.symptom_documentation
(
    symptom_id,
    documentation_phrase,
    language_code,
    is_preferred
)
VALUES
(
    'f0b00000-0000-0000-0000-000000000007',
    'chest pain with clinical characteristics documented',
    'en',
    false
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'abdominal pain with site, character, chronology and associated symptoms documented',
    'en',
    false
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. ADDITIONAL CHEST PAIN RED FLAGS
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag
(
    symptom_id,
    red_flag_code,
    description,
    urgency
)
VALUES

(
    'f0b00000-0000-0000-0000-000000000007',
    'RF-CHEST-PAIN-SYNCOPE',
    'Chest pain associated with syncope or near-syncope requires urgent assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000007',
    'RF-CHEST-PAIN-DYSPNOEA',
    'Chest pain associated with significant dyspnoea may indicate a life-threatening cardiopulmonary process.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000007',
    'RF-CHEST-PAIN-HAEMOPTYSIS',
    'Chest pain associated with haemoptysis requires assessment for serious cardiopulmonary causes.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000007',
    'RF-CHEST-PAIN-PE',
    'Pleuritic chest pain with thromboembolic risk features requires assessment for pulmonary embolism.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000007',
    'RF-CHEST-PAIN-TAMPONADE',
    'Chest pain with severe dyspnoea, hypotension, syncope or obstructive shock features requires emergency assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000007',
    'RF-CHEST-PAIN-ENDOCARDITIS',
    'Chest symptoms with persistent fever and relevant infectious risk require assessment for serious infection where clinically appropriate.',
    'urgent'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 12. ADDITIONAL ABDOMINAL PAIN RED FLAGS
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag
(
    symptom_id,
    red_flag_code,
    description,
    urgency
)
VALUES

(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-ECTOPIC',
    'Abdominal or pelvic pain in a patient who could be pregnant requires exclusion of ectopic pregnancy where clinically appropriate.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-GI-BLEED',
    'Abdominal pain associated with haematemesis, melaena, significant rectal bleeding, syncope or haemodynamic compromise requires urgent assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-OBSTRUCTION',
    'Severe abdominal pain with distension, vomiting and failure to pass stool or flatus raises concern for intestinal obstruction.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-PERITONITIS',
    'Severe abdominal pain with guarding, rigidity or severe pain on movement raises concern for peritonitis.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-SHOCK',
    'Abdominal pain associated with collapse, syncope, severe weakness or shock features requires emergency assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-ISCHEMIA',
    'Severe abdominal pain that appears disproportionate to initial examination findings may represent a serious vascular or ischemic process.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000008',
    'RF-ABDO-PAIN-ANEURYSM',
    'Sudden severe abdominal or back pain with collapse or vascular risk features requires consideration of major vascular emergency.',
    'emergency'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. COUGH RED FLAGS
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag
(
    symptom_id,
    red_flag_code,
    description,
    urgency
)
VALUES

(
    'f0b00000-0000-0000-0000-000000000001',
    'RF-COUGH-HAEMOPTYSIS',
    'Cough with significant or unexplained haemoptysis requires clinical assessment.',
    'urgent'
),
(
    'f0b00000-0000-0000-0000-000000000001',
    'RF-COUGH-STRIDOR',
    'Stridor may indicate upper-airway obstruction and requires immediate severity assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000001',
    'RF-COUGH-ASPIRATION',
    'Sudden cough during eating or drinking may indicate foreign-body aspiration.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000001',
    'RF-COUGH-HYPOXAEMIA',
    'Cough associated with clinically significant hypoxaemia requires urgent severity assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000001',
    'RF-COUGH-RESPIRATORY-DISTRESS',
    'Cough with severe respiratory distress requires emergency assessment.',
    'emergency'
),
(
    'f0b00000-0000-0000-0000-000000000001',
    'RF-COUGH-TB',
    'Persistent cough with compatible epidemiological or systemic features requires consideration of tuberculosis.',
    'urgent'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 14. FINAL QUESTION-ENGINE CONTRACT
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
    'f1200000-0000-0000-0000-000000000016',
    'OVR-QUESTION-ENGINE-UNIVERSAL-CLINICAL-INTELLIGENCE-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(

        'architecture',
        'SYMPTOM_TO_FACT_TO_REASONING',

        'question_order',
        jsonb_build_array(
            'safety',
            'core_characterization',
            'chronology',
            'severity',
            'associated_symptoms',
            'system_discriminators',
            'risk_factors',
            'exposures',
            'patient_context',
            'previous_treatment'
        ),

        'safety_policy',
        jsonb_build_object(
            'red_flags_first', true,
            'emergency_questions_priority', 100,
            'never_skip_safety_due_to_low_probability', true,
            'never_diagnose_from_single_answer', true
        ),

        'reasoning_policy',
        jsonb_build_object(
            'symptom_first', true,
            'fact_first', true,
            'diagnosis_after_fact_acquisition', true,
            'preserve_positive_and_negative_findings', true,
            'negative_findings_are_clinically_meaningful', true,
            'avoid_duplicate_questions', true,
            'adaptive_questioning', true
        ),

        'documentation_policy',
        jsonb_build_object(
            'store_raw_answer', true,
            'store_normalized_fact', true,
            'store_source_question', true,
            'store_timestamp', true,
            'store_patient_context', true,
            'preserve_uncertainty', true
        ),

        'clinical_scope',
        jsonb_build_array(
            'cardiovascular',
            'respiratory',
            'gastrointestinal',
            'genitourinary',
            'reproductive',
            'vascular',
            'infectious',
            'musculoskeletal',
            'neurological',
            'endocrine',
            'oncological',
            'toxicological',
            'paediatric',
            'geriatric'
        ),

        'core_rule',
        'AMEXAN asks the smallest clinically sufficient set of questions required to safely characterize the presenting problem and acquire discriminating facts.'
    ),
    'AMEXAN Universal Clinical Question Intelligence contract.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- END ZP2.1
-- =============================================================================