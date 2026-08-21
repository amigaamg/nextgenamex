-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H4 seed zq5: universal symptom dimensions
-- =============================================================================
-- Seeds the H4 grammar on top of the H2 substrate:
--   knowledge.symptom_dimension          (SD001..SD025 canonical registry)
--   knowledge.history_concept            (HC058..HC066 new dimension concepts)
--   knowledge.symptom_dimension_option   (symptom-specific vocabularies)
--   knowledge.red_flag_rule              (FACT + CONTEXT + SIGNIFICANCE)
--   knowledge.exposure_concept           (15 reusable exposure classes)
--   knowledge.symptom_exposure           (symptom → exposure maps)
--   knowledge.symptom_relationship       (diagnostic_weight backfill)
--   knowledge.provenance                 (H1/H12 claim → H4 object edges)
--
-- Deterministic uuid5 object ids (namespace 6ba7b810-9dad-11d1-80b4-00c04fd430c8,
-- scheme "H4:<object_type>:<object_code>" for H4 objects, matching the existing
-- H2 "HISTORY_CONCEPT:<code>" / H3 "H3:<object_type>:<object_code>" conventions)
-- so edges are stable across rebuilds.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. NEW dimension concepts missing from the H2 vocabulary (HC058..HC066)
-- ---------------------------------------------------------------------------
-- H2 gave us HC002-HC012 (onset/duration/time-course/site/radiation/character/
-- severity/aggravating/relieving/associated/functional) plus HC029-HC057
-- symptom-specific concepts. H4 adds the remaining canonical dimensions:
--   PRESENCE, DISTRIBUTION, SYSTEMIC_IMPACT, RED_FLAG, PREVIOUS_EPISODES,
--   PREVIOUS_TREATMENT, RESPONSE_TO_TREATMENT, EVOLUTION, RESOLUTION.
INSERT INTO knowledge.history_concept
    (history_concept_id, concept_code, concept_name, concept_type, reusable, description) VALUES
   ('HC058', 'PRESENCE',              'Presence',              'symptom',   true, 'Whether the symptom is present/absent/unknown/not-assessed (three-state, H2).'),
   ('HC059', 'DISTRIBUTION',          'Distribution',          'symptom',   true, 'Localized/generalized/unilateral/bilateral/proximal/distal/dermatomal (rash, weakness, numbness, pain).'),
   ('HC060', 'SYSTEMIC_IMPACT',       'Systemic impact',       'function',  true, 'Constitutional consequences: appetite, weight, energy, sleep, hydration, mobility, consciousness, nutrition, activity.'),
   ('HC061', 'RED_FLAG',              'Red flag',              'symptom',   true, 'Contextualized clinical-significance rules (fact + context), not a bare boolean.'),
   ('HC062', 'PREVIOUS_EPISODES',     'Previous episodes',     'temporal',  true, 'Whether the symptom has occurred before (recurrent / relapsing).'),
   ('HC063', 'PREVIOUS_TREATMENT',    'Previous treatment',    'background', true, 'What treatment was tried for this illness before this consultation.'),
   ('HC064', 'RESPONSE_TO_TREATMENT', 'Response to treatment', 'background', true, 'Whether previous treatment helped (response / no response / worsened).'),
   ('HC065', 'EVOLUTION',             'Evolution',             'temporal',  true, 'How the symptom has changed character over time (changed quality, spread).'),
   ('HC066', 'RESOLUTION',            'Resolution',            'temporal',  true, 'Whether the symptom disappeared and/or recurred (resolution/recurrence).')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. symptom_dimension — canonical 25-dimension registry (H4 spec §24)
-- ---------------------------------------------------------------------------
-- universal=true  : explored for every symptom (asked broadly).
-- universal=false : conditional on the symptom (site/radiation only where they
--                   make sense — fever has no site).
-- Each row is backed by a history_concept so the H2 vocabulary stays the single
-- source of definitions and nothing is duplicated.
INSERT INTO knowledge.symptom_dimension
    (dimension_id, dimension_code, dimension_name, universal, applicability, history_concept_id, sort_order, description) VALUES
   ('SD001', 'PRESENCE',              'Presence',              true,  'always',      'HC058',  1,  'Present / absent / unknown / not-assessed (three-state).'),
   ('SD002', 'ONSET',                 'Onset',                 true,  'always',      'HC002',  2,  'When it started; sudden vs gradual (raw + canonical).'),
   ('SD003', 'DURATION',              'Duration',              true,  'always',      'HC003',  3,  'value + unit + precision + certainty (structured).'),
   ('SD004', 'TIME_COURSE',           'Time course',           true,  'always',      'HC004',  4,  'single episode/continuous/intermittent/recurrent/progressive/stable/improving/fluctuating/relapsing/stepwise/episodic.'),
   ('SD005', 'FREQUENCY',             'Frequency',             false, 'conditional', 'HC038',  5,  'episodes per day / how often (cough, vomiting, diarrhoea).'),
   ('SD006', 'SITE',                  'Site',                  false, 'conditional', 'HC005',  6,  'where the symptom is felt (pain); NOT_APPLICABLE for fever.'),
   ('SD007', 'DISTRIBUTION',          'Distribution',          false, 'conditional', 'HC059',  7,  'localized/generalized/unilateral/bilateral/proximal/distal/dermatomal.'),
   ('SD008', 'RADIATION',             'Radiation',             false, 'conditional', 'HC006',  8,  'where it spreads to (chest → jaw/arm); separate from site.'),
   ('SD009', 'CHARACTER',             'Character',             false, 'conditional', 'HC007',  9,  'symptom-specific vocabulary (cough: dry/productive; pain: burning/sharp).'),
   ('SD010', 'SEVERITY',              'Severity',              true,  'always',      'HC008', 10,  'measurement model: numeric 1-10 / verbal / functional / clinical.'),
   ('SD011', 'TRIGGERS',              'Triggers',              true,  'always',      'HC036', 11,  'what brings it on (exertion, food, position, time of day, exposure...).'),
   ('SD012', 'AGGRAVATING',           'Aggravating factors',   true,  'always',      'HC009', 12,  'what makes it worse (separate from trigger).'),
   ('SD013', 'RELIEVING',             'Relieving factors',     true,  'always',      'HC010', 13,  'what makes it better (rest, medication, position change...).'),
   ('SD014', 'TIMING_PATTERN',        'Timing/pattern',        true,  'always',      'HC035', 14,  'nocturnal / morning / seasonal / positional.'),
   ('SD015', 'ASSOCIATED',            'Associated symptoms',   true,  'always',      'HC011', 15,  'co-occurring symptoms → new symptom nodes (graph, not questionnaire).'),
   ('SD016', 'FUNCTION',              'Functional impact',     true,  'always',      'HC012', 16,  'walking, stairs, work, school, sleep, eating, breastfeeding, play.'),
   ('SD017', 'SYSTEMIC',              'Systemic impact',       true,  'always',      'HC060', 17,  'appetite, weight, energy, sleep, hydration, mobility, consciousness, nutrition, activity.'),
   ('SD018', 'RED_FLAG',              'Red flag',              false, 'conditional', 'HC061', 18,  'context-aware significance rules (haemoptysis, syncope, severe dyspnoea).'),
   ('SD019', 'EXPOSURE',              'Exposure',              false, 'conditional', 'HC020', 19,  'contact, travel, occupation, animal, insect, food, water, smoke, dust...'),
   ('SD020', 'PREVIOUS_EPISODES',     'Previous episodes',     false, 'conditional', 'HC062', 20,  'recurrent/relapsing history of the same symptom.'),
   ('SD021', 'PREVIOUS_TREATMENT',    'Previous treatment',    false, 'conditional', 'HC063', 21,  'what was tried before this consultation.'),
   ('SD022', 'RESPONSE_TO_TREATMENT', 'Response to treatment', false, 'conditional', 'HC064', 22,  'helped / no response / worsened.'),
   ('SD023', 'PATIENT_PERSPECTIVE',   'Patient perspective',   true,  'always',      'HC023', 23,  'ideas/concerns/expectations/goals (H2 patient_perspective).'),
   ('SD024', 'EVOLUTION',             'Evolution',             true,  'always',      'HC065', 24,  'changed character / spread over time.'),
   ('SD025', 'RESOLUTION',            'Resolution',            false, 'conditional', 'HC066', 25,  'disappeared and/or recurred.')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. symptom_dimension_option — symptom-specific vocabularies (H4 spec §26)
-- ---------------------------------------------------------------------------
-- Universal dimension + symptom-specific vocabulary. These are the controlled
-- vocabularies the CPU offers as answers; the option is always scoped to a
-- (symptom, dimension) pair. (Character is the flagship: cough vs chest pain
-- vs vomiting each keep their own list.)
INSERT INTO knowledge.symptom_dimension_option
    (symptom_id, dimension_id, option_code, option_name, sort_order) VALUES
   -- COUGH × CHARACTER
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'),      'SD009', 'DRY',        'Dry',         1),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'),      'SD009', 'PRODUCTIVE', 'Productive',  2),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'),      'SD009', 'BARKING',    'Barking',     3),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'),      'SD009', 'PAROXYSMAL', 'Paroxysmal',  4),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'),      'SD009', 'WHOOPING',   'Whooping',    5),
   -- CHEST PAIN × CHARACTER
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'PRESSURE',   'Pressure',    1),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'TIGHTNESS',  'Tightness',   2),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'BURNING',    'Burning',     3),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'STABBING',   'Stabbing',    4),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'SHARP',      'Sharp',       5),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'DULL',       'Dull',        6),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'ACHING',     'Aching',      7),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'COLICY',     'Colicky',     8),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD009', 'TEARING',    'Tearing',     9),
   -- ABDOMINAL PAIN × CHARACTER
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ABDOMINAL-PAIN'),  'SD009', 'COLICY',     'Colicky',     1),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ABDOMINAL-PAIN'),  'SD009', 'BURNING',    'Burning',     2),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ABDOMINAL-PAIN'),  'SD009', 'SHARP',      'Sharp',       3),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ABDOMINAL-PAIN'),  'SD009', 'DULL',       'Dull',        4),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ABDOMINAL-PAIN'),  'SD009', 'ACHING',     'Aching',      5),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ABDOMINAL-PAIN'),  'SD009', 'CRAMPING',   'Cramping',    6),
   -- CHEST PAIN × RADIATION
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD008', 'LEFT_ARM',   'Left arm',    1),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD008', 'JAW',        'Jaw',         2),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD008', 'NECK',       'Neck',        3),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD008', 'BACK',       'Back',        4),
   ((SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'), 'SD008', 'EPIGASTRIUM','Epigastrium', 5)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. red_flag_rule — FACT + CONTEXT + CLINICAL_SIGNIFICANCE (H4 spec §19)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.red_flag_rule
    (rule_id, rule_code, symptom_id, fact_definition_code, context_condition, clinical_significance, urgency, priority, evidence_claim_code) VALUES
   ('RFR001', 'RFR-HAEMOPTYSIS',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-HAEMOPTYSIS'),
    'BLOOD_IN_SPUTUM', NULL,
    'Haemoptysis must never be dismissed without careful evaluation — source (TB, bronchial carcinoma, PE) must be sought.',
    'emergency', 100, 'HCH12-0007'),
   ('RFR002', 'RFR-ORTHOPNOEA',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-ORTHOPNOEA'),
    'ORTHOPNOEA', NULL,
    'Orthopnoea indicates left-heart failure / pulmonary oedema — requires urgent cardiac assessment.',
    'urgent', 90, 'HCH12-0003'),
   ('RFR003', 'RFR-SEVERE-DYSPNOEA',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-DYSPNOEA'),
    'DYSPNOEA_SEVERITY', '{"fact":{"code":"DYSPNOEA_SEVERITY","gte":4}}',
    'Dyspnoea at rest / on minimal exertion (MRC 4-5) — consider respiratory failure, PE, severe heart failure.',
    'emergency', 100, 'HCH12-0021'),
   ('RFR004', 'RFR-SUDDEN-CHEST-PAIN',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-CHEST-PAIN'),
    'CHEST_PAIN_PLEURITIC', '{"fact":{"code":"CHEST_PAIN_PLEURITIC","value":"YES"}}',
    'Pleuritic chest pain raises PE / pneumonia / pneumothorax — localize the source.',
    'urgent', 90, 'HCH12-0009'),
   ('RFR005', 'RFR-REST-DYSPNOEA',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-DYSPNOEA'),
    'DYSPNOEA_PRESENT', '{"fact":{"code":"DYSPNOEA_PRESENT","value":"YES"}}',
    'Breathlessness inappropriate to exertion — quantify with the MRC scale and functional limitation.',
    'urgent', 85, 'HCH12-0002'),
   ('RFR006', 'RFR-WEIGHT-LOSS',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-WEIGHT-LOSS'),
    'WEIGHT_LOSS', NULL,
    'Unintentional weight loss accompanying respiratory symptoms suggests TB / malignancy — quantify amount and timeframe.',
    'urgent', 80, 'HCH12-0020'),
   ('RFR007', 'RFR-FEVER-RIGORS',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-FEVER'),
    'CHILLS', NULL,
    'Fever with rigors suggests bacteraemia / severe infection — assess the septic patient urgently.',
    'urgent', 85, 'HCH12-0020'),
   ('RFR008', 'RFR-RESPIRATORY-DISTRESS',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-DYSPNOEA'),
    'RESPIRATORY_DISTRESS', NULL,
    'Respiratory distress on inspection — looks unwell / tachypnoeic; treat as potentially serious.',
    'emergency', 100, 'HCH2-0002'),
   ('RFR009', 'RFR-CHEST-INDRAWING',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-DYSPNOEA'),
    'CHEST_INDRAWING', NULL,
    'Subcostal/intercostal indrawing in a child indicates significant respiratory effort.',
    'emergency', 100, 'HCH12-0017'),
   ('RFR010', 'RFR-CYANOSIS',
    (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-DYSPNOEA'),
    'CYANOSIS', NULL,
    'Central cyanosis implies significant hypoxaemia — urgent assessment required.',
    'emergency', 100, 'HCH2-0002')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. exposure_concept — 15 reusable exposure classes (H4 spec §20)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.exposure_concept
    (exposure_code, exposure_class, label, description) VALUES
   ('CONTACT',      'infectious', 'Contact',        'Contacts with infected persons; living arrangements; household members.'),
   ('TRAVEL',       'infectious', 'Travel',         'Recent travel and endemic exposure.'),
   ('OCCUPATION',   'occupational','Occupation',    'Workplace exposures acting now or years later (asbestos, silica).'),
   ('ANIMAL',       'infectious', 'Animal',         'Contact with animals / bites / scratches.'),
   ('INSECT',       'infectious', 'Insect',         'Insect bites; vector exposure.'),
   ('FOOD',         'dietary',    'Food',           'Food exposure; foodborne risk.'),
   ('WATER',        'dietary',    'Water',          'Water exposure; sanitation.'),
   ('SEXUAL',       'behavioural','Sexual',         'Sexual history / risk exposure.'),
   ('HEALTHCARE',   'infectious', 'Healthcare',     'Healthcare exposure; previous admissions / procedures.'),
   ('ENVIRONMENTAL', 'environmental', 'Environmental','Home environment; housing; pollutants.'),
   ('SMOKE',        'substance',  'Smoke',          'Cigarette / tobacco smoke exposure.'),
   ('BIOMASS',      'environmental','Biomass fuel', 'Biomass / wood / dung fuel smoke exposure.'),
   ('DUST',         'occupational','Dust',          'Occupational dust (construction, mining, grain).'),
   ('CHEMICAL',     'occupational','Chemical',      'Occupational chemical / fume exposure.'),
   ('DRUG',         'behavioural','Drug',           'Recreational / illicit drug exposure (incl. inhaled).')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. symptom_exposure — which exposure concepts each symptom explores
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.symptom_exposure (symptom_id, exposure_code, priority)
SELECT s.id, x.exposure_code, x.priority
FROM (VALUES
   ('SYM-COUGH',        'SMOKE',   100),
   ('SYM-COUGH',        'CONTACT',  90),
   ('SYM-COUGH',        'TRAVEL',   80),
   ('SYM-COUGH',        'OCCUPATION', 80),
   ('SYM-COUGH',        'BIOMASS',  70),
   ('SYM-COUGH',        'DUST',     70),
   ('SYM-FEVER',        'CONTACT', 100),
   ('SYM-FEVER',        'TRAVEL',   90),
   ('SYM-FEVER',        'ANIMAL',   80),
   ('SYM-FEVER',        'INSECT',   80),
   ('SYM-FEVER',        'FOOD',     70),
   ('SYM-FEVER',        'WATER',    70),
   ('SYM-FEVER',        'HEALTHCARE', 70),
   ('SYM-CHEST-PAIN',   'SMOKE',    80),
   ('SYM-CHEST-PAIN',   'OCCUPATION', 60),
   ('SYM-DYSPNOEA',     'SMOKE',    90),
   ('SYM-DYSPNOEA',     'OCCUPATION', 80),
   ('SYM-DYSPNOEA',     'BIOMASS',  80),
   ('SYM-DYSPNOEA',     'DUST',     70),
   ('SYM-WEIGHT-LOSS',  'CONTACT',  90),
   ('SYM-WEIGHT-LOSS',  'TRAVEL',   70)
) AS x(symptom_code, exposure_code, priority)
JOIN knowledge.symptom s ON s.symptom_code = x.symptom_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. symptom_relationship.diagnostic_weight — hard vs soft symptoms (H4 §16)
-- ---------------------------------------------------------------------------
-- Hutchison: a hard symptom carries more diagnostic weight; soft symptoms vary
-- or occur across many conditions. Haemoptysis is harder than fever; fever
-- harder than night sweats. Higher weight = more diagnostic value.
UPDATE knowledge.symptom_relationship r SET diagnostic_weight = x.weight
FROM (VALUES
   ('SYM-COUGH',      'SYM-HAEMOPTYSIS', 5),
   ('SYM-COUGH',      'SYM-FEVER',       3),
   ('SYM-COUGH',      'SYM-DYSPNOEA',    3),
   ('SYM-COUGH',      'SYM-CHEST-PAIN',  3),
   ('SYM-COUGH',      'SYM-WEIGHT-LOSS', 4),
   ('SYM-COUGH',      'SYM-NIGHT-SWEATS',3),
   ('SYM-FEVER',      'SYM-NIGHT-SWEATS',3),
   ('SYM-FEVER',      'SYM-WEIGHT-LOSS', 4),
   ('SYM-NIGHT-SWEATS','SYM-WEIGHT-LOSS',4)
) AS x(src, tgt, weight)
JOIN knowledge.symptom s1 ON s1.symptom_code = x.src
JOIN knowledge.symptom s2 ON s2.symptom_code = x.tgt
WHERE r.symptom_id = s1.id AND r.related_symptom_id = s2.id
  AND r.diagnostic_weight <> x.weight;

-- ---------------------------------------------------------------------------
-- 8. provenance — H1/H12 claims → H4 objects
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, x.object_type, x.object_id::uuid, x.object_code, 'derived_from'
FROM (VALUES
   ('HCH1-0004', 'history_concept', 'dd9e83d5-60ac-5b02-94ed-229f112951e6', 'HC058'),
   ('HCH1-0013', 'history_concept', '5a22bf51-a074-5807-8307-882b8d68760f', 'HC059'),
   ('HCH1-0004', 'history_concept', 'af4e083c-16e0-5e26-a37d-512129e63852', 'HC060'),
   ('HCH12-0007', 'history_concept', '6bdb1991-28c4-52ab-9255-c0d9fd0a550f', 'HC061'),
   ('HCH1-0005', 'history_concept', '81cf4759-5a10-5a26-b741-24c4c74ab80a', 'HC062'),
   ('HCH1-0013', 'history_concept', '719a6313-0ef0-5ef1-9e97-a2b0d52e8147', 'HC063'),
   ('HCH1-0013', 'history_concept', '6005cb26-da69-569a-8ba0-3447ee0d2718', 'HC064'),
   ('HCH1-0021', 'history_concept', 'c2bbb63c-f532-55ba-ab91-f4763758aba1', 'HC065'),
   ('HCH1-0021', 'history_concept', '785de120-5ef6-5316-8bd0-8c25a7e142fe', 'HC066'),
   -- canonical dimensions
   ('HCH1-0004', 'symptom_dimension', '8e5e8d2e-7065-54b2-8951-85a80fda30b5', 'SD001'),
   ('HCH1-0013', 'symptom_dimension', '985c93e7-b4e6-5f13-b312-0e3193a2f863', 'SD002'),
   ('HCH1-0013', 'symptom_dimension', '0e8a62ef-2cf3-5575-92ae-de91540a2466', 'SD003'),
   ('HCH1-0021', 'symptom_dimension', '4ec1a098-a9ef-54fa-b3f9-2647195edf09', 'SD004'),
   ('HCH1-0013', 'symptom_dimension', '50795d01-8206-58ff-b5de-00abecf3bdac', 'SD005'),
   ('HCH1-0015', 'symptom_dimension', '41999326-9e38-5aa3-8d44-aa413f953df7', 'SD006'),
   ('HCH1-0013', 'symptom_dimension', 'bbc85b4d-bb83-53bc-ba34-cdacf7010a6a', 'SD007'),
   ('HCH1-0015', 'symptom_dimension', '577dd56f-c9c2-5a0e-b620-d8b1485fcbd1', 'SD008'),
   ('HCH1-0015', 'symptom_dimension', '871ead9c-8dff-5834-b2ed-7266eee0502b', 'SD009'),
   ('HCH1-0012', 'symptom_dimension', '0c18bc05-5bba-5286-96f0-d9ea33026db1', 'SD010'),
   ('HCH1-0013', 'symptom_dimension', '440dd5d6-05d0-562e-a628-e9ba64c81631', 'SD011'),
   ('HCH1-0015', 'symptom_dimension', '835e8fae-c376-5308-b528-77a96e545dd0', 'SD012'),
   ('HCH1-0015', 'symptom_dimension', '3ae52317-a084-5ca9-a6fe-6ab119d9fabf', 'SD013'),
   ('HCH1-0013', 'symptom_dimension', '3f207a3f-97d7-5264-bb83-ddec7faa69a3', 'SD014'),
   ('HCH1-0004', 'symptom_dimension', '2101afca-ac0d-5c1c-b43f-3e085277983f', 'SD015'),
   ('HCH1-0011', 'symptom_dimension', '964cc45b-6653-58fd-803d-cd1e503dd49e', 'SD016'),
   ('HCH1-0004', 'symptom_dimension', '5a3d44ed-a24b-577f-8b2d-991dd01738b1', 'SD017'),
   ('HCH12-0007', 'symptom_dimension', 'd557b1af-db7b-5bc5-af36-8546855489d3', 'SD018'),
   ('HCH1-0018', 'symptom_dimension', 'ef724969-c131-5bbb-a475-2003d2dd2f88', 'SD019'),
   ('HCH1-0005', 'symptom_dimension', '72dcd0e2-b72b-5726-9fad-69f36fca2450', 'SD020'),
   ('HCH1-0013', 'symptom_dimension', 'e6a4338d-1198-548e-8063-ce47ca59add4', 'SD021'),
   ('HCH1-0013', 'symptom_dimension', '3d09f922-7833-5cd2-93af-6fa0f0d6e1b1', 'SD022'),
   ('HCH1-0023', 'symptom_dimension', '53c24113-ef4e-524c-a2a7-c72dbcb67c1f', 'SD023'),
   ('HCH1-0021', 'symptom_dimension', 'e92e21f1-036e-5b2a-8420-930c65add75f', 'SD024'),
   ('HCH1-0021', 'symptom_dimension', '4e39bd02-72ca-5330-b27c-fb6fe43fcb4c', 'SD025'),
   -- symptom-dimension options (cough character, chest-pain character/radiation, abdo character)
   ('HCH12-0005', 'symptom_dimension_option', 'd01304fc-00e1-5d59-abd0-826aa0559e77', 'SYM-COUGH:CHARACTER'),
   ('HCH12-0009', 'symptom_dimension_option', 'e3c3359f-8073-5629-847e-9b914a7a6478', 'SYM-CHEST-PAIN:CHARACTER'),
   ('HCH12-0009', 'symptom_dimension_option', '25c5d416-e08b-5947-89d4-4b3bf5afd055', 'SYM-CHEST-PAIN:RADIATION'),
   ('HCH12-0010', 'symptom_dimension_option', '91c91eb8-07d7-5a3e-a8dc-66a98ce78b20', 'SYM-ABDOMINAL-PAIN:CHARACTER'),
   -- red-flag rules
   ('HCH12-0007', 'red_flag_rule', '83d445d6-449b-5d32-aebc-bdc3e29886ec', 'RFR-HAEMOPTYSIS'),
   ('HCH12-0003', 'red_flag_rule', '8b7c033f-6764-5a3e-b45a-6552da59e662', 'RFR-ORTHOPNOEA'),
   ('HCH12-0021', 'red_flag_rule', '15b004d1-b65a-5b33-812c-8cfb9456b8c6', 'RFR-SEVERE-DYSPNOEA'),
   ('HCH12-0009', 'red_flag_rule', 'eb6ddba6-da65-5657-bd31-aba54c6f14a1', 'RFR-SUDDEN-CHEST-PAIN'),
   ('HCH12-0002', 'red_flag_rule', 'afda7c34-8487-57a8-9883-367ddc0ea3ae', 'RFR-REST-DYSPNOEA'),
   ('HCH12-0020', 'red_flag_rule', 'e47a6fea-a132-5eab-9b13-d232d746f162', 'RFR-WEIGHT-LOSS'),
   ('HCH12-0020', 'red_flag_rule', '975df4e5-4514-5633-8317-791cc1b9a4d2', 'RFR-FEVER-RIGORS'),
   ('HCH2-0002',  'red_flag_rule', 'dbb70678-9181-5672-930d-73f7e0c91d84', 'RFR-RESPIRATORY-DISTRESS'),
   ('HCH12-0017', 'red_flag_rule', '012701b3-8a2a-5970-ae6f-a09325b62c45', 'RFR-CHEST-INDRAWING'),
   ('HCH2-0002',  'red_flag_rule', '8757ecfd-8cdc-5067-ba2a-59d394c193ad', 'RFR-CYANOSIS'),
   -- exposure concepts
   ('HCH12-0013', 'exposure_concept', '11188b29-9d07-502d-90fa-4e614ed09b6e', 'CONTACT'),
   ('HCH1-0018',  'exposure_concept', '87893f65-615d-54a0-b06d-06aeb23e7c22', 'TRAVEL'),
   ('HCH12-0013', 'exposure_concept', 'fbe899b3-cca7-5b5c-aaa1-7a76ad730161', 'OCCUPATION'),
   ('HCH12-0013', 'exposure_concept', '48b4a113-45e7-5039-a41f-7174de09fbc3', 'ANIMAL'),
   ('HCH12-0013', 'exposure_concept', 'e4f12500-ee12-54a0-9c1e-4e1b84a5c316', 'INSECT'),
   ('HCH12-0013', 'exposure_concept', 'a542adf2-7dde-5e98-8774-308a31eeb1b4', 'FOOD'),
   ('HCH12-0013', 'exposure_concept', 'afa01d01-3ef5-58bd-abe2-c868e81e662a', 'WATER'),
   ('HCH12-0013', 'exposure_concept', '0f0f4611-b170-5f41-bf6a-621af41f6ad4', 'SEXUAL'),
   ('HCH12-0013', 'exposure_concept', '81d491a8-4f6d-5da0-8bf9-4830d81e13f2', 'HEALTHCARE'),
   ('HCH12-0013', 'exposure_concept', 'c7f3e3fd-1a28-51bf-a5b8-d2c5eb9c84ea', 'ENVIRONMENTAL'),
   ('HCH12-0011', 'exposure_concept', 'cc9b0029-4357-59b3-bc2a-6329bbebd14b', 'SMOKE'),
   ('HCH12-0013', 'exposure_concept', '91c5b725-3dfa-577e-92e0-58fe8c4ddd2b', 'BIOMASS'),
   ('HCH12-0013', 'exposure_concept', '209f12cb-915a-564c-bc0e-e91c567acf4e', 'DUST'),
   ('HCH12-0013', 'exposure_concept', 'f08b9c05-1750-54c9-90a6-f6d92e74168d', 'CHEMICAL'),
   ('HCH12-0011', 'exposure_concept', 'c85f95ce-d819-5ded-86be-962b51270427', 'DRUG'),
   -- symptom-exposure maps
   ('HCH12-0011', 'symptom_exposure', 'cc9b0029-4357-59b3-bc2a-6329bbebd14b', 'SYM-COUGH:SMOKE'),
   ('HCH12-0013', 'symptom_exposure', '11188b29-9d07-502d-90fa-4e614ed09b6e', 'SYM-COUGH:CONTACT'),
   ('HCH12-0013', 'symptom_exposure', '87893f65-615d-54a0-b06d-06aeb23e7c22', 'SYM-FEVER:TRAVEL'),
   ('HCH12-0013', 'symptom_exposure', '48b4a113-45e7-5039-a41f-7174de09fbc3', 'SYM-FEVER:ANIMAL')
) AS x(claim_code, object_type, object_id, object_code)
JOIN knowledge.source_claim s ON s.claim_code = x.claim_code
  ON CONFLICT DO NOTHING;
