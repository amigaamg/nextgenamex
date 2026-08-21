// =============================================================================
// AMEXAN Service Catalogue — facility operational service registry
//
// This module produces the READ-ONLY Control Plane projection behind
//
//   GET /admin/catalogues            the full facility catalogue overview
//   GET /admin/catalogues/:code      one service with its operational definition
//
// The Facility Administrator treats this page as the configuration source for
// the rest of AMEXAN: every service carries its operational definition
// (department · location · workforce · workflow · capacity · pricing ·
// reporting · integrations), and downstream surfaces (Clinical Operations,
// Workforce Analytics, Financial, HMIS Connection, Asset Intelligence,
// Referral/Ecosystem) consume these projections.
//
// DEMO ENVIRONMENT
// -----------------------------------------------------------------------------
// The facility (KTRH) is served from a deterministic demo dataset. The shape of
// the projection mirrors the Phase 1 schema (organization.service ·
// department · facility_service · department_service · service_location), and
// the operational fields are exactly the fields the catalogue owns once it is a
// governed configuration. Nothing in this module mutates state.
//
// AMEXAN RULE (service ≠ department)
// -----------------------------------------------------------------------------
// A department is an organizational unit; a service is an operational
// capability. A department may provide many services and a service may be
// delivered across many departments (many-to-many). This projection preserves
// that separation — the responsible department is a reference, never the
// service's identity.
// =============================================================================

// =============================================================================
// PROJECTION TYPES
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

export interface CatalogueService {
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

export interface CatalogueIntegrityItem {
  complete: number;
  total: number;
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
    serviceDefinitions: CatalogueIntegrityItem;
    workflowConfigured: CatalogueIntegrityItem;
    pricingConfigured: CatalogueIntegrityItem;
    reportingMapping: CatalogueIntegrityItem;
    integrationMappings: CatalogueIntegrityItem;
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

export interface CatalogueOverview {
  generatedAt: string;
  facility: { name: string; code: string; scope: 'facility' };
  environment: 'demo';
  health: CatalogueHealth;
  categories: CatalogueCategoryGroup[];
  services: CatalogueService[];
  attention: CatalogueAttentionItem[];
}

// =============================================================================
// HELPERS
// =============================================================================

const DEFAULT_GOVERNANCE: CatalogueGovernanceRule[] = [
  { change: 'Change reporting classification', approval: 'Configuration review' },
  { change: 'Change clinical workflow', approval: 'Clinical governance review' },
  { change: 'Change tariff', approval: 'Finance authorization' },
  { change: 'Change staffing requirement', approval: 'Workforce / administrative authorization' },
];

function node(name: string, requiredRole: string, inputs: string[], outputs: string[]): CatalogueWorkflowNode {
  return { name, requiredRole, inputs, outputs };
}

// =============================================================================
// KTRH DEMO DATASET
// =============================================================================

const SERVICES: CatalogueService[] = [
  // ===========================================================================
  // CLINICAL (8)
  // ===========================================================================
  {
    id: 'svc-opd',
    code: 'OPD',
    name: 'Outpatient Department',
    description: 'General ambulatory consultations for the facility.',
    category: 'CLINICAL',
    serviceType: 'Ambulatory care',
    location: {
      label: 'Outpatient Complex',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'OPD',
      rooms: '01–12',
      queue: 'OPD-GENERAL',
    },
    department: { code: 'GEN-OUT', name: 'General Outpatient Services' },
    units: { offering: 'Encounter / visit', billingUnit: 'Encounter', reportingUnit: 'Visit' },
    workforce: {
      requiredCapacity: 12,
      currentlyAssigned: 14,
      onDuty: 9,
      coveragePercent: 92,
      roles: [
        { role: 'Clinical Officer', required: 2 },
        { role: 'Medical Officer', required: 4 },
        { role: 'Nurse', required: 4 },
        { role: 'Registration', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Registration → Triage → Consultation → Orders/Rx → Disposition',
      nodes: [
        node('Registration', 'Registration Clerk', ['Patient identity', 'Demographics'], ['Active encounter', 'Queue entry']),
        node('Triage', 'Nurse / Clinical Officer', ['Vitals', 'Chief complaint', 'Priority'], ['Triage category', 'Queue destination']),
        node('Consultation', 'Clinician', ['Clinical history', 'Examination', 'Triage data'], ['Assessment', 'Orders', 'Treatment', 'Disposition']),
        node('Orders / Rx', 'Clinician', ['Orders', 'Prescription'], ['Investigations', 'Dispensing queue']),
        node('Disposition', 'Clinician', ['Assessment', 'Results'], ['Admission / Referral / Follow-up']),
      ],
    },
    capacity: {
      rooms: 12,
      configuredDaily: 180,
      current: 156,
      demand: 194,
      pressure: 'HIGH',
    },
    pricing: {
      status: 'configured',
      unit: 'Encounter',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 750',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
        { label: 'Special contract tariff', active: false, effective: null },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 101',
      dataset: 'Outpatient Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 101', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'OPD-ENC', status: 'valid' },
      { kind: 'External', standard: 'FHIR R4', representation: 'Encounter (ambulatory)', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Pharmacy', 'Laboratory', 'Radiology'],
    equipment: [],
    integrations: ['HMIS', 'FHIR gateway'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 156, unit: 'visits' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-em',
    code: 'EM',
    name: 'Emergency',
    description: '24-hour emergency and resuscitation care.',
    category: 'CLINICAL',
    serviceType: 'Emergency care',
    location: {
      label: 'Emergency Bay',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'EMERGENCY',
      rooms: 'ER 01–08',
      queue: 'EM-TRIAGE',
    },
    department: { code: 'EMERGENCY', name: 'Accident & Emergency' },
    units: { offering: 'Episode', billingUnit: 'Episode', reportingUnit: 'Attendance' },
    workforce: {
      requiredCapacity: 9,
      currentlyAssigned: 10,
      onDuty: 6,
      coveragePercent: 88,
      roles: [
        { role: 'Medical Officer', required: 3 },
        { role: 'Nurse', required: 4 },
        { role: 'Triage', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Triage → Resuscitation → Investigation → Admission / Discharge',
      nodes: [
        node('Triage', 'Nurse / Clinical Officer', ['Vitals', 'Presentation', 'Priority'], ['Priority', 'Resus / Wait queue']),
        node('Resuscitation', 'Medical Officer', ['Priority', 'Airway / Breathing / Circulation'], ['Stabilisation', 'Initial orders']),
        node('Investigation', 'Clinician', ['Orders', 'Vitals'], ['Results', 'Diagnosis']),
        node('Admission / Discharge', 'Clinician', ['Assessment', 'Results'], ['Admission decision', 'Discharge / Referral']),
      ],
    },
    capacity: { rooms: 8, configuredDaily: 120, current: 98, demand: 116, pressure: 'HIGH' },
    pricing: {
      status: 'configured',
      unit: 'Episode',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 1,200',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 102',
      dataset: 'Emergency Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 102', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'EM-EP', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Laboratory', 'Radiology', 'Blood Bank', 'Theatre'],
    equipment: [],
    integrations: ['HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 98, unit: 'attendances' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-med',
    code: 'MED',
    name: 'Inpatient',
    description: 'Adult medical and surgical ward care.',
    category: 'CLINICAL',
    serviceType: 'Inpatient care',
    location: {
      label: 'Wards 1–5',
      building: 'Main Hospital',
      floor: '1–2',
      zone: 'WARD',
      rooms: 'W1–W5',
      queue: 'WARD-ADMISSIONS',
    },
    department: { code: 'INPATIENT', name: 'Inpatient Services' },
    units: { offering: 'Bed-day', billingUnit: 'Bed-day', reportingUnit: 'Inpatient day' },
    workforce: {
      requiredCapacity: 32,
      currentlyAssigned: 34,
      onDuty: 22,
      coveragePercent: 90,
      roles: [
        { role: 'Medical Officer', required: 8 },
        { role: 'Nurse', required: 20 },
        { role: 'Nursing Aide', required: 4 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Admission → Ward care → Review → Discharge',
      nodes: [
        node('Admission', 'Nurse', ['Admission order', 'Biodata'], ['Ward allocation', 'Care plan start']),
        node('Ward care', 'Nurse', ['Orders', 'Vitals'], ['Observations', 'Medication record']),
        node('Review', 'Clinician', ['Observations', 'Results'], ['Assessment', 'Updated plan']),
        node('Discharge', 'Clinician', ['Readiness', 'Discharge plan'], ['Discharge summary', 'Follow-up']),
      ],
    },
    capacity: { rooms: 40, configuredDaily: 160, current: 132, demand: 141, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Bed-day',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 4,500',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 201',
      dataset: 'Inpatient Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 201', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'INP-BD', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Pharmacy', 'Laboratory', 'Radiology'],
    equipment: [],
    integrations: ['HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 132, unit: 'occupied bed-days' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-icu',
    code: 'ICU',
    name: 'Intensive Care Unit',
    description: 'High-dependency monitoring and intervention.',
    category: 'CLINICAL',
    serviceType: 'Critical care',
    location: {
      label: 'Third Floor',
      building: 'Main Hospital',
      floor: '3',
      zone: 'ICU',
      rooms: 'ICU 01–08',
      queue: 'ICU-REFERRALS',
    },
    department: { code: 'ICU', name: 'Intensive Care' },
    units: { offering: 'Bed-day', billingUnit: 'Bed-day', reportingUnit: 'ICU day' },
    workforce: {
      requiredCapacity: 14,
      currentlyAssigned: 14,
      onDuty: 9,
      coveragePercent: 86,
      roles: [
        { role: 'Intensivist', required: 2 },
        { role: 'Critical Care Nurse', required: 10 },
        { role: 'Physiotherapist', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Admission → Monitoring → Intervention → Step-down / Discharge',
      nodes: [
        node('Admission', 'Intensivist', ['ICU referral', 'Vitals'], ['ICU care plan']),
        node('Monitoring', 'Critical Care Nurse', ['Vitals', 'Observations'], ['Monitor record', 'Escalation']),
        node('Intervention', 'Intensivist', ['Assessment', 'Monitor record'], ['Ventilation', 'Lines', 'Therapy']),
        node('Step-down / Discharge', 'Intensivist', ['Readiness', 'Stability'], ['Step-down transfer', 'Discharge']),
      ],
    },
    capacity: { rooms: 8, configuredDaily: 8, current: 7, demand: 9, pressure: 'HIGH' },
    pricing: {
      status: 'configured',
      unit: 'Bed-day',
      payerRules: ['SHA', 'Private'],
      baseTariff: 'KES 28,000',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 203',
      dataset: 'Critical Care',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 203', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'ICU-BD', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Laboratory', 'Radiology', 'Blood Bank', 'Pharmacy'],
    equipment: [],
    integrations: ['HMIS', 'Ventilator telemetry'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 7, unit: 'occupied ICU bed-days' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-the',
    code: 'THE',
    name: 'Theatre',
    description: 'Operating theatre and surgical procedures.',
    category: 'CLINICAL',
    serviceType: 'Surgical procedure',
    location: {
      label: 'Theatre Suite',
      building: 'Main Hospital',
      floor: '2',
      zone: 'THEATRE',
      rooms: 'TH 01–04',
      queue: 'THEATRE-LIST',
    },
    department: { code: 'SURGERY', name: 'Surgical Services' },
    units: { offering: 'Procedure', billingUnit: 'Procedure', reportingUnit: 'Operation' },
    workforce: {
      requiredCapacity: 18,
      currentlyAssigned: 18,
      onDuty: 11,
      coveragePercent: 84,
      roles: [
        { role: 'Surgeon', required: 4 },
        { role: 'Anaesthetist', required: 3 },
        { role: 'Scrub Nurse', required: 4 },
        { role: 'Circulating Nurse', required: 4 },
        { role: 'Recovery Nurse', required: 3 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Pre-op → Anaesthesia → Procedure → Recovery → Disposition',
      nodes: [
        node('Pre-op', 'Surgeon / Anaesthetist', ['Consent', 'Pre-op workup'], ['Listed procedure', 'Anaesthesia plan']),
        node('Anaesthesia', 'Anaesthetist', ['Anaesthesia plan', 'Vitals'], ['Anaesthetic record', 'Induction']),
        node('Procedure', 'Surgeon', ['Surgical plan', 'Team'], ['Operation note', 'Specimens']),
        node('Recovery', 'Recovery Nurse', ['Vitals', 'Anaesthetic record'], ['Recovery record', 'Discharge to ward']),
        node('Disposition', 'Clinician', ['Recovery record', 'Post-op plan'], ['Ward transfer', 'ICU referral']),
      ],
    },
    capacity: { rooms: 4, configuredDaily: 16, current: 12, demand: 15, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Procedure',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 15,000',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
        { label: 'Special contract tariff', active: false, effective: null },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 301',
      dataset: 'Surgical Procedures',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 301', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'SURG-PROC', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Anaesthesia', 'Sterile processing', 'Blood Bank', 'Laboratory', 'Radiology', 'Pharmacy'],
    equipment: [],
    integrations: ['HMIS', 'Surgical log'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 12, unit: 'procedures' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-obg',
    code: 'OBG',
    name: 'Maternity',
    description: 'Obstetric and gynaecological care including delivery.',
    category: 'CLINICAL',
    serviceType: 'Obstetric care',
    location: {
      label: 'Maternity Ward',
      building: 'Maternity Block',
      floor: '1',
      zone: 'OBG',
      rooms: 'M 01–20',
      queue: 'OBG-ANC',
    },
    department: { code: 'OBGYN', name: 'Obstetrics & Gynaecology' },
    units: { offering: 'Episode / delivery', billingUnit: 'Episode / delivery', reportingUnit: 'Delivery' },
    workforce: {
      requiredCapacity: 22,
      currentlyAssigned: 24,
      onDuty: 14,
      coveragePercent: 91,
      roles: [
        { role: 'Obstetrician', required: 4 },
        { role: 'Midwife', required: 12 },
        { role: 'Clinical Officer', required: 2 },
        { role: 'Nurse', required: 4 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'ANC → Labour → Delivery → Postnatal',
      nodes: [
        node('ANC', 'Midwife / Obstetrician', ['Booking', 'Vitals', 'Fetal assessment'], ['ANC plan', 'Risk classification']),
        node('Labour', 'Midwife', ['Contractions', 'Progress', 'Maternal / fetal vitals'], ['Partogram', 'Labour record']),
        node('Delivery', 'Midwife / Obstetrician', ['Labour record', 'Fetal status'], ['Delivery record', 'Apgar', 'Complications']),
        node('Postnatal', 'Midwife', ['Maternal / neonatal assessment'], ['Postnatal plan', 'Discharge / follow-up']),
      ],
    },
    capacity: { rooms: 20, configuredDaily: 15, current: 11, demand: 13, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Episode / delivery',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 8,500',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 301',
      dataset: 'Reproductive & Maternal Health',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 301', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'OBG-EP', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Laboratory', 'Blood Bank', 'Radiology', 'Neonatal'],
    equipment: [],
    integrations: ['HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 11, unit: 'deliveries / episodes' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-neo',
    code: 'NEO',
    name: 'Neonatal',
    description: 'Newborn and neonatal care.',
    category: 'CLINICAL',
    serviceType: 'Neonatal care',
    location: {
      label: 'Neonatal Unit',
      building: 'Maternity Block',
      floor: '1',
      zone: 'NEONATAL',
      rooms: 'NBU 01–12',
      queue: 'NEO-REFERRALS',
    },
    department: { code: 'NEONATOLOGY', name: 'Neonatology' },
    units: { offering: 'Bed-day / episode', billingUnit: 'Bed-day', reportingUnit: 'Neonatal episode' },
    workforce: {
      requiredCapacity: 12,
      currentlyAssigned: 12,
      onDuty: 8,
      coveragePercent: 89,
      roles: [
        { role: 'Paediatrician', required: 2 },
        { role: 'Neonatal Nurse', required: 8 },
        { role: 'Nursing Aide', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Admission → Monitoring → Feeding / Treatment → Discharge',
      nodes: [
        node('Admission', 'Neonatal Nurse', ['Referral', 'Gestation', 'Birth weight'], ['Neonatal care plan']),
        node('Monitoring', 'Neonatal Nurse', ['Vitals', 'Feeding', 'SpO₂'], ['Monitor record', 'Escalation']),
        node('Feeding / Treatment', 'Paediatrician', ['Monitor record', 'Results'], ['Feeding plan', 'Therapy']),
        node('Discharge', 'Paediatrician', ['Stability', 'Follow-up'], ['Discharge summary', 'Follow-up plan']),
      ],
    },
    capacity: { rooms: 12, configuredDaily: 12, current: 9, demand: 11, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Bed-day',
      payerRules: ['SHA', 'Private'],
      baseTariff: 'KES 9,500',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 203',
      dataset: 'Neonatal Care',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 203', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'NEO-BD', status: 'valid' },
    ],
    integrationMapping: false,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Laboratory', 'Radiology', 'Maternity'],
    equipment: [],
    integrations: [],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 9, unit: 'occupied neonatal bed-days' },
    attention: 'Missing external integration mapping',
    requiresReview: false,
  },

  {
    id: 'svc-pae',
    code: 'PAE',
    name: 'Paediatrics',
    description: 'Child health — ambulatory and ward care.',
    category: 'CLINICAL',
    serviceType: 'Paediatric care',
    location: {
      label: "Children's Ward",
      building: 'Main Hospital',
      floor: '1',
      zone: 'PAEDIATRIC',
      rooms: 'PC 01–18',
      queue: 'PAE-GENERAL',
    },
    department: { code: 'PAEDIATRICS', name: 'Paediatric Services' },
    units: { offering: 'Encounter / bed-day depending on configured service', billingUnit: 'Encounter / bed-day', reportingUnit: 'Child visit / inpatient day' },
    workforce: {
      requiredCapacity: 16,
      currentlyAssigned: 17,
      onDuty: 11,
      coveragePercent: 90,
      roles: [
        { role: 'Paediatrician', required: 3 },
        { role: 'Clinical Officer', required: 3 },
        { role: 'Nurse', required: 8 },
        { role: 'Registration', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Triage → Assessment → Treatment → Review → Disposition',
      nodes: [
        node('Triage', 'Nurse', ['Vitals', 'Chief complaint'], ['Triage category']),
        node('Assessment', 'Clinician', ['History', 'Examination'], ['Assessment', 'Orders']),
        node('Treatment', 'Clinician', ['Orders', 'Plan'], ['Therapy', 'Dispensing queue']),
        node('Review', 'Clinician', ['Results', 'Response'], ['Updated plan']),
        node('Disposition', 'Clinician', ['Assessment', 'Response'], ['Admission / Discharge / Follow-up']),
      ],
    },
    capacity: { rooms: 18, configuredDaily: 60, current: 48, demand: 55, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Encounter / bed-day',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 650',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 101',
      dataset: 'Child Health Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 101 (child)', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'PAE-ENC', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Pharmacy', 'Laboratory', 'Radiology'],
    equipment: [],
    integrations: ['HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 48, unit: 'encounters' },
    attention: null,
    requiresReview: false,
  },

  // ===========================================================================
  // DIAGNOSTICS (4)
  // ===========================================================================
  {
    id: 'svc-lab',
    code: 'LAB',
    name: 'Laboratory',
    description: 'Clinical laboratory investigations.',
    category: 'DIAGNOSTICS',
    serviceType: 'Diagnostic service',
    location: {
      label: 'Laboratory Wing',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'LAB',
      rooms: 'LAB 01–06',
      queue: 'LAB-COLLECTION',
    },
    department: { code: 'LAB', name: 'Laboratory' },
    units: { offering: 'Test / request', billingUnit: 'Test item', reportingUnit: 'Investigation' },
    workforce: {
      requiredCapacity: 15,
      currentlyAssigned: 16,
      onDuty: 10,
      coveragePercent: 93,
      roles: [
        { role: 'Lab Technologist', required: 10 },
        { role: 'Lab Technician', required: 4 },
        { role: 'Pathologist', required: 1 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Sample collection → Processing → Verification → Reporting → Critical-result alert',
      nodes: [
        node('Sample collection', 'Phlebotomist', ['Request', 'Patient identity'], ['Labelled specimen']),
        node('Processing', 'Lab Technologist', ['Specimen', 'Test order'], ['Analysed result']),
        node('Verification', 'Pathologist / Senior Tech', ['Analysed result', 'Quality data'], ['Verified result']),
        node('Reporting', 'Lab Technologist', ['Verified result'], ['Result record', 'Clinician notification']),
        node('Critical-result alert', 'Lab Technologist', ['Critical threshold'], ['Critical alert', 'Escalation']),
      ],
    },
    capacity: { rooms: 6, configuredDaily: 450, current: 402, demand: 415, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Test item',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'Per test',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 401',
      dataset: 'Laboratory Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 401', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'LAB-TEST', status: 'valid' },
      { kind: 'External', standard: 'LIS', representation: 'Test catalogue sync', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Pharmacy'],
    equipment: [],
    integrations: ['LIS', 'HMIS'],
    items: [
      { code: 'CBC', name: 'Full blood count' },
      { code: 'UEC', name: 'Urea / electrolytes' },
      { code: 'MPS', name: 'Malaria parasite smear' },
      { code: 'CS', name: 'Culture & sensitivity' },
      { code: 'LFT', name: 'Liver function test' },
    ],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 402, unit: 'tests' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-rad',
    code: 'RAD',
    name: 'Radiology',
    description: 'Diagnostic imaging across all modalities.',
    category: 'DIAGNOSTICS',
    serviceType: 'Diagnostic service',
    location: {
      label: 'Radiology Suite',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'RADIOLOGY',
      rooms: 'RX 01–04',
      queue: 'RAD-REQUESTS',
    },
    department: { code: 'RADIOLOGY', name: 'Radiology' },
    units: { offering: 'Study', billingUnit: 'Modality study', reportingUnit: 'Imaging study' },
    workforce: {
      requiredCapacity: 8,
      currentlyAssigned: 8,
      onDuty: 5,
      coveragePercent: 87,
      roles: [
        { role: 'Radiographer', required: 4 },
        { role: 'Radiologist', required: 2 },
        { role: 'Radiology Nurse', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Request → Screening → Scheduling → Acquisition → Interpretation → Report → Archive',
      nodes: [
        node('Request', 'Clinician', ['Clinical question'], ['Imaging request']),
        node('Screening', 'Radiologist', ['Request', 'Safety screening'], ['Feasibility', 'Protocol']),
        node('Scheduling', 'Radiology Clerk', ['Feasibility', 'Priority'], ['Slot', 'Queue entry']),
        node('Acquisition', 'Radiographer', ['Protocol', 'Patient'], ['Images']),
        node('Interpretation', 'Radiologist', ['Images', 'Clinical question'], ['Preliminary report']),
        node('Report', 'Radiologist', ['Preliminary report'], ['Final report', 'Archive']),
      ],
    },
    capacity: { rooms: 4, configuredDaily: 90, current: 76, demand: 82, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Modality study',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'Per study',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 402',
      dataset: 'Radiology Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 402', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'RAD-STUDY', status: 'valid' },
      { kind: 'External', standard: 'FHIR R4', representation: 'ImagingStudy', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Radiologist', 'Radiographer', 'RIS/PACS'],
    equipment: [],
    integrations: ['RIS/PACS', 'HMIS', 'FHIR gateway'],
    items: [
      { code: 'X-RAY', name: 'X-ray' },
      { code: 'US', name: 'Ultrasound' },
      { code: 'CT', name: 'CT' },
    ],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 76, unit: 'studies' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-us',
    code: 'US',
    name: 'Ultrasound',
    description: 'Ultrasonography for obstetric, abdominal and vascular assessment.',
    category: 'DIAGNOSTICS',
    serviceType: 'Diagnostic service',
    location: {
      label: 'Ultrasound Rooms',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'RADIOLOGY',
      rooms: 'US 01–02',
      queue: 'US-BOOKING',
    },
    department: { code: 'RADIOLOGY', name: 'Radiology' },
    units: { offering: 'Study', billingUnit: 'Modality study', reportingUnit: 'Imaging study' },
    workforce: {
      requiredCapacity: 4,
      currentlyAssigned: 4,
      onDuty: 3,
      coveragePercent: 95,
      roles: [
        { role: 'Radiographer', required: 2 },
        { role: 'Radiologist', required: 1 },
        { role: 'Sonographer', required: 1 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Request → Scheduling → Scan → Report',
      nodes: [
        node('Request', 'Clinician', ['Clinical question'], ['Ultrasound request']),
        node('Scheduling', 'Radiology Clerk', ['Request', 'Priority'], ['Slot']),
        node('Scan', 'Sonographer / Radiographer', ['Protocol', 'Patient'], ['Images']),
        node('Report', 'Radiologist', ['Images', 'Clinical question'], ['Report']),
      ],
    },
    capacity: { rooms: 2, configuredDaily: 24, current: 19, demand: 21, pressure: 'LOW' },
    pricing: {
      status: 'configured',
      unit: 'Modality study',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 2,400',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 402',
      dataset: 'Radiology Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 402 (US)', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'RAD-US', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Radiologist', 'Radiographer', 'RIS/PACS'],
    equipment: [],
    integrations: ['RIS/PACS', 'HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 19, unit: 'studies' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-ct',
    code: 'CT',
    name: 'CT Imaging',
    description: 'Computed tomography diagnostic imaging.',
    category: 'DIAGNOSTICS',
    serviceType: 'Diagnostic service',
    location: {
      label: 'CT Suite',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'RADIOLOGY',
      rooms: 'CT 01',
      queue: 'CT-BOOKING',
    },
    department: { code: 'RADIOLOGY', name: 'Radiology' },
    units: { offering: 'Study', billingUnit: 'Modality study', reportingUnit: 'Imaging study' },
    workforce: {
      requiredCapacity: 3,
      currentlyAssigned: 3,
      onDuty: 2,
      coveragePercent: 80,
      roles: [
        { role: 'Radiographer', required: 2 },
        { role: 'Radiologist coverage', required: 1 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Request → Screening → Scheduling → Scan → Interpretation → Report → Archive',
      nodes: [
        node('Request', 'Clinician', ['Clinical question', 'Renal function'], ['CT request']),
        node('Screening', 'Radiologist', ['Request', 'Contrast safety', 'Weight'], ['Feasibility', 'Protocol']),
        node('Scheduling', 'Radiology Clerk', ['Feasibility', 'Priority'], ['Slot']),
        node('Scan', 'Radiographer', ['Protocol', 'Patient', 'Contrast'], ['Images']),
        node('Interpretation', 'Radiologist', ['Images', 'Clinical question'], ['Preliminary report']),
        node('Report', 'Radiologist', ['Preliminary report'], ['Final report', 'Archive']),
        node('Archive', 'RIS/PACS', ['Final report', 'Images'], ['DICOM archive', 'Retrieval']),
      ],
    },
    capacity: { rooms: 1, configuredDaily: 18, current: 14, demand: 17, pressure: 'MEDIUM' },
    pricing: {
      status: 'configured',
      unit: 'Modality study',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 12,000',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 402',
      dataset: 'Radiology Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 402 (CT)', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'RAD-CT', status: 'valid' },
      { kind: 'External', standard: 'FHIR R4', representation: 'ImagingStudy (CT)', status: 'valid' },
    ],
    integrationMapping: true,
    status: {
      state: 'limited',
      reason: 'CT maintenance',
      expectedRecovery: '16:00',
    },
    dependencies: ['Radiology', 'Radiologist', 'Radiographer', 'RIS/PACS'],
    equipment: [
      { name: 'CT Scanner #01', status: 'Operational', utilization: 76, maintenanceNextDue: '2026-08-28' },
    ],
    integrations: ['RIS/PACS', 'DICOM', 'HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 14, unit: 'studies' },
    attention: 'Maintenance dependency detected',
    requiresReview: true,
  },

  // ===========================================================================
  // SUPPORT / ALLIED (4)
  // ===========================================================================
  {
    id: 'svc-pha',
    code: 'PHA',
    name: 'Pharmacy',
    description: 'Medication dispensing and clinical pharmacy.',
    category: 'SUPPORT',
    serviceType: 'Allied / clinical support',
    location: {
      label: 'Pharmacy',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'PHARMACY',
      rooms: 'PH 01–03',
      queue: 'PHX-DISPENSE',
    },
    department: { code: 'PHARMACY', name: 'Pharmacy' },
    units: { offering: 'Prescription / dispense', billingUnit: 'Line item', reportingUnit: 'Dispensing event' },
    workforce: {
      requiredCapacity: 10,
      currentlyAssigned: 11,
      onDuty: 7,
      coveragePercent: 92,
      roles: [
        { role: 'Pharmacist', required: 4 },
        { role: 'Pharmacy Technician', required: 4 },
        { role: 'Pharmacy Assistant', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Order → Clinical check → Dispense → Counseling',
      nodes: [
        node('Order', 'Pharmacist', ['Prescription'], ['Pharmacy order']),
        node('Clinical check', 'Pharmacist', ['Prescription', 'Patient record', 'Stock'], ['Verified order']),
        node('Dispense', 'Pharmacy Technician', ['Verified order'], ['Dispensed items', 'Label']),
        node('Counseling', 'Pharmacist', ['Dispensed items', 'Patient'], ['Counseling record']),
      ],
    },
    capacity: { rooms: 3, configuredDaily: 320, current: 286, demand: 292, pressure: 'LOW' },
    pricing: {
      status: 'configured',
      unit: 'Line item',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'Per item',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 501',
      dataset: 'Pharmaceutical Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 501', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'PHX-ITEM', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: [],
    equipment: [],
    integrations: ['HMIS', 'Stock / supply'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 286, unit: 'dispensing events' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-blb',
    code: 'BLB',
    name: 'Blood Bank',
    description: 'Blood donation, storage, cross-match and transfusion.',
    category: 'SUPPORT',
    serviceType: 'Specialized laboratory / transfusion capability',
    location: {
      label: 'Blood Bank',
      building: 'Main Hospital',
      floor: 'Ground',
      zone: 'BLOOD BANK',
      rooms: 'BB 01–02',
      queue: 'BB-REQUESTS',
    },
    department: { code: 'LAB', name: 'Laboratory' },
    units: { offering: 'Unit / transfusion', billingUnit: 'Unit', reportingUnit: 'Transfusion event' },
    workforce: {
      requiredCapacity: 6,
      currentlyAssigned: 6,
      onDuty: 4,
      coveragePercent: 90,
      roles: [
        { role: 'Lab Technologist', required: 4 },
        { role: 'Transfusion Officer', required: 1 },
        { role: 'Pathologist', required: 1 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Request → Compatibility → Cross-match → Issue → Trace',
      nodes: [
        node('Request', 'Clinician', ['Transfusion request', 'Group'], ['Blood request']),
        node('Compatibility', 'Lab Technologist', ['Patient group', 'Stock'], ['Compatibility result']),
        node('Cross-match', 'Lab Technologist', ['Compatibility result', 'Unit'], ['Cross-matched unit']),
        node('Issue', 'Transfusion Officer', ['Cross-matched unit', 'Patient identity'], ['Issued unit', 'Trace record']),
      ],
    },
    capacity: { rooms: 2, configuredDaily: 20, current: 14, demand: 16, pressure: 'LOW' },
    pricing: {
      status: 'configured',
      unit: 'Unit',
      payerRules: ['SHA', 'Private'],
      baseTariff: 'KES 3,200',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 601',
      dataset: 'Transfusion Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 601', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'BB-UNIT', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: ['Laboratory'],
    equipment: [],
    integrations: ['HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 14, unit: 'units issued' },
    attention: null,
    requiresReview: false,
  },

  {
    id: 'svc-nut',
    code: 'NUT',
    name: 'Nutrition',
    description: 'Clinical nutrition assessment and dietary care.',
    category: 'SUPPORT',
    serviceType: 'Allied clinical care',
    location: {
      label: 'Nutrition Department',
      building: 'Main Hospital',
      floor: '1',
      zone: 'NUTRITION',
      rooms: 'ND 01–02',
      queue: 'NUT-REFERRALS',
    },
    department: { code: 'NUTRITION', name: 'Nutrition & Dietetics' },
    units: { offering: 'Assessment / session', billingUnit: 'Session', reportingUnit: 'Nutrition episode' },
    workforce: {
      requiredCapacity: 5,
      currentlyAssigned: 5,
      onDuty: 3,
      coveragePercent: 88,
      roles: [
        { role: 'Dietitian', required: 3 },
        { role: 'Nutrition Officer', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Referral → Assessment → Plan → Review',
      nodes: [
        node('Referral', 'Clinician', ['Referral', 'Clinical need'], ['Nutrition referral']),
        node('Assessment', 'Dietitian', ['Referral', 'Nutrition screen'], ['Nutrition assessment']),
        node('Plan', 'Dietitian', ['Assessment', 'Dietary goals'], ['Nutrition care plan']),
        node('Review', 'Dietitian', ['Progress', 'Plan'], ['Updated plan', 'Discharge']),
      ],
    },
    capacity: { rooms: 2, configuredDaily: 40, current: 31, demand: 33, pressure: 'LOW' },
    pricing: {
      status: 'missing',
      unit: 'Session',
      payerRules: ['SHA'],
      baseTariff: 'Not configured',
      currency: 'KES',
      effective: null,
      versions: [],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 701',
      dataset: 'Nutrition Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 701', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'NUT-SESSION', status: 'review' },
    ],
    integrationMapping: false,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: [],
    equipment: [],
    integrations: [],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 31, unit: 'sessions' },
    attention: 'Missing external integration mapping',
    requiresReview: false,
  },

  {
    id: 'svc-pht',
    code: 'PHT',
    name: 'Physiotherapy',
    description: 'Rehabilitation and physical therapy.',
    category: 'SUPPORT',
    serviceType: 'Allied clinical care',
    location: {
      label: 'Physiotherapy',
      building: 'Main Hospital',
      floor: '1',
      zone: 'THERAPY',
      rooms: 'PT 01–04',
      queue: 'PHT-REFERRALS',
    },
    department: { code: 'PHYSIOTHERAPY', name: 'Physiotherapy' },
    units: { offering: 'Session', billingUnit: 'Session', reportingUnit: 'Physiotherapy episode' },
    workforce: {
      requiredCapacity: 6,
      currentlyAssigned: 7,
      onDuty: 4,
      coveragePercent: 91,
      roles: [
        { role: 'Physiotherapist', required: 4 },
        { role: 'Physio Assistant', required: 2 },
      ],
    },
    workflow: {
      configured: true,
      summary: 'Referral → Assessment → Treatment → Review → Discharge',
      nodes: [
        node('Referral', 'Clinician', ['Referral', 'Functional need'], ['Physio referral']),
        node('Assessment', 'Physiotherapist', ['Referral', 'Functional assessment'], ['Assessment', 'Goals']),
        node('Treatment', 'Physiotherapist', ['Assessment', 'Plan'], ['Treatment record']),
        node('Review', 'Physiotherapist', ['Progress', 'Goals'], ['Updated plan']),
        node('Discharge', 'Physiotherapist', ['Goals met', 'Home plan'], ['Discharge summary']),
      ],
    },
    capacity: { rooms: 4, configuredDaily: 32, current: 24, demand: 26, pressure: 'LOW' },
    pricing: {
      status: 'configured',
      unit: 'Session',
      payerRules: ['SHA', 'Private', 'Cash'],
      baseTariff: 'KES 1,500',
      currency: 'KES',
      effective: '2026-07-01',
      versions: [
        { label: '2026 tariff', active: true, effective: '2026-07-01' },
        { label: '2025 tariff', active: false, effective: '2025-07-01' },
      ],
    },
    reporting: {
      status: 'valid',
      classification: 'HMIS 701',
      dataset: 'Rehabilitation Services',
      mappingStatus: 'Valid',
      lastValidated: '2026-08-20',
    },
    mappings: [
      { kind: 'National reporting', standard: 'Kenya HMIS', representation: 'HMIS 701 (rehab)', status: 'valid' },
      { kind: 'Payer', standard: 'SHA tariff', representation: 'PHT-SESSION', status: 'valid' },
    ],
    integrationMapping: true,
    status: { state: 'operational', reason: null, expectedRecovery: null },
    dependencies: [],
    equipment: [],
    integrations: ['HMIS'],
    items: [],
    governance: DEFAULT_GOVERNANCE,
    activity: { today: 24, unit: 'sessions' },
    attention: null,
    requiresReview: false,
  },
];

// =============================================================================
// PROJECTION BUILDERS
// =============================================================================

function buildHealth(services: CatalogueService[]): CatalogueHealth {
  const active = services.length;
  const clinical = services.filter((s) => s.category === 'CLINICAL').length;
  const diagnostics = services.filter((s) => s.category === 'DIAGNOSTICS').length;
  const support = services.filter((s) => s.category === 'SUPPORT').length;

  const configuredWorkflows = services.filter((s) => s.workflow.configured).length;
  const reportingMappings = services.filter((s) => s.reporting.status === 'valid').length;
  const pricingConfigurations = services.filter((s) => s.pricing.status === 'configured').length;
  const integrationMappings = services.filter((s) => s.integrationMapping).length;
  const requiresReview = services.filter((s) => s.requiresReview).length;

  // Weighted catalogue completeness: definitions, workflow, pricing, reporting
  // and integration each carry one point per service.
  const achieved =
    active +
    configuredWorkflows +
    pricingConfigurations +
    reportingMappings +
    integrationMappings;

  const possible = active * 5;

  const catalogueStatusPercent =
    possible === 0 ? 0 : Math.round((achieved / possible) * 100);

  return {
    activeServices: active,
    clinical,
    diagnostics,
    support,
    configuredWorkflows,
    reportingMappings,
    pricingConfigurations,
    requiresReview,
    catalogueStatusPercent,
    integrity: {
      serviceDefinitions: { complete: active, total: active },
      workflowConfigured: { complete: configuredWorkflows, total: active },
      pricingConfigured: { complete: pricingConfigurations, total: active },
      reportingMapping: { complete: reportingMappings, total: active },
      integrationMappings: { complete: integrationMappings, total: active },
    },
  };
}

function buildAttention(services: CatalogueService[]): CatalogueAttentionItem[] {
  const attention: CatalogueAttentionItem[] = [];

  for (const service of services) {
    if (service.attention) {
      attention.push({
        code: service.code,
        name: service.name,
        issue: service.attention,
        severity: service.requiresReview ? 'bad' : 'warn',
      });
    }
  }

  return attention;
}

function buildCategories(services: CatalogueService[]): CatalogueCategoryGroup[] {
  const order: CatalogueCategory[] = ['CLINICAL', 'DIAGNOSTICS', 'SUPPORT'];

  return order.map((code) => ({
    code,
    label:
      code === 'CLINICAL'
        ? 'Clinical'
        : code === 'DIAGNOSTICS'
          ? 'Diagnostics'
          : 'Support / Allied',
    count: services.filter((s) => s.category === code).length,
  }));
}

export function serviceCatalogueOverview(): CatalogueOverview {
  return {
    generatedAt: new Date().toISOString(),
    facility: { name: 'Kenyatta Teaching & Referral Hospital', code: 'KTRH', scope: 'facility' },
    environment: 'demo',
    health: buildHealth(SERVICES),
    categories: buildCategories(SERVICES),
    services: SERVICES,
    attention: buildAttention(SERVICES),
  };
}

export function serviceCatalogueDetail(
  code: string,
): CatalogueService | null {
  const normalized = code.trim().toUpperCase();
  return SERVICES.find((service) => service.code === normalized) ?? null;
}

export const catalogueServiceCount = SERVICES.length;