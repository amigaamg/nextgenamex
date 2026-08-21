import { writeFileSync } from 'node:fs';

import { composePdfContent } from '../dist/server/compose.js';
import { renderEncounterPdf } from '../dist/server/pdf.js';

function fact(
  factCode,
  section,
  { text = null, numeric = null, boolean = null, unitCode = null } = {},
) {
  return {
    id: `${factCode}-${Math.random().toString(36).slice(2)}`,
    factCode,
    section,
    statusCode: 'active',
    sourceType: 'patient',
    recordedAt: new Date().toISOString(),
    dataType: 'text',
    text,
    numeric,
    boolean,
    unitCode,
  };
}

function baseSnapshot() {
  return {
    patientId: 'pat-1',
    encounterId: 'enc-1',
    context: {
      sex: 'male',
      birthDate: null,
      department: null,
      encounterTypeCode: 'opd',
      presentingComplaint: null,
    },
    facts: [
      fact('PATIENT_NAME', 'biodata', {
        text: 'kimunya njogu',
      }),
      fact('MRN', 'biodata', {
        text: 'Patient No 00130',
      }),
      fact('SEX', 'biodata', { text: 'male' }),
      fact('REPORTED_AGE', 'biodata', {
        numeric: 28,
      }),
      fact('OCCUPATION', 'biodata', {
        text: 'teacher',
      }),
      fact('RESIDENCE', 'biodata', {
        text: 'kimunye',
      }),
      fact('COUNTY', 'biodata', {
        text: 'kirinyaga',
      }),
      fact('INFORMANT_RELATION', 'biodata', {
        text: 'SELF',
      }),
      fact('INFORMANT_RELIABILITY', 'biodata', {
        text: 'GOOD',
      }),
    ],
  };
}

function withStructuredComplaints(snapshot) {
  snapshot.facts.push(
    fact('CHIEF_COMPLAINT_ORDER', 'chief_complaint', {
      text: 'COUGH,FEVER',
    }),
    fact('CHIEF_COMPLAINT_COUGH_LABEL', 'chief_complaint', {
      text: 'Cough',
    }),
    fact('CHIEF_COMPLAINT_COUGH_DURATION', 'chief_complaint', {
      text: '4 days',
      numeric: 4,
      unitCode: 'days',
    }),
    fact('CHIEF_COMPLAINT_FEVER_LABEL', 'chief_complaint', {
      text: 'Fever',
    }),
    fact('CHIEF_COMPLAINT_FEVER_DURATION', 'chief_complaint', {
      text: '3 days',
      numeric: 3,
      unitCode: 'days',
    }),
  );
  return snapshot;
}

function withLegacyJunkSummary(snapshot) {
  snapshot.context.presentingComplaint =
    'COUGH for days; FEVER for days; Yes; NO_CHIEF_COMPLAINT; None';
  return snapshot;
}

function withEqualComplaints(snapshot) {
  snapshot.facts.push(
    fact('CHIEF_COMPLAINT_ORDER', 'chief_complaint', {
      text: 'COUGH,FEVER',
    }),
    fact('CHIEF_COMPLAINT_COUGH_LABEL', 'chief_complaint', {
      text: 'Cough',
    }),
    fact('CHIEF_COMPLAINT_COUGH_DURATION', 'chief_complaint', {
      text: '4 days',
      numeric: 4,
      unitCode: 'days',
    }),
    fact('CHIEF_COMPLAINT_FEVER_LABEL', 'chief_complaint', {
      text: 'Fever',
    }),
    fact('CHIEF_COMPLAINT_FEVER_DURATION', 'chief_complaint', {
      text: '4 days',
      numeric: 4,
      unitCode: 'days',
    }),
  );
  return snapshot;
}

function withUnknownFeverDuration(snapshot) {
  snapshot.facts.push(
    fact('CHIEF_COMPLAINT_ORDER', 'chief_complaint', {
      text: 'COUGH,FEVER',
    }),
    fact('CHIEF_COMPLAINT_COUGH_LABEL', 'chief_complaint', {
      text: 'Cough',
    }),
    fact('CHIEF_COMPLAINT_COUGH_DURATION', 'chief_complaint', {
      text: '4 days',
      numeric: 4,
      unitCode: 'days',
    }),
    fact('CHIEF_COMPLAINT_FEVER_LABEL', 'chief_complaint', {
      text: 'Fever',
    }),
  );
  return snapshot;
}

// -----------------------------------------------------------------------------
// Structured path (the user's real encounter)
// -----------------------------------------------------------------------------

const structured = composePdfContent(
  withStructuredComplaints(baseSnapshot()),
);

console.log('--- structured path ---');
console.log('patientName:', structured.patientName);
console.log('mrn:', structured.mrn);
console.log('age:', structured.age);
console.log('occupation:', structured.occupation);
console.log('residence:', structured.residence);
console.log('county:', structured.county);
console.log('informant:', structured.informantRelation, structured.informantReliability);
console.log('complaints:', JSON.stringify(structured.complaints));
console.log('hpi:', structured.hpi);

const expectedHpiStructured =
  'The illness began with cough 4 days ago. Fever developed 1 day after the cough began.';

if (structured.hpi !== expectedHpiStructured) {
  throw new Error(
    `Structured HPI mismatch:\n  got:  ${structured.hpi}\n  want: ${expectedHpiStructured}`,
  );
}

if (structured.complaints.length !== 2) {
  throw new Error('Structured: expected 2 complaints');
}

if (
  structured.complaints[0].label !== 'Cough' ||
  structured.complaints[0].duration?.value !== 4
) {
  throw new Error('Structured: first complaint should be Cough 4 days');
}

if (structured.complaints[1].label !== 'Fever') {
  throw new Error('Structured: second complaint should be Fever');
}

if (structured.age !== 28) {
  throw new Error(`Structured: expected age 28, got ${structured.age}`);
}

// -----------------------------------------------------------------------------
// Equal durations — symptoms that began together must not be ordered
// -----------------------------------------------------------------------------

const equal = composePdfContent(
  withEqualComplaints(baseSnapshot()),
);

console.log('--- equal durations ---');
console.log('hpi:', equal.hpi);

const expectedHpiEqual =
  'The illness began with cough 4 days ago. Fever began at the same time.';

if (equal.hpi !== expectedHpiEqual) {
  throw new Error(
    `Equal-duration HPI mismatch:\n  got:  ${equal.hpi}\n  want: ${expectedHpiEqual}`,
  );
}

// -----------------------------------------------------------------------------
// Unknown duration — an unknown onset must never invent a time relationship
// -----------------------------------------------------------------------------

const unknown = composePdfContent(
  withUnknownFeverDuration(baseSnapshot()),
);

console.log('--- unknown fever duration ---');
console.log('hpi:', unknown.hpi);

const expectedHpiUnknown =
  'The illness began with cough 4 days ago. Fever is also present.';

if (unknown.hpi !== expectedHpiUnknown) {
  throw new Error(
    `Unknown-duration HPI mismatch:\n  got:  ${unknown.hpi}\n  want: ${expectedHpiUnknown}`,
  );
}

// -----------------------------------------------------------------------------
// Canonical DB cough facts (reference: cough 4d, acute onset, productive,
// yellow sputum, worse at night, no blood) — the HPI narrative renders the
// CPU's facts and filters negatives.
// -----------------------------------------------------------------------------

function withCoughBatteryFacts(snapshot) {
  snapshot.facts.push(
    fact('COUGH_DURATION_DAYS', 'hpi', {
      numeric: 4,
      unitCode: 'day',
    }),
    fact('COUGH_ONSET', 'hpi', { text: 'ACUTE' }),
    fact('COUGH_PRODUCTIVITY', 'hpi', {
      text: 'PRODUCTIVE',
    }),
    fact('SPUTUM_COLOUR', 'hpi', {
      text: 'YELLOW_GREEN',
    }),
    fact('COUGH_NIGHT_PREDOMINANCE', 'hpi', {
      text: 'YES',
    }),
    fact('BLOOD_IN_SPUTUM', 'hpi', { text: 'NO' }),
  );
  return snapshot;
}

const battery = composePdfContent(
  withCoughBatteryFacts(
    withStructuredComplaints(baseSnapshot()),
  ),
);

console.log('--- cough battery facts ---');
console.log('hpi:', battery.hpi);

const expectedHpiBattery =
  'The illness began with cough 4 days ago, acute onset. ' +
  'Fever developed 1 day after the cough began. ' +
  'The cough is productive. ' +
  'The cough is worse at night. ' +
  'The sputum is yellow green in colour.';

if (battery.hpi !== expectedHpiBattery) {
  throw new Error(
    `Cough-battery HPI mismatch:\n  got:  ${battery.hpi}\n  want: ${expectedHpiBattery}`,
  );
}

if (battery.hpi.includes('blood')) {
  throw new Error(
    'Cough battery: BLOOD_IN_SPUTUM=NO must not appear in HPI',
  );
}

// -----------------------------------------------------------------------------
// Legacy junk summary path (old DB rows) — must never emit "Yes"/bare "for days"
// -----------------------------------------------------------------------------

const legacy = composePdfContent(
  withLegacyJunkSummary(baseSnapshot()),
);

console.log('--- legacy junk path ---');
console.log('complaints:', JSON.stringify(legacy.complaints));
console.log('hpi:', legacy.hpi);

if (legacy.complaints.length !== 2) {
  throw new Error(
    `Legacy: expected 2 clean complaints, got ${legacy.complaints.length}`,
  );
}

for (const complaint of legacy.complaints) {
  const lower = complaint.label.toLowerCase();
  if (['yes', 'no', 'none', 'no chief complaint'].includes(lower)) {
    throw new Error(`Legacy: junk leaked into complaints: ${complaint.label}`);
  }
}

if (legacy.complaints.some((c) => c.label.toLowerCase() === 'no chief complaint')) {
  throw new Error('Legacy: NO_CHIEF_COMPLAINT leaked');
}

// -----------------------------------------------------------------------------
// Render the structured encounter to PDF and verify clean bytes
// -----------------------------------------------------------------------------

const pdf = renderEncounterPdf({
  encounterId: structured && 'enc-1',
  department: null,
  sex: 'male',
  birthDate: null,
  patientName: structured.patientName,
  mrn: structured.mrn,
  age: structured.age,
  occupation: structured.occupation,
  residence: structured.residence,
  county: structured.county,
  informantRelation: structured.informantRelation,
  informantReliability: structured.informantReliability,
  complaints: structured.complaints,
  hpi: structured.hpi,
  presentingComplaint: null,
  facts: [],
});

writeFileSync('pdf-coincide-test.pdf', pdf);

const text = pdf.toString('latin1');
const mustContain = [
  'kimunya njogu',
  '28 years',
  'Male',
  'MRN Patient No 00130',
  'teacher',
  'kimunye',
  'kirinyaga',
  'Informant: self',
  'good',
  'Cough',
  'Fever',
  '4 days',
  '3 days',
  'CHIEF COMPLAINT',
  'HPI',
];

let allOk = true;
for (const needle of mustContain) {
  const ok = text.includes(needle);
  if (!ok) allOk = false;
  console.log(`${ok ? 'OK  ' : 'MISS'} ${needle}`);
}

for (const banned of ['Yes', 'for days', 'NO_CHIEF_COMPLAINT', 'CHIEF COMPLAINT (C/C)']) {
  const leaked = text.includes(banned);
  if (leaked) allOk = false;
  console.log(`${leaked ? 'LEAK' : 'OK  '} (absent) ${banned}`);
}

if (!allOk) {
  throw new Error('PDF content checks failed');
}

console.log('OK — structured + legacy-junk paths produce clean, coincident output.');