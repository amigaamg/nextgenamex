-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H10 seed zqC: provenance, governance &
-- clinical knowledge control (migration 036)
--   seed_zknowledge_zqC_h10_governance.sql
-- NOTE: named zqC so it sorts AFTER zqB (H9) in seed.ps1 lexical ordering.
-- =============================================================================
-- Seeds the H10 GOVERNANCE CATALOGUE, grounded in Hutchison claims ONLY (§46
-- provenance law — the shared knowledge.provenance backbone carries one
-- 'governance_…' edge per governed object; provenance count == object count).
--
-- H10 does NOT re-implement the H1 source/claim backbone nor the per-layer
-- version registries. It GOVERNS them by reference:
--   * every governed object cites knowledge.source_claim(claim_code) (H1)
--   * system_version cites knowledge.reasoning_version + documentation_version
--   * the registry object codes (DA001, DEV-003, PHEN-…, PROT-CAP-ADULT, …)
--     are the REAL H4-H9 business codes, so the catalogue cross-references
--     the layers instead of duplicating them (H6/H7/H8/H9 precedent).
--
-- RUNTIME tables (rule_execution / audit_event / provenance_record /
-- clinical_snapshot / reasoning_snapshot / documentation_snapshot) are seeded
-- EMPTY — the CPU records them per computation (H6/H7/H8/H9 precedent).
--
-- Grounding claims (Hutchison 24e):
--   HCH1-0001  Clinical Methods framework/methodology (registries, versions)
--   HCH2-0005  Box 2.3 pathological-process framework
--   HCH2-0006  Box 2.4 immediate workup
--   HCH12-0002 dyspnoea — cardiovascular vs respiratory
--   HCH12-0004 cough acute <3wk / chronic >8wk
--   HCH12-0005 asthma cough patterns
--   HCH12-0006 sputum colour/character
--   HCH12-0007 haemoptysis never dismissed
--   HCH12-0016 SpO2 / RR respiratory monitoring
--   HCH12-0018 auscultation — consolidation, wheezes, crackles
--   HCH12-0020 Box 12.5 chronic-cough questions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. jurisdiction — 2 rows (#22/#24)
-- ---------------------------------------------------------------------------
INSERT INTO governance.jurisdiction
    (jurisdiction_code, name, description, country_code, is_default, is_active, status)
VALUES
    ('JUR-GLOBAL', 'Global core', 'Jurisdiction-neutral core knowledge of the universal AMEXAN ontology.', NULL, true,  true,  'active'),
    ('JUR-KENYA',  'Kenya',      'Kenyan jurisdictional overlay for governed knowledge (national guidance).', 'KE', false, true,  'active')
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. population_context — 4 rows (#15/#23)
-- ---------------------------------------------------------------------------
INSERT INTO governance.population_context
    (population_code, name, description, applies_to_context_codes, is_active)
VALUES
    ('POP-ADULT',     'Adult',      'Adult population — the universal core coverage.',        ARRAY['ADULT'], true),
    ('POP-PAEDIATRIC','Paediatric', 'Paediatric population overlay.',                         ARRAY['CHILD','INFANT'], true),
    ('POP-NEONATE',   'Neonate',    'Neonatal population overlay.',                           ARRAY['NEONATE'], true),
    ('POP-PREGNANCY', 'Pregnancy',  'Pregnancy population overlay for governed knowledge.',   ARRAY['PREGNANCY'], true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. evidence_metadata — 5 levels (#15/#45)
-- ---------------------------------------------------------------------------
INSERT INTO governance.evidence_metadata
    (evidence_level_code, level_label, ranking, description, is_active)
VALUES
    ('EV-A', 'Meta-analysis / systematic review / RCT',     1, 'Highest strength: synthesized randomised evidence.', true),
    ('EV-B', 'Cohort / case-control / observational',        2, 'Strong observational evidence.',                   true),
    ('EV-C', 'Expert consensus / textbook method',           3, 'Consensus clinical method (Hutchison cornerstone).', true),
    ('EV-D', 'Case series / expert opinion',                 4, 'Lower-strength single-centre / opinion evidence.',  true),
    ('EV-E', 'Anecdote / in progress at Level D',            5, 'Lowest strength, flagged as such.',                 true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. knowledge_object — 25 governed-object catalogue (#14/#15/#40)
--     object_code == the REAL H4-H9 business code; knowledge_type marks the
--     governing category. Every row cites its Hutchison claim (§46 / §49 — no
--     anonymous clinical logic). GL-KENYA-ASTHMA-2021 is a DRAFT jurisdictional
--     guideline the machine test uses to prove the PUBLISH gate fails closed.
-- ---------------------------------------------------------------------------
INSERT INTO governance.knowledge_object
    (object_code, knowledge_type, canonical_name, description, source_claim_code,
     jurisdiction_code, population_code, evidence_level_code, lifecycle_status,
     confidence, review_date, created_by, reviewed_by, approved_by, is_active)
VALUES
    ('Q-COUGH_DURATION',       'QUESTION',              'Cough duration question',      'OSCE/symptom question: how long has the cough lasted (acute/chronic bands).', 'HCH12-0004',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.95, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('Q-SPUTUM_COLOUR',        'QUESTION',              'Sputum colour question',       'OSCE/symptom question: sputum colour/character (HCH12-0006).',             'HCH12-0006',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('Q-BLOOD_IN_SPUTUM',      'QUESTION',              'Haemoptysis question',         'Safety question: haemoptysis must never be dismissed (HCH12-0007).',      'HCH12-0007',
     'JUR-GLOBAL', NULL, 'EV-A', 'ACTIVE', 0.99, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('COUGH_DURATION_DAYS',    'CLINICAL_FACT',         'Cough duration (days)',        'Cardinal fact: acute <3 weeks, chronic >8 weeks (56 days).',               'HCH12-0004',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.95, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('SPO2',                   'CLINICAL_FACT',         'Peripheral oxygen saturation', 'Vital fact: SpO2 normal >=95%; RR ~14-16 respiratory monitoring.',         'HCH12-0016',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('SPUTUM_COLOUR',          'CLINICAL_FACT',         'Sputum colour/character',      'Fact: purulent colour change signals infection.',                          'HCH12-0006',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('BLOOD_IN_SPUTUM',        'CLINICAL_FACT',         'Blood in sputum (haemoptysis)','Red-flag fact: evaluate carefully, never dismiss.',                        'HCH12-0007',
     'JUR-GLOBAL', NULL, 'EV-A', 'ACTIVE', 0.99, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('PHEN-ACUTE-LRTI',        'PHENOTYPE',             'Acute lower respiratory tract illness', 'Phenotype frame for the acute LRTI syndrome.',                            'HCH12-0004',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('PHEN-HYPOXAEMIA',        'PHENOTYPE',             'Hypoxaemia',                   'Severity phenotype: oxygen saturation below normal threshold.',           'HCH12-0016',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.95, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('PHEN-AIRWAY-WHEEZE',     'PHENOTYPE',             'Airway wheeze',                'Auscultatory phenotype: wheezes = variable airway obstruction.',          'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.85, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('MECH-ALVEOLAR-INFLAMMATION','MECHANISM',          'Alveolar inflammatory filling','Mechanism: alveolar filling process underlying consolidation.',             'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DA001',                  'DIAGNOSIS',             'Pneumonia',                    'Diagnosis: alveolar consolidation / inflammatory filling of lung tissue.', 'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-B', 'ACTIVE', 0.95, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DA005',                  'DIAGNOSIS',             'Asthma',                       'Diagnosis: variable airway obstruction with wheeze.',                     'HCH12-0005',
     'JUR-GLOBAL', NULL, 'EV-B', 'ACTIVE', 0.85, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DA006',                  'DIAGNOSIS',             'Gastro-oesophageal reflux cough', 'Diagnosis: acid reflux driving the chronic-cough pattern (Box 12.5).',   'HCH12-0020',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.85, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DEV-003',                'DIFFERENTIAL_RULE',     'Bronchial breath sounds strongly support consolidation', 'H8 differential evidence rule: bronchial sounds -> pneumonia frame.',     'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-B', 'ACTIVE', 0.95, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DEV-006',                'DIFFERENTIAL_RULE',     'Acute cough (<21d) supports bronchial syndrome',       'H8 rule: acute band supports the bronchial/acute-LRTI frame.',            'HCH12-0004',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.85, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DEV-007',                'DIFFERENTIAL_RULE',     'Chronic cough (>56d) opposes bronchial syndrome',      'H8 rule: chronic band opposes the bronchial frame (moves to chronic DDx).','HCH12-0004',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.85, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('RINT_CONSOLIDATION',     'INTERPRETATION',        'Radiographic consolidation',   'H7/H8 result interpretation: consolidation confirms the consolidative process.', 'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-B', 'ACTIVE', 0.95, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('RINT_MTB_DETECTED',      'INTERPRETATION',        'Mycobacterium tuberculosis detected', 'Interpretation: MTB identified — must-not-miss TB.',                    'HCH12-0007',
     'JUR-GLOBAL', NULL, 'EV-A', 'ACTIVE', 0.99, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('PROT-CAP-ADULT',         'PROTOCOL',              'Community-acquired pneumonia — adult management',     'Protocol: adult CAP management frame (H8 lead hypothesis triggers it).',  'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-B', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('TPL-ADULT-MEDICAL',      'DOCUMENTATION_TEMPLATE','Adult Medical Clerking document template', 'H9 documentation template: universal adult clerking document.',          'HCH12-0018',
     'JUR-GLOBAL', 'POP-ADULT', 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DTE-ASSESS-PNEUMONIA',   'DOCUMENTATION_TEMPLATE','Assessment element: pneumonia renders the diagnosis', 'H9 template element: renders the pneumonia assessment sentence.',         'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('DRule-001',              'DOCUMENTATION_RULE',    'Render consolidation element when DEV-003 fires',     'H9 documentation rule: EVIDENCE_RULE trigger on DEV-003 -> RENDER.',      'HCH12-0018',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.90, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true),
    ('GL-KENYA-ASTHMA-2021',   'GUIDELINE',             'Kenya asthma management guideline (BTS 2021)',        'DRAFT jurisdictional guideline awaiting population validation (NOT live).','HCH12-0005',
     'JUR-KENYA', NULL, 'EV-B', 'DRAFT', 0.80, '2024-01-01', 'Dr B Njenga', NULL, NULL, false),
    ('RV2024.01.002',          'KNOWLEDGE_VERSION',     'Documentation knowledge version RV2024.01.002 (H9)',  'Governed knowledge version: H9 documentation ruleset (mirrors H8 HUTCHISON_24_2018).','HCH1-0001',
     'JUR-GLOBAL', NULL, 'EV-C', 'ACTIVE', 0.99, '2024-01-01', 'Dr A Otieno', 'Dr A Otieno', 'Dr A Otieno', true)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. knowledge_object_version — 7 version rows; never overwrite history (#8/#9)
--     v1 rows first, then v2 rows with supersedes links (self-reference).
-- ---------------------------------------------------------------------------
INSERT INTO governance.knowledge_object_version
    (object_id, version_no, version_code, change_note, lifecycle_status, source_claim_code, created_by)
SELECT ko.id, v.version_no, v.version_code, v.change_note, v.lifecycle_status, v.source_claim_code, 'Dr A Otieno'
FROM (VALUES
    ('DA001',              1, 'GO-V-DA001-1', 'Initial pneumonia diagnostic frame (H8).',          'SUPERSEDED', 'HCH12-0018'),
    ('DEV-003',            1, 'GO-V-DEV003-1','Initial bronchial-sound evidence rule (H8).',        'ACTIVE',     'HCH12-0018'),
    ('PROT-CAP-ADULT',     1, 'GO-V-PROT-1',  'Initial CAP protocol (H8).',                         'SUPERSEDED', 'HCH12-0018'),
    ('TPL-ADULT-MEDICAL',  1, 'GO-V-TPL-1',   'Initial adult clerking template (H9).',              'ACTIVE',     'HCH12-0018'),
    ('GL-KENYA-ASTHMA-2021',1,'GO-V-GL-1',    'Draft national asthma guideline overlay (Kenya).',   'DRAFT',      'HCH12-0005')
) AS v(object_code, version_no, version_code, change_note, lifecycle_status, source_claim_code)
JOIN governance.knowledge_object ko ON ko.object_code = v.object_code
  ON CONFLICT DO NOTHING;

INSERT INTO governance.knowledge_object_version
    (object_id, version_no, version_code, change_note, supersedes_version_id, lifecycle_status, source_claim_code, created_by)
SELECT ko.id, v.version_no, v.version_code, v.change_note,
       vs.id                          AS supersedes_version_id,
       'ACTIVE', v.source_claim_code, 'Dr A Otieno'
FROM (VALUES
    ('DA001',         2, 'GO-V-DA001-2','Pneumonia frame v2: review + approval + published (H10).', 'GO-V-DA001-1', 'HCH12-0018'),
    ('PROT-CAP-ADULT',2, 'GO-V-PROT-2', 'CAP protocol v2: safety review PASS, published (H10).',    'GO-V-PROT-1',  'HCH12-0018')
) AS v(object_code, version_no, version_code, change_note, supersedes_code, source_claim_code)
JOIN governance.knowledge_object ko ON ko.object_code = v.object_code
JOIN governance.knowledge_object_version vs ON vs.version_code = v.supersedes_code
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. knowledge_relationship — 10 governed knowledge-graph edges (#42/#43)
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object)
INSERT INTO governance.knowledge_relationship
    (relationship_code, from_object_id, to_object_id, relationship_type, weight, source_claim_code)
SELECT r.relationship_code, o1.id, o2.id, r.relationship_type, r.weight, r.source_claim_code
FROM (VALUES
    ('GO-REL-QCD-COUGHDUR',  'Q-COUGH_DURATION',   'COUGH_DURATION_DAYS', 'ASSESSES',   1.0, 'HCH12-0004'),
    ('GO-REL-QSC-SPUTUM',    'Q-SPUTUM_COLOUR',    'SPUTUM_COLOUR',       'ASSESSES',   1.0, 'HCH12-0006'),
    ('GO-REL-QBIS-BLOOD',    'Q-BLOOD_IN_SPUTUM',  'BLOOD_IN_SPUTUM',     'ASSESSES',   1.0, 'HCH12-0007'),
    ('GO-REL-SPO2-HYPOX',    'SPO2',               'PHEN-HYPOXAEMIA',     'SUPPORTS',   1.5, 'HCH12-0016'),
    ('GO-REL-LRTI-DA001',    'PHEN-ACUTE-LRTI',    'DA001',               'SUPPORTS',   1.2, 'HCH12-0004'),
    ('GO-REL-HYPOX-DA001',   'PHEN-HYPOXAEMIA',    'DA001',               'SUPPORTS',   0.8, 'HCH12-0016'),
    ('GO-REL-MECH-DA001',    'MECH-ALVEOLAR-INFLAMMATION', 'DA001',       'SUPPORTS',   1.2, 'HCH12-0018'),
    ('GO-REL-RINT-DA001',    'RINT_CONSOLIDATION', 'DA001',               'SUPPORTS',   2.0, 'HCH12-0018'),
    ('GO-REL-DA001-PROT',    'DA001',              'PROT-CAP-ADULT',      'TRIGGERS',   1.0, 'HCH12-0018'),
    ('GO-REL-DTE-DA001',     'DTE-ASSESS-PNEUMONIA','DA001',              'DOCUMENTS',  1.0, 'HCH12-0018')
) AS r(relationship_code, from_code, to_code, relationship_type, weight, source_claim_code)
JOIN objs o1 ON o1.object_code = r.from_code
JOIN objs o2 ON o2.object_code = r.to_code
ON CONFLICT (relationship_code) DO UPDATE SET
    weight = EXCLUDED.weight, source_claim_code = EXCLUDED.source_claim_code;

-- ---------------------------------------------------------------------------
-- 7. knowledge_dependency — 8 dependency edges, acyclic (#28/#29)
--     Cycle detection in the machine test runs over this table.
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object)
INSERT INTO governance.knowledge_dependency
    (dependency_code, dependent_object_id, required_object_id, dependency_type, is_optional, source_claim_code)
SELECT d.dependency_code, o1.id, o2.id, d.dependency_type, d.is_optional, d.source_claim_code
FROM (VALUES
    ('GO-DEP-PROT-DA001',  'PROT-CAP-ADULT',    'DA001',              'REQUIRES', false, 'HCH12-0018'),
    ('GO-DEP-DA001-LRTI',  'DA001',             'PHEN-ACUTE-LRTI',    'REQUIRES', false, 'HCH12-0004'),
    ('GO-DEP-LRTI-COUGHDUR','PHEN-ACUTE-LRTI',  'COUGH_DURATION_DAYS','REQUIRES', false, 'HCH12-0004'),
    ('GO-DEP-HYPOX-SPO2',  'PHEN-HYPOXAEMIA',   'SPO2',               'REQUIRES', false, 'HCH12-0016'),
    ('GO-DEP-DEV6-COUGHDUR','DEV-006',          'COUGH_DURATION_DAYS','REQUIRES', false, 'HCH12-0004'),
    ('GO-DEP-DEV7-COUGHDUR','DEV-007',          'COUGH_DURATION_DAYS','REQUIRES', false, 'HCH12-0004'),
    ('GO-DEP-TPL-DA001',   'TPL-ADULT-MEDICAL', 'DA001',              'REQUIRES', false, 'HCH12-0018'),
    ('GO-DEP-DA005-WHEEZE', 'DA005',            'PHEN-AIRWAY-WHEEZE', 'REQUIRES', false, 'HCH12-0018')
) AS d(dependency_code, dependent_code, required_code, dependency_type, is_optional, source_claim_code)
JOIN objs o1 ON o1.object_code = d.dependent_code
JOIN objs o2 ON o2.object_code = d.required_code
ON CONFLICT (dependency_code) DO UPDATE SET
    dependency_type = EXCLUDED.dependency_type, is_optional = EXCLUDED.is_optional;

-- ---------------------------------------------------------------------------
-- 8. knowledge_review — 4 lifecycle reviews (#11/#12/#13)
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object)
INSERT INTO governance.knowledge_review
    (review_code, object_id, review_type, reviewer, outcome, notes, reviewed_at)
SELECT r.review_code, o.id, r.review_type, r.reviewer, r.outcome, r.notes, r.reviewed_at
FROM (VALUES
    ('GO-REV-DA001-1','DA001',                'CLINICAL_REVIEW','Dr A Otieno','PASS',
        'Pneumonia diagnostic criteria confirmed against Box 2.3 / 12.16.', '2024-01-03'::timestamptz),
    ('GO-REV-DEV003-1','DEV-003',             'MEDICAL_VALIDATION',     'Dr B Njenga','PASS',
        'Rule validated against auscultation semantics (bronchial breath sounds).', '2024-01-03'::timestamptz),
    ('GO-REV-PROT-1','PROT-CAP-ADULT',        'SAFETY_REVIEW',         'Dr C Mwangi','PASS',
        'Protocol safety review passed; escalation/antibiotic steps need human authorization.', '2024-01-03'::timestamptz),
    ('GO-REV-GL-1','GL-KENYA-ASTHMA-2021',    'SAFETY_REVIEW',         'Dr B Njenga','FAIL',
        'Guideline population scope not confirmed for all target groups.', '2024-01-03'::timestamptz)
) AS r(review_code, object_code, review_type, reviewer, outcome, notes, reviewed_at)
JOIN objs o ON o.object_code = r.object_code
ON CONFLICT (review_code) DO UPDATE SET
    outcome = EXCLUDED.outcome, notes = EXCLUDED.notes;

-- ---------------------------------------------------------------------------
-- 9. knowledge_approval — 4 governance approvals (#11/#41)
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object),
     vers AS (SELECT version_code, id FROM governance.knowledge_object_version)
INSERT INTO governance.knowledge_approval
    (approval_code, object_id, version_id, approver, decision, note, approved_at)
SELECT a.approval_code, o.id, v.id, a.approver, a.decision, a.note, a.approved_at
FROM (VALUES
    ('GO-APP-DA001-1','DA001',                'GO-V-DA001-2','Dr A Otieno','APPROVED','Approved for release.', '2024-01-04'::timestamptz),
    ('GO-APP-DEV003-1','DEV-003',             'GO-V-DEV003-1','Dr A Otieno','APPROVED','Approved for release.', '2024-01-04'::timestamptz),
    ('GO-APP-PROT-1','PROT-CAP-ADULT',        'GO-V-PROT-2','Dr A Otieno','APPROVED','Approved for release.', '2024-01-04'::timestamptz),
    ('GO-APP-GL-1','GL-KENYA-ASTHMA-2021',    'GO-V-GL-1','Dr A Otieno','DEFERRED','Deferred: awaiting population validation.', '2024-01-04'::timestamptz)
) AS a(approval_code, object_code, version_code, approver, decision, note, approved_at)
JOIN objs o ON o.object_code = a.object_code
JOIN vers v ON v.version_code = a.version_code
ON CONFLICT (approval_code) DO UPDATE SET
    decision = EXCLUDED.decision, note = EXCLUDED.note;

-- ---------------------------------------------------------------------------
-- 10. knowledge_publication — 4 publish-gate records (#41): 3 PASS, 1 BLOCKED
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object),
     vers AS (SELECT version_code, id FROM governance.knowledge_object_version)
INSERT INTO governance.knowledge_publication
    (publication_code, object_id, version_id, provenance_complete, validation_passed,
     dependency_integrity, jurisdiction_ok, population_ok, safety_review_ok, clinical_review_ok, approval_ok,
     decision, decision_reason, published_by, published_at)
SELECT p.publication_code, o.id, v.id, p.provenance_complete, p.validation_passed,
       p.dependency_integrity, p.jurisdiction_ok, p.population_ok, p.safety_review_ok,
       p.clinical_review_ok, p.approval_ok,
       p.decision, p.decision_reason, p.published_by, p.published_at
FROM (VALUES
    ('GO-PUB-DA001','DA001',    'GO-V-DA001-2', true,true,true,true,true,true,true,true,'PUBLISHED','All gates passed.',                      'Dr A Otieno','2024-01-05'::timestamptz),
    ('GO-PUB-DEV003','DEV-003', 'GO-V-DEV003-1', true,true,true,true,true,true,true,true,'PUBLISHED','All gates passed.',                      'Dr A Otieno','2024-01-05'::timestamptz),
    ('GO-PUB-PROT','PROT-CAP-ADULT','GO-V-PROT-2', true,true,true,true,true,true,true,true,'PUBLISHED','All gates passed.',                    'Dr A Otieno','2024-01-05'::timestamptz),
    ('GO-PUB-GL','GL-KENYA-ASTHMA-2021','GO-V-GL-1', true,true,true,true,false,false,false,false,'BLOCKED',
        'BLOCKED: population scope not validated and safety review FAILED — must not go live (#41).', 'Dr A Otieno', NULL)
) AS p(publication_code, object_code, version_code, provenance_complete, validation_passed,
       dependency_integrity, jurisdiction_ok, population_ok, safety_review_ok, clinical_review_ok, approval_ok,
       decision, decision_reason, published_by, published_at)
JOIN objs o ON o.object_code = p.object_code
JOIN vers v ON v.version_code = p.version_code
ON CONFLICT (publication_code) DO UPDATE SET
    decision = EXCLUDED.decision, decision_reason = EXCLUDED.decision_reason;

-- ---------------------------------------------------------------------------
-- 11. knowledge_deprecation — 1 version deprecation (#8/#11): PROT-CAP-ADULT v1
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object),
     vers AS (SELECT version_code, id FROM governance.knowledge_object_version)
INSERT INTO governance.knowledge_deprecation
    (deprecation_code, object_id, version_id, deprecation_reason, replacement_object_id,
     deprecated_by, deprecated_at)
SELECT 'GO-DEPR-PROT-1', o.id, v.id,
       'Protocol v1 retired when v2 was approved — version immutability (#8), history never overwritten invisibly.',
       o.id, 'Dr A Otieno', '2024-01-05'::timestamptz
FROM objs o JOIN vers v ON v.version_code = 'GO-V-PROT-1'
WHERE o.object_code = 'PROT-CAP-ADULT'
ON CONFLICT (deprecation_code) DO UPDATE SET
    deprecation_reason = EXCLUDED.deprecation_reason,
    replacement_object_id = EXCLUDED.replacement_object_id;

-- ---------------------------------------------------------------------------
-- 12. conflict_record — 1 TEMPORAL_CONFLICT, RESOLVED (#20/#21)
--     DEV-006 (acute <21d SUPPORTS) vs DEV-007 (chronic >56d OPPOSES) both speak
--     for the same patient on cough acuity — AMEXAN never silently merges them.
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object)
INSERT INTO governance.conflict_record
    (conflict_code, object_id_a, object_id_b, conflict_type, classification, description,
     status, resolution, resolved_by, resolved_at, source_claim_a, source_claim_b)
SELECT 'GO-CONF-DEV6-7', a.id, b.id, 'TEMPORAL_CONFLICT',
       jsonb_build_object('same_jurisdiction', true, 'same_population', true,
                          'same_date', true, 'overlapping_band', false),
       'DEV-006 (acute cough <21 days SUPPORTS the bronchial frame) and DEV-007 (chronic cough >56 days OPPOSES it) can both look authoritative on a single patient — a temporal conflict on the cough-acuity frame.',
       'RESOLVED',
       'Resolution: the rules bind DISJOINT temporal bands (<21 and >56 days). Between 21 and 56 days the frame is indeterminate — keep the Box 12.5 HPI questions open instead of auto-deciding acuity.',
       'Dr A Otieno', '2024-01-04', 'HCH12-0004', 'HCH12-0004'
FROM objs a JOIN objs b ON a.object_code='DEV-006' AND b.object_code='DEV-007'
ON CONFLICT (conflict_code) DO UPDATE SET
    classification = EXCLUDED.classification, resolution = EXCLUDED.resolution,
    resolved_by = EXCLUDED.resolved_by, resolved_at = EXCLUDED.resolved_at;

-- ---------------------------------------------------------------------------
-- 13. safety_review — 4 risk classifications (#25/#26)
-- ---------------------------------------------------------------------------
WITH objs AS (SELECT object_code, id FROM governance.knowledge_object)
INSERT INTO governance.safety_review
    (safety_code, object_id, risk_class, human_in_the_loop, mitigation, reviewer, reviewed_at)
SELECT s.safety_code, o.id, s.risk_class, s.human_in_the_loop, s.mitigation, s.reviewer, s.reviewed_at
FROM (VALUES
    ('GO-SAF-HYPOX-1','PHEN-HYPOXAEMIA',  'HIGH_RISK_RECOMMENDATION', true,
        'Hypoxaemia triggers escalation; any action requires human authorization.', 'Dr B Njenga','2024-01-03'::timestamptz),
    ('GO-SAF-DEV3-1','DEV-003',           'DECISION_SUPPORT', false,
        'Evidence-rule output supports, never replaces, the clinical decision.', 'Dr B Njenga','2024-01-03'::timestamptz),
    ('GO-SAF-PROT-1','PROT-CAP-ADULT',    'HIGH_RISK_RECOMMENDATION', true,
        'Antibiotic/escalation steps require clinician authorization.', 'Dr B Njenga','2024-01-03'::timestamptz),
    ('GO-SAF-DTE-1','DTE-ASSESS-PNEUMONIA','CLINICAL_SUGGESTION', false,
        'Rendered as a clinician-editable assessment sentence (H9 §38).', 'Dr C Mwangi','2024-01-03'::timestamptz)
) AS s(safety_code, object_code, risk_class, human_in_the_loop, mitigation, reviewer, reviewed_at)
JOIN objs o ON o.object_code = s.object_code
ON CONFLICT (safety_code) DO UPDATE SET
    risk_class = EXCLUDED.risk_class, human_in_the_loop = EXCLUDED.human_in_the_loop,
    mitigation = EXCLUDED.mitigation;

-- ---------------------------------------------------------------------------
-- 14. model_registry — 2 models (#47/#48): deterministic engine ACTIVE; LLM DRAFT
--     An LLM is a language-realisation component, never the hidden source of
--     clinical truth, so it cannot be ACTIVE until reviewed and approved.
-- ---------------------------------------------------------------------------
INSERT INTO governance.model_registry
    (model_code, model_name, model_type, model_version, training_dataset_version,
     features, validation_metrics, deployment_date, approval_status, approved_by, is_active)
VALUES
    ('MODEL-DOC-CPU-1.0', 'Documentation compiler CPU', 'DETERMINISTIC', 'DOCUMENTATION-CPU-1.0', 'HUTCHISON_24_2018',
     jsonb_build_object('role','documentation_compiler','deterministic',true), jsonb_build_object('deterministic', true, 'accuracy', 1.0), '2024-01-01', 'ACTIVE', 'Dr A Otieno', true),
    ('MODEL-LLM-01', 'AMEXAN language realisation model', 'LLM', 'AMEXAN-LLM-1', NULL,
     jsonb_build_object('role','language_realisation_only'), '{}'::jsonb, NULL, 'DRAFT', NULL, false)
  ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 15. system_version — 1 master version fingerprint (#10/#17)
--     Ties the ACTUAL H8 reasoning version + H9 documentation version + the H8
--     differential ruleset the CPU computed with. Never reinterpreted later.
-- ---------------------------------------------------------------------------
INSERT INTO governance.system_version
    (system_version_code, reasoning_version_code, documentation_version_code,
     differential_version_code, engine_version, released_at, is_active)
VALUES
    ('AMEXAN-1.0.0', 'RV2024.01.001', 'RV2024.01.002', 'RV2024.01.001', 'CLINICAL-CPU-1.0', '2024-01-01', true)
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 16. PROVENANCE — one shared knowledge.provenance edge per governed object
--     (object_type = 'governance_…'). 82 edges == 2+4+5+25+7+10+8+4+4+4+1+1+4+2+1
--     governed rows. §46 law: provenance count == object count; 0 dangling.
-- =============================================================================
WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_jurisdiction', j.id, j.jurisdiction_code, 'derived_from', 1.0
FROM governance.jurisdiction j CROSS JOIN c
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_population_context', p.id, p.population_code, 'derived_from', 1.0
FROM governance.population_context p CROSS JOIN c
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_evidence_metadata', e.id, e.evidence_level_code, 'derived_from', 1.0
FROM governance.evidence_metadata e CROSS JOIN c
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'governance_knowledge_object', ko.id, ko.object_code, 'derived_from', 1.0
FROM governance.knowledge_object ko JOIN sc ON sc.claim_code = ko.source_claim_code
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'governance_knowledge_object_version', v.id, v.version_code, 'derived_from', 1.0
FROM governance.knowledge_object_version v
JOIN governance.knowledge_object ko ON ko.id = v.object_id
JOIN sc ON sc.claim_code = COALESCE(v.source_claim_code, ko.source_claim_code)
ON CONFLICT DO NOTHING;

WITH objs AS (SELECT object_code, id FROM governance.knowledge_object),
     sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'governance_knowledge_relationship', r.id, r.relationship_code, 'derived_from', 1.0
FROM governance.knowledge_relationship r JOIN sc ON sc.claim_code = r.source_claim_code
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'governance_knowledge_dependency', d.id, d.dependency_code, 'derived_from', 1.0
FROM governance.knowledge_dependency d JOIN sc ON sc.claim_code = d.source_claim_code
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE WHEN rev.review_code = 'GO-REV-GL-1' THEN (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0005')
            ELSE (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018') END,
       'governance_knowledge_review', rev.id, rev.review_code, 'derived_from', 1.0
FROM governance.knowledge_review rev
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE WHEN app.approval_code = 'GO-APP-GL-1' THEN (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0005')
            ELSE (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018') END,
       'governance_knowledge_approval', app.id, app.approval_code, 'derived_from', 1.0
FROM governance.knowledge_approval app
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE WHEN pub.publication_code = 'GO-PUB-GL' THEN (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0005')
            ELSE (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018') END,
       'governance_knowledge_publication', pub.id, pub.publication_code, 'derived_from', 1.0
FROM governance.knowledge_publication pub
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_knowledge_deprecation', d.id, d.deprecation_code, 'derived_from', 1.0
FROM governance.knowledge_deprecation d CROSS JOIN c
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0004')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_conflict_record', f.id, f.conflict_code, 'derived_from', 1.0
FROM governance.conflict_record f CROSS JOIN c
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT CASE WHEN s.safety_code='GO-SAF-DTE-1' THEN (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018')
            WHEN s.safety_code='GO-SAF-HYPOX-1' THEN (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0016')
            ELSE (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH12-0018') END,
       'governance_safety_review', s.id, s.safety_code, 'derived_from', 1.0
FROM governance.safety_review s
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_model_registry', m.id, m.model_code, 'derived_from', 1.0
FROM governance.model_registry m CROSS JOIN c
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code='HCH1-0001')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_system_version', s.id, s.system_version_code, 'derived_from', 1.0
FROM governance.system_version s CROSS JOIN c
ON CONFLICT DO NOTHING;

-- =============================================================================
-- RUNTIME tables (rule_execution / audit_event / provenance_record /
-- clinical_snapshot / reasoning_snapshot / documentation_snapshot) are
-- intentionally EMPTY at seed time — the CPU records them per computation,
-- exactly as H7/H8/H9 leave their runtime tables empty at rest.
-- =============================================================================