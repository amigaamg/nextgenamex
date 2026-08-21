-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H9 migration 035
-- DOCUMENTATION LIFECYCLE, VERSIONING & HUMAN EDITING COMPLETION
-- =============================================================================
--
-- Purpose
-- -------
-- Completes the H9 documentation model introduced by migration 034.
--
-- Migration 034 established the DOCUMENT COMPILER:
--   H8 reasoning_run
--        ↓
--   documentation_instance
--        ↓
--   documentation_block
--        ↓
--   documentation_sentence
--        ↓
--   documentation_sentence_fact
--
-- Migration 035 establishes the DOCUMENT LIFECYCLE:
--   DRAFT → FINAL → AMENDED
--
-- and preserves the constitutional distinction between:
--
--   1. STRUCTURED CLINICAL FACTS
--      The machine-readable clinical source of truth.
--
--   2. COMPILED DOCUMENTATION
--      The controlled-language representation produced by H9.
--
--   3. HUMAN EDITING
--      A clinician may edit the rendered documentation without silently
--      changing the underlying structured fact.
--
-- Clinical safety principles
-- --------------------------
--   • A documentation edit is NOT a clinical fact mutation.
--   • fact_value in documentation_sentence_fact remains the structured
--     source used for provenance.
--   • A clinician-added sentence is explicitly marked as such.
--   • A clinician-deleted sentence remains auditable; it is not physically
--     erased merely because it was removed from the rendered document.
--   • FINAL is a documentation state, not a statement that every clinical
--     proposition is true.
--   • AMENDED means a new document version superseded an earlier finalized
--     representation.
--   • H9 does not diagnose. H8 owns diagnostic reasoning.
--   • The UI does not compile or infer clinical content.
--
-- Architecture
-- ------------
-- PostgreSQL = lifecycle/configuration/audit persistence
-- CPU        = compilation/version creation
-- UI         = rendering/editing workflow
--
-- Runtime rows are not seeded here. The CPU creates document instances,
-- sentences, amendment versions and validation events during execution.
--
-- =============================================================================


-- =============================================================================
-- A. DOCUMENT LIFECYCLE
-- =============================================================================
--
-- documentation_instance already represents one compiled H9 document.
-- These columns add the identity and lifecycle information required for
-- authorship, finalisation and amendment.
--
-- IMPORTANT:
-- compile status and document status are intentionally different.
--
--   status:
--       RUNNING / COMPILED / FAILED
--       = technical compiler execution state
--
--   document_status:
--       DRAFT / FINAL / AMENDED
--       = clinical-document lifecycle state
--
-- A document can therefore be technically COMPILED while still being DRAFT.
-- =============================================================================

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS patient_id
        uuid REFERENCES patient.patient(id);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS author_id
        uuid REFERENCES organization.professional(id);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS document_type
        text;

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS document_version
        integer NOT NULL DEFAULT 1;

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS document_status
        text NOT NULL DEFAULT 'DRAFT';

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS finalized_at
        timestamptz;

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS finalized_by_id
        uuid REFERENCES organization.professional(id);

ALTER TABLE knowledge.documentation_instance
    ADD COLUMN IF NOT EXISTS amended_from_id
        uuid REFERENCES knowledge.documentation_instance(instance_id);


-- -----------------------------------------------------------------------------
-- Document type
-- -----------------------------------------------------------------------------
--
-- Document type describes WHAT KIND OF CLINICAL DOCUMENT this is.
-- It must not be confused with the H9 template itself.
--
-- template_code = compilation/presentation template
-- document_type = clinical-document category
--
-- Keeping both allows, for example, different templates for an adult HPI
-- without creating a new clinical document type.
-- -----------------------------------------------------------------------------

DO $h9_doc_type_constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_instance'::regclass
          AND conname = 'ck_documentation_instance_document_type'
    ) THEN
        ALTER TABLE knowledge.documentation_instance
            ADD CONSTRAINT ck_documentation_instance_document_type
            CHECK (
                document_type IS NULL
                OR document_type IN (
                    'HPI',
                    'SOAP',
                    'CLERKING',
                    'ADMISSION',
                    'PROGRESS',
                    'WARD_ROUND',
                    'CONSULTATION',
                    'EMERGENCY',
                    'DISCHARGE',
                    'REFERRAL',
                    'TRANSFER',
                    'OPERATIVE',
                    'PROCEDURE',
                    'PRESCRIPTION',
                    'MAR',
                    'NURSING',
                    'PATIENT_INSTRUCTIONS',
                    'HANDOVER'
                )
            );
    END IF;
END
$h9_doc_type_constraint$;


-- -----------------------------------------------------------------------------
-- Document version constraint
-- -----------------------------------------------------------------------------

DO $h9_doc_version_constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_instance'::regclass
          AND conname = 'ck_documentation_instance_document_version'
    ) THEN
        ALTER TABLE knowledge.documentation_instance
            ADD CONSTRAINT ck_documentation_instance_document_version
            CHECK (document_version >= 1);
    END IF;
END
$h9_doc_version_constraint$;


-- -----------------------------------------------------------------------------
-- Document lifecycle constraint
-- -----------------------------------------------------------------------------

DO $h9_doc_status_constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_instance'::regclass
          AND conname = 'ck_documentation_instance_document_status'
    ) THEN
        ALTER TABLE knowledge.documentation_instance
            ADD CONSTRAINT ck_documentation_instance_document_status
            CHECK (
                document_status IN (
                    'DRAFT',
                    'FINAL',
                    'AMENDED'
                )
            );
    END IF;
END
$h9_doc_status_constraint$;


-- -----------------------------------------------------------------------------
-- Lifecycle integrity
-- -----------------------------------------------------------------------------
--
-- FINAL documents require finalisation metadata.
-- DRAFT documents must not pretend to have been finalised.
-- AMENDED documents require an amendment parent and finalisation metadata.
--
-- This is deliberately implemented as a CHECK rather than CPU-only logic:
-- the database must reject impossible lifecycle states even if an application
-- makes a mistake.
-- -----------------------------------------------------------------------------

DO $h9_lifecycle_integrity$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_instance'::regclass
          AND conname = 'ck_documentation_instance_lifecycle_integrity'
    ) THEN
        ALTER TABLE knowledge.documentation_instance
            ADD CONSTRAINT ck_documentation_instance_lifecycle_integrity
            CHECK (
                (
                    document_status = 'DRAFT'
                    AND finalized_at IS NULL
                    AND finalized_by_id IS NULL
                )
                OR
                (
                    document_status = 'FINAL'
                    AND finalized_at IS NOT NULL
                    AND finalized_by_id IS NOT NULL
                )
                OR
                (
                    document_status = 'AMENDED'
                    AND amended_from_id IS NOT NULL
                    AND finalized_at IS NOT NULL
                    AND finalized_by_id IS NOT NULL
                )
            );
    END IF;
END
$h9_lifecycle_integrity$;


-- -----------------------------------------------------------------------------
-- Version / amendment indexes
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_doc_inst_patient
    ON knowledge.documentation_instance(patient_id);

CREATE INDEX IF NOT EXISTS idx_doc_inst_author
    ON knowledge.documentation_instance(author_id);

CREATE INDEX IF NOT EXISTS idx_doc_inst_doc_type
    ON knowledge.documentation_instance(document_type);

CREATE INDEX IF NOT EXISTS idx_doc_inst_doc_status
    ON knowledge.documentation_instance(document_status);

CREATE INDEX IF NOT EXISTS idx_doc_inst_amended_from
    ON knowledge.documentation_instance(amended_from_id);

CREATE INDEX IF NOT EXISTS idx_doc_inst_finalized_by
    ON knowledge.documentation_instance(finalized_by_id);


COMMENT ON COLUMN knowledge.documentation_instance.patient_id
    IS 'Patient to whom the clinical document belongs. H9 §29.';

COMMENT ON COLUMN knowledge.documentation_instance.author_id
    IS 'Responsible clinician/professional for the document. H9 §29.';

COMMENT ON COLUMN knowledge.documentation_instance.document_type
    IS 'Clinical document category: HPI, SOAP, admission, progress, discharge, referral, handover, etc. H9 §25/§29.';

COMMENT ON COLUMN knowledge.documentation_instance.document_version
    IS 'Version number of the clinical document. Starts at 1 and increases for subsequent amended representations. H9 §41.';

COMMENT ON COLUMN knowledge.documentation_instance.document_status
    IS 'Clinical-document lifecycle state: DRAFT, FINAL or AMENDED. Separate from technical compiler status. H9 §29.';

COMMENT ON COLUMN knowledge.documentation_instance.finalized_at
    IS 'Time at which this document version was finalised. NULL while DRAFT. H9 §29/§41.';

COMMENT ON COLUMN knowledge.documentation_instance.finalized_by_id
    IS 'Professional who finalised this document version. H9 §41.';

COMMENT ON COLUMN knowledge.documentation_instance.amended_from_id
    IS 'Immediate predecessor documentation_instance superseded by this amended version. Preserves the amendment chain. H9 §41.';


-- =============================================================================
-- B. HUMAN EDITING OF RENDERED SENTENCES
-- =============================================================================
--
-- A documentation_sentence is the rendered clinical-language layer.
--
-- Human editing changes that layer.
--
-- It MUST NOT silently mutate:
--
--     clinical.fact_definition
--     captured clinical facts
--     H8 evidence
--     H8 differential scores
--     H8 hypotheses
--
-- Therefore author_status belongs on the sentence, not on the fact layer.
-- =============================================================================

ALTER TABLE knowledge.documentation_sentence
    ADD COLUMN IF NOT EXISTS author_status
        text NOT NULL DEFAULT 'SYSTEM_GENERATED';

ALTER TABLE knowledge.documentation_sentence
    ADD COLUMN IF NOT EXISTS amended_from_id
        uuid REFERENCES knowledge.documentation_sentence(id);


DO $h9_author_status_constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_sentence'::regclass
          AND conname = 'ck_documentation_sentence_author_status'
    ) THEN
        ALTER TABLE knowledge.documentation_sentence
            ADD CONSTRAINT ck_documentation_sentence_author_status
            CHECK (
                author_status IN (
                    'SYSTEM_GENERATED',
                    'CLINICIAN_EDITED',
                    'CLINICIAN_ADDED',
                    'CLINICIAN_DELETED',
                    'SYSTEM_VALIDATED'
                )
            );
    END IF;
END
$h9_author_status_constraint$;


CREATE INDEX IF NOT EXISTS idx_doc_sentence_author_status
    ON knowledge.documentation_sentence(author_status);

CREATE INDEX IF NOT EXISTS idx_doc_sentence_amended_from
    ON knowledge.documentation_sentence(amended_from_id);


COMMENT ON COLUMN knowledge.documentation_sentence.author_status
    IS 'Provenance of the rendered sentence: SYSTEM_GENERATED, CLINICIAN_EDITED, CLINICIAN_ADDED, CLINICIAN_DELETED or SYSTEM_VALIDATED. Human editing changes documentation, not the underlying structured fact. H9 §38/§39.';

COMMENT ON COLUMN knowledge.documentation_sentence.amended_from_id
    IS 'Previous rendered sentence version from which this sentence was amended. Preserves sentence-level auditability. H9 §38/§41.';


-- =============================================================================
-- C. EXPLICIT HUMAN-EDIT SAFETY CONTRACT
-- =============================================================================
--
-- This table is deliberately small.
--
-- It records the constitutional rule in the database itself:
--
--   HUMAN EDIT ≠ FACT MUTATION
--
-- The actual structured fact remains in documentation_sentence_fact.
--
-- A later H9 service can use this as an auditable policy registry and can
-- validate editing operations against it.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.documentation_edit_policy (
    policy_code       text PRIMARY KEY,
    label             text NOT NULL,
    description       text NOT NULL,
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.documentation_edit_policy
    IS 'H9 documentation editing policy registry. Human editing changes the rendered documentation layer and must not silently mutate structured clinical facts.';


INSERT INTO knowledge.documentation_edit_policy (
    policy_code,
    label,
    description,
    is_active
)
VALUES
(
    'HUMAN_EDIT_NOT_FACT_MUTATION',
    'Human edit does not mutate structured fact',
    'Editing a documentation sentence changes the rendered documentation representation only. The structured clinical fact and its provenance remain unchanged unless a separate authorised clinical-data workflow explicitly records a fact correction.',
    true
),
(
    'CLINICIAN_DELETION_IS_AUDITABLE',
    'Clinical sentence deletion is auditable',
    'A clinician-deleted sentence must remain represented in the audit/version chain and must not be silently destroyed from clinical-document history.',
    true
),
(
    'SYSTEM_MUST_NOT_UPGRADE_CERTAINTY',
    'System must not upgrade certainty',
    'H9 documentation generation and editing must not silently convert a POSSIBLE, PROBABLE or UNCERTAIN clinical state into a stronger certainty without an authorised clinical reasoning/data change.',
    true
)
ON CONFLICT (policy_code)
DO UPDATE SET
    label = EXCLUDED.label,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active,
    updated_at = now();


-- =============================================================================
-- D. DOCUMENT VERSION INTEGRITY
-- =============================================================================
--
-- PostgreSQL cannot express "amended_from_id must belong to the same logical
-- document" with a simple CHECK because that requires a cross-row lookup.
--
-- Therefore the database uses a trigger for the invariant:
--
--   1. An AMENDED document must point to an existing predecessor.
--   2. Its version must be predecessor.version + 1.
--   3. It cannot amend itself.
--   4. The predecessor must belong to the same patient.
--   5. The predecessor must have the same document_type.
--
-- This prevents accidental version-chain corruption.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_documentation_amendment()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    parent_row knowledge.documentation_instance%ROWTYPE;
BEGIN
    IF NEW.amended_from_id IS NULL THEN
        IF NEW.document_status = 'AMENDED' THEN
            RAISE EXCEPTION
                'H9 document % is AMENDED but amended_from_id is NULL',
                NEW.instance_id;
        END IF;

        RETURN NEW;
    END IF;

    IF NEW.amended_from_id = NEW.instance_id THEN
        RAISE EXCEPTION
            'H9 document % cannot amend itself',
            NEW.instance_id;
    END IF;

    SELECT *
    INTO parent_row
    FROM knowledge.documentation_instance
    WHERE instance_id = NEW.amended_from_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'H9 amendment parent % does not exist',
            NEW.amended_from_id;
    END IF;

    IF NEW.document_version <> parent_row.document_version + 1 THEN
        RAISE EXCEPTION
            'H9 invalid document version: version % must follow parent version %',
            NEW.document_version,
            parent_row.document_version;
    END IF;

    IF NEW.patient_id IS DISTINCT FROM parent_row.patient_id THEN
        RAISE EXCEPTION
            'H9 amendment patient mismatch: document % and parent % belong to different patients',
            NEW.instance_id,
            NEW.amended_from_id;
    END IF;

    IF NEW.document_type IS DISTINCT FROM parent_row.document_type THEN
        RAISE EXCEPTION
            'H9 amendment document-type mismatch: % cannot amend %',
            NEW.document_type,
            parent_row.document_type;
    END IF;

    IF NEW.document_status = 'AMENDED'
       AND parent_row.document_status NOT IN ('FINAL', 'AMENDED')
    THEN
        RAISE EXCEPTION
            'H9 amended document % must amend a FINAL or previously AMENDED document',
            NEW.instance_id;
    END IF;

    RETURN NEW;
END;
$function$;


DROP TRIGGER IF EXISTS trg_validate_documentation_amendment
    ON knowledge.documentation_instance;

CREATE TRIGGER trg_validate_documentation_amendment
    BEFORE INSERT OR UPDATE
    ON knowledge.documentation_instance
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.validate_documentation_amendment();


-- =============================================================================
-- E. SENTENCE VERSION INTEGRITY
-- =============================================================================
--
-- A sentence amendment is a rendered-document change.
--
-- It must:
--   • point to a real predecessor;
--   • never point to itself;
--   • remain in the same document instance;
--   • remain in the same section.
--
-- A clinician may add a completely new sentence; in that case
-- amended_from_id remains NULL and author_status = CLINICIAN_ADDED.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_documentation_sentence_amendment()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    parent_row knowledge.documentation_sentence%ROWTYPE;
BEGIN
    IF NEW.amended_from_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.amended_from_id = NEW.id THEN
        RAISE EXCEPTION
            'H9 sentence % cannot amend itself',
            NEW.id;
    END IF;

    SELECT *
    INTO parent_row
    FROM knowledge.documentation_sentence
    WHERE id = NEW.amended_from_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'H9 sentence amendment parent % does not exist',
            NEW.amended_from_id;
    END IF;

    IF NEW.instance_id <> parent_row.instance_id THEN
        RAISE EXCEPTION
            'H9 sentence amendment must remain within the same documentation instance';
    END IF;

    IF NEW.section_code <> parent_row.section_code THEN
        RAISE EXCEPTION
            'H9 sentence amendment cannot silently move between sections';
    END IF;

    RETURN NEW;
END;
$function$;


DROP TRIGGER IF EXISTS trg_validate_documentation_sentence_amendment
    ON knowledge.documentation_sentence;

CREATE TRIGGER trg_validate_documentation_sentence_amendment
    BEFORE INSERT OR UPDATE
    ON knowledge.documentation_sentence
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.validate_documentation_sentence_amendment();


-- =============================================================================
-- F. HUMAN EDITING STATUS INTEGRITY
-- =============================================================================
--
-- The author_status is not merely decorative.
--
--   SYSTEM_GENERATED
--       H9 CPU generated the sentence.
--
--   SYSTEM_VALIDATED
--       H9 validation accepted the sentence without changing its clinical
--       meaning. It is still system-produced content.
--
--   CLINICIAN_EDITED
--       A previously generated sentence was altered by a clinician.
--
--   CLINICIAN_ADDED
--       A clinician added a new rendered sentence that was not generated by
--       the compiler.
--
--   CLINICIAN_DELETED
--       A prior rendered sentence has been explicitly marked deleted.
--
-- The trigger prevents contradictory combinations such as a new sentence
-- being marked CLINICIAN_ADDED while simultaneously claiming that it amends
-- a previous sentence.
-- =============================================================================

DO $h9_sentence_status_constraints$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_sentence'::regclass
          AND conname = 'ck_documentation_sentence_edit_status'
    ) THEN
        ALTER TABLE knowledge.documentation_sentence
            ADD CONSTRAINT ck_documentation_sentence_edit_status
            CHECK (
                (
                    author_status = 'CLINICIAN_ADDED'
                    AND amended_from_id IS NULL
                )
                OR
                (
                    author_status = 'CLINICIAN_EDITED'
                    AND amended_from_id IS NOT NULL
                )
                OR
                (
                    author_status IN (
                        'SYSTEM_GENERATED',
                        'SYSTEM_VALIDATED',
                        'CLINICIAN_DELETED'
                    )
                )
            );
    END IF;
END
$h9_sentence_status_constraints$;


-- =============================================================================
-- G. DOCUMENT LIFECYCLE STATE TRANSITION GUARD
-- =============================================================================
--
-- Allowed lifecycle:
--
--   DRAFT → FINAL
--   FINAL → AMENDED
--   AMENDED → AMENDED
--
-- No silent reopening:
--
--   FINAL → DRAFT                 prohibited
--   AMENDED → DRAFT               prohibited
--
-- If a finalised document needs correction, create an amendment version.
--
-- This preserves the legal/clinical distinction between editing history and
-- overwriting history.
-- =============================================================================

CREATE OR REPLACE FUNCTION knowledge.validate_documentation_lifecycle_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.document_status IS DISTINCT FROM OLD.document_status
    THEN
        IF OLD.document_status = 'FINAL'
           AND NEW.document_status = 'DRAFT'
        THEN
            RAISE EXCEPTION
                'H9 lifecycle violation: FINAL documents cannot be silently reopened as DRAFT; create an AMENDED version';
        END IF;

        IF OLD.document_status = 'AMENDED'
           AND NEW.document_status = 'DRAFT'
        THEN
            RAISE EXCEPTION
                'H9 lifecycle violation: AMENDED documents cannot be silently reopened as DRAFT';
        END IF;

        IF OLD.document_status = 'DRAFT'
           AND NEW.document_status = 'AMENDED'
        THEN
            RAISE EXCEPTION
                'H9 lifecycle violation: DRAFT cannot become AMENDED without first being FINAL';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;


DROP TRIGGER IF EXISTS trg_validate_documentation_lifecycle_transition
    ON knowledge.documentation_instance;

CREATE TRIGGER trg_validate_documentation_lifecycle_transition
    BEFORE UPDATE
    ON knowledge.documentation_instance
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.validate_documentation_lifecycle_transition();


-- =============================================================================
-- H. FINALISATION SAFETY
-- =============================================================================
--
-- A document cannot be FINAL merely because an application changed a status.
--
-- At minimum:
--   • it must have a patient;
--   • it must have an author;
--   • it must be technically COMPILED;
--   • it must have finalisation metadata.
--
-- Clinical validation itself remains represented by H9
-- documentation_validation. This trigger does not pretend that database
-- completeness equals clinical correctness.
-- =============================================================================

DO $h9_finalisation_guard$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'knowledge.documentation_instance'::regclass
          AND conname = 'ck_documentation_instance_finalization_metadata'
    ) THEN
        ALTER TABLE knowledge.documentation_instance
            ADD CONSTRAINT ck_documentation_instance_finalization_metadata
            CHECK (
                document_status = 'DRAFT'
                OR (
                    patient_id IS NOT NULL
                    AND author_id IS NOT NULL
                    AND status = 'COMPILED'
                    AND finalized_at IS NOT NULL
                    AND finalized_by_id IS NOT NULL
                )
            );
    END IF;
END
$h9_finalisation_guard$;


-- =============================================================================
-- I. DOCUMENTATION EDIT AUDIT
-- =============================================================================
--
-- The sentence table records the resulting rendered sentence.
--
-- This audit table records the EDIT OPERATION itself.
--
-- That distinction is useful because:
--
--   sentence.content
--       = current rendered wording
--
--   documentation_edit_event
--       = who changed it, when, and what operation occurred
--
-- No structured fact is changed by this table.
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge.documentation_edit_event (
    edit_event_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id         uuid NOT NULL
        REFERENCES knowledge.documentation_instance(instance_id)
        ON DELETE CASCADE,
    sentence_id         uuid
        REFERENCES knowledge.documentation_sentence(id)
        ON DELETE SET NULL,
    editor_id            uuid
        REFERENCES organization.professional(id),
    edit_type            text NOT NULL CHECK (
        edit_type IN (
            'EDIT_SENTENCE',
            'ADD_SENTENCE',
            'DELETE_SENTENCE',
            'RESTORE_SENTENCE',
            'FINALIZE_DOCUMENT',
            'AMEND_DOCUMENT'
        )
    ),
    previous_sentence_id uuid
        REFERENCES knowledge.documentation_sentence(id)
        ON DELETE SET NULL,
    reason               text,
    created_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.documentation_edit_event
    IS 'Auditable human/document lifecycle edit events. Editing documentation does not mutate structured clinical facts. H9 §38/§39/§41.';

CREATE INDEX IF NOT EXISTS idx_doc_edit_event_instance
    ON knowledge.documentation_edit_event(instance_id);

CREATE INDEX IF NOT EXISTS idx_doc_edit_event_sentence
    ON knowledge.documentation_edit_event(sentence_id);

CREATE INDEX IF NOT EXISTS idx_doc_edit_event_editor
    ON knowledge.documentation_edit_event(editor_id);

CREATE INDEX IF NOT EXISTS idx_doc_edit_event_type
    ON knowledge.documentation_edit_event(edit_type);


-- =============================================================================
-- J. PROVENANCE COMMENTS
-- =============================================================================

COMMENT ON TABLE knowledge.documentation_sentence
    IS 'Rendered clinical-language sentence. It is a documentation representation, not the structured clinical fact itself. Human edits are explicitly attributed and remain separate from documentation_sentence_fact. H9 §15/§32/§38/§39.';

COMMENT ON TABLE knowledge.documentation_sentence_fact
    IS 'Structured provenance bridge from rendered sentence to source fact. fact_value remains the structured source of truth for the sentence and is not silently overwritten by human wording edits. H9 §32/§39/§40.';

COMMENT ON TABLE knowledge.documentation_edit_event
    IS 'Human and lifecycle edit audit trail. Records who changed the rendered document, what operation occurred and when. Does not mutate the clinical fact layer.';


-- =============================================================================
-- K. IDEMPOTENT COMPLETION REPORT
-- =============================================================================

DO $h9_completion$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'knowledge'
          AND table_name = 'documentation_instance'
          AND column_name = 'document_version'
    )
    AND EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'knowledge'
          AND table_name = 'documentation_instance'
          AND column_name = 'document_status'
    )
    AND EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'knowledge'
          AND table_name = 'documentation_sentence'
          AND column_name = 'author_status'
    )
    AND EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'knowledge'
          AND table_name = 'documentation_edit_event'
    )
    THEN
        RAISE NOTICE
            'AMEXAN H9 migration 035 COMPLETE: document lifecycle, versioning, human-edit provenance, amendment integrity and edit audit are installed.';
    ELSE
        RAISE EXCEPTION
            'AMEXAN H9 migration 035 verification FAILED';
    END IF;
END
$h9_completion$;


-- =============================================================================
-- END MIGRATION 035
-- =============================================================================
--
-- Resulting constitutional flow:
--
--   STRUCTURED FACT
--          ↓
--      H8 REASONING
--          ↓
--      H9 COMPILER
--          ↓
--   SYSTEM-GENERATED DOCUMENT
--          ↓
--       CLINICIAN EDIT
--          ↓
--   VERSIONED DOCUMENT AMENDMENT
--
-- The clinician's wording change does NOT silently become a new fact.
--
-- If the underlying clinical fact is wrong, that requires a separate,
-- authorised clinical-data correction workflow.
--
-- H9 documents what the clinical system knows and what the responsible
-- clinician has documented; H8 remains responsible for diagnostic reasoning.
-- =============================================================================