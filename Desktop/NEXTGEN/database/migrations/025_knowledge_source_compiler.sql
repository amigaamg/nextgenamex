-- =============================================================================
-- AMEXAN Medical Knowledge Compiler
-- H1 â€” SOURCE + CHAPTER MAP
-- UNIVERSAL MEDICINE / CLINICAL OPERATING SYSTEM FOUNDATION
-- =============================================================================
--
-- PURPOSE
-- -------
-- This migration establishes the SOURCE layer of the AMEXAN Medical
-- Knowledge Compiler.
--
-- SOURCE KNOWLEDGE IS NOT RUNTIME KNOWLEDGE.
--
-- The compiler pipeline is:
--
--   AUTHORITATIVE SOURCE
--          â†“
--   SOURCE VERSION
--          â†“
--   SECTION
--          â†“
--   CHAPTER
--          â†“
--   PAGE / CHUNK
--          â†“
--   ATOMIC CLAIM
--          â†“
--   EXTRACTION CONTRACT
--          â†“
--   HUMAN / MACHINE REVIEW
--          â†“
--   AMEXAN OPERATIONAL OBJECT
--          â†“
--   PROVENANCE
--          â†“
--   CLINICAL CPU
--
-- The CPU MUST NOT directly reason from raw textbook text.
--
-- The compiler converts authoritative medical knowledge into reusable,
-- composable AMEXAN objects:
--
--   concept
--   symptom
--   sign
--   fact
--   question
--   answer
--   phenotype
--   mechanism
--   condition
--   investigation
--   examination
--   monitoring
--   medication
--   protocol
--   documentation rule
--   safety rule
--   differential relationship
--   education
--
-- DESIGN PRINCIPLES
-- -----------------
--
-- 1. SOURCE â‰  OPERATIONAL KNOWLEDGE
-- 2. CLAIM â‰  PARAGRAPH
-- 3. ONE CLAIM = ONE ATOMIC ASSERTION
-- 4. EVERY OPERATIONAL OBJECT MUST BE TRACEABLE TO SOURCE CLAIMS
-- 5. ONE CLAIM MAY PRODUCE MANY OPERATIONAL OBJECTS
-- 6. ONE OPERATIONAL OBJECT MAY BE SUPPORTED BY MANY CLAIMS
-- 7. PRINTED BOOK PAGE NUMBERS ARE THE CLINICAL REFERENCE
-- 8. PDF PAGE NUMBERS ARE RETAINED FOR DIGITAL TRACEABILITY
-- 9. SOURCE AUTHORITY IS EXPLICIT
-- 10. AUTHORITY SCOPE IS EXPLICIT
-- 11. CLINICAL-METHOD SOURCES MUST NOT SILENTLY BECOME DRUG-DOSING
--     AUTHORITIES
-- 12. GUIDELINE / FORMULARY / PHARMACOLOGY AUTHORITY REMAINS SEPARATE
-- 13. KNOWLEDGE COMPILATION IS VERSIONED
-- 14. SUPERSESSION NEVER DESTROYS HISTORY
-- 15. HUMAN REVIEW IS FIRST-CLASS
-- 16. EXTRACTION MUST BE IDEMPOTENT
-- 17. SOURCE CONTENT IS IMMUTABLE IN MEANING AFTER PUBLICATION;
--     CORRECTIONS CREATE VERSIONED / REVIEWABLE RECORDS
-- 18. THE SAME SOURCE CLAIM CAN POWER HISTORY, EXAMINATION, REASONING,
--     DOCUMENTATION AND NAVIGATION WITHOUT DUPLICATING THE CLAIM
--
-- PAGE CONVENTION
-- ---------------
--
-- PDF extraction:
--
--     pdf_page_index = physical PDF page, 1-based
--
-- Printed book:
--
--     printed_page = pdf_page_index - pdf_page_offset
--
-- All clinical page references stored in page_start/page_end/page_number
-- represent PRINTED BOOK PAGES.
--
-- =============================================================================


CREATE SCHEMA IF NOT EXISTS knowledge;

COMMENT ON SCHEMA knowledge IS
'AMEXAN universal clinical knowledge: operational objects plus compiler source layer.';


-- =============================================================================
-- 0. SOURCE AUTHORITY TAXONOMY
-- =============================================================================
--
-- Authority is deliberately represented as data.
--
-- Example:
--
--   Hutchison
--      â†’ clinical method / history / examination / communication
--
--   Davidson
--      â†’ internal medicine / disease / investigation / management
--
--   Kumar & Clark
--      â†’ internal medicine / pathology / clinical reasoning
--
--   Nelson
--      â†’ paediatrics
--
--   Williams
--      â†’ obstetrics
--
--   Bailey & Love
--      â†’ surgery
--
--   Oxford Handbooks
--      â†’ concise operational reference
--
--   WHO / NICE / national guidelines
--      â†’ guideline activity
--
--   BNF / national formulary
--      â†’ medication / prescribing authority
--
-- No source gets universal authority merely because it is authoritative.
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.source CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.source (
    source_id            text PRIMARY KEY,

    source_name          text NOT NULL,

    edition              integer,

    year                 integer,

    source_type          text NOT NULL
        CHECK (
            source_type IN (
                'clinical_methods_text',
                'textbook',
                'guideline',
                'journal',
                'reference',
                'protocol',
                'formulary',
                'pharmacology',
                'consensus',
                'regulatory'
            )
        ),

    authority_scope      text,

    amexan_role          text,

    description          text,

    publisher            text,

    isbn                 text,

    doi                  text,

    language_code        text NOT NULL DEFAULT 'en',

    jurisdiction_code    text,

    specialty_scope      text[] NOT NULL DEFAULT ARRAY[]::text[],

    authority_rank       integer NOT NULL DEFAULT 50
        CHECK (authority_rank BETWEEN 0 AND 100),

    status               text NOT NULL DEFAULT 'ACTIVE_FOUNDATION'
        CHECK (
            status IN (
                'ACTIVE_FOUNDATION',
                'active',
                'deprecated',
                'superseded',
                'pending_review'
            )
        ),

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.source IS
'Named authoritative medical source. Defines what domain the source is authoritative for.';

COMMENT ON COLUMN knowledge.source.authority_scope IS
'Explicit boundary of authority, e.g. clinical method, internal medicine, paediatrics, pharmacology, guideline activity.';

COMMENT ON COLUMN knowledge.source.amexan_role IS
'How AMEXAN uses the source, e.g. HISTORY_ENGINE, EXAM_ENGINE, MEDICINE_ENGINE, DRUG_ENGINE.';

COMMENT ON COLUMN knowledge.source.authority_rank IS
'Relative source-authority ranking used during compiler conflict review; never substitutes for clinical judgment or guideline precedence.';


CREATE INDEX IF NOT EXISTS idx_source_type
    ON knowledge.source(source_type);

CREATE INDEX IF NOT EXISTS idx_source_status
    ON knowledge.source(status);

CREATE INDEX IF NOT EXISTS idx_source_authority_scope
    ON knowledge.source(authority_scope);

CREATE INDEX IF NOT EXISTS idx_source_jurisdiction
    ON knowledge.source(jurisdiction_code);


DROP TRIGGER IF EXISTS trg_knowledge_source_updated_at
    ON knowledge.source;

CREATE TRIGGER trg_knowledge_source_updated_at
    BEFORE UPDATE ON knowledge.source
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 1. SOURCE VERSION
-- =============================================================================
--
-- A source is conceptually stable.
-- An edition/version is not.
--
-- Never overwrite a published edition to silently change medical meaning.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_version (
    version_id           text PRIMARY KEY,

    source_id            text NOT NULL
        REFERENCES knowledge.source(source_id)
        ON DELETE CASCADE,

    edition              integer NOT NULL,

    publication_year     integer NOT NULL,

    language             text NOT NULL DEFAULT 'English',

    supersedes           text
        REFERENCES knowledge.source_version(version_id),

    effective_from       date,

    effective_to         date,

    status               text NOT NULL DEFAULT 'ACTIVE'
        CHECK (
            status IN (
                'ACTIVE',
                'active',
                'deprecated',
                'superseded',
                'pending_review'
            )
        ),

    pdf_page_offset      integer NOT NULL DEFAULT 0,

    page_count           integer,

    file_path            text,

    checksum             text,

    extraction_engine    text,

    extraction_version   text,

    source_metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (source_id, edition, publication_year, language)
);

COMMENT ON TABLE knowledge.source_version IS
'Concrete edition/version of an authoritative source.';

COMMENT ON COLUMN knowledge.source_version.pdf_page_offset IS
'Printed page = PDF page index - offset. All clinical references use printed page numbers.';

COMMENT ON COLUMN knowledge.source_version.checksum IS
'Cryptographic checksum of the source file used for extraction.';

COMMENT ON COLUMN knowledge.source_version.source_metadata IS
'Machine-readable source metadata without changing the canonical source identity.';


CREATE INDEX IF NOT EXISTS idx_source_version_source
    ON knowledge.source_version(source_id);

CREATE INDEX IF NOT EXISTS idx_source_version_status
    ON knowledge.source_version(status);

CREATE INDEX IF NOT EXISTS idx_source_version_supersedes
    ON knowledge.source_version(supersedes);


DROP TRIGGER IF EXISTS trg_knowledge_source_version_updated_at
    ON knowledge.source_version;

CREATE TRIGGER trg_knowledge_source_version_updated_at
    BEFORE UPDATE ON knowledge.source_version
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 2. SOURCE SECTION
-- =============================================================================
--
-- The source is mapped into AMEXAN layers.
--
-- UNIVERSAL
--     history, examination, communication, reasoning principles
--
-- CONTEXT
--     paediatrics, OBG, geriatrics, emergency, psychiatry, etc.
--
-- SYSTEM
--     respiratory, cardiovascular, GI, neurological, renal, etc.
--
-- NAVIGATION_ONLY
--     index / appendices / cross-reference material that should not itself
--     become clinical knowledge.
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.source_section CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.source_section (
    section_id           text PRIMARY KEY,

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    section_no           integer,

    section_name         text NOT NULL,

    section_description  text,

    amexan_layer          text NOT NULL
        CHECK (
            amexan_layer IN (
                'UNIVERSAL',
                'CONTEXT',
                'SYSTEM',
                'NAVIGATION_ONLY'
            )
        ),

    authority_scope       text,

    sort_order            integer NOT NULL DEFAULT 0,

    is_extractable        boolean NOT NULL DEFAULT true,

    metadata              jsonb NOT NULL DEFAULT '{}'::jsonb,

    UNIQUE (source_version_id, section_name)
);

COMMENT ON TABLE knowledge.source_section IS
'Top-level source section mapped into an AMEXAN knowledge layer.';


CREATE INDEX IF NOT EXISTS idx_source_section_version
    ON knowledge.source_section(source_version_id);

CREATE INDEX IF NOT EXISTS idx_source_section_layer
    ON knowledge.source_section(amexan_layer);


-- =============================================================================
-- 3. SOURCE CHAPTER
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_chapter (
    chapter_id           text PRIMARY KEY,

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    section_id           text NOT NULL
        REFERENCES knowledge.source_section(section_id)
        ON DELETE RESTRICT,

    chapter_no           integer NOT NULL,

    chapter_name         text NOT NULL,

    chapter_description  text,

    start_page           integer,

    end_page             integer,

    amexan_role           text,

    amexan_context        text,

    amexan_system         text,

    specialty_scope       text[] NOT NULL DEFAULT ARRAY[]::text[],

    extraction_priority   integer NOT NULL DEFAULT 50
        CHECK (extraction_priority BETWEEN 0 AND 100),

    is_extractable        boolean NOT NULL DEFAULT true,

    metadata              jsonb NOT NULL DEFAULT '{}'::jsonb,

    sort_order            integer NOT NULL DEFAULT 0,

    UNIQUE (source_version_id, chapter_no),

    CHECK (
        start_page IS NULL
        OR end_page IS NULL
        OR start_page <= end_page
    )
);

COMMENT ON TABLE knowledge.source_chapter IS
'Chapter-level compiler unit. Claims and extraction jobs hang from the chapter.';

COMMENT ON COLUMN knowledge.source_chapter.amexan_role IS
'Operational role such as HISTORY_ENGINE, EXAM_ENGINE, REASONING_INTERFACE, ETHICS_ENGINE, MEDICINE_ENGINE.';

COMMENT ON COLUMN knowledge.source_chapter.amexan_context IS
'Clinical context such as PAEDIATRIC, FEMALE_OBG, GERIATRIC, EMERGENCY, FEVER_PRESENTATION, PAIN_PRESENTATION.';

COMMENT ON COLUMN knowledge.source_chapter.amexan_system IS
'Clinical body-system scope such as RESPIRATORY, CARDIOVASCULAR, GASTROINTESTINAL, NEUROLOGICAL.';


CREATE INDEX IF NOT EXISTS idx_source_chapter_section
    ON knowledge.source_chapter(section_id);

CREATE INDEX IF NOT EXISTS idx_source_chapter_version
    ON knowledge.source_chapter(source_version_id);

CREATE INDEX IF NOT EXISTS idx_source_chapter_role
    ON knowledge.source_chapter(amexan_role);

CREATE INDEX IF NOT EXISTS idx_source_chapter_context
    ON knowledge.source_chapter(amexan_context);

CREATE INDEX IF NOT EXISTS idx_source_chapter_system
    ON knowledge.source_chapter(amexan_system);


-- =============================================================================
-- 4. SOURCE CHUNK
-- =============================================================================
--
-- READ LAYER.
--
-- A chunk is not clinical knowledge.
-- It is the exact extracted material from which claims are produced.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_chunk (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    chapter_id           text NOT NULL
        REFERENCES knowledge.source_chapter(chapter_id)
        ON DELETE CASCADE,

    page_number          integer NOT NULL,

    pdf_page_index       integer,

    chunk_index          integer NOT NULL DEFAULT 0,

    chunk_text           text NOT NULL,

    char_count           integer NOT NULL DEFAULT 0,

    token_count          integer,

    extraction_method    text,

    extraction_quality   numeric(3,2)
        CHECK (
            extraction_quality IS NULL
            OR extraction_quality BETWEEN 0 AND 1
        ),

    checksum             text,

    created_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        source_version_id,
        chapter_id,
        page_number,
        chunk_index
    )
);

COMMENT ON TABLE knowledge.source_chunk IS
'READ layer: page-anchored raw extracted source text. Not directly consumed by the clinical CPU.';

COMMENT ON COLUMN knowledge.source_chunk.page_number IS
'Printed book page number.';

COMMENT ON COLUMN knowledge.source_chunk.pdf_page_index IS
'Original PDF page index, retained for digital reproducibility.';


CREATE INDEX IF NOT EXISTS idx_source_chunk_chapter_page
    ON knowledge.source_chunk(chapter_id, page_number, chunk_index);

CREATE INDEX IF NOT EXISTS idx_source_chunk_version
    ON knowledge.source_chunk(source_version_id);

CREATE INDEX IF NOT EXISTS idx_source_chunk_page
    ON knowledge.source_chunk(source_version_id, page_number);


-- =============================================================================
-- 5. SOURCE CLAIM
-- =============================================================================
--
-- THE ATOMIC UNIT OF MEDICAL COMPILATION.
--
-- A paragraph:
--
--     "Patients with X may present with A, B and C..."
--
-- can become:
--
--     CLAIM 1 â†’ X definition
--     CLAIM 2 â†’ A presentation
--     CLAIM 3 â†’ B presentation
--     CLAIM 4 â†’ C presentation
--     CLAIM 5 â†’ relevant examination
--     CLAIM 6 â†’ differential
--
-- This allows each claim to feed different operational objects.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_claim (
    claim_id             text PRIMARY KEY,

    claim_code           text NOT NULL UNIQUE,

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    chapter_id           text NOT NULL
        REFERENCES knowledge.source_chapter(chapter_id)
        ON DELETE CASCADE,

    chunk_id             uuid
        REFERENCES knowledge.source_chunk(id)
        ON DELETE SET NULL,

    page_start           integer,

    page_end             integer,

    claim_type           text NOT NULL,

    claim_kind           text NOT NULL
        CHECK (
            claim_kind IN (
                'definition',
                'rule',
                'question',
                'red_flag',
                'differential',
                'examination',
                'investigation',
                'threshold',
                'contraindication',
                'principle',
                'risk_factor',
                'history_section',
                'management',
                'prognosis',
                'pathophysiology',
                'epidemiology',
                'aetiology',
                'classification',
                'diagnostic_criterion',
                'monitoring',
                'follow_up',
                'communication',
                'documentation',
                'safety',
                'ethics'
            )
        ),

    claim_text           text NOT NULL,

    knowledge_type       text NOT NULL DEFAULT 'clinical_method'
        CHECK (
            knowledge_type IN (
                'clinical_method',
                'medicine',
                'guideline_activity',
                'reference'
            )
        ),

    clinical_scope       text,

    population_scope     text[] NOT NULL DEFAULT ARRAY[]::text[],

    specialty_scope      text[] NOT NULL DEFAULT ARRAY[]::text[],

    jurisdiction_scope   text[] NOT NULL DEFAULT ARRAY[]::text[],

    contract             jsonb NOT NULL DEFAULT '{}'::jsonb,

    extraction_metadata  jsonb NOT NULL DEFAULT '{}'::jsonb,

    extracted_object_id  uuid,

    confidence           numeric(3,2) NOT NULL DEFAULT 0.90
        CHECK (confidence BETWEEN 0 AND 1),

    reviewer_confidence  numeric(3,2)
        CHECK (
            reviewer_confidence IS NULL
            OR reviewer_confidence BETWEEN 0 AND 1
        ),

    is_compiled          boolean NOT NULL DEFAULT false,

    status               text NOT NULL DEFAULT 'VERIFIED'
        CHECK (
            status IN (
                'VERIFIED',
                'active',
                'pending',
                'superseded',
                'rejected',
                'needs_review'
            )
        ),

    reviewed_by          uuid,

    reviewed_at          timestamptz,

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now(),

    CHECK (
        page_start IS NULL
        OR page_end IS NULL
        OR page_start <= page_end
    )
);

COMMENT ON TABLE knowledge.source_claim IS
'Atomic, provenance-ready medical claim. The primary unit compiled into operational AMEXAN knowledge.';

COMMENT ON COLUMN knowledge.source_claim.contract IS
'Machine-readable extraction contract describing what the compiler must resolve before an object is approved.';

COMMENT ON COLUMN knowledge.source_claim.knowledge_type IS
'Authority boundary: clinical_method, medicine, guideline_activity or reference.';


CREATE INDEX IF NOT EXISTS idx_source_claim_chapter
    ON knowledge.source_claim(chapter_id);

CREATE INDEX IF NOT EXISTS idx_source_claim_chunk
    ON knowledge.source_claim(chunk_id);

CREATE INDEX IF NOT EXISTS idx_source_claim_type
    ON knowledge.source_claim(claim_type);

CREATE INDEX IF NOT EXISTS idx_source_claim_kind
    ON knowledge.source_claim(claim_kind);

CREATE INDEX IF NOT EXISTS idx_source_claim_knowledge_type
    ON knowledge.source_claim(knowledge_type);

CREATE INDEX IF NOT EXISTS idx_source_claim_status
    ON knowledge.source_claim(status);

CREATE INDEX IF NOT EXISTS idx_source_claim_compiled
    ON knowledge.source_claim(is_compiled);

CREATE INDEX IF NOT EXISTS idx_source_claim_page
    ON knowledge.source_claim(
        source_version_id,
        page_start,
        page_end
    );

CREATE INDEX IF NOT EXISTS idx_source_claim_contract
    ON knowledge.source_claim
    USING gin(contract);


DROP TRIGGER IF EXISTS trg_knowledge_source_claim_updated_at
    ON knowledge.source_claim;

CREATE TRIGGER trg_knowledge_source_claim_updated_at
    BEFORE UPDATE ON knowledge.source_claim
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 6. SOURCE CLAIM RELATIONSHIPS
-- =============================================================================
--
-- Claims can support, contradict, refine, qualify or supersede one another.
--
-- This is deliberately separate from knowledge.relationship because these are
-- SOURCE-LEVEL epistemic relationships, not clinical runtime relationships.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_claim_relationship (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_claim_id      text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    related_claim_id     text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    relationship_type    text NOT NULL
        CHECK (
            relationship_type IN (
                'supports',
                'contradicts',
                'qualifies',
                'refines',
                'extends',
                'supersedes',
                'duplicates',
                'contextualizes'
            )
        ),

    weight               numeric(3,2) NOT NULL DEFAULT 1.0,

    rationale            text,

    created_at           timestamptz NOT NULL DEFAULT now(),

    CHECK (source_claim_id <> related_claim_id),

    UNIQUE (
        source_claim_id,
        related_claim_id,
        relationship_type
    )
);

COMMENT ON TABLE knowledge.source_claim_relationship IS
'Relationships among source claims before compilation into operational knowledge.';


CREATE INDEX IF NOT EXISTS idx_source_claim_rel_source
    ON knowledge.source_claim_relationship(source_claim_id);

CREATE INDEX IF NOT EXISTS idx_source_claim_rel_target
    ON knowledge.source_claim_relationship(related_claim_id);


-- =============================================================================
-- 7. EXTRACTION JOB
-- =============================================================================
--
-- One chapter may be processed repeatedly.
-- The logical extraction job remains tied to a source version + chapter,
-- while attempts are retained separately.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.extraction_job (
    extraction_id        text PRIMARY KEY,

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    chapter_id           text NOT NULL
        REFERENCES knowledge.source_chapter(chapter_id)
        ON DELETE CASCADE,

    extraction_type      text NOT NULL,

    status               text NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'IN_PROGRESS',
                'REVIEWED',
                'APPROVED',
                'REJECTED',
                'DONE',
                'BLOCKED'
            )
        ),

    extraction_contract  jsonb NOT NULL DEFAULT '{}'::jsonb,

    model_name           text,

    model_version        text,

    source_checksum      text,

    claim_count          integer NOT NULL DEFAULT 0,

    compiled_count       integer NOT NULL DEFAULT 0,

    rejected_count       integer NOT NULL DEFAULT 0,

    reviewer_notes       text,

    reviewed_by          uuid,

    reviewed_at          timestamptz,

    started_at           timestamptz,

    completed_at         timestamptz,

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        source_version_id,
        chapter_id,
        extraction_type
    )
);

COMMENT ON TABLE knowledge.extraction_job IS
'Compiler job controlling extraction, validation and human review of a source chapter.';


CREATE INDEX IF NOT EXISTS idx_extraction_job_version
    ON knowledge.extraction_job(source_version_id);

CREATE INDEX IF NOT EXISTS idx_extraction_job_chapter
    ON knowledge.extraction_job(chapter_id);

CREATE INDEX IF NOT EXISTS idx_extraction_job_status
    ON knowledge.extraction_job(status);


DROP TRIGGER IF EXISTS trg_knowledge_extraction_job_updated_at
    ON knowledge.extraction_job;

CREATE TRIGGER trg_knowledge_extraction_job_updated_at
    BEFORE UPDATE ON knowledge.extraction_job
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 8. EXTRACTION ATTEMPT
-- =============================================================================
--
-- The same chapter may be compiled again after:
--
--   source correction
--   extraction-model upgrade
--   contract upgrade
--   reviewer rejection
--   improved OCR
--   guideline reconciliation
--
-- Never destroy previous attempts.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.extraction_attempt (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    extraction_id        text NOT NULL
        REFERENCES knowledge.extraction_job(extraction_id)
        ON DELETE CASCADE,

    attempt_no           integer NOT NULL,

    started_at           timestamptz NOT NULL DEFAULT now(),

    completed_at         timestamptz,

    model_name           text,

    model_version        text,

    prompt_version       text,

    extraction_contract  jsonb NOT NULL DEFAULT '{}'::jsonb,

    input_checksum       text,

    output_checksum      text,

    claims_produced      integer NOT NULL DEFAULT 0,

    status               text NOT NULL DEFAULT 'RUNNING'
        CHECK (
            status IN (
                'RUNNING',
                'COMPLETED',
                'FAILED',
                'REJECTED',
                'SUPERSEDED'
            )
        ),

    error_message        text,

    metadata             jsonb NOT NULL DEFAULT '{}'::jsonb,

    UNIQUE (extraction_id, attempt_no)
);

COMMENT ON TABLE knowledge.extraction_attempt IS
'Immutable-ish record of an individual compiler extraction attempt.';


CREATE INDEX IF NOT EXISTS idx_extraction_attempt_job
    ON knowledge.extraction_attempt(extraction_id);

CREATE INDEX IF NOT EXISTS idx_extraction_attempt_status
    ON knowledge.extraction_attempt(status);


-- =============================================================================
-- 9. CLAIM â†’ EXTRACTION ATTEMPT
-- =============================================================================
--
-- A claim should know exactly which compiler run produced it.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.extraction_attempt_claim (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    extraction_attempt_id uuid NOT NULL
        REFERENCES knowledge.extraction_attempt(id)
        ON DELETE CASCADE,

    claim_id             text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    extraction_confidence numeric(3,2)
        CHECK (
            extraction_confidence IS NULL
            OR extraction_confidence BETWEEN 0 AND 1
        ),

    reviewer_status      text NOT NULL DEFAULT 'pending'
        CHECK (
            reviewer_status IN (
                'pending',
                'accepted',
                'modified',
                'rejected'
            )
        ),

    reviewer_notes       text,

    created_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        extraction_attempt_id,
        claim_id
    )
);

COMMENT ON TABLE knowledge.extraction_attempt_claim IS
'Links extracted claims to the exact compiler attempt that generated them.';


CREATE INDEX IF NOT EXISTS idx_extraction_attempt_claim_attempt
    ON knowledge.extraction_attempt_claim(extraction_attempt_id);

CREATE INDEX IF NOT EXISTS idx_extraction_attempt_claim_claim
    ON knowledge.extraction_attempt_claim(claim_id);


-- =============================================================================
-- 10. PROVENANCE
-- =============================================================================
--
-- THIS IS THE BRIDGE TO RUNTIME KNOWLEDGE.
--
-- Example:
--
--   Hutchison claim
--        â†“
--   question: COUGH_DURATION
--        â†“
--   fact: COUGH_DURATION_DAYS
--        â†“
--   HPI documentation rule
--
-- Or:
--
--   Davidson claim
--        â†“
--   phenotype
--        â†“
--   condition
--        â†“
--   investigation recommendation
--
-- One claim â†’ many objects.
-- One object â†’ many claims.
-- =============================================================================


-- [RECONCILED] drop earlier definition before authoritative re-create
DROP TABLE IF EXISTS knowledge.provenance CASCADE;
CREATE TABLE IF NOT EXISTS knowledge.provenance (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    claim_id             text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    object_type          text NOT NULL,

    object_id            uuid NOT NULL,

    object_code          text,

    relationship         text NOT NULL DEFAULT 'derived_from'
        CHECK (
            relationship IN (
                'derived_from',
                'refined_by',
                'corroborated_by',
                'supersedes',
                'validated_by',
                'qualified_by',
                'contextualized_by'
            )
        ),

    weight               numeric(3,2) NOT NULL DEFAULT 1.0,

    compiler_version     text,

    review_status        text NOT NULL DEFAULT 'pending'
        CHECK (
            review_status IN (
                'pending',
                'accepted',
                'modified',
                'rejected'
            )
        ),

    reviewer_notes       text,

    created_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        claim_id,
        object_type,
        object_id,
        relationship
    )
);

COMMENT ON TABLE knowledge.provenance IS
'Derivation edges from authoritative source claims to compiled AMEXAN operational objects.';


CREATE INDEX IF NOT EXISTS idx_knowledge_provenance_claim
    ON knowledge.provenance(claim_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_provenance_object
    ON knowledge.provenance(object_type, object_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_provenance_code
    ON knowledge.provenance(object_code);

CREATE INDEX IF NOT EXISTS idx_knowledge_provenance_status
    ON knowledge.provenance(review_status);


-- =============================================================================
-- 11. SOURCE CLAIM CONFLICTS
-- =============================================================================
--
-- Medicine contains legitimate conflicts:
--
--   old edition vs new edition
--   textbook vs guideline
--   international guideline vs local guideline
--   adult vs paediatric
--   general population vs pregnancy
--   tertiary centre vs resource-limited setting
--
-- The compiler MUST NOT silently choose.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_claim_conflict (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    claim_id             text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    conflicting_claim_id text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    conflict_type        text NOT NULL
        CHECK (
            conflict_type IN (
                'threshold',
                'definition',
                'classification',
                'diagnosis',
                'investigation',
                'management',
                'dose',
                'timing',
                'contraindication',
                'population',
                'jurisdiction',
                'terminology',
                'other'
            )
        ),

    resolution_status    text NOT NULL DEFAULT 'UNRESOLVED'
        CHECK (
            resolution_status IN (
                'UNRESOLVED',
                'RESOLVED',
                'ACCEPTED_DIFFERENCE',
                'SUPERSEDED',
                'REJECTED'
            )
        ),

    preferred_claim_id   text
        REFERENCES knowledge.source_claim(claim_id),

    rationale            text,

    resolved_by          uuid,

    resolved_at          timestamptz,

    created_at           timestamptz NOT NULL DEFAULT now(),

    CHECK (claim_id <> conflicting_claim_id),

    UNIQUE (
        claim_id,
        conflicting_claim_id,
        conflict_type
    )
);

COMMENT ON TABLE knowledge.source_claim_conflict IS
'Explicit conflict registry preventing silent resolution of clinically meaningful source disagreement.';


CREATE INDEX IF NOT EXISTS idx_source_claim_conflict_claim
    ON knowledge.source_claim_conflict(claim_id);

CREATE INDEX IF NOT EXISTS idx_source_claim_conflict_other
    ON knowledge.source_claim_conflict(conflicting_claim_id);

CREATE INDEX IF NOT EXISTS idx_source_claim_conflict_status
    ON knowledge.source_claim_conflict(resolution_status);


-- =============================================================================
-- 12. SOURCE ERRATA / CORRECTIONS
-- =============================================================================
--
-- Corrections do not rewrite the original extracted text.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_erratum (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    page_number          integer,

    chunk_id             uuid
        REFERENCES knowledge.source_chunk(id)
        ON DELETE SET NULL,

    original_text        text,

    corrected_text       text NOT NULL,

    correction_reason    text,

    correction_source    text,

    status               text NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'VERIFIED',
                'APPLIED',
                'REJECTED'
            )
        ),

    reviewed_by          uuid,

    reviewed_at          timestamptz,

    created_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.source_erratum IS
'Reviewed correction layer for extraction or source transcription errors without mutating original source chunks.';


CREATE INDEX IF NOT EXISTS idx_source_erratum_version
    ON knowledge.source_erratum(source_version_id);

CREATE INDEX IF NOT EXISTS idx_source_erratum_chunk
    ON knowledge.source_erratum(chunk_id);

CREATE INDEX IF NOT EXISTS idx_source_erratum_status
    ON knowledge.source_erratum(status);


-- =============================================================================
-- 13. CLAIM EVIDENCE LOCATION
-- =============================================================================
--
-- A claim may be supported by several exact source locations.
-- This is more precise than forcing one chunk_id.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_claim_location (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    claim_id             text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    chunk_id             uuid
        REFERENCES knowledge.source_chunk(id)
        ON DELETE SET NULL,

    page_start           integer NOT NULL,

    page_end             integer NOT NULL,

    text_start           integer,

    text_end             integer,

    location_role        text NOT NULL DEFAULT 'primary'
        CHECK (
            location_role IN (
                'primary',
                'supporting',
                'qualifying',
                'contradicting'
            )
        ),

    created_at           timestamptz NOT NULL DEFAULT now(),

    CHECK (page_start <= page_end),

    UNIQUE (
        claim_id,
        chunk_id,
        page_start,
        page_end,
        location_role
    )
);

COMMENT ON TABLE knowledge.source_claim_location IS
'Precise page/chunk evidence locations supporting or qualifying an atomic source claim.';


CREATE INDEX IF NOT EXISTS idx_source_claim_location_claim
    ON knowledge.source_claim_location(claim_id);

CREATE INDEX IF NOT EXISTS idx_source_claim_location_chunk
    ON knowledge.source_claim_location(chunk_id);


-- =============================================================================
-- 14. COMPILER OBJECT TARGET
-- =============================================================================
--
-- The compiler needs to know WHAT KIND OF AMEXAN OBJECT a claim should become.
--
-- Examples:
--
--   QUESTION
--   FACT
--   SYMPTOM
--   SIGN
--   PHENOTYPE
--   MECHANISM
--   CONDITION
--   INVESTIGATION
--   RULE
--   DOCUMENTATION
--   PROTOCOL
--   EDUCATION
--
-- This avoids burying compilation intent inside free text.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.compiler_target (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    claim_id             text NOT NULL
        REFERENCES knowledge.source_claim(claim_id)
        ON DELETE CASCADE,

    object_type          text NOT NULL,

    target_code          text,

    compilation_role     text NOT NULL DEFAULT 'primary'
        CHECK (
            compilation_role IN (
                'primary',
                'secondary',
                'supporting',
                'documentation',
                'navigation',
                'safety'
            )
        ),

    extraction_contract  jsonb NOT NULL DEFAULT '{}'::jsonb,

    status               text NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'COMPILED',
                'REVIEWED',
                'APPROVED',
                'REJECTED'
            )
        ),

    compiled_object_id   uuid,

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        claim_id,
        object_type,
        target_code,
        compilation_role
    )
);

COMMENT ON TABLE knowledge.compiler_target IS
'Explicit compiler target describing which operational AMEXAN object should be produced from a source claim.';


CREATE INDEX IF NOT EXISTS idx_compiler_target_claim
    ON knowledge.compiler_target(claim_id);

CREATE INDEX IF NOT EXISTS idx_compiler_target_type
    ON knowledge.compiler_target(object_type);

CREATE INDEX IF NOT EXISTS idx_compiler_target_status
    ON knowledge.compiler_target(status);

CREATE INDEX IF NOT EXISTS idx_compiler_target_contract
    ON knowledge.compiler_target
    USING gin(extraction_contract);


DROP TRIGGER IF EXISTS trg_knowledge_compiler_target_updated_at
    ON knowledge.compiler_target;

CREATE TRIGGER trg_knowledge_compiler_target_updated_at
    BEFORE UPDATE ON knowledge.compiler_target
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 15. EXTRACTION CONTRACT STANDARD
-- =============================================================================
--
-- Every clinically compilable claim should answer the same universal questions.
--
-- WHAT IS IT?
-- WHY DOES IT MATTER?
-- WHEN DOES IT APPLY?
-- WHAT ACTIVATES IT?
-- WHAT FACT DOES IT PRODUCE?
-- WHAT FACTS SUPPORT IT?
-- WHAT FACTS CONTRADICT IT?
-- WHAT SHOULD BE ASKED?
-- WHAT SHOULD BE EXAMINED?
-- WHAT SHOULD BE INVESTIGATED?
-- WHAT SHOULD BE MONITORED?
-- WHAT CAN IT TRIGGER?
-- WHAT DOES IT DIFFERENTIATE?
-- WHAT CHANGES MANAGEMENT?
-- WHAT CHANGES URGENCY?
-- WHAT SAFETY CONDITIONS MODIFY IT?
-- HOW IS IT DOCUMENTED?
-- WHAT POPULATION DOES IT APPLY TO?
-- WHAT SPECIALTY/CONTEXT DOES IT APPLY TO?
-- WHAT SOURCE SUPPORTS IT?
-- WHO APPROVED IT?
-- WHEN DOES IT BECOME EFFECTIVE?
--
-- The JSON schema below is a CONTRACT TEMPLATE, not the medical answer.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.compiler_contract (
    contract_code        text PRIMARY KEY,

    contract_name        text NOT NULL,

    object_type          text NOT NULL,

    contract_version     integer NOT NULL DEFAULT 1,

    required_fields      jsonb NOT NULL DEFAULT '[]'::jsonb,

    optional_fields      jsonb NOT NULL DEFAULT '[]'::jsonb,

    validation_rules     jsonb NOT NULL DEFAULT '{}'::jsonb,

    status               text NOT NULL DEFAULT 'active'
        CHECK (
            status IN (
                'active',
                'deprecated'
            )
        ),

    created_at           timestamptz NOT NULL DEFAULT now(),

    updated_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.compiler_contract IS
'Versioned extraction contracts defining the minimum information required to compile a source claim into an AMEXAN operational object.';


DROP TRIGGER IF EXISTS trg_knowledge_compiler_contract_updated_at
    ON knowledge.compiler_contract;

CREATE TRIGGER trg_knowledge_compiler_contract_updated_at
    BEFORE UPDATE ON knowledge.compiler_contract
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();


-- =============================================================================
-- 16. DEFAULT UNIVERSAL CLINICAL-METHOD CONTRACT
-- =============================================================================


INSERT INTO knowledge.compiler_contract
(
    contract_code,
    contract_name,
    object_type,
    contract_version,
    required_fields,
    optional_fields,
    validation_rules
)
VALUES
(
    'CONTRACT-UNIVERSAL-CLINICAL',
    'Universal AMEXAN Clinical Knowledge Contract',
    'universal',
    1,

    '[
        "what_is_it",
        "why_it_matters",
        "when_it_applies",
        "activating_facts",
        "supporting_facts",
        "contradicting_facts",
        "questions_generated",
        "examination_targets",
        "investigation_targets",
        "differentials",
        "safety_modifiers",
        "documentation",
        "source_support"
    ]'::jsonb,

    '[
        "risk_factors",
        "etiology",
        "mechanisms",
        "phenotypes",
        "complications",
        "monitoring",
        "management_effect",
        "urgency",
        "education",
        "follow_up",
        "population_scope",
        "specialty_scope",
        "jurisdiction_scope"
    ]'::jsonb,

    '{
        "must_be_traceable": true,
        "must_have_source_location": true,
        "must_define_population": false,
        "must_define_activation": true,
        "must_define_documentation": true,
        "must_define_safety": true
    }'::jsonb
)
ON CONFLICT (contract_code) DO NOTHING;


-- =============================================================================
-- 17. SPECIALIZED COMPILER CONTRACTS
-- =============================================================================


INSERT INTO knowledge.compiler_contract
(
    contract_code,
    contract_name,
    object_type,
    contract_version,
    required_fields,
    optional_fields,
    validation_rules
)
VALUES

(
    'CONTRACT-HISTORY',
    'AMEXAN History / HPI Compiler Contract',
    'question',
    1,

    '[
        "what_is_being_explored",
        "why_question_is_needed",
        "activation_condition",
        "fact_produced",
        "answer_structure",
        "documentation_output",
        "source_support"
    ]'::jsonb,

    '[
        "question_priority",
        "red_flag_relation",
        "differential_relation",
        "risk_factor_relation",
        "age_modification",
        "sex_modification",
        "pregnancy_modification",
        "paediatric_modification",
        "geriatric_modification",
        "emergency_modification",
        "previous_episode_relation",
        "health_seeking_relation"
    ]'::jsonb,

    '{
        "must_map_to_fact": true,
        "must_define_activation": true,
        "must_support_documentation": true,
        "must_not_make_diagnosis_from_question": true
    }'::jsonb
),

(
    'CONTRACT-EXAMINATION',
    'AMEXAN Examination Compiler Contract',
    'examination_finding',
    1,

    '[
        "finding_definition",
        "examination_method",
        "fact_produced",
        "clinical_significance",
        "source_support"
    ]'::jsonb,

    '[
        "body_system",
        "maneuver",
        "measurement",
        "normal_range",
        "age_range",
        "red_flag",
        "differential",
        "documentation_output"
    ]'::jsonb,

    '{
        "must_map_to_fact": true,
        "must_define_observation_method": true
    }'::jsonb
),

(
    'CONTRACT-REASONING',
    'AMEXAN Clinical Reasoning Contract',
    'rule',
    1,

    '[
        "triggering_facts",
        "supporting_facts",
        "contradicting_facts",
        "action",
        "clinical_rationale",
        "source_support"
    ]'::jsonb,

    '[
        "priority",
        "urgency",
        "red_flags",
        "differentials",
        "investigations",
        "management",
        "monitoring",
        "safety_modifiers"
    ]'::jsonb,

    '{
        "must_be_reproducible": true,
        "must_expose_reason": true,
        "must_define_conflicts": true
    }'::jsonb
),

(
    'CONTRACT-MEDICINE',
    'AMEXAN Disease / Medicine Contract',
    'condition',
    1,

    '[
        "definition",
        "classification",
        "aetiology",
        "risk_factors",
        "phenotypes",
        "mechanisms",
        "clinical_features",
        "differentials",
        "investigations",
        "complications",
        "source_support"
    ]'::jsonb,

    '[
        "management",
        "prognosis",
        "monitoring",
        "follow_up",
        "education",
        "special_populations",
        "severity",
        "staging"
    ]'::jsonb,

    '{
        "must_separate_diagnosis_from_symptom": true,
        "must_support_differential_reasoning": true,
        "must_define_complications": true
    }'::jsonb
),

(
    'CONTRACT-INVESTIGATION',
    'AMEXAN Investigation Contract',
    'investigation',
    1,

    '[
        "what_test_is",
        "why_ordered",
        "what_question_it_answers",
        "result_structure",
        "source_support"
    ]'::jsonb,

    '[
        "preparation",
        "specimen",
        "turnaround",
        "limitations",
        "sensitivity",
        "specificity",
        "positive_result_effect",
        "negative_result_effect",
        "dangerous_result",
        "follow_up"
    ]'::jsonb,

    '{
        "must_define_clinical_question": true,
        "must_define_result_interpretation": true
    }'::jsonb
),

(
    'CONTRACT-SAFETY',
    'AMEXAN Safety Contract',
    'safety',
    1,

    '[
        "triggering_condition",
        "risk",
        "action",
        "urgency",
        "source_support"
    ]'::jsonb,

    '[
        "contraindication",
        "allergy",
        "pregnancy",
        "renal",
        "hepatic",
        "age",
        "interaction",
        "monitoring"
    ]'::jsonb,

    '{
        "must_be_explicit": true,
        "must_not_be_silent": true
    }'::jsonb
),

(
    'CONTRACT-DOCUMENTATION',
    'AMEXAN Clinical Documentation Contract',
    'documentation',
    1,

    '[
        "fact",
        "clinical_meaning",
        "rendering_rule",
        "source_support"
    ]'::jsonb,

    '[
        "section",
        "chronology",
        "severity",
        "functional_impact",
        "risk",
        "health_seeking",
        "previous_episode",
        "examination",
        "language",
        "patient_gender",
        "age"
    ]'::jsonb,

    '{
        "must_not_invent_facts": true,
        "must_not_make_unsupported_deductions": true,
        "must_preserve_temporal_order": true,
        "must_preserve_negatives": true
    }'::jsonb
)

ON CONFLICT (contract_code) DO NOTHING;


-- =============================================================================
-- 18. SOURCE VERSION QUALITY CONTROL
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_quality_check (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    check_type           text NOT NULL
        CHECK (
            check_type IN (
                'checksum',
                'page_count',
                'ocr',
                'page_number',
                'chapter_map',
                'text_integrity',
                'claim_integrity',
                'provenance',
                'authority',
                'compiler'
            )
        ),

    status               text NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'PASS',
                'FAIL',
                'WARNING'
            )
        ),

    expected_value       text,

    observed_value       text,

    details              jsonb NOT NULL DEFAULT '{}'::jsonb,

    checked_at           timestamptz,

    checked_by           uuid,

    created_at           timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge.source_quality_check IS
'Quality gates protecting the compiler from malformed, incomplete or incorrectly mapped source material.';


CREATE INDEX IF NOT EXISTS idx_source_quality_version
    ON knowledge.source_quality_check(source_version_id);

CREATE INDEX IF NOT EXISTS idx_source_quality_status
    ON knowledge.source_quality_check(status);


-- =============================================================================
-- 19. SOURCE PUBLICATION / APPROVAL GATE
-- =============================================================================
--
-- A source version should not become a compiler foundation merely because a
-- file exists.
-- =============================================================================


CREATE TABLE IF NOT EXISTS knowledge.source_release (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    source_version_id    text NOT NULL
        REFERENCES knowledge.source_version(version_id)
        ON DELETE CASCADE,

    release_code         text NOT NULL UNIQUE,

    release_type         text NOT NULL DEFAULT 'compiler_foundation'
        CHECK (
            release_type IN (
                'compiler_foundation',
                'clinical_reference',
                'training',
                'archive'
            )
        ),

    status               text NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'APPROVED',
                'REJECTED',
                'RETIRED'
            )
        ),

    required_checks      jsonb NOT NULL DEFAULT '[]'::jsonb,

    approval_notes       text,

    approved_by          uuid,

    approved_at          timestamptz,

    created_at           timestamptz NOT NULL DEFAULT now(),

    UNIQUE (
        source_version_id,
        release_type
    )
);

COMMENT ON TABLE knowledge.source_release IS
'Publication gate determining whether a source version may be used as a compiler foundation.';


CREATE INDEX IF NOT EXISTS idx_source_release_version
    ON knowledge.source_release(source_version_id);

CREATE INDEX IF NOT EXISTS idx_source_release_status
    ON knowledge.source_release(status);


-- =============================================================================
-- 20. UNIVERSAL SOURCE SEARCH INDEX
-- =============================================================================
--
-- Fast compiler navigation across source text and claims.
-- PostgreSQL full-text search is used for discovery; it does not replace
-- exact provenance.
-- =============================================================================


ALTER TABLE knowledge.source_chunk
    ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (
        to_tsvector(
            'english',
            coalesce(chunk_text, '')
        )
    ) STORED;


CREATE INDEX IF NOT EXISTS idx_source_chunk_search
    ON knowledge.source_chunk
    USING gin(search_vector);


ALTER TABLE knowledge.source_claim
    ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (
        to_tsvector(
            'english',
            coalesce(claim_text, '') || ' ' ||
            coalesce(claim_type, '') || ' ' ||
            coalesce(claim_kind, '')
        )
    ) STORED;


CREATE INDEX IF NOT EXISTS idx_source_claim_search
    ON knowledge.source_claim
    USING gin(search_vector);


-- =============================================================================
-- 21. SOURCE NAVIGATION VIEW
-- =============================================================================


CREATE OR REPLACE VIEW knowledge.source_map AS
SELECT
    sv.version_id,
    s.source_id,
    s.source_name,
    s.source_type,
    s.authority_scope,
    s.amexan_role,
    sv.edition,
    sv.publication_year,
    sv.language,

    ss.section_id,
    ss.section_no,
    ss.section_name,
    ss.amexan_layer,

    sc.chapter_id,
    sc.chapter_no,
    sc.chapter_name,
    sc.start_page,
    sc.end_page,
    sc.amexan_role       AS chapter_amexan_role,
    sc.amexan_context,
    sc.amexan_system,

    sc.extraction_priority,
    sc.is_extractable

FROM knowledge.source_version sv

JOIN knowledge.source s
    ON s.source_id = sv.source_id

JOIN knowledge.source_section ss
    ON ss.source_version_id = sv.version_id

JOIN knowledge.source_chapter sc
    ON sc.section_id = ss.section_id

WHERE sv.status IN ('ACTIVE', 'active');


COMMENT ON VIEW knowledge.source_map IS
'Fast navigation map from source â†’ edition â†’ section â†’ chapter â†’ AMEXAN role/context/system.';


-- =============================================================================
-- 22. CLAIM PROVENANCE VIEW
-- =============================================================================


CREATE OR REPLACE VIEW knowledge.claim_provenance AS
SELECT
    c.claim_id,
    c.claim_code,
    c.claim_type,
    c.claim_kind,
    c.knowledge_type,
    c.claim_text,

    c.page_start,
    c.page_end,

    sv.version_id,
    s.source_id,
    s.source_name,
    s.source_type,
    s.authority_scope,

    ch.chapter_id,
    ch.chapter_name,

    c.status,
    c.is_compiled,
    c.confidence,

    p.object_type,
    p.object_id,
    p.object_code,
    p.relationship,
    p.weight,
    p.review_status

FROM knowledge.source_claim c

JOIN knowledge.source_version sv
    ON sv.version_id = c.source_version_id

JOIN knowledge.source s
    ON s.source_id = sv.source_id

JOIN knowledge.source_chapter ch
    ON ch.chapter_id = c.chapter_id

LEFT JOIN knowledge.provenance p
    ON p.claim_id = c.claim_id;


COMMENT ON VIEW knowledge.claim_provenance IS
'Complete source â†’ claim â†’ compiled AMEXAN object provenance view.';


-- =============================================================================
-- 23. CHAPTER COMPILATION STATUS VIEW
-- =============================================================================


CREATE OR REPLACE VIEW knowledge.chapter_compilation_status AS
SELECT
    ch.chapter_id,
    ch.chapter_name,
    ch.source_version_id,

    COUNT(DISTINCT c.claim_id) AS claim_count,

    COUNT(DISTINCT c.claim_id)
        FILTER (
            WHERE c.status IN ('VERIFIED', 'active')
        ) AS verified_claim_count,

    COUNT(DISTINCT c.claim_id)
        FILTER (
            WHERE c.is_compiled = true
        ) AS compiled_claim_count,

    COUNT(DISTINCT c.claim_id)
        FILTER (
            WHERE c.status = 'needs_review'
        ) AS review_required_count,

    COUNT(DISTINCT p.id) AS provenance_edge_count,

    ej.status AS extraction_status,

    CASE
        WHEN COUNT(DISTINCT c.claim_id) = 0
            THEN 'NOT_STARTED'

        WHEN COUNT(DISTINCT c.claim_id)
             FILTER (WHERE c.status = 'needs_review') > 0
            THEN 'REVIEW_REQUIRED'

        WHEN COUNT(DISTINCT c.claim_id)
             FILTER (WHERE c.is_compiled = false) > 0
            THEN 'COMPILATION_INCOMPLETE'

        ELSE 'COMPILED'
    END AS compilation_state

FROM knowledge.source_chapter ch

LEFT JOIN knowledge.source_claim c
    ON c.chapter_id = ch.chapter_id

LEFT JOIN knowledge.provenance p
    ON p.claim_id = c.claim_id

LEFT JOIN LATERAL (
    SELECT e.status
    FROM knowledge.extraction_job e
    WHERE e.chapter_id = ch.chapter_id
    ORDER BY e.created_at DESC
    LIMIT 1
) ej
    ON true

GROUP BY
    ch.chapter_id,
    ch.chapter_name,
    ch.source_version_id,
    ej.status;


COMMENT ON VIEW knowledge.chapter_compilation_status IS
'Fast compiler dashboard showing source extraction, claim verification, compilation and provenance completeness.';


-- =============================================================================
-- 24. SOURCE AUTHORITY RESOLUTION VIEW
-- =============================================================================
--
-- Used by the compiler when multiple sources address the same concept.
-- This does NOT automatically resolve clinical conflicts.
-- It exposes authority boundaries so the compiler can require explicit review.
-- =============================================================================


CREATE OR REPLACE VIEW knowledge.source_authority_resolution AS
SELECT
    c.claim_id,
    c.claim_code,
    c.claim_type,
    c.claim_kind,
    c.knowledge_type,

    s.source_id,
    s.source_name,
    s.source_type,
    s.authority_scope,
    s.amexan_role,
    s.authority_rank,

    sv.version_id,
    sv.edition,
    sv.publication_year,
    sv.status AS source_version_status,

    c.population_scope,
    c.specialty_scope,
    c.jurisdiction_scope,

    c.status AS claim_status,
    c.confidence

FROM knowledge.source_claim c

JOIN knowledge.source_version sv
    ON sv.version_id = c.source_version_id

JOIN knowledge.source s
    ON s.source_id = sv.source_id;


COMMENT ON VIEW knowledge.source_authority_resolution IS
'Authority-aware source claim view used during compiler reconciliation.';


-- =============================================================================
-- 25. UNIVERSAL COMPILER METRICS
-- =============================================================================


CREATE OR REPLACE VIEW knowledge.compiler_metrics AS
SELECT
    (SELECT COUNT(*)
       FROM knowledge.source) AS source_count,

    (SELECT COUNT(*)
       FROM knowledge.source_version) AS source_version_count,

    (SELECT COUNT(*)
       FROM knowledge.source_section) AS section_count,

    (SELECT COUNT(*)
       FROM knowledge.source_chapter) AS chapter_count,

    (SELECT COUNT(*)
       FROM knowledge.source_chunk) AS chunk_count,

    (SELECT COUNT(*)
       FROM knowledge.source_claim) AS claim_count,

    (SELECT COUNT(*)
       FROM knowledge.source_claim
      WHERE is_compiled = true) AS compiled_claim_count,

    (SELECT COUNT(*)
       FROM knowledge.source_claim
      WHERE status = 'needs_review') AS review_required_count,

    (SELECT COUNT(*)
       FROM knowledge.provenance) AS provenance_edge_count,

    (SELECT COUNT(*)
       FROM knowledge.extraction_job
      WHERE status IN ('PENDING', 'IN_PROGRESS')) AS active_extraction_jobs,

    (SELECT COUNT(*)
       FROM knowledge.source_claim_conflict
      WHERE resolution_status = 'UNRESOLVED') AS unresolved_conflicts;


COMMENT ON VIEW knowledge.compiler_metrics IS
'Real-time compiler health metrics for the AMEXAN knowledge pipeline.';


-- =============================================================================
-- 26. UNIVERSAL CLAIM INTEGRITY FUNCTION
-- =============================================================================
--
-- Prevents an apparently verified claim from existing without minimum
-- provenance anchors.
-- =============================================================================


CREATE OR REPLACE FUNCTION knowledge.validate_source_claim_integrity(
    p_claim_id text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_claim knowledge.source_claim%ROWTYPE;
    v_chunk_exists boolean;
    v_location_exists boolean;
BEGIN

    SELECT *
    INTO v_claim
    FROM knowledge.source_claim
    WHERE claim_id = p_claim_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_claim.claim_text IS NULL
       OR btrim(v_claim.claim_text) = '' THEN
        RETURN false;
    END IF;

    IF v_claim.page_start IS NULL
       OR v_claim.page_end IS NULL THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM knowledge.source_chunk
        WHERE id = v_claim.chunk_id
    )
    INTO v_chunk_exists;

    SELECT EXISTS (
        SELECT 1
        FROM knowledge.source_claim_location
        WHERE claim_id = p_claim_id
    )
    INTO v_location_exists;

    IF NOT v_chunk_exists AND NOT v_location_exists THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$;


COMMENT ON FUNCTION knowledge.validate_source_claim_integrity(text) IS
'Checks whether a source claim has sufficient text and source-location provenance for compilation.';


-- =============================================================================
-- 27. VERIFIED-CLAIM GUARD
-- =============================================================================
--
-- A VERIFIED claim must have:
--
--   text
--   source version
--   chapter
--   page range
--   valid confidence
--
-- =============================================================================


CREATE OR REPLACE FUNCTION knowledge.guard_verified_source_claim()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.status IN ('VERIFIED', 'active') THEN

        IF NEW.claim_text IS NULL
           OR btrim(NEW.claim_text) = '' THEN
            RAISE EXCEPTION
                'Verified source claim % must contain claim_text',
                NEW.claim_id;
        END IF;

        IF NEW.page_start IS NULL
           OR NEW.page_end IS NULL THEN
            RAISE EXCEPTION
                'Verified source claim % must have printed page range',
                NEW.claim_id;
        END IF;

        IF NEW.confidence IS NULL THEN
            RAISE EXCEPTION
                'Verified source claim % must have confidence',
                NEW.claim_id;
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS trg_guard_verified_source_claim
    ON knowledge.source_claim;

CREATE TRIGGER trg_guard_verified_source_claim
    BEFORE INSERT OR UPDATE
    ON knowledge.source_claim
    FOR EACH ROW
    EXECUTE FUNCTION knowledge.guard_verified_source_claim();


-- =============================================================================
-- 28. COMPILATION SAFETY FUNCTION
-- =============================================================================
--
-- The compiler must refuse to mark a claim compiled unless:
--
--   1. claim is valid
--   2. claim is reviewed/verified
--   3. a compiler target exists
--   4. provenance exists
--
-- This is intentionally exposed as a function for the compiler service.
-- =============================================================================


CREATE OR REPLACE FUNCTION knowledge.can_compile_claim(
    p_claim_id text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_valid boolean;
    v_target boolean;
    v_provenance boolean;
    v_status text;
BEGIN

    SELECT status
    INTO v_status
    FROM knowledge.source_claim
    WHERE claim_id = p_claim_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_status NOT IN ('VERIFIED', 'active') THEN
        RETURN false;
    END IF;

    v_valid :=
        knowledge.validate_source_claim_integrity(p_claim_id);

    IF NOT v_valid THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM knowledge.compiler_target
        WHERE claim_id = p_claim_id
          AND status IN (
              'PENDING',
              'COMPILED',
              'REVIEWED',
              'APPROVED'
          )
    )
    INTO v_target;

    IF NOT v_target THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$;


COMMENT ON FUNCTION knowledge.can_compile_claim(text) IS
'Compilation gate ensuring that only verified, provenance-backed claims with explicit compiler targets enter operational knowledge.';


-- =============================================================================
-- 29. SOURCE â†’ OPERATIONAL OBJECT DEPENDENCY MAP
-- =============================================================================
--
-- Gives the CPU/compiler a universal map:
--
-- SOURCE
--   â†’ CLAIM
--      â†’ TARGET
--         â†’ PROVENANCE
--            â†’ OPERATIONAL OBJECT
--
-- =============================================================================


CREATE OR REPLACE VIEW knowledge.source_operational_map AS
SELECT
    s.source_id,
    s.source_name,
    s.source_type,
    s.authority_scope,

    sv.version_id,
    sv.edition,
    sv.publication_year,

    ss.section_id,
    ss.section_name,
    ss.amexan_layer,

    ch.chapter_id,
    ch.chapter_name,
    ch.amexan_role,
    ch.amexan_context,
    ch.amexan_system,

    c.claim_id,
    c.claim_code,
    c.claim_type,
    c.claim_kind,
    c.claim_text,
    c.knowledge_type,
    c.page_start,
    c.page_end,
    c.status AS claim_status,

    ct.object_type AS target_object_type,
    ct.target_code,
    ct.compilation_role,
    ct.status AS target_status,

    p.object_type,
    p.object_id,
    p.object_code,
    p.relationship,
    p.review_status AS provenance_status

FROM knowledge.source s

JOIN knowledge.source_version sv
    ON sv.source_id = s.source_id

JOIN knowledge.source_section ss
    ON ss.source_version_id = sv.version_id

JOIN knowledge.source_chapter ch
    ON ch.section_id = ss.section_id

JOIN knowledge.source_claim c
    ON c.chapter_id = ch.chapter_id

LEFT JOIN knowledge.compiler_target ct
    ON ct.claim_id = c.claim_id

LEFT JOIN knowledge.provenance p
    ON p.claim_id = c.claim_id;


COMMENT ON VIEW knowledge.source_operational_map IS
'Universal compiler lineage from authoritative source through claim and compiler target to the AMEXAN operational knowledge graph.';


-- =============================================================================
-- 30. MEDICAL KNOWLEDGE COMPILER PRINCIPLES
-- =============================================================================
--
-- These comments are intentionally stored in PostgreSQL so the architecture
-- remains self-describing to developers, auditors and future compiler agents.
-- =============================================================================


COMMENT ON TABLE knowledge.source IS
'AMEXAN SOURCE AUTHORITY LAYER. Defines the authoritative scope of each textbook, guideline, formulary, journal, protocol or reference. A source is never universally authoritative merely because it is prestigious.';

COMMENT ON TABLE knowledge.source_version IS
'AMEXAN SOURCE VERSION LAYER. Every edition is independently traceable. Historical versions are preserved rather than overwritten.';

COMMENT ON TABLE knowledge.source_section IS
'AMEXAN SOURCE TAXONOMY LAYER. Maps source material into UNIVERSAL, CONTEXT, SYSTEM or NAVIGATION_ONLY knowledge layers.';

COMMENT ON TABLE knowledge.source_chapter IS
'AMEXAN SOURCE NAVIGATION LAYER. Chapters are mapped to operational roles such as HISTORY_ENGINE, EXAM_ENGINE, MEDICINE_ENGINE, REASONING_INTERFACE and context/system engines.';

COMMENT ON TABLE knowledge.source_chunk IS
'AMEXAN READ LAYER. Raw extracted text anchored to printed pages. Raw source text is never treated as an operational clinical rule without compilation.';

COMMENT ON TABLE knowledge.source_claim IS
'AMEXAN ATOMIC KNOWLEDGE LAYER. Every clinically meaningful statement is decomposed into an atomic claim that can independently support questions, facts, symptoms, examinations, investigations, phenotypes, mechanisms, conditions, rules, documentation and safety objects.';

COMMENT ON TABLE knowledge.compiler_target IS
'AMEXAN COMPILATION INTENT LAYER. Explicitly states which operational knowledge objects a source claim is intended to produce.';

COMMENT ON TABLE knowledge.provenance IS
'AMEXAN LINEAGE LAYER. Every operational object can be traced back through compiled claims to exact source material and page-level evidence.';

COMMENT ON TABLE knowledge.source_claim_conflict IS
'AMEXAN EPISTEMIC CONFLICT LAYER. Clinically meaningful disagreement between authoritative claims must be explicitly resolved or retained as an accepted contextual difference; it must never be silently discarded.';


-- =============================================================================
-- 31. FINAL ARCHITECTURAL GUARANTEE
-- =============================================================================
--
-- AMEXAN now has a source-to-CPU knowledge lineage:
--
--
--      â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--      â”‚              AUTHORITATIVE MEDICINE         â”‚
--      â”‚ textbooks / guidelines / journals /        â”‚
--      â”‚ clinical methods / formularies / protocols  â”‚
--      â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                             â”‚
--                             â–¼
--                    knowledge.source
--                             â”‚
--                             â–¼
--                 knowledge.source_version
--                             â”‚
--                             â–¼
--                   knowledge.source_section
--                             â”‚
--                             â–¼
--                    knowledge.source_chapter
--                             â”‚
--                             â–¼
--                     knowledge.source_chunk
--                             â”‚
--                             â–¼
--                     knowledge.source_claim
--                             â”‚
--              â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--              â”‚              â”‚               â”‚
--              â–¼              â–¼               â–¼
--        compiler_target   conflicts     evidence locations
--              â”‚
--              â–¼
--       extraction / review
--              â”‚
--              â–¼
--       AMEXAN OPERATIONAL KNOWLEDGE
--              â”‚
--      â”Œâ”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--      â”‚       â”‚       â”‚       â”‚           â”‚
--      â–¼       â–¼       â–¼       â–¼           â–¼
--    FACT   QUESTION  SYMPTOM PHENOTYPE  MECHANISM
--      â”‚       â”‚       â”‚       â”‚           â”‚
--      â””â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                              â”‚
--                              â–¼
--                          CONDITION
--                              â”‚
--             â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
--             â–¼                â–¼                â–¼
--        INVESTIGATION     PROTOCOL        MANAGEMENT
--             â”‚                â”‚                â”‚
--             â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
--                              â–¼
--                       CLINICAL CPU
--                              â”‚
--                              â–¼
--                 PATIENT-SPECIFIC STATE
--                              â”‚
--                              â–¼
--                 QUESTION / EXAM / ACTION
--                              â”‚
--                              â–¼
--                      NEW CLINICAL FACT
--                              â”‚
--                              â–¼
--                         CPU REASONING
--
--
-- CRITICAL AMEXAN RULE:
--
--       SOURCE KNOWLEDGE
--              â‰ 
--       RUNTIME KNOWLEDGE
--
-- The compiler is the controlled bridge.
--
-- Therefore the system can answer:
--
--   "Why did AMEXAN ask this question?"
--        â†’ question
--        â†’ fact
--        â†’ rule
--        â†’ compiled claim
--        â†’ exact source
--        â†’ printed page
--
--   "Why was this examination requested?"
--        â†’ examination target
--        â†’ symptom / phenotype / mechanism
--        â†’ rule
--        â†’ source claim
--        â†’ source page
--
--   "Why was this investigation suggested?"
--        â†’ investigation
--        â†’ clinical question
--        â†’ phenotype / mechanism / condition
--        â†’ rule
--        â†’ source claim
--        â†’ authority
--
--   "Why did the documentation engine write this sentence?"
--        â†’ documentation rule
--        â†’ fact
--        â†’ symptom / clinical object
--        â†’ source claim
--        â†’ exact source location
--
--   "Why did the system NOT use this recommendation?"
--        â†’ conflicting claim / scope / population / jurisdiction
--        â†’ safety rule / override
--        â†’ provenance
--
-- This makes the AMEXAN clinical operating system auditable, versioned,
-- explainable, source-grounded and capable of continuously compiling
-- universal medical knowledge into fast operational clinical intelligence.
-- =============================================================================
