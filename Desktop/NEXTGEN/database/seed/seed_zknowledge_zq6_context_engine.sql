-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H5 seed zq6: universal context engine
-- =============================================================================
-- Seeds the H5 adaptation layer on top of the H2/H3/H4 substrate:
--   knowledge.clinical_context          (C001..C016 — the context registry, H5 §31)
--   knowledge.developmental_stage       (9 universal age bands, H5 §5)
--   knowledge.historian_type            (7 — who gives the history, H5 §8)
--   knowledge.historian_reliability     (5 — how much to trust them, H5 §8)
--   knowledge.communication_context     (language/interpretation/hearing/vision/... H5 §13)
--   knowledge.encounter_mode            (5 — in-person/VIDEO/AUDIO/CHAT/remote, H5 §29)
--   knowledge.response_mode             (capture strategy, H5 §7 Layer B)
--   knowledge.response_variant          (age-appropriate answer surfaces, H5 §40)
--   knowledge.functional_domain         (17 — developmental + adult functions, H5 §24)
--   knowledge.context_adaptation_rule   (24 — the H5 rule engine, H5 §32)
--   knowledge.context_fact_mapping      (10 — raw→canonical fact normalization, H5 §23)
--   knowledge.fact_capture_method       (7 — fact provenance classes, H5 §10)
--   knowledge.fact_provenance           (fact → lawful capture methods, H5 §10)
--   question_variant                    (extended: new wording variants + response_mode/historian)
--   question                            (tagged with functional_domain where relevant)
--   knowledge.provenance                (H5:<object_type>:<code> → claim edges)
--
-- Architecture law (H5 §46): the SAME canonical fact is elicited differently.
--   H1=WHAT SOURCE TEACHES → H2=WHAT FACT IS → H3=WHY ASK → H4=WHAT TO EXPLORE
--                            → H5=HOW TO ELICIT FOR THIS PATIENT → CANONICAL FACT.
--
-- Deterministic uuid5 provenance ids: namespace 6ba7b810-9dad-11d1-80b4-00c04fd430c8,
-- scheme "H5:<object_type>:<code>" (computed offline with uuid5 and pasted as
-- literals — matching the H3/H4 seed convention, since the instance has no uuid-ossp).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. clinical_context — the canonical context registry (H5 §31)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.clinical_context (context_id, code, category, label, description, applies_to_questions, applies_to_exam, priority_weight) VALUES
    ('C001', 'NEONATE',             'AGE',           'Neonate',             'Birth to 28 days. Communication: only caregiver observations; self-report impossible.',                    true,  true,  1.0),
    ('C002', 'INFANT',              'AGE',           'Infant',              '29 days to <3 months. Caregiver history; feeding/apnoea/cyanosis matter.',                                  true,  true,  1.0),
    ('C003', 'CHILD',               'AGE',           'Child',               '1 to <12 years. Mixed self/caregiver; school/play functional domains matter.',                                true,  true,  1.0),
    ('C004', 'ADOLESCENT',          'AGE',           'Adolescent',          '12 to <18 years. Near-adult questioning with reproductive/safety adaptations.',                             true,  true,  1.0),
    ('C005', 'ADULT',               'AGE',           'Adult',               '18 to <65 years. Full self-report; occupation/exercise relevant.',                                         true,  true,  1.0),
    ('C006', 'OLDER_ADULT',         'AGE',           'Older adult',         '65+. Comorbidity, cognition, medications, ADLs/IADLs, falls — geriatric layers.',                           true,  true,  1.0),
    ('C007', 'PREGNANCY',           'REPRODUCTIVE',  'Pregnancy',           'Pregnancy modifies relevance; NOT a new disease universe (H5 §16).',                                       true,  true,  1.0),
    ('C008', 'POSTPARTUM',          'REPRODUCTIVE',  'Postpartum',          'Distinct from non-pregnant state (H5 §17): up to 6 weeks postpartum.',                                        true,  true,  1.0),
    ('C009', 'LACTATION',           'REPRODUCTIVE',  'Lactation',           'Breastfeeding state; nutrition/medication transfer relevant.',                                               true,  true,  1.0),
    ('C010', 'EMERGENCY',           'SETTING',       'Emergency',           'Immediate danger questions first; full characterization deferred (H5 §18).',                                 true,  true,  1.0),
    ('C011', 'OUTPATIENT',          'SETTING',       'Outpatient',          'Routine review; full characterization available.',                                                              true,  true,  1.0),
    ('C012', 'INPATIENT',           'SETTING',       'Inpatient',           'In-hospital review; chart review possible alongside interview.',                                          true,  true,  1.0),
    ('C013', 'TELEMEDICINE',        'MODE',          'Telemedicine',        'Remote: auscultation unavailable; some data from device/caregiver (H5 §29).',                                  true,  true,  1.0),
    ('C014', 'CAREGIVER_HISTORY',   'HISTORIAN',     'Caregiver history',   'Patient cannot self-report fully; caregiver proxy is the capture path.',                                    true,  true,  1.0),
    ('C015', 'COGNITIVE_IMPAIRMENT','COMMUNICATION', 'Cognitive impairment','Confused/delirious/cognitively impaired; history quality and capture method constrained (H5 §11).',            true,  true,  1.0),
    ('C016', 'UNCONSCIOUS',         'COMMUNICATION', 'Unconscious',         'Cannot provide history; collateral from companion + record only (H5 §12/32).',                                   true,  true,  1.0),
    ('C017', 'PRESCHOOL',           'AGE',           'Preschool',           '3 to <5 years (developmental_stage PRESCHOOL). Play-based reporting; cannot self-report exertion reliably.',        true,  true,  1.0),
    ('C018', 'SCHOOL_AGE',          'AGE',           'School age',          '5 to <12 years (developmental_stage SCHOOL_AGE). Can report with scaffolding; exercise/play relevant.',                true,  true,  1.0)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. developmental_stage — the 9 universal age bands (H5 §5)
-- ---------------------------------------------------------------------------
-- min_age_days / max_age_days are the default boundaries. A protocol-specific
-- context_rule may bind a narrower band (spec §5: boundaries are not immutable).
INSERT INTO knowledge.developmental_stage (stage_code, label, min_age_days, max_age_days, sort_order, description) VALUES
    ('NEONATE',       'Neonate',        0,    28,     1, 'Birth to 28 days.'),
    ('YOUNG_INFANT',  'Young infant',   29,   89,     2, '29 days to <3 months.'),
    ('OLDER_INFANT',  'Older infant',   90,   364,    3, '3 to <12 months.'),
    ('TODDLER',       'Toddler',        365,  1094,   4, '1 to <3 years.'),
    ('PRESCHOOL',     'Preschool',      1095, 1825,   5, '3 to <5 years.'),
    ('SCHOOL_AGE',    'School age',     1826, 4380,   6, '5 to <12 years.'),
    ('ADOLESCENT',    'Adolescent',     4381, 6570,   7, '12 to <18 years.'),
    ('ADULT',         'Adult',          6571, 23396,  8, '18 to <65 years.'),
    ('OLDER_ADULT',   'Older adult',    23397,NULL,   9, '>=65 years.')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. historian_type — who provides the history (H5 §8)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.historian_type (type_code, label, is_patient, description, sort_order) VALUES
    ('PATIENT',      'Patient',       true,  'The patient themselves (age-appropriate self-report).',               1),
    ('PARENT',       'Parent',        false, 'Parent/guardian of a dependent patient.',                               2),
    ('CAREGIVER',    'Caregiver',     false, 'Non-parent caregiver (nurse, nurse aide, family friend).',            3),
    ('SPOUSE',       'Spouse',        false, 'Spouse/partner.',                                                     4),
    ('RELATIVE',     'Relative',      false, 'Other blood/affinity relative.',                                      5),
    ('HEALTH_WORKER','Health worker', false, 'Nurse, doctor, pharmacist or allied professional with record access.',6),
    ('OTHER',        'Other',         false, 'Another person or source (e.g. court-appointed guardian).',           7)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. historian_reliability — how much to trust the source (H5 §8)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.historian_reliability (reliability_code, label, sort_order, description) VALUES
    ('GOOD',      'Good',      1, 'Patient/caregiver alert and articulate; history reliable.'),
    ('FAIR',      'Fair',      2, 'Some limitation (fatigue, mild confusion, language barrier with interpreter).'),
    ('POOR',      'Poor',      3, 'Significant limitation (severe distress, cognitive impairment, critical illness).'),
    ('UNRELIABLE','Unreliable',4, 'Unclear motive/context; information not to be trusted as fact.'),
    ('UNKNOWN',   'Unknown',   5, 'Source reliability not yet assessed.')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. communication_context — interface-level communication constraints (H5 §13)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.communication_context (factor_code, context_type_code, label, description, sort_order) VALUES
    ('LANGUAGE_BARRIER',    'CARE_SETTING', 'Language barrier',    'Preferred language differs from the clinician; an interpreter route must be chosen.', 1),
    ('INTERPRETER_REQUIRED', 'CARE_SETTING', 'Interpreter required', 'Professional interpreter needed for an accurate history (H5 §13).',        2),
    ('HEARING_IMPAIRED',    'CARE_SETTING', 'Hearing impaired',    'Hears poorly; visual/written/tactile communication needed.',                  3),
    ('VISUAL_IMPAIRED',     'CARE_SETTING', 'Visual impaired',     'Vision poor; auditory/tactile communication needed.',                         4),
    ('SPEECH_IMPAIRED',     'CARE_SETTING', 'Speech impaired',     'Cannot speak clearly; written/alternative input needed.',                     5),
    ('LOW_LITERACY',        'CARE_SETTING', 'Low literacy',        'Simple language, visual aids, demonstrated scales needed.',                   6)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. encounter_mode — how care is delivered (H5 §29)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.encounter_mode (mode_code, label, supports_auscultation, supports_inspection, supports_device_readings, description, sort_order) VALUES
    ('IN_PERSON',          'In-person',          true,  true,  true,  'Full examination modalities available.',                                  1),
    ('VIDEO',              'Video',              false, true,  false, 'Visual inspection only; auscultation and device readings unavailable.',   2),
    ('AUDIO',              'Audio only',         false, false, false, 'Audio questions only; no visual inspection.',                            3),
    ('CHAT',               'Chat/text',          false, false, false, 'Text-based questions; useful with hearing impairment + interpreter.',     4),
    ('REMOTE_MONITORING',  'Remote monitoring',  false, false, true,  'Vital signs/device readings streamed; limited interaction.',              5)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. response_mode — the CAPTURE STRATEGY layer (H5 §7 Layer B)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.response_mode (mode_code, label, is_patient_facing, description, sort_order) VALUES
    ('SELF_REPORT',       'Self report',       true,  'The patient reports their own experience (alert adult).',    1),
    ('CAREGIVER_REPORT',  'Caregiver report',  false, 'A caregiver reports on the patient (child/infant/unconscious).', 2),
    ('OBSERVATION',       'Clinical observation','false', 'A clinician observes a sign/behaviour (unconscious, infant).', 3),
    ('NUMERIC_SCALE',     'Numeric scale',     true,  'A 0-10 (or other) numeric rating (H5 §40).',                  4),
    ('STRUCTURED_CHOICE', 'Structured choice', true,  'Closed-list answer from controlled vocabulary.',             5)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. response_variant — age-appropriate answer surfaces (H5 §40/§45)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.response_variant (variant_id, response_type, variant_name, applicable_context_codes, is_active, description) VALUES
    ('RV001', 'numeric',  'NUMERIC_SCALE',        ARRAY['ADULT','OLDER_ADULT','ADOLESCENT'],            true,  '0-10 numeric severity slider for ages that can self-report numbers.'),
    ('RV002', 'scale',    'FACES_SCALE',          ARRAY['CHILD','TODDLER','PRESCHOOL','SCHOOL_AGE'],      true,  'Age-appropriate faces (emoji) scale for children who cannot number-rate.'),
    ('RV003', 'checklist','OBSERVABLE_CHECKLIST', ARRAY['INFANT','NEONATE','UNCONSCIOUS','CAREGIVER_HISTORY'], true, 'Caregiver/clinician observable checklist (no self-report possible).')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9. functional_domain — developmental + adult functional domains (H5 §24)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.functional_domain (domain_code, code, label, category, age_relevance, description, sort_order) VALUES
    ('FD001', 'FEEDING',           'Feeding',           'developmental', 'NEONATE..OLDER_INFANT', 'Ability to feed; breastfeeding, choking, intake. (H5 §24)',  1),
    ('FD021', 'BREASTFEEDING',     'Breastfeeding',     'developmental', 'NEONATE..OLDER_INFANT', 'Maternal feeding relationship.',                             2),
    ('FD022', 'SPEECH',            'Speech',            'developmental', 'TODDLER..PRESCHOOL',    'Talking, words, intelligibility.',                             3),
    ('FD023', 'MOBILITY',          'Mobility',          'developmental', 'TODDLER..',             'Walking, running, gross movement.',                           4),
    ('FD024', 'PLAY',              'Play',              'developmental', 'TODDLER..SCHOOL_AGE',   'Activity level, play participation.',                         5),
    ('FD025', 'SCHOOL',            'School',            'developmental', 'SCHOOL_AGE..ADOLESCENT','School attendance, concentration, performance.',             6),
    ('FD026', 'INTERACTION',       'Interaction',       'developmental', 'TODDLER..SCHOOL_AGE',   'Social engagement with peers/caregivers.',                     7),
    ('FD027', 'TOILETTING',        'Toileting',         'developmental', 'TODDLER..PRESCHOOL',    'Bladder/bowel control.',                                    8),
    ('FD028', 'SELF_CARE',         'Self-care',         'developmental', 'TODDLER..',             'Dressing, eating, personal care (ADL basics).',              9),
    ('FD029', 'OCCUPATION',        'Occupation',        'adult',         'ADULT',                 'Work, job function, productivity.',                          10),
    ('FD030', 'EDUCATION',         'Education',         'adult',         'ADULT..OLDER_ADULT',    'Study, learning, cognitive work capacity.',                   11),
    ('FD031', 'SLEEP',             'Sleep',             'adult',         'ADULT..OLDER_ADULT',    'Sleep quality/quantity disturbance.',                         12),
    ('FD032', 'SOCIAL',            'Social',            'adult',         'ADULT..OLDER_ADULT',    'Social life, relationships, isolation.',                      13),
    ('FD033', 'EXERCISE',          'Exercise / activity','adult',        'ADULT..OLDER_ADULT',    'Physical activity tolerance (H5 §22-23 translation layer).',  14),
    ('FD034', 'WORK_PRODUCTIVITY', 'Work productivity', 'adult',         'ADULT',                 'Presenteeism/absenteeism from illness.',                      15),
    ('FD035', 'ADL',               'ADL',               'geriatric',       'OLDER_ADULT',           'Activities of daily living (geriatric baseline, H5 §26).',      16),
    ('FD036', 'IADL',              'IADL',              'geriatric',       'OLDER_ADULT',           'Instrumental ADLs (shopping, meds, finance — geriatric).',     17)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 10. fact_capture_method — provenance classes (H5 §10)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.fact_capture_method (method_code, label, is_patient_source, description, sort_order) VALUES
    ('PATIENT_REPORTED',    'Patient reported',    true,  'The patient reports the fact directly (alert, capacity).',   1),
    ('CAREGIVER_REPORTED',  'Caregiver reported',  false, 'A caregiver reports on the patient (child/infant/unconscious).', 2),
    ('CLINICIAN_OBSERVED',  'Clinician observed',  false, 'A clinician directly observes a sign/symptom.',               3),
    ('DEVICE_MEASURED',     'Device measured',     false, 'Captured by a physical device (thermometer, BP cuff, Oxi).', 4),
    ('LAB_MEASURED',        'Lab measured',        false, 'Laboratory assay value (blood, urine).',                       5),
    ('IMAGING_DERIVED',     'Imaging derived',     false, 'Derived from an imaging study.',                               6),
    ('SYSTEM_DERIVED',     'System derived',       false, 'Computed/derived by another system (e.g. severity score).',  7)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 11. fact_provenance — which capture methods are lawful per fact (H5 §10)
-- ---------------------------------------------------------------------------
-- A fact may be captured several ways; some ways are never lawful (e.g. a
-- device cannot measure pack-years). min_reliability_code gates the source.
INSERT INTO knowledge.fact_provenance (fact_definition_code, capture_method_code, historian_type_code, min_reliability_code, is_valid) VALUES
    ('FEEDING_DIFFICULTY', 'CAREGIVER_REPORTED','CAREGIVER',   'FAIR',  true),
    ('FEEDING_DIFFICULTY', 'CLINICIAN_OBSERVED','HEALTH_WORKER','GOOD',  true),
    ('SMOKING_PACK_YEARS', 'PATIENT_REPORTED', 'PATIENT',      'GOOD', true),
    ('SMOKING_PACK_YEARS', 'CAREGIVER_REPORTED','PARENT',       'FAIR',  true),
    ('SMOKING_PACK_YEARS', 'SYSTEM_DERIVED',    'HEALTH_WORKER','GOOD',  true),
    ('EXERCISE_INTOLERANCE','CAREGIVER_REPORTED','CAREGIVER','FAIR', true),
    ('EXERCISE_INTOLERANCE','CLINICIAN_OBSERVED','HEALTH_WORKER','GOOD', true),
    ('COUGH_DURATION_DAYS','PATIENT_REPORTED', 'PATIENT',       'FAIR', true),
    ('COUGH_DURATION_DAYS','CAREGIVER_REPORTED','PARENT',        'FAIR', true),
    ('EXERCISE_INTOLERANCE','PATIENT_REPORTED', 'PATIENT',      'GOOD', true),
    ('SYMPTOM_SEVERITY_SCORE','PATIENT_REPORTED','PATIENT',     'GOOD', true),
    ('SYMPTOM_SEVERITY_SCORE','CAREGIVER_REPORTED','CAREGIVER', 'FAIR', true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 12. context_adaptation_rule — the H5 rule engine (spec §32)
-- ---------------------------------------------------------------------------
-- "Given CONTEXT, do MODIFICATION to TARGET." Mirrors H3 question_rule but for
-- context (not fact triggers): the CPU applies these AFTER H3 priority and
-- BEFORE picking the wording variant. DISABLE/UNAVAILABLE suppress; ACTIVATE
-- boosts (subtraction in the lower-score-first queue, like question_rule).
--   context_code → a clinical_context.code
--   target_type  → question | fact_definition | functional_domain | examination_modality
INSERT INTO knowledge.context_adaptation_rule
    (rule_code, context_code, target_type, target_code, modification, priority_delta, required_historian, rationale, evidence_claim_code) VALUES
    ('CR001', 'INFANT',            'functional_domain', 'FEEDING',          'ACTIVATE', 30, 'CAREGIVER', 'Infants manifest respiratory compromise via feeding; caregiver reports.',         'HCH1-0006'),
    ('CR002', 'INFANT',            'question',        'DYSPNOEA_SEVERITY',   'DISABLE',  0, NULL,        'Infants cannot self-report exertion; use work-of-breathing capture instead.', 'HCH1-0006'),
    ('CR003', 'CHILD',             'functional_domain', 'PLAY',              'ACTIVATE', 20, NULL,        'Children express dyspnoea as reduced play/activity.',                          'HCH1-0006'),
    ('CR004', 'CHILD',             'fact_definition', 'FEEDING_DIFFICULTY',  'UNAVAILABLE',0, NULL,      'Solid-eating children: feeding difficulty is not the right frame.',              'HCH1-0006'),
    ('CR005', 'ADULT',             'functional_domain', 'EXERCISE',           'ACTIVATE',  0, NULL,       'Adult dyspnoea gate: exertion threshold is the reliable gauge (Box 12.3).',     'HCH12-0003'),
    ('CR006', 'OLDER_ADULT',       'functional_domain', 'EXERCISE',           'ACTIVATE',  0, NULL,       'Geriatric functional baseline is the relevant comparison.',                      'HCH1-0006'),
    ('CR007', 'UNCONSCIOUS',       'question',        'OPEN_PRESENTING_CONCERN','DISABLE',0,NULL,'Cannot self-report; history must come from companion (§37 conflict resolution).', 'HCH2-0002'),
    ('CR008', 'UNCONSCIOUS',       'question',        'SYMPTOM_ONSET',       'DISABLE',  0, NULL,        'Patient cannot report onset.',                                                 'HCH2-0002'),
    ('CR009', 'UNCONSCIOUS',       'question',        'SYMPTOM_DURATION',    'DISABLE',  0, NULL,        'Patient cannot report duration.',                                               'HCH2-0002'),
    ('CR010','CAREGIVER_HISTORY',   'fact_definition', 'SMOKING_PACK_YEARS',  'UNAVAILABLE',0,'CAREGIVER','A caregiver cannot reliably report pack-years; defer to patient record.',    'HCH1-0006'),
    ('CR011','TELEMEDICINE',       'examination_modality','AUSCULTATION','UNAVAILABLE',0,NULL,'Auscultation is not available over telemedicine (H5 §29: NOT_NORMAL vs NORMAL distinction).','HCH1-0006'),
    ('CR012','ADOLESCENT',         'functional_domain', 'EXERCISE',           'ACTIVATE',  0, NULL,        'Adolescent dyspnoea is exertion-based like adult.',                            'HCH12-0003'),
    ('CR013','PREGNANCY',           'question',        'ACE_INHIBITOR',       'ACTIVATE', 15, NULL,        'Pregnancy: ACE inhibitors are teratogenic; confirm/contracept before safety.', 'HCH12-0012'),
    ('CR014','OLDER_ADULT',         'fact_definition', 'SMOKING_PACK_YEARS',  'ACTIVATE', 10, NULL,        'Smoking is a major geriatric risk modifier.',                                  'HCH12-0011'),
    ('CR015','PRESCHOOL',           'question',        'EXERCISE_INTOLERANCE','UNAVAILABLE',0,NULL,'Preschoolers cannot self-report exertion quantification.',              'HCH1-0006'),
    ('CR016','NEONATE',             'functional_domain', 'FEEDING',          'ACTIVATE', 40, 'CAREGIVER','In neonates feeding difficulty IS the dyspnoea sign.',                       'HCH2-0002'),
    ('CR017','SCHOOL_AGE',          'functional_domain', 'EXERCISE',           'ACTIVATE', 10, NULL,        'School-age functional impact matters.',                                    'HCH12-0003'),
    ('CR018','EMERGENCY',           'fact_definition', 'COUGH_SEVERITY',      'ACTIVATE', 15, NULL,        'Emergency: safety first — characterise severity immediately.',               'HCH2-0002'),
    ('CR019','COGNITIVE_IMPAIRMENT','question',        'SYMPTOM_DURATION',    'DISABLE',  0, NULL,        'Confused patient cannot give reliable duration.',                            'HCH1-0006'),
    ('CR020','CAREGIVER_HISTORY',   'question',        'FEEDING_DIFFICULTY',  'ACTIVATE', 25, 'CAREGIVER','Caregiver is the right source for paediatric feeding questions.',       'HCH1-0006'),
    ('CR021','CHILD',               'question',        'EXERCISE_INTOLERANCE','ACTIVATE', 20, NULL,        'Child functional impact via play/activity.',                                 'HCH12-0003'),
    ('CR022','ADOLESCENT',          'question',        'SMOKING_PACK_YEARS',  'ACTIVATE', 10, NULL,        'Adolescent smoking screening is age-appropriate.',                            'HCH12-0011'),
    ('CR023','ADOLESCENT',          'functional_domain', 'SOCIAL',            'ACTIVATE',  5, NULL,        'Adolescent social/sexual-health context activates.',                          'HCH1-0018'),
    ('CR024','OLDER_ADULT',         'question',        'FEEDING_DIFFICULTY',  'UNAVAILABLE',0,NULL,'Feeding difficulty is not the right functional frame for an older adult.', 'HCH1-0006')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 13. context_fact_mapping — raw expression → canonical fact (H5 §23)
-- ---------------------------------------------------------------------------
-- The paediatric translation layer (§22): observed/lay statements are
-- normalized onto the universal fact vocabulary.
INSERT INTO knowledge.context_fact_mapping
    (mapping_code, context_code, raw_expression, target_type, target_code, canonical_value, strength, description) VALUES
    ('CFM001','INFANT','stops playing','fact_definition','EXERCISE_INTOLERANCE','reduced','strong','Caregiver "stops playing" → reduced activity tolerance.'),
    ('CFM002','INFANT','stops feeding to breathe','fact_definition','FEEDING_DIFFICULTY','YES','strong','Feeding-associated respiratory limitation.'),
    ('CFM003','CHILD','cannot keep up with friends','fact_definition','EXERCISE_INTOLERANCE','reduced','moderate','Child exertional limitation reported by caregiver.'),
    ('CFM004','CHILD','needs to stop and rest','fact_definition','EXERCISE_INTOLERANCE','reduced','moderate','Intermittent exertional limitation.'),
    ('CFM005','OLDER_ADULT','cannot climb stairs','fact_definition','EXERCISE_INTOLERANCE','reduced','strong','Geriatric exertional limitation.'),
    ('CFM006','ADULT','gets winded walking uphill','fact_definition','EXERCISE_INTOLERANCE','reduced','moderate','Adult exertional limitation.'),
    ('CFM007','INFANT','tummy breathing or grunting','fact_definition','RESPIRATORY_DISTRESS','YES','strong','Work of breathing observed in an infant.'),
    ('CFM008','CHILD','wakes up breathless','fact_definition','EXERCISE_INTOLERANCE','reduced','moderate','Child exertional limitation (nocturnal frame).'),
    ('CFM009','ADULT','needs to stop for breath when undressing','fact_definition','EXERCISE_INTOLERANCE','reduced','moderate','Adult exertional breathlessness (canonical).'),
    ('CFM010','OLDER_ADULT','walks slower than peers','fact_definition','EXERCISE_INTOLERANCE','reduced','weak','Functional decline vs baseline in older adult.')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 14. Question wording variants per context (H5 §6/§33/§42)
-- ---------------------------------------------------------------------------
-- The same question_code (canonical concept) gets context-specific wording +
-- response_mode + historian. The first matching variant by context wins; the
-- CPU falls back to the 'default'/'adult' wording when none matches.
-- New wording for the feeding / dyspnoea / exercise / severity probes.
INSERT INTO knowledge.question_variant
    (question_id, context, language_code, wording, is_active, response_mode, historian_type)
SELECT q.id, v.context, v.language_code, v.wording, v.is_active, v.response_mode, v.historian_type
FROM (VALUES
    -- SYMPTOM_SEVERITY (HC008) — the 1-10 bother scale only works for self-reporters
    ('SYMPTOM_SEVERITY', 'adult',      'en', 'How much does this bother you? (0-10)',                   true, 'NUMERIC_SCALE',  'PATIENT'),
    ('SYMPTOM_SEVERITY', 'older_adult','en', 'How much has this bothered you today? (0-10)',             true, 'NUMERIC_SCALE',  'PATIENT'),
    ('SYMPTOM_SEVERITY', 'child',      'en', 'How bothered has your child been by this?',              true, 'NUMERIC_SCALE',  'PARENT'),
    ('SYMPTOM_SEVERITY', 'infant',     'en', 'Is the baby uncomfortable, irritable or sweaty?',        true, 'OBSERVATION',    'CAREGIVER'),
    -- DYSPNOEA_SEVERITY (H5 §6 example) — same canonical fact, four wordings
    ('DYSPNOEA_SEVERITY', 'adult',      'en', 'How much activity brings on the breathlessness?',      true, 'SELF_REPORT',   'PATIENT'),
    ('DYSPNOEA_SEVERITY', 'child',      'en', 'Can the child still play normally?',                     true, 'CAREGIVER_REPORT','CAREGIVER'),
    ('DYSPNOEA_SEVERITY', 'infant',     'en', 'Does the baby become breathless, sweaty or stop feeding?', true, 'CAREGIVER_REPORT','CAREGIVER'),
    ('DYSPNOEA_SEVERITY', 'unconscious','en', '<unavailable: cannot self-report>',                    false,'OBSERVATION',   'CAREGIVER'),
    -- EXERCISE_INTOLERANCE — child/infant vs adult wording
    ('EXERCISE_INTOLERANCE', 'adult', 'en', 'Has the cough limited how far you can walk or exercise?',  true, 'SELF_REPORT','PATIENT'),
    ('EXERCISE_INTOLERANCE', 'child', 'en', 'Has the child been able to play and run normally?',        true, 'CAREGIVER_REPORT','CAREGIVER'),
    ('EXERCISE_INTOLERANCE', 'infant','en', 'Does the baby tire during feeds?',                         true, 'CAREGIVER_REPORT','CAREGIVER'),
    -- FEEDING_DIFFICULTY — the §6 feeding ladder: neonate → infant → child → adult
    ('FEEDING_DIFFICULTY', 'neonate', 'en', 'Has the baby had difficulty breastfeeding?',               true, 'CAREGIVER_REPORT','CAREGIVER'),
    ('FEEDING_DIFFICULTY', 'infant',  'en', 'Does the baby stop feeding because of breathing difficulty?', true, 'CAREGIVER_REPORT','CAREGIVER'),
    ('FEEDING_DIFFICULTY', 'child',   'en', 'Has the cough made it harder to eat or drink?',            true, 'CAREGIVER_REPORT','CAREGIVER'),
    ('FEEDING_DIFFICULTY', 'adult',   'en', 'Have you had trouble eating or drinking because of the cough?', true, 'SELF_REPORT','PATIENT'),
    -- Caregiver proxy openers (H5 §42 example phrasing)
    ('OPEN_PRESENTING_CONCERN', 'caregiver', 'en', 'Tell me what has been going on with your child today.', true, 'CAREGIVER_REPORT','CAREGIVER')
) AS v(question_code, context, language_code, wording, is_active, response_mode, historian_type)
JOIN knowledge.question q ON q.question_code = v.question_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 15. Tag functional questions with their functional domain (H5 §24/42)
-- ---------------------------------------------------------------------------
UPDATE knowledge.question SET functional_domain_code = 'EXERCISE_TOLERANCE'
WHERE question_code IN ('EXERCISE_INTOLERANCE','DYSPNOEA_SEVERITY') AND functional_domain_code IS NULL;
UPDATE knowledge.question SET functional_domain_code = 'FEEDING'
WHERE question_code = 'FEEDING_DIFFICULTY' AND functional_domain_code IS NULL;
UPDATE knowledge.question SET functional_domain_code = 'EXERCISE_TOLERANCE'
WHERE question_code = 'SYMPTOM_SEVERITY' AND functional_domain_code IS NULL;

-- ---------------------------------------------------------------------------
-- 16. provenance — H1/H2/H4 claims → H5 objects
-- ---------------------------------------------------------------------------
-- Deterministic uuid5 object ids: scheme "H5:<object_type>:<code>".
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, x.object_type, x.object_id::uuid, x.object_code, 'derived_from'
FROM (VALUES
    -- clinical_context
    ('HCH1-0006', 'clinical_context', '3a793d76-a413-570d-bbbf-3825d4f91f6b'::uuid, 'C001'),
    ('HCH1-0006', 'clinical_context', 'd7357021-5376-5460-925b-f7aa5c6044db'::uuid, 'C002'),
    ('HCH1-0006', 'clinical_context', 'a519a93a-3ed4-57f3-a713-41d289a6b3ce'::uuid, 'C003'),
    ('HCH1-0006', 'clinical_context', 'c7797122-87bc-5d5a-9d69-7fb942344622'::uuid, 'C004'),
    ('HCH1-0006', 'clinical_context', '8cce989f-ef67-560b-8eb9-4c2b5ffccc3d'::uuid, 'C005'),
    ('HCH1-0006', 'clinical_context', 'c15574d1-fe0d-5a93-a838-2be8b69c6b0d'::uuid, 'C006'),
    ('HCH12-0003', 'clinical_context', '8876e64b-dc39-5c50-afa7-33560b2192e5'::uuid, 'C007'),
    ('HCH12-0003', 'clinical_context', 'cbe19a9d-826c-5e52-bede-38edcc94ca24'::uuid, 'C008'),
    ('HCH12-0003', 'clinical_context', 'a72773a4-747a-529e-93d9-3ab4290d55a5'::uuid, 'C009'),
    ('HCH2-0002', 'clinical_context', 'eba05b20-9282-5fa2-944e-8cda35f1ab97'::uuid, 'C010'),
    ('HCH1-0006', 'clinical_context', '9333beca-f8cd-5c26-861d-cf3edd4cd4e4'::uuid, 'C011'),
    ('HCH1-0006', 'clinical_context', '88752925-5c07-5001-9977-99f179010e7c'::uuid, 'C012'),
    ('HCH1-0006', 'clinical_context', '0a67a1d9-936a-5b69-828c-b90aad2164ae'::uuid, 'C013'),
    ('HCH1-0006', 'clinical_context', 'b240b4fa-2da4-53d7-82d8-3e19697140b9'::uuid, 'C014'),
    ('HCH2-0002', 'clinical_context', '417cee43-b4d2-53b2-a931-018fc999f02c'::uuid, 'C015'),
    ('HCH2-0002', 'clinical_context', '39e11813-daac-5317-af41-222da1165e38'::uuid, 'C016'),
    ('HCH1-0006', 'clinical_context', 'ba33a207-28d4-5fcb-b693-8d06f2007647'::uuid, 'C017'),
    ('HCH1-0006', 'clinical_context', 'd0f5d0c7-4d52-5cb2-b773-29a3bd912928'::uuid, 'C018'),
    -- developmental_stage
    ('HCH1-0006', 'developmental_stage', '783ca9bd-4420-568f-b5a3-5658dd87c1d8'::uuid, 'NEONATE'),
    ('HCH1-0006', 'developmental_stage', '134e6843-59fb-5137-8e3f-5c07567e44e8'::uuid, 'YOUNG_INFANT'),
    ('HCH1-0006', 'developmental_stage', 'e92230dd-eda4-5758-bf2a-5f1c2fea1f16'::uuid, 'OLDER_INFANT'),
    ('HCH1-0006', 'developmental_stage', '73e13950-9113-5b86-b160-5cd4e042495d'::uuid, 'TODDLER'),
    ('HCH1-0006', 'developmental_stage', 'd5111129-4b20-5039-a64c-0bf40e9b13d8'::uuid, 'PRESCHOOL'),
    ('HCH1-0006', 'developmental_stage', 'e40829f2-3260-56ba-a248-d8ef1225c4f3'::uuid, 'SCHOOL_AGE'),
    ('HCH1-0006', 'developmental_stage', '14453f52-c0c2-5545-9537-026da1eeb89f'::uuid, 'ADOLESCENT'),
    ('HCH1-0006', 'developmental_stage', 'c659a36f-b065-53fc-85b7-3eafd444ee84'::uuid, 'ADULT'),
    ('HCH1-0006', 'developmental_stage', 'a40df51c-671c-5010-9936-669ad4193e2f'::uuid, 'OLDER_ADULT'),
    -- historian_type
    ('HCH1-0006', 'historian_type', '4b803923-7243-5ef9-8eb2-ac6a279d451f'::uuid, 'PATIENT'),
    ('HCH1-0006', 'historian_type', '6e60957a-1d63-5981-8b7e-1c60c3c52b3c'::uuid, 'PARENT'),
    ('HCH1-0006', 'historian_type', '50226e3a-4fe9-57ef-a147-0a52fcbe1227'::uuid, 'CAREGIVER'),
    ('HCH1-0006', 'historian_type', 'b7f6e9f1-261e-54fa-8c7c-3d5a7584617a'::uuid, 'SPOUSE'),
    ('HCH1-0006', 'historian_type', '4e59bed8-6715-530d-b863-6de4938b17c3'::uuid, 'RELATIVE'),
    ('HCH1-0006', 'historian_type', '53abd4f3-ca02-58cb-a3fc-265b823a1c1f'::uuid, 'HEALTH_WORKER'),
    ('HCH1-0006', 'historian_type', '53b1afd9-50c0-56e6-8456-4c5fe1f13b7d'::uuid, 'OTHER'),
    -- historian_reliability
    ('HCH1-0006', 'historian_reliability', '7b6b033b-3a7d-57cf-8a43-25c0454a859b'::uuid, 'GOOD'),
    ('HCH1-0006', 'historian_reliability', '4d6ffb89-2b48-572f-ae33-0758baae0b2a'::uuid, 'FAIR'),
    ('HCH1-0006', 'historian_reliability', '00b20962-7c64-54f2-a0e6-80450291b9f9'::uuid, 'POOR'),
    ('HCH1-0006', 'historian_reliability', 'e9731f8f-ab31-5114-bb64-7c464a61c569'::uuid, 'UNRELIABLE'),
    ('HCH1-0006', 'historian_reliability', '9d37e845-8c59-539a-ae44-8ee62f965e6a'::uuid, 'UNKNOWN'),
    -- communication_context
    ('HCH1-0006', 'communication_context', 'ac902645-3d3e-5395-9b49-c7ac4854aa6b'::uuid, 'LANGUAGE_BARRIER'),
    ('HCH1-0006', 'communication_context', '7f6a379b-e8a9-5432-a6fd-85196d1bf4cb'::uuid, 'INTERPRETER_REQUIRED'),
    ('HCH1-0006', 'communication_context', 'dee0b497-9a5f-5a68-8e96-813a46244dba'::uuid, 'HEARING_IMPAIRED'),
    ('HCH1-0006', 'communication_context', 'fa38cd01-2c37-5261-a934-528a849ba4c2'::uuid, 'VISUAL_IMPAIRED'),
    ('HCH1-0006', 'communication_context', '2564177d-6d9e-5a53-bd2f-479e1557e331'::uuid, 'SPEECH_IMPAIRED'),
    ('HCH1-0006', 'communication_context', 'd16f119a-e6fc-51b0-9dab-dc65d4b1dd04'::uuid, 'LOW_LITERACY'),
    -- encounter_mode
    ('HCH1-0006', 'encounter_mode', '08a1c780-551b-5338-95f3-6d0c53a903bc'::uuid, 'IN_PERSON'),
    ('HCH1-0006', 'encounter_mode', 'cd7bdfda-3ede-5235-a4e0-df87e13baa3c'::uuid, 'VIDEO'),
    ('HCH1-0006', 'encounter_mode', 'cf651a37-627b-57ea-a5c2-a3c089c12799'::uuid, 'AUDIO'),
    ('HCH1-0006', 'encounter_mode', 'e13c97bf-2704-51db-a3da-6e447fcbbd50'::uuid, 'CHAT'),
    ('HCH1-0006', 'encounter_mode', 'a940eb16-c44d-5065-979e-adba80b06112'::uuid, 'REMOTE_MONITORING'),
    -- response_mode
    ('HCH12-0003', 'response_mode', '5b294713-59bf-56f7-943a-7c6eb6d49dca'::uuid, 'SELF_REPORT'),
    ('HCH1-0006', 'response_mode', 'b5586bfe-f548-5fc2-8553-409899528117'::uuid, 'CAREGIVER_REPORT'),
    ('HCH2-0002', 'response_mode', 'd647140d-9451-5d4e-8321-9e926277f58b'::uuid, 'OBSERVATION'),
    ('HCH12-0003', 'response_mode', '51f21bcd-9da0-5534-bbff-b4162bf9781b'::uuid, 'NUMERIC_SCALE'),
    ('HCH12-0003', 'response_mode', 'affe0826-8908-5a1b-b888-88f7bc920056'::uuid, 'STRUCTURED_CHOICE'),
    -- response_variant
    ('HCH12-0003', 'response_variant', '16d45827-adfc-582a-80e7-daeedc96f13c'::uuid, 'NUMERIC_SCALE'),
    ('HCH12-0003', 'response_variant', '2a838f69-9290-5f86-b31e-a6e3d2b35722'::uuid, 'FACES_SCALE'),
    ('HCH2-0002', 'response_variant', 'f916097b-80a3-561d-9e3e-42c6b5e703f9'::uuid, 'OBSERVABLE_CHECKLIST'),
    -- functional_domain
    ('HCH1-0006', 'functional_domain', '9639e01d-9c83-50b0-a533-252ff7db998b'::uuid, 'FD001'),
    ('HCH1-0006', 'functional_domain', '0e288bc4-a0f8-5281-9c8f-125261f28f7b'::uuid, 'FD021'),
    ('HCH1-0006', 'functional_domain', '3989fc93-8b17-5e49-97a3-806f2bb08564'::uuid, 'FD022'),
    ('HCH1-0006', 'functional_domain', 'd3bf8c2f-8411-5649-a35f-6ed39607a04c'::uuid, 'FD023'),
    ('HCH1-0006', 'functional_domain', '79f2f375-4087-5313-a6e4-1a9d73a3c468'::uuid, 'FD024'),
    ('HCH1-0006', 'functional_domain', '1015bbda-4bb1-5981-bbf8-9f10bc641f18'::uuid, 'FD025'),
    ('HCH1-0006', 'functional_domain', '227123e8-8766-5f12-bec7-a5f8fc1e7395'::uuid, 'FD026'),
    ('HCH1-0006', 'functional_domain', '5500bab1-5ac1-5e09-a6ba-b70533938bf5'::uuid, 'FD027'),
    ('HCH1-0006', 'functional_domain', 'c4f96351-8223-5980-b22a-e8c3f88c13db'::uuid, 'FD028'),
    ('HCH1-0018', 'functional_domain', '0feed1f5-99b0-5b36-b8c3-fcf9dcca4d92'::uuid, 'FD029'),
    ('HCH1-0018', 'functional_domain', '3680e02f-200f-5d40-b10e-daa847d85664'::uuid, 'FD030'),
    ('HCH1-0006', 'functional_domain', '6c6a29cb-619c-5ad8-ba2d-07a17f641ac0'::uuid, 'FD031'),
    ('HCH1-0006', 'functional_domain', 'd8f48a49-8002-5264-affb-a3dcfa8d74c9'::uuid, 'FD032'),
    ('HCH12-0003', 'functional_domain', '33a50a99-6aa1-53b8-ba0d-12f1d64b9afd'::uuid, 'FD033'),
    ('HCH1-0018', 'functional_domain', '26888454-ac89-54c3-955a-8314237c6c9b'::uuid, 'FD034'),
    ('HCH1-0018', 'functional_domain', '928f0028-d362-5cdf-b9ad-0b583a289b5b'::uuid, 'FD035'),
    ('HCH1-0018', 'functional_domain', '7f8d2487-c516-574b-a293-2678060abf2a'::uuid, 'FD036'),
    -- fact_capture_method
    ('HCH1-0006', 'fact_capture_method', 'fe7d3596-7bc3-5aa1-ad56-654d1bbf60f7'::uuid, 'PATIENT_REPORTED'),
    ('HCH1-0006', 'fact_capture_method', '43cfb8d2-337e-5c9e-9492-0998cc43907a'::uuid, 'CAREGIVER_REPORTED'),
    ('HCH2-0002', 'fact_capture_method', '45ded9fe-51f9-5d4a-9665-4625f594ec51'::uuid, 'CLINICIAN_OBSERVED'),
    ('HCH1-0006', 'fact_capture_method', '73c5734f-54e3-53ee-9db4-b1e4f75bb699'::uuid, 'DEVICE_MEASURED'),
    ('HCH1-0006', 'fact_capture_method', 'b7f1d7b5-51ae-5e1f-9538-f48ae93092c9'::uuid, 'LAB_MEASURED'),
    ('HCH1-0006', 'fact_capture_method', 'cd3144b7-5cd2-58c2-9b1b-20d58c794d2b'::uuid, 'IMAGING_DERIVED'),
    ('HCH1-0006', 'fact_capture_method', 'ed7f30d5-1d33-5af5-892d-b0a1898f88cc'::uuid, 'SYSTEM_DERIVED'),
    -- context_adaptation_rule
    ('HCH1-0006', 'context_adaptation_rule', '5a9bb508-4e41-5e99-be4d-447e4a8b1407'::uuid, 'CR001'),
    ('HCH1-0006', 'context_adaptation_rule', '26c53d7b-8b10-56e5-a31f-bd437ba9656c'::uuid, 'CR002'),
    ('HCH1-0006', 'context_adaptation_rule', 'd0810385-55f7-5dec-9023-28a9912f2315'::uuid, 'CR003'),
    ('HCH1-0006', 'context_adaptation_rule', 'df32124b-5539-522f-ac99-d50030ec9d52'::uuid, 'CR004'),
    ('HCH12-0003', 'context_adaptation_rule', 'a089aa56-1de1-5de0-87b3-44982a57795d'::uuid, 'CR005'),
    ('HCH1-0006', 'context_adaptation_rule', '395d56b3-e67c-5089-803b-d1299cd12482'::uuid, 'CR006'),
    ('HCH2-0002', 'context_adaptation_rule', '6fd66066-e9fd-5e7b-b9a3-e535b6559ee1'::uuid, 'CR007'),
    ('HCH2-0002', 'context_adaptation_rule', 'af629d43-5326-5ef2-8f2a-5adea8adf73b'::uuid, 'CR008'),
    ('HCH2-0002', 'context_adaptation_rule', '4d1a4c10-4e19-50a2-ae2d-788aea02c886'::uuid, 'CR009'),
    ('HCH1-0006', 'context_adaptation_rule', '21ec49e8-4d60-5982-bbd8-cdcae0dbcfc3'::uuid, 'CR010'),
    ('HCH1-0006', 'context_adaptation_rule', '3d9b9dc8-0761-54f0-960e-6b96cc15af49'::uuid, 'CR011'),
    ('HCH12-0003', 'context_adaptation_rule', '7093fd93-0860-563a-a205-4eaa2279d7ee'::uuid, 'CR012'),
    ('HCH12-0012', 'context_adaptation_rule', '313876e5-285a-5f5e-8130-c3232fc20886'::uuid, 'CR013'),
    ('HCH12-0011', 'context_adaptation_rule', 'd22aedb4-195d-5e46-a60f-122db348a86e'::uuid, 'CR014'),
    ('HCH1-0006', 'context_adaptation_rule', '8b03e87d-96b2-579a-8101-79d5d5865497'::uuid, 'CR015'),
    ('HCH2-0002', 'context_adaptation_rule', '2675e78a-8028-561b-ad9d-e1578718767f'::uuid, 'CR016'),
    ('HCH12-0003', 'context_adaptation_rule', '231f50a0-2c79-5caa-9ee0-bb342380e90b'::uuid, 'CR017'),
    ('HCH2-0002', 'context_adaptation_rule', '2537db5d-6ecb-599f-a3e6-22941667e112'::uuid, 'CR018'),
    ('HCH1-0006', 'context_adaptation_rule', '00c9008b-bf94-5a2b-af9e-7b31fbb11cf4'::uuid, 'CR019'),
    ('HCH1-0006', 'context_adaptation_rule', 'ae47ce7e-8db7-56a7-8543-3f12fb378685'::uuid, 'CR020'),
    ('HCH12-0003', 'context_adaptation_rule', 'fd726f5d-15f7-535c-9bac-2e853211550d'::uuid, 'CR021'),
    ('HCH12-0011', 'context_adaptation_rule', 'da151acd-734b-5e2a-a31c-602ab5f9b895'::uuid, 'CR022'),
    ('HCH1-0018', 'context_adaptation_rule', '4993885b-d507-5c06-a0e8-23feeaa45131'::uuid, 'CR023'),
    ('HCH1-0006', 'context_adaptation_rule', 'eedc7358-3b6f-5e37-9335-7a63833339fa'::uuid, 'CR024'),
    -- context_fact_mapping
    ('HCH1-0006', 'context_fact_mapping', '57f4edbf-e62f-56b1-96ac-178d03122b6d'::uuid, 'CFM001'),
    ('HCH1-0006', 'context_fact_mapping', 'a659a3c5-5f46-5c3d-aad7-834bed9a703c'::uuid, 'CFM002'),
    ('HCH12-0003', 'context_fact_mapping', '3dfe2cea-2378-59f3-b977-5ecbf3deaaa7'::uuid, 'CFM003'),
    ('HCH12-0003', 'context_fact_mapping', 'b7c77f51-9a5a-5e40-823a-f1994bda5b9b'::uuid, 'CFM004'),
    ('HCH12-0003', 'context_fact_mapping', 'cfcaa384-ce50-5de9-8cef-6ae271998f88'::uuid, 'CFM005'),
    ('HCH12-0003', 'context_fact_mapping', '44e8e3d3-2c35-59e2-99bf-4edc4302a55d'::uuid, 'CFM006'),
    ('HCH12-0002', 'context_fact_mapping', 'e4705668-2cea-5970-8467-5db4263d808a'::uuid, 'CFM007'),
    ('HCH12-0003', 'context_fact_mapping', 'efc0bcf9-1ade-577a-9785-df2687ba2f0b'::uuid, 'CFM008'),
    ('HCH12-0003', 'context_fact_mapping', '1907c004-b941-5e0c-a565-3900ec6d86b8'::uuid, 'CFM009'),
    ('HCH12-0003', 'context_fact_mapping', 'd54e87f1-fc71-51b5-882f-83b895f24673'::uuid, 'CFM010')
) AS x(claim_code, object_type, object_id, object_code)
JOIN knowledge.source_claim s ON s.claim_code = x.claim_code
  ON CONFLICT DO NOTHING;