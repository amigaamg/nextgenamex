-- =============================================================================
-- ZPD. HPI OBJECTIVE BRIDGES (respiratory battery)
-- =============================================================================
--
-- Maps symptoms and questions to HPI exploration objectives so the CPU can
-- walk a presenting symptom through the clinical flow:
--
--   1  CHARACTERIZE    SOCRATES-style characterization
--   2  CHRONOLOGY      onset / progression / temporal relationships
--   3  ASSOCIATED      clinically relevant associated symptoms
--   4  RULE_IN_OUT     possible diagnosis / differential discriminators
--   5  ETIOLOGY        exposures and precipitants (aetiology)
--   6  RISK            demographic / environmental / medical risk factors
--   7  COMPLICATION    deterioration / complications of likely diagnosis
--   8  SAFETY          red flags and treatment-safety context
--   9  PREVIOUS        previous episodes
--   10 HEALTH_SEEKING  prior consultations / treatment / response
--   11 FUNCTION        impact on work / school / sleep / feeding
--
-- The CPU orders questions by objective sequence_no; within an objective the
-- normal requirement/priority logic still applies.
--
-- Everything references question codes by subselect so a code that has not
-- been seeded yet is skipped (no-op). All inserts are idempotent.

-- =============================================================================
-- 1. SYMPTOM → OBJECTIVE (per-symptom exploration order)
-- =============================================================================

INSERT INTO knowledge.symptom_hpi_objective
    (symptom_id, objective_code, priority, required_mode)
SELECT
    s.id,
    o.objective_code,
    o.priority,
    o.required_mode
FROM knowledge.symptom s
CROSS JOIN (VALUES
    ('CHARACTERIZE',   10, 'always'::text),
    ('CHRONOLOGY',     20, 'always'),
    ('ASSOCIATED',     30, 'core'),
    ('RULE_IN_OUT',    40, 'conditional'),
    ('ETIOLOGY',       50, 'conditional'),
    ('RISK',           60, 'conditional'),
    ('COMPLICATION',   70, 'conditional'),
    ('SAFETY',         80, 'always'),
    ('PREVIOUS',       90, 'optional'),
    ('HEALTH_SEEKING', 100, 'conditional'),
    ('FUNCTION',       110, 'conditional')
) AS o(objective_code, priority, required_mode)
WHERE lower(s.canonical_name) IN ('cough', 'fever', 'dyspnoea', 'chest pain')
ON CONFLICT (symptom_id, objective_code) DO NOTHING;

-- =============================================================================
-- 2. QUESTION → OBJECTIVE
-- =============================================================================
--
-- Each INSERT below populates the objective for every seeded question code in
-- its list. A question may appear under several objectives; the CPU uses the
-- earliest (lowest sequence_no) as its primary phase.

-- ---------------------------------------------------------------------------
-- 2a. CHARACTERIZE — the nature, severity, aggravating/relieving factors
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'CHARACTERIZE', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'COUGH_CHARACTER',
    'COUGH_TIMING',
    'COUGH_TRIGGERS',
    'COUGH_RELIEVING',
    'COUGH_POSITIONAL',
    'COUGH_PRODUCTIVITY',
    'COUGH_SEVERITY',
    'SPUTUM_PRESENT',
    'SPUTUM_CONSISTENCY',
    'SPUTUM_ODOUR',
    'SPUTUM_COLOUR',
    'FEVER_PATTERN',
    'DYSPNOEA_SEVERITY',
    'ORTHOPNOEA_ASK',
    'PND_ASK',
    'BLOOD_IN_SPUTUM'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2b. CHRONOLOGY — onset, duration and temporal relationships
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'CHRONOLOGY', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'COUGH_ONSET',
    'COUGH_DURATION',
    'FEVER_ONSET',
    'DYSPNOEA_ONSET'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2c. ASSOCIATED — associated symptoms that build the clinical picture
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'ASSOCIATED', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'WHEEZE_PRESENT',
    'RHINORRHOEA',
    'SORE_THROAT',
    'HOARSENESS',
    'POSTNASAL_DRIP',
    'VOICE_CHANGE',
    'PLEURITIC_CHEST_PAIN',
    'LEG_SWELLING_ASK',
    'HEARTBURN_ASK',
    'FEVER_PRESENT',
    'DYSPNOEA_PRESENT'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2d. RULE_IN_OUT — diagnostic discriminators for possible dx / ddx
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'RULE_IN_OUT', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'COUGH_PRODUCTIVITY',
    'COUGH_CHARACTER',
    'COUGH_TIMING',
    'COUGH_TRIGGERS',
    'COUGH_POSITIONAL',
    'HEARTBURN_ASK',
    'DYSPNOEA_SEVERITY',
    'ORTHOPNOEA_ASK',
    'PND_ASK',
    'SPUTUM_CONSISTENCY',
    'SPUTUM_COLOUR',
    'BLOOD_IN_SPUTUM',
    'FEVER_PATTERN',
    'FEVER_ONSET'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2e. ETIOLOGY — exposures, precipitants and contextual causes
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'ETIOLOGY', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'ACE_INHIBITOR',
    'OCCUPATIONAL_DUST',
    'BIOMASS_EXPOSURE',
    'ASPIRATION_RISK',
    'DYSPHAGIA',
    'HEARTBURN_ASK',
    'HIV_STATUS',
    'IMMUNOSUPPRESSED',
    'TB_CONTACT'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2f. RISK — demographic / environmental / medical risk factors
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'RISK', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'SMOKING_STATUS',
    'SMOKING_PACK_YEARS',
    'HIV_STATUS',
    'IMMUNOSUPPRESSED',
    'TB_CONTACT',
    'WEIGHT_LOSS',
    'NIGHT_SWEATS',
    'OCCUPATIONAL_DUST',
    'BIOMASS_EXPOSURE'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2g. COMPLICATION — deterioration or complications of likely diagnosis
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'COMPLICATION', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'SEVERE_RESPIRATORY_DISTRESS',
    'STRIDOR_PRESENT',
    'CHEST_INDRAWING',
    'CYANOSIS',
    'ORTHOPNOEA_ASK',
    'PND_ASK',
    'LEG_SWELLING_ASK',
    'SLEEP_DISTURBANCE',
    'WORK_ABSENCE',
    'FEEDING_DIFFICULTY',
    'BLOOD_IN_SPUTUM',
    'PLEURITIC_CHEST_PAIN'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2h. SAFETY — red flags and treatment-safety context
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'SAFETY', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'SEVERE_RESPIRATORY_DISTRESS',
    'STRIDOR_PRESENT',
    'CHEST_INDRAWING',
    'BLOOD_IN_SPUTUM',
    'DYSPNOEA_SEVERITY'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2i. HEALTH_SEEKING — prior consultations, treatment and response
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'HEALTH_SEEKING', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'HEALTH_SEEKING'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2j. FUNCTION — impact on work, school, sleep, feeding
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.question_hpi_objective
    (question_id, objective_code, weight)
SELECT q.id, 'FUNCTION', 1.0
FROM knowledge.question q
WHERE q.question_code IN (
    'SLEEP_DISTURBANCE',
    'WORK_ABSENCE',
    'EXERCISE_INTOLERANCE',
    'FEEDING_DIFFICULTY'
)
ON CONFLICT (question_id, objective_code) DO NOTHING;