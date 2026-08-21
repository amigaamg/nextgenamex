"""Curated atomic claims for the R1 respiratory vertical slice.

Two sources (registered by build_respiratory_sources.py):
  KC = KUMAR_CLARK_CM / KUMAR_CLARK_10_2017 / KC-C28 (Respiratory disease, 927-999)
  BN = NELSON_ILLUSTRATED / NELSON_ILLUSTRATED_2017 / BN-C01 (Pulmonology, 156-213)

PAGE CONVENTION: every page value is a PRINTED book page (pdf_index - offset,
offset 18 for K&C, 13 for Baby Nelson). Printed pages map 1:1 to one chunk.

claim_code prefixes: KCR-xxxx (Kumar & Clark), BNR-xxxx (Baby Nelson).
claim_kind values: definition|rule|question|red_flag|differential|examination|
  investigation|threshold|contraindication|principle|risk_factor|
  history_section|management|prognosis
knowledge_type: clinical_method|medicine|guideline_activity|reference

This file is the knowledge-authoring layer for the FIRST slice: the universal
COUGH graph (adult + paediatric capture) and PNEUMONIA across both populations.
"""
from __future__ import annotations

CLAIMS: list[dict] = [
    # ============================================================================
    # KUMAR & CLARK 10e — ch28 Respiratory disease
    # ============================================================================
    {
        "code": "KCR-0001", "source": "KC", "page": 927, "kind": "history_section", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "The core respiratory symptoms in the medical history are cough, sputum production, breathlessness, chest pain, haemoptysis and wheeze; specify the acuity of onset, the change over time and any change in symptoms with location.",
        "contract": {
            "what_is_it": "core respiratory symptom set (adult)",
            "what_connects_to": "cough graph, dyspnoea graph, haemoptysis red flags",
            "source_support": "Kumar & Clark 10e ch28 p927",
        },
    },
    {
        "code": "KCR-0002", "source": "KC", "page": 927, "kind": "history_section", "claim_type": "CLINICAL_METHOD",
        "type": "clinical_method",
        "text": "Systemic symptoms relevant to respiratory disease include weight loss, malaise and night sweats; occupational exposure, smoking history, recreational drug use, family history, childhood history and travel history are all relevant.",
        "contract": {
            "what_is_it": "systemic + exposure domains for respiratory history",
            "what_fact_produces": "WEIGHT_LOSS, TB_CONTACT, SMOKING_STATUS, SMOKING_PACK_YEARS",
            "source_support": "Kumar & Clark 10e ch28 p927",
        },
    },
    {
        "code": "KCR-0003", "source": "KC", "page": 964, "kind": "definition", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "Community-acquired pneumonia (CAP) presents with a dry or productive cough, sometimes with haemoptysis, breathlessness and fever; chest pain is commonly pleuritic due to pleural inflammation and a pleural rub may be heard early.",
        "contract": {
            "what_is_it": "CAP clinical presentation",
            "what_fact_produces": "COUGH_PRODUCTIVITY, COUGH_DURATION_DAYS, FEVER_PRESENT, CHEST_PAIN_PLEURITIC, DYSPNOEA_PRESENT",
            "source_support": "Kumar & Clark 10e ch28 p964",
        },
    },
    {
        "code": "KCR-0004", "source": "KC", "page": 964, "kind": "rule", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "A swinging fever in pneumonia may indicate empyema; in the elderly CAP can present with confusion or non-specific symptoms such as recurrent falls, so pneumonia should always be considered in sick elderly patients.",
        "contract": {
            "what_is_it": "pneumonia atypical-presentation warning",
            "what_fact_produces": "CHILLS, CONFUSION, FEVER_PRESENT",
            "source_support": "Kumar & Clark 10e ch28 p964",
        },
    },
    {
        "code": "KCR-0005", "source": "KC", "page": 964, "kind": "threshold", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "CURB-65 severity scoring: 1 point each for confusion, urea >7 mmol/L, respiratory rate >30/min, systolic BP <90 or diastolic BP <60 mmHg, age >65. Score 0-1 treat as outpatient, score 2 admit to hospital, score 3+ often requires ITU care.",
        "contract": {
            "what_is_it": "CURB-65 severity threshold (adult CAP)",
            "what_fact_produces": "RESP_RATE, CONFUSION, SYSTOLIC_BP, AGE",
            "source_support": "Kumar & Clark 10e ch28 p964",
        },
    },
    {
        "code": "KCR-0006", "source": "KC", "page": 964, "kind": "management", "claim_type": "RESPIRATORY_METHOD",
        "type": "guideline_activity",
        "text": "Mild CAP is treated at home with standard oral antibiotics (amoxicillin, or clarithromycin for penicillin allergy); chest X-ray is not routinely needed unless the patient fails to improve after 48-72 hours.",
        "contract": {
            "what_is_it": "mild CAP ambulatory management",
            "what_connects_to": "protocol action for mild CAP",
            "source_support": "Kumar & Clark 10e ch28 p964",
        },
    },
    {
        "code": "KCR-0007", "source": "KC", "page": 965, "kind": "investigation", "claim_type": "RESPIRATORY_METHOD",
        "type": "guideline_activity",
        "text": "All patients admitted with suspected CAP need a chest X-ray, blood tests and microbiological tests; radiological abnormalities can lag behind clinical signs, so a normal CXR should be repeated after 2-3 days and 6 weeks later to rule out an underlying bronchial malignancy.",
        "contract": {
            "what_is_it": "admitted CAP investigation set",
            "what_fact_produces": "CXR_OPACITY, SPUTUM_CULTURE, BLOOD_CULTURE",
            "source_support": "Kumar & Clark 10e ch28 p965",
        },
    },
    {
        "code": "KCR-0008", "source": "KC", "page": 965, "kind": "threshold", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "Arterial blood gas analysis is necessary if oxygen saturation is below 94%; supplemental oxygen should maintain saturations 94-98%, or 88-92% in patients with known COPD at risk of CO2 retention.",
        "contract": {
            "what_is_it": "oxygen target threshold",
            "what_fact_produces": "SPO2, PAO2",
            "source_support": "Kumar & Clark 10e ch28 p965",
        },
    },
    {
        "code": "KCR-0009", "source": "KC", "page": 965, "kind": "management", "claim_type": "RESPIRATORY_METHOD",
        "type": "guideline_activity",
        "text": "In severe CAP the first dose of antibiotic should be given within 1 hour of identifying high-risk criteria and must not be delayed while investigations are awaited; switch from parenteral to oral antibiotics once the temperature has settled for 24 hours.",
        "contract": {
            "what_is_it": "timely antibiotic escalation",
            "what_connects_to": "protocol step (adult CAP)",
            "source_support": "Kumar & Clark 10e ch28 p965",
        },
    },
    {
        "code": "KCR-0010", "source": "KC", "page": 965, "kind": "rule", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "Parapneumonic effusion complicates around one-third to one-half of CAP; an exudative effusion with pleural fluid pH below 7.2 is strongly suggestive of empyema, which should be drained urgently.",
        "contract": {
            "what_is_it": "effusion / empyema complication of CAP",
            "what_connects_to": "pleural effusion differential, empyema complication",
            "source_support": "Kumar & Clark 10e ch28 p965",
        },
    },
    {
        "code": "KCR-0011", "source": "KC", "page": 964, "kind": "risk_factor", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "Risk factors for community-acquired pneumonia include age under 16 or over 65 years, HIV infection, diabetes mellitus, chronic kidney disease, malnutrition, recent viral respiratory infection, smoking, excess alcohol and immunosuppressant therapy.",
        "contract": {
            "what_is_it": "CAP risk factors",
            "what_fact_produces": "AGE, SMOKING_STATUS, HIV_STATUS, DIABETES_STATUS, CKD_STATUS",
            "source_support": "Kumar & Clark 10e ch28 p964",
        },
    },
    {
        "code": "KCR-0012", "source": "KC", "page": 964, "kind": "definition", "claim_type": "RESPIRATORY_METHOD",
        "type": "medicine",
        "text": "Infection in the lung can be localized to one or more lobes (lobar pneumonia) or diffuse with lobular involvement centred on bronchi and bronchioles (bronchopneumonia); in 30-50% of CAP cases no organism is identifiable.",
        "contract": {
            "what_is_it": "CAP anatomical classification",
            "what_connects_to": "CXR lobar vs bronchopneumonia interpretation",
            "source_support": "Kumar & Clark 10e ch28 p964",
        },
    },
    # ============================================================================
    # ILLUSTRATED BABY NELSON — Pulmonology
    # ============================================================================
    {
        "code": "BNR-0001", "source": "BN", "page": 166, "kind": "definition", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "medicine",
        "text": "In children pneumonia is an infection of the lower respiratory tract involving airways and parenchyma with consolidation of the alveolar spaces; pneumonitis is lung inflammation that may or may not be associated with consolidation.",
        "contract": {
            "what_is_it": "paediatric pneumonia definition",
            "what_connects_to": "pneumonia differential (paediatric overlay)",
            "source_support": "Illustrated Baby Nelson Pulmonology p166",
        },
    },
    {
        "code": "BNR-0002", "source": "BN", "page": 166, "kind": "question", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "medicine",
        "text": "Symptoms of pneumonia in children: cough that is dry then becomes productive, dyspnoea with grunting, fever, malaise and toxaemia; abdominal pain may occur referred from lower-lobe pneumonia.",
        "contract": {
            "what_is_it": "paediatric pneumonia symptom set",
            "what_fact_produces": "COUGH_PRESENT, COUGH_PRODUCTIVITY, FEVER_PRESENT, DYSPNOEA_PRESENT, ABDO_PAIN_PRESENT",
            "source_support": "Illustrated Baby Nelson Pulmonology p166",
        },
    },
    {
        "code": "BNR-0003", "source": "BN", "page": 166, "kind": "examination", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "medicine",
        "text": "Tachypnoea is the most consistent clinical manifestation of pneumonia in children; respiratory distress is signalled by nasal flaring, chest-wall retractions (chest indrawing) and grunting.",
        "contract": {
            "what_is_it": "paediatric pneumonia cardinal signs",
            "what_fact_produces": "RESP_RATE, FAST_BREATHING, NASAL_FLARING, CHEST_INDRAWING, GRUNTING",
            "source_support": "Illustrated Baby Nelson Pulmonology p166",
        },
    },
    {
        "code": "BNR-0004", "source": "BN", "page": 166, "kind": "red_flag", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "medicine",
        "text": "Cyanosis and lethargy in pneumonia indicate severe infection, especially in infants, and warrant urgent escalation.",
        "contract": {
            "what_is_it": "paediatric pneumonia danger signal",
            "what_fact_produces": "CYANOSIS, LETHARGY",
            "source_support": "Illustrated Baby Nelson Pulmonology p166",
        },
    },
    {
        "code": "BNR-0005", "source": "BN", "page": 167, "kind": "rule", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "medicine",
        "text": "In children a large pleural effusion, lobar consolidation and a high fever at onset suggest a bacterial aetiology; interstitial pneumonia shows minimal chest findings with prolonged expiration and wheezes common.",
        "contract": {
            "what_is_it": "bacterial vs viral pneumonia distinction (child)",
            "what_fact_produces": "CXR_OPACITY, FEVER_PRESENT, WHEEZE_PRESENT",
            "source_support": "Illustrated Baby Nelson Pulmonology p167",
        },
    },
    {
        "code": "BNR-0006", "source": "BN", "page": 171, "kind": "management", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "guideline_activity",
        "text": "Supportive care of childhood pneumonia: bed rest, humidified oxygen inhalation with restricted IV fluids, symptomatic treatment (antipyretics for fever) and treatment of complications such as heart failure; oral zinc 10-20 mg/day is recommended as an add-on in developing countries.",
        "contract": {
            "what_is_it": "paediatric pneumonia supportive care",
            "what_connects_to": "protocol action (paediatric pneumonia)",
            "source_support": "Illustrated Baby Nelson Pulmonology p171",
        },
    },
    {
        "code": "BNR-0007", "source": "BN", "page": 171, "kind": "management", "claim_type": "PAEDIATRIC_RESPIRATORY",
        "type": "guideline_activity",
        "text": "Empirical antibiotics for childhood pneumonia are chosen by clinical picture, chest X-ray and age: milder cases amoxicillin 50-90 mg/kg/dose; hospitalized infants under 4 weeks IV ampicillin plus an aminoglycoside; infants 4-12 weeks IV ampicillin for 7-10 days; older children ampicillin or penicillin G if fully immunized, otherwise parenteral cefotaxime or ceftriaxone; add vancomycin or clindamycin for suspected staphylococcal infection; macrolides for Mycoplasma. Duration is 10-14 days, or 5 days if azithromycin.",
        "contract": {
            "what_is_it": "paediatric pneumonia empirical antibiotic protocol",
            "what_connects_to": "protocol step (paediatric pneumonia)",
            "source_support": "Illustrated Baby Nelson Pulmonology p171",
        },
    },
]