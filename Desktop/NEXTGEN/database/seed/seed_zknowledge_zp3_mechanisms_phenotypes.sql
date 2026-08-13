-- =============================================================================
-- AMEXAN Phase 2 â€” Seed ZP3: Phase 1E mechanisms + phenotypes
-- =============================================================================
-- Adds the three mechanisms (granulomatous infection, pulmonary congestion,
-- gastroesophageal reflux) and three phenotypes (airway-wheeze, CHF-congestive,
-- reflux-cough) that complete the five-disease MVP graph. Mechanisms and
-- phenotypes are REUSABLE patterns â€” never disease-owned.
-- =============================================================================

INSERT INTO knowledge.mechanism (id, concept_id, mechanism_code, canonical_name, description, body_system_code) VALUES
   ('f0e00000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-00000000001c', 'MECH-GRANULOMATOUS-INFECTION',
    'Chronic granulomatous pulmonary infection', 'Persistent host-pathogen interaction producing chronic pulmonary disease', 'RESPIRATORY'),
   ('f0e00000-0000-0000-0000-000000000006', 'f0a00000-0000-0000-0000-00000000001d', 'MECH-PULMONARY-CONGESTION',
    'Pulmonary vascular congestion', 'Raised pulmonary venous pressure producing interstitial/alveolar fluid accumulation', 'CARDIOVASCULAR'),
   ('f0e00000-0000-0000-0000-000000000007', 'f0a00000-0000-0000-0000-00000000001e', 'MECH-GASTROESOPHAGEAL-REFLUX',
    'Gastroesophageal reflux', 'Retrograde movement of gastric contents causing oesophageal/airway irritation', 'GASTROINTESTINAL')
ON CONFLICT (mechanism_code) DO NOTHING;

INSERT INTO knowledge.mechanism_feature (mechanism_id, feature_type, feature_code, weight, polarity) VALUES
   ('f0e00000-0000-0000-0000-000000000005', 'fact',    'COUGH_DURATION_DAYS', 0.9, 'positive'),
   ('f0e00000-0000-0000-0000-000000000005', 'fact',    'WEIGHT_LOSS',         0.8, 'positive'),
   ('f0e00000-0000-0000-0000-000000000005', 'fact',    'NIGHT_SWEATS',        0.8, 'positive'),
   ('f0e00000-0000-0000-0000-000000000005', 'fact',    'TB_CONTACT',          0.7, 'positive'),
   ('f0e00000-0000-0000-0000-000000000006', 'fact',    'DYSPNOEA_PRESENT',    1.0, 'positive'),
   ('f0e00000-0000-0000-0000-000000000006', 'fact',    'ORTHOPNOEA',          0.9, 'positive'),
   ('f0e00000-0000-0000-0000-000000000006', 'fact',    'PND',                 0.9, 'positive'),
   ('f0e00000-0000-0000-0000-000000000006', 'fact',    'CRACKLES',            0.7, 'positive'),
   ('f0e00000-0000-0000-0000-000000000007', 'fact',    'HEARTBURN',           1.0, 'positive'),
   ('f0e00000-0000-0000-0000-000000000007', 'fact',    'COUGH_PRESENT',       0.5, 'positive')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype (id, concept_id, phenotype_code, canonical_name, description) VALUES
   ('f0f00000-0000-0000-0000-000000000005', 'f0a00000-0000-0000-0000-00000000003b', 'PHEN-AIRWAY-WHEEZE',
    'Variable obstructive airway pattern', 'Episodic cough and breathlessness with wheeze suggesting variable airflow obstruction'),
   ('f0f00000-0000-0000-0000-000000000006', 'f0a00000-0000-0000-0000-00000000001a', 'PHEN-CHF-CONGESTIVE',
    'Cardiopulmonary congestion pattern', 'Cough and dyspnoea with congestion features (orthopnoea, PND, oedema) suggesting cardiac pump failure'),
   ('f0f00000-0000-0000-0000-000000000007', 'f0a00000-0000-0000-0000-00000000001b', 'PHEN-REFLUX-COUGH',
    'Reflux-associated cough pattern', 'Cough temporally associated with reflux/regurgitation features')
ON CONFLICT (phenotype_code) DO NOTHING;

INSERT INTO knowledge.phenotype_feature (phenotype_id, feature_type, feature_code, operator, value, weight, polarity) VALUES
   ('f0f00000-0000-0000-0000-000000000005', 'fact', 'WHEEZE_PRESENT',    'eq',  '"YES"',    1.0, 'positive'),
   ('f0f00000-0000-0000-0000-000000000005', 'fact', 'DYSPNOEA_PRESENT',  'eq',  '"YES"',    0.7, 'positive'),
   ('f0f00000-0000-0000-0000-000000000005', 'fact', 'COUGH_PRESENT',     'eq',  '"YES"',    0.6, 'positive'),
   ('f0f00000-0000-0000-0000-000000000006', 'fact', 'DYSPNOEA_PRESENT',  'eq',  '"YES"',    1.0, 'positive'),
   ('f0f00000-0000-0000-0000-000000000006', 'fact', 'ORTHOPNOEA',        'eq',  '"YES"',    0.9, 'positive'),
   ('f0f00000-0000-0000-0000-000000000006', 'fact', 'PND',               'eq',  '"YES"',    0.9, 'positive'),
   ('f0f00000-0000-0000-0000-000000000006', 'fact', 'CRACKLES',          'eq',  'true',     0.6, 'positive'),
   ('f0f00000-0000-0000-0000-000000000006', 'fact', 'PERIPHERAL_OEDEMA', 'eq',  'true',     0.7, 'positive'),
   ('f0f00000-0000-0000-0000-000000000007', 'fact', 'HEARTBURN',         'eq',  '"YES"',    1.0, 'positive'),
   ('f0f00000-0000-0000-0000-000000000007', 'fact', 'COUGH_PRESENT',     'eq',  '"YES"',    0.6, 'positive'),
   ('f0f00000-0000-0000-0000-000000000007', 'fact', 'COUGH_DURATION_DAYS','gt', '21',       0.4, 'positive')
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.phenotype_documentation (phenotype_id, documentation_phrase, language_code, is_preferred) VALUES
   ('f0f00000-0000-0000-0000-000000000005', 'Variable obstructive airway pattern with wheeze', 'en', true),
   ('f0f00000-0000-0000-0000-000000000006', 'Cardiopulmonary congestion pattern', 'en', true),
   ('f0f00000-0000-0000-0000-000000000007', 'Reflux-associated cough pattern', 'en', true)
ON CONFLICT DO NOTHING;
