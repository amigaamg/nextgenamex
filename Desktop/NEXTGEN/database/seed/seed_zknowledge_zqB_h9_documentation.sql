-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H9 seed: documentation compiler knowledge
--   seed_zknowledge_zqB_h9_documentation.sql
-- =============================================================================
-- Seeds the H9 documentation catalogue on Hutchison claims ONLY (§46 provenance
-- law). The runtime tables (documentation_instance / _sentence / _sentence_fact)
-- are intentionally left EMPTY — the CPU compiles a document per reasoning_run,
-- exactly as H7/H8 leave investigation_result / differential_rank empty at seed
-- time (H6/H7 precedent). Idempotent (  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A2. documentation_section + documentation_template — the canonical section
--     catalogue and the three document templates used by the compiler rules.
--     (Sections/templates are configuration objects; seeded here because no
--     earlier seed defines them.)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_section
    (id, section_code, label, heading_template, section_type, is_required, is_repeatable,
     default_certainty, sort_order, applies_to_context_codes, status)
VALUES
    ('f1100000-0000-0000-0000-000000000001','DOC-CC','Chief complaint','Chief complaint','NARRATIVE', true, false, 'DEFINITE', 1, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000002','DOC-HPI','History of present illness','History of present illness','NARRATIVE', true, false, 'DEFINITE', 2, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000003','DOC-SYM','Symptom review','Symptoms','LIST', false, true, 'POSSIBLE', 3, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000004','DOC-NEG','Pertinent negatives','Pertinent negatives','LIST', false, true, 'POSSIBLE', 4, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000005','DOC-PMH','Past medical history','Past medical history','NARRATIVE', false, true, 'POSSIBLE', 5, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000006','DOC-MED','Medications','Medications','LIST', false, true, 'POSSIBLE', 6, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000007','DOC-ALL','Allergies','Allergies','LIST', false, true, 'POSSIBLE', 7, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000008','DOC-SOC','Social history','Social history','NARRATIVE', false, true, 'POSSIBLE', 8, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-000000000009','DOC-FAM','Family history','Family history','NARRATIVE', false, true, 'POSSIBLE', 9, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-00000000000a','DOC-ROS','Review of systems','Review of systems','LIST', false, true, 'POSSIBLE', 10, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-00000000000b','DOC-EXAM','Examination','Examination','NARRATIVE', false, true, 'POSSIBLE', 11, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-00000000000c','DOC-INVEST','Investigations','Investigations','LIST', false, true, 'POSSIBLE', 12, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-00000000000d','DOC-ASSESS','Assessment','Assessment','NARRATIVE', true, false, 'PROBABLE', 13, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-00000000000e','DOC-DIFF','Differential diagnosis','Differential diagnosis','LIST', false, true, 'PROBABLE', 14, ARRAY['ADULT','CHILD'], 'active'),
    ('f1100000-0000-0000-0000-00000000000f','DOC-PLAN','Plan','Plan','LIST', true, false, 'PROBABLE', 15, ARRAY['ADULT','CHILD'], 'active')
  ON CONFLICT DO NOTHING;

INSERT INTO knowledge.documentation_template
    (id, template_code, canonical_name, short_label, description, applies_to_context_codes, is_active, status)
VALUES
    ('f1200000-0000-0000-0000-000000000001','TPL-ADULT-MEDICAL','Adult medical admission','Adult medical',
     'Comprehensive adult medical admission note (all canonical sections).', ARRAY['ADULT','OLDER_ADULT'], true, 'active'),
    ('f1200000-0000-0000-0000-000000000002','TPL-EMERGENCY','Emergency department note','ED note',
     'Focused emergency note (triage-relevant sections).', ARRAY['EMERGENCY'], true, 'active'),
    ('f1200000-0000-0000-0000-000000000003','TPL-DISCHARGE','Discharge summary','Discharge',
     'Discharge summary (follow-up relevant sections).', ARRAY['ADULT','OLDER_ADULT'], true, 'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A3. documentation_template_section — section membership + order (33 rows)
--     Adult = 15 (all); Emergency = 9; Discharge = 9.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_template_section (template_code, section_code, sort_order, is_required, is_repeatable) VALUES
    ('TPL-ADULT-MEDICAL','DOC-CC', 1,'t','f'),
    ('TPL-ADULT-MEDICAL','DOC-HPI',2,'t','f'),
    ('TPL-ADULT-MEDICAL','DOC-SYM',3,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-NEG',4,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-PMH',5,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-MED',6,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-ALL',7,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-SOC',8,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-FAM',9,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-ROS',10,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-EXAM',11,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-INVEST',12,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-ASSESS',13,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-DIFF',14,'f','t'),
    ('TPL-ADULT-MEDICAL','DOC-PLAN',15,'f','t'),

    ('TPL-EMERGENCY','DOC-CC',      1,'t','f'),
    ('TPL-EMERGENCY','DOC-HPI',      2,'t','f'),
    ('TPL-EMERGENCY','DOC-SYM',      3,'f','t'),
    ('TPL-EMERGENCY','DOC-NEG',      4,'f','t'),
    ('TPL-EMERGENCY','DOC-EXAM',    11,'f','t'),
    ('TPL-EMERGENCY','DOC-INVEST',  12,'f','t'),
    ('TPL-EMERGENCY','DOC-ASSESS',  13,'f','t'),
    ('TPL-EMERGENCY','DOC-DIFF',    14,'f','t'),
    ('TPL-EMERGENCY','DOC-PLAN',    15,'f','t'),

    ('TPL-DISCHARGE','DOC-PMH',      5,'f','t'),
    ('TPL-DISCHARGE','DOC-MED',      6,'f','t'),
    ('TPL-DISCHARGE','DOC-ALL',      7,'f','t'),
    ('TPL-DISCHARGE','DOC-SOC',      8,'f','t'),
    ('TPL-DISCHARGE','DOC-FAM',      9,'f','t'),
    ('TPL-DISCHARGE','DOC-INVEST',  12,'f','t'),
    ('TPL-DISCHARGE','DOC-ASSESS',  13,'f','t'),
    ('TPL-DISCHARGE','DOC-DIFF',    14,'f','t'),
    ('TPL-DISCHARGE','DOC-PLAN',    15,'f','t')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A4. documentation_template_element — 9 structured propositions (H9 §7)
--     All FK targets verified real (H7 phenomenology / H8 evidence rules):
--       fact_definition: COUGH_DURATION_DAYS, SPUTUM_COLOUR, SPO2, BLOOD_IN_SPUTUM
--       phenotype:       PHEN-ACUTE-HYPOXAEMIC, PHEN-AIRWAY-WHEEZE
--       result_interpretation: RINT_CONSOLIDATION, RINT_MTB_DETECTED, RINT_LEUKOCYTOSIS
--       diagnosis_concept: DA001 (Pneumonia)
--       differential_evidence_rule: DEV-003
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_template_element
    (element_code, template_code, section_code, evidence_type, fact_definition_code,
     phenotype_code, result_interpretation_code, diagnosis_code, evidence_rule_code,
     wording_template, source_method_code, certainty, min_strength, is_must_document)
VALUES
    ('DTE-HPI-COUGH-DUR',        'TPL-ADULT-MEDICAL','DOC-HPI',    'FACT','COUGH_DURATION_DAYS',            NULL,NULL,NULL,NULL,
     'The patient presents with a {value}-day history of cough.',                  'PATIENT_REPORTED','PROBABLE', 0.5, true),
    ('DTE-HPI-SPUTUM-COLOUR',    'TPL-ADULT-MEDICAL','DOC-HPI',    'FACT','SPUTUM_COLOUR',                   NULL,NULL,NULL,NULL,
     'Sputum is {value} in character.',                                              'PATIENT_REPORTED','PROBABLE', 0.5, true),
    ('DTE-HPI-HYPOX',            'TPL-ADULT-MEDICAL','DOC-HPI',    'PHENOTYPE',NULL,'PHEN-ACUTE-HYPOXAEMIC',         NULL,NULL,NULL,
     'This was associated with hypoxaemia (SpO2 {value}%).',                        'CLINICIAN_OBSERVED','DEFINITE', 0.8, true),
    ('DTE-SYM-WHEEZE',           'TPL-ADULT-MEDICAL','DOC-SYM',    'PHENOTYPE',NULL,'PHEN-AIRWAY-WHEEZE',      NULL,NULL,NULL,
     'Wheaze is {value}.',                                                           'PATIENT_REPORTED','POSSIBLE', 0.5, false),
    ('DTE-SYM-HAEMOPTYSIS',      'TPL-ADULT-MEDICAL','DOC-SYM',    'FACT','BLOOD_IN_SPUTUM',                  NULL,NULL,NULL,NULL,
     'Haemoptysis is {value}.',                                                      'PATIENT_REPORTED','POSSIBLE', 0.5, true),
    ('DTE-INVEST-CONSOLIDATION','TPL-ADULT-MEDICAL','DOC-INVEST', 'RESULT_INTERPRETATION',NULL,NULL,'RINT_CONSOLIDATION',NULL,'DEV-003',
     'Chest imaging demonstrates {value}.',                                          'IMAGING_DERIVED','DEFINITE', 1.2, true),
    ('DTE-INVEST-MTB',           'TPL-ADULT-MEDICAL','DOC-INVEST', 'RESULT_INTERPRETATION',NULL,NULL,'RINT_MTB_DETECTED',NULL,'DEV-003',
     'Microbiology detects {value}.',                                                'LAB_MEASURED','DEFINITE', 1.5, true),
    ('DTE-INVEST-LEUKO',         'TPL-ADULT-MEDICAL','DOC-INVEST', 'RESULT_INTERPRETATION',NULL,NULL,'RINT_LEUKOCYTOSIS',NULL,'DEV-003',
     'Laboratory shows {value}.',                                                    'LAB_MEASURED','PROBABLE', 0.9, true),
    ('DTE-ASSESS-PNEUMONIA',     'TPL-ADULT-MEDICAL','DOC-ASSESS', 'DIAGNOSIS',NULL,NULL,NULL,'DA001',NULL,
     'The clinical picture is most consistent with {value}.',                        'SYSTEM_DERIVED','PROBABLE', 1.5, true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A5. documentation_template_rule — 8 IF proposition THEN ACT rules (H9 §9)
--     evidence_rule_code reuses H8 differential_evidence_rule (the H8→H9 link).
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_template_rule
    (rule_code, template_code, trigger_type, trigger_code, evidence_rule_code,
     target_element_code, action, weight_delta, wording_template, evidence_claim_code)
VALUES
    ('DRule-001','TPL-ADULT-MEDICAL','EVIDENCE_RULE', NULL, 'DEV-003', 'DTE-INVEST-CONSOLIDATION','RENDER',        0.0, NULL, 'HCH12-0018'),
    ('DRule-002','TPL-ADULT-MEDICAL','EVIDENCE_RULE', NULL, 'DEV-006', 'DTE-HPI-COUGH-DUR',      'RENDER',        0.0, NULL, 'HCH12-0018'),
    ('DRule-003','TPL-ADULT-MEDICAL','EVIDENCE_RULE', NULL, 'DEV-007', 'DTE-HPI-COUGH-DUR',      'SUPPRESS',       0.0, NULL, 'HCH12-0018'),
    ('DRule-004','TPL-ADULT-MEDICAL','EVIDENCE_RULE', NULL, 'DEV-005', 'DTE-SYM-WHEEZE',         'WEAKLY_INCLUDE', 0.0, NULL, 'HCH12-0018'),
    ('DRule-005','TPL-ADULT-MEDICAL','FACT',  'SPO2',           NULL, 'DTE-HPI-HYPOX',            'RENDER',        0.0, NULL, 'HCH12-0018'),
    ('DRule-006','TPL-ADULT-MEDICAL','FACT',  'BLOOD_IN_SPUTUM',NULL, 'DTE-SYM-HAEMOPTYSIS',      'RENDER',        0.0, NULL, 'HCH12-0007'),
    ('DRule-007','TPL-ADULT-MEDICAL','FACT',  'COUGH_DURATION_DAYS',NULL,'DTE-HPI-COUGH-DUR',     'RENDER',        0.0, NULL, 'HCH12-0018'),
    ('DRule-008','TPL-ADULT-MEDICAL','EVIDENCE_RULE', NULL, 'DEV-003', 'DTE-INVEST-CONSOLIDATION','ESCALATE',      0.8, NULL, 'HCH12-0018')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A6. documentation_order_rule — 9 HPI narrative-ordering steps (H9 §9/§11)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_order_rule
    (rule_code, section_code, proposition_code, proposition_type, clinical_narrative_position, sort_order, wording_template, evidence_claim_code)
VALUES
    ('DOR-001','DOC-HPI','COUGH_DURATION_DAYS','FACT',      'ONSET',              1, 'History began with {value}.',        'HCH12-0018'),
    ('DOR-002','DOC-HPI','SPUTUM_COLOUR',      'FACT',      'CHARACTER',          2, 'Character: {value}.',               'HCH12-0018'),
    ('DOR-003','DOC-HPI','SPO2',               'FACT',      'SEVERITY',           3, 'Severity reflected by {value}.',    'HCH12-0018'),
    ('DOR-004','DOC-HPI','PHEN-ACUTE-HYPOXAEMIC',    'PHENOTYPE', 'ASSOCIATED_FEATURES',4, 'Associated {value}.',              'HCH12-0018'),
    ('DOR-005','DOC-HPI','BLOOD_IN_SPUTUM',    'FACT',      'PERTINENT_NEGATIVES',5, 'No {value}.',                      'HCH12-0007'),
    ('DOR-006','DOC-HPI','COUGH_DURATION_DAYS','FACT',      'MODIFIERS',          6, 'Duration {value} days.',            'HCH12-0018'),
    ('DOR-007','DOC-HPI','SPO2',               'FACT',      'FUNCTIONAL_IMPACT',  7, 'Functional impact: {value}.',       'HCH12-0018'),
    ('DOR-008','DOC-HPI','COUGH_DURATION_DAYS','FACT',      'RELEVANT_CONTEXT',   8, 'Context: {value} days.',            'HCH1-0001'),
    ('DOR-009','DOC-HPI','PHEN-ACUTE-HYPOXAEMIC',    'PHENOTYPE', 'CHRONOLOGY',         9, 'Chronology: {value}.',             'HCH12-0018')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A7. documentation_relevance_rule — 7 document-priority rules (H9 §17)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_relevance_rule
    (rule_code, proposition_code, proposition_type, priority_level, rationale, evidence_claim_code)
VALUES
    ('DRL-001','PHEN-ACUTE-HYPOXAEMIC',    'PHENOTYPE','HIGH',   'Hypoxaemia is a red-flag severity signal.',          'HCH12-0018'),
    ('DRL-002','RINT_MTB_DETECTED',  'RESULT_INTERPRETATION','HIGH','MTB detected is must-not-miss (TB).',         'HCH12-0007'),
    ('DRL-003','BLOOD_IN_SPUTUM',    'FACT','HIGH',        'Haemoptysis raises the TB differential (H8 RR004).', 'HCH12-0007'),
    ('DRL-004','RINT_CONSOLIDATION', 'RESULT_INTERPRETATION','MEDIUM','Consolidation strengthens the pneumonia frame.','HCH12-0018'),
    ('DRL-005','PHEN-AIRWAY-WHEEZE', 'PHENOTYPE','MEDIUM',  'Wheaze is a supporting airways feature.',            'HCH12-0018'),
    ('DRL-006','COUGH_DURATION_DAYS','FACT','MEDIUM',       'Cough duration frames acuity.',                      'HCH12-0018'),
    ('DRL-007','SPUTUM_COLOUR',      'FACT','LOW',         'Sputum character is supporting detail.',               'HCH12-0018')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A8. documentation_lexicon — 8 canonical terms (H9 §23)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_lexicon (concept_code, concept_type, canonical_term)
VALUES
    ('COUGH_DURATION_DAYS',    'FACT',                   'Cough duration'),
    ('SPUTUM_COLOUR',          'FACT',                   'Sputum character')  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.documentation_lexicon (concept_code, concept_type, canonical_term)
VALUES
    ('SPO2',                   'FACT',                   'Oxygen saturation'),
    ('BLOOD_IN_SPUTUM',        'FACT',                   'Haemoptysis')  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.documentation_lexicon (concept_code, concept_type, canonical_term)
VALUES
    ('PHEN-ACUTE-HYPOXAEMIC',        'PHENOTYPE',              'Hypoxaemia'),
    ('PHEN-AIRWAY-WHEEZE',     'PHENOTYPE',              'Wheeze')  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.documentation_lexicon (concept_code, concept_type, canonical_term)
VALUES
    ('RINT_CONSOLIDATION',     'RESULT_INTERPRETATION',  'Consolidation'),
    ('RINT_MTB_DETECTED',      'RESULT_INTERPRETATION',  'MTB detected')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A9. documentation_term — 8 ADULT realisations of the lexicon (H9 §23/§24)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_term (lexicon_id, applies_to_context_code, preferred_label, wording_template, is_preferred)
SELECT l.id, 'ADULT', l.canonical_term,
       CASE l.canonical_term
            WHEN 'Cough duration' THEN 'The patient reports a {value}-day cough.'
            WHEN 'Sputum character' THEN 'Sputum is {value}.'
            WHEN 'Oxygen saturation' THEN 'Oxygen saturation is {value}%.'
            WHEN 'Haemoptysis' THEN 'The patient reports {value} haemoptysis.'
            WHEN 'Hypoxaemia' THEN 'The patient is hypoxaemic ({value}).'
            WHEN 'Wheeze' THEN 'There is {value} wheeze.'
            WHEN 'Consolidation' THEN 'Imaging shows {value}.'
            WHEN 'MTB detected' THEN 'Laboratory confirms {value}.'
            ELSE l.canonical_term
       END, true
FROM knowledge.documentation_lexicon l
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A10. documentation_term_variant — 8 synonym variants (H9 §23)
-- ---------------------------------------------------------------------------
WITH term_map AS (
    SELECT t.id AS term_id, l.canonical_term
    FROM knowledge.documentation_term t
    JOIN knowledge.documentation_lexicon l ON l.id = t.lexicon_id
)
INSERT INTO knowledge.documentation_term_variant (term_id, variant_label, language_code, is_preferred)
SELECT term_id,
       CASE canonical_term
            WHEN 'Cough duration' THEN 'Duration of cough'
            WHEN 'Sputum character' THEN 'Sputum appearance'
            WHEN 'Oxygen saturation' THEN 'SpO2 level'
            WHEN 'Haemoptysis' THEN 'Blood in sputum'
            WHEN 'Hypoxaemia' THEN 'Low blood oxygen'
            WHEN 'Wheeze' THEN 'High-pitched wheeze'
            WHEN 'Consolidation' THEN 'Lung consolidation'
            WHEN 'MTB detected' THEN 'Tuberculosis detected'
            ELSE canonical_term
       END, 'en', false
FROM term_map
ON CONFLICT (term_id, variant_label, language_code) DO UPDATE SET is_preferred = EXCLUDED.is_preferred;

-- ---------------------------------------------------------------------------
-- A11. documentation_version — 1 documentation knowledge version (H9 §40)
--     knowledge_version mirrors H8 reasoning_version.knowledge_version so
--     documentation provenance tracks the same Hutchison source.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.documentation_version
    (version_code, ruleset_version, knowledge_version, engine_version, effective_from, change_note)
VALUES
    ('RV2024.01.002', 'H9-RULESET-1.0', 'HUTCHISON_24_2018', 'DOCUMENTATION-CPU-1.0', '2024-01-01',
     'Initial H9 documentation compiler knowledge set.')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- A12. PROVENANCE — one derived_from edge per seeded H9 object to a real
--     Hutchison claim (§46). All objects map to claim HCH12-0018 (respiratory
--     history method, HCH1-0001 for the general framework / version, HCH12-0007
--     for TB/haemoptysis propositions). Every row gets exactly one edge so
--     provenance count == object count (109).
-- ---------------------------------------------------------------------------
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018'),
     tb  AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0007'),
     fw  AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_section', s.id, s.section_code, 'derived_from', 1.0
FROM knowledge.documentation_section s CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_template', t.id, t.template_code, 'derived_from', 1.0
FROM knowledge.documentation_template t CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_template_section', ts.id, ts.template_code||':'||ts.section_code, 'derived_from', 1.0
FROM knowledge.documentation_template_section ts CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018'),
     tb  AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0007')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE e.element_code
            WHEN 'DTE-INVEST-MTB'       THEN tb.claim_id
            WHEN 'DTE-SYM-HAEMOPTYSIS'  THEN tb.claim_id
            WHEN 'DTE-ASSESS-PNEUMONIA' THEN tb.claim_id
            ELSE hpi.claim_id
       END,
       'documentation_template_element', e.id, e.element_code, 'derived_from', 1.0
FROM knowledge.documentation_template_element e CROSS JOIN hpi CROSS JOIN tb
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_template_rule', r.id, r.rule_code, 'derived_from', 1.0
FROM knowledge.documentation_template_rule r CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_order_rule', r.id, r.rule_code, 'derived_from', 1.0
FROM knowledge.documentation_order_rule r CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018'),
     tb  AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0007')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE WHEN r.proposition_code='BLOOD_IN_SPUTUM' THEN tb.claim_id ELSE hpi.claim_id END,
       'documentation_relevance_rule', r.id, r.rule_code, 'derived_from', 1.0
FROM knowledge.documentation_relevance_rule r CROSS JOIN hpi CROSS JOIN tb
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018'),
     tb  AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0007')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE WHEN l.canonical_term IN ('Haemoptysis') THEN tb.claim_id ELSE hpi.claim_id END,
       'documentation_lexicon', l.id, l.concept_code, 'derived_from', 1.0
FROM knowledge.documentation_lexicon l CROSS JOIN hpi CROSS JOIN tb
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_term', t.id, l.concept_code, 'derived_from', 1.0
FROM knowledge.documentation_term t
JOIN knowledge.documentation_lexicon l ON l.id = t.lexicon_id
CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH hpi AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT hpi.claim_id, 'documentation_term_variant', tv.id, tv.variant_label, 'derived_from', 1.0
FROM knowledge.documentation_term_variant tv CROSS JOIN hpi
ON CONFLICT DO NOTHING;
WITH fw AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT fw.claim_id, 'documentation_version', dv.version_id, dv.version_code, 'derived_from', 1.0
FROM knowledge.documentation_version dv CROSS JOIN fw
ON CONFLICT DO NOTHING;
-- =============================================================================
-- Runtime tables (documentation_instance / _sentence / _sentence_fact) are
-- intentionally EMPTY at seed time — the CPU compiles documents at reasoning
-- time, exactly as H7/H8 leave investigation_result / differential_rank empty.
-- =============================================================================
