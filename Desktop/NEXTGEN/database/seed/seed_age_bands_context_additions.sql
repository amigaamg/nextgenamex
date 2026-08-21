-- =============================================================================
-- AMEXAN context additions
-- Clinical contexts referenced by context_adaptation_rule seeds but missing
-- from the seed_age_bands context catalogue. Added here so FK constraints on
-- knowledge.context_adaptation_rule(context_code) resolve for all seeds.
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
    'AGE-PRESCHOOL',
    'PRESCHOOL',
    'AGE',
    'Preschool age',
    'Child aged approximately 3-5 years (preschool).',
    TRUE,
    TRUE,
    1.100
),
(
    'AGE-SCHOOL_AGE',
    'SCHOOL_AGE',
    'AGE',
    'School age',
    'Child of school age, approximately 6-12 years.',
    TRUE,
    TRUE,
    1.100
),
(
    'CAREGIVER-HISTORY',
    'CAREGIVER_HISTORY',
    'HISTORIAN',
    'Caregiver history',
    'History obtained from a caregiver rather than the patient directly.',
    TRUE,
    FALSE,
    1.100
),
(
    'COG-IMPAIRMENT',
    'COGNITIVE_IMPAIRMENT',
    'COGNITION',
    'Cognitive impairment',
    'Patient has cognitive impairment affecting history reliability.',
    TRUE,
    TRUE,
    1.400
),
(
    'LACT-LACTATION',
    'LACTATION',
    'LACTATION',
    'Lactation',
    'Patient currently breastfeeding/lactating. Relevant to maternal and infant assessment.',
    TRUE,
    TRUE,
    1.200
),
(
    'REP-PREGNANCY',
    'PREGNANCY',
    'REPRODUCTIVE',
    'Pregnancy',
    'Patient is pregnant. Relevant to obstetric and medication-safety assessment.',
    TRUE,
    TRUE,
    1.500
)
ON CONFLICT DO NOTHING;