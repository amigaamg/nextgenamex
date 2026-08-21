// =============================================================================
// AMEXAN Clinical CPU — Database Access Layer
//
// PURPOSE
// -------
// Provides the single database abstraction used by the AMEXAN Clinical CPU.
//
// The CPU is deliberately database-agnostic above this layer. Clinical engines
// do not receive a Pool or PoolClient directly; they receive Db. This gives the
// CPU one consistent query contract whether it is:
//
//   1. running normally against a PostgreSQL connection pool,
//   2. running inside an explicit transaction using a PoolClient,
//   3. running in machine/integration tests inside BEGIN/ROLLBACK,
//   4. being executed by multiple CPU engines that share the same transaction.
//
// ARCHITECTURAL RULE
// ------------------
// Db owns query execution, while clinical engines own clinical logic.
//
//     PostgreSQL
//         ↓
//     Pool / PoolClient
//         ↓
//     Db
//         ↓
//     Clinical CPU / Engines
//
// No clinical decision-making belongs in this file.
//
// TRANSACTION SAFETY
// ------------------
// A PoolClient represents one PostgreSQL connection and therefore cannot safely
// execute multiple statements concurrently. The internal promise queue
// serializes all Db operations.
//
// This is particularly important because CPUOrchestrator runs several engines
// concurrently with Promise.all(). The engines may therefore issue overlapping
// database calls while sharing the same Db instance.
//
// Db guarantees that those statements are executed sequentially on the
// underlying PostgreSQL client.
//
// IMPORTANT
// ---------
// Db does NOT create, commit, or rollback transactions.
//
// Transaction ownership remains with the caller:
//
//     const client = await pool.connect();
//
//     try {
//       await client.query('BEGIN');
//       const db = new Db(client);
//
//       await clinicalCPU.process(...);
//
//       await client.query('COMMIT');
//     } catch (error) {
//       await client.query('ROLLBACK');
//       throw error;
//     } finally {
//       client.release();
//     }
//
// This separation prevents the database wrapper from accidentally committing
// part of a clinical computation.
//
// =============================================================================

import { Pool, PoolClient, type QueryResult } from 'pg';

/**
 * Anything capable of executing a PostgreSQL query through pg's query API.
 *
 * Pool
 * ----
 * Used for ordinary application/database access.
 *
 * PoolClient
 * ----------
 * Used when the caller owns a specific connection, particularly for
 * transaction-scoped CPU execution.
 */
export type Queryable = Pool | PoolClient;

/**
 * Generic database row.
 *
 * PostgreSQL column names are represented dynamically, while individual
 * engines define their own strongly typed row interfaces:
 *
 *     interface MedicationRow extends Row {
 *       medication_code: string;
 *       generic_name: string;
 *     }
 *
 * Db itself intentionally does not impose a clinical schema.
 */
export interface Row {
  [column: string]: unknown;
}

/**
 * Thin PostgreSQL access wrapper used by the AMEXAN Clinical CPU.
 *
 * One Db instance should normally be shared by all engines participating in
 * one CPU pass.
 */
export class Db {
  /**
   * Promise chain used to serialize queries against one underlying pg client.
   *
   * The queue is intentionally internal. Callers simply await query() and do
   * not need to coordinate concurrent engine execution themselves.
   */
  private queue: Promise<unknown> = Promise.resolve();

  constructor(private readonly q: Queryable) {}

  /**
   * Execute a PostgreSQL query and return all rows.
   *
   * The generic parameter describes the expected application-level row shape.
   *
   * Example:
   *
   *     const rows = await db.query<MedicationRow>(
   *       `SELECT medication_code, generic_name
   *          FROM knowledge.medication
   *         WHERE medication_code = ANY($1::text[])`,
   *       [codes],
   *     );
   *
   * Parameters are always passed separately to pg rather than interpolated
   * into SQL.
   */
  async query<T extends Row = Row>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    /**
     * Keep the actual execution function small so both the normal and rejected
     * paths of the queue can invoke the same operation.
     */
    const run = async (): Promise<QueryResult> => {
      return this.q.query(sql, params);
    };

    /**
     * Chain this query after the previous query.
     *
     * `then(run, run)` is important:
     *
     * If the previous query succeeds:
     *     → execute this query.
     *
     * If the previous query fails:
     *     → execute this query anyway.
     *
     * This prevents one failed query from permanently poisoning the queue.
     */
    const result = this.queue.then(run, run);

    /**
     * The queue itself must never remain rejected.
     *
     * The actual caller still receives the original query error through
     * `await result`, while future queries remain executable.
     */
    this.queue = result.catch(() => undefined);

    const queryResult = await result;

    return queryResult.rows as T[];
  }

  /**
   * Execute a query and return its first row, or null when no row exists.
   *
   * This is useful for singleton lookups such as:
   *
   *     SELECT ...
   *       FROM knowledge.condition
   *      WHERE condition_code = $1
   *
   * It deliberately returns null rather than undefined so database absence is
   * explicit and predictable throughout the clinical engines.
   */
  async queryOne<T extends Row = Row>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T | null> {
    const rows = await this.query<T>(sql, params);

    return rows.length > 0 ? rows[0] : null;
  }
}

/**
 * AMEXAN PostgreSQL connection-pool factory.
 *
 * Environment variables:
 *
 *   AMEXAN_PGHOST
 *   AMEXAN_PGPORT
 *   AMEXAN_PGUSER
 *   AMEXAN_PGPASSWORD
 *   AMEXAN_PGDATABASE
 *
 * Development defaults are retained for local AMEXAN development, but
 * production deployments should explicitly provide credentials through the
 * environment rather than relying on defaults.
 */
export function createPool(): Pool {
  const portRaw = process.env.AMEXAN_PGPORT;

  const port = portRaw ? Number(portRaw) : 5432;

  if (!Number.isInteger(port) || port <= 0 || port > 65535) {
    throw new Error(
      `Invalid AMEXAN_PGPORT: "${portRaw}". Expected a valid PostgreSQL port.`,
    );
  }

  return new Pool({
    host: process.env.AMEXAN_PGHOST || 'localhost',
    port,
    user: process.env.AMEXAN_PGUSER || 'postgres',
    password: process.env.AMEXAN_PGPASSWORD || 'postgres',
    database: process.env.AMEXAN_PGDATABASE || 'amexan',

    /**
     * Small default pool for the CPU service.
     *
     * The application can increase this through a future configuration layer
     * if workload requires it. Keeping the pool bounded prevents uncontrolled
     * connection creation.
     */
    max: 5,

    /**
     * Do not allow an idle connection to remain indefinitely in deployments
     * where database infrastructure may recycle connections.
     */
    idleTimeoutMillis: 30_000,

    /**
     * Fail reasonably quickly when PostgreSQL is unavailable instead of
     * allowing CPU requests to hang indefinitely.
     */
    connectionTimeoutMillis: 10_000,

    /**
     * Application-level name visible to PostgreSQL monitoring tools.
     *
     * This makes AMEXAN Clinical CPU traffic identifiable in pg_stat_activity
     * and related operational tooling.
     */
    application_name: 'AMEXAN Clinical CPU',
  });
}