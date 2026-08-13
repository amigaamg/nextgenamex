-- =============================================================================
-- AMEXAN Phase 2 — Seed Z7: clinical rules (composable, versioned, provenanced)
-- =============================================================================
-- Reusable rules with full provenance so the system can explain itself.
-- =============================================================================

INSERT INTO knowledge.rule (id, rule_code, name, description, rule_type, status, priority, evidence_level, guideline, approval_status) VALUES
   ('f1100000-0000-0000-0000-000000000001', 'RULE-TB-SCREEN',
    'TB screening in chronic productive cough',
    'Patients with cough >2 weeks and constitutional symptoms should be investigated for TB',
    'clinical', 'active', 80, 'A1', 'WHO TB screening', 'approved'),
   ('f1100000-0000-0000-0000-000000000002', 'RULE-HYPOXAEMIA-URGENT',
    'Hypoxaemia escalation',
    'SpO2 below 92% with dyspnoea requires urgent oxygen and assessment',
    'safety', 'active', 90, 'A1', 'Hospital oxygen guidelines', 'approved'),
   ('f1100000-0000-0000-0000-000000000003', 'RULE-HAEMOPTYSIS-URGENT',
    'Haemoptysis escalation',
    'Any haemoptysis requires urgent evaluation for mass lesion / infection',
    'safety', 'active', 85, 'B2', 'British Thoracic Society', 'approved'),
   ('f1100000-0000-0000-0000-000000000004', 'RULE-PNEUMONIA-INVESTIGATE',
    'Investigate suspected pneumonia',
    'Acute productive cough with fever suggests pneumonia - order chest X-ray',
    'investigation', 'active', 60, 'B2', NULL, 'approved'),
   ('f1100000-0000-0000-0000-000000000005', 'RULE-TB-CONTACT-SCREEN',
    'TB contact screening',
    'Known TB contact with respiratory symptoms should be screened for TB',
    'clinical', 'active', 75, 'A1', 'WHO TB screening', 'approved')
ON CONFLICT (rule_code) DO NOTHING;

INSERT INTO knowledge.rule_version (id, rule_id, version, body, is_active, changed_by) VALUES
   (gen_random_uuid(), 'f1100000-0000-0000-0000-000000000001', 1,
    jsonb_build_object('type', 'rule', 'rule_code', 'RULE-TB-SCREEN', 'version', 1), true, 'seed'),
   (gen_random_uuid(), 'f1100000-0000-0000-0000-000000000002', 1,
    jsonb_build_object('type', 'rule', 'rule_code', 'RULE-HYPOXAEMIA-URGENT', 'version', 1), true, 'seed'),
   (gen_random_uuid(), 'f1100000-0000-0000-0000-000000000003', 1,
    jsonb_build_object('type', 'rule', 'rule_code', 'RULE-HAEMOPTYSIS-URGENT', 'version', 1), true, 'seed'),
   (gen_random_uuid(), 'f1100000-0000-0000-0000-000000000004', 1,
    jsonb_build_object('type', 'rule', 'rule_code', 'RULE-PNEUMONIA-INVESTIGATE', 'version', 1), true, 'seed'),
   (gen_random_uuid(), 'f1100000-0000-0000-0000-000000000005', 1,
    jsonb_build_object('type', 'rule', 'rule_code', 'RULE-TB-CONTACT-SCREEN', 'version', 1), true, 'seed')
ON CONFLICT (rule_id, version) DO NOTHING;

INSERT INTO knowledge.rule_condition (rule_id, condition_group, condition_order, entity_type, entity_code, operator, value) VALUES
   ('f1100000-0000-0000-0000-000000000001', 1, 1, 'fact', 'COUGH_DURATION_DAYS', 'gt',  '14'),
   ('f1100000-0000-0000-0000-000000000001', 1, 2, 'fact', 'COUGH_PRODUCTIVITY',  'eq', '"PRODUCTIVE"'),
   ('f1100000-0000-0000-0000-000000000001', 2, 1, 'fact', 'WEIGHT_LOSS',          'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000001', 2, 2, 'fact', 'NIGHT_SWEATS',         'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000001', 2, 3, 'fact', 'FEVER_PRESENT',        'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000002', 1, 1, 'measurement', 'SPO2', 'lt', '92'),
   ('f1100000-0000-0000-0000-000000000002', 1, 2, 'fact', 'DYSPNOEA_PRESENT', 'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000003', 1, 1, 'fact', 'BLOOD_IN_SPUTUM', 'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000004', 1, 1, 'fact', 'COUGH_PRODUCTIVITY', 'eq', '"PRODUCTIVE"'),
   ('f1100000-0000-0000-0000-000000000004', 1, 2, 'fact', 'FEVER_PRESENT', 'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000005', 1, 1, 'fact', 'TB_CONTACT', 'eq', '"YES"'),
   ('f1100000-0000-0000-0000-000000000005', 1, 2, 'fact', 'COUGH_PRESENT', 'eq', '"YES"')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.rule_action (rule_id, action_order, action_type, action_entity_type, action_code, params) VALUES
   ('f1100000-0000-0000-0000-000000000001', 1, 'recommend_investigation', 'investigation', 'SPUTUM_AFB',
    jsonb_build_object('rationale', 'Two-week cough with constitutional symptoms requires TB investigation')),
   ('f1100000-0000-0000-0000-000000000001', 2, 'activate_phenotype', 'phenotype', 'PHEN-CHRONIC-PRODUCTIVE', NULL),
   ('f1100000-0000-0000-0000-000000000002', 1, 'recommend_management', 'management', 'OXYGEN',
    jsonb_build_object('rationale', 'SpO2 below 92% requires urgent supplemental oxygen')),
   ('f1100000-0000-0000-0000-000000000002', 2, 'set_priority', 'context', 'urgent', NULL),
   ('f1100000-0000-0000-0000-000000000003', 1, 'raise_red_flag', 'red_flag', 'RF-HAEMOPTYSIS-MASS', NULL),
   ('f1100000-0000-0000-0000-000000000004', 1, 'recommend_investigation', 'investigation', 'INV-CXR',
    jsonb_build_object('rationale', 'Acute productive cough with fever - exclude consolidation')),
   ('f1100000-0000-0000-0000-000000000004', 2, 'activate_phenotype', 'phenotype', 'PHEN-ACUTE-LRTI', NULL),
   ('f1100000-0000-0000-0000-000000000005', 1, 'recommend_investigation', 'investigation', 'SPUTUM_AFB',
    jsonb_build_object('rationale', 'TB contact with respiratory symptoms warrants screening'))
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.rule_context (rule_id, context_type_code, context_value_id, applicability) VALUES
   ('f1100000-0000-0000-0000-000000000001', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='0-28D'), 'excludes'),
   ('f1100000-0000-0000-0000-000000000005', 'AGE',
    (SELECT id FROM knowledge.context_value WHERE context_type_code='AGE' AND value='0-28D'), 'excludes')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.rule_source (rule_id, source_type, source_ref, citation, evidence_level) VALUES
   ('f1100000-0000-0000-0000-000000000001', 'guideline', 'WHO TB screening guidelines',
    'WHO. Systematic screening for active tuberculosis, 2021.', 'A1'),
   ('f1100000-0000-0000-0000-000000000002', 'guideline', 'Hospital oxygen guidelines',
    'Oxygen therapy: management of hypoxaemia in adults.', 'A1'),
   ('f1100000-0000-0000-0000-000000000003', 'guideline', 'BTS haemoptysis guideline',
    'British Thoracic Society recommendations on haemoptysis.', 'B2'),
   ('f1100000-0000-0000-0000-000000000004', 'expert', 'Local practice',
    'Local respiratory medicine consensus.', 'expert_opinion'),
   ('f1100000-0000-0000-0000-000000000005', 'guideline', 'WHO TB screening guidelines',
    'WHO. Systematic screening for active tuberculosis, 2021.', 'A1')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.rule_priority (rule_id, priority_score, basis, description) VALUES
   ('f1100000-0000-0000-0000-000000000001', 90, 'guideline', 'High priority - potential TB'),
   ('f1100000-0000-0000-0000-000000000002', 100, 'safety',   'Immediate safety - oxygen'),
   ('f1100000-0000-0000-0000-000000000003', 95, 'safety',   'Haemoptysis requires urgent workup'),
   ('f1100000-0000-0000-0000-000000000004', 60, 'clinical', 'Routine investigation'),
   ('f1100000-0000-0000-0000-000000000005', 80, 'guideline', 'TB exposure with symptoms')
ON CONFLICT DO NOTHING;
