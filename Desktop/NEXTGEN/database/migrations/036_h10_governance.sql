-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H10 migration 036: provenance, governance
-- & clinical knowledge control
-- =============================================================================
-- H10 is the TRUST LAYER of the AMEXAN Clinical OS. It answers:
--
--   "Why should AMEXAN be allowed to believe, use, document, compare, or act
--    on any of this information — and can we prove exactly what happened?"
--
-- It does NOT re-implement the H1 source/claim backbone or the per-layer
-- version registries. It GOVERNS them. Everything here either:
--
--   (a) reuses the shared H1 backbone by reference:
--         knowledge.source / source_version / source_section / source_chapter /
--         source_chunk / source_claim (H1) and the shared derivation-edge law
--         knowledge.provenance (H8 §45/§46) — H10 provenance rows live there
--         with object_type = 'governance_…';
--   (b) reuses the per-layer version registries by reference:
--         knowledge.reasoning_version (H8), knowledge.documentation_version (H9),
--         knowledge.investigation_version (H7), knowledge.differential_version;
--   (c) or adds the governance/audit/replay family the spec §50 lists.
--
-- H10's eight constitutional responsibilities (spec §3):
--   1 Provenance    5 Knowledge lifecycle
--   2 Versioning    6 Safety controls
--   3 Governance    7 Conflict management
--   4 Auditability  8 Reproducibility
--
-- Architectural law (as in H6/H7/H8/H9):
--   PostgreSQL = KNOWLEDGE + CONFIGURATION (the governance catalogue)
--   CPU        = EXECUTION / REPLAY         (writes rule_execution / audit_event /
--                                            snapshots per computation)
--   UI         = RENDERING                  (renders governed knowledge only)
--
-- RUNTIME tables below (rule_execution / audit_event / provenance_record /
-- clinical_snapshot / reasoning_snapshot / documentation_snapshot) are created
-- EMPTY — the CPU records them per computation, exactly as H7/H8/H9 leave their
-- runtime tables empty at seed time.
--
-- SHARED-REGISTRY REUSE (H10 must NOT redefine these):
--   • source claims   — knowledge.source_claim(claim_code) for every governed
--                       object's provenance (H1 + §46 law)
--   • version lineage — knowledge.reasoning_version / documentation_version
--   • clinical anchor — patient.patient / encounter.encounter / reasoning_run
--                       / documentation_instance referenced by snapshot family
-- =============================================================================

-- ---------------------------------------------------------------------------
-- GOVERNANCE SCHEMA
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS governance;
COMMENT ON SCHEMA governance
    IS 'H10 governance backbone: provenance, versioning, audit, safety, conflicts, reproducibility.';

-- ---------------------------------------------------------------------------
-- A1. jurisdiction — applicable geography (#22/#24): core + jurisdictional overlay
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.jurisdiction (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_code text NOT NULL UNIQUE,   -- JUR-GLOBAL / JUR-KENYA / …
    name          text NOT NULL,
    description   text,
    country_code  text,                       -- ISO-3166-1 alpha-2, NULL = global
    is_default    boolean NOT NULL DEFAULT false,
    is_active     boolean NOT NULL DEFAULT true,
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.jurisdiction
    IS 'Applicable geography for governed knowledge (#22). Universal core + jurisdictional overlays, never duplicated systems per country.';
DROP TRIGGER IF EXISTS trg_gov_jurisdiction_updated_at ON governance.jurisdiction;
CREATE TRIGGER trg_gov_jurisdiction_updated_at
    BEFORE UPDATE ON governance.jurisdiction FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A2. population_context — population overlays (#15/#23)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.population_context (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    population_code text NOT NULL UNIQUE,     -- POP-ADULT / POP-PAEDIATRIC / …
    name          text NOT NULL,
    description   text,
    applies_to_context_codes text[] NOT NULL DEFAULT '{}',  -- clinical_context.code
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.population_context
    IS 'Population overlays for governed knowledge (#23): adult / paediatric / neonate / pregnancy / geriatric / …';
DROP TRIGGER IF EXISTS trg_gov_population_context_updated_at ON governance.population_context;
CREATE TRIGGER trg_gov_population_context_updated_at
    BEFORE UPDATE ON governance.population_context FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A3. evidence_metadata — evidence level classification (#15/#45)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.evidence_metadata (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_level_code text NOT NULL UNIQUE, -- EV-A .. EV-E
    level_label   text NOT NULL,
    ranking       integer NOT NULL,           -- 1 highest .. 5 lowest
    description   text,
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.evidence_metadata
    IS 'Evidence-level classification for governed knowledge (#15): a rule knows how well-supported it is, without deciding on its own authority.';
DROP TRIGGER IF EXISTS trg_gov_evidence_metadata_updated_at ON governance.evidence_metadata;
CREATE TRIGGER trg_gov_evidence_metadata_updated_at
    BEFORE UPDATE ON governance.evidence_metadata FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A4. knowledge_object — UNIVERSAL registry of governed objects (#14/#15/#40)
--     One row per governed object across ALL layers (question / fact /
--     phenotype / mechanism / diagnosis / rule / protocol / documentation…),
--     carrying its lifecycle status, jurisdiction, population, evidence level
--     and source claim. Polymorphic object_code (the H1-H9 business code).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_object (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_code         text NOT NULL UNIQUE,   -- e.g. Q-COUGH_DURATION / DEV-003 / DA001
    knowledge_type      text NOT NULL CHECK (knowledge_type IN
        ('CLINICAL_FACT','SYMPTOM','PHENOTYPE','MECHANISM','AETIOLOGY','DIAGNOSIS',
         'RISK_FACTOR','COMPLICATION','QUESTION','QUESTION_OPTION','EXAMINATION',
         'EXAM_FINDING','INVESTIGATION','INTERPRETATION','DIFFERENTIAL_RULE','PROTOCOL',
         'GUIDELINE','DRUG','CONTRAINDICATION','DOSING_RULE','MONITORING_RULE',
         'DOCUMENTATION_RULE','DOCUMENTATION_TEMPLATE','DOCUMENTATION_SECTION',
         'KNOWLEDGE_VERSION','SYSTEM_VERSION')),
    canonical_name      text NOT NULL,
    description         text,
    source_claim_code   text REFERENCES knowledge.source_claim(claim_code),  -- H1 provenance
    jurisdiction_code   text NOT NULL REFERENCES governance.jurisdiction(jurisdiction_code) DEFAULT 'JUR-GLOBAL',
    population_code     text REFERENCES governance.population_context(population_code),
    evidence_level_code text NOT NULL REFERENCES governance.evidence_metadata(evidence_level_code) DEFAULT 'EV-C',
    lifecycle_status    text NOT NULL DEFAULT 'DRAFT'
                        CHECK (lifecycle_status IN
                            ('DRAFT','EXTRACTED','STRUCTURED','CLINICALLY_REVIEWED',
                             'VALIDATED','APPROVED','ACTIVE','DEPRECATED','RETIRED','SUPERSEDED')),  -- #40 + #8
    effective_from      date,
    effective_to        date,
    confidence          numeric(3,2) NOT NULL DEFAULT 0.9 CHECK (confidence BETWEEN 0 AND 1),
    review_date         date,                    -- next review due (#15)
    created_by          text,                    -- author of the object (#15)
    reviewed_by         text,
    approved_by         text,
    is_active           boolean NOT NULL DEFAULT true,
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active','draft','retired')),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.knowledge_object
    IS 'Universal governed-knowledge registry (#14/#15/#40): every object across layers carries identity, version, lifecycle, jurisdiction, population, evidence level and source claim. No anonymous clinical logic.';
CREATE INDEX IF NOT EXISTS idx_gov_kobj_type  ON governance.knowledge_object(knowledge_type);
CREATE INDEX IF NOT EXISTS idx_gov_kobj_jur   ON governance.knowledge_object(jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_gov_kobj_status ON governance.knowledge_object(lifecycle_status);
DROP TRIGGER IF EXISTS trg_gov_knowledge_object_updated_at ON governance.knowledge_object;
CREATE TRIGGER trg_gov_knowledge_object_updated_at
    BEFORE UPDATE ON governance.knowledge_object FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A5. knowledge_object_version — version rows; never overwrite history (#8/#9/#10)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_object_version (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_id         uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    version_no        integer NOT NULL CHECK (version_no >= 1),
    version_code      text NOT NULL UNIQUE,      -- e.g. GO-VER-DEV003-2
    change_note       text,
    supersedes_version_id uuid REFERENCES governance.knowledge_object_version(id),  -- #8 OLD -> RETIRED
    lifecycle_status  text NOT NULL DEFAULT 'DRAFT'
                      CHECK (lifecycle_status IN
                          ('DRAFT','EXTRACTED','STRUCTURED','CLINICALLY_REVIEWED',
                           'VALIDATED','APPROVED','ACTIVE','DEPRECATED','RETIRED','SUPERSEDED')),
    effective_from    date,
    effective_to      date,
    source_claim_code text REFERENCES knowledge.source_claim(claim_code),
    created_by        text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (object_id, version_no)
);
COMMENT ON TABLE governance.knowledge_object_version
    IS 'Versioned state of a governed object (#8): v→v+1 never overwrites history; the old version is retired and pointed to by supersedes.';
CREATE INDEX IF NOT EXISTS idx_gov_kobjver_obj ON governance.knowledge_object_version(object_id);
DROP TRIGGER IF EXISTS trg_gov_knowledge_object_version_updated_at ON governance.knowledge_object_version;
CREATE TRIGGER trg_gov_knowledge_object_version_updated_at
    BEFORE UPDATE ON governance.knowledge_object_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A6. knowledge_relationship — the governed knowledge graph (#42/#43)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_relationship (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_code text NOT NULL UNIQUE,
    from_object_id   uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    to_object_id     uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    relationship_type text NOT NULL CHECK (relationship_type IN
        ('ASSESSES','SUPPORTS','OPPOSES','TRIGGERS','RULES','REQUIRES','DOCUMENTS',
         'PRECEDES','SPECIALIZES','CONTRAINDICATES','DERIVED_FROM')),
    weight           numeric(5,2) NOT NULL DEFAULT 1.0,
    source_claim_code text REFERENCES knowledge.source_claim(claim_code),
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.knowledge_relationship
    IS 'Edges of the governed knowledge graph (#42/#43): source → concept → rule → protocol, each versioned and attributable.';
CREATE INDEX IF NOT EXISTS idx_gov_krel_from ON governance.knowledge_relationship(from_object_id);
CREATE INDEX IF NOT EXISTS idx_gov_krel_to   ON governance.knowledge_relationship(to_object_id);

-- ---------------------------------------------------------------------------
-- A7. knowledge_dependency — dependency edges for cycle detection (#28/#29)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_dependency (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dependency_code    text NOT NULL UNIQUE,
    dependent_object_id  uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,  -- needs
    required_object_id   uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,  -- to be active
    dependency_type    text NOT NULL DEFAULT 'REQUIRES'
                       CHECK (dependency_type IN ('REQUIRES','REQUIRES_CONFIRMATION','CYCLIC_GUARD')),
    is_optional        boolean NOT NULL DEFAULT false,
    source_claim_code  text REFERENCES knowledge.source_claim(claim_code),
    created_at         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (dependent_object_id, required_object_id)
);
COMMENT ON TABLE governance.knowledge_dependency
    IS 'Dependency edges between governed objects (#28/#29). Cycle detection runs over this table before any object is published (ORPHAN / CIRCULAR -> REJECT).';
CREATE INDEX IF NOT EXISTS idx_gov_kdep_depend ON governance.knowledge_dependency(dependent_object_id);
CREATE INDEX IF NOT EXISTS idx_gov_kdep_required ON governance.knowledge_dependency(required_object_id);

-- ---------------------------------------------------------------------------
-- A8. knowledge_review — clinical review events on the lifecycle (#11/#12/#13)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_review (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    review_code   text NOT NULL UNIQUE,
    object_id     uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    review_type   text NOT NULL CHECK (review_type IN ('CLINICAL_REVIEW','VALIDATION','SAFETY','LEGAL')),
    reviewer      text NOT NULL,
    outcome       text NOT NULL CHECK (outcome IN ('PASS','FAIL','PASS_WITH_NOTES')),
    notes         text,
    reviewed_at   timestamptz NOT NULL DEFAULT now(),
    created_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.knowledge_review
    IS 'Clinical/validation/safety review events (#11/#12): a textbook extraction never goes live before review — the lifecycle moves DRAFT→…→REVIEW→…→ACTIVE through this record.';

-- ---------------------------------------------------------------------------
-- A9. knowledge_approval — governance approval (#11/#41)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_approval (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_code text NOT NULL UNIQUE,
    object_id     uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    version_id    uuid REFERENCES governance.knowledge_object_version(id),
    approver      text NOT NULL,
    decision      text NOT NULL CHECK (decision IN ('APPROVED','REJECTED','DEFERRED')),
    note          text,
    approved_at   timestamptz NOT NULL DEFAULT now(),
    created_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.knowledge_approval
    IS 'Governance approvals (#11/#41): who approved, which version, when. PUBLISH gate depends on an APPROVED record for the object version.';

-- ---------------------------------------------------------------------------
-- A10. knowledge_publication — publish gates (#41): all gates must pass to go live
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_publication (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    publication_code    text NOT NULL UNIQUE,
    object_id           uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    version_id          uuid REFERENCES governance.knowledge_object_version(id),
    provenance_complete boolean NOT NULL DEFAULT false,
    validation_passed   boolean NOT NULL DEFAULT false,
    dependency_integrity boolean NOT NULL DEFAULT false,
    jurisdiction_ok     boolean NOT NULL DEFAULT false,
    population_ok       boolean NOT NULL DEFAULT false,
    safety_review_ok    boolean NOT NULL DEFAULT false,
    decision            text NOT NULL CHECK (decision IN ('PUBLISHED','BLOCKED')),
    decision_reason     text,
    published_by        text,
    published_at        timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (object_id, version_id)
);
COMMENT ON TABLE governance.knowledge_publication
    IS 'Publish gate record (#41): provenance complete + validation passed + dependency integrity + jurisdiction + population + safety. If any gate fails -> BLOCKED / DO NOT PUBLISH.';

-- ---------------------------------------------------------------------------
-- A11. knowledge_deprecation — retire/deprecate (#11/#8)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.knowledge_deprecation (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    deprecation_code text NOT NULL UNIQUE,
    object_id       uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    version_id      uuid REFERENCES governance.knowledge_object_version(id),
    deprecation_reason text,
    replacement_object_id uuid REFERENCES governance.knowledge_object(id),  -- superseded_by (#15)
    deprecated_by   text,
    deprecated_at   timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.knowledge_deprecation
    IS 'Deprecation / retirement records (#11/#8): the old version is RETIRED, the replacement is identified — history is never overwritten invisibly.';

-- ---------------------------------------------------------------------------
-- A12. conflict_record — knowledge conflicts (#20/#21) + resolutions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.conflict_record (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conflict_code   text NOT NULL UNIQUE,
    object_id_a     uuid REFERENCES governance.knowledge_object(id),   -- source A
    object_id_b     uuid REFERENCES governance.knowledge_object(id),   -- source B
    conflict_type   text NOT NULL CHECK (conflict_type IN
        ('KNOWLEDGE_CONFLICT','TEMPORAL_CONFLICT','DOCUMENTATION_CONFLICT')),  -- #36/#37
    classification  jsonb,   -- same population? same jurisdiction? same date? (#21)
    description     text NOT NULL,
    status          text NOT NULL DEFAULT 'DETECTED' CHECK (status IN
        ('DETECTED','CLASSIFIED','RESOLVED','PUBLISHED')),
    resolution      text,     -- documented resolution decision (#21)
    resolved_by     text,
    resolved_at     timestamptz,
    source_claim_a  text REFERENCES knowledge.source_claim(claim_code),
    source_claim_b  text REFERENCES knowledge.source_claim(claim_code),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.conflict_record
    IS 'Detected knowledge conflicts (#20) with structured classification + documented resolution (#21). AMEXAN never silently merges contradicting sources.';
CREATE INDEX IF NOT EXISTS idx_gov_conflict_status ON governance.conflict_record(status);
DROP TRIGGER IF EXISTS trg_gov_conflict_record_updated_at ON governance.conflict_record;
CREATE TRIGGER trg_gov_conflict_record_updated_at
    BEFORE UPDATE ON governance.conflict_record FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A13. safety_review — risk classification + human-in-the-loop (#25/#26)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.safety_review (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    safety_code         text NOT NULL UNIQUE,
    object_id           uuid NOT NULL REFERENCES governance.knowledge_object(id) ON DELETE CASCADE,
    risk_class          text NOT NULL CHECK (risk_class IN
        ('INFORMATIONAL','CLINICAL_SUGGESTION','DECISION_SUPPORT',
         'HIGH_RISK_RECOMMENDATION','ACTION_REQUIRING_HUMAN_AUTHORIZATION')),
    human_in_the_loop   boolean NOT NULL DEFAULT false,
    mitigation          text,
    reviewer            text NOT NULL,
    reviewed_at         timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.safety_review
    IS 'Safety classification of governed output (#25): the more consequential, the steeper the governance requirement and human-in-the-loop gate (#26). Configurable policy, never hard-coded per module.';

-- ---------------------------------------------------------------------------
-- A14. model_registry — ML / LLM / deterministic model identity (#47/#48)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.model_registry (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    model_code            text NOT NULL UNIQUE,
    model_name            text NOT NULL,
    model_type            text NOT NULL CHECK (model_type IN ('DETERMINISTIC','ML','LLM')),
    model_version         text NOT NULL,
    training_dataset_version text,
    features              jsonb,            -- input features for ML disposition
    validation_metrics    jsonb,            -- evaluation before deployment (#47)
    deployment_date       date,
    approval_status       text NOT NULL DEFAULT 'DRAFT' CHECK (approval_status IN
        ('DRAFT','REVIEW','APPROVED','ACTIVE','RETIRED')),
    approved_by           text,
    is_active             boolean NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.model_registry
    IS 'Deterministic / ML / LLM model registry (#47/#48): a result records which model+version produced it. An LLM is a language-realisation component, never the hidden source of clinical truth.';
DROP TRIGGER IF EXISTS trg_gov_model_registry_updated_at ON governance.model_registry;
CREATE TRIGGER trg_gov_model_registry_updated_at
    BEFORE UPDATE ON governance.model_registry FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A15. system_version — master version registry tying layer versions (#10/#17)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS governance.system_version (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_version_code text NOT NULL UNIQUE,     -- AMEXAN-1.0.0
    reasoning_version_code      text REFERENCES knowledge.reasoning_version(version_code),       -- H8
    documentation_version_code  text REFERENCES knowledge.documentation_version(version_code),   -- H9
    differential_version_code   text,             -- H8 completion ruleset (KV snapshot)
    engine_version              text NOT NULL,
    released_at                 date,
    is_active                   boolean NOT NULL DEFAULT true,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.system_version
    IS 'Master version fingerprint (#10/#17): a clinical_snapshot records which knowledge+reasoning+documentation versions produced a computation, so history is never silently reinterpreted (#9/#49).';

-- ---------------------------------------------------------------------------
-- B. RUNTIME LAYER (empty at seed — the CPU records per computation)
-- ---------------------------------------------------------------------------

-- B1. rule_execution — every rule/market evaluation the CPU ran (#18)
CREATE TABLE IF NOT EXISTS governance.rule_execution (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id          uuid REFERENCES knowledge.reasoning_run(run_id),
    object_id       uuid REFERENCES governance.knowledge_object(id),
    object_version_id uuid REFERENCES governance.knowledge_object_version(id),
    rule_code       text,                           -- the underlying rule / evidence code
    knowledge_version text,
    input_facts     jsonb,                          -- facts used (#19 black box)
    output          jsonb,                          -- effect emitted
    executed_at     timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.rule_execution
    IS 'Auditable record of every rule the CPU executed (#18): which rule, which version, which facts, which output — the decision black box (#19).';
CREATE INDEX IF NOT EXISTS idx_gov_rule_exec_run ON governance.rule_execution(run_id);

-- B2. audit_event — the clinical computation event stream (#16/#17/#18)
CREATE TABLE IF NOT EXISTS governance.audit_event (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type      text NOT NULL CHECK (event_type IN
        ('CPU_ENGINE_STARTED','QUESTION_DISPLAYED','ANSWER_RECEIVED','FACT_CREATED','FACT_UPDATED',
         'PHENOTYPE_MATCHED','DDX_UPDATED','RULE_EVALUATED','PROTOCOL_SELECTED',
         'INVESTIGATION_REQUESTED','DOCUMENT_GENERATED','SENTENCE_EDITED','DOCUMENT_FINALIZED',
         'ALERT_GENERATED','SYSTEM_VERSION_SELECTED','SNAPSHOT_RECORDED')),
    actor_type      text NOT NULL CHECK (actor_type IN ('CLINICIAN','SYSTEM','API_CLIENT')),
    actor_code      text,
    entity_type     text,                            -- clinical_fact / reasoning_run / documentation_instance / …
    entity_id       uuid,
    entity_code     text,
    previous_value  text,
    new_value       text,
    encounter_id    uuid,
    run_id          uuid REFERENCES knowledge.reasoning_run(run_id),
    correlation_id  uuid,                            -- #17 RUN-001
    occurred_at     timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.audit_event
    IS 'Clinical computation event stream (#16/#17/#18): questions, answers, fact events, H8 updates, H9 regenerations, clinician edits — the whole loop, not just final states.';
CREATE INDEX IF NOT EXISTS idx_gov_audit_enc ON governance.audit_event(encounter_id);
CREATE INDEX IF NOT EXISTS idx_gov_audit_run ON governance.audit_event(run_id);

-- B3. provenance_record — unified two-way trace (#34/#35/#36)
CREATE TABLE IF NOT EXISTS governance.provenance_record (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    direction      text NOT NULL CHECK (direction IN ('FORWARD','BACKWARD')),
    source_claim_code text REFERENCES knowledge.source_claim(claim_code),
    governance_object_code text,
    fact_code      text,                             -- the canonical fact used
    reasoning_run_id uuid REFERENCES knowledge.reasoning_run(run_id),
    documentation_instance_id uuid REFERENCES knowledge.documentation_instance(instance_id),
    documentation_sentence_id uuid REFERENCES knowledge.documentation_sentence(id),
    rule_execution_id uuid REFERENCES governance.rule_execution(id),
    link_type      text NOT NULL DEFAULT 'derived_from',
    created_at     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.provenance_record
    IS 'Two-way trace links (#34/#35/#36): forward from Hutchison → question → fact → H8 → H9, and backward from a rendered sentence to its facts, rules and source. Queryable, not a narrative.';
CREATE INDEX IF NOT EXISTS idx_gov_prov_rec_dir ON governance.provenance_record(direction);
CREATE INDEX IF NOT EXISTS idx_gov_prov_rec_sent ON governance.provenance_record(documentation_sentence_id);

-- B4. clinical_snapshot — the SNAPSHOT PRINCIPLE (#10): patient+knowledge+rule state
CREATE TABLE IF NOT EXISTS governance.clinical_snapshot (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id          uuid REFERENCES patient.patient(id),
    encounter_id        uuid,
    captured_at         timestamptz NOT NULL DEFAULT now(),
    system_version_code text REFERENCES governance.system_version(system_version_code),
    reasoning_version_code   text,
    documentation_version_code text,
    patient_facts       jsonb,             -- fact state at the snapshot (#10/#30)
    knowledge_state     jsonb,             -- knowledge + rule state (§10)
    input_fingerprint   text,              -- deterministic hash of captured input state (#30)
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.clinical_snapshot
    IS 'Clinical computation snapshot (#10/#30): patient facts + knowledge + rule + reasoning + documentation state at one point, reproducibly identifiable.';
CREATE INDEX IF NOT EXISTS idx_gov_snapshot_enc ON governance.clinical_snapshot(encounter_id);
CREATE INDEX IF NOT EXISTS idx_gov_snapshot_pt ON governance.clinical_snapshot(patient_id);

-- B5. reasoning_snapshot — H8 state inside a snapshot (#10/#30/#31)
CREATE TABLE IF NOT EXISTS governance.reasoning_snapshot (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinical_snapshot_id uuid NOT NULL REFERENCES governance.clinical_snapshot(id) ON DELETE CASCADE,
    run_id              uuid REFERENCES knowledge.reasoning_run(run_id),
    reasoning_version_code text,
    candidate_states    jsonb,             -- H8 differential candidate / rank state
    exception_notes     text,
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.reasoning_snapshot
    IS 'H8 reasoning state captured inside a clinical snapshot (#10/#31) so a historical run can be reconstructed and replayed.';

-- B6. documentation_snapshot — H9 document state inside a snapshot (#10/#30)
CREATE TABLE IF NOT EXISTS governance.documentation_snapshot (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinical_snapshot_id uuid NOT NULL REFERENCES governance.clinical_snapshot(id) ON DELETE CASCADE,
    instance_id          uuid REFERENCES knowledge.documentation_instance(instance_id),
    documentation_version_code text,
    sections             jsonb,            -- rendered sections + sentences captured
    created_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE governance.documentation_snapshot
    IS 'H9 documentation state captured inside a clinical snapshot (#10/#30) — a compiled document is never an isolated blob (#51).';

-- ---------------------------------------------------------------------------
-- Completion self-check
-- ---------------------------------------------------------------------------
DO $h10_governance$
BEGIN
    IF to_regclass('governance.knowledge_object') IS NOT NULL
       AND to_regclass('governance.audit_event') IS NOT NULL
       AND to_regclass('governance.clinical_snapshot') IS NOT NULL
    THEN
        RAISE NOTICE 'H10 governance OK: 21-table governance/audit/replay family created (#50)';
    END IF;
END
$h10_governance$;