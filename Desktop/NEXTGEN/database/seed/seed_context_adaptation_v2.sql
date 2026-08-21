-- =============================================================================
-- AMEXAN H5 — CONTEXT INTELLIGENCE / FORMAT SELECTION RULESET
-- Migration / Seed: 047
--
-- PURPOSE
-- -------
-- This seed defines the AMEXAN Context Adaptation Layer.
--
-- The CPU, NOT the UI and NOT the clinician manually choosing a form, determines
-- which clinical question modules are:
--
--   ACTIVATE      → eligible and promoted into the encounter
--   UNAVAILABLE   → must not be rendered
--   DEACTIVATE    → removed from the active question set
--   MODIFY        → context-specific adaptation of an otherwise valid module
--
-- UNIVERSAL PRINCIPLES
-- --------------------
-- 1. Age is determined from the patient's actual DOB / encounter date.
-- 2. More specific age contexts may coexist with broad age contexts.
-- 3. NEONATE has absolute precedence over generic paediatric logic.
-- 4. INFANT/CHILD/PRESCHOOL/SCHOOL_AGE use paediatric clinical architecture.
-- 5. ADOLESCENT uses adolescent/adult-compatible medicine with adolescent
--    safeguards rather than blindly using adult or infant questions.
-- 6. Pregnancy, postpartum and lactation are state contexts, not age groups.
-- 7. Emergency, inpatient, outpatient and telemedicine are encounter contexts.
-- 8. Cognitive impairment, unconsciousness and caregiver-history contexts alter
--    the method of history acquisition.
-- 9. Context adaptation does NOT diagnose disease.
-- 10. Context adaptation determines what information is clinically appropriate
--     to collect.
-- 11. A suppressed module can only become available when another valid context
--     or clinical rule explicitly authorizes it.
-- 12. The UI must never infer or override CPU authorization.
--
-- CURRENT CANONICAL CONTEXT CODES USED HERE
-- ------------------------------------------
-- AGE:
--   NEONATE
--   INFANT
--   CHILD
--   ADOLESCENT
--   ADULT
--   OLDER_ADULT
--   PRESCHOOL
--   SCHOOL_AGE
--
-- REPRODUCTIVE:
--   PREGNANCY
--   POSTPARTUM
--   LACTATION
--
-- SETTING:
--   EMERGENCY
--   INPATIENT
--   OUTPATIENT
--
-- MODE:
--   TELEMEDICINE
--
-- COMMUNICATION:
--   COGNITIVE_IMPAIRMENT
--   UNCONSCIOUS
--   CAREGIVER_HISTORY
--
-- IMPORTANT
-- ---------
-- This file intentionally does not reference context codes that are not part
-- of the canonical context vocabulary above.
--
-- This migration is designed to be safely re-runnable.
-- =============================================================================

BEGIN;

-- =============================================================================
-- 0. ENSURE THE UNIVERSAL UPDATED-AT FUNCTION EXISTS
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
-- 1. AGE / DEVELOPMENTAL FORMAT RULES
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

-- -------------------------------------------------------------------------
-- NEONATE
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-001',
    'NEONATE',
    'question_module',
    'neonatal',
    'ACTIVATE',
    100,
    'Neonates require neonatal-specific clinical history and examination architecture.',
    NULL
),
(
    'CR-FORMAT-002',
    'NEONATE',
    'question_module',
    'pediatric',
    'UNAVAILABLE',
    100,
    'Neonates must not be processed using the generic paediatric format.',
    NULL
),
(
    'CR-FORMAT-003',
    'NEONATE',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    100,
    'Neonates must not receive adult medical history architecture.',
    NULL
),

-- -------------------------------------------------------------------------
-- INFANT
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-004',
    'INFANT',
    'question_module',
    'pediatric',
    'ACTIVATE',
    40,
    'Infants require paediatric history and examination architecture.',
    NULL
),
(
    'CR-FORMAT-005',
    'INFANT',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    80,
    'Infants must not receive adult medical history as the primary format.',
    NULL
),
(
    'CR-FORMAT-006',
    'INFANT',
    'question_module',
    'infant_history',
    'ACTIVATE',
    50,
    'Infants require feeding, developmental, immunisation and caregiver-mediated history.',
    NULL
),

-- -------------------------------------------------------------------------
-- CHILD
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-007',
    'CHILD',
    'question_module',
    'pediatric',
    'ACTIVATE',
    40,
    'Children require paediatric clinical history and examination architecture.',
    NULL
),
(
    'CR-FORMAT-008',
    'CHILD',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    80,
    'Children must not receive adult medical history as the primary format.',
    NULL
),

-- -------------------------------------------------------------------------
-- PRESCHOOL
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-009',
    'PRESCHOOL',
    'question_module',
    'pediatric',
    'ACTIVATE',
    45,
    'Preschool children require developmentally appropriate paediatric assessment.',
    NULL
),
(
    'CR-FORMAT-010',
    'PRESCHOOL',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    80,
    'Preschool children must not receive adult medical history architecture.',
    NULL
),

-- -------------------------------------------------------------------------
-- SCHOOL AGE
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-011',
    'SCHOOL_AGE',
    'question_module',
    'pediatric',
    'ACTIVATE',
    40,
    'School-age children require paediatric clinical architecture with age-appropriate communication.',
    NULL
),
(
    'CR-FORMAT-012',
    'SCHOOL_AGE',
    'question_module',
    'adult_medical',
    'UNAVAILABLE',
    70,
    'School-age children must not receive adult medical history architecture.',
    NULL
),

-- -------------------------------------------------------------------------
-- ADOLESCENT
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-013',
    'ADOLESCENT',
    'question_module',
    'adolescent_medical',
    'ACTIVATE',
    60,
    'Adolescents require developmentally appropriate medical assessment with adolescent-specific safeguards.',
    NULL
),
(
    'CR-FORMAT-014',
    'ADOLESCENT',
    'question_module',
    'adult_medical',
    'ACTIVATE',
    10,
    'Adult-compatible medical modules may be used when clinically appropriate for adolescents.',
    NULL
),
(
    'CR-FORMAT-015',
    'ADOLESCENT',
    'question_module',
    'pediatric',
    'UNAVAILABLE',
    30,
    'Adolescents should not automatically receive the full child-format history.',
    NULL
),
(
    'CR-FORMAT-016',
    'ADOLESCENT',
    'question_module',
    'adolescent_confidentiality',
    'ACTIVATE',
    50,
    'Adolescent encounters require appropriate confidential and sensitive-history handling.',
    NULL
),

-- -------------------------------------------------------------------------
-- ADULT
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-017',
    'ADULT',
    'question_module',
    'adult_medical',
    'ACTIVATE',
    40,
    'Adults receive the standard adult medical clinical format.',
    NULL
),
(
    'CR-FORMAT-018',
    'ADULT',
    'question_module',
    'pediatric',
    'UNAVAILABLE',
    80,
    'Adults must not receive paediatric clinical history architecture.',
    NULL
),

-- -------------------------------------------------------------------------
-- OLDER ADULT
-- -------------------------------------------------------------------------
(
    'CR-FORMAT-019',
    'OLDER_ADULT',
    'question_module',
    'adult_medical',
    'ACTIVATE',
    40,
    'Older adults retain adult medical architecture with geriatric adaptations.',
    NULL
),
(
    'CR-FORMAT-020',
    'OLDER_ADULT',
    'question_module',
    'geriatric_assessment',
    'ACTIVATE',
    50,
    'Older adults require additional assessment of function, cognition, falls, frailty and medication burden.',
    NULL
),
(
    'CR-FORMAT-021',
    'OLDER_ADULT',
    'question_module',
    'pediatric',
    'UNAVAILABLE',
    100,
    'Older adults must not receive paediatric clinical architecture.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. PREGNANCY / POSTPARTUM / LACTATION
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

-- -------------------------------------------------------------------------
-- PREGNANCY
-- -------------------------------------------------------------------------
(
    'CR-REPRO-001',
    'PREGNANCY',
    'question_module',
    'obstetric_history',
    'ACTIVATE',
    100,
    'Pregnancy requires obstetric history appropriate to gestational age and clinical presentation.',
    NULL
),
(
    'CR-REPRO-002',
    'PREGNANCY',
    'question_module',
    'gynaecological_history',
    'ACTIVATE',
    50,
    'Relevant gynaecological history remains clinically important during pregnancy.',
    NULL
),
(
    'CR-REPRO-003',
    'PREGNANCY',
    'question_module',
    'anc_profile',
    'ACTIVATE',
    100,
    'Pregnant patients require antenatal care information where applicable.',
    NULL
),
(
    'CR-REPRO-004',
    'PREGNANCY',
    'question_module',
    'pregnancy_red_flags',
    'ACTIVATE',
    120,
    'Pregnancy requires active screening for obstetric danger symptoms when clinically relevant.',
    NULL
),
(
    'CR-REPRO-005',
    'PREGNANCY',
    'question_module',
    'medication_pregnancy_safety',
    'ACTIVATE',
    70,
    'Medication exposure and treatment decisions during pregnancy require pregnancy-specific safety assessment.',
    NULL
),

-- -------------------------------------------------------------------------
-- POSTPARTUM
-- -------------------------------------------------------------------------
(
    'CR-REPRO-006',
    'POSTPARTUM',
    'question_module',
    'postpartum_history',
    'ACTIVATE',
    100,
    'Postpartum patients require assessment of delivery, puerperium and maternal recovery.',
    NULL
),
(
    'CR-REPRO-007',
    'POSTPARTUM',
    'question_module',
    'postpartum_red_flags',
    'ACTIVATE',
    120,
    'Postpartum encounters require assessment for haemorrhage, infection, hypertensive and thromboembolic complications.',
    NULL
),
(
    'CR-REPRO-008',
    'POSTPARTUM',
    'question_module',
    'newborn_context',
    'ACTIVATE',
    30,
    'Maternal postpartum assessment may require clinically relevant newborn and feeding context.',
    NULL
),

-- -------------------------------------------------------------------------
-- LACTATION
-- -------------------------------------------------------------------------
(
    'CR-REPRO-009',
    'LACTATION',
    'question_module',
    'breastfeeding_history',
    'ACTIVATE',
    80,
    'Lactating patients require clinically relevant breastfeeding assessment.',
    NULL
),
(
    'CR-REPRO-010',
    'LACTATION',
    'question_module',
    'medication_lactation_safety',
    'ACTIVATE',
    70,
    'Medication exposure during lactation requires breastfeeding safety assessment.',
    NULL
),
(
    'CR-REPRO-011',
    'LACTATION',
    'question_module',
    'breast_complaint',
    'ACTIVATE',
    20,
    'Breast-related symptoms during lactation may require dedicated breast assessment.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. EMERGENCY CONTEXT
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
    'CR-EMERG-001',
    'EMERGENCY',
    'question_module',
    'emergency_protocol',
    'ACTIVATE',
    150,
    'Emergency encounters prioritize immediate threat recognition and stabilization.',
    NULL
),
(
    'CR-EMERG-002',
    'EMERGENCY',
    'question_module',
    'primary_survey',
    'ACTIVATE',
    150,
    'Emergency assessment requires an immediate structured primary survey when indicated.',
    NULL
),
(
    'CR-EMERG-003',
    'EMERGENCY',
    'question_module',
    'secondary_survey',
    'ACTIVATE',
    80,
    'A structured secondary survey follows stabilization where clinically appropriate.',
    NULL
),
(
    'CR-EMERG-004',
    'EMERGENCY',
    'question_module',
    'emergency_red_flags',
    'ACTIVATE',
    150,
    'Emergency presentations require active screening for immediately life-threatening features.',
    NULL
),
(
    'CR-EMERG-005',
    'EMERGENCY',
    'question_module',
    'routine_history',
    'MODIFY',
    -20,
    'Routine history must not delay immediate recognition and treatment of life-threatening conditions.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. INPATIENT CONTEXT
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
    'CR-INPT-001',
    'INPATIENT',
    'question_module',
    'inpatient_assessment',
    'ACTIVATE',
    80,
    'Inpatient encounters require structured admission and ongoing inpatient assessment.',
    NULL
),
(
    'CR-INPT-002',
    'INPATIENT',
    'question_module',
    'outpatient_specific',
    'UNAVAILABLE',
    50,
    'Outpatient-specific encounter questions should not be used as the primary inpatient workflow.',
    NULL
),
(
    'CR-INPT-003',
    'INPATIENT',
    'question_module',
    'medication_reconciliation',
    'ACTIVATE',
    70,
    'Inpatient care requires review of current and prior medication exposure.',
    NULL
),
(
    'CR-INPT-004',
    'INPATIENT',
    'question_module',
    'functional_status',
    'ACTIVATE',
    40,
    'Baseline and current functional status are important to inpatient management.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. OUTPATIENT CONTEXT
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
    'CR-OUTPT-001',
    'OUTPATIENT',
    'question_module',
    'outpatient_specific',
    'ACTIVATE',
    40,
    'Outpatient encounters require assessment appropriate to ambulatory review.',
    NULL
),
(
    'CR-OUTPT-002',
    'OUTPATIENT',
    'question_module',
    'follow_up_assessment',
    'ACTIVATE',
    50,
    'Review encounters require comparison with prior status and response to previous management.',
    NULL
),
(
    'CR-OUTPT-003',
    'OUTPATIENT',
    'question_module',
    'inpatient_admission_workflow',
    'MODIFY',
    -20,
    'Routine outpatient encounters should not begin with the full inpatient workflow unless admission becomes clinically indicated.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. TELEMEDICINE CONTEXT
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
    'CR-TELE-001',
    'TELEMEDICINE',
    'question_module',
    'telehealth_screening',
    'ACTIVATE',
    100,
    'Telemedicine requires confirmation that remote assessment is clinically appropriate.',
    NULL
),
(
    'CR-TELE-002',
    'TELEMEDICINE',
    'question_module',
    'remote_observation',
    'ACTIVATE',
    60,
    'The clinician must document findings observable through the available remote modality.',
    NULL
),
(
    'CR-TELE-003',
    'TELEMEDICINE',
    'question_module',
    'home_measurements',
    'ACTIVATE',
    40,
    'Home-generated measurements may supplement assessment when available and clinically reliable.',
    NULL
),
(
    'CR-TELE-004',
    'TELEMEDICINE',
    'question_module',
    'physical_examination_limitation',
    'ACTIVATE',
    90,
    'The record must distinguish findings directly observed from examinations that could not be performed remotely.',
    NULL
),
(
    'CR-TELE-005',
    'TELEMEDICINE',
    'question_module',
    'escalation_to_in_person',
    'ACTIVATE',
    100,
    'Potentially unsafe remote assessment requires consideration of in-person evaluation.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. COGNITIVE IMPAIRMENT
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
    'CR-COMM-001',
    'COGNITIVE_IMPAIRMENT',
    'question_module',
    'cognitive_assessment',
    'ACTIVATE',
    80,
    'Cognitive impairment requires appropriate assessment of cognition and ability to provide history.',
    NULL
),
(
    'CR-COMM-002',
    'COGNITIVE_IMPAIRMENT',
    'question_module',
    'caregiver_history',
    'ACTIVATE',
    70,
    'A collateral history may be required when the patient cannot reliably provide the complete history.',
    NULL
),
(
    'CR-COMM-003',
    'COGNITIVE_IMPAIRMENT',
    'question_module',
    'complex_self_report',
    'MODIFY',
    -30,
    'Complex self-report questions should be adapted to the patient’s communication capacity.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. UNCONSCIOUS PATIENT
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
    'CR-UNCON-001',
    'UNCONSCIOUS',
    'question_module',
    'primary_survey',
    'ACTIVATE',
    200,
    'Unconscious patients require immediate structured assessment of airway, breathing and circulation.',
    NULL
),
(
    'CR-UNCON-002',
    'UNCONSCIOUS',
    'question_module',
    'neurological_assessment',
    'ACTIVATE',
    180,
    'Unconsciousness requires structured neurological assessment.',
    NULL
),
(
    'CR-UNCON-003',
    'UNCONSCIOUS',
    'question_module',
    'caregiver_history',
    'ACTIVATE',
    100,
    'A collateral history is required because the patient cannot provide a direct history.',
    NULL
),
(
    'CR-UNCON-004',
    'UNCONSCIOUS',
    'question_module',
    'routine_patient_interview',
    'UNAVAILABLE',
    200,
    'The routine direct patient interview cannot be completed while the patient is unconscious.',
    NULL
),
(
    'CR-UNCON-005',
    'UNCONSCIOUS',
    'question_module',
    'cause_of_unconsciousness',
    'ACTIVATE',
    160,
    'The history and assessment must investigate potentially reversible causes of impaired consciousness.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. CAREGIVER-HISTORY CONTEXT
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
    'CR-HIST-001',
    'CAREGIVER_HISTORY',
    'question_module',
    'caregiver_history',
    'ACTIVATE',
    100,
    'The caregiver is an authorized collateral historian when the patient cannot provide sufficient information.',
    NULL
),
(
    'CR-HIST-002',
    'CAREGIVER_HISTORY',
    'question_module',
    'source_of_history',
    'ACTIVATE',
    80,
    'The record must identify the source of history and distinguish direct from collateral information.',
    NULL
),
(
    'CR-HIST-003',
    'CAREGIVER_HISTORY',
    'question_module',
    'history_reliability',
    'ACTIVATE',
    70,
    'The reliability and limitations of collateral history should be documented.',
    NULL
)  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. CROSS-CONTEXT FORMAT ADAPTATION
-- =============================================================================
-- These rules allow the CPU to combine context states rather than treating
-- each context as an isolated IF/ELSE branch.
--
-- Example:
--
--   NEONATE + EMERGENCY
--       → neonatal + emergency architecture
--
--   CHILD + EMERGENCY
--       → paediatric + emergency architecture
--
--   ADULT + EMERGENCY
--       → adult + emergency architecture
--
--   PREGNANCY + EMERGENCY
--       → emergency + pregnancy-specific assessment
--
--   TELEMEDICINE + UNCONSCIOUS
--       → immediate escalation / emergency pathway
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
    'CR-CROSS-001',
    'EMERGENCY',
    'question_module',
    'age_specific_emergency',
    'ACTIVATE',
    180,
    'Emergency assessment must retain the patient’s age-specific clinical architecture.',
    NULL
),
(
    'CR-CROSS-002',
    'PREGNANCY',
    'question_module',
    'pregnancy_specific_emergency',
    'ACTIVATE',
    180,
    'Emergency presentations during pregnancy require pregnancy-specific emergency considerations.',
    NULL
),
(
    'CR-CROSS-003',
    'POSTPARTUM',
    'question_module',
    'postpartum_specific_emergency',
    'ACTIVATE',
    180,
    'Emergency postpartum presentations require postpartum-specific emergency considerations.',
    NULL
),
(
    'CR-CROSS-004',
    'TELEMEDICINE',
    'question_module',
    'emergency_escalation',
    'ACTIVATE',
    180,
    'Potential emergencies encountered remotely require immediate escalation logic.',
    NULL
),
(
    'CR-CROSS-005',
    'UNCONSCIOUS',
    'question_module',
    'emergency_escalation',
    'ACTIVATE',
    250,
    'Unconsciousness is a high-priority state requiring immediate escalation and stabilization.',
    NULL
)  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 13. VERIFY THE CONTEXT CODES USED BY THIS SEED
-- =============================================================================

SELECT
    '=== CONTEXT CODES USED BY AMEXAN FORMAT ENGINE ===' AS verification;

SELECT
    code,
    category,
    label,
    description
FROM knowledge.clinical_context
WHERE code IN
(
    'NEONATE',
    'INFANT',
    'CHILD',
    'ADOLESCENT',
    'ADULT',
    'OLDER_ADULT',
    'PRESCHOOL',
    'SCHOOL_AGE',
    'PREGNANCY',
    'POSTPARTUM',
    'LACTATION',
    'EMERGENCY',
    'INPATIENT',
    'OUTPATIENT',
    'TELEMEDICINE',
    'COGNITIVE_IMPAIRMENT',
    'UNCONSCIOUS',
    'CAREGIVER_HISTORY'
)
ORDER BY
    category,
    code;


-- =============================================================================
-- 14. VERIFY CONTEXT ADAPTATION RULES
-- =============================================================================

SELECT
    '=== CONTEXT ADAPTATION RULES ===' AS verification;

SELECT
    rule_code,
    context_code,
    target_type,
    target_code,
    modification,
    priority_delta,
    rationale
FROM knowledge.context_adaptation_rule
WHERE rule_code LIKE 'CR-%'
ORDER BY
    priority_delta DESC,
    rule_code;


-- =============================================================================
-- 15. VERIFY QUESTION RULES
-- =============================================================================

SELECT
    '=== QUESTION RULE ENGINE ===' AS verification;

SELECT
    rule_id,
    rule_name,
    trigger_type,
    trigger_code,
    trigger_operator,
    trigger_value,
    action,
    target_type,
    target_code,
    priority_delta,
    rationale
FROM knowledge.question_rule
WHERE rule_id LIKE 'QR-%'
ORDER BY
    priority_delta DESC,
    rule_id;


-- =============================================================================
-- 16. TRIGGER MANAGEMENT
-- =============================================================================
-- PostgreSQL does not support:
--
--     CREATE TRIGGER IF NOT EXISTS
--
-- therefore trigger existence is checked explicitly through pg_trigger.
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


    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c
          ON c.oid = t.tgrelid
        JOIN pg_namespace n
          ON n.oid = c.relnamespace
        WHERE t.tgname = 'trg_knowledge_question_rule_updated_at'
          AND n.nspname = 'knowledge'
          AND c.relname = 'question_rule'
    )
    THEN
        CREATE TRIGGER trg_knowledge_question_rule_updated_at
        BEFORE UPDATE
        ON knowledge.question_rule
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;

END
$$;


-- =============================================================================
-- 17. FINAL COUNTS
-- =============================================================================

SELECT
    'CONTEXT_ADAPTATION_RULE_COUNT' AS metric,
    COUNT(*)::text AS value
FROM knowledge.context_adaptation_rule
WHERE rule_code LIKE 'CR-%'

UNION ALL

SELECT
    'QUESTION_RULE_COUNT' AS metric,
    COUNT(*)::text AS value
FROM knowledge.question_rule
WHERE rule_id LIKE 'QR-%';


-- =============================================================================
-- 18. COMPLETION MARKER
-- =============================================================================

SELECT
    'AMEXAN H5 CONTEXT INTELLIGENCE / FORMAT SELECTION RULESET 047 SEEDED SUCCESSFULLY'
    AS status;


COMMIT;