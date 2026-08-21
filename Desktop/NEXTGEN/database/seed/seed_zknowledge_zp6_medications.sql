-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP6
-- FULL MEDICATION INTELLIGENCE + DOSE REFERENCES
-- =============================================================================
--
-- PURPOSE
-- -------
-- This seed establishes the reusable AMEXAN Medication Intelligence Layer.
--
-- Architecture:
--
--      CONDITION
--          │
--          ├── medication_condition
--          │       └── role
--          │
--          └── protocol
--                   │
--                   └── medication
--                           │
--                           └── drug_dose_reference
--
-- IMPORTANT:
-- 1. Medications are reusable knowledge objects.
-- 2. A medication is NOT itself a treatment protocol.
-- 3. medication_condition expresses that a medication may have a role
--    in a condition.
-- 4. drug_dose_reference stores population + indication + route-specific
--    dose knowledge.
-- 5. Production prescribing MUST NOT consume an unverified dose row.
-- 6. VERIFY_* rows are deliberately gated and are NOT executable dosing.
-- 7. Jurisdiction, formulary, age, weight, renal function, hepatic function,
--    pregnancy/lactation, allergy status and contraindications must be resolved
--    before a medication can become an executable order.
--
-- MVP clinical coverage:
--
--   PNEUMONIA
--   TUBERCULOSIS
--   ASTHMA
--   HEART FAILURE
--   GERD
--
-- Medication families represented:
--
--   Antibacterials
--   Macrolides
--   Corticosteroids
--   Bronchodilators
--   ICS / LABA
--   Loop diuretics
--   ACE inhibitors
--   ARNI
--   Beta blockers
--   Mineralocorticoid receptor antagonists
--   SGLT2 inhibitors
--   Vasodilator therapy
--   Proton-pump inhibitors
--   H2 receptor antagonists
--   Antacids
--   TB first-line medicines
--   Pyridoxine
--   Analgesic / antipyretic
--
-- =============================================================================



-- ============================================================================
-- 1. MEDICATION MASTER
-- ============================================================================

INSERT INTO knowledge.medication (
    id,
    concept_id,
    medication_code,
    generic_name,
    drug_class,
    route_options,
    formulations,
    contraindications,
    renal_adjustment_notes,
    hepatic_adjustment_notes,
    pregnancy_notes,
    lactation_notes,
    evidence_source
) VALUES

-- ============================================================================
-- PNEUMONIA / COMMON RESPIRATORY INFECTION
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000001',
    'f0a00000-0000-0000-0000-000000000027',
    'MED-AMOXICILLIN',
    'Amoxicillin',
    'Aminopenicillin',
    '["oral","intravenous"]'::jsonb,
    '["tablet","capsule","oral_suspension","injection"]'::jsonb,
    '["serious_immediate_beta_lactam_hypersensitivity"]'::jsonb,
    'Renal dose adjustment may be required according to kidney function and local formulary.',
    'No routine hepatic adjustment; verify severe hepatic disease context.',
    'Use current pregnancy guidance and indication-specific guidance.',
    'Generally compatible with breastfeeding; verify current product/formulary guidance.',
    'Current antimicrobial guideline/formulary required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000002',
    'f0a00000-0000-0000-0000-000000000028',
    'MED-AMOXICILLIN-CLAVULANATE',
    'Amoxicillin/clavulanate',
    'Aminopenicillin / beta-lactamase inhibitor',
    '["oral","intravenous"]'::jsonb,
    '["tablet","oral_suspension","injection"]'::jsonb,
    '["serious_immediate_beta_lactam_hypersensitivity",
      "previous_cholestatic_jaundice_or_hepatic_dysfunction_associated_with_drug"]'::jsonb,
    'Renal dose adjustment may be required.',
    'Use caution with hepatic dysfunction and prior antibiotic-associated cholestasis.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current antimicrobial guideline/formulary required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000003',
    'f0a00000-0000-0000-0000-000000000029',
    'MED-CEFTRIAXONE',
    'Ceftriaxone',
    'Third-generation cephalosporin',
    '["intravenous","intramuscular"]'::jsonb,
    '["injection"]'::jsonb,
    '["serious_immediate_beta_lactam_hypersensitivity",
      "neonatal_calcium_containing_iv_solution_context"]'::jsonb,
    'Usually no routine renal adjustment when hepatic function is preserved, but verify combined renal/hepatic impairment.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current antimicrobial guideline/formulary required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000004',
    'f0a00000-0000-0000-0000-00000000002a',
    'MED-AZITHROMYCIN',
    'Azithromycin',
    'Macrolide',
    '["oral","intravenous"]'::jsonb,
    '["tablet","capsule","oral_suspension","injection"]'::jsonb,
    '["macrolide_hypersensitivity",
      "significant_qt_prolongation_or_high_risk_arrhythmia_context"]'::jsonb,
    'Use current renal guidance in significant renal impairment.',
    'Use caution in hepatic impairment; verify current guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current antimicrobial guideline/formulary required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-00000000002b',
    'MED-PARACETAMOL',
    'Paracetamol',
    'Analgesic / antipyretic',
    '["oral","intravenous","rectal"]'::jsonb,
    '["tablet","capsule","oral_suspension","injection","suppository"]'::jsonb,
    '["severe_active_liver_disease",
      "previous_serious_hypersensitivity"]'::jsonb,
    'Use current guidance for severe renal impairment and prolonged use.',
    'Maximum total daily exposure requires adjustment/clinical caution in hepatic disease, malnutrition or chronic alcohol exposure.',
    'Use current pregnancy guidance.',
    'Generally compatible with breastfeeding at therapeutic doses; verify current guidance.',
    'Current formulary/product information required before production use.'
),


-- ============================================================================
-- ASTHMA — RELIEVER / BRONCHODILATOR
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000006',
    NULL,
    'MED-SALBUTAMOL',
    'Salbutamol',
    'Short-acting beta-2 agonist (SABA)',
    '["inhaled","nebulized","oral"]'::jsonb,
    '["metered_dose_inhaler","dry_powder_inhaler","nebules","oral_solution","tablet"]'::jsonb,
    '["hypersensitivity",
      "significant_tachyarrhythmia_context"]'::jsonb,
    'No routine adjustment for inhaled use; verify severe renal impairment where relevant.',
    'Use current guidance in severe hepatic disease.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'GINA/current national asthma guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000007',
    NULL,
    'MED-IPRATROPIUM',
    'Ipratropium bromide',
    'Short-acting muscarinic antagonist (SAMA)',
    '["inhaled","nebulized"]'::jsonb,
    '["metered_dose_inhaler","nebules"]'::jsonb,
    '["hypersensitivity_to_atropine_like_agents"]'::jsonb,
    'No routine renal adjustment for inhaled therapy.',
    'No routine hepatic adjustment; verify severe hepatic disease.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'GINA/current national asthma guideline required before production use.'
),


-- ============================================================================
-- ASTHMA — INHALED ANTI-INFLAMMATORY THERAPY
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000008',
    NULL,
    'MED-BUDESONIDE',
    'Budesonide',
    'Inhaled corticosteroid (ICS)',
    '["inhaled","nebulized"]'::jsonb,
    '["metered_dose_inhaler","dry_powder_inhaler","nebules"]'::jsonb,
    '["hypersensitivity"]'::jsonb,
    'No routine renal adjustment.',
    'Use current guidance in severe hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'GINA/current national asthma guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000009',
    NULL,
    'MED-BECLOMETASONE',
    'Beclometasone dipropionate',
    'Inhaled corticosteroid (ICS)',
    '["inhaled"]'::jsonb,
    '["metered_dose_inhaler","dry_powder_inhaler"]'::jsonb,
    '["hypersensitivity"]'::jsonb,
    'No routine renal adjustment.',
    'Use current guidance in severe hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'GINA/current national asthma guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-00000000000a',
    NULL,
    'MED-PREDNISOLONE',
    'Prednisolone',
    'Systemic corticosteroid',
    '["oral"]'::jsonb,
    '["tablet","oral_solution"]'::jsonb,
    '["systemic_fungal_infection_without_appropriate_treatment",
      "live_vaccine_context_at_immunosuppressive_doses",
      "hypersensitivity"]'::jsonb,
    'Use current guidance in renal impairment.',
    'Use caution in hepatic impairment.',
    'Use current pregnancy guidance; indication and duration matter.',
    'Use current lactation guidance.',
    'GINA/current national guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-00000000000b',
    NULL,
    'MED-HYDROCORTISONE',
    'Hydrocortisone',
    'Systemic corticosteroid',
    '["intravenous","intramuscular","oral"]'::jsonb,
    '["injection","tablet"]'::jsonb,
    '["hypersensitivity",
      "systemic_fungal_infection_without_appropriate_treatment"]'::jsonb,
    'Use current guidance in renal impairment.',
    'Use caution in hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current emergency/asthma guideline required before production use.'
),


-- ============================================================================
-- ASTHMA — ICS/LABA
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000000c',
    NULL,
    'MED-BUDESONIDE-FORMOTEROL',
    'Budesonide/formoterol',
    'Inhaled corticosteroid / long-acting beta-2 agonist (ICS/LABA)',
    '["inhaled"]'::jsonb,
    '["metered_dose_inhaler","dry_powder_inhaler"]'::jsonb,
    '["hypersensitivity"]'::jsonb,
    'No routine renal adjustment; verify severe impairment context.',
    'Use caution in severe hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'GINA 2025/current national asthma guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-00000000000d',
    NULL,
    'MED-FORMOTEROL',
    'Formoterol',
    'Long-acting beta-2 agonist (LABA)',
    '["inhaled"]'::jsonb,
    '["dry_powder_inhaler","metered_dose_inhaler"]'::jsonb,
    '["hypersensitivity",
      "use_as_monotherapy_for_asthma"]'::jsonb,
    'Use current renal guidance.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'GINA/current national asthma guideline required before production use.'
),


-- ============================================================================
-- HEART FAILURE — DIURETIC
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000000e',
    NULL,
    'MED-FUROSEMIDE',
    'Furosemide',
    'Loop diuretic',
    '["oral","intravenous","intramuscular"]'::jsonb,
    '["tablet","oral_solution","injection"]'::jsonb,
    '["severe_hypovolaemia",
      "severe_hypokalaemia_or_hyponatraemia_until_corrected",
      "anuria"]'::jsonb,
    'Dose response depends strongly on renal function; higher doses may be required with renal dysfunction.',
    'Use caution in severe hepatic disease and hepatic encephalopathy risk.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure/diuretic guideline required before production use.'
),


-- ============================================================================
-- HEART FAILURE — ACE INHIBITOR
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000000f',
    NULL,
    'MED-ENALAPRIL',
    'Enalapril',
    'Angiotensin-converting enzyme inhibitor (ACE inhibitor)',
    '["oral","intravenous"]'::jsonb,
    '["tablet","oral_solution","injection"]'::jsonb,
    '["pregnancy",
      "previous_ACE_inhibitor_angioedema",
      "bilateral_renal_artery_stenosis_context",
      "significant_hyperkalaemia"]'::jsonb,
    'Dose initiation and titration require renal function and potassium assessment.',
    'No routine hepatic adjustment; verify severe hepatic disease.',
    'Contraindicated during pregnancy.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),


-- ============================================================================
-- HEART FAILURE — ARNI
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000010',
    NULL,
    'MED-SACUBITRIL-VALSARTAN',
    'Sacubitril/valsartan',
    'Angiotensin receptor-neprilysin inhibitor (ARNI)',
    '["oral"]'::jsonb,
    '["tablet"]'::jsonb,
    '["pregnancy",
      "history_of_angioedema_related_to_ACE_inhibitor_or_ARB",
      "concomitant_ACE_inhibitor_use"]'::jsonb,
    'Dose selection requires renal function and potassium assessment.',
    'Dose adjustment may be required in hepatic impairment depending on severity.',
    'Contraindicated during pregnancy.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),


-- ============================================================================
-- HEART FAILURE — BETA BLOCKER
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000011',
    NULL,
    'MED-BISOPROLOL',
    'Bisoprolol',
    'Evidence-based beta-1 selective beta blocker',
    '["oral"]'::jsonb,
    '["tablet"]'::jsonb,
    '["severe_bradycardia",
      "advanced_heart_block_without_pacing",
      "cardiogenic_shock",
      "acute_decompensated_heart_failure_without_stabilization"]'::jsonb,
    'Use current renal guidance.',
    'Dose considerations may apply in significant hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000012',
    NULL,
    'MED-CARVEDILOL',
    'Carvedilol',
    'Non-selective beta blocker / alpha-1 blocker',
    '["oral"]'::jsonb,
    '["tablet","oral_solution"]'::jsonb,
    '["severe_bradycardia",
      "advanced_heart_block_without_pacing",
      "cardiogenic_shock",
      "acute_decompensated_heart_failure_without_stabilization",
      "severe_asthma_or_reactive_airway_context"]'::jsonb,
    'Use current renal guidance.',
    'Use caution in hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000013',
    NULL,
    'MED-METOPROLOL-SUCCINATE',
    'Metoprolol succinate',
    'Evidence-based beta-1 selective beta blocker',
    '["oral"]'::jsonb,
    '["extended_release_tablet"]'::jsonb,
    '["severe_bradycardia",
      "advanced_heart_block_without_pacing",
      "cardiogenic_shock",
      "acute_decompensated_heart_failure_without_stabilization"]'::jsonb,
    'Usually no major renal adjustment; verify current guidance.',
    'Dose considerations may apply in hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),


-- ============================================================================
-- HEART FAILURE — MINERALOCORTICOID RECEPTOR ANTAGONIST
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000014',
    NULL,
    'MED-SPIRONOLACTONE',
    'Spironolactone',
    'Mineralocorticoid receptor antagonist (MRA)',
    '["oral"]'::jsonb,
    '["tablet","oral_suspension"]'::jsonb,
    '["significant_hyperkalaemia",
      "severe_renal_impairment_context",
      "concomitant_potassium_sparing_therapy_without_monitoring"]'::jsonb,
    'Renal function and potassium must be assessed before initiation and during titration.',
    'Use caution in severe hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),


-- ============================================================================
-- HEART FAILURE — SGLT2 INHIBITOR
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000015',
    NULL,
    'MED-DAPAGLIFLOZIN',
    'Dapagliflozin',
    'Sodium-glucose cotransporter-2 inhibitor (SGLT2 inhibitor)',
    '["oral"]'::jsonb,
    '["tablet"]'::jsonb,
    '["hypersensitivity",
      "type_1_diabetes_context_without_specialist_protocol"]'::jsonb,
    'Use current eGFR/renal-function guidance for initiation and continuation.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline/product information required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000016',
    NULL,
    'MED-EMPAGLIFLOZIN',
    'Empagliflozin',
    'Sodium-glucose cotransporter-2 inhibitor (SGLT2 inhibitor)',
    '["oral"]'::jsonb,
    '["tablet"]'::jsonb,
    '["hypersensitivity",
      "type_1_diabetes_context_without_specialist_protocol"]'::jsonb,
    'Use current eGFR/renal-function guidance.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline/product information required before production use.'
),


-- ============================================================================
-- HEART FAILURE — VASODILATOR OPTION
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000017',
    NULL,
    'MED-HYDRAZINE-NITRATE',
    'Hydralazine/isosorbide dinitrate',
    'Direct vasodilator / nitrate combination',
    '["oral"]'::jsonb,
    '["tablet","fixed_dose_combination"]'::jsonb,
    '["severe_hypotension",
      "concomitant_PDE5_inhibitor_context",
      "nitrate_hypersensitivity"]'::jsonb,
    'Use current renal guidance.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current heart-failure guideline required before production use.'
),


-- ============================================================================
-- GERD — PROTON PUMP INHIBITORS
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000018',
    NULL,
    'MED-OMEPRAZOLE',
    'Omeprazole',
    'Proton-pump inhibitor (PPI)',
    '["oral","intravenous"]'::jsonb,
    '["capsule","tablet","oral_suspension","injection"]'::jsonb,
    '["hypersensitivity",
      "important_drug_interaction_context"]'::jsonb,
    'Use current renal guidance; usually no major adjustment.',
    'Dose adjustment may be required in significant hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current GERD guideline/product information required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000019',
    NULL,
    'MED-PANTOPRAZOLE',
    'Pantoprazole',
    'Proton-pump inhibitor (PPI)',
    '["oral","intravenous"]'::jsonb,
    '["tablet","injection"]'::jsonb,
    '["hypersensitivity"]'::jsonb,
    'Usually no major renal adjustment.',
    'Dose considerations may apply in severe hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current GERD guideline/product information required before production use.'
),


-- ============================================================================
-- GERD — H2 BLOCKER
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000001a',
    NULL,
    'MED-FAMOTIDINE',
    'Famotidine',
    'Histamine H2 receptor antagonist',
    '["oral","intravenous"]'::jsonb,
    '["tablet","oral_solution","injection"]'::jsonb,
    '["hypersensitivity"]'::jsonb,
    'Dose adjustment is commonly required in renal impairment.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current GERD guideline/product information required before production use.'
),


-- ============================================================================
-- GERD — ANTACID
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000001b',
    NULL,
    'MED-ALUMINIUM-MAGNESIUM-ANTACID',
    'Aluminium hydroxide/magnesium hydroxide',
    'Antacid',
    '["oral"]'::jsonb,
    '["suspension","chewable_tablet"]'::jsonb,
    '["severe_renal_impairment_context_for_magnesium_containing_products"]'::jsonb,
    'Renal impairment is important because magnesium/aluminium accumulation may occur.',
    'Use current hepatic guidance.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'Current product information required before production use.'
),


-- ============================================================================
-- TUBERCULOSIS — FIRST-LINE MEDICINES
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000001c',
    NULL,
    'MED-RIFAMPICIN',
    'Rifampicin',
    'Rifamycin antituberculosis agent',
    '["oral","intravenous"]'::jsonb,
    '["capsule","tablet","injection"]'::jsonb,
    '["hypersensitivity",
      "important_drug_interaction_context"]'::jsonb,
    'Use current TB guideline guidance.',
    'Major hepatic safety/interaction considerations; verify current TB guidance.',
    'Use current TB pregnancy guidance.',
    'Use current TB lactation guidance.',
    'WHO consolidated TB treatment guidance required before production use.'
),

(
    'f1600000-0000-0000-0000-00000000001d',
    NULL,
    'MED-ISONIAZID',
    'Isoniazid',
    'Antituberculosis agent',
    '["oral","intramuscular"]'::jsonb,
    '["tablet","oral_solution","injection"]'::jsonb,
    '["hypersensitivity",
      "acute_severe_liver_disease_context"]'::jsonb,
    'Usually no routine renal adjustment at standard dosing; verify advanced renal disease.',
    'Major hepatotoxicity considerations.',
    'Use current TB pregnancy guidance.',
    'Use current TB lactation guidance.',
    'WHO consolidated TB treatment guidance required before production use.'
),

(
    'f1600000-0000-0000-0000-00000000001e',
    NULL,
    'MED-PYRAZINAMIDE',
    'Pyrazinamide',
    'Antituberculosis agent',
    '["oral"]'::jsonb,
    '["tablet"]'::jsonb,
    '["severe_hepatic_disease",
      "previous_serious_hypersensitivity"]'::jsonb,
    'Dose scheduling may require modification in advanced renal impairment.',
    'Major hepatotoxicity considerations.',
    'Use current TB pregnancy guidance.',
    'Use current TB lactation guidance.',
    'WHO consolidated TB treatment guidance required before production use.'
),

(
    'f1600000-0000-0000-0000-00000000001f',
    NULL,
    'MED-ETHAMBUTOL',
    'Ethambutol',
    'Antituberculosis agent',
    '["oral"]'::jsonb,
    '["tablet"]'::jsonb,
    '["optic_neuritis",
      "inability_to_assess_visual_function_when_required"]'::jsonb,
    'Dose adjustment is important in significant renal impairment.',
    'Use current hepatic guidance.',
    'Use current TB pregnancy guidance.',
    'Use current TB lactation guidance.',
    'WHO consolidated TB treatment guidance required before production use.'
),

(
    'f1600000-0000-0000-0000-000000000020',
    NULL,
    'MED-PYRIDOXINE',
    'Pyridoxine',
    'Vitamin B6',
    '["oral","intravenous","intramuscular"]'::jsonb,
    '["tablet","injection"]'::jsonb,
    '["hypersensitivity"]'::jsonb,
    'Use current guidance in renal impairment.',
    'Use current guidance in hepatic impairment.',
    'Use current pregnancy guidance.',
    'Use current lactation guidance.',
    'WHO/national TB programme guidance required before production use.'
)

  ON CONFLICT DO NOTHING;



-- ============================================================================
-- 2. DOSE REFERENCES
-- ============================================================================
--
-- IMPORTANT:
-- These are knowledge references, NOT executable prescriptions.
--
-- Every VERIFY_* expression remains non-executable until approved.
--
-- The engine must resolve:
--
--   patient age
--   weight
--   indication
--   severity
--   route
--   renal function
--   hepatic function
--   pregnancy
--   lactation
--   allergy
--   interactions
--   jurisdiction
--   facility formulary
--   guideline version
--
-- before converting a dose reference into an order.
-- ============================================================================


-- ============================================================================
-- PNEUMONIA
-- ============================================================================

INSERT INTO knowledge.drug_dose_reference (
    medication_id,
    population,
    indication_code,
    route,
    dose_expression,
    frequency_expression,
    duration_expression,
    is_verified
) VALUES

(
    'f1600000-0000-0000-0000-000000000001',
    'adult',
    'PNEUMONIA',
    'oral',
    'VERIFY_CURRENT_CAP_AMOXICILLIN_ADULT_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000001',
    'paediatric',
    'PNEUMONIA',
    'oral',
    'VERIFY_WEIGHT_BASED_AMOXICILLIN_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000002',
    'adult',
    'PNEUMONIA',
    'oral',
    'VERIFY_CURRENT_AMOXICILLIN_CLAVULANATE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000003',
    'adult',
    'PNEUMONIA',
    'intravenous',
    'VERIFY_CURRENT_CEFTRIAXONE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000003',
    'paediatric',
    'PNEUMONIA',
    'intravenous',
    'VERIFY_WEIGHT_BASED_CEFTRIAXONE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000004',
    'adult',
    'PNEUMONIA',
    'oral',
    'VERIFY_CURRENT_AZITHROMYCIN_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000004',
    'adult',
    'PNEUMONIA',
    'intravenous',
    'VERIFY_CURRENT_AZITHROMYCIN_IV_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000005',
    'adult',
    'PNEUMONIA',
    'oral',
    'VERIFY_ADULT_PARACETAMOL_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_MAXIMUM_DAILY_EXPOSURE',
    false
),

(
    'f1600000-0000-0000-0000-000000000005',
    'paediatric',
    'PNEUMONIA',
    'oral',
    'VERIFY_WEIGHT_BASED_PARACETAMOL_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_MAXIMUM_DAILY_EXPOSURE',
    false
),


-- ============================================================================
-- ASTHMA
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000006',
    'adult',
    'ASTHMA',
    'inhaled',
    'VERIFY_SALBUTAMOL_INHALER_DOSE',
    'VERIFY_PRN_OR_PROTOCOL_FREQUENCY',
    'VERIFY_MAXIMUM_DAILY_USE',
    false
),

(
    'f1600000-0000-0000-0000-000000000006',
    'paediatric',
    'ASTHMA',
    'inhaled',
    'VERIFY_WEIGHT_OR_AGE_APPROPRIATE_SALBUTAMOL_REGIMEN',
    'VERIFY_FREQUENCY',
    'VERIFY_MAXIMUM_USE',
    false
),

(
    'f1600000-0000-0000-0000-000000000006',
    'adult',
    'ASTHMA_EXACERBATION',
    'nebulized',
    'VERIFY_SALBUTAMOL_NEBULIZED_DOSE',
    'VERIFY_REPEAT_INTERVAL',
    'VERIFY_EMERGENCY_PROTOCOL_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000006',
    'paediatric',
    'ASTHMA_EXACERBATION',
    'nebulized',
    'VERIFY_PAEDIATRIC_SALBUTAMOL_NEBULIZED_DOSE',
    'VERIFY_REPEAT_INTERVAL',
    'VERIFY_EMERGENCY_PROTOCOL_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000007',
    'adult',
    'ASTHMA_EXACERBATION',
    'nebulized',
    'VERIFY_IPRATROPIUM_DOSE',
    'VERIFY_REPEAT_INTERVAL',
    'VERIFY_EMERGENCY_PROTOCOL_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000008',
    'adult',
    'ASTHMA',
    'inhaled',
    'VERIFY_BUDESONIDE_CONTROLLER_DOSE',
    'VERIFY_CONTROLLER_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000009',
    'adult',
    'ASTHMA',
    'inhaled',
    'VERIFY_BECLOMETASONE_CONTROLLER_DOSE',
    'VERIFY_CONTROLLER_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-00000000000a',
    'adult',
    'ASTHMA_EXACERBATION',
    'oral',
    'VERIFY_SYSTEMIC_CORTICOSTEROID_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_SHORT_COURSE_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000000a',
    'paediatric',
    'ASTHMA_EXACERBATION',
    'oral',
    'VERIFY_WEIGHT_BASED_SYSTEMIC_CORTICOSTEROID_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_SHORT_COURSE_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000000c',
    'adult',
    'ASTHMA',
    'inhaled',
    'VERIFY_BUDESONIDE_FORMOTEROL_STRENGTH',
    'VERIFY_MAINTENANCE_AND_RELIEVER_REGIMEN',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-00000000000c',
    'adolescent',
    'ASTHMA',
    'inhaled',
    'VERIFY_BUDESONIDE_FORMOTEROL_ADOLESCENT_REGIMEN',
    'VERIFY_MAINTENANCE_AND_RELIEVER_REGIMEN',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000008',
    'paediatric',
    'ASTHMA',
    'inhaled',
    'VERIFY_PAEDIATRIC_ICS_DOSE_BY_AGE_AND_DEVICE',
    'VERIFY_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),


-- ============================================================================
-- HEART FAILURE
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000000e',
    'adult',
    'HEART_FAILURE',
    'oral',
    'VERIFY_FUROSEMIDE_ORAL_DOSE_BASED_ON_CONGESTION_AND_PRIOR_DIURETIC_EXPOSURE',
    'VERIFY_FREQUENCY',
    'VERIFY_TITRATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000000e',
    'adult',
    'ACUTE_DECOMPENSATED_HEART_FAILURE',
    'intravenous',
    'VERIFY_IV_LOOP_DIURETIC_REGIMEN',
    'VERIFY_REASSESSMENT_INTERVAL',
    'VERIFY_UNTIL_DECONGESTION',
    false
),

(
    'f1600000-0000-0000-0000-00000000000f',
    'adult',
    'HEART_FAILURE',
    'oral',
    'VERIFY_ENALAPRIL_STARTING_DOSE',
    'VERIFY_TITRATION_INTERVAL',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000010',
    'adult',
    'HEART_FAILURE_HFrEF',
    'oral',
    'VERIFY_SACUBITRIL_VALSARTAN_STARTING_DOSE',
    'VERIFY_TITRATION_INTERVAL',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000011',
    'adult',
    'HEART_FAILURE_HFrEF',
    'oral',
    'VERIFY_BISOPROLOL_STARTING_DOSE',
    'VERIFY_TITRATION_INTERVAL',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000012',
    'adult',
    'HEART_FAILURE_HFrEF',
    'oral',
    'VERIFY_CARVEDILOL_STARTING_DOSE',
    'VERIFY_TITRATION_INTERVAL',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000013',
    'adult',
    'HEART_FAILURE_HFrEF',
    'oral',
    'VERIFY_METOPROLOL_SUCCINATE_STARTING_DOSE',
    'VERIFY_TITRATION_INTERVAL',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000014',
    'adult',
    'HEART_FAILURE_HFrEF',
    'oral',
    'VERIFY_SPIRONOLACTONE_STARTING_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000015',
    'adult',
    'HEART_FAILURE',
    'oral',
    'VERIFY_DAPAGLIFLOZIN_HEART_FAILURE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000016',
    'adult',
    'HEART_FAILURE',
    'oral',
    'VERIFY_EMPAGLIFLOZIN_HEART_FAILURE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),

(
    'f1600000-0000-0000-0000-000000000017',
    'adult',
    'HEART_FAILURE_HFrEF',
    'oral',
    'VERIFY_HYDRAZINE_NITRATE_REGIMEN',
    'VERIFY_FREQUENCY',
    'VERIFY_LONG_TERM',
    false
),


-- ============================================================================
-- GERD
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000018',
    'adult',
    'GERD',
    'oral',
    'VERIFY_OMEPRAZOLE_GERD_DOSE',
    'VERIFY_ONCE_DAILY_OR_GUIDELINE_REGIMEN',
    'VERIFY_INITIAL_TREATMENT_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000019',
    'adult',
    'GERD',
    'oral',
    'VERIFY_PANTOPRAZOLE_GERD_DOSE',
    'VERIFY_ONCE_DAILY_OR_GUIDELINE_REGIMEN',
    'VERIFY_INITIAL_TREATMENT_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001a',
    'adult',
    'GERD',
    'oral',
    'VERIFY_FAMOTIDINE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001b',
    'adult',
    'GERD',
    'oral',
    'VERIFY_ANTACID_PRODUCT_SPECIFIC_DOSE',
    'VERIFY_AFTER_MEALS_AND_BEDTIME_REGIMEN',
    'VERIFY_DURATION',
    false
),


-- ============================================================================
-- TUBERCULOSIS
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000001c',
    'adult',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_RIFAMPICIN_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_TB_REGIMEN_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001c',
    'paediatric',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_RIFAMPICIN_PAEDIATRIC_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_TB_REGIMEN_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001d',
    'adult',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_ISONIAZID_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_TB_REGIMEN_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001d',
    'paediatric',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_ISONIAZID_PAEDIATRIC_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_TB_REGIMEN_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001e',
    'adult',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_PYRAZINAMIDE_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_INITIAL_PHASE_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001e',
    'paediatric',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_PYRAZINAMIDE_PAEDIATRIC_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_INITIAL_PHASE_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001f',
    'adult',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_ETHAMBUTOL_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_INITIAL_PHASE_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-00000000001f',
    'paediatric',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_ETHAMBUTOL_PAEDIATRIC_WEIGHT_BAND_DOSE',
    'VERIFY_DAILY_FREQUENCY',
    'VERIFY_INITIAL_PHASE_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000020',
    'adult',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_PYRIDOXINE_DOSE_FOR_TB_RISK_GROUP',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
),

(
    'f1600000-0000-0000-0000-000000000020',
    'paediatric',
    'TUBERCULOSIS',
    'oral',
    'VERIFY_PAEDIATRIC_PYRIDOXINE_DOSE',
    'VERIFY_FREQUENCY',
    'VERIFY_DURATION',
    false
)

  ON CONFLICT DO NOTHING;



-- ============================================================================
-- 3. MEDICATION ↔ CONDITION RELATIONSHIPS
-- ============================================================================
--
-- role vocabulary:
--
--   treatment
--   symptomatic
--   reliever
--   controller
--   exacerbation
--   disease_modifying
--   supportive
--   prophylactic
--
-- ============================================================================

INSERT INTO knowledge.medication_condition (
    medication_id,
    condition_id,
    role,
    weight
) VALUES

-- ============================================================================
-- PNEUMONIA
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    'treatment',
    1.0
),

(
    'f1600000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000001',
    'treatment',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000001',
    'treatment',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000004',
    'f1000000-0000-0000-0000-000000000001',
    'treatment',
    0.7
),

(
    'f1600000-0000-0000-0000-000000000005',
    'f1000000-0000-0000-0000-000000000001',
    'symptomatic',
    1.0
),


-- ============================================================================
-- ASTHMA
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000006',
    'f1000000-0000-0000-0000-000000000004',
    'reliever',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000007',
    'f1000000-0000-0000-0000-000000000004',
    'exacerbation',
    0.8
),

(
    'f1600000-0000-0000-0000-000000000008',
    'f1000000-0000-0000-0000-000000000004',
    'controller',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000009',
    'f1000000-0000-0000-0000-000000000004',
    'controller',
    0.8
),

(
    'f1600000-0000-0000-0000-00000000000a',
    'f1000000-0000-0000-0000-000000000004',
    'exacerbation',
    0.9
),

(
    'f1600000-0000-0000-0000-00000000000b',
    'f1000000-0000-0000-0000-000000000004',
    'exacerbation',
    0.7
),

(
    'f1600000-0000-0000-0000-00000000000c',
    'f1000000-0000-0000-0000-000000000004',
    'controller',
    1.0
),

(
    'f1600000-0000-0000-0000-00000000000d',
    'f1000000-0000-0000-0000-000000000004',
    'controller',
    0.7
),


-- ============================================================================
-- HEART FAILURE
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000000e',
    'f1000000-0000-0000-0000-000000000005',
    'symptomatic',
    1.0
),

(
    'f1600000-0000-0000-0000-00000000000f',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000010',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    1.0
),

(
    'f1600000-0000-0000-0000-000000000011',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000012',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000013',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000014',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000015',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000016',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.9
),

(
    'f1600000-0000-0000-0000-000000000017',
    'f1000000-0000-0000-0000-000000000005',
    'disease_modifying',
    0.5
),


-- ============================================================================
-- GERD
-- ============================================================================

(
    'f1600000-0000-0000-0000-000000000018',
    'f1000000-0000-0000-0000-000000000006',
    'treatment',
    1.0
),

(
    'f1600000-0000-0000-0000-000000000019',
    'f1000000-0000-0000-0000-000000000006',
    'treatment',
    0.9
),

(
    'f1600000-0000-0000-0000-00000000001a',
    'f1000000-0000-0000-0000-000000000006',
    'treatment',
    0.6
),

(
    'f1600000-0000-0000-0000-00000000001b',
    'f1000000-0000-0000-0000-000000000006',
    'symptomatic',
    0.5
),


-- ============================================================================
-- TUBERCULOSIS
-- ============================================================================

(
    'f1600000-0000-0000-0000-00000000001c',
    'f1000000-0000-0000-0000-000000000002',
    'treatment',
    1.0
),

(
    'f1600000-0000-0000-0000-00000000001d',
    'f1000000-0000-0000-0000-000000000002',
    'treatment',
    1.0
),

(
    'f1600000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-000000000002',
    'treatment',
    1.0
),

(
    'f1600000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-000000000002',
    'treatment',
    1.0
),

(
    'f1600000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000002',
    'supportive',
    0.8
)

  ON CONFLICT DO NOTHING;



-- ============================================================================
-- 4. GENERALIZED MEDICATION RELATIONSHIP EDGES
-- ============================================================================
--
-- These allow the CPU to traverse medication knowledge without making
-- disease-specific medication objects.
-- ============================================================================

INSERT INTO knowledge.relationship (
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
) VALUES

-- Asthma
(
    'medication',
    'f1600000-0000-0000-0000-000000000006',
    'relieves',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000005',
    0.9,
    'positive',
    0.95,
    'Bronchodilator reliever therapy targets variable airflow obstruction'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000008',
    'controls',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000005',
    0.9,
    'positive',
    0.95,
    'ICS reduces airway inflammation'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000000c',
    'controls',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000005',
    1.0,
    'positive',
    0.95,
    'ICS-formoterol addresses airway inflammation and bronchoconstriction'
),

-- Heart failure
(
    'medication',
    'f1600000-0000-0000-0000-00000000000e',
    'reduces',
    'phenotype',
    'f0f00000-0000-0000-0000-000000000006',
    1.0,
    'positive',
    0.95,
    'Loop diuretic reduces fluid congestion'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000010',
    'modifies',
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    1.0,
    'positive',
    0.95,
    'ARNI is guideline-directed heart-failure therapy in appropriate patients'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000015',
    'modifies',
    'condition',
    'f1000000-0000-0000-0000-000000000005',
    0.9,
    'positive',
    0.95,
    'SGLT2 inhibitor is part of modern heart-failure guideline-directed therapy'
),

-- GERD
(
    'medication',
    'f1600000-0000-0000-0000-000000000018',
    'treats',
    'condition',
    'f1000000-0000-0000-0000-000000000006',
    1.0,
    'positive',
    0.95,
    'PPI suppresses gastric acid secretion'
),

-- TB
(
    'medication',
    'f1600000-0000-0000-0000-00000000001c',
    'treats',
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.98,
    'Rifampicin is a core antituberculosis medicine'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000001d',
    'treats',
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.98,
    'Isoniazid is a core antituberculosis medicine'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000001e',
    'treats',
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.98,
    'Pyrazinamide is a core antituberculosis medicine'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000001f',
    'treats',
    'condition',
    'f1000000-0000-0000-0000-000000000002',
    1.0,
    'positive',
    0.98,
    'Ethambutol is a core antituberculosis medicine'
)

  ON CONFLICT DO NOTHING;



-- ============================================================================
-- 5. MEDICATION CLASS / FUNCTION RELATIONSHIPS
-- ============================================================================
--
-- This makes the medication library useful even before a specific disease
-- has been selected.
-- ============================================================================

INSERT INTO knowledge.relationship (
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
) VALUES

(
    'medication',
    'f1600000-0000-0000-0000-000000000006',
    'is_reliever_for',
    'symptom',
    'f0b00000-0000-0000-0000-000000000003',
    0.8,
    'positive',
    0.9,
    'Salbutamol relieves bronchospasm-related breathlessness'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000006',
    'is_reliever_for',
    'symptom',
    'f0b00000-0000-0000-0000-000000000001',
    0.6,
    'positive',
    0.8,
    'Bronchodilation may reduce cough associated with bronchospasm'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000000e',
    'reduces',
    'symptom',
    'f0b00000-0000-0000-0000-000000000003',
    0.9,
    'positive',
    0.95,
    'Reduction of congestion improves dyspnoea in appropriate heart failure'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000018',
    'reduces',
    'symptom',
    'f0b00000-0000-0000-0000-000000000001',
    0.7,
    'positive',
    0.9,
    'Acid suppression may improve reflux-associated cough when reflux is causal'
)

  ON CONFLICT DO NOTHING;



-- ============================================================================
-- 6. SAFETY-CRITICAL MEDICATION FACTS
-- ============================================================================
--
-- These relationships allow the CPU to know that certain medications require
-- additional safety checks.
--
-- The actual allergy / renal / pregnancy / interaction engine should evaluate
-- patient facts rather than hard-code these decisions in UI code.
-- ============================================================================

-- Safety-check facts referenced by the relationships below
INSERT INTO knowledge.concept
(
    id,
    concept_code,
    concept_type,
    canonical_name,
    display_name,
    description
)
VALUES
(
    'f0a00000-0000-0000-0000-000000000080',
    'DRUG_HYPERSENSITIVITY',
    'fact',
    'Drug hypersensitivity',
    'Drug hypersensitivity',
    'Known or suspected hypersensitivity to a medication requiring pre-administration assessment.'
),
(
    'f0a00000-0000-0000-0000-000000000081',
    'f0a00000-0000-0000-0000-000000000081',
    'fact',
    'Renal function',
    'Renal function',
    'Patient renal function relevant to medication dosing and monitoring.'
),
(
    'f0a00000-0000-0000-0000-000000000082',
    'f0a00000-0000-0000-0000-000000000082',
    'fact',
    'Serum potassium',
    'Serum potassium',
    'Serum potassium level relevant to medication safety monitoring.'
),
(
    'f0a00000-0000-0000-0000-000000000083',
    'f0a00000-0000-0000-0000-000000000083',
    'fact',
    'Pregnancy status',
    'Pregnancy status',
    'Pregnancy status relevant to medication contraindications.'
),
(
    'f0a00000-0000-0000-0000-000000000084',
    'f0a00000-0000-0000-0000-000000000084',
    'fact',
    'QT prolongation risk',
    'QT prolongation risk',
    'Risk of QT prolongation relevant to medication selection.'
),
(
    'f0a00000-0000-0000-0000-000000000085',
    'f0a00000-0000-0000-0000-000000000085',
    'fact',
    'Hepatic function',
    'Hepatic function',
    'Patient hepatic function relevant to medication dosing and monitoring.'
),
(
    'f0a00000-0000-0000-0000-000000000086',
    'f0a00000-0000-0000-0000-000000000086',
    'fact',
    'Visual function',
    'Visual function',
    'Visual function assessment relevant to medication safety monitoring.'
)
ON CONFLICT DO NOTHING;

INSERT INTO knowledge.relationship (
    source_type,
    source_id,
    relationship_type,
    target_type,
    target_id,
    weight,
    polarity,
    confidence,
    evidence
) VALUES

-- Beta-lactam allergy
(
    'medication',
    'f1600000-0000-0000-0000-000000000001',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000080',
    1.0,
    'positive',
    1.0,
    'Beta-lactam hypersensitivity must be checked before administration'
),

-- Renal function
(
    'medication',
    'f1600000-0000-0000-0000-000000000001',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000081',
    0.8,
    'positive',
    0.95,
    'Renal function may affect beta-lactam dosing'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000000e',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000081',
    1.0,
    'positive',
    0.98,
    'Renal function affects loop-diuretic management and monitoring'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000014',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000082',
    1.0,
    'positive',
    1.0,
    'MRA therapy requires potassium monitoring'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000014',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000081',
    1.0,
    'positive',
    1.0,
    'MRA therapy requires renal-function assessment'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000015',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000081',
    1.0,
    'positive',
    0.98,
    'SGLT2 inhibitor use requires renal-function assessment'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000000f',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000082',
    1.0,
    'positive',
    1.0,
    'ACE inhibitor therapy requires potassium monitoring'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000000f',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000081',
    1.0,
    'positive',
    1.0,
    'ACE inhibitor therapy requires renal-function monitoring'
),

-- Pregnancy
(
    'medication',
    'f1600000-0000-0000-0000-00000000000f',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000083',
    1.0,
    'positive',
    1.0,
    'ACE inhibitor therapy is contraindicated in pregnancy'
),

(
    'medication',
    'f1600000-0000-0000-0000-000000000010',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000083',
    1.0,
    'positive',
    1.0,
    'ARNI therapy is contraindicated in pregnancy'
),

-- QT
(
    'medication',
    'f1600000-0000-0000-0000-000000000004',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000084',
    1.0,
    'positive',
    0.95,
    'Macrolide therapy requires QT-risk assessment in appropriate patients'
),

-- TB liver monitoring
(
    'medication',
    'f1600000-0000-0000-0000-00000000001c',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000085',
    1.0,
    'positive',
    0.98,
    'Rifampicin has important hepatic and drug-interaction considerations'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000001d',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000085',
    1.0,
    'positive',
    1.0,
    'Isoniazid has important hepatotoxicity considerations'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000001e',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000085',
    1.0,
    'positive',
    1.0,
    'Pyrazinamide has important hepatotoxicity considerations'
),

(
    'medication',
    'f1600000-0000-0000-0000-00000000001f',
    'requires_check',
    'fact',
    'f0a00000-0000-0000-0000-000000000086',
    1.0,
    'positive',
    1.0,
    'Ethambutol requires appropriate visual assessment and monitoring'
)

  ON CONFLICT DO NOTHING;



-- ============================================================================
-- 7. DOSE-ENGINE SAFETY RULE
-- ============================================================================
--
-- The application/CPU should implement the following invariant:
--
--     is_verified = TRUE
--          AND
--     jurisdiction is compatible
--          AND
--     guideline version is current
--          AND
--     patient population matches
--          AND
--     route is valid
--          AND
--     safety checks pass
--          AND
--     protocol permits medication
--
-- only then:
--
--     medication -> executable order
--
-- Otherwise:
--
--     medication -> knowledge/reference only
--
-- This is intentionally represented in the knowledge architecture rather than
-- allowing UI code to decide whether a medication is safe.
-- ============================================================================



-- ============================================================================
-- 8. VERIFICATION METADATA PLACEHOLDER
-- ============================================================================
--
-- DO NOT change is_verified to TRUE merely because a clinician recognizes the
-- dose. Verification must be tied to an approved source and jurisdiction.
--
-- Examples of authoritative source families:
--
--   WHO TB consolidated guidelines
--   WHO operational TB handbook
--   GINA asthma strategy
--   national asthma guideline
--   ACC/AHA/HFSA heart-failure guideline
--   national/local formulary
--   facility-approved antimicrobial guideline
--   product SmPC / regulatory source where appropriate
--
-- WHO's current consolidated TB treatment guidance was published in 2025 and
-- covers drug-susceptible and drug-resistant TB treatment and care.
--
-- GINA's current 2025 materials explicitly contain updated medication guidance.
--
-- Heart-failure guideline-directed medical therapy includes four major
-- medication classes for HFrEF, including SGLT2 inhibitors.
-- ============================================================================


-- ============================================================================
-- END ZP6
-- ============================================================================