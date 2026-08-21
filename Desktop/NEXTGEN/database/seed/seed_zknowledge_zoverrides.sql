-- =============================================================================
-- AMEXAN Phase 2 — Seed Z9
-- UNIVERSAL KNOWLEDGE OVERRIDE / INTELLIGENCE ADAPTATION LAYER
-- =============================================================================
--
-- PURPOSE
-- -------
-- Z9 is the contextual intelligence layer of AMEXAN.
--
-- It allows canonical medical knowledge to remain immutable while allowing
-- AMEXAN to determine the CURRENT operational interpretation of that knowledge
-- according to:
--
--     1. AMEXAN GLOBAL DEFAULT
--     2. COUNTRY / JURISDICTION
--     3. HEALTH SYSTEM
--     4. FACILITY
--     5. DEPARTMENT / SERVICE
--     6. CLINICAL SPECIALTY
--     7. PROFESSIONAL / CLINICIAN
--     8. PATIENT-SPECIFIC CONTEXT
--
-- The canonical knowledge node is NEVER mutated.
--
-- Resolution concept:
--
--     DEFAULT
--        ↓
--     LOCAL
--        ↓
--     WHY
--        ↓
--     CURRENT
--
-- The runtime intelligence engine selects the highest applicable active
-- override according to scope, version, context and priority.
--
-- IMPORTANT
-- ---------
-- Z9 does NOT replace:
--     Z3 = Symptoms
--     Z4 = Questions
--     Z5 = Phenotypes / mechanisms / clinical concepts
--     Z6 = Conditions + knowledge graph
--     Z7 = Clinical rules
--     Z8 = investigations / management / additional knowledge
--
-- Z9 determines HOW canonical knowledge is operationalized in context.
--
-- Canonical medical knowledge remains immutable.
-- =============================================================================


-- =============================================================================
-- 1. AMEXAN GLOBAL DEFAULT
-- =============================================================================
--
-- The global scope is the baseline AMEXAN interpretation.
--
-- scope_entity_id = NULL because the global baseline does not belong to a
-- particular facility, country or clinician.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1.1 Pneumonia investigation
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000001',
    'OVR-PNEUMONIA-DEFAULT-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 65,
        'investigation', 'INV-CXR',
        'note',
            'Chest radiography may support evaluation of suspected pneumonia.'
    ),
    'AMEXAN baseline operationalization of the pneumonia investigation rule.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 1.2 Updated global pneumonia interpretation
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version,
    supersedes_id
)
VALUES
(
    'f1200000-0000-0000-0000-000000000002',
    'OVR-PNEUMONIA-DEFAULT-V2',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 70,
        'investigation', 'INV-CXR',
        'note',
            'Do not interpret chest radiography as mandatory in every uncomplicated outpatient presentation; escalate investigation according to severity, diagnostic uncertainty, red flags and clinical context.'
    ),
    'Updated AMEXAN baseline to distinguish diagnostic support from universal mandatory testing.',
    'active',
    2,
    'f1200000-0000-0000-0000-000000000001'
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. UNIVERSAL SAFETY OVERRIDES
-- =============================================================================
--
-- Safety rules should have very high operational priority.
-- A contextual override must never silently downgrade a safety rule.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 2.1 Hypoxaemia
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000003',
    'OVR-HYPOXAEMIA-DEFAULT-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000002',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 100,
        'safety', true,
        'preserve_red_flag', true,
        'note',
            'Safety escalation for clinically significant hypoxaemia must not be downgraded by ordinary local preference.'
    ),
    'AMEXAN safety invariant for hypoxaemia.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- 2.2 Haemoptysis
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000004',
    'OVR-HAEMOPTYSIS-DEFAULT-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000003',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 95,
        'safety', true,
        'preserve_red_flag', true,
        'note',
            'Haemoptysis requires clinical assessment; urgency depends on severity, haemodynamic/respiratory status and clinical context.'
    ),
    'AMEXAN safety baseline for haemoptysis.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. UNIVERSAL TB OVERRIDES
-- =============================================================================


INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000005',
    'OVR-TB-SCREEN-DEFAULT-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000001',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 90,
        'investigation', 'SPUTUM_AFB',
        'preserve_red_flags', true,
        'note',
            'Suspected pulmonary TB should proceed through the applicable diagnostic pathway rather than being treated as a generic chronic cough.'
    ),
    'AMEXAN baseline TB diagnostic pathway.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000006',
    'OVR-TB-CONTACT-DEFAULT-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000005',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 85,
        'investigation', 'SPUTUM_AFB',
        'contact_history', true,
        'symptom_screening', true,
        'note',
            'Known TB exposure combined with compatible respiratory symptoms increases the requirement for TB evaluation.'
    ),
    'AMEXAN baseline TB contact pathway.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. CONDITION-LEVEL OVERRIDES
-- =============================================================================
--
-- Z9 is not limited to rules.
--
-- Any knowledge node may eventually be overridden:
--
--     rule
--     condition
--     symptom
--     phenotype
--     investigation
--     management
--     protocol
--     threshold
--     question
--     recommendation
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Pneumonia
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000007',
    'OVR-CONDITION-PNEUMONIA-DEFAULT-V1',
    'condition',
    'f1000000-0000-0000-0000-000000000001',
    'global',
    NULL,
    jsonb_build_object(
        'classification',
            jsonb_build_array(
                'community_acquired',
                'healthcare_associated',
                'hospital_acquired',
                'ventilator_associated'
            ),
        'severity_context_required', true,
        'age_context_required', true,
        'host_context_required', true,
        'note',
            'Pneumonia interpretation must incorporate age, setting, severity, host factors and epidemiological context.'
    ),
    'Universal AMEXAN pneumonia contextualization.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- Tuberculosis
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000008',
    'OVR-CONDITION-TB-DEFAULT-V1',
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    'global',
    NULL,
    jsonb_build_object(
        'pulmonary', true,
        'extrapulmonary', true,
        'host_context_required', true,
        'exposure_context_required', true,
        'note',
            'TB intelligence must not be restricted to pulmonary disease; extrapulmonary and host-specific presentations must remain available.'
    ),
    'Universal AMEXAN tuberculosis knowledge representation.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. SYMPTOM-LEVEL OVERRIDES
-- =============================================================================
--
-- Symptoms are the entry point to clinical reasoning.
--
-- A symptom must therefore be interpreted according to patient context.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Cough
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000009',
    'OVR-SYMPTOM-COUGH-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000001',
    'global',
    NULL,
    jsonb_build_object(
        'mandatory_dimensions',
            jsonb_build_array(
                'onset',
                'duration',
                'course',
                'productivity',
                'sputum',
                'haemoptysis',
                'associated_symptoms',
                'exposures',
                'red_flags'
            ),
        'context_dimensions',
            jsonb_build_array(
                'age',
                'sex',
                'pregnancy',
                'smoking',
                'immunocompromise',
                'occupation',
                'environment'
            ),
        'note',
            'Cough must be characterized before disease-level reasoning.'
    ),
    'AMEXAN Universal Symptom Intelligence Architecture baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- Fever
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-00000000000a',
    'OVR-SYMPTOM-FEVER-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000002',
    'global',
    NULL,
    jsonb_build_object(
        'mandatory_dimensions',
            jsonb_build_array(
                'onset',
                'duration',
                'pattern',
                'maximum_temperature',
                'associated_symptoms',
                'exposures',
                'medications',
                'red_flags'
            ),
        'context_dimensions',
            jsonb_build_array(
                'age',
                'immunocompromise',
                'pregnancy',
                'travel',
                'epidemiology'
            ),
        'note',
            'Fever must be interpreted according to age, host status and epidemiological context.'
    ),
    'AMEXAN Universal Symptom Intelligence Architecture baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- Dyspnoea
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-00000000000b',
    'OVR-SYMPTOM-DYSPNOEA-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000003',
    'global',
    NULL,
    jsonb_build_object(
        'mandatory_dimensions',
            jsonb_build_array(
                'onset',
                'duration',
                'severity',
                'rest_vs_exertion',
                'orthopnoea',
                'paroxysmal_nocturnal_dyspnoea',
                'associated_chest_pain',
                'wheeze',
                'stridor',
                'syncope',
                'cyanosis'
            ),
        'mandatory_measurements',
            jsonb_build_array(
                'SPO2',
                'RESPIRATORY_RATE',
                'HEART_RATE'
            ),
        'safety_priority', 100,
        'note',
            'Dyspnoea is a symptom requiring immediate severity assessment before etiological reasoning.'
    ),
    'AMEXAN universal emergency-aware dyspnoea baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- Haemoptysis
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-00000000000c',
    'OVR-SYMPTOM-HAEMOPTYSIS-DEFAULT-V1',
    'symptom',
    'f0b00000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(
        'mandatory_dimensions',
            jsonb_build_array(
                'amount',
                'frequency',
                'duration',
                'colour',
                'clots',
                'associated_dyspnoea',
                'chest_pain',
                'fever',
                'weight_loss',
                'smoking',
                'TB_exposure'
            ),
        'safety_priority', 95,
        'note',
            'Haemoptysis requires characterization of severity and source before differential diagnosis.'
    ),
    'AMEXAN universal haemoptysis assessment baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. QUESTION-LEVEL OVERRIDES
-- =============================================================================
--
-- This is particularly important for AMEXAN because the question engine is
-- DATA-driven.
--
-- Z9 can therefore adapt questioning without rewriting Z4.
--
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Cough productivity
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-00000000000d',
    'OVR-QUESTION-COUGH-PRODUCTIVITY-DEFAULT-V1',
    'question',
    'f0c10000-0000-0000-0000-000000000013',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 40,
        'required', true,
        'documentation_dimension', 'COUGH_PRODUCTIVITY',
        'note',
            'Productivity is a core characterization dimension of cough.'
    ),
    'AMEXAN universal cough assessment.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- -----------------------------------------------------------------------------
-- Cough duration
-- -----------------------------------------------------------------------------

INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-00000000000e',
    'OVR-QUESTION-COUGH-DURATION-DEFAULT-V1',
    'question',
    'f0c10000-0000-0000-0000-000000000011',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 30,
        'required', true,
        'numeric', true,
        'unit', 'days',
        'note',
            'Duration should preferably be stored numerically to support temporal reasoning.'
    ),
    'AMEXAN temporal reasoning baseline.',
    'active',
    1
)
  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. FACILITY-LEVEL OVERRIDE EXAMPLES
-- =============================================================================
--
-- These are intentionally examples.
--
-- The actual facility UUID must come from the facility/organization registry.
--
-- =============================================================================


/*
INSERT INTO knowledge.knowledge_override
(
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'OVR-PNEUMONIA-FACILITY-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'facility',
    '<REAL-FACILITY-UUID>',
    jsonb_build_object(
        'priority', 75,
        'investigation', 'INV-CXR',
        'availability',
            jsonb_build_object(
                '24_hours', true,
                'weekends', true
            ),
        'note',
            'Facility has continuous radiography access.'
    ),
    'Facility-specific operational availability.',
    'active',
    1
)
 ON CONFLICT DO NOTHING;
*/


-- =============================================================================
-- 15. EXPLICIT RETIREMENT EXAMPLE
-- =============================================================================
--
-- Historical knowledge is retained.
--
-- It is NOT deleted.
--
-- Runtime resolution ignores retired versions.
--
-- =============================================================================


INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version,
    supersedes_id
)
VALUES
(
    'f1200000-0000-0000-0000-000000000010',
    'OVR-PNEUMONIA-DEFAULT-V4-RETIRED',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(
        'priority', 60,
        'investigation', 'INV-CXR'
    ),
    'Historical example retained for auditability.',
    'retired',
    4,
    NULL
)
 ON CONFLICT DO NOTHING;


-- =============================================================================
-- 16. UNIVERSAL OVERRIDE SAFETY PRINCIPLES
-- =============================================================================
--
-- These are represented as configuration semantics for the runtime engine.
--
-- =============================================================================


INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000011',
    'OVR-AMEXAN-SAFETY-INVARIANTS-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000002',
    'global',
    NULL,
    jsonb_build_object(
        'override_policy',
            jsonb_build_object(
                'allow_downgrade_safety', false,
                'allow_disable_red_flag', false,
                'allow_remove_contraindication', false,
                'allow_remove_emergency_action', false,
                'allow_remove_required_context', false,
                'allow_reduce_evidence_level', false
            ),
        'precedence',
            jsonb_build_array(
                'patient_safety',
                'legal_requirement',
                'current_approved_guideline',
                'institutional_policy',
                'AMEXAN_DEFAULT',
                'clinician_preference'
            )
    ),
    'AMEXAN universal safety invariants.',
    'active',
    1
)
 ON CONFLICT DO NOTHING;


-- =============================================================================
-- 17. KNOWLEDGE CONFLICT HANDLING
-- =============================================================================
--
-- When two applicable overrides disagree, AMEXAN must NOT silently choose one
-- merely because it was inserted later.
--
-- Runtime resolution should consider:
--
--     evidence
--     scope
--     safety
--     specificity
--     priority
--     version
--     applicability
--
-- =============================================================================


INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000012',
    'OVR-AMEXAN-CONFLICT-RESOLUTION-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(
        'resolution_policy',
            jsonb_build_object(
                'safety_first', true,
                'specificity_first', true,
                'evidence_first', true,
                'latest_active_version', true,
                'explicit_conflict_required', true,
                'never_silent', true
            ),
        'scope_precedence',
            jsonb_build_array(
                'patient',
                'clinician',
                'department',
                'facility',
                'health_system',
                'country',
                'global'
            )
    ),
    'AMEXAN deterministic contextual knowledge resolution policy.',
    'active',
    1
)
 ON CONFLICT DO NOTHING;


-- =============================================================================
-- 18. FINAL AMEXAN DEFAULT INTELLIGENCE CONTRACT
-- =============================================================================
--
-- The final current baseline establishes the intended architecture:
--
-- canonical truth
--       +
-- contextual interpretation
--       +
-- provenance
--       +
-- versioning
--       +
-- safety
--       =
-- explainable clinical intelligence
--
-- =============================================================================


INSERT INTO knowledge.knowledge_override
(
    id,
    override_code,
    target_type,
    target_id,
    scope_code,
    scope_entity_id,
    config,
    reason,
    status,
    version
)
VALUES
(
    'f1200000-0000-0000-0000-000000000013',
    'OVR-AMEXAN-INTELLIGENCE-CONTRACT-V1',
    'rule',
    'f1100000-0000-0000-0000-000000000004',
    'global',
    NULL,
    jsonb_build_object(
        'architecture', 'AMEXAN_UNIVERSAL_CLINICAL_INTELLIGENCE',
        'knowledge_model',
            jsonb_build_array(
                'symptoms',
                'facts',
                'questions',
                'phenotypes',
                'mechanisms',
                'conditions',
                'risk_factors',
                'investigations',
                'management',
                'complications',
                'red_flags',
                'rules',
                'guidelines',
                'relationships'
            ),
        'context_model',
            jsonb_build_array(
                'age',
                'sex',
                'pregnancy',
                'host_status',
                'comorbidities',
                'medications',
                'allergies',
                'exposures',
                'epidemiology',
                'facility',
                'department',
                'clinician',
                'jurisdiction'
            ),
        'resolution_model',
            jsonb_build_array(
                'DEFAULT',
                'LOCAL',
                'WHY',
                'CURRENT'
            ),
        'immutability', true,
        'explainability', true,
        'provenance_required', true,
        'versioning_required', true,
        'safety_invariants', true
    ),
    'AMEXAN Universal Clinical Intelligence contract.',
    'active',
    1
)
 ON CONFLICT DO NOTHING;