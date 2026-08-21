-- =============================================================================
-- AMEXAN UNIVERSAL CLINICAL OPERATING SYSTEM
-- Migration 039 — Universal Clinical Formats, Sections, Context Resolution
-- =============================================================================
--
-- PURPOSE
-- -------
-- This migration establishes the universal clinical workspace used by AMEXAN
-- across medicine, surgery, paediatrics, obstetrics & gynaecology, emergency
-- medicine, outpatient care, inpatient care, theatre, procedures, critical
-- care, mental health, rehabilitation and chronic disease care.
--
-- CORE CLINICAL LAW
-- -----------------
-- 1. The patient context is resolved first.
-- 2. The clinical format is selected from the context vector.
-- 3. The format determines the major clinical pathway.
-- 4. Sections are resolved from the selected format.
-- 5. Context-specific rules modify the section set.
-- 6. Questions belong to sections.
-- 7. Facts belong to clinical concepts, not merely UI fields.
-- 8. Examination follows history.
-- 9. Assessment follows examination/investigation evidence.
-- 10. Investigation follows a clinical question/problem.
-- 11. Management follows the established clinical assessment.
-- 12. Medication prescribing is governed by structured pharmacology knowledge.
-- 13. Severity scores are executable knowledge objects.
-- 14. Documentation is generated from the structured clinical state.
-- 15. The UI never decides clinical applicability.
-- 16. The CPU resolves applicability and produces a rendering projection.
--
-- CLINICAL FLOW
-- -------------
--
-- CONTEXT
--   ↓
-- FORMAT
--   ↓
-- CLINICAL IDENTIFICATION
--   ↓
-- CHIEF COMPLAINT
--   ↓
-- HISTORY OF PRESENTING ILLNESS
--   ↓
-- ASSOCIATED SYMPTOMS / ROS
--   ↓
-- RELEVANT BACKGROUND
--   ↓
-- MEDICATIONS / ALLERGIES
--   ↓
-- PATIENT-SPECIFIC HISTORIES
--   ↓
-- EXAMINATION
--   ↓
-- INITIAL CLINICAL ASSESSMENT
--   ↓
-- DIFFERENTIAL / CLINICAL HYPOTHESES
--   ↓
-- INVESTIGATIONS
--   ↓
-- RESULTS / INTERPRETATION
--   ↓
-- DIAGNOSIS
--   ↓
-- SEVERITY / RISK
--   ↓
-- MANAGEMENT
--   ↓
-- PRESCRIPTION / PROCEDURES / PROTOCOLS
--   ↓
-- MONITORING
--   ↓
-- RESPONSE
--   ↓
-- DISPOSITION
--   ↓
-- FOLLOW-UP / SAFETY NET
--   ↓
-- CLINICAL DOCUMENTATION
--
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS knowledge;


-- =============================================================================
-- 1. UNIVERSAL CLINICAL FORMAT
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_format (
    format_code text PRIMARY KEY,
    name text NOT NULL,
    description text,
    clinical_purpose text,
    sort_order integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.clinical_format IS
'Universal AMEXAN clinical encounter formats. A format defines the broad clinical workflow selected from the patient context vector.';


-- =============================================================================
-- 2. UNIVERSAL CLINICAL SECTIONS
-- =============================================================================
--
-- A section is a clinical concept in the workspace, not merely a visual panel.
--
-- The same section may occur in many formats.
--
-- Example:
--   DOC-HPI can be used in:
--     outpatient medicine
--     emergency medicine
--     paediatrics
--     surgery
--     OBGYN
--     admission
--     consultation
--
-- The format determines whether it is present.
-- Context rules determine whether it becomes required, active or hidden.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_section (
    section_code text PRIMARY KEY,
    name text NOT NULL,
    description text,
    clinical_purpose text NOT NULL,
    section_group text NOT NULL
        CHECK (section_group IN (
            'IDENTIFICATION',
            'HISTORY',
            'EXAMINATION',
            'ASSESSMENT',
            'INVESTIGATIONS',
            'MANAGEMENT',
            'MONITORING',
            'DISPOSITION',
            'DOCUMENTATION'
        )),
    clinical_sequence integer NOT NULL,
    repeatable boolean NOT NULL DEFAULT false,
    default_required boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_section_group
    ON knowledge.clinical_section(section_group);

CREATE INDEX IF NOT EXISTS idx_clinical_section_sequence
    ON knowledge.clinical_section(clinical_sequence);


-- =============================================================================
-- 3. FORMAT → SECTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_format_section (
    format_code text NOT NULL
        REFERENCES knowledge.clinical_format(format_code)
        ON DELETE CASCADE,

    section_code text NOT NULL
        REFERENCES knowledge.clinical_section(section_code)
        ON DELETE CASCADE,

    label text NOT NULL,

    section_group text NOT NULL
        CHECK (section_group IN (
            'IDENTIFICATION',
            'HISTORY',
            'EXAMINATION',
            'ASSESSMENT',
            'INVESTIGATIONS',
            'MANAGEMENT',
            'MONITORING',
            'DISPOSITION',
            'DOCUMENTATION'
        )),

    sequence_no integer NOT NULL DEFAULT 0,

    is_required boolean NOT NULL DEFAULT false,

    default_state text NOT NULL DEFAULT 'available'
        CHECK (default_state IN (
            'hidden',
            'locked',
            'available',
            'active',
            'complete'
        )),

    completion_rule text,

    created_at timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (format_code, section_code)
);

CREATE INDEX IF NOT EXISTS idx_format_section_sequence
    ON knowledge.clinical_format_section(format_code, sequence_no);

CREATE INDEX IF NOT EXISTS idx_format_section_group
    ON knowledge.clinical_format_section(format_code, section_group);


-- =============================================================================
-- 4. CONTEXT → FORMAT RULE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.format_context_rule (
    rule_code text PRIMARY KEY,

    format_code text NOT NULL
        REFERENCES knowledge.clinical_format(format_code)
        ON DELETE CASCADE,

    context_type text NOT NULL
        CHECK (context_type IN (
            'AGE_BAND',
            'SEX',
            'PREGNANCY',
            'DEPARTMENT',
            'SERVICE',
            'ENCOUNTER_TYPE',
            'SYMPTOM_DOMAIN',
            'CARE_SETTING',
            'URGENCY'
        )),

    context_value text NOT NULL,

    action text NOT NULL
        CHECK (action IN ('SELECT','BLOCK')),

    priority_weight integer NOT NULL DEFAULT 0,

    rationale text,

    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        context_type,
        context_value,
        format_code,
        action
    )
);

CREATE INDEX IF NOT EXISTS idx_format_context_lookup
    ON knowledge.format_context_rule(
        context_type,
        context_value,
        status
    );

CREATE INDEX IF NOT EXISTS idx_format_context_format
    ON knowledge.format_context_rule(format_code);


-- =============================================================================
-- 5. CONTEXT → SECTION RULE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.section_context_rule (
    rule_code text PRIMARY KEY,

    section_code text NOT NULL
        REFERENCES knowledge.clinical_section(section_code)
        ON DELETE CASCADE,

    context_type text NOT NULL
        CHECK (context_type IN (
            'AGE_BAND',
            'SEX',
            'PREGNANCY',
            'DEPARTMENT',
            'SERVICE',
            'ENCOUNTER_TYPE',
            'SYMPTOM_DOMAIN',
            'CARE_SETTING',
            'URGENCY'
        )),

    context_value text NOT NULL,

    modification text NOT NULL
        CHECK (modification IN (
            'HIDE',
            'REQUIRE',
            'ACTIVATE'
        )),

    priority_weight integer NOT NULL DEFAULT 0,

    rationale text,

    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        section_code,
        context_type,
        context_value,
        modification
    )
);

CREATE INDEX IF NOT EXISTS idx_section_context_lookup
    ON knowledge.section_context_rule(
        section_code,
        context_type,
        context_value,
        status
    );


-- =============================================================================
-- 6. FORMAT RESOLUTION RECORD
-- =============================================================================
--
-- Runtime table.
--
-- The CPU records why a particular format was selected.
-- This is essential for reproducibility and auditability.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_format_resolution (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id uuid,

    format_code text NOT NULL
        REFERENCES knowledge.clinical_format(format_code),

    resolution_status text NOT NULL
        CHECK (resolution_status IN (
            'SELECTED',
            'BLOCKED',
            'REJECTED',
            'OVERRIDDEN'
        )),

    context_vector jsonb NOT NULL DEFAULT '{}'::jsonb,

    matched_rules jsonb NOT NULL DEFAULT '[]'::jsonb,

    score integer NOT NULL DEFAULT 0,

    resolution_reason text,

    resolved_at timestamptz NOT NULL DEFAULT now(),

    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_format_resolution_encounter
    ON knowledge.clinical_format_resolution(encounter_id);

CREATE INDEX IF NOT EXISTS idx_format_resolution_format
    ON knowledge.clinical_format_resolution(format_code);


-- =============================================================================
-- 7. RUNTIME SECTION RESOLUTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_section_resolution (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id uuid,

    format_code text NOT NULL
        REFERENCES knowledge.clinical_format(format_code),

    section_code text NOT NULL
        REFERENCES knowledge.clinical_section(section_code),

    state text NOT NULL
        CHECK (state IN (
            'HIDDEN',
            'LOCKED',
            'AVAILABLE',
            'ACTIVE',
            'REQUIRED',
            'COMPLETE'
        )),

    sequence_no integer NOT NULL,

    matched_rules jsonb NOT NULL DEFAULT '[]'::jsonb,

    resolved_at timestamptz NOT NULL DEFAULT now(),

    created_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (encounter_id, section_code)
);

CREATE INDEX IF NOT EXISTS idx_section_resolution_encounter
    ON knowledge.clinical_section_resolution(encounter_id);

CREATE INDEX IF NOT EXISTS idx_section_resolution_order
    ON knowledge.clinical_section_resolution(
        encounter_id,
        sequence_no
    );


-- =============================================================================
-- 8. QUESTION MODULE → SECTION
-- =============================================================================

ALTER TABLE knowledge.question_module
    ADD COLUMN IF NOT EXISTS section_code text;

CREATE INDEX IF NOT EXISTS idx_question_module_section
    ON knowledge.question_module(section_code);


-- =============================================================================
-- 9. UNIVERSAL CLINICAL FORMATS
-- =============================================================================

INSERT INTO knowledge.clinical_format
(
    format_code,
    name,
    description,
    clinical_purpose,
    sort_order
)
VALUES

(
    'FMT-GENERAL-MEDICAL',
    'General Medical',
    'Universal medical assessment for undifferentiated and established medical presentations.',
    'History, examination, clinical assessment, investigation, diagnosis, treatment and follow-up.',
    10
),

(
    'FMT-EMERGENCY',
    'Emergency Assessment',
    'Time-critical assessment designed around immediate physiological threats before complete diagnostic elaboration.',
    'Rapid stabilization, focused history, primary survey, secondary survey, investigations, emergency treatment and disposition.',
    20
),

(
    'FMT-PAEDIATRIC',
    'Paediatric Assessment',
    'Clinical assessment adapted to the developing child, with age-specific history, examination, growth, development, immunization and safeguarding.',
    'Age-appropriate assessment and management of infants, children and adolescents.',
    30
),

(
    'FMT-NEONATAL',
    'Neonatal Assessment',
    'Assessment of the newborn and neonate with emphasis on birth history, gestational age, feeding, thermoregulation, respiratory adaptation and neonatal danger signs.',
    'Newborn and neonatal assessment from birth through the neonatal period.',
    40
),

(
    'FMT-OBSTETRIC',
    'Obstetric Assessment',
    'Pregnancy-focused clinical assessment integrating maternal and fetal status.',
    'Antenatal, intrapartum, postpartum and obstetric emergency care.',
    50
),

(
    'FMT-GYNAECOLOGICAL',
    'Gynaecological Assessment',
    'Clinical assessment for reproductive and gynaecological presentations outside pregnancy.',
    'Gynaecological history, examination, investigation, diagnosis and treatment.',
    60
),

(
    'FMT-SURGICAL',
    'Surgical Assessment',
    'Assessment of patients with surgical conditions, including operative decision-making and perioperative care.',
    'Surgical history, focused examination, diagnosis, operative planning and postoperative care.',
    70
),

(
    'FMT-TRAUMA',
    'Trauma Assessment',
    'Structured trauma assessment prioritizing life-threatening injury before definitive diagnosis.',
    'Primary survey, resuscitation, secondary survey, imaging, injury classification, operative/non-operative decisions and disposition.',
    80
),

(
    'FMT-INPATIENT-ADMISSION',
    'Inpatient Admission',
    'Comprehensive admission assessment for patients requiring inpatient care.',
    'Establish the presenting problem, baseline status, diagnoses, active problems and inpatient management plan.',
    90
),

(
    'FMT-INPATIENT-PROGRESS',
    'Inpatient Progress',
    'Focused reassessment of an admitted patient over time.',
    'Interval events, current symptoms, examination, results, active problems, response to treatment and revised plan.',
    100
),

(
    'FMT-WARD-ROUND',
    'Ward Round',
    'Structured multidisciplinary review of an inpatient.',
    'Current status, active problems, investigations, treatment, barriers to discharge and daily plan.',
    110
),

(
    'FMT-CONSULTATION',
    'Specialist Consultation',
    'Focused consultation assessment requested by another clinical service.',
    'Reason for referral, relevant history, examination, specialist assessment, recommendations and follow-up.',
    120
),

(
    'FMT-DISCHARGE',
    'Discharge Assessment',
    'Final clinical assessment before discharge from an episode of care.',
    'Diagnosis, hospital course, procedures, medications, condition at discharge, follow-up and safety-netting.',
    130
),

(
    'FMT-REFERRAL',
    'Referral Assessment',
    'Clinical documentation supporting transfer or referral to another clinician or facility.',
    'Clinical summary, urgency, diagnosis, treatment already given, reason for referral and information required by the receiving team.',
    140
),

(
    'FMT-OPERATIVE',
    'Operative Encounter',
    'Structured perioperative clinical format.',
    'Indication, preoperative assessment, procedure, findings, specimens, complications, postoperative plan and recovery.',
    150
),

(
    'FMT-PROCEDURE',
    'Clinical Procedure',
    'Structured documentation for a bedside or procedural intervention.',
    'Indication, consent, preparation, procedure, findings, complications and aftercare.',
    160
),

(
    'FMT-CHRONIC-CARE',
    'Chronic Disease Review',
    'Longitudinal review of an established chronic condition.',
    'Disease control, treatment adherence, complications, risk factors, monitoring and long-term management.',
    170
),

(
    'FMT-PREVENTIVE',
    'Preventive Health Assessment',
    'Assessment focused on prevention, screening, vaccination and health promotion.',
    'Risk assessment, screening, preventive interventions and individualized health advice.',
    180
),

(
    'FMT-MENTAL-HEALTH',
    'Mental Health Assessment',
    'Structured psychiatric and psychosocial assessment.',
    'Presenting symptoms, mental state, risk, psychosocial context, diagnosis and management.',
    190
),

(
    'FMT-CRITICAL-CARE',
    'Critical Care Assessment',
    'High-acuity assessment for patients requiring intensive monitoring or organ support.',
    'Physiological stabilization, organ-system assessment, invasive monitoring, treatment and escalation/de-escalation decisions.',
    200
),

(
    'FMT-MATERNITY-LABOUR',
    'Labour and Delivery',
    'Intrapartum assessment of the mother and fetus.',
    'Labour progress, maternal observations, fetal surveillance, complications, delivery planning and postpartum transition.',
    210
),

(
    'FMT-POSTNATAL',
    'Postnatal Assessment',
    'Maternal and newborn assessment following delivery.',
    'Maternal recovery, uterine involution, bleeding, breastfeeding, newborn status and discharge planning.',
    220
),

(
    'FMT-TELEMEDICINE',
    'Telemedicine Assessment',
    'Remote clinical assessment with explicit documentation of limitations imposed by remote examination.',
    'Remote history, available observations, visual assessment where appropriate, investigations, clinical assessment, advice and escalation.',
    230
)

ON CONFLICT (format_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    clinical_purpose = EXCLUDED.clinical_purpose,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();


-- =============================================================================
-- 10. UNIVERSAL CLINICAL SECTION CATALOGUE
-- =============================================================================

INSERT INTO knowledge.clinical_section
(
    section_code,
    name,
    description,
    clinical_purpose,
    section_group,
    clinical_sequence,
    repeatable,
    default_required
)
VALUES

-- ---------------------------------------------------------------------------
-- IDENTIFICATION
-- ---------------------------------------------------------------------------

(
    'CTX-PATIENT',
    'Patient Context',
    'Resolved demographic and clinical context.',
    'Establish age, sex, pregnancy state, encounter type, care setting and other variables controlling clinical applicability.',
    'IDENTIFICATION',
    10,
    false,
    true
),

(
    'CTX-ENCOUNTER',
    'Encounter Context',
    'Reason and circumstances for the current clinical encounter.',
    'Establish the clinical setting, service, urgency and purpose of the encounter.',
    'IDENTIFICATION',
    20,
    false,
    true
),

(
    'CC',
    'Chief Complaint',
    'The patient’s principal presenting concern or reason for attendance.',
    'Identify the problem that initiated the current encounter using the patient’s own presenting concern where appropriate.',
    'HISTORY',
    100,
    false,
    true
),

-- ---------------------------------------------------------------------------
-- HISTORY
-- ---------------------------------------------------------------------------

(
    'HPI',
    'History of Present Illness',
    'Chronological exploration of the presenting problem.',
    'Characterize the presenting complaint, associated symptoms, relevant negatives, progression, impact, risk factors, prior events and actions already taken.',
    'HISTORY',
    110,
    false,
    true
),

(
    'ROS',
    'Review of Systems',
    'Systematic exploration of relevant symptoms not fully covered by the presenting complaint.',
    'Identify associated or alternative-system symptoms relevant to the differential diagnosis.',
    'HISTORY',
    120,
    false,
    false
),

(
    'PAST-MEDICAL',
    'Past Medical History',
    'Previous illnesses, diagnoses, admissions and significant medical events.',
    'Identify background disease that changes the differential diagnosis, risk, treatment or prognosis.',
    'HISTORY',
    130,
    false,
    false
),

(
    'PAST-SURGICAL',
    'Past Surgical History',
    'Previous operations and procedures.',
    'Identify previous procedures, complications, anatomical changes and perioperative risks.',
    'HISTORY',
    140,
    false,
    false
),

(
    'MEDICATIONS',
    'Current Medications',
    'Medicines currently taken by the patient.',
    'Establish prescribed, over-the-counter, traditional and other medicines relevant to diagnosis, interactions, adherence and prescribing safety.',
    'HISTORY',
    150,
    false,
    true
),

(
    'ALLERGIES',
    'Allergies and Adverse Drug Reactions',
    'Drug, food and other clinically relevant allergies and reactions.',
    'Prevent avoidable exposure to allergens and identify clinically important previous drug reactions.',
    'HISTORY',
    160,
    true,
    true
),

(
    'IMMUNIZATION',
    'Immunization History',
    'Vaccination history appropriate to age and clinical context.',
    'Establish protection against vaccine-preventable disease and identify missed or indicated vaccinations.',
    'HISTORY',
    170,
    false,
    false
),

(
    'FAMILY-HISTORY',
    'Family History',
    'Relevant illnesses and inherited conditions in family members.',
    'Identify hereditary disease, familial risk and relevant epidemiological exposure.',
    'HISTORY',
    180,
    false,
    false
),

(
    'SOCIAL-HISTORY',
    'Social History',
    'Living circumstances, occupation, substance exposure, support and relevant social determinants.',
    'Identify exposures, barriers, functional impact and social factors affecting clinical care.',
    'HISTORY',
    190,
    false,
    false
),

(
    'OCCUPATIONAL',
    'Occupational and Environmental History',
    'Occupational and environmental exposures.',
    'Identify workplace, household, travel, animal, biomass, toxic and other environmental risks.',
    'HISTORY',
    200,
    false,
    false
),

(
    'NUTRITION',
    'Nutrition and Dietary History',
    'Dietary intake and nutritional risk.',
    'Identify nutritional adequacy, feeding problems, dietary exposures and nutritional risk.',
    'HISTORY',
    210,
    false,
    false
),

(
    'DEVELOPMENT',
    'Growth and Development',
    'Growth, developmental milestones and developmental concerns.',
    'Assess physical growth and neurodevelopment relative to age.',
    'HISTORY',
    220,
    false,
    false
),

(
    'PAEDIATRIC-HISTORY',
    'Paediatric History',
    'Age-specific history for infants, children and adolescents.',
    'Capture birth, feeding, development, immunization, growth, school and safeguarding information as clinically applicable.',
    'HISTORY',
    230,
    false,
    false
),

(
    'BIRTH-HISTORY',
    'Birth and Neonatal History',
    'Pregnancy, delivery and immediate neonatal history.',
    'Establish gestational age, mode of delivery, birth complications, resuscitation and neonatal adaptation.',
    'HISTORY',
    240,
    false,
    false
),

(
    'OBSTETRIC-HISTORY',
    'Obstetric History',
    'Previous pregnancies and pregnancy outcomes.',
    'Establish gravidity, parity, previous pregnancy outcomes and obstetric complications.',
    'HISTORY',
    250,
    false,
    false
),

(
    'CURRENT-PREGNANCY',
    'Current Pregnancy',
    'History and status of the current pregnancy.',
    'Establish gestational age, antenatal care, pregnancy complications, fetal concerns and relevant exposures.',
    'HISTORY',
    260,
    false,
    false
),

(
    'GYN-HISTORY',
    'Gynaecological History',
    'Menstrual, reproductive and gynaecological history.',
    'Assess menstrual, reproductive, sexual and gynaecological symptoms where clinically appropriate.',
    'HISTORY',
    270,
    false,
    false
),

(
    'SEXUAL-HISTORY',
    'Sexual and Reproductive History',
    'Sexual and reproductive health history.',
    'Assess clinically relevant sexual exposure, contraception, fertility, STI risk and reproductive goals with appropriate privacy.',
    'HISTORY',
    280,
    false,
    false
),

(
    'PSYCHOSOCIAL',
    'Psychosocial History',
    'Psychological, social and functional context.',
    'Identify psychosocial factors affecting symptoms, safety, adherence, recovery and support.',
    'HISTORY',
    290,
    false,
    false
),

(
    'MENTAL-HEALTH-HISTORY',
    'Mental Health History',
    'Psychiatric symptoms, previous mental health conditions and treatment.',
    'Establish current and previous psychiatric illness, treatment, substance exposure and relevant risk.',
    'HISTORY',
    300,
    false,
    false
),

(
    'TRAUMA-MECHANISM',
    'Mechanism of Injury',
    'Detailed description of the traumatic event.',
    'Establish mechanism, energy transfer, timing, position, protective factors and potential injury pattern.',
    'HISTORY',
    310,
    false,
    false
),

-- ---------------------------------------------------------------------------
-- EXAMINATION
-- ---------------------------------------------------------------------------

(
    'GENERAL-EXAM',
    'General Examination',
    'Overall clinical assessment of the patient.',
    'Assess general appearance, distress, consciousness, hydration, perfusion, nutrition and other immediately observable abnormalities.',
    'EXAMINATION',
    400,
    false,
    true
),

(
    'VITALS',
    'Vital Signs',
    'Core physiological observations.',
    'Measure and trend temperature, pulse, respiratory rate, blood pressure, oxygen saturation and other context-specific observations.',
    'EXAMINATION',
    410,
    true,
    true
),

(
    'GROWTH-MEASUREMENTS',
    'Growth and Anthropometry',
    'Weight, height/length, BMI, MUAC and age-appropriate growth assessment.',
    'Assess nutritional status and growth trajectory.',
    'EXAMINATION',
    420,
    false,
    false
),

(
    'SYSTEM-RESPIRATORY',
    'Respiratory Examination',
    'Focused respiratory system examination.',
    'Assess airway, breathing, work of breathing, oxygenation and respiratory physical findings.',
    'EXAMINATION',
    430,
    false,
    false
),

(
    'SYSTEM-CARDIOVASCULAR',
    'Cardiovascular Examination',
    'Focused cardiovascular examination.',
    'Assess circulation, cardiac findings, perfusion, volume status and peripheral vascular findings.',
    'EXAMINATION',
    440,
    false,
    false
),

(
    'SYSTEM-ABDOMINAL',
    'Abdominal Examination',
    'Focused abdominal examination.',
    'Assess abdominal tenderness, distension, masses, organomegaly, peritonism and other abdominal findings.',
    'EXAMINATION',
    450,
    false,
    false
),

(
    'SYSTEM-NEUROLOGICAL',
    'Neurological Examination',
    'Focused neurological examination.',
    'Assess mental state, cranial nerves, motor, sensory, coordination, reflexes and gait where appropriate.',
    'EXAMINATION',
    460,
    false,
    false
),

(
    'SYSTEM-MSK',
    'Musculoskeletal Examination',
    'Musculoskeletal assessment.',
    'Assess bones, joints, muscles, range of motion, deformity, neurovascular status and function.',
    'EXAMINATION',
    470,
    false,
    false
),

(
    'SYSTEM-SKIN',
    'Skin Examination',
    'Assessment of skin and mucosal findings.',
    'Characterize lesions, colour changes, hydration, perfusion, wounds and other dermatological findings.',
    'EXAMINATION',
    480,
    false,
    false
),

(
    'SYSTEM-ENT',
    'ENT Examination',
    'Ear, nose, throat and related examination.',
    'Assess relevant upper airway, ear, nasal, oral and pharyngeal findings.',
    'EXAMINATION',
    490,
    false,
    false
),

(
    'SYSTEM-EYE',
    'Ophthalmic Examination',
    'Focused eye examination.',
    'Assess visual function, pupils, ocular structures and relevant pathology.',
    'EXAMINATION',
    500,
    false,
    false
),

(
    'BREAST-EXAM',
    'Breast Examination',
    'Clinical breast assessment.',
    'Assess breast tissue, nipple, skin, axillae and relevant regional findings.',
    'EXAMINATION',
    510,
    false,
    false
),

(
    'PELVIC-EXAM',
    'Pelvic Examination',
    'Gynaecological pelvic examination.',
    'Assess external genitalia, vagina, cervix, uterus and adnexa when indicated and consented.',
    'EXAMINATION',
    520,
    false,
    false
),

(
    'OBSTETRIC-EXAM',
    'Obstetric Examination',
    'Maternal and fetal examination during pregnancy.',
    'Assess maternal condition, uterine findings, fetal lie/presentation/position and fetal wellbeing as appropriate.',
    'EXAMINATION',
    530,
    false,
    false
),

(
    'FOETAL-ASSESSMENT',
    'Fetal Assessment',
    'Clinical assessment of fetal wellbeing.',
    'Assess fetal heart rate, movements, presentation and other relevant fetal parameters.',
    'EXAMINATION',
    540,
    false,
    false
),

(
    'LABOUR-ASSESSMENT',
    'Labour Assessment',
    'Intrapartum assessment.',
    'Assess cervical change, descent, contractions, membranes, fetal status and maternal condition.',
    'EXAMINATION',
    550,
    false,
    false
),

(
    'TRAUMA-PRIMARY',
    'Trauma Primary Survey',
    'Immediate structured assessment of life-threatening injury.',
    'Identify and treat threats to airway, breathing, circulation, neurological status and environmental exposure.',
    'EXAMINATION',
    560,
    false,
    false
),

(
    'TRAUMA-SECONDARY',
    'Trauma Secondary Survey',
    'Systematic head-to-toe trauma examination.',
    'Identify injuries not detected during the primary survey and establish a complete injury profile.',
    'EXAMINATION',
    570,
    false,
    false
),

(
    'MENTAL-STATE',
    'Mental State Examination',
    'Structured psychiatric examination.',
    'Assess appearance, behaviour, speech, mood, affect, thought, perception, cognition, insight and judgement.',
    'EXAMINATION',
    580,
    false,
    false
),

(
    'FUNCTIONAL-ASSESSMENT',
    'Functional Assessment',
    'Assessment of functional capacity.',
    'Determine mobility, activities of daily living, work capacity and other functional effects of illness.',
    'EXAMINATION',
    590,
    false,
    false
),

-- ---------------------------------------------------------------------------
-- ASSESSMENT
-- ---------------------------------------------------------------------------

(
    'PROBLEM-LIST',
    'Active Clinical Problems',
    'Structured list of active clinical problems.',
    'Separate the patient’s active problems and allow each problem to be investigated and managed independently.',
    'ASSESSMENT',
    600,
    true,
    true
),

(
    'CLINICAL-ASSESSMENT',
    'Clinical Assessment',
    'Synthesis of the available clinical evidence.',
    'State the clinical assessment without fabricating certainty beyond the available evidence.',
    'ASSESSMENT',
    610,
    false,
    true
),

(
    'DIFFERENTIAL',
    'Differential Diagnosis',
    'Ranked clinical possibilities supported by the available evidence.',
    'Maintain explicit diagnostic uncertainty and identify what evidence supports or opposes each candidate.',
    'ASSESSMENT',
    620,
    true,
    true
),

(
    'SEVERITY-RISK',
    'Severity and Risk Assessment',
    'Structured severity and risk assessment.',
    'Apply validated severity instruments and clinically relevant risk stratification when indicated.',
    'ASSESSMENT',
    630,
    true,
    false
),

(
    'DIAGNOSIS',
    'Diagnosis',
    'Established or working diagnosis.',
    'Record the diagnosis at the level justified by the evidence and preserve uncertainty when it remains.',
    'ASSESSMENT',
    640,
    true,
    true
),

(
    'COMPLICATIONS',
    'Complications',
    'Current or potential complications.',
    'Identify complications requiring treatment, monitoring, investigation or escalation.',
    'ASSESSMENT',
    650,
    true,
    false
),

-- ---------------------------------------------------------------------------
-- INVESTIGATIONS
-- ---------------------------------------------------------------------------

(
    'INVESTIGATION-QUESTIONS',
    'Clinical Investigation Questions',
    'Clinical questions requiring objective investigation.',
    'Define what the clinician needs the investigation to establish before selecting a test.',
    'INVESTIGATIONS',
    700,
    true,
    false
),

(
    'INVESTIGATIONS',
    'Investigations',
    'Laboratory, imaging and other investigations ordered or performed.',
    'Record investigations requested, indication, priority and status.',
    'INVESTIGATIONS',
    710,
    true,
    false
),

(
    'LAB-RESULTS',
    'Laboratory Results',
    'Laboratory results relevant to active problems.',
    'Capture structured laboratory findings and their clinical context.',
    'INVESTIGATIONS',
    720,
    true,
    false
),

(
    'IMAGING-RESULTS',
    'Imaging Results',
    'Imaging findings and interpretation.',
    'Capture imaging findings, interpretation and diagnostic significance.',
    'INVESTIGATIONS',
    730,
    true,
    false
),

(
    'OTHER-RESULTS',
    'Other Investigation Results',
    'ECG, pathology, microbiology, functional studies and other results.',
    'Capture non-routine investigation findings and interpretation.',
    'INVESTIGATIONS',
    740,
    true,
    false
),

(
    'RESULT-INTERPRETATION',
    'Clinical Interpretation',
    'Clinical interpretation of investigation results.',
    'Connect objective results to clinical questions without confusing a test result with a diagnosis.',
    'INVESTIGATIONS',
    750,
    true,
    false
),

-- ---------------------------------------------------------------------------
-- MANAGEMENT
-- ---------------------------------------------------------------------------

(
    'IMMEDIATE-MANAGEMENT',
    'Immediate Management',
    'Time-critical treatment and stabilization.',
    'Record immediate interventions required to stabilize the patient or prevent deterioration.',
    'MANAGEMENT',
    800,
    true,
    false
),

(
    'NON-PHARMACOLOGICAL',
    'Non-Pharmacological Management',
    'Management not involving medicines.',
    'Record oxygen, fluids, nutrition, physiotherapy, wound care, procedures, lifestyle measures and other interventions.',
    'MANAGEMENT',
    810,
    true,
    false
),

(
    'PHARMACOLOGICAL',
    'Pharmacological Management',
    'Medication treatment plan.',
    'Select medicines according to indication, patient factors, dose, route, frequency, duration, contraindications and monitoring requirements.',
    'MANAGEMENT',
    820,
    true,
    false
),

(
    'PRESCRIPTION',
    'Prescription',
    'Executable medication orders.',
    'Convert an approved therapeutic plan into a complete, safe and auditable prescription.',
    'MANAGEMENT',
    830,
    true,
    false
),

(
    'PROTOCOLS',
    'Clinical Protocols',
    'Applicable treatment protocols and pathways.',
    'Identify and execute relevant evidence-based protocols according to patient context and jurisdiction.',
    'MANAGEMENT',
    840,
    true,
    false
),

(
    'PROCEDURES',
    'Procedures',
    'Procedures performed or planned.',
    'Document indication, consent, preparation, procedure, findings, complications and aftercare.',
    'MANAGEMENT',
    850,
    true,
    false
),

(
    'REFERRAL',
    'Referral and Escalation',
    'Referral or escalation of care.',
    'Record the reason, urgency, destination and clinical information required for escalation.',
    'MANAGEMENT',
    860,
    true,
    false
),

-- ---------------------------------------------------------------------------
-- MONITORING
-- ---------------------------------------------------------------------------

(
    'MONITORING',
    'Monitoring Plan',
    'Clinical parameters requiring surveillance.',
    'Define what must be monitored, how often, expected range, deterioration thresholds and responsible team.',
    'MONITORING',
    900,
    true,
    false
),

(
    'RESPONSE',
    'Response to Treatment',
    'Clinical response after intervention.',
    'Determine whether treatment is effective, ineffective, harmful or incomplete.',
    'MONITORING',
    910,
    true,
    false
),

(
    'ESCALATION',
    'Escalation Criteria',
    'Conditions requiring a change in level of care or treatment.',
    'Make deterioration thresholds explicit and actionable.',
    'MONITORING',
    920,
    true,
    false
),

-- ---------------------------------------------------------------------------
-- DISPOSITION
-- ---------------------------------------------------------------------------

(
    'DISPOSITION',
    'Disposition',
    'Immediate destination and level of care.',
    'Determine outpatient care, admission, observation, referral, transfer, theatre, ICU or other disposition.',
    'DISPOSITION',
    1000,
    false,
    false
),

(
    'DISCHARGE',
    'Discharge Plan',
    'Plan for safe discharge from the encounter.',
    'Record medicines, follow-up, investigations, patient instructions and warning signs.',
    'DISPOSITION',
    1010,
    false,
    false
),

(
    'FOLLOW-UP',
    'Follow-up',
    'Planned continuing care.',
    'Define follow-up interval, responsible service, pending results and treatment review.',
    'DISPOSITION',
    1020,
    true,
    false
),

(
    'SAFETY-NET',
    'Safety-Netting',
    'Explicit warning signs and return instructions.',
    'Tell the patient when and where to seek urgent reassessment.',
    'DISPOSITION',
    1030,
    false,
    false
),

-- ---------------------------------------------------------------------------
-- DOCUMENTATION
-- ---------------------------------------------------------------------------

(
    'CLINICAL-DOCUMENTATION',
    'Clinical Documentation',
    'Compiled clinical record.',
    'Generate the controlled clinical narrative from the structured clinical state.',
    'DOCUMENTATION',
    1100,
    false,
    true
),

(
    'CLINICAL-SUMMARY',
    'Clinical Summary',
    'Concise summary of the encounter.',
    'Provide a clinically useful synthesis for handover, referral, discharge or longitudinal review.',
    'DOCUMENTATION',
    1110,
    false,
    false
),

(
    'HANDOVER',
    'Clinical Handover',
    'Structured transfer of responsibility.',
    'Communicate active problems, current status, pending actions, risks and required follow-up.',
    'DOCUMENTATION',
    1120,
    false,
    false
)

ON CONFLICT (section_code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    clinical_purpose = EXCLUDED.clinical_purpose,
    section_group = EXCLUDED.section_group,
    clinical_sequence = EXCLUDED.clinical_sequence,
    repeatable = EXCLUDED.repeatable,
    default_required = EXCLUDED.default_required,
    updated_at = now();


-- =============================================================================
-- 11. GENERAL MEDICAL FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-GENERAL-MEDICAL',
    section_code,
    name,
    section_group,
    clinical_sequence,
    default_required
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'FAMILY-HISTORY',
    'SOCIAL-HISTORY',
    'OCCUPATIONAL',
    'NUTRITION',
    'GENERAL-EXAM',
    'VITALS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'DISCHARGE',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 12. PAEDIATRIC FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-PAEDIATRIC',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT','CC','HPI','PAEDIATRIC-HISTORY',
            'MEDICATIONS','ALLERGIES','GENERAL-EXAM','VITALS',
            'GROWTH-MEASUREMENTS','CLINICAL-ASSESSMENT',
            'DIFFERENTIAL','DIAGNOSIS','INVESTIGATIONS',
            'PHARMACOLOGICAL','MONITORING'
        )
        THEN true
        ELSE default_required
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAEDIATRIC-HISTORY',
    'BIRTH-HISTORY',
    'DEVELOPMENT',
    'IMMUNIZATION',
    'NUTRITION',
    'MEDICATIONS',
    'ALLERGIES',
    'FAMILY-HISTORY',
    'SOCIAL-HISTORY',
    'GENERAL-EXAM',
    'VITALS',
    'GROWTH-MEASUREMENTS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'DISCHARGE',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 13. NEONATAL FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-NEONATAL',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT','CC','HPI','BIRTH-HISTORY',
            'GENERAL-EXAM','VITALS','GROWTH-MEASUREMENTS',
            'SYSTEM-RESPIRATORY','SYSTEM-CARDIOVASCULAR',
            'SYSTEM-NEUROLOGICAL','NUTRITION',
            'CLINICAL-ASSESSMENT','DIFFERENTIAL','DIAGNOSIS',
            'INVESTIGATIONS','MONITORING'
        )
        THEN true
        ELSE default_required
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'BIRTH-HISTORY',
    'PAEDIATRIC-HISTORY',
    'NUTRITION',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'GROWTH-MEASUREMENTS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 14. OBSTETRIC FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-OBSTETRIC',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT','CC','HPI','OBSTETRIC-HISTORY',
            'CURRENT-PREGNANCY','GENERAL-EXAM','VITALS',
            'OBSTETRIC-EXAM','FOETAL-ASSESSMENT',
            'CLINICAL-ASSESSMENT','DIFFERENTIAL',
            'DIAGNOSIS','INVESTIGATIONS','MONITORING'
        )
        THEN true
        ELSE default_required
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'OBSTETRIC-HISTORY',
    'CURRENT-PREGNANCY',
    'GYN-HISTORY',
    'SEXUAL-HISTORY',
    'GENERAL-EXAM',
    'VITALS',
    'OBSTETRIC-EXAM',
    'FOETAL-ASSESSMENT',
    'PELVIC-EXAM',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 15. GYNAECOLOGICAL FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-GYNAECOLOGICAL',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT','CC','HPI','GYN-HISTORY',
            'SEXUAL-HISTORY','GENERAL-EXAM','VITALS',
            'CLINICAL-ASSESSMENT','DIFFERENTIAL',
            'DIAGNOSIS','INVESTIGATIONS'
        )
        THEN true
        ELSE default_required
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'GYN-HISTORY',
    'OBSTETRIC-HISTORY',
    'SEXUAL-HISTORY',
    'SOCIAL-HISTORY',
    'GENERAL-EXAM',
    'VITALS',
    'BREAST-EXAM',
    'PELVIC-EXAM',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'REFERRAL',
    'MONITORING',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 16. SURGICAL FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-SURGICAL',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT','CC','HPI','PAST-SURGICAL',
            'GENERAL-EXAM','VITALS','CLINICAL-ASSESSMENT',
            'DIFFERENTIAL','DIAGNOSIS','INVESTIGATIONS'
        )
        THEN true
        ELSE default_required
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'SOCIAL-HISTORY',
    'OCCUPATIONAL',
    'NUTRITION',
    'GENERAL-EXAM',
    'VITALS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'SYSTEM-SKIN',
    'BREAST-EXAM',
    'PELVIC-EXAM',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 17. EMERGENCY FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-EMERGENCY',
    section_code,
    name,
    section_group,
    CASE
        WHEN section_code = 'TRAUMA-PRIMARY' THEN 100
        WHEN section_code = 'CC' THEN 110
        WHEN section_code = 'HPI' THEN 120
        WHEN section_code = 'VITALS' THEN 130
        WHEN section_code = 'GENERAL-EXAM' THEN 140
        WHEN section_code = 'TRAUMA-SECONDARY' THEN 150
        ELSE clinical_sequence + 100
    END,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CC',
            'HPI',
            'GENERAL-EXAM',
            'VITALS',
            'CLINICAL-ASSESSMENT',
            'DIFFERENTIAL',
            'DIAGNOSIS',
            'IMMEDIATE-MANAGEMENT',
            'MONITORING',
            'DISPOSITION'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'TRAUMA-PRIMARY',
    'TRAUMA-SECONDARY',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 18. TRAUMA FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-TRAUMA',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'TRAUMA-MECHANISM',
            'TRAUMA-PRIMARY',
            'TRAUMA-SECONDARY',
            'VITALS',
            'GENERAL-EXAM',
            'CLINICAL-ASSESSMENT',
            'DIAGNOSIS',
            'INVESTIGATIONS',
            'IMMEDIATE-MANAGEMENT',
            'MONITORING',
            'DISPOSITION'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'TRAUMA-MECHANISM',
    'HPI',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'TRAUMA-PRIMARY',
    'TRAUMA-SECONDARY',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 19. INPATIENT ADMISSION
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-INPATIENT-ADMISSION',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CC',
            'HPI',
            'PAST-MEDICAL',
            'MEDICATIONS',
            'ALLERGIES',
            'GENERAL-EXAM',
            'VITALS',
            'PROBLEM-LIST',
            'CLINICAL-ASSESSMENT',
            'DIFFERENTIAL',
            'DIAGNOSIS',
            'INVESTIGATIONS',
            'IMMEDIATE-MANAGEMENT',
            'PHARMACOLOGICAL',
            'MONITORING'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'FAMILY-HISTORY',
    'SOCIAL-HISTORY',
    'OCCUPATIONAL',
    'NUTRITION',
    'GENERAL-EXAM',
    'VITALS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 20. INPATIENT PROGRESS / WARD ROUND
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    f.format_code,
    s.section_code,
    s.name,
    s.section_group,
    CASE
        WHEN s.section_code = 'PROBLEM-LIST' THEN 100
        WHEN s.section_code = 'VITALS' THEN 110
        WHEN s.section_code = 'RESPONSE' THEN 120
        WHEN s.section_code = 'LAB-RESULTS' THEN 130
        WHEN s.section_code = 'IMAGING-RESULTS' THEN 140
        WHEN s.section_code = 'CLINICAL-ASSESSMENT' THEN 150
        WHEN s.section_code = 'DIAGNOSIS' THEN 160
        WHEN s.section_code = 'PHARMACOLOGICAL' THEN 170
        WHEN s.section_code = 'MONITORING' THEN 180
        WHEN s.section_code = 'DISPOSITION' THEN 190
        ELSE s.clinical_sequence
    END,
    CASE
        WHEN s.section_code IN (
            'PROBLEM-LIST',
            'VITALS',
            'RESPONSE',
            'CLINICAL-ASSESSMENT',
            'MONITORING'
        )
        THEN true
        ELSE false
    END
FROM
    (VALUES
        ('FMT-INPATIENT-PROGRESS'),
        ('FMT-WARD-ROUND')
    ) AS f(format_code)
CROSS JOIN knowledge.clinical_section s
WHERE s.section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'HPI',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'HANDOVER',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 21. CONSULTATION
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-CONSULTATION',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CC',
            'HPI',
            'GENERAL-EXAM',
            'VITALS',
            'CLINICAL-ASSESSMENT',
            'DIFFERENTIAL',
            'DIAGNOSIS',
            'REFERRAL'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'PAST-SURGICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-MSK',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'REFERRAL',
    'MONITORING',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 22. DISCHARGE
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-DISCHARGE',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'PROBLEM-LIST',
            'DIAGNOSIS',
            'CLINICAL-ASSESSMENT',
            'PHARMACOLOGICAL',
            'PRESCRIPTION',
            'DISPOSITION',
            'DISCHARGE',
            'FOLLOW-UP',
            'SAFETY-NET',
            'CLINICAL-SUMMARY'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROCEDURES',
    'MONITORING',
    'RESPONSE',
    'DISPOSITION',
    'DISCHARGE',
    'FOLLOW-UP',
    'SAFETY-NET',
    'HANDOVER',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 23. OPERATIVE FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-OPERATIVE',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CLINICAL-ASSESSMENT',
            'DIAGNOSIS',
            'PROCEDURES',
            'MONITORING',
            'CLINICAL-DOCUMENTATION'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CLINICAL-ASSESSMENT',
    'DIAGNOSIS',
    'SEVERITY-RISK',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'PROCEDURES',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 24. PROCEDURE FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-PROCEDURE',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CLINICAL-ASSESSMENT',
            'PROCEDURES',
            'MONITORING',
            'CLINICAL-DOCUMENTATION'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'CLINICAL-ASSESSMENT',
    'DIAGNOSIS',
    'SEVERITY-RISK',
    'INVESTIGATIONS',
    'RESULT-INTERPRETATION',
    'PROCEDURES',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'MONITORING',
    'RESPONSE',
    'COMPLICATIONS',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 25. CHRONIC DISEASE FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-CHRONIC-CARE',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CC',
            'HPI',
            'MEDICATIONS',
            'ALLERGIES',
            'VITALS',
            'PROBLEM-LIST',
            'CLINICAL-ASSESSMENT',
            'DIAGNOSIS',
            'INVESTIGATIONS',
            'PHARMACOLOGICAL',
            'MONITORING',
            'FOLLOW-UP'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'SOCIAL-HISTORY',
    'NUTRITION',
    'GENERAL-EXAM',
    'VITALS',
    'GROWTH-MEASUREMENTS',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION',
    'CLINICAL-SUMMARY'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 26. MENTAL HEALTH FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-MENTAL-HEALTH',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CC',
            'HPI',
            'MENTAL-HEALTH-HISTORY',
            'MENTAL-STATE',
            'CLINICAL-ASSESSMENT',
            'DIFFERENTIAL',
            'DIAGNOSIS',
            'MONITORING'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'MENTAL-HEALTH-HISTORY',
    'PSYCHOSOCIAL',
    'SOCIAL-HISTORY',
    'SEXUAL-HISTORY',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'MENTAL-STATE',
    'FUNCTIONAL-ASSESSMENT',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'REFERRAL',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 27. CRITICAL CARE FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-CRITICAL-CARE',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'GENERAL-EXAM',
            'VITALS',
            'SYSTEM-RESPIRATORY',
            'SYSTEM-CARDIOVASCULAR',
            'SYSTEM-NEUROLOGICAL',
            'CLINICAL-ASSESSMENT',
            'PROBLEM-LIST',
            'INVESTIGATIONS',
            'IMMEDIATE-MANAGEMENT',
            'MONITORING',
            'ESCALATION',
            'DISPOSITION'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'SYSTEM-NEUROLOGICAL',
    'SYSTEM-SKIN',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATION-QUESTIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'OTHER-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'HANDOVER',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 28. LABOUR AND DELIVERY
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-MATERNITY-LABOUR',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CC',
            'HPI',
            'CURRENT-PREGNANCY',
            'VITALS',
            'OBSTETRIC-EXAM',
            'FOETAL-ASSESSMENT',
            'LABOUR-ASSESSMENT',
            'CLINICAL-ASSESSMENT',
            'DIAGNOSIS',
            'MONITORING',
            'DISPOSITION'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'OBSTETRIC-HISTORY',
    'CURRENT-PREGNANCY',
    'MEDICATIONS',
    'ALLERGIES',
    'GENERAL-EXAM',
    'VITALS',
    'OBSTETRIC-EXAM',
    'FOETAL-ASSESSMENT',
    'LABOUR-ASSESSMENT',
    'PELVIC-EXAM',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'PROCEDURES',
    'MONITORING',
    'RESPONSE',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 29. POSTNATAL FORMAT
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-POSTNATAL',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CC',
            'HPI',
            'CURRENT-PREGNANCY',
            'GENERAL-EXAM',
            'VITALS',
            'CLINICAL-ASSESSMENT',
            'DIAGNOSIS',
            'MONITORING',
            'DISCHARGE',
            'FOLLOW-UP'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'OBSTETRIC-HISTORY',
    'CURRENT-PREGNANCY',
    'GYN-HISTORY',
    'MEDICATIONS',
    'ALLERGIES',
    'NUTRITION',
    'GENERAL-EXAM',
    'VITALS',
    'OBSTETRIC-EXAM',
    'FOETAL-ASSESSMENT',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIAGNOSIS',
    'COMPLICATIONS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'MONITORING',
    'RESPONSE',
    'DISPOSITION',
    'DISCHARGE',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 30. TELEMEDICINE
-- =============================================================================

INSERT INTO knowledge.clinical_format_section
(format_code, section_code, label, section_group, sequence_no, is_required)
SELECT
    'FMT-TELEMEDICINE',
    section_code,
    name,
    section_group,
    clinical_sequence,
    CASE
        WHEN section_code IN (
            'CTX-PATIENT',
            'CTX-ENCOUNTER',
            'CC',
            'HPI',
            'MEDICATIONS',
            'ALLERGIES',
            'CLINICAL-ASSESSMENT',
            'DIFFERENTIAL',
            'DIAGNOSIS',
            'SAFETY-NET',
            'FOLLOW-UP'
        )
        THEN true
        ELSE false
    END
FROM knowledge.clinical_section
WHERE section_code IN (
    'CTX-PATIENT',
    'CTX-ENCOUNTER',
    'CC',
    'HPI',
    'ROS',
    'PAST-MEDICAL',
    'MEDICATIONS',
    'ALLERGIES',
    'SOCIAL-HISTORY',
    'GENERAL-EXAM',
    'VITALS',
    'SYSTEM-RESPIRATORY',
    'SYSTEM-CARDIOVASCULAR',
    'SYSTEM-ABDOMINAL',
    'MENTAL-STATE',
    'PROBLEM-LIST',
    'CLINICAL-ASSESSMENT',
    'DIFFERENTIAL',
    'SEVERITY-RISK',
    'DIAGNOSIS',
    'INVESTIGATIONS',
    'LAB-RESULTS',
    'IMAGING-RESULTS',
    'RESULT-INTERPRETATION',
    'IMMEDIATE-MANAGEMENT',
    'NON-PHARMACOLOGICAL',
    'PHARMACOLOGICAL',
    'PRESCRIPTION',
    'PROTOCOLS',
    'REFERRAL',
    'MONITORING',
    'ESCALATION',
    'DISPOSITION',
    'FOLLOW-UP',
    'SAFETY-NET',
    'CLINICAL-DOCUMENTATION'
)
ON CONFLICT (format_code, section_code)
DO NOTHING;


-- =============================================================================
-- 31. CONTEXT RULES — AGE
-- =============================================================================

INSERT INTO knowledge.format_context_rule
(
    rule_code,
    format_code,
    context_type,
    context_value,
    action,
    priority_weight,
    rationale
)
VALUES

(
    'FCR-NEONATE-001',
    'FMT-NEONATAL',
    'AGE_BAND',
    'NEONATE',
    'SELECT',
    1000,
    'Neonatal encounters require neonatal clinical history and examination.'
),

(
    'FCR-INFANT-001',
    'FMT-PAEDIATRIC',
    'AGE_BAND',
    'INFANT',
    'SELECT',
    800,
    'Infants require age-specific paediatric assessment.'
),

(
    'FCR-CHILD-001',
    'FMT-PAEDIATRIC',
    'AGE_BAND',
    'CHILD',
    'SELECT',
    800,
    'Children require age-specific paediatric assessment.'
),

(
    'FCR-ADOLESCENT-001',
    'FMT-PAEDIATRIC',
    'AGE_BAND',
    'ADOLESCENT',
    'SELECT',
    700,
    'Adolescents remain within the paediatric clinical pathway unless the service explicitly resolves otherwise.'
),

(
    'FCR-ADULT-001',
    'FMT-GENERAL-MEDICAL',
    'AGE_BAND',
    'ADULT',
    'SELECT',
    500,
    'Adults use the general medical format unless a higher-priority context selects a specialty format.'
),

(
    'FCR-ADULT-SURG-001',
    'FMT-SURGICAL',
    'AGE_BAND',
    'ADULT',
    'SELECT',
    100,
    'Age alone does not establish a surgical encounter; service and presentation rules provide the stronger selection.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 32. SEX / PREGNANCY SAFETY RULES
-- =============================================================================

INSERT INTO knowledge.format_context_rule
(
    rule_code,
    format_code,
    context_type,
    context_value,
    action,
    priority_weight,
    rationale
)
VALUES

(
    'FCR-MALE-OBGYN-BLOCK',
    'FMT-OBSTETRIC',
    'SEX',
    'MALE',
    'BLOCK',
    10000,
    'Obstetric care requires a clinically applicable pregnancy context; male sex blocks the obstetric format.'
),

(
    'FCR-MALE-GYN-BLOCK',
    'FMT-GYNAECOLOGICAL',
    'SEX',
    'MALE',
    'BLOCK',
    10000,
    'Gynaecological care is restricted to clinically applicable female reproductive anatomy/context.'
),

(
    'FCR-PREGNANCY-OB-SELECT',
    'FMT-OBSTETRIC',
    'PREGNANCY',
    'PREGNANT',
    'SELECT',
    3000,
    'Pregnancy activates the obstetric pathway unless the encounter is explicitly resolved to another clinical format.'
),

(
    'FCR-PREGNANCY-NOT-OBGYN-BLOCK',
    'FMT-GYNAECOLOGICAL',
    'PREGNANCY',
    'PREGNANT',
    'BLOCK',
    500,
    'Pregnancy-specific care belongs to the obstetric pathway unless an explicit specialty rule resolves otherwise.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 33. ENCOUNTER TYPE RULES
-- =============================================================================

INSERT INTO knowledge.format_context_rule
(
    rule_code,
    format_code,
    context_type,
    context_value,
    action,
    priority_weight,
    rationale
)
VALUES

(
    'FCR-EMERGENCY-001',
    'FMT-EMERGENCY',
    'ENCOUNTER_TYPE',
    'EMERGENCY',
    'SELECT',
    5000,
    'Emergency encounters require immediate threat-oriented assessment.'
),

(
    'FCR-ADMISSION-001',
    'FMT-INPATIENT-ADMISSION',
    'ENCOUNTER_TYPE',
    'ADMISSION',
    'SELECT',
    4500,
    'Admission encounters require a comprehensive inpatient admission assessment.'
),

(
    'FCR-PROGRESS-001',
    'FMT-INPATIENT-PROGRESS',
    'ENCOUNTER_TYPE',
    'PROGRESS',
    'SELECT',
    4500,
    'Progress encounters require interval reassessment.'
),

(
    'FCR-WARD-001',
    'FMT-WARD-ROUND',
    'ENCOUNTER_TYPE',
    'WARD_ROUND',
    'SELECT',
    4500,
    'Ward rounds require a structured active-problem and daily-plan format.'
),

(
    'FCR-CONSULT-001',
    'FMT-CONSULTATION',
    'ENCOUNTER_TYPE',
    'CONSULTATION',
    'SELECT',
    4500,
    'Consultations require a focused referral-driven assessment.'
),

(
    'FCR-DISCHARGE-001',
    'FMT-DISCHARGE',
    'ENCOUNTER_TYPE',
    'DISCHARGE',
    'SELECT',
    5000,
    'Discharge encounters require a discharge-specific clinical and medication reconciliation pathway.'
),

(
    'FCR-REFERRAL-001',
    'FMT-REFERRAL',
    'ENCOUNTER_TYPE',
    'REFERRAL',
    'SELECT',
    4500,
    'Referral encounters require a clinically complete transfer summary.'
),

(
    'FCR-OPERATIVE-001',
    'FMT-OPERATIVE',
    'ENCOUNTER_TYPE',
    'OPERATIVE',
    'SELECT',
    5000,
    'Operative encounters require perioperative and procedure-specific documentation.'
),

(
    'FCR-PROCEDURE-001',
    'FMT-PROCEDURE',
    'ENCOUNTER_TYPE',
    'PROCEDURE',
    'SELECT',
    4500,
    'Procedure encounters require indication, consent, procedure and post-procedure documentation.'
),

(
    'FCR-TELEMED-001',
    'FMT-TELEMEDICINE',
    'ENCOUNTER_TYPE',
    'TELEMEDICINE',
    'SELECT',
    4000,
    'Remote encounters require explicit recognition of examination limitations and escalation criteria.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 34. DEPARTMENT / SERVICE RULES
-- =============================================================================

INSERT INTO knowledge.format_context_rule
(
    rule_code,
    format_code,
    context_type,
    context_value,
    action,
    priority_weight,
    rationale
)
VALUES

(
    'FCR-PAEDS-DEPT',
    'FMT-PAEDIATRIC',
    'DEPARTMENT',
    'PAEDIATRICS',
    'SELECT',
    4000,
    'Paediatric service selects paediatric clinical workflow.'
),

(
    'FCR-NEONATAL-DEPT',
    'FMT-NEONATAL',
    'DEPARTMENT',
    'NEONATOLOGY',
    'SELECT',
    5000,
    'Neonatal service selects neonatal workflow.'
),

(
    'FCR-OBGYN-DEPT',
    'FMT-GYNAECOLOGICAL',
    'DEPARTMENT',
    'GYNAECOLOGY',
    'SELECT',
    4000,
    'Gynaecology service selects gynaecological workflow.'
),

(
    'FCR-OBSTETRICS-DEPT',
    'FMT-OBSTETRIC',
    'DEPARTMENT',
    'OBSTETRICS',
    'SELECT',
    4500,
    'Obstetric service selects pregnancy-focused workflow.'
),

(
    'FCR-SURGERY-DEPT',
    'FMT-SURGICAL',
    'DEPARTMENT',
    'SURGERY',
    'SELECT',
    4000,
    'Surgical service selects surgical assessment workflow.'
),

(
    'FCR-TRAUMA-DEPT',
    'FMT-TRAUMA',
    'DEPARTMENT',
    'TRAUMA',
    'SELECT',
    5000,
    'Trauma service selects trauma workflow.'
),

(
    'FCR-ICU-DEPT',
    'FMT-CRITICAL-CARE',
    'DEPARTMENT',
    'ICU',
    'SELECT',
    5000,
    'Intensive care requires high-acuity organ-system and monitoring workflow.'
),

(
    'FCR-MH-DEPT',
    'FMT-MENTAL-HEALTH',
    'DEPARTMENT',
    'MENTAL_HEALTH',
    'SELECT',
    4000,
    'Mental health service selects psychiatric assessment workflow.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 35. SYMPTOM DOMAIN RULES
-- =============================================================================

INSERT INTO knowledge.format_context_rule
(
    rule_code,
    format_code,
    context_type,
    context_value,
    action,
    priority_weight,
    rationale
)
VALUES

(
    'FCR-TRAUMA-DOMAIN',
    'FMT-TRAUMA',
    'SYMPTOM_DOMAIN',
    'TRAUMA',
    'SELECT',
    4000,
    'Trauma presentation activates injury-focused clinical assessment.'
),

(
    'FCR-RESPIRATORY-DOMAIN',
    'FMT-GENERAL-MEDICAL',
    'SYMPTOM_DOMAIN',
    'RESPIRATORY',
    'SELECT',
    100,
    'Respiratory symptoms initially enter the general medical pathway unless a stronger context selects another format.'
),

(
    'FCR-ABDOMINAL-DOMAIN',
    'FMT-GENERAL-MEDICAL',
    'SYMPTOM_DOMAIN',
    'ABDOMINAL',
    'SELECT',
    100,
    'Abdominal symptoms initially enter the general medical pathway unless a stronger surgical or emergency context applies.'
),

(
    'FCR-OBSTETRIC-DOMAIN',
    'FMT-OBSTETRIC',
    'SYMPTOM_DOMAIN',
    'PREGNANCY',
    'SELECT',
    2500,
    'Pregnancy-related symptoms require pregnancy-specific clinical assessment.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 36. CONTEXT SECTION RULES — PAEDIATRICS
-- =============================================================================

INSERT INTO knowledge.section_context_rule
(
    rule_code,
    section_code,
    context_type,
    context_value,
    modification,
    priority_weight,
    rationale
)
VALUES

(
    'SCR-CHILD-BIRTH-HISTORY',
    'BIRTH-HISTORY',
    'AGE_BAND',
    'CHILD',
    'ACTIVATE',
    100,
    'Birth history may remain clinically relevant when childhood disease requires it.'
),

(
    'SCR-PAEDS-DEVELOPMENT',
    'DEVELOPMENT',
    'AGE_BAND',
    'CHILD',
    'REQUIRE',
    1000,
    'Developmental assessment is fundamental to paediatric care.'
),

(
    'SCR-PAEDS-GROWTH',
    'GROWTH-MEASUREMENTS',
    'AGE_BAND',
    'CHILD',
    'REQUIRE',
    1000,
    'Growth assessment is fundamental to paediatric clinical assessment.'
),

(
    'SCR-PAEDS-IMMUNIZATION',
    'IMMUNIZATION',
    'AGE_BAND',
    'CHILD',
    'ACTIVATE',
    900,
    'Immunization status is clinically relevant in paediatric assessment.'
),

(
    'SCR-PAEDS-NUTRITION',
    'NUTRITION',
    'AGE_BAND',
    'CHILD',
    'ACTIVATE',
    900,
    'Nutrition is clinically relevant to paediatric assessment and treatment.'
),

(
    'SCR-NEONATE-BIRTH',
    'BIRTH-HISTORY',
    'AGE_BAND',
    'NEONATE',
    'REQUIRE',
    3000,
    'Birth history is essential in neonatal assessment.'
),

(
    'SCR-NEONATE-FEEDING',
    'NUTRITION',
    'AGE_BAND',
    'NEONATE',
    'REQUIRE',
    3000,
    'Feeding is a core component of neonatal assessment.'
),

(
    'SCR-NEONATE-GROWTH',
    'GROWTH-MEASUREMENTS',
    'AGE_BAND',
    'NEONATE',
    'REQUIRE',
    2500,
    'Birth weight and current anthropometry are important in neonatal assessment.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 37. PREGNANCY SECTION RULES
-- =============================================================================

INSERT INTO knowledge.section_context_rule
(
    rule_code,
    section_code,
    context_type,
    context_value,
    modification,
    priority_weight,
    rationale
)
VALUES

(
    'SCR-PREGNANCY-OB-HISTORY',
    'OBSTETRIC-HISTORY',
    'PREGNANCY',
    'PREGNANT',
    'REQUIRE',
    3000,
    'Previous obstetric history informs current pregnancy risk.'
),

(
    'SCR-PREGNANCY-CURRENT',
    'CURRENT-PREGNANCY',
    'PREGNANCY',
    'PREGNANT',
    'REQUIRE',
    4000,
    'Current pregnancy status is required for pregnancy-related encounters.'
),

(
    'SCR-PREGNANCY-FOETAL',
    'FOETAL-ASSESSMENT',
    'PREGNANCY',
    'PREGNANT',
    'ACTIVATE',
    2500,
    'Fetal assessment becomes applicable according to gestational age and clinical context.'
),

(
    'SCR-PREGNANCY-OB-EXAM',
    'OBSTETRIC-EXAM',
    'PREGNANCY',
    'PREGNANT',
    'ACTIVATE',
    2500,
    'Pregnancy activates maternal obstetric examination where clinically indicated.'
),

(
    'SCR-PREGNANCY-GYN-HIDE',
    'GYN-HISTORY',
    'PREGNANCY',
    'PREGNANT',
    'ACTIVATE',
    500,
    'Gynaecological history remains available where clinically relevant during pregnancy.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 38. EMERGENCY SECTION RULES
-- =============================================================================

INSERT INTO knowledge.section_context_rule
(
    rule_code,
    section_code,
    context_type,
    context_value,
    modification,
    priority_weight,
    rationale
)
VALUES

(
    'SCR-EMERGENCY-VITALS',
    'VITALS',
    'ENCOUNTER_TYPE',
    'EMERGENCY',
    'REQUIRE',
    5000,
    'Physiological observations are mandatory in emergency assessment.'
),

(
    'SCR-EMERGENCY-GENERAL',
    'GENERAL-EXAM',
    'ENCOUNTER_TYPE',
    'EMERGENCY',
    'REQUIRE',
    5000,
    'Immediate general assessment is required in emergency care.'
),

(
    'SCR-EMERGENCY-IMMEDIATE',
    'IMMEDIATE-MANAGEMENT',
    'ENCOUNTER_TYPE',
    'EMERGENCY',
    'REQUIRE',
    4500,
    'Emergency encounters require explicit consideration of immediate stabilization.'
),

(
    'SCR-EMERGENCY-MONITORING',
    'MONITORING',
    'ENCOUNTER_TYPE',
    'EMERGENCY',
    'ACTIVATE',
    4000,
    'Monitoring requirements are determined from acuity and clinical findings.'
),

(
    'SCR-EMERGENCY-ESCALATION',
    'ESCALATION',
    'ENCOUNTER_TYPE',
    'EMERGENCY',
    'ACTIVATE',
    4000,
    'Emergency care requires explicit escalation criteria where clinically relevant.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 39. TRAUMA SECTION RULES
-- =============================================================================

INSERT INTO knowledge.section_context_rule
(
    rule_code,
    section_code,
    context_type,
    context_value,
    modification,
    priority_weight,
    rationale
)
VALUES

(
    'SCR-TRAUMA-MECHANISM',
    'TRAUMA-MECHANISM',
    'SYMPTOM_DOMAIN',
    'TRAUMA',
    'REQUIRE',
    5000,
    'Mechanism of injury determines the pattern and severity of possible trauma.'
),

(
    'SCR-TRAUMA-PRIMARY',
    'TRAUMA-PRIMARY',
    'SYMPTOM_DOMAIN',
    'TRAUMA',
    'REQUIRE',
    6000,
    'Primary survey must precede detailed trauma assessment when major trauma is suspected.'
),

(
    'SCR-TRAUMA-SECONDARY',
    'TRAUMA-SECONDARY',
    'SYMPTOM_DOMAIN',
    'TRAUMA',
    'REQUIRE',
    4500,
    'Secondary survey identifies injuries not detected during the primary survey.'
),

(
    'SCR-TRAUMA-ESCALATION',
    'ESCALATION',
    'SYMPTOM_DOMAIN',
    'TRAUMA',
    'ACTIVATE',
    4500,
    'Trauma assessment requires explicit escalation criteria.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 40. SURGICAL SECTION RULES
-- =============================================================================

INSERT INTO knowledge.section_context_rule
(
    rule_code,
    section_code,
    context_type,
    context_value,
    modification,
    priority_weight,
    rationale
)
VALUES

(
    'SCR-SURGICAL-EXAM',
    'GENERAL-EXAM',
    'DEPARTMENT',
    'SURGERY',
    'REQUIRE',
    3000,
    'Surgical patients require structured physical assessment.'
),

(
    'SCR-SURGICAL-DIAGNOSIS',
    'DIAGNOSIS',
    'DEPARTMENT',
    'SURGERY',
    'REQUIRE',
    3000,
    'Surgical planning requires a documented diagnosis or working diagnosis.'
),

(
    'SCR-SURGICAL-PROCEDURES',
    'PROCEDURES',
    'DEPARTMENT',
    'SURGERY',
    'ACTIVATE',
    2000,
    'Procedure documentation becomes available when an intervention is performed or planned.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 41. MEDICATION / PRESCRIBING SECTION RULES
-- =============================================================================

INSERT INTO knowledge.section_context_rule
(
    rule_code,
    section_code,
    context_type,
    context_value,
    modification,
    priority_weight,
    rationale
)
VALUES

(
    'SCR-PRESCRIPTION-MEDICATION',
    'MEDICATIONS',
    'ENCOUNTER_TYPE',
    'MEDICATION_REVIEW',
    'REQUIRE',
    3000,
    'Medication review requires a complete current medication history.'
),

(
    'SCR-PRESCRIPTION-ALLERGY',
    'ALLERGIES',
    'ENCOUNTER_TYPE',
    'MEDICATION_REVIEW',
    'REQUIRE',
    4000,
    'Allergy and adverse reaction status must be established before medication decisions.'
),

(
    'SCR-PRESCRIPTION-PHARMACOLOGY',
    'PHARMACOLOGICAL',
    'ENCOUNTER_TYPE',
    'MEDICATION_REVIEW',
    'ACTIVATE',
    3000,
    'Medication review may require pharmacological optimization.'
),

(
    'SCR-PRESCRIPTION-PRESCRIPTION',
    'PRESCRIPTION',
    'ENCOUNTER_TYPE',
    'MEDICATION_REVIEW',
    'ACTIVATE',
    3000,
    'A medication review may result in executable prescription changes.'
)

ON CONFLICT (rule_code)
DO NOTHING;


-- =============================================================================
-- 42. QUESTION MODULE SECTION LINKAGE
-- =============================================================================
--
-- Existing question modules without a section remain valid legacy objects.
-- The CPU can progressively map them to universal clinical sections.
-- =============================================================================

UPDATE knowledge.question_module
SET section_code = 'HPI'
WHERE section_code IS NULL
  AND (
      lower(coalesce(module_code,'')) LIKE '%hpi%'
      OR lower(coalesce(module_name,'')) LIKE '%history of present illness%'
  );

UPDATE knowledge.question_module
SET section_code = 'CC'
WHERE section_code IS NULL
  AND (
      lower(coalesce(module_code,'')) LIKE '%chief%'
      OR lower(coalesce(module_name,'')) LIKE '%chief complaint%'
  );

UPDATE knowledge.question_module
SET section_code = 'ROS'
WHERE section_code IS NULL
  AND (
      lower(coalesce(module_code,'')) LIKE '%ros%'
      OR lower(coalesce(module_name,'')) LIKE '%review of systems%'
  );

UPDATE knowledge.question_module
SET section_code = 'MEDICATIONS'
WHERE section_code IS NULL
  AND (
      lower(coalesce(module_code,'')) LIKE '%medication%'
      OR lower(coalesce(module_name,'')) LIKE '%medication%'
  );

UPDATE knowledge.question_module
SET section_code = 'ALLERGIES'
WHERE section_code IS NULL
  AND (
      lower(coalesce(module_code,'')) LIKE '%allerg%'
      OR lower(coalesce(module_name,'')) LIKE '%allerg%'
  );


-- =============================================================================
-- 43. CLINICAL FORMAT RESOLUTION FUNCTION
-- =============================================================================
--
-- This function performs deterministic format resolution.
--
-- RULE:
--   BLOCK > SELECT
--   score = sum(priority_weight of matching SELECT rules)
--   blocked format cannot win
--   highest score wins
--   tie → format.sort_order
--
-- This function is intentionally context-vector based.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_clinical_format(
    p_context jsonb
)
RETURNS TABLE (
    format_code text,
    score integer,
    blocked boolean,
    resolution_reason text
)
LANGUAGE sql
STABLE
AS $$
WITH matching AS (
    SELECT
        f.format_code,

        COALESCE(
            SUM(
                CASE
                    WHEN r.action = 'SELECT'
                    THEN r.priority_weight
                    ELSE 0
                END
            ),
            0
        )::integer AS score,

        BOOL_OR(
            r.action = 'BLOCK'
        ) FILTER (
            WHERE r.action = 'BLOCK'
        ) AS blocked,

        COUNT(*)::integer AS matched_rule_count

    FROM knowledge.clinical_format f

    LEFT JOIN knowledge.format_context_rule r
        ON r.format_code = f.format_code
       AND r.status = 'active'
       AND p_context ->> r.context_type = r.context_value

    WHERE f.status = 'active'

    GROUP BY f.format_code
)

SELECT
    m.format_code,
    m.score,
    COALESCE(m.blocked,false),
    CASE
        WHEN COALESCE(m.blocked,false)
            THEN 'FORMAT BLOCKED BY CONTEXT RULE'
        WHEN m.matched_rule_count = 0
            THEN 'NO SPECIFIC CONTEXT RULE; UNIVERSAL FALLBACK'
        ELSE
            'FORMAT SELECTED FROM MATCHED CONTEXT RULES'
    END
FROM matching m
ORDER BY
    COALESCE(m.blocked,false) ASC,
    m.score DESC,
    (
        SELECT sort_order
        FROM knowledge.clinical_format f
        WHERE f.format_code = m.format_code
    )
ASC;
$$;


-- =============================================================================
-- 44. SECTION RESOLUTION FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_clinical_sections(
    p_format_code text,
    p_context jsonb
)
RETURNS TABLE (
    section_code text,
    label text,
    section_group text,
    sequence_no integer,
    state text
)
LANGUAGE sql
STABLE
AS $$
WITH base_sections AS (
    SELECT
        cfs.section_code,
        cfs.label,
        cfs.section_group,
        cfs.sequence_no,
        CASE
            WHEN cfs.is_required
                THEN 'REQUIRED'
            ELSE upper(cfs.default_state)
        END AS base_state
    FROM knowledge.clinical_format_section cfs
    WHERE cfs.format_code = p_format_code
),

rules AS (
    SELECT
        s.section_code,

        BOOL_OR(
            scr.modification = 'HIDE'
        ) FILTER (
            WHERE p_context ->> scr.context_type = scr.context_value
              AND scr.status = 'active'
        ) AS hidden,

        BOOL_OR(
            scr.modification = 'REQUIRE'
        ) FILTER (
            WHERE p_context ->> scr.context_type = scr.context_value
              AND scr.status = 'active'
        ) AS required,

        BOOL_OR(
            scr.modification = 'ACTIVATE'
        ) FILTER (
            WHERE p_context ->> scr.context_type = scr.context_value
              AND scr.status = 'active'
        ) AS activated

    FROM base_sections s

    LEFT JOIN knowledge.section_context_rule scr
        ON scr.section_code = s.section_code

    GROUP BY s.section_code
)

SELECT
    b.section_code,
    b.label,
    b.section_group,
    b.sequence_no,

    CASE
        WHEN COALESCE(r.hidden,false)
            THEN 'HIDDEN'

        WHEN COALESCE(r.required,false)
            THEN 'REQUIRED'

        WHEN COALESCE(r.activated,false)
            THEN 'ACTIVE'

        ELSE b.base_state
    END AS state

FROM base_sections b

LEFT JOIN rules r
    ON r.section_code = b.section_code

WHERE NOT COALESCE(r.hidden,false)

ORDER BY b.sequence_no;
$$;


-- =============================================================================
-- 45. CLINICAL WORKSPACE NAVIGATION PROJECTION
-- =============================================================================
--
-- This is the CPU/UI boundary.
--
-- The UI receives this projection.
-- The UI does NOT evaluate format_context_rule or section_context_rule.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.build_workspace_navigation_projection(
    p_format_code text,
    p_context jsonb
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
SELECT jsonb_build_object(
    'format',
    p_format_code,

    'context',
    p_context,

    'sections',
    COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'sectionCode', section_code,
                'label', label,
                'group', section_group,
                'sequence', sequence_no,
                'state', state
            )
            ORDER BY sequence_no
        ),
        '[]'::jsonb
    ),

    'generatedAt',
    now()
)
FROM knowledge.resolve_clinical_sections(
    p_format_code,
    p_context
);
$$;


-- =============================================================================
-- 46. FORMAT VALIDATION
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_clinical_format(
    p_format_code text
)
RETURNS TABLE (
    check_name text,
    status text,
    detail text
)
LANGUAGE sql
STABLE
AS $$
WITH format_exists AS (
    SELECT EXISTS (
        SELECT 1
        FROM knowledge.clinical_format
        WHERE format_code = p_format_code
          AND status = 'active'
    ) AS ok
),

sections AS (
    SELECT COUNT(*)::integer AS count
    FROM knowledge.clinical_format_section
    WHERE format_code = p_format_code
),

duplicate_sequence AS (
    SELECT COUNT(*)::integer AS count
    FROM (
        SELECT sequence_no
        FROM knowledge.clinical_format_section
        WHERE format_code = p_format_code
        GROUP BY sequence_no
        HAVING COUNT(*) > 1
    ) x
),

required_missing AS (
    SELECT COUNT(*)::integer AS count
    FROM knowledge.clinical_format_section
    WHERE format_code = p_format_code
      AND is_required = true
      AND default_state = 'hidden'
)

SELECT
    'FORMAT_EXISTS',
    CASE WHEN f.ok THEN 'PASS' ELSE 'FAIL' END,
    CASE
        WHEN f.ok THEN 'Format exists and is active.'
        ELSE 'Format does not exist or is not active.'
    END
FROM format_exists f

UNION ALL

SELECT
    'SECTION_COUNT',
    CASE WHEN s.count > 0 THEN 'PASS' ELSE 'FAIL' END,
    'Format contains ' || s.count || ' clinical sections.'
FROM sections s

UNION ALL

SELECT
    'SEQUENCE_COLLISIONS',
    CASE WHEN d.count = 0 THEN 'PASS' ELSE 'WARN' END,
    CASE
        WHEN d.count = 0 THEN 'No duplicate section sequence numbers.'
        ELSE d.count || ' duplicate sequence groups detected.'
    END
FROM duplicate_sequence d

UNION ALL

SELECT
    'REQUIRED_HIDDEN_CONFLICT',
    CASE WHEN r.count = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE
        WHEN r.count = 0 THEN 'No required section is hidden by default.'
        ELSE r.count || ' required section(s) are hidden by default.'
    END
FROM required_missing r;
$$;


-- =============================================================================
-- 47. UNIVERSAL CLINICAL FLOW ORDER
-- =============================================================================
--
-- These are explicit constitutional workflow stages.
-- A format may omit stages when clinically inappropriate.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_workflow_stage (
    stage_code text PRIMARY KEY,
    stage_name text NOT NULL,
    description text NOT NULL,
    sequence_no integer NOT NULL UNIQUE,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired'))
);

INSERT INTO knowledge.clinical_workflow_stage
(
    stage_code,
    stage_name,
    description,
    sequence_no
)
VALUES

(
    'STAGE-CONTEXT',
    'Context',
    'Resolve patient, encounter and clinical applicability context.',
    10
),

(
    'STAGE-HISTORY',
    'History',
    'Collect the clinical history needed to characterize the presenting problem and relevant background.',
    20
),

(
    'STAGE-EXAMINATION',
    'Examination',
    'Obtain objective clinical findings appropriate to the patient and presenting problem.',
    30
),

(
    'STAGE-ASSESSMENT',
    'Assessment',
    'Synthesize history and examination into problems, hypotheses, severity and working diagnoses.',
    40
),

(
    'STAGE-INVESTIGATION',
    'Investigation',
    'Answer explicit clinical questions using appropriate investigations and interpretation.',
    50
),

(
    'STAGE-DIAGNOSIS',
    'Diagnosis',
    'Record the diagnosis or working diagnosis at the level supported by the available evidence.',
    60
),

(
    'STAGE-MANAGEMENT',
    'Management',
    'Select and execute appropriate non-pharmacological, pharmacological, procedural and protocol-based treatment.',
    70
),

(
    'STAGE-MONITORING',
    'Monitoring',
    'Monitor response, adverse effects, deterioration and treatment endpoints.',
    80
),

(
    'STAGE-DISPOSITION',
    'Disposition',
    'Determine admission, discharge, referral, transfer, observation or continuing care.',
    90
),

(
    'STAGE-DOCUMENTATION',
    'Documentation',
    'Compile the clinically accurate and provenance-linked record of the encounter.',
    100
)

ON CONFLICT (stage_code)
DO UPDATE SET
    stage_name = EXCLUDED.stage_name,
    description = EXCLUDED.description,
    sequence_no = EXCLUDED.sequence_no;


-- =============================================================================
-- 48. FORMAT → WORKFLOW STAGE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_format_stage (
    format_code text NOT NULL
        REFERENCES knowledge.clinical_format(format_code)
        ON DELETE CASCADE,

    stage_code text NOT NULL
        REFERENCES knowledge.clinical_workflow_stage(stage_code)
        ON DELETE CASCADE,

    sequence_no integer NOT NULL,

    required boolean NOT NULL DEFAULT false,

    PRIMARY KEY (format_code, stage_code)
);

CREATE INDEX IF NOT EXISTS idx_format_stage_sequence
    ON knowledge.clinical_format_stage(format_code, sequence_no);


INSERT INTO knowledge.clinical_format_stage
(
    format_code,
    stage_code,
    sequence_no,
    required
)
SELECT
    f.format_code,
    s.stage_code,
    s.sequence_no,
    true
FROM knowledge.clinical_format f
CROSS JOIN knowledge.clinical_workflow_stage s
WHERE f.status = 'active'
  AND s.status = 'active'
ON CONFLICT (format_code, stage_code)
DO NOTHING;


-- =============================================================================
-- 49. CLINICAL SECTION → WORKFLOW STAGE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_section_stage (
    section_code text PRIMARY KEY
        REFERENCES knowledge.clinical_section(section_code)
        ON DELETE CASCADE,

    stage_code text NOT NULL
        REFERENCES knowledge.clinical_workflow_stage(stage_code),

    created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO knowledge.clinical_section_stage
(
    section_code,
    stage_code
)
SELECT
    section_code,
    CASE section_group
        WHEN 'IDENTIFICATION' THEN 'STAGE-CONTEXT'
        WHEN 'HISTORY' THEN 'STAGE-HISTORY'
        WHEN 'EXAMINATION' THEN 'STAGE-EXAMINATION'
        WHEN 'ASSESSMENT' THEN 'STAGE-ASSESSMENT'
        WHEN 'INVESTIGATIONS' THEN 'STAGE-INVESTIGATION'
        WHEN 'MANAGEMENT' THEN 'STAGE-MANAGEMENT'
        WHEN 'MONITORING' THEN 'STAGE-MONITORING'
        WHEN 'DISPOSITION' THEN 'STAGE-DISPOSITION'
        WHEN 'DOCUMENTATION' THEN 'STAGE-DOCUMENTATION'
    END
FROM knowledge.clinical_section
ON CONFLICT (section_code)
DO UPDATE SET
    stage_code = EXCLUDED.stage_code;


-- =============================================================================
-- 50. CLINICAL SECTION COMPLETION STATE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_section_completion (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id uuid NOT NULL,

    section_code text NOT NULL
        REFERENCES knowledge.clinical_section(section_code),

    state text NOT NULL
        CHECK (state IN (
            'NOT_STARTED',
            'IN_PROGRESS',
            'COMPLETE',
            'SKIPPED',
            'NOT_APPLICABLE',
            'BLOCKED'
        )),

    completion_percent numeric(5,2) NOT NULL DEFAULT 0
        CHECK (completion_percent BETWEEN 0 AND 100),

    required_item_count integer NOT NULL DEFAULT 0,

    completed_item_count integer NOT NULL DEFAULT 0,

    next_question_count integer NOT NULL DEFAULT 0,

    last_updated_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (encounter_id, section_code)
);

CREATE INDEX IF NOT EXISTS idx_section_completion_encounter
    ON knowledge.clinical_section_completion(encounter_id);

CREATE INDEX IF NOT EXISTS idx_section_completion_state
    ON knowledge.clinical_section_completion(
        encounter_id,
        state
    );


-- =============================================================================
-- 51. CLINICAL WORKSPACE STATE
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.clinical_workspace_state (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    encounter_id uuid NOT NULL UNIQUE,

    format_code text
        REFERENCES knowledge.clinical_format(format_code),

    current_section_code text
        REFERENCES knowledge.clinical_section(section_code),

    current_stage_code text
        REFERENCES knowledge.clinical_workflow_stage(stage_code),

    context_vector jsonb NOT NULL DEFAULT '{}'::jsonb,

    navigation_projection jsonb NOT NULL DEFAULT '{}'::jsonb,

    unresolved_information_gaps jsonb NOT NULL DEFAULT '[]'::jsonb,

    active_problems jsonb NOT NULL DEFAULT '[]'::jsonb,

    updated_at timestamptz NOT NULL DEFAULT now(),

    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workspace_state_format
    ON knowledge.clinical_workspace_state(format_code);

CREATE INDEX IF NOT EXISTS idx_workspace_state_stage
    ON knowledge.clinical_workspace_state(current_stage_code);


-- =============================================================================
-- 52. UPDATED_AT TRIGGERS
-- =============================================================================

DROP TRIGGER IF EXISTS trg_clinical_format_updated_at
ON knowledge.clinical_format;

CREATE TRIGGER trg_clinical_format_updated_at
BEFORE UPDATE ON knowledge.clinical_format
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_clinical_section_updated_at
ON knowledge.clinical_section;

CREATE TRIGGER trg_clinical_section_updated_at
BEFORE UPDATE ON knowledge.clinical_section
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_format_context_rule_updated_at
ON knowledge.format_context_rule;

CREATE TRIGGER trg_format_context_rule_updated_at
BEFORE UPDATE ON knowledge.format_context_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


DROP TRIGGER IF EXISTS trg_section_context_rule_updated_at
ON knowledge.section_context_rule;

CREATE TRIGGER trg_section_context_rule_updated_at
BEFORE UPDATE ON knowledge.section_context_rule
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 53. CLINICAL FORMAT SAFETY CONSTRAINTS
-- =============================================================================

ALTER TABLE knowledge.clinical_format_section
    DROP CONSTRAINT IF EXISTS clinical_format_section_sequence_positive;

ALTER TABLE knowledge.clinical_format_section
    ADD CONSTRAINT clinical_format_section_sequence_positive
    CHECK (sequence_no >= 0);


ALTER TABLE knowledge.clinical_format_section
    DROP CONSTRAINT IF EXISTS clinical_format_section_required_state;

ALTER TABLE knowledge.clinical_format_section
    ADD CONSTRAINT clinical_format_section_required_state
    CHECK (
        NOT is_required
        OR default_state IN ('available','active','complete')
    );


ALTER TABLE knowledge.clinical_section
    DROP CONSTRAINT IF EXISTS clinical_section_sequence_positive;

ALTER TABLE knowledge.clinical_section
    ADD CONSTRAINT clinical_section_sequence_positive
    CHECK (clinical_sequence >= 0);


-- =============================================================================
-- 54. VALIDATION — NO FORMAT WITHOUT A CORE HISTORY PATH
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_all_clinical_formats()
RETURNS TABLE (
    format_code text,
    status text,
    detail text
)
LANGUAGE sql
STABLE
AS $$
WITH required_core AS (
    SELECT
        f.format_code,

        COUNT(*) FILTER (
            WHERE cfs.section_code = 'CC'
        ) AS has_cc,

        COUNT(*) FILTER (
            WHERE cfs.section_code = 'HPI'
        ) AS has_hpi,

        COUNT(*) FILTER (
            WHERE cfs.section_code = 'CLINICAL-ASSESSMENT'
        ) AS has_assessment,

        COUNT(*) FILTER (
            WHERE cfs.section_code = 'CLINICAL-DOCUMENTATION'
        ) AS has_documentation

    FROM knowledge.clinical_format f

    LEFT JOIN knowledge.clinical_format_section cfs
        ON cfs.format_code = f.format_code

    WHERE f.status = 'active'

    GROUP BY f.format_code
)

SELECT
    format_code,

    CASE
        WHEN has_cc > 0
         AND has_hpi > 0
         AND has_assessment > 0
         AND has_documentation > 0
        THEN 'PASS'
        ELSE 'FAIL'
    END,

    CASE
        WHEN has_cc = 0
            THEN 'Missing Chief Complaint section.'
        WHEN has_hpi = 0
            THEN 'Missing History of Present Illness section.'
        WHEN has_assessment = 0
            THEN 'Missing Clinical Assessment section.'
        WHEN has_documentation = 0
            THEN 'Missing Clinical Documentation section.'
        ELSE
            'Core clinical pathway present.'
    END

FROM required_core;
$$;


-- =============================================================================
-- 55. FORMAT SELECTION VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_active_clinical_formats
AS
SELECT
    f.format_code,
    f.name,
    f.description,
    f.clinical_purpose,
    f.sort_order,
    COUNT(cfs.section_code) AS section_count
FROM knowledge.clinical_format f
LEFT JOIN knowledge.clinical_format_section cfs
    ON cfs.format_code = f.format_code
WHERE f.status = 'active'
GROUP BY
    f.format_code,
    f.name,
    f.description,
    f.clinical_purpose,
    f.sort_order;


-- =============================================================================
-- 56. SECTION CATALOGUE VIEW
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_clinical_section_catalogue
AS
SELECT
    cs.section_code,
    cs.name,
    cs.section_group,
    cs.clinical_purpose,
    cs.clinical_sequence,
    cs.repeatable,
    cs.default_required,
    cws.stage_code,
    cws.stage_name
FROM knowledge.clinical_section cs
LEFT JOIN knowledge.clinical_section_stage css
    ON css.section_code = cs.section_code
LEFT JOIN knowledge.clinical_workflow_stage cws
    ON cws.stage_code = css.stage_code
WHERE cs.status = 'active';


-- =============================================================================
-- 57. COMPLETE UNIVERSAL CLINICAL WORKSPACE PROJECTION
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.compile_universal_workspace(
    p_context jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_format text;
    v_score integer;
    v_blocked boolean;
    v_projection jsonb;
BEGIN

    SELECT
        r.format_code,
        r.score,
        r.blocked
    INTO
        v_format,
        v_score,
        v_blocked
    FROM knowledge.resolve_clinical_format(p_context) r
    WHERE NOT r.blocked
    ORDER BY r.score DESC
    LIMIT 1;

    IF v_format IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'NO_CLINICALLY_APPLICABLE_FORMAT',
            'context', p_context,
            'sections', '[]'::jsonb
        );
    END IF;

    v_projection :=
        knowledge.build_workspace_navigation_projection(
            v_format,
            p_context
        );

    RETURN jsonb_build_object(
        'status', 'READY',
        'formatCode', v_format,
        'formatScore', v_score,
        'contextVector', p_context,
        'clinicalWorkflow',
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'stageCode', stage_code,
                    'stageName', stage_name,
                    'sequence', sequence_no,
                    'required', required
                )
                ORDER BY sequence_no
            )
            FROM knowledge.clinical_format_stage cfs
            JOIN knowledge.clinical_workflow_stage cws
                ON cws.stage_code = cfs.stage_code
            WHERE cfs.format_code = v_format
        ),
        'navigation',
        v_projection,
        'resolvedAt',
        now()
    );
END;
$$;


-- =============================================================================
-- 58. FINAL CLINICAL SAFETY SELF-CHECK
-- =============================================================================

DO $universal_clinical_os$
DECLARE
    v_formats integer;
    v_sections integer;
    v_rules integer;
    v_stages integer;
BEGIN

    SELECT COUNT(*)
    INTO v_formats
    FROM knowledge.clinical_format
    WHERE status = 'active';

    SELECT COUNT(*)
    INTO v_sections
    FROM knowledge.clinical_section
    WHERE status = 'active';

    SELECT COUNT(*)
    INTO v_rules
    FROM knowledge.format_context_rule
    WHERE status = 'active';

    SELECT COUNT(*)
    INTO v_stages
    FROM knowledge.clinical_workflow_stage
    WHERE status = 'active';

    IF v_formats = 0 THEN
        RAISE EXCEPTION
            'AMEXAN Universal Clinical OS validation failed: no active clinical formats.';
    END IF;

    IF v_sections = 0 THEN
        RAISE EXCEPTION
            'AMEXAN Universal Clinical OS validation failed: no active clinical sections.';
    END IF;

    IF v_stages = 0 THEN
        RAISE EXCEPTION
            'AMEXAN Universal Clinical OS validation failed: no workflow stages.';
    END IF;

    RAISE NOTICE
        'AMEXAN Universal Clinical OS ready: % formats, % sections, % active format rules, % workflow stages.',
        v_formats,
        v_sections,
        v_rules,
        v_stages;
END
$universal_clinical_os$;


-- =============================================================================
-- 59. CANONICAL AGE-BAND INVARIANT
-- =============================================================================
--
-- Canonical age interpretation used by the CPU.
-- No duplicate age-band catalogue is created here.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_age_band(
    p_age_days integer
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN

    IF p_age_days IS NULL OR p_age_days < 0 THEN
        RETURN NULL;
    END IF;

    IF p_age_days <= 27 THEN
        RETURN 'NEONATE';

    ELSIF p_age_days < 365 THEN
        RETURN 'INFANT';

    ELSIF p_age_days < 4380 THEN
        RETURN 'CHILD';

    ELSIF p_age_days < 6570 THEN
        RETURN 'ADOLESCENT';

    ELSE
        RETURN 'ADULT';
    END IF;

END;
$$;


-- =============================================================================
-- 60. UNIVERSAL CONTEXT VECTOR BUILDER
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.build_clinical_context_vector(
    p_age_days integer,
    p_sex text,
    p_pregnancy_status text,
    p_department text,
    p_service text,
    p_encounter_type text,
    p_symptom_domain text,
    p_care_setting text,
    p_urgency text
)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
SELECT jsonb_strip_nulls(
    jsonb_build_object(
        'AGE_BAND',
        knowledge.resolve_age_band(p_age_days),

        'SEX',
        upper(NULLIF(p_sex,'')),

        'PREGNANCY',
        upper(NULLIF(p_pregnancy_status,'')),

        'DEPARTMENT',
        upper(NULLIF(p_department,'')),

        'SERVICE',
        upper(NULLIF(p_service,'')),

        'ENCOUNTER_TYPE',
        upper(NULLIF(p_encounter_type,'')),

        'SYMPTOM_DOMAIN',
        upper(NULLIF(p_symptom_domain,'')),

        'CARE_SETTING',
        upper(NULLIF(p_care_setting,'')),

        'URGENCY',
        upper(NULLIF(p_urgency,''))
    )
);
$$;


-- =============================================================================
-- 61. UNIVERSAL ENTRY FUNCTION
-- =============================================================================
--
-- One CPU entry point:
--
-- patient context
--      ↓
-- context vector
--      ↓
-- format resolution
--      ↓
-- section resolution
--      ↓
-- workspace projection
--
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_universal_clinical_entry(
    p_age_days integer,
    p_sex text,
    p_pregnancy_status text,
    p_department text,
    p_service text,
    p_encounter_type text,
    p_symptom_domain text,
    p_care_setting text,
    p_urgency text
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
WITH context AS (
    SELECT knowledge.build_clinical_context_vector(
        p_age_days,
        p_sex,
        p_pregnancy_status,
        p_department,
        p_service,
        p_encounter_type,
        p_symptom_domain,
        p_care_setting,
        p_urgency
    ) AS context_vector
)
SELECT knowledge.compile_universal_workspace(
    context_vector
)
FROM context;
$$;


-- =============================================================================
-- 62. FINAL RESULT
-- =============================================================================

SELECT
    'AMEXAN UNIVERSAL CLINICAL OPERATING SYSTEM READY' AS status,
    (
        SELECT COUNT(*)
        FROM knowledge.clinical_format
        WHERE status = 'active'
    ) AS active_formats,
    (
        SELECT COUNT(*)
        FROM knowledge.clinical_section
        WHERE status = 'active'
    ) AS clinical_sections,
    (
        SELECT COUNT(*)
        FROM knowledge.format_context_rule
        WHERE status = 'active'
    ) AS format_rules,
    (
        SELECT COUNT(*)
        FROM knowledge.section_context_rule
        WHERE status = 'active'
    ) AS section_rules,
    (
        SELECT COUNT(*)
        FROM knowledge.clinical_workflow_stage
        WHERE status = 'active'
    ) AS workflow_stages;