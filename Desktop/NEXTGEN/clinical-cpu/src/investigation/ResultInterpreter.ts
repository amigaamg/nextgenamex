// =============================================================================
// AMEXAN Clinical CPU — ResultInterpreter
// =============================================================================
//
// UNIVERSAL INVESTIGATION RESULT INTELLIGENCE
//
// Purpose
// -------
// Converts ANY structured investigation result into normalized AMEXAN clinical
// facts.
//
//     LAB / IMAGING / ECG / PATHOLOGY / MICROBIOLOGY / POCUS / PROCEDURE
//                              │
//                              ▼
//                    ResultInterpreter
//                              │
//               ┌──────────────┼──────────────┐
//               ▼              ▼              ▼
//          Result mapping   Normalization   Interpretation
//               │              │              │
//               └──────────────┼──────────────┘
//                              ▼
//                         Clinical Facts
//                              │
//                              ▼
//                 Clinical reasoning substrate
//
// CORE PRINCIPLE
// --------------
// The CPU does NOT reason over raw strings such as:
//
//     "RLL consolidation"
//     "positive"
//     "Hb 8.2"
//     "Na 128"
//     "E. coli"
//
// It resolves them into canonical clinical facts.
//
// Example:
//
//     CXR → RLL_CONSOLIDATION
//             ↓
//     fact: LUNG_CONSOLIDATION = true
//
//     Hb = 8.2 g/dL
//             ↓
//     fact: HAEMOGLOBIN = 8.2 g/dL
//
//     Na = 128 mmol/L
//             ↓
//     fact: SERUM_SODIUM = 128 mmol/L
//
//     HIV antibody = positive
//             ↓
//     fact: HIV_TEST_POSITIVE = true
//
//     Blood culture = S. aureus
//             ↓
//     fact: BLOOD_CULTURE_ORGANISM = S_AUREUS
//
// The same facts can then be consumed by:
//     - DifferentialEngine
//     - MechanismEngine
//     - SeverityEngine
//     - AlertEngine
//     - InvestigationSelector
//     - TreatmentEngine
//     - EducationEngine
//     - DocumentationEngine
//     - ProtocolEngine
//
// IMPORTANT SAFETY PRINCIPLE
// --------------------------
// A NORMAL / NEGATIVE result must not automatically create a positive clinical
// fact.
//
// Instead:
//
//     NEGATIVE → explicit negative fact IF mapped by knowledge
//     NORMAL   → normal interpretation metadata
//     POSITIVE → mapped positive fact
//
// This preserves the distinction between:
//     "no abnormality detected"
// and
//     "the condition is absent".
//
// =============================================================================

import type { Db, Row } from '../db.js';

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

export type ResultSource =
  | 'laboratory'
  | 'imaging'
  | 'pathology'
  | 'microbiology'
  | 'ecg'
  | 'physiology'
  | 'point_of_care'
  | 'procedure'
  | 'device'
  | 'other';

export type ResultPolarity =
  | 'positive'
  | 'negative'
  | 'normal'
  | 'abnormal'
  | 'indeterminate'
  | 'critical'
  | 'unknown';

export type ResultValueType =
  | 'boolean'
  | 'numeric'
  | 'text'
  | 'coded'
  | 'date'
  | 'range';

export interface InvestigationResultInput {
  /**
   * Canonical investigation code.
   *
   * Example:
   *   INV-CXR
   *   INV-FBC
   *   INV-UREA-CREAT
   */
  investigationCode: string;

  /**
   * Result codes supplied by the UI / LIS / RIS / external integration.
   *
   * Example:
   *   ["RLL_CONSOLIDATION"]
   */
  resultCodes?: string[];

  /**
   * Optional raw structured results.
   *
   * This permits quantitative and textual results that cannot be represented
   * adequately by a result code alone.
   */
  observations?: InvestigationObservationInput[];

  /**
   * Optional source supplied by the integration.
   */
  sourceType?: ResultSource;

  /**
   * Optional external accession / order / report identifiers.
   */
  accessionNumber?: string | null;
  orderId?: string | null;
  reportId?: string | null;

  /**
   * Optional report text.
   *
   * This is provenance/documentation data. It must NOT itself become a clinical
   * fact without an explicit knowledge mapping.
   */
  reportText?: string | null;

  /**
   * Optional timestamp of observation.
   */
  observedAt?: string | null;
}

export interface InvestigationObservationInput {
  /**
   * Result code when a structured result exists.
   */
  resultCode?: string | null;

  /**
   * Direct fact hint supplied by a trusted integration.
   *
   * This should still be validated against the fact vocabulary.
   */
  factCode?: string | null;

  /**
   * Actual result value.
   */
  value?: unknown;

  /**
   * Unit supplied by the instrument/integration.
   */
  unit?: string | null;

  /**
   * Optional reference interval supplied by the source.
   *
   * AMEXAN should preferentially use canonical knowledge reference ranges,
   * but retaining the source interval is useful for provenance.
   */
  referenceLow?: number | null;
  referenceHigh?: number | null;

  /**
   * Explicit polarity.
   */
  polarity?: ResultPolarity | null;

  /**
   * Free-text interpretation from the source.
   */
  interpretation?: string | null;
}

export interface InterpretedFact {
  factCode: string;

  /**
   * Normalized value.
   */
  value: unknown;

  /**
   * How the value should be persisted.
   */
  valueType: ResultValueType;

  /**
   * Canonical unit.
   */
  unit: string | null;

  /**
   * Whether this is a positive/negative/normal/abnormal interpretation.
   */
  polarity: ResultPolarity | null;

  /**
   * Optional result code that produced the fact.
   */
  resultCode: string | null;

  /**
   * Human-readable result label.
   */
  resultLabel: string | null;

  /**
   * Optional clinical interpretation.
   */
  interpretation: string | null;

  /**
   * Source-specific reference range.
   */
  referenceLow: number | null;
  referenceHigh: number | null;

  /**
   * Canonical result mapping ID where available.
   */
  mappingId: string | null;
}

export interface ResultInterpretation {
  facts: InterpretedFact[];

  /**
   * Result codes which were received but intentionally produced no clinical
   * fact because they are descriptive/documentary only.
   */
  unmappedResults: string[];

  /**
   * Explicitly normal/negative results that produced no positive fact.
   */
  nonPositiveResults: {
    resultCode: string;
    label: string | null;
    polarity: ResultPolarity;
  }[];

  /**
   * Critical findings which downstream alerting should inspect.
   */
  criticalResults: InterpretedFact[];

  /**
   * Human-readable provenance for audit/documentation.
   */
  provenance: {
    investigationCode: string;
    resultCodes: string[];
    sourceType: ResultSource;
    accessionNumber: string | null;
    orderId: string | null;
    reportId: string | null;
    observedAt: string | null;
  };
}

// -----------------------------------------------------------------------------
// Database rows
// -----------------------------------------------------------------------------

interface ResultRow extends Row {
  id?: string;

  result_code: string;
  result_label: string | null;

  /**
   * Canonical fact established by this result.
   */
  fact_definition_code: string | null;

  /**
   * Optional explicit value defined by the knowledge mapping.
   *
   * Example:
   *   result_code = BLOOD_GROUP_A
   *   value = "A"
   */
  value: string | null;

  /**
   * Optional canonical unit.
   */
  unit_code: string | null;

  /**
   * Optional data type.
   */
  data_type: string | null;

  /**
   * Optional polarity.
   */
  polarity: string | null;

  /**
   * Optional interpretation code.
   */
  interpretation_code: string | null;

  /**
   * Optional interpretation text.
   */
  interpretation_text: string | null;

  /**
   * Optional priority/order.
   */
  sort_order: number | null;
}

interface FactDefinitionRow extends Row {
  code: string;
  data_type: string;
  unit_code: string | null;
}

interface UnitRow extends Row {
  code: string;
}

interface InterpretationRow extends Row {
  code: string;
  label: string | null;
  severity: string | null;
}

interface ResultMappingRow extends Row {
  id: string;
  result_code: string;
  result_label: string | null;
  fact_definition_code: string | null;
  value: string | null;
  unit_code: string | null;
  data_type: string | null;
  polarity: string | null;
  interpretation_code: string | null;
  interpretation_text: string | null;
}

// =============================================================================
// ResultInterpreter
// =============================================================================

export class ResultInterpreter {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // UNIVERSAL ENTRY POINT
  // ===========================================================================

  async interpret(
    investigationCode: string,
    resultCodes: string[],
    observations: InvestigationObservationInput[] = [],
    metadata?: Partial<InvestigationResultInput>,
  ): Promise<ResultInterpretation> {
    const normalizedInvestigationCode = investigationCode.trim();

    if (!normalizedInvestigationCode) {
      throw new Error('Investigation code is required');
    }

    const uniqueResultCodes = [
      ...new Set(
        resultCodes
          .map((code) => code?.trim())
          .filter((code): code is string => Boolean(code)),
      ),
    ];

    const mappedRows =
      uniqueResultCodes.length > 0
        ? await this.loadResultMappings(
            normalizedInvestigationCode,
            uniqueResultCodes,
          )
        : [];

    const facts: InterpretedFact[] = [];
    const unmappedResults: string[] = [];
    const nonPositiveResults: ResultInterpretation['nonPositiveResults'] = [];

    // -------------------------------------------------------------------------
    // 1. Structured result-code mappings
    // -------------------------------------------------------------------------

    for (const resultCode of uniqueResultCodes) {
      const rows = mappedRows.filter((row) => row.result_code === resultCode);

      if (rows.length === 0) {
        unmappedResults.push(resultCode);
        continue;
      }

      for (const row of rows) {
        const fact = await this.mapResultRow(row);

        if (!fact) {
          const polarity = normalizePolarity(row.polarity);

          if (
            polarity === 'negative' ||
            polarity === 'normal'
          ) {
            nonPositiveResults.push({
              resultCode,
              label: row.result_label,
              polarity,
            });
          }

          continue;
        }

        facts.push(fact);
      }
    }

    // -------------------------------------------------------------------------
    // 2. Quantitative / free structured observations
    // -------------------------------------------------------------------------

    for (const observation of observations) {
      const observationFacts = await this.interpretObservation(
        normalizedInvestigationCode,
        observation,
      );

      facts.push(...observationFacts);

      if (
        observation.resultCode &&
        !mappedRows.some(
          (row) => row.result_code === observation.resultCode,
        )
      ) {
        if (!unmappedResults.includes(observation.resultCode)) {
          unmappedResults.push(observation.resultCode);
        }
      }
    }

    // -------------------------------------------------------------------------
    // 3. Deduplicate identical clinical facts
    //
    // A result can occasionally map through multiple knowledge relationships.
    // We retain the first clinically equivalent fact.
    // -------------------------------------------------------------------------

    const deduplicated = this.deduplicateFacts(facts);

    // -------------------------------------------------------------------------
    // 4. Identify critical results
    // -------------------------------------------------------------------------

    const criticalResults = deduplicated.filter(
      (fact) =>
        fact.polarity === 'critical' ||
        this.isCriticalInterpretation(fact.interpretation),
    );

    return {
      facts: deduplicated,
      unmappedResults,
      nonPositiveResults,
      criticalResults,

      provenance: {
        investigationCode: normalizedInvestigationCode,
        resultCodes: uniqueResultCodes,
        sourceType:
          metadata?.sourceType ??
          this.inferSourceType(normalizedInvestigationCode),
        accessionNumber: metadata?.accessionNumber ?? null,
        orderId: metadata?.orderId ?? null,
        reportId: metadata?.reportId ?? null,
        observedAt: metadata?.observedAt ?? null,
      },
    };
  }

  // ===========================================================================
  // BACKWARD-COMPATIBLE API
  // ===========================================================================
  //
  // Existing callers can continue doing:
  //
  //   interpret("INV-CXR", ["RLL_CONSOLIDATION"])
  //
  // and receive:
  //
  //   {
  //      facts: [
  //        {
  //          factCode: "LUNG_CONSOLIDATION",
  //          value: true
  //        }
  //      ]
  //   }
  //
  // while the richer universal method remains available.
  // ===========================================================================

  async interpretLegacy(
    investigationCode: string,
    resultCodes: string[],
  ): Promise<{ facts: { factCode: string; value: unknown }[] }> {
    const result = await this.interpret(
      investigationCode,
      resultCodes,
    );

    return {
      facts: result.facts.map((fact) => ({
        factCode: fact.factCode,
        value: fact.value,
      })),
    };
  }

  // ===========================================================================
  // RESULT MAPPING
  // ===========================================================================

  private async loadResultMappings(
    investigationCode: string,
    resultCodes: string[],
  ): Promise<ResultMappingRow[]> {
    return this.db.query<ResultMappingRow>(
      `
      SELECT
          r.id,
          r.result_code,
          r.result_label,
          r.fact_definition_code,
          r.fact_value::text AS value,
          r.unit AS unit_code,
          NULL::text AS data_type,
          NULL::text AS polarity,
          NULL::text AS interpretation_code,
          r.interpretation AS interpretation_text
        FROM knowledge.investigation_result r
        JOIN knowledge.investigation inv
          ON inv.id = r.investigation_id
       WHERE inv.investigation_code = $1
         AND r.result_code = ANY($2::text[])
         AND r.status = 'active'
       ORDER BY
          r.result_code,
          r.id
      `,
      [investigationCode, resultCodes],
    );
  }

  // ===========================================================================
  // MAP KNOWLEDGE RESULT → FACT
  // ===========================================================================

  private async mapResultRow(
    row: ResultMappingRow,
  ): Promise<InterpretedFact | null> {
    const polarity = normalizePolarity(row.polarity);

    // -------------------------------------------------------------------------
    // Explicitly non-positive result.
    //
    // Do NOT convert:
    //
    //   NORMAL
    //   NEGATIVE
    //
    // into a positive fact.
    // -------------------------------------------------------------------------

    if (polarity === 'normal' || polarity === 'negative') {
      return null;
    }

    if (!row.fact_definition_code) {
      return null;
    }

    const definition = await this.loadFactDefinition(
      row.fact_definition_code,
    );

    if (!definition) {
      throw new Error(
        `Result '${row.result_code}' maps to unknown fact definition '${row.fact_definition_code}'`,
      );
    }

    const dataType =
      row.data_type ||
      definition.data_type ||
      'text';

    const value = this.resolveMappedValue(
      row,
      dataType,
      polarity,
    );

    const unit = await this.validateUnit(
      row.unit_code ?? definition.unit_code,
    );

    const interpretation = await this.resolveInterpretation(
      row.interpretation_code,
      row.interpretation_text,
    );

    return {
      factCode: row.fact_definition_code,
      value,
      valueType: this.toResultValueType(dataType),
      unit,
      polarity,
      resultCode: row.result_code,
      resultLabel: row.result_label,
      interpretation,
      referenceLow: null,
      referenceHigh: null,
      mappingId: row.id,
    };
  }

  // ===========================================================================
  // RAW STRUCTURED OBSERVATION
  // ===========================================================================

  private async interpretObservation(
    investigationCode: string,
    observation: InvestigationObservationInput,
  ): Promise<InterpretedFact[]> {
    // -------------------------------------------------------------------------
    // Case A:
    // Observation already specifies a trusted canonical fact.
    // -------------------------------------------------------------------------

    if (observation.factCode) {
      return this.captureDirectObservation(
        observation.factCode,
        observation,
      );
    }

    // -------------------------------------------------------------------------
    // Case B:
    // Result code has a knowledge mapping.
    // -------------------------------------------------------------------------

    if (observation.resultCode) {
      const rows = await this.loadResultMappings(
        investigationCode,
        [observation.resultCode],
      );

      const facts: InterpretedFact[] = [];

      for (const row of rows) {
        if (!row.fact_definition_code) continue;

        const definition = await this.loadFactDefinition(
          row.fact_definition_code,
        );

        if (!definition) continue;

        const dataType =
          row.data_type ||
          definition.data_type ||
          'text';

        const value =
          observation.value !== undefined
            ? this.normalizeValue(
                dataType,
                observation.value,
              )
            : this.resolveMappedValue(
                row,
                dataType,
                normalizePolarity(row.polarity),
              );

        const unit = await this.validateUnit(
          observation.unit ??
            row.unit_code ??
            definition.unit_code,
        );

        facts.push({
          factCode: row.fact_definition_code,
          value,
          valueType: this.toResultValueType(dataType),
          unit,
          polarity:
            normalizePolarity(
              observation.polarity ??
                row.polarity,
            ),
          resultCode: observation.resultCode,
          resultLabel: row.result_label,
          interpretation:
            observation.interpretation ??
            row.interpretation_text ??
            null,
          referenceLow:
            observation.referenceLow ?? null,
          referenceHigh:
            observation.referenceHigh ?? null,
          mappingId: row.id,
        });
      }

      return facts;
    }

    // No canonical fact and no result code.
    return [];
  }

  // ===========================================================================
  // DIRECT OBSERVATION
  // ===========================================================================

  private async captureDirectObservation(
    factCode: string,
    observation: InvestigationObservationInput,
  ): Promise<InterpretedFact[]> {
    const definition = await this.loadFactDefinition(factCode);

    if (!definition) {
      throw new Error(
        `Unknown investigation fact definition: ${factCode}`,
      );
    }

    const value = this.normalizeValue(
      definition.data_type,
      observation.value,
    );

    const unit = await this.validateUnit(
      observation.unit ?? definition.unit_code,
    );

    return [
      {
        factCode,
        value,
        valueType: this.toResultValueType(
          definition.data_type,
        ),
        unit,
        polarity:
          normalizePolarity(observation.polarity),
        resultCode:
          observation.resultCode ?? null,
        resultLabel: null,
        interpretation:
          observation.interpretation ?? null,
        referenceLow:
          observation.referenceLow ?? null,
        referenceHigh:
          observation.referenceHigh ?? null,
        mappingId: null,
      },
    ];
  }

  // ===========================================================================
  // FACT DEFINITION
  // ===========================================================================

  private async loadFactDefinition(
    factCode: string,
  ): Promise<FactDefinitionRow | null> {
    return this.db.queryOne<FactDefinitionRow>(
      `
      SELECT
          code,
          data_type
        FROM clinical.fact_definition
       WHERE code = $1
      `,
      [factCode],
    );
  }

  // ===========================================================================
  // VALUE RESOLUTION
  // ===========================================================================

  private resolveMappedValue(
    row: ResultMappingRow,
    dataType: string,
    polarity: ResultPolarity | null,
  ): unknown {
    // Knowledge explicitly defines a value.
    if (row.value != null) {
      return this.normalizeValue(
        dataType,
        row.value,
      );
    }

    // A result with a positive/abnormal/critical polarity but no explicit
    // value is normally represented as a boolean fact.
    if (
      dataType === 'boolean' ||
      dataType === 'bool'
    ) {
      return polarity !== 'negative' &&
        polarity !== 'normal';
    }

    // If the knowledge result itself represents a coded/textual observation,
    // retain the canonical result code.
    return row.result_code;
  }

  // ===========================================================================
  // NORMALIZATION
  // ===========================================================================

  private normalizeValue(
    dataType: string,
    raw: unknown,
  ): unknown {
    if (raw == null) return null;

    const type = dataType.trim().toLowerCase();

    switch (type) {
      case 'boolean':
      case 'bool':
        return normalizeBoolean(raw);

      case 'numeric':
      case 'number':
      case 'decimal':
      case 'integer':
      case 'float': {
        const value =
          typeof raw === 'number'
            ? raw
            : Number(raw);

        if (!Number.isFinite(value)) {
          throw new Error(
            `Invalid numeric investigation result: ${String(raw)}`,
          );
        }

        return value;
      }

      case 'date': {
        const value = String(raw);

        if (!/^\d{4}-\d{2}-\d{2}/.test(value)) {
          throw new Error(
            `Invalid investigation date value: ${value}`,
          );
        }

        return value;
      }

      case 'coded':
      case 'code':
        return String(raw).trim();

      case 'text':
      case 'string':
      default:
        return String(raw);
    }
  }

  // ===========================================================================
  // UNIT VALIDATION
  // ===========================================================================

  private async validateUnit(
    unit: string | null,
  ): Promise<string | null> {
    if (!unit) return null;

    const normalized = unit.trim();

    if (!normalized) return null;

    const row = await this.db.queryOne<UnitRow>(
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
  // INTERPRETATION RESOLUTION
  // ===========================================================================

  private async resolveInterpretation(
    interpretationCode: string | null,
    interpretationText: string | null,
  ): Promise<string | null> {
    if (interpretationText?.trim()) {
      return interpretationText.trim();
    }

    if (!interpretationCode) {
      return null;
    }

    const row = await this.db.queryOne<InterpretationRow>(
      `
      SELECT
          code,
          label,
          severity
        FROM knowledge.clinical_interpretation
       WHERE code = $1
      `,
      [interpretationCode],
    );

    return row?.label ?? interpretationCode;
  }

  // ===========================================================================
  // VALUE TYPE
  // ===========================================================================

  private toResultValueType(
    dataType: string,
  ): ResultValueType {
    switch (dataType.toLowerCase()) {
      case 'boolean':
      case 'bool':
        return 'boolean';

      case 'numeric':
      case 'number':
      case 'decimal':
      case 'integer':
      case 'float':
        return 'numeric';

      case 'coded':
      case 'code':
        return 'coded';

      case 'date':
        return 'date';

      default:
        return 'text';
    }
  }

  // ===========================================================================
  // DEDUPLICATION
  // ===========================================================================

  private deduplicateFacts(
    facts: InterpretedFact[],
  ): InterpretedFact[] {
    const seen = new Map<string, InterpretedFact>();

    for (const fact of facts) {
      const key = [
        fact.factCode,
        String(fact.value),
        fact.unit ?? '',
      ].join('|');

      if (!seen.has(key)) {
        seen.set(key, fact);
      }
    }

    return [...seen.values()];
  }

  // ===========================================================================
  // CRITICALITY
  // ===========================================================================

  private isCriticalInterpretation(
    interpretation: string | null,
  ): boolean {
    if (!interpretation) return false;

    const text = interpretation.toLowerCase();

    return (
      text.includes('critical') ||
      text.includes('life-threatening') ||
      text.includes('severe abnormal') ||
      text.includes('urgent')
    );
  }

  // ===========================================================================
  // INVESTIGATION SOURCE CLASSIFICATION
  // ===========================================================================

  private inferSourceType(
    investigationCode: string,
  ): ResultSource {
    const code = investigationCode.toUpperCase();

    if (
      code.includes('CXR') ||
      code.includes('XRAY') ||
      code.includes('CT') ||
      code.includes('MRI') ||
      code.includes('ULTRASOUND') ||
      code.includes('USG') ||
      code.includes('ECHO')
    ) {
      return 'imaging';
    }

    if (
      code.includes('ECG') ||
      code.includes('EKG')
    ) {
      return 'ecg';
    }

    if (
      code.includes('BIOPSY') ||
      code.includes('HISTOLOGY') ||
      code.includes('CYTOLOGY') ||
      code.includes('PATH')
    ) {
      return 'pathology';
    }

    if (
      code.includes('CULTURE') ||
      code.includes('PCR') ||
      code.includes('AFB') ||
      code.includes('MICRO')
    ) {
      return 'microbiology';
    }

    if (
      code.includes('POCUS') ||
      code.includes('BEDSIDE')
    ) {
      return 'point_of_care';
    }

    return 'laboratory';
  }
}

// =============================================================================
// NORMALIZATION HELPERS
// =============================================================================

function normalizeBoolean(
  value: unknown,
): boolean {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  const normalized = String(value)
    .trim()
    .toLowerCase();

  if (
    [
      'true',
      'yes',
      'y',
      'positive',
      'present',
      'detected',
      'abnormal',
      '1',
    ].includes(normalized)
  ) {
    return true;
  }

  if (
    [
      'false',
      'no',
      'n',
      'negative',
      'absent',
      'not detected',
      'normal',
      '0',
    ].includes(normalized)
  ) {
    return false;
  }

  throw new Error(
    `Cannot normalize investigation value '${String(value)}' as boolean`,
  );
}

function normalizePolarity(
  value: string | null | undefined,
): ResultPolarity | null {
  if (!value) return null;

  switch (value.trim().toLowerCase()) {
    case 'positive':
    case 'pos':
      return 'positive';

    case 'negative':
    case 'neg':
      return 'negative';

    case 'normal':
      return 'normal';

    case 'abnormal':
      return 'abnormal';

    case 'critical':
      return 'critical';

    case 'indeterminate':
      return 'indeterminate';

    default:
      return 'unknown';
  }
}