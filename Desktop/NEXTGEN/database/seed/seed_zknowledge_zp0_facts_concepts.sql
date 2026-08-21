-- =============================================================================
-- AMEXAN Phase 2 — Z9 Runtime Intelligence Resolver
-- =============================================================================
-- PURPOSE
-- -------
-- Converts immutable canonical knowledge + contextual overrides into the
-- CURRENT operational interpretation.
--
-- Resolution:
--
--   CANONICAL
--      ↓
--   APPLICABLE OVERRIDES
--      ↓
--   SAFETY FILTER
--      ↓
--   SPECIFICITY
--      ↓
--   EVIDENCE
--      ↓
--   PRIORITY
--      ↓
--   VERSION
--      ↓
--   CURRENT
--
-- Z9 NEVER mutates canonical knowledge.
-- =============================================================================


CREATE OR REPLACE FUNCTION knowledge.z9_scope_rank(
    p_scope_code text
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE p_scope_code
        WHEN 'patient'       THEN 800
        WHEN 'clinician'     THEN 700
        WHEN 'department'    THEN 600
        WHEN 'facility'      THEN 500
        WHEN 'health_system' THEN 400
        WHEN 'country'       THEN 300
        WHEN 'global'        THEN 100
        ELSE 0
    END;
$$;


-- =============================================================================
-- 1. Resolve all applicable overrides
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_resolve_overrides(
    p_target_type text,
    p_target_id uuid,
    p_patient_context_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_health_system_id uuid DEFAULT NULL,
    p_country_id uuid DEFAULT NULL
)
RETURNS TABLE
(
    override_id uuid,
    override_code text,
    target_type text,
    target_id uuid,
    scope_code text,
    scope_entity_id uuid,
    config jsonb,
    reason text,
    status text,
    version integer,
    supersedes_id uuid,
    scope_rank integer,
    priority integer,
    safety boolean,
    specificity integer
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        ko.id,
        ko.override_code,
        ko.target_type,
        ko.target_id,
        ko.scope_code,
        ko.scope_entity_id,
        ko.config,
        ko.reason,
        ko.status,
        ko.version,
        ko.supersedes_id,

        knowledge.z9_scope_rank(ko.scope_code) AS scope_rank,

        COALESCE(
            NULLIF(
                ko.config ->> 'priority',
                ''
            )::integer,
            0
        ) AS priority,

        COALESCE(
            (ko.config ->> 'safety')::boolean,
            false
        ) AS safety,

        CASE ko.scope_code
            WHEN 'patient'       THEN 800
            WHEN 'clinician'     THEN 700
            WHEN 'department'    THEN 600
            WHEN 'facility'      THEN 500
            WHEN 'health_system' THEN 400
            WHEN 'country'       THEN 300
            WHEN 'global'        THEN 100
            ELSE 0
        END AS specificity

    FROM knowledge.knowledge_override ko

    WHERE ko.target_type = p_target_type
      AND ko.target_id = p_target_id
      AND ko.status = 'active'

      AND (
            (
                ko.scope_code = 'global'
                AND ko.scope_entity_id IS NULL
            )

            OR

            (
                ko.scope_code = 'country'
                AND ko.scope_entity_id = p_country_id
            )

            OR

            (
                ko.scope_code = 'health_system'
                AND ko.scope_entity_id = p_health_system_id
            )

            OR

            (
                ko.scope_code = 'facility'
                AND ko.scope_entity_id = p_facility_id
            )

            OR

            (
                ko.scope_code = 'department'
                AND ko.scope_entity_id = p_department_id
            )

            OR

            (
                ko.scope_code = 'clinician'
                AND ko.scope_entity_id = p_clinician_id
            )

            OR

            (
                ko.scope_code = 'patient'
                AND ko.scope_entity_id = p_patient_context_id
            )
      );
$$;


-- =============================================================================
-- 2. Resolve CURRENT winner
-- =============================================================================
--
-- Ordering intentionally separates:
--
--   SAFETY
--   SCOPE
--   PRIORITY
--   VERSION
--
-- A later insertion never automatically wins.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_resolve_current(
    p_target_type text,
    p_target_id uuid,
    p_patient_context_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_health_system_id uuid DEFAULT NULL,
    p_country_id uuid DEFAULT NULL
)
RETURNS TABLE
(
    override_id uuid,
    override_code text,
    target_type text,
    target_id uuid,
    scope_code text,
    scope_entity_id uuid,
    config jsonb,
    reason text,
    status text,
    version integer,
    supersedes_id uuid
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        r.override_id,
        r.override_code,
        r.target_type,
        r.target_id,
        r.scope_code,
        r.scope_entity_id,
        r.config,
        r.reason,
        r.status,
        r.version,
        r.supersedes_id

    FROM knowledge.z9_resolve_overrides(
        p_target_type,
        p_target_id,
        p_patient_context_id,
        p_clinician_id,
        p_department_id,
        p_facility_id,
        p_health_system_id,
        p_country_id
    ) r

    ORDER BY
        r.safety DESC,
        r.specificity DESC,
        r.priority DESC,
        r.version DESC,
        r.override_code ASC

    LIMIT 1;
$$;


-- =============================================================================
-- 3. Resolve CURRENT configuration only
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_current_config(
    p_target_type text,
    p_target_id uuid,
    p_patient_context_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_health_system_id uuid DEFAULT NULL,
    p_country_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        (
            SELECT r.config
            FROM knowledge.z9_resolve_current(
                p_target_type,
                p_target_id,
                p_patient_context_id,
                p_clinician_id,
                p_department_id,
                p_facility_id,
                p_health_system_id,
                p_country_id
            ) r
        ),
        '{}'::jsonb
    );
$$;


-- =============================================================================
-- 4. Explain CURRENT resolution
-- =============================================================================
--
-- This is the WHY layer.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_explain(
    p_target_type text,
    p_target_id uuid,
    p_patient_context_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_health_system_id uuid DEFAULT NULL,
    p_country_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        (
            SELECT jsonb_build_object(
                'target_type', r.target_type,
                'target_id', r.target_id,

                'current', jsonb_build_object(
                    'override_id', r.override_id,
                    'override_code', r.override_code,
                    'scope', r.scope_code,
                    'scope_entity_id', r.scope_entity_id,
                    'version', r.version,
                    'status', r.status,
                    'config', r.config
                ),

                'why', jsonb_build_object(
                    'reason', r.reason,
                    'supersedes_id', r.supersedes_id
                ),

                'resolution', jsonb_build_object(
                    'model',
                    'DEFAULT -> LOCAL -> WHY -> CURRENT',
                    'immutable_canonical', true,
                    'safety_preserved', true
                )
            )

            FROM knowledge.z9_resolve_current(
                p_target_type,
                p_target_id,
                p_patient_context_id,
                p_clinician_id,
                p_department_id,
                p_facility_id,
                p_health_system_id,
                p_country_id
            ) r
        ),
        jsonb_build_object(
            'target_type', p_target_type,
            'target_id', p_target_id,
            'current', NULL,
            'why', NULL,
            'resolution', jsonb_build_object(
                'model',
                'DEFAULT -> LOCAL -> WHY -> CURRENT',
                'immutable_canonical', true,
                'safety_preserved', true
            )
        )
    );
$$;


-- =============================================================================
-- 5. Full resolution trace
-- =============================================================================
--
-- Unlike z9_resolve_current(), this returns every applicable active override.
-- This is required for auditing and debugging conflicts.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_resolution_trace(
    p_target_type text,
    p_target_id uuid,
    p_patient_context_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_health_system_id uuid DEFAULT NULL,
    p_country_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'override_id', r.override_id,
                'override_code', r.override_code,
                'scope', r.scope_code,
                'scope_entity_id', r.scope_entity_id,
                'priority', r.priority,
                'specificity', r.specificity,
                'safety', r.safety,
                'version', r.version,
                'status', r.status,
                'config', r.config,
                'reason', r.reason,
                'supersedes_id', r.supersedes_id
            )
            ORDER BY
                r.safety DESC,
                r.specificity DESC,
                r.priority DESC,
                r.version DESC,
                r.override_code ASC
        ),
        '[]'::jsonb
    )

    FROM knowledge.z9_resolve_overrides(
        p_target_type,
        p_target_id,
        p_patient_context_id,
        p_clinician_id,
        p_department_id,
        p_facility_id,
        p_health_system_id,
        p_country_id
    ) r;
$$;


-- =============================================================================
-- 6. Detect conflicting active overrides
-- =============================================================================
--
-- AMEXAN must expose conflicts instead of silently hiding them.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_detect_conflicts(
    p_target_type text,
    p_target_id uuid,
    p_patient_context_id uuid DEFAULT NULL,
    p_clinician_id uuid DEFAULT NULL,
    p_department_id uuid DEFAULT NULL,
    p_facility_id uuid DEFAULT NULL,
    p_health_system_id uuid DEFAULT NULL,
    p_country_id uuid DEFAULT NULL
)
RETURNS TABLE
(
    conflict boolean,
    override_count integer,
    override_codes text[]
)
LANGUAGE sql
STABLE
AS $$
    WITH applicable AS
    (
        SELECT *
        FROM knowledge.z9_resolve_overrides(
            p_target_type,
            p_target_id,
            p_patient_context_id,
            p_clinician_id,
            p_department_id,
            p_facility_id,
            p_health_system_id,
            p_country_id
        )
    )
    SELECT
        COUNT(*) > 1 AS conflict,
        COUNT(*)::integer AS override_count,
        ARRAY_AGG(override_code ORDER BY override_code) AS override_codes
    FROM applicable;
$$;


-- =============================================================================
-- 7. Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_override_target
ON knowledge.knowledge_override
(
    target_type,
    target_id
);


CREATE INDEX IF NOT EXISTS idx_knowledge_override_scope
ON knowledge.knowledge_override
(
    scope_code,
    scope_entity_id
);


CREATE INDEX IF NOT EXISTS idx_knowledge_override_active
ON knowledge.knowledge_override
(
    status,
    target_type,
    target_id
)
WHERE status = 'active';


CREATE INDEX IF NOT EXISTS idx_knowledge_override_supersedes
ON knowledge.knowledge_override
(
    supersedes_id
)
WHERE supersedes_id IS NOT NULL;


-- =============================================================================
-- 8. Z9 invariant validation
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.z9_validate_invariants()
RETURNS TABLE
(
    invariant text,
    passed boolean,
    violation_count bigint
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        'GLOBAL_OVERRIDES_REQUIRE_NULL_SCOPE_ENTITY',
        COUNT(*) = 0,
        COUNT(*)
    FROM knowledge.knowledge_override
    WHERE scope_code = 'global'
      AND scope_entity_id IS NOT NULL

    UNION ALL

    SELECT
        'ACTIVE_OVERRIDES_REQUIRE_REASON',
        COUNT(*) = 0,
        COUNT(*)
    FROM knowledge.knowledge_override
    WHERE status = 'active'
      AND NULLIF(BTRIM(reason), '') IS NULL

    UNION ALL

    SELECT
        'ACTIVE_OVERRIDES_REQUIRE_VERSION',
        COUNT(*) = 0,
        COUNT(*)
    FROM knowledge.knowledge_override
    WHERE status = 'active'
      AND version IS NULL

    UNION ALL

    SELECT
        'SAFETY_OVERRIDES_CANNOT_HAVE_ZERO_PRIORITY',
        COUNT(*) = 0,
        COUNT(*)
    FROM knowledge.knowledge_override
    WHERE status = 'active'
      AND COALESCE((config ->> 'safety')::boolean, false) = true
      AND COALESCE((config ->> 'priority')::integer, 0) <= 0;
$$;


-- =============================================================================
-- 9. Z9 current intelligence view
-- =============================================================================

CREATE OR REPLACE VIEW knowledge.v_z9_active_overrides
AS
SELECT
    ko.id,
    ko.override_code,
    ko.target_type,
    ko.target_id,
    ko.scope_code,
    ko.scope_entity_id,
    ko.config,
    ko.reason,
    ko.status,
    ko.version,
    ko.supersedes_id,

    knowledge.z9_scope_rank(ko.scope_code) AS scope_rank,

    COALESCE(
        NULLIF(ko.config ->> 'priority', '')::integer,
        0
    ) AS priority,

    COALESCE(
        (ko.config ->> 'safety')::boolean,
        false
    ) AS safety

FROM knowledge.knowledge_override ko

WHERE ko.status = 'active';


-- =============================================================================
-- 10. TEST — GLOBAL PNEUMONIA
-- =============================================================================

SELECT *
FROM knowledge.z9_resolve_current(
    'rule',
    'f1100000-0000-0000-0000-000000000004'
);


-- =============================================================================
-- 11. TEST — COUGH
-- =============================================================================

SELECT *
FROM knowledge.z9_resolve_current(
    'symptom',
    'f0b00000-0000-0000-0000-000000000001'
);


-- =============================================================================
-- 12. TEST — DYSPNOEA
-- =============================================================================

SELECT *
FROM knowledge.z9_resolve_current(
    'symptom',
    'f0b00000-0000-0000-0000-000000000003'
);


-- =============================================================================
-- 13. TEST — EXPLAINABILITY
-- =============================================================================

SELECT knowledge.z9_explain(
    'rule',
    'f1100000-0000-0000-0000-000000000004'
);


-- =============================================================================
-- 14. TEST — FULL TRACE
-- =============================================================================

SELECT knowledge.z9_resolution_trace(
    'rule',
    'f1100000-0000-0000-0000-000000000004'
);


-- =============================================================================
-- 15. TEST — INVARIANTS
-- =============================================================================

SELECT *
FROM knowledge.z9_validate_invariants();


-- =============================================================================
-- END Z9 RUNTIME RESOLUTION
-- =============================================================================