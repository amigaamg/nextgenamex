-- =============================================================================
-- AMEXAN Universal Symptom Engine — migration 024
-- =============================================================================
-- Extends knowledge.symptom_hpi_template.documentation_group so the HPI can be
-- assembled in a FULL internal-medicine narrative order:
--
--   presenting → chronology → character → sputum → associated → systemic →
--   ent_gi → risk → previous → health_seeking → severity → functional →
--   examination
--
-- New groups:
--   chronology     — baseline / onset timeline ("The patient was well until N
--                    days ago... he subsequently developed...")
--   previous       — first episode vs recurrent, prior diagnosis/treatment
--   health_seeking — prior consultation, treatment/self-medication, response,
--                    reason for current presentation
--   severity       — progression, complications, red flags
-- =============================================================================

ALTER TABLE knowledge.symptom_hpi_template
    DROP CONSTRAINT IF EXISTS symptom_hpi_template_documentation_group_check;

ALTER TABLE knowledge.symptom_hpi_template
    ADD CONSTRAINT symptom_hpi_template_documentation_group_check
        CHECK (documentation_group = ANY (ARRAY[
            'presenting', 'chronology', 'character', 'sputum', 'associated',
            'systemic', 'ent_gi', 'risk', 'previous', 'health_seeking',
            'severity', 'functional', 'examination'
        ]));
