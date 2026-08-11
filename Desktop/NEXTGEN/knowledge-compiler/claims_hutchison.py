"""Curated atomic claims for the first compiler pass (Hutchison 24e).

Each claim is grounded in the source by (chapter_number, page). The claim_text
is the atomic statement; the contract is the extraction contract that the
compiler will expand into operational knowledge.

PAGE CONVENTION: page values are PRINTED book pages (pdf_index - 11, see
compiler_core.PAGE_OFFSET). E.g. ch1 p14(pdf) -> p3(printed); ch12 p178(pdf) -> p167(printed).

claim_type values (AMEXAN layer classification, per the locked H1 spec):
  CLINICAL_METHOD / QUESTIONING_PRINCIPLE / EXAMINATION_PRINCIPLE /
  REASONING_PRINCIPLE / RESPIRATORY_METHOD / ...

This file is the knowledge-authoring layer: a clinician/compiler reads the
source chunks and authors atomic claims. Later compiler stages (H2+) consume
these claims.
"""
from __future__ import annotations

# claim_kind values: definition|rule|question|red_flag|differential|examination|
#                    investigation|threshold|contraindication|principle|risk_factor|history_section|management|prognosis
# knowledge_type: clinical_method|medicine|guideline_activity|reference

CLAIMS: list[dict] = [
    # ============================================================================
    # CHAPTER 1 — Doctor and patient: General principles of history taking
    # ============================================================================
    {
        "code": "HCH1-0001", "chapter": "1", "page": 3, "kind": "definition", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "Clinical Methods is the set of skills doctors use to diagnose and treat disease, and the manner in which doctors approach clinical problems and relate to patients.",
        "contract": {
            "what_is_it": "Clinical methods (definition)",
            "why": "Frames the entire clinical-assessment skill set.",
            "source_support": "Hutchison 24e ch1 p3",
        },
    },
    {
        "code": "HCH1-0002", "chapter": "1", "page": 3, "kind": "principle", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "There are two main steps to making a diagnosis: (1) establish the clinical features by history and examination (the clinical database); (2) interpret that database in terms of disordered function and potential causative pathologies (physical, mental, social, or a combination).",
        "contract": {
            "what_is_it": "Two-step diagnostic process",
            "what_connects_to": "differential reasoning interface",
            "source_support": "Hutchison 24e ch1 p3",
        },
    },
    {
        "code": "HCH1-0003", "chapter": "1", "page": 3, "kind": "question", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "Symptoms are what the patient reports or complains of (e.g. cough, headache); signs are findings on observation or physical examination.",
        "contract": {
            "what_is_it": "symptom vs sign definition",
            "what_fact_produces": "symptom presence facts vs examination facts",
            "source_support": "Hutchison 24e ch1 p3",
        },
    },
    {
        "code": "HCH1-0004", "chapter": "1", "page": 4, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Begin the history with a single open-ended question such as 'Tell me about what has led up to you coming here today', leaving as open as possible any question about the cause of the patient's problems.",
        "contract": {
            "what_is_it": "opening question (open-ended)",
            "question_mode": "OPEN",
            "what_activates_it": "start of any history",
            "where_documented": "history of presenting complaint opening",
            "source_support": "Hutchison 24e ch1 p4",
        },
    },
    {
        "code": "HCH1-0005", "chapter": "1", "page": 4, "kind": "history_section", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "There is particular logic in taking the past medical history before the presenting complaint, because for many conditions the distinction between current problem and past history is unclear and arbitrary in the patient's mind; taking the history along a timeline builds a better picture.",
        "contract": {
            "what_is_it": "schematic history order — past medical history first",
            "when_applies": "non-emergency new-patient history",
            "where_documented": "past medical history section",
            "source_support": "Hutchison 24e ch1 p4",
        },
    },
    {
        "code": "HCH1-0006", "chapter": "1", "page": 4, "kind": "rule", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Box 1.1 beginning-history question areas: confirm date of birth and age; occupation and occupational history; past medical history; smoking; alcohol consumption; drug and treatment history; family history.",
        "contract": {
            "what_is_it": "beginning history checklist",
            "what_fact_produces": "demographics, occupation, smoking, alcohol, drugs, family history facts",
            "where_documented": "background/social history",
            "source_support": "Hutchison 24e ch1 p4 Box 1.1",
        },
    },
    {
        "code": "HCH1-0007", "chapter": "1", "page": 5, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Vocabulary must be clarified: ordinary English words (diarrhoea, constipation, wind, indigestion, being sick, dizziness, headache, double vision, pins and needles, rash, blister) and medical terms patients use imprecisely (arthritis, sciatica, migraine, fits, stroke, palpitation, angina, heart attack, nausea, piles/haemorrhoids, anaemia, pleurisy, eczema, urticaria, warts, cystitis) require clarification of meaning.",
        "contract": {
            "what_is_it": "vocabulary clarification list",
            "question_mode": "CLARIFYING",
            "what_fact_produces": "clarified symptom interpretation",
            "source_support": "Hutchison 24e ch1 p5 Box 1.3",
        },
    },
    {
        "code": "HCH1-0008", "chapter": "1", "page": 6, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Indirect/open-ended questions invite the patient to talk about a general area ('Tell me more about...', 'What do you think about...', 'How does that make you feel...', 'What happened next...', 'Is there anything else you would like to tell me?'); direct/closed questions elicit yes/no answers.",
        "contract": {
            "what_is_it": "indirect vs direct question types",
            "question_mode": "OPEN vs DIRECT",
            "source_support": "Hutchison 24e ch1 p6",
        },
    },
    {
        "code": "HCH1-0009", "chapter": "1", "page": 6, "kind": "principle", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "A patient-centred interview contains enough open-ended questions for patients to talk about all their problems and enough time to do so; an interview using many direct questions tends to be disease-centred.",
        "contract": {
            "what_is_it": "patient-centred vs disease-centred interview",
            "source_support": "Hutchison 24e ch1 p6",
        },
    },
    {
        "code": "HCH1-0010", "chapter": "1", "page": 6, "kind": "rule", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Box 1.4 pitfall: leading closed questions ('Is it in the middle of your chest? Does it travel to your left arm? Does it come on when you walk? Is it relieved by rest?') railroad the diagnosis; open questions plus clarifying questions preserve an open mind.",
        "contract": {
            "what_is_it": "leading-question anti-pattern",
            "question_mode": "OPEN then CLARIFYING preferred over leading DIRECT",
            "source_support": "Hutchison 24e ch1 p6 Box 1.4",
        },
    },
    {
        "code": "HCH1-0011", "chapter": "1", "page": 7, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Judging severity: ask 'How much does this bother you?' and probe daily-life impact (Box 1.5): exercise tolerance (how far can you walk on the flat at your own speed; climb one flight of stairs slowly; do simple housework), work (kept off work; why), sport (affected?), eating (affected; particular foods), social life (restricted; sex life affected).",
        "contract": {
            "what_is_it": "severity/functional-impact probing",
            "question_mode": "FUNCTIONAL",
            "what_fact_produces": "functional impact facts (mobility, work, sport, eating, social)",
            "where_documented": "functional impact",
            "source_support": "Hutchison 24e ch1 p7 Box 1.5",
        },
    },
    {
        "code": "HCH1-0012", "chapter": "1", "page": 7, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Pain severity is rated on a scale 1-10, where 1 is barely noticeable and 10 is the worst pain the patient can imagine or has ever experienced; clarify the reference point for '10'.",
        "contract": {
            "what_is_it": "pain numeric rating scale",
            "what_fact_produces": "PAIN_SEVERITY_SCORE",
            "when_applies": "any pain complaint",
            "source_support": "Hutchison 24e ch1 p7",
        },
    },
    {
        "code": "HCH1-0013", "chapter": "1", "page": 7, "kind": "history_section", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Suggested scheme for basic history taking (Box 1.6): name/age/occupation/country of birth; main presenting problem; past medical history (all serious problems in the whole of life); specific past medical history (diabetes, jaundice, TB, heart disease, high blood pressure, rheumatic fever, epilepsy); history of main presenting complaint; family history; occupational history; smoking, alcohol, allergies; drug and other treatment history; direct questions about bodily systems not covered by the presenting complaint.",
        "contract": {
            "what_is_it": "schematic history (canonical order)",
            "where_documented": "entire history structure",
            "source_support": "Hutchison 24e ch1 p7 Box 1.6",
        },
    },
    {
        "code": "HCH1-0014", "chapter": "1", "page": 8, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Direct questions about bodily systems (Box 1.7): cardiorespiratory (chest pain, intermittent claudication, palpitation, ankle swelling, orthopnoea, nocturnal dyspnoea, shortness of breath, cough with/without sputum, haemoptysis); gastrointestinal (abdominal pain, dyspepsia, dysphagia, nausea and/or vomiting, appetite, weight loss/gain, bowel pattern and change, rectal bleeding, jaundice); genitourinary (haematuria, nocturia, frequency, dysuria, menstrual irregularity in women, urethral discharge in men); locomotor (joint pain, change in mobility); neurological (seizures, collapses, dizziness, eyesight, hearing, transient loss of function, paraesthesia).",
        "contract": {
            "what_is_it": "systems review question set",
            "question_mode": "DIRECT",
            "when_applies": "systems not covered by presenting complaint",
            "what_fact_produces": "review-of-systems presence facts",
            "where_documented": "review of systems",
            "source_support": "Hutchison 24e ch1 p8 Box 1.7",
        },
    },
    {
        "code": "HCH1-0015", "chapter": "1", "page": 8, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Pain clarification (Box 1.8): site, radiation, character, severity, time course, aggravating factors, relieving factors, associated symptoms.",
        "contract": {
            "what_is_it": "universal pain exploration dimensions",
            "question_mode": "CLARIFYING",
            "what_fact_produces": "pain site/radiation/character/severity/timing/aggravators/relievers/associations",
            "source_support": "Hutchison 24e ch1 p8 Box 1.8",
        },
    },
    {
        "code": "HCH1-0016", "chapter": "1", "page": 9, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Drug-history clarifying questions (Box 1.9): all drugs/medicines taken; prescribed from another clinic/doctor/dentist; bought from a pharmacy; all tablets/capsules/liquids; inhalers, skin creams, patches, suppositories, lozenges; medicines stopped recently; medicines prescribed for other people; herbal or complementary medicines.",
        "contract": {
            "what_is_it": "comprehensive drug history probe set",
            "question_mode": "DIRECT + CLARIFYING",
            "what_fact_produces": "complete medication list incl. OTC, complementary, recently stopped",
            "where_documented": "drug history",
            "source_support": "Hutchison 24e ch1 p9 Box 1.9",
        },
    },
    {
        "code": "HCH1-0017", "chapter": "1", "page": 9, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Family-history detail (Box 1.10): illnesses that run in the family; a basic family tree of first-degree relatives (with major illnesses, cause and age of deaths); specific questions about problems similar to the patient's and items in the developing differential diagnosis (e.g. gallstones, epilepsy, high blood pressure).",
        "contract": {
            "what_is_it": "family history structure",
            "what_fact_produces": "family history facts, genetic risk",
            "where_documented": "family history",
            "source_support": "Hutchison 24e ch1 p9 Box 1.10",
        },
    },
    {
        "code": "HCH1-0018", "chapter": "1", "page": 9, "kind": "history_section", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Occupational history is taken chronologically from leaving school forwards; a careful chronological occupational history may be required to elucidate exposures that act years later (e.g. asbestosis, silicosis).",
        "contract": {
            "what_is_it": "occupational history method",
            "question_mode": "CONTEXT",
            "what_fact_produces": "occupational exposure history",
            "source_support": "Hutchison 24e ch1 p9, ch12 p170",
        },
    },
    {
        "code": "HCH1-0019", "chapter": "1", "page": 9, "kind": "history_section", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Alcohol history: probe in different ways rather than taking the patient's word; convert reported amounts to units of alcohol per week (units = volume ml x %abv / 1000); UK recommendation is less than 14 units/week; assess dependency with CAGE (Cut down, Angry, Guilty, Eye-opener — two or more positives may indicate dependency).",
        "contract": {
            "what_is_it": "alcohol history + CAGE screen",
            "question_mode": "PROBING",
            "what_fact_produces": "alcohol units/week, CAGE score, dependency risk",
            "source_support": "Hutchison 24e ch1 p9 Boxes 1.11-1.13",
        },
    },
    {
        "code": "HCH1-0020", "chapter": "1", "page": 12, "kind": "definition", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "Hard vs soft symptoms (Box 1.15): a hard symptom, if clearly present, adds a lot of weight to a particular diagnosis (e.g. pneumaturia→colovesical fistula; fortification spectra with unilateral headache→classical migraine; rigors→bacteraemia/viraemia/malaria; bitten tongue with a seizure→grand mal; sudden severe headache 'like a hammer blow'→subarachnoid haemorrhage; pleuritic chest pain→pleural irritation; itching with jaundice→cholestasis). Soft symptoms are reported variably or present in many conditions and do not confirm or refute a diagnosis (e.g. dizziness, light-headedness, tiredness, back pain, headache, wind).",
        "contract": {
            "what_is_it": "evidence class of symptoms",
            "what_fact_produces": "qualitative evidence weight for differential scoring",
            "source_support": "Hutchison 24e ch1 p12 Box 1.15",
        },
    },
    {
        "code": "HCH1-0021", "chapter": "1", "page": 12, "kind": "principle", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "Time course: the character of a symptom suggests the 'anatomy' of the problem and the time course the 'pathology'. A vascular event (myocardial infarction, stroke, subarachnoid haemorrhage) usually has sudden onset; gradually progressing or undatable-onset symptoms (weight loss, dysphagia) may be malignant.",
        "contract": {
            "what_is_it": "time-course analysis principle",
            "what_fact_produces": "onset/duration/trajectory facts",
            "source_support": "Hutchison 24e ch1 p12-13",
        },
    },
    {
        "code": "HCH1-0022", "chapter": "1", "page": 13, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Negative data: ask specific yes/no questions for which a negative answer is as important as a positive one (e.g. for exertional chest pain, whether pain is worse on increased exertion and how long a rest relieves it).",
        "contract": {
            "what_is_it": "negative-data probing",
            "question_mode": "NEGATIVE/EXCLUSION",
            "what_fact_produces": "explicitly-recorded negative findings",
            "source_support": "Hutchison 24e ch1 p13",
        },
    },
    {
        "code": "HCH1-0023", "chapter": "1", "page": 13, "kind": "question", "claim_type": "QUESTIONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "What the patient actually wants (Box 1.16) should be explored: cannot tolerate ongoing symptoms; someone else noticed a problem; another doctor noticed a problem; worry about an underlying diagnosis; spouse/relative worried; cannot work with symptoms; colleagues/bosses complaining; requirement of others (insurance, employment benefit, litigation).",
        "contract": {
            "what_is_it": "reason-for-consultation exploration",
            "question_mode": "CONTEXT",
            "what_fact_produces": "reason_for_consultation fact",
            "source_support": "Hutchison 24e ch1 p13 Box 1.16",
        },
    },
    # ============================================================================
    # CHAPTER 2 — General patient examination and differential diagnosis
    # ============================================================================
    {
        "code": "HCH2-0001", "chapter": "2", "page": 15, "kind": "principle", "claim_type": "EXAMINATION_PRINCIPLE",
        "type": "clinical_method",
        "text": "The separation of history from examination is artificial; the examination starts with the first greeting and ends when the patient departs, and physical findings may prompt further questioning (history and exam are iterative, not linear).",
        "contract": {
            "what_is_it": "history-exam iteration principle",
            "source_support": "Hutchison 24e ch2 p15",
        },
    },
    {
        "code": "HCH2-0002", "chapter": "2", "page": 15, "kind": "examination", "claim_type": "EXAMINATION_PRINCIPLE",
        "type": "clinical_method",
        "text": "Global assessment first: ask 'Does this person look well, mildly ill or severely ill?'; if severely ill, postpone detailed examination until the acute situation is attended to.",
        "contract": {
            "what_is_it": "severity triage during examination",
            "when_applies": "start of every examination",
            "source_support": "Hutchison 24e ch2 p15",
        },
    },
    {
        "code": "HCH2-0003", "chapter": "2", "page": 16, "kind": "examination", "claim_type": "EXAMINATION_PRINCIPLE",
        "type": "clinical_method",
        "text": "General examination components: posture and gait; speech and interaction; physique and nutrition (BMI; cachexia; central vs generalised obesity; muscle wasting); temperature (mouth 35.8-37C, ear/rectum 0.5C higher, axilla 0.5C lower; diurnal variation; persistent/remittent/intermittent fever patterns); hands (handshake, wasting, tremor, clubbing with Lovibond's angle and Schamroth's window, Dupuytren's contracture); odours (alcohol, acetone in DKA, hepatic/uraemic foetor, halitosis); face and neck (facial nerve palsy, parotid swelling, malar flush of mitral stenosis, butterfly rash of SLE, telangiectasia, scleroderma furrowing, JVP); lymph glands; axillae; skin (temperature, hydration, turgor, pallor, jaundice, cyanosis peripheral vs central); pulses (radial, femoral, popliteal, dorsalis pedis, posterior tibial); blood pressure (+postural drop >20/10 within 3 min supine→upright); legs and feet (colour, texture, hair, oedema, varicose veins, DVT); breasts; then a structured 'putting it all together' sequence.",
        "contract": {
            "what_is_it": "universal general-examination object set",
            "what_fact_produces": "examination facts (BMI, temperature, clubbing, oedema, cyanosis, pulse character, BP, JVP...)",
            "where_documented": "examination section of clinical documentation",
            "source_support": "Hutchison 24e ch2 p16-26",
        },
    },
    {
        "code": "HCH2-0004", "chapter": "2", "page": 27, "kind": "examination", "claim_type": "EXAMINATION_PRINCIPLE",
        "type": "clinical_method",
        "text": "Suggested complete-examination order (Box 2.5): general; mouth and pharynx; hands; cardiovascular and respiratory (anterior, semi-recumbent); cardiovascular and respiratory (posterior, sitting forward); neck (sitting forward); abdomen; upper limbs; lower limbs; cranial nerves.",
        "contract": {
            "what_is_it": "complete examination sequence",
            "where_documented": "examination documentation order",
            "source_support": "Hutchison 24e ch2 p27",
        },
    },
    {
        "code": "HCH2-0005", "chapter": "2", "page": 28, "kind": "management", "claim_type": "REASONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Differential diagnosis framework (Box 2.3) — pathological processes to consider: Congenital, Degenerative, Infective/inflammatory, Metabolic, Neoplastic, Nutritional, Toxic, Traumatic, Vascular.",
        "contract": {
            "what_is_it": "differential diagnosis sieve",
            "what_activates_it": "any differential reasoning",
            "source_support": "Hutchison 24e ch2 p28 Box 2.3",
        },
    },
    {
        "code": "HCH2-0006", "chapter": "2", "page": 28, "kind": "management", "claim_type": "REASONING_PRINCIPLE",
        "type": "clinical_method",
        "text": "Order of tasks for a provisional management plan (Box 2.4): (1) list monitoring/nursing recommendations imperative to immediate comfort and safety; (2) list investigations to do immediately; (3) document medications to prescribe with doses and frequency (including IV fluids); (4) list investigations that may be needed later for further diagnostic information.",
        "contract": {
            "what_is_it": "management plan construction order",
            "source_support": "Hutchison 24e ch2 p28 Box 2.4",
        },
    },
    # ============================================================================
    # CHAPTER 12 — Respiratory system
    # ============================================================================
    {
        "code": "HCH12-0001", "chapter": "12", "page": 167, "kind": "definition", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Most patients with respiratory disease present with breathlessness, cough, excess sputum, haemoptysis, wheeze or chest pain.",
        "contract": {
            "what_is_it": "respiratory cardinal symptoms",
            "what_connects_to": "symptom registry for respiratory system",
            "source_support": "Hutchison 24e ch12 p167",
        },
    },
    {
        "code": "HCH12-0002", "chapter": "12", "page": 167, "kind": "definition", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Dyspnoea is breathlessness inappropriate to the level of physical exertion, or occurring at rest; it may be due to cardiac disease, anaemia, thyrotoxicosis or metabolic acidosis as well as primary respiratory problems.",
        "contract": {
            "what_is_it": "dyspnoea definition",
            "what_connects_to": "cardiac, haematological, endocrine, metabolic systems",
            "source_support": "Hutchison 24e ch12 p167 Box 12.1",
        },
    },
    {
        "code": "HCH12-0003", "chapter": "12", "page": 167, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Dyspnoea clarification: is it related only to exertion and how far can the patient walk at a normal pace on the level (exercise tolerance); is there variability, good days and bad days; are there times of day or night that are worse (asthma worse at night/early morning vs COPD mainly exertional).",
        "contract": {
            "what_is_it": "dyspnoea exploration dimensions",
            "question_mode": "CLARIFYING + FUNCTIONAL",
            "what_fact_produces": "MRC dyspnoea grade, exercise tolerance, diurnal variation",
            "source_support": "Hutchison 24e ch12 p167",
        },
    },
    {
        "code": "HCH12-0004", "chapter": "12", "page": 167, "kind": "threshold", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Cough is defined as acute if it lasts less than 3 weeks and chronic if it lasts more than 8 weeks; any cough associated with haemoptysis requires prompt assessment and at least a baseline chest X-ray; any chronic cough (>8 weeks) should have CXR and spirometry as baseline investigations.",
        "contract": {
            "what_is_it": "cough duration thresholds + baseline investigation triggers",
            "what_fact_produces": "COUGH_DURATION, chronic-cough flags",
            "what_activates_it": "CXR + spirometry for chronic cough",
            "source_support": "Hutchison 24e ch12 p167 Box 12.3-12.4",
        },
    },
    {
        "code": "HCH12-0005", "chapter": "12", "page": 167, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Cough discussion should include: how long has the cough been present; is the cough worse at any time of day or night (dry cough at night/spasms may be asthma); is the cough aggravated by anything (allergic triggers: dust, animals, pollen; non-specific triggers: exercise, cold air); severe coughing may be followed by vomiting.",
        "contract": {
            "what_is_it": "cough exploration dimensions",
            "question_mode": "CLARIFYING + PROBING",
            "what_fact_produces": "cough duration, timing, triggers, post-tussive vomiting",
            "source_support": "Hutchison 24e ch12 p167",
        },
    },
    {
        "code": "HCH12-0006", "chapter": "12", "page": 168, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Sputum clarification: is sputum produced; what does it look like (colour, consistency — yellow/green usually purulent; thick/jelly-like with casts in asthma; eosinophilic purulent appearance without infection); how much is produced (a cupful daily suggests bronchiectasis; smaller amounts in chronic bronchitis).",
        "contract": {
            "what_is_it": "sputum exploration dimensions",
            "question_mode": "CLARIFYING",
            "what_fact_produces": "sputum volume, colour, purulence, consistency",
            "source_support": "Hutchison 24e ch12 p168",
        },
    },
    {
        "code": "HCH12-0007", "chapter": "12", "page": 168, "kind": "red_flag", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Haemoptysis (coughing up blood) should never be dismissed without very careful evaluation; a specific question is always necessary (fear often leads patients not to mention it); decide if fresh or altered blood, how much, when it started and how often; ask about epistaxis and subsequent melaena.",
        "contract": {
            "what_is_it": "haemoptysis red flag",
            "urgency": "urgent",
            "what_activates_it": "investigation (CXR at least)",
            "source_support": "Hutchison 24e ch12 p168-169 Box 12.6",
        },
    },
    {
        "code": "HCH12-0008", "chapter": "12", "page": 169, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Wheezing: always ask whether the patient hears any noises coming from the chest; wheezing may be noticed by others (partner at night) and not by the patient; distinguish wheeze from stridor (stridor indicates narrowing of the larynx, trachea or main bronchi).",
        "contract": {
            "what_is_it": "wheeze exploration",
            "question_mode": "DIRECT",
            "what_fact_produces": "wheeze presence, audibility, stridor vs wheeze distinction",
            "source_support": "Hutchison 24e ch12 p169",
        },
    },
    {
        "code": "HCH12-0009", "chapter": "12", "page": 169, "kind": "differential", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Chest pain in respiratory disease: pleuritic pain is sharp and stabbing, worsened by deep breathing or coughing, and occurs when the pleura is inflamed (most commonly infection); constant pain unrelated to breathing may indicate local invasion of the chest wall by tumour; spontaneous pneumothorax pain is worse on breathing but more aching; pulmonary embolus can cause pleuritic pain, non-stabbing pain, or cardiac-type pain with haemodynamic disturbance.",
        "contract": {
            "what_is_it": "respiratory chest pain differential",
            "what_fact_produces": "pleuritic character, relation to breathing, pain constancy",
            "source_support": "Hutchison 24e ch12 p169",
        },
    },
    {
        "code": "HCH12-0010", "chapter": "12", "page": 169, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Respiratory history upper-airway/ENT: rhinosinusitis often coexists with asthma or bronchiectasis and can aggravate; postnasal drip from rhinitis is a common cause of chronic cough; change in voice may indicate left recurrent laryngeal nerve involvement by lung carcinoma; hoarseness persisting >4 weeks warrants laryngoscopy.",
        "contract": {
            "what_is_it": "ENT/upper-airway dimensions of respiratory history",
            "what_fact_produces": "rhinosinusitis, postnasal drip, hoarseness duration",
            "source_support": "Hutchison 24e ch12 p169",
        },
    },
    {
        "code": "HCH12-0011", "chapter": "12", "page": 169, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Full smoking and recreational drug history is required: 'Do you smoke?' is not enough; record age of starting and stopping for ex-smokers, average consumption for current and ex-smokers (pack-years); recreational drugs (heroin, crack, cannabis) are smoked and can damage the lungs; take the history sympathetically and non-judgementally.",
        "contract": {
            "what_is_it": "smoking + recreational drug history",
            "question_mode": "PROBING",
            "what_fact_produces": "smoking status, pack-years, recreational drug exposure",
            "source_support": "Hutchison 24e ch12 p169",
        },
    },
    {
        "code": "HCH12-0012", "chapter": "12", "page": 170, "kind": "risk_factor", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Family history: strong inherited susceptibility to asthma; associated atopic conditions (eczema, hay fever) may be present in relatives of those with asthma, particularly when onset is young.",
        "contract": {
            "what_is_it": "asthma/atopy family history",
            "what_fact_produces": "family history of asthma/atopy",
            "source_support": "Hutchison 24e ch12 p170",
        },
    },
    {
        "code": "HCH12-0013", "chapter": "12", "page": 170, "kind": "risk_factor", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Occupational history: no other organ is as susceptible to the working environment as the lungs; several hundred substances cause occupational asthma (car paint sprayers/isocyanates, woodworkers, bakers/flour dust, animals, hairdressing, healthcare/latex); always ask about the relationship between symptoms and work; asbestos exposure (mining, shipbuilding, construction, lagging, car mechanics, family exposure) may take decades to manifest as malignant mesothelioma.",
        "contract": {
            "what_is_it": "occupational respiratory risk factors",
            "question_mode": "PROBING + CONTEXT",
            "what_fact_produces": "occupational exposure facts (dusts, isocyanates, asbestos)",
            "source_support": "Hutchison 24e ch12 p170 Boxes 12.7-12.8",
        },
    },
    {
        "code": "HCH12-0014", "chapter": "12", "page": 170, "kind": "examination", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Respiratory general assessment (Box 12.9): physique and gait; voice; breathlessness (accessory muscles, pursed lips in COPD); clubbing of the fingers; tobacco staining; bruising/thin skin; venous pulses; cyanosis or pallor; ptosis; swollen face; collateral vessels across anterior chest wall; intercostal recession; use of accessory respiratory muscles; lymph nodes.",
        "contract": {
            "what_is_it": "respiratory general assessment object set",
            "what_fact_produces": "respiratory general examination facts",
            "source_support": "Hutchison 24e ch12 p170 Box 12.9",
        },
    },
    {
        "code": "HCH12-0015", "chapter": "12", "page": 171, "kind": "examination", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Hands in respiratory examination (Box 12.10): clubbing (respiratory causes: carcinoma of the bronchus, pulmonary fibrosis, bronchiectasis, lung abscess, empyema), pallor, cyanosis, warm well-perfused palms (CO2 retention), flap (hypercapnia), tremor (inhaled beta2-agonists), tobacco staining, bruising/thin skin, pulse rate and character (raised in significant asthma attack; pulsus paradoxus degree measures asthma severity).",
        "contract": {
            "what_is_it": "respiratory hand examination",
            "what_fact_produces": "clubbing, CO2 retention flap, tremor, pulse facts",
            "source_support": "Hutchison 24e ch12 p171 Box 12.10",
        },
    },
    {
        "code": "HCH12-0016", "chapter": "12", "page": 171, "kind": "examination", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Respiratory rate and rhythm: normal adult rate ~14-16 breaths/min; tachypnoea is increased rate observed by the doctor, dyspnoea is the symptom experienced by the patient; apnoea is cessation of respiration; Cheyne-Stokes breathing (cyclical deepening/quickening then diminishing with apnoeic pauses) occurs in severe cardiac failure, narcotic poisoning and neurological disorders; obstructive sleep apnoea is commoner in obese patients.",
        "contract": {
            "what_is_it": "respiratory rate/rhythm examination",
            "what_fact_produces": "respiratory rate, breathing pattern facts",
            "source_support": "Hutchison 24e ch12 p171-172 Box 12.11",
        },
    },
    {
        "code": "HCH12-0017", "chapter": "12", "page": 172, "kind": "examination", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Chest examination sequence: look (inspection — scars, shape, symmetry, movement, intercostal recession, barrel chest/overinflation), then feel (palpation — lymph nodes, swellings, tenderness, tracheal position, chest expansion, tactile vocal fremitus), then percuss (resonance/dullness, comparing sides), then listen (auscultation — breath sounds, added sounds, vocal resonance/fremitus).",
        "contract": {
            "what_is_it": "chest examination sequence (inspect-feel-percuss-listen)",
            "source_support": "Hutchison 24e ch12 p172-178",
        },
    },
    {
        "code": "HCH12-0018", "chapter": "12", "page": 176, "kind": "examination", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Auscultation interpretation (Box 12.16): vesicular breath sounds are normal; bronchial breath sounds indicate consolidation; whispering pectoriloquy indicates consolidation; aegophony indicates top of pleural effusion or consolidation; pleural rub is associated with infection; wheezes occur in asthma, COPD, infection and cardiac failure; crackles occur in pulmonary fibrosis, cardiac failure and COPD; crackles at the beginning of inspiration are common in COPD; localized loud coarse crackles may indicate bronchiectasis; fine late-inspiratory crackles are characteristic of diffuse interstitial fibrosis.",
        "contract": {
            "what_is_it": "auscultation finding → pathology interpretation map",
            "what_fact_produces": "breath sound interpretation facts",
            "source_support": "Hutchison 24e ch12 p176-177 Box 12.16",
        },
    },
    {
        "code": "HCH12-0019", "chapter": "12", "page": 175, "kind": "differential", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Tracheal deviation interpretation: deviation of trachea or cardiac impulse away from the affected side suggests a pleural effusion or pneumothorax (mediastinum pushed); deviation towards the affected side suggests fibrosis or collapse (mediastinum pulled); displacement of cardiac impulse without tracheal displacement may be scoliosis, funnel chest or left ventricular enlargement.",
        "contract": {
            "what_is_it": "tracheal/cardiac displacement differential",
            "source_support": "Hutchison 24e ch12 p175",
        },
    },
    {
        "code": "HCH12-0020", "chapter": "12", "page": 168, "kind": "question", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "Box 12.5 important questions in chronic cough: recent cold/sore throat/viral infection; history of asthma, nocturnal cough or wheeze; nasal discharge or sinusitis; acid reflux/indigestion or coughing after meals; what time of day is the cough worse; do you smoke; are you breathless; have you coughed up blood; hoarse voice; fevers or night sweats; weight loss; chest pain.",
        "contract": {
            "what_is_it": "chronic cough question set",
            "question_mode": "DIRECT",
            "what_fact_produces": "chronic cough red-flag and cause-eliciting facts",
            "source_support": "Hutchison 24e ch12 p168 Box 12.5",
        },
    },
    # ============================================================================
    # CROSS-CUTTING: MRC dyspnoea scale
    # ============================================================================
    {
        "code": "HCH12-0021", "chapter": "12", "page": 167, "kind": "threshold", "claim_type": "RESPIRATORY_METHOD",
        "type": "clinical_method",
        "text": "MRC dyspnoea scale (Box 12.2): 1=not troubled except on strenuous exercise; 2=short of breath when hurrying or walking up a slight hill; 3=walks slower than contemporaries on the level because of breathlessness or stops for breath at own pace; 4=stops for breath after about 100 m or a few minutes on the level; 5=too breathless to leave the house or breathless when dressing/undressing.",
        "contract": {
            "what_is_it": "MRC dyspnoea grading scale",
            "what_fact_produces": "MRC_DYSPNOEA_GRADE",
            "source_support": "Hutchison 24e ch12 p167 Box 12.2",
        },
    },
]

# Lookup helper: claim by code
CLAIM_BY_CODE = {c["code"]: c for c in CLAIMS}


def claims_for_chapter(chapter: str) -> list[dict]:
    return [c for c in CLAIMS if c["chapter"] == chapter]
