"""AMEXAN Medical Knowledge Compiler — claim build.

Resolves each curated claim to its source chunk (chapter + page) and emits a
PostgreSQL seed inserting knowledge.source_claim rows, grounded to chunks.

Run:  python build_h2_claims.py <toc> <full> <out.sql>
"""
from __future__ import annotations

import json
import sys

from compiler_core import sql_literal, stable_uuid
from claims_hutchison import CLAIMS
from hutchison_chunk import build_chunks, parse_pages
from hutchison_toc import parse_toc

SRC_CODE = "SRC-HUTCHISON-2018"
DOC_CODE = "DOC-HUTCHISON-24E"


def chunk_for(chunks: list[dict], chapter: str, page: int):
    """Find the chunk for (chapter, page)."""
    for c in chunks:
        if c["chapter_number"] == chapter and c["page"] == page:
            return c
    return None


def main(toc_path: str, text_path: str, out_path: str) -> None:
    chapters = parse_toc(toc_path)
    raw = open(text_path, encoding="utf-8").read()
    pages = parse_pages(raw)

    chapter_ranges = [(c.number, c.page, c.next_page) for c in chapters]
    mapping = {}
    for number, start, end in chapter_ranges:
        for p in range(start, end):
            mapping[p] = number
    from hutchison_chunk import build_chunks as bc
    chunks = build_chunks(pages, mapping, {})

    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler — H1 source_claim seed (Hutchison 24e)")
    w("-- GENERATED FILE — do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_h2_claims.py <toc> <text> <out>")
    w("-- =============================================================================")
    w("")
    w("INSERT INTO knowledge.source_claim (id, chunk_id, claim_code, claim_text, claim_kind, knowledge_type, contract, confidence) VALUES")

    rows = []
    missing = []
    for i, cl in enumerate(CLAIMS):
        claim_id = stable_uuid(f"{DOC_CODE}:claim:{cl['code']}")
        chunk = chunk_for(chunks, cl["chapter"], cl["page"])
        if chunk is None:
            missing.append(cl["code"])
            continue
        cid = stable_uuid(f"{DOC_CODE}:chapter:{cl['chapter']}:page:{cl['page']}:chunk:{chunk['chunk_index']}")
        contract_json = json.dumps(cl.get("contract", {}), ensure_ascii=False)
        rows.append(
            f"   ({sql_literal(str(claim_id))}, {sql_literal(str(cid))}, {sql_literal(cl['code'])}, {sql_literal(cl['text'])}, {sql_literal(cl['kind'])}, {sql_literal(cl['type'])}, {sql_literal(contract_json)}::jsonb, 0.9)"
        )

    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET claim_text = EXCLUDED.claim_text, claim_kind = EXCLUDED.claim_kind, contract = EXCLUDED.contract;")
    w("")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(rows)} claims; {len(missing)} ungrounded: {missing}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
