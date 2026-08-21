-- =============================================================================
-- 059. MONITORING CRITICAL THRESHOLDS + PROTOCOL ESCALATION COLUMNS
-- =============================================================================
--
-- The monitoring engine (MonitoringEngine) reads optional severity attributes
-- off the monitoring registry and protocol_monitoring junction that the
-- original physical schema never materialised:
--
--     knowledge.monitoring
--         critical_low / critical_high   urgent/critical range boundaries
--         measurement_code               unit-conversion / measurement metadata
--
--     knowledge.protocol_monitoring
--         escalation_level               protocol-configured severity override
--         persistence_count              consecutive-observation persistence rule
--
-- All five are optional (NULL-safe in the engine). Adding them as nullable
-- columns lets the engine run inside BEGIN/ROLLBACK machine tests without a
-- missing-column failure aborting the whole transaction, and lets the
-- knowledge compiler populate them going forward.
-- =============================================================================

ALTER TABLE knowledge.monitoring
    ADD COLUMN IF NOT EXISTS critical_low    numeric,
    ADD COLUMN IF NOT EXISTS critical_high   numeric,
    ADD COLUMN IF NOT EXISTS measurement_code text;

ALTER TABLE knowledge.protocol_monitoring
    ADD COLUMN IF NOT EXISTS escalation_level text,
    ADD COLUMN IF NOT EXISTS persistence_count integer;