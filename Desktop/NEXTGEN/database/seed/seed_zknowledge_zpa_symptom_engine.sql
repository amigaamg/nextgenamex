-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP9
-- UNIVERSAL CONSOLIDATION FINDINGS → PHENOTYPE → MECHANISM GRAPH
-- =============================================================================
--
-- PURPOSE
-- -------
-- Phase 1E hardening of the Universal Clinical Intelligence Graph.
--
-- This seed establishes reusable pulmonary consolidation evidence and connects
-- it to:
--
--      UNIVERSAL CLINICAL FACT
--              │
--              ├──────────────► PHEN-ACUTE-LRTI
--              │
--              └──────────────► MECH-ALVEOLAR-INFLAMMATION
--                                      │
--                                      ▼
--                               PHEN-ACUTE-LRTI
--
-- The findings are UNIVERSAL clinical evidence.
--
-- They are NOT owned by pneumonia.
--
-- They may occur in:
--
--   • community-acquired pneumonia
--   • aspiration pneumonia
--   • pulmonary infarction with peripheral consolidation
--   • organizing pneumonia
--   • pulmonary haemorrhage
--   • atelectatic/consolidative processes
--   • other focal alveolar syndromes
--
-- The disease layer therefore remains downstream.
--
-- ARCHITECTURAL RULE
-- ------------------
--
--       OBSERVATION
--            ↓
--       UNIVERSAL FACT
--            ↓
--       PHENOTYPE
--            ↓
--       MECHANISM
--            ↓
--       CONDITION / DIFFERENTIAL
--            ↓
--       INVESTIGATION
--            ↓
--       MANAGEMENT
--            ↓
--       MONITORING
--            ↓
--       EDUCATION / FOLLOW-UP
--
-- This seed MUST NOT create:
--
--       consolidation → pneumonia
--
-- directly.
--
-- It only establishes:
--
--       consolidation findings → phenotype
--       consolidation findings → mechanism
--       mechanism ↔ phenotype
--
-- DEPENDENCIES
-- ------------
--
-- Required existing objects:
--
--   knowledge.phenotype
--       PHEN-ACUTE-LRTI
--
--   knowledge.mechanism
--       MECH-ALVEOLAR-INFLAMMATION
--
-- Required relationship tables:
--
--   knowledge.phenotype_feature
--   knowledge.mechanism_feature
--   knowledge.mechanism_phenotype
--
-- SEED ORDER
-- ----------
--
-- ZP9 runs after the foundational phenotype/mechanism seeds.
--
-- =============================================================================


BEGIN;


-- =============================================================================
-- 0. DEPENDENCY VALIDATION
-- =============================================================================
--
-- Fail loudly if foundational intelligence objects do not exist.
--
-- This is preferable to silently inserting NULL foreign keys or creating an
-- apparently successful but incomplete intelligence graph.
--
-- =============================================================================

DO $$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM knowledge.phenotype
        WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
    )
    THEN
        RAISE EXCEPTION
            'ZP9 dependency missing: phenotype PHEN-ACUTE-LRTI does not exist';
    END IF;


    IF NOT EXISTS
    (
        SELECT 1
        FROM knowledge.mechanism
        WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
    )
    THEN
        RAISE EXCEPTION
            'ZP9 dependency missing: mechanism MECH-ALVEOLAR-INFLAMMATION does not exist';
    END IF;

END
$$;


-- =============================================================================
-- 1. UNIVERSAL CONSOLIDATION → ACUTE LRTI PHENOTYPE
-- =============================================================================
--
-- These are clinical findings.
--
-- They are NOT diagnoses.
--
-- The phenotype represents an acute lower-respiratory presentation and may
-- subsequently support several disease hypotheses.
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
    v.feature_type,
    v.feature_code,
    v.operator,
    v.value::jsonb,
    v.weight,
    v.polarity
FROM
(
    VALUES

        -----------------------------------------------------------------------
        -- Focal percussion dullness
        -----------------------------------------------------------------------
        (
            'fact',
            'RLL_DULLNESS',
            'eq',
            'true',
            1.0::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Bronchial breath sounds over focal area
        -----------------------------------------------------------------------
        (
            'fact',
            'RLL_BRONCHIAL_BREATH_SOUNDS',
            'eq',
            'true',
            1.0::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Crackles
        -----------------------------------------------------------------------
        (
            'fact',
            'CRACKLES',
            'eq',
            'true',
            0.9::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Pleuritic chest pain
        -----------------------------------------------------------------------
        (
            'fact',
            'CHEST_PAIN_PLEURITIC',
            'eq',
            '"YES"',
            0.7::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Dyspnoea
        -----------------------------------------------------------------------
        (
            'fact',
            'DYSPNOEA_PRESENT',
            'eq',
            '"YES"',
            0.6::numeric,
            'positive'
        )

) AS v
(
    feature_type,
    feature_code,
    operator,
    value,
    weight,
    polarity
)

CROSS JOIN
(
    SELECT id
    FROM knowledge.phenotype
    WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
) AS p

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. UNIVERSAL CONSOLIDATION → ALVEOLAR INFLAMMATION MECHANISM
-- =============================================================================
--
-- These findings support an alveolar process.
--
-- They do NOT establish infectious aetiology by themselves.
--
-- Therefore:
--
--       alveolar inflammation ≠ pneumonia
--
-- The mechanism remains reusable by multiple conditions.
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
    v.feature_type,
    v.feature_code,
    v.weight,
    v.polarity
FROM
(
    VALUES

        -----------------------------------------------------------------------
        -- Focal dullness
        -----------------------------------------------------------------------
        (
            'fact',
            'RLL_DULLNESS',
            1.0::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Bronchial breathing
        -----------------------------------------------------------------------
        (
            'fact',
            'RLL_BRONCHIAL_BREATH_SOUNDS',
            1.0::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Crackles
        -----------------------------------------------------------------------
        (
            'fact',
            'CRACKLES',
            0.8::numeric,
            'positive'
        ),

        -----------------------------------------------------------------------
        -- Pleuritic pain
        -----------------------------------------------------------------------
        (
            'fact',
            'CHEST_PAIN_PLEURITIC',
            0.8::numeric,
            'positive'
        )

) AS v
(
    feature_type,
    feature_code,
    weight,
    polarity
)

CROSS JOIN
(
    SELECT id
    FROM knowledge.mechanism
    WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
) AS m

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. MECHANISM ↔ PHENOTYPE LINK
-- =============================================================================
--
-- Focal consolidation is strongly compatible with an alveolar inflammatory
-- mechanism.
--
-- This remains a mechanism ↔ phenotype relationship.
--
-- It does NOT directly establish a disease.
--
-- =============================================================================

INSERT INTO knowledge.mechanism_phenotype
(
    mechanism_id,
    phenotype_id,
    weight
)
SELECT
    m.id,
    p.id,
    1.0
FROM
(
    SELECT id
    FROM knowledge.mechanism
    WHERE mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
) AS m

CROSS JOIN
(
    SELECT id
    FROM knowledge.phenotype
    WHERE phenotype_code = 'PHEN-ACUTE-LRTI'
) AS p

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. CANONICAL FACT CONTRACT
-- =============================================================================
--
-- The following canonical codes form the machine-facing vocabulary for this
-- consolidation phenotype.
--
-- The observation layer should normalize clinical language into these codes.
--
-- =============================================================================
--
-- RLL_DULLNESS
--     Domain: examination
--     Type: boolean
--     Meaning: percussion dullness over right lower lung field
--
-- RLL_BRONCHIAL_BREATH_SOUNDS
--     Domain: examination
--     Type: boolean
--     Meaning: bronchial breath sounds over right lower lung field
--
-- CRACKLES
--     Domain: examination
--     Type: boolean
--     Meaning: crackles detected on auscultation
--
-- CHEST_PAIN_PLEURITIC
--     Domain: history
--     Type: coded
--     Values: YES / NO / UNKNOWN
--
-- DYSPNOEA_PRESENT
--     Domain: history
--     Type: coded
--     Values: YES / NO / UNKNOWN
--
-- =============================================================================


-- =============================================================================
-- 5. GRAPH INTEGRITY VALIDATION
-- =============================================================================
--
-- Verify that the expected phenotype features exist.
--
-- =============================================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_count
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
      );

    IF v_count < 5 THEN
        RAISE EXCEPTION
            'ZP9 validation failed: expected 5 phenotype consolidation features, found %',
            v_count;
    END IF;


END
$$;


-- =============================================================================
-- 6. MECHANISM FEATURE VALIDATION
-- =============================================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_count
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
      );

    IF v_count < 4 THEN
        RAISE EXCEPTION
            'ZP9 validation failed: expected 4 mechanism consolidation features, found %',
            v_count;
    END IF;

END
$$;


-- =============================================================================
-- 7. MECHANISM → PHENOTYPE VALIDATION
-- =============================================================================

DO $$
DECLARE
    v_count INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_count
    FROM knowledge.mechanism_phenotype mp
    JOIN knowledge.mechanism m
      ON m.id = mp.mechanism_id
    JOIN knowledge.phenotype p
      ON p.id = mp.phenotype_id
    WHERE m.mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
      AND p.phenotype_code = 'PHEN-ACUTE-LRTI';

    IF v_count < 1 THEN
        RAISE EXCEPTION
            'ZP9 validation failed: mechanism → phenotype relationship missing';
    END IF;

END
$$;


-- =============================================================================
-- 8. UNIVERSAL FINDING GRAPH VALIDATION
-- =============================================================================
--
-- This proves that every expected consolidation finding can participate in
-- both the phenotype and mechanism layers.
--
-- =============================================================================

SELECT
    pf.feature_code,

    pf.value
        AS phenotype_value,

    pf.weight
        AS phenotype_weight,

    pf.polarity
        AS phenotype_polarity,

    p.phenotype_code,

    m.mechanism_code,

    mf.weight
        AS mechanism_weight,

    mf.polarity
        AS mechanism_polarity,

    mp.weight
        AS mechanism_phenotype_weight

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
-- 9. PHENOTYPE FEATURE SUMMARY
-- =============================================================================

SELECT
    p.phenotype_code,
    p.canonical_name,
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
ORDER BY
    pf.weight DESC,
    pf.feature_code;


-- =============================================================================
-- 10. MECHANISM FEATURE SUMMARY
-- =============================================================================

SELECT
    m.mechanism_code,
    m.canonical_name,
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
ORDER BY
    mf.weight DESC,
    mf.feature_code;


-- =============================================================================
-- 11. MECHANISM ↔ PHENOTYPE SUMMARY
-- =============================================================================

SELECT
    m.mechanism_code,
    m.canonical_name AS mechanism_name,
    p.phenotype_code,
    p.canonical_name AS phenotype_name,
    mp.weight
FROM knowledge.mechanism_phenotype mp
JOIN knowledge.mechanism m
    ON m.id = mp.mechanism_id
JOIN knowledge.phenotype p
    ON p.id = mp.phenotype_id
WHERE m.mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
  AND p.phenotype_code = 'PHEN-ACUTE-LRTI';


-- =============================================================================
-- 12. COMPLETE UNIVERSAL CONSOLIDATION GRAPH
-- =============================================================================
--
-- Machine-readable representation:
--
--      FINDING
--         │
--         ├──────────────► PHENOTYPE
--         │
--         └──────────────► MECHANISM
--                                │
--                                ▼
--                           PHENOTYPE
--
-- =============================================================================

SELECT
    pf.feature_code,

    p.phenotype_code,

    p.canonical_name
        AS phenotype_name,

    pf.value
        AS observed_value,

    pf.operator
        AS phenotype_operator,

    pf.weight
        AS phenotype_weight,

    pf.polarity
        AS phenotype_polarity,

    m.mechanism_code,

    m.canonical_name
        AS mechanism_name,

    mf.weight
        AS mechanism_weight,

    mf.polarity
        AS mechanism_polarity,

    mp.weight
        AS mechanism_phenotype_weight

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
      'CHEST_PAIN_PLEURITIC',
      'DYSPNOEA_PRESENT'
  )

ORDER BY
    CASE pf.feature_code
        WHEN 'RLL_DULLNESS' THEN 1
        WHEN 'RLL_BRONCHIAL_BREATH_SOUNDS' THEN 2
        WHEN 'CRACKLES' THEN 3
        WHEN 'CHEST_PAIN_PLEURITIC' THEN 4
        WHEN 'DYSPNOEA_PRESENT' THEN 5
        ELSE 99
    END;


-- =============================================================================
-- 13. CANONICAL NORMALIZATION CONTRACT
-- =============================================================================
--
-- The clinical observation/intake layer should normalize free clinical
-- language into the canonical fact vocabulary before the reasoning engine
-- evaluates phenotype or mechanism.
--
-- =============================================================================
--
-- EXAMINATION NORMALIZATION
--
-- "dull percussion note right base"
-- "dullness at right lower zone"
-- "right basal dullness"
-- "RLL percussion dull"
--             ↓
-- RLL_DULLNESS = true
--
--
-- "bronchial breathing RLL"
-- "bronchial breath sounds right base"
-- "bronchial breathing over right lower zone"
--             ↓
-- RLL_BRONCHIAL_BREATH_SOUNDS = true
--
--
-- "fine inspiratory crackles"
-- "crepitations"
-- "basal crackles"
-- "inspiratory crackles"
--             ↓
-- CRACKLES = true
--
--
-- HISTORY NORMALIZATION
--
-- "pain worse when breathing in"
-- "pleuritic chest pain"
-- "sharp pain aggravated by inspiration"
--             ↓
-- CHEST_PAIN_PLEURITIC = "YES"
--
--
-- "shortness of breath"
-- "breathlessness"
-- "difficulty breathing"
-- "dyspnoea"
--             ↓
-- DYSPNOEA_PRESENT = "YES"
--
-- =============================================================================


-- =============================================================================
-- 14. IMPORTANT ABSENCE / NEGATION RULE
-- =============================================================================
--
-- Absence must NOT be inferred from failure to document a finding.
--
-- These states are different:
--
--      TRUE
--      FALSE
--      UNKNOWN / NOT_ASSESSED
--
-- Therefore:
--
--      "No crackles"
--          → CRACKLES = false
--
--      "Chest examination not documented"
--          → CRACKLES = unknown
--
-- The reasoning engine must never interpret:
--
--      missing fact = negative fact
--
-- This distinction is essential for safe clinical inference.
--
-- =============================================================================


-- =============================================================================
-- 15. UNIVERSALITY CHECK
-- =============================================================================
--
-- Confirm that the findings are attached to phenotype/mechanism objects and
-- not directly encoded as pneumonia-specific rules in this seed.
--
-- =============================================================================

SELECT
    pf.feature_code,
    p.phenotype_code,
    'UNIVERSAL_PHENOTYPE_EVIDENCE' AS graph_layer
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

UNION ALL

SELECT
    mf.feature_code,
    m.mechanism_code,
    'UNIVERSAL_MECHANISM_EVIDENCE' AS graph_layer
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
  );


-- =============================================================================
-- 16. FINAL GRAPH ASSERTION
-- =============================================================================
--
-- ZP9 is considered successfully installed only when all critical edges
-- exist.
--
-- =============================================================================

DO $$
DECLARE
    phenotype_features_count INTEGER;
    mechanism_features_count INTEGER;
    mechanism_phenotype_count INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO phenotype_features_count
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
      );


    SELECT COUNT(*)
    INTO mechanism_features_count
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
      );


    SELECT COUNT(*)
    INTO mechanism_phenotype_count
    FROM knowledge.mechanism_phenotype mp
    JOIN knowledge.mechanism m
      ON m.id = mp.mechanism_id
    JOIN knowledge.phenotype p
      ON p.id = mp.phenotype_id
    WHERE m.mechanism_code = 'MECH-ALVEOLAR-INFLAMMATION'
      AND p.phenotype_code = 'PHEN-ACUTE-LRTI';


    IF phenotype_features_count < 5 THEN
        RAISE EXCEPTION
            'ZP9 FAILED: phenotype graph incomplete (%/5 features)',
            phenotype_features_count;
    END IF;


    IF mechanism_features_count < 4 THEN
        RAISE EXCEPTION
            'ZP9 FAILED: mechanism graph incomplete (%/4 features)',
            mechanism_features_count;
    END IF;


    IF mechanism_phenotype_count < 1 THEN
        RAISE EXCEPTION
            'ZP9 FAILED: mechanism → phenotype edge missing';
    END IF;


    RAISE NOTICE
        'ZP9 SUCCESS: universal consolidation graph installed — % phenotype features, % mechanism features, % mechanism→phenotype edge(s).',
        phenotype_features_count,
        mechanism_features_count,
        mechanism_phenotype_count;

END
$$;


COMMIT;


-- =============================================================================
-- EXPECTED UNIVERSAL INTELLIGENCE GRAPH
-- =============================================================================
--
--
--  RLL_DULLNESS ────────────────────────────────┐
--                                               │
--  RLL_BRONCHIAL_BREATH_SOUNDS ─────────────────┤
--                                               │
--  CRACKLES ────────────────────────────────────┤
--                                               ├──► PHEN-ACUTE-LRTI
--  CHEST_PAIN_PLEURITIC ────────────────────────┤
--                                               │
--  DYSPNOEA_PRESENT ────────────────────────────┘
--
--
--
--  RLL_DULLNESS ────────────────────────────────┐
--                                               │
--  RLL_BRONCHIAL_BREATH_SOUNDS ─────────────────┤
--                                               │
--  CRACKLES ────────────────────────────────────┤
--                                               ├──► MECH-ALVEOLAR-INFLAMMATION
--  CHEST_PAIN_PLEURITIC ────────────────────────┘
--
--
--
--              MECH-ALVEOLAR-INFLAMMATION
--                         │
--                         ▼
--                  PHEN-ACUTE-LRTI
--
--
--                     ↓
--              CONDITION LAYER
--
--                     ↓
--             DIFFERENTIAL ENGINE
--
--                     ↓
--              INVESTIGATION CPU
--
--                     ↓
--              MANAGEMENT ENGINE
--
--                     ↓
--             MONITORING ENGINE
--
--                     ↓
--          EDUCATION / FOLLOW-UP
--
--
-- =============================================================================
-- END OF SEED ZP9
-- =============================================================================