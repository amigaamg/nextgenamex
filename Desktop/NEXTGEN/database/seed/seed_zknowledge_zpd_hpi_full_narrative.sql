-- =============================================================================
-- AMEXAN Universal Symptom Engine — Seed D: full HPI narrative groups
-- =============================================================================
-- Migration 024 extended documentation_group to the full internal-medicine
-- narrative order:
--
--   presenting → chronology → character → sputum → associated → systemic →
--   ent_gi → risk → previous → health_seeking → severity → functional →
--   examination
--
-- This seed defines the facts + HPI template rows for the four NEW groups
-- (chronology, previous, health_seeking, severity) so the DocumentationEngine
-- renders them as structured prose rather than leaving them empty:
--
--   chronology     — baseline / onset timeline ("previously well until...")
--   previous       — first episode vs recurrent, prior diagnosis/treatment
--   health_seeking — prior consultation, self-medication, treatment response,
--                    reason for the current presentation
--   severity       — progression, complications, red flags
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. New fact definitions for the narrative groups
-- ---------------------------------------------------------------------------

INSERT INTO clinical.fact_definition (code, name, data_type, description) VALUES
   ('PREVIOUSLY_WELL',       'Previously well before this illness', 'boolean', 'Whether the patient was generally well until the onset of the current illness'),
   ('EPISODE_RECURRENCE',    'Episode recurrence',                  'coded',   'Whether this is the first episode or a recurrent presentation'),
   ('PRIOR_DIAGNOSIS',       'Prior diagnosis of this condition',   'text',    'Earlier diagnosis of the same / related condition'),
   ('PRIOR_TREATMENT',       'Prior treatment for this illness',    'text',    'Treatment previously received for this illness'),
   ('PRIOR_CONSULTATION',    'Prior consultation sought',           'coded',   'Whether medical advice was sought before this visit'),
   ('SELF_MEDICATION',       'Self-medication used',                'coded',   'Whether the patient self-medicated before presentation'),
   ('TREATMENT_RESPONSE',    'Response to prior treatment',         'coded',   'How the illness responded to prior treatment'),
   ('REASON_PRESENTATION',   'Reason for current presentation',     'text',    'Why the patient presents now'),
   ('SYMPTOM_PROGRESSION',   'Progression of symptoms',             'coded',   'Worsening / stable / improving course of the illness')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. HPI templates for the new groups (cough clinical object)
-- ---------------------------------------------------------------------------

DELETE FROM knowledge.symptom_hpi_template
 WHERE symptom_id = 'f0b00000-0000-0000-0000-000000000001'
   AND documentation_group IN ('chronology', 'previous', 'health_seeking', 'severity');

-- 2a. Chronology — baseline and onset timeline
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'chronology', 'PREVIOUSLY_WELL', 'true',  'previously well until the onset of the current illness', 10),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'chronology', 'PREVIOUSLY_WELL', 'false', 'underlying chronic illness before this episode', 10)
;

-- 2b. Previous episodes — recurrence, prior diagnosis and treatment
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'previous', 'EPISODE_RECURRENCE', 'FIRST',     'this is the first episode', 20),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'previous', 'EPISODE_RECURRENCE', 'RECURRENT', 'recurrent episodes', 20),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'previous', 'PRIOR_DIAGNOSIS',    NULL,        'previously diagnosed with {value}', 30),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'previous', 'PRIOR_TREATMENT',    NULL,        'previously treated with {value}', 35)
;

-- 2c. Health-seeking behaviour
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'PRIOR_CONSULTATION', 'YES', 'has sought prior medical consultation', 40),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'PRIOR_CONSULTATION', 'NO',  'no prior medical consultation', 40),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'SELF_MEDICATION',    'YES', 'self-medication used', 45),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'SELF_MEDICATION',    'NO',  'no self-medication', 45),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'TREATMENT_RESPONSE', 'IMPROVED',  'symptoms improved with treatment', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'TREATMENT_RESPONSE', 'UNCHANGED', 'no response to treatment', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'TREATMENT_RESPONSE', 'WORSENED',  'symptoms worsened with treatment', 50),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'health_seeking', 'REASON_PRESENTATION', NULL,       'presenting because {value}', 55)
;

-- 2d. Severity — progression, complications, red flags
INSERT INTO knowledge.symptom_hpi_template
       (symptom_id, section, documentation_group, fact_definition_code, fact_value, phrase_template, sort_order) VALUES
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'severity', 'SYMPTOM_PROGRESSION', 'WORSENING', 'progressive worsening', 60),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'severity', 'SYMPTOM_PROGRESSION', 'STABLE',    'stable course', 60),
   ('f0b00000-0000-0000-0000-000000000001', 'history', 'severity', 'SYMPTOM_PROGRESSION', 'IMPROVING', 'improving', 60)
;
