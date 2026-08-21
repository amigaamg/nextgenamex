// =============================================================================
// AMEXAN Clinical CPU — KnowledgeResolver (H10 §37)
// =============================================================================
// Runtime knowledge governance gate.
//
// The resolver is the single runtime policy boundary between the Clinical CPU
// and governed clinical knowledge.
//
// Resolution contract:
//
//   VALID
//     A governed runtime object exists and its lifecycle is LIVE.
//     LIVE statuses are:
//       ACTIVE
//       APPROVED
//       VALIDATED
//
//   BLOCKED
//     A governed object exists but is not live.
//     Examples:
//       DRAFT
//       SUPERSEDED
//       DEPRECATED
//       RETIRED
//
//     BLOCKED knowledge MUST NOT be used by downstream clinical engines.
//
//   UNGOVERNED
//     No governance registration can be resolved for the requested runtime
//     object. This is a provenance/governance gap and is never silently treated
//     as trusted.
//
// Architectural rules:
//
//   • Governance is database-driven.
//   • The resolver does not contain clinical medicine.
//   • The resolver does not modify knowledge.
//   • The resolver is deterministic and side-effect free.
//   • Every requested target receives exactly one governance verdict.
//   • All lifecycle states are loaded so obsolete knowledge can be BLOCKED.
//   • Runtime codes are resolved to governance objects by reference.
//   • Duplicate targets are evaluated deterministically.
//   • A BLOCKED object never becomes VALID merely because another object with
//     the same runtime code exists.
//   • The resolver does not silently fall back from governed knowledge to an
//     ungoverned object.
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  KnowledgeGateEntry,
  KnowledgeGateResult,
  KnowledgeGateTarget,
} from '../types.js';

// -----------------------------------------------------------------------------
// Database row
// -----------------------------------------------------------------------------

interface GovernedRow extends Row {
  kind: string;
  key_code: string;
  object_code: string;
  lifecycle_status: string;
}

// -----------------------------------------------------------------------------
// Governance policy
// -----------------------------------------------------------------------------

/**
 * Lifecycle states which are permitted to participate in clinical runtime
 * computation.
 *
 * This is intentionally centralized. Engines must not independently interpret
 * lifecycle status.
 */
export const LIVE_STATUSES: ReadonlySet<string> = new Set([
  'ACTIVE',
  'APPROVED',
  'VALIDATED',
]);

/**
 * Runtime knowledge kinds represented directly by CPU knowledge tables.
 *
 * The resolver also supports arbitrary governance knowledge types through the
 * generic knowledge_object fallback query.
 */
const RUNTIME_KINDS: ReadonlySet<string> = new Set([
  'phenotype',
  'condition',
  'protocol',
  'question',
]);

// -----------------------------------------------------------------------------
// Resolver
// -----------------------------------------------------------------------------

export class KnowledgeResolver {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // Public API
  // ===========================================================================

  /**
   * Gate all knowledge targets required by a CPU pass.
   *
   * No knowledge is modified and no clinical interpretation is performed.
   *
   * Every target is classified as:
   *
   *   VALID
   *   BLOCKED
   *   UNGOVERNED
   *
   * `passes` is true only when there are no BLOCKED objects.
   *
   * UNGOVERNED objects deliberately do NOT make `passes` false because they
   * represent a provenance gap rather than a positively identified obsolete
   * object. They remain explicitly surfaced in `ungoverned`.
   */
  async gate(targets: KnowledgeGateTarget[]): Promise<KnowledgeGateResult> {
    if (targets.length === 0) {
      return {
        passes: true,
        checked: 0,
        valid: [],
        blocked: [],
        ungoverned: [],
      };
    }

    const normalizedTargets = normalizeTargets(targets);
    const governed = await this.loadGoverned();

    const valid: KnowledgeGateEntry[] = [];
    const blocked: KnowledgeGateEntry[] = [];
    const ungoverned: KnowledgeGateEntry[] = [];

    for (const target of normalizedTargets) {
      const key = targetKey(target);
      const row = governed.get(key);

      if (!row) {
        const entry = this.ungovernedEntry(target);
        ungoverned.push(entry);
        continue;
      }

      if (LIVE_STATUSES.has(normalizeLifecycle(row.lifecycle_status))) {
        const entry = this.validEntry(target, row);
        valid.push(entry);
        continue;
      }

      const entry = this.blockedEntry(target, row);
      blocked.push(entry);
    }

    return {
      passes: blocked.length === 0,
      checked: normalizedTargets.length,
      valid,
      blocked,
      ungoverned,
    };
  }

  /**
   * Gate one knowledge object.
   *
   * This convenience method preserves exactly the same policy as `gate()`.
   */
  async gateOne(target: KnowledgeGateTarget): Promise<KnowledgeGateEntry> {
    const result = await this.gate([target]);

    return (
      result.valid[0] ??
      result.blocked[0] ??
      result.ungoverned[0] ??
      this.ungovernedEntry(normalizeTarget(target))
    );
  }

  // ===========================================================================
  // Entry construction
  // ===========================================================================

  private validEntry(
    target: KnowledgeGateTarget,
    row: GovernedRow,
  ): KnowledgeGateEntry {
    const lifecycleStatus = normalizeLifecycle(row.lifecycle_status);

    return {
      kind: target.kind,
      code: target.code,
      governed: true,
      objectCode: row.object_code,
      lifecycleStatus,
      verdict: 'VALID',
      reason:
        `governed object '${row.object_code}' is live with lifecycle ` +
        `'${lifecycleStatus}' — runtime use permitted`,
    };
  }

  private blockedEntry(
    target: KnowledgeGateTarget,
    row: GovernedRow,
  ): KnowledgeGateEntry {
    const lifecycleStatus = normalizeLifecycle(row.lifecycle_status);

    return {
      kind: target.kind,
      code: target.code,
      governed: true,
      objectCode: row.object_code,
      lifecycleStatus,
      verdict: 'BLOCKED',
      reason:
        `governed object '${row.object_code}' has lifecycle ` +
        `'${lifecycleStatus}', which is not live — runtime use blocked ` +
        '(H10 §37 / §41 / §49)',
    };
  }

  private ungovernedEntry(
    target: KnowledgeGateTarget,
  ): KnowledgeGateEntry {
    return {
      kind: target.kind,
      code: target.code,
      governed: false,
      objectCode: null,
      lifecycleStatus: null,
      verdict: 'UNGOVERNED',
      reason:
        `no governed knowledge_object is registered for runtime ` +
        `code '${target.code}' of kind '${target.kind}' — ` +
        'provenance gap; object is flagged rather than silently trusted ' +
        '(H10 §27 / §49)',
    };
  }

  // ===========================================================================
  // Governance catalogue
  // ===========================================================================

  /**
   * Load the COMPLETE governance catalogue relevant to runtime resolution.
   *
   * Important:
   *
   * We intentionally do not filter lifecycle_status in SQL.
   *
   * If the query loaded only ACTIVE objects, a DRAFT/SUPERSEDED/DEPRECATED
   * object would appear indistinguishable from an ungoverned object. That would
   * violate the governance contract.
   *
   * Every obsolete registration therefore remains visible to the resolver and
   * is explicitly returned as BLOCKED.
   */
  private async loadGoverned(): Promise<Map<string, GovernedRow>> {
    const rows = await this.db.query<GovernedRow>(
      `
      WITH governed_runtime_objects AS (

        -- -------------------------------------------------------------------
        -- Phenotypes
        -- -------------------------------------------------------------------
        SELECT
          'phenotype'::text AS kind,
          ph.phenotype_code AS key_code,
          ko.object_code,
          ko.lifecycle_status
        FROM governance.knowledge_object ko
        JOIN knowledge.phenotype ph
          ON ph.phenotype_code = ko.object_code
        WHERE LOWER(ko.knowledge_type) IN (
          'phenotype',
          'clinical_phenotype'
        )

        UNION ALL

        -- -------------------------------------------------------------------
        -- Conditions / diagnoses
        -- -------------------------------------------------------------------
        SELECT
          'condition'::text AS kind,
          c.condition_code AS key_code,
          ko.object_code,
          ko.lifecycle_status
        FROM governance.knowledge_object ko
        JOIN knowledge.diagnosis_concept dc
          ON dc.code = ko.object_code
        JOIN knowledge.condition c
          ON c.concept_id = dc.concept_id
        WHERE LOWER(ko.knowledge_type) IN (
          'condition',
          'diagnosis',
          'diagnosis_concept'
        )

        UNION ALL

        -- -------------------------------------------------------------------
        -- Protocols
        -- -------------------------------------------------------------------
        SELECT
          'protocol'::text AS kind,
          pr.protocol_code AS key_code,
          ko.object_code,
          ko.lifecycle_status
        FROM governance.knowledge_object ko
        JOIN knowledge.protocol pr
          ON pr.protocol_code = ko.object_code
        WHERE LOWER(ko.knowledge_type) IN (
          'protocol',
          'clinical_protocol'
        )

        UNION ALL

        -- -------------------------------------------------------------------
        -- Questions
        -- -------------------------------------------------------------------
        SELECT
          'question'::text AS kind,
          q.question_code AS key_code,
          ko.object_code,
          ko.lifecycle_status
        FROM governance.knowledge_object ko
        JOIN knowledge.question q
          ON q.question_code = ko.object_code
        WHERE LOWER(ko.knowledge_type) IN (
          'question',
          'clinical_question'
        )

        UNION ALL

        -- -------------------------------------------------------------------
        -- Generic governed objects
        --
        -- These cover governed entities which do not have a direct runtime
        -- table mapping, for example:
        --
        --   guidelines
        --   documentation templates
        --   education objects
        --   configuration objects
        --   governance-specific knowledge
        --
        -- The object remains addressable by:
        --
        --   lower(knowledge_type) : object_code
        --
        -- so a DRAFT object can still be explicitly BLOCKED.
        -- -------------------------------------------------------------------
        SELECT
          LOWER(ko.knowledge_type)::text AS kind,
          ko.object_code::text AS key_code,
          ko.object_code,
          ko.lifecycle_status
        FROM governance.knowledge_object ko
        WHERE LOWER(ko.knowledge_type) NOT IN (
          'phenotype',
          'clinical_phenotype',
          'condition',
          'diagnosis',
          'diagnosis_concept',
          'protocol',
          'clinical_protocol',
          'question',
          'clinical_question'
        )
      )

      SELECT
        kind,
        key_code,
        object_code,
        lifecycle_status
      FROM governed_runtime_objects
      `,
    );

    return buildGovernedMap(rows);
  }
}

// =============================================================================
// Pure helpers
// =============================================================================

/**
 * Canonical target normalization.
 *
 * Governance keys are case-insensitive at runtime. The original target values
 * are preserved in the returned projection, while lookup uses normalized keys.
 */
function normalizeTarget(target: KnowledgeGateTarget): KnowledgeGateTarget {
  return {
    kind: normalizeKind(target.kind),
    code: normalizeCode(target.code),
  };
}

/**
 * Normalize a target list while:
 *
 *   • removing null/empty targets
 *   • normalizing kind/code
 *   • deduplicating identical governance targets
 *
 * Stable insertion order is preserved.
 */
function normalizeTargets(
  targets: KnowledgeGateTarget[],
): KnowledgeGateTarget[] {
  const seen = new Set<string>();
  const normalized: KnowledgeGateTarget[] = [];

  for (const target of targets) {
    if (!target) continue;

    const normalizedTarget = normalizeTarget(target);

    if (!normalizedTarget.kind || !normalizedTarget.code) continue;

    const key = targetKey(normalizedTarget);

    if (seen.has(key)) continue;

    seen.add(key);
    normalized.push(normalizedTarget);
  }

  return normalized;
}

function normalizeKind(value: string): string {
  return String(value ?? '')
    .trim()
    .toLowerCase();
}

function normalizeCode(value: string): string {
  return String(value ?? '').trim();
}

function normalizeLifecycle(value: string): string {
  return String(value ?? '')
    .trim()
    .toUpperCase();
}

function targetKey(target: KnowledgeGateTarget): string {
  return `${normalizeKind(target.kind)}:${normalizeCode(target.code)}`;
}

/**
 * Convert governance rows into a deterministic lookup map.
 *
 * If malformed/duplicate governance registrations exist, lifecycle resolution
 * follows this policy:
 *
 *   1. Prefer LIVE registrations.
 *   2. If no LIVE registration exists, retain a non-live registration.
 *
 * This prevents a stale duplicate registration from shadowing a valid live
 * registration while still allowing obsolete objects to be surfaced when no
 * live object exists.
 */
function buildGovernedMap(
  rows: GovernedRow[],
): Map<string, GovernedRow> {
  const map = new Map<string, GovernedRow>();

  for (const raw of rows) {
    const row: GovernedRow = {
      kind: normalizeKind(raw.kind),
      key_code: normalizeCode(raw.key_code),
      object_code: normalizeCode(raw.object_code),
      lifecycle_status: normalizeLifecycle(raw.lifecycle_status),
    };

    if (!row.kind || !row.key_code || !row.object_code) continue;

    const key = `${row.kind}:${row.key_code}`;
    const existing = map.get(key);

    if (!existing) {
      map.set(key, row);
      continue;
    }

    const existingLive = LIVE_STATUSES.has(existing.lifecycle_status);
    const incomingLive = LIVE_STATUSES.has(row.lifecycle_status);

    if (!existingLive && incomingLive) {
      map.set(key, row);
    }
  }

  return map;
}

// =============================================================================
// Optional policy helpers
// =============================================================================

/**
 * Determines whether a knowledge kind is one of the canonical runtime table
 * kinds.
 *
 * Kept exported for engines/tests that need to distinguish direct runtime
 * objects from generic governed knowledge.
 */
export function isRuntimeKnowledgeKind(kind: string): boolean {
  return RUNTIME_KINDS.has(normalizeKind(kind));
}

/**
 * Determines whether a lifecycle status is currently permitted for CPU use.
 */
export function isLiveKnowledgeStatus(status: string): boolean {
  return LIVE_STATUSES.has(normalizeLifecycle(status));
}