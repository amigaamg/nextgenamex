// =============================================================================
// AMEXAN Clinical CPU — database access
// The CPU talks to PostgreSQL through this thin wrapper so every engine can run
// inside the same transaction (the machine test wraps a CPU run in BEGIN/ROLLBACK).
// =============================================================================

import { Pool, PoolClient } from 'pg';

export type Queryable = Pool | PoolClient;

export interface Row {
  [column: string]: unknown;
}

export class Db {
  private queue: Promise<unknown> = Promise.resolve();

  constructor(private readonly q: Queryable) {}

  async query<T extends Row = Row>(sql: string, params: unknown[] = []): Promise<T[]> {
    // A single pg.Client cannot run concurrent queries; serialize every statement
    // so a CPU run works identically on a pooled connection or inside one transaction.
    const run = () => this.q.query(sql, params);
    const result = this.queue.then(run, run);
    this.queue = result.catch(() => undefined);
    const queryResult = await result;
    return queryResult.rows as T[];
  }

  async queryOne<T extends Row = Row>(sql: string, params: unknown[] = []): Promise<T | null> {
    const rows = await this.query<T>(sql, params);
    return rows.length > 0 ? rows[0] : null;
  }
}

export function createPool(): Pool {
  return new Pool({
    host: process.env.AMEXAN_PGHOST || 'localhost',
    port: Number(process.env.AMEXAN_PGPORT || 5432),
    user: process.env.AMEXAN_PGUSER || 'postgres',
    password: process.env.AMEXAN_PGPASSWORD || 'postgres',
    database: process.env.AMEXAN_PGDATABASE || 'amexan',
    max: 5,
  });
}
