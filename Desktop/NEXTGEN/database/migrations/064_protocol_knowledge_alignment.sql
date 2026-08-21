-- =============================================================================
-- 064. PROTOCOL + KNOWLEDGE ALIGNMENT FOR THE MACHINE RUN
-- =============================================================================
--
-- Aligns knowledge content with the documented machine-run behaviour:
--
--   1. OVR-CXR-FACILITY-DEFER: the seeded facility-scoped CXR override carried
--      approval_status='pending' + review_required=true, so the active_override
--      view (migration 020) excluded it. Approve it so the 3.19 configuration
--      chain becomes real.
--
--   2. PROT-CAP-ADULT: the adult community-acquired pneumonia pathway was left
--      'draft'. Activate it so adult CAP activates the intended protocol
--      (the paediatric Kenya pathway must not win for a 35-year-old).
--
--   3. PHEN-ACUTE-LRTI / PHEN-PLEURITIC phenotype features referenced the
--      stale fact code CHEST_PAIN_PLEURITIC. The canonical pleuritic fact is
--      PLEURITIC_CHEST_PAIN (question wiring, migration 060). Point the
--      features at the canonical fact so the phenotype matches.
--
--   4. PHEN-HYPOXAEMIA: the severity phenotype referenced by the CPU's
--      IMMEDIATE_DETERIORATION_PHENOTYPES, governance, rules and the machine
--      run did not exist as a phenotype row. Create it with an SpO2 feature.
--
--   5. PHEN-TUBERCULOSIS: the machine run expects TB to appear in the
--      differential (low-ranked) with against-lines for absent weight loss,
--      night sweats and TB contact. The KB had TB evidence rules but no
--      phenotype → TUBERCULOSIS differential link, so TB never appeared.
--      Create the phenotype and link it with a low weight.
-- =============================================================================

-- 1. Approve the facility CXR override ---------------------------------------
UPDATE knowledge.knowledge_override
   SET approval_status = 'approved',
       review_required = false
 WHERE override_code = 'OVR-CXR-FACILITY-DEFER'
   AND approval_status <> 'approved';

-- 2. Activate the adult CAP protocol -----------------------------------------
UPDATE knowledge.protocol
   SET status = 'active'
 WHERE protocol_code = 'PROT-CAP-ADULT'
   AND status = 'draft';

-- 3. Canonical pleuritic fact code in phenotype features ---------------------
UPDATE knowledge.phenotype_feature pf
   SET feature_code = 'PLEURITIC_CHEST_PAIN'
  FROM knowledge.phenotype ph
 WHERE ph.id = pf.phenotype_id
   AND pf.feature_code = 'CHEST_PAIN_PLEURITIC';

-- 4. PHEN-HYPOXAEMIA ---------------------------------------------------------
INSERT INTO knowledge.phenotype
    (id, concept_id, phenotype_code, canonical_name, display_name, description,
     phenotype_class, status, version)
VALUES
    ('f0f00000-0000-0000-0000-00000000a101'::uuid, NULL, 'PHEN-HYPOXAEMIA', 'Hypoxaemia',
     'Hypoxaemia', 'Severity phenotype: oxygen saturation below the normal threshold.',
     'severity', 'active', 1)
ON CONFLICT (phenotype_code) DO NOTHING;

INSERT INTO knowledge.phenotype_feature
    (id, phenotype_id, feature_type, feature_code, operator, value, weight,
     polarity, certainty, requiredness, temporal_role, minimum_duration,
     maximum_duration, description)
SELECT
    'f0f00000-0000-0000-0000-00000000a201'::uuid, ph.id, 'measurement', 'SPO2', 'lte', '90',
    1.0, 'positive', 'probable', 'supporting', NULL, NULL, NULL,
    'Oxygen saturation at or below 90% is clinically significant hypoxaemia.'
  FROM knowledge.phenotype ph
 WHERE ph.phenotype_code = 'PHEN-HYPOXAEMIA'
ON CONFLICT (id) DO NOTHING;

-- 5. PHEN-TUBERCULOSIS -------------------------------------------------------
INSERT INTO knowledge.phenotype
    (id, concept_id, phenotype_code, canonical_name, display_name, description,
     phenotype_class, status, version)
VALUES
    ('f0f00000-0000-0000-0000-00000000a102'::uuid, NULL, 'PHEN-TUBERCULOSIS', 'Tuberculosis',
     'Tuberculosis', 'Respiratory phenotype compatible with pulmonary tuberculosis.',
     'clinical', 'active', 1)
ON CONFLICT (phenotype_code) DO NOTHING;

INSERT INTO knowledge.phenotype_feature
    (id, phenotype_id, feature_type, feature_code, operator, value, weight,
     polarity, certainty, requiredness, temporal_role, minimum_duration,
     maximum_duration, description)
SELECT
    f.id::uuid, ph.id, f.feature_type, f.feature_code, f.operator, f.value, f.weight,
    f.polarity, f.certainty, f.requiredness, f.temporal_role, f.minimum_duration::interval,
    f.maximum_duration::interval, f.description
  FROM knowledge.phenotype ph
  CROSS JOIN (VALUES
      ('f0f00000-0000-0000-0000-00000000a202', 'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"'::jsonb, 0.8,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Productive cough supports pulmonary TB.'),
      ('f0f00000-0000-0000-0000-00000000a203', 'fact', 'FEVER_PRESENT', 'eq', 'true'::jsonb, 0.8,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Fever supports pulmonary TB.'),
      ('f0f00000-0000-0000-0000-00000000a204', 'fact', 'DYSPNOEA_PRESENT', 'eq', 'true'::jsonb, 0.6,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Dyspnoea may accompany pulmonary TB.'),
      ('f0f00000-0000-0000-0000-00000000a205', 'fact', 'CRACKLES', 'eq', 'true'::jsonb, 0.6,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Crackles may be heard in pulmonary TB.'),
      ('f0f00000-0000-0000-0000-00000000a206', 'fact', 'COUGH_DURATION_DAYS', 'lte', '14'::jsonb, 0.3,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'A subacute cough is compatible with TB.'),
      ('f0f00000-0000-0000-0000-00000000a207', 'fact', 'WEIGHT_LOSS', 'eq', 'true'::jsonb, 0.8,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Weight loss is a classic TB constitutional symptom.'),
      ('f0f00000-0000-0000-0000-00000000a208', 'fact', 'NIGHT_SWEATS', 'eq', 'true'::jsonb, 0.8,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Night sweats are a classic TB constitutional symptom.'),
      ('f0f00000-0000-0000-0000-00000000a209', 'fact', 'TB_CONTACT', 'eq', 'true'::jsonb, 0.8,
       'positive', 'probable', 'supporting', NULL, NULL, NULL, 'Known TB contact increases suspicion.')
  ) AS f(id, feature_type, feature_code, operator, value, weight, polarity,
         certainty, requiredness, temporal_role, minimum_duration,
         maximum_duration, description)
 WHERE ph.phenotype_code = 'PHEN-TUBERCULOSIS'
ON CONFLICT (phenotype_id, feature_type, feature_code, operator, polarity,
             requiredness, temporal_role) DO NOTHING;

INSERT INTO knowledge.phenotype_differential
    (id, phenotype_id, condition_id, relationship_type, weight, polarity, context)
SELECT
    'f0f00000-0000-0000-0000-00000000a301'::uuid, ph.id, c.id,
    'suggestive_of', 0.4, 'positive', NULL
  FROM knowledge.phenotype ph
  CROSS JOIN knowledge.condition c
 WHERE ph.phenotype_code = 'PHEN-TUBERCULOSIS'
   AND c.condition_code = 'TUBERCULOSIS'
ON CONFLICT (phenotype_id, condition_id, relationship_type, polarity) DO NOTHING;