-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP9
-- UNIVERSAL CONSOLIDATION FINDINGS → PHENOTYPE → MECHANISM GRAPH
-- =============================================================================
--
-- PURPOSE
-- -------
-- Phase 1E hardening of the Universal Clinical Intelligence Graph.
--
-- This seed connects reusable clinical findings associated with pulmonary
-- consolidation to:
--
--      UNIVERSAL FINDING
--              │
--              ├──────────────► PHEN-ACUTE-LRTI
--              │
--              └──────────────► MECH-ALVEOLAR-INFLAMMATION
--
-- The findings are NOT owned by pneumonia.
--
-- They may be reused by:
--   • community-acquired pneumonia
--   • aspiration pneumonia
--   • pulmonary infarction with peripheral consolidation
--   • organizing pneumonia
--   • pulmonary haemorrhage
--   • atelectatic/consolidative processes
--   • other focal alveolar syndromes
--
-- The disease layer is therefore downstream of universal clinical evidence.
--
-- IMPORTANT
-- ---------
-- This seed assumes the following objects already exist:
--
--   knowledge.phenotype
--      PHEN-ACUTE-LRTI
--
--   knowledge.mechanism
--      MECH-ALVEOLAR-INFLAMMATION
--
--   knowledge.phenotype_feature
--   knowledge.mechanism_feature
--   knowledge.mechanism_phenotype
--
-- It is intentionally named ZP9 so it executes after the foundational
-- knowledge/mechanism seeds.
--
-- =============================================================================


-- =============================================================================
-- 1. UNIVERSAL PHENOTYPE FEATURES
-- =============================================================================
--
-- These findings strengthen the acute lower-respiratory phenotype.
--
-- They remain facts, not diagnoses.
--
-- =============================================================================

INSERT INTO knowledge.phenotype_feature
(
    phenotype_id,
    feature_type,
    feature_code,
    operator,
    value,
    weight,
    polarity
)
VALUES

    ---------------------------------------------------------------------------
    -- Focal percussion abnormality
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.phenotype
            WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
        ),
        'fact',
        'RLL_DULLNESS',
        'eq',
        'true',
        1.0,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Bronchial breathing over a focal area
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.phenotype
            WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
        ),
        'fact',
        'RLL_BRONCHIAL_BREATH_SOUNDS',
        'eq',
        'true',
        1.0,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Crackles
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.phenotype
            WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
        ),
        'fact',
        'CRACKLES',
        'eq',
        'true',
        0.9,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Pleuritic chest pain
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.phenotype
            WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
        ),
        'fact',
        'CHEST_PAIN_PLEURITIC',
        'eq',
        '"YES"',
        0.7,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Dyspnoea
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.phenotype
            WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
        ),
        'fact',
        'DYSPNOEA_PRESENT',
        'eq',
        '"YES"',
        0.6,
        'positive'
    )

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. UNIVERSAL MECHANISM FEATURES
-- =============================================================================
--
-- The same findings support the mechanism:
--
--      MECH-ALVEOLAR-INFLAMMATION
--
-- This is deliberately independent of a particular disease.
--
-- =============================================================================

INSERT INTO knowledge.mechanism_feature
(
    mechanism_id,
    feature_type,
    feature_code,
    weight,
    polarity
)
VALUES

    ---------------------------------------------------------------------------
    -- Focal dullness
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.mechanism
            WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
        ),
        'fact',
        'RLL_DULLNESS',
        1.0,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Bronchial breath sounds
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.mechanism
            WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
        ),
        'fact',
        'RLL_BRONCHIAL_BREATH_SOUNDS',
        1.0,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Crackles
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.mechanism
            WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
        ),
        'fact',
        'CRACKLES',
        0.8,
        'positive'
    ),

    ---------------------------------------------------------------------------
    -- Pleuritic pain
    ---------------------------------------------------------------------------
    (
        (
            SELECT id
            FROM knowledge.mechanism
            WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
        ),
        'fact',
        'CHEST_PAIN_PLEURITIC',
        0.8,
        'positive'
    )

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. LINK MECHANISM TO PHENOTYPE
-- =============================================================================
--
-- Focal consolidation is highly compatible with alveolar inflammation.
--
-- This is a phenotype ↔ mechanism relationship, NOT:
--
--      mechanism → disease
--
-- The disease layer can subsequently use both the phenotype and mechanism.
--
-- =============================================================================

INSERT INTO knowledge.mechanism_phenotype
(
    mechanism_id,
    phenotype_id,
    weight
)
VALUES
(
    (
        SELECT id
        FROM knowledge.mechanism
        WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
    ),
    (
        SELECT id
        FROM knowledge.phenotype
        WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
    ),
    1.0
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. UNIVERSAL FINDING → MECHANISM HARDENING
-- =============================================================================
--
-- Explicitly ensure that the core consolidation findings participate in the
-- alveolar-inflammation mechanism.
--
-- These are deliberately separate from disease associations.
--
-- =============================================================================

INSERT INTO knowledge.mechanism_feature
(
    mechanism_id,
    feature_type,
    feature_code,
    weight,
    polarity
)
SELECT
    m.id,
    'fact',
    v.feature_code,
    v.weight,
    'positive'
FROM
    (
        VALUES
            ('RLL_DULLNESS',                 1.0::numeric),
            ('RLL_BRONCHIAL_BREATH_SOUNDS', 1.0::numeric),
            ('CRACKLES',                     0.8::numeric),
            ('CHEST_PAIN_PLEURITIC',         0.8::numeric)
    ) AS v(feature_code, weight)
CROSS JOIN
    (
        SELECT id
        FROM knowledge.mechanism
        WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
    ) AS m
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. UNIVERSAL FINDING → PHENOTYPE HARDENING
-- =============================================================================
--
-- Same principle as above, but for the phenotype layer.
--
-- =============================================================================

INSERT INTO knowledge.phenotype_feature
(
    phenotype_id,
    feature_type,
    feature_code,
    operator,
    value,
    weight,
    polarity
)
SELECT
    p.id,
    'fact',
    v.feature_code,
    'eq',
    v.value::jsonb,
    v.weight,
    'positive'
FROM
    (
        VALUES
            ('RLL_DULLNESS',                 'true',  1.0::numeric),
            ('RLL_BRONCHIAL_BREATH_SOUNDS', 'true',  1.0::numeric),
            ('CRACKLES',                     'true',  0.9::numeric),
            ('CHEST_PAIN_PLEURITIC',         '"YES"', 0.7::numeric),
            ('DYSPNOEA_PRESENT',             '"YES"', 0.6::numeric)
    ) AS v(feature_code, value, weight)
CROSS JOIN
    (
        SELECT id
        FROM knowledge.phenotype
        WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
    ) AS p
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. OPTIONAL NEGATIVE-PHENOTYPE SIGNALS
-- =============================================================================
--
-- IMPORTANT:
--
-- Absence of a finding is not automatically evidence against every diagnosis.
-- Therefore these should only be activated where the clinical model explicitly
-- treats the absence as informative.
--
-- These rows are intentionally conservative and are NOT required for the
-- positive consolidation proof chain.
--
-- They can be enabled in a later seed once the fact engine formally supports
-- explicit NEGATED / ABSENT observations.
--
-- Example architecture:
--
--   feature_type = 'fact'
--   operator     = 'eq'
--   value        = 'false'
--   polarity     = 'negative'
--
-- DO NOT seed these as ordinary positive facts.
--
-- =============================================================================


-- =============================================================================
-- 7. MACHINE-READABLE CONSOLIDATION FACTS
-- =============================================================================
--
-- These comments define the canonical fact contract used by the clinical CPU.
--
-- RLL_DULLNESS
--     true/false
--
-- RLL_BRONCHIAL_BREATH_SOUNDS
--     true/false
--
-- CRACKLES
--     true/false
--
-- CHEST_PAIN_PLEURITIC
--     YES/NO
--
-- DYSPNOEA_PRESENT
--     YES/NO
--
-- The observation layer should normalize synonyms into these canonical codes.
--
-- Examples:
--
--   "dull percussion note right base"
--       → RLL_DULLNESS = true
--
--   "bronchial breathing RLL"
--       → RLL_BRONCHIAL_BREATH_SOUNDS = true
--
--   "fine inspiratory crackles"
--       → CRACKLES = true
--
--   "pain worse on inspiration"
--       → CHEST_PAIN_PLEURITIC = "YES"
--
--   "shortness of breath"
--       → DYSPNOEA_PRESENT = "YES"
--
-- =============================================================================


-- =============================================================================
-- 8. VALIDATION QUERIES
-- =============================================================================
--
-- These are SELECT statements only. They do not mutate the database.
-- They can be run after the seed to prove the graph exists.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 8.1 Confirm phenotype
-- -----------------------------------------------------------------------------

SELECT
    id,
    phenotype_code,
    canonical_name
FROM knowledge.phenotype
WHERE phenotype_code = 'PHEN-ACUTE-LRTI';


-- -----------------------------------------------------------------------------
-- 8.2 Confirm phenotype features
-- -----------------------------------------------------------------------------

SELECT
    p.phenotype_code,
    pf.feature_code,
    pf.operator,
    pf.value,
    pf.weight,
    pf.polarity
FROM knowledge.phenotype_feature pf
JOIN knowledge.phenotype p
    ON p.id = pf.phenotype_id
WHERE p.phenotype_code = 'PHEN-ACUTE-LRTI'
  AND pf.feature_code IN
      (
          'RLL_DULLNESS',
          'RLL_BRONCHIAL_BREATH_SOUNDS',
          'CRACKLES',
          'CHEST_PAIN_PLEURITIC',
          'DYSPNOEA_PRESENT'
      )
ORDER BY pf.weight DESC;


-- -----------------------------------------------------------------------------
-- 8.3 Confirm mechanism
-- -----------------------------------------------------------------------------

SELECT
    id,
    mechanism_code,
    canonical_name
FROM knowledge.mechanism
WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION';


-- -----------------------------------------------------------------------------
-- 8.4 Confirm mechanism features
-- -----------------------------------------------------------------------------

SELECT
    m.mechanism_code,
    mf.feature_code,
    mf.weight,
    mf.polarity
FROM knowledge.mechanism_feature mf
JOIN knowledge.mechanism m
    ON m.id = mf.mechanism_id
WHERE m.mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
  AND mf.feature_code IN
      (
          'RLL_DULLNESS',
          'RLL_BRONCHIAL_BREATH_SOUNDS',
          'CRACKLES',
          'CHEST_PAIN_PLEURITIC'
      )
ORDER BY mf.weight DESC;


-- -----------------------------------------------------------------------------
-- 8.5 Confirm mechanism → phenotype link
-- -----------------------------------------------------------------------------

SELECT
    m.mechanism_code,
    p.phenotype_code,
    mp.weight
FROM knowledge.mechanism_phenotype mp
JOIN knowledge.mechanism m
    ON m.id = mp.mechanism_id
JOIN knowledge.phenotype p
    ON p.id = mp.phenotype_id
WHERE m.mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
  AND p.phenotype_code = 'PHEN-ACUTE-LRTI';


-- =============================================================================
-- 9. COMPLETE GRAPH PROOF
-- =============================================================================
--
-- This query gives one machine-readable view of:
--
--       FINDING
--          ↓
--       PHENOTYPE
--          ↓
--       MECHANISM
--
-- =============================================================================

SELECT
    pf.feature_code,
    pf.value AS phenotype_value,
    pf.weight AS phenotype_weight,
    p.phenotype_code,
    m.mechanism_code,
    mf.weight AS mechanism_weight
FROM knowledge.phenotype_feature pf

JOIN knowledge.phenotype p
    ON p.id = pf.phenotype_id

JOIN knowledge.mechanism_phenotype mp
    ON mp.phenotype_id = p.id

JOIN knowledge.mechanism m
    ON m.id = mp.mechanism_id

JOIN knowledge.mechanism_feature mf
    ON mf.mechanism_id = m.id
   AND mf.feature_code = pf.feature_code

WHERE p.phenotype_code = 'PHEN-ACUTE-LRTI'
  AND m.mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
  AND pf.feature_code IN
      (
          'RLL_DULLNESS',
          'RLL_BRONCHIAL_BREATH_SOUNDS',
          'CRACKLES',
          'CHEST_PAIN_PLEURITIC'
      )

ORDER BY
    pf.weight DESC,
    pf.feature_code;


-- =============================================================================
-- 10. EXPECTED MACHINE GRAPH
-- =============================================================================
--
-- The resulting architecture is:
--
--
-- RLL_DULLNESS ──────────────────────┐
--                                    │
-- RLL_BRONCHIAL_BREATH_SOUNDS ───────┤
--                                    ├──► PHEN-ACUTE-LRTI
-- CRACKLES ──────────────────────────┤
--                                    │
-- CHEST_PAIN_PLEURITIC ──────────────┤
--                                    │
-- DYSPNOEA_PRESENT ──────────────────┘
--
--
-- RLL_DULLNESS ──────────────────────┐
--                                    │
-- RLL_BRONCHIAL_BREATH_SOUNDS ───────┤
--                                    ├──► MECH-ALVEOLAR-INFLAMMATION
-- CRACKLES ──────────────────────────┤
--                                    │
-- CHEST_PAIN_PLEURITIC ──────────────┘
--
--
-- MECH-ALVEOLAR-INFLAMMATION
--              │
--              ▼
--       PHEN-ACUTE-LRTI
--
--
-- Disease reasoning then occurs downstream:
--
--       UNIVERSAL FACTS
--             ↓
--       PHENOTYPE
--             ↓
--       MECHANISM
--             ↓
--       CONDITION / DIFFERENTIAL
--             ↓
--       INVESTIGATION
--             ↓
--       MANAGEMENT
--             ↓
--       MONITORING
--             ↓
--       EDUCATION / FOLLOW-UP
--
-- =============================================================================
-- END OF SEED ZP9
-- =============================================================================