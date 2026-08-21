-- =============================================================================
-- 062. MISSING FACT DEFINITIONS (RESP_RATE, RLL SIGNS)
-- =============================================================================
--
-- Three fact codes used by the knowledge layer and the benchmark machine run
-- were never registered in clinical.fact_definition:
--
--     RESP_RATE                  respiratory rate (per minute), consumed by
--                                the SCORE-CURB65 severity component
--                                (numeric_gte 30) and by the examination /
--                                vital-capture engines.
--
--     RLL_DULLNESS               right-lower-lobe percussion dullness, a
--                                boolean finding scored by the pneumonia
--                                phenotype features.
--
--     RLL_BRONCHIAL_BREATH_SOUNDS  right-lower-lobe bronchial breath sounds,
--                                a boolean finding scored by the pneumonia
--                                phenotype features.
--
-- The phenotype knowledge and severity components already referenced these
-- codes, so capturing them previously failed with "Unknown fact definition".
-- =============================================================================

INSERT INTO clinical.fact_definition
    (code, name, description, data_type, is_active, allow_multiple)
VALUES
    ('RESP_RATE', 'Respiratory rate',
     'Respiratory rate in breaths per minute.', 'numeric', true, true),
    ('RLL_DULLNESS', 'Right lower lobe dullness',
     'Percussion dullness over the right lower lobe.', 'boolean', true, true),
    ('RLL_BRONCHIAL_BREATH_SOUNDS', 'Right lower lobe bronchial breath sounds',
     'Bronchial breath sounds audible over the right lower lobe.', 'boolean', true, true)
ON CONFLICT (code) DO NOTHING;