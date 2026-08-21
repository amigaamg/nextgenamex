-- =============================================================================
-- AMEXAN — H10 GOVERNED COMMIT: RESPIRATORY VERTICAL SLICE R0–R2
-- =============================================================================
-- The respiratory slice (R0 sources + R1 claims + R2 paediatric population) is
-- committed to PostgreSQL as a governed, versioned release:
--
--   1. every derived clinical object (danger-sign questions, danger facts,
--      paediatric pneumonia alarm phenotype) is registered in
--      governance.knowledge_object — lawful identity, population, evidence
--      level and source claim (Baby Nelson p166–171 / K&C ch28);
--   2. a knowledge_object_version row seals each object as ACTIVE v1;
--   3. a KNOWN VERSION marker object (RESP-VERTICAL-SLICE-1) records the slice;
--   4. a new master system_version fingerprint AMEXAN-1.1.0 supersedes
--      AMEXAN-1.0.0 (the old row is preserved, never overwritten);
--   5. provenance edges tie every governed object + the system_version to the
--      RC-* source claims.
--
-- Idempotent:   ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. system_version — new master fingerprint AMEXAN-1.1.0 supersedes 1.0.0
-- ---------------------------------------------------------------------------
INSERT INTO governance.system_version
    (system_version_code, reasoning_version_code, documentation_version_code,
     differential_version_code, engine_version, released_at, is_active)
VALUES
    ('AMEXAN-1.1.0', 'RV2024.01.001', 'RV2024.01.002', 'RV2024.01.001',
     'CLINICAL-CPU-1.0', CURRENT_DATE, true)
  ON CONFLICT DO NOTHING;

-- The previous master is superseded, not deleted (#8/#9/#10 — history preserved).
UPDATE governance.system_version
   SET is_active = false
 WHERE system_version_code = 'AMEXAN-1.0.0'
   AND is_active = true;

-- ---------------------------------------------------------------------------
-- 4. PROVENANCE — every governed object + the system_version tied to a claim
-- ---------------------------------------------------------------------------
WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'governance_knowledge_object', ko.id, ko.object_code, 'derived_from', 1.0
FROM governance.knowledge_object ko JOIN sc ON sc.claim_code = ko.source_claim_code
WHERE ko.object_code IN
      ('PAEDIATRIC_CHEST_INDRAWING','PAEDIATRIC_GRUNTING','PAEDIATRIC_NASAL_FLARING',
       'PAEDIATRIC_FAST_BREATHING','PAEDIATRIC_POOR_FEEDING','CHEST_INDRAWING','GRUNTING',
       'NASAL_FLARING','FAST_BREATHING','POOR_FEEDING','PHEN-PAEDIATRIC-PNEUMONIA-ALARM',
       'RESP-VERTICAL-SLICE-1')
ON CONFLICT DO NOTHING;

WITH sc AS (SELECT claim_code, claim_id FROM knowledge.source_claim)
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT sc.claim_id, 'governance_knowledge_object_version', v.id, v.version_code, 'derived_from', 1.0
FROM governance.knowledge_object_version v
JOIN governance.knowledge_object ko ON ko.id = v.object_id
JOIN sc ON sc.claim_code = COALESCE(v.source_claim_code, ko.source_claim_code)
WHERE v.version_code LIKE 'GO-V-RESP-%'
ON CONFLICT DO NOTHING;

WITH c AS (SELECT claim_id FROM knowledge.source_claim WHERE claim_code = 'BNR-0003')
INSERT INTO knowledge.provenance (claim_id, object_type, object_id, object_code, relationship, weight)
SELECT c.claim_id, 'governance_system_version', s.id, s.system_version_code, 'derived_from', 1.0
FROM governance.system_version s CROSS JOIN c
WHERE s.system_version_code = 'AMEXAN-1.1.0'
ON CONFLICT DO NOTHING;
