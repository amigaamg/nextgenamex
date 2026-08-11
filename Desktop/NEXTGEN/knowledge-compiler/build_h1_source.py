"""AMEXAN Medical Knowledge Compiler — H1 source-map build (locked spec).

Reads the extracted Hutchison full text + TOC and emits a PostgreSQL seed file
populating the source-knowledge layer, faithful to the locked H1 spec:

    SOURCE (HUTCHISON_CM)
      -> VERSION (HUTCHISON_24_2018)
      -> SECTION (H1-S1..H1-S4)   [UNIVERSAL / CONTEXT / SYSTEM / NAVIGATION_ONLY]
      -> CHAPTER (H1-C01..H1-C21) [AMEXAN role / context / system]
      -> CHUNK  (raw page text, PRINTED page numbers)
      -> EXTRACTION_JOB (EXT-H01..EXT-H21, PENDING)

PAGE CONVENTION: the extracted text/TOC carry 1-based PDF page indices. The
book's printed page numbers are offset by 11 (printed = pdf_index - 11, see
compiler_core.PAGE_OFFSET). All page columns store PRINTED pages.

Run:  python build_h1_source.py <toc.txt> <full.txt> <output.sql>

Deterministic ids (uuid5) make the output idempotent across runs.
"""
from __future__ import annotations

import sys

from compiler_core import PAGE_OFFSET, printed_page, sql_literal, stable_uuid
from hutchison_toc import parse_toc
from hutchison_chunk import build_chunks, parse_pages

SOURCE_CODE = "HUTCHISON_CM"
VERSION_CODE = "HUTCHISON_24_2018"

# chapter_no -> (chapter_id, chapter_name, amexan_role, amexan_context, amexan_system)
CHAPTER_META: dict[int, tuple[str, str, str | None, str | None, str | None]] = {
    1: ("H1-C01", "Doctor and patient: General principles of history taking", "HISTORY_ENGINE", None, None),
    2: ("H1-C02", "General patient examination and differential diagnosis", "EXAM_ENGINE", None, None),
    3: ("H1-C03", "The next steps: Differential diagnosis and initial management", "REASONING_INTERFACE", None, None),
    4: ("H1-C04", "Ethical considerations", "ETHICS_ENGINE", None, None),
    5: ("H1-C05", "Women", None, "FEMALE_OBG", None),
    6: ("H1-C06", "Children and adolescents", None, "PAEDIATRIC", None),
    7: ("H1-C07", "Older people", None, "GERIATRIC", None),
    8: ("H1-C08", "Psychiatric assessment", None, "PSYCHIATRIC", None),
    9: ("H1-C09", "Patients presenting as emergencies", None, "EMERGENCY", None),
    10: ("H1-C10", "Patients with a fever", None, "FEVER_PRESENTATION", None),
    11: ("H1-C11", "Patients in pain", None, "PAIN_PRESENTATION", None),
    12: ("H1-C12", "Respiratory system", None, None, "RESPIRATORY"),
    13: ("H1-C13", "Cardiovascular system", None, None, "CARDIOVASCULAR"),
    14: ("H1-C14", "Gastrointestinal system", None, None, "GASTROINTESTINAL"),
    15: ("H1-C15", "Locomotor system", None, None, "LOCOMOTOR"),
    16: ("H1-C16", "Nervous system", None, None, "NEUROLOGICAL"),
    17: ("H1-C17", "Urogenital system", None, None, "UROGENITAL"),
    18: ("H1-C18", "Endocrine and metabolic disorders", None, None, "ENDOCRINE_METABOLIC"),
    19: ("H1-C19", "Skin, nails and hair", None, None, "DERMATOLOGY"),
    20: ("H1-C20", "Eyes", None, None, "OPHTHALMOLOGY"),
    21: ("H1-C21", "Ear, nose and throat", None, None, "ENT"),
}

# chapter_no -> section_id
SECTION_OF_CHAPTER: dict[int, str] = {
    **{n: "H1-S1" for n in range(1, 5)},
    **{n: "H1-S2" for n in range(5, 12)},
    **{n: "H1-S3" for n in range(12, 22)},
}

# section_id -> (section_no, section_name, amexan_layer)
SECTION_META: list[tuple[str, int | None, str, str]] = [
    ("H1-S1", 1, "General patient assessment", "UNIVERSAL"),
    ("H1-S2", 2, "Assessment in particular groups", "CONTEXT"),
    ("H1-S3", 3, "Basic systems", "SYSTEM"),
    ("H1-S4", None, "Index", "NAVIGATION_ONLY"),
]

# chapter_no -> extraction_type
EXTRACTION_TYPE: dict[int, str] = {
    1: "CLINICAL_METHOD",
    2: "EXAMINATION",
    3: "DIFFERENTIAL_INTERFACE",
    4: "ETHICS",
    5: "FEMALE_CONTEXT",
    6: "PAEDIATRIC_CONTEXT",
    7: "GERIATRIC_CONTEXT",
    8: "PSYCHIATRIC_CONTEXT",
    9: "EMERGENCY_CONTEXT",
    10: "FEVER_CONTEXT",
    11: "PAIN_CONTEXT",
    12: "RESPIRATORY_METHOD",
    13: "CARDIOVASCULAR_METHOD",
    14: "GASTROINTESTINAL_METHOD",
    15: "LOCOMOTOR_METHOD",
    16: "NEUROLOGICAL_METHOD",
    17: "UROGENITAL_METHOD",
    18: "ENDOCRINE_METABOLIC_METHOD",
    19: "DERMATOLOGY_METHOD",
    20: "OPHTHALMOLOGY_METHOD",
    21: "ENT_METHOD",
}


def chunk_seed(chapter_id: str, page: int, chunk_index: int) -> str:
    return f"{VERSION_CODE}:chapter:{chapter_id}:page:{page}:chunk:{chunk_index}"


def main(toc_path: str, text_path: str, out_path: str) -> None:
    chapters = parse_toc(toc_path)
    raw = open(text_path, encoding="utf-8").read()
    pages = parse_pages(raw)

    # printed-space chapter ranges keyed by chapter_id
    chapter_ranges = []
    for c in chapters:
        n = int(c.number)
        if n not in CHAPTER_META:
            continue
        chapter_ranges.append((CHAPTER_META[n][0], printed_page(c.page), printed_page(c.next_page)))
    mapping = {}
    for cid, start, end in chapter_ranges:
        for p in range(start, end):
            mapping[p] = cid

    chunks = build_chunks(pages, mapping, {})

    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler — H1 source-map seed (Hutchison 24e)")
    w("-- LOCKED H1 SPEC: source -> version -> section -> chapter -> chunk + extraction_job")
    w("-- GENERATED FILE — do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_h1_source.py <toc> <text> <out>")
    w("-- Page convention: all page columns are PRINTED book pages (pdf_index - 11).")
    w("-- =============================================================================")
    w("")

    # source
    w("-- -----------------------------------------------------------------------------")
    w("-- source")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source (source_id, source_name, edition, year, source_type, authority_scope, amexan_role, description, publisher, language_code, status) VALUES")
    w("   ('HUTCHISON_CM', 'Hutchison''s Clinical Methods', 24, 2018, 'clinical_methods_text', 'clinical method', 'HISTORY + EXAMINATION + CLINICAL COMMUNICATION', 'Clinical methods foundation: how to elicit, organise and document history, examination and differential diagnosis.', 'Elsevier', 'en', 'ACTIVE_FOUNDATION')")
    w("ON CONFLICT (source_id) DO UPDATE SET source_name = EXCLUDED.source_name, edition = EXCLUDED.edition, year = EXCLUDED.year, source_type = EXCLUDED.source_type, authority_scope = EXCLUDED.authority_scope, amexan_role = EXCLUDED.amexan_role;")
    w("")

    # source_version
    w("-- -----------------------------------------------------------------------------")
    w("-- source_version")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_version (version_id, source_id, edition, publication_year, language, supersedes, effective_from, status, pdf_page_offset, page_count) VALUES")
    w("   ('HUTCHISON_24_2018', 'HUTCHISON_CM', 24, 2018, 'English', NULL, '2018-01-01', 'ACTIVE', 11, 499)")
    w("ON CONFLICT (version_id) DO UPDATE SET source_id = EXCLUDED.source_id, edition = EXCLUDED.edition, publication_year = EXCLUDED.publication_year, effective_from = EXCLUDED.effective_from, pdf_page_offset = EXCLUDED.pdf_page_offset, page_count = EXCLUDED.page_count;")
    w("")

    # sections
    w("-- -----------------------------------------------------------------------------")
    w("-- source_section")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_section (section_id, source_version_id, section_no, section_name, amexan_layer, sort_order) VALUES")
    srows = []
    for i, (sid, no, name, layer) in enumerate(SECTION_META, start=1):
        srows.append(f"   ({sql_literal(sid)}, {sql_literal(VERSION_CODE)}, {sql_literal(no)}, {sql_literal(name)}, {sql_literal(layer)}, {sql_literal(i)})")
    w(",\n".join(srows))
    w("ON CONFLICT (source_version_id, section_name) DO UPDATE SET section_no = EXCLUDED.section_no, amexan_layer = EXCLUDED.amexan_layer;")
    w("")

    # chapters
    w("-- -----------------------------------------------------------------------------")
    w("-- source_chapter")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_chapter (chapter_id, source_version_id, section_id, chapter_no, chapter_name, start_page, end_page, amexan_role, amexan_context, amexan_system, sort_order) VALUES")
    crows = []
    for c in chapters:
        n = int(c.number)
        meta = CHAPTER_META.get(n)
        if not meta:
            continue
        cid, cname, role, context, system = meta
        start = printed_page(c.page)
        end = printed_page(c.next_page) - 1
        crows.append(
            f"   ({sql_literal(cid)}, {sql_literal(VERSION_CODE)}, {sql_literal(SECTION_OF_CHAPTER[n])}, {sql_literal(n)}, {sql_literal(cname)}, {sql_literal(start)}, {sql_literal(end)}, {sql_literal(role)}, {sql_literal(context)}, {sql_literal(system)}, {sql_literal(c.sort_order)})"
        )
    w(",\n".join(crows))
    w("ON CONFLICT (source_version_id, chapter_no) DO UPDATE SET chapter_name = EXCLUDED.chapter_name, start_page = EXCLUDED.start_page, end_page = EXCLUDED.end_page, amexan_role = EXCLUDED.amexan_role, amexan_context = EXCLUDED.amexan_context, amexan_system = EXCLUDED.amexan_system;")
    w("")

    # chunks
    w("-- -----------------------------------------------------------------------------")
    w("-- source_chunk  (page-anchored raw text, printed page numbers)")
    w("-- -----------------------------------------------------------------------------")
    chunk_rows = []
    for chk in chunks:
        cid = stable_uuid(chunk_seed(chk["chapter_number"], chk["page"], chk["chunk_index"]))
        chunk_rows.append(
            f"   ({sql_literal(str(cid))}, {sql_literal(VERSION_CODE)}, {sql_literal(chk['chapter_number'])}, {sql_literal(chk['page'])}, {sql_literal(chk['pdf_index'])}, {sql_literal(chk['chunk_index'])}, {sql_literal(chk['text'])}, {sql_literal(len(chk['text']))})"
        )
    w("INSERT INTO knowledge.source_chunk (id, source_version_id, chapter_id, page_number, pdf_page_index, chunk_index, chunk_text, char_count) VALUES")
    w(",\n".join(chunk_rows))
    w("ON CONFLICT (id) DO UPDATE SET chunk_text = EXCLUDED.chunk_text, char_count = EXCLUDED.char_count;")
    w("")

    # extraction jobs
    w("-- -----------------------------------------------------------------------------")
    w("-- extraction_job  (per-chapter extraction/review tracking)")
    w("-- -----------------------------------------------------------------------------")
    w("INSERT INTO knowledge.extraction_job (extraction_id, source_version_id, chapter_id, extraction_type, status) VALUES")
    erows = []
    for n, cid in sorted((int(k), v[0]) for k, v in CHAPTER_META.items()):
        erows.append(f"   ({sql_literal(f'EXT-H{n:02d}')}, {sql_literal(VERSION_CODE)}, {sql_literal(cid)}, {sql_literal(EXTRACTION_TYPE[n])}, 'PENDING')")
    w(",\n".join(erows))
    w("ON CONFLICT (extraction_id) DO UPDATE SET extraction_type = EXCLUDED.extraction_type;")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(chapter_ranges)} chapters, {len(chunks)} chunks, {len(erows)} extraction jobs")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
