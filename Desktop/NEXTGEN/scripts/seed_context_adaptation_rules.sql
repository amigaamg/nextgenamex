-- =============================================================================
-- AMEXAN H5 Seed/Rule: Context adaptation rules for format selection
-- =============================================================================
-- These rules control which clinical format the CPU selects based on patient context.
-- They enforce the universal rule: "The patient does not choose the clinical format.
-- The CPU determines the format from structured context, and the UI renders only
-- what the CPU authorizes."

-- 1. NEONATE takes precedence - male neonate = NEONATAL format, NOT PEDIATRIC

INSERT INTO knowledge.context_adaptation_rule (rule_code, context_code, target_type, target_code, modification, priority_delta, rationale, condition) VALUES
  ('CR-FORMAT-001', 'NEONATE', 'question_module', 'pediatric', 'UNAVAILABLE', 50, 'Neonates must not receive pediatric format questions', NULL),
  ('CR-FORMAT-002', 'NEONATE', 'question_module', 'adult_medical', 'UNAVAILABLE', 50, 'Neonates must not receive adult medical format questions', NULL),

-- 2. Child context - pediatric format activated, adult format suppressed

  ('CR-FORMAT-003', 'CHILD', 'question_module', 'pediatric', 'ACTIVATE', 20, 'Child patients receive pediatric-format questions', NULL),
  ('CR-FORMAT-004', 'CHILD', 'question_module', 'adult_medical', 'UNAVAILABLE', 30, 'Child patients must not receive adult medical format', NULL),

-- 3. Adolescent context - adult format with adolescent considerations

  ('CR-FORMAT-005', 'ADOLESCENT', 'question_module', 'adult_medical', 'ACTIVATE', 10, 'Adolescent patients receive adult format with adaptations', NULL),
  ('CR-FORMAT-006', 'ADOLESCENT', 'question_module', 'pediatric', 'UNAVAILABLE', 40, 'Adolescents should not receive full pediatric format', NULL),

-- 4. Adult context - adult medical format

  ('CR-FORMAT-007', 'ADULT', 'question_module', 'adult_medical', 'ACTIVATE', 0, 'Adult patients receive adult medical format', NULL),
  ('CR-FORMAT-008', 'ADULT', 'question_module', 'pediatric', 'UNAVAILABLE', 50, 'Adult patients must not receive pediatric format', NULL),

-- 5. MALE sex - suppress obstetric/gynaecological formats

  ('CR-FORMAT-009', 'MALE', 'question_module', 'obstetric_history', 'UNAVAILABLE', 100, 'Male patients must not receive obstetric history questions', NULL),
  ('CR-FORMAT-010', 'MALE', 'question_module', 'gynaecological_history', 'UNAVAILABLE', 100, 'Male patients must not receive gynaecological history questions', NULL),
  ('CR-FORMAT-011', 'MALE', 'question_module', 'anc_profile', 'UNAVAILABLE', 100, 'Male patients must not receive ANC profile questions', NULL),
  ('CR-FORMAT-012', 'MALE', 'question_module', 'gestational_age', 'UNAVAILABLE', 100, 'Male patients must not receive gestational age questions', NULL),

-- 6. FEMALE + PREGNANT = OBGYN format activation

  ('CR-FORMAT-013', 'PREGNANT', 'question_module', 'obstetric_history', 'ACTIVATE', 30, 'Pregnant patients receive obstetric history', NULL),
  ('CR-FORMAT-014', 'PREGNANT', 'question_module', 'gynaecological_history', 'ACTIVATE', 30, 'Pregnant patients receive gynaecological history', NULL),
  ('CR-FORMAT-015', 'PREGNANT', 'question_module', 'anc_profile', 'ACTIVATE', 30, 'Pregnant patients receive ANC profile', NULL),

-- 7. FEMALE + NOT PREGNANT + Reproductive Age = context-dependent (suppressed default, can activate with triggers)

  ('CR-FORMAT-017', 'FEMALE', 'question_module', 'obstetric_history', 'UNAVAILABLE', 50, 'Non-pregnant females default suppress OB history', NULL),
  ('CR-FORMAT-018', 'FEMALE', 'question_module', 'gynaecological_history', 'UNAVAILABLE', 50, 'Non-pregnant females default suppress GYN history', NULL),
  ('CR-FORMAT-019', 'FEMALE', 'question_module', 'anc_profile', 'UNAVAILABLE', 50, 'Non-pregnant females default suppress ANC', NULL),

-- 8. Department/service context rules

  ('CR-FORMAT-020', 'INTERNAL_MEDICINE', 'question_module', 'obgyn', 'UNAVAILABLE', 40, 'Internal medicine encounters default to medical format', NULL),
  ('CR-FORMAT-021', 'PEDIATRICS', 'question_module', 'adult_medical', 'UNAVAILABLE', 60, 'Pediatric encounters default to pediatric format', NULL),
  ('CR-FORMAT-022', 'OBGYN', 'question_module', 'obstetric_history', 'ACTIVATE', 20, 'OBGYN encounters must have obstetric history', NULL),
  ('CR-FORMAT-023', 'OBGYN', 'question_module', 'gynaecological_history', 'ACTIVATE', 20, 'OBGYN encounters must have gynaecological history', NULL),
  ('CR-FORMAT-024', 'OBGYN', 'question_module', 'anc_profile', 'ACTIVATE', 20, 'OBGYN encounters must have ANC profile', NULL),

-- 9. Respiratory symptom context (age-dependent)

  ('CR-FORMAT-025', 'RESPIRATORY', 'question_module', 'cough_core', 'ACTIVATE', 15, 'Respiratory complaint activates cough module', NULL),
  ('CR-FORMAT-026', 'CHILD + RESPIRATORY', 'question_module', 'pediatric_wheeze', 'ACTIVATE', 25, 'Children with respiratory complaints get pediatric wheeze questions', NULL),
  ('CR-FORMAT-027', 'ADULT + RESPIRATORY', 'question_module', 'adult_cough', 'ACTIVATE', 15, 'Adults with respiratory complaints get adult cough questions', NULL),

-- 10. Sex + symptom interaction

  ('CR-FORMAT-028', 'MALE + RESPIRATORY', 'question_module', 'haemoptysis', 'ACTIVATE', 10, 'Males with respiratory complaints may have haemoptysis', NULL),
  ('CR-FORMAT-029', 'FEMALE + RESPIRATORY + PREGNANT', 'question_module', 'haemoptysis', 'ACTIVATE', 10, 'Pregnant females with haemoptysis need obstetric assessment', NULL);

-- Create trigger for updated_at
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
END$$;

SELECT 'Context adaptation rules for format selection seeded successfully';

-- Verify key rules
SELECT rule_code, context_code, target_type, modification, priority_delta, rationale 
FROM knowledge.context_adaptation_rule 
WHERE rule_code LIKE 'CR-FORMAT-%'
ORDER BY rule_code;