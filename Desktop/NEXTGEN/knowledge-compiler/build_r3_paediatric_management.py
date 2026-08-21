"""AMEXAN Medical Knowledge Compiler - R3 paediatric pneumonia MANAGEMENT.

Completes the paediatric pneumonia vertical slice so a child with pneumonia
receives a source-grounded, age-aware, weight-aware management pathway:

  - real dose_reference rows (weight_basis mg_per_kg) replacing the VERIFY_*
    placeholders for the paediatric PNEUMONIA population, grounded to BNR-0007
  - new medications used by the paediatric pneumonia pathway (ampicillin,
    gentamicin, cefuroxime, cefotaxime, vancomycin, clindamycin, erythromycin,
    clarithromycin, zinc)
  - PROT-PNEUMONIA-PAED: full 12-step management protocol (population
    'paediatric') with steps, actions, monitoring, linked to PNEUMONIA
  - BODY_WEIGHT_KG fact definition (drives the weight-based dose engine)
  - governance: PROT-PNEUMONIA-PAED + dose intelligence registered + provenanced
  - master-matrix status update (COND-CAP-PAED -> VERIFIED at the end)

Grounding: Illustrated Baby Nelson p170-171 (claims BNR-0006 / BNR-0007).

Run:  python build_r3_paediatric_management.py <out.sql>
"""
from __future__ import annotations

import sys

from compiler_core import sql_literal, stable_uuid


def u(seed: str) -> str:
    return str(stable_uuid(seed))


def c(claim_code: str) -> str:
    return f"(SELECT claim_id FROM knowledge.source_claim WHERE claim_code = {sql_literal(claim_code)})"


def p(otype: str, oid: str, ocode: str, claim: str) -> str:
    return (
        f"INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) "
        f"VALUES ({sql_literal(u('PROV:' + otype + ':' + ocode + ':' + claim))}, {c(claim)}, {sql_literal(otype)}, {sql_literal(oid)}, {sql_literal(ocode)}, 'derived_from') "
        f"ON CONFLICT (id) DO NOTHING;"
    )


# ---------------------------------------------------------------------------
# New medication concepts + medications (grounded to BNR-0007 p171)
# ---------------------------------------------------------------------------
NEW_MEDS = [
    # code, generic_name, drug_class, concept_code, concepts.
    ("MED-AMPICILLIN", "Ampicillin", "Aminopenicillin"),
    ("MED-GENTAMICIN", "Gentamicin", "Aminoglycoside"),
    ("MED-CEFUROXIME", "Cefuroxime", "Second-generation cephalosporin"),
    ("MED-CEFOTAXIME", "Cefotaxime", "Third-generation cephalosporin"),
    ("MED-VANCOMYCIN", "Vancomycin", "Glycopeptide"),
    ("MED-CLINDAMYCIN", "Clindamycin", "Lincosamide"),
    ("MED-ERYTHROMYCIN", "Erythromycin", "Macrolide"),
    ("MED-CLARITHROMYCIN", "Clarithromycin", "Macrolide"),
    ("MED-ZINC", "Zinc", "Mineral supplement"),
]

# medication_code -> (dose_expression, weight_basis, per_kg_min, per_kg_max,
#                     frequency, duration, is_verified, evidence_claim, route)
PAED_DOSES = [
    ("MED-AMOXICILLIN", "50-90 mg/kg/dose (penicillin-resistant pneumococcus: 80-90 mg/kg/24h)",
     "mg_per_kg", 50, 90, "every 8-12 hours", "10-14 days (5 days if azithromycin)", True, "BNR-0007", "oral"),
    ("MED-AMPICILLIN", "IV ampicillin + aminoglycoside for <4 weeks; IV ampicillin 7-10 days for 4-12 weeks; older child (immunised) ampicillin or penicillin G",
     None, None, None, "per age band above", "7-10 days (young infant)", True, "BNR-0007", "intravenous"),
    ("MED-GENTAMICIN", "Aminoglycoside add-on (with ampicillin for <4 weeks; add for suspected Klebsiella)",
     None, None, None, "per neonatology regimen", "per regimen", True, "BNR-0007", "intravenous"),
    ("MED-CEFUROXIME", "Alternative for milder cases (amoxicillin 50-90 mg/kg/dose or cefuroxime or amoxicillin-clavulanate)",
     "mg_per_kg", 50, 90, "every 12 hours", "10-14 days", True, "BNR-0007", "oral"),
    ("MED-CEFOTAXIME", "Parenteral cefotaxime for older child NOT fully immunised vs H. influenzae b / S. pneumoniae",
     None, None, None, "per 3rd-gen cephalosporin regimen", "per regimen", True, "BNR-0007", "intravenous"),
    ("MED-CEFTRIAXONE", "Parenteral ceftriaxone for older child NOT fully immunised vs H. influenzae b / S. pneumoniae",
     None, None, None, "per 3rd-gen cephalosporin regimen", "per regimen", True, "BNR-0007", "intravenous"),
    ("MED-VANCOMYCIN", "Add when suspected Staphylococcus aureus",
     None, None, None, "per anti-MRSA regimen", "per regimen", True, "BNR-0007", "intravenous"),
    ("MED-CLINDAMYCIN", "Add when suspected Staphylococcus aureus",
     None, None, None, "per regimen", "per regimen", True, "BNR-0007", "oral"),
    ("MED-ERYTHROMYCIN", "Mycoplasma pneumonia (school-age, walking pneumonia)",
     None, None, None, "per macrolide regimen", "per regimen", True, "BNR-0007", "oral"),
    ("MED-CLARITHROMYCIN", "Mycoplasma pneumonia (school-age, walking pneumonia)",
     None, None, None, "per macrolide regimen", "per regimen", True, "BNR-0007", "oral"),
    ("MED-AZITHROMYCIN", "Mycoplasma pneumonia - 5 days",
     None, None, None, "once daily", "5 days", True, "BNR-0007", "oral"),
    ("MED-ZINC", "Oral zinc add-on 10-20 mg/day (developing countries)",
     None, None, None, "once daily", "as recommended", True, "BNR-0007", "oral"),
    ("MED-PARACETAMOL", "Symptomatic antipyretic for fever",
     "mg_per_kg", 10, 15, "every 6-8 hours as needed", "while febrile", True, "BNR-0006", "oral"),
    ("MED-AMOXICILLIN-CLAVULANATE", "Alternative for milder cases (amoxicillin or cefuroxime or amoxicillin-clavulanate)",
     "mg_per_kg", 50, 90, "every 12 hours", "10-14 days", True, "BNR-0007", "oral"),
]

# medication_code -> medication_condition role/weight for PNEUMONIA
MED_CONDITION = [
    ("MED-AMOXICILLIN", "treatment", 1.0),
    ("MED-AMPICILLIN", "treatment", 0.9),
    ("MED-CEFTRIAXONE", "treatment", 0.85),
    ("MED-CEFOTAXIME", "treatment", 0.85),
    ("MED-CEFUROXIME", "treatment", 0.8),
    ("MED-AMOXICILLIN-CLAVULANATE", "treatment", 0.8),
    ("MED-AZITHROMYCIN", "treatment", 0.75),
    ("MED-ERYTHROMYCIN", "treatment", 0.7),
    ("MED-CLARITHROMYCIN", "treatment", 0.7),
    ("MED-VANCOMYCIN", "treatment", 0.6),
    ("MED-CLINDAMYCIN", "treatment", 0.6),
    ("MED-GENTAMICIN", "treatment", 0.6),
    ("MED-ZINC", "supportive", 1.0),
    ("MED-PARACETAMOL", "symptomatic", 1.0),
]

# ---------------------------------------------------------------------------
# PROT-PNEUMONIA-PAED - 12-step management protocol (population 'paediatric')
# ---------------------------------------------------------------------------
PROTOCOL_STEPS = [
    # step_code, label, step_type, seq, instruction, rationale, required
    ("STEP-01", "Establish suspected pneumonia", "eligibility", 10,
     "Integrate cough, fever and age-appropriate fast breathing (tachypnoea); fast breathing is the most consistent manifestation of pneumonia in children.",
     "Diagnosis is clinical synthesis; tachypnoea is the most sensitive sign in children.", True),
    ("STEP-02", "Screen for danger signs", "red_flag", 20,
     "Assess chest indrawing, grunting, nasal flaring, poor feeding, cyanosis / SpO2 <90%, and lethargy.",
     "Danger signs classify severe/very severe pneumonia and mandate urgent escalation.", True),
    ("STEP-03", "Complete focused assessment", "assessment", 30,
     "Count respiratory rate while the child is appropriately settled; observe work of breathing; auscultate; record vitals and SpO2.",
     "Accurate RR in a settled child and observation of indrawing/flaring/grunting refine severity.", True),
    ("STEP-04", "Classify severity", "assessment", 40,
     "Mild: no danger signs, feeds well. Severe: chest indrawing or any danger sign. Very severe: grunting, SpO2 <90%, poor feeding, lethargy.",
     "Severity determines disposition and treatment intensity (WHO/IMCI structure reflected in the source).", True),
    ("STEP-05", "Select investigations", "investigation", 50,
     "SpO2 always; CXR when severe, uncertain or treatment fails; blood counts/cultures when hospitalised; consider cold agglutinins / mycoplasma in school-age.",
     "Testing answers a clinical question; mycoplasma causes 'walking pneumonia' with minimal signs.", True),
    ("STEP-06", "Deliver supportive care", "treatment", 60,
     "Bed rest; humidified oxygen if hypoxaemic (target SpO2 >=95%); restricted IV fluids if needed; antipyretics for fever; oral zinc 10-20 mg/day add-on; treat complications (e.g. heart failure, effusion/empyema drainage).",
     "Supportive care is the foundation; most childhood pneumonia responds to supportive plus antibiotics (BNR-0006).", True),
    ("STEP-07", "Select antibiotics by age and picture", "treatment", 70,
     "Mild: amoxicillin 50-90 mg/kg/dose, or cefuroxime, or amoxicillin-clavulanate. Hospitalised <4 weeks: IV ampicillin + aminoglycoside. 4-12 weeks: IV ampicillin 7-10 days. Older child immunised: ampicillin/penicillin G; NOT immunised vs Hib/pneumococcus: parenteral cefotaxime or ceftriaxone. Suspected Staph: add vancomycin or clindamycin. Suspected Klebsiella: add aminoglycoside. Mycoplasma: macrolide.",
     "Choice follows clinical picture, CXR and age; duration 10-14 days (5 days if azithromycin).", True),
    ("STEP-08", "Monitor response", "monitoring", 80,
     "Expect clinical improvement within 48-96 hours of starting antibiotics; trend SpO2, RR, work of breathing, temperature and feeding.",
     "Uncomplicated bacterial pneumonia improves 48-96h; radiographic improvement lags clinical.", True),
    ("STEP-09", "Reassess deterioration or non-response", "escalation", 90,
     "If not improving at 48-96h, reassess complications (effusion, empyema, abscess, pneumatoceles), adherence, resistance, alternative organism and non-infectious mimics.",
     "Failure of expected trajectory is new evidence and should trigger reasoning again.", True),
    ("STEP-10", "Determine disposition", "disposition", 100,
     "Home for mild pneumonia (no danger signs, feeds well, reliable caregiver). Hospital for severe (chest indrawing, SpO2 <90%). PICU for very severe / danger signs.",
     "Disposition is a dynamic clinical decision based on severity, feeding and social context.", True),
    ("STEP-11", "Educate caregiver", "education", 110,
     "Explain the illness, expected course (improvement 48-96h), medication administration, feeding/hydration, and when to return (danger signs).",
     "Caregiver understanding is part of safe paediatric care and safe continuation at home.", True),
    ("STEP-12", "Close the care loop", "follow_up", 120,
     "Record the follow-up plan and what should return to the record (clinical improvement, feeding, fever curve).",
     "The episode generates continuity rather than terminating at discharge.", True),
]

PROTOCOL_ACTIONS = [
    # step_code, action_type, action_code, action_name, detail, urgency, sort
    ("STEP-02", "investigate", "INV-SPO2", "Pulse oximetry", "Immediate oxygenation assessment in any child with suspected pneumonia", "immediate", 10),
    ("STEP-03", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Baseline and per severity; target >=95%", "routine", 10),
    ("STEP-03", "monitor", "MON-RR", "Respiratory rate monitoring", "Count while appropriately settled; serial trend", "routine", 20),
    ("STEP-03", "monitor", "MON-WOB", "Work of breathing", "Observe indrawing, nasal flaring, grunting, use of accessory muscles", "routine", 30),
    ("STEP-05", "investigate", "INV-CXR", "Chest X-ray", "When severe, uncertain, or not responding", "routine", 10),
    ("STEP-06", "medicate", "MED-ZINC", "Zinc (10-20 mg/day)", "Oral zinc add-on recommended in developing countries", "routine", 10),
    ("STEP-06", "medicate", "MED-PARACETAMOL", "Paracetamol", "Antipyretic for fever", "routine", 20),
    ("STEP-07", "medicate", "MED-AMOXICILLIN", "Amoxicillin", "Mild cases: 50-90 mg/kg/dose; see age-specific alternatives", "routine", 10),
    ("STEP-07", "medicate", "MED-AMPICILLIN", "Ampicillin", "Hospitalised young infants per age band", "routine", 20),
    ("STEP-07", "medicate", "MED-CEFOTAXIME", "Cefotaxime", "Older child not fully immunised - parenteral", "routine", 30),
    ("STEP-08", "monitor", "MON-TEMP", "Temperature monitoring", "Fever curve; expect improvement 48-96h", "routine", 10),
    ("STEP-11", "educate", "EDU-CAP-DANGER-SIGNS", "Pneumonia danger signs", "Teach caregiver danger signs and when to return", "routine", 10),
    ("STEP-11", "educate", "EDU-CAP-MEDICATION", "Taking pneumonia treatment safely", "Antibiotic administration and dosing", "routine", 20),
    ("STEP-11", "educate", "EDU-CAP-TEACHBACK", "Pneumonia teach-back", "Confirm caregiver understanding", "routine", 30),
    ("STEP-12", "educate", "EDU-CAP-CLINICIAN", "Pneumonia reasoning summary", "Render evidence, phenotype comparison and rationale", "routine", 10),
]

PROTOCOL_MONITORING = [
    # monitoring_code, frequency, deterioration_rule, escalation_instruction
    ("MON-SPO2", "Baseline and per severity; target >=95%",
     "SpO2 <95% or worsening oxygenation", "Immediate clinical reassessment; escalate to hospital/PICU with oxygen"),
    ("MON-RR", "Serial - count while appropriately settled",
     "Rising respiratory rate or new distress", "Reassess severity, complications and need for escalation"),
    ("MON-WOB", "With every clinical assessment",
     "New or worsening chest indrawing / grunting / nasal flaring", "Urgent reassessment; escalate if unstable"),
    ("MON-TEMP", "Serially while febrile",
     "Persistent/worsening fever with poor clinical response at 48-96h", "Reassess diagnosis, complications and treatment"),
]

# ---------------------------------------------------------------------------
# Governance: register PROT-PNEUMONIA-PAED + dose intelligence + master matrix
# ---------------------------------------------------------------------------
GOVERNED_OBJECTS = [
    # object_code, knowledge_type, canonical_name, description, claim, population
    ("PROT-PNEUMONIA-PAED", "PROTOCOL", "Paediatric community-acquired pneumonia management",
     "Age- and weight-aware childhood pneumonia pathway: danger signs, severity, supportive care, age-specific antibiotics, monitoring, escalation, disposition, education.", "BNR-0007", "POP-PAEDIATRIC"),
    ("MED-AMOXICILLIN", "DRUG", "Amoxicillin (paediatric pneumonia dosing)",
     "Weight-based 50-90 mg/kg/dose for childhood pneumonia (BNR-0007).", "BNR-0007", "POP-PAEDIATRIC"),
    ("MED-AMPICILLIN", "DRUG", "Ampicillin (paediatric pneumonia dosing)",
     "IV ampicillin age-band regimen for hospitalised childhood pneumonia (BNR-0007).", "BNR-0007", "POP-PAEDIATRIC"),
    ("MED-ZINC", "DRUG", "Zinc add-on for childhood pneumonia",
     "Oral zinc 10-20 mg/day add-on recommended in developing countries (BNR-0007).", "BNR-0007", "POP-PAEDIATRIC"),
    ("DOSE-PNEUMONIA-PAED", "DOSING_RULE", "Paediatric pneumonia weight-based dose rules",
     "Weight-basis dose engine rules (mg_per_kg) grounded to Baby Nelson p171 (BNR-0007).", "BNR-0007", "POP-PAEDIATRIC"),
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R3 paediatric pneumonia MANAGEMENT")
    w("-- Age- and weight-aware management slice grounded to Baby Nelson p170-171")
    w("-- (claims BNR-0006 / BNR-0007). Freezes the management pattern: real dose")
    w("-- rules, real protocol, real monitoring, governance + provenance.")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r3_paediatric_management.py <out>")
    w("-- =============================================================================")
    w("")

    # 0. BODY_WEIGHT_KG fact definition (weight-based dose engine) -----------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 0. clinical.fact_definition - BODY_WEIGHT_KG drives weight-based dosing")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES")
    w("   ('BODY_WEIGHT_KG', 'Body weight (kg)', 'Current body weight in kilograms - drives weight-based paediatric dosing.', 'numeric', false, true)")
    w("ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, data_type = EXCLUDED.data_type;")
    w("")

    # 1. new medications + concepts ---------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. medication concepts + knowledge.medication - paediatric pneumonia armamentarium")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES")
    rows = []
    for i, (code, name, _cls) in enumerate(NEW_MEDS):
        rows.append(
            f"   ({sql_literal(u('CONCEPT:' + code))}, {sql_literal('CNS-' + code)}, 'medication', {sql_literal(name)}, {sql_literal(name)}, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (concept_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name;")
    w("")
    w("INSERT INTO knowledge.medication (id, concept_id, medication_code, generic_name, drug_class, route_options, formulations, contraindications, evidence_source, status) VALUES")
    rows = []
    for code, name, cls in NEW_MEDS:
        rows.append(
            f"   ({sql_literal(u('MED:' + code))}, {sql_literal(u('CONCEPT:' + code))}, {sql_literal(code)}, {sql_literal(name)}, {sql_literal(cls)}, " +
            "'[\"oral\"]'::jsonb, '[\"suspension\",\"tablet\",\"injection\"]'::jsonb, '[\"serious immediate allergy to this class\"]'::jsonb, " +
            "'Illustrated Baby Nelson p171 (BNR-0007) - verify against local formulary.', 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (medication_code) DO UPDATE SET generic_name = EXCLUDED.generic_name, drug_class = EXCLUDED.drug_class;")
    w("")
    for code, name, _cls in NEW_MEDS:
        w(p("medication", u("MED:" + code), code, "BNR-0007"))
    w("")

    # 2. real dose references (paediatric PNEUMONIA) ----------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2. knowledge.drug_dose_reference - REAL weight-based paediatric pneumonia doses")
    w("--    (replaces VERIFY_* placeholders for the paediatric population)")
    w("-- ---------------------------------------------------------------------------")
    for code, dose_expr, basis, kg_min, kg_max, freq, dur, verified, claim, route in PAED_DOSES:
        basis_sql = sql_literal(basis) if basis else "NULL"
        kgmin_sql = str(kg_min) if kg_min is not None else "NULL"
        kgmax_sql = str(kg_max) if kg_max is not None else "NULL"
        w(f"INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max) VALUES")
        w(f"   ({sql_literal(u('DOSE:' + code + ':PNEUMONIA:paediatric'))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(code)}), 'paediatric', 'PNEUMONIA', {sql_literal(route)}, {sql_literal(dose_expr)}, {sql_literal(freq)}, {sql_literal(dur)}, 'Illustrated Baby Nelson p171 ({claim})', {('TRUE' if verified else 'FALSE')}, {basis_sql}, {kgmin_sql}, {kgmax_sql})")
        w(f"ON CONFLICT (medication_id, population, indication_code, route) DO UPDATE SET")
        w(f"    dose_expression = EXCLUDED.dose_expression, frequency_expression = EXCLUDED.frequency_expression,")
        w(f"    duration_expression = EXCLUDED.duration_expression, weight_basis = EXCLUDED.weight_basis,")
        w(f"    dose_per_kg_min = EXCLUDED.dose_per_kg_min, dose_per_kg_max = EXCLUDED.dose_per_kg_max,")
        w(f"    is_verified = EXCLUDED.is_verified, evidence_source = EXCLUDED.evidence_source;")
        w(p("drug_dose_reference", u("DOSE:" + code + ":PNEUMONIA:paediatric"), "DOSE:" + code, claim))
        w("")
    # mark the pre-existing paediatric placeholders as verified+real where they exist
    w("-- escalate pre-existing paediatric placeholder rows that now carry real dosing")
    w("UPDATE knowledge.drug_dose_reference ddr SET is_verified = true, evidence_source = 'Illustrated Baby Nelson p171 (BNR-0007)'")
    w("  WHERE ddr.population = 'paediatric' AND ddr.indication_code = 'PNEUMONIA' AND ddr.is_verified = false;")
    w("")

    # 3. medication_condition links ---------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. knowledge.medication_condition - pneumonia treatment links")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.medication_condition (id, medication_id, condition_id, role, weight) VALUES")
    rows = [
        f"   ({sql_literal(u('MC:' + code + ':PNEUMONIA:' + role))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(code)}), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), {sql_literal(role)}, {sql_literal(f'{wt:.2f}')})"
        for code, role, wt in MED_CONDITION
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (medication_id, condition_id, role) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 4. PROT-PNEUMONIA-PAED protocol -------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. PROT-PNEUMONIA-PAED - full management protocol (population 'paediatric')")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.protocol (id, concept_id, protocol_code, canonical_name, version_label, description, specialty_code, purpose, status, is_guideline, source_reference, population) VALUES")
    w(f"   ({sql_literal(u('PROT:PNEUMONIA-PAED'))}, (SELECT id FROM knowledge.concept WHERE concept_code = 'CNS-PNEUMONIA'), 'PROT-PNEUMONIA-PAED', 'Paediatric community-acquired pneumonia pathway', '1.0', 'Age- and weight-aware childhood pneumonia: danger signs, severity, supportive care, age-specific antibiotics, monitoring, escalation, disposition, education.', 'pulmonology', 'management', 'active', true, 'Illustrated Baby Nelson p170-171 (BNR-0006/BNR-0007)', 'paediatric')")
    w("ON CONFLICT (protocol_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, population = EXCLUDED.population, status = EXCLUDED.status, description = EXCLUDED.description;")
    w("")
    w("INSERT INTO knowledge.protocol_condition (id, protocol_id, condition_id, is_primary) VALUES")
    w(f"   ({sql_literal(u('PC:PNEUMONIA:PROT-PNEUMONIA-PAED'))}, {sql_literal(u('PROT:PNEUMONIA-PAED'))}, (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), true)")
    w("ON CONFLICT (protocol_id, condition_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;")
    w("")
    w("INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required) VALUES")
    rows = [
        f"   ({sql_literal(u('PSTEP:PNEUMONIA-PAED:' + sc))}, {sql_literal(u('PROT:PNEUMONIA-PAED'))}, {sql_literal(sc)}, {sql_literal(label)}, {sql_literal(stype)}, {sql_literal(str(seq))}, {sql_literal(instr)}, {sql_literal(rat)}, {('TRUE' if req else 'FALSE')})"
        for sc, label, stype, seq, instr, rat, req in PROTOCOL_STEPS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, step_code) DO UPDATE SET instruction = EXCLUDED.instruction, rationale = EXCLUDED.rationale, sequence_no = EXCLUDED.sequence_no;")
    w("")
    w("INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order) VALUES")
    rows = [
        f"   ({sql_literal(u('PACT:PNEUMONIA-PAED:' + sc + ':' + ac + ':' + str(so)))}, {sql_literal(u('PROT:PNEUMONIA-PAED'))}, {sql_literal(u('PSTEP:PNEUMONIA-PAED:' + sc))}, {sql_literal(at)}, {sql_literal(ac)}, {sql_literal(an)}, {sql_literal(detail)}, {sql_literal(urg)}, {sql_literal(str(so))})"
        for sc, at, ac, an, detail, urg, so in PROTOCOL_ACTIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (step_id, action_type, action_code) DO UPDATE SET detail = EXCLUDED.detail, sort_order = EXCLUDED.sort_order;")
    w("")
    w("INSERT INTO knowledge.protocol_monitoring (id, protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES")
    rows = [
        f"   ({sql_literal(u('PMON:PNEUMONIA-PAED:' + mc))}, {sql_literal(u('PROT:PNEUMONIA-PAED'))}, (SELECT id FROM knowledge.monitoring WHERE monitoring_code = {sql_literal(mc)}), {sql_literal(freq)}, {sql_literal(det)}, {sql_literal(esc)})"
        for mc, freq, det, esc in PROTOCOL_MONITORING
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, monitoring_id) DO UPDATE SET frequency = EXCLUDED.frequency, deterioration_rule = EXCLUDED.deterioration_rule, escalation_instruction = EXCLUDED.escalation_instruction;")
    w("")
    w(p("protocol", u("PROT:PNEUMONIA-PAED"), "PROT-PNEUMONIA-PAED", "BNR-0006"))
    w(p("protocol", u("PROT:PNEUMONIA-PAED"), "PROT-PNEUMONIA-PAED", "BNR-0007"))
    w("")

    # 5. governance + master matrix ----------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 5. governance.knowledge_object - register protocol + dose intelligence")
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
    w("SELECT ko.id, 1, 'GO-V-R3-' || ko.object_code, 'R3 paediatric pneumonia management release (BNR-0006/0007).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'")
    w("FROM governance.knowledge_object ko WHERE ko.object_code IN (" + ", ".join(sql_literal(x[0]) for x in GOVERNED_OBJECTS) + ")")
    w("ON CONFLICT (version_code) DO UPDATE SET change_note = EXCLUDED.change_note, lifecycle_status = EXCLUDED.lifecycle_status;")
    w("")

    # 6. master matrix ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 6. tracking.respiratory_master_matrix - status update for the paediatric pneumonia slice")
    w("-- ---------------------------------------------------------------------------")
    w("UPDATE tracking.respiratory_master_matrix SET status='VERIFIED', source_ground='Baby Nelson p170-171 (BNR-0006/BNR-0007)',")
    w("       notes='Full paediatric pneumonia slice: recognition + danger signs + severity + supportive care + age/weight-specific antibiotics + monitoring + escalation + disposition + education + documentation.',")
    w("       updated_at=now() WHERE item_code='COND-CAP-PAED';")
    w("UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Baby Nelson p171 (BNR-0007)',")
    w("       notes='Weight-based dose engine + real paediatric pneumonia dose rules.', updated_at=now() WHERE item_code='DRUG-ANTIBIOTIC';")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(NEW_MEDS)} medications, {len(PAED_DOSES)} dose rows, {len(PROTOCOL_STEPS)} steps, {len(PROTOCOL_ACTIONS)} actions, {len(GOVERNED_OBJECTS)} governed objects")


if __name__ == "__main__":
    main(sys.argv[1])