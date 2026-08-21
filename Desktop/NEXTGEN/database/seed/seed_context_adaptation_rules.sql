-- =============================================================================
-- AMEXAN UNIVERSAL CLINICAL OPERATING SYSTEM
-- MIGRATION 047
--
-- CONTEXT ADAPTATION / CLINICAL FORMAT ARBITRATION RULES
-- =============================================================================
--
-- PURPOSE
-- -------
-- This migration seeds the Universal Clinical Context Adaptation Layer.
--
-- The CPU MUST determine which clinical modules/formats are:
--
--   1. ACTIVATED
--   2. SUPPRESSED / UNAVAILABLE
--   3. DEPRIORITISED
--   4. CONDITIONALLY AVAILABLE
--
-- The patient/UI never chooses the clinical format directly.
--
-- UNIVERSAL PIPELINE
--
--   PATIENT DATA
--       ↓
--   CONTEXT RESOLUTION
--       ↓
--   CONTEXT STACK
--       ↓
--   ADAPTATION RULE ENGINE
--       ↓
--   MODULE AUTHORIZATION
--       ↓
--   QUESTION / EXAMINATION SELECTION
--       ↓
--   CPU VALIDATION
--       ↓
--   UI RENDERING
--
-- IMPORTANT DESIGN PRINCIPLES
-- ---------------------------
--
-- 1. AGE IS STRUCTURED CONTEXT, NOT A UI LABEL.
-- 2. SEX IS STRUCTURED CONTEXT.
-- 3. PREGNANCY IS A DYNAMIC CLINICAL STATE.
-- 4. DEPARTMENT IS A SERVICE CONTEXT, NOT A DIAGNOSIS.
-- 5. SYMPTOM/PRESENTATION CONTEXT MAY ACTIVATE additional modules.
-- 6. MULTIPLE contexts are evaluated simultaneously.
-- 7. More specific rules outrank generic rules.
-- 8. SUPPRESSION rules protect against clinically inappropriate modules.
-- 9. ACTIVATION rules do not automatically create diagnoses.
-- 10. The CPU must never infer a diagnosis merely because a module is activated.
-- 11. A module being unavailable does not mean the clinical concept is
--     impossible; it means that module is not appropriate in that context.
-- 12. Clinical safety overrides UI convenience.
--
-- RULE PRIORITY
-- -------------
--
-- Suggested conceptual priority:
--
--   1000+  Safety / impossible-context suppression
--    800+  Life-stage overrides
--    700+  Reproductive-state overrides
--    600+  Emergency / acute-setting overrides
--    500+  Department/service adaptation
--    400+  Presentation/symptom adaptation
--    300+  Secondary contextual enhancement
--    100+  Default formatting
--
-- This allows a highly specific rule to override a generic activation.
--
-- IDEMPOTENCY
-- -----------
-- The migration removes/rebuilds only AMEXAN FORMAT rules.
-- It does not destroy unrelated adaptation rules.
--
-- =============================================================================

BEGIN;

-- =============================================================================
-- 0. SAFETY / SCHEMA COMPATIBILITY
-- =============================================================================

-- Ensure the rule table has the fields required by this migration.
-- Existing installations may already contain these columns.

ALTER TABLE knowledge.context_adaptation_rule
    ADD COLUMN IF NOT EXISTS condition jsonb;

ALTER TABLE knowledge.context_adaptation_rule
    ADD COLUMN IF NOT EXISTS priority_delta integer NOT NULL DEFAULT 0;

ALTER TABLE knowledge.context_adaptation_rule
    ADD COLUMN IF NOT EXISTS rationale text;

-- =============================================================================
-- 1. STANDARDIZE THE CONTEXT CODES USED BY THIS RULE SET
-- =============================================================================
--
-- These are intentionally ordinary context codes.
--
-- COMBINATIONS ARE EXPRESSED IN condition JSON,
-- NOT by creating fake contexts such as:
--
--   CHILD + RESPIRATORY
--   FEMALE + RESPIRATORY + PREGNANT
--
-- This keeps the context graph composable.
-- =============================================================================

INSERT INTO knowledge.clinical_context
(
    context_id,
    code,
    category,
    label,
    description,
    applies_to_questions,
    applies_to_exam,
    priority_weight
)
VALUES
(
    'CTX-NEONATE',
    'NEONATE',
    'AGE',
    'Neonate',
    'Birth through 27 completed days.',
    TRUE,
    TRUE,
    1.50
),
(
    'CTX-INFANT',
    'INFANT',
    'AGE',
    'Infant',
    '28 completed days through less than 12 months.',
    TRUE,
    TRUE,
    1.30
),
(
    'CTX-CHILD',
    'CHILD',
    'AGE',
    'Child',
    '12 months through less than 12 years.',
    TRUE,
    TRUE,
    1.20
),
(
    'CTX-ADOLESCENT',
    'ADOLESCENT',
    'AGE',
    'Adolescent',
    '12 through 17 years.',
    TRUE,
    TRUE,
    1.10
),
(
    'CTX-ADULT',
    'ADULT',
    'AGE',
    'Adult',
    '18 years and above.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-MALE',
    'MALE',
    'SEX',
    'Male',
    'Patient recorded as male according to the sex context used by the clinical system.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-FEMALE',
    'FEMALE',
    'SEX',
    'Female',
    'Patient recorded as female according to the sex context used by the clinical system.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-PREGNANT',
    'PREGNANT',
    'REPRODUCTIVE',
    'Pregnant',
    'Current pregnancy is clinically established or recorded.',
    TRUE,
    TRUE,
    1.40
),
(
    'CTX-NOT-PREGNANT',
    'NOT_PREGNANT',
    'REPRODUCTIVE',
    'Not pregnant',
    'Current pregnancy is explicitly recorded as absent where clinically applicable.',
    TRUE,
    TRUE,
    0.90
),
(
    'CTX-REPRODUCTIVE-AGE',
    'REPRODUCTIVE_AGE',
    'REPRODUCTIVE',
    'Reproductive age',
    'Female patient in the configured reproductive-age context.',
    TRUE,
    TRUE,
    1.10
),
(
    'CTX-EMERGENCY',
    'EMERGENCY',
    'SETTING',
    'Emergency',
    'Encounter occurring in an emergency/acute-care setting.',
    TRUE,
    TRUE,
    1.30
),
(
    'CTX-OPD',
    'OPD',
    'SETTING',
    'Outpatient',
    'Encounter occurring in an outpatient setting.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-INTERNAL-MED',
    'INTERNAL_MEDICINE',
    'DEPARTMENT',
    'Internal Medicine',
    'Internal medicine service context.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-PEDIATRICS',
    'PEDIATRICS',
    'DEPARTMENT',
    'Paediatrics',
    'Paediatric service context.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-OBGYN',
    'OBGYN',
    'DEPARTMENT',
    'Obstetrics and Gynaecology',
    'Obstetric and gynaecological service context.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-PSYCHIATRY',
    'PSYCHIATRY',
    'DEPARTMENT',
    'Psychiatry',
    'Psychiatric service context.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-RESPIRATORY',
    'RESPIRATORY',
    'PRESENTATION',
    'Respiratory presentation',
    'Current presentation contains respiratory symptoms/signals.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-CARDIOVASCULAR',
    'CARDIOVASCULAR',
    'PRESENTATION',
    'Cardiovascular presentation',
    'Current presentation contains cardiovascular symptoms/signals.',
    TRUE,
    TRUE,
    1.00
),
(
    'CTX-ABDOMINAL',
    'ABDOMINAL',
    'PRESENTATION',
    'Abdominal presentation',
    'Current presentation contains abdominal symptoms/signals.',
    TRUE,
    TRUE,
    1.00
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. REMOVE ONLY THIS MIGRATION'S PREVIOUS FORMAT RULES
-- =============================================================================

DELETE FROM knowledge.context_adaptation_rule
WHERE rule_code LIKE 'CR-FORMAT-%';


-- =============================================================================
-- 3. UNIVERSAL AGE / LIFE-STAGE FORMAT ARBITRATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

-- ---------------------------------------------------------------------------
-- NEONATE
-- ---------------------------------------------------------------------------

(
    'CR-FORMAT-001',
    'NEONATE',
    'question_module',
    'neonatal',
    'ACTIVATE',
    900,
    'Neonates require neonatal-specific history, examination, physiology,
     feeding, birth, maternal and perinatal assessment rather than generic
     paediatric or adult presentation.',
    NULL
),

(
    'CR-FORMAT-002',
    'NEONATE',
    'question_module',
    'pediatric',
    'UNAVAILABLE',
    900,
    'The neonatal period has distinct clinical physiology and requires a
     neonatal-specific framework.',
    NULL
),

(
    'CR-FORMAT-003',
    'NEONATE',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    1000,
    'Adult medical history and examination format is inappropriate for a
     neonate.',
    NULL
),

(
    'CR-FORMAT-004',
    'NEONATE',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    1000,
    'Neonatal assessment must not be rendered as an adult clinical format.',
    NULL
),

-- ---------------------------------------------------------------------------
-- INFANT
-- ---------------------------------------------------------------------------

(
    'CR-FORMAT-005',
    'INFANT',
    'question_module',
    'pediatric',
    'ACTIVATE',
    800,
    'Infants require paediatric history, feeding, immunisation, growth,
     developmental and age-specific examination adaptation.',
    NULL
),

(
    'CR-FORMAT-006',
    'INFANT',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    900,
    'Adult medical format is not appropriate for infants.',
    NULL
),

-- ---------------------------------------------------------------------------
-- CHILD
-- ---------------------------------------------------------------------------

(
    'CR-FORMAT-007',
    'CHILD',
    'question_module',
    'pediatric',
    'ACTIVATE',
    800,
    'Children require paediatric clinical history and examination adaptation.',
    NULL
),

(
    'CR-FORMAT-008',
    'CHILD',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    900,
    'Adult medical format must not be used as the default format for children.',
    NULL
),

-- ---------------------------------------------------------------------------
-- ADOLESCENT
-- ---------------------------------------------------------------------------

(
    'CR-FORMAT-009',
    'ADOLESCENT',
    'question_module',
    'adolescent',
    'ACTIVATE',
    850,
    'Adolescents require an adolescent-specific approach incorporating
     paediatric-to-adult transition, psychosocial assessment, confidentiality,
     sexual/reproductive health where clinically appropriate, substance use,
     mental health and development.',
    NULL
),

(
    'CR-FORMAT-010',
    'ADOLESCENT',
    'question_module',
    'adult_medical',
    'ACTIVATE',
    300,
    'Adult-style clinical reasoning may be required for adolescents but must
     remain age adapted.',
    NULL
),

(
    'CR-FORMAT-011',
    'ADOLESCENT',
    'question_module',
    'pediatric',
    'DEPRIORITIZE',
    150,
    'Full childhood format should not automatically dominate adolescent
     assessment.',
    NULL
),

-- ---------------------------------------------------------------------------
-- ADULT
-- ---------------------------------------------------------------------------

(
    'CR-FORMAT-012',
    'ADULT',
    'question_module',
    'adult_medical',
    'ACTIVATE',
    800,
    'Adults receive the standard adult medical clinical format unless a
     higher-priority specialty or emergency context modifies it.',
    NULL
),

(
    'CR-FORMAT-013',
    'ADULT',
    'question_module',
    'pediatric',
    'UNAVAILABLE',
    900,
    'Paediatric format is inappropriate for adults.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. SEX-DEPENDENT REPRODUCTIVE FORMAT RULES
-- =============================================================================

-- ---------------------------------------------------------------------------
-- MALE
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-020',
    'MALE',
    'question_module',
    'obstetric_history',
    'UNAVAILABLE',
    950,
    'Obstetric history requires an obstetric context and is not applicable to
     patients recorded as male in this clinical model.',
    NULL
),

(
    'CR-FORMAT-021',
    'MALE',
    'question_module',
    'antenatal_care',
    'UNAVAILABLE',
    950,
    'Antenatal care modules require pregnancy/obstetric context.',
    NULL
),

(
    'CR-FORMAT-022',
    'MALE',
    'question_module',
    'gestational_age',
    'UNAVAILABLE',
    950,
    'Gestational-age assessment is applicable to pregnancy.',
    NULL
),

(
    'CR-FORMAT-023',
    'MALE',
    'question_module',
    'labour_history',
    'UNAVAILABLE',
    950,
    'Labour history requires obstetric context.',
    NULL
),

(
    'CR-FORMAT-024',
    'MALE',
    'question_module',
    'gynaecological_history',
    'UNAVAILABLE',
    950,
    'Gynaecological reproductive-history modules are not appropriate for the
     male context.',
    NULL
),

(
    'CR-FORMAT-025',
    'MALE',
    'question_module',
    'male_reproductive_history',
    'ACTIVATE',
    250,
    'Male-specific reproductive, genital and sexual health assessment should
     remain available when clinically indicated.',
    NULL
) ON CONFLICT DO NOTHING;


-- ---------------------------------------------------------------------------
-- FEMALE
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-026',
    'FEMALE',
    'question_module',
    'female_reproductive_context',
    'ACTIVATE',
    150,
    'Female patients require reproductive-context assessment when clinically
     relevant, with exact modules determined by age, pregnancy status and
     presenting complaint.',
    NULL
),

(
    'CR-FORMAT-027',
    'FEMALE',
    'question_module',
    'gynaecological_history',
    'CONDITIONAL',
    200,
    'Gynaecological history should be activated by reproductive context,
     symptoms, age and clinical indication rather than automatically for
     every female encounter.',
    '{"all":[{"context":{"code":"FEMALE"}},{"any":[{"context":{"code":"REPRODUCTIVE_AGE"}},{"presentation":"gynaecological"}]}]}'
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. PREGNANCY CONTEXT
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-030',
    'PREGNANT',
    'question_module',
    'obstetric_history',
    'ACTIVATE',
    850,
    'Pregnancy requires obstetric history appropriate to gestational age and
     current presentation.',
    NULL
),

(
    'CR-FORMAT-031',
    'PREGNANT',
    'question_module',
    'antenatal_profile',
    'ACTIVATE',
    850,
    'Pregnant patients require pregnancy/antenatal assessment where applicable.',
    NULL
),

(
    'CR-FORMAT-032',
    'PREGNANT',
    'question_module',
    'gestational_age',
    'ACTIVATE',
    850,
    'Gestational age is fundamental to interpretation of pregnancy-related
     symptoms, investigations and management.',
    NULL
),

(
    'CR-FORMAT-033',
    'PREGNANT',
    'question_module',
    'obstetric_emergency',
    'CONDITIONAL',
    900,
    'Pregnancy combined with acute symptoms may require immediate obstetric
     emergency assessment.',
    '{"any":[{"presentation":"bleeding"},{"presentation":"severe_abdominal_pain"},{"presentation":"reduced_fetal_movement"},{"presentation":"seizure"},{"presentation":"severe_headache"},{"presentation":"shortness_of_breath"},{"presentation":"collapse"}]}'
),

(
    'CR-FORMAT-034',
    'PREGNANT',
    'question_module',
    'gynaecological_history',
    'CONDITIONAL',
    250,
    'Gynaecological history may remain clinically relevant in pregnancy but
     should be focused rather than automatically reproducing a complete
     non-pregnant gynaecological module.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. NON-PREGNANT REPRODUCTIVE-AGE FEMALE
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-040',
    'REPRODUCTIVE_AGE',
    'question_module',
    'pregnancy_status',
    'ACTIVATE',
    500,
    'Pregnancy status must be established when clinically relevant before
     applying pregnancy-specific modules or interpreting relevant symptoms.',
    '{"context":{"code":"FEMALE"}}'
),

(
    'CR-FORMAT-041',
    'NOT_PREGNANT',
    'question_module',
    'obstetric_history',
    'DEPRIORITIZE',
    100,
    'A complete antenatal format is not appropriate when the patient is known
     not to be pregnant, although prior obstetric history may remain relevant.',
    NULL
),

(
    'CR-FORMAT-042',
    'NOT_PREGNANT',
    'question_module',
    'antenatal_profile',
    'UNAVAILABLE',
    500,
    'Current antenatal assessment is not applicable when the patient is known
     not to be pregnant.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. DEPARTMENT / SERVICE CONTEXT
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

-- Internal medicine
(
    'CR-FORMAT-050',
    'INTERNAL_MEDICINE',
    'question_module',
    'adult_medical',
    'ACTIVATE',
    400,
    'Internal medicine encounters favour the comprehensive medical history and
     examination framework when age permits.',
    NULL
),

(
    'CR-FORMAT-051',
    'INTERNAL_MEDICINE',
    'question_module',
    'obstetric_history',
    'DEPRIORITIZE',
    100,
    'Specialist reproductive modules should not dominate a general internal
     medicine encounter unless clinically indicated.',
    NULL
),

-- Paediatrics
(
    'CR-FORMAT-052',
    'PEDIATRICS',
    'question_module',
    'pediatric',
    'ACTIVATE',
    600,
    'Paediatric service context activates paediatric clinical adaptation.',
    NULL
),

(
    'CR-FORMAT-053',
    'PEDIATRICS',
    'question_module',
    'adult_medical',
    'DEPRIORITIZE',
    400,
    'Adult medical format should not dominate paediatric encounters.',
    NULL
),

-- OBGYN
(
    'CR-FORMAT-054',
    'OBGYN',
    'question_module',
    'obstetric_history',
    'ACTIVATE',
    600,
    'OBGYN service context activates obstetric history when pregnancy/obstetric
     context is relevant.',
    NULL
),

(
    'CR-FORMAT-055',
    'OBGYN',
    'question_module',
    'gynaecological_history',
    'ACTIVATE',
    600,
    'OBGYN service context activates gynaecological history when applicable.',
    NULL
),

(
    'CR-FORMAT-056',
    'OBGYN',
    'question_module',
    'reproductive_health',
    'ACTIVATE',
    500,
    'OBGYN encounters require reproductive-system clinical context.',
    NULL
),

-- Psychiatry
(
    'CR-FORMAT-057',
    'PSYCHIATRY',
    'question_module',
    'mental_health',
    'ACTIVATE',
    650,
    'Psychiatric service context requires mental-health assessment.',
    NULL
),

(
    'CR-FORMAT-058',
    'PSYCHIATRY',
    'question_module',
    'mental_state_examination',
    'ACTIVATE',
    700,
    'Mental State Examination is central to psychiatric clinical assessment.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. EMERGENCY CONTEXT
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-060',
    'EMERGENCY',
    'question_module',
    'acute_assessment',
    'ACTIVATE',
    950,
    'Emergency encounters require immediate structured assessment of airway,
     breathing, circulation, disability and exposure as clinically appropriate.',
    NULL
),

(
    'CR-FORMAT-061',
    'EMERGENCY',
    'question_module',
    'red_flag_screen',
    'ACTIVATE',
    950,
    'Emergency assessment must identify immediate danger and time-critical
     deterioration before routine history expansion.',
    NULL
),

(
    'CR-FORMAT-062',
    'EMERGENCY',
    'question_module',
    'comprehensive_history',
    'DEPRIORITIZE',
    150,
    'The complete routine history should not delay immediate stabilization and
     life-threatening condition assessment.',
    NULL
),

(
    'CR-FORMAT-063',
    'EMERGENCY',
    'question_module',
    'vital_signs',
    'ACTIVATE',
    1000,
    'Vital signs are fundamental to acute clinical assessment.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. RESPIRATORY PRESENTATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-070',
    'RESPIRATORY',
    'question_module',
    'respiratory_core',
    'ACTIVATE',
    500,
    'Respiratory presentations require structured respiratory symptom
     characterization and associated-system review.',
    NULL
),

(
    'CR-FORMAT-071',
    'RESPIRATORY',
    'examination_module',
    'respiratory_examination',
    'ACTIVATE',
    500,
    'Respiratory presentations require respiratory examination.',
    NULL
),

(
    'CR-FORMAT-072',
    'RESPIRATORY',
    'question_module',
    'cough_core',
    'CONDITIONAL',
    400,
    'Cough-specific questioning is activated when cough is part of the
     respiratory presentation.',
    '{"presentation":"cough"}'
),

(
    'CR-FORMAT-073',
    'RESPIRATORY',
    'question_module',
    'dyspnoea_core',
    'CONDITIONAL',
    450,
    'Dyspnoea-specific assessment is activated when shortness of breath or
     respiratory difficulty is present.',
    '{"any":[{"presentation":"dyspnoea"},{"presentation":"shortness_of_breath"},{"presentation":"difficulty_breathing"}]}'
),

(
    'CR-FORMAT-074',
    'RESPIRATORY',
    'question_module',
    'haemoptysis',
    'CONDITIONAL',
    500,
    'Haemoptysis requires targeted characterization when blood is reported in
     sputum or coughed from the respiratory tract.',
    '{"presentation":"haemoptysis"}'
),

(
    'CR-FORMAT-075',
    'RESPIRATORY',
    'question_module',
    'wheeze',
    'CONDITIONAL',
    400,
    'Wheeze-specific assessment should be activated when wheeze is reported or
     clinically identified.',
    '{"presentation":"wheeze"}'
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. CHILD + RESPIRATORY INTERACTION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-080',
    'RESPIRATORY',
    'question_module',
    'pediatric_respiratory',
    'ACTIVATE',
    650,
    'Children with respiratory presentations require age-specific respiratory
     assessment, including feeding, activity, respiratory effort and age-based
     respiratory rate interpretation.',
    '{"any":[{"context":{"code":"INFANT"}},{"context":{"code":"CHILD"}},{"context":{"code":"NEONATE"}}]}'
),

(
    'CR-FORMAT-081',
    'RESPIRATORY',
    'question_module',
    'pediatric_wheeze',
    'CONDITIONAL',
    500,
    'Wheeze in children requires paediatric-specific characterization and
     recurrent/episodic respiratory history where relevant.',
    '{"all":[{"any":[{"context":{"code":"INFANT"}},{"context":{"code":"CHILD"}}]},{"presentation":"wheeze"}]}'
),

(
    'CR-FORMAT-082',
    'RESPIRATORY',
    'question_module',
    'feeding_respiratory_assessment',
    'CONDITIONAL',
    450,
    'In infants and young children, feeding difficulty may be a marker of
     respiratory severity.',
    '{"all":[{"any":[{"context":{"code":"INFANT"}},{"context":{"code":"CHILD"}}]},{"presentation":"difficulty_breathing"}]}'
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. ADULT + RESPIRATORY INTERACTION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-090',
    'RESPIRATORY',
    'question_module',
    'adult_respiratory',
    'ACTIVATE',
    500,
    'Adult respiratory presentations require adult-specific respiratory
     characterization and relevant occupational, smoking, exposure,
     medication and comorbidity assessment.',
    '{"context":{"code":"ADULT"}}'
),

(
    'CR-FORMAT-091',
    'RESPIRATORY',
    'question_module',
    'occupational_exposure',
    'CONDITIONAL',
    350,
    'Occupational exposure assessment is relevant to selected adult respiratory
     presentations.',
    '{"context":{"code":"ADULT"}}'
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 12. CARDIOVASCULAR PRESENTATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-100',
    'CARDIOVASCULAR',
    'question_module',
    'cardiovascular_core',
    'ACTIVATE',
    500,
    'Cardiovascular presentations require structured cardiovascular symptom
     assessment.',
    NULL
),

(
    'CR-FORMAT-101',
    'CARDIOVASCULAR',
    'examination_module',
    'cardiovascular_examination',
    'ACTIVATE',
    500,
    'Cardiovascular presentations require cardiovascular examination.',
    NULL
),

(
    'CR-FORMAT-102',
    'CARDIOVASCULAR',
    'question_module',
    'chest_pain_core',
    'CONDITIONAL',
    500,
    'Chest pain requires structured characterization when present.',
    '{"presentation":"chest_pain"}'
),

(
    'CR-FORMAT-103',
    'CARDIOVASCULAR',
    'question_module',
    'palpitations_core',
    'CONDITIONAL',
    450,
    'Palpitations require rhythm-related characterization when reported.',
    '{"presentation":"palpitations"}'
),

(
    'CR-FORMAT-104',
    'CARDIOVASCULAR',
    'question_module',
    'syncope_core',
    'CONDITIONAL',
    500,
    'Syncope/collapse requires targeted cardiovascular and neurological
     assessment.',
    '{"any":[{"presentation":"syncope"},{"presentation":"collapse"}]}'
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. ABDOMINAL PRESENTATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-110',
    'ABDOMINAL',
    'question_module',
    'abdominal_core',
    'ACTIVATE',
    500,
    'Abdominal presentations require structured abdominal symptom
     characterization and gastrointestinal, urinary and reproductive
     considerations where appropriate.',
    NULL
),

(
    'CR-FORMAT-111',
    'ABDOMINAL',
    'examination_module',
    'abdominal_examination',
    'ACTIVATE',
    500,
    'Abdominal presentations require abdominal examination.',
    NULL
),

(
    'CR-FORMAT-112',
    'ABDOMINAL',
    'question_module',
    'surgical_abdominal_red_flags',
    'ACTIVATE',
    550,
    'Acute abdominal presentations require assessment for features suggesting
     urgent surgical pathology.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 14. PSYCHIATRIC / MENTAL HEALTH CROSS-CONTEXT
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-120',
    'PSYCHIATRY',
    'question_module',
    'risk_assessment',
    'ACTIVATE',
    850,
    'Psychiatric assessment requires appropriate assessment of immediate risk,
     including self-harm, harm to others, vulnerability and safeguarding.',
    NULL
),

(
    'CR-FORMAT-121',
    'PSYCHIATRY',
    'examination_module',
    'mental_state_examination',
    'ACTIVATE',
    850,
    'Mental State Examination is a core component of psychiatric assessment.',
    NULL
),

(
    'CR-FORMAT-122',
    'PSYCHIATRY',
    'question_module',
    'substance_use_assessment',
    'ACTIVATE',
    450,
    'Substance use may contribute to psychiatric presentations and should be
     assessed where clinically relevant.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 15. UNIVERSAL EXAMINATION ACTIVATION
-- =============================================================================
--
-- These rules connect context adaptation to examination modules.
-- They do not replace examination knowledge seeded elsewhere.
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-130',
    'EMERGENCY',
    'examination_module',
    'general_examination',
    'ACTIVATE',
    900,
    'Emergency patients require rapid general examination.',
    NULL
),

(
    'CR-FORMAT-131',
    'EMERGENCY',
    'examination_module',
    'vital_signs',
    'ACTIVATE',
    1000,
    'Vital signs are mandatory in acute assessment unless technically
     impossible or clinically deferred for immediate life-saving intervention.',
    NULL
),

(
    'CR-FORMAT-132',
    'RESPIRATORY',
    'examination_module',
    'respiratory_examination',
    'ACTIVATE',
    600,
    'Respiratory presentations require examination of respiratory effort,
     oxygenation and respiratory system findings.',
    NULL
),

(
    'CR-FORMAT-133',
    'CARDIOVASCULAR',
    'examination_module',
    'cardiovascular_examination',
    'ACTIVATE',
    600,
    'Cardiovascular presentations require cardiovascular examination.',
    NULL
),

(
    'CR-FORMAT-134',
    'ABDOMINAL',
    'examination_module',
    'abdominal_examination',
    'ACTIVATE',
    600,
    'Abdominal presentations require abdominal examination.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 16. AGE-SPECIFIC EXAMINATION ADAPTATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-140',
    'NEONATE',
    'examination_module',
    'neonatal_examination',
    'ACTIVATE',
    950,
    'Neonates require neonatal examination including maturity, tone, colour,
     perfusion, feeding-related findings, congenital abnormalities and
     cardiorespiratory assessment.',
    NULL
),

(
    'CR-FORMAT-141',
    'INFANT',
    'examination_module',
    'paediatric_examination',
    'ACTIVATE',
    700,
    'Infants require age-specific paediatric examination.',
    NULL
),

(
    'CR-FORMAT-142',
    'CHILD',
    'examination_module',
    'paediatric_examination',
    'ACTIVATE',
    700,
    'Children require age-specific paediatric examination.',
    NULL
),

(
    'CR-FORMAT-143',
    'ADOLESCENT',
    'examination_module',
    'adolescent_examination',
    'ACTIVATE',
    700,
    'Adolescents require age-appropriate physical and psychosocial examination.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 17. PAEDIATRIC GROWTH / DEVELOPMENT ADAPTATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-150',
    'INFANT',
    'examination_module',
    'growth_assessment',
    'ACTIVATE',
    650,
    'Growth assessment is clinically important in infancy.',
    NULL
),

(
    'CR-FORMAT-151',
    'CHILD',
    'examination_module',
    'growth_assessment',
    'ACTIVATE',
    650,
    'Growth assessment is required as part of paediatric evaluation.',
    NULL
),

(
    'CR-FORMAT-152',
    'INFANT',
    'question_module',
    'developmental_assessment',
    'ACTIVATE',
    600,
    'Infant assessment requires developmental surveillance.',
    NULL
),

(
    'CR-FORMAT-153',
    'CHILD',
    'question_module',
    'developmental_assessment',
    'ACTIVATE',
    600,
    'Child assessment requires developmental and functional assessment where
     clinically appropriate.',
    NULL
),

(
    'CR-FORMAT-154',
    'ADOLESCENT',
    'question_module',
    'psychosocial_assessment',
    'ACTIVATE',
    500,
    'Adolescence requires assessment of psychosocial development and relevant
     mental/social determinants of health.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 18. UNIVERSAL SAFETY OVERRIDES
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-160',
    'EMERGENCY',
    'question_module',
    'life_threat_screen',
    'ACTIVATE',
    1000,
    'Immediate threats to life take precedence over routine history collection.',
    NULL
),

(
    'CR-FORMAT-161',
    'EMERGENCY',
    'question_module',
    'routine_biodata_expansion',
    'DEPRIORITIZE',
    700,
    'Non-urgent history expansion must not delay stabilization.',
    NULL
),

(
    'CR-FORMAT-162',
    'EMERGENCY',
    'examination_module',
    'primary_survey',
    'ACTIVATE',
    1000,
    'Primary survey is prioritized in emergency presentations.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 19. SURGICAL LOCAL EXAMINATION ACTIVATION
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-170',
    'ABDOMINAL',
    'examination_module',
    'surgical_local_examination',
    'CONDITIONAL',
    450,
    'Local surgical examination is activated when the abdominal presentation
     contains features suggesting surgical pathology.',
    '{"any":[{"presentation":"acute_abdomen"},{"presentation":"abdominal_mass"},{"presentation":"peritonism"},{"presentation":"obstruction_features"},{"presentation":"gastrointestinal_bleeding"}]}'
),

(
    'CR-FORMAT-171',
    'CARDIOVASCULAR',
    'examination_module',
    'vascular_examination',
    'CONDITIONAL',
    350,
    'Vascular examination is activated when vascular disease is clinically
     suspected or relevant.',
    '{"presentation":"limb_ischaemia"}'
),

(
    'CR-FORMAT-172',
    'RESPIRATORY',
    'examination_module',
    'chest_local_examination',
    'ACTIVATE',
    450,
    'Respiratory presentations require local chest examination.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 20. OUTPUT / PRESENTATION ADAPTATION
-- =============================================================================
--
-- The clinical record itself should be adapted to context without changing
-- the underlying canonical facts.
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-180',
    'NEONATE',
    'output_format',
    'neonatal_clinical_record',
    'ACTIVATE',
    900,
    'Neonatal records require neonatal-specific presentation.',
    NULL
),

(
    'CR-FORMAT-181',
    'INFANT',
    'output_format',
    'paediatric_clinical_record',
    'ACTIVATE',
    700,
    'Infant clinical documentation uses paediatric presentation.',
    NULL
),

(
    'CR-FORMAT-182',
    'CHILD',
    'output_format',
    'paediatric_clinical_record',
    'ACTIVATE',
    700,
    'Child clinical documentation uses paediatric presentation.',
    NULL
),

(
    'CR-FORMAT-183',
    'ADOLESCENT',
    'output_format',
    'adolescent_clinical_record',
    'ACTIVATE',
    700,
    'Adolescent documentation should preserve adolescent-specific context.',
    NULL
),

(
    'CR-FORMAT-184',
    'ADULT',
    'output_format',
    'adult_clinical_record',
    'ACTIVATE',
    700,
    'Adult documentation uses the standard adult clinical record.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 21. CONTEXT RULES FOR CLINICAL HISTORY DEPTH
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-190',
    'NEONATE',
    'question_module',
    'birth_history',
    'ACTIVATE',
    850,
    'Birth history is fundamental to neonatal assessment.',
    NULL
),

(
    'CR-FORMAT-191',
    'NEONATE',
    'question_module',
    'maternal_history',
    'ACTIVATE',
    800,
    'Maternal and antenatal history directly informs neonatal assessment.',
    NULL
),

(
    'CR-FORMAT-192',
    'NEONATE',
    'question_module',
    'feeding_history',
    'ACTIVATE',
    800,
    'Feeding is a major component of neonatal assessment.',
    NULL
),

(
    'CR-FORMAT-193',
    'INFANT',
    'question_module',
    'feeding_history',
    'ACTIVATE',
    650,
    'Feeding history is clinically important in infants.',
    NULL
),

(
    'CR-FORMAT-194',
    'INFANT',
    'question_module',
    'immunisation_history',
    'ACTIVATE',
    600,
    'Immunisation history is important in infant assessment.',
    NULL
),

(
    'CR-FORMAT-195',
    'CHILD',
    'question_module',
    'immunisation_history',
    'ACTIVATE',
    550,
    'Immunisation history remains important in childhood.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 22. CLINICAL SAFETY: MODULE ACTIVATION MUST NOT EQUAL DIAGNOSIS
-- =============================================================================
--
-- These are CPU metadata rules documenting the semantic boundary.
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-200',
    'RESPIRATORY',
    'clinical_reasoning',
    'diagnosis',
    'NO_AUTO_DIAGNOSIS',
    1000,
    'A respiratory context activates assessment but must never by itself
     establish a respiratory diagnosis.',
    NULL
),

(
    'CR-FORMAT-201',
    'CARDIOVASCULAR',
    'clinical_reasoning',
    'diagnosis',
    'NO_AUTO_DIAGNOSIS',
    1000,
    'A cardiovascular presentation activates assessment but does not establish
     a cardiovascular diagnosis.',
    NULL
),

(
    'CR-FORMAT-202',
    'ABDOMINAL',
    'clinical_reasoning',
    'diagnosis',
    'NO_AUTO_DIAGNOSIS',
    1000,
    'An abdominal presentation activates assessment but does not establish
     surgical or medical diagnosis.',
    NULL
),

(
    'CR-FORMAT-203',
    'PREGNANT',
    'clinical_reasoning',
    'diagnosis',
    'NO_AUTO_DIAGNOSIS',
    1000,
    'Pregnancy changes clinical interpretation but does not itself establish
     a pregnancy complication.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 23. CPU GOVERNANCE RULES
-- =============================================================================
--
-- These rules describe how the CPU should resolve competing adaptations.
-- =============================================================================

INSERT INTO knowledge.context_adaptation_rule
(
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale,
    condition
)
VALUES

(
    'CR-FORMAT-210',
    'EMERGENCY',
    'cpu_policy',
    'safety_over_completeness',
    'ENFORCE',
    1000,
    'In emergency settings, immediate safety and stabilization take precedence
     over completion of routine history modules.',
    NULL
),

(
    'CR-FORMAT-211',
    'NEONATE',
    'cpu_policy',
    'life_stage_override',
    'ENFORCE',
    1000,
    'Neonatal context overrides generic paediatric/adult formatting.',
    NULL
),

(
    'CR-FORMAT-212',
    'PREGNANT',
    'cpu_policy',
    'pregnancy_override',
    'ENFORCE',
    900,
    'Pregnancy-specific clinical interpretation takes precedence where
     pregnancy materially changes assessment.',
    NULL
),

(
    'CR-FORMAT-213',
    'RESPIRATORY',
    'cpu_policy',
    'presentation_adaptation',
    'ENFORCE',
    700,
    'Presentation-specific modules are added to, rather than replacing,
     the universal clinical framework.',
    NULL
),

(
    'CR-FORMAT-214',
    'CARDIOVASCULAR',
    'cpu_policy',
    'presentation_adaptation',
    'ENFORCE',
    700,
    'Cardiovascular-specific modules supplement the universal clinical
     assessment framework.',
    NULL
),

(
    'CR-FORMAT-215',
    'ABDOMINAL',
    'cpu_policy',
    'presentation_adaptation',
    'ENFORCE',
    700,
    'Abdominal-specific modules supplement the universal clinical assessment
     framework.',
    NULL
) ON CONFLICT DO NOTHING;


-- =============================================================================
-- 24. UPDATED_AT FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


-- =============================================================================
-- 25. TRIGGER
-- =============================================================================
--
-- PostgreSQL does not universally support:
--
--   CREATE TRIGGER IF NOT EXISTS
--
-- Therefore explicitly check pg_trigger.
-- =============================================================================

DO $$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c
          ON c.oid = t.tgrelid
        JOIN pg_namespace n
          ON n.oid = c.relnamespace
        WHERE t.tgname = 'trg_knowledge_context_adaptation_rule_updated_at'
          AND n.nspname = 'knowledge'
          AND c.relname = 'context_adaptation_rule'
    )
    THEN

        CREATE TRIGGER trg_knowledge_context_adaptation_rule_updated_at
        BEFORE UPDATE
        ON knowledge.context_adaptation_rule
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();

    END IF;

END
$$;


-- =============================================================================
-- 26. INDEXES FOR CPU RESOLUTION
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_context_adaptation_rule_context
ON knowledge.context_adaptation_rule (context_code);

CREATE INDEX IF NOT EXISTS idx_context_adaptation_rule_target
ON knowledge.context_adaptation_rule (target_type, target_code);

CREATE INDEX IF NOT EXISTS idx_context_adaptation_rule_priority
ON knowledge.context_adaptation_rule (priority_delta DESC);

CREATE INDEX IF NOT EXISTS idx_context_adaptation_rule_condition
ON knowledge.context_adaptation_rule
USING GIN (condition);


-- =============================================================================
-- 27. VALIDATION
-- =============================================================================

DO $$
DECLARE
    v_count integer;
BEGIN

    SELECT COUNT(*)
      INTO v_count
      FROM knowledge.context_adaptation_rule
     WHERE rule_code LIKE 'CR-FORMAT-%';

    IF v_count < 50 THEN
        RAISE EXCEPTION
            'AMEXAN 047 validation failed: expected >= 50 format rules, found %',
            v_count;
    END IF;

END
$$;


-- =============================================================================
-- 28. FINAL VERIFICATION
-- =============================================================================

SELECT
    'AMEXAN 047 — Context Adaptation / Clinical Format Arbitration seeded'
        AS status;


SELECT
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale
FROM knowledge.context_adaptation_rule
WHERE rule_code LIKE 'CR-FORMAT-%'
ORDER BY priority_delta DESC, rule_code;


-- =============================================================================
-- 29. CONTEXT COVERAGE REPORT
-- =============================================================================

SELECT
    context_code,
    COUNT(*) AS rule_count
FROM knowledge.context_adaptation_rule
WHERE rule_code LIKE 'CR-FORMAT-%'
GROUP BY context_code
ORDER BY context_code;


-- =============================================================================
-- 30. TARGET COVERAGE REPORT
-- =============================================================================

SELECT
    target_type,
    target_code,
    COUNT(*) AS rule_count
FROM knowledge.context_adaptation_rule
WHERE rule_code LIKE 'CR-FORMAT-%'
GROUP BY target_type, target_code
ORDER BY target_type, target_code;


COMMIT;

-- =============================================================================
-- END OF AMEXAN 047
-- =============================================================================