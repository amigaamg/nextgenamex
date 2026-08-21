"""AMEXAN Medical Knowledge Compiler - Respiratory Master Matrix.

Objective, queryable tracking table so NO item in the respiratory domain can be
silently missing or shallow. Every item in the target universe is listed with a
completeness ladder:

  MISSING -> SEEDED -> STRUCTURED -> GROUNDED -> EXECUTABLE -> VERIFIED

The ladder means (respiratory-domain rule, locked from the domain plan):
  MISSING    - no row in any knowledge table
  SEEDED     - concept/diagnosis/symptom row exists
  STRUCTURED - relationships exist (phenotype, mechanism, differential, question)
  GROUNDED   - provenance edges to source_claim (KCR-/BNR-/HCH-)
  EXECUTABLE - CPU engines can actually consume it (question selector,
               phenotype scorer, protocol engine, treatment engine, ...)
  VERIFIED   - a live test/benchmark proves the runtime behaviour

The tracking table lives in its own schema `tracking` so it never mixes with
governed clinical knowledge. It is a project instrument, not clinical truth.

Run:  python build_respiratory_master_matrix.py <out.sql>
"""
from __future__ import annotations

import sys

from compiler_core import sql_literal, stable_uuid


def u(seed: str) -> str:
    return str(stable_uuid(seed))


# ---------------------------------------------------------------------------
# Target universe: family -> list of (item_code, item_name, population)
# population: A=adult, P=paediatric, B=both
# ---------------------------------------------------------------------------
FAMILIES: list[dict[str, object]] = [
    {
        "family_code": "A",
        "family_name": "Presenting symptoms & syndromes",
        "items": [
            ("SYM-COUGH", "Cough (acute/chronic, dry/productive, haemoptysis)", "B"),
            ("SYM-DYSPNOEA", "Dyspnoea (onset, exertional threshold, orthopnoea, PND)", "B"),
            ("SYM-WHEEZE", "Wheeze (episodic, expiratory, triggers, nocturnal)", "B"),
            ("SYM-CHEST-PAIN", "Chest pain (pleuritic/non-pleuritic, exertional, positional)", "B"),
            ("SYM-HAEMOPTYSIS", "Haemoptysis (quantity, source, duration)", "B"),
            ("SYM-SPUTUM", "Sputum production (colour, amount, consistency, odour)", "B"),
            ("SYM-STRIDOR", "Stridor (inspiratory, upper-airway obstruction)", "B"),
            ("SYM-CYANOSIS", "Cyanosis (central/peripheral)", "B"),
            ("SYM-EXERCISE-INTOLERANCE", "Exercise intolerance (functional limitation)", "B"),
            ("SYM-SLEEP-BREATHING", "Sleep-related breathing symptoms (snoring, apnoea, somnolence)", "B"),
            ("SYM-HOARSENESS", "Voice change/hoarseness (laryngeal involvement)", "B"),
            ("SYM-TACHYPNOEA", "Tachypnoea (age/context dependent)", "B"),
        ],
    },
    {
        "family_code": "B",
        "family_name": "Infectious respiratory disease",
        "items": [
            ("COND-CAP", "Community-acquired pneumonia (adult)", "A"),
            ("COND-CAP-PAED", "Community-acquired pneumonia (child/infant/neonate)", "P"),
            ("COND-HAP", "Hospital-acquired pneumonia", "A"),
            ("COND-VAP", "Ventilator-associated pneumonia", "A"),
            ("COND-TB", "Pulmonary tuberculosis (adult)", "A"),
            ("COND-TB-PAED", "Pulmonary tuberculosis (child)", "P"),
            ("COND-PLEURAL-TB", "Pleural tuberculosis", "B"),
            ("COND-VIRAL-RTI", "Viral respiratory infections (influenza, COVID-19, RSV)", "B"),
            ("COND-BRONCHIOLITIS", "Bronchiolitis (infant)", "P"),
            ("COND-PERTUSSIS", "Pertussis", "B"),
            ("COND-CROUP", "Croup / acute laryngotracheobronchitis", "P"),
            ("COND-EPIGLOTTITIS", "Epiglottitis / serious upper-airway infection", "B"),
            ("COND-LUNG-ABSCESS", "Lung abscess", "B"),
            ("COND-EMPYEMA-INFECTIOUS", "Empyema (as complication of pneumonia)", "B"),
        ],
    },
    {
        "family_code": "C",
        "family_name": "Obstructive airway disease",
        "items": [
            ("COND-ASTHMA", "Asthma (adult)", "A"),
            ("COND-ASTHMA-PAED", "Asthma / recurrent wheeze / viral-induced wheeze (child)", "P"),
            ("COND-COPD", "COPD (chronic bronchitis + emphysema phenotypes)", "A"),
            ("COND-BRONCHIECTASIS", "Bronchiectasis", "B"),
            ("COND-FOREIGN-BODY", "Foreign-body aspiration (child)", "P"),
            ("COND-ANAPHYLAXIS-AIRWAY", "Anaphylaxis-related airway obstruction", "B"),
            ("COND-ACUTE-SEVERE-ASTHMA", "Acute severe asthma (life-threatening)", "B"),
            ("COND-COPD-EXACERBATION", "COPD exacerbation", "A"),
            ("COND-UPPER-AIRWAY-OBSTRUCTION", "Upper-airway obstruction", "B"),
        ],
    },
    {
        "family_code": "D",
        "family_name": "Pleural disease",
        "items": [
            ("COND-PLEURAL-EFFUSION", "Pleural effusion", "B"),
            ("COND-PARAPNEUMONIC-EFFUSION", "Parapneumonic effusion", "B"),
            ("COND-EMPYEMA", "Empyema", "B"),
            ("COND-PNEUMOTHORAX", "Pneumothorax", "B"),
            ("COND-TENSION-PNEUMOTHORAX", "Tension pneumothorax", "B"),
            ("COND-HAEMOTHORAX", "Haemothorax", "B"),
            ("COND-CHYLOTHORAX", "Chylothorax", "B"),
            ("COND-PLEURAL-MALIGNANCY", "Pleural malignancy / mesothelioma", "A"),
        ],
    },
    {
        "family_code": "E",
        "family_name": "Parenchymal / interstitial lung disease",
        "items": [
            ("COND-ILD", "Interstitial lung disease (generic)", "A"),
            ("COND-IPF", "Idiopathic pulmonary fibrosis", "A"),
            ("COND-HYPERSENSITIVITY-PNEUMONITIS", "Hypersensitivity pneumonitis", "A"),
            ("COND-SARCOIDOSIS", "Sarcoidosis", "A"),
            ("COND-CTD-ILD", "Connective-tissue-disease-associated ILD", "A"),
            ("COND-DRUG-INDUCED-LUNG", "Drug-induced lung disease", "A"),
            ("COND-ORGANISING-PNEUMONIA", "Organising pneumonia", "A"),
            ("COND-EOSINOPHILIC-LUNG", "Eosinophilic lung disease", "A"),
            ("COND-PNEUMOCONIOSIS", "Occupational pneumoconiosis", "A"),
        ],
    },
    {
        "family_code": "F",
        "family_name": "Pulmonary vascular disease",
        "items": [
            ("COND-PE", "Pulmonary embolism", "B"),
            ("COND-DVT", "Deep-vein thrombosis (thromboembolic disease)", "A"),
            ("COND-PULMONARY-HYPERTENSION", "Pulmonary hypertension", "A"),
            ("COND-CTEPH", "Chronic thromboembolic pulmonary hypertension", "A"),
            ("COND-COR-PULMONALE", "Cor pulmonale", "A"),
        ],
    },
    {
        "family_code": "G",
        "family_name": "Respiratory failure & critical illness",
        "items": [
            ("PHEN-RF-HYPOXAEMIC", "Hypoxaemic (type I) respiratory failure", "B"),
            ("PHEN-RF-HYPERCAPNIC", "Hypercapnic (type II) respiratory failure", "B"),
            ("PHEN-RF-ACUTE", "Acute respiratory failure", "B"),
            ("PHEN-RF-CHRONIC", "Chronic respiratory failure", "B"),
            ("PHEN-RF-ACUTE-ON-CHRONIC", "Acute-on-chronic respiratory failure", "B"),
            ("COND-ARDS", "ARDS (acute respiratory distress syndrome)", "A"),
            ("COND-ASPIRATION", "Aspiration pneumonitis/pneumonia", "B"),
        ],
    },
    {
        "family_code": "H",
        "family_name": "Sleep-related breathing disorders",
        "items": [
            ("COND-OSA", "Obstructive sleep apnoea", "A"),
            ("COND-CENTRAL-SLEEP-APNOEA", "Central sleep apnoea", "A"),
            ("COND-OHS", "Obesity hypoventilation syndrome", "A"),
        ],
    },
    {
        "family_code": "I",
        "family_name": "Thoracic malignancy",
        "items": [
            ("COND-LUNG-CANCER", "Lung cancer (NSCLC + SCLC)", "A"),
            ("COND-MESOTHELIOMA", "Mesothelioma", "A"),
            ("COND-ENDOBRONCHIAL-MALIGNANCY", "Endobronchial malignancy", "A"),
        ],
    },
    {
        "family_code": "J",
        "family_name": "Congenital / developmental respiratory disease",
        "items": [
            ("COND-CF", "Cystic fibrosis", "P"),
            ("COND-PCD", "Primary ciliary dyskinesia", "P"),
            ("COND-TRACHEOMALACIA", "Tracheomalacia / bronchomalacia", "P"),
            ("COND-CONGENITAL-LUNG-MALFORMATION", "Congenital lung malformations", "P"),
            ("COND-CDH", "Congenital diaphragmatic hernia / pulmonary hypoplasia", "P"),
        ],
    },
    {
        "family_code": "K",
        "family_name": "Occupational / environmental respiratory disease",
        "items": [
            ("COND-OCCUPATIONAL-ASTHMA", "Occupational asthma", "A"),
            ("COND-SILICOSIS", "Silicosis", "A"),
            ("COND-ASBESTOSIS", "Asbestosis", "A"),
            ("COND-COAL-PNEUMOCONIOSIS", "Coal workers' pneumoconiosis", "A"),
            ("COND-BIOMASS-EXPOSURE", "Biomass smoke / air pollution lung disease", "A"),
        ],
    },
    {
        "family_code": "L",
        "family_name": "Physiology knowledge",
        "items": [
            ("PHYS-VENTILATION", "Ventilation & dead space", "B"),
            ("PHYS-PERFUSION", "Perfusion & V/Q matching", "B"),
            ("PHYS-SHUNT", "Shunt", "B"),
            ("PHYS-DIFFUSION", "Diffusion & DLCO", "B"),
            ("PHYS-GAS-TRANSPORT", "O2/CO2 transport & acid-base", "B"),
            ("PHYS-MECHANICS", "Lung volumes, resistance, compliance, elastic recoil", "B"),
            ("PHYS-DRIVE", "Respiratory drive & work of breathing", "B"),
        ],
    },
    {
        "family_code": "M",
        "family_name": "Investigations universe",
        "items": [
            ("INV-BEDSIDE", "Bedside: SpO2, respiratory rate, peak flow", "B"),
            ("INV-BLOOD", "Blood: FBC, CRP, cultures, ABG, VBG, biochemistry", "B"),
            ("INV-MICRO", "Microbiology: sputum microscopy/culture, AFB, molecular TB, viral", "B"),
            ("INV-IMAGING", "Imaging: CXR, CT, HRCT, CTPA, ultrasound", "B"),
            ("INV-PFT", "Pulmonary function: spirometry, bronchodilator response, lung volumes, DLCO, PEF", "B"),
            ("INV-PROCEDURE", "Procedures: thoracentesis, bronchoscopy, BAL, pleural biopsy, lung biopsy", "B"),
        ],
    },
    {
        "family_code": "N",
        "family_name": "Procedures",
        "items": [
            ("PROC-OXYGEN", "Oxygen administration", "B"),
            ("PROC-NEBULISATION", "Nebulisation / inhaler / spacer", "B"),
            ("PROC-AIRWAY-SUCTION", "Airway suction", "B"),
            ("PROC-THORACENTESIS", "Thoracentesis", "B"),
            ("PROC-CHEST-DRAIN", "Intercostal chest drain", "B"),
            ("PROC-BRONCHOSCOPY", "Bronchoscopy", "B"),
            ("PROC-NIV", "Non-invasive ventilation", "B"),
            ("PROC-MECHANICAL-VENTILATION", "Intubation & mechanical ventilation", "B"),
        ],
    },
    {
        "family_code": "O",
        "family_name": "Drug intelligence (respiratory map)",
        "items": [
            ("DRUG-BRONCHODILATOR", "SABA / SAMA / LABA / LAMA", "B"),
            ("DRUG-ICS", "ICS / ICS-LABA / LTRA", "B"),
            ("DRUG-CORTICOSTEROID", "Systemic corticosteroids", "B"),
            ("DRUG-ANTIBIOTIC", "Antibiotics (respiratory regimens incl. anti-TB)", "B"),
            ("DRUG-ANTICOAGULANT", "Anticoagulants (VTE)", "A"),
            ("DRUG-MUCOACTIVE", "Mucolytics", "A"),
        ],
    },
    {
        "family_code": "P",
        "family_name": "Complications",
        "items": [
            ("COMP-RESP-FAILURE", "Respiratory failure", "B"),
            ("COMP-SEPSIS", "Sepsis", "B"),
            ("COMP-ARDS", "ARDS", "A"),
            ("COMP-EMPYEMA", "Empyema / lung abscess / pneumothorax", "B"),
            ("COMP-MASSIVE-HAEMOPTYSIS", "Massive haemoptysis", "B"),
            ("COMP-PH-COR-PULMONALE", "Pulmonary hypertension / cor pulmonale", "A"),
            ("COMP-BRONCHIECTASIS", "Bronchiectasis / fibrosis", "B"),
            ("COMP-MALNUTRITION", "Malnutrition / growth impairment (children)", "P"),
            ("COMP-TREATMENT-TOXICITY", "Treatment toxicity", "B"),
            ("COMP-RECURRENT-EXACERBATION", "Recurrent exacerbation / death", "B"),
        ],
    },
    {
        "family_code": "Q",
        "family_name": "Longitudinal respiratory care",
        "items": [
            ("LONG-ASTHMA", "Asthma control, step-up/step-down, exacerbation, follow-up", "B"),
            ("LONG-COPD", "COPD maintenance, exacerbation, rehabilitation", "A"),
            ("LONG-TB", "TB treatment completion, public-health follow-up", "B"),
            ("LONG-BRONCHIECTASIS", "Bronchiectasis monitoring", "B"),
            ("LONG-ILD", "ILD monitoring & therapy response", "A"),
            ("LONG-PH", "Pulmonary hypertension monitoring", "A"),
            ("LONG-SLEEP", "Sleep apnoea treatment & follow-up", "A"),
        ],
    },
]


def main(out_path: str) -> None:
    lines: list[str] = []
    w = lines.append
    w("-- =============================================================================")
    w("-- AMEXAN Medical Knowledge Compiler - Respiratory Master Matrix")
    w("-- Objective, queryable tracking of every respiratory-domain item and its")
    w("-- completeness ladder (MISSING -> SEEDED -> STRUCTURED -> GROUNDED ->")
    w("-- EXECUTABLE -> VERIFIED). A project instrument - NOT governed clinical truth.")
    w("-- GENERATED FILE - do not edit by hand. Regenerate with:")
    w("--   python knowledge-compiler/build_respiratory_master_matrix.py <out>")
    w("-- =============================================================================")
    w("")
    w("CREATE SCHEMA IF NOT EXISTS tracking;")
    w("")
    w("CREATE TABLE IF NOT EXISTS tracking.respiratory_master_matrix (")
    w("    id            uuid PRIMARY KEY,")
    w("    family_code   text NOT NULL,")
    w("    family_name   text NOT NULL,")
    w("    item_code     text NOT NULL UNIQUE,")
    w("    item_name     text NOT NULL,")
    w("    population    text NOT NULL DEFAULT 'B',")
    w("    status        text NOT NULL DEFAULT 'MISSING'")
    w("        CHECK (status IN ('MISSING','SEEDED','STRUCTURED','GROUNDED','EXECUTABLE','VERIFIED')),")
    w("    source_ground text,")
    w("    notes         text,")
    w("    updated_at    timestamptz NOT NULL DEFAULT now()")
    w(");")
    w("")
    w("INSERT INTO tracking.respiratory_master_matrix")
    w("    (id, family_code, family_name, item_code, item_name, population, status, source_ground, notes) VALUES")
    rows: list[str] = []
    for fam in FAMILIES:
        for code, name, pop in fam["items"]:  # type: ignore[union-attr]
            rows.append(
                f"   ({sql_literal(u('RMM:' + fam['family_code'] + ':' + code))}, "
                f"{sql_literal(fam['family_code'])}, {sql_literal(fam['family_name'])}, "
                f"{sql_literal(code)}, {sql_literal(name)}, {sql_literal(pop)}, 'MISSING', NULL, NULL)"
            )
    w(",\n".join(rows))
    w("ON CONFLICT (item_code) DO UPDATE SET")
    w("    item_name     = EXCLUDED.item_name,")
    w("    population    = EXCLUDED.population,")
    w("    updated_at    = now();")
    w("")

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    total = sum(len(fam["items"]) for fam in FAMILIES)  # type: ignore[union-attr]
    print(f"wrote {out_path}: {len(FAMILIES)} families, {total} tracked items (status MISSING)")


if __name__ == "__main__":
    main(sys.argv[1])
