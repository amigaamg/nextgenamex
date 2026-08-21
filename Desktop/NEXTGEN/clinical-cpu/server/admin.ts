// =============================================================================
// AMEXAN Admin Control Plane API — /admin/*
// =============================================================================
//
// The read-only operational surface for administrators. It surfaces the
// platform's registry and provenance tables (system, configuration, governance,
// security, cpu.event_log) exactly as PostgreSQL holds them. Nothing here
// mutates clinical state; the mutating surfaces (encounters, safety, config)
// live behind their own routes.
//
//   GET /admin/summary          overall control-plane dashboard
//   GET /admin/engines          engine registry + versions
//   GET /admin/engines/:code    one engine with its version history
//   GET /admin/health           health checks (system.health_check)
//   GET /admin/jobs             scheduled jobs (system.job)
//   GET /admin/feature-flags    feature flags (system.feature_flag)
//   GET /admin/config           configuration scopes + active configurations
//   GET /admin/config/:key      one configuration + versions + activations
//   GET /admin/versions         system version registry (governance.system_version)
//   GET /admin/audit            audit events (governance.audit_event)
//   GET /admin/events           event explorer over cpu.event_log
//   GET /admin/events/:id       one event with its full payload
//   GET /admin/security         RBAC overview (roles + permissions)
//   GET /admin/database         database health + migration registry (§61)
//   GET /admin/runtime          CPU run/processing-error/checkpoint state
//   GET /admin/workflow         workflow instances, tasks, queues
//   GET /admin/incidents        incident registry (§59)
//   GET /admin/incidents/:id    one incident with its timeline
//   GET /admin/integrations     interoperability connections + messages
//   GET /admin/notifications    communication messages + deliveries
//   GET /admin/analytics        operational analytics (Phase G)
//   GET /admin/catalogues       facility service catalogue (operational registry)
//   GET /admin/catalogues/:code one service's operational definition
//   GET /admin/assets           facility asset intelligence (care dependency)
//   GET /admin/assets/:code     one asset with its care-dependency impact
// =============================================================================

import type { Db, Row } from '../src/db.js';
import {
  serviceCatalogueDetail,
  serviceCatalogueOverview,
} from './catalogue.js';
import {
  assetIntelligenceDetail,
  assetIntelligenceOverview,
} from './assets.js';

// =============================================================================
// HELPERS
// =============================================================================

export class AdminRouteError extends Error {}

function pagination(url: URL): { limit: number; offset: number } {
  const limit = Math.min(Math.max(Number(url.searchParams.get('limit') ?? 50), 1), 500);
  const offset = Math.max(Number(url.searchParams.get('offset') ?? 0), 0);
  return { limit, offset };
}

interface CountRow extends Row {
  n: string;
}

async function count(db: Db, sql: string, params: unknown[] = []): Promise<number> {
  const row = await db.queryOne<CountRow>(sql, params);
  return Number(row?.n ?? 0);
}

// =============================================================================
// ROUTER
// =============================================================================

export async function handleAdmin(
  db: Db,
  method: string,
  path: string,
  url: URL,
): Promise<{ status: number; body: unknown }> {
  if (method !== 'GET') {
    return { status: 405, body: { error: 'method not allowed' } };
  }

  if (path === '/admin/summary') {
    return { status: 200, body: await adminSummary(db) };
  }

  if (path === '/admin/engines') {
    return { status: 200, body: await listEngines(db) };
  }

  const engineByCode = path.match(/^\/admin\/engines\/([^/]+)$/);
  if (engineByCode) {
    const detail = await engineDetail(db, decodeURIComponent(engineByCode[1]));
    if (!detail) return { status: 404, body: { error: 'Engine not found' } };
    return { status: 200, body: detail };
  }

  if (path === '/admin/health') {
    return { status: 200, body: await listHealthChecks(db, url) };
  }

  if (path === '/admin/jobs') {
    return { status: 200, body: await listJobs(db) };
  }

  if (path === '/admin/feature-flags') {
    return { status: 200, body: await listFeatureFlags(db) };
  }

  if (path === '/admin/config') {
    return { status: 200, body: await listConfiguration(db) };
  }

  const configByKey = path.match(/^\/admin\/config\/([^/]+)$/);
  if (configByKey) {
    const detail = await configDetail(db, decodeURIComponent(configByKey[1]));
    if (!detail) return { status: 404, body: { error: 'Configuration not found' } };
    return { status: 200, body: detail };
  }

  if (path === '/admin/versions') {
    return { status: 200, body: await listSystemVersions(db) };
  }

  if (path === '/admin/audit') {
    return { status: 200, body: await listAuditEvents(db, url) };
  }

  if (path === '/admin/events') {
    return { status: 200, body: await listEvents(db, url) };
  }

  const eventById = path.match(/^\/admin\/events\/([^/]+)$/);
  if (eventById) {
    const detail = await eventDetail(db, Number(eventById[1]));
    if (!detail) return { status: 404, body: { error: 'Event not found' } };
    return { status: 200, body: detail };
  }

  if (path === '/admin/security') {
    return { status: 200, body: await securityOverview(db) };
  }

  if (path === '/admin/database') {
    return { status: 200, body: await databaseOverview(db) };
  }

  if (path === '/admin/runtime') {
    return { status: 200, body: await runtimeOverview(db, url) };
  }

  if (path === '/admin/workflow') {
    return { status: 200, body: await workflowOverview(db, url) };
  }

  if (path === '/admin/incidents') {
    return { status: 200, body: await listIncidents(db, url) };
  }

  const incidentById = path.match(/^\/admin\/incidents\/([^/]+)$/);
  if (incidentById) {
    const detail = await incidentDetail(db, incidentById[1]);
    if (!detail) return { status: 404, body: { error: 'Incident not found' } };
    return { status: 200, body: detail };
  }

  if (path === '/admin/integrations') {
    return { status: 200, body: await integrationsOverview(db) };
  }

  if (path === '/admin/notifications') {
    return { status: 200, body: await notificationsOverview(db, url) };
  }

  if (path === '/admin/analytics') {
    return { status: 200, body: await analyticsOverview(db) };
  }

  if (path === '/admin/catalogues') {
    return { status: 200, body: serviceCatalogueOverview() };
  }

  const catalogueByCode = path.match(/^\/admin\/catalogues\/([^/]+)$/);
  if (catalogueByCode) {
    const detail = serviceCatalogueDetail(decodeURIComponent(catalogueByCode[1]));
    if (!detail) return { status: 404, body: { error: 'Service not found in catalogue' } };
    return { status: 200, body: detail };
  }

  if (path === '/admin/assets') {
    return { status: 200, body: assetIntelligenceOverview() };
  }

  const assetByCode = path.match(/^\/admin\/assets\/([^/]+)$/);
  if (assetByCode) {
    const detail = assetIntelligenceDetail(decodeURIComponent(assetByCode[1]));
    if (!detail) return { status: 404, body: { error: 'Asset not found' } };
    return { status: 200, body: detail };
  }

  throw new AdminRouteError('unknown admin route');
}

// =============================================================================
// SUMMARY
// =============================================================================

async function adminSummary(db: Db): Promise<Record<string, unknown>> {
  const [
    engines,
    engineVersions,
    activeSystemVersions,
    featureFlags,
    jobs,
    configs,
    configVersions,
    auditEvents,
    eventLog,
    activeEncounters,
    openAlerts,
    users,
    rulesExecuted,
    reasoningRuns,
    knowledgeObjects,
  ] = await Promise.all([
    count(db, 'SELECT count(*) AS n FROM system.engine'),
    count(db, 'SELECT count(*) AS n FROM system.engine_version'),
    count(db, 'SELECT count(*) AS n FROM governance.system_version WHERE is_active = true'),
    count(db, 'SELECT count(*) AS n FROM system.feature_flag'),
    count(db, 'SELECT count(*) AS n FROM system.job'),
    count(db, 'SELECT count(*) AS n FROM configuration.configuration'),
    count(db, 'SELECT count(*) AS n FROM configuration.configuration_version'),
    count(db, 'SELECT count(*) AS n FROM governance.audit_event'),
    count(db, 'SELECT count(*) AS n FROM cpu.event_log'),
    count(
      db,
      `SELECT count(*) AS n FROM encounter.encounter WHERE status_code NOT IN ('completed','cancelled','planned')`,
    ),
    count(db, 'SELECT count(*) AS n FROM clinical.alert WHERE resolved = false'),
    count(db, 'SELECT count(*) AS n FROM identity.user_account'),
    count(db, 'SELECT count(*) AS n FROM governance.rule_execution'),
    count(db, 'SELECT count(*) AS n FROM knowledge.reasoning_run'),
    count(db, 'SELECT count(*) AS n FROM governance.knowledge_object'),
  ]);

  const recentEvents = await db.query<Row>(
    `SELECT id, event_type, source_type, patient_id, encounter_id, occurred_at
       FROM cpu.event_log
      ORDER BY occurred_at DESC
      LIMIT 10`,
  );

  return {
    generatedAt: new Date().toISOString(),
    registry: {
      engines,
      engineVersions,
      activeSystemVersions,
      featureFlags,
      jobs,
      knowledgeObjects,
    },
    configuration: {
      configurations: configs,
      configurationVersions: configVersions,
    },
    governance: {
      auditEvents,
      ruleExecutions: rulesExecuted,
      reasoningRuns,
    },
    clinical: {
      activeEncounters,
      openAlerts,
      eventLog,
    },
    identity: { userAccounts: users },
    recentEvents: recentEvents.map((r) => ({
      id: Number(r.id),
      eventType: r.event_type,
      sourceType: r.source_type,
      patientId: r.patient_id,
      encounterId: r.encounter_id,
      occurredAt: r.occurred_at,
    })),
  };
}

// =============================================================================
// OBSERVATORY
// =============================================================================

export async function observatorySummary(db: Db): Promise<Record<string, unknown>> {
  const [
    patientCount,
    encounterTotal,
    activeEncounters,
    completedEncounters,
    factCount,
    eventTotal,
    eventsLastMinute,
    eventsLastHour,
    eventsToday,
    engineRows,
    engineHealthy,
    engineDegraded,
    engineFailed,
    engineStates,
    openAlerts,
    acknowledgedAlerts,
    criticalAlerts,
    highAlerts,
    recentAlertRows,
    decisions,
  ] = await Promise.all([
    count(db, 'SELECT count(*) AS n FROM clinical.patients'),
    count(db, 'SELECT count(*) AS n FROM encounter.encounter'),
    count(
      db,
      `SELECT count(*) AS n FROM encounter.encounter WHERE status_code NOT IN ('completed','cancelled','planned')`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM encounter.encounter WHERE status_code = 'completed'`,
    ),
    count(db, 'SELECT count(*) AS n FROM clinical.fact'),
    count(db, 'SELECT count(*) AS n FROM cpu.event_log'),
    count(
      db,
      `SELECT count(*) AS n FROM cpu.event_log WHERE occurred_at >= now() - interval '1 minute'`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM cpu.event_log WHERE occurred_at >= now() - interval '1 hour'`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM cpu.event_log WHERE occurred_at >= now() - interval '24 hours'`,
    ),
    db.query<Row>(
      `SELECT code, name, status FROM system.engine ORDER BY code`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM system.engine WHERE status IN ('active','starting')`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM system.engine WHERE status = 'degraded'`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM system.engine WHERE status = 'failed'`,
    ),
    db.query<Row>(
      `SELECT e.code AS engine, e.name AS engine_name, e.status,
              (SELECT count(*) FROM cpu.event_log l WHERE l.source_id = e.code::text) AS completed
         FROM system.engine e
        ORDER BY e.code`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM clinical.alert WHERE resolved = false`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM clinical.alert WHERE acknowledged = true`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM clinical.alert WHERE severity = 'CRITICAL' AND resolved = false`,
    ),
    count(
      db,
      `SELECT count(*) AS n FROM clinical.alert WHERE severity = 'HIGH' AND resolved = false`,
    ),
    db.query<Row>(
      `SELECT id, patient_id, encounter_id, alert_code, alert_type, severity,
              title, message, acknowledged, resolved, created_at
         FROM clinical.alert
        ORDER BY created_at DESC
        LIMIT 10`,
    ),
    db.query<Row>(
      `SELECT status, count(*)::text AS n FROM cpu.decision GROUP BY status`,
    ),
  ]);

  const decisionsByStatus = new Map<string, number>();
  for (const row of decisions ?? []) {
    decisionsByStatus.set(String(row.status), Number(row.n));
  }

  const decisionTotal = Array.from(decisionsByStatus.values()).reduce(
    (sum, value) => sum + value,
    0,
  );

  return {
    generatedAt: new Date().toISOString(),
    totals: {
      patients: patientCount,
      encounters: encounterTotal,
      activeEncounters,
      completedEncounters,
      facts: factCount,
      eventsTotal: eventTotal,
    },
    throughput: {
      eventsLastMinute,
      eventsLastHour,
      eventsToday,
    },
    engines: {
      healthy: engineHealthy,
      degraded: engineDegraded,
      failed: engineFailed,
      engineStates: (engineStates ?? []).map((r) => ({
        engine: r.engine,
        status: r.status,
        completed: Number(r.completed ?? 0),
        failed: 0,
        lastMs: null,
      })),
    },
    safety: {
      openAlerts,
      acknowledgedAlerts,
      criticalAlerts,
      highAlerts,
      recentAlerts: (recentAlertRows ?? []).map((r) => ({
        id: r.id,
        patientId: r.patient_id,
        encounterId: r.encounter_id,
        alertCode: r.alert_code,
        alertType: r.alert_type,
        severity: r.severity,
        title: r.title,
        message: r.message,
        acknowledged: r.acknowledged,
        resolved: r.resolved,
        createdAt: new Date(String(r.created_at)).toISOString(),
      })),
    },
    clinicianBehaviour: {
      accepted: decisionsByStatus.get('accepted') ?? 0,
      modified: decisionsByStatus.get('modified') ?? 0,
      rejected: decisionsByStatus.get('dismissed') ?? 0,
      overrides: decisionsByStatus.get('overridden') ?? 0,
      decisionTotal,
    },
    documentation: {
      generated: 0,
      finalized: 0,
      amended: 0,
    },
  };
}

// =============================================================================
// ENGINES
// =============================================================================

interface EngineRow extends Row {
  id: string;
  code: string;
  name: string;
  engine_type: string;
  status: string | null;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

interface EngineRegistryRow extends Row {
  engine_code: string;
  engine_name: string;
  engine_type: string;
  engine_version: string;
  system_version_code: string | null;
  status: string;
  deterministic: boolean;
  human_authorization_required: boolean;
}

interface EngineVersionRow extends Row {
  id: string;
  version: string;
  released_at: Date | null;
}

async function listEngines(db: Db): Promise<Record<string, unknown>> {
  const rows = await db.query<EngineRow>(
    `SELECT id, code, name, engine_type, status, is_active, created_at, updated_at
       FROM system.engine
      ORDER BY code`,
  );

  const registry = await db.query<EngineRegistryRow>(
    `SELECT engine_code, engine_name, engine_type, engine_version, system_version_code,
            status, deterministic, human_authorization_required
       FROM governance.engine_registry
      ORDER BY engine_code`,
  );

  const engines = await Promise.all(
    rows.map(async (r) => {
      const versions = await db.query<EngineVersionRow>(
        `SELECT id, version, released_at
           FROM system.engine_version
          WHERE engine_id = $1
          ORDER BY released_at DESC NULLS LAST
          LIMIT 10`,
        [r.id],
      );
      return {
        id: r.id,
        code: r.code,
        name: r.name,
        engineType: r.engine_type,
        status: r.status,
        isActive: r.is_active,
        created_at: new Date(r.created_at).toISOString(),
        versions: versions.map((v) => ({
          id: v.id,
          version: v.version,
          releasedAt: v.released_at ? new Date(v.released_at).toISOString() : null,
        })),
      };
    }),
  );

  return {
    engines,
    engineRegistry: registry.map((r) => ({
      engineCode: r.engine_code,
      engineName: r.engine_name,
      engineType: r.engine_type,
      engineVersion: r.engine_version,
      systemVersionCode: r.system_version_code,
      status: r.status,
      deterministic: r.deterministic,
      humanAuthorizationRequired: r.human_authorization_required,
    })),
  };
}

async function engineDetail(db: Db, code: string): Promise<Record<string, unknown> | null> {
  const row = await db.queryOne<EngineRow>(
    `SELECT id, code, name, engine_type, status, is_active, created_at, updated_at
       FROM system.engine
      WHERE code = $1`,
    [code],
  );
  if (!row) return null;

  const versions = await db.query<EngineVersionRow>(
    `SELECT id, version, released_at
       FROM system.engine_version
      WHERE engine_id = $1
      ORDER BY released_at DESC NULLS LAST`,
    [row.id],
  );

  const registry = await db.query<EngineRegistryRow>(
    `SELECT engine_code, engine_name, engine_type, engine_version, system_version_code,
            status, deterministic, human_authorization_required
       FROM governance.engine_registry
      WHERE engine_code = $1 OR engine_name ILIKE $2`,
    [code, `%${code.replace(/_/g, '-')}%`],
  );

  const lastRun = await db.queryOne<Row>(
    `SELECT id, event_type, occurred_at, payload
       FROM cpu.event_log
      WHERE source_id = $1
      ORDER BY occurred_at DESC
      LIMIT 1`,
    [code.replace(/_/g, '-')],
  );

  return {
    id: row.id,
    code: row.code,
    name: row.name,
    engineType: row.engine_type,
    status: row.status,
    isActive: row.is_active,
    created_at: new Date(row.created_at).toISOString(),
    registry: registry.length > 0 ? registry[0] : null,
    versions: versions.map((v) => ({
      id: v.id,
      version: v.version,
      releasedAt: v.released_at ? new Date(v.released_at).toISOString() : null,
    })),
    lastRun: lastRun
      ? {
          eventId: Number(lastRun.id),
          eventType: lastRun.event_type,
          occurredAt: lastRun.occurred_at,
        }
      : null,
  };
}

// =============================================================================
// HEALTH CHECKS
// =============================================================================

async function listHealthChecks(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);
  const rows = await db.query<Row>(
    `SELECT id, service_id, status, latency_ms, checked_at, detail
       FROM system.health_check
      ORDER BY checked_at DESC
      LIMIT $1 OFFSET $2`,
    [limit, offset],
  );
  return {
    limit,
    offset,
    total: await count(db, 'SELECT count(*) AS n FROM system.health_check'),
    checks: rows.map((r) => ({
      id: r.id,
      serviceId: r.service_id,
      status: r.status,
      latencyMs: Number(r.latency_ms),
      checkedAt: r.checked_at,
      detail: r.detail ?? null,
    })),
  };
}

// =============================================================================
// JOBS
// =============================================================================

async function listJobs(db: Db): Promise<Record<string, unknown>> {
  const rows = await db.query<Row>(
    `SELECT id, code, name, schedule, handler, is_active, last_run_at
       FROM system.job
      ORDER BY code`,
  );
  return {
    jobs: rows.map((r) => ({
      id: r.id,
      code: r.code,
      name: r.name,
      schedule: r.schedule,
      handler: r.handler,
      isActive: r.is_active,
      lastRunAt: r.last_run_at ?? null,
    })),
  };
}

// =============================================================================
// FEATURE FLAGS
// =============================================================================

async function listFeatureFlags(db: Db): Promise<Record<string, unknown>> {
  const rows = await db.query<Row>(
    `SELECT id, code, name, description, enabled, environment_code, scope, updated_at
       FROM system.feature_flag
      ORDER BY code`,
  );
  return {
    featureFlags: rows.map((r) => ({
      id: r.id,
      code: r.code,
      name: r.name,
      description: r.description ?? null,
      enabled: r.enabled,
      environment: r.environment_code,
      scope: r.scope ?? null,
      updatedAt: r.updated_at,
    })),
  };
}

// =============================================================================
// CONFIGURATION
// =============================================================================

interface ConfigRow extends Row {
  id: string;
  code: string;
  key: string;
  name: string;
  description: string | null;
  data_type: string;
  default_value: string | null;
  is_active: boolean;
  created_at: Date;
}

async function listConfiguration(db: Db): Promise<Record<string, unknown>> {
  const scopes = await db.query<Row>(
    `SELECT code, label, precedence FROM configuration.scope ORDER BY precedence`,
  );
  const inheritance = await db.query<Row>(
    `SELECT scope_code, parent_scope_code, precedence
       FROM configuration.inheritance
      ORDER BY precedence`,
  );
  const configs = await db.query<ConfigRow>(
    `SELECT id, code, key, name, description, data_type, default_value, is_active, created_at
       FROM configuration.configuration
      ORDER BY key`,
  );

  const activeVersions = await db.query<Row>(
    `SELECT a.configuration_id, cv.version, cv.value, cv.created_at
       FROM configuration.activation a
       JOIN configuration.configuration_version cv ON cv.id = a.active_version_id
      WHERE a.scope_code IS NULL`,
  );
  const activeByConfig = new Map<string, Row>();
  for (const a of activeVersions) activeByConfig.set(String(a.configuration_id), a);

  return {
    scopes: scopes.map((r) => ({
      code: r.code,
      label: r.label,
      precedence: Number(r.precedence),
    })),
    inheritance: inheritance.map((r) => ({
      scopeCode: r.scope_code,
      parentScopeCode: r.parent_scope_code,
      precedence: Number(r.precedence),
    })),
    configurations: configs.map((r) => {
      const active = activeByConfig.get(String(r.id));
      return {
        id: r.id,
        code: r.code,
        key: r.key,
        name: r.name,
        description: r.description ?? null,
        dataType: r.data_type,
        defaultValue: r.default_value ?? null,
        isActive: r.is_active,
        activeVersion: active ? Number(active.version) : null,
        activeValue: active ? active.value : null,
        activeSince: active ? active.created_at : null,
      };
    }),
  };
}

async function configDetail(db: Db, key: string): Promise<Record<string, unknown> | null> {
  const row = await db.queryOne<ConfigRow>(
    `SELECT id, code, key, name, description, data_type, default_value, is_active, created_at
       FROM configuration.configuration
      WHERE key = $1`,
    [key],
  );
  if (!row) return null;

  const versions = await db.query<Row>(
    `SELECT id, version, value, created_at, created_by
       FROM configuration.configuration_version
      WHERE configuration_id = $1
      ORDER BY version DESC`,
    [row.id],
  );

  const activations = await db.query<Row>(
    `SELECT a.id, a.active_version_id, a.scope_code, a.scope_entity_id, a.activated_at, a.activated_by
       FROM configuration.activation a
      WHERE a.configuration_id = $1
      ORDER BY a.activated_at DESC`,
    [row.id],
  );

  return {
    id: row.id,
    code: row.code,
    key: row.key,
    name: row.name,
    description: row.description ?? null,
    dataType: row.data_type,
    defaultValue: row.default_value ?? null,
    isActive: row.is_active,
    created_at: new Date(row.created_at).toISOString(),
    versions: versions.map((v) => ({
      id: v.id,
      version: Number(v.version),
      value: v.value,
      createdAt: v.created_at,
      createdBy: v.created_by ?? null,
    })),
    activations: activations.map((a) => ({
      id: a.id,
      activeVersionId: a.active_version_id,
      scopeCode: a.scope_code ?? null,
      scopeEntityId: a.scope_entity_id ?? null,
      activatedAt: a.activated_at,
      activatedBy: a.activated_by ?? null,
    })),
  };
}

// =============================================================================
// SYSTEM VERSIONS
// =============================================================================

async function listSystemVersions(db: Db): Promise<Record<string, unknown>> {
  const rows = await db.query<Row>(
    `SELECT id, system_version_code, reasoning_version_code, documentation_version_code,
            investigation_version_code, differential_version_code, engine_version,
            knowledge_fingerprint, ruleset_fingerprint, release_notes, released_at,
            retired_at, is_active, created_at
       FROM governance.system_version
      ORDER BY released_at DESC NULLS LAST, created_at DESC`,
  );
  return {
    systemVersions: rows.map((r) => ({
      id: r.id,
      systemVersionCode: r.system_version_code,
      reasoningVersionCode: r.reasoning_version_code,
      documentationVersionCode: r.documentation_version_code,
      investigationVersionCode: r.investigation_version_code,
      differentialVersionCode: r.differential_version_code,
      engineVersion: r.engine_version,
      knowledgeFingerprint: r.knowledge_fingerprint,
      rulesetFingerprint: r.ruleset_fingerprint,
      releaseNotes: r.release_notes ?? null,
      releasedAt: r.released_at,
      retiredAt: r.retired_at ?? null,
      isActive: r.is_active,
    })),
  };
}

// =============================================================================
// AUDIT EVENTS
// =============================================================================

async function listAuditEvents(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);
  const filters: string[] = [];
  const params: (string | number)[] = [];

  const eventType = url.searchParams.get('eventType');
  if (eventType) {
    params.push(eventType);
    filters.push(`event_type = $${params.length}`);
  }
  const actorType = url.searchParams.get('actorType');
  if (actorType) {
    params.push(actorType);
    filters.push(`actor_type = $${params.length}`);
  }
  const entityType = url.searchParams.get('entityType');
  if (entityType) {
    params.push(entityType);
    filters.push(`entity_type = $${params.length}`);
  }
  const encounterId = url.searchParams.get('encounterId');
  if (encounterId) {
    params.push(encounterId);
    filters.push(`encounter_id = $${params.length}`);
  }
  const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  const rows = await db.query<Row>(
    `SELECT id, event_type, actor_type, actor_code, entity_type, entity_id, entity_code,
            previous_value, new_value, encounter_id, run_id, correlation_id, occurred_at
       FROM governance.audit_event
      ${where}
      ORDER BY occurred_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, limit, offset],
  );

  return {
    limit,
    offset,
    total: await count(
      db,
      `SELECT count(*) AS n FROM governance.audit_event ${where}`,
      params,
    ),
    events: rows.map((r) => ({
      id: r.id,
      eventType: r.event_type,
      actorType: r.actor_type,
      actorCode: r.actor_code,
      entityType: r.entity_type,
      entityId: r.entity_id,
      entityCode: r.entity_code ?? null,
      previousValue: r.previous_value ?? null,
      newValue: r.new_value ?? null,
      encounterId: r.encounter_id ?? null,
      runId: r.run_id ?? null,
      correlationId: r.correlation_id ?? null,
      occurredAt: r.occurred_at,
    })),
  };
}

// =============================================================================
// EVENT EXPLORER (cpu.event_log)
// =============================================================================

interface EventRow extends Row {
  id: number;
  event_type: string;
  patient_id: string | null;
  encounter_id: string | null;
  source_type: string | null;
  source_id: string | null;
  correlation_id: string | null;
  processing_status: string | null;
  occurred_at: Date;
  created_at: Date;
}

async function listEvents(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);
  const filters: string[] = [];
  const params: (string | number)[] = [];

  const eventType = url.searchParams.get('eventType');
  if (eventType) {
    params.push(eventType);
    filters.push(`event_type = $${params.length}`);
  }
  const sourceType = url.searchParams.get('sourceType');
  if (sourceType) {
    params.push(sourceType);
    filters.push(`source_type = $${params.length}`);
  }
  const patientId = url.searchParams.get('patientId');
  if (patientId) {
    params.push(patientId);
    filters.push(`patient_id = $${params.length}`);
  }
  const encounterId = url.searchParams.get('encounterId');
  if (encounterId) {
    params.push(encounterId);
    filters.push(`encounter_id = $${params.length}`);
  }
  const status = url.searchParams.get('status');
  if (status) {
    params.push(status);
    filters.push(`processing_status = $${params.length}`);
  }
  const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  const rows = await db.query<EventRow>(
    `SELECT id, event_type, patient_id, encounter_id, source_type, source_id,
            correlation_id, processing_status, occurred_at, created_at
       FROM cpu.event_log
      ${where}
      ORDER BY occurred_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, limit, offset],
  );

  return {
    limit,
    offset,
    total: await count(
      db,
      `SELECT count(*) AS n FROM cpu.event_log ${where}`,
      params,
    ),
    events: rows.map((r) => ({
      id: Number(r.id),
      eventType: r.event_type,
      patientId: r.patient_id,
      encounterId: r.encounter_id,
      sourceType: r.source_type,
      sourceId: r.source_id,
      correlationId: r.correlation_id,
      processingStatus: r.processing_status,
      occurredAt: new Date(r.occurred_at).toISOString(),
      createdAt: new Date(r.created_at).toISOString(),
    })),
  };
}

async function eventDetail(db: Db, id: number): Promise<Record<string, unknown> | null> {
  const row = await db.queryOne<Row>(
    `SELECT id, event_type, patient_id, encounter_id, source_type, source_id,
            idempotency_key, correlation_id, parent_event_id, payload, fact_code,
            fact_value, occurred_at, created_at, processed_at, processing_status,
            processing_attempts, processing_error, knowledge_version, cpu_version
       FROM cpu.event_log
      WHERE id = $1`,
    [id],
  );
  if (!row) return null;

  const lineage = await db.query<Row>(
    `SELECT id, event_type, occurred_at
       FROM cpu.event_log
      WHERE correlation_id = $1
      ORDER BY occurred_at
      LIMIT 100`,
    [row.correlation_id],
  );

  return {
    id: Number(row.id),
    eventType: row.event_type,
    patientId: row.patient_id,
    encounterId: row.encounter_id,
    sourceType: row.source_type,
    sourceId: row.source_id,
    idempotencyKey: row.idempotency_key ?? null,
    correlationId: row.correlation_id ?? null,
    parentEventId: row.parent_event_id ?? null,
    payload: row.payload ?? null,
    factCode: row.fact_code ?? null,
    factValue: row.fact_value ?? null,
    occurredAt: row.occurred_at,
    createdAt: row.created_at,
    processedAt: row.processed_at ?? null,
    processingStatus: row.processing_status ?? null,
    processingAttempts: Number(row.processing_attempts ?? 0),
    processingError: row.processing_error ?? null,
    knowledgeVersion: row.knowledge_version ?? null,
    cpuVersion: row.cpu_version ?? null,
    lineage: lineage.map((l) => ({
      id: Number(l.id),
      eventType: l.event_type,
      occurredAt: l.occurred_at,
    })),
  };
}

// =============================================================================
// SECURITY OVERVIEW (RBAC)
// =============================================================================

async function securityOverview(db: Db): Promise<Record<string, unknown>> {
  const permissions = await db.query<Row>(
    `SELECT code, resource, action, description FROM security.permission ORDER BY resource, action`,
  );
  const roles = await db.query<Row>(
    `SELECT r.id, r.code, r.name, r.description, r.is_system, r.is_active,
            count(rp.permission_code)::text AS permission_count
       FROM security.role r
       LEFT JOIN security.role_permission rp ON rp.role_id = r.id
      GROUP BY r.id
      ORDER BY r.code`,
  );
  const scopes = await db.query<Row>(
    `SELECT code, label, description FROM security.api_scope ORDER BY code`,
  );
  const assignments = await db.query<Row>(
    `SELECT ur.id, ur.user_account_id, ur.role_id, ur.organization_id, ur.facility_id,
            ur.department_id, ur.valid_from, ur.valid_to,
            u.username, r.code AS role_code
       FROM security.user_role ur
       LEFT JOIN identity.user_account u ON u.id = ur.user_account_id
       LEFT JOIN security.role r ON r.id = ur.role_id
      ORDER BY ur.valid_from DESC
      LIMIT 200`,
  );

  const resources = new Map<string, number>();
  for (const p of permissions) {
    resources.set(String(p.resource), (resources.get(String(p.resource)) ?? 0) + 1);
  }

  return {
    summary: {
      permissions: permissions.length,
      roles: roles.length,
      apiScopes: scopes.length,
      assignments: await count(db, 'SELECT count(*) AS n FROM security.user_role'),
    },
    resources: Array.from(resources.entries())
      .map(([resource, n]) => ({ resource, permissions: n }))
      .sort((a, b) => a.resource.localeCompare(b.resource)),
    roles: roles.map((r) => ({
      id: r.id,
      code: r.code,
      name: r.name,
      description: r.description ?? null,
      isSystem: r.is_system,
      isActive: r.is_active,
      permissionCount: Number(r.permission_count),
    })),
    apiScopes: scopes.map((s) => ({
      code: s.code,
      label: s.label,
      description: s.description ?? null,
    })),
    assignments: assignments.map((a) => ({
      id: a.id,
      userId: a.user_account_id,
      username: a.username ?? null,
      roleId: a.role_id,
      roleCode: a.role_code,
      organizationId: a.organization_id ?? null,
      facilityId: a.facility_id ?? null,
      departmentId: a.department_id ?? null,
      validFrom: a.valid_from,
      validTo: a.valid_to ?? null,
    })),
  };
}

// =============================================================================
// DATABASE OVERVIEW (§61)
// =============================================================================

async function databaseOverview(db: Db): Promise<Record<string, unknown>> {
  const [server, dbSize, migrations, tables, migrationCountRow] = await Promise.all([
    db.queryOne<Row>(
      `SELECT version() AS version,
              current_database() AS database,
              current_user AS username,
              pg_postmaster_start_time() AS started_at`,
    ),
    db.queryOne<Row>(
      `SELECT pg_size_pretty(pg_database_size(current_database())) AS size`,
    ),
    db.query<Row>(
      `SELECT version, name, applied_at, applied_by FROM system.migration
        ORDER BY version DESC`,
    ),
    db.query<Row>(
      `SELECT schemaname, tablename
         FROM pg_tables
        WHERE schemaname NOT IN ('pg_catalog','information_schema')
        ORDER BY schemaname, tablename`,
    ),
    db.queryOne<Row>(
      `SELECT count(*)::text AS n FROM system.migration`,
    ),
  ]);

  const schemas = new Map<string, number>();
  for (const t of tables) {
    const name = String(t.schemaname);
    schemas.set(name, (schemas.get(name) ?? 0) + 1);
  }

  return {
    server: {
      version: server?.version ?? null,
      database: server?.database ?? null,
      username: server?.username ?? null,
      startedAt: server?.started_at ?? null,
      size: dbSize?.size ?? null,
    },
    migrationCount: Number(migrationCountRow?.n ?? 0),
    migrations: migrations.map((m) => ({
      version: Number(m.version),
      name: m.name,
      appliedAt: m.applied_at,
      appliedBy: m.applied_by ?? null,
    })),
    tables: tables.map((t) => ({
      schema: t.schemaname,
      table: t.tablename,
    })),
    schemaCounts: Array.from(schemas.entries())
      .map(([schema, count]) => ({ schema, count }))
      .sort((a, b) => a.schema.localeCompare(b.schema)),
  };
}

// =============================================================================
// RUNTIME OVERVIEW (CPU runs, processing errors, worker checkpoints)
// =============================================================================

async function runtimeOverview(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);

  const [runStats, runs, errors, checkpoints, errorTotal] = await Promise.all([
    db.queryOne<Row>(
      `SELECT count(*)::text AS total,
              count(*) FILTER (WHERE status = 'completed')::text AS completed,
              count(*) FILTER (WHERE status = 'failed')::text AS failed,
              count(*) FILTER (WHERE status = 'running')::text AS running
         FROM cpu.run`,
    ),
    db.query<Row>(
      `SELECT id, patient_id, encounter_id, trigger_type, status, started_at,
              completed_at, duration_ms, events_consumed, rules_evaluated,
              rules_triggered, recommendations, error_code, error_message, metadata
         FROM cpu.run
        ORDER BY started_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    ),
    db.query<Row>(
      `SELECT id, run_id, patient_id, event_id, error_code, error_message,
              retryable, attempt_no, created_at, resolved_at
         FROM cpu.processing_error
        ORDER BY created_at DESC
        LIMIT 50`,
    ),
    db.query<Row>(
      `SELECT worker_code, last_event_id, lease_owner, lease_expires_at,
              heartbeat_at, updated_at
         FROM cpu.event_checkpoint
        ORDER BY worker_code`,
    ),
    count(db, 'SELECT count(*) AS n FROM cpu.processing_error WHERE resolved_at IS NULL'),
  ]);

  return {
    runStats: {
      total: Number(runStats?.total ?? 0),
      completed: Number(runStats?.completed ?? 0),
      failed: Number(runStats?.failed ?? 0),
      running: Number(runStats?.running ?? 0),
    },
    runs: (runs ?? []).map((r) => ({
      id: r.id,
      patientId: r.patient_id,
      encounterId: r.encounter_id,
      triggerType: r.trigger_type,
      status: r.status,
      startedAt: r.started_at,
      completedAt: r.completed_at ?? null,
      durationMs: r.duration_ms != null ? Number(r.duration_ms) : null,
      eventsConsumed: Number(r.events_consumed ?? 0),
      rulesEvaluated: Number(r.rules_evaluated ?? 0),
      rulesTriggered: Number(r.rules_triggered ?? 0),
      recommendations: Number(r.recommendations ?? 0),
      errorCode: r.error_code ?? null,
      errorMessage: r.error_message ?? null,
      metadata: r.metadata ?? null,
    })),
    processingErrors: {
      unresolved: errorTotal,
      items: (errors ?? []).map((e) => ({
        id: e.id,
        runId: e.run_id,
        patientId: e.patient_id,
        eventId: e.event_id != null ? Number(e.event_id) : null,
        errorCode: e.error_code,
        errorMessage: e.error_message,
        retryable: e.retryable,
        attemptNo: Number(e.attempt_no ?? 0),
        createdAt: e.created_at,
        resolvedAt: e.resolved_at ?? null,
      })),
    },
    checkpoints: (checkpoints ?? []).map((c) => ({
      workerCode: c.worker_code,
      lastEventId: c.last_event_id != null ? Number(c.last_event_id) : null,
      leaseOwner: c.lease_owner ?? null,
      leaseExpiresAt: c.lease_expires_at ?? null,
      heartbeatAt: c.heartbeat_at ?? null,
      updatedAt: c.updated_at,
    })),
  };
}

// =============================================================================
// WORKFLOW OVERVIEW
// =============================================================================

async function workflowOverview(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);

  const [instanceStats, instances, tasks, queues, queueItems] = await Promise.all([
    db.queryOne<Row>(
      `SELECT count(*)::text AS total,
              count(*) FILTER (WHERE status = 'running')::text AS active,
              count(*) FILTER (WHERE status = 'completed')::text AS completed
         FROM workflow.instance`,
    ),
    db.query<Row>(
      `SELECT i.id, i.entity_type, i.entity_id, i.current_state_id, i.status,
              i.started_at, i.ended_at, wv.version, s.code AS current_state_code
         FROM workflow.instance i
         LEFT JOIN workflow.version wv ON wv.id = i.workflow_version_id
         LEFT JOIN workflow.state s ON s.id = i.current_state_id
        ORDER BY i.started_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    ),
    db.query<Row>(
      `SELECT id, instance_id, task_type, name, status, priority, due_at, created_at, completed_at
         FROM workflow.task
        ORDER BY created_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    ),
    db.query<Row>(
      `SELECT id, code, name, facility_id, department_id, is_active FROM workflow.queue ORDER BY code`,
    ),
    db.query<Row>(
      `SELECT id, queue_id, workflow_instance_id, entity_type, entity_id, priority, status, entered_at, exited_at
         FROM workflow.queue_item
        ORDER BY entered_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    ),
  ]);

  return {
    instanceStats: {
      total: Number(instanceStats?.total ?? 0),
      active: Number(instanceStats?.active ?? 0),
      completed: Number(instanceStats?.completed ?? 0),
    },
    instances: (instances ?? []).map((i) => ({
      id: i.id,
      entityType: i.entity_type,
      entityId: i.entity_id,
      currentStateId: i.current_state_id,
      currentStateCode: i.current_state_code ?? null,
      status: i.status,
      workflowVersion: i.version ?? null,
      startedAt: i.started_at,
      endedAt: i.ended_at ?? null,
    })),
    tasks: (tasks ?? []).map((t) => ({
      id: t.id,
      instanceId: t.instance_id,
      taskType: t.task_type,
      name: t.name,
      status: t.status,
      priority: Number(t.priority ?? 0),
      dueAt: t.due_at ?? null,
      createdAt: t.created_at,
      completedAt: t.completed_at ?? null,
    })),
    queues: (queues ?? []).map((q) => ({
      id: q.id,
      code: q.code,
      name: q.name,
      facilityId: q.facility_id ?? null,
      departmentId: q.department_id ?? null,
      isActive: q.is_active,
    })),
    queueItems: (queueItems ?? []).map((q) => ({
      id: q.id,
      queueId: q.queue_id,
      workflowInstanceId: q.workflow_instance_id,
      entityType: q.entity_type,
      entityId: q.entity_id,
      priority: Number(q.priority ?? 0),
      status: q.status,
      enteredAt: q.entered_at,
      exitedAt: q.exited_at ?? null,
    })),
  };
}

// =============================================================================
// INCIDENTS (§59)
// =============================================================================

async function listIncidents(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);
  const filters: string[] = [];
  const params: (string | number)[] = [];

  const status = url.searchParams.get('status');
  if (status) {
    params.push(status);
    filters.push(`i.status = $${params.length}`);
  }
  const severity = url.searchParams.get('severity');
  if (severity) {
    params.push(severity);
    filters.push(`i.severity = $${params.length}`);
  }
  const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  const rows = await db.query<Row>(
    `SELECT i.id, i.incident_code, i.title, i.description, i.severity, i.status,
            i.category, i.owning_team, i.reported_by, i.related_entity_type,
            i.related_entity_id, i.created_at, i.updated_at, i.resolved_at,
            (SELECT count(*) FROM governance.incident_event e WHERE e.incident_id = i.id)::text AS event_count
       FROM governance.incident i
      ${where}
      ORDER BY i.updated_at DESC
      LIMIT $${params.length + 1} OFFSET $${params.length + 2}`,
    [...params, limit, offset],
  );

  return {
    limit,
    offset,
    total: await count(
      db,
      `SELECT count(*) AS n FROM governance.incident i ${where}`,
      params,
    ),
    open: await count(db, `SELECT count(*) AS n FROM governance.incident WHERE status NOT IN ('resolved','closed','cancelled')`),
    incidents: rows.map((r) => ({
      id: r.id,
      incidentCode: r.incident_code,
      title: r.title,
      description: r.description ?? null,
      severity: r.severity,
      status: r.status,
      category: r.category ?? null,
      owningTeam: r.owning_team ?? null,
      reportedBy: r.reported_by ?? null,
      relatedEntityType: r.related_entity_type ?? null,
      relatedEntityId: r.related_entity_id ?? null,
      eventCount: Number(r.event_count ?? 0),
      createdAt: r.created_at,
      updatedAt: r.updated_at,
      resolvedAt: r.resolved_at ?? null,
    })),
  };
}

async function incidentDetail(db: Db, id: string): Promise<Record<string, unknown> | null> {
  const row = await db.queryOne<Row>(
    `SELECT id, incident_code, title, description, severity, status, category,
            owning_team, reported_by, related_entity_type, related_entity_id,
            created_at, updated_at, resolved_at
       FROM governance.incident WHERE id = $1`,
    [id],
  );
  if (!row) return null;

  const timeline = await db.query<Row>(
    `SELECT id, event_type, detail, occurred_at, actor_id
       FROM governance.incident_event
      WHERE incident_id = $1
      ORDER BY occurred_at DESC`,
    [id],
  );

  return {
    id: row.id,
    incidentCode: row.incident_code,
    title: row.title,
    description: row.description ?? null,
    severity: row.severity,
    status: row.status,
    category: row.category ?? null,
    owningTeam: row.owning_team ?? null,
    reportedBy: row.reported_by ?? null,
    relatedEntityType: row.related_entity_type ?? null,
    relatedEntityId: row.related_entity_id ?? null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    resolvedAt: row.resolved_at ?? null,
    timeline: timeline.map((t) => ({
      id: t.id,
      eventType: t.event_type,
      detail: t.detail ?? null,
      occurredAt: t.occurred_at,
      actorId: t.actor_id ?? null,
    })),
  };
}

// =============================================================================
// INTEGRATIONS
// =============================================================================

async function integrationsOverview(db: Db): Promise<Record<string, unknown>> {
  const [connections, endpoints, messages, systems, messageStats] = await Promise.all([
    db.query<Row>(
      `SELECT c.id, c.endpoint_id, c.status, c.connected_at, c.last_error, c.is_active, c.updated_at
         FROM interoperability.connection c
        ORDER BY c.updated_at DESC`,
    ),
    db.query<Row>(
      `SELECT e.id, e.system_id, e.name, e.base_url, e.auth_type, e.is_active, e.created_at
         FROM interoperability.endpoint e
        ORDER BY e.name`,
    ),
    db.query<Row>(
      `SELECT m.id, m.direction, m.system_id, m.endpoint_id, m.message_type,
              m.external_message_id, m.status, m.created_at
         FROM interoperability.message m
        ORDER BY m.created_at DESC
        LIMIT 100`,
    ),
    db.query<Row>(`SELECT id, name, code FROM interoperability.system ORDER BY name`),
    db.query<Row>(
      `SELECT direction, status, count(*)::text AS n
         FROM interoperability.message
        GROUP BY direction, status
        ORDER BY direction, status`,
    ),
  ]);

  return {
    connections: (connections ?? []).map((c) => ({
      id: c.id,
      endpointId: c.endpoint_id,
      status: c.status,
      connectedAt: c.connected_at ?? null,
      lastError: c.last_error ?? null,
      isActive: c.is_active,
      updatedAt: c.updated_at,
    })),
    endpoints: (endpoints ?? []).map((e) => ({
      id: e.id,
      systemId: e.system_id,
      name: e.name,
      baseUrl: e.base_url,
      authType: e.auth_type ?? null,
      isActive: e.is_active,
      createdAt: e.created_at,
    })),
    systems: (systems ?? []).map((s) => ({
      id: s.id,
      code: s.code,
      name: s.name,
    })),
    messages: (messages ?? []).map((m) => ({
      id: m.id,
      direction: m.direction,
      systemId: m.system_id,
      endpointId: m.endpoint_id,
      messageType: m.message_type,
      externalMessageId: m.external_message_id ?? null,
      status: m.status,
      createdAt: m.created_at,
    })),
    messageStats: (messageStats ?? []).map((m) => ({
      direction: m.direction,
      status: m.status,
      count: Number(m.n),
    })),
  };
}

// =============================================================================
// NOTIFICATIONS
// =============================================================================

async function notificationsOverview(db: Db, url: URL): Promise<Record<string, unknown>> {
  const { limit, offset } = pagination(url);

  const [messages, deliveries, messageStats] = await Promise.all([
    db.query<Row>(
      `SELECT m.id, m.thread_id, m.sender_type, m.sender_id, m.message_type, m.body, m.sent_at, m.status
         FROM communication.message m
        ORDER BY m.sent_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    ),
    db.query<Row>(
      `SELECT d.id, d.message_id, d.notification_id, d.channel, d.provider, d.status,
              d.attempted_at, d.sent_at, d.error
         FROM communication.delivery d
        ORDER BY d.attempted_at DESC
        LIMIT $1 OFFSET $2`,
      [limit, offset],
    ),
    db.query<Row>(
      `SELECT message_type, status, count(*)::text AS n
         FROM communication.message
        GROUP BY message_type, status
        ORDER BY message_type, status`,
    ),
  ]);

  return {
    limit,
    offset,
    messageTotal: await count(db, 'SELECT count(*) AS n FROM communication.message'),
    messages: (messages ?? []).map((m) => ({
      id: m.id,
      threadId: m.thread_id ?? null,
      senderType: m.sender_type,
      senderId: m.sender_id ?? null,
      messageType: m.message_type,
      body: m.body ?? null,
      sentAt: m.sent_at,
      status: m.status,
    })),
    deliveries: (deliveries ?? []).map((d) => ({
      id: d.id,
      messageId: d.message_id,
      notificationId: d.notification_id ?? null,
      channel: d.channel,
      provider: d.provider ?? null,
      status: d.status,
      attemptedAt: d.attempted_at,
      sentAt: d.sent_at ?? null,
      error: d.error ?? null,
    })),
    messageStats: (messageStats ?? []).map((m) => ({
      messageType: m.message_type,
      status: m.status,
      count: Number(m.n),
    })),
  };
}

// =============================================================================
// ANALYTICS (Phase G)
// =============================================================================

async function analyticsOverview(db: Db): Promise<Record<string, unknown>> {
  const [
    encounters,
    encounterByStatus,
    eventLogStats,
    eventsByType,
    eventsByDay,
    decisions,
    suggestions,
    alertsBySeverity,
    factsBySource,
  ] = await Promise.all([
    count(db, 'SELECT count(*) AS n FROM encounter.encounter'),
    db.query<Row>(
      `SELECT status_code, count(*)::text AS n FROM encounter.encounter
        GROUP BY status_code ORDER BY n DESC`,
    ),
    db.queryOne<Row>(
      `SELECT count(*)::text AS total,
              count(*) FILTER (WHERE processing_status = 'failed')::text AS failed,
              count(DISTINCT patient_id)::text AS patients
         FROM cpu.event_log`,
    ),
    db.query<Row>(
      `SELECT event_type, count(*)::text AS n FROM cpu.event_log
        GROUP BY event_type ORDER BY n DESC LIMIT 20`,
    ),
    db.query<Row>(
      `SELECT to_char(occurred_at, 'YYYY-MM-DD') AS day, count(*)::text AS n
         FROM cpu.event_log
        GROUP BY 1 ORDER BY 1 DESC LIMIT 14`,
    ),
    db.query<Row>(
      `SELECT status, count(*)::text AS n FROM cpu.decision GROUP BY status ORDER BY n DESC`,
    ),
    db.query<Row>(
      `SELECT recommendation_type, count(*)::text AS n FROM cpu.decision
        GROUP BY recommendation_type ORDER BY n DESC`,
    ),
    db.query<Row>(
      `SELECT severity, count(*)::text AS n FROM cpu.alert GROUP BY severity ORDER BY n DESC`,
    ),
    db.query<Row>(
      `SELECT source_type, count(*)::text AS n FROM cpu.event_log
        GROUP BY source_type ORDER BY n DESC`,
    ),
  ]);

  return {
    generatedAt: new Date().toISOString(),
    encounters: {
      total: encounters,
      byStatus: (encounterByStatus ?? []).map((r) => ({
        status: r.status_code,
        count: Number(r.n),
      })),
    },
    events: {
      total: Number(eventLogStats?.total ?? 0),
      failed: Number(eventLogStats?.failed ?? 0),
      patients: Number(eventLogStats?.patients ?? 0),
      byType: (eventsByType ?? []).map((r) => ({
        eventType: r.event_type,
        count: Number(r.n),
      })),
      byDay: (eventsByDay ?? []).map((r) => ({
        day: r.day,
        count: Number(r.n),
      })),
      bySource: (factsBySource ?? []).map((r) => ({
        sourceType: r.source_type,
        count: Number(r.n),
      })),
    },
    decisions: (decisions ?? []).map((r) => ({
      status: r.status,
      count: Number(r.n),
    })),
    suggestions: (suggestions ?? []).map((r) => ({
      recommendationType: r.recommendation_type,
      count: Number(r.n),
    })),
    alerts: (alertsBySeverity ?? []).map((r) => ({
      severity: r.severity,
      count: Number(r.n),
    })),
  };
}