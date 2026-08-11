-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H1: source + chapter map (locked spec)
-- =============================================================================
-- The Medical Knowledge Compiler turns authoritative sources (textbooks,
-- guidelines) into structured, provenance-backed AMEXAN knowledge. This
-- migration builds the SOURCE side of the pipeline only — the raw material
-- from which operational knowledge (symptom/question/fact/phenotype/...) is
-- compiled:
--
--   SOURCE (HUTCHISON_CM)
--     -> VERSION (HUTCHISON_24_2018)
--     -> SECTION (H1-S1..H1-S4)   [UNIVERSAL / CONTEXT / SYSTEM / NAVIGATION_ONLY]
--     -> CHAPTER (H1-C01..H1-C21) [AMEXAN role / context / system]
--     -> CHUNK  (raw page text, printed page numbers)      [the READ layer]
--     -> CLAIM  (atomic, provenance-ready statements)
--     -> EXTRACTION_JOB (EXT-H01..EXT-H21, PENDING review)
--
-- and the bridge that ties compiled operational objects back to the exact
-- source claims that support them: knowledge.provenance.
--
-- Design rules (from the compiler contract):
--   • source_knowledge is a SEPARATE layer from operational knowledge.
--     Nothing here is directly consumed by the CPU; it exists to be compiled.
--   • Every claim is atomic and carries its source page range (printed book
--     page numbers), its claim_type (the AMEXAN-layer classification, e.g.
--     CLINICAL_METHOD / QUESTIONING_PRINCIPLE / EXAMINATION_PRINCIPLE /
--     RESPIRATORY_METHOD), its claim_kind (definition / rule / question /
--     red_flag / ...), and its knowledge_type (clinical_method / medicine /
--     guideline_activity / reference).
--   • knowledge_type enforces the authority boundary: Hutchison is the HOW
--     TO ASSESS THE PATIENT authority (clinical method), NEVER a treatment or
--     drug-dosing authority.
--   • Claims are NOT paragraphs: a paragraph may yield many claims.
--   • source_claim.contract encodes the extraction contract — the standard
--     question set answered for every object compiled from this claim.
--   • PAGE CONVENTION: the raw PDF extraction / TOC carry 1-based PDF page
--     indices; printed book page numbers are offset by pdf_page_offset
--     (printed = pdf_index - offset). All page columns store PRINTED pages.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- source: a named authoritative source (book, guideline series)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source (
    source_id        text PRIMARY KEY,           -- e.g. HUTCHISON_CM
    source_name      text NOT NULL,
    edition          integer,
    year             integer,
    source_type      text NOT NULL
                     CHECK (source_type IN ('clinical_methods_text','textbook','guideline','journal','reference','protocol')),
    authority_scope  text,                       -- e.g. 'clinical method'
    amexan_role      text,                       -- e.g. HISTORY + EXAMINATION + CLINICAL COMMUNICATION
    description      text,
    publisher        text,
    language_code    text NOT NULL DEFAULT 'en',
    status           text NOT NULL DEFAULT 'ACTIVE_FOUNDATION'
                     CHECK (status IN ('ACTIVE_FOUNDATION','active','deprecated','superseded')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.source IS 'A named authoritative source compiled into AMEXAN knowledge.';

-- ---------------------------------------------------------------------------
-- source_version: a concrete edition/version of the source
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_version (
    version_id       text PRIMARY KEY,           -- e.g. HUTCHISON_24_2018
    source_id        text NOT NULL REFERENCES knowledge.source(source_id) ON DELETE CASCADE,
    edition          integer NOT NULL,
    publication_year integer NOT NULL,
    language         text NOT NULL DEFAULT 'English',
    supersedes       text REFERENCES knowledge.source_version(version_id),
    effective_from   date,
    status           text NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE','active','deprecated','superseded')),
    pdf_page_offset  integer NOT NULL DEFAULT 11,  -- printed = pdf_index - offset
    page_count       integer,
    file_path        text,                       -- original file location
    checksum         text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.source_version IS 'A concrete edition/version of a source.';

-- ---------------------------------------------------------------------------
-- source_section: top-level part of the source (the AMEXAN layer map)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_section (
    section_id       text PRIMARY KEY,           -- e.g. H1-S1
    source_version_id text NOT NULL REFERENCES knowledge.source_version(version_id) ON DELETE CASCADE,
    section_no       integer,                    -- 1..4 (NULL for the Index)
    section_name     text NOT NULL,
    amexan_layer     text NOT NULL               -- UNIVERSAL / CONTEXT / SYSTEM / NAVIGATION_ONLY
                     CHECK (amexan_layer IN ('UNIVERSAL','CONTEXT','SYSTEM','NAVIGATION_ONLY')),
    sort_order       integer NOT NULL DEFAULT 0,
    UNIQUE (source_version_id, section_name)
);
COMMENT ON TABLE knowledge.source_section IS 'Top-level part of the source; each maps to one AMEXAN knowledge layer.';

-- ---------------------------------------------------------------------------
-- source_chapter: a chapter of the source version
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_chapter (
    chapter_id       text PRIMARY KEY,           -- e.g. H1-C01
    source_version_id text NOT NULL REFERENCES knowledge.source_version(version_id) ON DELETE CASCADE,
    section_id       text NOT NULL REFERENCES knowledge.source_section(section_id),
    chapter_no       integer NOT NULL,
    chapter_name     text NOT NULL,
    start_page       integer,                    -- printed book page (inclusive)
    end_page         integer,                    -- printed book page (inclusive)
    amexan_role      text,                       -- HISTORY_ENGINE / EXAM_ENGINE / REASONING_INTERFACE / ETHICS_ENGINE (section 1)
    amexan_context   text,                       -- FEMALE_OBG / PAEDIATRIC / GERIATRIC / PSYCHIATRIC / EMERGENCY / FEVER_PRESENTATION / PAIN_PRESENTATION (section 2)
    amexan_system    text,                       -- RESPIRATORY / CARDIOVASCULAR / ... / ENT (section 3)
    sort_order       integer NOT NULL DEFAULT 0,
    UNIQUE (source_version_id, chapter_no)
);
COMMENT ON TABLE knowledge.source_chapter IS 'A chapter of the source version; the unit that claims and extractions hang off.';

CREATE INDEX idx_source_chapter_section ON knowledge.source_chapter(section_id);

-- ---------------------------------------------------------------------------
-- source_chunk: a page-anchored fragment of raw extracted text (READ layer)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_chunk (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_version_id text NOT NULL REFERENCES knowledge.source_version(version_id) ON DELETE CASCADE,
    chapter_id       text NOT NULL REFERENCES knowledge.source_chapter(chapter_id) ON DELETE CASCADE,
    page_number      integer NOT NULL,           -- printed page number
    pdf_page_index   integer,                    -- 1-based index in the original PDF
    chunk_index      integer NOT NULL DEFAULT 0, -- order within the page
    chunk_text       text NOT NULL,
    char_count       integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE knowledge.source_chunk IS 'Raw extracted text fragment anchored to a printed page. This is the READ layer: what the source literally says.';

CREATE INDEX idx_source_chunk_chapter_page ON knowledge.source_chunk(chapter_id, page_number);
CREATE INDEX idx_source_chunk_version ON knowledge.source_chunk(source_version_id);

-- ---------------------------------------------------------------------------
-- source_claim: an atomic, provenance-ready knowledge statement from a chunk
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_claim (
    claim_id         text PRIMARY KEY,           -- e.g. HC-000001
    claim_code       text NOT NULL UNIQUE,       -- e.g. HCH1-0001 (stable authoring code)
    source_version_id text NOT NULL REFERENCES knowledge.source_version(version_id) ON DELETE CASCADE,
    chapter_id       text NOT NULL REFERENCES knowledge.source_chapter(chapter_id),
    chunk_id         uuid REFERENCES knowledge.source_chunk(id) ON DELETE SET NULL,
    page_start       integer,                    -- printed page (inclusive)
    page_end         integer,                    -- printed page (inclusive)
    claim_type       text NOT NULL,              -- CLINICAL_METHOD / QUESTIONING_PRINCIPLE / EXAMINATION_PRINCIPLE / REASONING_PRINCIPLE / RESPIRATORY_METHOD / ...
    claim_kind       text NOT NULL               -- definition / rule / question / red_flag / differential / examination / investigation / threshold / contraindication / principle / risk_factor / history_section
                     CHECK (claim_kind IN ('definition','rule','question','red_flag','differential','examination','investigation','threshold','contraindication','principle','risk_factor','history_section','management','prognosis')),
    claim_text       text NOT NULL,              -- one atomic, verbatim-grounded claim
    knowledge_type   text NOT NULL DEFAULT 'clinical_method'
                     CHECK (knowledge_type IN ('clinical_method','medicine','guideline_activity','reference')),
    contract         jsonb,                      -- the extraction contract (WHAT IS IT / WHY / WHEN APPLIES / WHAT CONNECTS TO / WHAT FACT PRODUCES / WHAT ACTIVATES IT / WHAT CHANGES / WHERE DOCUMENTED / WHAT INFLUENCES / SOURCE SUPPORT / WHO APPROVED / WHEN EFFECTIVE)
    extracted_object_id uuid,                    -- backlink once H2+ compiles this claim into an AMEXAN object
    confidence       numeric(3,2) NOT NULL DEFAULT 0.9
                     CHECK (confidence BETWEEN 0 AND 1),
    is_compiled      boolean NOT NULL DEFAULT false,  -- has an operational object been produced from it?
    status           text NOT NULL DEFAULT 'VERIFIED'
                     CHECK (status IN ('VERIFIED','active','pending','superseded','rejected')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.source_claim IS 'An atomic knowledge claim extracted from a source chunk. The unit of compilation.';

CREATE INDEX idx_source_claim_chapter ON knowledge.source_claim(chapter_id);
CREATE INDEX idx_source_claim_type ON knowledge.source_claim(claim_type);
CREATE INDEX idx_source_claim_kind ON knowledge.source_claim(claim_kind);
CREATE TRIGGER trg_knowledge_source_claim_updated_at
   BEFORE UPDATE ON knowledge.source_claim
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- extraction_job: per-chapter extraction/review tracking
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.extraction_job (
    extraction_id    text PRIMARY KEY,           -- e.g. EXT-H01
    source_version_id text NOT NULL REFERENCES knowledge.source_version(version_id) ON DELETE CASCADE,
    chapter_id       text NOT NULL REFERENCES knowledge.source_chapter(chapter_id),
    extraction_type  text NOT NULL,              -- CLINICAL_METHOD / EXAMINATION / DIFFERENTIAL_INTERFACE / ETHICS / <CONTEXT>_CONTEXT / <SYSTEM>_METHOD
    status           text NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING','IN_PROGRESS','REVIEWED','APPROVED','REJECTED','DONE')),
    reviewed_by      uuid,
    reviewed_at      timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (source_version_id, chapter_id)
);
COMMENT ON TABLE knowledge.extraction_job IS 'Tracks per-chapter extraction and human review of the compiled source.';

-- ---------------------------------------------------------------------------
-- provenance: the bridge from COMPILED AMEXAN objects back to source claims
-- ---------------------------------------------------------------------------
-- A single AMEXAN operational object (question, fact, symptom, phenotype,
-- condition, documentation_rule, ...) may be derived from many claims, and
-- one claim may feed many objects. provenance records each derivation edge.
CREATE TABLE IF NOT EXISTS knowledge.provenance (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id       text NOT NULL REFERENCES knowledge.source_claim(claim_id) ON DELETE CASCADE,
    object_type    text NOT NULL,              -- question / fact / symptom / concept / phenotype / condition / rule / documentation_group / ...
    object_id      uuid NOT NULL,              -- id of the operational object (polymorphic)
    object_code    text,                       -- human-readable code (e.g. COUGH_PRESENT) for audits
    relationship   text NOT NULL DEFAULT 'derived_from'
                   CHECK (relationship IN ('derived_from','refined_by','corroborated_by','supersedes')),
    weight         numeric(3,2) NOT NULL DEFAULT 1.0,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (claim_id, object_type, object_id)
);
COMMENT ON TABLE knowledge.provenance IS 'Derivation edges from source claims to compiled AMEXAN objects.';
