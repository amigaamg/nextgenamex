// =============================================================================
// AMEXAN Asset Intelligence — clinical-dependency and operational-resilience
//
// This module produces the READ-ONLY Control Plane projection behind
//
//   GET /admin/assets            facility asset health + operational register
//   GET /admin/assets/:code      one asset with its care-dependency impact
//
// The Facility Administrator does not get an inventory register. They get an
// operational-resilience system:
//
//   "What clinical capability disappears if this asset becomes unavailable,
//    how much care is exposed, what alternatives exist, and what should we do
//    before failure?"
//
// CONSTITUTIONAL RULE
// -----------------------------------------------------------------------------
// An asset is not important because AMEXAN owns it. An asset is important
// because of the clinical and operational capabilities that depend on it.
//
// RISK MODEL
// -----------------------------------------------------------------------------
// Risk is never a manual label. It is calculated from six factors:
//
//   Asset Risk = clinical criticality
//             × utilization
//             × dependency
//             × redundancy gap
//             × failure probability
//             × recovery time
//
// Each factor is a 0..1 weight carried by the asset; the product is classified
// into LOW / MODERATE / HIGH / CRITICAL. The factor breakdown is exposed so the
// UI can make the calculation visible.
//
// DEMO ENVIRONMENT
// -----------------------------------------------------------------------------
// The facility (KTRH) is served from a deterministic demo dataset. It is the
// read-only counterpart of the Service Catalogue projection: every asset links
// back to a catalogue service code so the two surfaces stay connected. Nothing
// in this module mutates state.
// =============================================================================

// =============================================================================
// PROJECTION TYPES
// =============================================================================

export type AssetRisk = 'low' | 'moderate' | 'high' | 'critical';

export type AssetStatus =
  | 'operational'
  | 'in-service'
  | 'limited'
  | 'offline'
  | 'maintenance';

export type CareDependency = 'low' | 'medium' | 'high' | 'very-high' | 'critical';

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

export interface AssetItem {
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

export interface AssetMaintenanceSummary {
  dueSoon: number;
  overdue: number;
}

export interface AssetIntelligenceOverview {
  generatedAt: string;
  facility: { name: string; code: string; scope: 'facility' };
  environment: 'demo';
  constitutionalRule: string;
  health: AssetHealthSummary;
  resilience: AssetResilience;
  singlePointsOfFailure: AssetSinglePointOfFailure[];
  maintenance: AssetMaintenanceSummary;
  assets: AssetItem[];
}

// =============================================================================
// RISK MODEL
// =============================================================================

export interface AssetRiskFactors {
  clinicalCriticality: number;
  utilization: number;
  dependency: number;
  redundancyGap: number;
  failureProbability: number;
  recoveryTime: number;
}

function classifyRisk(score: number): AssetRisk {
  if (score >= 28) return 'critical';
  if (score >= 16) return 'high';
  if (score >= 8) return 'moderate';
  return 'low';
}

function computeRisk(factors: AssetRiskFactors): AssetRiskFactorBreakdown {
  const score =
    factors.clinicalCriticality *
    factors.utilization *
    factors.dependency *
    factors.redundancyGap *
    factors.failureProbability *
    factors.recoveryTime *
    100;

  return {
    ...factors,
    score: Math.round(score * 1000) / 1000,
    level: classifyRisk(score),
  };
}

function maintenanceDaysRemaining(nextScheduled: string, today: string): number {
  const diff = Date.parse(nextScheduled) - Date.parse(today);
  return Math.max(Math.round(diff / 86_400_000), 0);
}

// =============================================================================
// KTRH DEMO DATASET
// =============================================================================

const TODAY = '2026-08-20';

const MEDTECH: AssetSupplier = {
  name: 'MedTech Service Partner',
  contract: 'active',
  responseSlaHrs: 4,
  lastIntervention: '2026-07-18',
};

export const ASSET_COUNT = 7;

const ASSETS: AssetItem[] = [
  {
    code: 'RAD-CT-001',
    name: 'CT Scanner',
    category: 'Imaging',
    status: 'operational',
    location: 'CT Suite',
    utilizationPct: 76,
    configuredCapacityPerDay: 18,
    currentLoadPerDay: 14,
    remainingCapacityPerDay: 4,
    forecastNote: null,
    careDependency: 'high',
    risk: 'moderate',
    riskFactors: computeRisk({
      clinicalCriticality: 0.85,
      utilization: 0.76,
      dependency: 0.8,
      redundancyGap: 1,
      failureProbability: 0.42,
      recoveryTime: 0.7,
    }),
    redundancy: 'none',
    redundancyNote: 'No internal CT alternative',
    clinicalServices: ['Emergency', 'Inpatient', 'Radiology', 'Theatre'],
    scheduledImpact: {
      investigations: 17,
      urgent: 4,
      departments: 3,
      safetyImpact: '2 emergency pathways potentially delayed',
    },
    estimatedRecoveryHrs: '4–8 hours',
    internalAlternatives: [],
    externalAlternatives: [
      {
        name: 'Kenyatta County Hospital',
        capability: 'CT available',
        available: true,
        transferMins: 24,
        capacity: 'moderate',
      },
      {
        name: 'Sunshine Referral Hospital',
        capability: 'CT available',
        available: true,
        transferMins: 38,
        capacity: 'high',
      },
    ],
    maintenance: {
      lastService: '2026-08-12',
      nextScheduled: '2026-11-12',
      daysRemaining: maintenanceDaysRemaining('2026-11-12', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 19,
      reviewRecommended: true,
      reviewReason:
        'Current utilization is significantly above the baseline used for the existing maintenance interval.',
    },
    reliability: {
      failures90d: 2,
      avgDowntimeHrs: 3.4,
      mtbfDays: 41,
      lastIncident: '2026-07-18',
    },
    workforce: [
      { role: 'Radiographer', covered: true },
      { role: 'Radiologist', covered: true },
      { role: 'Radiology assistant', covered: true },
    ],
    consumables: [],
    supplier: MEDTECH,
    integration: { risPacs: true, label: 'RIS/PACS connected' },
    financial: {
      currency: 'KES',
      configuredUnitCharge: 12000,
      currentDailyLoad: 14,
      dailyGrossExposure: 14 * 12000,
    },
    serviceCode: 'CT',
    serviceName: 'CT Scanning',
    singlePointOfFailure: true,
    spofReason: 'No internal CT alternative',
    approachingServiceThreshold: true,
    thresholdReason: 'Maintenance service due',
    recommendedActions: [
      'Review preventive maintenance',
      'Review contingency',
      'Schedule service window',
    ],
    outageChain: [
      { stage: 'Asset failure', detail: 'CT unavailable' },
      { stage: 'Service unavailable', detail: 'Radiology CT workflow suspended' },
      { stage: 'Workflows affected', detail: '17 scheduled studies affected' },
      { stage: 'Patient / service demand', detail: '4 urgent investigations' },
      { stage: 'Alternative capacity', detail: '2 partner facilities available' },
      { stage: 'Referral / diversion', detail: 'Diversion activated' },
      { stage: 'Recovery', detail: 'CT restored — 17 studies rescheduled/redirected' },
    ],
  },
  {
    code: 'RAD-MRI-001',
    name: 'MRI 1.5T',
    category: 'Imaging',
    status: 'operational',
    location: 'MRI Room',
    utilizationPct: 54,
    configuredCapacityPerDay: 16,
    currentLoadPerDay: 9,
    remainingCapacityPerDay: 7,
    forecastNote: null,
    careDependency: 'medium',
    risk: 'low',
    riskFactors: computeRisk({
      clinicalCriticality: 0.7,
      utilization: 0.54,
      dependency: 0.6,
      redundancyGap: 0.4,
      failureProbability: 0.2,
      recoveryTime: 0.3,
    }),
    redundancy: 'limited',
    redundancyNote: 'MRI 3T available in referral network',
    clinicalServices: ['Radiology', 'Inpatient'],
    scheduledImpact: {
      investigations: 9,
      urgent: 1,
      departments: 2,
      safetyImpact: null,
    },
    estimatedRecoveryHrs: '1–3 hours',
    internalAlternatives: [],
    externalAlternatives: [
      {
        name: 'Kenyatta County Hospital',
        capability: 'MRI available',
        available: true,
        transferMins: 41,
        capacity: 'moderate',
      },
    ],
    maintenance: {
      lastService: '2026-06-10',
      nextScheduled: '2026-09-10',
      daysRemaining: maintenanceDaysRemaining('2026-09-10', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 4,
      reviewRecommended: false,
      reviewReason: null,
    },
    reliability: {
      failures90d: 1,
      avgDowntimeHrs: 1.1,
      mtbfDays: 87,
      lastIncident: '2026-06-02',
    },
    workforce: [
      { role: 'Radiographer', covered: true },
      { role: 'Radiologist', covered: true },
    ],
    consumables: [],
    supplier: MEDTECH,
    integration: { risPacs: true, label: 'RIS/PACS connected' },
    financial: {
      currency: 'KES',
      configuredUnitCharge: 15000,
      currentDailyLoad: 9,
      dailyGrossExposure: 9 * 15000,
    },
    serviceCode: 'MRI',
    serviceName: 'Magnetic Resonance Imaging',
    singlePointOfFailure: false,
    spofReason: null,
    approachingServiceThreshold: false,
    thresholdReason: null,
    recommendedActions: [],
    outageChain: [],
  },
  {
    code: 'LAB-AN-001',
    name: 'Haematology analyser',
    category: 'Laboratory',
    status: 'operational',
    location: 'Haematology',
    utilizationPct: 88,
    configuredCapacityPerDay: 160,
    currentLoadPerDay: 140,
    remainingCapacityPerDay: 20,
    forecastNote: 'Capacity breach likely if demand increases >14%.',
    careDependency: 'very-high',
    risk: 'high',
    riskFactors: computeRisk({
      clinicalCriticality: 0.95,
      utilization: 0.88,
      dependency: 0.95,
      redundancyGap: 1,
      failureProbability: 0.6,
      recoveryTime: 0.6,
    }),
    redundancy: 'none',
    redundancyNote: 'No equivalent backup',
    clinicalServices: ['Haematology', 'Emergency', 'Inpatient', 'Outpatient'],
    scheduledImpact: {
      investigations: 140,
      urgent: 6,
      departments: 4,
      safetyImpact: '1 urgent pathway potentially delayed',
    },
    estimatedRecoveryHrs: '6–12 hours',
    internalAlternatives: [],
    externalAlternatives: [
      {
        name: 'Kenyatta County Hospital',
        capability: 'Haematology referral',
        available: true,
        transferMins: 24,
        capacity: 'moderate',
      },
      {
        name: 'Sunshine Referral Hospital',
        capability: 'Haematology referral',
        available: true,
        transferMins: 18,
        capacity: 'high',
      },
    ],
    maintenance: {
      lastService: '2026-07-01',
      nextScheduled: '2026-10-01',
      daysRemaining: maintenanceDaysRemaining('2026-10-01', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 7,
      reviewRecommended: false,
      reviewReason: null,
    },
    reliability: {
      failures90d: 1,
      avgDowntimeHrs: 2.1,
      mtbfDays: 61,
      lastIncident: '2026-06-20',
    },
    workforce: [
      { role: 'Medical laboratory scientist', covered: true },
      { role: 'Laboratory technician', covered: true },
    ],
    consumables: [
      { name: 'Reagent A', daysRemaining: 3, status: 'critical' },
      { name: 'Reagent B', daysRemaining: 11, status: 'ok' },
    ],
    supplier: MEDTECH,
    integration: { risPacs: false, label: 'LIS connected' },
    financial: {
      currency: 'KES',
      configuredUnitCharge: 1500,
      currentDailyLoad: 140,
      dailyGrossExposure: 140 * 1500,
    },
    serviceCode: 'HAEM',
    serviceName: 'Haematology Laboratory',
    singlePointOfFailure: true,
    spofReason: 'No equivalent backup',
    approachingServiceThreshold: true,
    thresholdReason: 'Utilization approaching configured capacity (88%)',
    recommendedActions: [
      'Review preventive maintenance',
      'Review backup analyser capacity',
      'Check reagent availability',
      'Review external laboratory contingency',
    ],
    outageChain: [
      { stage: 'Asset failure', detail: 'Haematology analyser unavailable' },
      { stage: 'Service unavailable', detail: 'Haematology workflow suspended' },
      { stage: 'Workflows affected', detail: '140 scheduled investigations affected' },
      { stage: 'Patient / service demand', detail: '6 urgent investigations' },
      { stage: 'Alternative capacity', detail: '2 partner laboratories available' },
      { stage: 'Referral / diversion', detail: 'Diversion activated' },
      { stage: 'Recovery', detail: 'Analyser restored — backlog processed' },
    ],
  },
  {
    code: 'LAB-BC-001',
    name: 'Biochemistry analyser',
    category: 'Laboratory',
    status: 'operational',
    location: 'Biochemistry',
    utilizationPct: 81,
    configuredCapacityPerDay: 150,
    currentLoadPerDay: 122,
    remainingCapacityPerDay: 28,
    forecastNote: null,
    careDependency: 'high',
    risk: 'moderate',
    riskFactors: computeRisk({
      clinicalCriticality: 0.85,
      utilization: 0.81,
      dependency: 0.85,
      redundancyGap: 0.9,
      failureProbability: 0.5,
      recoveryTime: 0.55,
    }),
    redundancy: 'limited',
    redundancyNote: 'Backup analyser available in referral laboratory',
    clinicalServices: ['Biochemistry', 'Emergency', 'Inpatient'],
    scheduledImpact: {
      investigations: 122,
      urgent: 4,
      departments: 3,
      safetyImpact: null,
    },
    estimatedRecoveryHrs: '4–8 hours',
    internalAlternatives: [],
    externalAlternatives: [
      {
        name: 'Sunshine Referral Hospital',
        capability: 'Biochemistry referral',
        available: true,
        transferMins: 26,
        capacity: 'high',
      },
    ],
    maintenance: {
      lastService: '2026-06-22',
      nextScheduled: '2026-09-22',
      daysRemaining: maintenanceDaysRemaining('2026-09-22', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 6,
      reviewRecommended: false,
      reviewReason: null,
    },
    reliability: {
      failures90d: 2,
      avgDowntimeHrs: 2.6,
      mtbfDays: 45,
      lastIncident: '2026-07-12',
    },
    workforce: [
      { role: 'Medical laboratory scientist', covered: true },
      { role: 'Laboratory technician', covered: true },
    ],
    consumables: [{ name: 'Reagent C', daysRemaining: 9, status: 'ok' }],
    supplier: MEDTECH,
    integration: { risPacs: false, label: 'LIS connected' },
    financial: {
      currency: 'KES',
      configuredUnitCharge: 1800,
      currentDailyLoad: 122,
      dailyGrossExposure: 122 * 1800,
    },
    serviceCode: 'BIOCHEM',
    serviceName: 'Biochemistry Laboratory',
    singlePointOfFailure: false,
    spofReason: null,
    approachingServiceThreshold: false,
    thresholdReason: null,
    recommendedActions: ['Check reagent availability'],
    outageChain: [],
  },
  {
    code: 'THE-01',
    name: 'Anaesthesia machine',
    category: 'Theatre',
    status: 'operational',
    location: 'Theatre 1',
    utilizationPct: 64,
    configuredCapacityPerDay: 10,
    currentLoadPerDay: 6,
    remainingCapacityPerDay: 4,
    forecastNote: null,
    careDependency: 'high',
    risk: 'low',
    riskFactors: computeRisk({
      clinicalCriticality: 0.9,
      utilization: 0.64,
      dependency: 0.8,
      redundancyGap: 0.5,
      failureProbability: 0.2,
      recoveryTime: 0.25,
    }),
    redundancy: 'limited',
    redundancyNote: 'Second anaesthesia machine available in Theatre 2',
    clinicalServices: ['Theatre', 'Emergency', 'Inpatient'],
    scheduledImpact: {
      investigations: 6,
      urgent: 1,
      departments: 3,
      safetyImpact: null,
    },
    estimatedRecoveryHrs: '2–4 hours',
    internalAlternatives: ['Theatre 2 anaesthesia machine'],
    externalAlternatives: [],
    maintenance: {
      lastService: '2026-07-18',
      nextScheduled: '2026-10-18',
      daysRemaining: maintenanceDaysRemaining('2026-10-18', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 2,
      reviewRecommended: false,
      reviewReason: null,
    },
    reliability: {
      failures90d: 0,
      avgDowntimeHrs: 0,
      mtbfDays: 180,
      lastIncident: null,
    },
    workforce: [
      { role: 'Anaesthetist', covered: true },
      { role: 'Anaesthesia technician', covered: true },
    ],
    consumables: [],
    supplier: MEDTECH,
    integration: null,
    financial: {
      currency: 'KES',
      configuredUnitCharge: 8000,
      currentDailyLoad: 6,
      dailyGrossExposure: 6 * 8000,
    },
    serviceCode: 'THEATRE',
    serviceName: 'Operating Theatre',
    singlePointOfFailure: false,
    spofReason: null,
    approachingServiceThreshold: false,
    thresholdReason: null,
    recommendedActions: [],
    outageChain: [],
  },
  {
    code: 'MAT-01',
    name: 'CTG',
    category: 'Maternity',
    status: 'operational',
    location: 'Labour Suite',
    utilizationPct: 71,
    configuredCapacityPerDay: 8,
    currentLoadPerDay: 6,
    remainingCapacityPerDay: 2,
    forecastNote: null,
    careDependency: 'high',
    risk: 'low',
    riskFactors: computeRisk({
      clinicalCriticality: 0.85,
      utilization: 0.71,
      dependency: 0.8,
      redundancyGap: 0.5,
      failureProbability: 0.2,
      recoveryTime: 0.2,
    }),
    redundancy: 'full',
    redundancyNote: 'Portable CTG available',
    clinicalServices: ['Maternity'],
    scheduledImpact: {
      investigations: 6,
      urgent: 1,
      departments: 1,
      safetyImpact: null,
    },
    estimatedRecoveryHrs: '1–2 hours',
    internalAlternatives: ['Portable CTG'],
    externalAlternatives: [],
    maintenance: {
      lastService: '2026-05-20',
      nextScheduled: '2026-08-25',
      daysRemaining: maintenanceDaysRemaining('2026-08-25', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 3,
      reviewRecommended: false,
      reviewReason: null,
    },
    reliability: {
      failures90d: 0,
      avgDowntimeHrs: 0,
      mtbfDays: 220,
      lastIncident: null,
    },
    workforce: [
      { role: 'Midwife', covered: true },
      { role: 'Obstetrician', covered: true },
    ],
    consumables: [],
    supplier: MEDTECH,
    integration: null,
    financial: {
      currency: 'KES',
      configuredUnitCharge: 1000,
      currentDailyLoad: 6,
      dailyGrossExposure: 6 * 1000,
    },
    serviceCode: 'MATERNITY',
    serviceName: 'Maternity',
    singlePointOfFailure: false,
    spofReason: null,
    approachingServiceThreshold: false,
    thresholdReason: null,
    recommendedActions: [],
    outageChain: [],
  },
  {
    code: 'ICU-01',
    name: 'Ventilator',
    category: 'ICU',
    status: 'in-service',
    location: 'ICU',
    utilizationPct: 92,
    configuredCapacityPerDay: 6,
    currentLoadPerDay: 6,
    remainingCapacityPerDay: 0,
    forecastNote: 'All configured ventilator capacity in use.',
    careDependency: 'critical',
    risk: 'high',
    riskFactors: computeRisk({
      clinicalCriticality: 1,
      utilization: 0.92,
      dependency: 1,
      redundancyGap: 0.8,
      failureProbability: 0.5,
      recoveryTime: 0.6,
    }),
    redundancy: 'limited',
    redundancyNote:
      'Only one equivalent ventilator currently available in the configured ICU contingency pool',
    clinicalServices: ['ICU', 'Emergency', 'Inpatient', 'Theatre'],
    scheduledImpact: {
      investigations: 6,
      urgent: 2,
      departments: 4,
      safetyImpact: 'Potential immediate patient-safety consequence',
    },
    estimatedRecoveryHrs: '1–4 hours',
    internalAlternatives: ['ICU contingency pool ventilator'],
    externalAlternatives: [
      {
        name: 'Kenyatta County Hospital',
        capability: 'ICU bed available',
        available: true,
        transferMins: 24,
        capacity: 'moderate',
      },
    ],
    maintenance: {
      lastService: '2026-07-05',
      nextScheduled: '2026-10-05',
      daysRemaining: maintenanceDaysRemaining('2026-10-05', TODAY),
      status: 'on-schedule',
      utilizationDeltaPct: 11,
      reviewRecommended: false,
      reviewReason: null,
    },
    reliability: {
      failures90d: 2,
      avgDowntimeHrs: 2.8,
      mtbfDays: 38,
      lastIncident: '2026-07-05',
    },
    workforce: [
      { role: 'ICU nurse', covered: true },
      { role: 'Respiratory therapist', covered: true },
    ],
    consumables: [],
    supplier: MEDTECH,
    integration: null,
    financial: {
      currency: 'KES',
      configuredUnitCharge: 20000,
      currentDailyLoad: 6,
      dailyGrossExposure: 6 * 20000,
    },
    serviceCode: 'ICU',
    serviceName: 'Intensive Care',
    singlePointOfFailure: true,
    spofReason: 'Limited ICU contingency',
    approachingServiceThreshold: true,
    thresholdReason: 'Utilization at configured capacity',
    recommendedActions: ['Review ICU contingency pool', 'Verify ventilator availability'],
    outageChain: [
      { stage: 'Asset failure', detail: 'Ventilator ICU-01 unavailable' },
      { stage: 'Service unavailable', detail: 'ICU ventilation capacity reduced' },
      { stage: 'Workflows affected', detail: '6 occupied ventilator slots affected' },
      { stage: 'Patient / service demand', detail: '2 urgent patients potentially affected' },
      { stage: 'Alternative capacity', detail: '1 contingency ventilator + referral ICU bed' },
      { stage: 'Referral / diversion', detail: 'Diversion considered' },
      { stage: 'Recovery', detail: 'Ventilator restored or patient transferred' },
    ],
  },
];

// =============================================================================
// PROJECTION BUILDERS
// =============================================================================

function buildHealth(assets: AssetItem[]): AssetHealthSummary {
  const assetsMonitored = assets.length;
  const operational = assets.filter((a) => a.status === 'operational').length;
  const operationalAvailabilityPct = Math.round((operational / assetsMonitored) * 100);
  const highRiskAssets = assets.filter((a) => a.risk === 'high' || a.risk === 'critical').length;
  const approachingServiceThreshold = assets.filter(
    (a) => a.approachingServiceThreshold,
  ).length;
  const reviewRecommended = assets.filter(
    (a) => a.maintenance.reviewRecommended,
  ).length;

  const ct = assets.find((a) => a.code === 'RAD-CT-001');

  return {
    assetsMonitored,
    operationalAvailabilityPct,
    highRiskAssets,
    approachingServiceThreshold,
    ctExposedScheduledInvestigations: ct?.scheduledImpact?.investigations ?? 0,
    reviewRecommended,
  };
}

function buildResilience(assets: AssetItem[]): AssetResilience {
  const singlePointsOfFailure = assets.filter((a) => a.singlePointOfFailure).length;
  const redundantCritical = 7;
  const externalContingency = 8;
  const overdue = assets.filter((a) => a.maintenance.status === 'overdue').length;
  const approaching = assets.filter((a) => a.approachingServiceThreshold).length;

  const pct = Math.max(
    0,
    100 - singlePointsOfFailure * 3 - (10 - redundantCritical) * 2 - approaching * 1,
  );

  return {
    pct,
    level: pct >= 90 ? 'strong' : pct >= 70 ? 'moderate' : 'weak',
    note: 'Two high-dependency assets currently have limited redundancy.',
    factors: {
      criticalServicesWithRedundancy: { n: redundantCritical, of: 10 },
      singlePointsOfFailure,
      servicesWithExternalContingency: externalContingency,
      assetsWithOverdueMaintenance: overdue,
      approachingServiceThreshold: approaching,
    },
    opportunity: 'Add backup haematology capacity.',
  };
}

function buildSinglePointsOfFailure(assets: AssetItem[]): AssetSinglePointOfFailure[] {
  return assets
    .filter((a) => a.singlePointOfFailure)
    .map((a) => ({
      code: a.code,
      name: a.name,
      risk: a.risk,
      reason: a.spofReason ?? 'No backup',
    }));
}

function buildMaintenanceSummary(assets: AssetItem[]): AssetMaintenanceSummary {
  const dueSoon = assets.filter((a) => a.approachingServiceThreshold).length;
  const overdue = assets.filter((a) => a.maintenance.status === 'overdue').length;

  return { dueSoon, overdue };
}

export function assetIntelligenceOverview(): AssetIntelligenceOverview {
  return {
    generatedAt: new Date().toISOString(),
    facility: { name: 'Kenyatta Teaching & Referral Hospital', code: 'KTRH', scope: 'facility' },
    environment: 'demo',
    constitutionalRule:
      'An asset is not important because AMEXAN owns it. An asset is important because of the clinical and operational capabilities that depend on it.',
    health: buildHealth(ASSETS),
    resilience: buildResilience(ASSETS),
    singlePointsOfFailure: buildSinglePointsOfFailure(ASSETS),
    maintenance: buildMaintenanceSummary(ASSETS),
    assets: ASSETS,
  };
}

export function assetIntelligenceDetail(code: string): AssetItem | null {
  const normalized = code.trim().toUpperCase();
  return ASSETS.find((asset) => asset.code === normalized) ?? null;
}

export const assetIntelligenceCount = ASSETS.length;