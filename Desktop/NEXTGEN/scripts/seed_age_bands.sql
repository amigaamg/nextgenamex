-- =============================================================================
-- AMEXAN H5 Seed: Developmental stages and clinical contexts
-- =============================================================================
-- Seeds the 5 universal age bands and clinical context categories
-- =============================================================================

-- 1. Seed developmental_stage (the 5 age bands)
-- These are the canonical AMEXAN age contexts that the CPU uses to
-- determine question wording, capture method, and format selection.

INSERT INTO knowledge.developmental_stage (stage_code, label, min_age_days, max_age_days, sort_order, description) VALUES
  ('NEONATE', 'Neonate', 0, 27, 1, 'Birth through 27 completed days'),
  ('INFANT', 'Infant', 28, 364, 2, '28 days through <1 year'),
  ('CHILD', 'Child', 1, 11, 3, '1 year through <12 years'),
  ('ADOLESCENT', 'Adolescent', 12, 17, 4, '12 through <18 years'),
  ('ADULT', 'Adult', 18, NULL, 5, '>=18 years');

-- 2. Seed clinical_context (patient demographic contexts)
-- The CPU evaluates the entire context stack simultaneously, not an IF-chain.

INSERT INTO knowledge.clinical_context (context_id, code, category, label, description, applies_to_questions, applies_to_exam, priority_weight) VALUES
  ('C001', 'NEONATE', 'AGE', 'Neonate', 'Patient from birth through 27 days', true, true, 1.5),
  ('C002', 'INFANT', 'AGE', 'Infant', 'Patient from 28 days through <1 year', true, true, 1.3),
  ('C003', 'CHILD', 'AGE', 'Child', 'Patient from 1 year through <12 years', true, true, 1.2),
  ('C004', 'ADOLESCENT', 'AGE', 'Adolescent', 'Patient 12 through <18 years', true, true, 1.1),
  ('C005', 'ADULT', 'AGE', 'Adult', 'Patient >=18 years', true, true, 1.0),
  ('S001', 'MALE', 'SEX', 'Male', 'Patient sex at birth = male', true, true, 1.0),
  ('S002', 'FEMALE', 'SEX', 'Female', 'Patient sex at birth = female', true, true, 1.0),
  ('R001', 'PREGNANT', 'REPRODUCTIVE', 'Pregnant', 'Patient is currently pregnant', true, true, 1.4),
  ('R002', 'NOT_PREGNANT', 'REPRODUCTIVE', 'Not Pregnant', 'Patient is not currently pregnant', true, true, 0.9),
  ('R003', 'REPRODUCTIVE_AGE', 'REPRODUCTIVE', 'Reproductive Age', 'Female patient of reproductive age (12-50)', true, true, 1.1),
  ('E001', 'EMERGENCY', 'SETTING', 'Emergency', 'Encounter in emergency setting', true, true, 1.3),
  ('E002', 'OPD', 'SETTING', 'OPD', 'Encounter in outpatient department', true, true, 1.0),
  ('D001', 'INTERNAL_MEDICINE', 'DEPARTMENT', 'Internal Medicine', 'Medical internal encounter', true, true, 1.0),
  ('D002', 'PEDIATRICS', 'DEPARTMENT', 'Pediatrics', 'Pediatric encounter', true, true, 1.0),
  ('D003', 'OBGYN', 'DEPARTMENT', 'OBGYN', 'Obstetric/Gynecologic encounter', true, true, 1.0),
  ('D004', 'PSYCHIATRY', 'DEPARTMENT', 'Psychiatry', 'Psychiatric encounter', true, true, 1.0),
  ('P001', 'RESPIRATORY', 'SYMPTOM', 'Respiratory', 'Respiratory complaint/presentation', true, true, 1.0),
  ('P002', 'CARDIOVASCULAR', 'SYMPTOM', 'Cardiovascular', 'Cardiovascular complaint/presentation', true, true, 1.0),
  ('P003', 'ABDOMINAL', 'SYMPOM', 'Abdominal', 'Abdominal complaint/presentation', true, true, 1.0);

-- Create triggers for updated_at
DO $$
BEGIN
    CREATE OR REPLACE FUNCTION public.set_updated_at()
    RETURNS trigger AS \$\$
    BEGIN
        NEW.updated_at = now();
        RETURN NEW;
    END;
    \$\$ LANGUAGE plpgsql;

    -- Apply triggers if they don't exist
    CREATE TRIGGER IF NOT EXISTS trg_knowledge_developmental_stage_updated_at
        BEFORE UPDATE ON knowledge.developmental_stage
        FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

    CREATE TRIGGER IF NOT EXISTS trg_knowledge_clinical_context_updated_at
        BEFORE UPDATE ON knowledge.clinical_context
        FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
END$$;

SELECT 'Age bands and clinical contexts seeded successfully';

-- Verify
SELECT stage_code, label, min_age_days, max_age_days FROM knowledge.developmental_stage ORDER BY sort_order;
SELECT context_id, code, category, label FROM knowledge.clinical_context ORDER BY sort_order;