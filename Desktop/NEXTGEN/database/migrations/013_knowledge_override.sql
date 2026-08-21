-- =============================================================================
-- AMEXAN Phase 2 — Migration 013: UNIVERSAL KNOWLEDGE OVERRIDE / CONFIGURATION
-- =============================================================================
-- PURPOSE
-- -------
-- The AMEXAN DEFAULT clinical knowledge substrate is immutable.
--
-- Local practice never edits the universal knowledge node.
-- Instead:
--
--   AMEXAN DEFAULT
--        │
--        ├── ORGANIZATION OVERRIDE
--        │       │
--        │       ├── FACILITY OVERRIDE
--        │       │       │
--        │       │       └── DEPARTMENT OVERRIDE
--        │       │               │
--        │       │               └── CLINICIAN OVERRIDE
--        │
--        └── CURRENT RESOLVED KNOWLEDGE
--
-- Resolution is deterministic:
--
--   clinician > department > facility > organization > global
--
-- The engine can therefore answer:
--
--   WHAT is the default?
--   WHAT changed?
--   WHO changed it?
--   WHERE does it apply?
--   WHEN does it apply?
--   WHY was it changed?
--   WHAT did it supersede?
--   WHAT is the currently effective value?
--   WHAT evidence supports the default?
--
-- IMPORTANT:
--   This layer does NOT replace clinical knowledge.
--   It changes configuration of existing knowledge.
--   The universal knowledge graph remains reusable across every AMEXAN tenant.
-- =============================================================================


-- =============================================================================
-- 1. KNOWLEDGE OVERRIDE
-- =============================================================================

CREATE TABLE knowledge.knowledge_override (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    override_code       text NOT NULL UNIQUE,

    -- Universal knowledge object being modified.
    --
    -- Supported:
    -- concept
    -- symptom
    -- question
    -- answer
    -- fact
    -- rule
    -- phenotype
    -- mechanism
    -- condition
    -- investigation
    -- medication
    -- complication
    -- protocol
    -- management
    -- pathway
    -- recommendation
    -- screening
    -- documentation
    target_type         text NOT NULL
                        CHECK (
                            target_type IN (
                                'concept',
                                'symptom',
                                'question',
                                'answer',
                                'fact',
                                'rule',
                                'phenotype',
                                'mechanism',
                                'condition',
                                'investigation',
                                'medication',
                                'complication',
                                'protocol',
                                'management',
                                'pathway',
                                'recommendation',
                                'screening',
                                'documentation'
                            )
                        ),

    target_id           uuid NOT NULL,

    -- Resolution scope.
    --
    -- global         = AMEXAN universal default
    -- organization   = organization-wide configuration
    -- facility       = facility-specific configuration
    -- department     = department-specific configuration
    -- clinician      = clinician-specific configuration
    scope_code         text NOT NULL
                        REFERENCES configuration.scope(code),

    -- Entity receiving the override.
    --
    -- NULL is valid only for global scope.
    -- The referenced entity depends on scope_code.
    scope_entity_id    uuid,

    -- -------------------------------------------------------------------------
    -- OVERRIDE MODE
    -- -------------------------------------------------------------------------
    --
    -- patch:
    --   modifies selected properties while retaining the default.
    --
    -- replace:
    --   replaces the resolved representation of the targeted property.
    --
    -- disable:
    --   prevents the target from being active in the selected scope.
    --
    -- append:
    --   adds local configuration without replacing universal knowledge.
    --
    override_mode      text NOT NULL DEFAULT 'patch'
                        CHECK (
                            override_mode IN (
                                'patch',
                                'replace',
                                'disable',
                                'append'
                            )
                        ),

    -- -------------------------------------------------------------------------
    -- MACHINE CONFIGURATION
    -- -------------------------------------------------------------------------
    --
    -- Examples:
    --
    -- {
    --   "priority": 90,
    --   "params": {...}
    -- }
    --
    -- {
    --   "question_required": true
    -- }
    --
    -- {
    --   "recommendation": {...}
    -- }
    --
    -- {
    --   "threshold": {...}
    -- }
    --
    -- {
    --   "documentation": {...}
    -- }
    config              jsonb NOT NULL DEFAULT '{}'::jsonb,

    -- Human-readable reason for the modification.
    reason              text,

    -- Clinical / operational justification.
    justification       text,

    -- -------------------------------------------------------------------------
    -- PROVENANCE
    -- -------------------------------------------------------------------------

    author_id           uuid,
    author_type         text
                        CHECK (
                            author_type IS NULL
                            OR author_type IN (
                                'system',
                                'organization',
                                'facility',
                                'department',
                                'clinician',
                                'administrator'
                            )
                        ),

    reviewer_id         uuid,

    reviewed_at         timestamptz,

    approval_status     text NOT NULL DEFAULT 'pending'
                        CHECK (
                            approval_status IN (
                                'not_required',
                                'pending',
                                'approved',
                                'rejected',
                                'expired'
                            )
                        ),

    -- Evidence supporting the local change.
    evidence_level      text,

    evidence_reference  text,

    evidence_url        text,

    -- -------------------------------------------------------------------------
    -- LIFECYCLE
    -- -------------------------------------------------------------------------

    status              text NOT NULL DEFAULT 'draft'
                        CHECK (
                            status IN (
                                'draft',
                                'active',
                                'suspended',
                                'retired',
                                'rejected'
                            )
                        ),

    effective_from      timestamptz NOT NULL DEFAULT now(),

    effective_to        timestamptz,

    -- Version within the same target/scope.
    version             integer NOT NULL DEFAULT 1
                        CHECK (version > 0),

    -- Previous override from which this override evolved.
    supersedes_id       uuid
                        REFERENCES knowledge.knowledge_override(id),

    -- Optional reason for supersession.
    supersession_reason text,

    -- -------------------------------------------------------------------------
    -- AUDIT
    -- -------------------------------------------------------------------------

    created_at          timestamptz NOT NULL DEFAULT now(),

    created_by          text,

    updated_at          timestamptz NOT NULL DEFAULT now(),

    updated_by          text,

    -- -------------------------------------------------------------------------
    -- TEMPORAL INTEGRITY
    -- -------------------------------------------------------------------------

    CHECK (effective_to IS NULL OR effective_to > effective_from),

    -- Global overrides cannot point at a scope entity.
    CHECK (
        (
            scope_code = 'global'
            AND scope_entity_id IS NULL
        )
        OR
        (
            scope_code <> 'global'
            AND scope_entity_id IS NOT NULL
        )
    ),

    -- A configuration must always contain an object.
    CHECK (jsonb_typeof(config) = 'object'),

    UNIQUE (
        target_type,
        target_id,
        scope_code,
        scope_entity_id,
        version
    )
);

COMMENT ON TABLE knowledge.knowledge_override IS
'Immutable-overlay configuration layer for AMEXAN universal clinical knowledge. Local configuration never mutates the universal knowledge substrate.';


COMMENT ON COLUMN knowledge.knowledge_override.target_id IS
'UUID of the universal knowledge object being configured. Its table is determined by target_type.';


COMMENT ON COLUMN knowledge.knowledge_override.scope_entity_id IS
'Entity receiving the override. NULL only for global AMEXAN knowledge.';


COMMENT ON COLUMN knowledge.knowledge_override.config IS
'Machine-readable local configuration patch/replace/append payload.';


COMMENT ON COLUMN knowledge.knowledge_override.supersedes_id IS
'Previous override in the provenance chain. Enables complete historical reconstruction.';


COMMENT ON COLUMN knowledge.knowledge_override.reason IS
'Human-readable explanation of why the local configuration differs from AMEXAN DEFAULT.';


COMMENT ON COLUMN knowledge.knowledge_override.justification IS
'Clinical, regulatory, operational, resource, formulary, or facility justification for the change.';


-- =============================================================================
-- 2. INDEXES — OPTIMIZED FOR THE CLINICAL CPU
-- =============================================================================

CREATE INDEX idx_knowledge_override_target
    ON knowledge.knowledge_override(
        target_type,
        target_id
    );


CREATE INDEX idx_knowledge_override_target_status
    ON knowledge.knowledge_override(
        target_type,
        target_id,
        status
    );


CREATE INDEX idx_knowledge_override_scope
    ON knowledge.knowledge_override(
        scope_code,
        scope_entity_id
    );


CREATE INDEX idx_knowledge_override_scope_target
    ON knowledge.knowledge_override(
        scope_code,
        scope_entity_id,
        target_type,
        target_id
    );


CREATE INDEX idx_knowledge_override_effective
    ON knowledge.knowledge_override(
        effective_from,
        effective_to
    );


CREATE INDEX idx_knowledge_override_active
    ON knowledge.knowledge_override(
        target_type,
        target_id,
        scope_code,
        scope_entity_id,
        version
    )
    WHERE status = 'active';


CREATE INDEX idx_knowledge_override_supersedes
    ON knowledge.knowledge_override(supersedes_id);


CREATE INDEX idx_knowledge_override_config_gin
    ON knowledge.knowledge_override
    USING gin(config);


-- =============================================================================
-- 3. UPDATED-AT TRIGGER
-- =============================================================================

CREATE TRIGGER trg_knowledge_override_updated_at
    BEFORE UPDATE ON knowledge.knowledge_override
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 4. VALIDATE OVERRIDE JSON
-- =============================================================================
-- Prevent arbitrary primitive JSON from entering the configuration layer.

CREATE OR REPLACE FUNCTION knowledge.validate_override_config()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF jsonb_typeof(NEW.config) <> 'object' THEN
        RAISE EXCEPTION
            'knowledge_override.config must be a JSON object';
    END IF;

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_knowledge_override_validate_config
    BEFORE INSERT OR UPDATE ON knowledge.knowledge_override
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.validate_override_config();


-- =============================================================================
-- 5. PREVENT SELF-SUPERSESSION
-- =============================================================================

ALTER TABLE knowledge.knowledge_override
    ADD CONSTRAINT chk_override_not_self_supersede
    CHECK (
        supersedes_id IS NULL
        OR supersedes_id <> id
    );


-- =============================================================================
-- 6. ACTIVE OVERRIDE RESOLUTION
-- =============================================================================
-- Resolution order:
--
--   clinician   5
--   department  4
--   facility    3
--   organization 2
--   global      1
--
-- IMPORTANT:
-- A higher scope does not automatically erase lower-scope configuration.
-- The CPU first resolves the hierarchy and then applies the appropriate
-- override according to the requested scope.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.active_override AS
WITH ranked AS (
    SELECT
        o.*,

        CASE o.scope_code
            WHEN 'clinician'    THEN 5
            WHEN 'department'   THEN 4
            WHEN 'facility'     THEN 3
            WHEN 'organization' THEN 2
            WHEN 'global'       THEN 1
            ELSE 0
        END AS scope_precedence,

        row_number() OVER (
            PARTITION BY
                o.target_type,
                o.target_id,
                o.scope_code,
                o.scope_entity_id

            ORDER BY
                o.version DESC,
                o.effective_from DESC,
                o.created_at DESC
        ) AS scope_rank

    FROM knowledge.knowledge_override o

    WHERE o.status = 'active'

      AND o.approval_status IN (
          'not_required',
          'approved'
      )

      AND o.effective_from <= now()

      AND (
          o.effective_to IS NULL
          OR o.effective_to > now()
      )
)

SELECT
    id,
    override_code,
    target_type,
    target_id,

    scope_code,
    scope_entity_id,

    override_mode,

    config,

    reason,
    justification,

    author_id,
    author_type,

    reviewer_id,
    reviewed_at,

    approval_status,

    evidence_level,
    evidence_reference,
    evidence_url,

    version,
    supersedes_id,
    supersession_reason,

    effective_from,
    effective_to,

    created_at,
    created_by,
    updated_at,
    updated_by,

    scope_precedence

FROM ranked

WHERE scope_rank = 1;


COMMENT ON VIEW knowledge.active_override IS
'Currently effective highest-version override within each target and scope. Used as an intermediate layer by the AMEXAN clinical knowledge resolver.';


-- =============================================================================
-- 7. COMPLETE OVERRIDE CHAIN
-- =============================================================================
-- Allows the CPU / audit system to reconstruct:
--
-- DEFAULT
--   -> ORGANIZATION CHANGE
--      -> FACILITY CHANGE
--         -> DEPARTMENT CHANGE
--            -> CLINICIAN CHANGE
--
-- without modifying historical records.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.override_provenance AS
SELECT
    o.id,
    o.override_code,

    o.target_type,
    o.target_id,

    o.scope_code,
    o.scope_entity_id,

    o.override_mode,

    o.config,

    o.reason,
    o.justification,

    o.author_id,
    o.author_type,

    o.reviewer_id,
    o.reviewed_at,
    o.approval_status,

    o.evidence_level,
    o.evidence_reference,
    o.evidence_url,

    o.status,

    o.effective_from,
    o.effective_to,

    o.version,

    o.supersedes_id,

    parent.override_code AS supersedes_override_code,

    parent.scope_code AS supersedes_scope_code,

    parent.scope_entity_id AS supersedes_scope_entity_id,

    o.supersession_reason,

    o.created_at,
    o.created_by,

    o.updated_at,
    o.updated_by

FROM knowledge.knowledge_override o

LEFT JOIN knowledge.knowledge_override parent
    ON parent.id = o.supersedes_id;


COMMENT ON VIEW knowledge.override_provenance IS
'Full audit/provenance representation of local knowledge modifications and their predecessor chain.';


-- =============================================================================
-- 8. EFFECTIVE KNOWLEDGE REQUEST MODEL
-- =============================================================================
-- A clinical request can supply:
--
--   organization
--   facility
--   department
--   clinician
--
-- This table-valued function returns all applicable overrides ordered from
-- lowest to highest precedence so the resolver can construct the final state.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.resolve_overrides(
    p_target_type text,
    p_target_id uuid,
    p_organization_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL
)
RETURNS TABLE (
    override_id uuid,
    override_code text,
    target_type text,
    target_id uuid,
    scope_code text,
    scope_entity_id uuid,
    override_mode text,
    config jsonb,
    reason text,
    justification text,
    version integer,
    supersedes_id uuid,
    scope_precedence integer,
    effective_from timestamptz,
    effective_to timestamptz
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        o.id,
        o.override_code,
        o.target_type,
        o.target_id,
        o.scope_code,
        o.scope_entity_id,
        o.override_mode,
        o.config,
        o.reason,
        o.justification,
        o.version,
        o.supersedes_id,

        CASE o.scope_code
            WHEN 'global'       THEN 1
            WHEN 'organization' THEN 2
            WHEN 'facility'     THEN 3
            WHEN 'department'   THEN 4
            WHEN 'clinician'    THEN 5
            ELSE 0
        END AS scope_precedence,

        o.effective_from,
        o.effective_to

    FROM knowledge.knowledge_override o

    WHERE o.target_type = p_target_type
      AND o.target_id = p_target_id

      AND o.status = 'active'

      AND o.approval_status IN (
          'not_required',
          'approved'
      )

      AND o.effective_from <= now()

      AND (
          o.effective_to IS NULL
          OR o.effective_to > now()
      )

      AND (
            o.scope_code = 'global'

         OR (
                o.scope_code = 'organization'
                AND o.scope_entity_id = p_organization_id
            )

         OR (
                o.scope_code = 'facility'
                AND o.scope_entity_id = p_facility_id
            )

         OR (
                o.scope_code = 'department'
                AND o.scope_entity_id = p_department_id
            )

         OR (
                o.scope_code = 'clinician'
                AND o.scope_entity_id = p_clinician_id
            )
      )

    ORDER BY
        CASE o.scope_code
            WHEN 'global'       THEN 1
            WHEN 'organization' THEN 2
            WHEN 'facility'     THEN 3
            WHEN 'department'   THEN 4
            WHEN 'clinician'    THEN 5
            ELSE 0
        END ASC,

        o.version ASC,

        o.effective_from ASC;
$$;


COMMENT ON FUNCTION knowledge.resolve_overrides IS
'Returns all currently applicable knowledge overrides in deterministic precedence order for the AMEXAN clinical knowledge resolver.';


-- =============================================================================
-- 9. OVERRIDE EFFECTIVE STATE
-- =============================================================================
-- This view exposes one row per target/scope combination while retaining the
-- full machine configuration needed by the clinical CPU.
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.effective_override AS
WITH ranked AS (

    SELECT
        o.*,

        CASE o.scope_code
            WHEN 'global'       THEN 1
            WHEN 'organization' THEN 2
            WHEN 'facility'     THEN 3
            WHEN 'department'   THEN 4
            WHEN 'clinician'    THEN 5
            ELSE 0
        END AS scope_precedence,

        row_number() OVER (
            PARTITION BY
                o.target_type,
                o.target_id,
                o.scope_code,
                o.scope_entity_id

            ORDER BY
                o.version DESC,
                o.effective_from DESC,
                o.created_at DESC
        ) AS rn

    FROM knowledge.knowledge_override o

    WHERE o.status = 'active'
      AND o.approval_status IN ('not_required', 'approved')
      AND o.effective_from <= now()
      AND (
          o.effective_to IS NULL
          OR o.effective_to > now()
      )
)

SELECT
    id,
    override_code,

    target_type,
    target_id,

    scope_code,
    scope_entity_id,

    override_mode,

    config,

    reason,
    justification,

    evidence_level,
    evidence_reference,
    evidence_url,

    version,
    supersedes_id,

    scope_precedence,

    effective_from,
    effective_to

FROM ranked

WHERE rn = 1;


COMMENT ON VIEW knowledge.effective_override IS
'Latest currently effective approved configuration for every target/scope pair.';


-- =============================================================================
-- 10. PROVENANCE EVENTS
-- =============================================================================
-- Configuration changes themselves become auditable clinical-system events.
-- =============================================================================

CREATE TABLE knowledge.override_event (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    override_id         uuid NOT NULL
                        REFERENCES knowledge.knowledge_override(id)
                        ON DELETE CASCADE,

    event_type          text NOT NULL
                        CHECK (
                            event_type IN (
                                'created',
                                'submitted',
                                'approved',
                                'rejected',
                                'activated',
                                'suspended',
                                'retired',
                                'superseded',
                                'expired'
                            )
                        ),

    actor_id            uuid,

    actor_type          text,

    event_reason        text,

    previous_status     text,

    new_status          text,

    event_data          jsonb NOT NULL DEFAULT '{}'::jsonb,

    created_at          timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX idx_override_event_override
    ON knowledge.override_event(override_id, created_at);


CREATE INDEX idx_override_event_type
    ON knowledge.override_event(event_type, created_at);


COMMENT ON TABLE knowledge.override_event IS
'Immutable audit events describing the lifecycle of clinical knowledge overrides.';


-- =============================================================================
-- 11. IMMUTABILITY GUARD FOR AUDIT EVENTS
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.prevent_override_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'knowledge.override_event is append-only and cannot be modified or deleted';
END;
$$;


CREATE TRIGGER trg_override_event_immutable_update
    BEFORE UPDATE ON knowledge.override_event
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.prevent_override_event_mutation();


CREATE TRIGGER trg_override_event_immutable_delete
    BEFORE DELETE ON knowledge.override_event
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.prevent_override_event_mutation();


-- =============================================================================
-- 12. KNOWLEDGE RESOLUTION PRIORITY FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.scope_precedence(
    p_scope_code text
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE p_scope_code
        WHEN 'global'       THEN 1
        WHEN 'organization' THEN 2
        WHEN 'facility'     THEN 3
        WHEN 'department'   THEN 4
        WHEN 'clinician'    THEN 5
        ELSE 0
    END;
$$;


COMMENT ON FUNCTION knowledge.scope_precedence IS
'Canonical AMEXAN knowledge configuration precedence: global < organization < facility < department < clinician.';


-- =============================================================================
-- 13. TARGET INTEGRITY
-- =============================================================================
-- The polymorphic target cannot use ordinary PostgreSQL foreign keys.
-- This trigger verifies that the requested knowledge object exists in the
-- corresponding universal knowledge table.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_override_target()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    target_exists boolean := false;
BEGIN

    CASE NEW.target_type

        WHEN 'concept' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.concept
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'symptom' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.symptom
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'question' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.question
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'answer' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.answer_option
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'rule' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.rule
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'phenotype' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.phenotype
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'mechanism' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.mechanism
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        WHEN 'condition' THEN
            SELECT EXISTS (
                SELECT 1
                FROM knowledge.condition
                WHERE id = NEW.target_id
            )
            INTO target_exists;

        ELSE
            -- Additional target layers can be registered as they are created.
            target_exists := true;

    END CASE;


    IF NOT target_exists THEN
        RAISE EXCEPTION
            'Invalid knowledge override target: type=%, id=%',
            NEW.target_type,
            NEW.target_id;
    END IF;


    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_knowledge_override_validate_target
    BEFORE INSERT OR UPDATE ON knowledge.knowledge_override
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.validate_override_target();


-- =============================================================================
-- 14. SCOPE CONSISTENCY
-- =============================================================================
-- Explicitly prevents accidental cross-scope rows.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_override_scope()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.scope_code = 'global'
       AND NEW.scope_entity_id IS NOT NULL
    THEN
        RAISE EXCEPTION
            'Global AMEXAN knowledge overrides cannot have scope_entity_id';
    END IF;


    IF NEW.scope_code <> 'global'
       AND NEW.scope_entity_id IS NULL
    THEN
        RAISE EXCEPTION
            'Non-global knowledge overrides require scope_entity_id';
    END IF;


    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_knowledge_override_validate_scope
    BEFORE INSERT OR UPDATE ON knowledge.knowledge_override
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.validate_override_scope();


-- =============================================================================
-- 15. EFFECTIVE OVERRIDE LOOKUP INDEX
-- =============================================================================
-- Optimized for the clinical CPU's hot path:
--
-- "Give me the current configuration for this knowledge node."
-- =============================================================================

CREATE INDEX idx_knowledge_override_cpu_lookup
    ON knowledge.knowledge_override (
        target_type,
        target_id,
        scope_code,
        scope_entity_id,
        status,
        approval_status,
        effective_from,
        effective_to
    );


-- =============================================================================
-- 16. DEFAULT KNOWLEDGE PRINCIPLE
-- =============================================================================
-- No override row means:
--
--       USE AMEXAN UNIVERSAL DEFAULT
--
-- This intentionally remains a logical rule rather than copying every default
-- knowledge object into this table.
-- =============================================================================

COMMENT ON SCHEMA knowledge IS
'AMEXAN Universal Clinical Knowledge Substrate. Default knowledge is reusable and immutable by local configuration. knowledge_override provides scoped, versioned, auditable overlays without duplicating or mutating the universal clinical knowledge graph.';


-- =============================================================================
-- 17. FINAL RESOLUTION CONTRACT
-- =============================================================================
--
-- The AMEXAN Clinical CPU should resolve knowledge in this order:
--
--   1. LOAD UNIVERSAL DEFAULT
--   2. LOAD GLOBAL OVERRIDE
--   3. APPLY ORGANIZATION OVERRIDE
--   4. APPLY FACILITY OVERRIDE
--   5. APPLY DEPARTMENT OVERRIDE
--   6. APPLY CLINICIAN OVERRIDE
--   7. APPLY TEMPORAL VALIDITY
--   8. APPLY APPROVAL STATUS
--   9. APPLY OVERRIDE MODE
--  10. RETAIN FULL PROVENANCE
--  11. RETURN RESOLVED KNOWLEDGE
--
-- The clinical knowledge itself is therefore never duplicated per facility.
--
-- Example:
--
--   CNS-COUGH
--       │
--       ├── universal symptom definition
--       ├── universal questions
--       ├── universal red flags
--       ├── universal mechanisms
--       ├── universal phenotypes
--       ├── universal differential relationships
--       └── universal clinical rules
--                    │
--                    ▼
--             KNOWLEDGE OVERRIDE
--                    │
--          ┌─────────┴──────────┐
--          │                    │
--      FACILITY             CLINICIAN
--      config                 config
--          │                    │
--          └─────────┬──────────┘
--                    ▼
--             RESOLVED KNOWLEDGE
--
-- This preserves one universal medical vocabulary while allowing local,
-- facility, departmental and clinician-specific practice configuration.
-- =============================================================================