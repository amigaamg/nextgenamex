-- =============================================================================
-- AMEXAN PHASE 2 — SEED Z6
-- UNIVERSAL CONDITION LAYER + MEDICAL KNOWLEDGE GRAPH
-- =============================================================================
--
-- PURPOSE
-- -------
-- Z6 is the universal disease/condition layer of the AMEXAN Clinical
-- Intelligence Knowledge Graph.
--
-- CONDITIONS ARE NOT SPECIALTY-LOCKED.
--
-- The same condition can participate in:
--
--   symptom -> question -> fact -> phenotype -> condition
--                                  |
--                                  v
--                              mechanism
--                                  |
--                     +------------+------------+
--                     |            |            |
--               investigation   complication   rule
--                     |
--                  management
--
-- This layer therefore covers:
--
--   Internal Medicine
--   Emergency Medicine
--   Family Medicine
--   Paediatrics
--   Surgery
--   Obstetrics
--   Gynaecology
--   Neurology
--   Cardiology
--   Respiratory Medicine
--   Gastroenterology
--   Hepatology
--   Nephrology
--   Endocrinology
--   Rheumatology
--   Haematology
--   Oncology
--   Infectious Diseases
--   Dermatology
--   ENT
--   Ophthalmology
--   Orthopaedics
--   Psychiatry
--   Urology
--   Anaesthesia
--   Critical Care
--   Public Health
--
-- ARCHITECTURAL RULES
-- -------------------
-- 1. Disease is never the starting point of clinical history.
-- 2. Conditions are downstream of observations/facts/phenotypes.
-- 3. Conditions may be associated with many symptoms.
-- 4. Conditions may belong to multiple systems.
-- 5. Conditions may belong to multiple specialties.
-- 6. Conditions may have multiple mechanisms.
-- 7. Conditions may have multiple phenotypes.
-- 8. Conditions may have multiple differentials.
-- 9. Conditions may have multiple complications.
-- 10. Conditions may have multiple risk factors.
-- 11. No diagnosis should be declared solely from a single symptom.
-- 12. Weights represent knowledge relevance, NOT diagnostic probability.
-- 13. Rules determine clinical action.
-- 14. Z6 provides the graph substrate; Z7 provides executable reasoning.
-- 15. Provenance belongs on knowledge relationships and rules.
--
-- IMPORTANT
-- ---------
-- This seed intentionally avoids hard-coding treatment algorithms into the
-- condition table. Treatment, dosing, escalation and contraindications belong
-- in the management/rule/protocol layers.
--
-- PostgreSQL
-- =============================================================================


BEGIN;


-- =============================================================================
-- 1. UNIVERSAL CONDITION CATALOGUE
-- =============================================================================
--
-- concept_id is intentionally nullable here.
--
-- The condition is an independent clinical entity, while concept normalization
-- can be attached by the broader AMEXAN concept vocabulary.
--
-- This allows the condition catalogue to be seeded independently and then
-- connected to SNOMED/ICD/local AMEXAN concepts by a later normalization layer.
--
-- =============================================================================


INSERT INTO knowledge.condition
    (id, concept_id, condition_code, canonical_name, description, condition_type)
VALUES

-- ============================================================================
-- RESPIRATORY
-- ============================================================================

('f1000000-0000-0000-0000-000000000001', NULL, 'PNEUMONIA',
 'Pneumonia',
 'Infection and inflammation of the lung parenchyma.',
 'infectious'),

(gen_random_uuid(), NULL, 'COMMUNITY_ACQUIRED_PNEUMONIA',
 'Community-acquired pneumonia',
 'Acute pneumonia acquired outside a healthcare setting.',
 'infectious'),

(gen_random_uuid(), NULL, 'HOSPITAL_ACQUIRED_PNEUMONIA',
 'Hospital-acquired pneumonia',
 'Pneumonia developing during healthcare exposure after the relevant hospitalisation interval.',
 'infectious'),

('f1000000-0000-0000-0000-000000000002', NULL, 'TUBERCULOSIS',
 'Tuberculosis',
 'Infection caused by Mycobacterium tuberculosis complex with pulmonary and extrapulmonary manifestations.',
 'infectious'),

(gen_random_uuid(), NULL, 'ACUTE_BRONCHITIS',
 'Acute bronchitis',
 'Acute inflammation of the conducting airways, usually infectious.',
 'acute'),

('f1000000-0000-0000-0000-000000000004', NULL, 'ASTHMA',
 'Asthma',
 'Chronic inflammatory airway disease characterised by variable respiratory symptoms and variable expiratory airflow limitation.',
 'chronic'),

(gen_random_uuid(), NULL, 'COPD',
 'Chronic obstructive pulmonary disease',
 'Chronic respiratory disease characterised by persistent airflow limitation and respiratory symptoms.',
 'chronic'),

(gen_random_uuid(), NULL, 'BRONCHIOLITIS',
 'Bronchiolitis',
 'Acute viral lower respiratory tract infection involving the small airways, predominantly in infants.',
 'infectious'),

(gen_random_uuid(), NULL, 'PLEURAL_EFFUSION',
 'Pleural effusion',
 'Abnormal accumulation of fluid in the pleural space.',
 'structural'),

(gen_random_uuid(), NULL, 'PNEUMOTHORAX',
 'Pneumothorax',
 'Presence of air within the pleural space causing partial or complete lung collapse.',
 'structural'),

(gen_random_uuid(), NULL, 'PULMONARY_EMBOLISM',
 'Pulmonary embolism',
 'Obstruction of pulmonary arterial circulation, usually by thromboembolism.',
 'vascular'),

(gen_random_uuid(), NULL, 'INTERSTITIAL_LUNG_DISEASE',
 'Interstitial lung disease',
 'Heterogeneous group of disorders affecting pulmonary interstitium and lung parenchyma.',
 'structural'),

(gen_random_uuid(), NULL, 'LUNG_CANCER',
 'Lung cancer',
 'Malignant neoplasm arising from pulmonary tissues or bronchi.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'OBSTRUCTIVE_SLEEP_APNOEA',
 'Obstructive sleep apnoea',
 'Recurrent upper airway obstruction during sleep causing intermittent hypoxaemia and sleep fragmentation.',
 'sleep_disorder'),


-- ============================================================================
-- CARDIOVASCULAR
-- ============================================================================

(gen_random_uuid(), NULL, 'HYPERTENSION',
 'Hypertension',
 'Persistent elevation of systemic arterial blood pressure.',
 'chronic'),

(gen_random_uuid(), NULL, 'HYPERTENSIVE_EMERGENCY',
 'Hypertensive emergency',
 'Severe hypertension associated with acute target-organ injury.',
 'emergency'),

('f1000000-0000-0000-0000-000000000005', NULL, 'HEART_FAILURE',
 'Heart failure',
 'Clinical syndrome caused by structural or functional cardiac abnormality resulting in impaired cardiac output and/or elevated filling pressures.',
 'chronic'),

(gen_random_uuid(), NULL, 'ACUTE_HEART_FAILURE',
 'Acute heart failure',
 'Rapid onset or worsening of heart failure requiring urgent assessment and management.',
 'acute'),

(gen_random_uuid(), NULL, 'CORONARY_ARTERY_DISEASE',
 'Coronary artery disease',
 'Atherosclerotic disease affecting the coronary arteries.',
 'vascular'),

(gen_random_uuid(), NULL, 'ACUTE_CORONARY_SYNDROME',
 'Acute coronary syndrome',
 'Spectrum of acute myocardial ischaemic syndromes including unstable angina and myocardial infarction.',
 'emergency'),

(gen_random_uuid(), NULL, 'STEMI',
 'ST-elevation myocardial infarction',
 'Acute myocardial infarction associated with persistent ST-segment elevation in an appropriate clinical context.',
 'emergency'),

(gen_random_uuid(), NULL, 'NSTEMI',
 'Non-ST-elevation myocardial infarction',
 'Acute myocardial infarction without persistent diagnostic ST-segment elevation.',
 'emergency'),

(gen_random_uuid(), NULL, 'ATRIAL_FIBRILLATION',
 'Atrial fibrillation',
 'Supraventricular tachyarrhythmia characterised by uncoordinated atrial electrical activity.',
 'arrhythmia'),

(gen_random_uuid(), NULL, 'VENTRICULAR_TACHYCARDIA',
 'Ventricular tachycardia',
 'Tachyarrhythmia originating from ventricular myocardium.',
 'arrhythmia'),

(gen_random_uuid(), NULL, 'PERICARDITIS',
 'Pericarditis',
 'Inflammation of the pericardial layers.',
 'inflammatory'),

(gen_random_uuid(), NULL, 'INFECTIVE_ENDOCARDITIS',
 'Infective endocarditis',
 'Infection of the endocardial surface, usually involving cardiac valves.',
 'infectious'),

(gen_random_uuid(), NULL, 'CARDIOMYOPATHY',
 'Cardiomyopathy',
 'Disease of cardiac muscle causing structural or functional myocardial abnormality.',
 'structural'),

(gen_random_uuid(), NULL, 'PERIPHERAL_ARTERIAL_DISEASE',
 'Peripheral arterial disease',
 'Atherosclerotic disease affecting peripheral arteries, especially of the lower limbs.',
 'vascular'),

(gen_random_uuid(), NULL, 'DEEP_VEIN_THROMBOSIS',
 'Deep vein thrombosis',
 'Thrombus formation within a deep venous system.',
 'vascular'),


-- ============================================================================
-- NEUROLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'STROKE',
 'Stroke',
 'Acute neurological dysfunction caused by vascular injury to the brain.',
 'vascular'),

(gen_random_uuid(), NULL, 'ISCHAEMIC_STROKE',
 'Ischaemic stroke',
 'Cerebral infarction caused by arterial occlusion and tissue ischaemia.',
 'vascular'),

(gen_random_uuid(), NULL, 'INTRACEREBRAL_HAEMORRHAGE',
 'Intracerebral haemorrhage',
 'Bleeding directly into brain parenchyma.',
 'vascular'),

(gen_random_uuid(), NULL, 'SUBARACHNOID_HAEMORRHAGE',
 'Subarachnoid haemorrhage',
 'Bleeding into the subarachnoid space.',
 'vascular'),

(gen_random_uuid(), NULL, 'TRANSIENT_ISCHAEMIC_ATTACK',
 'Transient ischaemic attack',
 'Transient neurological dysfunction caused by focal cerebral, spinal or retinal ischaemia without established infarction.',
 'vascular'),

(gen_random_uuid(), NULL, 'EPILEPSY',
 'Epilepsy',
 'Neurological disorder characterised by an enduring predisposition to epileptic seizures.',
 'neurological'),

(gen_random_uuid(), NULL, 'STATUS_EPILEPTICUS',
 'Status epilepticus',
 'Prolonged or recurrent seizure activity requiring urgent treatment.',
 'emergency'),

(gen_random_uuid(), NULL, 'MENINGITIS',
 'Meningitis',
 'Inflammation of the meninges surrounding the brain and spinal cord.',
 'infectious'),

(gen_random_uuid(), NULL, 'ENCEPHALITIS',
 'Encephalitis',
 'Inflammation of brain parenchyma, commonly infectious or autoimmune.',
 'inflammatory'),

(gen_random_uuid(), NULL, 'MIGRAINE',
 'Migraine',
 'Neurological disorder characterised by recurrent attacks of headache and associated symptoms.',
 'neurological'),

(gen_random_uuid(), NULL, 'TENSION_TYPE_HEADACHE',
 'Tension-type headache',
 'Primary headache disorder characterised by recurrent bilateral pressing or tightening headache.',
 'neurological'),

(gen_random_uuid(), NULL, 'PARKINSON_DISEASE',
 'Parkinson disease',
 'Progressive neurodegenerative disorder involving dopaminergic neuronal dysfunction and characteristic motor and non-motor features.',
 'neurodegenerative'),

(gen_random_uuid(), NULL, 'MULTIPLE_SCLEROSIS',
 'Multiple sclerosis',
 'Immune-mediated inflammatory demyelinating disease of the central nervous system.',
 'immune'),

(gen_random_uuid(), NULL, 'PERIPHERAL_NEUROPATHY',
 'Peripheral neuropathy',
 'Disorder affecting peripheral nerves causing sensory, motor and/or autonomic dysfunction.',
 'neurological'),


-- ============================================================================
-- GASTROINTESTINAL / HEPATOBILIARY
-- ============================================================================

('f1000000-0000-0000-0000-000000000006', NULL, 'GERD',
 'Gastro-oesophageal reflux disease',
 'Condition caused by reflux of gastric contents producing troublesome symptoms or complications.',
 'chronic'),

(gen_random_uuid(), NULL, 'PEPTIC_ULCER_DISEASE',
 'Peptic ulcer disease',
 'Ulceration of gastric or duodenal mucosa related to acid-peptic injury and associated factors.',
 'gastrointestinal'),

(gen_random_uuid(), NULL, 'UPPER_GI_BLEED',
 'Upper gastrointestinal bleeding',
 'Bleeding arising from the gastrointestinal tract proximal to the ligament of Treitz.',
 'emergency'),

(gen_random_uuid(), NULL, 'LOWER_GI_BLEED',
 'Lower gastrointestinal bleeding',
 'Gastrointestinal bleeding arising from the lower intestinal tract.',
 'emergency'),

(gen_random_uuid(), NULL, 'ACUTE_GASTROENTERITIS',
 'Acute gastroenteritis',
 'Acute inflammatory or infectious disorder causing gastrointestinal symptoms, commonly diarrhoea and vomiting.',
 'infectious'),

(gen_random_uuid(), NULL, 'INFLAMMATORY_BOWEL_DISEASE',
 'Inflammatory bowel disease',
 'Chronic immune-mediated inflammatory disorders including Crohn disease and ulcerative colitis.',
 'immune'),

(gen_random_uuid(), NULL, 'APPENDICITIS',
 'Acute appendicitis',
 'Acute inflammation of the vermiform appendix.',
 'surgical'),

(gen_random_uuid(), NULL, 'INTESTINAL_OBSTRUCTION',
 'Intestinal obstruction',
 'Mechanical or functional interruption of intestinal contents passage.',
 'surgical'),

(gen_random_uuid(), NULL, 'PERITONITIS',
 'Peritonitis',
 'Inflammation or infection of the peritoneum.',
 'surgical'),

(gen_random_uuid(), NULL, 'ACUTE_PANCREATITIS',
 'Acute pancreatitis',
 'Acute inflammatory disorder of the pancreas.',
 'gastrointestinal'),

(gen_random_uuid(), NULL, 'CHRONIC_PANCREATITIS',
 'Chronic pancreatitis',
 'Persistent inflammatory and fibrotic pancreatic disease causing structural and functional impairment.',
 'chronic'),

(gen_random_uuid(), NULL, 'HEPATITIS',
 'Hepatitis',
 'Inflammation of the liver caused by infectious, toxic, metabolic, immune or other processes.',
 'inflammatory'),

(gen_random_uuid(), NULL, 'CIRRHOSIS',
 'Cirrhosis',
 'Advanced chronic liver disease characterised by fibrosis and regenerative nodules with architectural distortion.',
 'chronic'),

(gen_random_uuid(), NULL, 'ACUTE_LIVER_FAILURE',
 'Acute liver failure',
 'Acute severe hepatic dysfunction with coagulopathy and encephalopathy in a person without established cirrhosis.',
 'emergency'),

(gen_random_uuid(), NULL, 'CHOLECYSTITIS',
 'Acute cholecystitis',
 'Acute inflammation of the gallbladder, usually related to cystic duct obstruction.',
 'surgical'),

(gen_random_uuid(), NULL, 'CHOLANGITIS',
 'Acute cholangitis',
 'Infection and inflammation of the biliary tree, usually associated with biliary obstruction.',
 'infectious'),

(gen_random_uuid(), NULL, 'COLORECTAL_CANCER',
 'Colorectal cancer',
 'Malignant neoplasm arising from the colon or rectum.' ,
 'neoplastic'),


-- ============================================================================
-- RENAL / UROLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'ACUTE_KIDNEY_INJURY',
 'Acute kidney injury',
 'Acute decline in kidney function associated with accumulation of nitrogenous waste and disturbances of fluid, electrolyte or acid-base balance.',
 'acute'),

(gen_random_uuid(), NULL, 'CHRONIC_KIDNEY_DISEASE',
 'Chronic kidney disease',
 'Persistent abnormality of kidney structure or function with implications for health.',
 'chronic'),

(gen_random_uuid(), NULL, 'NEPHROTIC_SYNDROME',
 'Nephrotic syndrome',
 'Clinical syndrome characterised by heavy proteinuria, hypoalbuminaemia and oedema, often with hyperlipidaemia.',
 'renal'),

(gen_random_uuid(), NULL, 'NEPHRITIC_SYNDROME',
 'Nephritic syndrome',
 'Clinical syndrome characterised by glomerular inflammation, haematuria and variable renal dysfunction.',
 'renal'),

(gen_random_uuid(), NULL, 'PYELONEPHRITIS',
 'Acute pyelonephritis',
 'Infection of the renal pelvis and renal parenchyma.',
 'infectious'),

(gen_random_uuid(), NULL, 'URINARY_TRACT_INFECTION',
 'Urinary tract infection',
 'Infection involving the urinary tract.',
 'infectious'),

(gen_random_uuid(), NULL, 'UROLITHIASIS',
 'Urolithiasis',
 'Calculi within the urinary tract.',
 'structural'),

(gen_random_uuid(), NULL, 'BENIGN_PROSTATIC_HYPERPLASIA',
 'Benign prostatic hyperplasia',
 'Benign enlargement of the prostate that may cause lower urinary tract symptoms.',
 'structural'),

(gen_random_uuid(), NULL, 'PROSTATE_CANCER',
 'Prostate cancer',
 'Malignant neoplasm arising from prostate tissue.',
 'neoplastic'),


-- ============================================================================
-- ENDOCRINOLOGY / METABOLISM
-- ============================================================================

(gen_random_uuid(), NULL, 'DIABETES_MELLITUS',
 'Diabetes mellitus',
 'Metabolic disorder characterised by chronic hyperglycaemia resulting from impaired insulin secretion, insulin action or both.',
 'metabolic'),

(gen_random_uuid(), NULL, 'TYPE_1_DIABETES_MELLITUS',
 'Type 1 diabetes mellitus',
 'Diabetes caused by autoimmune or other destruction of pancreatic beta cells resulting in absolute insulin deficiency.',
 'metabolic'),

(gen_random_uuid(), NULL, 'TYPE_2_DIABETES_MELLITUS',
 'Type 2 diabetes mellitus',
 'Diabetes characterised predominantly by insulin resistance with progressive beta-cell dysfunction.',
 'metabolic'),

(gen_random_uuid(), NULL, 'DIABETIC_KETOACIDOSIS',
 'Diabetic ketoacidosis',
 'Acute metabolic emergency characterised by hyperglycaemia, ketosis and metabolic acidosis.',
 'emergency'),

(gen_random_uuid(), NULL, 'HYPEROSMOLAR_HYPERGLYCAEMIC_STATE',
 'Hyperosmolar hyperglycaemic state',
 'Severe hyperglycaemia with hyperosmolality and dehydration without significant ketoacidosis.',
 'emergency'),

(gen_random_uuid(), NULL, 'HYPOGLYCAEMIA',
 'Hypoglycaemia',
 'Abnormally low plasma glucose capable of causing autonomic and neuroglycopenic symptoms.',
 'metabolic'),

(gen_random_uuid(), NULL, 'HYPERTHYROIDISM',
 'Hyperthyroidism',
 'Clinical syndrome caused by excessive thyroid hormone action.',
 'endocrine'),

(gen_random_uuid(), NULL, 'HYPOTHYROIDISM',
 'Hypothyroidism',
 'Clinical syndrome caused by inadequate thyroid hormone production or action.',
 'endocrine'),

(gen_random_uuid(), NULL, 'THYROID_STORM',
 'Thyroid storm',
 'Life-threatening decompensation of thyrotoxicosis with systemic organ dysfunction.',
 'emergency'),

(gen_random_uuid(), NULL, 'ADRENAL_INSUFFICIENCY',
 'Adrenal insufficiency',
 'Inadequate production or action of adrenal glucocorticoids with or without mineralocorticoid deficiency.',
 'endocrine'),

(gen_random_uuid(), NULL, 'ADRENAL_CRISIS',
 'Adrenal crisis',
 'Acute life-threatening decompensation of adrenal insufficiency.',
 'emergency'),

(gen_random_uuid(), NULL, 'OBESITY',
 'Obesity',
 'Excess adiposity associated with increased risk of disease and functional impairment.',
 'metabolic'),


-- ============================================================================
-- HAEMATOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'IRON_DEFICIENCY_ANAEMIA',
 'Iron deficiency anaemia',
 'Anaemia caused by insufficient iron availability for haemoglobin synthesis.',
 'haematological'),

(gen_random_uuid(), NULL, 'MEGALOBLASTIC_ANAEMIA',
 'Megaloblastic anaemia',
 'Anaemia caused by impaired DNA synthesis, commonly due to vitamin B12 or folate deficiency.',
 'haematological'),

(gen_random_uuid(), NULL, 'SICKLE_CELL_DISEASE',
 'Sickle cell disease',
 'Inherited haemoglobinopathy causing chronic haemolysis and episodic vaso-occlusive complications.',
 'genetic'),

(gen_random_uuid(), NULL, 'HAEMOPHILIA',
 'Haemophilia',
 'Inherited coagulation disorder caused by deficiency of factor VIII or IX.',
 'genetic'),

(gen_random_uuid(), NULL, 'THROMBOCYTOPENIA',
 'Thrombocytopenia',
 'Reduction in circulating platelet count below the reference range.',
 'haematological'),

(gen_random_uuid(), NULL, 'DISSEMINATED_INTRAVASCULAR_COAGULATION',
 'Disseminated intravascular coagulation',
 'Systemic activation of coagulation resulting in thrombosis, consumption of coagulation factors and bleeding.',
 'emergency'),

(gen_random_uuid(), NULL, 'ACUTE_LEUKAEMIA',
 'Acute leukaemia',
 'Aggressive malignant proliferation of immature haematopoietic cells.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'CHRONIC_LEUKAEMIA',
 'Chronic leukaemia',
 'Clonal haematological malignancy characterised by proliferation of more mature blood-cell lineages.',
 'neoplastic'),


-- ============================================================================
-- INFECTIOUS DISEASE
-- ============================================================================

(gen_random_uuid(), NULL, 'HIV_INFECTION',
 'HIV infection',
 'Chronic infection caused by human immunodeficiency virus resulting in progressive immune dysfunction without effective treatment.',
 'infectious'),

(gen_random_uuid(), NULL, 'MALARIA',
 'Malaria',
 'Parasitic infection caused by Plasmodium species and transmitted by Anopheles mosquitoes.',
 'infectious'),

(gen_random_uuid(), NULL, 'SEPSIS',
 'Sepsis',
 'Life-threatening organ dysfunction caused by a dysregulated host response to infection.',
 'emergency'),

(gen_random_uuid(), NULL, 'SEPTIC_SHOCK',
 'Septic shock',
 'Subset of sepsis with profound circulatory and cellular/metabolic abnormalities associated with substantially increased mortality.',
 'emergency'),

(gen_random_uuid(), NULL, 'MENINGOCOCCAL_DISEASE',
 'Meningococcal disease',
 'Invasive infection caused by Neisseria meningitidis.',
 'infectious'),

(gen_random_uuid(), NULL, 'TYPHOID_FEVER',
 'Typhoid fever',
 'Systemic infection caused by Salmonella enterica serovar Typhi.',
 'infectious'),

(gen_random_uuid(), NULL, 'CHOLERA',
 'Cholera',
 'Acute diarrhoeal infection caused by toxigenic Vibrio cholerae.',
 'infectious'),

(gen_random_uuid(), NULL, 'DENGUE',
 'Dengue',
 'Mosquito-borne viral infection that may range from febrile illness to severe plasma leakage and shock.',
 'infectious'),

(gen_random_uuid(), NULL, 'TETANUS',
 'Tetanus',
 'Neurological disease caused by tetanospasmin produced by Clostridium tetani.',
 'infectious'),

(gen_random_uuid(), NULL, 'RABIES',
 'Rabies',
 'Acute progressive encephalitis caused by rabies virus following exposure to infected animals.',
 'infectious'),


-- ============================================================================
-- PAEDIATRICS / NEONATOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'NEONATAL_SEPSIS',
 'Neonatal sepsis',
 'Systemic infection in a neonate with potential for rapid clinical deterioration.',
 'neonatal'),

(gen_random_uuid(), NULL, 'NEONATAL_JAUNDICE',
 'Neonatal jaundice',
 'Visible neonatal hyperbilirubinaemia.',
 'neonatal'),

(gen_random_uuid(), NULL, 'NEONATAL_ASPHYXIA',
 'Birth asphyxia / neonatal encephalopathy',
 'Neonatal neurological dysfunction associated with impaired oxygenation or perfusion around birth.',
 'neonatal'),

(gen_random_uuid(), NULL, 'PRETERM_BIRTH',
 'Preterm birth',
 'Birth occurring before 37 completed weeks of gestation.',
 'obstetric'),

(gen_random_uuid(), NULL, 'ACUTE_MALNUTRITION',
 'Acute malnutrition',
 'Nutritional deficiency characterised by wasting and/or nutritional oedema according to established criteria.',
 'nutritional'),

(gen_random_uuid(), NULL, 'SEVERE_ACUTE_MALNUTRITION',
 'Severe acute malnutrition',
 'Severe wasting and/or nutritional oedema meeting established paediatric criteria.',
 'nutritional'),

(gen_random_uuid(), NULL, 'CROUP',
 'Croup',
 'Acute upper airway inflammatory syndrome causing barking cough, stridor and varying respiratory distress.',
 'paediatric'),

(gen_random_uuid(), NULL, 'EPIGLOTTITIS',
 'Epiglottitis',
 'Potentially life-threatening inflammation and swelling of supraglottic structures.',
 'emergency'),


-- ============================================================================
-- OBSTETRICS
-- ============================================================================

(gen_random_uuid(), NULL, 'PREECLAMPSIA',
 'Preeclampsia',
 'Pregnancy-specific hypertensive disorder associated with maternal and placental dysfunction.',
 'obstetric'),

(gen_random_uuid(), NULL, 'ECLAMPSIA',
 'Eclampsia',
 'Occurrence of seizures in association with preeclampsia after exclusion of alternative causes.',
 'emergency'),

(gen_random_uuid(), NULL, 'GESTATIONAL_HYPERTENSION',
 'Gestational hypertension',
 'New-onset hypertension during pregnancy without diagnostic features of preeclampsia.',
 'obstetric'),

(gen_random_uuid(), NULL, 'GESTATIONAL_DIABETES',
 'Gestational diabetes mellitus',
 'Glucose intolerance with onset or first recognition during pregnancy.',
 'obstetric'),

(gen_random_uuid(), NULL, 'PLACENTA_PREVIA',
 'Placenta previa',
 'Placental implantation in the lower uterine segment with relationship to the internal cervical os.',
 'obstetric'),

(gen_random_uuid(), NULL, 'PLACENTAL_ABRUPTION',
 'Placental abruption',
 'Premature separation of a normally implanted placenta before delivery.',
 'obstetric'),

(gen_random_uuid(), NULL, 'POSTPARTUM_HAEMORRHAGE',
 'Postpartum haemorrhage',
 'Excessive postpartum blood loss causing potential maternal morbidity or mortality.',
 'obstetric_emergency'),

(gen_random_uuid(), NULL, 'ECTOPIC_PREGNANCY',
 'Ectopic pregnancy',
 'Pregnancy implanted outside the normal endometrial cavity.',
 'obstetric_emergency'),

(gen_random_uuid(), NULL, 'MISCARRIAGE',
 'Miscarriage',
 'Spontaneous loss of an intrauterine pregnancy before viability according to applicable clinical definition.',
 'obstetric'),

(gen_random_uuid(), NULL, 'PRETERM_LABOUR',
 'Preterm labour',
 'Regular uterine contractions with cervical change occurring before term gestation.',
 'obstetric'),


-- ============================================================================
-- GYNAECOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'POLYCYSTIC_OVARY_SYNDROME',
 'Polycystic ovary syndrome',
 'Endocrine and reproductive disorder characterised by combinations of ovulatory dysfunction, hyperandrogenism and characteristic ovarian morphology.',
 'gynaecological'),

(gen_random_uuid(), NULL, 'ENDOMETRIOSIS',
 'Endometriosis',
 'Chronic inflammatory disease associated with endometrial-like tissue outside the uterine cavity.',
 'gynaecological'),

(gen_random_uuid(), NULL, 'UTERINE_FIBROIDS',
 'Uterine fibroids',
 'Benign smooth-muscle tumours of the uterus.',
 'gynaecological'),

(gen_random_uuid(), NULL, 'PELVIC_INFLAMMATORY_DISEASE',
 'Pelvic inflammatory disease',
 'Infection and inflammation of the upper female genital tract.',
 'infectious'),

(gen_random_uuid(), NULL, 'CERVICAL_CANCER',
 'Cervical cancer',
 'Malignant neoplasm arising from the cervix.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'BREAST_CANCER',
 'Breast cancer',
 'Malignant neoplasm arising from breast tissue.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'BENIGN_BREAST_DISEASE',
 'Benign breast disease',
 'Non-malignant disorders of breast tissue including proliferative and non-proliferative lesions.',
 'gynaecological'),


-- ============================================================================
-- SURGERY / TRAUMA
-- ============================================================================

(gen_random_uuid(), NULL, 'ACUTE_APPENDICITIS',
 'Acute appendicitis',
 'Acute inflammation of the vermiform appendix.',
 'surgical'),

(gen_random_uuid(), NULL, 'ACUTE_PERFORATED_VIScus',
 'Perforated viscus',
 'Perforation of a hollow gastrointestinal or other visceral organ causing contamination of surrounding tissues.',
 'surgical_emergency'),

(gen_random_uuid(), NULL, 'ACUTE_MESENTERIC_ISCHAEMIA',
 'Acute mesenteric ischaemia',
 'Acute reduction in intestinal blood flow causing bowel ischaemia.',
 'vascular_emergency'),

(gen_random_uuid(), NULL, 'INGUINAL_HERNIA',
 'Inguinal hernia',
 'Protrusion of abdominal contents through the inguinal region.',
 'surgical'),

(gen_random_uuid(), NULL, 'STRANGULATED_HERNIA',
 'Strangulated hernia',
 'Hernia associated with compromised blood supply to its contents.',
 'surgical_emergency'),

(gen_random_uuid(), NULL, 'BOWEL_OBSTRUCTION',
 'Bowel obstruction',
 'Interruption of normal intestinal transit due to mechanical or functional causes.',
 'surgical'),

(gen_random_uuid(), NULL, 'ACUTE_CHOLECYSTITIS',
 'Acute cholecystitis',
 'Acute inflammation of the gallbladder.',
 'surgical'),

(gen_random_uuid(), NULL, 'TRAUMATIC_BRAIN_INJURY',
 'Traumatic brain injury',
 'Brain dysfunction or structural injury caused by external mechanical force.',
 'trauma'),

(gen_random_uuid(), NULL, 'BLUNT_ABDOMINAL_TRAUMA',
 'Blunt abdominal trauma',
 'Abdominal injury caused by non-penetrating external force.',
 'trauma'),

(gen_random_uuid(), NULL, 'PENETRATING_ABDOMINAL_TRAUMA',
 'Penetrating abdominal trauma',
 'Abdominal injury involving penetration of the abdominal wall.',
 'trauma'),

(gen_random_uuid(), NULL, 'FRACTURE',
 'Fracture',
 'Break or disruption in the continuity of bone.',
 'orthopaedic'),

(gen_random_uuid(), NULL, 'OPEN_FRACTURE',
 'Open fracture',
 'Fracture associated with communication between fracture site and external environment.',
 'orthopaedic_emergency'),

(gen_random_uuid(), NULL, 'SEPTIC_ARTHRITIS',
 'Septic arthritis',
 'Infection of a synovial joint.',
 'infectious'),

(gen_random_uuid(), NULL, 'OSTEOARTHRITIS',
 'Osteoarthritis',
 'Chronic joint disorder involving structural and functional changes of articular cartilage, subchondral bone and other joint tissues.',
 'degenerative'),

(gen_random_uuid(), NULL, 'OSTEOMYELITIS',
 'Osteomyelitis',
 'Infection and inflammation of bone and bone marrow.',
 'infectious'),


-- ============================================================================
-- RHEUMATOLOGY / IMMUNOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'RHEUMATOID_ARTHRITIS',
 'Rheumatoid arthritis',
 'Systemic autoimmune inflammatory disease primarily affecting synovial joints.',
 'autoimmune'),

(gen_random_uuid(), NULL, 'SYSTEMIC_LUPUS_ERYTHEMATOSUS',
 'Systemic lupus erythematosus',
 'Systemic autoimmune disease capable of affecting multiple organs.',
 'autoimmune'),

(gen_random_uuid(), NULL, 'GOUT',
 'Gout',
 'Inflammatory arthritis caused by deposition of monosodium urate crystals.',
 'metabolic'),

(gen_random_uuid(), NULL, 'OSTEOPOROSIS',
 'Osteoporosis',
 'Skeletal disorder characterised by compromised bone strength and increased fracture risk.',
 'metabolic'),

(gen_random_uuid(), NULL, 'ANAPHYLAXIS',
 'Anaphylaxis',
 'Acute life-threatening systemic hypersensitivity reaction causing airway, breathing, circulation and/or severe systemic manifestations.',
 'emergency'),


-- ============================================================================
-- DERMATOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'ATOPIC_DERMATITIS',
 'Atopic dermatitis',
 'Chronic inflammatory pruritic skin disorder associated with epidermal barrier dysfunction and immune dysregulation.',
 'dermatological'),

(gen_random_uuid(), NULL, 'CONTACT_DERMATITIS',
 'Contact dermatitis',
 'Inflammatory skin reaction caused by direct contact with irritant or allergenic substances.',
 'dermatological'),

(gen_random_uuid(), NULL, 'CELLULITIS',
 'Cellulitis',
 'Acute bacterial infection of the dermis and subcutaneous tissues.',
 'infectious'),

(gen_random_uuid(), NULL, 'ERYTHRODERMA',
 'Erythroderma',
 'Generalised erythema and scaling involving most of the skin surface.',
 'dermatological_emergency'),

(gen_random_uuid(), NULL, 'STEVENS_JOHNSON_SYNDROME',
 'Stevens-Johnson syndrome',
 'Severe mucocutaneous reaction characterised by epidermal detachment and systemic illness.',
 'emergency'),

(gen_random_uuid(), NULL, 'TOXIC_EPITHELIAL_NECROLYSIS',
 'Toxic epidermal necrolysis',
 'Severe drug-associated mucocutaneous reaction with extensive epidermal necrosis and detachment.',
 'emergency'),


-- ============================================================================
-- PSYCHIATRY
-- ============================================================================

(gen_random_uuid(), NULL, 'MAJOR_DEPRESSIVE_DISORDER',
 'Major depressive disorder',
 'Mood disorder characterised by persistent depressive symptoms and associated cognitive, behavioural and somatic changes.',
 'psychiatric'),

(gen_random_uuid(), NULL, 'BIPOLAR_DISORDER',
 'Bipolar disorder',
 'Mood disorder characterised by episodes of mania or hypomania and episodes of depression.',
 'psychiatric'),

(gen_random_uuid(), NULL, 'SCHIZOPHRENIA',
 'Schizophrenia',
 'Chronic psychotic disorder involving disturbances of perception, thought, cognition and behaviour.',
 'psychiatric'),

(gen_random_uuid(), NULL, 'GENERALIZED_ANXIETY_DISORDER',
 'Generalized anxiety disorder',
 'Anxiety disorder characterised by excessive and persistent worry across multiple domains.',
 'psychiatric'),

(gen_random_uuid(), NULL, 'DELIRIUM',
 'Delirium',
 'Acute fluctuating disturbance of attention, awareness and cognition caused by an underlying medical or toxic state.',
 'emergency'),

(gen_random_uuid(), NULL, 'SUBSTANCE_USE_DISORDER',
 'Substance use disorder',
 'Pattern of problematic substance use associated with clinically significant impairment or distress.',
 'psychiatric'),


-- ============================================================================
-- OPHTHALMOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'CATARACT',
 'Cataract',
 'Opacity of the crystalline lens causing visual impairment.',
 'ophthalmological'),

(gen_random_uuid(), NULL, 'GLAUCOMA',
 'Glaucoma',
 'Progressive optic neuropathy associated with characteristic optic nerve damage and visual field loss.',
 'ophthalmological'),

(gen_random_uuid(), NULL, 'ACUTE_ANGLE_CLOSURE_GLAUCOMA',
 'Acute angle-closure glaucoma',
 'Acute elevation of intraocular pressure caused by angle closure.',
 'ophthalmic_emergency'),

(gen_random_uuid(), NULL, 'CONJUNCTIVITIS',
 'Conjunctivitis',
 'Inflammation of the conjunctiva caused by infectious, allergic or other processes.',
 'ophthalmological'),

(gen_random_uuid(), NULL, 'RETINAL_DETACHMENT',
 'Retinal detachment',
 'Separation of neurosensory retina from the underlying retinal pigment epithelium.',
 'ophthalmic_emergency'),


-- ============================================================================
-- ENT
-- ============================================================================

(gen_random_uuid(), NULL, 'OTITIS_MEDIA',
 'Acute otitis media',
 'Acute infection or inflammation of the middle ear.',
 'infectious'),

(gen_random_uuid(), NULL, 'OTITIS_EXTERNA',
 'Otitis externa',
 'Inflammation or infection of the external auditory canal.',
 'infectious'),

(gen_random_uuid(), NULL, 'ACUTE_SINUSITIS',
 'Acute rhinosinusitis',
 'Acute inflammation of the nasal and paranasal sinus mucosa.',
 'infectious'),

(gen_random_uuid(), NULL, 'TONSILLITIS',
 'Acute tonsillitis',
 'Acute inflammation of the palatine tonsils, usually infectious.',
 'infectious'),

(gen_random_uuid(), NULL, 'PERITONSILLAR_ABSCESS',
 'Peritonsillar abscess',
 'Collection of pus in the peritonsillar tissues, usually complicating tonsillar infection.',
 'infectious_emergency'),


-- ============================================================================
-- ONCOLOGY
-- ============================================================================

(gen_random_uuid(), NULL, 'BREAST_CANCER',
 'Breast cancer',
 'Malignant neoplasm of breast tissue.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'LUNG_CANCER',
 'Lung cancer',
 'Malignant neoplasm arising from pulmonary tissue.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'COLORECTAL_CANCER',
 'Colorectal cancer',
 'Malignant neoplasm arising in the colon or rectum.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'PROSTATE_CANCER',
 'Prostate cancer',
 'Malignant neoplasm arising from prostate tissue.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'CERVICAL_CANCER',
 'Cervical cancer',
 'Malignant neoplasm arising from the cervix.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'OVARIAN_CANCER',
 'Ovarian cancer',
 'Malignant neoplasm arising from ovarian or related adnexal tissues.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'LEUKAEMIA',
 'Leukaemia',
 'Malignant clonal proliferation of haematopoietic cells.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'LYMPHOMA',
 'Lymphoma',
 'Malignant neoplasm arising from lymphoid tissues.',
 'neoplastic'),

(gen_random_uuid(), NULL, 'MULTIPLE_MYELOMA',
 'Multiple myeloma',
 'Plasma-cell malignancy involving bone marrow and associated systemic manifestations.',
 'neoplastic')


ON CONFLICT (condition_code) DO NOTHING;


-- =============================================================================
-- 2. UNIVERSAL BODY-SYSTEM ASSOCIATION
-- =============================================================================
--
-- This layer allows a condition to participate in more than one physiological
-- system. A disease is therefore not forced into a single specialty box.
--
-- =============================================================================


INSERT INTO knowledge.condition_system
    (condition_id, body_system_code, weight)
SELECT c.id, x.body_system_code, x.weight
FROM (
    VALUES

    ('PNEUMONIA','RESPIRATORY',1.0),
    ('PNEUMONIA','IMMUNE',0.5),

    ('TUBERCULOSIS','RESPIRATORY',1.0),
    ('TUBERCULOSIS','IMMUNE',0.8),
    ('TUBERCULOSIS','CONSTITUTIONAL',0.7),

    ('ASTHMA','RESPIRATORY',1.0),
    ('COPD','RESPIRATORY',1.0),
    ('PULMONARY_EMBOLISM','RESPIRATORY',0.9),
    ('PULMONARY_EMBOLISM','CARDIOVASCULAR',1.0),

    ('HYPERTENSION','CARDIOVASCULAR',1.0),
    ('HEART_FAILURE','CARDIOVASCULAR',1.0),
    ('HEART_FAILURE','RENAL',0.5),
    ('HEART_FAILURE','RESPIRATORY',0.7),

    ('CORONARY_ARTERY_DISEASE','CARDIOVASCULAR',1.0),
    ('ACUTE_CORONARY_SYNDROME','CARDIOVASCULAR',1.0),

    ('STROKE','NERVOUS',1.0),
    ('MENINGITIS','NERVOUS',1.0),
    ('MENINGITIS','IMMUNE',0.7),
    ('EPILEPSY','NERVOUS',1.0),

    ('DIABETES_MELLITUS','ENDOCRINE',1.0),
    ('DIABETES_MELLITUS','METABOLIC',1.0),
    ('DIABETES_MELLITUS','RENAL',0.5),
    ('DIABETES_MELLITUS','CARDIOVASCULAR',0.6),

    ('ACUTE_KIDNEY_INJURY','RENAL',1.0),
    ('CHRONIC_KIDNEY_DISEASE','RENAL',1.0),
    ('CHRONIC_KIDNEY_DISEASE','CARDIOVASCULAR',0.6),

    ('CIRRHOSIS','HEPATOBILIARY',1.0),
    ('CIRRHOSIS','GASTROINTESTINAL',0.7),

    ('PREECLAMPSIA','OBSTETRIC',1.0),
    ('PREECLAMPSIA','CARDIOVASCULAR',0.8),
    ('PREECLAMPSIA','RENAL',0.6),

    ('ECLAMPSIA','OBSTETRIC',1.0),
    ('ECLAMPSIA','NERVOUS',0.8),

    ('MALARIA','INFECTIOUS',1.0),
    ('MALARIA','HAEMATOLOGICAL',0.6),

    ('SEPSIS','INFECTIOUS',1.0),
    ('SEPSIS','IMMUNE',0.9),
    ('SEPSIS','CARDIOVASCULAR',0.8),
    ('SEPSIS','RENAL',0.5),

    ('OSTEOARTHRITIS','MUSCULOSKELETAL',1.0),
    ('RHEUMATOID_ARTHRITIS','MUSCULOSKELETAL',1.0),
    ('RHEUMATOID_ARTHRITIS','IMMUNE',1.0),

    ('SYSTEMIC_LUPUS_ERYTHEMATOSUS','IMMUNE',1.0),
    ('SYSTEMIC_LUPUS_ERYTHEMATOSUS','RENAL',0.6),
    ('SYSTEMIC_LUPUS_ERYTHEMATOSUS','NERVOUS',0.4),

    ('MAJOR_DEPRESSIVE_DISORDER','PSYCHIATRIC',1.0),
    ('DELIRIUM','NERVOUS',1.0),
    ('DELIRIUM','CONSTITUTIONAL',0.5),

    ('BREAST_CANCER','ONCOLOGICAL',1.0),
    ('BREAST_CANCER','REPRODUCTIVE',0.5),

    ('FRACTURE','MUSCULOSKELETAL',1.0),
    ('TRAUMATIC_BRAIN_INJURY','NERVOUS',1.0),
    ('TRAUMATIC_BRAIN_INJURY','MULTISYSTEM',1.0)

) AS x(condition_code, body_system_code, weight)
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
ON CONFLICT (condition_id, body_system_code) DO NOTHING;


-- =============================================================================
-- 3. UNIVERSAL SPECIALTY ASSOCIATION
-- =============================================================================


INSERT INTO knowledge.condition_specialty
    (condition_id, specialty_code, weight)
SELECT c.id, x.specialty_code, x.weight
FROM (
    VALUES

    ('PNEUMONIA','internal_medicine',1.0),
    ('PNEUMONIA','family_medicine',0.9),
    ('PNEUMONIA','paediatrics',0.9),
    ('PNEUMONIA','emergency_medicine',0.9),

    ('TUBERCULOSIS','internal_medicine',1.0),
    ('TUBERCULOSIS','pulmonology',1.0),
    ('TUBERCULOSIS','paediatrics',0.8),
    ('TUBERCULOSIS','infectious_diseases',1.0),

    ('ASTHMA','pulmonology',1.0),
    ('ASTHMA','paediatrics',0.9),
    ('ASTHMA','family_medicine',0.9),

    ('COPD','pulmonology',1.0),
    ('COPD','internal_medicine',0.9),

    ('HYPERTENSION','internal_medicine',1.0),
    ('HYPERTENSION','family_medicine',1.0),
    ('HYPERTENSION','cardiology',0.8),

    ('HEART_FAILURE','cardiology',1.0),
    ('HEART_FAILURE','internal_medicine',1.0),

    ('ACUTE_CORONARY_SYNDROME','cardiology',1.0),
    ('ACUTE_CORONARY_SYNDROME','emergency_medicine',1.0),

    ('STROKE','neurology',1.0),
    ('STROKE','emergency_medicine',1.0),
    ('STROKE','internal_medicine',0.9),

    ('MENINGITIS','infectious_diseases',1.0),
    ('MENINGITIS','neurology',1.0),
    ('MENINGITIS','paediatrics',0.9),

    ('DIABETES_MELLITUS','endocrinology',1.0),
    ('DIABETES_MELLITUS','internal_medicine',1.0),
    ('DIABETES_MELLITUS','family_medicine',0.9),

    ('ACUTE_KIDNEY_INJURY','nephrology',1.0),
    ('CHRONIC_KIDNEY_DISEASE','nephrology',1.0),

    ('APPENDICITIS','surgery',1.0),
    ('INTESTINAL_OBSTRUCTION','surgery',1.0),
    ('PERITONITIS','surgery',1.0),

    ('PREECLAMPSIA','obstetrics_gynaecology',1.0),
    ('ECLAMPSIA','obstetrics_gynaecology',1.0),

    ('ECTOPIC_PREGNANCY','obstetrics_gynaecology',1.0),
    ('POSTPARTUM_HAEMORRHAGE','obstetrics_gynaecology',1.0),

    ('POLYCYSTIC_OVARY_SYNDROME','obstetrics_gynaecology',1.0),
    ('ENDOMETRIOSIS','obstetrics_gynaecology',1.0),

    ('OSTEOARTHRITIS','orthopaedics',0.9),
    ('OSTEOARTHRITIS','rheumatology',0.9),

    ('RHEUMATOID_ARTHRITIS','rheumatology',1.0),

    ('FRACTURE','orthopaedics',1.0),
    ('FRACTURE','emergency_medicine',0.8),

    ('BREAST_CANCER','oncology',1.0),
    ('BREAST_CANCER','surgery',0.9),
    ('BREAST_CANCER','surgery',1.0),

    ('MAJOR_DEPRESSIVE_DISORDER','psychiatry',1.0),
    ('SCHIZOPHRENIA','psychiatry',1.0),

    ('CATARACT','ophthalmology',1.0),
    ('GLAUCOMA','ophthalmology',1.0),

    ('OTITIS_MEDIA','ent',1.0),
    ('TONSILLITIS','ent',0.9),

    ('CELLULITIS','dermatology',0.9),
    ('CELLULITIS','infectious_diseases',0.8)

) AS x(condition_code, specialty_code, weight)
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
ON CONFLICT (condition_id, specialty_code) DO NOTHING;


-- =============================================================================
-- 4. UNIVERSAL RISK FACTOR ASSOCIATIONS
-- =============================================================================
--
-- These are deliberately broad. Detailed risk-factor semantics belong in the
-- risk-factor layer and fact engine.
-- =============================================================================


INSERT INTO knowledge.condition_risk_factor
    (condition_id, risk_factor_concept_id, risk_factor_code, weight, description)
SELECT
    c.id,
    NULL,
    x.risk_factor_code,
    x.weight,
    x.description
FROM (
    VALUES

    ('PNEUMONIA','SMOKING',0.7,
     'Smoking increases susceptibility to respiratory infection and pulmonary complications'),

    ('PNEUMONIA','IMMUNOCOMPROMISED',0.9,
     'Impaired host immunity increases risk of severe infection'),

    ('PNEUMONIA','EXTREMES_OF_AGE',0.8,
     'Infancy and advanced age increase vulnerability'),

    ('TUBERCULOSIS','TB_EXPOSURE',1.0,
     'Known exposure increases likelihood of tuberculosis infection'),

    ('TUBERCULOSIS','HIV_INFECTION',1.0,
     'HIV substantially increases risk of tuberculosis'),

    ('TUBERCULOSIS','IMMUNOSUPPRESSION',0.9,
     'Immunosuppression increases risk of active tuberculosis'),

    ('ASTHMA','ATOPY',0.8,
     'Atopic disease is associated with asthma'),

    ('ASTHMA','ALLERGEN_EXPOSURE',0.8,
     'Relevant allergens may precipitate symptoms'),

    ('COPD','SMOKING',1.0,
     'Tobacco exposure is a major risk factor'),

    ('COPD','BIOMASS_SMOKE',0.8,
     'Long-term household biomass exposure may contribute to chronic airflow limitation'),

    ('HYPERTENSION','OBESITY',0.7,
     'Excess adiposity is associated with hypertension'),

    ('HYPERTENSION','HIGH_SALT_INTAKE',0.6,
     'High sodium intake may contribute to elevated blood pressure'),

    ('HYPERTENSION','FAMILY_HISTORY',0.7,
     'Family history contributes to hypertension risk'),

    ('CORONARY_ARTERY_DISEASE','SMOKING',0.9,
     'Smoking is a major cardiovascular risk factor'),

    ('CORONARY_ARTERY_DISEASE','DIABETES_MELLITUS',0.8,
     'Diabetes increases atherosclerotic cardiovascular risk'),

    ('CORONARY_ARTERY_DISEASE','HYPERTENSION',0.8,
     'Hypertension increases atherosclerotic cardiovascular risk'),

    ('STROKE','HYPERTENSION',1.0,
     'Hypertension is a major modifiable stroke risk factor'),

    ('STROKE','ATRIAL_FIBRILLATION',0.8,
     'Atrial fibrillation increases embolic stroke risk'),

    ('DIABETES_MELLITUS','OBESITY',0.9,
     'Obesity is strongly associated with type 2 diabetes'),

    ('DIABETES_MELLITUS','FAMILY_HISTORY',0.8,
     'Family history increases risk'),

    ('ACUTE_KIDNEY_INJURY','SEPSIS',0.9,
     'Sepsis is a major cause of acute kidney injury'),

    ('ACUTE_KIDNEY_INJURY','NEPHROTOXIN_EXPOSURE',0.8,
     'Nephrotoxins can cause acute kidney injury'),

    ('CHRONIC_KIDNEY_DISEASE','DIABETES_MELLITUS',0.9,
     'Diabetes is a major cause of chronic kidney disease'),

    ('CHRONIC_KIDNEY_DISEASE','HYPERTENSION',0.9,
     'Hypertension is a major cause and consequence of CKD'),

    ('PREECLAMPSIA','FIRST_PREGNANCY',0.6,
     'Nulliparity is associated with increased risk'),

    ('PREECLAMPSIA','MULTIPLE_GESTATION',0.8,
     'Multiple pregnancy increases risk'),

    ('PREECLAMPSIA','PREVIOUS_PREECLAMPSIA',1.0,
     'Previous preeclampsia increases recurrence risk'),

    ('ECTOPIC_PREGNANCY','PREVIOUS_ECTOPIC_PREGNANCY',1.0,
     'Previous ectopic pregnancy increases recurrence risk'),

    ('ECTOPIC_PREGNANCY','PELVIC_INFLAMMATORY_DISEASE',0.9,
     'Tubal damage from PID increases ectopic pregnancy risk'),

    ('OSTEOARTHRITIS','AGE',0.8,
     'Risk increases with age'),

    ('OSTEOARTHRITIS','PREVIOUS_JOINT_INJURY',0.8,
     'Previous joint injury increases risk of post-traumatic osteoarthritis'),

    ('OSTEOPOROSIS','AGE',0.9,
     'Bone loss and fracture risk increase with age'),

    ('OSTEOPOROSIS','CORTICOSTEROID_EXPOSURE',0.9,
     'Long-term systemic corticosteroids increase fracture risk'),

    ('BREAST_CANCER','FAMILY_HISTORY',0.8,
     'Family history may increase breast cancer risk'),

    ('BREAST_CANCER','AGE',0.8,
     'Breast cancer risk increases with age'),

    ('LUNG_CANCER','SMOKING',1.0,
     'Smoking is the major preventable risk factor'),

    ('COLORECTAL_CANCER','AGE',0.8,
     'Risk increases with age'),

    ('COLORECTAL_CANCER','FAMILY_HISTORY',0.8,
     'Family history increases risk'),

    ('CERVICAL_CANCER','HPV_INFECTION',1.0,
     'Persistent oncogenic HPV infection is central to cervical carcinogenesis'),

    ('MALARIA','MOSQUITO_EXPOSURE',1.0,
     'Exposure to infected Anopheles mosquitoes permits transmission'),

    ('SEPSIS','INFECTION',1.0,
     'Sepsis occurs in the setting of infection'),

    ('HIV_INFECTION','UNPROTECTED_SEXUAL_EXPOSURE',0.8,
     'Sexual exposure may transmit HIV'),

    ('HIV_INFECTION','BLOOD_EXPOSURE',0.8,
     'Exposure to infected blood can transmit HIV')

) AS x(condition_code, risk_factor_code, weight, description)
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. UNIVERSAL COMPLICATION LIBRARY
-- =============================================================================
--
-- Complications are represented as graph edges rather than being buried in
-- disease descriptions.
-- =============================================================================


INSERT INTO knowledge.condition_complication
    (condition_id, complication_concept_id, complication_code, probability_weight, description)
SELECT
    c.id,
    NULL,
    x.complication_code,
    x.weight,
    x.description
FROM (
    VALUES

    ('PNEUMONIA','RESPIRATORY_FAILURE',0.8,
     'Severe pneumonia may impair gas exchange and progress to respiratory failure'),

    ('PNEUMONIA','SEPSIS',0.7,
     'Pulmonary infection may cause systemic infection and organ dysfunction'),

    ('PNEUMONIA','PLEURAL_EFFUSION',0.5,
     'Parapneumonic pleural fluid may develop'),

    ('TUBERCULOSIS','RESPIRATORY_FAILURE',0.5,
     'Advanced pulmonary disease may impair respiratory function'),

    ('TUBERCULOSIS','HAEMOPTYSIS',0.6,
     'Pulmonary TB may cause airway bleeding'),

    ('ASTHMA','RESPIRATORY_FAILURE',0.7,
     'Severe exacerbation may cause life-threatening respiratory failure'),

    ('COPD','RESPIRATORY_FAILURE',0.7,
     'Advanced disease and exacerbations may cause respiratory failure'),

    ('PULMONARY_EMBOLISM','SHOCK',0.8,
     'Massive pulmonary embolism can cause obstructive shock'),

    ('PULMONARY_EMBOLISM','SUDDEN_DEATH',0.8,
     'Severe pulmonary embolism can be fatal'),

    ('HEART_FAILURE','PULMONARY_OEDEMA',0.8,
     'Left-sided cardiac dysfunction can cause pulmonary congestion and oedema'),

    ('HEART_FAILURE','RENAL_DYSFUNCTION',0.6,
     'Cardiorenal interaction may cause or worsen renal dysfunction'),

    ('ACUTE_CORONARY_SYNDROME','ARRHYTHMIA',0.7,
     'Myocardial ischaemia may cause malignant arrhythmias'),

    ('ACUTE_CORONARY_SYNDROME','CARDIOGENIC_SHOCK',0.6,
     'Extensive myocardial injury may result in cardiogenic shock'),

    ('STROKE','CEREBRAL_OEDEMA',0.6,
     'Large cerebral infarction or haemorrhage may cause brain swelling'),

    ('STROKE','ASPIRATION_PNEUMONIA',0.6,
     'Dysphagia and impaired airway protection increase aspiration risk'),

    ('MENINGITIS','SEIZURES',0.7,
     'CNS inflammation may provoke seizures'),

    ('MENINGITIS','HEARING_LOSS',0.5,
     'Certain forms of meningitis may cause sensorineural hearing loss'),

    ('DIABETIC_KETOACIDOSIS','CEREBRAL_OEDEMA',0.5,
     'Cerebral oedema is a recognised severe complication, particularly in children'),

    ('DIABETES_MELLITUS','CHRONIC_KIDNEY_DISEASE',0.7,
     'Diabetes can cause chronic kidney disease'),

    ('DIABETES_MELLITUS','RETINOPATHY',0.7,
     'Chronic hyperglycaemia can damage retinal microvasculature'),

    ('DIABETES_MELLITUS','NEUROPATHY',0.7,
     'Chronic hyperglycaemia can cause peripheral and autonomic neuropathy'),

    ('SEPSIS','ACUTE_KIDNEY_INJURY',0.8,
     'Sepsis commonly causes acute kidney injury'),

    ('SEPSIS','RESPIRATORY_FAILURE',0.7,
     'Sepsis may cause severe pulmonary dysfunction'),

    ('SEPSIS','SHOCK',0.9,
     'Septic shock is a severe complication of sepsis'),

    ('CIRRHOSIS','ASCITES',0.8,
     'Portal hypertension and sodium retention may produce ascites'),

    ('CIRRHOSIS','HEPATIC_ENCEPHALOPATHY',0.7,
     'Advanced liver dysfunction can impair cerebral function'),

    ('CIRRHOSIS','VARICEAL_HAEMORRHAGE',0.7,
     'Portal hypertension may produce gastro-oesophageal varices'),

    ('ACUTE_KIDNEY_INJURY','HYPERKALAEMIA',0.7,
     'Reduced renal excretion can cause potassium accumulation'),

    ('CHRONIC_KIDNEY_DISEASE','ANAEMIA',0.7,
     'Reduced erythropoietin production contributes to anaemia'),

    ('CHRONIC_KIDNEY_DISEASE','HYPERKALAEMIA',0.6,
     'Advanced renal dysfunction may impair potassium excretion'),

    ('PREECLAMPSIA','ECLAMPSIA',0.7,
     'Severe hypertensive disease may progress to seizures'),

    ('PREECLAMPSIA','HELLP_SYNDROME',0.5,
     'Severe disease may be associated with haemolysis, liver dysfunction and thrombocytopenia'),

    ('PREECLAMPSIA','PLACENTAL_ABRUPTION',0.5,
     'Hypertensive placental disease increases abruption risk'),

    ('ECTOPIC_PREGNANCY','HAEMORRHAGIC_SHOCK',0.8,
     'Tubal rupture may cause severe intra-abdominal haemorrhage'),

    ('POSTPARTUM_HAEMORRHAGE','HAEMORRHAGIC_SHOCK',0.9,
     'Severe blood loss may produce circulatory shock'),

    ('SICKLE_CELL_DISEASE','ACUTE_CHEST_SYNDROME',0.8,
     'Sickle cell disease may produce acute pulmonary vaso-occlusive complications'),

    ('SICKLE_CELL_DISEASE','STROKE',0.6,
     'Cerebrovascular complications may occur'),

    ('OSTEOPOROSIS','FRACTURE',0.9,
     'Reduced bone strength increases fragility fracture risk'),

    ('ANAPHYLAXIS','AIRWAY_OBSTRUCTION',0.9,
     'Upper airway oedema can rapidly compromise the airway'),

    ('ANAPHYLAXIS','SHOCK',0.9,
     'Systemic vasodilation and capillary leak may cause distributive shock'),

    ('BREAST_CANCER','METASTATIC_DISEASE',0.8,
     'Breast malignancy may metastasise to distant organs'),

    ('LUNG_CANCER','METASTATIC_DISEASE',0.8,
     'Lung malignancy may metastasise'),

    ('COLORECTAL_CANCER','BOWEL_OBSTRUCTION',0.5,
     'Advanced colorectal tumours may obstruct the bowel'),

    ('ACUTE_APPENDICITIS','PERFORATION',0.6,
     'Untreated appendicitis may perforate'),

    ('PERITONITIS','SEPSIS',0.8,
     'Peritoneal infection can produce systemic infection and organ dysfunction'),

    ('STRANGULATED_HERNIA','BOWEL_ISCHAEMIA',0.8,
     'Compromised blood supply can cause bowel ischaemia and necrosis'),

    ('SEPTIC_ARTHRITIS','JOINT_DESTRUCTION',0.8,
     'Untreated joint infection can rapidly damage articular structures'),

    ('STEVENS_JOHNSON_SYNDROME','SEPSIS',0.6,
     'Extensive epithelial disruption increases infection risk'),

    ('TOXIC_EPITHELIAL_NECROLYSIS','SEPSIS',0.8,
     'Extensive skin barrier loss predisposes to severe infection'),

    ('DELIRIUM','FALLS',0.5,
     'Impaired attention and cognition increase risk of falls'),

    ('SCHIZOPHRENIA','SELF_HARM',0.5,
     'Psychotic illness may be associated with elevated self-harm risk')

) AS x(condition_code, complication_code, weight, description)
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. UNIVERSAL DIFFERENTIAL RELATIONSHIPS
-- =============================================================================
--
-- Differential diagnosis is explicitly directional.
--
-- A <-> B does not mean "same disease".
-- It means that the clinical presentation may require differentiation.
-- =============================================================================


INSERT INTO knowledge.condition_differential
    (condition_id, differential_condition_id, relationship_type, weight)
SELECT
    a.id,
    b.id,
    x.relationship_type,
    x.weight
FROM (
    VALUES

    ('PNEUMONIA','ACUTE_BRONCHITIS','differentiates',0.8),
    ('PNEUMONIA','PULMONARY_EMBOLISM','differentiates',0.7),
    ('PNEUMONIA','TUBERCULOSIS','differentiates',0.8),

    ('ASTHMA','COPD','differentiates',0.8),
    ('ASTHMA','HEART_FAILURE','differentiates',0.5),

    ('COPD','HEART_FAILURE','differentiates',0.6),
    ('COPD','PULMONARY_EMBOLISM','differentiates',0.6),

    ('ACUTE_CORONARY_SYNDROME','PULMONARY_EMBOLISM','differentiates',0.7),
    ('ACUTE_CORONARY_SYNDROME','AORTIC_DISSECTION','differentiates',0.8),

    ('STROKE','HYPOGLYCAEMIA','differentiates',0.8),
    ('STROKE','SEIZURE','differentiates',0.6),

    ('MENINGITIS','ENCEPHALITIS','differentiates',0.8),
    ('MENINGITIS','SUBARACHNOID_HAEMORRHAGE','differentiates',0.7),

    ('ACUTE_KIDNEY_INJURY','CHRONIC_KIDNEY_DISEASE','differentiates',0.7),

    ('APPENDICITIS','ECTOPIC_PREGNANCY','differentiates',0.7),
    ('APPENDICITIS','MESENTERIC_ISCHAEMIA','differentiates',0.6),

    ('ECTOPIC_PREGNANCY','MISCARRIAGE','differentiates',0.9),

    ('PREECLAMPSIA','CHRONIC_HYPERTENSION','differentiates',0.8),

    ('OSTEOARTHRITIS','RHEUMATOID_ARTHRITIS','differentiates',0.8),
    ('RHEUMATOID_ARTHRITIS','GOUT','differentiates',0.7),

    ('CELLULITIS','DEEP_VEIN_THROMBOSIS','differentiates',0.6),

    ('MAJOR_DEPRESSIVE_DISORDER','BIPOLAR_DISORDER','differentiates',0.8),
    ('DELIRIUM','SCHIZOPHRENIA','differentiates',0.7),

    ('GLAUCOMA','ACUTE_ANGLE_CLOSURE_GLAUCOMA','differentiates',0.7),

    ('OTITIS_MEDIA','OTITIS_EXTERNA','differentiates',0.7)

) AS x(a_code,b_code,relationship_type,weight)
JOIN knowledge.condition a
  ON a.condition_code = x.a_code
JOIN knowledge.condition b
  ON b.condition_code = x.b_code
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. EXISTING MECHANISM -> CONDITION JUNCTIONS
-- =============================================================================
--
-- Existing respiratory mechanisms remain valid.
-- Universal mechanisms from later seeds can join the same table.
-- =============================================================================


INSERT INTO knowledge.mechanism_condition
    (mechanism_id, condition_id, weight)
SELECT m.id, c.id, x.weight
FROM (
    VALUES

    ('MECH-AIRWAY-INFLAMMATION','ASTHMA',0.9),
    ('MECH-AIRWAY-INFLAMMATION','COPD',0.8),
    ('MECH-AIRWAY-INFLAMMATION','ACUTE_BRONCHITIS',0.9),

    ('MECH-ALVEOLAR-INFLAMMATION','PNEUMONIA',1.0),

    ('MECH-AIRWAY-OBSTRUCTION','ASTHMA',0.9),
    ('MECH-AIRWAY-OBSTRUCTION','COPD',0.8),

    ('MECH-PLEURAL-INFLAMMATION','PLEURAL_EFFUSION',0.8)

) AS x(mechanism_code,condition_code,weight)
JOIN knowledge.mechanism m
  ON m.mechanism_code = x.mechanism_code
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. PHENOTYPE -> CONDITION GRAPH
-- =============================================================================
--
-- Only use phenotypes that actually exist in the current phenotype seed.
-- New universal phenotypes can be connected by later phenotype seeds.
-- =============================================================================


INSERT INTO knowledge.phenotype_differential
    (phenotype_id, condition_id, relationship_type, weight)
SELECT p.id, c.id, x.relationship_type, x.weight
FROM (
    VALUES

    ('PHEN-ACUTE-LRTI','PNEUMONIA','suggestive_of',0.9),
    ('PHEN-ACUTE-LRTI','ACUTE_BRONCHITIS','suggestive_of',0.7),

    ('PHEN-CHRONIC-PRODUCTIVE','TUBERCULOSIS','suggestive_of',0.9),

    ('PHEN-HYPOXAEMIA','PNEUMONIA','compatible_with',0.6),
    ('PHEN-HYPOXAEMIA','PULMONARY_EMBOLISM','compatible_with',0.6),
    ('PHEN-HYPOXAEMIA','COPD','compatible_with',0.5),

    ('PHEN-RESPIRATORY-FAILURE','PNEUMONIA','compatible_with',0.6),
    ('PHEN-RESPIRATORY-FAILURE','ASTHMA','compatible_with',0.6),
    ('PHEN-RESPIRATORY-FAILURE','COPD','compatible_with',0.6)

) AS x(phenotype_code,condition_code,relationship_type,weight)
JOIN knowledge.phenotype p
  ON p.phenotype_code = x.phenotype_code
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. CONDITION -> PHENOTYPE
-- =============================================================================


INSERT INTO knowledge.condition_phenotype
    (condition_id, phenotype_id, weight, is_suggestive)
SELECT c.id, p.id, x.weight, x.is_suggestive
FROM (
    VALUES

    ('PNEUMONIA','PHEN-ACUTE-LRTI',0.9,true),
    ('PNEUMONIA','PHEN-HYPOXAEMIA',0.6,false),
    ('PNEUMONIA','PHEN-RESPIRATORY-FAILURE',0.5,false),

    ('TUBERCULOSIS','PHEN-CHRONIC-PRODUCTIVE',0.9,true),

    ('ACUTE_BRONCHITIS','PHEN-ACUTE-LRTI',0.7,true),

    ('ASTHMA','PHEN-HYPOXAEMIA',0.4,false),
    ('COPD','PHEN-HYPOXAEMIA',0.6,false),
    ('PULMONARY_EMBOLISM','PHEN-HYPOXAEMIA',0.6,false)

) AS x(condition_code,phenotype_code,weight,is_suggestive)
JOIN knowledge.condition c
  ON c.condition_code = x.condition_code
JOIN knowledge.phenotype p
  ON p.phenotype_code = x.phenotype_code
ON CONFLICT (condition_id, phenotype_id) DO NOTHING;


-- =============================================================================
-- 10. UNIVERSAL KNOWLEDGE GRAPH EDGES
-- =============================================================================
--
-- relationship is the cross-layer graph.
--
-- It must remain generic enough to connect:
--
-- symptom
-- question
-- fact
-- phenotype
-- mechanism
-- condition
-- investigation
-- complication
-- risk factor
-- rule
-- management
-- medication
-- procedure
-- red flag
-- context
--
-- =============================================================================


INSERT INTO knowledge.relationship
    (
        source_type,
        source_id,
        relationship_type,
        target_type,
        target_id,
        weight,
        polarity,
        context,
        confidence,
        evidence
    )
SELECT
    x.source_type,
    s.id,
    x.relationship_type,
    x.target_type,
    t.id,
    x.weight,
    x.polarity,
    x.context,
    x.confidence,
    x.evidence
FROM (
    VALUES

    (
        'condition',
        'PNEUMONIA',
        'associated_with',
        'symptom',
        'SYM-COUGH',
        0.9,
        'positive',
        jsonb_build_object('pattern','acute_lower_respiratory'),
        0.95,
        'Core clinical presentation'
    ),

    (
        'condition',
        'PNEUMONIA',
        'associated_with',
        'symptom',
        'SYM-FEVER',
        0.8,
        'positive',
        NULL,
        0.95,
        'Core infectious presentation'
    ),

    (
        'condition',
        'TUBERCULOSIS',
        'associated_with',
        'symptom',
        'SYM-WEIGHT-LOSS',
        0.9,
        'positive',
        jsonb_build_object('pattern','constitutional'),
        0.9,
        'Characteristic constitutional manifestation'
    ),

    (
        'condition',
        'TUBERCULOSIS',
        'associated_with',
        'symptom',
        'SYM-NIGHT-SWEATS',
        0.8,
        'positive',
        jsonb_build_object('pattern','constitutional'),
        0.9,
        'Characteristic constitutional manifestation'
    ),

    (
        'condition',
        'PNEUMONIA',
        'associated_with',
        'symptom',
        'SYM-DYSPNOEA',
        0.7,
        'positive',
        NULL,
        0.9,
        'May occur with clinically significant lower respiratory disease'
    ),

    (
        'condition',
        'TUBERCULOSIS',
        'associated_with',
        'symptom',
        'SYM-HAEMOPTYSIS',
        0.5,
        'positive',
        NULL,
        0.85,
        'May occur in pulmonary tuberculosis'
    )

) AS x(
    source_type,
    source_code,
    relationship_type,
    target_type,
    target_code,
    weight,
    polarity,
    context,
    confidence,
    evidence
)
JOIN knowledge.condition s
  ON s.condition_code = x.source_code
JOIN knowledge.symptom t
  ON t.symptom_code = x.target_code;


-- =============================================================================
-- 11. CONDITION CLASSIFICATION / UNIVERSAL METADATA
-- =============================================================================
--
-- The following graph relationships make conditions machine-addressable by
-- clinical domain without forcing one condition into one specialty.
-- =============================================================================


;


-- =============================================================================
-- 12. UNIVERSAL CONDITION GRAPH INTEGRITY CHECKS
-- =============================================================================
--
-- These do not modify data.
-- They make deployment/testing easier.
-- =============================================================================


DO $$
DECLARE
    missing_conditions INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO missing_conditions
    FROM (
        VALUES
        ('PNEUMONIA'),
        ('TUBERCULOSIS'),
        ('ASTHMA'),
        ('COPD'),
        ('HYPERTENSION'),
        ('HEART_FAILURE'),
        ('STROKE'),
        ('DIABETES_MELLITUS'),
        ('SEPSIS'),
        ('ACUTE_KIDNEY_INJURY'),
        ('PREECLAMPSIA'),
        ('ECTOPIC_PREGNANCY'),
        ('APPENDICITIS'),
        ('FRACTURE'),
        ('BREAST_CANCER'),
        ('MAJOR_DEPRESSIVE_DISORDER')
    ) AS expected(condition_code)
    WHERE NOT EXISTS (
        SELECT 1
        FROM knowledge.condition c
        WHERE c.condition_code = expected.condition_code
    );

    IF missing_conditions > 0 THEN
        RAISE EXCEPTION
            'AMEXAN Z6 integrity failure: % expected universal conditions missing',
            missing_conditions;
    END IF;

END $$;


COMMIT;


-- =============================================================================
-- END AMEXAN PHASE 2 — SEED Z6
-- =============================================================================