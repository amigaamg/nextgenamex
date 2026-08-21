-- =============================================================================
-- AMEXAN Phase 2 — Seed ZP3
-- UNIVERSAL MECHANISMS + PHENOTYPES
-- =============================================================================
--
-- PURPOSE
-- -------
-- Mechanisms and phenotypes are reusable clinical reasoning primitives.
--
-- They are NOT owned by individual diseases.
--
-- The same mechanism may participate in many conditions:
--
--     pulmonary congestion
--          -> heart failure
--          -> renal failure
--          -> fluid overload
--          -> valvular disease
--
--     inflammation
--          -> infection
--          -> autoimmune disease
--          -> inflammatory bowel disease
--          -> vasculitis
--
--     obstruction
--          -> asthma
--          -> COPD
--          -> bowel obstruction
--          -> urinary obstruction
--          -> biliary obstruction
--
--     tissue ischaemia
--          -> ACS
--          -> mesenteric ischaemia
--          -> limb ischaemia
--          -> stroke
--
-- ZP3 therefore represents:
--
--     FACTS
--       ↓
--     MECHANISMS
--       ↓
--     PHENOTYPES
--       ↓
--     CONDITIONS
--
-- It must never directly declare a diagnosis merely because one feature exists.
-- Multiple features, contradictions, context and competing mechanisms are
-- evaluated by the downstream intelligence engine.
--
-- =============================================================================


-- =============================================================================
-- 1. EXISTING UNIVERSAL MECHANISMS
-- =============================================================================

-- =============================================================================
-- =============================================================================
-- -- MECHANISM CONCEPTS (paired with mechanisms below)
-- =============================================================================

INSERT INTO knowledge.concept
(id, concept_code, concept_type, canonical_name, display_name, description)
VALUES
('f0a00000-0000-0000-0000-00000000005f',
 'CNS-RENAL-INFLAMMATION',
 'mechanism',
 'Renal inflammatory injury',
 'Renal inflammatory injury',
 'Inflammatory injury involving glomerular, interstitial or vascular renal structures.'
),

('f0a00000-0000-0000-0000-000000000060',
 'CNS-ECTOPIC-IMPLANTATION',
 'mechanism',
 'Extrauterine implantation',
 'Extrauterine implantation',
 'Implantation of a pregnancy outside the normal endometrial uterine cavity.'
),

('f0a00000-0000-0000-0000-000000000061',
 'CNS-UTERINE-CONTRACTION',
 'mechanism',
 'Uterine contractile activity',
 'Uterine contractile activity',
 'Coordinated or pathological uterine contractions producing cervical change, pain or labour.'
),

('f0a00000-0000-0000-0000-000000000062',
 'CNS-REPRODUCTIVE-INFLAMMATION',
 'mechanism',
 'Reproductive tract inflammation',
 'Reproductive tract inflammation',
 'Inflammatory or infectious injury involving reproductive tract structures.'
),

('f0a00000-0000-0000-0000-000000000063',
 'CNS-ABNORMAL-UTERINE-BLEEDING',
 'mechanism',
 'Abnormal uterine bleeding mechanism',
 'Abnormal uterine bleeding mechanism',
 'Bleeding arising from structural, ovulatory, endocrine, pregnancy-related or other reproductive causes.'
),

('f0a00000-0000-0000-0000-000000000064',
 'CNS-CEREBRAL-ISCHAEMIA',
 'mechanism',
 'Cerebral ischaemia',
 'Cerebral ischaemia',
 'Reduced cerebral blood flow causing neurological dysfunction.'
),

('f0a00000-0000-0000-0000-000000000065',
 'CNS-CEREBRAL-HAEMORRHAGE',
 'mechanism',
 'Intracranial haemorrhage',
 'Intracranial haemorrhage',
 'Bleeding within or around the intracranial compartment causing neurological injury or raised intracranial pressure.'
),

('f0a00000-0000-0000-0000-000000000066',
 'CNS-NEURONAL-HYPEREXCITABILITY',
 'mechanism',
 'Neuronal hyperexcitability',
 'Neuronal hyperexcitability',
 'Excessive synchronous neuronal activity producing seizures or related neurological manifestations.'
),

('f0a00000-0000-0000-0000-000000000067',
 'CNS-RAISED-INTRACRANIAL-PRESSURE',
 'mechanism',
 'Raised intracranial pressure',
 'Raised intracranial pressure',
 'Elevation of intracranial pressure caused by increased brain tissue, blood or cerebrospinal fluid volume.'
),

('f0a00000-0000-0000-0000-000000000068',
 'CNS-HYPERGLYCAEMIA',
 'mechanism',
 'Hyperglycaemic metabolic disturbance',
 'Hyperglycaemic metabolic disturbance',
 'Excess circulating glucose causing osmotic, metabolic and systemic physiological disturbance.'
),

('f0a00000-0000-0000-0000-000000000069',
 'CNS-HYPOGLYCAEMIA',
 'mechanism',
 'Hypoglycaemia',
 'Hypoglycaemia',
 'Insufficient circulating glucose availability causing autonomic and neuroglycopenic manifestations.'
),

('f0a00000-0000-0000-0000-00000000006a',
 'CNS-METABOLIC-ACIDOSIS',
 'mechanism',
 'Metabolic acidosis',
 'Metabolic acidosis',
 'Reduction in systemic bicarbonate or increase in metabolic acid load producing acid-base disturbance.'
),

('f0a00000-0000-0000-0000-00000000006b',
 'CNS-ELECTROLYTE-DISRUPTION',
 'mechanism',
 'Electrolyte disturbance',
 'Electrolyte disturbance',
 'Abnormal concentration or distribution of essential electrolytes affecting cellular and organ function.'
),

('f0a00000-0000-0000-0000-00000000006c',
 'CNS-NOCICEPTIVE-INFLAMMATORY-PAIN',
 'mechanism',
 'Inflammatory nociceptive pain',
 'Inflammatory nociceptive pain',
 'Pain produced by inflammatory mediators activating peripheral nociceptive pathways.'
),

('f0a00000-0000-0000-0000-00000000006d',
 'CNS-MECHANICAL-TISSUE-PAIN',
 'mechanism',
 'Mechanical tissue pain',
 'Mechanical tissue pain',
 'Pain produced by mechanical stress, injury or dysfunction of musculoskeletal structures.'
),

('f0a00000-0000-0000-0000-00000000006e',
 'CNS-NEUROPATHIC-PAIN',
 'mechanism',
 'Neuropathic pain',
 'Neuropathic pain',
 'Pain arising from lesion or disease affecting the somatosensory nervous system.'
),

('f0a00000-0000-0000-0000-000000000070',
 'CNS-ACUTE-INFECTIVE',
 'phenotype',
 'Acute infective illness',
 'Acute infective illness',
 'Acute infection-related systemic illness pattern.'
),

('f0a00000-0000-0000-0000-000000000071',
 'CNS-CONSOLIDATION',
 'phenotype',
 'Lung consolidation',
 'Lung consolidation',
 'Alveolar consolidation pattern.'
),

('f0a00000-0000-0000-0000-000000000072',
 'CNS-PLEURITIC',
 'phenotype',
 'Pleuritic inflammation',
 'Pleuritic inflammation',
 'Pleuritic inflammatory process.'
),

('f0a00000-0000-0000-0000-000000000074',
 'CNS-THROMBOEMBOLIC',
 'phenotype',
 'Thromboembolic disease',
 'Thromboembolic disease',
 'Thromboembolic process.'
),

('f0a00000-0000-0000-0000-000000000075',
 'CNS-ACUTE-ABDOMEN',
 'phenotype',
 'Acute abdomen',
 'Acute abdomen',
 'Acute abdominal pathology.'
),

('f0a00000-0000-0000-0000-000000000076',
 'CNS-OBSTRUCTIVE-ABDOMINAL',
 'phenotype',
 'Obstructive abdominal pattern',
 'Obstructive abdominal pattern',
 'Intestinal obstruction pattern.'
),

('f0a00000-0000-0000-0000-000000000077',
 'CNS-HEPATOBILIARY',
 'phenotype',
 'Hepatobiliary disease',
 'Hepatobiliary disease',
 'Hepatobiliary pathology.'
),

('f0a00000-0000-0000-0000-000000000078',
 'CNS-RENAL-URINARY',
 'phenotype',
 'Renal or urinary disease',
 'Renal or urinary disease',
 'Renal and urinary tract pathology.'
),

('f0a00000-0000-0000-0000-000000000079',
 'CNS-PELVIC-REPRODUCTIVE',
 'phenotype',
 'Pelvic or reproductive disease',
 'Pelvic or reproductive disease',
 'Pelvic and reproductive tract pathology.'
),

('f0a00000-0000-0000-0000-00000000007a',
 'CNS-FOCAL-NEUROLOGICAL',
 'phenotype',
 'Focal neurological deficit',
 'Focal neurological deficit',
 'Focal neurological pathology.'
),

('f0a00000-0000-0000-0000-00000000007b',
 'CNS-METABOLIC-DECOMPENSATION',
 'phenotype',
 'Metabolic decompensation',
 'Metabolic decompensation',
 'Metabolic derangement pattern.'
),

('f0a00000-0000-0000-0000-00000000007c',
 'CNS-SHOCK',
 'phenotype',
 'Shock',
 'Shock',
 'Circulatory shock pattern.'
),

('f0a00000-0000-0000-0000-00000000007d',
 'CNS-INFLAMMATORY-SYSTEMIC',
 'phenotype',
 'Systemic inflammation',
 'Systemic inflammation',
 'Systemic inflammatory process.'
),

('f0a00000-0000-0000-0000-00000000007e',
 'CNS-ISCHAEMIC-PAIN',
 'phenotype',
 'Ischaemic pain',
 'Ischaemic pain',
 'Pain arising from tissue ischaemia.'
),

('f0a00000-0000-0000-0000-00000000007f',
 'CNS-INFLAMMATORY-PAIN',
 'phenotype',
 'Inflammatory pain',
 'Inflammatory pain',
 'Pain arising from inflammation.'
)


  ON CONFLICT DO NOTHING;
INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-00000000001c',
    'MECH-GRANULOMATOUS-INFECTION',
    'Chronic granulomatous pulmonary infection',
    'Persistent host-pathogen interaction producing chronic pulmonary disease.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-000000000006',
    'f0a00000-0000-0000-0000-00000000001d',
    'MECH-PULMONARY-CONGESTION',
    'Pulmonary vascular congestion',
    'Raised pulmonary venous pressure producing interstitial or alveolar fluid accumulation.',
    'CARDIOVASCULAR'
),

(
    'f0e00000-0000-0000-0000-000000000007',
    'f0a00000-0000-0000-0000-00000000001e',
    'MECH-GASTROESOPHAGEAL-REFLUX',
    'Gastroesophageal reflux',
    'Retrograde movement of gastric contents causing oesophageal or airway irritation.',
    'GASTROINTESTINAL'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 2. CARDIOVASCULAR MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000008',
    'f0a00000-0000-0000-0000-000000000040',
    'MECH-MYOCARDIAL-ISCHAEMIA',
    'Myocardial ischaemia',
    'Mismatch between myocardial oxygen demand and coronary oxygen supply causing myocardial ischaemia.',
    'CARDIOVASCULAR'
),

(
    'f0e00000-0000-0000-0000-000000000041',
    'f0a00000-0000-0000-0000-000000000041',
    'MECH-MYOCARDIAL-INJURY',
    'Myocardial injury',
    'Acute or chronic injury to myocardial cells resulting from ischaemic or non-ischaemic processes.',
    'CARDIOVASCULAR'
),

(
    'f0e00000-0000-0000-0000-000000000042',
    'f0a00000-0000-0000-0000-000000000042',
    'MECH-REDUCED-CARDIAC-OUTPUT',
    'Reduced cardiac output',
    'Failure of the cardiovascular system to maintain adequate systemic perfusion.',
    'CARDIOVASCULAR'
),

(
    'f0e00000-0000-0000-0000-000000000043',
    'f0a00000-0000-0000-0000-000000000043',
    'MECH-VOLUME-OVERLOAD',
    'Intravascular or extracellular volume overload',
    'Excess total body fluid producing venous congestion, oedema or pulmonary congestion.',
    'CARDIOVASCULAR'
),

(
    'f0e00000-0000-0000-0000-000000000044',
    'f0a00000-0000-0000-0000-000000000044',
    'MECH-ARRHYTHMIA',
    'Cardiac rhythm disturbance',
    'Abnormal cardiac impulse generation or conduction causing altered heart rate or rhythm.',
    'CARDIOVASCULAR'
),

(
    'f0e00000-0000-0000-0000-000000000045',
    'f0a00000-0000-0000-0000-000000000045',
    'MECH-AORTIC-WALL-DISRUPTION',
    'Aortic wall disruption',
    'Structural disruption of the aortic wall producing acute vascular pain and potentially life-threatening complications.',
    'CARDIOVASCULAR'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 3. RESPIRATORY MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000009',
    'f0a00000-0000-0000-0000-000000000046',
    'MECH-AIRWAY-BRONCHOCONSTRICTION',
    'Airway bronchoconstriction',
    'Reversible or partially reversible narrowing of conducting airways caused by smooth muscle contraction and related inflammatory processes.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000000a',
    'f0a00000-0000-0000-0000-000000000047',
    'MECH-AIRWAY-INFLAMMATION',
    'Airway inflammation',
    'Inflammatory changes within the airway producing cough, mucus production, wheeze and airflow limitation.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000000b',
    'f0a00000-0000-0000-0000-000000000048',
    'MECH-AIRWAY-SECRETIONS',
    'Excess airway secretions',
    'Increased mucus production or impaired mucus clearance producing productive cough and airway obstruction.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000000c',
    'f0a00000-0000-0000-0000-000000000049',
    'MECH-ALVEOLAR-INFLAMMATION',
    'Alveolar inflammatory process',
    'Inflammation and exudation within alveolar spaces impairing gas exchange.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000004a',
    'f0a00000-0000-0000-0000-00000000004a',
    'MECH-VENTILATION-PERFUSION-MISMATCH',
    'Ventilation-perfusion mismatch',
    'Unequal matching of alveolar ventilation and pulmonary perfusion resulting in impaired oxygenation.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000004b',
    'f0a00000-0000-0000-0000-00000000004b',
    'MECH-ALVEOLAR-FLOODING',
    'Alveolar flooding',
    'Accumulation of fluid, blood or inflammatory material within alveoli impairing gas exchange.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000004c',
    'f0a00000-0000-0000-0000-00000000004c',
    'MECH-PULMONARY-VASCULAR-OCCLUSION',
    'Pulmonary vascular obstruction',
    'Acute or chronic obstruction of pulmonary vascular flow producing ventilation-perfusion disturbance and potentially right-heart strain.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000004d',
    'f0a00000-0000-0000-0000-00000000004d',
    'MECH-PLEURAL-INFLAMMATION',
    'Pleural inflammation',
    'Inflammation of the pleural surfaces producing pleuritic pain and impaired respiratory mechanics.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000004e',
    'f0a00000-0000-0000-0000-00000000004e',
    'MECH-PLEURAL-AIR',
    'Pleural air accumulation',
    'Accumulation of air in the pleural space causing partial or complete lung collapse.',
    'RESPIRATORY'
),

(
    'f0e00000-0000-0000-0000-00000000004f',
    'f0a00000-0000-0000-0000-00000000004f',
    'MECH-PLEURAL-FLUID',
    'Pleural fluid accumulation',
    'Accumulation of fluid in the pleural space from infectious, inflammatory, malignant, cardiac or other processes.',
    'RESPIRATORY'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 4. INFECTIOUS / INFLAMMATORY MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000050',
    'f0a00000-0000-0000-0000-000000000050',
    'MECH-ACUTE-INFECTION',
    'Acute infectious process',
    'Host response to an acute bacterial, viral, fungal or other infectious process.',
    'SYSTEMIC'
),

(
    'f0e00000-0000-0000-0000-000000000051',
    'f0a00000-0000-0000-0000-000000000051',
    'MECH-SYSTEMIC-INFLAMMATION',
    'Systemic inflammatory response',
    'Systemic host inflammatory activation caused by infection, tissue injury or sterile inflammation.',
    'SYSTEMIC'
),

(
    'f0e00000-0000-0000-0000-000000000052',
    'f0a00000-0000-0000-0000-000000000052',
    'MECH-GRANULOMATOUS-INFLAMMATION',
    'Granulomatous inflammation',
    'Organized macrophage-dominant inflammatory response associated with persistent infectious or non-infectious stimuli.',
    'SYSTEMIC'
),

(
    'f0e00000-0000-0000-0000-000000000053',
    'f0a00000-0000-0000-0000-000000000053',
    'MECH-AUTOIMMUNE-INFLAMMATION',
    'Autoimmune inflammation',
    'Immune-mediated tissue injury directed against self-antigens.',
    'SYSTEMIC'
),

(
    'f0e00000-0000-0000-0000-000000000054',
    'f0a00000-0000-0000-0000-000000000054',
    'MECH-SEPSIS-DYSREGULATION',
    'Dysregulated systemic response to infection',
    'Life-threatening organ dysfunction arising from a dysregulated host response to infection.',
    'SYSTEMIC'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 5. GASTROINTESTINAL MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000055',
    'f0a00000-0000-0000-0000-000000000055',
    'MECH-GI-INFLAMMATION',
    'Gastrointestinal inflammation',
    'Inflammation of gastrointestinal mucosa or wall producing pain, altered bowel function and systemic symptoms.',
    'GASTROINTESTINAL'
),

(
    'f0e00000-0000-0000-0000-000000000056',
    'f0a00000-0000-0000-0000-000000000056',
    'MECH-HOLLOW-VISCUS-OBSTRUCTION',
    'Hollow viscus obstruction',
    'Mechanical or functional obstruction impairing passage through the gastrointestinal tract.',
    'GASTROINTESTINAL'
),

(
    'f0e00000-0000-0000-0000-000000000057',
    'f0a00000-0000-0000-0000-000000000057',
    'MECH-HOLLOW-VISCUS-PERFORATION',
    'Hollow viscus perforation',
    'Full-thickness disruption of a gastrointestinal or other hollow viscus allowing contents to escape into adjacent spaces.',
    'GASTROINTESTINAL'
),

(
    'f0e00000-0000-0000-0000-000000000058',
    'f0a00000-0000-0000-0000-000000000058',
    'MECH-VISCERAL-ISCHAEMIA',
    'Visceral ischaemia',
    'Inadequate blood supply to an internal organ producing tissue dysfunction and potentially infarction.',
    'GASTROINTESTINAL'
),

(
    'f0e00000-0000-0000-0000-000000000059',
    'f0a00000-0000-0000-0000-000000000059',
    'MECH-BILIARY-OBSTRUCTION',
    'Biliary obstruction',
    'Impaired bile flow caused by obstruction within the biliary system.',
    'GASTROINTESTINAL'
),

(
    'f0e00000-0000-0000-0000-00000000005a',
    'f0a00000-0000-0000-0000-00000000005a',
    'MECH-PANCREATIC-INFLAMMATION',
    'Pancreatic inflammation',
    'Inflammatory injury of pancreatic tissue producing characteristic abdominal pain and systemic inflammatory response.',
    'GASTROINTESTINAL'
),

(
    'f0e00000-0000-0000-0000-00000000005b',
    'f0a00000-0000-0000-0000-00000000005b',
    'MECH-ACID-MUCOSAL-INJURY',
    'Acid-related mucosal injury',
    'Acid-mediated injury of the upper gastrointestinal mucosa.',
    'GASTROINTESTINAL'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 6. RENAL / URINARY MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-00000000005c',
    'f0a00000-0000-0000-0000-00000000005c',
    'MECH-URINARY-INFECTION',
    'Urinary tract infection',
    'Infectious inflammation involving the urinary tract.',
    'RENAL_URINARY'
),

(
    'f0e00000-0000-0000-0000-00000000005d',
    'f0a00000-0000-0000-0000-00000000005d',
    'MECH-URINARY-OBSTRUCTION',
    'Urinary tract obstruction',
    'Impaired urinary flow due to obstruction within the urinary tract.',
    'RENAL_URINARY'
),

(
    'f0e00000-0000-0000-0000-00000000005e',
    'f0a00000-0000-0000-0000-00000000005e',
    'MECH-RENAL-PERFUSION-FAILURE',
    'Reduced renal perfusion',
    'Reduced renal blood flow causing impaired filtration and potential acute kidney injury.',
    'RENAL_URINARY'
),

(
    'f0e00000-0000-0000-0000-00000000005f',
    'f0a00000-0000-0000-0000-00000000005f',
    'MECH-RENAL-INFLAMMATION',
    'Renal inflammatory injury',
    'Inflammatory injury involving glomerular, interstitial or vascular renal structures.',
    'RENAL_URINARY'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 7. REPRODUCTIVE / OBSTETRIC MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000060',
    'f0a00000-0000-0000-0000-000000000060',
    'MECH-ECTOPIC-IMPLANTATION',
    'Extrauterine implantation',
    'Implantation of a pregnancy outside the normal endometrial uterine cavity.',
    'REPRODUCTIVE'
),

(
    'f0e00000-0000-0000-0000-000000000061',
    'f0a00000-0000-0000-0000-000000000061',
    'MECH-UTERINE-CONTRACTION',
    'Uterine contractile activity',
    'Coordinated or pathological uterine contractions producing cervical change, pain or labour.',
    'REPRODUCTIVE'
),

(
    'f0e00000-0000-0000-0000-000000000062',
    'f0a00000-0000-0000-0000-000000000062',
    'MECH-REPRODUCTIVE-INFLAMMATION',
    'Reproductive tract inflammation',
    'Inflammatory or infectious injury involving reproductive tract structures.',
    'REPRODUCTIVE'
),

(
    'f0e00000-0000-0000-0000-000000000063',
    'f0a00000-0000-0000-0000-000000000063',
    'MECH-ABNORMAL-UTERINE-BLEEDING',
    'Abnormal uterine bleeding mechanism',
    'Bleeding arising from structural, ovulatory, endocrine, pregnancy-related or other reproductive causes.',
    'REPRODUCTIVE'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 8. NEUROLOGICAL MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000064',
    'f0a00000-0000-0000-0000-000000000064',
    'MECH-CEREBRAL-ISCHAEMIA',
    'Cerebral ischaemia',
    'Reduced cerebral blood flow causing neurological dysfunction.',
    'NERVOUS'
),

(
    'f0e00000-0000-0000-0000-000000000065',
    'f0a00000-0000-0000-0000-000000000065',
    'MECH-CEREBRAL-HAEMORRHAGE',
    'Intracranial haemorrhage',
    'Bleeding within or around the intracranial compartment causing neurological injury or raised intracranial pressure.',
    'NERVOUS'
),

(
    'f0e00000-0000-0000-0000-000000000066',
    'f0a00000-0000-0000-0000-000000000066',
    'MECH-NEURONAL-HYPEREXCITABILITY',
    'Neuronal hyperexcitability',
    'Excessive synchronous neuronal activity producing seizures or related neurological manifestations.',
    'NERVOUS'
),

(
    'f0e00000-0000-0000-0000-000000000067',
    'f0a00000-0000-0000-0000-000000000067',
    'MECH-RAISED-INTRACRANIAL-PRESSURE',
    'Raised intracranial pressure',
    'Elevation of intracranial pressure caused by increased brain tissue, blood or cerebrospinal fluid volume.',
    'NERVOUS'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 9. METABOLIC / ENDOCRINE MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-000000000068',
    'f0a00000-0000-0000-0000-000000000068',
    'MECH-HYPERGLYCAEMIA',
    'Hyperglycaemic metabolic disturbance',
    'Excess circulating glucose causing osmotic, metabolic and systemic physiological disturbance.',
    'ENDOCRINE'
),

(
    'f0e00000-0000-0000-0000-000000000069',
    'f0a00000-0000-0000-0000-000000000069',
    'MECH-HYPOGLYCAEMIA',
    'Hypoglycaemia',
    'Insufficient circulating glucose availability causing autonomic and neuroglycopenic manifestations.',
    'ENDOCRINE'
),

(
    'f0e00000-0000-0000-0000-00000000006a',
    'f0a00000-0000-0000-0000-00000000006a',
    'MECH-METABOLIC-ACIDOSIS',
    'Metabolic acidosis',
    'Reduction in systemic bicarbonate or increase in metabolic acid load producing acid-base disturbance.',
    'ENDOCRINE'
),

(
    'f0e00000-0000-0000-0000-00000000006b',
    'f0a00000-0000-0000-0000-00000000006b',
    'MECH-ELECTROLYTE-DISRUPTION',
    'Electrolyte disturbance',
    'Abnormal concentration or distribution of essential electrolytes affecting cellular and organ function.',
    'ENDOCRINE'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 10. MUSCULOSKELETAL / PAIN MECHANISMS
-- =============================================================================

INSERT INTO knowledge.mechanism
(
    id,
    concept_id,
    mechanism_code,
    canonical_name,
    description,
    body_system_code
)
VALUES

(
    'f0e00000-0000-0000-0000-00000000006c',
    'f0a00000-0000-0000-0000-00000000006c',
    'MECH-NOCICEPTIVE-INFLAMMATORY-PAIN',
    'Inflammatory nociceptive pain',
    'Pain produced by inflammatory mediators activating peripheral nociceptive pathways.',
    'MUSCULOSKELETAL'
),

(
    'f0e00000-0000-0000-0000-00000000006d',
    'f0a00000-0000-0000-0000-00000000006d',
    'MECH-MECHANICAL-TISSUE-PAIN',
    'Mechanical tissue pain',
    'Pain produced by mechanical stress, injury or dysfunction of musculoskeletal structures.',
    'MUSCULOSKELETAL'
),

(
    'f0e00000-0000-0000-0000-00000000006e',
    'f0a00000-0000-0000-0000-00000000006e',
    'MECH-NEUROPATHIC-PAIN',
    'Neuropathic pain',
    'Pain arising from lesion or disease affecting the somatosensory nervous system.',
    'NERVOUS'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 11. MECHANISM FEATURES
-- =============================================================================

INSERT INTO knowledge.mechanism_feature
(mechanism_id, feature_type, feature_code, weight, polarity)
VALUES

-- Existing mechanisms --------------------------------------------------------

('f0e00000-0000-0000-0000-000000000005','fact','COUGH_DURATION_DAYS',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000005','fact','WEIGHT_LOSS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000005','fact','NIGHT_SWEATS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000005','fact','TB_CONTACT',0.9,'positive'),

('f0e00000-0000-0000-0000-000000000006','fact','DYSPNOEA_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000006','fact','ORTHOPNOEA',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000006','fact','PND',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000006','fact','CRACKLES',0.7,'positive'),
('f0e00000-0000-0000-0000-000000000006','fact','PERIPHERAL_OEDEMA',0.8,'positive'),

('f0e00000-0000-0000-0000-000000000007','fact','HEARTBURN',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000007','fact','REGURGITATION',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000007','fact','COUGH_PRESENT',0.5,'positive'),
('f0e00000-0000-0000-0000-000000000007','fact','POSTPRANDIAL_SYMPTOMS',0.8,'positive'),

-- Cardiovascular -------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000008','fact','CHEST_PAIN_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','CHEST_PAIN_PRESSURE',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','EXERTIONAL_CHEST_PAIN',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','LEFT_ARM_RADIATION',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','JAW_RADIATION',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','DIAPHORESIS',0.6,'positive'),
('f0e00000-0000-0000-0000-000000000008','fact','NAUSEA',0.4,'positive'),

('f0e00000-0000-0000-0000-000000000009','fact','WHEEZE_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000009','fact','VARIABLE_SYMPTOMS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000009','fact','TRIGGER_EXPOSURE',0.6,'positive'),

('f0e00000-0000-0000-0000-00000000000a','fact','WHEEZE_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000000a','fact','COUGH_PRESENT',0.6,'positive'),
('f0e00000-0000-0000-0000-00000000000a','fact','FEVER_PRESENT',0.4,'positive'),

('f0e00000-0000-0000-0000-00000000000b','fact','COUGH_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000000b','fact','COUGH_PRODUCTIVE',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000000b','fact','SPUTUM_PRESENT',0.9,'positive'),

('f0e00000-0000-0000-0000-00000000004a','fact','SPO2_LOW',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000004a','fact','DYSPNOEA_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000004a','fact','TACHYPNOEA',0.7,'positive'),

('f0e00000-0000-0000-0000-00000000004c','fact','SUDDEN_DYSPNOEA',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000004c','fact','PLEURITIC_CHEST_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000004c','fact','HAEMOPTYSIS',0.5,'positive'),

('f0e00000-0000-0000-0000-00000000004d','fact','PLEURITIC_CHEST_PAIN',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000004d','fact','PAIN_ON_INSPIRATION',0.9,'positive'),

('f0e00000-0000-0000-0000-00000000004e','fact','SUDDEN_DYSPNOEA',0.9,'positive'),
('f0e00000-0000-0000-0000-00000000004e','fact','UNILATERAL_REDUCED_AIR_ENTRY',0.9,'positive'),

('f0e00000-0000-0000-0000-00000000004f','fact','DYSPNOEA_PRESENT',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000004f','fact','PLEURITIC_CHEST_PAIN',0.6,'positive'),

-- Infection ------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000050','fact','FEVER_PRESENT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000050','fact','CHILLS',0.7,'positive'),
('f0e00000-0000-0000-0000-000000000050','fact','ACUTE_ONSET',0.7,'positive'),

('f0e00000-0000-0000-0000-000000000051','fact','FEVER_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000051','fact','TACHYCARDIA',0.6,'positive'),
('f0e00000-0000-0000-0000-000000000051','fact','MALAISE',0.5,'positive'),

('f0e00000-0000-0000-0000-000000000052','fact','WEIGHT_LOSS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000052','fact','NIGHT_SWEATS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000052','fact','CHRONIC_COURSE',0.8,'positive'),

('f0e00000-0000-0000-0000-000000000054','fact','FEVER_PRESENT',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000054','fact','HYPOTENSION',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000054','fact','ALTERED_MENTAL_STATUS',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000054','fact','ORGAN_DYSFUNCTION',1.0,'positive'),

-- GI -------------------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000055','fact','ABDOMINAL_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000055','fact','FEVER_PRESENT',0.5,'positive'),
('f0e00000-0000-0000-0000-000000000055','fact','DIARRHOEA',0.7,'positive'),

('f0e00000-0000-0000-0000-000000000056','fact','COLICKY_ABDOMINAL_PAIN',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000056','fact','VOMITING',0.7,'positive'),
('f0e00000-0000-0000-0000-000000000056','fact','DISTENSION',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000056','fact','FAILURE_TO_PASS_STOOL',0.9,'positive'),

('f0e00000-0000-0000-0000-000000000057','fact','SUDDEN_SEVERE_ABDOMINAL_PAIN',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000057','fact','ABDOMINAL_GUARDING',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000057','fact','ABDOMINAL_RIGIDITY',1.0,'positive'),

('f0e00000-0000-0000-0000-000000000058','fact','PAIN_OUT_OF_PROPORTION',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000058','fact','VASCULAR_RISK',0.6,'positive'),

('f0e00000-0000-0000-0000-000000000059','fact','JAUNDICE',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000059','fact','DARK_URINE',0.6,'positive'),
('f0e00000-0000-0000-0000-000000000059','fact','PALE_STOOL',0.6,'positive'),

('f0e00000-0000-0000-0000-00000000005a','fact','EPIGASTRIC_PAIN',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000005a','fact','VOMITING',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000005a','fact','BACK_RADIATION',0.7,'positive'),

('f0e00000-0000-0000-0000-00000000005b','fact','EPIGASTRIC_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000005b','fact','POSTPRANDIAL_PAIN',0.6,'positive'),

-- Renal ----------------------------------------------------------------------

('f0e00000-0000-0000-0000-00000000005c','fact','DYSURIA',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000005c','fact','URINARY_FREQUENCY',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000005c','fact','FEVER_PRESENT',0.5,'positive'),

('f0e00000-0000-0000-0000-00000000005d','fact','FLANK_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000005d','fact','ANURIA',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000005d','fact','URINARY_RETENTION',1.0,'positive'),

('f0e00000-0000-0000-0000-00000000005e','fact','HYPOTENSION',0.8,'positive'),
('f0e00000-0000-0000-0000-00000000005e','fact','DEHYDRATION',0.8,'positive'),

('f0e00000-0000-0000-0000-00000000005f','fact','HAEMATURIA',0.7,'positive'),
('f0e00000-0000-0000-0000-00000000005f','fact','PROTEINURIA',1.0,'positive'),
('f0e00000-0000-0000-0000-00000000005f','fact','OEDEMA',0.7,'positive'),

-- Reproductive --------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000060','fact','PREGNANCY_POSSIBLE',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000060','fact','LOWER_ABDOMINAL_PAIN',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000060','fact','VAGINAL_BLEEDING',0.9,'positive'),
('f0e00000-0000-0000-0000-000000000060','fact','SYNCOPE',0.7,'positive'),

('f0e00000-0000-0000-0000-000000000062','fact','PELVIC_PAIN',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000062','fact','VAGINAL_DISCHARGE',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000062','fact','FEVER_PRESENT',0.5,'positive'),

-- Neurological --------------------------------------------------------------

('f0e00000-0000-0000-0000-000000000064','fact','FOCAL_NEUROLOGICAL_DEFICIT',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000064','fact','SUDDEN_ONSET',1.0,'positive'),

('f0e00000-0000-0000-0000-000000000065','fact','SUDDEN_SEVERE_HEADACHE',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000065','fact','ALTERED_MENTAL_STATUS',0.8,'positive'),

('f0e00000-0000-0000-0000-000000000066','fact','SEIZURE',1.0,'positive'),
('f0e00000-0000-0000-0000-000000000066','fact','ALTERED_AWARENESS',0.8,'positive'),

('f0e00000-0000-0000-0000-000000000067','fact','ALTERED_MENTAL_STATUS',0.8,'positive'),
('f0e00000-0000-0000-0000-000000000067','fact','VOMITING',0.5,'positive'),
('f0e00000-0000-0000-0000-000000000067','fact','PAPILLOEDEMA',1.0,'positive')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 12. UNIVERSAL PHENOTYPES
-- =============================================================================

INSERT INTO knowledge.phenotype
(
    id,
    concept_id,
    phenotype_code,
    canonical_name,
    description
)
VALUES

(
    'f0f00000-0000-0000-0000-000000000100',
    'f0a00000-0000-0000-0000-00000000003b',
    'PHEN-AIRWAY-WHEEZE',
    'Variable obstructive airway pattern',
    'Episodic cough and breathlessness with wheeze suggesting variable airflow obstruction.'
),

(
    'f0f00000-0000-0000-0000-000000000101',
    'f0a00000-0000-0000-0000-00000000001a',
    'PHEN-CHF-CONGESTIVE',
    'Cardiopulmonary congestion pattern',
    'Cough and dyspnoea with congestion features such as orthopnoea, PND or oedema.'
),

(
    'f0f00000-0000-0000-0000-000000000102',
    'f0a00000-0000-0000-0000-00000000001b',
    'PHEN-REFLUX-COUGH',
    'Reflux-associated cough pattern',
    'Cough temporally associated with reflux or regurgitation features.'
),

(
    'f0f00000-0000-0000-0000-000000000103',
    'f0a00000-0000-0000-0000-000000000070',
    'PHEN-ACUTE-INFECTIVE',
    'Acute infective inflammatory pattern',
    'Acute illness characterized by infectious features and systemic inflammatory response.'
),

(
    'f0f00000-0000-0000-0000-000000000104',
    'f0a00000-0000-0000-0000-000000000071',
    'PHEN-CONSOLIDATION',
    'Pulmonary consolidation pattern',
    'Clinical pattern suggesting alveolar filling with inflammatory, infectious, fluid or other material.'
),

(
    'f0f00000-0000-0000-0000-000000000105',
    'f0a00000-0000-0000-0000-000000000072',
    'PHEN-PLEURITIC',
    'Pleuritic respiratory pain pattern',
    'Sharp chest pain related to inspiration or coughing suggesting pleural or adjacent tissue involvement.'
),

(
    'f0f00000-0000-0000-0000-000000000005',
    'f0a00000-0000-0000-0000-000000000030',
    'PHEN-ACUTE-HYPOXAEMIC',
    'Acute hypoxaemic respiratory pattern',
    'Acute respiratory illness characterized by impaired oxygenation and increased respiratory effort.'
),

(
    'f0f00000-0000-0000-0000-000000000107',
    'f0a00000-0000-0000-0000-000000000074',
    'PHEN-THROMBOEMBOLIC',
    'Acute thromboembolic cardiopulmonary pattern',
    'Acute dyspnoea or chest pain pattern compatible with pulmonary vascular obstruction.'
),

(
    'f0f00000-0000-0000-0000-000000000108',
    'f0a00000-0000-0000-0000-000000000075',
    'PHEN-ACUTE-ABDOMEN',
    'Acute abdominal surgical pattern',
    'Acute abdominal pain with features suggesting peritoneal irritation, obstruction, perforation or other time-critical intra-abdominal pathology.'
),

(
    'f0f00000-0000-0000-0000-000000000109',
    'f0a00000-0000-0000-0000-000000000076',
    'PHEN-OBSTRUCTIVE-ABDOMINAL',
    'Gastrointestinal obstruction pattern',
    'Abdominal pain, distension, vomiting and impaired gastrointestinal passage suggesting obstruction.'
),

(
    'f0f00000-0000-0000-0000-00000000010a',
    'f0a00000-0000-0000-0000-000000000077',
    'PHEN-HEPATOBILIARY',
    'Hepatobiliary obstructive/inflammatory pattern',
    'Abdominal symptoms associated with jaundice or other hepatobiliary features.'
),

(
    'f0f00000-0000-0000-0000-00000000010b',
    'f0a00000-0000-0000-0000-000000000078',
    'PHEN-RENAL-URINARY',
    'Renal or urinary tract pattern',
    'Pain, urinary symptoms, haematuria or renal dysfunction suggesting urinary tract pathology.'
),

(
    'f0f00000-0000-0000-0000-00000000010c',
    'f0a00000-0000-0000-0000-000000000079',
    'PHEN-PELVIC-REPRODUCTIVE',
    'Pelvic reproductive pattern',
    'Pelvic or lower abdominal symptoms occurring in a reproductive context.'
),

(
    'f0f00000-0000-0000-0000-00000000010d',
    'f0a00000-0000-0000-0000-00000000007a',
    'PHEN-FOCAL-NEUROLOGICAL',
    'Focal neurological deficit pattern',
    'Acute or subacute focal neurological dysfunction requiring localization and urgent exclusion of vascular and other structural causes.'
),

(
    'f0f00000-0000-0000-0000-00000000010e',
    'f0a00000-0000-0000-0000-00000000007b',
    'PHEN-METABOLIC-DECOMPENSATION',
    'Metabolic decompensation pattern',
    'Systemic illness with metabolic disturbance causing altered physiology, neurological symptoms or organ dysfunction.'
),

(
    'f0f00000-0000-0000-0000-000000000014',
    'f0a00000-0000-0000-0000-00000000007c',
    'PHEN-SHOCK',
    'Circulatory shock pattern',
    'Clinical pattern of inadequate effective tissue perfusion with haemodynamic or organ dysfunction.'
),

(
    'f0f00000-0000-0000-0000-000000000110',
    'f0a00000-0000-0000-0000-00000000007d',
    'PHEN-INFLAMMATORY-SYSTEMIC',
    'Systemic inflammatory phenotype',
    'Systemic manifestations resulting from significant inflammatory activation.'
),

(
    'f0f00000-0000-0000-0000-000000000111',
    'f0a00000-0000-0000-0000-00000000007e',
    'PHEN-ISCHAEMIC-PAIN',
    'Ischaemic pain pattern',
    'Pain pattern produced by inadequate tissue perfusion, interpreted according to the involved organ and clinical context.'
),

(
    'f0f00000-0000-0000-0000-000000000112',
    'f0a00000-0000-0000-0000-00000000007f',
    'PHEN-INFLAMMATORY-PAIN',
    'Inflammatory pain pattern',
    'Pain associated with local or systemic inflammatory activity.'
)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 13. PHENOTYPE FEATURES
-- =============================================================================

INSERT INTO knowledge.phenotype_feature
(
    phenotype_id,
    feature_type,
    feature_code,
    operator,
    value,
    weight,
    polarity
)
VALUES

-- AIRWAY WHEEZE --------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000100','fact','WHEEZE_PRESENT','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000100','fact','DYSPNOEA_PRESENT','eq','"YES"',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000100','fact','COUGH_PRESENT','eq','"YES"',0.6,'positive'),

-- CHF ------------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000101','fact','DYSPNOEA_PRESENT','eq','"YES"',0.5,'positive'),
('f0f00000-0000-0000-0000-000000000101','fact','ORTHOPNOEA','eq','"YES"',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000101','fact','PND','eq','"YES"',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000101','fact','CRACKLES','eq','true',0.6,'positive'),
('f0f00000-0000-0000-0000-000000000101','fact','PERIPHERAL_OEDEMA','eq','true',0.7,'positive'),

-- REFLUX ---------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000102','fact','HEARTBURN','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000102','fact','REGURGITATION','eq','"YES"',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000102','fact','COUGH_PRESENT','eq','"YES"',0.6,'positive'),

-- ACUTE INFECTION ------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000103','fact','FEVER_PRESENT','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000103','fact','CHILLS','eq','"YES"',0.6,'positive'),
('f0f00000-0000-0000-0000-000000000103','fact','ACUTE_ONSET','eq','"YES"',0.6,'positive'),

-- CONSOLIDATION --------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000104','fact','COUGH_PRESENT','eq','"YES"',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000104','fact','FEVER_PRESENT','eq','"YES"',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000104','fact','CRACKLES','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000104','fact','BRONCHIAL_BREATH_SOUNDS','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000104','fact','FOCAL_CHEST_FINDINGS','eq','true',0.8,'positive'),

-- PLEURITIC ------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000105','fact','CHEST_PAIN_PRESENT','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000105','fact','CHEST_PAIN_PLEURITIC','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000105','fact','PAIN_ON_INSPIRATION','eq','"YES"',0.9,'positive'),

-- HYPOXAEMIC -----------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000005','fact','SPO2_LOW','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000005','fact','DYSPNOEA_PRESENT','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000005','fact','TACHYPNOEA','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000005','fact','CYANOSIS','eq','true',0.8,'positive'),

-- THROMBOEMBOLIC -------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000107','fact','SUDDEN_DYSPNOEA','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000107','fact','PLEURITIC_CHEST_PAIN','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000107','fact','HAEMOPTYSIS','eq','"YES"',0.4,'positive'),

-- ACUTE ABDOMEN --------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000108','fact','ABDOMINAL_PAIN','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000108','fact','ABDOMINAL_GUARDING','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000108','fact','ABDOMINAL_RIGIDITY','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000108','fact','SUDDEN_SEVERE_ABDOMINAL_PAIN','eq','true',0.9,'positive'),

-- OBSTRUCTION ----------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000109','fact','ABDOMINAL_PAIN','eq','"YES"',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000109','fact','DISTENSION','eq','"YES"',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000109','fact','VOMITING','eq','"YES"',0.7,'positive'),
('f0f00000-0000-0000-0000-000000000109','fact','FAILURE_TO_PASS_STOOL','eq','"YES"',1.0,'positive'),

-- HEPATOBILIARY --------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000010a','fact','JAUNDICE','eq','"YES"',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000010a','fact','DARK_URINE','eq','"YES"',0.5,'positive'),
('f0f00000-0000-0000-0000-00000000010a','fact','PALE_STOOL','eq','"YES"',0.5,'positive'),

-- RENAL ----------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000010b','fact','FLANK_PAIN','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000010b','fact','DYSURIA','eq','"YES"',0.7,'positive'),
('f0f00000-0000-0000-0000-00000000010b','fact','HAEMATURIA','eq','"YES"',0.8,'positive'),

-- REPRODUCTIVE --------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000010c','fact','LOWER_ABDOMINAL_PAIN','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000010c','fact','VAGINAL_BLEEDING','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000010c','fact','PREGNANCY_POSSIBLE','eq','true',1.0,'positive'),

-- FOCAL NEUROLOGICAL ---------------------------------------------------------

('f0f00000-0000-0000-0000-00000000010d','fact','FOCAL_NEUROLOGICAL_DEFICIT','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-00000000010d','fact','SUDDEN_ONSET','eq','true',1.0,'positive'),

-- METABOLIC ------------------------------------------------------------------

('f0f00000-0000-0000-0000-00000000010e','fact','ALTERED_MENTAL_STATUS','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-00000000010e','fact','DEHYDRATION','eq','true',0.7,'positive'),
('f0f00000-0000-0000-0000-00000000010e','fact','METABOLIC_ACIDOSIS','eq','true',1.0,'positive'),

-- SHOCK ----------------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000014','fact','HYPOTENSION','eq','true',1.0,'positive'),
('f0f00000-0000-0000-0000-000000000014','fact','ALTERED_MENTAL_STATUS','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000014','fact','OLIGURIA','eq','true',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000014','fact','COLD_EXTREMITIES','eq','true',0.5,'positive'),

-- SYSTEMIC INFLAMMATION ------------------------------------------------------

('f0f00000-0000-0000-0000-000000000110','fact','FEVER_PRESENT','eq','"YES"',0.8,'positive'),
('f0f00000-0000-0000-0000-000000000110','fact','TACHYCARDIA','eq','true',0.5,'positive'),
('f0f00000-0000-0000-0000-000000000110','fact','CRP_ELEVATED','eq','true',0.5,'positive'),

-- ISCHAEMIC PAIN -------------------------------------------------------------

('f0f00000-0000-0000-0000-000000000111','fact','EXERTIONAL_CHEST_PAIN','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000111','fact','PAIN_OUT_OF_PROPORTION','eq','true',0.9,'positive'),

-- INFLAMMATORY PAIN ----------------------------------------------------------

('f0f00000-0000-0000-0000-000000000112','fact','FEVER_PRESENT','eq','"YES"',0.5,'positive'),
('f0f00000-0000-0000-0000-000000000112','fact','LOCAL_INFLAMMATION','eq','true',0.9,'positive'),
('f0f00000-0000-0000-0000-000000000112','fact','TENDERNESS','eq','true',0.6,'positive')

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 14. PHENOTYPE DOCUMENTATION
-- =============================================================================

INSERT INTO knowledge.phenotype_documentation
(
    phenotype_id,
    documentation_phrase,
    language_code,
    is_preferred
)
VALUES

('f0f00000-0000-0000-0000-000000000100',
 'Variable obstructive airway pattern with wheeze',
 'en', true),

('f0f00000-0000-0000-0000-000000000101',
 'Cardiopulmonary congestion pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000102',
 'Reflux-associated cough pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000103',
 'Acute infective inflammatory pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000104',
 'Pulmonary consolidation pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000105',
 'Pleuritic chest pain pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000005',
 'Acute hypoxaemic respiratory pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000107',
 'Acute thromboembolic cardiopulmonary pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000108',
 'Acute abdominal pattern requiring exclusion of time-critical intra-abdominal pathology',
 'en', true),

('f0f00000-0000-0000-0000-000000000109',
 'Gastrointestinal obstruction pattern',
 'en', true),

('f0f00000-0000-0000-0000-00000000010a',
 'Hepatobiliary obstructive/inflammatory pattern',
 'en', true),

('f0f00000-0000-0000-0000-00000000010b',
 'Renal or urinary tract pattern',
 'en', true),

('f0f00000-0000-0000-0000-00000000010c',
 'Pelvic reproductive pattern',
 'en', true),

('f0f00000-0000-0000-0000-00000000010d',
 'Focal neurological deficit pattern',
 'en', true),

('f0f00000-0000-0000-0000-00000000010e',
 'Metabolic decompensation pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000014',
 'Circulatory shock pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000110',
 'Systemic inflammatory phenotype',
 'en', true),

('f0f00000-0000-0000-0000-000000000111',
 'Ischaemic pain pattern',
 'en', true),

('f0f00000-0000-0000-0000-000000000112',
 'Inflammatory pain pattern',
 'en', true)

  ON CONFLICT DO NOTHING;


-- =============================================================================
-- 15. IMPORTANT ARCHITECTURAL CONTRACT
-- =============================================================================
--
-- A phenotype is NOT a diagnosis.
--
-- Example:
--
--     CHEST PAIN
--          ↓
--     ISCHAEMIC PAIN PHENOTYPE
--          ↓
--     MYOCARDIAL ISCHAEMIA MECHANISM
--          ↓
--     possible conditions:
--          ACS
--          stable coronary disease
--          coronary vasospasm
--          etc.
--
-- Another example:
--
--     DYSPNOEA
--          ↓
--     CONGESTIVE PHENOTYPE
--          ↓
--     PULMONARY CONGESTION
--          ↓
--     possible conditions:
--          heart failure
--          valvular disease
--          renal fluid overload
--          etc.
--
-- Another:
--
--     ABDOMINAL PAIN
--          ↓
--     ACUTE ABDOMEN PHENOTYPE
--          ↓
--     obstruction / inflammation / perforation / ischaemia
--          ↓
--     differential diagnosis
--
-- Therefore:
--
--     SYMPTOM != PHENOTYPE
--     PHENOTYPE != MECHANISM
--     MECHANISM != CONDITION
--
-- They are separate reusable layers.
--
-- =============================================================================