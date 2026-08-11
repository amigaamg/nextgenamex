-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H3 seed zq4: worked-example wiring
-- =============================================================================
-- Completes H3 by making the UNIVERSAL L1 foundation actually askable and by
-- wiring the mandatory levels of the cough worked example.
--
-- The H3 spec §7 mandatory layers:
--   L1 UNIVERSAL  — the universal history foundations (Q001-Q005) are MANDATORY.
--   L2 SYMPTOM    — symptom banks activate when the symptom is present.
--   L3 SAFETY     — red-flag probes (haemoptysis, dyspnoea severity) outrank all.
--
-- Gap being closed: the H2 universal questions (OPEN_PRESENTING_CONCERN,
-- SYMPTOM_ONSET/DURATION/SEVERITY/ASSOCIATED) had no fact binding, so the CPU
-- correctly skipped them (a question that captures nothing has no value). zq4
-- binds each to a universal fact, marks them MANDATORY, and adds provenance.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. universal facts — generic fact definitions for the universal foundations
-- ---------------------------------------------------------------------------
-- REASON_PRESENTATION already exists (text). The other four universal dimensions
-- get generic (symptom-agnostic) fact definitions.
INSERT INTO clinical.fact_definition (code, name, description, data_type, is_active) VALUES
   ('SYMPTOM_ONSET_TEXT',   'Symptom onset description', 'When and how the presenting symptom started (free text).', 'text', true),
   ('SYMPTOM_DURATION_DAYS','Symptom duration (days)',   'How long the presenting symptom has been present.',       'numeric', true),
   ('SYMPTOM_SEVERITY_SCORE','Symptom severity (1-10)',  'Patient-reported severity on the 1-10 scale.',            'numeric', true),
   ('SYMPTOM_ASSOCIATED_TEXT','Associated symptoms text','Other symptoms the patient has noticed, in their own words.', 'text', true)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. bind the universal questions to facts (so the CPU can ask and capture)
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.question_fact (question_id, fact_definition_code, unit_code)
SELECT q.id, x.fact_definition_code, x.unit_code
FROM (VALUES
   ('OPEN_PRESENTING_CONCERN', 'REASON_PRESENTATION',     NULL),
   ('SYMPTOM_ONSET',           'SYMPTOM_ONSET_TEXT',      NULL),
   ('SYMPTOM_DURATION',        'SYMPTOM_DURATION_DAYS',   'days'),
   ('SYMPTOM_SEVERITY',        'SYMPTOM_SEVERITY_SCORE',  NULL),
   ('SYMPTOM_ASSOCIATED',      'SYMPTOM_ASSOCIATED_TEXT', NULL)
) AS x(question_code, fact_definition_code, unit_code)
JOIN knowledge.question q ON q.question_code = x.question_code
ON CONFLICT (question_id, fact_definition_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. L1 UNIVERSAL — the foundation is MANDATORY, asked first
-- ---------------------------------------------------------------------------
-- priority 0-3 so the open narrative, onset and duration lead the interview
-- (H1-0004 open-ended start; H1-0013 basic-history scheme; H1-0011 severity).
INSERT INTO knowledge.question_requirement (question_id, requirement_level, condition, priority)
SELECT q.id, x.requirement_level, '{}', x.priority
FROM (VALUES
   ('OPEN_PRESENTING_CONCERN', 'mandatory', 1),
   ('SYMPTOM_ONSET',           'mandatory', 2),
   ('SYMPTOM_DURATION',        'mandatory', 3),
   ('SYMPTOM_SEVERITY',        'mandatory', 4),
   ('SYMPTOM_ASSOCIATED',      'mandatory', 5)
) AS x(question_code, requirement_level, priority)
JOIN knowledge.question q ON q.question_code = x.question_code
ON CONFLICT (question_id, requirement_level, condition) DO UPDATE SET
    priority = EXCLUDED.priority;

-- ---------------------------------------------------------------------------
-- 4. provenance — universal facts + question bindings derive from H1 claims
-- ---------------------------------------------------------------------------
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship)
SELECT s.claim_id, x.object_type, x.object_id::uuid, x.object_code, 'derived_from'
FROM (VALUES
   ('HCH1-0004', 'fact_definition', 'f81442af-fec7-5157-b7bc-e327ac5565bc', 'REASON_PRESENTATION'),
   ('HCH1-0013', 'fact_definition', '1ef5f619-3685-52bc-9e37-f3fbff516b70', 'SYMPTOM_ONSET_TEXT'),
   ('HCH1-0013', 'fact_definition', 'd4580d4e-db2e-55f2-b4f6-b89c6e85d6af', 'SYMPTOM_DURATION_DAYS'),
   ('HCH1-0011', 'fact_definition', 'da01b546-109b-5a5e-b79c-09b23772fa45', 'SYMPTOM_SEVERITY_SCORE'),
   ('HCH1-0004', 'fact_definition', '550833e7-c142-5df5-9949-54722dc5436d', 'SYMPTOM_ASSOCIATED_TEXT'),
   ('HCH1-0004', 'question_fact',   'b9768bde-c083-5290-8bf1-54995276f69e', 'OPEN_PRESENTING_CONCERN'),
   ('HCH1-0013', 'question_fact',   '43e56497-e80c-5e5a-b9ce-aef6306c1e68', 'SYMPTOM_ONSET'),
   ('HCH1-0013', 'question_fact',   '4f3a5697-a741-5fab-9e51-8fb651329e3b', 'SYMPTOM_DURATION'),
   ('HCH1-0011', 'question_fact',   '573b303b-88ce-5077-9c3a-e5a02f75952b', 'SYMPTOM_SEVERITY'),
   ('HCH1-0004', 'question_fact',   '8d927648-2665-5187-b746-440e32ca0b2d', 'SYMPTOM_ASSOCIATED')
) AS x(claim_code, object_type, object_id, object_code)
JOIN knowledge.source_claim s ON s.claim_code = x.claim_code
ON CONFLICT (claim_id, object_type, object_id) DO NOTHING;
