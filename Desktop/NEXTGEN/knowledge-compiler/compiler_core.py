"""AMEXAN Medical Knowledge Compiler — shared core utilities.

Deterministic UUIDs (same code -> same id) make every generated seed
idempotent and re-runnable. SQL helpers keep emitted statements safe.
"""
from __future__ import annotations

import hashlib
import re
import uuid as uuid_mod

NS = uuid_mod.UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8")  # DNS namespace


def stable_uuid(seed: str) -> uuid_mod.UUID:
    """Deterministic uuid5 from a string seed (no randomness)."""
    return uuid_mod.uuid5(NS, seed)


def sql_literal(value) -> str:
    """Escape a Python value into a safe SQL literal."""
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    s = str(value)
    s = s.replace("'", "''")
    return "'" + s + "'"


def sql_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def text_hash(text: str) -> str:
    """Stable short hash of chunk text for change detection."""
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:16]


def clean_ws(text: str) -> str:
    """Collapse internal whitespace / hyphenation line breaks from PDF text."""
    # remove soft hyphenation: "indi-\nvidual" -> "individual"
    text = re.sub(r"([A-Za-z])-\s*\n\s*([a-z])", r"\1\2", text)
    # join wrapped lines into single spaces
    text = re.sub(r"[ \t]+", " ", text)
    text = text.replace("\u2019", "'").replace("\u2018", "'")
    text = text.replace("\u201c", '"').replace("\u201d", '"')
    text = text.replace("\u2013", "-").replace("\u2014", "-")
    return text.strip()
