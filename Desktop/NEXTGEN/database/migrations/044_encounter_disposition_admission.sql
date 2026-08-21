-- =============================================================================
-- AMEXAN Universal Entry — migration 044: encounter disposition + admission date
-- The registration interview gains two DATA-driven questions at the END of the
-- biodata module:
--
--   BIODATA_ENCOUNTER_TYPE  — inpatient (admitted) vs outpatient (review),
--                             defaulting to INPATIENT (a new encounter is a
--                             hospital admission until the clinician says
--                             otherwise).
--   BIODATA_ADMISSION_DATE  — asked for an INPATIENT so the date of admission
--                             is recorded (vital for a handwritten-style
--                             history and for CC presentation timing: "She
--                             presented today" / "2 days ago").
--
-- Gating: ADMISSION_DATE carries an ENCOUNTER_TYPE=INPATIENT 'applies' context
-- row plus a requirement condition {"fact":{"code":"ENCOUNTER_TYPE",
-- "value":"INPATIENT"}} so it drops out the moment the clinician records an
-- OUTPATIENT disposition. Because the encounter DEFAULTS to inpatient, the
-- date-of-admission card is asked from the very first encounter.
--
-- Idempotent: the migration runner re-applies every file in numeric order, so
-- 043 (which wipes BIODATA_% bindings) always runs before this file and 044
-- rebuilds its own rows afterwards.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. FACT DEFINITIONS
-- ---------------------------------------------------------------------------
INSERT INTO clinical.fact_definition (code, name, description, data_type)
VALUES
  ('ENCOUNTER_TYPE', 'Encounter disposition', 'Whether the patient is admitted (inpatient) or reviewed (outpatient).', 'coded'),
  ('ADMISSION_DATE', 'Date of admission',      'Calendar date the patient was admitted (inpatient).', 'date')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, data_type = EXCLUDED.data_type;

-- ---------------------------------------------------------------------------
-- 2. ENCOUNTER_TYPE CONTEXT (for 'applies'/'excludes' question gating)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.context_type (code, label, description)
VALUES ('ENCOUNTER_TYPE', 'Encounter disposition', 'Inpatient / outpatient disposition of the current encounter.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO knowledge.context_value (context_type_code, value, label, sort_order) VALUES
  ('ENCOUNTER_TYPE', 'INPATIENT',  'Inpatient (admitted)',  1),
  ('ENCOUNTER_TYPE', 'OUTPATIENT', 'Outpatient (review)',   2)
ON CONFLICT (context_type_code, value) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. DEFAULT VALUE COLUMN (questions can preselect an answer in the UI)
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.question ADD COLUMN IF NOT EXISTS default_value text;

-- ---------------------------------------------------------------------------
-- 4. QUESTIONS (priority 15/16 = asked AFTER the 1-14 core biodata cards)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question (question_code, question_type, text, response_type, priority, question_mode, is_active, default_value)
VALUES
  ('BIODATA_ENCOUNTER_TYPE', 'clinical',
   'Is this patient an inpatient (admitted) or an outpatient (review)?',
   'single_choice', 15, 'DIRECT', true, 'INPATIENT'),
  ('BIODATA_ADMISSION_DATE', 'clinical',
   'What is the date of admission? (used for the history and the admission date)',
   'date', 16, 'DIRECT', true, NULL)
ON CONFLICT (question_code) DO UPDATE
  SET text = EXCLUDED.text, response_type = EXCLUDED.response_type,
      priority = EXCLUDED.priority, default_value = EXCLUDED.default_value;

-- (Re)build the bindings for these two questions idempotently.
DELETE FROM knowledge.question_fact
 WHERE question_id IN (SELECT id FROM knowledge.question WHERE question_code IN ('BIODATA_ENCOUNTER_TYPE', 'BIODATA_ADMISSION_DATE'));
DELETE FROM knowledge.answer_option
 WHERE question_id IN (SELECT id FROM knowledge.question WHERE question_code IN ('BIODATA_ENCOUNTER_TYPE', 'BIODATA_ADMISSION_DATE'));
DELETE FROM knowledge.question_requirement
 WHERE question_id IN (SELECT id FROM knowledge.question WHERE question_code IN ('BIODATA_ENCOUNTER_TYPE', 'BIODATA_ADMISSION_DATE'));
DELETE FROM knowledge.question_context
 WHERE question_id IN (SELECT id FROM knowledge.question WHERE question_code IN ('BIODATA_ENCOUNTER_TYPE', 'BIODATA_ADMISSION_DATE'));
DELETE FROM knowledge.question_module_member
 WHERE question_id IN (SELECT id FROM knowledge.question WHERE question_code IN ('BIODATA_ENCOUNTER_TYPE', 'BIODATA_ADMISSION_DATE'));

-- Raw-value (date) question → fact binding.
INSERT INTO knowledge.question_fact (question_id, fact_definition_code, unit_code)
SELECT q.id, f.fact_code, f.unit
  FROM knowledge.question q
  CROSS JOIN (VALUES
    ('BIODATA_ADMISSION_DATE', 'ADMISSION_DATE', NULL)
  ) AS f(question_code, fact_code, unit)
 WHERE q.question_code = f.question_code
ON CONFLICT (question_id, fact_definition_code) DO NOTHING;

-- Module membership (both belong to the BIODATA registration interview).
INSERT INTO knowledge.question_module_member (module_code, question_id, sort_order)
SELECT 'BIODATA', q.id, q.priority
  FROM knowledge.question q
 WHERE q.question_code IN ('BIODATA_ENCOUNTER_TYPE', 'BIODATA_ADMISSION_DATE')
ON CONFLICT (module_code, question_id) DO NOTHING;

-- Choice question options + answer → fact mappings.
INSERT INTO knowledge.answer_option (question_id, answer_code, label, value_text, sort_order, is_active)
SELECT q.id, o.answer_code, o.label, o.value_text, o.sort_order, true
  FROM knowledge.question q
  CROSS JOIN (VALUES
    ('BIODATA_ENCOUNTER_TYPE', 'INPATIENT',  'Inpatient (admitted)', 'INPATIENT',  1),
    ('BIODATA_ENCOUNTER_TYPE', 'OUTPATIENT', 'Outpatient (review)', 'OUTPATIENT', 2)
  ) AS o(question_code, answer_code, label, value_text, sort_order)
 WHERE q.question_code = o.question_code
ON CONFLICT (question_id, answer_code) DO NOTHING;

INSERT INTO knowledge.fact_mapping (answer_option_id, fact_definition_code, value)
SELECT ao.id, fm.fact_code, fm.value
  FROM knowledge.answer_option ao
  JOIN knowledge.question q ON q.id = ao.question_id
  CROSS JOIN (VALUES
    ('BIODATA_ENCOUNTER_TYPE', 'INPATIENT',  'ENCOUNTER_TYPE', 'INPATIENT'),
    ('BIODATA_ENCOUNTER_TYPE', 'OUTPATIENT', 'ENCOUNTER_TYPE', 'OUTPATIENT')
  ) AS fm(question_code, answer_code, fact_code, value)
 WHERE ao.answer_code = fm.answer_code AND q.question_code = fm.question_code
ON CONFLICT (answer_option_id, fact_definition_code, value) DO NOTHING;

-- Requirements: the disposition card is always asked (unconditional, so the
-- BIODATA module always surfaces it); the admission date is asked only while
-- the disposition is INPATIENT (unknown disposition never suppresses it).
INSERT INTO knowledge.question_requirement (question_id, requirement_type, requirement_code, required, requirement_level, condition, priority)
SELECT q.id, 'requires_question_answer', q.question_code,
       r.requirement_level IN ('mandatory', 'safety'),
       r.requirement_level, r.condition::jsonb, r.priority
  FROM knowledge.question q
  CROSS JOIN (VALUES
    ('BIODATA_ENCOUNTER_TYPE', 'conditionally_required', NULL, 30),
    ('BIODATA_ADMISSION_DATE', 'conditionally_required',
     '{"fact":{"code":"ENCOUNTER_TYPE","value":"INPATIENT"}}', 40)
  ) AS r(question_code, requirement_level, condition, priority)
 WHERE q.question_code = r.question_code;

-- 'applies' context: ADMISSION_DATE is FOR inpatient encounters.
INSERT INTO knowledge.question_context (question_id, context_type_code, context_value_id, applicability, priority)
SELECT q.id, c.context_type_code, cv.id, c.applicability, c.priority
  FROM knowledge.question q
  CROSS JOIN (VALUES
    ('BIODATA_ADMISSION_DATE', 'ENCOUNTER_TYPE', 'INPATIENT', 'applies', 10)
  ) AS c(question_code, context_type_code, context_value, applicability, priority)
  JOIN knowledge.context_value cv
    ON cv.context_type_code = c.context_type_code AND cv.value = c.context_value
 WHERE q.question_code = c.question_code
ON CONFLICT (question_id, context_type_code, context_value_id) DO NOTHING;

SELECT 'Encounter disposition + admission date seeded';
-- =============================================================================
-- AMEXAN — 044: UNIVERSAL ENCOUNTER CLASSIFICATION + ADMISSION LIFECYCLE
--
-- PURPOSE
-- -------
-- Establishes the clinical encounter lifecycle used by the AMEXAN Clinical
-- Operating System.
--
-- IMPORTANT ARCHITECTURAL RULES
-- -----------------------------
-- 1. Patient identity != encounter identity.
-- 2. Encounter classification != admission status.
-- 3. A new encounter MUST NOT silently become an inpatient admission.
-- 4. Encounter state changes are auditable.
-- 5. Admission is a clinical event, not merely a biodata field.
-- 6. Admission date/time is timestamped.
-- 7. Emergency, observation and day-case encounters are first-class states.
-- 8. Historical values must remain recoverable.
-- 9. Unknown/unclassified is a legitimate initial state.
-- 10. Clinical facts must remain compatible with the universal fact engine.
--
-- This migration is intentionally data-driven and idempotent.
-- =============================================================================


-- =============================================================================
-- 1. FACT DEFINITIONS
-- =============================================================================

INSERT INTO clinical.fact_definition
    (code, name, description, data_type, is_active)
VALUES

    (
        'ENCOUNTER_CLASS',
        'Encounter class',
        'Clinical class of the current encounter: outpatient, inpatient,
         emergency, observation, day-case, home, telemedicine or other.',
        'coded',
        true
    ),

    (
        'ENCOUNTER_STATUS',
        'Encounter status',
        'Lifecycle status of the encounter.',
        'coded',
        true
    ),

    (
        'ADMISSION_STATUS',
        'Admission status',
        'Whether the patient has been formally admitted.',
        'coded',
        true
    ),

    (
        'ADMISSION_DATE',
        'Admission date',
        'Calendar date on which formal admission occurred.',
        'date',
        true
    ),

    (
        'ADMISSION_DATETIME',
        'Admission date and time',
        'Exact date and time of formal admission.',
        'datetime',
        true
    ),

    (
        'ENCOUNTER_START_DATETIME',
        'Encounter start date and time',
        'Date and time the current encounter began.',
        'datetime',
        true
    ),

    (
        'ENCOUNTER_END_DATETIME',
        'Encounter end date and time',
        'Date and time the current encounter ended.',
        'datetime',
        true
    ),

    (
        'ADMISSION_SOURCE',
        'Admission source',
        'Where or how the patient entered the hospital episode.',
        'coded',
        true
    ),

    (
        'ADMISSION_REASON',
        'Reason for admission',
        'Clinical or operational reason documented for admission.',
        'text',
        true
    ),

    (
        'ADMITTING_SERVICE',
        'Admitting service',
        'Clinical service responsible for the admission.',
        'coded',
        true
    ),

    (
        'ADMITTING_CLINICIAN',
        'Admitting clinician',
        'Clinician responsible for initiating the admission.',
        'coded',
        true
    ),

    (
        'INITIAL_LOCATION',
        'Initial clinical location',
        'Initial ward, department, unit or clinical location.',
        'coded',
        true
    ),

    (
        'BED_ASSIGNMENT',
        'Bed assignment',
        'Initial assigned bed or treatment space.',
        'text',
        true
    ),

    (
        'DISCHARGE_DATE',
        'Discharge date',
        'Date of discharge from the encounter.',
        'date',
        true
    ),

    (
        'DISCHARGE_DATETIME',
        'Discharge date and time',
        'Exact date and time the encounter was discharged.',
        'datetime',
        true
    ),

    (
        'DISCHARGE_DISPOSITION',
        'Discharge disposition',
        'Destination or disposition following completion of the encounter.',
        'coded',
        true
    ),

    (
        'TRANSFER_REQUIRED',
        'Transfer required',
        'Whether the patient requires transfer to another clinical service
         or facility.',
        'boolean',
        true
    ),

    (
        'TRANSFER_DESTINATION',
        'Transfer destination',
        'Destination service, ward or facility for transfer.',
        'coded',
        true
    )

ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    data_type = EXCLUDED.data_type,
    is_active = EXCLUDED.is_active;


-- =============================================================================
-- 2. ENCOUNTER CONTEXT TYPE
-- =============================================================================

INSERT INTO knowledge.context_type
    (code, label, description)
VALUES
(
    'ENCOUNTER_CLASS',
    'Encounter class',
    'Classification of the current clinical encounter.'
),
(
    'ENCOUNTER_STATUS',
    'Encounter status',
    'Current lifecycle state of the clinical encounter.'
),
(
    'ADMISSION_STATUS',
    'Admission status',
    'Whether the patient has formally been admitted.'
)

ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 3. ENCOUNTER CLASS VALUES
-- =============================================================================

INSERT INTO knowledge.context_value
    (context_type_code, value, label, sort_order)
VALUES

    (
        'ENCOUNTER_CLASS',
        'UNCLASSIFIED',
        'Not yet classified',
        1
    ),

    (
        'ENCOUNTER_CLASS',
        'OUTPATIENT',
        'Outpatient',
        2
    ),

    (
        'ENCOUNTER_CLASS',
        'INPATIENT',
        'Inpatient',
        3
    ),

    (
        'ENCOUNTER_CLASS',
        'EMERGENCY',
        'Emergency',
        4
    ),

    (
        'ENCOUNTER_CLASS',
        'OBSERVATION',
        'Observation',
        5
    ),

    (
        'ENCOUNTER_CLASS',
        'DAY_CASE',
        'Day case',
        6
    ),

    (
        'ENCOUNTER_CLASS',
        'HOME',
        'Home/community encounter',
        7
    ),

    (
        'ENCOUNTER_CLASS',
        'TELEMEDICINE',
        'Telemedicine',
        8
    ),

    (
        'ENCOUNTER_CLASS',
        'OTHER',
        'Other',
        9
    )

ON CONFLICT (context_type_code, value) DO NOTHING;


-- =============================================================================
-- 4. ENCOUNTER STATUS VALUES
-- =============================================================================

INSERT INTO knowledge.context_value
    (context_type_code, value, label, sort_order)
VALUES

    (
        'ENCOUNTER_STATUS',
        'OPEN',
        'Open',
        1
    ),

    (
        'ENCOUNTER_STATUS',
        'ACTIVE',
        'Active',
        2
    ),

    (
        'ENCOUNTER_STATUS',
        'ON_HOLD',
        'On hold',
        3
    ),

    (
        'ENCOUNTER_STATUS',
        'COMPLETED',
        'Completed',
        4
    ),

    (
        'ENCOUNTER_STATUS',
        'CANCELLED',
        'Cancelled',
        5
    ),

    (
        'ENCOUNTER_STATUS',
        'ENTERED_IN_ERROR',
        'Entered in error',
        6
    )

ON CONFLICT (context_type_code, value) DO NOTHING;


-- =============================================================================
-- 5. ADMISSION STATUS VALUES
-- =============================================================================

INSERT INTO knowledge.context_value
    (context_type_code, value, label, sort_order)
VALUES

    (
        'ADMISSION_STATUS',
        'NOT_ADMITTED',
        'Not admitted',
        1
    ),

    (
        'ADMISSION_STATUS',
        'PENDING',
        'Admission pending',
        2
    ),

    (
        'ADMISSION_STATUS',
        'ADMITTED',
        'Admitted',
        3
    ),

    (
        'ADMISSION_STATUS',
        'DISCHARGED',
        'Discharged',
        4
    ),

    (
        'ADMISSION_STATUS',
        'TRANSFERRED',
        'Transferred',
        5
    )

ON CONFLICT (context_type_code, value) DO NOTHING;


-- =============================================================================
-- 6. ENCOUNTER CLASS QUESTION
-- =============================================================================

INSERT INTO knowledge.question
(
    question_code,
    question_type,
    text,
    response_type,
    priority,
    question_mode,
    is_active,
    default_value
)
VALUES
(
    'BIODATA_ENCOUNTER_CLASS',
    'clinical',
    'What type of clinical encounter is this?',
    'single_choice',
    15,
    'DIRECT',
    true,
    'UNCLASSIFIED'
)

ON CONFLICT (question_code)
DO UPDATE SET
    text = EXCLUDED.text,
    response_type = EXCLUDED.response_type,
    priority = EXCLUDED.priority,
    question_mode = EXCLUDED.question_mode,
    is_active = EXCLUDED.is_active,
    default_value = EXCLUDED.default_value;


-- =============================================================================
-- 7. ADMISSION STATUS QUESTION
-- =============================================================================

INSERT INTO knowledge.question
(
    question_code,
    question_type,
    text,
    response_type,
    priority,
    question_mode,
    is_active,
    default_value
)
VALUES
(
    'BIODATA_ADMISSION_STATUS',
    'clinical',
    'What is the current admission status?',
    'single_choice',
    16,
    'DIRECT',
    true,
    'NOT_ADMITTED'
)

ON CONFLICT (question_code)
DO UPDATE SET
    text = EXCLUDED.text,
    response_type = EXCLUDED.response_type,
    priority = EXCLUDED.priority,
    question_mode = EXCLUDED.question_mode,
    is_active = EXCLUDED.is_active,
    default_value = EXCLUDED.default_value;


-- =============================================================================
-- 8. ADMISSION DATE/TIME
-- =============================================================================

INSERT INTO knowledge.question
(
    question_code,
    question_type,
    text,
    response_type,
    priority,
    question_mode,
    is_active,
    default_value
)
VALUES
(
    'BIODATA_ADMISSION_DATETIME',
    'clinical',
    'What was the date and time of admission?',
    'datetime',
    17,
    'DIRECT',
    true,
    NULL
)

ON CONFLICT (question_code)
DO UPDATE SET
    text = EXCLUDED.text,
    response_type = EXCLUDED.response_type,
    priority = EXCLUDED.priority,
    question_mode = EXCLUDED.question_mode,
    is_active = EXCLUDED.is_active,
    default_value = EXCLUDED.default_value;


-- =============================================================================
-- 9. ADMISSION SOURCE
-- =============================================================================

INSERT INTO knowledge.question
(
    question_code,
    question_type,
    text,
    response_type,
    priority,
    question_mode,
    is_active
)
VALUES
(
    'BIODATA_ADMISSION_SOURCE',
    'clinical',
    'How did the patient arrive for this encounter?',
    'single_choice',
    18,
    'DIRECT',
    true
)

ON CONFLICT (question_code)
DO UPDATE SET
    text = EXCLUDED.text,
    response_type = EXCLUDED.response_type,
    priority = EXCLUDED.priority,
    question_mode = EXCLUDED.question_mode,
    is_active = EXCLUDED.is_active;


-- =============================================================================
-- 10. ADMISSION REASON
-- =============================================================================

INSERT INTO knowledge.question
(
    question_code,
    question_type,
    text,
    response_type,
    priority,
    question_mode,
    is_active
)
VALUES
(
    'BIODATA_ADMISSION_REASON',
    'clinical',
    'What is the documented reason for admission?',
    'text',
    19,
    'DIRECT',
    true
)

ON CONFLICT (question_code)
DO UPDATE SET
    text = EXCLUDED.text,
    response_type = EXCLUDED.response_type,
    priority = EXCLUDED.priority,
    question_mode = EXCLUDED.question_mode,
    is_active = EXCLUDED.is_active;


-- =============================================================================
-- 11. ADMISSION SOURCE OPTIONS
-- =============================================================================

INSERT INTO knowledge.answer_option
(
    question_id,
    answer_code,
    label,
    value_text,
    sort_order,
    is_active
)
SELECT
    q.id,
    o.answer_code,
    o.label,
    o.value_text,
    o.sort_order,
    true
FROM knowledge.question q
CROSS JOIN
(
    VALUES
    (
        'REFERRED',
        'Referred from another facility/service',
        'REFERRED',
        1
    ),
    (
        'EMERGENCY_DEPARTMENT',
        'Emergency department',
        'EMERGENCY_DEPARTMENT',
        2
    ),
    (
        'OUTPATIENT_CLINIC',
        'Outpatient clinic',
        'OUTPATIENT_CLINIC',
        3
    ),
    (
        'DIRECT',
        'Direct presentation',
        'DIRECT',
        4
    ),
    (
        'TRANSFER',
        'Transfer from another facility/service',
        'TRANSFER',
        5
    ),
    (
        'BIRTH',
        'Birth/newborn admission',
        'BIRTH',
        6
    ),
    (
        'OTHER',
        'Other',
        'OTHER',
        7
    )
) AS o(answer_code, label, value_text, sort_order)
WHERE q.question_code = 'BIODATA_ADMISSION_SOURCE'

ON CONFLICT (question_id, answer_code) DO NOTHING;


-- =============================================================================
-- 12. ENCOUNTER CLASS OPTIONS
-- =============================================================================

INSERT INTO knowledge.answer_option
(
    question_id,
    answer_code,
    label,
    value_text,
    sort_order,
    is_active
)
SELECT
    q.id,
    o.answer_code,
    o.label,
    o.value_text,
    o.sort_order,
    true
FROM knowledge.question q
CROSS JOIN
(
    VALUES
    ('UNCLASSIFIED', 'Not yet classified', 'UNCLASSIFIED', 1),
    ('OUTPATIENT',   'Outpatient',         'OUTPATIENT',   2),
    ('INPATIENT',    'Inpatient',          'INPATIENT',    3),
    ('EMERGENCY',    'Emergency',          'EMERGENCY',    4),
    ('OBSERVATION',  'Observation',        'OBSERVATION',  5),
    ('DAY_CASE',     'Day case',           'DAY_CASE',     6),
    ('HOME',         'Home/community',      'HOME',         7),
    ('TELEMEDICINE', 'Telemedicine',       'TELEMEDICINE', 8),
    ('OTHER',        'Other',              'OTHER',        9)
) AS o(answer_code, label, value_text, sort_order)
WHERE q.question_code = 'BIODATA_ENCOUNTER_CLASS'

ON CONFLICT (question_id, answer_code) DO NOTHING;


-- =============================================================================
-- 13. ADMISSION STATUS OPTIONS
-- =============================================================================

INSERT INTO knowledge.answer_option
(
    question_id,
    answer_code,
    label,
    value_text,
    sort_order,
    is_active
)
SELECT
    q.id,
    o.answer_code,
    o.label,
    o.value_text,
    o.sort_order,
    true
FROM knowledge.question q
CROSS JOIN
(
    VALUES
    ('NOT_ADMITTED', 'Not admitted',       'NOT_ADMITTED', 1),
    ('PENDING',      'Admission pending',  'PENDING',      2),
    ('ADMITTED',     'Admitted',           'ADMITTED',     3),
    ('DISCHARGED',   'Discharged',         'DISCHARGED',   4),
    ('TRANSFERRED',  'Transferred',        'TRANSFERRED',  5)
) AS o(answer_code, label, value_text, sort_order)
WHERE q.question_code = 'BIODATA_ADMISSION_STATUS'

ON CONFLICT (question_id, answer_code) DO NOTHING;


-- =============================================================================
-- 14. FACT MAPPINGS
-- =============================================================================

INSERT INTO knowledge.fact_mapping
(
    answer_option_id,
    fact_definition_code,
    value
)
SELECT
    ao.id,
    fm.fact_code,
    fm.value
FROM knowledge.answer_option ao
JOIN knowledge.question q
    ON q.id = ao.question_id
CROSS JOIN
(
    VALUES
    ('BIODATA_ENCOUNTER_CLASS','UNCLASSIFIED','ENCOUNTER_CLASS','UNCLASSIFIED'),
    ('BIODATA_ENCOUNTER_CLASS','OUTPATIENT','ENCOUNTER_CLASS','OUTPATIENT'),
    ('BIODATA_ENCOUNTER_CLASS','INPATIENT','ENCOUNTER_CLASS','INPATIENT'),
    ('BIODATA_ENCOUNTER_CLASS','EMERGENCY','ENCOUNTER_CLASS','EMERGENCY'),
    ('BIODATA_ENCOUNTER_CLASS','OBSERVATION','ENCOUNTER_CLASS','OBSERVATION'),
    ('BIODATA_ENCOUNTER_CLASS','DAY_CASE','ENCOUNTER_CLASS','DAY_CASE'),
    ('BIODATA_ENCOUNTER_CLASS','HOME','ENCOUNTER_CLASS','HOME'),
    ('BIODATA_ENCOUNTER_CLASS','TELEMEDICINE','ENCOUNTER_CLASS','TELEMEDICINE'),
    ('BIODATA_ENCOUNTER_CLASS','OTHER','ENCOUNTER_CLASS','OTHER'),

    ('BIODATA_ADMISSION_STATUS','NOT_ADMITTED','ADMISSION_STATUS','NOT_ADMITTED'),
    ('BIODATA_ADMISSION_STATUS','PENDING','ADMISSION_STATUS','PENDING'),
    ('BIODATA_ADMISSION_STATUS','ADMITTED','ADMISSION_STATUS','ADMITTED'),
    ('BIODATA_ADMISSION_STATUS','DISCHARGED','ADMISSION_STATUS','DISCHARGED'),
    ('BIODATA_ADMISSION_STATUS','TRANSFERRED','ADMISSION_STATUS','TRANSFERRED'),

    ('BIODATA_ADMISSION_SOURCE','REFERRED','ADMISSION_SOURCE','REFERRED'),
    ('BIODATA_ADMISSION_SOURCE','EMERGENCY_DEPARTMENT','ADMISSION_SOURCE','EMERGENCY_DEPARTMENT'),
    ('BIODATA_ADMISSION_SOURCE','OUTPATIENT_CLINIC','ADMISSION_SOURCE','OUTPATIENT_CLINIC'),
    ('BIODATA_ADMISSION_SOURCE','DIRECT','ADMISSION_SOURCE','DIRECT'),
    ('BIODATA_ADMISSION_SOURCE','TRANSFER','ADMISSION_SOURCE','TRANSFER'),
    ('BIODATA_ADMISSION_SOURCE','BIRTH','ADMISSION_SOURCE','BIRTH'),
    ('BIODATA_ADMISSION_SOURCE','OTHER','ADMISSION_SOURCE','OTHER')
) AS fm(question_code, answer_code, fact_code, value)
WHERE q.question_code = fm.question_code
  AND ao.answer_code = fm.answer_code

ON CONFLICT (answer_option_id, fact_definition_code, value)
DO NOTHING;


-- =============================================================================
-- 15. RAW QUESTION → FACT BINDINGS
-- =============================================================================

INSERT INTO knowledge.question_fact
(
    question_id,
    fact_definition_code,
    unit_code
)
SELECT
    q.id,
    f.fact_code,
    f.unit
FROM knowledge.question q
CROSS JOIN
(
    VALUES
    ('BIODATA_ADMISSION_DATETIME','ADMISSION_DATETIME',NULL),
    ('BIODATA_ADMISSION_REASON','ADMISSION_REASON',NULL)
) AS f(question_code, fact_code, unit)
WHERE q.question_code = f.question_code

ON CONFLICT (question_id, fact_definition_code)
DO NOTHING;


-- =============================================================================
-- 16. BIODATA MODULE MEMBERSHIP
-- =============================================================================

INSERT INTO knowledge.question_module_member
(
    module_code,
    question_id,
    sort_order
)
SELECT
    'BIODATA',
    q.id,
    q.priority
FROM knowledge.question q
WHERE q.question_code IN
(
    'BIODATA_ENCOUNTER_CLASS',
    'BIODATA_ADMISSION_STATUS',
    'BIODATA_ADMISSION_DATETIME',
    'BIODATA_ADMISSION_SOURCE',
    'BIODATA_ADMISSION_REASON'
)

ON CONFLICT (module_code, question_id)
DO NOTHING;


-- =============================================================================
-- 17. REQUIREMENTS
-- =============================================================================

DELETE FROM knowledge.question_requirement
WHERE question_id IN
(
    SELECT id
    FROM knowledge.question
    WHERE question_code IN
    (
        'BIODATA_ENCOUNTER_CLASS',
        'BIODATA_ADMISSION_STATUS',
        'BIODATA_ADMISSION_DATETIME',
        'BIODATA_ADMISSION_SOURCE',
        'BIODATA_ADMISSION_REASON'
    )
);


INSERT INTO knowledge.question_requirement
(
    question_id,
    requirement_type,
    requirement_code,
    required,
    requirement_level,
    condition,
    priority
)
SELECT
    q.id,
    'requires_question_answer',
    q.question_code,
    r.requirement_level IN ('mandatory', 'safety'),
    r.requirement_level,
    r.condition::jsonb,
    r.priority
FROM knowledge.question q
CROSS JOIN
(
    VALUES
    (
        'BIODATA_ENCOUNTER_CLASS',
        'mandatory',
        NULL,
        30
    ),
    (
        'BIODATA_ADMISSION_STATUS',
        'mandatory',
        NULL,
        30
    ),
    (
        'BIODATA_ADMISSION_DATETIME',
        'conditionally_required',
        '{"fact":{"code":"ADMISSION_STATUS","value":"ADMITTED"}}',
        40
    ),
    (
        'BIODATA_ADMISSION_SOURCE',
        'conditionally_required',
        '{"fact":{"code":"ADMISSION_STATUS","value":"ADMITTED"}}',
        40
    ),
    (
        'BIODATA_ADMISSION_REASON',
        'conditionally_required',
        '{"fact":{"code":"ADMISSION_STATUS","value":"ADMITTED"}}',
        40
    )
) AS r(question_code, requirement_level, condition, priority)
WHERE q.question_code = r.question_code;


-- =============================================================================
-- 18. CONTEXT GATING
-- =============================================================================

DELETE FROM knowledge.question_context
WHERE question_id IN
(
    SELECT id
    FROM knowledge.question
    WHERE question_code IN
    (
        'BIODATA_ADMISSION_DATETIME',
        'BIODATA_ADMISSION_SOURCE',
        'BIODATA_ADMISSION_REASON'
    )
);


INSERT INTO knowledge.question_context
(
    question_id,
    context_type_code,
    context_value_id,
    applicability,
    priority
)
SELECT
    q.id,
    'ADMISSION_STATUS',
    cv.id,
    'applies',
    10
FROM knowledge.question q
JOIN knowledge.context_value cv
    ON cv.context_type_code = 'ADMISSION_STATUS'
   AND cv.value = 'ADMITTED'
WHERE q.question_code IN
(
    'BIODATA_ADMISSION_DATETIME',
    'BIODATA_ADMISSION_SOURCE',
    'BIODATA_ADMISSION_REASON'
)

ON CONFLICT
(
    question_id,
    context_type_code,
    context_value_id
)
DO NOTHING;


-- =============================================================================
-- 19. CLINICAL INVARIANTS
-- =============================================================================
--
-- These are documented here even if enforcement is implemented in the CPU.
--
-- INV-044-001:
-- An encounter may not be silently classified as inpatient.
--
-- INV-044-002:
-- ADMISSION_DATETIME requires ADMISSION_STATUS = ADMITTED.
--
-- INV-044-003:
-- ADMISSION_DATETIME cannot be later than the current clinical time unless
-- an explicit future-dated event workflow exists.
--
-- INV-044-004:
-- DISCHARGE_DATETIME must be >= ADMISSION_DATETIME.
--
-- INV-044-005:
-- An encounter marked DISCHARGED must have a discharge disposition.
--
-- INV-044-006:
-- An encounter marked TRANSFERRED must have a transfer destination.
--
-- INV-044-007:
-- Changing encounter classification must preserve the previous state in
-- the clinical audit/event stream.
--
-- INV-044-008:
-- Patient identity facts must never be mutated as a side effect of changing
-- encounter state.
--
-- INV-044-009:
-- Admission is an encounter event, not a permanent patient attribute.
--
-- INV-044-010:
-- Emergency arrival and formal admission are separate timestamps.
--
-- INV-044-011:
-- Observation does not automatically equal inpatient admission.
--
-- INV-044-012:
-- Day-case does not automatically equal inpatient admission.
--
-- INV-044-013:
-- A telemedicine encounter must never generate a physical bed assignment.
--
-- INV-044-014:
-- A home encounter must never generate a physical admission unless an
-- explicit subsequent admission event occurs.
--
-- =============================================================================


SELECT
    'AMEXAN 044: Universal encounter classification + admission lifecycle seeded'
    AS migration_result;