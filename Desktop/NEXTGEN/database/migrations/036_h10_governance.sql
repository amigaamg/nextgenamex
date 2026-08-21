-- =============================================================================
-- AMEXAN MEDICAL KNOWLEDGE COMPILER — H10 MIGRATION 036
-- PROVENANCE, GOVERNANCE, SAFETY, CONFLICT MANAGEMENT & REPRODUCIBILITY
-- =============================================================================
--
-- H10 = TRUST / GOVERNANCE LAYER OF THE AMEXAN CLINICAL OPERATING SYSTEM
--
-- CONSTITUTIONAL PURPOSE
-- ---------------------
-- H10 governs:
--   1. Provenance
--   2. Versioning
--   3. Governance
--   4. Auditability
--   5. Knowledge lifecycle
--   6. Safety controls
--   7. Conflict management
--   8. Reproducibility
--
-- H10 DOES NOT REPLACE H1-H9.
--
-- H1  = source / evidence backbone
-- H2  = clinical event / temporal backbone
-- H3  = patient clinical state
-- H4  = fact / phenotype / mechanism knowledge
-- H5  = question / capture / source hierarchy
-- H6  = investigation / protocol architecture
-- H7  = investigation execution + results
-- H8  = clinical reasoning / differential / uncertainty
-- H9  = documentation compilation / rendering
-- H10 = trust, governance, provenance, safety, audit and replay
--
-- ARCHITECTURAL LAW
-- -----------------
-- PostgreSQL = governed medical knowledge + configuration + immutable lineage
-- CPU        = execution / validation / replay / audit recording
-- UI         = presentation only
--
-- THE DATABASE MUST NEVER:
--   * silently overwrite clinical knowledge history
--   * silently merge contradictory medical sources
--   * publish unreviewed high-risk clinical logic
--   * treat an LLM as the source of clinical truth
--   * convert prose into an undocumented clinical fact
--   * allow an inactive / retired rule to execute as active knowledge
--   * lose the exact version of knowledge used for a clinical computation
--
-- RUNTIME TABLES ARE EMPTY AT SEED TIME.
-- The CPU creates runtime rows during actual clinical computation.
--
-- SHARED REGISTRIES REUSED
-- ------------------------
-- knowledge.source
-- knowledge.source_version
-- knowledge.source_section
-- knowledge.source_chapter
-- knowledge.source_chunk
-- knowledge.source_claim
-- knowledge.provenance
-- knowledge.reasoning_version
-- knowledge.documentation_version
-- knowledge.investigation_version
-- knowledge.differential_version
-- patient.patient
-- encounter.encounter
-- knowledge.reasoning_run
-- knowledge.documentation_instance
--
-- =============================================================================


-- ============================================================================
-- 0. GOVERNANCE SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS governance;

COMMENT ON SCHEMA governance IS
'AMEXAN H10 Trust Layer: provenance, governance, lifecycle, safety, conflicts,
auditability, version control and deterministic clinical reproducibility.';


-- ============================================================================
-- 1. JURISDICTION
-- ============================================================================
-- Defines where a governed clinical knowledge object is legally / clinically
-- applicable.
--
-- Example:
--   JUR-GLOBAL
--   JUR-KENYA
--   JUR-UGANDA
--   JUR-TANZANIA
--
-- Universal medical knowledge remains global where appropriate.
-- Jurisdictional overlays refine rather than duplicate the core system.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.jurisdiction (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    jurisdiction_code          text NOT NULL UNIQUE,
    name                       text NOT NULL,
    description                text,

    country_code               text,
    region_code                text,

    parent_jurisdiction_id     uuid
        REFERENCES governance.jurisdiction(id)
        ON DELETE RESTRICT,

    is_default                 boolean NOT NULL DEFAULT false,
    is_active                  boolean NOT NULL DEFAULT true,

    status                     text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    effective_from             date,
    effective_to               date,

    created_at                 timestamptz NOT NULL DEFAULT now(),
    updated_at                 timestamptz NOT NULL DEFAULT now(),

    CHECK (
        effective_to IS NULL
        OR effective_from IS NULL
        OR effective_to >= effective_from
    )
);

COMMENT ON TABLE governance.jurisdiction IS
'Geographic and regulatory applicability layer for clinical knowledge.';


CREATE INDEX IF NOT EXISTS idx_gov_jurisdiction_active
    ON governance.jurisdiction(is_active);

CREATE INDEX IF NOT EXISTS idx_gov_jurisdiction_country
    ON governance.jurisdiction(country_code);

DROP TRIGGER IF EXISTS trg_gov_jurisdiction_updated_at
ON governance.jurisdiction;

CREATE TRIGGER trg_gov_jurisdiction_updated_at
BEFORE UPDATE ON governance.jurisdiction
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 2. POPULATION CONTEXT
-- ============================================================================
-- Clinical knowledge is population-dependent.
--
-- Examples:
--   POP-NEONATE
--   POP-INFANT
--   POP-CHILD
--   POP-ADOLESCENT
--   POP-ADULT
--   POP-GERIATRIC
--   POP-PREGNANCY
--   POP-LACTATION
--   POP-IMMUNOCOMPROMISED
--
-- A medical rule MUST NOT be assumed universally applicable merely because
-- it exists in the global catalogue.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.population_context (
    id                           uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    population_code              text NOT NULL UNIQUE,
    name                         text NOT NULL,
    description                  text,

    applies_to_context_codes     text[] NOT NULL DEFAULT '{}',

    minimum_age_days             integer,
    maximum_age_days             integer,

    sex_applicability            text[] NOT NULL DEFAULT '{}'
        CHECK (
            sex_applicability <@
            ARRAY['MALE','FEMALE','INTERSEX','UNKNOWN','ALL']::text[]
        ),

    pregnancy_required           boolean NOT NULL DEFAULT false,
    lactation_relevant           boolean NOT NULL DEFAULT false,

    is_active                    boolean NOT NULL DEFAULT true,

    created_at                   timestamptz NOT NULL DEFAULT now(),
    updated_at                   timestamptz NOT NULL DEFAULT now(),

    CHECK (
        minimum_age_days IS NULL
        OR minimum_age_days >= 0
    ),

    CHECK (
        maximum_age_days IS NULL
        OR maximum_age_days >= 0
    ),

    CHECK (
        maximum_age_days IS NULL
        OR minimum_age_days IS NULL
        OR maximum_age_days >= minimum_age_days
    )
);

COMMENT ON TABLE governance.population_context IS
'Population-specific applicability layer preventing inappropriate cross-population use of medical knowledge.';


CREATE INDEX IF NOT EXISTS idx_gov_population_active
    ON governance.population_context(is_active);

CREATE INDEX IF NOT EXISTS idx_gov_population_context_codes
    ON governance.population_context
    USING GIN(applies_to_context_codes);

DROP TRIGGER IF EXISTS trg_gov_population_context_updated_at
ON governance.population_context;

CREATE TRIGGER trg_gov_population_context_updated_at
BEFORE UPDATE ON governance.population_context
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 3. EVIDENCE METADATA
-- ============================================================================
-- Evidence classification is metadata.
--
-- It does not independently authorize clinical action.
--
-- Suggested AMEXAN evidence hierarchy:
--
-- EV-A = high-quality evidence
-- EV-B = moderate-quality evidence
-- EV-C = limited / mixed evidence
-- EV-D = low-quality / indirect evidence
-- EV-E = expert consensus / contextual evidence
--
-- The exact classification policy is configurable.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.evidence_metadata (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    evidence_level_code      text NOT NULL UNIQUE,
    level_label              text NOT NULL,

    ranking                  integer NOT NULL
        CHECK (ranking >= 1),

    description              text,

    minimum_source_quality   numeric(5,2)
        CHECK (
            minimum_source_quality IS NULL
            OR minimum_source_quality BETWEEN 0 AND 1
        ),

    is_active                boolean NOT NULL DEFAULT true,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.evidence_metadata IS
'Evidence-strength classification attached to governed medical knowledge. Evidence level informs governance but does not itself create clinical authority.';


CREATE INDEX IF NOT EXISTS idx_gov_evidence_ranking
    ON governance.evidence_metadata(ranking);

CREATE INDEX IF NOT EXISTS idx_gov_evidence_active
    ON governance.evidence_metadata(is_active);

DROP TRIGGER IF EXISTS trg_gov_evidence_metadata_updated_at
ON governance.evidence_metadata;

CREATE TRIGGER trg_gov_evidence_metadata_updated_at
BEFORE UPDATE ON governance.evidence_metadata
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 4. UNIVERSAL GOVERNED KNOWLEDGE OBJECT
-- ============================================================================
-- Every clinically meaningful governed object receives a governance identity.
--
-- Examples:
--
--   Q-COUGH-DURATION
--   FACT-FEVER
--   PHENO-FEVER
--   DX-CAP
--   RF-SMOKING
--   COMP-HYPOXEMIA
--   DRUG-AMOXICILLIN
--   PROTOCOL-CAP
--   DTE-PNEUMONIA-CONSOLIDATION
--   DRULE-PNEUMONIA-001
--
-- This registry does not replace the canonical H1-H9 objects.
-- It provides the universal GOVERNANCE identity around them.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_object (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    object_code              text NOT NULL UNIQUE,

    knowledge_type            text NOT NULL
        CHECK (
            knowledge_type IN (
                'CLINICAL_FACT',
                'SYMPTOM',
                'SIGN',
                'PHENOTYPE',
                'MECHANISM',
                'AETIOLOGY',
                'DIAGNOSIS',
                'DIFFERENTIAL_DIAGNOSIS',
                'RISK_FACTOR',
                'COMPLICATION',
                'QUESTION',
                'QUESTION_OPTION',
                'EXAMINATION',
                'EXAM_FINDING',
                'INVESTIGATION',
                'RESULT',
                'INTERPRETATION',
                'DIFFERENTIAL_RULE',
                'EVIDENCE_RULE',
                'PROTOCOL',
                'GUIDELINE',
                'DRUG',
                'DRUG_CLASS',
                'CONTRAINDICATION',
                'DOSING_RULE',
                'MONITORING_RULE',
                'REFERRAL_RULE',
                'ESCALATION_RULE',
                'DOCUMENTATION_RULE',
                'DOCUMENTATION_TEMPLATE',
                'DOCUMENTATION_SECTION',
                'SAFETY_RULE',
                'ALERT_RULE',
                'KNOWLEDGE_VERSION',
                'SYSTEM_VERSION',
                'MODEL',
                'OTHER'
            )
        ),

    canonical_name           text NOT NULL,
    description              text,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    jurisdiction_code        text NOT NULL
        REFERENCES governance.jurisdiction(jurisdiction_code)
        ON DELETE RESTRICT
        DEFAULT 'JUR-GLOBAL',

    population_code          text
        REFERENCES governance.population_context(population_code)
        ON DELETE RESTRICT,

    evidence_level_code      text NOT NULL
        REFERENCES governance.evidence_metadata(evidence_level_code)
        ON DELETE RESTRICT
        DEFAULT 'EV-C',

    lifecycle_status         text NOT NULL DEFAULT 'DRAFT'
        CHECK (
            lifecycle_status IN (
                'DRAFT',
                'EXTRACTED',
                'STRUCTURED',
                'CLINICALLY_REVIEWED',
                'VALIDATED',
                'APPROVED',
                'ACTIVE',
                'DEPRECATED',
                'RETIRED',
                'SUPERSEDED'
            )
        ),

    effective_from           date,
    effective_to             date,

    confidence               numeric(4,3) NOT NULL DEFAULT 0.900
        CHECK (confidence BETWEEN 0 AND 1),

    review_date              date,

    created_by               text,
    reviewed_by              text,
    approved_by              text,

    is_active                boolean NOT NULL DEFAULT true,

    status                   text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','draft','retired')),

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    CHECK (
        effective_to IS NULL
        OR effective_from IS NULL
        OR effective_to >= effective_from
    ),

    CHECK (
        lifecycle_status <> 'ACTIVE'
        OR is_active = true
    )
);

COMMENT ON TABLE governance.knowledge_object IS
'Universal AMEXAN governance registry. Every governed clinical object has provenance, applicability, evidence classification and lifecycle state. No anonymous clinical logic.';


CREATE INDEX IF NOT EXISTS idx_gov_kobj_type
    ON governance.knowledge_object(knowledge_type);

CREATE INDEX IF NOT EXISTS idx_gov_kobj_jurisdiction
    ON governance.knowledge_object(jurisdiction_code);

CREATE INDEX IF NOT EXISTS idx_gov_kobj_population
    ON governance.knowledge_object(population_code);

CREATE INDEX IF NOT EXISTS idx_gov_kobj_evidence
    ON governance.knowledge_object(evidence_level_code);

CREATE INDEX IF NOT EXISTS idx_gov_kobj_lifecycle
    ON governance.knowledge_object(lifecycle_status);

CREATE INDEX IF NOT EXISTS idx_gov_kobj_review_date
    ON governance.knowledge_object(review_date);

CREATE INDEX IF NOT EXISTS idx_gov_kobj_active
    ON governance.knowledge_object(is_active);

DROP TRIGGER IF EXISTS trg_gov_knowledge_object_updated_at
ON governance.knowledge_object;

CREATE TRIGGER trg_gov_knowledge_object_updated_at
BEFORE UPDATE ON governance.knowledge_object
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 5. KNOWLEDGE OBJECT VERSION
-- ============================================================================
-- Medical knowledge is immutable by version.
--
-- Updating a clinical rule means creating v2.
-- It does NOT rewrite v1.
--
-- This is essential for retrospective reconstruction:
--
-- "What did AMEXAN know when this patient was assessed?"
--
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_object_version (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    object_id                uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    version_no               integer NOT NULL
        CHECK (version_no >= 1),

    version_code             text NOT NULL UNIQUE,

    change_note              text,

    supersedes_version_id    uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE RESTRICT,

    lifecycle_status         text NOT NULL DEFAULT 'DRAFT'
        CHECK (
            lifecycle_status IN (
                'DRAFT',
                'EXTRACTED',
                'STRUCTURED',
                'CLINICALLY_REVIEWED',
                'VALIDATED',
                'APPROVED',
                'ACTIVE',
                'DEPRECATED',
                'RETIRED',
                'SUPERSEDED'
            )
        ),

    effective_from           date,
    effective_to             date,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    content_fingerprint      text,

    created_by               text,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (object_id, version_no),

    CHECK (
        effective_to IS NULL
        OR effective_from IS NULL
        OR effective_to >= effective_from
    )
);

COMMENT ON TABLE governance.knowledge_object_version IS
'Immutable lineage of governed medical knowledge. Every meaningful change creates a new version; previous clinical knowledge remains reconstructable.';


CREATE INDEX IF NOT EXISTS idx_gov_kobjver_object
    ON governance.knowledge_object_version(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_kobjver_status
    ON governance.knowledge_object_version(lifecycle_status);

CREATE INDEX IF NOT EXISTS idx_gov_kobjver_effective
    ON governance.knowledge_object_version(effective_from, effective_to);

CREATE UNIQUE INDEX IF NOT EXISTS uq_gov_kobjver_active_per_object
    ON governance.knowledge_object_version(object_id)
    WHERE lifecycle_status = 'ACTIVE';

DROP TRIGGER IF EXISTS trg_gov_knowledge_object_version_updated_at
ON governance.knowledge_object_version;

CREATE TRIGGER trg_gov_knowledge_object_version_updated_at
BEFORE UPDATE ON governance.knowledge_object_version
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 6. KNOWLEDGE RELATIONSHIP
-- ============================================================================
-- Governed medical knowledge graph.
--
-- Examples:
--
-- symptom → supports → diagnosis
-- diagnosis → has_complication → complication
-- investigation → interprets → diagnosis
-- drug → contraindicated_by → condition
-- question → assesses → symptom
-- protocol → requires → investigation
-- documentation element → documents → clinical fact
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_relationship (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    relationship_code        text NOT NULL UNIQUE,

    from_object_id           uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    to_object_id             uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    relationship_type        text NOT NULL
        CHECK (
            relationship_type IN (
                'ASSESSES',
                'SUPPORTS',
                'OPPOSES',
                'TRIGGERS',
                'RULES',
                'REQUIRES',
                'DOCUMENTS',
                'PRECEDES',
                'FOLLOWS',
                'SPECIALIZES',
                'GENERALIZES',
                'CONTRAINDICATES',
                'DERIVED_FROM',
                'CAUSES',
                'ASSOCIATED_WITH',
                'COMPLICATES',
                'MONITORS',
                'TREATS',
                'PREVENTS',
                'INTERPRETS',
                'REFERS_TO',
                'ESCALATES_TO'
            )
        ),

    weight                   numeric(6,3) NOT NULL DEFAULT 1.000,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    is_active                boolean NOT NULL DEFAULT true,

    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.knowledge_relationship IS
'Governed clinical knowledge graph linking symptoms, facts, diagnoses, investigations, treatments, protocols, rules and documentation.';


CREATE INDEX IF NOT EXISTS idx_gov_krel_from
    ON governance.knowledge_relationship(from_object_id);

CREATE INDEX IF NOT EXISTS idx_gov_krel_to
    ON governance.knowledge_relationship(to_object_id);

CREATE INDEX IF NOT EXISTS idx_gov_krel_type
    ON governance.knowledge_relationship(relationship_type);


-- ============================================================================
-- 7. KNOWLEDGE DEPENDENCY
-- ============================================================================
-- Dependency graph used before publication.
--
-- An object cannot become ACTIVE when a mandatory dependency is:
--   missing
--   retired
--   superseded
--   unpublished
--   cyclic
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_dependency (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    dependency_code          text NOT NULL UNIQUE,

    dependent_object_id      uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    required_object_id       uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    dependency_type          text NOT NULL DEFAULT 'REQUIRES'
        CHECK (
            dependency_type IN (
                'REQUIRES',
                'REQUIRES_CONFIRMATION',
                'CYCLIC_GUARD',
                'REQUIRES_ACTIVE_VERSION',
                'REQUIRES_SAFETY_REVIEW'
            )
        ),

    is_optional              boolean NOT NULL DEFAULT false,

    source_claim_code        text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    created_at               timestamptz NOT NULL DEFAULT now(),

    UNIQUE (dependent_object_id, required_object_id)
);

COMMENT ON TABLE governance.knowledge_dependency IS
'Publication dependency graph. Missing or circular mandatory dependencies prevent activation of governed clinical knowledge.';


CREATE INDEX IF NOT EXISTS idx_gov_kdep_dependent
    ON governance.knowledge_dependency(dependent_object_id);

CREATE INDEX IF NOT EXISTS idx_gov_kdep_required
    ON governance.knowledge_dependency(required_object_id);


-- ============================================================================
-- 8. KNOWLEDGE REVIEW
-- ============================================================================
-- Human clinical / safety / legal review events.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_review (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    review_code              text NOT NULL UNIQUE,

    object_id                uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    review_type              text NOT NULL
        CHECK (
            review_type IN (
                'CLINICAL_REVIEW',
                'MEDICAL_VALIDATION',
                'SAFETY_REVIEW',
                'PHARMACOLOGY_REVIEW',
                'PAEDIATRIC_REVIEW',
                'OBSTETRIC_REVIEW',
                'SURGICAL_REVIEW',
                'LEGAL_REVIEW',
                'REGULATORY_REVIEW',
                'QUALITY_REVIEW'
            )
        ),

    reviewer                 text NOT NULL,

    outcome                  text NOT NULL
        CHECK (
            outcome IN (
                'PASS',
                'FAIL',
                'PASS_WITH_NOTES',
                'DEFERRED'
            )
        ),

    notes                    text,

    reviewed_at              timestamptz NOT NULL DEFAULT now(),
    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.knowledge_review IS
'Human review record for governed clinical knowledge. Review history is preserved as an auditable event.';


CREATE INDEX IF NOT EXISTS idx_gov_review_object
    ON governance.knowledge_review(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_review_version
    ON governance.knowledge_review(version_id);

CREATE INDEX IF NOT EXISTS idx_gov_review_outcome
    ON governance.knowledge_review(outcome);


-- ============================================================================
-- 9. KNOWLEDGE APPROVAL
-- ============================================================================
-- Approval is distinct from review.
--
-- A reviewer may PASS an object.
-- An authorized approver explicitly decides whether it may proceed.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_approval (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    approval_code            text NOT NULL UNIQUE,

    object_id                uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    approver                 text NOT NULL,

    decision                 text NOT NULL
        CHECK (
            decision IN (
                'APPROVED',
                'REJECTED',
                'DEFERRED'
            )
        ),

    note                     text,

    approved_at              timestamptz NOT NULL DEFAULT now(),
    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.knowledge_approval IS
'Explicit governance decision for a specific governed object/version.';


CREATE INDEX IF NOT EXISTS idx_gov_approval_object
    ON governance.knowledge_approval(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_approval_version
    ON governance.knowledge_approval(version_id);

CREATE INDEX IF NOT EXISTS idx_gov_approval_decision
    ON governance.knowledge_approval(decision);


-- ============================================================================
-- 10. KNOWLEDGE PUBLICATION
-- ============================================================================
-- Publication is a multi-gate safety decision.
--
-- REQUIRED:
--   provenance
--   validation
--   dependencies
--   jurisdiction
--   population
--   safety
--
-- Any failed gate = BLOCKED.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_publication (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    publication_code           text NOT NULL UNIQUE,

    object_id                  uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    version_id                 uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    provenance_complete        boolean NOT NULL DEFAULT false,
    validation_passed          boolean NOT NULL DEFAULT false,
    dependency_integrity       boolean NOT NULL DEFAULT false,
    jurisdiction_ok            boolean NOT NULL DEFAULT false,
    population_ok              boolean NOT NULL DEFAULT false,
    safety_review_ok           boolean NOT NULL DEFAULT false,
    clinical_review_ok         boolean NOT NULL DEFAULT false,
    approval_ok                boolean NOT NULL DEFAULT false,

    decision                   text NOT NULL
        CHECK (
            decision IN (
                'PUBLISHED',
                'BLOCKED',
                'WITHDRAWN'
            )
        ),

    decision_reason            text,

    published_by               text,
    published_at               timestamptz,

    withdrawn_by               text,
    withdrawn_at               timestamptz,
    withdrawal_reason          text,

    created_at                 timestamptz NOT NULL DEFAULT now(),

    UNIQUE (object_id, version_id),

    CHECK (
        decision <> 'PUBLISHED'
        OR (
            provenance_complete
            AND validation_passed
            AND dependency_integrity
            AND jurisdiction_ok
            AND population_ok
            AND safety_review_ok
            AND clinical_review_ok
            AND approval_ok
        )
    ),

    CHECK (
        decision = 'PUBLISHED'
        OR published_at IS NULL
    )
);

COMMENT ON TABLE governance.knowledge_publication IS
'Publication gate for governed medical knowledge. A clinical object cannot be published unless every required governance gate passes.';


CREATE INDEX IF NOT EXISTS idx_gov_publication_object
    ON governance.knowledge_publication(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_publication_version
    ON governance.knowledge_publication(version_id);

CREATE INDEX IF NOT EXISTS idx_gov_publication_decision
    ON governance.knowledge_publication(decision);


-- ============================================================================
-- 11. KNOWLEDGE DEPRECATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.knowledge_deprecation (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    deprecation_code         text NOT NULL UNIQUE,

    object_id                uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    deprecation_reason       text NOT NULL,

    replacement_object_id    uuid
        REFERENCES governance.knowledge_object(id)
        ON DELETE SET NULL,

    replacement_version_id   uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    deprecated_by            text NOT NULL,
    deprecated_at            timestamptz NOT NULL DEFAULT now(),

    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.knowledge_deprecation IS
'Historical retirement/deprecation record. Superseded medical knowledge remains traceable and is never silently deleted.';


CREATE INDEX IF NOT EXISTS idx_gov_deprecation_object
    ON governance.knowledge_deprecation(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_deprecation_replacement
    ON governance.knowledge_deprecation(replacement_object_id);


-- ============================================================================
-- 12. CONFLICT RECORD
-- ============================================================================
-- AMEXAN MUST NOT silently reconcile contradictory clinical knowledge.
--
-- Examples:
--   two guideline recommendations differ
--   dose differs by jurisdiction
--   recommendation changes over time
--   adult recommendation differs from paediatric recommendation
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.conflict_record (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    conflict_code            text NOT NULL UNIQUE,

    object_id_a              uuid
        REFERENCES governance.knowledge_object(id)
        ON DELETE SET NULL,

    object_id_b              uuid
        REFERENCES governance.knowledge_object(id)
        ON DELETE SET NULL,

    version_id_a             uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    version_id_b             uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    conflict_type            text NOT NULL
        CHECK (
            conflict_type IN (
                'KNOWLEDGE_CONFLICT',
                'TEMPORAL_CONFLICT',
                'JURISDICTIONAL_CONFLICT',
                'POPULATION_CONFLICT',
                'EVIDENCE_CONFLICT',
                'DOSING_CONFLICT',
                'DIAGNOSTIC_CONFLICT',
                'DOCUMENTATION_CONFLICT',
                'PROTOCOL_CONFLICT',
                'SAFETY_CONFLICT'
            )
        ),

    classification           jsonb NOT NULL DEFAULT '{}'::jsonb,

    description              text NOT NULL,

    status                   text NOT NULL DEFAULT 'DETECTED'
        CHECK (
            status IN (
                'DETECTED',
                'CLASSIFIED',
                'UNDER_REVIEW',
                'RESOLVED',
                'ACCEPTED_VARIANCE',
                'BLOCKED',
                'PUBLISHED'
            )
        ),

    resolution               text,

    resolution_type          text
        CHECK (
            resolution_type IS NULL
            OR resolution_type IN (
                'PREFER_NEWER',
                'PREFER_HIGHER_EVIDENCE',
                'JURISDICTIONAL_OVERLAY',
                'POPULATION_SPECIFIC',
                'RETAIN_BOTH',
                'REJECT_ONE',
                'ESCALATE_HUMAN_REVIEW'
            )
        ),

    resolved_by              text,
    resolved_at              timestamptz,

    source_claim_a           text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    source_claim_b           text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.conflict_record IS
'Clinical knowledge conflict registry. AMEXAN preserves disagreement, classifies its clinical context and records the explicit resolution rather than silently merging contradictory medical guidance.';


CREATE INDEX IF NOT EXISTS idx_gov_conflict_status
    ON governance.conflict_record(status);

CREATE INDEX IF NOT EXISTS idx_gov_conflict_type
    ON governance.conflict_record(conflict_type);

DROP TRIGGER IF EXISTS trg_gov_conflict_record_updated_at
ON governance.conflict_record;

CREATE TRIGGER trg_gov_conflict_record_updated_at
BEFORE UPDATE ON governance.conflict_record
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 13. SAFETY REVIEW
-- ============================================================================
-- Medical consequences determine governance intensity.
--
-- INFORMATIONAL
-- CLINICAL_SUGGESTION
-- DECISION_SUPPORT
-- HIGH_RISK_RECOMMENDATION
-- ACTION_REQUIRING_HUMAN_AUTHORIZATION
--
-- Examples of high-risk domains:
--   emergency treatment
--   medication dosing
--   anticoagulation
--   insulin
--   chemotherapy
--   procedural intervention
--   surgery
--   obstetric emergency management
--   neonatal resuscitation
--   critical-care escalation
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.safety_review (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    safety_code              text NOT NULL UNIQUE,

    object_id                uuid NOT NULL
        REFERENCES governance.knowledge_object(id)
        ON DELETE CASCADE,

    version_id               uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    risk_class               text NOT NULL
        CHECK (
            risk_class IN (
                'INFORMATIONAL',
                'CLINICAL_SUGGESTION',
                'DECISION_SUPPORT',
                'HIGH_RISK_RECOMMENDATION',
                'ACTION_REQUIRING_HUMAN_AUTHORIZATION'
            )
        ),

    human_in_the_loop        boolean NOT NULL DEFAULT false,

    requires_clinician_signoff boolean NOT NULL DEFAULT false,

    mitigation               text,

    contraindication_reviewed boolean NOT NULL DEFAULT false,

    adverse_event_reviewed   boolean NOT NULL DEFAULT false,

    reviewer                 text NOT NULL,

    reviewed_at              timestamptz NOT NULL DEFAULT now(),

    review_expiry_date       date,

    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.safety_review IS
'Safety classification and human-oversight requirements for governed clinical knowledge.';


CREATE INDEX IF NOT EXISTS idx_gov_safety_object
    ON governance.safety_review(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_safety_version
    ON governance.safety_review(version_id);

CREATE INDEX IF NOT EXISTS idx_gov_safety_risk
    ON governance.safety_review(risk_class);

CREATE INDEX IF NOT EXISTS idx_gov_safety_expiry
    ON governance.safety_review(review_expiry_date);


-- ============================================================================
-- 14. MODEL REGISTRY
-- ============================================================================
-- Registers deterministic algorithms, ML models and LLMs.
--
-- IMPORTANT:
-- An LLM may assist language realization.
-- An LLM does NOT become the undocumented clinical source of truth.
--
-- Clinical assertions must remain traceable to structured knowledge,
-- captured facts, evidence and governed rules.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.model_registry (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    model_code                 text NOT NULL UNIQUE,
    model_name                 text NOT NULL,

    model_type                 text NOT NULL
        CHECK (
            model_type IN (
                'DETERMINISTIC',
                'ML',
                'LLM',
                'HYBRID'
            )
        ),

    model_version              text NOT NULL,

    provider                   text,

    model_identifier           text,

    training_dataset_version   text,

    features                   jsonb NOT NULL DEFAULT '{}'::jsonb,

    validation_metrics         jsonb NOT NULL DEFAULT '{}'::jsonb,

    safety_constraints         jsonb NOT NULL DEFAULT '{}'::jsonb,

    deployment_date            date,

    approval_status            text NOT NULL DEFAULT 'DRAFT'
        CHECK (
            approval_status IN (
                'DRAFT',
                'REVIEW',
                'APPROVED',
                'ACTIVE',
                'SUSPENDED',
                'RETIRED'
            )
        ),

    approved_by                text,

    retired_at                 timestamptz,

    is_active                  boolean NOT NULL DEFAULT true,

    created_at                 timestamptz NOT NULL DEFAULT now(),
    updated_at                 timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.model_registry IS
'Identity and governance registry for deterministic algorithms, ML systems, LLMs and hybrid computational models.';


CREATE INDEX IF NOT EXISTS idx_gov_model_type
    ON governance.model_registry(model_type);

CREATE INDEX IF NOT EXISTS idx_gov_model_status
    ON governance.model_registry(approval_status);

CREATE INDEX IF NOT EXISTS idx_gov_model_active
    ON governance.model_registry(is_active);

DROP TRIGGER IF EXISTS trg_gov_model_registry_updated_at
ON governance.model_registry;

CREATE TRIGGER trg_gov_model_registry_updated_at
BEFORE UPDATE ON governance.model_registry
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 15. MASTER SYSTEM VERSION
-- ============================================================================
-- One fingerprint for the complete clinical OS state.
--
-- Example:
--
-- AMEXAN-CLINICAL-OS-1.0.0
--
-- Links:
--   H8 reasoning version
--   H9 documentation version
--   investigation version
--   differential version
--   engine version
--
-- This allows:
--
-- "Which exact AMEXAN clinical knowledge system produced this result?"
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.system_version (
    id                           uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    system_version_code         text NOT NULL UNIQUE,

    reasoning_version_code      text
        REFERENCES knowledge.reasoning_version(version_code)
        ON DELETE RESTRICT,

    documentation_version_code  text
        REFERENCES knowledge.documentation_version(version_code)
        ON DELETE RESTRICT,

    investigation_version_code  text,

    differential_version_code   text,

    engine_version              text NOT NULL,

    knowledge_fingerprint       text,

    ruleset_fingerprint         text,

    release_notes               text,

    released_at                 timestamptz,

    retired_at                  timestamptz,

    is_active                   boolean NOT NULL DEFAULT true,

    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.system_version IS
'Master AMEXAN Clinical OS version fingerprint tying clinical knowledge, investigation, reasoning, documentation and execution engine versions together.';


CREATE INDEX IF NOT EXISTS idx_gov_system_version_active
    ON governance.system_version(is_active);

CREATE INDEX IF NOT EXISTS idx_gov_system_version_release
    ON governance.system_version(released_at);

DROP TRIGGER IF EXISTS trg_gov_system_version_updated_at
ON governance.system_version;

CREATE TRIGGER trg_gov_system_version_updated_at
BEFORE UPDATE ON governance.system_version
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();


-- ============================================================================
-- 16. RULE EXECUTION
-- ============================================================================
-- Runtime.
--
-- Every clinically relevant rule execution must be reconstructable:
--
--   WHICH RULE?
--   WHICH VERSION?
--   WHICH INPUT FACTS?
--   WHICH MODEL?
--   WHICH OUTPUT?
--   WHEN?
--   DURING WHICH RUN?
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.rule_execution (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    run_id                   uuid
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE SET NULL,

    object_id                uuid
        REFERENCES governance.knowledge_object(id)
        ON DELETE SET NULL,

    object_version_id        uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    rule_code                text,

    knowledge_version        text,

    system_version_code      text
        REFERENCES governance.system_version(system_version_code)
        ON DELETE SET NULL,

    model_id                 uuid
        REFERENCES governance.model_registry(id)
        ON DELETE SET NULL,

    input_facts              jsonb NOT NULL DEFAULT '{}'::jsonb,

    input_fingerprint        text,

    output                   jsonb NOT NULL DEFAULT '{}'::jsonb,

    output_fingerprint       text,

    execution_status         text NOT NULL DEFAULT 'COMPLETED'
        CHECK (
            execution_status IN (
                'STARTED',
                'COMPLETED',
                'SKIPPED',
                'BLOCKED',
                'FAILED'
            )
        ),

    error_code               text,
    error_detail             text,

    executed_at              timestamptz NOT NULL DEFAULT now(),
    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.rule_execution IS
'Runtime audit record of governed rule execution. Records the exact rule, knowledge state, input state, model and output required for clinical replay.';


CREATE INDEX IF NOT EXISTS idx_gov_rule_exec_run
    ON governance.rule_execution(run_id);

CREATE INDEX IF NOT EXISTS idx_gov_rule_exec_object
    ON governance.rule_execution(object_id);

CREATE INDEX IF NOT EXISTS idx_gov_rule_exec_version
    ON governance.rule_execution(object_version_id);

CREATE INDEX IF NOT EXISTS idx_gov_rule_exec_system
    ON governance.rule_execution(system_version_code);

CREATE INDEX IF NOT EXISTS idx_gov_rule_exec_time
    ON governance.rule_execution(executed_at);


-- ============================================================================
-- 17. AUDIT EVENT
-- ============================================================================
-- Full clinical computation event stream.
--
-- This records EVENTS, not merely final database state.
--
-- Example:
--
-- QUESTION_DISPLAYED
-- ANSWER_RECEIVED
-- FACT_CREATED
-- PHENOTYPE_MATCHED
-- DDX_UPDATED
-- RULE_EVALUATED
-- INVESTIGATION_REQUESTED
-- DOCUMENT_GENERATED
-- SENTENCE_EDITED
-- DOCUMENT_FINALIZED
-- ALERT_GENERATED
-- SNAPSHOT_RECORDED
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.audit_event (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type               text NOT NULL
        CHECK (
            event_type IN (
                'CPU_ENGINE_STARTED',
                'CPU_ENGINE_COMPLETED',
                'CPU_ENGINE_FAILED',

                'QUESTION_DISPLAYED',
                'ANSWER_RECEIVED',

                'FACT_CREATED',
                'FACT_UPDATED',
                'FACT_RETRACTED',

                'PHENOTYPE_MATCHED',
                'PHENOTYPE_RETRACTED',

                'DDX_CREATED',
                'DDX_UPDATED',
                'DDX_RETIRED',

                'RULE_EVALUATED',
                'RULE_BLOCKED',

                'PROTOCOL_SELECTED',
                'PROTOCOL_BLOCKED',

                'INVESTIGATION_REQUESTED',
                'INVESTIGATION_COMPLETED',
                'INVESTIGATION_INTERPRETED',

                'DOCUMENT_GENERATED',
                'SENTENCE_EDITED',
                'SENTENCE_ADDED',
                'SENTENCE_DELETED',
                'DOCUMENT_FINALIZED',
                'DOCUMENT_AMENDED',

                'ALERT_GENERATED',
                'ALERT_ACKNOWLEDGED',
                'ALERT_ESCALATED',

                'SYSTEM_VERSION_SELECTED',
                'SNAPSHOT_RECORDED',

                'SAFETY_GATE_PASSED',
                'SAFETY_GATE_BLOCKED',

                'KNOWLEDGE_CONFLICT_DETECTED',
                'KNOWLEDGE_CONFLICT_RESOLVED'
            )
        ),

    actor_type               text NOT NULL
        CHECK (
            actor_type IN (
                'CLINICIAN',
                'SYSTEM',
                'API_CLIENT',
                'DEVICE',
                'PATIENT',
                'CAREGIVER'
            )
        ),

    actor_code               text,

    entity_type              text,
    entity_id                uuid,
    entity_code              text,

    previous_value           text,
    new_value                text,

    previous_fingerprint     text,
    new_fingerprint          text,

    encounter_id             uuid,

    run_id                   uuid
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE SET NULL,

    correlation_id           uuid,

    causation_id             uuid
        REFERENCES governance.audit_event(id)
        ON DELETE SET NULL,

    occurred_at              timestamptz NOT NULL DEFAULT now(),

    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.audit_event IS
'Immutable-style clinical computation event stream covering capture, reasoning, investigation, documentation, safety and clinician interaction.';


CREATE INDEX IF NOT EXISTS idx_gov_audit_encounter
    ON governance.audit_event(encounter_id);

CREATE INDEX IF NOT EXISTS idx_gov_audit_run
    ON governance.audit_event(run_id);

CREATE INDEX IF NOT EXISTS idx_gov_audit_entity
    ON governance.audit_event(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_gov_audit_correlation
    ON governance.audit_event(correlation_id);

CREATE INDEX IF NOT EXISTS idx_gov_audit_causation
    ON governance.audit_event(causation_id);

CREATE INDEX IF NOT EXISTS idx_gov_audit_event_type
    ON governance.audit_event(event_type);

CREATE INDEX IF NOT EXISTS idx_gov_audit_occurred
    ON governance.audit_event(occurred_at);


-- ============================================================================
-- 18. PROVENANCE RECORD
-- ============================================================================
-- Unified two-way clinical provenance.
--
-- FORWARD:
--
-- Source
--   ↓
-- Claim
--   ↓
-- Governed knowledge
--   ↓
-- Rule
--   ↓
-- Fact
--   ↓
-- Reasoning
--   ↓
-- Documentation
--
-- BACKWARD:
--
-- Rendered sentence
--   ↓
-- Fact
--   ↓
-- Rule
--   ↓
-- Source claim
--
-- This is the clinical audit spine.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.provenance_record (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    direction                   text NOT NULL
        CHECK (
            direction IN (
                'FORWARD',
                'BACKWARD'
            )
        ),

    source_claim_code           text
        REFERENCES knowledge.source_claim(claim_code)
        ON DELETE SET NULL,

    governance_object_id        uuid
        REFERENCES governance.knowledge_object(id)
        ON DELETE SET NULL,

    governance_object_version_id uuid
        REFERENCES governance.knowledge_object_version(id)
        ON DELETE SET NULL,

    governance_object_code      text,

    fact_code                   text,

    reasoning_run_id            uuid
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE SET NULL,

    documentation_instance_id  uuid
        REFERENCES knowledge.documentation_instance(instance_id)
        ON DELETE SET NULL,

    documentation_sentence_id  uuid
        REFERENCES knowledge.documentation_sentence(id)
        ON DELETE SET NULL,

    rule_execution_id           uuid
        REFERENCES governance.rule_execution(id)
        ON DELETE SET NULL,

    evidence_rule_code          text,

    link_type                   text NOT NULL DEFAULT 'DERIVED_FROM'
        CHECK (
            link_type IN (
                'DERIVED_FROM',
                'SUPPORTED_BY',
                'OPPOSED_BY',
                'DOCUMENTS',
                'GENERATED_BY',
                'TRIGGERED_BY',
                'VALIDATED_BY',
                'REVIEWED_BY',
                'SELECTED_BY',
                'INTERPRETED_BY'
            )
        ),

    created_at                  timestamptz NOT NULL DEFAULT now(),

    CHECK (
        source_claim_code IS NOT NULL
        OR governance_object_id IS NOT NULL
        OR fact_code IS NOT NULL
        OR reasoning_run_id IS NOT NULL
        OR documentation_instance_id IS NOT NULL
        OR documentation_sentence_id IS NOT NULL
        OR rule_execution_id IS NOT NULL
    )
);

COMMENT ON TABLE governance.provenance_record IS
'Unified bidirectional provenance spine connecting source evidence, governed knowledge, clinical facts, rules, reasoning and rendered documentation.';


CREATE INDEX IF NOT EXISTS idx_gov_prov_direction
    ON governance.provenance_record(direction);

CREATE INDEX IF NOT EXISTS idx_gov_prov_source
    ON governance.provenance_record(source_claim_code);

CREATE INDEX IF NOT EXISTS idx_gov_prov_object
    ON governance.provenance_record(governance_object_id);

CREATE INDEX IF NOT EXISTS idx_gov_prov_version
    ON governance.provenance_record(governance_object_version_id);

CREATE INDEX IF NOT EXISTS idx_gov_prov_fact
    ON governance.provenance_record(fact_code);

CREATE INDEX IF NOT EXISTS idx_gov_prov_run
    ON governance.provenance_record(reasoning_run_id);

CREATE INDEX IF NOT EXISTS idx_gov_prov_instance
    ON governance.provenance_record(documentation_instance_id);

CREATE INDEX IF NOT EXISTS idx_gov_prov_sentence
    ON governance.provenance_record(documentation_sentence_id);

CREATE INDEX IF NOT EXISTS idx_gov_prov_rule
    ON governance.provenance_record(rule_execution_id);


-- ============================================================================
-- 19. CLINICAL SNAPSHOT
-- ============================================================================
-- SNAPSHOT PRINCIPLE
--
-- A clinical decision must be reproducible from the state that existed when
-- the computation occurred.
--
-- Snapshot includes:
--
--   patient state
--   clinical facts
--   governed knowledge
--   system version
--   reasoning version
--   documentation version
--   deterministic fingerprints
--
-- Historical results must not change merely because current knowledge changed.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.clinical_snapshot (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_id                  uuid
        REFERENCES patient.patient(id)
        ON DELETE SET NULL,

    encounter_id               uuid,

    reasoning_run_id            uuid
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE SET NULL,

    documentation_instance_id  uuid
        REFERENCES knowledge.documentation_instance(instance_id)
        ON DELETE SET NULL,

    captured_at                 timestamptz NOT NULL DEFAULT now(),

    system_version_code         text
        REFERENCES governance.system_version(system_version_code)
        ON DELETE RESTRICT,

    reasoning_version_code      text,

    documentation_version_code text,

    investigation_version_code text,

    differential_version_code  text,

    patient_facts               jsonb NOT NULL DEFAULT '{}'::jsonb,

    clinical_events             jsonb NOT NULL DEFAULT '[]'::jsonb,

    knowledge_state             jsonb NOT NULL DEFAULT '{}'::jsonb,

    rule_state                  jsonb NOT NULL DEFAULT '{}'::jsonb,

    safety_state                jsonb NOT NULL DEFAULT '{}'::jsonb,

    input_fingerprint           text NOT NULL,

    knowledge_fingerprint       text,

    output_fingerprint          text,

    created_at                  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.clinical_snapshot IS
'Point-in-time clinical state snapshot containing patient facts, clinical events, knowledge state, rule state and system version fingerprints required for reproducibility.';


CREATE INDEX IF NOT EXISTS idx_gov_snapshot_patient
    ON governance.clinical_snapshot(patient_id);

CREATE INDEX IF NOT EXISTS idx_gov_snapshot_encounter
    ON governance.clinical_snapshot(encounter_id);

CREATE INDEX IF NOT EXISTS idx_gov_snapshot_run
    ON governance.clinical_snapshot(reasoning_run_id);

CREATE INDEX IF NOT EXISTS idx_gov_snapshot_instance
    ON governance.clinical_snapshot(documentation_instance_id);

CREATE INDEX IF NOT EXISTS idx_gov_snapshot_system
    ON governance.clinical_snapshot(system_version_code);

CREATE INDEX IF NOT EXISTS idx_gov_snapshot_time
    ON governance.clinical_snapshot(captured_at);

CREATE UNIQUE INDEX IF NOT EXISTS uq_gov_snapshot_input_fingerprint
    ON governance.clinical_snapshot(input_fingerprint);


-- ============================================================================
-- 20. REASONING SNAPSHOT
-- ============================================================================
-- Captures H8 state within a clinical snapshot.
--
-- Includes:
--   differential candidates
--   scores
--   evidence
--   hypotheses
--   uncertainty
--   information gaps
--   exceptions
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.reasoning_snapshot (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    clinical_snapshot_id     uuid NOT NULL
        REFERENCES governance.clinical_snapshot(id)
        ON DELETE CASCADE,

    run_id                   uuid
        REFERENCES knowledge.reasoning_run(run_id)
        ON DELETE SET NULL,

    reasoning_version_code   text,

    candidate_states         jsonb NOT NULL DEFAULT '[]'::jsonb,

    differential_scores      jsonb NOT NULL DEFAULT '[]'::jsonb,

    evidence_ledger          jsonb NOT NULL DEFAULT '[]'::jsonb,

    clinical_hypotheses      jsonb NOT NULL DEFAULT '[]'::jsonb,

    clinical_uncertainty     jsonb NOT NULL DEFAULT '[]'::jsonb,

    information_gaps         jsonb NOT NULL DEFAULT '[]'::jsonb,

    exception_notes          text,

    reasoning_fingerprint    text,

    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.reasoning_snapshot IS
'H8 reasoning state captured inside a clinical snapshot, including differential candidates, scores, evidence, hypotheses, uncertainty and information gaps.';


CREATE INDEX IF NOT EXISTS idx_gov_reason_snapshot_clinical
    ON governance.reasoning_snapshot(clinical_snapshot_id);

CREATE INDEX IF NOT EXISTS idx_gov_reason_snapshot_run
    ON governance.reasoning_snapshot(run_id);


-- ============================================================================
-- 21. DOCUMENTATION SNAPSHOT
-- ============================================================================
-- Captures H9 documentation state.
--
-- A historical clinical document must remain interpretable even after
-- documentation templates or wording rules evolve.
-- ============================================================================

CREATE TABLE IF NOT EXISTS governance.documentation_snapshot (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    clinical_snapshot_id        uuid NOT NULL
        REFERENCES governance.clinical_snapshot(id)
        ON DELETE CASCADE,

    instance_id                 uuid
        REFERENCES knowledge.documentation_instance(instance_id)
        ON DELETE SET NULL,

    documentation_version_code  text,

    document_version            integer,

    document_status             text,

    sections                    jsonb NOT NULL DEFAULT '[]'::jsonb,

    sentences                   jsonb NOT NULL DEFAULT '[]'::jsonb,

    human_edit_state            jsonb NOT NULL DEFAULT '[]'::jsonb,

    documentation_fingerprint   text,

    created_at                  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE governance.documentation_snapshot IS
'H9 documentation state captured inside a clinical snapshot, preserving rendered sections, sentences and human-edit state for historical reconstruction.';


CREATE INDEX IF NOT EXISTS idx_gov_doc_snapshot_clinical
    ON governance.documentation_snapshot(clinical_snapshot_id);

CREATE INDEX IF NOT EXISTS idx_gov_doc_snapshot_instance
    ON governance.documentation_snapshot(instance_id);

CREATE INDEX IF NOT EXISTS idx_gov_doc_snapshot_version
    ON governance.documentation_snapshot(documentation_version_code);


-- ============================================================================
-- 22. GOVERNANCE PUBLICATION VALIDATION FUNCTION
-- ============================================================================
-- Central deterministic gate.
--
-- The CPU may use this function before publishing a governed knowledge object.
--
-- This function DOES NOT modify lifecycle state.
-- It evaluates the gates only.
-- ============================================================================

CREATE OR REPLACE FUNCTION governance.can_publish_knowledge_object(
    p_object_id uuid,
    p_version_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_provenance_complete       boolean := false;
    v_validation_passed         boolean := false;
    v_dependency_integrity      boolean := false;
    v_jurisdiction_ok           boolean := false;
    v_population_ok             boolean := false;
    v_safety_ok                 boolean := false;
    v_clinical_review_ok       boolean := false;
    v_approval_ok               boolean := false;
    v_object_active             boolean := false;
BEGIN

    SELECT
        ko.is_active,
        ko.jurisdiction_code IS NOT NULL,
        (
            ko.population_code IS NULL
            OR EXISTS (
                SELECT 1
                FROM governance.population_context pc
                WHERE pc.population_code = ko.population_code
                  AND pc.is_active = true
            )
        )
    INTO
        v_object_active,
        v_jurisdiction_ok,
        v_population_ok
    FROM governance.knowledge_object ko
    WHERE ko.id = p_object_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;


    SELECT EXISTS (
        SELECT 1
        FROM knowledge.source_claim sc
        JOIN governance.knowledge_object_version kov
          ON kov.source_claim_code = sc.claim_code
        WHERE kov.id = p_version_id
    )
    INTO v_provenance_complete;


    SELECT NOT EXISTS (
        SELECT 1
        FROM governance.knowledge_dependency kd
        JOIN governance.knowledge_object required_object
          ON required_object.id = kd.required_object_id
        WHERE kd.dependent_object_id = p_object_id
          AND kd.is_optional = false
          AND (
              required_object.is_active = false
              OR required_object.lifecycle_status NOT IN ('APPROVED','ACTIVE')
          )
    )
    INTO v_dependency_integrity;


    SELECT EXISTS (
        SELECT 1
        FROM governance.knowledge_review kr
        WHERE kr.object_id = p_object_id
          AND (
              kr.version_id = p_version_id
              OR kr.version_id IS NULL
          )
          AND kr.review_type IN (
              'CLINICAL_REVIEW',
              'MEDICAL_VALIDATION'
          )
          AND kr.outcome IN ('PASS','PASS_WITH_NOTES')
    )
    INTO v_clinical_review_ok;


    SELECT EXISTS (
        SELECT 1
        FROM governance.knowledge_review kr
        WHERE kr.object_id = p_object_id
          AND (
              kr.version_id = p_version_id
              OR kr.version_id IS NULL
          )
          AND kr.review_type IN (
              'VALIDATION',
              'QUALITY_REVIEW'
          )
          AND kr.outcome IN ('PASS','PASS_WITH_NOTES')
    )
    INTO v_validation_passed;


    SELECT EXISTS (
        SELECT 1
        FROM governance.safety_review sr
        WHERE sr.object_id = p_object_id
          AND (
              sr.version_id = p_version_id
              OR sr.version_id IS NULL
          )
          AND sr.reviewed_at IS NOT NULL
          AND (
              sr.review_expiry_date IS NULL
              OR sr.review_expiry_date >= CURRENT_DATE
          )
    )
    INTO v_safety_ok;


    SELECT EXISTS (
        SELECT 1
        FROM governance.knowledge_approval ka
        WHERE ka.object_id = p_object_id
          AND ka.version_id = p_version_id
          AND ka.decision = 'APPROVED'
    )
    INTO v_approval_ok;


    RETURN (
        v_object_active
        AND v_provenance_complete
        AND v_validation_passed
        AND v_dependency_integrity
        AND v_jurisdiction_ok
        AND v_population_ok
        AND v_safety_ok
        AND v_clinical_review_ok
        AND v_approval_ok
    );
END;
$$;


COMMENT ON FUNCTION governance.can_publish_knowledge_object(uuid, uuid)
IS
'Deterministic AMEXAN publication gate. Returns true only when provenance, validation, dependencies, jurisdiction, population, safety, clinical review and approval requirements are satisfied.';


-- ============================================================================
-- 23. KNOWLEDGE DEPENDENCY CYCLE DETECTOR
-- ============================================================================
-- Recursive graph traversal.
--
-- Any circular dependency is a publication blocker.
-- ============================================================================

CREATE OR REPLACE FUNCTION governance.has_dependency_cycle(
    p_object_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
WITH RECURSIVE dependency_graph AS (
    SELECT
        kd.dependent_object_id,
        kd.required_object_id,
        ARRAY[
            kd.dependent_object_id,
            kd.required_object_id
        ]::uuid[] AS path,
        false AS cycle
    FROM governance.knowledge_dependency kd
    WHERE kd.dependent_object_id = p_object_id

    UNION ALL

    SELECT
        dg.dependent_object_id,
        kd.required_object_id,
        dg.path || kd.required_object_id,
        kd.required_object_id = ANY(dg.path)
    FROM dependency_graph dg
    JOIN governance.knowledge_dependency kd
      ON kd.dependent_object_id = dg.required_object_id
    WHERE NOT dg.cycle
      AND cardinality(dg.path) < 100
)
SELECT EXISTS (
    SELECT 1
    FROM dependency_graph
    WHERE cycle = true
);
$$;


COMMENT ON FUNCTION governance.has_dependency_cycle(uuid)
IS
'Detects circular dependencies in governed clinical knowledge before publication.';


-- ============================================================================
-- 24. GOVERNANCE OBJECT CURRENT VERSION VIEW
-- ============================================================================

CREATE OR REPLACE VIEW governance.v_current_knowledge_object AS
SELECT
    ko.id,
    ko.object_code,
    ko.knowledge_type,
    ko.canonical_name,
    ko.description,
    ko.source_claim_code,
    ko.jurisdiction_code,
    ko.population_code,
    ko.evidence_level_code,
    ko.lifecycle_status,
    ko.confidence,
    ko.review_date,
    ko.is_active,

    kov.id AS version_id,
    kov.version_no,
    kov.version_code,
    kov.change_note,
    kov.source_claim_code AS version_source_claim_code,
    kov.effective_from,
    kov.effective_to

FROM governance.knowledge_object ko

LEFT JOIN governance.knowledge_object_version kov
    ON kov.object_id = ko.id
   AND kov.lifecycle_status = 'ACTIVE';


COMMENT ON VIEW governance.v_current_knowledge_object IS
'Current active governed medical knowledge with its active version.';


-- ============================================================================
-- 25. GOVERNANCE PUBLICATION STATUS VIEW
-- ============================================================================

CREATE OR REPLACE VIEW governance.v_publication_gate_status AS
SELECT
    ko.id AS object_id,
    ko.object_code,
    ko.knowledge_type,
    ko.canonical_name,

    kov.id AS version_id,
    kov.version_code,

    EXISTS (
        SELECT 1
        FROM knowledge.source_claim sc
        WHERE sc.claim_code = kov.source_claim_code
    ) AS provenance_complete,

    EXISTS (
        SELECT 1
        FROM governance.knowledge_review kr
        WHERE kr.object_id = ko.id
          AND (kr.version_id = kov.id OR kr.version_id IS NULL)
          AND kr.review_type IN ('VALIDATION','QUALITY_REVIEW')
          AND kr.outcome IN ('PASS','PASS_WITH_NOTES')
    ) AS validation_passed,

    NOT EXISTS (
        SELECT 1
        FROM governance.knowledge_dependency kd
        JOIN governance.knowledge_object req
          ON req.id = kd.required_object_id
        WHERE kd.dependent_object_id = ko.id
          AND kd.is_optional = false
          AND (
              req.is_active = false
              OR req.lifecycle_status NOT IN ('APPROVED','ACTIVE')
          )
    ) AS dependency_integrity,

    ko.jurisdiction_code IS NOT NULL AS jurisdiction_ok,

    (
        ko.population_code IS NULL
        OR EXISTS (
            SELECT 1
            FROM governance.population_context pc
            WHERE pc.population_code = ko.population_code
              AND pc.is_active = true
        )
    ) AS population_ok,

    EXISTS (
        SELECT 1
        FROM governance.safety_review sr
        WHERE sr.object_id = ko.id
          AND (sr.version_id = kov.id OR sr.version_id IS NULL)
          AND (
              sr.review_expiry_date IS NULL
              OR sr.review_expiry_date >= CURRENT_DATE
          )
    ) AS safety_review_ok,

    EXISTS (
        SELECT 1
        FROM governance.knowledge_review kr
        WHERE kr.object_id = ko.id
          AND (kr.version_id = kov.id OR kr.version_id IS NULL)
          AND kr.review_type IN ('CLINICAL_REVIEW','MEDICAL_VALIDATION')
          AND kr.outcome IN ('PASS','PASS_WITH_NOTES')
    ) AS clinical_review_ok,

    EXISTS (
        SELECT 1
        FROM governance.knowledge_approval ka
        WHERE ka.object_id = ko.id
          AND ka.version_id = kov.id
          AND ka.decision = 'APPROVED'
    ) AS approval_ok

FROM governance.knowledge_object ko
JOIN governance.knowledge_object_version kov
  ON kov.object_id = ko.id
 AND kov.lifecycle_status = 'ACTIVE';


COMMENT ON VIEW governance.v_publication_gate_status IS
'Governance dashboard view showing every publication gate for the active version of a governed clinical object.';


-- ============================================================================
-- 26. CLINICAL SNAPSHOT REPLAY VIEW
-- ============================================================================
-- Gives the CPU / audit layer a single replay-oriented projection.
-- ============================================================================

CREATE OR REPLACE VIEW governance.v_clinical_replay_state AS
SELECT
    cs.id AS clinical_snapshot_id,

    cs.patient_id,
    cs.encounter_id,

    cs.reasoning_run_id,
    cs.documentation_instance_id,

    cs.captured_at,

    cs.system_version_code,

    cs.reasoning_version_code,
    cs.documentation_version_code,
    cs.investigation_version_code,
    cs.differential_version_code,

    cs.patient_facts,
    cs.clinical_events,
    cs.knowledge_state,
    cs.rule_state,
    cs.safety_state,

    cs.input_fingerprint,
    cs.knowledge_fingerprint,
    cs.output_fingerprint,

    rs.id AS reasoning_snapshot_id,
    rs.candidate_states,
    rs.differential_scores,
    rs.evidence_ledger,
    rs.clinical_hypotheses,
    rs.clinical_uncertainty,
    rs.information_gaps,
    rs.reasoning_fingerprint,

    ds.id AS documentation_snapshot_id,
    ds.document_version,
    ds.document_status,
    ds.sections,
    ds.sentences,
    ds.human_edit_state,
    ds.documentation_fingerprint

FROM governance.clinical_snapshot cs

LEFT JOIN governance.reasoning_snapshot rs
    ON rs.clinical_snapshot_id = cs.id

LEFT JOIN governance.documentation_snapshot ds
    ON ds.clinical_snapshot_id = cs.id;


COMMENT ON VIEW governance.v_clinical_replay_state IS
'Unified replay projection joining patient clinical state, H8 reasoning state and H9 documentation state from one immutable clinical snapshot.';


-- ============================================================================
-- 27. H10 GOVERNANCE HEALTH CHECK
-- ============================================================================

CREATE OR REPLACE FUNCTION governance.h10_health_check()
RETURNS TABLE (
    component              text,
    status                 text,
    detail                 text
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        'governance.jurisdiction',
        CASE
            WHEN to_regclass('governance.jurisdiction') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Jurisdiction governance registry'

    UNION ALL

    SELECT
        'governance.population_context',
        CASE
            WHEN to_regclass('governance.population_context') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Population applicability registry'

    UNION ALL

    SELECT
        'governance.evidence_metadata',
        CASE
            WHEN to_regclass('governance.evidence_metadata') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Evidence hierarchy registry'

    UNION ALL

    SELECT
        'governance.knowledge_object',
        CASE
            WHEN to_regclass('governance.knowledge_object') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Universal governed knowledge registry'

    UNION ALL

    SELECT
        'governance.knowledge_object_version',
        CASE
            WHEN to_regclass('governance.knowledge_object_version') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Immutable knowledge version lineage'

    UNION ALL

    SELECT
        'governance.knowledge_relationship',
        CASE
            WHEN to_regclass('governance.knowledge_relationship') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Governed medical knowledge graph'

    UNION ALL

    SELECT
        'governance.knowledge_dependency',
        CASE
            WHEN to_regclass('governance.knowledge_dependency') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Dependency and cycle-control graph'

    UNION ALL

    SELECT
        'governance.knowledge_review',
        CASE
            WHEN to_regclass('governance.knowledge_review') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Clinical review registry'

    UNION ALL

    SELECT
        'governance.knowledge_approval',
        CASE
            WHEN to_regclass('governance.knowledge_approval') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Governance approval registry'

    UNION ALL

    SELECT
        'governance.knowledge_publication',
        CASE
            WHEN to_regclass('governance.knowledge_publication') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Publication gate registry'

    UNION ALL

    SELECT
        'governance.knowledge_deprecation',
        CASE
            WHEN to_regclass('governance.knowledge_deprecation') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Knowledge deprecation registry'

    UNION ALL

    SELECT
        'governance.conflict_record',
        CASE
            WHEN to_regclass('governance.conflict_record') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Clinical knowledge conflict registry'

    UNION ALL

    SELECT
        'governance.safety_review',
        CASE
            WHEN to_regclass('governance.safety_review') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Clinical safety governance'

    UNION ALL

    SELECT
        'governance.model_registry',
        CASE
            WHEN to_regclass('governance.model_registry') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Computational model registry'

    UNION ALL

    SELECT
        'governance.system_version',
        CASE
            WHEN to_regclass('governance.system_version') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Master AMEXAN Clinical OS version registry'

    UNION ALL

    SELECT
        'governance.rule_execution',
        CASE
            WHEN to_regclass('governance.rule_execution') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Clinical rule execution audit'

    UNION ALL

    SELECT
        'governance.audit_event',
        CASE
            WHEN to_regclass('governance.audit_event') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Clinical event audit stream'

    UNION ALL

    SELECT
        'governance.provenance_record',
        CASE
            WHEN to_regclass('governance.provenance_record') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Bidirectional clinical provenance'

    UNION ALL

    SELECT
        'governance.clinical_snapshot',
        CASE
            WHEN to_regclass('governance.clinical_snapshot') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'Clinical reproducibility snapshot'

    UNION ALL

    SELECT
        'governance.reasoning_snapshot',
        CASE
            WHEN to_regclass('governance.reasoning_snapshot') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'H8 reasoning replay snapshot'

    UNION ALL

    SELECT
        'governance.documentation_snapshot',
        CASE
            WHEN to_regclass('governance.documentation_snapshot') IS NOT NULL
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        'H9 documentation replay snapshot';
$$;


-- ============================================================================
-- 28. H10 COMPLETION SELF-CHECK
-- ============================================================================

DO $h10_governance$
DECLARE
    v_expected_tables integer := 21;
    v_actual_tables   integer;
BEGIN

    SELECT count(*)
    INTO v_actual_tables
    FROM information_schema.tables
    WHERE table_schema = 'governance'
      AND table_name IN (
          'jurisdiction',
          'population_context',
          'evidence_metadata',
          'knowledge_object',
          'knowledge_object_version',
          'knowledge_relationship',
          'knowledge_dependency',
          'knowledge_review',
          'knowledge_approval',
          'knowledge_publication',
          'knowledge_deprecation',
          'conflict_record',
          'safety_review',
          'model_registry',
          'system_version',
          'rule_execution',
          'audit_event',
          'provenance_record',
          'clinical_snapshot',
          'reasoning_snapshot',
          'documentation_snapshot'
      );

    IF v_actual_tables = v_expected_tables THEN
        RAISE NOTICE
            'H10 GOVERNANCE OK: %/21 governance tables created.',
            v_actual_tables;
    ELSE
        RAISE EXCEPTION
            'H10 GOVERNANCE INCOMPLETE: expected 21 governance tables, found %.',
            v_actual_tables;
    END IF;

END
$h10_governance$;


-- ============================================================================
-- 29. H10 CONSTITUTIONAL INVARIANTS
-- ============================================================================

COMMENT ON TABLE governance.knowledge_object IS
'AMEXAN H10 constitutional invariant:
No clinical knowledge object may be anonymous.
Every governed object has a stable identity, applicability, evidence metadata,
lifecycle and provenance pathway.';


COMMENT ON TABLE governance.knowledge_object_version IS
'AMEXAN H10 constitutional invariant:
Clinical knowledge history is append-oriented by version.
A new medical rule version never silently destroys the prior version.';


COMMENT ON TABLE governance.knowledge_publication IS
'AMEXAN H10 constitutional invariant:
Publication is a gated clinical governance decision.
Provenance, validation, dependency integrity, jurisdiction, population,
safety, clinical review and approval must all pass before publication.';


COMMENT ON TABLE governance.conflict_record IS
'AMEXAN H10 constitutional invariant:
Contradictory medical knowledge is never silently merged.
Conflict context and resolution remain auditable.';


COMMENT ON TABLE governance.safety_review IS
'AMEXAN H10 constitutional invariant:
Clinical consequence determines governance intensity.
High-risk recommendations require explicit safety governance and appropriate
human oversight.';


COMMENT ON TABLE governance.provenance_record IS
'AMEXAN H10 constitutional invariant:
Every consequential clinical assertion must be traceable backward to its
structured clinical source and ultimately to governed evidence where available.';


COMMENT ON TABLE governance.clinical_snapshot IS
'AMEXAN H10 constitutional invariant:
Historical clinical computation is interpreted using the knowledge and system
state that existed at computation time, not silently re-evaluated against
current knowledge.';


COMMENT ON TABLE governance.rule_execution IS
'AMEXAN H10 constitutional invariant:
Every clinically consequential deterministic rule execution is auditable by
rule identity, version, input state and emitted output.';


COMMENT ON TABLE governance.audit_event IS
'AMEXAN H10 constitutional invariant:
The clinical operating system records the event history of computation,
reasoning, investigation, documentation, human editing and safety events,
not merely the final database state.';


COMMENT ON TABLE governance.model_registry IS
'AMEXAN H10 constitutional invariant:
Computational models are identifiable and versioned.
Language models may realize governed clinical content but may not become an
unattributed source of clinical truth.';


-- ============================================================================
-- END H10 MIGRATION 036
-- ============================================================================