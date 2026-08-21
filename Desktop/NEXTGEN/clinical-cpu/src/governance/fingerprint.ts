// =============================================================================
// AMEXAN Clinical CPU — H10 deterministic input fingerprint (§10/§30)
// =============================================================================
//
// PURPOSE
// -------
// Produces a deterministic SHA-256 fingerprint for the clinical fact state
// consumed by the CPU.
//
// INVARIANTS
// ----------
// 1. Fact identity is based on clinical content, not database row identity.
// 2. Object key ordering never affects the fingerprint.
// 3. PostgreSQL JSONB serialization differences never affect the fingerprint.
// 4. Fact ordering never affects the fingerprint.
// 5. Fact values preserve their semantic types.
// 6. Fact status is part of the fingerprint.
// 7. No patient identifiers, encounter identifiers, timestamps, or source
//    metadata are included unless explicitly represented as clinical facts.
// 8. The same canonical fact state MUST always produce the same SHA-256.
// 9. This function is pure: no database access, mutation, or side effects.
//
// The fingerprint is therefore suitable for:
//
//   patient facts
//        ↓
//   canonical representation
//        ↓
//   deterministic SHA-256
//        ↓
//   clinical_snapshot.input_fingerprint
//        ↓
//   replay verification
//
// =============================================================================

import { createHash } from 'node:crypto';
import type { Fact, FactValue } from '../types.js';

// -----------------------------------------------------------------------------
// Canonical JSON value
// -----------------------------------------------------------------------------
//
// Recursively canonicalizes JSON-compatible values.
//
// Objects:
//   Keys are sorted lexicographically.
//
// Arrays:
//   Array order is preserved.
//
// Primitives:
//   Returned unchanged.
//
// This distinction is deliberate. Object key order is not clinically
// meaningful, while array order MAY be meaningful to a FactValue collection.
// -----------------------------------------------------------------------------

export function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }

  if (value !== null && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const output: Record<string, unknown> = {};

    for (const key of Object.keys(record).sort()) {
      output[key] = canonicalize(record[key]);
    }

    return output;
  }

  return value;
}

// -----------------------------------------------------------------------------
// Canonical fact representation
// -----------------------------------------------------------------------------
//
// Deliberately excludes:
//
//   id
//   patientId
//   encounterId
//   recordedAt
//   sourceType
//
// Those fields describe where/when a fact was stored rather than the clinical
// fact itself. Including them would make replay fingerprints change merely
// because a database row received a different UUID or timestamp.
//
// Includes:
//
//   factCode
//   statusCode
//   values
//
// This is the exact clinical input surface used by the fingerprint.
// -----------------------------------------------------------------------------

interface FingerprintFact {
  code: string;
  status: string;
  values: FactValue[];
}

function fingerprintFact(fact: Fact): FingerprintFact {
  return {
    code: fact.factCode,
    status: fact.statusCode,
    values: fact.values,
  };
}

// -----------------------------------------------------------------------------
// Deterministic fact ordering
// -----------------------------------------------------------------------------
//
// Facts are sorted by their canonical JSON representation rather than only by
// factCode.
//
// Why?
//
// Two facts may legitimately have the same factCode but different status or
// values. Sorting only by factCode leaves their relative ordering dependent on
// insertion order, which could produce different hashes for semantically
// equivalent fact collections.
//
// Sorting by canonical serialized content gives every fact a stable position.
//
// -----------------------------------------------------------------------------

function canonicalFacts(facts: Fact[]): FingerprintFact[] {
  return facts
    .map(fingerprintFact)
    .sort((a, b) => {
      const left = JSON.stringify(canonicalize(a));
      const right = JSON.stringify(canonicalize(b));

      return left.localeCompare(right);
    });
}

// -----------------------------------------------------------------------------
// Input fingerprint
// -----------------------------------------------------------------------------
//
// Returns:
//
//   lowercase hexadecimal SHA-256 digest
//
// Example:
//
//   9b7c...
//
// The function intentionally hashes the canonical JSON bytes directly rather
// than relying on PostgreSQL JSONB ordering or JavaScript object insertion
// ordering.
// -----------------------------------------------------------------------------

export function inputFingerprint(facts: Fact[]): string {
  const canonicalState = canonicalize(canonicalFacts(facts));
  const serialized = JSON.stringify(canonicalState);

  return createHash('sha256')
    .update(serialized, 'utf8')
    .digest('hex');
}

// -----------------------------------------------------------------------------
// Optional helper: expose the exact canonical payload used for hashing.
//
// Useful for diagnostics, replay debugging, and deterministic test fixtures.
// It does NOT include patient identifiers or storage metadata.
//
// -----------------------------------------------------------------------------

export function canonicalFingerprintPayload(facts: Fact[]): string {
  return JSON.stringify(canonicalize(canonicalFacts(facts)));
}