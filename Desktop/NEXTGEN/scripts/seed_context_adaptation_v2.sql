-- =============================================================================
-- AMEXAN H5 Seed/Rule: Context adaptation rules for format selection
-- =============================================================================
-- Uses ONLY knowledge.clinical_context codes that exist in the database.
-- Available codes: NEONATE, INFANT, CHILD, ADOLESCENT, ADULT, OLDER_ADULT,
-- PRESCHOOL, SCHOOL_AGE (AGE category)
--              PREGNANCY, POSTPARTUM, LACTATION (REPRODUCTIVE category)
--              EMERGENCY, INPATIENT, OUTPATIENT (SETTING category)
--              TELEMEDICINE (MODE category)
--              COGNITIVE_IMPAIRMENT, UNCONSCIOUS (COMMUNICATION category)
--              CAREGIVER_HISTORY (HISTORIAN category)

-- ============================================================
-- 1. CONTEXT ADAPTATION RULES (format selection by age)

-- NEONATE: pediatric and adult formats unavailable
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-001', 'NEONATE', 'question_module', 'pediatric', 'UNAVAILABLE', 50, 'Neonates must not receive pediatric format questions', NULL),
  ('CR-FORMAT-002', 'NEONATE', 'question_module', 'adult_medical', 'UNAVAILABLE', 50, 'Neonates must not receive adult medical format questions', NULL);

-- INFANT: adult format suppressed, pediatric activated
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-003', 'INFANT', 'question_module', 'adult_medical', 'UNAVAILABLE', 40, 'Infants must not receive adult medical format as primary', NULL),
  ('CR-FORMAT-004', 'INFANT', 'question_module', 'pediatric', 'ACTIVATE', 20, 'Infants receive pediatric-format questions', NULL);

-- CHILD: pediatric format activated, adult format suppressed
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-005', 'CHILD', 'question_module', 'pediatric', 'ACTIVATE', 20, 'Child patients receive pediatric-format questions', NULL),
  ('CR-FORMAT-006', 'CHILD', 'question_module', 'adult_medical', 'UNAVAILABLE', 30, 'Child patients must not receive adult medical format', NULL);

-- ADOLESCENT: adult format with adaptations, pediatric suppressed
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-007', 'ADOLESCENT', 'question_module', 'adult_medical', 'ACTIVATE', 10, 'Adolescent patients receive adult format with adaptations', NULL),
  ('CR-FORMAT-008', 'ADOLESCENT', 'question_module', 'pediatric', 'UNAVAILABLE', 40, 'Adolescents should not receive full pediatric format', NULL);

-- ADULT: adult medical format activated
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-009', 'ADULT', 'question_module', 'adult_medical', 'ACTIVATE', 0, 'Adult patients receive adult medical format', NULL),
  ('CR-FORMAT-010', 'ADULT', 'question_module', 'pediatric', 'UNAVAILABLE', 50, 'Adult patients must not receive pediatric format', NULL);

-- OLDER_ADULT: same as adult (no suppression needed)
-- (handled by ADULT code being broad enough)

-- PRESCHOOL: pediatric format
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-011', 'PRESCHOOL', 'question_module', 'pediatric', 'ACTIVATE', 20, 'Preschool children receive pediatric-format questions', NULL),

-- SCHOOL_AGE: pediatric format (same as child)
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-012', 'SCHOOL_AGE', 'question_module', 'pediatric', 'ACTIVATE', 20, 'School-age children receive pediatric-format questions', NULL);

-- ============================================================
-- 2. PREGNANCY AND REPRODUCTIVE CONTEXT RULES

-- PREGNANCY: activate obstetric history, gynaecological history, ANC profile
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-013', 'PREGNANCY', 'question_module', 'obstetric_history', 'ACTIVATE', 30, 'Pregnant patients receive obstetric history', NULL),
  ('CR-FORMAT-014', 'PREGNANCY', 'question_module', 'gynaecological_history', 'ACTIVATE', 30, 'Pregnant patients receive gynaecological history', NULL),
  ('CR-FORMAT-015', 'PREGNANCY', 'question_module', 'anc_profile', 'ACTIVATE', 30, 'Pregnant patients receive ANC profile', NULL);

-- LACTATION: activate breastfeeding-related questions
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-016', 'LACTATION', 'question_module', 'breastfeeding_history', 'ACTIVATE', 25, 'Lactating patients receive breastfeeding history questions', NULL),

-- POSTPARTUM: postpartum-related questions
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-017', 'POSTPARTUM', 'question_module', 'postpartum_history', 'ACTIVATE', 25, 'Postpartum patients receive postpartum history questions', NULL);

-- ============================================================
-- 3. SETTING CONTEXT RULES

-- EMERGENCY: activate emergency protocol questions
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-018', 'EMERGENCY', 'question_module', 'emergency_protocol', 'ACTIVATE', 20, 'Emergency encounters activate emergency protocol questions', NULL),

-- INPATIENT: suppress some outpatient-focused questions
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-019', 'INPATIENT', 'question_module', 'outpatient_specific', 'UNAVAILABLE', 30, 'Inpatient encounters suppress outpatient-specific questions', NULL),

-- OUTPATIENT: activate outpatient-focused questions
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-020', 'OUTPATIENT', 'question_module', 'outpatient_specific', 'ACTIVATE', 20, 'Outpatient encounters activate outpatient-specific questions', NULL);

-- ============================================================
-- 4. MODE CONTEXT RULES

-- TELEMEDICINE: activate telehealth-specific questions
INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-021', 'TELEMEDICINE', 'question_module', 'telehealth_screening', 'ACTIVATE', 15, 'Telemedicine encounters activate telehealth screening questions', NULL);

-- ============================================================
-- 5. Question Rule Engine Rules (sex-based question suppression)
-- ==========================================================--
-- These use knowledge.question_rule which can reference context_type codes
-- (trigger_type = 'context', trigger_code = 'SEX', etc.)

-- MALE sex: deactivate obstetric/gynaecological questions
INSERT INTO knowledge.question_rule (rule_id, rule_name, trigger_type, trigger_code, trigger_operator, trigger_value, action, target_type, target_code, priority_delta, rationale, evidence_claim_code) VALUES
  ('MALE-NO-OBHX', 'Male - no obstetric history', 'context', 'SEX', 'eq', 'MALE', 'DEACTIVATE', 'question_module', 'obstetric_history', 100, 'Male patients must not receive obstetric history questions', NULL),
  ('MALE-NO-GYNHX', 'Male - no gynaecological history', 'context', 'SEX', 'eq', 'MALE', 'DEACTIVATE', 'question_module', 'gynaecological_history', 100, 'Male patients must not receive gynaecological history questions', NULL),
  ('MALE-NO-ANCP', 'Male - no ANC profile', 'context', 'SEX', 'eq', 'MALE', 'DEACTIVATE', 'question_module', 'anc_profile', 100, 'Male patients must not receive ANC profile questions', NULL);

-- FEMALE sex: conditional OBGYN activation (not automatic)
INSERT INTO knowledge.question_rule (rule_id, rule_name, trigger_type, trigger_code, trigger_operator, trigger_value, action, target_type, target_code, priority_delta, rationale, evidence_claim_code) VALUES
  ('FEMALE-CONDOBHX', 'Female - OB history conditional', 'context', 'SEX', 'eq', 'FEMALE', 'ACTIVATE', 'question_module', 'obstetric_history', 30, 'Female patients may receive obstetric history if clinically relevant', NULL),
  ('FEMALE-CONDGYNHX', 'Female - GYN history conditional', 'context', 'SEX', 'eq', 'FEMALE', 'ACTIVATE', 'question_module', 'gynaecological_history', 30, 'Female patients may receive gynaecological history if clinically relevant', NULL);

-- ============================================================
-- 6. Verification
-- ============================================================

-- Create triggers if not exists
DO $$
BEGIN
    CREATE OR REPLACE FUNCTION public.set_updated_at()
    RETURNS trigger AS \$\$
    BEGIN
        NEW.updated_at = now();
        RETURN NEW;
    END;
    \$\$ LANGUAGE plpgsql;

    CREATE TRIGGER IF NOT EXISTS trg_knowledge_context_adaptation_rule_updated_at
        BEFORE UPDATE ON knowledge.context_adaptation_rule
        FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    CREATE TRIGGER IF NOT EXISTS trg_knowledge_question_rule_updated_at
        BEFORE UPDATE ON knowledge.question_rule
        FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
END$$;

SELECT 'Context adaptation and question rule engine seeded successfully';

-- Verify key rules
SELECT '=== Context Adaptation Rules (format selection by age) ===';
SELECT rule_code, context_code, target_type, modification, priority_delta, rationale 
FROM knowledge.context_adaptation_rule 
WHERE rule_code LIKE 'CR-FORMAT-%'
ORDER BY rule_code;

SELECT '=== Question Rules (sex-based suppression) ===';
SELECT rule_id, rule_name, trigger_type, trigger_code, action, target_type, target_code, priority_delta, rationale 
FROM knowledge.question_rule 
WHERE rule_id LIKE 'MALE%' OR rule_id LIKE 'FEMALE%'
ORDER BY rule_id;