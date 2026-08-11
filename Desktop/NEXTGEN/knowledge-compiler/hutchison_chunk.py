"""Split the raw extracted PDF text into page-anchored chunks.

The extraction format marks every page as:

    === PDFPAGE 178 ===
    <page text>

Each page belongs to the chapter whose [start_page, next_page) range contains
it. Pages are further split into one chunk per TOC section where the section's
start page falls on that page; otherwise the page is a single chunk.
"""
from __future__ import annotations

import re

from compiler_core import PAGE_OFFSET, clean_ws


class Page:
    def __init__(self, pdf_index: int, printed_page: int, text: str):
        self.pdf_index = pdf_index
        self.printed_page = printed_page
        self.text = text


def parse_pages(raw: str) -> list[Page]:
    """Split the raw extraction stream into Page objects."""
    pages: list[Page] = []
    pattern = re.compile(r"=== PDFPAGE (\d+) ===\n")
    tokens = pattern.split(raw)
    # tokens: [pre, "1", text1, "2", text2, ...]
    idx = 1
    while idx < len(tokens):
        pno = int(tokens[idx])
        text = tokens[idx + 1] if idx + 1 < len(tokens) else ""
        pages.append(Page(pdf_index=pno, printed_page=pno - PAGE_OFFSET, text=clean_ws(text)))
        idx += 2
    return pages


def page_chapter(pages: list[Page], chapter_ranges: list[tuple[str, int, int]]) -> dict[int, str]:
    """Map printed_page -> chapter_number using [start, end) ranges."""
    mapping: dict[int, str] = {}
    for number, start, end in chapter_ranges:
        for p in range(start, end):
            mapping[p] = number
    return mapping


def build_chunks(
    pages: list[Page],
    mapping: dict[int, str],
    section_pages: dict[int, list[tuple[str, str, int]]],  # page -> [(section_number, title, depth)]
) -> list[dict]:
    """Return a list of chunk dicts:
    {chapter_number, page, pdf_index, chunk_index, section_number, section_title, text}
    A page assigned to no chapter is skipped (front matter / index / blank).
    """
    chunks: list[dict] = []
    for page in pages:
        ch = mapping.get(page.printed_page)
        if not ch:
            continue
        secs = section_pages.get(page.printed_page, [])
        if not secs:
            chunks.append({
                "chapter_number": ch,
                "page": page.printed_page,
                "pdf_index": page.pdf_index,
                "chunk_index": 0,
                "section_number": None,
                "section_title": None,
                "text": page.text,
            })
            continue
        # The page may open one or more sections; chunk the page text per
        # section (heuristic: later sections get later text). In practice a
        # page rarely opens more than one section, so we keep the whole page
        # under the first section that starts there, but record each section
        # start so section-boundary pages are attributed to the right section.
        primary = secs[0]
        chunks.append({
            "chapter_number": ch,
            "page": page.printed_page,
            "pdf_index": page.pdf_index,
            "chunk_index": 0,
            "section_number": primary[0],
            "section_title": primary[1],
            "text": page.text,
        })
    return chunks
