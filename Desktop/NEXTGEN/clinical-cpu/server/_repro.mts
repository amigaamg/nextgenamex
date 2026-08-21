import { randomUUID } from 'node:crypto';
import { Pool } from 'pg';
import { Db } from '../src/db.js';
import { createPersistentEncounter } from './encounters.js';
import { ClinicalCPU } from '../src/index.js';

const pool = new Pool({
  host: process.env.AMEXAN_PGHOST || 'localhost',
  port: Number(process.env.AMEXAN_PGPORT || 5432),
  user: process.env.AMEXAN_PGUSER || 'postgres',
  password: process.env.AMEXAN_PGPASSWORD || 'postgres',
  database: process.env.AMEXAN_PGDATABASE || 'amexan',
  max: 2,
});

class TraceDb extends Db {
  private currentSql = '';
  override async query<T extends { [column: string]: unknown }>(sql: string, params: unknown[] = []): Promise<T[]> {
    this.currentSql = sql;
    try {
      return await super.query(sql, params);
    } catch (e) {
      const err = e as Error & { position?: number };
      console.error('=== FAILING SQL ===');
      console.error(sql);
      if (err.position) {
        const pos = Number(err.position);
        console.error('--- context around position ---');
        console.error(sql.slice(Math.max(0, pos - 120), pos + 40));
        console.error('--- caret ---');
        console.error(' '.repeat(Math.min(pos - 1, 120)) + '^');
      }
      throw e;
    }
  }
}

try {
  const client = await pool.connect();
  try {
    const db = new TraceDb(client);
    const created = await createPersistentEncounter(db, {
      patientId: randomUUID(),
      encounterTypeCode: 'inpatient',
    });
    console.log('create OK', created.encounterId);

    const cpu = new ClinicalCPU(db);
    await cpu.process({
      patientId: created.patientId,
      encounterId: created.encounterId,
      event: {
        type: 'ENCOUNTER_CREATED',
        payload: {
          department: null,
          encounterType: 'inpatient',
          presentingComplaintCodes: [],
        },
      },
    });
    console.log('cpu OK');
  } catch (e) {
    console.error('FAILED:', (e as Error).message);
  } finally {
    client.release();
  }
} finally {
  await pool.end();
}