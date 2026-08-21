"""AMEXAN Medical Knowledge Compiler — R0 respiratory source registration.

Registers the respiratory vertical-slice sources in the SAME H1 source layer
(source -> version -> section -> chapter -> chunk + extraction_job) and emits a
PostgreSQL seed file. Nothing here is CPU-consumed knowledge yet — it is the
READ layer that the claim extractor (R1+) compiles from.

Two sources are registered:

  SOURCE: KUMAR_CLARK_CM        Kumar & Clark's Clinical Medicine, 10e (2017)
    -> VERSION: KUMAR_CLARK_10_2017   (pdf_page_offset 18)
    -> SECTION: KC-S1  Respiratory system            (SYSTEM)
    -> CHAPTER : KC-C28 Respiratory disease  printed 927-999  (RESPIRATORY)

  SOURCE: NELSON_ILLUSTRATED    Illustrated Baby Nelson, Dr Mohamed El Koumi (2017)
    -> VERSION: NELSON_ILLUSTRATED_2017 (pdf_page_offset 13)
    -> SECTION: BN-S1  Pulmonology                   (SYSTEM)
    -> CHAPTER : BN-C01 Pulmonology         printed 156-213  (RESPIRATORY + PAEDIATRIC)

PAGE CONVENTION: all page columns store PRINTED book pages
(printed = pdf_index - pdf_page_offset). Chunk ids are deterministic uuid5 so
the seed is idempotent across runs.

Run:
  python build_respiratory_sources.py <kumar_pdf> <baby_nelson_pdf> <output.sql>
"""
from __future__ import annotations

import sys

import fitz  # PyMuPDF

from compiler_core import clean_ws, sql_literal, stable_uuid

# ---------------------------------------------------------------------------
# Source catalogue — extend this to register more books in the same pipeline.
# ---------------------------------------------------------------------------
BOOKS = [
    {
        "pdf_path": None,  # filled from argv
        "source_id": "KUMAR_CLARK_CM",
        "source_name": "Kumar & Clark's Clinical Medicine",
        "edition": 10,
        "year": 2017,
        "source_type": "textbook",
        "authority_scope": "internal medicine",
        "amexan_role": "INTERPRET + MANAGE",
        "description": "Adult internal medicine textbook; respiratory disease chapter (28) forms the adult overlay of the respiratory vertical slice.",
        "publisher": "Elsevier",
        "version_id": "KUMAR_CLARK_10_2017",
        "publication_year": 2017,
        "pdf_page_offset": 18,
        "page_count": 1508,
        "section_id": "KC-S1",
        "section_name": "Respiratory system",
        "amexan_layer": "SYSTEM",
        "chapter_id": "KC-C28",
        "chapter_no": 28,
        "chapter_name": "Respiratory disease",
        "chapter_start_pdf": 945,   # printed 927
        "chapter_end_pdf": 1017,    # printed 999
        "amexan_context": None,
        "amexan_system": "RESPIRATORY",
        "extraction_id": "EXT-KC28",
        "extraction_type": "RESPIRATORY_METHOD",
    },
    {
        "pdf_path": None,  # filled from argv
        "source_id": "NELSON_ILLUSTRATED",
        "source_name": "Illustrated Baby Nelson",
        "edition": 1,
        "year": 2017,
        "source_type": "textbook",
        "authority_scope": "paediatrics",
        "amexan_role": "INTERPRET + MANAGE (PAEDIATRIC)",
        "description": "Illustrated paediatric revision text (Dr Mohamed El Koumi, 2017-2020); the Pulmonology chapter forms the paediatric overlay of the respiratory vertical slice.",
        "publisher": "University Book Center",
        "version_id": "NELSON_ILLUSTRATED_2017",
        "publication_year": 2017,
        "pdf_page_offset": 13,
        "page_count": 692,
        "section_id": "BN-S1",
        "section_name": "Pulmonology",
        "amexan_layer": "SYSTEM",
        "chapter_id": "BN-C01",
        "chapter_no": 1,
        "chapter_name": "Pulmonology",
        "chapter_start_pdf": 169,   # printed 156 (chapter opener at pdf 167)
        "chapter_end_pdf": 226,     # printed 213 (nephrology starts at pdf 227)
        "amexan_context": "PAEDIATRIC",
        "amexan_system": "RESPIRATORY",
        "extraction_id": "EXT-BN01",
        "extraction_type": "RESPIRATORY_METHOD",
    },
]


def extract_page_text(doc: fitz.Document, pdf_index: int) -> str:
    """Clean raw text for one 1-based PDF page (empty pages -> '')."""
    text = doc[pdf_index - 1].get_text()
    return clean_ws(text)


def chunk_seed(version_id: str, chapter_id: str, page: int, chunk_index: int) -> str:
    return f"{version_id}:chapter:{chapter_id}:page:{page}:chunk:{chunk_index}"


def main(kumar_pdf: str, nelson_pdf: str, out_path: str) -> None:
    paths = [kumar_pdf, nelson_pdf]
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler — R0 respiratory source map seed")
    w("-- SOURCE -> VERSION -> SECTION -> CHAPTER -> CHUNK + EXTRACTION_JOB")
    w("-- GENERATED FILE — do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_respiratory_sources.py <kumar.pdf> <baby_nelson.pdf> <out>")
    w("-- Page convention: all page columns are PRINTED book pages (pdf_index - offset).")
    w("-- =============================================================================")
    w("")

    total_chunks = 0
    for book, pdf_path in zip(BOOKS, paths):
        book["pdf_path"] = pdf_path
        doc = fitz.open(pdf_path)
        version_id = book["version_id"]
        section_id = book["section_id"]
        chapter_id = book["chapter_id"]
        offset = book["pdf_page_offset"]

        # source
        w("-- -----------------------------------------------------------------------------")
        w("-- source")
        w("-- -----------------------------------------------------------------------------")
        w("INSERT INTO knowledge.source (source_id, source_name, edition, year, source_type, authority_scope, amexan_role, description, publisher, language_code, status) VALUES")
        w(f"   ({sql_literal(book['source_id'])}, {sql_literal(book['source_name'])}, {sql_literal(book['edition'])}, {sql_literal(book['year'])}, {sql_literal(book['source_type'])}, {sql_literal(book['authority_scope'])}, {sql_literal(book['amexan_role'])}, {sql_literal(book['description'])}, {sql_literal(book['publisher'])}, 'en', 'ACTIVE_FOUNDATION')")
        w("ON CONFLICT (source_id) DO UPDATE SET source_name = EXCLUDED.source_name, edition = EXCLUDED.edition, year = EXCLUDED.year, source_type = EXCLUDED.source_type, authority_scope = EXCLUDED.authority_scope, amexan_role = EXCLUDED.amexan_role;")
        w("")

        # source_version
        w("-- -----------------------------------------------------------------------------")
        w("-- source_version")
        w("-- -----------------------------------------------------------------------------")
        w("INSERT INTO knowledge.source_version (version_id, source_id, edition, publication_year, language, supersedes, effective_from, status, pdf_page_offset, page_count, file_path) VALUES")
        w(f"   ({sql_literal(version_id)}, {sql_literal(book['source_id'])}, {sql_literal(book['edition'])}, {sql_literal(book['publication_year'])}, 'English', NULL, {sql_literal(str(book['publication_year']) + '-01-01')}, 'ACTIVE', {sql_literal(offset)}, {sql_literal(book['page_count'])}, {sql_literal(pdf_path)})")
        w("ON CONFLICT (version_id) DO UPDATE SET source_id = EXCLUDED.source_id, edition = EXCLUDED.edition, publication_year = EXCLUDED.publication_year, pdf_page_offset = EXCLUDED.pdf_page_offset, page_count = EXCLUDED.page_count;")
        w("")

        # section
        w("-- -----------------------------------------------------------------------------")
        w("-- source_section")
        w("-- -----------------------------------------------------------------------------")
        w("INSERT INTO knowledge.source_section (section_id, source_version_id, section_no, section_name, amexan_layer, sort_order) VALUES")
        w(f"   ({sql_literal(section_id)}, {sql_literal(version_id)}, 1, {sql_literal(book['section_name'])}, {sql_literal(book['amexan_layer'])}, 1)")
        w("ON CONFLICT (source_version_id, section_name) DO UPDATE SET amexan_layer = EXCLUDED.amexan_layer;")
        w("")

        # chapter
        start_print = book["chapter_start_pdf"] - offset
        end_print = book["chapter_end_pdf"] - offset
        w("-- -----------------------------------------------------------------------------")
        w("-- source_chapter")
        w("-- -----------------------------------------------------------------------------")
        w("INSERT INTO knowledge.source_chapter (chapter_id, source_version_id, section_id, chapter_no, chapter_name, start_page, end_page, amexan_role, amexan_context, amexan_system, sort_order) VALUES")
        w(f"   ({sql_literal(chapter_id)}, {sql_literal(version_id)}, {sql_literal(section_id)}, {sql_literal(book['chapter_no'])}, {sql_literal(book['chapter_name'])}, {sql_literal(start_print)}, {sql_literal(end_print)}, {sql_literal(book['amexan_role'])}, {sql_literal(book['amexan_context'])}, {sql_literal(book['amexan_system'])}, 1)")
        w("ON CONFLICT (source_version_id, chapter_no) DO UPDATE SET chapter_name = EXCLUDED.chapter_name, start_page = EXCLUDED.start_page, end_page = EXCLUDED.end_page, amexan_context = EXCLUDED.amexan_context, amexan_system = EXCLUDED.amexan_system;")
        w("")

        # chunks (one per PDF page, printed page numbers)
        chunk_rows = []
        for pdf_index in range(book["chapter_start_pdf"], book["chapter_end_pdf"] + 1):
            text = extract_page_text(doc, pdf_index)
            if not text:
                continue
            printed = pdf_index - offset
            cid = stable_uuid(chunk_seed(version_id, chapter_id, printed, 0))
            chunk_rows.append(
                f"   ({sql_literal(str(cid))}, {sql_literal(version_id)}, {sql_literal(chapter_id)}, {sql_literal(printed)}, {sql_literal(pdf_index)}, 0, {sql_literal(text)}, {sql_literal(len(text))})"
            )
            total_chunks += 1
        w("-- -----------------------------------------------------------------------------")
        w("-- source_chunk  (page-anchored raw text, printed page numbers)")
        w("-- -----------------------------------------------------------------------------")
        if chunk_rows:
            w("INSERT INTO knowledge.source_chunk (id, source_version_id, chapter_id, page_number, pdf_page_index, chunk_index, chunk_text, char_count) VALUES")
            w(",\n".join(chunk_rows))
            w("ON CONFLICT (id) DO UPDATE SET chunk_text = EXCLUDED.chunk_text, char_count = EXCLUDED.char_count;")
        w("")

        # extraction job
        w("-- -----------------------------------------------------------------------------")
        w("-- extraction_job")
        w("-- -----------------------------------------------------------------------------")
        w("INSERT INTO knowledge.extraction_job (extraction_id, source_version_id, chapter_id, extraction_type, status) VALUES")
        w(f"   ({sql_literal(book['extraction_id'])}, {sql_literal(version_id)}, {sql_literal(chapter_id)}, {sql_literal(book['extraction_type'])}, 'PENDING')")
        w("ON CONFLICT (extraction_id) DO UPDATE SET extraction_type = EXCLUDED.extraction_type;")
        w("")
        doc.close()

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(BOOKS)} sources, {total_chunks} chunks")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])