-- =============================================================================
-- AMEXAN PHASE 2 — SEED Z3
-- UNIVERSAL SYMPTOM LIBRARY
-- =============================================================================
--
-- PURPOSE
-- -------
-- Universal reusable symptom ontology for AMEXAN Clinical Intelligence.
--
-- DESIGN PRINCIPLES
-- -----------------
-- 1. Disease NEVER owns the symptom.
-- 2. One symptom = one reusable clinical concept.
-- 3. Symptoms are linked to diseases through rules / phenotypes / mechanisms.
-- 4. One symptom may belong to MANY body systems.
-- 5. One symptom may belong to MANY specialties.
-- 6. Patient language, clinician language and documentation language are
--    represented separately.
-- 7. Red flags are contextual, not intrinsic diagnoses.
-- 8. Emergency status means "can represent an emergency presentation",
--    NOT "every occurrence is an emergency".
-- 9. The same symptom can be used in adult medicine, paediatrics, surgery,
--    O&G, emergency medicine, primary care, etc.
-- 10. Common chief complaints are seeded first.
--
-- CLINICAL SOURCES / ONTOLOGY INTENT
-- ----------------------------------
-- Designed as a reusable clinical vocabulary compatible with the style of
-- major clinical-methods texts, internal medicine, surgery, paediatrics,
-- O&G, emergency medicine and primary-care history taking.
--
-- IMPORTANT
-- ---------
-- symptom_code is the stable AMEXAN identifier.
-- concept_id may point to the corresponding universal concept where that
-- concept already exists. New concepts may initially be NULL if the
-- knowledge-base concept seed has not yet been expanded.
--
-- =============================================================================



-- =============================================================================
-- 1. CORE UNIVERSAL SYMPTOMS
--    Highest-frequency / highest-value chief complaints FIRST
-- =============================================================================

INSERT INTO knowledge.symptom
(id, concept_id, symptom_code, canonical_name, definition, is_emergency)
VALUES

-- -------------------------------------------------------------------------
-- RESPIRATORY / CARDIORESPIRATORY
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000001',
 'f0a00000-0000-0000-0000-000000000001',
 'SYM-COUGH',
 'Cough',
 'A forceful expulsive manoeuvre involving the respiratory tract, usually producing a characteristic expiratory sound and serving to clear airway secretions or foreign material.',
 false),

('f0b00000-0000-0000-0000-000000000002',
 'f0a00000-0000-0000-0000-000000000002',
 'SYM-FEVER',
 'Fever',
 'A regulated elevation of core body temperature above the normal physiological range, usually associated with an altered thermoregulatory set point.',
 false),

('f0b00000-0000-0000-0000-000000000003',
 'f0a00000-0000-0000-0000-000000000003',
 'SYM-DYSPNOEA',
 'Dyspnoea',
 'Subjective awareness of difficult, uncomfortable, or laboured breathing or an uncomfortable sensation of insufficient air.',
 true),

('f0b00000-0000-0000-0000-000000000004',
 'f0a00000-0000-0000-0000-000000000004',
 'SYM-HAEMOPTYSIS',
 'Haemoptysis',
 'Expectoration of blood arising from the lower respiratory tract below the larynx.',
 true),

('f0b00000-0000-0000-0000-000000000005',
 'f0a00000-0000-0000-0000-000000000009',
 'SYM-WEIGHT-LOSS',
 'Unintentional weight loss',
 'Loss of body weight that is not intentionally undertaken by the patient.',
 false),

('f0b00000-0000-0000-0000-000000000006',
 'f0a00000-0000-0000-0000-00000000000a',
 'SYM-NIGHT-SWEATS',
 'Night sweats',
 'Episodes of excessive sweating occurring during sleep and sufficient to require changing clothing or bedding or otherwise perceived as abnormal.',
 false),

('f0b00000-0000-0000-0000-000000000007',
 NULL,
 'SYM-SPUTUM',
 'Sputum production',
 'Production and expectoration of mucus or other material from the lower respiratory tract.',
 false),

('f0b00000-0000-0000-0000-000000000008',
 NULL,
 'SYM-WHEEZE',
 'Wheeze',
 'A continuous musical respiratory sound, usually more prominent during expiration, caused by narrowed airways.',
 false),

('f0b00000-0000-0000-0000-000000000009',
 NULL,
 'SYM-STRIDOR',
 'Stridor',
 'A harsh, predominantly inspiratory respiratory sound produced by turbulent airflow through a narrowed upper airway.',
 true),

('f0b00000-0000-0000-0000-00000000000a',
 NULL,
 'SYM-CHEST-PAIN',
 'Chest pain',
 'Pain, discomfort, pressure, tightness, or other unpleasant sensation perceived in the chest.',
 true),

('f0b00000-0000-0000-0000-00000000000b',
 NULL,
 'SYM-PALPITATIONS',
 'Palpitations',
 'Subjective awareness of the heartbeat, which may be perceived as racing, pounding, fluttering, skipping, or irregular.',
 true),

('f0b00000-0000-0000-0000-00000000000c',
 NULL,
 'SYM-CYANOSIS',
 'Cyanosis',
 'Bluish or slate-coloured discoloration of skin or mucous membranes associated with increased deoxygenated haemoglobin or abnormal haemoglobin species.',
 true),


-- -------------------------------------------------------------------------
-- GENERAL / CONSTITUTIONAL
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-00000000000d',
 NULL,
 'SYM-FATIGUE',
 'Fatigue',
 'Persistent subjective feeling of physical or mental tiredness, reduced energy, or inability to sustain usual activity.',
 false),

('f0b00000-0000-0000-0000-00000000000e',
 NULL,
 'SYM-WEAKNESS',
 'Weakness',
 'Reduced ability to generate force or subjective loss of strength.',
 true),

('f0b00000-0000-0000-0000-00000000000f',
 NULL,
 'SYM-MALAISE',
 'Malaise',
 'General feeling of discomfort, illness, or lack of well-being.',
 false),

('f0b00000-0000-0000-0000-000000000010',
 NULL,
 'SYM-LOSS-OF-APPETITE',
 'Loss of appetite',
 'Reduced desire or interest in eating.',
 false),

('f0b00000-0000-0000-0000-000000000011',
 NULL,
 'SYM-NIGHT-SWEATS-HEAVY',
 'Profuse night sweating',
 'Marked sweating occurring during sleep beyond expected environmental or physiological sweating.',
 false),

('f0b00000-0000-0000-0000-000000000012',
 NULL,
 'SYM-CHILLS',
 'Chills',
 'Subjective sensation of cold, often accompanied by shivering or piloerection, commonly associated with infection or rapid temperature change.',
 false),

('f0b00000-0000-0000-0000-000000000013',
 NULL,
 'SYM-RIGORS',
 'Rigors',
 'Episodes of intense involuntary shivering, commonly associated with rapid changes in body temperature and systemic infection.',
 true),


-- -------------------------------------------------------------------------
-- PAIN — UNIVERSAL CHIEF COMPLAINTS
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000014',
 NULL,
 'SYM-HEADACHE',
 'Headache',
 'Pain or discomfort occurring in the head, scalp, or upper neck.',
 true),

('f0b00000-0000-0000-0000-000000000015',
 NULL,
 'SYM-FACIAL-PAIN',
 'Facial pain',
 'Pain perceived in the face or facial structures.',
 false),

('f0b00000-0000-0000-0000-000000000016',
 NULL,
 'SYM-NECK-PAIN',
 'Neck pain',
 'Pain perceived in the cervical region.',
 true),

('f0b00000-0000-0000-0000-000000000017',
 NULL,
 'SYM-BACK-PAIN',
 'Back pain',
 'Pain perceived in the posterior trunk, including cervical, thoracic, or lumbar regions.',
 false),

('f0b00000-0000-0000-0000-000000000018',
 NULL,
 'SYM-LOW-BACK-PAIN',
 'Low back pain',
 'Pain perceived in the lumbar or lumbosacral region.',
 false),

('f0b00000-0000-0000-0000-000000000019',
 NULL,
 'SYM-ABDOMINAL-PAIN',
 'Abdominal pain',
 'Pain or discomfort perceived within the abdominal region.',
 true),

('f0b00000-0000-0000-0000-00000000001a',
 NULL,
 'SYM-PELVIC-PAIN',
 'Pelvic pain',
 'Pain or discomfort perceived in the lower abdomen, pelvis, or pelvic organs.',
 true),

('f0b00000-0000-0000-0000-00000000001b',
 NULL,
 'SYM-LIMB-PAIN',
 'Limb pain',
 'Pain occurring in an upper or lower limb.',
 false),

('f0b00000-0000-0000-0000-00000000001c',
 NULL,
 'SYM-JOINT-PAIN',
 'Joint pain',
 'Pain perceived in or around a joint.',
 false),

('f0b00000-0000-0000-0000-00000000001d',
 NULL,
 'SYM-MUSCLE-PAIN',
 'Muscle pain',
 'Pain perceived within muscle or associated soft tissues.',
 false),

('f0b00000-0000-0000-0000-00000000001e',
 NULL,
 'SYM-BONE-PAIN',
 'Bone pain',
 'Pain perceived as arising from bone or deep musculoskeletal structures.',
 false),

('f0b00000-0000-0000-0000-00000000001f',
 NULL,
 'SYM-BREAST-PAIN',
 'Breast pain',
 'Pain or tenderness perceived in breast tissue.',
 false),


-- -------------------------------------------------------------------------
-- GASTROINTESTINAL
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000020',
 NULL,
 'SYM-NAUSEA',
 'Nausea',
 'Subjective unpleasant sensation with an urge to vomit.',
 false),

('f0b00000-0000-0000-0000-000000000021',
 NULL,
 'SYM-VOMITING',
 'Vomiting',
 'Forceful expulsion of gastric or upper gastrointestinal contents through the mouth.',
 true),

('f0b00000-0000-0000-0000-000000000022',
 NULL,
 'SYM-DIARRHOEA',
 'Diarrhoea',
 'Passage of abnormally loose or watery stools, generally with increased frequency or volume compared with the patient’s usual pattern.',
 false),

('f0b00000-0000-0000-0000-000000000023',
 NULL,
 'SYM-CONSTIPATION',
 'Constipation',
 'Infrequent, difficult, painful, or incomplete passage of stool relative to the patient’s usual bowel habit.',
 false),

('f0b00000-0000-0000-0000-000000000024',
 NULL,
 'SYM-DYSPEPSIA',
 'Dyspepsia',
 'Persistent or recurrent upper abdominal discomfort or pain, early satiety, postprandial fullness, or related upper gastrointestinal symptoms.',
 false),

('f0b00000-0000-0000-0000-000000000025',
 NULL,
 'SYM-HEARTBURN',
 'Heartburn',
 'Burning retrosternal discomfort, typically associated with reflux of gastric contents into the oesophagus.',
 false),

('f0b00000-0000-0000-0000-000000000026',
 NULL,
 'SYM-DIFFICULTY-SWALLOWING',
 'Dysphagia',
 'Difficulty or abnormality in swallowing food, liquid, saliva, or other material.',
 true),

('f0b00000-0000-0000-0000-000000000027',
 NULL,
 'SYM-PAINFUL-SWALLOWING',
 'Odynophagia',
 'Pain occurring during swallowing.',
 true),

('f0b00000-0000-0000-0000-000000000028',
 NULL,
 'SYM-BLOOD-IN-VOMIT',
 'Haematemesis',
 'Vomiting of blood or blood-containing gastric contents.',
 true),

('f0b00000-0000-0000-0000-000000000029',
 NULL,
 'SYM-BLACK-STOOL',
 'Melaena',
 'Passage of black, tarry, usually malodorous stool resulting from gastrointestinal bleeding with digestion of blood.',
 true),

('f0b00000-0000-0000-0000-00000000002a',
 NULL,
 'SYM-BLOOD-IN-STOOL',
 'Haematochezia',
 'Passage of fresh or relatively fresh blood through the rectum.',
 true),

('f0b00000-0000-0000-0000-00000000002b',
 NULL,
 'SYM-ABDOMINAL-BLOATING',
 'Abdominal bloating',
 'Subjective sensation of abdominal fullness, pressure, distension, or increased abdominal girth.',
 false),

('f0b00000-0000-0000-0000-00000000002c',
 NULL,
 'SYM-ABDOMINAL-DISTENSION',
 'Abdominal distension',
 'Visible or measurable increase in abdominal girth or abdominal enlargement.',
 true),

('f0b00000-0000-0000-0000-00000000002d',
 NULL,
 'SYM-JAUNDICE',
 'Jaundice',
 'Yellow discoloration of the skin, sclerae, and/or mucous membranes due to elevated bilirubin or related pigment accumulation.',
 true),

('f0b00000-0000-0000-0000-00000000002e',
 NULL,
 'SYM-PRURITUS',
 'Pruritus',
 'An unpleasant cutaneous sensation producing a desire to scratch.',
 false),


-- -------------------------------------------------------------------------
-- NEUROLOGICAL
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-00000000002f',
 NULL,
 'SYM-DIZZINESS',
 'Dizziness',
 'Subjective sensation of disturbed spatial orientation, light-headedness, imbalance, or altered awareness of movement without necessarily specifying a particular mechanism.',
 true),

('f0b00000-0000-0000-0000-000000000030',
 NULL,
 'SYM-VERTIGO',
 'Vertigo',
 'Illusory sensation of movement, usually rotation or spinning, of the patient or surrounding environment.',
 true),

('f0b00000-0000-0000-0000-000000000031',
 NULL,
 'SYM-SYNCOPE',
 'Syncope',
 'Transient loss of consciousness caused by transient global cerebral hypoperfusion, characterised by rapid onset, short duration, and spontaneous complete recovery.',
 true),

('f0b00000-0000-0000-0000-000000000032',
 NULL,
 'SYM-NEAR-SYNCOPE',
 'Near-syncope',
 'Transient sensation of impending loss of consciousness without complete loss of consciousness.',
 true),

('f0b00000-0000-0000-0000-000000000033',
 NULL,
 'SYM-SEIZURE',
 'Seizure',
 'A transient occurrence of signs or symptoms due to abnormal excessive or synchronous neuronal activity in the brain.',
 true),

('f0b00000-0000-0000-0000-000000000034',
 NULL,
 'SYM-LOSS-OF-CONSCIOUSNESS',
 'Loss of consciousness',
 'Transient or persistent loss of awareness and responsiveness to the environment.',
 true),

('f0b00000-0000-0000-0000-000000000035',
 NULL,
 'SYM-CONFUSION',
 'Confusion',
 'Disturbance of attention, awareness, orientation, or coherent thought.',
 true),

('f0b00000-0000-0000-0000-000000000036',
 NULL,
 'SYM-ALTERED-MENTAL-STATUS',
 'Altered mental status',
 'A clinically significant change from the patient’s usual level or quality of consciousness, cognition, behaviour, or awareness.',
 true),

('f0b00000-0000-0000-0000-000000000037',
 NULL,
 'SYM-MEMORY-LOSS',
 'Memory loss',
 'Subjective or observed impairment in the ability to encode, store, or retrieve previously learned information.',
 false),

('f0b00000-0000-0000-0000-000000000038',
 NULL,
 'SYM-MUSCLE-WEAKNESS',
 'Muscle weakness',
 'Reduced ability of skeletal muscle to generate voluntary force.',
 true),

('f0b00000-0000-0000-0000-000000000039',
 NULL,
 'SYM-NUMBNESS',
 'Numbness',
 'Subjective reduction or loss of normal skin sensation.',
 true),

('f0b00000-0000-0000-0000-00000000003a',
 NULL,
 'SYM-PARAESTHESIA',
 'Paraesthesia',
 'Abnormal sensation such as tingling, pins and needles, prickling, burning, or crawling.',
 false),

('f0b00000-0000-0000-0000-00000000003b',
 NULL,
 'SYM-PARALYSIS',
 'Paralysis',
 'Loss or marked reduction of voluntary motor function in one or more body regions.',
 true),

('f0b00000-0000-0000-0000-00000000003c',
 NULL,
 'SYM-TREMOR',
 'Tremor',
 'Involuntary rhythmic oscillatory movement of a body part.',
 false),

('f0b00000-0000-0000-0000-00000000003d',
 NULL,
 'SYM-ATAXIA',
 'Ataxia',
 'Impaired coordination of voluntary movement not primarily attributable to weakness.',
 true),

('f0b00000-0000-0000-0000-00000000003e',
 NULL,
 'SYM-SPEECH-DIFFICULTY',
 'Speech difficulty',
 'Difficulty producing or understanding spoken language or articulating speech.',
 true),

('f0b00000-0000-0000-0000-00000000003f',
 NULL,
 'SYM-VISION-LOSS',
 'Vision loss',
 'Partial or complete reduction in visual function.',
 true),

('f0b00000-0000-0000-0000-000000000040',
 NULL,
 'SYM-DOUBLE-VISION',
 'Diplopia',
 'Perception of two images of a single object.',
 true),

('f0b00000-0000-0000-0000-000000000041',
 NULL,
 'SYM-HEARING-LOSS',
 'Hearing loss',
 'Partial or complete reduction in auditory perception.',
 false),

('f0b00000-0000-0000-0000-000000000042',
 NULL,
 'SYM-TINNITUS',
 'Tinnitus',
 'Perception of sound in the absence of an external acoustic source.',
 false),


-- -------------------------------------------------------------------------
-- RENAL / URINARY
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000043',
 NULL,
 'SYM-DYSURIA',
 'Dysuria',
 'Pain, burning, discomfort, or difficulty occurring during urination.',
 false),

('f0b00000-0000-0000-0000-000000000044',
 NULL,
 'SYM-FREQUENCY',
 'Urinary frequency',
 'Need to urinate more frequently than usual.',
 false),

('f0b00000-0000-0000-0000-000000000045',
 NULL,
 'SYM-URGENCY',
 'Urinary urgency',
 'Sudden compelling desire to urinate that is difficult to defer.',
 false),

('f0b00000-0000-0000-0000-000000000046',
 NULL,
 'SYM-NOCTURIA',
 'Nocturia',
 'Waking from sleep one or more times to urinate.',
 false),

('f0b00000-0000-0000-0000-000000000047',
 NULL,
 'SYM-HAEMATURIA',
 'Haematuria',
 'Presence of blood originating from the urinary tract in the urine.',
 true),

('f0b00000-0000-0000-0000-000000000048',
 NULL,
 'SYM-URINARY-RETENTION',
 'Urinary retention',
 'Inability to empty the urinary bladder adequately or completely.',
 true),

('f0b00000-0000-0000-0000-000000000049',
 NULL,
 'SYM-URINARY-INCONTINENCE',
 'Urinary incontinence',
 'Involuntary leakage of urine.',
 false),

('f0b00000-0000-0000-0000-00000000004a',
 NULL,
 'SYM-POLYURIA',
 'Polyuria',
 'Excessive urine production, conventionally defined in adults as urine output exceeding approximately 3 litres per day.',
 false),

('f0b00000-0000-0000-0000-00000000004b',
 NULL,
 'SYM-OLIGURIA',
 'Oliguria',
 'Abnormally reduced urine output.',
 true),

('f0b00000-0000-0000-0000-00000000004c',
 NULL,
 'SYM-FLANK-PAIN',
 'Flank pain',
 'Pain perceived between the upper abdomen and posterior lateral trunk over the region of the kidneys.',
 true),


-- -------------------------------------------------------------------------
-- ENDOCRINE / METABOLIC
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-00000000004d',
 NULL,
 'SYM-POLYDIPSIA',
 'Polydipsia',
 'Excessive thirst or abnormal increase in fluid-seeking behaviour.',
 false),

('f0b00000-0000-0000-0000-00000000004e',
 NULL,
 'SYM-POLYPHAGIA',
 'Polyphagia',
 'Excessive or abnormally increased appetite.',
 false),

('f0b00000-0000-0000-0000-00000000004f',
 NULL,
 'SYM-HEAT-INTOLERANCE',
 'Heat intolerance',
 'Abnormal discomfort or inability to tolerate environmental heat.',
 false),

('f0b00000-0000-0000-0000-000000000050',
 NULL,
 'SYM-COLD-INTOLERANCE',
 'Cold intolerance',
 'Abnormal discomfort or inability to tolerate environmental cold.',
 false),

('f0b00000-0000-0000-0000-000000000051',
 NULL,
 'SYM-EXCESSIVE-SWEATING',
 'Excessive sweating',
 'Sweating greater than expected for environmental conditions, physical activity, or physiological need.',
 false),

('f0b00000-0000-0000-0000-000000000052',
 NULL,
 'SYM-PERIPHERAL-OEDEMA',
 'Peripheral oedema',
 'Abnormal accumulation of interstitial fluid producing swelling, commonly of the dependent limbs.',
 true),


-- -------------------------------------------------------------------------
-- SKIN
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000053',
 NULL,
 'SYM-RASH',
 'Rash',
 'A visible abnormality of the skin including alteration in colour, texture, elevation, or distribution.',
 false),

('f0b00000-0000-0000-0000-000000000054',
 NULL,
 'SYM-SKIN-ULCER',
 'Skin ulcer',
 'Loss of epidermal and dermal tissue resulting in an open lesion of the skin.',
 false),

('f0b00000-0000-0000-0000-000000000055',
 NULL,
 'SYM-SKIN-LUMP',
 'Skin lump',
 'A palpable or visible localised elevation, mass, swelling, or nodule within or beneath the skin.',
 false),

('f0b00000-0000-0000-0000-000000000056',
 NULL,
 'SYM-ITCHING',
 'Itching',
 'An unpleasant skin sensation producing a desire to scratch.',
 false),

('f0b00000-0000-0000-0000-000000000057',
 NULL,
 'SYM-HAIR-LOSS',
 'Hair loss',
 'Reduction or loss of hair from a previously hair-bearing region.',
 false),


-- -------------------------------------------------------------------------
-- ENT / HEAD AND NECK
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000058',
 NULL,
 'SYM-SORE-THROAT',
 'Sore throat',
 'Pain, irritation, or discomfort in the throat, particularly during swallowing.',
 false),

('f0b00000-0000-0000-0000-000000000059',
 NULL,
 'SYM-RUNNY-NOSE',
 'Rhinorrhoea',
 'Excessive discharge of fluid or mucus from the nasal passages.',
 false),

('f0b00000-0000-0000-0000-00000000005a',
 NULL,
 'SYM-NASAL-CONGESTION',
 'Nasal congestion',
 'Obstruction or blockage of the nasal passages resulting in impaired nasal airflow.',
 false),

('f0b00000-0000-0000-0000-00000000005b',
 NULL,
 'SYM-NOSEBLEED',
 'Epistaxis',
 'Bleeding originating from the nasal cavity.',
 true),

('f0b00000-0000-0000-0000-00000000005c',
 NULL,
 'SYM-HOARSENESS',
 'Hoarseness',
 'Alteration in voice quality including roughness, breathiness, weakness, or abnormal pitch.',
 false),

('f0b00000-0000-0000-0000-00000000005d',
 NULL,
 'SYM-EAR-PAIN',
 'Otalgia',
 'Pain perceived in or around the ear.',
 false),

('f0b00000-0000-0000-0000-00000000005e',
 NULL,
 'SYM-EAR-DISCHARGE',
 'Otorrhoea',
 'Discharge of fluid, pus, blood, or other material from the ear canal.',
 false),

('f0b00000-0000-0000-0000-00000000005f',
 NULL,
 'SYM-TOOTHACHE',
 'Toothache',
 'Pain arising from or perceived in a tooth or surrounding dental structures.',
 false),

('f0b00000-0000-0000-0000-000000000060',
 NULL,
 'SYM-FACIAL-SWELLING',
 'Facial swelling',
 'Localised or generalised enlargement or oedema of facial tissues.',
 true),


-- -------------------------------------------------------------------------
-- OPHTHALMOLOGY
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000061',
 NULL,
 'SYM-EYE-PAIN',
 'Eye pain',
 'Pain or significant discomfort perceived in or around the eye.',
 true),

('f0b00000-0000-0000-0000-000000000062',
 NULL,
 'SYM-RED-EYE',
 'Red eye',
 'Visible conjunctival or ocular redness caused by vascular dilation, inflammation, haemorrhage, or other ocular pathology.',
 false),

('f0b00000-0000-0000-0000-000000000063',
 NULL,
 'SYM-EYE-DISCHARGE',
 'Eye discharge',
 'Abnormal fluid, mucus, pus, or other material discharged from the eye.',
 false),

('f0b00000-0000-0000-0000-000000000064',
 NULL,
 'SYM-FLOATERS',
 'Visual floaters',
 'Perception of spots, threads, cobwebs, or other moving shapes within the visual field.',
 true),

('f0b00000-0000-0000-0000-000000000065',
 NULL,
 'SYM-FLASHES',
 'Photopsia',
 'Perception of flashes or brief bursts of light without an external light stimulus.',
 true),


-- -------------------------------------------------------------------------
-- REPRODUCTIVE / OBGYN
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000066',
 NULL,
 'SYM-VAGINAL-BLEEDING',
 'Vaginal bleeding',
 'Bleeding from the female genital tract occurring outside the expected pattern of menstruation or at another clinically relevant time.',
 true),

('f0b00000-0000-0000-0000-000000000067',
 NULL,
 'SYM-HEAVY-MENSTRUAL-BLEEDING',
 'Heavy menstrual bleeding',
 'Menstrual bleeding that is excessive in volume, duration, frequency, or impact on quality of life.',
 false),

('f0b00000-0000-0000-0000-000000000068',
 NULL,
 'SYM-PAINFUL-MENSTRUATION',
 'Dysmenorrhoea',
 'Painful menstruation occurring during the menstrual period.',
 false),

('f0b00000-0000-0000-0000-000000000069',
 NULL,
 'SYM-AMENORRHOEA',
 'Amenorrhoea',
 'Absence of menstrual bleeding during a period when menstruation would otherwise be expected.',
 false),

('f0b00000-0000-0000-0000-00000000006a',
 NULL,
 'SYM-VAGINAL-DISCHARGE',
 'Vaginal discharge',
 'Abnormal or clinically significant vaginal fluid or discharge perceived by the patient.',
 false),

('f0b00000-0000-0000-0000-00000000006b',
 NULL,
 'SYM-VAGINAL-ITCH',
 'Vulvovaginal itching',
 'Itching or pruritus involving the vulva and/or vagina.',
 false),

('f0b00000-0000-0000-0000-00000000006c',
 NULL,
 'SYM-POSTCOITAL-BLEEDING',
 'Postcoital bleeding',
 'Vaginal bleeding occurring during or after sexual intercourse.',
 false),

('f0b00000-0000-0000-0000-00000000006d',
 NULL,
 'SYM-INFERTILITY',
 'Infertility',
 'Failure to achieve pregnancy after an appropriate period of regular unprotected intercourse.',
 false),

('f0b00000-0000-0000-0000-00000000006e',
 NULL,
 'SYM-PREGNANCY-RELATED-VOMITING',
 'Nausea and vomiting in pregnancy',
 'Nausea and/or vomiting occurring during pregnancy.',
 false),

('f0b00000-0000-0000-0000-00000000006f',
 NULL,
 'SYM-REDUCED-FETAL-MOVEMENT',
 'Reduced fetal movement',
 'Patient-perceived reduction or alteration in expected fetal movements during pregnancy.',
 true),

('f0b00000-0000-0000-0000-000000000070',
 NULL,
 'SYM-LEAKING-FLUID-PREGNANCY',
 'Leakage of fluid in pregnancy',
 'Patient-reported leakage of fluid from the vagina during pregnancy, potentially representing rupture of membranes.',
 true),

('f0b00000-0000-0000-0000-000000000071',
 NULL,
 'SYM-CONTRACTIONS',
 'Uterine contractions',
 'Rhythmic or irregular tightening sensations of the uterus perceived during pregnancy or labour.',
 true),


-- -------------------------------------------------------------------------
-- MALE GENITOURINARY
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000072',
 NULL,
 'SYM-TESTICULAR-PAIN',
 'Testicular pain',
 'Pain perceived in one or both testes or adjacent scrotal structures.',
 true),

('f0b00000-0000-0000-0000-000000000073',
 NULL,
 'SYM-SCROTAL-SWELLING',
 'Scrotal swelling',
 'Abnormal enlargement or swelling of the scrotal contents or scrotal wall.',
 true),

('f0b00000-0000-0000-0000-000000000074',
 NULL,
 'SYM-PENILE-DISCHARGE',
 'Penile discharge',
 'Abnormal fluid or discharge emerging from the urethral opening.',
 false),

('f0b00000-0000-0000-0000-000000000075',
 NULL,
 'SYM-ERECTILE-DYSFUNCTION',
 'Erectile dysfunction',
 'Persistent or recurrent inability to attain or maintain an erection sufficient for satisfactory sexual activity.',
 false),

('f0b00000-0000-0000-0000-000000000076',
 NULL,
 'SYM-EJACULATORY-DIFFICULTY',
 'Ejaculatory difficulty',
 'Difficulty, delay, absence, or abnormality of ejaculation.',
 false),


-- -------------------------------------------------------------------------
-- PAEDIATRIC / NEONATAL PRESENTATIONS
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000077',
 NULL,
 'SYM-POOR-FEEDING',
 'Poor feeding',
 'Reduced ability, willingness, or amount of feeding compared with the patient’s expected pattern, particularly relevant in infants and children.',
 true),

('f0b00000-0000-0000-0000-000000000078',
 NULL,
 'SYM-EXCESSIVE-CRYING',
 'Excessive crying',
 'Crying that is prolonged, unusually frequent, difficult to console, or significantly different from the child’s usual behaviour.',
 false),

('f0b00000-0000-0000-0000-000000000079',
 NULL,
 'SYM-LETHARGY',
 'Lethargy',
 'Abnormally reduced energy, activity, responsiveness, or interaction.',
 true),

('f0b00000-0000-0000-0000-00000000007a',
 NULL,
 'SYM-FAILURE-TO-THRIVE',
 'Poor weight gain / growth faltering',
 'Inadequate physical growth or weight gain relative to expected growth trajectory.',
 false),

('f0b00000-0000-0000-0000-00000000007b',
 NULL,
 'SYM-DEHYDRATION-SYMPTOMS',
 'Symptoms of dehydration',
 'Patient or caregiver reported symptoms suggestive of reduced body fluid volume, including thirst, reduced urine output, lethargy, or dry mouth.',
 true),


-- -------------------------------------------------------------------------
-- BLEEDING / HAEMATOLOGICAL
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-00000000007c',
 NULL,
 'SYM-EASY-BRUSING',
 'Easy bruising',
 'Bruising occurring with minimal or no recognised trauma.',
 false),

('f0b00000-0000-0000-0000-00000000007d',
 NULL,
 'SYM-ABNORMAL-BLEEDING',
 'Abnormal bleeding',
 'Bleeding that is excessive, spontaneous, prolonged, recurrent, or otherwise disproportionate to the triggering event.',
 true),

('f0b00000-0000-0000-0000-00000000007e',
 NULL,
 'SYM-PALLOR',
 'Pallor',
 'Abnormally pale appearance of the skin, conjunctivae, mucous membranes, or other tissues.',
 false),


-- -------------------------------------------------------------------------
-- BREAST
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-00000000007f',
 NULL,
 'SYM-BREAST-LUMP',
 'Breast lump',
 'A palpable or otherwise clinically detectable focal mass within breast tissue.',
 false),

('f0b00000-0000-0000-0000-000000000080',
 NULL,
 'SYM-NIPPLE-DISCHARGE',
 'Nipple discharge',
 'Fluid emerging from the nipple that is spontaneous or expressed and may be physiologic or pathological.',
 false),

('f0b00000-0000-0000-0000-000000000081',
 NULL,
 'SYM-NIPPLE-CHANGE',
 'Nipple change',
 'New structural, positional, colour, skin, or contour change involving the nipple.',
 false),


-- -------------------------------------------------------------------------
-- SWELLING / MASSES
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000082',
 NULL,
 'SYM-LOCALIZED-SWELLING',
 'Localised swelling',
 'Focal enlargement of a body region caused by fluid, inflammation, tissue proliferation, vascular change, or another process.',
 false),

('f0b00000-0000-0000-0000-000000000083',
 NULL,
 'SYM-GENERALISED-SWELLING',
 'Generalised swelling',
 'Widespread or multi-site enlargement of body tissues, commonly related to fluid accumulation or systemic disease.',
 true),

('f0b00000-0000-0000-0000-000000000084',
 NULL,
 'SYM-MASS',
 'Mass',
 'A localised abnormal accumulation or enlargement of tissue perceived as a lump or mass.',
 false),

('f0b00000-0000-0000-0000-000000000085',
 NULL,
 'SYM-NECK-MASS',
 'Neck mass',
 'A focal lump, enlargement, or swelling occurring in the neck.',
 true),

('f0b00000-0000-0000-0000-000000000086',
 NULL,
 'SYM-LYMPH-NODE-SWELLING',
 'Lymph node swelling',
 'Patient-perceived or clinically detected enlargement of one or more lymph nodes.',
 false),


-- -------------------------------------------------------------------------
-- FUNCTIONAL / PSYCHIATRIC / SLEEP
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000087',
 NULL,
 'SYM-INSOMNIA',
 'Insomnia',
 'Difficulty initiating sleep, maintaining sleep, or achieving restorative sleep despite adequate opportunity for sleep.',
 false),

('f0b00000-0000-0000-0000-000000000088',
 NULL,
 'SYM-EXCESSIVE-DAYTIME-SLEEPINESS',
 'Excessive daytime sleepiness',
 'Abnormally increased tendency to fall asleep or struggle to remain awake during daytime.',
 false),

('f0b00000-0000-0000-0000-000000000089',
 NULL,
 'SYM-LOW-MOOD',
 'Low mood',
 'Subjective feeling of sadness, reduced mood, or emotional distress.',
 false),

('f0b00000-0000-0000-0000-00000000008a',
 NULL,
 'SYM-ANXIETY',
 'Anxiety',
 'Subjective experience of excessive worry, apprehension, fear, or physiological arousal related to perceived threat or uncertainty.',
 false),

('f0b00000-0000-0000-0000-00000000008b',
 NULL,
 'SYM-AGITATION',
 'Agitation',
 'Excessive motor activity, restlessness, or behavioural activation often accompanied by emotional distress or altered mental status.',
 true),

('f0b00000-0000-0000-0000-00000000008c',
 NULL,
 'SYM-SUICIDAL-THOUGHTS',
 'Suicidal thoughts',
 'Thoughts, ideas, wishes, or intentions concerning death or ending one’s own life.',
 true),


-- -------------------------------------------------------------------------
-- SEXUAL HEALTH / GENITAL
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-00000000008d',
 NULL,
 'SYM-GENITAL-ULCER',
 'Genital ulcer',
 'An ulcerative lesion involving genital skin or mucosa.',
 false),

('f0b00000-0000-0000-0000-00000000008e',
 NULL,
 'SYM-GENITAL-LUMP',
 'Genital lump',
 'A focal palpable or visible mass involving genital structures.',
 false),

('f0b00000-0000-0000-0000-00000000008f',
 NULL,
 'SYM-GENITAL-ITCHING',
 'Genital itching',
 'Itching involving external or internal genital structures.',
 false),


-- -------------------------------------------------------------------------
-- TRAUMA / ACUTE SURGICAL PRESENTATIONS
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000090',
 NULL,
 'SYM-INJURY',
 'Injury',
 'Damage to body tissue caused by an external mechanical, thermal, chemical, electrical, or other physical force.',
 true),

('f0b00000-0000-0000-0000-000000000091',
 NULL,
 'SYM-FALL',
 'Fall',
 'An event in which the patient unintentionally comes to rest on the ground, floor, or another lower level.',
 true),

('f0b00000-0000-0000-0000-000000000092',
 NULL,
 'SYM-BURN',
 'Burn injury',
 'Tissue injury caused by thermal, chemical, electrical, radiation, or frictional exposure.',
 true),

('f0b00000-0000-0000-0000-000000000093',
 NULL,
 'SYM-WOUND',
 'Wound',
 'Disruption of the normal integrity of skin or deeper tissues due to injury or another pathological process.',
 false),

('f0b00000-0000-0000-0000-000000000094',
 NULL,
 'SYM-ACUTE-LIMB-SWELLING',
 'Acute limb swelling',
 'New or rapidly developing swelling involving an upper or lower limb.',
 true),

('f0b00000-0000-0000-0000-000000000095',
 NULL,
 'SYM-ACUTE-LIMB-PAIN',
 'Acute limb pain',
 'Sudden or recently developed significant pain involving an upper or lower limb.',
 true),


-- -------------------------------------------------------------------------
-- EMERGENCY / UNIVERSAL
-- -------------------------------------------------------------------------

('f0b00000-0000-0000-0000-000000000096',
 NULL,
 'SYM-COLLAPSE',
 'Collapse',
 'Sudden loss of strength, postural tone, consciousness, or ability to remain upright.',
 true),

('f0b00000-0000-0000-0000-000000000097',
 NULL,
 'SYM-SHOCK-SYMPTOMS',
 'Symptoms suggestive of shock',
 'Patient-reported or observed symptoms associated with inadequate systemic perfusion, such as severe weakness, faintness, confusion, or cold clammy sensation.',
 true),

('f0b00000-0000-0000-0000-000000000098',
 NULL,
 'SYM-SEVERE-PAIN',
 'Severe pain',
 'Pain of high intensity or pain associated with substantial functional impairment or distress.',
 true),

('f0b00000-0000-0000-0000-000000000099',
 NULL,
 'SYM-ACUTE-CONFUSION',
 'Acute confusion',
 'New or rapidly developing disturbance of attention, awareness, cognition, or behaviour.',
 true)

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 2. UNIVERSAL PATIENT-LANGUAGE SYNONYMS
-- =============================================================================
-- These are deliberately separate from canonical documentation language.
-- The NLP / UI layer may map colloquial expressions to the same symptom.
-- =============================================================================

INSERT INTO knowledge.symptom_synonym
(symptom_id, synonym, language_code, is_preferred)
VALUES

-- Respiratory
('f0b00000-0000-0000-0000-000000000001','Cough','en',true),
('f0b00000-0000-0000-0000-000000000001','Kikohozi','sw',true),
('f0b00000-0000-0000-0000-000000000003','Shortness of breath','en',false),
('f0b00000-0000-0000-0000-000000000003','Breathlessness','en',false),
('f0b00000-0000-0000-0000-000000000003','Difficulty breathing','en',false),
('f0b00000-0000-0000-0000-000000000003','Upungufu wa pumzi','sw',true),
('f0b00000-0000-0000-0000-000000000004','Coughing blood','en',false),
('f0b00000-0000-0000-0000-000000000004','Blood in sputum','en',false),
('f0b00000-0000-0000-0000-000000000004','Kukohoa damu','sw',true),
('f0b00000-0000-0000-0000-00000000000a','Chest pain','en',true),
('f0b00000-0000-0000-0000-00000000000a','Pain in the chest','en',false),

-- General
('f0b00000-0000-0000-0000-000000000002','Fever','en',true),
('f0b00000-0000-0000-0000-000000000002','High temperature','en',false),
('f0b00000-0000-0000-0000-000000000002','Homa','sw',true),
('f0b00000-0000-0000-0000-00000000000d','Tiredness','en',false),
('f0b00000-0000-0000-0000-00000000000d','Feeling tired','en',false),
('f0b00000-0000-0000-0000-00000000000e','Weakness','en',true),
('f0b00000-0000-0000-0000-00000000000e','Loss of strength','en',false),

-- Pain
('f0b00000-0000-0000-0000-000000000014','Head pain','en',false),
('f0b00000-0000-0000-0000-000000000019','Stomach pain','en',false),
('f0b00000-0000-0000-0000-000000000019','Tummy pain','en',false),
('f0b00000-0000-0000-0000-000000000019','Abdominal pain','en',true),
('f0b00000-0000-0000-0000-000000000017','Backache','en',false),
('f0b00000-0000-0000-0000-00000000001c','Pain in the joints','en',false),

-- GI
('f0b00000-0000-0000-0000-000000000020','Feeling sick','en',false),
('f0b00000-0000-0000-0000-000000000021','Being sick','en',false),
('f0b00000-0000-0000-0000-000000000022','Loose stool','en',false),
('f0b00000-0000-0000-0000-000000000022','Loose stools','en',false),
('f0b00000-0000-0000-0000-000000000023','Difficulty passing stool','en',false),
('f0b00000-0000-0000-0000-00000000002d','Yellow eyes','en',false),
('f0b00000-0000-0000-0000-00000000002d','Yellow skin','en',false),

-- Neurological
('f0b00000-0000-0000-0000-00000000002f','Light-headedness','en',false),
('f0b00000-0000-0000-0000-00000000002f','Feeling faint','en',false),
('f0b00000-0000-0000-0000-000000000030','Room spinning','en',false),
('f0b00000-0000-0000-0000-000000000031','Fainted','en',false),
('f0b00000-0000-0000-0000-000000000031','Passed out','en',false),
('f0b00000-0000-0000-0000-000000000039','Loss of sensation','en',false),
('f0b00000-0000-0000-0000-00000000003b','Cannot move','en',false),

-- Urinary
('f0b00000-0000-0000-0000-000000000043','Painful urination','en',false),
('f0b00000-0000-0000-0000-000000000043','Burning urine','en',false),
('f0b00000-0000-0000-0000-000000000047','Blood in urine','en',true),
('f0b00000-0000-0000-0000-00000000004c','Kidney pain','en',true),

-- ENT
('f0b00000-0000-0000-0000-000000000058','Throat pain','en',false),
('f0b00000-0000-0000-0000-000000000059','Runny nose','en',false),
('f0b00000-0000-0000-0000-00000000005a','Blocked nose','en',false),
('f0b00000-0000-0000-0000-00000000005b','Nose bleeding','en',true),
('f0b00000-0000-0000-0000-00000000005d','Earache','en',false),

-- OBGYN
('f0b00000-0000-0000-0000-000000000066','Bleeding per vagina','en',true),
('f0b00000-0000-0000-0000-00000000006a','Vaginal discharge','en',false),
('f0b00000-0000-0000-0000-000000000068','Period pain','en',false),
('f0b00000-0000-0000-0000-000000000069','No periods','en',false),
('f0b00000-0000-0000-0000-00000000006f','Baby moving less','en',true),

-- Paediatric
('f0b00000-0000-0000-0000-000000000077','Not feeding well','en',true),
('f0b00000-0000-0000-0000-000000000077','Poor appetite in baby','en',false),
('f0b00000-0000-0000-0000-000000000078','Baby crying a lot','en',false),
('f0b00000-0000-0000-0000-000000000079','Very sleepy','en',true),

-- Breast
('f0b00000-0000-0000-0000-00000000007f','Lump in breast','en',false),
('f0b00000-0000-0000-0000-000000000080','Fluid from nipple','en',false),

-- Emergency
('f0b00000-0000-0000-0000-000000000096','Collapsed','en',true),
('f0b00000-0000-0000-0000-000000000098','Very severe pain','en',true)

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 3. BODY-SYSTEM ASSOCIATIONS
-- =============================================================================
-- A symptom may legitimately belong to several systems.
-- relevance is NOT probability of disease.
-- It is the strength of the symptom's relationship to that system.
-- =============================================================================

INSERT INTO knowledge.symptom_system
(symptom_id, body_system_code, relevance)
VALUES

-- Cough
('f0b00000-0000-0000-0000-000000000001','RESPIRATORY',1.0),
('f0b00000-0000-0000-0000-000000000001','CARDIOVASCULAR',0.5),
('f0b00000-0000-0000-0000-000000000001','GASTROINTESTINAL',0.3),
('f0b00000-0000-0000-0000-000000000001','HEAD_NECK',0.3),

-- Fever
('f0b00000-0000-0000-0000-000000000002','CONSTITUTIONAL',1.0),
('f0b00000-0000-0000-0000-000000000002','IMMUNE',0.9),
('f0b00000-0000-0000-0000-000000000002','RESPIRATORY',0.5),
('f0b00000-0000-0000-0000-000000000002','GASTROINTESTINAL',0.4),
('f0b00000-0000-0000-0000-000000000002','NEUROLOGICAL',0.3),

-- Dyspnoea
('f0b00000-0000-0000-0000-000000000003','RESPIRATORY',1.0),
('f0b00000-0000-0000-0000-000000000003','CARDIOVASCULAR',0.9),
('f0b00000-0000-0000-0000-000000000003','HAEMATOLOGICAL',0.4),
('f0b00000-0000-0000-0000-000000000003','PSYCHIATRIC',0.3),

-- Haemoptysis
('f0b00000-0000-0000-0000-000000000004','RESPIRATORY',1.0),
('f0b00000-0000-0000-0000-000000000004','CARDIOVASCULAR',0.4),

-- Weight loss
('f0b00000-0000-0000-0000-000000000005','CONSTITUTIONAL',1.0),
('f0b00000-0000-0000-0000-000000000005','GASTROINTESTINAL',0.7),
('f0b00000-0000-0000-0000-000000000005','ENDOCRINE',0.7),
('f0b00000-0000-0000-0000-000000000005','IMMUNE',0.5),
('f0b00000-0000-0000-0000-000000000005','ONCOLOGICAL',0.6),

-- Chest pain
('f0b00000-0000-0000-0000-00000000000a','CARDIOVASCULAR',1.0),
('f0b00000-0000-0000-0000-00000000000a','RESPIRATORY',0.8),
('f0b00000-0000-0000-0000-00000000000a','GASTROINTESTINAL',0.5),
('f0b00000-0000-0000-0000-00000000000a','MUSCULOSKELETAL',0.5),
('f0b00000-0000-0000-0000-00000000000a','PSYCHIATRIC',0.2),

-- Palpitations
('f0b00000-0000-0000-0000-00000000000b','CARDIOVASCULAR',1.0),
('f0b00000-0000-0000-0000-00000000000b','ENDOCRINE',0.5),
('f0b00000-0000-0000-0000-00000000000b','HAEMATOLOGICAL',0.4),
('f0b00000-0000-0000-0000-00000000000b','PSYCHIATRIC',0.3),

-- Headache
('f0b00000-0000-0000-0000-000000000014','NEUROLOGICAL',1.0),
('f0b00000-0000-0000-0000-000000000014','HEAD_NECK',0.6),
('f0b00000-0000-0000-0000-000000000014','IMMUNE',0.3),

-- Abdominal pain
('f0b00000-0000-0000-0000-000000000019','GASTROINTESTINAL',1.0),
('f0b00000-0000-0000-0000-000000000019','RENAL_URINARY',0.6),
('f0b00000-0000-0000-0000-000000000019','REPRODUCTIVE',0.6),
('f0b00000-0000-0000-0000-000000000019','MUSCULOSKELETAL',0.3),

-- Nausea/vomiting
('f0b00000-0000-0000-0000-000000000020','GASTROINTESTINAL',1.0),
('f0b00000-0000-0000-0000-000000000020','NEUROLOGICAL',0.4),
('f0b00000-0000-0000-0000-000000000020','REPRODUCTIVE',0.5),
('f0b00000-0000-0000-0000-000000000021','GASTROINTESTINAL',1.0),
('f0b00000-0000-0000-0000-000000000021','NEUROLOGICAL',0.5),
('f0b00000-0000-0000-0000-000000000021','REPRODUCTIVE',0.5),

-- Diarrhoea
('f0b00000-0000-0000-0000-000000000022','GASTROINTESTINAL',1.0),
('f0b00000-0000-0000-0000-000000000022','IMMUNE',0.5),

-- Jaundice
('f0b00000-0000-0000-0000-00000000002d','GASTROINTESTINAL',0.8),
('f0b00000-0000-0000-0000-00000000002d','HAEMATOLOGICAL',0.7),
('f0b00000-0000-0000-0000-00000000002d','CONSTITUTIONAL',0.4),

-- Dizziness
('f0b00000-0000-0000-0000-00000000002f','NEUROLOGICAL',1.0),
('f0b00000-0000-0000-0000-00000000002f','CARDIOVASCULAR',0.7),
('f0b00000-0000-0000-0000-00000000002f','HAEMATOLOGICAL',0.4),

-- Syncope
('f0b00000-0000-0000-0000-000000000031','CARDIOVASCULAR',1.0),
('f0b00000-0000-0000-0000-000000000031','NEUROLOGICAL',0.8),
('f0b00000-0000-0000-0000-000000000031','HAEMATOLOGICAL',0.4),

-- Seizure
('f0b00000-0000-0000-0000-000000000033','NEUROLOGICAL',1.0),
('f0b00000-0000-0000-0000-000000000033','METABOLIC',0.4),

-- Weakness
('f0b00000-0000-0000-0000-00000000000e','NEUROLOGICAL',0.8),
('f0b00000-0000-0000-0000-00000000000e','MUSCULOSKELETAL',0.7),
('f0b00000-0000-0000-0000-00000000000e','HAEMATOLOGICAL',0.6),
('f0b00000-0000-0000-0000-00000000000e','ENDOCRINE',0.5),
('f0b00000-0000-0000-0000-00000000000e','CONSTITUTIONAL',0.5),

-- Dysuria
('f0b00000-0000-0000-0000-000000000043','RENAL_URINARY',1.0),
('f0b00000-0000-0000-0000-000000000043','REPRODUCTIVE',0.4),

-- Haematuria
('f0b00000-0000-0000-0000-000000000047','RENAL_URINARY',1.0),

-- Rash
('f0b00000-0000-0000-0000-000000000053','INTEGUMENTARY',1.0),
('f0b00000-0000-0000-0000-000000000053','IMMUNE',0.7),
('f0b00000-0000-0000-0000-000000000053','HAEMATOLOGICAL',0.3),

-- Vaginal bleeding
('f0b00000-0000-0000-0000-000000000066','REPRODUCTIVE',1.0),
('f0b00000-0000-0000-0000-000000000066','HAEMATOLOGICAL',0.3),

-- Reduced fetal movement
('f0b00000-0000-0000-0000-00000000006f','REPRODUCTIVE',1.0),

-- Testicular pain
('f0b00000-0000-0000-0000-000000000072','REPRODUCTIVE',1.0),
('f0b00000-0000-0000-0000-000000000072','RENAL_URINARY',0.3),

-- Poor feeding
('f0b00000-0000-0000-0000-000000000077','GASTROINTESTINAL',0.5),
('f0b00000-0000-0000-0000-000000000077','CONSTITUTIONAL',0.7),
('f0b00000-0000-0000-0000-000000000077','NEUROLOGICAL',0.4),

-- Collapse
('f0b00000-0000-0000-0000-000000000096','CARDIOVASCULAR',0.8),
('f0b00000-0000-0000-0000-000000000096','NEUROLOGICAL',0.8),
('f0b00000-0000-0000-0000-000000000096','CONSTITUTIONAL',0.4)

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 4. UNIVERSAL SPECIALTY ASSOCIATIONS
-- =============================================================================

INSERT INTO knowledge.symptom_specialty
(symptom_id, specialty_code, relevance)
VALUES

-- High-volume general complaints
('f0b00000-0000-0000-0000-000000000001','internal_medicine',1.0),
('f0b00000-0000-0000-0000-000000000001','family_medicine',1.0),
('f0b00000-0000-0000-0000-000000000001','paediatrics',0.9),
('f0b00000-0000-0000-0000-000000000001','emergency_medicine',0.8),

('f0b00000-0000-0000-0000-000000000002','family_medicine',1.0),
('f0b00000-0000-0000-0000-000000000002','internal_medicine',1.0),
('f0b00000-0000-0000-0000-000000000002','paediatrics',1.0),
('f0b00000-0000-0000-0000-000000000002','emergency_medicine',0.9),

('f0b00000-0000-0000-0000-000000000003','emergency_medicine',1.0),
('f0b00000-0000-0000-0000-000000000003','internal_medicine',1.0),
('f0b00000-0000-0000-0000-000000000003','family_medicine',0.9),
('f0b00000-0000-0000-0000-000000000003','paediatrics',0.9),

('f0b00000-0000-0000-0000-00000000000a','emergency_medicine',1.0),
('f0b00000-0000-0000-0000-00000000000a','internal_medicine',1.0),
('f0b00000-0000-0000-0000-00000000000a','cardiology',1.0),
('f0b00000-0000-0000-0000-00000000000a','pulmonology',0.8),

('f0b00000-0000-0000-0000-000000000014','neurology',1.0),
('f0b00000-0000-0000-0000-000000000014','emergency_medicine',0.9),
('f0b00000-0000-0000-0000-000000000014','family_medicine',1.0),
('f0b00000-0000-0000-0000-000000000014','internal_medicine',0.8),

('f0b00000-0000-0000-0000-000000000019','surgery',1.0),
('f0b00000-0000-0000-0000-000000000019','internal_medicine',0.9),
('f0b00000-0000-0000-0000-000000000019','family_medicine',1.0),
('f0b00000-0000-0000-0000-000000000019','emergency_medicine',1.0),
('f0b00000-0000-0000-0000-000000000019','paediatrics',0.9),
('f0b00000-0000-0000-0000-000000000019','obstetrics_gynaecology',0.8),

('f0b00000-0000-0000-0000-000000000021','gastroenterology',1.0),
('f0b00000-0000-0000-0000-000000000021','family_medicine',1.0),
('f0b00000-0000-0000-0000-000000000021','paediatrics',1.0),
('f0b00000-0000-0000-0000-000000000021','emergency_medicine',0.9),

('f0b00000-0000-0000-0000-000000000022','gastroenterology',1.0),
('f0b00000-0000-0000-0000-000000000022','family_medicine',1.0),
('f0b00000-0000-0000-0000-000000000022','paediatrics',1.0),
('f0b00000-0000-0000-0000-000000000022','infectious_diseases',0.8),

('f0b00000-0000-0000-0000-000000000031','emergency_medicine',1.0),
('f0b00000-0000-0000-0000-000000000031','cardiology',1.0),
('f0b00000-0000-0000-0000-000000000031','neurology',0.9),
('f0b00000-0000-0000-0000-000000000031','internal_medicine',0.9),

('f0b00000-0000-0000-0000-000000000033','neurology',1.0),
('f0b00000-0000-0000-0000-000000000033','paediatrics',0.9),
('f0b00000-0000-0000-0000-000000000033','emergency_medicine',1.0),

-- O&G
('f0b00000-0000-0000-0000-000000000066','obstetrics_gynaecology',1.0),
('f0b00000-0000-0000-0000-000000000066','emergency_medicine',0.9),
('f0b00000-0000-0000-0000-000000000066','family_medicine',0.8),

('f0b00000-0000-0000-0000-000000000069','obstetrics_gynaecology',1.0),
('f0b00000-0000-0000-0000-000000000069','family_medicine',0.8),

('f0b00000-0000-0000-0000-00000000006f','obstetrics_gynaecology',1.0),
('f0b00000-0000-0000-0000-00000000006f','emergency_medicine',0.9),

-- Paediatrics
('f0b00000-0000-0000-0000-000000000077','paediatrics',1.0),
('f0b00000-0000-0000-0000-000000000077','paediatrics',1.0),
('f0b00000-0000-0000-0000-000000000077','emergency_medicine',0.8),

-- Surgery
('f0b00000-0000-0000-0000-000000000090','surgery',1.0),
('f0b00000-0000-0000-0000-000000000090','orthopaedics',0.9),
('f0b00000-0000-0000-0000-000000000090','emergency_medicine',1.0),

('f0b00000-0000-0000-0000-000000000091','emergency_medicine',1.0),
('f0b00000-0000-0000-0000-000000000091','orthopaedics',0.9),
('f0b00000-0000-0000-0000-000000000091','surgery',0.8)

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 5. SYMPTOM RELATIONSHIPS
-- =============================================================================
-- These are associations between presentations, NOT diagnoses.
-- =============================================================================

INSERT INTO knowledge.symptom_relationship
(symptom_id, related_symptom_id, relationship_type, weight)
VALUES

-- Respiratory cluster
('f0b00000-0000-0000-0000-000000000001',
 'f0b00000-0000-0000-0000-000000000002',
 'associated_with',0.6),

('f0b00000-0000-0000-0000-000000000001',
 'f0b00000-0000-0000-0000-000000000003',
 'associated_with',0.7),

('f0b00000-0000-0000-0000-000000000003',
 'f0b00000-0000-0000-0000-00000000000a',
 'associated_with',0.5),

('f0b00000-0000-0000-0000-000000000003',
 'f0b00000-0000-0000-0000-000000000008',
 'associated_with',0.6),

-- Constitutional
('f0b00000-0000-0000-0000-000000000002',
 'f0b00000-0000-0000-0000-00000000000d',
 'associated_with',0.5),

('f0b00000-0000-0000-0000-000000000002',
 'f0b00000-0000-0000-0000-00000000000e',
 'associated_with',0.4),

('f0b00000-0000-0000-0000-000000000005',
 'f0b00000-0000-0000-0000-00000000000d',
  'associated_with',0.5),

-- GI
('f0b00000-0000-0000-0000-000000000020',
 'f0b00000-0000-0000-0000-000000000021',
 'associated_with',0.8),

('f0b00000-0000-0000-0000-000000000022',
 'f0b00000-0000-0000-0000-000000000019',
 'associated_with',0.3),

('f0b00000-0000-0000-0000-000000000021',
 'f0b00000-0000-0000-0000-000000000019',
 'associated_with',0.4),

-- Neuro
('f0b00000-0000-0000-0000-00000000002f',
 'f0b00000-0000-0000-0000-000000000031',
 'associated_with',0.5),

('f0b00000-0000-0000-0000-000000000030',
 'f0b00000-0000-0000-0000-00000000002f',
 'associated_with',0.8),

('f0b00000-0000-0000-0000-000000000033',
 'f0b00000-0000-0000-0000-000000000036',
 'may_cause',0.4),

-- Urinary
('f0b00000-0000-0000-0000-000000000043',
 'f0b00000-0000-0000-0000-000000000044',
 'associated_with',0.5),

('f0b00000-0000-0000-0000-000000000043',
 'f0b00000-0000-0000-0000-000000000045',
 'associated_with',0.5),

-- OBG
('f0b00000-0000-0000-0000-000000000066',
 'f0b00000-0000-0000-0000-00000000001a',
 'associated_with',0.5),

('f0b00000-0000-0000-0000-00000000006f',
 'f0b00000-0000-0000-0000-00000000006e',
 'associated_with',0.3),

-- Paediatric
('f0b00000-0000-0000-0000-000000000077',
 'f0b00000-0000-0000-0000-000000000079',
 'associated_with',0.6),

-- Emergency
('f0b00000-0000-0000-0000-000000000096',
 'f0b00000-0000-0000-0000-000000000031',
 'associated_with',0.7),

('f0b00000-0000-0000-0000-000000000096',
 'f0b00000-0000-0000-0000-000000000036',
 'associated_with',0.5),

('f0b00000-0000-0000-0000-000000000098',
 'f0b00000-0000-0000-0000-000000000003',
 'associated_with',0.4),

('f0b00000-0000-0000-0000-000000000098',
 'f0b00000-0000-0000-0000-000000000019',
 'associated_with',0.5)

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 6. UNIVERSAL RED FLAGS
-- =============================================================================
-- IMPORTANT:
-- A red flag is a trigger for escalation / assessment.
-- It does NOT establish a diagnosis.
-- =============================================================================

INSERT INTO knowledge.symptom_red_flag
(symptom_id, red_flag_code, description, urgency)
VALUES

-- Respiratory
('f0b00000-0000-0000-0000-000000000001',
 'RF-COUGH-HAEMOPTYSIS',
 'Cough accompanied by haemoptysis requires assessment of severity and source.',
 'urgent'),

('f0b00000-0000-0000-0000-000000000003',
 'RF-DYSPNOEA-HYPOXAEMIA',
 'Dyspnoea accompanied by clinically significant hypoxaemia requires urgent assessment and appropriate oxygenation support.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000003',
 'RF-DYSPNOEA-STRIDOR',
 'Dyspnoea with stridor may indicate upper-airway obstruction.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000004',
 'RF-HAEMOPTYSIS-MAJOR',
 'Large-volume, recurrent, or haemodynamically significant haemoptysis requires emergency assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000009',
 'RF-STRIDOR-AIRWAY',
 'Stridor may indicate critical upper-airway narrowing.',
 'emergency'),

-- Chest
('f0b00000-0000-0000-0000-00000000000a',
 'RF-CHEST-PAIN-ACS',
 'Chest pain with features suggestive of myocardial ischaemia requires urgent cardiovascular assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-00000000000a',
 'RF-CHEST-PAIN-PE',
 'Chest pain associated with acute dyspnoea or thromboembolic features requires urgent assessment for pulmonary embolic disease.',
 'emergency'),

('f0b00000-0000-0000-0000-00000000000a',
 'RF-CHEST-PAIN-AORTIC',
 'Sudden severe chest or back pain with concerning features requires emergency assessment for acute aortic pathology.',
 'emergency'),

-- Neurology
('f0b00000-0000-0000-0000-000000000014',
 'RF-HEADACHE-SUDDEN',
 'Sudden maximal-at-onset headache requires emergency assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000014',
 'RF-HEADACHE-MENINGISM',
 'Headache with fever, neck stiffness, or altered consciousness requires urgent assessment for serious intracranial infection.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000031',
 'RF-SYNCOPE-CARDIAC',
 'Syncope associated with exertion, chest pain, palpitations, abnormal cardiac findings, or significant injury requires urgent evaluation.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000033',
 'RF-SEIZURE-PROLONGED',
 'Prolonged or recurrent seizure without recovery requires emergency management.',
 'emergency'),

('f0b00000-0000-0000-0000-00000000003b',
 'RF-PARALYSIS-ACUTE',
 'Acute paralysis or sudden focal motor deficit requires emergency neurological assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-00000000003e',
 'RF-SPEECH-ACUTE',
 'Acute speech disturbance may represent a neurological emergency.',
 'emergency'),

-- GI
('f0b00000-0000-0000-0000-000000000019',
 'RF-ABDOMINAL-PAIN-PERITONISM',
 'Severe abdominal pain with guarding, rigidity, rebound, or other peritoneal features requires urgent surgical assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000021',
 'RF-VOMITING-BLOOD',
 'Haematemesis requires urgent gastrointestinal bleeding assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-00000000002d',
 'RF-JAUNDICE-ACUTE',
 'Acute jaundice with systemic deterioration, altered mental status, bleeding, or severe abdominal pain requires urgent assessment.',
 'emergency'),

-- Urinary
('f0b00000-0000-0000-0000-000000000047',
 'RF-HAEMATURIA-GROSS',
 'Visible haematuria requires clinical assessment to establish urinary tract source and cause.',
 'urgent'),

('f0b00000-0000-0000-0000-000000000048',
 'RF-URINARY-RETENTION',
 'Acute urinary retention requires prompt assessment and bladder decompression where indicated.',
 'urgent'),

('f0b00000-0000-0000-0000-00000000004b',
 'RF-OLIGURIA',
 'Markedly reduced urine output may indicate significant renal or systemic compromise.',
 'urgent'),

-- OBGYN
('f0b00000-0000-0000-0000-000000000066',
 'RF-PREGNANCY-BLEEDING',
 'Vaginal bleeding during pregnancy requires urgent obstetric assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-00000000006f',
 'RF-REDUCED-FETAL-MOVEMENT',
 'Reduced or absent fetal movement requires prompt fetal assessment.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000070',
 'RF-POSSIBLE-ROM',
 'Leakage of fluid during pregnancy may represent rupture of membranes and requires obstetric assessment.',
 'urgent'),

('f0b00000-0000-0000-0000-000000000072',
 'RF-TESTICULAR-PAIN',
 'Acute testicular pain requires urgent exclusion of testicular torsion.',
 'emergency'),

-- Paediatrics
('f0b00000-0000-0000-0000-000000000077',
 'RF-PAEDIATRIC-POOR-FEEDING',
 'Poor feeding in a young infant may indicate serious systemic illness and requires age-appropriate assessment.',
 'urgent'),

('f0b00000-0000-0000-0000-000000000079',
 'RF-PAEDIATRIC-LETHARGY',
 'Marked lethargy or reduced responsiveness in a child requires urgent assessment.',
 'emergency'),

-- Mental health
('f0b00000-0000-0000-0000-00000000008c',
 'RF-SUICIDAL-THOUGHTS',
 'Suicidal thoughts require immediate assessment of intent, plan, means, protective factors, and immediate safety.',
 'emergency'),

-- General
('f0b00000-0000-0000-0000-000000000096',
 'RF-COLLAPSE',
 'Collapse requires assessment for cardiovascular, neurological, metabolic, traumatic, and other immediately dangerous causes.',
 'emergency'),

('f0b00000-0000-0000-0000-000000000098',
 'RF-SEVERE-PAIN',
 'Severe or rapidly escalating pain requires assessment for potentially serious underlying pathology.',
 'urgent')

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 7. AGE / CONTEXT ASSOCIATIONS
-- =============================================================================

INSERT INTO knowledge.symptom_context
(symptom_id, context_type_code, context_value_id, relevance, description)
VALUES

-- Neonates
('f0b00000-0000-0000-0000-000000000002',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='0-28D'),
 1.0,
 'Fever in a neonate requires urgent assessment for serious bacterial and other infection.'),

('f0b00000-0000-0000-0000-000000000077',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='0-28D'),
 1.0,
 'Poor feeding is an important neonatal danger presentation.'),

('f0b00000-0000-0000-0000-000000000079',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='0-28D'),
 1.0,
 'Lethargy or reduced responsiveness in a neonate is a danger sign.'),

('f0b00000-0000-0000-0000-000000000001',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='0-28D'),
 0.7,
 'Cough in a neonate is clinically significant and requires age-specific assessment.'),

-- Infants / children
('f0b00000-0000-0000-0000-000000000079',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='1-11M'),
 1.0,
 'Marked lethargy in an infant is a danger presentation.'),

('f0b00000-0000-0000-0000-000000000077',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='1-11M'),
 1.0,
 'Poor feeding is clinically important in infants.'),

-- Elderly
('f0b00000-0000-0000-0000-000000000002',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='65P'),
 0.9,
 'Fever may be less pronounced in older adults despite significant infection.'),

('f0b00000-0000-0000-0000-00000000000e',
 'AGE',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='AGE' AND value='65P'),
 0.8,
 'New weakness in an older adult may represent systemic, neurological, cardiovascular, or metabolic disease.'),

-- Pregnancy
('f0b00000-0000-0000-0000-000000000066',
 'PREGNANCY',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='PREGNANCY' AND value='pregnant'),
 1.0,
 'Vaginal bleeding during pregnancy requires obstetric interpretation.'),

('f0b00000-0000-0000-0000-00000000006f',
 'PREGNANCY',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='PREGNANCY' AND value='pregnant'),
 1.0,
 'Reduced fetal movement is applicable specifically to pregnancy.'),

('f0b00000-0000-0000-0000-000000000070',
 'PREGNANCY',
 (SELECT id FROM knowledge.context_value
  WHERE context_type_code='PREGNANCY' AND value='pregnant'),
 1.0,
 'Leakage of fluid is clinically relevant during pregnancy.')

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 8. UNIVERSAL DOCUMENTATION PHRASES
-- =============================================================================
-- These are clinician-facing preferred phrases.
-- They should not replace patient-language synonyms.
-- =============================================================================

INSERT INTO knowledge.symptom_documentation
(symptom_id, documentation_phrase, language_code, is_preferred)
VALUES

('f0b00000-0000-0000-0000-000000000001','cough','en',true),
('f0b00000-0000-0000-0000-000000000002','fever','en',true),
('f0b00000-0000-0000-0000-000000000003','dyspnoea','en',true),
('f0b00000-0000-0000-0000-000000000004','haemoptysis','en',true),
('f0b00000-0000-0000-0000-000000000005','unintentional weight loss','en',true),
('f0b00000-0000-0000-0000-000000000006','night sweats','en',true),
('f0b00000-0000-0000-0000-000000000008','wheeze','en',true),
('f0b00000-0000-0000-0000-000000000009','stridor','en',true),
('f0b00000-0000-0000-0000-00000000000a','chest pain','en',true),
('f0b00000-0000-0000-0000-00000000000b','palpitations','en',true),
('f0b00000-0000-0000-0000-00000000000d','fatigue','en',true),
('f0b00000-0000-0000-0000-00000000000e','weakness','en',true),
('f0b00000-0000-0000-0000-000000000014','headache','en',true),
('f0b00000-0000-0000-0000-000000000019','abdominal pain','en',true),
('f0b00000-0000-0000-0000-000000000020','nausea','en',true),
('f0b00000-0000-0000-0000-000000000021','vomiting','en',true),
('f0b00000-0000-0000-0000-000000000022','diarrhoea','en',true),
('f0b00000-0000-0000-0000-000000000023','constipation','en',true),
('f0b00000-0000-0000-0000-000000000026','dysphagia','en',true),
('f0b00000-0000-0000-0000-00000000002d','jaundice','en',true),
('f0b00000-0000-0000-0000-00000000002f','dizziness','en',true),
('f0b00000-0000-0000-0000-000000000030','vertigo','en',true),
('f0b00000-0000-0000-0000-000000000031','syncope','en',true),
('f0b00000-0000-0000-0000-000000000033','seizure','en',true),
('f0b00000-0000-0000-0000-000000000035','confusion','en',true),
('f0b00000-0000-0000-0000-000000000039','numbness','en',true),
('f0b00000-0000-0000-0000-00000000003a','paraesthesia','en',true),
('f0b00000-0000-0000-0000-00000000003b','paralysis','en',true),
('f0b00000-0000-0000-0000-000000000043','dysuria','en',true),
('f0b00000-0000-0000-0000-000000000047','haematuria','en',true),
('f0b00000-0000-0000-0000-000000000048','urinary retention','en',true),
('f0b00000-0000-0000-0000-00000000004d','polydipsia','en',true),
('f0b00000-0000-0000-0000-00000000004e','polyphagia','en',true),
('f0b00000-0000-0000-0000-000000000053','rash','en',true),
('f0b00000-0000-0000-0000-000000000058','sore throat','en',true),
('f0b00000-0000-0000-0000-00000000005b','epistaxis','en',true),
('f0b00000-0000-0000-0000-000000000061','eye pain','en',true),
('f0b00000-0000-0000-0000-000000000062','red eye','en',true),
('f0b00000-0000-0000-0000-000000000066','vaginal bleeding','en',true),
('f0b00000-0000-0000-0000-000000000068','dysmenorrhoea','en',true),
('f0b00000-0000-0000-0000-000000000069','amenorrhoea','en',true),
('f0b00000-0000-0000-0000-00000000006a','vaginal discharge','en',true),
('f0b00000-0000-0000-0000-00000000006f','reduced fetal movement','en',true),
('f0b00000-0000-0000-0000-000000000072','testicular pain','en',true),
('f0b00000-0000-0000-0000-000000000077','poor feeding','en',true),
('f0b00000-0000-0000-0000-000000000079','lethargy','en',true),
('f0b00000-0000-0000-0000-00000000007f','breast lump','en',true),
('f0b00000-0000-0000-0000-000000000084','mass','en',true),
('f0b00000-0000-0000-0000-000000000087','insomnia','en',true),
('f0b00000-0000-0000-0000-00000000008a','anxiety','en',true),
('f0b00000-0000-0000-0000-00000000008c','suicidal thoughts','en',true),
('f0b00000-0000-0000-0000-000000000090','injury','en',true),
('f0b00000-0000-0000-0000-000000000091','fall','en',true),
('f0b00000-0000-0000-0000-000000000092','burn injury','en',true),
('f0b00000-0000-0000-0000-000000000096','collapse','en',true),
('f0b00000-0000-0000-0000-000000000098','severe pain','en',true)

  ON CONFLICT DO NOTHING;



-- =============================================================================
-- 9. SWAHILI CORE TRANSLATIONS
-- =============================================================================
-- Keep canonical English terminology untouched.
-- Translation is an additional presentation layer.
-- =============================================================================

INSERT INTO knowledge.symptom_translation
(symptom_id, language_code, translation, is_preferred)
VALUES

('f0b00000-0000-0000-0000-000000000001','sw','Kikohozi',true),
('f0b00000-0000-0000-0000-000000000002','sw','Homa',true),
('f0b00000-0000-0000-0000-000000000003','sw','Upungufu wa pumzi',true),
('f0b00000-0000-0000-0000-000000000004','sw','Kukohoa damu',true),
('f0b00000-0000-0000-0000-000000000005','sw','Kupoteza uzito bila kukusudia',true),
('f0b00000-0000-0000-0000-000000000006','sw','Jasho la usiku',true),
('f0b00000-0000-0000-0000-00000000000a','sw','Maumivu ya kifua',true),
('f0b00000-0000-0000-0000-000000000014','sw','Maumivu ya kichwa',true),
('f0b00000-0000-0000-0000-000000000019','sw','Maumivu ya tumbo',true),
('f0b00000-0000-0000-0000-000000000020','sw','Kichefuchefu',true),
('f0b00000-0000-0000-0000-000000000021','sw','Kutapika',true),
('f0b00000-0000-0000-0000-000000000022','sw','Kuhara',true),
('f0b00000-0000-0000-0000-000000000023','sw','Kufunga choo',true),
('f0b00000-0000-0000-0000-00000000002d','sw','Manjano',true),
('f0b00000-0000-0000-0000-00000000002f','sw','Kizunguzungu',true),
('f0b00000-0000-0000-0000-000000000031','sw','Kuzimia',true),
('f0b00000-0000-0000-0000-000000000033','sw','Degedege',true),
('f0b00000-0000-0000-0000-000000000043','sw','Maumivu wakati wa kukojoa',true),
('f0b00000-0000-0000-0000-000000000047','sw','Damu kwenye mkojo',true),
('f0b00000-0000-0000-0000-000000000053','sw','Upele',true),
('f0b00000-0000-0000-0000-000000000058','sw','Maumivu ya koo',true),
('f0b00000-0000-0000-0000-00000000005b','sw','Kutokwa damu puani',true),
('f0b00000-0000-0000-0000-000000000066','sw','Kutokwa damu ukeni',true),
('f0b00000-0000-0000-0000-00000000006a','sw','Uchafu/majimaji yasiyo ya kawaida ukeni',true),
('f0b00000-0000-0000-0000-00000000006f','sw','Mtoto kupunguza kucheza tumboni',true),
('f0b00000-0000-0000-0000-000000000072','sw','Maumivu ya korodani',true),
('f0b00000-0000-0000-0000-000000000077','sw','Kutokula/kula vibaya',true),
('f0b00000-0000-0000-0000-000000000079','sw','Ulegevu',true),
('f0b00000-0000-0000-0000-00000000007f','sw','Kivimbe kwenye titi',true),
('f0b00000-0000-0000-0000-000000000091','sw','Kuanguka',true),
('f0b00000-0000-0000-0000-000000000096','sw','Kuanguka/kuporomoka ghafla',true)

  ON CONFLICT DO NOTHING;