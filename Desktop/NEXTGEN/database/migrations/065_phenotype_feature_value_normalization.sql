-- =============================================================================
-- 065. PHENOTYPE FEATURE VALUE NORMALIZATION
-- =============================================================================
--
-- Multiple phenotype features stored the expected value as the JSON string
-- "YES" (e.g. eq "YES"). The canonical facts are boolean (question answer
-- YES → boolean true). A "YES" expectation therefore NEVER matched a boolean
-- true fact, producing:
--
--   - spurious negative evidence for phenotypes whose features otherwise
--     matched (e.g. PHEN-ACUTE-LRTI dropped below zero once the pleuritic
--     feature was pointed at PLEURITIC_CHEST_PAIN, so the leading
--     differential flipped away from Pneumonia at interview time); and
--   - incompatibility between phenotype feature expectations and the
--     question/fact wiring.
--
-- Normalize all boolean-ish string expectations to boolean true. String/coded
-- expectations such as "PRODUCTIVE", "CURRENT" and "PREGNANT" are left intact.
--
-- The feature UNIQUE constraint omits value/weight, and duplicated rows carry
-- temporal_role NULL, so this UPDATE cannot violate it.
-- =============================================================================

UPDATE knowledge.phenotype_feature
   SET value = 'true'::jsonb
 WHERE value = '"YES"'::jsonb;

UPDATE knowledge.phenotype_feature
   SET value = 'false'::jsonb
 WHERE value = '"NO"'::jsonb;