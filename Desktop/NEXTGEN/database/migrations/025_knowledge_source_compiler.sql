-- =============================================================================
-- AMEXAN Medical Knowledge Compiler — H1: source-knowledge layer
-- =============================================================================
-- The Medical Knowledge Compiler turns authoritative sources (textbooks,
-- guidelines) into structured, provenance-backed AMEXAN knowledge. This
-- migration builds the SOURCE side of the pipeline only — the raw material
-- from which operational knowledge (symptom/question/fact/phenotype/...) is
-- compiled:
--
--   source -> source_document -> source_edition -> source_chapter
--          -> source_section -> source_chunk -> source_claim
--
-- and the bridge that ties compiled operational objects back to the exact
-- source claims that support them: knowledge.provenance.
--
-- Design rules (from the compiler contract):
--   • source_knowledge is a SEPARATE layer from operational knowledge.
--     Nothing here is directly consumed by the CPU; it exists to be compiled.
--   • Every claim is atomic and carries its source page range, its kind
--     (definition / rule / question / red_flag / differential / examination /
--     investigation / threshold / contraindication / principle), and its
--     knowledge type (clinical_method / medicine / guideline_activity).
--   • Claims are NOT paragraphs: a paragraph may yield many claims.
--   • source_claim.contract encodes the extraction contract — the standard
--     question set answered for every object compiled from this claim.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- source: a named authoritative source (book, guideline series)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_code   text NOT NULL UNIQUE,        -- e.g. SRC-HUTCHISON-2018
    title         text NOT NULL,
    source_type   text NOT NULL DEFAULT 'textbook'
                  CHECK (source_type IN ('textbook','guideline','journal','reference','protocol')),
    authority_type text NOT NULL DEFAULT 'clinical_method'
                  CHECK (authority_type IN ('clinical_method','medicine','guideline_activity','reference')),
    description   text,
    publisher     text,
    language_code text NOT NULL DEFAULT 'en',
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated','superseded')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.source IS 'A named authoritative source compiled into AMEXAN knowledge.';

-- ---------------------------------------------------------------------------
-- source_document: a concrete edition/volume of the source
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_document (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id        uuid NOT NULL REFERENCES knowledge.source(id) ON DELETE CASCADE,
    document_code    text NOT NULL UNIQUE,     -- e.g. DOC-HUTCHISON-24E
    title            text NOT NULL,
    edition_label    text,                     -- "24th edition"
    year             integer,
    isbn             text,
    page_count       integer,
    file_path        text,                     -- original file location
    checksum         text,
    status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active','deprecated')),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.source_document IS 'A concrete edition of a source.';

-- ---------------------------------------------------------------------------
-- source_chapter: top-level chapter of a document
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_chapter (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id    uuid NOT NULL REFERENCES knowledge.source_document(id) ON DELETE CASCADE,
    chapter_number text NOT NULL,
    chapter_title  text NOT NULL,
    chapter_type   text NOT NULL DEFAULT 'system'
                   CHECK (chapter_type IN ('general','group','system','reference','appendix','index')),
    start_page     integer,
    end_page       integer,
    sort_order     integer NOT NULL DEFAULT 0,
    UNIQUE (document_id, chapter_number)
);
COMMENT ON TABLE knowledge.source_chapter IS 'A chapter of the source document.';

-- ---------------------------------------------------------------------------
-- source_section: hierarchical sub-section within a chapter (from the TOC)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_section (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id     uuid NOT NULL REFERENCES knowledge.source_chapter(id) ON DELETE CASCADE,
    parent_section_id uuid REFERENCES knowledge.source_section(id) ON DELETE CASCADE,
    section_number text NOT NULL,              -- dotted path: 1.2.3
    section_title  text NOT NULL,
    depth          integer NOT NULL DEFAULT 1,
    start_page     integer,
    sort_order     integer NOT NULL DEFAULT 0,
    UNIQUE (chapter_id, section_number)
);
COMMENT ON TABLE knowledge.source_section IS 'Hierarchical section within a chapter (the book TOC).';

-- ---------------------------------------------------------------------------
-- source_chunk: a page-anchored fragment of raw extracted text
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_chunk (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id     uuid REFERENCES knowledge.source_section(id) ON DELETE CASCADE,
    chapter_id     uuid NOT NULL REFERENCES knowledge.source_chapter(id) ON DELETE CASCADE,
    page_number    integer NOT NULL,           -- printed page number
    pdf_page_index integer,                    -- 1-based index in the original PDF
    chunk_index    integer NOT NULL DEFAULT 0, -- order within the page
    chunk_text     text NOT NULL,
    char_count     integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE knowledge.source_chunk IS 'Raw extracted text fragment anchored to a page. This is the READ layer: what the source literally says.';

CREATE INDEX idx_source_chunk_chapter_page ON knowledge.source_chunk(chapter_id, page_number);
CREATE INDEX idx_source_chunk_section ON knowledge.source_chunk(section_id);

-- ---------------------------------------------------------------------------
-- source_claim: an atomic, provenance-ready knowledge statement from a chunk
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.source_claim (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    chunk_id       uuid REFERENCES knowledge.source_chunk(id) ON DELETE CASCADE,
    claim_code     text NOT NULL UNIQUE,       -- e.g. HCH1-CLAIM-0001
    claim_text     text NOT NULL,              -- one atomic, verbatim-grounded claim
    claim_kind     text NOT NULL               -- definition / rule / question / red_flag / differential / examination / investigation / threshold / contraindication / principle / risk_factor / history_section
                  CHECK (claim_kind IN ('definition','rule','question','red_flag','differential','examination','investigation','threshold','contraindication','principle','risk_factor','history_section','management','prognosis')),
                  -- knowledge_type: what layer of the compiler this feeds
    knowledge_type text NOT NULL DEFAULT 'clinical_method'
                  CHECK (knowledge_type IN ('clinical_method','medicine','guideline_activity','reference')),
    contract       jsonb,                      -- the extraction contract (WHAT IS IT / WHY / WHEN APPLIES / WHAT CONNECTS TO / WHAT FACT PRODUCES / WHAT ACTIVATES IT / WHAT CHANGES / WHERE DOCUMENTED / WHAT INFLUENCES / SOURCE SUPPORT / WHO APPROVED / WHEN EFFECTIVE)
    confidence     numeric(3,2) NOT NULL DEFAULT 0.8
                  CHECK (confidence BETWEEN 0 AND 1),
    is_compiled    boolean NOT NULL DEFAULT false,  -- has an operational object been produced from it?
    status         text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','rejected')),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE knowledge.source_claim IS 'An atomic knowledge claim extracted from a source chunk. The unit of compilation.';

CREATE INDEX idx_source_claim_kind ON knowledge.source_claim(claim_kind);
CREATE INDEX idx_source_claim_type ON knowledge.source_claim(knowledge_type);
CREATE TRIGGER trg_knowledge_source_claim_updated_at
   BEFORE UPDATE ON knowledge.source_claim
   FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- provenance: the bridge from COMPILED AMEXAN objects back to source claims
-- ---------------------------------------------------------------------------
-- A single AMEXAN operational object (question, fact, symptom, phenotype,
-- condition, documentation_rule, ...) may be derived from many claims, and
-- one claim may feed many objects. provenance records each derivation edge.
CREATE TABLE IF NOT EXISTS knowledge.provenance (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id       uuid NOT NULL REFERENCES knowledge.source_claim(id) ON DELETE CASCADE,
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
