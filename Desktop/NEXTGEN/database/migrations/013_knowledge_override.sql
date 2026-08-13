-- =============================================================================
-- AMEXAN Phase 2 — Migration 013: knowledge override / configuration layer
-- =============================================================================
-- The AMEXAN DEFAULT knowledge is never mutated. Facilities and clinicians
-- express LOCAL overrides as rows that point at the original knowledge node.
-- Every recommendation can therefore expose the full provenance chain:
--
--   DEFAULT RULE  ──►  LOCAL MODIFICATION  ──►  WHY MODIFIED  ──►  CURRENT ACTIVE RULE
--
-- Scope precedence reuses configuration.scope (global < ... < facility < clinician).
-- =============================================================================

CREATE TABLE knowledge.knowledge_override (
   id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
   override_code     text NOT NULL UNIQUE,       -- e.g. OVR-CAP-CXR-DEFER-FAC
   target_type       text NOT NULL,              -- rule / question / phenotype / mechanism / condition / concept / investigation / protocol
   target_id         uuid NOT NULL,              -- id of the knowledge row being overridden (universal)
   scope_code        text NOT NULL REFERENCES configuration.scope(code),
   scope_entity_id   uuid,                       -- facility.id / professional.id / department.id; NULL for global (AMEXAN DEFAULT)
   config            jsonb NOT NULL,             -- override body: params, weights, priority, conditions, recommendation text, ...
   reason            text,                       -- WHY MODIFIED (provenance for the clinician)
   status            text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','retired')),
   effective_from    timestamptz NOT NULL DEFAULT now(),
   effective_to      timestamptz,
   supersedes_id     uuid REFERENCES knowledge.knowledge_override(id),  -- chain back to the rule/lower-scope override it replaces
   version           integer NOT NULL DEFAULT 1,
   author            text,
   created_at        timestamptz NOT NULL DEFAULT now(),
   updated_at        timestamptz NOT NULL DEFAULT now(),
   UNIQUE (target_type, target_id, scope_code, scope_entity_id, version)
);
COMMENT ON TABLE knowledge.knowledge_override IS
   'Facility/clinician knowledge customization. Original knowledge rows are never modified; overrides layer on top with full provenance.';

COMMENT ON COLUMN knowledge.knowledge_override.scope_entity_id IS
   'NULL for AMEXAN DEFAULT (global). Set to the facility/professional/department id for scoped overrides.';

CREATE INDEX idx_knowledge_override_target ON knowledge.knowledge_override(target_type, target_id);
CREATE INDEX idx_knowledge_override_scope ON knowledge.knowledge_override(scope_code, scope_entity_id);
CREATE INDEX idx_knowledge_override_status ON knowledge.knowledge_override(status);

CREATE TRIGGER trg_knowledge_override_updated_at
   BEFORE UPDATE ON knowledge.knowledge_override
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Resolution view: for each target, the CURRENT ACTIVE override per scope.
-- Precedence: clinician > facility > global. Enables the CPU to read exactly
-- the rule that applies right now, and to explain HOW it was reached.
-- ---------------------------------------------------------------------------

CREATE VIEW knowledge.active_override AS
WITH ranked AS (
   SELECT o.*,
          row_number() OVER (
             PARTITION BY o.target_type, o.target_id
             ORDER BY
                CASE o.scope_code WHEN 'clinician' THEN 4 WHEN 'facility' THEN 3
                                  WHEN 'department' THEN 2 WHEN 'organization' THEN 1 ELSE 0 END DESC,
                o.version DESC
          ) AS rn
   FROM knowledge.knowledge_override o
   WHERE o.status = 'active'
     AND (o.effective_to IS NULL OR o.effective_to >= now())
     AND o.effective_from <= now()
)
SELECT id, override_code, target_type, target_id, scope_code, scope_entity_id,
       config, reason, version, supersedes_id
FROM ranked
WHERE rn = 1;
COMMENT ON VIEW knowledge.active_override IS
   'Current active override per knowledge target, by scope precedence. Default (AMEXAN) = no override row.';
