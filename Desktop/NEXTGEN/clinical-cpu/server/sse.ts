// =============================================================================
// Server-Sent Events — realtime projection (4.38). When any event lands, the
// new projection is pushed to every authorized client watching that patient.
// =============================================================================

import type { ServerResponse } from 'node:http';
import type { ClinicalRuntimeProjection } from '../src/types.js';

const subscribers = new Map<string, Set<ServerResponse>>();

export function writeSseHeaders(res: ServerResponse): void {
  res.writeHead(200, {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache',
    connection: 'keep-alive',
    'access-control-allow-origin': '*',
  });
}

export function registerStream(patientId: string, res: ServerResponse): void {
  let set = subscribers.get(patientId);
  if (!set) {
    set = new Set();
    subscribers.set(patientId, set);
  }
  set.add(res);
  res.on('close', () => {
    set!.delete(res);
    if (set!.size === 0) subscribers.delete(patientId);
  });
}

export function broadcast(patientId: string, projection: ClinicalRuntimeProjection): void {
  const set = subscribers.get(patientId);
  if (!set) return;
  const body = `data: ${JSON.stringify(projection)}\n\n`;
  for (const res of set) {
    try {
      res.write(body);
    } catch {
      set.delete(res);
    }
  }
}
