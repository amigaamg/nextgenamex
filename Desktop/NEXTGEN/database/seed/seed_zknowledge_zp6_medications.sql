-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP6: Phase 1E medication intelligence + dose references
-- =============================================================================
-- Drugs are reusable intelligence referenced by protocols. Dose rows carry
-- VERIFY_* placeholders (is_verified=false) â€” the schema is the deliverable;
-- jurisdiction-specific dosing must be clinically approved before production.
-- =============================================================================

INSERT INTO knowledge.medication (id, concept_id, medication_code, generic_name, drug_class,
                                   route_options, formulations, contraindications,
                                   renal_adjustment_notes, hepatic_adjustment_notes,
                                   pregnancy_notes, lactation_notes, evidence_source) VALUES
   ('f1600000-0000-0000-0000-000000000001', 'f0a00000-0000-0000-0000-000000000027', 'MED-AMOXICILLIN',
    'Amoxicillin', 'Aminopenicillin',
    '["oral","parenteral"]'::jsonb, '["tablet","capsule","suspension"]'::jsonb,
    '["serious immediate beta-lactam allergy"]'::jsonb,
    'Use verified renal-adjustment guidance.',
    'Use current hepatic-safety guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Verified formulary/CPG source required before production use.'),

   ('f1600000-0000-0000-0000-000000000002', 'f0a00000-0000-0000-0000-000000000028', 'MED-AMOXICILLIN-CLAVULANATE',
    'Amoxicillin/clavulanate', 'Beta-lactam/beta-lactamase inhibitor',
    '["oral","parenteral"]'::jsonb, '["tablet","suspension","injection"]'::jsonb,
    '["serious immediate beta-lactam allergy","previous cholestatic/hepatic reaction to this drug"]'::jsonb,
    'Use verified renal-adjustment guidance.',
    'Use current hepatic-safety guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Verified formulary/CPG source required before production use.'),

   ('f1600000-0000-0000-0000-000000000003', 'f0a00000-0000-0000-0000-000000000029', 'MED-CEFTRIAXONE',
    'Ceftriaxone', 'Third-generation cephalosporin',
    '["intravenous","intramuscular"]'::jsonb, '["injection"]'::jsonb,
    '["serious immediate beta-lactam allergy"]'::jsonb,
    'Use current renal guidance, especially with combined renal/hepatic impairment.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Verified formulary/CPG source required before production use.'),

   ('f1600000-0000-0000-0000-000000000004', 'f0a00000-0000-0000-0000-00000000002a', 'MED-AZITHROMYCIN',
    'Azithromycin', 'Macrolide',
    '["oral","intravenous"]'::jsonb, '["tablet","suspension","injection"]'::jsonb,
    '["macrolide allergy","important QT-risk context"]'::jsonb,
    'Use current renal guidance.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Verified formulary/CPG source required before production use.'),

   ('f1600000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-00000000002b', 'MED-PARACETAMOL',
    'Paracetamol', 'Analgesic / antipyretic',
    '["oral","intravenous","rectal"]'::jsonb, '["tablet","suspension","injection","suppository"]'::jsonb,
    '["severe hepatic disease without specialist guidance"]'::jsonb,
    'Use current guidance for severe renal impairment.',
    'Use current maximum-dose guidance in hepatic disease.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Verified formulary/CPG source required before production use.')
ON CONFLICT (medication_code) DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (medication_id, population, indication_code, route,
                                           dose_expression, frequency_expression, duration_expression, is_verified) VALUES
   ('f1600000-0000-0000-0000-000000000001', 'adult', 'PNEUMONIA', 'oral',
    'VERIFY_CURRENT_CAP_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000001', 'paediatric', 'PNEUMONIA', 'oral',
    'VERIFY_WEIGHT_BASED_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000002', 'adult', 'PNEUMONIA', 'oral',
    'VERIFY_CURRENT_CAP_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000003', 'adult', 'PNEUMONIA', 'intravenous',
    'VERIFY_CURRENT_CAP_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000003', 'paediatric', 'PNEUMONIA', 'intravenous',
    'VERIFY_WEIGHT_BASED_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000004', 'adult', 'PNEUMONIA', 'oral',
    'VERIFY_CURRENT_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000005', 'adult', 'PNEUMONIA', 'oral',
    'VERIFY_CURRENT_WEIGHT_OR_ADULT_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false),
   ('f1600000-0000-0000-0000-000000000005', 'paediatric', 'PNEUMONIA', 'oral',
    'VERIFY_WEIGHT_BASED_REGIMEN', 'VERIFY_FREQUENCY', 'VERIFY_DURATION', false)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.medication_condition (medication_id, condition_id, role, weight) VALUES
   ('f1600000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'treatment', 1.0),
   ('f1600000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 'treatment', 0.9),
   ('f1600000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 'treatment', 0.8),
   ('f1600000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 'treatment', 0.7),
   ('f1600000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 'symptomatic', 1.0)
ON CONFLICT DO NOTHING;
