"""Parse the extracted PDF table of contents into a chapter/section tree.

Input format (one entry per line):  [depth, 'title', page]
  depth 1 -> part (e.g. "1 General patient assessment")
  depth 2 -> chapter (e.g. "12 Respiratory system")
  depth 3+ -> hierarchical section within the chapter
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field


@dataclass
class TocEntry:
    depth: int
    title: str
    page: int


@dataclass
class Section:
    number: str          # dotted path e.g. "12.1.2"
    title: str
    depth: int
    page: int
    sort_order: int
    children: list["Section"] = field(default_factory=list)


@dataclass
class Chapter:
    number: str          # "1", "12"
    title: str
    page: int
    next_page: int       # first page of next chapter (or doc end)
    sort_order: int
    sections: list[Section] = field(default_factory=list)


def parse_toc(path: str) -> list[Chapter]:
    entries: list[TocEntry] = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"\s*\[\s*(\d+)\s*,\s*'(.*?)'\s*,\s*(\d+)\s*\]", line)
            if not m:
                continue
            depth = int(m.group(1))
            title = m.group(2)
            page = int(m.group(3))
            entries.append(TocEntry(depth, title, page))

    # Stop at the Index (depth 1) — the reference TOC ends there.
    chapters: list[Chapter] = []
    cur: Chapter | None = None
    sec_stack: list[Section] = []

    def parent_of(depth: int, stack: list[Section]) -> Section | None:
        # find the deepest open section whose depth < given depth
        for s in reversed(stack):
            if s.depth < depth:
                return s
        return None

    for e in entries:
        if e.depth == 1:
            if e.title.lower() == "index":
                break
            continue  # part headings are not chapters
        if e.depth == 2:
            num = e.title.split(" ", 1)[0]
            cur = Chapter(
                number=num,
                title=e.title.split(" ", 1)[1] if " " in e.title else e.title,
                page=e.page,
                next_page=0,
                sort_order=len(chapters),
                sections=[],
            )
            chapters.append(cur)
            sec_stack = []
            continue
        if cur is None:
            continue
        parent = parent_of(e.depth, sec_stack)
        if parent is None:
            path = f"{cur.number}.{len(cur.sections) + 1}"
        else:
            # dotted path: chapter.section.childindex...
            path = f"{parent.number}.{len(parent.children) + 1}"
        sec = Section(
            number=path,
            title=e.title,
            depth=e.depth - 2,       # TOC depth 3 -> section depth 1
            page=e.page,
            sort_order=len(parent.children) if parent else len(cur.sections),
        )
        if parent is None:
            cur.sections.append(sec)
        else:
            parent.children.append(sec)
        sec_stack.append(sec)

    # compute next_page for each chapter from following entries' page
    for i, ch in enumerate(chapters):
        nxt = 10 ** 9
        for e in entries:
            if e.depth in (1, 2) and e.page > ch.page:
                if e.depth == 1 and e.title.lower() == "index":
                    nxt = min(nxt, e.page)
                elif e.depth == 2 and e.page > ch.page:
                    nxt = min(nxt, e.page)
        ch.next_page = nxt if nxt != 10 ** 9 else ch.page + 1
    return chapters


def chapter_to_json(chapters: list[Chapter]) -> str:
    out = []
    for ch in chapters:
        out.append({
            "number": ch.number,
            "title": ch.title,
            "page": ch.page,
            "next_page": ch.next_page,
            "sort_order": ch.sort_order,
            "sections": [
                {
                    "number": s.number,
                    "title": s.title,
                    "depth": s.depth,
                    "page": s.page,
                    "sort_order": s.sort_order,
                }
                for s in _flatten(ch.sections)
            ],
        })
    return json.dumps(out, indent=1)


def _flatten(sections: list[Section]) -> list[Section]:
    out: list[Section] = []
    for s in sections:
        out.append(s)
        out.extend(_flatten(s.children))
    return out


def flatten_sections(chapters: list[Chapter]) -> list[tuple[Chapter, Section]]:
    out: list[tuple[Chapter, Section]] = []
    for ch in chapters:
        for s in _flatten(ch.sections):
            out.append((ch, s))
    return out
