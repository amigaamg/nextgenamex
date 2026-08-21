"""AMEXAN Medical Knowledge Compiler — R2 paediatric COUGH + pneumonia population.

First respiratory knowledge-population seed: the paediatric overlay that makes
the universal COUGH graph + PNEUMONIA slice work for children end-to-end.

  - new boolean danger-sign facts (fast breathing, grunting, nasal flaring,
    poor feeding)
  - paediatric question_variant wordings for the universal cough questions
  - context_fact_mapping (lay/observed expressions -> canonical facts)
  - fact_provenance (CAREGIVER_REPORT / PARENT lawful for cough facts)
  - PAEDIATRIC_DANGER_SIGNS module: 5 child-only danger-sign questions with
    AGE context activation (QR014 covers 5-17Y; QR006 covers <5Y) and adult
    exclusion
  - red_flag_rule entries (emergency/urgent) for the danger-sign facts
  - PHEN-PAEDIATRIC-PNEUMONIA-ALARM phenotype + features + condition_phenotype
  - provenance (derived_from) edges grounded to the R1 KCR/BNR claims

Every row carries a deterministic uuid5 id so the seed is idempotent.

Run:  python build_r2_paediatric.py <out.sql>
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


def jval(v: str) -> str:
    """Emit a JSON-literal for phenotype_feature.value (jsonb column).

    Postgres casts the SQL string literal to jsonb: 'true'::jsonb -> boolean,
    '90'::jsonb -> number, '"YES"'::jsonb -> string.
    """
    if v in ("true", "false"):
        return sql_literal(v)
    try:
        float(v)
        return sql_literal(v)
    except ValueError:
        return sql_literal('"' + v + '"')


DANGER_QUESTIONS = [
    {
        "q": "PAEDIATRIC_CHEST_INDRAWING",
        "fact": "CHEST_INDRAWING",
        "text": "Is there chest indrawing (ribs or tummy pulling in with each breath)?",
        "claim": "BNR-0003",
    },
    {
        "q": "PAEDIATRIC_GRUNTING",
        "fact": "GRUNTING",
        "text": "Is the child grunting with each breath?",
        "claim": "BNR-0003",
    },
    {
        "q": "PAEDIATRIC_NASAL_FLARING",
        "fact": "NASAL_FLARING",
        "text": "Are the nostrils flaring when the child breathes?",
        "claim": "BNR-0003",
    },
    {
        "q": "PAEDIATRIC_FAST_BREATHING",
        "fact": "FAST_BREATHING",
        "text": "Is the child breathing much faster than usual for their age?",
        "claim": "BNR-0003",
    },
    {
        "q": "PAEDIATRIC_POOR_FEEDING",
        "fact": "POOR_FEEDING",
        "text": "Is the child feeding poorly or refusing feeds?",
        "claim": "BNR-0004",
    },
]

VARIANTS = [
    ("COUGH_PRODUCTIVITY", "child", "Is the cough wet (brings up phlegm or mucus) or dry?", "CAREGIVER_REPORT", "PARENT", "BNR-0002"),
    ("COUGH_PRODUCTIVITY", "infant", "Is the cough rattly and chesty, or dry and hacking?", "CAREGIVER_REPORT", "CAREGIVER", "BNR-0002"),
    ("COUGH_CHARACTER", "child", "What does the cough sound like?", "CAREGIVER_REPORT", "PARENT", "BNR-0002"),
    ("COUGH_TRIGGERS", "child", "What makes the cough worse - running, feeding, or lying down?", "CAREGIVER_REPORT", "PARENT", "BNR-0002"),
    ("COUGH_TIMING", "child", "Is the cough worse at night or first thing in the morning?", "CAREGIVER_REPORT", "PARENT", "BNR-0002"),
    ("COUGH_SEVERITY", "child", "How much is the cough bothering the child?", "CAREGIVER_REPORT", "PARENT", "BNR-0002"),
    ("COUGH_SEVERITY", "infant", "Does the cough stop the baby from feeding or sleeping?", "CAREGIVER_REPORT", "CAREGIVER", "BNR-0002"),
]

FACT_PROVENANCE = [
    ("COUGH_PRODUCTIVITY", "BNR-0002"),
    ("COUGH_CHARACTER", "BNR-0002"),
    ("COUGH_TRIGGERS", "BNR-0002"),
    ("COUGH_TIMING", "BNR-0002"),
    ("COUGH_SEVERITY", "BNR-0002"),
    ("SPUTUM_COLOUR", "KCR-0001"),
    ("GRUNTING", "BNR-0003"),
    ("NASAL_FLARING", "BNR-0003"),
    ("FAST_BREATHING", "BNR-0003"),
    ("POOR_FEEDING", "BNR-0004"),
    ("CHEST_INDRAWING", "BNR-0003"),
]

CFM = [
    ("CFM-PAED-001", "CHILD", "wet cough", "COUGH_PRODUCTIVITY", "PRODUCTIVE", "strong", "BNR-0002"),
    ("CFM-PAED-002", "INFANT", "rattly chest", "COUGH_PRODUCTIVITY", "PRODUCTIVE", "strong", "BNR-0002"),
    ("CFM-PAED-003", "CHILD", "cough brings up phlegm", "COUGH_PRODUCTIVITY", "PRODUCTIVE", "strong", "BNR-0002"),
    ("CFM-PAED-004", "CHILD", "dry hacking cough", "COUGH_PRODUCTIVITY", "NON_PRODUCTIVE", "moderate", "BNR-0002"),
    ("CFM-PAED-005", "INFANT", "chest pulls in when breathing", "CHEST_INDRAWING", "true", "strong", "BNR-0003"),
]

RED_FLAGS = [
    ("RFR-PAED-FAST-BREATHING", "FAST_BREATHING", "urgent", "BNR-0003"),
    ("RFR-PAED-GRUNTING", "GRUNTING", "emergency", "BNR-0003"),
    ("RFR-PAED-NASAL-FLARING", "NASAL_FLARING", "urgent", "BNR-0003"),
    ("RFR-PAED-POOR-FEEDING", "POOR_FEEDING", "urgent", "BNR-0004"),
]

PHEN_FEATURES = [
    ("GRUNTING", "eq", "true", 1.50, "BNR-0003"),
    ("CHEST_INDRAWING", "eq", "true", 1.50, "BNR-0003"),
    ("NASAL_FLARING", "eq", "true", 1.20, "BNR-0003"),
    ("FAST_BREATHING", "eq", "true", 1.20, "BNR-0003"),
    ("POOR_FEEDING", "eq", "true", 1.00, "BNR-0004"),
    ("SPO2", "lte", "90", 1.80, "BNR-0004"),
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - R2 paediatric COUGH + pneumonia seed")
    w("-- Paediatric overlay on the universal COUGH graph + PNEUMONIA slice.")
    w("-- Grounds every object to the R1 respiratory claims (KCR/BNR) via provenance.")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_r2_paediatric.py <out>")
    w("-- =============================================================================")
    w("")

    # 1. new boolean fact definitions -------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 1. clinical.fact_definition - paediatric danger-sign facts (boolean)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO clinical.fact_definition (code, name, description, data_type, allow_multiple, is_active) VALUES")
    rows = [
        ("FAST_BREATHING", "Fast breathing (tachypnoea)", "Child breathes much faster than usual for age; the most consistent clinical manifestation of pneumonia in children."),
        ("GRUNTING", "Grunting with respiration", "Audible grunting at the end of each breath, a sign of respiratory distress in children."),
        ("NASAL_FLARING", "Nasal flaring", "Flaring of the nostrils with breathing, a sign of respiratory distress in children."),
        ("POOR_FEEDING", "Poor feeding / reduced intake", "Child feeds poorly or refuses feeds, a danger signal in severe childhood illness."),
    ]
    w(",\n".join(
        f"   ({sql_literal(code)}, {sql_literal(name)}, {sql_literal(desc)}, 'boolean', false, true)"
        for code, name, desc in rows
    ))
    w("ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, data_type = EXCLUDED.data_type;")
    w("")
    for code, _n, _d in rows:
        w(p("fact_definition", u("FACT:" + code), code, "BNR-0003"))
    w("")

    # 2. paediatric question_variant wordings ------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 2. knowledge.question_variant - paediatric wordings for universal cough questions")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.question_variant (id, question_id, context, language_code, wording, is_active, response_mode, historian_type, priority_delta, is_disabled) VALUES")
    rows = [
        f"   ({sql_literal(u('QV:' + q + ':' + ctx))}, (SELECT id FROM knowledge.question WHERE question_code = {sql_literal(q)}), {sql_literal(ctx)}, 'en', {sql_literal(wording)}, true, {sql_literal(mode)}, {sql_literal(hist)}, 0, false)"
        for q, ctx, wording, mode, hist, _cl in VARIANTS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET wording = EXCLUDED.wording, response_mode = EXCLUDED.response_mode, historian_type = EXCLUDED.historian_type;")
    w("")
    for q, ctx, _wording, mode, hist, claim in VARIANTS:
        w(p("question_variant", u("QV:" + q + ":" + ctx), q + ":" + ctx, claim))
    w("")

    # 3. context_fact_mapping ----------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 3. knowledge.context_fact_mapping - lay/observed paediatric expressions -> canonical facts")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.context_fact_mapping (mapping_code, context_code, raw_expression, target_type, target_code, canonical_value, strength, description, status) VALUES")
    rows = [
        f"   ({sql_literal(mc)}, {sql_literal(ctx)}, {sql_literal(raw)}, 'fact_definition', {sql_literal(tgt)}, {sql_literal(val)}, {sql_literal(strength)}, {sql_literal('Paediatric capture of canonical fact ' + tgt)}, 'active')"
        for mc, ctx, raw, tgt, val, strength, _cl in CFM
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (mapping_code) DO UPDATE SET raw_expression = EXCLUDED.raw_expression, canonical_value = EXCLUDED.canonical_value, strength = EXCLUDED.strength;")
    w("")
    for mc, _ctx, _raw, _tgt, _val, _strength, claim in CFM:
        w(p("context_fact_mapping", u("CFM:" + mc), mc, claim))
    w("")

    # 4. fact_provenance ---------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 4. knowledge.fact_provenance - CAREGIVER_REPORTED / PARENT lawful capture of cough + danger facts")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.fact_provenance (fact_definition_code, capture_method_code, historian_type_code, min_reliability_code, is_valid, evidence_claim_code) VALUES")
    rows = [
        f"   ({sql_literal(fc)}, 'CAREGIVER_REPORTED', 'PARENT', 'GOOD', true, {sql_literal(cl)})"
        for fc, cl in FACT_PROVENANCE
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (fact_definition_code, capture_method_code, historian_type_code, min_reliability_code) DO UPDATE SET is_valid = EXCLUDED.is_valid, evidence_claim_code = EXCLUDED.evidence_claim_code;")
    w("")
    for fc, cl in FACT_PROVENANCE:
        w(p("fact_provenance", u("FPROV:" + fc), fc, cl))
    w("")

    # 5. PAEDIATRIC_DANGER_SIGNS module + questions -------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 5. PAEDIATRIC_DANGER_SIGNS module (child-only, adult-excluded)")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.question_module (module_code, module_name, description, status) VALUES")
    w("   ('PAEDIATRIC_DANGER_SIGNS', 'Paediatric danger signs', 'Child-only severe-disease recognition questions (fast breathing, chest indrawing, grunting, nasal flaring, poor feeding).', 'active')")
    w("ON CONFLICT (module_code) DO UPDATE SET module_name = EXCLUDED.module_name;")
    w("")
    w("INSERT INTO knowledge.question (id, question_code, question_type, text, response_type, priority, is_active, question_mode) VALUES")
    rows = [
        f"   ({sql_literal(u('Q:' + d['q']))}, {sql_literal(d['q'])}, 'clinical', {sql_literal(d['text'])}, 'single_choice', 45, true, 'DIRECT')"
        for d in DANGER_QUESTIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET text = EXCLUDED.text, priority = EXCLUDED.priority;")
    w("")

    w("INSERT INTO knowledge.answer_option (id, question_id, answer_code, label, sort_order, is_active) VALUES")
    rows = []
    for d in DANGER_QUESTIONS:
        qid = f"(SELECT id FROM knowledge.question WHERE question_code = {sql_literal(d['q'])})"
        rows.append(f"   ({sql_literal(u('AO:' + d['q'] + ':YES'))}, {qid}, 'YES', 'Yes', 1, true)")
        rows.append(f"   ({sql_literal(u('AO:' + d['q'] + ':NO'))}, {qid}, 'NO', 'No', 2, true)")
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, sort_order = EXCLUDED.sort_order;")
    w("")

    w("INSERT INTO knowledge.fact_mapping (id, answer_option_id, fact_definition_code, value, is_active) VALUES")
    rows = []
    for d in DANGER_QUESTIONS:
        for ans, val in (("YES", "true"), ("NO", "false")):
            rows.append(
                f"   ({sql_literal(u('FM:' + d['q'] + ':' + ans))}, {sql_literal(u('AO:' + d['q'] + ':' + ans))}, {sql_literal(d['fact'])}, {sql_literal(val)}, true)"
            )
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET fact_definition_code = EXCLUDED.fact_definition_code, value = EXCLUDED.value;")
    w("")

    w("INSERT INTO knowledge.question_trigger (id, question_id, trigger_type, trigger_code, priority) VALUES")
    rows = []
    for d in DANGER_QUESTIONS:
        qid = f"(SELECT id FROM knowledge.question WHERE question_code = {sql_literal(d['q'])})"
        rows.append(f"   ({sql_literal(u('QT:' + d['q'] + ':cough'))}, {qid}, 'symptom', 'cough', 30)")
        rows.append(f"   ({sql_literal(u('QT:' + d['q'] + ':fever'))}, {qid}, 'symptom', 'fever', 30)")
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET trigger_code = EXCLUDED.trigger_code, priority = EXCLUDED.priority;")
    w("")

    w("INSERT INTO knowledge.question_context (id, question_id, context_type_code, context_value_id, applicability, priority) VALUES")
    rows = []
    for d in DANGER_QUESTIONS:
        qid = f"(SELECT id FROM knowledge.question WHERE question_code = {sql_literal(d['q'])})"
        for bucket in ("18-64Y", "65P"):
            rows.append(
                f"   ({sql_literal(u('QC:' + d['q'] + ':' + bucket))}, {qid}, 'AGE', (SELECT id FROM knowledge.context_value WHERE context_type_code = 'AGE' AND value = {sql_literal(bucket)}), 'excludes', 0)"
            )
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET context_value_id = EXCLUDED.context_value_id, applicability = EXCLUDED.applicability;")
    w("")

    w("INSERT INTO knowledge.question_module_member (id, module_code, question_id) VALUES")
    rows = [
        f"   ({sql_literal(u('QMM:PAEDIATRIC_DANGER_SIGNS:' + d['q']))}, 'PAEDIATRIC_DANGER_SIGNS', (SELECT id FROM knowledge.question WHERE question_code = {sql_literal(d['q'])}))"
        for d in DANGER_QUESTIONS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET module_code = EXCLUDED.module_code;")
    w("")

    w("INSERT INTO knowledge.question_rule (rule_id, rule_name, trigger_type, trigger_code, trigger_operator, trigger_value, action, target_type, target_code, priority_delta, rationale, context, version, status) VALUES")
    w("   ('QR014', 'AGE 5-17Y activates paediatric danger-sign module', 'context', 'AGE', 'in', '[\"5-17Y\"]', 'ACTIVATE', 'module', 'PAEDIATRIC_DANGER_SIGNS', 500, 'School-age children: danger-sign recognition must rank with the core cough branch (complements QR006 which covers <5Y).', NULL, 1, 'active')")
    w("ON CONFLICT (rule_id) DO UPDATE SET trigger_value = EXCLUDED.trigger_value, priority_delta = EXCLUDED.priority_delta;")
    w("")
    w(p("question_module", u("MOD:PAEDIATRIC_DANGER_SIGNS"), "PAEDIATRIC_DANGER_SIGNS", "BNR-0003"))
    w(p("question_rule", u("QRULE:QR014"), "QR014", "BNR-0003"))
    for d in DANGER_QUESTIONS:
        w(p("question", u("Q:" + d["q"]), d["q"], d["claim"]))
    w("")

    # 6. red_flag_rule ------------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 6. knowledge.red_flag_rule - paediatric danger-sign safety probes")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.red_flag_rule (rule_id, rule_code, symptom_id, fact_definition_code, clinical_significance, urgency, priority, evidence_claim_code, status) VALUES")
    rows = [
        f"   ({sql_literal(rc)}, {sql_literal(rc)}, (SELECT id FROM knowledge.symptom WHERE symptom_code = 'SYM-COUGH'), {sql_literal(fc)}, 'Paediatric severe-disease recognition', {sql_literal(urg)}, 10, {sql_literal(cl)}, 'active')"
        for rc, fc, urg, cl in RED_FLAGS
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (rule_id) DO UPDATE SET urgency = EXCLUDED.urgency, evidence_claim_code = EXCLUDED.evidence_claim_code;")
    w("")
    for rc, fc, urg, cl in RED_FLAGS:
        w(p("red_flag_rule", u("RF:" + rc), rc, cl))
    w("")

    # 7. phenotype -----------------------------------------------------------------------
    w("-- ---------------------------------------------------------------------------")
    w("-- 7. PHEN-PAEDIATRIC-PNEUMONIA-ALARM phenotype + features + condition_phenotype")
    w("-- ---------------------------------------------------------------------------")
    w("INSERT INTO knowledge.phenotype (id, phenotype_code, canonical_name, description, status) VALUES")
    w(f"   ({sql_literal(u('PHEN:PAEDIATRIC-PNEUMONIA-ALARM'))}, 'PHEN-PAEDIATRIC-PNEUMONIA-ALARM', 'Paediatric pneumonia danger signs', 'Child with cough or fever plus any pneumonia danger sign (fast breathing, chest indrawing, grunting, nasal flaring, poor feeding, low SpO2).', 'active')")
    w("ON CONFLICT (id) DO UPDATE SET canonical_name = EXCLUDED.canonical_name, description = EXCLUDED.description;")
    w("")
    w("-- rebuild feature set: the alarm fires ONLY on danger signs, never on fever/cough alone")
    w("DELETE FROM knowledge.phenotype_feature WHERE phenotype_id = " + sql_literal(u("PHEN:PAEDIATRIC-PNEUMONIA-ALARM")) + ";")
    w("INSERT INTO knowledge.phenotype_feature (id, phenotype_id, feature_type, feature_code, operator, value, weight, polarity) VALUES")
    rows = [
        f"   ({sql_literal(u('PF:PAEDIATRIC-PNEUMONIA-ALARM:' + fc + ':' + op + ':' + val))}, {sql_literal(u('PHEN:PAEDIATRIC-PNEUMONIA-ALARM'))}, 'fact', {sql_literal(fc)}, {sql_literal(op)}, {jval(val)}::jsonb, {sql_literal(f'{wgt:.2f}')}, 'positive')"
        for fc, op, val, wgt, _cl in PHEN_FEATURES
    ]
    w(",\n".join(rows))
    w("ON CONFLICT (id) DO UPDATE SET weight = EXCLUDED.weight, polarity = EXCLUDED.polarity;")
    w("")
    w("INSERT INTO knowledge.condition_phenotype (id, condition_id, phenotype_id, weight, is_suggestive) VALUES")
    w(f"   ({sql_literal(u('CP:PAEDIATRIC-PNEUMONIA-ALARM:PNEUMONIA'))}, (SELECT id FROM knowledge.condition WHERE condition_code = 'PNEUMONIA'), {sql_literal(u('PHEN:PAEDIATRIC-PNEUMONIA-ALARM'))}, 1.2, true)")
    w("ON CONFLICT (id) DO UPDATE SET weight = EXCLUDED.weight;")
    w("")
    w(p("phenotype", u("PHEN:PAEDIATRIC-PNEUMONIA-ALARM"), "PHEN-PAEDIATRIC-PNEUMONIA-ALARM", "BNR-0003"))
    w(p("condition_phenotype", u("CP:PAEDIATRIC-PNEUMONIA-ALARM:PNEUMONIA"), "PHEN-PAEDIATRIC-PNEUMONIA-ALARM", "BNR-0003"))
    for fc, op, val, wgt, cl in PHEN_FEATURES:
        w(p("phenotype_feature", u("PF:PAEDIATRIC-PNEUMONIA-ALARM:" + fc + ":" + op + ":" + val), "PF:" + fc, cl))

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {out_path}: {len(DANGER_QUESTIONS)} danger questions, {len(VARIANTS)} variants, {len(PHEN_FEATURES)} phenotype features, {len(FACT_PROVENANCE)} fact-provenance rows, {len(RED_FLAGS)} red flags")


if __name__ == "__main__":
    main(sys.argv[1])