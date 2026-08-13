-- =============================================================================
-- AMEXAN Universal Symptom Engine — migration 023
-- =============================================================================
-- documentation_group: gives every HPI template a structural home so the
-- DocumentationEngine can assemble the History of Present Illness in clinical
-- order (presenting complaint → character → sputum → associated symptoms →
-- systemic review → risk factors → functional impact → examination) instead of
-- a flat "with"-joined chain.
-- =============================================================================

ALTER TABLE knowledge.symptom_hpi_template
    ADD COLUMN documentation_group text NOT NULL DEFAULT 'character';

ALTER TABLE knowledge.symptom_hpi_template
    ADD CONSTRAINT symptom_hpi_template_documentation_group_check
        CHECK (documentation_group = ANY (ARRAY[
            'presenting', 'character', 'sputum', 'associated',
            'systemic', 'ent_gi', 'risk', 'functional', 'examination'
        ]));
