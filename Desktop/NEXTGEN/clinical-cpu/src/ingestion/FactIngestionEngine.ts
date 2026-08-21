// =============================================================================
// AMEXAN Clinical CPU — FactIngestionEngine
// =============================================================================
//
// PURPOSE
// -------
// The FactIngestionEngine is the universal clinical observation gateway.
//
// Every clinically meaningful patient input must eventually become a typed
// clinical FACT:
//
//     HISTORY QUESTION
//       answer -> answer_option -> fact_mapping -> FACT
//
//     FREE TEXT / NUMERIC / DATE
//       question -> question_fact -> FACT
//
//     EXAMINATION
//       finding -> examination_concept -> FACT
//
//     LABORATORY
//       result -> result interpreter -> FACT
//
//     IMAGING
//       finding -> imaging interpreter -> FACT
//
//     VITAL / DEVICE
//       observation -> FACT
//
// The downstream Clinical CPU NEVER reasons directly over UI answers such as:
//
//       "Yes"
//       "No"
//       "+++"
//       "88"
//       "productive"
//
// Instead it reasons over canonical medical facts:
//
//       PRODUCTIVE_COUGH = true
//       RESPIRATORY_RATE = 68 /min
//       SPO2 = 84 %
//       FEVER = true
//       FOCAL_CRACKLES = true
//
// IMPORTANT ARCHITECTURAL RULE
// ----------------------------
// This engine CAPTURES facts.
//
// It does NOT diagnose.
//
// It does NOT infer disease.
//
// It does NOT manufacture negative findings.
//
// It does NOT interpret absence of documentation as absence of disease.
//
// Interpretation belongs to downstream Clinical CPU engines.
//
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  ClinicalEvent,
  FactKind,
  ProcessRequest,
} from '../types.js';

import { ExaminationInterpreter } from '../examination/ExaminationInterpreter.js';
import { ResultInterpreter } from '../investigation/ResultInterpreter.js';
import {
  JourneyEventType,
  recordJourneyEvent,
} from '../observability/EventCore.js';


// =============================================================================
// DATABASE TYPES
// =============================================================================

interface QuestionRow extends Row {
  question_code: string;
}

interface AnswerOptionRow extends Row {
  answer_code: string;
}

interface FactMappingRow extends Row {
  fact_definition_code: string;
  value: string | null;
}

interface FactDefinitionRow extends Row {
  code?: string;
  fact_code?: string;
  data_type: string;
  unit_code?: string | null;
}

interface FactRow extends Row {
  id: string;
}

interface UnitRow extends Row {
  code: string;
}

interface ExistingFactRow extends Row {
  id: string;
  recorded_at: string;
  observed_at: string;
}

interface QuestionFactRow extends Row {
  fact_definition_code: string;
  unit_code: string | null;
}

interface PatientPersonRow extends Row {
  person_id: string;
}

interface FactValueRow extends Row {
  value_text: string | null;
  value_numeric: number | null;
  value_boolean: boolean | null;
}


// =============================================================================
// CHIEF COMPLAINT VOCABULARY
// =============================================================================
//
// The UI submits complaints with a compact complaint code (COUGH, FEVER, ...)
// plus a duration. The CPU mirrors each complaint into a durable
// symptom-present fact so the question selector and documentation engine
// reason against the same state the clinician captured.
//
// Only codes with a matching *_PRESENT definition are mirrored. Unknown codes
// still reach the PRESENTING_COMPLAINT summary.

interface ChiefComplaintInput {
  code: string;
  label: string;
  durationValue: string;
  durationUnit: string;
  durationSeconds: number | null;
  durationText: string | null;
}

const UNIT_TO_SECONDS: Record<string, number> = {
  minutes: 60,
  hours: 60 * 60,
  days: 24 * 60 * 60,
  weeks: 7 * 24 * 60 * 60,
  months: 30 * 24 * 60 * 60,
  years: 365 * 24 * 60 * 60,
};

function durationText(
  numeric: number,
  unit: string,
): string | null {
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return null;
  }

  const labels: Record<string, string> = {
    minutes: 'minute',
    hours: 'hour',
    days: 'day',
    weeks: 'week',
    months: 'month',
    years: 'year',
  };

  const label = labels[unit] ?? unit;

  const unitWord = numeric === 1 ? label : `${label}s`;

  return `${numeric} ${unitWord}`;
}

const CHIEF_COMPLAINT_PRESENT_FACT: Record<string, string> = {
  COUGH: 'COUGH_PRESENT',
  FEVER: 'FEVER_PRESENT',
  CHILLS: 'CHILLS_PRESENT',
  FATIGUE: 'FATIGUE_PRESENT',
  MALAISE: 'MALAISE_PRESENT',
  DYSPNOEA: 'DYSPNOEA_PRESENT',
  WHEEZE: 'WHEEZE_PRESENT',
  SPUTUM: 'SPUTUM_PRESENT',
  HAEMOPTYSIS: 'HEMOPTYSIS_PRESENT',
  CHEST_PAIN: 'CHEST_PAIN_PRESENT',
  PALPITATIONS: 'PALPITATIONS_PRESENT',
  SYNCOPE: 'SYNCOPE_PRESENT',
  ABDOMINAL_PAIN: 'ABDOMINAL_PAIN_PRESENT',
  NAUSEA: 'NAUSEA_PRESENT',
  VOMITING: 'VOMITING_PRESENT',
  DIARRHOEA: 'DIARRHEA_PRESENT',
  CONSTIPATION: 'CONSTIPATION_PRESENT',
  HEADACHE: 'HEADACHE_PRESENT',
  SEIZURE: 'SEIZURE_PRESENT',
  CONFUSION: 'CONFUSION_PRESENT',
  RASH: 'RASH_PRESENT',
  BLEEDING: 'BLEEDING_PRESENT',
  ANXIETY: 'ANXIETY_PRESENT',
};

// Complaint code → canonical *_DURATION_DAYS fact. Mirrors the chief-complaint
// duration into the symptom's own duration fact so the question selector sees
// the HPI duration as already captured and does not re-ask it.
const CHIEF_COMPLAINT_DURATION_FACT: Record<string, string> = {
  COUGH: 'COUGH_DURATION_DAYS',
  FEVER: 'FEVER_DURATION_DAYS',
  DYSPNOEA: 'DYSPNOEA_DURATION_DAYS',
};


// =============================================================================
// PUBLIC RESULT TYPES
// =============================================================================

export interface IngestResult {
  /**
   * Canonical fact definition codes captured by this event.
   */
  capturedFacts: string[];

  /**
   * Question answered, if this event originated from a question.
   */
  answeredQuestion: string | null;

  /**
   * IDs of newly created fact records.
   */
  factIds?: string[];

  /**
   * Facts that were intentionally not created because the same event/fact
   * was already processed.
   */
  deduplicated?: boolean;

  /**
   * Provenance source used for the capture.
   */
  sourceType?: string;
}


interface NormalizedValue {
  text: string | null;
  numeric: number | null;
  boolean: boolean | null;
}


// =============================================================================
// SOURCE MODEL
// =============================================================================

type FactSource =
  | 'patient_history'
  | 'examination'
  | 'lab'
  | 'imaging'
  | 'device'
  | 'clinician'
  | 'system'
  | 'derived';


// =============================================================================
// CLINICAL FACT INGESTION ENGINE
// =============================================================================

export class FactIngestionEngine {

  private readonly examination: ExaminationInterpreter;
  private readonly results: ResultInterpreter;

  constructor(
    private readonly db: Db,
  ) {
    this.examination = new ExaminationInterpreter(db);
    this.results = new ResultInterpreter(db);
  }


  // ===========================================================================
  // MAIN ENTRY POINT
  // ===========================================================================

  async ingest(
    request: ProcessRequest,
  ): Promise<IngestResult> {

    const {
      patientId,
      encounterId,
      event,
    } = request;

    if (!patientId) {
      throw new Error('Fact ingestion requires patientId');
    }

    if (!event?.type) {
      throw new Error('Fact ingestion requires event.type');
    }

    const payload =
      (event.payload ?? {}) as Record<string, unknown>;


    // -------------------------------------------------------------------------
    // QUESTION ANSWERED
    // -------------------------------------------------------------------------

    switch (event.type) {

      case 'QUESTION_ANSWERED': {

        const questionCode =
          this.asNonEmptyString(payload.questionCode);

        if (!questionCode) {
          return {
            capturedFacts: [],
            answeredQuestion: null,
          };
        }

        const answerCodes = this.extractAnswerCodes(payload);

        const rawValue =
          payload.rawValue ?? null;

        const factCodeHint =
          this.asOptionalString(payload.factCode);

        const unitCodeHint =
          this.asOptionalString(payload.unitCode);

        const sectionHint =
          this.asOptionalString(payload.section);

        const captured: string[] = [];
        const factIds: string[] = [];


        // ---------------------------------------------------------------------
        // Structured answer(s)
        // ---------------------------------------------------------------------

        if (answerCodes.length > 0) {

          for (const answerCode of answerCodes) {

            const result =
              await this.captureFromAnswer(
                patientId,
                encounterId ?? null,
                questionCode,
                answerCode,
                request.clinicianId ?? null,
                factCodeHint,
                unitCodeHint,
                sectionHint,
              );

            for (const code of result.factCodes) {
              if (!captured.includes(code)) {
                captured.push(code);
              }
            }

            factIds.push(...result.factIds);
          }
        }


        // ---------------------------------------------------------------------
        // Raw value question
        // ---------------------------------------------------------------------

        else if (rawValue !== null && rawValue !== undefined) {

          const result =
            await this.captureFromAnswer(
              patientId,
              encounterId ?? null,
              questionCode,
              String(rawValue),
              request.clinicianId ?? null,
              factCodeHint,
              unitCodeHint,
              sectionHint,
            );

          captured.push(...result.factCodes);
          factIds.push(...result.factIds);
        }


        // ---------------------------------------------------------------------
        // Derived administrative/clinical facts
        // ---------------------------------------------------------------------

        const derived =
          await this.applyDerivations(
            patientId,
            encounterId ?? null,
            captured,
            request.clinicianId ?? null,
          );

        for (const code of derived) {
          if (!captured.includes(code)) {
            captured.push(code);
          }
        }


        return {
          capturedFacts: captured,
          answeredQuestion: questionCode,
          factIds,
          sourceType: 'patient_history',
        };
      }


      // =========================================================================
      // QUESTION DISPOSITION
      // =========================================================================

      case 'QUESTION_DISPOSITIONED':
      case 'QUESTION_SKIPPED': {

        const questionCode =
          this.asOptionalString(payload.questionCode);

        /*
         * IMPORTANT:
         *
         * Skipped ≠ No.
         * Deferred ≠ No.
         * Not asked ≠ No.
         * Unknown ≠ No.
         *
         * Therefore NO clinical fact is created here.
         */

        return {
          capturedFacts: [],
          answeredQuestion: questionCode,
          sourceType: 'patient_history',
        };
      }


      // =========================================================================
      // CHIEF COMPLAINTS SAVED
      // =========================================================================

      case 'CHIEF_COMPLAINTS_SAVED': {

        /*
         * The UI submits the complete ordered complaint set (code, label,
         * durationValue, durationUnit) once the clinician finishes the CC
         * section. The CPU mirrors this into durable symptom-present facts so
         * downstream engines (question selector, documentation, differentials)
         * reason against the same clinical state the clinician sees.
         *
         * Unknown definitions are skipped, never fatal: an unrecognised
         * complaint still lands in the PRESENTING_COMPLAINT summary.
         */

        const complaints =
          this.extractComplaints(payload.complaints);

        const captured: string[] = [];
        const factIds: string[] = [];

        if (complaints.length > 0) {

          // Chronological order, oldest first — longest duration first.
          const ordered = [...complaints].sort(
            (a, b) =>
              (b.durationSeconds ?? 0) -
              (a.durationSeconds ?? 0),
          );

          const summary = ordered
            .map((entry) =>
              entry.durationText
                ? `${entry.label} for ${entry.durationText}`
                : entry.label,
            )
            .join('; ');

          const summaryFactId =
            await this.captureRawFact(
              patientId,
              encounterId ?? null,
              'PRESENTING_COMPLAINT',
              summary,
              null,
              'patient_history',
              request.clinicianId ?? null,
              'chief_complaint',
              this.observedAt(payload),
            );

          if (summaryFactId) {
            captured.push('PRESENTING_COMPLAINT');
            factIds.push(summaryFactId);
          }

          for (const entry of ordered) {
            const presentFact = CHIEF_COMPLAINT_PRESENT_FACT[entry.code];

            if (!presentFact) {
              continue;
            }

            const factId =
              await this.captureRawFact(
                patientId,
                encounterId ?? null,
                presentFact,
                true,
                null,
                'patient_history',
                request.clinicianId ?? null,
                'chief_complaint',
                this.observedAt(payload),
              );

            if (factId) {
              captured.push(presentFact);
              factIds.push(factId);
            }

            const durationFact =
              CHIEF_COMPLAINT_DURATION_FACT[entry.code];

            if (
              durationFact &&
              entry.durationSeconds != null &&
              entry.durationSeconds > 0
            ) {
              const days =
                entry.durationSeconds / 86_400;

              const factId =
                await this.captureRawFact(
                  patientId,
                  encounterId ?? null,
                  durationFact,
                  days,
                  'day',
                  'patient_history',
                  request.clinicianId ?? null,
                  'chief_complaint',
                  this.observedAt(payload),
                );

              if (factId) {
                captured.push(durationFact);
                factIds.push(factId);
              }
            }
          }
        }

        return {
          capturedFacts: captured,
          answeredQuestion: null,
          factIds,
          sourceType: 'patient_history',
        };
      }


      // =========================================================================
      // EXAMINATION
      // =========================================================================

      case 'EXAM_FINDING_CAPTURED': {

        const findingCode =
          this.asOptionalString(payload.findingCode);

        const rawFactCode =
          this.asOptionalString(payload.factCode);

        const value =
          payload.value;

        const unit =
          this.asOptionalString(payload.unit);

        if (findingCode) {

          const resolved =
            await this.examination.resolveFinding(
              findingCode,
            );

          const factCode =
            resolved?.factDefinitionCode ??
            rawFactCode;

          if (!factCode) {
            throw new Error(
              `Unable to resolve examination finding: ${findingCode}`,
            );
          }

          const factId =
            await this.captureRawFact(
              patientId,
              encounterId ?? null,
              factCode,
              value,
              unit,
              'examination',
              request.clinicianId ?? null,
              'examination',
              this.observedAt(payload),
            );

          return {
            capturedFacts: [factCode],
            answeredQuestion: null,
            factIds: factId ? [factId] : [],
            sourceType: 'examination',
          };
        }


        if (!rawFactCode) {
          throw new Error(
            'EXAM_FINDING_CAPTURED requires findingCode or factCode',
          );
        }

        const factId =
          await this.captureRawFact(
            patientId,
            encounterId ?? null,
            rawFactCode,
            value,
            unit,
            'examination',
            request.clinicianId ?? null,
            'examination',
            this.observedAt(payload),
          );

        return {
          capturedFacts: [rawFactCode],
          answeredQuestion: null,
          factIds: factId ? [factId] : [],
          sourceType: 'examination',
        };
      }


      // =========================================================================
      // IMAGING
      // =========================================================================

      case 'IMAGING_RESULT_RECEIVED': {

        const investigationCode =
          this.asOptionalString(
            payload.investigationCode,
          );

        const resultCodes =
          this.extractStringArray(payload.results);

        if (
          investigationCode &&
          resultCodes.length > 0
        ) {

          const interpreted =
            await this.results.interpret(
              investigationCode,
              resultCodes,
            );

          const captured: string[] = [];
          const factIds: string[] = [];

          for (const result of interpreted.facts) {

            const factId =
              await this.captureRawFact(
                patientId,
                encounterId ?? null,
                result.factCode,
                result.value,
                null,
                'imaging',
                request.clinicianId ?? null,
                'investigations',
                this.observedAt(payload),
              );

            if (!captured.includes(result.factCode)) {
              captured.push(result.factCode);
            }

            if (factId) {
              factIds.push(factId);
            }
          }

          return {
            capturedFacts: captured,
            answeredQuestion: null,
            factIds,
            sourceType: 'imaging',
          };
        }


        const factCode =
          this.asOptionalString(payload.factCode);

        if (!factCode) {
          throw new Error(
            'IMAGING_RESULT_RECEIVED requires investigationCode/results or factCode',
          );
        }

        const factId =
          await this.captureRawFact(
            patientId,
            encounterId ?? null,
            factCode,
            payload.value,
            this.asOptionalString(payload.unit),
            'imaging',
            request.clinicianId ?? null,
            'investigations',
            this.observedAt(payload),
          );

        return {
          capturedFacts: [factCode],
          answeredQuestion: null,
          factIds: factId ? [factId] : [],
          sourceType: 'imaging',
        };
      }


      // =========================================================================
      // LABORATORY
      // =========================================================================

      case 'LAB_RESULT_RECEIVED': {

        const factCode =
          this.asOptionalString(
            payload.factCode ??
            payload.observationCode,
          );

        if (!factCode) {
          throw new Error(
            'LAB_RESULT_RECEIVED requires factCode or observationCode',
          );
        }

        const factId =
          await this.captureRawFact(
            patientId,
            encounterId ?? null,
            factCode,
            payload.value,
            this.asOptionalString(payload.unit),
            'lab',
            request.clinicianId ?? null,
            'investigations',
            this.observedAt(payload),
          );

        return {
          capturedFacts: [factCode],
          answeredQuestion: null,
          factIds: factId ? [factId] : [],
          sourceType: 'lab',
        };
      }


      // =========================================================================
      // VITALS / DEVICES
      // =========================================================================

      case 'VITAL_CHANGED': {

        const factCode =
          this.asOptionalString(
            payload.factCode ??
            payload.observationCode,
          );

        if (!factCode) {
          throw new Error(
            'VITAL_CHANGED requires factCode or observationCode',
          );
        }

        const factId =
          await this.captureRawFact(
            patientId,
            encounterId ?? null,
            factCode,
            payload.value,
            this.asOptionalString(payload.unit),
            'device',
            request.clinicianId ?? null,
            'vitals',
            this.observedAt(payload),
          );

        return {
          capturedFacts: [factCode],
          answeredQuestion: null,
          factIds: factId ? [factId] : [],
          sourceType: 'device',
        };
      }


      // =========================================================================
      // DIRECT FACT
      // =========================================================================

      case 'FACT_CAPTURED': {

        const factCode =
          this.asOptionalString(payload.factCode);

        if (!factCode) {
          throw new Error(
            'FACT_CAPTURED requires factCode',
          );
        }

        const source =
          this.sourceFor(
            event.type,
            payload.sourceType,
          );

        const factId =
          await this.captureRawFact(
            patientId,
            encounterId ?? null,
            factCode,
            payload.value,
            this.asOptionalString(payload.unit),
            source,
            request.clinicianId ?? null,
            this.sectionFor(source),
            this.observedAt(payload),
          );

        return {
          capturedFacts: [factCode],
          answeredQuestion: null,
          factIds: factId ? [factId] : [],
          sourceType: source,
        };
      }


      default:
        return {
          capturedFacts: [],
          answeredQuestion: null,
        };
    }
  }


  // ===========================================================================
  // ANSWER → FACT
  // ===========================================================================

  private async captureFromAnswer(
    patientId: string,
    encounterId: string | null,
    questionCode: string,
    answerCode: string,
    clinicianId: string | null,
    factCodeHint?: string | null,
    unitCodeHint?: string | null,
    sectionHint?: string | null,
  ): Promise<{
    factCodes: string[];
    factIds: string[];
  }> {

    const question =
      await this.db.queryOne<QuestionRow>(
        `
        SELECT question_code
        FROM knowledge.question
        WHERE question_code = $1
        `,
        [questionCode],
      );


    // =========================================================================
    // UNIVERSAL VOCABULARY FALLBACK
    // =========================================================================

    if (!question) {

      if (!factCodeHint) {
        throw new Error(
          `Unknown question: ${questionCode}`,
        );
      }

      const factId =
        await this.captureRawFact(
          patientId,
          encounterId,
          factCodeHint,
          answerCode,
          unitCodeHint ?? null,
          'patient_history',
          clinicianId,
          sectionHint ?? 'hpi',
        );

      return {
        factCodes: [factCodeHint],
        factIds: factId ? [factId] : [],
      };
    }


    // =========================================================================
    // RAW VALUE QUESTION
    // =========================================================================

    const questionFact =
      await this.db.queryOne<QuestionFactRow>(
        `
        SELECT
          qf.fact_definition_code,
          qf.unit_code
        FROM knowledge.question_fact qf
        JOIN knowledge.question q
          ON q.id = qf.question_id
        WHERE q.question_code = $1
        `,
        [questionCode],
      );


    if (questionFact) {

      const factId =
        await this.captureRawFact(
          patientId,
          encounterId,
          questionFact.fact_definition_code,
          answerCode,
          questionFact.unit_code,
          'patient_history',
          clinicianId,
          sectionHint ?? 'hpi',
        );

      return {
        factCodes: [
          questionFact.fact_definition_code,
        ],
        factIds: factId ? [factId] : [],
      };
    }


    // =========================================================================
    // ANSWER OPTION
    // =========================================================================

    const option =
      await this.db.queryOne<AnswerOptionRow>(
        `
        SELECT ao.answer_code
        FROM knowledge.answer_option ao
        JOIN knowledge.question q
          ON q.id = ao.question_id
        WHERE q.question_code = $1
          AND ao.answer_code = $2
        `,
        [questionCode, answerCode],
      );


    if (!option) {
      throw new Error(
        `Unknown answer '${answerCode}' for question '${questionCode}'`,
      );
    }


    // =========================================================================
    // FACT MAPPINGS
    // =========================================================================

    const mappings =
      await this.db.query<FactMappingRow>(
        `
        SELECT
          fm.fact_definition_code,
          fm.value
        FROM knowledge.fact_mapping fm
        JOIN knowledge.answer_option ao
          ON ao.id = fm.answer_option_id
        JOIN knowledge.question q
          ON q.id = ao.question_id
        WHERE q.question_code = $1
          AND ao.answer_code = $2
        `,
        [questionCode, answerCode],
      );


    const factCodes: string[] = [];
    const factIds: string[] = [];


    for (const mapping of mappings) {

      const factId =
        await this.captureRawFact(
          patientId,
          encounterId,
          mapping.fact_definition_code,
          mapping.value ?? answerCode,
          null,
          'patient_history',
          clinicianId,
          sectionHint ?? 'hpi',
        );

      if (!factCodes.includes(mapping.fact_definition_code)) {
        factCodes.push(mapping.fact_definition_code);
      }

      if (factId) {
        factIds.push(factId);
      }
    }


    return {
      factCodes,
      factIds,
    };
  }


  // ===========================================================================
  // UNIVERSAL FACT CAPTURE
  // ===========================================================================

  private async captureRawFact(
    patientId: string,
    encounterId: string | null,
    factCode: string,
    rawValue: unknown,
    unit: string | null,
    sourceType: FactSource | string,
    clinicianId: string | null,
    sectionHint?: string | null,
    observedAt?: string | null,
  ): Promise<string | null> {

    if (!factCode) {
      throw new Error(
        'Cannot capture fact without factCode',
      );
    }


    // -------------------------------------------------------------------------
    // Resolve fact definition
    // -------------------------------------------------------------------------

    let definition =
      await this.db.queryOne<FactDefinitionRow>(
        `
        SELECT
          code,
          data_type
        FROM clinical.fact_definition
        WHERE code = $1
        `,
        [factCode],
      );


    // -------------------------------------------------------------------------
    // Universal vocabulary fallback
    // -------------------------------------------------------------------------

    if (!definition) {

      definition =
        await this.db.queryOne<FactDefinitionRow>(
          `
          SELECT
            fact_code,
            data_type
          FROM clinical.fact_definitions
          WHERE fact_code = $1
          `,
          [factCode],
        );

      if (!definition) {
        throw new Error(
          `Unknown fact definition: ${factCode}`,
        );
      }
    }


    // -------------------------------------------------------------------------
    // Normalize value
    // -------------------------------------------------------------------------

    const normalized =
      normalizeValue(
        definition.data_type as FactKind,
        rawValue,
      );


    // -------------------------------------------------------------------------
    // Reject invalid values instead of silently corrupting data.
    // -------------------------------------------------------------------------

    this.assertValidNormalizedValue(
      factCode,
      definition.data_type,
      rawValue,
      normalized,
    );


    // -------------------------------------------------------------------------
    // Validate unit against terminology.
    // -------------------------------------------------------------------------

    const unitCode =
      await this.validatedUnit(unit);


    // -------------------------------------------------------------------------
    // Determine section.
    // -------------------------------------------------------------------------

    const section =
      sectionHint ??
      this.sectionFor(sourceType);


    // -------------------------------------------------------------------------
    // Create fact record.
    //
    // A fact is immutable clinical provenance.
    //
    // If a value changes, create another fact rather than mutating the old
    // observation. Retraction/correction belongs to the provenance layer.
    // -------------------------------------------------------------------------

    const fact =
      await this.db.queryOne<FactRow>(
        `
        INSERT INTO clinical.fact
        (
          patient_id,
          encounter_id,
          fact_definition_code,
          status_code,
          recorded_by,
          observed_at
        )
        VALUES
        (
          $1,
          $2,
          $3,
          'active',
          $4,
          COALESCE($5::timestamptz, now())
        )
        RETURNING id
        `,
        [
          patientId,
          encounterId,
          factCode,
          clinicianId,
          observedAt ?? null,
        ],
      );


    if (!fact?.id) {
      throw new Error(
        `Failed to create fact: ${factCode}`,
      );
    }

    // Event Core — every captured fact joins the encounter journey so the
    // observatory can reconstruct exactly what was documented, by whom and when.
    await recordJourneyEvent(this.db, {
      eventType: JourneyEventType.FACT_CAPTURED,
      patientId,
      encounterId: encounterId ?? null,
      sourceType: normalizeSourceType(sourceType),
      sourceId: clinicianId ?? null,
      payload: {
        factId: fact.id,
        factCode,
        dataType: definition.data_type,
        normalized,
        unitCode: unitCode ?? null,
        section,
      },
      factCode,
      factValue: normalized,
    });


    // -------------------------------------------------------------------------
    // Fact value
    // -------------------------------------------------------------------------

    // The fact_value table enforces a strict data_type ↔ value-column contract
    // (chk_fact_value_type): 'coded' requires value_concept_id, 'date' requires
    // value_date, 'quantity' requires value_numeric, etc. The ingestion layer
    // only normalises into text/numeric/boolean, so we persist the type that
    // actually matches the populated column rather than the (richer) definition
    // type. This keeps writes valid against the DB constraint.
    const persistedDataType =
      normalized.boolean !== null && normalized.boolean !== undefined
        ? 'boolean'
        : normalized.numeric !== null &&
            normalized.numeric !== undefined
          ? 'numeric'
          : 'text';

    await this.db.query(
      `
      INSERT INTO clinical.fact_value
      (
        fact_id,
        value_order,
        data_type,
        value_text,
        value_numeric,
        value_boolean,
        unit_code
      )
      VALUES
      (
        $1,
        0,
        $2,
        $3,
        $4,
        $5,
        $6
      )
      `,
      [
        fact.id,
        persistedDataType,
        normalized.text,
        normalized.numeric,
        normalized.boolean,
        unitCode,
      ],
    );


    // -------------------------------------------------------------------------
    // Provenance source
    // -------------------------------------------------------------------------

    await this.db.query(
      `
      INSERT INTO clinical.fact_source
      (
        fact_id,
        source_type
      )
      VALUES
      (
        $1,
        $2
      )
      `,
      [
        fact.id,
        normalizeSourceType(sourceType),
      ],
    );


    // -------------------------------------------------------------------------
    // Clinical section context
    // -------------------------------------------------------------------------

    if (section) {

      await this.db.query(
        `
        INSERT INTO clinical.fact_context
        (
          fact_id,
          context_key,
          context_value
        )
        VALUES
        (
          $1,
          'section',
          $2
        )
        `,
        [
          fact.id,
          section,
        ],
      );
    }


    // -------------------------------------------------------------------------
    // Optional metadata context
    // -------------------------------------------------------------------------

    if (unitCode) {

      await this.db.query(
        `
        INSERT INTO clinical.fact_context
        (
          fact_id,
          context_key,
          context_value
        )
        VALUES
        (
          $1,
          'unit',
          $2
        )
        `,
        [
          fact.id,
          unitCode,
        ],
      );
    }


    return fact.id;
  }


  // ===========================================================================
  // VALUE VALIDATION
  // ===========================================================================

  private assertValidNormalizedValue(
    factCode: string,
    dataType: string,
    rawValue: unknown,
    normalized: NormalizedValue,
  ): void {

    switch (dataType) {

      case 'boolean': {

        if (
          normalized.boolean === null ||
          normalized.boolean === undefined
        ) {
          throw new Error(
            `Invalid boolean value for ${factCode}: ${String(rawValue)}`,
          );
        }

        break;
      }


      case 'numeric': {

        if (
          normalized.numeric === null ||
          !Number.isFinite(normalized.numeric)
        ) {
          throw new Error(
            `Invalid numeric value for ${factCode}: ${String(rawValue)}`,
          );
        }

        break;
      }


      default:
        break;
    }
  }


  // ===========================================================================
  // UNIT VALIDATION
  // ===========================================================================

  private async validatedUnit(
    unit: string | null,
  ): Promise<string | null> {

    if (!unit) {
      return null;
    }

    const normalized =
      unit.trim();

    if (!normalized) {
      return null;
    }

    const row =
      await this.db.queryOne<UnitRow>(
        `
        SELECT code
        FROM terminology.unit
        WHERE code = $1
        `,
        [normalized],
      );

    return row?.code ?? null;
  }


  // ===========================================================================
  // CLINICAL DERIVATIONS
  // ===========================================================================
  //
  // These are deterministic administrative/temporal derivations, NOT diagnoses.
  //
  // Example:
  //
  // LMP_DATE
  //    ↓
  // EDD
  //    ↓
  // GESTATIONAL_AGE
  //
  // DATE_OF_BIRTH
  //    ↓
  // person.birth_date
  //
  // AGE_YEARS
  //    ↓
  // estimated DOB
  //
  // ===========================================================================

  private async applyDerivations(
    patientId: string,
    encounterId: string | null,
    captured: string[],
    clinicianId: string | null,
  ): Promise<string[]> {

    const derived: string[] = [];

    if (captured.length === 0) {
      return derived;
    }


    const personRow =
      await this.db.queryOne<PatientPersonRow>(
        `
        SELECT person_id
        FROM patient.patient
        WHERE id = $1
        `,
        [patientId],
      );


    // =========================================================================
    // LMP → EDD + GA
    // =========================================================================

    if (captured.includes('LMP_DATE')) {

      const row =
        await this.latestFactValue(
          patientId,
          'LMP_DATE',
        );

      const lmp =
        row?.value_text;

      if (lmp) {

        const lmpDate =
          parseClinicalDate(lmp);

        if (lmpDate) {

          // Naegele's rule = 280 days.
          const edd =
            addDays(
              lmpDate,
              280,
            );

          const gaWeeks =
            gestationalAgeWeeks(
              lmpDate,
              new Date(),
            );


          await this.captureRawFact(
            patientId,
            encounterId,
            'EDD',
            toDateString(edd),
            null,
            'derived',
            clinicianId,
            'obstetric_history',
          );


          await this.captureRawFact(
            patientId,
            encounterId,
            'GESTATIONAL_AGE_WEEKS',
            gaWeeks,
            null,
            'derived',
            clinicianId,
            'obstetric_history',
          );


          derived.push(
            'EDD',
            'GESTATIONAL_AGE_WEEKS',
          );
        }
      }
    }


    if (!personRow?.person_id) {
      return derived;
    }


    // =========================================================================
    // DOB → person.birth_date
    // =========================================================================

    if (captured.includes('DATE_OF_BIRTH')) {

      const row =
        await this.latestFactValue(
          patientId,
          'DATE_OF_BIRTH',
        );

      if (row?.value_text) {

        const date =
          parseClinicalDate(
            row.value_text,
          );

        if (date) {

          await this.db.query(
            `
            UPDATE identity.person
            SET birth_date = $1::date,
                birth_date_estimated = false
            WHERE id = $2
            `,
            [
              toDateString(date),
              personRow.person_id,
            ],
          );
        }
      }
    }


    // =========================================================================
    // AGE → estimated DOB
    // =========================================================================

    if (captured.includes('AGE_YEARS')) {

      const person =
        await this.db.queryOne<{
          birth_date: string | null;
        }>(
          `
          SELECT birth_date::text AS birth_date
          FROM identity.person
          WHERE id = $1
          `,
          [personRow.person_id],
        );


      if (!person?.birth_date) {

        const row =
          await this.latestFactValue(
            patientId,
            'AGE_YEARS',
          );

        const years =
          row?.value_numeric;

        if (
          years != null &&
          Number.isFinite(years) &&
          years >= 0
        ) {

          const estimatedBirth =
            subtractDays(
              new Date(),
              Math.round(
                years * 365.2425,
              ),
            );


          await this.db.query(
            `
            UPDATE identity.person
            SET birth_date = $1::date,
                birth_date_estimated = true
            WHERE id = $2
            `,
            [
              toDateString(
                estimatedBirth,
              ),
              personRow.person_id,
            ],
          );
        }
      }
    }


    // =========================================================================
    // PATIENT NAME
    // =========================================================================

    if (captured.includes('PATIENT_NAME')) {

      const row =
        await this.latestFactValue(
          patientId,
          'PATIENT_NAME',
        );

      if (row?.value_text?.trim()) {

        await this.db.query(
          `
          UPDATE identity.person
          SET preferred_name = $1
          WHERE id = $2
          `,
          [
            row.value_text.trim(),
            personRow.person_id,
          ],
        );
      }
    }


    // =========================================================================
    // OCCUPATION
    // =========================================================================

    if (captured.includes('OCCUPATION')) {

      const row =
        await this.latestFactValue(
          patientId,
          'OCCUPATION',
        );

      if (row?.value_text?.trim()) {

        await this.db.query(
          `
          UPDATE identity.person
          SET occupation = $1
          WHERE id = $2
          `,
          [
            row.value_text.trim(),
            personRow.person_id,
          ],
        );
      }
    }


    // =========================================================================
    // SEX
    // =========================================================================

    if (captured.includes('SEX')) {

      const row =
        await this.latestFactValue(
          patientId,
          'SEX',
        );

      if (row?.value_text) {

        const gender =
          normalizeGender(
            row.value_text,
          );

        if (gender) {

          await this.db.query(
            `
            UPDATE identity.person
            SET gender = $1
            WHERE id = $2
            `,
            [
              gender,
              personRow.person_id,
            ],
          );
        }
      }
    }


    return derived;
  }


  // ===========================================================================
  // LATEST FACT VALUE
  // ===========================================================================

  private async latestFactValue(
    patientId: string,
    factCode: string,
  ): Promise<FactValueRow | null> {

    return this.db.queryOne<FactValueRow>(
      `
      SELECT
        fv.value_text,
        fv.value_numeric,
        fv.value_boolean
      FROM clinical.fact_value fv
      JOIN clinical.fact f
        ON f.id = fv.fact_id
      WHERE f.patient_id = $1
        AND f.fact_definition_code = $2
        AND f.status_code <> 'retracted'
      ORDER BY
        f.observed_at DESC,
        f.recorded_at DESC,
        fv.value_order ASC
      LIMIT 1
      `,
      [
        patientId,
        factCode,
      ],
    );
  }


  // ===========================================================================
  // SOURCE MAPPING
  // ===========================================================================

  private sourceFor(
    eventType: string,
    explicit: unknown,
  ): FactSource {

    if (
      typeof explicit === 'string' &&
      explicit.trim()
    ) {
      return explicit as FactSource;
    }

    switch (eventType) {

      case 'EXAM_FINDING_CAPTURED':
        return 'examination';

      case 'LAB_RESULT_RECEIVED':
        return 'lab';

      case 'IMAGING_RESULT_RECEIVED':
        return 'imaging';

      case 'VITAL_CHANGED':
        return 'device';

      default:
        return 'patient_history';
    }
  }


  // ===========================================================================
  // SECTION MAPPING
  // ===========================================================================

  private sectionFor(
    sourceType: string,
  ): string {

    switch (sourceType) {

      case 'examination':
        return 'examination';

      case 'lab':
      case 'imaging':
        return 'investigations';

      case 'device':
        return 'vitals';

      case 'obstetric_history':
        return 'obstetric_history';

      default:
        return 'hpi';
    }
  }


  // ===========================================================================
  // PAYLOAD HELPERS
  // ===========================================================================

  private extractAnswerCodes(
    payload: Record<string, unknown>,
  ): string[] {

    if (Array.isArray(payload.answerCodes)) {

      return payload.answerCodes
        .filter(
          (x): x is string =>
            typeof x === 'string' &&
            x.trim().length > 0,
        )
        .map(
          x => x.trim(),
        );
    }


    if (
      typeof payload.answerCode === 'string' &&
      payload.answerCode.trim()
    ) {
      return [
        payload.answerCode.trim(),
      ];
    }


    return [];
  }


  private extractStringArray(
    value: unknown,
  ): string[] {

    if (!Array.isArray(value)) {
      return [];
    }

    return value
      .filter(
        (x): x is string =>
          typeof x === 'string' &&
          x.trim().length > 0,
      )
      .map(
        x => x.trim(),
      );
  }


  private extractComplaints(
    value: unknown,
  ): ChiefComplaintInput[] {

    if (!Array.isArray(value)) {
      return [];
    }

    return value
      .filter(
        (x): x is Record<string, unknown> =>
          Boolean(x) &&
          typeof x === 'object',
      )
      .map((entry) => {
        const code = this.asNonEmptyString(entry.code);
        const canonicalLabel =
          this.asNonEmptyString(entry.canonicalLabel) ??
          this.asNonEmptyString(entry.label);
        const wording =
          this.asNonEmptyString(entry.patientWording) ??
          this.asNonEmptyString(entry.wording);
        const label = wording ?? canonicalLabel ?? code ?? 'complaint';
        const durationValue = this.asNonEmptyString(
          entry.durationValue,
        );
        const durationUnit = this.asNonEmptyString(
          entry.durationUnit,
        ) ?? 'days';

        const numeric = Number(durationValue);
        const unitSeconds =
          UNIT_TO_SECONDS[durationUnit];

        return {
          code,
          label,
          durationValue,
          durationUnit,
          durationSeconds:
            Number.isFinite(numeric) && numeric > 0 && unitSeconds
              ? numeric * unitSeconds
              : null,
          durationText: durationText(numeric, durationUnit),
        };
      })
      .filter(
        (entry): entry is ChiefComplaintInput =>
          Boolean(entry.code) || Boolean(entry.label),
      );
  }


  private asOptionalString(
    value: unknown,
  ): string | null {

    if (
      typeof value !== 'string' ||
      !value.trim()
    ) {
      return null;
    }

    return value.trim();
  }


  private asNonEmptyString(
    value: unknown,
  ): string | null {

    return this.asOptionalString(
      value,
    );
  }


  private observedAt(
    payload: Record<string, unknown>,
  ): string | null {

    const value =
      payload.observedAt ??
      payload.observationTime ??
      payload.measuredAt;

    if (
      typeof value === 'string' &&
      value.trim()
    ) {
      return value;
    }

    return null;
  }
}


// =============================================================================
// FACT SOURCE NORMALIZATION
// =============================================================================
//
// The internal source vocabulary (patient_history, examination, lab, ...)
// is richer than the persisted clinical.fact_source.source_type enum, which is
// constrained to:
//   patient | caregiver | clinician | collateral
//   | laboratory | imaging | device
//   | previous_encounter | imported_record | protocol | system | inferred
//
// Normalized only at the persistence boundary so the in-memory section/source
// mapping above stays unaffected by DB contract drift. Unknown values degrade
// to 'inferred' rather than violating the constraint.
// =============================================================================

function normalizeSourceType(
  value: string,
): 'clinical' | 'clinician' | 'patient' | 'device' | 'laboratory' | 'imaging' | 'medication' | 'system' | 'integration' | 'import' {
  switch (value) {
    case 'patient_history':
    case 'caregiver':
    case 'patient':
      return 'patient';
    case 'examination':
    case 'clinician':
    case 'collateral':
      return 'clinician';
    case 'lab':
    case 'laboratory':
      return 'laboratory';
    case 'imaging':
    case 'device':
    case 'medication':
      return value;
    case 'previous_encounter':
    case 'imported_record':
    case 'protocol':
    case 'system':
    case 'integration':
    case 'import':
      return 'system';
    case 'inferred':
    default:
      return 'system';
  }
}

// =============================================================================
// VALUE NORMALIZATION
// =============================================================================

function normalizeValue(
  dataType: FactKind,
  raw: unknown,
): NormalizedValue {

  switch (dataType) {

    // -------------------------------------------------------------------------
    // BOOLEAN
    // -------------------------------------------------------------------------

    case 'boolean': {

      if (typeof raw === 'boolean') {

        return {
          text: null,
          numeric: null,
          boolean: raw,
        };
      }


      if (
        typeof raw === 'number' &&
        (raw === 0 || raw === 1)
      ) {

        return {
          text: null,
          numeric: null,
          boolean: raw === 1,
        };
      }


      const value =
        String(raw ?? '')
          .trim()
          .toLowerCase();


      if (
        [
          'yes',
          'true',
          'y',
          '1',
          'present',
          'positive',
          'pos',
        ].includes(value)
      ) {

        return {
          text: null,
          numeric: null,
          boolean: true,
        };
      }


      if (
        [
          'no',
          'false',
          'n',
          '0',
          'absent',
          'negative',
          'neg',
        ].includes(value)
      ) {

        return {
          text: null,
          numeric: null,
          boolean: false,
        };
      }


      return {
        text: null,
        numeric: null,
        boolean: null,
      };
    }


    // -------------------------------------------------------------------------
    // NUMERIC
    // -------------------------------------------------------------------------

    case 'numeric': {

      const value =
        typeof raw === 'number'
          ? raw
          : Number(
              String(raw ?? '')
                .trim()
                .replace(/,/g, ''),
            );


      if (!Number.isFinite(value)) {

        return {
          text: null,
          numeric: null,
          boolean: null,
        };
      }


      return {
        text: null,
        numeric: value,
        boolean: null,
      };
    }


    // -------------------------------------------------------------------------
    // TEXT / DATE / CODE / OTHER
    // -------------------------------------------------------------------------

    default:

      return {
        text:
          raw == null
            ? null
            : String(raw),

        numeric: null,
        boolean: null,
      };
  }
}


// =============================================================================
// DATE UTILITIES
// =============================================================================

function parseClinicalDate(
  value: string,
): Date | null {

  const date =
    new Date(value);

  if (
    Number.isNaN(
      date.getTime(),
    )
  ) {
    return null;
  }

  return date;
}


function addDays(
  date: Date,
  days: number,
): Date {

  const result =
    new Date(date.getTime());

  result.setDate(
    result.getDate() + days,
  );

  return result;
}


function subtractDays(
  date: Date,
  days: number,
): Date {

  return addDays(
    date,
    -days,
  );
}


function gestationalAgeWeeks(
  lmp: Date,
  now: Date,
): number {

  const milliseconds =
    now.getTime() -
    lmp.getTime();

  const days =
    milliseconds /
    (24 * 60 * 60 * 1000);

  return Math.max(
    0,
    Math.floor(
      days / 7,
    ),
  );
}


function toDateString(
  date: Date,
): string {

  const year =
    date.getFullYear();

  const month =
    String(
      date.getMonth() + 1,
    ).padStart(2, '0');

  const day =
    String(
      date.getDate(),
    ).padStart(2, '0');

  return `${year}-${month}-${day}`;
}


// =============================================================================
// SEX / GENDER NORMALIZATION
// =============================================================================
//
// Clinical sex and administrative gender should ideally be separate concepts
// in the canonical model. This function exists only for compatibility with
// identity.person.gender.
//
// Do NOT use this value as a substitute for biological sex in clinical rules.
// The clinical context resolver should obtain SEX independently.
//
// =============================================================================

function normalizeGender(
  value: string,
): string | null {

  switch (
    value
      .trim()
      .toUpperCase()
  ) {

    case 'MALE':
      return 'male';

    case 'FEMALE':
      return 'female';

    case 'INTERSEX':
      return 'other';

    case 'NON_BINARY':
    case 'NON-BINARY':
      return 'other';

    case 'UNKNOWN':
      return 'unknown';

    default:
      return null;
  }
}