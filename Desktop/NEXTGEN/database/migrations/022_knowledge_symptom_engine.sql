-- =============================================================================
-- AMEXAN Universal Symptom Engine — schema
-- =============================================================================
-- The symptom is the clinical knowledge object; diseases are consumers of the
-- symptom infrastructure. This migration adds the symptom-centric junction
-- tables that make a symptom fully explorable as data:
--
--   symptom_risk_factor          — what predisposes to this symptom
--   symptom_etiology             — the causal categories that produce it
--   symptom_functional_impact    — how it impairs function
--   symptom_complication         — what it can lead to
--   symptom_examination_target   — what to look for on examination
--   symptom_investigation_target — what to investigate
--   symptom_hpi_template         — data-driven history/exam prose (per fact)
--   symptom_activation_fact      — which captured fact makes a symptom active
--
-- symptom_red_flag gains a fact binding so the CPU can boost red-flag probes
-- from data instead of a hardcoded list.
-- =============================================================================

-- Risk factors that predispose to / shape a symptom ---------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_risk_factor (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id      uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    risk_factor_code text NOT NULL,
    canonical_name  text NOT NULL,
    description     text,
    category        text NOT NULL DEFAULT 'behavioural',
    relevance       numeric(3,2) NOT NULL DEFAULT 1.0,
    UNIQUE (symptom_id, risk_factor_code)
);

-- Etiologic categories that can produce a symptom ------------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_etiology (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id    uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    etiology_code text NOT NULL,
    canonical_name text NOT NULL,
    description   text,
    category      text NOT NULL DEFAULT 'infectious',
    weight        numeric(3,2) NOT NULL DEFAULT 1.0,
    UNIQUE (symptom_id, etiology_code)
);

-- Functional impacts of a symptom ----------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_functional_impact (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id            uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    functional_impact_code text NOT NULL,
    canonical_name        text NOT NULL,
    description           text,
    weight                numeric(3,2) NOT NULL DEFAULT 1.0,
    UNIQUE (symptom_id, functional_impact_code)
);

-- Complications a symptom can herald --------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_complication (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id        uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    complication_code text NOT NULL,
    canonical_name    text NOT NULL,
    description       text,
    urgency           text NOT NULL DEFAULT 'urgent'
        CHECK (urgency IN ('emergency', 'urgent', 'routine')),
    weight            numeric(3,2) NOT NULL DEFAULT 1.0,
    UNIQUE (symptom_id, complication_code)
);

-- Examination targets driven by a symptom ----------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_examination_target (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id   uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    finding_code text NOT NULL,
    priority     integer NOT NULL DEFAULT 0,
    rationale    text,
    UNIQUE (symptom_id, finding_code)
);

-- Investigation targets driven by a symptom ---------------------------------------
CREATE TABLE IF NOT EXISTS knowledge.symptom_investigation_target (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id         uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    investigation_code text NOT NULL,
    priority           integer NOT NULL DEFAULT 0,
    rationale          text,
    UNIQUE (symptom_id, investigation_code)
);

-- Data-driven documentation: one phrase per (symptom, fact, value) ----------------
-- The DocumentationEngine renders any captured fact into clinician prose by
-- looking these up; the phrase may embed a {value} placeholder for numerics.
CREATE TABLE IF NOT EXISTS knowledge.symptom_hpi_template (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id         uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    section            text NOT NULL DEFAULT 'history'
        CHECK (section IN ('history', 'examination', 'assessment')),
    fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
    fact_value         text,
    phrase_template    text NOT NULL,
    sort_order         integer NOT NULL DEFAULT 0,
    language_code      text NOT NULL DEFAULT 'en',
    is_active          boolean NOT NULL DEFAULT true,
    supersedes_fact_code text REFERENCES clinical.fact_definition(code),
    UNIQUE (symptom_id, section, fact_definition_code, fact_value)
);

-- Which captured fact makes a symptom "active" (drives the adaptive interview) ----
CREATE TABLE IF NOT EXISTS knowledge.symptom_activation_fact (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    symptom_id           uuid NOT NULL REFERENCES knowledge.symptom(id) ON DELETE CASCADE,
    fact_definition_code text NOT NULL REFERENCES clinical.fact_definition(code),
    active_value         text,
    priority             integer NOT NULL DEFAULT 0,
    UNIQUE (symptom_id, fact_definition_code)
);

-- Bind red flags to facts so the CPU can boost them from data ---------------------
ALTER TABLE knowledge.symptom_red_flag
    ADD COLUMN IF NOT EXISTS fact_definition_code text REFERENCES clinical.fact_definition(code);
