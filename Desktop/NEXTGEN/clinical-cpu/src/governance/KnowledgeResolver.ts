// =============================================================================
// AMEXAN Clinical CPU — KnowledgeResolver (H10 §37)
// The runtime knowledge gate. Spec §37: the UI must never silently use an
// obsolete rule — at runtime the CPU asks the resolver, H10 checks
// active? applicable? jurisdiction? population? version? safety? and only a
// VALID result is returned.
//
//   VALID      — a governed object with a LIVE lifecycle (ACTIVE/APPROVED/VALIDATED)
//   BLOCKED    — a governed object whose lifecycle is not live (DRAFT/SUPERSEDED/
//                DEPRECATED/RETIRED) — MUST NOT be used (§41 publish gate / §49)
//   UNGOVERNED — no governed object is registered for this runtime code — a
//                provenance gap (§27/§49) that is flagged, not silently trusted
//
// The catalogue governs the REAL H4-H9 codes (DA001, PHEN-*, PROT-CAP-ADULT, …)
// by reference (§34). Governed objects that do not resolve to a runtime table
// (guidelines, documentation templates, …) register under their own
// object_code + knowledge_type so the DRAFT Kenya guideline stays BLOCKED.
// The resolver is pure policy (configurable, §26) — never hard-coded per module.
// =============================================================================

import type { Db, Row } from '../db.js';
import type {
  KnowledgeGateEntry,
  KnowledgeGateResult,
  KnowledgeGateTarget,
} from '../types.js';

interface GovernedRow extends Row {
  key_code: string;
  object_code: string;
  lifecycle_status: string;
}

const LIVE_STATUSES: ReadonlySet<string> = new Set(['ACTIVE', 'APPROVED', 'VALIDATED']);

export class KnowledgeResolver {
  constructor(private readonly db: Db) {}

  // -------------------------------------------------------------------------
  // Gate a set of knowledge entities the CPU is about to use. Read-only and
  // deterministic: no writes, no side effects — pure governance.
  // -------------------------------------------------------------------------
  async gate(targets: KnowledgeGateTarget[]): Promise<KnowledgeGateResult> {
    const governed = await this.loadGoverned();
    const valid: KnowledgeGateEntry[] = [];
    const blocked: KnowledgeGateEntry[] = [];
    const ungoverned: KnowledgeGateEntry[] = [];

    for (const target of targets) {
      const row = governed.get(`${target.kind}:${target.code}`);
      let entry: KnowledgeGateEntry;
      if (!row) {
        entry = {
          kind: target.kind,
          code: target.code,
          governed: false,
          objectCode: null,
          lifecycleStatus: null,
          verdict: 'UNGOVERNED',
          reason: 'no governed knowledge_object registered for this runtime code — provenance gap (§27/§49), flagged not trusted',
        };
        ungoverned.push(entry);
      } else if (LIVE_STATUSES.has(row.lifecycle_status)) {
        entry = {
          kind: target.kind,
          code: target.code,
          governed: true,
          objectCode: row.object_code,
          lifecycleStatus: row.lifecycle_status,
          verdict: 'VALID',
          reason: 'governed object is live — active, approved, validated',
        };
        valid.push(entry);
      } else {
        entry = {
          kind: target.kind,
          code: target.code,
          governed: true,
          objectCode: row.object_code,
          lifecycleStatus: row.lifecycle_status,
          verdict: 'BLOCKED',
          reason: `governed object lifecycle '${row.lifecycle_status}' is not live — must not be used (§37/§41/§49)`,
        };
        blocked.push(entry);
      }
    }

    return {
      passes: blocked.length === 0,
      checked: targets.length,
      valid,
      blocked,
      ungoverned,
    };
  }

  // -------------------------------------------------------------------------
  // Load the governed catalogue keyed by runtime code. Includes EVERY governed
  // object (not just live ones) so a DRAFT/SUPERSEDED object can be BLOCKED.
  // -------------------------------------------------------------------------
  private async loadGoverned(): Promise<Map<string, GovernedRow>> {
    const rows = await this.db.query<GovernedRow>(
      `SELECT ko.lifecycle_status, ko.object_code,
              'phenotype' AS kind, ph.phenotype_code AS key_code
         FROM governance.knowledge_object ko
         JOIN knowledge.phenotype ph ON ph.phenotype_code = ko.object_code
        UNION
       SELECT ko.lifecycle_status, ko.object_code,
              'condition' AS kind, c.condition_code AS key_code
         FROM governance.knowledge_object ko
         JOIN knowledge.diagnosis_concept dc ON dc.code = ko.object_code
         JOIN knowledge.condition c ON c.concept_id = dc.concept_id
        UNION
       SELECT ko.lifecycle_status, ko.object_code,
              'protocol' AS kind, pr.protocol_code AS key_code
         FROM governance.knowledge_object ko
         JOIN knowledge.protocol pr ON pr.protocol_code = ko.object_code
        UNION
       SELECT ko.lifecycle_status, ko.object_code,
              'question' AS kind, q.question_code AS key_code
         FROM governance.knowledge_object ko
         JOIN knowledge.question q ON q.question_code = ko.object_code
        UNION
       SELECT ko.lifecycle_status, ko.object_code,
              lower(ko.knowledge_type) AS kind, ko.object_code AS key_code
         FROM governance.knowledge_object ko`,
    );
    return new Map(rows.map((r) => [`${r.kind}:${r.key_code}`, r]));
  }
}
