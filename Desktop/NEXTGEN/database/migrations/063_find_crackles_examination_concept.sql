-- =============================================================================
-- 063. FIND-CRACKLES EXAMINATION CONCEPT
-- =============================================================================
--
-- The machine benchmark proves examination feeds the same reasoning substrate
-- as history by capturing crackles through the ExaminationInterpreter
-- (finding code → fact). The finding code FIND-CRACKLES was never registered
-- in knowledge.examination_concept, so resolveFinding() returned nothing and
-- capture failed with "Unable to resolve examination finding".
--
-- Register it against the canonical CRACKLES fact definition (boolean),
-- mirroring the existing respiratory auscultation concepts.
-- =============================================================================

INSERT INTO knowledge.examination_concept
    (code, domain_code, fact_definition_code, name, short_label, description,
     body_system_code, is_mandatory, base_priority, technique_codes,
     capture_method_codes, applies_to_context_codes, status)
VALUES
    ('FIND-CRACKLES', 'EXAM-RESPIRATORY', 'CRACKLES',
     'Crackles', 'Crackles', 'Discontinuous adventitious breath sounds (crackles/crepitations).',
     'respiratory', false, 100, ARRAY['AUSCULTATION'],
     ARRAY['observation'], ARRAY['all_ages'], 'active')
ON CONFLICT (code) DO NOTHING;