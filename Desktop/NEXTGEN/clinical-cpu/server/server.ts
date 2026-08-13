// =============================================================================
// AMEXAN Clinical Runtime API — entry point
// The thin HTTP boundary (4.37): the UI never implements medical reasoning; it
// posts events and renders the ClinicalRuntimeProjection the CPU returns.
//
//   POST /clinical/demo            create a demo patient + encounter
//   POST /clinical/events          ingest one event, return the new projection
//   GET  /clinical/state?patientId latest projection for a patient
//   GET  /clinical/timeline?patientId the cpu.event_log for a patient
//   GET  /events/stream?patientId  Server-Sent Events (realtime projection)
//   GET  /health                   liveness
//
// Also serves the built UI from ../clinical-ui/dist when present.
// =============================================================================

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, extname, normalize } from 'node:path';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { Pool } from 'pg';
import { ClinicalCPU, Db } from '../src/index.js';
import { createDemoEncounter } from './demo.js';
import { timelineForPatient } from './timeline.js';
import { broadcast, registerStream, writeSseHeaders } from './sse.js';
import type { ClinicalRuntimeProjection, ClinicalEvent } from '../src/types.js';

const PORT = Number(process.env.AMEXAN_API_PORT || 8787);
const pool = new Pool({
  host: process.env.AMEXAN_PGHOST || 'localhost',
  port: Number(process.env.AMEXAN_PGPORT || 5432),
  user: process.env.AMEXAN_PGUSER || 'postgres',
  password: process.env.AMEXAN_PGPASSWORD || 'postgres',
  database: process.env.AMEXAN_PGDATABASE || 'amexan',
  max: 10,
});

const UI_DIST = join(import.meta.dirname, '..', '..', 'clinical-ui', 'dist');

function json(res: ServerResponse, status: number, body: unknown): void {
  if (res.headersSent) {
    // Headers already flushed (e.g. a streaming/static response that later
    // failed). We cannot writeHead again — end the stream instead.
    try {
      res.end();
    } catch {
      // ignore
    }
    return;
  }
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
  });
  res.end(JSON.stringify(body));
}

async function readBody(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 1_000_000) throw new Error('payload too large');
    chunks.push(chunk as Buffer);
  }
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf-8'));
}

async function withDb<T>(fn: (db: Db) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    return await fn(new Db(client));
  } finally {
    client.release();
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
  const path = url.pathname;

  try {
    if (req.method === 'OPTIONS') {
      res.writeHead(204, { 'access-control-allow-origin': '*', 'access-control-allow-methods': 'GET, POST, OPTIONS' });
      res.end();
      return;
    }

    // ---- API routes ---------------------------------------------------------
    if (req.method === 'GET' && path === '/health') {
      json(res, 200, { ok: true, service: 'amexan-clinical-api', time: new Date().toISOString() });
      return;
    }

    if (req.method === 'POST' && path === '/clinical/demo') {
      const body = (await readBody(req)) as { symptom?: string };
      const projection = await withDb(async (db) => {
        const created = await createDemoEncounter(db);
        const cpu = new ClinicalCPU(db);
        return cpu.process({
          patientId: created.patientId,
          encounterId: created.encounterId,
          event: {
            type: 'SYMPTOM_PRESENTED',
            payload: { symptom: body?.symptom ?? 'cough' },
          },
        });
      });
      json(res, 200, { patientId: projection.patientId, encounterId: projection.encounterId, projection });
      return;
    }

    if (req.method === 'POST' && path === '/clinical/events') {
      const body = (await readBody(req)) as {
        patientId?: string;
        encounterId?: string | null;
        event?: ClinicalEvent;
      };
      if (!body?.patientId || !body?.event) {
        json(res, 400, { error: 'patientId and event are required' });
        return;
      }
      const projection = await withDb(async (db) => {
        const cpu = new ClinicalCPU(db);
        return cpu.process({
          patientId: body.patientId as string,
          encounterId: body.encounterId ?? undefined,
          event: body.event as ClinicalEvent,
        });
      });
      broadcast(projection.patientId, projection);
      json(res, 200, projection);
      return;
    }

    if (req.method === 'GET' && path === '/clinical/state') {
      const patientId = url.searchParams.get('patientId');
      if (!patientId) {
        json(res, 400, { error: 'patientId is required' });
        return;
      }
      const projection = await withDb(async (db) => {
        const row = await db.queryOne<{ state: unknown }>(
          `SELECT state FROM cpu.state_snapshot WHERE patient_id = $1 ORDER BY event_id DESC NULLS LAST LIMIT 1`,
          [patientId],
        );
        return row?.state as ClinicalRuntimeProjection | null;
      });
      if (!projection) {
        json(res, 404, { error: 'no projection yet for patient' });
        return;
      }
      json(res, 200, projection);
      return;
    }

    if (req.method === 'GET' && path === '/clinical/timeline') {
      const patientId = url.searchParams.get('patientId');
      if (!patientId) {
        json(res, 400, { error: 'patientId is required' });
        return;
      }
      const rows = await withDb((db) => timelineForPatient(db, patientId));
      json(res, 200, rows);
      return;
    }

    if (req.method === 'GET' && path === '/events/stream') {
      const patientId = url.searchParams.get('patientId');
      writeSseHeaders(res);
      if (patientId) registerStream(patientId, res);
      res.write('retry: 2000\n\n');
      req.on('close', () => res.end());
      return;
    }

    // ---- Static UI (built) ---------------------------------------------------
    if (!path.startsWith('/api')) {
      const staticPath = safeResolve(UI_DIST, path === '/' ? '/index.html' : path);
      if (existsSync(UI_DIST) && staticPath) {
        const ext = extname(staticPath) || '.html';
        const types: Record<string, string> = {
          '.html': 'text/html; charset=utf-8',
          '.js': 'text/javascript',
          '.css': 'text/css',
          '.svg': 'image/svg+xml',
          '.png': 'image/png',
          '.json': 'application/json',
          '.ico': 'image/x-icon',
        };
        if (existsSync(staticPath)) {
          res.writeHead(200, { 'content-type': types[ext] ?? 'application/octet-stream' });
          res.end(await readFile(staticPath));
          return;
        }
      }
    }

    json(res, 404, { error: 'not found' });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!res.headersSent) json(res, 500, { error: message });
    else {
      try {
        res.end();
      } catch {
        // ignore
      }
    }
  }
});

function safeResolve(base: string, requested: string): string | null {
  const candidate = normalize(join(base, requested));
  if (!candidate.startsWith(normalize(base))) return null;
  return candidate;
}

server.listen(PORT, () => {
  console.log(`AMEXAN Clinical Runtime API listening on http://localhost:${PORT}`);
  console.log(`UI served from: ${UI_DIST} (${existsSync(UI_DIST) ? 'present' : 'not built — use npm run dev in /clinical-ui'})`);
});
