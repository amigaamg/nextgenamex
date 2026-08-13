// =============================================================================
// AMEXAN Clinical CPU — FactIngestionEngine
// The fundamental operation: every patient input becomes a Fact.
//
//   question answer  → knowledge.answer_option → knowledge.fact_mapping → fact
//   examination      → fact (source = examination)
//   lab / imaging    → fact (source = lab / imaging)
//   vital change     → fact (source = device)
//
// The CPU never reasons over "Yes"/"No" — it reasons over the mapped medical
// fact (PRODUCTIVE, TRUE, 88). Values are normalized against the fact
// definition's declared data type before they are stored.
// =============================================================================

import type { Db, Row } from '../db.js';
import type { ClinicalEvent, FactKind, ProcessRequest } from '../types.js';
import { ExaminationInterpreter } from '../examination/ExaminationInterpreter.js';
import { ResultInterpreter } from '../investigation/ResultInterpreter.js';

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
  data_type: string;
}

interface FactRow extends Row {
  id: string;
}

export interface IngestResult {
  capturedFacts: string[];
  answeredQuestion: string | null;
}

export class FactIngestionEngine {
  private readonly examination: ExaminationInterpreter;
  private readonly results: ResultInterpreter;

  constructor(private readonly db: Db) {
    this.examination = new ExaminationInterpreter(db);
    this.results = new ResultInterpreter(db);
  }

  async ingest(request: ProcessRequest): Promise<IngestResult> {
    const { patientId, encounterId, event } = request;
    const payload = event.payload as Record<string, string | number | boolean | null>;

    switch (event.type) {
      case 'QUESTION_ANSWERED': {
        const questionCode = String(payload.questionCode ?? '');
        const answerCode = String(payload.answerCode ?? '');
        if (!questionCode || !answerCode) break;
        const captured = await this.captureFromAnswer(
          patientId,
          encounterId ?? null,
          questionCode,
          answerCode,
          request.clinicianId ?? null,
        );
        return { capturedFacts: captured, answeredQuestion: questionCode };
      }

      case 'QUESTION_SKIPPED': {
        // The clinician opted out of answering (4.9). The event is recorded by
        // the event bus but captures NO fact — "no data ≠ negative". The
        // ContextResolver treats it as answered so the question stops being
        // re-offered as the top priority.
        const questionCode = String(payload.questionCode ?? '');
        return { capturedFacts: [], answeredQuestion: questionCode || null };
      }

      case 'EXAM_FINDING_CAPTURED': {
        const findingCode = String(payload.findingCode ?? '');
        if (findingCode) {
          // The examination engine speaks finding codes; resolve to the fact
          // so examination feeds the same reasoning substrate as history.
          const resolved = await this.examination.resolveFinding(findingCode);
          const factCode = resolved?.factDefinitionCode ?? String(payload.factCode ?? '');
          if (!factCode) break;
          await this.captureRawFact(
            patientId,
            encounterId ?? null,
            factCode,
            payload.value,
            typeof payload.unit === 'string' ? (payload.unit as string) : null,
            'examination',
            request.clinicianId ?? null,
          );
          return { capturedFacts: [factCode], answeredQuestion: null };
        }
        const code = String(payload.factCode ?? '');
        if (!code) break;
        await this.captureRawFact(
          patientId,
          encounterId ?? null,
          code,
          payload.value,
          typeof payload.unit === 'string' ? (payload.unit as string) : null,
          'examination',
          request.clinicianId ?? null,
        );
        return { capturedFacts: [code], answeredQuestion: null };
      }

      case 'IMAGING_RESULT_RECEIVED': {
        const investigationCode = String(payload.investigationCode ?? '');
        const resultCodes = Array.isArray(payload.results) ? (payload.results as string[]) : [];
        if (investigationCode && resultCodes.length > 0) {
          // The closed loop: an imaging result returns to the CPU as facts.
          const interpreted = await this.results.interpret(investigationCode, resultCodes);
          const captured: string[] = [];
          for (const f of interpreted.facts) {
            await this.captureRawFact(
              patientId,
              encounterId ?? null,
              f.factCode,
              f.value,
              null,
              'imaging',
              request.clinicianId ?? null,
            );
            captured.push(f.factCode);
          }
          return { capturedFacts: captured, answeredQuestion: null };
        }
        const code = String(payload.factCode ?? '');
        if (!code) break;
        await this.captureRawFact(
          patientId,
          encounterId ?? null,
          code,
          payload.value,
          typeof payload.unit === 'string' ? (payload.unit as string) : null,
          'imaging',
          request.clinicianId ?? null,
        );
        return { capturedFacts: [code], answeredQuestion: null };
      }

      case 'FACT_CAPTURED':
      case 'LAB_RESULT_RECEIVED':
      case 'VITAL_CHANGED': {
        const code = String(payload.factCode ?? payload.observationCode ?? '');
        if (!code) break;
        const source = this.sourceFor(event.type, payload.sourceType);
        await this.captureRawFact(
          patientId,
          encounterId ?? null,
          code,
          payload.value,
          typeof payload.unit === 'string' ? (payload.unit as string) : null,
          source,
          request.clinicianId ?? null,
        );
        return { capturedFacts: [code], answeredQuestion: null };
      }

      default:
        break;
    }
    return { capturedFacts: [], answeredQuestion: null };
  }

  // Resolve answer → fact(s) through the knowledge graph, then capture them.
  private async captureFromAnswer(
    patientId: string,
    encounterId: string | null,
    questionCode: string,
    answerCode: string,
    clinicianId: string | null,
  ): Promise<string[]> {
    const question = await this.db.queryOne<QuestionRow>(
      `SELECT q.question_code FROM knowledge.question q WHERE q.question_code = $1`,
      [questionCode],
    );
    if (!question) throw new Error(`Unknown question: ${questionCode}`);

    // Raw-value questions (numeric / text / date) carry a question→fact binding:
    // the answer IS the medical value, so it captures directly.
    const questionFact = await this.db.queryOne<{ fact_definition_code: string; unit_code: string | null }>(
      `SELECT qf.fact_definition_code, qf.unit_code
         FROM knowledge.question_fact qf
         JOIN knowledge.question q ON q.id = qf.question_id
        WHERE q.question_code = $1`,
      [questionCode],
    );
    if (questionFact) {
      await this.captureRawFact(
        patientId,
        encounterId,
        questionFact.fact_definition_code,
        answerCode,
        questionFact.unit_code,
        'patient_history',
        clinicianId,
      );
      return [questionFact.fact_definition_code];
    }

    const option = await this.db.queryOne<AnswerOptionRow>(
      `SELECT ao.answer_code
         FROM knowledge.answer_option ao
         JOIN knowledge.question q ON q.id = ao.question_id
        WHERE q.question_code = $1 AND ao.answer_code = $2`,
      [questionCode, answerCode],
    );
    if (!option) throw new Error(`Unknown answer '${answerCode}' for question ${questionCode}`);

    const mappings = await this.db.query<FactMappingRow>(
      `SELECT fm.fact_definition_code, fm.value
         FROM knowledge.fact_mapping fm
         JOIN knowledge.answer_option ao ON ao.id = fm.answer_option_id
         JOIN knowledge.question q ON q.id = ao.question_id
        WHERE q.question_code = $1 AND ao.answer_code = $2`,
      [questionCode, answerCode],
    );

    const captured: string[] = [];
    for (const mapping of mappings) {
      await this.captureRawFact(
        patientId,
        encounterId,
        mapping.fact_definition_code,
        mapping.value ?? answerCode,
        null,
        'patient_history',
        clinicianId,
      );
      captured.push(mapping.fact_definition_code);
    }
    return captured;
  }

  // Normalize the value against the fact definition's data type and store it.
  private async captureRawFact(
    patientId: string,
    encounterId: string | null,
    factCode: string,
    rawValue: unknown,
    unit: string | null,
    sourceType: string,
    clinicianId: string | null,
  ): Promise<void> {
    const def = await this.db.queryOne<FactDefinitionRow>(
      `SELECT data_type FROM clinical.fact_definition WHERE code = $1`,
      [factCode],
    );
    if (!def) throw new Error(`Unknown fact definition: ${factCode}`);

    const normalized = normalizeValue(def.data_type as FactKind, rawValue);
    const unitCode = await this.validatedUnit(unit);
    const fact = await this.db.queryOne<FactRow>(
      `INSERT INTO clinical.fact
          (patient_id, encounter_id, fact_definition_code, status_code, recorded_by, observed_at)
       VALUES ($1, $2, $3, 'active', $4, now())
       RETURNING id`,
      [patientId, encounterId, factCode, clinicianId],
    );

    await this.db.query(
      `INSERT INTO clinical.fact_value
          (fact_id, value_order, data_type, value_text, value_numeric, value_boolean, unit_code)
       VALUES ($1, 0, $2, $3, $4, $5, $6)`,
      [fact!.id, def.data_type, normalized.text, normalized.numeric, normalized.boolean, unitCode],
    );

    await this.db.query(
      `INSERT INTO clinical.fact_source (fact_id, source_type) VALUES ($1, $2)`,
      [fact!.id, sourceType],
    );
  }

  private async validatedUnit(unit: string | null): Promise<string | null> {
    if (!unit) return null;
    const row = await this.db.queryOne<Row>(`SELECT code FROM terminology.unit WHERE code = $1`, [unit]);
    return row ? unit : null;
  }

  private sourceFor(eventType: string, explicit: unknown): string {
    if (typeof explicit === 'string' && explicit) return explicit;
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
}

function normalizeValue(dataType: FactKind, raw: unknown): {
  text: string | null;
  numeric: number | null;
  boolean: boolean | null;
} {
  switch (dataType) {
    case 'boolean':
      return {
        text: null,
        numeric: null,
        boolean: typeof raw === 'boolean' ? raw : /^(yes|true|y|1)$/i.test(String(raw)),
      };
    case 'numeric':
      return {
        text: null,
        numeric: typeof raw === 'number' ? raw : Number(raw),
        boolean: null,
      };
    default:
      return {
        text: raw == null ? null : String(raw),
        numeric: null,
        boolean: null,
      };
  }
}
