-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H2 seed zq1: history concepts
-- =============================================================================
-- Seeds the universal history vocabulary compiled from H1 Hutchison claims:
--   knowledge.history_concept            (HC001..HC057)
--   knowledge.functional_impact          (9 reusable domains)
--   knowledge.symptom_history_dimension  (cough / chest pain / dyspnoea / fever / abdo pain)
--   knowledge.provenance                 (H1 claim -> history_concept derivation edges)
--
-- The 28 universal concepts are exactly the H2 spec's Table 1. Dimension
-- concepts (HC029+) are the reusable symptom-specific characteristics that
-- symptom objects reference (they are NOT symptom objects themselves).
--
-- Provenance ids are deterministic uuid5 over 'HISTORY_CONCEPT:<code>' so the
-- trace requirement (question -> fact -> claim -> chapter -> page) stays intact.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. history_concept — universal vocabulary (28) + reusable dimensions (29)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.history_concept
    (history_concept_id, concept_code, concept_name, concept_type, reusable, description) VALUES
   -- ---- 28 UNIVERSAL CONCEPTS (H2 spec Table 1) ----
   ('HC001', 'PRESENTING_CONCERN',    'Presenting concern',    'encounter',           true,  'The patient''s reason for the encounter; how it started and developed (Box 1.3).'),
   ('HC002', 'ONSET',                 'Onset',                 'temporal',            true,  'When the problem started and how it developed over time (Box 1.6).'),
   ('HC003', 'DURATION',              'Duration',              'temporal',            true,  'How long the symptom has been present.'),
   ('HC004', 'TIME_COURSE',           'Time course',           'temporal',            true,  'How the symptom evolved: sudden vs gradual onset hints at pathology (Box 1.6).'),
   ('HC005', 'SITE',                  'Site',                  'symptom',             true,  'Where the symptom is felt (pain clarification, Box 1.8).'),
   ('HC006', 'RADIATION',             'Radiation',             'symptom',             true,  'Where the symptom spreads to (pain clarification, Box 1.8).'),
   ('HC007', 'CHARACTER',             'Character',             'symptom',             true,  'The quality of the symptom (burning, crushing, stabbing...) that hints at its anatomy (Box 1.8).'),
   ('HC008', 'SEVERITY',              'Severity',              'symptom',             true,  'How much it bothers the patient; quantified (1-10 scale, Box 1.8).'),
   ('HC009', 'AGGRAVATING_FACTORS',   'Aggravating factors',   'symptom',             true,  'What makes it worse (pain clarification, Box 1.8).'),
   ('HC010', 'RELIEVING_FACTORS',     'Relieving factors',     'symptom',             true,  'What makes it better (pain clarification, Box 1.8).'),
   ('HC011', 'ASSOCIATED_SYMPTOMS',   'Associated symptoms',   'symptom',             true,  'Other symptoms that accompany the presenting complaint.'),
   ('HC012', 'FUNCTIONAL_IMPACT',     'Functional impact',     'function',            true,  'Effect on exercise, work, sport, eating, social life (Box 1.5).'),
   ('HC013', 'PAST_MEDICAL_HISTORY',  'Past medical history',  'background',          true,  'All serious problems in the whole of life; taken early - the timeline builds a better picture (Box 1.4).'),
   ('HC014', 'SURGICAL_HISTORY',      'Surgical history',      'background',          true,  'Prior operations.'),
   ('HC015', 'MEDICATION_HISTORY',    'Medication history',    'background',          true,  'All prescribed, OTC, herbal and complementary medicines (Box 1.9).'),
   ('HC016', 'ALLERGY_HISTORY',       'Allergy history',       'background',          true,  'Known allergies and adverse drug reactions.'),
   ('HC017', 'FAMILY_HISTORY',        'Family history',        'background',          true,  'Illnesses that run in the family; basic family tree (Box 1.10).'),
   ('HC018', 'SOCIAL_HISTORY',        'Social history',        'background',          true,  'Smoking, alcohol (units/week), living circumstances, support (Boxes 1.11-1.13).'),
   ('HC019', 'OCCUPATIONAL_HISTORY',  'Occupational history',  'exposure',            true,  'Chronological from leaving school; exposures may act years later (asbestosis, silicosis).'),
   ('HC020', 'EXPOSURE_HISTORY',      'Exposure history',      'exposure',            true,  'Environmental / occupational / infectious exposures; travel.'),
   ('HC021', 'REPRODUCTIVE_HISTORY',  'Reproductive history',  'reproductive',        true,  'Menstrual, obstetric and sexual history; relevant in women and reproductive contexts.'),
   ('HC022', 'SYSTEM_REVIEW',         'Systems review',        'screening',           true,  'Direct questions about bodily systems not covered by the presenting complaint (Box 1.7).'),
   ('HC023', 'PATIENT_IDEA',          'Patient idea',          'patient_perspective', true,  'What the patient thinks is causing the problem (Box 1.16).'),
   ('HC024', 'PATIENT_CONCERN',       'Patient concern',       'patient_perspective', true,  'What the patient is worried about (Box 1.16).'),
   ('HC025', 'PATIENT_EXPECTATION',   'Patient expectation',   'patient_perspective', true,  'What the patient expects from the consultation (Box 1.16).'),
   ('HC026', 'PATIENT_GOAL',          'Patient goal',          'patient_perspective', true,  'What the patient wants to be able to do again.'),
   ('HC027', 'COLLATERAL_HISTORY',    'Collateral history',    'source',              true,  'History from those accompanying the patient (unconscious, child, delirium).'),
   ('HC028', 'RELIABILITY',           'Reliability',           'source',              true,  'Reliability of the history; uncertain information must not be treated as verified.'),

   -- ---- 29 REUSABLE SYMPTOM-SPECIFIC DIMENSIONS (HC029+) ----
   ('HC029', 'PRODUCTIVITY',           'Productivity',           'symptom',   true, 'Productive (sputum-producing) vs non-productive cough (Box 12.5).'),
   ('HC030', 'SPUTUM',                 'Sputum production',      'symptom',   true, 'Whether sputum is produced at all.'),
   ('HC031', 'SPUTUM_COLOUR',          'Sputum colour',          'symptom',   true, 'Yellow/green suggests purulent infection; colour change matters.'),
   ('HC032', 'SPUTUM_CONSISTENCY',     'Sputum consistency',     'symptom',   true, 'Thick/jelly-like in asthma; watery; frothy pink in pulmonary oedema.'),
   ('HC033', 'SPUTUM_AMOUNT',          'Sputum amount',          'symptom',   true, 'Cupfuls per day suggests bronchiectasis; frank blood = haemoptysis.'),
   ('HC034', 'HAEMOPTYSIS',            'Haemoptysis',            'symptom',   true, 'Coughing blood - a red flag that must never be dismissed without careful evaluation (Box 12.6).'),
   ('HC035', 'SYMPTOM_TIMING',         'Symptom timing',         'temporal',  true, 'Time of day/night it occurs (e.g. dry cough at night may be asthma).'),
   ('HC036', 'SYMPTOM_TRIGGERS',       'Symptom triggers',       'symptom',   true, 'Allergic triggers (dust, animals, pollen) and non-specific triggers (exercise, cold air).'),
   ('HC037', 'POSITIONAL_RELATIONSHIP','Positional relationship','symptom',   true, 'Relation to posture/lying flat (orthopnoea, positional cough).'),
   ('HC038', 'FREQUENCY',              'Frequency',              'temporal',  true, 'How often the symptom or episode recurs.'),
   ('HC039', 'STOOL_CONSISTENCY',      'Stool consistency',      'symptom',   true, 'Formed / loose / watery (diarrhoea) characterisation.'),
   ('HC040', 'STOOL_BLOOD',            'Blood in stool',         'symptom',   true, 'Rectal bleeding / melaena / fresh blood on paper.'),
   ('HC041', 'STOOL_MUCUS',            'Mucus in stool',         'symptom',   true, 'Mucus with stool - inflammatory bowel characterisation.'),
   ('HC042', 'NOCTURNAL_SYMPTOMS',     'Nocturnal symptoms',     'temporal',  true, 'Symptoms that wake the patient at night (asthma worse at night/early morning).'),
   ('HC043', 'URGENCY',                'Urgency',                'symptom',   true, 'Urgency of stool / micturition.'),
   ('HC044', 'TENESMUS',               'Tenesmus',               'symptom',   true, 'Incomplete evacuation sensation.'),
   ('HC045', 'ASSOCIATED_DYSPNOEA',    'Associated dyspnoea',    'symptom',   true, 'Breathlessness accompanying the symptom (ask, do not assume).'),
   ('HC046', 'ASSOCIATED_WHEEZE',      'Associated wheeze',      'symptom',   true, 'Audible wheeze accompanying the symptom (Box 12.8).'),
   ('HC047', 'ASSOCIATED_FEVER',       'Associated fever',       'symptom',   true, 'Fever / night sweats accompanying the symptom (Box 12.5 question set).'),
   ('HC048', 'DYSPNOEA_TRIGGER',       'Dyspnoea trigger',       'symptom',   true, 'Exertional vs at rest; variability; times of day (Box 12.2).'),
   ('HC049', 'EXERCISE_TOLERANCE',     'Exercise tolerance',     'function',  true, 'How far the patient can walk at a normal pace; climb stairs (Box 12.3).'),
   ('HC050', 'VOMITING',               'Vomiting',               'symptom',   true, 'Whether the symptom is associated with vomiting.'),
   ('HC051', 'APPETITE_CHANGE',        'Appetite change',        'symptom',   true, 'Appetite loss / change accompanying the symptom.'),
   ('HC052', 'WEIGHT_CHANGE',          'Weight change',          'symptom',   true, 'Weight loss / gain accompanying the symptom.'),
   ('HC053', 'TRAVEL_HISTORY',         'Travel history',         'exposure',  true, 'Recent travel relevant to infection risk.'),
   ('HC054', 'FOOD_EXPOSURE',          'Food exposure',          'exposure',  true, 'Foods that may explain acute GI symptoms.'),
   ('HC055', 'WHEEZE',                 'Wheeze',                 'symptom',   true, 'Audible wheeze - question and auscultate (Box 12.8).'),
   ('HC056', 'ALCOHOL_USE',            'Alcohol use',            'background', true, 'Units per week; CAGE screen when indicated (Box 1.12).'),
   ('HC057', 'SMOKING_STATUS',         'Smoking status',         'background', true, 'Current / ex / never; pack-years (Box 1.11).')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. functional_impact — the 9 reusable domains (H2 spec §9/functional)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.functional_impact (function_code, domain, label, description) VALUES
   ('WALKING_LIMITATION',     'mobility',          'Walking limitation',      'Cannot walk as far as before at own pace.'),
   ('EXERCISE_TOLERANCE',     'physical_activity', 'Exercise tolerance',      'How far/fast the patient can walk; stairs; housework.'),
   ('WORK_IMPACT',            'occupation',        'Work impact',             'Unable to work / reduced capacity at work.'),
   ('SCHOOL_IMPACT',          'education',         'School impact',           'School attendance/performance affected.'),
   ('FEEDING_IMPACT',         'nutrition',         'Feeding impact',          'Eating affected; particular foods avoided.'),
   ('SLEEP_IMPACT',           'sleep',             'Sleep impact',            'Sleep disturbed by the symptom.'),
   ('SOCIAL_IMPACT',          'social',            'Social impact',           'Social life restricted by the symptom.'),
   ('SELF_CARE_IMPACT',       'adl',               'Self-care impact',        'Dressing, washing, feeding affected.'),
   ('SEXUAL_FUNCTION_IMPACT', 'sexual_health',     'Sexual function impact',  'Sexual function affected (ask sensitively).')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. symptom_history_dimension — meaningful characteristics per symptom
-- ---------------------------------------------------------------------------
-- priority 100 = mandatory first pass; lower = follow-up / clarification.
INSERT INTO knowledge.symptom_history_dimension (symptom_id, history_concept_id, priority, mandatory) VALUES
   -- COUGH (f0b00000-...-0001) — Boxes 12.3-12.6
   ('f0b00000-0000-0000-0000-000000000001','HC002',100,true),
   ('f0b00000-0000-0000-0000-000000000001','HC003',100,true),
   ('f0b00000-0000-0000-0000-000000000001','HC029',100,true),
   ('f0b00000-0000-0000-0000-000000000001','HC034',100,true),
   ('f0b00000-0000-0000-0000-000000000001','HC004',90,false),
   ('f0b00000-0000-0000-0000-000000000001','HC030',90,false),
   ('f0b00000-0000-0000-0000-000000000001','HC045',90,false),
   ('f0b00000-0000-0000-0000-000000000001','HC035',85,false),
   ('f0b00000-0000-0000-0000-000000000001','HC046',85,false),
   ('f0b00000-0000-0000-0000-000000000001','HC047',85,false),
   ('f0b00000-0000-0000-0000-000000000001','HC031',80,false),
   ('f0b00000-0000-0000-0000-000000000001','HC036',80,false),
   ('f0b00000-0000-0000-0000-000000000001','HC008',80,false),
   ('f0b00000-0000-0000-0000-000000000001','HC007',80,false),
   ('f0b00000-0000-0000-0000-000000000001','HC032',70,false),
   ('f0b00000-0000-0000-0000-000000000001','HC033',70,false),
   ('f0b00000-0000-0000-0000-000000000001','HC037',60,false),
   ('f0b00000-0000-0000-0000-000000000001','HC012',60,false),

   -- CHEST PAIN (f0b00000-...-0007) — Box 1.8 exactly as the H2 spec's Table 2
   ('f0b00000-0000-0000-0000-000000000007','HC005',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC006',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC007',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC008',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC004',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC009',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC010',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC011',100,true),
   ('f0b00000-0000-0000-0000-000000000007','HC002',100,false),
   ('f0b00000-0000-0000-0000-000000000007','HC003',90,false),

   -- DYSPNOEA (f0b00000-...-0003) — Boxes 12.1-12.3
   ('f0b00000-0000-0000-0000-000000000003','HC002',100,true),
   ('f0b00000-0000-0000-0000-000000000003','HC048',100,true),
   ('f0b00000-0000-0000-0000-000000000003','HC049',100,true),
   ('f0b00000-0000-0000-0000-000000000003','HC003',100,true),
   ('f0b00000-0000-0000-0000-000000000003','HC004',90,false),
   ('f0b00000-0000-0000-0000-000000000003','HC046',90,false),
   ('f0b00000-0000-0000-0000-000000000003','HC042',85,false),
   ('f0b00000-0000-0000-0000-000000000003','HC008',90,false),
   ('f0b00000-0000-0000-0000-000000000003','HC047',80,false),
   ('f0b00000-0000-0000-0000-000000000003','HC037',75,false),
   ('f0b00000-0000-0000-0000-000000000003','HC012',70,false),

   -- FEVER (f0b00000-...-0002)
   ('f0b00000-0000-0000-0000-000000000002','HC002',100,true),
   ('f0b00000-0000-0000-0000-000000000002','HC003',100,true),
   ('f0b00000-0000-0000-0000-000000000002','HC004',90,false),
   ('f0b00000-0000-0000-0000-000000000002','HC011',90,false),
   ('f0b00000-0000-0000-0000-000000000002','HC008',75,false),
   ('f0b00000-0000-0000-0000-000000000002','HC035',70,false),
   ('f0b00000-0000-0000-0000-000000000002','HC012',60,false),

   -- ABDOMINAL PAIN (f0b00000-...-0008)
   ('f0b00000-0000-0000-0000-000000000008','HC002',100,true),
   ('f0b00000-0000-0000-0000-000000000008','HC003',100,true),
   ('f0b00000-0000-0000-0000-000000000008','HC005',100,true),
   ('f0b00000-0000-0000-0000-000000000008','HC007',100,true),
   ('f0b00000-0000-0000-0000-000000000008','HC008',100,true),
   ('f0b00000-0000-0000-0000-000000000008','HC004',90,false),
   ('f0b00000-0000-0000-0000-000000000008','HC006',90,false),
   ('f0b00000-0000-0000-0000-000000000008','HC011',90,false),
   ('f0b00000-0000-0000-0000-000000000008','HC009',85,false),
   ('f0b00000-0000-0000-0000-000000000008','HC010',85,false),
   ('f0b00000-0000-0000-0000-000000000008','HC038',70,false),
   ('f0b00000-0000-0000-0000-000000000008','HC042',60,false),
   ('f0b00000-0000-0000-0000-000000000008','HC012',60,false)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. provenance — every history_concept derived from its H1 Hutchison claim
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'history_concept', x.object_id::uuid, x.object_code, 'derived_from', x.weight
FROM (VALUES
   -- encounters / presentation
   ('HCH1-0004','PRESENTING_CONCERN',    '212c5760-5cbd-5ed9-bd48-ef6a51538662', 1.0),
   ('HCH1-0023','PRESENTING_CONCERN',    '212c5760-5cbd-5ed9-bd48-ef6a51538662', 1.0),
   ('HCH1-0023','PATIENT_IDEA',          '673925b2-a378-504c-b881-d9f8f951859f', 1.0),
   ('HCH1-0023','PATIENT_CONCERN',       'b0bf5a2a-b0c2-54fa-8129-8547f40e97ae', 1.0),
   ('HCH1-0023','PATIENT_EXPECTATION',   'd89485c0-6690-5e82-a7df-d2b08da8cf4c', 1.0),
   ('HCH1-0023','PATIENT_GOAL',          '09944bf2-e76f-50ad-8e66-9505d295ce12', 1.0),
   -- chronology / temporal
   ('HCH1-0013','ONSET',                 'b43da675-c1d8-52c5-92bc-dcc143b9404c', 1.0),
   ('HCH1-0013','DURATION',              'a388f2ba-da9e-5e18-a692-eac88c4e0163', 1.0),
   ('HCH1-0013','TIME_COURSE',           'd268c522-9716-56c5-a76f-b383bbef2a5c', 1.0),
   ('HCH1-0021','TIME_COURSE',           'd268c522-9716-56c5-a76f-b383bbef2a5c', 1.0),
   -- symptom characterisation (pain / any symptom) — Box 1.8
   ('HCH1-0015','SITE',                  '7ec2bd92-e836-5fd3-97e1-b26b43dff26a', 1.0),
   ('HCH1-0015','RADIATION',             '180047ac-353e-5ca6-8bb4-bebc2c600317', 1.0),
   ('HCH1-0015','CHARACTER',             '84d76077-8384-561d-8428-0bc8fea15908', 1.0),
   ('HCH1-0015','SEVERITY',              '42dff469-646c-5328-aba4-09f3668bd623', 1.0),
   ('HCH1-0012','SEVERITY',              '42dff469-646c-5328-aba4-09f3668bd623', 1.0),
   ('HCH1-0015','AGGRAVATING_FACTORS',   'c0dd826e-00b3-5cb8-a5e2-04898a64929b', 1.0),
   ('HCH1-0015','RELIEVING_FACTORS',     '182bd068-090a-5a75-9333-8d1ec0becb56', 1.0),
   ('HCH1-0015','ASSOCIATED_SYMPTOMS',   '2821aff0-98cb-5697-a574-ff5dc926ef2a', 1.0),
   ('HCH1-0011','FUNCTIONAL_IMPACT',     '22278d66-5360-5f50-bbfd-62b363d4e296', 1.0),
   -- past / background
   ('HCH1-0013','PAST_MEDICAL_HISTORY',  '3c538823-0130-5c00-a6ba-b3bafa659aab', 1.0),
   ('HCH1-0013','MEDICATION_HISTORY',    '563724c5-7769-5f75-b86a-17259bc837be', 1.0),
   ('HCH1-0016','MEDICATION_HISTORY',    '563724c5-7769-5f75-b86a-17259bc837be', 1.0),
   ('HCH1-0013','FAMILY_HISTORY',        'e91c6c82-12b1-5acf-be5c-260298f4837b', 1.0),
   ('HCH1-0017','FAMILY_HISTORY',        'e91c6c82-12b1-5acf-be5c-260298f4837b', 1.0),
   ('HCH1-0018','OCCUPATIONAL_HISTORY',  'e6212035-f976-5a45-964f-d378acf071ee', 1.0),
   ('HCH1-0018','EXPOSURE_HISTORY',      '5c59deae-e5fc-5a0b-bbbc-b94d4c639a97', 1.0),
   ('HCH1-0013','REPRODUCTIVE_HISTORY',  '30c4fe1b-45de-5d48-a767-0812ae1c7eed', 1.0),
   ('HCH1-0014','SYSTEM_REVIEW',         'b7cfd7b5-5d9b-5faa-9c3e-5e3d60acd29e', 1.0),
   ('HCH1-0006','SOCIAL_HISTORY',        '28926f55-7e02-51f4-bbef-a6df767cab25', 1.0),
   ('HCH1-0019','ALCOHOL_USE',           '58fe870d-c500-5cad-8317-3cf1251c6336', 1.0),
   ('HCH1-0006','SMOKING_STATUS',        'a0426ed6-b83c-566d-bbc9-4b4525d5974d', 1.0),
   -- respiratory (ch12)
   ('HCH12-0005','PRODUCTIVITY',         'f6301838-8187-5dcb-a8a6-6e540f9daa5b', 1.0),
   ('HCH12-0005','SYMPTOM_TIMING',       '13dc1f47-801f-5a8d-8372-0e45c6706e9a', 1.0),
   ('HCH12-0005','SYMPTOM_TRIGGERS',     '7834f9b8-4e64-522d-ad0d-70b6713c4055', 1.0),
   ('HCH12-0006','SPUTUM',               'b98dbeb0-c7c3-59b1-9cbc-8baeb4fee1c6', 1.0),
   ('HCH12-0006','SPUTUM_COLOUR',        '66ff48d1-8876-554f-9618-e240adc8f380', 1.0),
   ('HCH12-0006','SPUTUM_CONSISTENCY',   'e6e1035a-5c89-532a-b4b5-4ff0e2ce2fb5', 1.0),
   ('HCH12-0006','SPUTUM_AMOUNT',        'b867e7d6-8c46-5257-a93b-0b5aefb82931', 1.0),
   ('HCH12-0007','HAEMOPTYSIS',          '5962cecf-3f53-5fa3-b284-81ceeed3aeac', 1.0),
   ('HCH12-0020','HAEMOPTYSIS',          '5962cecf-3f53-5fa3-b284-81ceeed3aeac', 1.0),
   ('HCH12-0020','SYMPTOM_TRIGGERS',     '7834f9b8-4e64-522d-ad0d-70b6713c4055', 1.0),
   ('HCH12-0020','ASSOCIATED_FEVER',     '0bec3ff8-f304-5b16-b736-34c3b2b01c16', 1.0),
   ('HCH12-0003','DYSPNOEA_TRIGGER',     '05ee1fee-deae-54f8-a725-5a94b8406883', 1.0),
   ('HCH12-0003','EXERCISE_TOLERANCE',   '77334a8b-5bc9-5fc0-9df1-e25f3258fcf7', 1.0),
   ('HCH12-0008','WHEEZE',               'f06accca-468c-55a3-8de1-63b10eb14e10', 1.0),
   ('HCH12-0008','ASSOCIATED_WHEEZE',    'fb3b57f1-fdc9-5bbf-ba23-b477385700e6', 1.0)
) AS x(claim_code, object_code, object_id, weight)
JOIN knowledge.source_claim sc ON sc.claim_code = x.claim_code
  ON CONFLICT DO NOTHING;
