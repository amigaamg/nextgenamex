-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H6 seed zq7: universal physical examination engine
-- =============================================================================
-- Seeds the H6 examination knowledge base, GROUNDED IN HUTCHISON CH2 (General
-- patient examination: Box 2.5 complete-examination order, temperature/pulse/BP
-- ranges, postural drop), CH12 (Respiratory: Box 12.9-12.16 respiratory rate,
-- chest sequence, auscultation interpretation, hands/clubbing) and the
-- question-principle claims of CH1. Every H6 object carries at least one
-- provenance edge to the Hutchison claim that teaches it (§46).
--
--   clinical.fact_definition        — NEW canonical facts for physical signs
--   knowledge.examination_domain    — DOM01..DOM09 (universal domains)
--   knowledge.observation_concept   — OC001..OC016 (one per canonical fact, H6 §38)
--   knowledge.examination_concept   — EX001..EX009 (universal exam bundles, H6 §33)
--   knowledge.examination_component — EX## → {OC##} (H6 §34)
--   knowledge.examination_technique — the Four Techniques (H6 §12)
--   knowledge.examination_position  — patient positions (H6 §14)
--   knowledge.examination_site      — anatomical surfaces (H6 §13)
--   knowledge.examination_rule      — priority/safety engine (H6 §8/§32)
--   knowledge.reference_standard    — age-adjusted physiological ranges (H6 §9)
--   knowledge.finding_interpretation — NORMAL/ABNORMAL/... + sign descriptors (H6 §10)
--   knowledge.finding_phenotype_link — sign value → associated concept (H6 §44)
--   knowledge.provenance            — H6:<object> → Hutchison claim edges
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. New canonical fact_definitions for physical signs (H6 §38/§44)
-- Existing facts (TEMPERATURE, HEART_RATE, RESPIRATORY_RATE, SPO2,
-- RESPIRATORY_DISTRESS) come from clinical.fact_definition already and are reused.
-- ---------------------------------------------------------------------------
INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES
    ('BLOOD_PRESSURE',              'Blood pressure',               'Systolic/diastolic blood pressure as a single text measurement (mmHg).',                         'text',    false, true),
    ('GLASGOW_COMA_SCORE',          'Glasgow Coma Score',           'Level of consciousness: eye/verbal/motor (3-15; <8 = coma).',                                   'numeric', false, true),
    ('GENERAL_APPEARANCE',          'General appearance',           'Global "Does this person look well/mildly ill/severely ill?" assessment (HCH2-0002).',          'coded',   false, true),
    ('JUGULAR_VENOUS_DISTENTION',   'Jugular venous distention',    ' Elevated jugular venous pulse on neck inspection (HCH2-0003).',                               'boolean', false, true),
    ('CLUBBING',                    'Clubbing',                     ' Digital clubbing of the fingers (Lovibond angle, Schamroth window; HCH12-0015).',            'boolean', false, true),
    ('PULSE_PRESENCE',              'Pulse presence',               ' A peripheral pulse is palpable (absent = perfusion risk).',                                   'boolean', false, true),
    ('PULSE_CHARACTER',             'Pulse character',              ' Rate and character of the peripheral pulse (raised in asthma; pulsus paradoxus, HCH12-0015).',  'coded',   false, true),
    ('WORK_OF_BREATHING',           'Work of breathing',            ' Observable respiratory effort (accessory muscles, recession, Cheyne-Stokes, HCH12-0014/16).','coded',   false, true),
    ('CHEST_AUSCULTATION',          'Chest auscultation',           ' Breath sounds / added sounds interpreted by auscultation (HCH12-0018).',                       'coded',   false, true),
    ('ABDOMEN_ASSESSMENT',          'Abdomen assessment',           ' Inspection/palpation/percussion of the abdomen (tenderness, organomegaly, HCH2-0004).',        'coded',   false, true),
    ('FUNCTIONAL_MOBILITY',         'Functional mobility',          ' Posture, gait, speech and interaction as a functional screen (HCH2-0003).',                   'coded',   false, true),
    ('MUSCULOSKELETAL_ASSESSMENT',  'Musculoskeletal assessment',   ' Colour, texture, oedema, varicosities, gait and limb swelling (HCH2-0004).',                   'coded',   false, true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. examination_domain — the universal domains (H6 §33/§32)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_domain (domain_code, code, body_system_code, label, description, sort_order, is_mandatory, status) VALUES
    ('DOM01', 'GENERAL',            'CONSTITUTIONAL',    'General assessment',     'Global well-being, nutrition, odour, skin (HCH2-0002/0003).',                                       1, true,  'active'),
    ('DOM02', 'VITAL_SIGNS',        'CONSTITUTIONAL',    'Vital signs',             ' Physiological gate: temperature, pulse, BP, RR, saturation (HCH2-0003, HCH12-0016).',            2, true,  'active'),
    ('DOM03', 'HEAD_NECK',          'HEAD_NECK',         'Head & neck',            ' Face, neck, JVP, throat (HCH2-0003).',                                                           3, false, 'active'),
    ('DOM04', 'CARDIOVASCULAR',     'CARDIOVASCULAR',    'Cardiovascular',          ' Pulse, BP, JVP, oedema, heart sounds (HCH2-0003/0004).',                                            4, false, 'active'),
    ('DOM05', 'RESPIRATORY',        'RESPIRATORY',       'Respiratory',             ' General appearance, hands, RR, chest inspection/percussion/auscultation (HCH12-0014..18).',     5, false, 'active'),
    ('DOM06', 'ABDOMINAL',          'GASTROINTESTINAL',  'Abdomen',                 ' Inspection, palpation, percussion and auscultation (HCH2-0004).',                               6, false, 'active'),
    ('DOM07', 'NEUROLOGICAL',       'NEUROLOGICAL',      'Neurological',            ' Mental status, cranial nerves, motor and sensory (HCH2-0004).',                                    7, false, 'active'),
    ('DOM08', 'FUNCTIONAL',         'CONSTITUTIONAL',    'Functional',              ' Posture, gait, speech and interaction (HCH2-0003).',                                               8, false, 'active'),
    ('DOM09', 'MUSCULOSKELETAL',    'MUSCULOSKELETAL',   'Musculoskeletal',         ' Limbs, swelling, varicosities, gait (HCH2-0004).',                                                 9, false, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. observation_concept — one per canonical fact (H6 §33/§38), OC001..OC016
-- OC002/003/004/005 reuse the pre-existing TEMPERATURE/HEART_RATE/RESP_RATE/SPO2 facts.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.observation_concept
    (code, fact_definition_code, name, short_label, value_type, unit, value_set_code, normal_range,
     applies_to_context_codes, capture_method_code, interpretation_default, status)
VALUES
    ('OC001','GENERAL_APPEARANCE','General appearance','Looks well?',                    'CATEGORICAL', NULL, 'VS_GENERAL_APPEARANCE','{"min":null,"max":null,"unit":null,"inclusive":true}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active'),
    ('OC002','TEMPERATURE','Core body temperature','Temp °C',                          'NUMERIC',     'Celsius','VS_BODY_TEMPERATURE','{"min":35.8,"max":37.0,"unit":"Celsius","inclusive":true}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'DEVICE_MEASURED',  'FIN_NORMAL', 'active'),
    ('OC003','HEART_RATE','Heart rate','HR bpm',                                    'NUMERIC',     'bpm','VS_HEART_RATE','{"min":60,"max":100,"unit":"bpm","inclusive":true}',          ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'DEVICE_MEASURED',  'FIN_NORMAL', 'active'),
    ('OC004','RESP_RATE','Respiratory rate','RR /min',                       'NUMERIC',     'breaths per minute','VS_RESPIRATORY_RATE','{"min":12,"max":18,"unit":"breaths per minute","inclusive":true}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED','FIN_NORMAL', 'active'),
    ('OC005','SPO2','Oxygen saturation','SpO2 %',                                   'NUMERIC',     '%','VS_SPO2','{"min":95,"max":100,"unit":"%","inclusive":true}',             ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'DEVICE_MEASURED', 'FIN_NORMAL', 'active'),
    ('OC006','BLOOD_PRESSURE','Blood pressure','BP mmHg',                          'TEXT',        'mmHg','VS_BLOOD_PRESSURE', NULL,                                                ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'DEVICE_MEASURED',  'FIN_NORMAL', 'active'),
    ('OC007','GLASGOW_COMA_SCORE','Glasgow Coma Score','GCS',                     'NUMERIC',     NULL,'VS_GLASGOW','{"min":13,"max":15,"unit":"score","inclusive":true}',         ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED','FIN_NORMAL', 'active'),
    ('OC008','PULSE_CHARACTER','Pulse character','Pulse',                          'CATEGORICAL', NULL, 'VS_PULSE_CHARACTER','{"min":null,"max":null,"unit":null,"inclusive":true}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active'),
    ('OC009','WORK_OF_BREATHING','Work of breathing','Resp effort',                'CATEGORICAL', NULL, 'VS_WORK_OF_BREATHING','{"min":null,"max":null,"unit":null,"inclusive":true}', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active'),
    ('OC010','CHEST_AUSCULTATION','Chest auscultation','Lungs',                    'CATEGORICAL', NULL, 'VS_AUSCULTATION','{"min":null,"max":null,"unit":null,"inclusive":true}',  ARRAY['ADULT','OLDER_ADULT','CHILD'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active'),
    ('OC011','ABDOMEN_ASSESSMENT','Abdomen assessment','Abdomen',                  'CATEGORICAL', NULL, 'VS_ABDOMEN','{"min":null,"max":null,"unit":null,"inclusive":true}',     ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active'),
    ('OC012','JUGULAR_VENOUS_DISTENTION','Jugular venous distension','JVD',       'BOOLEAN',     NULL, NULL,'{"min":null,"max":null,"unit":null,"inclusive":true}',        ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_ABSENT', 'active'),
    ('OC013','CLUBBING','Clubbing','Clubbing',                                  'BOOLEAN',     NULL, NULL,'{"min":null,"max":null,"unit":null,"inclusive":true}',        ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_ABSENT', 'active'),
    ('OC014','PULSE_PRESENCE','Pulse presence','Pulse',                           'BOOLEAN',     NULL, NULL,'{"min":null,"max":null,"unit":null,"inclusive":true}',        ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_PRESENT', 'active'),
    ('OC015','FUNCTIONAL_MOBILITY','Functional mobility','Mobility',              'CATEGORICAL', NULL, 'VS_FUNCTIONAL','{"min":null,"max":null,"unit":null,"inclusive":true}',      ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active'),
    ('OC016','MUSCULOSKELETAL_ASSESSMENT','Musculoskeletal assessment','MSK',      'CATEGORICAL', NULL, 'VS_MSK','{"min":null,"max":null,"unit":null,"inclusive":true}',         ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'CLINICIAN_OBSERVED', 'FIN_NORMAL', 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. examination_concept — universal exam bundles EX001..EX009 (H6 §33)
-- base_priority uses H6 §8 absolute urgency (higher = sooner; safety-critical = 1000).
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_concept
    (code, domain_code, fact_definition_code, name, short_label, description, body_system_code,
     is_mandatory, base_priority, technique_codes, capture_method_codes, applies_to_context_codes, status)
VALUES
    ('EX001','DOM01', NULL, 'General assessment','Look, feel, listen','"Does this person look well/mildly ill/severely ill?" + nutrition, odour, skin (HCH2-0002/0003).', 'CONSTITUTIONAL', true,  1000, ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_AUSCULTATION'], ARRAY['CLINICIAN_OBSERVED','OBSERVATION'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','OUTPATIENT','INPATIENT'], 'active'),
    ('EX002','DOM02', NULL, 'Vital signs','Temp/Pulse/RR/SpO2/BP',' Physiological safety gate: temperature, heart rate, BP, respiratory rate, oxygen saturation (HCH2-0003, HCH12-0016).', 'CONSTITUTIONAL', true,  1000, ARRAY['TECH_INSPECTION','TECH_PALPATION'], ARRAY['DEVICE_MEASURED','CLINICIAN_OBSERVED'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','OUTPATIENT','INPATIENT'], 'active'),
    ('EX003','DOM03', NULL, 'Head & neck examination','Neck/JVP/throat',' Face, neck, jugular venous pulse, oropharynx (HCH2-0003).', 'HEAD_NECK', false,  300, ARRAY['TECH_INSPECTION'], ARRAY['CLINICIAN_OBSERVED','OBSERVATION'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'active'),
    ('EX004','DOM04', NULL, 'Cardiovascular examination','Pulse/BP/JVD/cv exam',' Pulse character, blood pressure, JVP, peripheral oedema, heart sounds (HCH2-0003/0004).', 'CARDIOVASCULAR', false,  700, ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_AUSCULTATION'], ARRAY['CLINICIAN_OBSERVED','DEVICE_MEASURED'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'active'),
    ('EX005','DOM05', NULL, 'Respiratory examination','Look, feel, listen chest',' General appearance, hands, respiratory rate, chest inspection/palpation/percussion/auscultation (HCH12-0014..0018).', 'RESPIRATORY', false,  950, ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_PERCUSSION','TECH_AUSCULTATION'], ARRAY['CLINICIAN_OBSERVED','OBSERVATION'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'active'),
    ('EX006','DOM06', NULL, 'Abdominal examination',' Abdomen',' Inspection, palpation, percussion and auscultation of the abdomen (HCH2-0004).', 'GASTROINTESTINAL', false,  500, ARRAY['TECH_INSPECTION','TECH_PALPATION','TECH_PERCUSSION','TECH_AUSCULTATION'], ARRAY['CLINICIAN_OBSERVED'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'active'),
    ('EX007','DOM07', NULL, 'Neurological examination',' GCS / neuro',' Mental status (Glasgow Coma Score), cranial nerves, motor and sensory (HCH2-0004).', 'NEUROLOGICAL', false,  990, ARRAY['TECH_INSPECTION','TECH_PALPATION'], ARRAY['CLINICIAN_OBSERVED'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 'active'),
    ('EX008','DOM08', NULL, 'Functional assessment',' Mobility/gait',' Posture, gait, speech and interaction as the functional screen (HCH2-0003).', 'CONSTITUTIONAL', false,  100, ARRAY['TECH_INSPECTION'], ARRAY['CLINICIAN_OBSERVED','OBSERVATION'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'active'),
    ('EX009','DOM09', NULL, 'Musculoskeletal examination',' Limbs',' Colour, texture, oedema, varicose veins, gait and limb swelling (HCH2-0004).', 'MUSCULOSKELETAL', false,  200, ARRAY['TECH_INSPECTION','TECH_PALPATION'], ARRAY['CLINICIAN_OBSERVED','OBSERVATION'], ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. examination_component — each exam concept's constituent observations (H6 §34)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_component (examination_concept_code, observation_concept_code, is_mandatory, sort_order) VALUES
    ('EX001','OC001', true,  1),  -- general appearance
    ('EX002','OC002', true,  1),  -- temperature
    ('EX002','OC003', true,  2),  -- heart rate
    ('EX002','OC004', true,  3),  -- respiratory rate
    ('EX002','OC005', true,  4),  -- oxygen saturation
    ('EX002','OC006', true,  5),  -- blood pressure (incl. postural drop, HCH2-0003)
    ('EX003','OC012', false, 1),  -- JVD (neck)
    ('EX004','OC003', true,  1),  -- heart rate / pulse
    ('EX004','OC008', true,  2),  -- pulse character
    ('EX004','OC006', true,  3),  -- blood pressure
    ('EX004','OC012', true,  4),  -- JVD (cardiac)
    ('EX004','OC014', true,  5),  -- pulse presence (perfusion)
    ('EX005','OC004', true,  1),  -- respiratory rate
    ('EX005','OC009', true,  2),  -- work of breathing
    ('EX005','OC010', true,  3),  -- chest auscultation
    ('EX005','OC013', false, 4),  -- clubbing (respiratory causes, HCH12-0015)
    ('EX005','OC014', true,  5),  -- pulse presence (accessory-muscle use)
    ('EX006','OC011', true,  1),  -- abdomen assessment
    ('EX007','OC007', true,  1),  -- Glasgow Coma Score
    ('EX008','OC015', true,  1),  -- functional mobility
    ('EX009','OC016', true,  1)   -- musculoskeletal assessment
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. examination_technique — The Four Techniques (H6 §12)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_technique (code, name, description, sort_order, status) VALUES
    ('TECH_INSPECTION',   'Inspection','Looking: posture, symmetry, colour, scars, movement, intercostal recession (HCH12-0017).', 1, 'active'),
    ('TECH_PALPATION',    'Palpation','Feeling with the hands: texture, temperature, tenderness, tracheal position, chest expansion (HCH12-0017).', 2, 'active'),
    ('TECH_PERCUSSION',   'Percussion','Tapping: resonance vs dullness over the chest, comparing sides (HCH12-0017).', 3, 'active'),
    ('TECH_AUSCULTATION', 'Auscultation','Listening: breath sounds and added sounds (vesicular/bronchial, wheeze, crackles) (HCH12-0018).', 4, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. examination_position — standardised patient positions (H6 §14)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_position (position_code, name, description, sort_order, status) VALUES
    ('POS_SUPINE',          'Supine',           'Back flat on the bed; feet supported. Default for vitals/BP.',                                   1, 'active'),
    ('POS_SITTING',         'Sitting',          'Upright; forward leaning for posterior chest examination (HCH12-0017).',                        2, 'active'),
    ('POS_LEFT_LATERAL',    'Left lateral',     'On the left side; improves cardiac filling and EXP breath sounds.',                             3, 'active'),
    ('POS_RIGHT_LATERAL',   'Right lateral',    'On the right side; aids hepatic dullness and gallbladder exam.',                               4, 'active'),
    ('POS_KNEELING_FLEXED', 'Kneeling, forward flexed', 'For back/vertebral and lower-lung posterior bases.',                                    5, 'active'),
    ('POS_OUTLET',          'Arm raised (outlet)', 'For brachial/radial pulse and BV access assessment.',                                      6, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. examination_site — anatomical surfaces (H6 §13)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_site (code, body_system_code, name, description, default_position_code, status) VALUES
    ('SITE_CHEST',        'RESPIRATORY',       'Chest',' Anterior and posterior chest wall for respiratory exam.', 'POS_SITTING','active'),
    ('SITE_NECK',         'HEAD_NECK',        'Neck',' Jugular venous pulse and neck inspection.', 'POS_SUPINE', 'active'),
    ('SITE_FINGERS',      'RESPIRATORY',      'Fingers',' Clubbing, cyanosis, tobacco staining (HCH12-0015).', 'POS_SUPINE', 'active'),
    ('SITE_FACE_NECK',    'HEAD_NECK',        'Face & neck',' Pallor, malar flush, butterfly rash, JVP (HCH2-0003).', 'POS_SUPINE','active'),
    ('SITE_ARMS',         'CARDIOVASCULAR',   'Upper limbs',' Radial/Brachial pulse, BP, varicosities (HCH2-0004).', 'POS_OUTLET','active'),
    ('SITE_LEGS',         'MUSCULOSKELETAL',  'Lower limbs',' Colour, texture, hair, oedema, varicose veins, DVT (HCH2-0003/0004).', 'POS_SUPINE','active'),
    ('SITE_ABDOMEN',      'GASTROINTESTINAL', 'Abdomen',' Inspection, palpation, percussion, auscultation (HCH2-0004).', 'POS_SUPINE','active'),
    ('SITE_AIRWAY',       'HEAD_NECK',        'Airway / face',' Facial symmetry, airway patency, consciousness (HCH2-0004).', 'POS_SUPINE','active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9. examination_rule — priority / safety / availability engine (H6 §8/§32)
-- Higher priority_delta = the exam is brought forward (safety-critical=1000 base).
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.examination_rule
    (rule_code, trigger_type, trigger_code, target_type, target_code, modification, priority_delta, rationale, evidence_claim_code, applies_to_context_codes, is_active, status)
VALUES
    ('ER001','ALWAYS',       NULL,            'examination_concept','EX001','SAFETY',     0, 'Never miss "looks severely ill"; global assessment first (HCH2-0002).',          'HCH2-0002', ARRAY['EMERGENCY','OUTPATIENT','INPATIENT','TELEMEDICINE'], true, 'active'),
    ('ER002','ALWAYS',       NULL,            'examination_concept','EX002','SAFETY',     0, 'Vital signs are a physiological safety gate (HCH2-0003, HCH12-0016).',           'HCH2-0003', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','OUTPATIENT','INPATIENT'], true, 'active'),
    ('ER003','SYMPTOM_SIGN', 'DIZZINESS',     'examination_concept','EX004','ACTIVATE',   0, 'Dizziness prioritises cardiovascular examination.',                            'HCH2-0003', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('ER004','SYMPTOM_SIGN', 'DYSPNOEA',      'examination_concept','EX005','ACTIVATE',  50, 'Dyspnoea is the cardinal respiratory exam trigger (HCH12-0016).',              'HCH12-0016', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], true, 'active'),
    ('ER005','SYMPTOM_SIGN', 'DYSaPNEA',      'examination_concept','EX004','ACTIVATE',  25, 'Severe dyspnoea raises the cardiovascular safety priority.',                     'HCH2-0003', ARRAY['ADULT','OLDER_ADULT','CHILD'], true, 'active'),
    ('ER006','SYMPTOM_SIGN', 'CHEST_PAIN',    'examination_concept','EX004','ACTIVATE',  30, 'Chest pain prioritises cardiovascular assessment (HCH2-0004).',               'HCH2-0004', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('ER007','SYMPTOM_SIGN', 'ABDOMINAL_PAIN','examination_concept','EX006','ACTIVATE', 15, 'Abdominal pain prioritises the abdominal examination.',                          'HCH2-0004', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('ER008','SYMPTOM_SIGN', 'HEADACHE',      'examination_concept','EX005','ACTIVATE',  10, 'Severe headache prioritises neurological screen (consciousness first).',         'HCH2-0004', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('ER009','SYMPTOM_SIGN', 'NEUROLOGY',     'examination_concept','EX007','MANDATORY',  0, 'Any focal neurology makes the full neurological examination mandatory.',        'HCH2-0004', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], true, 'active'),
    ('ER010','CONTEXT',      'EMERGENCY',     'examination_concept','EX001','MANDATORY',   0, 'Emergency: confirm airway/circulation BEFORE detailed exam (HCH2-0002).',        'HCH2-0002', ARRAY['EMERGENCY'], true, 'active'),
    ('ER011','CONTEXT',      'EMERGENCY',     'examination_concept','EX005','PRIORITY',    0, 'Emergency: respiratory exam second after circulation (HCH2-0002).',              'HCH2-0002', ARRAY['EMERGENCY'], true, 'active'),
    ('ER012','CONTEXT',      'TELEMEDICINE',  'technique',        'TECH_AUSCULTATION','UNAVAILABLE', 0, 'Auscultation is impossible over telemedicine (H5 §29 NOT_NORMAL vs NORMAL).','HCH2-0002', ARRAY['TELEMEDICINE'], true, 'active'),
    ('ER013','CONTEXT',      'NEONATE',       'examination_concept','EX001','ACTIVATE',    0, 'General appearance (incl. feeding/work-of-breathing) is the neonatal red flag.', 'HCH1-0006', ARRAY['NEONATE'], true, 'active'),
    ('ER014','CONTEXT',      'UNCONSCIOUS',   'examination_concept','EX007','MANDATORY',   0, 'Unconscious patient MUST have GCS documented (HCH2-0003).',                       'HCH2-0003', ARRAY['UNCONSCIOUS','COGNITIVE_IMPAIRMENT'], true, 'active'),
    ('ER015','CONTEXT',      'OLDER_ADULT',   'examination_concept','EX008','ACTIVATE',    0, 'Geriatric functional baseline (ADL/IADL) is the comparator in older adults.',    'HCH1-0006', ARRAY['OLDER_ADULT'], true, 'active'),
    ('ER016','SYMPTOM_SIGN', 'DYSPNOEA',      'examination_concept','EX001','ACTIVATE',    0, 'Severe dyspnoea: reconfirm severity by global assessment first.',                 'HCH2-0002', ARRAY['EMERGENCY'], true, 'active'),
    ('ER017','ALWAYS',       NULL,            'examination_concept','EX002','PRIORITY',    0, 'Vital signs are captured on EVERY encounter (safety gate, HCH2-0003).',         'HCH2-0003', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE','EMERGENCY','OUTPATIENT','INPATIENT'], true, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 10. reference_standard — age-adjusted normal ranges (H6 §9), RS001..RS016
-- Adult ranges from HCH2-0003 (temperature 35.8-37 ... pulse ... BP) and HCH12-0016
-- (adult RR ~14-16); paediatric/older-adult bands are the age-applied overrides.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.reference_standard
    (code, observation_concept_code, applies_to_context_codes, range_low, range_high, range_unit, is_inclusive, interpretation, source, source_claim_code, evidence_strength, status)
VALUES
    ('RS001','OC002', ARRAY['ADULT'],          35.8,  37.0, 'Celsius','t','NORMAL','Hutchison Box 2.5 (temperature 35.8-37, HCH2-0003).',       'HCH2-0003','strong',  'active'),
    ('RS002','OC002', ARRAY['OLDER_ADULT'],     35.5,  37.5, 'Celsius','t','NORMAL','Hutchison (lower set point in older adults).',            'HCH2-0003','moderate','active'),
    ('RS003','OC002', ARRAY['CHILD'],           36.0,  37.5, 'Celsius','t','NORMAL','Hutchison (young children run slightly higher).',         'HCH2-0003','moderate','active'),
    ('RS004','OC002', ARRAY['NEONATE'],          36.0,  37.5, 'Celsius','t','NORMAL','Hutchison (neonate thermoregulation immature).',        'HCH2-0003','moderate','active'),
    ('RS005','OC003', ARRAY['ADULT'],          60,    100,  'bpm','t','NORMAL','Hutchison Box 2.5 (pulse rate, HCH2-0003).',                   'HCH2-0003','strong',  'active'),
    ('RS006','OC003', ARRAY['OLDER_ADULT'],     50,    100,  'bpm','t','NORMAL','Hutchison (resting rate ~50-100 in older adults).',          'HCH2-0003','moderate','active'),
    ('RS007','OC003', ARRAY['CHILD'],           70,    120,  'bpm','t','NORMAL','Hutchison (child HR higher than adult).',                   'HCH2-0003','moderate','active'),
    ('RS008','OC003', ARRAY['INFANT'],          90,    160,  'bpm','t','NORMAL','Hutchison (infant HR 90-160).',                           'HCH2-0003','moderate','active'),
    ('RS009','OC003', ARRAY['NEONATE'],         100,   180,  'bpm','t','NORMAL','Hutchison (neonate HR 100-180).',                          'HCH2-0003','moderate','active'),
    ('RS010','OC004', ARRAY['ADULT'],          12,    18,   'breaths per minute','t','NORMAL',' Hutchison: adult rate ~14-16 breaths/min (HCH12-0016).', 'HCH12-0016','strong',  'active'),
    ('RS011','OC004', ARRAY['OLDER_ADULT'],     12,    20,   'breaths per minute','t','NORMAL',' Hutchison (older adults tolerate slightly wider).',    'HCH2-0003','moderate','active'),
    ('RS012','OC004', ARRAY['CHILD'],           20,    30,   'breaths per minute','t','NORMAL',' Hutchison (child RR > adult; 2-5y ~20-25, 6-11y 12-20).', 'HCH2-0003','moderate','active'),
    ('RS013','OC004', ARRAY['INFANT'],          30,    50,   'breaths per minute','t','NORMAL',' Hutchison (infant RR 30-50; tachypnoea = increased rate).', 'HCH2-0003','moderate','active'),
    ('RS014','OC004', ARRAY['NEONATE'],          30,    60,   'breaths per minute','t','NORMAL',' Hutchison (neonate RR 30-60; apnoea = cessation, HCH12-0016).', 'HCH12-0016','moderate','active'),
    ('RS015','OC005', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT','NEONATE'], 95, 100, '%','t','NORMAL',' Oxygen saturation ≥95 % is normal (HCH12-0016 respiratory monitoring).', 'HCH12-0016','moderate','active'),
    ('RS016','OC007', ARRAY['ADULT','OLDER_ADULT','CHILD','INFANT'], 13, 15, 'score','t','NORMAL',' Glasgow Coma Score ≥13 normal (consciousness screen, HCH2-0003).', 'HCH2-0003','moderate','active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 11. finding_interpretation — the interpretation vocabulary (H6 §10)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.finding_interpretation (code, canonical_name, label, value_type_constraint, is_abnormal, is_critical, description, sort_order, status) VALUES
    ('FIN_NORMAL',        'Normal',        'Normal',              NULL,          false, false, 'The finding is within normal limits.',                                          1, 'active'),
    ('FIN_ABNORMAL',      'Abnormal',      'Abnormal',            NULL,          true,  false, 'The finding is outside normal limits.',                                         2, 'active'),
    ('FIN_UNABLE',        'Unable to assess','Unable to assess',  NULL,          false, false, 'The finding could not be assessed (e.g. over telemedicine).',                 3, 'active'),
    ('FIN_PRESENT',       'Present',       'Present',             'BOOLEAN',     false, false, 'The sign/finding is present.',                                                  4, 'active'),
    ('FIN_ABSENT',        'Absent',        'Absent',              'BOOLEAN',     false, false, 'The sign/finding is absent.',                                                 5, 'active'),
    ('FIN_CRITICAL',      'Critical',      'Critical',            NULL,          true,  true,  'The finding is immediately life-threatening.',                                  6, 'active'),
    ('FIN_VESICULAR',     'Vesicular','Vesicular breath sounds','CATEGORICAL', false, false, ' Normal breath sounds — NOT abnormal (HCH12-0018).',                            7, 'active'),
    ('FIN_BRONCHIAL',     'Bronchial breath sounds','Bronchial','CATEGORICAL', true,  false, ' Indicates consolidation (HCH12-0018).',                                   8, 'active'),
    ('FIN_WHEEZE',        'Wheeze','Wheeze',             'CATEGORICAL', true,  false, ' Asthma/COPD/infection/cardiac failure (HCH12-0018).',                            9, 'active'),
    ('FIN_CRACKLES',      'Crackles','Crackles',        'CATEGORICAL', true,  false, ' Fibrosis/cardiac failure/COPD/bronchiectasis (HCH12-0018).',                   10,'active'),
    ('FIN_CLEAR',         'Clear to auscultation','Clear','CATEGORICAL', false, false, ' No added sounds — normal lung fields (HCH12-0018).',                          11,'active'),
    ('FIN_DULLNESS',      'Dullness','Dullness',        'CATEGORICAL', true,  false, ' Indicates consolidation/mass/effusion (percussion, HCH12-0017).',             12,'active'),
    ('FIN_TIMPANIC',      'Timpanic','Timpanic',        'CATEGORICAL', false, false, ' Resonant/timpanic percussion — normal over hyperinflated lung.',               13,'active'),
    ('FIN_JVD_ELEVATED',  'Jugular venous distension','Elevated JVP','BOOLEAN', true,  false, ' Raised JVP: fluid overload / cardiac failure (HCH2-0003).',                    14,'active'),
    ('FIN_PALLOR',        'Pallor','Pallor',            'CATEGORICAL', true,  false, ' Pallor of conjunctiva/skin: anaemia/perfusion (HCH2-0003/HCH12-0015).',        15,'active'),
    ('FIN_CLUBBING',      'Clubbing','Clubbing',        'BOOLEAN',     true,  false, ' Digital clubbing: carcinoma, fibrosis, bronchiectasis, abscess (HCH12-0015).', 16,'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 12. finding_phenotype_link — sign value → associated clinical concept (H6 §44)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.finding_phenotype_link
    (observation_concept_code, finding_value, associated_concept_code, strength, description, evidence_claim_code, is_active)
VALUES
    ('OC010','BRONCHIAL_BREATH_SOUNDS','CONSOLIDATION_SIGN',        'strong', ' Bronchial breath sounds indicate pulmonary consolidation (HCH12-0018).',  'HCH12-0018', true),
    ('OC010','WHEEZE',              'WHEEZE_SIGN',                  'strong', ' Wheeze across lung fields: asthma/COPD/infection/cardiac failure (HCH12-0018).', 'HCH12-0018', true),
    ('OC010','CRACKLES',            'CRACKLES_SIGN',                'strong', ' Crackles: fibrosis, cardiac failure, COPD, bronchiectasis (HCH12-0018).',    'HCH12-0018', true),
    ('OC009','PROMINENT_ACCESSORY', 'RESPIRATORY_DISTRESS',         'strong', ' Visible work of breathing implies respiratory distress (HCH12-0014/16).',     'HCH12-0016', true),
    ('OC009','CHYNE_STOKES',        'RESPIRATORY_DISTRESS',         'moderate',' Cheyne-Stokes: severe cardiac/neurological failure (HCH12-0016).',           'HCH12-0016', true),
    ('OC010','CRACKLES',            'PNEUMONIA_SIGN',               'moderate',' Fine late-inspiratory crackles: bronchiectasis/diffuse fibrosis (HCH12-0018).', 'HCH12-0018', true),
    ('OC013','PRESENT',             'CLUBBING_SIGN',                'strong', ' Digital clubbing: bronchus carcinoma, fibrosis, bronchiectasis, abscess (HCH12-0015).','HCH12-0015', true),
    ('OC012','PRESENT',             'JUGULAR_VENOUS_DISTENTION',    'strong', ' Raised JVP: fluid overload / cardiac failure (HCH2-0003 face/neck).',        'HCH2-0003', true),
    ('OC001','SEVERELY_ILL',        'ACUTE_SEVERITY_SIGN',          'strong', ' "Looks severely ill" triggers immediate prioritisation (HCH2-0002).',        'HCH2-0002', true),
    ('OC016','BRUISING',            'BLEEDING_RISK_SIGN',           'moderate',' Thin skin/bruising: possible coagulopathy (HCH12-0015).',                   'HCH12-0015', true),
    ('OC011','TENDERNESS',          'ABDOMINAL_PATHOLOGY_SIGN',     'moderate',' Localised abdominal tenderness localises pathology (HCH2-0004).',            'HCH2-0004', true),
    ('OC015','RESTRICTED',          'FUNCTIONAL_DECLINE_SIGN',      'moderate',' Restricted gait/posture/interaction: functional decline (HCH2-0003).',         'HCH2-0003', true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 13. provenance — Hutchison claims → H6 knowledge objects (H6 §46)
-- Each object gets a 'derived_from' edge to the claim that teaches it. JOINed to
-- the real row id by code so the edge always points at a real row (no offline uuid).
-- ---------------------------------------------------------------------------
-- 13a. examination_concept edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, md5(ec.code)::uuid, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0002','examination_concept','EX001'), ('HCH2-0003','examination_concept','EX001'),
     ('HCH2-0003','examination_concept','EX002'), ('HCH12-0016','examination_concept','EX002'),
     ('HCH2-0003','examination_concept','EX003'),
     ('HCH2-0003','examination_concept','EX004'), ('HCH2-0004','examination_concept','EX004'),
     ('HCH12-0016','examination_concept','EX005'),('HCH12-0014','examination_concept','EX005'),
     ('HCH12-0017','examination_concept','EX005'),('HCH12-0018','examination_concept','EX005'),
     ('HCH12-0015','examination_concept','EX005'),
     ('HCH2-0004','examination_concept','EX006'), ('HCH2-0004','examination_concept','EX007'),
     ('HCH2-0003','examination_concept','EX008'), ('HCH2-0004','examination_concept','EX009')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.examination_concept ec ON ec.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 13b. observation_concept edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, md5(oc.code)::uuid, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0003','observation_concept','OC001'),('HCH2-0003','observation_concept','OC002'),
     ('HCH2-0003','observation_concept','OC003'),('HCH2-0003','observation_concept','OC006'),
     ('HCH12-0016','observation_concept','OC004'),('HCH12-0016','observation_concept','OC005'),
     ('HCH2-0003','observation_concept','OC007'),('HCH2-0003','observation_concept','OC012'),
     ('HCH12-0015','observation_concept','OC013'),('HCH2-0003','observation_concept','OC014'),
     ('HCH2-0003','observation_concept','OC015'),('HCH2-0004','observation_concept','OC016'),
     ('HCH12-0015','observation_concept','OC008'),('HCH12-0014','observation_concept','OC009'),
     ('HCH12-0018','observation_concept','OC010'),('HCH2-0004','observation_concept','OC011')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.observation_concept oc ON oc.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 13c. examination_rule edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, md5(er.rule_code)::uuid, er.rule_code, 'derived_from'
FROM (VALUES
     ('HCH2-0002','examination_rule','ER001'),('HCH2-0003','examination_rule','ER002'),
     ('HCH2-0003','examination_rule','ER003'),('HCH12-0016','examination_rule','ER004'),
     ('HCH2-0003','examination_rule','ER005'),('HCH2-0004','examination_rule','ER006'),
     ('HCH2-0004','examination_rule','ER007'),('HCH2-0004','examination_rule','ER008'),
     ('HCH2-0004','examination_rule','ER009'),('HCH2-0002','examination_rule','ER010'),
     ('HCH2-0002','examination_rule','ER011'),('HCH2-0002','examination_rule','ER012'),
     ('HCH1-0006','examination_rule','ER013'),('HCH2-0003','examination_rule','ER014'),
     ('HCH1-0006','examination_rule','ER015'),('HCH2-0002','examination_rule','ER016'),
     ('HCH2-0003','examination_rule','ER017')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.examination_rule er ON er.rule_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 13d. reference_standard edges (joined by RS code)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, md5(rs.code)::uuid, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH2-0003','reference_standard','RS001'),('HCH2-0003','reference_standard','RS002'),
     ('HCH2-0003','reference_standard','RS003'),('HCH2-0003','reference_standard','RS004'),
     ('HCH2-0003','reference_standard','RS005'),('HCH2-0003','reference_standard','RS006'),
     ('HCH2-0003','reference_standard','RS007'),('HCH2-0003','reference_standard','RS008'),
     ('HCH2-0003','reference_standard','RS009'),('HCH12-0016','reference_standard','RS010'),
     ('HCH2-0003','reference_standard','RS011'),('HCH2-0003','reference_standard','RS012'),
     ('HCH12-0016','reference_standard','RS013'),('HCH12-0016','reference_standard','RS014'),
     ('HCH12-0016','reference_standard','RS015'),('HCH2-0003','reference_standard','RS016')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.reference_standard rs ON rs.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 13e. finding_interpretation edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, md5(x.code)::uuid, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0018','finding_interpretation','FIN_VESICULAR'),('HCH12-0018','finding_interpretation','FIN_BRONCHIAL'),
     ('HCH12-0018','finding_interpretation','FIN_WHEEZE'),   ('HCH12-0018','finding_interpretation','FIN_CRACKLES'),
     ('HCH12-0018','finding_interpretation','FIN_CLEAR'),    ('HCH12-0017','finding_interpretation','FIN_DULLNESS'),
     ('HCH12-0018','finding_interpretation','FIN_TIMPANIC'), ('HCH2-0003','finding_interpretation','FIN_PALLOR'),
     ('HCH12-0015','finding_interpretation','FIN_CLUBBING'), ('HCH2-0003','finding_interpretation','FIN_JVD_ELEVATED')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.finding_interpretation x ON x.code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;

-- 13e. finding_phenotype_link edges
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, v.object_type, fpl.id, v.object_code, 'derived_from'
FROM (VALUES
     ('HCH12-0018','finding_phenotype_link','BRONCHIAL_BREATH_SOUNDS|CONSOLIDATION_SIGN'),
     ('HCH12-0018','finding_phenotype_link','WHEEZE|WHEEZE_SIGN'),
     ('HCH12-0018','finding_phenotype_link','CRACKLES|CRACKLES_SIGN'),
     ('HCH12-0016','finding_phenotype_link','PROMINENT_ACCESSORY|RESPIRATORY_DISTRESS'),
     ('HCH12-0016','finding_phenotype_link','CHYNE_STOKES|RESPIRATORY_DISTRESS'),
     ('HCH12-0018','finding_phenotype_link','CRACKLES|PNEUMONIA_SIGN'),
     ('HCH12-0015','finding_phenotype_link','PRESENT|CLUBBING_SIGN'),
     ('HCH2-0003','finding_phenotype_link','PRESENT|JUGULAR_VENOUS_DISTENTION'),
     ('HCH2-0002','finding_phenotype_link','SEVERELY_ILL|ACUTE_SEVERITY_SIGN'),
     ('HCH12-0015','finding_phenotype_link','BRUISING|BLEEDING_RISK_SIGN'),
     ('HCH2-0004','finding_phenotype_link','TENDERNESS|ABDOMINAL_PATHOLOGY_SIGN'),
     ('HCH2-0003','finding_phenotype_link','RESTRICTED|FUNCTIONAL_DECLINE_SIGN')
) AS v(claim_code, object_type, object_code)
JOIN knowledge.finding_phenotype_link fpl
       ON fpl.observation_concept_code || '|' || fpl.associated_concept_code = v.object_code
JOIN knowledge.source_claim s ON s.claim_code = v.claim_code
  ON CONFLICT DO NOTHING;
