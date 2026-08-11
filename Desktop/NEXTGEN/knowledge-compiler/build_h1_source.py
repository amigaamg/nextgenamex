"""AMEXAN Medical Knowledge Compiler — H1 build.

Reads the extracted Hutchison full text + TOC and emits a PostgreSQL seed file
populating the source-knowledge layer:

    source -> source_document -> source_chapter -> source_section -> source_chunk

Run:  python build_h1_source.py <toc.txt> <full.txt> <output.sql>

Deterministic ids (uuid5) make the output idempotent across runs.
"""
from __future__ import annotations

import sys

from compiler_core import sql_literal, stable_uuid, text_hash
from hutchison_toc import Chapter, flatten_sections, parse_toc
from hutchison_chunk import build_chunks, parse_pages

SRC_CODE = "SRC-HUTCHISON-2018"
DOC_CODE = "DOC-HUTCHISON-24E"


def main(toc_path: str, text_path: str, out_path: str) -> None:
    chapters = parse_toc(toc_path)
    raw = open(text_path, encoding="utf-8").read()
    pages = parse_pages(raw)

    chapter_ranges = [(c.number, c.page, c.next_page) for c in chapters]
    mapping = {}
    for number, start, end in chapter_ranges:
        for p in range(start, end):
            mapping[p] = number

    # section start pages: printed_page -> [(section_number, title, depth)]
    section_pages: dict[int, list[tuple[str, str, int]]] = {}
    for ch, sec in flatten_sections(chapters):
        section_pages.setdefault(sec.page, []).append((sec.number, sec.title, sec.depth))

    chunks = build_chunks(pages, mapping, section_pages)

    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler — H1 source-knowledge seed (Hutchison 24e)")
    w("-- GENERATED FILE — do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_h1_source.py <toc> <text> <out>")
    w("-- =============================================================================")
    w("")
    w("-- -----------------------------------------------------------------------------")
    w("-- source + source_document")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source (id, source_code, title, source_type, authority_type, description, publisher, language_code, status) VALUES")
    w(f"   ({sql_literal(str(stable_uuid(SRC_CODE)))}, {sql_literal(SRC_CODE)}, 'Hutchison''s Clinical Methods', 'textbook', 'clinical_method', 'Clinical methods foundation: how to elicit, organise and document history, examination and differential diagnosis.', 'Elsevier', 'en', 'active')")
    w("ON CONFLICT (source_code) DO UPDATE SET description = EXCLUDED.description;")
    w("")
    w("INSERT INTO knowledge.source_document (id, source_id, document_code, title, edition_label, year, page_count, status) VALUES")
    w(f"   ({sql_literal(str(stable_uuid(DOC_CODE)))}, {sql_literal(str(stable_uuid(SRC_CODE)))}, {sql_literal(DOC_CODE)}, 'Hutchison''s Clinical Methods', '24th edition', 2018, 499, 'active')")
    w("ON CONFLICT (document_code) DO UPDATE SET edition_label = EXCLUDED.edition_label, year = EXCLUDED.year, page_count = EXCLUDED.page_count;")
    w("")

    # chapters
    w("-- -----------------------------------------------------------------------------")
    w("-- source_chapter")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_chapter (id, document_id, chapter_number, chapter_title, chapter_type, start_page, end_page, sort_order) VALUES")
    rows = []
    for c in chapters:
        ch_id = stable_uuid(f"{DOC_CODE}:chapter:{c.number}")
        doc_id = stable_uuid(DOC_CODE)
        ctype = chapter_type_for(c)
        end = c.next_page - 1
        rows.append(f"   ({sql_literal(str(ch_id))}, {sql_literal(str(doc_id))}, {sql_literal(c.number)}, {sql_literal(c.title)}, {sql_literal(ctype)}, {sql_literal(c.page)}, {sql_literal(end)}, {sql_literal(c.sort_order)})")
    w(",\n".join(rows))
    w("ON CONFLICT (document_id, chapter_number) DO UPDATE SET chapter_title = EXCLUDED.chapter_title, start_page = EXCLUDED.start_page, end_page = EXCLUDED.end_page;")
    w("")

    # sections
    w("-- -----------------------------------------------------------------------------")
    w("-- source_section")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_section (id, chapter_id, parent_section_id, section_number, section_title, depth, start_page, sort_order) VALUES")
    srows = []
    for ch, sec in flatten_sections(chapters):
        sid = stable_uuid(f"{DOC_CODE}:chapter:{ch.number}:section:{sec.number}")
        cid = stable_uuid(f"{DOC_CODE}:chapter:{ch.number}")
        parent = None
        if sec.depth > 1:
            parent_num = sec.number.rsplit(".", 1)[0]
            parent = stable_uuid(f"{DOC_CODE}:chapter:{ch.number}:section:{parent_num}")
        srows.append(f"   ({sql_literal(str(sid))}, {sql_literal(str(cid))}, {sql_literal(str(parent) if parent else None)}, {sql_literal(sec.number)}, {sql_literal(sec.title)}, {sql_literal(sec.depth)}, {sql_literal(sec.page)}, {sql_literal(sec.sort_order)})")
    w(",\n".join(srows))
    w("ON CONFLICT (chapter_id, section_number) DO UPDATE SET section_title = EXCLUDED.section_title, depth = EXCLUDED.depth, start_page = EXCLUDED.start_page;")
    w("")

    # chunks
    w("-- -----------------------------------------------------------------------------")
    w("-- source_chunk  (page-anchored raw text)")
    w("-- -----------------------------------------------------------------------------")
    chunk_rows = []
    for chk in chunks:
        cid = stable_uuid(f"{DOC_CODE}:chapter:{chk['chapter_number']}:page:{chk['page']}:chunk:{chk['chunk_index']}")
        sid = None
        if chk.get("section_number"):
            sid = stable_uuid(f"{DOC_CODE}:chapter:{chk['chapter_number']}:section:{chk['section_number']}")
        chunk_rows.append(
            f"   ({sql_literal(str(cid))}, {sql_literal(str(sid) if sid else None)}, {sql_literal(str(cid_chapter(chk['chapter_number'], DOC_CODE)))}, {sql_literal(chk['page'])}, {sql_literal(chk['pdf_index'])}, {sql_literal(chk['chunk_index'])}, {sql_literal(chk['text'])}, {sql_literal(len(chk['text']))})"
        )
    w("INSERT INTO knowledge.source_chunk (id, section_id, chapter_id, page_number, pdf_page_index, chunk_index, chunk_text, char_count) VALUES")
    w(",\n".join(chunk_rows))
    w("ON CONFLICT (id) DO UPDATE SET chunk_text = EXCLUDED.chunk_text, char_count = EXCLUDED.char_count;")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(chapters)} chapters, {sum(len(_flatten(c.sections)) for c in chapters)} sections, {len(chunks)} chunks")


def cid_chapter(number: str, doc: str) -> str:
    return str(stable_uuid(f"{doc}:chapter:{number}"))


def chapter_type_for(c: Chapter) -> str:
    n = int(c.number)
    if 1 <= n <= 4:
        return "general"
    if 5 <= n <= 11:
        return "group"
    return "system"


def _flatten(sections):
    from hutchison_toc import _flatten as f
    return f(sections)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
