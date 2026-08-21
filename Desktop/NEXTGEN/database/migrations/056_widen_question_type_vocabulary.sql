-- =============================================================================
-- 056. WIDEN question_type VOCABULARY
-- =============================================================================
--
-- Migration 008 fixed question_type to a nine-value CHECK that predates the
-- universal question engine's taxonomy. The seed suite now emits question
-- types such as 'red_flag', 'history', 'medication', 'paediatric', 'biodata'
-- and the investigation/management/monitoring families, so the CHECK must
-- cover the full vocabulary that seeds and the runtime share.

ALTER TABLE knowledge.question
    DROP CONSTRAINT IF EXISTS question_question_type_check;

ALTER TABLE knowledge.question
    ADD CONSTRAINT question_question_type_check
    CHECK (
        question_type IN (
            'clinical',
            'risk',
            'screening',
            'follow_up',
            'safety',
            'severity',
            'differential',
            'context',
            'documentation',
            'red_flag',
            'history',
            'medication',
            'paediatric',
            'allergy',
            'biodata',
            'onset',
            'exposure',
            'temporal',
            'finding',
            'investigation',
            'mechanism',
            'phenotype',
            'management',
            'monitoring',
            'education',
            'complication',
            'assessment'
        )
    );