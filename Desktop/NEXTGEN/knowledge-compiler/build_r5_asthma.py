"""AMEXAN Medical Knowledge Compiler - R5 asthma acute pathway (paediatric + adult).

Completes the obstructive-airway family slice grounded to Illustrated Baby
Nelson p183-186 (acute exacerbation management + written action plan):

  - claims BNR-0008..BNR-0012 (severity grid, ED treatment, imminent arrest,
    hospital/PICU escalation, action plan)
  - asthma medications: salbutamol (SABA), ipratropium (SAMA), prednisolone
    (oral corticosteroid), epinephrine, magnesium sulphate, aminophylline,
    beclometasone (ICS controller)
  - dose_reference rows for ASTHMA indication (paediatric + adult)
  - MON-PEF monitoring target
  - PROT-ASTHMA-ACUTE upgraded to a full 12-step pathway (both populations)
  - education: action plan, inhaler technique, triggers, teach-back, clinician
  - governance: PROT-ASTHMA-ACUTE ACTIVE + drug objects + provenance
  - master matrix: COND-ASTHMA / COND-ASTHMA-PAED / COND-ACUTE-SEVERE-ASTHMA /
    DRUG-BRONCHODILATOR / SYM-WHEEZE

Run:  python build_r5_asthma.py <out.sql>
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
# 0. Claims - Baby Nelson p183-186 (asthma)
# ---------------------------------------------------------------------------
ASTHMA_CLAIMS = [
    # code, chunk_id, page, type, kind, text, knowledge_type, contract
    ("BNR-0008", "eaf04089-8b6a-5d90-9569-56dc0394cb66", 183, "PAEDIATRIC_RESPIRATORY", "threshold",
     "Acute asthma severity assessment (mild / moderate / severe): consciousness (absent vs agitated-confused), cyanosis (absent vs likely), dyspnoea (walking vs talking vs at rest), speech (sentences vs phrases vs words), pulse (normal vs mild vs marked tachycardia, >180 bpm in young), pulsus paradoxus (normal vs <20 vs 20-40 mmHg), wheeze (end-expiratory vs holosystolic vs exp+insp, may be quiet), retractions (absent vs common vs usual), peak expiratory flow (>=70% vs 40-69% vs <40%), oximetry in air (>95% vs 90-95% vs <90%), PaCO2 (<42 vs >42 mmHg).",
     "medicine",
     {"what_is_it": "paediatric asthma severity grid", "what_fact_produces": "SPEECH_PATTERN, SPO2, PEF, HEART_RATE, WHEEZE_PRESENT, CYANOSIS", "source_support": "Illustrated Baby Nelson p183"}),
    ("BNR-0009", "eaf04089-8b6a-5d90-9569-56dc0394cb66", 183, "PAEDIATRIC_RESPIRATORY", "management",
     "Emergency department treatment of acute asthma exacerbation: inhaled SABA (salbutamol) 2.5-5 mg by nebulizer with saline up to 3 treatments in 1 hour OR 2-6 puffs SABA by MDI (puff=100 mcg); ipratropium bromide 125-250 mcg by nebulizer if no adequate response to the first salbutamol nebulizer (repeat every 20 minutes for the first hour only); oral corticosteroids 1-2 mg/kg in divided doses in moderate to severe exacerbations to hasten recovery and prevent recurrence; epinephrine (1:1000) 0.3-0.5 mg IM or SC may be given in severe cases.",
     "guideline_activity",
     {"what_is_it": "acute asthma ED treatment", "what_connects_to": "protocol step (acute asthma)", "source_support": "Illustrated Baby Nelson p183"}),
    ("BNR-0010", "eaf04089-8b6a-5d90-9569-56dc0394cb66", 183, "PAEDIATRIC_RESPIRATORY", "red_flag",
     "Signs of acute severe asthma with imminent respiratory arrest: drowsy or confused, paradoxical thoracoabdominal movement, absence of wheeze, bradycardia and absent pulsus paradoxus (due to respiratory muscle fatigue).",
     "medicine",
     {"what_is_it": "imminent arrest asthma signs", "what_fact_produces": "CONFUSION, CYANOSIS, WHEEZE_PRESENT", "source_support": "Illustrated Baby Nelson p183"}),
    ("BNR-0011", "d00bcd9e-a52b-5cac-adf8-0db3493f2071", 185, "PAEDIATRIC_RESPIRATORY", "management",
     "Hospital/PICU admission for asthma: PICU is indicated for severe respiratory distress or concern for potential respiratory failure and arrest. Inpatient action plan: cardio-pulmonary monitoring, oxygen, salbutamol nebulizer every 20 min as needed then every 1-4 hr, or continuous nebulization with oxygen 5-15 mg/hr; corticosteroids short course 3-7 days (oral prednisone 1-2 mg/kg, or parenteral methylprednisolone or hydrocortisone); ipratropium bromide nebulizer (poor evidence, no longer recommended).",
     "guideline_activity",
     {"what_is_it": "hospital/PICU asthma care", "what_connects_to": "protocol step (acute asthma)", "source_support": "Illustrated Baby Nelson p185"}),
    ("BNR-0012", "29895463-fd2b-5584-ab57-46065073a0f7", 186, "PAEDIATRIC_RESPIRATORY", "management",
     "After asthma exacerbation resolution: space SABA gradually; continue steroids for the full 3-7 days; start controller therapy; families of all children with asthma should have a written action plan to guide recognition and management of exacerbations; with a history of life-threatening episodes, especially abrupt-onset, consider providing an epinephrine autoinjector and possibly portable oxygen at home.",
     "guideline_activity",
     {"what_is_it": "post-exacerbation asthma action plan", "what_connects_to": "education (action plan), controller therapy", "source_support": "Illustrated Baby Nelson p186"}),
]

# ---------------------------------------------------------------------------
# 1. Asthma medications
# ---------------------------------------------------------------------------
# code, generic_name, drug_class, route_options, formulations
NEW_MEDS = [
    ("MED-SALBUTAMOL", "Salbutamol", "Short-acting beta-2 agonist (SABA)",
     '["inhalation","nebuliser","intravenous"]', '["MDI 100 mcg/puff","nebuliser solution","IV infusion"]'),
    ("MED-IPRATROPIUM", "Ipratropium bromide", "Short-acting muscarinic antagonist (SAMA)",
     '["inhalation","nebuliser"]', '["nebuliser solution"]'),
    ("MED-PREDNISOLONE", "Prednisolone", "Oral corticosteroid",
     '["oral"]', '["tablet","soluble tablet"]'),
    ("MED-EPINEPHRINE", "Epinephrine (adrenaline)", "Sympathomimetic (alpha+beta)",
     '["intramuscular","subcutaneous"]', '["1:1000 ampoule"]'),
    ("MED-MAGNESIUM-SULPHATE", "Magnesium sulphate", "Electrolyte / bronchodilator adjunct",
     '["intravenous"]', '["IV infusion"]'),
    ("MED-AMINOPHYLLINE", "Aminophylline", "Theophylline (phosphodiesterase inhibitor)",
     '["intravenous"]', '["IV infusion"]'),
    ("MED-BECLOMETASONE", "Beclometasone dipropionate", "Inhaled corticosteroid (ICS)",
     '["inhalation"]', '["MDI 100 mcg/puff"]'),
]

# medication_code -> (dose_expression, weight_basis, per_kg_min, per_kg_max,
#                     frequency, duration, is_verified, evidence_claim, route, population)
ASTHMA_DOSES = [
    ("MED-SALBUTAMOL", "2.5-5 mg by nebulizer (or 2-6 puffs by MDI, puff=100 mcg); repeat up to 3 treatments in 1 hour",
     None, None, None, "every 20 minutes in the first hour, then every 3-4 hours as needed",
     "during exacerbation", True, "BNR-0009", "inhalation", "paediatric"),
    ("MED-SALBUTAMOL", "2.5-5 mg by nebulizer (or 100-200 mcg by MDI); repeat up to 3 treatments in 1 hour",
     None, None, None, "every 20 minutes in the first hour, then every 3-4 hours as needed",
     "during exacerbation", True, "BNR-0009", "inhalation", "adult"),
    ("MED-IPRATROPIUM", "125-250 mcg by nebulizer if no adequate response to first salbutamol",
     None, None, None, "repeat every 20 minutes (first hour only)", "first hour",
     True, "BNR-0009", "inhalation", "paediatric"),
    ("MED-IPRATROPIUM", "250-500 mcg by nebulizer if no adequate response to first salbutamol",
     None, None, None, "repeat every 20 minutes (first hour only)", "first hour",
     True, "BNR-0009", "inhalation", "adult"),
    ("MED-PREDNISOLONE", "1-2 mg/kg in divided doses (max 60 mg/day)",
     "mg_per_kg", 1, 2, "once daily (or divided doses)", "3-7 days",
     True, "BNR-0009", "oral", "paediatric"),
    ("MED-PREDNISOLONE", "1-2 mg/kg in divided doses (max 60 mg/day)",
     "mg_per_kg", 1, 2, "once daily (or divided doses)", "3-7 days",
     True, "BNR-0009", "oral", "adult"),
    ("MED-EPINEPHRINE", "0.3-0.5 mg IM or SC (1:1000)",
     None, None, None, "single dose; may repeat if needed", "severe cases only",
     True, "BNR-0009", "intramuscular", "paediatric"),
    ("MED-EPINEPHRINE", "0.3-0.5 mg IM or SC (1:1000)",
     None, None, None, "single dose; may repeat if needed", "severe cases only",
     True, "BNR-0009", "intramuscular", "adult"),
    ("MED-MAGNESIUM-SULPHATE", "25-75 mg/kg IV over 20 minutes (max 2.5 g)",
     "mg_per_kg", 25, 75, "single infusion over 20 minutes", "critically ill only",
     True, "BNR-0011", "intravenous", "paediatric"),
    ("MED-MAGNESIUM-SULPHATE", "1.2-2 g IV over 20 minutes",
     None, None, None, "single infusion over 20 minutes", "critically ill only",
     True, "BNR-0011", "intravenous", "adult"),
    ("MED-AMINOPHYLLINE", "Loading 5-10 mg/kg over 1 hour, then maintenance 1 mg/kg/hour (0.7 mg/kg/hour if >10 years)",
     "mg_per_kg", 5, 10, "loading over 1 hour, then maintenance infusion",
     "while critically ill", True, "BNR-0011", "intravenous", "paediatric"),
    ("MED-AMINOPHYLLINE", "Loading 6 mg/kg over 20-30 min, then 0.5-0.9 mg/kg/hour",
     "mg_per_kg", 5, 6, "loading then maintenance infusion", "while critically ill",
     True, "BNR-0011", "intravenous", "adult"),
    ("MED-BECLOMETASONE", "Controller therapy after exacerbation - 100-200 mcg twice daily (MDI)",
     None, None, None, "twice daily (continue during and after exacerbation)",
     "ongoing controller", True, "BNR-0012", "inhalation", "paediatric"),
    ("MED-BECLOMETASONE", "Controller therapy after exacerbation - 100-200 mcg twice daily (MDI)",
     None, None, None, "twice daily (continue during and after exacerbation)",
     "ongoing controller", True, "BNR-0012", "inhalation", "adult"),
]

# medication_code -> (role, weight) for ASTHMA
MED_CONDITION = [
    ("MED-SALBUTAMOL", "treatment", 1.0),
    ("MED-IPRATROPIUM", "treatment", 0.8),
    ("MED-PREDNISOLONE", "treatment", 0.9),
    ("MED-EPINEPHRINE", "treatment", 0.6),
    ("MED-MAGNESIUM-SULPHATE", "treatment", 0.5),
    ("MED-AMINOPHYLLINE", "treatment", 0.4),
    ("MED-BECLOMETASONE", "supportive", 0.7),
]

# ---------------------------------------------------------------------------
# 2. PROT-ASTHMA-ACUTE - full 12-step pathway (population 'both')
# ---------------------------------------------------------------------------
PROTOCOL_STEPS = [
    # step_code, label, step_type, seq, instruction, rationale, required
    ("STEP-01", "Confirm acute asthma presentation", "eligibility", 10,
     "Establish recurrent/presenting wheeze, cough, dyspnoea and chest tightness with variable obstruction; elicit triggers, nocturnal symptoms and atopic history.",
     "Asthma is episodic and variable; triggers and atopy support the diagnosis.", True),
    ("STEP-02", "Assess severity immediately", "red_flag", 20,
     "Grade mild/moderate/severe by consciousness, speech (sentences/phrases/words), pulse, pulsus paradoxus, wheeze, retractions, PEF, oximetry in air and cyanosis.",
     "Severity grading drives treatment intensity and disposition (BNR-0008).", True),
    ("STEP-03", "Screen for imminent respiratory arrest", "red_flag", 30,
     "Look for drowsy/confused state, paradoxical thoracoabdominal movement, absence of wheeze, bradycardia and absent pulsus paradoxus.",
     "Respiratory muscle fatigue precedes arrest; these signs mandate immediate escalation (BNR-0010).", True),
    ("STEP-04", "Deliver emergency treatment", "treatment", 40,
     "High-flow oxygen to keep SpO2 >92%; salbutamol 2.5-5 mg nebulizer or 2-6 puffs MDI repeated up to 3 treatments in the first hour; ipratropium 125-250 mcg nebulizer if no response to first salbutamol (first hour only); oral corticosteroids 1-2 mg/kg in moderate-severe; epinephrine 0.3-0.5 mg IM/SC in severe cases.",
     "Rapid bronchodilation + corticosteroids shorten recovery and prevent recurrence (BNR-0009).", True),
    ("STEP-05", "Monitor response", "monitoring", 50,
     "Reassess at 1 hour: PEF >70% predicted/personal best, SpO2 >92% in room air for 4 hours, normal physical findings; trend pulse, respiratory effort and wheeze.",
     "Outcome at 1 hour determines discharge, admission or escalation (BNR-0009).", True),
    ("STEP-06", "Determine disposition", "disposition", 60,
     "Good outcome at 1 hour: discharge home with written action plan. Moderate-severe not improving after 1-2 hours of intensive treatment: admit. Severe respiratory distress or concern for respiratory failure/arrest: PICU.",
     "High-risk patients (previous ICU admission, 2+ hospitalisations or 3+ ED visits in past year) warrant admission (BNR-0011).", True),
    ("STEP-07", "Provide hospital care", "treatment", 70,
     "Cardio-pulmonary monitoring, oxygen, salbutamol nebulizer every 20 min then every 1-4 hours, or continuous nebulization 5-15 mg/hr; oral prednisolone 1-2 mg/kg or parenteral methylprednisolone/hydrocortisone for 3-7 days.",
     "Inpatient care delivers intensive bronchodilation and corticosteroids under observation (BNR-0011).", True),
    ("STEP-08", "Escalate for persistent severe / critical illness", "escalation", 80,
     "If persistent severe dyspnoea with high-flow oxygen requirements: IV access, electrolytes/glucose/ABG, CXR if life-threatening or suspected pneumothorax, IV maintenance fluids at 70-80% of maintenance, IV salbutamol (watch potassium + ECG), epinephrine IM/SC, magnesium sulphate 25-75 mg/kg (max 2.5 g) IV over 20 min, aminophylline, inhaled heliox, mechanical ventilation.",
     "Critically ill asthma requires intensive and multimodal therapy (BNR-0011).", True),
    ("STEP-09", "Resolve exacerbation and step down", "treatment", 90,
     "When improved: space SABA gradually to every 3-4 hours; continue steroids for the full 3-7 days; start controller therapy.",
     "Steroid taper and controller introduction prevent early relapse (BNR-0012).", True),
    ("STEP-10", "Issue written action plan", "education", 100,
     "Give the family/patient a written action plan for recognition and management of future exacerbations; for life-threatening (especially abrupt-onset) episodes consider an epinephrine autoinjector and portable oxygen at home.",
     "Every child/family with asthma should have a written action plan (BNR-0012).", True),
    ("STEP-11", "Educate on inhaler technique and triggers", "education", 110,
     "Teach spacer/MDI technique, trigger avoidance, correct use of reliever vs controller, and when to seek urgent care.",
     "Education improves adherence and reduces exacerbation risk.", True),
    ("STEP-12", "Close the care loop", "follow_up", 120,
     "Record severity, treatment given, response, discharge plan and follow-up; schedule controller review.",
     "The episode generates continuity rather than terminating at discharge.", True),
]

PROTOCOL_ACTIONS = [
    # step_code, action_type, action_code, action_name, detail, urgency, sort
    ("STEP-02", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Grade severity: >95% mild, 90-95% moderate, <90% severe", "immediate", 10),
    ("STEP-02", "monitor", "MON-PEF", "Peak expiratory flow", "Grade severity: >=70% mild, 40-69% moderate, <40% severe", "immediate", 20),
    ("STEP-02", "monitor", "MON-HR", "Heart rate monitoring", "Mild tachycardia vs marked (>180 bpm in young)", "immediate", 30),
    ("STEP-02", "monitor", "MON-WOB", "Work of breathing", "Retractions and paradoxical thoracoabdominal movement", "immediate", 40),
    ("STEP-04", "medicate", "MED-SALBUTAMOL", "Salbutamol (SABA)", "2.5-5 mg neb or 2-6 puffs MDI; repeat up to 3 treatments in 1 hr", "immediate", 10),
    ("STEP-04", "medicate", "MED-IPRATROPIUM", "Ipratropium bromide (SAMA)", "125-250 mcg neb if no response to first salbutamol", "immediate", 20),
    ("STEP-04", "medicate", "MED-PREDNISOLONE", "Prednisolone", "1-2 mg/kg in moderate-severe exacerbations", "urgent", 30),
    ("STEP-04", "medicate", "MED-EPINEPHRINE", "Epinephrine", "0.3-0.5 mg IM/SC in severe cases", "immediate", 40),
    ("STEP-05", "monitor", "MON-PEF", "Peak expiratory flow", "Target PEF >70% predicted/personal best at 1 hour", "urgent", 10),
    ("STEP-05", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Target SpO2 >92% in room air for 4 hours", "urgent", 20),
    ("STEP-07", "medicate", "MED-SALBUTAMOL", "Salbutamol (SABA)", "Nebulizer every 20 min then every 1-4 hr, or continuous 5-15 mg/hr", "urgent", 10),
    ("STEP-07", "medicate", "MED-PREDNISOLONE", "Prednisolone", "1-2 mg/kg oral or parenteral methylprednisolone/hydrocortisone, 3-7 days", "urgent", 20),
    ("STEP-08", "medicate", "MED-MAGNESIUM-SULPHATE", "Magnesium sulphate", "25-75 mg/kg IV over 20 min (max 2.5 g)", "urgent", 10),
    ("STEP-08", "medicate", "MED-AMINOPHYLLINE", "Aminophylline", "Loading 5-10 mg/kg over 1 hr, then 1 mg/kg/hr (0.7 if >10y)", "urgent", 20),
    ("STEP-08", "medicate", "MED-EPINEPHRINE", "Epinephrine", "0.3-0.5 mg IM/SC for critically ill", "urgent", 30),
    ("STEP-10", "educate", "EDU-ASTHMA-ACTION-PLAN", "Asthma written action plan", "Recognition and management of exacerbations; epinephrine autoinjector if life-threatening history", "routine", 10),
    ("STEP-11", "educate", "EDU-ASTHMA-INHALER-TECHNIQUE", "Inhaler technique", "Spacer/MDI technique and reliever vs controller use", "routine", 10),
    ("STEP-11", "educate", "EDU-ASTHMA-TRIGGERS", "Asthma triggers", "Identify and avoid individual triggers", "routine", 20),
    ("STEP-11", "educate", "EDU-ASTHMA-TEACHBACK", "Asthma teach-back", "Confirm the family/patient can demonstrate use and recognition", "routine", 30),
    ("STEP-12", "educate", "EDU-ASTHMA-CLINICIAN", "Asthma reasoning summary", "Render severity, evidence, phenotype comparison and rationale", "routine", 10),
]

PROTOCOL_MONITORING = [
    # monitoring_code, frequency, deterioration_rule, escalation_instruction
    ("MON-SPO2", "Continuous during exacerbation; target >92% in air for 4 hr before discharge",
     "SpO2 <92% or falling despite oxygen", "Escalate oxygen; reassess severity; consider PICU"),
    ("MON-PEF", "At baseline and at 1 hour after treatment",
     "PEF <40% or failing to rise to >70% by 1 hour", "Admit / escalate intensive treatment"),
    ("MON-HR", "Continuous during exacerbation",
     "Marked tachycardia (>180 bpm in young) or bradycardia", "Bradycardia in asthma signals imminent arrest - escalate immediately"),
    ("MON-WOB", "With every clinical assessment",
     "New paradoxical thoracoabdominal movement or fatigue", "Imminent respiratory failure - urgent escalation"),
]

# ---------------------------------------------------------------------------
# 3. Education objects
# ---------------------------------------------------------------------------
EDUCATION = [
    ("EDU-ASTHMA-ACTION-PLAN", "Written asthma action plan", "caregiver",
     "discharge", "A written plan for recognizing and managing asthma exacerbations: which medicines to take when symptoms worsen, when to seek urgent care, and home epinephrine/oxygen for life-threatening history (BNR-0012)."),
    ("EDU-ASTHMA-INHALER-TECHNIQUE", "Correct inhaler technique", "patient",
     "instruction", "Use a spacer with MDI: shake, insert, one puff, breathe in slowly and hold; reliever (salbutamol) for acute symptoms, controller (ICS) daily regardless of symptoms."),
    ("EDU-ASTHMA-TRIGGERS", "Asthma trigger avoidance", "patient",
     "explanation", "Identify and avoid triggers such as viral infections, allergens, exercise, cold air and smoke; keep reliever available."),
    ("EDU-ASTHMA-TEACHBACK", "Asthma teach-back", "caregiver",
     "teach_back", "Confirm the patient/family can demonstrate inhaler use and describe when to seek urgent care before discharge."),
    ("EDU-ASTHMA-CLINICIAN", "Asthma reasoning summary", "clinician",
     "explanation", "Render the acute asthma severity grade, evidence, phenotype comparison and the treatment/escalation rationale."),
]

# ---------------------------------------------------------------------------
# 4. Governance
# ---------------------------------------------------------------------------
GOVERNED_OBJECTS = [
    ("PROT-ASTHMA-ACUTE", "PROTOCOL", "Acute asthma pathway",
     "Population-aware (paediatric + adult) acute asthma exacerbation pathway: severity grading, emergency treatment, monitoring, escalation, disposition, written action plan, education.", "BNR-0009", "POP-BOTH"),
    ("MED-SALBUTAMOL", "DRUG", "Salbutamol (acute asthma)",
     "SABA bronchodilator for acute asthma exacerbation (BNR-0009).", "BNR-0009", "POP-BOTH"),
    ("MED-PREDNISOLONE", "DRUG", "Prednisolone (acute asthma)",
     "Oral corticosteroid 1-2 mg/kg for moderate-severe asthma exacerbations (BNR-0009).", "BNR-0009", "POP-BOTH"),
    ("MON-PEF", "MONITORING_RULE", "Peak expiratory flow monitoring",
     "Peak flow monitoring to grade and track asthma severity (BNR-0008).", "BNR-0008", "POP-BOTH"),
    ("DOSE-ASTHMA", "DOSING_RULE", "Acute asthma dose rules",
     "Population-aware dose rules for acute asthma bronchodilators and corticosteroids grounded to BNR-0009/0011/0012.", "BNR-0009", "POP-BOTH"),
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R5 acute asthma pathway")
    w("-- Paediatric + adult acute asthma management grounded to Baby Nelson p183-186")
    w("-- (claims BNR-0008..BNR-0012). Upgrades PROT-ASTHMA-ACUTE to a full pathway.")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r5_asthma.py <out>")
    w("-- =============================================================================")
    w("")

    # 0. claims ----------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 0. knowledge.source_claim - asthma claims (Baby Nelson p183-186)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_claim (claim_id, claim_code, source_version_id, chapter_id, chunk_id, page_start, page_end, claim_type, claim_kind, claim_text, knowledge_type, contract, confidence, status) VALUES")
    rows = []
    for i, (code, chunk, page, ctype, kind, text, ktype, contract) in enumerate(ASTHMA_CLAIMS):
        rows.append(
            f"   ({sql_literal(u('RC:' + code))}, {sql_literal(code)}, 'NELSON_ILLUSTRATED_2017', 'BN-C01', {sql_literal(chunk)}, {sql_literal(str(page))}, {sql_literal(str(page))}, {sql_literal(ctype)}, {sql_literal(kind)}, {sql_literal(text)}, {sql_literal(ktype)}, {jq(contract)}::jsonb, 0.9, 'VERIFIED')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET chunk_id = EXCLUDED.chunk_id, page_start = EXCLUDED.page_start, claim_text = EXCLUDED.claim_text, contract = EXCLUDED.contract;")
    w("")

    # 1. medications + concepts + doses ------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. medication concepts + knowledge.medication - asthma armamentarium")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES")
    rows = []
    for code, name, _cls, _routes, _forms in NEW_MEDS:
        rows.append(
            f"   ({sql_literal(u('CONCEPT:' + code))}, {sql_literal('CNS-' + code)}, 'medication', {sql_literal(name)}, {sql_literal(name)}, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (concept_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name;")
    w("")
    w("INSERT INTO knowledge.medication (id, concept_id, medication_code, generic_name, drug_class, route_options, formulations, contraindications, evidence_source, status) VALUES")
    rows = []
    for code, name, cls, routes, forms in NEW_MEDS:
        rows.append(
            f"   ({sql_literal(u('MED:' + code))}, {sql_literal(u('CONCEPT:' + code))}, {sql_literal(code)}, {sql_literal(name)}, {sql_literal(cls)}, "
            f"{sql_literal(routes)}::jsonb, {sql_literal(forms)}::jsonb, '[\"serious immediate allergy to this class\"]'::jsonb, "
            f"'Illustrated Baby Nelson p183-186 (BNR-0009/0011/0012) - verify against local formulary.', 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (medication_code) DO UPDATE SET generic_name = EXCLUDED.generic_name, drug_class = EXCLUDED.drug_class;")
    w("")

    # 1b. PEF monitoring ---------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1b. knowledge.monitoring - MON-PEF (peak expiratory flow)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES")
    w(f"   ({sql_literal(u('CONCEPT:PEF'))}, 'CNS-PEF', 'monitoring', 'Peak expiratory flow', 'Peak expiratory flow', 'active')")
    w("ON CONFLICT (concept_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name;")
    w("")
    w("INSERT INTO knowledge.monitoring (id, concept_id, monitoring_code, canonical_name, description, target_type, unit, body_system_code, normal_low, normal_high, status) VALUES")
    w(f"   ({sql_literal(u('MON:PEF'))}, (SELECT id FROM knowledge.concept WHERE concept_code = 'CNS-PEF'), 'MON-PEF', 'Peak expiratory flow', 'Peak expiratory flow rate - grades asthma severity (>=70% mild, 40-69% moderate, <40% severe) and tracks response.', 'numeric', '% predicted', 'RESPIRATORY', NULL, NULL, 'active')")
    w("ON CONFLICT (monitoring_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, description = EXCLUDED.description;")
    w("")

    # 1c. dose references ---------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1c. knowledge.drug_dose_reference - acute asthma doses (both populations)")
    w("-- ---------------------------------------------------------------------------")
    for code, dose_expr, basis, kg_min, kg_max, freq, dur, verified, claim, route, pop in ASTHMA_DOSES:
        basis_sql = sql_literal(basis) if basis else "NULL"
        kgmin_sql = str(kg_min) if kg_min is not None else "NULL"
        kgmax_sql = str(kg_max) if kg_max is not None else "NULL"
        w(f"INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max) VALUES")
        w(f"   ({sql_literal(u('DOSE:' + code + ':ASTHMA:' + pop))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(code)}), {sql_literal(pop)}, 'ASTHMA', {sql_literal(route)}, {sql_literal(dose_expr)}, {sql_literal(freq)}, {sql_literal(dur)}, 'Illustrated Baby Nelson p183-186 ({claim})', {('TRUE' if verified else 'FALSE')}, {basis_sql}, {kgmin_sql}, {kgmax_sql})")
        w(f"ON CONFLICT (medication_id, population, indication_code, route) DO UPDATE SET")
        w(f"    dose_expression = EXCLUDED.dose_expression, frequency_expression = EXCLUDED.frequency_expression,")
        w(f"    duration_expression = EXCLUDED.duration_expression, weight_basis = EXCLUDED.weight_basis,")
        w(f"    dose_per_kg_min = EXCLUDED.dose_per_kg_min, dose_per_kg_max = EXCLUDED.dose_per_kg_max,")
        w(f"    is_verified = EXCLUDED.is_verified, evidence_source = EXCLUDED.evidence_source;")
        w(p("drug_dose_reference", u("DOSE:" + code + ":ASTHMA:" + pop), "DOSE:" + code, claim))
        w("")

    # 1d. medication_condition ---------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1d. knowledge.medication_condition - asthma treatment links")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.medication_condition (id, medication_id, condition_id, role, weight) VALUES")
    rows = [
        f"   ({sql_literal(u('MC:' + code + ':ASTHMA:' + role))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(code)}), (SELECT id FROM knowledge.condition WHERE condition_code = 'ASTHMA'), {sql_literal(role)}, {sql_literal(f'{wt:.2f}')})"
        for code, role, wt in MED_CONDITION
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (medication_id, condition_id, role) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 2. protocol ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2. PROT-ASTHMA-ACUTE - full 12-step pathway (population 'both')")
    w("-- ---------------------------------------------------------------------------")
    w("UPDATE knowledge.protocol SET canonical_name = 'Acute asthma pathway', population = 'both', status = 'active',")
    w("       description = 'Population-aware acute asthma exacerbation pathway: severity grading, emergency treatment, monitoring, escalation, disposition, written action plan, education.',")
    w("       source_reference = 'Illustrated Baby Nelson p183-186 (BNR-0008..0012)' WHERE protocol_code = 'PROT-ASTHMA-ACUTE';")
    w("")
    w("INSERT INTO knowledge.protocol_condition (id, protocol_id, condition_id, is_primary) VALUES")
    w(f"   ({sql_literal(u('PC:ASTHMA:PROT-ASTHMA-ACUTE'))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-ASTHMA-ACUTE'), (SELECT id FROM knowledge.condition WHERE condition_code = 'ASTHMA'), true)")
    w("ON CONFLICT (protocol_id, condition_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;")
    w("")
    w("INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required) VALUES")
    rows = [
        f"   ({sql_literal(u('PSTEP:ASTHMA:' + sc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-ASTHMA-ACUTE'), {sql_literal(sc)}, {sql_literal(label)}, {sql_literal(stype)}, {sql_literal(str(seq))}, {sql_literal(instr)}, {sql_literal(rat)}, {('TRUE' if req else 'FALSE')})"
        for sc, label, stype, seq, instr, rat, req in PROTOCOL_STEPS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, step_code) DO UPDATE SET instruction = EXCLUDED.instruction, rationale = EXCLUDED.rationale, sequence_no = EXCLUDED.sequence_no, step_type = EXCLUDED.step_type;")
    w("")
    w("INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order) VALUES")
    rows = [
        f"   ({sql_literal(u('PACT:ASTHMA:' + sc + ':' + ac + ':' + str(so)))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-ASTHMA-ACUTE'), (SELECT ps.id FROM knowledge.protocol_step ps JOIN knowledge.protocol p ON p.id = ps.protocol_id WHERE p.protocol_code = 'PROT-ASTHMA-ACUTE' AND ps.step_code = {sql_literal(sc)}), {sql_literal(at)}, {sql_literal(ac)}, {sql_literal(an)}, {sql_literal(detail)}, {sql_literal(urg)}, {sql_literal(str(so))})"
        for sc, at, ac, an, detail, urg, so in PROTOCOL_ACTIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (step_id, action_type, action_code) DO UPDATE SET detail = EXCLUDED.detail, sort_order = EXCLUDED.sort_order;")
    w("")
    w("INSERT INTO knowledge.protocol_monitoring (id, protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES")
    rows = [
        f"   ({sql_literal(u('PMON:ASTHMA:' + mc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-ASTHMA-ACUTE'), (SELECT id FROM knowledge.monitoring WHERE monitoring_code = {sql_literal(mc)}), {sql_literal(freq)}, {sql_literal(det)}, {sql_literal(esc)})"
        for mc, freq, det, esc in PROTOCOL_MONITORING
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, monitoring_id) DO UPDATE SET frequency = EXCLUDED.frequency, deterioration_rule = EXCLUDED.deterioration_rule, escalation_instruction = EXCLUDED.escalation_instruction;")
    w("")

    # 3. education ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. knowledge.education - asthma education objects")
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
        rows.append(
            f"   ({sql_literal(u('EDC:' + code + ':ASTHMA'))}, (SELECT id FROM knowledge.education WHERE education_code = {sql_literal(code)}), (SELECT id FROM knowledge.condition WHERE condition_code = 'ASTHMA'), 1.0)"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (education_id, condition_id) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 4. governance + provenance --------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. governance.knowledge_object - asthma pathway objects")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO governance.population_context (id, population_code, name, description, applies_to_context_codes, is_active) VALUES")
    w(f"   ({sql_literal(u('POP:BOTH'))}, 'POP-BOTH', 'Both paediatric and adult', 'Protocols and knowledge objects that apply to paediatric and adult populations alike (e.g. acute asthma pathway).', ARRAY['inpatient','outpatient','emergency'], true)")
    w("ON CONFLICT (population_code) DO UPDATE SET description = EXCLUDED.description;")
    w("")
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
    w("SELECT ko.id, 1, 'GO-V-R5-' || ko.object_code, 'R5 acute asthma pathway release (BNR-0008..0012).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'")
    w("FROM governance.knowledge_object ko WHERE ko.object_code IN (" + ", ".join(sql_literal(x[0]) for x in GOVERNED_OBJECTS) + ")")
    w("ON CONFLICT (version_code) DO UPDATE SET change_note = EXCLUDED.change_note, lifecycle_status = EXCLUDED.lifecycle_status;")
    w("")
    for code, _ktype, _name, _desc, claim, _pop in GOVERNED_OBJECTS:
        w(p("governance.knowledge_object", u("GOBJ:" + code), code, claim))
    w("")

    # 5. master matrix ----------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 5. tracking.respiratory_master_matrix - asthma status")
    w("-- ---------------------------------------------------------------------------")
    w("UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Baby Nelson p183-186 (BNR-0008..0012)',")
    w("       notes='Acute asthma pathway (both populations): severity grid, emergency treatment, monitoring, escalation, disposition, written action plan, education.',")
    w("       updated_at=now() WHERE item_code='COND-ASTHMA';")
    w("UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Baby Nelson p183-186 (BNR-0008..0012)',")
    w("       notes='Paediatric acute asthma: severity grading, SABA/ipratropium/corticosteroids, PICU escalation, written action plan.',")
    w("       updated_at=now() WHERE item_code='COND-ASTHMA-PAED';")
    w("UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Baby Nelson p183 (BNR-0008/0010)',")
    w("       notes='Severity grid + imminent-arrest signs + critical-care escalation covered by the asthma pathway.',")
    w("       updated_at=now() WHERE item_code='COND-ACUTE-SEVERE-ASTHMA';")
    w("UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Baby Nelson p183-186 (BNR-0009/0012)',")
    w("       notes='SABA (salbutamol), SAMA (ipratropium), oral corticosteroids, epinephrine, magnesium, aminophylline, ICS controller dose rules.',")
    w("       updated_at=now() WHERE item_code='DRUG-BRONCHODILATOR';")
    w("UPDATE tracking.respiratory_master_matrix SET status='SEEDED', source_ground='Baby Nelson p174 (asthma vs bronchiolitis differential)',")
    w("       notes='Wheeze recognized (WHEEZE_PRESENT, COUGH_TRIGGERS); episodic/trigger/nocturnal graph not yet structured.',")
    w("       updated_at=now() WHERE item_code='SYM-WHEEZE';")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(ASTHMA_CLAIMS)} claims, {len(NEW_MEDS)} medications, {len(ASTHMA_DOSES)} dose rows, {len(PROTOCOL_STEPS)} steps, {len(PROTOCOL_ACTIONS)} actions, {len(GOVERNED_OBJECTS)} governed objects")


if __name__ == "__main__":
    main(sys.argv[1])