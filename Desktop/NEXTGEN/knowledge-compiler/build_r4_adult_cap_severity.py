"""AMEXAN Medical Knowledge Compiler - R4 adult CAP severity (CURB-65).

Adds the first STRUCTURED SEVERITY SCORING OBJECT to the respiratory vertical
slice, grounded to Kumar & Clark 10e claim KCR-0005:

  - facts: CONFUSION (coded), SYSTOLIC_BP / DIASTOLIC_BP (numeric) so the score
    is computable from captured facts (UREA and RESP_RATE already exist)
  - knowledge.severity_score SCORE-CURB65 + 5 components + 3 interpretations
  - PROT-CAP-ADULT: a 'score' step/action firing SCORE-CURB65 on the adult
    pneumonia pathway
  - governance: SCORE-CURB65 governed + provenanced to KCR-0005
  - master-matrix: mark COND-CAP severity structured (SCORE-CURB65 -> EXECUTABLE)

Run:  python build_r4_adult_cap_severity.py <out.sql>
"""
from __future__ import annotations

import json
import sys

from compiler_core import sql_literal, stable_uuid


def u(seed: str) -> str:
    return str(stable_uuid(seed))


def jq(condition: dict) -> str:
    """Emit a dict as a safe single-quoted JSON literal for ::jsonb casts."""
    return "'" + json.dumps(condition, separators=(",", ":"), ensure_ascii=False).replace("'", "''") + "'"


def c(claim_code: str) -> str:
    return f"(SELECT claim_id FROM knowledge.source_claim WHERE claim_code = {sql_literal(claim_code)})"


def p(otype: str, oid: str, ocode: str, claim: str) -> str:
    return (
        f"INSERT INTO knowledge.provenance (id, claim_id, object_type, object_id, object_code, relationship) "
        f"VALUES ({sql_literal(u('PROV:' + otype + ':' + ocode + ':' + claim))}, {c(claim)}, {sql_literal(otype)}, {sql_literal(oid)}, {sql_literal(ocode)}, 'derived_from') "
        f"ON CONFLICT (id) DO NOTHING;"
    )


# ---------------------------------------------------------------------------
# CURB-65 component definitions.
# condition jsonb is machine-evaluable by the SeverityScoreEngine:
#   {"type":"boolean",      "fact_code":"CONFUSION",  "expect":true}
#   {"type":"numeric_gt",   "fact_code":"UREA",       "threshold":7}
#   {"type":"numeric_gte",  "fact_code":"RESP_RATE",  "threshold":30}
#   {"type":"numeric_lt",   "fact_code":"SYSTOLIC_BP","threshold":90}
#   {"type":"age_gte",      "threshold":65}
# ---------------------------------------------------------------------------
CURB_COMPONENTS = [
    # code, name, condition, points, rationale, sort
    ("CURR-CONFUSION", "New mental confusion",
     {"type": "boolean", "fact_code": "CONFUSION", "expect": True}, 1,
     "Confusion is an independent predictor of mortality in CAP (KCR-0005).", 10),
    ("CURR-UREA", "Urea > 7 mmol/L",
     {"type": "numeric_gt", "fact_code": "UREA", "threshold": 7}, 1,
     "Elevated urea indicates impaired renal/perfusion status (KCR-0005).", 20),
    ("CURR-RR", "Respiratory rate >= 30/min",
     {"type": "numeric_gte", "fact_code": "RESP_RATE", "threshold": 30}, 1,
     "Tachypnoea reflects the ventilatory burden of infection (KCR-0005).", 30),
    ("CURR-BP", "Systolic BP < 90 or diastolic BP < 60 mmHg",
     {"type": "or", "conditions": [
         {"type": "numeric_lt", "fact_code": "SYSTOLIC_BP", "threshold": 90},
         {"type": "numeric_lt", "fact_code": "DIASTOLIC_BP", "threshold": 60},
     ]}, 1,
     "Hypotension signals severe sepsis / septic shock (KCR-0005).", 40),
    ("CURR-AGE", "Age >= 65 years",
     {"type": "age_gte", "threshold": 65}, 1,
     "Older age carries higher CAP mortality (KCR-0005).", 50),
]

CURB_INTERPRETATIONS = [
    # min, max, label, disposition, recommendation
    (0, 1, "Low", "Treat as outpatient",
     "Mild CAP (CURB-65 0-1): standard oral antibiotics at home (KCR-0006), no routine CXR unless no improvement at 48-72h."),
    (2, 2, "Moderate", "Admit to hospital",
     "CURB-65 2: admit to hospital for observation and parenteral therapy as indicated."),
    (3, 5, "Severe", "Admit to hospital; often requires ITU",
     "CURB-65 3+: severe CAP - first antibiotic dose within 1 hour of identifying high-risk criteria; ITU care often required (KCR-0009)."),
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R4 adult CAP severity (CURB-65)")
    w("-- Structured severity scoring object grounded to Kumar & Clark 10e (KCR-0005).")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r4_adult_cap_severity.py <out>")
    w("-- =============================================================================")
    w("")

    # 0. CURB-65 fact definitions --------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 0. clinical.fact_definition - CURB-65 components")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES")
    w("   ('CONFUSION', 'Acute confusion', 'New mental confusion - one point on the CURB-65 severity score.', 'coded', false, true),")
    w("   ('SYSTOLIC_BP', 'Systolic blood pressure', 'Systolic blood pressure in mmHg - CURB-65 component.', 'numeric', false, true),")
    w("   ('DIASTOLIC_BP', 'Diastolic blood pressure', 'Diastolic blood pressure in mmHg - CURB-65 component.', 'numeric', false, true)")
    w("ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, data_type = EXCLUDED.data_type;")
    w("")

    # 1. severity_score + components + interpretations ------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. knowledge.severity_score - SCORE-CURB65")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.severity_score (id, score_code, canonical_name, description, condition_id, population, max_score, source_reference, status) VALUES")
    w(f"   ({sql_literal(u('SCORE:CURB65'))}, 'SCORE-CURB65', 'CURB-65 severity score', "
      f"'Community-acquired pneumonia severity: 1 point each for confusion, urea >7 mmol/L, RR >=30/min, systolic BP <90 or diastolic BP <60 mmHg, age >=65. 0-1 outpatient, 2 admit, 3+ ITU.', "
      f"(SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), 'adult', 5, 'Kumar & Clark 10e (KCR-0005)', 'active')")
    w("ON CONFLICT (score_code) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, description = EXCLUDED.description, status = EXCLUDED.status, max_score = EXCLUDED.max_score;")
    w("")
    w("INSERT INTO knowledge.severity_score_component (id, score_id, component_code, component_name, condition, points, rationale, sort_order) VALUES")
    rows = []
    for code, name, cond, pts, rat, sort in CURB_COMPONENTS:
        rows.append(
            f"   ({sql_literal(u('SC:CURB65:' + code))}, {sql_literal(u('SCORE:CURB65'))}, {sql_literal(code)}, {sql_literal(name)}, "
            f"{jq(cond)}::jsonb, {sql_literal(str(pts))}, {sql_literal(rat)}, {sql_literal(str(sort))})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (score_id, component_code) DO UPDATE SET condition = EXCLUDED.condition, points = EXCLUDED.points, rationale = EXCLUDED.rationale, sort_order = EXCLUDED.sort_order;")
    w("")
    w("INSERT INTO knowledge.severity_score_interpretation (id, score_id, min_score, max_score, severity_label, disposition, recommendation) VALUES")
    rows = []
    for mn, mx, label, disp, rec in CURB_INTERPRETATIONS:
        rows.append(
            f"   ({sql_literal(u('SI:CURB65:' + str(mn) + '-' + str(mx)))}, {sql_literal(u('SCORE:CURB65'))}, "
            f"{sql_literal(str(mn))}, {sql_literal(str(mx))}, {sql_literal(label)}, {sql_literal(disp)}, {sql_literal(rec)})"
        )
    w(",\n".join(rows))
    w("ON CONFLICT (score_id, min_score, max_score) DO UPDATE SET severity_label = EXCLUDED.severity_label, disposition = EXCLUDED.disposition, recommendation = EXCLUDED.recommendation;")
    w("")
    w(p("severity_score", u("SCORE:CURB65"), "SCORE-CURB65", "KCR-0005"))
    w("")

    # 2. PROT-CAP-ADULT - add the severity scoring step -------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2. PROT-CAP-ADULT - severity scoring step + action")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.protocol_step (id, protocol_id, step_code, step_label, step_type, sequence_no, instruction, rationale, required)")
    w(f"VALUES ({sql_literal(u('PSTEP:CAP-ADULT:STEP-04A'))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-CAP-ADULT'), 'STEP-04A', 'Classify severity with CURB-65', 'assessment', 45, "
      f"'Score 1 point each for confusion, urea >7 mmol/L, RR >=30/min, SBP <90 or DBP <60 mmHg, age >=65. 0-1: outpatient; 2: admit; 3+: ITU.', "
      f"'CURB-65 guides disposition and intensity of care in CAP (KCR-0005).', true)")
    w("ON CONFLICT (protocol_id, step_code) DO UPDATE SET instruction = EXCLUDED.instruction, rationale = EXCLUDED.rationale, sequence_no = EXCLUDED.sequence_no;")
    w("")
    w("INSERT INTO knowledge.protocol_action (id, protocol_id, step_id, action_type, action_code, action_name, detail, urgency, sort_order)")
    w(f"VALUES ({sql_literal(u('PACT:CAP-ADULT:STEP-04A:SCORE-CURB65'))}, (SELECT id FROM knowledge.protocol WHERE protocol_code = 'PROT-CAP-ADULT'), "
      f"(SELECT ps.id FROM knowledge.protocol_step ps JOIN knowledge.protocol p ON p.id = ps.protocol_id WHERE p.protocol_code = 'PROT-CAP-ADULT' AND ps.step_code = 'STEP-04A'), 'score', 'SCORE-CURB65', 'CURB-65 severity score', "
      f"'Compute the CURB-65 score from captured facts and age; use it for disposition.', 'routine', 10)")
    w("ON CONFLICT (step_id, action_type, action_code) DO UPDATE SET detail = EXCLUDED.detail, sort_order = EXCLUDED.sort_order;")
    w("")

    # 3. governance + master matrix ---------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. governance.knowledge_object - SCORE-CURB65")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO governance.knowledge_object (id, object_code, knowledge_type, canonical_name, description, source_claim_code, jurisdiction_code, population_code, evidence_level_code, lifecycle_status, confidence, is_active, status) VALUES")
    w(f"   ({sql_literal(u('GOBJ:SCORE-CURB65'))}, 'SCORE-CURB65', 'INTERPRETATION', 'CURB-65 severity score', "
      f"'Adult community-acquired pneumonia severity stratification (confusion, urea, RR, BP, age). Kumar & Clark 10e.', 'KCR-0005', 'JUR-GLOBAL', 'POP-ADULT', 'EV-C', 'ACTIVE', 0.95, true, 'active')")
    w("ON CONFLICT (object_code) DO UPDATE SET lifecycle_status = EXCLUDED.lifecycle_status, description = EXCLUDED.description;")
    w("")
    w("INSERT INTO governance.knowledge_object_version (object_id, version_no, version_code, change_note, lifecycle_status, source_claim_code, created_by)")
    w("SELECT ko.id, 1, 'GO-V-R4-' || ko.object_code, 'R4 adult CAP severity release (KCR-0005).', 'ACTIVE', ko.source_claim_code, 'Dr A Otieno'")
    w("FROM governance.knowledge_object ko WHERE ko.object_code = 'SCORE-CURB65'")
    w("ON CONFLICT (version_code) DO UPDATE SET change_note = EXCLUDED.change_note, lifecycle_status = EXCLUDED.lifecycle_status;")
    w("")

    # 4. master matrix ----------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. tracking.respiratory_master_matrix - CURB-65 status")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO tracking.respiratory_master_matrix (id, family_code, family_name, item_code, item_name, population, status, source_ground, notes) VALUES")
    w(f"   ({sql_literal(u('MM:SCORE-CURB65'))}, 'B', 'Infectious respiratory disease', 'SCORE-CURB65', 'CURB-65 severity score (adult CAP)', 'A', 'EXECUTABLE', 'Kumar & Clark 10e (KCR-0005)', NULL)")
    w("ON CONFLICT (item_code) DO UPDATE SET status = EXCLUDED.status, source_ground = EXCLUDED.source_ground;")
    w("")
    w("UPDATE tracking.respiratory_master_matrix SET status='EXECUTABLE', source_ground='Kumar & Clark 10e (KCR-0005)',")
    w("       notes='Structured severity score object: SCORE-CURB65 + components + interpretations; SeverityScoreEngine computes from captured facts and age.',")
    w("       updated_at=now() WHERE item_code='SCORE-CURB65';")
    w("UPDATE tracking.respiratory_master_matrix SET status='GROUNDED', source_ground='Kumar & Clark 10e (KCR-0005)',")
    w("       notes='Adult CAP severity stratification live on the PROT-CAP-ADULT pathway.',")
    w("       updated_at=now() WHERE item_code='COND-CAP';")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(CURB_COMPONENTS)} components, {len(CURB_INTERPRETATIONS)} interpretations, 1 score object")


if __name__ == "__main__":
    main(sys.argv[1])