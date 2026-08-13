-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP5: Phase 1E investigations + examination modules
-- =============================================================================
-- Reusable investigation definitions and structured examination modules.
-- CXR/SpO2/sputum-AFB concepts existed in base seed; this adds the definitions
-- the CPU can order, and the examination modules whose findings become facts.
-- =============================================================================

INSERT INTO knowledge.investigation (id, concept_id, investigation_code, canonical_name, description,
                                     investigation_type, body_system_code, specimen, preparation) VALUES
   ('f1300000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-00000000001f', 'INV-FBC',
    'Full blood count', 'Haemoglobin, leukocyte and platelet assessment', 'laboratory', 'HAEMATOLOGICAL', 'blood', NULL),
   ('f1300000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000020', 'INV-CRP',
    'C-reactive protein', 'Systemic inflammatory marker', 'laboratory', 'IMMUNE', 'blood', NULL),
   ('f1300000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000012', 'INV-CXR',
    'Chest X-ray', 'Radiograph of the chest', 'imaging', 'RESPIRATORY', 'radiographic image', NULL),
   ('f1300000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000014', 'INV-SPO2',
    'Pulse oximetry', 'Non-invasive oxygen saturation', 'physiological', 'RESPIRATORY', 'bedside', NULL),
   ('f1300000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000021', 'INV-UREA-CREAT',
    'Urea and electrolytes', 'Renal function and electrolytes', 'laboratory', 'RENAL_URINARY', 'blood', NULL),
   ('f1300000-0000-0000-0000-000000000006', 'f0a00000-0000-0000-0000-000000000013', 'INV-SPUTUM-AFB',
    'Sputum acid-fast bacilli', 'AFB smear of sputum', 'microbiology', 'RESPIRATORY', 'sputum', 'Early morning sample')
ON CONFLICT (investigation_code) DO NOTHING;

INSERT INTO knowledge.investigation_condition (investigation_id, condition_id, weight, rationale) VALUES
   ('f1300000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 1.0, 'CXR confirms/excludes consolidation'),
   ('f1300000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 0.9, 'Assess oxygenation in suspected pneumonia'),
   ('f1300000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 0.6, 'Support inflammatory/haematological assessment'),
   ('f1300000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 0.5, 'Systemic inflammatory marker'),
   ('f1300000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 0.5, 'Severity/treatment planning in severe CAP'),
   ('f1300000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000002', 1.0, 'Sputum AFB is the key TB test'),
   ('f1300000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000005', 0.9, 'CXR assesses congestion/effusion in heart failure'),
   ('f1300000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000005', 0.7, 'Renal function guides heart failure therapy')
ON CONFLICT (investigation_id, condition_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Examination modules + findings
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.examination_module (id, concept_id, module_code, canonical_name, description, body_system_code, sort_order) VALUES
   ('f1400000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000022', 'EXAM-GENERAL',
    'General examination', 'Initial general clinical assessment (vitals, distress, cyanosis)', 'CONSTITUTIONAL', 10),
   ('f1400000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000023', 'EXAM-RESPIRATORY',
    'Respiratory examination', 'RR, SpO2, percussion, auscultation and work of breathing', 'RESPIRATORY', 20),
   ('f1400000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000024', 'EXAM-CARDIOVASCULAR',
    'Cardiovascular examination', 'HR, JVP, oedema and heart sounds', 'CARDIOVASCULAR', 30),
   ('f1400000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000025', 'EXAM-ABDOMINAL',
    'Abdominal examination', 'Inspection, palpation, percussion and auscultation', 'GASTROINTESTINAL', 40),
   ('f1400000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000026', 'EXAM-NEUROLOGICAL',
    'Neurological examination', 'Level of consciousness, focal deficits', 'NEUROLOGICAL', 50)
ON CONFLICT (module_code) DO NOTHING;

INSERT INTO knowledge.examination_finding (id, module_id, concept_id, finding_code, canonical_name, description,
                                           fact_definition_code, finding_type, sort_order) VALUES
   -- General
   ('f1500000-0000-0000-0000-000000000001', 'f1400000-0000-0000-0000-000000000001', NULL, 'FIND-RESP-DISTRESS',
    'Respiratory distress', 'Increased work of breathing observed', 'RESPIRATORY_DISTRESS', 'sign', 10),
   ('f1500000-0000-0000-0000-000000000002', 'f1400000-0000-0000-0000-000000000001', NULL, 'FIND-CYANOSIS',
    'Cyanosis', 'Central cyanosis', 'CYANOSIS', 'sign', 20),
   ('f1500000-0000-0000-0000-000000000003', 'f1400000-0000-0000-0000-000000000001', NULL, 'FIND-CHEST-INDRAWING',
     'Chest indrawing', 'Subcostal indrawing', 'CHEST_INDRAWING', 'sign', 30),
   ('f1500000-0000-0000-0000-00000000000f', 'f1400000-0000-0000-0000-000000000001', NULL, 'FIND-TEMP',
     'Temperature', 'Core temperature in degrees Celsius', 'TEMPERATURE', 'measurement', 40),
   -- Respiratory
   ('f1500000-0000-0000-0000-000000000004', 'f1400000-0000-0000-0000-000000000002', NULL, 'FIND-RR',
    'Respiratory rate', 'Breaths per minute', 'RESP_RATE', 'measurement', 10),
   ('f1500000-0000-0000-0000-000000000005', 'f1400000-0000-0000-0000-000000000002', NULL, 'FIND-SPO2',
    'Oxygen saturation', 'Peripheral SpO2 percent', 'SPO2', 'measurement', 20),
   ('f1500000-0000-0000-0000-000000000006', 'f1400000-0000-0000-0000-000000000002', NULL, 'FIND-RLL-DULLNESS',
    'Right lower lobe dullness', 'Percussion dullness RLL', 'RLL_DULLNESS', 'sign', 30),
   ('f1500000-0000-0000-0000-000000000007', 'f1400000-0000-0000-0000-000000000002', NULL, 'FIND-RLL-BRONCHIAL',
    'RLL bronchial breath sounds', 'Bronchial breath sounds over right lower lobe', 'RLL_BRONCHIAL_BREATH_SOUNDS', 'sign', 40),
   ('f1500000-0000-0000-0000-000000000008', 'f1400000-0000-0000-0000-000000000002', NULL, 'FIND-CRACKLES',
    'Crackles', 'Crackles on auscultation', 'CRACKLES', 'sign', 50),
   ('f1500000-0000-0000-0000-000000000009', 'f1400000-0000-0000-0000-000000000002', NULL, 'FIND-WHEEZE',
    'Wheeze', 'Wheeze on auscultation', 'WHEEZE_PRESENT', 'sign', 60),
   -- Cardiovascular
   ('f1500000-0000-0000-0000-00000000000a', 'f1400000-0000-0000-0000-000000000003', NULL, 'FIND-HR',
    'Heart rate', 'Beats per minute', 'HEART_RATE', 'measurement', 10),
   ('f1500000-0000-0000-0000-00000000000b', 'f1400000-0000-0000-0000-000000000003', NULL, 'FIND-JVP-ELEVATED',
    'Elevated JVP', 'Elevated jugular venous pressure', NULL, 'sign', 20),
   ('f1500000-0000-0000-0000-00000000000c', 'f1400000-0000-0000-0000-000000000003', NULL, 'FIND-PERIPHERAL-OEDEMA',
    'Peripheral oedema', 'Bilateral peripheral oedema', 'PERIPHERAL_OEDEMA', 'sign', 30),
   -- Abdominal
   ('f1500000-0000-0000-0000-00000000000d', 'f1400000-0000-0000-0000-000000000004', NULL, 'FIND-ABDO-TENDERNESS',
    'Abdominal tenderness', 'Tenderness on palpation', NULL, 'sign', 10),
   -- Neurological
   ('f1500000-0000-0000-0000-00000000000e', 'f1400000-0000-0000-0000-000000000005', NULL, 'FIND-FOCAL-NEURO',
    'Focal neurological deficit', 'Focal deficit on examination', NULL, 'sign', 10)
ON CONFLICT (module_id, finding_code) DO NOTHING;

INSERT INTO knowledge.examination_condition (examination_module_id, condition_id, weight) VALUES
   ('f1400000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f1400000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', 0.9),
   ('f1400000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 0.9),
   ('f1400000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000005', 1.0),
   ('f1400000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000006', 0.7)
ON CONFLICT (examination_module_id, condition_id) DO NOTHING;




