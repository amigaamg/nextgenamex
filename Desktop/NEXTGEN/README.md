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
| `database/seed/seed_zknowledge_zpc_*.sql`     | cough clinical object (etiology, risk, impact, HPI templates) |
| `database/seed/seed_zknowledge_zpd_*.sql`     | full HPI narrative groups (chronology, previous, health_seeking, severity) |
| `database/seed/seed_zknowledge_zpe_hutchison_source.sql` | compiled Hutchison 24e source map — source/version/section/chapter/chunk/extraction_job (generated) |
| `database/seed/seed_zknowledge_zpf_hutchison_claims.sql` | compiled Hutchison claims ch 1/2/12 — `HC-000001..`, `H1-Cxx`, printed pages (generated) |

## Knowledge compiler

`knowledge-compiler/` turns authoritative sources into provenance-backed SQL seeds (H1 done, H2+ planned). The locked H1 hierarchy is:

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
