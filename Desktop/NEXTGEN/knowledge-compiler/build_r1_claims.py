"""AMEXAN Medical Knowledge Compiler — R1 respiratory claim build.

Resolves each curated R1 claim (claims_respiratory.py) to its source chunk and
emits a PostgreSQL seed inserting knowledge.source_claim rows grounded to the
R0 chunks (chapter_id + printed page) with deterministic uuid5 chunk ids:

    claim_id RC-000001.. | claim_code KCR-0001 / BNR-0001

Run:  python build_r1_claims.py <out.sql>
"""
from __future__ import annotations

import json
import sys

from claims_respiratory import CLAIMS
from compiler_core import sql_literal, stable_uuid

SOURCE_MAP = {
    "KC": {"version": "KUMAR_CLARK_10_2017", "chapter": "KC-C28"},
    "BN": {"version": "NELSON_ILLUSTRATED_2017", "chapter": "BN-C01"},
}


def chunk_seed(version_id: str, chapter_id: str, page: int) -> str:
    return f"{version_id}:chapter:{chapter_id}:page:{page}:chunk:0"


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler — R1 respiratory source_claim seed")
    w("-- KUMAR_CLARK_10_2017 (KC-C28) + NELSON_ILLUSTRATED_2017 (BN-C01)")
    w("-- Claim codes KCR-xxxx / BNR-xxxx, grounded to printed pages, status VERIFIED")
    w("-- GENERATED FILE — do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r1_claims.py <out>")
    w("-- =============================================================================")
    w("")
    w("INSERT INTO knowledge.source_claim (claim_id, claim_code, source_version_id, chapter_id, chunk_id, page_start, page_end, claim_type, claim_kind, claim_text, knowledge_type, contract, confidence, status) VALUES")

    rows = []
    missing = []
    for i, cl in enumerate(CLAIMS, start=1):
        src = SOURCE_MAP[cl["source"]]
        page = int(cl["page"])
        claim_id = f"RC-{i:06d}"
        chunk_uuid = stable_uuid(chunk_seed(src["version"], src["chapter"], page))
        contract_json = json.dumps(cl.get("contract", {}), ensure_ascii=False)
        rows.append(
            f"   ({sql_literal(claim_id)}, {sql_literal(cl['code'])}, {sql_literal(src['version'])}, {sql_literal(src['chapter'])}, {sql_literal(str(chunk_uuid))}, {sql_literal(page)}, {sql_literal(page)}, {sql_literal(cl['claim_type'])}, {sql_literal(cl['kind'])}, {sql_literal(cl['text'])}, {sql_literal(cl['type'])}, {sql_literal(contract_json)}::jsonb, 0.9, 'VERIFIED')"
        )

    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET chapter_id = EXCLUDED.chapter_id, page_start = EXCLUDED.page_start, page_end = EXCLUDED.page_end, claim_type = EXCLUDED.claim_type, claim_kind = EXCLUDED.claim_kind, claim_text = EXCLUDED.claim_text, contract = EXCLUDED.contract;")
    w("")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(rows)} claims; {len(missing)} ungrounded: {missing}")


if __name__ == "__main__":
    main(sys.argv[1])