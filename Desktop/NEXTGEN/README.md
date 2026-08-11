# AMEXAN — Phase 1: Universal PostgreSQL Foundation

A fresh, from-scratch PostgreSQL foundation for AMEXAN, a universal healthcare
operating system. Phase 1 builds the **universal structured memory and
configuration substrate** — no disease logic, no phenotype rules, no drug
intelligence. Those belong to Phase 2+ (the knowledge layer).

## Architectural law

> - **PostgreSQL** stores *state and relationships*.
> - **The knowledge layer** stores *medical knowledge*.
> - **The CPU** performs *reasoning/orchestration*.
> - **The UI** displays *projections of state*.
> - **Documents** express *clinical state in human language*.
> - **External APIs** exchange *standardized representations*.

## Schemas

| Schema            | Purpose                                          |
| ----------------- | ------------------------------------------------ |
| `identity`        | universal persons, accounts, contacts, addresses |
| `organization`    | orgs, facilities, departments, workforce         |
| `security`        | roles, permissions, access, API clients          |
| `terminology`     | concepts, code systems, mappings, value sets     |
| `patient`         | the longitudinal patient record                  |
| `encounter`       | every clinical contact                           |
| `clinical`        | atomic facts, observations, problems, orders     |
| `workflow`        | how work moves                                   |
| `scheduling`      | appointments, schedules, check-in                |
| `document`        | documents as projections of clinical state       |
| `configuration`   | scoped, inheritable configuration                |
| `audit`           | who did what, when, to what, and what changed    |
| `interoperability`| FHIR / external system exchange                  |
| `communication`   | messages, notifications, delivery                |
| `system`          | AMEXAN itself                                    |
| `knowledge`       | medical knowledge graph (Phase 1E)               |

## Migrations

| File                                         | Contents                                    |
| -------------------------------------------- | ------------------------------------------- |
| `database/00_bootstrap.sql`                  | role + database creation (run manually)     |
| `database/migrations/001_identity.sql`       | identity schema                             |
| `database/migrations/002_organization.sql`   | organization + security + terminology       |
| `database/migrations/003_patient_encounter.sql` | patient + encounter schemas              |
| `database/migrations/004_clinical.sql`       | clinical primitives                         |
| `database/migrations/005_workflow_document.sql` | workflow + scheduling + document          |
| `database/migrations/006_platform.sql`       | configuration, audit, interop, communication, system |
| `database/seed/seed_reference.sql`           | reference/lookup data                       |
| `database/migrations/007-017_knowledge_*.sql`| knowledge graph (concepts, symptoms, questions, rules, phenotypes, mechanisms, conditions, investigations, monitoring, education, medications, protocols) |
| `database/migrations/018-020_cpu_*.sql`      | CPU runtime ledger (events, decisions, state snapshots), safety facts, result interpretation, overrides |
| `database/migrations/021_knowledge_question_fact.sql` | binds raw-value questions (numeric/text/date) to fact definitions |
| `database/migrations/022_knowledge_symptom_engine.sql` | symptom-centric junction tables (etiology, risk, HPI templates, activation) |
| `database/migrations/023_knowledge_hpi_documentation_group.sql` | `documentation_group` on HPI templates |
| `database/migrations/024_knowledge_hpi_documentation_groups.sql` | full internal-medicine HPI group order (adds chronology, previous, health_seeking, severity) |
| `database/migrations/025_knowledge_source_compiler.sql` | Medical Knowledge Compiler H1 (locked spec): source → version → section → chapter → chunk → claim + `extraction_job` + `provenance` bridge |
| `database/migrations/026_h2_universal_history_ontology.sql` | Medical Knowledge Compiler H2 (universal history ontology): `history_concept`, `symptom_history_dimension`, `history_context_rule`, `question_variant`, `question_priority_rule`, `functional_impact`, three-state `fact_value.value_state` (TRUE/FALSE/UNKNOWN vs NOT_ASKED), `clinical_event` timeline, `patient_perspective` (IDEA/CONCERN/EXPECTATION/GOAL), `history_reliability`, `question.history_concept_id` + `question_mode` |
| `database/migrations/027_h3_question_rule_engine.sql` | Medical Knowledge Compiler H3 (question & rule engine): `question_rule` (fact/context triggers → ACTIVATE/DEACTIVATE question/symptom/module), `question_module` + `question_module_member`, `question_dependency` (blocking prerequisites), `question_rationale` (clinical/safety/differential/documentation/context/educational), `question_differential_weight` (condition-scored answers), `documentation_requirement` (per-section required facts), `history_completion_rule` (and/or completion tree), plus `question_requirement` level CHECK extended with `safety` + `high_priority` |
| `database/migrations/028_h4_universal_symptom_dimensions.sql` | Medical Knowledge Compiler H4 (universal symptom dimensions): `symptom_dimension` canonical 25-dimension registry (SD001-SD025, universal vs conditional), `symptom_dimension_option` (symptom-specific controlled vocabularies), `red_flag_rule` (FACT + CONTEXT + CLINICAL_SIGNIFICANCE, urgency tiers), `exposure_concept` (15 reusable exposure classes) + `symptom_exposure`, and `symptom_relationship.diagnostic_weight` (hard-vs-soft symptoms) |
| `database/seed/seed_zknowledge_zpc_*.sql`     | cough clinical object (etiology, risk, impact, HPI templates) |
| `database/seed/seed_zknowledge_zpd_*.sql`     | full HPI narrative groups (chronology, previous, health_seeking, severity) |
| `database/seed/seed_zknowledge_zpe_hutchison_source.sql` | compiled Hutchison 24e source map — source/version/section/chapter/chunk/extraction_job (generated) |
| `database/seed/seed_zknowledge_zpf_hutchison_claims.sql` | compiled Hutchison claims ch 1/2/12 — `HC-000001..`, `H1-Cxx`, printed pages (generated) |
| `database/seed/seed_zknowledge_zq1_history_concepts.sql` | H2 universal history vocabulary — `history_concept` HC001..HC057 (28 universal + 29 symptom dimensions), 9 `functional_impact` domains, symptom dimension maps (cough/chest pain/dyspnoea/fever/abdo pain), `provenance` H1→H2 derivation edges |
| `database/seed/seed_zknowledge_zq2_history_engine.sql` | H2 universal question engine — 5 universal questions (Q001-Q005) with `question_mode` (OPEN/DIRECT/SCALE), `question_variant` context/language wordings (QV001+), `question_priority_rule` P001-P010, `history_context_rule` R001-R007 |
| `database/seed/seed_zknowledge_zq3_question_rule_engine.sql` | H3 engine content — 10 `question_module`s (COUGH_CORE, SPUTUM, DYSPNOEA, CHEST_PAIN, FEVER, CHRONIC_COUGH, HAEMOPTYSIS, PAEDIATRIC_RESPIRATORY, ADULT_RESPIRATORY, PREGNANCY_CONTEXT), 36 members, 13 `question_rule`s QR001-QR013 (cough/dyspnoea/haemoptysis/fever/context modules), 13 `question_dependency`s (blocking sputum/dyspnoea/fever/chest-pain probes), 12 `question_rationale`s, 18 `question_differential_weight`s (vs PNEUMONIA, TUBERCULOSIS, HEART-FAILURE, ASTHMA, ACUTE-BRONCHITIS, GERD), 9 `documentation_requirement`s (HPI/RED_FLAGS), 2 `history_completion_rule`s (HCR-COUGH, HCR-CHEST-PAIN), 7 `question_requirement` safety/high_priority rows, 67 `provenance` edges — all sourced from H1/H12 claims |
| `database/seed/seed_zknowledge_zq4_question_engine_worked_example.sql` | H3 worked example — makes the L1 universal foundation askable: binds Q001-Q005 to universal facts (REASON_PRESENTATION, SYMPTOM_ONSET_TEXT, SYMPTOM_DURATION_DAYS, SYMPTOM_SEVERITY_SCORE, SYMPTOM_ASSOCIATED_TEXT), marks them MANDATORY, adds provenance |
| `database/seed/seed_zknowledge_zq5_symptom_dimensions.sql` | H4 universal symptom grammar — 25 canonical dimensions (SD001-SD025) + 9 new history_concept rows (HC058-HC066: presence, distribution, systemic impact, red flag, previous episodes/treatment, treatment response, evolution, resolution), 25 symptom-specific option vocabularies (cough/chest-pain/abdo character, radiation), 10 red-flag rules (RFR-*, emergency/urgent, sourced to H1/H12 claims), 15 exposure concepts + 21 symptom→exposure maps, 9 hard-vs-soft diagnostic weights, 67 provenance edges |

## Knowledge compiler

`knowledge-compiler/` turns authoritative sources into provenance-backed SQL seeds (H1-H4 done). The locked H1 hierarchy is:

```
source (HUTCHISON_CM) → version (HUTCHISON_24_2018)
  → section (H1-S1..H1-S4)  [UNIVERSAL / CONTEXT / SYSTEM / NAVIGATION_ONLY]
  → chapter (H1-C01..H1-C21) [AMEXAN role / context / system]
  → chunk (raw page text) → claim (HC-000001..) → extraction_job (EXT-H01..)
```

**Page convention:** the raw PDF extraction and TOC carry 1-based PDF page
indices. Printed book page numbers are offset by 11 (`printed = pdf_index - 11`,
e.g. ch1 PDF p14 → printed p3, ch12 PDF p178 → printed p167). All page columns
store **printed** pages; the offset is recorded on `knowledge.source_version.pdf_page_offset`.

Regenerate:

```powershell
python knowledge-compiler/build_h1_source.py <toc.txt> <full.txt> database/seed/seed_zknowledge_zpe_hutchison_source.sql
python knowledge-compiler/build_h2_claims.py <toc.txt> <full.txt> database/seed/seed_zknowledge_zpf_hutchison_claims.sql
```

## Running

```powershell
# one-shot: create DB, run migrations, seed, run acceptance test
.\scripts\run_all.ps1

# individual steps
.\scripts\run_migrations.ps1
.\scripts\seed.ps1
.\scripts\run_acceptance.ps1
.\scripts\run_machine_test.ps1

# drop and recreate the whole database
.\scripts\reset.ps1
```

Connection defaults (override via env vars):

| Env var                  | Default              |
| ------------------------ | -------------------- |
| `AMEXAN_PGHOST`          | `localhost`          |
| `AMEXAN_PGPORT`          | `5432`               |
| `AMEXAN_PGSUPERUSER`     | `postgres`           |
| `AMEXAN_PGSUPERPASSWORD` | `postgres`           |
| `AMEXAN_PGDATABASE`      | `amexan`             |
| `AMEXAN_PGROLE`          | `amexan`             |
| `AMEXAN_PGROLEPASSWORD`  | `amexan`             |

## Question engine (H3)

The CPU (`clinical-cpu/src/questions/QuestionSelector.ts`) turns the H3 tables into
an adaptive "next best question" queue. Ordering combines mandatory levels,
symptom activation, blocking dependencies, and module rules:

| Level              | Rank | Meaning                                              |
| ------------------ | ---- | ---------------------------------------------------- |
| `safety`           | 0    | red-flag probes always first (e.g. haemoptysis)      |
| `mandatory`        | 1    | L1 universal foundation + symptom-cardinal probes    |
| `conditionally_required` | 2 | required once their gating fact is present         |
| `high_priority`    | 3    | clinically important but conditional                 |
| `optional`         | 4    | fill-in depth                                        |
| `informational`    | 5    | non-essential                                        |

Within a level, score = rank·1000 + question priority − info gain − safety
boost − H3 rule delta (ACTIVATE pulls up). A fired `question_rule` with
DEACTIVATE suppresses its target; a blocking `question_dependency` that is not
yet satisfied hides its question. `question_requirement` conditions only rule a
question *out* (dry cough hides sputum probes; unknown gating fact never
suppresses). The L1 universal foundation (Q001-Q005) is always asked first.

The safety boost is **H4-driven**: the CPU reads `knowledge.red_flag_rule`
(FACT + CONTEXT + CLINICAL_SIGNIFICANCE) instead of a hardcoded list —
emergency-tier facts (haemoptysis, cyanosis, chest indrawing, severe dyspnoea)
outrank urgent-tier ones.

## Universal symptom dimensions (H4)

The symptom *owns* its exploration dimensions; diseases consume the facts.
`knowledge.symptom_dimension` is the canonical 25-dimension registry
(SD001-SD025): presence, onset, duration, time course, frequency, site,
distribution, radiation, character, severity, triggers, aggravating, relieving,
timing/pattern, associated, functional impact, systemic impact, red flag,
exposure, previous episodes, previous treatment, treatment response, patient
perspective, evolution, resolution. Universal dimensions are always explored;
conditional ones (site, radiation, distribution, frequency, character, ...)
apply only where they make sense (fever has no site). Each dimension is backed
by a `history_concept` — the H2 vocabulary stays the single source of truth, so
nothing is duplicated.

Per-symptom vocabulary lives in `symptom_dimension_option` (universal dimension
+ symptom-specific terms: cough character dry/productive/barking/paroxysmal vs
chest-pain character pressure/burning/sharp/tearing). `red_flag_rule` encodes
red flags as fact + context + significance. `exposure_concept` +
`symptom_exposure` make exposure history reusable across symptoms.
`symptom_relationship.diagnostic_weight` ranks hard vs soft associations
(haemoptysis > weight loss > fever as cough companions).

## Acceptance criteria

The Phase 1 acceptance test (`database/tests/acceptance_test.sql`) walks a full
scenario with **zero disease-specific code**:

`person → user → organization → facility → department → professional → patient →
encounter → clinical fact → observation → problem → order → result →
assessment → plan → document → audit`

If that runs clean, Phase 1 is genuinely universal.

## Machine test (Phase 1E)

`database/tests/amexan_machine_test.sql` walks the AMEXAN nephron against the
live `knowledge` graph — the same path the CPU will take in Phase 3:

`facts → phenotype → mechanism → diagnosis → investigation → protocol →
monitoring → education → reassess`

The scenario: a 35-year-old male with 4 days of productive cough, fever,
dyspnoea and right-lower-lobe consolidation signs. It asserts that acute LRTI
leads the phenotype scores, alveolar inflammation is implicated, the working
diagnosis resolves to Pneumonia, the CAP protocol fires (with steps, monitoring
and education), and that when SpO2 drops 94 → 88 the hypoxaemia and
respiratory-failure scores rise so the CPU re-assesses.

The test runs inside a transaction and rolls back, leaving the database
pristine and re-runnable:
