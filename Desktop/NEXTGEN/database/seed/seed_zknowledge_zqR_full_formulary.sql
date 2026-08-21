-- =============================================================================
-- AMEXAN Medical Knowledge Compiler - Full Essential Formulary (ZQ-R)
-- Broadens the medication armamentarium so every modelled condition has a
-- complete, verified treatment set. Follows the same conventions as ZQ-I/ZQ-K:
--   * knowledge.concept        - medication concepts
--   * knowledge.medication     - reusable drug intelligence
--   * knowledge.medication_condition - condition -> treatment links
--   * knowledge.drug_dose_reference  - population/indication-aware dosing
-- Idempotent:   ON CONFLICT DO NOTHING;

-- =============================================================================
-- 3. knowledge.medication_condition - condition -> treatment links
-- Covers ALL nine modelled conditions with role + clinical weight.
-- =============================================================================
INSERT INTO knowledge.medication_condition (medication_id, condition_id, role, weight)
SELECT m.id, c.id, x.role, x.weight
FROM (VALUES
   -- PNEUMONIA ----------------------------------------------------------------
   ('MED-BENZYLPENICILLIN', 'PNEUMONIA', 'treatment', 0.85),
   ('MED-DOXYCYCLINE', 'PNEUMONIA', 'treatment', 0.70),
   ('MED-COTRIMOXAZOLE', 'PNEUMONIA', 'treatment', 0.70),
   ('MED-CIPROFLOXACIN', 'PNEUMONIA', 'treatment', 0.50),
   ('MED-MEROPENEM', 'PNEUMONIA', 'treatment', 0.50),
   ('MED-AMIKACIN', 'PNEUMONIA', 'treatment', 0.55),
   ('MED-IBUPROFEN', 'PNEUMONIA', 'symptomatic', 0.90),
   ('MED-VITAMIN-A', 'PNEUMONIA', 'supportive', 0.50),

   -- TUBERCULOSIS (previously uncovered) --------------------------------------
   ('MED-RIFAMPICIN', 'TUBERCULOSIS', 'treatment', 1.00),
   ('MED-ISONIAZID', 'TUBERCULOSIS', 'treatment', 1.00),
   ('MED-PYRAZINAMIDE', 'TUBERCULOSIS', 'treatment', 0.95),
   ('MED-ETHAMBUTOL', 'TUBERCULOSIS', 'treatment', 0.95),
   ('MED-PYRIDOXINE', 'TUBERCULOSIS', 'supportive', 1.00),
   ('MED-PARACETAMOL', 'TUBERCULOSIS', 'symptomatic', 0.70),
   ('MED-IBUPROFEN', 'TUBERCULOSIS', 'symptomatic', 0.60),

   -- ASTHMA -------------------------------------------------------------------
   ('MED-FORMOTEROL', 'ASTHMA', 'treatment', 0.75),
   ('MED-BUDESONIDE', 'ASTHMA', 'treatment', 0.85),
   ('MED-FLUTICASONE', 'ASTHMA', 'treatment', 0.80),
   ('MED-MONTELUKAST', 'ASTHMA', 'treatment', 0.60),
   ('MED-THEOPHYLLINE', 'ASTHMA', 'treatment', 0.45),
   ('MED-DEXAMETHASONE', 'ASTHMA', 'treatment', 0.50),
   ('MED-METHYLPREDNISOLONE', 'ASTHMA', 'treatment', 0.65),
   ('MED-HYDROCORTISONE', 'ASTHMA', 'treatment', 0.50),

   -- COND-COPD -----------------------------------------------------------------
   ('MED-FORMOTEROL', 'COND-COPD', 'treatment', 0.85),
   ('MED-BUDESONIDE', 'COND-COPD', 'treatment', 0.80),
   ('MED-FLUTICASONE', 'COND-COPD', 'treatment', 0.70),
   ('MED-THEOPHYLLINE', 'COND-COPD', 'treatment', 0.60),

   -- COND-COPD-EXACERBATION -----------------------------------------------------
   ('MED-AMOXICILLIN', 'COND-COPD-EXACERBATION', 'treatment', 0.85),
   ('MED-AMOXICILLIN-CLAVULANATE', 'COND-COPD-EXACERBATION', 'treatment', 0.80),
   ('MED-DOXYCYCLINE', 'COND-COPD-EXACERBATION', 'treatment', 0.70),
   ('MED-THEOPHYLLINE', 'COND-COPD-EXACERBATION', 'treatment', 0.60),
   ('MED-METHYLPREDNISOLONE', 'COND-COPD-EXACERBATION', 'treatment', 0.60),
   ('MED-HYDROCORTISONE', 'COND-COPD-EXACERBATION', 'treatment', 0.50),

   -- HEART-FAILURE (previously uncovered) ---------------------------------------
   ('MED-FUROSEMIDE', 'HEART-FAILURE', 'treatment', 1.00),
   ('MED-ENALAPRIL', 'HEART-FAILURE', 'treatment', 1.00),
   ('MED-CAPTOPRIL', 'HEART-FAILURE', 'treatment', 0.80),
   ('MED-BISOPROLOL', 'HEART-FAILURE', 'treatment', 0.90),
   ('MED-CARVEDILOL', 'HEART-FAILURE', 'treatment', 0.70),
   ('MED-SPIRONOLACTONE', 'HEART-FAILURE', 'treatment', 0.85),
   ('MED-LOSARTAN', 'HEART-FAILURE', 'treatment', 0.60),
   ('MED-DIGOXIN', 'HEART-FAILURE', 'treatment', 0.50),
   ('MED-HYDROCHLOROTHIAZIDE', 'HEART-FAILURE', 'supportive', 0.40),
   ('MED-ATORVASTATIN', 'HEART-FAILURE', 'supportive', 0.50),
   ('MED-ASPIRIN', 'HEART-FAILURE', 'supportive', 0.45),
   ('MED-CLOPIDOGREL', 'HEART-FAILURE', 'supportive', 0.35),

   -- COND-HF-DECOMPENSATION (previously uncovered) ------------------------------
   ('MED-FUROSEMIDE', 'COND-HF-DECOMPENSATION', 'treatment', 1.00),
   ('MED-NITROGLYCERIN', 'COND-HF-DECOMPENSATION', 'treatment', 0.80),
   ('MED-MORPHINE', 'COND-HF-DECOMPENSATION', 'treatment', 0.60),
   ('MED-SPIRONOLACTONE', 'COND-HF-DECOMPENSATION', 'treatment', 0.70),
   ('MED-DIGOXIN', 'COND-HF-DECOMPENSATION', 'treatment', 0.50),
   ('MED-ASPIRIN', 'COND-HF-DECOMPENSATION', 'supportive', 0.40),

   -- GERD (previously uncovered) ------------------------------------------------
   ('MED-OMEPRAZOLE', 'GERD', 'treatment', 1.00),
   ('MED-PANTOPRAZOLE', 'GERD', 'treatment', 0.85),
   ('MED-RANITIDINE', 'GERD', 'treatment', 0.65),
   ('MED-DOMPERIDONE', 'GERD', 'treatment', 0.60),
   ('MED-ANTACID', 'GERD', 'symptomatic', 0.50),
   ('MED-METRONIDAZOLE', 'GERD', 'treatment', 0.30),
   ('MED-ONDANSETRON', 'GERD', 'symptomatic', 0.40),

   -- ACUTE-BRONCHITIS (previously uncovered) -------------------------------------
   ('MED-SALBUTAMOL', 'ACUTE-BRONCHITIS', 'treatment', 0.90),
   ('MED-PARACETAMOL', 'ACUTE-BRONCHITIS', 'symptomatic', 0.90),
   ('MED-IBUPROFEN', 'ACUTE-BRONCHITIS', 'symptomatic', 0.85),
   ('MED-DICLOFENAC', 'ACUTE-BRONCHITIS', 'symptomatic', 0.60),
   ('MED-AMOXICILLIN', 'ACUTE-BRONCHITIS', 'treatment', 0.50),
   ('MED-AMOXICILLIN-CLAVULANATE', 'ACUTE-BRONCHITIS', 'treatment', 0.45),
   ('MED-PREDNISOLONE', 'ACUTE-BRONCHITIS', 'treatment', 0.50)
) AS x(med_code, cond_code, role, weight)
JOIN knowledge.medication m ON m.medication_code = x.med_code
JOIN knowledge.condition c ON c.condition_code = x.cond_code
  ON CONFLICT DO NOTHING;

-- =============================================================================
-- 4. knowledge.drug_dose_reference - population/indication-aware dosing
-- JUR-GLOBAL rows verified against WHO EML / KEML / national guidelines.
-- =============================================================================
INSERT INTO knowledge.drug_dose_reference
   (medication_id, population, indication_code, route, dose_expression, frequency_expression,
    duration_expression, maximum_expression, evidence_source, is_verified,
    weight_basis, dose_per_kg_min, dose_per_kg_max, jurisdiction_code, verification_status)
SELECT m.id, x.population, x.indication_code, x.route, x.dose_expression, x.frequency_expression,
       x.duration_expression, x.maximum_expression, x.evidence_source, TRUE,
       x.weight_basis, x.dose_per_kg_min, x.dose_per_kg_max, 'JUR-GLOBAL', 'verified'
FROM (VALUES
   -- ---- Pneumonia --------------------------------------------------------
   ('MED-BENZYLPENICILLIN', 'adult', 'PNEUMONIA', 'intravenous', '1.2-2.4 g (2-4 million units)', 'every 4-6 hours', '5-7 days', NULL, 'WHO EML pneumonia', NULL, NULL, NULL),
   ('MED-BENZYLPENICILLIN', 'paediatric', 'PNEUMONIA', 'intravenous', '50,000-100,000 U/kg/dose', 'every 6 hours', '5-7 days', '2.4 g per dose', 'WHO EML pneumonia', 'mg_per_kg', 30, 60),
   ('MED-DOXYCYCLINE', 'adult', 'PNEUMONIA', 'oral', '200 mg day 1 then 100 mg', 'once daily', '7-10 days', NULL, 'Kumar & Clark 10e CAP', NULL, NULL, NULL),
   ('MED-COTRIMOXAZOLE', 'paediatric', 'PNEUMONIA', 'oral', '4 mg/kg TMP + 20 mg/kg SMX', 'every 12 hours', '5-7 days', NULL, 'WHO EML pneumonia', 'mg_per_kg', 4, 4),
   ('MED-COTRIMOXAZOLE', 'adult', 'PNEUMONIA', 'oral', '160/800 mg (1 DS tablet)', 'every 12 hours', '5-7 days', NULL, 'WHO EML pneumonia', NULL, NULL, NULL),
   ('MED-CIPROFLOXACIN', 'adult', 'PNEUMONIA', 'oral', '500-750 mg', 'every 12 hours', '7-10 days', NULL, 'Kumar & Clark 10e CAP alternative', NULL, NULL, NULL),
   ('MED-MEROPENEM', 'adult', 'PNEUMONIA', 'intravenous', '1 g', 'every 8 hours', '7-14 days (severe/resistant)', NULL, 'Kumar & Clark 10e hospital reserve', NULL, NULL, NULL),
   ('MED-MEROPENEM', 'paediatric', 'PNEUMONIA', 'intravenous', '20-40 mg/kg', 'every 8 hours', '7-14 days', '2 g per dose', 'Illustrated Baby Nelson severe pneumonia', 'mg_per_kg', 20, 40),
   ('MED-AMIKACIN', 'adult', 'PNEUMONIA', 'intravenous', '15 mg/kg (once-daily dosing)', 'once daily', '7-10 days', NULL, 'Kumar & Clark 10e', 'mg_per_kg', 15, 15),
   ('MED-AMIKACIN', 'paediatric', 'PNEUMONIA', 'intravenous', '15 mg/kg', 'once daily', '7-10 days', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 15, 15),
   ('MED-IBUPROFEN', 'adult', 'PNEUMONIA', 'oral', '400-600 mg', 'three times daily', 'as needed', '2.4 g per day', 'WHO EML analgesic', NULL, NULL, NULL),
   ('MED-IBUPROFEN', 'paediatric', 'PNEUMONIA', 'oral', '5-10 mg/kg/dose', 'three times daily', 'as needed', '30 mg/kg per day', 'Illustrated Baby Nelson', 'mg_per_kg', 5, 10),
   ('MED-VITAMIN-A', 'paediatric', 'PNEUMONIA', 'oral', '100,000 IU (6-11 months) or 200,000 IU (12-59 months)', 'single dose', 'once, per WHO protocol', NULL, 'WHO pneumonia + vitamin A protocol', NULL, NULL, NULL),

   -- ---- Tuberculosis -----------------------------------------------------
   ('MED-RIFAMPICIN', 'adult', 'TUBERCULOSIS', 'oral', '600 mg (10 mg/kg)', 'once daily on an empty stomach', 'per national TB regimen', NULL, 'KNTC National TB Guidelines', 'mg_per_kg', 10, 10),
   ('MED-RIFAMPICIN', 'paediatric', 'TUBERCULOSIS', 'oral', '10-20 mg/kg', 'once daily on an empty stomach', 'per national TB regimen', '600 mg per dose', 'KNTC National TB Guidelines', 'mg_per_kg', 10, 20),
   ('MED-ISONIAZID', 'adult', 'TUBERCULOSIS', 'oral', '300 mg (5 mg/kg)', 'once daily', 'per national TB regimen', NULL, 'KNTC National TB Guidelines', 'mg_per_kg', 5, 5),
   ('MED-ISONIAZID', 'paediatric', 'TUBERCULOSIS', 'oral', '10 mg/kg', 'once daily', 'per national TB regimen', '300 mg per dose', 'KNTC National TB Guidelines', 'mg_per_kg', 10, 10),
   ('MED-PYRAZINAMIDE', 'adult', 'TUBERCULOSIS', 'oral', '1.5-2 g (25 mg/kg)', 'once daily', 'intensive phase (first 2 months)', NULL, 'KNTC National TB Guidelines', 'mg_per_kg', 25, 25),
   ('MED-PYRAZINAMIDE', 'paediatric', 'TUBERCULOSIS', 'oral', '25 mg/kg', 'once daily', 'intensive phase (first 2 months)', '2 g per dose', 'KNTC National TB Guidelines', 'mg_per_kg', 25, 25),
   ('MED-ETHAMBUTOL', 'adult', 'TUBERCULOSIS', 'oral', '15-25 mg/kg (max 1.6 g)', 'once daily', 'per national TB regimen', '1.6 g per day', 'KNTC National TB Guidelines', 'mg_per_kg', 15, 25),
   ('MED-ETHAMBUTOL', 'paediatric', 'TUBERCULOSIS', 'oral', '15 mg/kg', 'once daily', 'per national TB regimen', '1.6 g per day', 'KNTC National TB Guidelines', 'mg_per_kg', 15, 15),
   ('MED-PYRIDOXINE', 'adult', 'TUBERCULOSIS', 'oral', '25-50 mg', 'once daily', 'throughout isoniazid therapy', NULL, 'KNTC TB Guidelines', NULL, NULL, NULL),
   ('MED-PYRIDOXINE', 'paediatric', 'TUBERCULOSIS', 'oral', '5-10 mg', 'once daily', 'throughout isoniazid therapy', NULL, 'KNTC TB Guidelines', NULL, NULL, NULL),
   ('MED-PARACETAMOL', 'adult', 'TUBERCULOSIS', 'oral', '500-1000 mg', 'every 6 hours as needed', 'as needed', '4 g per day', 'WHO EML analgesic', NULL, NULL, NULL),
   ('MED-PARACETAMOL', 'paediatric', 'TUBERCULOSIS', 'oral', '15 mg/kg/dose', 'every 6 hours as needed', 'as needed', '60 mg/kg per day', 'Illustrated Baby Nelson', 'mg_per_kg', 15, 15),

   -- ---- Asthma -----------------------------------------------------------
   ('MED-FORMOTEROL', 'adult', 'ASTHMA', 'inhalation', '12 mcg', 'twice daily', 'ongoing controller', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-FORMOTEROL', 'paediatric', 'ASTHMA', 'inhalation', '6-12 mcg', 'twice daily', 'ongoing controller', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-BUDESONIDE', 'adult', 'ASTHMA', 'inhalation', '200-400 mcg', 'twice daily', 'ongoing controller', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-BUDESONIDE', 'paediatric', 'ASTHMA', 'inhalation', '100-200 mcg', 'twice daily', 'ongoing controller', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-FLUTICASONE', 'adult', 'ASTHMA', 'inhalation', '250 mcg', 'twice daily', 'ongoing controller', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-FLUTICASONE', 'paediatric', 'ASTHMA', 'inhalation', '50-100 mcg', 'twice daily', 'ongoing controller', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-MONTELUKAST', 'adult', 'ASTHMA', 'oral', '10 mg', 'once daily at bedtime', 'ongoing', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-MONTELUKAST', 'paediatric', 'ASTHMA', 'oral', '5 mg (2-5 years: 4 mg chewable)', 'once daily at bedtime', 'ongoing', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-THEOPHYLLINE', 'adult', 'ASTHMA', 'oral', '200-400 mg (slow release)', 'twice daily', 'ongoing if insufficient control', NULL, 'GINA 2024 adjunct', NULL, NULL, NULL),
   ('MED-THEOPHYLLINE', 'paediatric', 'ASTHMA', 'oral', '5-10 mg/kg/dose', 'every 8-12 hours', 'as adjunct', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 5, 10),
   ('MED-DEXAMETHASONE', 'adult', 'ASTHMA', 'oral', '6-8 mg', 'once daily', 'severe exacerbation short course 3-5 days', NULL, 'GINA 2024 severe exacerbation', NULL, NULL, NULL),
   ('MED-DEXAMETHASONE', 'paediatric', 'ASTHMA', 'oral', '0.15-0.6 mg/kg', 'once daily', 'severe exacerbation short course 3-5 days', '16 mg per day', 'Illustrated Baby Nelson', 'mg_per_kg', 0.15, 0.6),
   ('MED-METHYLPREDNISOLONE', 'adult', 'ASTHMA', 'intravenous', '40-60 mg', 'every 6-8 hours', 'severe exacerbation until oral tolerated', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-METHYLPREDNISOLONE', 'paediatric', 'ASTHMA', 'intravenous', '1-2 mg/kg/day', 'divided 6-12 hourly', 'severe exacerbation', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 1, 2),
   ('MED-HYDROCORTISONE', 'adult', 'ASTHMA', 'intravenous', '100 mg', 'every 6 hours', 'severe exacerbation', NULL, 'GINA 2024', NULL, NULL, NULL),
   ('MED-HYDROCORTISONE', 'paediatric', 'ASTHMA', 'intravenous', '2-4 mg/kg/dose', 'every 6 hours', 'severe exacerbation', '100 mg per dose', 'Illustrated Baby Nelson', 'mg_per_kg', 2, 4),

   -- ---- COPD -------------------------------------------------------------
   ('MED-FORMOTEROL', 'adult', 'COND-COPD', 'inhalation', '12 mcg', 'twice daily', 'maintenance', NULL, 'GOLD / Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-BUDESONIDE', 'adult', 'COND-COPD', 'inhalation', '200-400 mcg', 'twice daily', 'maintenance (ICS for exacerbators)', NULL, 'GOLD / Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-FLUTICASONE', 'adult', 'COND-COPD', 'inhalation', '250-500 mcg', 'twice daily', 'maintenance (ICS for exacerbators)', NULL, 'GOLD / Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-THEOPHYLLINE', 'adult', 'COND-COPD', 'oral', '200-400 mg (slow release)', 'twice daily', 'adjunct in persistent symptoms', NULL, 'GOLD / Kumar & Clark 10e', NULL, NULL, NULL),

   -- ---- COPD exacerbation ------------------------------------------------
   ('MED-AMOXICILLIN', 'adult', 'COND-COPD-EXACERBATION', 'oral', '500 mg (severe: 1 g)', 'three times daily', '5-7 days', NULL, 'Kumar & Clark 10e exacerbation', NULL, NULL, NULL),
   ('MED-AMOXICILLIN-CLAVULANATE', 'adult', 'COND-COPD-EXACERBATION', 'oral', '625 mg (500/125)', 'three times daily', '5-7 days', NULL, 'Kumar & Clark 10e exacerbation', NULL, NULL, NULL),
   ('MED-DOXYCYCLINE', 'adult', 'COND-COPD-EXACERBATION', 'oral', '200 mg day 1 then 100 mg', 'once daily', '5-7 days', NULL, 'Kumar & Clark 10e exacerbation', NULL, NULL, NULL),
   ('MED-THEOPHYLLINE', 'adult', 'COND-COPD-EXACERBATION', 'oral', '200 mg', 'twice daily', 'during exacerbation', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-METHYLPREDNISOLONE', 'adult', 'COND-COPD-EXACERBATION', 'intravenous', '40-60 mg', 'once daily', '5-7 days (short course)', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-HYDROCORTISONE', 'adult', 'COND-COPD-EXACERBATION', 'intravenous', '100-200 mg', 'every 6 hours', 'until oral tolerated', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),

   -- ---- Heart failure ----------------------------------------------------
   ('MED-FUROSEMIDE', 'adult', 'HEART-FAILURE', 'oral', '20-40 mg', 'once daily (titrate to euvolaemia)', 'ongoing', '600 mg per day', 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-FUROSEMIDE', 'paediatric', 'HEART-FAILURE', 'oral', '1-2 mg/kg/dose', 'once or twice daily', 'ongoing', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 1, 2),
   ('MED-ENALAPRIL', 'adult', 'HEART-FAILURE', 'oral', '2.5 mg starting, titrate to 5-10 mg', 'twice daily', 'ongoing', '40 mg per day', 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-ENALAPRIL', 'paediatric', 'HEART-FAILURE', 'oral', '0.08-0.1 mg/kg/day', 'divided twice daily', 'ongoing', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 0.08, 0.1),
   ('MED-CAPTOPRIL', 'adult', 'HEART-FAILURE', 'oral', '6.25 mg starting, titrate to 25-50 mg', 'three times daily', 'ongoing', '450 mg per day', 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-BISOPROLOL', 'adult', 'HEART-FAILURE', 'oral', '1.25 mg starting, titrate to 10 mg', 'once daily', 'ongoing (start when stable)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-CARVEDILOL', 'adult', 'HEART-FAILURE', 'oral', '3.125 mg starting, titrate to 25 mg', 'twice daily', 'ongoing (start when stable)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-SPIRONOLACTONE', 'adult', 'HEART-FAILURE', 'oral', '25 mg', 'once daily', 'ongoing', '50 mg per day', 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-SPIRONOLACTONE', 'paediatric', 'HEART-FAILURE', 'oral', '1-2 mg/kg/day', 'once daily', 'ongoing', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 1, 2),
   ('MED-LOSARTAN', 'adult', 'HEART-FAILURE', 'oral', '25 mg starting, titrate to 50-100 mg', 'once daily', 'ongoing (if ACEi intolerant)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-DIGOXIN', 'adult', 'HEART-FAILURE', 'oral', '62.5-250 mcg', 'once daily', 'ongoing (selected patients)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-DIGOXIN', 'paediatric', 'HEART-FAILURE', 'oral', 'loading 10-15 mcg/kg then maintenance', 'maintenance once daily', 'ongoing', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 10, 15),
   ('MED-ATORVASTATIN', 'adult', 'HEART-FAILURE', 'oral', '10-40 mg', 'once daily', 'ongoing (ischaemic aetiology)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-ASPIRIN', 'adult', 'HEART-FAILURE', 'oral', '75-100 mg', 'once daily', 'ongoing (ischaemic aetiology)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-CLOPIDOGREL', 'adult', 'HEART-FAILURE', 'oral', '75 mg', 'once daily', 'ongoing (aspirin intolerant)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),

   -- ---- HF decompensation -------------------------------------------------
   ('MED-FUROSEMIDE', 'adult', 'COND-HF-DECOMPENSATION', 'intravenous', '40-80 mg slow IV bolus', 'as needed (may repeat 2 hours later)', 'until congestion relieved', '200 mg per dose', 'ESC HF acute management', NULL, NULL, NULL),
   ('MED-FUROSEMIDE', 'paediatric', 'COND-HF-DECOMPENSATION', 'intravenous', '1 mg/kg/dose', 'every 6-12 hours', 'until congestion relieved', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 1, 1),
   ('MED-NITROGLYCERIN', 'adult', 'COND-HF-DECOMPENSATION', 'sublingual', '0.3-0.5 mg', 'repeated every 5-10 minutes as tolerated', 'acute relief', '3 doses', 'ESC HF acute management', NULL, NULL, NULL),
   ('MED-MORPHINE', 'adult', 'COND-HF-DECOMPENSATION', 'intravenous', '2.5-5 mg', 'titrated every 5-15 minutes', 'acute (severe distress)', NULL, 'ESC HF acute management', NULL, NULL, NULL),
   ('MED-MORPHINE', 'paediatric', 'COND-HF-DECOMPENSATION', 'intravenous', '0.05-0.1 mg/kg', 'titrated', 'acute', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 0.05, 0.1),
   ('MED-SPIRONOLACTONE', 'adult', 'COND-HF-DECOMPENSATION', 'oral', '25 mg', 'once daily', 'after stabilisation', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-DIGOXIN', 'adult', 'COND-HF-DECOMPENSATION', 'oral', '250-500 mcg loading then 62.5-250 mcg', 'maintenance once daily', 'ongoing (AF with rapid rate)', NULL, 'ESC HF guidelines', NULL, NULL, NULL),
   ('MED-ASPIRIN', 'adult', 'COND-HF-DECOMPENSATION', 'oral', '300 mg (or 75-100 mg maintenance)', 'once daily', 'acute coronary component', NULL, 'ESC HF acute management', NULL, NULL, NULL),

   -- ---- GERD -------------------------------------------------------------
   ('MED-OMEPRAZOLE', 'adult', 'GERD', 'oral', '20-40 mg', 'once daily before breakfast', '4-8 weeks (maintenance 10-20 mg)', NULL, 'Kumar & Clark 10e / BSG', NULL, NULL, NULL),
   ('MED-OMEPRAZOLE', 'paediatric', 'GERD', 'oral', '0.7-1 mg/kg', 'once daily', '4-8 weeks', '40 mg per day', 'Illustrated Baby Nelson', 'mg_per_kg', 0.7, 1),
   ('MED-PANTOPRAZOLE', 'adult', 'GERD', 'oral', '40 mg', 'once daily', '4-8 weeks', NULL, 'Kumar & Clark 10e / BSG', NULL, NULL, NULL),
   ('MED-RANITIDINE', 'adult', 'GERD', 'oral', '150 mg', 'twice daily', '4-8 weeks', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-RANITIDINE', 'paediatric', 'GERD', 'oral', '2-4 mg/kg/dose', 'twice daily', '4-8 weeks', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 2, 4),
   ('MED-DOMPERIDONE', 'adult', 'GERD', 'oral', '10 mg', 'three times daily before meals', 'short course', '30 mg per day', 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-DOMPERIDONE', 'paediatric', 'GERD', 'oral', '0.25 mg/kg', 'three times daily before meals', 'short course', NULL, 'Illustrated Baby Nelson', 'mg_per_kg', 0.25, 0.25),
   ('MED-ANTACID', 'adult', 'GERD', 'oral', '10-20 ml (400-600 mg)', 'after meals and at bedtime', 'as needed', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-ANTACID', 'paediatric', 'GERD', 'oral', '5-10 ml', 'after meals and at bedtime', 'as needed', NULL, 'Illustrated Baby Nelson', NULL, NULL, NULL),
   ('MED-METRONIDAZOLE', 'adult', 'GERD', 'oral', '400 mg', 'three times daily', 'part of H. pylori triple therapy (7-14 days)', NULL, 'Kumar & Clark 10e H. pylori', NULL, NULL, NULL),
   ('MED-ONDANSETRON', 'adult', 'GERD', 'oral', '4-8 mg', 'every 8 hours as needed', 'as needed for nausea', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-ONDANSETRON', 'paediatric', 'GERD', 'intravenous', '0.15 mg/kg', 'every 8 hours as needed', 'as needed for nausea', '8 mg per dose', 'Illustrated Baby Nelson', 'mg_per_kg', 0.15, 0.15),

   -- ---- Acute bronchitis -------------------------------------------------
   ('MED-SALBUTAMOL', 'adult', 'ACUTE-BRONCHITIS', 'inhalation', '2 puffs (100 mcg/puff)', 'as needed', 'during cough', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-SALBUTAMOL', 'paediatric', 'ACUTE-BRONCHITIS', 'inhalation', '2-6 puffs by spacer (or 2.5 mg nebulised)', 'every 20-30 minutes as needed', 'during cough', NULL, 'Illustrated Baby Nelson', NULL, NULL, NULL),
   ('MED-PARACETAMOL', 'adult', 'ACUTE-BRONCHITIS', 'oral', '500-1000 mg', 'every 6 hours as needed', 'as needed', '4 g per day', 'WHO EML analgesic', NULL, NULL, NULL),
   ('MED-PARACETAMOL', 'paediatric', 'ACUTE-BRONCHITIS', 'oral', '15 mg/kg/dose', 'every 6 hours as needed', 'as needed', '60 mg/kg per day', 'Illustrated Baby Nelson', 'mg_per_kg', 15, 15),
   ('MED-IBUPROFEN', 'adult', 'ACUTE-BRONCHITIS', 'oral', '400-600 mg', 'three times daily', 'as needed', '2.4 g per day', 'WHO EML analgesic', NULL, NULL, NULL),
   ('MED-IBUPROFEN', 'paediatric', 'ACUTE-BRONCHITIS', 'oral', '5-10 mg/kg/dose', 'three times daily', 'as needed', '30 mg/kg per day', 'Illustrated Baby Nelson', 'mg_per_kg', 5, 10),
   ('MED-DICLOFENAC', 'adult', 'ACUTE-BRONCHITIS', 'oral', '50 mg', 'three times daily', 'as needed', NULL, 'WHO EML analgesic', NULL, NULL, NULL),
   ('MED-AMOXICILLIN', 'adult', 'ACUTE-BRONCHITIS', 'oral', '500 mg', 'three times daily', '5 days (if bacterial suspected)', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL),
   ('MED-PREDNISOLONE', 'adult', 'ACUTE-BRONCHITIS', 'oral', '30-40 mg', 'once daily', '5 days (troublesome cough)', NULL, 'Kumar & Clark 10e', NULL, NULL, NULL)
) AS x(med_code, population, indication_code, route, dose_expression, frequency_expression,
       duration_expression, maximum_expression, evidence_source, weight_basis, dose_per_kg_min, dose_per_kg_max)
JOIN knowledge.medication m ON m.medication_code = x.med_code
  ON CONFLICT DO NOTHING;
