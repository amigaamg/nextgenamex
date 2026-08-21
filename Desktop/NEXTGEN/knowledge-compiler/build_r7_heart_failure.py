"""AMEXAN Medical Knowledge Compiler - R7 heart failure decompensation pathway (adult).

Completes the cardiac-cause-of-dyspnoea slice grounded to Hutchison 24e p193-198
(Cardiovascular system: congestive heart failure, NYHA, acute LVF, oedema, JVP)
and p123-129 (emergencies: breathless patient, cardiogenic shock) plus
Kumar & Clark 10e p929/937 (CXR heart size, orthopnoea/PND):

  - claims HCH13-0001..0006, HCH9-0001..0003, KCR-0019..0020
  - condition COND-HF-DECOMPENSATION (acute) linking to existing HEART-FAILURE
  - facts DYSPNOEA_AT_REST / DYSPNOEA_ON_MINIMAL_EXERTION /
    DYSPNOEA_ON_NORMAL_EXERTION (boolean, mapped from DYSPNOEA_SEVERITY answers)
  - SCORE-NYHA severity instrument (NYHA I-IV, boolean/and/not conditions)
  - fact-mapping reconciliation: LEG_SWELLING_ASK -> PERIPHERAL_OEDEMA (boolean)
  - investigations INV-ECG, INV-ECHO, INV-BNP, INV-TROPONIN
  - PROT-HF-DECOMP full 12-step adult pathway (advice-level diuretic + ACE
    inhibitor - no drug dose rows, per scope decision)
  - monitoring MON-WEIGHT (new) + MON-SPO2/MON-HR/MON-RR
  - education EDU-HF-*
  - governance + provenance + master matrix

Run:  python build_r7_heart_failure.py <out.sql>
"""
from __future__ import annotations

import json
import sys

from compiler_core import sql_literal, stable_uuid


def u(seed: str) -> str:
    return str(stable_uuid(seed))


def jq(obj: dict) -> str:
    """Emit a dict as a safe single-quoted JSON literal for ::jsonb casts."""
    return "'" + json.dumps(obj, separators=(",", ":"), ensure_ascii=False).replace("'", "''") + "'"


def c(claim_code: str) -> str:
    return f"(SELECT claim_id FROM knowledge.source_claim WHERE claim_code = {sql_literal(claim_code)})"


def p(otype: str, oid: str, ocode: str, claim: str) -> str:
    return (
        f"INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) "
        f"VALUES ({sql_literal(u('PROV:' + otype + ':' + ocode + ':' + claim))}, {c(claim)}, {sql_literal(otype)}, {sql_literal(oid)}, {sql_literal(ocode)}, 'derived_from') "
        f"ON CONFLICT (id) DO NOTHING;"
    )


# ---------------------------------------------------------------------------
# 0. Claims
# ---------------------------------------------------------------------------
# (code, page, chunk, chapter, ctype, kind, text, contract)
H1C13_CHUNK_193 = "019e65f6-2e79-5987-a4cf-f0a1b6b52068"
H1C13_CHUNK_196 = "7ac14d53-c395-5ca0-97d4-826c5d692565"
H1C13_CHUNK_198 = "959fd9ed-86c8-56df-9fa0-ba6e67cf6964"
H1C09_CHUNK_123 = "22bc3a24-79d6-526b-91bb-3dbee146ba26"
H1C09_CHUNK_124 = "3126b5c6-8d52-5a42-9cb9-2a48293eabba"
H1C09_CHUNK_129 = "bc7582d0-879d-53aa-b4e7-7c4e935252bb"
KC28_CHUNK_929 = "8015cb33-f797-5c8a-aeaf-c4e37beafd95"
KC28_CHUNK_937 = "68e27abe-86b4-5d63-926e-03a6126046ba"

CLAIMS = [
    ("HCH13-0001", 193, H1C13_CHUNK_193, "H1-C13", "HUTCHISON_24_2018", "CARDIOVASCULAR_METHOD", "definition",
     "Congestive heart failure - typical patient: middle-aged (male) or elderly (either sex) patient with a history of myocardial infarction or long-standing hypertension; in cases where there is no clear cause, always enquire about alcohol consumption. Major symptoms: exertional fatigue and shortness of breath, with orthopnoea and paroxysmal nocturnal dyspnoea in advanced cases. Major signs: fluid retention - basal crackles, raised JVP, peripheral oedema; reduced cardiac output - cool skin, peripheral cyanosis; other findings - third heart sound.",
     {"what_is_it": "Congestive heart failure clinical features (Box 13.10)", "what_fact_produces": "DYSPNOEA_PRESENT, ORTHOPNOEA, PND, PERIPHERAL_OEDEMA, CRACKLES, JUGULAR_VENOUS_DISTENTION", "source_support": "Hutchison 24e p193"}), 
    ("HCH13-0002", 193, H1C13_CHUNK_193, "H1-C13", "HUTCHISON_24_2018", "CARDIOVASCULAR_METHOD", "investigation",
     "Congestive heart failure diagnosis - ECG: usually abnormal, often showing Q waves (previous myocardial infarction), left ventricular hypertrophy (hypertension) or left bundle branch block (LBBB); chest X-ray: cardiac enlargement with congested lung fields; echocardiogram: left ventricular dilatation with regional (coronary heart disease) or global (cardiomyopathy) contractile impairment; raised B-type natriuretic peptide (BNP) useful in cases of diagnostic uncertainty; renal function as prelude to diuretic and angiotensin converting enzyme (ACE) inhibitor therapy; blood count to rule out anaemia. The echocardiogram is the single most important diagnostic test in the patient with heart failure.",
     {"what_is_it": "Congestive heart failure diagnosis + investigations (Box 13.10)", "what_connects_to": "INV-ECG, INV-CXR, INV-ECHO, INV-BNP, INV-UREA-CREAT, INV-FBC", "source_support": "Hutchison 24e p193"}),
    ("HCH13-0003", 193, H1C13_CHUNK_193, "H1-C13", "HUTCHISON_24_2018", "CARDIOVASCULAR_METHOD", "threshold",
     "New York Heart Association (NYHA) classification of breathlessness in heart failure (Table 13.2): Class I - asymptomatic; Class II - symptoms on normal exertion, e.g. walking up a flight of stairs; Class III - symptoms on minimal exertion, e.g. getting dressed; Class IV - symptoms at rest.",
     {"what_is_it": "NYHA functional classification", "what_fact_produces": "DYSPNOEA_AT_REST, DYSPNOEA_ON_MINIMAL_EXERTION, DYSPNOEA_ON_NORMAL_EXERTION", "source_support": "Hutchison 24e p193 (Table 13.2)"}),
    ("HCH13-0004", 193, H1C13_CHUNK_193, "H1-C13", "HUTCHISON_24_2018", "CARDIOVASCULAR_METHOD", "red_flag",
     "Acute left ventricular failure - typical patient: acute myocardial infarction or known left ventricular disease. Major symptoms: severe dyspnoea, orthopnoea, frothy sputum. Major signs: low-output state (hypotension, oliguria, cold periphery), tachycardia, S3, sweating, crackles at lung bases. Diagnosis: chest X-ray shows bilateral air space consolidation with typical perihilar distribution; echocardiogram usually confirms left ventricular disease; ECG may show evidence of acute or previous myocardial infarction; blood gas analysis shows variable hypoxaemia. Vital to exclude valvular disease which is potentially correctable by surgery.",
     {"what_is_it": "Acute left ventricular failure presentation (Box 13.9)", "what_fact_produces": "DYSPNOEA_PRESENT, ORTHOPNOEA, CRACKLES", "what_connects_to": "INV-ECG, INV-CXR, INV-ECHO", "source_support": "Hutchison 24e p193 (Box 13.9)"}),
    ("HCH13-0005", 196, H1C13_CHUNK_196, "H1-C13", "HUTCHISON_24_2018", "CARDIOVASCULAR_METHOD", "examination",
     "Subcutaneous oedema that pits on digital pressure is a cardinal feature of congestive heart failure; pressure should be applied over a bony prominence (tibia, lateral malleoli, sacrum). Oedema is caused by salt and water retention by the kidney: reduced sodium delivery to the nephron (from constriction of preglomerular arterioles in response to sympathetic activation and angiotensin II) and increased sodium reabsorption (proximal tubule early in failure; later renin-angiotensin activation stimulates aldosterone, increasing distal sodium reabsorption). Salt and water retention expands plasma volume and capillary hydrostatic pressure so fluid accumulates in the interstitial space; oedema is most prominent around the ankles in the ambulant patient and over the sacrum in the bedridden patient, and may involve legs, genitalia and trunk in advanced failure, with ascites and pleural/pericardial transudation.",
     {"what_is_it": "Pitting oedema - cardinal feature of congestive heart failure + mechanisms", "what_fact_produces": "PERIPHERAL_OEDEMA", "source_support": "Hutchison 24e p196"}),
    ("HCH13-0006", 198, H1C13_CHUNK_198, "H1-C13", "HUTCHISON_24_2018", "CARDIOVASCULAR_METHOD", "examination",
     "The jugular venous pressure (JVP) is assessed from the waveform of the internal jugular vein adjacent to the medial border of the sternocleidomastoid muscle; distension of the external jugular vein is a useful clue to an elevated JVP. It is measured in centimetres vertically from the sternal angle to the top of the venous waveform; the normal upper limit is 4 cm (about 9 cm above the right atrium, corresponding to 6 mmHg). Elevation of the JVP indicates a raised right atrial pressure unless the superior vena cava is obstructed. Causes of elevated JVP (Box 13.12) include congestive heart failure, cor pulmonale, pulmonary embolism, right ventricular infarction, tricuspid valve disease, tamponade, constrictive pericarditis, hypertrophic/restrictive cardiomyopathy, superior vena cava obstruction and iatrogenic fluid overload.",
     {"what_is_it": "Jugular venous pressure assessment + causes of elevated JVP (Box 13.12)", "what_fact_produces": "JUGULAR_VENOUS_DISTENTION", "source_support": "Hutchison 24e p198 (Box 13.12)"}),
    ("HCH9-0001", 123, H1C09_CHUNK_123, "H1-C09", "HUTCHISON_24_2018", "EMERGENCY_METHOD", "red_flag",
     "In the emergency patient, a raised jugular venous pressure may suggest early heart failure; precordial auscultation may reveal a pericardial rub. Important examination features in the initial rapid assessment include the fine crepitations of pulmonary oedema, the hyperresonant percussion and tracheal deviation of pneumothorax, and asymmetric blood pressure readings consistent with thoracic aortic dissection.",
     {"what_is_it": "Raised JVP may suggest early heart failure; fine crepitations of pulmonary oedema", "what_fact_produces": "JUGULAR_VENOUS_DISTENTION, CRACKLES", "source_support": "Hutchison 24e p123"}),
    ("HCH9-0002", 124, H1C09_CHUNK_124, "H1-C09", "HUTCHISON_24_2018", "EMERGENCY_METHOD", "management",
     "The breathless patient should be placed in a safe, monitored (ECG and pulse oximetry) environment; act quickly if there is visible distress, use of accessory muscles, high respiratory rate, high pulse rate, cyanosis or low oxygen saturations. The immediate response is to administer high-flow oxygen unless there is good evidence that this has, on this or previous occasions, caused breathing difficulties (most commonly chronic obstructive pulmonary disease). In most cases arrangements for urgent ECG and chest X-ray (CXR) will be made immediately, before the initial clinical assessment is complete. Pulmonary oedema is among the potentially life-threatening conditions presenting as breathlessness (Table 9.4). In chest pain, troponin is measured in blood (released when cardiac myocytes undergo ischaemic necrosis); a negative result indicates the risk of a serious acute cardiac event in the ensuing 30 days is extremely low.",
     {"what_is_it": "Breathless patient: monitored environment, high-flow O2 unless COPD, urgent ECG + CXR", "what_connects_to": "INV-ECG, INV-CXR, INV-TROPONIN, MON-SPO2", "source_support": "Hutchison 24e p124 (Table 9.4)"}),
    ("HCH9-0003", 129, H1C09_CHUNK_129, "H1-C09", "HUTCHISON_24_2018", "EMERGENCY_METHOD", "red_flag",
     "Cardiogenic shock is a failure of the heart to pump blood effectively to meet peripheral oxygen demands, most frequently due to a large myocardial infarction but also to cardiac dysrhythmias, other causes of cardiac muscle pump failure (myocarditis, cardiomyopathy) or acute cardiac valve problems. There is usually a narrow pulse pressure; it may be associated with preceding chest pain, palpitations or breathlessness (in particular orthopnoea), and there are frequently auscultatory features of pulmonary oedema. An ECG is often informative and may show changes of recent infarction, dysrhythmia or nonspecific changes of pericarditis, myocarditis and cardiomyopathy. Treatment largely depends on the cause; inotropic support and invasive measures are frequently required.",
     {"what_is_it": "Cardiogenic shock - presentation and escalation", "what_connects_to": "REF-CRITICAL-CARE, INV-ECG", "source_support": "Hutchison 24e p129"}),
    ("KCR-0019", 929, KC28_CHUNK_929, "KC-C28", "KUMAR_CLARK_10_2017", "RESPIRATORY_METHOD", "investigation",
     "On the chest X-ray, heart size should be less than 50% of the thoracic width on a PA chest film; assess the heart borders. Cardiomegaly may be caused by hypertension, valvular disease, heart failure or cardiomyopathy. Interstitial changes may be caused by pulmonary oedema or fibrosis; loss of the costophrenic angle is usually due to pleural effusions.",
     {"what_is_it": "CXR interpretation: heart size <50% thoracic width; cardiomegaly causes", "what_connects_to": "INV-CXR", "source_support": "Kumar & Clark 10e p929"}),
    ("KCR-0020", 937, KC28_CHUNK_937, "KC-C28", "KUMAR_CLARK_10_2017", "RESPIRATORY_METHOD", "definition",
     "Orthopnoea is breathlessness on lying down; while classically linked to heart failure it is partly due to the weight of the abdominal contents pushing the diaphragm up into the thorax. Paroxysmal nocturnal dyspnoea (PND) describes acute episodes of breathlessness at night, typically due to heart failure. Breathlessness can be graded using the Medical Research Council (MRC) grading of dyspnoea (Box 28.5).",
     {"what_is_it": "Orthopnoea and paroxysmal nocturnal dyspnoea - typically due to heart failure", "what_fact_produces": "ORTHOPNOEA, PND", "source_support": "Kumar & Clark 10e p937"}),
]

# ---------------------------------------------------------------------------
# 1. Conditions
# ---------------------------------------------------------------------------
CONDITIONS = [
    ("COND-HF-DECOMPENSATION", "acute", "Heart failure decompensation",
     "Acute worsening of heart failure with congestion (dyspnoea, orthopnoea, paroxysmal nocturnal dyspnoea, peripheral oedema, raised JVP, basal crackles) and/or low cardiac output (fatigue, cool periphery, hypotension), most often on a background of ischaemic or hypertensive left ventricular disease; severe cases present as acute left ventricular failure or cardiogenic shock."),
]

PHEN_DIFFERENTIAL = [
    ("PHEN-CHF-CONGESTIVE", "COND-HF-DECOMPENSATION", 0.95),
    ("PHEN-CHF-CONGESTIVE", "HEART-FAILURE", 0.90),
    ("PHEN-HYPOXAEMIA", "COND-HF-DECOMPENSATION", 0.40),
    ("PHEN-RESPIRATORY-FAILURE", "COND-HF-DECOMPENSATION", 0.50),
]

# ---------------------------------------------------------------------------
# 2. Facts + score
# ---------------------------------------------------------------------------
NEW_FACTS = [
    ("DYSPNOEA_AT_REST", "boolean", "Dyspnoea at rest - NYHA class IV (symptoms at rest)"),
    ("DYSPNOEA_ON_MINIMAL_EXERTION", "boolean", "Dyspnoea on minimal exertion (e.g. getting dressed) - NYHA class III"),
    ("DYSPNOEA_ON_NORMAL_EXERTION", "boolean", "Dyspnoea on normal exertion (e.g. walking up a flight of stairs) - NYHA class II"),
]

# SCORE-NYHA: mutually-exclusive classes; each class is a component whose
# condition gates exactly one NYHA band, so at most one matches.
NYHA_COMPONENTS = [
    ("NYHA-1", "NYHA I - Asymptomatic",
     {"type": "and", "conditions": [
         {"type": "not", "condition": {"type": "boolean", "fact_code": "DYSPNOEA_AT_REST", "expect": True}},
         {"type": "not", "condition": {"type": "boolean", "fact_code": "DYSPNOEA_ON_MINIMAL_EXERTION", "expect": True}},
         {"type": "not", "condition": {"type": "boolean", "fact_code": "DYSPNOEA_ON_NORMAL_EXERTION", "expect": True}},
     ]}, 1, "No dyspnoea on ordinary exertion; asymptomatic (HCH13-0003)."),
    ("NYHA-2", "NYHA II - Symptoms on normal exertion",
     {"type": "and", "conditions": [
         {"type": "boolean", "fact_code": "DYSPNOEA_ON_NORMAL_EXERTION", "expect": True},
         {"type": "not", "condition": {"type": "boolean", "fact_code": "DYSPNOEA_ON_MINIMAL_EXERTION", "expect": True}},
         {"type": "not", "condition": {"type": "boolean", "fact_code": "DYSPNOEA_AT_REST", "expect": True}},
     ]}, 2, "Symptoms on normal exertion, e.g. walking up a flight of stairs (HCH13-0003)."),
    ("NYHA-3", "NYHA III - Symptoms on minimal exertion",
     {"type": "and", "conditions": [
         {"type": "boolean", "fact_code": "DYSPNOEA_ON_MINIMAL_EXERTION", "expect": True},
         {"type": "not", "condition": {"type": "boolean", "fact_code": "DYSPNOEA_AT_REST", "expect": True}},
     ]}, 3, "Symptoms on minimal exertion, e.g. getting dressed (HCH13-0003)."),
    ("NYHA-4", "NYHA IV - Symptoms at rest",
     {"type": "boolean", "fact_code": "DYSPNOEA_AT_REST", "expect": True},
     4, "Symptoms at rest (HCH13-0003)."),
]

NYHA_INTERPRETATIONS = [
    (1, 1, "NYHA I - Asymptomatic", "Outpatient", "No symptoms on ordinary exertion; confirm cause (ischaemic/hypertensive/valvular), ECG, CXR, echo, BNP."),
    (2, 2, "NYHA II - Mild", "Outpatient", "Symptoms on normal exertion (stairs); institute disease-modifying therapy, monitor fluid status and weight."),
    (3, 3, "NYHA III - Moderate", "Refer", "Symptoms on minimal exertion (dressing); refer for specialist review; optimise diuretic/ACE therapy."),
    (4, 4, "NYHA IV - Severe", "Refer", "Symptoms at rest; urgent referral/admission; acute decompensation pathway with oxygen, ECG, CXR, echo, BNP."),
]

# ---------------------------------------------------------------------------
# 3. Fact-mapping reconciliation
# ---------------------------------------------------------------------------
# LEG_SWELLING_ASK currently maps to coded LEG_SWELLING; the CHF phenotype
# expects boolean PERIPHERAL_OEDEMA. Add complementary boolean mappings so the
# interview answer feeds the phenotype. Also map DYSPNOEA_SEVERITY answers to
# the NYHA boolean facts so the interview derives NYHA class.
FACT_MAPPINGS = [
    # question_code, answer_code, fact_definition_code, value
    ("LEG_SWELLING_ASK", "YES", "PERIPHERAL_OEDEMA", "true"),
    ("LEG_SWELLING_ASK", "NO", "PERIPHERAL_OEDEMA", "false"),
    ("DYSPNOEA_SEVERITY", "ON_EXERTION", "DYSPNOEA_ON_NORMAL_EXERTION", "true"),
    ("DYSPNOEA_SEVERITY", "ON_WALKING", "DYSPNOEA_ON_MINIMAL_EXERTION", "true"),
    ("DYSPNOEA_SEVERITY", "AT_REST", "DYSPNOEA_AT_REST", "true"),
]

# ---------------------------------------------------------------------------
# 4. Investigations
# ---------------------------------------------------------------------------
NEW_INVESTIGATIONS = [
    ("INV-ECG", "12-lead ECG", "physiological", "CARDIOVASCULAR",
     "12-lead electrocardiogram - in heart failure usually abnormal: Q waves (previous MI), left ventricular hypertrophy, left bundle branch block or dysrhythmia; in cardiogenic shock may show recent infarction or dysrhythmia."),
    ("INV-ECHO", "Echocardiogram", "imaging", "CARDIOVASCULAR",
     "Echocardiography - the single most important diagnostic test in heart failure: shows left ventricular dilatation with regional (coronary heart disease) or global (cardiomyopathy) contractile impairment; excludes correctable valvular disease."),
    ("INV-BNP", "B-type natriuretic peptide", "laboratory", "CARDIOVASCULAR",
     "B-type natriuretic peptide (BNP) - raised BNP is useful in cases of diagnostic uncertainty in heart failure."),
    ("INV-TROPONIN", "Cardiac troponin", "laboratory", "CARDIOVASCULAR",
     "Cardiac troponin - released when cardiac myocytes undergo ischaemic necrosis; measured in emergency chest pain/breathlessness; a negative result indicates the risk of a serious acute cardiac event in the ensuing 30 days is extremely low."),
]

INVESTIGATION_CONDITION = [
    ("HEART-FAILURE", "INV-ECG", 0.95, "ECG usually abnormal in heart failure (HCH13-0002)."),
    ("HEART-FAILURE", "INV-ECHO", 0.95, "Echo is the single most important diagnostic test in heart failure (HCH13-0002)."),
    ("HEART-FAILURE", "INV-BNP", 0.85, "Raised BNP useful in diagnostic uncertainty (HCH13-0002)."),
    ("HEART-FAILURE", "INV-FBC", 0.50, "Blood count to rule out anaemia (HCH13-0002)."),
    ("COND-HF-DECOMPENSATION", "INV-ECG", 0.95, "ECG in acute decompensation may show MI, LBBB or dysrhythmia (HCH13-0002/0004)."),
    ("COND-HF-DECOMPENSATION", "INV-CXR", 0.95, "CXR: cardiac enlargement, congested lung fields, bilateral perihilar air-space consolidation (HCH13-0002/0004, KCR-0019)."),
    ("COND-HF-DECOMPENSATION", "INV-ECHO", 0.95, "Echo confirms LV dilatation and contractile impairment; excludes correctable valvular disease (HCH13-0002/0004)."),
    ("COND-HF-DECOMPENSATION", "INV-BNP", 0.85, "Raised BNP useful in diagnostic uncertainty (HCH13-0002)."),
    ("COND-HF-DECOMPENSATION", "INV-TROPONIN", 0.60, "Troponin measured in emergency chest pain/breathlessness; negative result lowers 30-day acute cardiac risk (HCH9-0002)."),
]

# ---------------------------------------------------------------------------
# 5. Protocol - PROT-HF-DECOMP (adult, 12 steps)
# ---------------------------------------------------------------------------
PROTOCOL_STEPS = [
    ("STEP-01", "Confirm heart failure decompensation", "eligibility", 10,
     "Confirm acute decompensation of heart failure: worsening dyspnoea, orthopnoea, paroxysmal nocturnal dyspnoea, leg swelling/oedema, fatigue, on a background of ischaemic or hypertensive left ventricular disease (or known heart failure).",
     "Congestion with or without low cardiac output characterises decompensation (HCH13-0001/0004/0005).", True),
    ("STEP-02", "Assess airway, breathing, circulation + severity", "red_flag", 20,
     "Rapid ABC assessment in a safe, monitored (ECG + pulse oximetry) environment; detect severe dyspnoea, orthopnoea, frothy sputum, low-output state (hypotension, oliguria, cold periphery), tachycardia, S3, sweating, crackles, cyanosis or narrow pulse pressure (cardiogenic shock).",
     "Acute LVF and cardiogenic shock are emergencies (HCH13-0004, HCH9-0003).", True),
    ("STEP-03", "Position the patient upright and give oxygen", "treatment", 30,
     "Sit the patient upright. Administer high-flow oxygen unless there is good evidence it causes breathing difficulty (most commonly COPD); reassess frequently.",
     "High-flow oxygen unless COPD is the immediate response to the distressed breathless patient (HCH9-0002).", True),
    ("STEP-04", "Obtain a 12-lead ECG", "investigation", 40,
     "Urgent 12-lead ECG: look for Q waves (previous MI), left ventricular hypertrophy, LBBB or dysrhythmia; in cardiogenic shock may show recent infarction or dysrhythmia.",
     "ECG is urgent in the breathless patient and is usually abnormal in heart failure (HCH9-0002, HCH13-0002).", True),
    ("STEP-05", "Image the chest", "investigation", 50,
     "Chest X-ray: cardiac enlargement, congested lung fields, bilateral perihilar air-space consolidation; heart size should be <50% of thoracic width on PA film. Also excludes pneumothorax, pneumonia and large pleural effusions.",
     "CXR is urgent and shows the congested cardiac pattern; cardiomegaly <50% thoracic width (HCH9-0002, HCH13-0002/0004, KCR-0019).", True),
    ("STEP-06", "Send BNP + renal function + blood count", "investigation", 60,
     "BNP (raised in diagnostic uncertainty), renal function as prelude to diuretic and ACE inhibitor therapy, and blood count to rule out anaemia.",
     "BNP, renal function and FBC are the additional investigations in congestive heart failure (HCH13-0002).", True),
    ("STEP-07", "Echocardiogram", "investigation", 70,
     "Echocardiogram - the single most important diagnostic test: LV dilatation with regional or global contractile impairment; exclude correctable valvular disease.",
     "Echo confirms the diagnosis and guides therapy (HCH13-0002/0004).", True),
    ("STEP-08", "Start diuretic + ACE inhibitor therapy (advice-level)", "treatment", 80,
     "Loop diuretic for congestion and an angiotensin converting enzyme (ACE) inhibitor once renal function is known; monitor weight, fluid balance, renal function and potassium. (Advice-level - verify doses against the local formulary.)",
     "Renal function is the prelude to diuretic and ACE inhibitor therapy (HCH13-0002).", True),
    ("STEP-09", "Monitor vital signs and daily weight", "monitoring", 90,
     "Monitor SpO2 (target according to comorbidity), heart rate, respiratory rate and daily body weight; track urine output and fluid balance.",
     "Fluid retention tracking (daily weight) is central to decongestion in heart failure (HCH13-0005).", True),
    ("STEP-10", "Escalate if cardiogenic shock or deterioration", "escalation", 100,
     "If hypotension, oliguria, cool periphery, narrow pulse pressure or failure to improve: escalate urgently - inotropic support and invasive measures may be required; refer to critical care.",
     "Cardiogenic shock requires inotropic support and invasive measures (HCH9-0003).", True),
    ("STEP-11", "Educate the patient and plan prevention", "education", 110,
     "Teach daily weight monitoring, salt/fluid restriction, medication adherence (diuretic + ACE inhibitor) and symptom recognition (orthopnoea, PND, leg swelling) with an action plan to seek care early.",
     "Self-care reduces recurrent decompensation (HCH13-0005/0006).", True),
    ("STEP-12", "Close the care loop", "follow_up", 120,
     "Grade NYHA class (I-IV), document ECG/CXR/echo/BNP results, disposition, diuretic + ACE inhibitor plan and follow-up; reconsider the underlying cause (ischaemic, hypertensive, valvular, cardiomyopathy, alcohol).",
     "Heart failure is chronic: the decompensation episode feeds ongoing maintenance and surveillance (HCH13-0002/0003).", True),
]

PROTOCOL_ACTIONS = [
    ("STEP-01", "score", "SCORE-NYHA", "NYHA functional class", "Grade NYHA I-IV from exertional symptom threshold (normal exertion / minimal exertion / at rest)", "routine", 10),
    ("STEP-02", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Continuous in acute decompensation; target per comorbidity", "immediate", 10),
    ("STEP-02", "monitor", "MON-HR", "Heart rate monitoring", "Tachycardia and dysrhythmia detection; cardiac apex rate in AF", "immediate", 20),
    ("STEP-02", "monitor", "MON-RR", "Respiratory rate monitoring", "Tachypnoea and work of breathing", "immediate", 30),
    ("STEP-03", "advice", "ADV-HF-POSITION", "Sit the patient upright", "Sitting upright reduces preload and work of breathing in pulmonary oedema", "immediate", 10),
    ("STEP-03", "advice", "ADV-HF-OXYGEN", "High-flow oxygen unless COPD", "High-flow O2 with reservoir unless known COPD / CO2 retention; reassess frequently", "immediate", 20),
    ("STEP-04", "investigate", "INV-ECG", "12-lead ECG", "MI, LVH, LBBB, dysrhythmia; dynamic changes", "urgent", 10),
    ("STEP-05", "investigate", "INV-CXR", "Chest X-ray", "Cardiac enlargement, congested lung fields, perihilar consolidation; exclude pneumothorax/effusion", "urgent", 10),
    ("STEP-06", "investigate", "INV-BNP", "B-type natriuretic peptide", "Raised in heart failure; useful in diagnostic uncertainty", "urgent", 10),
    ("STEP-06", "investigate", "INV-UREA-CREAT", "Renal function (urea/creatinine)", "Prelude to diuretic + ACE inhibitor therapy", "urgent", 20),
    ("STEP-06", "investigate", "INV-FBC", "Full blood count", "Rule out anaemia as a driver of symptoms", "routine", 30),
    ("STEP-07", "investigate", "INV-ECHO", "Echocardiogram", "Single most important test: LV dilatation + contractile impairment; exclude valvular disease", "urgent", 10),
    ("STEP-08", "advice", "ADV-HF-DIURETIC", "Loop diuretic (advice)", "Loop diuretic for congestion once renal function known; monitor weight, fluid balance, electrolytes (advice-level - verify dose against local formulary)", "urgent", 10),
    ("STEP-08", "advice", "ADV-HF-ACE", "ACE inhibitor (advice)", "ACE inhibitor once renal function known; monitor potassium and renal function (advice-level - verify dose against local formulary)", "urgent", 20),
    ("STEP-09", "monitor", "MON-WEIGHT", "Daily body weight", "Daily weight tracks fluid retention/decongestion in heart failure", "routine", 10),
    ("STEP-09", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Target per comorbidity; avoid excessive O2 in COPD", "routine", 20),
    ("STEP-10", "refer", "REF-CRITICAL-CARE", "Critical care referral", "Cardiogenic shock: inotropic support + invasive measures", "immediate", 10),
    ("STEP-10", "refer", "REF-CARDIOLOGY", "Cardiology review", "Specialist review for echo-guided management and underlying cause", "urgent", 20),
    ("STEP-11", "educate", "EDU-HF-SELF-CARE", "Heart failure self-care", "Daily weight, salt/fluid restriction, medication adherence, early symptom recognition", "routine", 10),
    ("STEP-11", "educate", "EDU-HF-DIET", "Salt and fluid restriction", "Reduce sodium intake; monitor fluid balance to prevent fluid retention", "routine", 20),
    ("STEP-11", "educate", "EDU-HF-SYMPTOM-RECOGNITION", "Symptom recognition and action plan", "Seek care early for increasing orthopnoea, PND, leg swelling or weight gain", "routine", 30),
    ("STEP-12", "educate", "EDU-HF-CLINICIAN", "Heart failure reasoning summary", "Render NYHA class, ECG/CXR/echo/BNP evidence, diuretic + ACE plan, disposition and follow-up", "routine", 10),
]

PROTOCOL_MONITORING = [
    ("MON-SPO2", "Continuous during acute decompensation; target per comorbidity (avoid excessive O2 in COPD)",
     "SpO2 <90% or falling despite oxygen, or rising work of breathing",
     "Reassess severity; check ABG if available; escalate to critical care if cardiogenic shock"),
    ("MON-HR", "Continuous during acute decompensation",
     "New dysrhythmia, uncontrolled tachycardia, or pulse deficit (AF)",
     "Repeat ECG; senior/cardiology review"),
    ("MON-RR", "Continuous during acute decompensation",
     "Persistent tachypnoea or rising work of breathing",
     "Reassess severity; consider CXR/ABG; escalate"),
    ("MON-WEIGHT", "Daily",
     "Rapid weight gain (>2 kg over 1-2 days) reflecting fluid retention",
     "Review diuretic dose, fluid balance and renal function"),
]

# ---------------------------------------------------------------------------
# 6. Education
# ---------------------------------------------------------------------------
EDUCATION = [
    ("EDU-HF-SELF-CARE", "Heart failure self-care", "patient",
     "instruction", "Weigh yourself daily, restrict salt and fluid, take diuretic and ACE inhibitor medicines as prescribed, and seek care early for increasing orthopnoea, paroxysmal nocturnal dyspnoea, leg swelling or rapid weight gain (HCH13-0002/0005)."),
    ("EDU-HF-DIET", "Salt and fluid restriction", "patient",
     "instruction", "Heart failure causes salt and water retention; reduce sodium intake and monitor fluid balance to prevent peripheral oedema and pulmonary congestion (HCH13-0005)."),
    ("EDU-HF-SYMPTOM-RECOGNITION", "Symptom recognition and action plan", "caregiver",
     "discharge", "Rising JVP, basal crackles, pitting ankle/sacral oedema and orthopnoea signal congestion; rapid weight gain is an early warning. Seek care early rather than waiting for breathlessness at rest (HCH13-0001/0006)."),
    ("EDU-HF-CLINICIAN", "Heart failure reasoning summary", "clinician",
     "explanation", "Render NYHA class, ECG/CXR/echo/BNP evidence, diuretic + ACE inhibitor plan, escalation threshold (cardiogenic shock), disposition and follow-up."),
]

# ---------------------------------------------------------------------------
# 7. Governance
# ---------------------------------------------------------------------------
GOVERNED_OBJECTS = [
    ("PROT-HF-DECOMP", "PROTOCOL", "Acute heart failure decompensation pathway",
     "Population-aware adult acute heart failure decompensation pathway: confirm decompensation, ABC + severity, upright positioning + high-flow oxygen unless COPD, ECG, CXR, BNP + renal + FBC, echo, advice-level diuretic + ACE inhibitor, monitoring (SpO2/HR/RR/daily weight), cardiogenic shock escalation, education and NYHA grading.", "HCH13-0002", "POP-ADULT"),
    ("SCORE-NYHA", "INTERPRETATION", "NYHA functional classification",
     "NYHA I-IV functional class from exertional dyspnoea threshold (normal exertion / minimal exertion / at rest), per Hutchison 24e Table 13.2 (HCH13-0003).", "HCH13-0003", "POP-ADULT"),
    ("PHEN-CHF-CONGESTIVE", "PHENOTYPE", "Cardiopulmonary congestion phenotype",
     "Dyspnoea + orthopnoea + PND + peripheral oedema + crackles pattern suggesting congestive heart failure decompensation (HCH13-0001/0004/0005).", "HCH13-0001", "POP-ADULT"),
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R7 heart failure decompensation (adult)")
    w("-- Congestive heart failure / decompensation grounded to Hutchison 24e p193-198")
    w("-- (claims HCH13-0001..0006), p123-129 (HCH9-0001..0003) and")
    w("-- Kumar & Clark 10e p929/937 (KCR-0019..0020). Adds NYHA score, investigations,")
    w("-- full adult decompensation pathway, advice-level diuretic + ACE (no dose rows).")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r7_heart_failure.py <out>")
    w("-- =============================================================================")
    w("")

    # 0. claims ----------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 0. knowledge.source_claim - heart failure claims")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_claim (claim_id, claim_code, source_version_id, chapter_id, chunk_id, page_start, page_end, claim_type, claim_kind, claim_text, knowledge_type, contract, confidence, status) VALUES")
    rows = []
    for code, page, chunk, chapter, sver, ctype, kind, text, contract in CLAIMS:
        rows.append(
            f"   ({sql_literal(u('RC:' + code))}, {sql_literal(code)}, {sql_literal(sver)}, {sql_literal(chapter)}, {sql_literal(chunk)}, {sql_literal(str(page))}, {sql_literal(str(page))}, {sql_literal(ctype)}, {sql_literal(kind)}, {sql_literal(text)}, 'medicine', {jq(contract)}::jsonb, 0.9, 'VERIFIED')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET chunk_id = EXCLUDED.chunk_id, page_start = EXCLUDED.page_start, claim_text = EXCLUDED.claim_text, contract = EXCLUDED.contract;")
    w("")

    # 1. conditions -------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. knowledge.condition - COND-HF-DECOMPENSATION (HEART-FAILURE exists)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.condition (id, concept_id, condition_code, canonical_name, description, condition_type, status) VALUES")
    rows = []
    for code, ctype, name, desc in CONDITIONS:
        rows.append(
            f"   ({sql_literal(u('COND:' + code))}, NULL, {sql_literal(code)}, {sql_literal(name)}, {sql_literal(desc)}, {sql_literal(ctype)}, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (condition_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, description = EXCLUDED.description, condition_type = EXCLUDED.condition_type;")
    w("")
    w("INSERT INTO knowledge.phenotype_differential (id, phenotype_id, condition_id, relationship_type, weight) VALUES")
    rows = []
    for phen, cond, wt in PHEN_DIFFERENTIAL:
        rows.append(
            f"   ({sql_literal(u('PD:' + phen + ':' + cond))}, (SELECT id FROM knowledge.phenotype WHERE phenotype_code = {sql_literal(phen)}), (SELECT id FROM knowledge.condition WHERE condition_code = {sql_literal(cond)}), 'associated', {sql_literal(f'{wt:.2f}')})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (phenotype_id, condition_id, relationship_type) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 2. facts + score ----------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2. clinical.fact_definition - NYHA boolean facts")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES")
    rows = [
        f"   ({sql_literal(code)}, {sql_literal(code)}, {sql_literal(desc)}, {sql_literal(dtype)}, false, true)"
        for code, dtype, desc in NEW_FACTS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (code) DO UPDATE SET description = EXCLUDED.description;")
    w("")
    w("-- ---------------------------------------------------------------------------")
    w("-- 2b. knowledge.severity_score - SCORE-NYHA (I-IV)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.severity_score (id, score_code, canonical_name, description, condition_id, population, max_score, source_reference, status) VALUES")
    w(f"   ({sql_literal(u('SCORE:NYHA'))}, 'SCORE-NYHA', 'NYHA functional classification', 'NYHA I-IV functional class from exertional dyspnoea threshold (normal exertion / minimal exertion / at rest) per Hutchison 24e Table 13.2 (HCH13-0003).', (SELECT id FROM knowledge.condition WHERE condition_code = 'HEART_FAILURE'), 'adult', 4, 'Hutchison 24e p193 (Table 13.2) - HCH13-0003', 'active')")
    w("ON CONFLICT (score_code) DO UPDATE SET description = EXCLUDED.description;")
    w("")
    w("INSERT INTO knowledge.severity_score_component (id, score_id, component_code, component_name, condition, points, rationale, sort_order) VALUES")
    rows = [
        f"   ({sql_literal(u('SC:NYHA:' + cc))}, (SELECT id FROM knowledge.severity_score WHERE score_code = 'SCORE-NYHA'), {sql_literal(cc)}, {sql_literal(name)}, {jq(cond)}::jsonb, {sql_literal(str(points))}, {sql_literal(rat)}, {sql_literal(str(sort))})"
        for sort, (cc, name, cond, points, rat) in enumerate(NYHA_COMPONENTS, start=10)
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (score_id, component_code) DO UPDATE SET condition = EXCLUDED.condition, points = EXCLUDED.points, rationale = EXCLUDED.rationale;")
    w("")
    w("INSERT INTO knowledge.severity_score_interpretation (id, score_id, min_score, max_score, severity_label, disposition, recommendation) VALUES")
    rows = [
        f"   ({sql_literal(u('SI:NYHA:' + str(mn) + '-' + str(mx)))}, (SELECT id FROM knowledge.severity_score WHERE score_code = 'SCORE-NYHA'), {sql_literal(str(mn))}, {sql_literal(str(mx))}, {sql_literal(label)}, {sql_literal(disp)}, {sql_literal(rec)})"
        for mn, mx, label, disp, rec in NYHA_INTERPRETATIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (score_id, min_score, max_score) DO UPDATE SET severity_label = EXCLUDED.severity_label, disposition = EXCLUDED.disposition, recommendation = EXCLUDED.recommendation;")
    w("")

    # 2c. fact-mapping reconciliation -------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2c. knowledge.fact_mapping - PERIPHERAL_OEDEMA + NYHA boolean reconciliation")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.fact_mapping (id, answer_option_id, fact_definition_code, value, is_active) VALUES")
    rows = []
    for qcode, acode, fcode, val in FACT_MAPPINGS:
        rows.append(
            f"   ({sql_literal(u('FM:' + qcode + ':' + acode + ':' + fcode))}, (SELECT ao.id FROM knowledge.answer_option ao JOIN knowledge.question q ON q.id = ao.question_id WHERE q.question_code = {sql_literal(qcode)} AND ao.answer_code = {sql_literal(acode)}), {sql_literal(fcode)}, {sql_literal(val)}, true)"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (answer_option_id, fact_definition_code) DO UPDATE SET value = EXCLUDED.value;")
    w("")

    # 3. investigations ---------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. knowledge.investigation - ECG / echo / BNP / troponin")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.investigation (id, concept_id, investigation_code, canonical_name, description, investigation_type, body_system_code, specimen, turn_around_minutes, preparation, status) VALUES")
    rows = []
    for code, name, itype, bsys, desc in NEW_INVESTIGATIONS:
        rows.append(
            f"   ({sql_literal(u('INV:' + code))}, NULL, {sql_literal(code)}, {sql_literal(name)}, {sql_literal(desc)}, {sql_literal(itype)}, {sql_literal(bsys)}, NULL, NULL, NULL, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (investigation_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, description = EXCLUDED.description;")
    w("")
    w("INSERT INTO knowledge.investigation_condition (id, investigation_id, condition_id, weight, rationale) VALUES")
    rows = []
    for cond, inv, wt, rat in INVESTIGATION_CONDITION:
        rows.append(
            f"   ({sql_literal(u('IC:' + inv + ':' + cond))}, (SELECT id FROM knowledge.investigation WHERE investigation_code = {sql_literal(inv)}), (SELECT id FROM knowledge.condition WHERE condition_code = {sql_literal(cond)}), {sql_literal(f'{wt:.2f}')}, {sql_literal(rat)})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (investigation_id, condition_id) DO UPDATE SET weight = EXCLUDED.weight, rationale = EXCLUDED.rationale;")
    w("")

    # 4. monitoring -------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. knowledge.monitoring - MON-WEIGHT (new)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.monitoring (id, concept_id, monitoring_code, canonical_name, description, target_type, unit, body_system_code, normal_low, normal_high, status) VALUES")
    w(f"   ({sql_literal(u('MON:WEIGHT'))}, NULL, 'MON-WEIGHT', 'Daily body weight', 'Daily weight to track fluid retention and decongestion in heart failure; rapid gain reflects fluid overload (HCH13-0005).', 'numeric', 'kg', 'CONSTITUTIONAL', NULL, NULL, 'active')")
    w("ON CONFLICT (monitoring_code) DO UPDATE SET description = EXCLUDED.description;")
    w("")

    # 5. protocol ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 5. PROT-HF-DECOMP - full 12-step pathway (adult) - replaces the draft")
    w("-- ---------------------------------------------------------------------------")
    w("UPDATE knowledge.protocol SET status='active', canonical_name='Acute heart failure decompensation pathway',")
    w("       description='Adult acute heart failure decompensation: confirm decompensation, ABC + severity, upright + high-flow oxygen unless COPD, ECG, CXR, BNP + renal + FBC, echo, advice-level diuretic + ACE inhibitor, monitoring, cardiogenic shock escalation, education, NYHA grading.',")
    w("       population='adult', source_reference='Hutchison 24e p193-198 + Kumar & Clark 10e p929/937 (HCH13-0001..0006, HCH9-0001..0003, KCR-0019..0020)'")
    w("WHERE protocol_code='PROT-HF-DECOMP';")
    w("DELETE FROM knowledge.protocol_action WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP');")
    w("DELETE FROM knowledge.protocol_monitoring WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP');")
    w("DELETE FROM knowledge.protocol_step WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP');")
    w("DELETE FROM knowledge.protocol_condition WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP');")
    w("")
    w("INSERT INTO knowledge.protocol_condition (id, protocol_id, condition_id, is_primary) VALUES")
    w(f"   ({sql_literal(u('PC:HF-DECOMP:PROT'))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP'), (SELECT id FROM knowledge.condition WHERE condition_code = 'COND-HF-DECOMPENSATION'), true),")
    w(f"   ({sql_literal(u('PC:HF-DECOMP:CHRONIC'))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP'), (SELECT id FROM knowledge.condition WHERE condition_code = 'HEART_FAILURE'), false)")
    w("ON CONFLICT (protocol_id, condition_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;")
    w("")
    w("INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required) VALUES")
    rows = [
        f"   ({sql_literal(u('PSTEP:HF:' + sc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP'), {sql_literal(sc)}, {sql_literal(label)}, {sql_literal(stype)}, {sql_literal(str(seq))}, {sql_literal(instr)}, {sql_literal(rat)}, {('TRUE' if req else 'FALSE')})"
        for sc, label, stype, seq, instr, rat, req in PROTOCOL_STEPS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, step_code) DO UPDATE SET instruction = EXCLUDED.instruction, rationale = EXCLUDED.rationale, sequence_no = EXCLUDED.sequence_no, step_type = EXCLUDED.step_type;")
    w("")
    w("INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order) VALUES")
    rows = [
        f"   ({sql_literal(u('PACT:HF:' + sc + ':' + ac + ':' + str(so)))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP'), (SELECT ps.id FROM knowledge.protocol_step ps JOIN knowledge.protocol p ON p.id = ps.protocol_id WHERE p.protocol_code = 'PROT-HF-DECOMP' AND ps.step_code = {sql_literal(sc)}), {sql_literal(at)}, {sql_literal(ac)}, {sql_literal(an)}, {sql_literal(detail)}, {sql_literal(urg)}, {sql_literal(str(so))})"
        for sc, at, ac, an, detail, urg, so in PROTOCOL_ACTIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (step_id, action_type, action_code) DO UPDATE SET detail = EXCLUDED.detail, sort_order = EXCLUDED.sort_order;")
    w("")
    w("INSERT INTO knowledge.protocol_monitoring (id, protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES")
    rows = [
        f"   ({sql_literal(u('PMON:HF:' + mc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-HF-DECOMP'), (SELECT id FROM knowledge.monitoring WHERE monitoring_code = {sql_literal(mc)}), {sql_literal(freq)}, {sql_literal(det)}, {sql_literal(esc)})"
        for mc, freq, det, esc in PROTOCOL_MONITORING
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, monitoring_id) DO UPDATE SET frequency = EXCLUDED.frequency, deterioration_rule = EXCLUDED.deterioration_rule, escalation_instruction = EXCLUDED.escalation_instruction;")
    w("")

    # 6. education ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 6. knowledge.education - heart failure education objects")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES")
    rows = []
    for code, _title, _aud, _ct, _body in EDUCATION:
        rows.append(
            f"   ({sql_literal(u('CONCEPT:' + code))}, {sql_literal('CNS-' + code)}, 'education', {sql_literal(_title)}, {sql_literal(_title)}, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (concept_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name;")
    w("")
    w("INSERT INTO knowledge.education (id, concept_id, education_code, title, audience, content_type, language_code, literacy_level, body, status) VALUES")
    rows = []
    for code, title, audience, ctype, body in EDUCATION:
        rows.append(
            f"   ({sql_literal(u('EDU:' + code))}, (SELECT id FROM knowledge.concept WHERE concept_code = {sql_literal('CNS-' + code)}), {sql_literal(code)}, {sql_literal(title)}, {sql_literal(audience)}, {sql_literal(ctype)}, 'en', 'plain', {sql_literal(body)}, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (education_code) DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body;")
    w("")
    w("INSERT INTO knowledge.education_condition (id, education_id, condition_id, weight) VALUES")
    rows = []
    for code, _title, _aud, _ct, _body in EDUCATION:
        for cond in ("HEART-FAILURE", "COND-HF-DECOMPENSATION"):
            rows.append(
                f"   ({sql_literal(u('EDC:' + code + ':' + cond))}, (SELECT id FROM knowledge.education WHERE education_code = {sql_literal(code)}), (SELECT id FROM knowledge.condition WHERE condition_code = {sql_literal(cond)}), 1.0)"
            )
    w(",\n".join(rows))
    w("ON CONFLICT (education_id, condition_id) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 7. governance + provenance --------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 7. governance.knowledge_object - heart failure pathway objects")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO governance.knowledge_object (id, object_code, knowledge_type, canonical_name, description, source_claim_code, jurisdiction_code, population_code, evidence_level_code, lifecycle_status, confidence, is_active, status) VALUES")
    rows = []
    for code, ktype, name, desc, claim, pop in GOVERNED_OBJECTS:
        rows.append(
            f"   ({sql_literal(u('GOBJ:' + code))}, {sql_literal(code)}, {sql_literal(ktype)}, {sql_literal(name)}, {sql_literal(desc)}, {sql_literal(claim)}, 'JUR-GLOBAL', {sql_literal(pop)}, 'EV-C', 'ACTIVE', 0.95, true, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (object_code) DO UPDATE SET lifecycle_status = EXCLUDED.lifecycle_status, description = EXCLUDED.description, population_code = EXCLUDED.population_code;")
    w("")
    w("INSERT INTO governance.knowledge_object_version (object_id, version_no, version_code, change_note, lifecycle_status, source_claim_code, created_by)")
    w("SELECT ko.id, 1, 'GO-V-R7-' || ko.object_code, 'R7 heart failure decompensation pathway release (HCH13-0001..0006, HCH9-0001..0003, KCR-0019..0020).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'")
    w("FROM governance.knowledge_object ko WHERE ko.object_code IN (" + ", ".join(sql_literal(x[0]) for x in GOVERNED_OBJECTS) + ")")
    w("ON CONFLICT (version_code) DO UPDATE SET change_note = EXCLUDED.change_note, lifecycle_status = EXCLUDED.lifecycle_status;")
    w("")
    for code, _ktype, _name, _desc, claim, _pop in GOVERNED_OBJECTS:
        w(p("governance.knowledge_object", u("GOBJ:" + code), code, claim))
    w("")

    # 8. master matrix ----------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 8. tracking.respiratory_master_matrix - heart failure status")
    w("-- ---------------------------------------------------------------------------")
    w("UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Hutchison 24e p193-198 + Kumar & Clark 10e p929/937 (HCH13-0001..0006, KCR-0019/0020)',")
    w("       notes='Dyspnoea/orthopnoea/PND + heart failure differential: congestive heart failure, NYHA I-IV, acute LVF, oedema, JVP; ECG/CXR/echo/BNP investigations; adult decompensation pathway active.',")
    w("       updated_at=now() WHERE item_code='SYM-DYSPNOEA';")
    w("UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Hutchison 24e p193 (Table 13.2, HCH13-0003)',")
    w("       notes='NYHA functional classification grades exercise limitation in heart failure (I asymptomatic - IV at rest).',")
    w("       updated_at=now() WHERE item_code='SYM-EXERCISE-INTOLERANCE';")
    w("INSERT INTO tracking.respiratory_master_matrix (id, family_code, family_name, item_code, item_name, population, status, source_ground, notes) VALUES")
    w(f"   ({sql_literal(u('MATRIX:COND-HEART-FAILURE'))}, 'F', 'Pulmonary vascular disease', 'COND-HEART-FAILURE', 'Heart failure (congestive decompensation - cardiac cause of dyspnoea)', 'adult', 'VERIFIED', 'Hutchison 24e p193-198 + Kumar & Clark 10e p929/937 (HCH13-0001..0006, KCR-0019/0020)', 'Congestive heart failure + decompensation pathway with NYHA grading, ECG/CXR/echo/BNP, advice-level diuretic + ACE, cardiogenic shock escalation.'),")
    w(f"   ({sql_literal(u('MATRIX:COND-HF-DECOMPENSATION'))}, 'F', 'Pulmonary vascular disease', 'COND-HF-DECOMPENSATION', 'Acute heart failure decompensation', 'adult', 'VERIFIED', 'Hutchison 24e p193/196/198 (HCH13-0001/0004/0005)', 'Acute congestion +/- low output; 12-step adult pathway PROT-HF-DECOMP active.')")
    w("ON CONFLICT (item_code) DO UPDATE SET status = EXCLUDED.status, source_ground = EXCLUDED.source_ground, notes = EXCLUDED.notes, updated_at = now();")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(CLAIMS)} claims, {len(CONDITIONS)} new conditions, {len(NYHA_COMPONENTS)} NYHA grades, {len(FACT_MAPPINGS)} fact mappings, {len(NEW_INVESTIGATIONS)} new investigations, {len(PROTOCOL_STEPS)} steps, {len(PROTOCOL_ACTIONS)} actions, {len(GOVERNED_OBJECTS)} governed objects")


if __name__ == "__main__":
    main(sys.argv[1])