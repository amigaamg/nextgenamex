-- =============================================================================
-- 058. KNOWLEDGE CONTRADICTION / DEPENDENCY TABLES
-- =============================================================================
--
-- The mechanism engine and investigation selector reference four knowledge
-- tables that the original schema never materialised:
--
--     knowledge.mechanism_contradiction       features that weigh AGAINST a
--                                             mechanism (anti-evidence).
--     knowledge.mechanism_dependency          features a mechanism REQUIRES to
--                                             be credible.
--     knowledge.investigation_context_rule    context-sensitive overrides for
--                                             investigation ordering.
--     knowledge.investigation_dependency      prerequisites between
--                                             investigations (e.g. CXR before
--                                             CT chest).
--
-- The engines wrapped these reads in try/catch to degrade gracefully, but a
-- PostgreSQL statement failure inside an explicit transaction aborts the whole
-- transaction. Creating the tables lets the engines run inside the same
-- BEGIN/ROLLBACK used by machine tests and the CPU's own workflows without
-- poisoning the transaction, and the engines can promote them to required
-- tables later.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Mechanism contradictions
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.mechanism_contradiction (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   feature_code        text NOT NULL,

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   rationale           text,

   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now(),

   UNIQUE (mechanism_id, feature_code)
);

COMMENT ON TABLE knowledge.mechanism_contradiction IS
'Clinical features that contradict or exclude a mechanism.';

CREATE INDEX idx_knowledge_mechanism_contradiction_mech
   ON knowledge.mechanism_contradiction(mechanism_id);

-- -----------------------------------------------------------------------------
-- Mechanism dependencies
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.mechanism_dependency (
   id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   mechanism_id        uuid NOT NULL
                       REFERENCES knowledge.mechanism(id) ON DELETE CASCADE,

   required_feature_code text NOT NULL,

   dependency_type     text NOT NULL DEFAULT 'required'
                       CHECK (
                          dependency_type IN (
                             'required',
                             'probable',
                             'possible'
                          )
                       ),

   weight              numeric(5,4) NOT NULL DEFAULT 1.0,

   rationale           text,

   created_at          timestamptz NOT NULL DEFAULT now(),
   updated_at          timestamptz NOT NULL DEFAULT now(),

   UNIQUE (mechanism_id, required_feature_code, dependency_type)
);

COMMENT ON TABLE knowledge.mechanism_dependency IS
'Features a mechanism depends on to remain credible.';

CREATE INDEX idx_knowledge_mechanism_dependency_mech
   ON knowledge.mechanism_dependency(mechanism_id);

-- -----------------------------------------------------------------------------
-- Investigation context rules
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.investigation_context_rule (
   id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_code    text NOT NULL
                         REFERENCES knowledge.investigation(investigation_code)
                         ON DELETE CASCADE,

   context_type          text NOT NULL,

   context_value         text NOT NULL,

   action                text NOT NULL
                         CHECK (
                            action IN (
                               'prioritize',
                               'defer',
                               'restrict',
                               'exclude'
                            )
                         ),

   priority_weight       numeric(5,4) NOT NULL DEFAULT 0,

   rationale             text,

   status                text NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','deprecated')),

   created_at            timestamptz NOT NULL DEFAULT now(),
   updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.investigation_context_rule IS
'Context-sensitive overrides that re-order or gate investigation recommendations.';

CREATE INDEX idx_knowledge_inv_context_rule_investigation
   ON knowledge.investigation_context_rule(investigation_code);

-- -----------------------------------------------------------------------------
-- Investigation dependencies (prerequisites)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS knowledge.investigation_dependency (
   id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

   investigation_code            text NOT NULL
                                 REFERENCES knowledge.investigation(investigation_code)
                                 ON DELETE CASCADE,

   prerequisite_investigation_code text NOT NULL,

   rationale                     text,

   status                        text NOT NULL DEFAULT 'active'
                                 CHECK (status IN ('active','deprecated')),

   created_at                    timestamptz NOT NULL DEFAULT now(),
   updated_at                    timestamptz NOT NULL DEFAULT now(),

   UNIQUE (investigation_code, prerequisite_investigation_code)
);

COMMENT ON TABLE knowledge.investigation_dependency IS
'Prerequisites between investigations, e.g. a plain film before CT chest.';

CREATE INDEX idx_knowledge_inv_dependency_investigation
   ON knowledge.investigation_dependency(investigation_code);