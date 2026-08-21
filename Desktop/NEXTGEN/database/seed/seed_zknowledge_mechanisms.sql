-- =============================================================================
-- AMEXAN Phase 2 — Seed Z5: UNIVERSAL MEDICAL MECHANISM + PHENOTYPE LIBRARY
-- =============================================================================
-- Purpose:
--   Reusable pathophysiological intelligence for AMEXAN Clinical Intelligence.
--
-- Design principles:
--   1. Disease is NOT the primary unit of reasoning.
--   2. Symptoms/findings -> mechanisms -> phenotypes -> conditions.
--   3. One mechanism may participate in MANY diseases.
--   4. One phenotype may occur across MANY specialties.
--   5. Context modifies phenotype expression; it does not duplicate concepts.
--   6. Positive and negative features are explicitly represented.
--   7. Weight represents evidentiary contribution, NOT probability.
--   8. This seed contains knowledge/reference data only.
--   9. No patient data.
--  10. Deterministic UUIDs permit repeatable deployment.
--  11. Existing AMEXAN Z1/Z2 concepts/context values are reused.
--  12. Designed for longitudinal EMR/HMS/health-information exchange use.
--
-- IMPORTANT:
--   This file assumes the Z1/Z2 schema already exists and that the following
--   tables/columns are available:
--
--   knowledge.mechanism
--   knowledge.mechanism_feature
--   knowledge.phenotype
--   knowledge.phenotype_feature
--   knowledge.phenotype_context
--   knowledge.phenotype_documentation
--
--   It also assumes:
--   knowledge.concept(concept_id)
--   clinical.fact_definition(code)
--   knowledge.context_value(id)
--   knowledge.body_system(code)
--
--   Existing Z1 concept UUIDs are preserved.
-- =============================================================================


BEGIN;


-- =============================================================================
-- SECTION 1
-- UNIVERSAL PATHOPHYSIOLOGICAL MECHANISMS
-- =============================================================================
--
-- Mechanisms are deliberately broader than diagnoses.
--
-- Examples:
--   AIRWAY_OBSTRUCTION
--       -> asthma, COPD, bronchiolitis, foreign body, tumour
--
--   REDUCED_CARDIAC_OUTPUT
--       -> heart failure, shock, cardiomyopathy, MI
--
--   TISSUE_HYPOPERFUSION
--       -> sepsis, haemorrhage, cardiogenic shock, dehydration
--
--   INFLAMMATION
--       -> infection, autoimmune disease, inflammatory disease
--
--   This allows the intelligence engine to reason across specialties without
--   duplicating disease-specific logic.
-- =============================================================================


INSERT INTO knowledge.mechanism
(id, concept_id, mechanism_code, canonical_name, description, body_system_code)
VALUES

-- ---------------------------------------------------------------------------
-- RESPIRATORY
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000001',
 'f0a00000-0000-0000-0000-00000000000b',
 'MECH-AIRWAY-INFLAMMATION',
 'Airway inflammation',
 'Inflammation of the conducting airways causing cough, mucus production, oedema and variable airflow limitation.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000002',
 'f0a00000-0000-0000-0000-00000000000c',
 'MECH-ALVEOLAR-INFLAMMATION',
 'Alveolar inflammation',
 'Inflammation of the distal airspaces and lung parenchyma impairing ventilation and gas exchange.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000003',
 'f0a00000-0000-0000-0000-00000000000e',
 'MECH-AIRWAY-OBSTRUCTION',
 'Airway obstruction',
 'Fixed or variable obstruction of airflow caused by bronchoconstriction, mucus, oedema, foreign material or structural disease.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000004',
 'f0a00000-0000-0000-0000-00000000000d',
 'MECH-PLEURAL-INFLAMMATION',
 'Pleural inflammation',
 'Inflammation of the pleural surfaces producing pleuritic pain and potentially pleural effusion.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000005',
 NULL,
 'MECH-IMPAIRED-GAS-EXCHANGE',
 'Impaired gas exchange',
 'Failure of adequate oxygen and/or carbon dioxide exchange across the alveolar-capillary interface.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000006',
 NULL,
 'MECH-VENTILATION-FAILURE',
 'Ventilatory failure',
 'Inadequate alveolar ventilation resulting in impaired carbon dioxide clearance and potentially respiratory acidosis.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000007',
 NULL,
 'MECH-VQ-MISMATCH',
 'Ventilation-perfusion mismatch',
 'Mismatch between ventilation and pulmonary perfusion causing impaired oxygenation.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000008',
 NULL,
 'MECH-PULMONARY-VASCULAR-OCCLUSION',
 'Pulmonary vascular occlusion',
 'Obstruction of pulmonary arterial blood flow causing ventilation-perfusion disturbance and increased right ventricular strain.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-000000000009',
 NULL,
 'MECH-PULMONARY-CONGESTION',
 'Pulmonary congestion',
 'Accumulation of fluid within the pulmonary interstitium and/or alveoli due to increased hydrostatic pressure or other mechanisms.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-00000000000a',
 NULL,
 'MECH-REDUCED-LUNG-COMPLIANCE',
 'Reduced lung compliance',
 'Reduced distensibility of the respiratory system increasing the work of breathing.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-00000000000b',
 NULL,
 'MECH-BRONCHOSPASM',
 'Bronchospasm',
 'Reversible contraction of bronchial smooth muscle producing airflow limitation and wheeze.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-00000000000c',
 NULL,
 'MECH-MUCUS-HYPERSECRETION',
 'Mucus hypersecretion',
 'Excessive airway mucus production contributing to productive cough and airflow obstruction.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-00000000000d',
 NULL,
 'MECH-ALVEOLAR-FILLING',
 'Alveolar filling',
 'Replacement of normally aerated alveolar gas with inflammatory fluid, oedema, blood, cells or other material.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-00000000000e',
 NULL,
 'MECH-PLEURAL-EFFUSION',
 'Pleural effusion',
 'Accumulation of fluid in the pleural space causing impaired lung expansion and potentially respiratory compromise.',
 'RESPIRATORY'),

('f0e00000-0000-0000-0000-00000000000f',
 NULL,
 'MECH-PNEUMOTHORAX',
 'Pneumothorax',
 'Presence of air in the pleural space causing partial or complete lung collapse.',
 'RESPIRATORY'),

-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000010',
 NULL,
 'MECH-REDUCED-CARDIAC-OUTPUT',
 'Reduced cardiac output',
 'Inadequate forward cardiac output relative to tissue metabolic requirements.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000011',
 NULL,
 'MECH-LEFT-VENTRICULAR-DYSFUNCTION',
 'Left ventricular dysfunction',
 'Impaired left ventricular systolic and/or diastolic performance causing reduced output and/or pulmonary congestion.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000012',
 NULL,
 'MECH-RIGHT-VENTRICULAR-DYSFUNCTION',
 'Right ventricular dysfunction',
 'Impaired right ventricular performance causing systemic venous congestion and reduced pulmonary circulation.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000013',
 NULL,
 'MECH-VOLUME-OVERLOAD',
 'Volume overload',
 'Expansion of intravascular and extracellular fluid volume causing oedema and potentially pulmonary congestion.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000014',
 NULL,
 'MECH-PRESSURE-OVERLOAD',
 'Pressure overload',
 'Chronic or acute elevation in ventricular afterload causing myocardial adaptation and eventually dysfunction.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000015',
 NULL,
 'MECH-MYOCARDIAL-ISCHEMIA',
 'Myocardial ischaemia',
 'Insufficient myocardial oxygen delivery relative to myocardial oxygen demand.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000016',
 NULL,
 'MECH-MYOCARDIAL-NECROSIS',
 'Myocardial necrosis',
 'Irreversible myocardial cell injury and death resulting from severe or prolonged ischaemia or other injury.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000017',
 NULL,
 'MECH-ARRHYTHMIC-HEMODYNAMIC-IMPAIRMENT',
 'Arrhythmic haemodynamic impairment',
 'Abnormal cardiac rhythm reducing cardiac output, coronary perfusion or effective ventricular filling.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000018',
 NULL,
 'MECH-VASCULAR-OBSTRUCTION',
 'Vascular obstruction',
 'Partial or complete obstruction of arterial or venous blood flow.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-000000000019',
 NULL,
 'MECH-VASODILATION',
 'Pathological vasodilation',
 'Excessive reduction in systemic vascular tone producing hypotension and impaired effective tissue perfusion.',
 'CARDIOVASCULAR'),

('f0e00000-0000-0000-0000-00000000001a',
 NULL,
 'MECH-VASOCONSTRICTION',
 'Pathological vasoconstriction',
 'Excessive vascular smooth muscle constriction increasing vascular resistance and potentially reducing tissue perfusion.',
 'CARDIOVASCULAR'),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-00000000001b',
 NULL,
 'MECH-CEREBRAL-HYPOPERFUSION',
 'Cerebral hypoperfusion',
 'Insufficient cerebral blood flow resulting in neurological dysfunction.',
 'NEUROLOGICAL'),

('f0e00000-0000-0000-0000-00000000001c',
 NULL,
 'MECH-CEREBRAL-ISCHEMIA',
 'Cerebral ischaemia',
 'Reduced cerebral blood flow causing neuronal dysfunction and potentially infarction.',
 'NEUROLOGICAL'),

('f0e00000-0000-0000-0000-00000000001d',
 NULL,
 'MECH-CEREBRAL-EDEMA',
 'Cerebral oedema',
 'Abnormal accumulation of water within brain tissue causing increased intracranial pressure and/or neurological dysfunction.',
 'NEUROLOGICAL'),

('f0e00000-0000-0000-0000-00000000001e',
 NULL,
 'MECH-INTRACRANIAL-PRESSURE',
 'Raised intracranial pressure',
 'Pathological elevation of pressure within the cranial vault compromising cerebral perfusion and neurological function.',
 'NEUROLOGICAL'),

('f0e00000-0000-0000-0000-00000000001f',
 NULL,
 'MECH-NEURONAL-EXCITABILITY',
 'Abnormal neuronal excitability',
 'Excessive or dysregulated neuronal electrical activity producing seizures or other neurological manifestations.',
 'NEUROLOGICAL'),

('f0e00000-0000-0000-0000-000000000020',
 NULL,
 'MECH-NEUROTRANSMITTER-DYSREGULATION',
 'Neurotransmitter dysregulation',
 'Altered synthesis, release, degradation or receptor response of neurotransmitters.',
 'NEUROLOGICAL'),

('f0e00000-0000-0000-0000-000000000021',
 NULL,
 'MECH-PERIPHERAL-NERVE-DYSFUNCTION',
 'Peripheral nerve dysfunction',
 'Structural or functional impairment of peripheral nerves causing sensory, motor and/or autonomic manifestations.',
 'NEUROLOGICAL'),

-- ---------------------------------------------------------------------------
-- GASTROINTESTINAL
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000022',
 NULL,
 'MECH-GI-INFLAMMATION',
 'Gastrointestinal inflammation',
 'Inflammation of the gastrointestinal mucosa or wall causing pain, diarrhoea, bleeding or altered bowel function.',
 'GASTROINTESTINAL'),

('f0e00000-0000-0000-0000-000000000023',
 NULL,
 'MECH-GI-OBSTRUCTION',
 'Gastrointestinal obstruction',
 'Mechanical or functional interruption of gastrointestinal transit.',
 'GASTROINTESTINAL'),

('f0e00000-0000-0000-0000-000000000024',
 NULL,
 'MECH-GI-BLEEDING',
 'Gastrointestinal bleeding',
 'Loss of blood from the gastrointestinal tract causing overt or occult blood loss.',
 'GASTROINTESTINAL'),

('f0e00000-0000-0000-0000-000000000025',
 NULL,
 'MECH-MALABSORPTION',
 'Malabsorption',
 'Impaired digestion or absorption of nutrients from the gastrointestinal tract.',
 'GASTROINTESTINAL'),

('f0e00000-0000-0000-0000-000000000026',
 NULL,
 'MECH-PORTAL-HYPERTENSION',
 'Portal hypertension',
 'Pathological elevation of portal venous pressure causing collateral circulation, splenomegaly, ascites and/or variceal bleeding.',
 'GASTROINTESTINAL'),

('f0e00000-0000-0000-0000-000000000027',
 NULL,
 'MECH-CHOLESTASIS',
 'Cholestasis',
 'Impaired bile formation or flow causing accumulation of bile constituents.',
 'GASTROINTESTINAL'),

('f0e00000-0000-0000-0000-000000000028',
 NULL,
 'MECH-HEPATOCELLULAR-INJURY',
 'Hepatocellular injury',
 'Damage to hepatocytes causing leakage of intracellular enzymes and impaired liver function when extensive.',
 'GASTROINTESTINAL'),

-- ---------------------------------------------------------------------------
-- RENAL / URINARY
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000029',
 NULL,
 'MECH-REDUCED-GFR',
 'Reduced glomerular filtration',
 'Reduction in effective glomerular filtration resulting in impaired clearance of metabolic waste and altered fluid/electrolyte balance.',
 'RENAL_URINARY'),

('f0e00000-0000-0000-0000-00000000002a',
 NULL,
 'MECH-GLOMERULAR-INJURY',
 'Glomerular injury',
 'Damage to glomerular structures causing abnormal filtration and potentially proteinuria and haematuria.',
 'RENAL_URINARY'),

('f0e00000-0000-0000-0000-00000000002b',
 NULL,
 'MECH-TUBULAR-INJURY',
 'Tubular injury',
 'Damage to renal tubular epithelium impairing reabsorption, secretion and urine concentration.',
 'RENAL_URINARY'),

('f0e00000-0000-0000-0000-00000000002c',
 NULL,
 'MECH-POSTRENAL-OBSTRUCTION',
 'Postrenal obstruction',
 'Obstruction to urinary outflow causing increased upstream pressure and potentially impaired renal function.',
 'RENAL_URINARY'),

('f0e00000-0000-0000-0000-00000000002d',
 NULL,
 'MECH-FLUID-LOSS',
 'Pathological fluid loss',
 'Excessive loss of body fluid through gastrointestinal, renal, cutaneous or other routes causing volume depletion.',
 'RENAL_URINARY'),

('f0e00000-0000-0000-0000-00000000002e',
 NULL,
 'MECH-FLUID-RETENTION',
 'Pathological fluid retention',
 'Retention of sodium and water causing expansion of extracellular fluid volume.',
 'RENAL_URINARY'),

-- ---------------------------------------------------------------------------
-- ENDOCRINE / METABOLIC
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-00000000002f',
 NULL,
 'MECH-INSULIN-DEFICIENCY',
 'Insulin deficiency',
 'Absolute or relative deficiency of effective insulin activity causing impaired glucose utilization and hyperglycaemia.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000030',
 NULL,
 'MECH-INSULIN-RESISTANCE',
 'Insulin resistance',
 'Reduced biological response to insulin requiring increased insulin activity to maintain glucose homeostasis.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000031',
 NULL,
 'MECH-HYPERTHYROID-METABOLIC-STATE',
 'Hypermetabolic thyroid state',
 'Excess thyroid hormone activity increasing metabolic demand and sympathetic activity.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000032',
 NULL,
 'MECH-HYPO-METABOLIC-STATE',
 'Hypometabolic thyroid state',
 'Reduced thyroid hormone activity causing decreased metabolic activity.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000033',
 NULL,
 'MECH-ELECTROLYTE-DISRUPTION',
 'Electrolyte disturbance',
 'Abnormal concentration or distribution of essential electrolytes affecting cellular, neuromuscular and cardiovascular function.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000034',
 NULL,
 'MECH-ACID-BASE-DISRUPTION',
 'Acid-base disturbance',
 'Primary or compensatory disturbance of systemic acid-base homeostasis.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000035',
 NULL,
 'MECH-HYPERGLYCAEMIA',
 'Hyperglycaemia',
 'Elevation of circulating glucose above physiological range.',
 'ENDOCRINE'),

('f0e00000-0000-0000-0000-000000000036',
 NULL,
 'MECH-HYPOGLYCAEMIA',
 'Hypoglycaemia',
 'Abnormally low circulating glucose capable of producing autonomic and neuroglycopenic manifestations.',
 'ENDOCRINE'),

-- ---------------------------------------------------------------------------
-- HAEMATOLOGICAL
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000037',
 NULL,
 'MECH-REDUCED-OXYGEN-CARRYING-CAPACITY',
 'Reduced oxygen-carrying capacity',
 'Reduction in effective blood oxygen-carrying capacity, commonly due to reduced haemoglobin concentration or abnormal haemoglobin.',
 'HAEMATOLOGICAL'),

('f0e00000-0000-0000-0000-000000000038',
 NULL,
 'MECH-HAEMOLYSIS',
 'Haemolysis',
 'Premature destruction of circulating red blood cells exceeding effective replacement.',
 'HAEMATOLOGICAL'),

('f0e00000-0000-0000-0000-000000000039',
 NULL,
 'MECH-BLOOD-LOSS',
 'Blood loss',
 'Loss of circulating blood volume through internal or external bleeding.',
 'HAEMATOLOGICAL'),

('f0e00000-0000-0000-0000-00000000003a',
 NULL,
 'MECH-THROMBOCYTOPENIA',
 'Thrombocytopenia',
 'Reduced circulating platelet number causing increased bleeding tendency when sufficiently severe or functionally significant.',
 'HAEMATOLOGICAL'),

('f0e00000-0000-0000-0000-00000000003b',
 NULL,
 'MECH-COAGULATION-FAILURE',
 'Coagulation failure',
 'Impaired coagulation resulting in pathological bleeding or inability to form stable fibrin clots.',
 'HAEMATOLOGICAL'),

('f0e00000-0000-0000-0000-00000000003c',
 NULL,
 'MECH-THROMBOSIS',
 'Pathological thrombosis',
 'Formation of an intravascular thrombus capable of obstructing blood flow or embolizing.',
 'HAEMATOLOGICAL'),

-- ---------------------------------------------------------------------------
-- IMMUNOLOGICAL / INFLAMMATORY
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-00000000003d',
 NULL,
 'MECH-SYSTEMIC-INFLAMMATION',
 'Systemic inflammation',
 'System-wide inflammatory response affecting multiple tissues and potentially producing organ dysfunction.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-00000000003e',
 NULL,
 'MECH-LOCAL-INFLAMMATION',
 'Local inflammation',
 'Localized inflammatory response causing tissue swelling, pain, heat, redness and impaired function.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-00000000003f',
 NULL,
 'MECH-AUTOIMMUNE-TISSUE-INJURY',
 'Autoimmune tissue injury',
 'Immune-mediated injury directed against self-antigens.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-000000000040',
 NULL,
 'MECH-IMMUNODEFICIENCY',
 'Immunodeficiency',
 'Reduced ability of the immune system to mount effective host defence.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-000000000041',
 NULL,
 'MECH-HYPERSENSITIVITY',
 'Hypersensitivity reaction',
 'Excessive or inappropriate immune response causing tissue injury or physiological disturbance.',
 'IMMUNE'),

-- ---------------------------------------------------------------------------
-- INFECTIOUS
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000042',
 NULL,
 'MECH-BACTERIAL-INFECTION',
 'Bacterial infection',
 'Invasion and multiplication of pathogenic bacteria within host tissues.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-000000000043',
 NULL,
 'MECH-VIRAL-INFECTION',
 'Viral infection',
 'Replication of viruses within host cells causing direct and immune-mediated tissue injury.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-000000000044',
 NULL,
 'MECH-FUNGAL-INFECTION',
 'Fungal infection',
 'Invasion or colonization of tissues by pathogenic fungi.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-000000000045',
 NULL,
 'MECH-PARASITIC-INFECTION',
 'Parasitic infection',
 'Tissue or systemic disease caused by pathogenic parasites.',
 'IMMUNE'),

('f0e00000-0000-0000-0000-000000000046',
 NULL,
 'MECH-SYSTEMIC-INFECTION',
 'Systemic infection',
 'Infection disseminated or sufficiently extensive to produce systemic inflammatory and/or organ effects.',
 'IMMUNE'),

-- ---------------------------------------------------------------------------
-- MUSCULOSKELETAL
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000047',
 NULL,
 'MECH-MUSCULOSKELETAL-INFLAMMATION',
 'Musculoskeletal inflammation',
 'Inflammation affecting joints, muscles, tendons, bursae or related structures.',
 'MUSCULOSKELETAL'),

('f0e00000-0000-0000-0000-000000000048',
 NULL,
 'MECH-JOINT-DEGENERATION',
 'Joint degeneration',
 'Progressive structural deterioration of articular cartilage, subchondral bone and related joint structures.',
 'MUSCULOSKELETAL'),

('f0e00000-0000-0000-0000-000000000049',
 NULL,
 'MECH-BONE-FRACTURE',
 'Bone disruption',
 'Structural disruption of bone due to trauma, pathological weakness or repetitive loading.',
 'MUSCULOSKELETAL'),

('f0e00000-0000-0000-0000-00000000004a',
 NULL,
 'MECH-MUSCLE-INJURY',
 'Muscle injury',
 'Structural or metabolic injury to skeletal muscle causing pain, weakness and impaired function.',
 'MUSCULOSKELETAL'),

-- ---------------------------------------------------------------------------
-- INTEGUMENTARY
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-00000000004b',
 NULL,
 'MECH-SKIN-INFLAMMATION',
 'Skin inflammation',
 'Inflammatory reaction within the skin causing erythema, oedema, pruritus and/or pain.',
 'INTEGUMENTARY'),

('f0e00000-0000-0000-0000-00000000004c',
 NULL,
 'MECH-SKIN-BARRIER-DISRUPTION',
 'Skin barrier disruption',
 'Loss of integrity of the epidermal barrier increasing fluid loss, infection risk and inflammatory activation.',
 'INTEGUMENTARY'),

('f0e00000-0000-0000-0000-00000000004d',
 NULL,
 'MECH-TISSUE-ISCHAEMIA',
 'Tissue ischaemia',
 'Insufficient tissue perfusion relative to metabolic demand.',
 'INTEGUMENTARY'),

-- ---------------------------------------------------------------------------
-- REPRODUCTIVE / OBSTETRIC
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-00000000004e',
 NULL,
 'MECH-UTERINE-CONTRACTION',
 'Uterine contraction',
 'Coordinated or pathological contraction of uterine smooth muscle.',
 'REPRODUCTIVE'),

('f0e00000-0000-0000-0000-00000000004f',
 NULL,
 'MECH-PLACENTAL-INSUFFICIENCY',
 'Placental insufficiency',
 'Inadequate placental transfer of oxygen and/or nutrients relative to fetal requirements.',
 'REPRODUCTIVE'),

('f0e00000-0000-0000-0000-000000000050',
 NULL,
 'MECH-UTEROPLACENTAL-HYPOPERFUSION',
 'Uteroplacental hypoperfusion',
 'Reduced maternal blood flow through the uteroplacental circulation.',
 'REPRODUCTIVE'),

('f0e00000-0000-0000-0000-000000000051',
 NULL,
 'MECH-PARTURITION',
 'Parturition mechanism',
 'Physiological processes producing cervical change and coordinated uterine contractions leading to birth.',
 'REPRODUCTIVE'),

-- ---------------------------------------------------------------------------
-- PSYCHIATRIC / NEUROBEHAVIOURAL
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000052',
 NULL,
 'MECH-ANXIETY-AUTONOMIC-ACTIVATION',
 'Anxiety-associated autonomic activation',
 'Autonomic and cognitive activation associated with anxiety and threat perception.',
 'PSYCHIATRIC'),

('f0e00000-0000-0000-0000-000000000053',
 NULL,
 'MECH-MOOD-DYSREGULATION',
 'Mood dysregulation',
 'Persistent disturbance of affective regulation producing depressive, manic or mixed symptom patterns.',
 'PSYCHIATRIC'),

('f0e00000-0000-0000-0000-000000000054',
 NULL,
 'MECH-COGNITIVE-DYSFUNCTION',
 'Cognitive dysfunction',
 'Impairment of attention, memory, executive function, orientation or other cognitive processes.',
 'PSYCHIATRIC'),

-- ---------------------------------------------------------------------------
-- ONCOLOGY
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000055',
 NULL,
 'MECH-ABNORMAL-CELL-PROLIFERATION',
 'Abnormal cellular proliferation',
 'Uncontrolled or dysregulated cellular proliferation resulting in tissue expansion.',
 'CONSTITUTIONAL'),

('f0e00000-0000-0000-0000-000000000056',
 NULL,
 'MECH-TUMOUR-INVASION',
 'Tumour invasion',
 'Infiltration of surrounding tissues by malignant cells.',
 'CONSTITUTIONAL'),

('f0e00000-0000-0000-0000-000000000057',
 NULL,
 'MECH-METASTATIC-DISSEMINATION',
 'Metastatic dissemination',
 'Spread of malignant cells from a primary tumour to distant anatomical sites.',
 'CONSTITUTIONAL'),

('f0e00000-0000-0000-0000-000000000058',
 NULL,
 'MECH-TUMOUR-MASS-EFFECT',
 'Tumour mass effect',
 'Symptoms and organ dysfunction caused by physical compression or displacement by a mass.',
 'CONSTITUTIONAL'),

-- ---------------------------------------------------------------------------
-- TOXICOLOGICAL / ENVIRONMENTAL
-- ---------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000059',
 NULL,
 'MECH-TOXIC-TISSUE-INJURY',
 'Toxic tissue injury',
 'Direct or indirect tissue injury caused by an exogenous or endogenous toxic substance.',
 'CONSTITUTIONAL'),

('f0e00000-0000-0000-0000-00000000005a',
 NULL,
 'MECH-DRUG-ADVERSE-EFFECT',
 'Drug adverse effect',
 'Unintended physiological or pathological effect resulting from medication exposure.',
 'CONSTITUTIONAL'),

('f0e00000-0000-0000-0000-00000000005b',
 NULL,
 'MECH-OXIDATIVE-STRESS',
 'Oxidative stress',
 'Excess oxidative activity relative to antioxidant defence causing cellular and tissue injury.',
 'CONSTITUTIONAL')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 2
-- MECHANISM FEATURES
-- =============================================================================
--
-- Features are evidence that supports or opposes a mechanism.
--
-- "positive" does NOT mean "diagnostic".
-- It means the feature increases support for the mechanism.
--
-- Negative features are equally important:
-- absence of wheeze can reduce support for an obstructive airway mechanism;
-- absence of orthopnoea can reduce support for a congestive phenotype.
-- =============================================================================


INSERT INTO knowledge.mechanism_feature
(mechanism_id, feature_type, feature_code, weight, polarity)
VALUES

-- AIRWAY INFLAMMATION
('f0e00000-0000-0000-0000-000000000001','fact','COUGH_PRODUCTIVITY',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000001','fact','COUGH_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000001','fact','FEVER_PRESENT',0.5,'positive'),

-- ALVEOLAR INFLAMMATION
('f0e00000-0000-0000-0000-000000000002','fact','FEVER_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000002','fact','DYSPNOEA_PRESENT',0.7,'positive'),
('f0e00000-0000-0000-0000-000000000002','fact','COUGH_PRESENT',0.7,'positive'),

-- AIRWAY OBSTRUCTION
('f0e00000-0000-0000-0000-000000000003','fact','DYSPNOEA_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000003','fact','WHEEZE_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000003','fact','COUGH_PRESENT',0.5,'positive'),

-- PLEURAL INFLAMMATION
('f0e00000-0000-0000-0000-000000000004','fact','CHEST_PAIN_PLEURITIC',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000004','fact','COUGH_PRESENT',0.5,'positive'),

-- GAS EXCHANGE
('f0e00000-0000-0000-0000-000000000005','fact','DYSPNOEA_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000005','measurement','SPO2',1.0,'positive'),

-- VENTILATORY FAILURE
('f0e00000-0000-0000-0000-000000000006','fact','DYSPNOEA_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000006','measurement','PCO2',1.0,'positive'),

-- V/Q MISMATCH
('f0e00000-0000-0000-0000-000000000007','measurement','SPO2',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000007','fact','DYSPNOEA_PRESENT',0.7,'positive'),

-- PULMONARY VASCULAR OCCLUSION
('f0e00000-0000-0000-0000-000000000008','fact','DYSPNOEA_PRESENT',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','PLEURITIC_CHEST_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','HAEMOPTYSIS_PRESENT',0.4,'positive'),

-- PULMONARY CONGESTION
('f0e00000-0000-0000-0000-000000000009','fact','ORTHOPNOEA_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000009','fact','PAROXYSMAL_NOCTURNAL_DYSPNOEA',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000009','fact','PERIPHERAL_OEDEMA',0.7,'positive'),

-- BRONCHOSPASM
('f0e00000-0000-0000-0000-00000000000b','fact','WHEEZE_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000000b','fact','DYSPNOEA_PRESENT',0.8,'positive'),

-- MUCUS HYPERSECRETION
('f0e00000-0000-0000-0000-00000000000c','fact','COUGH_PRODUCTIVITY',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000000c','fact','SPUTUM_AMOUNT',0.7,'positive'),

-- ALVEOLAR FILLING
('f0e00000-0000-0000-0000-00000000000d','fact','FEVER_PRESENT',0.5,'positive'),
('f0e00000-0000-0000-0000-00000000000d','fact','DYSPNOEA_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000000d','measurement','SPO2',0.9,'positive'),

-- PLEURAL EFFUSION
('f0e00000-0000-0000-0000-00000000000e','fact','DYSPNOEA_PRESENT',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000000e','fact','PLEURITIC_CHEST_PAIN',0.7,'positive'),

-- PNEUMOTHORAX
('f0e00000-0000-0000-0000-00000000000f','fact','DYSPNOEA_PRESENT',0.9,'positive'),
('f0e00000-0000-0000-0000-00000000000f','fact','PLEURITIC_CHEST_PAIN',0.8,'positive'),

-- REDUCED CARDIAC OUTPUT
('f0e00000-0000-0000-0000-000000000010','fact','FATIGUE_PRESENT',0.7,'positive'),
('f0e00000-0000-0000-0000-000000000010','fact','EXERCISE_INTOLERANCE',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000010','measurement','LOW_BLOOD_PRESSURE',0.8,'positive'),

-- LEFT VENTRICULAR DYSFUNCTION
('f0e00000-0000-0000-0000-000000000011','fact','ORTHOPNOEA_PRESENT',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000011','fact','PAROXYSMAL_NOCTURNAL_DYSPNOEA',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000011','fact','EXERCISE_INTOLERANCE',0.8,'positive'),

-- RIGHT VENTRICULAR DYSFUNCTION
('f0e00000-0000-0000-0000-000000000012','fact','PERIPHERAL_OEDEMA',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000012','fact','RAISED_JVP',0.9,'positive'),

-- VOLUME OVERLOAD
('f0e00000-0000-0000-0000-000000000013','fact','PERIPHERAL_OEDEMA',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000013','fact','RAPID_WEIGHT_GAIN',0.7,'positive'),

-- MYOCARDIAL ISCHAEMIA
('f0e00000-0000-0000-0000-000000000015','fact','CHEST_PAIN',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000015','fact','EXERTIONAL_CHEST_PAIN',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000015','fact','DIAPHORESIS',0.4,'positive'),

-- MYOCARDIAL NECROSIS
('f0e00000-0000-0000-0000-000000000016','fact','CHEST_PAIN',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000016','measurement','TROPONIN_ELEVATED',1.0,'positive'),

-- CEREBRAL HYPOPERFUSION
('f0e00000-0000-0000-0000-00000000001b','fact','SYNCOPE',0.9,'positive'),
('f0e00000-0000-0000-0000-00000000001b','fact','POSTURAL_DIZZINESS',0.8,'positive'),

-- CEREBRAL ISCHAEMIA
('f0e00000-0000-0000-0000-00000000001c','fact','FOCAL_NEUROLOGICAL_DEFICIT',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000001c','fact','SUDDEN_ONSET',0.8,'positive'),

-- CEREBRAL OEDEMA
('f0e00000-0000-0000-0000-00000000001d','fact','HEADACHE',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000001d','fact','VOMITING',0.6,'positive'),
('f0e00000-0000-0000-0000-00000000001d','fact','ALTERED_CONSCIOUSNESS',0.8,'positive'),

-- NEURONAL EXCITABILITY
('f0e00000-0000-0000-0000-00000000001f','fact','SEIZURE',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000001f','fact','ALTERED_CONSCIOUSNESS',0.6,'positive'),

-- GI INFLAMMATION
('f0e00000-0000-0000-0000-000000000022','fact','ABDOMINAL_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000022','fact','DIARRHOEA',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000022','fact','FEVER_PRESENT',0.5,'positive'),

-- GI OBSTRUCTION
('f0e00000-0000-0000-0000-000000000023','fact','VOMITING',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000023','fact','ABDOMINAL_DISTENSION',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000023','fact','FAILURE_TO_PASS_FLATUS',1.0,'positive'),

-- GI BLEEDING
('f0e00000-0000-0000-0000-000000000024','fact','HAEMATEMESIS',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000024','fact','MELAENA',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000024','fact','HAEMATOCHEZIA',0.9,'positive'),

-- MALABSORPTION
('f0e00000-0000-0000-0000-000000000025','fact','CHRONIC_DIARRHOEA',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000025','fact','WEIGHT_LOSS',0.8,'positive'),

-- REDUCED GFR
('f0e00000-0000-0000-0000-000000000029','measurement','CREATININE_ELEVATED',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000029','measurement','EGFR_REDUCED',1.0,'positive'),

-- GLOMERULAR INJURY
('f0e00000-0000-0000-0000-00000000002a','measurement','PROTEINURIA',0.9,'positive'),
('f0e00000-0000-0000-0000-00000000002a','measurement','HAEMATURIA',0.8,'positive'),

-- TUBULAR INJURY
('f0e00000-0000-0000-0000-00000000002b','measurement','CREATININE_ELEVATED',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000002b','measurement','ELECTROLYTE_ABNORMALITY',0.7,'positive'),

-- INSULIN DEFICIENCY
('f0e00000-0000-0000-0000-00000000002f','measurement','HYPERGLYCAEMIA',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000002f','fact','POLYURIA',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000002f','fact','POLYDIPSIA',0.7,'positive'),

-- INSULIN RESISTANCE
('f0e00000-0000-0000-0000-000000000030','measurement','HYPERGLYCAEMIA',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000030','fact','CENTRAL_OBESITY',0.7,'positive'),

-- ELECTROLYTE DISTURBANCE
('f0e00000-0000-0000-0000-000000000033','measurement','ELECTROLYTE_ABNORMALITY',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000033','fact','MUSCLE_WEAKNESS',0.6,'positive'),

-- ACID BASE
('f0e00000-0000-0000-0000-000000000034','measurement','ABNORMAL_PH',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000034','measurement','ABNORMAL_BICARBONATE',0.8,'positive'),

-- ANAEMIC OXYGEN CAPACITY
('f0e00000-0000-0000-0000-000000000037','measurement','LOW_HAEMOGLOBIN',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000037','fact','FATIGUE_PRESENT',0.7,'positive'),
('f0e00000-0000-0000-0000-000000000037','fact','EXERTIONAL_DYSPNOEA',0.7,'positive'),

-- HAEMOLYSIS
('f0e00000-0000-0000-0000-000000000038','measurement','HAEMOLYSIS_MARKERS',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000038','fact','JAUNDICE',0.5,'positive'),

-- BLOOD LOSS
('f0e00000-0000-0000-0000-000000000039','fact','BLEEDING_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000039','measurement','LOW_HAEMOGLOBIN',0.7,'positive'),

-- THROMBOCYTOPENIA
('f0e00000-0000-0000-0000-00000000003a','measurement','LOW_PLATELETS',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000003a','fact','PETECHIAE',0.7,'positive'),

-- COAGULATION FAILURE
('f0e00000-0000-0000-0000-00000000003b','measurement','ABNORMAL_COAGULATION',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000003b','fact','BLEEDING_PRESENT',0.8,'positive'),

-- THROMBOSIS
('f0e00000-0000-0000-0000-00000000003c','fact','LIMB_SWELLING',0.6,'positive'),
('f0e00000-0000-0000-0000-00000000003c','fact','ACUTE_LIMB_PAIN',0.6,'positive'),

-- SYSTEMIC INFLAMMATION
('f0e00000-0000-0000-0000-00000000003d','fact','FEVER_PRESENT',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000003d','measurement','CRP_ELEVATED',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000003d','measurement','WBC_ABNORMAL',0.6,'positive'),

-- LOCAL INFLAMMATION
('f0e00000-0000-0000-0000-00000000003e','fact','LOCAL_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000003e','fact','LOCAL_SWELLING',0.8,'positive'),

-- IMMUNODEFICIENCY
('f0e00000-0000-0000-0000-000000000040','fact','RECURRENT_INFECTIONS',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000040','fact','IMMUNOCOMPROMISED_STATUS',1.0,'positive'),

-- AUTOIMMUNITY
('f0e00000-0000-0000-0000-00000000003f','fact','AUTOIMMUNE_FEATURES',1.0,'positive'),

-- INFECTION
('f0e00000-0000-0000-0000-000000000046','fact','FEVER_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000046','measurement','CRP_ELEVATED',0.7,'positive'),

-- MUSCULOSKELETAL INFLAMMATION
('f0e00000-0000-0000-0000-000000000047','fact','JOINT_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000047','fact','JOINT_SWELLING',0.8,'positive'),

-- JOINT DEGENERATION
('f0e00000-0000-0000-0000-000000000048','fact','CHRONIC_JOINT_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000048','fact','MECHANICAL_JOINT_PAIN',0.9,'positive'),

-- BONE FRACTURE
('f0e00000-0000-0000-0000-000000000049','fact','ACUTE_BONE_PAIN',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000049','fact','TRAUMA_HISTORY',0.8,'positive'),

-- SKIN INFLAMMATION
('f0e00000-0000-0000-0000-00000000004b','fact','RASH_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000004b','fact','PRURITUS',0.7,'positive'),

-- PLACENTAL INSUFFICIENCY
('f0e00000-0000-0000-0000-00000000004f','fact','FETAL_GROWTH_RESTRICTION',0.9,'positive'),
('f0e00000-0000-0000-0000-00000000004f','fact','ABNORMAL_DOPPLER',0.9,'positive'),

-- ABNORMAL CELL PROLIFERATION
('f0e00000-0000-0000-0000-000000000055','fact','UNEXPLAINED_MASS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000055','fact','UNINTENTIONAL_WEIGHT_LOSS',0.6,'positive'),

-- TOXIC INJURY
('f0e00000-0000-0000-0000-000000000059','fact','TOXIN_EXPOSURE',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000059','fact','ACUTE_ORGAN_DYSFUNCTION',0.7,'positive'),

-- DRUG ADVERSE EFFECT
('f0e00000-0000-0000-0000-00000000005a','fact','MEDICATION_EXPOSURE',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000005a','fact','NEW_SYMPTOM_AFTER_DRUG',0.8,'positive')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 3
-- UNIVERSAL CLINICAL PHENOTYPES
-- =============================================================================
--
-- Phenotypes represent recognizable clinical patterns.
--
-- They intentionally do NOT equal diagnoses.
--
-- Example:
--
--   ACUTE_RESPIRATORY_INFECTIVE
--          |
--          +--> pneumonia
--          +--> viral LRTI
--          +--> bronchitis
--          +--> aspiration
--
--   ACUTE_HYPOXAEMIC
--          |
--          +--> pneumonia
--          +--> pulmonary oedema
--          +--> PE
--          +--> pneumothorax
--          +--> ARDS
--
-- This is the layer where AMEXAN Clinical Intelligence can compress a large
-- differential into clinically meaningful patterns before condition ranking.
-- =============================================================================


INSERT INTO knowledge.phenotype
(id, concept_id, phenotype_code, canonical_name, description)
VALUES

-- ---------------------------------------------------------------------------
-- RESPIRATORY PHENOTYPES
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000001',
 NULL,
 'PHEN-ACUTE-RESPIRATORY-INFECTIVE',
 'Acute respiratory infective phenotype',
 'Acute respiratory symptoms with infectious or inflammatory features such as fever, cough, sputum and systemic symptoms.'),

('f0f00000-0000-0000-0000-000000000002',
 NULL,
 'PHEN-ACUTE-LRTI',
 'Acute lower respiratory infection phenotype',
 'Acute cough with fever and/or dyspnoea suggesting lower respiratory tract involvement.'),

('f0f00000-0000-0000-0000-000000000003',
 NULL,
 'PHEN-CHRONIC-PRODUCTIVE-COUGH',
 'Chronic productive cough phenotype',
 'Persistent productive cough suggesting chronic airway disease, chronic infection or other structural pathology.'),

('f0f00000-0000-0000-0000-000000000004',
 NULL,
 'PHEN-OBSTRUCTIVE-AIRWAY',
 'Obstructive airway phenotype',
 'Variable or persistent airflow limitation characterized by wheeze, dyspnoea and prolonged expiration.'),

('f0f00000-0000-0000-0000-000000000005',
 NULL,
 'PHEN-ACUTE-HYPOXAEMIC',
 'Acute hypoxaemic respiratory phenotype',
 'Acute respiratory distress accompanied by impaired oxygenation.'),

('f0f00000-0000-0000-0000-000000000006',
 NULL,
 'PHEN-RESPIRATORY-FAILURE',
 'Respiratory failure phenotype',
 'Severe impairment of oxygenation and/or ventilation sufficient to compromise physiological stability.'),

('f0f00000-0000-0000-0000-000000000007',
 NULL,
 'PHEN-PLEURITIC-RESPIRATORY',
 'Pleuritic respiratory phenotype',
 'Respiratory presentation dominated by pleuritic chest pain with or without dyspnoea.'),

('f0f00000-0000-0000-0000-000000000008',
 NULL,
 'PHEN-PULMONARY-CONGESTIVE',
 'Pulmonary congestive phenotype',
 'Dyspnoea with features suggesting pulmonary vascular congestion or pulmonary oedema.'),

('f0f00000-0000-0000-0000-000000000009',
 NULL,
 'PHEN-HAEMOPTYSIS',
 'Haemoptysis phenotype',
 'Expectoration of blood requiring assessment of airway, pulmonary, vascular and systemic causes.'),

('f0f00000-0000-0000-0000-00000000000a',
 NULL,
 'PHEN-CHRONIC-RESPIRATORY-SYSTEMIC',
 'Chronic respiratory constitutional phenotype',
 'Chronic respiratory symptoms accompanied by constitutional features such as weight loss or night sweats.'),

-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000000b',
 NULL,
 'PHEN-ACUTE-CHEST-PAIN',
 'Acute chest pain phenotype',
 'Acute chest discomfort requiring consideration of cardiac, pulmonary, vascular, gastrointestinal and musculoskeletal causes.'),

('f0f00000-0000-0000-0000-00000000000c',
 NULL,
 'PHEN-ISCHAEMIC-CHEST-PAIN',
 'Ischaemic chest pain phenotype',
 'Chest discomfort with features compatible with myocardial oxygen supply-demand imbalance.'),

('f0f00000-0000-0000-0000-00000000000d',
 NULL,
 'PHEN-HEART-FAILURE',
 'Heart failure phenotype',
 'Clinical syndrome characterized by dyspnoea, congestion and/or reduced cardiac output.'),

('f0f00000-0000-0000-0000-00000000000e',
 NULL,
 'PHEN-SHOCK',
 'Shock phenotype',
 'Acute circulatory failure resulting in inadequate tissue perfusion and cellular oxygen delivery.'),

('f0f00000-0000-0000-0000-00000000000f',
 NULL,
 'PHEN-PERIPHERAL-OEDEMA',
 'Peripheral oedema phenotype',
 'Accumulation of interstitial fluid causing visible or palpable swelling of dependent tissues.'),

('f0f00000-0000-0000-0000-000000000010',
 NULL,
 'PHEN-SYNCOPE-PRESYNCOPE',
 'Syncope/presyncope phenotype',
 'Transient cerebral hypoperfusion presenting as transient loss of consciousness or near-fainting.'),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000011',
 NULL,
 'PHEN-ACUTE-FOCAL-NEUROLOGICAL',
 'Acute focal neurological deficit',
 'Sudden or acute onset of localized neurological dysfunction.'),

('f0f00000-0000-0000-0000-000000000012',
 NULL,
 'PHEN-ALTERED-CONSCIOUSNESS',
 'Altered consciousness phenotype',
 'Abnormal level or content of consciousness ranging from confusion to coma.'),

('f0f00000-0000-0000-0000-000000000013',
 NULL,
 'PHEN-SEIZURE',
 'Seizure phenotype',
 'Transient neurological event caused by abnormal excessive or synchronous neuronal activity.'),

('f0f00000-0000-0000-0000-000000000014',
 NULL,
 'PHEN-ACUTE-HEADACHE',
 'Acute headache phenotype',
 'New or acute headache requiring assessment for primary and secondary neurological causes.'),

('f0f00000-0000-0000-0000-000000000015',
 NULL,
 'PHEN-RAISED-ICP',
 'Raised intracranial pressure phenotype',
 'Headache, vomiting, altered consciousness, visual or neurological features suggesting increased intracranial pressure.'),

-- ---------------------------------------------------------------------------
-- GASTROINTESTINAL
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000016',
 NULL,
 'PHEN-ACUTE-ABDOMINAL-PAIN',
 'Acute abdominal pain phenotype',
 'Acute abdominal pain requiring assessment for gastrointestinal, genitourinary, vascular, reproductive and systemic causes.'),

('f0f00000-0000-0000-0000-000000000017',
 NULL,
 'PHEN-ACUTE-DIARRHOEAL',
 'Acute diarrhoeal phenotype',
 'Acute increase in stool frequency and/or decreased stool consistency, with or without vomiting and fever.'),

('f0f00000-0000-0000-0000-000000000018',
 NULL,
 'PHEN-CHRONIC-DIARRHOEAL',
 'Chronic diarrhoeal phenotype',
 'Persistent diarrhoea suggesting inflammatory, malabsorptive, infectious, functional or other chronic gastrointestinal disease.'),

('f0f00000-0000-0000-0000-000000000019',
 NULL,
 'PHEN-GI-BLEEDING',
 'Gastrointestinal bleeding phenotype',
 'Evidence of gastrointestinal blood loss manifested by haematemesis, melaena, haematochezia or occult blood loss.'),

('f0f00000-0000-0000-0000-00000000001a',
 NULL,
 'PHEN-INTESTINAL-OBSTRUCTION',
 'Intestinal obstruction phenotype',
 'Abdominal pain, vomiting, distension and impaired passage of intestinal contents.'),

('f0f00000-0000-0000-0000-00000000001b',
 NULL,
 'PHEN-JAUNDICE',
 'Jaundice phenotype',
 'Yellow discoloration of skin or sclera caused by increased bilirubin concentration.'),

-- ---------------------------------------------------------------------------
-- RENAL / URINARY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000001c',
 NULL,
 'PHEN-ACUTE-KIDNEY-INJURY',
 'Acute kidney injury phenotype',
 'Acute decline in kidney function with impaired filtration and/or altered urine output.'),

('f0f00000-0000-0000-0000-00000000001d',
 NULL,
 'PHEN-CHRONIC-KIDNEY-DISEASE',
 'Chronic kidney disease phenotype',
 'Persistent reduction or structural abnormality of kidney function.'),

('f0f00000-0000-0000-0000-00000000001e',
 NULL,
 'PHEN-NEPHRITIC',
 'Nephritic phenotype',
 'Haematuria, hypertension, renal dysfunction and variable proteinuria suggesting glomerular inflammation.'),

('f0f00000-0000-0000-0000-00000000001f',
 NULL,
 'PHEN-NEPHROTIC',
 'Nephrotic phenotype',
 'Heavy proteinuria with hypoalbuminaemia and oedema, with or without hyperlipidaemia.'),

('f0f00000-0000-0000-0000-000000000020',
 NULL,
 'PHEN-URINARY-TRACT-INFECTION',
 'Urinary tract infection phenotype',
 'Urinary symptoms and/or systemic features suggesting infection of the urinary tract.'),

-- ---------------------------------------------------------------------------
-- ENDOCRINE / METABOLIC
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000021',
 NULL,
 'PHEN-HYPERGLYCAEMIC',
 'Hyperglycaemic phenotype',
 'Hyperglycaemia with possible polyuria, polydipsia, weight loss, dehydration or metabolic decompensation.'),

('f0f00000-0000-0000-0000-000000000022',
 NULL,
 'PHEN-HYPOGLYCAEMIC',
 'Hypoglycaemic phenotype',
 'Autonomic and/or neuroglycopenic manifestations associated with low blood glucose.'),

('f0f00000-0000-0000-0000-000000000023',
 NULL,
 'PHEN-THYROTOXIC',
 'Thyrotoxic phenotype',
 'Hypermetabolic syndrome characterized by heat intolerance, tachycardia, tremor, weight loss and related manifestations.'),

('f0f00000-0000-0000-0000-000000000024',
 NULL,
 'PHEN-HYPOTHYROID',
 'Hypothyroid phenotype',
 'Hypometabolic syndrome characterized by fatigue, cold intolerance, weight gain and slowed physiological function.'),

('f0f00000-0000-0000-0000-000000000025',
 NULL,
 'PHEN-ELECTROLYTE-DISRUPTION',
 'Electrolyte disturbance phenotype',
 'Neurological, muscular or cardiovascular manifestations associated with abnormal electrolyte concentrations.'),

('f0f00000-0000-0000-0000-000000000026',
 NULL,
 'PHEN-ACID-BASE-DISRUPTION',
 'Acid-base disturbance phenotype',
 'Clinical and biochemical pattern caused by metabolic or respiratory disturbance of acid-base homeostasis.'),

-- ---------------------------------------------------------------------------
-- HAEMATOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000027',
 NULL,
 'PHEN-ANAEMIC',
 'Anaemic phenotype',
 'Reduced oxygen-carrying capacity presenting with fatigue, weakness, pallor, exertional dyspnoea or related features.'),

('f0f00000-0000-0000-0000-000000000028',
 NULL,
 'PHEN-HAEMORRHAGIC',
 'Haemorrhagic phenotype',
 'Clinical evidence of abnormal or excessive bleeding.'),

('f0f00000-0000-0000-0000-000000000029',
 NULL,
 'PHEN-THROMBOTIC',
 'Thrombotic phenotype',
 'Clinical pattern suggesting abnormal intravascular thrombosis or embolic disease.'),

('f0f00000-0000-0000-0000-00000000002a',
 NULL,
 'PHEN-PANCYTOPENIC',
 'Pancytopenic phenotype',
 'Reduction in red cells, white cells and platelets requiring assessment of marrow, nutritional, immune, infectious and malignant causes.'),

-- ---------------------------------------------------------------------------
-- INFECTIOUS / SYSTEMIC
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000002b',
 NULL,
 'PHEN-ACUTE-FEBRILE-ILLNESS',
 'Acute febrile illness phenotype',
 'Acute illness characterized by fever with variable localizing or systemic manifestations.'),

('f0f00000-0000-0000-0000-00000000002c',
 NULL,
 'PHEN-SYSTEMIC-INFECTION',
 'Systemic infectious phenotype',
 'Infectious syndrome with systemic manifestations and possible organ dysfunction.'),

('f0f00000-0000-0000-0000-00000000002d',
 NULL,
 'PHEN-SEPSIS',
 'Sepsis phenotype',
 'Infection-associated life-threatening organ dysfunction requiring urgent recognition and management.'),

('f0f00000-0000-0000-0000-00000000002e',
 NULL,
 'PHEN-CHRONIC-INFECTIOUS-CONSTITUTIONAL',
 'Chronic infectious constitutional phenotype',
 'Prolonged constitutional symptoms such as fever, weight loss and night sweats with possible localizing manifestations.'),

-- ---------------------------------------------------------------------------
-- MUSCULOSKELETAL
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000002f',
 NULL,
 'PHEN-MECHANICAL-MUSCULOSKELETAL-PAIN',
 'Mechanical musculoskeletal pain',
 'Pain associated predominantly with movement, loading or mechanical use of musculoskeletal structures.'),

('f0f00000-0000-0000-0000-000000000030',
 NULL,
 'PHEN-INFLAMMATORY-JOINT',
 'Inflammatory joint phenotype',
 'Joint pain and stiffness associated with inflammatory features such as swelling, warmth and prolonged morning stiffness.'),

('f0f00000-0000-0000-0000-000000000031',
 NULL,
 'PHEN-ACUTE-TRAUMATIC',
 'Acute traumatic phenotype',
 'Acute pain, swelling, dysfunction or structural injury following trauma.'),

-- ---------------------------------------------------------------------------
-- DERMATOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000032',
 NULL,
 'PHEN-ACUTE-RASH',
 'Acute rash phenotype',
 'New skin eruption requiring consideration of infectious, allergic, inflammatory, vascular and drug-related causes.'),

('f0f00000-0000-0000-0000-000000000033',
 NULL,
 'PHEN-PRURITIC-SKIN',
 'Pruritic skin phenotype',
 'Predominant skin itching with or without visible lesions.'),

-- ---------------------------------------------------------------------------
-- OBSTETRICS / GYNAECOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000034',
 NULL,
 'PHEN-ANTE-PARTUM-BLEEDING',
 'Antepartum bleeding phenotype',
 'Vaginal bleeding during pregnancy requiring assessment of placental, cervical and other causes.'),

('f0f00000-0000-0000-0000-000000000035',
 NULL,
 'PHEN-PREGNANCY-HYPERTENSIVE',
 'Pregnancy hypertensive phenotype',
 'Elevated blood pressure during pregnancy with assessment for gestational hypertension and pre-eclampsia spectrum.'),

('f0f00000-0000-0000-0000-000000000036',
 NULL,
 'PHEN-FETAL-GROWTH-RESTRICTION',
 'Fetal growth restriction phenotype',
 'Fetal size and/or growth trajectory below expected potential with possible placental insufficiency.'),

('f0f00000-0000-0000-0000-000000000037',
 NULL,
 'PHEN-OBSTETRIC-LABOUR',
 'Labour phenotype',
 'Regular uterine contractions associated with progressive cervical change and/or birth process.'),

-- ---------------------------------------------------------------------------
-- ONCOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000038',
 NULL,
 'PHEN-UNEXPLAINED-WEIGHT-LOSS',
 'Unexplained weight loss phenotype',
 'Unintentional weight loss requiring evaluation for malignant, infectious, endocrine, gastrointestinal, psychiatric and systemic causes.'),

('f0f00000-0000-0000-0000-000000000039',
 NULL,
 'PHEN-UNEXPLAINED-MASS',
 'Unexplained mass phenotype',
 'New or persistent mass requiring anatomical, inflammatory, neoplastic and other differential assessment.'),

('f0f00000-0000-0000-0000-00000000003a',
 NULL,
 'PHEN-CONSTITUTIONAL-MALIGNANCY',
 'Malignancy-associated constitutional phenotype',
 'Persistent weight loss, fatigue, anorexia, night sweats or other constitutional features raising concern for malignant disease.'),

-- ---------------------------------------------------------------------------
-- TOXICOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000003b',
 NULL,
 'PHEN-TOXIC-METABOLIC',
 'Toxic-metabolic phenotype',
 'Altered physiological function caused by toxic exposure, medication effect or severe metabolic disturbance.'),

-- ---------------------------------------------------------------------------
-- PSYCHIATRY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000003c',
 NULL,
 'PHEN-ANXIETY',
 'Anxiety phenotype',
 'Excessive fear, apprehension or autonomic arousal with associated cognitive, behavioural and physical symptoms.'),

('f0f00000-0000-0000-0000-00000000003d',
 NULL,
 'PHEN-DEPRESSIVE',
 'Depressive phenotype',
 'Persistent low mood and/or loss of interest accompanied by cognitive, behavioural and somatic symptoms.'),

('f0f00000-0000-0000-0000-00000000003e',
 NULL,
 'PHEN-DELIRIUM',
 'Delirium phenotype',
 'Acute fluctuating disturbance of attention, awareness and cognition due to an underlying medical, toxic or neurological cause.')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 4
-- PHENOTYPE FEATURES
-- =============================================================================


INSERT INTO knowledge.phenotype_feature
(phenotype_id, feature_type, feature_code, operator, value, weight, polarity)
VALUES

-- ---------------------------------------------------------------------------
-- ACUTE RESPIRATORY INFECTIVE
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000001','fact','COUGH_PRESENT','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000001','fact','FEVER_PRESENT','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000001','fact','DYSPNOEA_PRESENT','eq','true',0.6,'positive'),

-- ACUTE LRTI
('f0f00000-0000-0000-0000-000000000002','fact','COUGH_PRODUCTIVITY','eq','"PRODUCTIVE"',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000002','fact','FEVER_PRESENT','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000002','fact','DYSPNOEA_PRESENT','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000002','fact','COUGH_DURATION_DAYS','lte','14',0.3,'positive'),

-- CHRONIC PRODUCTIVE COUGH
('f0f00000-0000-0000-0000-000000000003','fact','COUGH_PRODUCTIVITY','eq','"PRODUCTIVE"',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000003','fact','COUGH_DURATION_DAYS','gt','14',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000003','fact','SMOKING_STATUS','eq','"CURRENT"',0.6,'positive'),

-- OBSTRUCTIVE AIRWAY
('f0f00000-0000-0000-0000-000000000004','fact','WHEEZE_PRESENT','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000004','fact','DYSPNOEA_PRESENT','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000004','fact','PROLONGED_EXPIRATION','eq','true',0.8,'positive'),

-- HYPOXAEMIA
('f0f00000-0000-0000-0000-000000000005','fact','DYSPNOEA_PRESENT','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000005','measurement','SPO2','lt','92',1.0,'positive'),

-- RESPIRATORY FAILURE
('f0f00000-0000-0000-0000-000000000006','measurement','SPO2','lte','88',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000006','fact','DYSPNOEA_PRESENT','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000006','fact','ALTERED_CONSCIOUSNESS','eq','true',0.7,'positive'),

-- PLEURITIC
('f0f00000-0000-0000-0000-000000000007','fact','PLEURITIC_CHEST_PAIN','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000007','fact','DYSPNOEA_PRESENT','eq','true',0.5,'positive'),

-- CONGESTIVE
('f0f00000-0000-0000-0000-000000000008','fact','ORTHOPNOEA_PRESENT','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000008','fact','PERIPHERAL_OEDEMA','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000008','fact','PAROXYSMAL_NOCTURNAL_DYSPNOEA','eq','true',0.9,'positive'),

-- HAEMOPTYSIS
('f0f00000-0000-0000-0000-000000000009','fact','HAEMOPTYSIS_PRESENT','eq','true',1.0,'positive'),

-- CHRONIC INFECTIOUS
('f0f00000-0000-0000-0000-00000000000a','fact','COUGH_DURATION_DAYS','gt','14',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000000a','fact','WEIGHT_LOSS','eq','"YES"',0.9,'positive'),
('f0f00000-0000-0000-0000-00000000000a','fact','NIGHT_SWEATS','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000000a','fact','TB_CONTACT','eq','"YES"',0.7,'positive'),

-- ---------------------------------------------------------------------------
-- CARDIOVASCULAR PHENOTYPES
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000000b','fact','CHEST_PAIN','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000000c','fact','EXERTIONAL_CHEST_PAIN','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000000c','fact','CHEST_PAIN_RADIATION','eq','true',0.6,'positive'),

('f0f00000-0000-0000-0000-00000000000d','fact','DYSPNOEA_PRESENT','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000000d','fact','ORTHOPNOEA_PRESENT','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-00000000000d','fact','PERIPHERAL_OEDEMA','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-00000000000e','measurement','LOW_BLOOD_PRESSURE','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000000e','fact','ALTERED_CONSCIOUSNESS','eq','true',0.6,'positive'),
('f0f00000-0000-0000-0000-00000000000e','fact','OLIGURIA','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-00000000000f','fact','PERIPHERAL_OEDEMA','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000010','fact','SYNCOPE','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000010','fact','POSTURAL_DIZZINESS','eq','true',0.7,'positive'),

-- ---------------------------------------------------------------------------
-- NEUROLOGICAL
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000011','fact','SUDDEN_ONSET','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000011','fact','FOCAL_NEUROLOGICAL_DEFICIT','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000012','fact','ALTERED_CONSCIOUSNESS','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000012','fact','ACUTE_ONSET_CONFUSION','eq','true',0.9,'positive'),

('f0f00000-0000-0000-0000-000000000013','fact','SEIZURE','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000014','fact','HEADACHE','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000014','fact','SUDDEN_ONSET','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-000000000015','fact','HEADACHE','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000015','fact','VOMITING','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000015','fact','ALTERED_CONSCIOUSNESS','eq','true',0.8,'positive'),

-- ---------------------------------------------------------------------------
-- GI
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000016','fact','ABDOMINAL_PAIN','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000016','fact','VOMITING','eq','true',0.5,'positive'),

('f0f00000-0000-0000-0000-000000000017','fact','DIARRHOEA','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000017','fact','VOMITING','eq','true',0.6,'positive'),

('f0f00000-0000-0000-0000-000000000018','fact','CHRONIC_DIARRHOEA','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000018','fact','WEIGHT_LOSS','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-000000000019','fact','HAEMATEMESIS','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000019','fact','MELAENA','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000019','fact','HAEMATOCHEZIA','eq','true',0.9,'positive'),

('f0f00000-0000-0000-0000-00000000001a','fact','VOMITING','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000001a','fact','ABDOMINAL_DISTENSION','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000001a','fact','FAILURE_TO_PASS_FLATUS','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-00000000001b','fact','JAUNDICE','eq','true',1.0,'positive'),

-- ---------------------------------------------------------------------------
-- RENAL
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000001c','measurement','CREATININE_ELEVATED','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000001c','fact','OLIGURIA','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-00000000001d','measurement','EGFR_REDUCED','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-00000000001e','measurement','HAEMATURIA','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-00000000001e','measurement','HYPERTENSION','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-00000000001f','measurement','PROTEINURIA','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000001f','fact','PERIPHERAL_OEDEMA','eq','true',0.9,'positive'),

('f0f00000-0000-0000-0000-000000000020','fact','DYSURIA','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000020','fact','URINARY_FREQUENCY','eq','true',0.7,'positive'),

-- ---------------------------------------------------------------------------
-- ENDOCRINE
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000021','measurement','HYPERGLYCAEMIA','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000021','fact','POLYURIA','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000021','fact','POLYDIPSIA','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-000000000022','measurement','HYPOGLYCAEMIA','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000022','fact','ALTERED_CONSCIOUSNESS','eq','true',0.5,'positive'),

('f0f00000-0000-0000-0000-000000000023','fact','WEIGHT_LOSS','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000023','fact','HEAT_INTOLERANCE','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000023','fact','PALPITATIONS','eq','true',0.8,'positive'),

('f0f00000-0000-0000-0000-000000000024','fact','FATIGUE_PRESENT','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000024','fact','COLD_INTOLERANCE','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000024','fact','WEIGHT_GAIN','eq','true',0.6,'positive'),

('f0f00000-0000-0000-0000-000000000025','measurement','ELECTROLYTE_ABNORMALITY','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000026','measurement','ABNORMAL_PH','eq','true',1.0,'positive'),

-- ---------------------------------------------------------------------------
-- HAEMATOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000027','measurement','LOW_HAEMOGLOBIN','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000027','fact','FATIGUE_PRESENT','eq','true',0.6,'positive'),
('f0f00000-0000-0000-0000-000000000027','fact','EXERTIONAL_DYSPNOEA','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-000000000028','fact','BLEEDING_PRESENT','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000029','fact','LIMB_SWELLING','eq','true',0.6,'positive'),
('f0f00000-0000-0000-0000-000000000029','fact','ACUTE_LIMB_PAIN','eq','true',0.6,'positive'),
('f0f00000-0000-0000-0000-000000000029','fact','DYSPNOEA_PRESENT','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-00000000002a','measurement','PANCYTOPENIA','eq','true',1.0,'positive'),

-- ---------------------------------------------------------------------------
-- INFECTIOUS
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000002b','fact','FEVER_PRESENT','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000002b','fact','ACUTE_ONSET','eq','true',0.7,'positive'),

('f0f00000-0000-0000-0000-00000000002c','fact','FEVER_PRESENT','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000002c','measurement','CRP_ELEVATED','eq','true',0.6,'positive'),

('f0f00000-0000-0000-0000-00000000002d','fact','FEVER_PRESENT','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-00000000002d','fact','ORGAN_DYSFUNCTION','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-00000000002e','fact','WEIGHT_LOSS','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000002e','fact','NIGHT_SWEATS','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000002e','fact','FEVER_PRESENT','eq','true',0.7,'positive'),

-- ---------------------------------------------------------------------------
-- MUSCULOSKELETAL
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000002f','fact','MECHANICAL_JOINT_PAIN','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000002f','fact','PAIN_WITH_MOVEMENT','eq','true',0.8,'positive'),

('f0f00000-0000-0000-0000-000000000030','fact','JOINT_SWELLING','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000030','fact','MORNING_STIFFNESS','eq','true',0.9,'positive'),

('f0f00000-0000-0000-0000-000000000031','fact','TRAUMA_HISTORY','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000031','fact','ACUTE_BONE_PAIN','eq','true',0.9,'positive'),

-- ---------------------------------------------------------------------------
-- DERMATOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000032','fact','RASH_PRESENT','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000032','fact','ACUTE_ONSET','eq','true',0.6,'positive'),

('f0f00000-0000-0000-0000-000000000033','fact','PRURITUS','eq','true',1.0,'positive'),

-- ---------------------------------------------------------------------------
-- OBSTETRICS
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000034','fact','VAGINAL_BLEEDING_IN_PREGNANCY','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000035','measurement','HYPERTENSION','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000035','fact','PREGNANCY_STATUS','eq','"PREGNANT"',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000036','fact','FETAL_GROWTH_RESTRICTION','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000037','fact','UTERINE_CONTRACTIONS','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000037','fact','CERVICAL_CHANGE','eq','true',1.0,'positive'),

-- ---------------------------------------------------------------------------
-- ONCOLOGY
-- ---------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000038','fact','UNINTENTIONAL_WEIGHT_LOSS','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-000000000039','fact','UNEXPLAINED_MASS','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-00000000003a','fact','UNINTENTIONAL_WEIGHT_LOSS','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-00000000003a','fact','NIGHT_SWEATS','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-00000000003a','fact','FATIGUE_PRESENT','eq','true',0.6,'positive'),

-- TOXICOLOGY
('f0f00000-0000-0000-0000-00000000003b','fact','TOXIN_EXPOSURE','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000003b','fact','ALTERED_CONSCIOUSNESS','eq','true',0.7,'positive'),

-- PSYCHIATRY
('f0f00000-0000-0000-0000-00000000003c','fact','EXCESSIVE_WORRY','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000003c','fact','PALPITATIONS','eq','true',0.5,'positive'),

('f0f00000-0000-0000-0000-00000000003d','fact','LOW_MOOD','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000003d','fact','ANHEDONIA','eq','true',1.0,'positive'),

('f0f00000-0000-0000-0000-00000000003e','fact','ACUTE_ONSET_CONFUSION','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000003e','fact','FLUCTUATING_ATTENTION','eq','true',0.9,'positive')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 5
-- PHENOTYPE CONTEXT
-- =============================================================================
--
-- Context modifies applicability rather than creating another phenotype.
-- =============================================================================


INSERT INTO knowledge.phenotype_context
(phenotype_id, context_type_code, context_value_id, applicability)
SELECT
    p.id,
    x.context_type_code,
    cv.id,
    x.applicability
FROM (
    VALUES
      ('PHEN-ACUTE-LRTI','AGE','0-28D','applies'),
      ('PHEN-ACUTE-LRTI','AGE','1-11M','applies'),
      ('PHEN-ACUTE-LRTI','AGE','1-4Y','applies'),
      ('PHEN-ACUTE-LRTI','AGE','5-17Y','applies'),
      ('PHEN-ACUTE-LRTI','AGE','18-64Y','applies'),
      ('PHEN-ACUTE-LRTI','AGE','65P','applies'),

      ('PHEN-OBSTRUCTIVE-AIRWAY','AGE','1-11M','applies'),
      ('PHEN-OBSTRUCTIVE-AIRWAY','AGE','1-4Y','applies'),
      ('PHEN-OBSTRUCTIVE-AIRWAY','AGE','5-17Y','applies'),
      ('PHEN-OBSTRUCTIVE-AIRWAY','AGE','18-64Y','applies'),
      ('PHEN-OBSTRUCTIVE-AIRWAY','AGE','65P','applies'),

      ('PHEN-HEART-FAILURE','AGE','18-64Y','applies'),
      ('PHEN-HEART-FAILURE','AGE','65P','applies'),

      ('PHEN-PREGNANCY-HYPERTENSIVE','PREGNANCY','pregnant','required'),
      ('PHEN-FETAL-GROWTH-RESTRICTION','PREGNANCY','pregnant','required'),
      ('PHEN-ANTE-PARTUM-BLEEDING','PREGNANCY','pregnant','required'),
      ('PHEN-OBSTETRIC-LABOUR','PREGNANCY','pregnant','required'),

      ('PHEN-SEPSIS','ACUITY','emergency','preferred'),

      ('PHEN-RESPIRATORY-FAILURE','ACUITY','emergency','preferred'),

      ('PHEN-ACUTE-HYPOXAEMIC','CARE_SETTING','emergency','preferred'),
      ('PHEN-ACUTE-HYPOXAEMIC','CARE_SETTING','inpatient','applies'),

      ('PHEN-CHRONIC-INFECTIOUS-CONSTITUTIONAL','AGE','18-64Y','applies'),
      ('PHEN-CHRONIC-INFECTIOUS-CONSTITUTIONAL','AGE','65P','applies')
) AS x(phenotype_code,context_type_code,context_value,applicability)
JOIN knowledge.phenotype p
  ON p.phenotype_code = x.phenotype_code
JOIN knowledge.context_value cv
  ON cv.context_type_code = x.context_type_code
 AND cv.value = x.context_value

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 6
-- DOCUMENTATION PHRASES
-- =============================================================================
--
-- These are canonical documentation labels, NOT generated clinical conclusions.
-- The intelligence layer may use them after sufficient evidence is collected.
-- =============================================================================


INSERT INTO knowledge.phenotype_documentation
(phenotype_id, documentation_phrase, language_code, is_preferred)
SELECT p.id, x.documentation_phrase, x.language_code, x.is_preferred
FROM (
    VALUES
    ('PHEN-ACUTE-RESPIRATORY-INFECTIVE','Acute respiratory infective phenotype','en',true),
    ('PHEN-ACUTE-LRTI','Acute lower respiratory tract infection phenotype','en',true),
    ('PHEN-CHRONIC-PRODUCTIVE-COUGH','Chronic productive cough phenotype','en',true),
    ('PHEN-OBSTRUCTIVE-AIRWAY','Obstructive airway phenotype','en',true),
    ('PHEN-ACUTE-HYPOXAEMIC','Acute hypoxaemic respiratory phenotype','en',true),
    ('PHEN-RESPIRATORY-FAILURE','Respiratory failure phenotype','en',true),
    ('PHEN-PLEURITIC-RESPIRATORY','Pleuritic respiratory phenotype','en',true),
    ('PHEN-PULMONARY-CONGESTIVE','Pulmonary congestive phenotype','en',true),
    ('PHEN-HAEMOPTYSIS','Haemoptysis phenotype','en',true),
    ('PHEN-CHRONIC-RESPIRATORY-SYSTEMIC','Chronic respiratory constitutional phenotype','en',true),

    ('PHEN-ACUTE-CHEST-PAIN','Acute chest pain phenotype','en',true),
    ('PHEN-ISCHAEMIC-CHEST-PAIN','Ischaemic chest pain phenotype','en',true),
    ('PHEN-HEART-FAILURE','Heart failure phenotype','en',true),
    ('PHEN-SHOCK','Shock phenotype','en',true),
    ('PHEN-SYNCOPE-PRESYNCOPE','Syncope/presyncope phenotype','en',true),

    ('PHEN-ACUTE-FOCAL-NEUROLOGICAL','Acute focal neurological deficit','en',true),
    ('PHEN-ALTERED-CONSCIOUSNESS','Altered consciousness phenotype','en',true),
    ('PHEN-SEIZURE','Seizure phenotype','en',true),
    ('PHEN-ACUTE-HEADACHE','Acute headache phenotype','en',true),
    ('PHEN-RAISED-ICP','Raised intracranial pressure phenotype','en',true),

    ('PHEN-ACUTE-ABDOMINAL-PAIN','Acute abdominal pain phenotype','en',true),
    ('PHEN-ACUTE-DIARRHOEAL','Acute diarrhoeal phenotype','en',true),
    ('PHEN-CHRONIC-DIARRHOEAL','Chronic diarrhoeal phenotype','en',true),
    ('PHEN-GI-BLEEDING','Gastrointestinal bleeding phenotype','en',true),
    ('PHEN-INTESTINAL-OBSTRUCTION','Intestinal obstruction phenotype','en',true),
    ('PHEN-JAUNDICE','Jaundice phenotype','en',true),

    ('PHEN-ACUTE-KIDNEY-INJURY','Acute kidney injury phenotype','en',true),
    ('PHEN-CHRONIC-KIDNEY-DISEASE','Chronic kidney disease phenotype','en',true),
    ('PHEN-NEPHRITIC','Nephritic phenotype','en',true),
    ('PHEN-NEPHROTIC','Nephrotic phenotype','en',true),
    ('PHEN-URINARY-TRACT-INFECTION','Urinary tract infection phenotype','en',true),

    ('PHEN-HYPERGLYCAEMIC','Hyperglycaemic phenotype','en',true),
    ('PHEN-HYPOGLYCAEMIC','Hypoglycaemic phenotype','en',true),
    ('PHEN-THYROTOXIC','Thyrotoxic phenotype','en',true),
    ('PHEN-HYPOTHYROID','Hypothyroid phenotype','en',true),
    ('PHEN-ELECTROLYTE-DISRUPTION','Electrolyte disturbance phenotype','en',true),
    ('PHEN-ACID-BASE-DISRUPTION','Acid-base disturbance phenotype','en',true),

    ('PHEN-ANAEMIC','Anaemic phenotype','en',true),
    ('PHEN-HAEMORRHAGIC','Haemorrhagic phenotype','en',true),
    ('PHEN-THROMBOTIC','Thrombotic phenotype','en',true),
    ('PHEN-PANCYTOPENIC','Pancytopenic phenotype','en',true),

    ('PHEN-ACUTE-FEBRILE-ILLNESS','Acute febrile illness phenotype','en',true),
    ('PHEN-SYSTEMIC-INFECTION','Systemic infectious phenotype','en',true),
    ('PHEN-SEPSIS','Sepsis phenotype','en',true),
    ('PHEN-CHRONIC-INFECTIOUS-CONSTITUTIONAL','Chronic infectious constitutional phenotype','en',true),

    ('PHEN-MECHANICAL-MUSCULOSKELETAL-PAIN','Mechanical musculoskeletal pain phenotype','en',true),
    ('PHEN-INFLAMMATORY-JOINT','Inflammatory joint phenotype','en',true),
    ('PHEN-ACUTE-TRAUMATIC','Acute traumatic phenotype','en',true),

    ('PHEN-ACUTE-RASH','Acute rash phenotype','en',true),
    ('PHEN-PRURITIC-SKIN','Pruritic skin phenotype','en',true),

    ('PHEN-ANTE-PARTUM-BLEEDING','Antepartum bleeding phenotype','en',true),
    ('PHEN-PREGNANCY-HYPERTENSIVE','Pregnancy hypertensive phenotype','en',true),
    ('PHEN-FETAL-GROWTH-RESTRICTION','Fetal growth restriction phenotype','en',true),
    ('PHEN-OBSTETRIC-LABOUR','Labour phenotype','en',true),

    ('PHEN-UNEXPLAINED-WEIGHT-LOSS','Unexplained weight loss phenotype','en',true),
    ('PHEN-UNEXPLAINED-MASS','Unexplained mass phenotype','en',true),
    ('PHEN-CONSTITUTIONAL-MALIGNANCY','Malignancy-associated constitutional phenotype','en',true),

    ('PHEN-TOXIC-METABOLIC','Toxic-metabolic phenotype','en',true),

    ('PHEN-ANXIETY','Anxiety phenotype','en',true),
    ('PHEN-DEPRESSIVE','Depressive phenotype','en',true),
    ('PHEN-DELIRIUM','Delirium phenotype','en',true)
) AS x(phenotype_code,documentation_phrase,language_code,is_preferred)
JOIN knowledge.phenotype p
  ON p.phenotype_code = x.phenotype_code

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 7
-- SAFETY / DATA-QUALITY CHECKS
-- =============================================================================
--
-- These checks deliberately fail the transaction if the core Z5 dependency
-- graph is broken.
-- =============================================================================


DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.mechanism
        WHERE mechanism_code = 'MECH-AIRWAY-INFLAMMATION'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN Z5 integrity failure: MECH-AIRWAY-INFLAMMATION missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.mechanism
        WHERE mechanism_code = 'MECH-REDUCED-CARDIAC-OUTPUT'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN Z5 integrity failure: cardiovascular mechanism missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.phenotype
        WHERE phenotype_code = 'PHEN-SEPSIS'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN Z5 integrity failure: PHEN-SEPSIS missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.phenotype
        WHERE phenotype_code = 'PHEN-ACUTE-ABDOMINAL-PAIN'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN Z5 integrity failure: surgical/GI phenotype missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM knowledge.phenotype
        WHERE phenotype_code = 'PHEN-PREGNANCY-HYPERTENSIVE'
    ) THEN
        RAISE EXCEPTION
            'AMEXAN Z5 integrity failure: obstetric phenotype missing';
    END IF;

END $$;


COMMIT;


-- =============================================================================
-- END AMEXAN PHASE 2 — SEED Z5
-- =============================================================================