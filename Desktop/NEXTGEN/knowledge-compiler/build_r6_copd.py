"""AMEXAN Medical Knowledge Compiler - R6 COPD pathway (adult).

Completes the chronic-obstructive family slice grounded to Kumar & Clark 10e
p955-960 (definition, GOLD severity classification, exacerbation algorithm,
LTOT/NIV, BODE prognosis):

  - claims KCR-0013..KCR-0018
  - conditions COND-COPD (chronic) + COND-COPD-EXACERBATION (acute)
  - facts FEV1_PERCENT (numeric), PURSED_LIPS (coded)
  - SCORE-GOLD severity instrument (GOLD 1-4 by FEV1% with and/not conditions)
  - medications: tiotropium (LAMA), salmeterol (LABA), roflumilast (PDE4),
    carbocysteine (mucolytic) + COPD dose rows reusing salbutamol/ipratropium/
    prednisolone/azithromycin
  - investigations INV-SPIROMETRY, INV-ABG
  - PROT-COPD-EXACERBATION full 12-step pathway (adult)
  - education EDU-COPD-*
  - governance + provenance + master matrix

Run:  python build_r6_copd.py <out.sql>
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
# 0. Claims - Kumar & Clark p955-960 (COPD)
# ---------------------------------------------------------------------------
COPD_CLAIMS = [
    ("KCR-0013", 955, "RESPIRATORY_METHOD", "threshold",
     "COPD is airflow limitation that is not fully reversible, usually progressive, and associated with an abnormal inflammatory response of the lungs to noxious particles or gases. It brings together emphysema, small airways disease and chronic bronchitis. Chronic bronchitis is classically a daily productive cough for 3 months per year for 2 consecutive years. Cigarette smoking accounts for over 90% of cases in developed countries; in developing countries, smoke from biomass heating fuels and cooking in poorly ventilated areas is implicated.",
     {"what_is_it": "COPD definition + chronic bronchitis + aetiology", "what_fact_produces": "COUGH_DURATION_DAYS, SMOKING_STATUS, SMOKING_PACK_YEARS, BIOMASS_EXPOSURE", "source_support": "Kumar & Clark 10e p955"}),
    ("KCR-0014", 956, "RESPIRATORY_METHOD", "rule",
     "Characteristic symptoms of COPD: productive cough with white or clear sputum, wheeze and breathlessness; patients are prone to lower respiratory tract infections. Systemic effects include hypertension, osteoporosis, depression, weight loss, reduced muscle mass, weakness and right heart failure. In severe disease the patient is tachypnoeic with prolonged expiration, uses accessory muscles, may have intercostal indrawing and pursing of the lips on expiration; chest expansion is poor, lungs hyperinflated, cricosternal distance reduced, with loss of normal cardiac and liver dullness. Hypercapnia causes peripheral vasodilation, bounding pulse, coarse flapping tremor, confusion and progressive drowsiness.",
     {"what_is_it": "COPD clinical features + signs", "what_fact_produces": "PURSED_LIPS, COUGH_PRODUCTIVITY, DYSPNOEA_PRESENT, RESP_RATE", "source_support": "Kumar & Clark 10e p956"}),
    ("KCR-0015", 957, "RESPIRATORY_METHOD", "investigation",
     "COPD diagnosis is usually clinical: history of breathlessness and sputum production in a chronic smoker. Spirometry shows airflow limitation (FEV1:FVC reduced, PEFR low; usually <15% reversibility). CXR is often normal even when advanced, but classic features are over-inflation with low flat diaphragms and sometimes bullae with pruned vessels. Hb and packed cell volume may be elevated from persistent hypoxaemia (secondary polycythaemia). Blood gases determine respiratory failure. Sputum may grow Strep. pneumoniae, H. influenzae and Moraxella catarrhalis. ECG may show P pulmonale, RBBB and right ventricular hypertrophy. Measure alpha1-antitrypsin in premature disease or lifelong non-smokers.",
     {"what_is_it": "COPD diagnosis + investigations", "what_connects_to": "INV-SPIROMETRY, INV-ABG, INV-CXR, INV-FBC", "source_support": "Kumar & Clark 10e p957"}),
    ("KCR-0016", 957, "RESPIRATORY_METHOD", "threshold",
     "COPD airflow limitation severity (post-bronchodilator FEV1 in patients with FEV1/FVC <0.70): GOLD 1 Mild FEV1 >=80% predicted; GOLD 2 Moderate 50% <= FEV1 <80%; GOLD 3 Severe 30% <= FEV1 <50%; GOLD 4 Very severe FEV1 <30% predicted.",
     {"what_is_it": "GOLD severity classification", "what_fact_produces": "FEV1_PERCENT, FEV1_FVC_RATIO", "source_support": "Kumar & Clark 10e p957 (GOLD 2016)"}),
    ("KCR-0017", 957, "RESPIRATORY_METHOD", "management",
     "COPD management: smoking cessation is the single most useful measure. Drug therapy: mild COPD responds to inhaled short-acting beta-2 agonist (salbutamol 200 mcg every 4-6 h); moderate/severe uses a long-acting beta-2 agonist; a regular LAMA (tiotropium) improves lung function, dyspnoea and quality of life; inhaled corticosteroids are recommended with frequent exacerbations or FEV1 <50% predicted (high-dose ICS not advised - pneumonia risk); oral corticosteroids in acute exacerbation. Prompt antibiotics shorten exacerbations and should always be given in acute episodes; home antibiotics when sputum turns yellow/green; long-term azithromycin reduces exacerbations. Mucolytics (carbocysteine) reduce sputum viscosity and exacerbations. LTOT (>=15-19 h/day) improves survival when PaO2 <7.3 kPa on air on two occasions, or PaO2 <8 kPa with secondary polycythaemia, nocturnal hypoxaemia, peripheral oedema or pulmonary hypertension. Pulmonary rehabilitation improves fatigue, dyspnoea and exercise tolerance. Pneumococcal polysaccharide vaccine once + annual influenza vaccination.",
     {"what_is_it": "COPD drug + non-drug management", "what_connects_to": "medications, LTOT, rehabilitation, vaccination", "source_support": "Kumar & Clark 10e p957-958"}),
    ("KCR-0018", 959, "RESPIRATORY_METHOD", "management",
     "Acute COPD exacerbation may be precipitated by viral or bacterial infection with cough, acute bronchospasm and dyspnoea, and Type I or Type II respiratory failure. Management: assess airway, breathing and circulation; controlled oxygen via Venturi mask (initially 24%, target saturation 88-92% for those at risk of hypercapnia) with close ABG monitoring; corticosteroids, antibiotics and bronchodilators (nebulized salbutamol and ipratropium) in the acute phase; chest physiotherapy to clear retained secretions. If respiratory acidosis persists (pH <7.35 with elevated PaCO2), consider non-invasive ventilation - NIV reduces the need for intubation and lowers mortality. CXR excludes pneumothorax (chest drain) or pneumonia (antibiotics).",
     {"what_is_it": "acute COPD exacerbation management algorithm", "what_connects_to": "protocol step (acute COPD)", "source_support": "Kumar & Clark 10e p959-960"}),
]

# ---------------------------------------------------------------------------
# 1. Conditions
# ---------------------------------------------------------------------------
# condition_code, type, name, description, population (differential links via phenotypes)
CONDITIONS = [
    ("COND-COPD", "chronic", "COPD (chronic obstructive pulmonary disease)",
     "Chronic airflow limitation that is not fully reversible, encompassing emphysema, small airways disease and chronic bronchitis; caused by long-term exposure to toxic particles (smoking, biomass smoke)."),
    ("COND-COPD-EXACERBATION", "acute", "COPD exacerbation",
     "Acute worsening of COPD with increased dyspnoea, cough and sputum, precipitated by viral or bacterial infection; may cause Type I or Type II respiratory failure."),
]

# phenotype_code -> condition_code, weight (differential links)
PHEN_DIFFERENTIAL = [
    ("PHEN-CHRONIC-PRODUCTIVE", "COND-COPD", 0.80),
    ("PHEN-AIRWAY-WHEEZE", "COND-COPD", 0.60),
    ("PHEN-HYPOXAEMIA", "COND-COPD-EXACERBATION", 0.70),
    ("PHEN-RESPIRATORY-FAILURE", "COND-COPD-EXACERBATION", 0.80),
    ("PHEN-ACUTE-LRTI", "COND-COPD-EXACERBATION", 0.40),
]

# ---------------------------------------------------------------------------
# 2. Facts + score
# ---------------------------------------------------------------------------
NEW_FACTS = [
    ("FEV1_PERCENT", "numeric", "Forced expiratory volume in 1 second (% predicted) - GOLD severity grade"),
    ("PURSED_LIPS", "coded", "Pursing of the lips on expiration - sign of severe COPD / emphysema"),
]

# SCORE-GOLD: mutually-exclusive grades; each grade is a component whose
# condition gates the FEV1/FVC <0.70 precondition, so at most one matches.
GOLD_COMPONENTS = [
    # component_code, name, condition, points, rationale
    ("GOLD-1", "GOLD 1 - Mild (FEV1 >=80% predicted)",
     {"type": "and", "conditions": [
         {"type": "numeric_lt", "fact_code": "FEV1_FVC_RATIO", "threshold": 0.7},
         {"type": "numeric_gte", "fact_code": "FEV1_PERCENT", "threshold": 80},
     ]}, 1, "Post-bronchodilator FEV1 >=80% predicted with FEV1/FVC <0.70 (KCR-0016)."),
    ("GOLD-2", "GOLD 2 - Moderate (50% <= FEV1 <80%)",
     {"type": "and", "conditions": [
         {"type": "numeric_lt", "fact_code": "FEV1_FVC_RATIO", "threshold": 0.7},
         {"type": "numeric_gte", "fact_code": "FEV1_PERCENT", "threshold": 50},
         {"type": "numeric_lt", "fact_code": "FEV1_PERCENT", "threshold": 80},
     ]}, 2, "Post-bronchodilator FEV1 50-79% predicted with FEV1/FVC <0.70 (KCR-0016)."),
    ("GOLD-3", "GOLD 3 - Severe (30% <= FEV1 <50%)",
     {"type": "and", "conditions": [
         {"type": "numeric_lt", "fact_code": "FEV1_FVC_RATIO", "threshold": 0.7},
         {"type": "numeric_gte", "fact_code": "FEV1_PERCENT", "threshold": 30},
         {"type": "numeric_lt", "fact_code": "FEV1_PERCENT", "threshold": 50},
     ]}, 3, "Post-bronchodilator FEV1 30-49% predicted with FEV1/FVC <0.70 (KCR-0016)."),
    ("GOLD-4", "GOLD 4 - Very severe (FEV1 <30%)",
     {"type": "and", "conditions": [
         {"type": "numeric_lt", "fact_code": "FEV1_FVC_RATIO", "threshold": 0.7},
         {"type": "numeric_lt", "fact_code": "FEV1_PERCENT", "threshold": 30},
     ]}, 4, "Post-bronchodilator FEV1 <30% predicted with FEV1/FVC <0.70 (KCR-0016)."),
]

GOLD_INTERPRETATIONS = [
    (1, 1, "GOLD 1 - Mild", "Outpatient", "Post-bronchodilator FEV1 >=80% predicted; short-acting bronchodilator for symptoms; annual influenza + single pneumococcal vaccine."),
    (2, 2, "GOLD 2 - Moderate", "Outpatient", "Post-bronchodilator FEV1 50-79%; add LABA/LAMA; consider ICS if frequent exacerbations or blood eosinophilia."),
    (3, 3, "GOLD 3 - Severe", "Outpatient", "Post-bronchodilator FEV1 30-49%; LABA + LAMA; ICS for exacerbations; pulmonary rehabilitation."),
    (4, 4, "GOLD 4 - Very severe", "Refer", "Post-bronchodilator FEV1 <30%; assess LTOT, pulmonary rehabilitation, surgical/transplant options; screen for respiratory failure."),
]

# ---------------------------------------------------------------------------
# 3. Medications + dose rows
# ---------------------------------------------------------------------------
NEW_MEDS = [
    ("MED-TIOTROPIUM", "Tiotropium bromide", "Long-acting muscarinic antagonist (LAMA)",
     '["inhalation"]', '["dry powder inhaler 18 mcg"]'),
    ("MED-SALMETEROL", "Salmeterol", "Long-acting beta-2 agonist (LABA)",
     '["inhalation"]', '["MDI 25 mcg/puff"]'),
    ("MED-ROFLUMILAST", "Roflumilast", "Phosphodiesterase type 4 (PDE4) inhibitor",
     '["oral"]', '["tablet 500 mcg"]'),
    ("MED-CARBOCYSTEINE", "Carbocysteine", "Mucolytic",
     '["oral"]', '["capsule 375 mg","suspension 250 mg/5ml"]'),
]

# reuse: MED-SALBUTAMOL, MED-IPRATROPIUM, MED-PREDNISOLONE, MED-AZITHROMYCIN
# (medication_code, dose_expression, weight_basis, per_kg_min, per_kg_max,
#  frequency, duration, is_verified, claim, route, population, indication)
COPD_DOSES = [
    ("MED-SALBUTAMOL", "200 mcg by inhaler for acute symptom relief (mild COPD); in exacerbation 2.5-5 mg by nebulizer",
     None, None, None, "every 4-6 h as needed (exacerbation: up to 3 nebulizations in first hour)",
     "during exacerbation", True, "KCR-0017", "inhalation", "adult", "COND-COPD"),
    ("MED-SALBUTAMOL", "2.5-5 mg by nebulizer during acute exacerbation",
     None, None, None, "up to 3 treatments in 1 hour, then as needed", "during exacerbation",
     True, "KCR-0018", "inhalation", "adult", "COND-COPD-EXACERBATION"),
    ("MED-IPRATROPIUM", "250-500 mcg by nebulizer during acute exacerbation",
     None, None, None, "every 20 min in first hour, then as needed", "during exacerbation",
     True, "KCR-0018", "inhalation", "adult", "COND-COPD-EXACERBATION"),
    ("MED-PREDNISOLONE", "30-40 mg oral once daily",
     None, None, None, "once daily", "7-14 days (short course)", True, "KCR-0017",
     "oral", "adult", "COND-COPD-EXACERBATION"),
    ("MED-TIOTROPIUM", "18 mcg inhaled once daily (LAMA)",
     None, None, None, "once daily", "ongoing", True, "KCR-0017", "inhalation", "adult", "COND-COPD"),
    ("MED-SALMETEROL", "50 mcg inhaled twice daily (LABA)",
     None, None, None, "twice daily", "ongoing", True, "KCR-0017", "inhalation", "adult", "COND-COPD"),
    ("MED-ROFLUMILAST", "500 mcg oral once daily (PDE4 inhibitor, FEV1 <50% + chronic bronchitis)",
     None, None, None, "once daily", "ongoing", True, "KCR-0017", "oral", "adult", "COND-COPD"),
    ("MED-CARBOCYSTEINE", "750 mg oral three times daily (mucolytic)",
     None, None, None, "three times daily", "during exacerbations / as maintenance",
     True, "KCR-0017", "oral", "adult", "COND-COPD"),
    ("MED-AZITHROMYCIN", "Long-term macrolide 250-500 mg to reduce frequent exacerbations",
     None, None, None, "250 mg daily or 500 mg three times weekly", "ongoing for frequent exacerbations",
     True, "KCR-0017", "oral", "adult", "COND-COPD"),
]

# medication_code -> (role, weight) for each condition
MED_CONDITION = [
    ("COND-COPD", [
        ("MED-SALBUTAMOL", "treatment", 0.9),
        ("MED-TIOTROPIUM", "treatment", 0.9),
        ("MED-SALMETEROL", "treatment", 0.8),
        ("MED-ROFLUMILAST", "treatment", 0.5),
        ("MED-CARBOCYSTEINE", "supportive", 0.6),
        ("MED-AZITHROMYCIN", "treatment", 0.5),
    ]),
    ("COND-COPD-EXACERBATION", [
        ("MED-SALBUTAMOL", "treatment", 1.0),
        ("MED-IPRATROPIUM", "treatment", 0.9),
        ("MED-PREDNISOLONE", "treatment", 0.9),
    ]),
]

# ---------------------------------------------------------------------------
# 4. Investigations
# ---------------------------------------------------------------------------
NEW_INVESTIGATIONS = [
    ("INV-SPIROMETRY", "Spirometry (lung function tests)", "physiological", "RESPIRATORY",
     "Measures FEV1, FVC and PEFR to confirm airflow limitation and grade GOLD severity."),
    ("INV-ABG", "Arterial blood gas", "laboratory", "RESPIRATORY",
     "Determines PaO2, PaCO2 and pH to classify Type I/II respiratory failure and guide controlled oxygen / NIV."),
]

# ---------------------------------------------------------------------------
# 5. Protocol - PROT-COPD-EXACERBATION (adult, 12 steps)
# ---------------------------------------------------------------------------
PROTOCOL_STEPS = [
    ("STEP-01", "Confirm acute COPD exacerbation", "eligibility", 10,
     "Confirm known COPD with an acute, sustained worsening of dyspnoea, cough or sputum beyond day-to-day variation.",
     "Exacerbation is precipitated by viral/bacterial infection and may progress to respiratory failure (KCR-0018).", True),
    ("STEP-02", "Assess airway, breathing and circulation", "red_flag", 20,
     "Rapid ABC assessment; detect severe distress, confusion, drowsiness, bounding pulse or flapping tremor (hypercapnia), cyanosis or cardiorespiratory arrest.",
     "Airway compromise and cardiorespiratory arrest require immediate resuscitation (KCR-0018).", True),
    ("STEP-03", "Deliver controlled oxygen therapy", "treatment", 30,
     "For those at risk of hypercapnic failure use a Venturi mask (start 24%, titrate) to maintain target saturation 88-92%; monitor closely.",
     "Excess oxygen in Type II failure suppresses hypoxic drive and raises PaCO2 (KCR-0018).", True),
    ("STEP-04", "Obtain arterial blood gas", "investigation", 40,
     "Measure ABG to classify Type I (PaO2 <8 kPa, normal/low PaCO2) vs Type II (PaO2 <8 kPa, PaCO2 >6.5 kPa) respiratory failure; check pH.",
     "Respiratory acidosis (pH <7.35 with raised PaCO2) despite medical management triggers NIV consideration (KCR-0018).", True),
    ("STEP-05", "Start bronchodilators + corticosteroids + antibiotics", "treatment", 50,
     "Nebulized salbutamol and ipratropium; oral prednisolone 30-40 mg; prompt antibiotics (shorten exacerbation, prevent admission); home antibiotics when sputum turns yellow/green.",
     "Triple therapy in the acute phase shortens the exacerbation; ICS long-term decisions wait until recovery (KCR-0017/0018).", True),
    ("STEP-06", "Clear retained secretions", "treatment", 60,
     "Encourage effective cough; chest physiotherapy when clearing secretions is difficult.",
     "Retained secretions worsen obstruction and gas exchange (KCR-0018).", True),
    ("STEP-07", "Image the chest", "investigation", 70,
     "CXR to exclude pneumothorax (chest drain; CT guidance if complex bullous disease) and pneumonia (antibiotics).",
     "Pneumothorax and pneumonia are treatable precipitants of deterioration (KCR-0018).", True),
    ("STEP-08", "Re-assess and repeat ABG", "monitoring", 80,
     "Repeat ABG at 30-60 min (or on increasing oxygen requirements/breathlessness); keep target saturation 88-92%.",
     "Trends in pH/PaCO2 determine escalation to NIV (KCR-0018).", True),
    ("STEP-09", "Consider non-invasive ventilation", "escalation", 90,
     "If persistent respiratory acidosis (pH <7.35 with PaCO2 >6.5 kPa) despite medical management and clinically appropriate: start NIV; refer to senior; review and discuss ceiling of care.",
     "NIV reduces the need for intubation and lowers mortality in decompensated Type II failure (KCR-0018).", True),
    ("STEP-10", "Escalate to critical care if deteriorating", "escalation", 100,
     "If deterioration despite NIV and clinically appropriate: consider invasive ventilation; reassess ceiling of care.",
     "Invasive ventilation is used only with a clear precipitating factor and reasonable overall prognosis (KCR-0018).", True),
    ("STEP-11", "Plan discharge and prevention", "education", 110,
     "Smoking cessation (single most useful measure); pneumococcal vaccine + annual influenza; pulmonary rehabilitation; assess LTOT if PaO2 <7.3 kPa (or <8 kPa with polycythaemia/nocturnal hypoxaemia/oedema/pulmonary hypertension).",
     "Prevention and rehabilitation improve outcomes and reduce exacerbation frequency (KCR-0017/0018).", True),
    ("STEP-12", "Close the care loop", "follow_up", 120,
     "Grade GOLD severity (FEV1/FVC <0.70; FEV1 % predicted), document treatment, response, LTOT/referral plan and follow-up; consider BODE for prognosis.",
     "COPD is chronic: the exacerbation episode feeds into ongoing maintenance and surveillance (KCR-0015/0016).", True),
]

PROTOCOL_ACTIONS = [
    # step, type, code, name, detail, urgency, sort
    ("STEP-01", "score", "SCORE-GOLD", "GOLD severity grade", "Grade airflow limitation by post-bronchodilator FEV1 (% predicted) with FEV1/FVC <0.70", "routine", 10),
    ("STEP-02", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Target 88-92% for hypercapnia risk", "immediate", 10),
    ("STEP-02", "monitor", "MON-RR", "Respiratory rate monitoring", "Tachypnoea and work of breathing", "immediate", 20),
    ("STEP-03", "advice", "ADV-COPD-TARGETED-O2", "Controlled oxygen (target 88-92%)", "Venturi mask, start 24%, titrate to target SpO2 88-92%; avoid excess oxygen (hypercapnia risk)", "immediate", 10),
    ("STEP-04", "investigate", "INV-ABG", "Arterial blood gas", "Classify Type I/II respiratory failure; pH trend", "urgent", 10),
    ("STEP-05", "medicate", "MED-SALBUTAMOL", "Salbutamol (SABA)", "Nebulizer 2.5-5 mg in exacerbation", "immediate", 10),
    ("STEP-05", "medicate", "MED-IPRATROPIUM", "Ipratropium (SAMA)", "Nebulizer 250-500 mcg in exacerbation", "immediate", 20),
    ("STEP-05", "medicate", "MED-PREDNISOLONE", "Prednisolone", "30-40 mg oral once daily 7-14 days", "urgent", 30),
    ("STEP-05", "medicate", "MED-AMOXICILLIN", "Antibiotic (amoxicillin)", "Prompt antibiotics for acute episode; home antibiotics when sputum turns yellow/green", "urgent", 40),
    ("STEP-06", "advice", "ADV-COPD-CLEARANCE", "Secretions clearance", "Effective cough + chest physiotherapy", "urgent", 10),
    ("STEP-07", "investigate", "INV-CXR", "Chest X-ray", "Exclude pneumothorax and pneumonia", "urgent", 10),
    ("STEP-08", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Maintain target 88-92%; repeat ABG at 30-60 min", "urgent", 10),
    ("STEP-08", "investigate", "INV-ABG", "Arterial blood gas (repeat)", "Repeat 30-60 min or on deterioration", "urgent", 20),
    ("STEP-09", "refer", "REF-NIV", "Non-invasive ventilation", "pH <7.35 with PaCO2 >6.5 kPa despite medical management", "immediate", 10),
    ("STEP-09", "advice", "ADV-COPD-CEILING", "Ceiling of care discussion", "Review and discuss ceiling of care", "urgent", 20),
    ("STEP-10", "refer", "REF-CRITICAL-CARE", "Critical care referral", "Invasive ventilation if deterioration despite NIV + appropriate", "immediate", 10),
    ("STEP-11", "educate", "EDU-COPD-SMOKING-CESSATION", "Smoking cessation", "Single most useful measure; includes biomass smoke reduction", "routine", 10),
    ("STEP-11", "educate", "EDU-COPD-PULMONARY-REHAB", "Pulmonary rehabilitation", "Improves dyspnoea, fatigue and exercise tolerance", "routine", 20),
    ("STEP-11", "educate", "EDU-COPD-VACCINES", "Pneumococcal + influenza vaccination", "Single pneumococcal vaccine + annual influenza", "routine", 30),
    ("STEP-11", "educate", "EDU-COPD-LTOT", "Long-term oxygen therapy", "Assess if PaO2 <7.3 kPa on air (or <8 kPa with polycythaemia/nocturnal hypoxaemia/oedema/pulmonary hypertension); 15-19 h/day", "routine", 40),
    ("STEP-12", "educate", "EDU-COPD-CLINICIAN", "COPD reasoning summary", "Render GOLD grade, evidence, treatment/escalation rationale", "routine", 10),
]

PROTOCOL_MONITORING = [
    ("MON-SPO2", "Continuous during exacerbation; target 88-92% if hypercapnia risk (Venturi)",
     "SpO2 <88% despite oxygen, or oversaturation >92% with rising PaCO2",
     "Check ABG; adjust oxygen; escalate to NIV if respiratory acidosis"),
    ("MON-RR", "Continuous during exacerbation",
     "Persistent tachypnoea or rising work of breathing",
     "Reassess severity; consider ABG; escalate"),
]

# ---------------------------------------------------------------------------
# 6. Education
# ---------------------------------------------------------------------------
EDUCATION = [
    ("EDU-COPD-SMOKING-CESSATION", "Smoking cessation for COPD", "patient",
     "instruction", "Smoking cessation is the single most useful measure in COPD; it slows deterioration. Reduce biomass smoke in the home. Seek support, nicotine replacement and follow-up (KCR-0017)."),
    ("EDU-COPD-PULMONARY-REHAB", "Pulmonary rehabilitation", "patient",
     "explanation", "Structured exercise and education improve fatigue, dyspnoea and exercise tolerance in COPD (KCR-0017)."),
    ("EDU-COPD-VACCINES", "Vaccination for COPD", "patient",
     "instruction", "Receive a single pneumococcal polysaccharide vaccine and annual influenza vaccination (KCR-0017)."),
    ("EDU-COPD-LTOT", "Long-term oxygen therapy", "patient",
     "explanation", "If PaO2 <7.3 kPa on air (or <8 kPa with polycythaemia/nocturnal hypoxaemia/peripheral oedema/pulmonary hypertension), LTOT for 15-19 h/day improves survival (KCR-0017)."),
    ("EDU-COPD-EXACERBATION-PLAN", "COPD exacerbation action plan", "caregiver",
     "discharge", "Start home antibiotics when sputum turns yellow or green; seek urgent care for increased breathlessness, confusion or drowsiness; keep short-acting bronchodilators available (KCR-0017/0018)."),
    ("EDU-COPD-CLINICIAN", "COPD reasoning summary", "clinician",
     "explanation", "Render GOLD severity grade, evidence, treatment/escalation rationale and LTOT/rehabilitation plan."),
]

# ---------------------------------------------------------------------------
# 7. Governance
# ---------------------------------------------------------------------------
GOVERNED_OBJECTS = [
    ("PROT-COPD-EXACERBATION", "PROTOCOL", "Acute COPD exacerbation pathway",
     "Population-aware adult acute COPD exacerbation pathway: ABC, controlled oxygen 88-92%, ABG, bronchodilators + corticosteroids + antibiotics, clearance, CXR, NIV escalation, critical care, discharge prevention.", "KCR-0018", "POP-ADULT"),
    ("SCORE-GOLD", "INTERPRETATION", "GOLD airflow limitation severity",
     "GOLD 1-4 severity by post-bronchodilator FEV1 % predicted with FEV1/FVC <0.70 (KCR-0016).", "KCR-0016", "POP-ADULT"),
    ("MED-TIOTROPIUM", "DRUG", "Tiotropium (LAMA)",
     "Long-acting muscarinic antagonist improving lung function, dyspnoea and quality of life in COPD (KCR-0017).", "KCR-0017", "POP-ADULT"),
    ("DOSE-COPD", "DOSING_RULE", "COPD dose rules",
     "Population-aware dose rules for COPD maintenance and exacerbation drugs grounded to KCR-0017/0018.", "KCR-0017", "POP-ADULT"),
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R6 COPD pathway (adult)")
    w("-- Chronic + exacerbation COPD grounded to Kumar & Clark 10e p955-960")
    w("-- (claims KCR-0013..KCR-0018). Adds GOLD severity, drug therapy, LTOT, NIV.")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r6_copd.py <out>")
    w("-- =============================================================================")
    w("")

    # 0. claims ----------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 0. knowledge.source_claim - COPD claims (Kumar & Clark p955-960)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_claim (claim_id, claim_code, source_version_id, chapter_id, chunk_id, page_start, page_end, claim_type, claim_kind, claim_text, knowledge_type, contract, confidence, status) VALUES")
    rows = []
    for code, page, ctype, kind, text, contract in COPD_CLAIMS:
        chunk = "d133e703-46c8-5a26-a05b-0bd6c507b385"
        rows.append(
            f"   ({sql_literal(u('RC:' + code))}, {sql_literal(code)}, 'KUMAR_CLARK_10_2017', 'KC-C28', {sql_literal(chunk)}, {sql_literal(str(page))}, {sql_literal(str(page))}, {sql_literal(ctype)}, {sql_literal(kind)}, {sql_literal(text)}, 'medicine', {jq(contract)}::jsonb, 0.9, 'VERIFIED')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET chunk_id = EXCLUDED.chunk_id, page_start = EXCLUDED.page_start, claim_text = EXCLUDED.claim_text, contract = EXCLUDED.contract;")
    w("")

    # 1. conditions -------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. knowledge.condition - COPD + COPD exacerbation")
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
    w("-- 2. clinical.fact_definition - FEV1_PERCENT, PURSED_LIPS")
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
    w("-- 2b. knowledge.severity_score - SCORE-GOLD (GOLD 1-4 by FEV1 %)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.severity_score (id, score_code, canonical_name, description, condition_id, population, max_score, source_reference, status) VALUES")
    w(f"   ({sql_literal(u('SCORE:GOLD'))}, 'SCORE-GOLD', 'GOLD airflow limitation severity', 'GOLD 1-4 severity based on post-bronchodilator FEV1 % predicted with FEV1/FVC <0.70 (KCR-0016).', (SELECT id FROM knowledge.condition WHERE condition_code = 'COND-COPD'), 'adult', 4, 'Kumar & Clark 10e p957 (GOLD 2016) - KCR-0016', 'active')")
    w("ON CONFLICT (score_code) DO UPDATE SET description = EXCLUDED.description;")
    w("")
    w("INSERT INTO knowledge.severity_score_component (id, score_id, component_code, component_name, condition, points, rationale, sort_order) VALUES")
    rows = [
        f"   ({sql_literal(u('GCOMP:' + cc))}, (SELECT id FROM knowledge.severity_score WHERE score_code = 'SCORE-GOLD'), {sql_literal(cc)}, {sql_literal(name)}, {jq(cond)}::jsonb, {sql_literal(str(points))}, {sql_literal(rat)}, {sql_literal(str(sort))})"
        for sort, (cc, name, cond, points, rat) in enumerate(GOLD_COMPONENTS, start=10)
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (score_id, component_code) DO UPDATE SET condition = EXCLUDED.condition, points = EXCLUDED.points, rationale = EXCLUDED.rationale;")
    w("")
    w("INSERT INTO knowledge.severity_score_interpretation (id, score_id, min_score, max_score, severity_label, disposition, recommendation) VALUES")
    rows = [
        f"   ({sql_literal(u('GINT:' + str(mn)))}, (SELECT id FROM knowledge.severity_score WHERE score_code = 'SCORE-GOLD'), {sql_literal(str(mn))}, {sql_literal(str(mx))}, {sql_literal(label)}, {sql_literal(disp)}, {sql_literal(rec)})"
        for mn, mx, label, disp, rec in GOLD_INTERPRETATIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (score_id, min_score, max_score) DO UPDATE SET severity_label = EXCLUDED.severity_label, disposition = EXCLUDED.disposition, recommendation = EXCLUDED.recommendation;")
    w("")

    # 3. medications ------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. knowledge.medication - COPD armamentarium")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES")
    rows = [
        f"   ({sql_literal(u('CONCEPT:' + code))}, {sql_literal('CNS-' + code)}, 'medication', {sql_literal(name)}, {sql_literal(name)}, 'active')"
        for code, name, _cls, _routes, _forms in NEW_MEDS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (concept_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name;")
    w("")
    w("INSERT INTO knowledge.medication (id, concept_id, medication_code, generic_name, drug_class, route_options, formulations, contraindications, evidence_source, status) VALUES")
    rows = []
    for code, name, cls, routes, forms in NEW_MEDS:
        rows.append(
            f"   ({sql_literal(u('MED:' + code))}, {sql_literal(u('CONCEPT:' + code))}, {sql_literal(code)}, {sql_literal(name)}, {sql_literal(cls)}, "
            f"{sql_literal(routes)}::jsonb, {sql_literal(forms)}::jsonb, '[\"serious immediate allergy to this class\"]'::jsonb, "
            f"'Kumar & Clark 10e p957-958 (KCR-0017) - verify against local formulary.', 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (medication_code) DO UPDATE SET generic_name = EXCLUDED.generic_name, drug_class = EXCLUDED.drug_class;")
    w("")
    for med, dose_expr, basis, kg_min, kg_max, freq, dur, verified, claim, route, pop, ind in COPD_DOSES:
        basis_sql = sql_literal(basis) if basis else "NULL"
        kgmin_sql = str(kg_min) if kg_min is not None else "NULL"
        kgmax_sql = str(kg_max) if kg_max is not None else "NULL"
        w("INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max) VALUES")
        w(f"   ({sql_literal(u('DOSE:' + med + ':' + ind + ':' + pop))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(med)}), {sql_literal(pop)}, {sql_literal(ind)}, {sql_literal(route)}, {sql_literal(dose_expr)}, {sql_literal(freq)}, {sql_literal(dur)}, 'Kumar & Clark 10e p955-960 ({claim})', {('TRUE' if verified else 'FALSE')}, {basis_sql}, {kgmin_sql}, {kgmax_sql})")
        w(f"ON CONFLICT (medication_id, population, indication_code, route) DO UPDATE SET")
        w(f"    dose_expression = EXCLUDED.dose_expression, frequency_expression = EXCLUDED.frequency_expression,")
        w(f"    duration_expression = EXCLUDED.duration_expression, weight_basis = EXCLUDED.weight_basis,")
        w(f"    dose_per_kg_min = EXCLUDED.dose_per_kg_min, dose_per_kg_max = EXCLUDED.dose_per_kg_max,")
        w(f"    is_verified = EXCLUDED.is_verified, evidence_source = EXCLUDED.evidence_source;")
        w(p("drug_dose_reference", u("DOSE:" + med + ":" + ind + ":" + pop), "DOSE:" + med, claim))
        w("")
    w("INSERT INTO knowledge.medication_condition (id, medication_id, condition_id, role, weight) VALUES")
    rows = []
    for cond, meds in MED_CONDITION:
        for med, role, wt in meds:
            rows.append(
                f"   ({sql_literal(u('MC:' + med + ':' + cond + ':' + role))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(med)}), (SELECT id FROM knowledge.condition WHERE condition_code = {sql_literal(cond)}), {sql_literal(role)}, {sql_literal(f'{wt:.2f}')})"
            )
    w(",\n".join(rows))
    w("ON CONFLICT (medication_id, condition_id, role) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 4. investigations ---------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. knowledge.investigation - spirometry + ABG")
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

    # 5. protocol ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 5. PROT-COPD-EXACERBATION - full 12-step pathway (adult)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.protocol (id, concept_id, protocol_code, canonical_name, version_label, description, specialty_code, purpose, status, is_guideline, source_reference, population) VALUES")
    w(f"   ({sql_literal(u('PROT:COPD-EXACERBATION'))}, NULL, 'PROT-COPD-EXACERBATION', 'Acute COPD exacerbation pathway', '1.0', 'Adult acute COPD exacerbation: ABC, controlled oxygen 88-92%, ABG, bronchodilators + corticosteroids + antibiotics, clearance, CXR, NIV escalation, critical care, discharge prevention.', 'pulmonology', 'management', 'active', true, 'Kumar & Clark 10e p955-960 (KCR-0013..0018)', 'adult')")
    w("ON CONFLICT (protocol_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, status = EXCLUDED.status, description = EXCLUDED.description;")
    w("")
    w("INSERT INTO knowledge.protocol_condition (id, protocol_id, condition_id, is_primary) VALUES")
    w(f"   ({sql_literal(u('PC:COPD-EXACERBATION:PROT'))}, {sql_literal(u('PROT:COPD-EXACERBATION'))}, (SELECT id FROM knowledge.condition WHERE condition_code = 'COND-COPD-EXACERBATION'), true)")
    w("ON CONFLICT (protocol_id, condition_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;")
    w("")
    w("INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required) VALUES")
    rows = [
        f"   ({sql_literal(u('PSTEP:COPD:' + sc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-COPD-EXACERBATION'), {sql_literal(sc)}, {sql_literal(label)}, {sql_literal(stype)}, {sql_literal(str(seq))}, {sql_literal(instr)}, {sql_literal(rat)}, {('TRUE' if req else 'FALSE')})"
        for sc, label, stype, seq, instr, rat, req in PROTOCOL_STEPS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, step_code) DO UPDATE SET instruction = EXCLUDED.instruction, rationale = EXCLUDED.rationale, sequence_no = EXCLUDED.sequence_no, step_type = EXCLUDED.step_type;")
    w("")
    w("INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order) VALUES")
    rows = [
        f"   ({sql_literal(u('PACT:COPD:' + sc + ':' + ac + ':' + str(so)))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-COPD-EXACERBATION'), (SELECT ps.id FROM knowledge.protocol_step ps JOIN knowledge.protocol p ON p.id = ps.protocol_id WHERE p.protocol_code = 'PROT-COPD-EXACERBATION' AND ps.step_code = {sql_literal(sc)}), {sql_literal(at)}, {sql_literal(ac)}, {sql_literal(an)}, {sql_literal(detail)}, {sql_literal(urg)}, {sql_literal(str(so))})"
        for sc, at, ac, an, detail, urg, so in PROTOCOL_ACTIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (step_id, action_type, action_code) DO UPDATE SET detail = EXCLUDED.detail, sort_order = EXCLUDED.sort_order;")
    w("")
    w("INSERT INTO knowledge.protocol_monitoring (id, protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES")
    rows = [
        f"   ({sql_literal(u('PMON:COPD:' + mc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-COPD-EXACERBATION'), (SELECT id FROM knowledge.monitoring WHERE monitoring_code = {sql_literal(mc)}), {sql_literal(freq)}, {sql_literal(det)}, {sql_literal(esc)})"
        for mc, freq, det, esc in PROTOCOL_MONITORING
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, monitoring_id) DO UPDATE SET frequency = EXCLUDED.frequency, deterioration_rule = EXCLUDED.deterioration_rule, escalation_instruction = EXCLUDED.escalation_instruction;")
    w("")

    # 6. education ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 6. knowledge.education - COPD education objects")
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
        for cond in ("COND-COPD", "COND-COPD-EXACERBATION"):
            rows.append(
                f"   ({sql_literal(u('EDC:' + code + ':' + cond))}, (SELECT id FROM knowledge.education WHERE education_code = {sql_literal(code)}), (SELECT id FROM knowledge.condition WHERE condition_code = {sql_literal(cond)}), 1.0)"
            )
    w(",\n".join(rows))
    w("ON CONFLICT (education_id, condition_id) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 7. governance + provenance --------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 7. governance.knowledge_object - COPD pathway objects")
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
    w("SELECT ko.id, 1, 'GO-V-R6-' || ko.object_code, 'R6 COPD pathway release (KCR-0013..0018).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'")
    w("FROM governance.knowledge_object ko WHERE ko.object_code IN (" + ", ".join(sql_literal(x[0]) for x in GOVERNED_OBJECTS) + ")")
    w("ON CONFLICT (version_code) DO UPDATE SET change_note = EXCLUDED.change_note, lifecycle_status = EXCLUDED.lifecycle_status;")
    w("")
    for code, _ktype, _name, _desc, claim, _pop in GOVERNED_OBJECTS:
        w(p("governance.knowledge_object", u("GOBJ:" + code), code, claim))
    w("")

    # 8. master matrix ----------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 8. tracking.respiratory_master_matrix - COPD status")
    w("-- ---------------------------------------------------------------------------")
    w("UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Kumar & Clark 10e p955-957 (KCR-0013..0016)',")
    w("       notes='COPD definition, chronic bronchitis, clinical features, investigations, GOLD severity classification; adult pathway active.',")
    w("       updated_at=now() WHERE item_code='COND-COPD';")
    w("UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Kumar & Clark 10e p959-960 (KCR-0018)',")
    w("       notes='Acute exacerbation pathway: ABC, controlled oxygen 88-92%, ABG, bronchodilators + corticosteroids + antibiotics, clearance, CXR, NIV escalation, critical care.',")
    w("       updated_at=now() WHERE item_code='COND-COPD-EXACERBATION';")
    w("UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Kumar & Clark 10e p957-960 (KCR-0017/0018)',")
    w("       notes='Maintenance (SABA/LABA/LAMA/PDE4/mucolytic/ICS/LTOT/rehab/vaccines) + exacerbation management + BODE prognosis covered.',")
    w("       updated_at=now() WHERE item_code='LONG-COPD';")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(COPD_CLAIMS)} claims, {len(CONDITIONS)} conditions, {len(GOLD_COMPONENTS)} GOLD grades, {len(NEW_MEDS)} new meds, {len(COPD_DOSES)} dose rows, {len(PROTOCOL_STEPS)} steps, {len(PROTOCOL_ACTIONS)} actions, {len(GOVERNED_OBJECTS)} governed objects")


if __name__ == "__main__":
    main(sys.argv[1])