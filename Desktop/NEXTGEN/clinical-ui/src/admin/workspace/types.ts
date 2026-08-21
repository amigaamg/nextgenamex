// =============================================================================
// AMEXAN Admin Workspace — Control Plane Types
//
// These types describe the READ-ONLY projections exposed by the Control Plane
// API. The browser never owns the system-of-record.
// =============================================================================

export type AdminMode =
  | 'OPERATE'
  | 'INVESTIGATE'
  | 'IMPROVE';

export type AdminView =
  | 'command'
  | 'events'
  | 'trace'
  | 'engines'
  | 'safety'
  | 'config'
  | 'versions'
  | 'security'
  | 'database'
  | 'runtime'
  | 'workflow'
  | 'incidents'
  | 'integrations'
  | 'notifications'
  | 'analytics'
  | 'catalogues'
  | 'assets'
  | 'financial'
  | 'research';

// =============================================================================
// HEALTH
// =============================================================================

export type HealthStatus =
  | 'healthy'
  | 'degraded'
  | 'critical'
  | 'unknown';

export type ServiceStatus =
  | 'healthy'
  | 'degraded'
  | 'failed'
  | 'offline'
  | 'unknown';

export interface HealthProjection {
  status: HealthStatus;
  score?: number;
  checkedAt: string;
  message?: string;
}

export interface ServiceHealthProjection {
  id: string;
  name: string;
  status: ServiceStatus;
  latencyMs?: number;
  lastHeartbeatAt?: string;
  version?: string;
  message?: string;
}

export interface SystemHealthProjection {
  overall: HealthProjection;

  api: ServiceHealthProjection;
  database: ServiceHealthProjection;
  eventBus: ServiceHealthProjection;
  outbox: ServiceHealthProjection;
  workers: ServiceHealthProjection;
  observability: ServiceHealthProjection;
  safetySentinels: ServiceHealthProjection;
  z9: ServiceHealthProjection;
}

// =============================================================================
// SUMMARY PROJECTIONS
// =============================================================================

export interface ClinicalSummaryProjection {
  activeEncounters: number;
  openAlerts: number;
  eventLog: number;

  criticalAlerts?: number;
  pendingWorkflows?: number;
  encountersLast24h?: number;
}

export interface RegistrySummaryProjection {
  engines: number;
  activeEngines?: number;
  degradedEngines?: number;
  failedEngines?: number;
}

export interface IdentitySummaryProjection {
  userAccounts: number;
  activeUsers?: number;
  organizations?: number;
  facilities?: number;
}

export interface EventSummaryProjection {
  eventsLastMinute?: number;
  eventsLastHour?: number;

  failedDeliveries?: number;
  pendingDeliveries?: number;
  deadLetterEvents?: number;
}

export interface SafetySummaryProjection {
  critical?: number;
  high?: number;
  medium?: number;
  low?: number;

  unresolved?: number;
  overrides?: number;
}

export interface AdminSummary {
  generatedAt: string;

  system: SystemHealthProjection;

  clinical: ClinicalSummaryProjection;

  registry: RegistrySummaryProjection;

  identity: IdentitySummaryProjection;

  events?: EventSummaryProjection;

  safety?: SafetySummaryProjection;

  controlPlane: {
    version: string;
    environment: 'development' | 'staging' | 'production' | 'unknown';
    readOnly: true;
    requestId?: string;
  };
}

// =============================================================================
// ADMIN CONTEXT
// =============================================================================

export interface AdminContext {
  networkId?: string;
  networkName: string;

  organizationId?: string;
  organizationName?: string;

  facilityId?: string;
  facilityName?: string;

  scope: 'global' | 'organization' | 'facility' | 'department' | 'service';

  administratorRole: string;
}

// =============================================================================
// EVENT SELECTION
// =============================================================================

/**
 * A resolved reference to one AMEXAN event. Event IDs are opaque strings
 * (never numeric), so the browser never has to guess a surrogate identity.
 */
export interface EventSelection {
  eventId: string;
  encounterId?: string;
  correlationId?: string;
}

export interface AdminWorkspaceProps {
  onExit: () => void;

  /**
   * Administrative context should ideally come from the workspace resolver,
   * rather than being hard-coded inside the UI.
   */
  context?: AdminContext;
}

// =============================================================================
// ENGINES
// =============================================================================

export interface EngineVersion {
  id: string;
  version: string;
  releasedAt: string | null;
}

export interface EngineEntry {
  id: string;
  code: string;
  name: string;
  engineType: string;
  status: string | null;
  isActive: boolean;
  created_at: string;
  versions: EngineVersion[];
}

export interface EngineRegistryEntry {
  engineCode: string;
  engineName: string;
  engineType: string;
  engineVersion: string;
  systemVersionCode: string | null;
  status: string;
  deterministic: boolean;
  humanAuthorizationRequired: boolean;
}

export interface EnginesResponse {
  engines: EngineEntry[];
  engineRegistry: EngineRegistryEntry[];
}

export interface EngineDetail {
  id: string;
  code: string;
  name: string;
  engineType: string;
  status: string | null;
  isActive: boolean;
  created_at: string;
  registry: EngineRegistryEntry | null;
  versions: EngineVersion[];
  lastRun: { eventId: string; eventType: string; occurredAt: string } | null;
}

// =============================================================================
// HEALTH / JOBS / FEATURE FLAGS
// =============================================================================

export interface HealthCheck {
  id: string;
  serviceId: string;
  status: string;
  latencyMs: number;
  checkedAt: string;
  detail: unknown;
}

export interface HealthResponse {
  limit: number;
  offset: number;
  total: number;
  checks: HealthCheck[];
}

export interface Job {
  id: string;
  code: string;
  name: string;
  schedule: string | null;
  handler: string | null;
  isActive: boolean;
  lastRunAt: string | null;
}

export interface JobsResponse {
  jobs: Job[];
}

export interface FeatureFlag {
  id: string;
  code: string;
  name: string;
  description: string | null;
  enabled: boolean;
  environment: string;
  scope: string | null;
  updatedAt: string;
}

export interface FeatureFlagsResponse {
  featureFlags: FeatureFlag[];
}

// =============================================================================
// CONFIGURATION
// =============================================================================

export interface ConfigScope {
  code: string;
  label: string;
  precedence: number;
}

export interface ConfigInheritance {
  scopeCode: string;
  parentScopeCode: string;
  precedence: number;
}

export interface ConfigurationEntry {
  id: string;
  code: string;
  key: string;
  name: string;
  description: string | null;
  dataType: string;
  defaultValue: string | null;
  isActive: boolean;
  activeVersion: number | null;
  activeValue: string | null;
  activeSince: string | null;
}

export interface ConfigurationResponse {
  scopes: ConfigScope[];
  inheritance: ConfigInheritance[];
  configurations: ConfigurationEntry[];
}

export interface ConfigVersion {
  id: string;
  version: number;
  value: string;
  createdAt: string;
  createdBy: string | null;
}

export interface ConfigActivation {
  id: string;
  activeVersionId: string;
  scopeCode: string | null;
  scopeEntityId: string | null;
  activatedAt: string;
  activatedBy: string | null;
}

export interface ConfigurationDetail {
  id: string;
  code: string;
  key: string;
  name: string;
  description: string | null;
  dataType: string;
  defaultValue: string | null;
  isActive: boolean;
  created_at: string;
  versions: ConfigVersion[];
  activations: ConfigActivation[];
}

// =============================================================================
// SYSTEM VERSIONS
// =============================================================================

export interface SystemVersion {
  id: string;
  systemVersionCode: string;
  reasoningVersionCode: string | null;
  documentationVersionCode: string | null;
  investigationVersionCode: string | null;
  differentialVersionCode: string | null;
  engineVersion: string | null;
  knowledgeFingerprint: string | null;
  rulesetFingerprint: string | null;
  releaseNotes: string | null;
  releasedAt: string | null;
  retiredAt: string | null;
  isActive: boolean;
}

export interface SystemVersionsResponse {
  systemVersions: SystemVersion[];
}

// =============================================================================
// AUDIT
// =============================================================================

export interface AuditEvent {
  id: string;
  eventType: string;
  actorType: string;
  actorCode: string | null;
  entityType: string | null;
  entityId: string | null;
  entityCode: string | null;
  previousValue: string | null;
  newValue: string | null;
  encounterId: string | null;
  runId: string | null;
  correlationId: string | null;
  occurredAt: string;
}

export interface AuditResponse {
  limit: number;
  offset: number;
  total: number;
  events: AuditEvent[];
}

// =============================================================================
// EVENT EXPLORER (cpu.event_log)
// =============================================================================

export interface EventLogEntry {
  id: string;
  eventType: string;
  patientId: string | null;
  encounterId: string | null;
  sourceType: string | null;
  sourceId: string | null;
  correlationId: string | null;
  processingStatus: string | null;
  occurredAt: string;
  createdAt: string;
}

export interface EventsResponse {
  limit: number;
  offset: number;
  total: number;
  events: EventLogEntry[];
}

export interface EventLineageEntry {
  id: string;
  eventType: string;
  occurredAt: string;
}

export interface EventDetail {
  id: string;
  eventType: string;
  patientId: string | null;
  encounterId: string | null;
  sourceType: string | null;
  sourceId: string | null;
  idempotencyKey: string | null;
  correlationId: string | null;
  parentEventId: string | null;
  payload: Record<string, unknown> | null;
  factCode: string | null;
  factValue: string | null;
  occurredAt: string;
  createdAt: string;
  processedAt: string | null;
  processingStatus: string | null;
  processingAttempts: number;
  processingError: string | null;
  knowledgeVersion: string | null;
  cpuVersion: string | null;
  lineage: EventLineageEntry[];
}

// =============================================================================
// SECURITY / RBAC
// =============================================================================

export interface SecurityResource {
  resource: string;
  permissions: number;
}

export interface SecurityRole {
  id: string;
  code: string;
  name: string;
  description: string | null;
  isSystem: boolean;
  isActive: boolean;
  permissionCount: number;
}

export interface ApiScope {
  code: string;
  label: string;
  description: string | null;
}

export interface RoleAssignment {
  id: string;
  userId: string;
  username: string | null;
  roleId: string;
  roleCode: string | null;
  organizationId: string | null;
  facilityId: string | null;
  departmentId: string | null;
  validFrom: string;
  validTo: string | null;
}

export interface SecurityOverview {
  summary: {
    permissions: number;
    roles: number;
    apiScopes: number;
    assignments: number;
  };
  resources: SecurityResource[];
  roles: SecurityRole[];
  apiScopes: ApiScope[];
  assignments: RoleAssignment[];
}

// =============================================================================
// OBSERVATORY / JOURNEY (existing read-only endpoints)
// =============================================================================

export interface ObservatorySummary {
  generatedAt: string;
  totals: {
    patients: number;
    encounters: number;
    activeEncounters: number;
    completedEncounters: number;
    facts: number;
    eventsTotal: number;
  };
  throughput: {
    eventsLastMinute: number;
    eventsLastHour: number;
    eventsToday: number;
  };
  engines: {
    healthy: number;
    degraded: number;
    failed: number;
    engineStates: {
      engine: string;
      completed: number;
      failed: number;
      lastMs: string | null;
    }[];
  };
  safety: {
    openAlerts: number;
    acknowledgedAlerts: number;
    criticalAlerts: number;
    highAlerts: number;
    recentAlerts: ObservatoryAlert[];
  };
  clinicianBehaviour: {
    accepted: number;
    modified: number;
    rejected: number;
    overrides: number;
    decisionTotal: number;
  };
  documentation: {
    generated: number;
    finalized: number;
    amended: number;
  };
}

export interface ObservatoryAlert {
  id: string;
  patientId: string | null;
  encounterId: string | null;
  alertCode: string;
  alertType: string;
  severity: string;
  title: string;
  message: string;
  acknowledged: boolean;
  resolved: boolean;
  createdAt: string;
}

export interface JourneyEvent {
  eventId: string;
  eventType: string;
  payload: Record<string, unknown>;
  occurredAt: string;
}

// =============================================================================
// DATABASE (§61)
// =============================================================================

export interface MigrationRecord {
  version: number;
  name: string;
  appliedAt: string;
  appliedBy: string | null;
}

export interface DatabaseOverview {
  server: {
    version: string | null;
    database: string | null;
    username: string | null;
    startedAt: string | null;
    size: string | null;
  };
  migrationCount: number;
  migrations: MigrationRecord[];
  tables: { schema: string; table: string }[];
  schemaCounts: { schema: string; count: number }[];
}

// =============================================================================
// RUNTIME (CPU runs, processing errors, worker checkpoints)
// =============================================================================

export interface CpuRun {
  id: string;
  patientId: string | null;
  encounterId: string | null;
  triggerType: string | null;
  status: string;
  startedAt: string;
  completedAt: string | null;
  durationMs: number | null;
  eventsConsumed: number;
  rulesEvaluated: number;
  rulesTriggered: number;
  recommendations: number;
  errorCode: string | null;
  errorMessage: string | null;
  metadata: Record<string, unknown> | null;
}

export interface ProcessingError {
  id: string;
  runId: string | null;
  patientId: string | null;
  eventId: string | null;
  errorCode: string;
  errorMessage: string;
  retryable: boolean;
  attemptNo: number;
  createdAt: string;
  resolvedAt: string | null;
}

export interface WorkerCheckpoint {
  workerCode: string;
  lastEventId: string | null;
  leaseOwner: string | null;
  leaseExpiresAt: string | null;
  heartbeatAt: string | null;
  updatedAt: string;
}

export interface RuntimeOverview {
  runStats: {
    total: number;
    completed: number;
    failed: number;
    running: number;
  };
  runs: CpuRun[];
  processingErrors: {
    unresolved: number;
    items: ProcessingError[];
  };
  checkpoints: WorkerCheckpoint[];
}

// =============================================================================
// WORKFLOW
// =============================================================================

export interface WorkflowInstance {
  id: string;
  entityType: string | null;
  entityId: string | null;
  currentStateId: string | null;
  currentStateCode: string | null;
  status: string | null;
  workflowVersion: string | null;
  startedAt: string;
  endedAt: string | null;
}

export interface WorkflowTask {
  id: string;
  instanceId: string;
  taskType: string | null;
  name: string;
  status: string | null;
  priority: number;
  dueAt: string | null;
  createdAt: string;
  completedAt: string | null;
}

export interface WorkflowQueue {
  id: string;
  code: string;
  name: string;
  facilityId: string | null;
  departmentId: string | null;
  isActive: boolean;
}

export interface WorkflowQueueItem {
  id: string;
  queueId: string;
  workflowInstanceId: string | null;
  entityType: string | null;
  entityId: string | null;
  priority: number;
  status: string | null;
  enteredAt: string;
  exitedAt: string | null;
}

export interface WorkflowOverview {
  instanceStats: {
    total: number;
    active: number;
    completed: number;
  };
  instances: WorkflowInstance[];
  tasks: WorkflowTask[];
  queues: WorkflowQueue[];
  queueItems: WorkflowQueueItem[];
}

// =============================================================================
// INCIDENTS (§59)
// =============================================================================

export interface Incident {
  id: string;
  incidentCode: string;
  title: string;
  description: string | null;
  severity: string;
  status: string;
  category: string | null;
  owningTeam: string | null;
  reportedBy: string | null;
  relatedEntityType: string | null;
  relatedEntityId: string | null;
  eventCount: number;
  createdAt: string;
  updatedAt: string;
  resolvedAt: string | null;
}

export interface IncidentsResponse {
  limit: number;
  offset: number;
  total: number;
  open: number;
  incidents: Incident[];
}

export interface IncidentEvent {
  id: string;
  eventType: string;
  detail: unknown;
  occurredAt: string;
  actorId: string | null;
}

export interface IncidentDetail {
  id: string;
  incidentCode: string;
  title: string;
  description: string | null;
  severity: string;
  status: string;
  category: string | null;
  owningTeam: string | null;
  reportedBy: string | null;
  relatedEntityType: string | null;
  relatedEntityId: string | null;
  createdAt: string;
  updatedAt: string;
  resolvedAt: string | null;
  timeline: IncidentEvent[];
}

// =============================================================================
// INTEGRATIONS
// =============================================================================

export interface InteropConnection {
  id: string;
  endpointId: string | null;
  status: string | null;
  connectedAt: string | null;
  lastError: string | null;
  isActive: boolean;
  updatedAt: string;
}

export interface InteropEndpoint {
  id: string;
  systemId: string | null;
  name: string;
  baseUrl: string | null;
  authType: string | null;
  isActive: boolean;
  createdAt: string;
}

export interface InteropSystem {
  id: string;
  code: string | null;
  name: string;
}

export interface InteropMessage {
  id: string;
  direction: string;
  systemId: string | null;
  endpointId: string | null;
  messageType: string | null;
  externalMessageId: string | null;
  status: string | null;
  createdAt: string;
}

export interface InteropMessageStat {
  direction: string;
  status: string;
  count: number;
}

export interface IntegrationsOverview {
  connections: InteropConnection[];
  endpoints: InteropEndpoint[];
  systems: InteropSystem[];
  messages: InteropMessage[];
  messageStats: InteropMessageStat[];
}

// =============================================================================
// NOTIFICATIONS
// =============================================================================

export interface CommMessage {
  id: string;
  threadId: string | null;
  senderType: string;
  senderId: string | null;
  messageType: string;
  body: string | null;
  sentAt: string;
  status: string | null;
}

export interface CommDelivery {
  id: string;
  messageId: string;
  notificationId: string | null;
  channel: string;
  provider: string | null;
  status: string;
  attemptedAt: string;
  sentAt: string | null;
  error: string | null;
}

export interface CommMessageStat {
  messageType: string;
  status: string;
  count: number;
}

export interface NotificationsOverview {
  limit: number;
  offset: number;
  messageTotal: number;
  messages: CommMessage[];
  deliveries: CommDelivery[];
  messageStats: CommMessageStat[];
}

// =============================================================================
// ANALYTICS (Phase G)
// =============================================================================

export interface AnalyticsOverview {
  generatedAt: string;
  encounters: {
    total: number;
    byStatus: { status: string; count: number }[];
  };
  events: {
    total: number;
    failed: number;
    patients: number;
    byType: { eventType: string; count: number }[];
    byDay: { day: string; count: number }[];
    bySource: { sourceType: string; count: number }[];
  };
  decisions: { status: string; count: number }[];
  suggestions: { recommendationType: string; count: number }[];
  alerts: { severity: string; count: number }[];
}

// =============================================================================
// SERVICE CATALOGUE — facility operational service registry
// =============================================================================

export type CatalogueCategory = 'CLINICAL' | 'DIAGNOSTICS' | 'SUPPORT';

export type CatalogueServiceState =
  | 'operational'
  | 'limited'
  | 'suspended'
  | 'planned'
  | 'archived';

export type CataloguePressure = 'LOW' | 'MEDIUM' | 'HIGH';

export interface CatalogueWorkflowNode {
  name: string;
  requiredRole: string;
  inputs: string[];
  outputs: string[];
}

export interface CatalogueWorkforceRole {
  role: string;
  required: number;
}

export interface CataloguePricingVersion {
  label: string;
  active: boolean;
  effective: string | null;
}

export interface CatalogueEquipment {
  name: string;
  status: string;
  utilization: number;
  maintenanceNextDue: string;
}

export interface CatalogueMapping {
  kind: string;
  standard: string;
  representation: string;
  status: 'valid' | 'review' | 'missing';
}

export interface CatalogueGovernanceRule {
  change: string;
  approval: string;
}

export interface CatalogueItem {
  code: string;
  name: string;
}

export interface CatalogueServiceEntry {
  id: string;
  code: string;
  name: string;
  description: string;
  category: CatalogueCategory;
  serviceType: string;
  location: {
    label: string;
    building: string;
    floor: string;
    zone: string;
    rooms: string;
    queue: string;
  };
  department: { code: string; name: string };
  units: {
    offering: string;
    billingUnit: string;
    reportingUnit: string;
  };
  workforce: {
    requiredCapacity: number;
    currentlyAssigned: number;
    onDuty: number;
    coveragePercent: number;
    roles: CatalogueWorkforceRole[];
  };
  workflow: {
    configured: boolean;
    summary: string;
    nodes: CatalogueWorkflowNode[];
  };
  capacity: {
    rooms: number;
    configuredDaily: number;
    current: number;
    demand: number;
    pressure: CataloguePressure;
  };
  pricing: {
    status: 'configured' | 'missing';
    unit: string;
    payerRules: string[];
    baseTariff: string;
    currency: string;
    effective: string | null;
    versions: CataloguePricingVersion[];
  };
  reporting: {
    status: 'valid' | 'missing' | 'review';
    classification: string;
    dataset: string;
    mappingStatus: string;
    lastValidated: string;
  };
  mappings: CatalogueMapping[];
  integrationMapping: boolean;
  status: {
    state: CatalogueServiceState;
    reason: string | null;
    expectedRecovery: string | null;
  };
  dependencies: string[];
  equipment: CatalogueEquipment[];
  integrations: string[];
  items: CatalogueItem[];
  governance: CatalogueGovernanceRule[];
  activity: { today: number; unit: string };
  attention: string | null;
  requiresReview: boolean;
}

export interface CatalogueHealth {
  activeServices: number;
  clinical: number;
  diagnostics: number;
  support: number;
  configuredWorkflows: number;
  reportingMappings: number;
  pricingConfigurations: number;
  requiresReview: number;
  catalogueStatusPercent: number;
  integrity: {
    serviceDefinitions: { complete: number; total: number };
    workflowConfigured: { complete: number; total: number };
    pricingConfigured: { complete: number; total: number };
    reportingMapping: { complete: number; total: number };
    integrationMappings: { complete: number; total: number };
  };
}

export interface CatalogueAttentionItem {
  code: string;
  name: string;
  issue: string;
  severity: 'warn' | 'bad';
}

export interface CatalogueCategoryGroup {
  code: CatalogueCategory;
  label: string;
  count: number;
}

export interface ServiceCatalogueOverview {
  generatedAt: string;
  facility: { name: string; code: string; scope: 'facility' };
  environment: 'demo';
  health: CatalogueHealth;
  categories: CatalogueCategoryGroup[];
  services: CatalogueServiceEntry[];
  attention: CatalogueAttentionItem[];
}

export type AssetRisk = 'low' | 'moderate' | 'high' | 'critical';

export type AssetStatus =
  | 'operational'
  | 'in-service'
  | 'limited'
  | 'offline'
  | 'maintenance';

export type CareDependency =
  | 'low'
  | 'medium'
  | 'high'
  | 'very-high'
  | 'critical';

export type RedundancyLevel = 'none' | 'limited' | 'full';

export interface AssetRiskFactorBreakdown {
  clinicalCriticality: number;
  utilization: number;
  dependency: number;
  redundancyGap: number;
  failureProbability: number;
  recoveryTime: number;
  score: number;
  level: AssetRisk;
}

export interface AssetMaintenance {
  lastService: string;
  nextScheduled: string;
  daysRemaining: number;
  status: 'on-schedule' | 'due-soon' | 'overdue';
  utilizationDeltaPct: number;
  reviewRecommended: boolean;
  reviewReason: string | null;
}

export interface AssetReliability {
  failures90d: number;
  avgDowntimeHrs: number;
  mtbfDays: number;
  lastIncident: string | null;
}

export interface AssetSupplier {
  name: string;
  contract: 'active' | 'expired';
  responseSlaHrs: number;
  lastIntervention: string | null;
}

export interface AssetConsumable {
  name: string;
  daysRemaining: number;
  status: 'ok' | 'low' | 'critical';
}

export interface AssetWorkforceRole {
  role: string;
  covered: boolean;
}

export interface AssetFinancial {
  currency: string;
  configuredUnitCharge: number;
  currentDailyLoad: number;
  dailyGrossExposure: number;
}

export interface AssetExternalAlternative {
  name: string;
  capability: string;
  available: boolean;
  transferMins: number;
  capacity: 'low' | 'moderate' | 'high';
}

export interface AssetOutageStep {
  stage: string;
  detail: string;
}

export interface AssetEntry {
  code: string;
  name: string;
  category: string;
  status: AssetStatus;
  location: string;
  utilizationPct: number;
  configuredCapacityPerDay: number;
  currentLoadPerDay: number;
  remainingCapacityPerDay: number;
  forecastNote: string | null;
  careDependency: CareDependency;
  risk: AssetRisk;
  riskFactors: AssetRiskFactorBreakdown;
  redundancy: RedundancyLevel;
  redundancyNote: string | null;
  clinicalServices: string[];
  scheduledImpact: {
    investigations: number;
    urgent: number;
    departments: number;
    safetyImpact: string | null;
  } | null;
  estimatedRecoveryHrs: string;
  internalAlternatives: string[];
  externalAlternatives: AssetExternalAlternative[];
  maintenance: AssetMaintenance;
  reliability: AssetReliability;
  workforce: AssetWorkforceRole[];
  consumables: AssetConsumable[];
  supplier: AssetSupplier | null;
  integration: { risPacs: boolean; label: string } | null;
  financial: AssetFinancial;
  serviceCode: string | null;
  serviceName: string | null;
  singlePointOfFailure: boolean;
  spofReason: string | null;
  approachingServiceThreshold: boolean;
  thresholdReason: string | null;
  recommendedActions: string[];
  outageChain: AssetOutageStep[];
}

export interface AssetSinglePointOfFailure {
  code: string;
  name: string;
  risk: AssetRisk;
  reason: string;
}

export interface AssetHealthSummary {
  assetsMonitored: number;
  operationalAvailabilityPct: number;
  highRiskAssets: number;
  approachingServiceThreshold: number;
  ctExposedScheduledInvestigations: number;
  reviewRecommended: number;
}

export interface AssetResilience {
  pct: number;
  level: 'moderate' | 'strong' | 'weak';
  note: string;
  factors: {
    criticalServicesWithRedundancy: { n: number; of: number };
    singlePointsOfFailure: number;
    servicesWithExternalContingency: number;
    assetsWithOverdueMaintenance: number;
    approachingServiceThreshold: number;
  };
  opportunity: string;
}

export interface AssetIntelligenceOverview {
  generatedAt: string;
  facility: { name: string; code: string; scope: 'facility' };
  environment: 'demo';
  constitutionalRule: string;
  health: AssetHealthSummary;
  resilience: AssetResilience;
  singlePointsOfFailure: AssetSinglePointOfFailure[];
  maintenance: { dueSoon: number; overdue: number };
  assets: AssetEntry[];
}
