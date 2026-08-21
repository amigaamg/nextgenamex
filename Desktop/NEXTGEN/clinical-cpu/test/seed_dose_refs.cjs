const { Client } = require('pg');

const REFS = [
  // ---- AMOXICILLIN ----------------------------------------------------------
  {
    medication_code: 'AMOXICILLIN',
    population: 'ADULT',
    indication_code: 'RESPIRATORY_INFECTION',
    route: 'oral',
    dose_expression: '500 mg every 8 hours',
    dose_basis: 'fixed',
    dose_min: 500,
    dose_max: 875,
    dose_unit: 'mg',
    frequency: 'every 8 hours',
    max_single_dose: 875,
    max_single_dose_unit: 'mg',
    max_daily_dose: 3000,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },
  {
    medication_code: 'AMOXICILLIN',
    population: 'PEDIATRIC',
    indication_code: 'RESPIRATORY_INFECTION',
    route: 'oral',
    dose_expression: '40-90 mg/kg/day divided every 8-12 hours',
    dose_basis: 'weight',
    dose_min: null,
    dose_max: null,
    dose_unit: 'mg',
    frequency: 'divided every 8 hours',
    max_single_dose: 875,
    max_single_dose_unit: 'mg',
    max_daily_dose: 4000,
    max_daily_dose_unit: 'mg',
    weight_min_kg: null,
    weight_max_kg: 40,
    status: 'ACTIVE',
  },

  // ---- PARACETAMOL / ACETAMINOPHEN ------------------------------------------
  {
    medication_code: 'PARACETAMOL',
    population: 'ADULT',
    indication_code: 'FEVER',
    route: 'oral',
    dose_expression: '500-1000 mg every 4-6 hours PRN',
    dose_basis: 'fixed',
    dose_min: 500,
    dose_max: 1000,
    dose_unit: 'mg',
    frequency: 'every 4-6 hours PRN',
    max_single_dose: 1000,
    max_single_dose_unit: 'mg',
    max_daily_dose: 4000,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },
  {
    medication_code: 'PARACETAMOL',
    population: 'PEDIATRIC',
    indication_code: 'FEVER',
    route: 'oral',
    dose_expression: '10-15 mg/kg every 4-6 hours PRN',
    dose_basis: 'weight',
    dose_min: null,
    dose_max: null,
    dose_unit: 'mg',
    frequency: 'every 4-6 hours PRN',
    max_single_dose: 1000,
    max_single_dose_unit: 'mg',
    max_daily_dose: 4000,
    max_daily_dose_unit: 'mg',
    weight_min_kg: null,
    weight_max_kg: 60,
    status: 'ACTIVE',
  },

  // ---- IBUPROFEN ------------------------------------------------------------
  {
    medication_code: 'IBUPROFEN',
    population: 'ADULT',
    indication_code: 'PAIN',
    route: 'oral',
    dose_expression: '200-400 mg every 6-8 hours',
    dose_basis: 'fixed',
    dose_min: 200,
    dose_max: 400,
    dose_unit: 'mg',
    frequency: 'every 6-8 hours',
    max_single_dose: 400,
    max_single_dose_unit: 'mg',
    max_daily_dose: 3200,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },
  {
    medication_code: 'IBUPROFEN',
    population: 'PEDIATRIC',
    indication_code: 'PAIN',
    route: 'oral',
    dose_expression: '5-10 mg/kg every 6-8 hours',
    dose_basis: 'weight',
    dose_min: null,
    dose_max: null,
    dose_unit: 'mg',
    frequency: 'every 6-8 hours',
    max_single_dose: 400,
    max_single_dose_unit: 'mg',
    max_daily_dose: 2400,
    max_daily_dose_unit: 'mg',
    weight_min_kg: null,
    weight_max_kg: 40,
    status: 'ACTIVE',
  },

  // ---- AZITHROMYCIN ----------------------------------------------------------
  {
    medication_code: 'AZITHROMYCIN',
    population: 'ADULT',
    indication_code: 'RESPIRATORY_INFECTION',
    route: 'oral',
    dose_expression: '500 mg once daily',
    dose_basis: 'fixed',
    dose_min: 500,
    dose_max: 500,
    dose_unit: 'mg',
    frequency: 'once daily',
    max_single_dose: 500,
    max_single_dose_unit: 'mg',
    max_daily_dose: 500,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },
  {
    medication_code: 'AZITHROMYCIN',
    population: 'PEDIATRIC',
    indication_code: 'RESPIRATORY_INFECTION',
    route: 'oral',
    dose_expression: '10 mg/kg once daily (max 500 mg)',
    dose_basis: 'weight',
    dose_min: null,
    dose_max: null,
    dose_unit: 'mg',
    frequency: 'once daily',
    max_single_dose: 500,
    max_single_dose_unit: 'mg',
    max_daily_dose: 500,
    max_daily_dose_unit: 'mg',
    weight_min_kg: null,
    weight_max_kg: 50,
    status: 'ACTIVE',
  },

  // ---- SALBUTAMOL (INHALED) ---------------------------------------------------
  {
    medication_code: 'SALBUTAMOL',
    population: 'ADULT',
    indication_code: 'BRONCHOSPASM',
    route: 'inhalation',
    dose_expression: '100-200 mcg as needed',
    dose_basis: 'fixed',
    dose_min: 100,
    dose_max: 200,
    dose_unit: 'mcg',
    frequency: 'as needed',
    max_single_dose: 200,
    max_single_dose_unit: 'mcg',
    max_daily_dose: 1600,
    max_daily_dose_unit: 'mcg',
    status: 'ACTIVE',
  },
  {
    medication_code: 'SALBUTAMOL',
    population: 'PEDIATRIC',
    indication_code: 'BRONCHOSPASM',
    route: 'inhalation',
    dose_expression: '100-200 mcg as needed',
    dose_basis: 'fixed',
    dose_min: 100,
    dose_max: 200,
    dose_unit: 'mcg',
    frequency: 'as needed',
    max_single_dose: 200,
    max_single_dose_unit: 'mcg',
    max_daily_dose: 800,
    max_daily_dose_unit: 'mcg',
    weight_min_kg: null,
    weight_max_kg: 30,
    status: 'ACTIVE',
  },

  // ---- PREDNISOLONE ------------------------------------------------------------
  {
    medication_code: 'PREDNISOLONE',
    population: 'ADULT',
    indication_code: 'INFLAMMATION',
    route: 'oral',
    dose_expression: '5-60 mg once daily',
    dose_basis: 'fixed',
    dose_min: 5,
    dose_max: 60,
    dose_unit: 'mg',
    frequency: 'once daily',
    max_single_dose: 60,
    max_single_dose_unit: 'mg',
    max_daily_dose: 60,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },

  // ---- CEFTRIAXONE ---------------------------------------------------------------
  {
    medication_code: 'CEFTRIAXONE',
    population: 'ADULT',
    indication_code: 'SEVERE_INFECTION',
    route: 'intravenous',
    dose_expression: '1-2 g once daily',
    dose_basis: 'fixed',
    dose_min: 1000,
    dose_max: 2000,
    dose_unit: 'mg',
    frequency: 'once daily',
    max_single_dose: 2000,
    max_single_dose_unit: 'mg',
    max_daily_dose: 4000,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },

  // ---- MORPHINE (IV) ---------------------------------------------------------------
  {
    medication_code: 'MORPHINE',
    population: 'ADULT',
    indication_code: 'SEVERE_PAIN',
    route: 'intravenous',
    dose_expression: '2.5-10 mg every 4 hours',
    dose_basis: 'fixed',
    dose_min: 2.5,
    dose_max: 10,
    dose_unit: 'mg',
    frequency: 'every 4 hours',
    max_single_dose: 10,
    max_single_dose_unit: 'mg',
    max_daily_dose: 60,
    max_daily_dose_unit: 'mg',
    status: 'ACTIVE',
  },
];

async function main() {
  const c = new Client({
    host: 'localhost',
    port: 5432,
    user: 'postgres',
    password: 'postgres',
    database: 'amexan',
  });
  await c.connect();

  const { randomUUID } = require('node:crypto');

  const MEDS = [
    ['AMOXICILLIN', 'Amoxicillin', 'oral', '500 mg capsule', 'Antibiotic', 'Penicillin'],
    ['PARACETAMOL', 'Paracetamol', 'oral', '500 mg tablet', 'Analgesic', 'NSAID'],
    ['IBUPROFEN', 'Ibuprofen', 'oral', '200 mg tablet', 'Analgesic', 'NSAID'],
    ['AZITHROMYCIN', 'Azithromycin', 'oral', '500 mg tablet', 'Antibiotic', 'Macrolide'],
    ['SALBUTAMOL', 'Salbutamol', 'inhalation', '100 mcg inhaler', 'Bronchodilator', 'Beta2 agonist'],
    ['PREDNISOLONE', 'Prednisolone', 'oral', '5 mg tablet', 'Corticosteroid', 'Corticosteroid'],
    ['CEFTRIAXONE', 'Ceftriaxone', 'intravenous', '1 g injection', 'Antibiotic', 'Cephalosporin'],
    ['MORPHINE', 'Morphine', 'intravenous', '10 mg injection', 'Opioid', 'Opioid'],
  ];

  const existingMeds = await c.query(
    'SELECT medication_code FROM clinical.medications',
  );
  const seenMeds = new Set(existingMeds.rows.map((r) => r.medication_code));

  let medsInserted = 0;
  for (const m of MEDS) {
    if (seenMeds.has(m[0])) continue;
    await c.query(
      `INSERT INTO clinical.medications
        (medication_code, generic_name, route, formulation,
         therapeutic_class, pharmacological_class, active)
       VALUES ($1,$2,$3,$4,$5,$6,true)`,
      m,
    );
    medsInserted++;
  }
  console.log('medications inserted: ' + medsInserted);

  const existing = await c.query(
    'SELECT medication_code FROM clinical.drug_dose_reference',
  );
  const seen = new Set(existing.rows.map((r) => r.medication_code));

  let inserted = 0;
  for (const r of REFS) {
    if (seen.has(r.medication_code)) continue;
    await c.query(
      `INSERT INTO clinical.drug_dose_reference
        (id, medication_code, population, indication_code, route,
         dose_expression, dose_basis, dose_min, dose_max, dose_unit,
         frequency, max_single_dose, max_single_dose_unit,
         max_daily_dose, max_daily_dose_unit,
         weight_min_kg, weight_max_kg, age_min_years, age_max_years,
         status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)`,
      [
        randomUUID(),
        r.medication_code,
        r.population,
        r.indication_code,
        r.route,
        r.dose_expression,
        r.dose_basis,
        r.dose_min,
        r.dose_max,
        r.dose_unit,
        r.frequency,
        r.max_single_dose,
        r.max_single_dose_unit,
        r.max_daily_dose,
        r.max_daily_dose_unit,
        r.weight_min_kg ?? null,
        r.weight_max_kg ?? null,
        null,
        null,
        r.status,
      ],
    );
    inserted++;
  }

  console.log('inserted ' + inserted + ' dose references');
  await c.end();
}

main().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});