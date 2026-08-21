-- =============================================================================
-- 057. INVESTIGATION JUNCTION CLINICAL ATTRIBUTES
-- =============================================================================
--
-- The H7/H8 investigation selector (InvestigationSelector) reads richer
-- clinical attributes off the condition/mechanism investigation junction
-- tables:
--
--     role             clinical classification of the investigation
--                      (diagnostic / confirmatory / supportive / severity /
--                       complication / baseline / monitoring / exclusion /
--                       screening / pre_treatment)
--     clinical_question the clinical uncertainty the investigation answers
--     decision_impact   weighting used by the selector when scoring utility
--
-- These attributes were introduced by the engine rewrite but never existed in
-- the physical schema. Add them as nullable columns so existing seed rows
-- (which predate the attributes) keep working through the COALESCE defaults in
-- the selector, while the knowledge compiler can populate them going forward.
-- =============================================================================

ALTER TABLE knowledge.investigation_condition
    ADD COLUMN IF NOT EXISTS role            text,
    ADD COLUMN IF NOT EXISTS clinical_question text,
    ADD COLUMN IF NOT EXISTS decision_impact   numeric DEFAULT 0;

ALTER TABLE knowledge.mechanism_investigation
    ADD COLUMN IF NOT EXISTS role            text,
    ADD COLUMN IF NOT EXISTS clinical_question text,
    ADD COLUMN IF NOT EXISTS decision_impact   numeric DEFAULT 0;

-- Backfill legacy junction rows with the selector's conservative defaults so
-- existing encounters continue to produce the same investigation candidates.
UPDATE knowledge.investigation_condition
   SET role = COALESCE(role, 'diagnostic'),
       decision_impact = COALESCE(decision_impact, 0)
 WHERE role IS NULL OR decision_impact IS NULL;

UPDATE knowledge.mechanism_investigation
   SET role = COALESCE(role, 'diagnostic'),
       decision_impact = COALESCE(decision_impact, 0)
 WHERE role IS NULL OR decision_impact IS NULL;