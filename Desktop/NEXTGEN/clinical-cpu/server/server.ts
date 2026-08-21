// =============================================================================
// AMEXAN Clinical Runtime API — entry point
//
// PRINCIPLE
// -----------------------------------------------------------------------------
// The UI is NOT the clinical source of truth.
//
// UI
//   ↓
// POST clinical event
//   ↓
// ClinicalCPU
//   ↓
// PostgreSQL transaction / persisted state
//   ↓
// ClinicalRuntimeProjection
//   ↓
// HTTP response + SSE broadcast
//   ↓
// UI / documentation / PDF
//
// This guarantees:
//
//   1. Every clinical mutation is processed by ClinicalCPU.
//   2. The persisted CPU projection is authoritative.
//   3. Realtime clients receive the same projection returned by the API.
//   4. Encounter creation also participates in realtime broadcasting.
//   5. PDF/document generation reads persisted clinical state.
//   6. No clinical reasoning is performed in this HTTP layer.
//   7. The UI never creates its own competing clinical record.
// =============================================================================

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, extname, normalize, relative, isAbsolute } from 'node:path';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { Pool } from 'pg';

import { ClinicalCPU, Db } from '../src/index.js';
import type { Row } from '../src/db.js';

import {
  createDemoEncounter,
  type DemoPatientContext,
} from './demo.js';

import {
  createPersistentEncounter,
  getEncounter,
  listEncounters,
  type StartEncounterBody,
  completeEncounter,
  getEncounterDocument,
} from './encounters.js';

import { timelineForPatient } from './timeline.js';

import {
  handleAdmin,
  AdminRouteError,
  observatorySummary,
} from './admin.js';

import { renderEncounterPdf } from './pdf.js';

import { composePdfContent } from './compose.js';

import {
  broadcast,
  registerStream,
  writeSseHeaders,
} from './sse.js';

import {
  journeyForEncounter,
  journeyForPatient,
} from '../src/observability/EventCore.js';

import { SafetySentinel } from '../src/observability/SafetySentinel.js';

import type {
  ClinicalRuntimeProjection,
  ClinicalEvent,
} from '../src/types.js';

// =============================================================================
// Configuration
// =============================================================================

const PORT = Number(process.env.AMEXAN_API_PORT || 8787);

const pool = new Pool({
  host: process.env.AMEXAN_PGHOST || 'localhost',
  port: Number(process.env.AMEXAN_PGPORT || 5432),
  user: process.env.AMEXAN_PGUSER || 'postgres',
  password: process.env.AMEXAN_PGPASSWORD || 'postgres',
  database: process.env.AMEXAN_PGDATABASE || 'amexan',
  max: 10,
});

const UI_DIST = join(
  import.meta.dirname,
  '..',
  '..',
  'clinical-ui',
  'dist',
);

// =============================================================================
// HTTP helpers
// =============================================================================

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type, authorization',
};

function json(
  res: ServerResponse,
  status: number,
  body: unknown,
): void {
  if (res.headersSent) {
    try {
      res.end();
    } catch {
      // Nothing else can safely be done.
    }
    return;
  }

  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    ...CORS_HEADERS,
  });

  res.end(JSON.stringify(body));
}

function noContent(
  res: ServerResponse,
  status = 204,
): void {
  if (res.headersSent) {
    try {
      res.end();
    } catch {
      // ignore
    }
    return;
  }

  res.writeHead(status, CORS_HEADERS);
  res.end();
}

async function readBody(
  req: IncomingMessage,
): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;

  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk)
      ? chunk
      : Buffer.from(chunk);

    size += buffer.length;

    if (size > 1_000_000) {
      throw new Error('payload too large');
    }

    chunks.push(buffer);
  }

  if (chunks.length === 0) {
    return {};
  }

  const raw = Buffer
    .concat(chunks)
    .toString('utf-8')
    .trim();

  if (!raw) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    throw new Error('invalid JSON payload');
  }
}

async function withDb<T>(
  fn: (db: Db) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();

  try {
    return await fn(new Db(client));
  } finally {
    client.release();
  }
}

// =============================================================================
// Request validation helpers
// =============================================================================

function requiredString(
  value: unknown,
  field: string,
): string {
  if (
    typeof value !== 'string' ||
    value.trim().length === 0
  ) {
    throw new Error(`${field} is required`);
  }

  return value.trim();
}

function optionalString(
  value: unknown,
): string | undefined {
  if (
    typeof value !== 'string' ||
    value.trim().length === 0
  ) {
    return undefined;
  }

  return value.trim();
}

function decodePathId(value: string): string {
  return decodeURIComponent(value);
}

// =============================================================================
// Clinical projection broadcasting
// =============================================================================
//
// IMPORTANT:
//
// The projection is broadcast ONLY after ClinicalCPU has successfully returned.
//
// Therefore:
//
//     persisted clinical state
//             ===
//     HTTP response
//             ===
//     realtime SSE state
//
// There is no separate UI state to reconcile.
//

function publishProjection(
  projection: ClinicalRuntimeProjection,
): void {
  broadcast(
    projection.patientId,
    projection,
  );
}

// =============================================================================
// Latest persisted projection
// =============================================================================

async function latestProjectionForPatient(
  db: Db,
  patientId: string,
): Promise<ClinicalRuntimeProjection | null> {
  const row = await db.queryOne<Row>(
    `
      SELECT state
        FROM cpu.state_snapshot
       WHERE patient_id = $1
       ORDER BY id DESC
       LIMIT 1
    `,
    [patientId],
  );

  if (!row?.state) {
    return null;
  }

  return row.state as ClinicalRuntimeProjection;
}

async function latestProjectionForEncounter(
  db: Db,
  patientId: string,
  encounterId: string,
): Promise<ClinicalRuntimeProjection | null> {
  const row = await db.queryOne<Row>(
    `
      SELECT state
        FROM cpu.state_snapshot
       WHERE patient_id = $1
         AND encounter_id = $2
       ORDER BY id DESC
       LIMIT 1
    `,
    [patientId, encounterId],
  );

  if (!row?.state) {
    return null;
  }

  return row.state as ClinicalRuntimeProjection;
}

// =============================================================================
// Static file resolution
// =============================================================================
//
// Do not use:
//
//   candidate.startsWith(base)
//
// because:
//
//   /app/dist-evil
//
// also starts with:
//
//   /app/dist
//
// Instead resolve using path.relative().
//

function safeResolve(
  base: string,
  requested: string,
): string | null {
  const cleanRequested = requested.startsWith('/')
    ? requested.slice(1)
    : requested;

  const candidate = normalize(
    join(base, cleanRequested),
  );

  const rel = relative(
    normalize(base),
    candidate,
  );

  if (
    rel === '' ||
    rel === '..' ||
    rel.startsWith(`..${process.platform === 'win32' ? '\\' : '/'}`) ||
    isAbsolute(rel)
  ) {
    return null;
  }

  return candidate;
}

// =============================================================================
// Content types
// =============================================================================

const STATIC_CONTENT_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.json': 'application/json; charset=utf-8',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

// =============================================================================
// Server
// =============================================================================

const server = createServer(
  async (req, res) => {
    const url = new URL(
      req.url ?? '/',
      `http://${req.headers.host ?? 'localhost'}`,
    );

    // -------------------------------------------------------------------------
    // Route normalisation
    // -------------------------------------------------------------------------

    let path: string;

    if (
      url.pathname.startsWith('/api/control-plane')
    ) {
      const rest =
        url.pathname
          .slice('/api/control-plane'.length)
          .replace(/^\/+/, '') || '/';

      path = rest.startsWith('events/')
        ? `/admin/${rest}`
        : `/${rest}`;
    } else {
      path = url.pathname.startsWith('/api')
        ? url.pathname.slice(4) || '/'
        : url.pathname;
    }

    try {
      // =======================================================================
      // OPTIONS
      // =======================================================================

      if (req.method === 'OPTIONS') {
        noContent(res);
        return;
      }

      // =======================================================================
      // HEALTH
      // =======================================================================

      if (
        req.method === 'GET' &&
        path === '/health'
      ) {
        json(res, 200, {
          ok: true,
          service: 'amexan-clinical-api',
          time: new Date().toISOString(),
        });
        return;
      }

      // =======================================================================
      // DEMO ENCOUNTER
      // =======================================================================

      if (
        req.method === 'POST' &&
        path === '/clinical/demo'
      ) {
        const body = (await readBody(req)) as {
          symptom?: string;
          context?: DemoPatientContext;
        };

        const result = await withDb(
          async (db) => {
            const created =
              await createDemoEncounter(
                db,
                body?.context ?? {},
              );

            const cpu = new ClinicalCPU(db);

            const projection =
              await cpu.process({
                patientId: created.patientId,
                encounterId: created.encounterId,
                event: {
                  type: 'SYMPTOM_PRESENTED',
                  payload: {
                    symptom:
                      body?.symptom ??
                      'cough',
                  },
                },
              });

            return {
              patientId: created.patientId,
              encounterId: created.encounterId,
              projection,
            };
          },
        );

        publishProjection(result.projection);

        json(res, 200, result);
        return;
      }

      // =======================================================================
      // CREATE ENCOUNTER
      // =======================================================================

      if (
        req.method === 'POST' &&
        path === '/clinical/encounters'
      ) {
        const body =
          (await readBody(req)) as StartEncounterBody;

        const created =
          await withDb((db) =>
            createPersistentEncounter(
              db,
              body,
            ),
          );

        const projection =
          await withDb(async (db) => {
            const cpu = new ClinicalCPU(db);

            return cpu.process({
              patientId:
                created.patientId,

              encounterId:
                created.encounterId,

              event: {
                type: 'ENCOUNTER_CREATED',

                payload: {
                  department:
                    body.department ?? null,

                  encounterType:
                    body.encounterTypeCode ??
                    body.encounterType ??
                    null,

                  presentingComplaintCodes:
                    body.presentingComplaintCodes ??
                    [],
                },
              },
            });
          });

        // CRITICAL:
        // Encounter creation is a clinical mutation.
        // It must therefore enter the exact same realtime channel
        // as every later event.
        publishProjection(projection);

        json(res, 200, {
          patientId:
            created.patientId,

          encounterId:
            created.encounterId,

          projection,
        });

        return;
      }

      // =======================================================================
      // LIST ENCOUNTERS
      // =======================================================================

      if (
        req.method === 'GET' &&
        path === '/clinical/encounters'
      ) {
        const rows =
          await withDb((db) =>
            listEncounters(db),
          );

        json(res, 200, rows);
        return;
      }

      // =======================================================================
      // GET ENCOUNTER
      // =======================================================================

      const encounterById =
        path.match(
          /^\/clinical\/encounters\/([^/]+)$/,
        );

      if (
        req.method === 'GET' &&
        encounterById
      ) {
        const encounterId =
          decodePathId(encounterById[1]);

        const snapshot =
          await withDb((db) =>
            getEncounter(
              db,
              encounterId,
            ),
          );

        if (!snapshot) {
          json(res, 404, {
            error: 'Encounter not found',
          });
          return;
        }

        json(res, 200, snapshot);
        return;
      }

      // =======================================================================
      // COMPLETE ENCOUNTER
      // =======================================================================

      const encounterComplete =
        path.match(
          /^\/clinical\/encounters\/([^/]+)\/complete$/,
        );

      if (
        req.method === 'POST' &&
        encounterComplete
      ) {
        const encounterId =
          decodePathId(
            encounterComplete[1],
          );

        const result =
          await withDb((db) =>
            completeEncounter(
              db,
              encounterId,
            ),
          );

        if (!result) {
          json(res, 404, {
            error: 'Encounter not found',
          });
          return;
        }

        // If completion returns a projection,
        // publish it as the authoritative final state.
        if (
          typeof result === 'object' &&
          result !== null &&
          'projection' in result
        ) {
          const projection =
            (
              result as {
                projection?: ClinicalRuntimeProjection;
              }
            ).projection;

          if (projection) {
            publishProjection(
              projection,
            );
          }
        }

        json(res, 200, result);
        return;
      }

      // =======================================================================
      // ENCOUNTER DOCUMENT
      // =======================================================================

      const encounterDocument =
        path.match(
          /^\/clinical\/encounters\/([^/]+)\/document$/,
        );

      if (
        req.method === 'GET' &&
        encounterDocument
      ) {
        const encounterId =
          decodePathId(
            encounterDocument[1],
          );

        const document =
          await withDb((db) =>
            getEncounterDocument(
              db,
              encounterId,
            ),
          );

        if (!document) {
          json(res, 404, {
            error: 'Document not found',
          });
          return;
        }

        json(res, 200, document);
        return;
      }

      // =======================================================================
      // LATEST STATE — PATIENT
      // =======================================================================
      //
      // This route was documented in the original API but was missing.
      //
      // GET /clinical/state?patientId=...
      //

      if (
        req.method === 'GET' &&
        path === '/clinical/state'
      ) {
        const patientId =
          url.searchParams.get(
            'patientId',
          );

        if (!patientId) {
          json(res, 400, {
            error:
              'patientId is required',
          });
          return;
        }

        const projection =
          await withDb((db) =>
            latestProjectionForPatient(
              db,
              patientId,
            ),
          );

        if (!projection) {
          json(res, 404, {
            error:
              'No clinical state found',
          });
          return;
        }

        json(res, 200, projection);
        return;
      }

      // =======================================================================
      // LATEST STATE — ENCOUNTER
      // =======================================================================

      if (
        req.method === 'GET' &&
        path === '/clinical/state/encounter'
      ) {
        const patientId =
          url.searchParams.get(
            'patientId',
          );

        const encounterId =
          url.searchParams.get(
            'encounterId',
          );

        if (!patientId) {
          json(res, 400, {
            error:
              'patientId is required',
          });
          return;
        }

        if (!encounterId) {
          json(res, 400, {
            error:
              'encounterId is required',
          });
          return;
        }

        const projection =
          await withDb((db) =>
            latestProjectionForEncounter(
              db,
              patientId,
              encounterId,
            ),
          );

        if (!projection) {
          json(res, 404, {
            error:
              'No clinical state found',
          });
          return;
        }

        json(res, 200, projection);
        return;
      }

      // =======================================================================
      // PDF EXPORT
      // =======================================================================

      if (
        req.method === 'GET' &&
        path === '/clinical/export/pdf'
      ) {
        const encounterId =
          url.searchParams.get(
            'encounterId',
          );

        if (!encounterId) {
          json(res, 400, {
            error:
              'encounterId is required',
          });
          return;
        }

        const snapshot =
          await withDb((db) =>
            getEncounter(
              db,
              encounterId,
            ),
          );

        if (!snapshot) {
          json(res, 404, {
            error:
              'Encounter not found',
          });
          return;
        }

        // The PDF generator receives only persisted
        // clinical facts. It does not receive arbitrary
        // UI state.
        //
        // The C/C list and the HPI prose are composed from
        // the stored PRESENTING_COMPLAINT summary + facts
        // using the same rules as the live documentation,
        // so the export looks like the live note.
        const composed = composePdfContent(
          snapshot,
        );

        const pdf =
          renderEncounterPdf({
            encounterId:
              snapshot.encounterId,

            department:
              snapshot.context.department,

            sex:
              snapshot.context.sex,

            birthDate:
              snapshot.context.birthDate,

            patientName:
              composed.patientName,

            mrn: composed.mrn,

            age: composed.age,

            complaints:
              composed.complaints,

            hpi: composed.hpi,

            presentingComplaint:
              snapshot.context
                .presentingComplaint,

            facts:
              snapshot.facts.map(
                (fact) => ({
                  factCode:
                    fact.factCode,

                  section:
                    fact.section,

                  text:
                    fact.text,

                  numeric:
                    fact.numeric,

                  boolean:
                    fact.boolean,

                  unitCode:
                    fact.unitCode,
                }),
              ),
          });

        res.writeHead(200, {
          'content-type':
            'application/pdf',

          'content-disposition':
            `inline; filename="amexan-encounter-${snapshot.encounterId}.pdf"`,

          'content-length':
            pdf.length,

          ...CORS_HEADERS,
        });

        res.end(pdf);
        return;
      }

      // =======================================================================
      // CLINICAL EVENTS
      // =======================================================================

      if (
        req.method === 'POST' &&
        path === '/clinical/events'
      ) {
        const body =
          (await readBody(req)) as {
            patientId?: unknown;
            encounterId?: unknown;
            event?: unknown;
          };

        const patientId =
          requiredString(
            body.patientId,
            'patientId',
          );

        const encounterId =
          optionalString(
            body.encounterId,
          );

        if (
          !body.event ||
          typeof body.event !== 'object'
        ) {
          json(res, 400, {
            error:
              'event is required',
          });
          return;
        }

        const event =
          body.event as ClinicalEvent;

        // ---------------------------------------------------------------------
        // ClinicalCPU is the ONLY writer/clinical interpreter.
        // ---------------------------------------------------------------------

        const projection =
          await withDb(async (db) => {
            const cpu =
              new ClinicalCPU(db);

            return cpu.process({
              patientId,
              encounterId,
              event,
            });
          });

        // ---------------------------------------------------------------------
        // Broadcast ONLY after CPU processing succeeds.
        //
        // This is critical:
        //
        //     DB commit
        //         ↓
        //     projection
        //         ↓
        //     SSE
        //
        // Never:
        //
        //     SSE
        //         ↓
        //     DB
        //
        // because that creates a stale realtime state.
        // ---------------------------------------------------------------------

        publishProjection(
          projection,
        );

        json(
          res,
          200,
          projection,
        );

        return;
      }

      // =======================================================================
      // PATIENT TIMELINE
      // =======================================================================

      if (
        req.method === 'GET' &&
        path === '/clinical/timeline'
      ) {
        const patientId =
          url.searchParams.get(
            'patientId',
          );

        if (!patientId) {
          json(res, 400, {
            error:
              'patientId is required',
          });
          return;
        }

        const rows =
          await withDb((db) =>
            timelineForPatient(
              db,
              patientId,
            ),
          );

        json(res, 200, rows);
        return;
      }

      // =======================================================================
      // SSE REALTIME STREAM
      // =======================================================================

      if (
        req.method === 'GET' &&
        (
          path === '/events/stream' ||
          path === '/clinical/events/stream'
        )
      ) {
        const patientId =
          url.searchParams.get(
            'patientId',
          );

        const encounterId =
          url.searchParams.get(
            'encounterId',
          );

        if (!patientId) {
          json(res, 400, {
            error:
              'patientId is required',
          });
          return;
        }

        writeSseHeaders(res);

        registerStream(
          patientId,
          res,
        );

        // Tell the browser how quickly
        // it should reconnect.
        res.write(
          'retry: 2000\n\n',
        );

        // ---------------------------------------------------------------------
        // Initial state.
        //
        // This eliminates the classic:
        //
        // "I opened the encounter but nothing appears until I change something."
        // ---------------------------------------------------------------------

        const latest =
          await withDb((db) =>
            encounterId
              ? latestProjectionForEncounter(
                  db,
                  patientId,
                  encounterId,
                )
              : latestProjectionForPatient(
                  db,
                  patientId,
                ),
          );

        if (latest) {
          res.write(
            `data: ${JSON.stringify({
              type: 'projection',
              projection: latest,
            })}\n\n`,
          );
        }

        // Keep-alive.
        //
        // This prevents proxies/load balancers from
        // silently killing an otherwise idle stream.
        const heartbeat =
          setInterval(() => {
            if (!res.writableEnded) {
              try {
                res.write(
                  ': heartbeat\n\n',
                );
              } catch {
                // Connection is gone.
              }
            }
          }, 15_000);

        req.on('close', () => {
          clearInterval(
            heartbeat,
          );

          try {
            res.end();
          } catch {
            // ignore
          }
        });

        return;
      }

      // =======================================================================
      // OBSERVATORY
      // =======================================================================

      if (
        req.method === 'GET' &&
        path === '/observatory'
      ) {
        const summary =
          await withDb((db) =>
            observatorySummary(db),
          );

        json(res, 200, summary);
        return;
      }

      // =======================================================================
      // EVENT JOURNEY — ENCOUNTER
      // =======================================================================

      const journeyEncounter =
        path.match(
          /^\/journey\/encounter\/([^/]+)$/,
        );

      if (
        req.method === 'GET' &&
        journeyEncounter
      ) {
        const encounterId =
          decodePathId(
            journeyEncounter[1],
          );

        const events =
          await withDb((db) =>
            journeyForEncounter(
              db,
              encounterId,
            ),
          );

        json(res, 200, events);
        return;
      }

      // =======================================================================
      // EVENT JOURNEY — PATIENT
      // =======================================================================

      const journeyPatient =
        path.match(
          /^\/journey\/patient\/([^/]+)$/,
        );

      if (
        req.method === 'GET' &&
        journeyPatient
      ) {
        const patientId =
          decodePathId(
            journeyPatient[1],
          );

        const events =
          await withDb((db) =>
            journeyForPatient(
              db,
              patientId,
            ),
          );

        json(res, 200, events);
        return;
      }

      // =======================================================================
      // SAFETY CHECK
      // =======================================================================

      if (
        req.method === 'POST' &&
        path === '/clinical/safety/check'
      ) {
        const body =
          (await readBody(req)) as Record<
            string,
            unknown
          >;

        const result =
          await withDb((db) =>
            new SafetySentinel(
              db,
            ).evaluateDose({
              patientId:
                body.patientId as
                  | string
                  | undefined,

              encounterId:
                body.encounterId as
                  | string
                  | undefined,

              medicationCode:
                body.medicationCode as
                  | string,

              medicationName:
                body.medicationName as
                  | string
                  | undefined,

              suggestedDose:
                body.suggestedDose as
                  | number
                  | undefined,

              enteredDose:
                body.enteredDose as
                  | number
                  | undefined,

              doseUnit:
                body.doseUnit as
                  | string
                  | undefined,

              route:
                body.route as
                  | string
                  | undefined,

              frequency:
                body.frequency as
                  | string
                  | undefined,

              weightKg:
                body.weightKg as
                  | number
                  | undefined,

              ageYears:
                body.ageYears as
                  | number
                  | undefined,

              clinicianId:
                body.clinicianId as
                  | string
                  | undefined,

              source:
                body.source as
                  | string
                  | undefined,
            }),
          );

        json(
          res,
          200,
          result,
        );

        return;
      }

      // =======================================================================
      // ALERTS
      // =======================================================================

      const encounterAlerts =
        path.match(
          /^\/clinical\/encounters\/([^/]+)\/alerts$/,
        );

      if (
        req.method === 'GET' &&
        encounterAlerts
      ) {
        interface EncounterAlertRow
          extends Row {
          id: string;
          alert_code: string;
          alert_type: string;
          severity: string;
          title: string;
          message: string;
          acknowledged: boolean;
          resolved: boolean;
          created_at: Date;
        }

        const encounterId =
          decodePathId(
            encounterAlerts[1],
          );

        const rows =
          await withDb((db) =>
            db.query<EncounterAlertRow>(
              `
                SELECT
                  id,
                  alert_code,
                  alert_type,
                  severity,
                  title,
                  message,
                  acknowledged,
                  resolved,
                  created_at
                FROM clinical.alert
                WHERE encounter_id = $1
                  AND resolved = false
                ORDER BY created_at DESC
              `,
              [encounterId],
            ),
          );

        json(
          res,
          200,
          rows.map(
            (row) => ({
              id:
                row.id,

              code:
                row.alert_code,

              type:
                row.alert_type,

              severity:
                row.severity,

              title:
                row.title,

              message:
                row.message,

              acknowledged:
                row.acknowledged,

              createdAt:
                new Date(
                  row.created_at,
                ).toISOString(),
            }),
          ),
        );

        return;
      }

      // =======================================================================
      // ACKNOWLEDGE ALERT
      // =======================================================================

      const alertAck =
        path.match(
          /^\/clinical\/alerts\/([^/]+)\/acknowledge$/,
        );

      if (
        req.method === 'POST' &&
        alertAck
      ) {
        const body =
          (await readBody(req)) as {
            acknowledgedBy?: string;
          };

        const alertId =
          decodePathId(
            alertAck[1],
          );

        const ok =
          await withDb((db) =>
            new SafetySentinel(
              db,
            ).acknowledgeAlert(
              alertId,
              body?.acknowledgedBy ??
                null,
            ),
          );

        json(
          res,
          ok ? 200 : 404,
          ok
            ? {
                acknowledged:
                  true,
              }
            : {
                error:
                  'Alert not found or already acknowledged',
              },
        );

        return;
      }

      // =======================================================================
      // ADMIN CONTROL PLANE
      // =======================================================================

      if (
        path.startsWith('/admin')
      ) {
        if (req.method !== 'GET') {
          json(res, 405, {
            error:
              'method not allowed',
          });
          return;
        }

        try {
          const result =
            await withDb((db) =>
              handleAdmin(
                db,
                req.method ?? 'GET',
                path,
                url,
              ),
            );

          json(
            res,
            result.status,
            result.body,
          );
        } catch (error) {
          if (
            error instanceof
            AdminRouteError
          ) {
            json(res, 404, {
              error:
                error.message,
            });
            return;
          }

          throw error;
        }

        return;
      }

      // =======================================================================
      // STATIC UI
      // =======================================================================

      if (
        !path.startsWith('/api')
      ) {
        const requested =
          path === '/'
            ? '/index.html'
            : path;

        const staticPath =
          safeResolve(
            UI_DIST,
            requested,
          );

        if (
          existsSync(UI_DIST) &&
          staticPath &&
          existsSync(staticPath)
        ) {
          const ext =
            extname(
              staticPath,
            ).toLowerCase();

          res.writeHead(
            200,
            {
              'content-type':
                STATIC_CONTENT_TYPES[
                  ext
                ] ??
                'application/octet-stream',
            },
          );

          res.end(
            await readFile(
              staticPath,
            ),
          );

          return;
        }
      }

      // =======================================================================
      // NOT FOUND
      // =======================================================================

      json(res, 404, {
        error:
          'not found',
      });
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : String(error);

      console.error(
        '[SERVER ERROR]',
        req.method,
        path,
        message,
        error instanceof Error
          ? error.stack
          : undefined,
      );

      // NEVER expose internal stack traces
      // through the clinical API.
      if (!res.headersSent) {
        json(res, 500, {
          error:
            message,
        });
      } else {
        try {
          res.end();
        } catch {
          // ignore
        }
      }
    }
  },
);

// =============================================================================
// Graceful shutdown
// =============================================================================

async function shutdown(
  signal: string,
): Promise<void> {
  console.log(
    `[AMEXAN] ${signal} received; shutting down`,
  );

  server.close(
    async () => {
      try {
        await pool.end();
      } finally {
        process.exit(0);
      }
    },
  );

  // Do not allow a broken connection
  // to hold the process forever.
  setTimeout(
    () => process.exit(1),
    10_000,
  ).unref();
}

process.once(
  'SIGINT',
  () => {
    void shutdown('SIGINT');
  },
);

process.once(
  'SIGTERM',
  () => {
    void shutdown('SIGTERM');
  },
);

// =============================================================================
// Startup
// =============================================================================

server.listen(
  PORT,
  () => {
    console.log(
      `AMEXAN Clinical Runtime API listening on http://localhost:${PORT}`,
    );

    console.log(
      `UI served from: ${UI_DIST} (${
        existsSync(UI_DIST)
          ? 'present'
          : 'not built — use npm run dev in /clinical-ui'
      })`,
    );
  },
);