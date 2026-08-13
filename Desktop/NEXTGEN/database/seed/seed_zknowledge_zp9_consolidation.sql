-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP9: consolidation findings wired into the graph
-- =============================================================================
-- Phase 1E hardening: the acute infective lower-respiratory phenotype
-- (PHEN-ACUTE-LRTI) must recognize the UNIVERSAL consolidation findings
-- (RLL dullness, RLL bronchial breath sounds, crackles) and the pleuritic
-- character, otherwise the CAP chain cannot be machine-demonstrated.
--
-- These are NOT disease-owned rules. They are reusable universal findings
-- attached to a reusable phenotype and a reusable mechanism. Any other disease
-- that presents with consolidation (e.g. aspiration pneumonia) reuses them.
--
-- Named seed_zp* so it runs after seed_zknowledge_mechanisms.sql (Z5).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Consolidation findings support the acute infective lower-respiratory phenotype
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.phenotype_feature (phenotype_id, feature_type, feature_code, operator, value, weight, polarity) VALUES
   ((SELECT id FROM knowledge.phenotype WHERE phenotype_code='PHEN-ACUTE-LRTI'), 'fact', 'RLL_DULLNESS',                 'eq',  'true',  1.6, 'positive'),
   ((SELECT id FROM knowledge.phenotype WHERE phenotype_code='PHEN-ACUTE-LRTI'), 'fact', 'RLL_BRONCHIAL_BREATH_SOUNDS', 'eq',  'true',  1.6, 'positive'),
   ((SELECT id FROM knowledge.phenotype WHERE phenotype_code='PHEN-ACUTE-LRTI'), 'fact', 'CRACKLES',                    'eq',  'true',  0.9, 'positive'),
   ((SELECT id FROM knowledge.phenotype WHERE phenotype_code='PHEN-ACUTE-LRTI'), 'fact', 'CHEST_PAIN_PLEURITIC',        'eq',  '"YES"', 0.7, 'positive'),
   ((SELECT id FROM knowledge.phenotype WHERE phenotype_code='PHEN-ACUTE-LRTI'), 'fact', 'DYSPNOEA_PRESENT',            'eq',  '"YES"', 0.6, 'positive')
ON CONFLICT (phenotype_id, feature_type, feature_code, operator, polarity) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Consolidation findings also support the ALVEOLAR-INFLAMMATION mechanism,
-- which is the mechanism most consistent with a focal consolidation pattern.
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.mechanism_feature (mechanism_id, feature_type, feature_code, weight, polarity) VALUES
   ((SELECT id FROM knowledge.mechanism WHERE mechanism_code='MECH-ALVEOLAR-INFLAMMATION'), 'fact', 'RLL_DULLNESS',                 1.0, 'positive'),
   ((SELECT id FROM knowledge.mechanism WHERE mechanism_code='MECH-ALVEOLAR-INFLAMMATION'), 'fact', 'RLL_BRONCHIAL_BREATH_SOUNDS', 1.0, 'positive'),
   ((SELECT id FROM knowledge.mechanism WHERE mechanism_code='MECH-ALVEOLAR-INFLAMMATION'), 'fact', 'CRACKLES',                    0.8, 'positive'),
   ((SELECT id FROM knowledge.mechanism WHERE mechanism_code='MECH-ALVEOLAR-INFLAMMATION'), 'fact', 'CHEST_PAIN_PLEURITIC',        0.8, 'positive')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- The acute LRTI phenotype should be machine-linked to the alveolar
-- inflammation mechanism (currently only 0.7 via Z6); raise to reflect that
-- focal consolidation is the strongest alveolar pattern in this MVP graph.
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.mechanism_phenotype (mechanism_id, phenotype_id, weight) VALUES
   ((SELECT id FROM knowledge.mechanism WHERE mechanism_code='MECH-ALVEOLAR-INFLAMMATION'),
    (SELECT id FROM knowledge.phenotype WHERE phenotype_code='PHEN-ACUTE-LRTI'), 1.0)
ON CONFLICT (mechanism_id, phenotype_id) DO UPDATE SET weight = EXCLUDED.weight;
