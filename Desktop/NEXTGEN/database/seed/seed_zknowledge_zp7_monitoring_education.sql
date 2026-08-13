-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP7: Phase 1E monitoring targets + education content
-- =============================================================================
-- Monitoring targets prove the system does not stop at diagnosis. Education is
-- reusable content bound to conditions so plans surface teach-back material.
-- =============================================================================

INSERT INTO knowledge.monitoring (id, concept_id, monitoring_code, canonical_name, description,
                                   target_type, unit, body_system_code, normal_low, normal_high) VALUES
   ('f1700000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-00000000002c', 'MON-SPO2',
    'Oxygen saturation', 'Tracks oxygenation trajectory', 'numeric', '%', 'RESPIRATORY', 94, 100),
   ('f1700000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-00000000002d', 'MON-RR',
    'Respiratory rate', 'Tracks respiratory workload', 'numeric', 'breaths/min', 'RESPIRATORY', 12, 20),
   ('f1700000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-00000000002e', 'MON-TEMP',
    'Body temperature', 'Tracks febrile trajectory', 'numeric', 'degC', 'CONSTITUTIONAL', 36.5, 37.5),
   ('f1700000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-00000000002f', 'MON-HR',
    'Heart rate', 'Tracks physiological response', 'numeric', 'beats/min', 'CARDIOVASCULAR', 60, 100),
   ('f1700000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000030', 'MON-WOB',
    'Work of breathing', 'Tracks respiratory effort and deterioration', 'coded', NULL, 'RESPIRATORY', NULL, NULL)
ON CONFLICT (monitoring_code) DO NOTHING;

INSERT INTO knowledge.monitoring_condition (monitoring_id, condition_id, weight, rationale) VALUES
   ('f1700000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1.0, 'Oxygenation essential in pneumonia'),
   ('f1700000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 1.0, 'Respiratory trajectory'),
   ('f1700000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 0.9, 'Febrile trajectory'),
   ('f1700000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 0.8, 'Physiological response'),
   ('f1700000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 1.0, 'Work of breathing deterioration'),
   ('f1700000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000005', 1.0, 'Oxygenation essential in heart failure'),
   ('f1700000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000004', 0.9, 'Work of breathing in acute asthma')
ON CONFLICT (monitoring_id, condition_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Education content
-- ---------------------------------------------------------------------------

INSERT INTO knowledge.education (id, concept_id, education_code, title, audience, content_type,
                                  language_code, literacy_level, body) VALUES
   ('f1800000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000031', 'EDU-CAP-BASICS',
    'Understanding pneumonia', 'patient', 'explanation', 'en', 'plain',
    'Explain what pneumonia means, why symptoms occur, what recovery should look like, and why reassessment matters if the patient worsens.'),
   ('f1800000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000032', 'EDU-CAP-DANGER-SIGNS',
    'Pneumonia danger signs', 'patient', 'warning', 'en', 'plain',
    'Seek urgent clinical review for worsening breathing difficulty, severe weakness, confusion, inability to keep down fluids, or new blueness of lips/fingers.'),
   ('f1800000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000033', 'EDU-CAP-MEDICATION',
    'Taking pneumonia treatment safely', 'patient', 'instruction', 'en', 'plain',
    'Take each prescribed medicine exactly as directed. Report important adverse effects. Do not change or stop the regimen without clinical review.'),
   ('f1800000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-000000000034', 'EDU-CAP-TEACHBACK',
    'Pneumonia teach-back', 'patient', 'teach_back', 'en', 'plain',
    'Ask the patient to explain in their own words what the illness is, what treatment is for, how they will take it and which danger signs require help.'),
   ('f1800000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-000000000035', 'EDU-CAP-CLINICIAN',
    'Pneumonia reasoning summary', 'clinician', 'explanation', 'en', 'professional',
    'The system displays the active evidence, phenotype comparison, uncertainty, investigations selected and reasons, management rationale, monitoring targets and changes over time.')
ON CONFLICT (education_code) DO NOTHING;

INSERT INTO knowledge.education_condition (education_id, condition_id, weight) VALUES
   ('f1800000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f1800000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f1800000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f1800000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f1800000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 1.0),
   ('f1800000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 0.6)
ON CONFLICT (education_id, condition_id) DO NOTHING;
