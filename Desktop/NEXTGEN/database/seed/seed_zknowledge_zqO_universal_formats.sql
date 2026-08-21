-- =============================================================================
-- AMEXAN Universal Entry — seed: six clinical formats + sections + context rules
-- The universal shell (U2/U3/U4). Six encounter formats cover the whole of adult
-- and child clinical entry:
--   ADULT_MEDICAL, ADULT_SURGICAL, PEDIATRIC, NEONATAL, OBGYN, PSYCHIATRY
-- Format selection and section applicability are 100% DB-driven. The CPU's
-- FormatResolver evaluates the patient context vector against
-- knowledge.format_context_rule and the SectionEngine applies
-- knowledge.section_context_rule on top of the selected format's sections.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. The six universal formats
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.clinical_format (format_code, name, description, sort_order, status) VALUES
  ('ADULT_MEDICAL',  'Adult Medical',      'Adult (>=18y) medical entry: history, systems review, examination, assessment, investigations, management, monitoring, documentation.', 1, 'active'),
  ('ADULT_SURGICAL', 'Adult Surgical',     'Adult (>=18y) surgical entry: medical base plus musculoskeletal examination and surgical history.', 2, 'active'),
  ('PEDIATRIC',      'Paediatric',         'Child (1-<12y, incl. infant) entry: birth, feeding, developmental and immunization history plus paediatric examination.', 3, 'active'),
  ('NEONATAL',       'Neonatal',           'Neonate (0-27d) entry: birth, feeding and neonatal history, neonatal examination. Neonate is NOT simply "paediatric".', 4, 'active'),
  ('OBGYN',          'Obstetrics & Gynaecology', 'Female reproductive-age entry: menstrual, obstetric, gynaecological history and ANC profile. Never selected for a male.', 5, 'active'),
  ('PSYCHIATRY',     'Psychiatry',         'Psychiatric entry: psychiatric history, substance use, suicide risk and mental state examination.', 6, 'active')  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Sections per format
--   default_state: available | required(hidden-until-REQUIRE) | hidden
--   REQUIRED history/danger blocks are marked is_required so the SectionEngine
--   counts them toward navigation completion.
-- ---------------------------------------------------------------------------

-- ============================ ADULT_MEDICAL ================================
INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group, sequence_no, is_required, default_state)
VALUES
  ('ADULT_MEDICAL', 'BIODATA',      'Patient & Demographics',   'HISTORY',        1,  true,  'complete'),
  ('ADULT_MEDICAL', 'CC',           'Chief Complaint',          'HISTORY',        2,  true,  'available'),
  ('ADULT_MEDICAL', 'HPI',          'History of Present Illness','HISTORY',       3,  true,  'active'),
  ('ADULT_MEDICAL', 'ROS',          'Review of Systems',        'HISTORY',        4,  false, 'available'),
  ('ADULT_MEDICAL', 'PMHX',         'Past Medical History',     'HISTORY',        5,  false, 'available'),
  ('ADULT_MEDICAL', 'MEDICATIONS',  'Medications & Allergies',  'HISTORY',        6,  false, 'available'),
  ('ADULT_MEDICAL', 'SOCIAL',       'Social & Occupational',    'HISTORY',        7,  false, 'available'),
  ('ADULT_MEDICAL', 'FAMILY',       'Family History',           'HISTORY',        8,  false, 'available'),
  ('ADULT_MEDICAL', 'EXAM_GENERAL', 'General Examination',      'EXAMINATION',    9,  false, 'available'),
  ('ADULT_MEDICAL', 'EXAM_CVS',     'Cardiovascular Examination','EXAMINATION',   10, false, 'available'),
  ('ADULT_MEDICAL', 'EXAM_RESP',    'Respiratory Examination',  'EXAMINATION',    11, false, 'available'),
  ('ADULT_MEDICAL', 'EXAM_ABDO',    'Abdominal Examination',    'EXAMINATION',    12, false, 'available'),
  ('ADULT_MEDICAL', 'EXAM_NEURO',   'Neurological Examination', 'EXAMINATION',    13, false, 'available'),
  ('ADULT_MEDICAL', 'ASSESSMENT',   'Assessment & Differential','ASSESSMENT',     14, false, 'locked'),
  ('ADULT_MEDICAL', 'INVESTIGATIONS','Investigations',          'INVESTIGATIONS', 15, false, 'locked'),
  ('ADULT_MEDICAL', 'MANAGEMENT',   'Management & Treatment',   'MANAGEMENT',     16, false, 'locked'),
  ('ADULT_MEDICAL', 'MONITORING',   'Monitoring & Escalation',  'MONITORING',     17, false, 'locked'),
  ('ADULT_MEDICAL', 'DOCUMENTATION','Documentation',            'DOCUMENTATION',  18, false, 'locked')  ON CONFLICT DO NOTHING;

-- ============================ ADULT_SURGICAL ===============================
INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group, sequence_no, is_required, default_state)
VALUES
  ('ADULT_SURGICAL', 'BIODATA',      'Patient & Demographics',   'HISTORY',        1,  true,  'complete'),
  ('ADULT_SURGICAL', 'CC',           'Chief Complaint',          'HISTORY',        2,  true,  'available'),
  ('ADULT_SURGICAL', 'HPI',          'History of Present Illness','HISTORY',       3,  true,  'active'),
  ('ADULT_SURGICAL', 'ROS',          'Review of Systems',        'HISTORY',        4,  false, 'available'),
  ('ADULT_SURGICAL', 'PMHX',         'Past Medical History',     'HISTORY',        5,  false, 'available'),
  ('ADULT_SURGICAL', 'MEDICATIONS',  'Medications & Allergies',  'HISTORY',        6,  false, 'available'),
  ('ADULT_SURGICAL', 'SOCIAL',       'Social & Occupational',    'HISTORY',        7,  false, 'available'),
  ('ADULT_SURGICAL', 'FAMILY',       'Family History',           'HISTORY',        8,  false, 'available'),
  ('ADULT_SURGICAL', 'EXAM_GENERAL', 'General Examination',      'EXAMINATION',    9,  false, 'available'),
  ('ADULT_SURGICAL', 'EXAM_ABDO',    'Abdominal Examination',    'EXAMINATION',    10, false, 'available'),
  ('ADULT_SURGICAL', 'EXAM_MSK',     'Musculoskeletal Examination','EXAMINATION',  11, false, 'available'),
  ('ADULT_SURGICAL', 'EXAM_NEURO',   'Neurological Examination', 'EXAMINATION',    12, false, 'available'),
  ('ADULT_SURGICAL', 'ASSESSMENT',   'Assessment & Differential','ASSESSMENT',     13, false, 'locked'),
  ('ADULT_SURGICAL', 'INVESTIGATIONS','Investigations',          'INVESTIGATIONS', 14, false, 'locked'),
  ('ADULT_SURGICAL', 'MANAGEMENT',   'Management & Treatment',   'MANAGEMENT',     15, false, 'locked'),
  ('ADULT_SURGICAL', 'MONITORING',   'Monitoring & Escalation',  'MONITORING',     16, false, 'locked'),
  ('ADULT_SURGICAL', 'DOCUMENTATION','Documentation',            'DOCUMENTATION',  17, false, 'locked')  ON CONFLICT DO NOTHING;

-- ============================== PEDIATRIC ==================================
INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group, sequence_no, is_required, default_state)
VALUES
  ('PEDIATRIC', 'BIODATA',             'Patient & Demographics',    'HISTORY',        1,  true,  'complete'),
  ('PEDIATRIC', 'CC',                  'Chief Complaint',           'HISTORY',        2,  true,  'available'),
  ('PEDIATRIC', 'HPI',                 'History of Present Illness','HISTORY',        3,  true,  'active'),
  ('PEDIATRIC', 'ROS',                 'Review of Systems',         'HISTORY',        4,  false, 'available'),
  ('PEDIATRIC', 'PMHX',                'Past Medical History',      'HISTORY',        5,  false, 'available'),
  ('PEDIATRIC', 'MEDICATIONS',         'Medications & Allergies',   'HISTORY',        6,  false, 'available'),
  ('PEDIATRIC', 'SOCIAL',              'Social & Caregiver',        'HISTORY',        7,  false, 'available'),
  ('PEDIATRIC', 'FAMILY',              'Family History',            'HISTORY',        8,  false, 'available'),
  ('PEDIATRIC', 'BIRTH_HISTORY',       'Birth History',             'HISTORY',        9,  false, 'available'),
  ('PEDIATRIC', 'FEEDING_HISTORY',     'Feeding History',           'HISTORY',        10, false, 'available'),
  ('PEDIATRIC', 'DEVELOPMENTAL_HISTORY','Developmental History',    'HISTORY',        11, false, 'available'),
  ('PEDIATRIC', 'IMMUNIZATION_HISTORY','Immunization History',      'HISTORY',        12, false, 'available'),
  ('PEDIATRIC', 'EXAM_GENERAL',        'General Examination',       'EXAMINATION',    13, false, 'available'),
  ('PEDIATRIC', 'EXAM_RESP',           'Respiratory Examination',   'EXAMINATION',    14, false, 'available'),
  ('PEDIATRIC', 'EXAM_ABDO',           'Abdominal Examination',     'EXAMINATION',    15, false, 'available'),
  ('PEDIATRIC', 'EXAM_NEURO',          'Neurological Examination',  'EXAMINATION',    16, false, 'available'),
  ('PEDIATRIC', 'ASSESSMENT',          'Assessment & Differential', 'ASSESSMENT',     17, false, 'locked'),
  ('PEDIATRIC', 'INVESTIGATIONS',      'Investigations',            'INVESTIGATIONS', 18, false, 'locked'),
  ('PEDIATRIC', 'MANAGEMENT',          'Management & Treatment',    'MANAGEMENT',     19, false, 'locked'),
  ('PEDIATRIC', 'MONITORING',          'Monitoring & Escalation',   'MONITORING',     20, false, 'locked'),
  ('PEDIATRIC', 'DOCUMENTATION',       'Documentation',             'DOCUMENTATION',  21, false, 'locked')  ON CONFLICT DO NOTHING;

-- ============================== NEONATAL ===================================
INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group, sequence_no, is_required, default_state)
VALUES
  ('NEONATAL', 'BIODATA',             'Neonate & Demographics',    'HISTORY',        1,  true,  'complete'),
  ('NEONATAL', 'CC',                  'Chief Complaint',           'HISTORY',        2,  true,  'available'),
  ('NEONATAL', 'HPI',                 'History of Present Illness','HISTORY',        3,  true,  'active'),
  ('NEONATAL', 'BIRTH_HISTORY',       'Birth History (Required)',  'HISTORY',        4,  true,  'available'),
  ('NEONATAL', 'FEEDING_HISTORY',     'Feeding History (Required)','HISTORY',        5,  true,  'available'),
  ('NEONATAL', 'IMMUNIZATION_HISTORY','Birth Immunization',        'HISTORY',        6,  false, 'available'),
  ('NEONATAL', 'EXAM_GENERAL',        'General Examination',       'EXAMINATION',    7,  true,  'available'),
  ('NEONATAL', 'EXAM_RESP',           'Respiratory Examination',   'EXAMINATION',    8,  true,  'available'),
  ('NEONATAL', 'EXAM_ABDO',           'Abdominal Examination',     'EXAMINATION',    9,  false, 'available'),
  ('NEONATAL', 'EXAM_NEURO',          'Neurological Examination',  'EXAMINATION',    10, false, 'available'),
  ('NEONATAL', 'ASSESSMENT',          'Assessment & Differential', 'ASSESSMENT',     11, false, 'locked'),
  ('NEONATAL', 'INVESTIGATIONS',      'Investigations',            'INVESTIGATIONS', 12, false, 'locked'),
  ('NEONATAL', 'MANAGEMENT',          'Management & Treatment',    'MANAGEMENT',     13, false, 'locked'),
  ('NEONATAL', 'MONITORING',          'Monitoring & Escalation',   'MONITORING',     14, false, 'locked'),
  ('NEONATAL', 'DOCUMENTATION',       'Documentation',             'DOCUMENTATION',  15, false, 'locked')  ON CONFLICT DO NOTHING;

-- ================================ OBGYN ====================================
INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group, sequence_no, is_required, default_state)
VALUES
  ('OBGYN', 'BIODATA',             'Patient & Demographics',    'HISTORY',        1,  true,  'complete'),
  ('OBGYN', 'CC',                  'Chief Complaint',           'HISTORY',        2,  true,  'available'),
  ('OBGYN', 'HPI',                 'History of Present Illness','HISTORY',        3,  true,  'active'),
  ('OBGYN', 'ROS',                 'Review of Systems',         'HISTORY',        4,  false, 'available'),
  ('OBGYN', 'PMHX',                'Past Medical History',      'HISTORY',        5,  false, 'available'),
  ('OBGYN', 'MEDICATIONS',         'Medications & Allergies',   'HISTORY',        6,  false, 'available'),
  ('OBGYN', 'SOCIAL',              'Social History',            'HISTORY',        7,  false, 'available'),
  ('OBGYN', 'FAMILY',              'Family History',            'HISTORY',        8,  false, 'available'),
  ('OBGYN', 'MENSTRUAL_HISTORY',   'Menstrual History',         'HISTORY',        9,  false, 'available'),
  ('OBGYN', 'OBSTETRIC_HISTORY',   'Obstetric History',         'HISTORY',        10, false, 'available'),
  ('OBGYN', 'GYNAECOLOGICAL_HISTORY','Gynaecological History',  'HISTORY',        11, false, 'available'),
  ('OBGYN', 'ANC_PROFILE',         'Antenatal Care Profile',    'HISTORY',        12, false, 'available'),
  ('OBGYN', 'EXAM_GENERAL',        'General Examination',       'EXAMINATION',    13, false, 'available'),
  ('OBGYN', 'EXAM_ABDO',           'Abdominal Examination',     'EXAMINATION',    14, false, 'available'),
  ('OBGYN', 'EXAM_OBSTETRIC',      'Obstetric Examination',     'EXAMINATION',    15, false, 'available'),
  ('OBGYN', 'EXAM_GYNAEC',         'Gynaecological Examination','EXAMINATION',    16, false, 'available'),
  ('OBGYN', 'ASSESSMENT',          'Assessment & Differential', 'ASSESSMENT',     17, false, 'locked'),
  ('OBGYN', 'INVESTIGATIONS',      'Investigations',            'INVESTIGATIONS', 18, false, 'locked'),
  ('OBGYN', 'MANAGEMENT',          'Management & Treatment',    'MANAGEMENT',     19, false, 'locked'),
  ('OBGYN', 'MONITORING',          'Monitoring & Escalation',   'MONITORING',     20, false, 'locked'),
  ('OBGYN', 'DOCUMENTATION',       'Documentation',             'DOCUMENTATION',  21, false, 'locked')  ON CONFLICT DO NOTHING;

-- ============================= PSYCHIATRY ==================================
INSERT INTO knowledge.clinical_format_section
    (format_code, section_code, label, section_group, sequence_no, is_required, default_state)
VALUES
  ('PSYCHIATRY', 'BIODATA',             'Patient & Demographics',    'HISTORY',        1,  true,  'complete'),
  ('PSYCHIATRY', 'CC',                  'Chief Complaint',           'HISTORY',        2,  true,  'available'),
  ('PSYCHIATRY', 'HPI',                 'History of Present Illness','HISTORY',        3,  true,  'active'),
  ('PSYCHIATRY', 'ROS',                 'Review of Systems',         'HISTORY',        4,  false, 'available'),
  ('PSYCHIATRY', 'PMHX',                'Past Medical History',      'HISTORY',        5,  false, 'available'),
  ('PSYCHIATRY', 'MEDICATIONS',         'Medications & Allergies',   'HISTORY',        6,  false, 'available'),
  ('PSYCHIATRY', 'SOCIAL',              'Social History',            'HISTORY',        7,  false, 'available'),
  ('PSYCHIATRY', 'FAMILY',              'Family History',            'HISTORY',        8,  false, 'available'),
  ('PSYCHIATRY', 'PSYCHIATRIC_HISTORY', 'Psychiatric History',       'HISTORY',        9,  true,  'available'),
  ('PSYCHIATRY', 'SUBSTANCE_USE',       'Substance Use History',     'HISTORY',        10, false, 'available'),
  ('PSYCHIATRY', 'SUICIDE_RISK',        'Suicide & Self-harm Risk',  'HISTORY',        11, true,  'available'),
  ('PSYCHIATRY', 'EXAM_GENERAL',        'General Examination',       'EXAMINATION',    12, false, 'available'),
  ('PSYCHIATRY', 'EXAM_NEURO',          'Neurological Examination',  'EXAMINATION',    13, false, 'available'),
  ('PSYCHIATRY', 'EXAM_PSYCH',          'Mental State Examination',  'EXAMINATION',    14, true,  'available'),
  ('PSYCHIATRY', 'ASSESSMENT',          'Assessment & Differential', 'ASSESSMENT',     15, false, 'locked'),
  ('PSYCHIATRY', 'INVESTIGATIONS',      'Investigations',            'INVESTIGATIONS', 16, false, 'locked'),
  ('PSYCHIATRY', 'MANAGEMENT',          'Management & Treatment',    'MANAGEMENT',     17, false, 'locked'),
  ('PSYCHIATRY', 'MONITORING',          'Monitoring & Escalation',   'MONITORING',     18, false, 'locked'),
  ('PSYCHIATRY', 'DOCUMENTATION',       'Documentation',             'DOCUMENTATION',  19, false, 'locked')  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Format context rules (SELECT / BLOCK)
--   AGE_BAND is the deterministic base. Department and symptom domain refine.
--   Sex only ever BLOCKS (fail-closed: male never OBGYN). Pregnancy alone never
--   selects OBGYN — it activates sections on the base format instead.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.format_context_rule
    (rule_code, format_code, context_type, context_value, action, priority_weight, rationale, status)
VALUES
  -- ---- Age band base (the authoritative seed) -----------------------------
  ('FCR-NEONATE',    'NEONATAL',       'AGE_BAND', 'NEONATE',    'SELECT', 200, 'Age band 0-27d resolves to the NEONATAL format', 'active'),
  ('FCR-INFANT',     'PEDIATRIC',      'AGE_BAND', 'INFANT',     'SELECT', 200, 'Age band 28d-<1y resolves to the PEDIATRIC format', 'active'),
  ('FCR-CHILD',      'PEDIATRIC',      'AGE_BAND', 'CHILD',      'SELECT', 200, 'Age band 1-<12y resolves to the PEDIATRIC format', 'active'),
  ('FCR-ADOLESCENT', 'ADULT_MEDICAL',  'AGE_BAND', 'ADOLESCENT', 'SELECT', 100, 'Age band 12-<18y uses the adult medical base with adaptations', 'active'),
  ('FCR-ADULT',      'ADULT_MEDICAL',  'AGE_BAND', 'ADULT',      'SELECT', 100, 'Age band >=18y resolves to the ADULT_MEDICAL format', 'active'),

  -- ---- Sex (fail-closed BLOCK only — female alone does NOT activate OBGYN)
  ('FCR-MALE-NO-OBGYN', 'OBGYN', 'SEX', 'male', 'BLOCK', 500, 'INVARIANT-003: a male patient never receives the OBGYN format', 'active'),
  ('FCR-MALE-NO-OBST',  'OBGYN', 'SEX', 'MALE', 'BLOCK', 500, 'INVARIANT-003: a male patient never receives the OBGYN format', 'active'),

  -- ---- Department / service refine the adult base -------------------------
  ('FCR-DEPT-OBGYN',    'OBGYN',       'DEPARTMENT', 'OBSTETRICS_GYNAECOLOGY', 'SELECT', 150, 'Department OBGYN selects the OBGYN format', 'active'),
  ('FCR-DEPT-SURGERY',  'ADULT_SURGICAL', 'DEPARTMENT', 'SURGERY', 'SELECT', 150, 'Department SURGERY selects the ADULT_SURGICAL format', 'active'),
  ('FCR-DEPT-PSYCH',    'PSYCHIATRY',  'DEPARTMENT', 'PSYCHIATRY', 'SELECT', 150, 'Department PSYCHIATRY selects the PSYCHIATRY format', 'active'),
  ('FCR-DEPT-PAEDS',    'PEDIATRIC',   'DEPARTMENT', 'PEDIATRICS', 'SELECT', 150, 'Department PEDIATRICS selects the PEDIATRIC format', 'active'),

  -- ---- Symptom domain refines the adult base ------------------------------
  ('FCR-DOMAIN-PSYCH',  'PSYCHIATRY',     'SYMPTOM_DOMAIN', 'PSYCHIATRIC',    'SELECT', 130, 'A psychiatric presenting problem selects the PSYCHIATRY format', 'active'),
  ('FCR-DOMAIN-OBST',   'OBGYN',          'SYMPTOM_DOMAIN', 'OBSTETRIC',      'SELECT', 130, 'An obstetric presenting problem selects the OBGYN format (female only — male BLOCKed above)', 'active'),
  ('FCR-DOMAIN-SURG',   'ADULT_SURGICAL', 'SYMPTOM_DOMAIN', 'SURGICAL',       'SELECT', 120, 'A surgical presenting problem selects the ADULT_SURGICAL format', 'active'),
  ('FCR-DOMAIN-GYNAE',  'OBGYN',          'SYMPTOM_DOMAIN', 'GYNAECOLOGICAL', 'SELECT', 130, 'A gynaecological presenting problem selects the OBGYN format (female only)', 'active')  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Section context rules (HIDE / REQUIRE / ACTIVATE)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.section_context_rule
    (rule_code, section_code, context_type, context_value, modification, priority_weight, rationale, status)
VALUES
  -- ---- Sex (fail-closed): male never sees reproductive sections ------------
  ('SCR-MALE-MENSTRUAL', 'MENSTRUAL_HISTORY',    'SEX', 'male', 'HIDE', 200, 'INVARIANT-003: menstrual history is never shown for a male', 'active'),
  ('SCR-MALE-OBSTETRIC', 'OBSTETRIC_HISTORY',    'SEX', 'male', 'HIDE', 200, 'INVARIANT-003: obstetric history is never shown for a male', 'active'),
  ('SCR-MALE-GYNAEC',    'GYNAECOLOGICAL_HISTORY','SEX', 'male', 'HIDE', 200, 'INVARIANT-003: gynaecological history is never shown for a male', 'active'),
  ('SCR-MALE-ANC',       'ANC_PROFILE',          'SEX', 'male', 'HIDE', 200, 'INVARIANT-003: ANC profile is never shown for a male', 'active'),
  ('SCR-MALE-EXAM-OBST', 'EXAM_OBSTETRIC',       'SEX', 'male', 'HIDE', 200, 'INVARIANT-003: obstetric examination is never shown for a male', 'active'),
  ('SCR-MALE-EXAM-GYNAE','EXAM_GYNAEC',          'SEX', 'male', 'HIDE', 200, 'INVARIANT-003: gynaecological examination is never shown for a male', 'active'),

  -- ---- Age: adults never see birth/feeding/developmental/immunization ------
  ('SCR-ADULT-BIRTH',  'BIRTH_HISTORY',        'AGE_BAND', 'ADULT', 'HIDE', 150, 'Birth history is not part of adult entry', 'active'),
  ('SCR-ADULT-FEEDING','FEEDING_HISTORY',      'AGE_BAND', 'ADULT', 'HIDE', 150, 'Feeding history is not part of adult entry', 'active'),
  ('SCR-ADULT-DEV',    'DEVELOPMENTAL_HISTORY','AGE_BAND', 'ADULT', 'HIDE', 150, 'Developmental history is not part of adult entry', 'active'),
  ('SCR-ADULT-IMM',    'IMMUNIZATION_HISTORY', 'AGE_BAND', 'ADULT', 'HIDE', 150, 'Routine immunization history is not part of adult entry', 'active'),

  -- ---- Neonates REQUIRE birth + feeding history ----------------------------
  ('SCR-NEONATE-BIRTH',  'BIRTH_HISTORY',   'AGE_BAND', 'NEONATE', 'REQUIRE', 150, 'Neonatal entry requires birth history', 'active'),
  ('SCR-NEONATE-FEEDING','FEEDING_HISTORY', 'AGE_BAND', 'NEONATE', 'REQUIRE', 150, 'Neonatal entry requires feeding history', 'active'),

  -- ---- Children REQUIRE developmental + immunization history --------------
  ('SCR-CHILD-DEV', 'DEVELOPMENTAL_HISTORY', 'AGE_BAND', 'CHILD', 'REQUIRE', 120, 'Paediatric entry requires developmental history', 'active'),
  ('SCR-CHILD-IMM', 'IMMUNIZATION_HISTORY',  'AGE_BAND', 'CHILD', 'REQUIRE', 120, 'Paediatric entry requires immunization history', 'active'),
  ('SCR-INFANT-DEV','DEVELOPMENTAL_HISTORY', 'AGE_BAND', 'INFANT', 'REQUIRE', 120, 'Paediatric entry requires developmental history', 'active'),
  ('SCR-INFANT-IMM','IMMUNIZATION_HISTORY',  'AGE_BAND', 'INFANT', 'REQUIRE', 120, 'Paediatric entry requires immunization history', 'active'),

  -- ---- Pregnancy activates obstetric sections on ANY base format -----------
  ('SCR-PREG-ANC',    'ANC_PROFILE',           'PREGNANCY', 'pregnant', 'REQUIRE', 160, 'A pregnant patient always has an ANC profile', 'active'),
  ('SCR-PREG-OBST',   'OBSTETRIC_HISTORY',     'PREGNANCY', 'pregnant', 'REQUIRE', 160, 'A pregnant patient always has obstetric history', 'active'),
  ('SCR-PREG-EXAM',   'EXAM_OBSTETRIC',        'PREGNANCY', 'pregnant', 'REQUIRE', 160, 'A pregnant patient always has an obstetric examination', 'active')  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Question modules → format sections (required-count mapping for nav)
-- ---------------------------------------------------------------------------
UPDATE knowledge.question_module SET section_code = 'HPI'    WHERE module_code IN ('COUGH_CORE', 'DYSPNOEA', 'CHEST_PAIN', 'CHRONIC_COUGH', 'SPUTUM', 'FEVER', 'HAEMOPTYSIS', 'PAEDIATRIC_DANGER_SIGNS', 'PAEDIATRIC_RESPIRATORY');
UPDATE knowledge.question_module SET section_code = 'SOCIAL' WHERE module_code = 'ADULT_RESPIRATORY';
UPDATE knowledge.question_module SET section_code = 'OBSTETRIC_HISTORY' WHERE module_code = 'PREGNANCY_CONTEXT';

SELECT 'Universal formats seeded';
