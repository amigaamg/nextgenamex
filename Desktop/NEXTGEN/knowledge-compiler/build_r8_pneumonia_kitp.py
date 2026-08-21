"""AMEXAN Medical Knowledge Compiler - R8 Kenya paediatric pneumonia overlay.

Lands the Kenya Ministry of Health paediatric pneumonia pathway (jurisdictional
overlay for JUR-KENYA) on top of the existing universal paediatric pneumonia
assessment already encoded by R1/R2 (Baby Nelson danger-sign facts, phenotype
PHEN-PAEDIATRIC-PNEUMONIA-ALARM, condition PNEUMONIA). R8 adds:

  - Kenya BPP 5th-edition source grounding (a small jurisdictional source tree +
    claims BPP-0001..0005, pages 46-47)
  - PROT-PNEUMONIA-KENYA-PAED: the full 12-step Kenya paediatric pneumonia
    management pathway (eligibility -> danger signs -> classification ->
    investigation -> severe/non-severe treatment -> review -> monitoring ->
    escalation -> education -> follow-up), governed ACTIVE / JUR-KENYA
  - the Kenya high-dose amoxicillin dose (40-45 mg/kg/dose) as a JUR-KENYA
    drug_dose_reference override of the universal 50-90 row
  - Kenya-specific monitoring links (MON-SPO2 / MON-RR / MON-WOB) and education
    (EDU-KENYA-*) for childhood pneumonia

Run:  python build_r8_pneumonia_kitp.py <out.sql>
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


def c(claim: str) -> str:
    return f"(SELECT claim_id FROM knowledge.source_claim WHERE claim_code = {sql_literal(claim)})"


def p(otype: str, oid: str, ocode: str, claim: str) -> str:
    return (
        f"INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) "
        f"VALUES ({sql_literal(u('PROV:' + otype + ':' + ocode + ':' + claim))}, {c(claim)}, {sql_literal(otype)}, {sql_literal(oid)}, {sql_literal(ocode)}, 'derived_from') "
        f"ON CONFLICT (id) DO NOTHING;"
    )


# Source tree ----------------------------------------------------------------
SOURCE = ("SRC-KENYA-BPP", "Kenya Ministry of Health Paediatric Pneumonia Guidelines (5th ed)",
          "guideline", "JUR-KENYA", "paediatric_management_guided", "Clinical guidelines for under-5 illness/PCP; 5th edition.", "Kenya MoH", "en", "active", 2022)
VERSION = ("VV-KENYA-BPP-5", "SRC-KENYA-BPP", 5, 2022, "en", "active")
SECTION = ("KENYA-BPP-SECTION-CLINICAL", "VV-KENYA-BPP-5", 1, "Clinical management", "SYSTEM", 10)
CHAPTER = ("KENYA-BPP-CH-PNEUMONIA", "VV-KENYA-BPP-5", "KENYA-BPP-SECTION-CLINICAL", 9,
           "Childhood pneumonia and other severe infections (5-59 months)", 46, 50, "SYSTEM", "paediatrics", "paediatric_respiratory", 10)

# (code, page, chapter_id, claim_type, claim_kind, knowledge_type, text, contract)
CLAIMS = [
    ("BPP-0001", 46, "KENYA-BPP-CH-PNEUMONIA", "definition", "definition", "guideline_activity",
     "Childhood pneumonia (Kenya BPP 5th ed, p46): any child aged 2-59 months presenting with cough and/or difficulty breathing is assessed for pneumonia. Look for general danger signs (unable to drink, persistent grunting, convulsions, severe disease) and for chest indrawing and stridor in a cold.",
     {"what_is_it": "Kenya BPP childhood pneumonia assessment trigger", "what_connects_to": "COUGH_PRESENT,FAST_BREATHING,DYSPNOEA", "source_support": "Kenya BPP 5th ed p46"}),
    ("BPP-0002", 46, "KENYA-BPP-CH-PNEUMONIA", "management", "management", "guideline_activity",
     "Classification and first-line treatment (Kenya BPP 5th ed, p46): Severe pneumonia or very severe disease = any general danger sign OR chest indrawing OR stridor in a cold OR central cyanosis/SpO2<90%. Manage severe: parenteral antibiotics (IV benzylpenicillin + gentamicin, or ceftriaxone) + oxygen + refer/admit. Non-severe (no severe signs): high-dose amoxicillin 40-45 mg/kg/day divided twice daily (40-45 mg/kg PER DOSE) for 5 days.",
     {"what_is_it": "Kenya BPP severe vs non-severe pneumonia classification + treatment", "what_connects_to": "MED-AMOXICILLIN,MED-GENTAMICIN,MED-CEFTRIAXONE,REF-KENYA-REFERRAL", "source_support": "Kenya BPP 5th ed p46"}),
    ("BPP-0003", 46, "KENYA-BPP-CH-PNEUMONIA", "investigation", "investigation", "guideline_activity",
     "Assess respiratory rate, chest indrawing, stridor, central cyanosis; give pulse oximetry. Severe hypoxaemia (SpO2<90% or <60 mmHg RaO2) needs high-flow oxygen to a target of at least 90% saturation (Kenya BPP 5th ed, p46-47).",
     {"what_is_it": "Kenya BPP investigations and hypoxaemia thresholds", "what_connects_to": "INV-CXR,MON-SPO2,MON-RR", "source_support": "Kenya BPP 5th ed p46-47"}),
    ("BPP-0004", 47, "KENYA-BPP-CH-PNEUMONIA", "principle", "principle", "guideline_activity",
     "Review the child within 24-48 hours. If no improvement or worsening: treat as severe - give IV benzylpenicillin + gentamicin (or ceftriaxone), refer urgently, test for HIV and consider TB (Kenya BPP 5th ed, p47).",
     {"what_is_it": "Kenya BPP treatment-failure escalation", "what_connects_to": "MED-CEFTRIAXONE,REF-KENYA-ESCALATION", "source_support": "Kenya BPP 5th ed p47"}),
    ("BPP-0005", 47, "KENYA-BPP-CH-PNEUMONIA", "management", "management", "guideline_activity",
     "Discharge only once the child is feeding normally and has no severe signs. Teach caregivers to complete the full antibiotic course and to return immediately for return of danger signs (grunting, nasal flaring, poor feeding, chest indrawing, cyanosis) or no improvement (Kenya BPP 5th ed, p47).",
     {"what_is_it": "Kenya BPP discharge teaching + danger-sign return instructions", "what_connects_to": "EDU-KENYA-DANGER-SIGNS,EDU-KENYA-RETURN-CARE", "source_support": "Kenya BPP 5th ed p47"}),
]

# (step_code, step_label, step_type, sequence_no, instruction, rationale, required)
PROTOCOL_STEPS = [
    ("STEP-01", "Confirm childhood pneumonia", "eligibility", 10,
     "Confirm: child aged 2-59 months with cough and/or difficulty breathing.",
     "Any child 2-59 months with cough and/or difficulty breathing is assessed for pneumonia; the paediatric overlay only applies within this age band (BPP-0001).", True),
    ("STEP-02", "Assess general danger signs", "red_flag", 20,
     "Ask about and look for: inability to drink / poor feeding, persistent grunting, nasal flaring, chest indrawing, stridor in a cold, central cyanosis or SpO2<90%.",
     "General danger signs and chest indrawing identify severe disease requiring urgent action (BPP-0001/BPP-0002).", True),
    ("STEP-03", "Examine and stage severity", "investigation", 30,
     "Measure respiratory rate, look for chest indrawing/stridor, assess conscious state, and give pulse oximetry (SpO2).",
     "RR, chest indrawing and SpO2 are the staging variables used to separate severe from non-severe disease (BPP-0003).", True),
    ("STEP-04", "Classify", "score", 40,
     "Classify: Severe/non-severe. Severe if ANY general danger sign OR chest indrawing OR stridor in a cold OR SpO2<90%; otherwise non-severe.",
     "Classification drives the treatment intensity: severe -> parenteral antibiotics + refer; non-severe -> high-dose oral amoxicillin (BPP-0002).", True),
    ("STEP-05", "Give parenteral treatment for severe", "treatment", 50,
     "Severe: refer/admit urgently; give IV benzylpenicillin + gentamicin (or ceftriaxone); high-flow oxygen to SpO2>=90% unless COPD.",
     "Severe pneumonia / very severe disease needs parenteral antibiotics and hospital-level care (BPP-0002).", True),
    ("STEP-06", "Give high-dose amoxicillin for non-severe", "treatment", 60,
     "Non-severe: high-dose amoxicillin 40-45 mg/kg per dose orally every 12 hours for 5 days (dose served from the JUR-KENYA drug_dose_reference row).",
     "Non-severe pneumonia is treated with high-dose oral amoxicillin 40-45 mg/kg/dose (BPP-0002) - NOT the universal 50-90 row.", True),
    ("STEP-07", "Monitor response", "monitoring", 70,
     "Monitor SpO2 (target >=95% non-severe / >=90% severe), respiratory rate, work of breathing, feeding and temperature.",
     "Close monitoring of oxygenation, effort and intake/output detects deterioration early (BPP-0003).", True),
    ("STEP-08", "Supportive care and hydration", "treatment", 80,
     "Reassess hydration; give maintenance fluids if unable to drink; treat fever with paracetamol (verify dose against formulary).",
     "Dehydration and fever are managed alongside antibiotics (BPP-0002).", True),
    ("STEP-09", "Give oxygen for hypoxaemia", "treatment", 90,
     "If SpO2<90%: give high-flow oxygen to a target SpO2>=90% (adults/older children >=92%); wean as the child improves.",
     "Hypoxaemia is the principal cause of death in severe pneumonia and is reversible with oxygen (BPP-0003).", True),
    ("STEP-10", "Escalate on treatment failure", "escalation", 100,
     "If no improvement or worsening within 24-48h: switch to parenteral therapy (IV benzylpenicillin + gentamicin or ceftriaxone), escalate oxygen, refer; test for HIV and consider TB.",
     "Treatment failure in 1-2% of cases signals severity/misclassification and requires urgent escalation (BPP-0004).", True),
    ("STEP-11", "Educate the caregiver", "education", 110,
     "Teach: complete the full antibiotic course; recognise and act on danger signs (grunting, nasal flaring, poor feeding, chest indrawing, cyanosis); return immediately if no improvement.",
     "Discharge teaching reduces readmission; danger signs are the key messages (BPP-0005).", True),
    ("STEP-12", "Close the care loop", "follow_up", 120,
     "Document the severity classification and response to treatment; arrange follow-up and link to community outreach for the 48h review.",
     "A pneumonia episode feeds ongoing care and surveillance; the 48h review is a hard stop (BPP-0004).", True),
]

# (step_code, action_type, action_code, action_name, detail, urgency, sort_order)
PROTOCOL_ACTIONS = [
    ("STEP-02", "monitor", "MON-RR", "Respiratory rate", "Count respirations while appropriately settled; tachypnoea is an early severity marker (BPP-0003).", "immediate", 10),
    ("STEP-02", "monitor", "MON-SPO2", "Oxygen saturation", "Pulse oximetry; severe hypoxaemia defined as SpO2<90% (BPP-0003).", "immediate", 20),
    ("STEP-02", "monitor", "MON-WOB", "Work of breathing", "Chest indrawing, nasal flaring, grunt - watch for progression.", "immediate", 30),
    ("STEP-04", "score", "SCORE-KENYA-PNEUMONIA", "Pneumonia classification score", "Severe / non-severe / no pneumonia by Kenya BPP criteria (danger signs + chest indrawing + SpO2).", "routine", 10),
    ("STEP-05", "refer", "REF-KENYA-REFERRAL", "Refer / admit for severe pneumonia", "Parenteral antibiotics + oxygen in a facility that can provide higher-level care.", "immediate", 10),
    ("STEP-05", "advice", "ADV-KENYA-IV-AB", "IV benzylpenicillin + gentamicin (or ceftriaxone)", "Standard doses: benzylpenicillin 25 mg/kg IV q6h + gentamicin 7.5 mg/kg/day IM once (or ceftriaxone). Verify against formulary.", "immediate", 20),
    ("STEP-06", "advice", "ADV-KENYA-AMOX", "High-dose oral amoxicillin", "40-45 mg/kg per dose every 12h for 5 days; dose row served from knowledge.drug_dose_reference jurisdiction_code='JUR-KENYA'. Verify against formulary.", "immediate", 10),
    ("STEP-06", "advice", "ADV-KENYA-ZINC", "Zinc supplementation", "20 mg elemental zinc daily for children 2-11 months, 10 mg for 12-59 months, for 10-14 days (WHO/Kenya integrated mg).", "routine", 20),
    ("STEP-07", "monitor", "MON-SPO2", "Oxygen saturation monitoring", "Target >=95% (non-severe) or >=90% (severe); reassess with every clinical review.", "routine", 10),
    ("STEP-07", "monitor", "MON-RR", "Respiratory rate monitoring", "Tachypnoea and work of breathing tracked serially.", "routine", 20),
    ("STEP-07", "monitor", "MON-WOB", "Work of breathing", "Chest indrawing, grunting, nasal flaring - rise on any sign of progression.", "routine", 30),
    ("STEP-10", "refer", "REF-KENYA-ESCALATION", "Escalate on treatment failure", "Switch to parenteral therapy; urgent referral with oxygen support; HIV test + TB screen.", "immediate", 10),
    ("STEP-10", "investigate", "INV-CXR", "Chest X-ray", "If severe or no improvement: CXR to exclude concurrent/severe pathology.", "urgent", 20),
    ("STEP-10", "investigate", "INV-HIV", "HIV test", "HIV testing in severe/refractory childhood pneumonia (Kenya BPP).", "urgent", 30),
    ("STEP-11", "educate", "EDU-KENYA-DANGER-SIGNS", "Recognise danger signs (caregiver)", "Seek care immediately for: grunting, nasal flaring, poor feeding, chest indrawing, central cyanosis.", "routine", 10),
    ("STEP-11", "educate", "EDU-KENYA-TREATMENT-COMPLIANCE", "Complete the antibiotic course", "Give every dose of amoxicillin for the full 5 days, even when the child looks better.", "routine", 20),
    ("STEP-11", "educate", "EDU-KENYA-RETURN-CARE", "When to return / 48h review", "Return immediately if condition worsens or no improvement within 48 hours; attend the scheduled review.", "routine", 30),
    ("STEP-12", "follow_up", "REF-KENYA-48H-REVIEW", "48-hour review / outreach", "Hard-stop review within 48h; link to community health outreach for follow-up.", "routine", 10),
]

PROTOCOL_MONITORING = [
    ("MON-SPO2", "Every clinical review; target >=95% (non-severe) / >=90% (severe)",
     "SpO2 <90% or falling despite oxygen, or rising work of breathing",
     "Reassess severity; escalate oxygen; consider referral if severe."),
    ("MON-RR", "Serial count at every review; age-appropriate tachypnoea thresholds",
     "Persistent tachypnoea or rising work of breathing",
     "Reassess severity; consider CXR/ABG; escalate."),
    ("MON-WOB", "With every clinical assessment",
     "New or worsening chest indrawing, grunting, nasal flaring, or cyanosis",
     "Rise to severe pathway; admit; give oxygen and parenteral antibiotics."),
]

EDUCATION = [
    ("EDU-KENYA-DANGER-SIGNS", "Danger signs to watch in childhood pneumonia", "caregiver",
     "instruction", "Seek care immediately if your child develops: grunting, nasal flaring, chest indrawing, poor feeding or inability to drink, or blueness of the face/lips. These can mean severe pneumonia (Kenya BPP 5th ed, p47)."),
    ("EDU-KENYA-TREATMENT-COMPLIANCE", "Complete the antibiotic course", "caregiver",
     "instruction", "Give every dose of the amoxicillin exactly as prescribed for the full 5 days. Even if your child looks better, finish the antibiotics so the infection is fully cleared (Kenya BPP 5th ed, p47)."),
    ("EDU-KENYA-RETURN-CARE", "When to return and the 48-hour review", "caregiver",
     "discharge", "Bring your child back within 48 hours for review, or sooner if they get worse, develop danger signs, or stop feeding. Early return saves lives (Kenya BPP 5th ed, p47)."),
]

GOVERNED_OBJECTS = [
    ("PROT-PNEUMONIA-KENYA-PAED", "PROTOCOL", "Kenya paediatric pneumonia management pathway (5th ed)",
     "Jurisdictional overlay for JUR-KENYA of the paediatric pneumonia management pathway: eligibility (2-59mo), danger-sign assessment, severe vs non-severe classification, investigation, severe (parenteral + refer) vs non-severe (high-dose amoxicillin 40-45 mg/kg/dose) treatment, 48h review and escalation, monitoring and caregiver education, and follow-up. Replaces the generic protocol for Kenyan children.",
     "BPP-0002", "POP-PAEDIATRIC"),
]

AMOX_DOSAGE = [
    # (medication_code, population, indication_code, route, dose_expression, dose_per_kg_min, dose_per_kg_max, frequency, verified, evidence)
    ("MED-AMOXICILLIN", "paediatric", "PNEUMONIA", "oral",
     "40-45 mg/kg/dose high-dose amoxicillin dispersible tablets (non-severe pneumonia, 5 days) - Kenya BPP 5th ed p46",
     40, 45, "every 12 hours", True, "Kenya BPP 5th ed p46"),
]


def main(out_path: str) -> None:
    w = (lambda s="": lines.append(s))  # noqa: E731
    lines: list[str] = []
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R8 Kenya paediatric pneumonia overlay")
    w("-- Jurisdictional management overlay (JUR-KENYA) for the existing universal")
    w("-- paediatric pneumonia assessment (R1/R2 danger-sign facts +")
    w("-- PHEN-PAEDIATRIC-PNEUMONIA-ALARM + condition PNEUMONIA). Grounded to the")
    w("-- Kenya Ministry of Health paediatric pneumonia guidelines (BPP 5th ed, p46-47)")
    w("-- (claims BPP-0001..0005). Adds PROT-PNEUMONIA-KENYA-PAED, the Kenya amoxicillin")
    w("-- dose (40-45 mg/kg/dose), Kenya monitoring + education, all governed ACTIVE.")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r8_pneumonia_kitp.py <out>")
    w("-- =============================================================================")
    w("")

    # 0. source tree ------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 0. knowledge.source / section / version / chapter / claim (Kenya BPP 5th ed)")
    w("--    Required so governed knowledge_object.source_claim_code FKs resolve (#46).")
    w("-- ---------------------------------------------------------------------------")
    sid, sname, stype, scope, srole, sdesc, spub, slang, sstat, syear = SOURCE
    w(f"INSERT INTO knowledge.source (source_id, source_name, edition, year, source_type, "
      f"authority_scope, amexan_role, description, language_code, status) VALUES")
    w(f"   ({sql_literal(sid)}, {sql_literal(sname)}, 5, {sql_literal(str(syear))}, {sql_literal(stype)}, "
      f"{sql_literal(scope)}, {sql_literal(srole)}, {sql_literal(sdesc)}, {sql_literal(slang)}, {sql_literal('ACTIVE_FOUNDATION')})")
    w("ON CONFLICT (source_id) DO UPDATE SET authority_scope = EXCLUDED.authority_scope, status = EXCLUDED.status;")
    w("")
    vid, vsrc, ved, vyr, vlang, vstat = VERSION
    w(f"INSERT INTO knowledge.source_version (version_id, source_id, edition, publication_year, "
      f"language, status, pdf_page_offset) VALUES")
    w(f"   ({sql_literal(vid)}, {sql_literal(vsrc)}, {ved}, {vyr}, {sql_literal(vlang)}, {sql_literal(vstat)}, 0)")
    w("ON CONFLICT (version_id) DO UPDATE SET publication_year = EXCLUDED.publication_year;")
    w("")
    seid, sevid, seno, sename, selayer, sesort = SECTION
    w(f"INSERT INTO knowledge.source_section (section_id, source_version_id, section_no, section_name, amexan_layer, sort_order) VALUES")
    w(f"   ({sql_literal(seid)}, {sql_literal(sevid)}, {seno}, {sql_literal(sename)}, {sql_literal(selayer)}, {sesort})")
    w("ON CONFLICT (section_id) DO UPDATE SET section_name = EXCLUDED.section_name;")
    w("")
    cid, cvid, csec, cno, cname, csp, cep, cramex, camex, csys, csort = CHAPTER
    w(f"INSERT INTO knowledge.source_chapter (chapter_id, source_version_id, section_id, chapter_no, chapter_name, start_page, end_page, amexan_role, amexan_context, amexan_system, sort_order) VALUES")
    w(f"   ({sql_literal(cid)}, {sql_literal(cvid)}, {sql_literal(csec)}, {cno}, {sql_literal(cname)}, {csp}, {cep}, NULL, NULL, NULL, {csort})")
    w("ON CONFLICT (chapter_id) DO UPDATE SET start_page = EXCLUDED.start_page, end_page = EXCLUDED.end_page;")
    w("")

    # 1. claims -----------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. knowledge.source_claim - Kenya BPP claims BPP-0001..0005")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.source_claim (claim_id, claim_code, source_version_id, chapter_id, chunk_id, page_start, page_end, claim_type, claim_kind, claim_text, knowledge_type, contract, is_compiled, confidence, status) VALUES")
    rows = []
    for code, page, chap, ctype, ckind, ktype, text, contract in CLAIMS:
        rows.append(
            f"   ({sql_literal(u('BPPCL:' + code))}, {sql_literal(code)}, {sql_literal(vid)}, {sql_literal(chap)}, NULL, "
            f"{sql_literal(str(page))}, {sql_literal(str(page))}, {sql_literal(ctype)}, {sql_literal(ckind)}, {sql_literal(text)}, "
            f"{sql_literal(ktype)}, {jq(contract)}::jsonb, true, 0.9, 'VERIFIED')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (claim_code) DO UPDATE SET chapter_id = EXCLUDED.chapter_id, page_start = EXCLUDED.page_start, "
      "page_end = EXCLUDED.page_end, claim_text = EXCLUDED.claim_text, contract = EXCLUDED.contract, status = EXCLUDED.status;")
    w("")

    # 2. protocol ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2. PROT-PNEUMONIA-KENYA-PAED - full 12-step Kenya paediatric pneumonia pathway")
    w("--    (JUR-KENYA overlay; a Kenya child gets this rather than the global PROT-PNEUMONIA-PAED)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.protocol (id, protocol_code, canonical_name, description, population, purpose, status, is_guideline, source_reference, configurable) VALUES")
    w(f"   ({sql_literal(u('PROT:KENYA-PNEUMONIA-PAED'))}, 'PROT-PNEUMONIA-KENYA-PAED', 'Kenya paediatric pneumonia management pathway', "
      f"'Kenya MoH BPP 5th ed p46-47: 2-59 month old with cough/difficulty breathing; danger-sign assessment, severe vs non-severe classification, parenteral (severe) vs high-dose amoxicillin 40-45 mg/kg/dose (non-severe), 48h review and escalation, monitoring and caregiver education, follow-up.', "
      f"'paediatric', 'management', 'active', true, 'Kenya BPP 5th ed p46-50', false)")
    w("ON CONFLICT (protocol_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, description = EXCLUDED.description, purpose = EXCLUDED.purpose, population = EXCLUDED.population;")
    w("")
    w("DELETE FROM knowledge.protocol_action WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED');")
    w("DELETE FROM knowledge.protocol_monitoring WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED');")
    w("DELETE FROM knowledge.protocol_step WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED');")
    w("DELETE FROM knowledge.protocol_condition WHERE protocol_id = (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED');")
    w("")
    w("INSERT INTO knowledge.protocol_condition (id, protocol_id, condition_id, is_primary) VALUES")
    w(f"   ({sql_literal(u('PC:KENYA-PNEUMONIA'))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED'), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), true)")
    w("ON CONFLICT (protocol_id, condition_id) DO UPDATE SET is_primary = EXCLUDED.is_primary;")
    w("")
    w("INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required) VALUES")
    rows = []
    for sc, label, stype, seq, instr, rat, req in PROTOCOL_STEPS:
        rows.append(
            f"   ({sql_literal(u('PSTEP:KENYA:' + sc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED'), "
            f"{sql_literal(sc)}, {sql_literal(label)}, {sql_literal(stype)}, {sql_literal(str(seq))}, {sql_literal(instr)}, {sql_literal(rat)}, {'TRUE' if req else 'FALSE'})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, step_code) DO UPDATE SET instruction = EXCLUDED.instruction, rationale = EXCLUDED.rationale, sequence_no = EXCLUDED.sequence_no, step_type = EXCLUDED.step_type;")
    w("")
    w("INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order) VALUES")
    rows = []
    for sc, atype, acode, aname, detail, urg, so in PROTOCOL_ACTIONS:
        rows.append(
            f"   ({sql_literal(u('PACT:KENYA:' + sc + ':' + acode + ':' + str(so)))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED'), "
            f"(SELECT ps.id FROM knowledge.protocol_step ps JOIN knowledge.protocol p ON p.id = ps.protocol_id WHERE p.protocol_code = 'PROT-PNEUMONIA-KENYA-PAED' AND ps.step_code = {sql_literal(sc)}), "
            f"{sql_literal(atype)}, {sql_literal(acode)}, {sql_literal(aname)}, {sql_literal(detail)}, {sql_literal(urg)}, {sql_literal(str(so))})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (step_id, action_type, action_code) DO UPDATE SET detail = EXCLUDED.detail, urgency = EXCLUDED.urgency, sort_order = EXCLUDED.sort_order;")
    w("")
    w("INSERT INTO knowledge.protocol_monitoring (id, protocol_id, monitoring_id, frequency, deterioration_rule, escalation_instruction) VALUES")
    rows = []
    for mc, freq, det, esc in PROTOCOL_MONITORING:
        rows.append(
            f"   ({sql_literal(u('PMON:KENYA:' + mc))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-PNEUMONIA-KENYA-PAED'), "
            f"(SELECT id FROM knowledge.monitoring WHERE monitoring_code = {sql_literal(mc)}), {sql_literal(freq)}, {sql_literal(det)}, {sql_literal(esc)})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (protocol_id, monitoring_id) DO UPDATE SET frequency = EXCLUDED.frequency, deterioration_rule = EXCLUDED.deterioration_rule, escalation_instruction = EXCLUDED.escalation_instruction;")
    w("")

    # 3. education -------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. knowledge.education - Kenya pneumonia caregiver education")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.concept (id, concept_code, concept_type, canonical_name, display_name, status) VALUES")
    rows = [
        f"   ({sql_literal(u('CONCEPT:' + code))}, {sql_literal('CNS-' + code)}, 'education', {sql_literal(title)}, {sql_literal(title)}, 'active')"
        for code, title, _aud, _ct, _body in EDUCATION
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (concept_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name;")
    w("")
    w("INSERT INTO knowledge.education (id, concept_id, education_code, title, audience, content_type, language_code, literacy_level, body, status) VALUES")
    rows = []
    for code, title, audience, ctype, body in EDUCATION:
        rows.append(
            f"   ({sql_literal(u('EDU:' + code))}, (SELECT id FROM knowledge.concept WHERE concept_code = {sql_literal('CNS-' + code)}), "
            f"{sql_literal(code)}, {sql_literal(title)}, {sql_literal(audience)}, {sql_literal(ctype)}, 'en', 'plain', {sql_literal(body)}, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (education_code) DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body;")
    w("")
    w("INSERT INTO knowledge.education_condition (id, education_id, condition_id, weight) VALUES")
    rows = []
    for code, _title, _aud, _ct, _body in EDUCATION:
        rows.append(
            f"   ({sql_literal(u('EDC:' + code + ':PNEUMONIA'))}, (SELECT id FROM knowledge.education WHERE education_code = {sql_literal(code)}), (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 1.0)"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (education_id, condition_id) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")

    # 4. jurisdictional amoxicillin dose (40-45 mg/kg) -------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. knowledge.drug_dose_reference - Kenya high-dose amoxicillin (40-45 mg/kg)")
    w("--    A JUR-KENYA override of the universal 50-90 row; TreatmentEngine ranks the")
    w("--    patient's jurisdiction first so a Kenyan child receives 40-45, not 50-90.")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.drug_dose_reference (id, medication_id, population, indication_code, route, dose_expression, frequency_expression, duration_expression, evidence_source, is_verified, weight_basis, dose_per_kg_min, dose_per_kg_max, jurisdiction_code) VALUES")
    rows = []
    for med, pop, ind, route, expr, dkmin, dkmax, freq, verified, ev in AMOX_DOSAGE:
        rows.append(
            f"   ({sql_literal(u('DOSE:KENYA:' + med + ':' + ind + ':' + pop))}, (SELECT id FROM knowledge.medication WHERE medication_code = {sql_literal(med)}), "
            f"{sql_literal(pop)}, {sql_literal(ind)}, {sql_literal(route)}, {sql_literal(expr)}, {sql_literal(freq)}, '5 days', {sql_literal(ev)}, "
            f"{sql_literal('TRUE' if verified else 'FALSE')}, 'mg_per_kg', {sql_literal(str(dkmin))}, {sql_literal(str(dkmax))}, 'JUR-KENYA')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (medication_id, population, indication_code, route, jurisdiction_code) DO UPDATE SET dose_expression = EXCLUDED.dose_expression, dose_per_kg_min = EXCLUDED.dose_per_kg_min, dose_per_kg_max = EXCLUDED.dose_per_kg_max, is_verified = EXCLUDED.is_verified, weight_basis = EXCLUDED.weight_basis;")
    w("")

    # 5. governance ------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 5. governance.knowledge_object - Kenya pneumonia protocol is governed ACTIVE")
    w("--    (JUR-KENYA / POP-PAEDIATRIC / EV-B). JUR-GLOBAL patients are excluded by")
    w("--    the runtime gate's jurisdiction clause, so only Kenyan children activate it.")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO governance.knowledge_object (id, object_code, knowledge_type, canonical_name, description, source_claim_code, jurisdiction_code, population_code, evidence_level_code, lifecycle_status, confidence, is_active, status) VALUES")
    rows = []
    for code, ktype, name, desc, claim, pop in GOVERNED_OBJECTS:
        rows.append(
            f"   ({sql_literal(u('GOBJ:' + code))}, {sql_literal(code)}, {sql_literal(ktype)}, {sql_literal(name)}, {sql_literal(desc)}, {sql_literal(claim)}, 'JUR-KENYA', {sql_literal(pop)}, 'EV-B', 'ACTIVE', 0.95, true, 'active')"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (object_code) DO UPDATE SET lifecycle_status = EXCLUDED.lifecycle_status, description = EXCLUDED.description, jurisdiction_code = EXCLUDED.jurisdiction_code, population_code = EXCLUDED.population_code, is_active = EXCLUDED.is_active;")
    w("")
    w("INSERT INTO governance.knowledge_object_version (id, object_id, version_no, version_code, change_note, lifecycle_status, source_claim_code, created_by)")
    w("SELECT ko.id, ko.id, 1, 'GO-V-R8-' || ko.object_code, 'R8 Kenya paediatric pneumonia overlay (BPP-0001..0005).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'")
    w("FROM governance.knowledge_object ko WHERE ko.object_code IN (" + ", ".join(sql_literal(x[0]) for x in GOVERNED_OBJECTS) + ")")
    w("ON CONFLICT (version_code) DO UPDATE SET change_note = EXCLUDED.change_note, lifecycle_status = EXCLUDED.lifecycle_status;")
    w("")
    for code, _ktype, _name, _desc, claim, _pop in GOVERNED_OBJECTS:
        w(p("governance.knowledge_object", u("GOBJ:" + code), code, claim))
    w("")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "seed_zknowledge_zqN_pneumonia_kitp.sql"
    main(out)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Wrote {out} ({len(lines)} lines)")
