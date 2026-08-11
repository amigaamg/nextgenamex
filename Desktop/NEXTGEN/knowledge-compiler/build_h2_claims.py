"""AMEXAN Medical Knowledge Compiler — claim build.

Resolves each curated claim to its source chunk (chapter_id + printed page) and
emits a PostgreSQL seed inserting knowledge.source_claim rows, grounded to
chunks and carrying the locked-H1 identifiers:

    claim_id HC-000001..  |  claim_code HCH1-0001..  |  chapter_id H1-C01..

Run:  python build_h2_claims.py <toc> <full> <out.sql>
"""
from __future__ import annotations

import json
import sys

from compiler_core import printed_page, sql_literal, stable_uuid
from claims_hutchison import CLAIMS
from hutchison_chunk import build_chunks, parse_pages
from hutchison_toc import parse_toc

SOURCE_CODE = "HUTCHISON_CM"
VERSION_CODE = "HUTCHISON_24_2018"


def chapter_id_of(chapter: str) -> str:
    return f"H1-C{int(chapter):02d}"


def chunk_for(chunks: list[dict], chapter_id: str, page: int):
    """Find the chunk for (chapter_id, printed page)."""
    for c in chunks:
        if c["chapter_number"] == chapter_id and c["page"] == page:
            return c
    return None


def chunk_seed(chapter_id: str, page: int, chunk_index: int) -> str:
    return f"{VERSION_CODE}:chapter:{chapter_id}:page:{page}:chunk:{chunk_index}"


def main(toc_path: str, text_path: str, out_path: str) -> None:
    chapters = parse_toc(toc_path)
    raw = open(text_path, encoding="utf-8").read()
    pages = parse_pages(raw)

    # printed-space chapter ranges keyed by chapter_id
    chapter_ranges = []
    for c in chapters:
        try:
            n = int(c.number)
        except ValueError:
            continue
        if not (1 <= n <= 21):
            continue
        chapter_ranges.append((chapter_id_of(c.number), printed_page(c.page), printed_page(c.next_page)))
    mapping = {}
    for cid, start, end in chapter_ranges:
        for p in range(start, end):
            mapping[p] = cid

    chunks = build_chunks(pages, mapping, {})

    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler — H1 source_claim seed (Hutchison 24e)")
    w("-- LOCKED H1 SPEC: claim_id HC-xxxxxx, chapter_id H1-Cxx, printed pages, VERIFIED")
    w("-- GENERATED FILE — do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_h2_claims.py <toc> <text> <out>")
    w("-- =============================================================================")
    w("")
    w("INSERT INTO knowledge.source_claim (claim_id, claim_code, source_version_id, chapter_id, chunk_id, page_start, page_end, claim_type, claim_kind, claim_text, knowledge_type, contract, confidence, status) VALUES")

    rows = []
    missing = []
    for i, cl in enumerate(CLAIMS, start=1):
        claim_id = f"HC-{i:06d}"
        cid = chapter_id_of(cl["chapter"])
        page = int(cl["page"])
        chunk = chunk_for(chunks, cid, page)
        if chunk is None:
            missing.append(cl["code"])
            continue
        chunk_uuid = stable_uuid(chunk_seed(cid, page, chunk["chunk_index"]))
        contract_json = json.dumps(cl.get("contract", {}), ensure_ascii=False)
        rows.append(
            f"   ({sql_literal(claim_id)}, {sql_literal(cl['code'])}, {sql_literal(VERSION_CODE)}, {sql_literal(cid)}, {sql_literal(str(chunk_uuid))}, {sql_literal(page)}, {sql_literal(page)}, {sql_literal(cl['claim_type'])}, {sql_literal(cl['kind'])}, {sql_literal(cl['text'])}, {sql_literal(cl['type'])}, {sql_literal(contract_json)}::jsonb, 0.9, 'VERIFIED')"
        )

    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET chapter_id = EXCLUDED.chapter_id, page_start = EXCLUDED.page_start, page_end = EXCLUDED.page_end, claim_type = EXCLUDED.claim_type, claim_kind = EXCLUDED.claim_kind, claim_text = EXCLUDED.claim_text, contract = EXCLUDED.contract;")
    w("")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(rows)} claims; {len(missing)} ungrounded: {missing}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
