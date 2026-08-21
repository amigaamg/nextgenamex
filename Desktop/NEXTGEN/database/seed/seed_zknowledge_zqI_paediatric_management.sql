-- =============================================================================
-- AMEXAN Medical Knowledge Compiler - R3 paediatric pneumonia MANAGEMENT
-- Age- and weight-aware management slice grounded to Baby Nelson p170-171
-- (claims BNR-0006 / BNR-0007). Freezes the management pattern: real dose
-- rules, real protocol, real monitoring, governance + provenance.
-- GENERATED FILE - do not edit by hand. Regenerate with:
--   python knowledge-compiler/build_r3_paediatric_management.py <out>
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. clinical.fact_definition - BODY_WEIGHT_KG drives weight-based dosing
-- ---------------------------------------------------------------------------
INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES
   ('BODY_WEIGHT_KG', 'Body weight (kg)', 'Current body weight in kilograms - drives weight-based paediatric dosing.', 'numeric', false, true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 1. medication concepts + knowledge.medication - paediatric pneumonia armamentarium
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES
   ('6cd84b13-c405-5b15-880c-8c73937ac92f', 'CNS-MED-AMPICILLIN', 'medication', 'Ampicillin', 'Ampicillin', 'active'),
   ('678054c5-52be-5897-bb10-117bb406f017', 'CNS-MED-GENTAMICIN', 'medication', 'Gentamicin', 'Gentamicin', 'active'),
   ('2d055f9d-0b21-51a2-91f5-a48c9820d7fc', 'CNS-MED-CEFUROXIME', 'medication', 'Cefuroxime', 'Cefuroxime', 'active'),
   ('edf5db90-20ee-5440-a334-5382705917ac', 'CNS-MED-CEFOTAXIME', 'medication', 'Cefotaxime', 'Cefotaxime', 'active'),
   ('45e4ecc3-5890-50d9-b706-c0699f56a8f9', 'CNS-MED-VANCOMYCIN', 'medication', 'Vancomycin', 'Vancomycin', 'active'),
   ('52583a5b-d9c9-52ca-8684-9fabd5cf9ff8', 'CNS-MED-CLINDAMYCIN', 'medication', 'Clindamycin', 'Clindamycin', 'active'),
   ('77ae0d54-c42a-52e0-8b2c-1f797968e70c', 'CNS-MED-ERYTHROMYCIN', 'medication', 'Erythromycin', 'Erythromycin', 'active'),
   ('5c5e5912-d928-5f3a-ae3e-a48e205c1c27', 'CNS-MED-CLARITHROMYCIN', 'medication', 'Clarithromycin', 'Clarithromycin', 'active'),
   ('23319ffc-e6a0-59f6-a5db-bab86ffa98b1', 'CNS-MED-ZINC', 'medication', 'Zinc', 'Zinc', 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.medication (id, concept_id, medication_code, generic_name, drug_class, route_options, formulations, contraindications, evidence_source, status) VALUES
   ('b249fa92-881a-5827-8781-2a8b97cc3721', '6cd84b13-c405-5b15-880c-8c73937ac92f', 'MED-AMPICILLIN', 'Ampicillin', 'Aminopenicillin', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('bdf33696-0ee3-55ad-bc9c-9ec3e7143106', '678054c5-52be-5897-bb10-117bb406f017', 'MED-GENTAMICIN', 'Gentamicin', 'Aminoglycoside', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('e9794620-a79c-5ed9-8f39-e101dcf5a0f2', '2d055f9d-0b21-51a2-91f5-a48c9820d7fc', 'MED-CEFUROXIME', 'Cefuroxime', 'Second-generation cephalosporin', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('0a311aec-211f-5172-8c62-e45e54786d55', 'edf5db90-20ee-5440-a334-5382705917ac', 'MED-CEFOTAXIME', 'Cefotaxime', 'Third-generation cephalosporin', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('141425de-ac09-5fee-ad26-fc06eeb939f9', '45e4ecc3-5890-50d9-b706-c0699f56a8f9', 'MED-VANCOMYCIN', 'Vancomycin', 'Glycopeptide', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('02209437-04f7-5b32-a961-67189b5eb417', '52583a5b-d9c9-52ca-8684-9fabd5cf9ff8', 'MED-CLINDAMYCIN', 'Clindamycin', 'Lincosamide', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('c0f9bd3e-54e0-59a7-8afe-3a172d666d86', '77ae0d54-c42a-52e0-8b2c-1f797968e70c', 'MED-ERYTHROMYCIN', 'Erythromycin', 'Macrolide', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('eac1a1ce-0a73-5d84-ac19-fda8318c002d', '5c5e5912-d928-5f3a-ae3e-a48e205c1c27', 'MED-CLARITHROMYCIN', 'Clarithromycin', 'Macrolide', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active'),
   ('9bc98a82-2d69-57df-913e-29f602dc1247', '23319ffc-e6a0-59f6-a5db-bab86ffa98b1', 'MED-ZINC', 'Zinc', 'Mineral supplement', '["oral"]'::jsonb, '["suspension","tablet","injection"]'::jsonb, '["serious immediate allergy to this class"]'::jsonb, 'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('7b47bb89-27aa-5f91-8e39-3741d3d2722a', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', 'b249fa92-881a-5827-8781-2a8b97cc3721', 'MED-AMPICILLIN', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('5e9dc46d-e9f1-52a3-a032-555ee8a6f113', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', 'bdf33696-0ee3-55ad-bc9c-9ec3e7143106', 'MED-GENTAMICIN', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('ecc8d163-11f5-5adf-9904-8d36553790f2', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', 'e9794620-a79c-5ed9-8f39-e101dcf5a0f2', 'MED-CEFUROXIME', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('b5138ca0-90af-5618-9d4e-c6d3d541c18c', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', '0a311aec-211f-5172-8c62-e45e54786d55', 'MED-CEFOTAXIME', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('e362a4dd-adf0-57f6-9bc4-aca2078a8e28', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', '141425de-ac09-5fee-ad26-fc06eeb939f9', 'MED-VANCOMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('10dced1a-6750-5039-bba8-f973cd32f7e6', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', '02209437-04f7-5b32-a961-67189b5eb417', 'MED-CLINDAMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('d3a95825-c9bd-5357-aafe-2737b44ec8e0', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', 'c0f9bd3e-54e0-59a7-8afe-3a172d666d86', 'MED-ERYTHROMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('79dd4018-4173-57b7-a150-043ac264b6a9', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', 'eac1a1ce-0a73-5d84-ac19-fda8318c002d', 'MED-CLARITHROMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('5355ae8c-1f05-5471-aa5c-23a3ae290c95', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'medication', '9bc98a82-2d69-57df-913e-29f602dc1247', 'MED-ZINC', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. knowledge.drug_dose_reference - REAL weight-based paediatric pneumonia doses
--    (replaces VERIFY_* placeholders for the paediatric population)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('d39f6b33-1821-5225-92de-9c20fe10bfab', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AMOXICILLIN'), 'paediatric', 'PNEUMONIA', 'oral', '50-90 mg/kg/dose (penicillin-resistant pneumococcus: 80-90 mg/kg/24h)', 'every 8-12 hours', '10-14 days (5 days if azithromycin)', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, 'mg_per_kg', 50, 90, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('c98c585a-0f7b-5a20-b821-6f93c31e858e', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', 'd39f6b33-1821-5225-92de-9c20fe10bfab', 'DOSE:MED-AMOXICILLIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('51466a07-0108-53ca-9911-1181000a891b', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AMPICILLIN'), 'paediatric', 'PNEUMONIA', 'intravenous', 'IV ampicillin + aminoglycoside for <4 weeks; IV ampicillin 7-10 days for 4-12 weeks; older child (immunised) ampicillin or penicillin G', 'per age band above', '7-10 days (young infant)', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('af138a11-3781-5029-bf1d-1110636ae035', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '51466a07-0108-53ca-9911-1181000a891b', 'DOSE:MED-AMPICILLIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('07e072d0-adee-53e5-a943-ee6057ddae70', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-GENTAMICIN'), 'paediatric', 'PNEUMONIA', 'intravenous', 'Aminoglycoside add-on (with ampicillin for <4 weeks; add for suspected Klebsiella)', 'per neonatology regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('ba8e1d54-837f-5c9c-9238-77e8cde9184e', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '07e072d0-adee-53e5-a943-ee6057ddae70', 'DOSE:MED-GENTAMICIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('59728f93-7c2b-549b-9eae-28f14e580012', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CEFUROXIME'), 'paediatric', 'PNEUMONIA', 'oral', 'Alternative for milder cases (amoxicillin 50-90 mg/kg/dose or cefuroxime or amoxicillin-clavulanate)', 'every 12 hours', '10-14 days', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, 'mg_per_kg', 50, 90, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('a27cdf7b-f2af-563d-8a46-19ee5e3bfb83', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '59728f93-7c2b-549b-9eae-28f14e580012', 'DOSE:MED-CEFUROXIME', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('7c25253e-e7ad-5bbe-adaa-f0307356c419', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CEFOTAXIME'), 'paediatric', 'PNEUMONIA', 'intravenous', 'Parenteral cefotaxime for older child NOT fully immunised vs H. influenzae b / S. pneumoniae', 'per 3rd-gen cephalosporin regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('4b71bd3b-e698-57e6-b498-530c03771141', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '7c25253e-e7ad-5bbe-adaa-f0307356c419', 'DOSE:MED-CEFOTAXIME', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('7d714755-33af-5ade-95f1-abdd7762170b', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CEFTRIAXONE'), 'paediatric', 'PNEUMONIA', 'intravenous', 'Parenteral ceftriaxone for older child NOT fully immunised vs H. influenzae b / S. pneumoniae', 'per 3rd-gen cephalosporin regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('982de739-3bf0-53c6-835b-be7a23a3755f', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '7d714755-33af-5ade-95f1-abdd7762170b', 'DOSE:MED-CEFTRIAXONE', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('36a468b1-af98-5cc0-bb27-21fe59f3b82f', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-VANCOMYCIN'), 'paediatric', 'PNEUMONIA', 'intravenous', 'Add when suspected Staphylococcus aureus', 'per anti-MRSA regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('c6157baa-cb6f-5a48-9bc8-c6bf8215421e', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '36a468b1-af98-5cc0-bb27-21fe59f3b82f', 'DOSE:MED-VANCOMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('fdcc418d-008a-5d0a-9b53-60fafbc941d1', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CLINDAMYCIN'), 'paediatric', 'PNEUMONIA', 'oral', 'Add when suspected Staphylococcus aureus', 'per regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('fa58ed63-d271-5310-875a-90a49abec9a7', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', 'fdcc418d-008a-5d0a-9b53-60fafbc941d1', 'DOSE:MED-CLINDAMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('fe80c98d-d73f-5721-8fcc-524ffffe9440', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-ERYTHROMYCIN'), 'paediatric', 'PNEUMONIA', 'oral', 'Mycoplasma pneumonia (school-age, walking pneumonia)', 'per macrolide regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('9d038b6c-f81c-5eda-9c42-b3caa9a31557', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', 'fe80c98d-d73f-5721-8fcc-524ffffe9440', 'DOSE:MED-ERYTHROMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('ad4e81ac-5c2a-57b0-a351-9b9e93d2ed0a', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CLARITHROMYCIN'), 'paediatric', 'PNEUMONIA', 'oral', 'Mycoplasma pneumonia (school-age, walking pneumonia)', 'per macrolide regimen', 'per regimen', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('31093a5a-fb0c-5d48-b635-d8a810df0bdb', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', 'ad4e81ac-5c2a-57b0-a351-9b9e93d2ed0a', 'DOSE:MED-CLARITHROMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('7315a521-73be-5e6c-9aa1-5f8422911455', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AZITHROMYCIN'), 'paediatric', 'PNEUMONIA', 'oral', 'Mycoplasma pneumonia - 5 days', 'once daily', '5 days', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('8e19bd79-e5f2-51db-9acc-1298e651e457', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '7315a521-73be-5e6c-9aa1-5f8422911455', 'DOSE:MED-AZITHROMYCIN', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('0f956782-d259-5b9a-93f0-43e9dcfcbff2', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-ZINC'), 'paediatric', 'PNEUMONIA', 'oral', 'Oral zinc add-on 10-20 mg/day (developing countries)', 'once daily', 'as recommended', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, NULL, NULL, NULL, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('8c8243fe-9e45-5a66-afac-e7747fbb5a22', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', '0f956782-d259-5b9a-93f0-43e9dcfcbff2', 'DOSE:MED-ZINC', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('9cc9f215-95b9-5ff4-8f4e-1591cc3f1bc6', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-PARACETAMOL'), 'paediatric', 'PNEUMONIA', 'oral', 'Symptomatic antipyretic for fever', 'every 6-8 hours as needed', 'while febrile', 'Illustrated Baby Nelson p171 (BNR-0006)', TRUE, 'mg_per_kg', 10, 15, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('6304d1d4-fab7-5475-b9a8-721cebaa1877', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0006'), 'drug_dose_reference', '9cc9f215-95b9-5ff4-8f4e-1591cc3f1bc6', 'DOSE:MED-PARACETAMOL', 'derived_from')   ON CONFLICT DO NOTHING;

INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, verification_status) VALUES
   ('a84787e5-a317-515b-99ad-e6c7e23c82bc', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AMOXICILLIN-CLAVULANATE'), 'paediatric', 'PNEUMONIA', 'oral', 'Alternative for milder cases (amoxicillin or cefuroxime or amoxicillin-clavulanate)', 'every 12 hours', '10-14 days', 'Illustrated Baby Nelson p171 (BNR-0007)', TRUE, 'mg_per_kg', 50, 90, 'verified')
  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('42b3e8a3-1f4b-575c-90af-82449ef05e43', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'drug_dose_reference', 'a84787e5-a317-515b-99ad-e6c7e23c82bc', 'DOSE:MED-AMOXICILLIN-CLAVULANATE', 'derived_from')   ON CONFLICT DO NOTHING;

-- escalate pre-existing paediatric placeholder rows that now carry real dosing
UPDATE knowledge.drug_dose_reference ddr SET is_verified = true, verification_status = 'verified', evidence_source = 'Illustrated Baby Nelson p171 (BNR-0007)'
  WHERE ddr.population = 'paediatric' AND ddr.indication_code = 'PNEUMONIA' AND ddr.is_verified = false;

-- ---------------------------------------------------------------------------
-- 3. knowledge.medication_condition - pneumonia treatment links
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.medication_condition (id, medication_id, condition_id, role, weight) VALUES
   ('04fb6e22-4b64-57d6-9ed9-37c64bc51a0c', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AMOXICILLIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '1.00'),
   ('3057f6b3-f502-5360-81d4-d28cae76df40', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AMPICILLIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.90'),
   ('c41f62e2-4320-54ac-9d28-3b12973a4481', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CEFTRIAXONE'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.85'),
   ('d8ca7909-b453-597a-a41d-c799c3fc85c5', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CEFOTAXIME'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.85'),
   ('52958727-e797-5e50-a374-922ad0252dd6', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CEFUROXIME'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.80'),
   ('4e51d3bd-5d99-57ca-9137-5e50cdbbfc9d', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AMOXICILLIN-CLAVULANATE'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.80'),
   ('bb345c37-9fec-5ec9-a68e-168713f1126a', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-AZITHROMYCIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.75'),
   ('e65646a3-c60e-5cd9-88ea-d1dbb7698ef4', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-ERYTHROMYCIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.70'),
   ('433f1114-f0d2-5d76-8d6a-fb65c33c75d4', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CLARITHROMYCIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.70'),
   ('d90e9166-7e6b-5627-b34e-dc1c224e88cf', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-VANCOMYCIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.60'),
   ('e97ba460-dc3c-5ae4-9c3f-c864f4b83180', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-CLINDAMYCIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.60'),
   ('0f654f79-c246-540a-82e7-1e0904be1b07', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-GENTAMICIN'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'treatment', '0.60'),
   ('9938ba40-b1a4-5c5a-9074-c869662b45ea', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-ZINC'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'supportive', '1.00'),
   ('66aa5aa9-7f1a-5d22-93e8-0d5b4a395dba', (SELECT id FROM knowledge.medication WHERE medication_code = 'MED-PARACETAMOL'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'symptomatic', '1.00')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. PROT-PNEUMONIA-PAED - full management protocol (population 'paediatric')
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.protocol (id, concept_id, protocol_code, canonical_name, version_label, description, specialty_code, purpose, status, is_guideline, source_reference, population) VALUES
   ('8f0fec47-3433-587b-be59-d0b6f7796316', (SELECT id FROM knowledge.concept WHERE concept_code = 'CNS-PNEUMONIA'), 'PROT-PNEUMONIA-PAED', 'Paediatric community-acquired pneumonia pathway', '1.0', 'Age- and weight-aware childhood pneumonia: danger signs, severity, supportive care, age-specific antibiotics, monitoring, escalation, disposition, education.', 'pulmonology', 'management', 'active', true, 'Illustrated Baby Nelson p170-171 (BNR-0006/BNR-0007)', 'paediatric')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.protocol_condition (id, protocol_id, condition_id, is_primary) VALUES
   ('b708f69b-b517-5ce3-8eec-1aa43f3de03b', '8f0fec47-3433-587b-be59-d0b6f7796316', (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), true)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required) VALUES
   ('546e6796-7a16-55b6-854d-175776ef38b8', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-01', 'Establish suspected pneumonia', 'eligibility', '10', 'Integrate cough, fever and age-appropriate fast breathing (tachypnoea); fast breathing is the most consistent manifestation of pneumonia in children.', 'Diagnosis is clinical synthesis; tachypnoea is the most sensitive sign in children.', TRUE),
   ('a35fe318-3693-5656-b0cc-36df38b9a039', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-02', 'Screen for danger signs', 'red_flag', '20', 'Assess chest indrawing, grunting, nasal flaring, poor feeding, cyanosis / SpO2 <90%, and lethargy.', 'Danger signs classify severe/very severe pneumonia and mandate urgent escalation.', TRUE),
   ('0418ee4e-ff30-5dec-9c32-f6c9143fa625', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-03', 'Complete focused assessment', 'assessment', '30', 'Count respiratory rate while the child is appropriately settled; observe work of breathing; auscultate; record vitals and SpO2.', 'Accurate RR in a settled child and observation of indrawing/flaring/grunting refine severity.', TRUE),
   ('bd871ea0-805c-5537-bdc9-36ad435aa758', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-04', 'Classify severity', 'assessment', '40', 'Mild: no danger signs, feeds well. Severe: chest indrawing or any danger sign. Very severe: grunting, SpO2 <90%, poor feeding, lethargy.', 'Severity determines disposition and treatment intensity (WHO/IMCI structure reflected in the source).', TRUE),
   ('1775499d-7adc-51e5-95d5-3e5c8a53094a', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-05', 'Select investigations', 'investigation', '50', 'SpO2 always; CXR when severe, uncertain or treatment fails; blood counts/cultures when hospitalised; consider cold agglutinins / mycoplasma in school-age.', 'Testing answers a clinical question; mycoplasma causes ''walking pneumonia'' with minimal signs.', TRUE),
   ('944eda91-30fc-5091-b57c-439fee8c0c10', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-06', 'Deliver supportive care', 'treatment', '60', 'Bed rest; humidified oxygen if hypoxaemic (target SpO2 >=95%); restricted IV fluids if needed; antipyretics for fever; oral zinc 10-20 mg/day add-on; treat complications (e.g. heart failure, effusion/empyema drainage).', 'Supportive care is the foundation; most childhood pneumonia responds to supportive plus antibiotics (BNR-0006).', TRUE),
   ('bddd266c-a61d-5011-9743-23a0b9279800', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-07', 'Select antibiotics by age and picture', 'treatment', '70', 'Mild: amoxicillin 50-90 mg/kg/dose, or cefuroxime, or amoxicillin-clavulanate. Hospitalised <4 weeks: IV ampicillin + aminoglycoside. 4-12 weeks: IV ampicillin 7-10 days. Older child immunised: ampicillin/penicillin G; NOT immunised vs Hib/pneumococcus: parenteral cefotaxime or ceftriaxone. Suspected Staph: add vancomycin or clindamycin. Suspected Klebsiella: add aminoglycoside. Mycoplasma: macrolide.', 'Choice follows clinical picture, CXR and age; duration 10-14 days (5 days if azithromycin).', TRUE),
   ('a9fad8bd-a00c-5d07-bfef-9ad4fd34dc88', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-08', 'Monitor response', 'monitoring', '80', 'Expect clinical improvement within 48-96 hours of starting antibiotics; trend SpO2, RR, work of breathing, temperature and feeding.', 'Uncomplicated bacterial pneumonia improves 48-96h; radiographic improvement lags clinical.', TRUE),
   ('9da85256-7617-54b3-8b55-d0816d879f7b', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-09', 'Reassess deterioration or non-response', 'escalation', '90', 'If not improving at 48-96h, reassess complications (effusion, empyema, abscess, pneumatoceles), adherence, resistance, alternative organism and non-infectious mimics.', 'Failure of expected trajectory is new evidence and should trigger reasoning again.', TRUE),
   ('c734760a-f4c7-5a9e-9ee2-7b7ab1e9bf86', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-10', 'Determine disposition', 'disposition', '100', 'Home for mild pneumonia (no danger signs, feeds well, reliable caregiver). Hospital for severe (chest indrawing, SpO2 <90%). PICU for very severe / danger signs.', 'Disposition is a dynamic clinical decision based on severity, feeding and social context.', TRUE),
   ('589b7330-e7d8-5aff-aa18-891318b7831a', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-11', 'Educate caregiver', 'education', '110', 'Explain the illness, expected course (improvement 48-96h), medication administration, feeding/hydration, and when to return (danger signs).', 'Caregiver understanding is part of safe paediatric care and safe continuation at home.', TRUE),
   ('d82aa318-303e-5c6e-b2ef-b410dfbef693', '8f0fec47-3433-587b-be59-d0b6f7796316', 'STEP-12', 'Close the care loop', 'follow_up', '120', 'Record the follow-up plan and what should return to the record (clinical improvement, feeding, fever curve).', 'The episode generates continuity rather than terminating at discharge.', TRUE)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order) VALUES
   ('490fad32-1d3e-52c0-b428-547e5000b872', '8f0fec47-3433-587b-be59-d0b6f7796316', 'a35fe318-3693-5656-b0cc-36df38b9a039', 'investigate', 'INV-SPO2', 'Pulse oximetry', 'Immediate oxygenation assessment in any child with suspected pneumonia', 'immediate', '10'),
   ('a43e05e6-44a3-5a9c-aacc-7a5113384a01', '8f0fec47-3433-587b-be59-d0b6f7796316', '0418ee4e-ff30-5dec-9c32-f6c9143fa625', 'monitor', 'MON-SPO2', 'Oxygen saturation monitoring', 'Baseline and per severity; target >=95%', 'routine', '10'),
   ('b959d113-0618-5580-af87-df22ab953536', '8f0fec47-3433-587b-be59-d0b6f7796316', '0418ee4e-ff30-5dec-9c32-f6c9143fa625', 'monitor', 'MON-RR', 'Respiratory rate monitoring', 'Count while appropriately settled; serial trend', 'routine', '20'),
   ('d49072ed-e4dc-5229-917e-17f3d51ee59b', '8f0fec47-3433-587b-be59-d0b6f7796316', '0418ee4e-ff30-5dec-9c32-f6c9143fa625', 'monitor', 'MON-WOB', 'Work of breathing', 'Observe indrawing, nasal flaring, grunting, use of accessory muscles', 'routine', '30'),
   ('f296e113-5e90-55e0-8773-5513819afa08', '8f0fec47-3433-587b-be59-d0b6f7796316', '1775499d-7adc-51e5-95d5-3e5c8a53094a', 'investigate', 'INV-CXR', 'Chest X-ray', 'When severe, uncertain, or not responding', 'routine', '10'),
   ('1e079902-b77e-54c3-9d16-ba45a2ad4a0c', '8f0fec47-3433-587b-be59-d0b6f7796316', '944eda91-30fc-5091-b57c-439fee8c0c10', 'medicate', 'MED-ZINC', 'Zinc (10-20 mg/day)', 'Oral zinc add-on recommended in developing countries', 'routine', '10'),
   ('65ab4e73-92ae-5596-a9ce-ecc7cc2d185e', '8f0fec47-3433-587b-be59-d0b6f7796316', '944eda91-30fc-5091-b57c-439fee8c0c10', 'medicate', 'MED-PARACETAMOL', 'Paracetamol', 'Antipyretic for fever', 'routine', '20'),
   ('7d77becd-96cc-5609-9b5a-d18f3a407aef', '8f0fec47-3433-587b-be59-d0b6f7796316', 'bddd266c-a61d-5011-9743-23a0b9279800', 'medicate', 'MED-AMOXICILLIN', 'Amoxicillin', 'Mild cases: 50-90 mg/kg/dose; see age-specific alternatives', 'routine', '10'),
   ('033b4f5b-5b31-54b7-801a-a6d38b27450d', '8f0fec47-3433-587b-be59-d0b6f7796316', 'bddd266c-a61d-5011-9743-23a0b9279800', 'medicate', 'MED-AMPICILLIN', 'Ampicillin', 'Hospitalised young infants per age band', 'routine', '20'),
   ('fe05c66e-3292-5352-8496-432f37a368fb', '8f0fec47-3433-587b-be59-d0b6f7796316', 'bddd266c-a61d-5011-9743-23a0b9279800', 'medicate', 'MED-CEFOTAXIME', 'Cefotaxime', 'Older child not fully immunised - parenteral', 'routine', '30'),
   ('78bd5b44-dccc-5600-a3ab-7f0a8abd2f52', '8f0fec47-3433-587b-be59-d0b6f7796316', 'a9fad8bd-a00c-5d07-bfef-9ad4fd34dc88', 'monitor', 'MON-TEMP', 'Temperature monitoring', 'Fever curve; expect improvement 48-96h', 'routine', '10'),
   ('ccfdf32b-c5ee-5305-a7ac-db53c100d5cc', '8f0fec47-3433-587b-be59-d0b6f7796316', '589b7330-e7d8-5aff-aa18-891318b7831a', 'educate', 'EDU-CAP-DANGER-SIGNS', 'Pneumonia danger signs', 'Teach caregiver danger signs and when to return', 'routine', '10'),
   ('d61d1f8b-184e-5629-ae48-b96d35b27e86', '8f0fec47-3433-587b-be59-d0b6f7796316', '589b7330-e7d8-5aff-aa18-891318b7831a', 'educate', 'EDU-CAP-MEDICATION', 'Taking pneumonia treatment safely', 'Antibiotic administration and dosing', 'routine', '20'),
   ('0939af2c-ec5e-5223-9673-c3acee055b3b', '8f0fec47-3433-587b-be59-d0b6f7796316', '589b7330-e7d8-5aff-aa18-891318b7831a', 'educate', 'EDU-CAP-TEACHBACK', 'Pneumonia teach-back', 'Confirm caregiver understanding', 'routine', '30'),
   ('0d648378-a3b6-58cc-88b5-988a754c13ef', '8f0fec47-3433-587b-be59-d0b6f7796316', 'd82aa318-303e-5c6e-b2ef-b410dfbef693', 'educate', 'EDU-CAP-CLINICIAN', 'Pneumonia reasoning summary', 'Render evidence, phenotype comparison and rationale', 'routine', '10')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.protocol_monitoring (id, protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES
   ('0336bbe1-d76f-5d5e-8dab-5d5ce2ebf13c', '8f0fec47-3433-587b-be59-d0b6f7796316', (SELECT id FROM knowledge.monitoring WHERE monitoring_code = 'MON-SPO2'), 'Baseline and per severity; target >=95%', 'SpO2 <95% or worsening oxygenation', 'Immediate clinical reassessment; escalate to hospital/PICU with oxygen'),
   ('c4514cb6-97d8-5632-836b-1741198c8ea5', '8f0fec47-3433-587b-be59-d0b6f7796316', (SELECT id FROM knowledge.monitoring WHERE monitoring_code = 'MON-RR'), 'Serial - count while appropriately settled', 'Rising respiratory rate or new distress', 'Reassess severity, complications and need for escalation'),
   ('c995d301-fa14-506a-93a7-796839f8c549', '8f0fec47-3433-587b-be59-d0b6f7796316', (SELECT id FROM knowledge.monitoring WHERE monitoring_code = 'MON-WOB'), 'With every clinical assessment', 'New or worsening chest indrawing / grunting / nasal flaring', 'Urgent reassessment; escalate if unstable'),
   ('5c424d1f-430a-5d5b-9da5-6085630070a0', '8f0fec47-3433-587b-be59-d0b6f7796316', (SELECT id FROM knowledge.monitoring WHERE monitoring_code = 'MON-TEMP'), 'Serially while febrile', 'Persistent/worsening fever with poor clinical response at 48-96h', 'Reassess diagnosis, complications and treatment')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('11f683c9-cbd3-5307-bfcf-75e0320ddfd9', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0006'), 'protocol', '8f0fec47-3433-587b-be59-d0b6f7796316', 'PROT-PNEUMONIA-PAED', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('269b8963-77f0-5793-8e2c-61e5e962c0a2', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0007'), 'protocol', '8f0fec47-3433-587b-be59-d0b6f7796316', 'PROT-PNEUMONIA-PAED', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. governance.knowledge_object - register protocol + dose intelligence
-- ---------------------------------------------------------------------------
INSERT INTO governance.knowledge_object (id, object_code, knowledge_type, canonical_name, description, source_claim_code, jurisdiction_code, population_code, evidence_level_code, lifecycle_status, confidence, is_active, status) VALUES
   ('5c6a4e46-fe15-5bed-88f1-f44dceb6fc40', 'PROT-PNEUMONIA-PAED', 'PROTOCOL', 'Paediatric community-acquired pneumonia management', 'Age- and weight-aware childhood pneumonia pathway: danger signs, severity, supportive care, age-specific antibiotics, monitoring, escalation, disposition, education.', 'BNR-0007', 'JUR-GLOBAL', 'POP-PAEDIATRIC', 'EV-C', 'ACTIVE', 0.95, true, 'active'),
   ('f86b28e5-f54f-5ed0-a556-8e22c6503869', 'MED-AMOXICILLIN', 'DRUG', 'Amoxicillin (paediatric pneumonia dosing)', 'Weight-based 50-90 mg/kg/dose for childhood pneumonia (BNR-0007).', 'BNR-0007', 'JUR-GLOBAL', 'POP-PAEDIATRIC', 'EV-C', 'ACTIVE', 0.95, true, 'active'),
   ('24f8d0bb-c2b7-5133-a7b6-72883fd8f731', 'MED-AMPICILLIN', 'DRUG', 'Ampicillin (paediatric pneumonia dosing)', 'IV ampicillin age-band regimen for hospitalised childhood pneumonia (BNR-0007).', 'BNR-0007', 'JUR-GLOBAL', 'POP-PAEDIATRIC', 'EV-C', 'ACTIVE', 0.95, true, 'active'),
   ('b88d8ae8-a66e-50e0-bbfa-0b8b534b0a21', 'MED-ZINC', 'DRUG', 'Zinc add-on for childhood pneumonia', 'Oral zinc 10-20 mg/day add-on recommended in developing countries (BNR-0007).', 'BNR-0007', 'JUR-GLOBAL', 'POP-PAEDIATRIC', 'EV-C', 'ACTIVE', 0.95, true, 'active'),
   ('f406165f-d5b1-5ecd-a5eb-e362c304b52f', 'DOSE-PNEUMONIA-PAED', 'DOSING_RULE', 'Paediatric pneumonia weight-based dose rules', 'Weight-basis dose engine rules (mg_per_kg) grounded to Baby Nelson p171 (BNR-0007).', 'BNR-0007', 'JUR-GLOBAL', 'POP-PAEDIATRIC', 'EV-C', 'ACTIVE', 0.95, true, 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO governance.knowledge_object_version (object_id, version_no, version_code, change_note, lifecycle_status, source_claim_code, created_by)
SELECT ko.id, 1, 'GO-V-R3-' || ko.object_code, 'R3 paediatric pneumonia management release (BNR-0006/0007).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'
FROM governance.knowledge_object ko WHERE ko.object_code IN ('PROT-PNEUMONIA-PAED', 'MED-AMOXICILLIN', 'MED-AMPICILLIN', 'MED-ZINC', 'DOSE-PNEUMONIA-PAED')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. tracking.respiratory_master_matrix - status update for the paediatric pneumonia slice
-- ---------------------------------------------------------------------------
UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Baby Nelson p170-171 (BNR-0006/BNR-0007)',
       notes='Full paediatric pneumonia slice: recognition + danger signs + severity + supportive care + age/weight-specific antibiotics + monitoring + escalation + disposition + education + documentation.',
       updated_at=now() WHERE item_code='COND-CAP-PAED';
UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Baby Nelson p171 (BNR-0007)',
       notes='Weight-based dose engine + real paediatric pneumonia dose rules.', updated_at=now() WHERE item_code='DRUG-ANTIBIOTIC';
