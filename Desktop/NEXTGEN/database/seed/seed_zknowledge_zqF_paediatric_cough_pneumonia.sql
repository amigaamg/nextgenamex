-- =============================================================================
-- AMEXAN Medical Knowledge Compiler - R2 paediatric COUGH + pneumonia seed
-- Paediatric overlay on the universal COUGH graph + PNEUMONIA slice.
-- Grounds every object to the R1 respiratory claims (KCR/BNR) via provenance.
-- GENERATED FILE - do not edit by hand. Regenerate with:
--   python knowledge-compiler/build_r2_paediatric.py <out>
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. clinical.fact_definition - paediatric danger-sign facts (boolean)
-- ---------------------------------------------------------------------------
INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES
   ('FAST_BREATHING', 'Fast breathing (tachypnoea)', 'Child breathes much faster than usual for age; the most consistent clinical manifestation of pneumonia in children.', 'boolean', false, true),
   ('GRUNTING', 'Grunting with respiration', 'Audible grunting at the end of each breath, a sign of respiratory distress in children.', 'boolean', false, true),
   ('NASAL_FLARING', 'Nasal flaring', 'Flaring of the nostrils with breathing, a sign of respiratory distress in children.', 'boolean', false, true),
   ('POOR_FEEDING', 'Poor feeding / reduced intake', 'Child feeds poorly or refuses feeds, a danger signal in severe childhood illness.', 'boolean', false, true)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('08d88d86-d55c-56f6-98a5-c106ee516c86', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_definition', '6a962832-6997-5a69-ac1c-9cd532188a46', 'FAST_BREATHING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('fdef89ff-e7d0-5aed-9548-72b57f46a91f', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_definition', 'f8e6362b-6071-5453-b76c-5ad6c7d2004f', 'GRUNTING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('2fac11e6-09c1-5385-a553-a108db7927de', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_definition', '91f613c1-b1de-5fdc-a02a-db81e26a25fe', 'NASAL_FLARING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('8db8c877-1455-5c61-8109-a0f61d43f4fd', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_definition', 'db7f8e0f-b61b-5407-a70b-3753f8722480', 'POOR_FEEDING', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. knowledge.question_variant - paediatric wordings for universal cough questions
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_variant (id, question_id, context, language_code, wording, is_active, response_mode, historian_type, priority_delta, is_disabled) VALUES
   ('d17febee-60a2-560d-b1b1-48d1cd45da79', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_PRODUCTIVITY'), 'child', 'en', 'Is the cough wet (brings up phlegm or mucus) or dry?', true, 'CAREGIVER_REPORT', 'PARENT', 0, false),
   ('331df267-c10e-5aa6-88e6-6c18f4271b33', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_PRODUCTIVITY'), 'infant', 'en', 'Is the cough rattly and chesty, or dry and hacking?', true, 'CAREGIVER_REPORT', 'CAREGIVER', 0, false),
   ('cdfcec70-e7d1-5f11-81bc-b9f7355a6b5b', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_CHARACTER'), 'child', 'en', 'What does the cough sound like?', true, 'CAREGIVER_REPORT', 'PARENT', 0, false),
   ('d45793f3-eb9e-5ead-94e5-3d6c40360d1d', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_TRIGGERS'), 'child', 'en', 'What makes the cough worse - running, feeding, or lying down?', true, 'CAREGIVER_REPORT', 'PARENT', 0, false),
   ('efa0ab7c-da71-5487-9c05-17470ba27aac', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_TIMING'), 'child', 'en', 'Is the cough worse at night or first thing in the morning?', true, 'CAREGIVER_REPORT', 'PARENT', 0, false),
   ('d384dacc-2de2-5ae4-94df-4d6d71ed917c', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_SEVERITY'), 'child', 'en', 'How much is the cough bothering the child?', true, 'CAREGIVER_REPORT', 'PARENT', 0, false),
   ('78030eff-8120-5de3-9693-49a26d40674c', (SELECT id FROM knowledge.question WHERE question_code = 'COUGH_SEVERITY'), 'infant', 'en', 'Does the cough stop the baby from feeding or sleeping?', true, 'CAREGIVER_REPORT', 'CAREGIVER', 0, false)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('2c325d8f-83f9-5f16-b197-79be07c03631', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', 'd17febee-60a2-560d-b1b1-48d1cd45da79', 'COUGH_PRODUCTIVITY:child', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('8a78056a-e001-5940-807a-642e19c5a60c', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', '331df267-c10e-5aa6-88e6-6c18f4271b33', 'COUGH_PRODUCTIVITY:infant', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('8fe5f055-f492-564b-b696-7a653d6d65c4', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', 'cdfcec70-e7d1-5f11-81bc-b9f7355a6b5b', 'COUGH_CHARACTER:child', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('70223cba-9182-56ea-843c-a56b3e2e60cd', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', 'd45793f3-eb9e-5ead-94e5-3d6c40360d1d', 'COUGH_TRIGGERS:child', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('31091388-febe-5856-8db0-0f7dc90a8aee', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', 'efa0ab7c-da71-5487-9c05-17470ba27aac', 'COUGH_TIMING:child', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('390c69c7-e265-5bfd-9efc-fb85a89cdd14', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', 'd384dacc-2de2-5ae4-94df-4d6d71ed917c', 'COUGH_SEVERITY:child', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('c6201475-8dce-541c-8d25-2ae6e0ea2bd7', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'question_variant', '78030eff-8120-5de3-9693-49a26d40674c', 'COUGH_SEVERITY:infant', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. knowledge.context_fact_mapping - lay/observed paediatric expressions -> canonical facts
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.context_fact_mapping (mapping_code, context_code, raw_expression, target_type, target_code, canonical_value, strength, description, status) VALUES
   ('CFM-PAED-001', 'CHILD', 'wet cough', 'fact_definition', 'COUGH_PRODUCTIVITY', 'PRODUCTIVE', 'strong', 'Paediatric capture of canonical fact COUGH_PRODUCTIVITY', 'active'),
   ('CFM-PAED-002', 'INFANT', 'rattly chest', 'fact_definition', 'COUGH_PRODUCTIVITY', 'PRODUCTIVE', 'strong', 'Paediatric capture of canonical fact COUGH_PRODUCTIVITY', 'active'),
   ('CFM-PAED-003', 'CHILD', 'cough brings up phlegm', 'fact_definition', 'COUGH_PRODUCTIVITY', 'PRODUCTIVE', 'strong', 'Paediatric capture of canonical fact COUGH_PRODUCTIVITY', 'active'),
   ('CFM-PAED-004', 'CHILD', 'dry hacking cough', 'fact_definition', 'COUGH_PRODUCTIVITY', 'NON_PRODUCTIVE', 'moderate', 'Paediatric capture of canonical fact COUGH_PRODUCTIVITY', 'active'),
   ('CFM-PAED-005', 'INFANT', 'chest pulls in when breathing', 'fact_definition', 'CHEST_INDRAWING', 'true', 'strong', 'Paediatric capture of canonical fact CHEST_INDRAWING', 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('9cb2c53a-15ac-5203-be5c-7e74ddde8804', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'context_fact_mapping', '3c6f701f-22e6-5508-bd8c-e6a194458225', 'CFM-PAED-001', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('6694f101-be72-5562-baea-4e9422d7581e', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'context_fact_mapping', 'c748c7f3-ecdb-5468-97d1-2644ee58f119', 'CFM-PAED-002', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('384e2985-ff29-5039-afdd-829d48cd4c01', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'context_fact_mapping', '61fdc33c-2c7d-55b2-9479-b15843b9adc5', 'CFM-PAED-003', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('5146313a-dac6-520d-8e55-f4fbd93106c5', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'context_fact_mapping', '64e673cf-6fff-54df-bd72-e150e6fd8a02', 'CFM-PAED-004', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('dfa34d00-da81-5d72-94b3-bef353e55391', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'context_fact_mapping', '7eb246b1-8221-5ef5-b841-c486c00f78fd', 'CFM-PAED-005', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. knowledge.fact_provenance - CAREGIVER_REPORTED / PARENT lawful capture of cough + danger facts
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.fact_provenance (fact_definition_code, capture_method_code, historian_type_code, min_reliability_code, is_valid, evidence_claim_code) VALUES
   ('COUGH_PRODUCTIVITY', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0002'),
   ('COUGH_CHARACTER', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0002'),
   ('COUGH_TRIGGERS', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0002'),
   ('COUGH_TIMING', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0002'),
   ('COUGH_SEVERITY', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0002'),
   ('SPUTUM_COLOUR', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'KCR-0001'),
   ('GRUNTING', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0003'),
   ('NASAL_FLARING', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0003'),
   ('FAST_BREATHING', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0003'),
   ('POOR_FEEDING', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0004'),
   ('CHEST_INDRAWING', 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, 'BNR-0003')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('094d08d8-2f91-5ccb-b97f-e2a762af2438', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'fact_provenance', '27eefc8a-040f-5a33-a077-53e10b3970cd', 'COUGH_PRODUCTIVITY', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('b77f7867-63ea-5767-83f6-e692ad89bde7', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'fact_provenance', 'cad9ade7-1630-5ecd-a3d2-9b6a0d192fd3', 'COUGH_CHARACTER', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('3e4ccf32-b7dd-5d09-a72c-b44972640ff5', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'fact_provenance', '9c11a2f7-af3d-5583-8612-4ebba14fa731', 'COUGH_TRIGGERS', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('4fc5f4d8-d454-5abf-8b9f-5b1bfbae98bc', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'fact_provenance', '2090c199-dddc-5886-af70-6b6736fa6046', 'COUGH_TIMING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('21f24ae3-3679-5014-a8fa-8b039ffc1e28', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0002'), 'fact_provenance', '0fb760ae-f4e8-5e18-a8cc-edb151b47a17', 'COUGH_SEVERITY', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('c497c6a9-f9d9-5f0b-b0f8-0d2384f13083', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'KCR-0001'), 'fact_provenance', '35dfd715-abfa-5641-99ec-f0070a474581', 'SPUTUM_COLOUR', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('94bd20cc-0308-5097-9c6d-f02aa4273313', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_provenance', 'a7086637-eb1d-5b95-a2ad-c36871f9a991', 'GRUNTING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('f74a3cd5-91af-5e88-95e7-4ba7e2e7f32d', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_provenance', '6269ef1f-68c7-5402-98a1-979cb29b18a4', 'NASAL_FLARING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('9e7249d3-719f-5199-98ee-dd91d8975cca', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_provenance', '38b717a3-7854-51d6-97c6-9fb1eb5918a7', 'FAST_BREATHING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('8a8cae90-b145-5ea1-ae0a-1be7dd665630', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0004'), 'fact_provenance', 'a241bdde-5f22-51d1-90e3-4c59094d5752', 'POOR_FEEDING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('ba923be8-4c7f-5602-a253-d2d80d9b49a6', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'fact_provenance', '3bccb991-8d55-5c14-9a02-df1f5d3d7d8e', 'CHEST_INDRAWING', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. PAEDIATRIC_DANGER_SIGNS module (child-only, adult-excluded)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_module (module_code, module_name, description, status) VALUES
   ('PAEDIATRIC_DANGER_SIGNS', 'Paediatric danger signs', 'Child-only severe-disease recognition questions (fast breathing, chest indrawing, grunting, nasal flaring, poor feeding).', 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question (id, question_code, question_type, text, response_type, priority, is_active, question_mode) VALUES
   ('a6488276-b076-558e-92c0-5aa587daaa3a', 'PAEDIATRIC_CHEST_INDRAWING', 'clinical', 'Is there chest indrawing (ribs or tummy pulling in with each breath)?', 'single_choice', 45, true, 'DIRECT'),
   ('eae3f6ea-2e7a-5f37-ab93-19a83978f89f', 'PAEDIATRIC_GRUNTING', 'clinical', 'Is the child grunting with each breath?', 'single_choice', 45, true, 'DIRECT'),
   ('29969109-d24d-5200-9c6b-ab9167d3183c', 'PAEDIATRIC_NASAL_FLARING', 'clinical', 'Are the nostrils flaring when the child breathes?', 'single_choice', 45, true, 'DIRECT'),
   ('ad56ca5b-ee5b-5b94-adf0-1a008b22911b', 'PAEDIATRIC_FAST_BREATHING', 'clinical', 'Is the child breathing much faster than usual for their age?', 'single_choice', 45, true, 'DIRECT'),
   ('9c629153-df72-50f5-9f31-34c7e72fa58a', 'PAEDIATRIC_POOR_FEEDING', 'clinical', 'Is the child feeding poorly or refusing feeds?', 'single_choice', 45, true, 'DIRECT')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, sort_order, is_active) VALUES
   ('4afc28ab-e650-5d3f-9150-39000c76c327', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING'), 'YES', 'Yes', 1, true),
   ('58bb3f66-dbd9-5800-948e-ca13393880a2', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING'), 'NO', 'No', 2, true),
   ('9198ae37-b2bb-59fc-b7c3-9261c270ce8e', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING'), 'YES', 'Yes', 1, true),
   ('e8040135-873b-5e2c-bf17-d580b3817810', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING'), 'NO', 'No', 2, true),
   ('5fdaa8f2-2561-5f92-a196-7270b3dbd1fb', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING'), 'YES', 'Yes', 1, true),
   ('ddb63231-928b-5e5a-9b4d-7eb223dd4e20', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING'), 'NO', 'No', 2, true),
   ('b6c62b17-5152-592b-a15f-bdaef7a3fa4e', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING'), 'YES', 'Yes', 1, true),
   ('05ca4010-db97-50ca-831c-9f7e49340341', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING'), 'NO', 'No', 2, true),
   ('c94290c6-0d07-5b74-86a1-3dadff4a5318', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'), 'YES', 'Yes', 1, true),
   ('83c0d61a-e3ac-5949-b10f-232fac14382b', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'), 'NO', 'No', 2, true)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.fact_mapping (id, answer_option_id, fact_definition_code, value, is_active) VALUES
   ('31d792c4-e42f-5e11-91b8-4318a97f596a', '4afc28ab-e650-5d3f-9150-39000c76c327', 'CHEST_INDRAWING', 'true', true),
   ('7a5e3f81-b882-5394-99d4-a80adaea5011', '58bb3f66-dbd9-5800-948e-ca13393880a2', 'CHEST_INDRAWING', 'false', true),
   ('ce51a806-6f2c-5127-80b9-68dbb5f53c93', '9198ae37-b2bb-59fc-b7c3-9261c270ce8e', 'GRUNTING', 'true', true),
   ('9dfdcbb4-3632-5e2d-a229-6a43ff3e57c0', 'e8040135-873b-5e2c-bf17-d580b3817810', 'GRUNTING', 'false', true),
   ('19990aad-ebaf-5ccc-9e6d-6e4d274f764a', '5fdaa8f2-2561-5f92-a196-7270b3dbd1fb', 'NASAL_FLARING', 'true', true),
   ('fd8f8114-7388-51b2-a9d9-7aba9d4106af', 'ddb63231-928b-5e5a-9b4d-7eb223dd4e20', 'NASAL_FLARING', 'false', true),
   ('576c0fe6-7080-54a4-b296-a98e03c20aba', 'b6c62b17-5152-592b-a15f-bdaef7a3fa4e', 'FAST_BREATHING', 'true', true),
   ('53256bb4-f696-52f4-8490-df6896ada80c', '05ca4010-db97-50ca-831c-9f7e49340341', 'FAST_BREATHING', 'false', true),
   ('538bb4bf-1455-54d8-9f70-c6c57f754702', 'c94290c6-0d07-5b74-86a1-3dadff4a5318', 'POOR_FEEDING', 'true', true),
   ('3a8b9582-fe02-589d-9c7c-5c6b71c82c9b', '83c0d61a-e3ac-5949-b10f-232fac14382b', 'POOR_FEEDING', 'false', true)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_trigger (id, question_id, trigger_type, trigger_code, priority) VALUES
   ('6cd9970b-35b6-54bd-8a06-faa7d4bd9a98', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING'), 'symptom', 'cough', 30),
   ('ce3f8a79-b69a-57ea-9eba-35ed8797666b', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING'), 'symptom', 'fever', 30),
   ('a8fba759-d608-5e0a-a6bd-5eadabee6ba2', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING'), 'symptom', 'cough', 30),
   ('fe5d5be1-5f19-551f-aea7-3d9c58fce025', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING'), 'symptom', 'fever', 30),
   ('c78bd606-597d-5d67-b63d-d497365a41f7', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING'), 'symptom', 'cough', 30),
   ('c8e4499d-d330-5183-b7d2-0f0b0f04ce94', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING'), 'symptom', 'fever', 30),
   ('61e0167f-0355-57a1-b7fe-73870d31c013', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING'), 'symptom', 'cough', 30),
   ('6a04d8ea-d70d-536c-95ab-fec44fa00285', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING'), 'symptom', 'fever', 30),
   ('4aff39a6-cfdf-519a-af8e-0860c1a45623', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'), 'symptom', 'cough', 30),
   ('27ab7cb7-14a9-514d-8431-3d9f569b01b0', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'), 'symptom', 'fever', 30)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_context (id, question_id, context_type_code, context_value_id, applicability, priority) VALUES
   ('e59f2c6b-9456-59bd-8682-f48aced52ff0', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'), 'excludes', 0),
   ('6997491c-b45e-518a-b39d-f745e84d88b1', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '65P'), 'excludes', 0),
   ('dcd4a946-05b0-589d-b3de-8862e8a9657c', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'), 'excludes', 0),
   ('6f6fdeba-f058-5cb0-9aaf-216cbc74e1d9', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '65P'), 'excludes', 0),
   ('eff9c130-2cef-5e3e-8795-72f22bb5f95b', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'), 'excludes', 0),
   ('e036c493-09c4-5cc1-bb35-6db38c7722ad', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '65P'), 'excludes', 0),
   ('b7f07bdf-67c0-5186-9c48-3b0549c436e8', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'), 'excludes', 0),
   ('c5ee5091-0a91-5176-83d7-58572d482401', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '65P'), 'excludes', 0),
   ('51bcd092-5e65-5e57-bbb0-99913ec3c02c', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '18-64Y'), 'excludes', 0),
   ('d0eeee4b-a37b-5f39-9143-952247a3b303', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'), 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = '65P'), 'excludes', 0)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_module_member (id, module_code, question_id) VALUES
   ('b93defd6-cd6c-5c3e-8c48-090caf23f40c', 'PAEDIATRIC_DANGER_SIGNS', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_CHEST_INDRAWING')),
   ('a7a24c9c-9861-5511-b152-2dcce75cb7cd', 'PAEDIATRIC_DANGER_SIGNS', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_GRUNTING')),
   ('d0ba23f7-2107-5dad-9923-306876a411f9', 'PAEDIATRIC_DANGER_SIGNS', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_NASAL_FLARING')),
   ('5d2bcbe7-04c1-50e4-9fc2-a9ff41a883d8', 'PAEDIATRIC_DANGER_SIGNS', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_FAST_BREATHING')),
   ('5ab477fb-9695-528e-83f6-e1223e139b6e', 'PAEDIATRIC_DANGER_SIGNS', (SELECT id FROM knowledge.question WHERE question_code = 'PAEDIATRIC_POOR_FEEDING'))
  ON CONFLICT DO NOTHING;

-- 5b. question_requirement - danger signs are SAFETY probes (H3 rank 0): they
-- must surface beside the other red-flag probes for a child, not sit at the
-- informational tail where the adaptive selector would never reach them.
INSERT INTO knowledge.question_requirement (question_id, requirement_level, condition, priority)
SELECT q.id, x.requirement_level, x.condition::jsonb, x.priority
FROM (VALUES
   ('PAEDIATRIC_CHEST_INDRAWING', 'safety', '{}', 1),
   ('PAEDIATRIC_GRUNTING',        'safety', '{}', 1),
   ('PAEDIATRIC_NASAL_FLARING',   'safety', '{}', 1),
   ('PAEDIATRIC_FAST_BREATHING',  'safety', '{}', 1),
   ('PAEDIATRIC_POOR_FEEDING',    'safety', '{}', 1)
) AS x(question_code, requirement_level, condition, priority)
JOIN knowledge.question q ON q.question_code = x.question_code
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.question_rule (rule_id, rule_name, trigger_type, trigger_code, trigger_operator, trigger_value, action, target_type, target_code, priority_delta, rationale, context, version, status) VALUES
   ('QR014', 'AGE 5-17Y activates paediatric danger-sign module', 'context', 'AGE', 'in', '["5-17Y"]', 'ACTIVATE', 'module', 'PAEDIATRIC_DANGER_SIGNS', 500, 'School-age children: danger-sign recognition must rank with the core cough branch (complements QR006 which covers <5Y).', NULL, 1, 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('35524581-04ff-5074-874b-f7d5e388cd67', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'question_module', 'cd495581-888a-51eb-a4d5-26e1d0ac3f05', 'PAEDIATRIC_DANGER_SIGNS', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('bb4f8bf7-1342-5b8c-8b52-797655735567', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'question_rule', '4ad62970-792e-58c4-be4f-b84e836a4d3d', 'QR014', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('be9374f7-6260-5e16-b2f7-1e603476842d', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'question', 'a6488276-b076-558e-92c0-5aa587daaa3a', 'PAEDIATRIC_CHEST_INDRAWING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('bff666b4-52b1-52db-9961-46fb78cb2a8a', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'question', 'eae3f6ea-2e7a-5f37-ab93-19a83978f89f', 'PAEDIATRIC_GRUNTING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('edd4055a-61c4-5ed1-9592-dfec9cbd501c', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'question', '29969109-d24d-5200-9c6b-ab9167d3183c', 'PAEDIATRIC_NASAL_FLARING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('73f4c4a3-a1c4-5dc1-802f-5e7ef03d646b', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'question', 'ad56ca5b-ee5b-5b94-adf0-1a008b22911b', 'PAEDIATRIC_FAST_BREATHING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('abc863ee-215b-578e-8662-7531b68766bb', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0004'), 'question', '9c629153-df72-50f5-9f31-34c7e72fa58a', 'PAEDIATRIC_POOR_FEEDING', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. knowledge.red_flag_rule - paediatric danger-sign safety probes
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.red_flag_rule (rule_id, rule_code, symptom_id, fact_definition_code, clinical_significance, urgency, priority, evidence_claim_code, status) VALUES
   ('RFR-PAED-FAST-BREATHING', 'RFR-PAED-FAST-BREATHING', (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'), 'FAST_BREATHING', 'Paediatric severe-disease recognition', 'urgent', 10, 'BNR-0003', 'active'),
   ('RFR-PAED-GRUNTING', 'RFR-PAED-GRUNTING', (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'), 'GRUNTING', 'Paediatric severe-disease recognition', 'emergency', 10, 'BNR-0003', 'active'),
   ('RFR-PAED-NASAL-FLARING', 'RFR-PAED-NASAL-FLARING', (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'), 'NASAL_FLARING', 'Paediatric severe-disease recognition', 'urgent', 10, 'BNR-0003', 'active'),
   ('RFR-PAED-POOR-FEEDING', 'RFR-PAED-POOR-FEEDING', (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'), 'POOR_FEEDING', 'Paediatric severe-disease recognition', 'urgent', 10, 'BNR-0004', 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('c4e6713a-1493-5f94-8b8d-097114ffa37c', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'red_flag_rule', '3179d9d9-5a60-5919-98c8-ff9a39109e34', 'RFR-PAED-FAST-BREATHING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('b36c635e-35d4-5db9-b9fb-4a59fbcf7683', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'red_flag_rule', '338afb07-2731-5bf5-ac6e-24bac0d17319', 'RFR-PAED-GRUNTING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('5d16c602-93e4-5dd2-9ea4-78f40f0f83e9', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'red_flag_rule', 'efb54020-72af-59b7-b7a8-051a11241742', 'RFR-PAED-NASAL-FLARING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('99e7f2ee-11d4-5c96-adfb-fc14451410d4', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0004'), 'red_flag_rule', '195a8ee4-e7e7-506c-b979-96f216e51ff1', 'RFR-PAED-POOR-FEEDING', 'derived_from')   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. PHEN-PAEDIATRIC-PNEUMONIA-ALARM phenotype + features + condition_phenotype
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.phenotype (id, phenotype_code, canonical_name, description, status) VALUES
   ('94f382be-e653-5262-aebd-826d3ada078d', 'PHEN-PAEDIATRIC-PNEUMONIA-ALARM', 'Paediatric pneumonia danger signs', 'Child with cough or fever plus any pneumonia danger sign (fast breathing, chest indrawing, grunting, nasal flaring, poor feeding, low SpO2).', 'active')
  ON CONFLICT DO NOTHING;

-- rebuild feature set: the alarm fires ONLY on danger signs, never on fever/cough alone
DELETE FROM knowledge.phenotype_feature WHERE phenotype_id = '94f382be-e653-5262-aebd-826d3ada078d';
INSERT INTO knowledge.phenotype_feature (id, phenotype_id, feature_type, feature_code, operator, value, weight, polarity) VALUES
   ('c26f16d4-4c23-5dbd-9878-e1c0b92389de', '94f382be-e653-5262-aebd-826d3ada078d', 'fact', 'GRUNTING', 'eq', 'true'::jsonb, '0.90', 'positive'),
   ('e48ac1bf-a922-5f8e-bd9c-51b335edc556', '94f382be-e653-5262-aebd-826d3ada078d', 'fact', 'CHEST_INDRAWING', 'eq', 'true'::jsonb, '0.90', 'positive'),
   ('2f22ff96-1002-564c-a364-8037f9d86470', '94f382be-e653-5262-aebd-826d3ada078d', 'fact', 'NASAL_FLARING', 'eq', 'true'::jsonb, '0.80', 'positive'),
   ('0a36a945-f111-54ba-8e77-2c93d2f3ddac', '94f382be-e653-5262-aebd-826d3ada078d', 'fact', 'FAST_BREATHING', 'eq', 'true'::jsonb, '0.80', 'positive'),
   ('98bf765a-9945-57ab-868c-8b85db76d180', '94f382be-e653-5262-aebd-826d3ada078d', 'fact', 'POOR_FEEDING', 'eq', 'true'::jsonb, '0.70', 'positive'),
   ('4fadf411-9c83-549a-b7dd-5496a3c9112a', '94f382be-e653-5262-aebd-826d3ada078d', 'fact', 'SPO2', 'lte', '90'::jsonb, '1.00', 'positive')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.condition_phenotype (id, condition_id, phenotype_id, weight, is_suggestive) VALUES
   ('32d6cce9-d8af-52d0-9a6a-e25033182e10', (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), '94f382be-e653-5262-aebd-826d3ada078d', 1.2, true)
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('ab096dde-98ef-584c-9c03-2b48d38c60c5', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'phenotype', '94f382be-e653-5262-aebd-826d3ada078d', 'PHEN-PAEDIATRIC-PNEUMONIA-ALARM', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('4673b4a9-bc97-5cfe-b7db-4679746f48f6', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'condition_phenotype', '32d6cce9-d8af-52d0-9a6a-e25033182e10', 'PHEN-PAEDIATRIC-PNEUMONIA-ALARM', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('5b4f0cb7-fe56-50d8-be9f-34046e43d539', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'phenotype_feature', 'c26f16d4-4c23-5dbd-9878-e1c0b92389de', 'PF:GRUNTING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('ef80c63e-1e9a-5454-a690-e9b34c9cfaef', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'phenotype_feature', 'e48ac1bf-a922-5f8e-bd9c-51b335edc556', 'PF:CHEST_INDRAWING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('96a09899-fa7f-5ff6-9a67-4ed2f6434958', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'phenotype_feature', '2f22ff96-1002-564c-a364-8037f9d86470', 'PF:NASAL_FLARING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('f341d9b9-4256-55ae-a6c2-194ad887977a', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003'), 'phenotype_feature', '0a36a945-f111-54ba-8e77-2c93d2f3ddac', 'PF:FAST_BREATHING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('38e081c3-c899-5ff7-abcf-a25c864944f6', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0004'), 'phenotype_feature', '98bf765a-9945-57ab-868c-8b85db76d180', 'PF:POOR_FEEDING', 'derived_from')   ON CONFLICT DO NOTHING;
INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) VALUES ('2e1643b0-547c-59f6-ada0-50bbb439f868', (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0004'), 'phenotype_feature', '4fadf411-9c83-549a-b7dd-5496a3c9112a', 'PF:SPO2', 'derived_from')   ON CONFLICT DO NOTHING;