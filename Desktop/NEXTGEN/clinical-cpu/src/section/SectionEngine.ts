// =============================================================================
// AMEXAN Clinical CPU — SectionEngine (U3/U4)
// =============================================================================
//
// Universal workspace-navigation resolver.
//
// SectionEngine does NOT contain specialty medicine and does NOT decide clinical
// care. It resolves the structural clinical workspace from:
//
//   1. ClinicalFormatPlan
//      → patient/context-specific format
//
//   2. knowledge.clinical_format_section
//      → canonical workspace sections
//
//   3. knowledge.question_module
//      → module → section placement
//
//   4. knowledge.question_module_member
//      → question → module membership
//
//   5. knowledge.question_requirement
//      → required/safety/conditional workload
//
//   6. nextQuestions
//      → the CURRENT CPU-selected unresolved work
//
// The UI renders the resulting WorkspaceNavigationProjection. It does not
// independently decide whether a section is visible, locked, active, requires
// attention, or complete.
//
// -----------------------------------------------------------------------------
//
// SECTION STATE MODEL
//
//   hidden
//      Section is excluded by the patient's context/format.
//
//   locked
//      Section is applicable but the clinical workflow has not reached it.
//
//   available
//      Section is applicable and may be entered.
//
//   active
//      Section is the current CPU-selected working section.
//
//   attention
//      Section contains unresolved required/safety clinical work.
//
//   complete
//      All required work known to the CPU for that section is complete.
//
// -----------------------------------------------------------------------------
//
// UNIVERSAL WORKFLOW
//
//   HISTORY
//      ↓
//   EXAMINATION
//      ↓
//   ASSESSMENT
//      ↓
//   INVESTIGATIONS
//      ↓
//   MANAGEMENT
//      ↓
//   MONITORING
//      ↓
//   DOCUMENTATION
//
// The ordering is structural, not diagnostic. Specialty-specific sections are
// introduced through ClinicalFormatPlan and knowledge configuration.
//
// =============================================================================

import type { Db, Row } from '../db.js';

import type {
  ClinicalFormatPlan,
  NextQuestion,
  WorkspaceNavigationProjection,
  WorkspaceSectionProjection,
  WorkspaceSectionState,
  WorkspaceSubsectionProjection,
} from '../types.js';


// =============================================================================
// DATABASE ROW TYPES
// =============================================================================

interface SectionRow extends Row {
  format_code: string;
  section_code: string;
  label: string;
  section_group: string;
  sequence_no: number;
  is_required: boolean;
  default_state: string;
}

interface ModuleSectionRow extends Row {
  module_code: string;
  section_code: string | null;
}

interface QuestionModuleRow extends Row {
  question_code: string;
  module_code: string;
}

interface RequirementRow extends Row {
  question_code: string;
  requirement_level: string;
}

interface QuestionRow extends Row {
  question_code: string;
  is_active: boolean;
}

interface ContextSectionRow extends Row {
  section_code: string;
  context_type_code: string;
  context_value: string;
  applicability: string;
}


// =============================================================================
// WORKFLOW ORDER
// =============================================================================
//
// Lower number = earlier workflow group.
//
// This ordering is intentionally centralized so every SectionEngine operation
// uses exactly the same workflow semantics.
//

const GROUP_ORDER: Record<string, number> = {
  HISTORY: 0,
  EXAMINATION: 1,
  ASSESSMENT: 2,
  INVESTIGATIONS: 3,
  MANAGEMENT: 4,
  MONITORING: 5,
  DOCUMENTATION: 6,
};


// =============================================================================
// WORKFLOW PHASE MAPPING
// =============================================================================

const GROUP_TO_WORKFLOW: Record<
  string,
  WorkspaceNavigationProjection['workflowPhase']
> = {
  HISTORY: 'history',
  EXAMINATION: 'examination',
  ASSESSMENT: 'reasoning',
  INVESTIGATIONS: 'investigation',
  MANAGEMENT: 'management',
  MONITORING: 'monitoring',
  DOCUMENTATION: 'documentation',
};


// =============================================================================
// REQUIREMENT LEVELS THAT COUNT AS CLINICALLY REQUIRED WORK
// =============================================================================
//
// Safety is included because a safety question must not disappear from the
// navigation merely because it is not labelled "mandatory".
//
// Conditionally required questions count only when QuestionSelector has actually
// activated them into nextQuestions.
//

const REQUIRED_LEVELS = new Set<string>([
  'mandatory',
  'safety',
  'conditionally_required',
]);


// =============================================================================
// CANONICAL SECTION GROUPS
// =============================================================================
//
// Used only when a context format introduces a section that is not already
// present in clinical_format_section.
//
// The canonical database remains the preferred source.
//

const HISTORY_SECTIONS = new Set<string>([
  'CC',
  'HPI',
  'ROS',
  'PMHX',
  'MEDICATIONS',
  'ALLERGIES',
  'SOCIAL',
  'FAMILY',
  'BIRTH_HISTORY',
  'FEEDING_HISTORY',
  'DEVELOPMENTAL_HISTORY',
  'IMMUNIZATION_HISTORY',
  'MENSTRUAL_HISTORY',
  'OBSTETRIC_HISTORY',
  'GYNAECOLOGICAL_HISTORY',
  'ANC_PROFILE',
  'PSYCHIATRIC_HISTORY',
  'SUBSTANCE_USE',
  'SUICIDE_RISK',
  'BIODATA',
]);


// =============================================================================
// SECTION ENGINE
// =============================================================================

export class SectionEngine {
  constructor(private readonly db: Db) {}

  // ===========================================================================
  // BUILD WORKSPACE NAVIGATION
  // ===========================================================================
  //
  // Converts the current clinical format + current CPU question queue into the
  // navigation projection consumed by the UI.
  //
  // ===========================================================================

  async build(
    formatPlan: ClinicalFormatPlan,
    nextQuestions: NextQuestion[],
    hasFacts: boolean,
    hasChiefComplaint = hasFacts,
  ): Promise<WorkspaceNavigationProjection> {

    // -------------------------------------------------------------------------
    // LOAD ALL STRUCTURAL KNOWLEDGE IN PARALLEL
    // -------------------------------------------------------------------------

    const [
      sectionRows,
      moduleSections,
      questionModules,
      requirements,
      questionRows,
      contextSections,
    ] = await Promise.all([
      this.loadSections(formatPlan.baseFormat),

      this.loadModuleSections(),

      this.loadQuestionModules(),

      this.loadRequirements(),

      this.loadQuestions(),

      this.loadContextSections(),
    ]);


    // -------------------------------------------------------------------------
    // INDEX DATABASE KNOWLEDGE
    // -------------------------------------------------------------------------

    const moduleSectionByCode = this.indexModuleSections(moduleSections);

    const modulesByQuestion = this.indexQuestionModules(questionModules);

    const requirementsByQuestion =
      this.indexRequirements(requirements);

    const activeQuestionCodes = new Set(
      questionRows
        .filter((q) => q.is_active)
        .map((q) => q.question_code),
    );


    // -------------------------------------------------------------------------
    // CALCULATE REQUIRED QUESTION UNIVERSE
    // -------------------------------------------------------------------------
    //
    // requiredTotal is not simply nextQuestions.length.
    //
    // nextQuestions represents unresolved work.
    //
    // requiredTotal represents the amount of required work belonging to a
    // section according to the knowledge model.
    //
    // requiredRemaining represents what remains in the current CPU queue.
    //
    // -------------------------------------------------------------------------

    const requiredQuestionCodesBySection =
      this.buildRequiredQuestionUniverse(
        questionModules,
        moduleSectionByCode,
        requirementsByQuestion,
        activeQuestionCodes,
      );


    // -------------------------------------------------------------------------
    // CALCULATE CURRENT UNRESOLVED WORK
    // -------------------------------------------------------------------------

    const requiredRemainingBySection =
      this.buildRequiredRemaining(
        nextQuestions,
        modulesByQuestion,
        moduleSectionByCode,
        requirementsByQuestion,
      );


    // -------------------------------------------------------------------------
    // MERGE BASE FORMAT + CONTEXT ADDITIONS
    // -------------------------------------------------------------------------
    //
    // The format resolver can introduce additional sections for the patient.
    //
    // Example:
    //
    //   child
    //      → developmental history
    //
    //   pregnant patient
    //      → obstetric history / ANC
    //
    //   psychiatric context
    //      → suicide risk
    //
    // The section itself remains a universal workspace concept.
    //
    // -------------------------------------------------------------------------

    const excludedSections =
      new Set(formatPlan.excludedSections ?? []);

    const additionalSections =
      new Set(formatPlan.additionalSections ?? []);

    const requiredSections =
      new Set(formatPlan.requiredSections ?? []);

    const merged = this.mergeSections(
      sectionRows,
      additionalSections,
    );


    // -------------------------------------------------------------------------
    // APPLY CONTEXT SECTION MODIFIERS
    // -------------------------------------------------------------------------
    //
    // Context rules can:
    //
    //   - exclude a section
    //   - make a section applicable
    //   - elevate a section to required
    //
    // The format plan has already resolved the high-level context, therefore
    // SectionEngine primarily consumes its resulting sets here.
    //
    // -------------------------------------------------------------------------

    for (const code of requiredSections) {
      const row = merged.get(code);

      if (row) {
        row.is_required = true;
      }
    }


    // -------------------------------------------------------------------------
    // BUILD SECTION PROJECTIONS
    // -------------------------------------------------------------------------

    const sections: WorkspaceSectionProjection[] = [];

    for (const [sectionCode, row] of merged) {

      // -----------------------------------------------------------------------
      // EXCLUDED SECTION
      // -----------------------------------------------------------------------
      //
      // Excluded sections are not rendered into the active workspace tree.
      //
      // The state model supports "hidden", but the navigation projection should
      // normally omit hidden sections entirely. This prevents the UI from
      // presenting a clinically irrelevant section as selectable.
      //
      if (excludedSections.has(sectionCode)) {
        continue;
      }


      // -----------------------------------------------------------------------
      // REQUIRED COUNTS
      // -----------------------------------------------------------------------

      const requiredTotal =
        requiredQuestionCodesBySection.get(sectionCode)?.size ?? 0;

      const requiredRemaining =
        requiredRemainingBySection.get(sectionCode) ?? 0;


      // -----------------------------------------------------------------------
      // SECTION STATE
      // -----------------------------------------------------------------------

      const state = resolveSectionState({
        row,
        formatPlan,
        hasFacts,
        hasChiefComplaint,
        requiredRemaining,
        requiredTotal,
      });


      // -----------------------------------------------------------------------
      // BADGE / REASON
      // -----------------------------------------------------------------------

      const badge =
        requiredRemaining > 0
          ? requiredRemaining
          : null;

      const reason =
        requiredRemaining > 0
          ? `${requiredRemaining} required question${
              requiredRemaining === 1 ? '' : 's'
            } remaining`
          : null;


      // -----------------------------------------------------------------------
      // PROJECTION
      // -----------------------------------------------------------------------

      sections.push({
        sectionCode,
        label: row.label,
        state,
        priority: row.sequence_no,
        badge,
        reason,
        requiredRemaining,
        requiredTotal,
      });
    }


    // -------------------------------------------------------------------------
    // SORT SECTIONS
    // -------------------------------------------------------------------------

    sections.sort((a, b) => {
      const rowA = merged.get(a.sectionCode);
      const rowB = merged.get(b.sectionCode);

      const groupA =
        GROUP_ORDER[rowA?.section_group ?? 'HISTORY'] ?? 99;

      const groupB =
        GROUP_ORDER[rowB?.section_group ?? 'HISTORY'] ?? 99;

      if (groupA !== groupB) {
        return groupA - groupB;
      }

      return (
        (rowA?.sequence_no ?? a.priority) -
        (rowB?.sequence_no ?? b.priority)
      );
    });


    // -------------------------------------------------------------------------
    // BUILD WORKSPACE HIERARCHY
    // -------------------------------------------------------------------------
    //
    // History and examination become parent workspaces with subsections.
    //
    // Other sections remain top-level workspace entries.
    //
    // -------------------------------------------------------------------------

    const workspaces = groupWorkspaces(
      sections,
      merged,
    );


    // -------------------------------------------------------------------------
    // FIND CPU-DERIVED ACTIVE SECTION
    // -------------------------------------------------------------------------

    const activeSection = findActiveSection(
      workspaces,
      merged,
      hasFacts,
    );


    // -------------------------------------------------------------------------
    // DERIVE CURRENT WORKFLOW PHASE
    // -------------------------------------------------------------------------

    const workflowPhase = deriveWorkflowPhase(
      workspaces,
      merged,
      hasFacts,
    );


    // -------------------------------------------------------------------------
    // RETURN UNIVERSAL NAVIGATION PROJECTION
    // -------------------------------------------------------------------------

    return {
      sections: workspaces,

      activeSection,

      workflowPhase,

      currentContext: {
        ageBand: formatPlan.ageBand,
        sex: formatPlan.sex,
        pregnant: formatPlan.pregnant,
        gestationalAge: formatPlan.gestationalAge,
        department: formatPlan.department,
        encounterType: formatPlan.encounterType ?? null,
      },
    };
  }


  // ===========================================================================
  // LOAD SECTIONS
  // ===========================================================================

  private async loadSections(
    formatCode: string,
  ): Promise<SectionRow[]> {

    return this.db.query<SectionRow>(
      `
        SELECT
          format_code,
          section_code,
          label,
          section_group,
          sequence_no,
          is_required,
          default_state
        FROM knowledge.clinical_format_section
        WHERE format_code = $1
        ORDER BY sequence_no, section_code
      `,
      [formatCode],
    );
  }


  // ===========================================================================
  // LOAD MODULE → SECTION
  // ===========================================================================

  private async loadModuleSections(): Promise<ModuleSectionRow[]> {

    return this.db.query<ModuleSectionRow>(
      `
        SELECT
          module_code,
          section_code
        FROM knowledge.question_module
        WHERE section_code IS NOT NULL
      `,
    );
  }


  // ===========================================================================
  // LOAD QUESTION → MODULE
  // ===========================================================================

  private async loadQuestionModules(): Promise<QuestionModuleRow[]> {

    return this.db.query<QuestionModuleRow>(
      `
        SELECT
          q.question_code,
          qmm.module_code
        FROM knowledge.question_module_member qmm
        JOIN knowledge.question q
          ON q.id = qmm.question_id
      `,
    );
  }


  // ===========================================================================
  // LOAD REQUIREMENTS
  // ===========================================================================

  private async loadRequirements(): Promise<RequirementRow[]> {

    return this.db.query<RequirementRow>(
      `
        SELECT
          q.question_code,
          qr.requirement_level
        FROM knowledge.question_requirement qr
        JOIN knowledge.question q
          ON q.id = qr.question_id
      `,
    );
  }


  // ===========================================================================
  // LOAD ACTIVE QUESTIONS
  // ===========================================================================

  private async loadQuestions(): Promise<QuestionRow[]> {

    return this.db.query<QuestionRow>(
      `
        SELECT
          question_code,
          is_active
        FROM knowledge.question
        WHERE is_active = true
      `,
    );
  }


  // ===========================================================================
  // LOAD CONTEXT SECTION RULES
  // ===========================================================================
  //
  // Kept available for future/extended context-aware section resolution.
  //
  // The primary context decision remains centralized in FormatResolver so that
  // SectionEngine does not duplicate the universal patient context model.
  //
  // ===========================================================================

  private async loadContextSections(): Promise<ContextSectionRow[]> {

    try {
      return await this.db.query<ContextSectionRow>(
        `
          SELECT
            section_code,
            context_type AS context_type_code,
            context_value,
            modification AS applicability
          FROM knowledge.section_context_rule
          WHERE status = 'active'
        `,
      );
    } catch {
      // Backward-compatible operation where section_context_rule has not yet
      // been introduced in a deployment.
      //
      // The canonical format plan remains authoritative in that environment.
      return [];
    }
  }


  // ===========================================================================
  // INDEX MODULE → SECTION
  // ===========================================================================

  private indexModuleSections(
    rows: ModuleSectionRow[],
  ): Map<string, string> {

    const result = new Map<string, string>();

    for (const row of rows) {
      if (!row.section_code) continue;

      result.set(
        row.module_code,
        row.section_code,
      );
    }

    return result;
  }


  // ===========================================================================
  // INDEX QUESTION → ALL MODULES
  // ===========================================================================
  //
  // A question may legitimately belong to more than one module.
  //
  // Therefore this is intentionally NOT:
  //
  //   Map<question, module>
  //
  // It is:
  //
  //   Map<question, module[]>
  //
  // This prevents one module membership from silently overwriting another.
  //
  // ===========================================================================

  private indexQuestionModules(
    rows: QuestionModuleRow[],
  ): Map<string, string[]> {

    const result = new Map<string, string[]>();

    for (const row of rows) {
      const list =
        result.get(row.question_code) ?? [];

      if (!list.includes(row.module_code)) {
        list.push(row.module_code);
      }

      result.set(
        row.question_code,
        list,
      );
    }

    return result;
  }


  // ===========================================================================
  // INDEX REQUIREMENTS
  // ===========================================================================

  private indexRequirements(
    rows: RequirementRow[],
  ): Map<string, Set<string>> {

    const result = new Map<string, Set<string>>();

    for (const row of rows) {
      const levels =
        result.get(row.question_code) ??
        new Set<string>();

      levels.add(row.requirement_level);

      result.set(
        row.question_code,
        levels,
      );
    }

    return result;
  }


  // ===========================================================================
  // BUILD REQUIRED QUESTION UNIVERSE
  // ===========================================================================
  //
  // This determines how much required work belongs to each section.
  //
  // It deliberately excludes:
  //
  // - inactive questions
  // - questions without a section
  // - informational questions
  //
  // Conditional questions are counted as part of the requirement universe only
  // when they are present in the active knowledge model. Their current
  // applicability is reflected by nextQuestions.
  //
  // ===========================================================================

  private buildRequiredQuestionUniverse(
    questionModules: QuestionModuleRow[],
    moduleSectionByCode: Map<string, string>,
    requirementsByQuestion: Map<string, Set<string>>,
    activeQuestionCodes: Set<string>,
  ): Map<string, Set<string>> {

    const result =
      new Map<string, Set<string>>();

    for (const row of questionModules) {

      if (!activeQuestionCodes.has(row.question_code)) {
        continue;
      }

      const requirementLevels =
        requirementsByQuestion.get(row.question_code);

      if (!requirementLevels) {
        continue;
      }

      const required =
        [...requirementLevels].some(
          (level) => REQUIRED_LEVELS.has(level),
        );

      if (!required) {
        continue;
      }

      const section =
        moduleSectionByCode.get(row.module_code);

      if (!section) {
        continue;
      }

      const set =
        result.get(section) ??
        new Set<string>();

      set.add(row.question_code);

      result.set(section, set);
    }

    return result;
  }


  // ===========================================================================
  // BUILD CURRENT REQUIRED REMAINING
  // ===========================================================================
  //
  // nextQuestions already represents unresolved CPU-selected work.
  //
  // Therefore this method only counts required questions currently remaining.
  //
  // A question can belong to multiple modules; it is counted once per section.
  //
  // ===========================================================================

  private buildRequiredRemaining(
    nextQuestions: NextQuestion[],
    modulesByQuestion: Map<string, string[]>,
    moduleSectionByCode: Map<string, string>,
    requirementsByQuestion: Map<string, Set<string>>,
  ): Map<string, number> {

    const result =
      new Map<string, number>();

    const counted =
      new Map<string, Set<string>>();

    for (const question of nextQuestions) {

      const requirementLevels =
        requirementsByQuestion.get(
          question.questionCode,
        );

      if (!requirementLevels) {
        continue;
      }

      const required =
        [...requirementLevels].some(
          (level) => REQUIRED_LEVELS.has(level),
        );

      if (!required) {
        continue;
      }

      const modules =
        modulesByQuestion.get(
          question.questionCode,
        ) ?? [];

      const sections =
        new Set<string>();

      for (const module of modules) {
        const section =
          moduleSectionByCode.get(module);

        if (section) {
          sections.add(section);
        }
      }

      for (const section of sections) {

        const alreadyCounted =
          counted.get(section) ??
          new Set<string>();

        if (alreadyCounted.has(question.questionCode)) {
          continue;
        }

        alreadyCounted.add(
          question.questionCode,
        );

        counted.set(
          section,
          alreadyCounted,
        );

        result.set(
          section,
          (result.get(section) ?? 0) + 1,
        );
      }
    }

    return result;
  }


  // ===========================================================================
  // MERGE BASE FORMAT + ADDITIONAL SECTIONS
  // ===========================================================================

  private mergeSections(
    baseSections: SectionRow[],
    additionalSections: Set<string>,
  ): Map<string, SectionRow> {

    const merged =
      new Map<string, SectionRow>();

    for (const row of baseSections) {
      merged.set(
        row.section_code,
        { ...row },
      );
    }

    let additionalSequence = 1000;

    for (const code of additionalSections) {

      if (merged.has(code)) {
        continue;
      }

      merged.set(
        code,
        {
          format_code: baseSections[0]?.format_code ?? '',
          section_code: code,
          label: niceSection(code),
          section_group: sectionGroupOf(code),
          sequence_no: additionalSequence++,
          is_required: true,
          default_state: 'available',
        },
      );
    }

    return merged;
  }
}


// =============================================================================
// SECTION STATE RESOLUTION
// =============================================================================
//
// The UI receives the result verbatim.
//
// =============================================================================

interface SectionStateInput {
  row: SectionRow;
  formatPlan: ClinicalFormatPlan;
  hasFacts: boolean;
  hasChiefComplaint: boolean;
  requiredRemaining: number;
  requiredTotal: number;
}

function resolveSectionState(
  input: SectionStateInput,
): WorkspaceSectionState {

  const {
    row,
    hasFacts,
    hasChiefComplaint,
    requiredRemaining,
    requiredTotal,
  } = input;

  const group =
    normalizeGroup(row.section_group);


  // ---------------------------------------------------------------------------
  // REQUIRED WORK TAKES PRIORITY
  // ---------------------------------------------------------------------------
  //
  // If the CPU has unresolved required work, the section demands attention.
  //
  if (requiredRemaining > 0) {
    return 'attention';
  }


  // ---------------------------------------------------------------------------
  // WORKFLOW LOCKING
  // ---------------------------------------------------------------------------
  //
  // History and examination are the initial clinical workspace.
  //
  // Later groups require clinical content before they become reachable.
  //
  if (
    group !== 'HISTORY' &&
    group !== 'EXAMINATION' &&
    !hasFacts
  ) {
    return 'locked';
  }


  // ---------------------------------------------------------------------------
  // REQUIRED SECTION COMPLETION
  // ---------------------------------------------------------------------------

  if (
    row.is_required &&
    requiredTotal > 0 &&
    requiredRemaining === 0
  ) {
    return 'complete';
  }


  // ---------------------------------------------------------------------------
  // KNOWLEDGE-DEFINED DEFAULT COMPLETION
  // ---------------------------------------------------------------------------

  if (
    row.default_state === 'complete'
  ) {
    return 'complete';
  }


  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  if (group === 'HISTORY') {
    // HPI explores symptoms entered in the chief complaint. Until a chief
    // complaint has been recorded there is nothing for the HPI to explore,
    // so the section remains locked regardless of unrelated facts.
    if (
      row.section_code === 'HPI'
      && !hasChiefComplaint
    ) {
      return 'locked';
    }

    return hasFacts
      ? 'available'
      : 'available';
  }


  // ---------------------------------------------------------------------------
  // EXAMINATION
  // ---------------------------------------------------------------------------

  if (group === 'EXAMINATION') {
    return hasFacts
      ? 'available'
      : 'locked';
  }


  // ---------------------------------------------------------------------------
  // OTHER SECTIONS
  // ---------------------------------------------------------------------------

  return normalizeState(
    row.default_state,
  );
}


// =============================================================================
// GROUP WORKSPACES
// =============================================================================
//
// HISTORY and EXAMINATION are hierarchical workspace parents.
//
// Everything else remains a top-level workspace.
//
// =============================================================================

function groupWorkspaces(
  sections: WorkspaceSectionProjection[],
  merged: Map<string, SectionRow>,
): WorkspaceSectionProjection[] {

  const topLevel: WorkspaceSectionProjection[] = [];

  const historyChildren:
    WorkspaceSubsectionProjection[] = [];

  const examinationChildren:
    WorkspaceSubsectionProjection[] = [];


  // ---------------------------------------------------------------------------
  // CLASSIFY SECTIONS
  // ---------------------------------------------------------------------------

  for (const section of sections) {

    const group =
      normalizeGroup(
        merged.get(section.sectionCode)?.section_group,
      );

    if (group === 'HISTORY') {

      historyChildren.push({
        subsectionCode: section.sectionCode,
        label: section.label,
        state: section.state,
        requiredRemaining: section.requiredRemaining,
        requiredTotal: section.requiredTotal,
        badge: section.badge,
      });

      continue;
    }

    if (group === 'EXAMINATION') {

      examinationChildren.push({
        subsectionCode: section.sectionCode,
        label: section.label,
        state: section.state,
        requiredRemaining: section.requiredRemaining,
        requiredTotal: section.requiredTotal,
        badge: section.badge,
      });

      continue;
    }

    topLevel.push(section);
  }


  // ---------------------------------------------------------------------------
  // HISTORY PARENT
  // ---------------------------------------------------------------------------

  if (historyChildren.length > 0) {

    const historyRemaining =
      historyChildren.reduce(
        (sum, child) =>
          sum + (child.requiredRemaining ?? 0),
        0,
      );

    const historyTotal =
      historyChildren.reduce(
        (sum, child) =>
          sum + (child.requiredTotal ?? 0),
        0,
      );

    const historyState =
      aggregateParentState(
        historyChildren,
        'available',
      );

    topLevel.push({
      sectionCode: 'history',
      label: 'History',
      state: historyState,
      priority: GROUP_ORDER.HISTORY,
      badge:
        historyRemaining > 0
          ? historyRemaining
          : null,
      reason:
        historyRemaining > 0
          ? `${historyRemaining} required question${
              historyRemaining === 1 ? '' : 's'
            } remaining`
          : null,
      requiredRemaining: historyRemaining,
      requiredTotal: historyTotal,
      children: historyChildren,
    });
  }


  // ---------------------------------------------------------------------------
  // EXAMINATION PARENT
  // ---------------------------------------------------------------------------

  if (examinationChildren.length > 0) {

    const examinationRemaining =
      examinationChildren.reduce(
        (sum, child) =>
          sum + (child.requiredRemaining ?? 0),
        0,
      );

    const examinationTotal =
      examinationChildren.reduce(
        (sum, child) =>
          sum + (child.requiredTotal ?? 0),
        0,
      );

    const examinationState =
      aggregateParentState(
        examinationChildren,
        'locked',
      );

    topLevel.push({
      sectionCode: 'exam',
      label: 'Examination',
      state: examinationState,
      priority: GROUP_ORDER.EXAMINATION,
      badge:
        examinationRemaining > 0
          ? examinationRemaining
          : null,
      reason:
        examinationRemaining > 0
          ? `${examinationRemaining} required question${
              examinationRemaining === 1 ? '' : 's'
            } remaining`
          : null,
      requiredRemaining: examinationRemaining,
      requiredTotal: examinationTotal,
      children: examinationChildren,
    });
  }


  // ---------------------------------------------------------------------------
  // SORT FINAL WORKSPACE
  // ---------------------------------------------------------------------------

  return topLevel.sort(
    (a, b) => a.priority - b.priority,
  );
}


// =============================================================================
// PARENT STATE AGGREGATION
// =============================================================================

function aggregateParentState(
  children: WorkspaceSubsectionProjection[],
  emptyState: WorkspaceSectionState,
): WorkspaceSectionState {

  if (children.length === 0) {
    return emptyState;
  }


  // Any urgent unresolved work makes the parent require attention.
  if (
    children.some(
      (child) => child.state === 'attention',
    )
  ) {
    return 'attention';
  }


  // Active child makes the parent active.
  if (
    children.some(
      (child) => child.state === 'active',
    )
  ) {
    return 'active';
  }


  // Everything complete means parent complete.
  if (
    children.every(
      (child) =>
        child.state === 'complete' ||
        child.state === 'hidden',
    )
  ) {
    return 'complete';
  }


  // If at least one child is usable, parent is available.
  if (
    children.some(
      (child) =>
        child.state === 'available',
    )
  ) {
    return 'available';
  }


  // Otherwise all children are locked.
  return 'locked';
}


// =============================================================================
// ACTIVE SECTION
// =============================================================================
//
// Priority:
//
//   1. first section requiring attention
//   2. first active section
//   3. first section with unresolved required work
//   4. history before clinical facts exist
//   5. first available workspace
//
// This is a CPU-derived navigation decision, not a UI decision.
//
// =============================================================================

function findActiveSection(
  workspaces: WorkspaceSectionProjection[],
  merged: Map<string, SectionRow>,
  hasFacts: boolean,
): string {

  // ---------------------------------------------------------------------------
  // REQUIRED ATTENTION
  // ---------------------------------------------------------------------------

  const attention =
    findWorkspaceOrChild(
      workspaces,
      (state) => state === 'attention',
    );

  if (attention) {
    return attention;
  }


  // ---------------------------------------------------------------------------
  // ALREADY ACTIVE
  // ---------------------------------------------------------------------------

  const active =
    findWorkspaceOrChild(
      workspaces,
      (state) => state === 'active',
    );

  if (active) {
    return active;
  }


  // ---------------------------------------------------------------------------
  // REQUIRED WORK
  // ---------------------------------------------------------------------------

  const pending =
    workspaces.find(
      (section) =>
        section.requiredRemaining > 0,
    );

  if (pending) {
    return pending.sectionCode;
  }


  // ---------------------------------------------------------------------------
  // INITIAL CLINICAL WORKSPACE
  // ---------------------------------------------------------------------------

  if (!hasFacts) {
    const history =
      workspaces.find(
        (section) =>
          section.sectionCode === 'history',
      );

    if (history) {
      return history.sectionCode;
    }
  }


  // ---------------------------------------------------------------------------
  // FIRST AVAILABLE
  // ---------------------------------------------------------------------------

  const available =
    workspaces.find(
      (section) =>
        section.state === 'available' ||
        section.state === 'active',
    );

  if (available) {
    return available.sectionCode;
  }


  // ---------------------------------------------------------------------------
  // FALLBACK
  // ---------------------------------------------------------------------------

  return workspaces[0]?.sectionCode ?? 'history';
}


// =============================================================================
// FIND ACTIVE/ATTENTION CHILD
// =============================================================================

function findWorkspaceOrChild(
  workspaces: WorkspaceSectionProjection[],
  predicate: (state: WorkspaceSectionState) => boolean,
): string | null {

  for (const workspace of workspaces) {

    if (predicate(workspace.state)) {
      return workspace.sectionCode;
    }

    for (const child of workspace.children ?? []) {

      if (predicate(child.state)) {
        return child.subsectionCode;
      }
    }
  }

  return null;
}


// =============================================================================
// WORKFLOW PHASE
// =============================================================================
//
// Determines the current broad clinical workflow stage.
//
// The phase follows unresolved work rather than simply returning the first
// visible section.
//
// =============================================================================

function deriveWorkflowPhase(
  workspaces: WorkspaceSectionProjection[],
  merged: Map<string, SectionRow>,
  hasFacts: boolean,
): WorkspaceNavigationProjection['workflowPhase'] {

  if (!hasFacts) {
    return 'history';
  }


  // ---------------------------------------------------------------------------
  // REQUIRED WORK FIRST
  // ---------------------------------------------------------------------------

  const pending =
    findFirstPendingWorkspace(
      workspaces,
    );

  if (pending) {

    const row =
      merged.get(pending);

    const group =
      normalizeGroup(
        row?.section_group,
      );

    return (
      GROUP_TO_WORKFLOW[group] ??
      'history'
    );
  }


  // ---------------------------------------------------------------------------
  // FIND FIRST NON-COMPLETE WORKFLOW STAGE
  // ---------------------------------------------------------------------------

  const ordered =
    [...workspaces].sort(
      (a, b) => a.priority - b.priority,
    );

  for (const section of ordered) {

    if (
      section.state === 'locked' ||
      section.state === 'complete'
    ) {
      continue;
    }

    const row =
      merged.get(section.sectionCode);

    const group =
      normalizeGroup(
        row?.section_group,
      );

    const phase =
      GROUP_TO_WORKFLOW[group];

    if (phase) {
      return phase;
    }
  }


  // ---------------------------------------------------------------------------
  // ALL CURRENT WORK COMPLETE
  // ---------------------------------------------------------------------------

  return 'complete';
}


// =============================================================================
// FIND FIRST WORKSPACE WITH PENDING REQUIRED WORK
// =============================================================================

function findFirstPendingWorkspace(
  workspaces: WorkspaceSectionProjection[],
): string | null {

  const ordered =
    [...workspaces].sort(
      (a, b) => a.priority - b.priority,
    );

  for (const workspace of ordered) {

    if (workspace.requiredRemaining > 0) {
      return workspace.sectionCode;
    }

    for (const child of workspace.children ?? []) {
      if (child.requiredRemaining > 0) {
        return child.subsectionCode;
      }
    }
  }

  return null;
}


// =============================================================================
// SECTION GROUP NORMALIZATION
// =============================================================================

function normalizeGroup(
  value: string | null | undefined,
): string {

  if (!value) {
    return 'DOCUMENTATION';
  }

  const normalized =
    value.trim().toUpperCase();

  if (GROUP_ORDER[normalized] !== undefined) {
    return normalized;
  }

  if (
    normalized === 'EXAM' ||
    normalized === 'PHYSICAL_EXAM' ||
    normalized === 'PHYSICAL_EXAMINATION'
  ) {
    return 'EXAMINATION';
  }

  if (
    normalized === 'DIAGNOSIS' ||
    normalized === 'REASONING'
  ) {
    return 'ASSESSMENT';
  }

  if (
    normalized === 'TESTS' ||
    normalized === 'LABORATORY' ||
    normalized === 'IMAGING'
  ) {
    return 'INVESTIGATIONS';
  }

  if (
    normalized === 'TREATMENT' ||
    normalized === 'THERAPY'
  ) {
    return 'MANAGEMENT';
  }

  return 'DOCUMENTATION';
}


// =============================================================================
// DEFAULT SECTION GROUP RESOLUTION
// =============================================================================
//
// Used only for context-added sections where no canonical
// clinical_format_section row exists yet.
//
// =============================================================================

function sectionGroupOf(
  code: string,
): string {

  const normalized =
    code.trim().toUpperCase();

  if (
    HISTORY_SECTIONS.has(normalized)
  ) {
    return 'HISTORY';
  }

  if (
    normalized.startsWith('EXAM_') ||
    normalized.startsWith('EXAMINATION_')
  ) {
    return 'EXAMINATION';
  }

  if (
    normalized === 'ASSESSMENT' ||
    normalized === 'DIAGNOSIS' ||
    normalized === 'CLINICAL_REASONING'
  ) {
    return 'ASSESSMENT';
  }

  if (
    normalized === 'INVESTIGATIONS' ||
    normalized === 'LABORATORY' ||
    normalized === 'IMAGING'
  ) {
    return 'INVESTIGATIONS';
  }

  if (
    normalized === 'MANAGEMENT' ||
    normalized === 'TREATMENT'
  ) {
    return 'MANAGEMENT';
  }

  if (
    normalized === 'MONITORING' ||
    normalized === 'OBSERVATION'
  ) {
    return 'MONITORING';
  }

  return 'DOCUMENTATION';
}


// =============================================================================
// SECTION LABEL GENERATION
// =============================================================================

function niceSection(
  code: string,
): string {

  return code
    .replace(/[_-]+/g, ' ')
    .toLowerCase()
    .replace(/\b\w/g, (character) =>
      character.toUpperCase(),
    );
}


// =============================================================================
// STATE NORMALIZATION
// =============================================================================
//
// Prevent arbitrary database strings from escaping into the typed runtime
// projection.
//
// =============================================================================

function normalizeState(
  value: string | null | undefined,
): WorkspaceSectionState {

  switch (
    value?.trim().toLowerCase()
  ) {
    case 'hidden':
      return 'hidden';

    case 'locked':
      return 'locked';

    case 'available':
      return 'available';

    case 'active':
      return 'active';

    case 'attention':
      return 'attention';

    case 'complete':
      return 'complete';

    default:
      return 'available';
  }
}