// =============================================================================
// AMEXAN Clinical CPU — ConfigurationResolver
//
// Configuration Engine (3.19)
//
// The AMEXAN DEFAULT knowledge layer is immutable and remains the baseline.
// Local configuration is represented as an override layered above that
// baseline. The resolver NEVER mutates knowledge rows.
//
// Resolution model:
//
//   AMEXAN DEFAULT
//        ↓
//   GLOBAL / ORGANIZATION
//        ↓
//   FACILITY
//        ↓
//   DEPARTMENT
//        ↓
//   CLINICIAN
//
// The `knowledge.active_override` projection is the authoritative read-side
// source for the currently effective override. Scope precedence is therefore
// resolved by the database projection rather than by trusting arbitrary client
// input.
//
// Security guarantees:
//   - No caller-controlled table or column names are interpolated.
//   - Only explicitly whitelisted knowledge targets may be resolved.
//   - All values remain parameterized SQL parameters.
//   - Unknown target types are ignored rather than executed.
//   - Empty / malformed configuration payloads safely become `{}`.
//   - Duplicate targets are resolved once.
//   - A missing override is not treated as an error.
//   - Database rows are mapped into the public ConfigurationOverride contract.
//   - The original AMEXAN knowledge row is never modified.
//
// IMPORTANT:
// This resolver is READ-ONLY. Creating, approving, activating or retiring an
// override belongs to the configuration-governance/write path.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ConfigurationOverride } from '../types.js';

// =============================================================================
// DATABASE TYPES
// =============================================================================

interface OverrideRow extends Row {
  override_code: string;
  target_type: string;
  target_id: string;
  scope_code: string;
  config: unknown;
  reason: string | null;
  version: number | string;
  target_code: string;
}

// =============================================================================
// TARGET REGISTRY
// =============================================================================
//
// SQL identifiers cannot be parameterized with PostgreSQL `$1` parameters.
// Therefore target table / code-column selection MUST come exclusively from
// this static allow-list.
//
// Never replace this with:
//
//   FROM ${target.type}
//
// or:
//
//   c.${target.code}
//
// even if the value appears to come from a "trusted" internal caller.
//
// Adding a new target requires explicitly registering its table and code
// column here.
// =============================================================================

interface TargetDefinition {
  readonly table: string;
  readonly codeColumn: string;
}

const TARGET_TABLES: Readonly<Record<string, TargetDefinition>> = {
  investigation: {
    table: 'knowledge.investigation',
    codeColumn: 'investigation_code',
  },

  condition: {
    table: 'knowledge.condition',
    codeColumn: 'condition_code',
  },

  protocol: {
    table: 'knowledge.protocol',
    codeColumn: 'protocol_code',
  },

  medication: {
    table: 'knowledge.medication',
    codeColumn: 'medication_code',
  },

  question: {
    table: 'knowledge.question',
    codeColumn: 'question_code',
  },

  phenotype: {
    table: 'knowledge.phenotype',
    codeColumn: 'phenotype_code',
  },

  mechanism: {
    table: 'knowledge.mechanism',
    codeColumn: 'mechanism_code',
  },
};

// =============================================================================
// INPUT TYPES
// =============================================================================

export interface ConfigurationTarget {
  /**
   * Canonical AMEXAN knowledge target type.
   *
   * Examples:
   *   medication
   *   condition
   *   protocol
   *   investigation
   */
  type: string;

  /**
   * Canonical knowledge code.
   *
   * Examples:
   *   AMOXICILLIN
   *   COMMUNITY_ACQUIRED_PNEUMONIA
   */
  code: string;
}

// =============================================================================
// NORMALIZATION HELPERS
// =============================================================================

/**
 * Resolve a target definition exclusively from the static allow-list.
 */
function getTargetDefinition(
  type: string,
): TargetDefinition | null {
  if (typeof type !== 'string') {
    return null;
  }

  return TARGET_TABLES[type.trim().toLowerCase()] ?? null;
}

/**
 * Normalize a target code without changing its semantic value.
 *
 * We trim surrounding whitespace because codes are identifiers, but we do not
 * force uppercase: the database remains the authoritative representation.
 */
function normalizeTargetCode(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const code = value.trim();
  return code !== '' ? code : null;
}

/**
 * Convert the configuration column into the public configuration object.
 *
 * PostgreSQL JSON/JSONB normally arrives as an object, but drivers / database
 * adapters may return JSON values as strings. Handle both safely.
 *
 * Invalid or non-object configuration is represented as `{}` rather than
 * leaking arbitrary values into the resolver contract.
 */
function normalizeConfiguration(
  value: unknown,
): Record<string, unknown> {
  if (value == null) {
    return {};
  }

  if (typeof value === 'string') {
    try {
      const parsed: unknown = JSON.parse(value);

      if (
        typeof parsed === 'object' &&
        parsed !== null &&
        !Array.isArray(parsed)
      ) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return {};
    }

    return {};
  }

  if (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value)
  ) {
    return value as Record<string, unknown>;
  }

  return {};
}

/**
 * Normalize a database version value.
 *
 * PostgreSQL integer columns are normally returned as numbers, but keeping
 * this defensive conversion prevents accidental string leakage when a
 * different DB adapter is used.
 */
function normalizeVersion(value: unknown): number {
  const version = Number(value);

  return Number.isFinite(version) ? version : 0;
}

// =============================================================================
// RESOLVER
// =============================================================================

export class ConfigurationResolver {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /**
   * Resolve the currently effective configuration override for each requested
   * knowledge target.
   *
   * This method intentionally returns ONLY targets for which an active
   * override exists.
   *
   * Therefore:
   *
   *   [] → no active local configuration
   *
   * does NOT mean:
   *
   *   [] → target does not exist
   *
   * The caller should continue using AMEXAN DEFAULT knowledge when no override
   * is returned.
   */
  async resolve(
    targets: ConfigurationTarget[],
  ): Promise<ConfigurationOverride[]> {
    if (!Array.isArray(targets) || targets.length === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // Normalize and deduplicate targets.
    //
    // A duplicate target should never cause duplicate configuration entries
    // in the returned resolver result.
    // -------------------------------------------------------------------------

    const uniqueTargets = new Map<string, ConfigurationTarget>();

    for (const target of targets) {
      if (!target || typeof target !== 'object') {
        continue;
      }

      const type =
        typeof target.type === 'string'
          ? target.type.trim().toLowerCase()
          : '';

      const code = normalizeTargetCode(target.code);

      if (!type || !code) {
        continue;
      }

      if (!getTargetDefinition(type)) {
        continue;
      }

      const key = `${type}\u0000${code}`;

      if (!uniqueTargets.has(key)) {
        uniqueTargets.set(key, {
          type,
          code,
        });
      }
    }

    if (uniqueTargets.size === 0) {
      return [];
    }

    // -------------------------------------------------------------------------
    // Resolve each target independently.
    //
    // Keeping each query parameterized and its identifiers selected exclusively
    // from TARGET_TABLES gives us a strong SQL-injection boundary.
    //
    // Promise.all is safe here because these are independent READ operations.
    // -------------------------------------------------------------------------

    const results = await Promise.all(
      Array.from(uniqueTargets.values()).map((target) =>
        this.resolveOne(target),
      ),
    );

    // Missing overrides intentionally resolve to null and are removed.
    return results.filter(
      (result): result is ConfigurationOverride => result !== null,
    );
  }

  /**
   * Resolve one target.
   *
   * This is kept private so every public resolution path passes through the
   * same validation and mapping logic.
   */
  private async resolveOne(
    target: ConfigurationTarget,
  ): Promise<ConfigurationOverride | null> {
    const definition = getTargetDefinition(target.type);

    if (!definition) {
      return null;
    }

    const targetCode = normalizeTargetCode(target.code);

    if (!targetCode) {
      return null;
    }

    const row = await this.db.queryOne<OverrideRow>(
      `
        SELECT
          o.override_code,
          o.target_type,
          o.target_id,
          o.scope_code,
          o.config,
          o.reason,
          o.version,
          c.${definition.codeColumn} AS target_code
        FROM knowledge.active_override AS o
        INNER JOIN ${definition.table} AS c
          ON c.id = o.target_id
        WHERE o.target_type = $1
          AND c.${definition.codeColumn} = $2
        LIMIT 1
      `,
      [
        target.type,
        targetCode,
      ],
    );

    if (!row) {
      return null;
    }

    return this.mapOverride(row);
  }

  // ===========================================================================
  // ROW MAPPING
  // ===========================================================================

  /**
   * Convert the database projection into the application-level configuration
   * contract.
   */
  private mapOverride(
    row: OverrideRow,
  ): ConfigurationOverride {
    return {
      overrideCode: row.override_code,
      targetType: row.target_type,
      targetCode: row.target_code,
      scopeCode: row.scope_code,
      config: normalizeConfiguration(row.config),
      reason: row.reason,
      version: normalizeVersion(row.version),
    };
  }
}

// =============================================================================
// OPTIONAL REGISTRY HELPERS
// =============================================================================
//
// These helpers intentionally expose metadata only. They do not expose raw SQL
// identifiers to callers and cannot be used to bypass TARGET_TABLES.
// =============================================================================

/**
 * Returns true when AMEXAN supports configuration resolution for the supplied
 * target type.
 */
export function isConfigurableTargetType(
  type: string,
): boolean {
  return getTargetDefinition(type) !== null;
}

/**
 * Returns the canonical target types supported by the resolver.
 *
 * A new array is returned every time so callers cannot mutate the registry.
 */
export function getConfigurableTargetTypes(): string[] {
  return Object.keys(TARGET_TABLES);
}