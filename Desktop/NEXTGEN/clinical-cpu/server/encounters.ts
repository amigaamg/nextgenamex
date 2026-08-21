// =============================================================================
// AMEXAN Clinical Runtime API — encounter persistence helpers
// Creates a real patient + encounter in PostgreSQL (identity/patient/encounter)
// so that every captured fact survives across sessions, and lists past
// encounters for the "Records of Histories Done" screen.
// =============================================================================

import { randomUUID } from 'node:crypto';
import type { Db, Row } from '../src/db.js';
import {
  JourneyEventType,
  recordJourneyEvent,
} from '../src/observability/EventCore.js';

const PATIENT_FACT_SOURCE = 'patient';

export interface StartEncounterBody {
  patientId?: string;
  encounterId?: string | null;

  name?: string | null;
  occupation?: string | null;

  birthDate?: string | null;

  ageYears?: number | null;
  ageMonths?: number | null;
  ageDays?: number | null;

  sex?: string;
  pregnancyState?: string;
  pregnant?: boolean;
  gestationalAge?: string | null;
  gestationalAgeWeeks?: number | null;

  department?: string;
  encounterType?: string;
  encounterTypeCode?: string;

  presentingComplaintCodes?: string[];
  activeSymptomCodes?: string[];

  presentingComplaintText?: string | null;

  firstVisit?: boolean;
  emergency?: boolean;
}

export interface CreatedEncounter {
  personId: string;
  patientId: string;
  encounterId: string;
  facts: EncounterFactRow[];
}

export interface EncounterFactRow {
  id: string;
  factCode: string;
  section: string;
  statusCode: string;
  sourceType: string;
  recordedAt: string;
  dataType: string;
  text: string | null;
  numeric: number | null;
  boolean: boolean | null;
  unitCode: string | null;
}

const ENCOUNTER_TYPE_MAP: Record<string, string> = {
  opd: 'opd',
  ipd: 'ipd',
  inpatient: 'ipd',
  emergency: 'emergency',
  review: 'follow_up',
  follow_up: 'follow_up',
  antenatal: 'opd',
  postnatal: 'opd',
  neonatal: 'opd',
  procedure: 'procedure',
  telemedicine: 'telemedicine',
  home_visit: 'home_visit',
  community_visit: 'community_visit',
  special_clinic: 'special_clinic',
  discharge: 'discharge',
};

const VALID_ENCOUNTER_TYPES = new Set([
  'opd',
  'ipd',
  'emergency',
  'follow_up',
  'procedure',
  'telemedicine',
  'home_visit',
  'community_visit',
  'special_clinic',
  'discharge',
]);

function mapEncounterType(code: string | undefined | null): string {
  const normalized = (code ?? '').toLowerCase();
  const mapped = ENCOUNTER_TYPE_MAP[normalized];
  return mapped && VALID_ENCOUNTER_TYPES.has(mapped) ? mapped : 'opd';
}

function mapGender(sex: string | undefined): string {
  switch (sex?.toLowerCase()) {
    case 'male':
      return 'male';
    case 'female':
      return 'female';
    case 'intersex':
      return 'other';
    default:
      return 'unknown';
  }
}

// Derive a date of birth from a declared age (years / months / days). When only
// part of the age is known the remaining components default to zero.
function deriveBirthDateFromAge(body: StartEncounterBody): string | null {
  const years = body.ageYears ?? 0;
  const months = body.ageMonths ?? 0;
  const days = body.ageDays ?? 0;
  if (years <= 0 && months <= 0 && days <= 0) return null;
  const now = new Date();
  const birth = new Date(
    now.getFullYear() - years,
    now.getMonth() - months,
    now.getDate() - days,
  );
  return toYmd(birth);
}

function toYmd(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return value as string;
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

interface EncounterRow extends Row {
  id: string;
}

export async function createPersistentEncounter(
  db: Db,
  body: StartEncounterBody,
): Promise<CreatedEncounter> {
  const personId = randomUUID();
  // Honor a client-supplied patientId (client-orchestrated identity); otherwise
  // mint a fresh one. The server must never silently discard the identity the
  // caller is tracking — facts captured later key off this exact id.
  const patientId = body.patientId || randomUUID();

  const gender = mapGender(body.sex);
  // Prefer an explicit DOB; otherwise derive a date of birth from the declared
  // age so the CPU always has the exact age in days (INVARIANT-001).
  const birthDate = body.birthDate || deriveBirthDateFromAge(body);

  await db.query('BEGIN');
  try {
    // Simple sequential patient number (Patient No 00001, 00002, ...).
    const nextNo = await db.queryOne<{ nextval: string }>(
      `SELECT nextval('patient.patient_no_seq')::text AS nextval`,
      [],
    );
  const mrn = `Patient No ${String(nextNo?.nextval ?? 0).padStart(5, '0')}`;

  await db.query(
    `INSERT INTO identity.person (id, status_code, sex_at_birth, birth_date, nationality_code, occupation, preferred_name)
     VALUES ($1, 'active', $2, $3, $4, $5, $6)`,
    [personId, gender, birthDate, 'KE', body.occupation ?? null, body.name ?? null],
  );

  await db.query(
    `INSERT INTO patient.patient (id, person_id, status_code)
     VALUES ($1, $2, 'active')`,
    [patientId, personId],
  );

  const encounterRow = await db.queryOne<EncounterRow>(
    `INSERT INTO encounter.encounter
        (patient_id, encounter_type_code, status_code, phase_code, started_at)
     VALUES ($1, $2, 'active', 'assessment', now())
     RETURNING id`,
    [patientId, mapEncounterType(body.encounterTypeCode ?? body.encounterType)],
  );
  const encounterId = encounterRow!.id;

  // Bind the encounter to a department/service when one exists in the registry.
  if (body.department) {
    const svc = await db.queryOne<{ id: string }>(
      `SELECT id FROM organization.service WHERE code = $1 AND is_active`,
      [body.department],
    );
    if (svc) {
      await db.query(
        `INSERT INTO encounter.encounter_service (id, encounter_id, service_id, is_primary)
         VALUES ($1, $2, $3, true)`,
        [randomUUID(), encounterId, svc.id],
      );
    }
  }

  // Record the presenting complaint as the primary reason for the encounter.
  const complaintText =
    body.presentingComplaintText?.trim() ||
    (body.presentingComplaintCodes ?? []).join(', ') ||
    null;
  if (complaintText) {
    await db.query(
      `INSERT INTO encounter.encounter_reason (id, encounter_id, reason, is_primary)
       VALUES ($1, $2, $3, true)`,
      [randomUUID(), encounterId, complaintText],
    );
  }

  const facts: EncounterFactRow[] = [];

  // Patient number (biodata) — lets the UI and docs render the MRN.
  facts.push(
    await captureFact(db, {
      patientId,
      encounterId,
      factCode: 'MRN',
      section: 'biodata',
      dataType: 'text',
      text: mrn,
    }),
  );

  // Presenting complaint (chief complaint).
  if (complaintText) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'PRESENTING_COMPLAINT',
        section: 'chief_complaint',
        dataType: 'text',
        text: complaintText,
      }),
    );
  }

  // Sex + age (biodata).
  const sexCode = (body.sex ?? '').toUpperCase();
  if (sexCode) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'SEX',
        section: 'biodata',
        dataType: 'coded',
        text: sexCode,
      }),
    );
  }

  if (body.name?.trim()) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'PATIENT_NAME',
        section: 'biodata',
        dataType: 'text',
        text: body.name.trim(),
      }),
    );
  }

  if (birthDate) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'DATE_OF_BIRTH',
        section: 'biodata',
        dataType: 'date',
        text: toYmd(birthDate),
      }),
    );
  }

  const ageYears = body.ageYears ?? 0;
  if (ageYears > 0) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'AGE_YEARS',
        section: 'biodata',
        dataType: 'numeric',
        numeric: ageYears,
      }),
    );
  }

  if (body.ageMonths != null && body.ageMonths >= 0) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'AGE_MONTHS',
        section: 'biodata',
        dataType: 'numeric',
        numeric: body.ageMonths,
      }),
    );
  }

  if (body.ageDays != null && body.ageDays >= 0) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'AGE_DAYS',
        section: 'biodata',
        dataType: 'numeric',
        numeric: body.ageDays,
      }),
    );
  }

  if (body.occupation?.trim()) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'OCCUPATION',
        section: 'biodata',
        dataType: 'text',
        text: body.occupation.trim(),
      }),
    );
  }

  // Pregnancy status. The CPU's ContextResolver resolves pregnancy from the
  // PREGNANT boolean fact (INVARIANT-002) — never inferred from sex alone.
  const pregnant = body.pregnant === true || body.pregnancyState === 'pregnant';
  if (pregnant) {
    facts.push(
      await captureFact(db, {
        patientId,
        encounterId,
        factCode: 'PREGNANT',
        section: 'anc_profile',
        dataType: 'boolean',
        boolean: true,
      }),
    );
    const ga = body.gestationalAgeWeeks ?? (body.gestationalAge != null ? Number(body.gestationalAge) : null);
    if (ga != null && !Number.isNaN(ga)) {
      facts.push(
        await captureFact(db, {
          patientId,
          encounterId,
          factCode: 'GESTATIONAL_AGE_WEEKS',
          section: 'anc_profile',
          dataType: 'numeric',
          numeric: ga,
        }),
      );
    }
  }

    await db.query('COMMIT');
    return { personId, patientId, encounterId, facts };
  } catch (e) {
    await db.query('ROLLBACK');
    throw e;
  }
}

interface CaptureFactInput {
  patientId: string;
  encounterId: string;
  factCode: string;
  section: string;
  dataType: string;
  text?: string | null;
  numeric?: number | null;
  boolean?: boolean | null;
  unitCode?: string | null;
}

async function captureFact(
  db: Db,
  input: CaptureFactInput,
): Promise<EncounterFactRow> {
  const factId = randomUUID();
  const recordedAt = new Date().toISOString();

  // The fact_value table enforces a strict data_type ↔ value-column contract
  // (chk_fact_value_type). A 'coded' value requires value_concept_id (a concept
  // UUID we do not resolve here), and a 'date' value requires value_date.
  // Since the server only persists free-text codes / ISO dates at this layer,
  // we normalise those onto value_text so the write always satisfies the check.
  const dataType =
    input.dataType === 'coded' || input.dataType === 'date'
      ? 'text'
      : input.dataType;

  await db.query(
    `INSERT INTO clinical.fact
        (id, patient_id, encounter_id, fact_definition_code, status_code, recorded_at, observed_at)
     VALUES ($1, $2, $3, $4, 'active', now(), now())`,
    [factId, input.patientId, input.encounterId, input.factCode],
  );

  await db.query(
    `INSERT INTO clinical.fact_value
        (id, fact_id, value_order, data_type, value_text, value_numeric, value_boolean, unit_code)
     VALUES ($1, $2, 0, $3, $4, $5, $6, $7)`,
    [
      randomUUID(),
      factId,
      dataType,
      input.text ?? null,
      input.numeric ?? null,
      input.boolean ?? null,
      input.unitCode ?? null,
    ],
  );

  await db.query(
    `INSERT INTO clinical.fact_source (id, fact_id, source_type) VALUES ($1, $2, $3)`,
    [randomUUID(), factId, PATIENT_FACT_SOURCE],
  );

  await db.query(
    `INSERT INTO clinical.fact_context (fact_id, context_key, context_value) VALUES ($1, 'section', $2)`,
    [factId, input.section],
  );

  return {
    id: factId,
    factCode: input.factCode,
    section: input.section,
    statusCode: 'active',
    sourceType: PATIENT_FACT_SOURCE,
    recordedAt,
    dataType,
    text: input.text ?? null,
    numeric: input.numeric ?? null,
    boolean: input.boolean ?? null,
    unitCode: input.unitCode ?? null,
  };
}

interface EncounterListRow extends Row {
  encounter_id: string;
  patient_id: string;
  encounter_type_code: string;
  status_code: string;
  started_at: Date | null;
  gender: string | null;
  birth_date: Date | null;
  preferred_name: string | null;
  presenting_complaint: string | null;
  has_substantive: boolean;
}

export interface EncounterSummaryRow {
  encounterId: string;
  patientId: string;
  patientName: string;
  age: number | null;
  sex: string;
  department: string;
  encounterType?: string | null;
  presentingComplaint: string;
  startedAt: string;
  status: 'draft' | 'in_progress' | 'completed' | 'cancelled';
  hasSubstantive: boolean;
}

// An encounter appears in the history list only when it is substantial and was
// saved during history taking: it must carry a recorded presenting complaint
// AND captured patient identity (name, sex or age — from the biodata section or
// identity.person). A quick-create shell (MRN + presenting complaint, nothing
// else) or an encounter with only a stray fact is not a clinical history yet.

const DEPARTMENT_BY_TYPE: Record<string, string> = {
  opd: 'Outpatient',
  ipd: 'Inpatient',
  emergency: 'Emergency',
  follow_up: 'Follow-up',
  procedure: 'Procedure',
  telemedicine: 'Telemedicine',
  home_visit: 'Home Visit',
  community_visit: 'Community',
  special_clinic: 'Special Clinic',
  discharge: 'Discharge',
};

function ageFromBirthDate(birthDate: Date | null): number | null {
  if (!birthDate) return null;
  const today = new Date();
  let years = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    years -= 1;
  }
  return Math.max(0, years);
}

export interface EncounterSnapshot {
  patientId: string;
  encounterId: string;
  context: {
    sex: string;
    birthDate: string | null;
    department: string | null;
    encounterTypeCode: string | null;
    presentingComplaint: string | null;
  };
  facts: EncounterFactRow[];
}

interface EncounterContextRow extends Row {
  patient_id: string;
  gender: string | null;
  birth_date: Date | null;
}

interface FactQueryRow extends Row {
  fact_id: string;
  fact_code: string;
  status_code: string;
  recorded_at: Date;
  section: string | null;
  source_type: string | null;
  value_order: number;
  data_type: string;
  value_text: string | null;
  value_numeric: string | null;
  value_boolean: boolean | null;
  unit_code: string | null;
}

export async function getEncounter(
  db: Db,
  encounterId: string,
): Promise<EncounterSnapshot | null> {
  const encounter = await db.queryOne<EncounterContextRow>(
    `SELECT
         e.patient_id AS patient_id,
         p.sex_at_birth AS gender,
         p.birth_date  AS birth_date
     FROM encounter.encounter e
     JOIN patient.patient pp ON pp.id = e.patient_id
     LEFT JOIN identity.person p ON p.id = pp.person_id
     WHERE e.id = $1`,
    [encounterId],
  );

  if (!encounter) return null;

  const [reasonRow, typeRow, factRows] = await Promise.all([
    db.queryOne<{ reason: string | null }>(
      `SELECT reason FROM encounter.encounter_reason WHERE encounter_id = $1 AND is_primary ORDER BY reason LIMIT 1`,
      [encounterId],
    ),
    db.queryOne<{ encounter_type_code: string }>(
      `SELECT encounter_type_code FROM encounter.encounter WHERE id = $1`,
      [encounterId],
    ),
     db.query<FactQueryRow>(
      `SELECT
          f.id           AS fact_id,
          f.fact_definition_code AS fact_code,
          f.status_code  AS status_code,
          f.recorded_at  AS recorded_at,
          (SELECT fc.context_value FROM clinical.fact_context fc
            WHERE fc.fact_id = f.id AND fc.context_key = 'section'
            LIMIT 1)     AS section,
          fs.source_type AS source_type,
          fv.value_order AS value_order,
          fv.data_type   AS data_type,
          fv.value_text  AS value_text,
          fv.value_numeric::text AS value_numeric,
          fv.value_boolean AS value_boolean,
          fv.unit_code   AS unit_code
       FROM clinical.fact f
       JOIN clinical.fact_value fv ON fv.fact_id = f.id
       LEFT JOIN clinical.fact_source fs ON fs.fact_id = f.id
       WHERE f.encounter_id = $1
       ORDER BY f.recorded_at ASC, fv.value_order ASC`,
      [encounterId],
    ),
  ]);

  const facts: EncounterFactRow[] = factRows.map((row) => {
    const numericValue =
      row.value_numeric != null ? Number(row.value_numeric) : null;

    return {
      id: row.fact_id as string,
      factCode: row.fact_code as string,
      section: row.section ?? 'hpi',
      statusCode: row.status_code as string,
      sourceType: row.source_type ?? 'patient',
      recordedAt: new Date(row.recorded_at).toISOString(),
      dataType: row.data_type,
      text: row.value_text,
      numeric: numericValue,
      boolean: row.value_boolean,
      unitCode: row.unit_code,
    };
  });

  return {
    patientId: encounter.patient_id as string,
    encounterId,
    context: {
      sex: encounter.gender || 'unknown',
      birthDate: encounter.birth_date
        ? toLocalDateString(encounter.birth_date)
        : null,
      department: null,
      encounterTypeCode: typeRow?.encounter_type_code ?? null,
      presentingComplaint: reasonRow?.reason ?? null,
    },
    facts,
  };
}

function toLocalDateString(value: Date): string {
  const year = value.getFullYear();
  const month = String(value.getMonth() + 1).padStart(2, '0');
  const day = String(value.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// =============================================================================
// Encounter completion + clinical document lifecycle
// Completing an encounter is an explicit clinician action that:
//   1. marks the encounter COMPLETED (immutable clinical record),
//   2. freezes a document snapshot as an immutable version, and
//   3. records a PDF export entry so the UI can always render/download vN.
// Later amendments create NEW versions; completed versions are never mutated.
// =============================================================================

export interface ClinicalDocument {
  documentId: string;
  encounterId: string;
  title: string;
  status: string;
  currentVersion: number;
  versions: {
    version: number;
    content: string | null;
    contentJson: unknown;
    createdAt: string;
  }[];
  exports: {
    exportType: string;
    format: string | null;
    status: string;
    exportedAt: string;
  }[];
}

const DOCUMENT_TYPE = 'clinical_history';

async function ensureDocumentType(db: Db): Promise<void> {
  const existing = await db.queryOne<{ code: string }>(
    `SELECT code FROM document.document_type WHERE code = $1`,
    [DOCUMENT_TYPE],
  );
  if (!existing) {
    await db.query(
      `INSERT INTO document.document_type (code, label, description)
       VALUES ($1, 'Clinical History', 'History and examination clinical record')`,
      [DOCUMENT_TYPE],
    );
  }
}

function buildDocumentHtml(
  snapshot: EncounterSnapshot,
  patientName: string,
  mrn: string,
  department: string,
  version: number,
  finalizedAt: string,
): string {
  const patientLabel =
    patientName || snapshot.patientId.slice(0, 8).toUpperCase();
  const body = snapshot.facts
    .map((fact) => {
      const value =
        fact.text ??
        (fact.numeric != null ? String(fact.numeric) : null) ??
        (fact.boolean != null ? (fact.boolean ? 'Yes' : 'No') : null) ??
        '';
      if (!value) return null;
      const sectionLabel =
        {
          biodata: 'Biodata',
          chief_complaint: 'Chief Complaint',
          hpi: 'History of Presenting Illness',
          pmh: 'Past Medical History',
          dh: 'Drug History',
          allergies: 'Allergies',
          fh: 'Family History',
          sh: 'Social History',
          examination: 'Examination',
          investigations: 'Investigations',
          assessment: 'Assessment',
          plan: 'Plan',
          obstetric_history: 'Obstetric History',
          vitals: 'Vital Signs',
        }[fact.section] ?? fact.section;
      return `<tr><td><strong>${escapeHtml(sectionLabel)}</strong></td><td>${escapeHtml(fact.factCode)}</td><td>${escapeHtml(value)}</td></tr>`;
    })
    .filter(Boolean)
    .join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${escapeHtml(patientLabel)} — Clinical Record</title>
<style>
  body { font-family: Georgia, serif; color: #111; margin: 40px; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .meta { color: #444; font-size: 12px; margin-bottom: 4px; }
  table { width: 100%; border-collapse: collapse; margin-top: 18px; }
  th, td { border: 1px solid #bbb; padding: 6px 8px; text-align: left; vertical-align: top; font-size: 13px; }
  th { background: #f0f0f0; }
  .footer { margin-top: 24px; border-top: 1px solid #ccc; padding-top: 8px; font-size: 11px; color: #555; }
</style>
</head>
<body>
  <h1>AMEXAN Clinical Record</h1>
  <div class="meta"><strong>${escapeHtml(patientLabel)}</strong> &middot; ${escapeHtml(mrn)} &middot; ${escapeHtml(snapshot.context.sex)}</div>
  <div class="meta">Encounter ${escapeHtml(snapshot.encounterId.slice(0, 8).toUpperCase())} &middot; ${escapeHtml(department)}</div>
  <div class="meta">Encounter date: ${escapeHtml(toLocalDateString(new Date()))}</div>
  <table>
    <thead><tr><th>Section</th><th>Item</th><th>Value</th></tr></thead>
    <tbody>${body}</tbody>
  </table>
  <div class="footer">AMEXAN Clinical Record &middot; Version ${version} &middot; Final &middot; Generated ${escapeHtml(finalizedAt)}</div>
</body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export interface CompleteEncounterResult {
  encounterId: string;
  status: string;
  document: ClinicalDocument;
}

export async function completeEncounter(
  db: Db,
  encounterId: string,
  clinicianId?: string,
): Promise<CompleteEncounterResult | null> {
  const existing = await db.queryOne<{ id: string }>(
    `SELECT id FROM encounter.encounter WHERE id = $1`,
    [encounterId],
  );
  if (!existing) return null;

  const snapshot = await getEncounter(db, encounterId);
  if (!snapshot) return null;

  const mrnFact = snapshot.facts.find((f) => f.factCode === 'MRN');
  const nameFact = snapshot.facts.find((f) => f.factCode === 'PATIENT_NAME');
  const department =
    DEPARTMENT_BY_TYPE[snapshot.context.encounterTypeCode ?? ''] ??
    snapshot.context.encounterTypeCode ??
    '';

  const finalizedAt = new Date().toISOString();

  await db.query('BEGIN');
  try {
    await db.query(
      `UPDATE encounter.encounter
          SET status_code = 'completed', ended_at = now(), updated_at = now()
        WHERE id = $1`,
      [encounterId],
    );

    await ensureDocumentType(db);

    const docRow = await db.queryOne<{ id: string }>(
      `INSERT INTO document.document
          (patient_id, encounter_id, document_type_code, title, status, current_version, created_by)
       VALUES ($1, $2, $3, $4, 'final', 1, $5)
       RETURNING id`,
      [
        snapshot.patientId,
        encounterId,
        DOCUMENT_TYPE,
        'Clinical History',
        clinicianId ?? null,
      ],
    );
    const documentId = docRow!.id;

    const html = buildDocumentHtml(
      snapshot,
      nameFact?.text ?? '',
      mrnFact?.text ?? '',
      department,
      1,
      finalizedAt,
    );

    const versionRow = await db.queryOne<{ id: string }>(
      `INSERT INTO document.document_version (document_id, version, content, content_json, created_by)
       VALUES ($1, 1, $2, $3, $4)
       RETURNING id`,
      [documentId, html, { patientId: snapshot.patientId, encounterId, facts: snapshot.facts, version: 1 }, clinicianId ?? null],
    );

    await db.query(
      `INSERT INTO document.document_export (id, document_id, export_type, format, status, exported_by)
       VALUES (gen_random_uuid(), $1, 'pdf', 'html', 'completed', $2)`,
      [documentId, clinicianId ?? null],
    );

    await db.query('COMMIT');

    const createdDocument = await getEncounterDocument(db, encounterId);
    if (!createdDocument) {
      throw new Error('Failed to read created document');
    }

    await recordJourneyEvent(db, {
      eventType: JourneyEventType.ENCOUNTER_COMPLETED,
      sourceType: 'system',
      sourceId: clinicianId ?? null,
      patientId: snapshot.patientId,
      encounterId,
      payload: {
        statusCode: 'completed',
        finalizedAt,
        documentId: createdDocument.documentId,
      },
    });

    await recordJourneyEvent(db, {
      eventType: JourneyEventType.DOCUMENT_GENERATED,
      sourceType: 'system',
      sourceId: clinicianId ?? null,
      patientId: snapshot.patientId,
      encounterId,
      payload: {
        documentId: createdDocument.documentId,
        title: createdDocument.title,
        status: createdDocument.status,
        version: 1,
      },
    });

    return {
      encounterId,
      status: 'completed',
      document: createdDocument,
    };
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  }
}

export async function getEncounterDocument(
  db: Db,
  encounterId: string,
): Promise<ClinicalDocument | null> {
  const doc = await db.queryOne<{
    id: string;
    patient_id: string;
    title: string;
    status: string;
    current_version: number;
  }>(
    `SELECT id, patient_id, title, status, current_version
       FROM document.document
      WHERE encounter_id = $1
      ORDER BY created_at DESC
      LIMIT 1`,
    [encounterId],
  );
  if (!doc) return null;

  const [versions, exports] = await Promise.all([
    db.query<{
      version: number;
      content: string | null;
      content_json: unknown;
      created_at: Date;
    }>(
      `SELECT version, content, content_json, created_at
         FROM document.document_version
        WHERE document_id = $1
        ORDER BY version DESC`,
      [doc.id],
    ),
    db.query<{
      export_type: string;
      format: string | null;
      status: string;
      exported_at: Date;
    }>(
      `SELECT export_type, format, status, exported_at
         FROM document.document_export
        WHERE document_id = $1
        ORDER BY exported_at DESC`,
      [doc.id],
    ),
  ]);

  return {
    documentId: doc.id,
    encounterId,
    title: doc.title,
    status: doc.status,
    currentVersion: doc.current_version,
    versions: versions.map((v) => ({
      version: v.version,
      content: v.content,
      contentJson: v.content_json,
      createdAt: new Date(v.created_at).toISOString(),
    })),
    exports: exports.map((e) => ({
      exportType: e.export_type,
      format: e.format,
      status: e.status,
      exportedAt: new Date(e.exported_at).toISOString(),
    })),
  };
}

export async function listEncounters(db: Db): Promise<EncounterSummaryRow[]> {
  const rows = await db.query<EncounterListRow>(
    `SELECT *
       FROM (
         SELECT
           e.id                    AS encounter_id,
           e.patient_id            AS patient_id,
           e.encounter_type_code   AS encounter_type_code,
           e.status_code           AS status_code,
           COALESCE(e.started_at, e.created_at) AS started_at,
           p.sex_at_birth        AS gender,
           p.birth_date          AS birth_date,
           p.preferred_name        AS preferred_name,
           (SELECT fv.value_text
              FROM clinical.fact_value fv
              JOIN clinical.fact f ON f.id = fv.fact_id
             WHERE f.encounter_id = e.id
               AND f.fact_definition_code = 'PRESENTING_COMPLAINT'
               AND f.status_code = 'active'
             ORDER BY fv.value_order
             LIMIT 1)              AS presenting_complaint,
           EXISTS (
             SELECT 1
               FROM clinical.fact sf
              WHERE sf.encounter_id = e.id
                AND sf.fact_definition_code = 'PRESENTING_COMPLAINT'
                AND sf.status_code = 'active'
           )
           AND (
             p.preferred_name IS NOT NULL
             OR (
               p.sex_at_birth IS NOT NULL
               AND lower(p.sex_at_birth) <> 'unknown'
             )
             OR p.birth_date IS NOT NULL
             OR EXISTS (
               SELECT 1
                 FROM clinical.fact idf
                WHERE idf.encounter_id = e.id
                  AND idf.fact_definition_code IN (
                    'PATIENT_NAME', 'SEX', 'DATE_OF_BIRTH',
                    'AGE_YEARS', 'AGE_MONTHS', 'AGE_DAYS'
                  )
             )
           )                       AS has_substantive
         FROM encounter.encounter e
         JOIN patient.patient pp ON pp.id = e.patient_id
         LEFT JOIN identity.person p ON p.id = pp.person_id
         WHERE e.status_code <> 'planned'
       ) sub
      WHERE sub.has_substantive
      ORDER BY sub.started_at DESC
      LIMIT 200`,
  );

  return rows.map((row) => {
    const startedAt = row.started_at
      ? new Date(row.started_at).toISOString()
      : new Date().toISOString();
    const statusCode = row.status_code;
    const status: EncounterSummaryRow['status'] =
      statusCode === 'completed'
        ? 'completed'
        : statusCode === 'cancelled'
          ? 'cancelled'
          : row.has_substantive
            ? 'in_progress'
            : 'draft';

    return {
      encounterId: row.encounter_id as string,
      patientId: row.patient_id as string,
      patientName: row.preferred_name || '',
      age: ageFromBirthDate(row.birth_date),
      sex: row.gender || 'unknown',
      department:
        DEPARTMENT_BY_TYPE[row.encounter_type_code] ?? row.encounter_type_code,
      encounterType: row.encounter_type_code ?? null,
      presentingComplaint: row.presenting_complaint || '',
      startedAt,
      status,
      hasSubstantive: row.has_substantive,
    };
  });
}
