-- =============================================================================
-- AMEXAN CLINICAL OS
-- postgres/041_universal_fact_definitions.sql
--
-- UNIVERSAL CLINICAL CAPTURE â€” COMPLETE MEDICINE FACT VOCABULARY
--
-- PURPOSE
-- -------
-- This migration establishes the canonical fact vocabulary consumed by:
--
--   FactIngestionEngine
--   QuestionEngine
--   ContextResolver
--   HPIEngine
--   ExaminationEngine
--   InvestigationEngine
--   DifferentialEngine
--   SeverityScoreEngine
--   ProtocolEngine
--   MedicationEngine
--   PrescriptionEngine
--   MonitoringEngine
--   DocumentationEngine
--   SafetyEngine
--   ProvenanceEngine
--   ClinicalSnapshotEngine
--
-- ARCHITECTURAL LAW
-- -----------------
-- Disease is NEVER the starting point of capture.
-- The patient/context -> complaint/symptom -> history -> examination ->
-- investigations -> phenotype -> mechanism -> differential -> diagnosis ->
-- severity -> protocol -> treatment -> monitoring -> documentation chain
-- is preserved.
--
-- A FACT IS A FACTUAL OBSERVATION / PATIENT REPORT / MEASURED VALUE.
-- A FACT IS NOT A DIAGNOSIS.
-- A FACT IS NOT A CLINICIAN'S HIDDEN INFERENCE.
-- A FACT IS NOT A PROTOCOL.
-- A FACT IS NOT A GENERATED SENTENCE.
--
-- The clinical.fact_definition registry is the canonical source of fact codes.
-- Every captured fact must resolve to one of these definitions before it can
-- enter the canonical clinical fact layer.
--
-- IMPORTANT:
--   This migration is idempotent.
--   Existing definitions are preserved.
--   ON CONFLICT DO NOTHING is intentional.
--
-- =============================================================================


-- =============================================================================
-- 0. SCHEMA COMPATIBILITY
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS clinical;


-- =============================================================================
-- 1. CANONICAL FACT DEFINITION TABLE
-- =============================================================================

-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS clinical.fact_definition CASCADE;
CREATE TABLE IF NOT EXISTS clinical.fact_definition (
    code            TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    description     TEXT,
    data_type       TEXT NOT NULL
                    CHECK (
                        data_type IN (
                            'text',
                            'numeric',
                            'boolean',
                            'date',
                            'datetime',
                            'coded',
                            'json',
                            'quantity'
                        )
                    ),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE INDEX IF NOT EXISTS idx_fact_definition_active
    ON clinical.fact_definition(is_active);


-- =============================================================================
-- 2. CORE PATIENT / CONTEXT
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PATIENT_ID',
 'Patient identifier',
 'Canonical patient identifier associated with the clinical fact.',
 'text', true),

('ENCOUNTER_ID',
 'Encounter identifier',
 'Clinical encounter to which the fact belongs.',
 'text', true),

('SEX',
 'Sex',
 'Biologically defined sex of the patient.',
 'coded', true),

('AGE_YEARS',
 'Age in years',
 'Age of the patient in completed years.',
 'numeric', true),

('AGE_MONTHS',
 'Age in months',
 'Age of the patient in completed months.',
 'numeric', true),

('AGE_DAYS',
 'Age in days',
 'Age of the patient in completed days.',
 'numeric', true),

('DATE_OF_BIRTH',
 'Date of birth',
 'Date of birth used to calculate age and life stage.',
 'date', true),

('LIFE_STAGE',
 'Life stage',
 'Canonical clinical life-stage classification.',
 'coded', true),

('DEPARTMENT',
 'Department',
 'Clinical department/service responsible for the encounter.',
 'coded', true),

('ENCOUNTER_TYPE',
 'Encounter type',
 'Type of clinical encounter.',
 'coded', true),

('CARE_SETTING',
 'Care setting',
 'Location or level at which care is delivered.',
 'coded', true),

('PRESENTING_COMPLAINT',
 'Presenting complaint',
 'Principal reason for seeking care, preferably captured in the patient or caregiver words.',
 'text', true),

('CHIEF_COMPLAINT',
 'Chief complaint',
 'Canonical chief complaint selected from the presenting problem.',
 'coded', true),

('HISTORY_SOURCE',
 'History source',
 'Person or source providing the clinical history.',
 'coded', true),

('HISTORY_RELIABILITY',
 'History reliability',
 'Clinician assessment of reliability of the history source.',
 'coded', true),

('COLLATERAL_AVAILABLE',
 'Collateral available',
 'Whether collateral history is available.',
 'boolean', true),

('COLLATERAL_SOURCE',
 'Collateral source',
 'Person or source providing collateral information.',
 'text', true),

('ACUTE_DETERIORATION',
 'Acute deterioration',
 'Whether acute deterioration from baseline has occurred.',
 'boolean', true),

('LAST_KNOWN_BASELINE',
 'Last known baseline',
 'Last known clinical or functional baseline.',
 'text', true),

('FUNCTIONAL_BASELINE',
 'Functional baseline',
 'Usual mobility, activity, cognition and independence before the current illness.',
 'text', true),

('CURRENT_FUNCTIONAL_STATUS',
 'Current functional status',
 'Current ability to perform usual activities.',
 'text', true),

('SYMPTOM_DOMAIN',
 'Symptom domain',
 'Clinical symptom/system domain associated with the presenting complaint.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 3. SYMPTOM CHARACTERIZATION â€” UNIVERSAL SOCRATES / HPI
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('SYMPTOM_ONSET',
 'Symptom onset',
 'Whether onset was sudden, gradual, insidious or otherwise characterized.',
 'coded', true),

('SYMPTOM_ONSET_DATE',
 'Symptom onset date',
 'Calendar date on which the symptom began.',
 'date', true),

('SYMPTOM_ONSET_DATETIME',
 'Symptom onset date and time',
 'Date and time of symptom onset where clinically relevant.',
 'datetime', true),

('SYMPTOM_DURATION',
 'Symptom duration',
 'Duration of the symptom.',
 'quantity', true),

('SYMPTOM_COURSE',
 'Symptom course',
 'Evolution of the symptom over time.',
 'coded', true),

('SYMPTOM_PATTERN',
 'Symptom pattern',
 'Temporal pattern such as intermittent, continuous, episodic or recurrent.',
 'coded', true),

('SYMPTOM_FREQUENCY',
 'Symptom frequency',
 'Frequency with which the symptom occurs.',
 'quantity', true),

('SYMPTOM_SEVERITY',
 'Symptom severity',
 'Patient or caregiver reported severity.',
 'coded', true),

('SYMPTOM_SEVERITY_SCORE',
 'Symptom severity score',
 'Numerical severity rating associated with a symptom.',
 'numeric', true),

('SYMPTOM_CHARACTER',
 'Symptom character',
 'Qualitative character of the symptom.',
 'text', true),

('SYMPTOM_SITE',
 'Symptom site',
 'Anatomical site of the symptom.',
 'coded', true),

('SYMPTOM_LATERALITY',
 'Symptom laterality',
 'Right, left, bilateral, midline or non-lateralized.',
 'coded', true),

('SYMPTOM_RADIATION',
 'Symptom radiation',
 'Radiation or spread of a symptom from its primary site.',
 'text', true),

('SYMPTOM_TRIGGER',
 'Symptom trigger',
 'Known precipitating or triggering factor.',
 'text', true),

('SYMPTOM_AGGRAVATING_FACTORS',
 'Aggravating factors',
 'Factors that make the symptom worse.',
 'text', true),

('SYMPTOM_RELIEVING_FACTORS',
 'Relieving factors',
 'Factors that improve the symptom.',
 'text', true),

('SYMPTOM_FUNCTIONAL_IMPACT',
 'Symptom functional impact',
 'Effect of the symptom on daily activities, mobility, work, feeding or sleep.',
 'coded', true),

('SYMPTOM_SLEEP_IMPACT',
 'Sleep impact',
 'Effect of the symptom on sleep.',
 'boolean', true),

('SYMPTOM_FEEDING_IMPACT',
 'Feeding impact',
 'Effect of the symptom on feeding or oral intake.',
 'boolean', true),

('SYMPTOM_ACTIVITY_IMPACT',
 'Activity impact',
 'Effect of the symptom on usual activity.',
 'boolean', true),

('SIMILAR_PRIOR_EPISODES',
 'Similar prior episodes',
 'Whether a similar episode has occurred previously.',
 'boolean', true),

('NUMBER_OF_PRIOR_EPISODES',
 'Number of prior episodes',
 'Number of previous similar episodes.',
 'numeric', true),

('ASSOCIATED_SYMPTOMS',
 'Associated symptoms',
 'Other symptoms accompanying the presenting complaint.',
 'text', true),

('NEGATIVE_ASSOCIATED_SYMPTOMS',
 'Relevant absent associated symptoms',
 'Explicitly denied associated symptoms relevant to the clinical problem.',
 'text', true),

('SYMPTOM_RESOLUTION',
 'Symptom resolution',
 'Whether the symptom has resolved.',
 'boolean', true),

('SYMPTOM_RECURRENCE',
 'Symptom recurrence',
 'Whether the symptom recurs after resolution.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 4. GENERAL SYSTEMIC SYMPTOMS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('FEVER_PRESENT',
 'Fever present',
 'Presence of fever by history or measurement.',
 'boolean', true),

('FEVER_DURATION',
 'Fever duration',
 'Duration of fever.',
 'quantity', true),

('FEVER_PATTERN',
 'Fever pattern',
 'Pattern of fever over time.',
 'coded', true),

('FEVER_MAXIMUM_RECORDED',
 'Maximum recorded temperature',
 'Highest recorded temperature associated with the illness.',
 'quantity', true),

('CHILLS_PRESENT',
 'Chills present',
 'Presence of chills.',
 'boolean', true),

('RIGORS_PRESENT',
 'Rigors present',
 'Presence of rigors.',
 'boolean', true),

('NIGHT_SWEATS',
 'Night sweats',
 'Presence of night sweats.',
 'boolean', true),

('FATIGUE_PRESENT',
 'Fatigue',
 'Presence of fatigue.',
 'boolean', true),

('MALAISE_PRESENT',
 'Malaise',
 'Presence of malaise.',
 'boolean', true),

('WEIGHT_CHANGE_PRESENT',
 'Weight change',
 'Presence of clinically relevant weight change.',
 'boolean', true),

('WEIGHT_LOSS',
 'Weight loss',
 'Reported or measured weight loss.',
 'quantity', true),

('WEIGHT_GAIN',
 'Weight gain',
 'Reported or measured weight gain.',
 'quantity', true),

('APPETITE_CHANGE',
 'Appetite change',
 'Change in appetite.',
 'coded', true),

('DEHYDRATION_SYMPTOMS',
 'Dehydration symptoms',
 'Symptoms suggestive of dehydration.',
 'text', true),

('PAIN_PRESENT',
 'Pain present',
 'Presence of pain.',
 'boolean', true),

('GENERALIZED_WEAKNESS',
 'Generalized weakness',
 'Generalized weakness or loss of strength.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 5. RESPIRATORY HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('COUGH_PRESENT',
 'Cough present',
 'Presence of cough.',
 'boolean', true),

('COUGH_DURATION',
 'Cough duration',
 'Duration of cough.',
 'quantity', true),

('COUGH_CHARACTER',
 'Cough character',
 'Dry, productive, barking, paroxysmal or other cough character.',
 'coded', true),

('COUGH_PRODUCTIVE',
 'Productive cough',
 'Whether cough produces sputum.',
 'boolean', true),

('SPUTUM_PRESENT',
 'Sputum present',
 'Presence of sputum production.',
 'boolean', true),

('SPUTUM_COLOUR',
 'Sputum colour',
 'Colour of sputum.',
 'coded', true),

('SPUTUM_VOLUME',
 'Sputum volume',
 'Approximate sputum volume.',
 'quantity', true),

('HEMOPTYSIS_PRESENT',
 'Hemoptysis',
 'Presence of blood in sputum.',
 'boolean', true),

('HEMOPTYSIS_VOLUME',
 'Hemoptysis volume',
 'Estimated quantity of blood expectorated.',
 'quantity', true),

('DYSPNEA_PRESENT',
 'Dyspnea',
 'Subjective breathing difficulty.',
 'boolean', true),

('DYSPNEA_AT_REST',
 'Dyspnea at rest',
 'Breathlessness occurring at rest.',
 'boolean', true),

('DYSPNEA_ON_EXERTION',
 'Dyspnea on exertion',
 'Breathlessness occurring with exertion.',
 'boolean', true),

('ORTHOPNEA',
 'Orthopnea',
 'Breathlessness when lying flat.',
 'boolean', true),

('PND',
 'Paroxysmal nocturnal dyspnea',
 'Episodes of nocturnal breathlessness causing awakening.',
 'boolean', true),

('WHEEZE_PRESENT',
 'Wheeze',
 'Wheezing reported by patient/caregiver.',
 'boolean', true),

('STRIDOR_PRESENT',
 'Stridor',
 'Noisy upper-airway breathing consistent with stridor.',
 'boolean', true),

('PLEURITIC_CHEST_PAIN',
 'Pleuritic chest pain',
 'Chest pain associated with respiration.',
 'boolean', true),

('CYANOSIS_REPORTED',
 'Cyanosis reported',
 'Cyanosis reported by patient/caregiver.',
 'boolean', true),

('APNOEA_PRESENT',
 'Apnoea',
 'Observed or reported pauses in breathing.',
 'boolean', true),

('NASAL_CONGESTION',
 'Nasal congestion',
 'Nasal obstruction or congestion.',
 'boolean', true),

('RHINORRHEA',
 'Rhinorrhea',
 'Nasal discharge.',
 'boolean', true),

('SORE_THROAT',
 'Sore throat',
 'Throat pain or discomfort.',
 'boolean', true),

('HOARSENESS',
 'Hoarseness',
 'Change in voice quality.',
 'boolean', true),

('GRUNTING_PRESENT',
 'Grunting',
 'Expiratory grunting.',
 'boolean', true),

('NASAL_FLARING',
 'Nasal flaring',
 'Visible nasal flaring associated with respiratory effort.',
 'boolean', true),

('BREATHING_DIFFICULTY',
 'Breathing difficulty',
 'Laboured or difficult breathing.',
 'boolean', true),

('BREATHING_AFFECTING_FEEDING',
 'Breathing affecting feeding',
 'Respiratory difficulty interfering with feeding.',
 'boolean', true),

('RESPIRATORY_CONTACT',
 'Respiratory contact',
 'Recent contact with a person with respiratory illness.',
 'boolean', true),

('TB_CONTACT',
 'Tuberculosis contact',
 'Known or suspected exposure to tuberculosis.',
 'boolean', true),

('TB_PREVIOUS_HISTORY',
 'Previous tuberculosis',
 'Previous history of tuberculosis.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 6. CARDIOVASCULAR HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PALPITATIONS_PRESENT',
 'Palpitations',
 'Awareness of heartbeat.',
 'boolean', true),

('SYNCOPE_PRESENT',
 'Syncope',
 'Transient loss of consciousness.',
 'boolean', true),

('PRESYNCOPE_PRESENT',
 'Presyncope',
 'Near-fainting or impending loss of consciousness.',
 'boolean', true),

('EXERCISE_TOLERANCE',
 'Exercise tolerance',
 'Usual or current exercise tolerance.',
 'coded', true),

('LEG_SWELLING',
 'Leg swelling',
 'Presence of peripheral oedema/swelling.',
 'boolean', true),

('PND_PRESENT',
 'Paroxysmal nocturnal dyspnea',
 'Nocturnal breathlessness suggestive of cardiac congestion.',
 'boolean', true),

('KNOWN_HYPERTENSION',
 'Known hypertension',
 'History of diagnosed hypertension.',
 'boolean', true),

('KNOWN_HEART_DISEASE',
 'Known heart disease',
 'Known cardiovascular disease.',
 'boolean', true),

('KNOWN_HEART_FAILURE',
 'Known heart failure',
 'Known heart failure.',
 'boolean', true),

('KNOWN_ARRHYTHMIA',
 'Known arrhythmia',
 'Known cardiac rhythm disorder.',
 'boolean', true),

('RHEUMATIC_HEART_DISEASE',
 'Rheumatic heart disease',
 'Known rheumatic heart disease.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 7. GASTROINTESTINAL HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('NAUSEA_PRESENT',
 'Nausea',
 'Presence of nausea.',
 'boolean', true),

('VOMITING_PRESENT',
 'Vomiting',
 'Presence of vomiting.',
 'boolean', true),

('VOMITING_DURATION',
 'Vomiting duration',
 'Duration of vomiting.',
 'quantity', true),

('VOMITING_FREQUENCY',
 'Vomiting frequency',
 'Number of vomiting episodes over a defined period.',
 'quantity', true),

('VOMITING_CHARACTER',
 'Vomiting character',
 'Description of vomitus.',
 'coded', true),

('BILIOUS_VOMITING',
 'Bilious vomiting',
 'Green/bilious vomitus.',
 'boolean', true),

('HEMATEMESIS',
 'Hematemesis',
 'Vomiting blood.',
 'boolean', true),

('DIARRHEA_PRESENT',
 'Diarrhea',
 'Presence of diarrhea.',
 'boolean', true),

('DIARRHEA_DURATION',
 'Diarrhea duration',
 'Duration of diarrhea.',
 'quantity', true),

('STOOL_FREQUENCY',
 'Stool frequency',
 'Frequency of stools.',
 'quantity', true),

('STOOL_CHARACTER',
 'Stool character',
 'Character of stool.',
 'coded', true),

('BLOOD_IN_STOOL',
 'Blood in stool',
 'Visible blood in stool.',
 'boolean', true),

('MELENA',
 'Melena',
 'Black tarry stool.',
 'boolean', true),

('ABDOMINAL_PAIN_PRESENT',
 'Abdominal pain',
 'Presence of abdominal pain.',
 'boolean', true),

('ABDOMINAL_DISTENSION',
 'Abdominal distension',
 'Abdominal distension.',
 'boolean', true),

('CONSTIPATION_PRESENT',
 'Constipation',
 'Presence of constipation.',
 'boolean', true),

('JAUNDICE_REPORTED',
 'Jaundice reported',
 'Patient or caregiver reported yellow discoloration.',
 'boolean', true),

('DYSPHAGIA',
 'Dysphagia',
 'Difficulty swallowing.',
 'boolean', true),

('ODYNOPHAGIA',
 'Odynophagia',
 'Painful swallowing.',
 'boolean', true),

('REFLUX_SYMPTOMS',
 'Reflux symptoms',
 'Symptoms suggestive of gastroesophageal reflux.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 8. GENITOURINARY HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('DYSURIA',
 'Dysuria',
 'Pain or burning on urination.',
 'boolean', true),

('URINARY_FREQUENCY',
 'Urinary frequency',
 'Increased urinary frequency.',
 'boolean', true),

('URINARY_URGENCY',
 'Urinary urgency',
 'Urgent need to urinate.',
 'boolean', true),

('NOCTURIA',
 'Nocturia',
 'Night-time urination.',
 'boolean', true),

('HEMATURIA_REPORTED',
 'Hematuria reported',
 'Visible blood in urine.',
 'boolean', true),

('URINARY_RETENTION',
 'Urinary retention',
 'Difficulty or inability to pass urine.',
 'boolean', true),

('URINARY_INCONTINENCE',
 'Urinary incontinence',
 'Involuntary urinary leakage.',
 'boolean', true),

('URINE_OUTPUT_REDUCED',
 'Reduced urine output',
 'Reported reduction in urine output.',
 'boolean', true),

('URINE_OUTPUT',
 'Urine output',
 'Measured urine output.',
 'quantity', true),

('FLANK_PAIN',
 'Flank pain',
 'Pain in flank region.',
 'boolean', true),

('VAGINAL_DISCHARGE',
 'Vaginal discharge',
 'Presence of vaginal discharge.',
 'boolean', true),

('VAGINAL_BLEEDING',
 'Vaginal bleeding',
 'Abnormal vaginal bleeding.',
 'boolean', true),

('VAGINAL_PRURITUS',
 'Vaginal pruritus',
 'Vaginal itching.',
 'boolean', true),

('PENILE_DISCHARGE',
 'Penile discharge',
 'Urethral/penile discharge.',
 'boolean', true),

('SCROTAL_PAIN',
 'Scrotal pain',
 'Scrotal pain.',
 'boolean', true),

('SCROTAL_SWELLING',
 'Scrotal swelling',
 'Scrotal swelling.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 9. NEUROLOGICAL HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('HEADACHE_PRESENT',
 'Headache',
 'Presence of headache.',
 'boolean', true),

('HEADACHE_SUDDEN_ONSET',
 'Sudden-onset headache',
 'Abrupt onset of headache.',
 'boolean', true),

('SEIZURE_PRESENT',
 'Seizure',
 'Observed or reported seizure activity.',
 'boolean', true),

('SEIZURE_DURATION',
 'Seizure duration',
 'Duration of seizure.',
 'quantity', true),

('SEIZURE_FREQUENCY',
 'Seizure frequency',
 'Frequency of seizures.',
 'quantity', true),

('SEIZURE_TYPE',
 'Seizure type',
 'Clinical description/classification of seizure.',
 'coded', true),

('LOSS_OF_CONSCIOUSNESS',
 'Loss of consciousness',
 'Transient or sustained loss of consciousness.',
 'boolean', true),

('CONFUSION_PRESENT',
 'Confusion',
 'Acute or chronic confusion.',
 'boolean', true),

('ALTERED_MENTAL_STATUS',
 'Altered mental status',
 'Altered cognition, awareness or behaviour.',
 'boolean', true),

('FOCAL_WEAKNESS',
 'Focal weakness',
 'Weakness affecting a specific body region.',
 'boolean', true),

('GENERALIZED_WEAKNESS',
 'Generalized weakness',
 'Generalized weakness.',
 'boolean', true),

('NUMBNESS',
 'Numbness',
 'Reduced or absent sensation.',
 'boolean', true),

('PARESTHESIA',
 'Paresthesia',
 'Abnormal sensation such as tingling or pins and needles.',
 'boolean', true),

('VISUAL_DISTURBANCE',
 'Visual disturbance',
 'Change in vision.',
 'boolean', true),

('DIPLOPIA',
 'Diplopia',
 'Double vision.',
 'boolean', true),

('DIZZINESS',
 'Dizziness',
 'Subjective dizziness.',
 'boolean', true),

('VERTIGO',
 'Vertigo',
 'Illusion of movement or spinning.',
 'boolean', true),

('ATAXIA',
 'Ataxia',
 'Impaired coordination or gait.',
 'boolean', true),

('SPEECH_DISTURBANCE',
 'Speech disturbance',
 'Difficulty speaking or understanding speech.',
 'boolean', true),

('MEMORY_CHANGE',
 'Memory change',
 'Change in memory.',
 'boolean', true),

('BEHAVIOUR_CHANGE',
 'Behaviour change',
 'Change in behaviour.',
 'boolean', true),

('PHOTOPHOBIA',
 'Photophobia',
 'Light sensitivity.',
 'boolean', true),

('NECK_STIFFNESS',
 'Neck stiffness',
 'Neck stiffness or reduced movement.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 10. MUSCULOSKELETAL HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('JOINT_PAIN',
 'Joint pain',
 'Pain arising from a joint.',
 'boolean', true),

('JOINT_SWELLING',
 'Joint swelling',
 'Joint swelling.',
 'boolean', true),

('JOINT_STIFFNESS',
 'Joint stiffness',
 'Joint stiffness.',
 'boolean', true),

('MORNING_STIFFNESS',
 'Morning stiffness',
 'Stiffness occurring after waking.',
 'boolean', true),

('BACK_PAIN',
 'Back pain',
 'Back pain.',
 'boolean', true),

('NECK_PAIN',
 'Neck pain',
 'Neck pain.',
 'boolean', true),

('MUSCLE_PAIN',
 'Muscle pain',
 'Myalgia.',
 'boolean', true),

('TRAUMA_HISTORY',
 'Trauma history',
 'History of trauma preceding the presentation.',
 'boolean', true),

('FALL_HISTORY',
 'Fall history',
 'History of a fall.',
 'boolean', true),

('LIMB_DEFORMITY_REPORTED',
 'Limb deformity reported',
 'Reported deformity of a limb.',
 'boolean', true),

('LIMITED_RANGE_OF_MOTION',
 'Limited range of motion',
 'Reduced joint range of movement.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 11. DERMATOLOGICAL HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('RASH_PRESENT',
 'Rash',
 'Presence of a rash.',
 'boolean', true),

('RASH_ONSET',
 'Rash onset',
 'Time/course of rash onset.',
 'quantity', true),

('RASH_DISTRIBUTION',
 'Rash distribution',
 'Anatomical distribution of rash.',
 'text', true),

('RASH_CHARACTER',
 'Rash character',
 'Morphology/character of rash.',
 'text', true),

('PRURITUS',
 'Pruritus',
 'Itching.',
 'boolean', true),

('SKIN_PAIN',
 'Skin pain',
 'Pain involving the skin.',
 'boolean', true),

('SKIN_COLOUR_CHANGE',
 'Skin colour change',
 'Change in skin colour.',
 'boolean', true),

('ULCER_PRESENT',
 'Ulcer',
 'Presence of ulceration.',
 'boolean', true),

('WOUND_PRESENT',
 'Wound',
 'Presence of a wound.',
 'boolean', true),

('DISCHARGE_FROM_WOUND',
 'Wound discharge',
 'Discharge from wound.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 12. EYE / ENT
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('EYE_PAIN',
 'Eye pain',
 'Pain in or around the eye.',
 'boolean', true),

('RED_EYE',
 'Red eye',
 'Conjunctival or ocular redness.',
 'boolean', true),

('EYE_DISCHARGE',
 'Eye discharge',
 'Ocular discharge.',
 'boolean', true),

('VISION_LOSS',
 'Vision loss',
 'Loss of vision.',
 'boolean', true),

('HEARING_LOSS',
 'Hearing loss',
 'Reduced hearing.',
 'boolean', true),

('EAR_PAIN',
 'Ear pain',
 'Otalgia.',
 'boolean', true),

('EAR_DISCHARGE',
 'Ear discharge',
 'Otorrhea.',
 'boolean', true),

('TINNITUS',
 'Tinnitus',
 'Perception of ringing/noise without external source.',
 'boolean', true),

('NASAL_BLEEDING',
 'Nasal bleeding',
 'Epistaxis.',
 'boolean', true),

('FACIAL_PAIN',
 'Facial pain',
 'Facial or sinus-region pain.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 13. PAST MEDICAL HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PAST_MEDICAL_HISTORY_PRESENT',
 'Past medical history present',
 'Whether relevant past medical history exists.',
 'boolean', true),

('CHRONIC_CONDITIONS',
 'Chronic conditions',
 'Long-term medical conditions.',
 'text', true),

('PREVIOUS_HOSPITALIZATION',
 'Previous hospitalization',
 'Previous hospital admission.',
 'boolean', true),

('PREVIOUS_ICU_ADMISSION',
 'Previous ICU admission',
 'Previous admission to intensive care.',
 'boolean', true),

('PREVIOUS_TRANSFUSION',
 'Previous blood transfusion',
 'History of blood transfusion.',
 'boolean', true),

('PAST_SURGERY_PRESENT',
 'Past surgery present',
 'History of previous surgery.',
 'boolean', true),

('PAST_SURGERIES',
 'Past surgeries',
 'Previous surgical procedures.',
 'text', true),

('PREVIOUS_ANESTHESIA',
 'Previous anesthesia',
 'History of anesthesia exposure.',
 'boolean', true),

('PREVIOUS_COMPLICATIONS',
 'Previous complications',
 'Previous significant treatment or disease complications.',
 'text', true),

('KNOWN_DIABETES',
 'Known diabetes',
 'Known diabetes mellitus.',
 'boolean', true),

('KNOWN_HYPERTENSION',
 'Known hypertension',
 'Known hypertension.',
 'boolean', true),

('KNOWN_KIDNEY_DISEASE',
 'Known kidney disease',
 'Known renal disease.',
 'boolean', true),

('KNOWN_LIVER_DISEASE',
 'Known liver disease',
 'Known hepatic disease.',
 'boolean', true),

('KNOWN_ASTHMA',
 'Known asthma',
 'Known asthma.',
 'boolean', true),

('KNOWN_COPD',
 'Known COPD',
 'Known chronic obstructive pulmonary disease.',
 'boolean', true),

('KNOWN_EPILEPSY',
 'Known epilepsy',
 'Known epilepsy.',
 'boolean', true),

('KNOWN_HIV',
 'Known HIV',
 'Known HIV infection.',
 'boolean', true),

('KNOWN_TB',
 'Known tuberculosis',
 'Known or previous tuberculosis.',
 'boolean', true),

('KNOWN_CANCER',
 'Known cancer',
 'Known malignancy.',
 'boolean', true),

('IMMUNOSUPPRESSION',
 'Immunosuppression',
 'Known clinically relevant immunosuppression.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 14. MEDICATION HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('CURRENT_MEDICATION_PRESENT',
 'Current medication present',
 'Whether the patient currently takes medication.',
 'boolean', true),

('CURRENT_MEDICATIONS',
 'Current medications',
 'Current medications including dose/frequency where available.',
 'text', true),

('RECENT_TREATMENT',
 'Recent treatment',
 'Treatment already received for the current problem.',
 'text', true),

('RECENT_ANTIBIOTIC_USE',
 'Recent antibiotic use',
 'Antibiotic exposure within the clinically relevant period.',
 'boolean', true),

('RECENT_STEROID_USE',
 'Recent steroid use',
 'Recent corticosteroid exposure.',
 'boolean', true),

('ADHERENCE',
 'Medication adherence',
 'Reported adherence to prescribed therapy.',
 'coded', true),

('MISSED_DOSES',
 'Missed medication doses',
 'Number or pattern of missed doses.',
 'quantity', true),

('TREATMENT_RESPONSE',
 'Treatment response',
 'Response to treatment already received.',
 'coded', true),

('ADVERSE_DRUG_REACTION_HISTORY',
 'Previous adverse drug reaction',
 'History of clinically significant adverse drug reaction.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 15. ALLERGY / SAFETY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('ALLERGY_PRESENT',
 'Allergy present',
 'Whether the patient has a known allergy.',
 'boolean', true),

('ALLERGY_DETAILS',
 'Allergy details',
 'Allergen and reaction details.',
 'text', true),

('DRUG_ALLERGY_PRESENT',
 'Drug allergy present',
 'Known drug allergy.',
 'boolean', true),

('DRUG_ALLERGY_AGENT',
 'Drug allergy agent',
 'Medication associated with allergy.',
 'coded', true),

('DRUG_ALLERGY_REACTION',
 'Drug allergy reaction',
 'Reaction associated with drug allergy.',
 'coded', true),

('ANAPHYLAXIS_HISTORY',
 'Anaphylaxis history',
 'Previous anaphylaxis.',
 'boolean', true),

('FOOD_ALLERGY_PRESENT',
 'Food allergy',
 'Known food allergy.',
 'boolean', true),

('LATEX_ALLERGY',
 'Latex allergy',
 'Known latex allergy.',
 'boolean', true),

('CONTRAINDICATION_PRESENT',
 'Contraindication present',
 'Known clinical contraindication relevant to planned therapy.',
 'boolean', true),

('SAFETY_ALERT_PRESENT',
 'Safety alert present',
 'Clinical safety alert affecting care.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 16. FAMILY HISTORY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('FAMILY_HISTORY_PRESENT',
 'Family history present',
 'Relevant family history exists.',
 'boolean', true),

('FAMILY_HISTORY_DETAILS',
 'Family history details',
 'Relevant familial illnesses and relationships.',
 'text', true),

('FAMILY_HISTORY_PREMATURE_DEATH',
 'Family history of premature death',
 'Premature death in close relatives.',
 'boolean', true),

('FAMILY_HISTORY_CARDIOVASCULAR',
 'Family cardiovascular history',
 'Relevant cardiovascular family history.',
 'boolean', true),

('FAMILY_HISTORY_CANCER',
 'Family cancer history',
 'Relevant cancer family history.',
 'boolean', true),

('FAMILY_HISTORY_DIABETES',
 'Family diabetes history',
 'Relevant family history of diabetes.',
 'boolean', true),

('FAMILY_HISTORY_HYPERTENSION',
 'Family hypertension history',
 'Relevant family history of hypertension.',
 'boolean', true),

('FAMILY_HISTORY_GENETIC_DISEASE',
 'Family genetic disease history',
 'Known familial genetic disorder.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 17. SOCIAL / LIVING / OCCUPATIONAL
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('LIVING_SITUATION',
 'Living situation',
 'Patient living circumstances.',
 'text', true),

('HOUSEHOLD_SIZE',
 'Household size',
 'Number of people living in the household.',
 'numeric', true),

('SOCIAL_SUPPORT',
 'Social support',
 'Available family/community/social support.',
 'text', true),

('CAREGIVER_AVAILABLE',
 'Caregiver available',
 'Whether an appropriate caregiver is available.',
 'boolean', true),

('OCCUPATION',
 'Occupation',
 'Patient occupation.',
 'text', true),

('OCCUPATIONAL_EXPOSURES',
 'Occupational exposures',
 'Relevant workplace exposures.',
 'text', true),

('SMOKING_STATUS',
 'Smoking status',
 'Current/past/never smoking status.',
 'coded', true),

('SMOKING_PACK_YEARS',
 'Smoking pack-years',
 'Cumulative cigarette exposure.',
 'numeric', true),

('SECONDHAND_SMOKE_EXPOSURE',
 'Secondhand smoke exposure',
 'Exposure to environmental tobacco smoke.',
 'boolean', true),

('ALCOHOL_USE',
 'Alcohol use',
 'Alcohol consumption pattern.',
 'coded', true),

('ALCOHOL_QUANTITY',
 'Alcohol quantity',
 'Quantity/frequency of alcohol consumption.',
 'quantity', true),

('SUBSTANCE_USE_PRESENT',
 'Substance use present',
 'Use of alcohol, tobacco or other psychoactive substances.',
 'boolean', true),

('SUBSTANCE_USE_DETAILS',
 'Substance use details',
 'Substance, quantity, frequency and duration where relevant.',
 'text', true),

('DOMESTIC_VIOLENCE_CONCERN',
 'Domestic violence concern',
 'Concern for domestic violence or abuse.',
 'boolean', true),

('FOOD_SECURITY',
 'Food security',
 'Availability and reliability of adequate food.',
 'coded', true),

('HOUSING_SECURITY',
 'Housing security',
 'Stability and safety of housing.',
 'coded', true),

('TRAVEL_HISTORY',
 'Travel history',
 'Recent travel relevant to the presentation.',
 'text', true),

('IMMIGRATION_EXPOSURE',
 'Migration exposure',
 'Recent migration/travel exposure relevant to disease risk.',
 'text', true),

('ANIMAL_EXPOSURE',
 'Animal exposure',
 'Relevant animal contact/exposure.',
 'text', true),

('VECTOR_EXPOSURE',
 'Vector exposure',
 'Relevant mosquito/tick/vector exposure.',
 'text', true),

('ENVIRONMENTAL_EXPOSURE',
 'Environmental exposure',
 'Relevant environmental exposure.',
 'text', true),

('BIOMASS_FUEL_EXPOSURE',
 'Biomass fuel exposure',
 'Exposure to indoor biomass fuel smoke.',
 'boolean', true),

('OVERCROWDING',
 'Overcrowding',
 'Crowded living or care environment.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 18. WOMEN'S HEALTH / MENSTRUAL / SEXUAL
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('LMP_DATE',
 'Last menstrual period',
 'Date of the first day of the last menstrual period.',
 'date', true),

('MENARCHE_AGE',
 'Age at menarche',
 'Age at onset of menstruation.',
 'numeric', true),

('MENOPAUSE_STATUS',
 'Menopause status',
 'Premenopausal/perimenopausal/postmenopausal state.',
 'coded', true),

('MENSTRUAL_PATTERN',
 'Menstrual pattern',
 'Character and regularity of menstrual cycles.',
 'coded', true),

('MENSTRUAL_CYCLE_LENGTH',
 'Menstrual cycle length',
 'Typical menstrual cycle length.',
 'quantity', true),

('MENSTRUAL_DURATION',
 'Menstrual duration',
 'Typical duration of menstruation.',
 'quantity', true),

('MENSTRUAL_FLOW',
 'Menstrual flow',
 'Usual menstrual flow.',
 'coded', true),

('MENSTRUAL_PROBLEM_PRESENT',
 'Menstrual problem present',
 'Whether a menstrual problem is present.',
 'boolean', true),

('DYSMENORRHEA',
 'Dysmenorrhea',
 'Painful menstruation.',
 'boolean', true),

('AMENORRHEA',
 'Amenorrhea',
 'Absence of menstruation.',
 'boolean', true),

('ABNORMAL_UTERINE_BLEEDING',
 'Abnormal uterine bleeding',
 'Abnormal uterine bleeding pattern.',
 'boolean', true),

('SEXUAL_HISTORY_RELEVANT',
 'Sexual history relevant',
 'Whether sexual history is clinically relevant.',
 'boolean', true),

('SEXUAL_HISTORY_DETAILS',
 'Sexual history details',
 'Relevant sexual history.',
 'text', true),

('SEXUAL_PARTNERS',
 'Sexual partners',
 'Relevant number/pattern of sexual partners where clinically appropriate.',
 'quantity', true),

('CONTRACEPTION_USE',
 'Contraception use',
 'Current contraceptive method.',
 'coded', true),

('CONTRACEPTION_DETAILS',
 'Contraception details',
 'Details of contraceptive method and adherence.',
 'text', true),

('STI_HISTORY',
 'STI history',
 'Previous sexually transmitted infection.',
 'boolean', true),

('STI_EXPOSURE',
 'STI exposure',
 'Relevant exposure to sexually transmitted infection.',
 'boolean', true),

('CERVICAL_SCREENING_HISTORY',
 'Cervical screening history',
 'Previous cervical cancer screening.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 19. PREGNANCY / OBSTETRIC
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PREGNANCY_STATUS',
 'Pregnancy status',
 'Current pregnancy status.',
 'boolean', true),

('PREGNANCY_STATE',
 'Pregnancy state',
 'Not pregnant, pregnant, postpartum or other defined state.',
 'coded', true),

('GESTATIONAL_AGE',
 'Gestational age',
 'Gestational age in weeks/days.',
 'quantity', true),

('GESTATIONAL_AGE_WEEKS',
 'Gestational age in weeks',
 'Gestational age expressed in completed weeks.',
 'numeric', true),

('GESTATIONAL_AGE_DAYS',
 'Gestational age additional days',
 'Additional gestational days beyond completed weeks.',
 'numeric', true),

('EDD',
 'Estimated date of delivery',
 'Estimated date of delivery.',
 'date', true),

('GRAVIDITY',
 'Gravidity',
 'Number of pregnancies including current pregnancy.',
 'numeric', true),

('PARITY',
 'Parity',
 'Number of pregnancies reaching defined viability threshold.',
 'numeric', true),

('TERM_BIRTHS',
 'Term births',
 'Number of term births.',
 'numeric', true),

('PRETERM_BIRTHS',
 'Preterm births',
 'Number of preterm births.',
 'numeric', true),

('ABORTIONS',
 'Abortions',
 'Number of abortions.',
 'numeric', true),

('LIVING_CHILDREN',
 'Living children',
 'Number of living children.',
 'numeric', true),

('ANC_RECEIVED',
 'Antenatal care received',
 'Whether antenatal care has been received.',
 'boolean', true),

('ANC_VISITS',
 'Antenatal care visits',
 'Number of antenatal care visits.',
 'numeric', true),

('CURRENT_PREGNANCY_COMPLICATIONS',
 'Current pregnancy complications',
 'Complications in the current pregnancy.',
 'text', true),

('PREVIOUS_PREGNANCY_OUTCOMES',
 'Previous pregnancy outcomes',
 'Outcomes of previous pregnancies.',
 'text', true),

('PREVIOUS_C_SECTION',
 'Previous caesarean section',
 'History of caesarean section.',
 'boolean', true),

('PREVIOUS_PPH',
 'Previous postpartum hemorrhage',
 'Previous postpartum haemorrhage.',
 'boolean', true),

('RHESUS_STATUS',
 'Rhesus status',
 'Maternal rhesus status.',
 'coded', true),

('BLOOD_GROUP',
 'Blood group',
 'ABO blood group.',
 'coded', true),

('FETAL_MOVEMENT',
 'Fetal movement',
 'Reported fetal movement.',
 'coded', true),

('FETAL_MOVEMENT_CHANGE',
 'Change in fetal movement',
 'Reduction or alteration in fetal movement.',
 'boolean', true),

('VAGINAL_BLEEDING_IN_PREGNANCY',
 'Vaginal bleeding in pregnancy',
 'Vaginal bleeding during pregnancy.',
 'boolean', true),

('LEAKAGE_OF_LIQUOR',
 'Leakage of liquor',
 'Reported leakage of amniotic fluid.',
 'boolean', true),

('UTERINE_CONTRACTIONS',
 'Uterine contractions',
 'Presence/pattern of uterine contractions.',
 'coded', true),

('LABOUR_STATUS',
 'Labour status',
 'Current labour status.',
 'coded', true),

('BIRTH_MODE',
 'Birth mode',
 'Mode of delivery.',
 'coded', true),

('BIRTH_COMPLICATIONS',
 'Birth complications',
 'Complications around delivery.',
 'text', true),

('BIRTH_RESUSCITATION',
 'Birth resuscitation',
 'Whether neonatal resuscitation was required.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 20. PAEDIATRIC / NEONATAL
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('FEEDING_STATUS',
 'Feeding status',
 'Current feeding pattern.',
 'coded', true),

('BREASTFEEDING',
 'Breastfeeding',
 'Whether currently breastfed.',
 'boolean', true),

('EXCLUSIVE_BREASTFEEDING',
 'Exclusive breastfeeding',
 'Whether exclusively breastfed.',
 'boolean', true),

('FORMULA_FEEDING',
 'Formula feeding',
 'Whether formula is used.',
 'boolean', true),

('COMPLEMENTARY_FEEDING',
 'Complementary feeding',
 'Whether complementary foods have been introduced.',
 'boolean', true),

('RECENT_NUTRITION_CHANGE',
 'Recent nutrition change',
 'Recent change in appetite or intake.',
 'text', true),

('POOR_FEEDING',
 'Poor feeding',
 'Reduced feeding compared with baseline.',
 'boolean', true),

('FEEDING_DIFFICULTY',
 'Feeding difficulty',
 'Difficulty feeding.',
 'boolean', true),

('DEVELOPMENTAL_STATUS',
 'Developmental status',
 'Developmental milestone status.',
 'text', true),

('DEVELOPMENTAL_DELAY',
 'Developmental delay',
 'Concern or evidence of developmental delay.',
 'boolean', true),

('IMMUNIZATION_STATUS',
 'Immunization status',
 'Routine and additional immunizations received.',
 'text', true),

('MISSED_IMMUNIZATION',
 'Missed immunization',
 'One or more expected immunizations not received.',
 'boolean', true),

('BIRTH_WEIGHT',
 'Birth weight',
 'Weight at birth.',
 'quantity', true),

('CURRENT_WEIGHT',
 'Current weight',
 'Current body weight.',
 'quantity', true),

('HEIGHT',
 'Height',
 'Current height/length.',
 'quantity', true),

('LENGTH',
 'Length',
 'Current body length.',
 'quantity', true),

('HEAD_CIRCUMFERENCE',
 'Head circumference',
 'Head circumference measurement.',
 'quantity', true),

('MUAC',
 'Mid-upper arm circumference',
 'Mid-upper arm circumference measurement.',
 'quantity', true),

('PRETERM_BIRTH',
 'Preterm birth',
 'History of preterm birth.',
 'boolean', true),

('NEONATAL_JAUNDICE',
 'Neonatal jaundice',
 'History/presence of neonatal jaundice.',
 'boolean', true),

('NEONATAL_SEPSIS_HISTORY',
 'Neonatal sepsis history',
 'History of neonatal sepsis.',
 'boolean', true),

('NICU_ADMISSION_HISTORY',
 'NICU admission history',
 'Previous neonatal intensive care admission.',
 'boolean', true),

('BIRTH_ASPHYXIA_HISTORY',
 'Birth asphyxia history',
 'History of significant birth asphyxia.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 21. VITAL SIGNS / OBJECTIVE MEASUREMENTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('TEMPERATURE',
 'Temperature',
 'Measured body temperature.',
 'quantity', true),

('HEART_RATE',
 'Heart rate',
 'Measured heart rate.',
 'quantity', true),

('RESPIRATORY_RATE',
 'Respiratory rate',
 'Measured respiratory rate.',
 'quantity', true),

('SYSTOLIC_BP',
 'Systolic blood pressure',
 'Systolic blood pressure.',
 'quantity', true),

('DIASTOLIC_BP',
 'Diastolic blood pressure',
 'Diastolic blood pressure.',
 'quantity', true),

('MEAN_ARTERIAL_PRESSURE',
 'Mean arterial pressure',
 'Calculated or measured mean arterial pressure.',
 'quantity', true),

('OXYGEN_SATURATION',
 'Oxygen saturation',
 'Peripheral oxygen saturation.',
 'quantity', true),

('OXYGEN_FLOW_RATE',
 'Oxygen flow rate',
 'Oxygen flow delivered per minute.',
 'quantity', true),

('OXYGEN_DEVICE',
 'Oxygen delivery device',
 'Device used for oxygen delivery.',
 'coded', true),

('CAPILLARY_REFILL_TIME',
 'Capillary refill time',
 'Measured capillary refill time.',
 'quantity', true),

('WEIGHT',
 'Weight',
 'Measured body weight.',
 'quantity', true),

('BMI',
 'Body mass index',
 'Calculated body mass index.',
 'numeric', true),

('PAIN_SCORE',
 'Pain score',
 'Numerical pain score.',
 'numeric', true),

('GCS_SCORE',
 'Glasgow Coma Scale',
 'Glasgow Coma Scale score.',
 'numeric', true),

('AVPU',
 'AVPU consciousness level',
 'Alert, Voice, Pain, Unresponsive assessment.',
 'coded', true),

('URINE_OUTPUT_MEASURED',
 'Measured urine output',
 'Measured urine output over a defined period.',
 'quantity', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 22. GENERAL EXAMINATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('GENERAL_APPEARANCE',
 'General appearance',
 'Overall clinical appearance.',
 'coded', true),

('LEVEL_OF_CONSCIOUSNESS',
 'Level of consciousness',
 'Observed level of consciousness.',
 'coded', true),

('DISTRESS_PRESENT',
 'Distress',
 'Clinically apparent distress.',
 'boolean', true),

('ACUTELY_ILL_APPEARANCE',
 'Acute illness appearance',
 'Appearance suggesting acute illness.',
 'boolean', true),

('CHRONICALLY_ILL_APPEARANCE',
 'Chronic illness appearance',
 'Appearance suggesting chronic illness.',
 'boolean', true),

('PALLOR',
 'Pallor',
 'Clinical pallor.',
 'boolean', true),

('ICTERUS',
 'Icterus',
 'Clinical jaundice.',
 'boolean', true),

('CYANOSIS',
 'Cyanosis',
 'Clinical cyanosis.',
 'boolean', true),

('CLUBBING',
 'Clubbing',
 'Digital clubbing.',
 'boolean', true),

('LYMPHADENOPATHY',
 'Lymphadenopathy',
 'Clinically enlarged lymph nodes.',
 'boolean', true),

('OEDEMA',
 'Oedema',
 'Peripheral or generalized oedema.',
 'boolean', true),

('DEHYDRATION',
 'Dehydration',
 'Clinical evidence of dehydration.',
 'coded', true),

('NUTRITIONAL_STATUS',
 'Nutritional status',
 'Clinical nutritional assessment.',
 'coded', true),

('MOBILITY_STATUS',
 'Mobility status',
 'Observed mobility.',
 'coded', true),

('HYDRATION_STATUS',
 'Hydration status',
 'Overall hydration state.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 23. RESPIRATORY EXAMINATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('WORK_OF_BREATHING',
 'Work of breathing',
 'Observed respiratory effort.',
 'coded', true),

('CHEST_INDRAWING',
 'Chest indrawing',
 'Observed chest wall indrawing.',
 'boolean', true),

('INTERCOSTAL_RECESSION',
 'Intercostal recession',
 'Intercostal recession.',
 'boolean', true),

('SUBCOSTAL_RECESSION',
 'Subcostal recession',
 'Subcostal recession.',
 'boolean', true),

('NASAL_FLARING_EXAM',
 'Nasal flaring on examination',
 'Observed nasal flaring.',
 'boolean', true),

('GRUNTING_EXAM',
 'Grunting on examination',
 'Observed expiratory grunting.',
 'boolean', true),

('CENTRAL_CYANOSIS',
 'Central cyanosis',
 'Central cyanosis on examination.',
 'boolean', true),

('CHEST_EXPANSION',
 'Chest expansion',
 'Observed chest expansion.',
 'coded', true),

('TRACHEAL_POSITION',
 'Tracheal position',
 'Tracheal position.',
 'coded', true),

('CHEST_TENDERNESS',
 'Chest tenderness',
 'Chest wall tenderness.',
 'boolean', true),

('PERCUSSION_NOTE',
 'Percussion note',
 'Percussion finding.',
 'coded', true),

('BREATH_SOUND',
 'Breath sound',
 'Primary breath sound finding.',
 'coded', true),

('BRONCHIAL_BREATHING',
 'Bronchial breathing',
 'Bronchial breath sounds.',
 'boolean', true),

('CRACKLES',
 'Crackles',
 'Inspiratory crackles.',
 'boolean', true),

('WHEEZE',
 'Wheeze on examination',
 'Wheeze on auscultation.',
 'boolean', true),

('RHONCHI',
 'Rhonchi',
 'Rhonchi on auscultation.',
 'boolean', true),

('PLEURAL_RUB',
 'Pleural rub',
 'Pleural friction rub.',
 'boolean', true),

('AIR_ENTRY',
 'Air entry',
 'Degree of air entry.',
 'coded', true),

('VOCAL_RESONANCE',
 'Vocal resonance',
 'Vocal resonance finding.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 24. CARDIOVASCULAR EXAMINATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('JVP',
 'Jugular venous pressure',
 'Jugular venous pressure assessment.',
 'quantity', true),

('APEX_BEAT',
 'Apex beat',
 'Location/character of apex beat.',
 'text', true),

('HEART_SOUNDS',
 'Heart sounds',
 'Heart sound findings.',
 'coded', true),

('MURMUR_PRESENT',
 'Murmur',
 'Presence of cardiac murmur.',
 'boolean', true),

('MURMUR_CHARACTER',
 'Murmur character',
 'Character, timing and location of murmur.',
 'text', true),

('ADDED_HEART_SOUNDS',
 'Added heart sounds',
 'Presence of S3, S4 or other added sounds.',
 'coded', true),

('PERIPHERAL_PULSES',
 'Peripheral pulses',
 'Peripheral pulse examination.',
 'coded', true),

('PULSE_CHARACTER',
 'Pulse character',
 'Pulse volume/rhythm/character.',
 'coded', true),

('PERIPHERAL_PERFUSION',
 'Peripheral perfusion',
 'Peripheral perfusion assessment.',
 'coded', true),

('PERIPHERAL_OEDEMA',
 'Peripheral oedema',
 'Presence and degree of peripheral oedema.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 25. ABDOMINAL EXAMINATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('ABDOMINAL_INSPECTION',
 'Abdominal inspection',
 'Inspection findings of the abdomen.',
 'text', true),

('ABDOMINAL_TENDERNESS',
 'Abdominal tenderness',
 'Presence/location of abdominal tenderness.',
 'boolean', true),

('ABDOMINAL_TENDERNESS_SITE',
 'Abdominal tenderness site',
 'Location of abdominal tenderness.',
 'coded', true),

('GUARDING',
 'Guarding',
 'Abdominal guarding.',
 'boolean', true),

('RIGIDITY',
 'Rigidity',
 'Abdominal rigidity.',
 'boolean', true),

('REBOUND_TENDERNESS',
 'Rebound tenderness',
 'Rebound tenderness.',
 'boolean', true),

('ABDOMINAL_MASS',
 'Abdominal mass',
 'Palpable abdominal mass.',
 'boolean', true),

('HEPATOMEGALY',
 'Hepatomegaly',
 'Enlarged liver.',
 'boolean', true),

('SPLENOMEGALY',
 'Splenomegaly',
 'Enlarged spleen.',
 'boolean', true),

('ASCITES',
 'Ascites',
 'Ascites on examination.',
 'boolean', true),

('BOWEL_SOUNDS',
 'Bowel sounds',
 'Bowel sound findings.',
 'coded', true),

('HERNIA_PRESENT',
 'Hernia',
 'Presence of hernia.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 26. NEUROLOGICAL EXAMINATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('ORIENTATION',
 'Orientation',
 'Orientation to person, place and time.',
 'coded', true),

('PUPILS',
 'Pupils',
 'Pupil size and reactivity.',
 'text', true),

('CRANIAL_NERVES',
 'Cranial nerves',
 'Cranial nerve examination.',
 'text', true),

('MOTOR_POWER',
 'Motor power',
 'Motor strength assessment.',
 'text', true),

('MUSCLE_TONE',
 'Muscle tone',
 'Muscle tone assessment.',
 'coded', true),

('REFLEXES',
 'Reflexes',
 'Deep tendon and pathological reflexes.',
 'text', true),

('SENSORY_EXAMINATION',
 'Sensory examination',
 'Sensory examination findings.',
 'text', true),

('COORDINATION',
 'Coordination',
 'Coordination examination.',
 'coded', true),

('GAIT',
 'Gait',
 'Gait assessment.',
 'coded', true),

('MENINGEAL_SIGNS',
 'Meningeal signs',
 'Presence of meningeal irritation signs.',
 'boolean', true),

('FOCAL_NEUROLOGICAL_DEFICIT',
 'Focal neurological deficit',
 'Presence of focal neurological deficit.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 27. INVESTIGATION CAPTURE
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('INVESTIGATION_ORDERED',
 'Investigation ordered',
 'Investigation requested by clinician.',
 'coded', true),

('INVESTIGATION_RESULT',
 'Investigation result',
 'Result of an investigation.',
 'text', true),

('INVESTIGATION_RESULT_NUMERIC',
 'Numeric investigation result',
 'Numeric laboratory or diagnostic result.',
 'quantity', true),

('INVESTIGATION_RESULT_CODE',
 'Coded investigation result',
 'Coded investigation result.',
 'coded', true),

('INVESTIGATION_REFERENCE_RANGE',
 'Investigation reference range',
 'Reference range associated with result.',
 'text', true),

('INVESTIGATION_ABNORMAL',
 'Abnormal investigation result',
 'Whether result is outside the applicable reference range.',
 'boolean', true),

('LAB_HEMOGLOBIN',
 'Hemoglobin',
 'Hemoglobin concentration.',
 'quantity', true),

('LAB_WBC',
 'White blood cell count',
 'White blood cell count.',
 'quantity', true),

('LAB_NEUTROPHILS',
 'Neutrophil count',
 'Neutrophil count.',
 'quantity', true),

('LAB_LYMPHOCYTES',
 'Lymphocyte count',
 'Lymphocyte count.',
 'quantity', true),

('LAB_PLATELETS',
 'Platelet count',
 'Platelet count.',
 'quantity', true),

('LAB_CRPs',
 'C-reactive protein',
 'C-reactive protein measurement.',
 'quantity', true),

('LAB_ESR',
 'Erythrocyte sedimentation rate',
 'ESR measurement.',
 'quantity', true),

('LAB_SODIUM',
 'Sodium',
 'Serum sodium concentration.',
 'quantity', true),

('LAB_POTASSIUM',
 'Potassium',
 'Serum potassium concentration.',
 'quantity', true),

('LAB_CREATININE',
 'Creatinine',
 'Serum creatinine.',
 'quantity', true),

('LAB_UREA',
 'Urea',
 'Serum urea.',
 'quantity', true),

('LAB_GLUCOSE',
 'Glucose',
 'Blood glucose.',
 'quantity', true),

('LAB_HBA1C',
 'HbA1c',
 'Glycated hemoglobin.',
 'quantity', true),

('LAB_BILIRUBIN',
 'Bilirubin',
 'Bilirubin concentration.',
 'quantity', true),

('LAB_ALT',
 'ALT',
 'Alanine aminotransferase.',
 'quantity', true),

('LAB_AST',
 'AST',
 'Aspartate aminotransferase.',
 'quantity', true),

('LAB_ALBUMIN',
 'Albumin',
 'Serum albumin.',
 'quantity', true),

('LAB_LACTATE',
 'Lactate',
 'Blood lactate.',
 'quantity', true),

('LAB_INR',
 'INR',
 'International normalized ratio.',
 'quantity', true),

('LAB_PT',
 'Prothrombin time',
 'Prothrombin time.',
 'quantity', true),

('LAB_APTT',
 'APTT',
 'Activated partial thromboplastin time.',
 'quantity', true),

('LAB_TROPONIN',
 'Troponin',
 'Cardiac troponin measurement.',
 'quantity', true),

('LAB_BLOOD_CULTURE',
 'Blood culture',
 'Blood culture result.',
 'coded', true),

('LAB_URINALYSIS',
 'Urinalysis',
 'Urinalysis result.',
 'text', true),

('LAB_URINE_CULTURE',
 'Urine culture',
 'Urine culture result.',
 'coded', true),

('LAB_PREGNANCY_TEST',
 'Pregnancy test',
 'Pregnancy test result.',
 'coded', true),

('LAB_HIV_TEST',
 'HIV test',
 'HIV test result.',
 'coded', true),

('LAB_MALARIA_TEST',
 'Malaria test',
 'Malaria diagnostic test result.',
 'coded', true),

('LAB_TB_TEST',
 'Tuberculosis test',
 'Tuberculosis diagnostic test result.',
 'coded', true),

('IMAGING_RESULT',
 'Imaging result',
 'General imaging result.',
 'text', true),

('CXR_RESULT',
 'Chest X-ray result',
 'Chest radiograph result.',
 'text', true),

('ULTRASOUND_RESULT',
 'Ultrasound result',
 'Ultrasound result.',
 'text', true),

('CT_RESULT',
 'CT result',
 'Computed tomography result.',
 'text', true),

('MRI_RESULT',
 'MRI result',
 'Magnetic resonance imaging result.',
 'text', true),

('ECG_RESULT',
 'ECG result',
 'Electrocardiogram result.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 28. DIAGNOSTIC / PHENOTYPE / REASONING ANCHORS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PHENOTYPE_PRESENT',
 'Phenotype present',
 'Observed clinical phenotype represented by the canonical phenotype engine.',
 'coded', true),

('PHENOTYPE_CONFIDENCE',
 'Phenotype confidence',
 'Confidence associated with phenotype matching.',
 'numeric', true),

('MECHANISM_PRESENT',
 'Mechanism present',
 'Mechanistic interpretation generated by the reasoning layer.',
 'coded', true),

('DIFFERENTIAL_PRESENT',
 'Differential diagnosis present',
 'Differential candidate represented in the reasoning layer.',
 'coded', true),

('DIFFERENTIAL_RANK',
 'Differential rank',
 'Rank of a candidate diagnosis.',
 'numeric', true),

('DIFFERENTIAL_SCORE',
 'Differential score',
 'Computed support score for a differential candidate.',
 'numeric', true),

('DIAGNOSIS_CONFIRMED',
 'Confirmed diagnosis',
 'Diagnosis formally established by the responsible clinician.',
 'coded', true),

('DIAGNOSIS_PROVISIONAL',
 'Provisional diagnosis',
 'Working/provisional diagnosis.',
 'coded', true),

('DIAGNOSIS_EXCLUDED',
 'Excluded diagnosis',
 'Diagnosis explicitly excluded after clinical evaluation.',
 'coded', true),

('DIAGNOSIS_UNCERTAIN',
 'Uncertain diagnosis',
 'Diagnosis remaining uncertain after evaluation.',
 'coded', true),

('DIAGNOSIS_STATUS',
 'Diagnosis status',
 'Status of a diagnosis.',
 'coded', true),

('DIAGNOSIS_CONFIDENCE',
 'Diagnosis confidence',
 'Confidence associated with a diagnostic conclusion.',
 'numeric', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 29. SEVERITY / ACUITY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('ACUITY',
 'Clinical acuity',
 'Overall acuity of the current presentation.',
 'coded', true),

('SEVERITY_SCORE',
 'Severity score',
 'Result of a structured clinical severity scoring instrument.',
 'numeric', true),

('SEVERITY_SCORE_CODE',
 'Severity score instrument',
 'Code of the severity scoring instrument used.',
 'coded', true),

('SEVERITY_CLASS',
 'Severity classification',
 'Severity category derived from a validated scoring instrument.',
 'coded', true),

('CURB65_SCORE',
 'CURB-65 score',
 'CURB-65 pneumonia severity score.',
 'numeric', true),

('NEWS2_SCORE',
 'NEWS2 score',
 'National Early Warning Score 2.',
 'numeric', true),

('GCS_SEVERITY',
 'Glasgow Coma Scale severity',
 'Severity represented by Glasgow Coma Scale.',
 'numeric', true),

('QSOFA_SCORE',
 'qSOFA score',
 'Quick Sequential Organ Failure Assessment score.',
 'numeric', true),

('SOFA_SCORE',
 'SOFA score',
 'Sequential Organ Failure Assessment score.',
 'numeric', true),

('PEWS_SCORE',
 'Paediatric Early Warning Score',
 'Paediatric early warning score.',
 'numeric', true),

('ORGAN_DYSFUNCTION_PRESENT',
 'Organ dysfunction present',
 'Evidence of clinically significant organ dysfunction.',
 'boolean', true),

('SHOCK_PRESENT',
 'Shock present',
 'Clinical state consistent with shock.',
 'boolean', true),

('SEPSIS_SUSPECTED',
 'Sepsis suspected',
 'Clinical suspicion of sepsis.',
 'boolean', true),

('SEPSIS_CONFIRMED',
 'Sepsis confirmed',
 'Clinically established sepsis.',
 'boolean', true),

('RED_FLAG_PRESENT',
 'Red flag present',
 'Clinically significant red-flag finding.',
 'boolean', true),

('EMERGENCY_PRESENTATION',
 'Emergency presentation',
 'Presentation requiring emergency assessment.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 30. MEDICATION / PHARMACOLOGY FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('MEDICATION_NAME',
 'Medication name',
 'Generic medication name.',
 'coded', true),

('MEDICATION_FORMULATION',
 'Medication formulation',
 'Medication dosage form.',
 'coded', true),

('MEDICATION_STRENGTH',
 'Medication strength',
 'Medication concentration/strength.',
 'text', true),

('MEDICATION_ROUTE',
 'Medication route',
 'Administration route.',
 'coded', true),

('MEDICATION_DOSE',
 'Medication dose',
 'Individual dose prescribed/administered.',
 'quantity', true),

('MEDICATION_DOSE_UNIT',
 'Medication dose unit',
 'Unit associated with medication dose.',
 'coded', true),

('MEDICATION_FREQUENCY',
 'Medication frequency',
 'Frequency of medication administration.',
 'coded', true),

('MEDICATION_INTERVAL',
 'Medication interval',
 'Time interval between doses.',
 'quantity', true),

('MEDICATION_DURATION',
 'Medication duration',
 'Duration of medication therapy.',
 'quantity', true),

('MEDICATION_INDICATION',
 'Medication indication',
 'Clinical indication for medication.',
 'coded', true),

('MEDICATION_PRN',
 'Medication PRN',
 'Whether medication is prescribed as needed.',
 'boolean', true),

('PRN_INDICATION',
 'PRN indication',
 'Clinical indication for PRN administration.',
 'text', true),

('MAXIMUM_DAILY_DOSE',
 'Maximum daily dose',
 'Maximum permitted dose over 24 hours.',
 'quantity', true),

('WEIGHT_BASED_DOSE',
 'Weight based dose',
 'Medication dose calculated from body weight.',
 'quantity', true),

('BSA_BASED_DOSE',
 'Body surface area based dose',
 'Medication dose calculated from body surface area.',
 'quantity', true),

('RENAL_DOSE_ADJUSTMENT',
 'Renal dose adjustment',
 'Dose adjustment based on renal function.',
 'text', true),

('HEPATIC_DOSE_ADJUSTMENT',
 'Hepatic dose adjustment',
 'Dose adjustment based on hepatic function.',
 'text', true),

('DOSE_CALCULATION_RESULT',
 'Calculated medication dose',
 'Final calculated medication dose before prescribing.',
 'quantity', true),

('DOSE_CALCULATION_EXPRESSION',
 'Dose calculation expression',
 'Machine-readable dose calculation expression.',
 'text', true),

('DOSE_REFERENCE_SOURCE',
 'Dose reference source',
 'Source supporting the medication dose.',
 'coded', true),

('MEDICATION_CONTRAINDICATION',
 'Medication contraindication',
 'Known contraindication to a medication.',
 'text', true),

('MEDICATION_INTERACTION',
 'Medication interaction',
 'Relevant medication interaction.',
 'text', true),

('THERAPEUTIC_DUPLICATION',
 'Therapeutic duplication',
 'Potential duplication within a therapeutic class.',
 'boolean', true),

('MEDICATION_SAFETY_CHECK',
 'Medication safety check',
 'Result of medication safety validation.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 31. PRESCRIPTION / ADMINISTRATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PRESCRIPTION_CREATED',
 'Prescription created',
 'A prescription order was created.',
 'boolean', true),

('PRESCRIPTION_STATUS',
 'Prescription status',
 'Draft, active, discontinued, completed or cancelled.',
 'coded', true),

('PRESCRIBER_ID',
 'Prescriber identifier',
 'Clinician responsible for prescribing.',
 'text', true),

('PRESCRIPTION_DATE',
 'Prescription date',
 'Date prescription was issued.',
 'datetime', true),

('ADMINISTRATION_STATUS',
 'Medication administration status',
 'Whether a prescribed dose was administered.',
 'coded', true),

('ADMINISTRATION_TIME',
 'Medication administration time',
 'Time medication was administered.',
 'datetime', true),

('ADMINISTERED_DOSE',
 'Administered dose',
 'Dose actually administered.',
 'quantity', true),

('ADMINISTRATION_ROUTE',
 'Administration route',
 'Route actually used for administration.',
 'coded', true),

('MISSED_DOSE_REASON',
 'Missed dose reason',
 'Reason medication dose was not administered.',
 'text', true),

('MEDICATION_STOP_REASON',
 'Medication stop reason',
 'Reason medication was discontinued.',
 'text', true),

('MEDICATION_RESPONSE',
 'Medication response',
 'Observed response to medication.',
 'coded', true),

('MEDICATION_ADVERSE_EFFECT',
 'Medication adverse effect',
 'Adverse effect following medication exposure.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 32. PROTOCOL / GUIDELINE / MANAGEMENT
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PROTOCOL_SELECTED',
 'Protocol selected',
 'Clinical protocol selected by the protocol engine.',
 'coded', true),

('PROTOCOL_VERSION',
 'Protocol version',
 'Version of selected clinical protocol.',
 'text', true),

('PROTOCOL_ELIGIBILITY',
 'Protocol eligibility',
 'Whether patient/context satisfies protocol eligibility.',
 'boolean', true),

('PROTOCOL_STEP',
 'Protocol step',
 'Current protocol step.',
 'coded', true),

('PROTOCOL_STEP_STATUS',
 'Protocol step status',
 'Status of protocol step.',
 'coded', true),

('GUIDELINE_SOURCE',
 'Guideline source',
 'Guideline used to support clinical management.',
 'coded', true),

('MANAGEMENT_PLAN',
 'Management plan',
 'Clinician-approved management plan.',
 'text', true),

('NON_PHARMACOLOGICAL_MANAGEMENT',
 'Non-pharmacological management',
 'Non-drug management plan.',
 'text', true),

('REFERRAL_REQUIRED',
 'Referral required',
 'Whether referral is required.',
 'boolean', true),

('REFERRAL_DESTINATION',
 'Referral destination',
 'Service/facility to which patient is referred.',
 'coded', true),

('ADMISSION_REQUIRED',
 'Admission required',
 'Whether admission is required.',
 'boolean', true),

('ADMISSION_LEVEL',
 'Admission level',
 'Ward/HDU/ICU or other care level.',
 'coded', true),

('DISCHARGE_APPROPRIATE',
 'Discharge appropriate',
 'Whether discharge criteria are satisfied.',
 'boolean', true),

('FOLLOW_UP_REQUIRED',
 'Follow-up required',
 'Whether follow-up is required.',
 'boolean', true),

('FOLLOW_UP_INTERVAL',
 'Follow-up interval',
 'Recommended/ordered follow-up interval.',
 'quantity', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 33. MONITORING
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('MONITORING_REQUIRED',
 'Monitoring required',
 'Whether active monitoring is required.',
 'boolean', true),

('MONITORING_PARAMETER',
 'Monitoring parameter',
 'Clinical parameter requiring monitoring.',
 'coded', true),

('MONITORING_FREQUENCY',
 'Monitoring frequency',
 'Frequency of monitoring.',
 'quantity', true),

('ESCALATION_TRIGGER',
 'Escalation trigger',
 'Finding that should trigger escalation.',
 'text', true),

('CLINICAL_DETERIORATION',
 'Clinical deterioration',
 'Evidence of clinical deterioration.',
 'boolean', true),

('CLINICAL_IMPROVEMENT',
 'Clinical improvement',
 'Evidence of clinical improvement.',
 'boolean', true),

('RESPONSE_TO_TREATMENT',
 'Response to treatment',
 'Overall response to treatment.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 34. DISPOSITION / TRANSFER / DISCHARGE
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('DISPOSITION',
 'Disposition',
 'Final disposition from the current encounter.',
 'coded', true),

('DISCHARGE_DIAGNOSIS',
 'Discharge diagnosis',
 'Diagnosis recorded at discharge.',
 'text', true),

('DISCHARGE_CONDITION',
 'Discharge condition',
 'Clinical condition at discharge.',
 'coded', true),

('DISCHARGE_MEDICATIONS',
 'Discharge medications',
 'Medications prescribed on discharge.',
 'text', true),

('DISCHARGE_INSTRUCTIONS',
 'Discharge instructions',
 'Instructions provided to patient/caregiver.',
 'text', true),

('RETURN_PRECAUTIONS',
 'Return precautions',
 'Symptoms/findings requiring urgent return.',
 'text', true),

('TRANSFER_REQUIRED',
 'Transfer required',
 'Whether transfer to another service/facility is required.',
 'boolean', true),

('TRANSFER_DESTINATION',
 'Transfer destination',
 'Destination of transfer.',
 'coded', true),

('TRANSFER_REASON',
 'Transfer reason',
 'Reason for transfer.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 35. PSYCHIATRIC / MENTAL HEALTH
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PSYCHIATRIC_PRESENTATION',
 'Psychiatric presentation',
 'Description of current psychiatric presentation.',
 'text', true),

('PSYCHIATRIC_FUNCTIONAL_IMPACT',
 'Psychiatric functional impact',
 'Effect of psychiatric symptoms on functioning.',
 'text', true),

('MOOD_CHANGE',
 'Mood change',
 'Change in mood.',
 'boolean', true),

('DEPRESSED_MOOD',
 'Depressed mood',
 'Depressed mood.',
 'boolean', true),

('ANHEDONIA',
 'Anhedonia',
 'Loss of interest or pleasure.',
 'boolean', true),

('ANXIETY_PRESENT',
 'Anxiety',
 'Clinically relevant anxiety symptoms.',
 'boolean', true),

('PANIC_ATTACK',
 'Panic attack',
 'Panic attack symptoms.',
 'boolean', true),

('PSYCHOSIS_PRESENT',
 'Psychosis',
 'Psychotic symptoms.',
 'boolean', true),

('HALLUCINATION',
 'Hallucination',
 'Hallucination reported/observed.',
 'boolean', true),

('DELUSION',
 'Delusion',
 'Delusional belief.',
 'boolean', true),

('SUICIDAL_IDEATION',
 'Suicidal ideation',
 'Suicidal thoughts.',
 'boolean', true),

('SELF_HARM_HISTORY',
 'Self-harm history',
 'Previous self-harm.',
 'boolean', true),

('HOMICIDAL_IDEATION',
 'Homicidal ideation',
 'Thoughts of harming another person.',
 'boolean', true),

('SLEEP_DISTURBANCE',
 'Sleep disturbance',
 'Clinically relevant sleep disturbance.',
 'boolean', true),

('COGNITIVE_CHANGE',
 'Cognitive change',
 'Change in cognitive function.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 36. SEXUAL / REPRODUCTIVE SAFETY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PREGNANCY_POSSIBLE',
 'Pregnancy possible',
 'Pregnancy is biologically possible in the current context.',
 'boolean', true),

('PREGNANCY_TEST_REQUIRED',
 'Pregnancy test required',
 'Pregnancy testing required before a relevant intervention.',
 'boolean', true),

('SEXUAL_ASSAULT_CONCERN',
 'Sexual assault concern',
 'Concern for sexual assault.',
 'boolean', true),

('REPRODUCTIVE_INTENTION',
 'Reproductive intention',
 'Current reproductive intention where clinically appropriate.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 37. INFECTION / EXPOSURE / COMMUNICABLE DISEASE
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('INFECTIOUS_CONTACT',
 'Infectious contact',
 'Known contact with an infectious illness.',
 'boolean', true),

('OUTBREAK_EXPOSURE',
 'Outbreak exposure',
 'Exposure associated with an outbreak.',
 'boolean', true),

('RECENT_HEALTHCARE_EXPOSURE',
 'Recent healthcare exposure',
 'Recent healthcare-associated exposure.',
 'boolean', true),

('RECENT_HOSPITALIZATION',
 'Recent hospitalization',
 'Recent hospital admission.',
 'boolean', true),

('RECENT_PROCEDURE',
 'Recent procedure',
 'Recent invasive or surgical procedure.',
 'boolean', true),

('ANTIBIOTIC_RESISTANCE_HISTORY',
 'Antimicrobial resistance history',
 'Known previous resistant organism or resistant infection.',
 'boolean', true),

('KNOWN_CARRIAGE',
 'Known organism carriage',
 'Known colonization/carriage with clinically relevant organism.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 38. TRAUMA / EMERGENCY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('TRAUMA_MECHANISM',
 'Trauma mechanism',
 'Mechanism of injury.',
 'text', true),

('TRAUMA_TIME',
 'Trauma time',
 'Date/time of injury.',
 'datetime', true),

('INJURY_SITE',
 'Injury site',
 'Anatomical site of injury.',
 'coded', true),

('INJURY_SIDE',
 'Injury side',
 'Side of injury.',
 'coded', true),

('BLEEDING_PRESENT',
 'Bleeding present',
 'Active bleeding.',
 'boolean', true),

('ESTIMATED_BLOOD_LOSS',
 'Estimated blood loss',
 'Estimated blood loss.',
 'quantity', true),

('HEAD_INJURY',
 'Head injury',
 'History/evidence of head injury.',
 'boolean', true),

('NECK_INJURY',
 'Neck injury',
 'History/evidence of neck injury.',
 'boolean', true),

('CHEST_INJURY',
 'Chest injury',
 'History/evidence of chest injury.',
 'boolean', true),

('ABDOMINAL_INJURY',
 'Abdominal injury',
 'History/evidence of abdominal injury.',
 'boolean', true),

('PELVIC_INJURY',
 'Pelvic injury',
 'History/evidence of pelvic injury.',
 'boolean', true),

('LIMB_INJURY',
 'Limb injury',
 'History/evidence of limb injury.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 39. PROCEDURES
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PROCEDURE_PLANNED',
 'Procedure planned',
 'Procedure planned for the patient.',
 'coded', true),

('PROCEDURE_PERFORMED',
 'Procedure performed',
 'Procedure actually performed.',
 'coded', true),

('PROCEDURE_DATE',
 'Procedure date',
 'Date/time procedure occurred.',
 'datetime', true),

('PROCEDURE_INDICATION',
 'Procedure indication',
 'Clinical indication for procedure.',
 'text', true),

('PROCEDURE_OUTCOME',
 'Procedure outcome',
 'Outcome of procedure.',
 'coded', true),

('PROCEDURE_COMPLICATION',
 'Procedure complication',
 'Complication of procedure.',
 'text', true),

('CONSENT_OBTAINED',
 'Consent obtained',
 'Whether required consent was obtained.',
 'boolean', true),

('CONSENT_TYPE',
 'Consent type',
 'Type of consent obtained.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 40. NURSING / CARE
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('FALL_RISK',
 'Fall risk',
 'Clinical fall risk assessment.',
 'coded', true),

('PRESSURE_INJURY_RISK',
 'Pressure injury risk',
 'Risk of pressure injury.',
 'coded', true),

('NUTRITION_RISK',
 'Nutrition risk',
 'Risk of malnutrition.',
 'coded', true),

('VTE_RISK',
 'Venous thromboembolism risk',
 'VTE risk classification.',
 'coded', true),

('PAIN_MANAGEMENT_REQUIRED',
 'Pain management required',
 'Whether active pain management is required.',
 'boolean', true),

('ASSISTANCE_REQUIRED',
 'Assistance required',
 'Level of assistance required for activities of daily living.',
 'coded', true),

('MOBILITY_AID',
 'Mobility aid',
 'Mobility aid required or used.',
 'coded', true),

('PRESSURE_INJURY_PRESENT',
 'Pressure injury present',
 'Presence of pressure injury.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 41. CLINICAL COMMUNICATION / DOCUMENTATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('CLINICAL_SUMMARY',
 'Clinical summary',
 'Structured clinical summary.',
 'text', true),

('CLINICAL_ASSESSMENT',
 'Clinical assessment',
 'Clinician assessment of the current clinical state.',
 'text', true),

('CLINICAL_IMPRESSION',
 'Clinical impression',
 'Clinician documented impression.',
 'text', true),

('PATIENT_CONCERN',
 'Patient concern',
 'Patient expressed concern or priority.',
 'text', true),

('PATIENT_EXPECTATION',
 'Patient expectation',
 'Patient expectation of care.',
 'text', true),

('SHARED_DECISION_MAKING',
 'Shared decision making',
 'Whether shared decision making occurred.',
 'boolean', true),

('PATIENT_EDUCATION',
 'Patient education',
 'Education provided to patient/caregiver.',
 'text', true),

('DOCUMENTATION_COMPLETENESS',
 'Documentation completeness',
 'Completeness status of clinical documentation.',
 'coded', true),

('DOCUMENTATION_STATUS',
 'Documentation status',
 'Draft/final/amended status.',
 'coded', true),

('CLINICIAN_EDIT_PRESENT',
 'Clinician edit present',
 'Whether a clinician edited generated documentation.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 42. QUALITY / SAFETY / ESCALATION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('CLINICAL_ALERT',
 'Clinical alert',
 'Clinical alert generated by the safety/rules engine.',
 'coded', true),

('CRITICAL_RESULT',
 'Critical result',
 'Investigation result meeting critical-result criteria.',
 'boolean', true),

('CRITICAL_RESULT_ACKNOWLEDGED',
 'Critical result acknowledged',
 'Whether a critical result was acknowledged.',
 'boolean', true),

('ESCALATION_REQUIRED',
 'Escalation required',
 'Whether escalation of care is required.',
 'boolean', true),

('ESCALATION_LEVEL',
 'Escalation level',
 'Required escalation destination/level.',
 'coded', true),

('HUMAN_AUTHORIZATION_REQUIRED',
 'Human authorization required',
 'Whether human authorization is mandatory before action.',
 'boolean', true),

('HUMAN_AUTHORIZATION_GRANTED',
 'Human authorization granted',
 'Whether required human authorization was granted.',
 'boolean', true),

('SAFETY_OVERRIDE',
 'Safety override',
 'Explicit authorized override of a safety control.',
 'boolean', true),

('SAFETY_OVERRIDE_REASON',
 'Safety override reason',
 'Documented reason for safety override.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 43. PROVENANCE / SOURCE
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('SOURCE_TYPE',
 'Source type',
 'Origin of the fact: patient, caregiver, clinician, measurement, laboratory, system or other source.',
 'coded', true),

('SOURCE_ID',
 'Source identifier',
 'Identifier of the source where applicable.',
 'text', true),

('RECORDED_BY',
 'Recorded by',
 'Actor who recorded the fact.',
 'text', true),

('RECORDED_AT',
 'Recorded at',
 'Timestamp at which fact was recorded.',
 'datetime', true),

('OBSERVED_AT',
 'Observed at',
 'Timestamp at which clinical phenomenon was observed.',
 'datetime', true),

('FACT_CONFIDENCE',
 'Fact confidence',
 'Confidence/quality indicator associated with a captured fact.',
 'numeric', true),

('FACT_VERIFICATION_STATUS',
 'Fact verification status',
 'Verification state of the captured fact.',
 'coded', true),

('FACT_CORRECTION_PRESENT',
 'Fact correction present',
 'Whether the fact has been corrected or amended.',
 'boolean', true),

('FACT_CORRECTION_REASON',
 'Fact correction reason',
 'Reason a fact was corrected.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 44. UNIVERSAL REVIEW OF SYSTEMS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('ROS_COMPLETED',
 'Review of systems completed',
 'Whether relevant review of systems was completed.',
 'boolean', true),

('ROS_RESPIRATORY',
 'Respiratory review',
 'Respiratory review of systems.',
 'text', true),

('ROS_CARDIOVASCULAR',
 'Cardiovascular review',
 'Cardiovascular review of systems.',
 'text', true),

('ROS_GASTROINTESTINAL',
 'Gastrointestinal review',
 'Gastrointestinal review of systems.',
 'text', true),

('ROS_GENITOURINARY',
 'Genitourinary review',
 'Genitourinary review of systems.',
 'text', true),

('ROS_NEUROLOGICAL',
 'Neurological review',
 'Neurological review of systems.',
 'text', true),

('ROS_MUSCULOSKELETAL',
 'Musculoskeletal review',
 'Musculoskeletal review of systems.',
 'text', true),

('ROS_DERMATOLOGICAL',
 'Dermatological review',
 'Dermatological review of systems.',
 'text', true),

('ROS_PSYCHIATRIC',
 'Psychiatric review',
 'Psychiatric review of systems.',
 'text', true),

('ADDITIONAL_SYSTEM_SYMPTOMS',
 'Additional system symptoms',
 'Whether review of systems identified additional symptoms.',
 'boolean', true),

('ADDITIONAL_SYSTEM_SYMPTOM_DETAILS',
 'Additional system symptom details',
 'Details of additional system symptoms.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 45. HPI COMPLETION OBJECTIVES
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('HPI_CHARACTERISTICS_COMPLETE',
 'HPI symptom characteristics complete',
 'Whether relevant symptom characteristics have been captured.',
 'boolean', true),

('HPI_ASSOCIATED_SYMPTOMS_COMPLETE',
 'HPI associated symptoms complete',
 'Whether relevant associated symptoms have been explored.',
 'boolean', true),

('HPI_RELEVANT_HISTORY_COMPLETE',
 'HPI relevant history complete',
 'Whether relevant past, medication, allergy and exposure history has been captured.',
 'boolean', true),

('HPI_RISK_FACTORS_COMPLETE',
 'HPI risk factors complete',
 'Whether relevant risk factors have been explored.',
 'boolean', true),

('HPI_COMPLICATIONS_COMPLETE',
 'HPI complications complete',
 'Whether relevant complication features have been explored.',
 'boolean', true),

('HPI_HEALTH_SEEKING_COMPLETE',
 'HPI health seeking complete',
 'Whether previous healthcare-seeking and treatment have been captured.',
 'boolean', true),

('HPI_FUNCTIONAL_IMPACT_COMPLETE',
 'HPI functional impact complete',
 'Whether functional impact has been captured.',
 'boolean', true),

('HPI_COMPLETENESS',
 'HPI completeness',
 'Overall HPI completion status.',
 'coded', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 46. SPECIFIC SYSTEMIC RISK FACTORS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('IMMUNIZATION_RISK',
 'Immunization risk',
 'Relevant incomplete/missed immunization risk.',
 'boolean', true),

('MALNUTRITION_RISK',
 'Malnutrition risk',
 'Risk of malnutrition.',
 'boolean', true),

('IMMUNOCOMPROMISED_STATE',
 'Immunocompromised state',
 'Clinically relevant immunocompromised state.',
 'boolean', true),

('THROMBOSIS_HISTORY',
 'Thrombosis history',
 'Previous venous or arterial thrombosis.',
 'boolean', true),

('BLEEDING_DISORDER_HISTORY',
 'Bleeding disorder history',
 'Known bleeding disorder.',
 'boolean', true),

('RECENT_IMMOBILIZATION',
 'Recent immobilization',
 'Recent clinically significant immobilization.',
 'boolean', true),

('RECENT_TRAVEL',
 'Recent travel',
 'Recent travel relevant to clinical risk.',
 'boolean', true),

('RECENT_SURGERY',
 'Recent surgery',
 'Recent surgical procedure.',
 'boolean', true),

('RECENT_DELIVERY',
 'Recent delivery',
 'Recent childbirth.',
 'boolean', true),

('RECENT_ABORTION',
 'Recent abortion',
 'Recent abortion/miscarriage.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 47. RENAL / FLUID / ELECTROLYTE CLINICAL FACTS
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('FLUID_INTAKE',
 'Fluid intake',
 'Measured or estimated fluid intake.',
 'quantity', true),

('FLUID_OUTPUT',
 'Fluid output',
 'Measured or estimated fluid output.',
 'quantity', true),

('FLUID_BALANCE',
 'Fluid balance',
 'Net fluid balance.',
 'quantity', true),

('OLIGURIA',
 'Oliguria',
 'Reduced urine output consistent with oliguria.',
 'boolean', true),

('ANURIA',
 'Anuria',
 'Absent/minimal urine output.',
 'boolean', true),

('POLYURIA',
 'Polyuria',
 'Excessive urine output.',
 'boolean', true),

('ELECTROLYTE_ABNORMALITY',
 'Electrolyte abnormality',
 'Clinically relevant electrolyte abnormality.',
 'boolean', true),

('ACID_BASE_ABNORMALITY',
 'Acid-base abnormality',
 'Clinically relevant acid-base abnormality.',
 'boolean', true),

('ACUTE_KIDNEY_INJURY',
 'Acute kidney injury',
 'Clinically established acute kidney injury.',
 'boolean', true),

('CHRONIC_KIDNEY_DISEASE',
 'Chronic kidney disease',
 'Known chronic kidney disease.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 48. ENDOCRINE / METABOLIC
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('POLYDIPSIA',
 'Polydipsia',
 'Excessive thirst.',
 'boolean', true),

('POLYURIA_SYMPTOM',
 'Polyuria symptom',
 'Excessive urination reported by patient.',
 'boolean', true),

('POLYPHAGIA',
 'Polyphagia',
 'Excessive hunger.',
 'boolean', true),

('HEAT_INTOLERANCE',
 'Heat intolerance',
 'Heat intolerance.',
 'boolean', true),

('COLD_INTOLERANCE',
 'Cold intolerance',
 'Cold intolerance.',
 'boolean', true),

('GOITRE_PRESENT',
 'Goitre',
 'Enlarged thyroid.',
 'boolean', true),

('HYPOGLYCEMIA_SYMPTOMS',
 'Hypoglycemia symptoms',
 'Symptoms suggestive of hypoglycemia.',
 'boolean', true),

('HYPERGLYCEMIA_SYMPTOMS',
 'Hyperglycemia symptoms',
 'Symptoms suggestive of hyperglycemia.',
 'boolean', true),

('THYROID_DISEASE_HISTORY',
 'Thyroid disease history',
 'Known thyroid disease.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 49. ONCOLOGY
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('LUMP_PRESENT',
 'Lump present',
 'Patient-reported or observed lump/mass.',
 'boolean', true),

('LUMP_DURATION',
 'Lump duration',
 'Duration of lump.',
 'quantity', true),

('LUMP_GROWTH',
 'Lump growth',
 'Change in size of lump.',
 'coded', true),

('NIGHT_SWEATS_ONCOLOGY',
 'Oncology night sweats',
 'Night sweats relevant to malignancy assessment.',
 'boolean', true),

('UNEXPLAINED_WEIGHT_LOSS',
 'Unexplained weight loss',
 'Unexplained weight loss.',
 'boolean', true),

('CANCER_FAMILY_HISTORY',
 'Cancer family history',
 'Family history of cancer.',
 'boolean', true),

('PREVIOUS_MALIGNANCY',
 'Previous malignancy',
 'Previous malignancy.',
 'boolean', true),

('CANCER_TREATMENT_HISTORY',
 'Cancer treatment history',
 'Previous cancer-directed therapy.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 50. PROCEDURAL / PERIOPERATIVE
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('PREOPERATIVE_ASSESSMENT_COMPLETE',
 'Preoperative assessment complete',
 'Whether preoperative assessment has been completed.',
 'boolean', true),

('ASA_CLASS',
 'ASA physical status',
 'American Society of Anesthesiologists physical status classification.',
 'coded', true),

('AIRWAY_ASSESSMENT',
 'Airway assessment',
 'Preoperative airway assessment.',
 'text', true),

('FASTING_STATUS',
 'Fasting status',
 'Current fasting status.',
 'coded', true),

('ANTICOAGULANT_USE',
 'Anticoagulant use',
 'Current anticoagulant therapy.',
 'boolean', true),

('ANTIPLATELET_USE',
 'Antiplatelet use',
 'Current antiplatelet therapy.',
 'boolean', true),

('BLEEDING_RISK',
 'Bleeding risk',
 'Clinical bleeding risk.',
 'coded', true),

('ANESTHETIC_RISK',
 'Anesthetic risk',
 'Overall anesthetic risk.',
 'coded', true),

('SURGICAL_SITE',
 'Surgical site',
 'Planned or actual surgical site.',
 'coded', true),

('OPERATIVE_DIAGNOSIS',
 'Operative diagnosis',
 'Diagnosis recorded for operation.',
 'text', true),

('OPERATIVE_FINDINGS',
 'Operative findings',
 'Findings at operation.',
 'text', true),

('OPERATIVE_COMPLICATION',
 'Operative complication',
 'Complication occurring during surgery.',
 'text', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 51. REHABILITATION / FUNCTION
-- =============================================================================

INSERT INTO clinical.fact_definition
(code, name, description, data_type, is_active)
VALUES

('ADL_INDEPENDENCE',
 'Activities of daily living independence',
 'Level of independence in activities of daily living.',
 'coded', true),

('IADL_INDEPENDENCE',
 'Instrumental activities independence',
 'Level of independence in instrumental activities.',
 'coded', true),

('MOBILITY_LIMITATION',
 'Mobility limitation',
 'Limitation in mobility.',
 'boolean', true),

('COMMUNICATION_LIMITATION',
 'Communication limitation',
 'Limitation in communication.',
 'boolean', true),

('COGNITIVE_FUNCTION',
 'Cognitive function',
 'Current cognitive functional status.',
 'coded', true),

('REHABILITATION_REQUIRED',
 'Rehabilitation required',
 'Whether rehabilitation is required.',
 'boolean', true),

('PHYSIOTHERAPY_REQUIRED',
 'Physiotherapy required',
 'Whether physiotherapy is required.',
 'boolean', true),

('OCCUPATIONAL_THERAPY_REQUIRED',
 'Occupational therapy required',
 'Whether occupational therapy is required.',
 'boolean', true)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 52. FINAL CANONICAL INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_fact_definition_code_lower
    ON clinical.fact_definition(lower(code));

CREATE INDEX IF NOT EXISTS idx_fact_definition_name
    ON clinical.fact_definition(name);


-- =============================================================================
-- 53. UPDATED-AT TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION clinical.set_fact_definition_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_fact_definition_updated_at
ON clinical.fact_definition;


CREATE TRIGGER trg_fact_definition_updated_at
BEFORE UPDATE ON clinical.fact_definition
FOR EACH ROW
EXECUTE FUNCTION clinical.set_fact_definition_updated_at();


-- =============================================================================
-- 54. VALIDATION
-- =============================================================================

DO $$
DECLARE
    total_definitions BIGINT;
BEGIN

    SELECT COUNT(*)
    INTO total_definitions
    FROM clinical.fact_definition
    WHERE is_active = TRUE;

    IF total_definitions < 400 THEN
        RAISE EXCEPTION
            'AMEXAN clinical fact registry incomplete: only % active definitions found',
            total_definitions;
    END IF;

    RAISE NOTICE
        'AMEXAN Universal Clinical Fact Registry READY: % active canonical facts',
        total_definitions;

END;
$$;


-- =============================================================================
-- 55. FACT REGISTRY CONTRACT
--
-- These invariants are deliberately enforced conceptually by the schema and
-- consumed by the CPU:
--
-- 1. Every captured clinical fact MUST resolve to fact_definition.code.
-- 2. A diagnosis MUST NOT be required to create a symptom fact.
-- 3. A symptom fact MUST NOT automatically become a diagnosis.
-- 4. A generated interpretation MUST NOT overwrite the original fact.
-- 5. Measured values retain their original source and timestamp.
-- 6. Patient-reported facts remain distinguishable from clinician observations.
-- 7. Derived scores remain distinguishable from raw observations.
-- 8. Medication dose calculations remain distinguishable from administered dose.
-- 9. Protocol decisions remain distinguishable from clinical facts.
-- 10. Documentation sentences remain a rendered layer, not the fact source.
-- 11. Historical facts must remain auditable.
-- 12. Corrections create traceable changes rather than silently destroying the
--     previous state.
-- 13. Age/life-stage context is resolved by the CPU from date of birth and
--     encounter time; it is not allowed to silently mutate historical facts.
-- 14. Pregnancy context is explicit and must not be inferred solely from sex.
-- 15. Jurisdiction-specific knowledge belongs to governance/protocol layers,
--     while the clinical fact remains universal.
-- 16. Medication prescriptions are orders, not facts about administration.
-- 17. Medication administration is separately captured from prescription.
-- 18. Investigation orders are distinct from investigation results.
-- 19. Differential candidates are distinct from confirmed diagnoses.
-- 20. Severity scores are derived objects and never replace their component
--     clinical observations.
-- 21. Every high-risk recommendation must remain subject to the governance
--     and human-authorization layer.
-- 22. The UI may render facts but may not redefine the canonical fact codes.
-- 23. The CPU resolves applicability, priority, dependencies and context.
-- 24. Documentation is generated only from the canonical clinical state.
-- 25. Provenance remains attached to the clinical computation chain.
-- =============================================================================


SELECT
    'AMEXAN UNIVERSAL CLINICAL FACT REGISTRY READY' AS status,
    COUNT(*) AS active_fact_definitions
FROM clinical.fact_definition
WHERE is_active = TRUE;
