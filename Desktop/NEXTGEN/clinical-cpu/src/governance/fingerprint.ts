// =============================================================================
// AMEXAN Clinical CPU — H10 deterministic input fingerprint (§10/§30)
// A sha256 of the canonical patient-fact state. The same facts (code + status +
// values) always produce the same fingerprint, so a recorded clinical snapshot
// can be replayed and verified byte-for-byte.
// =============================================================================

import { createHash } from 'node:crypto';
import type { Fact } from '../types.js';

// Recursively sort every object's keys so two equal structures compare equal no
// matter where they came from. PostgreSQL's JSONB reorders keys (by length then
// bytewise), so a recorded snapshot must be compared canonically — key order is
// never semantically meaningful but always a serialization detail.
export function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value !== null && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(record).sort()) out[key] = canonicalize(record[key]);
    return out;
  }
  return value;
}

export function inputFingerprint(facts: Fact[]): string {
  const canonical = JSON.stringify(canonicalize(
    facts
      .map((f) => ({ code: f.factCode, status: f.statusCode, values: f.values }))
      .sort((a, b) => a.code.localeCompare(b.code)),
  ));
  return createHash('sha256').update(canonical).digest('hex');
}
