-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H9 migration 035: documentation completion
-- =============================================================================
-- Complements migration 034 with the document-LIFECYCLE and human-EDITING
-- objects the H9 spec mandates but the compiler core model deferred to the
-- audit layer (§29 / §38 / §39 / §41):
--
--   §29 documentation_document:
--     - patient_id          — which patient the clinical document belongs to
--     - author_id           — responsible clinician (organization.professional)
--     - document_type       — HPI / SOAP / discharge / referral / … (H9 §25)
--     - document_version    — per-document versioning v1/v2/v3 (H9 §41)
--     - document_status     — draft / final / amended (H9 §29)
--     - finalized_at        — timestamp of finalization (H9 §29)
--     - amended_from_id     — linkage of an amended document to its parent
--       (H9 §41: who changed it, when, from which prior version)
--     - finalized_by_id     — who finalized / amended it (H9 §41 who)
--
--   §38 documentation_sentence.author_status — provenance of human editing:
--       SYSTEM_GENERATED / CLINICIAN_EDITED / CLINICIAN_ADDED /
--       CLINICIAN_DELETED / SYSTEM_VALIDATED (H9 §38)
--
--   §39 human edit ≠ database fact — the amended text column(s) are stored on
--     the SENTENCE (a rendered view), never silently pushing into the fact
--     layer; fact_value in documentation_sentence_fact remains the structured
--     source of truth exactly as §40 mandates.
--
-- These are ADD COLUMN IF NOT EXISTS so both a fresh build (migrations applied
-- 001→035) and the live amexan DB (with 001→034 already applied) converge to
-- the same H9 schema. Runtime rows remain EMPTY at rest — the CPU writes them.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- §29 + §41: documentation_instance — document lifecycle + versioning
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS patient_id         uuid REFERENCES patient.patient(id);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS author_id          uuid REFERENCES organization.professional(id);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS document_type      text CHECK (document_type IS NULL OR document_type IN
        ('HPI','SOAP','CLERKING','ADMISSION','PROGRESS','WARD_ROUND','CONSULTATION',
         'EMERGENCY','DISCHARGE','REFERRAL','TRANSFER','OPERATIVE','PROCEDURE',
         'PRESCRIPTION','MAR','NURSING','PATIENT_INSTRUCTIONS','HANDOVER'));

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS document_version   integer NOT NULL DEFAULT 1 CHECK (document_version >= 1);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS document_status    text NOT NULL DEFAULT 'DRAFT'
        CHECK (document_status IN ('DRAFT','FINAL','AMENDED'));

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS finalized_at       timestamptz;

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS finalized_by_id    uuid REFERENCES organization.professional(id);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS amended_from_id    uuid REFERENCES knowledge.documentation_instance(instance_id);

COMMENT ON COLUMN knowledge.documentation_instance.document_version
    IS 'Per-document version v1/v2/v3... (H9 §41). Increments on each amendment; amended_from_id records the prior version that was amended.';
COMMENT ON COLUMN knowledge.documentation_instance.document_status
    IS 'Document lifecycle: DRAFT → FINAL → AMENDED (H9 §29). Independent of the CPU compile status (RUNNING/COMPILED/FAILED).';

-- ---------------------------------------------------------------------------
-- §38 + §39: documentation_sentence — human-edit provenance + amendment chain
-- ---------------------------------------------------------------------------
ALTER TABLE knowledge.documentation_sentence
    ADD COLUMN IF NOT EXISTS author_status      text NOT NULL DEFAULT 'SYSTEM_GENERATED'
        CHECK (author_status IN
            ('SYSTEM_GENERATED','CLINICIAN_EDITED','CLINICIAN_ADDED',
             'CLINICIAN_DELETED','SYSTEM_VALIDATED'));

ALTER TABLE knowledge.documentation_sentence
    ADD COLUMN IF NOT EXISTS amended_from_id    uuid REFERENCES knowledge.documentation_sentence(id);

COMMENT ON COLUMN knowledge.documentation_sentence.author_status
    IS 'Who produced the rendered sentence — SYSTEM_GENERATED / CLINICIAN_EDITED / CLINICIAN_ADDED / CLINICIAN_DELETED / SYSTEM_VALIDATED (H9 §38). A human edit never pushes into the fact layer (H9 §39).';

COMMENT ON COLUMN knowledge.documentation_sentence.amended_from_id
    IS 'Previous rendered version of this sentence (H9 §38/§41) so a clinician amendment is auditable back to the generated sentence it superseded.';

-- ---------------------------------------------------------------------------
-- Idempotent completion report
-- ---------------------------------------------------------------------------
DO $h9_completion$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'knowledge' AND table_name = 'documentation_sentence'
                 AND column_name = 'author_status')
    THEN
        RAISE NOTICE 'H9 completion OK: §29 document lifecycle + §38 author_status + §41 document_version applied';
    END IF;
END
$h9_completion$;